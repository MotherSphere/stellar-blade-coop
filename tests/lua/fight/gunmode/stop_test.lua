-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode put back over a fake UE4SS (fake.lua), with the rifle layer's path (the only one the park lets run): stop
-- (coop off) gives back the input mask, SB's rows, the rifle, her body's own post-process class, the FOV lock and the
-- layer's arms, then nothing more runs; the next Lua load puts back what coop-gun.txt says an earlier one left; a start
-- that fails gives back what it took; a new controller resets the old pawn's state and the deferred reset takes the
-- layer off her body. fake.lua's rows have the kinds of 26123051's: the Hit1 step has no StepType, so take() saves a
-- nil there that coop-gun.txt must skip, else no rifle comes out.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Fake=dofile('tests/lua/fight/gunmode/fake.lua')
local GunMode=require('fight.gunmode.mode')
local clock=100
os.clock=function() return clock end
-- coop-gun.txt in memory, as core/link.lua's store gives it: one line.
local function file()
    local f={}
    return {save=function(text) f.text=text; return true end,load=function() return f.text end,
        clear=function() f.text=nil end,peek=function() return f.text end}
end
-- fail: a log line that raises once when it starts with this text (an unexpected raise inside a start).
local function new(store,settings,fail)
    local logs={}
    local gun=GunMode.new({log=function(m)
            logs[#logs+1]=m
            if fail and m:sub(1,#fail)==fail then fail=nil; error('test raise',0) end
        end,store=store,folder=settings and 'mod',read_all=function() return settings end})
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
    w.down.G=true
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
    local part=w.component(w.pawn); part.hidden=true
    local move={IsValid=function() return true end,bOrientRotationToMovement=false,bUseControllerDesiredRotation=true}
    s.drone={actor=w.pawn,parts={part}}
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
    assert(part.hidden==false and s.drone==nil,'the drone shown')
    assert(move.bOrientRotationToMovement==true and move.bUseControllerDesiredRotation==false and s.facing==nil)
    out(gun)
    assert(#w.rifles()==1)
end

print('gunmode stop: ok')
