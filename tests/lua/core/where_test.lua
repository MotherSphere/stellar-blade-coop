-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- core/where.lua: whether a save is loaded, the title screen shown and where our EVE stands, as
-- online/partner/puppet_test.lua reads them through the ghost.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local function object(fields)
    local o=fields or {}
    o.type=function() return 'UObject' end
    o.IsValid=function() return true end
    return o
end
StaticFindObject=function(path) return object({path=path}) end
local player
package.loaded.UEHelpers={GetPlayer=function() return player end}
local Where=require('core.where')
local function both() local w,t=Where.world(); return tostring(w)..' '..tostring(t) end
local function world(name) return {GetFullName=function() return 'World '..name end} end
player=object({IsA=function(_,c) return c.path=='/Script/SB.SBCharacter' end,
    GetWorld=function() return world('/Game/Art/BG/WorldMap/Level_P/B07.B07') end,
    K2_GetActorLocation=function() return {X=1,Y=2,Z=3} end})
assert(both()=='true false','EVE on Spire IV')
assert(Where.me().map=='/game/art/bg/worldmap/level_p/b07' and Where.me().at.X==1 and Where.me().at.Z==3)
player=object({IsA=function() return false end,GetWorld=function() return world('/Game/Lobby/Lobby.Lobby') end})
assert(both()=='false true','Another pawn on the title map: the title')
player=nil
assert(both()=='false false','No pawn at all')
assert(Where.me()==nil,'Nowhere')
print('core/where_test: ok')
