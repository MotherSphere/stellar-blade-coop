-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode put back over a fake UE4SS (fake.lua), on the rifle layer's path: a start that fails gives back what it
-- took. The cases are stop_test's of 5492c007 fitted to luke's gun mode. Its coop-gun.txt cases are left out: no
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

print('gunmode stop: ok')
