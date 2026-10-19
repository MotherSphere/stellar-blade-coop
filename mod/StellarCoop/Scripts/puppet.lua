-- The ghost: a render-only EVE drawn from a component table (native/src/pose_table.h) the native part received, hers
-- back through the loopback or a replayed recording, or a friend's over Steam. A plain actor with one
-- PoseableMeshComponent per part and no collision: not a Pawn, so lock-on, AI and saves never see it, and nothing of it
-- is written to a save, an inventory or an unlock. Each part loads the mesh the table names (LoadAsset only brings a
-- cooked asset into memory: display only, nothing is worn) with its own default materials, so the ghost wears her
-- outfit. A mesh this PC lacks (a DLC it does not own), one the path rule refused ('-'), or one with other bones than
-- hers falls back to the base suit (body and hair), whose bones the native part drives by name (a remap); a part with
-- no fallback is left out, with its followers. Parts hang as the table says (parent part, socket, placement) and
-- followers follow their leader (SetMasterPoseComponent). No morphs: a neutral face. With look.cloth (cloth=on in
-- coop-settings.txt, or coop look), a follower whose mesh has clothing assets (her ponytail) is a SkeletalMeshComponent
-- whose cloth swings on its leader's bones; else it is a rigid Poseable like the rest. With look.dyes, a part drawn on
-- its own mesh takes the materials the table overrides (her hair colour), each one this PC has (the same path rule as
-- meshes, and a MaterialInterface); else, and on a fallback mesh, its mesh's own. With look.effects, her attack and
-- skill effects: the native part writes her four effect slots into boxes beside the mailbox, and place() starts the
-- Niagara system each names (an index into Capture.EFFECTS, never a path) on the part it hangs on, moves it with the
-- slot and stops it when the slot changes, at most 8 starts a second.
-- The build resolves one mesh a frame (a step a tick, never a coroutine), then names what it built for the native part
-- (coop-display.txt), which writes the leaders' bones each frame and the main mesh's world transform into the mailbox,
-- a scene component nothing moves; place() puts the root there after the native tick. A failed build is tried again
-- 2 s later, up to 3 tries in all, then said on screen. The ghost stays hidden until the first pose and after a second
-- without one, and is only built when she is on your map (a friend on another map is said on screen).
-- Above it, its name tag: whose ghost it is (her Steam name, or loopback, replay), turned to the camera at each pose.
-- The same table again with a part hung elsewhere (a blade drawn) or shown or hidden is applied in place; a new
-- generation (her outfit) is a new ghost. The ghost's path is kept in a file, so the next Lua load (a hot reload)
-- finds and destroys one left standing; after a level change it comes back once EVE has been in the world 2 s.
local UE=require('UEHelpers')
local U=require('unreal')
local valid,value_of,each,text,find,address,hex,word=U.valid,U.value_of,U.each,U.text,U.find,U.address,U.hex,U.word
local Puppet={}
local RIGHT=200 -- cm: in loopback the ghost is yours, so it walks 2 m to your right.
local TAG_SIZE,TAG_HEIGHT=18,200 -- cm: the name tag's letters, and its height above the main mesh (her feet).
local ABOVE=TAG_HEIGHT+20 -- cm: the UI marker's anchor above her feet, over the tag's place.
local KEEP_RELATIVE=0 -- EAttachmentRule::KeepRelative
local BASE_BODY='/Game/Art/Character/PC/CH_P_EVE_08/CH_P_EVE_08.CH_P_EVE_08'
local BASE_HAIR='/Game/Art/Character/PC/00_HR/EVE_HR_01/EVE_HR_01.EVE_HR_01'
local function fallback(part) return part.i==0 and BASE_BODY or part.name=='SBHair' and BASE_HAIR or nil end
local EFFECTS=require('capture').EFFECTS -- What the wire's effect indexes name, for both players.
local NIAGARA_SYSTEM='/Script/Niagara.NiagaraSystem'
local MAX_STARTS=8 -- Effects started on one ghost in a second, at most: a peer's slots cannot flood the game.
-- coop-remote.txt as the native part writes it (format_table), read strictly: nil on anything else. Parts are listed
-- in order, each with i (its index), lead and parent (indexes, nil for '-'), socket and path (nil for '-'), shown,
-- bones, name, place (its 10 numbers as written), materials ({slot=, path=}, slots rising) and a leader's names.
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
    local generation=take('^generation (%d+)$') -- tonumber() of no value at all raises: take it first.
    local t={generation=tonumber(generation),map=take('^map (%S+)$'),parts={}}
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
        part.materials={}
        while true do
            local index,slot,path=take('^material (%d+) (%d+) (%S+)$')
            if not index then break end
            local last=part.materials[#part.materials]
            slot=tonumber(slot)
            if tonumber(index)~=part.i or slot>63 or last and slot<=last.slot or #part.materials==16 then return nil end
            part.materials[#part.materials+1]={slot=slot,path=path}
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
-- withdraws the display file, store() keeps the ghost's object path across Lua loads (save, load, clear), friend() her
-- Steam name. capture gives yaw_delta(), the loopback's offset. say(text) puts a line on screen; name_tag: the tag.
-- look: what else the ghost shows ({cloth=,dyes=,effects=true|false}, read at each build; nil: nothing more).
function Puppet.new(link,capture,say,name_tag,look)
    look=look or {}
    local files=link or {remote_table=function() end,display=function() return false,'no native part' end}
    local store=link and link.store() or {save=function() end,load=function() end,clear=function() end}
    local self,wanted,basesuit={},false,false
    local remote,seen_count,source=nil,nil,nil -- The remote table, the status count it was read at, where it came from.
    local ghost -- The ghost, built or being built (then ghost.steps holds the steps left).
    local back_since,hidden_pair,her_at=nil,nil,nil
    local failed,tries=nil,0 -- After a failure: when her table may be built again (os.clock; math.huge: not by itself).
    local said_pair -- The map pair last said on screen: a new table on it (an outfit, a new EVE) says nothing.
    local cache={} -- Meshes and materials by class and path; false: none this Lua load (a missing DLC stays missing).
    -- Whose ghost: a friend's Steam name, else where her table comes from ('loopback', 'replay').
    local function whose() return source=='peer' and files.friend() or tostring(source) end
    local function clear(why)
        local g=ghost
        ghost=nil
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
    -- An asset of a class (a SkeletalMesh unless said) by its object path: in memory already (StaticFindObject), else
    -- loaded (LoadAsset, synchronous on this thread); nil when neither gives one of that class. A cached one nothing
    -- referenced may have been collected since, and its address reused: it is used again only while it is still that.
    local function resolve(path,counts,class)
        class=class or '/Script/Engine.SkeletalMesh'
        local key=class..' '..path -- A peer naming a mesh as a material spoils neither.
        if cache[key]==false then return nil end
        local asset=valid(cache[key] or nil)
        if asset and asset:IsA(find(class)) and asset:GetFullName():match('^%S+ (.+)$')==path then return asset end
        local started=os.clock()
        asset=valid(StaticFindObject(path))
        if not asset then
            local ok,loaded=pcall(LoadAsset,path)
            asset=ok and valid(loaded) or nil
        end
        if asset and not asset:IsA(find(class)) then asset=nil end
        cache[key]=asset or false
        counts.loaded,counts.ms=counts.loaded+1,counts.ms+(os.clock()-started)*1000
        return asset
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
    -- The build's first frame: spawns the hidden actor and lists the steps, one per part (and per listed effect), each
    -- resolving at most one mesh or material. tick() runs one step a frame, and g.finish() in the frame of the last
    -- one: the name tag, the mailbox (and the effect boxes), the hanging and the display file; it returns the build's
    -- line for the log. Never a coroutine: UE4SS refuses any call from a lua_State it did not create
    -- (process_lua_function, lua_instances), and a coroutine is one.
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
            hidden=true,stamp=1,stamp_at=0,cloth={},dyed=0,fx_stamp=1,fx_starts={},steps={}}
        ghost=g
        actor:SetActorHiddenInGame(true) -- Until the first pose: never her reference pose at the spawn spot.
        actor:SetActorEnableCollision(false,false)
        store.save(actor:GetFullName():match('^%S+ (.+)$'))
        local counts,notes={loaded=0,ms=0},{}
        -- A step for the next frame (k: the k-th next), before the steps listed earlier.
        local function soon(f,k) table.insert(g.steps,k or 1,f) end
        local function clothed(mesh) -- A read that fails counts as no clothing assets.
            local ok,n=pcall(function() local n=0; each(mesh.MeshClothingAssets,function() n=n+1 end); return n end)
            return ok and n>0
        end
        local function add(mesh,part)
            -- A follower with cloth is a SkeletalMeshComponent: NvCloth reads its master's component-space bones
            -- with no class check, so its cloth swings on the Poseable leader's (SetMasterPoseComponent, below).
            -- Never BindClothToMasterPoseComponent: that binds to the leader's own cloth, and a Poseable has none.
            if look.cloth and part.lead and clothed(mesh) then
                local target
                local made,why=pcall(function()
                    target=valid(actor:AddComponentByClass(find('/Script/Engine.SkeletalMeshComponent'),false,identity,
                        false))
                    assert(target,'a cloth part could not be added')
                    target:SetCollisionEnabled(0)
                    target:SetSkeletalMesh(mesh,true)
                    target.bLocalSpaceSimulation=true -- Its own space: place() moves the root by teleports.
                end)
                if made then g.cloth[#g.cloth+1]=target; return target end
                if target then pcall(function() target:K2_DestroyComponent(actor) end) end
                notes[#notes+1]=string.format('%s: cloth not used (%s), drawn as a plain part',part.name,tostring(why))
            end
            local target=valid(actor:AddComponentByClass(poseable,false,identity,false)) -- The first is the root.
            assert(target,'a ghost part could not be added')
            target:SetCollisionEnabled(0)
            target:SetSkeletalMesh(mesh,true) -- Its own materials, unless dyed below.
            return target
        end
        -- One of the table's materials on a part drawn on its own mesh (a fallback's slots are another mesh's): a step
        -- each, resolved and set in the same frame, as a mesh is.
        local function dye(target,part,m)
            local material=resolve(m.path,counts,'/Script/Engine.MaterialInterface')
            if material and m.slot<target:GetNumMaterials() then
                target:SetMaterial(m.slot,material)
                g.dyed=g.dyed+1
            else
                notes[#notes+1]=string.format('%s: slot %d material %s missing, default kept',part.name,m.slot,m.path)
            end
        end
        -- A part drawn (based: on its fallback's mesh, remap: a leader's bones by name).
        local function keep(part,target,mesh,based,remap)
            local lead=part.lead and g.parts[part.lead]
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
        local function left_out(part)
            assert(part.i>0,'her body could not be drawn, not even on the base suit')
            g.left_out=g.left_out+1
        end
        -- A part on its fallback's mesh, for a leader with its remap; left out when that one is missing too.
        local function on_base(part,base,why)
            local mesh=resolve(base,counts)
            if not mesh then return left_out(part) end
            local target=add(mesh,part)
            if part.lead then
                notes[#notes+1]=string.format('%s: %s %s, drawn as %s',part.name,part.path or '-',why,base)
                return keep(part,target,mesh,true)
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
            keep(part,target,mesh,true,remap)
        end
        -- One part's step: the table's mesh, then its dyes a step each; else its fallback's (a step of its own when the
        -- table's was resolved in this one); left out with neither, or when its leader was.
        local function dress(part)
            if part.lead and not g.parts[part.lead] then return left_out(part) end
            local base,why=fallback(part),'missing'
            if basesuit and base then
                why='replaced (basesuit)'
            elseif part.path then
                -- Resolved and added in the same frame, so a freshly loaded mesh nothing holds yet cannot be collected
                -- in between.
                local mesh=resolve(part.path,counts)
                if mesh then
                    local target=add(mesh,part)
                    if part.lead or target:GetNumBones()==part.bones then
                        if look.dyes then
                            for k,m in ipairs(part.materials) do soon(function() dye(target,part,m) end,k) end
                        end
                        return keep(part,target,mesh)
                    end
                    why=string.format('has %d bones, not %d',target:GetNumBones(),part.bones)
                    target:K2_DestroyComponent(actor) -- Never re-point it: a mesh of the same count would keep stale bones.
                end
                if base then return soon(function() on_base(part,base,why) end) end
            end
            if base then on_base(part,base,why) else left_out(part) end
        end
        for _,part in ipairs(t.parts) do g.steps[#g.steps+1]=function() dress(part) end end
        -- Her effects: the listed systems, a step each. One failing ends the build there, without effects.
        local fx_loaded,fx_why=0,nil
        if look.effects then
            for _,path in ipairs(EFFECTS) do
                g.steps[#g.steps+1]=function() -- Only effect steps are left: a failure drops them all.
                    local ok,system=pcall(resolve,path,counts,NIAGARA_SYSTEM)
                    if ok then fx_loaded=fx_loaded+(system and 1 or 0) else fx_why,g.steps=system,{} end
                end
            end
        end
        function g.finish()
            -- The name tag, on the main mesh, so it moves, hides and goes with the ghost. A tag that fails is only left
            -- out.
            local tag_off=''
            if name_tag then
                local tag
                local made,why=pcall(function()
                    tag=U.label(actor,TAG_SIZE)
                    tag:K2_AttachToComponent(g.parts[0].target,FName('None'),KEEP_RELATIVE,KEEP_RELATIVE,KEEP_RELATIVE,
                        false)
                    tag:K2_SetRelativeLocation({X=0,Y=0,Z=TAG_HEIGHT},false,{},true)
                    tag:K2_SetText(FText(whose()))
                end)
                if made then
                    g.tag=tag
                else
                    -- Else it reads the engine's 'Text'.
                    if tag then pcall(function() tag:K2_DestroyComponent(actor) end) end
                    tag_off='; name tag off: '..tostring(why)
                end
            end
            -- The mailbox: unattached, never moved; only the native part writes its relative fields.
            g.mailbox=valid(actor:AddComponentByClass(find('/Script/Engine.SceneComponent'),true,identity,false))
            assert(g.mailbox,'the mailbox could not be added')
            -- Her effects: the listed systems (resolved in the steps), the library that starts them, and four slot
            -- boxes beside the mailbox that only the native part writes. Anything failing leaves the ghost without
            -- effects only.
            local effects
            if look.effects then
                local made,why=pcall(function()
                    if fx_why then error(fx_why,0) end
                    g.fx_lib=find('/Script/Niagara.Default__NiagaraFunctionLibrary')
                    local slots,scene={},find('/Script/Engine.SceneComponent')
                    for n=1,4 do
                        local box=valid(actor:AddComponentByClass(scene,true,identity,false))
                        assert(box,'an effect box could not be added')
                        slots[n]={box=box}
                    end
                    g.slots,effects=slots,string.format('effects loaded %d of %d',fx_loaded,#EFFECTS)
                end)
                if not made then effects='effects off ('..tostring(why)..')' end
            end
            -- The table now, at the last step: a part hung elsewhere meanwhile comes in the same one.
            for _,part in ipairs(remote.parts) do
                if g.parts[part.i] then hang(g,part) end
            end
            local lines={'display '..t.generation,'mailbox '..hex(g.mailbox)..' '..hex(g.mailbox:GetClass())}
            if g.slots then
                local boxes={}
                for n,slot in ipairs(g.slots) do boxes[n]=hex(slot.box) end
                lines[#lines+1]='effects '..table.concat(boxes,' ')
            end
            for _,part in ipairs(t.parts) do
                local built=g.parts[part.i]
                if built and not part.lead then
                    lines[#lines+1]=string.format('drive %d %s %s %s %d',part.i,hex(built.target),
                        hex(built.target:GetClass()),hex(built.mesh),built.target:GetNumBones())
                    if built.remap then lines[#lines+1]='remap '..part.i..' '..table.concat(built.remap,' ') end
                end
            end
            local published,why=files.display(table.concat(lines,'\n')..'\n')
            g.built=true
            local line=string.format('Ghost %d built: %d parts (%d leaders), %d loaded in %.0f ms, %d on the base '
                ..'suit, %d left out%s%s',
                t.generation,g.count,g.leaders,counts.loaded,counts.ms,g.base,g.left_out,
                published and '' or '; display not published: '..tostring(why),tag_off)
            local looks={}
            if look.cloth then looks[#looks+1]=string.format('cloth parts %d',#g.cloth) end
            if look.dyes then looks[#looks+1]=string.format('dyed slots %d',g.dyed) end
            if look.effects then looks[#looks+1]=effects end
            if #looks>0 then line=line..'; look: '..table.concat(looks,', ') end
            if #notes>0 then line=line..'; '..table.concat(notes,'; ') end
            return line..string.format(' (%.0f ms in all).',(os.clock()-started)*1000)
        end
    end
    -- A failed build or ghost: her table is built again 2 s later, 3 tries in all, then not by itself (said on screen).
    -- A new table, a new EVE, coop puppet on or a rebuild tries again.
    local function retry()
        tries=tries+1
        failed=tries<3 and os.clock()+2 or math.huge
        if tries==3 then say('Ghost failed 3 times: the reason is in UE4SS.log.') end
    end
    -- One frame of the build, on the game thread: build_ghost(eve) first, then a step, and finish() after the last.
    local function step(eve)
        local ok,line=pcall(function()
            if eve then return build_ghost(eve) end
            table.remove(ghost.steps,1)()
            if not ghost.steps[1] then ghost.steps=nil; return ghost.finish() end
        end)
        if ok then return line and true,line end
        clear('build failed')
        retry()
        return false,'Ghost not built: '..tostring(line)
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
            remote,hidden_pair,said_pair=nil,nil,nil
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
            if not ok then retry(); return false,clear('stopped: '..tostring(why)) end
            return
        end
        remote,failed,tries,hidden_pair=t,nil,0,nil
        local message=clear('a new table')
        return message and true,message
    end
    -- During our own photo mode (main.lua, every 250 ms): ghost_off hides the ghost (photo_ghost=off), tag_off its name
    -- tag (photo_name_tag=off), until it ends; place() applies them.
    local veil_ghost,veil_tag,marked=false,false,false
    function self.photo(ghost_off,tag_off) veil_ghost,veil_tag=ghost_off,tag_off end
    -- The UI marker carries her name (main.lua, every 250 ms: partner_bar on and the UI's root up): the tag hides, and
    -- is the fallback again once it goes (UI-DESIGN D-UI5). place() applies it.
    function self.marker(on) marked=on==true end
    -- Where the UI marker goes: 2.2 m over her feet, and her feet, both as placed at her last pose; nil while the ghost
    -- is hidden or not built.
    function self.anchor()
        local g=ghost
        if wanted and g and g.built and not g.hidden and g.feet then
            return {X=g.feet.X,Y=g.feet.Y,Z=g.feet.Z+ABOVE},g.feet
        end
    end
    -- Her map's package path, from her table; nil without one.
    function self.her_map() return remote and remote.map end
    function self.active() return wanted end
    function self.toggle()
        sweep()
        if wanted then
            wanted=false
            return true,clear('coop puppet') or 'Ghost off.'
        end
        wanted,failed,tries=true,nil,0 -- A table whose build failed is tried again.
        return true,(swept and swept..' ' or '')..'Ghost on: her capture goes to the native part, and a ghost is drawn '
            ..'once a table comes back (a linked friend\'s; coop loopback 0 0 0 shows yours, coop replay a recording); '
            ..'coop puppet again ends it.'
    end
    -- The ghost removed to be built again at once (a failed table too): what it is drawn with changed.
    function self.rebuild(why)
        failed,tries=nil,0
        return clear(why)
    end
    -- Every part on the base suit where it has one (body and hair), or each on its own mesh again: rebuilt at once.
    function self.basesuit()
        basesuit=not basesuit
        self.rebuild('basesuit')
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
    -- A slot's effect started on its part, or why not (nil when started).
    local function start(g,slot,asset,part,at,rotation)
        local now=os.clock()
        while g.fx_starts[1] and now-g.fx_starts[1]>=1 do table.remove(g.fx_starts,1) end
        local built=g.parts[part]
        if not EFFECTS[asset] then return string.format('asset %g is not in the list',asset) end
        if not built then return string.format('part %g is not drawn',part) end
        if #g.fx_starts>=MAX_STARTS then return 'over '..MAX_STARTS..' a second' end
        local system=resolve(EFFECTS[asset],{loaded=0,ms=0},NIAGARA_SYSTEM) -- Cached, checked to be still itself.
        if not system then return string.format('spawn failed: asset %g is missing',asset) end
        g.fx_starts[#g.fx_starts+1]=now
        slot.fx=valid(g.fx_lib:SpawnSystemAttached(system,built.target,FName('None'),at,rotation,
            0 --[[KeepRelativeOffset]],true,true,0 --[[no pooling]],true))
        if not slot.fx then return 'spawn failed: nothing spawned' end
    end
    -- Each slot as the native part wrote its box (scale: asset + 1, part + 1, serial + 1; location and rotation
    -- relative to the part): a new key stops the slot's instance and starts the new one; the same key moves the one
    -- playing, so an effect hung on a socket (a kick trail) follows. Returns why the first refused one was.
    local function show_effects(g)
        local refused
        for _,slot in ipairs(g.slots) do
            local s=value_of(slot.box.RelativeScale3D)
            local asset,part=s.X-1,s.Y-1
            local key=string.format('%g:%g:%g',asset,part,s.Z-1)
            local l,r=value_of(slot.box.RelativeLocation),value_of(slot.box.RelativeRotation)
            local at,rotation={X=l.X,Y=l.Y,Z=l.Z},{Pitch=r.Pitch,Yaw=r.Yaw,Roll=r.Roll}
            local playing=valid(slot.fx)
            if key==slot.key then
                if playing then playing:K2_SetRelativeLocationAndRotation(at,rotation,false,{},true) end
            else
                slot.key,slot.fx=key,nil
                if playing then playing:Deactivate() end
                if asset~=0 then local why=start(g,slot,asset,part,at,rotation); refused=refused or why end
            end
        end
        return refused
    end
    -- After the native tick of the same frame: a new stamp in the mailbox is a pose just written, so the root takes its
    -- transform (2 m to the side in loopback) and the ghost shows; a second without one hides it (a stalled stream, or
    -- the native part refusing to draw), so it never stands frozen. The name tag turns to the camera at each new pose.
    -- Each time it shows, its cloth starts again from the pose it shows in, never stretched from where it was. A new
    -- effects stamp in the mailbox is a slot box just written: only then are the boxes read. Our photo mode's veils
    -- (self.photo) keep the ghost or its tag out of the shot.
    function self.place()
        local g=ghost
        if not (wanted and g and g.built) then return end
        local said={} -- What stopped on this ghost (its cloth, its tag turning, its effects): each is said once.
        local ok,why=pcall(function()
            local box=g.mailbox
            local s=value_of(box.RelativeScale3D)
            local stamp=s.Z
            local veiled=veil_tag or marked
            if g.tag and (g.tag_veiled==true)~=veiled then
                g.tag:SetVisibility(not veiled,false)
                g.tag_veiled=veiled
            end
            if veil_ghost and not g.hidden then
                g.actor:SetActorHiddenInGame(true)
                g.hidden=true
            end
            if stamp>1 and stamp~=g.stamp then
                g.stamp,g.stamp_at=stamp,os.clock()
                local at,rotation=value_of(box.RelativeLocation),value_of(box.RelativeRotation)
                g.seen={x=at.X,y=at.Y,z=at.Z,yaw=rotation.Yaw,at=os.clock()} -- For coop where: hers, before any offset.
                local x,y=at.X,at.Y
                if source=='loopback' then -- Her right: Unreal is left-handed.
                    local yaw=math.rad(rotation.Yaw+capture.yaw_delta())
                    x,y=x-math.sin(yaw)*RIGHT,y+math.cos(yaw)*RIGHT
                end
                g.parts[0].target:K2_SetWorldLocationAndRotation({X=x,Y=y,Z=at.Z},
                    {Pitch=rotation.Pitch,Yaw=rotation.Yaw,Roll=rotation.Roll},false,{},true)
                g.feet={X=x,Y=y,Z=at.Z}
                if g.hidden and not veil_ghost then
                    g.actor:SetActorHiddenInGame(false)
                    g.hidden=false
                    local reset,reset_why=pcall(function()
                        for _,part in ipairs(g.cloth) do part:ForceClothNextUpdateTeleportAndReset() end
                    end)
                    if not reset then -- Its cloth still simulates (only a rebuild removes it): said as it is.
                        g.cloth={}
                        said[#said+1]='Cloth reset failed: '..tostring(reset_why)..'; this ghost\'s cloth still '
                            ..'simulates but is never reset again (coop look cloth off removes it)'
                    end
                end
                if g.tag then -- Its own pcall: a failure stops the turning only, for this ghost, and never the ghost.
                    local turned,tag_why=pcall(function()
                        local camera=value_of(UE.GetPlayerController().PlayerCameraManager:GetCameraLocation())
                        g.tag:K2_SetWorldRotation({Pitch=0,Yaw=U.yaw_to({X=x,Y=y},camera),Roll=0},false,{},true)
                    end)
                    if not turned then
                        g.tag=nil
                        said[#said+1]='Name tag no longer turned to the camera: '..tostring(tag_why)
                    end
                end
            elseif not g.hidden and os.clock()-g.stamp_at>=1 then
                g.actor:SetActorHiddenInGame(true)
                g.hidden=true
            end
            if g.slots and s.X~=g.fx_stamp then
                g.fx_stamp=s.X
                local shown,fx_why=pcall(show_effects,g) -- Its own pcall: a failure stops effects, never the ghost.
                if not shown then
                    for _,slot in ipairs(g.slots) do -- None left looping.
                        pcall(function() local fx=valid(slot.fx); if fx then fx:Deactivate() end end)
                    end
                    g.slots=nil
                    said[#said+1]='Effects off on this ghost: '..tostring(fx_why)
                elseif fx_why and not g.fx_said then
                    g.fx_said=true
                    said[#said+1]='Effect not shown: '..fx_why
                end
            end
        end)
        if not ok then retry(); return false,clear('stopped: '..tostring(why)) end
        if #said>0 then return false,table.concat(said,' ') end
    end
    local function her(eve) return eve and eve:IsA(find('/Script/SB.SBCharacter')) and eve or nil end
    -- Whether a save is loaded: EVE on any map but the title screen's. The link holds an accepted invite until then.
    -- The same read keeps where she stands and her map for the partner HUD (me()).
    local me=nil
    function self.world()
        me=nil
        local ok,loaded=pcall(function()
            local eve=her(valid(UE.GetPlayer()))
            if not eve then return false end
            local map,at=U.map_of(eve),value_of(eve:K2_GetActorLocation())
            me={at={X=at.X,Y=at.Y,Z=at.Z},map=map}
            return map~='/game/lobby/lobby'
        end)
        return ok and loaded
    end
    -- Our EVE as of the last world(): {at={X,Y,Z}, map=}, or nil.
    function self.me() return me end
    local CAMPS={'Env_VendingMachine_C','Env_VendingMachine_Simple_C','Env_Camp_TeleportMachine_C',
        'Env_Camp_TeleportMachine_Tetrapod_C'} -- Leaf classes: exact whether FindAllOf returns subclasses or not.
    local function xyz(v) return string.format('%.1f,%.1f,%.1f',v.X,v.Y,v.Z) end
    local function metres(a,b) return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)/100 end
    -- One field that fails says why in place ('?(...)'), without the error's file and line (in the game a path that
    -- alone fills the 60 characters): the rest of the line still prints.
    local function try(f)
        local ok,v=pcall(f)
        return ok and v or '?('..tostring(v):gsub('^.-:%d+: ',''):sub(1,60)..')'
    end
    -- The nearest valid object of these classes to at: '<id>:<class>@x,y,z <unit>=<metres>', or 'none'.
    local function nearest(classes,at,id,unit)
        local best,line=nil,'none'
        for _,class in ipairs(classes) do
            each(FindAllOf(class) or {},function(_,a)
                a=valid(a)
                if not a then return end
                local p=value_of(a:K2_GetActorLocation())
                local d=metres(p,at)
                if not best or d<best then best,line=d,string.format('%s:%s@%s %s=%.1f',id(a),class,xyz(p),unit,d) end
            end)
        end
        return line
    end
    -- coop where: one line to compare between the two PCs (camps and spawn points are placed in the levels, so their
    -- ids and positions match on both; a map can stream every camp out, Spire IV does, while its spawn points stay
    -- loaded). FindAllOf walks every object: on demand only, never per tick. Needs neither a link nor a ghost.
    function self.where()
        local eve=her(valid(UE.GetPlayer()))
        if not eve then return false,'no EVE in the world' end
        local at,map=value_of(eve:K2_GetActorLocation()),U.map_of(eve)
        -- The mailbox holds her main mesh's transform, not her actor's: yaw= is the mesh's too, comparable with ghost_yaw=
        -- (her actor's differs by capture's yaw_delta).
        local body=valid(eve.Mesh)
        local mesh=value_of(body:K2_GetComponentLocation())
        local camp=try(function() return nearest(CAMPS,at,function(a) return text(a.EnvActorName) end,'camp_m') end)
        local spawn=try(function()
            return nearest({'SBSpawnPoint'},at,function(a) return text(a.SpawnPointName) end,'spawn_m')
        end)
        local origin=try(function()
            local o=value_of(find('/Script/Engine.Default__GameplayStatics'):GetWorldOriginLocation(eve))
            return string.format('%d,%d,%d',o.X,o.Y,o.Z)
        end)
        local flags=try(function()
            local ws=eve:GetWorld():K2_GetWorldSettings()
            return 'composition='..tostring(ws.bEnableWorldComposition)
                ..' rebasing='..tostring(ws.bEnableWorldOriginRebasing)
        end)
        local s=ghost and ghost.seen
        local other=s and string.format('%s@%.1f,%.1f,%.1f ghost_yaw=%.1f ghost_m=%.2f ghost_age=%.1f',tostring(source),
            s.x,s.y,s.z,s.yaw,metres({X=s.x,Y=s.y,Z=s.z},mesh),os.clock()-s.at)
            or remote and (remote.map==map and 'waiting' or 'elsewhere:'..remote.map) or 'none'
        return true,string.format('where map=%s eve=%s yaw=%.1f mesh=%s camp=%s spawn=%s origin=%s %s ghost=%s',map,
            xyz(at),value_of(body:K2_GetComponentRotation()).Yaw,xyz(mesh),camp,spawn,origin,flags,other)
    end
    -- Once per game-thread tick: nothing while the ghost is off. A level change removes the ghost; it is built again
    -- (or for a new table) once EVE has been in the world 2 s and she is on the table's map.
    function self.tick()
        sweep()
        if not wanted then return end
        local eve=her(valid(UE.GetPlayer()))
        local at=eve and address(eve) or nil
        if at~=her_at then -- A new EVE (travel, a load) or none: the ghost goes, a failed table is tried again.
            her_at,back_since,failed,tries=at,nil,nil,0
            if ghost then clear('level changed') end
        elseif ghost and not valid(ghost.actor) then
            clear('level changed')
            back_since=nil
        end
        if ghost and ghost.steps then return step() end
        if ghost or not remote then return end
        if not eve then back_since=nil; return end
        back_since=back_since or os.clock()
        if os.clock()-back_since<2 or os.clock()<(failed or 0) then return end
        -- Read each time, never kept by EVE's address: after travel her new EVE can stand where the freed one was.
        local map=U.map_of(eve)
        if remote.map~=map then
            local pair=remote.map..' '..map
            if pair==hidden_pair then return end
            hidden_pair=pair
            -- A friend away is said on screen too, by the maps' last segments ('b07').
            if source=='peer' and pair~=said_pair then
                said_pair=pair
                say(string.format('%s is in %s, you are in %s.',whose(),remote.map:match('[^/]*$'),map:match('[^/]*$')))
            end
            return true,string.format('Ghost hidden: she is on %s, you are on %s.',remote.map,map)
        end
        hidden_pair,said_pair=nil,nil
        return step(eve)
    end
    return self
end
return Puppet
