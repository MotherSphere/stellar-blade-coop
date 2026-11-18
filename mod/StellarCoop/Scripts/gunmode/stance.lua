-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- luke77's RifleStance (feature/rifle-stance, examples/RifleStance/Scripts/main.lua), kept as he wrote it: EVE keeps
-- her own animation (her own legs, hips and movement), a poseable copy of her mesh takes the arms of the NIKKE hide
-- pose so the rifle (a poseable GunNikke_Weapon at the grip) rides at her chest, and while aim is held she turns to
-- the camera and the rifle comes up to it. Only these changed, each marked "gun mode:": begin takes the controller,
-- the held test and the laser's end from gunmode/mode.lua; the input mask is mode.lua's. His F7 key bind and LoopAsync are gone: mode.lua calls start, frame and stop from its game-thread
-- loop (two threads in one Lua state crashed UE4SS).
local Stance={}
local function valid(o)return o and o:IsValid() end

-- laser: gunmode/laser.lua's function. Returns {start(pc,held_fn,beam_target) -> the rifle component, frame(),
-- stop(), running()}.
function Stance.new(laser)
 local grip={Translation={X=-2.110698699951172,Z=2.090805768966675,Y=-6.265880107879639},Rotation={X=-0.4851755201816559,W=-0.5130578875541687,Z=-0.4808891713619232,Y=-0.5197325944900513},Scale3D={X=1.000000238418579,Z=1.0000001192092896,Y=1}}
 local stop,frame,reloadFn
 local owned={} -- gun mode: the parts of the stance running now.
 local function begin(pc,held_fn,beam_target,turn,torso,camAnchor,chestFix,aimNative,upright) -- gun mode: turn false leaves EVE's facing to
  -- the game; torso (0 to 1): how much her spine takes the donor pose while aim is held; camAnchor: the arms along
  -- the camera while aim is held; chestFix: the arms' chest frame from her facing while aim is held; aimNative:
  -- the game's own animation while aim is held (her real body, the rifle on its hand); upright: her normal stance's
  -- spine while aim is held
  torso=torso or 0
  assert(valid(pc) and valid(pc.Pawn),'Load a campaign save first')
  local pawn=pc.Pawn
  assert(pawn.TPSModeType==0 and not pawn.bTPSMode,'Release aim first')
  local src=pawn.Mesh
  local mathlib=StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
  local game=StaticFindObject('/Script/Engine.Default__GameplayStatics')
  local hand,tip=FName('Bip001-R-Hand'),FName('Bip001-Spine2')
  local parts={}
  owned=parts -- gun mode
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
   reloadFn=nil
  end
  local function component(kind,asset)
   local id={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
   local c=pawn:AddComponentByClass(StaticFindObject('/Script/Engine.'..kind),true,id,true)
   assert(valid(c));parts[#parts+1]=c;c:SetVisibility(false,false);c:SetCollisionEnabled(0)
   pawn:FinishAddComponent(c,true,id);c:SetSkeletalMesh(asset,true)
   pcall(function() c.bPerBoneMotionBlur=false end) -- gun mode: per-bone motion blur smeared the posed copy (02:06)
   return c
  end
  assert(not pawn.bTPSMode,"Release campaign aim before enabling")
  -- gun mode: the input mask is gunmode/mode.lua's (TPSMode and the fire and zoom keys).
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
  local hideAnim=assert(LoadAsset('/Game/DLC_2/Art/Character/PC/CH_P_EVE_01/Animation/P_Eve_GunNikke_Hide.P_Eve_GunNikke_Hide'))
  donor:PlayAnimation(hideAnim,false)
  donor:Stop();donor:SetPosition(0,false)
  -- gun mode: the reload. The donor plays the NIKKE squad's reload (P_Eve_GunNikke_Reload) at the rate that fits
  -- the reload time, and her arms (and the rifle in her right hand) follow the donor's arms from its chest each frame
  -- instead of the held hide pose; the rifle comes down from the aim while it plays. Then the hide pose again.
  local reloading,reloadAt,reloadLen=false,0,1
  reloadFn=function(on,duration)
   if on then
    local anim=LoadAsset('/Game/DLC_2/Art/Character/PC/CH_P_EVE_01/Animation/P_Eve_GunNikke_Reload.P_Eve_GunNikke_Reload')
    if not anim then return false end
    donor:PlayAnimation(anim,false)
    local len=0
    pcall(function() len=anim:GetPlayLength() end)
    if len>0 and duration and duration>0 then pcall(function() donor:SetPlayRate(len/duration) end) end
    reloading,reloadAt,reloadLen=true,os.clock(),(duration and duration>0) and duration or 1
   elseif reloading then
    reloading=false
    pcall(function() donor:SetPlayRate(1) end)
    donor:PlayAnimation(hideAnim,false);donor:Stop();donor:SetPosition(0,false)
   end
   return true
  end
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
  -- gun mode: the torso bones set in the game's aim, and their offsets from the pelvis in the donor pose.
  local pelvis=FName('Bip001-Pelvis')
  local torsoBones,torsoOffsets={},{}
  local camOffsets={} -- gun mode: the donor's arm bones from its yaw-only Spine2 frame (camAnchor)
  local chestRel -- gun mode: the donor's Spine2 from its facing frame (chestFix)
  local onReal=false -- gun mode: the rifle on her real body (aimNative, aim held)
  -- gun mode (upright): her spine bones, their frames from her facing in her normal stance, and her neck and head.
  local spineBones,spineRel,headBones={},{},{}
  local thighL,thighR,hipRel,hipTurn,hipFollow=FName('Bip001-L-Thigh'),FName('Bip001-R-Thigh'),nil,0,0.65
  for _,n in ipairs({'Spine','Spine1','Spine2'}) do
   local b=FName('Bip001-'..n); if src:GetBoneIndex(b)>=0 then spineBones[#spineBones+1]=b end
  end
  for _,n in ipairs({'Neck','Head'}) do
   local b=FName('Bip001-'..n); if src:GetBoneIndex(b)>=0 then headBones[#headBones+1]=b end
  end
  for _,n in ipairs({'Spine','Spine1','Spine2','Neck','Head'}) do
   local b=FName('Bip001-'..n)
   if src:GetBoneIndex(b)>=0 then torsoBones[#torsoBones+1]=b end
  end
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
   local held=held_fn() -- gun mode: RMB / LT (and Luke's Alt, Ctrl), from gunmode/mode.lua.
   if reloading then held=false end -- gun mode: the rifle comes down to reload (her arms then follow the donor's).
   -- gun mode (aimNative): while aim is held the game's own animation shows (the aim stance's upper body made the
   -- NIKKE rifle's by gunmode/data.lua): her real body visible, the rifle on its right hand, nothing posed; the
   -- posed copy comes back when aim is let go.
   if aimNative then
    if held and not onReal then
     onReal=true
     gun:K2_AttachToComponent(src,hand,2,2,2,false);gun:K2_SetRelativeTransform(grip,false,{},true)
     body:SetVisibility(false,false);src:SetOwnerNoSee(hide);gun:SetVisibility(true,false)
    elseif not held and onReal then
     onReal=false
     gun:K2_AttachToComponent(body,hand,2,2,2,false);gun:K2_SetRelativeTransform(grip,false,{},true)
     aimBlend=0
    end
    if onReal then
     if not beam then beam,finish=laser(pawn,gun,mathlib) end
     beam(beam_target())
     return
    end
   end
   local cam=pc.PlayerCameraManager:GetCameraRotation()
   local turnNow=turn; if type(turn)=='function' then turnNow=turn() end -- gun mode: turn may be a test
   if held and turnNow then local r=pawn:K2_GetActorRotation();pawn:K2_SetActorRotation({Pitch=r.Pitch,Yaw=cam.Yaw,Roll=r.Roll},false) end
   local pitch=(cam.Pitch+180)%360-180
   aimBlend=math.max(0,math.min(1,aimBlend+(held and 0.08 or -0.2))) -- gun mode: let go fast (arms wrapped round her back as
   -- the aim eased out while the camera turned, 08:39)
   local right=pawn:GetActorRightVector()
   local freeAimMovement=true
   -- gun mode: in the game's aim its own pose turns her chest and shoulders to steer the drone, and Luke's arms,
   -- placed from her chest, came out twisted (00:56). While aim is held her spine, neck and head take the donor
   -- pose's (the NIKKE hide pose, as her arms do) from her pelvis up, eased in with the aim and scaled by torso.
   if torso>0 and aimBlend>0 then
    if #torsoOffsets==0 then
     local base=donor:GetSocketTransform(pelvis,0)
     for i,b in ipairs(torsoBones) do torsoOffsets[i]=mathlib:MakeRelativeTransform(donor:GetSocketTransform(b,0),base) end
    end
    local hips=body:GetBoneTransformByName(pelvis,0)
    local goal={}
    for i,b in ipairs(torsoBones) do goal[i]=mathlib:ComposeTransforms(torsoOffsets[i],hips) end
    for i,b in ipairs(torsoBones) do
     body:SetBoneTransformByName(b,mathlib:TLerp(body:GetBoneTransformByName(b,0),goal[i],aimBlend*torso,0),0)
    end
   end
     -- gun mode (upright, the game's aim): her spine from her normal stance. While aim is not held (her normal
     -- movement, before any of Luke's posing) her Spine, Spine1 and Spine2 are recorded from a frame at her pelvis
     -- turned to her facing (her actor's yaw), and while it is held they are put back from that frame there: the
     -- game's aim pose twists her spine to steer the drone (Luke's arms then came out twisted, 00:56, 02:26). Her neck
     -- and head stay where her real body's are (her face and hair follow her real body). Luke's aim then runs on that.
     -- The frame is her actor's location and yaw, not her pelvis: the copied pose is one frame old on some frames and
     -- new on others (the game finishes her animation on its own schedule), so anything anchored to it flipped
     -- between two poses (02:53); her actor's transform is steady, and in the game's aim her yaw follows the camera.
     if upright then
      local yaw=pawn:K2_GetActorRotation().Yaw
      -- gun mode: her hips' facing (the line between her thighs) from her actor's yaw, against what it was when her
      -- spine was recorded. The game's aim turns her hips sideways to its strafing; a chest held to her actor's yaw
      -- alone twisted her waist (08:39), so the chest follows her hips by hipFollow of that turn, eased.
      local hipOff
      pcall(function()
       local l=body:GetBoneTransformByName(thighL,0).Translation
       local r=body:GetBoneTransformByName(thighR,0).Translation
       hipOff=math.deg(math.atan(-(r.X-l.X),r.Y-l.Y))-yaw
      end)
      local speed=0
      pcall(function() local v=pawn:GetVelocity(); speed=math.sqrt(v.X*v.X+v.Y*v.Y) end)
      local recording=not held and aimBlend==0 and (#spineRel==0 or speed<20)
      if recording and hipOff then hipRel=hipOff end
      if hipOff and hipRel then
       local d=(hipOff-hipRel+180)%360-180
       hipTurn=hipTurn+(d-hipTurn)*0.15
      end
      local frame=mathlib:MakeTransform(pawn:K2_GetActorLocation(),{Pitch=0,Yaw=yaw+hipTurn*hipFollow*aimBlend,Roll=0},{X=1,Y=1,Z=1})
      if recording then
       local rec=mathlib:MakeTransform(pawn:K2_GetActorLocation(),{Pitch=0,Yaw=yaw,Roll=0},{X=1,Y=1,Z=1})
       for i,b in ipairs(spineBones) do spineRel[i]=mathlib:MakeRelativeTransform(body:GetBoneTransformByName(b,0),rec) end
      end
      if aimBlend>0 and #spineRel>0 then
       local keep={}
       for i,b in ipairs(headBones) do keep[i]=src:GetSocketTransform(b,0) end
       -- Her neck from her Spine2 as the copied pose has it, so the upright chest can be moved to meet her real
       -- neck: a neck pinned to her real one alone stretched while the two differed (03:38, as the aim came up).
       local top=spineBones[#spineBones]
       local neckRel=#headBones>0 and top and mathlib:MakeRelativeTransform(body:GetBoneTransformByName(headBones[1],0),
        body:GetBoneTransformByName(top,0))
       local goals={}
       for i,b in ipairs(spineBones) do
        local goal=mathlib:ComposeTransforms(spineRel[i],frame)
        if aimBlend<1 then goal=mathlib:TLerp(body:GetBoneTransformByName(b,0),goal,aimBlend,0) end
        goals[i]=goal
       end
       if neckRel and #goals>0 then
        local want=keep[1].Translation
        local got=mathlib:ComposeTransforms(neckRel,goals[#goals]).Translation
        local dx,dy,dz=want.X-got.X,want.Y-got.Y,want.Z-got.Z
        for i=1,#goals do
         local w=i/#goals
         local t=goals[i].Translation
         goals[i].Translation={X=t.X+dx*w,Y=t.Y+dy*w,Z=t.Z+dz*w}
        end
       end
       for i,b in ipairs(spineBones) do body:SetBoneTransformByName(b,goals[i],0) end
       for i,b in ipairs(headBones) do body:SetBoneTransformByName(b,keep[i],0) end
      end
     end
     local chest=body:GetBoneTransformByName(tip,0)
     -- gun mode (chestFix, the game's aim): her chest frame for the arms is the donor's chest orientation in its own
     -- facing frame, put in hers (her actor's yaw, which the game's aim keeps on the camera's), at her Spine2. Not
     -- her Spine2's own rotation (the game's aim pose turns it to steer the drone: twisted arms, 00:56), nor her
     -- pelvis's (it sways with each strafing step: the rifle shook, 02:20).
     if chestFix and aimBlend>0 then
      if not chestRel then
       local yawFix=pawn:K2_GetActorRotation().Yaw-src:K2_GetComponentRotation().Yaw
       local face=mathlib:MakeTransform(donor:GetSocketLocation(tip),
        {Pitch=0,Yaw=donor:K2_GetComponentRotation().Yaw+yawFix,Roll=0},{X=1,Y=1,Z=1})
       chestRel=mathlib:MakeRelativeTransform(donor:GetSocketTransform(tip,0),face)
      end
      local herFace=mathlib:MakeTransform(chest.Translation,{Pitch=0,Yaw=pawn:K2_GetActorRotation().Yaw,Roll=0},
       {X=1,Y=1,Z=1})
      local fixed=mathlib:ComposeTransforms(chestRel,herFace)
      fixed.Translation=chest.Translation
      chest=mathlib:TLerp(chest,fixed,aimBlend,0)
     end
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
     if camAnchor and coverPoses and aimBlend>0 then
      -- gun mode (camAnchor, the game's aim): the arms placed along the camera, not from her chest, whose own pose
      -- there turns to steer the drone (twisted arms, 00:56). The donor's arm bones are taken once from a frame at its
      -- Spine2 turned to its facing (yaw only); each frame that frame stands at her Spine2, turned to the control
      -- rotation (pitch clamped), eased in from Luke's carry pose with the aim.
      if #camOffsets==0 then
       local yawFix=pawn:K2_GetActorRotation().Yaw-src:K2_GetComponentRotation().Yaw
       local dAnchor=mathlib:MakeTransform(donor:GetSocketLocation(tip),
        {Pitch=0,Yaw=donor:K2_GetComponentRotation().Yaw+yawFix,Roll=0},{X=1,Y=1,Z=1})
       for i,b in ipairs(aimBones) do camOffsets[i]=mathlib:MakeRelativeTransform(donor:GetSocketTransform(b,0),dAnchor) end
      end
      local cr=pc:GetControlRotation()
      local p=math.max(-60,math.min(60,(cr.Pitch+180)%360-180))
      local anchor=mathlib:MakeTransform(body:GetBoneTransformByName(tip,0).Translation,{Pitch=p,Yaw=cr.Yaw,Roll=0},
       {X=1,Y=1,Z=1})
      for i,b in ipairs(aimBones) do
       local goal=mathlib:ComposeTransforms(camOffsets[i],anchor)
       body:SetBoneTransformByName(b,mathlib:TLerp(coverPoses[i],goal,aimBlend,0),0)
      end
     elseif freeAimMovement and coverPoses and aimBlend>0 then
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
      -- gun mode: the turn toward the camera is held to 70 degrees either way, and dropped at once when the aim is let go
      -- with the camera further round than that (her arms went behind her back, 08:39).
      if not held and math.abs(yawDelta)>70 then aimBlend=0 end
      yawDelta=math.max(-70,math.min(70,yawDelta))
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
     -- gun mode: the reload. Her arms take the donor's, from a frame at its chest turned only to its facing (its
     -- spine turns in the NIKKE squad's reload, and arms taken from the chest itself held the rifle out to her
     -- right), put at her chest turned to her facing; eased in and out over the first and last 15 % of the reload.
     if reloading then
      local t=(os.clock()-reloadAt)/reloadLen
      local w=math.max(0,math.min(1,t/0.15,(1-t)/0.15))
      if w>0 then
       local dRef=mathlib:MakeTransform(donor:GetSocketLocation(tip),{Pitch=0,Yaw=donor:K2_GetComponentRotation().Yaw,Roll=0},{X=1,Y=1,Z=1})
       local bRef=mathlib:MakeTransform(body:GetBoneTransformByName(tip,0).Translation,{Pitch=0,Yaw=src:K2_GetComponentRotation().Yaw,Roll=0},{X=1,Y=1,Z=1})
       for _,b in ipairs(aimBones) do
        local goal=mathlib:ComposeTransforms(mathlib:MakeRelativeTransform(donor:GetSocketTransform(b,0),dRef),bRef)
        if w<1 then goal=mathlib:TLerp(body:GetBoneTransformByName(b,0),goal,w,0) end
        body:SetBoneTransformByName(b,goal,0)
       end
       gun:K2_SetRelativeTransform(grip,false,{},true)
      end
     end
     src:SetOwnerNoSee(true);body:SetVisibility(true,false);gun:SetVisibility(true,false)
     if held then
      if not beam then beam,finish=laser(pawn,gun,mathlib) end
      beam(beam_target()) -- gun mode: its end on where the rounds go.
     elseif finish then finish();beam,finish=nil,nil end
  end
  return gun
 end
 local self={}
 function self.start(pc,held_fn,beam_target,turn,torso,camAnchor,chestFix,aimNative,upright)
  return begin(pc,held_fn,beam_target,type(turn)=='function' and turn or turn~=false,torso,camAnchor,chestFix,aimNative,upright)
 end
 -- gun mode: the posed copy of her body (her hair and face can follow it), or nil.
 function self.body() return owned[1] end
 function self.frame() if frame then frame() end end
 -- gun mode: the reload animation on (for duration s) or off; false if it could not start.
 function self.reload(on,duration) if reloadFn and frame then return reloadFn(on,duration) end return false end
 function self.stop() if stop then stop() end end
 function self.running() return frame~=nil end
 -- gun mode: whether component c is one of the stance's own (its poseable body and rifle, the donor).
 function self.owns(c)
  for _,part in ipairs(owned) do if part==c then return true end end
  return false
 end
 return self
end

return Stance
