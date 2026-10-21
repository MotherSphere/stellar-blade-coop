-- The ghost with fake UE4SS objects: built from the remote table one mesh a frame, each part on the mesh the table names
-- (LoadAsset, never SetMaterial) or on the base suit with a bone remap, left out with its followers when it has no
-- fallback; your EVE's render flags on each part; the display file; hidden until the first pose and after a second
-- without one; the root teleported only as it shows or steps over 2 m, so a cloth part keeps its inertia; the
-- loopback's offset; the map gate; the same table re-dressed in place; level change, comeback, the remote table gone,
-- basesuit, the sweep; a
-- mesh resolved and added in one frame, a cached mesh checked again, a failed table tried again (2 s apart, 3 times,
-- then said on screen), the strict table read; every UE4SS call on UE4SS's own Lua state, never in a coroutine;
-- a friend's ghost exactly at the mailbox, coop where's line, and whether a save is loaded; the name tag (whose ghost,
-- turned to the camera at each pose, left out alone when it fails), our photo mode hiding the ghost or its tag, the map
-- notice on screen, a title round trip; with
-- cloth on, the ponytail on a SkeletalMeshComponent with her outfit's collision (said when it cannot have it),
-- simulated only while drawn, its reset as the ghost shows, and a plain part when that fails;
-- with dyes on, the table's materials on the parts drawn on their own mesh, each resolved and set in one frame; with
-- effects on, the listed systems, the slot boxes beside the mailbox, and the effects started, moved and stopped from
-- them in place(), within their budget; with collide on, the solid partner's capsule and the rules that open it.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
-- UE4SS refuses any call from a lua_State it did not create (process_lua_function, lua_instances): a coroutine is one.
-- The tests run on the main thread, which stands for UE4SS's own states (its hook thread's callbacks). Level 3: the
-- error names the mod's line that called the fake, as the game's names unreal.lua:41.
local function ue4ss()
    local _,main=coroutine.running()
    if main then return end
    error('[process_lua_function] The lua state has no instance inside lua_instances unordered map',3)
end
local function fname(text) return {type=function() return 'FName' end,ToString=function() return text end} end
FName=function(text) ue4ss(); return fname(text) end
local next_address=0x1000
-- A fake UObject: each of its methods checks the Lua state first, whether given in fields, added or replaced later. The
-- methods live in a table of their own, so every assignment of one goes through __newindex.
local function object(name,fields,class_address)
    local methods={}
    local o=setmetatable({},{__index=methods,__newindex=function(t,k,v)
        if type(v)~='function' then return rawset(t,k,v) end
        methods[k]=function(...) ue4ss(); return v(...) end
    end})
    for k,v in pairs(fields or {}) do o[k]=v end
    next_address=next_address+0x100
    local at=next_address
    o.type=function() return 'UObject' end
    o.IsValid=function(self) return not self.destroyed end
    o.GetFName=function() return fname(name) end
    o.GetAddress=function() return at end
    o.GetClass=function() return {GetAddress=function() return class_address or 0xc1 end,type=function() return 'UObject' end} end
    return o
end
local invalid=object('Invalid',{destroyed=true}) -- What UE4SS returns for nothing found.
local BODY='/Game/Art/Character/PC/CH_P_EVE_52/CH_P_EVE_52_TypeB.CH_P_EVE_52_TypeB'
local FACE='/Game/Art/Character/PC/CH_P_EVE_Head/CH_P_EVE_Face_Jali3.CH_P_EVE_Face_Jali3'
local HAIR='/Game/DLC_2/Art/Character/PC/EVE_HR_Nikke_02/EVE_HR_Nikke_02.EVE_HR_Nikke_02'
local PONY='/Game/Art/Character/PC/CH_P_EVE_Hair/CH_P_EVE_Hair_PonyTail_2.CH_P_EVE_Hair_PonyTail_2'
local BLADE='/Game/Art/Character/Weapon/Sword/CH_W_Sword_01/CH_W_Sword_01.CH_W_Sword_01'
local NIER='/Game/DLC_1/Art/Character/PC/EVE_HR_Nier_01/EVE_HR_Nier_01.EVE_HR_Nier_01' -- A DLC this PC lacks.
local BASE_BODY='/Game/Art/Character/PC/CH_P_EVE_08/CH_P_EVE_08.CH_P_EVE_08'
local BASE_HAIR='/Game/Art/Character/PC/00_HR/EVE_HR_01/EVE_HR_01.EVE_HR_01'
local STATIC='/Game/Art/Character/PC/Rock/Rock.Rock'
local LONG_HAIR='/Game/Art/Character/PC/00_HR/EVE_HR_09/EVE_HR_09.EVE_HR_09'
local TWO_BLADE='/Game/Art/Character/Weapon/Sword/CH_W_Sword_02/CH_W_Sword_02.CH_W_Sword_02'
-- Meshes by path, with their bones; the body is in memory already, the rest only through LoadAsset.
local meshes,in_memory={},{[BODY]=true}
local function mesh(path,bones,skeletal)
    meshes[path]=object(path,{path=path,bones=bones or {}})
    meshes[path].IsA=function(_,class) return class.path=='/Script/Engine.SkeletalMesh' and skeletal~=false end
    meshes[path].GetFullName=function() return (skeletal~=false and 'SkeletalMesh ' or 'StaticMesh ')..path end
end
mesh(BODY,{'Root','Bip001','Bip001-Pelvis'})
mesh(FACE)
mesh(HAIR,{'Bip001-Head','Hair_01'})
mesh(PONY)
mesh(BLADE,{'Root'})
mesh(BASE_BODY,{'Root','Bip001','Spine','Bip001-Pelvis'})
mesh(BASE_HAIR,{'Bip001-Head','Other','Hair_01'})
mesh(STATIC,{},false)
mesh(LONG_HAIR,{'a','b','c','d','e'})
mesh(TWO_BLADE,{'Root','Tip'})
-- Materials: assets of another class, found by path the same way.
local SKIN='/Game/Art/Character/PC/CH_P_EVE_52/MI_EVE_52_Skin.MI_EVE_52_Skin'
local TYPE_B='/Game/Art/Character/PC/00_HR/EVE_HR_01/MI_EVE_HR_01_TypeB.MI_EVE_HR_01_TypeB'
local TYPE_C='/Game/Art/Character/PC/00_HR/EVE_HR_01/MI_EVE_HR_01_TypeC.MI_EVE_HR_01_TypeC'
for _,path in ipairs({SKIN,TYPE_B,TYPE_C}) do
    meshes[path]=object(path,{path=path})
    meshes[path].IsA=function(_,class) return class.path=='/Script/Engine.MaterialInterface' end
    meshes[path].GetFullName=function() return 'MaterialInstanceConstant '..path end
end
-- Her outfit's ponytail collision, a PhysicsAsset beside her body mesh; the base suit's is missing on this PC.
local COLLISION='/Game/Art/Character/PC/CH_P_EVE_52/CH_P_EVE_52_TypeB_PonytailPhysicsAsset.'
    ..'CH_P_EVE_52_TypeB_PonytailPhysicsAsset'
meshes[COLLISION]=object(COLLISION,{path=COLLISION})
meshes[COLLISION].IsA=function(_,class) return class.path=='/Script/Engine.PhysicsAsset' end
meshes[COLLISION].GetFullName=function() return 'PhysicsAsset '..COLLISION end
-- Clothing assets: the ponytail, a follower, and her hair, a leader.
meshes[PONY].MeshClothingAssets={object('ClothingAsset')}
meshes[HAIR].MeshClothingAssets={object('ClothingAsset')}
local lookups,loads=0,{} -- Mesh lookups (StaticFindObject on a /Game path) and LoadAsset's paths.
local frame=0 -- Each ghost.tick() reads the player once: the frame it runs in. A mesh keeps the frame it was resolved in.
LoadAsset=function(path)
    ue4ss()
    loads[#loads+1]=path
    if meshes[path] then meshes[path].resolved_at=frame end
    return meshes[path] or invalid
end

local spawned={}
local dyeable=false -- Parts take materials only once dyes are tested: until then a SetMaterial fails the build.
local fail_depth=false -- SetRenderCustomDepth refuses: the other render flags are still set.
local function poseable(actor)
    local p=object('Poseable',{calls={}},0xc2)
    function p:SetLightingChannels(a,b,c) self.channels={a,b,c} end
    function p:K2_IsCollisionEnabled() return self.calls.SetCollisionEnabled~=0 end
    function p:SetRenderCustomDepth(on) if fail_depth then error('no custom depth') end self.custom_depth=on end
    function p:SetCustomDepthStencilValue(v) self.stencil=v end
    for _,f in ipairs({'SetCollisionEnabled','SetMasterPoseComponent','SetForcedLOD'}) do
        p[f]=function(self,a) self.calls[f]=a end
    end
    function p:SetSkeletalMesh(m) self.mesh,self.added_at=m,frame end
    function p:GetNumBones() return #self.mesh.bones end
    function p:GetBoneName(j) return fname(self.mesh.bones[j+1]) end
    function p:SetVisibility(v) self.visible=v end
    function p:K2_SetWorldLocationAndRotation(at,r,sweep,_,teleport)
        assert(sweep==false,'Never a sweep')
        self.at,self.rot,self.teleport=at,r,teleport; self.moves=(self.moves or 0)+1
    end
    function p:K2_AttachToComponent(parent,socket,a,b,c) self.attached={parent=parent,socket=socket:ToString(),rules={a,b,c}} end
    function p:K2_SetRelativeTransform(t) self.relative=t end
    function p:K2_DestroyComponent(owner) assert(owner==actor,'DestroyComponent takes the owner'); self.destroyed=true end
    function p:IsA(class) return class.path=='/Script/Engine.PoseableMeshComponent' end
    function p:GetOwner() return actor end
    if dyeable then
        function p:GetNumMaterials() return 2 end
        function p:SetMaterial(slot,m)
            self.dyes=self.dyes or {}
            self.dyes[#self.dyes+1]={slot=slot,material=m,at=frame}
        end
    end
    return p -- No SetMaterial unless dyeable: a call fails the build, so the test.
end
-- A cloth part: a SkeletalMeshComponent with the same calls, plus the cloth reset; never bound to its leader's cloth.
-- order: its collision bones (the first written), its collision asset, its leader and its mesh, as they were set.
local fail_cloth,fail_reset,fail_array,skeletal_adds=nil,false,false,0 -- fail_cloth: 'add' or 'set'.
local function cloth_part(actor)
    local s=poseable(actor)
    s.cloth,s.order=true,{}
    local mt=getmetatable(s)
    local set=mt.__newindex
    mt.__newindex=function(t,k,v)
        if k=='OverrideClothPhysicsAsset' then t.order[#t.order+1]='override' end
        return set(t,k,v)
    end
    -- UE4SS's TArray: indexed from 1, resized when written past its end.
    s.AdditiveMasterBoneArray=setmetatable({},{__newindex=function(t,k,v)
        ue4ss()
        if fail_array then error('no array write') end
        assert(k==#t+1 and v:type()=='FName','Written in order, an FName each')
        if k==1 then s.order[#s.order+1]='bones' end
        rawset(t,k,v)
    end})
    function s:IsA(class) return class.path=='/Script/Engine.SkeletalMeshComponent' end
    function s:SetMasterPoseComponent(lead)
        self.calls.SetMasterPoseComponent=lead
        self.order[#self.order+1]='master'
    end
    function s:SetSkeletalMesh(m)
        if fail_cloth=='set' then error('no cloth mesh') end
        self.mesh,self.added_at=m,frame
        self.order[#self.order+1]='mesh'
    end
    function s:ForceClothNextUpdateTeleportAndReset()
        if fail_reset then error('no reset') end
        self.resets=(self.resets or 0)+1
    end
    function s:BindClothToMasterPoseComponent() error('a Poseable leader has no cloth to bind to') end
    return s
end
local fail_text,fail_color=false,false -- FText or FColor refuses its table: Lua to either is unproven in the game.
FText=function(text) ue4ss(); if fail_text then error('no FText') end return {text=text} end
local function text_render(actor)
    local l=object('TextRender',{},0xc3)
    for _,f in ipairs({'SetWorldSize','SetHorizontalAlignment','SetTextRenderColor','SetAbsolute',
        'SetCollisionEnabled'}) do
        l[f]=function(self,a) if f=='SetTextRenderColor' and fail_color then error('no FColor') end self[f]=a end
    end
    function l:K2_AttachToComponent(parent,socket) self.attached={parent=parent,socket=socket:ToString()} end
    function l:K2_SetRelativeLocation(at) self.relative=at end
    function l:K2_SetText(t) self.text=t.text end
    function l:K2_SetWorldRotation(r) self.rot=r; self.turns=(self.turns or 0)+1 end
    function l:SetVisibility(v,children) assert(children==false); self.visible=v; self.shows=(self.shows or 0)+1 end
    function l:K2_DestroyComponent(owner) assert(owner==actor,'DestroyComponent takes the owner'); self.destroyed=true end
    function l:K2_IsCollisionEnabled() return self.SetCollisionEnabled~=0 end -- The call's value once it was made.
    return l
end
-- The solid partner's capsule: every call kept in order, with its arguments; collision as last set. fail_capsule:
-- SetCapsuleSize refuses.
local fail_capsule=false
local function capsule_part(actor)
    local c=object('Capsule',{order={},args={},enabled={}},0xc4)
    for _,f in ipairs({'K2_SetRelativeLocation','SetAbsolute','SetCapsuleSize','SetGenerateOverlapEvents',
        'SetCollisionObjectType','SetCollisionResponseToAllChannels','SetCollisionResponseToChannel'}) do
        c[f]=function(self,...)
            if f=='SetCapsuleSize' and fail_capsule then error('no capsule size') end
            self.order[#self.order+1]=f; self.args[f]=table.pack(...)
        end
    end
    function c:SetCollisionEnabled(v)
        self.order[#self.order+1]='SetCollisionEnabled'
        self.enabled[#self.enabled+1]=v
    end
    function c:K2_IsCollisionEnabled() return (self.enabled[#self.enabled] or 1)~=0 end
    function c:K2_DestroyComponent(owner)
        assert(owner==actor,'DestroyComponent takes the owner')
        self.destroyed=true
    end
    return c
end
local fail_add,fail_label=false,false
local box_reads=0 -- Reads of an effect box's relative fields: place() reads them only on a new effects stamp.
local function effect_box()
    local fields={RelativeScale3D={X=1,Y=1,Z=1},RelativeLocation={X=0,Y=0,Z=0},RelativeRotation={Pitch=0,Yaw=0,Roll=0}}
    local box=object('EffectBox',{fields=fields},0x5c0)
    local mt=getmetatable(box)
    local methods=mt.__index
    mt.__index=function(_,key)
        if key:find('^Relative') then box_reads=box_reads+1; return fields[key] end
        return methods[key]
    end
    return box
end
local world=object('World',{SpawnActor=function(_,class,at)
    assert(class.path=='/Script/Engine.Actor' and at.X==1)
    local a=object('Ghost',{parts={},components={}})
    function a:SetActorEnableCollision(on,fast) self.collision={on,fast} end
    function a:SetActorHiddenInGame(hidden) self.hidden=hidden end
    function a:K2_GetComponentsByClass(c) -- Its primitives: the parts, the tag and the capsule.
        assert(c.path=='/Script/Engine.PrimitiveComponent')
        local list={}
        for _,added in ipairs(self.components) do if added.K2_IsCollisionEnabled then list[#list+1]=added end end
        return list
    end
    function a:AddComponentByClass(c,manual)
        if fail_add then return nil end
        local added
        if c.path=='/Script/Engine.CapsuleComponent' then
            assert(manual==false,'The capsule hangs on the root')
            added=capsule_part(self)
            self.capsule=added
        elseif c.path=='/Script/Engine.SceneComponent' then
            assert(manual==true,'The mailbox and the effect boxes are never attached')
            if self.mailbox then -- After it: an effect box.
                added=effect_box()
                self.boxes=self.boxes or {}
                self.boxes[#self.boxes+1]=added
            else
                added=object('Mailbox',{RelativeScale3D={X=1,Y=1,Z=1},RelativeLocation={X=0,Y=0,Z=0},
                    RelativeRotation={Pitch=0,Yaw=0,Roll=0}},0x5c0)
                self.mailbox=added
            end
        elseif c.path=='/Script/Engine.TextRenderComponent' then
            assert(manual==false)
            if fail_label then return nil end
            added=text_render(self)
            self.label=added
        elseif c.path=='/Script/Engine.SkeletalMeshComponent' then
            assert(manual==false)
            skeletal_adds=skeletal_adds+1
            if fail_cloth=='add' then return nil end
            added=cloth_part(self); self.parts[#self.parts+1]=added
        else
            assert(c.path=='/Script/Engine.PoseableMeshComponent' and manual==false)
            added=poseable(self); self.parts[#self.parts+1]=added
        end
        self.components[#self.components+1]=added
        return added
    end
    function a:K2_DestroyActor() self.destroyed=true end
    function a:K2_GetRootComponent() return self.components[1] end -- The first added, whatever its class.
    function a:GetFullName() return 'Actor /Game/Map.Map:PersistentLevel.Actor_'..#spawned end
    spawned[#spawned+1]=a
    return a
end,GetFullName=function() return 'World /Game/Art/BG/WorldMap/Level_P/E04.E04' end,
K2_GetWorldSettings=function() return {bEnableWorldComposition=false,bEnableWorldOriginRebasing=false} end})
-- EVE reads only: the ghost never writes to her.
local function eve_of(name,map_world,at)
    map_world=map_world and object('World',map_world)
    local e=object(name)
    if at then e.GetAddress=function() return at end end -- Where a freed EVE was.
    function e:IsA(class) return class.path=='/Script/SB.SBCharacter' end
    function e:GetWorld() return map_world or world end
    function e:K2_GetActorLocation() return {X=1,Y=2,Z=3} end
    function e:K2_GetActorRotation() return {Pitch=0,Yaw=90,Roll=0} end
    e.Mesh=object('CharacterMesh0',{K2_GetComponentLocation=function() return {X=1,Y=2,Z=-87} end,
        K2_GetComponentRotation=function() return {Pitch=0,Yaw=0,Roll=0} end}) -- Her actor's yaw minus 90.
    return setmetatable({},{__index=e,__newindex=function(_,key) error('the ghost wrote '..key..' on EVE',2) end})
end
local eve=eve_of('EVE')
local player=eve
local camera,camera_fails={X=-100,Y=100,Z=0},false
package.loaded.UEHelpers={GetPlayer=function() ue4ss(); frame=frame+1; return player end,GetPlayerController=function()
    ue4ss()
    if camera_fails then error('no player controller') end
    return {PlayerCameraManager={GetCameraLocation=function() return camera end}}
end}
local found_by_path={}
local niagara_lookups=0 -- Lookups of anything of Niagara: its classes, its library, the listed systems.
StaticFindObject=function(path)
    ue4ss()
    if path:find('Niagara',1,true) or path:find('^/Game/Art/FX/') then niagara_lookups=niagara_lookups+1 end
    if found_by_path[path] then return found_by_path[path] end
    if path:find('^/Game/') then
        lookups=lookups+1
        if not in_memory[path] then return invalid end
        meshes[path].resolved_at=frame
        return meshes[path]
    end
    local c=object(path,{path=path})
    if path=='/Script/Engine.Default__KismetMathLibrary' then c.MakeTransform=function() return 'identity' end end
    return c
end

-- The remote table as the native part writes it.
local function her_parts(o)
    o=o or {}
    return {
        {name='CharacterMesh0',path=o.body or BODY,names={'Root','Bip001','Bip001-Pelvis'},materials=o.body_materials},
        {name='Mesh_Face',lead=0,parent=0,path=FACE},
        {name='SBHair',parent=0,socket='Bip001-Head',path=o.hair or HAIR,names={'Bip001-Head','Hair_01'},
            place='0 0 0.707106769 0.707106769 1.5 -2 0.25 1 1 1',materials=o.hair_materials},
        {name='SBPonytail',lead=2,parent=2,shown=false,path=PONY},
        {name='SBSkeletalMeshComponent_7',parent=0,socket=o.socket or 'SC_SwordingPoint',shown=o.blade_shown,
            path=o.blade or BLADE,names={'Root'},place='0 0 0 1 10.25 0 1 1 1 1'},
        {name='Scabbard',lead=4,parent=4,path=PONY}, -- Follows the blade.
    }
end
local function remote_text(generation,parts,map)
    local lines={'SBT 9','generation '..generation,'map '..(map or '/game/art/bg/worldmap/level_p/e04')}
    for i,p in ipairs(parts) do
        lines[#lines+1]=string.format('part %d %s %s %s %d %d %s %s',i-1,p.lead or '-',p.parent or '-',p.socket or '-',
            p.shown==false and 0 or 1,p.names and #p.names or 0,p.name,p.path or '-')
        if i>1 then lines[#lines+1]='place '..(i-1)..' '..(p.place or '0 0 0 1 0 0 0 1 1 1') end
        for _,m in ipairs(p.materials or {}) do lines[#lines+1]=string.format('material %d %d %s',i-1,m[1],m[2]) end
        if p.names then lines[#lines+1]='names '..(i-1)..' '..table.concat(p.names,' ') end
    end
    return table.concat(lines,'\n')..'\n'
end
local remote_file,displays,stored,requests,said,said_en=nil,{},nil,{},{},{} -- said_en: the English given with each.
local friend_name='Kaanta' -- Her Steam name, as the link gives it.
local store={save=function(p) stored=p end,load=function() return stored end,clear=function() stored=nil end}
local link={remote_table=function() return remote_file end,store=function() return store end,
    display=function(text) displays[#displays+1]=text or 'withdrawn'; return true end,
    friend=function() return friend_name,true,false end,
    request=function(line) requests[#requests+1]=line; return true end} -- The ghost never asks the link anything.
local capture={yaw_delta=function() return 90 end} -- Her actor faces yaw 90 more than her mesh.
local Words=require('ui_text')
local words=Words.en -- The words for the screen (main.lua's: the game's language).
local function new(path_left,name_tag,look)
    stored=path_left
    package.loaded.puppet=nil
    return require('puppet').new(link,capture,function(text,en) said[#said+1]=text; said_en[#said]=en end,
        name_tag~=false,look,function() return words end)
end
local ghost=new(nil)
local count=0
local function send(generation,parts,source,map) -- The native part writes a table: a new count in its status.
    remote_file=remote_text(generation,parts,map)
    count=count+1
    return ghost.remote(generation,count,source or 'loopback')
end
-- Ticks until the build ends, checking that no frame resolves more than one mesh; returns its line.
local function build()
    for _=1,60 do
        local before=lookups
        local ok,message=ghost.tick()
        assert(lookups-before<=1,'One mesh resolved a frame at most')
        if message then return ok,message end
    end
    error('the build never ended')
end
local GAVE_UP='Ghost failed 3 times: the reason is in UE4SS.log.'
-- Fails the table's build 3 times, 2 s apart: then it is said on screen once and never tried again by itself.
local function give_up(gave_up)
    local said_before=#said
    fail_add=true
    for k=1,3 do
        local ok,message=build()
        assert(ok==false and message:find('^Ghost not built: '),message)
        clock=clock+2.5 -- Past the 2 s, never on their edge.
        assert(#said==said_before+(k<3 and 0 or 1),'Said once, after the 3rd')
    end
    fail_add=false
    assert(said[#said]==(gave_up or GAVE_UP),said[#said])
    assert(said_en[#said]==GAVE_UP,'Its English too, for the line above EVE')
    local spawned_before=#spawned
    for _=1,5 do assert(ghost.tick()==nil); clock=clock+2 end
    assert(#spawned==spawned_before,'Never a 4th time by itself')
end

assert(ghost.tick()==nil and ghost.status()=='ghost=off','Off: nothing')
send(500,her_parts())
assert(ghost.tick()==nil and #spawned==0,'Off: no ghost, even with a table')
local ok,message=ghost.toggle()
assert(ok and message:find('^Ghost on: ') and not message:find('runs coop puppet'),message)
assert(ghost.status()=='ghost=waiting')
assert(ghost.tick()==nil and #spawned==0,'EVE must have been in the world 2 s')
clock=clock+2
local frames=0
local before=lookups
repeat
    frames=frames+1
    local lookups_before=lookups
    ok,message=ghost.tick()
    assert(lookups-lookups_before<=1,'One mesh resolved a frame at most')
until message
assert(frames==7 and lookups-before==5,'Six parts, one a frame (the second ponytail mesh cached), then the hanging')
assert(ok and message:find('^Ghost 500 built: 6 parts %(3 leaders%), 5 loaded in %d+ ms, 0 on the base suit, 0 left out %(%d+ ms in all%)%.$'),message)
-- The body was in memory; every other mesh came through LoadAsset, by its path.
assert(table.concat(loads,' ')==table.concat({FACE,HAIR,PONY,BLADE},' '),table.concat(loads,' '))
local actor=spawned[1]
assert(actor.hidden==true,'Hidden until the first pose')
local root,face,hair,pony,blade,scabbard=table.unpack(actor.parts)
-- Each mesh is added in the frame it was found or loaded in, one frame after the other: nothing holds a fresh mesh
-- between two frames. The scabbard's is the ponytail's, cached.
for k,p in ipairs({root,face,hair,pony,blade}) do
    assert(p.added_at==p.mesh.resolved_at and p.added_at==root.added_at+k-1,'Resolved and added in the same frame: '..k)
end
assert(root.mesh==meshes[BODY] and root.calls.SetForcedLOD==1 and root.attached==nil and root.visible==true)
assert(face.calls.SetMasterPoseComponent==root and face.bUseBoundsFromMasterPoseComponent==true)
assert(face.attached.parent==root and face.attached.socket=='None' and face.relative.Rotation.W==1)
assert(hair.mesh==meshes[HAIR] and hair.attached.parent==root and hair.attached.socket=='Bip001-Head')
assert(hair.attached.rules[1]==0 and hair.attached.rules[2]==0 and hair.attached.rules[3]==0,'KeepRelative')
local r=hair.relative
assert(r.Rotation.Z==0.707106769 and r.Translation.X==1.5 and r.Translation.Y==-2 and r.Scale3D.Z==1)
assert(pony.calls.SetMasterPoseComponent==hair and pony.attached.parent==hair and pony.visible==false)
assert(blade.attached.socket=='SC_SwordingPoint' and blade.relative.Translation.X==10.25 and scabbard.attached.parent==blade)
assert(stored=='/Game/Map.Map:PersistentLevel.Actor_1','The path is kept for the next Lua load')
-- Each part drawn with your EVE's render flags: lighting channels 0 and 1, custom depth with stencil 10 (the player's).
for k,p in ipairs(actor.parts) do
    assert(p.channels[1]==true and p.channels[2]==true and p.channels[3]==false and p.custom_depth==true
        and p.stencil==10,'Render flags: part '..k)
end
-- The display file: each leader driven as it came.
local d=displays[#displays]:gsub('0x%x+','0xX')
assert(d=='display 500\nmailbox 0xX 0xX\ndrive 0 0xX 0xX 0xX 3\ndrive 2 0xX 0xX 0xX 2\ndrive 4 0xX 0xX 0xX 1\n',d)
assert(displays[#displays]:find('\nmailbox 0x%x+ 0x5c0\ndrive 0 '..string.format('0x%x',root.GetAddress())..' 0xc2 '
    ..string.format('0x%x',meshes[BODY].GetAddress())..' 3\n'),'The loaded mesh, not hers')
assert(ghost.status()=='ghost=on parts=6 leaders=3 basesuit=0 left_out=0 table=500 source=loopback collide=off',
    ghost.status())
-- The name tag: whose ghost (here her own, through the loopback), 2 m above the main mesh, never a part.
local tag=actor.label
assert(tag and tag.text=='loopback' and tag.attached.parent==root and tag.attached.socket=='None','Hung on the main mesh')
assert(tag.relative.X==0 and tag.relative.Y==0 and tag.relative.Z==200 and tag.SetWorldSize==18 and not tag.destroyed)
assert(actor.components[1]==root and actor.components[#actor.components]==actor.mailbox,'Before the mailbox, never root')
FindAllOf=function(class) assert(class=='PoseableMeshComponent'); return actor.parts end
assert(ghost.status():find('left_out=0 table=500 source=loopback collide=off$'),'No stray part: the tag is none')
FindAllOf=nil

-- Shown at the first pose, placed from the mailbox 2 m to her right in loopback; hidden a second after the last pose.
assert(ghost.place()==nil and actor.hidden and not root.moves,'No stamp yet: nothing')
assert(ghost.anchor()==nil,'Hidden: no anchor for the UI marker')
assert(ghost.her_map()=='/game/art/bg/worldmap/level_p/e04','Her map: the table\'s')
local box=actor.mailbox
box.RelativeScale3D.Z=5
box.RelativeLocation={X=100,Y=0,Z=30}
box.RelativeRotation={Pitch=0,Yaw=0,Roll=0}
ghost.place()
assert(actor.hidden==false and root.moves==1 and root.teleport==true,'Shown at the first stamp, by a teleport')
assert(math.abs(root.at.X-(100-200))<1e-6 and math.abs(root.at.Y)<1e-6 and root.at.Z==30,'Her right: mesh yaw 0 plus 90')
-- The UI marker's anchor: 2.2 m over where the root was put (the tag's 2 m and 20 cm), and her feet there.
local top,feet=ghost.anchor()
assert(math.abs(top.X+100)<1e-6 and math.abs(top.Y)<1e-6 and top.Z==250 and math.abs(feet.X+100)<1e-6 and feet.Z==30)
assert(tag.turns==1 and math.abs(tag.rot.Yaw-90)<1e-9 and tag.rot.Pitch==0 and tag.rot.Roll==0,'The tag faces the camera')
clock=clock+0.9
ghost.place()
assert(actor.hidden==false and root.moves==1,'The same stamp: not moved again, still shown')
clock=clock+0.1
ghost.place()
assert(actor.hidden==true,'A second without a pose: hidden, never frozen in view')
assert(ghost.anchor()==nil,'Hidden: no anchor')
box.RelativeScale3D.Z=6
camera={X=-100,Y=-100,Z=0}
ghost.place()
assert(actor.hidden==false and root.moves==2)
assert(tag.turns==2 and math.abs(tag.rot.Yaw+90)<1e-9,'Turned again at each new pose, only then')
-- Our own photo mode: photo_ghost=off hides the ghost while it lasts, poses or not, and photo_name_tag=off its tag; the
-- ghost comes back with the next pose once it ends, the tag at once. Never veiled, the tag was never touched.
assert(not tag.shows)
ghost.photo(true,true)
ghost.place()
assert(actor.hidden==true and tag.visible==false and root.moves==2,'At once, no pose needed')
box.RelativeScale3D.Z=6.5
ghost.place()
assert(actor.hidden==true and root.moves==3 and root.teleport==true and tag.shows==1,'Still placed, still hidden')
ghost.photo(false,true)
box.RelativeScale3D.Z=6.6
ghost.place()
assert(actor.hidden==false and tag.visible==false and tag.shows==1,'The ghost in the shot, its tag not')
ghost.photo(false,false)
ghost.place()
assert(tag.visible==true and tag.shows==2)
-- The UI marker up (main.lua: partner_bar on, the UI's root shown) carries her name: the tag hides, and is back at
-- once when the marker goes (the UI off or failed, partner_bar off). The photo veil still counts.
ghost.marker(true)
ghost.place()
assert(tag.visible==false and tag.shows==3 and actor.hidden==false)
ghost.place()
assert(tag.shows==3,'On change only')
ghost.photo(false,true)
ghost.marker(false)
ghost.place()
assert(tag.visible==false and tag.shows==3,'Still veiled')
ghost.photo(false,false)
ghost.place()
assert(tag.visible==true and tag.shows==4)
-- Shown, the root moves without a teleport, which would clear a cloth part's inertia at each pose; the first pose after
-- a hide (above) and a step over 2 m in one pose (a fast travel, a respawn) are teleports.
assert(root.teleport==true,'Shown again after the photo: a teleport')
local function pose_at(stamp,at) box.RelativeScale3D.Z,box.RelativeLocation=stamp,at; ghost.place() end
pose_at(6.7,{X=105,Y=0,Z=30})
assert(root.teleport==false and math.abs(root.at.X+95)<1e-6,'5 cm on: moved, no teleport')
pose_at(6.8,{X=105,Y=0,Z=230})
assert(root.teleport==false and root.at.Z==230,'2 m up: not over 2 m, no teleport')
pose_at(6.9,{X=606,Y=0,Z=230})
assert(root.teleport==true and math.abs(root.at.X-406)<1e-6,'5.01 m on: a teleport')
pose_at(6.93,{X=606,Y=0,Z=30})
assert(root.teleport==false,'Back to small steps')
pose_at(6.96,{X=100,Y=0,Z=30})
assert(root.teleport==true,'Back where it was, 5 m away: a teleport')
-- In loopback the side is kept while the ghost shows: her turn moves it neither around her nor by a teleport. The side
-- is taken again when it shows again.
box.RelativeRotation={Pitch=0,Yaw=90,Roll=0}
pose_at(6.98,{X=100,Y=0,Z=30})
assert(root.teleport==false and math.abs(root.at.X+100)<1e-6 and math.abs(root.at.Y)<1e-6,'Her turn: the same side')
clock=clock+1
ghost.place()
assert(actor.hidden==true)
pose_at(6.99,{X=100,Y=0,Z=30})
assert(root.teleport==true and math.abs(root.at.X-100)<1e-6 and math.abs(root.at.Y+200)<1e-6,'Shown again: her right now')
box.RelativeRotation={Pitch=0,Yaw=0,Roll=0}

-- The same generation with the blade sheathed and shown otherwise: applied in place, no rebuild.
local displays_before=#displays
assert(send(500,her_parts({socket='SC_Back',blade_shown=false}))==nil)
assert(#spawned==1 and not actor.destroyed and #displays==displays_before,'No rebuild, the display stays')
assert(blade.attached.socket=='SC_Back' and blade.visible==false and hair.attached.socket=='Bip001-Head')
assert(ghost.tick()==nil,'Nothing to build')
-- One change at a time: the socket alone hangs the blade elsewhere, shown alone shows it.
send(500,her_parts({socket='SC_Hip',blade_shown=false}))
assert(blade.attached.socket=='SC_Hip' and blade.visible==false,'The socket alone')
send(500,her_parts({socket='SC_Hip'}))
assert(blade.visible==true and blade.attached.socket=='SC_Hip','Shown alone')

-- A replay: placed where it was, no offset.
send(500,her_parts({socket='SC_Back',blade_shown=false}),'replay')
box.RelativeScale3D.Z=7
ghost.place()
assert(math.abs(root.at.X-100)<1e-6 and math.abs(root.at.Y)<1e-6,'No offset off the loopback')
assert(ghost.status():find(' source=replay collide=off$'),ghost.status())

-- A new generation, every fallback reason: part 0 has no path ('-'), the hair is missing (a DLC this PC lacks), the
-- blade has another bone count and no fallback: it is left out, and its scabbard with it.
loads={}
meshes[TWO_BLADE].bones={'Root','Tip'}
ok,message=send(501,her_parts({body='-',hair=NIER,blade=TWO_BLADE}))
assert(ok and message=='Ghost 500 removed (a new table).' and actor.destroyed and displays[#displays]=='withdrawn',message)
assert(stored==nil)
ok,message=build()
assert(ok and message:find('^Ghost 501 built: 4 parts %(2 leaders%), %d+ loaded in %d+ ms, 2 on the base suit, 2 left out'),message)
assert(message:find('; CharacterMesh0: %- missing, drawn as '..BASE_BODY:gsub('%p','%%%0')..' %(3 of 4 bones follow%)'),message)
assert(message:find('; SBHair: '..NIER:gsub('%p','%%%0')..' missing, drawn as '..BASE_HAIR:gsub('%p','%%%0')..' %(2 of 3 bones follow%)'),message)
assert(table.concat(loads,' ')==table.concat({BASE_BODY,NIER,BASE_HAIR,TWO_BLADE},' '),table.concat(loads,' '))
actor=spawned[#spawned]
assert(actor.parts[1].mesh==meshes[BASE_BODY] and actor.parts[3].mesh==meshes[BASE_HAIR])
assert(actor.parts[1].added_at==meshes[BASE_BODY].resolved_at and actor.parts[3].added_at==meshes[BASE_HAIR].resolved_at,
    'A fallback mesh too is resolved and added in the same frame')
local destroyed=0
for _,p in ipairs(actor.parts) do destroyed=destroyed+(p.destroyed and 1 or 0) end
assert(destroyed==1,'The blade on 2 bones was added, found wrong and destroyed, never re-pointed')
assert(actor.parts[1].mesh==meshes[BASE_BODY] and actor.parts[1].calls.SetForcedLOD==1)
d=displays[#displays]:gsub('0x%x+','0xX')
assert(d=='display 501\nmailbox 0xX 0xX\ndrive 0 0xX 0xX 0xX 4\nremap 0 0 1 -1 2\ndrive 2 0xX 0xX 0xX 3\nremap 2 0 -1 1\n',d)
assert(ghost.status():find('^ghost=on parts=4 leaders=2 basesuit=0 left_out=2 table=501 '),ghost.status())

-- The other two reasons: part 0's path is not a skeletal mesh, the hair's mesh has other bones than hers.
ok,message=send(502,her_parts({body=STATIC,hair=LONG_HAIR}))
ok,message=build()
assert(message:find('CharacterMesh0: '..STATIC:gsub('%p','%%%0')..' missing, drawn as '),message)
assert(message:find('SBHair: '..LONG_HAIR:gsub('%p','%%%0')..' has 5 bones, not 2, drawn as '),message)
assert(displays[#displays]:find('\nremap 0 0 1 %-1 2\n') and displays[#displays]:find('\nremap 2 0 %-1 1\n'))
-- The missing DLC mesh is never loaded twice in a Lua load.
loads={}
send(503,her_parts({hair=NIER}))
build()
for _,path in ipairs(loads) do assert(path~=NIER,'A missing mesh is remembered') end

-- basesuit: the body and the hair on the base suit even when hers load, rebuilt at once; then off again.
ok,message=ghost.basesuit()
assert(ok and message:find('^Base suit on') and spawned[#spawned].destroyed)
ok,message=build()
assert(message:find('^Ghost 503 built: 6 parts %(3 leaders%), %d+ loaded in %d+ ms, 2 on the base suit, 0 left out'),message)
assert(message:find('CharacterMesh0: '..BODY:gsub('%p','%%%0')..' replaced %(basesuit%)'),message)
assert(ghost.status():find(' basesuit=1 '),ghost.status())
ghost.basesuit()
ok,message=build()
assert(message:find(', 1 on the base suit, '),message) -- Only the missing NieR hair now.

-- Another map: no build, said once; back on hers, it is built.
send(504,her_parts(),nil,'/game/art/bg/worldmap/level_p/f01')
local pending_ghost=spawned[#spawned]
assert(pending_ghost.destroyed)
ok,message=ghost.tick()
assert(ok and message=='Ghost hidden: she is on /game/art/bg/worldmap/level_p/f01, you are on /game/art/bg/worldmap/level_p/e04.',message)
local spawned_count=#spawned
assert(ghost.tick()==nil and ghost.tick()==nil and #spawned==spawned_count,'Said once, never built')
assert(ghost.status()=='ghost=hidden map',ghost.status())
assert(#said==0,'Her own loopback: nothing on screen')
-- A friend on another map: on screen too, once per pair of maps, by the maps' last segments.
send(540,her_parts(),'peer','/game/art/bg/worldmap/level_p/f01')
ok,message=ghost.tick()
assert(ok and message:find('^Ghost hidden: she is on .*/f01, you are on .*/e04%.$'),message)
assert(#said==1 and said[1]=='Kaanta is in f01, you are in e04.',tostring(said[1]))
ghost.tick(); ghost.tick()
assert(#said==1,'Once per pair')
send(541,her_parts(),'peer','/game/art/bg/worldmap/level_p/b07')
ghost.tick()
assert(#said==2 and said[2]=='Kaanta is in b07, you are in e04.',tostring(said[2]))
send(542,her_parts(),'peer','/game/art/bg/worldmap/level_p/b07') -- A new outfit, or a new EVE, on the same map.
ghost.tick()
assert(#said==2,'A new table on the same pair: not said again')
words=Words.fr
send(543,her_parts(),'peer','/game/art/bg/worldmap/level_p/a01')
ghost.tick()
assert(#said==3 and said[3]=='Kaanta est dans a01, vous êtes dans e04.',tostring(said[3]))
assert(said_en[3]=='Kaanta is in a01, you are in e04.',tostring(said_en[3]))
words=Words.en
send(505,her_parts())
ok,message=build()
assert(message:find('^Ghost 505 built'),message)

-- A level change: the ghost goes, then comes back once EVE has been in the world 2 s, on the new map's gate.
actor=spawned[#spawned]
player=eve_of('EVE2')
assert(ghost.tick()==nil and actor.destroyed and displays[#displays]=='withdrawn' and stored==nil)
assert(ghost.status()=='ghost=waiting')
spawned_count=#spawned
assert(ghost.tick()==nil and #spawned==spawned_count,'Waits 2 s')
clock=clock+2
ok,message=build()
assert(message:find('^Ghost 505 built'),message)
-- A pawn that is not EVE (title screen): the comeback waits, it never gives up.
local menu=object('MenuPawn')
function menu:IsA() return false end
player=menu
ghost.tick()
clock=clock+3
ghost.tick()
assert(ghost.active() and ghost.status()=='ghost=waiting','Still waiting for EVE')
player=eve
ghost.tick()
clock=clock+2
build()
-- Travel to another map, her new EVE where the freed one was: the gate reads the new map, never one kept for that
-- address.
actor=spawned[#spawned]
actor.destroyed=true -- With the old world.
player=eve_of('EVE3',{GetFullName=function() return 'World /Game/Art/BG/WorldMap/Level_P/F01.F01' end},eve.GetAddress())
assert(ghost.tick()==nil and displays[#displays]=='withdrawn')
clock=clock+2
ok,message=ghost.tick()
assert(ok and message=='Ghost hidden: she is on /game/art/bg/worldmap/level_p/e04, you are on /game/art/bg/worldmap/level_p/f01.',
    tostring(message))
player=eve -- Back on hers, at that address again.
ok,message=build()
assert(message:find('^Ghost 505 built'),message)

-- The remote table gone (loopback off, replay off): the ghost goes and its display file is withdrawn.
actor=spawned[#spawned]
ok,message=ghost.remote(nil,nil,nil)
assert(ok and message=='Ghost 505 removed (her table is gone).' and actor.destroyed and displays[#displays]=='withdrawn',message)
assert(ghost.tick()==nil and ghost.status()=='ghost=waiting','No table: no ghost')
assert(ghost.remote(nil,nil,nil)==nil,'Said once')

-- A failed build says why and leaves nothing behind; it is tried again 2 s later, never before.
send(506,her_parts())
fail_add=true
ok,message=build()
assert(ok==false and message:find('^Ghost not built: .*could not be added') and spawned[#spawned].destroyed,message)
fail_add=false
spawned_count=#spawned
clock=clock+1.5
assert(ghost.tick()==nil and #spawned==spawned_count,'Not before 2 s')
clock=clock+1
ok,message=build()
assert(message:find('^Ghost 506 built'),message)
-- One failing each time: 3 tries in all, then said on screen once; a new table tries again at once.
send(510,her_parts())
give_up()
send(507,her_parts())
ok,message=build()
assert(message:find('^Ghost 507 built'),message)

-- Toggled off: removed; the table is kept for the next toggle.
actor=spawned[#spawned]
ok,message=ghost.toggle()
assert(ok and message=='Ghost 507 removed (coop puppet).' and actor.destroyed and stored==nil,message)
assert(ghost.status()=='ghost=off')
ghost.toggle()
build()
assert(not spawned[#spawned].destroyed)
ghost.toggle()

-- The next Lua load sweeps a ghost left standing, once it checks it is ours (its root, never its tag); a stranger at
-- that path is left alone.
local left=spawned[1]
assert(left.label,'A tagged ghost')
left.destroyed=false
found_by_path['/Game/Map.Map:PersistentLevel.Actor_1']=left
ghost=new('/Game/Map.Map:PersistentLevel.Actor_1')
assert(not left.destroyed,'Not while the Lua state loads: on the game thread only')
local _,first=ghost.toggle()
assert(left.destroyed and first:find('^Removed a ghost left by an earlier Lua load%. Ghost on'),first)
local stranger=object('Stranger')
function stranger:K2_GetRootComponent() return object('Capsule2',{IsA=function() return false end}) end
function stranger:K2_DestroyActor() self.destroyed=true end
found_by_path['/Game/Map.Map:PersistentLevel.Actor_9']=stranger
new('/Game/Map.Map:PersistentLevel.Actor_9').tick()
assert(not stranger.destroyed and stored==nil,'Not ours: left alone')

-- A cached mesh collected since, its address reused, is never drawn: the path is resolved again, whether the address
-- now holds another skeletal mesh or an object of another class (its name alone would pass).
send(600,her_parts())
ghost.tick()
clock=clock+2
build()
local stale=meshes[FACE]
stale.GetFullName=function() return 'SkeletalMesh '..PONY end
mesh(FACE)
loads={}
send(601,her_parts())
build()
assert(spawned[#spawned].parts[2].mesh==meshes[FACE] and table.concat(loads,' ')==FACE,'Another skeletal mesh there')
stale=meshes[FACE]
stale.IsA=function() return false end
stale.GetFullName=function() return 'Texture2D '..FACE end
mesh(FACE)
loads={}
send(602,her_parts())
build()
assert(spawned[#spawned].parts[2].mesh==meshes[FACE] and table.concat(loads,' ')==FACE,'Another class there')

-- A built part whose parent part was left out hangs on part 0, at its socket.
local charmed=her_parts({blade=TWO_BLADE})
charmed[7]={name='Charm',parent=4,socket='SC_Tip',path=BLADE,names={'Root'},place='0 0 0 1 2 0 0 1 1 1'}
send(603,charmed)
ok,message=build()
assert(ok and message:find('^Ghost 603 built: 5 parts %(3 leaders%), .*, 2 left out'),message)
actor=spawned[#spawned]
local charm=actor.parts[#actor.parts]
assert(charm.mesh==meshes[BLADE] and charm.attached.parent==actor.parts[1] and charm.attached.socket=='SC_Tip')

-- A table with no generation line is refused, never raised on.
remote_file=remote_text(604,her_parts()):gsub('generation 604\n','')
count=count+1
local read,refused,why=pcall(ghost.remote,604,count,'loopback')
assert(read and refused==false and why=='The remote table could not be read.',tostring(refused))

-- A table given up is tried again with a new EVE, even with no ghost left to remove.
send(605,her_parts())
give_up()
player=eve_of('EVE5')
assert(ghost.tick()==nil,'Waits 2 s')
clock=clock+2
ok,message=build()
assert(message:find('^Ghost 605 built'),message)
-- A new EVE before her 2 s are up, no ghost yet: they start again.
player=eve_of('EVE6')
ghost.tick()
clock=clock+1.5
player=eve_of('EVE7')
ghost.tick()
spawned_count=#spawned
clock=clock+0.5
assert(ghost.tick()==nil and #spawned==spawned_count,'The 2 s start again with each new EVE')
clock=clock+1.5
ok,message=build()
assert(message:find('^Ghost 605 built'),message)
-- Toggled off and on again: a table given up is tried again at once.
send(606,her_parts())
words=Words.fr
give_up('Le fantôme a échoué 3 fois : la raison est dans UE4SS.log.') -- In the game's language.
words=Words.en
ghost.toggle()
ghost.toggle()
ok,message=build()
assert(message:find('^Ghost 606 built'),message)

-- A tag that cannot be added leaves the ghost built without one, and the build line says why; so does a text Lua cannot
-- convert, and the tag made so far goes (it would read the engine's default text).
send(650,her_parts())
fail_label=true
ok,message=build()
fail_label=false
actor=spawned[#spawned]
assert(ok and message:find('^Ghost 650 built: 6 parts .*; name tag off: .*a text line could not be added'),message)
assert(not actor.destroyed and not actor.label and ghost.status():find('^ghost=on '),'The ghost stays')
send(651,her_parts())
fail_text=true
ok,message=build()
fail_text=false
actor=spawned[#spawned]
assert(ok and message:find('; name tag off: .*no FText') and actor.label.destroyed and not actor.destroyed,message)
box=actor.mailbox
box.RelativeScale3D.Z=8
assert(ghost.place()==nil and actor.parts[1].moves==1 and not actor.label.turns,'No tag to turn')
-- A setter that fails once the line is added (the colour): U.label takes the line off again.
send(653,her_parts())
fail_color=true
ok,message=build()
fail_color=false
actor=spawned[#spawned]
assert(ok and message:find('; name tag off: .*no FColor') and actor.label.destroyed and not actor.destroyed,message)
-- With name_tag off in the settings: no tag at all.
ghost.toggle()
ghost=new(nil,false)
ghost.toggle()
send(652,her_parts(),'peer')
ghost.tick()
clock=clock+2
ok,message=build()
assert(message:find('^Ghost 652 built') and not message:find('name tag') and not spawned[#spawned].label,message)
ghost.toggle()
ghost=new(nil)
ghost.toggle()

-- A friend's ghost (source peer): her Steam name above it.
send(607,her_parts(),'peer')
ghost.tick()
clock=clock+2
ok,message=build()
actor=spawned[#spawned]
assert(message:find('^Ghost 607 built') and actor.label.text=='Kaanta',message)
-- A title round trip (Esc to the title, a save loaded): the ghost goes with her EVE and comes back with its tag, and
-- no request is ever written (the link holds or keeps the session on its own).
player=menu
assert(ghost.tick()==nil and actor.destroyed and displays[#displays]=='withdrawn','Removed on the title')
player=eve
assert(ghost.tick()==nil)
clock=clock+2
ok,message=build()
assert(message:find('^Ghost 607 built') and spawned[#spawned]~=actor and spawned[#spawned].label.text=='Kaanta',message)
assert(#requests==0,'No request')
-- The tag sets no font, so the engine's default draws it, Latin-1 only: a character past U+00FF shows as '?', and a
-- name that loses more than half its characters gives way to the partner card's word for her, in the player's language
-- when that one draws whole, else in English. Cleaned as the card cleans her name.
local tag_text=require('puppet').tag_text
assert(tag_text('Zoë Ünal','Partner')=='Zoë Ünal' and tag_text(' \1Kaanta\n ','Partner')=='Kaanta')
assert(tag_text('Ann日本','Partner')=='Ann??' and tag_text('ab日本','Partner')=='ab??','Half lost: still hers')
assert(tag_text('日本a','Partenaire','Partner')=='Partenaire' and tag_text('','Partenaire','Partner')=='Partenaire')
assert(tag_text(nil,'Partenaire','Partner')=='Partenaire')
assert(tag_text('カンタ','パートナー','Partner')=='Partner' and tag_text('カンタ','Takım arkadaşı','Partner')=='Partner')
friend_name='カンタ'
player=menu
ghost.tick()
player=eve
ghost.tick()
clock=clock+2
ok,message=build()
assert(message:find('^Ghost 607 built') and spawned[#spawned].label.text=='Partner',message)
friend_name='Kaanta'
-- A camera that cannot be read stops the tag turning, once, and never the ghost.
actor=spawned[#spawned]
tag,box=actor.label,actor.mailbox
camera_fails=true
box.RelativeScale3D.Z=8
ok,message=ghost.place()
assert(ok==false and message:find('^Name tag no longer turned to the camera: .*no player controller'),tostring(message))
assert(not actor.destroyed and actor.hidden==false and actor.parts[1].moves==1 and not tag.turns,'The ghost stays, shown')
box.RelativeScale3D.Z=8.5
assert(ghost.place()==nil and actor.parts[1].moves==2,'Said once, the ghost still placed')
camera_fails=false
box.RelativeScale3D.Z=8.75
ghost.place()
assert(not tag.turns,'Turned no more on that ghost')
-- No offset, the root exactly where her mesh is.
root=actor.parts[1]
box.RelativeScale3D.Z=9
box.RelativeLocation={X=1,Y=402,Z=-87}
box.RelativeRotation={Pitch=1,Yaw=45,Roll=2}
ghost.place()
assert(root.at.X==1 and root.at.Y==402 and root.at.Z==-87 and root.rot.Yaw==45 and root.rot.Pitch==1 and
    root.rot.Roll==2 and actor.hidden==false,'Exactly at the mailbox')

-- coop where: the nearest camp of the leaf classes (an invalid one skipped; the nearest neither first nor last, so
-- neither the first nor the last found passes for it), the world origin and flags, her ghost.
local function camp(id,at) return object('Camp',{EnvActorName=fname(id),K2_GetActorLocation=function() return at end}) end
local camps={Env_VendingMachine_C={camp('Xion_10_EnvS_007',{X=1,Y=-498,Z=3})},Env_VendingMachine_Simple_C={invalid},
    Env_Camp_TeleportMachine_C={camp('Xion_10_EnvS_016',{X=301,Y=2,Z=3})},
    Env_Camp_TeleportMachine_Tetrapod_C={camp('Xion_10_EnvS_020',{X=1,Y=2,Z=903})}}
-- Spawn points: the nearest is neither the first nor the last valid one either.
local function spawn_point(id,at) return object('Spawn',{SpawnPointName=fname(id),K2_GetActorLocation=function() return at end}) end
camps.SBSpawnPoint={invalid,spawn_point('Xion_SP_far',{X=1,Y=2,Z=2003}),spawn_point('Xion_10_Camp_SV1',{X=1,Y=2,Z=203}),
    spawn_point('Xion_SP_mid',{X=1,Y=2,Z=1003})}
FindAllOf=function(class) return camps[class] end -- nil for a class with no object, as UE4SS does.
local STATICS='/Script/Engine.Default__GameplayStatics'
found_by_path[STATICS]=invalid -- Not in this build: that field says why, the rest of the line stays.
clock=clock+0.5
ok,message=ghost.where()
assert(ok and message:find(' origin=?(/Script/Engine.Default__GameplayStatics is unavailable in th) composition=false ',1,true),
    message)
found_by_path[STATICS]=object('GameplayStatics',{GetWorldOriginLocation=function(_,context)
    assert(context==player,'Asked for her world'); return {X=0,Y=0,Z=0}
end})
ok,message=ghost.where()
assert(ok and message=='where map=/game/art/bg/worldmap/level_p/e04 eve=1.0,2.0,3.0 yaw=0.0 mesh=1.0,2.0,-87.0 '
    ..'camp=Xion_10_EnvS_016:Env_Camp_TeleportMachine_C@301.0,2.0,3.0 camp_m=3.0 '
    ..'spawn=Xion_10_Camp_SV1:SBSpawnPoint@1.0,2.0,203.0 spawn_m=2.0 origin=0,0,0 composition=false '
    ..'rebasing=false ghost=peer@1.0,402.0,-87.0 ghost_yaw=45.0 ghost_m=4.00 ghost_age=0.5',message)
-- In loopback: where her mesh is, before the 2 m offset.
ghost.remote(607,count,'loopback') -- The same count: only the source changes.
box.RelativeScale3D.Z=10
ghost.place()
assert(root.at.Y~=402 and select(2,ghost.where()):find(' ghost=loopback@1.0,402.0,-87.0 ',1,true),'Hers, not offset')
-- No ghost: her table on this map (waiting), on another, or none.
send(608,her_parts(),'peer')
assert(select(2,ghost.where()):find(' ghost=waiting$'))
send(609,her_parts(),'peer','/game/art/bg/worldmap/level_p/f01')
assert(select(2,ghost.where()):find(' ghost=elsewhere:/game/art/bg/worldmap/level_p/f01$'))
ghost.remote(nil,nil,nil)
ghost.toggle()
ok,message=ghost.where()
assert(ok and message:find(' ghost=none$') and message:find(' camp=Xion_10_EnvS_016:'),'No link, no ghost: still a line')
camps.SBSpawnPoint=nil -- None loaded: the field says so, the line stays.
assert(select(2,ghost.where()):find(' spawn=none origin=',1,true),'No spawn point')
player=menu
ok,message=ghost.where()
assert(ok==false and message=='no EVE in the world',message)

-- A save is loaded once EVE stands on a map other than the title screen's: held invites wait for it. The second value
-- says the title screen is shown: any pawn on its map, never without one (a loading screen) nor on another map.
local function both() local w,t=ghost.world(); return tostring(w)..' '..tostring(t) end
player=object('MenuPawn',{IsA=function() return false end,
    GetWorld=function() return {GetFullName=function() return 'World /Game/Art/BG/WorldMap/Level_P/B07.B07' end} end})
assert(both()=='false false','Not EVE, even on a world map')
player=object('MenuPawn',{IsA=function() return false end,
    GetWorld=function() return {GetFullName=function() return 'World /Game/Lobby/Lobby.Lobby' end} end})
assert(both()=='false true','Another pawn on the title map: the title')
player=eve_of('EVE8',{GetFullName=function() return 'World /Game/Lobby/Lobby.Lobby' end})
assert(both()=='false true','EVE on the title map')
player=eve_of('EVE9',{GetFullName=function() return 'World /Game/Art/BG/WorldMap/Level_P/B07.B07' end})
assert(both()=='true false','EVE on Spire IV')
-- The same read keeps where we are for the partner HUD (her distance, whether she is on our map).
assert(ghost.me().map=='/game/art/bg/worldmap/level_p/b07' and ghost.me().at.X==1 and ghost.me().at.Z==3)
player=nil
assert(both()=='false false','No pawn at all')
assert(ghost.me()==nil,'Nowhere')
player=eve_of('EVE10',{GetFullName=function() error('world gone') end})
assert(both()=='false false','An engine error is neither a world nor the title, never raised')

-- Cloth (look.cloth, read at each build): a follower whose mesh has clothing assets, her ponytail, is a
-- SkeletalMeshComponent that follows its Poseable leader, with no collision, simulated in its own space, never bound to
-- the leader's cloth; a leader stays Poseable whatever its mesh, and a mesh whose assets cannot be read has none. Every
-- ghost above was built with cloth off: none had one, though the ponytail and the hair have clothing assets.
assert(skeletal_adds==0,'Cloth off: Poseables only')
player=eve
local look={cloth=true}
ghost=new(nil,true,look)
ghost.toggle()
local clothed=her_parts()
clothed[6].path=BLADE -- The scabbard on a mesh without cloth: the ponytail is the one cloth part.
local face_methods=getmetatable(meshes[FACE]).__index
getmetatable(meshes[FACE]).__index=function(_,key)
    if key=='MeshClothingAssets' then error('no such property') end
    return face_methods[key]
end
send(700,clothed)
ghost.tick()
clock=clock+2
ok,message=build()
assert(ok and message:find('^Ghost 700 built: 6 parts %(3 leaders%), %d+ loaded in %d+ ms, 0 on the base suit, 0 left out; '
    ..'look: cloth parts 1 %(%d+ ms in all%)%.$'),message)
actor=spawned[#spawned]
root,face,hair,pony,blade,scabbard=table.unpack(actor.parts)
assert(pony.cloth and pony.mesh==meshes[PONY] and pony.calls.SetCollisionEnabled==0 and pony.bLocalSpaceSimulation==true)
assert(pony.calls.SetMasterPoseComponent==hair and pony.bUseBoundsFromMasterPoseComponent==true,'It follows its leader')
assert(pony.attached.parent==hair and pony.visible==false,'Hung and shown as the table says')
-- Her outfit's collision, set up as SB does for her ponytail: the 18 body bones its collision bodies hang on, the
-- outfit's asset (named from her body mesh, resolved in a step of its own before), then the leader, then the mesh,
-- which creates the cloth. keep() names the leader again: the engine ignores the same one.
assert(table.concat(pony.order,' ')=='bones override master mesh master',table.concat(pony.order,' '))
assert(pony.OverrideClothPhysicsAsset==meshes[COLLISION] and pony.bLocalSpaceSimulation==true)
local bones={}
for k,name in ipairs(pony.AdditiveMasterBoneArray) do bones[k]=name:ToString() end
assert(table.concat(bones,' ')=='Bip001-R-Thigh Bip001-L-Thigh Bip001-L-UpperArm Bip001-L-Forearm Bip001-R-UpperArm '
    ..'Bip001-R-Forearm Bip001-Neck Bip001-L-Calf Bip001-R-Calf Bip001-L-Foot Bip001-R-Foot Bip001-Head Bip001-Pelvis '
    ..'Bip001-Spine Bip001-Spine1 Bip001-Spine2 Ab-L-Thigh-Tw0 Ab-R-Thigh-Tw0',table.concat(bones,' '))
assert(table.concat(loads,' ',#loads-4)==table.concat({COLLISION,FACE,HAIR,PONY,BLADE},' '),
    'Loaded in the frame after her body\'s, before the ponytail\'s')
-- The asset's name from her body mesh's path, as SB builds it.
local Puppet=require('puppet')
assert(Puppet.collision_path(BODY)==COLLISION)
assert(Puppet.collision_path(BASE_BODY)=='/Game/Art/Character/PC/CH_P_EVE_08/CH_P_EVE_08_PonytailPhysicsAsset.'
    ..'CH_P_EVE_08_PonytailPhysicsAsset')
assert(Puppet.collision_path('/Game/Art/Character/PC/CH_P_EVE_08/CH_P_EVE_08')==nil,'Not dir/name.object: none')
assert(not (root.cloth or face.cloth or hair.cloth or blade.cloth or scabbard.cloth),'The rest are Poseables')
-- Its cloth simulates only while it is drawn (OnlyTickPoseWhenRendered); the Poseables keep their default.
assert(pony.VisibilityBasedAnimTickOption==3)
for _,p in ipairs({root,face,hair,blade,scabbard}) do assert(p.VisibilityBasedAnimTickOption==nil) end
assert(hair.calls.SetForcedLOD==1 and face.calls.SetMasterPoseComponent==root)
d=displays[#displays]:gsub('0x%x+','0xX')
assert(d=='display 700\nmailbox 0xX 0xX\ndrive 0 0xX 0xX 0xX 3\ndrive 2 0xX 0xX 0xX 2\ndrive 4 0xX 0xX 0xX 1\n',d)
-- Its cloth starts again from the pose each time the ghost shows: the first pose, and after a hide.
box=actor.mailbox
assert(ghost.place()==nil and actor.hidden and not pony.resets,'No pose yet: hidden, no reset')
box.RelativeScale3D.Z=20
assert(ghost.place()==nil and actor.hidden==false and pony.resets==1,'Reset as it first shows')
box.RelativeScale3D.Z=21
ghost.place()
assert(pony.resets==1,'Shown already: not at each pose')
clock=clock+1
ghost.place()
assert(actor.hidden==true and pony.resets==1)
box.RelativeScale3D.Z=22
ghost.place()
assert(actor.hidden==false and pony.resets==2,'Again as it shows after a hide')
-- A reset that fails is said once and leaves the ghost shown; its cloth is never reset again.
fail_reset=true
clock=clock+1
ghost.place()
box.RelativeScale3D.Z=23
ok,message=ghost.place()
assert(ok==false and message:find('^Cloth reset failed: .*no reset; this ghost\'s cloth still simulates but is never reset again '
    ..'%(coop look cloth off removes it%)$'),tostring(message))
assert(actor.hidden==false and not actor.destroyed,'The ghost stays, shown')
clock=clock+1
ghost.place()
box.RelativeScale3D.Z=24
assert(ghost.place()==nil and actor.hidden==false and pony.resets==2,'Said once')
fail_reset=false
-- coop look: the ghost removed and built again at once with what the look says now.
look.cloth=false
assert(ghost.rebuild('look')=='Ghost 700 removed (look).' and actor.destroyed and displays[#displays]=='withdrawn')
ok,message=build()
actor=spawned[#spawned]
assert(message:find('^Ghost 700 built: 6 parts .* 0 left out %(%d+ ms in all%)%.$') and not actor.parts[4].cloth,message)
-- A cloth part that cannot be added, or fails once added (then it goes): the ponytail is a plain part, and says why.
look.cloth=true
fail_cloth='add'
ghost.rebuild('look')
ok,message=build()
actor=spawned[#spawned]
pony=actor.parts[4]
assert(ok and not pony.cloth and pony.calls.SetMasterPoseComponent==actor.parts[3] and #actor.parts==6,message)
assert(message:find('; look: cloth parts 0; SBPonytail: cloth not used %(.*a cloth part could not be added%), drawn as a '
    ..'plain part %('),message)
fail_cloth='set'
ghost.rebuild('look')
ok,message=build()
actor=spawned[#spawned]
assert(#actor.parts==7 and actor.parts[4].cloth and actor.parts[4].destroyed,'Added, failed, destroyed')
assert(not actor.parts[5].cloth and actor.parts[5].mesh==meshes[PONY] and actor.parts[5].calls.SetMasterPoseComponent==actor.parts[3])
assert(message:find('; look: cloth parts 0; SBPonytail: cloth not used %(.*no cloth mesh%), drawn as a plain part %('),message)
fail_cloth=nil
-- Her body on the base suit (no path): the base suit's collision, missing on this PC, is said and the cloth stays,
-- with its collision bones and the clothing asset's own collision. A clothed follower that is no ponytail (the
-- scabbard on the ponytail's mesh here) has cloth and no collision of hers.
local bare=her_parts({body='-'})
send(701,bare)
ok,message=build()
actor=spawned[#spawned]
pony,scabbard=actor.parts[4],actor.parts[6]
assert(ok and pony.cloth and pony.OverrideClothPhysicsAsset==nil and #pony.AdditiveMasterBoneArray==18,message)
assert(table.concat(pony.order,' ')=='bones master mesh master')
assert(table.concat(scabbard.order,' ')=='master mesh master')
assert(message:find('; look: cloth parts 2; .*; SBPonytail: outfit collision not used %(/Game/Art/Character/PC/'
    ..'CH_P_EVE_08/CH_P_EVE_08_PonytailPhysicsAsset%.CH_P_EVE_08_PonytailPhysicsAsset missing%) %('),message)
-- Its collision bones refused: said, and neither they nor the asset are used.
fail_array=true
send(702,her_parts())
ok,message=build()
pony=spawned[#spawned].parts[4]
assert(ok and pony.cloth and pony.OverrideClothPhysicsAsset==nil and table.concat(pony.order,' ')=='master mesh master')
assert(message:find('; look: cloth parts 2; SBPonytail: outfit collision not used %(.*no array write%) %('),message)
fail_array=false
-- A render flag refused: said once, the others still set, the ghost built.
fail_depth=true
ghost.rebuild('look')
ok,message=build()
assert(ok and message:find('; look: cloth parts 2; solo render flags not set %(.*no custom depth%) %(')
    and not message:find('render flags.*render flags'),message)
for _,p in ipairs(spawned[#spawned].parts) do assert(p.channels[2]==true and p.stencil==10 and p.custom_depth==nil) end
fail_depth=false
send(700,clothed)
-- A rebuild tries a table given up again at once.
ghost.rebuild('look')
give_up()
assert(ghost.rebuild('look')==nil,'No ghost to remove')
ok,message=build()
assert(message:find('^Ghost 700 built: .*; look: cloth parts 1 %('),message)

-- Dyes (look.dyes, read at each build). Off, a table's material lines are read and nothing is done with them: no
-- material resolved, and no SetMaterial (these parts have none).
local dyed={body_materials={{1,SKIN}},hair_materials={{0,TYPE_B},{1,FACE},{5,TYPE_C}}}
look.cloth=false
loads,before={},lookups
send(800,her_parts(dyed))
ok,message=build()
assert(ok and message:find('^Ghost 800 built: 6 parts .* 0 left out %(%d+ ms in all%)%.$'),message)
for _,path in ipairs(loads) do assert(not meshes[path]:IsA({path='/Script/Engine.MaterialInterface'}),path) end
assert(spawned[#spawned].parts[1].SetMaterial==nil,'Dyes off: the fakes still have no SetMaterial')
-- On: each part on its own mesh takes its slots below GetNumMaterials (2 here), one material a frame, resolved and set
-- in the same frame; a path that is no MaterialInterface (a mesh) or a slot past the mesh's keeps the default, said.
look.dyes,dyeable=true,true
ghost.rebuild('look')
ok,message=build()
assert(ok and message:find('^Ghost 800 built: 6 parts %(3 leaders%), .* 0 left out; look: dyed slots 2; SBHair: slot 1 '
    ..'material '..FACE:gsub('%p','%%%0')..' missing, default kept; SBHair: slot 5 material '..TYPE_C:gsub('%p','%%%0')
    ..' missing, default kept %(%d+ ms in all%)%.$'),message)
actor=spawned[#spawned]
root,face,hair=actor.parts[1],actor.parts[2],actor.parts[3]
assert(#root.dyes==1 and root.dyes[1].slot==1 and root.dyes[1].material==meshes[SKIN])
assert(#hair.dyes==1 and hair.dyes[1].slot==0 and hair.dyes[1].material==meshes[TYPE_B])
assert(root.dyes[1].at==meshes[SKIN].resolved_at and hair.dyes[1].at==meshes[TYPE_B].resolved_at,'Resolved, set: one frame')
assert(not face.dyes and face.mesh==meshes[FACE],'The face is still its mesh')
-- The face's path refused as a material is remembered as such only: the next build still draws the face on it.
ghost.rebuild('look')
build()
assert(spawned[#spawned].parts[2].mesh==meshes[FACE],'A mesh named as a material spoils neither')
-- A part on a fallback mesh is never dyed: its slots are another mesh's.
send(801,her_parts({hair=NIER,hair_materials={{0,TYPE_B}}}))
ok,message=build()
actor=spawned[#spawned]
assert(actor.parts[3].mesh==meshes[BASE_HAIR] and not actor.parts[3].dyes,'On the base suit')
assert(message:find('; look: dyed slots 0; ') and not message:find('slot 0 material'),message)
-- The table read stays strict: a material line of another part, a slot not rising, one over 63, a 17th, or an unknown
-- line refuses the whole table.
local good=remote_text(802,her_parts(dyed))
for _,bad in ipairs({good:gsub('\nmaterial 2 0 ','\nmaterial 1 0 '),good:gsub('\nmaterial 2 1 ','\nmaterial 2 0 '),
    good:gsub('\nmaterial 2 5 ','\nmaterial 2 64 '),good..'bogus\n'}) do
    remote_file=bad
    count=count+1
    ok,message=ghost.remote(802,count,'loopback')
    assert(ok==false and message=='The remote table could not be read.',bad)
end
local sixteen={}
for k=1,17 do sixteen[k]={k,TYPE_B} end
remote_file=remote_text(802,her_parts({hair_materials=sixteen}))
count=count+1
assert(select(2,ghost.remote(802,count,'loopback'))=='The remote table could not be read.','17 on one part')
table.remove(sixteen)
send(802,her_parts({hair_materials=sixteen}))
ok,message=build()
-- All 16 read: slot 1, below this mesh's 2, is set; the 15 above it are said.
assert(message:find('^Ghost 802 built: .*; look: dyed slots 1; ') and select(2,message:gsub(' default kept',''))==15,message)

-- Effects (look.effects, read at each build). Off, every ghost above: nothing of Niagara looked up, no effect box, and
-- the display file and the build line as they were.
assert(niagara_lookups==0,'Effects off: no Niagara lookup')
for _,a in ipairs(spawned) do assert(not a.boxes,'Effects off: no effect box') end
-- The listed systems, one this PC lacks; the library that starts them, each instance's calls in one list.
local E=require('capture').EFFECTS
for k,path in ipairs(E) do
    if k~=7 then
        meshes[path]=object(path,{path=path})
        meshes[path].IsA=function(_,class) return class.path=='/Script/Niagara.NiagaraSystem' end
        meshes[path].GetFullName=function() return 'NiagaraSystem '..path end
    end
end
local LIBRARY='/Script/Niagara.Default__NiagaraFunctionLibrary'
local events,spawns,spawn_fails={},{},false
local library=object('NiagaraFunctionLibrary',{SpawnSystemAttached=function(_,...)
    if spawn_fails then error('no Niagara on a Poseable') end
    local fx=object('NiagaraComponent')
    function fx:Deactivate() events[#events+1]='Deactivate'; self.stopped=true end
    function fx:SetCollisionEnabled(v) self.collision=v end -- Only on a ghost with the solid partner's capsule.
    function fx:K2_SetRelativeLocationAndRotation(at,rotation,sweep,hit,teleport)
        events[#events+1]='K2_SetRelativeLocationAndRotation'
        self.moved={at=at,rotation=rotation,sweep=sweep,hit=hit,teleport=teleport}
    end
    events[#events+1]='SpawnSystemAttached'
    spawns[#spawns+1]={args=table.pack(...),fx=fx}
    return fx
end})
-- No library in this build: the ghost is built without effects, and says why.
found_by_path[LIBRARY]=invalid
look.dyes,look.effects=false,true
send(900,her_parts())
before=lookups
ok,message=build()
actor=spawned[#spawned]
assert(ok and message:find('^Ghost 900 built: 6 parts %(3 leaders%), %d+ loaded in %d+ ms, 0 on the base suit, 0 left out; '
    ..'look: effects off %(.*Default__NiagaraFunctionLibrary is unavailable in this game build%.%) %(%d+ ms in all%)%.$'),
    message)
assert(lookups-before>=19 and not actor.boxes and not actor.destroyed,'Each system looked up, one a frame; no box')
d=displays[#displays]:gsub('0x%x+','0xX')
assert(d=='display 900\nmailbox 0xX 0xX\ndrive 0 0xX 0xX 0xX 3\ndrive 2 0xX 0xX 0xX 2\ndrive 4 0xX 0xX 0xX 1\n',d)
-- With it: four boxes after the mailbox, named in the display file right after it.
found_by_path[LIBRARY]=library
ghost.rebuild('look')
ok,message=build()
actor=spawned[#spawned]
assert(ok and message:find('^Ghost 900 built: 6 parts .* 0 left out; look: effects loaded 18 of 19 %(%d+ ms in all%)%.$'),
    message)
assert(#actor.boxes==4,'Four boxes')
d=displays[#displays]
local named=string.format('\nmailbox 0x%x 0x5c0\neffects 0x%x 0x%x 0x%x 0x%x\ndrive 0 ',actor.mailbox.GetAddress(),
    actor.boxes[1].GetAddress(),actor.boxes[2].GetAddress(),actor.boxes[3].GetAddress(),actor.boxes[4].GetAddress())
assert(d:find(named,1,true),d)
-- place(): the boxes are read only when the mailbox's effects stamp (its scale X) changes.
root,hair=actor.parts[1],actor.parts[3]
box=actor.mailbox
box_reads=0
box.RelativeScale3D.Z=30
assert(ghost.place()==nil and actor.hidden==false and box_reads==0,'A pose alone: no box read')
local function slot(n,asset,part,serial,at,rotation) -- As the native part writes a box.
    local f=actor.boxes[n].fields
    f.RelativeScale3D={X=asset+1,Y=part+1,Z=serial+1}
    f.RelativeLocation=at or {X=0,Y=0,Z=0}
    f.RelativeRotation=rotation or {Pitch=0,Yaw=0,Roll=0}
end
slot(1,2,2,1,{X=1,Y=2,Z=3},{Pitch=10,Yaw=20,Roll=30}) -- The second system, on her hair.
box.RelativeScale3D.X=2
assert(ghost.place()==nil and box_reads>0,'A new effects stamp: the boxes are read')
local a=spawns[1].args
assert(#spawns==1 and a.n==10 and a[1]==meshes[E[2]] and a[2]==hair and a[3]:ToString()=='None','Its system, its part')
assert(a[4].X==1 and a[4].Y==2 and a[4].Z==3 and a[5].Pitch==10 and a[5].Yaw==20 and a[5].Roll==30,'At its place there')
assert(a[6]==0 and a[7]==true and a[8]==true and a[9]==0 and a[10]==true,'Kept relative, auto destroyed, no pooling')
box_reads=0
box.RelativeScale3D.Z=31
assert(ghost.place()==nil and box_reads==0 and #spawns==1,'The same effects stamp: nothing read again')
-- A new key in that slot (a new instance): the old one stopped, then the new one started.
events={}
slot(1,3,0,2)
box.RelativeScale3D.X=3
ghost.place()
assert(table.concat(events,' ')=='Deactivate SpawnSystemAttached' and spawns[1].fx.stopped and #spawns==2,
    table.concat(events,' '))
assert(spawns[2].args[1]==meshes[E[3]] and spawns[2].args[2]==root,'On her main mesh')
-- The same key with a new place: the instance moves, nothing else.
events={}
slot(1,3,0,2,{X=5,Y=0,Z=0},{Pitch=0,Yaw=90,Roll=0})
box.RelativeScale3D.X=4
ghost.place()
local moved=spawns[2].fx.moved
assert(table.concat(events,' ')=='K2_SetRelativeLocationAndRotation' and #spawns==2,table.concat(events,' '))
assert(moved.at.X==5 and moved.rotation.Yaw==90 and moved.sweep==false and moved.teleport==true,'Teleported there')
-- At most 8 starts a second on a ghost: the 9th is refused, said once.
clock=clock+1
local function round(serial,stamp) -- Four new instances at once.
    for n=1,4 do slot(n,n,0,serial) end
    box.RelativeScale3D.X=stamp
    return ghost.place()
end
assert(round(10,5)==nil and round(11,6)==nil and #spawns==10,'8 in a second')
ok,message=round(12,7)
assert(ok==false and message=='Effect not shown: over 8 a second' and #spawns==10,tostring(message))
assert(round(13,8)==nil and #spawns==10,'Said once a ghost')
clock=clock+1
assert(round(14,9)==nil and #spawns==14,'A second later: started again')
-- The same table changed while the build resolves its systems: the parts hang as it says once built.
ghost.rebuild('look')
for _=1,10 do assert(ghost.tick()==nil,'Still building') end
assert(send(900,her_parts({socket='SC_Back',blade_shown=false}))==nil)
build()
actor=spawned[#spawned]
assert(actor.parts[5].attached.socket=='SC_Back' and actor.parts[5].visible==false,'The blade as the table is now')
-- A peer's index past the list, or a part this ghost did not draw: nothing started, one line; the slot after them
-- in the same stamp still starts.
box=actor.mailbox
for n=1,4 do slot(n,0,0,0) end
slot(2,40,0,1)
slot(3,1,9,1)
slot(4,1,0,1)
box.RelativeScale3D.X=10
ok,message=ghost.place()
assert(ok==false and message=='Effect not shown: asset 40 is not in the list' and #spawns==15,tostring(message))
assert(spawns[15].args[2]==actor.parts[1],'Slot 4 on her main mesh')
slot(2,7,0,2)
box.RelativeScale3D.X=11
assert(ghost.place()==nil and #spawns==15,'This PC lacks the 7th: said once already')
-- A spawn that raises: effects off on this ghost (its instances stopped), the ghost goes on.
slot(1,1,0,5)
box.RelativeScale3D.X=12
assert(ghost.place()==nil and #spawns==16)
spawn_fails=true
slot(4,2,0,2)
box.RelativeScale3D.X=13
ok,message=ghost.place()
assert(ok==false and message:find('^Effects off on this ghost: .*no Niagara on a Poseable$'),tostring(message))
assert(spawns[15].fx.stopped and spawns[16].fx.stopped and not actor.destroyed and ghost.status():find('^ghost=on '),
    'Stopped; the ghost stays')
box_reads=0
box.RelativeScale3D.X=14
box.RelativeScale3D.Z=40
assert(ghost.place()==nil and box_reads==0 and actor.hidden==false,'No box read again')
spawn_fails=false

-- The solid partner (collide=on, off by default). Puppet.solid's rules a to g as a table, one case each, then the
-- latches of b and e and their reset by a. Then on fakes: no capsule while off; built the first time the ghost shows
-- with collide on, from your EVE's capsule (size, height, object type), blocking her type alone, never a step, with
-- the tag's collision off and the actor's on; closed or opened only on a change; one line at each contact; the
-- friend's vitals (g) for a friend's ghost only; WorldDynamic when her capsule does not block its own type; an
-- effect started on it without collision; a capsule that cannot be built said once and never tried again on that
-- ghost, which stays.
local Solid=package.loaded.puppet.solid
local function rule(k,over) -- Two capsules of radius 40 and half height 95, 1 m apart across, level.
    local i={on=true,shown=true,h=100,v=0,r=80,hh=190,mode=1,down=false,now=0}
    for key,v in pairs(over or {}) do i[key]=v end
    return Solid(k or {},i)
end
for _,case in ipairs({
    {{},true},
    {{on=false},false,'a'},{{shown=false},false,'a'},
    {{h=78.9},false,'b'},{{h=79},true},
    {{h=50,v=190},false,'c'}, -- Across her, but a capsule's height apart: not inside her, and c opens.
    {{v=59.9},true},{{v=60},false,'c'},
    {{mode=2},true},{{mode=3},true},{{mode=0},false,'d'},{{mode=5},false,'d'},{{mode=6},false,'d'},
    {{down=true},false,'g'},
    {{on=false,h=10,down=true},false,'a'}, -- The first rule that opens it is the one named.
}) do
    local solid,why=rule(nil,case[1])
    local named={}
    for key,v in pairs(case[1]) do named[#named+1]=key..'='..tostring(v) end
    assert(solid==case[2] and why==case[3],table.concat(named,' ')..': '..tostring(solid)..' '..tostring(why))
end
-- b: once inside her, open until more than 20 cm past touching.
local k={}
assert(select(2,rule(k,{h=70}))=='b' and select(2,rule(k,{h=100}))=='b' and rule(k,{h=100.1})==true)
-- e: 2 s of contact (within 5 cm) with no gap, then open until 50 cm apart.
k={}
assert(rule(k,{h=82,now=0})==true and rule(k,{h=82,now=1.99})==true and select(2,rule(k,{h=82,now=2}))=='e')
assert(select(2,rule(k,{h=129.9,now=3}))=='e' and rule(k,{h=130,now=4})==true)
k={}
rule(k,{h=82,now=0})
rule(k,{h=85,now=1.5}) -- 5 cm apart: a gap.
assert(rule(k,{h=82,now=1.6})==true and rule(k,{h=82,now=3.59})==true and select(2,rule(k,{h=82,now=3.6}))=='e')
-- a: hidden or off forgets both.
k={}
assert(select(2,rule(k,{h=70,now=0}))=='b' and select(2,rule(k,{h=82,now=2}))=='b','Inside, and 2 s of contact')
assert(select(2,rule(k,{shown=false,now=2.1}))=='a' and rule(k,{h=90,now=2.2})==true,'Both forgotten')

-- On fakes: your EVE with her capsule (object type 24, blocking it unless blocks says otherwise), her movement and her
-- camera boom; her capsule's centre at her_at (the ghost spawns where she stands: X=1).
local blocks,her_at=2,{X=1,Y=2,Z=3}
local movement=object('CharMoveComp',{MovementMode=1,Velocity={X=300,Y=400,Z=50},
    RootMotionData={pRootMotionData=invalid}})
function movement:GetMaxSpeed() return 600 end
local cylinder=object('CollisionCylinder')
function cylinder:GetCollisionObjectType() return 24 end
function cylinder:GetCollisionResponseToChannel(channel) return channel==24 and blocks or 0 end
function cylinder:GetUnscaledCapsuleRadius() return 40 end
function cylinder:GetUnscaledCapsuleHalfHeight() return 95 end
local boom=object('CameraBoom',{ProbeChannel=4})
local function solid_eve(name,capsule)
    local her=eve_of(name)
    local e=getmetatable(her).__index
    e.CapsuleComponent,e.CharacterMovement=capsule,movement
    e.K2_GetActorLocation=function() return her_at end
    e.GetComponentByClass=function(_,class)
        return class.path=='/Script/Engine.SpringArmComponent' and boom or invalid
    end
    e.Mesh.RelativeLocation={X=0,Y=0,Z=-97}
    return her
end
local mate={life=1,hp=100,max_hp=100} -- Her vitals, as link.mate() gives them.
link.mate=function() return mate end
player=solid_eve('EVE8',cylinder)
ghost=new(nil,true,look) -- Effects on (above).
ghost.toggle()
send(910,her_parts(),'peer')
ghost.tick()
clock=clock+2
ok,message=build()
assert(ok and message:find('^Ghost 910 built: '),message)
actor=spawned[#spawned]
box=actor.mailbox
local function stand(stamp,x) -- A pose: the ghost's feet at (x, 0, 0), hers where her_at says.
    box.RelativeScale3D.Z,box.RelativeLocation=stamp,{X=x,Y=0,Z=0}
    return ghost.place()
end
her_at={X=600,Y=0,Z=97} -- 1 m from the ghost's feet across, level with its capsule.
assert(stand(60,500)==nil and actor.hidden==false and not actor.capsule,'Off: no capsule')
assert(ghost.status():find(' source=peer collide=off$'),ghost.status())
-- On: built at the next frame, then solid in that frame (1 m apart, level, walking, her vitals alive).
ghost.collide(true)
ok,message=ghost.place()
assert(ok==true and message=='Solid partner built: her capsule type 24 response 2, radius 40, half height 95, 97 cm '
    ..'above her feet; ours type 24; camera probe channel 4; other parts with collision 0.',tostring(message))
local cap=actor.capsule
assert(table.concat(cap.order,' ')=='SetCollisionEnabled K2_SetRelativeLocation SetAbsolute SetCapsuleSize '
    ..'SetGenerateOverlapEvents SetCollisionObjectType SetCollisionResponseToAllChannels '
    ..'SetCollisionResponseToChannel SetCollisionEnabled',table.concat(cap.order,' '))
local args=cap.args
assert(args.K2_SetRelativeLocation[1].X==0 and args.K2_SetRelativeLocation[1].Z==97,'As high as her capsule')
assert(args.SetAbsolute[1]==false and args.SetAbsolute[2]==true and args.SetAbsolute[3]==false,'Upright')
assert(args.SetCapsuleSize[1]==40 and args.SetCapsuleSize[2]==95 and args.SetGenerateOverlapEvents[1]==false)
assert(args.SetCollisionObjectType[1]==24 and args.SetCollisionResponseToAllChannels[1]==0
    and args.SetCollisionResponseToChannel[1]==24 and args.SetCollisionResponseToChannel[2]==2,'Hers, blocked alone')
assert(cap.CanCharacterStepUpOn==0 and actor.label.SetCollisionEnabled==0,'Never a step; the tag has no collision')
assert(actor.collision[1]==true and actor.collision[2]==false,"The actor's collision on")
assert(#cap.enabled==2 and cap.enabled[1]==0 and cap.enabled[2]==1,'Built closed, then solid')
assert(ghost.place()==nil and stand(61,500)==nil and #cap.enabled==2,'Nothing changed: nothing called')
-- b: the ghost steps into her (its stream lags hers): open in that frame, with the contact's line.
ok,message=stand(62,560)
assert(ok==true and message=='Solid partner contact: speed=500 max=600 mode=1 root_motion=none solid=0',
    tostring(message))
assert(#cap.enabled==3 and cap.enabled[3]==0)
assert(stand(63,505)==nil and #cap.enabled==3,'95 cm apart: still open, the same contact')
assert(stand(64,499)==nil and #cap.enabled==4 and cap.enabled[4]==1,'Past 1 m: solid again')
-- c: her feet 60 cm higher than the ghost's.
her_at={X=600,Y=0,Z=157}
assert(ghost.place()==nil and cap.enabled[5]==0)
her_at={X=600,Y=0,Z=156}
assert(ghost.place()==nil and cap.enabled[6]==1)
-- d: she swims, climbs or flies; falling still blocks.
movement.MovementMode=5
ghost.place()
assert(cap.enabled[7]==0)
movement.MovementMode=3
ghost.place()
assert(cap.enabled[8]==1 and #cap.enabled==8)
movement.MovementMode=1
-- g: no vitals from her, or down (life 3 to 5, or 0 HP), opens it; alive again closes it.
mate=nil
ghost.place()
assert(cap.enabled[9]==0)
for _,m in ipairs({{life=3,hp=50,max_hp=100},{life=1,hp=0,max_hp=100}}) do
    mate=m
    ghost.place()
    assert(#cap.enabled==9,'Down')
end
mate={life=6,hp=100,max_hp=100}
ghost.place()
assert(cap.enabled[10]==1)
-- e: in contact with her for 2 s (her walking into it in a doorway): open until 50 cm apart. The contact's line says
-- her move's root motion data.
movement.RootMotionData={pRootMotionData=object('RMD_Evade_F')}
her_at={X=582,Y=0,Z=97}
ok,message=ghost.place()
assert(ok==true and message=='Solid partner contact: speed=500 max=600 mode=1 root_motion=RMD_Evade_F solid=1',
    tostring(message))
clock=clock+0.75; stand(65,499)
clock=clock+0.75; stand(66,499)
assert(#cap.enabled==10,'1.5 s: still solid')
clock=clock+0.75; stand(67,499)
assert(cap.enabled[11]==0,'2.25 s: open')
her_at={X=628,Y=0,Z=97}
assert(ghost.place()==nil and #cap.enabled==11,'49 cm apart: still open')
her_at={X=630,Y=0,Z=97}
assert(ghost.place()==nil and cap.enabled[12]==1)
movement.RootMotionData={pRootMotionData=invalid}
-- a: collide off; the ghost hidden a second after her last pose.
ghost.collide(false)
ghost.place()
assert(cap.enabled[13]==0)
ghost.collide(true)
ghost.place()
assert(cap.enabled[14]==1)
clock=clock+1
ghost.place()
assert(actor.hidden and cap.enabled[15]==0 and #cap.enabled==15)
assert(ghost.status():find(' source=peer collide=on solid=0 changes=solid:7,a:2,b:1,c:1,d:1,e:1,g:1$'),ghost.status())
-- A replay has no vitals: g does not apply to it.
mate=nil
send(910,her_parts(),'replay')
stand(68,499)
assert(actor.hidden==false and #cap.enabled==16 and cap.enabled[16]==1,'Solid without vitals')
-- An effect started on this ghost has no collision; one started on a ghost without the capsule was left as it was.
local spawned_fx=#spawns
slot(1,1,0,1)
box.RelativeScale3D.X=2
ghost.place()
assert(#spawns==spawned_fx+1 and spawns[#spawns].fx.collision==0 and spawns[1].fx.collision==nil)
-- Her capsule not blocking its own type: WorldDynamic (1), which hers blocks, still blocking her type alone.
blocks=0
her_at={X=1,Y=2,Z=3}
ghost.rebuild('test')
build()
actor=spawned[#spawned]
box=actor.mailbox
her_at={X=600,Y=0,Z=97}
ok,message=stand(70,500)
assert(ok==true and message:find(' response 0, .*; ours type 1; '),tostring(message))
assert(actor.capsule.args.SetCollisionObjectType[1]==1 and actor.capsule.args.SetCollisionResponseToChannel[1]==24)
blocks=2
-- One that fails while it is set up: removed, said once, never tried again on this ghost, which stays.
fail_capsule=true
her_at={X=1,Y=2,Z=3}
ghost.rebuild('test')
build()
actor=spawned[#spawned]
box=actor.mailbox
her_at={X=600,Y=0,Z=97}
ok,message=stand(71,500)
assert(ok==false and message:find('^Solid partner off on this ghost: .*no capsule size$'),tostring(message))
assert(actor.capsule.destroyed and #actor.capsule.enabled==1 and not actor.destroyed,'Removed, never with collision')
assert(stand(72,500)==nil and ghost.status():find(' collide=failed$'),ghost.status())
fail_capsule=false
-- No capsule on her EVE at all: the same, nothing added.
her_at={X=1,Y=2,Z=3}
player=solid_eve('EVE9',nil)
ghost.tick()
clock=clock+2
build()
actor=spawned[#spawned]
box=actor.mailbox
her_at={X=600,Y=0,Z=97}
ok,message=stand(73,500)
assert(ok==false and message:find('^Solid partner off on this ghost: '),tostring(message))
assert(not actor.capsule and not actor.destroyed and stand(74,500)==nil,'Said once, never tried again')
link.mate=nil

-- Each fake method refuses a coroutine: an object's own, one added, one replaced, one given in fields, the controller.
local part=cloth_part(object('Owner'))
for what,f in pairs({own=part.GetAddress,added=part.SetVisibility,replaced=part.IsA,given=world.GetFullName,
    controller=package.loaded.UEHelpers.GetPlayerController}) do
    local ok,why=coroutine.resume(coroutine.create(f),part,{path='x'})
    assert(not ok and why:find('lua_instances',1,true),what..' answered from a coroutine')
end
-- No coroutine anywhere in the mod: UE4SS refuses every call made from one (ue4ss() above), and fakes of other
-- modules may lack that check.
local scripts=0
for path in io.popen('ls mod/StellarCoop/Scripts/*.lua'):lines() do
    local file=assert(io.open(path))
    assert(not file:read('a'):find('coroutine%.'),path..' uses a coroutine')
    file:close()
    scripts=scripts+1
end
assert(scripts>=9,'The scripts were listed')
print('puppet_test ok')
