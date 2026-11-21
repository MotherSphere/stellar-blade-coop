-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The photo hunt's wiring through main.lua: its round on the link, with os.time as its clock, [PH] log lines, coop
-- photohunt on the round, and its records file. coop-records.txt in the mod folder is read and written through
-- core/link.lua's files: no file, the .tmp write, a round that beats the best or not, a failed write, a refused
-- rename, the write in place, a file that cannot be opened. The other lines of the file stay.
dofile('tests/lua/main/fixture.lua')
local Round=require('online.modes.photohunt.round')
local new,o=Round.new,nil
Round.new=function(opts) o=opts; return new(opts) end -- The round main.lua's loader makes.
load_main(true)
assert(o and o.clock==os.time and o.link==fake_link,'Built on the link')
o.log('hello')
assert(printed[#printed]=='[StellarCoop][PH] hello\n',printed[#printed])
coop('photohunt')
assert(printed[#printed]:find('photohunt: no photo hunt yet',1,true),printed[#printed])
local P='mod/StellarCoop\\coop-records.txt'
-- No file: a first best, written through coop-records.txt.tmp with the challenges' header line.
assert(o.record('Xion',2,140)==true and nr.read==P and nr.wrote[1]==P..'.tmp' and disk.files[P..'.tmp']==nil)
assert(disk.files[P]=='# StellarCoop: your best challenge runs on this PC (score and seconds).\nbest_photohunt_xion=2 140\n',
    disk.files[P])
assert(printed[#printed]=='[StellarCoop][PH] new best in Xion: 2 points, last at 140 s\n',printed[#printed])
-- Fewer points, or the same points in more seconds: no record. More points, or the same in fewer seconds: a record.
-- Another world is another key. The other lines stay.
disk.files[P]='best_fish_10=138 1\nbest_photohunt_xion=2 140\n'
assert(o.record('Xion',1,10)==false and o.record('Xion',2,141)==false
    and disk.files[P]=='best_fish_10=138 1\nbest_photohunt_xion=2 140\n')
assert(o.record('Xion',2,139)==true and o.record('Wasteland',1,30)==true)
assert(disk.files[P]=='best_fish_10=138 1\nbest_photohunt_xion=2 139\nbest_photohunt_wasteland=1 30\n',disk.files[P])
-- A write that fails (a full disk) leaves the file as it was, with a log line; so does a rename refused while the old
-- file stays.
local was=disk.files[P]
disk.fail[P..'.tmp']='write'
assert(not o.record('Xion',3,100) and disk.files[P]==was)
assert(printed[#printed]=='[StellarCoop][PH] record not written: '..P..'.tmp\n',printed[#printed])
disk.fail[P..'.tmp']='rename'
local files=package.loaded['core.link'].files
local remove=files.remove
files.remove=function() return nil,'in use',13 end
assert(not o.record('Xion',3,100) and disk.files[P]==was)
assert(printed[#printed]=='[StellarCoop][PH] record not written: '..P..'\n',printed[#printed])
files.remove=remove
-- The rename refused once the old file went: written in place.
assert(o.record('Xion',3,100)==true and disk.files[P]:find('\nbest_photohunt_xion=3 100\n',1,true))
disk.fail[P..'.tmp']=nil
-- A file that cannot be opened raises: nothing is written over it.
disk.fail[P]='open'
assert(not pcall(o.record,'Xion',3,50),'It raises')
disk.fail[P]=nil
assert(disk.files[P]:find('\nbest_photohunt_xion=3 100\n',1,true))

-- The two runtime lines on a host's round over a fake clock and world: the 250 ms loop ticks the round, then its game
-- side, which arms the native part at GO with the three targets' FNames, then its screens (online/modes/photohunt/
-- ui/board.lua, built on the kit's hud step: the start and Camera notices in the menu's words, the card each pass,
-- hidden on the title screen); a valid photo in the engine line makes the host's own claim and its board line, with
-- the shot's words once the selfie mode closes; coop off ends the round with no line and no ask after it: it takes the
-- ask back and hides the card; the pass line is guarded; photohunt=off and a save that is not a co-op one refuse the
-- host's start.
local T=1000
local time=os.time
os.time=function() return T end
local round
Round.new=function(opts) o=opts; round=new(opts); return round end
local Game=require('online.modes.photohunt.game')
local read,game_new=Game.read,Game.new
Game.read=function() return {'Cat1','Cat2','MemoryOfXion'},'Xion' end -- SB's tables, walked by targets.lua.
Game.new=function(opts)
    opts.fname=function(row) return {index=({Cat1=502,Cat2=503,MemoryOfXion=501})[row],number=0} end -- FNAME_Find.
    return game_new(opts)
end
load_main(true)
local Where=require('core.where')
local world,me=Where.world,Where.me
Where.world,Where.me=function() return true,false end,function() return {map='/game/art/bg/worldmap/level_p/e04'} end
saves_info,chatting={steamid='1001'},true
fake_link.host=function() return {id='1001'} end
fake_link.members=function() return {{id='2002',linked=true,lost=false,name='P2'}} end
status_text='mod=v proto=3 steam=ready\nlink=host lobby=7\nslot=coop 2\nengine=v1 pad=xinput\n'
coop('photohunt','start','1')
assert(round.round().phase=='play' and fake_link.modes[#fake_link.modes]:find('^photohunt go %d+ 1 Xion %w+,%w+,%w+ 1001,2002$'),
    tostring(fake_link.modes[#fake_link.modes]))
-- A notice said: on the screen's notice line, or in the chat feed once the kit is up.
local function told(text)
    for _,each in ipairs(said) do if each==text then return true end end
    for _,call in ipairs(chat_calls) do if call:match('^system (.-) [%d.]+$')==text then return true end end
    return false
end
assert(said[#said-1]:find('^.+ starts a photo hunt in Xion: .+%. 1 minutes%.$'),'The start notice: '..said[#said-1])
assert(said[#said]=='Use the Camera to take the photos.',said[#said])
kit_ready=true
local function arms()
    local n,last=0,nil
    for _,line in ipairs(asked) do if line:find('^photohunt %d+ ') then n,last=n+1,line end end
    return n,last
end
loops[2].f() -- In the countdown: no ask.
assert(arms()==0)
assert(kit_shown.photohunt==true and not kit_shown.photohunt_result,'The pass ticks the screens: the card')
Where.world=function() return false,true end -- The title screen: the co-op saves' badge takes the card's place.
loops[2].f()
assert(kit_shown.photohunt==false,'Hidden on the title screen')
Where.world=function() return true,false end
loops[2].f()
assert(kit_shown.photohunt==true)
T=T+5 -- GO.
loops[2].f()
local n,line=arms()
assert(n==1 and line:find('^photohunt %d+ 50%d 0 50%d 0 50%d 0$'),'The pass ticks the game side: its ask at GO')
-- The native part's answer: a shot with a 3 for the round's first target. The host's own claim at this pass, then
-- its board at the next.
local ask=line:match('^photohunt (%d+) ')
status_text=status_text:gsub(' pad=',' photohunt='..ask..' 1 1,0,0 300 pad=')
selfie_mode=true -- The selfie mode is still open: the shot's words wait.
loops[2].f()
assert(round.round().board[1] and round.round().board[1].id=='1001','Taken by the host')
local first=require('online.modes.photohunt.targets').name(round.round().rows[1],require('ui.text').en.photohunt)
assert(told('You took '..first..'.') and not told(first..' counts: 1 point.'),'The shot words wait')
selfie_mode=false
loops[2].f()
assert(told(first..' counts: 1 point.'),'Said once the selfie mode closed')
loops[2].f()
assert(fake_link.modes[#fake_link.modes]:find('^photohunt board %d+ 1001:0,0:0,0:0$'),fake_link.modes[#fake_link.modes])
local lines=#fake_link.modes
coop('off')
assert(round.round().phase=='over' and round.round().why=='coop off' and #fake_link.modes==lines,'No line')
assert(kit_shown.photohunt==false,'coop off hides the card')
local back=false
for i=#asked,1,-1 do
    if asked[i]:find('^photohunt %d+ ') then break end
    back=back or asked[i]=='photohunt off'
end
assert(back,'The ask taken back, before the native part goes off')
local after=#asked
T=T+1
loops[2].f()
assert(#asked==after,'No pass and no ask after coop off')
-- Guarded: a tick that raises is logged once and the loop goes on.
load_main(true)
round.tick=function() error('boom',0) end
loops[2].f()
loops[2].f()
local errors=0
local ERROR='photohunt: error (logged once until the mod reloads; the other modules go on): boom'
for _,l in ipairs(printed) do if l:find(ERROR,1,true) then errors=errors+1 end end
assert(errors==1,'Logged once')
-- The photohunt setting and the co-op save check reach the round through main.lua: each refuses the host's start.
settings_text='photohunt=off\n'
load_main(true)
assert(select(2,round.start('1'))=='off','photohunt=off from the settings')
settings_text=''
load_main(true)
status_text=status_text:gsub('slot=coop ','slot=normal ')
assert(select(2,round.start('1'))=='slot','Off a co-op save')
status_text=status_text:gsub('slot=normal ','slot=coop ')
assert(round.start('1'),'Both hold: it starts')
Where.world,Where.me,os.time=world,me,time
Game.read,Game.new=read,game_new
print('main/photohunt_test ok')
