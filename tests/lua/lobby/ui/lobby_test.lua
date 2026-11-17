-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The lobby screens (lobby/ui/lobby.lua) over a fake kit and fake SB parts, every call on a part recorded: B's layout,
-- rows, hints, labels and focus looks, its status and members box, the mouse over its rows; C's tabs, focus looks and
-- the shapes it hands to act; the leave question; the countdown; the room overlay; parts made again after a root build;
-- the parts check; the two log lines a refused call or a class left out writes. Over the whole test no part is ever focused, clicked through or sent a call outside L4 2's list,
-- and every part but the popup is HitTestInvisible.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
FText=function(s) return {text=s} end
FName=function(s) return {name=s} end
local clock=0
os.clock=function() return clock end
local played={}
local statics={type=function() return 'UObject' end,IsValid=function() return true end,
    PlaySound2D=function(_,...) played[#played+1]=table.pack(...) end}
StaticFindObject=function(path)
    assert(path=='/Script/Engine.Default__GameplayStatics','unexpected StaticFindObject '..path)
    return statics
end
local T=require('ui.text')
local Lobby=require('lobby.ui.lobby')

-- Layout (design-lobby 4.3, my call 12).
local L=Lobby.layout(2,6)
assert(L.top==1002 and L.rows[1]==1002 and L.rows[2]==1108 and L.text_y==1234 and L.rows[3]==1364 and L.rows[8]==1894)
assert(L.logo_y==375 and L.rows[8]+106==2000)
L=Lobby.layout(2,4)
assert(L.top==1214 and L.logo_y==587)
L=Lobby.layout(2,6)

-- Fake SB parts: every method call and property write recorded in order, with AddChild and RemoveFromParent from the
-- fake kit.
local parts={}
local buttons={positive=false,negative=false}
local breaks={} -- Method name -> the error it raises, as UE4SS does on a name the class lacks.
local function new_part(class)
    local p={class=class:match('[^.]+$'),calls={},props={},alive=true}
    function p.note(...) p.calls[#p.calls+1]=table.pack(...) end
    local fields={Accept='anim Accept',close='anim close',PopupAcceptSound='sound accept',
        PopupCloseSound='sound close',Button_Positive={IsHovered=function() return buttons.positive end},
        Button_Negative={IsHovered=function() return buttons.negative end}}
    p.o=setmetatable({},{__index=function(_,k)
        if fields[k]~=nil then return fields[k] end
        if breaks[k] then return function() error(breaks[k],0) end end
        return function(_,...) p.note(k,...) end
    end,__newindex=function(_,k,v) p.props[k]=v; p.note('='..k,v) end})
    parts[#parts+1]=p
    return p
end
local function names(p) local t={} for i,c in ipairs(p.calls) do t[i]=c[1] end return table.concat(t,' ') end
local function has(p,name,arg)
    for _,c in ipairs(p.calls) do if c[1]==name and (arg==nil or c[2]==arg) then return true end end
    return false
end
local function count_of(p,name,arg)
    local n=0
    for _,c in ipairs(p.calls) do if c[1]==name and (arg==nil or c[2]==arg) then n=n+1 end end
    return n
end
local ROW,OPTION,HEADER,HINT='WB_Lobby_Menu_Slot_C','WB_Setting_Button_Slot_C','WB_Setting_Category_C',
    'WB_Common_IndicatorBtnDefault_C'
local POPUP,COUNT='WB_Common_Popup_C','WB_MainHUD_CountDown_C'
-- The live parts of a class, in the order made.
local function live(class)
    local t={}
    for _,p in ipairs(parts) do if p.alive and p.class==class then t[#t+1]=p end end
    return t
end
-- C's list: the live parts of a class at x 192, top to bottom.
local function in_list(class)
    local t={}
    for _,p in ipairs(live(class)) do if p.group=='lobby_settings' and p.x==192 then t[#t+1]=p end end
    table.sort(t,function(a,b) return a.y<b.y end)
    return t
end
local function in_group(class,group)
    local n=0
    for _,p in ipairs(live(class)) do if p.group==group then n=n+1 end end
    return n
end
-- The names of a part's calls from now on.
local function since(p)
    local n=#p.calls
    return function()
        local t={}
        for i=n+1,#p.calls do t[#t+1]=p.calls[i][1] end
        return table.concat(t,' ')
    end
end

-- The fake kit: groups built on their first view, texts, images and mouse zones (b.row) recorded.
local kit,groups,shown,sounds,inputs,warmed,moved={},{},{},{},{},{},{}
local refocused,fail_class,fail_why=0,nil,nil
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
        return {show=function(on) i.shown=on end,tint=function(c) i.tint=c end,turn=function() end,
            texture=function() return true end}
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
function kit.ready() return true end
function kit.off() return false end
function kit.input(on,who,mouse) inputs[#inputs+1]={on=on,who=who,mouse=mouse} end
function kit.sound(name) sounds[#sounds+1]=name end
function kit.refocus() refocused=refocused+1 end
function kit.warm_part(p) warmed[#warmed+1]=p end
function kit.move(name,x,y) moved[name]={x=x,y=y} end
function kit.language() return 'en-US' end
function kit.part(group,class,x,y,w,h,fill,hit)
    local short=class:match('[^.]+$')
    if short==fail_class then return nil,'part '..short..': '..(fail_why or 'not in this game build') end
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
local function text_at(group,x,y)
    for _,t in ipairs(groups[group].texts) do if t.x==x and t.y==y then return t end end
end
local function texts(group)
    local out={}
    for _,t in ipairs(groups[group].texts) do if t.shown and t.s~='' then out[#out+1]=t.s end end
    return table.concat(out,'|')
end

local me={id='76561198000000002',name='Eve'}
local input={role='none',me=me,now=0,settings={menu_key={name='F5'}}}
local acts,logs={},{}
-- The lines that say what the screens did (B or C opened, closed, the question and its answer, C's Back) go to states,
-- in order; logs keeps the rest (refusals, parts left out, the parts check).
local STATES={['lobby: open menu']=1,['lobby: open settings']=1,['lobby: closed']=1,['lobby: settings back']=1,
    ['lobby: popup leave open']=1,['lobby: popup leave yes']=1,['lobby: popup leave no']=1}
local states={}
local function logger(list)
    return function(line) if STATES[line] then states[#states+1]=line else list[#list+1]=line end end
end
-- The state lines since the n-th.
local function states_since(n) return table.concat(states,'|',n+1) end
local lobby=Lobby.new({kit=kit,words=function() return T.en end,view=function() return input end,
    act=function(a) acts[#acts+1]=a end,log=logger(logs)})
-- The six classes warmed ahead, by object path.
assert(#warmed==6 and warmed[1]=='/Game/Art/UI/Widget/Lobby/WB_Lobby_Menu_Slot.WB_Lobby_Menu_Slot',warmed[1])
assert(warmed[6]=='/Game/Art/UI/Widget/HUD/WB_MainHUD_CountDown.WB_MainHUD_CountDown',warmed[6])
assert(lobby.is_open()==nil and #parts==0)

-- B opens (idle): 8 rows at x 172 on the layout, three hints right to left from x 3700, 420 apart, at y 1990.
assert(lobby.open('menu')==true and lobby.is_open()=='menu')
assert(states_since(0)=='lobby: open menu',states_since(0))
assert(shown.lobby and shown.lobby_top and not shown.lobby_settings)
assert(inputs[1].on==true and inputs[1].who=='lobby' and inputs[1].mouse==true and sounds[1]=='open')
local rows=live(ROW)
assert(#rows==8,#rows)
for i,p in ipairs(rows) do assert(p.x==172 and p.y==L.rows[i] and p.group=='lobby',i) end
local hints=live(HINT)
assert(#hints==3 and hints[1].x==3280 and hints[2].x==2860 and hints[3].x==2440)
for _,p in ipairs(hints) do assert(p.y==1990 and has(p,'SetButtonClickable',false)) end
assert(hints[1].calls[2][2].text=='Back' and hints[1].calls[3][2].name=='Negative')
assert(hints[1].calls[4][2].name=='None')
assert(hints[3].calls[3][2].name=='UI_DPad_Up' and hints[3].calls[4][2].name=='UI_DPad_Down')
-- Labels (R24): mode.ffa, row.more with tag.soon beside it, row.<id> for the others.
local labels={}
for i,p in ipairs(rows) do labels[i]=p.props.Text_Value.text end
local joined=table.concat(labels,',')
assert(joined=='Free-for-all,More modes,Search,Private match,Join with a code,Waiting room,Settings,Leave',joined)
assert(text_at('lobby_top',772,L.rows[2]+32).s=='soon' and text_at('lobby_top',772,L.rows[1]+32).s=='')
-- A locked row is disabled before it enters the canvas; an open one is not.
assert(names(rows[2])=='SetVisibility =Text_Value SetIsEnabled AddChild' and rows[2].calls[3][2]==false,names(rows[2]))
assert(not has(rows[1],'SetIsEnabled'))
-- The cursor starts on the first action row (Search): its select look; the status beside it.
assert(count_of(rows[3],'SelectAnimation')==1 and not has(rows[1],'SelectAnimation'))
assert(text_at('lobby',772,1364+32).s=='Pick a mode, then Search.' and text_at('lobby',772,1470+32).s=='')
-- The top block is drawn at the 8-row layout: not moved; the English logo only; the FFA text.
assert(moved.lobby_top.y==0)
local logos={}
for _,i in ipairs(groups.lobby_top.images) do if i.shown then logos[#logos+1]=i.tex end end
assert(#logos==1 and logos[1]=='logo')
assert(text_at('lobby_top',233,1234).s==T.en.lobby.desc.ffa)
-- Idle: the members box says there is no lobby yet.
assert(text_at('lobby',2660,1040).s==T.en.lobby.empty)

-- Down: the row left gets NormalAnimation, the new one SelectAnimation; kit's move sound, no select sound.
sounds={}
lobby.nav('down')
assert(count_of(rows[3],'NormalAnimation')==1 and count_of(rows[4],'SelectAnimation')==1 and sounds[1]=='move')
-- Select on Search: act gets the request, the row its PressAccept; kit plays nothing.
lobby.nav('up')
sounds={}
lobby.nav('select')
assert(#acts==1 and acts[1].request=='match search ffa',#acts)
assert(count_of(rows[3],'EventNotification','PressAccept')==1 and #sounds==0)
-- Up to More (locked): no look on a locked row, the mode text says more modes come later; Select there does nothing.
lobby.nav('up')
assert(count_of(rows[3],'NormalAnimation')==2 and not has(rows[2],'SelectAnimation'))
assert(text_at('lobby_top',233,1234).s==T.en.lobby.desc.more)
sounds={}
lobby.nav('select')
assert(#acts==1 and not has(rows[2],'EventNotification') and #sounds==0)
-- Back is the waiting room (main.lua's act closes B, which logs it).
lobby.nav('back')
assert(acts[2].close=='room' and sounds[1]=='back' and #states==1)
acts={}

-- Searching: six rows made again (FFA locked now), the status beside Cancel in warn, the block moved down 212.
input.match,input.last={state='searching',mode='ffa'},'search'
lobby.slow(clock)
for _,p in ipairs(rows) do assert(not p.alive) end
rows=live(ROW)
local L4=Lobby.layout(2,4)
assert(#rows==6 and rows[1].y==L4.rows[1] and rows[3].y==1576 and has(rows[1],'SetIsEnabled',false))
assert(rows[3].props.Text_Value.text=='Cancel' and moved.lobby_top.y==212)
local status=text_at('lobby',772,1576+32)
assert(status.s=='Searching…' and status.color==require('ui.kit.kit').THEME.warn and text_at('lobby',772,1364+32).s=='')
assert(text_at('lobby',2660,1040).s==T.en.lobby.empty_search)
-- In a lobby: the members box lists us first (no name: the tag alone), the host, a ping, the connecting and lost words.
input.match={state='open',mode='ffa',members=5,limit=8}
input.me={id=me.id}
input.owner='76561198000000001'
input.role='guest'
input.members={{id='76561198000000001',linked=true,lost=false,muted=false,rtt=90,name='Ann'},
    {id='76561198000000004',linked=false,lost=false,muted=false,rtt=0,name='Cy'},
    {id='76561198000000005',linked=true,lost=true,muted=false,rtt=40,name='Di'}}
lobby.slow(clock)
local box=texts('lobby')
assert(box:find('Members|5 of 8|In the lobby, 5 of 8',1,true),box)
assert(box:find('|you|Ann|host|90 ms|Cy|connecting…|Di|lost',1,true),box)
input.me=me
-- The mouse: the first look takes nothing (a resting mouse); a move onto Waiting room takes the cursor; a click
-- selects the row under it.
groups.lobby.zones[5].hover=true -- Action zone 5 of 6: the 4th action row of 4 is zone 6, so zone 5 is Settings.
lobby.tick(clock)
local before=count_of(rows[5],'SelectAnimation')
assert(before==0)
groups.lobby.zones[5].hover,groups.lobby.zones[4].hover=false,true
clock=clock+0.2
sounds={}
lobby.tick(clock)
assert(count_of(rows[4],'SelectAnimation')==1 and sounds[1]=='move',names(rows[4]))
lobby.nav('click')
assert(acts[1].close=='room' and count_of(rows[4],'EventNotification','PressAccept')==1)
groups.lobby.zones[4].hover=false
acts={}

-- A root build (map change): the parts are gone; the next draw makes them again.
for _,p in ipairs(parts) do p.alive=false end
lobby.slow(clock)
assert(#live(ROW)==6 and #live(HINT)==3)
rows=live(ROW)

-- C: tab match, read-only, SB's locked look; the first item focused; the right pane's headers.
assert(lobby.open('settings')==true and lobby.is_open()=='settings')
assert(states_since(1)=='lobby: open settings',states_since(1))
assert(shown.lobby_settings and not shown.lobby and not shown.lobby_top)
local heads=in_list(HEADER)
assert(heads[1].props.Category_Name.text=='Free-for-all' and heads[1].x==192 and heads[1].y==384)
local opts=in_list(OPTION)
assert(opts[1].props.Text_TitleValue.text=='Players' and opts[1].props.Text_ItemValue.text=='2 to 8')
assert(opts[1].props.bLockItem==true and has(opts[1],'EventNotification','RefreshAppearance'))
assert(names(opts[1]):find('=bLockItem AddChild EventNotification',1,true),names(opts[1]))
assert(count_of(opts[1],'EventNotification','StateFocus')==1 and opts[1].y==384+130)
local pane=false
for _,h in ipairs(live(HEADER)) do if h.x==2600 and h.props.Category_Name.text=='Members  5 of 8' then pane=true end end
assert(pane)
-- Two tab icons at y 120 and three hints (Back, Change, Tabs: no Select off an action row).
local icons=0
for _,p in ipairs(live(HINT)) do if p.y==120 then icons=icons+1 end end
assert(icons==2 and in_group(HINT,'lobby_settings')==5,in_group(HINT,'lobby_settings'))
-- tab_right: tab sbo; the chat header and row; the cursor on Chat.
lobby.nav('tab_right')
heads,opts=in_list(HEADER),in_list(OPTION)
assert(heads[1].props.Category_Name.text=='CHAT' and opts[1].props.Text_TitleValue.text=='Chat')
assert(opts[1].props.Text_ItemValue.text=='On' and opts[1].props.bLockItem==nil)
assert(count_of(opts[1],'EventNotification','StateFocus')==1)
-- Down: Chat back to StateNormal, the mute row (Mute Ann) to StateFocus; its Select hint shows.
lobby.nav('down')
assert(count_of(opts[1],'EventNotification','StateNormal')==1)
assert(opts[2].props.Text_TitleValue.text=='Mute Ann' and count_of(opts[2],'EventNotification','StateFocus')==1)
local select_hint=false
for _,p in ipairs(live(HINT)) do if p.calls[2][2].text=='Select' then select_hint=true end end
assert(select_hint)
-- The shapes C hands to act (L12-R1): a mute row's request with SB's select look, a value row's new value, the
-- report.
lobby.nav('select')
assert(acts[1].request=='mute 76561198000000001' and count_of(opts[2],'EventNotification','StateSelect')==1)
lobby.nav('up')
lobby.nav('right')
assert(acts[2].set=='chat' and acts[2].value=='off')
for _=1,6 do lobby.nav('down') end -- mute x3, ui_language, ui_sounds, report
lobby.nav('select')
assert(acts[3].run=='report',acts[3] and acts[3].run)
-- private_room_row_cycles: idle with the hall lobbies, tab match's Map row (after Lobby) is a value row: right from
-- Random gives the first hall, left the last; the host's pick shows by its name.
local guest_input=input
input={role='none',me=me,now=0,settings=guest_input.settings,halls=true}
lobby.nav('tab_left')
for _=1,9 do lobby.nav('down') end -- finish to start, Lobby, Map
local function map_option()
    for _,p in ipairs(in_list(OPTION)) do if p.props.Text_TitleValue.text=='Map' then return p end end
end
assert(map_option().props.Text_ItemValue.text=='Random' and map_option().props.bLockItem==nil)
lobby.nav('right'); lobby.nav('left')
assert(acts[4].set=='room' and acts[4].value=='hotel' and acts[5].set=='room' and acts[5].value=='foyer')
input.room='station'
lobby.nav('up'); lobby.nav('down')
assert(map_option().props.Text_ItemValue.text=='Station',map_option().props.Text_ItemValue.text)
input=guest_input
-- Back: B again.
lobby.nav('back')
assert(lobby.is_open()=='menu' and shown.lobby and not shown.lobby_settings)
assert(states_since(2)=='lobby: settings back',states_since(2))
acts={}

-- The leave question: ButtonType 3, its texts, then RefreshAll; it holds the keys.
local answers={}
assert(lobby.popup('leave',function(yes) answers[#answers+1]=yes end)==true and lobby.is_open()=='popup')
assert(states_since(3)=='lobby: popup leave open',states_since(3))
local pop=live(POPUP)[1]
assert(pop.hit==true and pop.props.ButtonType==3 and pop.props.TitleText.text=='LEAVE THE LOBBY')
assert(pop.props.DescText.text==T.en.lobby.pop.leave and pop.props.MessageText.text=='')
assert(names(pop)=='=TitleText =DescText =MessageText =ButtonType AddChild EventNotification'
    and pop.calls[6][2]=='RefreshAll',names(pop))
assert(shown.lobby_popup)
lobby.nav('down') -- Nothing reaches B under it.
assert(#acts==0)
-- Yes: on_answer(true), SB's Accept animation and sound, focus back on the root at once, removed 0.25 s later.
refocused,played=0,{}
lobby.nav('select')
assert(answers[1]==true and refocused==1 and lobby.is_open()=='menu')
assert(states_since(4)=='lobby: popup leave yes',states_since(4))
assert(has(pop,'PlayAnimation','anim Accept') and played[1].n==8)
assert(played[1][1]==pop.o and played[1][2]=='sound accept')
local anim
for _,c in ipairs(pop.calls) do if c[1]=='PlayAnimation' then anim=c end end
assert(anim[3]==0 and anim[4]==1 and anim[5]==0 and anim[6]==1 and anim[7]==false)
lobby.tick(clock+0.2)
assert(pop.alive)
lobby.tick(clock+0.26)
assert(not pop.alive and not shown.lobby_popup)
-- No: Back, then a click on its No button.
lobby.popup('leave',function(yes) answers[#answers+1]=yes end)
pop=live(POPUP)[1]
lobby.nav('back')
assert(answers[2]==false and has(pop,'PlayAnimation','anim close') and played[2][2]=='sound close')
lobby.popup('leave',function(yes) answers[#answers+1]=yes end)
lobby.nav('click') -- Over neither button: nothing.
assert(#answers==2)
buttons.negative=true
lobby.nav('click')
assert(answers[3]==false)
assert(states_since(5)=='lobby: popup leave open|lobby: popup leave no|lobby: popup leave open|lobby: popup leave no',
    states_since(5))
buttons.negative=false
lobby.tick(clock+1)

-- The countdown: made at the first count, bIgnorePause; StartTimer once a start; each frame CurrentTime and
-- UpdateTimer; a restart writes the new length without a second StartTimer; stop collapses it.
lobby.count(10,0)
local cd=live(COUNT)[1]
assert(cd.group=='lobby_count' and cd.x==0 and cd.y==0 and cd.w==600 and cd.h==160 and cd.props.bIgnorePause==true)
assert(names(cd)=='SetVisibility =bIgnorePause AddChild =TotalTime =CurrentTime UpdateTimer EventNotification',
    names(cd))
assert(cd.calls[4][2]==10 and cd.calls[5][2]==0 and cd.calls[7][2]=='StartTimer')
local after=since(cd)
lobby.tick(2.5)
assert(after()=='=CurrentTime UpdateTimer' and cd.props.CurrentTime==2.5,after())
lobby.count(8,2.75) -- On time (shown 7.25): nothing written by count.
assert(after()=='=CurrentTime UpdateTimer')
lobby.count(5,3)
assert(cd.props.TotalTime==5 and cd.props.CurrentTime==0 and count_of(cd,'EventNotification','StartTimer')==1)
lobby.tick(9)
assert(cd.props.CurrentTime==5) -- Never past the length.
lobby.stop_count()
assert(cd.calls[#cd.calls][1]=='SetVisibility' and cd.calls[#cd.calls][2]==1)
lobby.count(10,20) -- A new start shows it again.
assert(count_of(cd,'EventNotification','StartTimer')==2 and #live(COUNT)==1)
lobby.stop_count()

-- close: the screens hidden, the input given back 150 ms later; the room overlay then shows.
clock=50
lobby.close()
assert(lobby.is_open()==nil and not shown.lobby and sounds[#sounds]=='close')
assert(states_since(9)=='lobby: closed',states_since(9))
lobby.close() -- Nothing open: no line.
assert(#states==10)
inputs={}
lobby.slow()
lobby.tick(50.1)
assert(#inputs==0) -- slow leaves it to tick, which alone clears back_at.
lobby.tick(50.2)
assert(inputs[1].on==false and inputs[1].who=='lobby')
input.match,input.members,input.role,input.last=nil,nil,'none',nil
lobby.room(true)
assert(shown.lobby_room)
-- Right of SB's bottom-left HUD icons, which reach x 221 (screenshot 2026-11-12 21:53 UTC).
assert(groups.lobby_room.place.x>=240,groups.lobby_room.place.x)
assert(texts('lobby_room')=='Free-for-all · Pick a mode, then Search.|Lobby menu: F5, or hold View',texts('lobby_room'))
lobby.open('menu')
assert(not shown.lobby_room)
lobby.close()
assert(shown.lobby_room)
assert(states_since(10)=='lobby: open menu|lobby: closed',states_since(10))

-- The parts check: each class made once and dropped, one line each; a class the build lacks says why.
assert(#logs==0,logs[1]) -- Nothing refused or left out so far.
fail_class=COUNT
local all,line=lobby.parts_check()
assert(all==false and line=='lobby parts: 5 of 6 made (the log has each)',line)
assert(logs[1]=='lobby parts: WB_Lobby_Menu_Slot_C ok')
assert(logs[6]=='lobby parts: WB_MainHUD_CountDown_C not in this game build',logs[6])
for _,p in ipairs(parts) do if p.group=='lobby_count' and p.class~=COUNT then assert(not p.alive) end end
fail_class=nil

-- Over the whole test: no focus, no click-through, no call outside L4 2's list; HitTestInvisible but the popup.
local FORBIDDEN={SetUserFocus=1,SetKeyboardFocus=1,RequestWidgetFocus=1,CloseSelf=1,FadeOutFinish=1,SelectButton=1,
    AcceptButton=1,CancelButton=1,ResetWidget=1,NotifyBlueprint=1,SendWidgetInputEvent=1}
local EVENTS={[ROW]={PressAccept=1},[OPTION]={StateNormal=1,StateFocus=1,StateSelect=1,RefreshAppearance=1,
    EnableSetting=1,DisableSetting=1},[POPUP]={RefreshAll=1,Refresh=1,PlayFadeInAnimation=1,PlayDisableAnimation=1},
    [COUNT]={StartTimer=1},[HEADER]={},[HINT]={}}
assert(#parts>40,#parts)
for _,p in ipairs(parts) do
    local vis={}
    for _,c in ipairs(p.calls) do
        assert(not FORBIDDEN[c[1]],p.class..' got '..c[1])
        if c[1]=='EventNotification' then assert(EVENTS[p.class][c[2]],p.class..' got '..tostring(c[2])) end
        if c[1]=='=ButtonType' then assert(c[2]~=4 and c[2]~=5 and c[2]~=7) end
        if c[1]=='SetVisibility' then vis[#vis+1]=c[2] end
    end
    if p.class==POPUP and p.hit then assert(#vis==0)
    else
        assert(vis[1]==3,p.class)
        for _,v in ipairs(vis) do assert(v==3 or v==1,p.class..' visibility '..tostring(v)) end
    end
end
-- The two log forms the grouped test looks for (L14-R2), on a second lobby: a refused call logs once a kind; a class
-- that cannot be made logs once and is left out; a UI not up yet logs nothing and is tried again.
local logs2={}
local lobby2=Lobby.new({kit=kit,words=function() return T.en end,view=function() return input end,
    act=function() end,log=logger(logs2)})
breaks.UpdateTimer='UpdateTimer is not a function'
lobby2.count(10,60)
lobby2.tick(61)
breaks.UpdateTimer=nil
assert(#logs2==1 and logs2[1]=='lobby: countdown refused: UpdateTimer is not a function',logs2[1])
lobby2.stop_count()
fail_class,fail_why=POPUP,'the UI is not up'
assert(lobby2.popup('leave',function() end)==false and #logs2==1)
fail_why=nil
-- Left out: ruling 5's fallback asks the same question with kit texts and Yes and No rows, and answers it.
local answered=nil
assert(lobby2.popup('leave',function(yes) answered=yes end)==true and #logs2==2)
assert(logs2[2]=='lobby: part '..POPUP..': not in this game build; left out until the mod reloads',logs2[2])
local pop=groups.lobby_popup
local function pop_texts() local t={} for _,x in ipairs(pop.texts) do t[#t+1]=x.s end return table.concat(t,'|') end
assert(pop_texts()==T.en.lobby.pop.leave_title..'|'..T.en.lobby.pop.leave and pop.images[1].shown)
assert(pop.zones[1].label==T.en.lobby.row.leave and pop.zones[2].label==T.en.hint.back)
assert(lobby2.is_open()=='popup')
lobby2.nav('select')
assert(answered==true and pop_texts()=='|' and not pop.images[1].shown and pop.zones[1].label=='')
fail_class=nil
assert(lobby2.popup('leave',function(yes) answered=yes end)==true and #logs2==2) -- Left out until the mod reloads.
pop.zones[2].hover=true
lobby2.nav('click')
pop.zones[2].hover=false
assert(answered==false and pop_texts()=='|')
-- B's rows and C's items with no SB part: their words on the kit rows under them, the cursor's in focus.
local logs3={}
fail_class=ROW
local rows_before,options_before=#live(ROW),#in_list(OPTION)
local lobby3=Lobby.new({kit=kit,words=function() return T.en end,view=function() return input end,
    act=function() end,log=logger(logs3)})
assert(lobby3.open('menu'))
local labels,focus={},0
for _,name in ipairs({'lobby_top','lobby'}) do
    for _,z in ipairs(groups[name].zones) do
        if z.label~='' then labels[z.label]=true end
        focus=focus+(z.state=='focus' and 1 or 0)
    end
end
assert(labels[T.en.lobby.mode.ffa] and labels[T.en.lobby.row.more] and focus==1 and #live(ROW)==rows_before)
assert(#logs3==1 and logs3[1]:find('left out until the mod reloads',1,true))
fail_class=OPTION
assert(lobby3.open('settings'))
local filled=0
for _,z in ipairs(groups.lobby_settings.zones) do filled=filled+(z.label~='' and 1 or 0) end
assert(filled>=2 and #in_list(OPTION)==options_before)
fail_class=COUNT
lobby3.count(7,100)
assert(groups.lobby_count.texts[1].s=='7')
lobby3.stop_count()
assert(groups.lobby_count.texts[1].s=='')
fail_class=nil
print('lobby_test ok')
