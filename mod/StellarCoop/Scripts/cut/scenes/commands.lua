-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop scene, two cut scenes through the game's theater (cut/scenes/scene.lua): a scene's name on a co-op save only
-- (lily, Lily's prologue talk, through o.lily); the list and stop on any. coop lines (cut/scenes/lines.lua). main.lua
-- builds it with new(o) at each Lua load and merges it into its command table. o: main.lua's coop_slot, scene
-- (cut/scenes/scene.lua's), lines (cut/scenes/lines.lua's) and lily (Lily's signal, set after this is built, so read at
-- each call).
local Scenes={}
function Scenes.new(o)
    local coop_slot=o.coop_slot
    local self={}
    -- coop lines (cut/scenes/lines.lua, o.lines): every word to it, on any save, as it only says lines in the feed and
    -- plays voice takes.
    function self.lines(...) return o.lines.command(...) end
    -- coop scene lily: Lily's prologue talk by hand, coop lily talk prologue's (matrix13/quest/on_time.lua: solo, the
    -- test pak).
    function self.scene(sub,extra)
        if o.scene.SCENES[sub] then
            local ok,why=coop_slot('coop scene '..sub)
            if not ok then return false,why end
        end
        if sub=='lily' and o.lily then return o.lily.talk('prologue',extra) end
        return o.scene.command(sub,extra)
    end
    return self
end
return Scenes
