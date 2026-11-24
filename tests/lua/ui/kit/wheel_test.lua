-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- ui/kit/wheel.lua on a fake kit: the slot under a direction, the stick's sectors, the pages split, the game's piece
-- sizes and pivots at 80 %; the open (the input taken with no cursor, the mouse centred, the open sound), the stick and
-- the mouse pointing (past the dead zone, once moved), the highlight that stays, the release that plays once (or
-- nothing when nothing was pointed at), the input back 150 ms after, a click and A, Esc and B, the pages, a guard, the
-- window lost, the HUD hidden, the refusals and coop off.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
local Wheel=require('ui.kit.wheel')
local T=require('ui.text')

-- The pure parts.
assert(Wheel.slot(6,0)==1 and Wheel.slot(6,29.9)==1 and Wheel.slot(6,30)==2 and Wheel.slot(6,359)==1)
assert(Wheel.slot(6,330)==1 and Wheel.slot(6,329.9)==6 and Wheel.slot(3,179)==2 and Wheel.slot(3,299)==3 and Wheel.slot(3,300)==1)
assert(Wheel.slot(4,90)==2 and Wheel.slot(4,180)==3 and Wheel.slot(4,270)==4 and Wheel.slot(5,72)==2)
assert(Wheel.angle(0,-10)==0 and Wheel.angle(10,0)==90 and Wheel.angle(0,10)==180 and Wheel.angle(-10,0)==270)
assert(Wheel.sector_angle(1)==2.5 and Wheel.sector_angle(19)==92.5 and Wheel.sector_angle(72)==357.5)
local function sizes(pages) local s={} for i,p in ipairs(pages) do s[i]=#p.slots end return table.concat(s,' ') end
local function group(title,n) local g={title=title,slots={}} for i=1,n do g.slots[i]={id=title..i,label=title..i} end return g end
local split=Wheel.pages({group('A',5),group('Pose',11),group('B',13),group('C',6),group('D',2)})
assert(sizes(split)=='5 6 5 5 4 4 6 2',sizes(split))
assert(split[2].title=='Pose 1' and split[3].title=='Pose 2' and split[1].title=='A' and split[6].title=='B 3')
assert(split[3].slots[1].id=='Pose7' and split[3].slots[5].id=='Pose11')
-- The game's brushes (790x790, 980x791, 1582x791, 1420x710) at 80 %, their pivot on the ring's centre, the 3-slot
-- pieces' 80 units under them; turned 360/n a slot, names at radius 462.
for n,want in pairs({[6]={632,632,1},[5]={784,633,1},[4]={1266,633,1},[3]={1136,568,790/710}}) do
    for i=1,n do
        local p=Wheel.place(n,i)
        assert(p.w==want[1] and p.h==want[2] and p.pivot.X==0.5 and p.pivot.Y==want[3],n)
        assert(math.abs(p.x+p.w/2-1000)<1e-9 and math.abs(p.y+p.h*p.pivot.Y-820)<1e-9,'Its pivot on the centre')
        assert(math.abs(p.angle-(i-1)*360/n)<1e-9)
        assert(math.abs((p.lx-1000)^2+(p.ly-820)^2-462^2)<1e-6)
    end
end
assert(math.abs(Wheel.place(3,1).h*(790/710)-632)<1,'The 3-slot ring as wide as the others')

-- A fake kit: the group's widgets, its calls in order.
local calls,views,shown,sounds,inputs={},{},{},{},{}
local kit_off,kit_ready,kit_paused,kit_holding,mouse_at=false,true,false,false,{1920,1080}
local function widget()
    local w={on=true}
    w.show=function(on) w.on=on end
    w.set=function(s) w.s=s end
    w.color=function(c) w.c=c end
    w.turn=function(a) w.a=a end
    w.tint=function() end
    return w
end
local b={shade=function() end,image=function(_,_,_,_,tex) local w=widget(); w.tex=tex; return w end,
    text=function(_,_,s) local w=widget(); w.s=s; return w end}
local kit={add=function(name,place,build) views[name]=build(b); views[name].place=place end,
    view=function(name) return kit_ready and views[name] or nil end,
    show=function(name,on) shown[name]=on end,sound=function(s) sounds[#sounds+1]=s end,
    input=function(on,who,mouse) inputs[#inputs+1]=tostring(on)..' '..tostring(who)..' '..tostring(mouse) end,
    off=function() return kit_off end,ready=function() return kit_ready end,paused=function() return kit_paused end,
    holding=function() return kit_holding end,screen=function() return {w=3840,h=2160,s=0.5} end,
    pointer=function() return mouse_at[1],mouse_at[2] end,
    centre_pointer=function() calls[#calls+1]='centre'; mouse_at={1920,1080}; return true end,
    move=function(name,x,y) calls[#calls+1]=('move %s %g,%g'):format(name,x,y) end,warm_part=function() end,
    part=function() return nil,'part WB_Common_IndicatorBtnDefault_C: the UI is not up' end,alive=function() end,
    drop=function() end}
local stick,held,fkey=0,1,2
local reads={stick=function() return stick end,held=function() return held end,fkey=function() return fkey end}
local w=Wheel.new({kit=kit,theme={grey='grey',white='white',beta='beta',dim='dim',shade='shade'},
    words=function() return T.en end,reads=reads})
local v=views.wheel
assert(v.place.most==1.3 and v.place.pivot.X==0.5 and not v.place.hit)
local closes={}
local function spec(device)
    return {pages=Wheel.pages({group('Greeting',5),group('Pose',11),group('Cut',6)}),title='Social action',
        device=device,key=2,closed=function(why,id,page) closes[#closes+1]={why=why,id=id,page=page} end}
end
local function lit() for i,f in ipairs(v.sets[5].focus) do if f.on then return i end end end

-- The open: centred, shown, the input taken without the cursor, the mouse centred, SB's open sound.
assert(w.open(spec('key')))
assert(w.is_open() and shown.wheel and inputs[#inputs]=='true wheel false' and calls[1]=='move wheel 920,260'
    and calls[2]=='centre' and sounds[#sounds]=='wheel_open')
assert(v.sets[5].bg[1].on and not v.sets[6].bg[1].on and v.sets[5].bg[2].a==72 and v.name.s=='Social action')
assert(v.fkeys[2].on and not v.fkeys[3].on and v.labels[1].s=='Release: play','The F-key held, in the hints')
assert(v.tabs[2].s=='Greeting' and v.tabs[1].s=='Cut' and v.tabs[3].s=='Pose 1')
assert(w.open(spec('key'))==false,'Open once')
-- The stick's sector 19 (92.5 degrees): slot 2 of 5, lit once with the focus sound.
stick=19
w.tick(clock)
assert(lit()==2 and sounds[#sounds]=='wheel_move' and v.sets[5].names[2].c=='white' and v.name.s=='Greeting2')
local n=#sounds
w.tick(clock)
assert(#sounds==n,'No sound while it stays')
-- The stick back to rest: the highlight stays.
stick=0
w.tick(clock)
assert(lit()==2)
-- The mouse: under 60 units from the centre or unmoved points at nothing; moved past it, the slot under it.
mouse_at={1920+40,1080-20}
w.tick(clock)
assert(lit()==2,'Inside the dead zone')
mouse_at={1920-300,1080+20}
w.tick(clock)
assert(lit()==5,'Left and a little down: slot 5 of 5') -- 266 degrees: slot 5 (252 to 324).
w.tick(clock)
assert(lit()==5)
-- The release of the F-key plays the slot pointed at, once; the input comes back 150 ms later.
fkey=0
w.tick(clock)
assert(not w.is_open() and not shown.wheel and closes[1].id=='Greeting5' and closes[1].why=='release'
    and closes[1].page==1 and sounds[#sounds]=='select')
w.tick(clock+0.1)
assert(inputs[#inputs]=='true wheel false','Not yet')
w.tick(clock+0.15)
assert(inputs[#inputs]=='false wheel nil')
w.tick(clock+0.2)
assert(#closes==1)
-- Released with nothing pointed at: nothing plays.
fkey=2
assert(w.open(spec('key')))
fkey=0
w.tick(clock)
assert(closes[2].id==nil and closes[2].why=='released with nothing pointed at' and sounds[#sounds]=='back')
-- Another F-key held instead (a lower one): released too.
fkey=2
assert(w.open(spec('key')))
fkey=1
w.tick(clock)
assert(not w.is_open() and closes[3].id==nil)
-- The pad: D-pad Left's hold; LB and RB change the page and clear the highlight; A plays; B cancels.
held=1
assert(w.open(spec('pad')))
assert(not v.fkeys[2].on and v.labels[1].s=='Release: play','The pad: no F-key; its words while SB parts are not up')
stick=1
w.tick(clock)
assert(lit()==1)
assert(w.nav('tab_right') and sounds[#sounds]=='change' and v.page.s=='Pose 1' and v.sets[6].bg[1].on)
for _,f in ipairs(v.sets[6].focus) do assert(not f.on,'Cleared') end
assert(w.nav('select') and w.is_open(),'A with nothing pointed at')
w.tick(clock)
assert(v.sets[6].focus[1].on)
assert(w.nav('select') and not w.is_open() and closes[4].id=='Pose1' and closes[4].page==2 and closes[4].why=='select')
assert(w.nav('back')==false,'Closed: not taken')
assert(w.open(spec('pad')))
w.nav('tab_left')
assert(v.page.s=='Cut','Wraps')
w.nav('back')
assert(closes[5].why=='cancelled' and closes[5].id==nil)
held=0
assert(w.open(spec('pad')))
w.tick(clock)
assert(not w.is_open() and closes[6].why=='released with nothing pointed at','D-pad Left released')
-- A guard reason, the window lost (73, 2, 13), the HUD hidden, the game paused, coop ui reset: closed, nothing played.
held,fkey,stick=1,2,0
local s=spec('pad')
local guard=nil
s.guard=function() return guard end
assert(w.open(s))
guard='EVE is in the air'
w.tick(clock)
assert(closes[7].why=='EVE is in the air' and closes[7].id==nil)
for _,lost in ipairs({{'stick',73,'pad'},{'held',2,'pad'},{'fkey',13,'key'}}) do
    assert(w.open(spec(lost[3])))
    reads[lost[1]]=function() return lost[2] end
    w.tick(clock)
    assert(not w.is_open() and closes[#closes].why=='the game window is not in front',lost[1])
    reads[lost[1]]=({stick=function() return stick end,held=function() return held end,
        fkey=function() return fkey end})[lost[1]]
end
assert(w.open(spec('pad')))
w.slow(false)
assert(not w.is_open() and closes[#closes].why=='our HUD is hidden')
assert(w.open(spec('pad')))
kit_paused=true
w.slow(true)
assert(not w.is_open() and closes[#closes].why=='the game paused')
kit_paused=false
assert(w.open(spec('pad')))
w.close()
assert(not w.is_open() and closes[#closes].why=='closed')
-- Refusals: the UI off, not up, paused, another screen holding the input, an older DLL.
clock=clock+1
w.tick(clock)
kit_holding=true
local ok,word=w.open(spec('pad'))
assert(not ok and word=='world')
kit_holding,kit_paused=false,true
ok,word=w.open(spec('pad'))
assert(not ok and word=='world')
kit_paused,kit_ready=false,false
ok,word=w.open(spec('pad'))
assert(not ok and word=='world')
kit_ready,kit_off=true,true
ok,word=w.open(spec('pad'))
assert(not ok and word=='off')
kit_off=false
local old=Wheel.new({kit=kit,theme={},words=function() return T.en end})
ok,word=old.open(spec('pad'))
assert(not ok and word=='native')
-- coop off: closed, no call.
assert(w.open(spec('pad')))
local before=#closes
w.stop()
assert(not w.is_open() and #closes==before and not shown.wheel)
print('wheel_test ok')
