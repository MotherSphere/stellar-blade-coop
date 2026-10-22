-- Doro races' driving on the game thread: drive_model.lua's car model fed into EVE's own movement each frame while a
-- race drives (race.lua turns it on at GO and off at our result) or the drive probe runs (coop race drive probe). Her
-- movement component's MaxAcceleration, GroundFriction, BrakingDecelerationWalking and BrakingFrictionFactor go to 0
-- meanwhile, so her movement neither accelerates, brakes nor turns the velocity it is given: each frame the model's
-- velocity reaches it as an impulse (or, with coop race drive feed struct, a write of its Velocity), and her yaw is the
-- model's heading. Floor, walls, slopes and gravity stay the game's. Nothing moves while the world's time stands still
-- (the pause menu): impulses would pile up. A dodge or a hit (root motion) holds the model and writes nothing.
-- The four values are kept in coop-drive.txt before they change and written back at every end (our result, quit, a
-- DNF, coop off, a map change, a Lua error), or by the next Lua load (Ctrl+R) when this one could not. That and the
-- velocity and yaw are all it writes, on the player's own EVE: never a pawn spawned or possessed, never a save.
-- The drift key: coop-settings.txt's drift_keys, read through the player controller's IsInputKeyDown.
local UE=require('UEHelpers')
local U=require('unreal')
local M=require('drive_model')
local valid,value_of,find=U.valid,U.value_of,U.find
local Drive={}
local FIELDS={'MaxAcceleration','GroundFriction','BrakingDecelerationWalking','BrakingFrictionFactor'}
local MAX_DT=0.1 -- s: a longer frame (a hitch) counts as this much.
local PROBE_SPEED,PROBE_FOR=1500,3 -- cm/s straight ahead, and s for each of the probe's two feeds.

local function path_of(o) return o:GetFullName():match('^%S+ (.+)$') end
local function same(o,path)
    o=valid(o)
    return o and path_of(o)==path and o or nil
end
local function her(pawn) return pawn and pawn:IsA(find('/Script/SB.SBCharacter')) and pawn or nil end
local function list(values)
    local out={}
    for _,name in ipairs(M.NAMES) do out[#out+1]=name..'='..values[name] end
    return table.concat(out,' ')
end

-- o: log (the [DR] lines), store (coop-drive.txt through link.store; nil without the native part: no restore) and
-- settings (main.lua's: drift_keys).
function Drive.new(o)
    local log=o.log
    local store=o.store or {save=function() end,load=function() end,clear=function() end}
    local self={}
    local values=M.clamp(M.DEFAULTS) -- The host's for this Lua load: coop race drive <name> <value> changes them.
    local feed='impulse'
    -- While one drives: eve, path, move, kept (the four values), P (drive_model's), state, why ('race' or 'probe'),
    -- t (her world time at the last frame), keys (each drift key's last state), probe ({phase, til, yaw}), said_at.
    local drive=nil
    local restored=false
    local keys_failed=nil -- Why IsInputKeyDown could not be read: no key until the mod reloads.
    local fkeys={}
    -- The four values on her movement (or kept), as one log word list.
    local function fields(move)
        local out={}
        for _,f in ipairs(FIELDS) do out[#out+1]=f..'='..string.format('%g',value_of(move[f])) end
        return table.concat(out,' ')
    end
    -- An earlier Lua load's coop-drive.txt (its drive was on): the four values back on that EVE if she still is one,
    -- then the file cleared. Once, at the first tick. One line: EVE's path, then the four values, tab-separated.
    function self.restore()
        if restored then return end
        restored=true
        local line=store.load()
        if not line then return end
        local f={}
        for field in (line..'\t'):gmatch('([^\t]*)\t') do f[#f+1]=field end
        local ok,why=pcall(function()
            local e=her(valid(StaticFindObject(f[1])))
            if not e then return 'her EVE is gone' end
            local move=valid(e.CharacterMovement)
            for k,name in ipairs(FIELDS) do move[name]=assert(tonumber(f[k+1]),name..' unreadable in the file') end
            return fields(move)
        end)
        store.clear()
        log('drive restored from coop-drive.txt: '..(ok and tostring(why) or 'failed ('..tostring(why)..')'))
    end
    function self.active() return drive~=nil end
    function self.racing() return drive~=nil and drive.why=='race' end
    function self.values() return M.clamp(values) end
    -- The four values back on the EVE they were kept from, while she is still that object (after a map change she is
    -- not, and nothing is written); the file cleared when nothing failed. Returns the log line.
    function self.off(why)
        local d=drive
        if not d then return 'drive off already' end
        drive=nil
        local ok,e=pcall(function()
            local move=same(d.eve,d.path) and same(d.move,d.move_path)
            if not move then return 'her EVE is gone, nothing to write' end
            for _,f in ipairs(FIELDS) do move[f]=d.kept[f] end
            return fields(move)..' back'
        end)
        if ok then store.clear() end
        return 'drive off ('..why..'): '
            ..(ok and e or 'failed, coop-drive.txt kept for the next Lua load: '..tostring(e))
    end
    -- The four values kept (the file first: whatever happens next, the next Lua load can undo it), then 0. P: the
    -- values to drive with (drive_model.lua's, as the line carries them); why: 'race' or 'probe'. Any drive on
    -- already (the probe at a race's GO) goes off first. True, or false and why with nothing left changed.
    function self.on(P,why)
        if drive then log(self.off('replaced by a '..why)) end
        local e=her(valid(UE.GetPlayer()))
        if not e then return false,'no EVE in the world' end
        local move=valid(e.CharacterMovement)
        if not move then return false,'EVE has no movement component' end
        local d={eve=e,path=path_of(e),move=move,move_path=path_of(move),kept={},P=M.values(P),state={},why=why,
            keys={},said_at=0}
        -- A file this Lua load left (an off that could not write the values back) holds hers: never replaced by the
        -- zeros she still has.
        local left={}
        for field in ((store.load() or '')..'\t'):gmatch('([^\t]*)\t') do left[#left+1]=field end
        local line={d.path}
        for k,f in ipairs(FIELDS) do
            d.kept[f]=left[1]==d.path and tonumber(left[k+1]) or tonumber(value_of(move[f]))
            if not d.kept[f] then return false,f..' is unreadable' end
            line[#line+1]=string.format('%.9g',d.kept[f])
        end
        local saved,save_why=store.save(table.concat(line,'\t'))
        if saved==false then return false,save_why end
        drive=d
        local ok,e=pcall(function() for _,f in ipairs(FIELDS) do move[f]=0 end end)
        if not ok then
            local message=self.off('error')
            return false,'its movement values could not be set ('..tostring(e)..'); '..message
        end
        log(('drive on (%s): %s kept; %s'):format(why,fields(d.kept),list(M.clamp(P))))
        return true
    end
    -- The drift keys (settings.drift_keys): any one held. Each change is logged; a read that fails is said once and
    -- the keys are left out until the mod reloads (the drift then comes from steering alone). No player controller
    -- this frame only skips this frame.
    local function drift(d)
        local names=o.settings and o.settings.drift_keys or {}
        if keys_failed or not names[1] then return false end
        local pc=valid(UE.GetPlayerController())
        -- UEHelpers keeps the last one while its address is valid: after a map change it may be another object.
        if not (pc and pc:IsA(find('/Script/Engine.PlayerController'))) then return false end
        local ok,down=pcall(function()
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
        end)
        if ok then return down end
        keys_failed=tostring(down)
        log('drive: the drift keys cannot be read ('..keys_failed..'); drifts come from steering alone')
        return false
    end
    -- The velocity to the movement component: the difference as an impulse (Z left to the game), or a write of its
    -- Velocity with her own vertical speed. The impulse an earlier frame left unused (her movement did not tick: photo
    -- mode with photo_pause=scenery runs the world but not SB's logic) is dropped first, so impulses never pile up.
    local function give(d,vx,vy,v)
        if (d.feed or feed)=='struct' then d.move.Velocity={X=vx,Y=vy,Z=v.Z}
        else
            d.move:ClearAccumulatedForces()
            d.move:AddImpulse({X=vx-v.X,Y=vy-v.Y,Z=0},true)
        end
    end
    -- The probe's first 6 s: 1500 cm/s straight ahead along her yaw at the start, 3 s through each feed, logged each
    -- frame; then the model drives as in a race until coop race drive off.
    local function probe_out(d,t,v)
        local p=d.probe
        p.til=p.til or t+PROBE_FOR
        if t>=p.til then
            p.phase,p.til=p.phase=='impulse' and 'struct' or 'free',t+PROBE_FOR
            d.feed=p.phase~='free' and p.phase or nil
            log('drive probe phase='..p.phase)
            if p.phase=='free' then return nil end
        end
        local a=math.rad(p.yaw)
        local out={vx=math.cos(a)*PROBE_SPEED,vy=math.sin(a)*PROBE_SPEED,heading=p.yaw}
        log(('drive probe %s target=%.0f read=%.0f,%.0f,%.0f gave=%.0f,%.0f'):format(p.phase,PROBE_SPEED,v.X,v.Y,v.Z,
            out.vx-v.X,out.vy-v.Y))
        return out
    end
    -- Each frame while a drive is on: the model from her stick, drift key and velocity; the velocity, a launch and the
    -- yaw to her. Returns what the look takes ({top, stumble}), or nil once the drive is off (her EVE gone). Raises on
    -- a failing call: the caller ends the race or the probe.
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
        local out=d.probe and d.probe.phase~='free' and probe_out(d,t,v) or M.step(d.state,input,d.P,dt)
        if out.launch then e:LaunchCharacter({X=out.launch.x,Y=out.launch.y,Z=out.launch.z},true,true)
        elseif out.vx then give(d,out.vx,out.vy,v) end
        if out.heading then e:K2_SetActorRotation({Pitch=0,Yaw=out.heading,Roll=0},false) end
        if out.stumble then log(('drive wall at %.0f cm/s: stumble'):format(d.state.asked or 0)) end
        if out.launch then log(('drive crest: launched at %.0f cm/s up'):format(out.launch.z)) end
        d.look={top=d.P.top,stumble=out.stumbling==true}
        if t>=d.said_at then -- Once a second: her speed, the speed asked, her yaw read against the heading written.
            d.said_at=t+1
            log(('drive v=%.0f vz=%.0f asked=%.0f yaw=%.1f heading=%s air=%d root=%d drift=%d stumble=%d'):format(
                math.sqrt(v.X*v.X+v.Y*v.Y),vz,d.state.asked or 0,yaw,out.heading and ('%.1f'):format(out.heading)
                or '-',input.falling and 1 or 0,input.root and 1 or 0,out.drifting and 1 or 0,out.stumbling and 1 or 0))
        end
        return d.look
    end
    -- Every 250 ms: any of the four the game wrote again (a stance push) goes back to 0, and is logged.
    function self.slow()
        local d=drive
        if not d or not same(d.move,d.move_path) then return end
        for _,f in ipairs(FIELDS) do
            local now=value_of(d.move[f])
            if now~=0 then
                log(('drive field %s=%g written by the game: 0 again'):format(f,now))
                d.move[f]=0
            end
        end
    end
    -- coop race drive [probe | off | feed impulse|struct | <name> <value>]: the values (none), the probe on or off,
    -- how the velocity reaches her movement, or one of the host's values for this Lua load. race.lua refuses the probe
    -- while a race is armed.
    function self.command(a,b)
        if a==nil then return true,'drive: '..list(values)..' feed='..feed end
        if a=='probe' and b==nil then
            local e=her(valid(UE.GetPlayer()))
            if not e then return false,'no EVE in the world' end
            local yaw=value_of(e:K2_GetActorRotation()).Yaw
            local ok,why=self.on(values,'probe')
            if not ok then return false,why end
            drive.probe,drive.feed={phase='impulse',yaw=yaw},'impulse'
            log('drive probe phase=impulse')
            return true,'Drive probe: 3 s straight ahead through impulses, 3 s through Velocity writes, then the race '
                ..'model until coop race drive off; [DR] lines in the log.'
        end
        if a=='off' and b==nil then
            if not drive then return false,'no drive probe runs' end
            if drive.why=='race' then return false,'a race drives: coop race quit leaves it' end
            return true,self.off('coop race drive off')
        end
        if a=='feed' and (b=='impulse' or b=='struct') then
            feed=b
            log('drive feed='..b)
            return true,'Drive feed: '..b..' from the next frame.'
        end
        if b==nil then return false,'Use: coop race drive [probe | off | feed impulse|struct | <name> <value>]' end
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
