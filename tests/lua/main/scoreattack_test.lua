-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The score attack's two runtime lines through main.lua: the 250 ms loop reads its score lines once a pass and plays
-- its round (a guest who is not in the lobby room sits out the host's go with one [SA] line); coop off ends the round
-- for it. No pass reads its lines after that. Then its wiring on a fake run: scoreattack=off, the bike, a Night
-- Operation run and SB's own hall chair each sit a round out with its notice; a hall seat is left first and the run
-- starts at our spot, then ready goes; each pass ticks the run; the run's end goes as the done line; the run's reads
-- (status, pause, life, the lobby room) and its records file; coop off stops the run. The screens
-- (online/modes/scoreattack/ui/board.lua) are built on the kit's hud step and tick each pass.
dofile('tests/lua/main/fixture.lua')
local Round=require('online.modes.scoreattack.round')
local new,round=Round.new,nil
Round.new=function(o) round=new(o); return round end -- The round main.lua's loader makes.
-- The run main.lua's loader makes, a fake: its starts, ticks and stops, and the o it got.
local fake={starts={},ticks=0,stops={}}
require('online.modes.scoreattack.run').new=function(o)
    fake.o=o
    return {start=function(def,seed,at,yaw)
            fake.starts[#fake.starts+1]=string.format('%s %d %d %d',def.id,seed,at.X,yaw)
            return true
        end,
        tick=function() fake.ticks=fake.ticks+1 end,stop=function(why) fake.stops[#fake.stops+1]=why end,
        state=function() return nil end}
end
load_main(true)
local takes,waiting=0,{}
fake_link.take_score=function()
    takes=takes+1
    local out=waiting
    waiting={}
    return out
end
link_mode,saves_info,link_owner='guest',{steamid='2002'},'1001'
loops[2].f()
assert(takes==1,'Once a pass')
link_round={n=1,kind='start',mode='scoreattack',map='lobby',seed=5,ids={'1001','2002'}}
waiting={{from='1001',text='go 5 targets'}}
loops[2].f()
assert(takes==2)
local function sat_out(why)
    for _,l in ipairs(printed) do if l=='[StellarCoop][SA] sit out: '..why..'\n' then return true end end
end
assert(sat_out('EVE is not in the lobby room'),'The go line reached the game side')
assert(round.status()=='pick random; round 1 (targets): play',round.status())
coop('off')
assert(round.status()=='pick random; round 1 (targets): coop off',round.status())
loops[2].f()
assert(takes==2,'No pass after coop off')

-- The wiring on the fake run. Each round: its start line, the host's go and one pass.
local ROOM={key='xion',spots={{X=100,Y=0,Z=0,Yaw=180},{X=-100,Y=0,Z=0,Yaw=0}}}
local n=1
local function go()
    n=n+1
    link_round={n=n,kind='start',mode='scoreattack',map='lobby',seed=n,ids={'1001','2002'}}
    waiting={{from='1001',text='go '..n..' targets'}}
    loops[2].f()
end
local function load(settings)
    settings_text=settings
    load_main(true)
    link_mode,saves_info,link_owner='guest',{steamid='2002'},'1001'
    sb.target=ROOM
    loops[2].f() -- The first pass: no round yet.
end
load('scoreattack=off\n')
go()
assert(sat_out('scoreattack=off') and #fake.starts==0,'Read from the settings')
local function told(text) for _,t in ipairs(said_en) do if t==text then return true end end end
assert(told(require('ui.text').en.scoreattack.out.off),'Its notice')
load('')
bk.riding=true
go()
assert(sat_out('EVE rides the bike') and #fake.starts==0)
bk.riding=false
nr.running=true
go()
assert(sat_out('a Night Operation run is on') and #fake.starts==0)
nr.running=false
-- SB's own hall chair seats her (the lobby's busy): she sits out with its notice, not stood up.
sb.busy,sb.sitting=true,{n=3}
go()
assert(sat_out('SB\'s chair seats EVE') and #fake.starts==0 and sb.stands==0)
assert(told(require('ui.text').en.scoreattack.out.seat),'Its notice')
sb.busy=false
local sent=#fake_link.scores
go()
assert(sb.stands==1 and fake.starts[1]=='targets '..n..' -100 0',tostring(fake.starts[1]))
assert(fake_link.scores[sent+1]=='ready '..n,tostring(fake_link.scores[sent+1]))
local ticks=fake.ticks
loops[2].f()
assert(fake.ticks==ticks+1,'Each pass ticks the run')
fake.o.ended({def=require('online.modes.scoreattack.challenges').find('targets'),outcome='time',score=30,time=90})
assert(fake_link.scores[#fake_link.scores]=='done '..n..' time 30 900',fake_link.scores[#fake_link.scores])
-- The run's reads: the status, the kit's pause (the kit off too), our life and the lobby room of a score attack
-- match (its match line past the search, sbo's target).
assert(fake.o.status()==status_text and fake.o.paused()==false)
kit_paused=true; assert(fake.o.paused()==true); kit_paused=false
kit_off,kit_paused=true,true; assert(fake.o.paused()==true,'The kit off'); kit_off,kit_paused=false,false
fake_link.Q.life={state=3,hp=0}
assert(fake.o.life()==fake_link.Q.life)
fake_link.Q.life=nil
link_match={state='open',mode='scoreattack'}
assert(fake.o.room()==true,'In the room of a score attack match')
sb.target=nil; assert(fake.o.room()==false,'Out of the room'); sb.target=ROOM
link_match.mode='ffa'; assert(fake.o.room()==false,'Another mode')
link_match={state='searching',mode='scoreattack'}; assert(fake.o.room()==false,'Still searching')
link_match=nil; assert(fake.o.room()==false,'No match')
-- The best match runs: coop-records.txt in the mod folder, read and written through core/link.lua's files. No file:
-- no best yet, nothing raised. Written through coop-records.txt.tmp, then read back.
do
    local P='mod/StellarCoop\\coop-records.txt'
    assert(fake.o.records.read()==nil and nr.read==P,nr.read)
    assert(fake.o.records.write('best_match_targets=1250 37\n')==true and nr.wrote[1]==P..'.tmp'
        and disk.files[P..'.tmp']==nil)
    assert(fake.o.records.read()=='best_match_targets=1250 37\n')
    -- A write that fails (a full disk) leaves the file as it was; so does a rename refused while the old file stays.
    disk.fail[P..'.tmp']='write'
    assert(fake.o.records.write('x')==false and disk.files[P]=='best_match_targets=1250 37\n')
    disk.fail[P..'.tmp']='rename'
    local files=package.loaded['core.link'].files
    local remove=files.remove
    files.remove=function() return nil,'in use',13 end
    assert(fake.o.records.write('x')==false and disk.files[P]=='best_match_targets=1250 37\n')
    files.remove=remove
    -- The rename refused once the old file went: written in place.
    assert(fake.o.records.write('y')==true and disk.files[P]=='y',tostring(disk.files[P]))
    disk.fail[P..'.tmp']=nil
    -- A rename that replaces the old file needs it gone first (rename never replaces on Windows).
    assert(fake.o.records.write('z')==true and disk.files[P]=='z' and disk.files[P..'.tmp']==nil)
    -- A file that cannot be opened raises: nothing is written over it.
    disk.fail[P]='open'
    assert(not pcall(fake.o.records.read),'It raises')
    disk.fail[P]=nil
end
coop('off')
assert(fake.stops[#fake.stops]=='coop off',tostring(fake.stops[#fake.stops]))
for _,l in ipairs(printed) do assert(not l:find('scoreattack: error',1,true),l) end
io.stdout:write('main scoreattack_test ok\n')
