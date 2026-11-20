-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The cut menus' console commands. coop devmenu, the developer menu's rows that still work (left out of the usage
-- line): its list on any save, a row on a co-op save only. coop devinfo, two read-only panels of the game's developer
-- UI (left out too), on any save. coop gift, the cut mailbox as a co-op gift box (cutmenus/mailbox.lua, o.mailbox,
-- built with the Steam link only), runs on a co-op save only: every word of it. cutmenus/wiring.lua builds it with
-- new(o) at each Lua load and main/loader.lua merges it into the command table. o: coop_slot, ask (a native request;
-- coop devinfo), devmenu (cutmenus/devmenu.lua's) and mailbox.
local Menus={}
function Menus.new(o)
    local coop_slot=o.coop_slot
    local self={}
    function self.gift(sub,a,b,c)
        if not o.mailbox then return false,'coop gift needs the Steam link' end
        local ok,why=coop_slot('coop gift')
        if not ok then return false,why end
        return o.mailbox.command(sub,a,b,c)
    end
    function self.devmenu(name,extra)
        if extra==nil and o.devmenu.row(name) then
            local ok,why=coop_slot('coop devmenu '..name)
            if not ok then return false,why end
        end
        return o.devmenu.command(name,extra)
    end
    -- coop devinfo quest|player|off: the native part opens SB's quest debugger or player info panel through the
    -- game's UI manager, or closes them (game/dev_panels.h). Both only read, so any save.
    function self.devinfo(which,extra)
        if extra~=nil or which~='quest' and which~='player' and which~='off' then
            return false,'Use: coop devinfo quest|player|off'
        end
        return o.ask('devinfo '..which)()
    end
    return self
end
return Menus
