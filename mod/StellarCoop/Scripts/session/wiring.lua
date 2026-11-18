-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The online session's wiring (session/): the chat, the phone booths, the session notices, the session screens.
return {
uses={'partner','lobby'},
exports={'chat','booth','paks_notice','dlcs_notice','cycle_notice','box','code_box','sessions','create','approval'},
new=function(M)
local print,log=M.print,M.log
-- The session chat's model (session/chat.lua, memory only, never logged): her lines come from coop-chat.txt, taken
-- every 250 ms so the file never stays on disk, session or not, and each frame while a race is armed (her race lines
-- come in it too); ours leave through coop-say.txt in the 250 ms loop, or stay on our screen alone in the SBO lobby.
-- Its clock is main/base.lua's chat_clock. session/chat.lua's view shows and sends the lines (box, its build step).
M.chat=require('session.chat').new(nil,M.settings and M.settings.chat)
-- The camp phone booths near EVE (session/booth.lua): the menu key opens the co-op line at one.
M.booth=require('session.booth').new(log)
if M.link then
    local T=require('ui.text')
    -- A notice naming mods (a list of core/link.lua's mods()): the file names (no folders) of the first two that fit,
    -- then (+n) for the others (ui/text.lua's T.mods).
    local mods_notice=T.mods
    -- The friend's game loads other .pak mods than ours (the native part compares a hash of them): one notice a session.
    -- With their names (her mod_names=on), it names those she uses and we lack, then those we have in another version,
    -- since parts of her outfit from them look different here; with neither, or without names, the two counts.
    local paks_said=false
    function M.paks_notice()
        local paks,mods=M.link.paks(),M.link.mods()
        if M.link.mode()=='none' then paks_said=false
        elseif paks and not paks.same and not paks_said then
            paks_said=true
            local missing,other=mods and mods.missing.n>0,mods and mods.other.n>0
            if missing then
                M.tell(function(w) return mods_notice(w.fight.mods_missing,M.her_name(w),mods.missing) end)
            end
            if other then M.tell(function(w) return mods_notice(w.fight.mods_other,M.her_name(w),mods.other) end) end
            if not missing and not other then
                M.tell(function(w) return w.fight.paks:format(M.her_name(w),paks.hers,paks.ours) end)
            end
        end
    end
    -- The DLCs installed on her PC against ours (link.dlcs()): when they differ, one notice a session names hers we
    -- lack and ours she lacks (ui/text.lua's T.dlcs).
    local dlcs_said=false
    function M.dlcs_notice()
        local dlcs=M.link.dlcs()
        if M.link.mode()=='none' then dlcs_said=false
        elseif dlcs and not dlcs.same and not dlcs_said then
            dlcs_said=true
            M.tell(function(w) return T.dlcs(w,M.her_name(w),dlcs.missing,dlcs.extra) end)
        end
    end
    -- Her New Game+ count and difficulty against ours (link.cycles()): the guest compares with the host, the host with
    -- each member. One notice a member while the two differ, one more each time the values change (ui/text.lua's
    -- T.cycle). None before ours is read, nor in a match lobby or the SBO lobby, where no enemy or quest is shared.
    local cycles_seen={} -- Her SteamID to the values as last compared this session.
    function M.cycle_notice()
        local mode=M.link.mode()
        if mode=='none' then cycles_seen={} return end
        local mine,list=M.link.cycles()
        if not mine or M.link.match() or M.sbo.in_lobby() then return end
        local host=mode=='guest' and M.link.host()
        for _,m in ipairs(list) do
            if mode=='host' or (host and m.id==host.id) then
                local seen=table.concat({m.count,m.difficulty,mine.count,mine.difficulty},' ')
                if cycles_seen[m.id]~=seen and (m.count~=mine.count or m.difficulty~=mine.difficulty) then
                    M.tell(function(w) return T.cycle(w,M.her_name(w,m.name),m,mine) end)
                end
                cycles_seen[m.id]=seen
            end
        end
    end
end
return require('session.commands').new({link=M.link,settings=M.settings,
    puppet={status=function() return M.puppet.status() or '' end},ask=M.ask,create=function() return M.create end})
end,
build={
box=function(M,Ui)
    M.box=require('session.chat').view({kit=M.kit,model=M.chat,settings=M.settings,theme=Ui.THEME,
        covered=function() return M.menu.is_open() end})
end,
code_box=function(M,Ui)
    local Join=require('session.join')
    M.code_box=Join.box({kit=M.kit,link=M.link,settings=M.settings,theme=Ui.THEME,run=function(name,...)
        local ok,why=M.run(name,...)
        if ok and name=='join' then M.lobby_last('join') end
        return ok,why
    end})
end,
sessions=function(M,Ui)
    -- The Sessions screen (session/ui/sessions.lua), which the menu's Find a session opens: the session list's rows
    -- read fresh at each call, with our protocol and game build from the status's first line; its searches and joins go
    -- to the native part as the lobby's requests do. SB's words in the game's language, none under ui_language=english.
    M.sessions=require('session.ui.sessions').new({kit=M.kit,words=M.words,log=M.ui_log,
        view=function()
            local first=('\n'..(M.link.status() or '')):match('\n(mod=[^\n]*)') or ''
            local search,rows=M.link.list()
            return {search=search,rows=rows,match=M.link.match(),role=M.link.mode() or 'none',
                proto=first:match(' proto=(%d+)'),build=first:match(' build=(%d+)')}
        end,
        act=function(a) M.report(M.link.request(a.request)) end,game_text=M.game_words})
end,
create=function(M,Ui)
    -- The Create a session screen (session/ui/create.lua), which Host a session and coop host alone open
    -- (session/commands.lua reads create()): the settings in effect, written back as the Options page writes them;
    -- Start hosts with its Who can join word through coop host.
    local Options=require('ui.kit.model')
    M.create=require('session.ui.create').new({kit=M.kit,words=M.words,log=M.ui_log,
        view=function()
            return {values=Options.values(M.settings),readable=M.link.settings_text()~=nil,role=M.link.mode() or 'none'}
        end,
        act=function(a)
            if a.set then return M.menu.set(a.set,a.value) end
            return M.run('host',a.host)
        end})
    local Join=require('session.join')
    M.approval=Join.ask({kit=M.kit,link=M.link,settings=M.settings,run=M.run,say=M.say,log=M.ui_log,
        game_text=M.game_words,menu=M.menu,chat=M.box,guide=M.guide})
end,
},
}
