-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The session's console commands: coop host (as who_can_join says, or by its word), invite, join, list, leave,
-- status, report, copy, mark, allow, deny and remove, block, unblock and blocked, mute and unmute.
-- main.lua builds them with new(o) at each Lua load and merges them into its command table, whose run() logs each
-- result and, after coop off, refuses all but status and report. o: main.lua's link, settings, puppet and ask (a line
-- for the native part); create(), read at each call: the Create a session screen is built later, with the Steam link
-- only.
local Session={}
-- who_can_join's words, which the native part's host request takes as they are: public (a Public lobby the session
-- list finds), friends (Friends only), invitation (a Steam invite or the join code) and closed (Private: nobody joins).
local WHO={public=true,friends=true,invitation=true,closed=true}
function Session.new(o)
    local link,settings,puppet,ask=o.link,o.settings,o.puppet,o.ask
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
    -- coop host <word> hosts at once with that word. coop host alone opens the Create a session screen when it can
    -- open (o.create(): the screen once built, whose open() is true and a message when it opened), else hosts at once
    -- as who_can_join says. friends_ask=on adds ask under public and invitation: Steam friends wait for the host's
    -- answer too. max_players ends the line (2 to 4: the lobby's room). While we host, the native part refuses a word
    -- other than the session's (leave first).
    function self.host(word,extra)
        if extra~=nil or word~=nil and not WHO[word] then
            return false,'Use: coop host [public|friends|invitation|closed]'
        end
        if word==nil then
            local screen=o.create and o.create()
            if screen then
                local opened,message=screen.open()
                if opened then return true,message end
            end
            word=settings and settings.who_can_join or 'public'
        end
        local friends_wait=settings and settings.friends_ask and (word=='public' or word=='invitation')
        return ask('host '..word..(friends_wait and ' ask' or '')..' '..(settings and settings.max_players or 4))()
    end
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
    -- A lobby id, a join code as the native part takes it, or a row of the session list (1 to 99: a Steam lobby id is
    -- far bigger).
    function self.join(lobby)
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
    -- The session list by hand: coop list public or coop list friends asks the native part for a search (one at a
    -- time, 5 s apart at least, none in a lobby: it says why it refuses); coop list alone shows the last list's rows,
    -- numbered for coop join <row>, or searches the Public sessions when there is none.
    function self.list(tab,extra)
        if extra~=nil or tab~=nil and tab~='public' and tab~='friends' then
            return false,'Use: coop list [public|friends]'
        end
        local search,rows
        if link then search,rows=link.list() end
        if tab or not search then return ask('list '..(tab or 'public'))() end
        local out={}
        for i,r in ipairs(rows) do
            out[i]=string.format('%d. %s %s %s %s%s%s%s',i,r.name~='' and r.name or '?',r.players,
                r.ping and r.ping..' ms' or '- ms',r.zone or '-',r.camp and ' '..r.camp or '',
                r.rules and ' rules '..r.rules or '',r.pal and ' (Steam friend)' or '')
        end
        return true,string.format('list %s %s, %d row%s%s',search.tab,search.state,#out,#out==1 and '' or 's',
            #out>0 and ': '..table.concat(out,' | ') or '')
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
