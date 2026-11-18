-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- EVE, her controller and the fight check, moved out of online/modes/nightop/probe.lua and
-- world/maps/matrix13/quest/zone_talks.lua.
local U=require('core.unreal')
local UE=require('UEHelpers')
local Player={}
local function her()
    local eve=U.valid(UE.GetPlayer())
    return eve and eve:IsA(U.find('/Script/SB.SBCharacter')) and eve or nil
end
local function controller()
    local pc=U.valid(UE.GetPlayerController())
    return pc and pc:IsA(U.find('/Script/SB.SBNetworkPlayerController')) and pc or nil
end
-- cm: an engaged enemy farther than this is no fight [inference].
Player.NEAR=5000
-- Whether an enemy within near cm (NEAR unless given) of EVE fights: IsBattle, standing, shown, with a controller.
-- Also online/lobby/sbo.lua's fight check, through main.lua.
local function engaged(eve,near)
    local here=U.value_of(eve:K2_GetActorLocation())
    local mine=U.address(eve)
    for _,c in ipairs((U.actors_of(U.find('/Script/SB.SBCharacter'),'SBCharacter',eve))) do
        local ok,fights=pcall(function()
            if U.address(c)==mine or c:IsBattle()~=true or c.bCharacterHiddenInGame==true then return false end
            local st,at=c.InteractionState,U.value_of(c:K2_GetActorLocation())
            local d=math.sqrt((at.X-here.X)^2+(at.Y-here.Y)^2+(at.Z-here.Z)^2)
            return (st==0 or st==1) and U.valid(c.Controller)~=nil and d<=(near or Player.NEAR)
        end)
        if ok and fights then return true end
    end
    return false
end
Player.her,Player.controller,Player.engaged=her,controller,engaged
return Player
