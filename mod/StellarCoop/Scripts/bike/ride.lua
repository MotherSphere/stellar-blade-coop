-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The bike on the game thread: SB's Adam_Vehicle_02 as a part on EVE's own actor with her ride on it, on any save
-- (nothing of the ride is saved). With bike=on the native part preloads the mesh and the riding clip once ("bike load",
-- native/src/game/bike.h; the bike= word of the status line says ready). Once that is ready and an EVE has been in the
-- world 2 s, the part is made: one SkeletalMeshComponent hung KeepRelative on her main mesh at the seat
-- (race/doro.lua's attach: collision off, single-node mode with no clip, so it keeps its reference pose), hidden. After
-- Ctrl+R the part is already there: it is found among her components by its mesh and used again. The capture sends it
-- to every ghost like any part of her outfit, shown or hidden, so nothing new travels.
-- A mount (self.toggle) checks EVE first and refuses with its reason; then, in this order: coop-bike.txt (her object
-- path, her main mesh's relative rotation and location), race/drive.lua's drive with bike/model.lua (why 'bike'), "bike
-- gate on" (SB's actions off on her controller, Jump left on), "anim play <id> <clip> ride" (the riding clip looped,
-- her foot IK off) and the part shown. A dismount runs it backward: the part hidden, "anim stop", "bike gate off", the
-- drive off, her mesh's rotation and location back, the file cleared. A dismount comes from the key, the pad, coop
-- bike, coop off, bike=off, a new EVE, a check every 250 ms (self.slow) and a failure; the next Lua load replays the
-- file at its first tick (self.restore) when this one could not (Ctrl+R). The native part turns the gate off and stops
-- the clip itself at a new Lua load.
-- Each frame (self.steer, before the native tick): the drive's frame, then her lean and pitch on her main mesh's
-- relative rotation, the base rotation then a turn about her actor's forward axis (lean) and side axis (pitch), through
-- KismetMathLibrary's ComposeRotators, written with teleport off (a teleport clears cloth inertia). The ghosts get it
-- through her mesh's transform. Every 0.1 s the anim answer: the clip played again when SB ended it, unless the photo
-- mode, a skill or a root-motion move holds her; three ends within 1 s take her off the bike (SB uses the slot).
-- What it writes on the player's own EVE: the part, her main mesh's relative rotation (and its location back at the
-- end), what race/drive.lua writes; through the native part SB's per-action switches and the custom animation slot.
-- Parts of this file adapt Eve On Wheels 1.2.1 by dCharisma1 (nexusmods.com/stellarblade/mods/4165), used with his
-- written consent given on 2026-11-16. They are licensed here under the SBO License 1.0 or any later version the
-- Licensor publishes (NOTICE). No file of Eve On Wheels ships with Stellar Blade Online.
local UE=require('UEHelpers')
local U=require('core.unreal')
local B=require('bike.model')
local Doro=require('race.doro')
local valid,value_of,each,find,address,why_of=U.valid,U.value_of,U.each,U.find,U.address,U.why
local Ride={}
-- SB's bike (37 bones, no wheel bone; its skeleton, physics asset and four material instances come with it).
Ride.MESH='/Game/Art/Character/ETC/Adam_vehicle_02/Adam_Vehicle_02.Adam_Vehicle_02'
-- The riding clip, one of EVE's clips (the native part plays only those): SB has no driver clip for her, so this is the
-- pillion pose asleep on the bike of the SD20 scene, 301 frames at 30 fps with no root motion. The one place to change
-- it.
Ride.CLIP='/Game/Art/Character/PC/CH_P_EVE_01/Animation/event/G03/MV_SD20_AfterBruteBattle_Main/eve/'
    ..'eve_bikeSleepPose.eve_bikeSleepPose'
-- The bike relative to her main mesh, cm and degrees: SD20's attach tracks (riders on its bone Base).
local SEAT,SEAT_PITCH={X=1.53,Y=0.52,Z=2.95},0.69
local SETTLE=2 -- s an EVE has been in the world before her part is made (the capture's own wait).
local POLL,ANSWER=0.1,5 -- s between reads of the anim answer; s with no answer for our play.
local ENDS,ENDS_IN=3,1 -- SB's ends of the riding clip within ENDS_IN s that take her off the bike.
local GATE_WAIT=1 -- s after the mount by which the gate must read on.
-- A right turn (the yaw growing) leans her right, a climb lifts the nose. Signs to check in the first ride.
local LEAN_SIGN,PITCH_SIGN=1,1
local TILT_STEP=0.05 -- degrees: a smaller change of the lean or the pitch is not written.
local WALKING,NAV_WALKING,FALLING,SWIMMING,CUSTOM=1,2,3,4,6 -- EMovementMode.
local SKINNED='/Script/Engine.SkeletalMeshComponent'
local MAX_ID=4294967295

-- The native status line's words for the bike: warp (idle or busy), anim and its id, the preload (bike=) and the gate
-- (bike_gate=); nil without an engine line (no native part).
function Ride.native(status)
    local line=('\n'..(status or '')):match('\nengine=([^\r\n]*)')
    if not line then return nil end
    local anim,id=line:match(' anim=(%S+) anim_id=(%d+)')
    local load,gate=line:match(' bike=(%S+) bike_gate=(%S+)')
    return {warp=line:match(' warp=(%a+)'),anim=anim,id=tonumber(id),load=load,gate=gate}
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
-- The bike part an earlier Lua load made on EVE: her skeletal mesh component that shows Ride.MESH, else nil.
local function find_part(e)
    local found=nil
    each(e:K2_GetComponentsByClass(find(SKINNED)),function(_,c)
        c=valid(c)
        local mesh=c and valid(c.SkeletalMesh)
        if not found and mesh and path_of(mesh)==Ride.MESH then found=c end
    end)
    return found
end
-- A new part on her main mesh at the seat, hidden. Raises, with nothing left, when it cannot be made.
local function make_part(e)
    local mesh=assert(valid(e.Mesh),'EVE has no main mesh')
    local c=Doro.attach(e,mesh,{path=Ride.MESH}).mesh
    local ok,why=pcall(function()
        c:K2_SetRelativeLocationAndRotation(SEAT,{Pitch=SEAT_PITCH,Yaw=0,Roll=0},false,{},false)
        c:SetVisibility(false,false)
    end)
    if not ok then
        pcall(function() c:K2_DestroyComponent(e) end)
        error(why,0)
    end
    return c
end
local function number(v) return (string.format('%.9g',v):gsub(',','.')) end

-- o: log (the [BK] lines); ask(line) (a native request: ok and its line); status() (the native status text); store
-- (coop-bike.txt through link.store); drive (race/drive.lua's); settings (main.lua's: bike); paused() (the game paused
-- or on one of its screens); photo() ('0', '1' in photo mode, 's' in the selfie mode); frozen() (the partner's photo
-- mode holds our game); life() (link.life's {state}, or nil); armed() (race/run.lua's: a race is armed here; nil when
-- there is none); busy() (why SBO's own state forbids a mount: the Doro look, coop emote, a hall seat, coop fly or
-- glide, Night Operation, an SBO menu or the chat; nil when none).
function Ride.new(o)
    local log,ask,status,drive=o.log,o.ask,o.status,o.drive
    local store=o.store or {save=function() end,load=function() end,clear=function() end}
    local self={}
    local values=B.clamp(B.DEFAULTS) -- coop bike tune changes them for this Lua load.
    -- The part on the EVE seen last: {at, path, since (os.clock), part, part_path, failed}.
    local here=nil
    -- While she rides: eve, path, at, mesh, part, part_path, base and base_at (her mesh's relative rotation and
    -- location before), lean and pitch (as written), since, what the mount did (drove, gated, shown), id (the play's),
    -- asked (os.clock of its ask), playing, ended (this id's end counted), ends (os.clock of each end), read.
    local ride=nil
    local preload=nil -- What the setting last asked of the native part: true (bike load), false (bike free).
    local restored=false
    local serial=2000000000+os.time()%1000000 -- Apart from coop emote's ids, which start under 1000000.

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
        local life=o.life()
        if life and life.state>=3 and life.state<=5 then return 'EVE is down' end
        return nil
    end
    -- The part for EVE (the one seen last), or nil and why.
    local function part_for(e)
        if here and here.at==address(e) and here.part and Doro.same(here.part,here.part_path) then return here.part end
        if here and here.failed then return nil,'the bike part could not be made ('..here.failed..')' end
        return nil,'the bike is still loading'
    end
    -- Every 250 ms: once bike=ready and EVE has been in the world SETTLE s, her part found or made, once for her.
    local function part_step(e,w,now)
        if not (w and w.load=='ready') then return end
        local at,path=address(e),path_of(e)
        if not here or here.at~=at or here.path~=path then here={at=at,path=path,since=now} end
        if here.part and Doro.same(here.part,here.part_path) or here.failed or now-here.since<SETTLE then return end
        local began=os.clock()
        local ok,made=pcall(function()
            local found=find_part(e)
            return found and {found,'found'} or {make_part(e),'made'}
        end)
        if not ok then
            here.failed=why_of(made)
            return log('bike part not made: '..here.failed)
        end
        here.part,here.part_path=made[1],path_of(made[1])
        if not ride then made[1]:SetVisibility(false,false) end
        log(('bike part ready on EVE (%s in %.1f ms)'):format(made[2],(os.clock()-began)*1000))
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

    -- Off the bike, backward from the mount: the part hidden, the clip stopped, SB's actions back, the drive off, her
    -- mesh's rotation and location back (only on the EVE she rode), the file cleared unless that write failed. Each
    -- step in its own pcall. Returns the log line, or nil when she does not ride.
    local function stop(why)
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
        local line=('bike off (%s) after %.1f s: %s%s'):format(why,os.clock()-r.since,mesh,
            failed[1] and '; failed: '..table.concat(failed,'; ') or '')
        log(line)
        return line
    end
    -- The SBO and native refusals that come after EVE's own checks.
    local function busy()
        if drive.active() then return 'a race or the drive probe drives EVE' end
        -- At GO the race's drive would replace the bike's.
        if o.armed and o.armed() then return 'a race is armed: coop race quit leaves it' end
        return o.busy and o.busy() or nil
    end
    local function mount()
        local e=her()
        local w=Ride.native(status())
        local why=o.settings and o.settings.bike=='off' and 'the bike is off (bike=off)'
            or not e and 'no EVE in the world' or blocked(e,w,true) or busy() or Ride.loaded(w.load)
        local part
        if not why then part,why=part_for(e) end
        if why then
            log('bike refused: '..why)
            return false,why
        end
        local began=os.clock()
        local mesh=assert(valid(e.Mesh),'EVE has no main mesh')
        local rot,at=value_of(mesh.RelativeRotation),value_of(mesh.RelativeLocation)
        local r={eve=e,path=path_of(e),at=address(e),mesh=mesh,part=part,part_path=here.part_path,
            base={Pitch=rot.Pitch,Yaw=rot.Yaw,Roll=rot.Roll},base_at={X=at.X,Y=at.Y,Z=at.Z},lean=0,pitch=0,
            since=began,read=began,ends={}}
        local saved,save_why=store.save(table.concat({r.path,number(rot.Pitch),number(rot.Yaw),number(rot.Roll),
            number(at.X),number(at.Y),number(at.Z)},'\t'))
        if saved==false then
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
        log(('bike on in %.1f ms: her mesh relative rotation P=%.2f Y=%.2f R=%.2f, location %.2f %.2f %.2f'):format(
            (os.clock()-began)*1000,rot.Pitch,rot.Yaw,rot.Roll,at.X,at.Y,at.Z))
        return true,'On the bike: coop bike gets her off.'
    end

    -- Adapted from Eve On Wheels' mesh tilt (handling.lua): her main mesh's relative rotation is its base rotation,
    -- then the lean and the pitch, written only after a change of TILT_STEP degrees or more; teleport is off here.
    local function tilt(r,look)
        local lean,pitch=look.lean or 0,look.pitch or 0
        if math.abs(lean-r.lean)<TILT_STEP and math.abs(pitch-r.pitch)<TILT_STEP then return end
        r.lean,r.pitch=lean,pitch
        local c=value_of(math_lib():ComposeRotators(r.base,{Pitch=PITCH_SIGN*pitch,Yaw=0,Roll=LEAN_SIGN*lean}))
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
        local now=os.clock()
        if now-r.read<POLL then return nil end
        r.read=now
        local w=Ride.native(status())
        if not w then return 'the bike needs the native part' end
        return keep(r,r.eve,w,now)
    end
    -- Every 250 ms while she rides: why she gets off, or nil.
    local function check(r,e,w,now)
        if not e or address(e)~=r.at then return 'her EVE changed' end
        local why=blocked(e,w,false)
        if why then return why end
        if drive.why()~='bike' then return 'her drive went off' end
        if now-r.since>=GATE_WAIT and w.gate~='on' then
            return "SB's actions are not off (bike_gate="..tostring(w.gate)..')'
        end
        drive.slow()
    end
    local function off_line(why)
        stop(why)
        return false,'Off the bike: '..why
    end

    function self.riding() return ride~=nil end
    -- The key, the pad gesture and coop bike: on the bike, or off it. ok and a line for the screen.
    function self.toggle(why)
        if ride then
            stop(why or 'coop bike')
            return true,'Off the bike.'
        end
        return mount()
    end
    -- coop off, bike=off, the guest's race: off the bike. The log line, or nil when she did not ride.
    function self.stop(why) return stop(why or 'coop off') end
    -- Each frame before the native tick, after race/run.lua's steer: the ride's drive, lean and clip. A reason to get
    -- off or an error ends the ride: false and a line for the screen.
    function self.steer()
        local r=ride
        if not r then return end
        local ok,why=pcall(frame,r)
        if not ok then return off_line('an error: '..why_of(why)) end
        if why then return off_line(why) end
    end
    -- Every 250 ms: the preload asked or released as the setting says, the part, the ride's checks. A reason to get off
    -- or an error ends the ride: false and a line for the screen.
    function self.slow()
        local want=not (o.settings and o.settings.bike=='off')
        if want~=preload then
            preload=want
            if not want then
                stop('bike=off')
                local ok,e=pcall(remove_part)
                if not ok then log('bike part not removed: '..why_of(e)) end
            end
            local _,said=ask(want and 'bike load '..Ride.CLIP or 'bike free')
            log('bike='..(want and 'on' or 'off')..': '..tostring(said))
        end
        if not want then return end
        local now=os.clock()
        local ok,why=pcall(function()
            local e=her()
            local w=Ride.native(status())
            if e then part_step(e,w,now) end
            if ride then return check(ride,e,w,now) end
        end)
        if not ok then
            if ride then return off_line('an error: '..why_of(why)) end
            error(why,0)
        end
        if why then return off_line(why) end
    end
    -- At the first tick of a Lua load: an earlier load's coop-bike.txt (it left EVE on the bike) puts her main mesh's
    -- rotation and location back on that EVE if she still is one and hides the bike part, then the file is cleared.
    -- Once. Its drive comes back through coop-drive.txt (race/drive.lua's restore).
    function self.restore()
        if restored then return end
        restored=true
        local line=store.load()
        if not line then return end
        local f={}
        for field in (line..'\t'):gmatch('([^\t]*)\t') do f[#f+1]=field end
        local ok,said=pcall(function()
            local e=U.her(valid(StaticFindObject(f[1])))
            if not e then return 'her EVE is gone' end
            local n={}
            for k=2,7 do n[k]=assert(tonumber(f[k]),'value '..(k-1)..' unreadable in the file') end
            valid(e.Mesh):K2_SetRelativeLocationAndRotation({X=n[5],Y=n[6],Z=n[7]},{Pitch=n[2],Yaw=n[3],Roll=n[4]},
                false,{},false)
            local p=find_part(e)
            if p then p:SetVisibility(false,false) end
            return 'her mesh back'..(p and ', the bike hidden' or '')
        end)
        store.clear()
        log('bike restored from coop-bike.txt: '..(ok and said or 'failed ('..why_of(said)..')'))
    end
    -- coop bike status: the preload, the part, the ride and the values.
    function self.status()
        local w=Ride.native(status())
        local h=here
        local part=h and h.part and Doro.same(h.part,h.part_path) and 'on EVE'
            or h and h.failed and 'not made ('..h.failed..')' or 'not made yet'
        local list={}
        for _,name in ipairs(B.NAMES) do list[#list+1]=name..'='..values[name] end
        return ('bike: preload %s, part %s, %s; %s'):format(w and w.load or 'none (no native part)',part,
            ride and ('riding for %.0f s'):format(os.clock()-ride.since) or 'not riding',table.concat(list,' '))
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
