-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The fishing tournament's wiring through main.lua: its round on the link, with os.time as its clock, [FT] log lines,
-- and its records file. coop-records.txt in the mod folder is read and written through core/link.lua's files: no
-- file, the .tmp write, a tournament that beats the best or not, a failed write, a refused rename, the write in place,
-- a file that cannot be opened. The other lines of the file stay. Then its two runtime lines: the 250 ms loop ticks
-- the round and its game side (the book asked once a second from GO); coop off ends the tournament with no line and no
-- ask after it; the pass line is guarded.
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

-- The two runtime lines on a host's tournament over a fake clock and world: the 250 ms loop ticks the round, then its
-- game side, which asks for the book once a second from GO; coop off ends the tournament with no line and no ask
-- after it; the pass line is guarded.
local T=1000
local time=os.time
os.time=function() return T end
local round
Round.new=function(opts) o=opts; round=new(opts); return round end
load_main(true)
require('online.modes.fishing.game').rows=function() return {[9220]=138} end -- SB's tables, read by row name.
local Where=require('core.where')
local world,me=Where.world,Where.me
Where.world,Where.me=function() return true,false end,function() return {map='/game/art/bg/worldmap/level_p/e04'} end
saves_info,chatting={steamid='1001'},true
fake_link.host=function() return {id='1001'} end
fake_link.members=function() return {{id='2002',linked=true,lost=false,name='P2'}} end
status_text='mod=v proto=3 steam=ready\nlink=host lobby=7\nslot=coop 2\nengine=v1 pad=xinput\n'
coop('fish','start','1')
assert(round.round().phase=='play' and fake_link.modes[#fake_link.modes]:find('^fish go %d+ 1 1001,2002$'),
    tostring(fake_link.modes[#fake_link.modes]))
local function books()
    local n=0
    for _,line in ipairs(asked) do if line:find('^fishbook %d+$') then n=n+1 end end
    return n
end
loops[2].f() -- In the countdown: the round's first board, no ask.
assert(fake_link.modes[#fake_link.modes]:find('^fish board %d+ 1001:0:0$') and books()==0)
T=T+5 -- GO.
loops[2].f()
assert(books()==1,'The pass ticks the game side: its first ask at GO')
-- The worker's answer in the engine line: an empty book, the baseline.
status_text=status_text:gsub(' pad=',' fish='..asked[#asked]:match('%d+')..' - pad=')
loops[2].f()
T=T+1
loops[2].f()
assert(books()==2,'Once a second')
local lines=#fake_link.modes
coop('off')
assert(round.round().phase=='over' and round.round().why=='coop off' and #fake_link.modes==lines,'No line')
T=T+1
loops[2].f()
assert(books()==2,'No pass and no ask after coop off')
-- Guarded: a tick that raises is logged once and the loop goes on.
load_main(true)
round.tick=function() error('boom',0) end
loops[2].f()
loops[2].f()
local errors=0
local ERROR='fishing: error (logged once until the mod reloads; the other modules go on): boom'
for _,l in ipairs(printed) do if l:find(ERROR,1,true) then errors=errors+1 end end
assert(errors==1,'Logged once')
Where.world,Where.me,os.time=world,me,time
print('main/fishing_test ok')
