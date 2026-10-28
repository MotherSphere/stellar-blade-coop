-- coop fly's keys (cut/flight.lua) with fakes: R2 written over every slot of the flight key list (two, or three as an
-- earlier version left it), the four Shift evade mappings added once and taken out (and the first version's A and E
-- ones), a climb or a descent each frame only while EVE flies with Z or S held (none with both), its line once a flight
-- (held, or ended, none after a press of the space bar, said when it was held from before the flight), no hook of its
-- own (the start and the level flight are the native part's), the keys and mappings back at off, the restore once a
-- load of keys an earlier load left (this version's R2 alone, S, or A and E, or our Shift evades left in the input
-- settings; never while on, nothing for the game's own keys), and no player input (the game's keys stay).
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
local cmc=object({MaxFlyingActionSpeed=1000})
RegisterHook=function() error('flight.lua registers no hook') end
local eve=object({IsFlyingAction=function() return flying end,CharacterMovement=cmc,
    AddMovementInput=function(_,v,scale,force) inputs[#inputs+1]={v.Z,scale,force} end})
local handler=object({})
local clock=0
os.clock=function() return clock end
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

-- On: R2 alone; four Shift mappings, the keymaps rebuilt at the last.
handler.DefinedFlyActionKeyLists=keys('Gamepad_RightTrigger','Z')
local f=fresh()
local said=f.on()
assert(names()=='Gamepad_RightTrigger,Gamepad_RightTrigger' and said:find('space three times',1,true),
    names()..' / '..said)
assert(#added==4 and added[1][1].ActionName:ToString()=='FlyingActionEvade_Left' and added[1][1].bShift==true
    and added[1][1].Key.KeyName:ToString()=='Q' and added[4][1].Key.KeyName:ToString()=='S' and added[4][2]==true
    and added[1][2]==false)
assert(lines[#lines]=='flight keys: Gamepad_RightTrigger, Gamepad_RightTrigger (space three times in the air flies);'
    ..' evades Shift+Q, D, Z, S',lines[#lines])
assert(f.on()=='flight keys already R2 alone' and #added==4,'Once')
-- Each frame: nothing on the ground; flying, Z climbs and S descends, each eased over 0.3 s (frames of 0.05 s here);
-- the speed starts at 40 % and reaches all of it in 0.6 s, then the game's value is left alone.
local function frame() clock=clock+0.05; f.tick() end
held.Z=true; f.tick(); assert(#inputs==0 and not handler.bPushedFlyingActionKey,'Not flying')
flying=true; f.tick()
assert(#inputs==0 and cmc.MaxFlyingActionSpeed==400,'The first frame: no climb yet, 40 % of the speed')
frame(); assert(#inputs==1 and math.abs(inputs[1][1]-1/6)<1e-9 and inputs[1][2]==1.0 and inputs[1][3]==false)
assert(math.abs(cmc.MaxFlyingActionSpeed-450)<1e-6)
for _=1,11 do frame() end
assert(inputs[#inputs][1]==1 and cmc.MaxFlyingActionSpeed==1000,'All of it')
cmc.MaxFlyingActionSpeed=777; frame(); assert(cmc.MaxFlyingActionSpeed==777,'Then left alone')
held.Z,held.S=false,true; frame(); assert(math.abs(inputs[#inputs][1]-5/6)<1e-9 and not handler.bPushedFlyingActionKey)
for _=1,12 do frame() end; assert(inputs[#inputs][1]==-1,'Down')
held.Z,held.S=true,true; for _=1,6 do frame() end
local n=#inputs; frame(); assert(#inputs==n,'Both: eased back to level, no input')
-- Neither held: still flying HOLD s later, said once a flight; the fly key is the native part's, never written here.
held.Z,held.S=false,false; frame()
clock=clock+0.5; f.tick(); assert(lines[#lines]:find('^level flight holds with no key held'),lines[#lines])
n=#lines; clock=clock+2; f.tick(); assert(#lines==n,'Said once a flight')
assert(handler.bPushedFlyingActionKey==nil,'Never written here')
-- A new flight that ends right after the keys are let go: said; not after the space bar.
flying=false; f.tick(); flying=true; clock=30; f.tick(); clock=30.1; flying=false; f.tick()
assert(lines[#lines]=='level flight did not hold: the flight ended 0.10 s after the keys were let go',lines[#lines])
n=#lines; flying=true; clock=40; f.tick(); held.SpaceBar=true; clock=40.1; f.tick(); held.SpaceBar=false
clock=40.2; flying=false; f.tick(); assert(#lines==n,'Dropped by the space bar: not said')
-- The space bar held from the jump before the flight: no press, so the flight's line still comes; let go and pressed
-- again, it drops her.
held.SpaceBar=true; flying=true; clock=50; f.tick(); clock=50.1; f.tick(); held.SpaceBar=false
clock=50.2; flying=false; f.tick()
assert(lines[#lines]=='level flight did not hold: the flight ended 0.20 s after the keys were let go',lines[#lines])
held.SpaceBar=true; flying=true; clock=60; f.tick(); held.SpaceBar=false; clock=60.1; f.tick()
n=#lines; held.SpaceBar=true; clock=60.2; f.tick(); held.SpaceBar=false
clock=60.3; flying=false; f.tick(); assert(#lines==n,'Let go and pressed again: dropped, not said')
-- Off: R2 and Z back, the mappings out (the A and E ones too); a tick then does nothing.
f.off()
assert(names()=='Gamepad_RightTrigger,Z' and #removed==6 and removed[4][2]==true,names())
n=#inputs; flying=true; held.Z=true; f.tick(); assert(#inputs==n); held.Z=false
-- A list with a third slot (the last version's R2, Z, S): R2 in all three, then Z in the second and third at off.
handler.DefinedFlyActionKeyLists=keys('Gamepad_RightTrigger','Z','S')
local g=fresh()
g.on(); assert(names()=='Gamepad_RightTrigger,Gamepad_RightTrigger,Gamepad_RightTrigger',names())
g.off(); assert(names()=='Gamepad_RightTrigger,Z,Z',names())
-- A later Lua load: keys an earlier one left go back once; never while on; the game's own keys stay.
handler.DefinedFlyActionKeyLists=keys('Gamepad_RightTrigger','Gamepad_RightTrigger')
local h=fresh()
h.restore()
assert(names()=='Gamepad_RightTrigger,Z' and lines[#lines]:find('^flight keys an earlier Lua load left, back'),names())
handler.DefinedFlyActionKeyLists=keys('Gamepad_RightTrigger','Gamepad_RightTrigger')
h.restore(); assert(names()=='Gamepad_RightTrigger,Gamepad_RightTrigger','Once a load')
local k=fresh(); k.on(); k.restore(); assert(names()=='Gamepad_RightTrigger,Gamepad_RightTrigger','Not while on')
handler.DefinedFlyActionKeyLists=keys('Gamepad_RightTrigger','Z','S') -- The last version's keys go back too,
fresh().restore(); assert(names()=='Gamepad_RightTrigger,Z,Z',names())
handler.DefinedFlyActionKeyLists=keys('Gamepad_RightTrigger','A','E') -- and the first version's.
fresh().restore(); assert(names()=='Gamepad_RightTrigger,Z,Z',names())
n=#lines; handler.DefinedFlyActionKeyLists=keys('Gamepad_RightTrigger','Z')
fresh().restore(); assert(names()=='Gamepad_RightTrigger,Z' and #lines==n,'The game\'s keys: nothing done')
-- The game's keys, but our Shift evades still in the input settings (SB saves those to its config with its key
-- options, so they can outlive the game run that added them): taken out. The game's own mappings alone: nothing done.
local function mapping(action,key,shift) return {ActionName=FName(action),Key={KeyName=FName(key)},bShift=shift} end
settings.ActionMappings={mapping('Evade','LeftShift',false),mapping('FlyingActionEvade_Up','Z',false)}
local was_removed,was_said=#removed,#lines
fresh().restore(); assert(#removed==was_removed and #lines==was_said,'Not ours: nothing done')
settings.ActionMappings[3]=mapping('FlyingActionEvade_Up','Z',true)
fresh().restore()
assert(#removed==was_removed+6 and removed[#removed][2]==true and names()=='Gamepad_RightTrigger,Z'
    and lines[#lines]:find('^flight keys an earlier Lua load left, back'),#removed-was_removed)
settings.ActionMappings=nil
-- No player input: the game's keys stay, said.
have_pc=false
said=fresh().on()
assert(said=='the flight keys stay the game\'s (no SB player input)',said)
print('flight_test ok')
