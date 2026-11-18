-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The shared world's wiring (world/objects/): the reload kill switch, the notices and the menu row's asks.
return {
uses={},
exports={'world_notices','world_asks'},
new=function(M)
local print,log=M.print,M.log
-- shared_world=on: coop world on asked once a load, as soon as the native part judged the slot, as coop quests on is;
-- the native part starts off and then waits for a friend and a co-op save. coop world off before then cancels the ask.
-- The co-op menu's row asks it again (on) or asks coop world off at once (off), whatever the world= line says: that
-- line lags a world on asked a moment before. world_wanted: the value last acted on. shared_world=off at a reload
-- (Ctrl+R) ends a coop world on an earlier load asked.
local world_auto=M.settings~=nil and M.settings.shared_world
local world_wanted=world_auto
local function world_running(line) return (line or ''):find('^world=on') or (line or ''):find('^world=waiting') end
if M.settings and not M.settings.shared_world and not M.off
    and world_running(('\n'..(M.link.status() or '')):match('\n(world=[^\r\n]*)')) then
    local ok,why=M.ask('world off')()
    log((ok and 'OK: ' or 'STOP: ')..'shared_world=off: '..tostring(why))
end
if M.link then
    -- The shared world's notices, in the menu's language: from the world= line, on with her each time both sides come
    -- on, and stopped for the run, each once as it starts.
    local world_was=nil
    function M.world_notices()
        local state=(M.link.world() or ''):match('^world=(%a+)')
        if not state then return end
        if state=='on' and world_was~='on' then
            M.tell(function(w) return w.world.on:format(M.her_name(w)) end)
        elseif state=='stopped' and world_was and world_was~='stopped' then
            M.tell(function(w) return w.world.stopped end)
        end
        world_was=state
    end
    -- The co-op menu's shared_world row, then coop world on once a load (main/pass.lua calls this).
    function M.world_asks()
        if M.settings.shared_world~=world_wanted and not M.off then -- The co-op menu's row.
            world_wanted=M.settings.shared_world
            world_auto=world_wanted
            if not world_wanted then
                local ok,message=M.ask('world off')()
                M.report(ok,'shared_world=off: '..tostring(message))
            end
        end
        if world_auto and not M.off then
            local verdict=(M.slot_line() or ''):match('^slot=(%a+)')
            if verdict=='coop' or verdict=='main' or verdict=='none' then
                world_auto=false
                local ok,message=M.commands.world('on')
                M.report(ok,'shared_world=on: '..tostring(message))
            end
        end
    end
end
return require('world.objects.commands').new({ask=M.ask,link=M.link,native_tick=M.native_tick,
    world_auto_off=function() world_auto=false end})
end,
}
