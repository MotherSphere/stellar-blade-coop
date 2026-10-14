-- The puppet with fake UE4SS objects: parts hang as hers, the component table, copy and mirror modes, the sweep of a
-- puppet left by an earlier Lua load, the comeback after a level change, cleanup on failure and on toggle.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
os.time=function() return 1000 end -- Table generations start at 1000 * 100. -- The comeback waits 2 s and visibility refreshes once a second.
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
    o.GetNumBones=function() return 466 end
    return o
end
local none={Get=function() return nil end}
local transforms={} -- Fake FTransforms by name, for the relative placement checks.
local function part(name,leader,parent,socket,visible)
    local c=object(name,{SkeletalMesh=object(name..'Mesh'),MasterPoseComponent=leader and {Get=function() return leader end} or none,
        bHiddenInGame=false})
    c.visible=visible~=false
    function c:GetNumMaterials() return 2 end
    function c:GetMaterial(i) return name..'Material'..i end
    function c:IsVisible() return self.visible end
    function c:K2_GetComponentLocation() return {X=10,Y=20,Z=30} end
    function c:K2_GetComponentRotation() return {Pitch=0,Yaw=0,Roll=0} end -- Her mesh faces yaw 0, her actor 90.
    function c:GetAttachParent() return parent end
    function c:GetAttachSocketName() return fname(socket or 'None') end
    function c:GetRelativeTransform() return 'relative of '..name end
    function c:K2_GetComponentToWorld() return 'world of '..name end
    return c
end
local capsule=object('Capsule')
local body=part('Body',nil,capsule)
local suit=part('Suit',body,body)
local blade=part('Blade',nil,body,'hand_r')
local orphan=part('Orphan',part('Elsewhere')) -- Its leader is not one of EVE's parts.
local spawned={}
local function poseable(class_address)
    local p=object('Poseable',{calls={},copies=0,attached=nil},class_address or 0xc2)
    for _,f in ipairs({'SetCollisionEnabled','SetSkeletalMesh','SetHiddenInGame','SetMasterPoseComponent','SetForcedLOD'}) do
        p[f]=function(self,a) self.calls[f]=a end
    end
    function p:SetVisibility(v) self.calls.SetVisibility=v; self.visible=v end
    function p:SetMaterial(i,m) self.calls['material'..i]=m end
    function p:K2_SetWorldLocationAndRotation(at,r) self.at,self.rot=at,r; self.moves=(self.moves or 0)+1 end
    function p:K2_AttachToComponent(parent,socket,a,b,c) self.attached={parent=parent,socket=socket:ToString(),rules={a,b,c}} end
    function p:K2_SetRelativeTransform(t) self.relative=t end
    function p:CopyPoseFromSkeletalComponent(source) assert(source==body or source==blade); self.copies=self.copies+1 end
    function p:IsA(class) return class.path=='/Script/Engine.PoseableMeshComponent' end
    return p
end
local fail_add=false
local world={SpawnActor=function(_,class,at)
    assert(class.path=='/Script/Engine.Actor' and at.X==1)
    local a=object('Puppet',{parts={}})
    function a:SetActorEnableCollision() end
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
        local p=poseable(); self.parts[#self.parts+1]=p; return p
    end
    function a:K2_DestroyActor() self.destroyed=true end
    function a:K2_GetRootComponent() return self.parts[1] end
    function a:GetFullName() return 'Actor /Game/Map.Map:PersistentLevel.Actor_'..#spawned end
    spawned[#spawned+1]=a
    return a
end}
local eve=object('EVE',{Mesh=body})
function eve:IsA(class) return class.path=='/Script/SB.SBCharacter' end
function eve:GetWorld() return world end
function eve:K2_GetActorLocation() return {X=1,Y=2,Z=3} end
function eve:K2_GetActorRotation() return {Pitch=0,Yaw=90,Roll=0} end
function eve:K2_GetComponentsByClass(class) assert(class.path=='/Script/Engine.SkeletalMeshComponent'); return {suit,orphan,blade,body} end
local player=eve
package.loaded.UEHelpers={GetPlayer=function() return player end}
local found_by_path={}
StaticFindObject=function(path)
    if found_by_path[path] then return found_by_path[path] end
    local c=object(path,{path=path})
    if path=='/Script/Engine.Default__KismetMathLibrary' then
        c.MakeTransform=function() return 'identity' end
        c.MakeRelativeTransform=function(_,a,b) return a..' relative to '..b end
    end
    return c
end

local tables,stored={},nil
local store={save=function(p) stored=p end,load=function() return stored end,clear=function() stored=nil end}
local function new(path_left)
    stored=path_left
    return require('puppet').new(function(text) tables[#tables+1]=text or 'withdrawn'; return true end,store)
end
package.loaded.puppet=nil
local puppet=new(nil)

assert(puppet.tick()==nil,'No puppet, no work')
assert(puppet.status()=='puppet=off')
player=nil
local built,err=pcall(puppet.toggle)
assert(not built and tostring(err):find('Load a save first') and #spawned==0,tostring(err))
player=eve
local ok,message=puppet.toggle()
assert(ok and message:find('3 parts (2 leaders, 2 hung as hers), 1 skipped without a leader',1,true),message)
assert(message:find('component table 100001 published',1,true),message)
local actor=spawned[1]
local root,blade_p,suit_p=actor.parts[1],actor.parts[2],actor.parts[3] -- Main mesh, leaders, followers.
-- Her main mesh first and the root; the follower hangs from it; the blade keeps her hand socket and placement.
assert(root.calls.SetSkeletalMesh==body.SkeletalMesh and root.calls.SetForcedLOD==1 and root.attached==nil)
assert(blade_p.calls.SetSkeletalMesh==blade.SkeletalMesh and blade_p.calls.SetForcedLOD==1)
assert(suit_p.calls.SetMasterPoseComponent==root and suit_p.bUseBoundsFromMasterPoseComponent==true)
assert(suit_p.attached.parent==root and suit_p.attached.socket=='None' and suit_p.relative=='relative of Suit')
assert(blade_p.attached.parent==root and blade_p.attached.socket=='hand_r' and blade_p.relative=='relative of Blade')
assert(blade_p.attached.rules[1]==0 and blade_p.attached.rules[2]==0 and blade_p.attached.rules[3]==0,'KeepRelative')
assert(stored=='/Game/Map.Map:PersistentLevel.Actor_1','The path is kept for the next Lua load')
-- The table: the mailbox, then her parts and the puppet's index for index.
local t=tables[1]
assert(t:find('^generation 100001\nmailbox 0x%x+ 0x5c0\n'),t)
assert(t:find('\npart eve 0 0x%x+ 0xc1 0x%x+ 466 1\npart puppet 0 0x%x+ 0xc2 0x%x+ 466 1\n'),t)
assert(t:find('\npart eve 1 0x%x+ 0xc1 0x%x+ 466 1\npart puppet 1 0x%x+ 0xc2 0x%x+ 466 1\n'),t)
assert(t:find('\npart eve 2 0x%x+ 0xc1 0x%x+ 466 0\npart puppet 2 0x%x+ 0xc2 0x%x+ 466 0\n$'),'The follower is part 2')

-- Copy mode: only the root moves, 2 m to her right (actor yaw 90: her right is -X); leaders copy her pose.
assert(puppet.tick()==nil)
assert(root.moves==1 and not suit_p.moves and not blade_p.moves,'Children hang from the root')
assert(math.abs(root.at.X-(10-200))<1e-6 and math.abs(root.at.Y-20)<1e-6 and root.at.Z==30)
assert(root.copies==1 and blade_p.copies==1 and suit_p.copies==0,'Only leaders copy her pose')
assert(puppet.status()=='puppet=on parts=3 mode=copy table=100001')

-- Mirror mode for this table: no copying; place() (after the native tick) waits for a native stamp (the engine
-- default scale Z is 1), then follows the mailbox.
assert(puppet.place()==nil and root.moves==1,'place() does nothing in copy mode')
puppet.set_mirror(100001,'loopback')
assert(puppet.status()=='puppet=on parts=3 mode=loopback table=100001','The native mode shows in coop status')
puppet.set_mirror(100001,'mirror')
assert(puppet.status()=='puppet=on parts=3 mode=mirror table=100001')
puppet.tick()
puppet.place()
assert(root.moves==1 and root.copies==1,'Nothing before the first native write')
actor.mailbox.RelativeScale3D.Z=5
actor.mailbox.RelativeLocation={X=100,Y=0,Z=0}
actor.mailbox.RelativeRotation={Pitch=0,Yaw=0,Roll=0}
puppet.tick()
assert(root.moves==1 and root.copies==1,'tick() leaves the root to place() in mirror mode')
puppet.place()
assert(root.moves==2 and root.copies==1,'Mirror: placed from the mailbox, no copy')
assert(math.abs(root.at.X-(100-200))<1e-6 and math.abs(root.at.Y)<1e-6,'Her right from the mesh yaw plus the 90 actor delta')
puppet.set_mirror(7) -- Another table's mirror: copy again.
puppet.tick()
assert(root.copies==2)
puppet.set_mirror(nil)

-- Her blade moves from her hand to her back: hung again on the next second.
blade.GetAttachSocketName=function() return fname('back') end
clock=clock+1
puppet.tick()
assert(blade_p.attached.socket=='back' and blade_p.attached.parent==root,'Re-hung on her new socket')
blade.GetAttachSocketName=function() return fname('hand_r') end
clock=clock+1
puppet.tick()
assert(blade_p.attached.socket=='hand_r')

-- Visibility follows hers once a second.
blade.visible=false
puppet.tick()
assert(blade_p.visible~=false,'Not before the second is up')
clock=clock+1
puppet.tick()
assert(blade_p.visible==false)
blade.visible=true

-- Her outfit changes (a new mesh on a part): a new puppet and table at once.
local before=#spawned
local old_mesh=suit.SkeletalMesh
suit.SkeletalMesh=object('NewSuitMesh')
clock=clock+1
puppet.tick()
assert(actor.destroyed and tables[#tables]=='withdrawn','The old puppet goes')
local _,outfit_message=puppet.tick()
assert(#spawned==before+1 and tables[#tables]:find('^generation 100002\n'),'Rebuilt with the new outfit at once')
assert(outfit_message=='Puppet back in her new outfit.',tostring(outfit_message))
actor=spawned[#spawned]
suit.SkeletalMesh=old_mesh
clock=clock+1
puppet.tick() -- The suit changed back: rebuilt again.
puppet.tick()
actor=spawned[#spawned]
assert(not actor.destroyed)

-- A level change: EVE becomes another object; the puppet goes, then comes back 2 s after she is in the world.
player=object('EVE2',{Mesh=body})
for k,v in pairs(eve) do if player[k]==nil then player[k]=v end end
puppet.tick()
assert(actor.destroyed and tables[#tables]=='withdrawn' and stored==nil,'Removed and withdrawn on the level change')
assert(puppet.status():find('puppet=waiting',1,true))
local count=#spawned
assert(puppet.tick()==nil and #spawned==count,'Waits 2 s')
clock=clock+2
local back,back_message=puppet.tick()
assert(back and back_message:find('back after a level change',1,true),back_message)
assert(tables[#tables]:find('^generation 10000[45]\n'),'A new table for the new puppet')
-- A pawn that is not EVE (title screen, a menu pawn): the comeback waits, it never gives up.
local menu_pawn=object('MenuPawn')
function menu_pawn:IsA() return false end
player=menu_pawn
puppet.tick()
clock=clock+3
puppet.tick()
assert(puppet.active() and puppet.status():find('puppet=waiting',1,true),'Still waiting for EVE')
player=eve

-- Any other failure removes it for good and says why.
puppet.tick() -- EVE changed back: another comeback cycle.
clock=clock+2
puppet.tick()
local current=spawned[#spawned]
suit.destroyed=true
clock=clock+1
local stopped,why=puppet.tick()
assert(stopped==false and why:find('stopped: .*a part left the world') and current.destroyed,why)
assert(puppet.tick()==nil and not puppet.active(),'A failed puppet is gone')
suit.destroyed=false

-- Toggle off and on; a failed setup leaves nothing behind.
assert(puppet.toggle() and puppet.active())
local _,removed=puppet.toggle()
assert(spawned[#spawned].destroyed and removed:find('Puppet removed (coop puppet)',1,true),removed)
assert(tables[#tables]=='withdrawn' and stored==nil)
fail_add=true
built,err=pcall(puppet.toggle)
assert(not built and tostring(err):find('could not be added') and spawned[#spawned].destroyed,'A failed setup leaves nothing behind')
fail_add=false

-- The next Lua load sweeps a puppet left standing, once it checks it is ours; a stranger at that path is left alone.
local left=spawned[1]
left.destroyed=false
found_by_path['/Game/Map.Map:PersistentLevel.Actor_1']=left
package.loaded.puppet=nil
local reloaded=new('/Game/Map.Map:PersistentLevel.Actor_1')
assert(not left.destroyed,'Not while the Lua state loads: on the game thread only')
local _,first=reloaded.toggle()
assert(left.destroyed,'Swept on the first game-thread call')
assert(first:find('^Removed a puppet left by an earlier Lua load%.'),first)
local stranger=object('Stranger')
function stranger:K2_GetRootComponent() return object('Capsule2',{IsA=function() return false end}) end
function stranger:K2_DestroyActor() self.destroyed=true end
found_by_path['/Game/Map.Map:PersistentLevel.Actor_9']=stranger
package.loaded.puppet=nil
new('/Game/Map.Map:PersistentLevel.Actor_9').tick()
assert(not stranger.destroyed and stored==nil,'Not ours: left alone')
print('puppet_test ok')
