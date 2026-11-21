-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Doro races' driving on the game thread: online/modes/race/drive_model.lua's car model fed into EVE's own movement
-- each frame while a race drives (online/modes/race/run.lua turns it on at GO and off at our result) or the drive probe
-- runs (coop race drive probe).
-- Its bike drive (vehicles/bike/model.lua's motorcycle model, why 'bike') no longer runs: since November 2026
-- vehicles/bike/ride.lua drives with its own copy, vehicles/bike/drive.lua. Each drive keeps its model.
-- Her movement component's MaxAcceleration, GroundFriction, BrakingDecelerationWalking and BrakingFrictionFactor go to
-- 0 meanwhile, so her movement neither accelerates, brakes nor turns the velocity it is given: each frame the model's
-- velocity reaches it as an impulse. Her yaw is the model's heading. Floor, walls, slopes and gravity stay the
-- game's. Nothing moves while the world's time stands still (the pause menu): impulses would pile up. A dodge or a hit
-- (root motion) holds the model and writes nothing.
-- The four values are the native part's to keep, set and put back (online/modes/race/hold.h, on the game thread behind
-- its fault guard): this file asks race hold on at drive on and race hold off at every end (our result, quit, a DNF,
-- coop off, a map change, a Lua error). The native part puts them back by itself at coop off, at a new Lua load
-- (Ctrl+R) and while a theater plays or photo mode runs. The model's impulses go only while the status line says the
-- hold is applied (race_hold=1, read every 250 ms); a hold still applied with no drive on is asked off again. Her
-- velocity and yaw are all this file writes, on the player's own EVE: never a pawn spawned or possessed, never a save.
-- The drift key: coop-settings.txt's drift_keys, read through the player controller's IsInputKeyDown.
local UE=require('UEHelpers')
local U=require('core.unreal')
local M=require('online.modes.race.drive_model')
local valid,value_of,find=U.valid,U.value_of,U.find
local Drive={}
local MAX_DT=0.1 -- s: a longer frame (a hitch) counts as this much.
local PROBE_SPEED,PROBE_FOR=1500,3 -- cm/s straight ahead for this many s.
local SAY_EVERY=10 -- s between two speed lines: players post UE4SS.log in public, a line a second buries the rest.
local STILL=1 -- cm/s: an impulse under this on both axes is not given once the last frame gave none (parked).
local TURNED=0.01 -- degrees: her yaw this close to the heading is not written again.
local PC='/Script/Engine.PlayerController'

local function path_of(o) return o:GetFullName():match('^%S+ (.+)$') end
-- The player controller, or nil. UEHelpers keeps the last one while its address is valid: after a map change it may
-- be another object.
local function controller()
    local pc=valid(UE.GetPlayerController())
    return pc and pc:IsA(find(PC)) and pc or nil
end
local function same(o,path)
    o=valid(o)
    return o and path_of(o)==path and o or nil
end
local her=U.her
local function list(values,model)
    local out={}
    for _,name in ipairs((model or M).NAMES) do out[#out+1]=name..'='..values[name] end
    return table.concat(out,' ')
end

-- o: log (the [DR] lines), settings (main.lua's: drift_keys), riding() whether EVE rides the bike (the bike drives
-- with its own copy), ask(text) (a request to the native part, core/link.lua's request: true, or false and why; nil
-- without the native part: no drive) and held() (the status line's race_hold: true while the native part holds her
-- four values at 0, false while it does not, nil when unread).
function Drive.new(o)
    local log=o.log
    local self={}
    local values=M.clamp(M.DEFAULTS) -- The host's for this Lua load: coop race drive <name> <value> changes them.
    -- While one drives: eve, path, move, M (its model: online/modes/race/drive_model.lua or vehicles/bike/model.lua), P
    -- (its model's values), state, why ('race', 'probe' or 'bike'), t (her world time at the last frame), keys (each
    -- drift key's last state), pc (the player controller, read at on and checked every 250 ms), held (the hold applied,
    -- as of the last 250 ms read), gave (the last frame gave an impulse of STILL or more), probe ({phase, til, yaw}),
    -- said_at.
    local drive=nil
    local keys_failed=nil -- Why IsInputKeyDown could not be read: no key until the mod reloads.
    local fkeys={}
    -- Nothing to do here since the native part keeps her four values: it puts them back at a new Lua load itself.
    -- main/frame.lua still calls it at each tick.
    function self.restore() end
    function self.active() return drive~=nil end
    function self.racing() return drive~=nil and drive.why=='race' end
    -- Why the drive is on ('race', 'probe' or 'bike'), or nil.
    function self.why() return drive and drive.why end
    function self.values() return M.clamp(values) end
    -- The hold asked off: the native part puts her four values back on the EVE they were kept from, while she is
    -- still that object. Returns the log line.
    function self.off(why)
        local d=drive
        if not d then return 'drive off already' end
        drive=nil
        local asked,ask_why=o.ask('race hold off')
        return 'drive off ('..why..'): '
            ..(asked and 'race hold off asked' or 'race hold off not asked: '..tostring(ask_why))
    end
    -- The hold asked on: the native part keeps her four values and sets them to 0. P: the values to drive with
    -- (online/modes/race/drive_model.lua's, as the line carries them, or model's); why: 'race', 'probe' or 'bike';
    -- model: the model to drive with (online/modes/race/drive_model.lua when nil). Any drive on already (the probe at a
    -- race's GO) goes off first. True, or false and why with nothing asked.
    function self.on(P,why,model)
        model=model or M
        if not o.ask then return false,'the driving needs the native part' end
        if drive then log(self.off('replaced by a '..why)) end
        local e=her(valid(UE.GetPlayer()))
        if not e then return false,'no EVE in the world' end
        local move=valid(e.CharacterMovement)
        if not move then return false,'EVE has no movement component' end
        local asked,ask_why=o.ask('race hold on')
        if not asked then return false,'race hold on not asked: '..tostring(ask_why) end
        drive={eve=e,path=path_of(e),move=move,M=model,P=model.values(P),state={},why=why,keys={},said_at=0,
            pc=controller(),held=false}
        log(('drive on (%s): race hold asked; %s'):format(why,list(model.clamp(P),model)))
        return true
    end
    -- Whether any of the keys names is held on pc, each change logged. Raises on a read that fails.
    local function keys_down(d,pc,names)
        local any=false
        for _,name in ipairs(names) do
            fkeys[name]=fkeys[name] or {KeyName=FName(name)}
            local held=pc:IsInputKeyDown(fkeys[name])==true
            if held~=(d.keys[name]==true) then
                d.keys[name]=held
                log('drive key '..name..(held and ' down' or ' up'))
            end
            any=any or held
        end
        return any
    end
    -- The drift keys (settings.drift_keys): any one held. Each change is logged; a read that fails is said once and
    -- the keys are left out until the mod reloads (the drift then comes from steering alone). No player controller
    -- means no key until a 250 ms check (self.slow) finds one.
    local function drift(d)
        local names=o.settings and o.settings.drift_keys or {}
        if keys_failed or not names[1] or not d.pc then return false end
        local ok,down=pcall(keys_down,d,d.pc,names)
        if ok then return down end
        keys_failed=tostring(down)
        log('drive: the drift keys cannot be read ('..keys_failed..'); drifts come from steering alone')
        return false
    end
    -- The velocity to the movement component: the difference as an impulse (Z left to the game). The impulse an
    -- earlier frame left unused (her movement did not tick: photo mode with photo_pause=scenery runs the world but not
    -- SB's logic) is dropped first, so impulses never pile up. Parked (an impulse under STILL cm/s on both axes after a
    -- frame that gave none), nothing is given: her movement neither brakes nor accelerates meanwhile, so she keeps
    -- within STILL cm/s of the model. None while the hold is not applied: her movement would brake each impulse away.
    local function give(d,vx,vy,v)
        if not d.held then return end
        local ix,iy=vx-v.X,vy-v.Y
        local real=math.abs(ix)>=STILL or math.abs(iy)>=STILL
        if not (real or d.gave) then return end
        d.gave=real
        d.move:ClearAccumulatedForces()
        d.move:AddImpulse({X=ix,Y=iy,Z=0},true)
    end
    -- The probe's first 3 s: 1500 cm/s straight ahead along her yaw at the start, logged each frame; then the model
    -- drives as in a race until coop race drive off.
    local function probe_out(d,t,v)
        local p=d.probe
        p.til=p.til or t+PROBE_FOR
        if t>=p.til then
            p.phase='free'
            log('drive probe phase=free')
            return nil
        end
        local a=math.rad(p.yaw)
        local out={vx=math.cos(a)*PROBE_SPEED,vy=math.sin(a)*PROBE_SPEED,heading=p.yaw}
        log(('drive probe %s target=%.0f read=%.0f,%.0f,%.0f gave=%.0f,%.0f'):format(p.phase,PROBE_SPEED,v.X,v.Y,v.Z,
            out.vx-v.X,out.vy-v.Y))
        return out
    end
    -- Each frame while a drive is on: the model from her stick, drift key and velocity; the velocity, a launch and the
    -- yaw to her. Returns what the look takes ({top, stumble, lean, pitch}: the last two the bike's, in degrees), or
    -- nil once the drive is off (her EVE gone). Raises on a failing call: the caller ends the race, the probe or the
    -- ride. The stick is GetLastMovementInputVector for the bike too: no move block is set while she rides, so SB's
    -- MoveForward handler (FUN_142059df0) still reaches AddMovementInput; every 10 s the bike's line adds the raw
    -- axes SB stored (LastMoveFowardInput, LastMoveRightInput) beside it.
    function self.tick()
        local d=drive
        if not d then return nil end
        local e=same(d.eve,d.path)
        if not e then
            log(self.off('map change'))
            return nil
        end
        local t=value_of(e:GetGameTimeSinceCreation())
        local dt=d.t and t-d.t or 0
        d.t=t
        if dt<=0 then return d.look end -- Paused, or her time not moved since the last frame.
        -- Her vertical speed from her height: on the ground her movement keeps its Velocity.Z at 0
        -- (MaintainHorizontalGroundVelocity at the end of each walking step), so a climb shows only in her place.
        local z=value_of(e:K2_GetActorLocation()).Z
        local vz=d.z and (z-d.z)/dt or 0
        d.z=z
        dt=math.min(dt,MAX_DT)
        local v=value_of(e:GetVelocity())
        local stick=value_of(e:GetLastMovementInputVector())
        local yaw=value_of(e:K2_GetActorRotation()).Yaw
        local input={stick={x=stick.X,y=stick.Y},drift=drift(d),v={x=v.X,y=v.Y,z=vz},falling=d.move:IsFalling()==true,
            root=e:IsPlayingRootMotion()==true,yaw=yaw}
        local out=d.probe and d.probe.phase~='free' and probe_out(d,t,v) or d.M.step(d.state,input,d.P,dt)
        if out.launch then e:LaunchCharacter({X=out.launch.x,Y=out.launch.y,Z=out.launch.z},true,true)
        elseif out.vx then give(d,out.vx,out.vy,v) end
        if out.heading and math.abs((out.heading-yaw+180)%360-180)>=TURNED then
            e:K2_SetActorRotation({Pitch=0,Yaw=out.heading,Roll=0},false)
        end
        if out.stumble then log(('drive wall at %.0f cm/s: stumble'):format(d.state.asked or 0)) end
        if out.launch then log(('drive crest: launched at %.0f cm/s up'):format(out.launch.z)) end
        d.look={top=d.P.top,stumble=out.stumbling==true,lean=out.lean,pitch=out.pitch}
        if t>=d.said_at then -- Every 10 s: her speed, the speed asked, her yaw read against the heading written.
            d.said_at=t+SAY_EVERY
            log(('drive v=%.0f vz=%.0f asked=%.0f yaw=%.1f heading=%s air=%d root=%d drift=%d stumble=%d%s'):format(
                math.sqrt(v.X*v.X+v.Y*v.Y),vz,d.state.asked or 0,yaw,out.heading and ('%.1f'):format(out.heading)
                or '-',input.falling and 1 or 0,input.root and 1 or 0,out.drifting and 1 or 0,out.stumbling and 1 or 0,
                d.why=='bike' and (' lean=%.1f pitch=%.1f stick=%.2f,%.2f raw=%.2f,%.2f'):format(out.lean or 0,
                out.pitch or 0,stick.X,stick.Y,tonumber(value_of(e.LastMoveFowardInput)) or 0,
                tonumber(value_of(e.LastMoveRightInput)) or 0) or ''))
        end
        return d.look
    end
    -- Every 250 ms: whether the native part holds her four values (the native part sets back one the game writes
    -- again, a stance push), each change logged; with no drive on, a hold still applied is asked off again (an off that
    -- never reached the native part). The drive's player controller is read again when it is gone or no longer one.
    function self.slow()
        local held=o.held and o.held()
        local d=drive
        if not d then
            if held==true and o.ask then o.ask('race hold off') end
            return
        end
        if (held==true)~=d.held then
            d.held=held==true
            log('drive hold '..(d.held and 'applied' or 'not applied: her movement brakes, no impulse goes'))
        end
        if not (valid(d.pc) and d.pc:IsA(find(PC))) then d.pc=controller() end
    end
    -- coop race drive [probe | off | <name> <value>]: the values (none), the probe on or off, or one of the host's
    -- values for this Lua load. online/modes/race/run.lua refuses the probe while a race is armed; the probe and its
    -- off wait while EVE rides the bike (vehicles/bike/ride.lua ends that drive).
    function self.command(a,b)
        if a==nil then return true,'drive: '..list(values) end
        if (a=='probe' or a=='off') and b==nil and (drive and drive.why=='bike' or o.riding and o.riding()) then
            return false,'EVE rides the bike: coop bike gets her off first'
        end
        if a=='probe' and b==nil then
            local e=her(valid(UE.GetPlayer()))
            if not e then return false,'no EVE in the world' end
            local yaw=value_of(e:K2_GetActorRotation()).Yaw
            local ok,why=self.on(values,'probe')
            if not ok then return false,why end
            drive.probe={phase='impulse',yaw=yaw}
            log('drive probe phase=impulse')
            return true,'Drive probe: 3 s straight ahead through impulses, then the race model until coop race drive '
                ..'off; [DR] lines in the log.'
        end
        if a=='off' and b==nil then
            if not drive then return false,'no drive probe runs' end
            if drive.why=='race' then return false,'a race drives: coop race quit leaves it' end
            return true,self.off('coop race drive off')
        end
        if b==nil then return false,'Use: coop race drive [probe | off | <name> <value>]' end
        local set,why=M.set(values,a,b)
        if not set then return false,why end
        values=set
        if drive and drive.why=='probe' then drive.P=M.values(values) end
        log('drive '..a..'='..values[a])
        return true,'Drive '..a..'='..values[a]..' for your next races (this Lua load).'
    end
    return self
end
return Drive
