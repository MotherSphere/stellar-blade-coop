-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode: the NIKKE DLC's rifle in EVE's hands on any save, on luke77's rifle stance. F4 (gun_key) or a tap of
-- D-pad Right brings the rifle out or puts it away. Out, EVE runs and jumps as Luke's stance has her (fight/gunmode/
-- stance.lua: her own animation, the rifle at her chest). Holding RMB / LT is firing mode: the camera comes in over her
-- right shoulder, she turns to the camera and brings the rifle up with its laser sight on, and LMB / RT fires full
-- auto at the point under the screen centre. Letting go goes back to Luke's movement. Logged as [StellarCoop][GM].
-- How: each shot is the NIKKE shot skill, started by a zone event through SB's own rows (fight/gunmode/data.lua), its
-- bullet sent to the crosshair's point (fight/gunmode/aim.lua). While the rifle is out the sword's attacks and the drone's
-- aim on the fire and zoom keys are masked in memory (lifted while the game is paused, where SB's key options can save
-- the mappings; put back when it goes away).
-- Gun mode is a module of its own: it reads its coop-settings.txt lines as main.lua read them (core/link.lua) and uses
-- no other module (only the shared core/ and ui/text); fight/gunmode/wiring.lua builds it and registers its controller
-- hook. All of it runs on the game thread, from main/frame.lua's loop (every frame) and the hook: no LoopAsync,
-- ExecuteWithDelay or key bind, whose callbacks run Lua on another thread (two threads in one Lua state crashed UE4SS,
-- 11-17). Every step is wrapped, so an error in gun mode never reaches the rest of the mod.
local Config=require('fight.gunmode.config')
local Aim=require('fight.gunmode.aim')
local Input=require('fight.gunmode.input')
local Stance=require('fight.gunmode.stance')
local Rifle=require('fight.gunmode.rifle')
local Laser=require('fight.gunmode.laser')
local Data=require('fight.gunmode.data')
local Probe=require('fight.gunmode.probe')
local Ammo=require('fight.gunmode.ammo')
local Overlay=require('fight.gunmode.overlay')
local Journal=require('fight.gunmode.journal')
local U=require('core.unreal')

local GunMode={}

-- Zone event kind 2 is ZoneEvent_AttachActorEffect (ESBZoneEventType's names at 0x145e29b00 on 26123051). RunEvent
-- (0x141ca5a10) hands it to 0x141c9e690, which applies the row's actor effect; no chain of direct calls from it reaches
-- RunEvent, RunZoneEvent (0x141ca5790) or StartMatchMaking (0x141ca3ea0, RunEvent's kind 15). Kinds 16 and 19 stop
-- matchmaking or go back to single play. The only zone event gun mode fires: kind 2 on the shot's row
-- (Data.row('Fire'), read at the call: arm() can borrow a spare NIKKE row in its place).
local ATTACH_ACTOR_EFFECT=2
function GunMode.allowed(kind,name) return kind==ATTACH_ACTOR_EFFECT and name~=nil and name==Data.row('Fire') end
local function find_name(t) return FName(t,EFindName.FNAME_Find) end -- None (index 0) when not a name yet.
local function zone_event(kind,name)
    assert(GunMode.allowed(kind,name),'zone event refused')
    U.find('/Script/SB.Default__SBBlueprintLibrary'):CreateSBZoneEvent(kind,find_name(name))
end

-- fight.gunmode's copy of vehicles/bike/ride.lua's blocked(): the checks of EVE's own state that need no native part.
-- Why the rifle cannot be out now, or nil. e: EVE (an SBCharacter); photo: main/base.lua's photo_state ('0', '1' in the
-- photo mode, 's' in the selfie mode; with SB.PhotoMode.PauseMethod 1 its start, 0x142381f90, sets a time dilation of
-- 1e-8 and asks no pause, so IsGamePaused stays false there). On 26123051: IsAttachedToLevelSequenceWithoutPlayable,
-- IsRunningInteraction and IsMoveInputBlock are SBCharacter natives (exec 0x142686f40, 0x14268cc20, 0x14268bc60;
-- registered by 0x14cef8000 with its other 233), bEnableInteractionBlock an SBCharacter bool (params 0x145d77b78).
-- EMovementMode (enumerators at 0x146548c80): 1 walking, 2 nav walking, 3 falling, 4 swimming, 5 flying, 6 custom
-- (a move of SB's own).
local WALKING,NAV_WALKING,FALLING,SWIMMING=1,2,3,4
function GunMode.blocked(e,photo)
    if photo=='s' then return 'the selfie mode is open' end
    if photo=='1' then return 'the photo mode is open' end
    if e:IsAttachedToLevelSequenceWithoutPlayable()==true then return 'a cutscene holds EVE' end
    if e:IsRunningInteraction()==true or e.bEnableInteractionBlock==true then return 'EVE is in an interaction' end
    if e:IsMoveInputBlock()==true then return 'the game holds her movement' end
    local mode=U.value_of(e.CharacterMovement.MovementMode)
    if mode==SWIMMING then return 'EVE is swimming' end
    if mode~=WALKING and mode~=NAV_WALKING and mode~=FALLING then
        return "EVE is in one of SB's moves (movement mode "..tostring(mode)..')'
    end
end

local SETTINGS='/Script/Engine.Default__InputSettings'
local TRACE='/Script/Engine.Default__KismetSystemLibrary'
local STATICS='/Script/Engine.Default__GameplayStatics'

-- A point along a camera's forward: loc + forward(rot) * d.
function GunMode.ahead(loc,rot,d)
    local p,y=math.rad(rot.Pitch),math.rad(rot.Yaw)
    local c=math.cos(p)
    return {X=loc.X+math.cos(y)*c*d,Y=loc.Y+math.sin(y)*c*d,Z=loc.Z+math.sin(p)*d}
end

-- a eased toward b by share k.
function GunMode.ease(a,b,k) return a+(b-a)*k end

-- env: {log, settings (main.lua's, as core/link.lua parses coop-settings.txt; nil: the defaults), words (the menu's
-- words, ui/text.lua's table in the player's language; English unless given), notice (a notice on screen, by its key
-- in ui/text.lua's gun: rebuilding when nil), store (coop-gun.txt through core/link.lua's store: save, load, clear; nil
-- without the native part, so a Lua reload then cannot put back what an earlier load changed), photo (main/base.lua's photo_state; '0' when not given), busy (why another module holds EVE now, or nil:
-- fight/gunmode/wiring.lua reads them), match (true while an SBO match runs: fight/gunmode/wiring.lua reads the link)}.
function GunMode.new(env)
    local cfg=Config.DEFAULTS
    local set,bad=Config.from(env.settings)
    local g={}
    function g.log(m) env.log(m) end
    function g.words() return (env.words and env.words() or require('ui.text').en).gun end
    function g.valid(o)
        if o==nil then return false end
        local ok,r=pcall(function() return o:IsValid() end)
        return ok and r==true
    end
    function g.try(fn) local ok,r=pcall(fn); if ok then return r end end
    -- An object's path (its full name without its class), as core/actors.lua's path_of: StaticFindObject finds it by
    -- that path while it lives. nil when it cannot be read.
    function g.path(o)
        local f=g.valid(o) and g.try(function() return o:GetFullName() end)
        return type(f)=='string' and f:match('^%S+ (.+)$') or nil
    end
    -- An object of /Script (a default object or a class: the engine never collects them) by its path, looked up once
    -- while it lives (M2): UE4SS's StaticFindObject walks the object array. After a miss, nil for a second.
    local found,missed={},{}
    function g.find(path)
        if g.valid(found[path]) then return found[path] end
        if (missed[path] or -1)>os.clock() then return nil end
        local o=StaticFindObject(path)
        if g.valid(o) then found[path]=o; return o end
        missed[path]=os.clock()+1.0
    end
    -- The controller: FindFirstOf walks the whole object array, so once a second at most while there is none (M2). A
    -- new one comes through new_controller at once.
    local cached,pc_wait
    function g.pc()
        if g.valid(cached) then return cached end
        if (pc_wait or -1)>os.clock() then return nil end
        local pc=FindFirstOf('SBPlayerController')
        if g.valid(pc) then cached=pc; return pc end
        pc_wait=os.clock()+1.0
    end
    function g.pawn()
        local pc=g.pc(); if not pc then return nil end
        local p=g.try(function() return pc.Pawn end)
        if g.valid(p) then return p end
    end
    if set.fire_key then Input.FIRE[#Input.FIRE+1]=set.fire_key end
    local aim,data=Aim.new(g),Data.new(g,set.native,{speed=cfg.native_speed,upper=set.upper and 'P_Eve_GunNikke' or nil,cool=cfg.fire_interval,bs=set.bs})
    -- The rifle: with the rifle layer or the rifle clips alone (zNGMSpike_P), fight/gunmode/rifle.lua (the rifle in her
    -- real hand; the rifle clips play on her real body); without them, Luke's posed stance (fight/gunmode/stance.lua).
    local posed=Stance.new(Laser,set.trace and g.log or nil)
    local single=Rifle.new(Laser,set.trace and g.log or nil)
    local stance=posed
    local probe=set.probe and Probe.new(g)
    -- The rifle layer (fight/gunmode/overlay.lua: ABP_NGM_Spike in zNGMSpike_P) plays the rifle clips on her arms over
    -- her own finished pose; nothing of her main animation, springs or outfit physics is touched.
    local layer=Overlay.new(g)
    local keys=Input.state()
    local self={}
    local s={hidden={},followed={},on=false,pause=0,next_shot=0,shots=0,zoom=0,zoom_held=false,target=nil,cam=nil,mask=nil,
        toggle_at=-1,hooked=false,errors=0}
    -- What belongs to one pawn and its controller, cleared on a new controller with no game call (new_controller).
    local PER_PAWN={'ovr_row','flash_fx','rifle','pose_m','pose_on','ik','layer_clip','reload_until','turn','turnq',
        'want','move','sounds','aim_seen','air_aim','key_held','held_since','jump_down','tps','drone_wait'}
    local restored=false -- coop-gun.txt read this Lua load (self.restore).

    -- The reload: the NIKKE squad's reload animation on the rifle stance, and its sounds at their times.
    local function sound(path)
        local ok,err=pcall(function()
            local cue=LoadAsset(path)
            assert(cue,'no '..path)
            g.find(STATICS):PlaySound2D(g.pawn(),cue,1.0,1.0,0.0,nil,nil,false)
        end)
        if not s.sound_logged then s.sound_logged=true; g.log('reload sound: '..(ok and 'played' or tostring(err))) end
    end
    local function on_reload(on,duration)
        local ok=stance.reload(on,duration)
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
    -- The D-pad rifle slot (fight/gunmode/ui/slot.lua), made by self.hud on the kit; until then, or without the Steam
    -- link's kit, the rounds go to no slot.
    local slot=nil
    local dpad={show=function(...) if slot then slot.show(...) end end,hide=function() if slot then slot.hide() end end}
    local ammo=Ammo.new(g,cfg,function(v) data.cool(v) end,on_reload,dpad)

    local function fire_row(row)
        local ok,err=pcall(zone_event,ATTACH_ACTOR_EFFECT,row)
        if not ok then g.log('row '..row..' failed: '..tostring(err)) end
        return ok
    end

    -- Masked keys given back (coop-gun.txt's key records, from an earlier Lua load or from mask below), each on a
    -- mapping of its action that still has the masked key: the one at its index, else the first not yet given back.
    -- Then the keymaps rebuilt. How many. The array is walked again at each call, its rows written in that call only:
    -- coop fly's AddActionMapping (its exec at 0x14478b400 on 26123051, an AddUnique on InputSettings' array) grows it
    -- through 0x140e6c0d0, which reallocates its buffer: a row kept from an earlier frame can point into freed memory.
    local function keys_back(records)
        local want={}
        for _,r in ipairs(records) do
            if r[1]=='key' then want[#want+1]={name=r[2],key=r[3],masked=r[4],at=tonumber(r[5])} end
        end
        if #want==0 then return 0 end
        local settings=StaticFindObject(SETTINGS)
        assert(g.valid(settings),'input settings unavailable')
        local rows={}
        settings.ActionMappings:ForEach(function(at,wrapped)
            local row=wrapped:get()
            rows[#rows+1]={at=at,row=row,name=row.ActionName:ToString(),key=row.Key.KeyName:ToString()}
        end)
        local n=0
        for _,k in ipairs(want) do
            local pick
            for _,m in ipairs(rows) do
                if not m.used and m.name==k.name and m.key==k.masked and (not pick or m.at==k.at) then pick=m end
            end
            if pick then pick.used=true; pick.row.Key.KeyName=FName(k.key); n=n+1 end
        end
        settings:ForceRebuildKeymaps()
        return n
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
        local saved,names,rows={},{},{} -- rows: the mappings to mask, written in this call only (keys_back)
        settings.ActionMappings:ForEach(function(at,wrapped)
            local row=wrapped:get()
            local name,key=row.ActionName:ToString(),row.Key.KeyName:ToString()
            if key~='None' and ((masked_key[key] and on_keys[name]) or masked_name[name]) then
                saved[#saved+1]={key=key,name=name,at=at}
                rows[#saved]=row
                names[#names+1]=name..'('..key..')'
            elseif set.native and name=='TPSMode' and key==cfg.aim_from then -- The game's aim moved to RMB.
                saved[#saved+1]={key=key,name=name,to=set.aim_key,at=at}
                rows[#saved]=row
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
            local back={}
            for _,e in ipairs(saved) do
                if e.changed then back[#back+1]={'key',e.name,e.key,e.to or 'None',tostring(e.at)}; e.changed=false end
            end
            local done,n=pcall(keys_back,back)
            g.log('input: '..(done and n..' of '..#back..' mappings put back'
                or 'mappings not put back ('..tostring(n)..')'))
        end
        local ok,err=pcall(function()
            for i,e in ipairs(saved) do e.changed=true; rows[i].Key.KeyName=FName(e.to or 'None') end
            settings:ForceRebuildKeymaps()
        end)
        if not ok then restore(); error(err) end
        g.log('input: masked '..table.concat(names,' '))
        return restore,saved -- saved: coop-gun.txt's key records (keep)
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
        local trace=g.find(TRACE)
        if not trace then return to end
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
        local cls,skel,static=g.find(MESH),g.find(SKEL),g.find(STATIC)
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
                        s.followed[addr]={c=c,to=src}
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
        s.hidden={}
        local p=g.pawn()
        local src=p and g.try(function() return p.Mesh end)
        for _,e in pairs(s.followed) do
            if g.valid(e.c) and g.valid(src) then pcall(function() e.c:SetMasterPoseComponent(src,true) end) end
        end
        s.followed={}
    end

    -- The drone (it fires the shots in the game's aim) hidden while the rifle is out: its mesh components
    -- bHiddenInGame, as race/doro.lua hides it; put back as they were. FindAllOf walks every object (race/doro.lua
    -- measured 25 to 40 ms), so it is looked for when the rifle comes out and again only when the one held goes (L1).
    -- None near her: none for the rest of this rifle out (s.drone false). A rifle out within DRONE_WAIT s of that miss
    -- looks once the wait is over. A new controller looks at once.
    local DRONE,DRONE_WAIT='CH_Drone_BP_C',10
    local function hide_drone(p,now)
        if s.drone==false or (s.drone and g.valid(s.drone.actor)) or now<(s.drone_wait or -1) then return end
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
        if not best then s.drone,s.drone_wait=false,now+DRONE_WAIT; return end
        local cls=g.find(MESH)
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
    -- fired: it looked right while firing) held near its start while aim is held and no shot is playing, so
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
    -- movement's own settings (no yaw written from Lua each frame: two writers made her legs twitch).
    local function unface()
        local f=s.facing
        s.facing=nil
        if f and g.valid(f.cm) then
            pcall(function() f.cm.bOrientRotationToMovement=f.orient; f.cm.bUseControllerDesiredRotation=f.desired end)
        end
    end
    local function face(p,on)
        local cm=g.try(function() return p.CharacterMovement end)
        if not g.valid(cm) then return end
        if on and not s.facing then
            s.facing={cm=cm,orient=cm.bOrientRotationToMovement,desired=cm.bUseControllerDesiredRotation}
            pcall(function() cm.bOrientRotationToMovement=false; cm.bUseControllerDesiredRotation=true end)
        elseif not on and s.facing then unface() end
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

    -- coop-gun.txt as gun mode's changes stand now (fight/gunmode/journal.lua): SB's rows (data.lua), the masked keys,
    -- the body meshes under the rifle layer (overlay.lua), her meshes hidden from her camera or following the posed
    -- copy, the drone's hidden parts, the carry stance, the posed stance's own changes (stance.lua) and out while the
    -- rifle is out; gone when nothing is changed. A line the file already holds is not written again. true when
    -- written (or with no file at all), else false and why, logged.
    local kept -- The line this load last wrote (false: cleared), so the same line is not written each second.
    local function keep()
        if not env.store then return true end
        local ok,why=pcall(function()
            local list=data.records()
            for _,k in ipairs(s.keys or {}) do list[#list+1]={'key',k.name,k.key,k.to or 'None',tostring(k.at)} end
            for _,r in ipairs(layer.records()) do list[#list+1]=r end
            for _,e in pairs(s.hidden) do
                local at=g.path(e.c)
                if at then list[#list+1]={'see',at,tostring(e.was)} end
            end
            for _,e in pairs(s.followed) do
                local at,to=g.path(e.c),g.path(e.to)
                if at and to then list[#list+1]={'follow',at,to} end
            end
            for _,c in ipairs(s.drone and s.drone.parts or {}) do
                local at=g.path(c)
                if at then list[#list+1]={'drone',at} end
            end
            local her=s.ovr_row and g.path(g.pawn())
            if her then list[#list+1]={'carry',her} end
            for _,r in ipairs(stance.records and stance.records() or {}) do list[#list+1]=r end
            if s.on then list[#list+1]={'out'} end
            local line=#list>0 and Journal.line(list)
            if line==kept then return end
            if line then
                local done,e=env.store.save(line)
                assert(done~=false,e or 'not written')
            else env.store.clear() end
            kept=line
        end)
        if not ok then g.log('coop-gun.txt not written: '..tostring(why)) end
        return ok,why
    end
    -- The rifle layer off every body mesh it went on (overlay.lua's list), her own post-process class back.
    local function layer_off(p)
        local ran,ok,e=pcall(layer.uninstall,p)
        if not (ran and ok~=false) then g.log('layer off: '..tostring(ran and e or ok)) end
    end
    -- What the rifle out changes, put back; also the parts a start took before it failed. SB's rows are the callers'.
    local function put_away()
        s.on=false
        pcall(stance.stop)
        if s.mask then pcall(s.mask) end
        s.mask,s.keys=nil,nil
        camera_back()
        unface()
        local pw=g.pawn()
        if pw then carry(pw,false) end
        if s.layer and pw then pcall(layer.stop,pw) end
        layer_off(pw)
        s.layer,s.layer_clip,s.reload_until,s.turn,s.turnq=false,nil,nil,nil,nil
        s.ovr_row=nil
        show_others()
        show_drone()
        pcall(ammo.stop)
        local pc=g.pc()
        if pc then pcall(fov,pc,false) end
    end
    local function disable(why)
        if not s.on then return end
        put_away()
        if s.native_taken then pcall(data.put_back); s.native_taken=false; aim.row=nil end
        keep()
        g.log('off ('..why..'), '..s.shots..' shots')
    end
    -- Everything back, SB's rows too, coop-gun.txt with it: a start that failed (L2), or stop.
    local function give_all_back()
        put_away()
        pcall(data.put_back); s.native_taken=false; aim.row=nil
        keep()
    end

    -- An SBO match (env.match) keeps the rifle away (M12): SBO's PvP rule refuses every hit from beyond 15 m whatever
    -- the move (native/src/game/pvp.h's kHitRangeCm, fight/enemies' defend()), while the rifle hits up to
    -- cfg.trace_range away. Until that rule takes rifle hits, a notice says so (ui/text.lua's gun.match).
    local MATCH='an SBO match runs: PvP hits past 15 m do not count yet'
    -- A notice on screen (env.notice; key: a word of ui/text.lua's gun, rebuilding when nil), at most one in 3 s.
    local function notice(now,key)
        if not (s.notice_at and now-s.notice_at<3) and env.notice and pcall(env.notice,key) then s.notice_at=now end
    end
    -- Why EVE cannot hold the rifle now (GunMode.blocked, env.busy, then env.match), or nil. A state it cannot read is
    -- a reason too.
    local function held(p)
        local ok,why=pcall(function()
            return GunMode.blocked(p,env.photo and env.photo() or '0') or (env.busy and env.busy())
                or (env.match and env.match() and MATCH) or nil
        end)
        if not ok then return 'her state is unreadable ('..tostring(why)..')' end
        return why
    end

    local function enable(why)
        self.restore() -- An earlier Lua load's changes back before this one reads the rows as they are.
        local pc,p=g.pc(),g.pawn()
        -- Each refusal says why on screen too (L4), in a word of ui/text.lua's gun; the log keeps the reason.
        if not (pc and p) then g.log('not now: no EVE'); notice(os.clock(),'eve'); return end
        if g.try(function() return p.TPSModeType~=0 or p.bTPSMode end) then
            g.log('not now: release the drone aim first'); notice(os.clock(),'aim'); return
        end
        local busy=held(p)
        if busy then
            g.log('not now: '..busy)
            notice(os.clock(),busy==MATCH and 'match' or 'busy')
            return
        end
        -- The rifle layer first. Without it, the rifle clips alone (cfg.pak_probe, in zNGMSpike_P): the aim stance's
        -- blend spaces point at the rifle's while the rifle is out. Her real body shows while aiming (nothing posed).
        -- Without either, Luke's posed stance.
        local okl,inst,why_not=pcall(layer.install,p)
        s.layer=okl and inst==true
        g.log('rifle layer '..(s.layer and 'on' or ('not available: '..tostring(okl and why_not or inst))))
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
        -- Each way out below gives back all it took (L2).
        if not data.take() then
            give_all_back()
            g.log('off: SB\'s rows could not be taken (see above)'); notice(os.clock(),'failed'); return
        end
        aim.setup()
        local ok,err=pcall(function() s.mask,s.keys=mask() end)
        if not ok then
            give_all_back(); g.log('off: the input mask failed ('..tostring(err)..')'); notice(os.clock(),'failed')
            return
        end
        ok,err=pcall(function()
            -- Held for Luke's aim: the aim key itself, not the game's aim stance, which drops for a frame now and
            -- then (each shot's skill, a jump) and made his arms jerk between carry and aim. Off the stance (a
            -- jump, a camp) his own turn to the camera keeps her facing the shot.
            -- With the animation pak her real body is shown while aiming, so held follows the game's aim stance
            -- (bridging its one-frame drops on shots: seen in the last 0.4 s with the key still down).
            if stance.single then
                s.rifle=stance.start(pc,function() return s.zoom_held or (s.key_held==true and s.aim_seen~=nil and os.clock()-s.aim_seen<0.4) end,
                    function() return s.target end)
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
            give_all_back()
            g.log('off: Luke\'s stance did not start ('..tostring(err)..')')
            notice(os.clock(),'failed')
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
        if set.native then pcall(hide_drone,p,os.clock()); s.native_taken=true end
        pcall(ammo.sync)
        if not keep() then
            give_all_back(); g.log('off: coop-gun.txt could not be written (see above)'); notice(os.clock(),'failed')
            return
        end
        g.log('on ('..why..')')
    end

    -- coop off (main/commands.lua): the rifle away, everything back, SB's rows and coop-gun.txt too; from then on gun
    -- mode does nothing (no key, no toggle, no reset) until the mod reloads.
    function self.stop(why)
        local was=s.on
        s.dead=true
        give_all_back()
        g.log('stopped ('..tostring(why)..')'..(was and ', '..s.shots..' shots' or ''))
    end

    function self.toggle(why)
        if s.dead then return end
        local now=os.clock()
        if now-s.toggle_at<0.3 then return end
        s.toggle_at=now
        -- Parked while it is rebuilt: the toggle says so on screen and nothing else of gun mode runs (no rows taken,
        -- no rifle, no posed copy).
        if cfg.enabled==false and not Overlay.available() then
            if s.on then disable(why) end
            g.log('toggle ('..why..'): gun mode is being rebuilt, off')
            notice(now)
            return
        end
        if s.on then disable(why); return end
        local ok,e=pcall(enable,why)
        if not ok then give_all_back(); g.log('off: the start failed'); notice(now,'failed'); error(e,0) end
    end

    -- Each shot: the bullet's destination made the crosshair point, then the shot's row.
    local function shoot(p,now)
        if now<s.next_shot then return end
        s.next_shot=now+cfg.fire_interval
        if not data.armed then
            if not data.arm() then s.next_shot=now+cfg.arm_hold; return end -- Tried again a second later, not each shot.
            keep()
        end
        s.armed_until=now+cfg.arm_hold
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
        if now<s.pause then pcall(dpad.hide); return end -- A new controller put the rifle away.
        if s.give_back then -- A new controller's deferred reset: the rows and the layer back (L3), the file with them.
            s.give_back=false; pcall(data.put_back); aim.row=nil
            layer_off(g.pawn())
            keep()
        end
        if s.stop_stance then s.stop_stance=false; pcall(stance.stop) end
        if s.show_back then s.show_back=false; show_others(); show_drone(); unface(); keep() end
        if s.ammo_reset then s.ammo_reset=false; pcall(ammo.stop); pcall(ammo.refill) end
        local pc=g.pc(); if not pc then return end
        -- Paused (the pause menu and its options among others): the mask lifted until the game runs again. SB's
        -- KeyMapping option (its save 0x14222dec0 on 26123051) writes the player input's mappings (+0x140 and +0x150,
        -- through 0x1423d04d0) into its settings. ForceRebuildKeymaps (0x144664bb0) copies them there from the input
        -- settings: a masked key would be saved as the player's own. The rifle away with nothing of it held (no mask,
        -- no armed rows) asks only at a toggle, which a pause refuses: no game call a frame for it then (M2).
        local idle=not s.on and not s.mask and not s.armed_until
        local function paused() return g.try(function() return g.find(STATICS):IsGamePaused(pc) end)==true end
        if not idle and paused() then
            pcall(dpad.hide) -- No ammo tick runs while paused: the slot shows again at the first frame after.
            if s.mask then
                pcall(s.mask)
                s.mask,s.keys=nil,nil
                keep()
            end
            if s.armed_until then s.armed_until=math.max(s.armed_until,now+cfg.arm_hold) end -- SB's events wait too
            return
        end
        if s.on and not s.mask then
            local ok,err=pcall(function() s.mask,s.keys=mask() end)
            if not ok then disable('the input mask failed ('..tostring(err)..')'); return end
            keep()
        end
        -- The shot's borrowed rows back once its last zone event has had its time (M4).
        if s.armed_until and now>=s.armed_until then
            s.armed_until=nil
            if data.armed then data.disarm(); keep() end
        end
        local function down(name) return g.try(function() return pc:IsInputKeyDown({KeyName=FName(name)}) end)==true end
        -- The rifle away: the toggle keys only. The game's own aim (gun_fire=native) reads its zoom keys itself (M2).
        local inp=Input.read(keys,down,now,cfg,set.key,not s.on,set.native)
        if (inp.key or inp.toggle) and not (idle and paused()) then
            if inp.key then self.toggle(set.key.name) else self.toggle('D-pad Right') end
        end
        -- (dev only) The facts probe waits out a pause as it did before the pause was asked only at a toggle: its F8
        -- plays a clip on her and its F11 swaps her body mesh's post-process class.
        if set.facts and not (idle and paused()) then
            s.facts=s.facts or require('fight.gunmode.facts').new(g)
            local ok,e=pcall(s.facts.tick,pc,g.pawn(),down,now)
            if not ok and not s.facts_err then s.facts_err=true; g.log('facts: '..tostring(e)) end
        end
        if not s.on then return end
        local p=g.pawn()
        if set.g0 and p and g.valid(s.rifle) then
            s.g0=s.g0 or require('fight.gunmode.g0').new(g)
            local ok,e=pcall(s.g0.tick,pc,p,s.rifle,s.want or 'carry',now)
            if not ok and not s.g0_err then s.g0_err=true; g.log('g0: '..tostring(e)) end
        end
        if not p then disable('no EVE'); return end
        -- A cutscene, a talk, a swim or another of the game's own states that starts puts the rifle away (M6), as does
        -- another module that takes EVE (M7: the Doro look, an emote...).
        if now-(s.held_at or 0)>=0.25 then
            s.held_at=now
            local busy=held(p)
            if busy then
                disable(busy)
                if busy==MATCH then notice(now,'match') end
                return
            end
        end
        if set.native then -- Firing mode is the game's own aim: held while EVE is in it.
            -- Firing mode: the game's aim, or a jump out of it with the aim key still held (the game drops its aim
            -- stance in the air and takes it up again only at a new press): from the jump until the key is let go the
            -- rifle stays up and gun mode fires the NIKKE shot itself (shoot), on the ground again too.
            local tps=g.try(function() return p.bTPSMode end)==true
            if tps then s.aim_seen=now end
            local key_held=down(set.aim_key) or down('Gamepad_LeftTrigger')
            s.key_held,s.tps=key_held,tps
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
            if s.air_aim and inp.fire and ammo.left>0 and not ammo.reload_until then pcall(shoot,p,now) end
            local before=ammo.left
            local ok_a,err_a=pcall(ammo.tick,s.zoom_held,inp.fire,now)
            -- The muzzle flash on Luke's rifle, once a frame that rounds went out: the NIKKE shot's own flash is on
            -- the NIKKE rifle of her hidden real body (the fire round her waist), which the pak's show drops.
            if ok_a and ammo.left<before and g.valid(s.rifle) and now-(s.flash_at or 0)>=cfg.muzzle_every then pcall(function()
                s.flash_at=now
                s.flash_lib=g.find('/Script/Niagara.Default__NiagaraFunctionLibrary')
                -- Found by its path at each flash, else loaded again, as laser.lua finds its own: nothing of the game
                -- holds it between shots, so the engine can collect it. A reference kept from an earlier flash then
                -- still passes IsValid once another object sits at the freed address.
                s.flash_fx=StaticFindObject(cfg.muzzle_fx)
                if not g.valid(s.flash_fx) then s.flash_fx=LoadAsset(cfg.muzzle_fx) end
                if g.valid(s.flash_lib) and g.valid(s.flash_fx) then
                    local fx=s.flash_lib:SpawnSystemAttached(s.flash_fx,s.rifle,FName('FX_Fire'),{X=0,Y=0,Z=0},{Pitch=0,Yaw=0,Roll=0},2,true,true,0,false)
                    if g.valid(fx) then local k=cfg.muzzle_scale; fx:SetRelativeScale3D({X=k,Y=k,Z=k}) end
                end
            end) end
            if not ok_a and not s.ammo_err then s.ammo_err=true; g.log('ammo: '..tostring(err_a)) end
            if probe then pcall(probe.tick,pc,p,s.zoom_held,inp.fire,now) end
        elseif set.zoom_toggle then
            if inp.zoom_press then s.zoom_held=not s.zoom_held end
        else s.zoom_held=inp.zoom end
        -- The point under the screen centre only while she aims, the only time it is read (M13): two traces a frame.
        s.target=(s.zoom_held or s.key_held==true) and crosshair(pc,p) or nil
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
                    keep() -- Her new body mesh listed.
                end
            end
            if s.reload_until and now>=s.reload_until then s.reload_until=nil end
            local want=s.reload_until and 'reload' or (s.zoom_held and 'aim' or 'carry')
            -- the game's own moves (dodges, evades, hit reactions, knockdowns) get her arms back: the layer's clip
            -- stops and the aim turn eases out until the move ends
            if now-(s.move_at or 0)>=0.1 then
                s.move_at=now
                local nm=g.try(function()
                    local m=p.Mesh:GetAnimInstance():GetCurrentActiveMontage()
                    return m and m:IsValid() and m:GetFName():ToString() or nil
                end)
                s.move=nm and (nm:find('[Ee]vade') or nm:find('[Dd]odge') or nm:find('[Aa]void') or nm:find('[Hh]it')
                    or nm:find('[Dd]amage') or nm:find('[Dd]own') or nm:find('[Kk]nock') or nm:find('[Ss]tun') or nm:find('[Rr]oll')
                    or nm:find('[Ff]lip') or nm:find('[Dd]ash') or nm:find('[Pp]arry') or nm:find('[Gg]uard') or nm:find('[Ss]lide')) and nm or nil
                if set.trace and nm~=s.last_montage then s.last_montage=nm; g.log('layer: montage '..tostring(nm)..(s.move and ' (layer steps aside)' or '')) end
            end
            if s.move then want='none' end
            s.want=want
            -- the game's aim stance (P_Eve_Gun) may switch her post-process graph off and hide what her hands hold: both
            -- are put back while the rifle is out (property reads and plain setters only, nothing on the instance itself)
            local mesh=g.try(function() return p.Mesh end)
            if g.try(function() return mesh.bDisablePostProcessBlueprint end)==true then
                local ok=pcall(function() mesh:SetDisablePostProcessBlueprint(false) end)
                if not s.pp_logged then s.pp_logged=true; g.log('layer: the game disabled post-process ('..want..'), re-enabled: '..tostring(ok)) end
            end
            if g.valid(s.rifle) then
                local vis=g.try(function() return s.rifle:IsVisible() end)
                local hid=g.try(function() return s.rifle.bHiddenInGame end)
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
                    local ml=StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
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
            -- The rifle-first solver places the rifle and puts both hands on it (fight/gunmode/ik.lua)
            s.ik=s.ik or require('fight.gunmode.ik').new(g)
            local ppi=g.try(function() return p.Mesh:GetPostProcessInstance() end)
            local mode_ik=(want=='aim') and 'aim' or ((want=='carry' or want=='reload') and 'carry' or 'off')
            local ok_i,err_i=pcall(s.ik.tick,pc,p,s.rifle,mode_ik,ppi)
            if not ok_i and not s.ik_err then s.ik_err=true; g.log('ik: '..tostring(err_i)) end
            if s.layer_clip and s.layer_clip~='none' and now-(s.layer_seen or 0)>=0.25 then
                s.layer_seen=now
                if not layer.playing(p,s.layer_clip) then
                    s.layer_stops=(s.layer_stops or 0)+1
                    if s.layer_stops<=3 or s.layer_stops%50==0 then g.log('layer: '..s.layer_clip..' was stopped ('..s.layer_stops..'), played again') end
                    s.layer_clip=nil
                end
            end
            if want~=s.layer_clip then
                local m,e
                if want=='carry' then m,e=layer.play(p,'carry',1.0,0,0.2,0.2)
                elseif want=='aim' then m,e=layer.play(p,'aim',1.0,0,0.12,0.15)
                elseif want=='none' then layer.stop(p,0.12); m=true
                else m,e=layer.play(p,'reload',1.0,0,0.1,0.15) end
                if m then s.layer_clip=want elseif not s.layer_err then s.layer_err=true; g.log('layer clip '..want..': '..tostring(e)) end
            end
        end
        if now-s.hide_at>=1.0 then
            s.hide_at=now
            pcall(hide_others,p,false)
            if set.native then pcall(hide_drone,p,now) end
            keep() -- A mesh or a drone hidden this second listed.
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
        if s.ovr_row then carry(p,not s.zoom_held) end
        if not set.native and inp.fire and s.held_since and now-s.held_since>=cfg.raise_time then shoot(p,now) end
    end

    -- The tick main/frame.lua runs each frame. Nothing at all with gun_mode=off.
    function self.tick()
        if not set.on or s.dead then return end
        local ok,e=pcall(tick)
        if not ok and s.errors<5 then s.errors=s.errors+1; g.log('error: '..tostring(e)) end
    end

    -- A new controller (map load, death, camp warp), from fight/gunmode/wiring.lua's NotifyOnNewObject: the rifle goes
    -- away and SB's rows go back. Nothing here calls into the game: the controller is still being built (reading its
    -- pawn from this callback crashed UE4SS). Nothing at all with gun_mode=off.
    function self.new_controller(pc)
        if not set.on or s.dead then return end
        cached=pc
        s.pause=os.clock()+4.0
        s.give_back=true
        if s.on then
            s.on=false
            if s.mask then pcall(s.mask); s.mask=nil end
            s.keys=nil
            s.cam,s.zoom=nil,0
            s.fov,s.fov_locked=nil,false
            s.ammo_reset=true
            s.stop_stance=true
            s.show_back=true
        end
        -- The old pawn's state goes with it (L3): the next start begins clean on the new one. Its drone parts and her
        -- facing go back at the deferred reset (show_back); its layer comes off there (give_back).
        for _,k in ipairs(PER_PAWN) do s[k]=nil end
        s.ovr,s.layer,s.zoom_held=false,false,false
    end

    -- An earlier load's changes to objects that are still there, each found by its path (StaticFindObject, as
    -- online/modes/race/doro.lua's restore finds EVE and the drone). On 26123051: her meshes shown to her own camera as
    -- they were (SetOwnerNoSee, exec 0x1448f0d20, writes bOwnerNoSee, bit 0x20 of UPrimitiveComponent+0x28e) with
    -- their tick option; the drone's parts shown (SetHiddenInGame, exec 0x14490b100); a mesh that followed the posed
    -- copy on her body again (SetMasterPoseComponent, exec 0x144928a80); the carry stance off
    -- (DeactiveCustomMovingStanceData: exec 0x14268c890 jumps to 0x1421287a0, which does nothing unless the flag at
    -- +0xf40 that ActiveCustomMovingStanceData's 0x1421282d0 sets is on, then clears it). Then the posed copy's parts
    -- and holder destroyed (K2_DestroyComponent 0x1446c1340, K2_DestroyActor 0x1446bf590). How many were put back or
    -- removed.
    local function objects_back(list)
        local function at(path)
            local o=path and g.try(function() return StaticFindObject(path) end)
            if g.valid(o) then return o end
        end
        local n=0
        local function done(ok) if ok then n=n+1 end end
        for _,r in ipairs(list) do
            local o=(r[1]=='see' or r[1]=='drone' or r[1]=='follow' or r[1]=='carry') and at(r[2])
            if o and r[1]=='see' then
                done(pcall(function()
                    o:SetOwnerNoSee(r[3]=='true')
                    if tonumber(r[4]) then o.VisibilityBasedAnimTickOption=tonumber(r[4]) end
                end))
            elseif o and r[1]=='drone' and g.try(function() return o.bHiddenInGame end)==true then
                done(pcall(function() o:SetHiddenInGame(false,false) end))
            elseif o and r[1]=='follow' then
                local to=at(r[3])
                done(to and pcall(function() o:SetMasterPoseComponent(to,true) end))
            elseif o and r[1]=='carry' then
                done(pcall(function() o:DeactiveCustomMovingStanceData() end))
            end
        end
        for _,r in ipairs(list) do
            local o=(r[1]=='part' or r[1]=='holder') and at(r[2])
            if o and r[1]=='part' then done(pcall(function() o:K2_DestroyComponent(o) end))
            elseif o then done(pcall(function() o:K2_DestroyActor() end)) end
        end
        return n
    end

    -- Once a Lua load, at main/frame.lua's first tick (coop off or not) and before a start: what coop-gun.txt says an
    -- earlier load left changed goes back (H4): SB's rows, the masked keys, the objects objects_back puts back, her
    -- body meshes' own post-process class (the one she wears rebuilt with it) and, when the rifle was out, its tagged
    -- rifle and the FOV lock. Then the file holds what this load has changed: the body meshes whose own class could not
    -- go back. A row or key that failed is logged, not kept.
    function self.restore()
        if restored or not env.store then return end
        restored=true
        local list=Journal.records(env.store.load())
        if #list==0 then return end
        local said={}
        local n,why=Data.put_back_records(g,list)
        said[#said+1]=n..' fields of SB\'s rows back'..(why and ' (failed: '..why..')' or '')
        local ok,keys=pcall(keys_back,list)
        said[#said+1]=ok and keys..' keys back' or 'keys not put back ('..tostring(keys)..')'
        said[#said+1]=objects_back(list)..' objects put back or removed'
        local out=false
        for _,r in ipairs(list) do
            if r[1]=='pp' then layer.adopt(r[2],r[3]) elseif r[1]=='out' then out=true end
        end
        layer_off(g.pawn())
        if out then
            local swept,count=pcall(Rifle.sweep,g.pawn())
            said[#said+1]=swept and count..' rifles removed' or 'rifle not removed ('..tostring(count)..')'
            local pc=g.pc()
            said[#said+1]=pc and pcall(function() pc:FOV(0) end) and 'FOV lock off' or 'FOV lock not reached'
        end
        keep()
        g.log('restore from coop-gun.txt: '..table.concat(said,', '))
    end

    for _,why in ipairs(bad) do g.log('coop-settings.txt: '..why) end
    if set.on then g.log('ready: '..(set.key.key and set.key.name..' or ' or '')..'a tap of D-pad Right')
    else g.log('off (gun_mode=off in coop-settings.txt)') end

    function self.status()
        return ('gun mode %s%s, key %s, %d shots'):format(s.on and 'on' or 'off',
            s.on and (s.zoom_held and ' (firing mode)' or ' (moving)') or '',set.key.name,s.shots)
    end
    self.toggle_now=function() self.toggle('command') end
    -- The D-pad rifle slot's kit group, from the manifest's hud build step (main/ui.lua): h {kit, theme}. Its place is
    -- cfg.slot_x and cfg.slot_y. Nothing with gun_mode=off.
    function self.hud(h)
        if not set.on then return end
        slot=require('fight.gunmode.ui.slot').new({kit=h.kit,theme=h.theme,log=g.log,x=cfg.slot_x,y=cfg.slot_y})
    end
    function self.out() return s.on==true end -- The bike's busy check reads it (vehicles/bike/wiring.lua).
    self.state=s
    return self
end

return GunMode
