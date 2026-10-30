-- Matrix XIII's ladders, ledges and ropes (cut/mxiii.lua ticks it): in world 2800 only, once a world, the mod spawns
-- SB's own BP_EM_Ladder_C, BP_EM_Ledge_C and Env_EM_VerticalRope_C at the points of cut/mxiii_rows.lua's MOVE list. A
-- cooked map never reruns construction scripts when a level streams in, so a ladder placed in the cooked map keeps the
-- components it was cooked with; one spawned at run time runs its construction script with ours. The spawn is deferred
-- (UGameplayStatics::BeginDeferredActorSpawnFromClass, the fields set, then FinishSpawningActor) so the construction
-- script sees them; if that call fails once, every later spawn of the Lua load uses World:SpawnActor, sets the fields
-- and calls the class's UserConstructionScript again. Each spawn logs one [MXMOVE] line with the way it took and, for
-- a ladder, its Meshes stack as read back before the finish.
-- A ladder's height comes from its Meshes stack (enum Enum_EM_LadderMeshes: 0 160.9 cm, 1 200, 2 240, 3 600, 11 40.9)
-- plus the 79.885 cm head. Its construction script stacks the pieces up from the actor's origin, the foot, starting at
-- whatever TotalHeight holds and adding each piece to it. So TotalHeight is left at its class default 0 (the SpawnActor
-- way puts it back to 0 before its second run), and HeadHeight, HeadWidthHalf and CollisionWidth, which the script
-- writes too, are not set: a TotalHeight set before the finish lifted every ladder by its own height (2026-10-31).
-- The actor stands on the rung line, its -X toward the upper landing, at the points tools/mxiii_climb.py takes from
-- the editor's proxy ladders. The line gives the TotalHeight read back after the finish ('built').
-- A ledge gets the shipped climbing mesh 006_B_SM (its grab line on the actor's +Y). A rope gets its drop
-- (RopeDistanceB) and, with a ladder bound to a row, its EnvActorName, the name its env row looks for: rope rows start
-- Off (hidden) until their winch turns them On, and ladder gate 435's lowered ladder starts with its row 437 Off.
-- [inference] Whether an SBZoneEnvActor spawned after its zone's rows were made registers with its row is untested.
local U=require('core.unreal')
local N=require('nightop.probe')
local Rows=require('cut.mxiii_rows')
local Move={}
Move.MAP='/mxiii_p' -- The end of core/unreal.lua's map_of in world 2800.
local DIR='/Game/GameDesign/Level/BluePrintActor/SBEventMove/'
Move.ASSETS={ladder=DIR..'BP_EM_Ladder.BP_EM_Ladder',ledge=DIR..'BP_EM_Ledge.BP_EM_Ledge',
    rope=DIR..'Env_EM_VerticalRope.Env_EM_VerticalRope'}
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
    -- An object of the ledge's mesh, loaded once.
    local meshes={}
    local function mesh_of(path)
        if not meshes[path] then
            local m=U.valid(StaticFindObject(path))
            if not m then
                pcall(LoadAsset,path)
                m=U.valid(StaticFindObject(path))
            end
            meshes[path]=assert(m,path..' does not load')
        end
        return meshes[path]
    end
    -- UE4SS 3.0.1 grows a TArray when it is indexed past its end, and that growth may zero the values already in it
    -- (UE4SS #436, fixed after 3.0.1). Filled from the last item, the empty array grows once and every later write lands
    -- inside it.
    local function fill(array,items) for i=#items,1,-1 do array[i]=items[i] end end
    -- The stack as the actor holds it, read back before the finish: 'stack 3,3' (or 'stack ? (why)').
    local function stack(array)
        local ok,s=pcall(function()
            local n=type(array.GetArrayNum)=='function' and array:GetArrayNum() or #array
            local t={}
            for i=1,n do t[i]=tostring(array[i]) end
            return table.concat(t,',')
        end)
        return 'stack '..(ok and s or '? ('..tostring(s)..')')
    end
    local function fields(a,m,mesh)
        if m.env then a.EnvActorName=FName(m.env) end
        if m.cls=='ladder' then
            fill(a.Meshes,m.meshes)
            a.StartUnit,a.CollisionBottomZAdd=m.start,m.bottom
            return ' '..stack(a.Meshes)
        elseif m.cls=='ledge' then
            fill(a.Meshes,{mesh})
        elseif m.cls=='rope' then
            a.RopeDistanceB=m.drop
        end
        return ''
    end
    -- The TotalHeight the construction script built: ' built 1279.9' (or nothing when it does not read).
    local function built(a)
        local ok,h=pcall(function() return a.TotalHeight end)
        return ok and type(h)=='number' and string.format(' built %.1f',h) or ''
    end
    -- One spawn: the deferred pair while it works, else SpawnActor and the construction script again.
    local function spawn(eve,m)
        local at={X=m.at[1],Y=m.at[2],Z=m.at[3]}
        local rot={Pitch=0,Yaw=m.yaw,Roll=0}
        local c=class_of(m.cls)
        -- Loaded before the deferred pair: an asset load between Begin and Finish crashed the game (2026-10-30).
        local mesh=m.cls=='ledge' and mesh_of(m.mesh) or nil
        if deferred then
            local ok,a,got=pcall(function()
                local gs=U.find('/Script/Engine.Default__GameplayStatics')
                local t=U.find('/Script/Engine.Default__KismetMathLibrary'):MakeTransform(at,rot,{X=1,Y=1,Z=1})
                local x=assert(U.valid(gs:BeginDeferredActorSpawnFromClass(eve,c,t,ALWAYS_SPAWN,nil)),'no actor')
                local got=fields(x,m,mesh)
                return assert(U.valid(gs:FinishSpawningActor(x,t)),'FinishSpawningActor gave nothing'),got
            end)
            if ok then return a,got,'deferred spawn' end
            deferred=false
            log('deferred spawn failed ('..tostring(a)..'): SpawnActor and the construction script from now on')
        end
        local a=assert(U.valid(eve:GetWorld():SpawnActor(c,at,rot)),'SpawnActor gave nothing')
        local got=fields(a,m,mesh)
        -- The spawn already ran the script once: its running sum back to the class default before the second run.
        if m.cls=='ladder' then a.TotalHeight=0 end
        local ran=pcall(function() a:UserConstructionScript() end)
        return a,got,ran and 'SpawnActor, construction script run again' or 'SpawnActor, construction script not run'
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
            local fine,a,got,how=pcall(spawn,eve,m)
            if fine then
                spawned[#spawned+1]=a
                made=made+1
                local extra=(m.height and string.format(' height %.1f',m.height) or '')
                    ..got..(m.cls=='ladder' and built(a) or '')..(m.drop and string.format(' drop %.0f',m.drop) or '')
                    ..(m.env and ' env '..m.env or '')
                log(string.format('%s %s at %.0f %.0f %.0f yaw %.0f%s (%s), %s',m.cls,m.key,m.at[1],m.at[2],m.at[3],
                    m.yaw,extra,m.role,how))
            else
                log(string.format('%s %s not spawned: %s',m.cls,m.key,tostring(a)))
            end
        end
        log(string.format('%d/%d ladders, ledges and ropes spawned in world 2800',made,#list))
    end
    return self
end
return Move
