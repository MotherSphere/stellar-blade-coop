-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- What gun mode costs a frame, over a fake UE4SS (fake.lua) that counts its engine calls: UE4SS 3.0.1's
-- StaticFindObject and FindAllOf walk the object array. With the rifle away (parked or not) a frame makes no lookup and
-- polls only the toggle keys (M2); out, no /Script object is looked up again, the crosshair is traced only while she
-- aims (M13) and the drone and the reticle's text are walked for only on an event (L1). The posed stance reads no bone
-- name and makes no FName a frame (M13). The dev facts probe still waits out a pause.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Fake=dofile('tests/lua/fight/gunmode/fake.lua')
-- The laser sight needs Niagara's objects, which the fake lacks: here a laser that draws nothing.
package.loaded['fight.gunmode.laser']=function() return function() end,function() end end
local GunMode=require('fight.gunmode.mode')
local Overlay=require('fight.gunmode.overlay')
local clock=100
os.clock=function() return clock end
local function frames(gun,n) for _=1,n do clock=clock+1/60; gun.tick() end end

-- The fake world with its engine calls counted: script (StaticFindObject of a /Script path), asset[path] (the other
-- StaticFindObject calls: assets, kept by mode.lua's g.asset and checked by their path), first (FindFirstOf), all[class] (FindAllOf), keys[name] (IsInputKeyDown),
-- polls (all of them), trace (LineTraceSingle), paused (IsGamePaused). The camera manager and the trace library let the
-- crosshair reach its traces. The layer's clips are found and play.
local function world()
    local w=Fake.new(); w.install()
    local n={script=0,first=0,all={},keys={},polls=0,trace=0,paused=0,asset={}}
    w.n=n
    local statics=w.find('/Script/Engine.Default__GameplayStatics')
    local paused=statics.IsGamePaused
    statics.IsGamePaused=function(...) n.paused=n.paused+1; return paused(...) end
    local find,first,all=StaticFindObject,FindFirstOf,FindAllOf
    StaticFindObject=function(path)
        if path:sub(1,8)=='/Script/' then n.script=n.script+1 else n.asset[path]=(n.asset[path] or 0)+1 end
        return find(path)
    end
    FindFirstOf=function(class) n.first=n.first+1; return first(class) end
    w.drones,w.blocks={},{}
    FindAllOf=function(class)
        n.all[class]=(n.all[class] or 0)+1
        if class=='CH_Drone_BP_C' then return w.drones end
        if class=='TextBlock' then return w.blocks end
        return all(class)
    end
    local down=w.pc.IsInputKeyDown
    function w.pc.IsInputKeyDown(o,k)
        local key=k.KeyName:ToString()
        n.keys[key]=(n.keys[key] or 0)+1
        n.polls=n.polls+1
        return down(o,k)
    end
    local valid=function() return true end
    w.pc.PlayerCameraManager={IsValid=valid,GetCameraLocation=function() return {X=0,Y=0,Z=0} end,
        GetCameraRotation=function() return {Pitch=0,Yaw=0,Roll=0} end,GetFOVAngle=function() return 45 end}
    local trace={IsValid=valid,LineTraceSingle=function() n.trace=n.trace+1; return false end}
    -- Engine classes the fake lacks, which every build has.
    local classes={}
    for _,c in ipairs({'MeshComponent','StaticMeshComponent'}) do
        classes['/Script/Engine.'..c]={IsValid=valid,GetFullName=function() return 'Class /Script/Engine.'..c end}
    end
    local clips={}
    for _,path in pairs(Overlay.CLIPS) do
        clips[path]={IsValid=valid,GetFullName=function() return 'AnimSequence '..path end}
    end
    -- Any other game asset (the muzzle flash, the reload's sounds) is there once loaded, under its own path.
    local assets={}
    local base=w.find
    function w.find(path)
        if path=='/Script/Engine.Default__KismetSystemLibrary' then return trace end
        local o=clips[path] or classes[path] or base(path)
        if o==nil and path:sub(1,6)=='/Game/' then
            assets[path]=assets[path] or {IsValid=valid,GetFullName=function() return 'Object '..path end}
            o=assets[path]
        end
        return o
    end
    return w
end
local function count(w,class) return w.n.all[class] or 0 end
-- The rifle out through the command, with the layer's instance made to play its clips.
local function out(w,gun)
    clock=clock+1
    gun.toggle_now()
    assert(gun.state.on,'the rifle is out')
    local pp=w.mesh.pp
    pp.PlaySlotAnimationAsDynamicMontage=function() return {} end
    pp.IsPlayingSlotAnimation=function() return true end
end

-- 1. M2: the rifle away, parked (no rifle layer) or not, 600 frames: no lookup at all and two key polls a frame (the
--    gun key and D-pad Right), except the HUD entry's look for the HUD (fight/gunmode/ui/dpad.lua): one walk per
--    Dpad.RETRY s while it is not built. The pause is asked at a toggle only: a press while paused does nothing.
for _,parked in ipairs({true,false}) do
    local w=world()
    w.no_layer=parked
    local gun=GunMode.new({log=function() end})
    frames(gun,1)
    w.n.script,w.n.first,w.n.polls,w.n.paused=0,0,0,0
    frames(gun,600)
    local hud=w.n.all.WB_MainHUD_Master_C or 0
    w.n.all.WB_MainHUD_Master_C=nil
    assert(hud<=1,('parked %s: %d HUD walks in 10 s'):format(tostring(parked),hud))
    assert(w.n.script==0 and w.n.first==0 and next(w.n.all)==nil,
        ('parked %s: %d lookups, %d FindFirstOf'):format(tostring(parked),w.n.script,w.n.first))
    assert(w.n.polls==2*600,('parked %s: %d key polls in 600 frames'):format(tostring(parked),w.n.polls))
    assert(w.n.paused==0,('parked %s: the pause asked %d times in 600 frames'):format(tostring(parked),w.n.paused))
    if not parked then
        w.paused=true
        w.down.F4=true; frames(gun,1); w.down.F4=nil; frames(gun,1)
        assert(not gun.state.on,'no toggle while paused')
        w.paused=false
        clock=clock+1
        w.down.F4=true; frames(gun,1); w.down.F4=nil
        assert(gun.state.on,'F4 brings the rifle out')
    end
end

-- 2. M2: no player controller (a map loading): FindFirstOf walks the object array, so once a second at most.
do
    local w=world()
    FindFirstOf=function() w.n.first=w.n.first+1 end
    local gun=GunMode.new({log=function() end})
    frames(gun,600)
    assert(w.n.first<=11,w.n.first..' FindFirstOf in 10 s')
end

-- 3. M2, M13: the rifle out on the layer's path, carried for 600 frames after its arrival (fight/gunmode/morph.lua,
--    whose effect looks up Niagara's library once): no /Script lookup, no trace, no zoom key polled (the game's aim
--    takes RMB / LT itself). Aiming traces the crosshair every frame. Its library is looked up once.
do
    local w=world()
    local gun=GunMode.new({log=function() end})
    out(w,gun)
    frames(gun,60)
    w.n.script,w.n.trace,w.n.keys=0,0,{}
    frames(gun,600)
    assert(w.n.script==0,w.n.script..' /Script lookups in 600 frames')
    assert(w.n.trace==0,w.n.trace..' traces while carried')
    assert(not w.n.keys.LeftAlt and not w.n.keys.LeftControl,'zoom keys polled')
    w.pawn.bTPSMode,w.down.RightMouseButton=true,true
    frames(gun,1) -- The trace library's own lookup, once.
    w.n.script=0
    frames(gun,59)
    assert(w.n.trace==2*60,w.n.trace..' traces in 60 aiming frames')
    assert(w.n.script==0,w.n.script..' /Script lookups while aiming')
    -- Firing for 10 s, through a reload: each asset (the muzzle flash, the reload's sounds) is walked for once at most.
    w.n.asset={}
    w.down.LeftMouseButton=true
    frames(gun,600)
    w.down.LeftMouseButton=nil
    local walked={}
    for path,k in pairs(w.n.asset) do if k>1 then walked[#walked+1]=path..' x'..k end end
    assert(#walked==0,'assets walked for again while firing: '..table.concat(walked,', '))
    local fx=require('fight.gunmode.config').DEFAULTS.muzzle_fx
    assert(w.n.asset[fx]==1,'the muzzle flash looked up '..tostring(w.n.asset[fx])..' times')
end

-- 4. L1: no drone near EVE and no reticle text: each walked for once at the rifle out, not once a second. A rifle out
--    again within 10 s of a miss looks for the drone only once that back-off is over. Firing mode entered twice within
--    10 s walks for the reticle's text once more (a walk costs 60-90 ms in game); entered again after 10 s, once more.
do
    local w=world()
    local gun=GunMode.new({log=function() end})
    out(w,gun)
    frames(gun,60)
    assert(count(w,'CH_Drone_BP_C')==1 and count(w,'TextBlock')==1)
    clock=clock+1; gun.toggle_now()
    assert(not gun.state.on,'the rifle is away')
    out(w,gun)
    frames(gun,1)
    assert(count(w,'CH_Drone_BP_C')==1,'a rifle out within the back-off walks for no drone')
    frames(gun,60*60)
    assert(count(w,'CH_Drone_BP_C')==2,count(w,'CH_Drone_BP_C')..' drone walks in 60 s')
    assert(count(w,'TextBlock')==2,count(w,'TextBlock')..' text walks in 60 s')
    for _=1,2 do
        w.pawn.bTPSMode,w.down.RightMouseButton=true,true
        frames(gun,120)
        w.pawn.bTPSMode,w.down.RightMouseButton=false,nil
        frames(gun,120)
    end
    assert(count(w,'TextBlock')==3,count(w,'TextBlock')..' text walks after two aims 4 s apart')
    frames(gun,60*7)
    w.pawn.bTPSMode,w.down.RightMouseButton=true,true
    frames(gun,120)
    w.pawn.bTPSMode,w.down.RightMouseButton=false,nil
    frames(gun,120)
    assert(count(w,'TextBlock')==4,count(w,'TextBlock')..' text walks after an aim 10 s on')
    assert(count(w,'CH_Drone_BP_C')==2,count(w,'CH_Drone_BP_C')..' drone walks after three aims')
end

-- 5. L1: a drone near EVE is hidden at the rifle out and held: no walk while it lives, one when it goes. The rifle out
--    again finds the same drone without a walk, unless that drone is now far from her.
do
    local w=world()
    local part={IsValid=function() return true end,bHiddenInGame=false,
        SetHiddenInGame=function(o,h) o.bHiddenInGame=h end,SetVisibility=function() end,IsVisible=function() return true end}
    local drone={IsValid=function(o) return not o.dead end,K2_GetActorLocation=function() return {X=100,Y=0,Z=0} end,
        K2_GetComponentsByClass=function() return {part} end,GetFullName=function() return 'CH_Drone_BP_C /Game/Map.Drone_1' end}
    w.drones={drone}
    local gun=GunMode.new({log=function() end})
    out(w,gun)
    assert(part.bHiddenInGame==true,'the drone is hidden')
    frames(gun,60*30)
    assert(count(w,'CH_Drone_BP_C')==1,count(w,'CH_Drone_BP_C')..' drone walks while it lives')
    clock=clock+1; gun.toggle_now()
    frames(gun,120) -- the departure's morph
    assert(not gun.state.on and part.bHiddenInGame==false,'the rifle away, the drone shown')
    out(w,gun)
    frames(gun,60)
    assert(part.bHiddenInGame==true,'the drone hidden again')
    assert(count(w,'CH_Drone_BP_C')==1,count(w,'CH_Drone_BP_C')..' drone walks after the rifle came out again')
    -- the kept drone far away and another one by her: the rifle out walks and hides the near one
    clock=clock+1; gun.toggle_now(); frames(gun,120)
    assert(not gun.state.on,'the rifle away')
    drone.K2_GetActorLocation=function() return {X=9000,Y=0,Z=0} end
    local part2={IsValid=function() return true end,bHiddenInGame=false,
        SetHiddenInGame=function(o,h) o.bHiddenInGame=h end,SetVisibility=function() end,IsVisible=function() return true end}
    local near={IsValid=function() return true end,K2_GetActorLocation=function() return {X=50,Y=0,Z=0} end,
        K2_GetComponentsByClass=function() return {part2} end,GetFullName=function() return 'CH_Drone_BP_C /Game/Map.Drone_2' end}
    w.drones={drone,near}
    out(w,gun)
    frames(gun,60)
    assert(count(w,'CH_Drone_BP_C')==2,count(w,'CH_Drone_BP_C')..' drone walks with the kept drone far away')
    assert(part2.bHiddenInGame==true,'the near drone hidden')
    clock=clock+1; gun.toggle_now(); frames(gun,120)
    out(w,gun)
    frames(gun,60)
    w.drones={}
    drone.dead=true
    frames(gun,60*30)
    assert(count(w,'CH_Drone_BP_C')==2,count(w,'CH_Drone_BP_C')..' drone walks while the near drone lives')
    near.IsValid=function() return false end
    frames(gun,60*30)
    assert(count(w,'CH_Drone_BP_C')==3,count(w,'CH_Drone_BP_C')..' drone walks after it went')
end

-- 6. M13: the posed stance (the fallback without the layer) on a fake whose engine calls give neutral transforms:
--    after its start, a carrying frame and 20 aiming frames read no bone name and make no FName.
do
    local Stance=require('fight.gunmode.stance')
    local n={tostring=0,fname=0}
    local NAME={__index={ToString=function(v) n.tostring=n.tostring+1; return v.text end}}
    FName=function(text) n.fname=n.fname+1; return setmetatable({text=text},NAME) end
    -- A value read as a vector, a rotator, a quaternion and a transform.
    local function xf()
        return {X=0,Y=0,Z=0,W=1,Pitch=0,Yaw=0,Roll=0,Translation={X=0,Y=0,Z=0},Rotation={X=0,Y=0,Z=0,W=1},
            Scale3D={X=1,Y=1,Z=1}}
    end
    local ANSWERS={GetBoneIndex=0,GetNumMaterials=0,IsGamePaused=false,DoesSocketExist=true}
    local function object(t)
        t=t or {}
        t.IsValid=function(o) return not rawget(o,'dead') end
        t.GetAddress=function(o) return o end
        return setmetatable(t,{__index=function(_,k)
            local a=ANSWERS[k]
            if a~=nil then return function() return a end end
            return function() return xf() end
        end})
    end
    local function owner(t)
        t=object(t)
        t.AddComponentByClass=function() return object() end
        return t
    end
    local world=object({SpawnActor=function() return owner() end})
    StaticFindObject=function() return object() end
    LoadAsset=function() return object() end
    local src=object({SkeletalMesh=object(),LightingChannels={},CastShadow=true,bOwnerNoSee=false,
        VisibilityBasedAnimTickOption=0})
    local pawn=owner({TPSModeType=0,bTPSMode=false,Mesh=src,GetWorld=function() return world end})
    local pc=object({Pawn=pawn,PlayerCameraManager=object()})
    local held=false
    local stance=Stance.new(function() return function() end,function() end end)
    -- As fight/gunmode/mode.lua starts it with gun_fire=native: no turn, no torso, no camera anchor or chest fix, her
    -- normal stance's spine while aiming.
    stance.start(pc,function() return held end,function() return nil end,function() return false end,0,false,false,
        false,true)
    for _=1,3 do stance.frame() end
    assert(stance.running(),'the posed stance runs')
    n.tostring,n.fname=0,0
    stance.frame()
    assert(n.tostring==0 and n.fname==0,('a carrying frame: %d ToString, %d FName'):format(n.tostring,n.fname))
    held=true
    for _=1,20 do stance.frame() end
    assert(n.tostring==0 and n.fname==0,('20 aiming frames: %d ToString, %d FName'):format(n.tostring,n.fname))
    stance.stop()
end

-- 7. M2: the rifle-first solver (ik.lua, each frame on the layer's path) takes KismetMathLibrary from gun mode's g.find
--    (looked up once while it lives), with no StaticFindObject of its own. Its engine calls answer neutral values.
do
    local IK=require('fight.gunmode.ik')
    local function neutral(t)
        return setmetatable(t or {},{__index=function(_,k)
            if k=='IsValid' then return function() return true end end
            return function() return {X=0,Y=0,Z=0,Pitch=0,Yaw=0,Roll=0,Translation={X=0,Y=0,Z=0},
                Rotation={X=0,Y=0,Z=0,W=1}} end
        end})
    end
    local ml,walks=neutral(),0
    StaticFindObject=function() walks=walks+1; return ml end
    local g={log=function() end,try=function(fn) local ok,r=pcall(fn); if ok then return r end end,
        find=function(path) assert(path=='/Script/Engine.Default__KismetMathLibrary',path); return ml end}
    local ik=IK.new(g)
    local pawn,pc=neutral({Mesh=neutral()}),neutral({PlayerCameraManager=neutral()})
    for i=1,60 do assert(ik.tick(pc,pawn,neutral(),i%2==0 and 'aim' or 'carry',neutral()),'the solver ran') end
    assert(walks==0,walks..' lookups of its own in 60 frames')
end

-- 8. The facts probe (gun_facts=on, dev only) waits while the game is paused, the rifle away too, as before the pause
--    was asked only at a toggle.
do
    local ticks=0
    package.loaded['fight.gunmode.facts']={new=function() return {tick=function() ticks=ticks+1 end} end}
    local w=world()
    local gun=GunMode.new({log=function() end,settings=require('core.link').parse_settings('gun_facts=on')})
    w.paused=true
    frames(gun,60)
    assert(ticks==0,ticks..' facts ticks while paused')
    w.paused=false
    frames(gun,60)
    assert(ticks==60,ticks..' facts ticks in 60 frames')
    package.loaded['fight.gunmode.facts']=nil
end

print('gunmode cost: ok')
