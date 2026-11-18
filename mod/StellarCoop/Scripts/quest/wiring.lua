-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The shared quests' wiring (quest/): the reload kill switch, the notices and the menu row's asks.
return {
uses={},
exports={'quest_notices','quests_asks'},
new=function(M)
local print,log=M.print,M.log
-- shared_quests=on: coop quests on asked once a load, as soon as the native part judged the slot, as coop fight on is;
-- it then waits there for a friend and a co-op save. coop quests off before then cancels the ask. The co-op menu's row
-- asks it again (on) or asks coop quests off at once while it waits or runs (off); quests_wanted: the value last acted
-- on. shared_quests=off at a reload (Ctrl+R) ends a coop quests on an earlier load asked, waiting or running; a probe,
-- record or replay goes on.
local quests_auto=M.settings~=nil and M.settings.shared_quests
local quests_wanted=quests_auto
if M.settings and not M.settings.shared_quests and not M.off
    and ('\n'..(M.link.status() or '')):find('\nquests=%a+ mode=on ') then
    local ok,why=M.ask('quests off')()
    log((ok and 'OK: ' or 'STOP: ')..'shared_quests=off: '..tostring(why))
end
if M.link then
    -- The shared quests' notices (Phase 12), in the menu's language: from the quests= line, on with her each time both
    -- sides come on, her side off while ours runs, a wait for a co-op save (coop quests on, a friend linked and a main
    -- save loaded, so not at the title or during a load) and stopped for the run, each once as it starts; and each
    -- quest note once (link.quest_notes): her quest ahead (in the host's words or hers, by our role), behind the host,
    -- a step waiting for its zone, a Request to hand in at her board, a kill step, and coop quests force's answers. A
    -- Request not on her board yet and a step no zone can place show in coop quests status only. With several guests,
    -- the host's on notice names the first whose side is on (with=) and his ahead notice the guest whose line it is.
    local QUEST_NOTES={ahead=true,behind=true,zone=true,board=true,kill=true,forced=true,forced_warp=true,
        not_forced=true}
    local quests_was,quests_with,quests_role=nil,false,nil
    local function member_name(id) local m=id and M.link.member(id); return m and m.name end
    function M.quest_notices()
        local line=M.link.quests()
        if line then
            local state,why,partner=line:match('^quests=(%a+)'),line:match(' why=(%a+)'),line:match(' partner=(%a+)')
            local with=state=='on' and partner=='on'
            if with and not quests_with then
                local name=member_name(line:match(' with=(%d+)'))
                M.tell(function(w) return w.quests.on:format(M.her_name(w,name)) end)
            elseif quests_with and state=='on' and partner=='off' then
                M.tell(function(w) return w.quests.partner_off:format(M.her_name(w)) end)
            end
            local now=state..(why and ' '..why or '')..((M.slot_line() or ''):find('^slot=main ') and ' main' or '')
            if now=='waiting save main' and quests_was~=now and line:find(' mode=on ') then
                M.tell(function(w) return w.quests.save end)
            elseif state=='stopped' and quests_was and quests_was~='stopped' then
                M.tell(function(w) return w.quests.stopped end)
            end
            quests_was,quests_with,quests_role=now,with,line:match(' role=(%a+)') or quests_role
        end
        for _,n in ipairs(M.link.quest_notes()) do
            if QUEST_NOTES[n.kind] then
                local key=n.kind=='ahead' and (quests_role=='host' and 'ahead_host' or 'ahead_guest') or n.kind
                local name=member_name(n.from)
                M.tell(function(w)
                    local q=w.quests
                    if key=='zone' then return q.zone:format(M.her_name(w),n.alias,n.zone or '?') end
                    if key=='kill' then return q.kill:format(n.alias,n.id) end
                    if key=='board' or key:find('forced') then return q[key]:format(n.alias) end
                    return q[key]:format(M.her_name(w,name),n.alias) -- ahead_host, ahead_guest, behind
                end)
            end
        end
    end
    -- The co-op menu's shared_quests row, then coop quests on once a load (main/pass.lua calls this).
    function M.quests_asks()
        if M.settings.shared_quests~=quests_wanted and not M.off then -- The co-op menu's row.
            quests_wanted=M.settings.shared_quests
            quests_auto=quests_wanted
            if not quests_wanted and (M.link.quests() or ''):find('^quests=%a+ mode=on ') then
                local ok,message=M.ask('quests off')()
                M.report(ok,'shared_quests=off: '..tostring(message))
            end
        end
        if quests_auto and not M.off then
            local verdict=(M.slot_line() or ''):match('^slot=(%a+)')
            if verdict=='coop' or verdict=='main' or verdict=='none' then
                quests_auto=false
                local ok,message=M.commands.quests('on')
                M.report(ok,'shared_quests=on: '..tostring(message))
            end
        end
    end
end
return require('quest.commands').new({ask=M.ask,coop_slot=M.coop_slot,link=M.link,native_tick=M.native_tick,
    quests_auto_off=function() quests_auto=false end,settings=M.settings})
end,
}
