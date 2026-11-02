-- matrix13/world/breakables.lua with fake UE4SS objects: outside world 2800 nothing; in it, once a world, one
-- FindAllOf('StaticMeshActor') pass on its own tick, then PER_TICK entries a tick, each with its proxy's collision off
-- and the proxy hidden before the deferred spawn, the class loaded before Begin, the alias and a barrel's fuse set
-- between Begin and Finish, and no save type written; one [MXBREAK] line each and a total line. A failed spawn gives
-- the proxy back; a missing proxy spawns nothing; an entry with proxy_in_cook=false spawns with no lookup. A box that
-- breaks and destroys itself brings no second spawn; a new world spawns all again. The BREAK list: Matrix 11's
-- pairings, Z4R21's lower box before the one on it, the R23 box with no proxy.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
local next_address=0x1000
local events={} -- What happened, in order: 'hide K', 'show K', 'begin K', 'finish K'.
local function object(fields)
    next_address=next_address+0x100
    local at,o=next_address,fields or {}
    o.type=function() return 'UObject' end
    o.IsValid=o.IsValid or function(self) return not self.destroyed end
    o.GetAddress=function() return at end
    o.K2_DestroyActor=function(self) self.destroyed=true end
    return o
end
local world_name='World /Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P.MXIII_P'
local world
local function new_world() world=object({GetFullName=function() return world_name end}) end
new_world()
local function wrapper(w) return setmetatable({},{__index=w}) end
local eve=object({IsA=function() return true end,GetWorld=function() return wrapper(world) end})
package.loaded.UEHelpers={GetPlayer=function() return eve end,GetPlayerController=function() return nil end}
-- A proxy: a tagged StaticMeshActor, solid and shown.
local function proxy(name,tag)
    return object({name=name,collision=true,hidden=false,
        GetFName=function() return name end,
        ActorHasTag=function(_,t) return tag and t.name=='MXIII_BREAK' end,
        SetActorEnableCollision=function(self,on) self.collision=on; events[#events+1]=(on and 'solid ' or 'clear ')..name end,
        SetActorHiddenInGame=function(self,h) self.hidden=h; events[#events+1]=(h and 'hide ' or 'show ')..name end})
end
local actors={} -- What FindAllOf('StaticMeshActor') gives.
local walks=0
FindAllOf=function(cls)
    assert(cls=='StaticMeshActor',cls)
    walks=walks+1
    return actors
end
local spawned={}
local fail_key=nil -- The key whose Begin fails.
local in_deferred=false
local by_x={} -- Each test entry's X, to tell which entry a Begin is for.
local gs=object({
    BeginDeferredActorSpawnFromClass=function(_,ctx,class,t,how,owner)
        assert(ctx==eve and how==1 and owner==nil)
        local current=by_x[t.at.X]
        if current==fail_key then error('no such function') end
        in_deferred=true
        events[#events+1]='begin '..current
        local a=object({class=class,at=t.at,rot=t.rot,key=current})
        spawned[#spawned+1]=a
        return a
    end,
    FinishSpawningActor=function(_,a,t)
        in_deferred=false
        a.finished=t
        events[#events+1]='finish '..a.key
        return a
    end})
local km=object({MakeTransform=function(_,at,rot,scale)
    -- The rotation as named fields, the scale 1: the construction script gives RootTransform its 1.8.
    assert(rot.Pitch==0 and rot.Roll==0 and rot.Yaw and scale.X==1)
    return {at=at,rot=rot,scale=scale}
end})
local loaded,classes={},{}
local finds=0
StaticFindObject=function(path)
    finds=finds+1
    if path=='/Script/Engine.Default__GameplayStatics' then return gs end
    if path=='/Script/Engine.Default__KismetMathLibrary' then return km end
    if path=='/Script/SB.SBCharacter' then return object({}) end
    assert(not path:find('MXIII_Editor',1,true),'No StaticFindObject of a proxy: '..path)
    if path:find('_C$') and loaded[path:sub(1,-3)] then
        classes[path]=classes[path] or object({path=path})
        return classes[path]
    end
    return nil
end
LoadAsset=function(path) assert(not in_deferred,'LoadAsset inside a deferred spawn: '..path); loaded[path]=true end
FName=function(t) return {name=t,ToString=function() return t end,type=function() return 'FName' end} end
local B=require('matrix13.world.breakables')
local Rows=require('matrix13.world.rows')

local function entry(key,cls,extra)
    local x=#by_x+1
    by_x[x]=key
    local m={key=key,level='MXIII_Z1_Life',cls=cls,at={x,2,3},yaw=-95,
        alias=cls=='barrel' and 'ME_01_ZEA_001' or cls=='box2' and 'ME_01_ZEA_007' or 'ME_01_ZEA_003'}
    if cls=='barrel' then m.delay={2.0,2.5} end
    for k,v in pairs(extra or {}) do m[k]=v end
    return m
end
local list={entry('A','box1'),entry('BAD','box2'),entry('C','barrel'),entry('R23','box1',{proxy_in_cook=false,
    gates='DLC02_10_E_ItemS_015'}),entry('LOST','box1')}
local pa,pbad,pc=proxy('A',true),proxy('BAD',true),proxy('C',true)
actors={pa,pbad,pc,proxy('LOST',false),proxy('Other',false)} -- LOST lacks the tag: not a proxy.
fail_key='BAD'
local lines={}
local br=B.new({log=function(m) lines[#lines+1]=m end,list=list})

-- Not in world 2800: nothing.
world_name='World /Game/Art/BG/WorldMap/Dungeon_P/Matrix_XI.Matrix_XI'
br.tick()
assert(walks==0 and #spawned==0 and #lines==0,'Outside Matrix XIII: nothing')
world_name='World /Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P.MXIII_P'
clock=0.5; br.tick(); assert(walks==0,'Once a second while idle')
clock=1.0; br.tick()
assert(walks==1 and #spawned==0,'The proxy pass on its own tick, nothing spawned yet')
br.tick()
assert(walks==1,'One FindAllOf pass a world')
-- Spawn after hide, with the class loaded before Begin.
local a=spawned[1]
assert(a.key=='A' and a.finished and a.class.path==B.ASSETS.box1..'_C' and a.at.X==1 and a.at.Z==3
    and a.rot.Yaw==-95 and a.ZoneEventActorTableAlias.name=='ME_01_ZEA_003' and a.ZoneEventActorSaveType==nil
    and a.DestructionDelayMinTime==nil,'Box_01 spawned with its alias, no save type, no fuse')
assert(events[1]=='clear A' and events[2]=='hide A' and events[3]=='begin A' and events[4]=='finish A',
    table.concat(events,', '))
assert(not pa.collision and pa.hidden,'The proxy is off')
assert(lines[1]=='box1 A (MXIII_Z1_Life) at 1 2 3 yaw -95 alias ME_01_ZEA_003, proxy hidden',lines[1])
-- A failed spawn: the proxy restored.
assert(events[5]=='clear BAD' and events[6]=='hide BAD' and events[7]=='solid BAD' and events[8]=='show BAD',
    table.concat(events,', '))
assert(pbad.collision and not pbad.hidden,'The proxy is back')
assert(lines[2]:find('^box2 BAD %(MXIII_Z1_Life%) not spawned: .*no such function, proxy restored$'),lines[2])
-- The barrel: its fuse, no save type.
local c=spawned[2]
assert(c.key=='C' and c.class.path==B.ASSETS.barrel..'_C' and c.ZoneEventActorTableAlias.name=='ME_01_ZEA_001'
    and c.DestructionDelayMinTime==2.0 and c.DestructionDelayMaxTime==2.5 and c.ZoneEventActorSaveType==nil,
    'The barrel: its alias and fuse')
-- R23: no proxy lookup, spawned alone.
local r=spawned[3]
assert(r.key=='R23' and r.finished and events[13]=='begin R23' and #events==14,table.concat(events,', '))
assert(lines[4]=='box1 R23 (MXIII_Z1_Life) at 4 2 3 yaw -95 alias ME_01_ZEA_003, no proxy in the cook, gates '
    ..'DLC02_10_E_ItemS_015',lines[4])
-- A proxy not found (no tag): nothing spawned.
assert(lines[5]=='box1 LOST (MXIII_Z1_Life) not spawned: no proxy LOST in MXIII_Z1_Life',lines[5])
assert(lines[6]=='3/5 boxes and barrels spawned in world 2800, 2 proxies hidden',lines[6])
assert(#spawned==3,'BAD never began')

-- No respawn after a box breaks and destroys itself: the world address alone decides.
for _,x in ipairs(spawned) do x.destroyed=true end
local before,said=#spawned,#lines
for t=2,5 do clock=t; br.tick() end
assert(#spawned==before and #lines==said and walks==1,'A destroyed box brings no second spawn')

-- Leaving world 2800 and a new world: all again, with a new proxy pass.
world_name='World /Game/Art/BG/WorldMap/Dungeon_P/Matrix_XI.Matrix_XI'
clock=6; br.tick()
world_name='World /Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P.MXIII_P'
new_world()
pa.collision,pa.hidden=true,false
clock=7; br.tick(); br.tick()
assert(walks==2 and spawned[#spawned].key=='R23' and #lines==said+6,'A new world spawns all again')

-- The tick spreading: PER_TICK entries a tick, the total line after the last.
do
    local many,props={},{}
    for i=1,B.PER_TICK*2+5 do
        many[i]=entry('K'..i,'box1')
        props[i]=proxy('K'..i,true)
    end
    actors=props
    fail_key=nil
    local got={}
    local count=#spawned
    local b2=B.new({log=function(m) got[#got+1]=m end,list=many})
    new_world()
    clock=clock+10
    b2.tick() -- The proxy pass.
    assert(#spawned==count,'Nothing spawned on the pass tick')
    b2.tick()
    assert(#spawned==count+B.PER_TICK and #got==B.PER_TICK,'PER_TICK the first tick: '..(#spawned-count))
    b2.tick()
    assert(#spawned==count+2*B.PER_TICK,'PER_TICK the second tick')
    b2.tick()
    assert(#spawned==count+#many and got[#got]==string.format('%d/%d boxes and barrels spawned in world 2800, %d '
        ..'proxies hidden',#many,#many,#many),got[#got])
    b2.tick()
    assert(#spawned==count+#many,'Done: nothing more')
end

-- The BREAK list: 317 entries, Matrix 11's pairings, Z4R21's Box_02_05 before Box_01_68_Plus, R23 with no proxy.
do
    local seen,at={},{}
    local R23='FP1_Z1_LOOT_R23_D_BP_Destruction_Box_01_FP1_153'
    for i,m in ipairs(Rows.BREAK) do
        assert(not seen[m.key],m.key)
        seen[m.key]=true
        at[m.key]=i
        assert(#m.at==3 and type(m.yaw)=='number' and m.level:find('^MXIII_Z%d_'),m.key)
        if m.cls=='barrel' then
            assert(m.alias=='ME_01_ZEA_001' and m.delay[1]==2.0 and m.delay[2]==2.5 and m.save==nil,m.key)
        elseif m.cls=='box2' then
            assert(m.alias=='ME_01_ZEA_007',m.key)
        else
            assert(m.cls=='box1' and (m.alias=='ME_01_ZEA_003' or m.alias=='ME_01_ZEA_007'),m.key)
        end
        assert((m.proxy_in_cook==false)==(m.key==R23),m.key)
    end
    assert(#Rows.BREAK==317,#Rows.BREAK)
    assert(at.Z4_LIFE_BRK_Z4R21_D_BP_Destruction_Box_02_05<at.Z4_LIFE_BRK_Z4R21_D_BP_Destruction_Box_01_68_Plus,
        'The lower box first')
    local r=Rows.BREAK[at[R23]]
    assert(r.level=='MXIII_Z1_Life' and r.at[1]==33806.648 and r.at[2]==31317.418 and r.at[3]==-2469.754
        and r.yaw==-95 and r.gates=='DLC02_10_E_ItemS_015','The R23 box')
end
print('matrix13/world/breakables_test: ok')
