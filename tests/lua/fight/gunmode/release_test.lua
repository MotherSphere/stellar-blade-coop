-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- fight/gunmode/release_check.lua on gun mode's shipped defaults, so every build checks them: Config.DEFAULTS holds no
-- debug flag set on. Planted cases first, so the check is seen to refuse what it guards against.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Check=require('fight.gunmode.release_check')
local Config=require('fight.gunmode.config')

-- A test-only line, a release value changed and a debug default set on are refused. A comment and the release value
-- pass.
assert(not Check.run('gun_facts=on\n',nil),'a test-only line passed')
assert(not Check.run('gun_aim_key=LeftMouseButton\n',nil),'a changed release value passed')
assert(Check.run('# gun_facts=on\ngun_aim_key=RightMouseButton\n',nil),'a comment or the release value was refused')
local planted={}
for k,v in pairs(Config.DEFAULTS) do planted[k]=v end
planted.debug_draw=true
assert(not Check.run('',planted),'a debug default set on passed')

-- The shipped defaults.
local ok,bad=Check.run('',Config.DEFAULTS)
assert(ok,'Config.DEFAULTS: '..table.concat(bad or {},'; '))
print('gunmode release check: ok')
