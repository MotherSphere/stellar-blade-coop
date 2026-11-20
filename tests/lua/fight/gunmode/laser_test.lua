-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's laser end: a target is sent to the parameter collection only when it moved; after a trace along the
-- barrel (no target) the next target is sent again; a small move of the end (under 3 deg seen from the muzzle) is eased
-- toward at laser_smooth, a bigger one is taken at once. A second laser start looks up none of its objects again while each
-- still has its path; an object whose address now holds another one is looked up again.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local sent={}
local function obj(t) t=t or {}; t.IsValid=function() return true end; return t end
local instance=obj({GetVectorParameter=function() return {X=0,Y=0,Z=0} end,
    SetVectorParameter=function(_,_,v) sent[#sent+1]={X=v.X,Y=v.Y,Z=v.Z} end})
local library=obj({GetNiagaraParameterCollection=function() return instance end,
    SpawnSystemAttached=function() return obj({Activate=function() end}) end})
local trace=obj({LineTraceSingle=function() return false end})
FName=function(n) return n end
local walks,named=0,{}
StaticFindObject=function(path)
    walks=walks+1
    local o
    if path:find('NiagaraFunctionLibrary') then o=library
    elseif path:find('KismetSystemLibrary') then o=trace
    else o=named[path] or obj() end
    named[path]=o
    o.GetFullName=o.GetFullName or function() return 'Object '..path end
    return o
end
local gun={GetSocketLocation=function() return {X=0,Y=0,Z=0} end,GetSocketRotation=function() return {} end,
    DoesSocketExist=function() return true end}
local mathlib={GetForwardVector=function() return {X=1,Y=0,Z=0} end}
local clock,t=os.clock,0
os.clock=function() return t end
local update=require('fight.gunmode.laser')(obj(),gun,mathlib)
assert(#sent==1) -- the spawn's trace along the barrel
update({X=1,Y=2,Z=3}); t=t+10; update({X=1,Y=2,Z=3})
assert(#sent==2,'the same point sent again')
t=t+10; update({X=1,Y=2,Z=4}); assert(#sent==3 and sent[3].Z==4)
update(); update({X=1,Y=2,Z=4})
assert(#sent==5,'a target after the barrel trace is sent')
-- The end eases (laser_smooth): with the muzzle at the origin and the dot 5000 cm away, a 100 cm move (1.1 deg) goes
-- 1-exp(-dt/laser_smooth) of the way in a frame and settles within 0.1 cm in 1 s; a 1000 cm move (11 deg: a snap) is
-- taken at once.
do
    local T=require('fight.gunmode.config').DEFAULTS.laser_smooth
    assert(T and T>0)
    t=t+10; update({X=5000,Y=0,Z=0}); local n=#sent
    t=t+1/60; update({X=5000,Y=100,Z=0})
    local want=100*(1-math.exp(-(1/60)/T))
    assert(#sent==n+1 and math.abs(sent[#sent].Y-want)<1e-9,'eased step '..sent[#sent].Y..' (want '..want..')')
    for _=1,60 do t=t+1/60; update({X=5000,Y=100,Z=0}) end
    assert(math.abs(sent[#sent].Y-100)<0.1,'settled at '..sent[#sent].Y)
    t=t+1/60; update({X=5000,Y=1100,Z=0})
    assert(sent[#sent].Y==1100,'a snap is taken at once: '..sent[#sent].Y)
end
os.clock=clock
-- A second start: no walk while each kept object still has its path.
local before=walks
require('fight.gunmode.laser')(obj(),gun,mathlib)
assert(walks==before,(walks-before)..' lookups at the second laser start')
-- The guide laser's asset collected and another object at its address: looked up again, once.
local path='/Game/DLC_2/Art/FX/MiniGame/NS_A_GuideLaser.NS_A_GuideLaser'
named[path].GetFullName=function() return 'Texture2D /Game/Other.Other' end
named[path]=nil
before=walks
require('fight.gunmode.laser')(obj(),gun,mathlib)
assert(walks==before+1,(walks-before)..' lookups after the asset changed')
print('gunmode laser_test ok')
