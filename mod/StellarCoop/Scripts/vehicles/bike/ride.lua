-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The bike on the game thread: SB's Adam_Vehicle_02 as a part on EVE's own actor with her ride on it, on any save
-- (where she leaves it is kept per save: the parked bike below). With bike=on the native part preloads the mesh and the
-- riding clip once ("bike load", native/src/game/bike.h; the bike= word of the status line says ready), asked again
-- while that word still reads off 5 s after the ask (a request lost on the way). Once that is ready and an EVE has been
-- in the world 2 s, the part is made: one SkeletalMeshComponent hung KeepRelative on her main mesh at the seat
-- (core/actors.lua's attach: collision off, single-node mode with no clip, so it keeps its reference pose), hidden, its
-- tick off, tagged Ride.TAG. After Ctrl+R the part is already there: the new Lua load's first tick (self.restore) finds
-- it among her components by its mesh and that tag, whatever the bike= word or the setting says. That load uses it
-- again; its first 250 ms pass removes it at bike=off. While she rides, the capture sends it to every ghost like any
-- part of her outfit. While she does not, self.idle_part names it and the capture leaves it out (main.lua): hidden, it
-- would take one of the ghost's 16 parts.
-- A mount (self.toggle) checks EVE first and refuses with its reason; then, in this order: coop-bike.txt (her object
-- path, her main mesh's relative rotation and location, or those of a file this Lua load kept for her),
-- vehicles/bike/drive.lua's drive with vehicles/bike/model.lua (why 'bike'), "bike gate on" (SB's actions off on her
-- controller, Jump left on), "anim play <id> <clip> ride" (the riding clip looped, her foot IK off) and the part shown.
-- A dismount runs it backward: the part hidden, "anim stop", "bike gate off", the drive off, her mesh's rotation and
-- location back, the file cleared. A dismount comes from the key, the pad, coop bike, coop off, bike=off, a new EVE, a
-- check every 250 ms (self.slow) and a failure; the next Lua load replays the file at its first tick (self.restore)
-- when this one could not (Ctrl+R). The native part turns the gate off and stops the clip itself at a new Lua load.
-- The parked bike is a second actor (vehicles/bike/stand.lua), one per EVE, made hidden after her part under the same 2
-- s gate.
-- A dismount by the key, the pad or coop bike leaves it where she stands when her floor counts (walkable, its base not
-- Movable). Any other dismount leaves it at the last ground pose the 250 ms checks kept, else where it stood before
-- the mount. Its actor's path goes to coop-bike-stand.txt: after Ctrl+R the new Lua load's first tick sweeps that
-- actor; when she rode, it parks the bike where she stands if her floor counts. coop off and bike=off take it out of
-- the world with its place kept; bike=on puts it back. Its place is kept per Steam account and save in
-- coop-bike-<steamid>-<saves><index>.txt (vehicles/bike/park.lua's key and line), written at each park that moves it;
-- the 250 ms pass reads it once each time that key changes, while she does not ride, so a park forced by a load writes
-- the save she rode in. A park made before the first key is written at that key instead of read from it. Without a key
-- (an unpinned build, saves=off, no link) the place lives in memory. While an SBO lobby is open no record is read or
-- written: it starts with no place; leaving it reads the save's record again. It shows on its map once her EVE stood
-- 2 s, while she does not ride and no cutscene holds her. With a place, a mount after EVE's own checks is refused while
-- the bike is on another map, not shown yet on hers or out of reach (her capsule over 50 cm from its body or her feet
-- over 100 cm up or down: vehicles/bike/park.lua), with its distance and side from her camera. Within reach the bike is
-- hidden, then her actor is teleported so the part lands on its root and heading (a teleport SB refuses mounts her
-- where she stands), then the mount above. A notice tells bike_key once each time she comes within reach of it. Her
-- bike line (vehicles/bike/park.lua's wire) goes to the link at each change, from a mount, a dismount or the 250 ms
-- pass: none while she rides, with bike=off or without a place.
-- At an activated Xion camp (online/group/travel.lua's camp_near, within CAMP m), outside an SBO lobby, the refusal for
-- a bike out of reach or on another map offers the paid fetch (vehicles/bike/fetch.lua): a second press within
-- Fetch.WINDOW s pays Fetch.PRICE betacrystal. While it runs every press is refused with that; once paid the bike
-- stands where she stood at the offer (her pose as a park takes it, else her feet with her actor's yaw), written and
-- sent as a park.
-- Its lines name the money as SB does in the screen's language (Gold in English), else Fetch.WORD.
-- Each frame (self.steer, before the native tick): the drive's frame, then her lean and pitch on her main mesh's
-- relative rotation, the base rotation then a turn about her actor's forward axis (lean) and side axis (pitch), through
-- KismetMathLibrary's ComposeRotators, written with teleport off (a teleport clears cloth inertia). The ghosts get it
-- through her mesh's transform. Every 250 ms (self.slow) the anim answer from that pass's status text: the clip played
-- again when SB ended it, unless the photo mode, a skill or a root-motion move holds her; three ends within 1 s take
-- her off the bike (SB uses the slot).
-- Once a second the part and the parked bike take the paint vehicles/bike/paint.lua lists for EVE's body mesh (the
-- outfit she wears); coop off puts the part's own materials back.
-- What it writes on the player's own EVE: the part, her main mesh's relative rotation (and its location back at the
-- end), what vehicles/bike/drive.lua writes; through the native part SB's per-action switches and the custom animation
-- slot.
-- Parts of this file adapt Eve On Wheels 1.2.1 by dCharisma1 (nexusmods.com/stellarblade/mods/4165), used with his
-- written consent given on 2026-11-16. They are licensed here under the SBO License 1.0 or any later version the
-- Licensor publishes (NOTICE). No file of Eve On Wheels ships with Stellar Blade Online.
local UE=require('UEHelpers')
local U=require('core.unreal')
local B=require('vehicles.bike.model')
local Doro=require('core.actors')
local Park=require('vehicles.bike.park')
local Stand=require('vehicles.bike.stand')
local Fetch=require('vehicles.bike.fetch')
local Paint=require('vehicles.bike.paint')
local T=require('ui.text')
local valid,value_of,each,find,address,why_of=U.valid,U.value_of,U.each,U.find,U.address,U.why
local Ride={}
-- SB's bike (37 bones, no wheel bone; its skeleton, physics asset and four material instances come with it).
Ride.MESH='/Game/Art/Character/ETC/Adam_vehicle_02/Adam_Vehicle_02.Adam_Vehicle_02'
-- The component tag that marks SBO's own part, so another mod's component on the same mesh is never taken for it.
Ride.TAG='SBO_Bike'
-- The riding clip, one of EVE's clips (the native part plays only those): SB has no driver clip for her, so this is the
-- pillion pose asleep on the bike of the SD20 scene, 301 frames at 30 fps with no root motion. The one place to change
-- it.
Ride.CLIP='/Game/Art/Character/PC/CH_P_EVE_01/Animation/event/G03/MV_SD20_AfterBruteBattle_Main/eve/'
    ..'eve_bikeSleepPose.eve_bikeSleepPose'
-- The bike relative to her main mesh, cm and degrees: SD20's attach tracks (riders on its bone Base).
local SEAT,SEAT_PITCH={X=1.53,Y=0.52,Z=2.95},0.69
local SETTLE=2 -- s an EVE has been in the world before her part is made (the capture's own wait).
local ANSWER=5 -- s with no answer for our play.
local ENDS,ENDS_IN=3,1 -- SB's ends of the riding clip within ENDS_IN s that take her off the bike.
local GATE_WAIT=1 -- s after the mount by which the gate must read on.
local LOAD_AGAIN=5 -- s with bike=off after the bike load before it is asked again.
-- A right turn (the yaw growing) leans her right, a climb lifts the nose. Signs to check in the first ride.
local LEAN_SIGN,PITCH_SIGN=1,1
local TILT_STEP=0.05 -- degrees: a smaller change of the lean or the pitch is not written.
local WALKING,NAV_WALKING,FALLING,SWIMMING,CUSTOM=1,2,3,4,6 -- EMovementMode.
local MOVABLE=2 -- EComponentMobility: a base she stands on that moves (a lift, a train, a pawn) is no floor.
local SKINNED='/Script/Engine.SkeletalMeshComponent'
local MAX_ID=4294967295
local CAMP=10 -- m from an activated Xion camp's spawn point for the paid fetch.
local FEED=200 -- Bytes a line of the chat's feed holds (online/session/chat.lua's MAX).

-- The native status line's words for the bike: warp (idle or busy), anim and its id, the preload (bike=), the gate
-- (bike_gate=) and EVE's life state (bike_life=, nil when it did not read); nil without an engine line (no native part).
function Ride.native(status)
    local line=('\n'..(status or '')):match('\nengine=([^\r\n]*)')
    if not line then return nil end
    local anim,id=line:match(' anim=(%S+) anim_id=(%d+)')
    local load,gate=line:match(' bike=(%S+) bike_gate=(%S+)')
    return {warp=line:match(' warp=(%a+)'),anim=anim,id=tonumber(id),load=load,gate=gate,
        life=tonumber(line:match(' bike_life=(%d+)'))}
end
-- The preload's word as a refusal, or nil when it is ready.
function Ride.loaded(word)
    if word=='ready' then return nil end
    if word=='loading' then return 'the bike is still loading' end
    if word=='fault' then return "the bike's native side stopped until the game restarts (a fault)" end
    local failed=(word or ''):match('^failed:(.+)$')
    if failed then return 'the bike did not load ('..failed..')' end
    return 'the bike is not loaded (bike=off, or not asked yet)'
end

local function path_of(o) return o:GetFullName():match('^%S+ (.+)$') end
local function her() return U.her(valid(UE.GetPlayer())) end
local function math_lib() return find('/Script/Engine.Default__KismetMathLibrary') end
-- EVE's body mesh as an object path (the paint's key). Raises when it does not read.
local function body_of(e) return path_of(valid(valid(e.Mesh).SkeletalMesh)) end
-- The bike part an earlier Lua load made on EVE: her skeletal mesh component that shows Ride.MESH and carries
-- Ride.TAG, else nil.
local function find_part(e)
    local found=nil
    each(e:K2_GetComponentsByClass(find(SKINNED)),function(_,c)
        c=valid(c)
        local mesh=c and valid(c.SkeletalMesh)
        if not found and mesh and path_of(mesh)==Ride.MESH and c:ComponentHasTag(FName(Ride.TAG))==true then
            found=c
        end
    end)
    return found
end
-- A new part on her main mesh at the seat, hidden, tagged, its tick off: its reference pose needs none and her mesh
-- moves it (online/modes/race/doro.lua's keepers do the same). Raises, with nothing left, when it cannot be made. Also
-- returns why the tag did not hold (nil when it did): the part still serves this Lua load, only a Ctrl+R cannot
-- find it again.
local function make_part(e)
    local mesh=assert(valid(e.Mesh),'EVE has no main mesh')
    local c=Doro.attach(e,mesh,{path=Ride.MESH}).mesh
    local ok,why=pcall(function()
        c:K2_SetRelativeLocationAndRotation(SEAT,{Pitch=SEAT_PITCH,Yaw=0,Roll=0},false,{},false)
        c:SetVisibility(false,false)
        c:SetComponentTickEnabled(false)
        c.VisibilityBasedAnimTickOption=3 -- OnlyTickPoseWhenRendered
    end)
    if not ok then
        pcall(function() c:K2_DestroyComponent(e) end)
        error(why,0)
    end
    -- A new component's ComponentTags is empty: UE4SS 3.0.1 lands a write at 1 there
    -- (world/maps/matrix13/level/move.lua), proven for uint8 arrays only. A tag that does not hold costs only the
    -- Ctrl+R find, so the part is kept.
    local tagged,tag_why=pcall(function()
        c.ComponentTags[1]=FName(Ride.TAG)
        assert(c:ComponentHasTag(FName(Ride.TAG))==true,'it did not hold')
    end)
    return c,not tagged and why_of(tag_why) or nil
end
local number=Park.number
local function whole(v) return math.floor(v+0.5) end
-- The tab-separated fields of a coop-bike.txt line (none for nil).
local function fields(line)
    local f={}
    for field in ((line or '')..'\t'):gmatch('([^\t]*)\t') do f[#f+1]=field end
    return f
end

-- o: log (the [BK] lines); ask(line) (a native request: ok and its line); status() (the native status text); store
-- (coop-bike.txt through link.store); stand_store (coop-bike-stand.txt, her parked bike's path); drive
-- (vehicles/bike/drive.lua's); settings (main.lua's: bike, false for off); paused() (the game paused or on one of its
-- screens); photo() ('0', '1' in photo mode, 's' in the selfie mode); frozen() (the partner's photo mode holds our
-- game); life() (link.life's {state}, or nil; only the fallback for the status line's bike_life=, since it reads only
-- in a session); armed() (online/modes/race/run.lua's: a race is armed here; nil when there is none); busy() (why SBO's
-- own state forbids a mount: the Doro look, coop emote, a hall seat, coop fly or glide, Night Operation, an SBO menu or
-- the chat; nil when none); words() (ui/text.lua's table for the screen); tell(build) (a notice build(words) puts
-- together); worlds (core/worlds.lua's table, for a map's name); file (the place's record: read(name) and write(name,
-- text), link.read_file and link.write_file; nil without the link); lobby() (whether an SBO lobby is open);
-- send(payload) (her bike line to the link, link.bike: true once written; nil without the link); camp(world, metres)
-- (online/group/travel.lua's camp_near, nil without the link); fetch (vehicles/bike/fetch.lua's, nil without the link);
-- game_text(key, table) (SB's text for a string table's key in the game's language, nil when unread or with
-- ui_language=english); drove() (online/modes/race/drive.lua's active: whether the races' drive runs).
function Ride.new(o)
    local log,ask,status,drive=o.log,o.ask,o.status,o.drive
    local none={save=function() end,load=function() end,clear=function() end}
    local store,stand_store=o.store or none,o.stand_store or none
    local self={}
    local values=B.clamp(B.DEFAULTS) -- coop bike tune changes them for this Lua load.
    -- The part on the EVE seen last: {at, path, since (os.clock), part, part_path, failed}, with her parked bike there
    -- (stand, or stand_failed), the map it was made on (map) and whether her feet were within its reach at the last
    -- 250 ms pass (near; true while she rides, so getting off tells nothing).
    local here=nil
    local place=nil -- Her bike's place ({map, at, rot}), in memory.
    local file,lobby=o.file,o.lobby or function() return false end
    local key=nil -- The record's file read last (vehicles/bike/park.lua's key), nil before the first and after an SBO
    -- lobby.
    local dirty=false -- A park in memory that no record holds (no key yet, or its write failed).
    local in_lobby=false -- lobby() at the last 250 ms pass with her off the bike.
    local ground=nil -- The last ground pose of this ride, kept every 250 ms.
    local floor_told=false
    -- While she rides: eve, path, at, mesh, part, part_path, base and base_at (her mesh's relative rotation and
    -- location before), lean and pitch (as written), math (KismetMathLibrary, looked up once a ride), since, what the
    -- mount did (drove, gated, shown), id (the play's), asked (os.clock of its ask), playing, ended (this id's end
    -- counted), ends (os.clock of each end).
    local ride=nil
    local preload=nil -- What the setting last asked of the native part: true (bike load), false (bike free).
    local load_asked=0 -- os.clock of the last bike load.
    local restored=false
    local serial=2000000000+os.time()%1000000 -- Apart from coop emote's ids, which start under 1000000.
    local sent=nil -- Her bike line as the link last took it.
    local offer=nil -- The paid fetch offered at the last refusal: {due (os.clock), pose, camp}.
    local paying=nil -- The offer being paid for, while o.fetch runs.
    local paint=Paint.new({log=log}) -- The part's and the parked bike's paint for her outfit.

    -- The check before a mount (mount true) and every 250 ms while she rides: why she cannot ride now, or nil. w: the
    -- native words. While she rides, the air, a skill, combat, aiming and the free camera are no reason: SB's actions
    -- are off, so she cannot fight from the saddle.
    local function blocked(e,w,mount)
        if not (w and w.load) then return 'the bike needs the native part' end
        if w.warp and w.warp~='idle' then return 'a load or a warp is under way' end
        local photo=o.photo()
        if photo=='s' then return 'the selfie mode is open' end
        if mount then
            if o.paused() then return 'the game is paused or shows one of its screens' end
            if photo~='0' then return 'the photo mode is open' end
            if o.frozen() then return "your friend's photo mode holds the game" end
        end
        if e:IsAttachedToLevelSequenceWithoutPlayable()==true then return 'a cutscene holds EVE' end
        if e:IsRunningInteraction()==true or e.bEnableInteractionBlock==true then return 'EVE is in an interaction' end
        if e:IsMoveInputBlock()==true then return 'the game holds her movement' end
        -- MovementMode covers SB's own moves. Swimming is MOVE_Swimming. The event moves, ladders, ropes, beams, wires
        -- and grabs are custom modes (IsEventMoving and its siblings read the custom mode; SB's IsClimbing always
        -- answers false in this build).
        local mode=value_of(valid(e.CharacterMovement).MovementMode)
        if mode==SWIMMING then return 'EVE is swimming' end
        if mode==CUSTOM then return "EVE is in one of SB's moves (a ladder, a rope, a beam, a wire or an event)" end
        if mount then
            if mode==FALLING then return 'EVE is in the air' end
            if mode~=WALKING and mode~=NAV_WALKING then
                return 'EVE cannot move now (movement mode '..tostring(mode)..')'
            end
            if e:IsRunningSkill()==true then return 'a skill runs (an attack or a dodge)' end
            if e:IsBattle()==true then return 'EVE is in combat' end
        end
        if (tonumber(e:GetFishingModeType()) or 0)~=0 then return 'EVE is fishing' end
        if mount then
            if e:IsTPSMode()==true then return 'EVE aims' end
            if e.bFreeCamMode==true then return 'the free camera is on' end
        end
        if valid(e.VehicleActor) then return "EVE is on one of the game's lifts or trains" end
        -- Her own life state from the native part, on any save; link.life() (a session's) when it did not read.
        local life=w.life or (o.life() or {}).state
        if life and life>=3 and life<=5 then return 'EVE is down' end
        return nil
    end
    -- The part for EVE (the one seen last), or nil and why.
    local function part_for(e)
        if here and here.at==address(e) and here.part and Doro.same(here.part,here.part_path) then return here.part end
        if here and here.failed then return nil,'the bike part could not be made ('..here.failed..')' end
        return nil,'the bike is still loading'
    end
    -- Every 250 ms: once bike=ready and EVE has been in the world SETTLE s, her part found or made, once for her, then
    -- her parked bike made, hidden. A new EVE takes the old one's parked bike out of the world first.
    local function part_step(e,w,now)
        if not (w and w.load=='ready') then return end
        local at,path=address(e),path_of(e)
        if not here or here.at~=at or here.path~=path then
            if here and here.stand then Stand.remove(here.stand) end
            here={at=at,path=path,since=now}
        end
        if here.failed or now-here.since<SETTLE then return end
        if not (here.part and Doro.same(here.part,here.part_path)) then
            local began=os.clock()
            local ok,made=pcall(function()
                local found=find_part(e)
                if found then return {found,'found'} end
                local c,untagged=make_part(e)
                return {c,'made',untagged}
            end)
            if not ok then
                here.failed=why_of(made)
                return log('bike part not made: '..here.failed)
            end
            here.part,here.part_path=made[1],path_of(made[1])
            if not ride then made[1]:SetVisibility(false,false) end
            log(('bike part ready on EVE (%s in %.1f ms)'):format(made[2],(os.clock()-began)*1000))
            if made[3] then
                log('bike part tag '..Ride.TAG..' not written ('..made[3]..'): a Ctrl+R will not find this part')
            end
        end
        if here.stand or here.stand_failed then return end
        local began=os.clock()
        local ok,d,map=pcall(function()
            local map=U.map_of(e)
            return Stand.make(e:GetWorld(),Ride.MESH),map
        end)
        if not ok then
            here.stand_failed=why_of(d)
            return log('bike stand not made: '..here.stand_failed)
        end
        here.stand,here.map=d,map
        -- New to the paint even at the freed address and path of a parked bike removed before (coop off). Never raises.
        paint.clear({d.mesh})
        stand_store.save(d.path) -- For the next Lua load's sweep (Ctrl+R).
        log(('bike stand made in %.1f ms'):format((os.clock()-began)*1000))
    end
    -- Her parked bike as the state says, on a change only: put at its place and shown while that place is on this map,
    -- her EVE stood SETTLE s, she does not ride and no cutscene holds her; else hidden. While shown, its collision rule.
    -- parked: called by a dismount, whose first show is no put back.
    local function sync(e,now,parked)
        local h=here
        local d=h and h.stand
        if not (e and d and Stand.alive(d)) then return end
        local want=place~=nil and place.map==h.map and now-h.since>=SETTLE and not ride
            and e:IsAttachedToLevelSequenceWithoutPlayable()~=true
        if want and d.place~=place then Stand.put(d,place) end
        if want~=d.shown then
            Stand.show(d,want)
            -- Its first show on this EVE, unless a park just made it: put back from the place she left it.
            if want and not h.back and not parked then
                log(('bike put back on %s at %d,%d,%d'):format(place.map,whole(place.at.X),whole(place.at.Y),
                    whole(place.at.Z)))
            end
            h.back=h.back or want
        end
        if want then
            local line=Stand.step(d,e)
            if line then log(line) end
        end
    end
    -- The floor under her as its normal when it counts: walkable, its base not Movable; else nil. A CurrentFloor that
    -- does not read (said once) counts as flat ground.
    local function floor_normal(e)
        local base=valid(e:GetMovementBase())
        if base and value_of(base.Mobility)==MOVABLE then return nil end
        local ok,f=pcall(function()
            local floor=value_of(valid(e.CharacterMovement).CurrentFloor)
            local n=value_of(value_of(floor.HitResult).ImpactNormal)
            return {walk=floor.bWalkableFloor==true,normal={X=n.X,Y=n.Y,Z=n.Z}}
        end)
        if ok then return f.walk and f.normal or nil end
        if not floor_told then
            floor_told=true
            log('bike floor: CurrentFloor not read ('..why_of(f)..'): walking on a fixed base counts')
        end
        return {X=0,Y=0,Z=1}
    end
    -- Where the bike would stand now: at her feet (her main mesh's origin) on this map, the part's heading laid on the
    -- floor. nil unless she walks on a floor that counts, so a press in the air keeps the last ground pose.
    local function pose_of(e,part)
        local mode=value_of(valid(e.CharacterMovement).MovementMode)
        if mode~=WALKING and mode~=NAV_WALKING then return nil end
        local normal=floor_normal(e)
        if not normal then return nil end
        local at=value_of(valid(e.Mesh):K2_GetComponentLocation())
        local rot=value_of(math_lib():MakeRotFromZX(normal,part:GetForwardVector()))
        return {map=U.map_of(e),at={X=at.X,Y=at.Y,Z=at.Z},rot={Pitch=rot.Pitch,Yaw=rot.Yaw,Roll=rot.Roll}}
    end
    -- Her bike's place against her for a mount: a refusal as a function of a words table (o.words() for the screen,
    -- T.en for the log) when it is on another map, not shown yet on hers or out of reach; else nil, with the stand to
    -- get on when there is one; its third value is true when the refusal may offer the paid fetch (far, another map).
    -- A stand that could not be made never holds the bike: it comes to her.
    local function at_place(e)
        if not place then return nil end
        if place.map~=U.map_of(e) then
            local name=Park.map_name(place.map,o.worlds)
            return function(t) return t.bike.other_map:format(name) end,nil,true
        end
        local h=here
        if h and h.at==address(e) and h.stand_failed then return nil end
        local d=h and h.at==address(e) and h.stand
        if not (d and d.shown) then return function(t) return t.bike.not_back end end
        local feet=value_of(valid(e.Mesh):K2_GetComponentLocation())
        if Park.reach(feet,place,valid(e.CapsuleComponent):GetUnscaledCapsuleRadius()) then return nil,d end
        local metres,side=Park.where(feet,value_of(e:GetControlRotation()).Yaw,place)
        return function(t) return t.bike.far:format(metres,t.bike[side]) end,nil,true
    end
    -- Every 250 ms after sync: bike_key's notice once each time her feet come within reach of her shown bike.
    local function prompt(e)
        local h=here
        if not (e and h and h.stand) then return end
        if ride then
            h.near=true
            return
        end
        if not (h.stand.shown and place) then return end
        local near=Park.reach(value_of(valid(e.Mesh):K2_GetComponentLocation()),place,
            valid(e.CapsuleComponent):GetUnscaledCapsuleRadius())
        local key=o.settings and o.settings.bike_key
        if near and not h.near and key and key.name~='none' then
            o.tell(function(w) return w.bike.prompt:format(key.name) end)
        end
        h.near=near
    end
    local function remove_part()
        local h=here
        here=nil
        local p=h and h.part and Doro.same(h.part,h.part_path)
        local e=p and her()
        if not (p and e) then return end
        p:K2_DestroyComponent(e)
        log('bike part removed from EVE')
    end
    -- The riding clip asked of the native part with a new id: nil, or why it was not taken.
    local function play(r)
        serial=serial%MAX_ID+1
        local ok,why=ask(('anim play %d %s ride'):format(serial,Ride.CLIP))
        if not ok then return 'the native part did not take the riding clip: '..tostring(why) end
        r.id,r.asked,r.playing,r.ended=serial,os.clock(),false,false
        log(('bike ride clip asked (anim %d)'):format(serial))
    end

    -- Her bike line to the link when it changed: none while she rides, with bike=off or without a place, else its
    -- place. Remembered only once the link took it, so a failed write goes again at the next pass.
    local function send()
        if not o.send then return end
        local off=ride or o.settings and o.settings.bike==false
        local line=off and 'none' or Park.wire(place)
        if line~=sent and o.send(line) then sent=line end
    end
    -- The place into the record at the key read last. Not written: kept in memory (dirty), said when the write failed.
    local function save()
        local ok,why=false,nil
        if file and key then ok,why=file.write(key,Park.line(place)..'\n') end
        dirty=not ok
        if key and not ok then log('bike place: write failed: '..tostring(why)..'; kept in memory') end
    end
    -- Every 250 ms with her off the bike: an SBO lobby opened (no place, no key) or left (the key read again); a new key
    -- read once, or given the park made before any key. raw: the status text.
    local function record(raw)
        local open=lobby()==true
        if open~=in_lobby then
            in_lobby=open
            place,key,dirty=nil,nil,false
        end
        local name=not open and file and Park.key(raw)
        if not name or name==key then return end
        local first=key==nil
        key=name
        if dirty and first then
            save()
            if not dirty then log('bike place: '..name..': kept the park made before the key') end
            return
        end
        dirty=false
        local why
        place,why=Park.read(file.read(name))
        log('bike place: '..name..': '..(place and place.map or why=='none' and 'none' or 'unreadable, read as none'))
    end
    -- The bike parks at live, else at the ride's last ground pose, else it stays where it was; the record written when
    -- it moved.
    local function park(live)
        local word,before
        before,place,word=place,Park.spot(live,ground,place)
        ground=nil
        if word then
            log(('bike parked on %s at %d,%d,%d (%s)'):format(place.map,whole(place.at.X),whole(place.at.Y),
                whole(place.at.Z),word))
        end
        if place~=before and not in_lobby then save() end
    end
    -- Off the bike, backward from the mount: the part hidden, the clip stopped, SB's actions back, the drive off, her
    -- mesh's rotation and location back (only on the EVE she rode), the file cleared unless that write failed. Then
    -- the bike parks at live (her pose at a dismount by the key), else at the ride's last ground pose, else it stays
    -- where it was. Each step in its own pcall. Returns the log line, or nil when she does not ride.
    local function stop(why,live)
        local r=ride
        if not r then return nil end
        ride=nil
        local failed={}
        local function try(what,f)
            local ok,e=pcall(f)
            if not ok then failed[#failed+1]=what..': '..why_of(e) end
        end
        local function asked(line)
            local ok,e=ask(line)
            if not ok then error(e,0) end
        end
        if r.shown then
            try('the part not hidden',function()
                local p=Doro.same(r.part,r.part_path)
                if p then p:SetVisibility(false,false) end
            end)
        end
        if r.id then try('anim stop',function() asked('anim stop') end) end
        if r.gated then try('bike gate off',function() asked('bike gate off') end) end
        if r.drove and drive.why()=='bike' then
            try('the drive',function() log(drive.off('bike '..why)) end)
        end
        local e=Doro.same(r.eve,r.path)
        local mesh='her EVE is gone, nothing to write'
        local ok,err=true,nil
        if e then
            ok,err=pcall(function()
                valid(e.Mesh):K2_SetRelativeLocationAndRotation(r.base_at,r.base,false,{},false)
            end)
            mesh=ok and 'her mesh back' or 'her mesh not written back ('..why_of(err)..'), coop-bike.txt kept'
        end
        if ok then store.clear() end
        park(live)
        try('the parked bike',function() sync(her(),os.clock(),true) end)
        send()
        local line=('bike off (%s) after %.1f s: %s%s'):format(why,os.clock()-r.since,mesh,
            failed[1] and '; failed: '..table.concat(failed,'; ') or '')
        log(line)
        return line
    end
    -- The SBO and native refusals that come after EVE's own checks.
    local function busy()
        if drive.active() or o.drove and o.drove() then return 'a race or the drive probe drives EVE' end
        -- At GO the race's drive would replace the bike's.
        if o.armed and o.armed() then return 'a race is armed: coop race quit leaves it' end
        return o.busy and o.busy() or nil
    end
    -- Where the bike would come at the paid fetch: her pose as a park takes it, else her feet with her actor's yaw.
    local function here_pose(e)
        local read,pose=pcall(pose_of,e,(part_for(e)))
        if read and pose then return pose end
        local at,yaw=value_of(valid(e.Mesh):K2_GetComponentLocation()),value_of(e:K2_GetActorRotation()).Yaw
        return {map=U.map_of(e),at={X=at.X,Y=at.Y,Z=at.Z},rot={Pitch=0,Yaw=yaw,Roll=0}}
    end
    -- The money's name in the words t: SB's on the screen's words, else Fetch.WORD (the log's word, also the English
    -- copy's that the line above EVE shows when its font cannot draw the screen's words).
    local function money(t)
        local name=t==o.words() and o.game_text and o.game_text(Fetch.NAME_KEY,Fetch.NAME_TABLE)
        return name and #name<=Fetch.NAME_MAX and name or Fetch.WORD
    end
    -- A refusal that may offer the paid fetch (far, another map): at an activated Xion camp outside an SBO lobby, a
    -- press within the offer's window starts the payment, any other press arms the offer after the refusal.
    local function offered(e,refusal)
        local words=o.words()
        local alias=o.fetch and not lobby() and o.camp and o.camp('Xion',CAMP)
        if not alias then
            offer=nil
            return false,refusal(words)
        end
        local now=os.clock()
        if offer and now<=offer.due then
            local paid_for=offer
            offer=nil
            local started,why=o.fetch.start(now)
            if not started then
                log('bike fetch not started: '..tostring(why))
                return false,words.bike.unpaid
            end
            paying=paid_for
            log(('bike fetch asked at %s for %d betacrystal'):format(paid_for.camp,Fetch.PRICE))
            -- main.lua puts only refusals on screen.
            o.tell(function(t) return t.bike.paying:format(Fetch.PRICE,money(t)) end)
            return true,words.bike.paying:format(Fetch.PRICE,money(words))
        end
        offer={due=now+Fetch.WINDOW,pose=here_pose(e),camp=alias}
        local key=o.settings and o.settings.bike_key
        key=key and key.name~='none' and key.name or 'coop bike'
        local line=refusal(words)..' '..words.bike.offer:format(key,Fetch.PRICE,money(words))
        -- A long map name and SB's money name may pass the feed's line: Fetch.WORD then, which ui/text_test fits.
        if #line>FEED then line=refusal(words)..' '..words.bike.offer:format(key,Fetch.PRICE,Fetch.WORD) end
        return false,line
    end
    -- Each 250 ms pass while the payment runs: its end on screen; paid, the bike stands where the offer was made.
    local function fetched()
        if not (paying and o.fetch.busy()) then return end
        local result,detail=o.fetch.step(os.clock())
        if not result then return end
        local paid_for=paying
        paying=nil
        if result=='paid' then
            place=paid_for.pose
            log(('bike brought to %s for %d betacrystal'):format(paid_for.camp,Fetch.PRICE))
            if not in_lobby then save() end
            local shown,why=pcall(sync,her(),os.clock(),true)
            if not shown then log('bike stand not shown: '..why_of(why)) end
            if here then here.near=true end -- This notice, not the prompt, says it stands at her feet.
            o.tell(function(t) return t.bike.paid:format(Fetch.PRICE,money(t)) end)
        elseif result=='poor' then
            log(('bike fetch refused: you carry %d betacrystal, %d needed'):format(detail,Fetch.PRICE))
            o.tell(function(t) return t.bike.poor:format(money(t),Fetch.PRICE,detail) end)
        else
            log('bike fetch failed: '..tostring(detail))
            o.tell(function(t) return t.bike.unpaid end)
        end
    end
    local function mount()
        if paying and o.fetch.busy() then
            log('bike refused: '..T.en.bike.paying:format(Fetch.PRICE,Fetch.WORD))
            local words=o.words()
            return false,words.bike.paying:format(Fetch.PRICE,money(words))
        end
        local e=her()
        local w=Ride.native(status())
        local why=o.settings and o.settings.bike==false and 'the bike is off (bike=off)'
            or not e and 'no EVE in the world' or blocked(e,w,true) or busy() or Ride.loaded(w.load)
        local part,stand
        if not why then
            local refusal,offers
            refusal,stand,offers=at_place(e)
            if refusal then
                log('bike refused: '..refusal(T.en))
                if offers then return offered(e,refusal) end
                return false,refusal(o.words())
            end
            part,why=part_for(e)
        end
        if why then
            log('bike refused: '..why)
            return false,why
        end
        if stand then
            -- Onto the parked bike: hidden, then her actor moved so the part lands on its root and heading.
            Stand.show(stand,false)
            local went,said=pcall(function()
                local at,yaw=Park.seat(value_of(e:K2_GetActorLocation()),value_of(e:K2_GetActorRotation()).Yaw,
                    value_of(part:K2_GetComponentLocation()),value_of(part:K2_GetComponentRotation()).Yaw,place)
                return e:K2_TeleportTo(at,{Pitch=0,Yaw=yaw,Roll=0})
            end)
            log(went and said~=false and 'bike mount: onto the parked bike'
                or 'bike mount: teleport refused, the bike came to her'..(went and '' or ' ('..why_of(said)..')'))
        end
        local began=os.clock()
        local mesh=assert(valid(e.Mesh),'EVE has no main mesh')
        local rot,at=value_of(mesh.RelativeRotation),value_of(mesh.RelativeLocation)
        -- A file this Lua load kept for her (a dismount that could not write her mesh back) holds her base: her mesh
        -- may still lean.
        local left,path=fields(store.load()),path_of(e)
        local function base(k,v) return left[1]==path and tonumber(left[k]) or v end
        rot={Pitch=base(2,rot.Pitch),Yaw=base(3,rot.Yaw),Roll=base(4,rot.Roll)}
        at={X=base(5,at.X),Y=base(6,at.Y),Z=base(7,at.Z)}
        local r={eve=e,path=path,at=address(e),mesh=mesh,part=part,part_path=here.part_path,
            base={Pitch=rot.Pitch,Yaw=rot.Yaw,Roll=rot.Roll},base_at={X=at.X,Y=at.Y,Z=at.Z},lean=0,pitch=0,
            math=math_lib(),since=began,ends={}}
        local saved,save_why=store.save(table.concat({r.path,number(rot.Pitch),number(rot.Yaw),number(rot.Roll),
            number(at.X),number(at.Y),number(at.Z)},'\t'))
        if saved==false then
            if stand then pcall(sync,e,os.clock()) end
            log('bike refused: coop-bike.txt could not be written ('..tostring(save_why)..')')
            return false,'coop-bike.txt could not be written: '..tostring(save_why)
        end
        ride=r
        local ok,err=pcall(function()
            local on,on_why=drive.on(values,'bike',B)
            if not on then error('no driving: '..tostring(on_why),0) end
            r.drove=true
            local gated,gate_why=ask('bike gate on')
            if not gated then error("SB's actions could not be turned off: "..tostring(gate_why),0) end
            r.gated=true
            local played=play(r)
            if played then error(played,0) end
            r.shown=true
            part:SetVisibility(true,false)
        end)
        if not ok then
            local why_not=why_of(err)
            stop('the mount failed: '..why_not)
            return false,why_not
        end
        log(('bike on in %.1f ms: her mesh relative rotation P=%.2f Y=%.2f R=%.2f, location %.2f %.2f %.2f%s'):format(
            (os.clock()-began)*1000,rot.Pitch,rot.Yaw,rot.Roll,at.X,at.Y,at.Z,
            left[1]==path and ' (kept in coop-bike.txt)' or ''))
        send()
        return true,'On the bike: coop bike gets her off.'
    end

    -- Adapted from Eve On Wheels' mesh tilt (handling.lua): her main mesh's relative rotation is its base rotation,
    -- then the lean and the pitch, written only after a change of TILT_STEP degrees or more; teleport is off here.
    local function tilt(r,look)
        local lean,pitch=look.lean or 0,look.pitch or 0
        if math.abs(lean-r.lean)<TILT_STEP and math.abs(pitch-r.pitch)<TILT_STEP then return end
        r.lean,r.pitch=lean,pitch
        local c=value_of(r.math:ComposeRotators(r.base,{Pitch=PITCH_SIGN*pitch,Yaw=0,Roll=LEAN_SIGN*lean}))
        r.mesh:K2_SetRelativeRotation({Pitch=c.Pitch,Yaw=c.Yaw,Roll=c.Roll},false,{},false)
    end
    -- The anim answer for our play: nil while it plays, waits or was played again; else why she gets off.
    local function keep(r,e,w,now)
        if w.id~=r.id then
            if now-r.asked<ANSWER then return nil end
            return 'no answer from the native part for the riding clip'
        end
        if w.anim=='playing' then
            if not r.playing then
                r.playing=true
                log(('bike ride clip plays (anim %d)'):format(r.id))
            end
            return nil
        end
        if w.anim=='ended' then
            if not r.ended then
                r.ended=true
                local kept={}
                for _,t in ipairs(r.ends) do if now-t<ENDS_IN then kept[#kept+1]=t end end
                kept[#kept+1]=now
                r.ends=kept
                log(('bike ride clip ended (anim %d, %d end(s) within %d s)'):format(r.id,#kept,ENDS_IN))
                if #kept>=ENDS then return ('SB ended the riding clip %d times within %d s'):format(#kept,ENDS_IN) end
            end
            if o.photo()~='0' or e:IsRunningSkill()==true or e:IsPlayingRootMotion()==true then return nil end
            return play(r)
        end
        if w.anim=='ended:weight' then return 'her animation blueprint showed none of the riding clip' end
        local refused=(w.anim or ''):match('^refused:(.+)$')
        if refused then return 'the game refused the riding clip ('..refused..')' end
        if w.anim=='stopped' or w.anim=='fault' then return 'the native part stopped the riding clip ('..w.anim..')' end
        return nil -- idle: our play not taken yet.
    end
    -- One frame of the ride: why she gets off, or nil.
    local function frame(r)
        local look=drive.tick() -- nil on its first frame (no look yet), or once it went off with her EVE.
        if drive.why()~='bike' then
            return drive.active() and 'a '..drive.why()..' drive took over her driving' or 'her EVE changed'
        end
        if look then tilt(r,look) end
    end
    -- Every 250 ms while she rides: why she gets off, or nil. The anim answer comes from this pass's status text.
    local function check(r,e,w,now)
        if not e or address(e)~=r.at then return 'her EVE changed' end
        local why=blocked(e,w,false)
        if why then return why end
        if drive.why()~='bike' then return 'her drive went off' end
        if now-r.since>=GATE_WAIT and w.gate~='on' then
            return "SB's actions are not off (bike_gate="..tostring(w.gate)..')'
        end
        ground=pose_of(e,r.part) or ground
        drive.slow()
        return keep(r,e,w,now)
    end
    local function off_line(why)
        stop(why)
        return false,'Off the bike: '..why
    end

    function self.riding() return ride~=nil end
    -- online/partner/capture.lua's leave_out at each look (main.lua): the address of the part this Lua load made or
    -- found on the EVE at at while she does not ride; nil while she rides, before the part and after bike=off. No
    -- engine call.
    -- After a Lua load, restore names the earlier load's part from the first tick, whatever the bike= word.
    function self.idle_part(at)
        local h=here
        return not ride and h and h.at==at and h.part and address(h.part) or nil
    end
    -- The key, the pad gesture and coop bike: on the bike, or off it. ok and a line for the screen.
    function self.toggle(why)
        if ride then
            -- A pose that does not read parks as a forced dismount does: the key always gets her off.
            local read,live=pcall(pose_of,her(),ride.part)
            stop(why or 'coop bike',read and live or nil)
            return true,'Off the bike.'
        end
        return mount()
    end
    -- coop off, bike=off, the guest's race: off the bike. The log line, or nil when she did not ride.
    function self.stop(why) return stop(why or 'coop off') end
    -- coop off and bike=off, after stop: her parked bike out of the world, its place kept. Logs nothing.
    function self.leave()
        local h=here
        local d=h and h.stand
        if h then
            paint.clear({h.part}) -- Before the stand goes. Never raises.
            h.stand=nil
        end
        stand_store.clear()
        if d then Stand.remove(d) end
    end
    -- Each frame before the native tick, after online/modes/race/run.lua's steer: the ride's drive and lean. A reason
    -- to get off or an error ends the ride: false and a line for the screen.
    function self.steer()
        local r=ride
        if not r then return end
        local ok,why=pcall(frame,r)
        if not ok then return off_line('an error: '..why_of(why)) end
        if why then return off_line(why) end
    end
    -- Every 250 ms: the preload asked or released as the setting says, the part, the ride's checks and its clip. A
    -- reason to get off or an error ends the ride: false and a line for the screen.
    local function pass()
        local want=not (o.settings and o.settings.bike==false)
        if want~=preload then
            preload=want
            if not want then
                stop('bike=off')
                -- Before remove_part, which forgets here and with it her parked bike.
                local left,why=pcall(self.leave)
                if not left then log('bike stand not removed: '..why_of(why)) end
                local ok,e=pcall(remove_part)
                if not ok then log('bike part not removed: '..why_of(e)) end
            end
            local _,said=ask(want and 'bike load '..Ride.CLIP or 'bike free')
            load_asked=os.clock()
            log('bike='..(want and 'on' or 'off')..': '..tostring(said))
        end
        if not want then return end
        local now=os.clock()
        local ok,why=pcall(function()
            local e=her()
            local raw=status()
            local w=Ride.native(raw)
            -- The native part shows bike=off only when it would take the ask: the request was lost or never reached it.
            if w and w.load=='off' and now-load_asked>=LOAD_AGAIN then
                load_asked=now
                local _,said=ask('bike load '..Ride.CLIP)
                log(('bike=off %.0f s after the bike load: asked again: %s'):format(LOAD_AGAIN,tostring(said)))
            end
            if e then part_step(e,w,now) end
            -- Then the paint of her part and her parked bike, for her body mesh (nil when it does not read). It never
            -- raises.
            if e and here then
                local read,mesh=pcall(body_of,e)
                paint.step(now,read and mesh or nil,{here.part,here.stand and here.stand.mesh})
            end
            local why=ride and check(ride,e,w,now)
            if why then return why end
            -- After check: a park it forces is written at the key she rode under.
            if not ride then record(raw) end
            sync(e,now)
            prompt(e)
        end)
        if not ok then
            if ride then return off_line('an error: '..why_of(why)) end
            error(why,0)
        end
        if why then return off_line(why) end
    end
    -- The paid fetch's step first, so a paid place is shown by the pass and sent. Then her bike line, whatever the
    -- pass did.
    function self.slow()
        fetched()
        local off,why=pass()
        send()
        return off,why
    end
    -- At the first tick of a Lua load, once: the parked bike an earlier load left in the world swept by its path. The
    -- part an earlier load made on her EVE (its tag), hidden and kept as this load's, so idle_part names it and
    -- bike=off removes it with no bike= word read. Then an earlier load's coop-bike.txt (it left EVE on the bike) puts
    -- her main mesh's rotation and location back on that EVE if she still is one and hides the bike part, then the file
    -- is cleared unless that mesh write failed; once her mesh is back the bike parks where she stands when her floor
    -- counts. Its drive comes back first, through coop-drive.txt (its own vehicles/bike/drive.lua's restore).
    function self.restore()
        if restored then return end
        restored=true
        local back,back_why=pcall(drive.restore)
        if not back then log('bike drive not restored: '..why_of(back_why)) end
        local stand=stand_store.load()
        if stand then
            local swept,why=pcall(Stand.sweep,stand,Ride.MESH)
            if not swept then log('bike stand not swept: '..why_of(why)) end
            stand_store.clear()
        end
        local found,why=pcall(function()
            local e=her()
            local p=e and find_part(e)
            if not p then return end
            p:SetVisibility(false,false)
            here={at=address(e),path=path_of(e),since=os.clock(),part=p,part_path=path_of(p)}
            log("bike part found on EVE (an earlier Lua load's), hidden")
        end)
        if not found then log('bike part not looked for: '..why_of(why)) end
        local line=store.load()
        if not line then return end
        local f=fields(line)
        -- A mesh write that fails keeps the file: her mesh may still lean, the next mount takes her base from it.
        local kept,e,p=false,nil,nil
        local ok,said=pcall(function()
            e=U.her(valid(StaticFindObject(f[1])))
            if not e then return 'her EVE is gone' end
            local n={}
            for k=2,7 do n[k]=assert(tonumber(f[k]),'value '..(k-1)..' unreadable in the file') end
            kept=true
            valid(e.Mesh):K2_SetRelativeLocationAndRotation({X=n[5],Y=n[6],Z=n[7]},{Pitch=n[2],Yaw=n[3],Roll=n[4]},
                false,{},false)
            kept=false
            p=find_part(e)
            if p then p:SetVisibility(false,false) end
            return 'her mesh back'..(p and ', the bike hidden' or '')
        end)
        if not kept then store.clear() end
        local read,live=false,nil
        if ok and p then read,live=pcall(pose_of,e,p) end
        if read and live then park(live) end
        log('bike restored from coop-bike.txt: '..(ok and said or 'failed ('..why_of(said)..')')
            ..(kept and ', coop-bike.txt kept' or ''))
    end
    -- coop bike status: the preload, the part, the ride, the values, where the bike is (its distance only from her feet
    -- on its map) and the paint for her body mesh, named by its whole path (the key a modder copies).
    function self.status()
        local w=Ride.native(status())
        local h=here
        local part=h and h.part and Doro.same(h.part,h.part_path) and 'on EVE'
            or h and h.failed and 'not made ('..h.failed..')' or 'not made yet'
        local list={}
        for _,name in ipairs(B.NAMES) do list[#list+1]=name..'='..values[name] end
        local at='no place yet'
        if place then
            local ok,metres=pcall(function()
                local e=her()
                if e and U.map_of(e)==place.map then
                    return (Park.where(value_of(valid(e.Mesh):K2_GetComponentLocation()),0,place))
                end
            end)
            at='parked on '..place.map..(ok and metres and (', %d m away'):format(metres) or '')
        end
        local read,mesh=pcall(function() return body_of(her()) end)
        mesh=read and mesh or nil
        local paint_word=mesh and ('paint %s for %s'):format(paint.on(mesh) and 'on' or 'off',mesh)
            or 'paint off (no body mesh read)'
        return ('bike: preload %s, part %s, %s; %s; %s; %s'):format(w and w.load or 'none (no native part)',part,
            ride and ('riding for %.0f s'):format(os.clock()-ride.since) or 'not riding',table.concat(list,' '),at,
            paint_word)
    end
    -- coop bike tune [<name> <value>]: the values, or one changed (clamped) for the next rides of this Lua load.
    function self.tune(name,text)
        if name==nil then
            local list={}
            for _,n in ipairs(B.NAMES) do list[#list+1]=n..'='..values[n] end
            return true,'bike: '..table.concat(list,' ')
        end
        local set,why=B.set(values,name,text)
        if not set then return false,why end
        values=set
        log('bike '..name..'='..values[name])
        return true,'Bike '..name..'='..values[name]..' from your next ride (this Lua load).'
    end
    return self
end
return Ride
