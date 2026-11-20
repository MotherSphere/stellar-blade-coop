-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- (dev only, setting gun_g0=on) The rifle layer's landmark numbers measured at the right places, plus side,
-- front and top pictures of the same moment from a hidden SceneCapture2D, so a pose is never judged on numbers alone.
--   * once: the rifle's own sockets and bones in rifle space (to find the handguard, grip and bore points)
--   * twice a second while gun mode is on: facing (actor vs control yaw), left palm to the handguard, IK reach of both
--     arms, the bore (two points) against the camera line; one CSV line each, prefixed "g0,"
--   * pictures: 3 s into carry and 1.5 s into each aim, written to NikkeGunBuild\cap\<n>_<mode>_<view>.png
-- Nothing here touches the post-process instance.
local G0={}

-- rifle-space points (cm); the handguard and breech are refined from the socket dump of the first run
G0.PTS={handguard=nil, breech={X=0,Y=0,Z=9.9}} -- breech: on the barrel line, level with the muzzle (rifle space)

function G0.new(g)
    local self={}
    local st={dumped=false,last=0,mode=nil,mode_at=0,shot={},n=0}
    local function valid(o) return o~=nil and g.try(function() return o:IsValid() end)==true end
    local function ml() return StaticFindObject('/Script/Engine.Default__KismetMathLibrary') end
    local function sub(a,b) return {X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z} end
    local function len(a) return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
    local function nrm(a) local l=len(a); return {X=a.X/l,Y=a.Y/l,Z=a.Z/l} end
    local function dot(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end
    local function wrap(a) a=a%360; if a>180 then a=a-360 end; return a end
    local function f(v) return v and ('%.1f'):format(v) or '' end
    local function v3(v) return v and ('%.1f %.1f %.1f'):format(v.X,v.Y,v.Z) or '-' end

    local function bone(mesh,name) return mesh:GetSocketLocation(FName(name)) end
    local function to_rifle(rifle,p) return ml():InverseTransformLocation(rifle:K2_GetComponentToWorld(),p) end
    local function from_rifle(rifle,p) return ml():TransformLocation(rifle:K2_GetComponentToWorld(),p) end

    local function dump(rifle,mesh)
        st.dumped=true
        local out={}
        local names=g.try(function() return rifle:GetAllSocketNames() end)
        local list={}
        if type(names)=='table' and rawget(names,'ForEach')==nil then for _,n in ipairs(names) do list[#list+1]=n end
        elseif names then pcall(function() names:ForEach(function(_,e) list[#list+1]=e:get() end) end) end
        for _,n in ipairs(list) do
            local nm=g.try(function() return n:ToString() end) or tostring(n)
            local p=g.try(function() return to_rifle(rifle,rifle:GetSocketLocation(FName(nm))) end)
            out[#out+1]=nm..'='..v3(p)
        end
        g.log('g0 rifle points (rifle space, cm): '..table.concat(out,' | '))
        local bounds=g.try(function() local b=rifle.SkeletalMesh:GetBounds(); return b end)
        if bounds then g.log('g0 rifle mesh bounds: origin '..v3(bounds.Origin)..' extent '..v3(bounds.BoxExtent)) end
        -- arm chain on her body mesh (parent names and lengths)
        for _,side in ipairs({'L','R'}) do
            local u,fo,h=('Bip001-%s-UpperArm'):format(side),('Bip001-%s-Forearm'):format(side),('Bip001-%s-Hand'):format(side)
            local pu=g.try(function() return mesh:GetParentBone(FName(u)):ToString() end)
            local pf=g.try(function() return mesh:GetParentBone(FName(fo)):ToString() end)
            local ph=g.try(function() return mesh:GetParentBone(FName(h)):ToString() end)
            local a=len(sub(bone(mesh,fo),bone(mesh,u))); local b=len(sub(bone(mesh,h),bone(mesh,fo)))
            g.log(('g0 %s arm: parents UpperArm<-%s Forearm<-%s Hand<-%s, upper %.1f cm, fore %.1f cm'):format(side,tostring(pu),tostring(pf),tostring(ph),a,b))
            st['arm'..side]=a+b
        end
    end

    -- the hidden capture camera: one SceneCapture2D actor, moved around her for each view
    local function capture(p,tag)
        local world=p:GetWorld()
        local kr=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary')
        if not st.cap_ok then
            local cls=StaticFindObject('/Script/Engine.SceneCapture2D')
            local a=world:SpawnActor(cls,{X=0,Y=0,Z=0},{Pitch=0,Yaw=0,Roll=0})
            if not valid(a) then g.log('g0 capture: could not spawn a SceneCapture2D'); st.cap_fail=true; return end
            st.cap_name=a:GetFullName()
            local c=a.CaptureComponent2D
            local rt=kr:CreateRenderTarget2D(world,960,960,2,{R=0,G=0,B=0,A=1},false) -- 2 = RTF_RGBA8
            c.TextureTarget=rt
            c.bCaptureEveryFrame=false
            c.bCaptureOnMovement=false
            c.CaptureSource=2 -- SCS_FinalColorLDR
            c.FOVAngle=45
            st.cap_ok=true
        end
        local a=StaticFindObject(st.cap_name:match('^%S+ (.+)$'))
        if not valid(a) then st.cap_ok=false; return end
        local c=a.CaptureComponent2D
        local mesh=p.Mesh
        local chest=bone(mesh,'Bip001-Spine2')
        local fwd=p:GetActorForwardVector(); local right=p:GetActorRightVector()
        local views={
            side={X=chest.X+right.X*190,Y=chest.Y+right.Y*190,Z=chest.Z+5},     -- from her right
            front={X=chest.X+fwd.X*200,Y=chest.Y+fwd.Y*200,Z=chest.Z+5},
            top={X=chest.X+fwd.X*40,Y=chest.Y+fwd.Y*40,Z=chest.Z+190},
        }
        st.n=st.n+1
        local dir=os.getenv('USERPROFILE')..'\\Downloads\\Modding Tools\\NikkeGunBuild\\cap'
        os.execute('mkdir "'..dir..'" 2>nul')
        for name,loc in pairs(views) do
            local rot=ml():FindLookAtRotation(loc,chest)
            a:K2_SetActorLocationAndRotation(loc,rot,false,{},false)
            c:CaptureScene()
            local file=('%03d_%s_%s'):format(st.n,tag,name)
            kr:ExportRenderTarget(world,c.TextureTarget,dir,file..'.png')
            st.shot[#st.shot+1]=file
        end
        g.log('g0 capture '..st.n..' '..tag..' (side, front, top) -> cap\\'..('%03d_%s_*.png'):format(st.n,tag))
    end

    function self.tick(pc,p,rifle,mode,now)
        if not (valid(p) and valid(rifle)) then return end
        local mesh=p.Mesh
        if not st.dumped then dump(rifle,mesh) end
        if mode~=st.mode then st.mode,st.mode_at,st.captured=mode,now,false end
        local wait=(mode=='aim') and 1.5 or 3.0
        if not st.captured and not st.cap_fail and now-st.mode_at>=wait and (mode=='aim' or mode=='carry') then
            st.captured=true
            local ok,e=pcall(capture,p,mode)
            if not ok then g.log('g0 capture error: '..tostring(e)); st.cap_fail=true end
        end
        if now-st.last<0.5 then return end
        st.last=now
        local ok,e=pcall(function()
            local cm=pc.PlayerCameraManager
            local ctrl=pc:GetControlRotation()
            local camr=cm:GetCameraRotation()
            local dActor=wrap(p:K2_GetActorRotation().Yaw-ctrl.Yaw)
            -- handguard: the measured point if known, else the CT_Hand_Socket, else 70% of the way from the grip to the muzzle
            local muzzle=rifle:GetSocketLocation(FName('FX_Fire'))
            local grip=rifle:K2_GetComponentLocation()
            -- the same handguard point the solver aims the left palm at (ik.lua), so the check measures that contact
            local frac=require('fight.gunmode.ik').CFG.handguard_frac
            local mzr=to_rifle(rifle,muzzle)
            local hg=G0.PTS.handguard and from_rifle(rifle,G0.PTS.handguard) or from_rifle(rifle,{X=mzr.X*frac,Y=mzr.Y*frac,Z=mzr.Z*frac})
            -- left palm: halfway between the hand bone and the middle finger's base
            local lh=bone(mesh,'Bip001-L-Hand'); local lf=bone(mesh,'Bip001-L-Finger2')
            local palm={X=(lh.X+lf.X)/2,Y=(lh.Y+lf.Y)/2,Z=(lh.Z+lf.Z)/2}
            local dPalm=len(sub(palm,hg))
            local rh=bone(mesh,'Bip001-R-Hand'); local rf=bone(mesh,'Bip001-R-Finger2')
            local rpalm={X=(rh.X+rf.X)/2,Y=(rh.Y+rf.Y)/2,Z=(rh.Z+rf.Z)/2}
            local dRGrip=len(sub(rpalm,grip))
            -- IK reach: target distance from the shoulder over the arm length
            local reachL=len(sub(hg,bone(mesh,'Bip001-L-UpperArm')))/(st.armL or 1)
            local reachR=len(sub(grip,bone(mesh,'Bip001-R-UpperArm')))/(st.armR or 1)
            -- bore: two points on the rifle (breech when measured, else the grip) to the muzzle, against the camera line
            local br=G0.PTS.breech and from_rifle(rifle,G0.PTS.breech) or grip
            local bore=nrm(sub(muzzle,br))
            local camf=ml():GetForwardVector(camr)
            local boreErr=math.deg(math.acos(math.max(-1,math.min(1,dot(bore,camf)))))
            g.log(('g0,%s,%.1f,dActor %s,palmL-handguard %s cm,palmR-grip %s cm,reachL %.2f,reachR %.2f,bore-camera %s deg,camPitch %s,handguard(rifle) %s'):format(
                mode,now,f(dActor),f(dPalm),f(dRGrip),reachL,reachR,f(boreErr),f(camr.Pitch),v3(to_rifle(rifle,hg))))
        end)
        if not ok and not st.err then st.err=true; g.log('g0 error: '..tostring(e)) end
    end
    return self
end

return G0
