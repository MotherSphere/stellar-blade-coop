-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- partner/bike_part.lua with fake UE4SS objects (its copy of bike/ride.lua's find_part, November 2026): the tagged
-- bike part on her EVE by her address; another mesh, no tag or another EVE's address gives nil.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
FName=function(t) return {ToString=function() return t end} end
local function uobj(o)
    o.type=function() return 'UObject' end
    o.IsValid=function(self) return not self.gone end
    return o
end
local classes={}
StaticFindObject=function(path) classes[path]=classes[path] or uobj({path=path}); return classes[path] end
local MESH='/Game/Art/Character/ETC/Adam_vehicle_02/Adam_Vehicle_02.Adam_Vehicle_02'
local function mesh(path) return uobj({GetFullName=function() return 'SkeletalMesh '..path end}) end
local function part(m,tags,at)
    return uobj({SkeletalMesh=m,GetAddress=function() return at end,ComponentHasTag=function(_,tag)
        for _,t in ipairs(tags) do if t==tag:ToString() then return true end end
        return false
    end})
end
local list={}
local eve=uobj({GetAddress=function() return 0x100 end,IsA=function(_,c) return c.path=='/Script/SB.SBCharacter' end,
    K2_GetComponentsByClass=function(_,c)
        assert(c.path=='/Script/Engine.SkeletalMeshComponent')
        return list
    end})
package.loaded['UEHelpers']={GetPlayer=function() return eve end}
local BikePart=require('partner.bike_part')
assert(BikePart.idle(0x100)==nil,'No part: nil')
list={part(mesh('/Game/Other.Other'),{'SBO_Bike'},0x201),part(mesh(MESH),{},0x202)}
assert(BikePart.idle(0x100)==nil,'Another mesh, or no tag: not the bike part')
list[#list+1]=part(mesh(MESH),{'SBO_Bike'},0x203)
assert(BikePart.idle(0x100)==0x203,'The tagged bike part')
assert(BikePart.idle(0x999)==nil,'Another EVE: nil')
print('bike_part_test ok')
