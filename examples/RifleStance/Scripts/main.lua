-- Temporary in-memory action mask. Never saves input settings to disk.
local function maskAim(log)
 local settings=StaticFindObject('/Script/Engine.Default__InputSettings')
 assert(settings and settings:IsValid(),'Input settings unavailable')
 local rebuild=StaticFindObject('/Script/Engine.InputSettings:ForceRebuildKeymaps')
 assert(rebuild and rebuild:IsValid(),'Input rebuild unavailable')
 local mappings=settings.ActionMappings
 assert(mappings and #mappings<=1024,'Unexpected action mappings')
 local saved={}
 mappings:ForEach(function(index,wrapped)
  local row=wrapped:get()
  if row.ActionName:ToString()=='TPSMode' and row.Key.KeyName:ToString()~='None' then
   saved[#saved+1]={row=row,key=row.Key.KeyName:ToString()}
  end
 end)
 assert(#saved>0 and #saved<=16,'Unexpected TPS bindings')
 local function restore()
  local failures={}
  for _,entry in ipairs(saved) do
   if entry.changed then
    local ok,err=pcall(function()
     assert(entry.row.ActionName:ToString()=='TPSMode','Action mapping changed')
     entry.row.Key.KeyName=FName(entry.key)
     assert(entry.row.Key.KeyName:ToString()==entry.key,'Key restore unconfirmed')
     entry.changed=false
    end)
    if not ok then failures[#failures+1]=tostring(err) end
   end
  end
  settings:ForceRebuildKeymaps()
  assert(#failures==0,table.concat(failures,' | '))
  log('Native aim mappings restored')
 end
 local ok,err=pcall(function()
  for _,entry in ipairs(saved) do
   entry.changed=true
   entry.row.Key.KeyName=FName('None')
   assert(entry.row.Key.KeyName:ToString()=='None','Key mask unconfirmed')
  end
  settings:ForceRebuildKeymaps()
 end)
 if not ok then
  local restored,why=pcall(restore)
  error(tostring(err)..(restored and '' or ' RESTORE FAILED '..tostring(why)))
 end
 log('Native TPSMode temporarily masked mappings='..#saved)
 return restore
end
local folder=assert(debug.getinfo(1,'S').source:match('^@(.+[\\/])'))
local laser=assert(loadfile(folder..'laser.lua'))()
local grip={Translation={X=-2.110698699951172,Z=2.090805768966675,Y=-6.265880107879639},Rotation={X=-0.4851755201816559,W=-0.5130578875541687,Z=-0.4808891713619232,Y=-0.5197325944900513},Scale3D={X=1.000000238418579,Z=1.0000001192092896,Y=1}}
local function valid(o)return o and o:IsValid() end
local stop,frame
local function begin()
 local pc
 for _,c in ipairs(FindAllOf('SBNetworkPlayerController') or {}) do if valid(c) and c:IsLocalController() then pc=c;break end end
 assert(valid(pc) and valid(pc.Pawn),'Load a campaign save first')
 local pawn=pc.Pawn
 assert(pawn.TPSModeType==0 and not pawn.bTPSMode,'Release aim first')
 local src=pawn.Mesh
 local mathlib=StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
 local game=StaticFindObject('/Script/Engine.Default__GameplayStatics')
 local hand,tip=FName('Bip001-R-Hand'),FName('Bip001-Spine2')
 local parts={}
 local hide,tick=src.bOwnerNoSee,src.VisibilityBasedAnimTickOption
 local restoreInput
 local beam,finish
 stop=function()
  frame=nil
  if restoreInput then pcall(restoreInput);restoreInput=nil end
  if finish then pcall(finish) end
  if valid(src) then src:SetOwnerNoSee(hide);src.VisibilityBasedAnimTickOption=tick end
  for i=#parts,1,-1 do local c=parts[i];if valid(c) then c:K2_DestroyComponent(c) end end
  stop=nil
 end
 local function component(kind,asset)
  local id={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
  local c=pawn:AddComponentByClass(StaticFindObject('/Script/Engine.'..kind),true,id,true)
  assert(valid(c));parts[#parts+1]=c;c:SetVisibility(false,false);c:SetCollisionEnabled(0)
  pawn:FinishAddComponent(c,true,id);c:SetSkeletalMesh(asset,true);return c
 end
 assert(not pawn.bTPSMode,"Release campaign aim before enabling")
 restoreInput=maskAim(function() end)
 local body=component('PoseableMeshComponent',src.SkeletalMesh)
 body:K2_AttachToComponent(src,FName('None'),2,2,2,false)
 for slot=0,src:GetNumMaterials()-1 do
  local mat=src:GetMaterial(slot)
  if valid(mat) then body:SetMaterial(slot,mat) end
 end
 local channels=src.LightingChannels
 body:SetLightingChannels(channels.bChannel0,channels.bChannel1,channels.bChannel2)
 body:SetCastShadow(src.CastShadow)
 local weapon=assert(LoadAsset('/Game/DLC_2/Art/Character/Weapon/Gun/CH_G_Nikke_01/GunNikke_Weapon.GunNikke_Weapon'))
 local gun=component('PoseableMeshComponent',weapon)
 gun:K2_AttachToComponent(body,hand,2,2,2,false);gun:K2_SetRelativeTransform(grip,false,{},true)
 local donor=component('SkeletalMeshComponent',src.SkeletalMesh)
 donor.VisibilityBasedAnimTickOption=0
 donor:PlayAnimation(assert(LoadAsset('/Game/DLC_2/Art/Character/PC/CH_P_EVE_01/Animation/P_Eve_GunNikke_Hide.P_Eve_GunNikke_Hide')),false)
 donor:Stop();donor:SetPosition(0,false)
  local leftElbowAngle=12
  local function turnLeftElbow(shoulder,elbow,wrist,right)
   local a,b,c=shoulder.Translation,elbow.Translation,wrist.Translation
   local x,y,z=c.X-a.X,c.Y-a.Y,c.Z-a.Z
   local length=math.sqrt(x*x+y*y+z*z)
   if length<0.01 then return end
   x,y,z=x/length,y/length,z/length
   local u,v,w=b.X-a.X,b.Y-a.Y,b.Z-a.Z
   local tx,ty,tz=y*w-z*v,z*u-x*w,x*v-y*u
   -- Pick the direction that moves the elbow toward Eve's left.
   local sign=(tx*right.X+ty*right.Y+tz*right.Z)>0 and -1 or 1
   local angle=math.rad(leftElbowAngle*sign)
   local sine,cosine=math.sin(angle),math.cos(angle)
   local projection=(x*u+y*v+z*w)*(1-cosine)
   elbow.Translation={
    X=a.X+u*cosine+tx*sine+x*projection,
    Y=a.Y+v*cosine+ty*sine+y*projection,
    Z=a.Z+w*cosine+tz*sine+z*projection
   }
   local half=math.sin(angle/2)
   local rx,ry,rz,rw=x*half,y*half,z*half,math.cos(angle/2)
   for _,pose in ipairs({shoulder,elbow}) do
    local q=pose.Rotation
    pose.Rotation={
     X=rw*q.X+rx*q.W+ry*q.Z-rz*q.Y,
     Y=rw*q.Y-rx*q.Z+ry*q.W+rz*q.X,
     Z=rw*q.Z+rx*q.Y-ry*q.X+rz*q.W,
     W=rw*q.W-rx*q.X-ry*q.Y-rz*q.Z
    }
   end
  end
  local aimBones={}
  for _,side in ipairs({'L','R'})do
   local candidates={'Clavicle','UpperArm','Forearm','Hand'}
   for digit=0,4 do for _,suffix in ipairs({'','1','2'})do candidates[#candidates+1]='Finger'..digit..suffix end end
   for _,partName in ipairs(candidates) do
    local bone=FName('Bip001-'..side..'-'..partName)
    if src:GetBoneIndex(bone)>=0 then aimBones[#aimBones+1]=bone
    elseif partName=='Hand' or partName=='UpperArm' or partName=='Forearm' then error('Missing arm bone '..bone:ToString()) end
   end
  end

 local age,aimBlend=0,0
 local alt={KeyName=FName('LeftAlt')}
 local coverOffsets={}
 frame=function()
  if not valid(pc) or not valid(pawn) or not valid(src) or not valid(pc.Pawn) or pc.Pawn:GetAddress()~=pawn:GetAddress() then stop();return end
  if game:IsGamePaused(pc) then return end
  age=age+1;if age<3 then return end
  src.VisibilityBasedAnimTickOption=0
  body:CopyPoseFromSkeletalComponent(src)
  if #coverOffsets==0 then
   local ref=donor:GetSocketTransform(tip,0)
   for i,b in ipairs(aimBones) do coverOffsets[i]=mathlib:MakeRelativeTransform(donor:GetSocketTransform(b,0),ref) end
  end
  local held=pc:IsInputKeyDown(alt) or pc:IsInputKeyDown({KeyName=FName('LeftControl')}) or pc:IsInputKeyDown({KeyName=FName('Gamepad_LeftTrigger')})
  local cam=pc.PlayerCameraManager:GetCameraRotation()
  if held then local r=pawn:K2_GetActorRotation();pawn:K2_SetActorRotation({Pitch=r.Pitch,Yaw=cam.Yaw,Roll=r.Roll},false) end
  local pitch=(cam.Pitch+180)%360-180
  aimBlend=math.max(0,math.min(1,aimBlend+(held and 0.08 or -0.06)))
  local right=pawn:GetActorRightVector()
  local freeAimMovement=true
    local chest=body:GetBoneTransformByName(tip,0)
    local coverPoses
    if coverOffsets and (aimBlend<1 or freeAimMovement) then
     if freeAimMovement then
      local socket=FName('FX_Fire')
      assert(gun:DoesSocketExist(socket),'Visual muzzle unavailable')
      local muzzleLocal=mathlib:MakeRelativeTransform(gun:GetSocketTransform(socket,0),gun:K2_GetComponentToWorld())
      local handPose
      for i,bone in ipairs(aimBones) do
       if bone:ToString()==hand:ToString() then handPose=mathlib:ComposeTransforms(coverOffsets[i],chest);break end
      end
      assert(handPose,'Right hand pose unavailable')
      local weapon=mathlib:ComposeTransforms(grip,handPose)
      local muzzle=mathlib:ComposeTransforms(muzzleLocal,weapon)
      local q=muzzle.Rotation
      local x=1-2*(q.Y*q.Y+q.Z*q.Z)
      local y=2*(q.X*q.Y+q.W*q.Z)
      local z=2*(q.X*q.Z-q.W*q.Y)
      local yaw=math.atan(y,x)
      local pitch=math.deg(math.atan(z,math.sqrt(x*x+y*y)))
      -- Keep the grip aligned while lowering the barrel.
      local correction=math.max(0,math.min(8,pitch))
      local anchor=chest.Translation
      local position={X=anchor.X,Y=anchor.Y,Z=anchor.Z}
      if correction>0 then
       local half=math.rad(correction)*0.5
       local sine=math.sin(half)
       local pitchTurn={Rotation={X=-math.sin(yaw)*sine,Y=math.cos(yaw)*sine,Z=0,W=math.cos(half)},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
       chest=mathlib:ComposeTransforms(chest,pitchTurn)
      end
      local leftHalf=math.rad(-12)*0.5
      local leftTurn={Rotation={X=0,Y=0,Z=math.sin(leftHalf),W=math.cos(leftHalf)},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
      chest=mathlib:ComposeTransforms(chest,leftTurn)
      chest.Translation=position
     end
     local poses={}
     local shoulder,elbow,wrist
     for i,bone in ipairs(aimBones) do
      local pose=mathlib:ComposeTransforms(coverOffsets[i],chest)
      poses[i]=pose
      local name=bone:ToString()
      if name=='Bip001-L-UpperArm' then shoulder=pose
      elseif name=='Bip001-L-Forearm' then elbow=pose
      elseif name=='Bip001-L-Hand' then wrist=pose end
     end
     if leftElbowAngle~=0 and shoulder and elbow and wrist then
      turnLeftElbow(shoulder,elbow,wrist,right)
     end
     coverPoses=poses
    end
    if freeAimMovement and coverPoses and aimBlend>0 then
     local rightHand
     for i,bone in ipairs(aimBones) do
      if bone:ToString()==hand:ToString() then rightHand=coverPoses[i];break end
     end
     local muzzleSocket=FName('FX_Fire')
     local muzzleLocal=mathlib:MakeRelativeTransform(gun:GetSocketTransform(muzzleSocket,0),gun:K2_GetComponentToWorld())
     local weapon=mathlib:ComposeTransforms(grip,rightHand)
     local muzzle=mathlib:ComposeTransforms(muzzleLocal,weapon)
     local q=muzzle.Rotation
     local x,y,z=1-2*(q.Y*q.Y+q.Z*q.Z),2*(q.X*q.Y+q.W*q.Z),2*(q.X*q.Z-q.W*q.Y)
     local cameraYaw=pc.PlayerCameraManager:GetCameraRotation().Yaw
     local yawDelta=(cameraYaw-math.deg(math.atan(y,x))+180)%360-180
     local targetYaw=math.rad(cameraYaw)
     local yawHalf=math.rad(yawDelta)*0.5
     local pitchHalf=(math.atan(z,math.sqrt(x*x+y*y))-math.rad(pitch))*0.5
     local yawTurn={Rotation={X=0,Y=0,Z=math.sin(yawHalf),W=math.cos(yawHalf)},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
     local pitchTurn={Rotation={X=-math.sin(targetYaw)*math.sin(pitchHalf),Y=math.cos(targetYaw)*math.sin(pitchHalf),Z=0,W=math.cos(pitchHalf)},Translation=yawTurn.Translation,Scale3D=yawTurn.Scale3D}
     local pivot={Rotation=yawTurn.Rotation,Translation=chest.Translation,Scale3D=yawTurn.Scale3D}
     pivot.Rotation={X=0,Y=0,Z=0,W=1}
     local target=mathlib:ComposeTransforms(yawTurn,pitchTurn)
     target.Translation=chest.Translation
     target=mathlib:TLerp(pivot,target,aimBlend,0)
     for i,bone in ipairs(aimBones) do
      local relative=mathlib:MakeRelativeTransform(coverPoses[i],pivot)
      body:SetBoneTransformByName(bone,mathlib:ComposeTransforms(relative,target),0)
     end

    elseif coverPoses then
     for i,b in ipairs(aimBones) do body:SetBoneTransformByName(b,coverPoses[i],0) end
    end
    gun:K2_SetRelativeTransform(grip,false,{},true)
    if held and aimBlend>=1 then
     local axis=mathlib:GetForwardVector(gun:GetSocketRotation(FName('FX_Fire')))
     local goal=mathlib:GetForwardVector(cam)
     local dot=axis.X*goal.X+axis.Y*goal.Y+axis.Z*goal.Z
     if dot<0.9999 then
      local x,y,z=axis.Y*goal.Z-axis.Z*goal.Y,axis.Z*goal.X-axis.X*goal.Z,axis.X*goal.Y-axis.Y*goal.X
      local w=1+dot
      if w<0.000001 then x,y,z=-axis.Y,axis.X,0;if x*x+y*y<0.000001 then x,y,z=1,0,0 end;w=0 end
      local length=math.sqrt(x*x+y*y+z*z+w*w)
      local origin=body:GetBoneTransformByName(tip,0).Translation
      local pivot={Rotation={X=0,Y=0,Z=0,W=1},Translation=origin,Scale3D={X=1,Y=1,Z=1}}
      local turn={Rotation={X=x/length,Y=y/length,Z=z/length,W=w/length},Translation=origin,Scale3D=pivot.Scale3D}
      local corrected={}
      for i,b in ipairs(aimBones) do
       corrected[i]=mathlib:ComposeTransforms(mathlib:MakeRelativeTransform(body:GetBoneTransformByName(b,0),pivot),turn)
      end
      for i,b in ipairs(aimBones) do body:SetBoneTransformByName(b,corrected[i],0) end
      gun:K2_SetRelativeTransform(grip,false,{},true)
     end
    end
    src:SetOwnerNoSee(true);body:SetVisibility(true,false);gun:SetVisibility(true,false)
    if held then
     if not beam then beam,finish=laser(pawn,gun,mathlib) end
     beam()
    elseif finish then finish();beam,finish=nil,nil end
 end
end
local function failed(err)
 if stop then pcall(stop) end
 frame,stop=nil,nil
 print('[RifleStance] '..tostring(err))
end
RegisterKeyBind(Key.F7,function() ExecuteInGameThread(function()
 local ok,err=pcall(function() if stop then stop() else begin() end end)
 if not ok then failed(err) end
end) end)
local pending=false
LoopAsync(16,function()
 if frame and not pending then
  pending=true
  ExecuteInGameThread(function()
   if frame then local ok,err=pcall(frame);if not ok then failed(err) end end
   pending=false
  end)
 end
 return false
end)
