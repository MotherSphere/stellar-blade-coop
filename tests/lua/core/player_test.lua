-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- core/player.lua: EVE and her controller by their classes (online/modes/nightop/probe.lua's), the fight check's reach
-- of world/maps/matrix13/quest/zone_talks.lua (5000 cm).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local function object(fields)
    local o=fields or {}
    o.type=function() return 'UObject' end
    o.IsValid=function() return true end
    return o
end
local classes={}
StaticFindObject=function(path) classes[path]=classes[path] or object({path=path}); return classes[path] end
local function of(class) return object({IsA=function(_,c) return c.path==class end}) end
local eve,pc=of('/Script/SB.SBCharacter'),of('/Script/SB.SBNetworkPlayerController')
package.loaded.UEHelpers={GetPlayer=function() return eve end,GetPlayerController=function() return pc end}
local Player=require('core.player')
assert(Player.her()==eve and Player.controller()==pc)
eve,pc=of('/Script/Engine.Pawn'),of('/Script/Engine.PlayerController')
assert(Player.her()==nil and Player.controller()==nil,'Another class: none')
assert(Player.NEAR==5000 and type(Player.engaged)=='function')
print('core/player_test: ok')
