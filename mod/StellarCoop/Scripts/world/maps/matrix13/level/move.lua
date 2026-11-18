-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Matrix XIII's ladders, ledges and ropes (world/maps/matrix13/level/travel.lua ticks it): in world 2800 only, once a
-- world, the mod spawns SB's own BP_EM_Ladder_C, BP_EM_Ledge_C and Env_EM_VerticalRope_C at the points of
-- world/maps/matrix13/level/rows.lua's MOVE list. A cooked map never reruns construction scripts when a level streams
-- in, so a ladder placed in the cooked map keeps the components it was cooked with; one spawned at run time runs its
-- construction script with ours. The spawn is deferred (UGameplayStatics::BeginDeferredActorSpawnFromClass, the fields
-- set, then FinishSpawningActor) so the construction script sees them; if that call fails once, every later spawn of
-- the Lua load uses World:SpawnActor, sets the fields and calls the class's UserConstructionScript again. The spawns
-- are spread over ticks on a time budget (BUDGET), in list order. After the last entry come one [MXMOVE] line per
-- class with the ways the spawns took, the spread and the count; a spread cut short gives one line of what it spawned
-- so far. An entry logs its own line only when it did not spawn,
-- when its construction script did not run again after SpawnActor, or for a ladder whose TotalHeight does not read back
-- as its listed height (the line gives its Meshes stack as read back before the finish); a ladder whose stack does not
-- read back as written is destroyed before its finish and its line says so.
-- A ladder's height comes from its Meshes stack (the list names Enum_EM_LadderMeshes' NewEnumeratorN: 0 160.9 cm, 1 200,
-- 2 240, 3 600, 11 40.9) plus the 79.885 cm head. A stack holds an enumerator's value, its place in the enum, not N:
-- BYTE below, read from the cooked enum (N written raw built ladders short with their head mid-way, 2026-10-31). Its construction script stacks the pieces up from the actor's origin, the foot, starting at
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
local N=require('core.player')
local Rows=require('world.maps.matrix13.level.rows')
local Move={}
Move.MAP='/mxiii_p' -- The end of core/unreal.lua's map_of in world 2800.
local DIR='/Game/GameDesign/Level/BluePrintActor/SBEventMove/'
local BYTE={[11]=1,[0]=2,[1]=3,[2]=4,[3]=5} -- NewEnumeratorN to its value (10 None 0, 9 600_Guard 6 are unused).
Move.ASSETS={ladder=DIR..'BP_EM_Ladder.BP_EM_Ladder',ledge=DIR..'BP_EM_Ledge.BP_EM_Ledge',
    rope=DIR..'Env_EM_VerticalRope.Env_EM_VerticalRope'}
local EVERY=1 -- s between looks at the world while nothing is left to spawn.
-- Seconds of spawning a tick: at least one entry, then more until this is spent. One spawn took 10 to 13 ms in game
-- (UE4SS.log 2026-11-12 21:49), so in practice one a tick; all 48 in one tick froze a frame for 689 ms. A spawn cannot
-- be split: FinishSpawningActor (exec 0x144773be0) runs AActor::FinishSpawning 0x143f6b580, construction script and
-- BeginPlay included, before it returns.
Move.BUDGET=0.004
local ALWAYS_SPAWN=1 -- ESpawnActorCollisionHandlingMethod::AlwaysSpawn.

-- o: log (the [MXMOVE] lines), list (the MOVE list; world/maps/matrix13/level/rows.lua's by default).
function Move.new(o)
    local log,list=o.log,o.list or Rows.MOVE
    local self={}
    local world,spawned,next_look,deferred=nil,{},0,true
    local todo,made=nil,0 -- The next entry to spawn (nil when done) and the spawns so far, in this world.
    -- The world's counts by class (order: the classes in list order) and its spread (ticks, the longest, its start).
    local counts,order,ticks,longest,began={},{},0,0,0
    -- Seconds the world's spawns spent finding their class and the ledge mesh: UE4SS's StaticFindObject walks the
    -- object array, so the spread line tells that share of a spawn from FinishSpawningActor's.
    local looked=0
    local function class_of(cls)
        local path=Move.ASSETS[cls]..'_C'
        local c=U.valid(StaticFindObject(path))
        if not c then
            pcall(LoadAsset,Move.ASSETS[cls])
            c=U.valid(StaticFindObject(path))
        end
        return assert(c,path..' does not load')
    end
    -- An object of the ledge's mesh, found again each spawning tick and never held past it: the game unloads it with
    -- the map, and a held object read in the next Matrix XIII world crashed the game (2026-11-03).
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
    -- The stack as the actor holds it: 'stack 3,3' (or 'stack ? (why)'). Only indexes inside the array are read: on
    -- UE4SS 3.0.1 a read past the end grows the array too.
    local function stack(array)
        local ok,s=pcall(function()
            local n=type(array.GetArrayNum)=='function' and array:GetArrayNum() or #array
            local t={}
            for i=1,n do t[i]=tostring(array[i]) end
            return table.concat(t,',')
        end)
        return 'stack '..(ok and s or '? ('..tostring(s)..')')
    end
    local function holds(array,items)
        local ok,same=pcall(function()
            if array:GetArrayNum()~=#items then return false end
            for i,v in ipairs(items) do if array[i]~=v then return false end end
            return true
        end)
        return ok and same
    end
    -- UE4SS 3.0.1 (this game's; its TArray fix #436 came in 4.0): a write two or more past the end grows the array to
    -- index-1 and loses the value, a write at 1 into the empty array lands. The 2026-10-30 23:03 UE4SS.log read all 41
    -- stacks, filled from their last piece, back that way: each multi-piece one a piece short (R28's 3,3 as 3, Z4_L1's
    -- 3,3,3,2,1 as 3,3,3,2), the 1-piece ones whole. So the first item goes in, a write one past the last item sizes
    -- the array, and every item then lands inside it. The array is read back; when it differs, it is emptied and filled
    -- front to back (what a fixed UE4SS takes) and read back again.
    -- Gives '' or ' (first fill read stack ..., filled again front to back)', or nil and why it is wrong.
    local function fill(array,items)
        local n=#items
        array[1]=items[1]
        if n>1 then array[n+1]=items[n] end
        for i=n,1,-1 do array[i]=items[i] end
        if holds(array,items) then return '' end
        local first=stack(array)
        local ok,why=pcall(function()
            array:Empty()
            for i=1,n do array[i]=items[i] end
        end)
        if ok and holds(array,items) then return ' (first fill read '..first..', filled again front to back)' end
        return nil,string.format('Meshes read back %s, then %s, for %s: nothing spawned',first,
            ok and stack(array) or 'no refill ('..tostring(why)..')',table.concat(items,','))
    end
    local function fields(a,m,mesh)
        if m.env then a.EnvActorName=FName(m.env) end
        if m.cls=='ladder' then
            local bytes={}
            for i,n in ipairs(m.meshes) do bytes[i]=assert(BYTE[n],'no enumerator '..tostring(n)) end
            local note,why=fill(a.Meshes,bytes)
            if not note then return nil,why end
            a.StartUnit,a.CollisionBottomZAdd=m.start,m.bottom
            return ' '..stack(a.Meshes)..note
        elseif m.cls=='ledge' then
            a.Meshes[1]=mesh -- One write into the empty array: 3.0.1 appends it (the 1-piece stacks read back whole).
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
        local t0=os.clock()
        local c=class_of(m.cls)
        -- Loaded before the deferred pair: an asset load between Begin and Finish crashed the game (2026-10-30).
        local mesh=m.cls=='ledge' and mesh_of(m.mesh) or nil
        looked=looked+os.clock()-t0
        if deferred then
            local ok,a,got=pcall(function()
                local gs=U.find('/Script/Engine.Default__GameplayStatics')
                local t=U.find('/Script/Engine.Default__KismetMathLibrary'):MakeTransform(at,rot,{X=1,Y=1,Z=1})
                local x=assert(U.valid(gs:BeginDeferredActorSpawnFromClass(eve,c,t,ALWAYS_SPAWN,nil)),'no actor')
                local got,why=fields(x,m,mesh)
                if not got then pcall(function() x:K2_DestroyActor() end); return false,why end
                return assert(U.valid(gs:FinishSpawningActor(x,t)),'FinishSpawningActor gave nothing'),got
            end)
            if ok and not a then error(got,0) end -- A stack that would not fill: this ladder only, not the way.
            if ok then return a,got,'deferred spawn' end
            deferred=false
            log('deferred spawn failed ('..tostring(a)..'): SpawnActor and the construction script from now on')
        end
        local a=assert(U.valid(eve:GetWorld():SpawnActor(c,at,rot)),'SpawnActor gave nothing')
        local got,why=fields(a,m,mesh)
        if not got then pcall(function() a:K2_DestroyActor() end); error(why,0) end
        -- The spawn already ran the script once: its running sum back to the class default before the second run.
        if m.cls=='ladder' then a.TotalHeight=0 end
        local ran=pcall(function() a:UserConstructionScript() end)
        return a,got,ran and 'SpawnActor, construction script run again' or 'SpawnActor, construction script not run'
    end
    -- A spread cut short: what it spawned so far, since the class lines come only after the last entry.
    local function stopped(why)
        if todo then log(string.format('spread stopped after %d/%d entries (%s): %d spawned',todo-1,#list,why,made)) end
    end
    -- True when this tick spent its time spawning: world/maps/matrix13/level/travel.lua then holds the boxes back for
    -- the frame.
    function self.tick()
        local now=os.clock()
        if not todo and now<next_look then return end
        next_look=now+EVERY
        local ok,map,eve=pcall(function()
            local x=U.valid(N.her())
            return x and U.map_of(x),x
        end)
        if not ok or not map or map:sub(-#Move.MAP)~=Move.MAP then
            stopped('world 2800 left')
            world,spawned,meshes,todo=nil,{},{},nil
            return
        end
        -- By address: UE4SS hands out a new wrapper on every call, so two wrappers of one world never compare equal.
        local w=U.valid(eve:GetWorld())
        local here=w and U.address(w)
        if here~=world or (spawned[1] and not U.valid(spawned[1])) then
            stopped(here~=world and 'new world' or 'first spawn gone')
            world,spawned,todo,made=here,{},1,0
            counts,order,ticks,longest,began,looked={},{},0,0,os.clock(),0
        end
        if not todo then return end
        meshes={}
        local start=os.clock()
        while todo<=#list do
            local m=list[todo]
            local c=counts[m.cls]
            if not c then
                c={n=0,made=0,ways={},refilled=0}
                counts[m.cls],order[#order+1]=c,m.cls
            end
            c.n=c.n+1
            local fine,a,got,how=pcall(spawn,eve,m)
            if fine then
                spawned[#spawned+1]=a
                made,c.made=made+1,c.made+1
                c.ways[how]=(c.ways[how] or 0)+1
                if got:find('filled again',1,true) then c.refilled=c.refilled+1 end
                local h=m.cls=='ladder' and built(a) or ''
                if (m.cls=='ladder' and (not m.height or h~=string.format(' built %.1f',m.height)))
                    or how:find('not run',1,true) then
                    local extra=(m.height and string.format(' height %.1f',m.height) or '')
                        ..got..h..(m.drop and string.format(' drop %.0f',m.drop) or '')
                        ..(m.env and ' env '..m.env or '')
                    log(string.format('%s %s at %.0f %.0f %.0f yaw %.0f%s (%s), %s',m.cls,m.key,m.at[1],m.at[2],
                        m.at[3],m.yaw,extra,m.role,how))
                end
            else
                log(string.format('%s %s not spawned: %s',m.cls,m.key,tostring(a)))
            end
            todo=todo+1
            if os.clock()-start>=Move.BUDGET then break end
        end
        ticks,longest=ticks+1,math.max(longest,os.clock()-start)
        if todo>#list then
            todo=nil
            for _,cls in ipairs(order) do
                local c,ways=counts[cls],{}
                for how,n in pairs(c.ways) do ways[#ways+1]=n..' '..how end
                table.sort(ways)
                log(string.format('%s: %d/%d spawned%s%s',cls,c.made,c.n,
                    #ways>0 and ', '..table.concat(ways,'; ') or '',
                    c.refilled>0 and '; '..c.refilled..' stack'..(c.refilled==1 and '' or 's')
                        ..' filled again front to back' or ''))
            end
            log(string.format('spread over %d tick%s in %.1f s, the longest %.0f ms, lookups %.0f ms in all',ticks,
                ticks==1 and '' or 's',os.clock()-began,longest*1000,looked*1000))
            log(string.format('%d/%d ladders, ledges and ropes spawned in world 2800',made,#list))
        end
        return true
    end
    return self
end
return Move
