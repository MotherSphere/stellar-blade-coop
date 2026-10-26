-- coop fly's keys, beside the native part's gate (game/debug_keys.h, through commands/cut.lua), logging [FL] lines.
-- SB's developer flight lasts while a key of USBPlayerInput's DefinedFlyActionKeyLists is held in the air (R2, or Z,
-- which also moves forward on an AZERTY keyboard): its input pass sets bPushedFlyingActionKey each frame, and EVE's
-- tick ends the flight once it reads false. It flies along the camera's heading at MaxFlyingActionSpeed, and its
-- velocity takes up and down only from the movement input's Z (FlyingActionVerticalMoveAttenuation), which no key
-- gives. Its four evades are bound to the pad's face buttons only (the flight research of 2026-10-24). While coop fly
-- is on: Z or S in the air starts a flight (S joins the key list: R2 stays when the list takes a third key, as it did
-- in game, else S takes its place); Z held climbs and S held descends, through a movement input straight up or down
-- each frame while EVE flies; with neither held she flies level until the space bar (her jump key) drops her or the
-- game ends the flight (landing, its 90 s pool). The level flight is the native part's (game/debug_keys.h's Hold): a
-- hook on the player controller's input pass sets bPushedFlyingActionKey again after the pass, before EVE's tick reads
-- it, and stops at her jump key (from Lua it came too early, before the pass, or too late, from her blueprint's
-- ReceiveTick: in game the flight ended 0.02 s after the keys were let go). Shift with Q, D, Z or S fires the evade
-- left, right, up or down, through four action mappings added to the input settings. The log says once a flight whether
-- the level flight held (HOLD s with no key). The game's flight sets its velocity whole each frame, with no easing: the
-- climb and the descent here ease in and out over RAMP s, and a flight starts at START of MaxFlyingActionSpeed and
-- reaches all of it in START_RAMP s (its value put back when the flight ends). coop fly off, coop off and the next Lua
-- load put the keys and the mappings back. Never called here: a save, the game's key settings file, anything on another
-- character.
local U=require('core.unreal')
local Flight={}
Flight.DEFAULT={'Gamepad_RightTrigger','Z'} -- DefaultInput.ini's DefinedFlyActionKeyLists.
Flight.KEYS={'Gamepad_RightTrigger','Z','S'}
Flight.UP,Flight.DOWN,Flight.DROP='Z','S','SpaceBar'
Flight.EVADES={{'FlyingActionEvade_Left','Q'},{'FlyingActionEvade_Right','D'},{'FlyingActionEvade_Up','Z'},
    {'FlyingActionEvade_Down','S'}}
Flight.HOLD=0.5 -- s with no key held after which a flight still on says the level flight holds.
Flight.RAMP,Flight.START,Flight.START_RAMP=0.3,0.4,0.6 -- s; share of the speed at the start; s to all of it.
local SETTINGS='/Script/Engine.Default__InputSettings'
local function key(name) return {KeyName=FName(name)} end

function Flight.new(o)
    local log=o.log
    local self={}
    local on,failed,restored=false,nil,false
    -- This flight: dropped (the space bar), since (os.clock with no key held, nil while one is), said (its line), at
    -- (os.clock at its first tick), last (at the last tick), v (the eased climb, -1 to 1), speed (the game's
    -- MaxFlyingActionSpeed, put back at its end), cmc (EVE's movement component).
    local fl=nil
    local function speed_back()
        if fl and fl.speed then pcall(function() fl.cmc.MaxFlyingActionSpeed=fl.speed end) end
    end
    local function handler()
        local pc=U.controller()
        local h=pc and U.valid(pc.InputHandler)
        if not h then error('no SB player input',0) end
        return h,pc
    end
    local function names(list)
        local t={}
        U.each(list,function(_,k) t[#t+1]=U.text(U.value_of(k).KeyName) end)
        return t
    end
    -- Each name of want into the list, the last one appended where the array takes it; the names it then holds.
    local function write(want)
        local list=handler().DefinedFlyActionKeyLists
        for i,n in ipairs(want) do pcall(function() list[i]=key(n) end) end
        return names(list)
    end
    local function mappings(add,evades)
        local s=U.find(SETTINGS)
        for i,e in ipairs(evades) do
            local m={ActionName=FName(e[1]),bShift=true,bCtrl=false,bAlt=false,bCmd=false,bCustomizeKey=false,
                bMainKey=false,bAZERTY=false,Priority=0,SortValue=0,Key=key(e[2])}
            if add then s:AddActionMapping(m,i==#evades) else s:RemoveActionMapping(m,i==#evades) end
        end
    end
    -- Ours: the keys put back (Z again in any third slot) and the mappings taken out, the A and E ones of the first
    -- version too. Returns the keys' line.
    local function put_back(list)
        local want={table.unpack(Flight.DEFAULT)}
        if #names(list)>2 then want[3]='Z' end
        local got=write(want)
        mappings(false,Flight.EVADES)
        mappings(false,{{'FlyingActionEvade_Up','A'},{'FlyingActionEvade_Down','E'}})
        return table.concat(got,', ')
    end
    function self.on()
        if on then return 'flight keys already Z and S' end
        local ok,why=pcall(function()
            local got=write(Flight.KEYS)
            if got[3]~='S' then got=write({'S','Z'}) end -- The array took no third key: S in R2's place.
            mappings(true,Flight.EVADES)
            on,failed,fl=true,nil,nil
            local pad=got[1]=='Gamepad_RightTrigger' and 'R2 too' or 'R2 no longer flies'
            log(string.format('flight keys: %s (%s); evades Shift+Q, D, Z, S',table.concat(got,', '),pad))
            return string.format('Z climbs, S descends, neither flies level, space drops (%s); Shift+Q/D/Z/S evade',pad)
        end)
        if not ok then log('flight keys not set: '..tostring(why)) end
        return ok and why or 'the flight keys stay the game\'s ('..tostring(why)..')'
    end
    function self.off()
        if not on then return end
        speed_back()
        on,fl=false,nil
        local ok,why=pcall(function() return put_back(handler().DefinedFlyActionKeyLists) end)
        log(ok and 'flight keys back: '..why or 'flight keys not put back: '..tostring(why))
    end
    -- Once a Lua load, at the first tick with a player input: keys an earlier load left (S, or A and E, in the list)
    -- go back.
    function self.restore()
        if restored or on then return end
        local ok,list=pcall(function() return handler().DefinedFlyActionKeyLists end)
        if not ok then return end
        restored=true
        local got=','..table.concat(names(list),',')..','
        if not (got:find(',S,',1,true) or got:find(',A,',1,true) and got:find(',E,',1,true)) then return end
        local done,why=pcall(put_back,list)
        log(done and 'flight keys an earlier Lua load left, back: '..why or 'flight keys not put back: '..tostring(why))
    end
    -- Each frame while on and EVE flies: Z or S held, a movement input straight up or down. Said once a flight: whether
    -- the native part's level flight held (none after the space bar).
    function self.tick()
        if not on then return end
        local ok,why=pcall(function()
            local _,pc=handler()
            local eve=U.valid(pc:K2_GetPawn())
            local flying=eve and eve:IsFlyingAction()==true
            if not flying then
                speed_back()
                if fl and fl.since and not fl.dropped and not fl.said then
                    log(string.format('level flight did not hold: the flight ended %.2f s after the keys were let go',
                        os.clock()-fl.since))
                end
                fl=nil
                return
            end
            local now=os.clock()
            if not fl then
                local cmc=U.valid(eve.CharacterMovement)
                fl={at=now,last=now,v=0,cmc=cmc,speed=cmc and tonumber(cmc.MaxFlyingActionSpeed)}
            end
            local dt=math.min(0.1,now-fl.last)
            fl.last=now
            if fl.speed then -- The start: from START of the speed to all of it, then the game's value again.
                local share=math.min(1,Flight.START+(1-Flight.START)*(now-fl.at)/Flight.START_RAMP)
                fl.cmc.MaxFlyingActionSpeed=fl.speed*share
                if share>=1 then fl.speed=nil end
            end
            local up,down=pc:IsInputKeyDown(key(Flight.UP))==true,pc:IsInputKeyDown(key(Flight.DOWN))==true
            if pc:IsInputKeyDown(key(Flight.DROP))==true then fl.dropped=true end
            local want=up==down and 0 or up and 1 or -1 -- The climb eases toward it.
            local step=dt/Flight.RAMP
            fl.v=fl.v<want and math.min(want,fl.v+step) or math.max(want,fl.v-step)
            if math.abs(fl.v)>0.01 then eve:AddMovementInput({X=0,Y=0,Z=fl.v},1.0,false) end
            if up or down then fl.since=nil return end
            if fl.dropped then return end
            fl.since=fl.since or os.clock()
            if not fl.said and os.clock()-fl.since>=Flight.HOLD then
                fl.said=true
                log(string.format('level flight holds with no key held (%.1f s)',os.clock()-fl.since))
            end
        end)
        if not ok and why~=failed then log('flight keys unread: '..tostring(why)) end
        failed=not ok and why or nil
    end
    return self
end
return Flight
