-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- core/unreal.lua's class_at: the engine's soft class path (KismetSystemLibrary) once the pawn's class came back by its
-- own path through it, else StaticFindObject as before. Covered: no context, no check and the walk; no pawn yet, no
-- decision and the walk, the check made again at the next call; the check passed, then the soft path alone (no
-- StaticFindObject of a class path, the check never made again, with or without a context); a class not in memory, nil
-- with no StaticFindObject; a check that raises, or that gives another object or none, the walk for good with the
-- reason in the route.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local KSL='/Script/Engine.Default__KismetSystemLibrary'
local EVE,BOOTH,GONE='/Game/Test/EVE.EVE_C','/Game/Test/Booth.Booth_C','/Game/Test/Gone.Gone_C'
local function object(address,fields)
    fields=fields or {}
    fields.type=function() return 'UObject' end
    fields.IsValid=function() return true end
    fields.GetAddress=function() return address end
    return fields
end
-- The classes the engine holds by path; what the engine gives for EVE's class instead (nil: the class itself, 'raise',
-- 'none' or another object).
local held={[EVE]=object(0x100,{GetFullName=function() return 'BlueprintGeneratedClass '..EVE end}),
    [BOOTH]=object(0x200)}
local back
local walks,soft,checks -- StaticFindObject paths (the library's aside); soft path calls by path; K2_GetPawn calls.
local kismet=object(1,{
    MakeSoftClassPath=function(_,path) soft[#soft+1]=path; return {AssetPathName=path} end,
    Conv_SoftClassPathToSoftClassRef=function(_,p) return {path=p.AssetPathName} end,
    Conv_SoftClassReferenceToClass=function(_,r)
        if r.path==EVE and back=='raise' then error('no such function',0) end
        if r.path==EVE and back=='none' then return nil end
        if r.path==EVE and back then return back end
        return held[r.path]
    end})
StaticFindObject=function(path)
    if path==KSL then return kismet end
    walks[#walks+1]=path
    return held[path]
end
local pawn -- What K2_GetPawn gives.
local ctx=object(0x300,{K2_GetPawn=function() checks=checks+1; return pawn end})
local function fresh()
    package.loaded['core.unreal']=nil
    walks,soft,checks=({}),{},0
    return require('core.unreal')
end

-- No context: no check, the walk.
local U=fresh()
local cls,route=U.class_at(BOOTH,nil)
assert(cls==held[BOOTH] and route=='walk' and #walks==1 and #soft==0 and checks==0)
-- No pawn yet: no decision, the walk; the check is made again at the next call.
cls,route=U.class_at(BOOTH,ctx)
assert(cls==held[BOOTH] and route=='walk' and #walks==2 and #soft==0 and checks==1)
-- EVE's class comes back by its own path: from then on the soft path alone.
pawn=object(0x400,{GetClass=function() return held[EVE] end})
cls,route=U.class_at(BOOTH,ctx)
assert(cls==held[BOOTH] and route=='soft path' and #walks==2 and checks==2 and soft[1]==EVE and soft[2]==BOOTH,
    table.concat(soft,','))
for _=1,100 do cls,route=U.class_at(BOOTH,ctx) end
cls,route=U.class_at(BOOTH,nil)
assert(cls==held[BOOTH] and route=='soft path' and #walks==2 and checks==2 and #soft==103,'No check and no walk again')
-- A class not in memory: nil, and no StaticFindObject.
cls,route=U.class_at(GONE,ctx)
assert(cls==nil and route=='soft path' and #walks==2 and soft[#soft]==GONE)

-- A check that raises: the walk for good, with the error in the route.
back='raise'
U=fresh()
for _=1,10 do cls,route=U.class_at(BOOTH,ctx) end
assert(cls==held[BOOTH] and route=='walk (no such function)' and checks==1 and #walks==10 and #soft==1,route)
cls,route=U.class_at(GONE,ctx)
assert(cls==nil and route=='walk (no such function)' and walks[11]==GONE)
-- Another object for EVE's class, or none: the walk for good, with what came back in the route.
back=object(0x999)
U=fresh()
cls,route=U.class_at(BOOTH,ctx)
cls,route=U.class_at(BOOTH,ctx)
assert(cls==held[BOOTH] and route=='walk (its pawn class came back as 0x999)' and checks==1 and #walks==2,route)
back='none'
U=fresh()
cls,route=U.class_at(BOOTH,ctx)
assert(cls==held[BOOTH] and route=='walk (its pawn class came back as nil)' and checks==1 and #walks==1,route)
-- object_at: nil and nil before the proof (no pawn: no walk, no soft call); the soft object path once proven (a _C
-- path through the class route), never a walk; the walk once the proof failed for good, as class_at.
local OBJ='/Game/Test/Seq.Seq'
held[OBJ]=object(0x500)
kismet.MakeSoftObjectPath=function(_,path) soft[#soft+1]=path; return {AssetPathName=path} end
kismet.Conv_SoftObjPathToSoftObjRef=function(_,p) return {path=p.AssetPathName} end
kismet.Conv_SoftObjectReferenceToObject=function(_,r) return held[r.path] end
back,pawn=nil,nil
U=fresh()
local x,known=U.object_at(OBJ,ctx)
assert(x==nil and known==nil and #walks==0 and #soft==0)
pawn=object(0x400,{GetClass=function() return held[EVE] end})
x,known=U.object_at(OBJ,ctx)
assert(x==held[OBJ] and known==true and #walks==0 and soft[#soft]==OBJ)
x,known=U.object_at(BOOTH,nil)
assert(x==held[BOOTH] and known==true and #walks==0 and soft[#soft]==BOOTH)
back='raise'
U=fresh()
x,known=U.object_at(OBJ,ctx)
assert(x==held[OBJ] and known==true and walks[#walks]==OBJ)
back=nil
print('class_at_test ok')
