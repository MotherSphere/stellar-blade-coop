-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- online/modes/race/ui/hud.lua, the Doro race's HUD, pure parts and a fake kit: the time and the panel's line; who we
-- are in the results; our live place in a session and among up to 8 racers of a match round (finish time, then
-- checkpoints passed, then the distance to the next one, a DNF last); the results' note and rows (a session's two, a
-- match's own row alone before the host's ranking with the results still to come or a new best, then the ranking with
-- placed finishers first, DNFs after, names cut, Not ranked. without our place); the groups on the kit (8 result rows);
-- each frame the panel or, in a match from our own end, the results with our row in Beta blue, all hidden while away.
-- online/modes/race/run_test.lua drives it through whole races.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local T=require('ui.text')
local Hud=require('online.modes.race.ui.hud')
local clock=0
os.clock=function() return clock end
local w=T.en
local pos,of

-- The time and the line.
assert(Hud.clock(83450)=='1:23.45' and Hud.clock(59999)=='0:59.99' and Hud.clock(-5)=='0:00.00')
assert(Hud.line(w,61000,2,6,1,5,3,8)=='1:01.00  CP 2/6  LAP 1/5  POS 3/8')
assert(Hud.mine({role='host'})=='host' and Hud.mine({role='guest'})=='guest' and Hud.mine({role='match'})=='me')

-- A track along X: checkpoints at 4000 and 8000 cm, 2 laps.
local TRACK={map='/m',laps=2,grid={x=0,y=0,z=0,yaw=0},cps={{x=4000,y=0,z=0,r=400},{x=8000,y=0,z=0,r=400}}}
-- A session race with her out: 1 of 1.
assert(select(2,Hud.place({role='host',m={track=TRACK,me={passed=0},her={out=true}}}))==1)
-- A session race with her in it: her ghost's feet nearer checkpoint 1 than ours, we are 2 of 2.
local duo={role='host',m={track=TRACK,pos={x=1000,y=0,z=0},me={passed=0},her={joined=true,passed=0}}}
pos,of=Hud.place(duo,{X=3000,Y=0,Z=0})
assert(pos==2 and of==2)
-- In a match: us at 6000 past checkpoint 1; one racer past checkpoint 1 nearer the next (ahead), one past none
-- (behind), one finished (ahead of all), one DNF (behind all).
local function match(me,racers)
    return {role='match',pos={x=6000,y=0,z=0},m={track=TRACK,phase='race',me=me},heard={racers=racers}}
end
pos,of=Hud.place(match({passed=1},{{passed=1,pos={x=7000,y=0,z=0}},{passed=0,pos={x=1000,y=0,z=0}},
    {ms=50000,passed=4},{why='map',passed=3}}))
assert(pos==3 and of==5,pos..' of '..of)
-- Our own feet count: nearer the next checkpoint than her, we lead her.
local near=match({passed=1},{{passed=1,pos={x=7000,y=0,z=0}}})
near.pos={x=7500,y=0,z=0}
assert(Hud.place(near)==1)
-- Her ghost not seen (no feet): behind us on a tie of checkpoints.
pos,of=Hud.place(match({passed=1},{{passed=1}}))
assert(pos==1 and of==2)
-- Alone in the round: 1 of 1; no news yet: 1 of 1.
assert(select(2,Hud.place(match({passed=0},{})))==1 and Hud.place({role='match',m={track=TRACK,me={passed=0}}})==1)
-- Our finish beats a racer still going; our DNF comes after her.
assert(Hud.place(match({ms=40000,passed=4},{{passed=4}}))==1)
assert(Hud.place(match({why='quit',passed=0},{{passed=0}}))==2)

-- The results. A session's: placed first, our row You, hers by her name.
local function name_of(e) return e.name or 'Her' end
local note,rows=Hud.results({role='guest',m={phase='results',results={{who='host',ms=31000,pos=2},
    {who='guest',ms=30000,pos=1}}}},w,name_of)
assert(note=='' and #rows==2 and rows[1].label=='1  You' and rows[1].value=='0:30.00' and rows[1].ours)
assert(rows[2].label=='2  Her' and rows[2].value=='0:31.00' and not rows[2].ours)
-- A match before the host's ranking: our row alone, our time or DNF; the note says how many still race, then a new
-- best once none does.
local r={role='match',m={phase='race',me={ms=42000}},heard={waiting=2,best=true}}
note,rows=Hud.results(r,w,name_of)
assert(note=='Results still to come: 2.' and #rows==1 and rows[1].label=='-  You' and rows[1].value=='0:42.00',note)
r.heard.waiting=1
assert(Hud.results(r,w,name_of)=='Results still to come: 1.','One still racing')
r.heard.waiting=0
assert(Hud.results(r,w,name_of)=='New personal best.')
r.heard.best=false
assert(Hud.results(r,w,name_of)=='')
r.m.me={why='map'}
note,rows=Hud.results(r,w,name_of)
assert(rows[1].value=='DNF')
r.heard=nil
assert(Hud.results(r,w,name_of)=='','No news yet')
-- The ranking: up to 8 rows, placed finishers in place order (a shared place kept), then the DNFs in the host's order.
local list={{who='1',ms=30000,pos=1,name='Ann'},{who='me',ms=30005,pos=1},{who='3',ms=31000,pos=3,name='Cat'},
    {who='4',name='Dee'},{who='5',name='Eve'},{who='6',ms=40000,pos=4,name='Fay'},{who='7',ms=41000,pos=5,name='Gil'},
    {who='8',ms=42000,pos=6,name='Hal'}}
r={role='match',m={phase='results',results=list,me={ms=30005}},heard={waiting=1,best=true}}
note,rows=Hud.results(r,w,name_of)
local labels={}
for i,row in ipairs(rows) do labels[i]=row.label..'='..row.value end
assert(table.concat(labels,',')=='1  Ann=0:30.00,1  You=0:30.00,3  Cat=0:31.00,4  Fay=0:40.00,5  Gil=0:41.00,'
    ..'6  Hal=0:42.00,-  Dee=DNF,-  Eve=DNF',table.concat(labels,','))
assert(rows[2].ours and not rows[1].ours and note=='New personal best.','Ranked: the best, never the wait')
r.heard.best=false
assert(Hud.results(r,w,name_of)=='')
-- A ranking without us: Not ranked., whatever the best.
r.m.results={{who='1',ms=30000,pos=1,name='Ann'}}
r.heard.best=true
note,rows=Hud.results(r,w,name_of)
assert(note=='Not ranked.' and #rows==1 and not rows[1].ours)
-- Our DNF listed: placed nowhere, ranked all the same.
r.m.results={{who='1',ms=30000,pos=1},{who='me'}}
r.heard.best=false
note,rows=Hud.results(r,w,name_of)
assert(note=='' and rows[2].label=='-  You' and rows[2].value=='DNF')

-- The groups on a fake kit (as run_test's, with colours), then the frames.
local function fake_kit()
    local kit={groups={},shown={},moved={},is_off=false,lang=nil,sounds={}}
    function kit.add(name,place,build)
        local g={place=place}
        local b={}
        function b.panel(...) g.panel={...} end
        function b.text(x,y,str)
            local e={text=str,x=x,y=y}
            function e.set(t) e.text=t end
            function e.color(c) e.c=c end
            return e
        end
        function b.image(_,_,_,_,tex)
            local e={tex=tex}
            function e.turn(a) e.angle=a end
            return e
        end
        g.view=build(b)
        kit.groups[name]=g
    end
    function kit.view(name) return not kit.is_off and kit.groups[name] and kit.groups[name].view or nil end
    function kit.show(name,on) kit.shown[name]=on==true end
    function kit.move(name,x,y) kit.moved[name]={x,y} end
    function kit.off() return kit.is_off end
    function kit.language() return kit.lang end
    function kit.sound(name) kit.sounds[#kit.sounds+1]=name end
    function kit.project() end -- Nothing on screen: no marker.
    return kit
end
local kit=fake_kit()
local H=Hud.new({clock=function() return clock*1000 end,name=function() return 'Her' end,
    anchor=function() end})
assert(not H.shown(),'No kit yet')
H.hide() -- Nothing to hide: no error.
H.add({kit=kit,theme={beta='beta',text='text',grey='grey',warn='warn',error='error'},settings={}})
assert(H.shown())
H.sound('select')
assert(kit.sounds[1]=='select')
local res=kit.groups.race_results
assert(res.place.x+res.place.w/2==1920 and res.place.y==96 and res.place.h==720 and #res.view.rows==8)
assert(res.view.note.y==186 and res.view.rows[1].label.y==250 and res.view.rows[8].label.y==250+7*56)
assert(res.view.rows[8].label.y<res.place.h-40,'The last row inside the panel')
-- A match race under way: the panel with POS among the round's racers.
clock=10
r={role='match',pos={x=6000,y=0,z=0},m={track=TRACK,phase='race',t_go=5000,slot=0,me={passed=1,flags=0},
    her={out=true},runner={next=2,lap=1,passed=1}},heard={racers={{passed=1,pos={x=7000,y=0,z=0}},{passed=0}}}}
H.draw(r,false)
assert(kit.shown.race_panel and not kit.shown.race_results)
assert(kit.groups.race_panel.view.line.text=='0:05.00  CP 1/2  LAP 1/2  POS 2/3',kit.groups.race_panel.view.line.text)
-- Our finish: the results at once, our row in Beta blue, the wait under the heading.
r.m.me.ms,r.heard.waiting=33000,2
H.draw(r,false)
assert(kit.shown.race_results and not kit.shown.race_panel)
local v=res.view
assert(v.head.text=='RESULTS' and v.sub.text=='' and v.note.text=='Results still to come: 2.')
assert(v.rows[1].label.text=='-  You' and v.rows[1].value.text=='0:33.00' and v.rows[1].label.c=='beta'
    and v.rows[1].value.c=='beta' and v.rows[2].label.text=='' and v.rows[2].label.c=='text')
-- The ranking: names, ours coloured, the fin flags under the heading.
r.m.phase,r.m.me.flags='results',3
r.m.results={{who='2002',ms=32000,pos=1,name=('W'):rep(30)},{who='me',ms=33000,pos=2},{who='3003'}}
H.draw(r,false)
assert(v.sub.text=='fast run · paused' and v.note.text=='')
assert(v.rows[1].label.text=='1  '..('W'):rep(16)..'...' and v.rows[1].label.c=='text',
    'A name cut as core/line.lua cuts it')
assert(v.rows[2].label.text=='2  You' and v.rows[2].label.c=='beta')
assert(v.rows[3].label.text=='-  Partner' and v.rows[3].value.text=='DNF','No name: the partner word')
assert(v.rows[4].label.text=='' and v.rows[4].value.text=='')
-- Paused or on a game screen: every group hidden; the kit off: nothing drawn.
H.draw(r,true)
assert(not kit.shown.race_panel and not kit.shown.race_results and not kit.shown.race_banner)
kit.shown={}
kit.is_off=true
assert(not H.shown())
H.draw(r,false)
assert(next(kit.shown)==nil)
kit.is_off=false
-- A session race keeps its results to the end of both: no results at our finish before then.
r={role='host',m={track=TRACK,phase='race',t_go=0,me={ms=30000,passed=4,flags=0},her={joined=true,passed=2},
    runner={next=1,lap=2,passed=4,done=true}}}
H.draw(r,false)
assert(kit.shown.race_panel and not kit.shown.race_results)
H.hide()
for _,g in ipairs(Hud.GROUPS) do assert(kit.shown[g]==false,g) end
-- Her ghost's feet from anchor() in a session race: the panel's POS against her.
local k2=fake_kit()
local H2=Hud.new({clock=function() return 0 end,name=function() return 'Her' end,
    anchor=function() return {X=3000,Y=0,Z=220},{X=3000,Y=0,Z=0} end})
H2.add({kit=k2,theme={beta='beta',text='text'},settings={}})
duo.m.phase,duo.m.t_go=duo.m.phase or 'race',0
H2.draw(duo,false)
assert(k2.groups.race_panel.view.line.text:find('  POS 2/2$'),k2.groups.race_panel.view.line.text)
print('race_hud_test ok')
