-- The puppet: parts per EVE component, leaders copy her pose, followers follow, cleanup on failure and on toggle.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local function fname(text) return {type=function() return 'FName' end,ToString=function() return text end} end
local next_address=0x1000
local function object(name,fields)
    local o=fields or {}
    next_address=next_address+0x100
    local at=next_address
    o.type=function() return 'UObject' end
    o.GetAddress=function() return at end
    o.GetClass=function() return {GetAddress=function() return name=='Poseable' and 0xc2 or 0xc1 end,type=function() return 'UObject' end} end
    o.GetNumBones=function() return 466 end
    o.IsValid=function(self) return not self.destroyed end
    o.GetFName=function() return fname(name) end
    return o
end
local none={Get=function() return nil end}
local function part(name,leader)
    local c=object(name,{SkeletalMesh=object(name..'Mesh'),MasterPoseComponent=leader and {Get=function() return leader end} or none,
        bHiddenInGame=false})
    function c:GetNumMaterials() return 2 end
    function c:GetMaterial(i) return name..'Material'..i end
    function c:IsVisible() return true end
    function c:K2_GetComponentLocation() return {X=10,Y=20,Z=30} end
    function c:K2_GetComponentRotation() return {Pitch=0,Yaw=90,Roll=0} end
    return c
end
local body=part('Body')
local suit=part('Suit',body)
local orphan=part('Orphan',part('Elsewhere')) -- Its leader is not one of EVE's parts.
local spawned,fail_add={},false
local function poseable()
    local p=object('Poseable',{calls={},copies=0})
    for _,f in ipairs({'SetCollisionEnabled','SetSkeletalMesh','SetVisibility','SetHiddenInGame','SetMasterPoseComponent'}) do
        p[f]=function(self,a) self.calls[f]=a end
    end
    function p:SetMaterial(i,m) self.calls['material'..i]=m end
    function p:K2_SetWorldLocationAndRotation(at,r) self.at,self.rot=at,r end
    function p:CopyPoseFromSkeletalComponent(source) assert(source==body); self.copies=self.copies+1 end
    return p
end
local world={SpawnActor=function(_,class,at)
    assert(class.path=='/Script/Engine.Actor' and at.X==1)
    local a=object('Puppet',{parts={}})
    function a:SetActorEnableCollision() end
    function a:AddComponentByClass(c) assert(c.path=='/Script/Engine.PoseableMeshComponent'); if fail_add then return nil end
        local p=poseable(); self.parts[#self.parts+1]=p; return p end
    function a:K2_DestroyActor() self.destroyed=true end
    function a:K2_GetRootComponent() return self.parts[1] end
    spawned[#spawned+1]=a
    return a
end}
local eve=object('EVE')
function eve:IsA(class) return class.path=='/Script/SB.SBCharacter' end
function eve:GetWorld() return world end
function eve:K2_GetActorLocation() return {X=1,Y=2,Z=3} end
function eve:K2_GetActorRotation() return {Pitch=0,Yaw=90,Roll=0} end
function eve:K2_GetComponentsByClass(class) assert(class.path=='/Script/Engine.SkeletalMeshComponent'); return {body,orphan,suit} end
local player=eve
package.loaded.UEHelpers={GetPlayer=function() return player end}
StaticFindObject=function(path)
    local c=object(path,{path=path})
    if path=='/Script/Engine.Default__KismetMathLibrary' then c.MakeTransform=function() return 'identity' end end
    return c
end
local tables={}
local puppet=require('puppet').new(function(text) tables[#tables+1]=text or 'withdrawn'; return true end)

assert(puppet.tick()==nil,'No puppet, no work')
player=nil
local built,err=pcall(puppet.toggle)
assert(not built and tostring(err):find('Load a save first') and #spawned==0,tostring(err))
player=eve
local ok,message=puppet.toggle()
assert(ok and message:find('2 parts (1 leaders), 1 skipped',1,true),message)
assert(message:find('component table 1 published',1,true),message)
local t=tables[1]
assert(t:find('^generation 1\nroot 0x%x+\n'),t)
assert(t:find('\npart eve 0 0x%x+ 0xc1 0x%x+ 466 1\npart puppet 0 0x%x+ 0xc2 0x%x+ 466 1\n'),t)
assert(t:find('\npart eve 1 0x%x+ 0xc1 0x%x+ 466 0\npart puppet 1 0x%x+ 0xc2 0x%x+ 466 0\n$'),t)
local eve_mesh,puppet_mesh=t:match('part eve 0 0x%x+ 0xc1 (0x%x+)'),t:match('part puppet 0 0x%x+ 0xc2 (0x%x+)')
assert(eve_mesh==puppet_mesh,'Both sides publish the same mesh')
local actor=spawned[1]
local lead,follow=actor.parts[1],actor.parts[2]
assert(lead.calls.SetSkeletalMesh==body.SkeletalMesh and lead.calls.material1=='BodyMaterial1' and lead.calls.SetCollisionEnabled==0)
assert(follow.calls.SetMasterPoseComponent==lead and lead.calls.SetMasterPoseComponent==nil,'The follower follows the puppet leader')
assert(puppet.tick()==nil)
-- Yaw 90: her right is -X in Unreal's left-handed frame.
assert(math.abs(lead.at.X-(10-200))<1e-6 and math.abs(lead.at.Y-20)<1e-6 and lead.at.Z==30 and lead.rot.Yaw==90)
assert(lead.copies==1 and follow.copies==0,'Only leaders copy her pose')
suit.destroyed=true
local stopped,why=puppet.tick()
assert(stopped==false and why:find('stopped: .*a part left the world') and actor.destroyed,why)
assert(tables[#tables]=='withdrawn','A stopped puppet withdraws its table')
assert(puppet.tick()==nil,'A failed puppet is gone')
suit.destroyed=false
assert(puppet.toggle() and not spawned[2].destroyed)
local _,removed=puppet.toggle()
assert(spawned[2].destroyed and removed:find('Puppet removed (coop puppet) after 0 frames',1,true),removed)
assert(tables[#tables]=='withdrawn' and tables[#tables-1]:find('^generation 2'),'A new table per build')
fail_add=true
built,err=pcall(puppet.toggle)
assert(not built and tostring(err):find('could not be added') and spawned[3].destroyed,'A failed setup leaves nothing behind')
assert(puppet.tick()==nil)
print('puppet_test ok')
