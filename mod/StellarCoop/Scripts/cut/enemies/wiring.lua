-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The cut enemies' wiring (cut/enemies/): coop lion, coop gardener fight, coop tendril fight, the model viewer.
return {
uses={'session','save'},
exports={'lion','gardener','tendril','leviathan'},
new=function(M)
local print,log=M.print,M.log
-- coop lion (cut/enemies/lion.lua), logging [LI] lines: its rows asked of the native part, its status read back. Night
-- Operation's shop asks it for the cut items' rows at each call (nightop/wiring.lua's rows).
M.lion=require('cut.enemies.lion').new({log=function(m) print('[StellarCoop][LI] '..tostring(m)..'\n') end,
    ask=function(line) return M.ask(line)() end,status=function() return M.link and M.link.status() end})
-- coop gardener fight (cut/enemies/gardener.lua), logging [GD] lines: the same, for the cut Gardener's rows and spawn.
M.gardener=require('cut.enemies.gardener').new({log=function(m) print('[StellarCoop][GD] '..tostring(m)..'\n') end,
    ask=function(line) return M.ask(line)() end,status=function() return M.link and M.link.status() end})
-- coop tendril fight (cut/enemies/tendril.lua), logging [TD] lines: the same, for the cut Tendril's rows, Shows and
-- spawn.
M.tendril=require('cut.enemies.tendril').new({log=function(m) print('[StellarCoop][TD] '..tostring(m)..'\n') end,
    ask=function(line) return M.ask(line)() end,status=function() return M.link and M.link.status() end})
-- The cut model viewer of coop leviathan and the other viewer commands (cut/enemies/leviathan.lua): its read, display
-- and free camera, logging [LV] lines. coop-leviathan.txt lets the next Lua load remove a display this one left and
-- give the player controller back. The free camera reads no key while the co-op menu or one of its boxes is open.
M.leviathan=require('cut.enemies.leviathan').new({
    log=function(m) print('[StellarCoop][LV] '..tostring(m)..'\n') end,
    store=M.link and M.link.store('coop-leviathan.txt'),
    blocked=function()
        return M.menu~=nil and (M.menu.is_open() or M.box.is_open() or M.code_box.is_open() or M.approval.is_open()
            or M.saves_ui.is_open() or M.open_screen()~=nil)
    end})
return require('cut.enemies.commands').new({coop_slot=M.coop_slot,leviathan=M.leviathan,lion=M.lion,gardener=M.gardener,
    tendril=M.tendril})
end,
}
