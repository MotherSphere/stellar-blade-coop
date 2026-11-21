-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- luke77's laser sight (feature/rifle-stance, examples/RifleStance/Scripts/laser.lua): the NIKKE minigame's guide
-- laser on the rifle's muzzle, its end through the minigame's parameter collection. Changes marked "gun mode:":
-- update takes the point the rounds go to (sent only when it moved; without it the end is his trace along the
-- barrel); the beam hangs from a plain scene component on the muzzle socket, not from the rifle itself. The trace's
-- colour and ignore list are made once.
-- laser(pawn, gun, mathlib) -> update(target), cleanup.
-- gun mode: the laser starts at each aim and at each reload's end. Its five objects were looked up at each start (five
-- walks of the object array, about 100-150 ms: a hitch on every press). They are kept here for the game run, each
-- checked against its path at the next start (an asset can be collected and its address reused).
local kept,socket,tag={},nil,nil
local function find(path,load)
 local o=kept[path]
 if o and o:IsValid() then
  local ok,full=pcall(function() return o:GetFullName() end)
  if ok and type(full)=='string' and full:match('^%S+ (.+)$')==path then return o end
 end
 o=StaticFindObject(path)
 if load and (not o or not o:IsValid()) then o=LoadAsset(path) end
 kept[path]=o
 return o
end
return function(pawn,gun,mathlib)
 socket=socket or FName('FX_Fire')
 assert(gun:DoesSocketExist(socket),'Visual rifle muzzle socket missing')
 local library=find('/Script/Niagara.Default__NiagaraFunctionLibrary')
 local base='/Game/DLC_2/Art/FX/MiniGame/'
 local function resource(name)
  local path=base..name..'.'..name
  local object=find(path,true)
  assert(object and object:IsValid(),'Laser resource unavailable: '..path)
  return object
 end
 local asset=resource('NS_A_GuideLaser')
 local collection=resource('NC_NikkeMinigame')
 assert(library and library:IsValid() and asset and asset:IsValid() and collection and collection:IsValid(),'Native laser resources unavailable')
 local instance=library:GetNiagaraParameterCollection(pawn,collection)
 assert(instance and instance:IsValid(),'Laser collection unavailable')
 local value=instance:GetVectorParameter('LaserPosition')
 local saved={X=value.X,Y=value.Y,Z=value.Z}
 local trace=find('/Script/Engine.Default__KismetSystemLibrary')
 assert(trace and trace:IsValid(),'Collision library unavailable')
 local beam,holder
 local function cleanup()
  pcall(function()
   if beam and beam:IsValid() then beam:SetVisibility(false,false);beam:Deactivate() end
  end)
  pcall(function() if holder and holder:IsValid() then holder:K2_DestroyComponent(holder) end end)
  pcall(function()
   if instance:IsValid() then instance:SetVectorParameter('LaserPosition',saved) end
  end)
 end
 local pawnClass=find('/Script/Engine.Pawn')
 local transparent,ignore={R=0,G=0,B=0,A=0},{pawn} -- gun mode: made once (less garbage a frame)
 local lx,ly,lz -- gun mode: the last target sent (the same point is not sent again)
 local function update(target)
  -- gun mode: the end on where the rounds go (the crosshair's point), when fight/gunmode/mode.lua has it.
  if target then
   if target.X~=lx or target.Y~=ly or target.Z~=lz then
    instance:SetVectorParameter('LaserPosition',target); lx,ly,lz=target.X,target.Y,target.Z
   end
   return
  end
  lx=nil

  local origin=gun:GetSocketLocation(socket)
  local axis=mathlib:GetForwardVector(gun:GetSocketRotation(socket))
  local destination={X=origin.X+axis.X*8000,Y=origin.Y+axis.Y*8000,Z=origin.Z+axis.Z*8000}
  local nearest=destination
  local distance=8000
  local function consider(blocked,hit)
   if blocked and hit.ImpactPoint then
    local point=hit.ImpactPoint
    local along=(point.X-origin.X)*axis.X+(point.Y-origin.Y)*axis.Y+(point.Z-origin.Z)*axis.Z
    if along>=0 and along<distance then
     distance=along
     nearest={X=point.X,Y=point.Y,Z=point.Z}
    end
   end
  end
  for channel=0,1 do
   local hit={}
   local blocked=trace:LineTraceSingle(pawn,origin,destination,channel,false,ignore,0,hit,true,transparent,transparent,0)
   consider(blocked,hit)
  end
  local hit={}
  if trace:LineTraceSingle(pawn,origin,destination,4,true,ignore,0,hit,true,transparent,transparent,0) then
   local ok,actor=pcall(function() return hit.Actor:Get() end)
   if ok and actor and actor:IsValid() and actor:IsA(pawnClass) and actor:GetAddress()~=pawn:GetAddress() then
    consider(true,hit)
   end
  end
  destination=nearest
  instance:SetVectorParameter('LaserPosition',destination)
 end
 local ok,err=pcall(function()
  -- gun mode: attached to the muzzle through a plain scene component. Attached to the rifle itself (a part of EVE
  -- online/partner/capture.lua sends) a partner's game drew a copy of it on her ghost, its end at that game's own
  -- LaserPosition: one value per world (the collection's instance comes from the world's FNiagaraWorldManager,
  -- GetNiagaraParameterCollection's exec 0x14115be00 on 26123051), so never where she aims (M11). The capture and the
  -- native part's effect read (native/src/game/partner/engine.h read_effects) take only the Niagara components hung
  -- right on a part: one a step below is never sent. Spawned at the muzzle with no parent (11-20), it lagged the
  -- rifle by a frame: it was moved from here before her hand's animation ran. The engine now carries it with the
  -- socket. UNiagaraFunctionLibrary::SpawnSystemAttached (params 0x1459beff0 on 26123051: SystemTemplate,
  -- AttachToComponent, AttachPointName, Location, Rotation, LocationType, bAutoDestroy, bAutoActivate,
  -- PoolingMethod, bPreCullCheck), LocationType 2 SnapToTarget (EAttachLocation, enum params 0x146d4a8a0). The holder
  -- is added and attached as fight/gunmode/rifle.lua adds the rifle. Both carry the rifle's tag, so Rifle.sweep takes
  -- them after a Lua reload.
  local id={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
  tag=tag or FName('SBO_Gun')
  holder=pawn:AddComponentByClass(find('/Script/Engine.SceneComponent'),true,id,true)
  assert(holder and holder:IsValid(),'Laser holder failed')
  pawn:FinishAddComponent(holder,true,id)
  pcall(function() holder.ComponentTags[1]=tag end)
  holder:K2_AttachToComponent(gun,socket,2,2,2,false)
  beam=library:SpawnSystemAttached(asset,holder,FName('None'),{X=0,Y=0,Z=0},{Pitch=0,Yaw=0,Roll=0},2,true,false,0,false)
  assert(beam and beam:IsValid(),'Laser spawn failed')
  pcall(function() beam.ComponentTags[1]=tag end)
  update()
  beam:Activate(false)
 end)
 if not ok then cleanup();error(err) end
 return update,cleanup
end
