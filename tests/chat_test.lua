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
local Chat=require('chat')

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
-- The native part cleans her lines the same way (link_protocol.h's chat_clean): tests/link_protocol_test.cpp makes
-- these 20,000 lines with the same generator and asserts the same digest (FNV-1a over each result and a 0xFF).
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

os.date=date
stdout:write('chat_test ok\n')
