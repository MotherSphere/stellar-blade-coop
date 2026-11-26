-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop closet (closet/commands.lua): alone and with status it answers the dress's status line; another word is
-- refused with the use line. The wear, off and fits words are checked in dress_test.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
package.loaded.UEHelpers={GetPlayer=function() return nil end}
local Cmd=require('closet.commands').new({dress={status=function() return 'closet: nothing worn' end},
    fits=require('closet.fits')})
local ok,line=Cmd.closet()
assert(ok and line=='closet: nothing worn',line)
ok,line=Cmd.closet('status')
assert(ok and line=='closet: nothing worn',line)
ok,line=Cmd.closet('nope')
assert(not ok and line=='Use: coop closet [status|wear <fit>[:<Slot>,...] ...|off|fits|menu|probe <1-5|off>]',line)
ok,line=Cmd.closet('status','extra')
assert(not ok,line)
print('closet_test ok')
