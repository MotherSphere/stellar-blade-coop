-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- core/unreal.lua's kind: the UE4SS type name of a typed object, nil for an object whose __index raises (a stale
-- one), a table with no type, a number or nil; a wrapped parameter opened by value_of and valid; no garbage per call.
-- The helpers the modules share: why without the file and line, metres from cm, her for an SBCharacter only.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local U=require('core.unreal')
local function object(fields)
    fields.type=fields.type or function() return 'UObject' end
    fields.IsValid=fields.IsValid or function() return true end
    return setmetatable({},{__index=fields})
end
local obj=object({})
local stale=setmetatable({},{__index=function(_,k) error('no '..k) end})
assert(U.kind(obj)=='UObject')
assert(U.kind(stale)==nil and U.kind({})==nil and U.kind(3)==nil and U.kind('UObject')==nil and U.kind(nil)==nil)
local param=object({type=function() return 'RemoteUnrealParam' end,get=function() return obj end})
assert(U.value_of(param)==obj and U.valid(param)==obj and U.valid(stale)==nil)
assert(U.valid(object({IsValid=function() return false end}))==nil)

-- No garbage: a function made in each call was 80 B a call (800 KB here).
collectgarbage('collect'); collectgarbage('stop')
local before=collectgarbage('count')
for _=1,10000 do U.kind(obj) end
local after=collectgarbage('count')
collectgarbage('restart')
assert(after-before<1,string.format('U.kind left %.1f KiB of garbage over 10000 calls',after-before))

assert(U.why('mod/x.lua:12: no row')=='no row' and U.why('a: b:3: c')=='c' and U.why('plain')=='plain')
assert(U.why(nil)=='nil')
assert(U.metres({X=0,Y=0,Z=0},{X=300,Y=-400,Z=0})==5 and U.metres({X=1,Y=2,Z=3},{X=1,Y=2,Z=103})==1)
local SBC=object({})
StaticFindObject=function(path) return path=='/Script/SB.SBCharacter' and SBC or nil end
local eve=object({IsA=function(_,c) return c==SBC end})
assert(U.her(eve)==eve and U.her(object({IsA=function() return false end}))==nil and U.her(nil)==nil)
print('unreal_test ok')
