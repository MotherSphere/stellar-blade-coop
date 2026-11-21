-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Where the rounds go. The round's destination is written in EVE's root frame with its pitch and roll, as SB places it
-- (Base and RootAxis). Firing mode writes it every frame from that frame's camera: a round that spawns in any frame
-- leaves for that frame's reticle point (it was written ten times a second). The spread keeps each round within
-- gun_spread degrees of the reticle point, seen from the camera; gun_spread=0 puts every round on it.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Aim=require('fight.gunmode.aim')
local close=function(a,b,e) return math.abs(a-b)<=(e or 1e-6) end

-- 1. The root frame with pitch and roll: world_point gives local_offset back; a pitch of 90 makes up her forward.
do
    local loc,rot={X=100,Y=-50,Z=20},{Pitch=30,Yaw=-40,Roll=15}
    local t={X=900,Y=300,Z=-120}
    local x,y,z=Aim.local_offset(t,loc,rot)
    local w=Aim.world_point(x,y,z,loc,rot)
    assert(close(w.X,t.X,1e-6) and close(w.Y,t.Y,1e-6) and close(w.Z,t.Z,1e-6),'round trip')
    local f,r,u=Aim.local_offset({X=0,Y=0,Z=100},{X=0,Y=0,Z=0},{Pitch=90,Yaw=0,Roll=0})
    assert(close(f,100) and close(r,0) and close(u,0),'pitched frame')
    f,r,u=Aim.local_offset({X=0,Y=100,Z=0},{X=0,Y=0,Z=0},{Pitch=0,Yaw=0,Roll=90})
    assert(close(f,0) and close(r,0) and close(u,100),'rolled frame') -- (UE's roll: her right side goes down)
end

-- 2. The spread: within deg of the line from the camera, every way round; 0 gives the point itself.
do
    local cam,t={X=0,Y=0,Z=0},{X=2000,Y=500,Z=300}
    assert(Aim.spread(t,cam,0,0.5,0.5)==t)
    local most=0
    for i=0,20 do for j=0,20 do
        local p=Aim.spread(t,cam,0.5,i/20,j/20)
        most=math.max(most,Aim.apart(p,t,cam))
    end end
    assert(most<=0.5+1e-9 and most>0.49,'spread reaches '..most)
    local up=Aim.spread({X=0,Y=0,Z=1000},cam,1,1,0.25) -- straight up
    assert(close(Aim.apart(up,{X=0,Y=0,Z=1000},cam),1,1e-6))
end

-- 3. Firing mode on the fake world: the row's destination is this frame's crosshair point, every frame.
local Fake=dofile('tests/lua/fight/gunmode/fake.lua')
package.loaded['fight.gunmode.laser']=function() return function() end,function() end end
local GunMode=require('fight.gunmode.mode')
local Overlay=require('fight.gunmode.overlay')
local clock=100
os.clock=function() return clock end
local function world()
    local w=Fake.new(); w.install()
    local valid=function() return true end
    w.cam={Pitch=-5,Yaw=0,Roll=0}
    w.pc.PlayerCameraManager={IsValid=valid,GetCameraLocation=function() return {X=-300,Y=40,Z=160} end,
        GetCameraRotation=function() return {Pitch=w.cam.Pitch,Yaw=w.cam.Yaw,Roll=0} end,GetFOVAngle=function() return 45 end}
    w.pawn.K2_GetActorRotation=function() return {Pitch=0,Yaw=w.cam.Yaw*0.5,Roll=0} end
    local trace={IsValid=valid,LineTraceSingle=function() return false end}
    local clips,assets={},{}
    for _,path in pairs(Overlay.CLIPS) do clips[path]={IsValid=valid,GetFullName=function() return 'AnimSequence '..path end} end
    local base=w.find
    function w.find(path)
        if path=='/Script/Engine.Default__KismetSystemLibrary' then return trace end
        if path=='/Script/Engine.Default__KismetMathLibrary' then return nil end
        local o=clips[path] or base(path)
        if o==nil and path:sub(1,6)=='/Game/' then
            assets[path]=assets[path] or {IsValid=valid,GetFullName=function() return 'Object '..path end}
            o=assets[path]
        end
        return o
    end
    return w
end
for _,spread in ipairs({0,0.5}) do
    local w=world()
    local logs={}
    local gun=GunMode.new({log=function(l) logs[#logs+1]=l end,
        settings=require('core.link').parse_settings('gun_spread='..spread..'\n')})
    clock=clock+1
    gun.toggle_now()
    assert(gun.state.on,'the rifle is out')
    w.mesh.pp.PlaySlotAnimationAsDynamicMontage=function() return {} end
    w.mesh.pp.IsPlayingSlotAnimation=function() return true end
    for _=1,60 do clock=clock+1/60; gun.tick() end
    w.pawn.bTPSMode,w.down.RightMouseButton=true,true
    local row=w.tables.ProjectileTable.P_Eve_GunNikke_ShootSlug1_Projectile1
    local range=require('fight.gunmode.config').DEFAULTS.trace_range
    local most=0
    for i=1,30 do
        w.cam.Yaw=i*1.5 -- the camera turns a little every frame
        clock=clock+1/60; gun.tick()
        -- this frame's crosshair point: the camera's line out to the trace's range (nothing hit)
        local cl=w.pc.PlayerCameraManager:GetCameraLocation()
        local want=Aim.world_point(range,0,0,cl,w.pc.PlayerCameraManager:GetCameraRotation())
        local d=row.DestTargetRelativeLocation
        local got=Aim.world_point(d.X,d.Y,d.Z,{X=0,Y=0,Z=0},w.pawn:K2_GetActorRotation())
        local off=Aim.apart(got,want,cl)
        most=math.max(most,off)
        if spread==0 then assert(off<1e-3,('frame %d: the destination is %.2f deg off this frame\'s reticle point'):format(i,off)) end
    end
    if spread>0 then assert(most<=spread+1e-6 and most>0,'spread '..most) end
    -- The game's montage on her while she fires is named in the log once (what bends her as she fires).
    local montage={IsValid=function() return true end,GetFName=function() return {ToString=function() return 'Test_Shot_Montage' end} end}
    w.mesh.GetAnimInstance=function() return {GetCurrentActiveMontage=function() return montage end,
        Montage_IsPlaying=function() return true end} end
    w.down.LeftMouseButton=true
    for _=1,30 do clock=clock+1/60; gun.tick() end
    w.down.LeftMouseButton=nil
    local named=0
    for _,l in ipairs(logs) do if l:find('layer: montage Test_Shot_Montage while firing',1,true) then named=named+1 end end
    assert(named==1,'montage named '..named..' times')
    w.mesh.GetAnimInstance=nil
    assert(row.DestTargetUpdate==0,'the destination is placed at the spawn only')
    w.pawn.bTPSMode,w.down.RightMouseButton=false,nil
    for _=1,10 do clock=clock+1/60; gun.tick() end
    clock=clock+1; gun.toggle_now()
    for _=1,60 do clock=clock+1/60; gun.tick() end
    assert(not gun.state.on and row.DestTargetUpdate==1,'put back')
end
print('gunmode aim_test ok')
