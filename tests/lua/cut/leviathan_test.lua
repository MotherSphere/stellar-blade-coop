-- cut/leviathan.lua with fake UE4SS objects: list only reads (a line per asset: missing, or its class with a mesh's
-- or clip's skeleton and a class's super class, a class found once its Blueprint's package loads; the CharacterTable
-- rows that name it, by row name or name field, with their ID and MeshScale; a table it cannot read said so) and
-- spawns nothing; show spawns one plain /Script/Engine.Actor 6 m ahead of EVE, facing her, with collision off and one
-- mesh component (a static one for the statue), writes coop-leviathan.txt and plays each clip of the mesh's skeleton
-- twice in turn, a log line a step, a clip the engine collected found again without counting as a Doro reload; a
-- second show replaces the first; play holds one clip (by suffix, else anywhere in its name, any case) and play alone
-- resumes the cycle; off, coop off, a map change, no EVE and its first error remove it and clear the file (kept when
-- the removal fails, and swept by the next show, which shows nothing new while that fails), with no call on an object
-- that took its actor's place; a pawn that is no SBCharacter, or a mesh of another class (also after list), shows
-- nothing; the next Lua load sweeps what the file names, once; no SpawnActor call ever takes another class than
-- /Script/Engine.Actor.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
local function fname(t) return {type=function() return 'FName' end,ToString=function() return t end} end
FName=fname
local next_address=0x1000
local function object(fields)
    next_address=next_address+0x100
    local at=next_address
    local o=fields or {}
    o.type=function() return 'UObject' end
    o.IsValid=o.IsValid or function(self) return not self.destroyed end
    o.GetAddress=function() return at end
    return o
end
local invalid=object({destroyed=true})
local function class(path) return object({path=path,MakeTransform=function() return 'identity' end}) end
local assets,loads,by_path={},{},{}
local packages={} -- A class that shows only once LoadAsset loaded its Blueprint's package: package path -> class.
local player
package.loaded.UEHelpers={GetPlayer=function() return player end}
StaticFindObject=function(path)
    if by_path[path] then return by_path[path] end
    if path:find('^/Script/') then return class(path) end
    return assets[path] or invalid
end
LoadAsset=function(path)
    loads[#loads+1]=path
    local c=packages[path]
    if c then assets[c.at_path]=c end
    return invalid
end
local L=require('cut.leviathan')
local function path(name)
    for _,e in ipairs(L.LIST) do if e.path:match('[^.]+$')==name then return e.path end end
    error(name)
end
-- An asset at its LIST path: kinds are the class paths it IsA (the first one names its class), fields its properties.
local made=0
local function asset(name,kinds,fields)
    local p=path(name)
    local o=object(fields or {})
    o.key=name
    o.GetFullName=function() return kinds[1]:match('[^.]+$')..' '..p end
    o.IsA=function(_,c)
        if c.path=='/Script/CoreUObject.Object' then return true end
        for _,k in ipairs(kinds) do if k==c.path then return true end end
        return false
    end
    assets[p]=o
    made=made+1
    return o
end
local SEQ,BS={'/Script/Engine.AnimSequence','/Script/Engine.AnimationAsset'},
    {'/Script/Engine.BlendSpace','/Script/Engine.AnimationAsset'}
local function skeleton(name) return asset(name,{'/Script/Engine.Skeleton'}) end
local body_sk,a_sk,tentacle_sk=skeleton('CH_M_NA_10_Skeleton'),skeleton('Leviathan_A_Skeleton'),
    skeleton('M_LeviathanTentacleA_Skeleton')
local eve_sk=object({GetFullName=function() return 'Skeleton /Game/Art/Character/PC/EVE_Skeleton.EVE_Skeleton' end})
local MESH,STATIC={'/Script/Engine.SkeletalMesh'},{'/Script/Engine.StaticMesh'}
asset('CH_M_NA_10',MESH,{Skeleton=body_sk})
asset('Leviathan_A',MESH,{Skeleton=a_sk}) -- Leviathan_B is missing.
asset('M_LeviathanTentacleA',MESH,{Skeleton=tentacle_sk})
asset('C_Reviathan',STATIC)
asset('M_Leviathan_BattleIdle01',SEQ,{Skeleton=body_sk,SequenceLength=2.0})
asset('M_Leviathan_Catch_1',SEQ,{Skeleton=a_sk,SequenceLength=1.0})
asset('M_Leviathan_LightningBall1_1',SEQ,{Skeleton=body_sk,SequenceLength=1.5})
asset('M_LeviathanTentacleA_BashLeft',SEQ,{Skeleton=tentacle_sk,SequenceLength=1.0})
asset('M_LeviathanTentacleA_BashLeft_1',SEQ,{Skeleton=tentacle_sk,SequenceLength=1.2})
asset('IdleRun_BS_Battle',BS,{Skeleton=body_sk}) -- No length: 3 s.
asset('TentacleA_IdleRun_BS_Peaceful',BS,{Skeleton=tentacle_sk})
asset('CH_M_NA_10_Anim',{'/Script/Engine.PoseWatch'},{Skeleton=body_sk}) -- Its skeleton, but no clip.
asset('Hit_Leviathan_GrabSuccess',SEQ,{Skeleton=eve_sk,SequenceLength=2.5})
local function super(name) return function() return object({GetFName=function() return fname(name) end}) end end
asset('CH_M_NA_10_Blueprint_C',{'/Script/Engine.BlueprintGeneratedClass'},{GetSuperStruct=super('SBMonster')})
do -- The AnimBP's class shows once its package is loaded.
    local p=path('CH_M_NA_10_AnimBP_C')
    local c=asset('CH_M_NA_10_AnimBP_C',{'/Script/Engine.AnimBlueprintGeneratedClass'},
        {GetSuperStruct=super('SBAnimInstance'),at_path=p})
    assets[p]=nil
    packages[p:sub(1,-3)]=c
end
asset('M_Leviathan_Despawn',{'/Script/LevelSequence.LevelSequence'})
-- The CharacterTable: row names as strings or FNames, fields as numbers, FNames or strings.
local ROWS={{'M_Hydra',{ID=50090,Type=fname('M_Hydra'),DespawnShow='Despawn/M_Hydra_Despawn',MeshScale=1.5}},
    {fname('M_Leviathan'),{ID=50100,Type=fname('M_Leviathan'),MeshScale=2}},
    {'Test_Boss',{ID=99,DespawnShow='Despawn/M_Leviathan_Despawn'}},{'CH_M_NA_10_Test',{ID=7}}}
local TABLE='/Game/Local/Data/CharacterTable.CharacterTable'
local character_table=object({GetFullName=function() return 'DataTable '..TABLE end,
    IsA=function(_,c) return c.path=='/Script/Engine.DataTable' end,
    ForEachRow=function(_,f) for _,r in ipairs(ROWS) do f(r[1],r[2]) end end})
assets[TABLE]=character_table
-- A display's component: its calls in order, as words. broken: PlayAnimation raises it.
local broken
local function component(actor,kind)
    local c=object({calls={},actor=actor,kind=kind})
    local function said(...)
        local words={...}
        for k,w in ipairs(words) do if math.type(w)=='float' then words[k]=string.format('%g',w) end end
        c.calls[#c.calls+1]=table.concat(words,' ')
    end
    function c:SetSkeletalMesh(m) self.SkeletalMesh=m; said('mesh',m.key) end
    function c:SetStaticMesh(m) self.StaticMesh=m; said('static',m.key) end
    function c:SetRelativeScale3D(v) said('scale',v.X) end
    function c:SetCollisionEnabled(n) said('collision',n) end
    function c:SetAnimationMode(n) said('mode',n) end
    function c:K2_SetWorldLocationAndRotation(at,r) self.at,self.rot=at,r end
    function c:PlayAnimation(a,loop) if broken then error(broken,0) end said('play',a.key,tostring(loop)) end
    function c:SetPlayRate(r) said('rate',r) end
    function c:SetPosition(at,notifies) assert(notifies==false,'Never notifies'); said('at',at) end
    function c:K2_DestroyComponent() self.destroyed=true end
    function c:IsA(k) return k.path==self.kind end
    return c
end
local spawned,spawn_classes={},{}
local map='/Game/Art/BG/WorldMap/Level_P/E04'
local world=object({GetFullName=function() return 'World '..map..'.'..map:match('[^/]+$') end})
function world:SpawnActor(c,at,rot)
    spawn_classes[#spawn_classes+1]=c.path
    local a=object({components={},destroys=0})
    function a:SetActorEnableCollision(on) self.collision=on end
    function a:AddComponentByClass(k,manual,transform,deferred)
        assert((k.path=='/Script/Engine.SkeletalMeshComponent' or k.path=='/Script/Engine.StaticMeshComponent')
            and manual==false and transform=='identity' and deferred==false)
        local added=component(self,k.path)
        self.components[#self.components+1]=added
        return added
    end
    function a:K2_GetRootComponent() return self.components[1] end
    function a:K2_DestroyActor() self.destroyed,self.destroys=true,self.destroys+1 end
    local n=#spawned+1
    function a:GetFullName() return 'Actor /Game/Map.Map:PersistentLevel.Actor_'..n end
    a.spawned_at,a.spawned_rot=at,rot
    spawned[n]=a
    return a
end
-- EVE: her main mesh at her feet, turned as her actor minus 90 degrees, her actor facing +Y.
local eve=object({Mesh=object({K2_GetComponentLocation=function() return {X=10,Y=20,Z=-87} end,
    K2_GetComponentRotation=function() return {Pitch=0,Yaw=0,Roll=0} end})})
function eve:IsA(k) return k.path=='/Script/SB.SBCharacter' end
function eve:GetWorld() return world end
function eve:K2_GetActorRotation() return {Pitch=0,Yaw=90,Roll=0} end
player=eve
local stored -- coop-leviathan.txt's line.
local store={save=function(line) stored=line; return true end,load=function() return stored end,
    clear=function() stored=nil end}
local logs={}
local function log(m) logs[#logs+1]=m end
local function last() return logs[#logs] end
local function close(a,b) return math.abs(a-b)<1e-6 end
local lv=L.new({log=log,store=store})
local USE='Use: coop leviathan [list] | show [body|a|b|tentacle|statue] | play [<clip>] | off'

-- list: a line per asset of LIST, then the rows that name it and the count. Nothing spawned.
local ok,why=lv.command()
assert(ok and why==string.format('Leviathan list: %d of %d assets found, 3 CharacterTable rows name it; [LV] lines '
    ..'in this log.',made,#L.LIST),why)
assert(#spawned==0,'list spawns nothing')
local function logged(line) for _,l in ipairs(logs) do if l==line then return true end end return false end
for _,line in ipairs({'list mesh CH_M_NA_10: SkeletalMesh skeleton=CH_M_NA_10_Skeleton',
        'list mesh Leviathan_B: missing','list mesh C_Reviathan: StaticMesh skeleton=-',
        'list skeleton CH_M_NA_10_Skeleton: Skeleton','list skeleton Leviathan_B_Skeleton: missing',
        'list clip M_Leviathan_LightningBall1_1: AnimSequence skeleton=CH_M_NA_10_Skeleton',
        'list clip IdleRun_BS_Battle: BlendSpace skeleton=CH_M_NA_10_Skeleton',
        'list clip Hit_Leviathan_GrabSuccess: AnimSequence skeleton=EVE_Skeleton',
        'list clip M_Leviathan_SmashLeft1_1: missing',
        'list class CH_M_NA_10_Blueprint_C: BlueprintGeneratedClass super=SBMonster',
        'list class CH_M_NA_10_AnimBP_C: AnimBlueprintGeneratedClass super=SBAnimInstance',
        'list class ME_Area04_SecretRoom_Leviathan_C: missing','list asset M_Leviathan_Despawn: LevelSequence',
        'list asset Default: missing'}) do
    assert(logged(line),line)
end
local function loaded(p) for _,l in ipairs(loads) do if l==p then return true end end return false end
assert(loaded(path('CH_M_NA_10_AnimBP_C'):sub(1,-3)),'Its Blueprint\'s package loaded')
assert(not loaded(path('CH_M_NA_10_Blueprint_C'):sub(1,-3)),'A class in memory: no package load')
local n=0
for _,l in ipairs(logs) do
    if l:find('^list ') and not l:find('^list row ') and not l:find('^list Char') then n=n+1 end
end
assert(n==#L.LIST,n)
assert(logged('list row M_Leviathan Type=M_Leviathan Flag=? DeadAlias=? DespawnShow=? DefaultStanceAlias=? '
    ..'BehaviorTreeRes=? DefaultDetectAIAlias=? NarrowDetectAIAlias=? RefAppearance=? ID=50100 MeshScale=2'))
assert(logged('list row Test_Boss Type=? Flag=? DeadAlias=? DespawnShow=Despawn/M_Leviathan_Despawn '
    ..'DefaultStanceAlias=? BehaviorTreeRes=? DefaultDetectAIAlias=? NarrowDetectAIAlias=? RefAppearance=? ID=99 '
    ..'MeshScale=?'))
assert(logged('list row CH_M_NA_10_Test Type=? Flag=? DeadAlias=? DespawnShow=? DefaultStanceAlias=? '
    ..'BehaviorTreeRes=? DefaultDetectAIAlias=? NarrowDetectAIAlias=? RefAppearance=? ID=7 MeshScale=?'))
assert(last()=='list CharacterTable rows=4 named=3' and not logged('list row M_Hydra'),last())
-- coop leviathan list says the same; a table it cannot read is said so.
assert(select(2,lv.command('list'))==why)
assets[TABLE],character_table.destroyed=nil,true -- Collected, and none to load.
local _,again=lv.command('list')
assert(last()=='list CharacterTable not read: not found' and again:find('CharacterTable not read; ',1,true),again)
assets[TABLE],character_table.destroyed=character_table,nil
-- Anything else: its usage line.
for _,bad in ipairs({{'list','x'},{'show','huge'},{'show','body','x'},{'off','x'},{'play','a','b'},{'on'}}) do
    local done,said=lv.command(table.unpack(bad))
    assert(not done and said==USE,said)
end
assert(#spawned==0)

-- show: one plain Actor 6 m ahead of EVE, facing her, collision off, the body's mesh at scale 1 in the single-node
-- mode; the file names it; then each clip of its skeleton twice in turn (the blend space for 3 s), logged.
logs={}
clock=100
ok,why=lv.command('show')
assert(ok and why=='Leviathan body shown 6 m ahead, 3 clips in turn; [LV] lines in this log.',why)
assert(last()=='show body: CH_M_NA_10, 3 clips on skeleton CH_M_NA_10_Skeleton',last())
local a=spawned[1]
local m=a.components[1]
assert(#spawned==1 and #a.components==1 and a.collision==false)
assert(close(a.spawned_at.X,10) and close(a.spawned_at.Y,620) and a.spawned_at.Z==-87,'600 cm ahead of her')
assert(a.spawned_rot.Yaw==180 and close(m.at.Y,620) and m.rot.Yaw==180,'Facing her')
assert(m.kind=='/Script/Engine.SkeletalMeshComponent'
    and table.concat(m.calls,'|')=='mesh CH_M_NA_10|scale 1|collision 0|mode 1',table.concat(m.calls,'|'))
assert(stored=='/Game/Map.Map:PersistentLevel.Actor_1\t'..path('CH_M_NA_10'),stored)
m.calls={}
local function tick_at(t) clock=t; return lv.tick() end
local function newest() local k=#spawned; return spawned[k],'/Game/Map.Map:PersistentLevel.Actor_'..k end
assert(tick_at(100)==nil and last()=='show body step 1/3 M_Leviathan_BattleIdle01 2.00 s twice',last())
assert(tick_at(103.9)==nil and #m.calls==3,'4 s: the clip twice')
-- A clip collected meanwhile is found again, and not counted as a reload of the Doro look's minute line.
local Doro=require('race.doro')
local ball=assets[path('M_Leviathan_LightningBall1_1')]
ball.destroyed=true
assets[path('M_Leviathan_LightningBall1_1')]=object({key=ball.key,GetFullName=ball.GetFullName,IsA=ball.IsA,
    Skeleton=body_sk,SequenceLength=1.5})
Doro.reloads.n=0
tick_at(104); assert(last()=='show body step 2/3 M_Leviathan_LightningBall1_1 1.50 s twice',last())
assert(Doro.reloads.n==0,Doro.reloads.n)
tick_at(107); assert(last()=='show body step 3/3 IdleRun_BS_Battle 3.00 s twice',last())
tick_at(112.9); tick_at(113); assert(last()=='show body step 1/3 M_Leviathan_BattleIdle01 2.00 s twice',last())
assert(table.concat(m.calls,'|')=='play M_Leviathan_BattleIdle01 true|rate 1|at 0|'
    ..'play M_Leviathan_LightningBall1_1 true|rate 1|at 0|play IdleRun_BS_Battle true|rate 1|at 0|'
    ..'play M_Leviathan_BattleIdle01 true|rate 1|at 0',table.concat(m.calls,'|'))
-- play: a clip held looping, named by its end, else by any part, in any case; play alone: the cycle goes on.
m.calls={}
ok,why=lv.command('play','LIGHTNINGBALL')
assert(ok and why=='Leviathan body holds M_Leviathan_LightningBall1_1 looping; coop leviathan play goes back to the '
    ..'cycle.',why)
tick_at(114); assert(last()=='play M_Leviathan_LightningBall1_1 looping',last())
tick_at(500); tick_at(900)
assert(table.concat(m.calls,'|')=='play M_Leviathan_LightningBall1_1 true|rate 1|at 0',table.concat(m.calls,'|'))
assert(select(2,lv.command('play','battle')):find(' holds IdleRun_BS_Battle looping;',1,true),'Its end first')
ok,why=lv.command('play','catch')
assert(not ok and why=='no clip of the shown body ends with or holds catch','Another skeleton\'s clip: not this one')
ok,why=lv.command('play')
assert(ok and why=='Leviathan body back to its cycle.')
tick_at(901); assert(last()=='show body step 2/3 M_Leviathan_LightningBall1_1 1.50 s twice',last())
-- A second show replaces the first: the tentacle, its own clips; bashleft is the clip that ends so.
logs={}
ok,why=lv.command('show','tentacle')
assert(ok and logs[1]=='removed (replaced)' and a.destroyed and #spawned==2,logs[1])
assert(last()=='show tentacle: M_LeviathanTentacleA, 3 clips on skeleton M_LeviathanTentacleA_Skeleton',last())
assert(stored=='/Game/Map.Map:PersistentLevel.Actor_2\t'..path('M_LeviathanTentacleA'),stored)
assert(select(2,lv.command('play','bashleft')):find(' holds M_LeviathanTentacleA_BashLeft looping;',1,true))
assert(select(2,lv.command('play','BashLeft_1')):find(' holds M_LeviathanTentacleA_BashLeft_1 looping;',1,true))
tick_at(902); assert(last()=='play M_LeviathanTentacleA_BashLeft_1 looping',last())
-- off: gone, the file cleared; then nothing to remove.
ok,why=lv.command('off')
assert(ok and why=='Leviathan removed.' and spawned[2].destroyed and stored==nil
    and last()=='removed (coop leviathan off)')
assert(tick_at(903)==nil and select(2,lv.command('off'))=='No Leviathan is shown.')
assert(select(2,lv.command('play'))=='no Leviathan is shown: coop leviathan show first')
-- The statue: a StaticMeshComponent, no animation mode, no clip.
ok,why=lv.command('show','statue')
local s=spawned[3].components[1]
assert(ok and s.kind=='/Script/Engine.StaticMeshComponent'
    and table.concat(s.calls,'|')=='static C_Reviathan|scale 1|collision 0',table.concat(s.calls,'|'))
assert(last()=='show statue: C_Reviathan, 0 clips on skeleton -',last())
assert(tick_at(904)==nil and tick_at(999)==nil and #s.calls==3,'Nothing to play')
assert(not lv.command('play','idle'))
-- A missing mesh: its actor destroyed at once, the earlier display gone too.
ok,why=pcall(lv.command,'show','b')
assert(not ok and why:find('Leviathan_B is missing on this PC',1,true) and spawned[4].destroyed,why)
assert(spawned[3].destroyed and stored==nil and lv.tick()==nil)
-- No EVE, or a pawn that is no SBCharacter: nothing spawned.
player=nil
assert(select(2,lv.command('show'))=='no EVE in the world' and #spawned==4)
player=object({IsA=function() return false end})
assert(select(2,lv.command('show'))=='no EVE in the world' and #spawned==4)
player=eve

-- coop off removes it.
lv.command('show')
lv.stop()
assert(spawned[5].destroyed and stored==nil and last()=='removed (coop off)' and lv.tick()==nil)
lv.stop()
-- A map change (EVE on another map, or none) removes it.
lv.command('show')
tick_at(1000)
map='/Game/Art/BG/WorldMap/Level_P/B07'
ok,why=tick_at(1001)
assert(ok==true and why=='Leviathan body removed: map change.' and spawned[6].destroyed and stored==nil,why)
map='/Game/Art/BG/WorldMap/Level_P/E04'
lv.command('show')
player=nil
ok,why=tick_at(1002)
assert(ok==true and why=='Leviathan body removed: map change.' and spawned[7].destroyed)
player=eve
-- Another object where its actor was: removed with no call on it.
lv.command('show')
spawned[8].GetFullName=function() return 'Other /Game/Other.Other:PersistentLevel.Other' end
spawned[8].components[1].calls={}
ok,why=tick_at(1003)
assert(ok==true and why=='Leviathan body removed: its actor is gone.' and not spawned[8].destroyed
    and #spawned[8].components[1].calls==0 and stored==nil,why)
-- A removal that fails keeps the file: the next Lua load tries again, and so does the next show, which shows nothing
-- new while it still fails, so the file never loses it.
lv.command('show')
local stuck,stuck_path=newest()
local kept,destroy=stuck_path..'\t'..path('CH_M_NA_10'),stuck.K2_DestroyActor
by_path[stuck_path]=stuck
stuck.K2_DestroyActor=function() error('busy',0) end
ok,why=lv.command('show','tentacle')
assert(not ok and why=='the Leviathan shown before could not be removed: busy' and last()=='removed (replaced): busy'
    and newest()==stuck and stored==kept,why)
assert(not lv.command('show','tentacle') and newest()==stuck and stored==kept,'Refused again')
stuck.K2_DestroyActor=destroy
ok,why=lv.command('show','tentacle')
local tentacle,tentacle_path=newest()
assert(ok and stuck.destroys==1 and stored==tentacle_path..'\t'..path('M_LeviathanTentacleA'),why)
tentacle.K2_DestroyActor=function() error('busy',0) end
ok,why=lv.command('off')
assert(ok and stored==tentacle_path..'\t'..path('M_LeviathanTentacleA')
    and last()=='removed (coop leviathan off): busy' and lv.tick()==nil,last())
tentacle.destroyed,stored=true,nil
-- Its first error removes it.
lv.command('show')
local erred=spawned[#spawned]
broken='no instance'
ok,why=tick_at(1004)
assert(ok==false and why=='Leviathan body removed on an error: no instance' and erred.destroyed and stored==nil,why)
assert(last()=='removed (error: no instance)' and lv.tick()==nil,last())
broken=nil

-- The next Lua load (Ctrl+R): the display the file names is destroyed at its first tick (or show), once, and the
-- file cleared.
lv.command('show')
local left,left_path=newest()
by_path[left_path]=left
local next_load=L.new({log=log,store=store})
next_load.restore()
assert(left.destroys==1 and stored==nil and last()=='restore: the display of an earlier Lua load destroyed',last())
stored=left_path..'\t'..path('CH_M_NA_10')
next_load.restore()
assert(stored~=nil,'Once a load')
-- show runs it first; a stale path only clears the file.
stored='/Game/Map.Map:PersistentLevel.Actor_77\t'..path('CH_M_NA_10')
local third=L.new({log=log,store=store})
logs={}
third.command('show','statue')
local statue,statue_path=newest()
assert(logs[1]=='restore: nothing left' and stored==statue_path..'\t'..path('C_Reviathan'))
-- A statue is swept by its static mesh; an actor whose root shows another mesh is left standing.
by_path[statue_path]=statue
L.new({log=log,store=store}).restore()
assert(statue.destroys==1 and stored==nil)
lv.command('show','a')
local other,other_path=newest()
by_path[other_path]=other
stored=other_path..'\t'..path('CH_M_NA_10')
L.new({log=log,store=store}).restore()
assert(not other.destroyed and stored==nil and last()=='restore: nothing left',last())
-- Without the native part: no file, the same display.
local bare=L.new({log=log})
bare.restore()
local before=#spawned
assert(bare.command('show') and #spawned==before+1 and bare.command('off'))
-- A mesh of another class than show needs is refused, also once list met it as any Object: Leviathan_A as a
-- StaticMesh never reaches SetSkeletalMesh.
local la=assets[path('Leviathan_A')]
local isa=la.IsA
la.IsA=function(_,c) return c.path=='/Script/CoreUObject.Object' or c.path=='/Script/Engine.StaticMesh' end
lv.command('list')
ok,why=pcall(lv.command,'show','a')
local refused=newest()
assert(not ok and why:find('Leviathan_A is missing on this PC',1,true) and refused.destroyed
    and #refused.components==0,why)
la.IsA=isa

-- Never another class than a plain Actor: here, and in the sources, which name no achievement, reward, item, quest,
-- save, possession, console command, spawn or destroy call of their own (race/doro.lua's spawn and remove do both).
for k,c in ipairs(spawn_classes) do assert(c=='/Script/Engine.Actor',k..': '..c) end
assert(#spawn_classes==#spawned)
for _,name in ipairs({'cut/leviathan','commands/cut'}) do
    local f=assert(io.open('mod/StellarCoop/Scripts/'..name..'.lua','rb'))
    local src=f:read('a')
    f:close()
    for call in src:gmatch('[:.]([%a_][%w_]*)%s*%(') do
        for _,word in ipairs({'Achiev','Reward','Item','Quest','Save','ExecuteConsoleCommand','Possess','Spawn',
            'CreateActor','Destroy'}) do
            assert(not call:find(word),name..': '..call)
        end
    end
end
print('leviathan_test ok')
