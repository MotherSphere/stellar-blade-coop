-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's laser end: a target is sent to the parameter collection only when it moved; after a trace along the
-- barrel (no target) the next target is sent again.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local sent={}
local function obj(t) t=t or {}; t.IsValid=function() return true end; return t end
local instance=obj({GetVectorParameter=function() return {X=0,Y=0,Z=0} end,
    SetVectorParameter=function(_,_,v) sent[#sent+1]={X=v.X,Y=v.Y,Z=v.Z} end})
local library=obj({GetNiagaraParameterCollection=function() return instance end,
    SpawnSystemAttached=function() return obj({Activate=function() end}) end})
local trace=obj({LineTraceSingle=function() return false end})
FName=function(n) return n end
StaticFindObject=function(path)
    if path:find('NiagaraFunctionLibrary') then return library end
    if path:find('KismetSystemLibrary') then return trace end
    return obj()
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
print('gunmode laser_test ok')
