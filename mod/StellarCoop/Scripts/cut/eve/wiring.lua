-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The wiring of EVE's cut moves (cut/eve/): coop wear, glide, emote, fly and chainspin.
return {
uses={'cut.enemies'},
exports={'wear','glide','emote','flight'},
new=function(M)
local print,log=M.print,M.log
-- coop wear (cut/eve/wear.lua), logging [WR] lines: coop-wear.txt lets the next Lua load give EVE the game's meshes
-- back.
-- No look goes on again while the game is paused or shows one of its screens (its wardrobe among them).
M.wear=require('cut.eve.wear').new({log=function(m) print('[StellarCoop][WR] '..tostring(m)..'\n') end,
    store=M.link and M.link.store('coop-wear.txt'),paused=function() return M.kit~=nil and M.kit.paused(true) end})
-- coop glide (cut/eve/glide.lua), logging [GL] lines: EVE's bGlide set while Jump is held in the air, on a co-op save.
M.glide=require('cut.eve.glide').new({log=function(m) print('[StellarCoop][GL] '..tostring(m)..'\n') end,
    slot=function() return M.coop_slot('coop glide') end})
-- coop emote (cut/eve/emote.lua), logging [EM] lines: one of EVE's clips until she moves, played by the native part
-- (its anim request and the status line's anim field), else as a montage. None starts while she rides.
M.emote=require('cut.eve.emote').new({log=function(m) print('[StellarCoop][EM] '..tostring(m)..'\n') end,
    ask=function(line) return M.ask(line)() end,status=function() return M.link and M.link.status() end,
    riding=function() return M.riding() end})
-- coop fly's keys (cut/eve/flight.lua), logging [FL] lines: R2 alone flies, Shift with a direction evades.
M.flight=require('cut.eve.flight').new({log=function(m) print('[StellarCoop][FL] '..tostring(m)..'\n') end})
-- coop chainspin (cut/eve/chainspin.lua), logging [CS] lines: the cut ChainSpin's rows through coop lion, then the
-- request.
local chainspin=require('cut.eve.chainspin').new({log=function(m) print('[StellarCoop][CS] '..tostring(m)..'\n') end,
    status=function() return M.link and M.link.status() end,rows=function(done) return M.lion.rows(done) end})
return require('cut.eve.commands').new({ask=M.ask,chainspin=chainspin,coop_slot=M.coop_slot,emote=M.emote,
    flight=M.flight,glide=M.glide,riding=function() return M.riding() end,wear=M.wear})
end,
}
