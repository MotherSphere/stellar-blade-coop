-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Join codes on screen (session/join.lua) on a fake kit, link and console (ui_kit_test tests the kit itself: the field,
-- its focus and who holds the game's input). The code box: opened by the menu's row in a world only, the game's input
-- on the box and its keyboard focus again 50 ms later; Enter joins with a join code in either case, with or without the
-- dash, closes on an empty box, and keeps any other text with a line saying what a code looks like; Esc cancels; the
-- game's input comes back 150 ms after a close, not under a box opened again; it closes when the world goes, the game
-- pauses, a session starts or the kit turns off.
-- The host's question on the kit's panel (SB's popup missing from this build, logged once): a player asks to join;
-- "<name> wants to join" with Deny focused, the menu closed and the alert played as it opens; every key does nothing
-- for 1 s after it shows; then up and down move, Enter answers, Esc denies, each with SB's popup cue; each player asked
-- once a lobby; no answer runs nothing, the native part's 60 s answer; it waits while the chat box is open or the game
-- is paused (hidden then); a name is cleaned (no < or >) and cut; the joiner's wait on the panel, Close leaving the
-- lobby; coop ui reset denies an open question; coop off ends it.
-- The same on SB's WB_Common_Popup: filled before its Construct (title, description, seconds, ButtonType 3 or 1), then
-- RefreshAll and SB's words on its buttons (UI_Request_Accept, UI_CollectPersonalInfo_Refuse, UI_Close), the cursor
-- as its hover look, the seconds and a late name written to its blocks on change only; an answer plays its Accept or
-- close animation and cue, the part removed 250 ms later. The joiner's wait: Close leaves the lobby, a let in plays
-- Accept, a refusal close; coop ui reset hides it and stays. The feed's join and leave lines in SB's words (Join.feed).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
local calls,state,built,placed={},{ready=true,off=false,paused=false},{},{}
local holder,inputting=nil,false
local fields={} -- The field of each group: {text=, hint=, focuses=}.
local kit={}
function kit.add(name,place,build)
    placed[#placed+1]=name
    local b={}
    function b.panel(_,y,_,h) b.bottom=y+h end
    function b.text(_,_,s,_,color)
        local t={s=s,c=color}
        t.set,t.color=function(v) t.s=v end,function(c) t.c=c end
        return t
    end
    function b.field(_,_,_,_,hint)
        local f={text='',hint=hint,focuses=0}
        fields[name]=f
        return {text=function() return f.text end,set=function(s) f.text=s end,
            focus=function() f.focuses=f.focuses+1 end,hint=function(s) f.hint=s end}
    end
    function b.row()
        local r={}
        r.set=function(l,v,st) r.l,r.v,r.st=l,v,st end
        return r
    end
    -- Its labels; keys: the icons asked, in order ('move enter escape'); y: the row's top; bottom: the panel's.
    function b.hints(_,y,_,list)
        local out,keys={},{}
        for i,h in ipairs(list) do out[i],keys[i]=b.text(0,0,h[2]),h[1] end
        out.keys,out.y,out.bottom=table.concat(keys,' '),y,b.bottom
        return out
    end
    built[name]={place=place,view=build(b)}
end
function kit.ready() return state.ready and not state.off end
function kit.view(name) return kit.ready() and built[name].view or nil end
function kit.off() return state.off end
function kit.paused() return state.paused end
function kit.language() return state.language end
function kit.show(name,on) calls[#calls+1]='show '..name..' '..tostring(on) end
function kit.sound(name) calls[#calls+1]='sound '..name end
function kit.input(on,who) -- As the kit: each once, and off only from the one who holds it.
    if on then
        if inputting and holder==who then return end
        holder,inputting=who,true
        calls[#calls+1]='input true '..tostring(who)
    elseif inputting and holder==who then
        inputting=false
        calls[#calls+1]='input false '..tostring(who)
    end
end
-- SB's parts (kit.part): each a fake WB_Common_Popup keeping what it is sent (sent) and its fields; no_parts: the kit
-- answers as for a part missing from this game build.
local made,warmed,no_parts={},{},false
FText=function(s) return s end
local function popup()
    local w={sent={},Accept='Accept',close='close'}
    for _,name in ipairs({'TitleTextBlock','RichTextBlock_Message','ButtonTextBlock_1','ButtonTextBlock_2',
            'Image_Hover_Positive','Image_Hover_Negative'}) do
        w[name]={SetText=function(_,t) w.sent[#w.sent+1]=name..' '..t end,
            SetVisibility=function(_,v) w.sent[#w.sent+1]=name..' '..v end}
    end
    function w.EventNotification(_,e) w.sent[#w.sent+1]='event '..e end
    function w.PlayAnimation(_,a) w.sent[#w.sent+1]='play '..a end
    return w
end
function kit.warm_part(path) warmed[#warmed+1]=path end
function kit.part(group,class,_,_,_,_,fill)
    if no_parts then return nil,'part '..class:match('[^.]+$')..': not in this game build' end
    local w=popup()
    fill(w)
    made[#made+1]={o=w}
    calls[#calls+1]='part '..group
    return made[#made]
end
function kit.alive(rec) return rec and not rec.dropped and rec.o or nil end
function kit.drop(rec) if rec and not rec.dropped then rec.dropped=true; calls[#calls+1]='drop' end end
function kit.refocus() calls[#calls+1]='refocus' end
local function since(n) return table.concat(calls,'|',n+1) end
-- The link as of its last read: the mode, the lobby, the joiner waiting for our answer, our own wait as a joiner.
local link={m='none',at='0',waiting=nil,joined=nil}
function link.mode() return link.m end
function link.lobby() return link.at end
function link.pending() return link.waiting end
function link.wait() return link.joined end
link.join_code=require('core.link').join_code -- The real one (link_test tests it).
-- The console's commands (main.lua's run): each call kept as 'name arg'; refusal: what the next one answers.
local ran,refusal,said={},nil,{}
local function run(name,arg)
    ran[#ran+1]=name..(arg and ' '..arg or '')
    if refusal then local why=refusal; refusal=nil; return false,why end
    return true,'asked the native part'
end
local menu={open=false}
function menu.is_open() return menu.open end
function menu.close() menu.open=false; calls[#calls+1]='menu closed' end
local chat={open=false}
function chat.is_open() return chat.open end
local settings={ui_language='game'}
local Join=require('session.join')
local TH={error='red'}
local box=Join.box({kit=kit,link=link,settings=settings,theme=TH,run=run})
local logs={}
local function log(line) logs[#logs+1]=line end
local ask=Join.ask({kit=kit,link=link,settings=settings,theme=TH,run=run,say=function(t) said[#said+1]=t end,log=log,
    menu=menu,chat=chat})
assert(placed[1]=='code' and placed[2]=='ask' and placed[3]=='ask_popup' and built.code.place.hit
    and not built.code.place.shown and not built.ask.place.hit and not built.ask.place.shown
    and not built.ask_popup.place.hit and not built.ask_popup.place.shown and built.ask_popup.place.fixed
    and built.ask_popup.place.w==3840,'All hidden at first; the box takes the mouse, the popup keys only')
assert(warmed[1]=='/Game/Art/UI/Widget/GameMenu/Common/WB_Common_Popup.WB_Common_Popup','The popup loaded ahead')
local code,field=built.code.view,fields.code

-- The box: nothing while the root is down, the kit off or the game paused.
state.ready=false; assert(box.open()==false and #calls==0)
state.ready,state.paused=true,true; assert(box.open()==false and #calls==0)
state.paused,state.off=false,true; assert(box.open()==false and #calls==0)
state.off=false
-- Open: shown, the game's input on its field, an old text gone, its words; the keyboard focus again 50 ms later.
field.text='old'
assert(box.open()==true and box.is_open() and since(0)=='show code true|input true code')
assert(field.text=='' and field.hint=='XXX-XXXX' and code.title.s=='JOIN WITH A CODE' and code.note.s==''
    and code.note.c=='red' and code.hints[1].s=='Join' and code.hints[2].s=='Cancel' and code.hints.keys=='enter escape')
clock=0.04; box.tick(clock); assert(field.focuses==0)
clock=0.06; box.tick(clock); assert(field.focuses==1)
box.tick(clock); assert(field.focuses==1,'Once')
-- Not a code: said, kept, nothing run, focused again; a pasted megabyte too.
for _,typed in ipairs({'hello','0CS-CBM','0CS-CBMH\nleave',('7'):rep(1000000)}) do
    field.text=typed
    box.send()
    assert(box.is_open() and field.text==typed and #ran==0
        and code.note.s=='A join code is 7 letters and digits, like XXX-XXXX.',typed:sub(1,20))
end
clock=0.12; box.tick(clock); assert(field.focuses==2)
-- A code, either case, with or without the dash: joined, closed; the game's input back 150 ms later, once.
local n=#calls
field.text=' 0cs cbmh '
box.send()
assert(ran[1]=='join 0CS-CBMH' and not box.is_open() and field.text=='' and since(n)=='show code false')
clock=0.26; box.tick(clock); assert(since(n)=='show code false')
clock=0.28; box.tick(clock); assert(since(n)=='show code false|input false code')
box.slow(true); box.tick(1); assert(since(n)=='show code false|input false code')
-- The join refused (no native part, a file that cannot be written): said in the box, which stays.
box.open(); field.text='0CSCBMH'; refusal='cannot write coop-request.txt'
box.send()
assert(ran[2]=='join 0CS-CBMH' and box.is_open() and code.note.s=='cannot write coop-request.txt')
-- Enter on an empty box closes it; Esc cancels and the text goes.
field.text='   '; box.send(); assert(not box.is_open() and #ran==2)
box.open(); field.text='0CS'; box.cancel(); assert(not box.is_open() and field.text=='')
-- Opened again within the 150 ms: the input stays on the box.
clock=2; box.tick(clock)
n=#calls
box.open(); box.cancel(); clock=2.1; box.open()
clock=2.5; box.tick(clock); box.slow(true)
assert(box.is_open() and since(n)=='show code true|input true code|show code false|show code true')
-- It closes by itself: our HUD hidden (no world, our photo mode), the game paused, a session started, the kit off. An
-- unread status (no mode) closes nothing.
link.m=nil; box.slow(true); assert(box.is_open(),'Unread: still open')
for _,case in ipairs({{'hud',function() return false end},{'paused',function() state.paused=true end},
        {'host',function() link.m='host' end},{'guest',function() link.m='guest' end},
        {'off',function() state.off=true end}}) do
    state.paused,state.off,link.m=false,false,'none'
    if not box.is_open() then assert(box.open(),case[1]) end
    local shown=case[2]()
    box.slow(shown~=false)
    assert(not box.is_open(),case[1])
end
state.paused,state.off,link.m=false,false,'none'
-- French when the game is French.
state.language='fr-FR'
box.open(); field.text='x'; box.send()
assert(code.title.s=='REJOINDRE AVEC UN CODE' and code.hints[2].s=='Annuler'
    and code.note.s=='Un code compte 7 lettres et chiffres, comme XXX-XXXX.')
settings.ui_language='english'; box.cancel(); box.open(); assert(code.title.s=='JOIN WITH A CODE')
settings.ui_language,state.language='game',nil
-- coop off: closed with no engine call.
n=#calls
box.stop(); assert(not box.is_open() and #calls==n)
clock=10; box.tick(clock); assert(#calls==n)


-- The host's question on the kit's panel: SB's popup is missing from this build (the kit says so), so the first open
-- logs it once and ruling 5's panel shows. A player waiting (link.pending): it opens in a world, the menu closed first,
-- the game's input on it, the alert; Deny focused.
local q=built.ask.view
local function shown_rows() return q.rows[1].l..'|'..q.rows[1].st..' '..q.rows[2].l..'|'..q.rows[2].st end
no_parts=true
link.m,link.at='host','7000'
ask.slow(true); assert(not ask.is_open(),'Nobody asks')
link.waiting={id='76561198000000009',name='Stranger'}
menu.open=true
n=#calls
ask.slow(true)
assert(ask.is_open() and since(n)=='show ask_popup true|show ask_popup false|menu closed|show ask true|input true ask|'
    ..'sound alert',since(n))
assert(#logs==1 and logs[1]=='join: part WB_Common_Popup_C: not in this game build; left out until the mod reloads',
    logs[1])
assert(q.title.s=='Stranger wants to join' and q.about.s=='Declined in 60 s if you do not answer.'
    and shown_rows()=='Accept|normal Deny|focus' and q.hints[1].s=='Move' and q.hints[3].s=='Deny')
assert(q.hints.keys=='arrows enter escape','The arrows only: it opens on its own while she walks')
assert(q.hints.y+66<=q.hints.bottom and code.hints.y+66<=code.hints.bottom,'The key icons stay inside both panels')
-- It opened on its own: for 1 s every key does nothing (a walk forward then a jump, a stray Enter or Esc).
local runs
n,runs=#calls,#ran
for _,what in ipairs({'up','select','down','back'}) do ask.nav(what) end
clock=10.99; ask.nav('up'); ask.nav('select')
assert(ask.is_open() and #ran==runs and #calls==n and shown_rows()=='Accept|normal Deny|focus','1 s: nothing')
-- Up and down move; Enter on Accept lets her in with SB's confirm cue; asked once: her line, until the native part
-- drops it, opens nothing.
clock=11; ask.nav('up'); assert(shown_rows()=='Accept|focus Deny|normal' and calls[#calls]=='sound move')
ask.nav('left'); assert(shown_rows()=='Accept|focus Deny|normal','Left and right: nothing')
n=#calls
ask.nav('select')
assert(ran[#ran]=='allow 76561198000000009' and not ask.is_open() and since(n)=='show ask false|sound popup_confirm',
    since(n))
clock=11.1; ask.tick(clock); assert(calls[#calls]=='sound popup_confirm')
clock=11.2; ask.tick(clock); assert(calls[#calls]=='input false ask','The game gets its keys 150 ms after')
runs=#ran
for _=1,300 do ask.slow(true) end
assert(not ask.is_open() and #ran==runs,'Answered: never asked again')
-- Another one, with the alert again and no new try at SB's popup: Esc denies with SB's close cue; Enter on the Deny
-- it starts on denies.
link.waiting={id='76561198000000008',name='Two'}
n=#calls
ask.slow(true)
assert(ask.is_open() and shown_rows()=='Accept|normal Deny|focus' and #logs==1
    and since(n)=='show ask true|input true ask|sound alert',since(n))
clock=12.2; ask.nav('back'); assert(ran[#ran]=='deny 76561198000000008' and calls[#calls]=='sound popup_close')
link.waiting={id='76561198000000007',name='Three'}
ask.slow(true); clock=13.2; ask.nav('down'); ask.nav('down'); ask.nav('select')
assert(ran[#ran]=='deny 76561198000000007')
-- Hidden while the chat box is open or the game is paused (the game's input given back), shown again after with Deny
-- focused, the seconds left, its 1 s with no keys and SB's popup cue in place of the alert.
link.waiting,clock={id='76561198000000006',name=''},20
chat.open=true
n=#calls
ask.slow(true); assert(not ask.is_open() and since(n)=='','The chat box open: it waits')
chat.open=false
for _=1,39 do ask.slow(true) end
assert(ask.is_open() and q.title.s=='A player wants to join' and q.about.s:find('in 50 s ',1,true),q.about.s)
link.waiting.name='Late Name'
clock=21; ask.nav('up'); ask.slow(true); assert(q.title.s=='Late Name wants to join','Her name, once Steam has it')
state.paused=true; ask.slow(true); assert(not ask.is_open() and calls[#calls]=='sound popup_close')
clock=21.2; ask.tick(clock); assert(calls[#calls]=='input false ask')
n=#calls
state.paused=false; ask.slow(true); assert(ask.is_open() and shown_rows()=='Accept|normal Deny|focus')
assert(since(n)=='show ask true|input true ask|sound popup_open',since(n))
ask.nav('up'); assert(shown_rows()=='Accept|normal Deny|focus','Shown again: 1 s with no keys')
ask.slow(false); assert(not ask.is_open(),'Our HUD hidden: no world, our photo mode')
-- No answer runs nothing, shown or not: the native part refuses her at 60 s and drops her line. The seconds left
-- stop at 0 if its line is late.
runs=#ran
for _=1,300 do ask.slow(false) end
ask.slow(true); assert(ask.is_open() and #ran==runs and q.about.s:find('in 0 s ',1,true),q.about.s)
link.waiting=nil; ask.slow(true); assert(not ask.is_open() and #ran==runs)
-- The UI off: no question, nothing run.
link.waiting,state.off={id='76561198000000005',name='Five'},true
for _=1,300 do ask.slow(true) end
assert(not ask.is_open() and #ran==runs)
state.off=false
-- Her line gone before an answer (she left, or the console answered): closed, nothing run. An unread status (no mode)
-- changes nothing.
link.waiting={id='76561198000000004',name='Four'}
ask.slow(true); assert(ask.is_open())
link.m=nil; link.waiting=nil; ask.slow(true); assert(ask.is_open(),'Unread')
link.m='host'; runs=#ran
ask.slow(true); assert(not ask.is_open() and #ran==runs)
-- A name is hers to choose: cleaned (controls, broken UTF-8, < and >, which SB's rich text reads as a tag) and cut
-- to 16 characters.
link.waiting={id='76561198000000003',name='\27[31mÉve\226\128\174 '..('x'):rep(40)..' %s %d'}
ask.slow(true)
assert(q.title.s=='[31mÉve '..('x'):rep(8)..'... wants to join',q.title.s)
assert(Join.name('')==nil and Join.name('\1\2')==nil and Join.name('Kaanta')=='Kaanta' and Join.name('<>')==nil
    and Join.name('<Orange>Kaanta</>')=='OrangeKaanta/')
-- An answer that cannot be written: said on screen.
refusal='cannot write coop-request.txt'
clock=clock+1; ask.nav('select')
assert(ran[#ran]=='deny 76561198000000003' and said[#said]=='cannot write coop-request.txt')
-- A new lobby: every answer of the last one forgotten.
link.at,link.waiting='7001',{id='76561198000000009',name='Stranger'}
ask.slow(true); assert(ask.is_open(),'Asked again in a new lobby')
-- coop ui reset: an open question denied.
ask.close(); assert(ran[#ran]=='deny 76561198000000009' and not ask.is_open())
ask.close(); assert(ran[#ran]=='deny 76561198000000009','Closed: nothing')
-- Our own wait on the panel (we joined; link.wait): "Waiting for <host>'s answer", Close focused alone, the seconds the
-- native part gives; SB's popup cue as it opens (no alert: we asked); every key dead for 1 s; then Enter or Esc closes
-- it and leaves the lobby, once.
link.m,link.at,link.waiting,link.joined='guest','7300',nil,{left=60,host='<b>Host</b>'}
clock=clock+1; ask.tick(clock)
n=#calls
ask.slow(true)
assert(ask.is_open() and since(n)=='show ask true|input true ask|sound popup_open',since(n))
assert(q.title.s=="Waiting for bHost/b's answer"
    and q.about.s=='Close cancels your request to join. The host has 60 s left to answer.'
    and shown_rows()=='Close|focus |normal' and q.hints[1].s=='' and q.hints[3].s=='Close',q.title.s)
link.joined.left=42; ask.slow(true); assert(q.about.s:find('has 42 s left',1,true),q.about.s)
ask.nav('back'); assert(ask.is_open(),'1 s: nothing')
clock=clock+1; ask.nav('up'); ask.nav('down'); assert(ask.is_open(),'Up and down: nothing')
runs=#ran
ask.nav('select')
assert(ran[#ran]=='leave' and #ran==runs+1 and not ask.is_open() and calls[#calls]=='sound popup_close')
ask.slow(true); assert(not ask.is_open() and #ran==runs+1,'Closed: not again in this lobby')
-- A nameless host; let in: the panel goes with SB's confirm cue. Turned away (the lobby left): its close cue.
link.at,link.joined='7301',{left=60,host=''}
ask.slow(true); assert(ask.is_open() and q.title.s=="Waiting for the host's answer",q.title.s)
link.joined=nil; ask.slow(true)
assert(not ask.is_open() and calls[#calls]=='sound popup_confirm' and #ran==runs+1)
link.at,link.joined='7302',{left=60,host='Host'}
ask.slow(true); assert(ask.is_open())
link.m,link.at,link.joined='none',nil,nil; ask.slow(true)
assert(not ask.is_open() and calls[#calls]=='sound popup_close' and #ran==runs+1)
-- coop ui reset: our wait hidden, the lobby kept; not shown again in it.
link.m,link.at,link.joined='guest','7303',{left=60,host='Host'}
ask.slow(true); assert(ask.is_open())
ask.close(); assert(not ask.is_open() and #ran==runs+1)
ask.slow(true); assert(not ask.is_open(),'Hidden for this lobby')
-- coop off: nothing more.
link.m,link.at,link.joined='host','7002',nil
link.waiting={id='76561198000000009',name='Stranger'}
ask.slow(true); assert(ask.is_open())
runs,n=#ran,#calls
ask.stop()
for _=1,200 do ask.slow(true) end
ask.nav('select')
assert(not ask.is_open() and #ran==runs and #calls==n)
kit.input(false,'ask') -- As kit.stop does.

-- SB's popup (WB_Common_Popup), as in game: a new Join.ask, the part made this time. The host's question: filled
-- before its Construct (ButtonType 3), then RefreshAll, SB's Accept and Decline on its buttons and its hover look on
-- Decline; the panel never shows.
no_parts=false
local sb={UI_Request_Accept='Accept SB',UI_CollectPersonalInfo_Refuse='Decline SB',UI_Close='Close SB'}
local read={}
local pa=Join.ask({kit=kit,link=link,settings=settings,run=run,say=function(t) said[#said+1]=t end,log=log,
    game_text=function(key) read[#read+1]=key; return sb[key] end,menu=menu,chat=chat})
local function w() return made[#made].o end
local function sent(from,p) return table.concat((p or w()).sent,'|',from+1) end
link.at,link.waiting='7100',{id='76561198000000019',name='<Orange>Rex'}
menu.open,clock=true,100
n=#calls
pa.slow(true)
assert(pa.is_open() and since(n)=='show ask_popup true|part ask_popup|menu closed|input true ask|refocus|sound alert',
    since(n))
local p1=w()
assert(p1.TitleText=='OrangeRex wants to join' and p1.DescText=='They wait for your answer before they enter your game.'
    and p1.MessageText=='Declined in 60 s if you do not answer.' and p1.ButtonType==3)
assert(sent(0)=='event RefreshAll|ButtonTextBlock_1 Accept SB|ButtonTextBlock_2 Decline SB|Image_Hover_Positive 2|'
    ..'Image_Hover_Negative 3',sent(0))
-- 1 s with no keys; then up moves the hover look to Accept.
runs=#ran
pa.nav('select'); pa.nav('up'); assert(pa.is_open() and #ran==runs and #p1.sent==5,'1 s: nothing')
clock=101; pa.nav('up')
assert(calls[#calls]=='sound move' and sent(5)=='Image_Hover_Positive 3|Image_Hover_Negative 2',sent(5))
-- The seconds left and a late name: written to SB's blocks on change only.
pa.slow(true); assert(#p1.sent==7,'Nothing changed: nothing sent')
for _=1,3 do pa.slow(true) end
assert(sent(7)=='RichTextBlock_Message Declined in 59 s if you do not answer.'
    and p1.MessageText=='Declined in 59 s if you do not answer.',sent(7))
link.waiting.name='Rex'; pa.slow(true)
assert(sent(8)=='TitleTextBlock Rex wants to join' and p1.TitleText=='Rex wants to join',sent(8))
-- Accept: SB's Accept animation and confirm cue, our focus back; the game's input 150 ms later, the part gone at 250.
n=#calls
pa.nav('select')
assert(ran[#ran]=='allow 76561198000000019' and not pa.is_open() and sent(9)=='play Accept'
    and since(n)=='refocus|sound popup_confirm',since(n))
clock=101.2; pa.tick(clock); assert(calls[#calls]=='input false ask' and not made[#made].dropped)
clock=101.3; pa.tick(clock); assert(made[#made].dropped and since(n):find('|drop|show ask_popup false$'),since(n))
-- Esc on the next one: its close animation and cue. SB's words read once an open.
link.waiting={id='76561198000000018',name='Two'}
local reads=#read
pa.slow(true)
local p2=w()
assert(p2~=p1 and pa.is_open() and calls[#calls]=='sound alert' and #read==reads+2,#read-reads)
clock=102.3; pa.nav('back')
assert(ran[#ran]=='deny 76561198000000018' and sent(0,p2):find('|play close$') and calls[#calls]=='sound popup_close')
-- Hidden by a pause: its close animation; shown again as a new part with SB's popup cue. The old one goes at its
-- time; the group stays shown under the new one.
link.waiting={id='76561198000000017',name='Three'}
pa.slow(true)
local p3=w()
state.paused=true; pa.slow(true)
assert(not pa.is_open() and sent(0,p3):find('|play close$') and calls[#calls]=='sound popup_close')
state.paused=false
n=#calls
pa.slow(true)
assert(pa.is_open() and w()~=p3 and since(n):find('part ask_popup',1,true) and calls[#calls]=='sound popup_open',
    since(n))
clock=103; n=#calls; pa.tick(clock)
assert(made[#made-1].dropped and not made[#made].dropped and not since(n):find('ask_popup false',1,true),since(n))
-- A root build (a map change, the look warmed) took the part: made again at the next pass, Decline focused, 1 s with
-- no keys.
made[#made].dropped=true
local p6=w()
clock=103.5; pa.nav('up'); n=#calls
pa.slow(true)
assert(pa.is_open() and w()~=p6 and since(n):find('part ask_popup',1,true) and calls[#calls]=='sound popup_open'
    and sent(0):find('|Image_Hover_Positive 2|Image_Hover_Negative 3$'),since(n))
pa.nav('select'); assert(pa.is_open(),'1 s: nothing')
link.waiting=nil; pa.slow(true); assert(not pa.is_open() and sent(0):find('|play close$'),'She left')
clock=104; pa.tick(clock)
-- Our wait on SB's popup: ButtonType 1 with SB's Close on its buttons, no hover look, the seconds as the native part
-- gives them; Esc closes it and leaves the lobby.
link.m,link.at,link.joined='guest','7200',{left=60,host='Host<b>'}
reads=#read
pa.slow(true)
local p4=w()
assert(pa.is_open() and p4.ButtonType==1 and p4.TitleText=="Waiting for Hostb's answer"
    and p4.DescText=='Close cancels your request to join.' and p4.MessageText=='The host has 60 s left to answer.')
assert(sent(0)=='event RefreshAll|ButtonTextBlock_1 Close SB|ButtonTextBlock_2 Close SB',sent(0))
assert(calls[#calls]=='sound popup_open' and #read==reads+1)
link.joined.left=42; pa.slow(true)
assert(sent(3)=='RichTextBlock_Message The host has 42 s left to answer.',sent(3))
clock=104.5; pa.nav('select'); assert(pa.is_open(),'1 s: nothing')
clock=105; pa.nav('up'); assert(pa.is_open() and #p4.sent==4,'Up: nothing')
runs=#ran
pa.nav('back')
assert(ran[#ran]=='leave' and #ran==runs+1 and not pa.is_open() and sent(4,p4)=='play close'
    and calls[#calls]=='sound popup_close')
-- Let in: SB's Accept animation and confirm cue.
link.at,link.joined='7201',{left=60,host='Host'}
pa.slow(true)
local p5=w()
assert(pa.is_open() and p5~=p4)
link.joined=nil; pa.slow(true)
assert(not pa.is_open() and sent(0,p5):find('|play Accept$') and calls[#calls]=='sound popup_confirm'
    and #ran==runs+1)
-- coop ui reset: hidden, the lobby kept; not shown again in it.
link.at,link.joined='7202',{left=60,host='Host'}
pa.slow(true); assert(pa.is_open())
pa.close(); assert(not pa.is_open() and #ran==runs+1)
pa.slow(true); assert(not pa.is_open())
assert(#logs==1,'No refusal from SB\'s popup: '..table.concat(logs,'|'))

-- The feed's join and leave lines in SB's words, the name as the native part wrote it (a % in it kept); the others,
-- and every line when SB's word is missing or has no {Name}, stay as they came (nil).
local fr={UI_Night_Message_ComeBackFriend='{Name} a rejoint la partie.',
    UI_Night_Message_LeaveFriend='{Name} has left the game.'}
local function g(key) return fr[key] end
assert(Join.feed('Kaanta joined.',g)=='Kaanta a rejoint la partie.')
assert(Join.feed('Kaanta was let in.',g)=='Kaanta a rejoint la partie.')
assert(Join.feed('Kaanta left.',g)=='Kaanta has left the game.')
assert(Join.feed('100% %1 joined.',g)=='100% %1 a rejoint la partie.')
for _,line in ipairs({'Kaanta was not let in.','Session ended: Kaanta left.',' joined.','Kaanta: connection lost.',
        "Joined Kaanta's game. Waiting to be let in.",'A player who is not your Steam friend is asking to join.'}) do
    assert(Join.feed(line,g)==nil,line)
end
assert(Join.feed('Kaanta joined.',function() return nil end)==nil)
assert(Join.feed('Kaanta joined.',function() return 'Joined.' end)==nil)
print('join_test ok')
