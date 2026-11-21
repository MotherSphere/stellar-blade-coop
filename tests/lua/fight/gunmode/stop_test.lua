-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode put back over a fake UE4SS (fake.lua), on the rifle layer's path unless a case says otherwise: stop
-- (coop off) gives back the input mask, SB's rows, the rifle, her body's own post-process class, the FOV lock and the
-- layer's arms, then nothing more runs; the next Lua load puts back what coop-gun.txt says an earlier one left, also
-- on the posed stance and the rifle clips' path (the park lets them run when the layer's class is found but its
-- install fails); a start that fails gives back what it took; a new controller resets the old pawn's state and the
-- deferred reset takes the layer off her body. fake.lua's rows have the kinds of 26123051's: the Hit1 step's Type is a
-- byte, kept in coop-gun.txt as a number.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Fake=dofile('tests/lua/fight/gunmode/fake.lua')
-- The laser sight needs Niagara's objects, which the fake lacks: here a laser that draws nothing.
package.loaded['fight.gunmode.laser']=function() return function() end,function() end end
local GunMode=require('fight.gunmode.mode')
local clock=100
os.clock=function() return clock end
-- coop-gun.txt in memory, as core/link.lua's store gives it: one line.
local function file()
    local f={}
    return {save=function(text) f.text=text; return true end,load=function() return f.text end,
        clear=function() f.text=nil end,peek=function() return f.text end}
end
-- settings: coop-settings.txt's text, read as main.lua reads it (core/link.lua's parse_settings). fail: a log line that
-- raises once when it starts with this text (an unexpected raise inside a start).
local function new(store,settings,fail)
    local logs={}
    local gun=GunMode.new({log=function(m)
            logs[#logs+1]=m
            if fail and m:sub(1,#fail)==fail then fail=nil; error('test raise',0) end
        end,store=store,settings=settings and require('core.link').parse_settings(settings)})
    return gun,logs
end
local function said(logs,text)
    for _,l in ipairs(logs) do if l:find(text,1,true) then return true end end
    return false
end
local function out(gun)
    clock=clock+1
    gun.toggle_now()
    assert(gun.state.on,'the rifle is out')
end
-- Everything as before the rifle came out.
local function as_shipped(w,keys,store)
    assert(#w.changed()==0,table.concat(w.changed(),'; '))
    assert(w.keys()==keys,w.keys())
    assert(#w.rifles()==0,'no rifle on her')
    assert(w.body.PostProcessAnimBlueprint==w.own_class,'her body\'s own post-process class')
    assert(w.mesh.pp.cls==w.own_class,'her body runs it again')
    assert(store.peek()==nil,tostring(store.peek()))
end

-- 1. H3: stop with the rifle out puts everything back, then nothing of gun mode runs: no key, no toggle, no reset.
do
    local w=Fake.new(); w.install()
    local keys,store=w.keys(),file()
    local gun,logs=new(store)
    out(gun)
    assert(#w.changed()>0 and w.keys()~=keys and #w.rifles()==1 and w.body.PostProcessAnimBlueprint==w.layer_class)
    assert(store.peek(),'coop-gun.txt written while the rifle is out')
    local layer=w.mesh.pp
    layer.ArmsAlpha=1 -- fight/gunmode/ik.lua's hold
    gun.state.fov,gun.state.fov_locked=50,true
    gun.stop('coop off')
    as_shipped(w,keys,store)
    assert(layer.ArmsAlpha==0,'the layer lets go of her arms')
    assert(w.fovs[#w.fovs]==0,'the FOV lock off')
    assert(said(logs,'stopped (coop off)'),table.concat(logs,'|'))
    local function still()
        assert(not gun.state.on and #w.rifles()==0 and w.keys()==keys and #w.changed()==0 and store.peek()==nil)
    end
    w.down.F4=true -- gun_key's default
    for _=1,10 do clock=clock+0.1; gun.tick() end
    w.down.F4=nil
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

-- 2. H3 with gun_fire=own: the rows stay borrowed after the rifle goes away (until a new world); stop gives them back.
do
    local w=Fake.new(); w.install()
    local keys,store=w.keys(),file()
    local gun=new(store,'gun_fire=own\n')
    out(gun)
    clock=clock+1; gun.toggle_now()
    assert(not gun.state.on and #w.changed()>0 and store.peek(),'rows kept and in coop-gun.txt')
    gun.stop('coop off')
    as_shipped(w,keys,store)
end

-- 3. H4: a Lua reload with the rifle out. The next load's restore puts back the rows, the keys, her body's class, the
--    rifle and the FOV lock from coop-gun.txt, then its own rifle takes and gives back the shipped values.
do
    local w=Fake.new(); w.install()
    local keys,store=w.keys(),file()
    out(new(store))
    w.mesh.pp.ArmsAlpha=1
    local b,logs=new(store) -- Ctrl+R: the same game, the same file, an empty Lua state
    w.fovs={}
    b.restore()
    as_shipped(w,keys,store)
    assert(w.fovs[1]==0,'the FOV lock off')
    assert(said(logs,'restore from coop-gun.txt'),table.concat(logs,'|'))
    b.restore() -- once a load
    assert(#w.fovs==1)
    out(b)
    assert(#w.rifles()==1 and w.body.PostProcessAnimBlueprint==w.layer_class)
    clock=clock+1; b.toggle_now()
    assert(not b.state.on)
    as_shipped(w,keys,store)
    -- No file: nothing to do, nothing called.
    local c=new(file())
    w.fovs={}
    c.restore()
    assert(#w.fovs==0)
    -- A start puts back what an earlier load left before it reads the rows, even when no first frame ran restore.
    out(new(store))
    local d=new(store)
    out(d)
    clock=clock+1; d.toggle_now()
    as_shipped(w,keys,store)
end

-- 3b. H4 with v4's writes on her and the camera. A Lua reload in the morph's arrival, in the game's aim and in
--     gun_fire=own's firing mode: the next load destroys the morph's cube and takes the aim camera's modifier off the
--     camera manager. It turns her mesh back to its rotation before the aim turned it and gives her movement its own
--     facing flags. Each drone part goes back as it was: a part the game kept invisible stays invisible.
do
    local w=Fake.new(); w.install()
    local keys,store=w.keys(),file()
    local function thing(full,t)
        t=t or {}
        t.full=full; t.IsValid=function(o) return not o.gone end; t.GetFullName=function(o) return o.full end
        w.paths[full:match('^%S+ (.+)$')]=t
        return t
    end
    w.mesh.RelativeRotation={Pitch=0,Yaw=-90,Roll=0}
    function w.mesh.K2_SetRelativeRotation(c,r) c.RelativeRotation={Pitch=r.Pitch,Yaw=r.Yaw,Roll=r.Roll} end
    local move=w.pawn.CharacterMovement
    move.bOrientRotationToMovement,move.bUseControllerDesiredRotation=true,false
    w.paths['Test.Move']=move
    local mods={}
    local cam=thing('PlayerCameraManager Test.PC.Camera',{GetCameraLocation=function() return {X=-300,Y=40,Z=160} end,
        GetCameraRotation=function() return {Pitch=-5,Yaw=0,Roll=0} end,GetFOVAngle=function() return 45 end})
    function cam.AddNewCameraModifier()
        mods[#mods+1]=thing('BP_NGM_CamMod_C Test.PC.Camera.Mod_'..(#mods+1),{Offset={X=0,Y=0,Z=0}})
        return mods[#mods]
    end
    function cam.RemoveCameraModifier(_,m)
        for i,x in ipairs(mods) do if x==m then table.remove(mods,i); return true end end
        return false
    end
    w.pc.PlayerCameraManager=cam
    thing('BlueprintGeneratedClass /Game/Mods/NGM/BP_NGM_CamMod.BP_NGM_CamMod_C')
    local cube_mesh=require('fight.gunmode.config').DEFAULTS.cube_mesh
    thing('StaticMesh '..cube_mesh,{GetBoundingBox=function() return {Min={X=-50},Max={X=50}} end})
    local add=w.pawn.AddComponentByClass
    w.pawn.AddComponentByClass=function(o,...) local c=add(o,...); c.GetMaterial=function() end; return c end
    -- the drone: one part shown, one the game keeps invisible
    local _,shown=w.drone()
    local dark=w.component(w.drones[1])
    for _,c in ipairs({shown,dark}) do
        c.visible=true; c.SetVisibility=function(o,v) o.visible=v end; c.IsVisible=function(o) return o.visible end
    end
    dark.visible=false
    local function frames(gun,n) for _=1,n do clock=clock+1/60; gun.tick() end end
    local function drone_as_before()
        assert(not shown.bHiddenInGame and shown.visible and not dark.bHiddenInGame and not dark.visible,
            ('drone parts: shown %s %s, dark %s %s'):format(tostring(shown.bHiddenInGame),tostring(shown.visible),
                tostring(dark.bHiddenInGame),tostring(dark.visible)))
    end
    -- in the arrival: the cube in her hand, the modifier added, the drone hidden
    local a=new(store)
    out(a)
    frames(a,6)
    local cube=a.state.cube
    assert(cube and not cube.dead and #mods==1 and dark.bHiddenInGame,'the cube, the modifier and the hidden drone')
    new(store).restore() -- Ctrl+R
    assert(cube.dead,'the cube destroyed')
    assert(#mods==0,#mods..' camera modifiers left')
    drone_as_before()
    as_shipped(w,keys,store)
    -- in the game's aim: her mesh turned toward it
    local b=new(store)
    out(b)
    frames(b,60)
    w.pawn.bTPSMode,w.down.RightMouseButton=true,true
    frames(b,30)
    assert(w.mesh.RelativeRotation.Yaw<-150,'her mesh turned: '..w.mesh.RelativeRotation.Yaw)
    new(store).restore()
    w.pawn.bTPSMode,w.down.RightMouseButton=false,nil
    local r=w.mesh.RelativeRotation
    assert(r.Pitch==0 and r.Yaw==-90 and r.Roll==0,('her mesh at %s %s %s'):format(r.Pitch,r.Yaw,r.Roll))
    assert(#mods==0,#mods..' camera modifiers left')
    drone_as_before()
    as_shipped(w,keys,store)
    -- in gun_fire=own's firing mode: her movement turns her to the camera
    local c=new(store,'gun_fire=own\n')
    out(c)
    frames(c,60)
    w.down.RightMouseButton=true
    frames(c,10)
    assert(move.bOrientRotationToMovement==false and move.bUseControllerDesiredRotation==true,'facing the camera')
    new(store).restore()
    w.down.RightMouseButton=nil
    assert(move.bOrientRotationToMovement==true and move.bUseControllerDesiredRotation==false,'her own facing')
    assert(#mods==0,#mods..' camera modifiers left')
    drone_as_before()
    as_shipped(w,keys,store)
end

-- 4. H4: values kept exactly: floats, integers, booleans, FNames, strings and vectors.
do
    Fake.new().install()
    local Journal=require('fight.gunmode.journal')
    for _,v in ipairs({0.11,400.5,1/3,3,true,false,'Test|Skill\t%',Fake.name('P_Eve_Gun'),{X=1.5,Y=-2,Z=1/3}}) do
        local kind,text=Journal.value(v)
        local list=Journal.records(Journal.line({{'row','T','R','F',kind,text},{'out'}}))
        assert(#list==2 and list[2][1]=='out')
        local back=Journal.parse(list[1][5],list[1][6])
        if type(v)=='table' and v.X then assert(back.X==v.X and back.Y==v.Y and back.Z==v.Z)
        elseif type(v)=='table' then assert(back:ToString()==v:ToString())
        else assert(back==v and math.type(back)==math.type(v),tostring(v)) end
    end
    assert(not pcall(Journal.value,function() end),'a value it cannot keep raises')
end

-- 5. L2: a start that fails after the rows are taken gives back the rows, the layer and the mask.
do
    local w=Fake.new(); w.install()
    local keys,store=w.keys(),file()
    w.no_settings=true -- the input mask fails
    local gun,logs=new(store)
    clock=clock+1; gun.toggle_now()
    assert(not gun.state.on and said(logs,'off: the input mask failed'),table.concat(logs,'|'))
    as_shipped(w,keys,store)
    w.no_settings,w.no_rifle=false,true -- the rifle's stance fails
    clock=clock+1; gun.toggle_now()
    assert(not gun.state.on and said(logs,'off: Luke\'s stance did not start'),table.concat(logs,'|'))
    as_shipped(w,keys,store)
end

-- 6. L2: an unexpected raise inside a start, once the rifle layer is on: the start gives back what it took, then
--    raises again.
do
    local w=Fake.new(); w.install()
    local keys,store=w.keys(),file()
    local gun,logs=new(store,nil,'rifle layer on')
    clock=clock+1
    local ok,e=pcall(gun.toggle_now)
    assert(not ok and e=='test raise',tostring(e))
    assert(not gun.state.on and said(logs,'off: the start failed'),table.concat(logs,'|'))
    as_shipped(w,keys,store)
end

-- 7. L3: a new controller (a map load: a new EVE on the same body mesh) resets the old pawn's state at once; the deferred
--    reset gives back the rows, shows the drone, puts her facing back and takes the layer off her new body.
do
    local w=Fake.new(); w.install()
    local keys,store=w.keys(),file()
    local gun=new(store)
    out(gun)
    local s=gun.state
    local part=w.component(w.pawn); part.bHiddenInGame=true
    local move={IsValid=function() return true end,bOrientRotationToMovement=false,bUseControllerDesiredRotation=true}
    s.drone={actor=w.pawn,parts={{c=part,hidden=false,visible=true}}}
    s.facing={cm=move,orient=true,desired=false}
    s.ovr,s.ovr_row,s.flash_fx,s.pose_m=true,'N_Test_Dead',{},{}
    local p2=w.new_pawn()
    gun.new_controller(w.pc)
    assert(not s.on and not s.ovr and s.ovr_row==nil and s.flash_fx==nil and s.pose_m==nil and not s.layer)
    assert(w.keys()==keys,'the mask off at once')
    assert(p2.Mesh.pp.cls==w.layer_class,'her new body still has the layer until the deferred reset')
    clock=clock+5; gun.tick()
    w.mesh=p2.Mesh
    as_shipped(w,keys,store)
    assert(part.bHiddenInGame==false and s.drone==nil,'the drone shown')
    assert(move.bOrientRotationToMovement==true and move.bUseControllerDesiredRotation==false and s.facing==nil)
    out(gun)
    assert(#w.rifles()==1)
end

-- 8. H4: a Lua reload with the rifle out on the layer's path, a sword drawn and a drone near her, a second sword drawn
--    once the rifle is out (a fight starts). The next load's restore shows both swords to her own camera and the drone
--    again; its own rifle out and away leaves them shown. coop-gun.txt is written again only when its line changes.
do
    local w=Fake.new(); w.install()
    local keys,store=w.keys(),file()
    local saves,save=0,store.save
    store.save=function(text) saves=saves+1; return save(text) end
    local sword=w.sword()
    local _,part=w.drone()
    local a=new(store)
    out(a)
    assert(sword.bOwnerNoSee==true and part.bHiddenInGame==true,'the rifle out hides her sword and the drone')
    clock=clock+0.6; a.tick() -- the arrival's end moves the game's aim to RMB: its keys change the line once
    local later=w.sword()
    saves=0
    for _=1,10 do clock=clock+0.6; a.tick() end
    assert(later.bOwnerNoSee==true,'the sword drawn later hidden within a second')
    assert(saves==1,saves..' writes of coop-gun.txt in 6 s')
    local b=new(store) -- Ctrl+R
    b.restore()
    assert(sword.bOwnerNoSee==false and later.bOwnerNoSee==false,'her swords shown to her own camera again')
    assert(part.bHiddenInGame==false,'the drone shown again')
    as_shipped(w,keys,store)
    out(b)
    assert(sword.bOwnerNoSee==true and part.bHiddenInGame==true)
    clock=clock+1; b.toggle_now()
    assert(sword.bOwnerNoSee==false and part.bHiddenInGame==false,'shown after the next rifle out')
    as_shipped(w,keys,store)
end

-- 9. H4: a Lua reload with the rifle out on the posed stance (the layer's class found, its install failed, no rifle
--    clips). The next load's restore shows her body to her own camera with its own tick option, removes the posed
--    copy's parts from her and the actor its donor stands on.
do
    local w=Fake.new(); w.install()
    w.no_base=true -- The layer cannot rebuild her body.
    local keys,store=w.keys(),file()
    local a,logs=new(store)
    out(a)
    assert(said(logs,'animation pak not installed: posed aim'),table.concat(logs,'|'))
    -- What a carrying frame of the posed stance does (fight/gunmode/stance.lua's frame): her real body hidden from her
    -- camera and ticking always.
    w.mesh.bOwnerNoSee,w.mesh.VisibilityBasedAnimTickOption=true,0
    local parts={}
    for _,c in ipairs(w.pawn.comps) do if not c.dead then parts[#parts+1]=c end end
    assert(#parts>0 and #w.spawned==1,'the posed copy on her, its holder in the world')
    local b=new(store) -- Ctrl+R
    b.restore()
    assert(w.mesh.bOwnerNoSee==false,'her body shown to her own camera again')
    assert(w.mesh.VisibilityBasedAnimTickOption==2,'her body\'s own tick option back')
    for _,c in ipairs(parts) do assert(c.dead,'a part of the posed copy left on her') end
    assert(w.spawned[1].dead,'the holder left in the world')
    as_shipped(w,keys,store)
end

-- 10. H4: a Lua reload with the rifle out on the rifle clips alone (the layer's install failed, the clips found) and
--     the carry stance on. The next load's restore turns the carry stance off.
do
    local w=Fake.new(); w.install()
    w.no_base,w.pak=true,true
    local keys,store=w.keys(),file()
    local a,logs=new(store,'gun_carry_ovr=N_Test_Carry\n')
    out(a)
    assert(said(logs,'animation pak found'),table.concat(logs,'|'))
    assert(w.pawn.stance and w.pawn.stance.OverrideStanceAnim:ToString()=='N_Test_Carry','the carry stance on')
    local b=new(store) -- Ctrl+R
    b.restore()
    assert(w.pawn.stance==nil,'the carry stance off')
    as_shipped(w,keys,store)
end

print('gunmode stop: ok')
