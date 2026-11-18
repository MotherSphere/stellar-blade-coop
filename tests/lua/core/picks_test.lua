-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- core/picks.lua: the select widgets' watcher online/modes/nightop/roxanne.lua and
-- world/maps/matrix13/quest/on_time.lua take, looking again every 2 s once it walks FindAllOf.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Roxanne=require('core.picks')
assert(Roxanne.FIND_EVERY==2)
local w=Roxanne.watcher({log=function() end,paused=function() return false end})
assert(type(w.watch)=='function' and type(w.reset)=='function')
print('core/picks_test: ok')
