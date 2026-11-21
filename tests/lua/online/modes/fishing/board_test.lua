-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The fishing tournament's screens (online/modes/fishing/ui/board.lua): the corner board's title line and its rows
-- (the go line's players at 0 before the first board, the top three, ours fourth when we are not among them); the
-- result panel's line, notes and ranking. Then on a fake kit and round: the two groups' places; the corner board
-- from the countdown to Time up (ours in teal, hidden under a pause); the result panel from our end, with the ranking
-- once it comes, closed SHOW seconds after it or after the no-ranking note; the words in the game's language; the
-- round's notices said with the kit up; a tournament without a ranking says why once; with the kit off GO, each change
-- of our place or points, our end, the first three and our place come as notices; an error in the HUD gives one STOP
-- line and notices from then on; stop hides every group.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Board=require('online.modes.fishing.ui.board')
local T=require('ui.text')
local en=T.en

local names={['1001']='Ann',['2002']='Eve',['3003']='ABCDEFGHIJKLMNOPQRS',['4004']='Dee'}
local function name(id) return names[id] or id end
local function row(id,points,catches,place) return {id=id,points=points,catches=catches,place=place} end

-- The corner: FISHING over the countdown, the time left, then Time up; before the first board, the go line's players
-- at 0, all first.
local cur={seed=7,minutes=10,ids={'1001','2002','3003','4004'},me='4004',go=100,phase='play'}
local title,rows=Board.corner(cur,101,en)
assert(title=='FISHING  Starts in 4' and #rows==4 and rows[4].id=='4004' and rows[1].place==1
    and rows[1].points==0,title)
title=Board.corner(cur,105,en)
assert(title=='FISHING  10:00',title)
title=Board.corner(cur,105+600-62,en)
assert(title=='FISHING  1:02',title)
title=Board.corner(cur,105+600,en)
assert(title=='FISHING  Time up',title)
-- The last board's top three, then ours fourth; ours among the three: three rows.
cur.board={row('1001',240,2,1),row('2002',138,1,2),row('3003',138,1,2),row('4004',30,1,4)}
_,rows=Board.corner(cur,200,en)
assert(#rows==4 and rows[3].id=='3003' and rows[3].place==2 and rows[4].id=='4004' and rows[4].place==4)
cur.me='2002'
_,rows=Board.corner(cur,200,en)
assert(#rows==3 and rows[2].id=='2002',#rows)
_,rows=Board.corner({ids={'1001','2002','3003','4004','5005'},me='5005',go=100,minutes=1,board={row('1001',0,0,1)}},
    200,en)
assert(#rows==1,'A player off the board: not shown')

-- The result panel: our points and fish from the last board before the ranking, with the wait; Not ranked. once a
-- ranking without us came; New personal best. when ours wrote one; nothing else then; the note that none came.
local head,sub,note,list=Board.result(cur,en,name)
assert(head=='Fishing tournament' and sub=='138 points · 1 fish' and note=="Waiting for the host's ranking."
    and #list==0,sub)
cur.list={row('1001',240,2,1),row('3003',138,1,2)}
_,sub,note,list=Board.result(cur,en,name)
assert(sub=='' and note=='Not ranked.' and #list==2 and list[1].label=='1  Ann' and list[1].fish=='2 fish'
    and list[1].value=='240' and not list[1].ours,note)
cur.list={row('1001',240,2,1),row('2002',138,1,2),row('3003',138,1,2)}
cur.best=true
_,sub,note,list=Board.result(cur,en,name)
assert(sub=='138 points · 1 fish' and note=='New personal best.' and list[2].ours
    and list[3].label=='2  ABCDEFGHIJKLMNOPQRS')
cur.best=false
_,_,note=Board.result(cur,en,name)
assert(note=='',note)
_,sub,note=Board.result({me='2002',phase='over',why='norank',board={row('2002',60,2,1)}},en,name)
assert(sub=='60 points · 2 fish' and note=='No ranking came from the host.',note)
_,sub=Board.result({me='2002',phase='play'},en,name)
assert(sub=='','No row: no line')

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
local told,logs,clock={},{},100
local round=nil
local board=Board.new({round=function() return round end,name=name,tell=function(build) told[#told+1]=build(en) end,
    clock=function() return clock end,log=function(line) logs[#logs+1]=line end})
board.tick() -- No HUD, no round: nothing.
assert(#told==0 and #logs==0)
board.hud({kit=kit,theme=theme,settings=settings})
local p=kit.groups.fishing.place
assert(p.x+p.w==3840-96 and p.y==96 and p.pivot.X==1 and p.pivot.Y==0 and not p.shown,'The corner: top right')
assert(#kit.groups.fishing.view.rows==4)
p=kit.groups.fishing_result.place
assert(p.x+p.w/2==1920 and p.y==96 and p.pivot.X==0.5 and #kit.groups.fishing_result.view.rows==8,'The panel: centre')
local corner,res=kit.groups.fishing.view,kit.groups.fishing_result.view
-- The countdown: the corner with the go line's players, ours in teal; no panel; nothing said with the kit up.
round={seed=7,minutes=1,ids={'1001','2002','3003'},me='2002',go=100,phase='play'}
board.tick()
assert(kit.shown.fishing and not kit.shown.fishing_result and corner.title.text=='FISHING  Starts in 5')
assert(corner.title.c=='warn' and corner.rows[1].label.text=='1  Ann' and corner.rows[2].label.c=='teal')
assert(corner.rows[3].label.text=='1  ABCDEFGHIJKLMNOP...' and corner.rows[3].back.on and not corner.rows[4].back.on)
assert(corner.rows[4].label.text=='' and corner.rows[2].value.text=='0' and corner.rows[1].value.c=='text')
-- GO, then the host's board.
clock=105
round.board={row('1001',138,1,1),row('2002',60,2,2),row('3003',0,0,3)}
board.tick()
assert(corner.title.text=='FISHING  1:00' and corner.rows[2].value.text=='60' and corner.rows[2].value.c=='teal')
assert(#told==0,'The kit shows it: no notice')
-- A pause hides it.
kit.away=true; board.tick()
assert(not kit.shown.fishing and not kit.shown.fishing_result)
kit.away=false; board.tick()
assert(kit.shown.fishing)
-- Our end: Time up in the corner, the panel with the wait.
clock=165
board.tick()
assert(kit.shown.fishing and kit.shown.fishing_result and corner.title.text=='FISHING  Time up')
assert(res.head.text=='Fishing tournament' and res.sub.text=='60 points · 2 fish'
    and res.note.text=="Waiting for the host's ranking." and res.rows[1].label.text=='',res.sub.text)
-- The ranking: the corner goes, its rows on the panel, ours in teal; the new best; closed 20 s after it.
clock=175
round.phase,round.list,round.best='ranked',{row('2002',198,3,1),row('1001',138,1,2)},true
board.tick()
assert(not kit.shown.fishing and kit.shown.fishing_result and res.note.text=='New personal best.')
assert(res.sub.text=='198 points · 3 fish' and res.rows[1].label.text=='1  Eve' and res.rows[1].label.c=='teal')
assert(res.rows[1].fish.text=='3 fish' and res.rows[1].value.text=='198' and res.rows[2].label.text=='2  Ann')
assert(res.rows[2].value.c=='text' and res.rows[3].label.text=='' and res.rows[3].fish.text=='')
clock=194; board.tick()
assert(kit.shown.fishing_result,'Shown 20 s')
clock=195; board.tick()
assert(not kit.shown.fishing_result,'Then closed')
assert(#told==0,'Nothing said with the kit up')
-- A ranking heard after our Lua reload (no go): the panel, in the game's language, picked again at a root build.
kit.lang='fr-FR'
kit.rebuild()
corner,res=kit.groups.fishing.view,kit.groups.fishing_result.view
round={seed=8,minutes=5,ids={},me='2002',phase='ranked',list={row('1001',30,1,1),row('2002',0,1,2)}}
board.tick()
assert(not kit.shown.fishing and kit.shown.fishing_result and res.head.text=='Tournoi de pêche')
assert(res.sub.text=='0 points · poissons : 1' and res.rows[2].fish.text=='Poissons : 1',res.sub.text)
kit.lang='en-US'
kit.rebuild()
corner,res=kit.groups.fishing.view,kit.groups.fishing_result.view
-- No ranking came: the note on the panel, no notice with the kit up, closed 20 s later.
round={seed=9,minutes=1,ids={'1001','2002'},me='2002',go=100,phase='over',why='norank',
    board={row('2002',30,1,1),row('1001',0,0,2)}}
clock=200
board.tick()
assert(kit.shown.fishing_result and not kit.shown.fishing and res.note.text=='No ranking came from the host.')
assert(#told==0)
clock=220; board.tick()
assert(not kit.shown.fishing_result)
-- A tournament that ends without a ranking says why once, kit up or not; the others say nothing.
round={seed=10,minutes=1,ids={'1001','2002'},me='2002',go=100,phase='over',why='host_left'}
board.tick(); board.tick()
assert(#told==1 and told[1]==en.fishing.host_left and not kit.shown.fishing and not kit.shown.fishing_result)
round={seed=11,minutes=1,ids={'1001','2002'},me='2002',go=100,phase='over',why='void'}
board.tick(); board.tick()
assert(#told==2 and told[2]=='The tournament was cancelled.',told[2])
for _,why in ipairs({'left','replaced','out','coop off'}) do
    round={seed=12,minutes=1,ids={'1001','2002'},me='2002',go=100,phase='over',why=why}
    board.tick()
end
assert(#told==2 and not kit.shown.fishing_result,'Those say nothing')
-- The round's notices, said with the kit up: the start with the host's name cut, each sit-out, a reloaded game.
board.notice('starts','ABCDEFGHIJKLMNOPQRS',10)
board.notice('out','off'); board.notice('out','slot'); board.notice('out','table')
board.notice('reloaded')
assert(told[3]=='ABCDEFGHIJKLMNOP... starts a fishing tournament: 10 min.',told[3])
assert(told[4]=='Fishing tournament is off in Options.' and told[5]=='Load a co-op save to fish in the tournament.')
assert(told[6]=='Could not read the fish table.' and told[7]==en.fishing.reloaded and #told==7)
-- With the kit off: GO, each change of our place or points, our end, the first three and our place, each once.
told={}
kit.is_off=true
clock=100
round={seed=20,minutes=2,ids={'1001','2002','3003','4004'},me='2002',go=100,phase='play'}
board.tick()
assert(#told==0,'The countdown: nothing')
clock=105
round.board={row('1001',0,0,1),row('2002',0,0,1),row('3003',0,0,1),row('4004',0,0,1)}
board.tick(); board.tick()
assert(#told==1 and told[1]=='Fishing tournament: start fishing. 2 min left.',told[1])
round.board={row('2002',138,1,1),row('1001',0,0,2),row('3003',0,0,2),row('4004',0,0,2)}
board.tick(); board.tick()
assert(#told==2 and told[2]=='Fishing tournament: place 1, 138 points.',told[2])
round.board={row('1001',180,1,1),row('2002',138,1,2),row('3003',0,0,3),row('4004',0,0,3)}
board.tick()
assert(#told==3 and told[3]=='Fishing tournament: place 2, 138 points.',told[3])
clock=225
board.tick(); board.tick()
assert(#told==4 and told[4]=='Fishing tournament: time up, 138 points, 1 fish.',told[4])
round.phase,round.list='ranked',{row('1001',180,1,1),row('2002',138,1,2),row('3003',0,0,3),row('4004',0,0,3)}
board.tick(); board.tick()
assert(#told==6 and told[5]=='Fishing tournament: 1. Ann 180, 2. Eve 138, 3. ABCDEFGHIJKLMNOP... 0.',told[5])
assert(told[6]=='You placed 2 of 4.',told[6])
round={seed=21,minutes=2,ids={},me='2002',phase='ranked',list={row('1001',30,1,1)}}
board.tick()
assert(#told==8 and told[7]=='Fishing tournament: 1. Ann 30.' and told[8]=='Not ranked.',told[8])
round={seed=22,minutes=2,ids={},me='2002',phase='ranked',list={}}
board.tick()
assert(#told==9 and told[9]=='Not ranked.','An empty ranking: no first three')
round={seed=23,minutes=1,ids={'1001','2002'},me='2002',go=100,phase='over',why='norank'}
board.tick(); board.tick()
assert(#told==10 and told[10]=='No ranking came from the host.',told[10])
kit.is_off=false
-- An error in the HUD: one STOP line, every group hidden, notices from then on.
told={}
clock=105
round={seed=30,minutes=1,ids={'1001','2002'},me='2002',go=100,phase='play'}
kit.raise='widget gone'
board.tick()
kit.raise=nil
assert(#logs==1 and logs[1]=='STOP: HUD: widget gone' and not kit.shown.fishing,logs[1])
assert(#told==0,'GO was marked said before the HUD failed')
round.board={row('2002',30,1,1),row('1001',0,0,2)}
board.tick()
assert(#logs==1 and #told==1 and told[1]=='Fishing tournament: place 1, 30 points.','Notices now')
-- stop hides every group (coop off: no tick may come after it).
local b2=Board.new({round=function() return round end,name=name,clock=function() return clock end,
    log=function() end})
b2.hud({kit=kit,theme=theme,settings=settings})
b2.tick()
assert(kit.shown.fishing)
b2.stop()
assert(not kit.shown.fishing and not kit.shown.fishing_result)
b2.notice('reloaded') -- No tell: nothing.
print('fishing_board_test: ok')
