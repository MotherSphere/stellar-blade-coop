-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Matrix XIII's words in the game's 21 cultures past English and French, by source id (quest.<key>, talk.<scene>.NN,
-- speaker.<name>, boss.<name>), from the generated world/maps/matrix13/text/<culture>.lua. English and French stay
-- hand-written in world/maps/matrix13/quest/text.lua, world/maps/matrix13/talks/ and the native headers.
local W={TEXT={}}
for c in pairs(require('ui.text.culture').CULTURES) do
    if c~='en' and c~='fr' then W.TEXT[c]=require('world.maps.matrix13.text.'..c) end
end
-- The line of culture c: fr when c is French and fr is given, else the generated line of that id, else en.
function W.line(c,id,en,fr)
    if c=='fr' and fr then return fr end
    return W.TEXT[c] and W.TEXT[c][id] or en
end
-- A talk's lines, each given its id <prefix>.NN (NN counts every line from 01).
function W.ids(lines,prefix)
    for k,l in ipairs(lines) do l.id=('%s.%02d'):format(prefix,k) end
    return lines
end
-- A zone file's scenes, each line given its id talk.zone.<scene>.NN.
function W.zone(scenes)
    for name,lines in pairs(scenes) do W.ids(lines,'talk.zone.'..name) end
    return scenes
end
return W
