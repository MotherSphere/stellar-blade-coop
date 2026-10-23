-- EVE's capture with fake UE4SS objects that only read (any write to EVE or her components fails, and so does any Set*
-- call): the table's text, names made safe and the map lowercased, a part hung from no lower part placed from her main
-- mesh, the generation (a new mesh bumps it, a new socket keeps it, a placement that drifts never republishes), the 2 s
-- wait, the menu pawn, the native part's caps and pose size (the last leaders left out); with dyes on, her overridden
-- materials (a dynamic one as its parent); with effects on, the Niagara layout by reflection and the listed systems in
-- memory, looked up one a tick; the game's own folders against a mod's, a mod's mesh tagged with its outfit and sending
-- its materials with dyes off, and her cloth's collision line.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
os.time=function() return 1000 end -- Generations start at 1000 * 100.
local function fname(text) return {type=function() return 'FName' end,ToString=function() return text end} end
local next_address=0x1000
-- A proxy that reads through to o and refuses every write and every Set* call; o itself stays reachable for the test as
-- raw[proxy]. reads counts each field read by name.
local raw,reads={},{}
local function read_only(o,what)
    local proxy=setmetatable({},{__index=function(_,key)
        if tostring(key):find('^Set') then error('the capture called '..key..' on '..what,2) end
        reads[key]=(reads[key] or 0)+1
        return o[key]
    end,__newindex=function(_,key) error('the capture wrote '..tostring(key)..' on '..what,2) end})
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
local fx_lookups,systems={},{} -- Niagara lookups (the class, the listed systems) in order; what each finds.
StaticFindObject=function(path)
    if path:find('Niagara',1,true) or path:find('^/Game/Art/FX/') then
        fx_lookups[#fx_lookups+1]=path
        if systems[path]~=nil or path:find('^/Game/') then return systems[path] end -- A system not in memory: nil.
    end
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
local Capture=require('partner.capture')
local capture=Capture.new(function(text) published[#published+1]=text or 'withdrawn'; return true end)
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
-- with its followers, and the last leaders while a pose would pass 16384 bytes (one of 1024 bones would: 113 bytes of
-- header, effect slots and world transform, 1 a part, 18 a bone); her main mesh outside them, no table at all.
local X='/Game/Art/Character/X/'
local many={body}
for k=1,20 do many[#many+1]=her('Extra'..k,X..'X'..k..'.X'..k,{parent=body,bones=1}) end
player=eve_of('EVE3',many)
tick()
ok,message=step(2)
t=published[#published]
assert(ok and message:find('^Capture %d+: 16 parts, ') and select(2,t:gsub('\npart ',''))==16,tostring(message))
assert(t:find(' Extra15 ',1,true) and not t:find(' Extra16 ',1,true),t)
local zero=her('Zero',X..'Zero.Zero',{parent=body})
local huge=her('Huge',X..'Huge.Huge',{parent=body,bones=1025})
local full=her('Full',X..'Full.Full',{parent=body,bones=900}) -- 903 bones with hers: 113 + 2 + 16254 bytes.
local on_zero=her('OnZero',X..'OnZero.OnZero',{leader=zero,parent=zero})
player=eve_of('EVE4',{body,zero,huge,full,on_zero})
tick()
ok,message=step(2)
t=published[#published]
assert(ok and message:find('^Capture %d+: 2 parts, 903 bone names, .* ms$'),tostring(message))
assert(t:find('\npart 1 - 0 - 1 900 Full ',1,true) and not t:find('Zero',1,true) and not t:find('Huge',1,true),t)
-- One bone more is over: the last leader goes with its follower, and the leader before it, if a pose is still over.
local tail=her('Tail',X..'Tail.Tail',{parent=body,bones=1})
local on_tail=her('OnTail',X..'OnTail.OnTail',{leader=tail,parent=tail})
local on_full=her('OnFull',X..'OnFull.OnFull',{leader=full,parent=full})
player=eve_of('EVE4b',{body,full,tail,on_full,on_tail})
tick()
ok,message=step(2)
t=published[#published]
assert(ok and message:find('^Capture %d+: 3 parts, 903 bone names, .*; 1 leaders left out, over the pose size$'),
    tostring(message))
assert(t:find('\npart 2 1 1 - 1 0 OnFull ',1,true) and not t:find('Tail',1,true),t)
full.state.bones=1024
player=eve_of('EVE4c',{body,tail,full,on_tail})
tick()
ok,message=step(2)
t=published[#published]
assert(ok and message:find('^Capture %d+: 3 parts, 4 bone names, .*; 1 leaders left out, over the pose size$'),
    tostring(message))
assert(t:find(' Tail ',1,true) and t:find(' OnTail ',1,true) and not t:find('Full',1,true),t)
body.state.bones=904 -- Her main mesh alone is over: no table.
player=eve_of('EVE4d',{body,tail})
tick()
local count_before=#published
step(2); step(1)
assert(#published==count_before,'Her main mesh over the pose size: no table')
body.state.bones=3
body.state.bones=0
player=eve_of('EVE5',{body,blade})
tick()
local before=#published
step(2); step(1)
assert(#published==before,'Her main mesh without bones: no table')
body.state.bones=3

-- Dyes off (every capture above): her overridden materials are never read, so no material lines and the key as before.
assert(not reads.OverrideMaterials and not published[#published]:find('\nmaterial '),'Dyes off: not read')
-- Dyes on: each part's overridden slots after its place, before its names; a null or invalid entry skipped; a dynamic
-- instance sent as its parent; and only a change of what they are made from is a new generation.
local MID='/Script/Engine.MaterialInstanceDynamic'
local function material(path) -- A material asset: its full name; read-only.
    return read_only(object(path,{GetFullName=function() return 'MaterialInstanceConstant '..path end,
        IsA=function() return false end}),path)
end
local function dynamic(parent) -- Made at run time from parent: never loadable by a peer.
    return read_only(object('MID',{Parent=parent,IsA=function(_,class) return class.path==MID end,
        GetFullName=function() return 'MaterialInstanceDynamic /Engine/Transient.MID' end}),'a MID')
end
local function slots(n,entries) -- A TArray of n slots, nil where entries has none, as UE4SS hands it over.
    return {ForEach=function(_,f) for k=1,n do f(k,{get=function() return entries[k] end}) end end}
end
local SKIN='/Game/Art/Character/PC/CH_P_EVE_52/MI_EVE_52_Skin.MI_EVE_52_Skin'
local TYPE_B='/Game/Art/Character/PC/00_HR/EVE_HR_01/MI_EVE_HR_01_TypeB.MI_EVE_HR_01_TypeB'
local TYPE_C='/Game/Art/Character/PC/00_HR/EVE_HR_01/MI_EVE_HR_01_TypeC.MI_EVE_HR_01_TypeC'
local skin,type_b=material(SKIN),material(TYPE_B)
local gone=object('Gone')
gone.IsValid=function() return false end
raw[body].OverrideMaterials=slots(3,{[2]=dynamic(skin),[3]=gone})
raw[hair].OverrideMaterials=slots(1,{type_b})
local looks={dyes=true}
published={}
capture=Capture.new(function(text) published[#published+1]=text or 'withdrawn'; return true end,looks)
player=eve_of('EVE6',{body,hair})
tick()
ok,message=step(2)
assert(ok and message:find('^Capture 100001: 2 parts, .* ms; dyes: 2 slots %(1 dynamic%)$'),tostring(message))
t=published[1]
assert(t:find(' CharacterMesh0 '..BODY..'\nmaterial 0 1 '..SKIN..'\nnames 0 ',1,true),t)
assert(t:find('\nplace 1 [^\n]*\nmaterial 1 0 '..TYPE_B..'\nnames 1 '),t)
assert(select(2,t:gsub('\nmaterial ',''))==2,'Slot 0 empty, slot 2 invalid: skipped')
-- A new dynamic instance from the same asset (SB makes them again): the same key, nothing published.
raw[body].OverrideMaterials=slots(2,{nil,dynamic(skin)})
assert(step(1)==nil and #published==1,'The same parent: no new generation')
-- Another hair colour: a new generation.
raw[hair].OverrideMaterials=slots(1,{dynamic(dynamic(material(TYPE_C)))})
ok,message=step(1)
assert(ok and message:find('^Capture 100002: .*; dyes: 2 slots %(2 dynamic%)$') and #published==2,tostring(message))
assert(published[2]:find('\nmaterial 1 0 '..TYPE_C..'\n',1,true),published[2])
-- At most 16 slots, and none at 64 or above (the native part refuses the whole table past either).
raw[hair].OverrideMaterials=slots(70,setmetatable({},{__index=function() return type_b end}))
step(1)
t=published[#published]
assert(select(2,t:gsub('\nmaterial 1 ',''))==16 and t:find('\nmaterial 1 15 ',1,true),t)
raw[hair].OverrideMaterials=slots(70,setmetatable({},{__index=function(_,k) return k>=62 and type_b or nil end}))
step(1)
t=published[#published]
assert(select(2,t:gsub('\nmaterial 1 ',''))==3 and t:find('\nmaterial 1 61 ') and t:find('\nmaterial 1 63 '),t)
-- Materials that cannot be read: that part sends none, the capture goes on, and why is said once, a look later.
raw[hair].OverrideMaterials={ForEach=function() error('no such array') end}
ok,message=step(1)
t=published[#published]
assert(ok and message:find('^Capture %d+: ') and not t:find('\nmaterial 1 ') and t:find('\nmaterial 0 1 '),t)
ok,message=step(1)
assert(ok==false and message:find('^Capture: materials not read: .*no such array$'),tostring(message))
assert(step(1)==nil,'Said once')
-- Dyes off again (coop look dyes off): a new generation with no material lines, and the line without its tail.
looks.dyes=false
ok,message=step(1)
assert(ok and message:find(' ms$') and not published[#published]:find('\nmaterial '),tostring(message))

-- Effects off (every capture above): nothing of Niagara looked up, no effect line.
assert(#fx_lookups==0 and not published[#published]:find('\neffect'),'Effects off: nothing looked up or sent')
-- The list the wire's indexes name: the 19 Niagara systems, no Cascade trail.
local E=require('partner.capture').EFFECTS
assert(#E==19 and E[1]=='/Game/Art/FX/Char/PC/Skill/Attack/NS_A_ParTrail_SwordDefaultAtk_01.NS_A_ParTrail_SwordDefaultAtk_01'
    and E[19]=='/Game/Art/FX/Char/PC/Skill/Parry/NS_JustParry_02.NS_JustParry_02',E[1])
for _,path in ipairs(E) do assert(not path:find('AnimTrail',1,true),path) end
-- Effects on: the NiagaraComponent class and its Asset field's offset, found up its supers; then each listed system
-- looked up, one a tick, and only then the capture, with the effect lines after the last part.
local function property(name,offset)
    return {GetFName=function() return fname(name) end,GetOffset_Internal=function() return offset end}
end
local asset_offset=0x5d8
local super=object('FXSystemComponent',{GetSuperStruct=function() return nil end})
super.ForEachProperty=function(_,f) f(property('Asset',asset_offset)) end
local niagara=object('NiagaraComponent',{ForEachProperty=function(_,f) f(property('bAutoActivate',0x120)) end,
    GetSuperStruct=function() return super end})
systems['/Script/Niagara.NiagaraComponent']=niagara
local function system(path) return object(path,{GetFullName=function() return 'NiagaraSystem '..path end}) end
for _,k in ipairs({1,5,19}) do systems[E[k]]=system(E[k]) end -- In memory; the other 16 are not.
local function looked_up() -- The systems looked up since the last call.
    local list={}
    for _,path in ipairs(fx_lookups) do if path:find('^/Game/') then list[#list+1]=path end end
    fx_lookups={}
    return list
end
local function fx_step() -- A 250 ms tick: one system looked up at most.
    local ok_of,message_of=step(0.25)
    assert(#looked_up()<=1,'One system a tick at most')
    return ok_of,message_of
end
looks={effects=true}
published={}
capture=Capture.new(function(text) published[#published+1]=text or 'withdrawn'; return true end,looks)
player=eve_of('EVE7',{body,hair})
assert(tick()==nil and fx_lookups[1]=='/Script/Niagara.NiagaraComponent' and fx_lookups[2]==E[1] and #fx_lookups==2,
    'The layout, then the first system')
looked_up()
for _=1,17 do assert(fx_step()==nil and #published==0,'Nothing published before all 19 are looked up') end
ok,message=fx_step()
assert(ok and message:find('^Capture 100001: 2 parts, .* ms; effects: 3 of 19 found$') and #published==1,tostring(message))
t=published[1]
local lines=string.format('effects 0x%x 0x5d8\neffect 1 0x%x\neffect 5 0x%x\neffect 19 0x%x\n',niagara.GetAddress(),
    systems[E[1]].GetAddress(),systems[E[5]].GetAddress(),systems[E[19]].GetAddress())
assert(t:sub(-#lines)==lines and t:find('\nread 1 0x%x+ 0x%x+ 0x%x+\neffects '),t)
assert(step(1)==nil and #published==1 and #looked_up()==0,'Looked up once: no new scan, nothing new')
-- Off: a new generation without them; on again: a new scan (only what was not found), then a new generation with them.
looks.effects=false
ok,message=step(1)
assert(ok and message:find('^Capture 100002: .* ms$') and not published[2]:find('\neffect'),tostring(message))
looks.effects=true
local scanned={}
for _=1,16 do
    assert(step(0.25)==nil and #published==2,'The old one stays until the scan ends')
    for _,path in ipairs(looked_up()) do scanned[#scanned+1]=path end
end
ok,message=step(0.25)
assert(ok and message:find('^Capture 100003: .*; effects: 3 of 19 found$') and #published==3,tostring(message))
assert(#scanned==16 and published[3]:sub(-#lines)==lines,'Each system found and still itself is not looked up again')
-- A new EVE: a new scan, where a system collected since, or another object at its address, is looked up again.
systems[E[5]].IsValid=function() return false end
systems[E[19]].GetFullName=function() return 'Texture2D /Game/Other.Other' end
systems[E[5]],systems[E[19]]=system(E[5]),nil
player=eve_of('EVE8',{body,hair})
scanned={}
for _=1,20 do
    ok,message=step(0.25)
    for _,path in ipairs(looked_up()) do scanned[#scanned+1]=path end
    if message then break end
end
assert(ok and message:find('^Capture 100004: .*; effects: 2 of 19 found$'),tostring(message))
assert(#scanned==18 and not table.concat(scanned,' '):find(E[1],1,true),'The first, still itself, is kept')
assert(published[#published]:find('\neffect 5 '..string.format('0x%x',systems[E[5]].GetAddress())..'\n$'),'The new one')
-- The layout not found, or out of the native part's bounds: said once, and the capture goes on without effects.
super.ForEachProperty=function() end
published={}
capture=Capture.new(function(text) published[#published+1]=text or 'withdrawn'; return true end,looks)
ok,message=tick()
assert(ok==false and message=='Effects not captured: NiagaraComponent has no Asset property',tostring(message))
ok,message=step(2)
assert(ok and message:find(' ms$') and #published==1 and not published[1]:find('\neffect'),tostring(message))
assert(step(1)==nil and #looked_up()==0,'Said once, and nothing looked up')
super.ForEachProperty=function(_,f) f(property('Asset',0x1008)) end
capture=Capture.new(function() return true end,looks)
ok,message=tick()
assert(ok==false and message:find('^Effects not captured: the Asset offset 0x1008 is outside '),tostring(message))

-- The game's own folders (table.h's first family) against a mod's: only the first are sent untagged.
local B=Capture.base_path
for _,good in ipairs({BODY,HAIR,FACE,'/Game/DLC_12/Art/Character/PC/X/X.X','/Game/Art/Character/A/B/C/D.D'}) do
    assert(B(good),good)
end
for _,bad in ipairs({'/Game/Art/Character/X.X','/Game/Art/Character/PC/X-1/X.X','/Game/DLC_123/Art/Character/P/X.X',
    '/Game/Art/Character//PC/X.X','/Game/Art/Character/PC/X/X.Y','/Game/Art/Character/PC/X/X','/Game/OutfitMods/F/F.F',
    '/Game/Art/CharacterX/PC/X.X','/game/art/character/pc/x/x.x','/Game/Art/Character/PC/'..('x'):rep(240)..'/X.X',
    '/Game/Art/Character/PC/X/X.X:Sub',42}) do
    assert(not B(bad),tostring(bad))
end
-- A mod's tag: the UniqueFitID our CNS packs give its path, else its first two folders (or its one); none for the
-- game's own or a path outside /Game.
local SUIT,ATOOL='/Game/OutfitMods/FooSuit/Meshes/SK_Foo.SK_Foo','/Game/Mods/HD-ATOOL_P/data/cha/Eve/hair/P_2.P_2'
local cns={[SUIT]='Foo_Suit',['/Game/Mods/X/T.T']='-'}
assert(Capture.label(SUIT,cns)=='Foo_Suit' and Capture.label(SUIT,{})=='OutfitMods/FooSuit' and Capture.label(SUIT)==
    'OutfitMods/FooSuit')
assert(Capture.label(ATOOL,cns)=='Mods/HD-ATOOL_P' and Capture.label('/Game/Mods/X/T.T',cns)=='Mods/X')
assert(Capture.label('/Game/One/A.A')=='One' and Capture.label(BODY,cns)==nil and Capture.label('/Engine/X/X.X')==nil)
assert(Capture.label('/Game/'..('m'):rep(70)..'/n/A.A')==('m'):rep(64),'A word: 64 bytes at most')

-- Parts on mods' meshes, dyes off: tagged after their materials (sent all the same: CNS puts an outfit's materials on
-- at run time) and cloth; the game's own parts send none. Her ponytail's cloth collision goes on its own line, on any
-- part, and another asset there is a new generation.
local suit=her('Suit',SUIT,{parent=body,bones=2})
local tail_part=her('SBPonytail',ATOOL,{leader=suit,parent=suit})
local MOD_MAT='/Game/OutfitMods/FooSuit/MI_Foo.MI_Foo'
raw[suit].OverrideMaterials=slots(2,{nil,material(MOD_MAT)})
raw[body].OverrideMaterials=slots(1,{skin})
local PA='/Game/OutfitMods/FooSuit/PA_Tail.PA_Tail'
local function physics(path) return object(path,{GetFullName=function() return 'PhysicsAsset '..path end}) end
raw[tail_part].OverrideClothPhysicsAsset=physics(PA)
published={}
capture=Capture.new(function(text) published[#published+1]=text or 'withdrawn'; return true end,{},
    function() return cns end)
player=eve_of('EVE9',{body,suit,tail_part})
tick()
ok,message=step(2)
assert(ok and message:find('^Capture 100001: 3 parts, 5 bone names, .* ms$'),tostring(message))
t=published[1]
local function plain(p) return (p:gsub('%p','%%%0')) end
assert(t:find(' Suit '..SUIT..'\nplace 1 [^\n]*\nmaterial 1 1 '..plain(MOD_MAT)..'\nmod 1 Foo_Suit\nnames 1 '),t)
assert(t:find(' SBPonytail '..plain(ATOOL)..'\nplace 2 [^\n]*\ncloth 2 '..plain(PA)..'\nmod 2 Mods/HD%-ATOOL_P\n$'),t)
assert(not t:find('\nmaterial 0 ') and not t:find('\nmod 0 '),'The game\'s own part: no materials, no tag')
assert(step(1)==nil,'Nothing changed')
raw[tail_part].OverrideClothPhysicsAsset=physics('/Game/OutfitMods/FooSuit/PA_Other.PA_Other')
ok,message=step(1)
assert(ok and message:find('^Capture 100002: ') and published[2]:find('\ncloth 2 /Game/OutfitMods/FooSuit/PA_Other%.'),
    tostring(message))
-- A cloth asset with a path of 256 bytes would refuse the whole table: left out.
raw[tail_part].OverrideClothPhysicsAsset=physics('/Game/'..('p'):rep(246)..'/P.P')
step(1)
assert(not published[3]:find('\ncloth '),published[3])
-- mod_names=off: no path outside the game's own folders goes, nor a tag. Her suit and its ponytail go as '-' (the
-- friend draws fallbacks), its material and cloth asset are left out; the game's own parts go as before.
raw[tail_part].OverrideClothPhysicsAsset=physics(PA)
raw[body].OverrideMaterials=slots(1,{skin})
published={}
capture=Capture.new(function(text) published[#published+1]=text or 'withdrawn'; return true end,{dyes=true},
    function() return cns end,true)
player=eve_of('EVE10',{body,suit,tail_part})
tick()
ok,message=step(2)
t=published[1]
assert(ok and t:find(' CharacterMesh0 '..plain(BODY)..'\nmaterial 0 0 '..plain(SKIN)..'\nnames 0 '),t)
assert(t:find('\npart 1 %- 0 %- 1 2 Suit %-\nplace 1 [^\n]*\nnames 1 ') and t:find('\npart 2 1 1 %- 1 0 SBPonytail %-\n'),t)
assert(not t:find('OutfitMods',1,true) and not t:find('ATOOL',1,true) and not t:find('\nmod ') and not t:find('\ncloth '),
    t)
print('capture_test ok')
