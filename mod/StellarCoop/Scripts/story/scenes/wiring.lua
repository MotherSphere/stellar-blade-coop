-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The cut scenes' wiring (story/scenes/): coop scene and coop lines.
return {
uses={'online.session','world.maps.matrix13'},
exports={'scene','cut_lines'},
new=function(M)
local print,log=M.print,M.log
-- coop scene (story/scenes/scene.lua), logging [SC] lines: two cut scenes through two of SB's theater rows.
M.scene=require('story.scenes.scene').new({log=function(m) print('[StellarCoop][SC] '..tostring(m)..'\n') end,
    status=function() return M.link and M.link.status() end})
-- coop lines (story/scenes/lines.lua), logging [LN] lines: cut scenes' unvoiced subtitles in the chat's feed, and
-- unused voice takes played as 2D sounds.
M.cut_lines=require('story.scenes.lines').new({log=function(m) print('[StellarCoop][LN] '..tostring(m)..'\n') end,
    say=function(text) return M.box~=nil and M.box.say(text) end,
    ready=function() return M.kit~=nil and M.kit.ready() end})
return require('story.scenes.commands').new({coop_slot=M.coop_slot,lily=require('main.loader').get(M,
    'world.maps.matrix13','lily'),
    lines=M.cut_lines,scene=M.scene})
end,
}
