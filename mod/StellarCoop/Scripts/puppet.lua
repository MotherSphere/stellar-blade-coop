-- The ghost: a render-only EVE drawn from a component table (native/src/pose_table.h) the native part received, hers
-- back through the loopback or a replayed recording today, a friend's in Phase 4. A plain actor with one
-- PoseableMeshComponent per part and no collision: not a Pawn, so lock-on, AI and saves never see it, and nothing of it
-- is written to a save, an inventory or an unlock. Each part loads the mesh the table names (LoadAsset only brings a
-- cooked asset into memory: display only, nothing is worn) with its own default materials, so the ghost wears her
-- outfit. A mesh this PC lacks (a DLC it does not own), one the path rule refused ('-'), or one with other bones than
-- hers falls back to the base suit (body and hair), whose bones the native part drives by name (a remap); a part with
-- no fallback is left out, with its followers. Parts hang as the table says (parent part, socket, placement) and
-- followers follow their leader (SetMasterPoseComponent). No cloth or morphs: a rigid ponytail and a neutral face.
-- The build resolves one mesh a frame (a coroutine), then names what it built for the native part (coop-display.txt),
-- which writes the leaders' bones each frame and the main mesh's world transform into the mailbox, a scene component
-- nothing moves; place() puts the root there after the native tick. The ghost stays hidden until the first pose and
-- after a second without one, and is only built when she is on your map.
-- The same table again with a part hung elsewhere (a blade drawn) or shown or hidden is applied in place; a new
-- generation (her outfit) is a new ghost. The ghost's path is kept in a file, so the next Lua load (a hot reload)
-- finds and destroys one left standing; after a level change it comes back once EVE has been in the world 2 s.
local UE=require('UEHelpers')
local U=require('unreal')
local valid,value_of,each,text,find,address,hex,word=U.valid,U.value_of,U.each,U.text,U.find,U.address,U.hex,U.word
local Puppet={}
local RIGHT=200 -- cm: in loopback the ghost is yours, so it walks 2 m to your right.
local KEEP_RELATIVE=0 -- EAttachmentRule::KeepRelative
local BASE_BODY='/Game/Art/Character/PC/CH_P_EVE_08/CH_P_EVE_08.CH_P_EVE_08'
local BASE_HAIR='/Game/Art/Character/PC/00_HR/EVE_HR_01/EVE_HR_01.EVE_HR_01'
local function fallback(part) return part.i==0 and BASE_BODY or part.name=='SBHair' and BASE_HAIR or nil end
-- coop-remote.txt as the native part writes it (format_table), read strictly: nil on anything else. Parts are listed
-- in order, each with i (its index), lead and parent (indexes, nil for '-'), socket and path (nil for '-'), shown,
-- bones, name, place (its 10 numbers as written) and a leader's names.
local function parse_remote(file)
    if type(file)~='string' then return nil end
    local lines,at={},1
    for line in file:gmatch('([^\n]*)\n') do lines[#lines+1]=line end
    local function take(pattern)
        local found={(lines[at] or ''):match(pattern)}
        if found[1]~=nil then at=at+1 end
        return table.unpack(found)
    end
    if not take('^SBT %d+$') then return nil end
    local t={generation=tonumber(take('^generation (%d+)$')),map=take('^map (%S+)$'),parts={}}
    if not (t.generation and t.map) then return nil end
    while lines[at] do
        local i,lead,parent,socket,shown,bones,name,path=take('^part (%d+) (%S+) (%S+) (%S+) ([01]) (%d+) (%S+) (%S+)$')
        local part={i=#t.parts,lead=tonumber(lead),parent=tonumber(parent),socket=socket~='-' and socket or nil,
            shown=shown=='1',bones=tonumber(bones),name=name,path=path~='-' and path or nil}
        if tonumber(i)~=part.i then return nil end
        if part.i>0 then
            local index,place=take('^place (%d+) (%S+ %S+ %S+ %S+ %S+ %S+ %S+ %S+ %S+ %S+)$')
            if tonumber(index)~=part.i then return nil end
            part.place=place
        end
        if lead=='-' then
            local index,names=take('^names (%d+) (.+)$')
            if tonumber(index)~=part.i then return nil end
            part.names={}
            for name_of in names:gmatch('%S+') do part.names[#part.names+1]=name_of end
            if #part.names~=part.bones then return nil end
        end
        t.parts[#t.parts+1]=part
    end
    return #t.parts>0 and t or nil
end
-- What must stay for a table to be applied to a ghost built from another under the same generation.
local function layout(t)
    local key={}
    for _,part in ipairs(t.parts) do key[#key+1]=tostring(part.lead)..':'..part.bones..':'..(part.path or '-') end
    return table.concat(key,' ')
end
local function transform(place)
    local v={}
    for number in place:gmatch('%S+') do v[#v+1]=tonumber(number) end
    return {Rotation={X=v[1],Y=v[2],Z=v[3],W=v[4]},Translation={X=v[5],Y=v[6],Z=v[7]},Scale3D={X=v[8],Y=v[9],Z=v[10]}}
end
-- link (nil without the native part): remote_table() -> coop-remote.txt's text, display(text|nil) publishes or
-- withdraws the display file, store() keeps the ghost's object path across Lua loads (save, load, clear). capture gives
-- yaw_delta(), the loopback's offset.
function Puppet.new(link,capture)
    local files=link or {remote_table=function() end,display=function() return false,'no native part' end}
    local store=link and link.store() or {save=function() end,load=function() end,clear=function() end}
    local self,wanted,basesuit={},false,false
    local remote,seen_count,source=nil,nil,nil -- The remote table, the status count it was read at, where it came from.
    local ghost,build=nil,nil -- The ghost (built or being built) and its build coroutine.
    local back_since,failed,hidden_pair=nil,nil,nil
    local cache={} -- Meshes by path; false: none this Lua load (a missing DLC stays missing).
    local function clear(why)
        local g=ghost
        ghost,build=nil,nil
        if not g then return nil end
        files.display(nil)
        store.clear()
        if valid(g.actor) then g.actor:K2_DestroyActor() end
        return string.format('Ghost %d removed (%s).',g.generation,why)
    end
    -- A ghost an earlier Lua load left standing (hot reload): found by its path, checked to be ours, destroyed. Done on
    -- the game thread (the first tick or toggle), never while the Lua state loads on UE4SS's own thread.
    local swept,swept_done=nil,false
    local function sweep()
        if swept_done then return end
        swept_done=true
        local path=store.load()
        store.clear()
        if not path then return nil end
        local actor=valid(StaticFindObject(path))
        local root=actor and valid(actor:K2_GetRootComponent())
        if not (actor and root and root:IsA(find('/Script/Engine.PoseableMeshComponent'))) then return nil end
        actor:K2_DestroyActor()
        swept='Removed a ghost left by an earlier Lua load.'
    end
    -- A skeletal mesh by its object path: in memory already (StaticFindObject), else loaded (LoadAsset, synchronous on
    -- this thread); nil when neither gives a SkeletalMesh.
    local function resolve(path,counts)
        local mesh=valid(cache[path] or nil)
        if mesh or cache[path]==false then return mesh end
        local started=os.clock()
        mesh=valid(StaticFindObject(path))
        if not mesh then
            local ok,loaded=pcall(LoadAsset,path)
            mesh=ok and valid(loaded) or nil
        end
        if mesh and not mesh:IsA(find('/Script/Engine.SkeletalMesh')) then mesh=nil end
        cache[path]=mesh or false
        counts.loaded,counts.ms=counts.loaded+1,counts.ms+(os.clock()-started)*1000
        return mesh
    end
    -- Hangs a built part as the table says: its parent part (part 0 when that one was left out), socket and place;
    -- then shown or hidden.
    local function hang(g,part)
        local built=g.parts[part.i]
        if part.i>0 then
            local parent=g.parts[part.parent] or g.parts[0]
            built.target:K2_AttachToComponent(parent.target,FName(part.socket or 'None'),KEEP_RELATIVE,KEEP_RELATIVE,
                KEEP_RELATIVE,false)
            built.target:K2_SetRelativeTransform(transform(part.place),false,{},true)
        end
        built.target:SetVisibility(part.shown,false)
    end
    -- The coroutine: spawns the hidden actor, then dresses one part per resume (one mesh resolved a frame), hangs them
    -- all, adds the mailbox and publishes the display file. Returns the build's line for the log.
    local function build_ghost(eve)
        local t=remote
        local started=os.clock()
        local poseable=find('/Script/Engine.PoseableMeshComponent')
        local identity=find('/Script/Engine.Default__KismetMathLibrary'):MakeTransform({X=0,Y=0,Z=0},
            {Pitch=0,Yaw=0,Roll=0},{X=1,Y=1,Z=1})
        local actor=valid(eve:GetWorld():SpawnActor(find('/Script/Engine.Actor'),value_of(eve:K2_GetActorLocation()),
            {Pitch=0,Yaw=0,Roll=0}))
        assert(actor,'the ghost actor could not be spawned')
        local g={actor=actor,generation=t.generation,eve=address(eve),parts={},count=0,leaders=0,base=0,left_out=0,
            hidden=true,stamp=1,stamp_at=0}
        ghost=g
        actor:SetActorHiddenInGame(true) -- Until the first pose: never her reference pose at the spawn spot.
        actor:SetActorEnableCollision(false,false)
        store.save(actor:GetFullName():match('^%S+ (.+)$'))
        local counts,notes={loaded=0,ms=0},{}
        local function add(mesh)
            local target=valid(actor:AddComponentByClass(poseable,false,identity,false)) -- The first is the root.
            assert(target,'a ghost part could not be added')
            target:SetCollisionEnabled(0)
            target:SetSkeletalMesh(mesh,true) -- And no SetMaterial: the mesh's own materials.
            return target
        end
        -- One part's component and mesh: the table's, else its fallback's (then with true, and for a leader its remap);
        -- nil when it has neither.
        local function dress(part)
            local base,why=fallback(part),'missing'
            if basesuit and base then
                why='replaced (basesuit)'
            else
                local mesh=part.path and resolve(part.path,counts)
                coroutine.yield()
                if mesh then
                    local target=add(mesh)
                    if part.lead or target:GetNumBones()==part.bones then return target,mesh end
                    why=string.format('has %d bones, not %d',target:GetNumBones(),part.bones)
                    target:K2_DestroyComponent(actor) -- Never re-point it: a mesh of the same count would keep stale bones.
                end
            end
            if not base then return nil end
            local mesh=resolve(base,counts)
            coroutine.yield()
            if not mesh then return nil end
            local target=add(mesh)
            if part.lead then
                notes[#notes+1]=string.format('%s: %s %s, drawn as %s',part.name,part.path or '-',why,base)
                return target,mesh,true
            end
            -- Each of the fallback's bones takes her bone of the same name, else keeps its reference pose.
            local of,remap,follow={},{},0
            for k,name in ipairs(part.names) do of[name]=of[name] or k-1 end
            for j=0,target:GetNumBones()-1 do
                local k=of[word(text(target:GetBoneName(j)))]
                remap[#remap+1]=k or -1
                follow=follow+(k and 1 or 0)
            end
            notes[#notes+1]=string.format('%s: %s %s, drawn as %s (%d of %d bones follow)',part.name,part.path or '-',why,
                base,follow,#remap)
            return target,mesh,true,remap
        end
        for _,part in ipairs(t.parts) do
            local lead=part.lead and g.parts[part.lead]
            local target,mesh,based,remap
            if not part.lead or lead then target,mesh,based,remap=dress(part) end
            if not target then
                assert(part.i>0,'her body could not be drawn, not even on the base suit')
                g.left_out=g.left_out+1
            else
                if lead then
                    target:SetMasterPoseComponent(lead.target,false)
                    target.bUseBoundsFromMasterPoseComponent=true -- No culling pops apart from its leader.
                else
                    target:SetForcedLOD(1) -- LOD 0 always: no pops as the ghost walks away.
                    g.leaders=g.leaders+1
                end
                g.base=g.base+(based and 1 or 0)
                g.parts[part.i]={target=target,mesh=mesh,remap=remap}
                g.count=g.count+1
            end
        end
        for _,part in ipairs(remote.parts) do -- The table now: a part hung elsewhere meanwhile comes in the same one.
            if g.parts[part.i] then hang(g,part) end
        end
        -- The mailbox: unattached, never moved; only the native part writes its relative fields.
        g.mailbox=valid(actor:AddComponentByClass(find('/Script/Engine.SceneComponent'),true,identity,false))
        assert(g.mailbox,'the mailbox could not be added')
        local lines={'display '..t.generation,'mailbox '..hex(g.mailbox)..' '..hex(g.mailbox:GetClass())}
        for _,part in ipairs(t.parts) do
            local built=g.parts[part.i]
            if built and not part.lead then
                lines[#lines+1]=string.format('drive %d %s %s %s %d',part.i,hex(built.target),hex(built.target:GetClass()),
                    hex(built.mesh),built.target:GetNumBones())
                if built.remap then lines[#lines+1]='remap '..part.i..' '..table.concat(built.remap,' ') end
            end
        end
        local published,why=files.display(table.concat(lines,'\n')..'\n')
        g.built=true
        local line=string.format('Ghost %d built: %d parts (%d leaders), %d loaded in %.0f ms, %d on the base suit, %d left out%s',
            t.generation,g.count,g.leaders,counts.loaded,counts.ms,g.base,g.left_out,
            published and '' or '; display not published: '..tostring(why))
        if #notes>0 then line=line..'; '..table.concat(notes,'; ') end
        return line..string.format(' (%.0f ms in all).',(os.clock()-started)*1000)
    end
    local function resume(eve)
        local ok,result=coroutine.resume(build,eve)
        if not ok then
            failed=remote.generation -- Not again on this table: a new one, a level change or basesuit tries again.
            clear('build failed')
            return false,'Ghost not built: '..tostring(result)
        end
        if coroutine.status(build)=='dead' then build=nil; return true,result end
    end
    -- The same generation again: the parts hung elsewhere, shown or hidden are applied to the ghost in place.
    local function redress(old)
        local before={}
        for _,part in ipairs(old.parts) do before[part.i]=part end
        for _,part in ipairs(remote.parts) do
            local was=before[part.i]
            if ghost.parts[part.i] and (part.parent~=was.parent or part.socket~=was.socket or part.place~=was.place or
                part.shown~=was.shown) then
                hang(ghost,part)
            end
        end
    end
    -- From main.lua every 250 ms, after link.changes(): the remote table the native part holds (generation, count of
    -- tables it wrote, source), all nil when it has none.
    function self.remote(generation,count,from)
        source=from
        if not generation then
            seen_count=nil
            if not remote then return end
            remote,hidden_pair=nil,nil
            local message=clear('her table is gone')
            return message and true,message
        end
        if count==seen_count then return end
        seen_count=count
        local t=parse_remote(files.remote_table())
        if not t then return false,'The remote table could not be read.' end
        if remote and t.generation==remote.generation and layout(t)==layout(remote) then
            local old=remote
            remote=t
            if not (ghost and ghost.built) then return end -- A build in progress hangs its parts from the new one.
            local ok,why=pcall(redress,old)
            if not ok then failed=remote.generation; return false,clear('stopped: '..tostring(why)) end
            return
        end
        remote,failed,hidden_pair=t,nil,nil
        local message=clear('a new table')
        return message and true,message
    end
    function self.active() return wanted end
    function self.toggle()
        sweep()
        if wanted then
            wanted=false
            return true,clear('coop puppet') or 'Ghost off.'
        end
        wanted=true
        return true,(swept and swept..' ' or '')..'Ghost on: her capture goes to the native part, and a ghost is drawn '
            ..'once a table comes back (coop loopback 0 0 0 shows yours, coop replay a recording); coop puppet again ends it.'
    end
    -- Every part on the base suit where it has one (body and hair), or each on its own mesh again: rebuilt at once.
    function self.basesuit()
        basesuit=not basesuit
        failed=nil
        clear('basesuit')
        return true,basesuit and 'Base suit on: the body and hair are drawn on the base suit, driven by bone name.'
            or 'Base suit off: each part on its own mesh again.'
    end
    -- Ghost parts in the world that are not this Lua load's ghost (one the game restored would show here).
    local function strays()
        local count,ours=0,ghost and valid(ghost.actor) and address(ghost.actor)
        each(FindAllOf and FindAllOf('PoseableMeshComponent') or {},function(_,component)
            local owner=valid(component) and valid(component:GetOwner())
            if owner and address(owner)~=ours then count=count+1 end
        end)
        return count
    end
    function self.status()
        local stray=strays()
        local tail=stray>0 and string.format(' stray_parts=%d',stray) or ''
        if not wanted then return 'ghost=off'..tail end
        if ghost and ghost.built then
            return string.format('ghost=on parts=%d leaders=%d basesuit=%d left_out=%d table=%d source=%s',ghost.count,
                ghost.leaders,basesuit and 1 or 0,ghost.left_out,ghost.generation,tostring(source))..tail
        end
        return (hidden_pair and 'ghost=hidden map' or 'ghost=waiting')..tail
    end
    -- After the native tick of the same frame: a new stamp in the mailbox is a pose just written, so the root takes its
    -- transform (2 m to the side in loopback) and the ghost shows; a second without one hides it (a stalled stream, or
    -- the native part refusing to draw), so it never stands frozen.
    function self.place()
        local g=ghost
        if not (wanted and g and g.built) then return end
        local ok,why=pcall(function()
            local box=g.mailbox
            local stamp=value_of(box.RelativeScale3D).Z
            if stamp>1 and stamp~=g.stamp then
                g.stamp,g.stamp_at=stamp,os.clock()
                local at,rotation=value_of(box.RelativeLocation),value_of(box.RelativeRotation)
                local x,y=at.X,at.Y
                if source=='loopback' then -- Her right: Unreal is left-handed.
                    local yaw=math.rad(rotation.Yaw+capture.yaw_delta())
                    x,y=x-math.sin(yaw)*RIGHT,y+math.cos(yaw)*RIGHT
                end
                g.parts[0].target:K2_SetWorldLocationAndRotation({X=x,Y=y,Z=at.Z},
                    {Pitch=rotation.Pitch,Yaw=rotation.Yaw,Roll=rotation.Roll},false,{},true)
                if g.hidden then g.actor:SetActorHiddenInGame(false); g.hidden=false end
            elseif not g.hidden and os.clock()-g.stamp_at>=1 then
                g.actor:SetActorHiddenInGame(true)
                g.hidden=true
            end
        end)
        if not ok then failed=g.generation; return false,clear('stopped: '..tostring(why)) end
    end
    local function her(eve) return eve and eve:IsA(find('/Script/SB.SBCharacter')) and eve or nil end
    -- Once per game-thread tick: nothing while the ghost is off. A level change removes the ghost; it is built again
    -- (or for a new table) once EVE has been in the world 2 s and she is on the table's map.
    function self.tick()
        sweep()
        if not wanted then return end
        local eve=her(valid(UE.GetPlayer()))
        if ghost and (not eve or address(eve)~=ghost.eve or not valid(ghost.actor)) then
            clear('level changed')
            back_since,failed=nil,nil
        end
        if build then return resume() end
        if ghost or not remote then return end
        if not eve then back_since=nil; return end
        back_since=back_since or os.clock()
        if os.clock()-back_since<2 or failed==remote.generation then return end
        -- Read each time, never kept by EVE's address: after travel her new EVE can stand where the freed one was.
        local map=U.map_of(eve)
        if remote.map~=map then
            local pair=remote.map..' '..map
            if pair==hidden_pair then return end
            hidden_pair=pair
            return true,string.format('Ghost hidden: she is on %s, you are on %s.',remote.map,map)
        end
        hidden_pair=nil
        build=coroutine.create(build_ghost)
        return resume(eve)
    end
    return self
end
return Puppet
