-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop xion (world/maps/sboxion/commands.lua): alone and with status it answers the status line; another word is
-- refused with the use line.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Cmd=require('world.maps.sboxion.commands').new({})
local ok,line=Cmd.xion()
assert(ok and line=='world.maps.sboxion: nothing built yet',line)
ok,line=Cmd.xion('status')
assert(ok and line=='world.maps.sboxion: nothing built yet',line)
ok,line=Cmd.xion('nope')
assert(not ok and line=='Use: coop xion [status]',line)
print('sboxion_test ok')
