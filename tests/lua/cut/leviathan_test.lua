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
-- show also takes a distance (by default 1.6 times the mesh's bounding sphere radius, 6 m at least, or 6 m when its
-- bounds are unread), a height (by default its lowest point 5 m above EVE's feet, or its root when its bounds are
-- unread; the bounds are its asset's, times its scale) and a scale; move places the shown mesh again from where EVE
-- stands, without a new actor, with the same defaults; skin sets every material slot to the statue's or the Hydra's
-- material and default puts the mesh's own back, the skin kept across play, move and a new show; move and skin make no
-- call on a display whose actor is gone. The free camera: show and play turn it on, cam toggles it and sets its speed;
-- on, a plain actor with one CameraComponent where the game's camera was is the view target, and the controller ignores
-- move and look input; a coop-leviathan.txt that cannot be written leaves it off; each frame the keys (QWERTY and
-- AZERTY, Shift 4 times as fast, a hitch capped at 0.1 s) and the mouse move and turn it, and nothing reads a key while
-- the co-op menu is open; off, coop off, a map change, its first error and the next Lua load put the view back on what
-- it showed before (EVE when that is gone), leave a view the game took meanwhile, put both ignore flags back as they
-- were, and remove its actor.
-- coop gardener and coop tendril: one command a creature, each with its own usage line, list, clips (of its own folder
-- and skeleton), automatic distance and height (its lowest point at EVE's feet) and skins (none but its own for the
-- Gardener, the Hydra's for the Tendril, kept for that creature's next show only); showing one removes another
-- creature's display and says so, move and play of another creature leave it as it is, off from any creature's
-- command removes it, a failed removal is named by the creature its mesh belongs to.
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
local player,controller
package.loaded.UEHelpers={GetPlayer=function() return player end,GetPlayerController=function() return controller end}
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
-- An asset's path in the LIST of a creature (who: its word, the Leviathan when none).
local function path(name,who)
    for _,e in ipairs(L.CREATURES[who or 'leviathan'].LIST) do if e.path:match('[^.]+$')==name then return e.path end end
    error(name)
end
-- An asset at its LIST path: kinds are the class paths it IsA (the first one names its class), fields its properties.
local made=0
local function asset(name,kinds,fields,who)
    local p=path(name,who)
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
-- A display's component: its calls in order, as words. broken: PlayAnimation raises it. A mesh's has three material
-- slots, its own materials 'own 0' to 'own 2'. no_camera: no CameraComponent is added.
local broken,no_camera
local function component(actor,kind)
    local c=object({calls={},actor=actor,kind=kind,slots={[0]='own 0','own 1','own 2'}})
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
    function c:SetFieldOfView(v) said('fov',v) end
    function c:GetNumMaterials() return 3 end
    function c:GetMaterial(i) return self.slots[i] end
    function c:SetMaterial(i,m) assert(math.type(i)=='integer' and i>=0 and i<3); self.slots[i]=m end
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
        assert((k.path=='/Script/Engine.SkeletalMeshComponent' or k.path=='/Script/Engine.StaticMeshComponent'
            or k.path=='/Script/Engine.CameraComponent')
            and manual==false and transform=='identity' and deferred==false)
        if no_camera and k.path=='/Script/Engine.CameraComponent' then return nil end
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
-- EVE: her main mesh at her feet (eve_at), turned as her actor (eve_yaw) minus 90 degrees, her actor facing +Y.
local eve_at,eve_yaw={X=10,Y=20,Z=-87},90
local EVE_PATH='/Game/Map.Map:PersistentLevel.CH_P_EVE_01_Blueprint_C_0'
local eve=object({Mesh=object({K2_GetComponentLocation=function() return eve_at end,
    K2_GetComponentRotation=function() return {Pitch=0,Yaw=eve_yaw-90,Roll=0} end}),
    GetFullName=function() return 'CH_P_EVE_01_Blueprint_C '..EVE_PATH end})
by_path[EVE_PATH]=eve
function eve:IsA(k) return k.path=='/Script/SB.SBCharacter' end
function eve:GetWorld() return world end
function eve:K2_GetActorRotation() return {Pitch=0,Yaw=eve_yaw,Roll=0} end
player=eve
local stored -- coop-leviathan.txt's line.
local store={save=function(line) stored=line; return true end,load=function() return stored end,
    clear=function() stored=nil end}
local save=store.save
local logs={}
local function log(m) logs[#logs+1]=m end
local function last() return logs[#logs] end
local function close(a,b) return math.abs(a-b)<1e-6 end
local menu_open=false
local lv=L.new({log=log,store=store,blocked=function() return menu_open end})
local USE='Use: coop leviathan [list] | show [body|a|b|tentacle|statue] [<distance m>|auto] [<height m>|auto] '
    ..'[<scale>] | move <distance m>|auto [<height m>|auto] | skin statue|hydra|default | cam [<m/s>] | '
    ..'play [<clip>] | off'
local NO_CAM=', no free camera (no player controller)' -- Until the camera's part below.

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
for _,bad in ipairs({{'list','x'},{'show','huge'},{'show','body','x'},{'off','x'},{'play','a','b'},{'on'},
        {'show','-1'},{'show','body','10','1e9'},{'show','body','10','0','0'},{'show','10','up'},
        {'show','body','10','0','1','x'},{'show','10','0','1','x'},{'move'},{'move','up'},
        {'move','x'},{'move','10','up'},{'move','10','0','1'},{'skin'},{'skin','gold'},{'skin','hydra','x'},
        {'cam','0'},{'cam','fast'},{'cam','10','x'}}) do
    local done,said=lv.command(table.unpack(bad))
    assert(not done and said==USE,said)
end
assert(#spawned==0)

-- show: one plain Actor 6 m ahead of EVE and 5 m up (its bounds unread), facing her, collision off, the body's mesh at
-- scale 1 in the single-node mode; the file names it; then each clip of its skeleton twice in turn (the blend space for
-- 3 s), logged. No player controller: no free camera, said.
logs={}
clock=100
ok,why=lv.command('show')
assert(ok and why=='Leviathan body shown 6 m ahead, 5 m up, scale 1, 3 clips in turn'..NO_CAM..'; [LV] lines in this '
    ..'log.',why)
assert(last()=='show body: CH_M_NA_10, 3 clips on skeleton CH_M_NA_10_Skeleton, 6 m ahead, 5 m up, scale 1',last())
assert(logs[#logs-1]:find('^show body: bounds unread %(.*%), 6 m ahead, its root 5 m up$'),logs[#logs-1])
local a=spawned[1]
local m=a.components[1]
assert(#spawned==1 and #a.components==1 and a.collision==false)
assert(close(a.spawned_at.X,10) and close(a.spawned_at.Y,620) and a.spawned_at.Z==-87,'600 cm ahead of her')
assert(a.spawned_rot.Yaw==180 and close(m.at.Y,620) and m.at.Z==-87+500 and m.rot.Yaw==180,'Facing her, 5 m up')
assert(m.kind=='/Script/Engine.SkeletalMeshComponent'
    and table.concat(m.calls,'|')=='mesh CH_M_NA_10|scale 1|collision 0|mode 1|scale 1',table.concat(m.calls,'|'))
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
assert(ok and why=='Leviathan body holds M_Leviathan_LightningBall1_1 looping'..NO_CAM..'; coop leviathan play goes '
    ..'back to the cycle.',why)
tick_at(114); assert(last()=='play M_Leviathan_LightningBall1_1 looping',last())
tick_at(500); tick_at(900)
assert(table.concat(m.calls,'|')=='play M_Leviathan_LightningBall1_1 true|rate 1|at 0',table.concat(m.calls,'|'))
assert(select(2,lv.command('play','battle')):find(' holds IdleRun_BS_Battle looping,',1,true),'Its end first')
ok,why=lv.command('play','catch')
assert(not ok and why=='no clip of the shown body ends with or holds catch','Another skeleton\'s clip: not this one')
ok,why=lv.command('play')
assert(ok and why=='Leviathan body back to its cycle'..NO_CAM..'.',why)
tick_at(901); assert(last()=='show body step 2/3 M_Leviathan_LightningBall1_1 1.50 s twice',last())
-- A second show replaces the first: the tentacle, its own clips; bashleft is the clip that ends so.
logs={}
ok,why=lv.command('show','tentacle')
assert(ok and logs[1]=='removed (replaced)' and a.destroyed and #spawned==2,logs[1])
assert(last()=='show tentacle: M_LeviathanTentacleA, 3 clips on skeleton M_LeviathanTentacleA_Skeleton, 6 m ahead, 5 '
    ..'m up, scale 1',last())
assert(stored=='/Game/Map.Map:PersistentLevel.Actor_2\t'..path('M_LeviathanTentacleA'),stored)
assert(select(2,lv.command('play','bashleft')):find(' holds M_LeviathanTentacleA_BashLeft looping,',1,true))
assert(select(2,lv.command('play','BashLeft_1')):find(' holds M_LeviathanTentacleA_BashLeft_1 looping,',1,true))
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
    and table.concat(s.calls,'|')=='static C_Reviathan|scale 1|collision 0|scale 1',table.concat(s.calls,'|'))
assert(last()=='show statue: C_Reviathan, 0 clips on skeleton -, 6 m ahead, 5 m up, scale 1',last())
assert(tick_at(904)==nil and tick_at(999)==nil and #s.calls==4,'Nothing to play')
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

-- Placement: from the bounds of the mesh's asset times its scale, the distance (1.6 radii, 6 m at least) and the height
-- (its lowest point 5 m above EVE's feet), its radius, centre and lowest point logged; a distance, a height and a scale
-- given; auto for either.
lv.command('off')
local body=assets[path('CH_M_NA_10')]
local function bounds(r,z,half) body.ExtendedBounds={SphereRadius=r,Origin={X=0,Y=0,Z=z},BoxExtent={X=r,Y=r,Z=half}} end
bounds(5000,3000,3200)
logs={}
ok,why=lv.command('show')
local big=newest()
assert(ok and why:find('Leviathan body shown 80 m ahead, 7 m up, scale 1, ',1,true),why)
assert(logged('show body: bounding sphere radius 50 m, centre 30 m and lowest point -2 m above its root'))
assert(close(big.components[1].at.X,10) and close(big.components[1].at.Y,20+8000)
    and big.components[1].at.Z==-87+700,'80 m ahead, its lowest point 5 m above her feet')
-- Its scale counts: twice the size, twice as far, its lowest point still 5 m up.
ok,why=lv.command('show','auto','auto','2')
assert(ok and why:find('Leviathan body shown 160 m ahead, 9 m up, scale 2, ',1,true),why)
assert(logged('show body: bounding sphere radius 100 m, centre 60 m and lowest point -4 m above its root'))
bounds(100,0,50)
assert(select(2,lv.command('show')):find(' shown 6 m ahead, 5.5 m up,',1,true),'6 m at least')
ok,why=lv.command('show','body','20','5','2')
local placed=newest().components[1]
assert(ok and why:find('Leviathan body shown 20 m ahead, 5 m up, scale 2, ',1,true),why)
assert(close(placed.at.Y,20+2000) and placed.at.Z==-87+500 and placed.rot.Yaw==180,'20 m ahead, 5 m up, facing her')
assert(table.concat(placed.calls,'|')=='mesh CH_M_NA_10|scale 1|collision 0|mode 1|scale 2',
    table.concat(placed.calls,'|'))
bounds(2500,0,1000)
ok,why=lv.command('show','auto','10')
assert(ok and why:find(' shown 40 m ahead, 10 m up, scale 1, ',1,true) and newest().components[1].at.Z==-87+1000,why)
ok,why=lv.command('show','30')
assert(ok and why:find('Leviathan body shown 30 m ahead, 15 m up, ',1,true),'A distance alone: the body')
ok,why=lv.command('show','30','-2')
assert(ok and why:find(' shown 30 m ahead, -2 m up, ',1,true) and newest().components[1].at.Z==-87-200,why)
-- move: the same actor placed again from where EVE stands now and the way she faces; auto, or no word, takes its
-- bounds again.
lv.command('show','auto')
local moved,moved_path=newest()
local before=#spawned
eve_at,eve_yaw={X=1000,Y=0,Z=0},0
ok,why=lv.command('move','30','10')
local mm=moved.components[1]
assert(ok and why=='Leviathan body moved 30 m ahead of EVE, 10 m up.' and #spawned==before and not moved.destroyed,why)
assert(close(mm.at.X,4000) and close(mm.at.Y,0) and mm.at.Z==1000 and mm.rot.Yaw==90,'Ahead of her, facing her')
assert(last()=='move body: 30 m ahead, 10 m up' and stored==moved_path..'\t'..path('CH_M_NA_10'),last())
ok,why=lv.command('move','auto')
assert(ok and why=='Leviathan body moved 40 m ahead of EVE, 15 m up.' and close(mm.at.X,5000) and mm.at.Z==1500,why)
ok,why=lv.command('move','12')
assert(ok and why=='Leviathan body moved 12 m ahead of EVE, 15 m up.' and close(mm.at.X,2200),why)
ok,why=lv.command('move','12','auto')
assert(ok and why=='Leviathan body moved 12 m ahead of EVE, 15 m up.',why)
body.ExtendedBounds=nil
eve_at,eve_yaw={X=10,Y=20,Z=-87},90
-- Another object where its actor was: move and skin make no call on it, and it is removed as a tick would.
moved.GetFullName=function() return 'Other /Game/Other.Other:PersistentLevel.Other' end
local at_was=mm.at
ok,why=lv.command('move','10')
assert(not ok and why=='no Leviathan is shown: coop leviathan show first' and mm.at==at_was and not moved.destroyed
    and last()=='removed (its actor is gone)' and stored==nil,why)
lv.command('show')
local gone=newest()
gone.GetFullName=function() return 'Other /Game/Other.Other:PersistentLevel.Other' end
ok,why=lv.command('skin','statue')
assert(ok and why=='Leviathan skin statue for the next show.' and gone.components[1].slots[0]=='own 0',why)
lv.command('skin','default')
lv.command('off')
ok,why=lv.command('move','10')
assert(not ok and why=='no Leviathan is shown: coop leviathan show first')

-- skin: every slot to the material, default back to the mesh's own; kept across play, move and a new show; a missing
-- material changes nothing; with nothing shown, kept for the next show.
local function material(p)
    local o=object({key=p:match('[^.]+$')})
    o.GetFullName=function() return 'MaterialInstanceConstant '..p end
    o.IsA=function(_,c) return c.path=='/Script/Engine.MaterialInterface' or c.path=='/Script/CoreUObject.Object' end
    assets[p]=o
    return o
end
material(L.SKINS.statue)
local hydra=material(L.SKINS.hydra)
local function slots(c)
    local t={}
    for i=0,2 do t[#t+1]=type(c.slots[i])=='string' and c.slots[i] or c.slots[i].key end
    return table.concat(t,',')
end
lv.command('show')
local dm=newest().components[1]
ok,why=lv.command('skin','hydra')
assert(ok and why=='Leviathan body skin hydra on its 3 material slots.' and last()=='skin hydra: 3 slots, '
    ..'MI_M_NA_09_V03_Tentacle',why)
assert(slots(dm)=='MI_M_NA_09_V03_Tentacle,MI_M_NA_09_V03_Tentacle,MI_M_NA_09_V03_Tentacle',slots(dm))
lv.command('play','battle')
lv.command('move','12')
tick_at(5000)
assert(slots(dm)=='MI_M_NA_09_V03_Tentacle,MI_M_NA_09_V03_Tentacle,MI_M_NA_09_V03_Tentacle','Kept')
ok,why=lv.command('skin','default')
assert(ok and slots(dm)=='own 0,own 1,own 2' and last()=='skin default: 3 slots, its own',slots(dm))
lv.command('skin','statue')
assert(slots(dm)=='C_Reviathan_MI,C_Reviathan_MI,C_Reviathan_MI')
lv.command('skin','hydra')
lv.command('skin','default')
assert(slots(dm)=='own 0,own 1,own 2','One skin over another: default is still the mesh\'s own')
lv.command('skin','statue')
lv.command('show','tentacle')
local tm=newest().components[1]
assert(slots(tm)=='C_Reviathan_MI,C_Reviathan_MI,C_Reviathan_MI' and logged('skin statue: 3 slots, C_Reviathan_MI'),
    'A new show keeps the last skin')
hydra.destroyed,assets[L.SKINS.hydra]=true,nil
ok,why=pcall(lv.command,'skin','hydra')
assert(not ok and why:find('MI_M_NA_09_V03_Tentacle is missing on this PC',1,true)
    and slots(tm)=='C_Reviathan_MI,C_Reviathan_MI,C_Reviathan_MI',why)
lv.command('show','tentacle')
assert(slots(newest().components[1])=='C_Reviathan_MI,C_Reviathan_MI,C_Reviathan_MI','Still the statue\'s')
hydra=material(L.SKINS.hydra)
lv.command('off')
ok,why=lv.command('skin','default')
assert(ok and why=='Leviathan skin default for the next show.')
lv.command('show')
assert(slots(newest().components[1])=='own 0,own 1,own 2')
lv.command('off')

-- The free camera. The player controller: stacked move and look ignore counts, its view target, the keys held (down),
-- the mouse's delta, each key and mouse read counted.
local down,keys_broken={},nil
local PC_PATH='/Game/Map.Map:PersistentLevel.SBPlayerController_0'
local pc=object({move_n=0,look_n=0,reads=0,mouse_reads=0})
function pc:GetFullName() return 'SBPlayerController '..PC_PATH end
function pc:IsA(k) return k.path=='/Script/Engine.PlayerController' end
pc.PlayerCameraManager=object({GetCameraLocation=function() return {X=100,Y=200,Z=300} end,
    GetCameraRotation=function() return {Pitch=-10,Yaw=45,Roll=0} end,GetFOVAngle=function() return 80 end})
function pc:SetViewTargetWithBlend(a,blend,f,e,lock)
    assert(f==0 and e==0 and lock==false)
    self.view,self.blend=a,blend
end
function pc:GetViewTarget() return self.view end
function pc:K2_GetPawn() return player end
function pc:SetIgnoreMoveInput(b) self.move_n=math.max(self.move_n+(b and 1 or -1),0) end
function pc:SetIgnoreLookInput(b) self.look_n=math.max(self.look_n+(b and 1 or -1),0) end
function pc:IsMoveInputIgnored() return self.move_n>0 end
function pc:IsLookInputIgnored() return self.look_n>0 end
function pc:ResetIgnoreMoveInput() self.move_n=0 end
function pc:ResetIgnoreLookInput() self.look_n=0 end
function pc:IsInputKeyDown(k)
    self.reads=self.reads+1
    if keys_broken then error(keys_broken,0) end
    return down[k.KeyName:ToString()]==true
end
-- The controller's rotation, which the game turns from the mouse: the camera manager's at first.
local ctrl={Pitch=-10,Yaw=45,Roll=0}
function pc:GetControlRotation()
    self.mouse_reads=self.mouse_reads+1
    return {Pitch=ctrl.Pitch,Yaw=ctrl.Yaw,Roll=ctrl.Roll}
end
controller=pc
local function back(why)
    return pc.view==eve and pc.blend==0.3 and pc.move_n==0 and pc.look_n==0,why
end
-- show turns it on: a plain Actor with one CameraComponent where the game's camera is, with its field of view, the view
-- target; move and look input ignored; the file holds it beside the display, with the flags from before.
clock=6000
logs={}
ok,why=lv.command('show','body','20','5','2')
assert(ok and why=='Leviathan body shown 20 m ahead, 5 m up, scale 2, 3 clips in turn, free camera on; [LV] lines in '
    ..'this log.',why)
local camera,camera_path=newest()
local display_path='/Game/Map.Map:PersistentLevel.Actor_'..(#spawned-1)
local lens=camera.components[1]
assert(lens.kind=='/Script/Engine.CameraComponent' and #camera.components==1 and camera.collision==false)
assert(camera.spawned_at.X==100 and camera.spawned_at.Y==200 and camera.spawned_at.Z==300
    and camera.spawned_rot.Yaw==45 and camera.spawned_rot.Pitch==-10 and table.concat(lens.calls,'|')=='fov 80')
assert(pc.view==camera and pc.blend==0.3 and pc.move_n==1 and pc.look_n==0,'Move input ignored, look input left on')
assert(stored==display_path..'\t'..path('CH_M_NA_10')..'\t'..camera_path..'\t'..PC_PATH..'\t0\t0',stored)
assert(logged('cam on at 100 200 300 yaw 45.0 pitch -10.0, 10 m/s; before: move ignored 0, look ignored 0, view none'))
-- The keys move it along its view at 10 m/s: W (or Z) forward, Space (or E) up, Shift 4 times as fast; the mouse turns
-- it through the controller's rotation (pitch kept by the engine from 0 to 360); a hitch counts as 0.1 s.
local function fly(t) clock=t; return lv.tick() end
local function near(x,y,z) return close(lens.at.X,x) and close(lens.at.Y,y) and close(lens.at.Z,z) end
local p,y=math.rad(-10),math.rad(45)
down={W=true}
assert(fly(6000.05)==nil)
local x0,y0,z0=100+50*math.cos(p)*math.cos(y),200+50*math.cos(p)*math.sin(y),300+50*math.sin(p)
assert(near(x0,y0,z0) and lens.rot.Yaw==45 and lens.rot.Pitch==-10,lens.at.X)
down={Z=true,SpaceBar=true,LeftShift=true}
fly(6000.1)
x0,y0,z0=x0+200*math.cos(p)*math.cos(y),y0+200*math.cos(p)*math.sin(y),z0+200*math.sin(p)+200
assert(near(x0,y0,z0),'AZERTY forward, up, 4 times as fast')
down={E=true}
fly(6005)
assert(near(x0,y0,z0+100),'A hitch: 0.1 s')
z0=z0+100
down,ctrl={},{Pitch=340,Yaw=50,Roll=0}
fly(6005.05)
assert(near(x0,y0,z0) and close(lens.rot.Yaw,50) and close(lens.rot.Pitch,-20),lens.rot.Pitch)
-- The arrows add their turn to the controller's: 90 degrees a second.
down={Right=true,Up=true}
fly(6005.1)
assert(close(lens.rot.Yaw,54.5) and close(lens.rot.Pitch,-15.5),lens.rot.Yaw)
down={Left=true,Down=true}
fly(6005.15)
assert(close(lens.rot.Yaw,50) and close(lens.rot.Pitch,-20),'The arrows turned back')
down={}
-- Nothing reads a key or the mouse while the co-op menu is open; the camera stays.
menu_open,down=true,{W=true}
local reads,mouse_reads=pc.reads,pc.mouse_reads
fly(6005.1)
assert(pc.reads==reads and pc.mouse_reads==mouse_reads and near(x0,y0,z0),'The menu open')
menu_open,down=false,{}
-- 1 s in, its view target logged once.
fly(6001.5+5)
assert(logged('cam view target Actor '..camera_path),'The view target')
-- cam <m/s>: its speed.
ok,why=lv.command('cam','20')
assert(ok and why=='Free camera speed 20 m/s, 4 times that with Shift.' and last()=='cam speed 20 m/s',why)
down={S=true}
local t=6006.55
fly(t)
assert(near(x0-100*math.cos(math.rad(-20))*math.cos(math.rad(50)),y0-100*math.cos(math.rad(-20))*math.sin(math.rad(50)),
    z0-100*math.sin(math.rad(-20))),'Back at 20 m/s')
down={}
assert(lv.command('cam','10'))
-- move and skin leave it as it is.
local count=#spawned
assert(lv.command('move','25') and lv.command('skin','statue') and #spawned==count and pc.view==camera)
lv.command('skin','default')
-- cam: off, the view back on EVE (no view target before) with a 0.3 s blend, both flags back, its actor gone, the
-- file the display's alone.
ok,why=lv.command('cam')
assert(ok and why=="Free camera off: the game's camera is back." and back() and camera.destroyed,why)
assert(last()=='cam off (coop leviathan cam): move ignored 0, look ignored 0',last())
assert(stored==display_path..'\t'..path('CH_M_NA_10'),stored)
ok,why=lv.command('cam')
camera,camera_path=newest()
assert(ok and why:find('^Free camera on: W or Z, S, A or Q, D move it') and pc.view==camera and pc.move_n==1,why)
-- play keeps it on, and turns it on when it is off.
ok,why=lv.command('play','battle')
assert(ok and why=='Leviathan body holds IdleRun_BS_Battle looping; coop leviathan play goes back to the cycle.',why)
lv.command('cam')
ok,why=lv.command('play')
assert(ok and why=='Leviathan body back to its cycle, free camera on.' and pc.view==newest(),why)
lv.command('cam')
-- The flags as they were: move input ignored by the game before stays ignored; one the game added meanwhile goes.
pc.move_n,pc.look_n=1,1
lv.command('cam')
assert(pc.move_n==2 and pc.look_n==1 and stored:sub(-#EVE_PATH-5)=='\t1\t1\t'..EVE_PATH,stored)
lv.command('cam')
assert(pc.move_n==1 and pc.look_n==1,'Ignored before, ignored after')
pc.move_n,pc.look_n=0,0
lv.command('cam')
pc.move_n=2
lv.command('cam')
assert(back(),'Not ignored before: not after')
-- off: the display and the camera.
lv.command('cam')
camera=newest()
ok,why=lv.command('off')
assert(ok and why=="Leviathan removed. Free camera off: the game's camera is back." and back() and camera.destroyed
    and stored==nil,why)
-- cam alone, without a display; no EVE: none.
ok,why=lv.command('cam')
assert(ok and pc.view==newest() and stored=='\t\t'..select(2,newest())..'\t'..PC_PATH..'\t0\t0\t'..EVE_PATH,stored)
lv.command('cam')
player=nil
ok,why=lv.command('cam')
assert(not ok and why=='no free camera: no EVE in the world' and back())
player=eve
-- The view as it was before: a camera of the game's comes back, EVE when it is gone; a view the game took meanwhile (a
-- dialogue's camera) is left to it, the flags back all the same.
local function game_camera(name)
    local p='/Game/Map.Map:PersistentLevel.'..name
    local c=object({GetFullName=function() return name:match('^(.-)_%d+$')..' '..p end})
    by_path[p]=c
    return c,p
end
local fixed,fixed_path=game_camera('SBCameraActor_3')
pc.view=fixed
lv.command('cam')
assert(stored:sub(-#fixed_path-1)=='\t'..fixed_path and last():find(', view '..fixed_path,1,true),last())
lv.command('cam')
assert(pc.view==fixed and pc.blend==0.3 and pc.move_n==0 and pc.look_n==0,"The game's camera back")
lv.command('cam')
fixed.destroyed=true
lv.command('cam')
assert(back(),'That camera gone: EVE')
lv.command('cam')
local dialogue=game_camera('SBCineDialogueCameraActor_1')
pc.view=dialogue
ok,why=lv.command('cam')
assert(ok and pc.view==dialogue and pc.move_n==0 and pc.look_n==0 and newest().destroyed,'Taken: left to the game')
pc.view=eve
-- A coop-leviathan.txt that cannot be written: no free camera, its actor gone, the controller as it was.
store.save=function() return false,'cannot write coop-leviathan.txt' end
ok,why=lv.command('cam')
assert(not ok and why=='no free camera: coop-leviathan.txt not written (cannot write coop-leviathan.txt)'
    and newest().destroyed and pc.view==eve and pc.move_n==0 and pc.look_n==0 and not lv.filming(),why)
store.save=save
-- A camera that cannot be made: the show stands and says so, its actor gone, nothing of the controller changed.
no_camera=true
ok,why=lv.command('show')
assert(ok and why:find(', no free camera %(.*the camera could not be added%); ') and newest().destroyed
    and back() and stored=='/Game/Map.Map:PersistentLevel.Actor_'..(#spawned-1)..'\t'..path('CH_M_NA_10'),why)
no_camera=false
lv.command('off')
-- coop off.
lv.command('show')
camera=newest()
lv.stop()
assert(back() and camera.destroyed and stored==nil and last()=='cam off (coop off): move ignored 0, look ignored 0',
    last())
-- A map change: with the display, both go; the camera alone goes too.
lv.command('show')
camera=newest()
fly(7000)
map='/Game/Art/BG/WorldMap/Level_P/B07'
ok,why=fly(7000.1)
assert(ok==true and why=='Leviathan body removed: map change.' and back() and camera.destroyed and stored==nil,why)
map='/Game/Art/BG/WorldMap/Level_P/E04'
lv.command('cam')
camera=newest()
map='/Game/Art/BG/WorldMap/Level_P/B07'
ok,why=fly(7000.2)
assert(ok==true and why=='Free camera off: map change.' and back() and camera.destroyed and stored==nil,why)
map='/Game/Art/BG/WorldMap/Level_P/E04'
-- Its first error: the camera off, the display stays.
lv.command('show')
camera=newest()
keys_broken='no input'
ok,why=fly(7000.3)
assert(ok==false and why=='Free camera off on an error: no input' and back() and camera.destroyed,why)
assert(stored=='/Game/Map.Map:PersistentLevel.Actor_'..(#spawned-1)..'\t'..path('CH_M_NA_10'),stored)
keys_broken=nil
assert(fly(7000.4)==nil and lv.command('off'))
-- The mouse turns the controller's yaw but not its pitch in this game: the pitch follows the source that moved most,
-- here EVE's own camera component, and a probe line each second for 6 s says what each source read.
local eve_cam={pitch=-5,desired=-6}
local sbcam=object({K2_GetComponentRotation=function() return {Pitch=eve_cam.pitch,Yaw=0,Roll=0} end})
function eve:GetComponentByClass(k)
    assert(k.path=='/Script/SB.SBCameraComponent',k.path)
    sbcam.DesiredViewRotFromLegacy={Pitch=eve_cam.desired,Yaw=0,Roll=0}
    return sbcam
end
logs={}
lv.command('cam')
lens=newest().components[1]
local t0=clock
fly(t0+0.05)
assert(close(lens.rot.Pitch,-10) and close(lens.rot.Yaw,50),'Nothing moved: the pitch it started with')
eve_cam.pitch,eve_cam.desired=340,-6 -- 20 degrees down, 0 to 360 as the engine keeps it.
fly(t0+0.1)
assert(close(lens.rot.Pitch,-25) and close(lens.rot.Yaw,50),lens.rot.Pitch)
fly(t0+1.2)
assert(logged('cam pitch probe 1: control -20.0, camera -20.0, desired -6.0; used camera -15.0'),logs[#logs])
for i=2,8 do fly(t0+i+0.2) end
local probes=0
for _,line in ipairs(logs) do if line:find('^cam pitch probe') then probes=probes+1 end end
assert(probes==6,'6 probe lines: '..probes)
lv.command('cam')
eve.GetComponentByClass=nil
clock=t0 -- The clock the next test counts from.
-- The controller's rotation unread: said once, the arrows alone turn it, 90 degrees a second.
pc.GetControlRotation=function() error('no rotation',0) end
lv.command('cam')
lens=newest().components[1]
down={Right=true,Up=true}
fly(7000.5)
assert(close(lens.rot.Yaw,54) and close(lens.rot.Pitch,-1),lens.rot.Yaw)
assert(logged('cam: the view cannot follow the mouse (no rotation); the arrow keys turn the camera'))
mouse_reads=#logs
fly(7000.6)
assert(#logs==mouse_reads,'Said once')
down={}
lv.command('cam')
-- The next Lua load: the display swept, the camera's actor too, the controller given back (its view on what it showed
-- before), the file cleared; a file whose controller is gone only sweeps.
local old=L.new({log=log,store=store})
old.command('show')
camera,camera_path=newest()
local display=spawned[#spawned-1]
by_path[camera_path],by_path['/Game/Map.Map:PersistentLevel.Actor_'..(#spawned-1)],by_path[PC_PATH]=camera,display,pc
assert(pc.view==camera and pc.move_n==1)
L.new({log=log,store=store}).restore()
assert(back() and camera.destroys==1 and display.destroys==1 and stored==nil)
assert(last()=='restore: the display of an earlier Lua load destroyed; the free camera of an earlier Lua load off: '
    ..'move ignored 0, look ignored 0',last())
-- A camera of the game's before it comes back.
local before_cam=game_camera('SBCameraActor_4')
pc.view=before_cam
L.new({log=log,store=store}).command('cam')
camera,camera_path=newest()
by_path[camera_path]=camera
L.new({log=log,store=store}).restore()
assert(pc.view==before_cam and pc.move_n==0 and pc.look_n==0 and camera.destroys==1 and stored==nil)
pc.view=eve
stored='\t\t/Game/Map.Map:PersistentLevel.Actor_99\t/Game/Gone.Gone:PersistentLevel.PC_0\t0\t0'
L.new({log=log,store=store}).restore()
assert(stored==nil and last()=='restore: the free camera of an earlier Lua load off: its controller is gone',last())
controller=nil

-- coop gardener and coop tendril: the same viewer with their own meshes, clips, defaults and skins, and one display
-- between the three. new gives one command a creature, coop leviathan's also as command; no LIST names a path twice.
local cmds=L.new({log=log})
assert(cmds.command==cmds.commands.leviathan and cmds.commands.gardener and cmds.commands.tendril)
local n_cmds=0
for _ in pairs(cmds.commands) do n_cmds=n_cmds+1 end
assert(n_cmds==3,n_cmds)
for name,who in pairs(L.CREATURES) do
    local seen={}
    for _,e in ipairs(who.LIST) do assert(not seen[e.path],name..': '..e.path); seen[e.path]=true end
end
local gd,td=L.CREATURES.gardener,L.CREATURES.tendril
local gardener,tendril=lv.commands.gardener,lv.commands.tendril
assert(gd.USE=='Use: coop gardener [list] | show [body] [<distance m>|auto] [<height m>|auto] [<scale>] | move '
    ..'<distance m>|auto [<height m>|auto] | skin default | cam [<m/s>] | play [<clip>] | off',gd.USE)
assert(td.USE=='Use: coop tendril [list] | show [body] [<distance m>|auto] [<height m>|auto] [<scale>] | move '
    ..'<distance m>|auto [<height m>|auto] | skin hydra|default | cam [<m/s>] | play [<clip>] | off',td.USE)
for _,bad in ipairs({{'show','a'},{'show','statue'},{'skin','statue'},{'skin','hydra'},{'list','x'},{'move'}}) do
    local done,said=gardener(table.unpack(bad))
    assert(not done and said==gd.USE,said)
end
assert(select(2,tendril('skin','statue'))==td.USE)
-- The Gardener's files as the pak has them (its bounds, read offline: about 20 m tall), three clips and a blend space
-- of its skeleton, one of them named as one of the Leviathan's in another folder.
local g_sk=asset('CH_M_NA_01_Skeleton',{'/Script/Engine.Skeleton'},nil,'gardener')
asset('CH_M_NA_01',MESH,{Skeleton=g_sk,ExtendedBounds={SphereRadius=1453,Origin={X=0,Y=206,Z=798},
    BoxExtent={X=511,Y=907,Z=1014}}},'gardener')
asset('Mon_Gardener_C_Hide',SEQ,{Skeleton=g_sk,SequenceLength=4.0},'gardener')
asset('Mon_Gardener_C_UnHide',SEQ,{Skeleton=g_sk,SequenceLength=4.5},'gardener')
asset('Mon_Gardener_S_03_Toxic_Beam',SEQ,{Skeleton=g_sk,SequenceLength=6.0},'gardener')
asset('IdleRun_BS_Battle',BS,{Skeleton=g_sk},'gardener')
asset('CH_M_NA_01_BluePrint_C',{'/Script/Engine.BlueprintGeneratedClass'},{GetSuperStruct=super('SBCharacter')},
    'gardener')
local function present(who)
    local n=0
    for _,e in ipairs(L.CREATURES[who].LIST) do if assets[e.path] then n=n+1 end end
    return n
end
-- list: its own assets, and the rows its words name.
ROWS[#ROWS+1]={'M_Gardener',{ID=50010,Type=fname('M_Gardener')}}
logs={}
local count=#spawned
ok,why=gardener('list')
assert(ok and why==string.format('Gardener list: %d of %d assets found, 1 CharacterTable rows name it; [LV] lines in '
    ..'this log.',present('gardener'),#gd.LIST),why)
assert(logged('list class CH_M_NA_01_BluePrint_C: BlueprintGeneratedClass super=SBCharacter')
    and logged('list clip Mon_Gardener_B_Tower_01: missing') and logged('list mesh CH_M_NA_01: SkeletalMesh '
    ..'skeleton=CH_M_NA_01_Skeleton') and not logged('list mesh CH_M_NA_10: SkeletalMesh skeleton=CH_M_NA_10_Skeleton'))
assert(last()=='list CharacterTable rows=5 named=1' and #spawned==count,last())
-- show: the Leviathan shown before goes, said; 1.6 radii ahead, its lowest point at EVE's feet; its own clips in turn.
lv.command('show','tentacle')
local lev_shown=newest()
logs={}
ok,why=gardener('show')
local g,g_path=newest()
local gm=g.components[1]
assert(ok and why=='Leviathan removed: one cut Naytiba is shown at a time. Gardener body shown 23.2 m ahead, 2.2 m up, '
    ..'scale 1, 4 clips in turn'..NO_CAM..'; [LV] lines in this log.',why)
assert(logs[1]=='removed (replaced by the Gardener)' and lev_shown.destroyed,logs[1])
assert(close(gm.at.Y,20+1.6*1453) and gm.at.Z==-87+216 and gm.rot.Yaw==180,'Ahead of her, on the ground')
assert(table.concat(gm.calls,'|')=='mesh CH_M_NA_01|scale 1|collision 0|mode 1|scale 1',table.concat(gm.calls,'|'))
assert(last()=='show body: CH_M_NA_01, 4 clips on skeleton CH_M_NA_01_Skeleton, 23.2 m ahead, 2.2 m up, scale 1',
    last())
assert(stored==g_path..'\t'..path('CH_M_NA_01','gardener'),stored)
gm.calls={}
tick_at(8000); assert(last()=='show body step 1/4 Mon_Gardener_C_Hide 4.00 s twice',last())
tick_at(8008); assert(last()=='show body step 2/4 Mon_Gardener_C_UnHide 4.50 s twice',last())
tick_at(8017); assert(last()=='show body step 3/4 Mon_Gardener_S_03_Toxic_Beam 6.00 s twice',last())
tick_at(8029); assert(last()=='show body step 4/4 IdleRun_BS_Battle 3.00 s twice',last())
assert(table.concat(gm.calls,'|'):find('|play IdleRun_BS_Battle true|',1,true))
ok,why=gardener('play','TOXIC_BEAM')
assert(ok and why=='Gardener body holds Mon_Gardener_S_03_Toxic_Beam looping'..NO_CAM..'; coop gardener play goes '
    ..'back to the cycle.',why)
assert(select(2,gardener('play','hide')):find(' holds Mon_Gardener_C_Hide looping',1,true),'Its end, the first')
assert(select(2,gardener('play','unhide')):find(' holds Mon_Gardener_C_UnHide looping',1,true))
ok,why=gardener('move','auto','0')
assert(ok and why=='Gardener body moved 23.2 m ahead of EVE, 0 m up.' and gm.at.Z==-87,why)
ok,why=gardener('skin','default')
assert(ok and why=='Gardener body skin default on its 3 material slots.' and slots(gm)=='own 0,own 1,own 2',why)
-- The Leviathan's and the Tendril's commands leave the Gardener as it is: no move, no play, a skin for their next show.
local g_at=gm.at
for _,c in ipairs({{lv.command,'Leviathan','leviathan'},{tendril,'Tendril','tendril'}}) do
    local run,title,word=c[1],c[2],c[3]
    assert(select(2,run('move','10'))=='no '..title..' is shown: coop '..word..' show first' and gm.at==g_at)
    assert(select(2,run('play','idle'))=='no '..title..' is shown: coop '..word..' show first')
end
ok,why=lv.command('skin','statue')
assert(ok and why=='Leviathan skin statue for the next show.' and slots(gm)=='own 0,own 1,own 2',why)
lv.command('skin','default')
-- A map change: the Gardener's title in the message.
map='/Game/Art/BG/WorldMap/Level_P/B07'
ok,why=tick_at(8030)
assert(ok==true and why=='Gardener body removed: map change.' and g.destroyed and stored==nil,why)
map='/Game/Art/BG/WorldMap/Level_P/E04'
-- The Tendril: no material of its own; the Hydra's skin, kept for its next show and never given to another creature.
-- A clip of another skeleton in its folder is left out.
local t_sk=asset('CH_M_NA_06_test_Skeleton',{'/Script/Engine.Skeleton'},nil,'tendril')
asset('CH_M_NA_06_test',MESH,{Skeleton=t_sk,ExtendedBounds={SphereRadius=724,Origin={X=-12,Y=-62,Z=315},
    BoxExtent={X=302,Y=565,Z=338}}},'tendril')
asset('M_Tendril_WhipAttack',SEQ,{Skeleton=t_sk,SequenceLength=5.1},'tendril')
asset('M_Tendril_WhipAttack_L',SEQ,{Skeleton=t_sk,SequenceLength=2.0},'tendril')
asset('Idle',SEQ,{Skeleton=t_sk,SequenceLength=10.0},'tendril')
asset('Airborne_BS',BS,{Skeleton=g_sk},'tendril')
ok,why=tendril('list')
assert(ok and why==string.format('Tendril list: %d of %d assets found, 0 CharacterTable rows name it; [LV] lines in '
    ..'this log.',present('tendril'),#td.LIST),why)
gardener('show')
ok,why=tendril('show')
local t,t_path=newest()
local tm2=t.components[1]
assert(ok and why=='Gardener removed: one cut Naytiba is shown at a time. Tendril body shown 11.6 m ahead, 0.2 m up, '
    ..'scale 1, 3 clips in turn'..NO_CAM..'; [LV] lines in this log.',why)
assert(last()=='show body: CH_M_NA_06_test, 3 clips on skeleton CH_M_NA_06_test_Skeleton, 11.6 m ahead, 0.2 m up, '
    ..'scale 1',last())
assert(stored==t_path..'\t'..path('CH_M_NA_06_test','tendril'),stored)
assert(select(2,tendril('play','whipattack')):find(' holds M_Tendril_WhipAttack looping',1,true))
assert(select(2,tendril('play','WhipAttack_L')):find(' holds M_Tendril_WhipAttack_L looping',1,true))
assert(not tendril('play','airborne'),'Another skeleton\'s blend space: not played')
ok,why=tendril('skin','hydra')
assert(ok and why=='Tendril body skin hydra on its 3 material slots.' and slots(tm2)=='MI_M_NA_09_V03_Tentacle,'
    ..'MI_M_NA_09_V03_Tentacle,MI_M_NA_09_V03_Tentacle',why)
tendril('show','auto','auto','2')
assert(slots(newest().components[1])=='MI_M_NA_09_V03_Tentacle,MI_M_NA_09_V03_Tentacle,MI_M_NA_09_V03_Tentacle'
    and logged('show body: bounding sphere radius 14.5 m, centre 6.3 m and lowest point -0.5 m above its root'),
    'Kept for its next show, at its scale')
lv.command('show')
assert(slots(newest().components[1])=='own 0,own 1,own 2','The Leviathan keeps its own skin')
-- off from another creature's command removes whichever is shown; then nothing.
ok,why=gardener('off')
assert(ok and why=='Leviathan removed.' and newest().destroyed and stored==nil and last()=='removed (coop gardener off)',
    why)
assert(select(2,gardener('off'))=='No Gardener is shown.')
tendril('skin','default')
-- A display of another creature whose removal fails is named by its mesh; the next Lua load sweeps a Gardener too.
gardener('show')
local stuck_g,stuck_g_path=newest()
by_path[stuck_g_path]=stuck_g
local g_destroy=stuck_g.K2_DestroyActor
stuck_g.K2_DestroyActor=function() error('busy',0) end
ok,why=tendril('show')
assert(not ok and why=='the Gardener shown before could not be removed: busy'
    and stored==stuck_g_path..'\t'..path('CH_M_NA_01','gardener'),why)
stuck_g.K2_DestroyActor=g_destroy
L.new({log=log,store=store}).restore()
assert(stuck_g.destroys==1 and stored==nil and last()=='restore: the display of an earlier Lua load destroyed',last())

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
