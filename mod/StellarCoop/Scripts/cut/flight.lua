-- coop fly's keys, beside the native part's gate (game/debug_keys.h, through commands/cut.lua), logging [FL] lines.
-- SB's developer flight lasts while a key of USBPlayerInput's DefinedFlyActionKeyLists is held in the air (R2, or Z,
-- which also moves forward on an AZERTY keyboard). It flies along the camera's heading at MaxFlyingActionSpeed, and
-- its velocity takes up and down only from the movement input's Z (FlyingActionVerticalMoveAttenuation), which no key
-- gives. Its four evades are bound to the pad's face buttons only (the flight research of 2026-10-24). While coop fly
-- is on: A and E are the flight keys in place of Z (R2 stays when the list takes a third key, else E takes its place);
-- A held climbs and E held descends, through a movement input straight up or down each frame while EVE flies (both
-- held: level); Shift with Q, D, A or E fires the evade left, right, up or down, through four action mappings added to
-- the input settings. coop fly off, coop off and the next Lua load put the keys and the mappings back. Never called
-- here: a save, the game's key settings file, anything on another character.
local U=require('core.unreal')
local Flight={}
Flight.DEFAULT={'Gamepad_RightTrigger','Z'} -- DefaultInput.ini's DefinedFlyActionKeyLists.
Flight.KEYS={'Gamepad_RightTrigger','A','E'}
Flight.EVADES={{'FlyingActionEvade_Left','Q'},{'FlyingActionEvade_Right','D'},{'FlyingActionEvade_Up','A'},
    {'FlyingActionEvade_Down','E'}}
local SETTINGS='/Script/Engine.Default__InputSettings'
local function key(name) return {KeyName=FName(name)} end

function Flight.new(o)
    local log=o.log
    local self={}
    local on,failed,restored=false,nil,false
    local function list_of()
        local pc=U.controller()
        local h=pc and U.valid(pc.InputHandler)
        if not h then error('no SB player input',0) end
        return h.DefinedFlyActionKeyLists
    end
    local function names(list)
        local t={}
        U.each(list,function(_,k) t[#t+1]=U.text(U.value_of(k).KeyName) end)
        return t
    end
    -- Each name of want into the list, the last one appended where the array takes it; the names it then holds.
    local function write(want)
        local list=list_of()
        for i,n in ipairs(want) do pcall(function() list[i]=key(n) end) end
        return names(list)
    end
    local function mappings(add)
        local s=U.find(SETTINGS)
        for i,e in ipairs(Flight.EVADES) do
            local m={ActionName=FName(e[1]),bShift=true,bCtrl=false,bAlt=false,bCmd=false,bCustomizeKey=false,
                bMainKey=false,bAZERTY=false,Priority=0,SortValue=0,Key=key(e[2])}
            if add then s:AddActionMapping(m,i==#Flight.EVADES) else s:RemoveActionMapping(m,i==#Flight.EVADES) end
        end
    end
    -- Ours: the keys put back (Z again in any third slot) and the mappings taken out. Returns the keys' line.
    local function put_back(list)
        local want={table.unpack(Flight.DEFAULT)}
        if #names(list)>2 then want[3]='Z' end
        local got=write(want)
        mappings(false)
        return table.concat(got,', ')
    end
    function self.on()
        if on then return 'flight keys already A and E' end
        local ok,why=pcall(function()
            local got=write(Flight.KEYS)
            if got[3]~='E' then got=write({'E','A'}) end -- The array took no third key: E in R2's place.
            mappings(true)
            on,failed=true,nil
            local pad=got[1]=='Gamepad_RightTrigger' and 'R2 too' or 'R2 no longer flies'
            log(string.format('flight keys: %s (%s); evades Shift+Q, D, A, E',table.concat(got,', '),pad))
            return string.format('A climbs, E descends, both level (%s); Shift+Q/D/A/E evade',pad)
        end)
        if not ok then log('flight keys not set: '..tostring(why)) end
        return ok and why or 'the flight keys stay the game\'s ('..tostring(why)..')'
    end
    function self.off()
        if not on then return end
        on=false
        local ok,why=pcall(function() return put_back(list_of()) end)
        log(ok and 'flight keys back: '..why or 'flight keys not put back: '..tostring(why))
    end
    -- Once a Lua load, at the first tick with a player input: keys an earlier load left (A and E in the list) go back.
    function self.restore()
        if restored or on then return end
        local ok,list=pcall(list_of)
        if not ok then return end
        restored=true
        local got=table.concat(names(list),',')
        if not (got:find('A',1,true) and got:find('E',1,true)) then return end
        local done,why=pcall(put_back,list)
        log(done and 'flight keys an earlier Lua load left, back: '..why or 'flight keys not put back: '..tostring(why))
    end
    -- Each frame while on and EVE flies: A or E held, a movement input straight up or down.
    function self.tick()
        if not on then return end
        local ok,why=pcall(function()
            local pc=U.controller()
            local eve=pc and U.valid(pc:K2_GetPawn())
            if not (eve and eve:IsFlyingAction()) then return end
            local up,down=pc:IsInputKeyDown(key('A'))==true,pc:IsInputKeyDown(key('E'))==true
            if up~=down then eve:AddMovementInput({X=0,Y=0,Z=up and 1 or -1},1.0,false) end
        end)
        if not ok and why~=failed then log('flight climb unread: '..tostring(why)) end
        failed=not ok and why or nil
    end
    return self
end
return Flight
