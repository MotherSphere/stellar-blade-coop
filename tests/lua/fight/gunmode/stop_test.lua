-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode put back over a fake UE4SS (fake.lua), on the rifle layer's path: a start that fails gives back what it
-- took; stop (coop off) gives back the input mask, SB's rows, the rifle, her body's own post-process class and the FOV
-- lock, then nothing more runs; a new controller drops the old pawn's state and its deferred reset gives back the rest.
-- The cases are stop_test's of 5492c007 fitted to luke's gun mode. Its coop-gun.txt cases are left out: no
-- journal is kept.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Fake=dofile('tests/lua/fight/gunmode/fake.lua')
-- The laser sight needs Niagara's objects, which the fake lacks: here a laser that draws nothing.
package.loaded['fight.gunmode.laser']=function() return function() end,function() end end
local GunMode=require('fight.gunmode.mode')
local clock=100
os.clock=function() return clock end
-- settings: coop-settings.txt's text, read through env.read_all. fail: a log line that raises once when it starts with
-- this text (an unexpected raise inside a start).
local function new(settings,fail)
    local logs={}
    local gun=GunMode.new({log=function(m)
            logs[#logs+1]=m
            if fail and m:sub(1,#fail)==fail then fail=nil; error('test raise',0) end
        end,folder=settings and 'Test',read_all=function() return settings end})
    return gun,logs
end
local function said(logs,text)
    for _,l in ipairs(logs) do if l:find(text,1,true) then return true end end
    return false
end
-- Everything as before the rifle came out.
local function as_shipped(w,keys)
    assert(#w.changed()==0,table.concat(w.changed(),'; '))
    assert(w.keys()==keys,w.keys())
    assert(#w.rifles()==0,'no rifle on her')
    assert(w.body.PostProcessAnimBlueprint==w.own_class,'her body\'s own post-process class')
    assert(w.mesh.pp.cls==w.own_class,'her body runs it again')
end

-- 1. A start that fails after the rows are taken gives back the rows, the layer and the mask (67ea7e8c L2).
do
    local w=Fake.new(); w.install()
    local keys=w.keys()
    w.no_settings=true -- the input mask fails
    local gun,logs=new()
    clock=clock+1; gun.toggle_now()
    assert(not gun.state.on and said(logs,'off: the input mask failed'),table.concat(logs,'|'))
    as_shipped(w,keys)
    w.no_settings,w.no_rifle=false,true -- the rifle's stance fails
    clock=clock+1; gun.toggle_now()
    assert(not gun.state.on and said(logs,'off: Luke\'s stance did not start'),table.concat(logs,'|'))
    as_shipped(w,keys)
end

-- 2. An unexpected raise inside a start, once the rifle layer is on: the start gives back what it took, then raises
--    again (67ea7e8c L2).
do
    local w=Fake.new(); w.install()
    local keys=w.keys()
    local gun,logs=new(nil,'rifle layer on')
    clock=clock+1
    local ok,e=pcall(gun.toggle_now)
    assert(not ok and e=='test raise',tostring(e))
    assert(not gun.state.on and said(logs,'off: the start failed'),table.concat(logs,'|'))
    as_shipped(w,keys)
end

-- 3. stop (coop off) with the rifle out puts everything back at once, also within 0.3 s of the press that brought it
--    out. The HUD entry comes off SB's HUD. Then nothing of gun mode runs: no key, no toggle, no reset (67ea7e8c H3).
do
    local w=Fake.new(); w.install()
    local keys=w.keys()
    local gun,logs=new()
    clock=clock+1; gun.toggle_now()
    assert(gun.state.on and #w.changed()>0 and w.keys()~=keys and #w.rifles()==1
        and w.body.PostProcessAnimBlueprint==w.layer_class,'the rifle out')
    local hidden=false
    gun.state.dpad={tick=function() end,crosshair=function() end,hide=function() hidden=true end}
    gun.state.fov,gun.state.fov_locked=50,true
    clock=clock+0.1
    gun.stop('coop off')
    as_shipped(w,keys)
    assert(w.fovs[#w.fovs]==0,'the FOV lock off')
    assert(hidden,'the HUD entry taken off')
    assert(said(logs,'stopped (coop off)'),table.concat(logs,'|'))
    local function still()
        assert(not gun.state.on and #w.rifles()==0 and w.keys()==keys and #w.changed()==0)
    end
    w.down.G=true -- gun_key's default
    for _=1,10 do clock=clock+0.1; gun.tick() end
    w.down.G=nil
    still()
    clock=clock+1; gun.toggle_now()
    still()
    local held={}
    gun.state.pose_m=held
    gun.new_controller(w.pc)
    assert(gun.state.pose_m==held and not gun.state.give_back,'no reset after stop')
    clock=clock+5; gun.tick()
    still()
end

-- 4. gun_fire=own keeps SB's rows after the rifle goes away (until a new world). stop gives them back (67ea7e8c H3).
do
    local w=Fake.new(); w.install()
    local keys=w.keys()
    local gun=new('gun_fire=own\n')
    clock=clock+1; gun.toggle_now()
    clock=clock+1; gun.toggle_now()
    for _=1,60 do clock=clock+1/60; gun.tick() end
    assert(not gun.state.on and #w.changed()>0,'rows kept')
    gun.stop('coop off')
    as_shipped(w,keys)
end

-- 5. stop while a new controller's reset waits (a map load with the rifle out, the next tick not run yet): the layer
--    comes off her new body at once (67ea7e8c H3).
do
    local w=Fake.new(); w.install()
    local keys=w.keys()
    local gun=new()
    clock=clock+1; gun.toggle_now()
    local p2=w.new_pawn()
    gun.new_controller(w.pc)
    assert(p2.Mesh.pp.cls==w.layer_class,'her new body has the layer until the reset')
    gun.stop('coop off')
    w.mesh=p2.Mesh
    as_shipped(w,keys)
end

-- 6. A new controller (a map load: a new EVE on the same body mesh) resets the old pawn's state at once. The deferred
--    reset gives back the rows, shows the drone, puts her facing back, drops the morph's cube and takes the layer off
--    her new body (67ea7e8c L3).
do
    local w=Fake.new(); w.install()
    local keys=w.keys()
    local gun=new()
    clock=clock+1; gun.toggle_now()
    local s=gun.state
    local part=w.component(w.pawn); part.bHiddenInGame=true
    local move={IsValid=function() return true end,
        GetFullName=function() return 'CharacterMovementComponent Old.Move' end,
        bOrientRotationToMovement=false,bUseControllerDesiredRotation=true}
    local cube=w.component(w.pawn)
    s.drone={actor=w.pawn,parts={{c=part,at=part.full:match('^%S+ (.+)$'),hidden=false,visible=true}}}
    s.facing={cm=move,orient=true,desired=false,at='Old.Move'}
    s.ovr,s.ovr_row,s.flash_fx,s.pose_m,s.cube=true,'N_Test_Dead',{},{},cube
    local p2=w.new_pawn()
    gun.new_controller(w.pc)
    assert(not s.on and not s.ovr and s.ovr_row==nil and s.flash_fx==nil and s.pose_m==nil and not s.layer)
    assert(w.keys()==keys,'the mask off at once')
    assert(p2.Mesh.pp.cls==w.layer_class,'her new body still has the layer until the deferred reset')
    clock=clock+5; gun.tick()
    w.mesh=p2.Mesh
    as_shipped(w,keys)
    assert(part.bHiddenInGame==false and s.drone==nil,'the drone shown')
    assert(move.bOrientRotationToMovement==true and move.bUseControllerDesiredRotation==false and s.facing==nil)
    assert(cube.dead and s.cube==nil,'the morph\'s cube destroyed')
    clock=clock+1; gun.toggle_now()
    assert(#w.rifles()==1)
end

-- 7. Her facing flags go back only to the movement they were taken from. A map change frees it. Another object can
--    then sit at its address and pass IsValid, so its path is checked before the write (2702a557).
do
    local w=Fake.new(); w.install()
    local gun=new('gun_fire=own\n')
    local function frames(n) for _=1,n do clock=clock+1/60; gun.tick() end end
    clock=clock+1; gun.toggle_now()
    frames(60)
    w.down.RightMouseButton=true
    frames(10)
    local move=w.pawn.CharacterMovement
    assert(move.bOrientRotationToMovement==false and move.bUseControllerDesiredRotation==true,'facing the camera')
    move.full='SkeletalMeshComponent Test.Other'
    move.bOrientRotationToMovement,move.bUseControllerDesiredRotation='other','other'
    w.down.RightMouseButton=nil
    clock=clock+1; gun.toggle_now(); frames(120)
    assert(not gun.state.on and gun.state.facing==nil,'the rifle away, no facing kept')
    assert(move.bOrientRotationToMovement=='other' and move.bUseControllerDesiredRotation=='other',
        'the facing flags written to another object')
end

-- 8. A new map ends the comeback after an interaction: the rifle away for a talk, then a map load (29e92c98).
do
    local w=Fake.new(); w.install()
    local gun=new()
    local function frames(n) for _=1,n do clock=clock+1/60; gun.tick() end end
    clock=clock+1; gun.toggle_now(); frames(60)
    w.pawn.talk=true; frames(12)
    assert(not gun.state.on and gun.state.resume,'away for the talk, its comeback set')
    w.new_pawn(); gun.new_controller(w.pc)
    frames(60*6)
    assert(not gun.state.on,'a new map ends the comeback')
end

-- 9. The drone's parts go back only while their paths still name them. A new controller's deferred reset comes after
--    a map load: another component can then sit at a part's freed address and pass IsValid.
do
    local w=Fake.new(); w.install()
    local _,part=w.drone()
    local gun=new()
    clock=clock+1; gun.toggle_now()
    assert(gun.state.on and part.bHiddenInGame==true,'the drone hidden')
    w.new_pawn(); gun.new_controller(w.pc)
    part.full='SkeletalMeshComponent Test.Other_Actor.Part'
    local writes,hide=0,part.SetHiddenInGame
    part.SetHiddenInGame=function(o,h) writes=writes+1; hide(o,h) end
    clock=clock+5; gun.tick()
    assert(writes==0 and gun.state.drone==nil,'no write to another component at the old address')
end

-- 10. An unexpected raise in the comeback after an interaction, once the rifle layer is on: the start gives back what
--     it took and the log names the raise. In luke's tick it reached the frame loop's error line (67ea7e8c L2).
do
    local w=Fake.new(); w.install()
    local keys=w.keys()
    local logs,armed={},false
    local gun=GunMode.new({log=function(m)
        logs[#logs+1]=m
        if armed and m:sub(1,14)=='rifle layer on' then armed=false; error('test raise',0) end
    end})
    local function frames(n) for _=1,n do clock=clock+1/60; gun.tick() end end
    clock=clock+1; gun.toggle_now(); frames(60)
    w.pawn.talk=true; frames(12)
    assert(not gun.state.on and gun.state.resume,'away for the talk, its comeback set')
    w.pawn.talk=false
    armed=true
    frames(70)
    assert(not armed and not gun.state.on,'the comeback raised')
    assert(said(logs,'off: the comeback failed (test raise)'),table.concat(logs,'|'))
    as_shipped(w,keys)
end

print('gunmode stop: ok')
