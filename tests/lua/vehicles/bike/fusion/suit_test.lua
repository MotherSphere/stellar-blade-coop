-- vehicles/bike/fusion/suit.lua with fake UE4SS objects (dev build): the suit-up by turns (wipe, then Tachy);
-- every swap keeps her riding clip (SetSkeletalMesh with bReinitPose false) and the wipe's end puts materials back
-- only (2026-11-19: a mesh swap after the riding pose left EVE standing inside the bike in Eve Hoverbike); a keeper
-- holds her own body; wings follow her pose; the dismount puts her own body back and drops every helper; no pak: no
-- suit, her outfit untouched.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
FName=function(t) return {type=function() return 'FName' end,ToString=function() return t end} end
local next_address=0x1000
local function object(o)
    next_address=next_address+0x100
    local at=next_address
    o=o or {}
    o.type=function() return 'UObject' end
    o.IsValid=o.IsValid or function(self) return not self.destroyed end
    o.GetAddress=function() return at end
    o.IsA=o.IsA or function() return true end
    return o
end
local assets,missing,shows,niagara={},{},{},{}
local function asset(path)
    if missing[path] then return nil end
    assets[path]=assets[path] or object({path=path,GetFullName=function() return 'Object '..path end})
    return assets[path]
end
local function mid(parent)
    local m=object({parent=parent,s={},t={},v={}})
    function m:SetScalarParameterValue(k,v) self.s[k:ToString()]=v end
    function m:SetTextureParameterValue(k,v) self.t[k:ToString()]=v end
    function m:SetVectorParameterValue(k,v) self.v[k:ToString()]=v end
    return m
end
local function comp(mesh,mats)
    local c=object({SkeletalMesh=mesh,mats=mats,swaps={}})
    function c:SetSkeletalMesh(m,reinit) self.SkeletalMesh=m self.swaps[#self.swaps+1]=reinit end
    function c:GetNumMaterials() return #self.mats end
    function c:GetMaterial(i) return self.mats[i+1] end
    function c:SetMaterial(i,m) self.mats[i+1]=m end
    function c:CreateDynamicMaterialInstance(i,p) local m=mid(p) self.mats[i+1]=m return m end
    function c:SetMasterPoseComponent(m) self.master=m end
    function c:SetComponentTickEnabled() end
    return c
end
local actors={}
local world=object({})
function world:SpawnActor()
    local a=object({SkeletalMeshComponent=comp(nil,{}),hidden=false})
    function a:SetActorHiddenInGame(h) self.hidden=h end
    function a:SetActorEnableCollision() end
    function a:K2_AttachToComponent(p) self.parent=p end
    function a:K2_DestroyActor() self.destroyed=true end
    actors[#actors+1]=a
    return a
end
local lib=object({})
function lib:PlaySBShowToPlayerCharacter(s) shows[#shows+1]=s end
local nfl=object({})
function nfl:SpawnSystemAttached(sys)
    local n=object({sys=sys})
    function n:Deactivate() self.off=true end
    function n:K2_DestroyComponent() self.destroyed=true end
    function n:SetNiagaraVariableFloat() end
    niagara[#niagara+1]=n
    return n
end
local gs=object({})
function gs:SpawnDecalAttached()
    local d=object({})
    function d:CreateDynamicMaterialInstance() self.mid=mid() return self.mid end
    function d:K2_DestroyComponent() self.destroyed=true end
    return d
end
StaticFindObject=function(path)
    if path:find('SBBlueprintLibrary',1,true) then return lib end
    if path:find('NiagaraFunctionLibrary',1,true) then return nfl end
    if path:find('GameplayStatics',1,true) then return gs end
    if path:find('^/Script/') then return object({path=path}) end
    return assets[path] or object({destroyed=true})
end
LoadAsset=function(path) return asset(path) end
local clock=0
os.clock=function() return clock end
local Suit=require('vehicles.bike.fusion.suit')

local own_mesh,own0,own1=object({}),object({}),object({})
local function eve()
    local e=object({Mesh=comp(own_mesh,{own0,own1})})
    function e:K2_GetActorLocation() return {X=0,Y=0,Z=0} end
    function e:GetWorld() return world end
    return e
end
local suit_mesh=asset(Suit.MESH)

-- 1. A mount with the wipe (Suit.ON set to it). Her body wears the suit mesh at once, without restarting her clip.
Suit.ON,Suit.OFF="prologue","prologue"
local e=eve()
local s,said=Suit.on(e)
assert(s and said:find('prologue wipe',1,true) and said:find('wings on',1,true),said)
assert(e.Mesh.SkeletalMesh==suit_mesh and #e.Mesh.swaps==1 and e.Mesh.swaps[1]==false,'suit mesh on, clip kept')
assert(e.Mesh.mats[1].s.MaskDirection==1,'masking copies on her body, new side')
local keeper=actors[1]
assert(keeper.hidden and keeper.SkeletalMeshComponent.SkeletalMesh==own_mesh
    and keeper.SkeletalMeshComponent.mats[2]==own1,'keeper holds her own body')
local copy=actors[2]
assert(not copy.hidden and copy.SkeletalMeshComponent.master==e.Mesh and copy.SkeletalMeshComponent.mats[1].s.MaskDirection==0,
    'old outfit copy follows her pose, old side')
local wings=actors[3]
assert(not wings.hidden and wings.parent==e.Mesh and wings.SkeletalMeshComponent.master==e.Mesh,'wings follow her pose')
clock=Suit.TIME/2
Suit.tick(s,e)
assert(math.abs(e.Mesh.mats[1].s.HeightMask-(Suit.H0+Suit.H1)/2)<1e-9,'half way')
clock=Suit.TIME+0.01
Suit.tick(s,e)
assert(#e.Mesh.swaps==1,'the wipe ends with materials only: no second mesh swap')
assert(e.Mesh.mats[1]==asset(Suit.MATS[1]) and e.Mesh.mats[4]==asset(Suit.MATS[4]),"the suit's real materials")
assert(copy.destroyed and s.fx==nil,'copy gone, suit-up over')
for _,n in ipairs(niagara) do assert(n.destroyed) end

-- 2. Dismount: her own body back, still without restarting her animation; helpers gone.
-- 2. Dismount (Saroj 2026-11-19): the same wipe backward to her own outfit; wings and keeper go at its end.
clock=10
local back=Suit.off(s,e)
assert(back:find('prologue wipe',1,true) and back:find('back to her own outfit',1,true),back)
assert(e.Mesh.SkeletalMesh==own_mesh and e.Mesh.swaps[2]==false,'her own mesh at once, animation kept')
assert(e.Mesh.mats[1].s.MaskDirection==1 and e.Mesh.mats[2].s.HeightMask==Suit.H0,'her own outfit wipes in')
local copy2=actors[4]
assert(copy2.SkeletalMeshComponent.SkeletalMesh==suit_mesh and copy2.SkeletalMeshComponent.mats[1].s.MaskDirection==0,
    'the suit wipes out on a copy')
assert(not keeper.destroyed and not wings.destroyed and not s.done,'wings stay while it plays')
clock=10+Suit.TIME/2
Suit.tick(s,e)
assert(not s.done)
clock=10+Suit.TIME+0.01
Suit.tick(s,e)
assert(#e.Mesh.swaps==2 and e.Mesh.mats[1]==own0 and e.Mesh.mats[2]==own1,'her own materials, no third mesh swap')
assert(copy2.destroyed and keeper.destroyed and wings.destroyed and s.done and s.fx==nil)
assert(Suit.off(s,e)=='no suit' and Suit.drop(s,e)=='no suit','done: nothing more')

-- 3. A mount with the Tachy show; the swap after its flash, clip kept. Its dismount set to the show too: her own body
-- back at its flash.
actors,clock={},0
Suit.ON,Suit.OFF='tachy','tachy'
e=eve()
s,said=Suit.on(e)
assert(said:find('Tachy',1,true) and #shows==1 and #e.Mesh.swaps==0,'no swap before the flash')
clock=0.05
Suit.tick(s,e)
assert(#e.Mesh.swaps==0)
clock=0.2
Suit.tick(s,e)
assert(e.Mesh.SkeletalMesh==suit_mesh and e.Mesh.swaps[1]==false and s.fx==nil,'swapped at the flash, clip kept')
clock=5
assert(Suit.off(s,e):find('Tachy',1,true) and #shows==2 and e.Mesh.SkeletalMesh==suit_mesh,'show first, suit still on')
clock=5.2
Suit.tick(s,e)
assert(e.Mesh.SkeletalMesh==own_mesh and e.Mesh.swaps[2]==false and e.Mesh.mats[1]==own0 and s.done)
assert(actors[1].destroyed and actors[2].destroyed,'keeper and wings gone')

-- 4. A new mount cuts the dismount's change short: her own outfit at once.
actors,clock={},0
Suit.ON,Suit.OFF="prologue","prologue"
e=eve()
s=Suit.on(e)
clock=5
Suit.off(s,e)
clock=5.3
Suit.tick(s,e)
assert(Suit.drop(s,e)=='her own body back' and e.Mesh.SkeletalMesh==own_mesh and e.Mesh.mats[1]==own0 and s.done)
assert(actors[4].destroyed and actors[1].destroyed and actors[3].destroyed,'copy, keeper and wings gone')

-- 5. Her EVE gone mid change (a load): the change ends, keepers go, nothing written on the new one.
actors,clock={},0
e=eve()
s=Suit.on(e)
Suit.off(s,e)
local other=eve()
Suit.tick(s,other)
assert(s.done and other.Mesh.SkeletalMesh==own_mesh and #other.Mesh.swaps==0)
-- dismount on another EVE: no change, nothing written
s=Suit.on(eve())
assert(Suit.off(s,eve())=='her EVE is gone' and s.done)

-- 6. Saroj's pair (the defaults): get on with the Fusion (Tachy) show, get off with the drop-pod wipe.
Suit.ON,Suit.OFF='tachy','prologue'
actors,clock,shows={},0,{}
e=eve()
s,said=Suit.on(e)
assert(said:find('Tachy',1,true) and #shows==1,said)
local wc=actors[#actors].SkeletalMeshComponent -- the wings, made last at the mount
assert(wc.bUseBoundsFromMasterPoseComponent==true,'wings use her bounds: never culled on their own')
wc.master=nil
clock=0.2
Suit.tick(s,e)
assert(e.Mesh.SkeletalMesh==suit_mesh and s.fx==nil)
assert(wc.master==e.Mesh and s.report and s.report:find('wings',1,true),'wings linked again after the swap, state logged')
clock=5
said=Suit.off(s,e)
assert(said:find('prologue wipe',1,true) and #shows==1 and e.Mesh.SkeletalMesh==own_mesh,'off: the wipe, no show')
clock=5+Suit.TIME+0.01
Suit.tick(s,e)
assert(s.done and e.Mesh.mats[1]==own0)

-- 5. No pak: no suit, her outfit untouched.
actors={}
missing[Suit.MESH]=true
assets[Suit.MESH].destroyed=true
assets[Suit.MESH]=nil
e=eve()
local none,why=Suit.on(e)
assert(none==nil and why:find('EveBike_FusionRider_P',1,true) and #e.Mesh.swaps==0 and #actors==0)
assert(Suit.off(nil,e)=='no suit')
print('fusion suit_test ok')
