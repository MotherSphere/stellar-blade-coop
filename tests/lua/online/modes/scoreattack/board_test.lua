-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Score attack's screens (online/modes/scoreattack/ui/board.lua): the time and the card's words; the in-round board's
-- order, shared places and statuses; the result panel's line, note and ranking with each difficulty. Then on a fake kit
-- and round: the three groups' places; the card and the board while our run plays (ours in teal, one row a player,
-- hidden under a pause); the result panel at our run's end, the ranking once it comes, closed at the round's end line
-- or SHOW seconds after the ranking; the words in the game's language; a round without a ranking says why once; with
-- the kit off the start, each wave, our end, the record line and our place come as notices; an error in the HUD gives one STOP line and
-- notices from then on; stop hides every group.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Board=require('online.modes.scoreattack.ui.board')
local C=require('online.modes.scoreattack.challenges')
local T=require('ui.text')
local en=T.en
local targets,swarm=C.find('targets'),C.find('swarm')

-- The time in tenths: minutes, seconds and the tenth.
assert(Board.time(0)=='0:00.0' and Board.time(723)=='1:12.3' and Board.time(7200)=='12:00.0',Board.time(723))

-- The card: the challenge's name, its countdown, then the wave, the time left and the score; the next wave's countdown
-- in a breather.
local s={def=swarm,phase='countdown',t0=105,wave=0,score=0}
local title,line=Board.card(s,100.2,en)
assert(title=='Antlion Swarm' and line=='STARTS IN 5',line)
s.phase,s.wave,s.score='wave',1,40
title,line=Board.card(s,117,en)
assert(line=='WAVE 1/'..#swarm.waves..'  2:48  SCORE 40',line)
s.phase,s.next_at='breather',20
_,line=Board.card(s,117,en)
assert(line:find('^NEXT WAVE IN 8  2:48  SCORE 40'),line)
_,line=Board.card(s,117,T.fr)
assert(line:find('^VAGUE SUIVANTE DANS 8'),line)

-- The board: best score first, equal scores share a place in the round's order; her end word once her run ended, else
-- her wave, else nothing.
local cur={n=1,ids={'1001','2002','3003','4004'},me='2002',def=targets,phase='play',board={
    ['1001']={ready=true,score=40,wave=1},['2002']={ready=true,score=60,ending='win',tenths=700},
    ['3003']={ready=true,score=40,wave=2}}}
local list=Board.standings(cur,en)
local function row(e) return e.place..' '..e.id..' '..e.score..' '..e.status end
assert(row(list[1])=='1 2002 60 Cleared' and row(list[2])=='2 1001 40 Wave 1/'..#targets.waves,row(list[2]))
assert(row(list[3])=='2 3003 40 Wave 2/'..#targets.waves and row(list[4])=='4 4004 0 ',row(list[4]))

-- The result panel: before the ranking, the results still to come (ready, no end); our end, score and time under the
-- heading; the record line once none waits; the ranking's rows with each difficulty, ours marked; Not ranked. when the
-- ranking leaves us out.
local names={['1001']='Ann',['2002']='Eve',['3003']='ABCDEFGHIJKLMNOPQRS'}
local function name(id) return names[id] or id end
local levels={['1001']=2,['2002']=0}
local function level(id) return levels[id] end
local head,sub,note,rows=Board.result(cur,en,name,level,{new=true})
assert(head=='Target Practice' and sub=='Cleared · score 60 · 1:10.0' and note=='Results still to come: 2.'
    and #rows==0,note)
cur.board['1001'].ending,cur.board['1001'].tenths='time',900
cur.board['3003'].ending,cur.board['3003'].tenths='dead',900
_,_,note=Board.result(cur,en,name,level,{new=true})
assert(note==en.challenge.record,note)
_,_,note=Board.result(cur,en,name,level,{score=99,s=60})
assert(note=='','No new best: no line')
cur.list={{id='2002',score=60,tenths=700,ending='win',place=1},{id='1001',score=40,tenths=900,ending='time',place=2},
    {id='3003',score=40,tenths=900,ending='dead',place=2}}
_,_,note,rows=Board.result(cur,en,name,level,nil)
assert(note=='' and #rows==3 and rows[1].label=='1  Eve' and rows[1].level=='Normal' and rows[1].ours,rows[1].label)
assert(rows[1].value=='60  1:10.0' and rows[2].label=='2  Ann' and rows[2].level=='Hard' and not rows[2].ours)
assert(rows[3].label=='2  ABCDEFGHIJKLMNOPQRS' and rows[3].level=='' and rows[3].value=='40  1:30.0',rows[3].value)
table.remove(cur.list,1)
_,_,note=Board.result(cur,en,name,level,{new=true})
assert(note=='Not ranked.',note)

-- The screens on a fake kit.
local kit={groups={},shown={},is_off=false,away=false,lang='en-US'}
function kit.add(name,place,build)
    local g={place=place}
    local b={}
    local function el(t)
        function t.set(x) if kit.raise then error(kit.raise,0) end; t.text=x end
        function t.color(c) t.c=c end
        function t.show(on) t.on=on end
        return t
    end
    function b.panel(...) g.panel={...} end
    function b.text(x,y,str,style,color,align) return el({text=str,c=color,x=x,y=y,style=style,align=align}) end
    function b.image(x,y,w,h,tex,tint) return el({x=x,y=y,w=w,h=h,tex=tex,c=tint}) end
    g.view=build(b)
    g.rebuild=function() g.view=build(b) end
    kit.groups[name]=g
end
-- A root build (a map change, the game's language changed): new views.
function kit.rebuild() for _,g in pairs(kit.groups) do g.rebuild() end end
function kit.view(name) return not kit.is_off and kit.groups[name] and kit.groups[name].view or nil end
function kit.show(name,on) kit.shown[name]=on==true end
function kit.off() return kit.is_off end
function kit.paused() return kit.away end
function kit.language() return kit.lang end
local theme={text='text',grey='grey',teal='teal',warn='warn',panel='panel'}
local settings={ui_language='game'}
local told,logs,clock={},{},100
local state={} -- What the fake run's state() gives: s, now, best.
local round=nil
local board=Board.new({round=function() return round end,run=function() return state.s,state.now,state.best end,
    name=name,level=level,tell=function(build) told[#told+1]=build(en) end,clock=function() return clock end,
    log=function(line) logs[#logs+1]=line end})
board.tick() -- No HUD, no round: nothing.
assert(#told==0 and #logs==0)
board.hud({kit=kit,theme=theme,settings=settings})
for _,g in ipairs({'scoreattack','scoreattack_board','scoreattack_result'}) do
    local p=kit.groups[g].place
    assert(p.x+p.w/2==1920 and p.pivot.X==0.5 and p.pivot.Y==0 and not p.shown,g)
end
assert(kit.groups.scoreattack.place.y==96 and kit.groups.scoreattack_board.place.y==96+160+12)
assert(kit.groups.scoreattack_result.place.y==96 and #kit.groups.scoreattack_board.view.rows==8)
local card,bd,res=kit.groups.scoreattack.view,kit.groups.scoreattack_board.view,kit.groups.scoreattack_result.view
-- A round we sit out (no ready from us) beside a run state: no card, no board.
round={n=2,ids={'1001','2002','3003'},me='2002',def=targets,phase='play',board={}}
state.s,state.now={def=targets,phase='countdown',t0=105,wave=0,score=0},100
board.tick()
assert(not kit.shown.scoreattack and not kit.shown.scoreattack_board)
-- Our round, our run's countdown: the card and the board, three rows on their glass, ours in teal.
round.board['2002']={ready=true}
board.tick()
assert(kit.shown.scoreattack and kit.shown.scoreattack_board and not kit.shown.scoreattack_result)
assert(card.title.text=='Target Practice' and card.line.text=='STARTS IN 5' and card.title.c=='warn',card.line.text)
assert(bd.rows[1].label.text=='1  Ann' and bd.rows[2].label.text=='1  Eve'
    and bd.rows[3].label.text=='1  ABCDEFGHIJKLMNOP...')
assert(bd.rows[1].back.on and bd.rows[3].back.on and not bd.rows[4].back.on and bd.rows[4].label.text=='')
assert(bd.rows[2].label.c=='teal' and bd.rows[1].label.c=='text' and bd.rows[2].value.text=='0',bd.rows[2].value.text)
assert(#told==0,'The kit shows it: no notice')
-- Her now lines: the board in score order with each wave.
state.s.phase,state.s.wave,state.s.score,state.now='wave',1,30,110
round.board['1001']={ready=true,score=50,wave=2}
round.board['2002'].score,round.board['2002'].wave=30,1
board.tick()
assert(bd.rows[1].label.text=='1  Ann' and bd.rows[1].value.text=='50  Wave 2/'..#targets.waves,bd.rows[1].value.text)
assert(bd.rows[2].label.text=='2  Eve' and bd.rows[2].value.text=='30  Wave 1/'..#targets.waves)
-- A pause hides them.
kit.away=true; board.tick()
assert(not kit.shown.scoreattack and not kit.shown.scoreattack_board and not kit.shown.scoreattack_result)
kit.away=false; board.tick()
assert(kit.shown.scoreattack)
-- Our run ends (its done line went): the result panel in their place, its best read at the end; the record line once
-- every run ended.
round.board['2002']={ready=true,score=60,ending='win',tenths=700}
state.s.phase,state.best='result',{score=60,s=70,new=true}
board.tick()
assert(not kit.shown.scoreattack and not kit.shown.scoreattack_board and kit.shown.scoreattack_result)
assert(res.head.text=='Target Practice' and res.head.c=='teal' and res.sub.text=='Cleared · score 60 · 1:10.0')
assert(res.note.text=='Results still to come: 1.' and res.rows[1].label.text=='',res.note.text)
kit.away=true; board.tick()
assert(not kit.shown.scoreattack_result,'A pause hides the panel too')
kit.away=false
state.s,state.best=nil,nil -- The run's own 10 s are over: its best stays on the panel.
round.board['1001'].ending,round.board['1001'].tenths='time',900
board.tick()
assert(res.note.text==en.challenge.record,res.note.text)
-- The ranking: its rows, ours in teal, each difficulty; shown SHOW s after it when no end line comes.
round.list={{id='2002',score=60,tenths=700,ending='win',place=1},{id='1001',score=50,tenths=900,ending='time',place=2}}
round.phase='ranked'
board.tick()
assert(res.rows[1].label.text=='1  Eve' and res.rows[1].level.text=='Normal' and res.rows[1].label.c=='teal')
assert(res.rows[2].label.text=='2  Ann' and res.rows[2].level.text=='Hard' and res.rows[2].value.text=='50  1:30.0')
assert(res.rows[3].label.text=='' and res.note.text==en.challenge.record)
clock=clock+19.9; board.tick()
assert(kit.shown.scoreattack_result,'Shown 20 s')
clock=clock+0.1; board.tick()
assert(not kit.shown.scoreattack_result,'Then closed')
assert(#told==0,'Nothing said with the kit up')
-- The next round: the end line closes the panel at once; the words follow the game's language, picked again at each
-- root build.
kit.lang='fr-FR'
kit.rebuild()
card,bd,res=kit.groups.scoreattack.view,kit.groups.scoreattack_board.view,kit.groups.scoreattack_result.view
round={n=3,ids={'1001','2002'},me='2002',def=targets,phase='ranked',board={['2002']={ready=true,score=10,
    ending='dead',tenths=900}},list={{id='1001',score=20,tenths=900,ending='time',place=1}}}
board.tick()
assert(kit.shown.scoreattack_result and res.head.text=='Entraînement au tir' and res.head.c=='warn')
assert(res.sub.text=='Morte · score 10 · 1:30.0' and res.note.text=='Hors classement.',res.sub.text)
round.phase,round.why='over','host'
board.tick()
assert(not kit.shown.scoreattack_result and #told==0,'The end line after a ranking: closed, nothing said')
kit.lang='en-US'
-- A round that ends without a ranking says why once, kit up or not: the host left, or the round was cancelled.
round={n=4,ids={'1001','2002'},me='2002',def=targets,phase='over',why='host_left',board={}}
board.tick(); board.tick()
assert(#told==1 and told[1]==en.scoreattack.host_left and not kit.shown.scoreattack_result,told[1])
round={n=5,ids={'1001','2002'},me='2002',def=targets,phase='over',why='host_lost',board={}}
board.tick()
assert(#told==2 and told[2]==en.scoreattack.host_left)
for n,why in ipairs({'host','void'}) do
    round={n=5+n,ids={'1001','2002'},me='2002',def=nil,phase='over',why=why,board={}}
    board.tick()
    assert(told[#told]==en.scoreattack.cancelled and #told==2+n,why)
end
for n,why in ipairs({'left','replaced','reload','coop off'}) do
    round={n=7+n,ids={'1001','2002'},me='2002',def=nil,phase='over',why=why,board={}}
    board.tick()
end
assert(#told==4,'Those say nothing')
-- With the kit off: the start, each wave, our end and our place as notices, each once.
told={}
kit.is_off=true
round={n=20,ids={'1001','2002'},me='2002',def=swarm,phase='play',board={['2002']={ready=true}}}
state.s,state.now={def=swarm,phase='countdown',t0=105,wave=0,score=0},100
board.tick(); board.tick()
assert(#told==1 and told[1]=='Antlion Swarm starts in 5 s.',told[1])
state.s.phase,state.s.wave=('wave'),1
board.tick(); board.tick()
assert(#told==2 and told[2]=='Antlion Swarm: wave 1/'..#swarm.waves..'.',told[2])
round.board['2002']={ready=true,score=120,ending='time',tenths=1800}
state.s.phase='result'
board.tick()
assert(#told==3 and told[3]=='Antlion Swarm: Time up, score 120, time 3:00.0.',told[3])
round.list,round.phase={{id='1001',score=150,tenths=1700,ending='win',place=1},
    {id='2002',score=120,tenths=1800,ending='time',place=2}},'ranked'
board.tick(); board.tick()
assert(#told==4 and told[4]=='Score attack: you placed 2 of 2.',told[4])
round={n=21,ids={'1001','2002'},me='2002',def=swarm,phase='ranked',board={},
    list={{id='1001',score=150,tenths=1700,ending='win',place=1}}}
board.tick()
assert(#told==5 and told[5]=='Not ranked.',told[5])
-- A success that wrote a new best: the record line after our end, once.
round={n=23,ids={'1001','2002'},me='2002',def=swarm,phase='play',board={['2002']={ready=true,score=300,
    ending='win',tenths=1200}}}
state.s,state.now,state.best={def=swarm,phase='result',t0=105,wave=3,score=300},300,{score=300,s=120,new=true}
board.tick(); board.tick()
assert(#told==7 and told[6]=='Antlion Swarm: Cleared, score 300, time 2:00.0.' and told[7]==en.challenge.record,tostring(told[7]))
state.best=nil
kit.is_off=false
-- An error in the HUD: one STOP line, every group hidden, notices from then on.
told={}
round={n=22,ids={'1001','2002'},me='2002',def=swarm,phase='play',board={['2002']={ready=true}}}
state.s,state.now={def=swarm,phase='countdown',t0=105,wave=0,score=0},100
kit.raise='widget gone'
board.tick()
kit.raise=nil
assert(#logs==1 and logs[1]=='STOP: HUD: widget gone' and not kit.shown.scoreattack,logs[1])
board.tick()
assert(#logs==1 and #told==0,'The start was marked said in the failed tick')
state.s.phase,state.s.wave='wave',1
board.tick()
assert(#told==1 and told[1]:find('wave 1/',1,true),'Notices now')
-- stop hides every group (coop off: no tick may come after it).
local b2=Board.new({round=function() return round end,run=function() return state.s,state.now end,name=name,
    level=level,clock=function() return clock end,log=function() end})
b2.hud({kit=kit,theme=theme,settings=settings})
b2.tick()
assert(kit.shown.scoreattack)
b2.stop()
assert(not kit.shown.scoreattack and not kit.shown.scoreattack_board and not kit.shown.scoreattack_result)
print('scoreattack_board_test: ok')
