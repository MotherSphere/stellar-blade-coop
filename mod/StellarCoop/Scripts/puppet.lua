-- The ghost: a render-only EVE drawn from a component table (native/src/pose_table.h) the native part received, hers
-- back through the loopback or a replayed recording, or a friend's over Steam. A plain actor with one
-- PoseableMeshComponent per part and no collision: not a Pawn, so lock-on, AI and saves never see it, and nothing of it
-- is written to a save, an inventory or an unlock. Each part loads the mesh the table names (LoadAsset only brings a
-- cooked asset into memory: display only, nothing is worn) with its own default materials, so the ghost wears her
-- outfit. A mesh this PC lacks (a DLC it does not own), one the path rule refused ('-'), or one with other bones than
-- hers falls back to the base suit (body and hair), whose bones the native part drives by name (a remap); a part with
-- no fallback is left out, with its followers. Parts hang as the table says (parent part, socket, placement) and
-- followers follow their leader (SetMasterPoseComponent). No morphs: a neutral face. With look.cloth (on unless
-- coop-settings.txt says cloth=off, or coop look), a follower whose mesh has clothing assets (her ponytail) is a
-- SkeletalMeshComponent whose cloth swings on its leader's bones, as hers does in solo: the bones only anchor the
-- strands. Else it is a rigid Poseable like the rest, which draws her ponytail as one block. With look.dyes, a part
-- drawn on its own mesh takes the materials the table overrides (her hair colour), each one this PC has (the same path
-- rule as meshes, and a MaterialInterface); else, and on a fallback mesh, its mesh's own. With look.effects, her attack
-- and skill effects: the native part writes her four effect slots into boxes beside the mailbox, and place() starts the
-- Niagara system each names (an index into Capture.EFFECTS, never a path) on the part it hangs on, moves it with the
-- slot and stops it when the slot changes, at most 8 starts a second.
-- The build resolves one mesh a frame (a step a tick, never a coroutine), then names what it built for the native part
-- (coop-display.txt), which writes the leaders' bones each frame and the main mesh's world transform into the mailbox,
-- a scene component nothing moves; place() puts the root there after the native tick. A failed build is tried again
-- 2 s later, up to 3 tries in all, then said on screen. The ghost stays hidden until the first pose and after a second
-- without one, and is only built when she is on your map (a friend on another map is said on screen).
-- Above it, its name tag: whose ghost it is (her Steam name, or loopback, replay; Puppet.tag_text keeps it readable),
-- turned to the camera at each pose.
-- The same table again with a part hung elsewhere (a blade drawn) or shown or hidden is applied in place; a new
-- generation (her outfit) is a new ghost. The ghost's path is kept in a file, so the next Lua load (a hot reload)
-- finds and destroys one left standing; after a level change it comes back once EVE has been in the world 2 s.
-- collide=on adds one capsule that blocks your EVE alone (Puppet.solid); no other part of the ghost has collision.
-- In Doro mode (self.doro, coop race look) every part is hidden and a Doro (doro.lua) hangs on the main mesh, her feet,
-- animated from the speed of her feet between poses; the ghost's own hiding covers it too.
local UE=require('UEHelpers')
local U=require('unreal')
local T=require('ui_text')
local clean=require('chat').clean
local valid,value_of,each,text,find,address,hex,word=U.valid,U.value_of,U.each,U.text,U.find,U.address,U.hex,U.word
local Puppet={}
-- cm: in loopback the ghost is yours, so it walks 2 m to your right. The side is taken each time it shows and kept
-- while it shows: taken at each pose, a turn would swing the ghost around her and throw its cloth sideways.
local RIGHT=200
local TAG_SIZE,TAG_HEIGHT=18,200 -- cm: the name tag's letters, and its height above the main mesh (her feet).
local ABOVE=TAG_HEIGHT+20 -- cm: the UI marker's anchor above her feet, over the tag's place.
-- cm in one pose: a longer step of the root is a teleport (a fast travel, a respawn). 60 m/s at 30 FPS, above any of
-- her moves.
local TELEPORT=200
local KEEP_RELATIVE=0 -- EAttachmentRule::KeepRelative
local BASE_BODY='/Game/Art/Character/PC/CH_P_EVE_08/CH_P_EVE_08.CH_P_EVE_08'
local BASE_HAIR='/Game/Art/Character/PC/00_HR/EVE_HR_01/EVE_HR_01.EVE_HR_01'
local function fallback(part) return part.i==0 and BASE_BODY or part.name=='SBHair' and BASE_HAIR or nil end
local Doro=require('doro')
local EFFECTS=require('capture').EFFECTS -- What the wire's effect indexes name, for both players.
local NIAGARA_SYSTEM='/Script/Niagara.NiagaraSystem'
local MAX_STARTS=8 -- Effects started on one ghost in a second, at most: a peer's slots cannot flood the game.
local PHYSICS_ASSET='/Script/Engine.PhysicsAsset'
-- The solid partner (collide=on, off by default): one capsule on the ghost that only your EVE's movement meets. cm and
-- s, for Puppet.solid: inside her by more than SLACK, out again past LEAVE; feet STEP apart in height; contact within
-- TOUCH, STUCK of it with no gap of GAP, then free until PART apart.
local SLACK,LEAVE,STEP,TOUCH,STUCK,GAP,PART=1,20,60,5,2,0.5,50
local WALKS={[1]=true,[2]=true,[3]=true} -- EMovementMode: Walking, NavWalking, Falling.
local CHANGES={'solid','a','b','c','d','e','g'} -- The order status() counts the capsule's changes in.
-- Whether the solid partner's capsule blocks your EVE now: true, or false and the first rule that opens it.
-- i: on (collide=on), shown (the ghost shown, your EVE found), h and v (cm across and up or down between the centres
-- of her capsule and the ghost's, which sit as high above their feet), r and hh (the two radii and the two half
-- heights added), mode (your EVE's MovementMode), down (the friend's vitals missing or down; false for a replay or
-- the loopback, which have none) and now (s). k keeps the rules' state from one frame to the next.
-- a: on and shown. b: not inside her (h at least r - 1 cm, or v at least hh); once inside, open until h is past r + 20
-- cm, so the ghost walks through her (an overlap of 1 cm or less stays solid: her movement pushes her out). c: their
-- feet less than 60 cm apart in height (her on its head, a ladder, an elevator that moved in one world only). d: your
-- EVE walking or falling (swimming, climbing, a zipline pass). e: not 2 s of contact (h under r + 5 cm) with no gap of
-- 0.5 s, so a ghost stepping back for a pose cannot hold it; once tripped, open until 50 cm apart (a partner standing
-- in a doorway). g: the friend's vitals there and not down, so a downed friend is never a wall and can be reached for a
-- revive. No rule tells a dodge from a run yet: each contact's line (place()) logs what could.
function Puppet.solid(k,i)
    if not (i.on and i.shown) then
        k.inside,k.since,k.stuck=nil,nil,nil
        return false,'a'
    end
    if i.h<i.r-SLACK and i.v<i.hh then k.inside=true elseif i.h>i.r+LEAVE then k.inside=nil end
    if k.stuck and i.h>=i.r+PART then k.stuck=nil end
    local touch=i.h<i.r+TOUCH
    if k.since and not touch then k.gap=k.gap or i.now end
    if k.gap and i.now-k.gap>=GAP then k.since,k.gap=nil,nil end
    if touch then
        k.since,k.gap=k.since or i.now,nil
        if i.now-k.since>=STUCK then k.stuck=true end
    end
    if k.inside then return false,'b' end
    if i.v>=STEP then return false,'c' end
    if not WALKS[i.mode] then return false,'d' end
    if k.stuck then return false,'e' end
    if i.down then return false,'g' end
    return true
end
-- The partner card's rule (partner.lua): down in life state 3 to 5, or at 0 HP of a maximum above 0.
local function down(m) return m.life>=3 and m.life<=5 or m.hp==0 and m.max_hp>0 end
-- Her ponytail's AdditiveMasterBoneArray in her Blueprint: body bones its 22-bone mesh lacks and its cloth's collision
-- bodies hang on. SB's UpdateMasterBoneMap maps each to the leader's bone of that name.
local COLLISION_BONES={'Bip001-R-Thigh','Bip001-L-Thigh','Bip001-L-UpperArm','Bip001-L-Forearm','Bip001-R-UpperArm',
    'Bip001-R-Forearm','Bip001-Neck','Bip001-L-Calf','Bip001-R-Calf','Bip001-L-Foot','Bip001-R-Foot','Bip001-Head',
    'Bip001-Pelvis','Bip001-Spine','Bip001-Spine1','Bip001-Spine2','Ab-L-Thigh-Tw0','Ab-R-Thigh-Tw0'}
-- Her outfit's ponytail collision, named from her body mesh's path as ASBCharacter::SetOverrideClothPhysicsAsset
-- names it: <dir>/<mesh>_PonytailPhysicsAsset.<mesh>_PonytailPhysicsAsset. nil for a path that is not dir/name.object.
function Puppet.collision_path(path)
    local dir,name=tostring(path):match('^(/.+)/([^/.]+)%.[^/.]+$')
    return dir and string.format('%s/%s_PonytailPhysicsAsset.%s_PonytailPhysicsAsset',dir,name,name) or nil
end
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
-- The name tag's text. The tag sets no font, so the engine's default (RobotoDistanceField) draws it, Latin-1 only: a
-- character past U+00FF shows as '?'. Of the names given (her Steam name, then the partner card's word for her in the
-- player's language, then in English), the first that loses at most half its characters, or none for the words after
-- her name; each cleaned as the card cleans her name. nil when none does.
function Puppet.tag_text(...)
    for i=1,select('#',...) do
        local lost,count=0,0
        local shown=clean(select(i,...) or ''):gsub(utf8.charpattern,function(c)
            count=count+1
            if utf8.codepoint(c)<=0xFF then return c end
            lost=lost+1
            return '?'
        end)
        if count>0 and (lost==0 or i==1 and lost*2<=count) then return shown end
    end
end
-- link (nil without the native part): remote_table() -> coop-remote.txt's text, display(text|nil) publishes or
-- withdraws the display file, store() keeps the ghost's object path across Lua loads (save, load, clear), friend() her
-- Steam name. capture gives yaw_delta(), the loopback's offset. say(text,en) puts a line on screen (en: the same in
-- English); name_tag: the tag. look: what else the ghost shows ({cloth=,dyes=,effects=true|false}, read at each build;
-- nil: nothing more). words: the words for the screen now (ui_text.lua's T.en or T.fr; English when nil).
function Puppet.new(link,capture,say,name_tag,look,words)
    look=look or {}
    words=words or function() return T.en end
    local files=link or {remote_table=function() end,display=function() return false,'no native part' end}
    local store=link and link.store() or {save=function() end,load=function() end,clear=function() end}
    local self,wanted,basesuit={},false,false
    local remote,seen_count,source=nil,nil,nil -- The remote table, the status count it was read at, where it came from.
    local unread -- The count whose file could not be read: read again at each call, said once.
    local ghost -- The ghost, built or being built (then ghost.steps holds the steps left).
    local back_since,hidden_pair,her_at=nil,nil,nil
    local failed,tries=nil,0 -- After a failure: when her table may be built again (os.clock; math.huge: not by itself).
    local said_pair -- The map pair last said on screen: a new table on it (an outfit, a new EVE) says nothing.
    local cache={} -- Meshes and materials by class and path; false: none this Lua load (a missing DLC stays missing).
    local doro_on,doro_log,doro_emote=false,nil,nil -- Doro mode, where its [DR] lines go, the race's emote.
    local doro_top=nil -- While a race drives: its top speed (cm/s), for her Doro's dash, play rate and tilt.
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
    -- then shown or hidden (hidden in Doro mode).
    local function hang(g,part)
        local built=g.parts[part.i]
        if part.i>0 then
            local parent=g.parts[part.parent] or g.parts[0]
            built.target:K2_AttachToComponent(parent.target,FName(part.socket or 'None'),KEEP_RELATIVE,KEEP_RELATIVE,
                KEEP_RELATIVE,false)
            built.target:K2_SetRelativeTransform(transform(part.place),false,{},true)
        end
        built.target:SetVisibility(part.shown and not doro_on,false)
    end
    -- Doro mode on a built ghost: its Doro on part 0 (added or removed), each part shown as the table says unless in
    -- Doro mode. SetVisibility leaves the children alone: the Doro and the name tag stay drawn.
    local function doro_dress(g)
        if doro_on and not g.doro then
            g.doro,g.doro_state,g.doro_from=Doro.attach(g.actor,g.parts[0].target),{},nil
        elseif not doro_on and g.doro then
            local d=g.doro
            g.doro=nil
            d.mesh:K2_DestroyComponent(g.actor)
        end
        for _,part in ipairs(remote.parts) do
            local built=g.parts[part.i]
            if built then built.target:SetVisibility(part.shown and not doro_on,false) end
        end
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
        -- Her outfit's collision on her ponytail's cloth, set up before its leader and its mesh as SB does: the body
        -- bones its collision bodies hang on, mapped from the leader when it is set, then the outfit's asset, which
        -- the cloth takes when SetSkeletalMesh creates it (RecreateClothingActors). A failure keeps the clothing
        -- asset's own collision, said in the build line.
        local function collide(target,part)
            local ok,why=pcall(function()
                for k,name in ipairs(COLLISION_BONES) do target.AdditiveMasterBoneArray[k]=FName(name) end
                local asset=g.collision and resolve(g.collision,counts,PHYSICS_ASSET) -- Cached by its own step.
                if not asset then error(tostring(g.collision or 'her body mesh\'s collision name')..' missing',0) end
                target.OverrideClothPhysicsAsset=asset
            end)
            if not ok then
                notes[#notes+1]=string.format('%s: outfit collision not used (%s)',part.name,tostring(why))
            end
        end
        -- Your EVE's render flags, as on every EVE part in her Blueprint: lighting channels 0 and 1 (SB's character
        -- lights use 1) and custom depth with stencil 10 (ESBCustomDepthStencilValue::PC). Each its own pcall: one
        -- refused leaves the others set, and is said once a build.
        local function light(target)
            for _,set in ipairs({function() target:SetLightingChannels(true,true,false) end,
                function() target:SetRenderCustomDepth(true) end,
                function() target:SetCustomDepthStencilValue(10) end}) do
                local ok,why=pcall(set)
                if not (ok or g.unlit) then
                    g.unlit=true
                    notes[#notes+1]='solo render flags not set ('..tostring(why)..')'
                end
            end
            return target
        end
        local function add(mesh,part)
            -- A follower with cloth is a SkeletalMeshComponent: NvCloth reads its master's component-space bones
            -- with no class check, so its cloth swings on the Poseable leader's (SetMasterPoseComponent, set before
            -- its mesh so the cloth is created on the leader's bones, as SB sets up its slots).
            -- Never BindClothToMasterPoseComponent: that binds to the leader's own cloth, and a Poseable has none.
            if look.cloth and part.lead and clothed(mesh) then
                local target
                local made,why=pcall(function()
                    target=valid(actor:AddComponentByClass(find('/Script/Engine.SkeletalMeshComponent'),false,identity,
                        false))
                    assert(target,'a cloth part could not be added')
                    target:SetCollisionEnabled(0)
                    -- OnlyTickPoseWhenRendered: the engine's cloth tick skips the solve while the ghost is hidden, off
                    -- screen or behind a wall (up to 1 s after its last render), and resets the cloth to its bones
                    -- when it is drawn again. SB sets the same on her own ponytail during its Show sequences.
                    target.VisibilityBasedAnimTickOption=3
                    target.bLocalSpaceSimulation=true -- As hers: the cloth's inertia comes from its frame's moves.
                    if part.name:find('Ponytail',1,true) then collide(target,part) end
                    target:SetMasterPoseComponent(g.parts[part.lead].target,false)
                    target:SetSkeletalMesh(mesh,true)
                end)
                if made then g.cloth[#g.cloth+1]=target; return light(target) end
                if target then pcall(function() target:K2_DestroyComponent(actor) end) end
                notes[#notes+1]=string.format('%s: cloth not used (%s), drawn as a plain part',part.name,tostring(why))
            end
            local target=valid(actor:AddComponentByClass(poseable,false,identity,false)) -- The first is the root.
            assert(target,'a ghost part could not be added')
            target:SetCollisionEnabled(0)
            target:SetSkeletalMesh(mesh,true) -- Its own materials, unless dyed below.
            return light(target)
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
            if part.i==0 and look.cloth then -- Her outfit's ponytail collision, from her body as drawn: its own step.
                g.collision=Puppet.collision_path(mesh:GetFullName():match('^%S+ (.+)$'))
                if g.collision then soon(function() resolve(g.collision,counts,PHYSICS_ASSET) end) end
            end
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
        -- Doro mode: its mesh found or loaded in a step of its own, never with another one.
        if doro_on then
            g.steps[#g.steps+1]=function() Doro.resolve(Doro.ASSETS.mesh,'/Script/Engine.SkeletalMesh') end
        end
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
                    tag:K2_SetText(FText(Puppet.tag_text(whose(),words().partner.partner,T.en.partner.partner)))
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
            -- Doro mode: a Doro that cannot be made leaves the ghost drawn as her, said in the build line.
            if doro_on then
                local made,why=pcall(function() g.doro,g.doro_state=Doro.attach(actor,g.parts[0].target),{} end)
                if not made then
                    doro_on=false
                    notes[#notes+1]='Doro mode off ('..tostring(why)..')'
                end
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
        if tries==3 then say(words().ghost.failed,T.en.ghost.failed) end
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
            seen_count,unread=nil,nil
            if not remote then return end
            remote,hidden_pair,said_pair=nil,nil,nil
            local message=clear('her table is gone')
            return message and true,message
        end
        if count==seen_count then return end
        local t=parse_remote(files.remote_table())
        if not t then
            if count==unread then return end
            unread=count
            return false,'The remote table could not be read.'
        end
        seen_count=count
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
    -- collide=on (main.lua, every 250 ms): the solid partner's capsule, built the first time the ghost shows with it on
    -- and closed while it is off. eve_now: your EVE, as tick() found her this frame.
    local collide,eve_now=false,nil
    function self.collide(on) collide=on==true end
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
    -- Doro mode on or off (coop race look), kept across rebuilds and new tables; log takes its [DR] lines. Returns
    -- false, why when the Doro could not be made: the ghost is then drawn as her.
    function self.doro(on,log)
        on=on==true
        doro_log=log or doro_log
        if on==doro_on then return end
        doro_on=on
        local g=ghost
        if not (g and g.built) then return end
        local ok,why=pcall(doro_dress,g)
        if ok then return end
        doro_on=false
        pcall(doro_dress,g)
        return false,'Doro mode off on the ghost: '..tostring(why)
    end
    -- The race's results on her Doro: 'win' or 'lose' while she stands (Doro.pick), nil for none.
    function self.emote(e) doro_emote=e end
    -- While a race drives: its top speed, so her Doro dashes, plays and leans by it as yours does; nil after.
    function self.drive(top) doro_top=top end
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
            -- collide=: off or on, then the capsule closed or solid and its changes counted by what made them.
            local s,solid=ghost.capsule,' collide='..(collide and 'on' or 'off')
            if s==false then
                solid=' collide=failed'
            elseif s then
                local changes={}
                for _,key in ipairs(CHANGES) do
                    if s.changes[key] then changes[#changes+1]=key..':'..s.changes[key] end
                end
                solid=string.format('%s solid=%d changes=%s',solid,s.on and 1 or 0,
                    #changes>0 and table.concat(changes,',') or 'none')
            end
            return string.format('ghost=on parts=%d leaders=%d basesuit=%d left_out=%d table=%d source=%s%s',
                ghost.count,ghost.leaders,basesuit and 1 or 0,ghost.left_out,ghost.generation,tostring(source),
                solid)..tail
        end
        return (hidden_pair and 'ghost=hidden map' or 'ghost=waiting')..tail
    end
    -- One field that fails says why in place ('?(...)'), without the error's file and line (in the game a path that
    -- alone fills the 60 characters): the rest of the line still prints.
    local function try(f)
        local ok,v=pcall(f)
        return ok and v or '?('..tostring(v):gsub('^.-:%d+: ',''):sub(1,60)..')'
    end
    -- The solid partner's capsule on the ghost (collide=on): your EVE's capsule's size, as high above the ghost's feet
    -- as hers is above her own, hung on its main mesh and upright whatever the mesh's tilt. Of her capsule's object
    -- type and blocking that type alone (WorldDynamic, which her capsule blocks, if hers does not block its own type),
    -- so monsters, NPCs, the camera and every trace pass through it; no overlap events; never a step. Closed (no
    -- collision) until place() finds it may block, and the ghost's only collision: its parts have none, its tag and
    -- any effect started on it get none. A failure while it is set up removes it. Returns the line for the log: her
    -- capsule as read, the camera boom's probe channel, and the ghost's other parts with collision on (0 expected).
    local function solid_body(g,eve)
        local cap=eve.CapsuleComponent
        local channel=cap:GetCollisionObjectType()
        local response=cap:GetCollisionResponseToChannel(channel)
        local ours=response==2 and channel or 1 -- ECR_Block; else ECC_WorldDynamic.
        local up=-value_of(eve.Mesh.RelativeLocation).Z
        local radius,half=cap:GetUnscaledCapsuleRadius(),cap:GetUnscaledCapsuleHalfHeight()
        local c=valid(g.actor:AddComponentByClass(find('/Script/Engine.CapsuleComponent'),false,
            find('/Script/Engine.Default__KismetMathLibrary'):MakeTransform({X=0,Y=0,Z=0},{Pitch=0,Yaw=0,Roll=0},
            {X=1,Y=1,Z=1}),false)) -- On the root, its main mesh.
        assert(c,'the capsule could not be added')
        c:SetCollisionEnabled(0) -- First: whatever fails next, it never blocks.
        local made,why=pcall(function()
            c:K2_SetRelativeLocation({X=0,Y=0,Z=up},false,{},true)
            c:SetAbsolute(false,true,false)
            c:SetCapsuleSize(radius,half,false)
            c:SetGenerateOverlapEvents(false)
            c:SetCollisionObjectType(ours)
            c:SetCollisionResponseToAllChannels(0) -- ECR_Ignore
            c:SetCollisionResponseToChannel(channel,2)
            c.CanCharacterStepUpOn=0 -- ECB_No
            if g.tag then g.tag:SetCollisionEnabled(0) end
            g.actor:SetActorEnableCollision(true,false)
        end)
        if not made then
            pcall(function() c:K2_DestroyComponent(g.actor) end)
            error(why,0)
        end
        g.capsule={c=c,up=up,r=2*radius,hh=2*half,k={},on=false,changes={}}
        local probe=try(function()
            return valid(eve:GetComponentByClass(find('/Script/Engine.SpringArmComponent'))).ProbeChannel
        end)
        local others=try(function()
            local n=0
            each(g.actor:K2_GetComponentsByClass(find('/Script/Engine.PrimitiveComponent')),function(_,p)
                p=valid(p)
                if p and address(p)~=address(c) and p:K2_IsCollisionEnabled() then n=n+1 end
            end)
            return n
        end)
        return string.format('Solid partner built: her capsule type %s response %s, radius %g, half height %g, %g cm '
            ..'above her feet; ours type %s; camera probe channel %s; other parts with collision %s.',tostring(channel),
            tostring(response),radius,half,up,tostring(ours),tostring(probe),tostring(others))
    end
    -- One frame of the solid partner, after the ghost was placed: its capsule built the first time it shows with
    -- collide on, then Puppet.solid on where both stand now, and the capsule closed or made solid on a change only.
    -- The start of a contact (within 5 cm, again once more than 20 cm apart) gives one line: her speed across,
    -- GetMaxSpeed(), her MovementMode and her move's root motion data, to tell a dodge from a run.
    local function solidity(g)
        local eve=valid(eve_now)
        local line
        if not g.capsule then
            if g.hidden or not eve then return nil end
            line=solid_body(g,eve)
        end
        local s=g.capsule
        local i,touch={on=collide,shown=not g.hidden and eve~=nil,now=os.clock()},false
        if i.on and i.shown then
            local at,f=value_of(eve:K2_GetActorLocation()),g.feet
            i.h,i.v,i.r,i.hh=math.sqrt((at.X-f.X)^2+(at.Y-f.Y)^2),math.abs(at.Z-f.Z-s.up),s.r,s.hh
            i.mode=eve.CharacterMovement.MovementMode
            local m=source=='peer' and files.mate and files.mate()
            i.down=source=='peer' and (not m or down(m))
            if i.h<s.r+TOUCH then
                touch,s.touching=not s.touching,true
            elseif i.h>s.r+LEAVE then
                s.touching=nil
            end
        else
            s.touching=nil
        end
        local on,rule=Puppet.solid(s.k,i)
        if on~=s.on then
            s.c:SetCollisionEnabled(on and 1 or 0) -- QueryOnly: her movement's sweeps are queries.
            s.on=on
            local key=on and 'solid' or rule
            s.changes[key]=(s.changes[key] or 0)+1
        end
        if touch then
            local read,contact=pcall(function()
                local cmc=eve.CharacterMovement
                local v,data=value_of(cmc.Velocity),valid(cmc.RootMotionData.pRootMotionData)
                return string.format('Solid partner contact: speed=%.0f max=%.0f mode=%s root_motion=%s solid=%d',
                    math.sqrt(v.X^2+v.Y^2),cmc:GetMaxSpeed(),tostring(i.mode),data and text(data:GetFName()) or 'none',
                    on and 1 or 0)
            end)
            contact=read and contact or 'Solid partner contact: not read ('..tostring(contact)..')'
            line=line and line..' '..contact or contact
        end
        return line
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
        if g.capsule then slot.fx:SetCollisionEnabled(0) end -- The capsule stays the ghost's only collision.
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
    -- Doro mode, at each pose: her speed and vertical speed from her feet over at least 50 ms (os.clock may step by
    -- whole ms), the same mapping as your own Doro's but with no sprint or falling flag; a teleport starts it again
    -- from standing. While a race drives, its lean and landing pitch from her yaw and feet, as a turn of the Doro on
    -- her main mesh. Her speed is logged once a second.
    local function feed(g,jump)
        local now,f,from=os.clock(),g.feet,g.doro_from
        local drive=doro_top and {top=doro_top,yaw=g.yaw or 0}
        local c,speed
        if jump or not from then
            g.doro_state,g.doro_from={},{X=f.X,Y=f.Y,Z=f.Z,at=now}
            c=Doro.pick(g.doro_state,{speed=0,vz=0,emote=doro_emote,now=now,drive=drive})
        else
            local dt=now-from.at
            if dt<0.05 then return end
            speed=math.sqrt((f.X-from.X)^2+(f.Y-from.Y)^2)/dt
            g.doro_from={X=f.X,Y=f.Y,Z=f.Z,at=now}
            c=Doro.pick(g.doro_state,{speed=speed,vz=(f.Z-from.Z)/dt,emote=doro_emote,now=now,drive=drive})
        end
        Doro.apply(g.doro,c)
        if c.tilt or g.doro_tilted then
            g.doro.mesh:K2_SetRelativeRotation(Doro.tilted({Pitch=0,Yaw=0,Roll=0},c.tilt),false,{},false)
            g.doro_tilted=c.tilt~=nil
        end
        if speed and doro_log and now>=(g.doro_said or 0) then
            g.doro_said=now+1
            doro_log(string.format('ghost doro speed=%.0f',speed))
        end
    end
    -- After the native tick of the same frame: a new stamp in the mailbox is a pose just written, so the root takes its
    -- transform (2 m to the side in loopback) and the ghost shows; a second without one hides it (a stalled stream, or
    -- the native part refusing to draw), so it never stands frozen. The name tag turns to the camera at each new pose.
    -- Each time it shows, its cloth starts again from the pose it shows in, never stretched from where it was. While it
    -- shows, the root moves without the teleport flag: the flag reaches a cloth part through the attachment and clears
    -- its inertia, so the strands would hang and never trail. Hidden, or a step over TELEPORT, it teleports. A new
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
                    if g.hidden or not g.side then g.side=math.rad(rotation.Yaw+capture.yaw_delta()) end
                    x,y=x-math.sin(g.side)*RIGHT,y+math.cos(g.side)*RIGHT
                end
                -- ponytail: one distance threshold, add a rotation threshold if a snap turn throws the tail.
                local f=g.feet
                local jump=g.hidden or not f or (x-f.X)^2+(y-f.Y)^2+(at.Z-f.Z)^2>TELEPORT^2
                g.parts[0].target:K2_SetWorldLocationAndRotation({X=x,Y=y,Z=at.Z},
                    {Pitch=rotation.Pitch,Yaw=rotation.Yaw,Roll=rotation.Roll},false,{},jump)
                g.feet,g.yaw={X=x,Y=y,Z=at.Z},rotation.Yaw
                if g.doro then -- Its own pcall: a failure ends Doro mode (the ghost drawn as her), never the ghost.
                    local fed,doro_why=pcall(feed,g,jump)
                    if not fed then
                        doro_on=false
                        pcall(doro_dress,g)
                        said[#said+1]='Doro mode off on the ghost: '..tostring(doro_why)
                    end
                end
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
                if g.tag and not g.tag_fixed then -- Its own pcall: a failure stops the turning only, for this ghost.
                    local turned,tag_why=pcall(function()
                        local camera=value_of(UE.GetPlayerController().PlayerCameraManager:GetCameraLocation())
                        g.tag:K2_SetWorldRotation({Pitch=0,Yaw=U.yaw_to({X=x,Y=y},camera),Roll=0},false,{},true)
                    end)
                    if not turned then
                        g.tag_fixed=true -- g.tag kept: the veils and the capsule still reach it.
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
        -- The solid partner, in its own pcall: a failure leaves this ghost without it (closed), never stops the ghost.
        local line
        if g.capsule~=false and (collide or g.capsule) then
            local ran,result=pcall(solidity,g)
            if ran then
                line=result
            else
                if g.capsule then pcall(function() g.capsule.c:SetCollisionEnabled(0) end) end
                g.capsule=false
                said[#said+1]='Solid partner off on this ghost: '..tostring(result)
            end
        end
        if #said>0 then return false,table.concat(said,' ') end
        if line then return true,line end
    end
    local function her(eve) return eve and eve:IsA(find('/Script/SB.SBCharacter')) and eve or nil end
    -- Whether a save is loaded: EVE on any map but the title screen's. The link holds an accepted invite until then.
    -- Second: whether the title screen is shown, a pawn of any class on its map (never during a loading screen, which
    -- has no pawn); the native part changes the co-op saves only then. The same read keeps where she stands and her
    -- map for the partner HUD (me()).
    local me=nil
    local TITLE='/game/lobby/lobby'
    function self.world()
        me=nil
        local ok,loaded,title=pcall(function()
            local pawn=valid(UE.GetPlayer())
            local eve=her(pawn)
            if not eve then return false,pawn~=nil and U.map_of(pawn)==TITLE end
            local map,at=U.map_of(eve),value_of(eve:K2_GetActorLocation())
            me={at={X=at.X,Y=at.Y,Z=at.Z},map=map}
            return map~=TITLE,map==TITLE
        end)
        return ok and loaded,ok and title
    end
    -- Our EVE as of the last world(): {at={X,Y,Z}, map=}, or nil.
    function self.me() return me end
    local CAMPS={'Env_VendingMachine_C','Env_VendingMachine_Simple_C','Env_Camp_TeleportMachine_C',
        'Env_Camp_TeleportMachine_Tetrapod_C'} -- Leaf classes: exact whether FindAllOf returns subclasses or not.
    local function xyz(v) return string.format('%.1f,%.1f,%.1f',v.X,v.Y,v.Z) end
    local function metres(a,b) return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)/100 end
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
        eve_now=eve
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
                local hers,ours=remote.map:match('[^/]*$'),map:match('[^/]*$')
                local function away(w) return w.ghost.away:format(whose(),hers,ours) end
                say(away(words()),away(T.en))
            end
            return true,string.format('Ghost hidden: she is on %s, you are on %s.',remote.map,map)
        end
        hidden_pair,said_pair=nil,nil
        return step(eve)
    end
    return self
end
return Puppet
