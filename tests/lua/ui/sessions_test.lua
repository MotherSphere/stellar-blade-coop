-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Sessions screen (ui/sessions.lua) over a fake kit and fake SB parts, every call on a part recorded: it opens and
-- asks for a search, shows the search, the rows, the details and the hints, Refresh and its stop, the 5 s gap, the
-- tabs, the cursor and its scroll window, Select asking to join, the mouse, the closes by itself, the input given back,
-- parts made again after a root build, the kit fallback of each part and the log lines. Over the whole test no part is
-- focused or sent a call outside the lobby's list. Every part is HitTestInvisible.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
FText=function(s) return {text=s} end
FName=function(s) return {name=s} end
local clock=0
os.clock=function() return clock end
local T=require('ui.text')
local Sessions=require('ui.sessions')

-- Fake SB parts: every method call and property write recorded in order.
local parts={}
local breaks={} -- Method name -> the error it raises.
local function new_part(class)
    local p={class=class:match('[^.]+$'),calls={},props={},alive=true}
    function p.note(...) p.calls[#p.calls+1]=table.pack(...) end
    p.o=setmetatable({},{__index=function(_,k)
        if breaks[k] then return function() error(breaks[k],0) end end
        return function(_,...) p.note(k,...) end
    end,__newindex=function(_,k,v) p.props[k]=v; p.note('='..k,v) end})
    parts[#parts+1]=p
    return p
end
local function has(p,name,arg)
    for _,c in ipairs(p.calls) do if c[1]==name and (arg==nil or c[2]==arg) then return true end end
    return false
end
local function count_of(p,name,arg)
    local n=0
    for _,c in ipairs(p.calls) do if c[1]==name and (arg==nil or c[2]==arg) then n=n+1 end end
    return n
end
local OPTION,HEADER,HINT='WB_Setting_Button_Slot_C','WB_Setting_Category_C','WB_Common_IndicatorBtnDefault_C'
local function live(class,x)
    local t={}
    for _,p in ipairs(parts) do if p.alive and p.class==class and (x==nil or p.x==x) then t[#t+1]=p end end
    table.sort(t,function(a,b) return a.y<b.y or a.y==b.y and a.x>b.x end)
    return t
end
-- The live hints at the bottom, right to left: their labels and icons.
local function hint_line()
    local out={}
    for _,p in ipairs(live(HINT)) do
        if p.y==1990 then out[#out+1]=p.calls[2][2].text..'/'..p.calls[3][2].name end
    end
    return table.concat(out,' ')
end

-- The fake kit: groups built on their first view; texts, images and mouse zones recorded.
local kit,groups,shown,sounds,inputs,warmed={},{},{},{},{},{}
local fail_class,azerty=nil,false
local function builder(g)
    local b={}
    function b.text(x,y,str,style,color,align,o)
        local t={x=x,y=y,s=str or '',color=color,shown=true,style=style,o=o}
        g.texts[#g.texts+1]=t
        return {set=function(s) t.s=s or '' end,color=function(c) t.color=c end,show=function(on) t.shown=on end}
    end
    function b.image(x,y,w,h,tex,tint)
        local i={x=x,y=y,tex=tex,tint=tint,shown=true}
        g.images[#g.images+1]=i
        return {show=function(on) i.shown=on end,tint=function(c) i.tint=c end}
    end
    function b.row(x,y,width)
        local z={x=x,y=y,w=width,hover=false,label='',value='',state='normal'}
        g.zones[#g.zones+1]=z
        return {set=function(l,v,st) z.label,z.value,z.state=l or '',v or '',st or 'normal' end,
            hovered=function() return z.hover end}
    end
    function b.shade() g.shade=true end
    return b
end
function kit.add(name,place,build) groups[name]={place=place,build=build,texts={},images={},zones={}} end
function kit.view(name)
    local g=groups[name]
    if not g.view then g.view=g.build(builder(g)) or {} end
    return g.view
end
function kit.show(name,on) shown[name]=on==true end
local ready,off,paused=true,false,false
function kit.ready() return ready end
function kit.off() return off end
function kit.paused() return paused end
function kit.input(on,who,mouse) inputs[#inputs+1]={on=on,who=who,mouse=mouse} end
function kit.sound(name) sounds[#sounds+1]=name end
function kit.warm_part(p) warmed[#warmed+1]=p end
function kit.azerty() return azerty end
function kit.part(group,class,x,y,w,h,fill,hit)
    local short=class:match('[^.]+$')
    if short==fail_class then return nil,'part '..short..': not in this game build' end
    local p=new_part(class)
    p.group,p.x,p.y,p.w,p.h,p.hit=group,x,y,w,h,hit
    if not hit then p.o:SetVisibility(3) end
    if fill then fill(p.o) end
    p.note('AddChild')
    return {p=p}
end
function kit.alive(rec) return rec and rec.p.alive and rec.p.o or nil end
function kit.drop(rec)
    if rec and rec.p.alive then rec.p.alive=false; rec.p.note('RemoveFromParent') end
end
local function text_at(x,y)
    for _,t in ipairs(groups.sessions.texts) do if t.x==x and t.y==y then return t.s end end
end

-- The view main.lua gives (link.list(), link.match(), link.mode(), our protocol and build) and SB's words.
local input={rows={},role='none',proto='21',build='26123051'}
local SB={UI_Night_SearchPartner='Searching for team members',UI_Friends='Comrades',UI_RegionAlias_E04='Xion',
    UI_CampAlias_Xion_Camp_01='Camp of the Xion gate',UI_Cancel='Cancel search'}
local reads={}
local acts,logs={},{}
local screen=Sessions.new({kit=kit,words=function() return T.en end,view=function() return input end,
    act=function(a) acts[#acts+1]=a.request end,log=function(l) logs[#logs+1]=l end,
    game_text=function(key) reads[key]=(reads[key] or 0)+1; return SB[key] end})
assert(#warmed==3 and warmed[1]=='/Game/Art/UI/Widget/GameMenu/Setting/Slot/WB_Setting_Button_Slot.WB_Setting_Button_Slot'
    and warmed[3]:find('WB_Common_IndicatorBtnDefault$'),warmed[1])
assert(screen.is_open()==false and #parts==0)

-- Open: the input with the mouse cursor, the open sound, a search of the Public tab asked at once.
clock=100
assert(screen.open()==true and screen.is_open())
assert(inputs[1].on==true and inputs[1].who=='sessions' and inputs[1].mouse==true and sounds[1]=='open')
assert(shown.sessions and acts[1]=='list public' and logs[1]=='sessions: open public',logs[1])
-- Tabs: Public in front, Friends in SB's word; the shoulder icons; the list's header names the tab.
assert(text_at(236,120)=='Public' and text_at(596,120)=='Comrades' and text_at(3686,72)=='Find a session')
local icons=live(HINT)
assert(icons[1].y==120 and icons[2].y==120)
local heads=live(HEADER,192)
assert(#heads==1 and heads[1].y==384 and heads[1].props.Category_Name.text=='Public')
-- No list line yet: under 5 s since the ask, the wait; the hints Back and Refresh only.
assert(text_at(228,1574)=='You can search again in 5 s.',text_at(228,1574))
assert(hint_line()=='Back/Negative Refresh/UI_FaceButton_Top',hint_line())
assert(#live(OPTION)==0 and text_at(2600,524)=='')

-- Searching: SB's word; Refresh stops it (its hint SB's Cancel), with no new ask time.
input.search={tab='public',state='searching',rows=0}
screen.slow(true)
assert(text_at(228,1574)=='Searching for team members')
assert(hint_line()=='Back/Negative Cancel search/UI_FaceButton_Top',hint_line())
sounds={}
screen.nav('refresh')
assert(acts[2]=='list stop' and sounds[1]=='change')

-- Done: the rows as the native part gave them, the first focused, its details; Select's hint on.
local ROWS={}
for i=1,12 do
    ROWS[i]={lobby=tostring(109775241234567890+i),owner='7656119800000000'..(i%10),players='1/2',ping=40+i,pal=i==2,
        zone=i==1 and 'e04' or 'f01',camp=i==1 and 'Xion_Camp_01' or nil,rules=i==1 and 'ebwqr200' or 'x',
        name='Host'..i}
end
ROWS[3].ping=nil -- Steam could not estimate it.
input.search,input.rows={tab='public',state='done',rows=3},{ROWS[1],ROWS[2],ROWS[3]}
screen.slow(true)
local opts=live(OPTION)
assert(#opts==3 and opts[1].x==192 and opts[1].y==514 and opts[2].y==644 and opts[3].y==774)
assert(opts[1].props.Text_TitleValue.text=='Host1' and opts[1].props.Text_ItemValue.text=='Xion · 1/2 · 41 ms')
assert(opts[2].props.Text_ItemValue.text=='f01 · 1/2 · 42 ms','A zone with no key: its word as written')
assert(opts[3].props.Text_ItemValue.text=='f01 · 1/2 · -','No ping known: -')
assert(count_of(opts[1],'EventNotification','StateFocus')==1 and not has(opts[2],'EventNotification','StateFocus'))
assert(text_at(228,1574)=='','Rows show: no status')
local pane=live(HEADER,2600)
assert(#pane==1 and pane[1].props.Category_Name.text=='Host1')
assert(text_at(2600,524)=='Xion' and text_at(2600,594)=='Camp of the Xion gate' and text_at(2600,664)=='1/2 · 41 ms')
assert(text_at(2600,734)=='Shared enemies (experimental) · Shared bosses (experimental) · Shared world (experimental)'
    ..' · Shared quests (experimental) · Friend can revive me · Boss HP (host\'s) 200 %',text_at(2600,734))
assert(text_at(2656,944)=='' and text_at(2600,1014)=='Protocol 21, game build 26123051')
assert(text_at(192,2000)=='Your version: protocol 21, game build 26123051. Sessions of other versions are not listed.')
assert(hint_line()=='Back/Negative Refresh/UI_FaceButton_Top Ask to join/Positive',hint_line())
-- SB's words read once a key while open.
assert(reads.UI_RegionAlias_E04==1 and reads.UI_Friends==1,reads.UI_Friends)
-- Down: the second row focused, its details: no camp, a rules word of another shape shows none, the friend mark.
sounds={}
screen.nav('down')
assert(count_of(opts[1],'EventNotification','StateNormal')==1 and count_of(opts[2],'EventNotification','StateFocus')==1)
assert(sounds[1]=='move' and live(HEADER,2600)[1].props.Category_Name.text=='Host2')
assert(text_at(2600,594)=='' and text_at(2600,734)=='' and text_at(2656,944)=='Steam friend')
screen.nav('down'); assert(text_at(2600,664)=='1/2 · -','The third row: no ping known'); screen.nav('up')
-- Refresh within 5 s of the last ask: nothing asked; after it, list public again.
clock=104
screen.nav('refresh')
assert(#acts==2)
clock=105.5
screen.nav('refresh')
assert(acts[3]=='list public')
-- Select: SB's select on the row, the join asked, the screen closed; one line each.
screen.nav('select')
assert(count_of(opts[2],'EventNotification','StateSelect')==1 and acts[4]=='join '..ROWS[2].lobby)
assert(not screen.is_open() and not shown.sessions and sounds[#sounds]=='close')
assert(logs[2]=='sessions: ask to join lobby '..ROWS[2].lobby and logs[3]=='sessions: closed',logs[2])
-- The input back 150 ms later, from tick only; slow asks again while it is due no more.
inputs={}
screen.tick(clock+0.1)
assert(#inputs==0)
screen.tick(clock+0.2)
assert(inputs[1].on==false and inputs[1].who=='sessions')

-- Open again under 5 s after the last ask: no search, the last list shows; the cursor on the first row.
clock=108
screen.open()
assert(#acts==4 and logs[4]=='sessions: open public' and count_of(opts[1],'EventNotification','StateFocus')==2)
-- The Friends tab (E, RB): SB's word on its header; the 5 s are not over, so the wait shows and no rows.
sounds={}
screen.nav('tab_right')
assert(sounds[1]=='change' and #acts==4 and live(HEADER,192)[1].props.Category_Name.text=='Comrades')
assert(#live(OPTION)==0 and text_at(228,1574)=='You can search again in 3 s.')
-- Over 5 s: back to Public (a click on its tab) asks for its search; the other tab's rows never show.
clock=111
groups.sessions.zones[1].hover=true
screen.nav('click')
groups.sessions.zones[1].hover=false
assert(acts[5]=='list public' and live(HEADER,192)[1].props.Category_Name.text=='Public')

-- The window: 12 rows, 8 shown; the cursor down to the 9th scrolls by one.
input.search,input.rows={tab='public',state='done',rows=12},ROWS
screen.slow(true)
opts=live(OPTION)
assert(#opts==8 and opts[8].props.Text_TitleValue.text=='Host8' and opts[8].y==514+7*130)
for _=1,8 do screen.nav('down') end -- The 9th: one row stays in view under it, as on the lobby's settings.
opts=live(OPTION)
assert(#opts==8 and opts[1].props.Text_TitleValue.text=='Host3' and opts[8].props.Text_TitleValue.text=='Host10')
assert(has(opts[7],'EventNotification','StateFocus') and not has(opts[8],'EventNotification','StateFocus'))
for _=1,4 do screen.nav('down') end -- The 12th, then the 1st again.
opts=live(OPTION)
assert(opts[1].props.Text_TitleValue.text=='Host1' and has(opts[1],'EventNotification','StateFocus'))

-- The mouse: a resting mouse takes nothing; a move onto row 3 takes the cursor; a click there asks to join it.
local zones=groups.sessions.zones -- Tabs 1 and 2, then the rows' 8.
zones[5].hover=true
screen.tick(200)
assert(not has(live(OPTION)[3],'EventNotification','StateFocus'),'The first look: a resting mouse')
zones[5].hover,zones[4].hover=false,true
screen.tick(200.2)
assert(has(live(OPTION)[2],'EventNotification','StateFocus'),'Moved onto row 2')
zones[4].hover,zones[5].hover=false,true
screen.nav('click')
zones[5].hover=false
assert(acts[6]=='join '..ROWS[3].lobby and not screen.is_open())

-- It closes by itself: no world, the game paused, in a lobby, the kit off.
for _,case in ipairs({{'world'},{'paused'},{'lobby'},{'off'}}) do
    clock=clock+10
    screen.open()
    if case[1]=='world' then screen.slow(false)
    elseif case[1]=='paused' then paused=true; screen.slow(true); paused=false
    elseif case[1]=='lobby' then input.role='guest'; screen.slow(true); input.role='none'
    else off=true; screen.nav('down'); off=false end
    assert(not screen.is_open(),case[1])
end
-- Open refused: the kit off, or not up.
off=true
assert(select(2,screen.open())=='Find a session is off: the UI stopped (see the log)')
off,ready=false,false
assert(select(2,screen.open())=='Find a session opens in the game world only' and not screen.is_open())
ready=true
-- Back closes it with the back and close sounds.
screen.open()
sounds={}
screen.nav('back')
assert(not screen.is_open() and sounds[1]=='back' and sounds[2]=='close')

-- A root build (a map change): the parts are gone; the next draw makes them again.
screen.open()
for _,p in ipairs(parts) do p.alive=false end
screen.slow(true)
assert(#live(OPTION)==8 and #live(HINT)==5 and #live(HEADER)==2)
screen.close()

-- Over the whole test so far: nothing refused or left out; no focus, no call outside the lobby's list (option rows
-- StateNormal, StateFocus, StateSelect; hints SetText, SetResourceAction, SetResourceAction2, SetButtonClickable);
-- every part HitTestInvisible.
local CALLS={[OPTION]={EventNotification=1},[HEADER]={},[HINT]={SetText=1,SetResourceAction=1,SetResourceAction2=1,
    SetButtonClickable=1}}
local EVENTS={StateNormal=1,StateFocus=1,StateSelect=1}
for _,p in ipairs(parts) do
    assert(p.calls[1][1]=='SetVisibility' and p.calls[1][2]==3,p.class)
    for _,c in ipairs(p.calls) do
        local name=c[1]
        if name~='SetVisibility' and name~='AddChild' and name~='RemoveFromParent' and name:sub(1,1)~='=' then
            assert(CALLS[p.class][name],p.class..' got '..name)
        end
        if name=='EventNotification' then assert(EVENTS[c[2]],p.class..' got '..tostring(c[2])) end
        if name=='SetButtonClickable' then assert(c[2]==false) end
    end
end
for _,l in ipairs(logs) do assert(not l:find('refused') and not l:find('left out'),l) end

-- A refused call logs once a kind; a class left out logs once and its kit fallback draws: rows on the kit rows, the
-- headers and hints as kit texts with the keys' names, the tab keys' names.
local logs2={}
fail_class=OPTION
local s2=Sessions.new({kit=kit,words=function() return T.en end,view=function() return input end,
    act=function() end,log=function(l) logs2[#logs2+1]=l end})
zones=groups.sessions.zones
clock=clock+10
s2.open()
assert(logs2[2]=='sessions: part '..OPTION..': not in this game build; left out until the mod reloads',logs2[2])
assert(zones[3].label=='Host1' and zones[3].value=='e04 · 1/2 · 41 ms' and zones[3].state=='focus')
assert(zones[4].label=='Host2' and zones[4].state=='normal' and text_at(2600,524)=='e04','No SB word: as written')
local n=#logs2
s2.nav('down'); s2.nav('down')
assert(#logs2==n and zones[5].state=='focus','Left out: logged once')
s2.close()
fail_class=HEADER
local s3=Sessions.new({kit=kit,words=function() return T.en end,view=function() return input end,act=function() end})
s3.open()
assert(text_at(192,384)=='Friends only' or text_at(192,384)=='Public',text_at(192,384))
assert(text_at(2600,384)=='Host1','The pane header\'s fallback')
s3.close()
fail_class=HINT
azerty=true
local s4=Sessions.new({kit=kit,words=function() return T.en end,view=function() return input end,act=function() end})
s4.open()
assert(text_at(86,120)=='A' and text_at(956,120)=='E')
assert(text_at(3280,2010)=='Esc  Back' and text_at(2860,2010)=='F  Refresh' and text_at(2440,2010)=='Enter  Ask to join')
s4.close()
fail_class,azerty=nil,false
-- A part call refused: logged once a kind; with every part made, the fallbacks are empty.
local logs5={}
local s5=Sessions.new({kit=kit,words=function() return T.en end,view=function() return input end,act=function() end,
    log=function(l) logs5[#logs5+1]=l end})
zones=groups.sessions.zones
breaks.EventNotification='EventNotification is not a function'
s5.open(); s5.nav('down'); s5.nav('down')
breaks.EventNotification=nil
assert(#logs5==2 and logs5[2]=='sessions: option look refused: EventNotification is not a function',logs5[2])
assert(text_at(86,120)=='' and text_at(3280,2010)=='' and text_at(2600,384)=='' and text_at(192,384)=='')
assert(zones[3].label=='' and zones[4].label=='')
s5.close()
print('sessions_test ok')
