-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The wiring of EVE's cut moves (eve/): coop wear, glide, emote, fly and chainspin, with the emote wheel.
return {
uses={'fight.bosses','closet'},
exports={'wear','glide','emote','flight','emote_wheel','eve_page'},
new=function(M)
local print,log=M.print,M.log
-- coop wear (eve/wear.lua), logging [WR] lines: coop-wear.txt lets the next Lua load give EVE the game's meshes
-- back.
-- No look goes on again while the game is paused or shows one of its screens (its wardrobe among them). No suit goes
-- on while Stellar Closet has a look on EVE or waits to wear a kept one again (an off closet module's stub reads nil);
-- a hair still does, as the closet never sets SBHair. The closet refuses the other way round while a suit is worn
-- (closet/wiring.lua reads M.wear.worn).
M.wear=require('eve.wear').new({log=function(m) print('[StellarCoop][WR] '..tostring(m)..'\n') end,
    store=M.link and M.link.store('coop-wear.txt'),paused=function() return M.kit~=nil and M.kit.paused(true) end,
    closet=function() return M.closet.worn() end})
-- coop glide (eve/glide.lua), logging [GL] lines: EVE's bGlide set while Jump is held in the air, on a co-op save.
M.glide=require('eve.glide').new({log=function(m) print('[StellarCoop][GL] '..tostring(m)..'\n') end,
    slot=function() return M.coop_slot('coop glide') end})
-- coop emote (eve/emote.lua), logging [EM] lines: one of EVE's clips until she moves, played by the native part
-- (its anim request and the status line's anim field), else as a montage. None starts while she rides.
M.emote=require('eve.emote').new({log=function(m) print('[StellarCoop][EM] '..tostring(m)..'\n') end,
    ask=function(line) return M.ask(line)() end,status=function() return M.link and M.link.status() end,
    riding=function() return M.riding() end})
-- The emote wheel (eve/ui/wheel.lua), logging [EM] wheel: lines: coop emote's clips on the kit's wheel (M.wheel, built
-- by main/ui.lua with the Steam link only), opened by emote_key or D-pad Left held (main/keys.lua, main/input.lua).
M.emote_wheel=require('eve.ui.wheel').new({wheel=function() return M.wheel end,words=M.words,game=M.game_words,
    busy=function() return M.emote.busy() end,run=function(...) return M.run(...) end,
    log=function(m) print('[StellarCoop][EM] '..tostring(m)..'\n') end,say=function(text,en) M.say(text,en) end})
-- coop fly's keys (eve/flight.lua), logging [FL] lines: R2 alone flies, Shift with a direction evades.
M.flight=require('eve.flight').new({log=function(m) print('[StellarCoop][FL] '..tostring(m)..'\n') end})
-- coop chainspin (eve/chainspin.lua), logging [CS] lines: the cut ChainSpin's rows through coop lion, then the
-- request.
local chainspin=require('eve.chainspin').new({log=function(m) print('[StellarCoop][CS] '..tostring(m)..'\n') end,
    status=function() return M.link and M.link.status() end,rows=function(done)
        if M.off_modules['fight.bosses'] then return false,'coop lion is not loaded: its rows carry the ChainSpin' end
        return M.lion.rows(done)
    end})
-- The co-op menu's TEST TOOLS page of coop fly, coop slowmo and coop glide (eve/ui/tools.lua): fly and slowmo as the
-- native part last took them in this Lua load (switched), glide as eve/glide.lua has it.
local switched={}
M.eve_page=require('eve.ui.tools').new({run=function(...) return M.run(...) end,
    on=function(name) if name=='glide' then return M.glide.active() end return switched[name]==true end})
return require('eve.commands').new({ask=M.ask,chainspin=chainspin,coop_slot=M.coop_slot,emote=M.emote,
    flight=M.flight,glide=M.glide,riding=function() return M.riding() end,wear=M.wear,
    switched=function(name,on) switched[name]=on end})
end,
}
