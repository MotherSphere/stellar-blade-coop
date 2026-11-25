-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The cut menus' wiring (cutmenus/): coop devmenu, coop devinfo and coop gift, with the developer menu's page.
return {
uses={},
exports={'devmenu','mailbox','devmenu_page'},
new=function(M)
local print,log=M.print,M.log
-- coop devmenu (cutmenus/devmenu.lua), logging [DM] lines: the developer menu's working rows, through the same call.
M.devmenu=require('cutmenus.devmenu').new({log=function(m) print('[StellarCoop][DM] '..tostring(m)..'\n') end,
    status=function() return M.link and M.link.status() end,store=M.link and M.link.store('coop-devmenu.txt')})
-- coop gift (cutmenus/mailbox.lua), logging [GF] lines: SB's cut mailbox as a co-op gift box, with the Steam link
-- only. Its tick runs in the 250 ms loop of main/pass.lua, her gift lines come through inbox(), and coop gift runs on a
-- co-op save only (cutmenus/commands.lua). Its notices come in the menu's words (tell, ui/text.lua's gift table). Its
-- FName and pause rules are the bike's paid fetch's (main/base.lua's fname and logic_paused).
M.mailbox=M.link and require('cutmenus.mailbox').new({
    log=function(m) print('[StellarCoop][GF] '..tostring(m)..'\n') end,
    tell=M.tell,status=function() return M.link.status() end,
    request=function(line) return M.link.request(line) end,read=function(name) return M.link.read_file(name) end,
    write=function(name,text) return M.link.write_file(name,text) end,friend=function() return M.link.friend() end,
    loopback=function() return M.link.loopback() end,store=M.link.store('coop-gift-toast.txt'),
    paused=M.logic_paused,name=M.fname}) or nil
-- The co-op menu's TEST TOOLS page of coop devmenu and coop devinfo (cutmenus/ui/devmenu.lua): the developer panel as
-- the native part last took it in this Lua load (panel).
local panel='off'
M.devmenu_page=require('cutmenus.ui.devmenu').new({run=function(...) return M.run(...) end,devmenu=M.devmenu,
    panel=function() return panel end})
return require('cutmenus.commands').new({ask=M.ask,coop_slot=M.coop_slot,devmenu=M.devmenu,mailbox=M.mailbox,
    panel=function(which) panel=which end})
end,
}
