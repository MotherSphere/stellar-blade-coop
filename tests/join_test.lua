-- Join codes on screen (join.lua) on a fake kit, link and console (ui_kit_test tests the kit itself: the field, its
-- focus and who holds the game's input). The code box: opened by the menu's row in a world only, the game's input on
-- the box and its keyboard focus again 50 ms later; Enter joins with a join code in either case, with or without the
-- dash, closes on an empty box, and keeps any other text with a line saying what a code looks like; Esc cancels; the
-- game's input comes back 150 ms after a close, not under a box opened again; it closes when the world goes, the game
-- pauses, a session starts or the kit turns off. The host's question: a player who is not her Steam friend asks to
-- join; "<name> wants to join" with Deny focused, the menu closed and the alert played as it opens; every key does
-- nothing for 1 s after it shows; then up and down move, Enter answers, Esc denies; each player asked once a lobby;
-- no answer runs nothing, the native part's 60 s answer; it waits while the chat box is open or the game is paused,
-- and hides then; a name is cleaned and cut; coop ui reset denies an open question; coop off ends it.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
local calls,state,built,placed={},{ready=true,off=false,paused=false},{},{}
local holder,inputting=nil,false
local fields={} -- The field of each group: {text=, hint=, focuses=}.
local kit={}
function kit.add(name,place,build)
    placed[#placed+1]=name
    local b={panel=function() end}
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
    function b.hints(_,_,_,list) local out={}; for i,h in ipairs(list) do out[i]=b.text(0,0,h[2]) end; return out end
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
local function since(n) return table.concat(calls,'|',n+1) end
-- The link as of its last read: the mode, the lobby, the joiner waiting.
local link={m='none',at='0',waiting=nil}
function link.mode() return link.m end
function link.lobby() return link.at end
function link.pending() return link.waiting end
link.join_code=require('link').join_code -- The real one (link_test tests it).
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
local Join=require('join')
local TH={error='red'}
local box=Join.box({kit=kit,link=link,settings=settings,theme=TH,run=run})
local ask=Join.ask({kit=kit,link=link,settings=settings,theme=TH,run=run,say=function(t) said[#said+1]=t end,
    menu=menu,chat=chat})
assert(placed[1]=='code' and placed[2]=='ask' and built.code.place.hit and not built.code.place.shown
    and not built.ask.place.hit and not built.ask.place.shown,'Both hidden at first; the box takes the mouse')
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
    and code.note.c=='red' and code.hints[1].s=='Join' and code.hints[2].s=='Cancel')
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

-- The host's question. A joiner waiting (link.pending): it opens in a world, the menu closed first, the game's input on
-- it, the alert; Deny focused.
local q=built.ask.view
local function shown_rows() return q.rows[1].l..'|'..q.rows[1].st..' '..q.rows[2].l..'|'..q.rows[2].st end
link.m,link.at='host','7000'
ask.slow(true); assert(not ask.is_open(),'Nobody asks')
link.waiting={id='76561198000000009',name='Stranger'}
menu.open=true
n=#calls
ask.slow(true)
assert(ask.is_open() and since(n)=='menu closed|show ask true|input true ask|sound alert')
assert(q.title.s=='Stranger wants to join' and q.about.s=='Not on your Steam friends list. Denied in 60 s if you do '
    ..'not answer.' and shown_rows()=='Accept|normal Deny|focus' and q.hints[1].s=='Move' and q.hints[3].s=='Deny')
-- It opened on its own: for 1 s every key does nothing (a walk forward then a jump, a stray Enter or Esc).
local runs
n,runs=#calls,#ran
for _,what in ipairs({'up','select','down','back'}) do ask.nav(what) end
clock=10.99; ask.nav('up'); ask.nav('select')
assert(ask.is_open() and #ran==runs and #calls==n and shown_rows()=='Accept|normal Deny|focus','1 s: nothing')
-- Up and down move; Enter on Accept lets her in; asked once: her line, until the native part drops it, opens nothing.
clock=11; ask.nav('up'); assert(shown_rows()=='Accept|focus Deny|normal' and calls[#calls]=='sound move')
ask.nav('left'); assert(shown_rows()=='Accept|focus Deny|normal','Left and right: nothing')
n=#calls
ask.nav('select')
assert(ran[#ran]=='allow 76561198000000009' and not ask.is_open()
    and since(n)=='sound select|show ask false|sound close')
clock=11.1; ask.tick(clock); assert(calls[#calls]=='sound close')
clock=11.2; ask.tick(clock); assert(calls[#calls]=='input false ask','The game gets its keys 150 ms after')
runs=#ran
for _=1,300 do ask.slow(true) end
assert(not ask.is_open() and #ran==runs,'Answered: never asked again')
-- Another one: Esc denies; Enter on the Deny it starts on denies.
link.waiting={id='76561198000000008',name='Two'}
ask.slow(true); assert(ask.is_open() and shown_rows()=='Accept|normal Deny|focus')
clock=12.2; ask.nav('back'); assert(ran[#ran]=='deny 76561198000000008' and calls[#calls-2]=='sound back')
link.waiting={id='76561198000000007',name='Three'}
ask.slow(true); clock=13.2; ask.nav('down'); ask.nav('down'); ask.nav('select')
assert(ran[#ran]=='deny 76561198000000007')
-- Hidden while the chat box is open or the game is paused (the game's input given back), shown again after with Deny
-- focused, the seconds left and its 1 s with no keys.
link.waiting,clock={id='76561198000000006',name=''},20
chat.open=true
n=#calls
ask.slow(true); assert(not ask.is_open() and since(n)=='','The chat box open: it waits')
chat.open=false
for _=1,39 do ask.slow(true) end
assert(ask.is_open() and q.title.s=='A player wants to join' and q.about.s:find('in 50 s ',1,true),q.about.s)
link.waiting.name='Late Name'
clock=21; ask.nav('up'); ask.slow(true); assert(q.title.s=='Late Name wants to join','Her name, once Steam has it')
state.paused=true; ask.slow(true); assert(not ask.is_open())
clock=21.2; ask.tick(clock); assert(calls[#calls]=='input false ask')
state.paused=false; ask.slow(true); assert(ask.is_open() and shown_rows()=='Accept|normal Deny|focus')
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
-- A name is hers to choose: cleaned (controls, broken UTF-8) and cut to 16 characters.
link.waiting={id='76561198000000003',name='\27[31mÉve\226\128\174 '..('x'):rep(40)..' %s %d'}
ask.slow(true)
assert(q.title.s=='[31mÉve '..('x'):rep(8)..'... wants to join',q.title.s)
assert(Join.name('')==nil and Join.name('\1\2')==nil and Join.name('Kaanta')=='Kaanta')
-- An answer that cannot be written: said on screen.
refusal='cannot write coop-request.txt'
clock=clock+1; ask.nav('select')
assert(ran[#ran]=='deny 76561198000000003' and said[#said]=='cannot write coop-request.txt')
-- A new lobby: every answer of the last one forgotten.
link.at,link.waiting='7001',{id='76561198000000009',name='Stranger'}
ask.slow(true); assert(ask.is_open(),'Asked again in a new lobby')
-- coop ui reset: an open question denied. coop off: nothing more.
ask.close(); assert(ran[#ran]=='deny 76561198000000009' and not ask.is_open())
ask.close(); assert(ran[#ran]=='deny 76561198000000009','Closed: nothing')
link.at='7002'; ask.slow(true); assert(ask.is_open())
runs,n=#ran,#calls
ask.stop()
for _=1,200 do ask.slow(true) end
ask.nav('select')
assert(not ask.is_open() and #ran==runs and #calls==n)
print('join_test ok')
