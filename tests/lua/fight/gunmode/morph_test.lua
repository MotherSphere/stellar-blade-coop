-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The rifle's morph: the ends, the hand-over from cube to rifle, out as in played backwards.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local M=require('fight.gunmode.morph')
local close=function(a,b) return math.abs(a-b)<1e-6 end

-- 1. In: nothing at the start, the full rifle and no cube at the end.
local a=M.at('in',0); assert(close(a.cube,0) and close(a.rifle,0) and not a.done)
local z=M.at('in',M.IN); assert(close(z.cube,0) and close(z.rifle,1) and z.done)
-- 2. Mid-way the cube is gone and the rifle is out; a third of the way the cube is full size.
assert(close(M.at('in',M.IN*0.33-1e-9).cube,1) or M.at('in',M.IN*0.33-1e-9).cube>0.99)
local m=M.at('in',M.IN*0.66); assert(m.cube<0.01 and m.rifle>0.99)
-- 3. The flash only around the hand-over.
local fl=0
for i=0,100 do if M.at('in',M.IN*i/100).flash then fl=fl+1 end end
assert(fl>0 and fl<15,'flash frames '..fl)
-- 4. Out is in backwards (same shape at mirrored times, scaled to its own length).
for _,f in ipairs({0.1,0.4,0.7,0.95}) do
    local o,i=M.at('out',M.OUT*f),M.at('in',M.IN*(1-f))
    assert(close(o.cube,i.cube) and close(o.rifle,i.rifle),'out vs in at '..f)
end
assert(M.at('out',M.OUT).done and close(M.at('out',M.OUT).rifle,0) and close(M.at('out',M.OUT).cube,0))
print('gunmode morph_test ok')
