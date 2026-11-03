-- Matrix XIII's boxes and barrels (matrix13/world/travel.lua ticks it): in world 2800 only, once a world, the mod
-- spawns SB's own BP_Destruction_Box_01_C, BP_Destruction_Box_02_C and BP_Barrel_01_Child_C at the points of
-- matrix13/world/rows.lua's BREAK list. The cooked map holds a StaticMeshActor tagged MXIII_BREAK at each point, a
-- proxy that cannot break; shipped levels place the real actors and no table row spawns them. Each actor gets the
-- ZoneEventActorTableAlias Matrix 11 pairs with its class (Box_01 ME_01_ZEA_003, or ME_01_ZEA_007 for a Plus box;
-- Box_02 always ME_01_ZEA_007; a barrel ME_01_ZEA_001, explosive with no drop, with its 2.0 to 2.5 s fuse) through the
-- deferred spawn matrix13/world/move.lua proved on the ladders. No ZoneEventActorSaveType is written: a spawned actor's
-- name changes from load to load, so nothing saved by name could find it again, and the boxes come back at each world
-- load. Per entry, in list order (Z4R21's Box_02_05 before the Box_01_68_Plus that rests on it): the class loaded, the
-- proxy's collision off and the proxy hidden, then the spawn; a failed spawn gives the proxy back its collision and
-- visibility. The proxies come from one FindAllOf('StaticMeshActor') pass a world, kept by name: a StaticFindObject per
-- entry would cost 4 to 35 ms at each miss. An entry whose proxy is not found spawns nothing, so no box can start
-- inside a solid proxy. The R23 box that gates DLC02_10_E_ItemS_015 has no proxy in the cook (proxy_in_cook=false) and
-- spawns alone. The spawns are spread over ticks, PER_TICK at a time. Each entry logs one [MXBREAK] line, then a total
-- line. Co-op: each PC spawns its own; a box broken on one PC stays whole on the other.
-- [inference] Whether a ZoneEventActor spawned after its level loaded registers with its row and breaks is untested.
local U=require('core.unreal')
local N=require('nightop.probe')
local Rows=require('matrix13.world.rows')
local Breakables={}
Breakables.MAP=require('matrix13.world.move').MAP
local DIR='/Game/GameDesign/Level/ZoneEventActor/'
Breakables.ASSETS={box1=DIR..'BP_Destruction_Box_01.BP_Destruction_Box_01',
    box2=DIR..'BP_Destruction_Box_02.BP_Destruction_Box_02',barrel=DIR..'BP_Barrel_01_Child.BP_Barrel_01_Child'}
Breakables.TAG='MXIII_BREAK'
Breakables.PER_TICK=40
local EVERY=1 -- s between looks at the world while nothing is left to spawn.
local ALWAYS_SPAWN=1 -- ESpawnActorCollisionHandlingMethod::AlwaysSpawn.

-- o: log (the [MXBREAK] lines), list (the BREAK list; matrix13/world/rows.lua's by default).
function Breakables.new(o)
    local log,list=o.log,o.list or Rows.BREAK
    local self={}
    -- world: the address the list was spawned in (or is being spawned in); todo: the next entry to spawn,
    -- nil when done.
    local world,next_look,todo,proxies,made,hidden=nil,0,nil,nil,0,0
    -- Found each time, never held: the game unloads them with the map, and a freed class read crashed it
    -- (2026-11-03). A class in memory is found at once.
    local function class_of(cls)
        local path=Breakables.ASSETS[cls]..'_C'
        local c=U.valid(StaticFindObject(path))
        if not c then
            pcall(LoadAsset,Breakables.ASSETS[cls])
            c=U.valid(StaticFindObject(path))
        end
        return assert(c,path..' does not load')
    end
    -- One pass over the StaticMeshActors: the tagged ones the list names, by name.
    local function find_proxies()
        local wanted,map,tag={},{},FName(Breakables.TAG)
        for _,m in ipairs(list) do if m.proxy_in_cook~=false then wanted[m.key]=true end end
        U.each(FindAllOf('StaticMeshActor') or {},function(_,a)
            a=U.valid(a)
            local name=a and U.text(a:GetFName())
            if name and wanted[name] and a:ActorHasTag(tag) then map[name]=a end
        end)
        return map
    end
    local function show(p,on)
        p:SetActorEnableCollision(on,false) -- SB's Actor takes (bNewActorEnableCollision, inFastUpdate)
        p:SetActorHiddenInGame(not on)
    end
    local function spawn(eve,m,c)
        local gs=U.find('/Script/Engine.Default__GameplayStatics')
        local t=U.find('/Script/Engine.Default__KismetMathLibrary'):MakeTransform({X=m.at[1],Y=m.at[2],Z=m.at[3]},
            {Pitch=0,Yaw=m.yaw,Roll=0},{X=1,Y=1,Z=1})
        local a=assert(U.valid(gs:BeginDeferredActorSpawnFromClass(eve,c,t,ALWAYS_SPAWN,nil)),'no actor')
        local ok,why=pcall(function()
            a.ZoneEventActorTableAlias=FName(m.alias)
            if m.delay then a.DestructionDelayMinTime,a.DestructionDelayMaxTime=m.delay[1],m.delay[2] end
        end)
        if not ok then
            pcall(function() a:K2_DestroyActor() end)
            error(why,0)
        end
        return assert(U.valid(gs:FinishSpawningActor(a,t)),'FinishSpawningActor gave nothing')
    end
    -- One entry: its line, true when spawned.
    local function one(eve,m)
        local fine,c=pcall(class_of,m.cls)
        if not fine then return false,'not spawned: '..tostring(c) end
        local p=nil
        if m.proxy_in_cook~=false then
            p=proxies[m.key]
            -- Still the one found by name: a reload at the same world address frees it, and another object can sit
            -- at its address.
            local same,is=pcall(function() return U.text(p:GetFName())==m.key end)
            if not (same and is) then return false,'not spawned: no proxy '..m.key..' in '..m.level end
            local off,why=pcall(show,p,false)
            if not off then
                pcall(show,p,true)
                return false,'not spawned: the proxy would not hide ('..tostring(why)..')'
            end
        end
        local ok,a=pcall(spawn,eve,m,c)
        if not ok then
            local back=p and pcall(show,p,true)
            return false,'not spawned: '..tostring(a)..(p and (back and ', proxy restored' or ', proxy NOT restored')
                or '')
        end
        if p then hidden=hidden+1 end
        local alias='?'
        pcall(function() alias=U.text(a.ZoneEventActorTableAlias) end)
        return true,string.format('at %.0f %.0f %.0f yaw %.0f alias %s%s, %s',m.at[1],m.at[2],m.at[3],m.yaw,alias,
            alias==m.alias and '' or ' (asked '..m.alias..')',
            p and 'proxy hidden' or 'no proxy in the cook'..(m.gates and ', gates '..m.gates or ''))
    end
    function self.tick()
        local now=os.clock()
        if not todo and now<next_look then return end
        next_look=now+EVERY
        local ok,map,eve=pcall(function()
            local x=U.valid(N.her())
            return x and U.map_of(x),x
        end)
        if not ok or not map or map:sub(-#Breakables.MAP)~=Breakables.MAP then
            world,todo=nil,nil
            return
        end
        -- By address only: a broken box destroys itself, so no spawned actor can say whether this world has them.
        local w=U.valid(eve:GetWorld())
        local here=w and U.address(w)
        if here~=world then
            world,todo,proxies,made,hidden=here,1,nil,0,0
        end
        if not todo then return end
        if not proxies then -- Its own tick: the pass walks every object.
            local found,got=pcall(find_proxies)
            proxies=found and got or {}
            if not found then log('no proxy list ('..tostring(got)..'): only the entries without a proxy spawn') end
            return
        end
        local last=math.min(#list,todo+Breakables.PER_TICK-1)
        for i=todo,last do
            local m=list[i]
            local spawned,line=one(eve,m)
            if spawned then made=made+1 end
            log(string.format('%s %s (%s) %s',m.cls,m.key,m.level,line))
        end
        todo=last+1
        if todo>#list then
            todo=nil
            log(string.format('%d/%d boxes and barrels spawned in world 2800, %d proxies hidden',made,#list,hidden))
        end
    end
    return self
end
return Breakables
