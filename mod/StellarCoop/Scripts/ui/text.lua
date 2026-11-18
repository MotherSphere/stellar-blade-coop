-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The co-op menu's, the co-op line's, the chat's, the partner HUD's, the co-op saves', the join codes', the shared
-- enemies', same place's, same spawns', the shared quests', the shared world's, story together's, the follow's, Night
-- Operation's, the challenges', the status line's, the status strip's above the partner card (overlay) and the
-- notices' words that the Lua side writes.
-- T.en is English; another language's table sits under its game culture name as ui/text/culture.lua's culture()
-- gives it (T.fr, T.de, T['zh-Hans']...: the 23 text languages the game ships), with T.en's keys at every level. The
-- game's language picks the table (GetCurrentLanguage) unless ui_language=english; a language with no table, or a word
-- missing from one, reads English. Row ids and setting names are ui/kit/model.lua's; a value's word is its id's (on,
-- both, game...), or <setting>_<id> where one setting's value needs other words (aggro_game).
local T={}
-- The language tables, one file each in ui/text/ (T.en first, then the game's cultures).
T.en=require('ui.text.en')
T.fr=require('ui.text.fr')
T.ar=require('ui.text.ar')
T.da=require('ui.text.da')
T.de=require('ui.text.de')
T.es=require('ui.text.es')
T['es-MX']=require('ui.text.es-MX')
T.fi=require('ui.text.fi')
T.it=require('ui.text.it')
T.ja=require('ui.text.ja')
T.ko=require('ui.text.ko')
T.nl=require('ui.text.nl')
T.no=require('ui.text.no')
T.pl=require('ui.text.pl')
T.pt=require('ui.text.pt')
T['pt-BR']=require('ui.text.pt-BR')
T.ru=require('ui.text.ru')
T.sv=require('ui.text.sv')
T.th=require('ui.text.th')
T.tr=require('ui.text.tr')
T['zh-Hans']=require('ui.text.zh-Hans')
T['zh-Hant']=require('ui.text.zh-Hant')
local culture=require('ui.text.culture').culture
-- A table and the tables in it read T.en's word for a key they lack.
local function fallback(t,en)
    for k,v in pairs(t) do if type(v)=='table' and type(en[k])=='table' then fallback(v,en[k]) end end
    return setmetatable(t,{__index=en})
end
-- fmt with name and the first two of names that fit max bytes, then (+n) for the others of n.
local function fit(fmt,name,names,n,max)
    local room,shown=max-#fmt:format(name,''),{}
    for i=1,math.min(2,#names) do
        local text=table.concat(shown,', ')..(i>1 and ', ' or '')..names[i]
        local rest=n-i
        if #text+(rest>0 and #(' (+'..rest..')') or 0)>room then break end
        shown[i]=names[i]
    end
    local text,rest=table.concat(shown,', '),n-#shown
    if rest>0 then text=text..(text~='' and ' ' or '')..'(+'..rest..')' end
    return fmt:format(name,text)
end
-- A notice naming mods (main.lua's about her .pak mods, online/partner/puppet.lua's about her outfit's parts): fmt with
-- name and the last part ('/'-separated) of each of the first two of list.names ({n=, names=}) that fit the feed's 200
-- bytes (online/session/chat.lua), then (+n) for the others.
function T.mods(fmt,name,list)
    local short={}
    for i=1,math.min(2,#list.names) do short[i]=list.names[i]:match('[^/]*$') end
    return fit(fmt,name,short,list.n,200)
end
-- The DLC notice (main.lua): in w's words, the sentence of hers we lack (missing) and the one of ours she lacks
-- (extra), each when its list of names is not empty, in the feed's 200 bytes: the first takes the first two names that
-- fit once the second has room for its count alone, the second the first two that fit in what is left. Her name comes
-- in both: when it is so long (link/protocol.h's kMaxName is 64 bytes) that the two counts alone pass 200 bytes, it is
-- cut at a character's start until they fit.
function T.dlcs(w,name,missing,extra)
    local parts,said,room={},{},200
    if #missing>0 then parts[#parts+1]={w.dlc.theirs,missing} end
    if #extra>0 then parts[#parts+1]={w.dlc.yours,extra} end
    local least=-1
    for _,part in ipairs(parts) do least=least+1+#fit(part[1],name,{},#part[2],200) end
    if least>200 then
        local at=math.max(0,#name-(least-200+#parts-1)//#parts)+1
        while at>1 and (name:byte(at) or 0)>=0x80 and name:byte(at)<0xC0 do at=at-1 end
        name=name:sub(1,at-1)
    end
    for i,part in ipairs(parts) do
        local later=parts[i+1] and 1+#fit(parts[i+1][1],name,{},#parts[i+1][2],200) or 0
        said[i]=fit(part[1],name,part[2],#part[2],room-later)
        room=room-#said[i]-1
    end
    return table.concat(said,' ')
end
-- The New Game+ notice (main.lua): in w's words, her name, then her cycle and difficulty and ours (core/link.lua's
-- cycles(): {count=, difficulty=}). A count of 0 reads as a first playthrough, any other as New Game+ n; difficulty 0
-- is Normal, 1 Story, 2 Hard (game/sbo.h).
function T.cycle(w,name,theirs,mine)
    local c=w.cycle
    local level={[0]=c.normal,c.story,c.hard}
    local function run(n,first) return n==0 and first or c.plus:format(n) end
    return c.notice:format(name,run(theirs.count,c.their_first),level[theirs.difficulty],run(mine.count,c.your_first),
        level[mine.difficulty])
end
-- A notice of the Steam link (core/link.lua's notices(), link/core.h's English): for a join Steam refused, the
-- function of the words (T.en or another table) that gives it in their language, as main.lua's tell takes one; nil
-- for any other notice.
function T.join_refused(text)
    for key,en in pairs(T.en.join_refused) do
        if en==text and key~='other' then return function(w) return w.join_refused[key] end end
    end
    local n=text:match('^Could not join: Steam response (%d+)%.$')
    if n then return function(w) return w.join_refused.other:format(tonumber(n)) end end
end
-- The words for the game's culture (nil when unread) and ui_language.
function T.pick(name,setting)
    local t=setting~='english' and T[culture(name)] or T.en
    if t~=T.en and not getmetatable(t) then fallback(t,T.en) end
    return t
end
return T
