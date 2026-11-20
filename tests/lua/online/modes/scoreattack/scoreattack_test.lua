-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop scoreattack (online/modes/scoreattack/commands.lua): alone and with status it answers the status line; another
-- word is refused with the use line.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Cmd=require('online.modes.scoreattack.commands').new({})
local ok,line=Cmd.scoreattack()
assert(ok and line=='online.modes.scoreattack: nothing built yet',line)
ok,line=Cmd.scoreattack('status')
assert(ok and line=='online.modes.scoreattack: nothing built yet',line)
ok,line=Cmd.scoreattack('nope')
assert(not ok and line=='Use: coop scoreattack [status]',line)
print('scoreattack_test ok')
