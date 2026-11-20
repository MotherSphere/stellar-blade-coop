-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- luke77's laser sight (feature/rifle-stance, examples/RifleStance/Scripts/laser.lua): the NIKKE minigame's guide
-- laser on the rifle's muzzle, its end through the minigame's parameter collection. Two changes, marked "gun mode:":
-- update takes the point the rounds go to (without it the end is his trace along the barrel); the beam is spawned at
-- the muzzle with no parent and moved there at each update.
-- laser(pawn, gun, mathlib) -> update(target), cleanup.
return function(pawn,gun,mathlib)
 local socket=FName('FX_Fire')
 assert(gun:DoesSocketExist(socket),'Visual rifle muzzle socket missing')
 local library=StaticFindObject('/Script/Niagara.Default__NiagaraFunctionLibrary')
 local base='/Game/DLC_2/Art/FX/MiniGame/'
 local function resource(name)
  local path=base..name..'.'..name
  local object=StaticFindObject(path)
  if not object or not object:IsValid() then object=LoadAsset(path) end
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
 local trace=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
 assert(trace and trace:IsValid(),'Collision library unavailable')
 local beam
 local function cleanup()
  pcall(function()
   if beam and beam:IsValid() then beam:SetVisibility(false,false);beam:Deactivate() end
  end)
  pcall(function()
   if instance:IsValid() then instance:SetVectorParameter('LaserPosition',saved) end
  end)
 end
 local pawnClass=StaticFindObject('/Script/Engine.Pawn')
 local function update(target)
  -- gun mode: the beam at the muzzle, as an attached one would be (SnapToTarget).
  if beam and beam:IsValid() then
   beam:K2_SetWorldLocationAndRotation(gun:GetSocketLocation(socket),gun:GetSocketRotation(socket),false,{},true)
  end
  -- gun mode: the end on where the rounds go (the crosshair's point), when fight/gunmode/mode.lua has it.
  if target then instance:SetVectorParameter('LaserPosition',target);return end

  local origin=gun:GetSocketLocation(socket)
  local axis=mathlib:GetForwardVector(gun:GetSocketRotation(socket))
  local destination={X=origin.X+axis.X*8000,Y=origin.Y+axis.Y*8000,Z=origin.Z+axis.Z*8000}
  local nearest=destination
  local distance=8000
  local transparent={R=0,G=0,B=0,A=0}
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
   local blocked=trace:LineTraceSingle(pawn,origin,destination,channel,false,{pawn},0,hit,true,transparent,transparent,0)
   consider(blocked,hit)
  end
  local hit={}
  if trace:LineTraceSingle(pawn,origin,destination,4,true,{pawn},0,hit,true,transparent,transparent,0) then
   local ok,actor=pcall(function() return hit.Actor:Get() end)
   if ok and actor and actor:IsValid() and actor:IsA(pawnClass) and actor:GetAddress()~=pawn:GetAddress() then
    consider(true,hit)
   end
  end
  destination=nearest
  instance:SetVectorParameter('LaserPosition',destination)
 end
 local ok,err=pcall(function()
  -- gun mode: attached to nothing. Attached to the rifle (a part of EVE online/partner/capture.lua sends) a partner's
  -- game drew a copy of it on her ghost, its end at that game's own LaserPosition: one value per world (the
  -- collection's instance comes from the world's FNiagaraWorldManager, GetNiagaraParameterCollection's exec 0x14115be00
  -- on 26123051), so never where she aims (M11). UNiagaraFunctionLibrary::SpawnSystemAtLocation (params 0x146d57f00:
  -- WorldContextObject, SystemTemplate, Location, Rotation, Scale, bAutoDestroy, bAutoActivate, PoolingMethod,
  -- bPreCullCheck; its exec 0x14115e280 registers the component with absolute location, rotation and scale and attaches
  -- it to nothing). The other values as the attached spawn had them.
  beam=library:SpawnSystemAtLocation(pawn,asset,gun:GetSocketLocation(socket),gun:GetSocketRotation(socket),
   {X=1,Y=1,Z=1},true,false,0,false)
  assert(beam and beam:IsValid(),'Laser spawn failed')
  update()
  beam:Activate(false)
 end)
 if not ok then cleanup();error(err) end
 return update,cleanup
end
