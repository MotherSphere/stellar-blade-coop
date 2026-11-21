-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The UI on the Uplink kit, with the Steam link only: the kit, the guide, the menu, each module's groups between.
return function(M)
local print,log=M.print,M.log
-- The chat's box and feed (online/session/chat.lua's view), the partner HUD (online/partner/hud.lua's), Night
-- Operation's card and result panel (online/modes/nightop/run.lua's), score attack's card, board and result panel
-- (online/modes/scoreattack/ui/board.lua), the code box (online/session/join.lua), the co-op menu (ui/kit/menu.lua),
-- the host's question (online/session/join.lua) and the co-op saves' question (online/saves/saves.lua) on the Uplink
-- kit (ui/kit/kit.lua), with the Steam link only: its root is built in a world or on the title screen, after one
-- lookup a 250 ms tick. The feed and the HUDs first: the menu draws over them, the questions over all.
-- Each module's groups are its build steps (main/loader.lua's build), run here at their old places.
if M.settings then
    local Ui=require('ui.kit.kit')
    M.kit=Ui.kit({log=M.ui_log,store=M.link.store('coop-ui.txt'),scale=M.settings.ui_scale,sounds=M.settings.ui_sounds,
        uidev=M.link.uidev})
    require('main.loader').build(M,'online.session','box',Ui)
    require('main.loader').build(M,'online.partner','hud',Ui)
    require('main.loader').build(M,'online.modes.nightop','hud',Ui)
    require('main.loader').build(M,'online.modes.scoreattack','hud',Ui)
    require('main.loader').build(M,'online.modes.race','hud',Ui)
    require('main.loader').build(M,'world.maps.matrix13','hud',Ui)
    require('main.loader').build(M,'online.session','code_box',Ui)
    -- The first-launch guide (ui/kit/guide.lua): the menu's Guide row and coop guide open it; in front of the co-op
    -- saves' question, it takes the question's keys, pad, clicks and loops first (front), and the question waits for
    -- it. It never opens over another co-op panel (busy).
    M.guide=require('ui.kit.guide').new({kit=M.kit,link=M.link,settings=M.settings,theme=Ui.THEME,log=log,
        folder=M.folder,
        busy=function()
            return M.menu.is_open() or M.box.is_open() or M.code_box.is_open() or M.approval.is_open()
                or M.saves_ui.is_open() or M.open_screen()~=nil
        end})
    require('main.loader').build(M,'online.session','sessions',Ui)
    -- While the online sessions are off, Find a session's open refuses: the menu logs why.
    M.menu=require('ui.kit.menu').new({kit=M.kit,link=M.link,settings=M.settings,look=M.look,
        puppet=require('main.loader').view(M,'puppet'),run=M.run,log=log,version=M.VERSION,
        chat=require('main.loader').view(M,'box'),code=require('main.loader').view(M,'code_box'),guide=M.guide,
        sessions=setmetatable({open=function(...)
            if M.off_modules['online.session'] then return false,'online sessions are off until the mod reloads' end
            return M.sessions.open(...)
        end},{__index=require('main.loader').view(M,'sessions')})})
    require('main.loader').build(M,'online.session','create',Ui)
    require('main.loader').build(M,'online.saves','saves',Ui)
    require('main.loader').build(M,'online.lobby','screens',Ui)
end
end
