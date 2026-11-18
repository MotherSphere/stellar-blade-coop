-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The partner's copy of bike/ride.lua's find_part with Ride.MESH and Ride.TAG (November 2026 restructure): while
-- the bike module is off, the bike part an earlier Lua load left on EVE stays out of the ghost's capture.
local UE=require('UEHelpers')
local U=require('core.unreal')
local valid,each,find,address=U.valid,U.each,U.find,U.address
local BikePart,Ride={},{}
Ride.MESH='/Game/Art/Character/ETC/Adam_vehicle_02/Adam_Vehicle_02.Adam_Vehicle_02'
-- The component tag that marks SBO's own part, so another mod's component on the same mesh is never taken for it.
Ride.TAG='SBO_Bike'
local SKINNED='/Script/Engine.SkeletalMeshComponent'
local function path_of(o) return o:GetFullName():match('^%S+ (.+)$') end
local function her() return U.her(valid(UE.GetPlayer())) end
-- The bike part an earlier Lua load made on EVE: her skeletal mesh component that shows Ride.MESH and carries
-- Ride.TAG, else nil.
local function find_part(e)
    local found=nil
    each(e:K2_GetComponentsByClass(find(SKINNED)),function(_,c)
        c=valid(c)
        local mesh=c and valid(c.SkeletalMesh)
        if not found and mesh and path_of(mesh)==Ride.MESH and c:ComponentHasTag(FName(Ride.TAG))==true then
            found=c
        end
    end)
    return found
end
-- The address of that part on her EVE, whose address is at, or nil: partner/wiring.lua's leave_out while the bike
-- module is off, when no ride can show it.
function BikePart.idle(at)
    local e=her()
    local p=e and address(e)==at and find_part(e)
    return p and address(p) or nil
end
return BikePart
