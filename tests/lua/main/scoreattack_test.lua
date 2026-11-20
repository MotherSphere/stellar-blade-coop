-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The score attack's two runtime lines through main.lua: the 250 ms loop reads its score lines once a pass and plays
-- its round (a guest who is not in the lobby room sits out the host's go with one [SA] line); coop off ends the round
-- for it. No pass reads its lines after that. Then its wiring on a fake run: scoreattack=off, the bike and a Night
-- Operation run each sit a round out with its notice; a hall seat is left first and the run starts at our spot, then
-- ready goes; each pass ticks the run; the run's end goes as the done line; coop off stops the run. The screens
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
sb.sitting={n=3}
local sent=#fake_link.scores
go()
assert(sb.stands==1 and fake.starts[1]=='targets '..n..' -100 0',tostring(fake.starts[1]))
assert(fake_link.scores[sent+1]=='ready '..n,tostring(fake_link.scores[sent+1]))
local ticks=fake.ticks
loops[2].f()
assert(fake.ticks==ticks+1,'Each pass ticks the run')
fake.o.ended({def=require('online.modes.scoreattack.challenges').find('targets'),outcome='time',score=30,time=90})
assert(fake_link.scores[#fake_link.scores]=='done '..n..' time 30 900',fake_link.scores[#fake_link.scores])
coop('off')
assert(fake.stops[#fake.stops]=='coop off',tostring(fake.stops[#fake.stops]))
for _,l in ipairs(printed) do assert(not l:find('scoreattack: error',1,true),l) end
io.stdout:write('main scoreattack_test ok\n')
