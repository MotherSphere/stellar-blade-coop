-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode (11-18 rebuild): the NIKKE rifle in EVE's real right hand, nothing else. Her body is never copied or posed:
-- while the rifle is out the animation pak's rifle set plays on her real body through the game's own animation
-- blueprint (fight/gunmode/data.lua points her animation sets' blend spaces and aim offset at it), so she carries, runs,
-- strafes and aims with the rifle in her hands and her left hand on it, on one skeleton, for her and for co-op partners.
-- Same interface as fight/gunmode/stance.lua (start, frame, stop, running, reload, owns, copy, body) so fight/gunmode/mode.lua
-- drives it unchanged.
local U=require('core.unreal')
local Rifle={}
local function isv(o) return o:IsValid() end
local function valid(o) if o==nil then return false end local ok,r=pcall(isv,o); return ok and r==true end
-- The rifle component's tag, so the next Lua load finds a rifle this one left on her (sweep).
Rifle.TAG='SBO_Gun'

-- The grip: the rifle in her right hand (Bip001-R-Hand) as the pak's animations were made with it (Blender
-- ngm_bl_rifle1: the NIKKE shot's grip, the barrel through her support hand). UE units (cm), the bone's frame.
Rifle.GRIP={Translation={X=-1.17,Y=-5.68,Z=2.09},Rotation={X=0.3426,Y=0.5891,Z=0.4513,W=0.5761},Scale3D={X=1,Y=1,Z=1}}
-- The grips of the authored v4 poses (NikkeGunBuild\poses\<Pose>\pose.json, rifle relative to Bip001-R-Hand, UE).
-- Each layer clip needs the grip it was posed with; the reload clip is SB's, made with GRIP.
local function grip(tx,ty,tz,qx,qy,qz,qw) return {Translation={X=tx,Y=ty,Z=tz},Rotation={X=qx,Y=qy,Z=qz,W=qw},Scale3D={X=1,Y=1,Z=1}} end
Rifle.GRIPS={
    aim=grip(-1.92,-4.57,4.10, 0.5752,0.3591,0.4710,0.5642),   -- AimLevel round 4
    carry=grip(-1.83,-6.80,3.16, 0.3045,0.4069,0.6102,0.6078), -- CarryLowReady rd4
}
Rifle.GRIPS.reload=Rifle.GRIPS.carry -- the reload plays the carry pose (fight/gunmode/overlay.lua)
-- the aim-up and aim-down clips give her head and shoulders only: the rifle stays placed as in AimLevel (fight/gunmode/ik.lua)
Rifle.GRIPS.aimup=Rifle.GRIPS.aim
Rifle.GRIPS.aimdown=Rifle.GRIPS.aim
-- In aim: TURN_MAX, the most the rifle turns in her hands onto the reticle's line (degrees). EASE_IN: that turn's
-- ease-in (s).
Rifle.TURN_MAX,Rifle.EASE_IN=6,0.15
local function qmul(a,b) return require('fight.gunmode.ik').math.qmul(a,b) end

-- laser: fight/gunmode/laser.lua's function (pawn, rifle, mathlib) -> beam(target), finish().
function Rifle.new(laser,trace,grip)
    local function crumb(t) if trace then trace('crumb '..t) end end
    local self={single=true}
    local st -- the running state: {pawn, src, gun, held, target, beam, finish, reload...}
    local mathlib=StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
    local GRIP=grip or Rifle.GRIP
    -- The grip sent while it eases from the last clip's grip toward GRIP (nil once there): the IK eases her hands
    -- toward the new clip at pin_blend (fight/gunmode/ik.lua), so the grip does too and the rifle never jumps.
    local eased,eased_at

    function self.start(pc,held_fn,beam_target)
        assert(valid(pc) and valid(pc.Pawn),'Load a campaign save first')
        local pawn=pc.Pawn
        local src=pawn.Mesh
        assert(valid(src),'no body mesh')
        local weapon=assert(LoadAsset('/Game/DLC_2/Art/Character/Weapon/Gun/CH_G_Nikke_01/GunNikke_Weapon.GunNikke_Weapon'))
        local id={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
        local gun=pawn:AddComponentByClass(StaticFindObject('/Script/Engine.SkeletalMeshComponent'),true,id,true)
        assert(valid(gun),'rifle component')
        gun:SetCollisionEnabled(0)
        pawn:FinishAddComponent(gun,true,id)
        -- A new component's ComponentTags is empty: UE4SS 3.0.1 lands a write at 1 there (vehicles/bike/ride.lua's
        -- part; proven for uint8 arrays only). A tag that does not hold costs only the sweep after a Ctrl+R.
        pcall(function() gun.ComponentTags[1]=FName(Rifle.TAG) end)
        gun:SetSkeletalMesh(weapon,true)
        pcall(function() gun.bPerBoneMotionBlur=false end)
        pcall(function() gun:SetCastShadow(src.CastShadow) end)
        pcall(function() local ch=src.LightingChannels; gun:SetLightingChannels(ch.bChannel0,ch.bChannel1,ch.bChannel2) end)
        gun:K2_AttachToComponent(src,FName('Bip001-R-Hand'),2,2,2,false)
        gun:K2_SetRelativeTransform(GRIP,false,{},true)
        gun:SetVisibility(true,false)
        st={pc=pc,pawn=pawn,addr=pawn:GetAddress(),src=src,gun=gun,held=held_fn,target=beam_target,aimAt=nil,reloading=false,reloadAt=0,reloadLen=1}
        return gun
    end

    function self.stop()
        if not st then return end
        if st.finish then pcall(st.finish) end
        if valid(st.gun) then pcall(function() st.gun:K2_DestroyComponent(st.gun) end) end
        st=nil
    end
    function self.running() return st~=nil end
    -- the morph (fight/gunmode/morph.lua through mode.lua): the rifle's scale k and an extra spin (deg about its up axis);
    -- nil puts it back to normal. While k<1 the laser stays off.
    function self.morph(k,spin) if st then st.mk,st.mspin=k,spin end end
    -- the grip of the clip on the layer (Rifle.GRIPS name); unknown names keep the current grip
    function self.grip(name)
        local G=Rifle.GRIPS[name]
        if not G or G==GRIP then return end
        local f=eased or GRIP
        eased={Translation={X=f.Translation.X,Y=f.Translation.Y,Z=f.Translation.Z},
            Rotation={X=f.Rotation.X,Y=f.Rotation.Y,Z=f.Rotation.Z,W=f.Rotation.W},Scale3D={X=1,Y=1,Z=1}}
        GRIP=G
        -- The IK has eased her hands one step toward the new clip this tick: the grip takes its first step now too.
        eased_at=st and st.before or os.clock() -- (the frame before this tick's: one tick's step, as the IK's)
        if st and valid(st.gun) then pcall(self.send,st.gun,os.clock()) end
    end
    -- eased one step toward GRIP (lerp, and the short-way nlerp for the rotation); nil once there
    local function ease(now)
        local k=1-math.exp(-math.max(0,now-eased_at)/require('fight.gunmode.ik').CFG.pin_blend); eased_at=now
        local a,b=eased.Translation,GRIP.Translation
        a.X,a.Y,a.Z=a.X+(b.X-a.X)*k,a.Y+(b.Y-a.Y)*k,a.Z+(b.Z-a.Z)*k
        local q,t=eased.Rotation,GRIP.Rotation
        local s=(q.X*t.X+q.Y*t.Y+q.Z*t.Z+q.W*t.W)<0 and -1 or 1
        local x,y,z,w=q.X+(s*t.X-q.X)*k,q.Y+(s*t.Y-q.Y)*k,q.Z+(s*t.Z-q.Z)*k,q.W+(s*t.W-q.W)*k
        local l=math.sqrt(x*x+y*y+z*z+w*w); q.X,q.Y,q.Z,q.W=x/l,y/l,z/l,w/l
        if math.abs(q.X*t.X+q.Y*t.Y+q.Z*t.Z+q.W*t.W)>0.9999999 and math.abs(a.X-b.X)+math.abs(a.Y-b.Y)+math.abs(a.Z-b.Z)<1e-3 then eased=nil end
    end

    -- The rifle on her hand at the grip (eased), with the morph's scale and spin.
    function self.send(gun,now)
        if eased then ease(now) end
        st.before,st.at=st.at,now
        local G,mk=eased or GRIP,st.mk
        if mk then
            -- a fresh transform each frame: GRIP tables are shared between clips and must never be scaled in place
            gun:K2_SetRelativeTransform({Translation=G.Translation,Rotation=G.Rotation,Scale3D={X=mk,Y=mk,Z=mk}},false,{},true)
            if st.mspin and st.mspin~=0 then gun:K2_AddLocalRotation({Pitch=0,Yaw=st.mspin,Roll=0},false,{},true) end
        else
            gun:K2_SetRelativeTransform(G,false,{},true)
        end
    end
    function self.owns(c) return st~=nil and valid(c) and valid(st.gun) and c:GetAddress()==st.gun:GetAddress() end
    function self.copy() return true end
    function self.body() return nil end

    -- The reload: a quick tilt of the rifle in her hands while the reload runs (sounds and timing are fight/gunmode/mode.lua's).
    function self.reload(on,duration)
        if not st then return false end
        if on then st.reloading,st.reloadAt,st.reloadLen=true,os.clock(),(duration and duration>0) and duration or 1
        else st.reloading=false end
        return true
    end

    function self.frame()
        if not st then return end
        local pc,pawn,gun=st.pc,st.pawn,st.gun
        local cur=valid(pc) and pc.Pawn
        if not valid(pawn) or not valid(gun) or not valid(cur) or cur:GetAddress()~=st.addr then self.stop(); return end
        -- (paused: fight/gunmode/mode.lua's tick returns before any call of frame, its own and facts.lua's)
        local mk=st.mk
        local now=os.clock()
        self.send(gun,now)
        local held=st.held() and not self.no_laser and not (mk and mk<1) -- (no laser while the morph runs)
        if st.reloading then
            local k=math.max(0,math.min(1,(now-st.reloadAt)/st.reloadLen))
            local w=math.sin(math.pi*k)
            gun:K2_AddLocalRotation({Pitch=-14*w,Yaw=6*w,Roll=40*w},false,{},true)
        end
        if held then
            if not st.aimAt then st.aimAt=now; crumb('aim') end
            local t=st.target()
            -- the barrel on the line to where the rounds go (the reticle's point), every frame: the rifle turned in her
            -- hands by the whole error up to Rifle.TURN_MAX degrees (the aim and its chest loop hold it within that;
            -- this takes up the rest). The turn eases in over the aim's first Rifle.EASE_IN s and fades out between 19
            -- and 25 degrees of error. It stopped dead past 6 degrees: the rifle jumped whenever the error crossed it.
            local onTarget=false
            if t and not st.reloading and not self.no_turn then pcall(function()
                st.fire=st.fire or FName('FX_Fire') -- made once per rifle, not each frame
                local fire=st.fire
                local m=gun:GetSocketLocation(fire)
                local have=mathlib:GetForwardVector(gun:GetSocketRotation(fire))
                local dx,dy,dz=t.X-m.X,t.Y-m.Y,t.Z-m.Z
                local len=math.sqrt(dx*dx+dy*dy+dz*dz)
                if len<80 then return end
                local want={X=dx/len,Y=dy/len,Z=dz/len}
                local dot=have.X*want.X+have.Y*want.Y+have.Z*want.Z
                local err=math.deg(math.acos(math.max(-1,math.min(1,dot))))
                if err>=25 then return end
                onTarget=true
                local a=math.rad(math.min(err,Rifle.TURN_MAX))*math.min(1,(now-st.aimAt)/Rifle.EASE_IN)*math.min(1,(25-err)/6)
                -- the turn about have x want in the world frame, put before the rifle's own rotation
                local cx,cy,cz=have.Y*want.Z-have.Z*want.Y,have.Z*want.X-have.X*want.Z,have.X*want.Y-have.Y*want.X
                local cl=math.sqrt(cx*cx+cy*cy+cz*cz)
                if a<1e-5 or cl<1e-9 then return end
                local k=math.sin(a/2)/cl
                local gt=gun:K2_GetComponentToWorld()
                local r=gt.Rotation
                local q=qmul({cx*k,cy*k,cz*k,math.cos(a/2)},{r.X,r.Y,r.Z,r.W})
                gt.Rotation={X=q[1],Y=q[2],Z=q[3],W=q[4]}
                gun:K2_SetWorldTransform(gt,false,{},true)
            end) end
            -- the laser once the rifle is up (the aim blends in over ~0.2 s), then it stays on until aim is let go
            if st.beam or (onTarget and now-st.aimAt>=0.12) or now-st.aimAt>=0.6 then
                if not st.beam then st.beam,st.finish=laser(pawn,gun,mathlib); crumb('laser on') end
                st.beam(t) -- Each frame: beam to the muzzle; no target (the flip): trace along the barrel (laser.lua).
            end
        else
            if st.aimAt then st.aimAt=nil; crumb('aim off') end
            if st.finish then pcall(st.finish); st.beam,st.finish=nil,nil; crumb('laser off') end
        end
    end
    return self
end

-- The rifles an earlier Lua load left on her pawn (components tagged Rifle.TAG: the rifle, the laser's holder and
-- beam, fight/gunmode/laser.lua), destroyed: how many.
function Rifle.sweep(pawn)
    if not valid(pawn) then return 0 end
    local n,tag=0,FName(Rifle.TAG)
    U.each(pawn:K2_GetComponentsByClass(StaticFindObject('/Script/Engine.SceneComponent')),function(_,c)
        if valid(c) and c:ComponentHasTag(tag)==true then c:K2_DestroyComponent(c); n=n+1 end
    end)
    return n
end
return Rifle
