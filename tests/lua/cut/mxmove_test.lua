-- cut/mxmove.lua with fake UE4SS objects: outside world 2800 nothing; in it, once a world, every ladder, ledge and
-- rope of the MOVE list spawned by the deferred pair (BeginDeferredActorSpawnFromClass, then the ladder's Meshes,
-- StartUnit and CollisionBottomZAdd, the ledge's mesh, the rope's drop and EnvActorName set before
-- FinishSpawningActor, at its point with its yaw; never the ladder's TotalHeight, the construction script's running
-- sum, nor the head values it writes), one [MXMOVE] line each, a ladder's with the TotalHeight it built, and a count;
-- a class or mesh not in memory
-- loaded first; nothing again in the same world, all again in a new one. When the deferred call fails, that spawn and
-- every later one go through SpawnActor and the construction script (TotalHeight back to 0 before it), and the line
-- says so. The MOVE list: each ladder's height is its Meshes stack plus the head, the ledges carry 006_B_SM,
-- the ropes and gate 435's ladder name their rows. The fake Meshes array zeroes its values when it grows (UE4SS #436),
-- so a stack filled front to back would read 0,3.
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
    return o
end
-- A TArray as UE4SS 3.0.1 may treat it (#436): a write past the end resizes it and zeroes every value already in it.
local function tarray()
    local v,n={},0
    return setmetatable({},{__index=function(_,i) return v[i] end,__len=function() return n end,
        __newindex=function(_,i,x)
            if i>n then
                for k=1,i do v[k]=0 end
                n=i
            end
            v[i]=x
        end})
end
local world_name='World /Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P.MXIII_P'
local spawned,worlds={},{}
local function new_world()
    local w=object({GetFullName=function() return world_name end})
    w.SpawnActor=function(_,class,at,rot)
        -- Spawned, its script has run once with no Meshes: the head alone.
        local a=object({class=class,at=at,rot=rot,how='SpawnActor',Meshes=tarray(),TotalHeight=79.885})
        -- Like the game's script: the stack starts at TotalHeight and adds to it (L1's 600+600 and head).
        a.UserConstructionScript=function(self) self.rerun=true; self.TotalHeight=self.TotalHeight+1279.885 end
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
        in_deferred=false
        a.finished,a.height_at_finish,a.meshes_at_finish=t,a.TotalHeight,#a.Meshes
        if a.class.path:find('BP_EM_Ladder') then a.TotalHeight=(a.TotalHeight or 0)+1279.885 end
        return a
    end})
local km=object({MakeTransform=function(_,at,rot,scale) return {at=at,rot=rot,scale=scale} end})
local loaded,classes={},{}
StaticFindObject=function(path)
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
local M=require('cut.mxmove')
local Rows=require('cut.mxiii_rows')
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
    and ladder.rot.Yaw==175 and ladder.meshes_at_finish==2 and ladder.Meshes[1]==3 and ladder.Meshes[2]==3
    and ladder.StartUnit==2
    and ladder.CollisionBottomZAdd==-75 and ladder.height_at_finish==nil and ladder.HeadHeight==nil
    and ladder.HeadWidthHalf==nil and ladder.CollisionWidth==nil and ladder.EnvActorName==nil,
    'The ladder: its stack (no piece zeroed by the growth) and foot set before the finish, TotalHeight left alone')
assert(ledge.how=='deferred' and ledge.TotalHeight==nil and ledge.finished and ledge.meshes_at_finish==1
    and ledge.Meshes[1]==classes[MESH],'The ledge: the climbing mesh')
assert(rope.class.path==M.ASSETS.rope..'_C' and rope.RopeDistanceB==1200 and rope.EnvActorName.name=='DLC02_10_EnvS_642'
    and rope.finished,'The rope: its drop and its row')
assert(lines[1]=='ladder L1 at 10 20 30 yaw 175 height 1279.9 stack 3,3 built 1279.9 (critical), deferred spawn',
    lines[1])
assert(lines[2]=='ledge E1 at 1 2 3 yaw 85 (climb_R16), deferred spawn',lines[2])
assert(lines[3]=='rope R1 at 4 5 6 yaw -95 drop 1200 env DLC02_10_EnvS_642 (critical), deferred spawn',lines[3])
assert(lines[4]=='3/3 ladders, ledges and ropes spawned in world 2800',lines[4])
clock=2.0; mv.tick()
assert(#spawned==3 and #lines==4,'Once a world')
-- A new world (a reload, a travel back): all again; the deferred call failing: SpawnActor and the script again.
world=new_world()
deferred_fails=true
clock=3.0; mv.tick()
assert(#spawned==6 and spawned[4].how=='SpawnActor' and spawned[4].rerun and spawned[4].Meshes[1]==3 and spawned[4].Meshes[2]==3
    and spawned[5].how=='SpawnActor','SpawnActor with the fields, then the construction script')
assert(lines[5]:find('^deferred spawn failed %(.*no such function%): SpawnActor and the construction script from now '
    ..'on$'),lines[5])
assert(lines[6]=='ladder L1 at 10 20 30 yaw 175 height 1279.9 stack 3,3 built 1279.9 (critical), SpawnActor, '
    ..'construction script run again',
    lines[6])
deferred_fails=false
world=new_world()
clock=4.0; mv.tick()
assert(spawned[7].how=='SpawnActor','The fallback stays for the Lua load')
-- A class that does not load: its line says so, the others still spawn.
world=new_world()
loaded,classes={},{}
LoadAsset=function(path)
    assert(not in_deferred,'LoadAsset inside a deferred spawn: '..path)
    if path==M.ASSETS.ledge or path==MESH then loaded[path]=true end
end
clock=5.0; mv.tick()
assert(lines[#lines]=='1/3 ladders, ledges and ropes spawned in world 2800',lines[#lines])
assert(lines[#lines-3]:find('^ladder L1 not spawned: .*BP_EM_Ladder_C does not load'),lines[#lines-3])
assert(lines[#lines-1]:find('^rope R1 not spawned: .*Env_EM_VerticalRope_C does not load'),lines[#lines-1])

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
assert(#ladders==41 and ledges==4 and critical>20,#ladders..' '..ledges..' '..critical)
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
print('mxmove_test: ok')
