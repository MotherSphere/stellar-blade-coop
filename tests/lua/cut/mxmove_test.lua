-- cut/mxmove.lua with fake UE4SS objects: outside world 2800 nothing; in it, once a world, every ladder and ledge of
-- the MOVE list spawned by the deferred pair (BeginDeferredActorSpawnFromClass, the ladder's TotalHeight and head set
-- before FinishSpawningActor, at the foot with its yaw), one [MXMOVE] line each and a count; a class not in memory
-- loaded first; nothing again in the same world, all again in a new one. When the deferred call fails, that spawn and
-- every later one go through SpawnActor and the construction script, and the line says so. The MOVE list's ladders
-- all have a height, critical ladders included.
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
local world_name='World /Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P.MXIII_P'
local spawned,worlds={},{}
local function new_world()
    local w=object({GetFullName=function() return world_name end})
    w.SpawnActor=function(_,class,at,rot)
        local a=object({class=class,at=at,rot=rot,how='SpawnActor'})
        a.UserConstructionScript=function(self) self.rerun=true end
        spawned[#spawned+1]=a
        return a
    end
    worlds[#worlds+1]=w
    return w
end
local world=new_world()
local eve=object({IsA=function() return true end,GetWorld=function() return world end})
package.loaded.UEHelpers={GetPlayer=function() return eve end,GetPlayerController=function() return nil end}
local deferred_fails=false
local gs=object({
    BeginDeferredActorSpawnFromClass=function(_,ctx,class,t,how,owner)
        assert(ctx==eve and how==1 and owner==nil)
        if deferred_fails then error('no such function') end
        local a=object({class=class,at=t.at,rot=t.rot,how='deferred'})
        spawned[#spawned+1]=a
        return a
    end,
    FinishSpawningActor=function(_,a,t)
        a.finished,a.height_at_finish=t,a.TotalHeight
        return a
    end})
local km=object({MakeTransform=function(_,at,rot,scale) return {at=at,rot=rot,scale=scale} end})
local loaded,classes={},{}
StaticFindObject=function(path)
    if path=='/Script/Engine.Default__GameplayStatics' then return gs end
    if path=='/Script/Engine.Default__KismetMathLibrary' then return km end
    if path=='/Script/SB.SBCharacter' then return object({}) end
    if path:find('_C$') and loaded[path:sub(1,-3)] then
        classes[path]=classes[path] or object({path=path})
        return classes[path]
    end
    return nil
end
LoadAsset=function(path) loaded[path]=true end
local M=require('cut.mxmove')
local Rows=require('cut.mxiii_rows')
local lines={}
local list={
    {key='L1',cls='ladder',at={10,20,30},yaw=175,height=400,role='critical'},
    {key='E1',cls='ledge',at={1,2,3},yaw=85,role='climb_R16'},
}
local mv=M.new({log=function(m) lines[#lines+1]=m end,list=list})

-- Not in world 2800: nothing.
world_name='World /Game/Art/BG/WorldMap/Dungeon_P/Matrix_XI.Matrix_XI'
mv.tick()
assert(#spawned==0 and #lines==0,'Outside Matrix XIII: nothing')
world_name='World /Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P.MXIII_P'
clock=0.5; mv.tick(); assert(#spawned==0,'Once a second')
clock=1.0; mv.tick()
assert(#spawned==2 and loaded[M.ASSETS.ladder] and loaded[M.ASSETS.ledge],'Both classes loaded, both spawned')
local ladder,ledge=spawned[1],spawned[2]
assert(ladder.how=='deferred' and ladder.class.path==M.ASSETS.ladder..'_C' and ladder.at.X==10 and ladder.at.Z==30
    and ladder.rot.Yaw==175 and ladder.height_at_finish==400 and ladder.HeadHeight==79.885
    and ladder.HeadWidthHalf==34.9 and ladder.CollisionWidth==40,'The ladder: its height set before the finish')
assert(ledge.how=='deferred' and ledge.TotalHeight==nil and ledge.finished,'The ledge: its defaults')
assert(lines[1]=='ladder L1 at 10 20 30 yaw 175 height 400.0 (critical), deferred spawn',lines[1])
assert(lines[2]=='ledge E1 at 1 2 3 yaw 85 (climb_R16), deferred spawn',lines[2])
assert(lines[3]=='2/2 ladders and ledges spawned in world 2800; the warp switches beside them stay',lines[3])
clock=2.0; mv.tick()
assert(#spawned==2 and #lines==3,'Once a world')
-- A new world (a reload, a travel back): all again; the deferred call failing: SpawnActor and the script again.
world=new_world()
deferred_fails=true
clock=3.0; mv.tick()
assert(#spawned==4 and spawned[3].how=='SpawnActor' and spawned[3].rerun and spawned[3].TotalHeight==400
    and spawned[4].how=='SpawnActor','SpawnActor with the fields, then the construction script')
assert(lines[4]:find('^deferred spawn failed %(.*no such function%): SpawnActor and the construction script from now '
    ..'on$'),lines[4])
assert(lines[5]=='ladder L1 at 10 20 30 yaw 175 height 400.0 (critical), SpawnActor, construction script run again',
    lines[5])
deferred_fails=false
world=new_world()
clock=4.0; mv.tick()
assert(spawned[5].how=='SpawnActor','The fallback stays for the Lua load')
-- A class that does not load: its line says so, the others still spawn.
world=new_world()
loaded,classes={},{}
LoadAsset=function(path) if path==M.ASSETS.ledge then loaded[path]=true end end
clock=5.0; mv.tick()
assert(lines[#lines]=='1/2 ladders and ledges spawned in world 2800; the warp switches beside them stay',lines[#lines])
assert(lines[#lines-2]:find('^ladder L1 not spawned: .*BP_EM_Ladder_C does not load'),lines[#lines-2])

-- The generated list: every ladder has a height and a role, critical ones among them; the ledges are R16's.
local ladders,critical,ledges=0,0,0
for _,m in ipairs(Rows.MOVE) do
    assert(#m.at==3 and type(m.yaw)=='number' and m.key and m.role,m.key)
    if m.cls=='ladder' then
        ladders=ladders+1
        assert(m.height>0,m.key)
        if m.role=='critical' then critical=critical+1 end
    else
        assert(m.cls=='ledge' and m.role=='climb_R16',m.key)
        ledges=ledges+1
    end
end
assert(ladders==37 and ledges==5 and critical>20,ladders..' '..ledges..' '..critical)
print('mxmove_test: ok')
