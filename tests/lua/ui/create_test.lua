-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Create a session screen (ui/create.lua) over a fake kit and fake SB parts, every call on a part recorded: it
-- opens on the values in effect, shows the rows, headers, right pane and hints, changes a value with Left, Right and
-- Select (rows coming and going with it), scrolls, starts or goes back, takes the mouse, shows a locked row's look and
-- reason, closes by itself, refuses to open, gives the input back, makes its parts again after a root build and draws
-- its kit fallback for a part the game cannot make, with its log lines. Over the whole test no part is focused or sent a
-- call outside the lobby's list. Every part is HitTestInvisible.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
FText=function(s) return {text=s} end
FName=function(s) return {name=s} end
local clock=0
os.clock=function() return clock end
local T=require('ui.text')
local Options=require('ui.model')
local Create=require('ui.create')

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
local OPTION,HEADER,HINT='WB_Setting_Button_Slot_C','WB_Setting_Category_C','WB_Common_IndicatorBtnDefault_C'
local function live(class,x)
    local t={}
    for _,p in ipairs(parts) do if p.alive and p.class==class and (x==nil or p.x==x) then t[#t+1]=p end end
    table.sort(t,function(a,b) return a.y<b.y or a.y==b.y and a.x>b.x end)
    return t
end
-- The list as drawn, top to bottom: '#HEADER' or 'Title=Value' ('*' when locked, '>' on the focused row).
local function list()
    local out={}
    for _,p in ipairs(parts) do
        if p.alive and p.x==192 and (p.class==OPTION or p.class==HEADER) then out[#out+1]=p end
    end
    table.sort(out,function(a,b) return a.y<b.y end)
    for i,p in ipairs(out) do
        if p.class==HEADER then out[i]='#'..p.props.Category_Name.text
        else
            local focus=false
            for _,c in ipairs(p.calls) do
                if c[1]=='EventNotification' and (c[2]=='StateFocus' or c[2]=='StateNormal') then focus=c[2]=='StateFocus' end
            end
            out[i]=(focus and '>' or '')..p.props.Text_TitleValue.text..'='..p.props.Text_ItemValue.text
                ..(p.props.bLockItem and '*' or '')
        end
    end
    return table.concat(out,' | ')
end
-- The live hints at the bottom, right to left: their labels and icons.
local function hint_line()
    local out={}
    for _,p in ipairs(live(HINT)) do out[#out+1]=p.calls[2][2].text..'/'..p.calls[3][2].name end
    return table.concat(out,' ')
end

-- The fake kit: groups built on their first view; texts, images and mouse zones recorded.
local kit,groups,shown,sounds,inputs,warmed={},{},{},{},{},{}
local fail_class,azerty=nil,false
local function builder(g)
    local b={}
    function b.text(x,y,str,style,color,align,o)
        local t={x=x,y=y,s=str or '',color=color,style=style,o=o}
        g.texts[#g.texts+1]=t
        return {set=function(s) t.s=s or '' end,color=function(c) t.color=c end}
    end
    function b.image() return {show=function() end} end
    function b.row(x,y,width)
        local z={x=x,y=y,w=width,hover=false,label='',value='',state='normal'}
        g.zones[#g.zones+1]=z
        return {set=function(l,v,st) z.label,z.value,z.state=l or '',v or '',st or 'normal' end,
            hovered=function() return z.hover end}
    end
    function b.shade() end
    return b
end
function kit.add(name,place,build) groups[name]={place=place,build=build,texts={},zones={}} end
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
    for _,t in ipairs(groups.create.texts) do if t.x==x and t.y==y then return t.s end end
end

-- The view main.lua gives (the settings in effect, whether coop-settings.txt reads, link.mode()); act as main.lua's:
-- a change goes into the values in effect, as menu.set applies it, or with refuse set is not saved, as menu.set says.
local input={values=Options.read(''),readable=true,role='none'}
local acts,logs={},{}
local refuse=nil
local function act(a)
    acts[#acts+1]=a
    if a.set and refuse then return false,'not saved: '..refuse,T.en.not_saved:format(refuse) end
    if a.set then input.values[a.set]=a.value end
end
local screen=Create.new({kit=kit,words=function() return T.en end,view=function() return input end,act=act,
    log=function(l) logs[#logs+1]=l end})
assert(#warmed==3 and warmed[1]=='/Game/Art/UI/Widget/GameMenu/Setting/Slot/WB_Setting_Button_Slot.WB_Setting_Button_Slot'
    and warmed[2]:find('WB_Setting_Category$') and warmed[3]:find('WB_Common_IndicatorBtnDefault$'),warmed[1])
assert(screen.is_open()==false and #parts==0)

-- Open: the input with the mouse cursor, the open sound, one line; the rows of the defaults, Who can join focused.
clock=100
assert(select(2,screen.open())=='Create a session opens in the game world only','No slow yet: no world known')
screen.slow(true)
inputs={} -- That slow gave the input back, as it does while closed.
local ok,message=screen.open()
assert(ok and message=='Create a session is open' and screen.is_open() and shown.create)
assert(inputs[1].on==true and inputs[1].who=='create' and inputs[1].mouse==true and sounds[1]=='open')
assert(logs[1]=='create: open' and text_at(3686,72)=='Create a session')
assert(list()=='#SESSION | >Who can join=Public | Friends join without asking=On | #SESSION RULES | '
    ..'Shared enemies (experimental)=On | Same place (experimental)=On | Same spawns (experimental)=On | '
    ..'Extra enemies (host\'s)=0 | Shared bosses (experimental)=On | Enemy HP (host\'s)=135 %',list())
local pane=live(HEADER,2600)
assert(#pane==1 and pane[1].y==384 and pane[1].props.Category_Name.text=='Who can join')
assert(text_at(2600,524)==T.en.create.who.public,text_at(2600,524))
assert(hint_line()=='Back/Negative Change/UI_DPad_Left',hint_line())
-- Right: the next value written (act), the change sound; Friends only takes Friends join without asking away.
sounds={}
screen.nav('right')
assert(acts[1].set=='who_can_join' and acts[1].value=='friends' and sounds[1]=='change')
assert(list():find('^#SESSION | >Who can join=Friends only | #SESSION RULES',1),list())
assert(text_at(2600,524)==T.en.create.who.friends)
-- Left twice: Public, then Private (wrapping back past Public's left); Invitation gives the row back.
screen.nav('left'); screen.nav('left')
assert(acts[3].value=='closed' and list():find('>Who can join=Private | #SESSION RULES',1,true))
screen.nav('left')
assert(acts[4].value=='invitation' and list():find('>Who can join=Invitation | Friends join without asking=On',1,true))
-- Select on a setting: its next value, as Right.
screen.nav('select')
assert(acts[5].value=='closed' and input.values.who_can_join=='closed' and #logs==1)
screen.nav('right')
assert(input.values.who_can_join=='public')
-- Down: Friends join without asking (On while friends_ask=off); Right turns it Off (friends_ask=on).
screen.nav('down')
assert(live(HEADER,2600)[1].props.Category_Name.text=='Friends join without asking' and text_at(2600,524)=='')
screen.nav('right')
assert(acts[7].set=='friends_ask' and acts[7].value=='on' and list():find('>Friends join without asking=Off',1,true))
-- Down past the header to Shared enemies; Off takes its seven sub-rows away.
sounds={}
screen.nav('down')
assert(sounds[1]=='move' and list():find('>Shared enemies (experimental)=On',1,true))
screen.nav('left')
assert(acts[8].set=='shared_enemies' and acts[8].value=='off')
assert(list()=='#SESSION | Who can join=Public | Friends join without asking=Off | #SESSION RULES | '
    ..'>Shared enemies (experimental)=Off | Shared world (experimental)=On | Shared quests (experimental)=On | '
    ..'Friend can revive me=On | Start= | Back=',list())
screen.nav('right')
assert(input.values.shared_enemies=='on')

-- The window: 17 rows, 10 shown; down to the end scrolls, Start and Back last; their hint is Select.
for _=1,11 do screen.nav('down') end
assert(list():find('| >Start= | Back=$'),list())
assert(list():find('^Extra enemies'),list())
assert(hint_line()=='Back/Negative Select/Positive',hint_line())
assert(live(HEADER,2600)[1].props.Category_Name.text=='Start')
-- Start: SB's select on the row, one line, closed, then hosting with Who can join's value shown.
local start=live(OPTION)[9]
sounds={}
screen.nav('select')
assert(has(start,'EventNotification','StateSelect') and logs[2]=='create: start public' and logs[3]=='create: closed')
assert(acts[#acts].host=='public' and not screen.is_open() and not shown.create and sounds[1]=='close')
-- The input back 150 ms later, from tick only.
inputs={}
screen.tick(clock+0.1)
assert(#inputs==0)
screen.tick(clock+0.2)
assert(inputs[1].on==false and inputs[1].who=='create')

-- Open again: on the values now in effect, the cursor on Who can join. Back (its row) closes it, hosting nothing.
clock=110
screen.open()
assert(list():find('>Who can join=Public | Friends join without asking=Off',1,true) and logs[4]=='create: open')
local n=#acts
screen.nav('up') -- Up from the first row wraps past the header to the last.
assert(list():find('| >Back=$'),list())
sounds={}
screen.nav('select')
assert(not screen.is_open() and #acts==n and sounds[1]=='back' and sounds[2]=='close' and logs[5]=='create: closed')
-- Esc or B: the same.
screen.open(); sounds={}
screen.nav('back')
assert(not screen.is_open() and #acts==n and sounds[1]=='back')

-- The mouse: a resting mouse takes nothing; a move onto a row takes the cursor; a click there changes it, a click on a
-- header does nothing.
clock=120
screen.open()
local zones=groups.create.zones
zones[5].hover=true
screen.tick(200)
assert(list():find('>Who can join',1,true),'The first look: a resting mouse')
zones[5].hover,zones[3].hover=false,true
screen.tick(200.2)
assert(list():find('>Friends join without asking',1,true),'Moved onto row 3')
zones[3].hover,zones[5].hover=false,true
screen.nav('click')
assert(acts[#acts].set=='shared_enemies' and acts[#acts].value=='off' and #acts==n+1)
zones[5].hover,zones[4].hover=false,true
screen.nav('click')
zones[4].hover=false
assert(#acts==n+1,'A click on a header: nothing')
screen.nav('select')
assert(input.values.shared_enemies=='on')

-- coop-settings.txt cannot be read: every setting in SB's locked look (bLockItem before the canvas, then
-- RefreshAppearance), its reason on the right, Back the only hint; Left, Right and Select change nothing. Start runs.
input.readable=false
screen.slow(true)
local locked=live(OPTION)[1]
assert(locked.props.bLockItem==true and has(locked,'EventNotification','RefreshAppearance'))
assert(list():find('Shared enemies (experimental)=On*',1,true),list())
n=#acts
screen.nav('up') -- From Shared enemies over the header: Friends join without asking.
assert(list():find('>Friends join without asking=Off*',1,true) and text_at(2600,524)==T.en.create.locked,list())
assert(hint_line()=='Back/Negative',hint_line())
screen.nav('right'); screen.nav('left'); screen.nav('select')
assert(#acts==n and screen.is_open())
screen.nav('up'); screen.nav('up'); screen.nav('up') -- Who can join, Back, Start.
screen.nav('select')
assert(acts[#acts].host=='public' and not screen.is_open())
input.readable=true

-- The mouse moved onto the 10th row (Enemy HP) and resting there: the list keeps still under it, one move sound; a
-- click 0.7 s later changes Enemy HP and the list still keeps still. Keys that scroll the list under the resting mouse
-- keep the cursor.
clock=125
screen.open()
sounds={}
zones[9].hover=true
screen.tick(300)
zones[9].hover,zones[10].hover=false,true
for k=1,7 do screen.tick(300+0.1*k) end
local window=list()
local function ends(text,tail) return text:sub(-#tail)==tail end
assert(window:find('#SESSION |',1,true)==1 and ends(window,'| >Enemy HP (host\'s)=135 %'),window)
assert(#sounds==1 and sounds[1]=='move',#sounds)
n=#acts
screen.nav('click')
assert(acts[n+1].set=='enemy_hp_scale' and ends(list(),'| >Enemy HP (host\'s)=140 %'),list())
screen.nav('left')
assert(ends(list(),'| >Enemy HP (host\'s)=135 %'),list())
screen.nav('down') -- Boss HP; the list scrolls by two: Enemies attack under the mouse.
screen.tick(302)
assert(list():find('| >Boss HP (host\'s)=200 % | Enemies attack (host\'s)=',1,true),list())
zones[10].hover=false
screen.close()

-- A change that is not saved (coop-settings.txt cannot be written): no change sound, the value as it was, why on the
-- right until the next key.
screen.open()
refuse='cannot write coop-settings.txt.tmp'
sounds={}
screen.nav('down'); screen.nav('down') -- Shared enemies.
screen.nav('right')
refuse=nil
assert(acts[#acts].set=='shared_enemies' and table.concat(sounds,' ')=='move move',table.concat(sounds,' '))
assert(list():find('>Shared enemies (experimental)=On',1,true) and text_at(2600,524)=='Not saved: cannot write '
    ..'coop-settings.txt.tmp',text_at(2600,524))
screen.nav('up')
assert(text_at(2600,524)=='')
screen.close()

-- It closes by itself: no world, the game paused, in a lobby, the kit off.
for _,case in ipairs({'world','paused','lobby','off'}) do
    clock=clock+10
    screen.slow(true)
    assert(screen.open())
    if case=='world' then screen.slow(false)
    elseif case=='paused' then paused=true; screen.slow(true); paused=false
    elseif case=='lobby' then input.role='host'; screen.slow(true); input.role='none'
    else off=true; screen.nav('down'); off=false end
    assert(not screen.is_open(),case)
end
-- Open refused: the kit off or not up, the game paused, in a lobby (coop host then asks the native part).
off=true
assert(select(2,screen.open())=='Create a session is off: the UI stopped (see the log)')
off,ready=false,false
assert(select(2,screen.open())=='Create a session opens in the game world only')
ready=true
screen.slow(false)
assert(select(2,screen.open())=='Create a session opens in the game world only','Outside a world: the title')
screen.slow(true)
paused=true
assert(select(2,screen.open())=='Create a session does not open while the game is paused or shows a menu')
paused,input.role=false,'guest'
assert(select(2,screen.open())=='Create a session opens outside a lobby only' and not screen.is_open())
input.role='none'

-- A root build (a map change): the parts are gone; the next draw makes them again.
screen.open()
for _,p in ipairs(parts) do p.alive=false end
screen.slow(true)
assert(#live(OPTION)==8 and #live(HEADER)==3 and #live(HINT)==2,#live(OPTION))
screen.close()

-- Over the whole test so far: nothing refused or left out; no focus, no call outside the lobby's list (option rows
-- StateNormal, StateFocus, StateSelect, RefreshAppearance; hints SetText, SetResourceAction, SetResourceAction2,
-- SetButtonClickable); every part HitTestInvisible.
local CALLS={[OPTION]={EventNotification=1},[HEADER]={},[HINT]={SetText=1,SetResourceAction=1,SetResourceAction2=1,
    SetButtonClickable=1}}
local EVENTS={StateNormal=1,StateFocus=1,StateSelect=1,RefreshAppearance=1}
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

-- A class left out logs once and its kit fallback draws: rows on the kit rows (a locked one disabled), the headers and
-- hints as kit texts with the keys' names.
local logs2={}
fail_class=OPTION
local s2=Create.new({kit=kit,words=function() return T.en end,view=function() return input end,act=act,
    log=function(l) logs2[#logs2+1]=l end})
zones=groups.create.zones
s2.slow(true); s2.open()
assert(logs2[2]=='create: part '..OPTION..': not in this game build; left out until the mod reloads',logs2[2])
assert(zones[2].label=='Who can join' and zones[2].value=='Public' and zones[2].state=='focus')
assert(zones[3].label=='Friends join without asking' and zones[3].state=='normal' and zones[1].label=='')
n=#logs2
s2.nav('down')
assert(#logs2==n and zones[3].state=='focus','Left out: logged once')
input.readable=false
s2.slow(true)
assert(zones[3].state=='disabled' and zones[2].state=='disabled')
input.readable=true
s2.close()
fail_class=HEADER
local s3=Create.new({kit=kit,words=function() return T.en end,view=function() return input end,act=act})
zones=groups.create.zones
s3.slow(true); s3.open()
assert(zones[1].label=='SESSION' and zones[1].state=='disabled' and zones[4].label=='SESSION RULES')
assert(text_at(2600,384)=='Who can join','The pane header\'s fallback')
s3.close()
fail_class=HINT
local s4=Create.new({kit=kit,words=function() return T.en end,view=function() return input end,act=act})
s4.slow(true); s4.open()
assert(text_at(3280,2010)=='Esc  Back' and text_at(2860,2010)=='A D  Change',text_at(2860,2010))
azerty=true
s4.slow(true)
assert(text_at(2860,2010)=='Q D  Change')
s4.close()
fail_class,azerty=nil,false
-- A part call refused: logged once a kind; with every part made, the fallbacks are empty.
local logs5={}
local s5=Create.new({kit=kit,words=function() return T.en end,view=function() return input end,act=act,
    log=function(l) logs5[#logs5+1]=l end})
zones=groups.create.zones
breaks.EventNotification='EventNotification is not a function'
s5.slow(true); s5.open(); s5.nav('down'); s5.nav('down')
breaks.EventNotification=nil
assert(#logs5==2 and logs5[2]=='create: option look refused: EventNotification is not a function',logs5[2])
assert(text_at(3280,2010)=='' and text_at(2600,384)=='' and zones[2].label=='' and zones[1].label=='')
s5.close()
print('create_test ok')
