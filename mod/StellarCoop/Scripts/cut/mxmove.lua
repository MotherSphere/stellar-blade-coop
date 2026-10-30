-- Matrix XIII's ladders and ledges (cut/mxiii.lua ticks it): in world 2800 only, once a world, the mod spawns SB's
-- own BP_EM_Ladder_C and BP_EM_Ledge_C at the points of cut/mxiii_rows.lua's MOVE list. A cooked map never reruns
-- construction scripts when a level streams in, so a ladder placed in the cooked map keeps the height it was cooked
-- with; one spawned at run time runs its construction script with ours. The spawn is deferred
-- (UGameplayStatics::BeginDeferredActorSpawnFromClass, the fields set, then FinishSpawningActor) so the construction
-- script sees TotalHeight; if that call fails once, every later spawn of the Lua load uses World:SpawnActor, sets the
-- fields and calls the class's UserConstructionScript again. Each spawn logs one [MXMOVE] line with the way it took.
-- Every critical climb also has a warp switch pair (the mxwarp rows), so a ladder that does not work never blocks.
-- The ledges keep their blueprint's default spline [inference: their length was never set from a marker].
local U=require('core.unreal')
local N=require('nightop.probe')
local Rows=require('cut.mxiii_rows')
local Move={}
Move.MAP='/mxiii_p' -- The end of core/unreal.lua's map_of in world 2800.
local DIR='/Game/GameDesign/Level/BluePrintActor/SBEventMove/'
Move.ASSETS={ladder=DIR..'BP_EM_Ladder.BP_EM_Ladder',ledge=DIR..'BP_EM_Ledge.BP_EM_Ledge'}
-- The ladder's head and collision as Matrix 11's placed ladders have them (MOVERS F11).
Move.LADDER={HeadHeight=79.885,HeadWidthHalf=34.9,CollisionWidth=40}
local EVERY=1 -- s between looks at the world.
local ALWAYS_SPAWN=1 -- ESpawnActorCollisionHandlingMethod::AlwaysSpawn.

-- o: log (the [MXMOVE] lines), list (the MOVE list; cut/mxiii_rows.lua's by default).
function Move.new(o)
    local log,list=o.log,o.list or Rows.MOVE
    local self={}
    local world,spawned,next_look,deferred=nil,{},0,true
    local function class_of(cls)
        local path=Move.ASSETS[cls]..'_C'
        local c=U.valid(StaticFindObject(path))
        if not c then
            pcall(LoadAsset,Move.ASSETS[cls])
            c=U.valid(StaticFindObject(path))
        end
        return assert(c,path..' does not load')
    end
    local function fields(a,m)
        if m.cls~='ladder' then return end
        a.TotalHeight=m.height
        for k,v in pairs(Move.LADDER) do a[k]=v end
    end
    -- One spawn: the deferred pair while it works, else SpawnActor and the construction script again.
    local function spawn(eve,m)
        local at={X=m.at[1],Y=m.at[2],Z=m.at[3]}
        local rot={Pitch=0,Yaw=m.yaw,Roll=0}
        local c=class_of(m.cls)
        if deferred then
            local ok,a=pcall(function()
                local gs=U.find('/Script/Engine.Default__GameplayStatics')
                local t=U.find('/Script/Engine.Default__KismetMathLibrary'):MakeTransform(at,rot,{X=1,Y=1,Z=1})
                local x=assert(U.valid(gs:BeginDeferredActorSpawnFromClass(eve,c,t,ALWAYS_SPAWN,nil)),'no actor')
                fields(x,m)
                return assert(U.valid(gs:FinishSpawningActor(x,t)),'FinishSpawningActor gave nothing')
            end)
            if ok then return a,'deferred spawn' end
            deferred=false
            log('deferred spawn failed ('..tostring(a)..'): SpawnActor and the construction script from now on')
        end
        local a=assert(U.valid(eve:GetWorld():SpawnActor(c,at,rot)),'SpawnActor gave nothing')
        fields(a,m)
        local ran=pcall(function() a:UserConstructionScript() end)
        return a,ran and 'SpawnActor, construction script run again' or 'SpawnActor, construction script not run'
    end
    function self.tick()
        local now=os.clock()
        if now<next_look then return end
        next_look=now+EVERY
        local ok,map,eve=pcall(function()
            local x=U.valid(N.her())
            return x and U.map_of(x),x
        end)
        if not ok or not map or map:sub(-#Move.MAP)~=Move.MAP then
            world,spawned=nil,{}
            return
        end
        -- By address: UE4SS hands out a new wrapper on every call, so two wrappers of one world never compare equal.
        local w=U.valid(eve:GetWorld())
        local here=w and U.address(w)
        if here==world and (not spawned[1] or U.valid(spawned[1])) then return end
        world,spawned=here,{}
        local made=0
        for _,m in ipairs(list) do
            local fine,a,how=pcall(spawn,eve,m)
            if fine then
                spawned[#spawned+1]=a
                made=made+1
                log(string.format('%s %s at %.0f %.0f %.0f yaw %.0f%s (%s), %s',m.cls,m.key,m.at[1],m.at[2],m.at[3],
                    m.yaw,m.height and string.format(' height %.1f',m.height) or '',m.role,how))
            else
                log(string.format('%s %s not spawned: %s',m.cls,m.key,tostring(a)))
            end
        end
        log(string.format('%d/%d ladders and ledges spawned in world 2800; the warp switches beside them stay',made,
            #list))
    end
    return self
end
return Move
