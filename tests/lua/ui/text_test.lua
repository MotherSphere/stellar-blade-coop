-- ui/text.lua, pure (no fakes): a language's table only under one of the 23 culture names nightop/recruiter_text.lua's
-- culture() gives, and either empty or with exactly T.en's keys at every level, each word with T.en's format
-- placeholders in T.en's order (Lua's format has no positional arguments; a percent sign, %%, may stand anywhere, as
-- Turkish puts it first); T.pick's choice (the game's culture through culture(), English with ui_language=english,
-- for a culture with no table and for a word a table lacks); in every language, every notice within the feed's 200
-- bytes a line (Chat.clean) with a 32-byte name, every menu row, value and key hint within its column, the co-op
-- saves' question, with its invite line, within its 5 rows (Chat.wrap), Night Operation's card and result panel within
-- their columns, the challenges' words: a name for each of nightop/challenges.lua's ids, as the card's title, the Best
-- row and the lines under the heading within their columns, the notices with the longest name within 200 bytes (the
-- co-op one with a partner's 32-byte name too), the
-- co-op line's hint and sentences within theirs, the status strip's rows (partner/hud.lua): the second with every fact
-- within its columns, the top one with its connection lost and paused words whole before the status line, which comes
-- without its prefix, the race's panel, marker, banner and results within theirs, and no Thai word that ends on a
-- leading vowel.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local T=require('ui.text')
local R=require('nightop.recruiter_text')
local Chat=require('session.chat')
local C=require('nightop.challenges')
local P=require('partner.hud')
local function specs(s)
    local list={}
    for p in s:gmatch('%%.') do if p~='%%' then list[#list+1]=p end end -- %% takes no argument: anywhere.
    return table.concat(list,' ')
end
-- t has exactly en's keys at every level, its words with en's placeholders.
local function same(t,en,at)
    for k,v in pairs(en) do
        local mine=rawget(t,k)
        assert(type(mine)==type(v),at..k..': '..(mine==nil and 'missing' or 'a '..type(mine)))
        if type(v)=='table' then same(mine,v,at..k..'.')
        else assert(specs(mine)==specs(v),at..k..': "'..specs(mine)..'", not "'..specs(v)..'"') end
    end
    for k in pairs(t) do assert(en[k]~=nil,at..tostring(k)..': not in T.en') end
end
for name,t in pairs(T) do
    if type(t)=='table' then
        assert(R.TEXT[name],'T.'..name..': not a game culture name')
        if name~='en' and next(t) then same(t,T.en,name..'.') end
    end
end
assert(T.fr and next(T.fr),'French stays complete')
-- A challenge name for each challenge, and no other.
local ids={}
for _,def in ipairs(C.LIST) do
    ids[def.id]=true
    assert(type(T.en.challenge.names[def.id])=='string','T.en.challenge.names.'..def.id..': missing')
end
for id in pairs(T.en.challenge.names) do assert(ids[id],'T.en.challenge.names.'..id..': no such challenge') end

-- The pick: the game's culture as culture() names it, else English.
assert(T.pick('fr-FR')==T.fr and T.pick('FR')==T.fr and T.pick('fr-FR','game')==T.fr)
assert(T.pick('fr-FR','english')==T.en and T.pick(nil)==T.en and T.pick('xx-YY')==T.en and T.pick('en-US')==T.en)
for name in pairs(R.TEXT) do assert(T.pick(name)==(T[name] or T.en),name) end
assert(T.pick('zh-TW')==(T['zh-Hant'] or T.en) and T.pick('nb-NO')==(T.no or T.en) and T.pick('pt-PT')==(T.pt or T.en))
-- A word a table lacks reads English, at every level; one it has, its own.
local had=T.de
T.de={row={host='Sitzung hosten'}}
local de=T.pick('de-DE')
assert(de==T.de and de.row.host=='Sitzung hosten' and de.row.leave==T.en.row.leave and de.chat.hint==T.en.chat.hint)
assert(de.title==T.en.title and T.pick('de-DE','english')==T.en)
T.de=had

-- Format arguments: a 32-byte name for %s, a number for %d.
local NAME=('W'):rep(32)
local function fill(s)
    local args={}
    for p in s:gmatch('%%(.)') do if p~='%' then args[#args+1]=p=='s' and NAME or 16 end end
    return s:format(table.unpack(args))
end
-- The lines that go to the feed, as main.lua, partner/puppet.lua, session/saves.lua, core/link.lua and session/join.lua
-- put them together.
local function notices(w)
    local lines={}
    for _,group in ipairs({'fight','spawns','group','ghost','refused','quests','travel','ue4ss'}) do
        for _,text in pairs(w[group]) do lines[#lines+1]=fill(text) end
    end
    lines[#lines+1]=w.fight.on:format(16)..' '..w.fight.scale:format(200,200) -- The longest on.
    local p=w.pilot
    for _,text in ipairs({p.on:format(16),p.one,p.off:format(p.stopped),p.off:format(fill(p.host))}) do
        lines[#lines+1]=text
    end
    for _,text in ipairs({w.saves.on,fill(w.saves.off),w.saves.off:format(w.saves.see_log),w.saves.build,
        w.saves.manual:format('4','4'),w.chat.no_session,
        w.chat.off,w.chat.ui_off,w.join.bad}) do lines[#lines+1]=text end
    -- Night Operation's notices (nightop/run.lua, with the UI off): the start, a wave, a clear, the end and why; for
    -- two players, her notice of his start and his of each refusal, and whose EVE died; the points a run earned, or
    -- could not credit; a level picked from Roxanne, by the host or alone and by a guest (nightop/roxanne.lua); the
    -- shop's screen that could not open (nightop/shop.lua).
    local n=w.night
    for _,text in ipairs({n.start_notice:format(5),n.wave_notice:format(5,5),n.clear_notice:format(5),n.died,
        n.time_up,n.end_notice:format(n.success,5,5,20,9999,'8:00'),n.end_notice:format(n.fail,5,5,20,9999,'8:00'),
        n.coop_notice:format(NAME,5),n.mate_died,n.you_died,n.earned:format(42,999999999),n.unpaid,n.booked,
        n.host_only,n.shop_failed}) do
        lines[#lines+1]=text
    end
    for _,text in pairs(n.why) do lines[#lines+1]=text end
    for _,text in pairs(n.refuse) do lines[#lines+1]=n.refused:format(NAME,text) end
    -- A challenge's notices, with its longest name in this language, and the lines under its result.
    local c,long=w.challenge,''
    for _,def in ipairs(C.LIST) do if #c.names[def.id]>#long then long=c.names[def.id] end end
    for _,text in ipairs({c.start_notice:format(long,5),c.wave_notice:format(long,8,8),c.clear_notice:format(long,8),
        c.record,c.stopped,c.coop_notice:format(long,NAME,5)}) do
        lines[#lines+1]=text
    end
    -- The race's notices (race/run.lua): its banners too, which come as notices with the UI off.
    local r=w.race
    for _,group in ipairs({'why','refused','declined'}) do
        for _,text in pairs(r[group]) do lines[#lines+1]=fill(text) end
    end
    for _,k in ipairs({'armed','armed_guest','false_start','cancelled','out','recording','dropped','too_close','full',
        'other_map','saved','go','wrong_way','missed','finished','dnf'}) do
        lines[#lines+1]=fill(r[k])
    end
    local s=w.summary
    for _,k in ipairs({'stopped','waiting','held','rejoin','none','alone','connecting','hosting','guest'}) do
        lines[#lines+1]=fill(s[k])..fill(s.paused)..s.lost -- Paused and lost added to each, beyond what can happen.
    end
    return lines
end
-- Columns a word takes: an East Asian wide character two, a combining mark none, any other one.
local function columns(s)
    local n=0
    for _,c in utf8.codes(s) do
        if c>=0x1100 and c<=0x115F or c>=0x2E80 and c<=0xA4CF or c>=0xAC00 and c<=0xD7A3 or c>=0xF900 and c<=0xFAFF
            or c>=0xFE30 and c<=0xFE4F or c>=0xFF00 and c<=0xFF60 or c>=0xFFE0 and c<=0xFFE6 then n=n+2
        elseif not (c>=0x300 and c<=0x36F or c>=0x64B and c<=0x65F or c==0x670 or c==0xE31 or c>=0xE34 and c<=0xE3A
            or c>=0xE47 and c<=0xE4E) then n=n+1 end
    end
    return n
end
assert(columns('Ab')==2 and columns('日本')==4 and columns('한')==2 and columns('กิ')==1 and columns('é')==1)
-- The menu's columns (ui/menu.lua's rows, 1452 units wide, their value in the last 600; ui/kit.lua's row puts the label
-- 36 units in; Bold 40, about 23 units a column in the game's Latin face, a CJK character about two): a value within
-- its 600 units, a label within the 792 units from its start to 24 units before the value, a key hint within its
-- 320-unit cell after the 78 units of its icon (Bold 30, about 17 units a column).
local UNIT,ROW,CELL,GAP=23,1452,600,24
local LABEL,VALUE,HINT=(ROW-CELL-36-GAP)//UNIT,CELL//UNIT,14 -- 34 and 26.
local function fits(at,text,most) assert(columns(text)<=most,at..': '..columns(text)..' columns, at most '..most) end
for name in pairs(R.TEXT) do
    local w=T.pick(name)
    for _,line in ipairs(notices(w)) do assert(Chat.clean(line)==line,name..': '..#line..' bytes or a control: '..line) end
    for k,text in pairs(w.row) do fits(name..'.row.'..k,text:format(('W'):rep(16)..'...'),LABEL) end
    for k,text in pairs(w.head) do fits(name..'.head.'..k,text,LABEL) end
    for k,text in pairs(w.value) do fits(name..'.value.'..k,text,VALUE) end
    for _,text in ipairs({w.no_limit,w.minutes:format(30),w.seconds:format(30),w.percent:format(250),w.press}) do
        fits(name..' value',text,VALUE)
    end
    for k,text in pairs(w.hint) do fits(name..'.hint.'..k,text,HINT) end
    -- The co-op saves' question (session/saves.lua): its text within 5 body rows of 78 columns, as each phase shows it,
    -- the question with the invite line a held invite adds.
    local s=w.saves
    for _,texts in ipairs({{s.new,s.new_about,s.invite},{s.old,s.old_about,s.invite},{s.failed,s.see_log..'.'}}) do
        local rows=0
        for _,text in ipairs(texts) do rows=rows+#Chat.wrap(text,78) end
        assert(rows<=5,name..'.saves: '..rows..' rows, at most 5: '..texts[1])
    end
    -- Night Operation's card (nightop/run.lua: 1040 units wide, 24 in from each side; title Bold 36, its line Bold 40,
    -- about 23 units a column), with the longest numbers (Gauntlet's 12:00); its result panel: the heading Bold 56
    -- (about 32 units a column), the line under it and the row labels Mideum 34 (18 units a column, as the feed's) from
    -- 96 units in, a label before its value's 5 Bold 40 columns at the right end.
    local n=w.night
    fits(name..'.night.title',n.title,43)
    fits(name..'.night.waiting',n.waiting,43)
    fits(name..'.night.starts',n.starts:format(5),43)
    for _,head in ipairs({n.wave:format(5,5),n.next:format(10)}) do
        fits(name..'.night line',head..'  12:00  '..n.score:format(9999),43)
    end
    -- A challenge's name as the card's title; the Best row's label before a value of up to 11 Bold 40 columns
    -- ('9999  12:00', 24 units apart: 31 columns); the record and stop lines under the heading.
    local c=w.challenge
    for _,def in ipairs(C.LIST) do fits(name..'.challenge.names.'..def.id,c.names[def.id],43) end
    fits(name..'.challenge.best',c.best,31)
    fits(name..'.challenge.record',c.record,54)
    fits(name..'.challenge.stopped',c.stopped,54)
    fits(name..'.night.success',n.success,31)
    fits(name..'.night.fail',n.fail,31)
    for _,text in ipairs({n.died,n.time_up,n.mate_died,n.you_died}) do fits(name..'.night: '..text,text,54) end
    for k,text in pairs(n.why) do fits(name..'.night.why.'..k,text,54) end
    for _,k in ipairs({'waves','kills','points','time'}) do fits(name..'.night.'..k,n[k],40) end
    -- The co-op line (ui/menu.lua): the booth hint's word after the longest menu key name, within the hint's 700 units;
    -- each sentence in the menu's note (the status style, 78 columns as the saves' question's body) with a 32-byte
    -- name, and within the feed's line.
    fits(name..'.line.prompt','Shift+F12  '..w.line.prompt,700//UNIT)
    for _,k in ipairs({'free','open','linked'}) do
        local text=fill(w.line[k])
        fits(name..'.line.'..k,text,78)
        assert(Chat.clean(text)==text,name..'.line.'..k..': '..#text..' bytes or a control')
    end
    -- The status strip above the partner card: its second row with every fact at two-digit counts and 60 poses a
    -- second, uncut, within its columns.
    local o=w.overlay
    local all=table.concat({o.enemies:format(16),o.place:format(16),o.quests,o.rate:format(60)},' · ')
    local second=select(3,P.status_rows(w,{mode='detailed',summary='',fight='fight=on mode=on role=host enemies=16',
        pilot='pilot=on piloted=16 owned=8 drawn=8',quests='quests=on mode=on role=host',rate=60}))
    assert(second==all,name..'.overlay: cut to '..tostring(second))
    fits(name..'.overlay',all,P.COLS)
    -- Every state's status line in the strip: the line less one prefix, the same in each (summary.none's, up to its
    -- colon), its placeholders kept.
    local S,cut=P.short(w).summary,nil
    for _,k in ipairs({'stopped','waiting','held','rejoin','none','alone','connecting','hosting','guest'}) do
        local full=w.summary[k]
        assert(#S[k]<#full and full:sub(-#S[k])==S[k] and specs(S[k])==specs(full),name..'.summary.'..k..': '..S[k])
        cut=cut or #full-#S[k]
        local prefix=full:sub(1,cut)
        assert(#full-#S[k]==cut and (prefix:find(':%s*$') or prefix:find('：$')),name..'.summary.'..k..': '..prefix)
    end
    local lead=w.partner.lost..' · '..o.paused
    local top=P.status_rows(w,{mode='compact',summary=S.hosting:format(NAME),lost=true,paused=true,rate=60})
    assert(top:sub(1,#lead)==lead,name..'.overlay.paused: cut to '..top)
    -- The race (race/run.lua): its panel as the night card (title, then the time, CP, LAP and POS two spaces apart, or
    -- the wait for her name of 20 characters and an ellipsis); the marker's label over your start (Bold 30, 17 units a
    -- column in 320); a banner (Bold 56, 32 units a column, in 1600 less 24 a side); the results as the night panel,
    -- the heading, the flags line under it, and two rows: the place and a name of 21 columns at the left (Mideum 34),
    -- the time or DNF at the right (Bold 40) in 14 columns.
    local r=w.race
    fits(name..'.race.title',r.title,43)
    fits(name..'.race line','9:59.99  '..r.cp:format(64,64)..'  '..r.lap:format(9,9)..'  '..r.pos:format(2,2),43)
    fits(name..'.race.waiting',r.waiting:format(('W'):rep(20)..'…'),43)
    fits(name..'.race.slot',r.slot,18)
    for _,k in ipairs({'go','wrong_way','finished','dnf'}) do fits(name..'.race.'..k,r[k],48) end
    fits(name..'.race.missed',r.missed:format(64),48)
    fits(name..'.race.results',r.results,31)
    fits(name..'.race flags',r.fast..' · '..r.pause,54)
    for _,who in ipairs({w.chat.you,w.chat.partner,('W'):rep(20)..'…'}) do fits(name..'.race row: '..who,'2  '..who,27) end
    fits(name..'.race.dnf value',r.dnf,14)
end
-- Thai writes a leading vowel (U+0E40 to U+0E44) before its consonant: no word ends on one.
local function thai(t,at)
    for k,v in pairs(t) do
        if type(v)=='table' then thai(v,at..k..'.')
        elseif v~='' then
            local last=utf8.codepoint(v,utf8.offset(v,-1))
            assert(not (last>=0xE40 and last<=0xE44),at..k..' ends on a leading vowel')
        end
    end
end
if T.th then thai(T.th,'th.') end
print('ui_text_test ok')
