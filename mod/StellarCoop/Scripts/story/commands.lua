-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop scenes (story together, experimental): on and off change it until the mod reloads, whatever shared_story says
-- (the native part then waits for a friend and a co-op save). status answers with the story= line and its counters (the
-- native part's answer follows in the log). story/wiring.lua builds it with new(o) at each Lua load and main/loader.lua
-- merges it into the command table; main/pass.lua asks the native part by itself for shared_story (story/wiring.lua's
-- scenes_asks). o: link, native_tick, ask (a line for the native part) and scenes_auto_off(): coop scenes on or off
-- cancels that ask. coop story [dump|find] (story/snapshot.lua, read only, any save); o.story: the story dump.
local Scenes={}
local USE='Use: coop scenes on | off | status'
local WORDS={on=true,off=true,status=true}
function Scenes.new(o)
    local self={}
    function self.scenes(sub,extra)
        if extra~=nil or not WORDS[sub or ''] then return false,USE end
        if sub~='status' then o.scenes_auto_off() end
        if sub=='on' and not o.native_tick then return false,'the native tick is unavailable' end
        local ok,why=o.ask('scenes '..sub)()
        if not ok or sub~='status' then return ok,why end
        return true,o.link.story() or 'no story together status yet'
    end
    function self.story(sub,extra) return o.story.command(sub,extra) end
    return self
end
return Scenes
