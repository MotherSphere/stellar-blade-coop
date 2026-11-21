-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The fishing tournament's copy of the records part of tests/lua/online/modes/scoreattack/challenges_test.lua
-- (2026-11-21), for its copy in online/modes/fishing/records.lua: the best tournament of each length in
-- coop-records.txt (read, compared, rewritten) under its own key, beside the challenges' and score attack's bests.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Rec=require('online.modes.fishing.records')

-- Records: best_fish_<minutes>=<points> <catches>, read the way the mod reads its settings (the last line naming the
-- key). Each length has its own key. A challenge's or a match's best is no fishing best.
local file='# mine\nbest_fish_10=1250 37\r\nbest_fish_5 = 314 6\nbest_fish_2=12\n'
    ..'best_fish_3=a b\nbest_match_targets=1590 31\nbest_swarm=314 46\n'
local points,catches=Rec.best(file,10)
assert(points==1250 and catches==37)
points,catches=Rec.best(file,5)
assert(points==314 and catches==6)
for _,minutes in ipairs({2,3,30}) do assert(Rec.best(file,minutes)==nil,minutes..': malformed or missing') end
assert(Rec.best(nil,10)==nil and Rec.best('',10)==nil,'No file, no best')
assert(Rec.best('best_fish_5=1 2\nbest_fish_5=99999999999999999999 1\n',5)==nil,'Points past an integer')
assert(Rec.best('best_fish_5=-5 2\n',5)==nil and Rec.best('best_fish_5=5 2 3\n',5)==nil)
assert(Rec.best('best_fish_5=5 2\nbest_fish_5=7 9\n',5)==7,'The last line wins')
assert(Rec.best('best_fish_50=5 2\n',5)==nil and Rec.best('best_fish_5=5 2\n',50)==nil,'Each length its own')

-- Better: more points; the same points with fewer fish; anything beats no best, 0 points included.
assert(Rec.better(100,5,101,9) and not Rec.better(100,5,99,1))
assert(Rec.better(100,5,100,4) and not Rec.better(100,5,100,5) and not Rec.better(100,5,100,6))
assert(Rec.better(nil,nil,0,3))

-- Write: the line rewritten in place, every other line kept (the challenges' and the match's bests too); a key not
-- yet there goes at the end; a new or empty file starts with the challenges' comment line.
local text=assert(Rec.write(file,10,1300,41))
assert(text==file:gsub('best_fish_10=1250 37','best_fish_10=1300 41'),text)
assert(Rec.best(text,10)==1300 and select(2,Rec.best(text,10))==41)
text=assert(Rec.write(file,30,1600,30))
assert(text==file..'best_fish_30=1600 30\r\n','Added with the file\'s line end (it has a CRLF)')
assert(text:find('\nbest_match_targets=1590 31\nbest_swarm=314 46\n',1,true),'The other bests stay')
for _,empty in pairs({[1]=false,[2]=''}) do
    text=assert(Rec.write(empty or nil,10,314,6))
    assert(text=='# StellarCoop: your best challenge runs on this PC (score and seconds).\nbest_fish_10=314 6\n',text)
end
assert(Rec.write('# kept\n',10,1,2)=='# kept\nbest_fish_10=1 2\n','A file with lines gets no second comment')

print('fishing_records_test: ok')
