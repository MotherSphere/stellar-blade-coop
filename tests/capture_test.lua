-- EVE's capture with fake UE4SS objects that only read (any write to EVE or her components fails): the table's text,
-- names made safe and the map lowercased, a part hung from no lower part placed from her main mesh, the generation
-- (a new mesh bumps it, a new socket keeps it, a placement that drifts never republishes), the 2 s wait, the menu pawn,
-- the native part's caps.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
os.time=function() return 1000 end -- Generations start at 1000 * 100.
local function fname(text) return {type=function() return 'FName' end,ToString=function() return text end} end
local next_address=0x1000
-- A proxy that reads through to o and refuses every write; o itself stays reachable for the test as raw[proxy].
local raw={}
local function read_only(o,what)
    local proxy=setmetatable({},{__index=o,__newindex=function(_,key) error('the capture wrote '..tostring(key)..' on '..what,2) end})
    raw[proxy]=o
    return proxy
end
local function object(name,fields)
    local o=fields or {}
    next_address=next_address+0x100
    local at=next_address
    o.type=function() return 'UObject' end
    o.IsValid=function() return true end
    o.GetFName=function() return fname(name) end
    o.GetAddress=function() return at end
    o.GetClass=function() return {GetAddress=function() return 0xc1 end,type=function() return 'UObject' end} end
    return o
end
local function mesh(path) return object(path,{GetFullName=function() return 'SkeletalMesh '..path end}) end
local function transform(x) return {Rotation={X=0,Y=0,Z=0,W=1},Translation={X=x,Y=0.1,Z=0},Scale3D={X=1,Y=1,Z=1}} end
local none={Get=function() return nil end}
-- A component of hers: names her bones b0, b1, ... unless given; place is the x of its relative translation.
local function part(name,path,o)
    local c=object(name,{SkeletalMesh=mesh(path),MasterPoseComponent=o.leader and {Get=function() return o.leader end} or none,
        bHiddenInGame=o.hidden_in_game or false})
    c.state={parent=o.parent,socket=o.socket or 'None',visible=o.visible~=false,x=o.x or 0,bones=o.bones or 0,names=o.names}
    function c:GetNumBones() return self.state.bones end
    function c:GetBoneName(b) return fname(self.state.names and self.state.names[b+1] or 'b'..b) end
    function c:GetAttachParent() return self.state.parent end
    function c:GetAttachSocketName() return fname(self.state.socket) end
    function c:IsVisible() return self.state.visible end
    function c:GetRelativeTransform() return transform(self.state.x) end
    function c:K2_GetComponentToWorld() return 'world of '..name end
    function c:K2_GetComponentRotation() return {Pitch=0,Yaw=10,Roll=0} end
    return c
end
local BODY,FACE='/Game/Art/Character/PC/CH_P_EVE_52/CH_P_EVE_52_TypeB.CH_P_EVE_52_TypeB','/Game/Art/Character/PC/Face/Face.Face'
local HAIR,BLADE='/Game/DLC_2/Art/Character/PC/EVE_HR_Nikke_02/EVE_HR_Nikke_02.EVE_HR_Nikke_02','/Game/Art/Character/Weapon/Sword/S/S.S'
local function her(name,path,o) return read_only(part(name,path,o),'her '..name) end
local capsule=object('Capsule')
local body=her('CharacterMesh0',BODY,{parent=capsule,bones=3,names={'Root','Bip 001\tPelvis',string.rep('n',70)}})
local face=her('Mesh_Face',FACE,{leader=body,parent=body})
local hair=her('SBHair',HAIR,{parent=face,socket='Bip001-Head',bones=2,x=1.5}) -- Hung from a follower, after it.
local blade=her('Weapon 7',BLADE,{parent=body,socket='SC_SwordingPoint',bones=1,x=10.25,visible=false})
local stray=her('Stray','/Game/Art/Character/PC/S/S.S',{leader=part('Elsewhere',BODY,{}),parent=body}) -- No leader of hers.
local function world_named(full) return {GetFullName=function() return full end} end
local world=world_named('World /Game/Art/BG/WorldMap/Level_P/E04.E04')
local function eve_of(name,components)
    local e=object(name,{Mesh=body})
    function e:IsA(class) return class.path=='/Script/SB.SBCharacter' end
    function e:GetWorld() return world end
    function e:K2_GetActorRotation() return {Pitch=0,Yaw=100,Roll=0} end
    function e:K2_GetComponentsByClass(class)
        assert(class.path=='/Script/Engine.SkeletalMeshComponent')
        return components or {face,stray,blade,hair,body} -- Not in rank order.
    end
    return read_only(e,'EVE')
end
local eve=eve_of('EVE')
local player=eve
package.loaded.UEHelpers={GetPlayer=function() return player end}
local relative_calls=0
StaticFindObject=function(path)
    local c=object(path,{path=path})
    if path=='/Script/Engine.Default__KismetMathLibrary' then
        c.MakeRelativeTransform=function(_,a,b)
            relative_calls=relative_calls+1
            assert(a=='world of SBHair' and b=='world of CharacterMesh0',a)
            return transform(7)
        end
    end
    return c
end

local published={}
local capture=require('capture').new(function(text) published[#published+1]=text or 'withdrawn'; return true end)
local function tick(on) return capture.tick(on~=false) end
local function step(seconds) clock=clock+seconds; return tick() end

assert(tick(false)==nil and #published==0,'Off: nothing')
-- A menu pawn (the title screen) is never captured.
local pawn=object('MenuPawn')
function pawn:IsA() return false end
player=pawn
tick(); step(3); step(1)
assert(#published==0,'Nothing from the menu pawn')
player=eve
assert(tick()==nil and #published==0,'She must be in the world 2 s first')
local ok,message=step(2)
assert(ok and message:find('^Capture 100001: 4 parts, 6 bone names, map /game/art/bg/worldmap/level_p/e04, %d+%.%d ms$'),message)
-- Her main mesh first, then leaders, then followers, each in the engine's order; the stray follower (its leader is not
-- hers) is left out. Addresses read as 0xX here.
local t=published[1]:gsub('0x%x+','0xX')
local expected='generation 100001\n'..
    'map /game/art/bg/worldmap/level_p/e04\n'..
    'part 0 - - - 1 3 CharacterMesh0 '..BODY..'\n'..
    'names 0 Root Bip_001_Pelvis '..string.rep('n',64)..'\n'..
    'read 0 0xX 0xX 0xX\n'..
    'part 1 - 0 SC_SwordingPoint 0 1 Weapon_7 '..BLADE..'\n'..
    'place 1 0 0 0 1 10.25 0.1 0 1 1 1\n'..
    'names 1 b0\n'..
    'read 1 0xX 0xX 0xX\n'..
    'part 2 - 0 - 1 2 SBHair '..HAIR..'\n'..
    'place 2 0 0 0 1 7 0.1 0 1 1 1\n'..
    'names 2 b0 b1\n'..
    'read 2 0xX 0xX 0xX\n'..
    'part 3 0 0 - 1 0 Mesh_Face '..FACE..'\n'..
    'place 3 0 0 0 1 0 0.1 0 1 1 1\n'
assert(t==expected,t)
assert(published[1]:find('\nread 0 0x%x+ 0xc1 0x%x+\n'),'Object, class and mesh addresses')
-- The hair hangs from the face, a part after it: it goes on part 0 instead, placed from her main mesh's transform.
assert(relative_calls==1)
assert(math.abs(capture.yaw_delta()-90)<1e-9,'Her actor yaw 100 minus her mesh yaw 10')

-- Once a second, and only on a change.
assert(step(0.5)==nil and #published==1,'Not before the second is up')
body.state.x=3 -- Placement alone (part 0 moves with the animation): never republished.
hair.state.x=9
blade.state.x=11 -- Hung, so its place is read: still no change.
assert(step(0.5)==nil and #published==1,'Placement drift is not a change')
blade.state.socket='SC_Back' -- The blade sheathed: the same generation, hung elsewhere.
assert(step(1)==nil and #published==2,'Republished without a log line')
assert(published[2]:find('^generation 100001\n') and published[2]:find('\npart 1 %- 0 SC_Back 0 1 ',1),published[2])
blade.state.visible=true -- Shown: the same generation again.
step(1)
assert(#published==3 and published[3]:find('^generation 100001\n') and published[3]:find('\npart 1 %- 0 SC_Back 1 1 '))
assert(step(1)==nil and #published==3,'Nothing changed: nothing published')
raw[hair].SkeletalMesh=mesh('/Game/Art/Character/PC/00_HR/EVE_HR_01/EVE_HR_01.EVE_HR_01') -- A new outfit.
ok,message=step(1)
assert(ok and message:find('^Capture 100002: ') and published[4]:find('^generation 100002\n'),tostring(message))
assert(published[4]:find(' SBHair /Game/Art/Character/PC/00_HR/EVE_HR_01/EVE_HR_01.EVE_HR_01\n',1,true))

-- Another map: lowercased and made safe; a level change brings a new EVE, withdrawn at once, captured 2 s later.
world=world_named('World /Game/DLC_2/NK_P.NK_P:PersistentLevel')
player=eve_of('EVE2')
assert(tick()==nil and published[#published]=='withdrawn','The old addresses are withdrawn at once')
step(1)
assert(published[#published]=='withdrawn','Then 2 s of waiting')
ok,message=step(1)
assert(ok and message:find('^Capture 100003: .* map /game/dlc_2/nk_p,'),message)
assert(published[#published]:find('^generation 100003\nmap /game/dlc_2/nk_p\n'))
-- Off: withdrawn; on again: a new generation (the native part may have dropped the old one).
tick(false)
assert(published[#published]=='withdrawn')
tick(); step(2)
assert(published[#published]:find('^generation 100004\n'))

-- The native part's caps: at most 16 parts, the rest left out; a leader of 1 to 1024 bones, one of 0 or more left out
-- with its followers; her main mesh outside them, no table at all.
local many={body}
for k=1,20 do many[#many+1]=her('Extra'..k,'/Game/X/X'..k..'.X'..k,{parent=body,bones=1}) end
player=eve_of('EVE3',many)
tick()
ok,message=step(2)
t=published[#published]
assert(ok and message:find('^Capture %d+: 16 parts, ') and select(2,t:gsub('\npart ',''))==16,tostring(message))
assert(t:find(' Extra15 ',1,true) and not t:find(' Extra16 ',1,true),t)
local zero=her('Zero','/Game/X/Zero.Zero',{parent=body})
local huge=her('Huge','/Game/X/Huge.Huge',{parent=body,bones=1025})
local full=her('Full','/Game/X/Full.Full',{parent=body,bones=1024})
local on_zero=her('OnZero','/Game/X/OnZero.OnZero',{leader=zero,parent=zero})
player=eve_of('EVE4',{body,zero,huge,full,on_zero})
tick()
ok,message=step(2)
t=published[#published]
assert(ok and message:find('^Capture %d+: 2 parts, 1027 bone names, '),tostring(message))
assert(t:find('\npart 1 - 0 - 1 1024 Full ',1,true) and not t:find('Zero',1,true) and not t:find('Huge',1,true),t)
body.state.bones=0
player=eve_of('EVE5',{body,blade})
tick()
local before=#published
step(2); step(1)
assert(#published==before,'Her main mesh without bones: no table')
body.state.bones=3
print('capture_test ok')
