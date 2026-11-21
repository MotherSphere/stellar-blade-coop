-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The fishing tournament's copy of C.best, C.better and C.write in online/modes/scoreattack/challenges.lua
-- (2026-11-21): fishing owns it; a fix here does not reach score attack's. Our best tournament of each length in
-- coop-records.txt, one line best_fish_<minutes>=<points> <catches> read and rewritten through core/settings_file.lua.
-- A key per length: 5 and 30 minutes do not compare. The challenges and score attack keep their lines in the same
-- file. tests/lua/online/modes/fishing/records_test.lua covers it with lua5.4 alone.
local F=require('core.settings_file')
local Rec={}
-- Our best tournament of minutes in the records file's text (nil when there is none): points and catches, or nil for
-- a missing or malformed value.
function Rec.best(text,minutes)
    local value=text and F.get(text,'best_fish_'..minutes)
    local points,catches=(value or ''):match('^(%d+) (%d+)$')
    points,catches=math.tointeger(tonumber(points or '')),math.tointeger(tonumber(catches or ''))
    if points and catches then return points,catches end
end
-- A tournament of points in catches beats the stored best (old_points nil: none): more points, or the same with fewer
-- fish.
function Rec.better(old_points,old_catches,points,catches)
    return old_points==nil or points>old_points or points==old_points and catches<old_catches
end
-- The records file's text with the best of minutes set, or nil and why. A new or empty file starts with the line the
-- challenges start it with.
function Rec.write(text,minutes,points,catches)
    if not text or text=='' then text='# StellarCoop: your best challenge runs on this PC (score and seconds).\n' end
    return F.set(text,'best_fish_'..minutes,string.format('%d %d',points,catches))
end
return Rec
