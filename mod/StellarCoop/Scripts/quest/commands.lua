-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The shared quests' console command (Phase 12, experimental): coop quests. main.lua builds it with new(o) at each Lua
-- load and merges it into its command table; its 250 ms loop runs coop quests on by itself for shared_quests=on. o:
-- main.lua's link, settings, native_tick, ask (a line for the native part), coop_slot and quests_auto_off() (coop
-- quests off cancels that ask).
local Quest={}
-- coop quests (Phase 12, experimental): on (needs shared_quests=on; the native part waits for a friend and a co-op
-- save), off, status (the quests= line, while the native part's whole answer follows in the log as quests_status
-- lines), probe, record and replay (the solo tools, on a co-op save only), and force <number>: the step that quest
-- holds for your own kill, or for a place the host's game could not read, made where you stand, once typed twice for
-- the same quest within 10 s (it can unlock that quest's trophies). on, probe and record carry quest_deny.
local QUESTS_USE='Use: coop quests on | off | status | probe | record | replay | force <quest number>'
local QUESTS_ALONE={on=true,off=true,status=true,probe=true,record=true,replay=true}
function Quest.new(o)
    local link,settings,native_tick,ask,coop_slot=o.link,o.settings,o.native_tick,o.ask,o.coop_slot
    local self={}
    local force_asked=nil -- coop quests force: the number typed and when ({id=, at=}), until typed again.
    function self.quests(sub,a,extra)
        if extra~=nil or not (QUESTS_ALONE[sub or ''] and a==nil or sub=='force' and a~=nil) then
            return false,QUESTS_USE
        end
        if sub=='force' then
            local id=a:match('^%d+$') and tonumber(a)
            if not id or id<1 or id>65535 then return false,QUESTS_USE end
            local now=os.clock()
            if not (force_asked and force_asked.id==id and now-force_asked.at<=10) then
                force_asked={id=id,at=now}
                return false,'coop quests force '..id..' makes the step that quest '..id..' holds for your own kill, '
                    ..'or for a place the host\'s game could not read, where you stand now; the game may then unlock '
                    ..'that quest\'s trophies: type it again within 10 s to go on'
            end
            force_asked=nil
            return ask('quests force '..id)()
        end
        if sub=='off' then o.quests_auto_off() end
        if sub~='off' and sub~='status' then
            if not native_tick then return false,'the native tick is unavailable' end
            if sub=='on' and not settings.shared_quests then
                return false,'shared quests are off in coop-settings.txt (shared_quests=off)'
            end
            if sub~='on' then
                local ok,why=coop_slot('coop quests')
                if not ok then return false,why end
            end
        end
        local line='quests '..sub
        if (sub=='on' or sub=='probe' or sub=='record') and settings.quest_deny~='' then
            line=line..' deny '..settings.quest_deny
        end
        local ok,why=ask(line)()
        if not ok or sub~='status' then return ok,why end
        return true,(link.quests() or 'no shared quests status yet')
            ..' (the whole status follows in this log as quests_status lines)'
    end
    return self
end
return Quest
