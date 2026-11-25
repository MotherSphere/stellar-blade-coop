-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop closet (closet/commands.lua): alone and with status it answers the status line; another word is refused
-- with the use line.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Cmd=require('closet.commands').new({})
local ok,line=Cmd.closet()
assert(ok and line=='closet: nothing built yet',line)
ok,line=Cmd.closet('status')
assert(ok and line=='closet: nothing built yet',line)
ok,line=Cmd.closet('nope')
assert(not ok and line=='Use: coop closet [status]',line)
print('closet_test ok')
