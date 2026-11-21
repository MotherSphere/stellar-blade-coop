-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The photo hunt's copy of the records part of tests/lua/online/modes/scoreattack/challenges_test.lua (2026-11-21), for
-- its copy in online/modes/photohunt/records.lua: the best photo hunt of each world in coop-records.txt (read,
-- compared, rewritten) under its own key, beside the challenges', score attack's and the fishing tournament's bests.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Rec=require('online.modes.photohunt.records')

-- Records: best_photohunt_<world>=<points> <seconds>, the world in lower case, read the way the mod reads its settings
-- (the last line naming the key). Each world has its own key. A challenge's, a match's or a tournament's best is no
-- photo hunt best.
local file='# mine\nbest_photohunt_xion=2 314\r\nbest_photohunt_wastelanda = 1 46\nbest_photohunt_nest=12\n'
    ..'best_photohunt_arden=a b\nbest_match_targets=1590 31\nbest_fish_10=1250 37\nbest_swarm=314 46\n'
local points,s=Rec.best(file,'Xion')
assert(points==2 and s==314)
points,s=Rec.best(file,'WasteLandA')
assert(points==1 and s==46)
assert(Rec.best(file,'xion')==2,'The key is the same in any case')
for _,world in ipairs({'Nest','Arden','WasteLandB'}) do assert(Rec.best(file,world)==nil,world..': malformed or missing') end
assert(Rec.best(nil,'Xion')==nil and Rec.best('','Xion')==nil,'No file, no best')
assert(Rec.best('best_photohunt_xion=1 2\nbest_photohunt_xion=99999999999999999999 1\n','Xion')==nil,
    'Points past an integer')
assert(Rec.best('best_photohunt_xion=-1 2\n','Xion')==nil and Rec.best('best_photohunt_xion=1 2 3\n','Xion')==nil)
assert(Rec.best('best_photohunt_xion=1 2\nbest_photohunt_xion=3 9\n','Xion')==3,'The last line wins')
assert(Rec.best('best_photohunt_xion2=1 2\n','Xion')==nil,'Each world its own')

-- Better: more points; the same points in fewer seconds; anything beats no best.
assert(Rec.better(2,300,3,900) and not Rec.better(2,300,1,10))
assert(Rec.better(2,300,2,299) and not Rec.better(2,300,2,300) and not Rec.better(2,300,2,301))
assert(Rec.better(nil,nil,1,600))

-- Write: the line rewritten in place, every other line kept (the challenges', the match's and the tournament's bests
-- too); a key not yet there goes at the end; a new or empty file starts with the challenges' comment line.
local text=assert(Rec.write(file,'Xion',3,420))
assert(text==file:gsub('best_photohunt_xion=2 314','best_photohunt_xion=3 420'),text)
assert(Rec.best(text,'Xion')==3 and select(2,Rec.best(text,'Xion'))==420)
text=assert(Rec.write(file,'WasteLandB',1,77))
assert(text==file..'best_photohunt_wastelandb=1 77\r\n','Added with the file\'s line end (it has a CRLF)')
assert(text:find('\nbest_match_targets=1590 31\nbest_fish_10=1250 37\nbest_swarm=314 46\n',1,true),'The other bests stay')
for _,empty in pairs({[1]=false,[2]=''}) do
    text=assert(Rec.write(empty or nil,'Xion',1,6))
    assert(text=='# StellarCoop: your best challenge runs on this PC (score and seconds).\nbest_photohunt_xion=1 6\n',
        text)
end
assert(Rec.write('# kept\n','Xion',1,2)=='# kept\nbest_photohunt_xion=1 2\n','A file with lines gets no second comment')

print('photohunt_records_test: ok')
