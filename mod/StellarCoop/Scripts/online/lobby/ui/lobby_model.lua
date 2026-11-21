-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The lobby screens' model (design-lobby 4.3 to 4.5), no engine call: the lobby menu's rows by state, what Select on a
-- row asks for, its status line and members box, a cursor that wraps and visits locked rows, the settings screen's
-- rows of both tabs, and the countdown's local clock. Rows, statuses and values are ids or keys of ui/text.lua's
-- lobby table; online/lobby/ui/lobby.lua gives them their words. The mode rows: free-for-all, score attack
-- (online.modes.scoreattack) and the Doro race (online.modes.race), the last two with their round in the waiting room,
-- picked before Search or Private match; in a score attack match lobby, its Challenge row in place of free-for-all; in
-- a Doro race match lobby, its Track row.
local Join=require('core.line')
local Maps=require('online.lobby.sbo_maps')
local M={}
-- FFA's lobby size (N11's 8); an online session's while its max_players is not known (a guest before the host's let
-- line: the most one holds); seconds the copied word stays.
local LIMIT,COOP,COPIED=8,4,3
-- The mode rows (four at most, so B's top block keeps one layout), then the action rows of each state.
local MODES={'ffa','scoreattack','race','more'}
local SCORE={'scoreattack','challenge','more'} -- In a score attack match lobby.
local RACE={'race','track','more'} -- In a Doro race match lobby.
local OWN={scoreattack=SCORE,race=RACE}
-- Each mode row's round: it can play while the view holds it (sa, dr).
local CAN={scoreattack='sa',race='dr'}
local ROWS={
    idle={'search','private','join_code','room','settings','leave'},
    public={'cancel','room','settings','leave'},
    code={'code','cancel','room','settings','leave'},
}
-- Select on a row; cancel depends on the state; search and private name the mode picked; more asks for nothing. Search
-- and Private name the lobby too (lobby: main.lua adds the room and hall words of online/lobby/sbo.lua's lobby_words()
-- to Search, and sends Private through sbo.create() with the map picked on C). A mode row picks its mode; the Challenge
-- row cycles the host's pick (online.modes.scoreattack's cycle), the Track row the host's track (online.modes.race's).
local ACTS={search={request='match search',lobby=true},private={request='match create',lobby=true},
    join_code={open='join'},code={copy=true},room={close='room'},settings={open='settings'},leave={popup='leave'},
    ffa={mode='ffa'},scoreattack={mode='scoreattack'},race={mode='race'},challenge={cycle=true},track={cycle='race'}}
-- Tab match's rules of each mode; a value key of a mode's own where the rule's words differ from another mode's.
local MATCH={ffa={'players','finish','tie','respawn','protection','difficulty','equipment','start'},
    scoreattack={'players','challenge','ranking','damage','equipment','start'},
    race={'players','track','ranking','damage','start'}}
local VALUE={race={ranking='race_ranking'}}
-- The rows that read the host's pick: the score attack's challenge, the Doro race's track.
local PICK={challenge='sa',track='dr'}
-- A Private match's map: a draw, or one of the hall lobbies.
local ROOMS={'random',table.unpack(Maps.order)}
-- The other members (link.members()), our own SteamID left out.
local function others(o)
    local me,out=(o.me or {}).id,{}
    for _,m in ipairs(o.members or {}) do if m.id~=me then out[#out+1]=m end end
    return out
end
-- idle: no Steam lobby; public: searching, or in a match lobby found by Search; code: in a match lobby made or
-- joined by code, or in a lobby that is not a match lobby (a co-op lobby). After a Lua reload (last nil) a match lobby
-- is ours by code when we hold a code.
local function state_of(o)
    local m=o.match
    if not m then return (o.role or 'none')=='none' and 'idle' or 'code' end
    if m.state=='searching' or o.last=='search' then return 'public' end
    if o.last=='create' or o.last=='join' then return 'code' end
    return o.code and 'code' or 'public'
end
local function mark(m)
    if m.lost or m.rtt>=250 then return 'error' end
    if not m.linked or m.rtt>=150 then return 'warn' end
    return 'ok'
end
-- o: {match=link.match(), members=link.members(), role=link.mode() or 'none', limit=link.cap() (the players at most of
-- the online session we are in, its host's max_players; nil otherwise), code=our code while we host with one,
-- me={id=our SteamID, name=link.me()}, owner=link.owner(), last=our last request ('search', 'create', 'join' or nil),
-- copied_at=, now= (seconds), version=, proto= (mod= and proto=), pick= (the mode picked on B: 'ffa', 'scoreattack',
-- 'race' or nil), sa= (score attack while it can play: online.modes.scoreattack on and scoreattack=on, {pick=the host's
-- challenge pick, 'random' or a challenge id}; nil otherwise), dr= (the Doro race while it can play: online.modes.race
-- on and race_match=on, {pick=the host's track pick, 'random' or a track's name}; nil otherwise)}. A countdown's status
-- is its left seconds; a match lobby playing a round reads as open. view.mode: the match lobby's mode, else the mode
-- picked (the Doro race when it was picked and can play, else score attack unless it cannot play or free-for-all was
-- picked: it is the mode whose round plays). The picked mode's row is marked (picked); the Challenge and Track rows'
-- value is the host's pick, or 'host' for a guest.
function M.view(o)
    local m,me,list=o.match,o.me or {},others(o)
    local state=state_of(o)
    local mode=m and m.mode or (o.dr and o.pick=='race' and 'race' or o.sa and o.pick~='ffa' and 'scoreattack' or 'ffa')
    local rows={}
    for _,id in ipairs(m and OWN[m.mode] or MODES) do
        local locked=id=='more' or (id=='ffa' or CAN[id]) and (state~='idle' or CAN[id] and not o[CAN[id]])
        if PICK[id] then
            local can=o[PICK[id]]
            locked=o.role~='host' or not can
            rows[#rows+1]={id=id,locked=locked,value=o.role=='host' and (can and can.pick or 'random') or 'host'}
        else rows[#rows+1]={id=id,locked=locked,picked=id==mode or nil} end
    end
    for _,id in ipairs(ROWS[state]) do -- The code row only while we hold a code (a guest by code has none).
        if id~='code' then rows[#rows+1]={id=id}
        elseif o.code then rows[#rows+1]={id=id,args={o.code}} end
    end
    local n,limit=1,LIMIT
    if m and m.state~='searching' then n,limit=m.members or 1,m.limit or LIMIT
    elseif not m and state=='code' then n,limit=1+#list,o.limit or COOP end
    local key,args,tone
    if m and m.state=='searching' then key,tone='status.searching','warn'
    elseif m and m.state=='countdown' then key,args,tone='status.start',{m.left or 0},'teal'
    elseif state=='idle' then key,tone='status.idle','grey'
    elseif state=='code' then
        if o.copied_at and o.now-o.copied_at<COPIED then key,tone='status.copied','teal'
        else key,args,tone='status.private',{n,limit},'teal' end
    elseif o.last=='search' and o.role=='host' and n==1 then key,tone='status.created','grey'
    else key,args,tone=n==limit and 'status.full' or 'status.open',{n,limit},'teal' end
    -- link: the word shown where the ping would be ('lost', 'connecting') or 'ok' for the ping itself.
    local members={{id=me.id,name=Join.name(me.name),you=true,host=o.role=='host',mark='ok',link='ok'}}
    for _,p in ipairs(list) do
        members[#members+1]={id=p.id,name=Join.name(p.name) or '',host=p.id==o.owner,
            ping=p.rtt>=0 and p.rtt or nil,mark=mark(p),link=p.lost and 'lost' or not p.linked and 'connecting' or 'ok'}
    end
    return {state=state,mode=mode,rows=rows,status={key=key,args=args or {},tone=tone},members=members,
        count={n=n,limit=limit},left=m and m.state=='countdown' and m.left or nil}
end
-- What Select on row id asks for: {request=a link request, lobby=true when it names the lobby}, {open='join'|'settings'},
-- {close='room'}, {copy=true}, {popup='leave'}, {mode=the mode picked}, {cycle=true} (the Challenge row), {cycle='race'}
-- (the Track row); nil for more, a locked row or a row the view does not show.
function M.act(view,id)
    for _,row in ipairs(view.rows) do
        if row.id==id then
            if row.locked then return nil end
            if id=='cancel' then return {request=view.status.key=='status.searching' and 'match cancel' or 'leave'} end
            local a=ACTS[id]
            if a and a.request then return {request=a.request..' '..view.mode,lobby=true} end
            return a
        end
    end
end
-- The row after at, step +1 or -1, wrapping; locked rows are visited (my call 7).
function M.move(rows,at,step) return (at-1+step)%#rows+1 end
-- The settings screen's rows of tab 'match' or 'sbo': headers {head=} and items {id=, value=, args=, locked=,
-- values=, action=, name=, shown=, pick=}. Tab match, all locked: headers are the mode's id (view.mode) and 'lobby',
-- values keys of the lobby table (args when they format), the score attack's challenge and the Doro race's track their
-- pick (pick: 'random', a challenge id or a track's name, or 'host', as the row's value on B); idle with the hall
-- lobbies in use, the room row is not
-- locked: the map of a Private match, 'random' or a hall's key, shown by its word (shown: a key of the lobby table, or
-- the hall's name). Tab sbo: headers 'chat', 'display', 'help'; values the setting's own ('on', 'off', 'game',
-- 'english') with the values a change cycles through; one mute row per other member, its action the link request.
-- o: M.view's, plus settings=
-- (main.lua's: chat, ui_language, ui_sounds), halls= (true: the hall lobbies are in use) and room= (the map picked).
function M.settings(view,tab,o)
    local rows={}
    local function add(row) rows[#rows+1]=row end
    if tab=='match' then
        add({head=view.mode})
        local pick={}
        for _,row in ipairs(view.rows) do if PICK[row.id] then pick[row.id]=row.value end end
        for _,id in ipairs(MATCH[view.mode] or MATCH.ffa) do
            if PICK[id] then
                local can=o[PICK[id]]
                add({id=id,pick=pick[id] or can and can.pick or 'random',locked=true})
            else add({id=id,value='val.'..((VALUE[view.mode] or {})[id] or id),locked=true}) end
        end
        add({head='lobby'})
        if view.state=='code' then add({id='lobby',value='val.private',args={o.code or '-'},locked=true})
        else add({id='lobby',value='val.public',locked=true}) end
        if o.halls and view.state=='idle' then
            local room=Maps.maps[o.room] and o.room or 'random'
            add({id='room',value=room,values=ROOMS,shown=room=='random' and 'val.random' or Maps.maps[room].name})
        end
        add({id='version',value='val.version',args={o.version or '-',o.proto or 0},locked=true})
        return rows
    end
    local s=o.settings or {}
    add({head='chat'})
    add({id='chat',value=s.chat==false and 'off' or 'on',values={'on','off'}})
    for _,p in ipairs(others(o)) do
        add({id='mute',name=Join.name(p.name) or '',value=p.muted and 'on' or 'off',
            action=(p.muted and 'unmute ' or 'mute ')..p.id})
    end
    add({head='display'})
    add({id='ui_language',value=s.ui_language or 'game',values={'game','english'}})
    add({id='ui_sounds',value=s.ui_sounds==false and 'off' or 'on',values={'on','off'}})
    add({head='help'})
    add({id='report',action='report'})
    return rows
end
-- The countdown to show, state {start=, total=} (nil: none runs), from the status's left seconds: a new start when
-- none runs, a restart at total=left when the shown seconds (total - (now - start)) are more than 1 s off, else the
-- same state.
function M.count(state,left,now)
    if state and math.abs(state.total-(now-state.start)-left)<=1 then return state end
    return {start=now,total=left}
end
return M
