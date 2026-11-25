-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Doro races in matches through main.lua and online/modes/race/wiring.lua, on a fake race (online/modes/race/run.lua
-- is the fixture's, its match and match_stop added here): the race's 250 ms pass ticks the round, which needs no
-- runtime line of its own. The host's Random draw reads the official track of Xion's room from the Scripts folder
-- (online/modes/race/match/tracks/xion_eight.txt) and our race starts on slot 1 with ready after the host's lines,
-- one handed to the link a pass; a guest's ghost by her ghost slot (the puppet on slot 0, ghost_of(k) on slots 1 to 6
-- in a round of 8); a hall offers the host's own tracks of coop-tracks.txt that fit it, a name with no track file
-- dropped from that file; coop race save and a pick by name add to it; each sit-out's notice in the menu's words
-- (race_match=off read from the settings, out of the room, SB's own hall chair seating her); the round's end with the
-- host gone tells it; our finish writes coop-records.txt in the mod folder once it beats the best; coop off stops the
-- round (the race's stop calls round_stop); the match lobby refuses coop race start. Then the wiring's adapters that
-- match/game.lua reads (the bike, a Night Operation run, the co-op save, SB's chair, the mod's seat and its stand-up,
-- a member's name), the round's clock in milliseconds and the records file's read and write, as score attack's copy.
dofile('tests/lua/main/fixture.lua')
local T=require('ui.text')
local R=require('online.modes.race.model')
local Mm=require('online.modes.race.match.model')
local Round=require('online.modes.race.match.round')
local new,round,round_o=Round.new,nil,nil
Round.new=function(o) round_o,round=o,new(o); return round end -- The round main.lua's loader makes; its o kept.
local Game=require('online.modes.race.match.game')
local game_new,game_o=Game.new,nil
Game.new=function(o) game_o=o; return game_new(o) end -- The game side's o, the wiring's adapters.
-- The ghosts of slots 1 to 6 (online/partner/ghosts.lua) main.lua's loader makes: get(k) gives slot_ghost[k].
local Ghosts=require('online.partner.ghosts')
local ghosts_new,slot_ghost=Ghosts.new,{}
for k=1,6 do slot_ghost[k]={slot=k} end
Ghosts.new=function(...)
    local g=ghosts_new(...)
    g.get=function(k) return slot_ghost[k] end
    return g
end
-- The fixture's fake race, with the match role's two calls: each start's arguments and each stop's reason.
local fake={}
local Run=package.loaded['online.modes.race.run']
local run_new=Run.new
Run.new=function(o)
    local r=run_new(o)
    r.match=function(t,name,seed,k,by_id,line,news)
        fake.matches[#fake.matches+1]={t=t,name=name,seed=seed,k=k,by_id=by_id,line=line,news=news}
        if fake.refuse then return false,fake.refuse,'refused here' end
        return true
    end
    r.match_stop=function(why) fake.stops[#fake.stops+1]=why end
    return r
end
local MAP='/game/art/bg/worldmap/level_p/e04'
local XION={key='xion',fence={X=-64028.5,Y=151213.6,R=3000,zmin=-16100,zmax=-14700},spots={}}
local HALL={key='hotel',fence={X=0,Y=0,R=3573,zmin=-200,zmax=900},spots={}}
local HALL_MAP='/game/sbo_lobby/lobby_hotel'
local function load(settings)
    settings_text=settings or ''
    status_text=COOP
    load_main(true)
    fake.matches,fake.stops,fake.refuse={},{},nil
    saves_info,link_owner,link_mode={steamid='1001'},'1001','host'
    sb.target=XION
    bt.me={at={X=-64029,Y=151214,Z=-15900},map=MAP}
    ra.o.round_tick() -- The first pass: no round yet (a round met here is one from before a Lua reload).
end
local function dr(text)
    for _,l in ipairs(printed) do if l=='[StellarCoop][DR] '..text..'\n' then return true end end
end
local function told(text) for _,t in ipairs(said_en) do if t==text then return true end end end
local function pass() ra.o.round_tick() end -- The race's 250 ms pass, its first call (run.lua's slow).

-- The host's round: Random draws the room's official track, read from the Scripts folder.
load()
assert(type(ra.o.round_tick)=='function' and type(ra.o.round_stop)=='function','The race\'s pass carries the round')
fake_link.members=function() return {{id='2002',slot=0,linked=true,name='Bee'}} end
link_round={n=1,kind='start',mode='race',map='lobby',seed=7,ids={'1001','2002'}}
local sent=#fake_link.drs
pass()
assert(#fake.matches==1,'Our race started')
local m=fake.matches[1]
assert(m.name=='xion_eight' and m.seed==7 and m.k==0 and m.t.map==MAP and #m.t.cps==6 and m.t.laps==5)
assert(m.by_id['2002']~=nil and m.by_id['1001']==nil,'Her ghost: the puppet, her ghost slot 0')
assert(dr('match round 1: xion_eight, seed 7, slot 1 of 2'))
assert(#fake_link.drs==sent+1 and fake_link.drs[sent+1]:find('^track 7 6 5 '),tostring(fake_link.drs[sent+1]))
for _=1,3 do pass() end
assert(fake_link.drs[sent+2]:find('^cps 7 1 ') and fake_link.drs[sent+3]=='go 7 '..Mm.sum(m.t)..' xion_eight'
    and fake_link.drs[sent+4]=='ready 7',tostring(fake_link.drs[sent+4]))
-- Our lines through the round: a split, then our finish, which writes coop-records.txt in the mod folder.
m.line({word='cp',lap=1,i=1,ms=3000})
pass()
assert(fake_link.drs[#fake_link.drs]=='cp 7 1 1 3000')
local P='mod/StellarCoop\\coop-records.txt'
disk.files[P]=nil
m.line({word='done',ending='fin',ms=95000,flags=0})
assert(Mm.best(disk.files[P],Mm.sum(m.t))==95000,tostring(disk.files[P]))
assert(dr('best on xion_eight: 95000 ms (was none)'))
-- A better finish over the file: the old file goes first (rename never replaces on Windows). A write that fails (a
-- full disk) leaves the file as it was, with a log line.
m.line({word='done',ending='fin',ms=90000,flags=0})
assert(Mm.best(disk.files[P],Mm.sum(m.t))==90000 and disk.files[P..'.tmp']==nil,tostring(disk.files[P]))
assert(dr('best on xion_eight: 90000 ms (was 95000)'))
disk.fail[P..'.tmp']='write'
m.line({word='done',ending='fin',ms=80000,flags=0})
assert(Mm.best(disk.files[P],Mm.sum(m.t))==90000 and dr('records: not written: the file write failed'))
disk.fail[P..'.tmp']=nil
-- What the round tells our race: a finish came, then the host's ranking with names.
assert(m.news().fin==true and m.news().list==nil)
-- The round's end with the host gone: our race closes, the notice in the menu's words.
link_round={n=1,kind='end',why='host_left'}
pass()
assert(fake.stops[#fake.stops]=='host_left' and told(T.en.race.match.host_left))

-- A guest whose round's track lies outside her room: she sits out with its notice and sends nothing.
load()
saves_info,link_owner,link_mode={steamid='2002'},'1001','guest'
link_round={n=2,kind='start',mode='race',map='lobby',seed=9,ids={'1001','2002'}}
pass()
local far='SBR 1\nmap '..MAP..'\nlaps 1\ngrid 0 0 -15900 0\ncp 2000 0 -15900 400\ncp 4000 0 -15900 400\n'
local t=assert(R.parse_track(far))
local lines=Mm.lines(t,9,'far')
local queue={}
for _,text in ipairs(lines) do queue[#queue+1]={from='1001',text=text} end
fake_link.take_dr=function() local out=queue; queue={}; return out end
sent=#fake_link.drs
pass()
assert(#fake.matches==0 and dr('sit out: the track runs outside the room xion') and told(T.en.race.match.fence))
for _=1,3 do pass() end
assert(#fake_link.drs==sent,'A player who sits out sends nothing')
fake_link.take_dr=function() return {} end

-- race_match=off, read from the settings: a sit-out with its notice.
load('race_match=off\n')
link_round={n=3,kind='start',mode='race',map='lobby',seed=11,ids={'1001','2002'}}
pass()
assert(#fake.matches==0 and dr('sit out: race_match=off') and told(T.en.race.match.off))

-- The host in a hall with no official track: her own tracks of coop-tracks.txt that fit it; a name with no file is
-- dropped from that file. coop race save (the race's saved hook) and coop race match pick <name> add to it.
load()
sb.target,bt.me=HALL,{at={X=0,Y=0,Z=0},map=HALL_MAP}
local loop='SBR 1\nmap '..HALL_MAP..'\nlaps 1\ngrid 0 0 0 0\ncp 1600 0 0 400\ncp 1600 1600 0 400\n'
link_files['coop-track-loop.txt']=loop
ra.o.saved('loop')
assert(link_files['coop-tracks.txt']=='# StellarCoop: your tracks a match lobby may offer, one name a line.\nloop\n')
coop('race','match','pick','gone')
assert(link_files['coop-tracks.txt']:find('\nloop\ngone\n$'),link_files['coop-tracks.txt'])
coop('race','match','pick','random')
link_round={n=4,kind='start',mode='race',map='lobby',seed=13,ids={'1001','2002'}}
pass()
assert(#fake.matches==1 and fake.matches[1].name=='loop' and fake.matches[1].t.map==HALL_MAP)
assert(not link_files['coop-tracks.txt']:find('gone'),'A name with no track file dropped')
assert(dr('coop-tracks.txt: 1 names without a track file dropped'))
-- A hall offering none: the host voids the round with the notice.
load()
link_files['coop-tracks.txt']=nil
sb.target,bt.me=HALL,{at={X=0,Y=0,Z=0},map=HALL_MAP}
link_round={n=5,kind='start',mode='race',map='lobby',seed=15,ids={'1001','2002'}}
pass()
assert(#fake.matches==0 and told(T.en.race.match.notrack) and fake_link.drs[#fake_link.drs]=='void 15')
-- Out of the lobby (online.lobby has no room for her): the host's room offers nothing either.
load()
sb.target=nil
link_round={n=6,kind='start',mode='race',map='lobby',seed=17,ids={'1001','2002'}}
pass()
assert(#fake.matches==0 and told(T.en.race.match.notrack))

-- coop off: the race's stop calls round_stop, which ends our round for us.
load()
link_round={n=7,kind='start',mode='race',map='lobby',seed=19,ids={'1001','2002'}}
pass()
assert(#fake.matches==1)
ra.o.round_stop('coop off')
assert(fake.stops[#fake.stops]=='coop off' and round.round().why=='coop off')
-- The match lobby: coop race start is refused there (run.lua reads match_lobby), not while searching.
link_match={state='open',mode='race'}
assert(ra.o.match_lobby()==true)
link_match.state='searching'
assert(ra.o.match_lobby()==false)
link_match=nil
assert(ra.o.match_lobby()==false)

-- SB's own hall chair seats her at the round's start (the lobby's busy): she sits out with its notice, not stood up.
load()
sb.busy,sb.sitting=true,{n=3}
link_round={n=8,kind='start',mode='race',map='lobby',seed=21,ids={'1001','2002'}}
pass()
assert(#fake.matches==0 and sb.stands==0 and dr('sit out: SB\'s chair seats EVE') and told(T.en.race.match.seat))

-- A round of 8: the puppet for the member on ghost slot 0, ghost_of(k) for each one on slots 1 to 6.
load()
local members,ids={{id='2002',slot=0,linked=true,name='Bee'}},{'1001','2002'}
for k=1,6 do
    members[#members+1]={id=tostring(3000+k),slot=k,linked=true,name='P'..k}
    ids[#ids+1]=tostring(3000+k)
end
fake_link.members=function() return members end
link_round={n=9,kind='start',mode='race',map='lobby',seed=23,ids=ids}
pass()
m=fake.matches[1]
assert(m and dr('match round 9: xion_eight, seed 23, slot 1 of 8') and m.by_id['1001']==nil)
for k=1,6 do assert(m.by_id[tostring(3000+k)]==slot_ghost[k],'Slot '..k) end
for k=1,6 do assert(m.by_id['2002']~=nil and m.by_id['2002']~=slot_ghost[k],'Slot 0: the puppet') end

-- The wiring's adapters, each read at its call: the bike, a Night Operation run, the co-op save (the slot line), SB's
-- chair (the race's at GO too), the mod's seat and its stand-up, a member's name; the round's clock in milliseconds
-- (round.lua's waits).
load()
local g=game_o
bk.riding=true; assert(g.riding()==true); bk.riding=false; assert(g.riding()==false)
nr.running=true; assert(g.night()==true); nr.running=nil; assert(g.night()==false)
assert(g.slot()==true)
status_text=plain; assert(g.slot()==false,'No slot line: not a co-op save'); status_text=COOP
sb.busy=true; assert(g.resting()==true and ra.o.resting()==true,'The race reads it at GO too')
sb.busy=false; assert(g.resting()==false and ra.o.resting()==false)
sb.sitting={n=3}; assert(g.seated()==true); sb.sitting=nil; assert(g.seated()==false)
g.stand(); assert(sb.stands==1)
local member=fake_link.member
fake_link.member=function(id) return {name=id=='2002' and 'Bee' or ''} end
assert(g.name('2002')=='Bee' and g.name('3003')==nil,'An empty name: none')
fake_link.member=member
assert(g.name('2002')==nil,'No member line')
clock=12.5; assert(round_o.clock()==12500,tostring(round_o.clock()))
-- The records file through core/link.lua's files, as score attack's copy: no file reads as none, nothing raised; a
-- write goes through coop-records.txt.tmp, then a rename. A write that fails (a full disk) leaves the file as it was;
-- so does a rename refused while the old file stays. A rename refused once the old file went writes in place. A
-- rename that replaces the old file needs it gone first (rename never replaces on Windows). A file that cannot be
-- opened raises, so nothing is written over it.
do
    local rec,P=g.records,'mod/StellarCoop\\coop-records.txt'
    disk.files[P],disk.files[P..'.tmp']=nil,nil
    assert(rec.read()==nil and nr.read==P,nr.read)
    assert(rec.write('best_race_1=1250 a\n')==true and nr.wrote[1]==P..'.tmp' and disk.files[P..'.tmp']==nil)
    assert(rec.read()=='best_race_1=1250 a\n')
    disk.fail[P..'.tmp']='write'
    assert(rec.write('x')==false and disk.files[P]=='best_race_1=1250 a\n')
    disk.fail[P..'.tmp']='rename'
    local files=package.loaded['core.link'].files
    local remove=files.remove
    files.remove=function() return nil,'in use',13 end
    assert(rec.write('x')==false and disk.files[P]=='best_race_1=1250 a\n')
    files.remove=remove
    assert(rec.write('y')==true and disk.files[P]=='y',tostring(disk.files[P]))
    disk.fail[P..'.tmp']=nil
    assert(rec.write('z')==true and disk.files[P]=='z' and disk.files[P..'.tmp']==nil)
    disk.fail[P]='open'
    assert(not pcall(rec.read),'It raises')
    disk.fail[P]=nil
end
for _,l in ipairs(printed) do assert(not l:find('match round: error',1,true),l) end
io.stdout:write('main race_match_test ok\n')
