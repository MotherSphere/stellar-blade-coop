-- The ghost with fake UE4SS objects: built from the remote table one mesh a frame, each part on the mesh the table names
-- (LoadAsset, never SetMaterial) or on the base suit with a bone remap, left out with its followers when it has no
-- fallback; the display file; hidden until the first pose and after a second without one; the loopback's offset; the
-- map gate; the same table re-dressed in place; level change, comeback, the remote table gone, basesuit, the sweep.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
local function fname(text) return {type=function() return 'FName' end,ToString=function() return text end} end
FName=fname
local next_address=0x1000
local function object(name,fields,class_address)
    local o=fields or {}
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
local lookups,loads=0,{} -- Mesh lookups (StaticFindObject on a /Game path) and LoadAsset's paths.
LoadAsset=function(path) loads[#loads+1]=path; return meshes[path] or invalid end

local spawned={}
local function poseable(actor)
    local p=object('Poseable',{calls={}},0xc2)
    for _,f in ipairs({'SetCollisionEnabled','SetMasterPoseComponent','SetForcedLOD'}) do
        p[f]=function(self,a) self.calls[f]=a end
    end
    function p:SetSkeletalMesh(m) self.mesh=m end
    function p:GetNumBones() return #self.mesh.bones end
    function p:GetBoneName(j) return fname(self.mesh.bones[j+1]) end
    function p:SetVisibility(v) self.visible=v end
    function p:K2_SetWorldLocationAndRotation(at,r) self.at,self.rot=at,r; self.moves=(self.moves or 0)+1 end
    function p:K2_AttachToComponent(parent,socket,a,b,c) self.attached={parent=parent,socket=socket:ToString(),rules={a,b,c}} end
    function p:K2_SetRelativeTransform(t) self.relative=t end
    function p:K2_DestroyComponent(owner) assert(owner==actor,'DestroyComponent takes the owner'); self.destroyed=true end
    function p:IsA(class) return class.path=='/Script/Engine.PoseableMeshComponent' end
    return p -- No SetMaterial: a call fails the build, so the test.
end
local fail_add=false
local world={SpawnActor=function(_,class,at)
    assert(class.path=='/Script/Engine.Actor' and at.X==1)
    local a=object('Ghost',{parts={}})
    function a:SetActorEnableCollision() end
    function a:SetActorHiddenInGame(hidden) self.hidden=hidden end
    function a:AddComponentByClass(c,manual)
        if fail_add then return nil end
        if c.path=='/Script/Engine.SceneComponent' then
            assert(manual==true,'The mailbox is never attached')
            local box=object('Mailbox',{RelativeScale3D={X=1,Y=1,Z=1},RelativeLocation={X=0,Y=0,Z=0},
                RelativeRotation={Pitch=0,Yaw=0,Roll=0}},0x5c0)
            self.mailbox=box
            return box
        end
        assert(c.path=='/Script/Engine.PoseableMeshComponent' and manual==false)
        local p=poseable(self); self.parts[#self.parts+1]=p; return p
    end
    function a:K2_DestroyActor() self.destroyed=true end
    function a:K2_GetRootComponent() return self.parts[1] end
    function a:GetFullName() return 'Actor /Game/Map.Map:PersistentLevel.Actor_'..#spawned end
    spawned[#spawned+1]=a
    return a
end,GetFullName=function() return 'World /Game/Art/BG/WorldMap/Level_P/E04.E04' end}
-- EVE reads only: the ghost never writes to her.
local function eve_of(name,map_world,at)
    local e=object(name)
    if at then e.GetAddress=function() return at end end -- Where a freed EVE was.
    function e:IsA(class) return class.path=='/Script/SB.SBCharacter' end
    function e:GetWorld() return map_world or world end
    function e:K2_GetActorLocation() return {X=1,Y=2,Z=3} end
    return setmetatable({},{__index=e,__newindex=function(_,key) error('the ghost wrote '..key..' on EVE',2) end})
end
local eve=eve_of('EVE')
local player=eve
package.loaded.UEHelpers={GetPlayer=function() return player end}
local found_by_path={}
StaticFindObject=function(path)
    if found_by_path[path] then return found_by_path[path] end
    if path:find('^/Game/') then
        lookups=lookups+1
        return in_memory[path] and meshes[path] or invalid
    end
    local c=object(path,{path=path})
    if path=='/Script/Engine.Default__KismetMathLibrary' then c.MakeTransform=function() return 'identity' end end
    return c
end

-- The remote table as the native part writes it.
local function her_parts(o)
    o=o or {}
    return {
        {name='CharacterMesh0',path=o.body or BODY,names={'Root','Bip001','Bip001-Pelvis'}},
        {name='Mesh_Face',lead=0,parent=0,path=FACE},
        {name='SBHair',parent=0,socket='Bip001-Head',path=o.hair or HAIR,names={'Bip001-Head','Hair_01'},
            place='0 0 0.707106769 0.707106769 1.5 -2 0.25 1 1 1'},
        {name='SBPonytail',lead=2,parent=2,shown=false,path=PONY},
        {name='SBSkeletalMeshComponent_7',parent=0,socket=o.socket or 'SC_SwordingPoint',shown=o.blade_shown,
            path=o.blade or BLADE,names={'Root'},place='0 0 0 1 10.25 0 1 1 1 1'},
        {name='Scabbard',lead=4,parent=4,path=PONY}, -- Follows the blade.
    }
end
local function remote_text(generation,parts,map)
    local lines={'SBT 3','generation '..generation,'map '..(map or '/game/art/bg/worldmap/level_p/e04')}
    for i,p in ipairs(parts) do
        lines[#lines+1]=string.format('part %d %s %s %s %d %d %s %s',i-1,p.lead or '-',p.parent or '-',p.socket or '-',
            p.shown==false and 0 or 1,p.names and #p.names or 0,p.name,p.path or '-')
        if i>1 then lines[#lines+1]='place '..(i-1)..' '..(p.place or '0 0 0 1 0 0 0 1 1 1') end
        if p.names then lines[#lines+1]='names '..(i-1)..' '..table.concat(p.names,' ') end
    end
    return table.concat(lines,'\n')..'\n'
end
local remote_file,displays,stored=nil,{},nil
local store={save=function(p) stored=p end,load=function() return stored end,clear=function() stored=nil end}
local link={remote_table=function() return remote_file end,store=function() return store end,
    display=function(text) displays[#displays+1]=text or 'withdrawn'; return true end}
local capture={yaw_delta=function() return 90 end} -- Her actor faces yaw 90 more than her mesh.
local function new(path_left)
    stored=path_left
    package.loaded.puppet=nil
    return require('puppet').new(link,capture)
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
    for _=1,30 do
        local before=lookups
        local ok,message=ghost.tick()
        assert(lookups-before<=1,'One mesh resolved a frame at most')
        if message then return ok,message end
    end
    error('the build never ended')
end

assert(ghost.tick()==nil and ghost.status()=='ghost=off','Off: nothing')
send(500,her_parts())
assert(ghost.tick()==nil and #spawned==0,'Off: no ghost, even with a table')
local ok,message=ghost.toggle()
assert(ok and message:find('^Ghost on: '),message)
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
-- The display file: each leader driven as it came.
local d=displays[#displays]:gsub('0x%x+','0xX')
assert(d=='display 500\nmailbox 0xX 0xX\ndrive 0 0xX 0xX 0xX 3\ndrive 2 0xX 0xX 0xX 2\ndrive 4 0xX 0xX 0xX 1\n',d)
assert(displays[#displays]:find('\nmailbox 0x%x+ 0x5c0\ndrive 0 '..string.format('0x%x',root.GetAddress())..' 0xc2 '
    ..string.format('0x%x',meshes[BODY].GetAddress())..' 3\n'),'The loaded mesh, not hers')
assert(ghost.status()=='ghost=on parts=6 leaders=3 basesuit=0 left_out=0 table=500 source=loopback',ghost.status())

-- Shown at the first pose, placed from the mailbox 2 m to her right in loopback; hidden a second after the last pose.
assert(ghost.place()==nil and actor.hidden and not root.moves,'No stamp yet: nothing')
local box=actor.mailbox
box.RelativeScale3D.Z=5
box.RelativeLocation={X=100,Y=0,Z=30}
box.RelativeRotation={Pitch=0,Yaw=0,Roll=0}
ghost.place()
assert(actor.hidden==false and root.moves==1,'Shown at the first stamp')
assert(math.abs(root.at.X-(100-200))<1e-6 and math.abs(root.at.Y)<1e-6 and root.at.Z==30,'Her right: mesh yaw 0 plus 90')
clock=clock+0.9
ghost.place()
assert(actor.hidden==false and root.moves==1,'The same stamp: not moved again, still shown')
clock=clock+0.1
ghost.place()
assert(actor.hidden==true,'A second without a pose: hidden, never frozen in view')
box.RelativeScale3D.Z=6
ghost.place()
assert(actor.hidden==false and root.moves==2)

-- The same generation with the blade sheathed and shown otherwise: applied in place, no rebuild.
local displays_before=#displays
assert(send(500,her_parts({socket='SC_Back',blade_shown=false}))==nil)
assert(#spawned==1 and not actor.destroyed and #displays==displays_before,'No rebuild, the display stays')
assert(blade.attached.socket=='SC_Back' and blade.visible==false and hair.attached.socket=='Bip001-Head')
assert(ghost.tick()==nil,'Nothing to build')

-- A replay: placed where it was, no offset.
send(500,her_parts({socket='SC_Back',blade_shown=false}),'replay')
box.RelativeScale3D.Z=7
ghost.place()
assert(math.abs(root.at.X-100)<1e-6 and math.abs(root.at.Y)<1e-6,'No offset off the loopback')
assert(ghost.status():find(' source=replay$'),ghost.status())

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

-- A failed build says why, leaves nothing behind and is not tried again on that table; a new table tries again.
send(506,her_parts())
fail_add=true
ok,message=build()
assert(ok==false and message:find('^Ghost not built: .*could not be added') and spawned[#spawned].destroyed,message)
assert(ghost.tick()==nil,'Not again on table 506')
fail_add=false
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

-- The next Lua load sweeps a ghost left standing, once it checks it is ours; a stranger at that path is left alone.
local left=spawned[1]
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
print('puppet_test ok')
