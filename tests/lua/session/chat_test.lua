-- The session chat's model: a line is cleaned (well-formed UTF-8 only, C0, DEL, C1, bidi and zero-width controls
-- dropped, trimmed, at most 200 bytes and never cut inside a character); sent lines show at once and leave at most two
-- a second, four waiting at most; received lines need a session and chat on; the history keeps its last 50 lines (or
-- fewer) in memory only and is cleared when the session ends, by coop off (clear) and by a reload (a new model); and
-- no chat text ever reaches a log, a file or the console: the model has no way to write one.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
-- Any write the model could make is trapped: print, io and os file calls fail the test.
local function trap(what) return function() error('chat text could leak through '..what,2) end end
print,io.write,io.open,io.lines,io.popen,io.output=trap('print'),trap('io.write'),trap('io.open'),trap('io.lines'),
    trap('io.popen'),trap('io.output')
os.remove,os.rename,os.execute,os.tmpname=trap('os.remove'),trap('os.rename'),trap('os.execute'),trap('os.tmpname')
local stdout=io.stdout
local date=os.date
os.date=function(format) assert(format=='%H:%M'); return '21:04' end
local Chat=require('session.chat')

-- clean(): what the text box gives, as the line both players see.
local clean=Chat.clean
assert(clean('Bonjour é à ç')=='Bonjour é à ç' and clean('  hi  ')=='hi' and clean('😀 ok')=='😀 ok')
assert(clean('a\tb\nc\rd\0e')=='abcde','C0 controls dropped, not turned into spaces')
assert(clean('\27[31mred\127')=='[31mred','ESC and DEL dropped: the rest is plain text')
assert(clean('a\194\133b\194\160c')=='ab\194\160c','C1 (NEL) dropped, a no-break space kept')
for _,mark in ipairs({'\216\156','\226\128\139','\226\128\140','\226\128\141','\226\128\142','\226\128\143',
    '\226\128\168','\226\128\169','\226\128\170','\226\128\174','\226\129\160','\226\129\166','\226\129\169',
    '\239\187\191'}) do
    assert(clean('a'..mark..'b')=='ab',string.format('%q',mark)) -- ALM, ZW*, LRM/RLM, LS/PS, LRE..RLO, WJ, LRI..PDI, BOM.
end
assert(clean('a\255b\192\175c\237\160\128d\244\144\128\128e\226\130')=='abcde',
    'Invalid UTF-8 dropped: a stray byte, an overlong, a surrogate, past U+10FFFF, a cut character')
assert(clean('\0 \226\128\174 ')=='' and clean('')=='','Nothing left: empty')
-- 200 bytes at most, cut on a character boundary, then trimmed again.
local a=string.rep('a',199)
assert(clean(a..'é')==a,'é on bytes 200-201: dropped whole')
assert(clean(a:sub(2)..'é')==a:sub(2)..'é' and #clean(a:sub(2)..'é')==200,'é on bytes 199-200: kept')
assert(clean(string.rep('a',197)..'😀')==string.rep('a',197),'A 4-byte emoji across the cut: dropped whole')
assert(clean(a..' b')==a,'A space left at the cut: trimmed')
assert(clean(string.rep('\0',50)..string.rep('a',250))==string.rep('a',200),'Controls go before the cut')
-- Long runs of spaces cost no more than other text (a pasted line runs on the game thread): well under a second.
local start=os.clock()
assert(clean('a'..string.rep(' ',32000)..'b')=='a' and clean(string.rep(' ',32000))=='')
assert(os.clock()-start<0.5,os.clock()-start)
-- Whatever bytes come in, what comes out is well-formed, short, trimmed and free of controls.
math.randomseed(7)
for _=1,3000 do
    local bytes={}
    for i=1,math.random(0,320) do bytes[i]=string.char(math.random(0,255)) end
    local out=clean(table.concat(bytes))
    assert(utf8.len(out) and #out<=200 and not out:find('^%s') and not out:find('%s$'),out)
    for _,c in utf8.codes(out) do assert(c>=0x20 and c~=0x7F and not (c>=0x80 and c<=0x9F),c) end
end
-- The native part cleans her lines the same way (link/protocol.h's chat_clean): tests/native/link/protocol_test.cpp
-- makes these 20,000 lines with the same generator and asserts the same digest (FNV-1a over each result and a 0xFF).
do
    local TOKENS={' ','a','A','\0','\t','\n','\27','\127','\194\133','\194\160','\195\169','\226\130\172',
        '\240\159\152\128','\226\128\141','\226\128\174','\216\156','\239\187\191','\237\160\128','\192\175',
        '\244\144\128\128','\128','\191','\194','\226\130','\240\159','\248','\255'}
    local x=12345
    local function next_rand() x=(x*1103515245+12345)&0x7fffffff return x>>8 end
    local digest,total=2166136261,0
    for n=1,20000 do
        local longer=n%16==0
        local parts={longer and string.rep('a',170+next_rand()%40) or ''}
        for _=1,(longer and 12 or next_rand()%24) do
            parts[#parts+1]=next_rand()%8==0 and string.char(next_rand()%256) or TOKENS[next_rand()%#TOKENS+1]
        end
        local out=clean(table.concat(parts))..'\255'
        total=total+#out
        for i=1,#out do digest=((digest~out:byte(i))*16777619)&0xffffffff end
    end
    assert(digest==0xb5b7514c and total==368115,string.format('0x%08x %d',digest,total))
end

-- No session: nothing to send, nothing received.
local chat=Chat.new()
assert(select(2,chat.send('hi',0))=='no_session' and chat.receive('Kaanta','salut',0)==nil and #chat.lines()==0)
-- System notices go in the same feed, with or without a session.
local notice=chat.system('Kaanta joined.',0)
assert(notice.who=='system' and notice.text=='Kaanta joined.' and notice.time=='21:04' and chat.lines()[1]==notice)
chat.session(true)
local ok,line=chat.send('  hi ',1)
assert(ok and line.who=='you' and line.text=='hi' and line.time=='21:04' and line.at==1 and chat.lines()[2]==line,
    'Shown at once, cleaned')
local why
ok,why=chat.send(' \0 ',1)
assert(not ok and why=='empty' and #chat.lines()==2,'An empty line is no line (the box closes)')
assert(chat.take(1)=='hi' and chat.take(1)==nil,'Taken once')

-- Two a second at most, four waiting at most: the fifth is refused, never queued.
for _,text in ipairs({'a','b','c','d'}) do assert(chat.send(text,2)) end
ok,why=chat.send('e',2)
assert(not ok and why=='too_fast' and #chat.lines()==6,'The refused line is not shown')
assert(chat.take(1.2)==nil,'Half a second after the last one taken at the soonest')
assert(chat.take(1.5)=='a' and chat.take(1.9)==nil and chat.take(2)=='b' and chat.take(2.5)=='c')
assert(chat.send('e',2.5),'Room again')
assert(chat.take(3)=='d')
-- A line the native part could not send is marked on screen: the last one taken.
chat.fail()
local lines=chat.lines()
assert(lines[6].text=='d' and lines[6].unsent and not lines[5].unsent and not lines[7].unsent)
assert(chat.take(3.5)=='e' and chat.take(9)==nil)

-- Received: cleaned, name too; empty after cleaning, nothing.
local got=chat.receive('Ka\0anta\226\128\174','  salut é ',4)
assert(got.who=='partner' and got.name=='Kaanta' and got.text=='salut é' and got.at==4 and chat.lines()[8]==got)
assert(chat.receive('Kaanta','\226\128\139',4)==nil and #chat.lines()==8)

-- The session ends: history and waiting lines go; the next session starts empty.
chat.send('waiting',5)
chat.session(true) -- Still on: nothing cleared.
assert(#chat.lines()==9)
chat.session(false)
assert(#chat.lines()==0 and chat.take(10)==nil,'Cleared, the waiting line too')
assert(select(2,chat.send('x',10))=='no_session' and chat.receive('Kaanta','x',10)==nil)
chat.session(true)
assert(#chat.lines()==0 and chat.send('again',11) and chat.take(11)=='again')
-- coop off clears too.
chat.clear()
assert(#chat.lines()==0 and chat.take(12)==nil)
-- A pasted megabyte costs the game thread no more than a line: only its first 4 KB is cleaned.
local paste=string.rep('é',1<<20)
start=os.clock()
ok,line=chat.send(paste,13)
assert(ok and line.text==string.rep('é',100) and os.clock()-start<0.05,os.clock()-start)
assert(chat.take(13)==line.text)

-- 50 lines by default, or the chat_lines setting's count: the oldest go first.
chat=Chat.new()
for i=1,60 do chat.system('n'..i,i) end
assert(#chat.lines()==50 and chat.lines()[1].text=='n11' and chat.lines()[50].text=='n60')
chat=Chat.new(20)
for i=1,25 do chat.system('n'..i,i) end
assert(#chat.lines()==20 and chat.lines()[1].text=='n6')
-- A reload is a new model: nothing kept at the module's level.
assert(#Chat.new().lines()==0)

-- chat=off: nothing sent, nothing received is shown; notices still are.
chat=Chat.new(50,false)
chat.session(true)
assert(select(2,chat.send('hi',0))=='off' and chat.receive('Kaanta','hi',0)==nil and chat.system('x',0))
assert(#chat.lines()==1 and chat.take(1)==nil)
-- The settings as ui_model.read gives them: text.
chat=Chat.new('20','off')
chat.session(true)
assert(select(2,chat.send('hi',0))=='off' and chat.receive('Kaanta','hi',0)==nil)
for i=1,25 do chat.system('n'..i,i) end
assert(#chat.lines()==20 and chat.lines()[1].text=='n6')
chat=Chat.new('50','on')
chat.session(true)
assert(chat.send('hi',0) and chat.receive('Kaanta','hi',0))

-- active() and enable(): a session holds; chat turned off and on again while the mod runs (the menu's Options).
chat=Chat.new()
assert(chat.active()==false)
chat.session(true)
assert(chat.active()==true)
chat.enable(false)
assert(select(2,chat.send('hi',0))=='off' and chat.receive('Kaanta','hi',0)==nil)
chat.enable(true)
assert(chat.send('hi',0) and chat.receive('Kaanta','hi',0))
chat.enable('off'); assert(select(2,chat.send('hi',0))=='off')
-- A notice is cleaned like a line (a Steam name may hold anything): nothing at all, no line.
assert(chat.system('Ka\0anta\226\128\174 joined.',0).text=='Kaanta joined.' and chat.system(' \0 ',0)==nil)

-- The view (Chat.view): the feed and the box on a fake kit (ui_kit_test tests the kit itself: the field, its focus and
-- who holds the game's input). Enter opens the box in a session only, with the game's input on the box and its
-- keyboard focus again 50 ms later; Enter sends (shown at once, queued, the box emptied and focused again), an empty
-- line closes, a line too fast stays in the box; Esc cancels and empties it; the game's input comes back 150 ms after
-- a close, once, and not when the box opens again before. The feed: chat lines and notices, newest at the bottom, the
-- last 6 rows of lines under 8 s old while closed, the last 12 while open, long lines wrapped at a space; her lines in
-- teal with a sound, ours white, notices grey, a line not sent red. It closes and empties when the session ends, chat
-- turns off (her lines hidden, Enter refused), our HUD hides or the kit turns off. No log function is given: nothing
-- can be logged (print and io are trapped above).
local clock=0
os.clock=function() return clock end
local calls,state,box,built,placed={},{ready=true,off=false,paused=false},{text='',focuses=0},{},{}
local holder,inputting=nil,false
local kit={}
function kit.add(name,place,build)
    placed[#placed+1]=name
    local b={panel=function() end}
    function b.text(_,_,s,_,color)
        local t={s=s,c=color,on=true}
        t.set,t.color,t.show=function(v) t.s=v end,function(c) t.c=c end,function(on) t.on=on end
        return t
    end
    function b.field(_,_,_,_,hint)
        box.hint=hint
        return {text=function() return box.text end,set=function(s) box.text=s end,
            focus=function() box.focuses=box.focuses+1 end,hint=function(s) box.hint=s end}
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
local TH={text='white',grey='grey',teal='teal',error='red'}
local settings,menu_open={chat=true,ui_language='game'},false
local model=Chat.new()
local view=Chat.view({kit=kit,model=model,settings=settings,theme=TH,covered=function() return menu_open end})
assert(placed[1]=='chat' and placed[2]=='feed' and built.chat.place.hit and not built.chat.place.shown
    and built.feed.place.shown and not built.feed.place.hit,
    'The glass and the box under the feed; only the box takes the mouse')
local rows=built.feed.view.rows
assert(#rows==12)
local function shown()
    local out={}
    for _,r in ipairs(rows) do if r.on then out[#out+1]=r.s end end
    return table.concat(out,'\n')
end
local function since(n) return table.concat(calls,'|',n+1) end

-- No session: Enter says so, once per 10 s; nothing opens and the kit is not touched.
view.slow(0)
assert(shown()=='' and #calls==0)
local ok,why=view.open()
assert(ok==false and why=='Chat needs a session.' and #calls==0)
assert(select(2,view.open())==nil,'Once per 10 s')
view.slow(9.75); assert(select(2,view.open())==nil)
view.slow(10); assert(select(2,view.open())=='Chat needs a session.')
-- No root up (a map loads, warming), the game paused or on one of its screens: nothing, quietly.
model.session(true)
state.ready=false; assert(view.open()==false and select(2,view.open())==nil and not view.can())
state.ready,state.paused=true,true; assert(view.open()==false and select(2,view.open())==nil and #calls==0)
state.paused=false
assert(view.can(),"The menu's Chat row")

-- Open: the box shown, the game's input on it, the hint in the game's language, an old draft gone; its keyboard focus
-- again 50 ms later.
box.text='old draft'
assert(view.open()==true and view.is_open() and since(0)=='show chat true|input true chat')
assert(box.text=='' and box.hint=='Message · Enter to send · Esc to close')
clock=0.04; view.tick(clock); assert(box.focuses==0)
clock=0.06; view.tick(clock); assert(box.focuses==1)
view.tick(clock); assert(box.focuses==1,'Once')
-- The counter at the box's right, read each 250 ms while open: from 160 bytes, red past the 200 a line keeps.
local count=built.chat.view.count
box.text=('é'):rep(79)..'a'; view.slow(10); assert(count.s=='' and count.c=='grey','159 bytes: none')
box.text=('é'):rep(80); view.slow(10); assert(count.s=='160/200' and count.c=='grey')
box.text=('a'):rep(205); view.slow(10); assert(count.s=='205/200' and count.c=='red','Past 200: the end is cut')
-- Enter: what Slate typed (any layout, accents) goes as one cleaned line, shown at once and queued; the box empties and
-- has the keys again 50 ms later.
box.text='  Bonjour é à ç  '
view.send()
assert(box.text=='' and shown()=='[21:04] You: Bonjour é à ç' and rows[12].c=='white' and view.is_open())
assert(count.s=='','Sent: the counter goes with the line')
assert(model.take(10)=='Bonjour é à ç','Queued for the native part')
clock=0.12; view.tick(clock); assert(box.focuses==2)
-- Her line: teal, after ours, with the game's chat sound; a notice grey.
model.receive('Kaanta','salut',10)
view.slow(10.25)
assert(shown()=='[21:04] You: Bonjour é à ç\n[21:04] Kaanta: salut' and rows[12].c=='teal'
    and calls[#calls]=='sound chat')
local n=#calls
view.slow(10.5); assert(#calls==n,'The sound once a line')
assert(view.say('Kaanta: connection lost.')==true and rows[12].s=='[21:04] Kaanta: connection lost.'
    and rows[12].c=='grey')
-- Four waiting at most: the fifth stays in the box to send again.
for _,t in ipairs({'a','b','c','d'}) do box.text=t; view.send() end
box.text='e'; view.send()
assert(box.text=='e' and view.is_open() and not shown():find('] You: e',1,true))
-- A line the native part could not send: red, marked.
assert(model.take(10.5)=='a')
model.fail()
view.slow(10.5)
assert(rows[9].s=='[21:04] You: a (not sent)' and rows[9].c=='red',rows[9].s)
-- An empty line closes the box; the game's input comes back 150 ms later, once (asked again each 250 ms till given).
box.text='   '
n=#calls
view.send()
assert(not view.is_open() and since(n)=='show chat false' and box.text=='')
clock=0.22; view.tick(clock); assert(since(n)=='show chat false')
clock=0.28; view.tick(clock); assert(since(n)=='show chat false|input false chat')
view.slow(10.75); view.tick(1); assert(since(n)=='show chat false|input false chat')
-- Esc: the draft goes with the box.
view.open(); box.text='brouillon'
view.cancel()
assert(not view.is_open() and box.text=='')
-- Opened again within the 150 ms: the input stays on the box, never given back under it.
n=#calls
clock=1.1; view.open()
clock=1.5; view.tick(clock); view.slow(11)
assert(view.is_open() and since(n)=='show chat true')
view.cancel(); clock=2; view.tick(clock)
assert(since(n)=='show chat true|show chat false|input false chat')

-- Closed, the feed shows the lines under 8 s old, 6 rows at most; open, the last 12, wrapped at a space.
model.session(false); model.session(true)
for i=1,8 do model.system('n'..i,20) end
view.slow(20)
assert(shown()=='[21:04] n3\n[21:04] n4\n[21:04] n5\n[21:04] n6\n[21:04] n7\n[21:04] n8' and not rows[6].on)
view.slow(27.75); assert(select(2,shown():gsub('\n',''))==5)
view.slow(28); assert(shown()=='','Faded 8 s after')
view.open()
assert(shown():find('^%[21:04%] n1\n') and select(2,shown():gsub('\n',''))==7,'Open: all of them')
local long=string.rep('word ',38)..'end'
model.receive('Kaanta',long,28)
view.slow(28)
assert(rows[10].s=='[21:04] Kaanta: '..string.rep('word ',10)..'word'
    and rows[11].s==string.rep('word ',13)..'word' and rows[12].s==string.rep('word ',13)..'end'
    and rows[11].c=='teal',rows[10].s..'|'..rows[11].s..'|'..rows[12].s)
model.receive('Kaanta',string.rep('x',150),28)
view.slow(28)
assert(rows[9].s=='[21:04] Kaanta:' and rows[10].s==string.rep('x',70) and rows[11].s==string.rep('x',70)
    and rows[12].s==string.rep('x',10),'A word longer than a row: on rows of its own, cut between characters')
model.receive('Kaanta',string.rep('敵',40),28)
view.slow(28)
assert(rows[10].s=='[21:04] Kaanta:' and rows[11].s==string.rep('敵',35) and rows[12].s==string.rep('敵',5),
    'A Chinese or Japanese character takes two of the 70 columns')
-- Thai and Arabic vowel and tone marks (Thai U+0E31, U+0E34 to U+0E3A, U+0E47 to U+0E4E; Arabic U+064B to U+065F,
-- U+0670) take no column: never the first thing on a row, they stay with the letter before them, the 70th's too.
-- Thai text with no space breaks between two letters; one with a space, at the space.
local function wrapped(text,wide) return table.concat(Chat.wrap(text,wide),'|') end
local THI,KO='ที่','กิ้' -- A letter and two marks each: one column.
assert(wrapped(THI:rep(75),70)==THI:rep(70)..'|'..THI:rep(5),'Thai, no space: 70 letters a row, marks and all')
assert(wrapped(('ก'):rep(69)..KO..'ข',70)==('ก'):rep(69)..KO..'|ข','The 70th letter keeps its marks')
assert(wrapped(('ก'):rep(40)..' '..('ข'):rep(40),70)==('ก'):rep(40)..'|'..('ข'):rep(40),'At the space')
assert(wrapped(('بَ'):rep(72),70)==('بَ'):rep(70)..'|'..('بَ'):rep(2),'Arabic: the fatha stays with its letter')
assert(wrapped(('ب'):rep(69)..'ىٰ'..'ب',70)==('ب'):rep(69)..'ىٰ|ب','And the superscript alef (U+0670)')
assert(Chat.columns('Ab 日本'..KO..'بَ')==9,'Columns as wrap counts them (the status strip measures with it)')
-- A Thai leading vowel (U+0E40 to U+0E44), written before the consonant it follows in speech, never ends a row cut
-- between letters: it goes to the next row with its consonant. A row it would leave empty keeps today's cut.
for _,v in ipairs({'เ','แ','โ','ใ','ไ'}) do
    assert(wrapped(('ก'):rep(69)..v..'ข',70)==('ก'):rep(69)..'|'..v..'ข',v..' moves to the next row')
    assert(wrapped(('ก'):rep(68)..v..v..'ข',70)==('ก'):rep(68)..'|'..v..v..'ข',v..' twice: both move')
    assert(wrapped(v..'ข',1)==v..'|ข',v..' alone on its row: kept there')
end
assert(wrapped(('ก'):rep(69)..'เ'..KO..'ข',70)==('ก'):rep(69)..'|เ'..KO..'ข','Marks still stay with their letter')
assert(wrapped(('ก'):rep(68)..KO..'เ'..'ข',70)==('ก'):rep(68)..KO..'|เข','After a letter with its marks')
assert(wrapped(('ก'):rep(40)..'เ '..('ข'):rep(40),70)==('ก'):rep(40)..'เ|'..('ข'):rep(40),'At a space: as before')

-- The session ends: the box closes and empties, the history goes (the notice that says so comes after).
box.text='half typed'
n=#calls
model.session(false)
view.slow(28.25)
assert(not view.is_open() and box.text=='' and shown()=='' and since(n)=='show chat false')
clock=3; view.tick(clock); assert(calls[#calls]=='input false chat')
-- chat=off (the menu's Options, at once): her lines and ours hidden, notices shown, Enter says it is off; the box
-- closes if open.
model.session(true)
view.open()
model.receive('Kaanta','secret',30)
view.slow(30)
assert(shown()=='[21:04] Kaanta: secret')
settings.chat=false
view.slow(30.25)
assert(not view.is_open() and shown()=='' and not view.can())
view.say('Kaanta left.')
assert(shown()=='[21:04] Kaanta left.')
assert(model.receive('Kaanta','hidden',30.25)==nil and select(2,model.send('x',30.25))=='off','The model off too')
view.slow(30.5); assert(shown()=='[21:04] Kaanta left.')
assert(select(2,view.open())=='Chat is off (Options > Chat).')
settings.chat=true
view.slow(41)
-- The menu open over the feed: the feed hides, once, and comes back after.
n=#calls
menu_open=true; view.slow(41); view.slow(41.25)
assert(since(n)=='show feed false')
menu_open=false; view.slow(41.5); assert(since(n)=='show feed false|show feed true')
-- Meanwhile the menu shows the newest notice under 8 s old (UI-DESIGN 4.4), past a chat line after it.
assert(view.notice()==nil,'The last notice is older than 8 s')
view.say('Kaanta joined.'); model.receive('Kaanta','hi',41.5)
assert(view.notice()=='Kaanta joined.')
view.slow(49.25); assert(view.notice()=='Kaanta joined.')
view.slow(49.5); assert(view.notice()==nil,'Faded with it')
-- The kit off (a fault, which gives the input back) or our HUD hidden: the box closes; notices go back to the line
-- above EVE (say is false).
view.open()
state.off=true
view.slow(50)
assert(not view.is_open() and view.say('x')==false)
assert(select(2,view.open())=='The chat box is off (the UI stopped, see UE4SS.log).','Said, not silent')
state.off=false
view.open()
state.ready=false
view.send()
assert(not view.is_open(),'Enter with no root: closed, nothing read')
assert(view.say('x')==false)
state.ready=true
-- The game pauses or shows the mouse cursor while open (a death screen, the friend's photo pause): closed, the draft
-- gone, so that screen's Enter and Esc are its own.
view.open(); box.text='draft'
state.paused=true; view.slow(50.25)
assert(not view.is_open() and box.text=='')
view.send(); assert(model.take(99)==nil,'Nothing sent')
state.paused=false
-- French: the hint and our name.
state.language='fr-FR'
clock=10; view.tick(clock)
view.open()
assert(box.hint=='Message · Entrée pour envoyer · Échap pour fermer')
box.text='salut'
view.send()
assert(rows[12].s=='[21:04] Vous : salut',rows[12].s)
-- Her line while our root is down (a map load, our photo mode): its sound once the feed can show it, unless it waited
-- out its 8 s.
n=#calls
state.ready=false
model.receive('Kaanta','late',51); view.slow(51.25)
state.ready=true; view.slow(59)
assert(not since(n):find('sound chat',1,true),'8 s later: no sound')
state.ready=false
model.receive('Kaanta','soon',59); view.slow(59.25)
state.ready=true; view.slow(66.75)
assert(since(n):find('sound chat',1,true),'Under 8 s: its sound')
-- Enter with the kit off, in French: why in French, and in English for the line above EVE (Latin-1 only).
state.off=true; view.slow(67)
local _,why_fr,why_en=view.open()
assert(why_fr==require('ui.text').fr.chat.ui_off and why_en=='The chat box is off (the UI stopped, see UE4SS.log).')
state.off=false
-- coop off: closed, nothing more asked of the kit (kit.stop gives the input back).
n=#calls
view.stop()
clock=20; view.tick(clock)
assert(not view.is_open() and #calls==n)

os.date=date
stdout:write('chat_test ok\n')
