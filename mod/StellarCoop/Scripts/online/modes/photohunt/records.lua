-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The photo hunt's copy of C.best, C.better and C.write in online/modes/scoreattack/challenges.lua (2026-11-21):
-- photohunt owns it; a fix here does not reach score attack's. Our best photo hunt of each world in coop-records.txt,
-- one line best_photohunt_<world>=<points> <seconds> read and rewritten through core/settings_file.lua. <world> is the
-- go line's WorldTable alias in lower case: Xion's three targets and the Wasteland's do not compare. The challenges,
-- score attack and the fishing tournament keep their lines in the same file.
-- tests/lua/online/modes/photohunt/records_test.lua covers it with lua5.4 alone.
local F=require('core.settings_file')
local Rec={}
local function key(world) return 'best_photohunt_'..world:lower() end
-- Our best photo hunt of world in the records file's text (nil when there is none): points and the host's seconds of
-- our last point, or nil for a missing or malformed value.
function Rec.best(text,world)
    local value=text and F.get(text,key(world))
    local points,s=(value or ''):match('^(%d+) (%d+)$')
    points,s=math.tointeger(tonumber(points or '')),math.tointeger(tonumber(s or ''))
    if points and s then return points,s end
end
-- A photo hunt of points with its last point at s beats the stored best (old_points nil: none): more points, or the
-- same in fewer seconds.
function Rec.better(old_points,old_s,points,s)
    return old_points==nil or points>old_points or points==old_points and s<old_s
end
-- The records file's text with the best of world set, or nil and why. A new or empty file starts with the line the
-- challenges start it with.
function Rec.write(text,world,points,s)
    if not text or text=='' then text='# StellarCoop: your best challenge runs on this PC (score and seconds).\n' end
    return F.set(text,key(world),string.format('%d %d',points,s))
end
return Rec
