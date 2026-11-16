-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The session's console commands: coop host (as who_can_join says), invite, join, leave, status, report, copy, mark,
-- allow, deny and remove, block, unblock and blocked, coop match, mute and unmute, with coop revive test, coop travel,
-- coop saves and coop sbo.
-- main.lua builds them with new(o) at each Lua load and merges them into its command table, whose run() logs each
-- result and, after coop off, refuses all but status and report. o: main.lua's link, settings, puppet, ask (a line for
-- the native part), coop_slot and sbo, and group(), travel() and lobby (ui/lobby.lua's), read at each call: the
-- revive, the follow and the lobby's screens are built later, with the Steam link only.
local Session={}
-- Host by who_can_join: code (an invisible lobby with a join code), private (invited only), friends.
local HOSTS={code='host code',private='host private'}
function Session.new(o)
    local link,settings,puppet,ask,coop_slot=o.link,o.settings,o.puppet,o.ask,o.coop_slot
    local self={}
    -- The host's answers about a player (allow, deny: one who is not her Steam friend and waits; remove: anyone in the
    -- lobby), by SteamID, or by the 4 digits UE4SS.log shows after *** for it (core/mask.lua): the one player in the
    -- lobby whose SteamID ends in them.
    local function answer(verb)
        return function(id)
            if type(id)~='string' or not id:match('^%d+$') or #id>20 then
                return false,'Use: coop '..verb..' <SteamID>'
            end
            if #id==4 then
                local found
                for _,m in ipairs(link and link.members() or {}) do
                    if m.id:sub(-4)==id then
                        if found then
                            return false,'two players have a SteamID ending in '..id
                                ..': use the full SteamID from coop-status.txt'
                        end
                        found=m.id
                    end
                end
                if not found then return false,'no player in the lobby has a SteamID ending in '..id end
                id=found
            end
            return ask(verb..' '..id)()
        end
    end
    local twice=nil -- coop saves refresh and export: the request typed and when ({line=, at=}), until typed again.
    function self.host() return ask(HOSTS[settings and settings.who_can_join] or 'host')() end
    self.invite,self.leave,self.report,self.copy=ask('invite'),ask('leave'),ask('report'),ask('copy')
    -- Every word typed after mark (the console handler joins them), cleaned like a chat line; the native part numbers
    -- the mark, logs it and sends it to the friend. A console tool: no key, no text on screen.
    function self.mark(text)
        if not link then return false,'coop mark needs the Steam link' end
        text=require('session.chat').clean(text or '')
        return link.request(text~='' and 'mark '..text or 'mark')
    end
    self.allow,self.deny,self.remove=answer('allow'),answer('deny'),answer('remove')
    -- A player's chat lines dropped (mute) or heard again (unmute), in any lobby, for the game run.
    self.mute,self.unmute=answer('mute'),answer('unmute')
    -- The block list (coop-blocked.txt, which the native part keeps): block keeps a player out of every game you host,
    -- across game runs, as coop remove does; unblock takes one player off, or all; blocked counts them, since the file
    -- holds hashes and never a SteamID. unblock takes the 4 digits the logs show too, for a player blocked in this
    -- game run: the status's block= lines name those whole.
    self.block=answer('block')
    function self.unblock(id)
        if id=='all' then return ask('unblock all')() end
        if type(id)~='string' or not id:match('^%d+$') or #id>20 then return false,'Use: coop unblock <SteamID>|all' end
        if #id==4 then
            local found
            for full in (link and link.status() or ''):gmatch('\nblock=(%d+)') do
                if full:sub(-4)==id then
                    if found then
                        return false,'two players blocked in this game run have a SteamID ending in '..id
                            ..': use the full SteamID from coop-status.txt'
                    end
                    found=full
                end
            end
            if not found then
                return false,'no player blocked in this game run has a SteamID ending in '..id..': use the full SteamID'
            end
            id=found
        end
        return ask('unblock '..id)()
    end
    function self.blocked()
        local n=link and (link.status() or ''):match('\nblocked=(%d+)\n')
        if not n then return false,'no Steam link status yet' end
        return true,n..(n=='1' and ' player is' or ' players are')..' on your block list'
    end
    -- A lobby id, or a join code as the native part takes it.
    function self.join(lobby)
        if lobby and link then
            lobby=link.valid_lobby(lobby) and lobby or link.join_code(lobby)
            if not lobby then return false,'a lobby id is digits only, a join code 7 letters and digits' end
        end
        return ask(lobby and 'join '..lobby or 'join')()
    end
    -- Matches: search <mode> (join an open public match lobby of that mode, or host one), create <mode> (a private
    -- match lobby joined with its code), cancel (the search), end (the host's round in play), join <code> and leave
    -- (as coop join and coop leave). The native part checks the mode; search and create name the SBO lobby's room and
    -- hall (session/sbo.lua's lobby_words()).
    function self.match(sub,arg,extra)
        if extra==nil then
            if (sub=='search' or sub=='create') and arg~=nil then
                if not o.sbo then return false,'the Steam link needs the native part' end
                return ask('match '..sub..' '..arg..' '..o.sbo.lobby_words())()
            end
            if (sub=='cancel' or sub=='end') and arg==nil then return ask('match '..sub)() end
            if sub=='join' and arg~=nil then return self.join(arg) end
            if sub=='leave' and arg==nil then return self.leave() end
        end
        return false,'Use: coop match search|create <mode> | cancel | end | join <code> | leave'
    end
    -- test: the revive's solo probe at the death screen, on a co-op save only (session/group.lua says why not).
    function self.revive(sub,extra)
        if sub~='test' or extra~=nil then return false,'Use: coop revive test' end
        local group=o.group() -- main.lua builds it after the commands, with the Steam link only.
        if not group then return false,'the Steam link needs the native part' end
        local ok,why=coop_slot('coop revive test')
        if not ok then return false,why end
        return group.test()
    end
    -- host: as follow_key (the travel to the camp nearest the host, or always's start cancelled); probe <camp>: its
    -- solo test, the native call alone (session/travel.lua says why not).
    function self.travel(sub,arg,extra)
        local travel=o.travel() -- Likewise.
        if not travel then return false,'the Steam link needs the native part' end
        if sub=='host' and arg==nil then return travel.press() end
        if sub=='probe' and arg~=nil and extra==nil then return travel.probe(arg) end
        return false,'Use: coop travel host'
    end
    -- The co-op saves by hand (the question at the title asks for them): probe logs what the native part reads and the
    -- next copy pass's plan; convert makes the copies; coop makes them and switches the save name; main switches back;
    -- refresh <0-4> replaces that slot's co-op copy, played or not, with a new copy of the player's save (the native
    -- part backs the old one up first); export <0-4> <0-4> writes that co-op slot's copy over that save of the player's
    -- (backed up first), to play on without the mod, and the native part refuses a copy that holds the mod's items or
    -- stands in Matrix XIII, or a developer save coop shortcut load wrote. Each is asked once typed twice the same
    -- within 10 s. The native part refuses all but probe off the title screen, and says why in coop-link.log.
    local function confirmed(line)
        local now=os.clock()
        if twice and twice.line==line and now-twice.at<=10 then
            twice=nil
            return true
        end
        twice={line=line,at=now}
        return false
    end
    function self.saves(sub,extra,more,rest)
        local function slot(word) return type(word)=='string' and word:match('^[0-4]$')~=nil end
        if sub=='refresh' and more==nil and slot(extra) then
            if not confirmed('saves refresh '..extra) then
                return false,'coop saves refresh '..extra..' replaces the co-op copy StellarBladeCoop0'..extra..'.sav, '
                    ..'played in co-op or not, with a new copy of your save StellarBladeSave0'..extra..'.sav (the old '
                    ..'copy goes to StellarCoopBackups first): type it again within 10 s to go on'
            end
            return ask('saves refresh '..extra)()
        end
        if sub=='export' and rest==nil and slot(extra) and slot(more) then
            if not confirmed('saves export '..extra..' '..more) then
                return false,'coop saves export '..extra..' '..more..' writes your co-op save StellarBladeCoop0'..extra
                    ..'.sav over your own save StellarBladeSave0'..more..'.sav (your save there, if any, goes to '
                    ..'StellarCoopBackups first), to play on without the mod; it is refused while that co-op save '
                    ..'holds the mod\'s items or stands in Matrix XIII, and for a developer save coop shortcut load '
                    ..'wrote: type it again within 10 s to go on'
            end
            return ask('saves export '..extra..' '..more)()
        end
        if extra~=nil or not ({probe=true,convert=true,coop=true,main=true})[sub or ''] then
            return false,'Use: coop saves probe | convert | coop | main | refresh <0-4> | export <0-4> <0-4>'
        end
        return ask('saves '..sub)()
    end
    -- The SBO lobby by hand (session/sbo.lua, o.sbo: with the Steam link only): enter, leave, status, hop and back (the
    -- arena round trip), view and view set (the menu camera's view), seq (a light sequence) and parts (the lobby's SB
    -- widget parts made once each). Every word says the lobby is off while sbo_lobby=off. Left out of coop's usage
    -- line, as a test tool.
    function self.sbo(word,extra,more)
        if not o.sbo then return false,'the Steam link needs the native part' end
        if not settings.sbo_lobby then return false,require('session.sbo').OFF end
        if more==nil then
            if extra==nil and ({enter=true,leave=true,status=true,hop=true,back=true,view=true})[word or ''] then
                return o.sbo[word]()
            end
            if word=='view' and extra=='set' then return o.sbo.view_set() end
            if word=='seq' and extra then return o.sbo.seq(extra) end
            if word=='parts' and extra==nil and o.lobby then return o.lobby.parts_check() end
        end
        return false,'Use: coop sbo enter | leave | status | hop | back | view [set] | seq <alias> | parts'
    end
    -- The native part's status on one line, our CNS packs in words when there are some, then the ghost's.
    function self.status()
        local text=link and link.status()
        if not text then return false,'no Steam link status yet; '..puppet.status() end
        local cns=link.cns()
        return true,text:gsub('[\r\n]+',' | ')..(cns and cns..' | ' or '')..puppet.status()
    end
    return self
end
return Session
