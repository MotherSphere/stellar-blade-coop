-- coop fly's keys (cut/flight.lua) with fakes: the flight key list taking a third key (R2, A, E) or not (E, A), the
-- four Shift evade mappings added once and taken out, a climb or a descent each frame only while EVE flies with A or E
-- held (none with both or neither), the keys and mappings back at off, the restore once a load of keys an earlier
-- load left (never while on), and no player input (the game's keys stay).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
FName=function(t) return {type=function() return 'FName' end,ToString=function() return t end} end
local function object(t)
    t.type=t.type or function() return 'UObject' end
    t.IsValid=t.IsValid or function() return true end
    return t
end
local added,removed,inputs,held,flying={},{},{},{},false
local settings=object({AddActionMapping=function(_,m,rebuild) added[#added+1]={m,rebuild} end,
    RemoveActionMapping=function(_,m,rebuild) removed[#removed+1]={m,rebuild} end})
local pc_class=object({})
local eve=object({IsFlyingAction=function() return flying end,
    AddMovementInput=function(_,v,scale,force) inputs[#inputs+1]={v.Z,scale,force} end})
local handler=object({})
local pc=object({InputHandler=handler,IsA=function(_,c) return c==pc_class end,K2_GetPawn=function() return eve end,
    IsInputKeyDown=function(_,k) return held[k.KeyName:ToString()]==true end})
local have_pc=true
package.loaded.UEHelpers={GetPlayerController=function() return have_pc and pc or nil end}
StaticFindObject=function(path)
    if path=='/Script/Engine.PlayerController' then return pc_class end
    assert(path=='/Script/Engine.Default__InputSettings',path)
    return settings
end
local function keys(...) local t={} for i,n in ipairs({...}) do t[i]={KeyName=FName(n)} end return t end
local function names() local t={} for i,k in ipairs(handler.DefinedFlyActionKeyLists) do t[i]=k.KeyName:ToString() end
    return table.concat(t,',') end
local lines={}
local F=require('cut.flight')
local function fresh() return F.new({log=function(m) lines[#lines+1]=m end}) end

-- On: R2, A, E; four Shift mappings, the keymaps rebuilt at the last.
handler.DefinedFlyActionKeyLists=keys('Gamepad_RightTrigger','Z')
local f=fresh()
local said=f.on()
assert(names()=='Gamepad_RightTrigger,A,E' and said:find('R2 too',1,true),names()..' / '..said)
assert(#added==4 and added[1][1].ActionName:ToString()=='FlyingActionEvade_Left' and added[1][1].bShift==true
    and added[1][1].Key.KeyName:ToString()=='Q' and added[4][1].Key.KeyName:ToString()=='E' and added[4][2]==true
    and added[1][2]==false)
assert(lines[#lines]=='flight keys: Gamepad_RightTrigger, A, E (R2 too); evades Shift+Q, D, A, E',lines[#lines])
assert(f.on()=='flight keys already A and E' and #added==4,'Once')
-- Each frame: nothing on the ground; flying, A climbs, E descends, both or neither nothing.
held.A=true; f.tick(); assert(#inputs==0,'Not flying')
flying=true; f.tick(); assert(#inputs==1 and inputs[1][1]==1 and inputs[1][2]==1.0 and inputs[1][3]==false)
held.A,held.E=false,true; f.tick(); assert(#inputs==2 and inputs[2][1]==-1)
held.A=true; f.tick(); held.A,held.E=false,false; f.tick(); assert(#inputs==2,'Both or neither: level')
-- Off: R2 and Z back (Z in the third slot too), the mappings out; a tick then does nothing.
f.off()
assert(names()=='Gamepad_RightTrigger,Z,Z' and #removed==4 and removed[4][2]==true,names())
held.A=true; f.tick(); assert(#inputs==2); held.A=false
-- A list that takes no third key: E in R2's place.
handler.DefinedFlyActionKeyLists=setmetatable({},{__index=keys('Gamepad_RightTrigger','Z'),
    __newindex=function(t,i,v) if i>2 then error('no room') end rawset(t,i,v) end})
local fixed=handler.DefinedFlyActionKeyLists
local g=fresh()
said=g.on()
assert(fixed[1].KeyName:ToString()=='E' and fixed[2].KeyName:ToString()=='A' and said:find('R2 no longer flies',1,true))
-- A later Lua load: keys an earlier one left go back once; never while on.
handler.DefinedFlyActionKeyLists=keys('Gamepad_RightTrigger','A','E')
local h=fresh()
h.restore()
assert(names()=='Gamepad_RightTrigger,Z,Z' and lines[#lines]:find('^flight keys an earlier Lua load left, back'),names())
handler.DefinedFlyActionKeyLists=keys('Gamepad_RightTrigger','A','E')
h.restore(); assert(names()=='Gamepad_RightTrigger,A,E','Once a load')
local k=fresh(); k.on(); k.restore(); assert(names()=='Gamepad_RightTrigger,A,E','Not while on')
-- No player input: the game's keys stay, said.
have_pc=false
said=fresh().on()
assert(said=='the flight keys stay the game\'s (no SB player input)',said)
print('flight_test ok')
