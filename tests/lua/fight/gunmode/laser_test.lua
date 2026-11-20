-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's laser end: a target is sent to the parameter collection only when it moved; after a trace along the
-- barrel (no target) the next target is sent again. A second laser start looks up none of its objects again while each
-- still has its path; an object whose address now holds another one is looked up again.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local sent={}
local function obj(t) t=t or {}; t.IsValid=function() return true end; return t end
local instance=obj({GetVectorParameter=function() return {X=0,Y=0,Z=0} end,
    SetVectorParameter=function(_,_,v) sent[#sent+1]={X=v.X,Y=v.Y,Z=v.Z} end})
local library=obj({GetNiagaraParameterCollection=function() return instance end,
    SpawnSystemAtLocation=function() return obj({Activate=function() end,K2_SetWorldLocationAndRotation=function() end}) end})
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
local update=require('fight.gunmode.laser')(obj(),gun,mathlib)
assert(#sent==1) -- the spawn's trace along the barrel
update({X=1,Y=2,Z=3}); update({X=1,Y=2,Z=3})
assert(#sent==2,'the same point sent again')
update({X=1,Y=2,Z=4}); assert(#sent==3 and sent[3].Z==4)
update(); update({X=1,Y=2,Z=4})
assert(#sent==5,'a target after the barrel trace is sent')
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
