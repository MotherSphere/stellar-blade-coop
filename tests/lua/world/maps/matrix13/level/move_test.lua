-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- world/maps/matrix13/level/move.lua with fake UE4SS objects: outside world 2800 nothing; in it, once a world, every
-- ladder, ledge and rope of the MOVE list spawned by the deferred pair (BeginDeferredActorSpawnFromClass, then the
-- ladder's Meshes, StartUnit and CollisionBottomZAdd, the ledge's mesh, the rope's drop and EnvActorName set before
-- FinishSpawningActor, at its point with its yaw; never the ladder's TotalHeight, the construction script's running
-- sum, nor the head values it writes), one [MXMOVE] line per class with the ways taken, the spread and a count, and a
-- line of its own only for an entry not spawned, one whose construction script did not run again after SpawnActor, or
-- a ladder whose built TotalHeight is not its listed height;
-- one entry a tick or more while BUDGET lasts, in list order, the ledge mesh never held from one tick to the next; a
-- class or mesh not in memory loaded first; nothing again in the same world, all again in a new one. When the deferred
-- call fails, that spawn and every later one go through SpawnActor and the construction script (TotalHeight back to 0
-- before it), and the line says so. The MOVE list: each ladder's height is its Meshes stack plus the head, the ledges
-- carry 006_B_SM, the ropes and gate 435's ladder name their rows. The fake Meshes array writes like UE4SS 3.0.1 (a
-- write past the end grows it to index-1 and loses the value), so the fill from the last piece, which read every
-- multi-piece stack back a piece short in game on 2026-10-30, reads 3,3 as 3 here too. A stack that reads back wrong is
-- emptied and filled front to back (a fixed UE4SS's way); one that still reads wrong spawns nothing for that ladder,
-- and says so.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
local next_address=0x1000
local function object(fields)
    next_address=next_address+0x100
    local at,o=next_address,fields or {}
    o.type=function() return 'UObject' end
    o.IsValid=o.IsValid or function(self) return not self.destroyed end
    o.GetAddress=function() return at end
    o.K2_DestroyActor=function(self) self.destroyed=true end
    return o
end
-- A TArray of the deferred ladder's Meshes. '3.0.1': UE4SS 3.0.1's index access (LuaTArray.cpp prepare_to_handle,
-- reads and writes alike): an index past the end grows the array to index-1 (index 1 of the empty array grows it to
-- 1), and the value lands only inside the array. This fits all 41 stacks the 2026-10-30 23:03 UE4SS.log read back;
-- a write at Num+1 into a non-empty array is lost here, the stricter of the two readings the log allows.
-- 'fixed': a write past the end grows the array to that index and lands (UE4SS 4.0). 'broken': nothing past 1 lands.
local tarray_kind='3.0.1'
local function tarray()
    local v,n,kind={},0,tarray_kind
    local function reach(i)
        if kind=='3.0.1' and (i-1>n or n==0) then
            local grow=i==1 and 1 or i-1-n
            for k=n+1,n+grow do v[k]=0 end
            n=n+grow
        elseif kind=='fixed' and i>n then
            for k=n+1,i do v[k]=0 end
            n=i
        elseif kind=='broken' and n==0 then
            v[1],n=0,1
        end
        return i<=n
    end
    local methods={GetArrayNum=function() return n end,Empty=function() v,n={},0 end}
    return setmetatable({},{__len=function() return n end,
        __index=function(_,i)
            if methods[i] then return methods[i] end
            return reach(i) and v[i] or nil
        end,
        __newindex=function(_,i,x) if reach(i) then v[i]=x end end})
end
local world_name='World /Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P.MXIII_P'
local spawned,worlds={},{}
local script_fails=false -- The construction script run again after SpawnActor raises.
local function new_world()
    local w=object({GetFullName=function() return world_name end})
    w.SpawnActor=function(_,class,at,rot)
        -- Spawned, its script has run once with no Meshes: the head alone.
        local a=object({class=class,at=at,rot=rot,how='SpawnActor',Meshes=tarray(),TotalHeight=79.885})
        -- Like the game's script: the stack starts at TotalHeight and adds to it (L1's 600+600 and head).
        a.UserConstructionScript=function(self)
            if script_fails then error('no such function') end
            self.rerun=true; self.TotalHeight=self.TotalHeight+1279.885
        end
        spawned[#spawned+1]=a
        return a
    end
    worlds[#worlds+1]=w
    return w
end
local world=new_world()
-- Like UE4SS, every GetWorld call gives a new wrapper of the same world (same address).
local function wrapper(w) return setmetatable({},{__index=w}) end
local eve=object({IsA=function() return true end,GetWorld=function() return wrapper(world) end})
package.loaded.UEHelpers={GetPlayer=function() return eve end,GetPlayerController=function() return nil end}
local deferred_fails=false
local spawn_cost=0 -- Seconds a spawn moves the clock: 0 outside the pacing cases.
local in_deferred=false -- Between BeginDeferredActorSpawnFromClass and FinishSpawningActor.
local gs=object({
    BeginDeferredActorSpawnFromClass=function(_,ctx,class,t,how,owner)
        assert(ctx==eve and how==1 and owner==nil)
        if deferred_fails then error('no such function') end
        in_deferred=true
        local a=object({class=class,at=t.at,rot=t.rot,how='deferred',Meshes=tarray()})
        spawned[#spawned+1]=a
        return a
    end,
    FinishSpawningActor=function(_,a,t)
        clock=clock+spawn_cost
        in_deferred=false
        a.finished,a.height_at_finish,a.meshes_at_finish=t,a.TotalHeight,#a.Meshes
        if a.class.path:find('BP_EM_Ladder') then a.TotalHeight=(a.TotalHeight or 0)+1279.885 end
        return a
    end})
local km=object({MakeTransform=function(_,at,rot,scale) return {at=at,rot=rot,scale=scale} end})
local loaded,classes={},{}
local find_cost=0 -- Seconds a class lookup moves the clock: UE4SS's StaticFindObject walk.
StaticFindObject=function(path)
    if path:find('_C$') then clock=clock+find_cost end
    if path=='/Script/Engine.Default__GameplayStatics' then return gs end
    if path=='/Script/Engine.Default__KismetMathLibrary' then return km end
    if path=='/Script/SB.SBCharacter' then return object({}) end
    if loaded[path] then
        classes[path]=classes[path] or object({path=path})
        return classes[path]
    end
    if path:find('_C$') and loaded[path:sub(1,-3)] then
        classes[path]=classes[path] or object({path=path})
        return classes[path]
    end
    return nil
end
LoadAsset=function(path) assert(not in_deferred,'LoadAsset inside a deferred spawn: '..path); loaded[path]=true end
FName=function(t) return {name=t} end
local M=require('world.maps.matrix13.level.move')
local Rows=require('world.maps.matrix13.level.rows')
local lines={}
local MESH='/Game/Art/BG/Actor/Interaction/Climbing/006_B_SM.006_B_SM'
local list={
    {key='L1',cls='ladder',at={10,20,30},yaw=175,height=1279.885,meshes={3,3},start=2,bottom=-75,role='critical'},
    {key='E1',cls='ledge',at={1,2,3},yaw=85,mesh=MESH,role='climb_R16'},
    {key='R1',cls='rope',at={4,5,6},yaw=-95,drop=1200,env='DLC02_10_EnvS_642',role='critical'},
}
local mv=M.new({log=function(m) lines[#lines+1]=m end,list=list})

-- Not in world 2800: nothing.
world_name='World /Game/Art/BG/WorldMap/Dungeon_P/Matrix_XI.Matrix_XI'
mv.tick()
assert(#spawned==0 and #lines==0,'Outside Matrix XIII: nothing')
world_name='World /Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P.MXIII_P'
clock=0.5; mv.tick(); assert(#spawned==0,'Once a second')
clock=1.0; mv.tick()
assert(#spawned==3 and loaded[M.ASSETS.ladder] and loaded[M.ASSETS.ledge] and loaded[M.ASSETS.rope] and loaded[MESH],
    'Every class and the mesh loaded, all spawned')
local ladder,ledge,rope=spawned[1],spawned[2],spawned[3]
assert(ladder.how=='deferred' and ladder.class.path==M.ASSETS.ladder..'_C' and ladder.at.X==10 and ladder.at.Z==30
    and ladder.rot.Yaw==175 and ladder.meshes_at_finish==2 and ladder.Meshes[1]==5 and ladder.Meshes[2]==5
    and ladder.StartUnit==2
    and ladder.CollisionBottomZAdd==-75 and ladder.height_at_finish==nil and ladder.HeadHeight==nil
    and ladder.HeadWidthHalf==nil and ladder.CollisionWidth==nil and ladder.EnvActorName==nil,
    'The ladder: its whole stack and foot set before the finish, TotalHeight left alone')
assert(ledge.how=='deferred' and ledge.TotalHeight==nil and ledge.finished and ledge.meshes_at_finish==1
    and ledge.Meshes[1]==classes[MESH],'The ledge: the climbing mesh')
assert(rope.class.path==M.ASSETS.rope..'_C' and rope.RopeDistanceB==1200 and rope.EnvActorName.name=='DLC02_10_EnvS_642'
    and rope.finished,'The rope: its drop and its row')
-- A spawn as listed (the ladder built to its height) has no line of its own: its class line counts it.
assert(lines[1]=='ladder: 1/1 spawned, 1 deferred spawn',lines[1])
assert(lines[2]=='ledge: 1/1 spawned, 1 deferred spawn',lines[2])
assert(lines[3]=='rope: 1/1 spawned, 1 deferred spawn',lines[3])
assert(lines[4]=='spread over 1 tick in 0.0 s, the longest 0 ms, lookups 0 ms in all',lines[4])
assert(lines[5]=='3/3 ladders, ledges and ropes spawned in world 2800' and #lines==5,lines[5])
clock=2.0; mv.tick()
assert(#spawned==3 and #lines==5,'Once a world')
-- A new world (a reload, a travel back): all again; the deferred call failing: SpawnActor and the script again.
world=new_world()
deferred_fails=true
clock=3.0; mv.tick()
assert(#spawned==6 and spawned[4].how=='SpawnActor' and spawned[4].rerun and spawned[4].Meshes[1]==5 and spawned[4].Meshes[2]==5
    and spawned[5].how=='SpawnActor','SpawnActor with the fields, then the construction script')
assert(lines[6]:find('^deferred spawn failed %(.*no such function%): SpawnActor and the construction script from now '
    ..'on$'),lines[6])
assert(lines[7]=='ladder: 1/1 spawned, 1 SpawnActor, construction script run again',lines[7])
deferred_fails=false
world=new_world()
-- A construction script that does not run again: every entry keeps its own line with its key, the ladder's built 0.
script_fails=true
local said=#lines
clock=4.0; mv.tick()
script_fails=false
assert(spawned[7].how=='SpawnActor','The fallback stays for the Lua load')
assert(lines[said+1]=='ladder L1 at 10 20 30 yaw 175 height 1279.9 stack 5,5 built 0.0 (critical), SpawnActor, '
    ..'construction script not run',lines[said+1])
assert(lines[said+2]=='ledge E1 at 1 2 3 yaw 85 (climb_R16), SpawnActor, construction script not run',lines[said+2])
assert(lines[said+3]=='rope R1 at 4 5 6 yaw -95 drop 1200 env DLC02_10_EnvS_642 (critical), SpawnActor, construction '
    ..'script not run',lines[said+3])
assert(lines[said+5]=='ledge: 1/1 spawned, 1 SpawnActor, construction script not run',lines[said+5])
-- A class that does not load: its line says so, the others still spawn.
world=new_world()
loaded,classes={},{}
LoadAsset=function(path)
    assert(not in_deferred,'LoadAsset inside a deferred spawn: '..path)
    if path==M.ASSETS.ledge or path==MESH then loaded[path]=true end
end
clock=5.0; mv.tick()
assert(lines[#lines]=='1/3 ladders, ledges and ropes spawned in world 2800',lines[#lines])
assert(lines[#lines-6]:find('^ladder L1 not spawned: .*BP_EM_Ladder_C does not load'),lines[#lines-6])
assert(lines[#lines-5]:find('^rope R1 not spawned: .*Env_EM_VerticalRope_C does not load'),lines[#lines-5])
assert(lines[#lines-4]=='ladder: 0/1 spawned' and lines[#lines-2]=='rope: 0/1 spawned',lines[#lines-4])

-- A UE4SS whose arrays grow to the index written: the first fill reads one piece long, the refill front to back holds.
-- One whose writes past the first never land: that ladder is destroyed before its finish, named, and the deferred way
-- stays for the others.
do
    local function one(kind,meshes)
        world=new_world()
        loaded,classes={},{}
        LoadAsset=function(path) loaded[path]=true end
        tarray_kind=kind
        local got={}
        local before=#spawned
        local mv4=M.new({log=function(l) got[#got+1]=l end,list={
            {key='L2',cls='ladder',at={0,0,0},yaw=0,height=999,meshes=meshes,start=1,bottom=55,role='test'},
            {key='L3',cls='ladder',at={0,0,0},yaw=0,height=279.885,meshes={1},start=1,bottom=55,role='test'}}})
        clock=clock+10; mv4.tick()
        tarray_kind='3.0.1'
        return got,spawned[before+1],spawned[before+2]
    end
    local got,a=one('fixed',{3,3,2})
    assert(got[1]=='ladder L2 at 0 0 0 yaw 0 height 999.0 stack 5,5,4 (first fill read stack 5,5,4,4, filled again '
        ..'front to back) built 1279.9 (test), deferred spawn',got[1])
    assert(got[3]=='ladder: 2/2 spawned, 2 deferred spawn; 1 stack filled again front to back',got[3])
    assert(a.finished and a.Meshes:GetArrayNum()==3,'The refilled stack reaches the finish')
    local got2,b,c=one('broken',{3,3})
    assert(got2[1]=='ladder L2 not spawned: Meshes read back stack 5, then stack 5, for 5,5: nothing spawned',got2[1])
    assert(b.destroyed and not b.finished,'The ladder that would not fill is destroyed before its finish')
    assert(c.how=='deferred' and c.finished and got2[2]:find('deferred spawn$'),'The next ladder still spawns deferred')
    assert(got2[3]=='ladder: 1/2 spawned, 1 deferred spawn',got2[3])
    assert(got2[5]=='1/2 ladders, ledges and ropes spawned in world 2800',got2[5])
end

-- The generated list: every ladder's height is its stack plus the head (StartUnit k with CollisionBottomZAdd 5 - 40 k,
-- or the defaults 1 and 55; tests/tools/mxiii_climb_test.py checks where the pieces land); the ledges are R16's with
-- the climbing mesh; the two ropes and gate 435's ladder name their rows.
local PIECE={[0]=160.909,[1]=200,[2]=240,[3]=600,[11]=40.909}
local ladders,critical,ledges,envs={},0,0,{}
for _,m in ipairs(Rows.MOVE) do
    assert(#m.at==3 and type(m.yaw)=='number' and m.key and m.role,m.key)
    if m.env then envs[m.key]=m.env end
    if m.cls=='ladder' then
        ladders[#ladders+1]=m.key
        local sum=79.885
        for _,k in ipairs(m.meshes) do sum=sum+assert(PIECE[k],m.key) end
        assert(math.abs(sum-m.height)<0.01,m.key..' height '..m.height..', stack '..sum)
        assert((m.start==1 and m.bottom==55) or m.bottom==5-40*m.start,m.key)
        if m.role=='critical' then critical=critical+1 end
    elseif m.cls=='ledge' then
        assert(m.mesh==MESH and m.role=='climb_R16',m.key)
        ledges=ledges+1
    else
        assert(m.cls=='rope' and m.drop>0 and m.env,m.key)
    end
end
assert(#ladders==41 and ledges==5 and critical>20,#ladders..' '..ledges..' '..critical)
assert(envs.Rope_R28=='DLC02_10_EnvS_642' and envs.Rope_Z4=='DLC02_40_EnvS_022'
    and envs.R20_LadderGate435=='DLC02_10_EnvS_437','The rows the ropes and the gate ladder bind')
-- A ledge whose mesh is not in memory yet: it loads before the deferred pair, never between Begin and Finish (an asset
-- load there crashed the game on 2026-10-30).
do
    world=new_world()
    loaded,classes={},{}
    loaded[M.ASSETS.ledge]=true
    LoadAsset=function(path) assert(not in_deferred,'LoadAsset inside a deferred spawn: '..path); loaded[path]=true end
    local before=#spawned
    local mv3=M.new({log=function() end,list={{cls='ledge',key='E9',at={0,0,0},yaw=0,role='test',mesh=MESH}}})
    clock=clock+10; mv3.tick()
    assert(#spawned==before+1,'one actor spawned: '..(#spawned-before))
    local a=spawned[#spawned]
    assert(a.how=='deferred' and a.finished and a.Meshes[1],'the ledge spawned by the deferred pair, its mesh set')
end
-- Matrix XIII, another map, Matrix XIII again in one Lua load: the game unloads the ledge mesh in between, so the mesh
-- is found again in the new world, never the freed object of the first (that read crashed the game on 2026-11-03).
do
    world=new_world()
    loaded,classes={},{}
    loaded[M.ASSETS.ledge]=true
    LoadAsset=function(path) assert(not in_deferred,'LoadAsset inside a deferred spawn: '..path); loaded[path]=true end
    local mv4=M.new({log=function() end,list={{cls='ledge',key='E8',at={0,0,0},yaw=0,role='test',mesh=MESH}}})
    clock=clock+10; mv4.tick()
    local first=spawned[#spawned].Meshes[1]
    assert(first and first==classes[MESH],'first world: the mesh set')
    world_name='World /Game/Art/BG/WorldMap/E05_GreatDesert_P/E05_GreatDesert_P.E05_GreatDesert_P'
    clock=clock+10; mv4.tick()
    loaded[MESH],classes[MESH]=nil,nil -- Unloaded with the map: the old object is gone.
    world_name='World /Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P.MXIII_P'
    world=new_world()
    clock=clock+10; mv4.tick()
    local again=spawned[#spawned].Meshes[1]
    assert(again and again~=first and again==classes[MESH] and loaded[MESH],'back in Matrix XIII: the mesh found again')
end
-- The spread: one spawn a tick when it costs more than BUDGET (10 to 13 ms in game), the next one on the next tick (not
-- a second later), list order kept, the class lines, the spread and the count after the last; a world left in the
-- middle stops it with a line of what it spawned so far, a new one starts it over.
do
    world=new_world()
    loaded,classes={},{}
    LoadAsset=function(path) assert(not in_deferred,'LoadAsset inside a deferred spawn: '..path); loaded[path]=true end
    local got={}
    local before=#spawned
    local mv5=M.new({log=function(l) got[#got+1]=l end,list=list})
    spawn_cost=0.011
    clock=clock+10
    -- tick says whether it spawned, so world/maps/matrix13/level/travel.lua holds the boxes back for that frame.
    local busy=mv5.tick()
    assert(busy==true and #spawned==before+1 and spawned[#spawned].class.path==M.ASSETS.ladder..'_C' and #got==0,
        'one a tick')
    busy=mv5.tick()
    assert(busy==true and #spawned==before+2 and spawned[#spawned].class.path==M.ASSETS.ledge..'_C',
        'the next tick at once')
    world_name='World /Game/Art/BG/WorldMap/E05_GreatDesert_P/E05_GreatDesert_P.E05_GreatDesert_P'
    busy=mv5.tick()
    assert(busy==nil and #spawned==before+2 and #got==1,'another map: nothing more')
    assert(got[1]=='spread stopped after 2/3 entries (world 2800 left): 2 spawned',got[1])
    world_name='World /Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P.MXIII_P'
    world=new_world()
    -- A class lookup of 2 ms: the ladder's and ledge's classes are in memory (one walk each), the rope's is loaded
    -- first (two), 8 ms in all, counted in the ticks too.
    find_cost=0.002
    clock=clock+10; mv5.tick(); mv5.tick(); busy=mv5.tick()
    find_cost=0
    assert(busy==true and #spawned==before+5 and spawned[#spawned].class.path==M.ASSETS.rope..'_C',
        'started over: '..(#spawned-before))
    assert(mv5.tick()==nil,'done: nothing spawned, the boxes may go')
    assert(got[2]=='ladder: 1/1 spawned, 1 deferred spawn' and got[5]=='spread over 3 ticks in 0.0 s, the longest 15 ms, lookups 8 ms in all'
        and got[6]=='3/3 ladders, ledges and ropes spawned in world 2800' and #got==6,got[5])
    -- The ledge mesh is found again on each spawning tick: a world reloaded at the same address between two ticks
    -- frees it, and a held one would be read.
    world=new_world()
    local mv6=M.new({log=function() end,list={{cls='ledge',key='E6',at={0,0,0},yaw=0,role='test',mesh=MESH},
        {cls='ledge',key='E7',at={0,0,0},yaw=0,role='test',mesh=MESH}}})
    clock=clock+10; mv6.tick()
    local first=spawned[#spawned].Meshes[1]
    classes[MESH]=nil -- The next lookup gives another object.
    mv6.tick()
    local again=spawned[#spawned].Meshes[1]
    assert(#spawned==before+7 and again and again~=first and again==classes[MESH],
        'the second tick: the mesh found again')
    spawn_cost=0
end
-- A spread cut short by a new world address, or by its first spawn gone (a reload at the same address frees it), says
-- what it spawned so far, then starts over.
do
    world=new_world()
    local got={}
    local mv7=M.new({log=function(l) got[#got+1]=l end,list=list})
    spawn_cost=0.011
    clock=clock+10; mv7.tick()
    world=new_world()
    mv7.tick()
    assert(got[1]=='spread stopped after 1/3 entries (new world): 1 spawned' and #got==1,tostring(got[1]))
    spawned[#spawned].destroyed=true
    mv7.tick()
    assert(got[2]=='spread stopped after 1/3 entries (first spawn gone): 1 spawned' and #got==2,tostring(got[2]))
    spawn_cost=0
end
-- The keep: the three classes and the ledge's mesh wanted when Move is made; nothing spawned before the keep settles;
-- once settled one find each for the game run, no lookup of a kept path and no LoadAsset, a second world included.
do
    local Keep=require('core.keep')
    local keep_fake=dofile('tests/lua/core/keep_fake.lua')
    local finds_k={}
    local kf=keep_fake(function(p)
        finds_k[#finds_k+1]=p
        -- An earlier section's lookup may have made it: the keep reads its full name.
        classes[p]=classes[p] or object({path=p})
        classes[p].GetFullName=function() return 'Object '..p end
        return classes[p],true
    end)
    local mk=M.new({log=function() end,list={
        {key='KL',cls='ladder',at={10,20,30},yaw=175,height=1279.885,meshes={3,3},start=2,bottom=-75,role='critical'},
        {key='KE',cls='ledge',at={1,2,3},yaw=85,mesh=MESH,role='climb_R16'}}})
    for _,p in pairs(M.ASSETS) do assert(Keep.wanted(p..'_C'),p) end
    assert(Keep.wanted(MESH))
    local saved=LoadAsset
    local loads=0
    LoadAsset=function() loads=loads+1 end
    Keep.slow()
    local count=#spawned
    world=new_world(); clock=clock+10; mk.tick(); mk.tick()
    assert(#spawned==count and not Keep.ready())
    kf.settle()
    local saved_find=StaticFindObject
    StaticFindObject=function(p) assert(not Keep.wanted(p),'A kept path looked up: '..p); return saved_find(p) end
    clock=clock+10; mk.tick(); mk.tick()
    assert(#spawned==count+2 and #finds_k==4 and loads==0,#finds_k)
    world=new_world(); clock=clock+10; mk.tick(); mk.tick()
    assert(#spawned==count+4 and #finds_k==4 and loads==0,'Held across a second world')
    StaticFindObject,LoadAsset=saved_find,saved
    Keep.reset()
end

-- done(world) and tick(budget), as breakables'.
do
    local md=M.new({log=function() end,list={
        {key='KE1',cls='ledge',at={1,2,3},yaw=85,mesh=MESH,role='climb_R16'},
        {key='KE2',cls='ledge',at={4,5,6},yaw=85,mesh=MESH,role='climb_R16'}}})
    world=new_world(); clock=clock+10
    local w=world:GetAddress()
    md.tick(0)
    assert(not md.done(w),'One of two spawned')
    md.tick(0)
    assert(md.done(w) and not md.done(w+1),'Both spawned in this world')
end
print('world/maps/matrix13/level/move_test: ok')
