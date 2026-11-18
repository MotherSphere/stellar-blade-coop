-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Story together's wiring (story/together/): the story dump, the notices and the menu row's asks.
return {
uses={},
exports={'story','story_notices','scenes_asks'},
new=function(M)
local print,log=M.print,M.log
-- shared_story: the native part starts with it on. Once a load, as soon as the native part judged the slot, the loop
-- asks coop scenes off for shared_story=off, or coop scenes on for shared_story=on while the story= line reads off by
-- the setting (an earlier load's off, or coop scenes off). It asks nothing when the line already agrees. coop scenes on
-- or off before then cancels the ask. The co-op menu's row asks coop scenes on or off at once; scenes_wanted: the value
-- last acted on.
local scenes_auto=M.settings~=nil
local scenes_wanted=M.settings~=nil and M.settings.shared_story
-- coop story (story/together/snapshot.lua), logging [ST] lines: the live save object's story lines; its request file is
-- polled in the 250 ms loop of main/pass.lua, with the Steam link only.
M.story=require('story.together.snapshot').new({log=function(m) print('[StellarCoop][ST] '..tostring(m)..'\n') end,
    folder=M.folder})
if M.link then
    -- Story together's notices, the same way from the story= line.
    local story_was=nil
    function M.story_notices()
        local state=(M.link.story() or ''):match('^story=(%a+)')
        if not state then return end
        if state=='on' and story_was~='on' then
            M.tell(function(w) return w.story.on:format(M.her_name(w)) end)
        elseif state=='stopped' and story_was and story_was~='stopped' then
            M.tell(function(w) return w.story.stopped end)
        end
        story_was=state
    end
    -- The co-op menu's shared_story row, then coop scenes on or off once a load (main/pass.lua calls this).
    function M.scenes_asks()
        if M.settings.shared_story~=scenes_wanted and not M.off then -- The co-op menu's row.
            scenes_wanted=M.settings.shared_story
            local word=scenes_wanted and 'on' or 'off'
            local ok,message=M.commands.scenes(word)
            M.report(ok,'shared_story='..word..': '..tostring(message))
        end
        if scenes_auto and not M.off then
            local verdict=(M.slot_line() or ''):match('^slot=(%a+)')
            if verdict=='coop' or verdict=='main' or verdict=='none' then
                scenes_auto=false
                -- off why=build and off why=coop_off refuse any ask; off scene= is the setting's off.
                local line=M.link.story() or ''
                local word=M.settings.shared_story and 'on' or 'off'
                local setting_off=line:find('^story=off scene=')~=nil
                if not line:find('^story=off why=') and M.settings.shared_story==setting_off then
                    local ok,message=M.commands.scenes(word)
                    M.report(ok,'shared_story='..word..': '..tostring(message))
                end
            end
        end
    end
end
return require('story.together.commands').new({ask=M.ask,link=M.link,native_tick=M.native_tick,
    scenes_auto_off=function() scenes_auto=false end,story=M.story})
end,
}
