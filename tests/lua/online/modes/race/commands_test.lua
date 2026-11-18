-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- online/modes/race/commands.lua: coop race look on is refused while EVE rides the bike, with nothing asked of the Doro
-- look; once she is off, the look starts.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local looks=0
local rides=true
local Cmd=require('online.modes.race.commands').new({puppet={doro=function() return true end},
    doro={on=function() looks=looks+1; return true,'look on' end,off=function() return true,'look off' end},
    coop_slot=function() return true end,race={command=function() return true end},riding=function() return rides end})
local ok,why=Cmd.race('look','on')
assert(not ok and why=='EVE rides the bike: coop bike gets her off first' and looks==0,why)
rides=false
assert(Cmd.race('look','on') and looks==1)
print('race_commands_test ok')
