-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The ghost's collision through main/pass.lua (fixture.lua): as collide says, never solid during an SBO session. The
-- statement reads the ghost (online/partner/) and the SBO lobby (online/lobby/), so its test stays with the runtime's.
dofile('tests/lua/main/fixture.lua')
settings_text='sbo_lobby=on\n'
load_main(true)
-- The ghost's collision: off while a session is active, even with collide=on (design-lobby 12.7).
sb.o.settings.collide=true
quarter()
assert(package.loaded['online.partner.puppet'].collide==true)
sb.active=true
quarter()
assert(package.loaded['online.partner.puppet'].collide==false,'No solid ghost in a session')
sb.active,sb.o.settings.collide=false,false
print('collide_test ok')
