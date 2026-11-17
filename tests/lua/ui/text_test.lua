-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
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
-- without its prefix, the race's panel, marker, banner and results within theirs, the lobby menu's rows, settings,
-- values and status within their columns and its waiting-room notice within 200 bytes, Find a session's hints, status
-- lines, version and footer within theirs, Create a session's title, rules header, Start row and right-pane words
-- within theirs; no Thai word that ends on a leading vowel; each join Steam refused as link/core.h words it, in every language; the DLC notice (T.dlcs) within
-- 200 bytes with 100-byte DLC names in every language; its English as main.lua says it.
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
    for _,group in ipairs({'fight','spawns','group','ghost','refused','quests','world','travel','ue4ss',
        'join_refused'}) do
        for _,text in pairs(w[group]) do lines[#lines+1]=fill(text) end
    end
    lines[#lines+1]=w.fight.on:format(16)..' '..w.fight.scale:format(200,200) -- The longest on.
    -- The DLC notice (T.dlcs): one sentence or both, with short names and with names of link/protocol.h's kMaxDlcName.
    local long,short={('d'):rep(100),('e'):rep(100),('f'):rep(100)},{'Twin Expansion Pack','NieR:Automata','x'}
    for _,two in ipairs({{long,long},{short,short},{long,{}},{{},long},{short,long},{long,short}}) do
        lines[#lines+1]=T.dlcs(w,NAME,two[1],two[2])
    end
    local p=w.pilot
    for _,text in ipairs({p.on:format(16),p.one,p.off:format(p.stopped),p.off:format(fill(p.host))}) do
        lines[#lines+1]=text
    end
    for _,text in ipairs({w.saves.on,fill(w.saves.off),w.saves.off:format(w.saves.see_log),w.saves.build,
        w.saves.manual:format('4','4'),w.chat.no_session,w.chat.alone,
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
    -- The SBO lobby's notices (session/sbo.lua): the save before the entry, each refusal and each failure.
    lines[#lines+1]=w.sbo.saving
    for _,group in ipairs({'no','fail'}) do
        for _,text in pairs(w.sbo[group]) do lines[#lines+1]=text end
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
    -- The hall lobby seats' hint, in the same place: Sit near a free seat, Stand up while EVE sits.
    fits(name..'.sit','Shift+F12  '..w.sit,700//UNIT)
    fits(name..'.stand','Shift+F12  '..w.stand,700//UNIT)
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
    -- The lobby menu (mockup B, ui/lobby.lua): a row and the mode's name within B's row box (Bold 55 in 512 units, 18
    -- columns), the code row with a join code; a setting's title in C within 32 columns, Mute with a name cut as
    -- Join.name cuts it; a value within 40, with a join code, a long version and protocol 20; the status line within
    -- 40 (Mideum 36, about 19 units a column, ends before the members box at x 2660) at 8 of 8 and a 10 s countdown;
    -- the waiting room's notice with its key within the feed's line.
    for k,text in pairs(w.lobby.row) do fits(name..'.lobby.row.'..k,text:format('ABC-1234'),18) end
    fits(name..'.lobby.mode.ffa',w.lobby.mode.ffa,18)
    for k,text in pairs(w.lobby.set) do fits(name..'.lobby.set.'..k,text:format(('W'):rep(16)..'...'),32) end
    for k,text in pairs(w.lobby.val) do
        fits(name..'.lobby.val.'..k,text:format(k=='version' and 'v0.9.0-99-gabcdef12' or 'ABC-1234',20),40)
    end
    for k,text in pairs(w.lobby.status) do fits(name..'.lobby.status.'..k,text:format(k=='start' and 10 or 8,8),40) end
    local room=w.lobby.room:format('F5')
    assert(Chat.clean(room)==room,name..'.lobby.room: '..#room..' bytes or a control')
    -- Find a session (ui/sessions.lua): a key hint's label within the 420 units between two hints less the icon
    -- (Bold 30, 17 units a column); a status line on one line of the list's 1600 units (Bold 36, about 21 units a
    -- column); the version in the details pane on one line of its 1040 units (Mideum 34, 18 units a column), with a
    -- two-digit protocol and an 8-digit build; the footer within two lines of 2200 units (Mideum 30, 16 units a column).
    local ss=w.sessions
    for _,k in ipairs({'ask','refresh'}) do fits(name..'.sessions.'..k,ss[k],20) end
    for _,k in ipairs({'empty','failed','idle'}) do fits(name..'.sessions.'..k,ss[k],76) end
    fits(name..'.sessions.wait',ss.wait:format(5),76)
    fits(name..'.sessions.friend',ss.friend,57)
    fits(name..'.sessions.version',ss.version:format('22','26123051'),57)
    fits(name..'.sessions.footer',ss.footer:format('22','26123051'),2*2200//16)
    -- Create a session (ui/create.lua): its page title at the top right within 40 columns (Mideum 34, 18 units a
    -- column); the rules header and the Start row within a setting's title column on C (32); a locked row's reason and
    -- each Who can join word within four lines of the right pane's 1040 units (57 columns a line).
    local cr=w.create
    fits(name..'.create.title',cr.title,40)
    fits(name..'.create.rules',cr.rules,32)
    fits(name..'.create.start',cr.start,32)
    fits(name..'.create.locked',cr.locked,4*57)
    for k,text in pairs(cr.who) do fits(name..'.create.who.'..k,text,4*57) end
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

-- A join Steam refused: link/core.h's join_refusal() gives the English lines T.en.join_refused holds and no other.
-- Any other number gets T.en's other words. T.join_refused gives each in every language's words; any other notice
-- gets nil.
local src=io.open('native/src/link/core.h'):read('a')
local body=src:match('inline std::string join_refusal%(uint32_t response%) {(.-)\n}\n')
assert(body,'link/core.h: no join_refusal()')
local native,en={},T.en.join_refused
for line in body:gmatch('return "([^"]*)";') do native[line]=true end
for key,text in pairs(en) do assert(key=='other' or native[text],'link/core.h lacks T.en.join_refused.'..key) end
for line in pairs(native) do
    local found=false
    for _,text in pairs(en) do found=found or text==line end
    assert(found,'T.en.join_refused lacks "'..line..'"')
end
local head,tail=en.other:match('^(.*)%%d(.*)$')
assert(body:find('return "'..head..'" + std::to_string(response) + "'..tail..'";',1,true),'link/core.h: other')
for name,w in pairs(T) do
    if type(w)=='table' then
        w=T.pick(name)
        for key,text in pairs(en) do
            if key~='other' then assert(T.join_refused(text)(w)==w.join_refused[key],name..'.'..key) end
        end
        assert(T.join_refused(en.other:format(12))(w)==w.join_refused.other:format(12),name..'.other')
        assert(T.join_refused(en.other:format(4294967295))(w)==w.join_refused.other:format(4294967295),name)
    end
end
assert(T.join_refused(en.full)(T.pick('fr-FR'))=='Impossible de rejoindre : cette partie est complète.')
assert(T.join_refused(en.other:format(16))(T.en)=='Could not join: Steam response 16.')
for _,text in ipairs({'Kaanta joined.','Could not join: Steam response .','Could not join: Steam response -1.',
    'Could not join: Steam response 5. ','x'..en.full,'Could not join: unknown match mode tdm.',en.other}) do
    assert(T.join_refused(text)==nil,text)
end
-- The DLC notice: hers we lack, then ours she lacks, in one notice; the names that fit, (+n) for the others; the first
-- sentence leaves the second room for its count; one sentence when a list is empty.
local DLC_THEIRS,DLC_YOURS="Kaanta has DLCs you don't have: ","You have DLCs Kaanta doesn't have: "
assert(T.dlcs(T.en,'Kaanta',{'Alpha','Beta','Gamma'},{'Delta'})==DLC_THEIRS..'Alpha, Beta (+1). '..DLC_YOURS..'Delta.')
assert(T.dlcs(T.en,'Kaanta',{},{'Delta','Epsilon'})==DLC_YOURS..'Delta, Epsilon.')
assert(T.dlcs(T.en,'Kaanta',{'Alpha'},{})==DLC_THEIRS..'Alpha.')
local hundred,other=('a'):rep(100),('b'):rep(100)
assert(T.dlcs(T.en,'Kaanta',{hundred},{other})==DLC_THEIRS..hundred..'. '..DLC_YOURS..'(+1).')
assert(T.dlcs(T.fr,'Kaanta',{'Alpha'},{'Delta'})=="Kaanta a des DLC que vous n'avez pas : Alpha. Vous avez des DLC que "
    .."Kaanta n'a pas : Delta.")
-- Her name at link/protocol.h's kMaxName (64 bytes, 32 Cyrillic letters) in both sentences: cut at a character's
-- start in every language until both counts fit, so the feed's 200 bytes never cut the second sentence.
local LONG_NAME=('Ж'):rep(32)
for lang,w in pairs(T) do
    if type(w)=='table' and w.dlc then
        local line=T.dlcs(w,LONG_NAME,{hundred},{other})
        assert(#line<=200 and utf8.len(line) and Chat.clean(line)==line,lang..': '..line)
        assert(select(2,line:gsub('%(%+1%)',''))==2,lang..': '..line)
    end
end
assert(T.dlcs(T.en,LONG_NAME,{'Alpha'},{'Delta'}):find(LONG_NAME,1,true),'A name that fits stays whole')
print('ui_text_test ok')
