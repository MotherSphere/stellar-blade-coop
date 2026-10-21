-- ui_text.lua, pure (no fakes): a language's table only under one of the 23 culture names recruiter_text.lua's
-- culture() gives, and either empty or with exactly T.en's keys at every level, each word with T.en's format
-- placeholders in T.en's order (Lua's format has no positional arguments; a percent sign, %%, may stand anywhere, as
-- Turkish puts it first); T.pick's choice (the game's culture through culture(), English with ui_language=english,
-- for a culture with no table and for a word a table lacks); in every language, every notice within the feed's 200
-- bytes a line (Chat.clean) with a 32-byte name, every menu row, value and key hint within its column, the co-op
-- saves' question, with its invite line, within its 5 rows (Chat.wrap), and Night Operation's card and result panel
-- within their columns.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local T=require('ui_text')
local R=require('recruiter_text')
local Chat=require('chat')
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
-- The lines that go to the feed, as main.lua, puppet.lua, saves.lua, link.lua and join.lua put them together.
local function notices(w)
    local lines={}
    for _,group in ipairs({'fight','spawns','ghost','refused','quests'}) do
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
    -- Night Operation's notices (nightop_run.lua, with the UI off): the start, a wave, a clear, the end and why; for
    -- two players, her notice of his start and his of each refusal, and whose EVE died; the points a run earned.
    local n=w.night
    for _,text in ipairs({n.start_notice:format(5),n.wave_notice:format(5,5),n.clear_notice:format(5),n.died,
        n.time_up,n.end_notice:format(n.success,5,5,20,9999,'8:00'),n.end_notice:format(n.fail,5,5,20,9999,'8:00'),
        n.coop_notice:format(NAME,5),n.mate_died,n.you_died,n.earned:format(42,999999999)}) do
        lines[#lines+1]=text
    end
    for _,text in pairs(n.why) do lines[#lines+1]=text end
    for _,text in pairs(n.refuse) do lines[#lines+1]=n.refused:format(NAME,text) end
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
-- The menu's columns (menu.lua's rows, 1452 units wide, their value in the last 600; ui.lua's row puts the label 36
-- units in; Bold 40, about 23 units a column in the game's Latin face, a CJK character about two): a value within its
-- 600 units, a label within the 792 units from its start to 24 units before the value, a key hint within its 320-unit
-- cell after the 78 units of its icon (Bold 30, about 17 units a column).
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
    -- The co-op saves' question (saves.lua): its text within 5 body rows of 78 columns, as each phase shows it, the
    -- question with the invite line a held invite adds.
    local s=w.saves
    for _,texts in ipairs({{s.new,s.new_about,s.invite},{s.old,s.old_about,s.invite},{s.failed,s.see_log..'.'}}) do
        local rows=0
        for _,text in ipairs(texts) do rows=rows+#Chat.wrap(text,78) end
        assert(rows<=5,name..'.saves: '..rows..' rows, at most 5: '..texts[1])
    end
    -- Night Operation's card (nightop_run.lua: 1040 units wide, 24 in from each side; title Bold 36, its line Bold 40,
    -- about 23 units a column), with the longest numbers; its result panel: the heading Bold 56 (about 32 units a
    -- column), the line under it and the row labels Mideum 34 (18 units a column, as the feed's) from 96 units in, a
    -- label before its value's 5 Bold 40 columns at the right end.
    local n=w.night
    fits(name..'.night.title',n.title,43)
    fits(name..'.night.waiting',n.waiting,43)
    fits(name..'.night.starts',n.starts:format(5),43)
    for _,head in ipairs({n.wave:format(5,5),n.next:format(10)}) do
        fits(name..'.night line',head..'  8:00  '..n.score:format(9999),43)
    end
    fits(name..'.night.success',n.success,31)
    fits(name..'.night.fail',n.fail,31)
    for _,text in ipairs({n.died,n.time_up,n.mate_died,n.you_died}) do fits(name..'.night: '..text,text,54) end
    for k,text in pairs(n.why) do fits(name..'.night.why.'..k,text,54) end
    for _,k in ipairs({'waves','kills','points','time'}) do fits(name..'.night.'..k,n[k],40) end
end
print('ui_text_test ok')
