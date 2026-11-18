-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Matrix XIII's wiring (world/maps/matrix13/): coop mxiii's travel, Lily's signal with its talks and Mila, the talks'
-- HUD.
return {
uses={'story.scenes','online.group','fight.bosses'},
exports={'mxiii','talks','lily'},
new=function(M)
local print,log=M.print,M.log
-- coop mxiii [30] (world/maps/matrix13/level/travel.lua), logging [MX] lines: Matrix XIII's camp rows asked of the
-- native part, then the follow's camp travel (read at each call: online/group/wiring.lua builds it), once the zMXIII_P
-- test pak is found under SB/Content/Paks; coop mxiii leave, the follow's probe to the camp EVE respawned at before
-- coop mxiii, or another camp this save has activated. The same rows alone at the title, before any save loads, while
-- the game uses the co-op save files (main/pass.lua: mxiii.title), then its spawn, loot and mechanism rows and the
-- Lion's and the Gardener's. In world 2800 its tick spawns the ladders, ledges and ropes
-- (world/maps/matrix13/level/move.lua) and fixes the bosses the game spawns (world/maps/matrix13/level/boss.lua, with
-- coop lion's and coop gardener fight's instances, read at each call); coop mxiii boss is their key-0 fallback, and
-- coop mxiii warp <n|name> puts EVE on one of the old warp switches' arrival points (a test fallback).
M.mxiii=require('world.maps.matrix13.level.travel').new({
    log=function(m) print('[StellarCoop][MX] '..tostring(m)..'\n') end,
    ask=function(line) return M.ask(line)() end,status=function() return M.link and M.link.status() end,
    travel=require('main.loader').get(M,'online.group','travel'),paks=require('core.pak_gate').paks_of(M.folder),
    read=require('core.link').files.read,lion=require('main.loader').get(M,'fight.bosses','lion'),
    gardener=require('main.loader').get(M,'fight.bosses','gardener')})
-- Lily's signal (world/maps/matrix13/quest/on_time.lua, experimental), logging [LY] lines: on a co-op save, solo, with
-- the zMXIII_P test pak, in Phase 5 the mod's prologue starts and her choice list offers "The other signal"; its pick
-- plays the prologue talk, starts the mod's quest "On Time" and runs coop mxiii's travel; coop lily signal|talk|hold by
-- hand.
-- Ticked in the 250 ms loop of main/pass.lua (with the Steam link only), after coop off too: coop off puts her list
-- back. Its rows also go in at the title on the co-op save files, with the test pak only (lily.title). Its talks
-- (world/maps/matrix13/quest/subtitles.lua) play through coop scene's rows, ticked each frame.
local function lily_log(m) print('[StellarCoop][LY] '..tostring(m)..'\n') end
-- While story.scenes is off, talk refuses (not ours): the talks then show in the kit's lines.
M.talks=require('world.maps.matrix13.quest.subtitles').new({log=lily_log,scene=setmetatable({talk=function(...)
    if M.off_modules['story.scenes'] then return false,'coop scene is off until the mod reloads',false end
    return M.scene.talk(...)
end},{__index=require('main.loader').view(M,'scene')})})
-- Mila's body (world/maps/matrix13/level/mila.lua): placed by the zone talks, posed by coop mxiii mila
-- (world/maps/matrix13/commands.lua).
local mila=require('world.maps.matrix13.level.mila').new({log=lily_log,
    read=function(name) return M.link and M.link.read_file(name) end,
    write=function(name,text) if M.link then return M.link.write_file(name,text) end end})
M.lily=require('world.maps.matrix13.quest.on_time').new({log=lily_log,
    status=function() return M.link and M.link.status() end,ask=function(line) return M.ask(line)() end,
    mode=function() return M.link and M.link.mode() end,paused=function() return M.kit~=nil and M.kit.paused(true) end,
    travel=function() return M.commands.mxiii() end,paks=require('core.pak_gate').paks_of(M.folder),
    read=require('core.link').files.read,talks=M.talks,
    zones=require('world.maps.matrix13.quest.zone_talks').new({log=lily_log,talks=M.talks,
        plan=require('world.maps.matrix13.quest.on_time').plan,
        read=function(name) return M.link and M.link.read_file(name) end,
        write=function(name,text) if M.link then return M.link.write_file(name,text) end end,mila=mila})})
return require('world.maps.matrix13.commands').new({coop_slot=M.coop_slot,lily=M.lily,mila=mila,mxiii=M.mxiii})
end,
build={
hud=function(M,Ui)
    M.talks.hud({kit=M.kit,theme=Ui.THEME}) -- The kit version of Lily's talks.
end,
},
}
