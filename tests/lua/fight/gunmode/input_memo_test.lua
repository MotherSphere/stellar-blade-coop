-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's key reads, over fake.lua with the rifle out: one IsInputKeyDown a key a frame. With
-- gun_fire_key=RightMouseButton the right mouse button is in both the fire and the zoom keys (gun_fire=own polls the
-- zoom keys); it is read once a frame, and read again on the next frame. The keys' names are made once.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Fake=dofile('tests/lua/fight/gunmode/fake.lua')
package.loaded['fight.gunmode.laser']=function() return function() end,function() end end
local GunMode=require('fight.gunmode.mode')
local clock=100
os.clock=function() return clock end

local w=Fake.new(); w.install()
local logs={}
local gun=GunMode.new({log=function(m) logs[#logs+1]=m end,
    settings=require('core.link').parse_settings('gun_fire_key=RightMouseButton\ngun_fire=own\n')})
clock=clock+1; gun.toggle_now()
assert(gun.state.on,'the rifle is out')
clock=clock+1/60; gun.tick()
local reads={}
local down=w.pc.IsInputKeyDown
function w.pc.IsInputKeyDown(o,k)
    local n=k.KeyName:ToString()
    reads[n]=(reads[n] or 0)+1
    return down(o,k)
end
local fname,made=FName,0
FName=function(n,...) if not tostring(n):find('/',1,true) then made=made+1 end return fname(n,...) end -- (key names: no path)
clock=clock+1/60; gun.tick()
for _,m in ipairs(logs) do assert(not m:find('^error'),m) end
assert(reads.RightMouseButton==1,'RightMouseButton read '..tostring(reads.RightMouseButton)..' times in one frame')
assert(reads.F4==1 and reads.LeftMouseButton==1,'F4 '..tostring(reads.F4)..', LMB '..tostring(reads.LeftMouseButton))
local before=made
clock=clock+1/60; gun.tick()
assert(reads.RightMouseButton==2 and reads.F4==2,'each frame reads the keys again')
assert(made==before,(made-before)..' key names made on a frame')
print('gunmode input_memo_test ok')
