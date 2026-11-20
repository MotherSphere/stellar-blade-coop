-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The fishing tournament's wiring through main.lua: its round on the link, with os.time as its clock, [FT] log lines,
-- and its records file. coop-records.txt in the mod folder is read and written through core/link.lua's files: no
-- file, the .tmp write, a tournament that beats the best or not, a failed write, a refused rename, the write in place,
-- a file that cannot be opened. The other lines of the file stay.
dofile('tests/lua/main/fixture.lua')
local Round=require('online.modes.fishing.round')
local new,o=Round.new,nil
Round.new=function(opts) o=opts; return new(opts) end -- The round main.lua's loader makes.
load_main(true)
assert(o and o.clock==os.time and o.link==fake_link,'Built on the link')
o.log('hello')
assert(printed[#printed]=='[StellarCoop][FT] hello\n',printed[#printed])
local P='mod/StellarCoop\\coop-records.txt'
-- No file: a first best, written through coop-records.txt.tmp with the challenges' header line.
assert(o.record(10,138,1)==true and nr.read==P and nr.wrote[1]==P..'.tmp' and disk.files[P..'.tmp']==nil)
assert(disk.files[P]=='# StellarCoop: your best challenge runs on this PC (score and seconds).\nbest_fish_10=138 1\n',
    disk.files[P])
assert(printed[#printed]=='[StellarCoop][FT] new best of 10 minutes: 138 points, 1 fish\n')
-- Fewer points, or the same points in more fish: no record. More points, or the same in fewer fish: a record. Another
-- length is another key. The other lines stay.
disk.files[P]='best_match_targets=1250 37\nbest_fish_10=138 2\n'
assert(o.record(10,100,1)==false and o.record(10,138,3)==false
    and disk.files[P]=='best_match_targets=1250 37\nbest_fish_10=138 2\n')
assert(o.record(10,138,1)==true and o.record(5,30,1)==true)
assert(disk.files[P]=='best_match_targets=1250 37\nbest_fish_10=138 1\nbest_fish_5=30 1\n',disk.files[P])
-- A write that fails (a full disk) leaves the file as it was, with a log line; so does a rename refused while the old
-- file stays.
local was=disk.files[P]
disk.fail[P..'.tmp']='write'
assert(not o.record(10,500,1) and disk.files[P]==was)
assert(printed[#printed]=='[StellarCoop][FT] record not written: '..P..'.tmp\n',printed[#printed])
disk.fail[P..'.tmp']='rename'
local files=package.loaded['core.link'].files
local remove=files.remove
files.remove=function() return nil,'in use',13 end
assert(not o.record(10,500,1) and disk.files[P]==was)
assert(printed[#printed]=='[StellarCoop][FT] record not written: '..P..'\n',printed[#printed])
files.remove=remove
-- The rename refused once the old file went: written in place.
assert(o.record(10,500,1)==true and disk.files[P]:find('\nbest_fish_10=500 1\n',1,true))
disk.fail[P..'.tmp']=nil
-- A file that cannot be opened raises: nothing is written over it.
disk.fail[P]='open'
assert(not pcall(o.record,10,900,1),'It raises')
disk.fail[P]=nil
assert(disk.files[P]:find('\nbest_fish_10=500 1\n',1,true))
print('main/fishing_test ok')
