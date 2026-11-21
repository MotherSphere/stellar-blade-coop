-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The photo hunt's screens (online/modes/photohunt/ui/board.lua): the card's title line from the countdown to Time up
-- (also at a full board), its target rows (open, you, the taker's name) and its last line (our points and place, as
-- the host ranks); the world's words; the result panel's line, notes and ranking with each last point's time. Then on
-- a fake kit and round: the two groups' places; the card from the countdown (ours in teal, hidden under a pause and on
-- the title screen); the result panel from our end, with the ranking once it comes, closed SHOW seconds after it or
-- after the no-ranking note; the words in the game's language; each target taken said once a taker, kit up or not, a
-- player who left keeping her name; the shot words queued until the selfie mode closes, the strongest one a target a
-- selfie session; the round's notices said with the kit up (the start with the Camera's, each sit-out, each stop of
-- the photo checks, a reloaded game); a photo hunt without a ranking says why once; with the kit off GO, our end, the
-- first three, our place and a new personal best come as notices; an error in the HUD gives one STOP line and notices
-- from then on; stop hides every group.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Board=require('online.modes.photohunt.ui.board')
local T=require('ui.text')
local en=T.en

local names={['1001']='Ann',['2002']='Eve',['3003']='ABCDEFGHIJKLMNOPQRS',['4004']='Dee'}
local function name(id) return names[id] end -- nil for one not in the session, as the wiring's.
local function row(id,points,s,place) return {id=id,points=points,s=s,place=place} end
local ROWS={'Cat4','MemoryOfXion','Butterfly12'}

-- The card: PHOTO HUNT over the countdown, the time left, then Time up; Time up too once every target has a taker.
-- Its last line says 1 point, 0 points and 2 points.
local cur={seed=7,minutes=10,ids={'1001','2002','3003','4004'},me='4004',go=100,phase='play',rows=ROWS,board={}}
local title,rows,line=Board.card(cur,101,en,name)
assert(title=='PHOTO HUNT  Starts in 4',title)
assert(#rows==3 and rows[1].label=='Cat 4' and rows[2].label=='Memory of Xion' and rows[3].label=='Butterfly 12')
assert(rows[1].value=='open' and not rows[1].ours and line=='0 points · place 1',line)
assert(Board.card(cur,105,en,name)=='PHOTO HUNT  10:00')
assert(Board.card(cur,105+600-62,en,name)=='PHOTO HUNT  1:02')
assert(Board.card(cur,105+600,en,name)=='PHOTO HUNT  Time up')
-- Takers: ours as you, another's by name; our points and place.
cur.board={[1]={id='4004',s=40},[3]={id='1001',s=90}}
title,rows,line=Board.card(cur,200,en,name)
assert(title=='PHOTO HUNT  8:25' and rows[1].value=='you' and rows[1].ours and rows[2].value=='open')
assert(rows[3].value=='Ann' and not rows[3].ours and line=='1 point · place 1',line)
cur.board[2]={id='1001',s=120}
title,rows,line=Board.card(cur,200,en,name)
assert(title=='PHOTO HUNT  Time up' and line=='1 point · place 2',title)
assert(select(3,Board.card({go=100,minutes=10,ids={'1','2'},me='1',rows=ROWS,
    board={[1]={id='1',s=5},[2]={id='1',s=6}}},200,en,name))=='2 points · place 1','2 points')
-- The place as the host ranks: more points first, then the earlier last point; 0 points share the last place.
assert(select(2,Board.standing({ids={'1','2','3'},me='2',board={[1]={id='1',s=50},[2]={id='2',s=60}}}))==2)
assert(select(2,Board.standing({ids={'1','2','3'},me='2',board={[1]={id='1',s=70},[2]={id='2',s=60}}}))==1)
assert(select(2,Board.standing({ids={'1','2','3'},me='3',board={[1]={id='1',s=70},[2]={id='2',s=60}}}))==3)
assert(select(2,Board.standing({ids={'1','2','3'},me='3',board={[1]={id='1',s=70}}}))==2,'0 points: shared last')
assert(select(2,Board.standing({ids={'1','2','3'},me='3',board={}}))==1,'Nobody scored: all first')
-- The world's words; another alias as it is.
assert(Board.where('Xion',en)=='in Xion' and Board.where('WasteLandA',en)=='in the Wasteland')
assert(Board.where('WasteLandB',en)=='in the Great Desert' and Board.where('Moon_2',en)=='in Moon_2')

-- The result panel: our points from the board before the ranking, with the wait; Not ranked. once a ranking without
-- us came; New personal best. when ours wrote one; nothing else then; the note that none came.
local head,sub,note,list=Board.result(cur,en,name)
assert(head=='Photo hunt' and sub=='1 point' and note=="Waiting for the host's ranking." and #list==0,sub)
cur.list={row('1001',2,120,1),row('3003',0,0,2)}
_,sub,note,list=Board.result(cur,en,name)
assert(sub=='' and note=='Not ranked.' and #list==2 and list[1].label=='1  Ann' and list[1].time=='2:00'
    and list[1].value=='2' and not list[1].ours and list[2].time=='',note)
cur.list={row('1001',2,120,1),row('4004',1,40,2),row('3003',0,0,3)}
cur.best=true
_,sub,note,list=Board.result(cur,en,name)
assert(sub=='1 point' and note=='New personal best.' and list[2].ours and list[2].time=='0:40'
    and list[3].label=='3  ABCDEFGHIJKLMNOPQRS',sub)
cur.best=false
_,_,note=Board.result(cur,en,name)
assert(note=='',note)
_,sub,note=Board.result({me='2002',phase='over',why='norank',rows=ROWS,board={[2]={id='2002',s=5}}},en,name)
assert(sub=='1 point' and note=='No ranking came from the host.',note)
_,sub=Board.result({me='2002',phase='ranked',board={},list={row('2002',3,700,1)}},en,name)
assert(sub=='3 points','A ranking heard after a reload: our row in it')

-- The screens on a fake kit.
local kit={groups={},shown={},is_off=false,away=false,lang='en-US'}
function kit.add(gname,place,build)
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
    kit.groups[gname]=g
end
function kit.rebuild() for _,g in pairs(kit.groups) do g.rebuild() end end -- A root build: new views.
function kit.view(gname) return not kit.is_off and kit.groups[gname] and kit.groups[gname].view or nil end
function kit.show(gname,on) kit.shown[gname]=on==true end
function kit.off() return kit.is_off end
function kit.paused() return kit.away end
function kit.language() return kit.lang end
local theme={text='text',grey='grey',teal='teal',warn='warn',panel='panel'}
local settings={ui_language='game'}
local told,logs,clock,selfie={},{},100,false
local round,title_screen=nil,false
local board=Board.new({round=function() return round end,name=name,tell=function(build) told[#told+1]=build(en) end,
    clock=function() return clock end,log=function(text) logs[#logs+1]=text end,
    title=function() return title_screen end,selfie=function() return selfie end})
board.tick() -- No HUD, no round: nothing.
board.feedback(1,'counts')
assert(#told==0 and #logs==0)
board.hud({kit=kit,theme=theme,settings=settings})
local p=kit.groups.photohunt.place
assert(p.x+p.w==3840-96 and p.y==96 and p.pivot.X==1 and p.pivot.Y==0,'The card: top right')
assert(#kit.groups.photohunt.view.rows==4)
p=kit.groups.photohunt_result.place
assert(p.x+p.w/2==1920 and p.y==96 and p.pivot.X==0.5 and #kit.groups.photohunt_result.view.rows==8,'The panel')
local card,res=kit.groups.photohunt.view,kit.groups.photohunt_result.view
-- The countdown: the card with the three targets open; no panel; nothing said with the kit up.
round={seed=7,minutes=1,ids={'1001','2002','3003'},me='2002',go=100,phase='play',rows=ROWS,board={}}
board.tick()
assert(kit.shown.photohunt and not kit.shown.photohunt_result and card.title.text=='PHOTO HUNT  Starts in 5')
assert(card.title.c=='warn' and card.rows[1].label.text=='Cat 4' and card.rows[1].value.text=='open')
assert(card.rows[4].label.text=='0 points · place 1' and card.rows[4].value.text=='' and card.rows[4].label.c=='text')
assert(#told==0,'Nothing said with the kit up')
-- The title screen: the co-op saves' badge takes the card's place.
title_screen=true; board.tick()
assert(not kit.shown.photohunt,'Hidden on the title screen')
title_screen=false; board.tick()
assert(kit.shown.photohunt)
-- GO, then the host's board: ours in teal, another's taker by name, each said once a taker, kit up or not.
clock=105
round.board={[1]={id='2002',s=10},[3]={id='3003',s=20}}
board.tick(); board.tick()
assert(card.title.text=='PHOTO HUNT  1:00' and card.rows[1].value.text=='you' and card.rows[1].value.c=='teal')
assert(card.rows[1].label.c=='teal' and card.rows[3].value.text=='ABCDEFGHIJKLMNOP...' and card.rows[3].value.c=='text')
assert(card.rows[4].label.text=='1 point · place 1',card.rows[4].label.text)
assert(#told==2 and told[1]=='You took Cat 4.' and told[2]=='ABCDEFGHIJKLMNOP... took Butterfly 12.',told[2])
-- A pause hides it.
kit.away=true; board.tick()
assert(not kit.shown.photohunt and not kit.shown.photohunt_result)
kit.away=false; board.tick()
assert(kit.shown.photohunt)
-- The shot words: queued while the selfie mode is open, the strongest a target, said when it closes; none for a
-- target the round does not have or an unknown word. A later selfie session queues again.
selfie=true
board.feedback(2,'close')
board.feedback(2,'counts')
board.feedback(2,'yours') -- Weaker than counts: kept out.
board.feedback(3,'taken')
board.feedback(1,'close')
board.feedback(1,'yours')
board.feedback(4,'counts')
board.feedback(2,'nonsense')
board.tick()
assert(#told==2,'Nothing while the selfie mode is open')
names['3003']=nil -- She left: her name stays as the card knew it.
selfie=false; board.tick()
assert(#told==5 and told[3]=='Cat 4 is yours already.' and told[4]=='Memory of Xion counts: 1 point.',told[4])
assert(told[5]=='Butterfly 12 was taken by ABCDEFGHIJKLMNOP....',told[5])
assert(card.rows[3].value.text=='ABCDEFGHIJKLMNOP...','A leaver keeps her name')
names['3003']='ABCDEFGHIJKLMNOPQRS'
board.tick()
assert(#told==5,'Said once')
board.feedback(2,'close')
board.tick()
assert(#told==6 and told[6]=='Memory of Xion was in your photo: get closer, centre it and face it.',told[6])
-- Our end: Time up on the card, the panel with the wait.
clock=165
board.tick()
assert(kit.shown.photohunt and kit.shown.photohunt_result and card.title.text=='PHOTO HUNT  Time up')
assert(res.head.text=='Photo hunt' and res.sub.text=='1 point' and res.note.text=="Waiting for the host's ranking.")
assert(res.rows[1].label.text=='',res.sub.text)
-- A pause hides the panel too; the title screen only the card.
kit.away=true; board.tick()
assert(not kit.shown.photohunt and not kit.shown.photohunt_result)
kit.away=false; title_screen=true; board.tick()
assert(not kit.shown.photohunt and kit.shown.photohunt_result)
title_screen=false; board.tick()
-- The ranking: the card goes, its rows on the panel, ours in teal; the new best; closed 20 s after it.
clock=175
round.phase,round.list,round.best='ranked',{row('2002',2,40,1),row('3003',1,20,2),row('1001',0,0,3)},true
round.board[2]={id='2002',s=40}
board.tick()
assert(#told==7 and told[7]=='You took Memory of Xion.',told[7])
assert(not kit.shown.photohunt and kit.shown.photohunt_result and res.note.text=='New personal best.')
assert(res.sub.text=='2 points' and res.rows[1].label.text=='1  Eve' and res.rows[1].label.c=='teal')
assert(res.rows[1].time.text=='0:40' and res.rows[1].value.text=='2')
assert(res.rows[2].label.text=='2  ABCDEFGHIJKLMNOP...')
assert(res.rows[3].time.text=='' and res.rows[3].value.text=='0' and res.rows[4].label.text=='')
clock=194; board.tick()
assert(kit.shown.photohunt_result,'Shown 20 s')
clock=195; board.tick()
assert(not kit.shown.photohunt_result,'Then closed')
assert(#told==7,'Nothing more said with the kit up')
-- A full board ends a guest's round before the time: Time up and the panel with the wait.
told={}
round={seed=6,minutes=10,ids={'1001','2002'},me='2002',go=100,phase='play',rows=ROWS,
    board={[1]={id='1001',s=10},[2]={id='1001',s=20},[3]={id='1001',s=30}}}
board.tick()
assert(card.title.text=='PHOTO HUNT  Time up' and kit.shown.photohunt_result and #told==3)
-- A ranking heard after our Lua reload (no go): the panel, in the game's language, picked again at a root build.
kit.lang='fr-FR'
kit.rebuild()
card,res=kit.groups.photohunt.view,kit.groups.photohunt_result.view
told={}
round={seed=8,world='Xion',ids={},me='2002',phase='ranked',board={},list={row('1001',2,30,1),row('2002',1,50,2)}}
board.tick()
assert(not kit.shown.photohunt and kit.shown.photohunt_result and res.head.text==T.fr.photohunt.title)
assert(res.sub.text==T.fr.photohunt.one.points and res.rows[2].time.text=='0:50' and #told==0,res.sub.text)
kit.lang='en-US'
kit.rebuild()
card,res=kit.groups.photohunt.view,kit.groups.photohunt_result.view
-- No ranking came: the note on the panel, no notice with the kit up, closed 20 s later.
round={seed=9,minutes=1,ids={'1001','2002'},me='2002',go=100,phase='over',why='norank',rows=ROWS,
    board={[1]={id='2002',s=30}}}
clock=200
board.tick()
assert(kit.shown.photohunt_result and not kit.shown.photohunt and res.note.text=='No ranking came from the host.')
assert(#told==1 and told[1]=='You took Cat 4.',told[1])
clock=220; board.tick()
assert(not kit.shown.photohunt_result)
-- A photo hunt that ends without a ranking says why once, kit up or not; the others say nothing.
told={}
round={seed=10,minutes=1,ids={'1001','2002'},me='2002',go=100,phase='over',why='host_left',rows=ROWS,board={}}
board.tick(); board.tick()
assert(#told==1 and told[1]=='The host left. This photo hunt has no ranking.' and not kit.shown.photohunt)
assert(not kit.shown.photohunt_result)
round={seed=11,minutes=1,ids={'1001','2002'},me='2002',go=100,phase='over',why='void',rows=ROWS,board={}}
board.tick(); board.tick()
assert(#told==2 and told[2]=='The photo hunt was cancelled.',told[2])
for _,why in ipairs({'left','replaced','out','coop off'}) do
    round={seed=12,minutes=1,ids={'1001','2002'},me='2002',go=100,phase='over',why=why,rows=ROWS,board={}}
    board.tick()
end
assert(#told==2 and not kit.shown.photohunt_result,'Those say nothing')
-- The round's notices, said with the kit up: the start with the host's name cut and the Camera's after it, each
-- sit-out, each stop of the photo checks, a reloaded game.
told={}
board.notice('starts','ABCDEFGHIJKLMNOPQRS',10,'Xion','Cat4','Cat9','MemoryOfXion')
assert(told[1]=='ABCDEFGHIJKLMNOP... starts a photo hunt in Xion: Cat 4, Cat 9, Memory of Xion. 10 min.',told[1])
assert(told[2]=='Use the Camera to take the photos.' and #told==2)
board.notice('starts','Ann',15,'WasteLandB','Fish7','Butterfly2','Odd_Row')
assert(told[3]=='Ann starts a photo hunt in the Great Desert: Fish 7, Butterfly 2, Odd_Row. 15 min.',told[3])
board.notice('out','off'); board.notice('out','slot'); board.notice('out','checks')
assert(told[5]=='Photo hunt is off in Options.' and told[6]=='Load a co-op save to play the photo hunt.')
assert(told[7]=='Photo checks are off in this game.')
board.notice('stopped','fault'); board.notice('stopped','unpinned'); board.notice('stopped','names')
assert(told[8]=='Photo checks stopped in this game: restart the game to play.')
assert(told[9]=='Photo checks are off in this game.' and told[10]==en.photohunt.stopped.names)
board.notice('reloaded')
assert(told[11]=='Your game reloaded: your photos no longer count in this photo hunt.' and #told==11)
-- With the kit off: GO, our end, the first three, our place and a new personal best, each once; each target taken
-- as always.
told={}
kit.is_off=true
clock=100
round={seed=20,minutes=2,ids={'1001','2002','3003','4004'},me='2002',go=100,phase='play',rows=ROWS,board={}}
board.tick()
assert(#told==0,'The countdown: nothing')
clock=105
board.tick(); board.tick()
assert(#told==1 and told[1]=='Photo hunt: take your photos. 2 min left.',told[1])
round.board={[2]={id='2002',s=30}}
board.tick()
assert(#told==2 and told[2]=='You took Memory of Xion.',told[2])
clock=225
board.tick(); board.tick()
assert(#told==3 and told[3]=='Photo hunt over: 1 point.',told[3])
round.phase,round.list,round.best='ranked',{row('1001',2,90,1),row('2002',1,30,2),row('3003',0,0,3),
    row('4004',0,0,3)},true
board.tick(); board.tick()
assert(#told==6 and told[4]=='Photo hunt: 1. Ann 2, 2. Eve 1, 3. ABCDEFGHIJKLMNOP... 0.',told[4])
assert(told[5]=='You placed 2 of 4.' and told[6]=='New personal best.',told[6])
round={seed=21,minutes=2,world='Xion',ids={},me='2002',phase='ranked',board={},list={row('1001',1,30,1)}}
board.tick()
assert(#told==8 and told[7]=='Photo hunt: 1. Ann 1.' and told[8]=='Not ranked.',told[8])
round={seed=22,minutes=2,world='Xion',ids={},me='2002',phase='ranked',board={},list={}}
board.tick()
assert(#told==9 and told[9]=='Not ranked.','An empty ranking: no first three')
round={seed=23,minutes=1,ids={'1001','2002'},me='2002',go=100,phase='over',why='norank',rows=ROWS,board={}}
board.tick(); board.tick()
assert(#told==10 and told[10]=='No ranking came from the host.',told[10])
-- A host's third point: the board full and the ranking in one tick; our end said before the first three.
told={}
round={seed=24,minutes=5,ids={'1001','2002'},me='2002',go=100,phase='ranked',rows=ROWS,
    board={[1]={id='2002',s=10},[2]={id='2002',s=20},[3]={id='1001',s=30}},list={row('2002',2,20,1),row('1001',1,30,2)}}
board.tick()
assert(#told==6 and told[4]=='Photo hunt over: 2 points.' and told[6]=='You placed 1 of 2.',told[4])
kit.is_off=false
-- An error in the HUD: one STOP line, every group hidden, notices from then on.
told={}
clock=105
round={seed=30,minutes=1,ids={'1001','2002'},me='2002',go=100,phase='play',rows=ROWS,board={}}
kit.raise='widget gone'
board.tick()
kit.raise=nil
assert(#logs==1 and logs[1]=='STOP: HUD: widget gone' and not kit.shown.photohunt,logs[1])
assert(#told==0,'GO was marked said before the HUD failed')
clock=165
board.tick()
assert(#logs==1 and #told==1 and told[1]=='Photo hunt over: 0 points.','Notices now')
-- stop hides every group (coop off: no tick may come after it).
local b2=Board.new({round=function() return round end,name=name,clock=function() return clock end,
    log=function() end})
b2.hud({kit=kit,theme=theme,settings=settings})
clock=105
b2.tick()
assert(kit.shown.photohunt)
b2.stop()
assert(not kit.shown.photohunt and not kit.shown.photohunt_result)
b2.notice('reloaded') -- No tell: nothing.
b2.feedback(1,'counts')
b2.tick() -- No selfie(): the queue goes at once, to no tell.
print('photohunt_board_test: ok')
