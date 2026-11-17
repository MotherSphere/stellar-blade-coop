-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The standing rifle pose, after luke77's RifleStance (examples/RifleStance, feature/rifle-stance): EVE's arms posed
-- in code so the rifle's muzzle points along the camera, pitch included, on top of whatever her body plays.
-- * body: a PoseableMeshComponent of her own mesh, snapped to her main mesh, with its materials, lighting channels and
--   shadow; each frame it copies her pose (CopyPoseFromSkeletalComponent), so legs, hips and spine stay hers.
-- * gun: a PoseableMeshComponent of GunNikke_Weapon on the body's right hand at the NIKKE grip (GRIP).
-- * The arms: each arm and finger bone's offset from Spine2 in P_Eve_GunNikke_Hide's first frame (read once from a
--   hidden donor mesh), put back on her chest each frame; the chest frame turned 12 degrees left and lifted at most
--   8 degrees when the barrel points down; the left elbow out 12 degrees; then the whole arm set turned about Spine2 so
--   the muzzle (FX_Fire) yaws and pitches with the camera, blended in over about 12 frames; last, an exact turn of the
--   muzzle axis onto the camera's forward vector.
-- * Her main mesh and SB's own rifle are hidden from her own camera only (SetOwnerNoSee): co-op partners and the
--   ghost capture still read them, so they see the stance's animation with the real rifle.
-- Runs from a 16 ms LoopAsync handed to the game thread, as RifleStance does, not from EVE's tick. Any error stops it
-- and puts her mesh back: gun mode carries on with the stance's own animation.
local Pose={}

Pose.GRIP={Translation={X=-2.110698699951172,Y=-6.265880107879639,Z=2.090805768966675},
    Rotation={X=-0.4851755201816559,Y=-0.5197325944900513,Z=-0.4808891713619232,W=-0.5130578875541687},
    Scale3D={X=1.000000238418579,Y=1,Z=1.0000001192092896}}
Pose.WEAPON='/Game/DLC_2/Art/Character/Weapon/Gun/CH_G_Nikke_01/GunNikke_Weapon.GunNikke_Weapon'
Pose.DONOR_ANIM='/Game/DLC_2/Art/Character/PC/CH_P_EVE_01/Animation/P_Eve_GunNikke_Hide.P_Eve_GunNikke_Hide'
Pose.LEFT_ELBOW,Pose.CHEST_LEFT,Pose.LIFT_MAX,Pose.BLEND_IN,Pose.BLEND_OUT=12,-12,8,0.08,0.06
local IDENTITY={X=0,Y=0,Z=0,W=1}
local ZERO={X=0,Y=0,Z=0}
local ONE={X=1,Y=1,Z=1}

-- A transform turning half-angle `half` (radians) about unit axis (x, y, z).
local function turn(x,y,z,half)
    local s=math.sin(half)
    return {Rotation={X=x*s,Y=y*s,Z=z*s,W=math.cos(half)},Translation=ZERO,Scale3D=ONE}
end
-- A rotation's forward vector (unit quaternion q).
function Pose.forward(q)
    return 1-2*(q.Y*q.Y+q.Z*q.Z),2*(q.X*q.Y+q.W*q.Z),2*(q.X*q.Z-q.W*q.Y)
end
-- Quaternion p*q (Hamilton product, X Y Z W).
function Pose.mul(p,q)
    return {X=p.W*q.X+p.X*q.W+p.Y*q.Z-p.Z*q.Y,Y=p.W*q.Y-p.X*q.Z+p.Y*q.W+p.Z*q.X,
        Z=p.W*q.Z+p.X*q.Y-p.Y*q.X+p.Z*q.W,W=p.W*q.W-p.X*q.X-p.Y*q.Y-p.Z*q.Z}
end
-- The left elbow turned deg degrees about the shoulder-wrist line, toward EVE's left (right: her right vector).
-- shoulder, elbow, wrist: world bone transforms, changed in place.
function Pose.elbow_out(shoulder,elbow,wrist,right,deg)
    local a,b,c=shoulder.Translation,elbow.Translation,wrist.Translation
    local x,y,z=c.X-a.X,c.Y-a.Y,c.Z-a.Z
    local len=math.sqrt(x*x+y*y+z*z)
    if len<0.01 then return end
    x,y,z=x/len,y/len,z/len
    local u,v,w=b.X-a.X,b.Y-a.Y,b.Z-a.Z
    local tx,ty,tz=y*w-z*v,z*u-x*w,x*v-y*u
    local sign=(tx*right.X+ty*right.Y+tz*right.Z)>0 and -1 or 1
    local angle=math.rad(deg*sign)
    local s,co=math.sin(angle),math.cos(angle)
    local proj=(x*u+y*v+z*w)*(1-co)
    elbow.Translation={X=a.X+u*co+tx*s+x*proj,Y=a.Y+v*co+ty*s+y*proj,Z=a.Z+w*co+tz*s+z*proj}
    local h=math.sin(angle/2)
    local r={X=x*h,Y=y*h,Z=z*h,W=math.cos(angle/2)}
    shoulder.Rotation=Pose.mul(r,shoulder.Rotation)
    elbow.Rotation=Pose.mul(r,elbow.Rotation)
end

-- g: gun mode's shared state (gunmode/mode.lua). laser: gunmode/laser.lua's (or nil).
function Pose.new(g,laser)
    local self={on=false}
    local parts,src,pawn,pc,body,gun,donor,bones,offsets,blend,age,saved,hidden,M,running
    local hand,chest_bone,muzzle=FName('Bip001-R-Hand'),FName('Bip001-Spine2'),FName('FX_Fire')

    local function add(kind,asset)
        local id={Rotation=IDENTITY,Translation=ZERO,Scale3D=ONE}
        local c=pawn:AddComponentByClass(StaticFindObject('/Script/Engine.'..kind),true,id,true)
        assert(g.valid(c),'cannot add a '..kind)
        parts[#parts+1]=c
        c:SetVisibility(false,false); c:SetCollisionEnabled(0)
        pawn:FinishAddComponent(c,true,id)
        c:SetSkeletalMesh(asset,true)
        return c
    end
    -- SB's own NIKKE rifle on her: any skeletal mesh component of hers (or of an actor attached to her) with GunNikke.
    local function real_guns()
        local out={}
        local cls=StaticFindObject('/Script/Engine.SkeletalMeshComponent')
        local function scan(actor)
            for _,e in ipairs(g.try(function() return actor:K2_GetComponentsByClass(cls) end) or {}) do
                local c=g.try(function() return e:get() end) or e
                local mesh=g.valid(c) and g.try(function() return c.SkeletalMesh:GetFName():ToString() end)
                if mesh and mesh:find('GunNikke',1,true) and c~=gun then out[#out+1]=c end
            end
        end
        scan(pawn)
        for _,a in ipairs(g.try(function() return pawn:GetAttachedActors({},true) end) or {}) do
            local o=g.try(function() return a:get() end) or a
            if g.valid(o) then scan(o) end
        end
        return out
    end

    function self.stop(why)
        self.on=false
        if laser then pcall(laser.off) end
        if g.valid(src) and saved then
            pcall(function() src:SetOwnerNoSee(saved.hide); src.VisibilityBasedAnimTickOption=saved.tick end)
        end
        for _,c in ipairs(hidden or {}) do pcall(function() if g.valid(c) then c:SetOwnerNoSee(false) end end) end
        for i=#(parts or {}),1,-1 do
            local c=parts[i]
            pcall(function() if g.valid(c) then c:K2_DestroyComponent(c) end end)
        end
        parts,hidden,saved,body,gun,donor,offsets=nil,nil,nil,nil,nil,nil,nil
        if why then g.log('pose: off ('..why..')') end
    end

    function self.start()
        if self.on then return end
        pc,pawn=g.pc(),g.pawn()
        assert(pc and pawn,'no player')
        M=StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
        assert(g.valid(M),'no math library')
        src=pawn.Mesh
        parts,hidden,blend,age,offsets={},{},0,0,nil
        saved={hide=src.bOwnerNoSee,tick=src.VisibilityBasedAnimTickOption}
        body=add('PoseableMeshComponent',src.SkeletalMesh)
        body:K2_AttachToComponent(src,FName('None'),2,2,2,false)
        for slot=0,src:GetNumMaterials()-1 do
            local m=src:GetMaterial(slot)
            if g.valid(m) then body:SetMaterial(slot,m) end
        end
        local ch=src.LightingChannels
        body:SetLightingChannels(ch.bChannel0,ch.bChannel1,ch.bChannel2)
        body:SetCastShadow(src.CastShadow)
        local weapon=LoadAsset(Pose.WEAPON); assert(g.valid(weapon),'no rifle mesh')
        gun=add('PoseableMeshComponent',weapon)
        gun:K2_AttachToComponent(body,hand,2,2,2,false)
        gun:K2_SetRelativeTransform(Pose.GRIP,false,{},true)
        assert(gun:DoesSocketExist(muzzle),'the rifle has no FX_Fire socket')
        donor=add('SkeletalMeshComponent',src.SkeletalMesh)
        donor.VisibilityBasedAnimTickOption=0
        local anim=LoadAsset(Pose.DONOR_ANIM); assert(g.valid(anim),'no NIKKE cover clip')
        donor:PlayAnimation(anim,false); donor:Stop(); donor:SetPosition(0,false)
        bones={}
        for _,side in ipairs({'L','R'}) do
            local names={'Clavicle','UpperArm','Forearm','Hand'}
            for d=0,4 do for _,sfx in ipairs({'','1','2'}) do names[#names+1]='Finger'..d..sfx end end
            for _,n in ipairs(names) do
                local b=FName('Bip001-'..side..'-'..n)
                if src:GetBoneIndex(b)>=0 then bones[#bones+1]=b
                elseif n=='Hand' or n=='UpperArm' or n=='Forearm' then error('no bone '..b:ToString()) end
            end
        end
        self.on=true
        g.log('pose: on ('..#bones..' arm bones)')
    end

    local function muzzle_dir(pose_hand,muzzle_local)
        local w=M:ComposeTransforms(Pose.GRIP,pose_hand)
        return Pose.forward(M:ComposeTransforms(muzzle_local,w).Rotation)
    end

    -- One frame. held: aiming (standing gun mode: always).
    local function frame(held)
        if not (g.valid(pawn) and g.valid(src) and g.valid(pc) and g.valid(pc.Pawn))
                or pc.Pawn:GetAddress()~=pawn:GetAddress() then
            return self.stop('player changed')
        end
        if StaticFindObject('/Script/Engine.Default__GameplayStatics'):IsGamePaused(pc) then return end
        age=age+1; if age<3 then return end
        src.VisibilityBasedAnimTickOption=0
        body:CopyPoseFromSkeletalComponent(src)
        if not offsets then
            offsets={}
            local ref=donor:GetSocketTransform(chest_bone,0)
            for i,b in ipairs(bones) do offsets[i]=M:MakeRelativeTransform(donor:GetSocketTransform(b,0),ref) end
        end
        local cam=pc.PlayerCameraManager:GetCameraRotation()
        local pitch=(cam.Pitch+180)%360-180
        blend=math.max(0,math.min(1,blend+(held and Pose.BLEND_IN or -Pose.BLEND_OUT)))
        local right=pawn:GetActorRightVector()
        local chest=body:GetBoneTransformByName(chest_bone,0)
        local muzzle_local=M:MakeRelativeTransform(gun:GetSocketTransform(muzzle,0),gun:K2_GetComponentToWorld())
        local hand_i
        for i,b in ipairs(bones) do if b:ToString()=='Bip001-R-Hand' then hand_i=i; break end end
        -- The chest frame: lifted when the cover pose's barrel points down, turned left, kept in place.
        local x,y,z=muzzle_dir(M:ComposeTransforms(offsets[hand_i],chest),muzzle_local)
        local yaw=math.atan(y,x)
        local lift=math.max(0,math.min(Pose.LIFT_MAX,math.deg(math.atan(z,math.sqrt(x*x+y*y)))))
        local at=chest.Translation
        if lift>0 then chest=M:ComposeTransforms(chest,turn(-math.sin(yaw),math.cos(yaw),0,math.rad(lift)*0.5)) end
        chest=M:ComposeTransforms(chest,turn(0,0,1,math.rad(Pose.CHEST_LEFT)*0.5))
        chest.Translation={X=at.X,Y=at.Y,Z=at.Z}
        local poses,sh,el,wr={},nil,nil,nil
        for i,b in ipairs(bones) do
            poses[i]=M:ComposeTransforms(offsets[i],chest)
            local n=b:ToString()
            if n=='Bip001-L-UpperArm' then sh=poses[i] elseif n=='Bip001-L-Forearm' then el=poses[i]
            elseif n=='Bip001-L-Hand' then wr=poses[i] end
        end
        if sh and el and wr then Pose.elbow_out(sh,el,wr,right,Pose.LEFT_ELBOW) end
        -- The arm set turned about Spine2: the muzzle's yaw and pitch onto the camera's, by the blend.
        x,y,z=muzzle_dir(poses[hand_i],muzzle_local)
        local dyaw=(cam.Yaw-math.deg(math.atan(y,x))+180)%360-180
        local ty=math.rad(cam.Yaw)
        local ph=(math.atan(z,math.sqrt(x*x+y*y))-math.rad(pitch))*0.5
        local target=M:ComposeTransforms(turn(0,0,1,math.rad(dyaw)*0.5),turn(-math.sin(ty),math.cos(ty),0,ph))
        target.Translation=chest.Translation
        local pivot={Rotation=IDENTITY,Translation=chest.Translation,Scale3D=ONE}
        target=M:TLerp(pivot,target,blend,0)
        for i,b in ipairs(bones) do
            body:SetBoneTransformByName(b,M:ComposeTransforms(M:MakeRelativeTransform(poses[i],pivot),target),0)
        end
        gun:K2_SetRelativeTransform(Pose.GRIP,false,{},true)
        -- Fully aimed: the muzzle axis turned exactly onto the camera's forward vector.
        if held and blend>=1 then
            local axis=M:GetForwardVector(gun:GetSocketRotation(muzzle))
            local goal=M:GetForwardVector(cam)
            local dot=axis.X*goal.X+axis.Y*goal.Y+axis.Z*goal.Z
            if dot<0.9999 then
                local cx,cy,cz=axis.Y*goal.Z-axis.Z*goal.Y,axis.Z*goal.X-axis.X*goal.Z,axis.X*goal.Y-axis.Y*goal.X
                local cw=1+dot
                if cw<1e-6 then cx,cy,cz=-axis.Y,axis.X,0; if cx*cx+cy*cy<1e-6 then cx,cy,cz=1,0,0 end; cw=0 end
                local len=math.sqrt(cx*cx+cy*cy+cz*cz+cw*cw)
                local origin=body:GetBoneTransformByName(chest_bone,0).Translation
                local piv={Rotation=IDENTITY,Translation=origin,Scale3D=ONE}
                local rot={Rotation={X=cx/len,Y=cy/len,Z=cz/len,W=cw/len},Translation=origin,Scale3D=ONE}
                local fixed={}
                for i,b in ipairs(bones) do
                    fixed[i]=M:ComposeTransforms(M:MakeRelativeTransform(body:GetBoneTransformByName(b,0),piv),rot)
                end
                for i,b in ipairs(bones) do body:SetBoneTransformByName(b,fixed[i],0) end
                gun:K2_SetRelativeTransform(Pose.GRIP,false,{},true)
            end
        end
        src:SetOwnerNoSee(true); body:SetVisibility(true,false); gun:SetVisibility(true,false)
        for _,c in ipairs(real_guns()) do
            local key=c:GetFullName()
            if not hidden[key] then hidden[key]=true; hidden[#hidden+1]=c; c:SetOwnerNoSee(true) end
        end
        if laser then
            if held then laser.on(pawn,gun); laser.update() else laser.off() end
        end
    end

    -- The 16 ms loop, armed once a Lua load; want() says whether the pose should be on and held this frame.
    function self.run(want)
        if running then return end
        running=true
        local pending=false
        LoopAsync(16,function()
            if pending then return false end
            pending=true
            ExecuteInGameThread(function()
                local ok,err=pcall(function()
                    local on,held=want()
                    if on and not self.on then self.start() end
                    if not on and self.on then self.stop() end
                    if self.on then frame(held) end
                end)
                if not ok then pcall(self.stop,'error: '..tostring(err)); self.failed=(self.failed or 0)+1 end
                pending=false
            end)
            return false
        end)
    end

    return self
end

return Pose
