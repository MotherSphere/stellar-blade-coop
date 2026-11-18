-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode: the NIKKE DLC's rifle in EVE's hands on any save, on luke77's rifle stance. G (gun_key) or a tap of
-- D-pad Right brings the rifle out or puts it away. Out, EVE runs and jumps as Luke's stance has her (gunmode/
-- stance.lua: her own animation, the rifle at her chest). Holding RMB / LT is firing mode: the camera comes in over her
-- right shoulder, she turns to the camera and brings the rifle up with its laser sight on, and LMB / RT fires full
-- auto at the point under the screen centre. Letting go goes back to Luke's movement. Logged as [StellarCoop][GM].
-- How: each shot is the NIKKE shot skill, started by a zone event through SB's own rows (gunmode/data.lua), its
-- bullet sent to the crosshair's point (gunmode/aim.lua). While the rifle is out the sword's attacks and the drone's
-- aim on the fire and zoom keys are masked in memory (never saved; put back when it goes away).
-- Gun mode is a module of its own: it reads its own coop-settings.txt lines and uses nothing of the rest of the mod;
-- main.lua only builds and starts it, inside a pcall. All of it runs on the game thread, from one
-- LoopInGameThreadWithDelay loop (every frame): no LoopAsync, ExecuteWithDelay or key bind, whose callbacks run Lua on
-- another thread (two threads in one Lua state crashed UE4SS, 11-17). Every step is wrapped, so an error in gun mode
-- never reaches the rest of the mod.
local Config=require('gunmode.config')
local Aim=require('gunmode.aim')
local Input=require('gunmode.input')
local Stance=require('gunmode.stance')
local Laser=require('gunmode.laser')
local Data=require('gunmode.data')
local Probe=require('gunmode.probe')
local Ammo=require('gunmode.ammo')

local GunMode={}

local LIB='/Script/SB.Default__SBBlueprintLibrary'
local SETTINGS='/Script/Engine.Default__InputSettings'
local TRACE='/Script/Engine.Default__KismetSystemLibrary'

local function read_all(path)
    local f=io.open(path,'rb')
    if not f then return nil end
    local text=f:read('a')
    f:close()
    return text
end

-- A point along a camera's forward: loc + forward(rot) * d.
function GunMode.ahead(loc,rot,d)
    local p,y=math.rad(rot.Pitch),math.rad(rot.Yaw)
    local c=math.cos(p)
    return {X=loc.X+math.cos(y)*c*d,Y=loc.Y+math.sin(y)*c*d,Z=loc.Z+math.sin(p)*d}
end

-- a eased toward b by share k.
function GunMode.ease(a,b,k) return a+(b-a)*k end

-- env: {log, folder (the mod folder: coop-settings.txt), read_all (a file's text; io.open's unless given)}.
function GunMode.new(env)
    local cfg=Config.DEFAULTS
    local whole=env.read_all or read_all
    local set,bad=Config.parse(env.folder and whole(env.folder..'\\coop-settings.txt'))
    local g={}
    function g.log(m) env.log(m) end
    function g.valid(o)
        if o==nil then return false end
        local ok,r=pcall(function() return o:IsValid() end)
        return ok and r==true
    end
    function g.try(fn) local ok,r=pcall(fn); if ok then return r end end
    local cached -- The controller: FindFirstOf walks the whole object array.
    function g.pc()
        if g.valid(cached) then return cached end
        local pc=FindFirstOf('SBPlayerController')
        if g.valid(pc) then cached=pc; return pc end
    end
    function g.pawn()
        local pc=g.pc(); if not pc then return nil end
        local p=g.try(function() return pc.Pawn end)
        if g.valid(p) then return p end
    end
    local aim,data=Aim.new(g),Data.new(g,set.native,{speed=cfg.native_speed,upper=set.upper and 'P_Eve_GunNikke' or nil,cool=cfg.fire_interval})
    local stance=Stance.new(Laser)
    local probe=set.probe and Probe.new(g)
    local keys=Input.state()
    local self={}
    local s={hidden={},followed={},on=false,pause=0,next_shot=0,shots=0,zoom=0,zoom_held=false,target=nil,cam=nil,mask=nil,
        toggle_at=-1,hooked=false,errors=0}

    -- The reload: the NIKKE squad's reload animation on the rifle stance, and its sounds at their times.
    local function sound(path)
        local ok,err=pcall(function()
            local cue=LoadAsset(path)
            assert(cue,'no '..path)
            StaticFindObject('/Script/Engine.Default__GameplayStatics'):PlaySound2D(g.pawn(),cue,1.0,1.0,0.0,nil,nil,false)
        end)
        if not s.sound_logged then s.sound_logged=true; g.log('reload sound: '..(ok and 'played' or tostring(err))) end
    end
    local function on_reload(on,duration)
        local ok=stance.reload(on,duration)
        if on then
            s.sounds={}
            local now=os.clock()
            for _,e in ipairs(cfg.reload_sounds) do s.sounds[#s.sounds+1]={at=now+e[2]*duration,path=e[1]} end
            if not s.reload_logged then s.reload_logged=true; g.log('reload animation: '..(ok and 'playing' or 'not found')) end
        else s.sounds=nil end
    end
    local ammo=Ammo.new(g,cfg,function(v) data.cool(v) end,on_reload)

    local function fire_row(row)
        local lib=StaticFindObject(LIB)
        if not g.valid(lib) then return false end
        local ok,err=pcall(function() lib:CreateSBZoneEvent(2,FName(row)) end)
        if not ok then g.log('row '..row..' failed: '..tostring(err)) end
        return ok
    end

    -- The input mask, as Luke's maskAim makes it: cfg.mask_on_keys on cfg.mask_keys, and cfg.mask_actions on any key,
    -- set to key None and the keymaps rebuilt; restore() puts each one back. Axis mappings on those keys are only
    -- logged (the first time) so a later build can mask them if the game reads one.
    local function mask()
        local settings=StaticFindObject(SETTINGS)
        assert(g.valid(settings),'input settings unavailable')
        local masked_key,on_keys,masked_name={},{},{}
        for _,k in ipairs(cfg.mask_keys) do masked_key[k]=true end
        for _,n in ipairs(set.native and cfg.native_mask_on_keys or cfg.mask_on_keys) do on_keys[n]=true end
        if not set.native then for _,n in ipairs(cfg.mask_actions) do masked_name[n]=true end end
        local saved,names={},{}
        settings.ActionMappings:ForEach(function(_,wrapped)
            local row=wrapped:get()
            local name,key=row.ActionName:ToString(),row.Key.KeyName:ToString()
            if key~='None' and ((masked_key[key] and on_keys[name]) or masked_name[name]) then
                saved[#saved+1]={row=row,key=key,name=name}
                names[#names+1]=name..'('..key..')'
            elseif set.native and name=='TPSMode' and key==cfg.aim_from then -- The game's aim moved to RMB.
                saved[#saved+1]={row=row,key=key,name=name,to=set.aim_key}
                names[#names+1]=name..'('..key..' -> '..set.aim_key..')'
            end
        end)
        assert(#saved<=64,'unexpected action mappings: '..#saved)
        if not s.axes_logged then
            s.axes_logged=true
            local axes={}
            pcall(function() settings.AxisMappings:ForEach(function(_,wrapped)
                local row=wrapped:get()
                local key=row.Key.KeyName:ToString()
                if masked_key[key] then axes[#axes+1]=row.AxisName:ToString()..'('..key..')' end
            end) end)
            g.log('input: axes on the fire and zoom keys (not masked): '..(#axes>0 and table.concat(axes,' ') or 'none'))
        end
        local function restore()
            for _,e in ipairs(saved) do
                if e.changed then
                    pcall(function() e.row.Key.KeyName=FName(e.key) end)
                    e.changed=false
                end
            end
            pcall(function() settings:ForceRebuildKeymaps() end)
            g.log('input: '..#saved..' mappings put back')
        end
        local ok,err=pcall(function()
            for _,e in ipairs(saved) do e.changed=true; e.row.Key.KeyName=FName(e.to or 'None') end
            settings:ForceRebuildKeymaps()
        end)
        if not ok then restore(); error(err) end
        g.log('input: masked '..table.concat(names,' '))
        return restore
    end

    -- The point under the screen centre: the camera's line traced (visibility and camera channels, EVE ignored), or
    -- the far end of it.
    local function crosshair(pc,p)
        local cm=g.try(function() return pc.PlayerCameraManager end)
        if not g.valid(cm) then return nil end
        local loc,rot=cm:GetCameraLocation(),cm:GetCameraRotation()
        s.cam_loc,s.cam_rot=loc,rot
        local from=GunMode.ahead(loc,rot,0)
        local to=GunMode.ahead(loc,rot,cfg.trace_range)
        local trace=StaticFindObject(TRACE)
        if not g.valid(trace) then return to end
        local clear={R=0,G=0,B=0,A=0}
        local best,dist=to,cfg.trace_range
        for channel=0,1 do
            local hit={}
            local ok,blocked=pcall(function()
                return trace:LineTraceSingle(p,from,to,channel,false,{p},0,hit,true,clear,clear,0)
            end)
            if ok and blocked and hit.ImpactPoint then
                local q=hit.ImpactPoint
                local d=math.sqrt((q.X-from.X)^2+(q.Y-from.Y)^2+(q.Z-from.Z)^2)
                if d<dist then best,dist={X=q.X,Y=q.Y,Z=q.Z},d end
            end
        end
        return best
    end

    -- The camera: CameraBoom.CustomOffset, the rifle-out offset eased toward the zoom offset while zoom is held.
    local function camera(p)
        local boom=g.try(function() return p.CameraBoom end)
        if not g.valid(boom) then return end
        if not s.cam then
            local c=boom.CustomOffset
            s.cam={boom=boom,X=c.X,Y=c.Y,Z=c.Z}
        end
        s.zoom=GunMode.ease(s.zoom,s.zoom_held and 1 or 0,cfg.zoom_ease)
        local a,b=cfg.cam_offset,cfg.zoom_offset
        -- Her normal camera ignores CustomOffset (00:22): its arm length (the game sets it, so taken again whenever
        -- the zoom is out) and SocketOffset (right, up) are eased instead.
        if not s.cam.socket then
            local so=g.try(function() return boom.SocketOffset end)
            s.cam.socket=so and {X=so.X,Y=so.Y,Z=so.Z}
        end
        if s.zoom<0.01 then
            s.cam.arm=g.try(function() return boom.TargetArmLength end) or s.cam.arm
            return
        end
        local so=s.cam.socket
        local ok,err=pcall(function()
            if s.cam.arm then boom.TargetArmLength=s.cam.arm*GunMode.ease(1,cfg.zoom_arm,s.zoom) end
            if so then
                boom.SocketOffset={X=so.X,Y=GunMode.ease(so.Y,so.Y+b.Y,s.zoom),Z=GunMode.ease(so.Z,so.Z+b.Z,s.zoom)}
            end
        end)
        if not s.cam_logged and s.zoom>0.9 then
            s.cam_logged=true
            local now_arm=g.try(function() return boom.TargetArmLength end)
            local c=g.try(function() return boom.SocketOffset end)
            g.log(('camera: zoom %s, arm %s (base %s), socket (%s, %s, %s)'):format(ok and 'written' or tostring(err),
                tostring(now_arm),tostring(s.cam.arm),tostring(c and c.X),tostring(c and c.Y),tostring(c and c.Z)))
        end
    end
    local function camera_back()
        local c=s.cam
        s.cam,s.zoom=nil,0
        if c and g.valid(c.boom) then
            pcall(function() c.boom.CustomOffset={X=c.X,Y=c.Y,Z=c.Z} end)
            if c.socket then pcall(function() c.boom.SocketOffset={X=c.socket.X,Y=c.socket.Y,Z=c.socket.Z} end) end
            if c.arm then pcall(function() c.boom.TargetArmLength=c.arm end) end
        end
    end

    -- Her other mesh components hidden from the player's own camera while the rifle is out: Luke's stance hides her
    -- real body there and shows a posed copy, so a layer on the real body (Ultra Violence's blood, an overlay wearing
    -- her body's mesh) or the sword drawn in a fight showed as a ghost doing the real animation (00:12). Looked for
    -- again every second (the sword comes out with a fight); each one put back as it was when the rifle goes away.
    local MESH,SKEL,STATIC='/Script/Engine.MeshComponent','/Script/Engine.SkeletalMeshComponent',
        '/Script/Engine.StaticMeshComponent'
    local function hide_others(p,first)
        local src=g.try(function() return p.Mesh end)
        if not g.valid(src) then return end
        local body=g.try(function() return src.SkeletalMesh:GetFullName() end)
        local cls,skel,static=StaticFindObject(MESH),StaticFindObject(SKEL),StaticFindObject(STATIC)
        if not g.valid(cls) then return end
        local list=g.try(function() return p:K2_GetComponentsByClass(cls) end)
        if not list then return end
        local items={}
        local function unwrap(c) -- An element of the array: its object (wrapped, as the rifle scan found, 11-17).
            if c~=nil and not g.valid(c) then
                local ok,v=pcall(function() return c:get() end)
                if ok then return v end
            end
            return c
        end
        if type(list)=='table' and rawget(list,'ForEach')==nil then
            for _,c in ipairs(list) do items[#items+1]=unwrap(c) end
        else
            pcall(function() list:ForEach(function(_,e) items[#items+1]=unwrap(e) end) end)
        end
        if first then g.log('hide: '..#items..' mesh components') end
        local seen={}
        for _,c in ipairs(items) do
            local addr=g.valid(c) and g.try(function() return c:GetAddress() end)
            if addr and not s.hidden[addr] and c~=src and not stance.owns(c) then
                local mesh
                if g.valid(skel) and g.try(function() return c:IsA(skel) end) then
                    mesh=g.try(function() return c.SkeletalMesh:GetFullName() end)
                elseif g.valid(static) and g.try(function() return c:IsA(static) end) then
                    mesh=g.try(function() return c.StaticMesh:GetFullName() end)
                end
                local hide=mesh~=nil and mesh==body
                local short=mesh and mesh:match('[^%.]+$') -- The asset's own name: its path named the hairpin's folder.
                for _,n in ipairs(cfg.hide_names) do
                    if short and short:find(n,1,true) then hide=true end
                end
                local follow=false
                if not hide and short and g.valid(skel) and g.try(function() return c:IsA(skel) end) then
                    for _,n in ipairs(cfg.follow_names) do if short:find(n,1,true) then follow=true end end
                end
                if follow and not s.followed[addr] then
                    local body=stance.body()
                    if g.valid(body) and pcall(function() c:SetMasterPoseComponent(body,true) end) then
                        s.followed[addr]={c=c}
                    end
                end
                if first then
                    seen[#seen+1]=(hide and '*' or follow and '+' or '')..tostring(mesh and mesh:match('[^%.]+$'))
                end
                if hide then
                    local was=g.try(function() return c.bOwnerNoSee end)
                    if pcall(function() c:SetOwnerNoSee(true) end) then s.hidden[addr]={c=c,was=was==true} end
                end
            end
        end
        if first then
            g.log('hide: her meshes (* hidden from her camera, + following the posed copy): '..table.concat(seen,' '))
        end
    end
    local function show_others()
        for _,e in pairs(s.hidden) do
            if g.valid(e.c) then pcall(function() e.c:SetOwnerNoSee(e.was) end) end
        end
        s.hidden={}
        local p=g.pawn()
        local src=p and g.try(function() return p.Mesh end)
        for _,e in pairs(s.followed) do
            if g.valid(e.c) and g.valid(src) then pcall(function() e.c:SetMasterPoseComponent(src,true) end) end
        end
        s.followed={}
    end

    -- The drone (it fires the shots in the game's aim) hidden while the rifle is out: its mesh components
    -- bHiddenInGame, as race/doro.lua hides it; put back as they were. FindAllOf walks every object, so it is looked
    -- for when the rifle comes out and again only when the one held goes.
    local DRONE='CH_Drone_BP_C'
    local function hide_drone(p)
        if s.drone and g.valid(s.drone.actor) then return end
        local best,best_d
        local loc=g.try(function() return p:K2_GetActorLocation() end)
        if not loc then return end
        local all=g.try(function() return FindAllOf(DRONE) end) or {}
        for _,d in ipairs(all) do
            local q=g.valid(d) and g.try(function() return d:K2_GetActorLocation() end)
            if q then
                local dist=math.sqrt((q.X-loc.X)^2+(q.Y-loc.Y)^2+(q.Z-loc.Z)^2)
                if dist<3000 and (not best_d or dist<best_d) then best,best_d=d,dist end
            end
        end
        if not best then return end
        local cls=StaticFindObject(MESH)
        local parts={}
        local list=g.try(function() return best:K2_GetComponentsByClass(cls) end)
        local function each(fn)
            if type(list)=='table' and rawget(list,'ForEach')==nil then for _,c in ipairs(list) do fn(c) end
            elseif list then pcall(function() list:ForEach(function(_,e) fn(e) end) end) end
        end
        each(function(c)
            if not g.valid(c) then local ok,v=pcall(function() return c:get() end); if ok then c=v end end
            if g.valid(c) and g.try(function() return c.bHiddenInGame end)~=true then
                if pcall(function() c:SetHiddenInGame(true,false) end) then parts[#parts+1]=c end
            end
        end)
        s.drone={actor=best,parts=parts}
        g.log('drone: '..#parts..' parts hidden ('..#all..' drones)')
    end
    local function show_drone()
        if s.drone then
            for _,c in ipairs(s.drone.parts) do if g.valid(c) then pcall(function() c:SetHiddenInGame(false,false) end) end end
        end
        s.drone=nil
    end

    -- Firing mode's pose between shots: the NIKKE shot's own animation (its montage, learnt from the first shot
    -- fired: it looked right while firing, 02:34) held near its start while aim is held and no shot is playing, so
    -- she keeps the rifle up instead of the drone aim's pointing pose; stopped when aim is let go.
    local function hold_pose(p,firing)
        local ai=g.try(function() return p.Mesh:GetAnimInstance() end)
        if not g.valid(ai) then return end
        local cur=g.try(function() return ai:GetCurrentActiveMontage() end)
        local name=g.valid(cur) and g.try(function() return cur:GetFName():ToString() end)
        if name and name:find('GunNikke',1,true) and name:find('Shoot',1,true) and not s.pose_m then
            s.pose_m=cur
            g.log('pose: the NIKKE shot montage is '..name)
        end
        if not g.valid(s.pose_m) then return end
        if s.zoom_held and not firing and not g.valid(cur) then
            pcall(function()
                ai:Montage_Play(s.pose_m,0.0,0,cfg.pose_time,false)
            end)
            s.pose_on=true
        elseif s.zoom_held and firing and s.pose_on and cur==s.pose_m then
            pcall(function() ai:Montage_SetPlayRate(s.pose_m,1.0) end) -- The shot's own play takes over.
            s.pose_on=false
        elseif not s.zoom_held and s.pose_on then
            pcall(function() ai:Montage_Stop(0.2,s.pose_m) end)
            s.pose_on=false
        end
    end

    -- Firing mode (Luke's aim on her normal stance): the game itself keeps her facing the camera, through her
    -- movement's own settings (no yaw written from Lua each frame: two writers made her legs twitch, 00:27).
    local function face(p,on)
        local cm=g.try(function() return p.CharacterMovement end)
        if not g.valid(cm) then return end
        if on and not s.facing then
            s.facing={cm=cm,orient=cm.bOrientRotationToMovement,desired=cm.bUseControllerDesiredRotation}
            pcall(function() cm.bOrientRotationToMovement=false; cm.bUseControllerDesiredRotation=true end)
        elseif not on and s.facing then
            local f=s.facing
            pcall(function() f.cm.bOrientRotationToMovement=f.orient; f.cm.bUseControllerDesiredRotation=f.desired end)
            s.facing=nil
        end
    end

    -- Firing mode on the game's aim: its camera's field of view eased to cfg.aim_fov (the game's 45 shows her from the
    -- chest up), held by the camera manager's FOV lock and unlocked (0) when the aim ends.
    local function fov(pc,aiming)
        if aiming then
            local cm=g.try(function() return pc.PlayerCameraManager end)
            if not s.fov then s.fov=g.try(function() return cm:GetFOVAngle() end) or cfg.aim_fov end
            s.fov=GunMode.ease(s.fov,cfg.aim_fov,cfg.fov_ease)
            if pcall(function() pc:FOV(s.fov) end) then s.fov_locked=true end
        elseif s.fov_locked or s.fov then
            pcall(function() pc:FOV(0) end)
            s.fov_locked,s.fov=false,nil
        end
    end

    local function disable(why)
        if not s.on then return end
        s.on=false
        pcall(stance.stop)
        if s.mask then pcall(s.mask); s.mask=nil end
        camera_back()
        if s.facing then
            local f=s.facing
            pcall(function() f.cm.bOrientRotationToMovement=f.orient; f.cm.bUseControllerDesiredRotation=f.desired end)
            s.facing=nil
        end
        show_others()
        show_drone()
        pcall(ammo.stop)
        local pc=g.pc()
        if pc then pcall(fov,pc,false) end
        if s.native_taken then pcall(data.put_back); s.native_taken=false; aim.row=nil end
        g.log('off ('..why..'), '..s.shots..' shots')
    end

    local function enable(why)
        local pc,p=g.pc(),g.pawn()
        if not (pc and p) then g.log('not now: no EVE'); return end
        if g.try(function() return p.TPSModeType~=0 or p.bTPSMode end) then
            g.log('not now: release the drone aim first'); return
        end
        if not data.take() then g.log('off: SB\'s rows could not be taken (see above)'); return end
        aim.setup()
        local ok,err=pcall(function() s.mask=mask() end)
        if not ok then g.log('off: the input mask failed ('..tostring(err)..')'); return end
        ok,err=pcall(function()
            s.rifle=stance.start(pc,function() return s.zoom_held end,function() return s.target end,
                function() return s.air_aim==true end,
                0,false,false,set.native and set.upper,set.native and not set.upper)
        end)
        if not ok then
            if s.mask then pcall(s.mask); s.mask=nil end
            pcall(stance.stop)
            g.log('off: Luke\'s stance did not start ('..tostring(err)..')')
            return
        end
        s.on,s.shots,s.next_shot,s.zoom_held,s.held_since=true,0,0,false,nil
        pcall(hide_others,p,true)
        s.hide_at=os.clock()
        if set.native then pcall(hide_drone,p); s.native_taken=true end
        pcall(ammo.sync)
        g.log('on ('..why..')')
    end

    function self.toggle(why)
        local now=os.clock()
        if now-s.toggle_at<0.3 then return end
        s.toggle_at=now
        if s.on then disable(why) else enable(why) end
    end

    -- Each shot: the bullet's destination made the crosshair point, then the shot's row.
    local function shoot(p,now)
        if now<s.next_shot then return end
        s.next_shot=now+cfg.fire_interval
        aim.write(p,s.target)
        if fire_row(Data.row('Fire')) then
            s.shots=s.shots+1
            if s.shots<=3 or s.shots%50==0 then
                local l,r,t,e=s.cam_loc,s.cam_rot,s.target,g.try(function() return p:K2_GetActorLocation() end)
                local function v(a) return a and ('(%.0f, %.0f, %.0f)'):format(a.X,a.Y,a.Z) or '?' end
                g.log(('shot #%d: camera %s pitch %.1f yaw %.1f, target %s, EVE %s%s'):format(s.shots,v(l),
                    r and r.Pitch or 0,r and r.Yaw or 0,v(t),v(e),s.zoom_held and ', zoomed' or ''))
            end
        end
    end

    local function tick()
        local now=os.clock()
        if now<s.pause then return end
        if s.give_back then s.give_back=false; pcall(data.put_back); aim.row=nil end
        if s.stop_stance then s.stop_stance=false; pcall(stance.stop) end
        if s.show_back then s.show_back=false; show_others() end
        if s.ammo_reset then s.ammo_reset=false; pcall(ammo.stop); pcall(ammo.refill) end
        local pc=g.pc(); if not pc then return end
        if g.try(function() return StaticFindObject('/Script/Engine.Default__GameplayStatics'):IsGamePaused(pc) end) then
            return
        end
        local function down(name) return g.try(function() return pc:IsInputKeyDown({KeyName=FName(name)}) end)==true end
        local inp=Input.read(keys,down,now,cfg,set.key)
        if inp.key then self.toggle(set.key) elseif inp.toggle then self.toggle('D-pad Right') end
        if not s.on then return end
        local p=g.pawn()
        if not p then disable('no EVE'); return end
        if set.native then -- Firing mode is the game's own aim: held while EVE is in it.
            -- Firing mode: the game's aim, or a jump out of it with the aim key still held (the game drops its aim
            -- stance in the air and takes it up again only at a new press): from the jump until the key is let go the
            -- rifle stays up and gun mode fires the NIKKE shot itself (shoot), on the ground again too.
            local tps=g.try(function() return p.bTPSMode end)==true
            if tps then s.aim_seen=now end
            local key_held=down(set.aim_key) or down('Gamepad_LeftTrigger')
            local falling=g.try(function() return p.CharacterMovement:IsFalling() end)==true
            s.air_aim=not tps and key_held and s.aim_seen~=nil and (s.air_aim or (falling and now-s.aim_seen<1))
            s.zoom_held=tps or s.air_aim
            if now-(s.probe_at or 0)>=1.0 then
                s.probe_at=now
                local function rd(f) local ok,v=pcall(f); return ok and tostring(v) or '?' end
                local cam=''
                pcall(function()
                    local b=p.CameraBoom
                    local cm=pc.PlayerCameraManager
                    local cl,el=cm:GetCameraLocation(),p:K2_GetActorLocation()
                    local d=math.sqrt((cl.X-el.X)^2+(cl.Y-el.Y)^2+(cl.Z-el.Z)^2)
                    cam=(' cam: arm %.0f socket (%.0f,%.0f,%.0f) target (%.0f,%.0f,%.0f) custom (%.0f,%.0f,%.0f) dist %.0f fov %.0f')
                        :format(b.TargetArmLength,b.SocketOffset.X,b.SocketOffset.Y,b.SocketOffset.Z,b.TargetOffset.X,
                        b.TargetOffset.Y,b.TargetOffset.Z,b.CustomOffset.X,b.CustomOffset.Y,b.CustomOffset.Z,d,
                        cm:GetFOVAngle())
                end)
                local line=('native: aim %s mode %s stance %s bullet %s fire %s'..cam):format(rd(function() return p.bTPSMode end),
                    rd(function() return p.TPSModeType end),rd(function() return p:GetCurrentStanceName():ToString() end),
                    rd(function() return p.CurrentBulletItemAlias:ToString() end),tostring(inp.fire))
                if line~=s.probe_last then s.probe_last=line; g.log(line) end
            end
            pcall(fov,pc,s.zoom_held)
            -- Jumping in firing mode: the game's aim takes no jump input, so a press of the jump key (Space / pad A)
            -- makes her jump (her movement's jump speed, launched); the aim stance stays through the jump (gunmode/data.lua).
            local jump=down('SpaceBar') or down('Gamepad_FaceButton_Bottom')
            if jump and not s.jump_down and s.zoom_held then
                -- SB's movement refuses ACharacter::Jump in its aim: the jump's own launch instead, on the ground only.
                local ok,err=pcall(function()
                    local cm=p.CharacterMovement
                    if cm:IsFalling() then return end
                    local z=cm.JumpZVelocity
                    if not z or z<=0 then z=700 end
                    p:LaunchCharacter({X=0,Y=0,Z=z},false,true)
                end)
                if not s.jump_logged then s.jump_logged=true; g.log('jump in the aim: '..(ok and 'done' or tostring(err))) end
            end
            s.jump_down=jump
            if s.sounds then
                for i=#s.sounds,1,-1 do
                    if now>=s.sounds[i].at then sound(s.sounds[i].path); table.remove(s.sounds,i) end
                end
            end
            if s.air_aim and inp.fire and ammo.left>0 and not ammo.reload_until then pcall(shoot,p,now) end
            local ok_a,err_a=pcall(ammo.tick,s.zoom_held,inp.fire,now)
            if not ok_a and not s.ammo_err then s.ammo_err=true; g.log('ammo: '..tostring(err_a)) end
            if probe then pcall(probe.tick,pc,p,s.zoom_held,inp.fire,now) end
        elseif set.zoom_toggle then
            if inp.zoom_press then s.zoom_held=not s.zoom_held end
        else s.zoom_held=inp.zoom end
        s.target=crosshair(pc,p)
        local ok,err=pcall(stance.frame)
        if not ok then g.log('stance: '..tostring(err)); disable('stance error'); return end
        if not stance.running() then disable('the stance stopped'); return end
        if not set.native then camera(p) end
        if now-s.hide_at>=1.0 then
            s.hide_at=now
            pcall(hide_others,p,false)
            if set.native then pcall(hide_drone,p) end
        end
        if set.native and set.upper then pcall(hold_pose,p,inp.fire) end
        -- In firing mode, ten times a second: the NIKKE bullet's start put on the rifle's muzzle and its destination
        -- on the crosshair point (each shot writes the destination again).
        if s.zoom_held and now-(s.aim_w or 0)>=0.1 then
            s.aim_w=now
            local m=g.valid(s.rifle) and g.try(function() return s.rifle:GetSocketLocation(FName('FX_Fire')) end)
            aim.write_start(p,m or nil,cfg.start_min_forward,cfg.start_fallback)
            aim.write(p,s.target)
        end
        if not set.native then face(p,s.zoom_held) end
        -- Firing mode: fire once the rifle has had a moment to come up (Luke's raise eases in over ~12 frames).
        if s.zoom_held then s.held_since=s.held_since or now else s.held_since=nil end
        if not set.native and inp.fire and s.held_since and now-s.held_since>=cfg.raise_time then shoot(p,now) end
    end

    function self.hook()
        if s.hooked then return true end
        local function guarded(f)
            local ok,e=pcall(f)
            if not ok and s.errors<5 then s.errors=s.errors+1; g.log('error: '..tostring(e)) end
        end
        s.hooked=pcall(function() LoopInGameThreadWithDelay(1,function() guarded(tick) end) end)
        return s.hooked
    end

    -- The new-controller reset and the loop. Nothing at all with gun_mode=off.
    function self.start()
        for _,why in ipairs(bad) do g.log('coop-settings.txt: '..why) end
        if not set.on then g.log('off (gun_mode=off in coop-settings.txt)'); return end
        -- A new controller (map load, death, camp warp): the rifle goes away and SB's rows go back. Nothing here calls
        -- into the game: the controller is still being built (reading its pawn from this callback crashed UE4SS).
        NotifyOnNewObject('/Script/SB.SBPlayerController',function(pc)
            cached=pc
            s.pause=os.clock()+4.0
            s.give_back=true
            if s.on then
                s.on=false
                if s.mask then pcall(s.mask); s.mask=nil end
                s.cam,s.zoom=nil,0
                s.fov,s.fov_locked=nil,false
                s.ammo_reset=true
                s.stop_stance=true
                s.show_back=true
            end
        end)
        if not self.hook() then g.log('off: this UE4SS has no LoopInGameThreadWithDelay'); return end
        g.log('ready: '..set.key..' or a tap of D-pad Right')
    end

    function self.status()
        return ('gun mode %s%s, key %s, %d shots'):format(s.on and 'on' or 'off',
            s.on and (s.zoom_held and ' (firing mode)' or ' (moving)') or '',set.key,s.shots)
    end
    self.toggle_now=function() self.toggle('command') end
    self.state=s
    return self
end

return GunMode
