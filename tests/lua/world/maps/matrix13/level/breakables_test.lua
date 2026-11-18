-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- world/maps/matrix13/level/breakables.lua with fake UE4SS objects: outside world 2800 nothing; in it, once a world,
-- one FindAllOf('StaticMeshActor') pass on its own tick, then one entry a tick or more while BUDGET lasts, each with
-- its proxy's collision off and the proxy hidden before the deferred spawn, the class loaded before Begin, the alias
-- and a barrel's fuse set between Begin and Finish, and no save type written; a [MXBREAK] line of its own only for an
-- entry that did not spawn as listed, then one per class, the spread and the total. A failed spawn gives the proxy
-- back; a missing proxy spawns nothing; an entry with proxy_in_cook=false spawns with no lookup. World 2800 loaded
-- again at the same address during the spread (its real time going back): the list starts over on a new proxy pass. A
-- box that breaks and destroys itself brings no second spawn; a new world spawns all again. The BREAK list: Matrix 11's
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
-- born: the clock when the world started, its real time 0 (GetRealTimeSeconds gives 0.5 s more, never 0).
local function new_world() world=object({born=clock,GetFullName=function() return world_name end}) end
new_world()
local function wrapper(w) return setmetatable({},{__index=w}) end
local eve=object({IsA=function() return true end,GetWorld=function() return wrapper(world) end})
package.loaded.UEHelpers={GetPlayer=function() return eve end,GetPlayerController=function() return nil end}
-- A proxy: a tagged StaticMeshActor, solid and shown.
local function proxy(name,tag)
    return object({name=name,collision=true,hidden=false,
        GetFName=function() return name end,
        ActorHasTag=function(_,t) return tag and t.name=='MXIII_BREAK' end,
        SetActorEnableCollision=function(self,on,fast)
            assert(fast==false,'SB wants inFastUpdate too: UE4SS refuses the call with one argument')
            self.collision=on; events[#events+1]=(on and 'solid ' or 'clear ')..name end,
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
local spawn_cost=0 -- Seconds a spawn moves the clock: 0 outside the pacing cases.
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
    GetRealTimeSeconds=function(_,ctx)
        assert(ctx==eve)
        return clock-world.born+0.5
    end,
    FinishSpawningActor=function(_,a,t)
        clock=clock+spawn_cost
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
local find_cost=0 -- Seconds a class lookup moves the clock: UE4SS's StaticFindObject walk.
StaticFindObject=function(path)
    finds=finds+1
    if path:find('_C$') then clock=clock+find_cost end
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
local B=require('world.maps.matrix13.level.breakables')
local Rows=require('world.maps.matrix13.level.rows')

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
-- A failed spawn: the proxy restored. A spawn as listed (A: the alias asked, the proxy hidden) has no line of its own.
assert(events[5]=='clear BAD' and events[6]=='hide BAD' and events[7]=='solid BAD' and events[8]=='show BAD',
    table.concat(events,', '))
assert(pbad.collision and not pbad.hidden,'The proxy is back')
assert(lines[1]:find('^box2 BAD %(MXIII_Z1_Life%) not spawned: .*no such function, proxy restored$'),lines[1])
-- The barrel: its fuse, no save type.
local c=spawned[2]
assert(c.key=='C' and c.class.path==B.ASSETS.barrel..'_C' and c.ZoneEventActorTableAlias.name=='ME_01_ZEA_001'
    and c.DestructionDelayMinTime==2.0 and c.DestructionDelayMaxTime==2.5 and c.ZoneEventActorSaveType==nil,
    'The barrel: its alias and fuse')
-- R23: no proxy lookup, spawned alone.
local r=spawned[3]
assert(r.key=='R23' and r.finished and events[13]=='begin R23' and #events==14,table.concat(events,', '))
assert(lines[2]=='box1 R23 (MXIII_Z1_Life) at 4 2 3 yaw -95 alias ME_01_ZEA_003, no proxy in the cook, gates '
    ..'DLC02_10_E_ItemS_015',lines[2])
-- A proxy not found (no tag): nothing spawned.
assert(lines[3]=='box1 LOST (MXIII_Z1_Life) not spawned: no proxy LOST in MXIII_Z1_Life',lines[3])
assert(lines[4]=='box1: 2/3 spawned, 1 with the alias asked and the proxy hidden',lines[4])
assert(lines[5]=='box2: 0/1 spawned, 0 with the alias asked and the proxy hidden',lines[5])
assert(lines[6]=='barrel: 1/1 spawned, 1 with the alias asked and the proxy hidden',lines[6])
assert(lines[7]=='spread over 1 tick in 0.0 s, the longest 0 ms, lookups 0 ms in all',lines[7])
assert(lines[8]=='3/5 boxes and barrels spawned in world 2800, 2 proxies hidden' and #lines==8,lines[8])
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
assert(walks==2 and spawned[#spawned].key=='R23' and #lines==said+8,'A new world spawns all again')

-- The tick spreading: one entry a tick when a spawn costs more than BUDGET (8 to 13 ms in game), more while the budget
-- lasts, and an entry that spawns nothing costs nothing; list order kept, the failure's line when it comes, the class,
-- spread and total lines after the last.
do
    local many,props={},{}
    for i=1,7 do
        many[i]=entry('K'..i,'box1')
        if i~=5 then props[#props+1]=proxy('K'..i,true) end -- K5 has no proxy: it spawns nothing.
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
    spawn_cost=0.009
    b2.tick()
    assert(#spawned==count+1 and spawned[#spawned].key=='K1' and #got==0,'One 9 ms spawn a tick: '..(#spawned-count))
    spawn_cost=B.BUDGET*0.4
    b2.tick()
    assert(#spawned==count+4 and spawned[#spawned].key=='K4' and #got==0,'Three spawns of 0.4 BUDGET: '
        ..(#spawned-count))
    b2.tick() -- K5 (no cost), K6, K7: the list ends inside the budget.
    assert(#spawned==count+6 and spawned[#spawned].key=='K7','The rest')
    assert(got[1]=='box1 K5 (MXIII_Z1_Life) not spawned: no proxy K5 in MXIII_Z1_Life',got[1])
    assert(got[2]=='box1: 6/7 spawned, 6 with the alias asked and the proxy hidden',got[2])
    assert(got[3]=='spread over 3 ticks in 0.0 s, the longest 9 ms, lookups 0 ms in all',got[3])
    assert(got[4]=='6/7 boxes and barrels spawned in world 2800, 6 proxies hidden' and #got==4,got[4])
    clock=clock+1; b2.tick()
    assert(#spawned==count+6 and #got==4,'Done: nothing more')
    spawn_cost=0
end
-- The spread line's lookups: the time the class lookups took, counted against the budget too. Two 3 ms lookups: the
-- second entry still fits in the tick (3 ms spent), then the budget is gone.
do
    actors={proxy('L1',true)}
    fail_key=nil
    local got={}
    local b9=B.new({log=function(m) got[#got+1]=m end,list={entry('L1','box1'),entry('L2','box1',{proxy_in_cook=false})}})
    new_world()
    find_cost=0.003
    clock=clock+10; b9.tick(); b9.tick()
    find_cost=0
    assert(got[3]=='spread over 1 tick in 0.0 s, the longest 6 ms, lookups 6 ms in all' and #got==4,got[3])
end
-- A box whose alias reads back as another keeps its own line, with the alias it asked.
do
    actors={proxy('ODD',true)}
    fail_key=nil
    local got={}
    local b5=B.new({log=function(m) got[#got+1]=m end,list={entry('ODD','box1')}})
    local finish=gs.FinishSpawningActor
    gs.FinishSpawningActor=function(s,a,t) a.ZoneEventActorTableAlias=FName('ME_01_ZEA_007'); return finish(s,a,t) end
    new_world()
    clock=clock+10; b5.tick(); b5.tick()
    gs.FinishSpawningActor=finish
    assert(got[1]:find('^box1 ODD %(MXIII_Z1_Life%) at %S+ 2 3 yaw %-95 alias ME_01_ZEA_007 %(asked ME_01_ZEA_003%), '
        ..'proxy hidden$') and got[2]=='box1: 1/1 spawned, 0 with the alias asked and the proxy hidden',got[1])
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
-- Matrix XIII, another map, Matrix XIII again in one Lua load: a class the game unloaded in between is never touched
-- again (reading the freed object of the first world crashed the game on 2026-11-03), it is found anew.
do
    local held={}
    for path,c in pairs(classes) do held[#held+1]=c end
    actors={proxy('A',true)}
    fail_key=nil
    local b3=B.new({log=function() end,list={entry('A','box1')}})
    new_world()
    clock=clock+10; b3.tick(); b3.tick()
    local first=spawned[#spawned].class
    assert(first,'first world: a box spawned')
    world_name='World /Game/Art/BG/WorldMap/E05_GreatDesert_P/E05_GreatDesert_P.E05_GreatDesert_P'
    clock=clock+10; b3.tick()
    for path,c in pairs(classes) do c.IsValid=function() error('read of a freed object: '..path) end end
    loaded,classes={},{}
    world_name='World /Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P.MXIII_P'
    new_world()
    actors={proxy('A',true)}
    local before=#spawned
    clock=clock+10; b3.tick(); b3.tick()
    assert(#spawned==before+1 and spawned[#spawned].class~=first,'back in Matrix XIII: the class found anew')
end
-- World 2800 loaded again at the same address within the spawn spread (a death seconds after arriving) while the
-- world's real time does not read, so the reload goes unseen and the spread carries on with the proxies it holds. A
-- class of the freed world is never touched: it is found anew. A held proxy is read by name before use, and one whose
-- name no longer reads as its own (another object at its address) spawns nothing.
do
    local many={entry('S1','box1'),entry('S_ALONE','box1',{proxy_in_cook=false}),entry('S_LAST','box1')}
    local last=proxy('S_LAST',true)
    actors={proxy('S1',true),last}
    fail_key=nil
    local got={}
    local b4=B.new({log=function(m) got[#got+1]=m end,list=many})
    local read=gs.GetRealTimeSeconds
    gs.GetRealTimeSeconds=nil
    new_world()
    spawn_cost=0.009 -- One a tick.
    clock=clock+10; b4.tick(); b4.tick()
    local first=spawned[#spawned].class
    assert(#got==1 and got[1]:find('^no world time ') and spawned[#spawned].key=='S1' and first,
        'first world: one box spawned, the time said once not to read')
    for path,c in pairs(classes) do c.IsValid=function() error('read of a freed class: '..path) end end
    loaded,classes={},{}
    last.GetFName=function() return 'Other' end
    last.SetActorEnableCollision=function() error('call on a freed proxy') end
    last.SetActorHiddenInGame=last.SetActorEnableCollision
    local before=#spawned
    b4.tick()
    assert(#spawned==before+1 and spawned[#spawned].key=='S_ALONE' and spawned[#spawned].class~=first,
        'the class found anew')
    b4.tick()
    spawn_cost=0
    gs.GetRealTimeSeconds=read
    assert(got[2]:find('^box1 S_ALONE ') and got[3]=='box1 S_LAST (MXIII_Z1_Life) not spawned: no proxy S_LAST in '
        ..'MXIII_Z1_Life' and got[4]=='box1: 2/3 spawned, 1 with the alias asked and the proxy hidden',got[3])
end
-- World 2800 loaded again at the same address in the middle of the spread, EVE there on its first tick: its real time
-- goes back, so the old proxies are never touched again, a line says what the cut spread spawned, a new proxy pass runs
-- and the list starts over from its first entry. Once the list is done the time is not read.
do
    local many={entry('T1','box1'),entry('T2','box1'),entry('T3','box1')}
    local old={proxy('T1',true),proxy('T2',true),proxy('T3',true)}
    actors=old
    fail_key=nil
    local got={}
    local b6=B.new({log=function(m) got[#got+1]=m end,list=many})
    new_world()
    spawn_cost=0.009 -- One a tick.
    local passes=walks
    clock=clock+10; b6.tick(); b6.tick(); b6.tick()
    assert(walks==passes+1 and spawned[#spawned].key=='T2' and #got==0,'first load: T1 and T2 spawned')
    world.born=clock -- The same world object, its address unchanged: a new load.
    for _,x in ipairs(old) do
        x.GetFName=function() error('read of a freed proxy') end
        x.SetActorEnableCollision,x.SetActorHiddenInGame=x.GetFName,x.GetFName
    end
    local fresh={proxy('T1',true),proxy('T2',true),proxy('T3',true)}
    actors=fresh
    local before=#spawned
    b6.tick()
    assert(walks==passes+2 and #spawned==before,'the reload: a new proxy pass on its own tick')
    assert(got[1]=='world 2800 loaded again at the same address (real time 0.5 s, 10.5 s at the last tick): the list '
        ..'starts over',got[1])
    assert(got[2]=='spread stopped after 2/3 entries (loaded again): 2 spawned, 2 proxies hidden',got[2])
    b6.tick(); b6.tick(); b6.tick()
    assert(#spawned==before+3 and spawned[before+1].key=='T1' and spawned[before+3].key=='T3' and fresh[1].hidden
        and fresh[3].hidden,'all three spawned again on the new proxies')
    assert(got[3]=='box1: 3/3 spawned, 3 with the alias asked and the proxy hidden'
        and got[5]=='3/3 boxes and barrels spawned in world 2800, 3 proxies hidden' and #got==5,got[5])
    world.born=clock
    clock=clock+5; b6.tick()
    assert(#spawned==before+3 and #got==5,'done: a time going back no longer counts')
    spawn_cost=0
end
-- A spread cut short by leaving world 2800, or by a new world address, says what it spawned so far.
do
    actors={proxy('V1',true),proxy('V2',true),proxy('V3',true)}
    fail_key=nil
    local got={}
    local b10=B.new({log=function(m) got[#got+1]=m end,list={entry('V1','box1'),entry('V2','box1'),entry('V3','box1')}})
    new_world()
    spawn_cost=0.009 -- One a tick.
    clock=clock+10; b10.tick(); b10.tick()
    world_name='World /Game/Art/BG/WorldMap/Dungeon_P/Matrix_XI.Matrix_XI'
    b10.tick()
    assert(got[1]=='spread stopped after 1/3 entries (world 2800 left): 1 spawned, 1 proxies hidden' and #got==1,
        tostring(got[1]))
    world_name='World /Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P.MXIII_P'
    new_world()
    clock=clock+10; b10.tick(); b10.tick()
    new_world()
    b10.tick()
    assert(got[2]=='spread stopped after 1/3 entries (new world): 1 spawned, 1 proxies hidden' and #got==2,
        tostring(got[2]))
    spawn_cost=0
end
-- A real time that does not read: said once, and the spread runs as before on the world address alone.
do
    actors={proxy('U1',true),proxy('U2',true)}
    local got={}
    local b7=B.new({log=function(m) got[#got+1]=m end,list={entry('U1','box1'),entry('U2','box1')}})
    local read=gs.GetRealTimeSeconds
    gs.GetRealTimeSeconds=nil
    new_world()
    local before=#spawned
    clock=clock+10; b7.tick(); b7.tick()
    gs.GetRealTimeSeconds=read
    assert(#spawned==before+2 and got[1]:find('^no world time %(.*%): a reload at the same world address during the '
        ..'spread goes unseen$') and got[2]=='box1: 2/2 spawned, 2 with the alias asked and the proxy hidden',got[1])
    -- Something other than a number: said the same way.
    gs.GetRealTimeSeconds=function() return 'x' end
    local said={}
    local b8=B.new({log=function(m) said[#said+1]=m end,list={entry('U3','box1',{proxy_in_cook=false})}})
    new_world()
    clock=clock+10; b8.tick(); b8.tick()
    gs.GetRealTimeSeconds=read
    assert(said[1]=='no world time (it read x): a reload at the same world address during the spread goes unseen'
        and said[#said]=='1/1 boxes and barrels spawned in world 2800, 0 proxies hidden',said[1])
    -- 0, what the engine gives when the context has no world: said the same way.
    gs.GetRealTimeSeconds=function() return 0.0 end
    local zero={}
    local b11=B.new({log=function(m) zero[#zero+1]=m end,list={entry('U4','box1',{proxy_in_cook=false})}})
    new_world()
    clock=clock+10; b11.tick(); b11.tick()
    gs.GetRealTimeSeconds=read
    assert(zero[1]=='no world time (it read 0.0): a reload at the same world address during the spread goes unseen'
        and zero[#zero]=='1/1 boxes and barrels spawned in world 2800, 0 proxies hidden' and #zero==5,tostring(zero[1]))
end
print('world/maps/matrix13/level/breakables_test: ok')
