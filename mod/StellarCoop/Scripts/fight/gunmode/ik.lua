-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The rifle-first solver (gate G0). Each tick, in her body mesh's component space:
--   1. place the rifle: its grip a little in front of her right shoulder; in aim the bore points at the spot 20 m down
--      the camera line, in carry it hangs at low ready (pitched down, across her body)
--   2. right hand = rifle composed with the inverse of the attach GRIP (the attached rifle then lands exactly there)
--   3. left hand = the hand placement that puts her palm on the handguard point (its palm offset measured live)
--   4. elbow poles below and outside each shoulder
-- and writes the layer's variables in one batch (ArmsAlpha, RHandLoc_S2, RHandRot_CS, RElbowPole_S2, LHandLoc_RH,
-- LHandRot_RH, LElbowPole_S2; the names are the layer's. Every value here is in component space, which is how
-- the graph's nodes are set). Only property writes reach the post-process instance.
local IK={}

-- quaternions {x,y,z,w}, UE conventions
local function qmul_into(o,a,b) -- a after b, into o (o may be b)
    o[1],o[2],o[3],o[4]=a[4]*b[1]+a[1]*b[4]+a[2]*b[3]-a[3]*b[2], a[4]*b[2]-a[1]*b[3]+a[2]*b[4]+a[3]*b[1],
        a[4]*b[3]+a[1]*b[2]-a[2]*b[1]+a[3]*b[4], a[4]*b[4]-a[1]*b[1]-a[2]*b[2]-a[3]*b[3]
    return o
end
local function qmul(a,b) return qmul_into({},a,b) end -- a after b
local function qinv(q) return {-q[1],-q[2],-q[3],q[4]} end
local function qrot3n(q,vx,vy,vz) -- q*v*conj(q) on numbers (the same product for any |q|)
    local x,y,z,w=q[1],q[2],q[3],q[4]
    local a=w*w-(x*x+y*y+z*z); local b=2*(x*vx+y*vy+z*vz); local c=2*w
    return a*vx+b*x+c*(y*vz-z*vy),a*vy+b*y+c*(z*vx-x*vz),a*vz+b*z+c*(x*vy-y*vx)
end
local function qrot3(q,vx,vy,vz) local X,Y,Z=qrot3n(q,vx,vy,vz); return {X=X,Y=Y,Z=Z} end
local function qrot(q,v) return qrot3(q,v.X,v.Y,v.Z) end -- rotate vector {X,Y,Z}
local function rot2q(r) -- FRotator -> FQuat (UE)
    local DR=math.pi/360
    local sp,cp=math.sin(r.Pitch*DR),math.cos(r.Pitch*DR)
    local sy,cy=math.sin(r.Yaw*DR),math.cos(r.Yaw*DR)
    local sr,cr=math.sin(r.Roll*DR),math.cos(r.Roll*DR)
    return {cr*sp*sy-sr*cp*cy, -cr*sp*cy-sr*cp*sy, cr*cp*sy-sr*sp*cy, cr*cp*cy+sr*sp*sy}
end
local function q2rot(q) -- FQuat::Rotator
    local X,Y,Z,W=q[1],q[2],q[3],q[4]
    local st=Z*X-W*Y
    local yaw=math.deg(math.atan(2*(W*Z+X*Y),1-2*(Y*Y+Z*Z)))
    local pitch,roll
    if st<-0.4999995 then pitch=-90; roll=-yaw-2*math.deg(math.atan(X,W))
    elseif st>0.4999995 then pitch=90; roll=yaw-2*math.deg(math.atan(X,W))
    else pitch=math.deg(math.asin(2*st)); roll=math.deg(math.atan(-2*(W*X+Y*Z),1-2*(X*X+Y*Y))) end
    return {Pitch=pitch,Yaw=yaw,Roll=roll}
end
-- the v4 pin's writes to the post-process instance, in their order (a function made once, not a closure a frame)
local function write_pin(pp,o1,rq,o2,o3,lq,o4)
    pp.RHandLoc_S2=o1
    pp.RHandRot_CS=q2rot(rq)
    pp.RElbowPole_S2=o2
    pp.LHandLoc_RH=o3
    pp.LHandRot_RH=q2rot(lq)
    pp.LElbowPole_S2=o4
    pp.ArmsAlpha=IK.fade or 1 -- (fight/gunmode/mode.lua eases it through the rifle's arrival and departure)
end
local function isv(o) return o:IsValid() end
local Z0={X=0,Y=0,Z=0}
-- a grip's rotation as a quaternion {x,y,z,w}, made once per grip table (Rifle.GRIPS never change)
local GQ=setmetatable({},{__mode='k'})
local function grip_q(G)
    local q=GQ[G]; if not q then local r=G.Rotation; q={r.X,r.Y,r.Z,r.W}; GQ[G]=q end
    return q
end
-- t = a + (x,y,z), written into t (a scratch table of the caller)
local function add_into(t,a,x,y,z) t.X,t.Y,t.Z=a.X+x,a.Y+y,a.Z+z; return t end
local function lerp_into(o,a,b,k) o.X,o.Y,o.Z=a.X+(b.X-a.X)*k,a.Y+(b.Y-a.Y)*k,a.Z+(b.Z-a.Z)*k; return o end
local function slerp_into(o,a,b,k) -- quaternion slerp a -> b by k on the short way, into o
    local d=a[1]*b[1]+a[2]*b[2]+a[3]*b[3]+a[4]*b[4]; local s=d<0 and -1 or 1; d=math.abs(d)
    local ka,kb=1-k,k
    if d<0.9995 then local th=math.acos(d); local sn=math.sin(th); ka,kb=math.sin((1-k)*th)/sn,math.sin(k*th)/sn end
    kb=kb*s
    local x,y,z,w=a[1]*ka+b[1]*kb,a[2]*ka+b[2]*kb,a[3]*ka+b[3]*kb,a[4]*ka+b[4]*kb
    local l=math.sqrt(x*x+y*y+z*z+w*w); o[1],o[2],o[3],o[4]=x/l,y/l,z/l,w/l; return o
end
local function tbv(ai,ap,v) return qrot3(ai,v.X-ap.X,v.Y-ap.Y,v.Z-ap.Z) end -- v into the anchor's frame
local function add(a,b) return {X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z} end
local function sub(a,b) return {X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z} end
local function mul(a,s) return {X=a.X*s,Y=a.Y*s,Z=a.Z*s} end
local function dot(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end
local function cross(a,b) return {X=a.Y*b.Z-a.Z*b.Y,Y=a.Z*b.X-a.X*b.Z,Z=a.X*b.Y-a.Y*b.X} end
local function len(a) return math.sqrt(dot(a,a)) end
local function nrm(a) local l=len(a); return l>1e-6 and mul(a,1/l) or {X=1,Y=0,Z=0} end
-- the rotation taking orthonormal frame (x1,z1) onto (x2,z2), as a quaternion
local function frame_q(x,z) -- quaternion of the basis (x, y=z cross x, z)
    local y=cross(z,x)
    local m00,m01,m02=x.X,y.X,z.X
    local m10,m11,m12=x.Y,y.Y,z.Y
    local m20,m21,m22=x.Z,y.Z,z.Z
    local tr=m00+m11+m22
    local q
    if tr>0 then local s=math.sqrt(tr+1)*2; q={(m21-m12)/s,(m02-m20)/s,(m10-m01)/s,0.25*s}
    elseif m00>m11 and m00>m22 then local s=math.sqrt(1+m00-m11-m22)*2; q={0.25*s,(m01+m10)/s,(m02+m20)/s,(m21-m12)/s}
    elseif m11>m22 then local s=math.sqrt(1+m11-m00-m22)*2; q={(m01+m10)/s,0.25*s,(m12+m21)/s,(m02-m20)/s}
    else local s=math.sqrt(1+m22-m00-m11)*2; q={(m02+m20)/s,(m12+m21)/s,0.25*s,(m10-m01)/s} end
    return q
end
local function ortho(x,z) x=nrm(x); z=nrm(sub(z,mul(x,dot(z,x)))); return x,z end
-- a pin entry's left hand (t, q, e) in the rifle's frame for the grip G its pose was made with: right hand = rifle * G^-1,
-- so left = G^-1 * (left in the hand's frame - G.T). Made once per entry and grip (the entries never change)
local LRF=setmetatable({},{__mode='k'})
local function left_in_rifle(rel,G)
    local c=LRF[rel]; if c and c.G==G then return c end
    local gi=qinv(grip_q(G)); local T=G.Translation
    c={G=G,t=qrot(gi,sub(rel.t,T)),q=qmul(gi,rel.q),e=rel.e and qrot(gi,sub(rel.e,T))}
    LRF[rel]=c; return c
end
-- the run carry's entry at run weight W (into the scratch tables o, made once): the rifle's place on Spine2 (r) and the
-- right elbow (re) from the carry entry cr toward the aim entry ar; the left hand blended in the rifle's frame (where it
-- sits on the rifle in each pose), then put back in the right hand's frame through the live grip Gc
local function run_entry(o,cr,ar,Gc,Ga,W)
    local lc,la=left_in_rifle(cr,Gc),left_in_rifle(ar,Ga)
    local gq,T=grip_q(Gc),Gc.Translation
    local x,y,z
    lerp_into(o.t,lc.t,la.t,W); x,y,z=qrot3n(gq,o.t.X,o.t.Y,o.t.Z); o.t.X,o.t.Y,o.t.Z=x+T.X,y+T.Y,z+T.Z
    qmul_into(o.q,gq,slerp_into(o.q,lc.q,la.q,W))
    if lc.e and la.e then
        lerp_into(o.le,lc.e,la.e,W); x,y,z=qrot3n(gq,o.le.X,o.le.Y,o.le.Z); o.le.X,o.le.Y,o.le.Z=x+T.X,y+T.Y,z+T.Z; o.e=o.le
    else o.e=cr.e end
    lerp_into(o.r.t,cr.r.t,ar.r.t,W); slerp_into(o.r.q,cr.r.q,ar.r.q,W)
    lerp_into(o.re,cr.re,ar.re,W)
    return o
end

-- tuning (cm / degrees); starting values set before the build, refined in game
IK.CFG={
    grip_aim={fwd=22,right=3,up=3},     -- rifle grip point from her right shoulder joint, aim (stock in the shoulder pocket)
    grip_carry={fwd=16,right=-5,up=-3}, -- (carry places the grip from butt_carry instead)
    butt_carry={fwd=2,right=-4,up=-4}, stock_len=15, -- low ready: the butt in her shoulder pocket, the grip 15 cm down the bore
    carry_pitch=-30, carry_yaw=35, carry_cant=12, aim_cant=3,
    pole_r={right=40,fwd=5,up=-5}, pole_l={right=-25,fwd=20,up=-35}, -- elbows out, clear of her chest
    aim_dist=2000, head_turn=1.0, aim_mesh_yaw=-75, -- her mesh turned back this far while aiming (the aim stance blades her ~105 deg)
    lhand={x_fwd=0.85,x_right=0.4,x_up=0.15,z_up=1,below=3.5}, -- (z_up -1 put the palm face down, G1 v3a2: 178 deg) left hand axes in rifle space; palm this far under the bore line
    rel=false, -- was {q={0.2301,0.6314,0.3212,0.6672},t={X=1.91,Y=-24.67,Z=10.52}}: put her hand through the rifle; the support hand in the right hand's frame {q={x,y,z,w},t={X,Y,Z}} once measured (Blender: P_Eve_GunNikke_Shoot_Idle frame 0, Y mirrored to UE; nil: measure in game)
    lhand_nudge={X=-4,Y=0,Z=4}, -- (rifle space, cm) the NIKKE support hand moved onto this rifle's handguard
    handguard_frac=0.62,                  -- the handguard as a fraction of the grip->muzzle distance, until measured
    -- v3 aim (round 2): the butt plate centre at the pocket point, 3.5 cm medial, 4.5 forward and 1.5 up from the right
    -- shoulder joint in her chest frame; rifle points in rifle space (cm, Blender rifle10: barrel along -X at Z 9.88)
    -- pocket refined on her mesh (Blender raycast: skin 8.2 cm in front of the joint at the pocket, 10.5-13.6 lower
    -- down where the toe lands): butt centre 10 forward, 3 up, so the heel rides the collarbone and the toe meets the skin
    pocket={r=-3.5,f=10.5,u=3}, butt_r={X=14.4,Y=0,Z=8.72}, breech_r={X=0,Y=0,Z=9.88},
    lhand_hg={X=-21,Y=0,Z=-1.5}, -- left palm target: under the rear of the handguard (35.4 cm from the butt)
    reach_max=0.88, -- the left target slides back toward the butt (2 cm steps, up to 8) while beyond this share of her arm
    scale=1,        -- rifle scale (fight/gunmode/rifle.lua builds GRIP with it)
    straight_wrist=true, -- aim: elbows placed so the forearm continues each hand (see the pole code in tick)
    -- v4: the layer plays the authored poses; only the left hand is pinned, to the live right hand (her in-game body's
    -- proportions differ from the authoring skeleton, so the clip alone leaves the hand off the rifle). Per layer clip:
    -- the left hand in the right hand's frame (UE, cm), from NikkeGunBuild\poses\<Pose>\<Pose>.blend, Y mirrored.
    -- nil turns the v4 pin off (the v2/v3 solver below runs); a clip without an entry gets no pin.
    pin_left={
        -- e: the left elbow (Bip001-L-Forearm) in the same frame, so the IK bends the arm as authored
        -- r: the rifle in pin_anchor's frame (Bip001-Spine2: the layer's clips start at Bip001-Neck, so the aim-up and
        -- aim-down clips do not move it) and re: the right elbow in the rifle's frame (rifle first: the rifle placed as
        -- authored, then both hands reach it); without r the right hand keeps the clip's pose
        aim={t={X=-13.07,Y=-27.70,Z=5.90},q={0.3627,0.6272,0.3505,0.5935},e={X=-10.69,Y=-12.12,Z=24.51},   -- AimLevel round 4
            r={t={X=0.58,Y=-8.64,Z=22.95},q={0.3557,0.6366,-0.5606,0.3924}},re={X=21.87,Y=-17.12,Z=-11.52}},
        carry={t={X=-3.12,Y=-28.68,Z=11.08},q={0.2780,0.7190,0.3644,0.5224},e={X=-5.83,Y=-10.24,Z=26.81}, -- CarryLowReady rd4
            r={t={X=1.58,Y=22.02,Z=15.67},q={-0.0232,0.4741,-0.8215,0.3160}},re={X=30.26,Y=0.68,Z=-5.25}},
    },
    -- rifle space (cm; -X is toward the muzzle, +Z up): the rifle moved this far from the authored place, clear of her
    -- in-game body (G1 v4d: stock heel 2.3 cm into her neck, grip base 0.5 cm from the right breast)
    pin_nudge={aim={X=-3,Y=0,Z=-1},carry={X=-2,Y=0,Z=0}},
    -- rifle space (cm): the left hand moved this far after its place from the right hand, onto this rifle's handguard
    -- (start: lhand_nudge, the v2 solver's measure; the v4 pin had no correction for this rifle)
    pin_lnudge={aim={X=-4,Y=0,Z=4},carry={X=-4,Y=0,Z=4}},
    pin_anchor='Bip001-Spine2',
    -- 'bone': the IK targets go out in pin_anchor's bone space (TwoBoneIK_0/1 effector and joint targets on
    -- Bip001-Spine2 in ABP_NGM_Spike), so the graph follows her spine every frame; 'component': component space
    pin_space='bone',
    -- hip fire (fight/gunmode/mode.lua): the body turn on and off at these degrees of body yaw against the camera yaw, at
    -- turn_rate deg/s; on the hip-fire press a gap of snap_deg or more snaps her round at snap_rate deg/s (at most
    -- snap_max s). turn_start stays below chest_yaw_max_hip (the chest's yaw limit in hip fire), or a gap between them
    -- never fires. chest_yaw_max is the limit in the game's aim and in the air
    turn_start=25, turn_stop=6, turn_rate=360, snap_deg=45, snap_rate=1440, snap_max=0.3, chest_yaw_max=60, chest_yaw_max_hip=55,
    pin_blend=0.14, -- s: the rifle and both hands ease toward a new placement (aim <-> carry <-> reload) at this time constant
    -- recoil per round (fight/gunmode/mode.lua calls kick): the rifle back along its stock and its muzzle up, both through the
    -- butt, easing out at recoil_time (s); the hands go with it
    recoil_back=1.6, recoil_up=3.5, recoil_time=0.07, recoil_max=2.2,
    pin_wrist=true, -- the left hand turned with the forearm the IK will give it (the wrist keeps the authored bend)
    pin_pole=30, -- cm the left elbow pole sits out from the elbow (keeps the clip's bend plane)
    -- the reload (want 'reload', on the carry pose): over the reload's time k 0..1 the rifle turns about its butt (roll
    -- toward her, muzzle down), the left hand leaves the handguard for the magazine (rifle space: its base -11.33, 0,
    -- -1.75), pulls it 10 cm down, brings it back and returns to the handguard
    pin_reload={roll=35, pitch=-12, mag={X=-11.3,Y=0,Z=-4}, pull=10},
    -- aim pitch split (fight/gunmode/mode.lua): the chest (AimRot on Spine2) up to chest_pitch_max, the rifle pivoting on its
    -- butt (pin_butt, rifle space) for the rest up to rifle_pitch_max (one joint carrying 40 deg put the stock in her mouth).
    -- The chest takes the pitch first (the rifle pivots only past the chest's cap). chest_roll_max: the chest levelled
    -- about the bore by at most this many deg (her Spine1 -> Neck against world up; 0: no roll, as before)
    chest_pitch_max=28, rifle_pitch_max=55, pin_butt={X=14.4,Y=0,Z=8.72}, chest_roll_max=25,
    aim_clip_up=22, aim_clip_back=15, -- deg of rifle pitch for the AimUp45 / AimDown45 head clips (fight/gunmode/mode.lua)
    flip_tilt=60, -- deg of Pelvis->Spine1 tilt in the air that counts as the double-jump flip (fight/gunmode/mode.lua)
    pin_down_fwd=0.1, -- cm per degree of downward rifle pitch the rifle moves out level (G1 v4f at -40: grip 1.5 cm into the breast)
    -- the run carry (a chest ready): a run weight W, 0 at run_lo cm/s of ground speed and 1 at run_hi (eased at time
    -- constant run_ease s), moves the carried rifle from the carry entry toward the aim entry (its place on Spine2, its
    -- nudge and the left hand on the handguard, all by W), then turns its muzzle down by run_down*W deg through the
    -- butt (run_down=30: at chest height, muzzle forward and down, both hands on it). Both hands (not the elbow poles)
    -- lag her chest's bob on a damped spring (sway_hz, sway_zeta), sway_gain of the lag up to sway_max cm, all times W
    run_lo=150, run_hi=300, run_ease=0.25, run_down=30,
    sway_hz=2.2, sway_zeta=0.45, sway_gain=0.3, sway_max=4,
    pin_reach=0.92,   -- the left-hand target at most this share of her arm's length from the shoulder (false: no limit)
    lpole_rifle=true, -- at a run the left elbow pole holds the direction last seen standing, in the rifle's frame
}

-- the reload stands on the carry pose (fight/gunmode/overlay.lua CLIPS.reload)
IK.CFG.pin_left.reload=IK.CFG.pin_left.carry
IK.CFG.pin_nudge.reload=IK.CFG.pin_nudge.carry
IK.CFG.pin_lnudge.reload=IK.CFG.pin_lnudge.carry

-- The run weight: 0 at lo cm/s, 1 at hi (smoothstep)
function IK.run_target(speed,lo,hi)
    local t=math.max(0,math.min(1,((speed or 0)-lo)/(hi-lo)))
    return t*t*(3-2*t)
end

-- One step of a damped spring sp ({x,y,z,vx,vy,vz}) toward v ({X,Y,Z}) at hz with damping ratio zeta. Semi-implicit
-- Euler, dt clamped to 0.05 s (stable while 2*pi*hz*dt stays under 2).
local function spring1(x,vel,to,w,zeta,dt)
    vel=vel+(-2*zeta*w*vel-w*w*(x-to))*dt
    return x+vel*dt,vel
end
function IK.spring(sp,v,dt,hz,zeta)
    dt=math.max(0,math.min(dt,0.05)); local w=2*math.pi*hz
    sp.x,sp.vx=spring1(sp.x,sp.vx,v.X,w,zeta,dt)
    sp.y,sp.vy=spring1(sp.y,sp.vy,v.Y,w,zeta,dt)
    sp.z,sp.vz=spring1(sp.z,sp.vz,v.Z,w,zeta,dt)
    return sp
end

function IK.new(g)
    local self={}
    local st={}
    local function valid(o) if o==nil then return false end local ok,r=pcall(isv,o); return ok and r==true end
    local FN={} -- FName per bone name, made once (an FName from a string each call cost frame time)
    local function cs(mesh,bone) -- component-space bone transform: location, quaternion
        local f=FN[bone]; if not f then f=FName(bone); FN[bone]=f end
        local t=mesh:GetSocketTransform(f,2) -- RTS_Component
        local p,r=t.Translation,t.Rotation
        return {X=p.X,Y=p.Y,Z=p.Z},{r.X,r.Y,r.Z,r.W}
    end

    -- rifle-space geometry, measured once from the attached rifle: bore axis, up, muzzle, handguard point
    local function measure(rifle,Rifle)
        local ml=StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
        local T=rifle:K2_GetComponentToWorld()
        local mz=ml:InverseTransformLocation(T,rifle:GetSocketLocation(FName('FX_Fire')))
        local fwdW=ml:GetForwardVector(rifle:GetSocketRotation(FName('FX_Fire')))
        local bore=nrm(ml:InverseTransformDirection(T,fwdW))
        local up=ml:InverseTransformDirection(T,ml:GetUpVector(rifle:K2_GetComponentRotation()))
        st.geo={muzzle=mz,bore=bore,up=nrm(up)}
        g.log(('ik: rifle muzzle (rifle space) %.1f %.1f %.1f, bore %.2f %.2f %.2f'):format(mz.X,mz.Y,mz.Z,bore.X,bore.Y,bore.Z))
        local G=Rifle.GRIP
        st.gq={G.Rotation.X,G.Rotation.Y,G.Rotation.Z,G.Rotation.W}
        st.gt={X=G.Translation.X,Y=G.Translation.Y,Z=G.Translation.Z}
    end

    -- The support hand as NIKKE holds the rifle: the vanilla NIKKE rifle idle is played once on her main anim instance
    -- (the layer off meanwhile) and her left hand is read relative to her right hand. The left hand then rides on the
    -- right hand with that transform, so it lands where (and shaped as) the clip's left hand holds the rifle.
    local SHOOT_IDLE='/Game/DLC_2/Art/Character/PC/CH_P_EVE_01/Animation/P_Eve_GunNikke_Shoot_Idle.P_Eve_GunNikke_Shoot_Idle'
    local SLOTS={'DefaultSlot','UpperBody','FullBody','Upper'}
    local function find(path)
        local o=StaticFindObject(path)
        if valid(o) then return o end
        return g.try(function() return StaticFindObject('/Script/AssetRegistry.Default__AssetRegistryHelpers'):GetAsset({ObjectPath=FName(path)}) end)
    end
    local function measure_rel(mesh,pp)
        local now=os.clock()
        local m=st.meas
        if not m then
            local mi=mesh:GetAnimInstance(); local seq=find(SHOOT_IDLE)
            if not (valid(mi) and valid(seq)) then st.rel=false; g.log('ik: support-hand measure: no anim instance or clip'); return end
            local l0=cs(mesh,'Bip001-L-Hand')
            st.meas={mi=mi,seq=seq,slot=1,at=now,l0=l0}
            pcall(function() mi:PlaySlotAnimationAsDynamicMontage(seq,FName(SLOTS[1]),0.0,0.0,1.0,100000,-1.0,0.0) end)
            pcall(function() pp.ArmsAlpha=0 end); st.alpha=0
            return
        end
        if now-m.at<0.6 then return end
        local rp,rq=cs(mesh,'Bip001-R-Hand'); local lp,lq=cs(mesh,'Bip001-L-Hand')
        local moved=len(sub(lp,m.l0))
        local playing=g.try(function() return m.mi:IsPlayingSlotAnimation(m.seq,FName(SLOTS[m.slot])) end)
        g.log(('ik: support-hand measure on slot %s: playing %s, left hand moved %.1f cm'):format(SLOTS[m.slot],tostring(playing),moved))
        pcall(function() m.mi:StopSlotAnimation(0.0,FName(SLOTS[m.slot])) end)
        if moved<4 and m.slot<#SLOTS then
            m.slot=m.slot+1; m.at=now; m.l0=lp
            pcall(function() m.mi:PlaySlotAnimationAsDynamicMontage(m.seq,FName(SLOTS[m.slot]),0.0,0.0,1.0,100000,-1.0,0.0) end)
            return
        end
        if moved<4 then st.rel=false; g.log('ik: support-hand measure failed (no slot moved her)'); return end
        local iq=qinv(rq)
        st.rel={q=qmul(iq,lq),t=qrot(iq,sub(lp,rp))}
        local t,q=st.rel.t,st.rel.q
        g.log(('ik: support hand from the NIKKE idle (in the right hand frame): t %.2f %.2f %.2f q %.4f %.4f %.4f %.4f'):format(t.X,t.Y,t.Z,q[1],q[2],q[3],q[4]))
    end

    -- quaternion blend a -> b by t (normalised lerp on the short way: enough for small per-frame steps)
    local function qblend(a,b,t)
        local d=a[1]*b[1]+a[2]*b[2]+a[3]*b[3]+a[4]*b[4]; local s=d<0 and -1 or 1
        local x,y,z,w=a[1]+(s*b[1]-a[1])*t,a[2]+(s*b[2]-a[2])*t,a[3]+(s*b[3]-a[3])*t,a[4]+(s*b[4]-a[4])*t
        local l=math.sqrt(x^2+y^2+z^2+w^2); return {x/l,y/l,z/l,w/l}
    end
    -- one round fired: the recoil kick (fight/gunmode/mode.lua)
    -- scale: this round's share of a full kick (hip fire kicks less; nil: 1). The scaled amount builds up, so a change
    -- of scale never rescales the kick still easing out
    function self.kick(scale) st.recoil=math.min(IK.CFG.recoil_max,(st.recoil or 0)+(scale or 1)) end

    -- the shortest turn taking direction a onto direction b (both unit)
    local function q_between(a,b)
        local cx,cy,cz=a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X; local d=dot(a,b)
        if d<-0.9999 then return {0,0,1,0} end
        local w=1+d; local l=math.sqrt(cx*cx+cy*cy+cz*cz+w*w)
        return {cx/l,cy/l,cz/l,w/l}
    end
    -- where a two-bone chain shoulder->elbow->wrist puts the elbow for this wrist target and pole (lengths a, b)
    local function elbow_at(sh,wr,pole,a,b)
        -- (plain numbers, the same operations in the same order as the vector helpers: one table)
        local dx,dy,dz=wr.X-sh.X,wr.Y-sh.Y,wr.Z-sh.Z; local c=math.sqrt(dx*dx+dy*dy+dz*dz); if c<1e-3 then return nil end
        local ic=1/c; local nx,ny,nz=dx*ic,dy*ic,dz*ic; c=math.min(c,(a+b)*0.9999)
        local x=(c*c+a*a-b*b)/(2*c); local r=math.sqrt(math.max(0,a*a-x*x))
        local px,py,pz=pole.X-sh.X,pole.Y-sh.Y,pole.Z-sh.Z; local k=px*nx+py*ny+pz*nz
        px,py,pz=px-nx*k,py-ny*k,pz-nz*k; local pl=math.sqrt(px*px+py*py+pz*pz); if pl<1e-3 then return nil end
        local ip=1/pl
        return {X=sh.X+nx*x+px*ip*r,Y=sh.Y+ny*x+py*ip*r,Z=sh.Z+nz*x+pz*ip*r}
    end

    -- v4 pin: the left hand where the authored pose has it relative to the right hand (rel = {t, q} in the right
    -- hand's frame); the elbow pole out from the authored elbow (rel.e; else the current one), away from the
    -- shoulder->hand line. The right hand
    -- values are its own pose (its IK node is off). No rel: the IK stands down.
    function self.pin(mesh,pp,rel)
        if not rel then
            if st.alpha~=0 then pcall(function() pp.ArmsAlpha=0 end); st.alpha=0 end
            return
        end
        local G=rel.r and (require('fight.gunmode.rifle').GRIPS or {})[self.want]
        local rp,rq,rpole,np,nq
        -- the run weight (self.speed: her ground speed, fight/gunmode/mode.lua), eased every frame so it fades out of carry
        local C=IK.CFG
        local t_run=os.clock(); local d_run=math.min(0.5,math.max(0,t_run-(st.run_at or t_run))); st.run_at=t_run
        local tgt=self.want=='carry' and IK.run_target(self.speed,C.run_lo,C.run_hi) or 0
        st.runw=(st.runw or 0)+(tgt-(st.runw or 0))*(1-math.exp(-d_run/C.run_ease))
        local W=st.runw; self.runw=W -- (fight/gunmode/mode.lua logs it under gun_trace=on)
        local AE=IK.CFG.pin_left.aim
        local run=G and self.want=='carry' and W>0 and AE and AE.r and AE.re and true or false
        if run then
            local o=st.rr; if not o then o={t={},q={},le={},r={t={},q={}},re={}}; st.rr=o end
            rel=run_entry(o,rel,AE,G,require('fight.gunmode.rifle').GRIPS.aim,W)
        end
        if G then
            -- rifle first: rifle = anchor * r (+ nudge in rifle space); right hand = rifle * GRIP^-1
            np,nq=cs(mesh,IK.CFG.pin_anchor)
            local Rq=qmul(nq,rel.r.q)
            local Rp=add(np,qrot(nq,rel.r.t))
            local PN=IK.CFG.pin_nudge or {}
            local nd=PN[self.want]
            if run and (nd or PN.aim) then -- (into a scratch table: CFG unchanged)
                st.ndw=st.ndw or {}; nd=lerp_into(st.ndw,nd or Z0,PN.aim or Z0,W)
            end
            if nd then Rp=add(Rp,qrot(Rq,nd)) end
            local rk=self.want=='reload' and self.reload_k
            local w=rk and math.sin(math.pi*math.max(0,math.min(1,rk))) or 0
            if w>0 then
                -- reload tilt: roll about the bore (rifle X), then muzzle down about its right (Y), both through the butt
                local RL=IK.CFG.pin_reload; local B=IK.CFG.pin_butt
                local bw=add(Rp,qrot(Rq,B))
                local hr,hp=math.rad(RL.roll*w)/2,math.rad(RL.pitch*w)/2
                Rq=qmul(qmul(Rq,{math.sin(hr),0,0,math.cos(hr)}),{0,math.sin(hp),0,math.cos(hp)})
                Rp=sub(bw,qrot(Rq,B))
            end
            self.rifle_now={p=Rp,q=Rq} -- (the reload's left hand path is in this rifle frame)
            local pa=self.want=='aim' and (self.rpitch or 0) or (run and -C.run_down*W or 0)
            if pa~=0 then
                -- muzzle up by pa degrees: a turn about the rifle's own +Y (its right) through the butt
                if pa<0 then -- (out level along the bore, on numbers into a scratch table)
                    local fx,fy=qrot3n(Rq,-1,0,0); local fl=math.sqrt(fx*fx+fy*fy)
                    if fl>0.1 then
                        local k=-pa*IK.CFG.pin_down_fwd/fl
                        local r=st.pdp or {}; st.pdp=r; r.X,r.Y,r.Z=Rp.X+fx*k,Rp.Y+fy*k,Rp.Z; Rp=r
                    end
                end
                -- (on numbers into scratch tables made once: it runs every frame at a run; rifle_now keeps the tables above)
                local h=math.rad(pa)/2; local B=IK.CFG.pin_butt
                local sx,sy,sz=qrot3n(Rq,B.X,B.Y,B.Z)
                local bx,by,bz=Rp.X+sx,Rp.Y+sy,Rp.Z+sz -- the butt
                local sn,cs_=math.sin(h),math.cos(h)
                local a1,a2,a3,a4=Rq[1],Rq[2],Rq[3],Rq[4]
                local q=st.pq or {}; st.pq=q -- qmul(Rq,{0,sn,0,cs_}), term for term
                q[1],q[2],q[3],q[4]=a4*0+a1*cs_+a2*0-a3*sn, a4*sn-a1*0+a2*cs_+a3*0, a4*0+a1*sn-a2*0+a3*cs_, a4*cs_-a1*0-a2*sn-a3*0
                Rq=q
                local tx,ty,tz=qrot3n(Rq,B.X,B.Y,B.Z)
                local r=st.prp or {}; st.prp=r; r.X,r.Y,r.Z=bx-tx,by-ty,bz-tz
                Rp=r
            end
            local gq=grip_q(G)
            rq=qmul(Rq,qinv(gq)); rp=sub(Rp,qrot(rq,G.Translation))
            local rsh=cs(mesh,'Bip001-R-UpperArm')
            local re=add(Rp,qrot(Rq,rel.re)); local ro=sub(re,mul(add(rsh,rp),0.5))
            rpole=len(ro)>0.5 and add(re,mul(nrm(ro),IK.CFG.pin_pole)) or re
        else
            rp,rq=cs(mesh,'Bip001-R-Hand'); rpole=cs(mesh,'Bip001-R-Forearm')
        end
        local lq=qmul(rq,rel.q)
        local lloc=add(rp,qrot(rq,rel.t))
        local LN=C.pin_lnudge or {}
        local lnd=G and LN[self.want]
        if run and (lnd or LN.aim) then st.lndw=st.lndw or {}; lnd=lerp_into(st.lndw,lnd or Z0,LN.aim or Z0,W) end
        if lnd then lloc=add(lloc,qrot(qmul(rq,grip_q(G)),lnd)) end -- rq*grip: the rifle's final rotation, pitch included
        local rk=self.want=='reload' and self.reload_k
        if rk and G and self.rifle_now then
            -- the left hand's trip: handguard -> magazine (k 0..0.3), pull down (0.3..0.5), push up (0.5..0.7), back (0.7..1)
            local RL=IK.CFG.pin_reload; local R=self.rifle_now
            local mag=add(R.p,qrot(R.q,RL.mag)); local low=add(R.p,qrot(R.q,{X=RL.mag.X,Y=RL.mag.Y,Z=RL.mag.Z-RL.pull}))
            local function lerp(a,b,t) return add(a,mul(sub(b,a),t)) end
            local function ss(t) t=math.max(0,math.min(1,t)); return t*t*(3-2*t) end
            if rk<0.3 then lloc=lerp(lloc,mag,ss(rk/0.3))
            elseif rk<0.5 then lloc=lerp(mag,low,ss((rk-0.3)/0.2))
            elseif rk<0.7 then lloc=lerp(low,mag,ss((rk-0.5)/0.2))
            else lloc=lerp(mag,lloc,ss((rk-0.7)/0.3)) end
        end
        local sh=cs(mesh,'Bip001-L-UpperArm'); local el=rel.e and add(rp,qrot(rq,rel.e)) or cs(mesh,'Bip001-L-Forearm')
        if not st.larm then -- her left upper arm and forearm lengths, measured once
            local u,f,h=cs(mesh,'Bip001-L-UpperArm'),cs(mesh,'Bip001-L-Forearm'),cs(mesh,'Bip001-L-Hand')
            st.larm={len(sub(f,u)),len(sub(h,f))}
        end
        -- the left target kept within pin_reach of her arm's length from the shoulder: the elbow never locks straight
        -- (a target past reach flipped the elbow at a run). Not during the reload trip: its points must be reached
        if C.pin_reach and not rk then
            local lim=C.pin_reach*(st.larm[1]+st.larm[2])
            local dx,dy,dz=lloc.X-sh.X,lloc.Y-sh.Y,lloc.Z-sh.Z; local d=math.sqrt(dx*dx+dy*dy+dz*dz)
            if d>lim then local k=lim/d; lloc={X=sh.X+dx*k,Y=sh.Y+dy*k,Z=sh.Z+dz*k} end
        end
        local mid=mul(add(sh,lloc),0.5); local out=sub(el,mid)
        local pole=el
        if len(out)>0.5 then
            local d=nrm(out)
            -- lpole_rifle: at a run the pole's direction is the one last seen standing, held in the right hand's frame
            -- (the rifle's), so the elbow stays put on the rifle while her shoulder bobs
            if C.lpole_rifle and G then
                local lp=st.lpole
                if W<0.01 or not lp or st.lpole_want~=self.want then
                    lp=lp or {}; st.lpole=lp; st.lpole_want=self.want
                    lp.X,lp.Y,lp.Z=qrot3n(qinv(rq),d.X,d.Y,d.Z)
                else d=qrot(rq,lp) end
            end
            pole=add(el,mul(d,IK.CFG.pin_pole))
        end
        if IK.CFG.pin_wrist and rel.e and not rk then
            -- the authored forearm direction (elbow -> wrist) onto the one the IK gives her arm: the hand turns with it
            local e=elbow_at(sh,lloc,pole,st.larm[1],st.larm[2])
            if e then
                local fa=nrm(qrot(rq,sub(rel.t,rel.e))); local fb=nrm(sub(lloc,e))
                lq=qmul(q_between(fa,fb),lq)
            end
        end
        -- ease toward this placement in the anchor's frame (a new clip or the reload no longer jumps), then the recoil
        -- (the G branch read the anchor already; nothing was written to the engine since)
        local ap,aq=np,nq; if not ap then ap,aq=cs(mesh,IK.CFG.pin_anchor) end; local ai=qinv(aq)
        local now=os.clock()
        local T={tbv(ai,ap,rp),qmul(ai,rq),tbv(ai,ap,rpole),tbv(ai,ap,lloc),qmul(ai,lq),tbv(ai,ap,pole)}
        local sm=st.sm
        local dt=sm and now-sm.at or 1
        if sm and dt<0.5 then
            local k=IK.CFG.pin_blend<=1e-6 and 1 or 1-math.exp(-math.max(dt,0)/IK.CFG.pin_blend)
            for i=1,6 do
                if i==2 or i==5 then sm[i]=qblend(sm[i],T[i],k)
                else local a,b=sm[i],T[i]; a.X=a.X+(b.X-a.X)*k; a.Y=a.Y+(b.Y-a.Y)*k; a.Z=a.Z+(b.Z-a.Z)*k end -- (in place: sm's own table)
            end
            sm.at=now
        else sm={T[1],T[2],T[3],T[4],T[5],T[6],at=now}; st.sm=sm end
        local b_rp,b_rq,b_rpole,b_l,b_lq,b_pole=sm[1],sm[2],sm[3],sm[4],sm[5],sm[6]
        -- the run sway: a spring follows the anchor's component-space path (her chest's bob with each stride); its lag,
        -- turned into the anchor frame, moves the rifle and both hands, not the elbow poles (after the blend, so it is not damped by it;
        -- before the recoil, which applies on top)
        if W>=0.01 and dt<0.5 then
            local sp=st.sp
            if not sp then sp={x=ap.X,y=ap.Y,z=ap.Z,vx=0,vy=0,vz=0}; st.sp=sp end
            IK.spring(sp,ap,dt,C.sway_hz,C.sway_zeta)
            local k=C.sway_gain*W
            local ox,oy,oz=(sp.x-ap.X)*k,(sp.y-ap.Y)*k,(sp.z-ap.Z)*k
            local l=math.sqrt(ox*ox+oy*oy+oz*oz); if l>C.sway_max then local m=C.sway_max/l; ox,oy,oz=ox*m,oy*m,oz*m end
            ox,oy,oz=qrot3n(ai,ox,oy,oz)
            -- the hands only: a pole moved with them flapped her elbows at each stride. Into scratch tables made once (sm
            -- keeps the eased targets)
            local w=st.sw; if not w then w={{},{}}; st.sw=w end
            b_rp,b_l=add_into(w[1],b_rp,ox,oy,oz),add_into(w[2],b_l,ox,oy,oz)
        else st.sp=nil end
        local rc=st.recoil or 0
        if rc>0.01 and G then
            -- recoil in the anchor frame: about the rifle's right (Y) through its butt, and back along its stock (+X)
            local gq=grip_q(G)
            local Rq=qmul(b_rq,gq); local Rp=add(b_rp,qrot(b_rq,G.Translation))
            local bw=add(Rp,qrot(Rq,IK.CFG.pin_butt))
            local h=math.rad(IK.CFG.recoil_up*rc)/2
            local rot=qmul(qmul(Rq,{0,math.sin(h),0,math.cos(h)}),qinv(Rq)) -- the turn, in the anchor frame
            local back=qrot(Rq,{X=IK.CFG.recoil_back*rc,Y=0,Z=0})
            local function mv(p) return add(add(bw,qrot(rot,sub(p,bw))),back) end
            b_rp,b_l=mv(b_rp),mv(b_l); b_rq,b_lq=qmul(rot,b_rq),qmul(rot,b_lq)
            st.recoil=rc*math.exp(-math.max(dt,0)/IK.CFG.recoil_time)
        else st.recoil=0 end
        rq,lq=qmul(aq,b_rq),qmul(aq,b_lq)
        -- locations in the anchor bone's space (the graph's IK nodes read them there); rotations stay component
        local o1,o2,o3,o4=b_rp,b_rpole,b_l,b_pole
        if IK.CFG.pin_space~='bone' then
            local function fc(v) return add(ap,qrot(aq,v)) end
            o1,o2,o3,o4=fc(b_rp),fc(b_rpole),fc(b_l),fc(b_pole)
        end
        local ok,e=pcall(write_pin,pp,o1,rq,o2,o3,lq,o4)
        st.alpha=1
        if not ok and not st.err then st.err=true; g.log('ik pin write: '..tostring(e)) end
        st.last={hloc=o1,lloc=o3} -- (nothing reads it; in bone mode it holds anchor-space locations)
        return st.last
    end

    -- mode: 'aim' | 'carry' | 'off'; returns a table of numbers for the log
    function self.tick(pc,p,rifle,mode,pp)
        local mesh=p.Mesh
        if not valid(pp) then return end
        if mode=='off' then
            if st.alpha~=0 then pcall(function() pp.ArmsAlpha=0 end); st.alpha=0 end
            return
        end
        if IK.CFG.pin_left then return self.pin(mesh,pp,IK.CFG.pin_left[self.want or mode]) end
        if not st.geo then measure(rifle,require('fight.gunmode.rifle')) end
        if st.rel==nil and IK.CFG.rel==false then st.rel=false end
        if st.rel==nil and IK.CFG.rel then st.rel={q=IK.CFG.rel.q,t=IK.CFG.rel.t} end
        if st.rel==nil then measure_rel(mesh,pp); if st.rel==nil then return end end
        local ml=StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
        local CT=mesh:K2_GetComponentToWorld()
        -- her axes in component space
        local fwd=nrm(ml:InverseTransformDirection(CT,p:GetActorForwardVector()))
        local right=nrm(ml:InverseTransformDirection(CT,p:GetActorRightVector()))
        local up=nrm(cross(fwd,right)); up= (up.Z<0) and mul(up,-1) or up
        local rsh=cs(mesh,'Bip001-R-UpperArm'); local lsh=cs(mesh,'Bip001-L-UpperArm')
        local C=IK.CFG
        if mode~='aim' then
            -- carry (and firing in the air) follows her upper body, not the actor: turns and the run twist her shoulders
            -- away from the actor's facing (a video), and in a flip the whole frame turns over with her
            local neck=cs(mesh,'Bip001-Neck'); local pel=cs(mesh,'Bip001-Pelvis')
            local sr=nrm(sub(rsh,lsh)); local su=nrm(sub(neck,pel))
            local f2=nrm(cross(sr,su))
            if f2.X==f2.X and sr.X==sr.X then right=sr; fwd=f2; up=nrm(cross(fwd,right)) end
        end
        local o=(mode=='aim' or mode=='air') and C.grip_aim or C.grip_carry
        local gripP=add(add(add(rsh,mul(fwd,o.fwd)),mul(right,o.right)),mul(up,o.up))
        -- bore direction
        local d
        if mode=='aim' then
            local cm=pc.PlayerCameraManager
            local cl=cm:GetCameraLocation()
            local cf=ml:GetForwardVector(cm:GetCameraRotation())
            local aimW={X=cl.X+cf.X*C.aim_dist,Y=cl.Y+cf.Y*C.aim_dist,Z=cl.Z+cf.Z*C.aim_dist}
            local aimC=ml:InverseTransformLocation(CT,aimW)
            d=nrm(sub(aimC,gripP))
        elseif mode=='air' then
            d=fwd -- in the air the rifle points where her chest points, through the flip
        else
            -- low ready: forward, pitched down, turned across her body
            local yaw,pit=math.rad(C.carry_yaw),math.rad(C.carry_pitch)
            local h=add(mul(fwd,math.cos(yaw)),mul(right,-math.sin(yaw)))
            d=nrm(add(mul(h,math.cos(pit)),mul(up,math.sin(pit))))
            -- low ready pivots on the butt in her shoulder pocket: the grip sits a stock's length down the bore from it
            local b=C.butt_carry
            local butt=add(add(add(rsh,mul(fwd,b.fwd)),mul(right,b.right)),mul(up,b.up))
            gripP=add(butt,mul(d,C.stock_len))
        end
        -- rifle rotation: its bore onto d, its up as close to her up as possible (plus cant)
        local G=st.geo
        local bx,bz=ortho(G.bore,G.up)
        local tx,tz=ortho(d,up)
        local cant=math.rad((mode=='aim' or mode=='air') and C.aim_cant or C.carry_cant)
        local ty=cross(tz,tx); tz=nrm(add(mul(tz,math.cos(cant)),mul(ty,math.sin(cant))))
        local Rr=qmul(frame_q(tx,tz),qinv(frame_q(bx,bz)))
        -- the rifle's origin so that its grip (origin) sits at gripP
        local rifleLoc=gripP
        local s=C.scale or 1
        local hgAim
        if mode=='aim' and C.pocket then
            -- v3 (round 2, 1.3): the rifle pivots on its butt at the pocket point, in her chest frame (up Spine1->Neck,
            -- right across the shoulder joints), so aiming up or down swings the barrel, not the stock; two passes
            -- put the bore line (not the butt) through the aim point
            local neck=cs(mesh,'Bip001-Neck'); local sp1=cs(mesh,'Bip001-Spine1')
            local cu=nrm(sub(neck,sp1)); local sr=sub(rsh,lsh)
            local cr=nrm(sub(sr,mul(cu,dot(sr,cu)))); local cf=cross(cr,cu)
            if dot(cf,fwd)<0 then cf=mul(cf,-1) end
            local P=C.pocket
            local pocket=add(add(add(rsh,mul(cr,P.r)),mul(cf,P.f)),mul(cu,P.u))
            local cm=pc.PlayerCameraManager
            local cl=cm:GetCameraLocation(); local cfw=ml:GetForwardVector(cm:GetCameraRotation())
            local aimC=ml:InverseTransformLocation(CT,{X=cl.X+cfw.X*C.aim_dist,Y=cl.Y+cfw.Y*C.aim_dist,Z=cl.Z+cfw.Z*C.aim_dist})
            local function rot_for(dir)
                local x,z=ortho(dir,cu); local y=cross(z,x); local c=math.rad(C.aim_cant)
                z=nrm(add(mul(z,math.cos(c)),mul(y,math.sin(c))))
                return qmul(frame_q(x,z),qinv(frame_q(bx,bz)))
            end
            local dd=nrm(sub(aimC,pocket))
            for _=1,2 do
                local R=rot_for(dd)
                dd=nrm(sub(aimC,add(pocket,qrot(R,mul(sub(C.breech_r,C.butt_r),s)))))
            end
            Rr=rot_for(dd)
            rifleLoc=sub(pocket,qrot(Rr,mul(C.butt_r,s)))
            -- the left hand under the rear of the handguard, slid back toward the butt while it is out of reach
            local la=len(sub(cs(mesh,'Bip001-L-Forearm'),lsh))+len(sub(cs(mesh,'Bip001-L-Hand'),cs(mesh,'Bip001-L-Forearm')))
            local hr=C.lhand_hg
            for back=0,8,2 do
                hgAim=add(rifleLoc,qrot(Rr,mul({X=hr.X+back,Y=hr.Y,Z=hr.Z},s)))
                if len(sub(hgAim,lsh))<=C.reach_max*la then break end
            end
            up,right,fwd=cu,cr,cf -- the poles below use her chest frame while aiming
        end
        -- right hand = rifle composed with inverse GRIP:  rifle = hand * GRIP  ->  hand.rot = Rr * gq^-1, hand.loc = rifleLoc - hand.rot*gt
        local hq=qmul(Rr,qinv(st.gq))
        local hloc=sub(rifleLoc,qrot(hq,st.gt))
        -- handguard point (rifle space) along the grip->muzzle line
        local hgR=mul(G.muzzle,C.handguard_frac*s)
        local hg=hgAim or add(rifleLoc,qrot(Rr,hgR))
        -- left hand: rotation = right hand's (until the style pose); palm offset measured live in hand space
        -- left hand: palm up under the handguard, fingers across to the far side (axes set in rifle space)
        local rr=cross(bz,bx) -- rifle right (y = z cross x)
        local L=C.lhand
        local lx=nrm(add(add(mul(bx,L.x_fwd),mul(rr,L.x_right)),mul(bz,L.x_up)))
        local lz=mul(bz,L.z_up)
        lx,lz=ortho(lx,lz)
        local lq=qmul(Rr,frame_q(lx,lz))
        if not hgAim then hg=add(hg,qrot(Rr,mul(bz,-L.below))) end -- (the aim target is already on the underside)
        local lloc_rel
        if st.rel then lq=qmul(hq,st.rel.q); lloc_rel=add(add(hloc,qrot(hq,st.rel.t)),qrot(Rr,C.lhand_nudge)) end
        local lh,lhq=cs(mesh,'Bip001-L-Hand'); local lf=cs(mesh,'Bip001-L-Finger2')
        local palmLocal=qrot(qinv(lhq),mul(sub(lf,lh),0.5))
        st.palm=st.palm or palmLocal -- frozen on first use
        local lloc=lloc_rel or sub(hg,qrot(lq,st.palm))
        -- poles
        local pr,pl=C.pole_r,C.pole_l
        local poleR=add(add(add(rsh,mul(right,pr.right)),mul(fwd,pr.fwd)),mul(up,pr.up))
        local poleL=add(add(add(lsh,mul(right,pl.right)),mul(fwd,pl.fwd)),mul(up,pl.up))
        if hgAim and C.straight_wrist then
            -- wrist-friendly elbows (round 2, 3.2): of all elbow positions the two-bone chain allows (a circle around
            -- the shoulder->wrist line), take the one nearest to "a forearm's length straight back along the hand's long
            -- axis", so the forearm continues the hand instead of bending the wrist; the pole is pushed out through it
            local function elbow_pole(sh,fo,ha,wr,q,longL,old)
                local a=len(sub(cs(mesh,fo),sh)); local b=len(sub(cs(mesh,ha),cs(mesh,fo)))
                local d=sub(wr,sh); local c=len(d); if c<1 or c>=a+b then return old end
                local n=mul(d,1/c); local x=(c*c+a*a-b*b)/(2*c); local r=math.sqrt(math.max(0,a*a-x*x))
                local ctr=add(sh,mul(n,x))
                -- scored search round the circle: wrist bend (deg) + 12 per cm of forearm inside a breast sphere (r 10,
                -- forearm r 3.2, 2 cm margin) + a little for an elbow above the shoulder (winged)
                local long=nrm(qrot(q,longL))
                local e1=nrm(sub(up,mul(n,dot(up,n)))); if len(e1)<0.2 then e1=nrm(sub(fwd,mul(n,dot(fwd,n)))) end
                local e2=cross(n,e1)
                local bL=cs(mesh,'Ab-L-Breast'); local bR=cs(mesh,'Ab-R-Breast'); local br={bL,bR} -- (cs returns two values)
                local function segpt(p,s0,s1) local ab=sub(s1,s0); local tt=math.max(0,math.min(1,dot(sub(p,s0),ab)/math.max(dot(ab,ab),1e-6))); return len(sub(p,add(s0,mul(ab,tt)))) end
                local best,bv=math.huge,nil
                for i=0,23 do
                    local ang=i*math.pi/12
                    local v=add(mul(e1,math.cos(ang)),mul(e2,math.sin(ang)))
                    local e=add(ctr,mul(v,r))
                    local bend=math.deg(math.acos(math.max(-1,math.min(1,dot(nrm(sub(wr,e)),long)))))
                    local pen=0
                    for _,bc in ipairs(br) do pen=math.max(pen,(10+3.2+2)-segpt(bc,e,wr)) end
                    local wing=math.max(0,dot(sub(e,sh),up))
                    local score=bend+12*math.max(0,pen)+0.5*wing
                    if score<best then best,bv=score,v end
                end
                if not bv then return old end
                return add(add(ctr,mul(bv,r)),mul(bv,40))
            end
            if not st.longR then local h,hq0=cs(mesh,'Bip001-R-Hand'); st.longR=nrm(qrot(qinv(hq0),sub(cs(mesh,'Bip001-R-Finger2'),h))) end
            poleR=elbow_pole(rsh,'Bip001-R-Forearm','Bip001-R-Hand',hloc,hq,st.longR,poleR)
            poleL=elbow_pole(lsh,'Bip001-L-Forearm','Bip001-L-Hand',lloc,lq,nrm(st.palm),poleL)
        end
        -- one batch of writes
        local ok,e=pcall(function()
            pp.RHandLoc_S2=hloc
            pp.RHandRot_CS=q2rot(hq)
            pp.RElbowPole_S2=poleR
            pp.LHandLoc_RH=lloc
            pp.LHandRot_RH=q2rot(lq)
            pp.LElbowPole_S2=poleL
            pp.ArmsAlpha=1
        end)
        st.alpha=1
        if not ok and not st.err then st.err=true; g.log('ik write: '..tostring(e)) end
        st.last={hloc=hloc,lloc=lloc,hg=hg}
        return st.last
    end
    return self
end

return IK
