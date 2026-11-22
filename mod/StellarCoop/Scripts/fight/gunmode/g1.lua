-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- (dev only, setting gun_g1=on) Gate G1 of the v3 plan, standing aim. 1.5 s into an aim it waits for the camera to
-- hold within 3 deg of -40, then 0, then +40 for 1 s ("g1 pitch wait" log lines guide the mouse), once per pitch per
-- load; at each:
--   1. the gate numbers of g1_gates.lua, averaged over 5 samples, one "g1," line per gate and a pass/fail line
--   2. the AimRot test: IK writes frozen, both shoulder joints in Spine2 space logged, the layer's AimRot set to 0
--      for 0.5 s, logged again (moved > 2 cm = the Neck node moves the shoulder girdle). The AimRot-0 sample is the
--      layer-off shoulder reference (the IK nodes do not move the shoulder joints).
--   3. four fixed SceneCapture views (actor axes, never chosen per shot) and the game camera, to NikkeGunBuild\cap
-- Body reads only; the post-process instance gets one property write (AimRot), as mode.lua does.
local Gates=require('fight.gunmode.g1_gates')
local G1={}

local R,BODY=Gates.RIFLE,Gates.BODY
-- rifle-space samples (cm; bore along -X at Z 9.9), from NikkeGunBuild\g1\measure.json
local P={
    butt={X=R.butt_x,Y=0,Z=8.72}, heel={X=14.56,Y=0,Z=12.69}, toe={X=13.96,Y=0,Z=2.62}, rcv_rear={X=10,Y=0,Z=14},
    grip_base={X=4,Y=0,Z=-1}, mag_base={X=-12,Y=0,Z=-1.5}, hg_rear={X=-18,Y=0,Z=2}, receiver={X=0,Y=0,Z=10},
    breech={X=0,Y=0,Z=9.9}, muzzle={X=-53.4,Y=0,Z=9.9}, sight_rear={X=8,Y=0,Z=16.8}, sight_front={X=-30,Y=0,Z=16.8},
}
local HG_REAR,HG_FRONT,HG_UNDER_Z,HG_AXIS_Z=-18,-44,1.5,5 -- handguard underside span (X), underside and axis height
local TARGETS={-40,0,40}

local function sub(a,b) return {X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z} end
local function add(a,b) return {X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z} end
local function mul(a,s) return {X=a.X*s,Y=a.Y*s,Z=a.Z*s} end
local function dot(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end
local function cross(a,b) return {X=a.Y*b.Z-a.Z*b.Y,Y=a.Z*b.X-a.X*b.Z,Z=a.X*b.Y-a.Y*b.X} end
local function len(a) return math.sqrt(dot(a,a)) end
local function nrm(a) local l=len(a); return l>1e-6 and mul(a,1/l) or {X=0,Y=0,Z=1} end
local function ang(a,b) return math.deg(math.acos(math.max(-1,math.min(1,dot(nrm(a),nrm(b)))))) end
-- quaternions {X,Y,Z,W}
local function qmul(a,b) return {X=a.W*b.X+a.X*b.W+a.Y*b.Z-a.Z*b.Y, Y=a.W*b.Y-a.X*b.Z+a.Y*b.W+a.Z*b.X,
    Z=a.W*b.Z+a.X*b.Y-a.Y*b.X+a.Z*b.W, W=a.W*b.W-a.X*b.X-a.Y*b.Y-a.Z*b.Z} end
local function qinv(q) return {X=-q.X,Y=-q.Y,Z=-q.Z,W=q.W} end
local function qrot(q,v) local p=qmul(qmul(q,{X=v.X,Y=v.Y,Z=v.Z,W=0}),qinv(q)); return {X=p.X,Y=p.Y,Z=p.Z} end
-- point p to segment a-b
local function seg_pt(p,a,b) local ab=sub(b,a); local t=math.max(0,math.min(1,dot(sub(p,a),ab)/math.max(dot(ab,ab),1e-6)))
    return len(sub(p,add(a,mul(ab,t)))) end
local function seg_seg(a,b,c,d) -- sampled; exact enough at 1/20 steps for gate logging
    local best=1e9
    for i=0,20 do local t=i/20; best=math.min(best,seg_pt(add(a,mul(sub(b,a),t)),c,d)) end
    for i=0,20 do local t=i/20; best=math.min(best,seg_pt(add(c,mul(sub(d,c),t)),a,b)) end
    return best
end
-- point to the infinite line through a with direction u
local function line_pt(p,a,u) local d=sub(p,a); return len(sub(d,mul(u,dot(d,u)))) end

-- bind-pose local rotations (shipped CH_P_EVE_01_Skeleton): hand in forearm, Tw1 in forearm
local REF={
    R={hand={X=0.12396,Y=-0.59277,Z=0.00072,W=-0.79577}, tw={X=0,Y=-0.67400,Z=0,W=-0.73873}},
    L={hand={X=0.12396,Y=0.59277,Z=-0.00072,W=-0.79577}, tw={X=0,Y=0.66939,Z=0,W=-0.74291}},
}
-- delta from bind, in the child's own frame: twist about its Y (the long axis, children sit along -Y), swing split
-- into flexion (about X, across the knuckles) and deviation (about Z, the palm normal)
local function decompose(ref,loc)
    local d=qmul(qinv(ref),loc)
    if d.W<0 then d={X=-d.X,Y=-d.Y,Z=-d.Z,W=-d.W} end
    local tl=math.sqrt(d.Y*d.Y+d.W*d.W)
    local tw={X=0,Y=d.Y/tl,Z=0,W=d.W/tl}
    local twist=math.deg(2*math.atan(tw.Y,tw.W))
    local sw=qmul(d,qinv(tw))
    local s=math.sqrt(sw.X*sw.X+sw.Y*sw.Y+sw.Z*sw.Z)
    local a=2*math.atan(s,sw.W)
    local k=s>1e-6 and math.deg(a)/s or 0
    return twist,math.abs(sw.X*k),math.abs(sw.Z*k)
end

function G1.new(g)
    local self={}
    local st={done={},hold_p=nil,hold_at=0,phase=nil,acc=nil,n=0}
    local ml=function() return StaticFindObject('/Script/Engine.Default__KismetMathLibrary') end
    local function valid(o) return o~=nil and g.try(function() return o:IsValid() end)==true end
    local function has(mesh,b) return g.try(function() return mesh:GetBoneIndex(FName(b)) end) or -1 end
    local function W(mesh,b) return mesh:GetSocketLocation(FName(b)) end
    local function CS(mesh,b) return mesh:GetSocketTransform(FName(b),2) end
    local function RW(rifle,p) return ml():TransformLocation(rifle:K2_GetComponentToWorld(),p) end
    local function to_rifle(rifle,p) return ml():InverseTransformLocation(rifle:K2_GetComponentToWorld(),p) end
    local function in_s2(mesh,b) -- bone position in Spine2 space (component-space reads)
        local s2=CS(mesh,'Bip001-Spine2'); local t=CS(mesh,b).Translation
        return qrot(qinv(s2.Rotation),sub(t,s2.Translation))
    end
    local function eye(p,mesh)
        local pts={}
        for _,b in ipairs({'DM_Eye_L','DM_Eye_R'}) do if has(mesh,b)>=0 then pts[#pts+1]=W(mesh,b) end end
        if #pts==2 then return mul(add(pts[1],pts[2]),0.5),'body DM_Eye' end
        local face=g.try(function() return p.Mesh_Face end)
        if valid(face) then
            pts={}
            for _,b in ipairs({'DM_Eye_L','DM_Eye_R'}) do if has(face,b)>=0 then pts[#pts+1]=W(face,b) end end
            if #pts==2 then return mul(add(pts[1],pts[2]),0.5),'face DM_Eye' end
        end
        -- fallback: the right eye from the glabella bone, 2.8 cm to her right and 1.7 cm back (Blender, rest pose)
        if has(mesh,'SC_Glabella')>=0 then
            local JR,JL=W(mesh,'Bip001-R-UpperArm'),W(mesh,'Bip001-L-UpperArm')
            local up=nrm(sub(W(mesh,'Bip001-Neck'),W(mesh,'Bip001-Spine1')))
            local right=nrm(sub(sub(JR,JL),mul(up,dot(sub(JR,JL),up)))); local fwd=cross(right,up)
            return add(add(W(mesh,'SC_Glabella'),mul(right,2.8)),mul(fwd,-1.7)),'SC_Glabella (right eye)'
        end
        return nil,'no eye bones'
    end

    -- one sample of every gate number, world space (cm)
    local function measure(pc,p,rifle)
        local mesh=p.Mesh
        local v,info={},{}
        local JR,JL=W(mesh,'Bip001-R-UpperArm'),W(mesh,'Bip001-L-UpperArm')
        local neck,head,sp1=W(mesh,'Bip001-Neck'),W(mesh,'Bip001-Head'),W(mesh,'Bip001-Spine1')
        local up=nrm(sub(neck,sp1)); local right=nrm(sub(sub(JR,JL),mul(up,dot(sub(JR,JL),up)))); local fwd=cross(right,up)
        local PK=require('fight.gunmode.ik').CFG.pocket -- the solver's pocket (refined on her mesh), so the gate checks the same point
        local pocket=add(add(add(JR,mul(right,PK.r)),mul(fwd,PK.f)),mul(up,PK.u))
        local rp={}; for k,q in pairs(P) do rp[k]=RW(rifle,q) end
        v.butt_pocket=len(sub(rp.butt,pocket))
        -- neck capsule r 5.5, wrist sphere r 3, forearm capsule r 3.2 (surface to surface)
        local RH,RF=W(mesh,'Bip001-R-Hand'),W(mesh,'Bip001-R-Forearm')
        v.rwrist_neck=seg_pt(RH,neck,head)-5.5-3
        v.rforearm_neck=seg_seg(RF,RH,neck,head)-5.5-3.2
        local rpalm=mul(add(RH,W(mesh,'Bip001-R-Finger2')),0.5)
        v.grip_fwd=dot(sub(rpalm,JR),fwd)
        -- stock vs neck (5.5), chest Spine1->Neck (9.5), collar sphere at the R clavicle midpoint (4); samples r 1.5
        local RC=W(mesh,'Bip001-R-Clavicle'); local collar=mul(add(RC,JR),0.5)
        local sc,scw=1e9,''
        for _,k in ipairs({'butt','heel','toe','rcv_rear'}) do
            for name,d in pairs({neck=seg_pt(rp[k],neck,head)-5.5, chest=seg_pt(rp[k],sp1,neck)-9.5, collar=len(sub(rp[k],collar))-4}) do
                if d-1.5<sc then sc,scw=d-1.5,k..'/'..name end
            end
        end
        v.stock_clear=sc; info.stock_worst=scw
        -- rifle samples (r 2) and forearm capsules (r 3.2) vs breast spheres r 10 + 1 on the live Ab-*-Breast bones
        local bc,bcw=1e9,'no breast bones'
        for _,b in ipairs({'Ab-L-Breast','Ab-R-Breast'}) do
            if has(mesh,b)>=0 then
                local c=W(mesh,b)
                for _,k in ipairs({'grip_base','mag_base','hg_rear','receiver'}) do
                    local d=len(sub(rp[k],c))-11-2; if d<bc then bc,bcw=d,k..'/'..b end
                end
                for _,s in ipairs({'L','R'}) do
                    local d=seg_pt(c,W(mesh,('Bip001-%s-Forearm'):format(s)),W(mesh,('Bip001-%s-Hand'):format(s)))-11-3.2
                    if d<bc then bc,bcw=d,s..'forearm/'..b end
                end
            end
        end
        if bc<1e9 then v.breast_clear_0=bc; v.breast_clear_40=bc end; info.breast_worst=bcw
        -- eye to the sight line (approximate line 1 cm under the sight top, parallel to the bore)
        local e,esrc=eye(p,mesh); info.eye=esrc
        if e then v.eye_sight=line_pt(e,rp.sight_rear,nrm(sub(rp.sight_front,rp.sight_rear))) end
        -- bore, two points, against the camera forward
        local camf=ml():GetForwardVector(pc.PlayerCameraManager:GetCameraRotation())
        v.bore_ray=ang(sub(rp.muzzle,rp.breech),camf)
        -- wrists, elbows, reach, both sides (component space for the rotations)
        local armlen=BODY.arm_upper+BODY.arm_fore
        for _,s in ipairs({'L','R'}) do
            local fo,ha,tw=CS(mesh,('Bip001-%s-Forearm'):format(s)),CS(mesh,('Bip001-%s-Hand'):format(s)),CS(mesh,('Ab-%s-Forearm-Tw1'):format(s))
            local twist,flex,dev=decompose(REF[s].hand,qmul(qinv(fo.Rotation),ha.Rotation))
            local twt=decompose(REF[s].tw,qmul(qinv(fo.Rotation),tw.Rotation))
            v['wrist_flex_'..s]=flex; v['wrist_dev_'..s]=dev
            local r=math.abs(twist-twt)%360; v['wrist_twist_'..s]=r>180 and 360-r or r
            local U,F,H=W(mesh,('Bip001-%s-UpperArm'):format(s)),W(mesh,('Bip001-%s-Forearm'):format(s)),W(mesh,('Bip001-%s-Hand'):format(s))
            v['elbow_'..s]=ang(sub(U,F),sub(H,F))
            v['reach_'..s]=len(sub(H,U))/armlen
        end
        v.lforearm_vert=(function() local a=ang(sub(W(mesh,'Bip001-L-Hand'),W(mesh,'Bip001-L-Forearm')),{X=0,Y=0,Z=1}); return math.min(a,180-a) end)()
        -- left palm in rifle space: normal = across x long, signed toward the curl of the middle finger
        local LH,LF2=W(mesh,'Bip001-L-Hand'),W(mesh,'Bip001-L-Finger2')
        local long=nrm(sub(LF2,LH)); local across=nrm(sub(W(mesh,'Bip001-L-Finger1'),W(mesh,'Bip001-L-Finger4')))
        local n=nrm(cross(long,across))
        local curl=sub(W(mesh,'Bip001-L-Finger22'),LF2); curl=sub(curl,mul(long,dot(curl,long)))
        if dot(n,curl)<0 then n=mul(n,-1) end
        info.lcurl=len(curl)
        local palm=mul(add(LH,LF2),0.5)
        local pr=to_rifle(rifle,palm)
        local axis_pt=RW(rifle,{X=math.max(HG_FRONT,math.min(HG_REAR,pr.X)),Y=0,Z=HG_AXIS_Z})
        v.lpalm_normal=ang(n,sub(axis_pt,palm))
        v.lpalm_gap=math.abs(pr.Z-HG_UNDER_Z)+math.max(0,math.abs(pr.Y)-2.6)
        v.lpalm_rear=(HG_REAR-pr.X)/(HG_REAR-HG_FRONT)
        info.lpalm_rifle=('%.1f %.1f %.1f'):format(pr.X,pr.Y,pr.Z)
        -- the arm joints in rifle space (log only; compared with the authored pose)
        local js={}
        for _,jn in ipairs({'Neck','L-Clavicle','L-UpperArm','L-Forearm','L-Hand','R-Clavicle','R-UpperArm','R-Forearm','R-Hand'}) do
            local q=to_rifle(rifle,W(mesh,'Bip001-'..jn)); js[#js+1]=('%s %.1f %.1f %.1f'):format(jn,q.X,q.Y,q.Z)
        end
        info.joints=table.concat(js,' | ')
        -- fingertips (log only): the four finger tips' distance to the handguard surface (axis minus 4 cm)
        local ft=0
        for i=1,4 do
            -- a missing Nub bone would read as the mesh origin: use the last joint then
            local nub=('Bip001-L-Finger%dNub'):format(i)
            local tip=W(mesh,has(mesh,nub)>=0 and nub or ('Bip001-L-Finger%d2'):format(i))
            local tr=to_rifle(rifle,tip)
            ft=math.max(ft,math.abs(math.sqrt(tr.Y*tr.Y+(tr.Z-HG_AXIS_Z)^2)-4))
        end
        v.fingertip=ft
        return v,info
    end

    local function capture(p,pc,rifle,tag)
        local world=p:GetWorld()
        local kr=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary')
        if not st.cap_name then
            local a=world:SpawnActor(StaticFindObject('/Script/Engine.SceneCapture2D'),{X=0,Y=0,Z=0},{Pitch=0,Yaw=0,Roll=0})
            if not valid(a) then g.log('g1 capture: no SceneCapture2D'); st.cap_fail=true; return end
            st.cap_name=a:GetFullName()
            local c=a.CaptureComponent2D
            c.TextureTarget=kr:CreateRenderTarget2D(world,960,960,2,{R=0,G=0,B=0,A=1},false)
            c.bCaptureEveryFrame=false; c.bCaptureOnMovement=false; c.CaptureSource=2
        end
        local a=StaticFindObject(st.cap_name:match('^%S+ (.+)$'))
        if not valid(a) then st.cap_name=nil; return end
        local c=a.CaptureComponent2D
        local mesh=p.Mesh
        local chest=W(mesh,'Bip001-Spine2')
        local F,Rt=p:GetActorForwardVector(),p:GetActorRightVector(); local U={X=0,Y=0,Z=1}
        local function at(o,f,r,u) return add(add(add(o,mul(F,f)),mul(Rt,r)),mul(U,u)) end
        local lh=W(mesh,'Bip001-L-Hand'); local rn=mul(add(W(mesh,'Bip001-R-Hand'),W(mesh,'Bip001-Neck')),0.5)
        -- four views: right profile and front at 3 m with a 20 deg lens; 80 cm close-ups at 45 deg
        local d80=80/math.sqrt(3)
        local views={
            {'side',at(chest,0,300,0),chest,20},
            {'front',at(chest,300,0,0),chest,20},
            {'lhand',at(lh,d80,-d80,-d80),lh,45},
            {'rwrist',at(rn,d80,d80,d80),rn,45},
            {'q34',at(chest,170,170,90),chest,30}, -- front-right-high, 2.6 m (a wall in front blocks 'front' at some spots)
        }
        st.n=st.n+1
        local dir=os.getenv('USERPROFILE')..'\\Downloads\\Modding Tools\\NikkeGunBuild\\cap'
        os.execute('mkdir "'..dir..'" 2>nul')
        for _,vw in ipairs(views) do
            c.FOVAngle=vw[4]
            a:K2_SetActorLocationAndRotation(vw[2],ml():FindLookAtRotation(vw[2],vw[3]),false,{},false)
            c:CaptureScene()
            kr:ExportRenderTarget(world,c.TextureTarget,dir,('g1_%s_%s.png'):format(tag,vw[1]))
        end
        pcall(function()
            local cm=pc.PlayerCameraManager
            c.FOVAngle=cm:GetFOVAngle()
            a:K2_SetActorLocationAndRotation(cm:GetCameraLocation(),cm:GetCameraRotation(),false,{},false)
            c:CaptureScene()
            kr:ExportRenderTarget(world,c.TextureTarget,dir,('g1_%s_cam.png'):format(tag))
        end)
        g.log('g1 capture '..tag..' -> cap\\g1_'..tag..'_{side,front,lhand,rwrist,cam}.png')
    end

    -- s: mode.lua's state (s.g1_hold freezes the IK writes and mode.lua's AimRot write); ppi: the post-process instance
    function self.tick(pc,p,rifle,mode,now,s,ppi,tag)
        if not (valid(p) and valid(rifle)) then return end
        local function cam_pitch() local q=pc.PlayerCameraManager:GetCameraRotation().Pitch; return q>180 and q-360 or q end
        -- 1.5 s into an aim the targets are taken in turn
        if st.phase==nil then
            if mode~='aim' then st.aim_at=nil; return end
            st.aim_at=st.aim_at or now
            if now-st.aim_at<1.5 then return end
            local nxt; for _,x in ipairs(TARGETS) do if not st.done[x] then nxt=x; break end end
            if not nxt then
                if not st.all then st.all=true; g.log('g1: all three pitches done') end
                return
            end
            st.phase,st.t,st.at=nxt,'settle_in',now
            return
        end
        local t=st.phase
        if mode~='aim' then -- left aim mid-test: release, retry later
            s.g1_hold=false; s.head_yaw=nil; st.phase=nil; st.aim_at=nil
            g.log(('g1 %d: aim left mid-test, will retry'):format(t)); return
        end
        if st.t=='settle_in' then
            -- the aim camera does not follow SetControlRotation (red2: -12.3 at every target), so wait until the camera
            -- itself holds within 3 deg of the target for 1 s (mouse input brings it there), logging it twice a second
            local cp=cam_pitch()
            if now-(st.wlog or 0)>=0.5 then st.wlog=now; g.log(('g1 pitch wait %d camera %.1f'):format(t,cp)) end
            if math.abs(cp-t)>3 then st.in_at=nil
                if now-st.at>45 then g.log(('g1 %d: camera never reached it (last %.1f), skipped'):format(t,cp)); st.done[t]=true; st.phase=nil end
                return
            end
            st.in_at=st.in_at or now
            if now-st.in_at<1.0 then return end
            st.t,st.acc,st.k,st.at,st.pitch_sum='sample',{},0,now,0
        elseif st.t=='sample' then
            if now-st.at<0.1 then return end
            st.at=now
            local v,info=measure(pc,p,rifle)
            for k,x in pairs(v) do st.acc[k]=(st.acc[k] or 0)+x end
            st.info=info; st.k=st.k+1; st.pitch_sum=st.pitch_sum+cam_pitch()
            if st.k<5 then return end
            local avg={}; for k,x in pairs(st.acc) do avg[k]=x/st.k end
            st.avg=avg
            local cp=st.pitch_sum/st.k
            g.log(('g1,%s,%d,camera_pitch,%.1f,%s'):format(tag,t,cp,math.abs(cp-t)<=3 and 'at target' or 'OFF TARGET (camera clamp?)'))
            for _,gt in ipairs(Gates.LIST) do
                local r=Gates.check(gt.id,avg[gt.id],t)
                if gt.id~='shoulder_drift' and (r~=nil or avg[gt.id]==nil) then
                    g.log(('g1,%s,%d,%s,%s,%s'):format(tag,t,gt.id,avg[gt.id] and ('%.2f'):format(avg[gt.id]) or 'n/a',
                        r==nil and 'n/a' or (gt.logonly and 'log' or (r and 'PASS' or 'FAIL'))))
                end
            end
            local i=st.info
            g.log(('g1 %d info: stock worst %s, breast worst %s, eye from %s, left palm (rifle) %s, middle-finger curl %.1f cm'):format(
                t,i.stock_worst,i.breast_worst,i.eye,i.lpalm_rifle,i.lcurl))
            if i.joints then g.log(('g1 %d joints (rifle cm): %s'):format(t,i.joints)) end
            -- pictures before the AimRot test (the test zeroes the chest turn for 0.5 s, so pictures after it show an unaimed pose)
            if not st.cap_fail then
                local okc,ec=pcall(capture,p,pc,rifle,('%s_p%d'):format(tag,t))
                if not okc then g.log('g1 capture error: '..tostring(ec)); st.cap_fail=true end
            end
            -- AimRot test: freeze, read shoulders, AimRot 0
            s.g1_hold=true
            st.sh0={R=in_s2(p.Mesh,'Bip001-R-UpperArm'),L=in_s2(p.Mesh,'Bip001-L-UpperArm')}
            local ok=pcall(function()
                local r=ppi.AimRot; st.aimrot={Pitch=r.Pitch,Yaw=r.Yaw,Roll=r.Roll} -- copy: r reads the live property
                ppi.AimRot={Pitch=0,Yaw=0,Roll=0}
            end)
            if not ok then g.log('g1: AimRot write failed') end
            st.t,st.at='aimrot',now
        elseif st.t=='aimrot' then
            if now-st.at<0.5 then return end
            local sh1={R=in_s2(p.Mesh,'Bip001-R-UpperArm'),L=in_s2(p.Mesh,'Bip001-L-UpperArm')}
            local dR,dL=len(sub(st.sh0.R,sh1.R)),len(sub(st.sh0.L,sh1.L))
            local ar=st.aimrot; local ars=ar and ('(%.1f, %.1f, %.1f)'):format(ar.Pitch,ar.Yaw,ar.Roll) or '?'
            local big=ar and (math.abs(ar.Pitch)+math.abs(ar.Yaw)+math.abs(ar.Roll))>=5
            g.log(('g1,%s,%d,aimrot_test,AimRot %s -> 0: R shoulder moved %.2f cm, L %.2f cm (Spine2 space) -> R1 %s'):format(
                tag,t,ars,dR,dL,not big and 'NOT TESTED (AimRot under 5 deg)' or ((math.max(dR,dL)>2) and 'CONFIRMED' or 'NOT confirmed')))
            local drift=math.max(dR,dL)
            local r=Gates.check('shoulder_drift',drift,t)
            g.log(('g1,%s,%d,shoulder_drift,%.2f,%s'):format(tag,t,drift,r and 'PASS' or 'FAIL'))
            st.avg.shoulder_drift=drift
            local pass,fail=Gates.judge(st.avg,t)
            g.log(('g1,%s,%d,summary,pass %d,fail %d: %s'):format(tag,t,#pass,#fail,table.concat(fail,' ')))
            -- release: mode.lua writes AimRot again on its next tick
            s.g1_hold=false; s.head_yaw=nil
            st.t,st.at='settle',now
        elseif st.t=='settle' then
            if now-st.at<0.4 then return end
            st.done[t]=true; st.phase=nil
        end
    end
    self.capture=capture -- (p, pc, rifle, tag): the fixed views now, also outside the gate (mode.lua: photo mode)
    return self
end

return G1
