-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode hosted by StellarCoop: start() registers no hook or loop; fight/gunmode/wiring.lua calls new_controller
-- and main/frame.lua calls tick. Both do nothing with gun_mode=off or after stop. out() follows the on state. In
-- StellarCoop start() registers nothing even without env.hosted: engine hooks belong to wiring.lua (texts_test).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local reads=0
local pc={}
function pc:IsValid() return true end
function pc:IsInputKeyDown() reads=reads+1; return false end
local gs={}
function gs:IsValid() return true end
function gs:IsGamePaused() return false end
FName=function(n) return n end
FindFirstOf=function() return pc end
StaticFindObject=function() return gs end
local hooks,loops=0,0
NotifyOnNewObject=function() hooks=hooks+1 end
LoopInGameThreadWithDelay=function() loops=loops+1 end
local GunMode=require('fight.gunmode.mode')
local function new(text,hosted)
    local logs={}
    local gm=GunMode.new({log=function(m) logs[#logs+1]=m end,folder='x',hosted=hosted,
        read_all=function() return text end})
    return gm,logs
end

-- 1. Hosted: no hook, no loop, the ready line; tick reads the keys; new_controller resets the pause.
do
    local gm,logs=new('',true)
    gm.start()
    assert(hooks==0 and loops==0,'a hosted start registers nothing')
    assert(logs[#logs]:find('^ready: G'))
    gm.tick(); assert(reads>0,'tick runs a frame')
    for _,m in ipairs(logs) do assert(not m:find('^error'),m) end
    gm.new_controller(pc); assert(gm.state.pause>0)
    -- 2. out() follows the on state.
    assert(gm.out()==false)
    gm.state.on=true; assert(gm.out()==true)
    gm.state.on=false
    gm.restore()
    -- 3. After stop: tick and new_controller do nothing.
    gm.stop('coop off')
    assert(gm.out()==false and gm.state.dead)
    local r=reads; gm.tick(); assert(reads==r,'no frame after stop')
    gm.state.pause=0; gm.new_controller(pc); assert(gm.state.pause==0,'no reset after stop')
end

-- 4. gun_mode=off: tick and new_controller do nothing.
do
    local gm=new('gun_mode=off\n',true)
    gm.start()
    local r=reads; gm.tick(); assert(reads==r)
    gm.new_controller(pc); assert(gm.state.pause==0)
end

-- 5. Not hosted: start() still registers no hook and no loop.
do
    local gm=new('',nil)
    gm.start()
    assert(hooks==0 and loops==0,'start registers nothing without a host either')
end
print('gunmode/hosted_test: ok')
