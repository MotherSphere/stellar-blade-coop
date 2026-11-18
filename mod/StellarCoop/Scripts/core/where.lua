-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Our EVE's world, the title screen and her place, moved out of partner/puppet.lua for every module to read.
local UE=require('UEHelpers')
local U=require('core.unreal')
local valid,value_of=U.valid,U.value_of
local her=U.her
local Where={}
-- Whether a save is loaded: EVE on any map but the title screen's. The link holds an accepted invite until then.
-- Second: whether the title screen is shown, a pawn of any class on its map (never during a loading screen, which
-- has no pawn); the native part changes the co-op saves only then. The same read keeps where she stands and her
-- map for the partner HUD (me()).
local me=nil
local TITLE='/game/lobby/lobby'
function Where.world()
    me=nil
    local ok,loaded,title=pcall(function()
        local pawn=valid(UE.GetPlayer())
        local eve=her(pawn)
        if not eve then return false,pawn~=nil and U.map_of(pawn)==TITLE end
        local map,at=U.map_of(eve),value_of(eve:K2_GetActorLocation())
        me={at={X=at.X,Y=at.Y,Z=at.Z},map=map}
        return map~=TITLE,map==TITLE
    end)
    return ok and loaded,ok and title
end
-- Our EVE as of the last world(): {at={X,Y,Z}, map=}, or nil.
function Where.me() return me end
return Where
