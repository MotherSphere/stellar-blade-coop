-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode: the NIKKE DLC's rifle in EVE's hands on any save, on luke77's rifle stance. G (gun_key) or a tap of
-- D-pad Right brings the rifle out or puts it away. Out, EVE runs and jumps as Luke's stance has her (fight/gunmode/
-- stance.lua: her own animation, the rifle at her chest). Holding RMB / LT is firing mode: the camera comes in over her
-- right shoulder, she turns to the camera and brings the rifle up with its laser sight on. LMB / RT fires full
-- auto at the point under the screen centre. Letting go goes back to Luke's movement. Logged as [StellarCoop][GM].
-- How: each shot is the NIKKE shot skill, started by a zone event through SB's own rows (fight/gunmode/data.lua), its
-- bullet sent to the crosshair's point (fight/gunmode/aim.lua). While the rifle is out the sword's attacks and the drone's
-- aim on the fire and zoom keys are masked in memory (never saved; put back when it goes away).
-- Gun mode is a module of its own: it reads its own coop-settings.txt lines and uses nothing of the rest of the mod;
-- fight/gunmode/wiring.lua builds and starts it. All of it runs on the game thread, from main/frame.lua's
-- LoopInGameThreadWithDelay loop (every frame): no LoopAsync, ExecuteWithDelay or key bind, whose callbacks run Lua on
-- another thread (two threads in one Lua state crashed UE4SS, 11-17). Every step is wrapped, so an error in gun mode
-- never reaches the rest of the mod.
local Config=require('fight.gunmode.config')
local Aim=require('fight.gunmode.aim')
local Input=require('fight.gunmode.input')
local Stance=require('fight.gunmode.stance')
local Rifle=require('fight.gunmode.rifle')
local Laser=require('fight.gunmode.laser')
local Data=require('fight.gunmode.data')
local Probe=require('fight.gunmode.probe')
local Ammo=require('fight.gunmode.ammo')
local Dpad=require('fight.gunmode.ui.dpad')
local Overlay=require('fight.gunmode.overlay')
local Morph=require('fight.gunmode.morph')

local GunMode={}

-- Zone event kind 2 is ZoneEvent_AttachActorEffect (ESBZoneEventType's names at 0x145e29b00 on 26123051). RunEvent
-- (0x141ca5a10) hands it to 0x141c9e690, which applies the row's actor effect; no chain of direct calls from it reaches
-- RunEvent, RunZoneEvent (0x141ca5790) or StartMatchMaking (0x141ca3ea0, RunEvent's kind 15). Kinds 16 and 19 stop
-- matchmaking or go back to single play. The only zone event gun mode fires: kind 2 on the shot's row
-- (Data.row('Fire'), read at the call).
local U=require('core.unreal')
local ATTACH_ACTOR_EFFECT=2
function GunMode.allowed(kind,name) return kind==ATTACH_ACTOR_EFFECT and name~=nil and name==Data.row('Fire') end
local function find_name(t) return FName(t,EFindName.FNAME_Find) end -- None (index 0) when not a name yet.
local function zone_event(kind,name)
    assert(GunMode.allowed(kind,name),'zone event refused')
    U.find('/Script/SB.Default__SBBlueprintLibrary'):CreateSBZoneEvent(kind,find_name(name))
end

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

-- The layer's clip: the reload; else aim while the aim key or fire is held (hip fire raises the rifle first); else
-- carry. One of the game's moves on the ground keeps the rifle carried. In the air (the double-jump flip) the aim stays.
-- The aim clip by the rifle's pitch (s.rpitch, deg): AimUp45's head and shoulders past +up, AimDown45's past -up, back to
-- AimLevel inside +-back (hysteresis, so the clip does not flicker at the edge). was: the last aim clip.
function GunMode.aim_clip(was,pitch,up,back)
    pitch=pitch or 0
    if pitch>=up then return 'aimup' end
    if pitch<=-up then return 'aimdown' end
    if was=='aimup' and pitch>back then return 'aimup' end
    if was=='aimdown' and pitch<-back then return 'aimdown' end
    return 'aim'
end

-- The recoil envelope: 1 at the round, easing out with time constant decay; 0 once it is small (dt nil: no round yet).
function GunMode.kick(dt,decay)
    if not dt or dt<0 then return 0 end
    local k=math.exp(-dt/decay); return k>0.02 and k or 0
end

-- The chest turn c eased back toward 0 by AR.decay (fight/gunmode/aimrot.lua). Under 0.001 degrees in all it snaps to 0.
-- A zero turn is given back as it is: no new table each frame out of aim.
function GunMode.decay(AR,c)
    if c.Pitch==0 and c.Yaw==0 and c.Roll==0 then return c end
    if math.abs(c.Pitch)+math.abs(c.Yaw)+math.abs(c.Roll)<1e-3 then return {Pitch=0,Yaw=0,Roll=0} end
    return AR.decay(c,0.15)
end

-- The hip-fire body turn with hysteresis: on past on_deg of chest yaw, off inside off_deg.
function GunMode.turn(was,yaw,on_deg,off_deg)
    yaw=math.abs(yaw or 0)
    if yaw>=on_deg then return true end
    if yaw<=off_deg then return false end
    return was==true
end

-- Back after an interaction (a camp seat, a rest, a door): once she has been free for settle seconds.
function GunMode.resume_due(free_at,now,settle) return free_at~=nil and now-free_at>=settle end

function GunMode.want(reload,zoom,fire,move,falling)
    if reload then return 'reload' end
    if move and not falling then return 'carry' end
    return (zoom or fire) and 'aim' or 'carry'
end

-- env: {log, folder (the mod folder: coop-settings.txt), read_all (a file's text; io.open's unless given)}.
function GunMode.new(env)
    local cfg=Config.DEFAULTS
    local whole=env.read_all or read_all
    local set,bad=Config.parse(env.folder and whole(env.folder..'\\coop-settings.txt'))
    local spread=set.spread or cfg.spread -- degrees around the reticle point (gun_spread)
    local g={}
    function g.log(m) env.log(m) end
    -- ui/text.lua's gun words in the player's language (env.words), English without one.
    function g.words() return (env.words and env.words() or require('ui.text').en).gun end
    local function is_valid(o) return o:IsValid() end
    local function get_field(o,k) return o[k] end
    function g.valid(o)
        if o==nil then return false end
        local ok,r=pcall(is_valid,o)
        return ok and r==true
    end
    function g.try(fn) local ok,r=pcall(fn); if ok then return r end end
    function g.get(o,k) local ok,r=pcall(get_field,o,k); if ok then return r end end -- a property read without a closure
    local cached -- The controller: FindFirstOf walks the whole object array.
    local cdos={}
    -- a class default object ('/Script/...Default__X') found once: they live as long as the game
    function g.cdo(path) local o=cdos[path]; if not o then o=StaticFindObject(path); cdos[path]=o end; return o end
    function g.pc()
        if g.valid(cached) then return cached end
        local pc=FindFirstOf('SBPlayerController')
        if g.valid(pc) then cached=pc; return pc end
    end
    function g.pawn()
        local pc=g.pc(); if not pc then return nil end
        local p=g.get(pc,'Pawn')
        if g.valid(p) then return p end
    end
    if set.fire_key then Input.FIRE[#Input.FIRE+1]=set.fire_key end
    local aim,data=Aim.new(g),Data.new(g,set.native,{speed=cfg.native_speed,upper=set.upper and 'P_Eve_GunNikke' or nil,cool=cfg.fire_interval,bs=set.bs})
    -- The rifle: with the animation pak, fight/gunmode/rifle.lua (the rifle in her real hand; the pak's rifle animations play on
    -- her real body); without it, Luke's posed stance (fight/gunmode/stance.lua).
    local posed=Stance.new(Laser,set.trace and g.log or nil)
    local single=Rifle.new(Laser,set.trace and g.log or nil)
    local stance=posed
    local probe=set.probe and Probe.new(g)
    -- M1 (11-18 rebuild): the post-process layer (fight/gunmode/overlay.lua, ABP in gunmode's pak) plays the NIKKE rifle clips
    -- on her arms over her own finished pose; nothing of her main animation, springs or outfit physics is touched.
    local layer=Overlay.new(g)
    local keys=Input.state()
    local self={}
    local s={hidden={},followed={},on=false,pause=0,next_shot=0,shots=0,zoom=0,zoom_held=false,target=nil,cam=nil,mask=nil,
        toggle_at=-1,hooked=false,errors=0}

    -- The reload: the NIKKE squad's reload animation on the rifle stance, with its sounds at their times.
    local function sound(path)
        local ok,err=pcall(function()
            local cue=LoadAsset(path)
            assert(cue,'no '..path)
            StaticFindObject('/Script/Engine.Default__GameplayStatics'):PlaySound2D(g.pawn(),cue,1.0,1.0,0.0,nil,nil,false)
        end)
        if not s.sound_logged then s.sound_logged=true; g.log('reload sound: '..(ok and 'played' or tostring(err))) end
    end
    local function on_reload(on,duration)
        local ok=stance.reload(on and not s.layer,duration) -- with the layer the real reload clip plays: no extra tilt of the rifle in her hand
        if s.layer then
            s.reload_until=on and os.clock()+((duration and duration>0) and duration or 1) or nil
            s.reload_len=(duration and duration>0) and duration or 1
            s.layer_clip=nil
            ok=true
        end
        if on then
            s.sounds={}
            local now=os.clock()
            for _,e in ipairs(cfg.reload_sounds) do s.sounds[#s.sounds+1]={at=now+e[2]*duration,path=e[1]} end
            if not s.reload_logged then s.reload_logged=true; g.log('reload animation: '..(ok and 'playing' or 'not found')) end
        else s.sounds=nil end
    end
    -- No D-pad slot widget for now: the runtime widget never drew. As nothing held it, the engine could free it
    -- while its text was still being set every frame (a likely cause of the crashes in one play session).
    local ammo=Ammo.new(g,cfg,function(v) data.cool(v) end,on_reload,nil)

    local function fire_row(row)
        local ok,err=pcall(zone_event,ATTACH_ACTOR_EFFECT,row)
        if not ok then g.log('row '..row..' failed: '..tostring(err)) end
        return ok
    end

    -- The input mask, as Luke's maskAim makes it: cfg.mask_on_keys on cfg.mask_keys plus cfg.mask_actions on any key,
    -- set to key None and the keymaps rebuilt; restore() puts each one back. Axis mappings on those keys are only
    -- logged (the first time) so a later build can mask them if the game reads one.
    local function mask()
        local settings=StaticFindObject(SETTINGS)
        assert(g.valid(settings),'input settings unavailable')
        local masked_key,on_keys,masked_name={},{},{}
        local reload_key={} -- every action on these keys is masked while the rifle is out (they reload it)
        for _,k in ipairs(cfg.reload_keys or {}) do reload_key[k]=true end
        for _,k in ipairs(cfg.mask_keys) do masked_key[k]=true end
        for _,n in ipairs(set.native and cfg.native_mask_on_keys or cfg.mask_on_keys) do on_keys[n]=true end
        if not set.native then for _,n in ipairs(cfg.mask_actions) do masked_name[n]=true end end
        local saved,names={},{}
        settings.ActionMappings:ForEach(function(_,wrapped)
            local row=wrapped:get()
            local name,key=row.ActionName:ToString(),row.Key.KeyName:ToString()
            if key~='None' and ((masked_key[key] and on_keys[name]) or masked_name[name] or reload_key[key]) then
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
            local ph={} -- the photo mode's own keys (log only; the photo-mode freeze below is tested with them)
            pcall(function() settings.ActionMappings:ForEach(function(_,wrapped)
                local row=wrapped:get(); local name=row.ActionName:ToString()
                if name:lower():find('photo') then ph[#ph+1]=name..'('..row.Key.KeyName:ToString()..')' end
            end) end)
            g.log('input: photo mode actions: '..(#ph>0 and table.concat(ph,' ') or 'none'))
            -- every keyboard key the game binds (actions and axes), so the rifle's own keys can avoid them
            local used={}
            local function add(row) local k=row.Key.KeyName:ToString(); if not k:find('Gamepad',1,true) and not k:find('Mouse',1,true) and k~='None' then used[k]=true end end
            pcall(function() settings.ActionMappings:ForEach(function(_,w) add(w:get()) end) end)
            pcall(function() settings.AxisMappings:ForEach(function(_,w) add(w:get()) end) end)
            local list={}; for k in pairs(used) do list[#list+1]=k end; table.sort(list)
            g.log('input: keyboard keys bound: '..table.concat(list,' '))
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
    local FX_FIRE -- the rifle's muzzle socket, FName('FX_Fire'), made once
    local function fx_fire() FX_FIRE=FX_FIRE or FName('FX_Fire'); return FX_FIRE end
    local CLEAR,IGN={R=0,G=0,B=0,A=0},{}
    local function trace_one(trace,p,from,to,channel,hit)
        return trace:LineTraceSingle(p,from,to,channel,false,IGN,0,hit,true,CLEAR,CLEAR,0)
    end
    local function crosshair(pc,p)
        local cm=g.get(pc,'PlayerCameraManager')
        if not g.valid(cm) then s.cam_loc,s.cam_rot=nil,nil; return nil end -- (the chest loop reads the camera from here)
        local loc,rot=cm:GetCameraLocation(),cm:GetCameraRotation()
        s.cam_loc,s.cam_rot=loc,rot
        local from=loc -- GunMode.ahead(loc,rot,0) is loc
        local to=GunMode.ahead(loc,rot,cfg.trace_range)
        local trace=g.cdo(TRACE)
        if not g.valid(trace) then return to end
        IGN[1]=p
        local best,dist=to,cfg.trace_range
        for channel=0,1 do
            local hit={}
            local ok,blocked=pcall(trace_one,trace,p,from,to,channel,hit)
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
        -- Her normal camera ignores CustomOffset: its arm length (the game sets it, so taken again whenever
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
    -- her body's mesh) or the sword drawn in a fight showed as a ghost doing the real animation. Looked for
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
            -- each component is looked at once (a second pass every second cost ~50 engine calls: a stutter)
            if addr and not s.hidden[addr] and not (s.checked or {})[addr] and c~=src and not stance.owns(c) then
                s.checked=s.checked or {}; s.checked[addr]=true
                local mesh
                if g.valid(skel) and g.try(function() return c:IsA(skel) end) then
                    mesh=g.try(function() return c.SkeletalMesh:GetFullName() end)
                elseif g.valid(static) and g.try(function() return c:IsA(static) end) then
                    mesh=g.try(function() return c.StaticMesh:GetFullName() end)
                end
                local hide=mesh~=nil and mesh==body and not stance.single
                local short=mesh and mesh:match('[^%.]+$') -- The asset's own name: its path named the hairpin's folder.
                for _,n in ipairs(cfg.hide_names) do
                    if short and short:find(n,1,true) then hide=true end
                end
                local follow=false
                if not hide and short and g.valid(skel) and g.try(function() return c:IsA(skel) end) then
                    for _,n in ipairs(cfg.follow_names) do if short:find(n,1,true) then follow=true end end
                end
                local copy=false
                if not hide and not follow and short and g.valid(skel) and g.try(function() return c:IsA(skel) end) then
                    for _,n in ipairs(cfg.copy_names) do if short:find(n,1,true) then copy=true end end
                end
                if copy then
                    local ok,err=stance.copy(c)
                    if ok==false then g.log('hide: '..short..' not copied ('..tostring(err)..')') end
                end
                if follow and not s.followed[addr] then
                    local body=stance.body()
                    if g.valid(body) and pcall(function() c:SetMasterPoseComponent(body,true) end) then
                        s.followed[addr]={c=c}
                    end
                end
                if first then
                    seen[#seen+1]=(hide and '*' or follow and '+' or copy and '=' or '')..tostring(mesh and mesh:match('[^%.]+$'))
                        ..(g.try(function() return c:IsVisible() end)==false and '(invisible)' or '')
                        ..(g.try(function() return c.bOwnerNoSee end)==true and '(ownernosee)' or '')
                end
                if hide then
                    local was=g.try(function() return c.bOwnerNoSee end)
                    if pcall(function() c:SetOwnerNoSee(true) end) then s.hidden[addr]={c=c,was=was==true} end
                end
            end
        end
        if first then
            g.log('hide: her meshes (* hidden from her camera, + following the posed copy, = copied with it): '..table.concat(seen,' '))
        end
    end
    local function show_others()
        for _,e in pairs(s.hidden) do
            if g.valid(e.c) then pcall(function() e.c:SetOwnerNoSee(e.was) end) end
        end
        s.hidden={}; s.checked={}
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
        -- FindAllOf walks every object: with no drone near, look again only every 5 s (each look was a stutter)
        local t=os.clock(); if t-(s.drone_look or -99)<5 then return end; s.drone_look=t
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
        -- every scene component, not only its meshes: its light, glows and effects go with it (11-20: the light stayed)
        local cls=StaticFindObject('/Script/Engine.SceneComponent')
        local parts={}
        local list=g.try(function() return best:K2_GetComponentsByClass(cls) end)
        local function each(fn)
            if type(list)=='table' and rawget(list,'ForEach')==nil then for _,c in ipairs(list) do fn(c) end
            elseif list then pcall(function() list:ForEach(function(_,e) fn(e) end) end) end
        end
        each(function(c)
            if not g.valid(c) then local ok,v=pcall(function() return c:get() end); if ok then c=v end end
            if g.valid(c) then
                local was_hidden=g.try(function() return c.bHiddenInGame end)==true
                local was_visible=g.try(function() return c:IsVisible() end)~=false
                if (not was_hidden or was_visible) and pcall(function() c:SetHiddenInGame(true,false); c:SetVisibility(false,false) end) then
                    parts[#parts+1]={c=c,hidden=was_hidden,visible=was_visible}
                end
            end
        end)
        s.drone={actor=best,parts=parts}
        g.log('drone: '..#parts..' parts hidden ('..#all..' drones)')
    end
    local function show_drone()
        if s.drone then
            for _,e in ipairs(s.drone.parts) do
                local c=e.c
                if g.valid(c) then pcall(function() c:SetHiddenInGame(e.hidden,false); c:SetVisibility(e.visible,false) end) end
            end
        end
        s.drone=nil; s.drone_look=nil
    end

    -- Firing mode's pose between shots: the NIKKE shot's own animation (its montage, learnt from the first shot
    -- fired: it looked right while firing in game) held near its start while aim is held and no shot is playing, so
    -- she keeps the rifle up instead of the drone aim's pointing pose; stopped when aim is let go.
    local function hold_pose(p,firing)
        local ai=g.try(function() return p.Mesh:GetAnimInstance() end)
        if not g.valid(ai) then return end
        local cur=g.try(function() return ai:GetCurrentActiveMontage() end)
        local name=not s.pose_m and g.valid(cur) and g.try(function() return cur:GetFName():ToString() end) -- (read only until learnt)
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
    -- movement's own settings (no yaw written from Lua each frame: two writers made her legs twitch in game).
    local function face(p,on)
        if (on and s.facing) or (not on and not s.facing) then return end -- nothing to change: no reads
        local cm=g.get(p,'CharacterMovement')
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
    local function set_fov(pc,v) pc:FOV(v) end
    local function fov(pc,aiming)
        if aiming then
            if not s.fov then local cm=g.get(pc,'PlayerCameraManager'); s.fov=g.try(function() return cm:GetFOVAngle() end) or cfg.aim_fov end
            s.fov=GunMode.ease(s.fov,cfg.aim_fov,cfg.fov_ease)
            if pcall(set_fov,pc,s.fov) then s.fov_locked=true end
        elseif s.fov_locked or s.fov then
            pcall(function() pc:FOV(0) end)
            s.fov_locked,s.fov=false,nil
        end
    end

    -- The rifle carried: a custom moving stance with no force whose OverrideStanceAnim is the carry animation set
    -- (fight/gunmode/data.lua fills it); off while she aims, so the aim stance's own set plays.
    local function carry(p,on)
        if on and s.ovr_row and not s.ovr then
            s.ovr=pcall(function()
                p:ActiveCustomMovingStanceData({OverrideStanceAnim=FName(s.ovr_row),NormalAnimRangeDegree=180.0,ApplySpeedForIdleAnimScale=1.0})
            end)
        elseif not on and s.ovr then
            pcall(function() p:DeactiveCustomMovingStanceData() end)
            s.ovr=false
        end
    end

    -- The morph's black cube: an engine cube mesh in her right hand with the rifle's own (black metal) material, sized to
    -- cfg.cube_cm. Made when a morph starts, destroyed when it ends or gun mode goes off. A missing mesh logs once and the
    -- morph runs with the rifle's scale alone.
    local function cube_make(p)
        if g.valid(s.cube) then return s.cube end
        local ok,c=pcall(function()
            local mesh=StaticFindObject(cfg.cube_mesh) or (pcall(LoadAsset,cfg.cube_mesh) and StaticFindObject(cfg.cube_mesh))
            assert(g.valid(mesh),'no '..cfg.cube_mesh)
            local id={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
            local c=p:AddComponentByClass(StaticFindObject('/Script/Engine.StaticMeshComponent'),true,id,true)
            assert(g.valid(c),'cube component')
            c:SetCollisionEnabled(0)
            p:FinishAddComponent(c,true,id)
            c:SetStaticMesh(mesh)
            pcall(function() local bb=mesh:GetBoundingBox(); s.cube_size=math.max(1,bb.Max.X-bb.Min.X) end)
            c:K2_AttachToComponent(p.Mesh,FName('Bip001-R-Hand'),2,2,2,false)
            c:K2_SetRelativeTransform({Translation=cfg.cube_at,Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=0,Y=0,Z=0}},false,{},true)
            if g.valid(s.rifle) then local m=s.rifle:GetMaterial(0); if m then c:SetMaterial(0,m) end end
            return c
        end)
        if ok then s.cube=c; return c end
        if not s.cube_err then s.cube_err=true; g.log('morph: no cube ('..tostring(c)..'), the rifle scales alone') end
    end
    local function cube_drop()
        if g.valid(s.cube) then local c=s.cube; pcall(function() c:K2_DestroyComponent(c) end) end
        s.cube=nil
    end

    local function disable(why)
        if not s.on then return end
        s.morph=nil; cube_drop(); require('fight.gunmode.ik').fade=1
        if single.morph then pcall(single.morph,nil) end
        s.on=false
        pcall(stance.stop)
        if s.mask then pcall(s.mask); s.mask=nil end
        camera_back()
        if s.facing then
            local f=s.facing
            pcall(function() f.cm.bOrientRotationToMovement=f.orient; f.cm.bUseControllerDesiredRotation=f.desired end)
            s.facing=nil
        end
        local pw=g.pawn()
        if pw then carry(pw,false) end
        if s.layer and pw then pcall(layer.stop,pw); local ok,e=pcall(layer.uninstall,pw); if not ok then g.log('layer off: '..tostring(e)) end end
        if not pw then s.layer_back=s.layer or s.layer_back; s.mesh_back=(s.mesh_yaw or 0)~=0 and s.mesh_rot or nil end -- no pawn now: the loop puts these back
        if s.mesh_rot and pw then local b=s.mesh_rot; pcall(function() pw.Mesh:K2_SetRelativeRotation(b,false,{},false) end) end
        s.mesh_rot,s.mesh_yaw,s.head_yaw=nil,0,nil
        if s.cmod and g.valid(s.cmod) then local m=s.cmod; pcall(function() g.pc().PlayerCameraManager:RemoveCameraModifier(m) end) end
        s.cmod,s.cmod_fail=nil,nil
        s.layer,s.layer_clip,s.reload_until,s.turn,s.turnq,s.chest,s.move=false,nil,nil,nil,nil,nil,nil -- (no aim turn left for next time)
        s.ovr_row=nil
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
        -- The gun mode animation pak (zNGMSpike_P): when it is installed, the aim stance's blend spaces point at
        -- its firing-stance animations while the rifle is out. Her real body shows while aiming (nothing posed).
        local okl,inst,why_not=pcall(layer.install,p)
        s.layer=okl and inst==true
        g.log('rifle layer '..(s.layer and 'on' or ('not available: '..tostring(okl and why_not or inst))))
        pcall(ammo.refill) -- full magazines each time the rifle comes out (the shop sells the drone's rounds, not these)
        if s.layer then s.pak=false end
        if s.pak==nil then
            s.pak=g.try(function() return LoadAsset(cfg.pak_probe)~=nil end)==true
            g.log('animation pak '..(s.pak and 'found' or 'not installed: posed aim'))
        end
        data.opts.bs=set.bs or (s.pak and cfg.pak_bs or nil)
        data.opts.pak=s.pak and cfg.pak or nil
        data.opts.carry_ovr=s.pak and (set.carry_ovr or 'auto') or nil
        data.opts.carry_spare=set.carry_spare
        data.opts.carry_idle_type=set.carry_idle_type
        stance=(s.pak or s.layer) and single or posed
        single.no_turn=s.layer==true
        if not data.take() then
            if s.layer then pcall(layer.uninstall,p); s.layer=false end
            g.log('off: SB\'s rows could not be taken (see above)'); return
        end
        aim.setup()
        local ok,err=pcall(function() s.mask=mask() end)
        if not ok then g.log('off: the input mask failed ('..tostring(err)..')'); return end
        ok,err=pcall(function()
            -- Held for Luke's aim: the aim key itself, not the game's aim stance, which drops for a frame now and
            -- then (each shot's skill, a jump) and made his arms jerk between carry and aim. Off the stance (a
            -- jump, a camp) his own turn to the camera keeps her facing the shot.
            -- With the animation pak her real body is shown while aiming, so held follows the game's aim stance
            -- (bridging its one-frame drops on shots: seen in the last 0.4 s with the key still down).
            if stance.single then
                -- with the layer the laser follows the aim pose (aiming or hip fire); in the flip it runs along the bore
                s.rifle=stance.start(pc,function()
                        if s.layer then return s.want=='aim' end
                        return s.zoom_held or (s.key_held==true and s.aim_seen~=nil and os.clock()-s.aim_seen<0.4) end,
                    function() if not s.flip then return s.target end end)
                return
            end
            s.rifle=stance.start(pc,function()
                    if s.pak then return s.zoom_held or (s.key_held==true and s.aim_seen~=nil and os.clock()-s.aim_seen<0.4) end
                    return s.zoom_held or (s.on and s.key_held==true) end,function() return s.target end,
                function() return s.air_aim==true or (s.key_held==true and not s.tps) end,
                -- With the animation pak her body under the posed copy is the pak's rifle stance (upright, strafing),
                -- so Luke's own aim runs on it unchanged: his arms from her chest, turned to the camera, the rifle
                -- squared on the camera's line (the user's call: Luke's aim is the look to keep).
                0,false,false,set.native and (set.upper or s.pak),set.native and not set.upper and not s.pak)
        end)
        if not ok then
            if s.mask then pcall(s.mask); s.mask=nil end
            pcall(stance.stop)
            if s.layer then pcall(layer.uninstall,p); s.layer=false end
            g.log('off: Luke\'s stance did not start ('..tostring(err)..')')
            return
        end
        if set.trace and not s.funcs_logged then -- (testing) the pawn's and its anim instance's stance / anim set functions
            s.funcs_logged=true
            pcall(function()
                local function scan(obj,label)
                    local names={}
                    local cls=obj:GetClass()
                    local depth=0
                    while cls and cls:IsValid() and depth<8 do
                        pcall(function() cls:ForEachFunction(function(f)
                            local n=f:GetFName():ToString()
                            local l=n:lower()
                            if l:find('stance') or l:find('animset') or l:find('anim_set') or l:find('refresh') then names[#names+1]=n end
                        end) end)
                        cls=cls:GetSuperStruct(); depth=depth+1
                    end
                    g.log('funcs '..label..': '..table.concat(names,' '))
                end
                scan(p,'pawn')
                local function params(fname)
                    local cls=p:GetClass(); local f
                    local depth=0
                    while cls and cls:IsValid() and depth<8 and not f do
                        pcall(function() cls:ForEachFunction(function(fn) if fn:GetFName():ToString()==fname then f=fn end end) end)
                        cls=cls:GetSuperStruct(); depth=depth+1
                    end
                    if not f then g.log('params '..fname..': not found'); return end
                    local out={}
                    pcall(function() f:ForEachProperty(function(pr)
                        local t=g.try(function() return pr:GetClass():GetFName():ToString() end) or '?'
                        local extra=''
                        pcall(function() local st=pr:GetStruct(); if st then extra=' '..st:GetFName():ToString() end end)
                        out[#out+1]=pr:GetFName():ToString()..':'..t..extra
                    end) end)
                    g.log('params '..fname..': '..table.concat(out,', '))
                    return f
                end
                params('ActiveCustomMovingStanceData'); params('DeactiveCustomMovingStanceData'); params('IsActiveCustomMovingStanceData')
                -- the struct's fields
                pcall(function()
                    local st
                    for _,n in ipairs({'/Script/SB.SBCharMovingStanceData','/Script/SB.SBCharacterMovingStanceData'}) do
                        local o=StaticFindObject(n); if o and o:IsValid() then st=st or o end
                    end
                    if st and st:IsValid() then
                        local out={}
                        local function walk(stt,pre,d)
                            stt:ForEachProperty(function(pr)
                                local t=g.try(function() return pr:GetClass():GetFName():ToString() end) or '?'
                                local inner
                                pcall(function() inner=pr:GetStruct() end)
                                local iname=inner and (g.try(function() return inner:GetFName():ToString() end) or '') or ''
                                out[#out+1]=pre..pr:GetFName():ToString()..':'..t..(iname~='' and ('<'..iname..'>') or '')
                                if inner and d<2 then pcall(walk,inner,pre..pr:GetFName():ToString()..'.',d+1) end
                            end)
                        end
                        walk(st,'',0)
                        g.log('struct '..st:GetFullName()..': '..table.concat(out,', '))
                    else g.log('struct: not found by guessed names') end
                end)
                local ai=g.try(function() return p.Mesh:GetAnimInstance() end)
                if ai then scan(ai,'anim') end
            end)
        end
        local co=data.opts.carry_ovr
        s.ovr_row=(co=='auto' and data.carry_ovr_row) or (co and co~='auto' and co~='off' and co) or nil
        if s.ovr_row then
            carry(p,true)
            g.log('carry override '..s.ovr_row..': '..(s.ovr and 'on' or 'failed')..', active='..tostring(g.try(function() return p:IsActiveCustomMovingStanceData() end)))
        end
        s.on,s.shots,s.next_shot,s.zoom_held,s.held_since=true,0,0,false,nil
        pcall(hide_others,p,true)
        s.hide_at=os.clock()
        if set.native then s.native_taken=true end
        if cfg.hide_drone~=false then pcall(hide_drone,p) end -- (the game's aim puts the drone on her arm: hidden, light and all)
        pcall(ammo.sync)
        -- the arrival: a cube in her hand turns into the rifle (fight/gunmode/morph.lua); the tick runs it
        if cfg.morph~=false and s.layer then s.morph={dir='in',t0=os.clock()}; pcall(cube_make,p); pcall(single.morph,0,0) end
        if set.trace then pcall(function() require('fight.gunmode.ui.dpad').new(g).dump() end)
            -- (dev) loaded key and pad icon textures (the HUD entry's gamepad and keyboard glyphs)
            -- plus cube mesh candidates
            pcall(function()
                local hits={}
                for _,t in ipairs(FindAllOf('Texture2D') or {}) do
                    local n=t:GetFullName()
                    if (n:find('KeyIcon',1,true) or n:find('Dpad',1,true) or n:find('DPad',1,true) or n:find('Pad_',1,true)) and #hits<120 then hits[#hits+1]=n:match('[^/]+$') end
                end
                g.log('hud textures: '..#hits..': '..table.concat(hits,' | '))
            end)
            for _,c in ipairs({'/Engine/BasicShapes/Cube.Cube','/Engine/EngineMeshes/Cube.Cube','/Engine/EditorMeshes/EditorCube.EditorCube',
                '/Engine/VREditor/BasicMeshes/SM_Cube_01.SM_Cube_01','/Engine/EngineMeshes/SM_MatPreviewMesh_02.SM_MatPreviewMesh_02',
                '/Engine/EditorMeshes/MatineeCam_SM.MatineeCam_SM','/Engine/EngineMeshes/BaseCube.BaseCube'}) do
                local ok=pcall(LoadAsset,c); local o=StaticFindObject(c)
                g.log('morph mesh '..c..': '..((o and o:IsValid()) and 'found' or 'missing'))
            end
        end
        g.log('on ('..why..')')
    end

    -- (test harness) this instance off for good: gun mode put away, its loop idle; a fresh one takes over.
    function self.kill()
        if s.on then pcall(self.toggle,'reload') end
        s.dead=true
    end

    function self.toggle(why)
        local now=os.clock()
        if now-s.toggle_at<0.3 then return end
        s.toggle_at=now
        s.resume,s.free_at=false,nil -- (a press wins over the comeback after an interaction)
        -- Parked while it is rebuilt: the toggle says so on screen and nothing else of gun mode runs (no rows taken,
        -- no rifle, no posed copy).
        if cfg.enabled==false and not Overlay.available() then
            if s.on then disable(why) end
            g.log('toggle ('..why..'): gun mode is being rebuilt, off')
            if not s.notice_off then
                if env.notice and pcall(env.notice,'rebuilding') then s.notice_off,s.notice_at=function() end,now end
            end
            return
        end
        if s.on then
            -- a press (key, D-pad, command) plays the departure first; anything else (reload, faults) goes at once
            local press=why==set.key or why=='D-pad Right' or why=='command'
            if press and cfg.morph~=false and s.layer then
                if not (s.morph and s.morph.dir=='out') then
                    s.morph={dir='out',t0=now,why=why}; local p=g.pawn(); if p then pcall(cube_make,p) end
                end
                return
            end
            disable(why)
        else enable(why) end
    end

    -- Each shot: the bullet's start on the muzzle and its destination on the crosshair point, then the shot's row.
    -- Only in the double-jump flip it goes along the bore, where the laser points.
    local function shoot(p,now)
        if now<s.next_shot then return end
        s.next_shot=now+cfg.fire_interval
        s.shot_at=now
        -- The round's destination: the reticle point moved at random within the spread. The flip's goes along the bore.
        local tgt=s.flip and s.target or Aim.spread(s.target,s.cam_loc,spread,math.random(),math.random())
        local mz0=g.valid(s.rifle) and g.try(function() return s.rifle:GetSocketLocation(fx_fire()) end)
        aim.write_start(p,mz0 or nil,cfg.start_min_forward,cfg.start_fallback)
        if s.flip and g.valid(s.rifle) then
            pcall(function()
                local ml=g.cdo('/Script/Engine.Default__KismetMathLibrary')
                local mz=s.rifle:GetSocketLocation(fx_fire())
                local f=ml:GetForwardVector(s.rifle:GetSocketRotation(fx_fire()))
                tgt={X=mz.X+f.X*3000,Y=mz.Y+f.Y*3000,Z=mz.Z+f.Z*3000}
            end)
        end
        aim.write(p,tgt)
        if fire_row(Data.row('Fire')) then
            s.shots=s.shots+1
            pcall(ammo.spend,now)
            if s.shots<=3 or s.shots%50==0 then
                local l,r,t,e=s.cam_loc,s.cam_rot,s.target,g.try(function() return p:K2_GetActorLocation() end)
                local function v(a) return a and ('(%.0f, %.0f, %.0f)'):format(a.X,a.Y,a.Z) or '?' end
                g.log(('shot #%d: camera %s pitch %.1f yaw %.1f, target %s, EVE %s%s'):format(s.shots,v(l),
                    r and r.Pitch or 0,r and r.Yaw or 0,v(t),v(e),s.zoom_held and ', zoomed' or ''))
            end
        end
    end

    -- A key's down state: one IsInputKeyDown a key a frame; the key's table and its FName are made once (less garbage)
    local KEYS,dn_t,dn_v,dn_pc,dn_frame={},{},{},nil,0
    local function key_down(pc,k) return pc:IsInputKeyDown(k) end
    local function down(name)
        if dn_t[name]==dn_frame then return dn_v[name] end
        local k=KEYS[name]; if not k then k={KeyName=FName(name)}; KEYS[name]=k end
        local ok,r=pcall(key_down,dn_pc,k)
        local v=ok and r==true
        dn_t[name],dn_v[name]=dn_frame,v
        return v
    end
    local inp_buf={}
    local RECOIL_CAM={X=5,Y=0.8,Z=1.4} -- the camera's recoil when cfg.recoil_cam is not set
    local function is_vis(o) return o:IsVisible() end
    local function paused(gs,pc) return gs:IsGamePaused(pc) end
    local PELVIS,SPINE1 -- FName('Bip001-Pelvis') and FName('Bip001-Spine1'), made once (the flip test while falling)

    local function tick()
        local now=os.clock()
        if now<s.pause then return end
        if s.give_back then s.give_back=false; pcall(data.put_back); aim.row=nil end
        if s.stop_stance then s.stop_stance=false; pcall(stance.stop) end
        if s.show_back then s.show_back=false; show_others() end
        if s.ammo_reset then s.ammo_reset=false; pcall(ammo.stop); pcall(ammo.refill) end
        -- left over by a new controller or a lost pawn: her body asset's own post-process and her mesh's turn put back
        if (s.layer_back or s.mesh_back) and not s.on then
            local p=g.pawn()
            if p then
                if s.mesh_back then local b=s.mesh_back; s.mesh_back=nil; pcall(function() p.Mesh:K2_SetRelativeRotation(b,false,{},false) end) end
                if s.layer_back then
                    s.layer_back_at=s.layer_back_at or now
                    -- her outfit may be put on after the pause: wait until our layer is really on her body (at most 30 s)
                    if layer.active(p) or now-s.layer_back_at>30 then
                        local ok,r,e=pcall(layer.uninstall,p)
                        g.log(('layer: put back after a new controller (%s, %s)'):format(tostring(ok and r),tostring(e)))
                        s.layer_back,s.layer_back_at=false,nil
                    end
                end
            end
        end
        local pc=g.pc(); if not pc then return end
        local okp,pz=pcall(paused,g.cdo('/Script/Engine.Default__GameplayStatics'),pc)
        if okp and pz then
            -- (dev only, gun_g1=on) the fixed views once per photo mode, to check the pose holds in it
            if set.g1 and s.on and g.valid(s.rifle) then
                local photo=g.try(function() return g.cdo('/Script/SB.Default__SBAutomationBlueprintFunctionLibrary'):IsPhotoMode() end)==true
                if photo and not s.photo_cap then
                    s.photo_cap=true
                    local ok,e=pcall(function()
                        s.g1=s.g1 or require('fight.gunmode.g1').new(g)
                        s.g1.capture(g.pawn(),pc,s.rifle,(set.g1_tag or 'run')..'_photo')
                    end)
                    if not ok then g.log('photo capture: '..tostring(e)) end
                elseif not photo then s.photo_cap=false end
            end
            return
        end
        dn_pc,dn_frame=pc,dn_frame+1
        if s.prof then s.prof('head') end
        local inp=Input.read(keys,down,now,cfg,set.key,inp_buf)
        -- the player's reload: a press of a reload key while the rifle is out (rising edge)
        local rk=false
        if s.on then for _,k in ipairs(cfg.reload_keys or {}) do if down(k) then rk=true end end end
        if rk and not s.reload_held and s.on and not s.morph then pcall(ammo.manual,now) end
        s.reload_held=rk
        if inp.key then self.toggle(set.key) elseif inp.toggle then self.toggle('D-pad Right') end
        if s.notice_off and now-s.notice_at>=3 then pcall(s.notice_off); s.notice_off=nil end
        if set.facts then
            s.facts=s.facts or require('fight.gunmode.facts').new(g)
            local ok,e=pcall(s.facts.tick,pc,g.pawn(),down,now)
            if not ok and not s.facts_err then s.facts_err=true; g.log('facts: '..tostring(e)) end
        end
        -- the HUD entry beside the D-pad marker (fight/gunmode/dpad.lua): the gun mode key and the rifle icon always, the
        -- rounds while the rifle is out; ten times a second
        if cfg.hud_entry~=false and now-(s.hud_at or 0)>=0.1 then
            s.hud_at=now
            s.dpad=s.dpad or Dpad.new(g)
            local txt=s.on and Ammo.lower_text(ammo.left,ammo.reserve,cfg.mag_size) or nil
            pcall(s.dpad.tick,set.key or 'G',txt,{1,1,1})
            -- hip fire (the rifle up, the game's own aim and its reticle off): a crosshair at the screen's centre
            pcall(s.dpad.crosshair,s.on and s.want=='aim' and not s.tps and not s.air_aim)
        end
        -- camps, seats, rests, doors and cutscenes: gun mode steps aside (rifle away, layer off, her own pose) while
        -- the game holds EVE in an interaction or a level sequence. It comes back 1 s after she is free (SBCharacter's
        -- reflected calls, as bike/ride.lua uses them). A press of the gun mode key cancels the comeback.
        if now-(s.held_at or 0)>=0.1 then
            s.held_at=now
            local p0=g.pawn()
            s.is_held=p0~=nil and g.try(function() return p0:IsAttachedToLevelSequenceWithoutPlayable()==true
                or p0:IsRunningInteraction()==true or p0.bEnableInteractionBlock==true end)==true
            if s.on and s.is_held then s.resume=true; s.free_at=nil; disable('EVE is in an interaction or a cutscene'); return end
            if not s.on and s.resume then
                if p0 and not s.is_held then
                    s.free_at=s.free_at or now
                    if GunMode.resume_due(s.free_at,now,1.0) then
                        enable('back after the interaction')
                        if s.on then s.resume,s.free_at=false,nil end
                    end
                else s.free_at=nil end
            end
        end
        if not s.on then return end
        local p=g.pawn()
        if set.g0 and p and g.valid(s.rifle) then
            s.g0=s.g0 or require('fight.gunmode.g0').new(g)
            local ok,e=pcall(s.g0.tick,pc,p,s.rifle,s.want or 'carry',now)
            if not ok and not s.g0_err then s.g0_err=true; g.log('g0: '..tostring(e)) end
        end
        if not p then disable('no EVE'); return end
        if s.prof then s.prof('input') end
        local falling_n -- IsFalling read once a frame in native mode (a launch takes effect at the next movement update)
        if set.native then -- Firing mode is the game's own aim: held while EVE is in it.
            -- Firing mode: the game's aim, or a jump out of it with the aim key still held (the game drops its aim
            -- stance in the air and takes it up again only at a new press): from the jump until the key is let go the
            -- rifle stays up and gun mode fires the NIKKE shot itself (shoot), on the ground again too.
            local tps=g.get(p,'bTPSMode')==true
            if tps then s.aim_seen=now end
            local key_held=down(set.aim_key) or down('Gamepad_LeftTrigger')
            s.key_held,s.tps=key_held,tps
            falling_n=g.try(function() return p.CharacterMovement:IsFalling() end)==true
            -- a dodge drops the game's aim like a jump: bridged the same way
            s.air_aim=Input.bridge(s.air_aim,tps,key_held,s.aim_seen and now-s.aim_seen)
            s.zoom_held=tps or s.air_aim
            if set.trace and now-(s.probe_at or 0)>=1.0 then -- (testing only: the reads and the log line cost frame time)
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
            -- makes her jump (her movement's jump speed, launched); the aim stance stays through the jump (fight/gunmode/data.lua).
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
            -- outside the game's aim (a jump or a dodge out of it, or hip fire) its TPSFire fires nothing: gun mode fires
            -- in hip fire the shot waits until the rifle points at the target (she turns first): bore error under
            -- cfg.hip_aligned degrees, measured this frame or the last (gunmode's chest loop); the flip shoots along the bore
            local aligned=s.flip or ((s.bore_err or 180)<(cfg.hip_aligned or 10) and now-(s.bore_at or 0)<0.1)
            local before=ammo.left
            if not tps and inp.fire and aligned and not s.morph and ammo.left>0 and not ammo.reload_until then pcall(shoot,p,now) end
            if s.prof then s.prof('native') end
            -- the timer counts the game's own rounds (its aim); gun mode's own shots count themselves (shoot -> ammo.spend)
            local ok_a,err_a=pcall(ammo.tick,s.zoom_held or inp.fire,inp.fire and tps,now)
            -- The muzzle flash on Luke's rifle, once a frame that rounds went out: the NIKKE shot's own flash is on
            -- the NIKKE rifle of her hidden real body (the fire round her waist), which the pak's show drops.
            -- recoil, once a frame that rounds went out: the rifle kicks in her hands (fight/gunmode/ik.lua kick) and the camera
            -- climbs a little (the controller's pitch input, eased by the game's own camera)
            if ok_a and ammo.left<before then
                if s.ik and s.ik.kick then s.ik.kick() end
                s.kick_at,s.kick_n=now,(s.kick_n or 0)+1
            end
            if ok_a and ammo.left<before and g.valid(s.rifle) and now-(s.flash_at or 0)>=cfg.muzzle_every then pcall(function()
                s.flash_at=now
                s.flash_lib=s.flash_lib or StaticFindObject('/Script/Niagara.Default__NiagaraFunctionLibrary')
                s.flash_fx=s.flash_fx or LoadAsset(cfg.muzzle_fx)
                if g.valid(s.flash_lib) and s.flash_fx then
                    local fx=s.flash_lib:SpawnSystemAttached(s.flash_fx,s.rifle,FName('FX_Fire'),{X=0,Y=0,Z=0},{Pitch=0,Yaw=0,Roll=0},2,true,true,0,false)
                    if g.valid(fx) then local k=cfg.muzzle_scale; fx:SetRelativeScale3D({X=k,Y=k,Z=k}) end
                end
            end) end
            if not ok_a and not s.ammo_err then s.ammo_err=true; g.log('ammo: '..tostring(err_a)) end
            if probe then pcall(probe.tick,pc,p,s.zoom_held,inp.fire,now) end
        elseif set.zoom_toggle then
            if inp.zoom_press then s.zoom_held=not s.zoom_held end
        else s.zoom_held=inp.zoom end
        if s.prof then s.prof('ammo') end
        -- the crosshair point (two line traces): every frame while aiming or firing, else 5 times a second
        if s.zoom_held or inp.fire or s.want=='aim' or not s.target or now-(s.cross_at or 0)>=0.2 then
            s.cross_at=now; s.target=crosshair(pc,p)
        end
        if s.prof then s.prof('crosshair') end
        local ok,err=pcall(stance.frame)
        if not ok then g.log('stance: '..tostring(err)); disable('stance error'); return end
        if not stance.running() then disable('the stance stopped'); return end
        if not set.native then camera(p) end
        if s.layer then
            -- her outfit changed (a new body mesh drops the layer): put it back, at most once a second
            if now-(s.layer_check or 0)>=1.0 then
                s.layer_check=now
                if not layer.active(p) then
                    local ok,inst=pcall(layer.install,p); s.layer_clip=nil
                    if not (ok and inst==true) then disable('rifle layer lost'); return end
                end
            end
            if s.reload_until and now>=s.reload_until then s.reload_until=nil end
            -- the game's own moves (dodges, evades, hit reactions, knockdowns) get her arms back: the layer's clip
            -- stops and the aim turn eases out until the move ends
            if s.prof then s.prof('stance') end
            if now-(s.move_at or 0)>=0.1 then
                s.move_at=now
                local nm=g.try(function()
                    local ai=p.Mesh:GetAnimInstance()
                    local m=ai:GetCurrentActiveMontage()
                    -- a montage still active but no longer playing (held at its end) is no move: it kept the carry on
                    return m and m:IsValid() and ai:Montage_IsPlaying(m)==true and m:GetFName():ToString() or nil
                end)
                s.move=nm and (nm:find('[Ee]vade') or nm:find('[Dd]odge') or nm:find('[Aa]void') or nm:find('[Hh]it')
                    or nm:find('[Dd]amage') or nm:find('[Dd]own') or nm:find('[Kk]nock') or nm:find('[Ss]tun') or nm:find('[Rr]oll')
                    or nm:find('[Ff]lip') or nm:find('[Dd]ash') or nm:find('[Pp]arry') or nm:find('[Gg]uard') or nm:find('[Ss]lide')) and nm or nil
                if set.trace and nm~=s.last_montage then s.last_montage=nm; g.log('layer: montage '..tostring(nm)..(s.move and ' (layer steps aside)' or '')) end
            end
            -- a move keeps the rifle held (the carry follows her body through it) instead of handing her arms back
            local falling0
            if set.native then falling0=falling_n else falling0=g.try(function() return p.CharacterMovement:IsFalling() end)==true end
            local want=GunMode.want(s.reload_until,s.zoom_held,inp.fire,s.move,falling0)
            if s.morph then
                local m=Morph.at(s.morph.dir,now-s.morph.t0)
                pcall(single.morph,m.rifle,m.spin)
                if g.valid(s.cube) then
                    local k=m.cube*(cfg.cube_cm or 9)/(s.cube_size or 100) -- (scaled from the mesh's own size)
                    pcall(function() s.cube:K2_SetRelativeTransform({Translation=cfg.cube_at,Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=k,Y=k,Z=k}},false,{},true)
                        s.cube:K2_AddLocalRotation({Pitch=m.spin*0.35,Yaw=m.spin,Roll=0},false,{},true) end)
                end
                if m.flash and not s.morph.flashed then
                    s.morph.flashed=true
                    pcall(function()
                        s.flash_lib=s.flash_lib or StaticFindObject('/Script/Niagara.Default__NiagaraFunctionLibrary')
                        local fx=StaticFindObject(cfg.morph_fx); if not g.valid(fx) then pcall(LoadAsset,cfg.morph_fx); fx=StaticFindObject(cfg.morph_fx) end
                        if g.valid(fx) and g.valid(s.rifle) then s.flash_lib:SpawnSystemAttached(fx,s.rifle,FName('None'),{X=0,Y=0,Z=0},{Pitch=0,Yaw=0,Roll=0},2,true,true,0,false) end
                    end)
                end
                -- while it runs: the arrival holds the carry, the departure lets her arms go back to her own pose
                want='carry'
                -- the layer and the arms' IK eased in over the arrival and out over the departure: ArmsAlpha (the IK)
                -- and AimExactAlpha (the layer's own weight variable) both follow it
                local f=math.max(0,math.min(1,(now-s.morph.t0)/(s.morph.dir=='in' and Morph.IN or Morph.OUT)))
                f=f*f*(3-2*f); if s.morph.dir=='out' then f=1-f end
                require('fight.gunmode.ik').fade=f
                pcall(function() local pp=p.Mesh:GetPostProcessInstance(); pp.AimExactAlpha=f end)
                if m.done then
                    if s.morph.dir=='out' then local w=s.morph.why or 'press'; disable(w); return end
                    s.morph=nil; cube_drop(); pcall(single.morph,nil); require('fight.gunmode.ik').fade=1
                end
            end
            s.want=want
            -- the game's aim stance (P_Eve_Gun) may switch her post-process graph off and hide what her hands hold: both
            -- are put back while the rifle is out (property reads and plain setters only, nothing on the instance itself)
            if s.prof then s.prof('montage') end
            local mesh=g.get(p,'Mesh')
            if g.get(mesh,'bDisablePostProcessBlueprint')==true then
                local ok=pcall(function() mesh:SetDisablePostProcessBlueprint(false) end)
                if not s.pp_logged then s.pp_logged=true; g.log('layer: the game disabled post-process ('..want..'), re-enabled: '..tostring(ok)) end
            end
            if g.valid(s.rifle) then
                local okv,vis=pcall(is_vis,s.rifle); if not okv then vis=nil end
                local hid=g.get(s.rifle,'bHiddenInGame')
                if vis==false or hid==true then
                    pcall(function() s.rifle:SetHiddenInGame(false,false) end); pcall(function() s.rifle:SetVisibility(true,false) end)
                    if not s.vis_logged then s.vis_logged=true; g.log(('layer: rifle hidden by the game (%s, visible %s hidden %s), shown again'):format(want,tostring(vis),tostring(hid))) end
                end
            end
            -- (testing) the aim's geometry, once a second while aiming: the barrel against the camera's line, the
            -- muzzle from her right shoulder, her left hand from the rifle
            if set.trace and want=='aim' and g.valid(s.rifle) and now-(s.geo_at or 0)>=1.0 then
                s.geo_at=now
                pcall(function()
                    local ml=g.cdo('/Script/Engine.Default__KismetMathLibrary')
                    local cm=pc.PlayerCameraManager
                    local cf=ml:GetForwardVector(cm:GetCameraRotation())
                    local fire=FName('FX_Fire')
                    local mz=s.rifle:GetSocketLocation(fire)
                    local bf=ml:GetForwardVector(s.rifle:GetSocketRotation(fire))
                    local root=s.rifle:K2_GetComponentLocation()
                    local mesh=p.Mesh
                    local sh=mesh:GetSocketLocation(FName('Bip001-R-UpperArm'))
                    local lh=mesh:GetSocketLocation(FName('Bip001-L-Hand'))
                    local rh=mesh:GetSocketLocation(FName('Bip001-R-Hand'))
                    local function d(a,b) return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2) end
                    -- the left hand's distance to the rifle's line (root to muzzle)
                    local ax,ay,az=mz.X-root.X,mz.Y-root.Y,mz.Z-root.Z
                    local L=math.sqrt(ax*ax+ay*ay+az*az); ax,ay,az=ax/L,ay/L,az/L
                    local px,py,pz=lh.X-root.X,lh.Y-root.Y,lh.Z-root.Z
                    local t=px*ax+py*ay+pz*az
                    local qx,qy,qz=px-t*ax,py-t*ay,pz-t*az
                    local dot=cf.X*bf.X+cf.Y*bf.Y+cf.Z*bf.Z
                    g.log(('layer geo: barrel vs camera %.0f deg, muzzle %.0f cm from her right shoulder, rifle %.0f cm long, left hand %.0f cm off the rifle line at %.0f cm along, right hand %.0f cm from the rifle root, actor yaw %.0f camera yaw %.0f'):format(
                        math.deg(math.acos(math.max(-1,math.min(1,dot)))),d(mz,sh),L,math.sqrt(qx*qx+qy*qy+qz*qz),t,d(rh,root),
                        p:K2_GetActorRotation().Yaw,cm:GetCameraRotation().Yaw))
                    local t=s.turn or {Pitch=0,Yaw=0,Roll=0}
                    local rb=g.try(function() local r=p.Mesh:GetPostProcessInstance().AimRot; return ('(%.1f, %.1f, %.1f)'):format(r.Pitch,r.Yaw,r.Roll) end)
                    g.log(('layer turn: computed (%.1f, %.1f, %.1f), on the layer %s, set ok %s, %s, passes %s steps %s err %s'):format(t.Pitch,t.Yaw,t.Roll,tostring(rb),tostring(s.turn_ok),tostring(s.turn_dbg),tostring(s.turn_n),tostring(s.turn_steps),tostring(s.turn_lasterr)))
                end)
            end
            if set.trace and want~=(s.trace_want or '') then
                s.trace_want=want
                g.log(('layer: %s, post-process disabled %s, rifle visible %s'):format(want,
                    tostring(g.try(function() return mesh.bDisablePostProcessBlueprint end)),
                    tostring(g.valid(s.rifle) and g.try(function() return s.rifle:IsVisible() end))))
            end
            -- the game stops montages when its stances change (its aim among them): the clip is checked four times a
            -- second and played again when it was stopped
            -- the rifle-first solver places the rifle and puts both hands on it (fight/gunmode/ik.lua)
            s.ik=s.ik or require('fight.gunmode.ik').new(g)
            local ppi=g.try(function() return mesh:GetPostProcessInstance() end)
            local mode_ik=(want=='aim') and 'aim' or ((want=='carry' or want=='reload') and 'carry' or 'off')
            -- In the air the aim stays as on the ground. Only the double-jump flip (her Pelvis->Spine1 tilted past
            -- flip_tilt) stops the chest and rifle-pitch loops: AimRot is in component space and would twist her chest as
            -- she turns over. The laser and the shots then go along the bore (shoot, the laser's nil target).
            local falling=falling0
            s.in_air=falling
            s.flip=falling and (g.try(function() local m=mesh
                PELVIS=PELVIS or FName('Bip001-Pelvis'); SPINE1=SPINE1 or FName('Bip001-Spine1')
                return require('fight.gunmode.aimrot').tilt(m:GetSocketLocation(PELVIS),m:GetSocketLocation(SPINE1)) end) or 0)>require('fight.gunmode.ik').CFG.flip_tilt
            -- a reload while aiming keeps her aimed: body turn, aim camera and chest turn held while the reload clip plays
            -- (not in the air or through one of the game's moves: the mesh yaw must ease out then)
            local hold_aim=mode_ik=='aim' or (want=='reload' and s.zoom_held and not falling and not s.move)
            -- (dev only, gun_airtrace=on) ten times a second while falling: her body tilt (Pelvis->Spine1 against world up),
            -- the game's aim flag, the state, the chest turn and the rifle's bore pitch; facts for the flip work
            if set.airtrace and falling and now-(s.at_log or 0)>=0.1 then s.at_log=now
                pcall(function()
                    local m=p.Mesh; local a=m:GetSocketLocation(FName('Bip001-Pelvis')); local b=m:GetSocketLocation(FName('Bip001-Spine1'))
                    local dx,dy,dz=b.X-a.X,b.Y-a.Y,b.Z-a.Z; local l=math.sqrt(dx*dx+dy*dy+dz*dz)
                    local tilt=math.deg(math.acos(math.max(-1,math.min(1,dz/l))))
                    local bp='-'
                    if g.valid(s.rifle) then local ml=g.cdo('/Script/Engine.Default__KismetMathLibrary')
                        local f=ml:GetForwardVector(s.rifle:GetSocketRotation(FName('FX_Fire'))); bp=('%.0f'):format(math.deg(math.asin(math.max(-1,math.min(1,f.Z))))) end
                    local c=s.chest or {Pitch=0,Yaw=0,Roll=0}
                    g.log(('airtrace tilt %.0f tps %s mode %s want %s zoom %s chest %.0f %.0f %.0f borepitch %s'):format(tilt,tostring(s.tps),tostring(mode_ik),tostring(want),tostring(s.zoom_held),c.Pitch,c.Yaw,c.Roll,bp))
                end)
            end
            local ok_i,err_i=true,nil
            if s.prof then s.prof('layer_misc') end
            s.ik.want=want -- the v4 pin follows the layer clip (aim, carry, reload)
            s.ik.reload_k=(want=='reload' and s.reload_until) and 1-(s.reload_until-now)/(s.reload_len or 1) or nil
            single.no_laser=want=='reload'
            if not s.g1_hold then ok_i,err_i=pcall(s.ik.tick,pc,p,s.rifle,mode_ik,ppi) end -- g1's AimRot test freezes the IK writes
            if not ok_i and not s.ik_err then s.ik_err=true; g.log('ik: '..tostring(err_i)) end
            -- the aim camera over her right shoulder (the native TPS camera ignores the boom): gunmode's camera
            -- modifier (BP_NGM_CamMod in the layer pak) adds Offset (camera space: forward, right, up), eased
            pcall(function()
                if not s.cmod and not s.cmod_fail then
                    local cm=pc.PlayerCameraManager
                    local path='/Game/Mods/NGM/BP_NGM_CamMod.BP_NGM_CamMod_C'
                    local cls=StaticFindObject(path)
                    if not g.valid(cls) then
                        cls=StaticFindObject('/Script/AssetRegistry.Default__AssetRegistryHelpers'):GetAsset({ObjectPath=FName(path)})
                    end
                    if g.valid(cls) then s.cmod=cm:AddNewCameraModifier(cls); s.cmod_k=0 end
                    if not g.valid(s.cmod) then s.cmod=nil; s.cmod_fail=true; g.log('camera: modifier not available') else g.log('camera: modifier added') end
                end
                if s.cmod then
                    -- the aim camera offset: full while the game's aim is on, half for hip fire (11-20: "less than in aim")
                    local kt=hold_aim and ((s.tps or s.air_aim) and 1 or (cfg.hip_cam or 0.5)) or 0
                    -- recoil: the camera pushed back and jolted (alternating left/right, up) each round, easing out
                    local kick=GunMode.kick(s.kick_at and now-s.kick_at,cfg.recoil_decay or 0.06)
                    if math.abs(kt-s.cmod_k)>0.002 or kick>0 or s.kick_was then
                        s.cmod_k=s.cmod_k+(kt-s.cmod_k)*0.2
                        local o,k=cfg.aim_cam,s.cmod_k
                        local r=cfg.recoil_cam or RECOIL_CAM; local j=(s.kick_n or 0)%2==0 and 1 or -1
                        s.cmod.Offset={X=o.X*k-r.X*kick,Y=o.Y*k+r.Y*kick*j,Z=o.Z*k+r.Z*kick}
                        s.kick_was=kick>0
                    end
                end
            end)
            -- the game's aim stance turns her side-on; her mesh is turned back toward the aim (eased)
            pcall(function()
                local m=mesh
                if not s.mesh_rot then local r=m.RelativeRotation; s.mesh_rot={Pitch=r.Pitch,Yaw=r.Yaw,Roll=r.Roll}; s.mesh_yaw=0 end
                local C=require('fight.gunmode.ik').CFG
                local target=(hold_aim and s.tps) and C.aim_mesh_yaw or 0
                local dy=target-s.mesh_yaw
                if math.abs(dy)>0.05 then
                    s.mesh_yaw=s.mesh_yaw+dy*0.25
                    local b=s.mesh_rot
                    m:K2_SetRelativeRotation({Pitch=b.Pitch,Yaw=b.Yaw+s.mesh_yaw,Roll=b.Roll},false,{},false)
                end
                -- her head turned back by the same amount (the stance has her looking over her left shoulder). The layer's
                -- Neck node is off since the v3a pak (rotating the neck dragged both shoulder joints ~7.4 cm, red test
                -- 11-19): AimRot reaches Bip001-Head alone, so the head takes the whole turn
                -- v3c pak: the NIKKE clip drives her arms, hands and head from Bip001-Neck down. AimRot turns
                -- Bip001-Spine2 (chest, arms and rifle together). In aim a closed loop turns it until the rifle's real
                -- bore (FX_Fire forward) points at the spot aim_dist down the camera line; otherwise it eases back to 0
                if ppi and not s.g1_hold then
                    local AR=require('fight.gunmode.aimrot')
                    s.chest=s.chest or {Pitch=0,Yaw=0,Roll=0}
                    if mode_ik=='aim' and not s.flip and g.valid(s.rifle) then
                        local ml=g.cdo('/Script/Engine.Default__KismetMathLibrary')
                        local CT=m:K2_GetComponentToWorld()
                        local mz=s.rifle:GetSocketLocation(fx_fire())
                        local bw=ml:GetForwardVector(s.rifle:GetSocketRotation(fx_fire()))
                        -- aim needs zoom or fire, so the crosshair read the camera this frame; without a camera manager
                        -- the rest of this loop is skipped as before
                        local cl,cr=s.cam_loc,s.cam_rot
                        if not cl then error('no camera manager') end
                        local cf=ml:GetForwardVector(cr)
                        local d=C.aim_dist
                        local want={X=cl.X+cf.X*d-mz.X,Y=cl.Y+cf.Y*d-mz.Y,Z=cl.Z+cf.Z*d-mz.Z}
                        local bc,wc=ml:InverseTransformDirection(CT,bw),ml:InverseTransformDirection(CT,want)
                        s.chest=AR.step_yp(s.chest,bc,wc,0.35,C.chest_pitch_max or 65,C.chest_yaw_max or 60)
                        do local wl=math.sqrt(wc.X^2+wc.Y^2+wc.Z^2); local bl=math.sqrt(bc.X^2+bc.Y^2+bc.Z^2)
                            s.bore_err=math.deg(math.acos(math.max(-1,math.min(1,(bc.X*wc.X+bc.Y*wc.Y+bc.Z*wc.Z)/(wl*bl))))); s.bore_at=now end
                        -- v4: the chest takes at most chest_pitch_max of the pitch; the rifle pivots on its butt for the
                        -- rest (fight/gunmode/ik.lua pin, both hands follow by IK). Same closed loop on the bore's pitch error.
                        local wl=math.sqrt(want.X^2+want.Y^2+want.Z^2)
                        local pe=math.deg(math.asin(math.max(-1,math.min(1,want.Z/wl))))-math.deg(math.asin(math.max(-1,math.min(1,bw.Z))))
                        local rm=C.rifle_pitch_max or 0
                        s.rpitch=math.max(-rm,math.min(rm,(s.rpitch or 0)+0.35*pe))
                        if set.trace and now-(s.chest_log or 0)>=1 then s.chest_log=now
                            local wl=math.sqrt(wc.X^2+wc.Y^2+wc.Z^2); local bl=math.sqrt(bc.X^2+bc.Y^2+bc.Z^2)
                            local e=math.deg(math.acos(math.max(-1,math.min(1,(bc.X*wc.X+bc.Y*wc.Y+bc.Z*wc.Z)/(wl*bl)))))
                            g.log(('chest turn %.1f %.1f %.1f, bore error %.1f deg'):format(s.chest.Pitch,s.chest.Yaw,s.chest.Roll,e))
                        end
                    -- the flip: the chest turn eases out, s.rpitch (rifle frame off her neck) is held; both resume upright
                    elseif s.flip then s.chest=GunMode.decay(AR,s.chest)
                    elseif not hold_aim then s.chest=GunMode.decay(AR,s.chest); s.rpitch=(s.rpitch or 0)*0.85 end
                    ppi.AimRot=s.chest
                    -- hip fire (the game's own aim off): she faces the camera through her own movement (the game turns
                    -- her, standing or strafing: one writer, gunmode's face). Shots wait until the bore is on
                    -- target (hip_aligned); a big turn from standing plays the game's aim-stance turn clip as the shuffle
                    local hip=want=='aim' and not s.tps and not falling
                    face(p,hip)
                    local was=s.turning
                    s.turning=hip and GunMode.turn(s.turning,s.chest.Yaw,C.turn_start or 40,C.turn_stop or 12)
                    if s.turning and not was and now-(s.shuffle_at or 0)>0.5
                        and g.try(function() local v=p:GetVelocity(); return v.X*v.X+v.Y*v.Y<60*60 end)==true then
                        s.shuffle_at=now
                        pcall(function()
                            local nm=(s.chest.Yaw or 0)<0 and 'P_Eve_Gun_RotateLw' or 'P_Eve_Gun_RotateRw'
                            local path='/Game/Art/Character/PC/CH_P_EVE_01/Animation/'..nm..'.'..nm
                            local seq=StaticFindObject(path); if not g.valid(seq) then pcall(LoadAsset,path); seq=StaticFindObject(path) end
                            if g.valid(seq) then p.Mesh:GetAnimInstance():PlaySlotAnimationAsDynamicMontage(seq,FName('DefaultSlot'),0.1,0.15,1.0,1,-1,0)
                            elseif not s.shuffle_err then s.shuffle_err=true; g.log('turn: no '..nm) end
                        end)
                    end
                    if s.turning then pcall(function()
                        local cy=s.cam_rot and s.cam_rot.Yaw or pc.PlayerCameraManager:GetCameraRotation().Yaw
                        local r=p:K2_GetActorRotation()
                        local d=(cy-r.Yaw+540)%360-180
                        local dt=math.min(0.05,math.max(0,now-(s.turn_at or now))); local mx=(C.turn_rate or 360)*dt
                        local st=math.max(-mx,math.min(mx,d))
                        if math.abs(st)>0.01 then p:K2_SetActorRotation({Pitch=0,Yaw=r.Yaw+st,Roll=0},false) end
                    end) end
                    s.turn_at=now
                    s.ik.rpitch=s.rpitch
                end
            end)
            if s.prof then s.prof('ik_chest') end
            -- (dev only, gun_g1=on) the fixed views once in carry (3 s into it) and once mid-reload
            if set.g1 and g.valid(s.rifle) then
                local tagc
                if want=='carry' then s.carry_since=s.carry_since or now; if now-s.carry_since>3 and not s.cap_carry then s.cap_carry=true; tagc='carry' end
                else s.carry_since=nil end
                if want=='reload' and (s.ik.reload_k or 0)>0.45 and not s.cap_reload then s.cap_reload=true; tagc='reload' end
                if tagc then pcall(function()
                    s.g1=s.g1 or require('fight.gunmode.g1').new(g)
                    s.g1.capture(p,pc,s.rifle,(set.g1_tag or 'run')..'_'..tagc)
                end) end
            end
            -- (dev only) gate G1 of the v3 plan: gate numbers, the AimRot test and fixed captures (fight/gunmode/g1.lua)
            if set.g1 and g.valid(s.rifle) then
                local ok,e=pcall(function()
                    s.g1=s.g1 or require('fight.gunmode.g1').new(g)
                    s.g1.tick(pc,p,s.rifle,mode_ik,now,s,ppi,set.g1_tag or 'run')
                end)
                if not ok then s.g1_hold=false; if not s.g1_err then s.g1_err=true; g.log('g1: '..tostring(e)) end end
            end
            if s.layer_clip and s.layer_clip~='none' and now-(s.layer_seen or 0)>=0.25 then
                s.layer_seen=now
                if not layer.playing(p,s.layer_clip) then
                    s.layer_stops=(s.layer_stops or 0)+1
                    if s.layer_stops<=3 or s.layer_stops%50==0 then g.log('layer: '..s.layer_clip..' was stopped ('..s.layer_stops..'), played again') end
                    s.layer_clip=nil
                end
            end
            -- the layer clip: want, with the aim split by the rifle's pitch (the hands are pinned by IK either way)
            local clip=want
            if want=='aim' then
                local C=require('fight.gunmode.ik').CFG
                clip=GunMode.aim_clip(s.layer_clip,s.rpitch,C.aim_clip_up,C.aim_clip_back)
            end
            if clip~=s.layer_clip then
                local m,e
                if clip=='carry' then m,e=layer.play(p,'carry',1.0,0,0.3,0.25)
                elseif clip=='aim' or clip=='aimup' or clip=='aimdown' then m,e=layer.play(p,clip,1.0,0,(s.layer_clip=='carry' or s.layer_clip=='reload') and 0.18 or 0.3,0.2)
                elseif clip=='none' then layer.stop(p,0.12); m=true
                else -- the reload clip fitted to the reload time (at rate 1 it was cut off or looped); 0.1 s spare so it does not wrap before the reload ends
                    local L=layer.length('reload')
                    local k=(L and L>0) and L/((s.reload_len or 1)+0.1) or 1.0
                    m,e=layer.play(p,'reload',k,0,0.25,0.2)
                    if not s.reload_rate_logged then s.reload_rate_logged=true; g.log(('layer: reload clip %s s, rate %.2f'):format(tostring(L),k)) end
                end
                if m then s.layer_clip=clip; if single.grip then single.grip(clip) end elseif not s.layer_err then s.layer_err=true; g.log('layer clip '..clip..': '..tostring(e)) end
            end
        end
        if s.prof then s.prof('layer_play') end
        if now-s.hide_at>=1.0 then
            s.hide_at=now
            pcall(hide_others,p,false)
            if cfg.hide_drone~=false then pcall(hide_drone,p) end
        end
        if s.prof then s.prof('hide') end
        if set.native and set.upper then pcall(hold_pose,p,inp.fire) end
        -- In firing mode, ten times a second: the NIKKE bullet's start put on the rifle's muzzle and its destination
        -- on the crosshair point, moved at random within the spread (each shot writes the destination again).
        if s.prof then s.prof('pose') end
        if (s.zoom_held or inp.fire) and now-(s.aim_w or 0)>=0.1 then
            s.aim_w=now
            local m=g.valid(s.rifle) and g.try(function() return s.rifle:GetSocketLocation(fx_fire()) end)
            aim.write_start(p,m or nil,cfg.start_min_forward,cfg.start_fallback)
            aim.write(p,Aim.spread(s.target,s.cam_loc,spread,math.random(),math.random()))
        end
        if not set.native then face(p,s.zoom_held) end
        -- Firing mode: fire once the rifle has had a moment to come up (Luke's raise eases in over ~12 frames).
        if s.zoom_held then s.held_since=s.held_since or now else s.held_since=nil end
        if s.ovr_row then carry(p,not s.zoom_held) end
        if not set.native and inp.fire and s.held_since and now-s.held_since>=cfg.raise_time then shoot(p,now) end
    end

    local function guarded(f)
        local ok,e=pcall(f)
        if not ok and s.errors<5 then s.errors=s.errors+1; g.log('error: '..tostring(e)) end
    end
    -- gun mode's own frame time: every 10 s while on, the average and the worst tick (one log line)
    -- per-section split of the tick (marks in tick: s.prof('<section that ends here>'))
    local sec,last={},0
    local smax={}
    -- Lua's collector stays as UE4SS sets it: a generational mode, a hand-paced one and an aggressive pause were tried;
    -- the last one crashed UE4SS (access violation in UE4SS.dll right after gun mode came on). The stutters are
    -- cut at their source instead: less garbage a frame.
    s.prof=function(name) local t=os.clock(); local d=t-last; sec[name]=(sec[name] or 0)+d; if d>(smax[name] or 0) then smax[name]=d end; last=t end
    local function timed()
        local t0=os.clock(); last=t0; guarded(tick); local dt=os.clock()-t0
        if not s.on then return end
        local pf=s.perf or {n=0,sum=0,max=0,at=t0}; s.perf=pf
        pf.n,pf.sum,pf.max=pf.n+1,pf.sum+dt,math.max(pf.max,dt)
        if t0-pf.at>=10 then
            local parts={}
            for k,v in pairs(sec) do parts[#parts+1]={k,v} end
            table.sort(parts,function(a,b) return a[2]>b[2] end)
            local txt={}
            for i=1,math.min(6,#parts) do txt[#txt+1]=('%s %.2f (worst %.1f)'):format(parts[i][1],parts[i][2]/pf.n*1000,(smax[parts[i][1]] or 0)*1000) end
            g.log(('perf: tick %.2f ms average, %.2f ms worst, %d ticks, Lua %.0f KB; ms a tick: %s'):format(pf.sum/pf.n*1000,pf.max*1000,pf.n,collectgarbage('count'),table.concat(txt,', ')))
            s.perf=nil; sec={}; smax={}
        end
    end

    -- A new controller (map load, death, camp warp): the rifle goes away and SB's rows go back. Nothing here touches
    -- the pawn (only the input settings are put back): the controller is still being built (reading its pawn from
    -- this callback crashed UE4SS). Her body asset's post-process and her mesh's turn are put back from the loop.
    -- fight/gunmode/wiring.lua calls this from its NotifyOnNewObject.
    function self.new_controller(pc)
        if not set.on or s.dead then return end
        cached=pc
        s.pause=os.clock()+4.0
        s.give_back=true
        if s.on then
            s.on=false
            if s.mask then pcall(s.mask); s.mask=nil end
            s.mask_dry=nil
            s.cam,s.zoom=nil,0
            s.mesh_back=(s.mesh_yaw or 0)~=0 and s.mesh_rot or nil -- (her mesh's turn, if this pawn lives on)
            s.mesh_rot,s.mesh_yaw,s.cmod,s.cmod_fail,s.head_yaw,s.chest=nil,0,nil,nil,nil,nil
            -- the layer is still named on her body asset (the next pawn gets it): put back from the loop as well
            s.layer_back=s.layer or s.layer_back
            s.layer,s.layer_clip,s.reload_until,s.move=false,nil,nil,nil
            s.snap,s.was_hip,s.turning=nil,nil,nil
            s.ovr_active,s.hip,s.burst=nil,nil,nil -- (the next pawn starts with no override)
            s.fov,s.fov_locked=nil,false
            s.ammo_reset=true
            s.stop_stance=true
            s.show_back=true
        end
    end

    -- One frame of gun mode: main/frame.lua calls this from its frame loop.
    function self.tick()
        if not set.on or s.dead then return end
        timed()
    end

    -- A frame loop of gun mode's own (tests only: main/frame.lua ticks it in the mod).
    function self.hook()
        if s.hooked then return true end
        local function guarded(f)
            local ok,e=pcall(f)
            if not ok and s.errors<5 then s.errors=s.errors+1; g.log('error: '..tostring(e)) end
        end
        -- gun mode's own frame time: every 10 s while on, the average and the worst tick (one log line)
        -- per-section split of the tick (marks in tick: s.prof('<section that ends here>'))
        local sec,last={},0
        local smax={}
        -- Lua's collector stays as UE4SS sets it: a generational mode, a hand-paced one and an aggressive pause were tried
        -- (11-20); the last one crashed UE4SS (access violation in UE4SS.dll right after gun mode came on). The stutters are
        -- cut at their source instead: less garbage a frame.
        s.prof=function(name) local t=os.clock(); local d=t-last; sec[name]=(sec[name] or 0)+d; if d>(smax[name] or 0) then smax[name]=d end; last=t end
        local function timed()
            local t0=os.clock(); last=t0; guarded(tick); local dt=os.clock()-t0
            if not s.on then return end
            local pf=s.perf or {n=0,sum=0,max=0,at=t0}; s.perf=pf
            pf.n,pf.sum,pf.max=pf.n+1,pf.sum+dt,math.max(pf.max,dt)
            if t0-pf.at>=10 then
                local parts={}
                for k,v in pairs(sec) do parts[#parts+1]={k,v} end
                table.sort(parts,function(a,b) return a[2]>b[2] end)
                local txt={}
                for i=1,math.min(6,#parts) do txt[#txt+1]=('%s %.2f (worst %.1f)'):format(parts[i][1],parts[i][2]/pf.n*1000,(smax[parts[i][1]] or 0)*1000) end
                g.log(('perf: tick %.2f ms average, %.2f ms worst, %d ticks, Lua %.0f KB; ms a tick: %s'):format(pf.sum/pf.n*1000,pf.max*1000,pf.n,collectgarbage('count'),table.concat(txt,', ')))
                s.perf=nil; sec={}; smax={}
            end
        end
        s.hooked=pcall(function() LoopInGameThreadWithDelay(1,function() if not s.dead then timed() end end) end)
        return s.hooked
    end

    -- The start's log lines. Nothing at all with gun_mode=off. wiring.lua registers the new-controller reset and
    -- main/frame.lua runs the loop.
    function self.start()
        for _,why in ipairs(bad) do g.log('coop-settings.txt: '..why) end
        if not set.on then g.log('off (gun_mode=off in coop-settings.txt)'); return end
        g.log('ready: '..set.key..' or a tap of D-pad Right')
    end

    function self.out() return s.on==true end
    -- (coop off) gun mode put away for good.
    function self.stop(why) self.kill() end
    -- Nothing to put back: gun mode keeps no file of its own.
    function self.restore() end

    function self.status()
        return ('gun mode %s%s, key %s, %d shots'):format(s.on and 'on' or 'off',
            s.on and (s.zoom_held and ' (firing mode)' or ' (moving)') or '',set.key,s.shots)
    end
    self.toggle_now=function() self.toggle('command') end
    self.state=s
    return self
end

return GunMode
