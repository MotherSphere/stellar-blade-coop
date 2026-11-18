-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The SBO lobby's console commands: coop match and coop sbo. lobby/wiring.lua builds them with new(o) at each Lua load
-- and main/loader.lua merges them into the command table. o: link, settings, ask (a line for the native part) and sbo;
-- lobby(), lobby/ui/lobby.lua's screens, read at each call: they are built later, with the Steam link only.
local Lobby={}
function Lobby.new(o)
    local link,settings,ask=o.link,o.settings,o.ask
    local self={}
    -- coop match join's own copy of coop join (session/commands.lua): a lobby id, a join code as the native part takes
    -- it, or a row of the session list (1 to 99: a Steam lobby id is far bigger).
    local function join(lobby)
        if lobby and link then
            local n=lobby:match('^%d%d?$') and tonumber(lobby)
            if n then
                local _,rows=link.list()
                if not rows[n] then return false,'the session list has no row '..lobby..': coop list shows it' end
                lobby=rows[n].lobby
            else
                lobby=link.valid_lobby(lobby) and lobby or link.join_code(lobby)
                if not lobby then return false,'a lobby id is digits only, a join code 7 letters and digits' end
            end
        end
        return ask(lobby and 'join '..lobby or 'join')()
    end
    -- Matches: search <mode> (join an open public match lobby of that mode, or host one), create <mode> (a private
    -- match lobby joined with its code), cancel (the search), end (the host's round in play), join <code> and leave
    -- (as coop join and coop leave). The native part checks the mode; search and create name the SBO lobby's room and
    -- hall (lobby/sbo.lua's lobby_words()).
    function self.match(sub,arg,extra)
        if extra==nil then
            if (sub=='search' or sub=='create') and arg~=nil then
                if not o.sbo then return false,'the Steam link needs the native part' end
                return ask('match '..sub..' '..arg..' '..o.sbo.lobby_words())()
            end
            if (sub=='cancel' or sub=='end') and arg==nil then return ask('match '..sub)() end
            if sub=='join' and arg~=nil then return join(arg) end
            if sub=='leave' and arg==nil then return ask('leave')() end
        end
        return false,'Use: coop match search|create <mode> | cancel | end | join <code> | leave'
    end
    -- The SBO lobby by hand (lobby/sbo.lua, o.sbo: with the Steam link only): enter, leave, status, hop and back (the
    -- arena round trip), view and view set (the menu camera's view), seq (a light sequence) and parts (the lobby's SB
    -- widget parts made once each). Every word says the lobby is off while sbo_lobby=off. Left out of coop's usage
    -- line, as a test tool.
    function self.sbo(word,extra,more)
        if not o.sbo then return false,'the Steam link needs the native part' end
        if not settings.sbo_lobby then return false,require('lobby.sbo').OFF end
        if more==nil then
            if extra==nil and ({enter=true,leave=true,status=true,hop=true,back=true,view=true})[word or ''] then
                return o.sbo[word]()
            end
            if word=='view' and extra=='set' then return o.sbo.view_set() end
            if word=='seq' and extra then return o.sbo.seq(extra) end
            if word=='parts' and extra==nil and o.lobby() then return o.lobby().parts_check() end
        end
        return false,'Use: coop sbo enter | leave | status | hop | back | view [set] | seq <alias> | parts'
    end
    return self
end
return Lobby
