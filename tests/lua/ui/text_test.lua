-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- ui/text.lua, pure (no fakes): a language's table only under one of the 23 culture names
-- ui/text/culture.lua's culture() gives, and either empty or with exactly T.en's keys at every
-- level, each word with T.en's format placeholders in T.en's order (Lua's format has no positional arguments; a percent
-- sign, %%, may stand anywhere, as Turkish puts it first); T.pick's choice (the game's culture through culture(),
-- English with ui_language=english, for a culture with no table and for a word a table lacks); in every language, every
-- notice within the feed's 200 bytes a line (Chat.clean) with a 32-byte name, every menu row, value and key hint within
-- its column, the co-op saves' question, with its invite line, within its 5 rows (Chat.wrap), Night Operation's card
-- and result panel within their columns, the challenges' words: a name for each of
-- online/modes/nightop/challenges.lua's ids, as the card's title, the Best row and the lines under the heading within
-- their columns, the notices with the longest name within 200 bytes (the co-op one with a partner's 32-byte name too),
-- the co-op line's hint and sentences within theirs, the status strip's rows (online/partner/hud.lua): the second with
-- every fact within its columns, the top one with its connection lost and paused words whole before the status line,
-- which comes without its prefix, the race's panel, marker, banner and results within theirs, the lobby menu's rows,
-- settings, values and status within their columns and its waiting-room notice within 200 bytes, Find a session's
-- hints, status lines, version and footer within theirs, Create a session's title, rules header, Start row and
-- right-pane words within theirs, the fishing tournament's corner board and result panel within theirs and its
-- notices with 32-byte names within 200 bytes, the photo hunt's card and result panel within theirs and its notices
-- with 32-byte names, the longest place and the longest target names within 200 bytes, the pause menu's Online tab
-- word within its tab and its notice within 200 bytes; no Thai word that ends on a leading vowel; each join Steam
-- refused as link/core.h words it, in every language; the DLC notice (T.dlcs) within 200 bytes with 100-byte DLC names
-- in every language; its English as main.lua says it; the New Game+ notice (T.cycle) within 200 bytes with every
-- count word and difficulty on both sides; its English; the bike's refusals with each side word and a six-digit
-- distance or another map's 32-byte name, the paid fetch's offer after them with the longest key name and betacrystal,
-- the fetch's other lines with a 32-byte money name, within 200 bytes; coop gift's notices with a 32-byte name and
-- alias within 200 bytes; the 25 module names in every table; the notice
-- of a module that failed to load with the longest of them within 200 bytes.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local T=require('ui.text')
local R=require('online.modes.nightop.recruiter_text')
local Chat=require('core.line')
local C=require('online.modes.nightop.challenges')
local P=require('online.partner.hud')
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
-- Every one of the 22 tables names the ghost's drone, sounds and faces rows.
for culture,t in pairs(T) do if type(t)=='table' and t.row and t.row.dyes then
    assert(type(t.row.drone)=='string' and type(t.row.sounds)=='string' and type(t.row.faces)=='string',culture) end end
-- The modules' names for the off notice: exactly T.en's 26 keys in every table (tests/tools/modules_test.py checks
-- them against main.lua's MODULES).
local MODULE_KEYS=0
for _ in pairs(T.en.modules) do MODULE_KEYS=MODULE_KEYS+1 end
assert(MODULE_KEYS==26,'T.en.modules: '..MODULE_KEYS..' names')
for name,t in pairs(T) do
    if type(t)=='table' and next(t) then
        local n=0
        for k,v in pairs(t.modules) do n=n+1; assert(type(v)=='string' and T.en.modules[k],name..'.modules.'..k) end
        assert(n==MODULE_KEYS,name..'.modules: '..n..' names')
    end
end
-- A challenge name for each challenge, and no other.
local ids={}
for _,def in ipairs(C.LIST) do
    ids[def.id]=true
    assert(type(T.en.challenge.names[def.id])=='string','T.en.challenge.names.'..def.id..': missing')
end
for id in pairs(T.en.challenge.names) do assert(ids[id],'T.en.challenge.names.'..id..': no such challenge') end
-- A word for each Options row and head (ui/kit/model.lua's OPTIONS; ui/kit/menu.lua labels a row with row[id or key]).
for _,row in ipairs(require('ui.kit.model').OPTIONS) do
    if row.head then assert(type(T.en.head[row.head])=='string','T.en.head.'..row.head..': missing')
    else assert(type(T.en.row[row.id or row.key])=='string','T.en.row.'..(row.id or row.key)..': missing') end
end

-- The pick: the game's culture as culture() names it, else English.
assert(T.pick('fr-FR')==T.fr and T.pick('FR')==T.fr and T.pick('fr-FR','game')==T.fr)
assert(T.pick('fr-FR','english')==T.en and T.pick(nil)==T.en and T.pick('xx-YY')==T.en and T.pick('en-US')==T.en)
for name in pairs(R.TEXT) do assert(T.pick(name)==(T[name] or T.en),name) end
-- ui/text/culture.lua's CULTURES: exactly the guard's TEXT cultures.
local CULTURES=require('ui.text.culture').CULTURES
for name in pairs(R.TEXT) do assert(CULTURES[name]==true,name..': not in CULTURES') end
for name in pairs(CULTURES) do assert(R.TEXT[name],name..': not a culture of the guard\'s TEXT') end
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
-- The lines that go to the feed, as main.lua, online/partner/puppet.lua, online/saves/saves.lua, core/link.lua,
-- online/session/join.lua and cutmenus/mailbox.lua put them together.
local function notices(w)
    local lines={}
    for _,group in ipairs({'fight','spawns','group','ghost','refused','quests','world','story','travel','ue4ss',
        'join_refused','bike','gun','gift'}) do
        for _,text in pairs(w[group]) do if text~=w.group.places then lines[#lines+1]=fill(text) end end
    end
    -- A member in a solo area (online/group/group.lua): each place with a 32-byte name.
    for _,place in pairs(w.group.places) do lines[#lines+1]=w.group.solo:format(NAME,place) end
    -- The bike's refusals (vehicles/bike/ride.lua) with the paid fetch's offer after them, as its mount joins them:
    -- each side word with a six-digit distance (positions reach 10,000,000 cm), another map with a 32-byte name; the
    -- offer with the longest key name (Shift+F12, as long as coop bike when bike_key is none) and betacrystal, the word
    -- ride.lua puts when SB's name would pass 200 bytes (fill gives the other fetch lines a 32-byte name, fetch.lua's
    -- NAME_MAX).
    local offer=w.bike.offer:format('Shift+F12',500,'betacrystal')
    for _,side in ipairs({'ahead','behind','left','right'}) do
        lines[#lines+1]=w.bike.far:format(999999,w.bike[side])..' '..offer
    end
    lines[#lines+1]=w.bike.other_map:format(NAME)..' '..offer
    lines[#lines+1]=w.fight.on:format(16)..' '..w.fight.scale:format(200,200) -- The longest on.
    -- The DLC notice (T.dlcs): one sentence or both, with short names and with names of link/protocol.h's kMaxDlcName.
    local long,short={('d'):rep(100),('e'):rep(100),('f'):rep(100)},{'Twin Expansion Pack','NieR:Automata','x'}
    for _,two in ipairs({{long,long},{short,short},{long,{}},{{},long},{short,long},{long,short}}) do
        lines[#lines+1]=T.dlcs(w,NAME,two[1],two[2])
    end
    -- The New Game+ notice (T.cycle): a first playthrough and New Game+ 99, each difficulty, on both sides.
    for _,a in ipairs({0,99}) do for _,b in ipairs({0,99}) do for d=0,2 do for e=0,2 do
        lines[#lines+1]=T.cycle(w,NAME,{count=a,difficulty=d},{count=b,difficulty=e})
    end end end end
    local p=w.pilot
    for _,text in ipairs({p.on:format(16),p.one,p.off:format(p.stopped),p.off:format(fill(p.host))}) do
        lines[#lines+1]=text
    end
    for _,text in ipairs({w.saves.on,fill(w.saves.off),w.saves.off:format(w.saves.see_log),w.saves.build,
        w.saves.manual:format('4','4'),w.chat.no_session,w.chat.alone,
        w.chat.off,w.chat.ui_off,w.join.bad}) do lines[#lines+1]=text end
    -- Night Operation's notices (online/modes/nightop/run.lua, with the UI off): the start, a wave, a clear, the end
    -- and why; for two players, her notice of his start (with each level's word) and his of each refusal, and whose
    -- EVE died; the points a run
    -- earned, or could not credit; a level picked from Roxanne, by the host or alone and by a guest
    -- (online/modes/nightop/roxanne.lua); the shop's screen that could not open (online/modes/nightop/shop.lua).
    local n=w.night
    for _,text in ipairs({n.start_notice:format(5),n.wave_notice:format(5,5),n.clear_notice:format(5),n.died,
        n.time_up,n.end_notice:format(n.success,5,5,20,9999,'8:00'),n.end_notice:format(n.fail,5,5,20,9999,'8:00'),
        n.mate_died,n.you_died,n.earned:format(42,999999999),n.unpaid,n.booked,
        n.host_only,n.shop_failed}) do
        lines[#lines+1]=text
    end
    for _,text in pairs(n.why) do lines[#lines+1]=text end
    for _,text in pairs(n.refuse) do lines[#lines+1]=n.refused:format(NAME,text) end
    for _,level in pairs(n.levels) do lines[#lines+1]=n.coop_notice:format(NAME,level,5) end
    -- A challenge's notices, with its longest name in this language, and the lines under its result.
    local c,long=w.challenge,''
    for _,def in ipairs(C.LIST) do if #c.names[def.id]>#long then long=c.names[def.id] end end
    for _,text in ipairs({c.start_notice:format(long,5),c.wave_notice:format(long,8,8),c.clear_notice:format(long,8),
        c.record,c.stopped,c.coop_notice:format(long,NAME,5)}) do
        lines[#lines+1]=text
    end
    -- Score attack's notices (online/modes/scoreattack/ui/board.lua, game.lua): each sit-out, a round without a
    -- ranking, and with the UI off our run's end (the longest challenge name and end word, 9999 points, 12:00.0) and
    -- our place.
    local sa,ending=w.scoreattack,''
    for _,text in pairs(sa.ending) do if #text>#ending then ending=text end end
    for _,text in pairs(sa.out) do lines[#lines+1]=text end
    for _,text in ipairs({sa.host_left,sa.cancelled,sa.unranked,sa.end_notice:format(long,ending,9999,'12:00.0'),
        sa.placed:format(8,8)}) do
        lines[#lines+1]=text
    end
    -- The fishing tournament's notices (online/modes/fishing/ui/board.lua): the start with a 32-byte name and 60
    -- minutes, each sit-out, a tournament without a ranking, a reloaded game; with the UI off GO, our place and points,
    -- our end, the first three with 32-byte names and 6-digit points (a catch scores 450 at most, one each 2 s for an
    -- hour), our place, Not ranked and a new personal best.
    local f=w.fishing
    for _,text in pairs(f.out) do lines[#lines+1]=text end
    local entry=f.entry:format(8,NAME,999999)
    for _,text in ipairs({f.start:format(NAME,60),f.host_left,f.cancelled,f.reloaded,f.norank,f.unranked,f.best,
        f.go:format(60),f.standing:format(8,999999),f.end_notice:format(999999,9999),
        f.top:format(table.concat({entry,entry,entry},f.sep)),f.placed:format(8,8)}) do
        lines[#lines+1]=text
    end
    -- The photo hunt's notices (online/modes/photohunt/ui/board.lua): the start with a 32-byte name, the longest place
    -- (another world's among them: the longest alias of core/worlds.lua, as targets.lua takes a world from there only),
    -- the three longest target names with two-digit numbers and 60 minutes; the Camera's; a target taken by a 32-byte
    -- name or by us; each sit-out and each stop of the photo checks; a photo hunt without a ranking; a reloaded game;
    -- each shot's words with the longest target (taken with a 32-byte name); with the UI off GO, our end (3 points or
    -- 1), the first three with 32-byte names, our place, Not ranked, the no-ranking note and a new personal best.
    local ph=w.photohunt
    local targets,place,alias={},'',''
    for _,k in ipairs({'memory','cat','butterfly','fish'}) do targets[#targets+1]=ph[k]:format(99) end
    table.sort(targets,function(a,b) return #a>#b end)
    for k in pairs(require('core.worlds')) do if #k>#alias then alias=k end end
    for k,text in pairs(ph.places) do
        text=k=='other' and text:format(alias) or text
        if #text>#place then place=text end
    end
    for _,group in ipairs({'out','stopped','shot'}) do
        for k,text in pairs(ph[group]) do lines[#lines+1]=text:format(targets[1],NAME) end
    end
    local pentry=ph.entry:format(8,NAME,3)
    for _,text in ipairs({ph.start:format(NAME,place,table.concat({targets[1],targets[2],targets[3]},ph.sep),60),
        ph.camera,ph.took:format(NAME,targets[1]),ph.you_took:format(targets[1]),ph.host_left,ph.cancelled,
        ph.reloaded,ph.norank,ph.unranked,ph.best,ph.go:format(60),ph.end_notice:format(3),ph.one.end_notice,
        ph.top:format(table.concat({pentry,pentry,pentry},ph.sep)),ph.placed:format(8,8)}) do
        lines[#lines+1]=text
    end
    -- The race's notices (online/modes/race/run.lua): its banners too, which come as notices with the UI off; a match
    -- round's (online/modes/race/match/game.lua).
    local r=w.race
    for _,group in ipairs({'why','refused','declined','match'}) do
        for _,text in pairs(r[group]) do lines[#lines+1]=fill(text) end
    end
    for _,k in ipairs({'armed','armed_guest','false_start','cancelled','out','recording','dropped','too_close','full',
        'other_map','saved','go','wrong_way','missed','finished','dnf','best','unranked'}) do
        lines[#lines+1]=fill(r[k])
    end
    lines[#lines+1]=r.placed:format(8,8) -- A match round's place with the UI off.
    local s=w.summary
    for _,k in ipairs({'stopped','waiting','held','rejoin','none','alone','connecting','hosting','guest'}) do
        lines[#lines+1]=fill(s[k])..fill(s.paused)..s.lost -- Paused and lost added to each, beyond what can happen.
    end
    -- The SBO lobby's notices (online/lobby/sbo.lua): the save before the entry, each refusal and each failure.
    lines[#lines+1]=w.sbo.saving
    for _,group in ipairs({'no','fail'}) do
        for _,text in pairs(w.sbo[group]) do lines[#lines+1]=text end
    end
    -- The notice of a module that failed to load (main/pass.lua), with this table's longest module name.
    local longest=''
    for _,name in pairs(w.modules) do if #name>#longest then longest=name end end
    lines[#lines+1]=w.module_off:format(longest)
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
-- The menu's columns (ui/kit/menu.lua's rows, 1452 units wide, their value in the last 600; ui/kit/kit.lua's row puts
-- the label 36 units in; Bold 40, about 23 units a column in the game's Latin face, a CJK character about two): a value
-- within its 600 units, a label within the 792 units from its start to 24 units before the value, a key hint within its
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
    -- The co-op saves' question (online/saves/saves.lua): its text within 5 body rows of 78 columns, as each phase
    -- shows it, the question with the invite line a held invite adds.
    local s=w.saves
    for _,texts in ipairs({{s.new,s.new_about,s.invite},{s.old,s.old_about,s.invite},{s.failed,s.see_log..'.'}}) do
        local rows=0
        for _,text in ipairs(texts) do rows=rows+#Chat.wrap(text,78) end
        assert(rows<=5,name..'.saves: '..rows..' rows, at most 5: '..texts[1])
    end
    -- Night Operation's card (online/modes/nightop/run.lua: 1040 units wide, 24 in from each side; title Bold 36, its
    -- line Bold 40, about 23 units a column), with the longest numbers (Gauntlet's 12:00); its result panel: the
    -- heading Bold 56 (about 32 units a column), the line under it and the row labels Mideum 34 (18 units a column, as
    -- the feed's) from 96 units in, a label before its value's 5 Bold 40 columns at the right end.
    local n=w.night
    fits(name..'.night.title',n.title,43)
    for k,level in pairs(n.levels) do fits(name..'.night.title_level '..k,n.title_level:format(level),43) end
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
    -- The co-op line (ui/kit/menu.lua): the booth hint's word after the longest menu key name, within the hint's 700
    -- units; each sentence in the menu's note (the status style, 78 columns as the saves' question's body) with a
    -- 32-byte name, and within the feed's line.
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
    -- The race (online/modes/race/run.lua): its panel as the night card (title, then the time, CP, LAP and POS two
    -- spaces apart, or the wait for her name of 20 characters and an ellipsis); the marker's label over your start
    -- (Bold 30, 17 units a column in 320); a banner (Bold 56, 32 units a column, in 1600 less 24 a side); the results
    -- as the night panel, the heading, the flags line under it, a match round's note under them (Mideum 34, 54 columns
    -- as score attack's) and 8 rows: the place and a name of 21 columns at the left (Mideum 34), the time or DNF at the
    -- right (Bold 40) in 14 columns. POS counts up to 8 racers.
    local r=w.race
    fits(name..'.race.title',r.title,43)
    fits(name..'.race line','9:59.99  '..r.cp:format(64,64)..'  '..r.lap:format(9,9)..'  '..r.pos:format(8,8),43)
    fits(name..'.race.waiting',r.waiting:format(('W'):rep(20)..'…'),43)
    fits(name..'.race.slot',r.slot,18)
    for _,k in ipairs({'go','wrong_way','finished','dnf'}) do fits(name..'.race.'..k,r[k],48) end
    fits(name..'.race.missed',r.missed:format(64),48)
    fits(name..'.race.results',r.results,31)
    fits(name..'.race flags',r.fast..' · '..r.pause,54)
    for _,k in ipairs({'still','best','unranked'}) do fits(name..'.race.'..k,r[k]:format(7),54) end
    for _,who in ipairs({w.chat.you,w.chat.partner,('W'):rep(20)..'…'}) do fits(name..'.race row: '..who,'2  '..who,27) end
    fits(name..'.race.dnf value',r.dnf,14)
    -- The lobby menu (mockup B, online/lobby/ui/lobby.lua): a row and the mode's name within B's row box (Bold 55 in
    -- 512 units, 18 columns), the code row with a join code; a setting's title in C within 32 columns, Mute with a name
    -- cut as Join.name cuts it; a value within 40, with a join code, a long version and protocol 20; the status line
    -- within 40 (Mideum 36, about 19 units a column, ends before the members box at x 2660) at 8 of 8 and a 10 s
    -- countdown; the waiting room's notice with its key within the feed's line.
    for k,text in pairs(w.lobby.row) do fits(name..'.lobby.row.'..k,text:format('ABC-1234'),18) end
    for k,text in pairs(w.lobby.mode) do fits(name..'.lobby.mode.'..k,text,18) end
    for k,text in pairs(w.lobby.set) do fits(name..'.lobby.set.'..k,text:format(('W'):rep(16)..'...'),32) end
    for k,text in pairs(w.lobby.val) do
        fits(name..'.lobby.val.'..k,text:format(k=='version' and 'v0.9.0-99-gabcdef12' or 'ABC-1234',20),40)
    end
    for k,text in pairs(w.lobby.status) do fits(name..'.lobby.status.'..k,text:format(k=='start' and 10 or 8,8),40) end
    -- Score attack's screens (online/modes/scoreattack/ui/board.lua, 1040 units wide as Night Operation's card): an
    -- in-round board row (Mideum 34, 18 units a column, 64 units in from each side), the place and a cut name
    -- (Join.name: 16 characters and '...') at the left, 24 columns, then the score and the wave or end word at the
    -- right within 26; the result panel's heading (a challenge's name, Bold 56, 31 columns as the night panel's), the
    -- line under it with the longest end word, 9999 points and 12:00.0, and each note, within 54 (Mideum 34); a ranking
    -- row's difficulty within its 10 columns (Mideum 30, right-aligned between the name and the value).
    local sa,ending=w.scoreattack,''
    for k,text in pairs(sa.ending) do
        fits(name..'.scoreattack.ending.'..k,'9999  '..text,26)
        if columns(text)>columns(ending) then ending=text end
    end
    fits(name..'.scoreattack.wave','9999  '..sa.wave:format(9,9),26)
    for _,def in ipairs(C.LIST) do fits(name..'.challenge.names.'..def.id..' heading',c.names[def.id],31) end
    fits(name..'.scoreattack.mine',sa.mine:format(ending,9999,'12:00.0'),54)
    for _,k in ipairs({'waiting','unranked','host_left','cancelled'}) do
        fits(name..'.scoreattack.'..k,sa[k]:format(8),54)
    end
    for _,k in ipairs({'normal','story','hard'}) do fits(name..'.cycle.'..k,w.cycle[k],10) end
    -- The fishing tournament's screens (online/modes/fishing/ui/board.lua): the corner board's title line (Bold 36,
    -- about 21 units a column, 32 units in from each side of its 720: 31 columns) with the countdown, the longest
    -- time left (60:00) or Time up; the result panel's heading (Bold 56, 31 columns as score attack's), the line
    -- under it with 6-digit points and 4-digit fish and each note within 54 (Mideum 34); a ranking row's fish within
    -- the 16 columns between the name and the points (Mideum 30, 16 units a column, right-aligned at 780).
    local fi=w.fishing
    for _,clock in ipairs({fi.count:format(5),'60:00',fi.up}) do fits(name..'.fishing.head',fi.head..'  '..clock,31) end
    fits(name..'.fishing.title',fi.title,31)
    fits(name..'.fishing.mine',fi.mine:format(999999,9999),54)
    for _,k in ipairs({'waiting','unranked','best','norank'}) do fits(name..'.fishing.'..k,fi[k],54) end
    fits(name..'.fishing.fish',fi.fish:format(9999),16)
    -- The photo hunt's screens (online/modes/photohunt/ui/board.lua, in the fishing tournament's places): the card's
    -- title line as the corner board's (31 columns) with the countdown, the longest time left (60:00) or Time up; a
    -- target row (Mideum 34, 18 units a column, 32 units in from each side of its 720: 36 columns), the target's name
    -- with two-digit numbers at the left, then a column, then open, you or a name cut by Join.name (19 columns) at the
    -- right; the last line with 3 points or 1 and place 8 within the 36; the result panel's heading within 31, the
    -- line under it with 3 points or 1 and each note within 54.
    local pc=w.photohunt
    for _,clock in ipairs({pc.count:format(5),'60:00',pc.up}) do
        fits(name..'.photohunt.head',pc.head..'  '..clock,31)
    end
    for _,k in ipairs({'memory','cat','butterfly','fish'}) do fits(name..'.photohunt.'..k,pc[k]:format(99),36-1-19) end
    fits(name..'.photohunt.open',pc.open,19)
    fits(name..'.photohunt.you',pc.you,19)
    fits(name..'.photohunt.card',pc.card:format(3,8),36)
    fits(name..'.photohunt.one.card',pc.one.card:format(8),36)
    fits(name..'.photohunt.title',pc.title,31)
    fits(name..'.photohunt.points',pc.points:format(3),54)
    fits(name..'.photohunt.one.points',pc.one.points,54)
    for _,k in ipairs({'waiting','unranked','best','norank'}) do fits(name..'.photohunt.'..k,pc[k],54) end
    local room=w.lobby.room:format('F5')
    assert(Chat.clean(room)==room,name..'.lobby.room: '..#room..' bytes or a control')
    -- Find a session (online/session/ui/sessions.lua): a key hint's label within the 420 units between two hints less
    -- the icon (Bold 30, 17 units a column); a status line on one line of the list's 1600 units (Bold 36, about 21
    -- units a column); the version in the details pane on one line of its 1040 units (Mideum 34, 18 units a column),
    -- with a two-digit protocol and an 8-digit build; the footer within two lines of 2200 units (Mideum 30, 16 units a
    -- column).
    local ss=w.sessions
    for _,k in ipairs({'ask','refresh'}) do fits(name..'.sessions.'..k,ss[k],20) end
    for _,k in ipairs({'empty','failed','idle'}) do fits(name..'.sessions.'..k,ss[k],76) end
    fits(name..'.sessions.wait',ss.wait:format(5),76)
    fits(name..'.sessions.friend',ss.friend,57)
    fits(name..'.sessions.version',ss.version:format('22','26123051'),57)
    fits(name..'.sessions.footer',ss.footer:format('22','26123051'),2*2200//16)
    -- Create a session (online/session/ui/create.lua): its page title at the top right within 40 columns (Mideum 34, 18
    -- units a column); the rules header and the Start row within a setting's title column on C (32); a locked row's
    -- reason and each Who can join word within four lines of the right pane's 1040 units (57 columns a line).
    local cr=w.create
    fits(name..'.create.title',cr.title,40)
    fits(name..'.create.rules',cr.rules,32)
    fits(name..'.create.start',cr.start,32)
    fits(name..'.create.locked',cr.locked,4*57)
    for k,text in pairs(cr.who) do fits(name..'.create.who.'..k,text,4*57) end
    -- The pause menu's Online tab (ui/kit/pause_tab.lua): its word within SB's tab, whose TextWidthValue it copies (16
    -- columns, so Thai's marks count as nothing), the notice when the game stays paused within the feed's 200 bytes.
    local pt=w.pause_tab
    fits(name..'.pause_tab.tab',pt.tab,16)
    assert(Chat.clean(pt.stuck)==pt.stuck,name..'.pause_tab.stuck: '..#pt.stuck..' bytes or a control')
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
-- The New Game+ notice: her name, her cycle and difficulty, then ours.
local CYCLE_TAIL=' Enemies with another max HP stay unshared.'
assert(T.cycle(T.en,'Kaanta',{count=1,difficulty=2},{count=0,difficulty=0})=='Kaanta is on New Game+ 1 (Hard); you are '
    ..'on your first playthrough (Normal).'..CYCLE_TAIL)
assert(T.cycle(T.en,'Kaanta',{count=0,difficulty=1},{count=12,difficulty=1})=='Kaanta is on their first playthrough '
    ..'(Story); you are on New Game+ 12 (Story).'..CYCLE_TAIL)
-- The emote wheel (ui/kit/wheel.lua, eve/ui/wheel.lua) and the TEST TOOLS pages, in every language: a hint within its
-- 420-unit cell after its icon (Bold 30, about 17 units a column: 20 columns), the centre's word as wide; a page's tab
-- within its 230 units (13 columns); a slot's name within two lines of its 370 units (Bold 36, about 21 units a
-- column: 2 lines of 15), the waves' with their side; the refusals within the feed's 200 bytes; the pages' labels and
-- values within the menu's columns. Each emote id of the wheel has a name: the two waves share hello.
local EMOTES={'hello','salute','kungfu','toast','clap','heart','thumbsup','victory','kiss','bringiton','giveme','hush',
    'reach','omg','what','worry','wish','wedidit','charm','confident','cutie','sweetie','squat','stretch','warmup','walk',
    'shutter1','shutter2','shutter3','flow','nataraja','somersault','chariotstruggle','chariotcounter','chariotfail',
    'chariottakedown','kalitakedown','kaligrab'}
for name in pairs(R.TEXT) do
    local w=T.pick(name)
    for _,k in ipairs({'release','point','next','title'}) do fits(name..'.wheel.'..k,w.wheel[k],20) end
    for _,k in ipairs({'world','busy','native','off'}) do
        assert(Chat.clean(w.wheel[k])==w.wheel[k],name..'.wheel.'..k..': over 200 bytes or a control')
    end
    for k,text in pairs(w.emote.cats) do fits(name..'.emote.cats.'..k,text..' 2',13) end
    for _,k in ipairs(EMOTES) do fits(name..'.emote.names.'..k,w.emote.names[k],30) end
    for _,side in ipairs({'left','right'}) do fits(name..'.emote.'..side,w.emote[side]:format(w.emote.names.hello),30) end
    fits(name..'.tools.done',w.tools.done,78)
    for k,text in pairs(w.tools.eve) do fits(name..'.tools.eve.'..k,text,LABEL) end
    for k,text in pairs(w.tools.dev) do fits(name..'.tools.dev.'..k,text,(k=='quest' or k=='player') and VALUE or LABEL) end
    for k,text in pairs(w.tools.viewer) do fits(name..'.tools.viewer.'..k,text,LABEL) end
    for _,k in ipairs({'nothing','leviathan','gardener','tendril','mann','nier','orcal','enya'}) do
        fits(name..'.tools.viewer.'..k,w.tools.viewer[k],VALUE)
    end
end
local n=0
for _ in pairs(T.en.emote.names) do n=n+1 end
assert(n==#EMOTES,'T.en.emote.names: '..n..' names')

print('ui_text_test ok')
