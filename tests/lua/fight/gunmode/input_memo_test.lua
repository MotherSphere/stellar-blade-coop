-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's key reads: one IsInputKeyDown a key a frame. With gun_fire_key=RightMouseButton the right mouse button
-- is in both the fire and the zoom keys. It is read once a frame. It is read again on the next frame.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local reads,fnames={},0
local pc={}
function pc:IsValid() return true end
function pc:IsInputKeyDown(k) reads[k.KeyName]=(reads[k.KeyName] or 0)+1; return false end
local gs={}
function gs:IsValid() return true end
function gs:IsGamePaused() return false end
FName=function(n) fnames=fnames+1; return n end
FindFirstOf=function() return pc end
StaticFindObject=function() return gs end
local loop
LoopInGameThreadWithDelay=function(_,f) loop=f end
local logs={}
local GunMode=require('fight.gunmode.mode')
local gm=GunMode.new({log=function(m) logs[#logs+1]=m end,folder='x',
    read_all=function() return 'gun_fire_key=RightMouseButton\n' end})
assert(gm.hook() and loop)
loop()
for _,m in ipairs(logs) do assert(not m:find('^error'),m) end
assert(reads.RightMouseButton==1,'RightMouseButton read '..tostring(reads.RightMouseButton)..' times in one frame')
assert(reads.G==1 and reads.LeftMouseButton==1)
local made=fnames
loop()
assert(reads.RightMouseButton==2 and reads.G==2,'each frame reads the keys again')
assert(fnames==made,'the key names are made once')
print('gunmode input_memo_test ok')
