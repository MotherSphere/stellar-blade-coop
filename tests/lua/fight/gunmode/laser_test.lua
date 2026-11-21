-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's laser end: a target is sent to the parameter collection only when it moved; after a trace along the
-- barrel (no target) the next target is sent again. A second laser start looks up none of its objects again while each
-- still has its path; an object whose address now holds another one is looked up again.
-- The beam hangs from a scene component snapped to the rifle's FX_Fire socket, so the engine carries it with the
-- muzzle (it was moved from Lua and lagged a frame). It never hangs right on the rifle, a part a partner's game copies.
-- Both carry the rifle's tag for the sweep after a Lua reload. The cleanup takes the holder away.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local sent={}
local function obj(t) t=t or {}; t.IsValid=function() return true end; return t end
local instance=obj({GetVectorParameter=function() return {X=0,Y=0,Z=0} end,
    SetVectorParameter=function(_,_,v) sent[#sent+1]={X=v.X,Y=v.Y,Z=v.Z} end})
local spawned={}
local library=obj({GetNiagaraParameterCollection=function() return instance end,
    SpawnSystemAttached=function(_,asset,parent,point,loc,rot,kind)
        local beam=obj({Activate=function() end,ComponentTags={},Deactivate=function() end,SetVisibility=function() end})
        spawned[#spawned+1]={beam=beam,parent=parent,point=point,kind=kind}
        return beam
    end})
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
local holders={}
local function pawn() return obj({AddComponentByClass=function()
    local h=obj({ComponentTags={},K2_AttachToComponent=function(o,parent,socket,a,b,c) o.parent,o.socket,o.rules=parent,socket,{a,b,c} end,
        K2_DestroyComponent=function(o) o.destroyed=true end})
    holders[#holders+1]=h
    return h
end,FinishAddComponent=function() end}) end
local update,cleanup=require('fight.gunmode.laser')(pawn(),gun,mathlib)
assert(#sent==1) -- the spawn's trace along the barrel
local h,b=holders[1],spawned[1]
assert(h.parent==gun and h.socket=='FX_Fire' and h.rules[1]==2 and h.rules[2]==2,'holder snapped to the muzzle')
assert(b.parent==h and b.parent~=gun and b.kind==2,'beam on the holder, not on the rifle')
assert(h.ComponentTags[1]=='SBO_Gun' and b.beam.ComponentTags[1]=='SBO_Gun','tagged for the sweep')
update({X=1,Y=2,Z=3}); update({X=1,Y=2,Z=3})
assert(#sent==2,'the same point sent again')
update({X=1,Y=2,Z=4}); assert(#sent==3 and sent[3].Z==4)
update(); update({X=1,Y=2,Z=4})
assert(#sent==5,'a target after the barrel trace is sent')
cleanup()
assert(h.destroyed,'holder taken away')
-- A second start: no walk while each kept object still has its path.
local before=walks
require('fight.gunmode.laser')(pawn(),gun,mathlib)
assert(walks==before,(walks-before)..' lookups at the second laser start')
-- The guide laser's asset collected and another object at its address: looked up again, once.
local path='/Game/DLC_2/Art/FX/MiniGame/NS_A_GuideLaser.NS_A_GuideLaser'
named[path].GetFullName=function() return 'Texture2D /Game/Other.Other' end
named[path]=nil
before=walks
require('fight.gunmode.laser')(pawn(),gun,mathlib)
assert(walks==before+1,(walks-before)..' lookups after the asset changed')
print('gunmode laser_test ok')
