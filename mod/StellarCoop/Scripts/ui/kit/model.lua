-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The co-op menu's model (UI-DESIGN 4.1 and its Options table), no engine call: the main page's rows by session state,
-- the co-op line's (a camp phone booth's page: the main page's session rows, Co-op menu and Hang up),
-- the Options tree (every co-op setting as a toggle, a choice, a range or a key; Reset all keys too), a cursor that
-- skips section headers and wraps, Leave, Remove and Reset all keys only on a second Select of that row within 3 s,
-- values read as the mod reads coop-settings.txt (link.parse_settings) and each change as the one value to write there
-- (settings_file.set). Rows and values are ids; ui_text gives their words.
local SF=require('core.settings_file')
local K=require('core.keybind')
local Link=require('core.link')
local M={}
-- ctx: {mode=link.mode() ('none', 'host', 'guest', nil before Steam), chat=the chat box can open (a session, the SBO
-- lobby too), code=our join code while we host with one (link.code), stranger=a player we let in who is not our Steam
-- friend ({id=, name=}, link.stranger), values=the settings' values (M.read), for a row shown by another one's value,
-- members=the online session's other players past the handshake (link.members()'s), for their mute rows,
-- pages=the modules' TEST TOOLS pages (see below) whose title in these words is not nil, words=the player's words}.
-- A module's page: {title=function(words) -> its name or nil (off: not listed), rows=function(words) -> its rows, made
-- anew at each draw from the module's state: {id= (unique on the page: the cursor follows it), label=, value= ('' for
-- a button), head=true (a heading: grey, the cursor skips it), select=function() -> ok, note (Enter, Space, A, a left
-- click), step=function(dir) -> ok, note (left or right; nil: they do nothing)}}. note: the player's words, or the
-- console's English refusal, under the rows.
-- confirm: the row runs on a second Select within 3 s.
local function none(c) return c.mode=='none' end
M.MAIN={
    {head='session'},
    {id='host',show=none},
    {id='leave',confirm=true,show=function(c) return c.mode=='host' or c.mode=='guest' end},
    {id='invite',show=function(c) return c.mode=='host' end},
    {id='copy',show=function(c) return c.code~=nil end},
    {id='remove',confirm=true,show=function(c) return c.stranger~=nil end},
    {id='find',show=none}, -- Find a session: the Sessions screen (online/session/ui/sessions.lua).
    {id='join_code',show=none},
    {id='chat',show=function(c) return c.chat end},
    {head='settings'},
    {id='options'},
    {head='tools'},
    {pages=true}, -- One row a module page (ctx.pages): Select opens it, Back comes back to its row.
    {head='help'},
    {id='guide'}, -- The first-launch guide (ui/kit/guide.lua); its word is ui/text/guide.lua's.
    {id='report'},
    {id='close'},
}
local function main_row(id) for _,row in ipairs(M.MAIN) do if row.id==id then return row end end end
-- The co-op line: the main page's own session rows (the same tables: the same show and confirm), then Co-op menu (the
-- main page) and Hang up (closed).
M.LINE={{head='line'},main_row('host'),main_row('invite'),main_row('copy'),main_row('find'),main_row('join_code'),
    main_row('remove'),main_row('leave'),{id='menu'},{id='hangup'}}
local function toggle(key,default) return {key=key,values={'on','off'},default=default} end
local function range(key,min,max,step,default) return {key=key,min=min,max=max,step=step,default=tostring(default)} end
local function bind(key,default) return {key=key,bind=true,default=default} end
local function reload(row) row.reload=true; return row end -- The mod takes it at its next load only.
-- Defaults as the file writes them. A setting gets its row with its feature: every row is one the mod reads.
M.OPTIONS={
    {head='controls'},
    bind('menu_key','F5'),bind('status_key','F6'),bind('leave_key','F8'),bind('follow_key','F7'),bind('race_key','F9'),
    toggle('bike','on'),bind('bike_key','F3'), -- bike at once: vehicles/bike/ride.lua reads it every 250 ms.
    {key='bike_pose',values={'rig','hold'},default='rig'}, -- At the next mount: vehicles/bike/ride.lua reads it there.
    reload(toggle('gun_mode','on')),reload(bind('gun_key','F4')), -- Gun mode reads both when it starts.
    -- At once: main/keys.lua and main/input.lua read them at each press (the emote wheel, eve/ui/wheel.lua).
    bind('emote_key','F2'),{key='emote_pad',values={'dpad_left','off'},default='dpad_left'},
    bind('closet_key','F1'), -- At once: main/keys.lua reads it at each press (the closet menu, closet/ui/menu.lua).
    toggle('pause_tab','on'), -- At once: ui/kit/pause_tab.lua asks the native part pausetab on or off.
    {id='reset_keys',confirm=true}, -- Every key back to its default (reset_keys), host_key too.
    {head='photo'},
    {key='photo_sync',values={'both','notice','off'},default='both'},
    -- The file's range: 0 (no limit) or 30 to 3600 s; a minute a step, shown in minutes.
    {key='photo_freeze_max',min=30,max=3600,step=60,zero=true,default='600'},
    toggle('photo_ghost','on'),toggle('photo_name_tag','on'),
    {key='photo_pause',values={'full','scenery'},default='full'}, -- From the next photo mode.
    {head='partner'},
    reload(toggle('name_tag','on')),toggle('partner_bar','on'),toggle('partner_arrow','on'),toggle('partner_card','on'),
    toggle('card_details','on'), -- Ping and the friend's map on the card.
    {head='ghost'},
    toggle('cloth','on'),toggle('dyes','on'),toggle('effects','on'),toggle('drone','on'),toggle('sounds','on'),
    toggle('faces','on'),
    toggle('collide','on'), -- Yours, at once: the solid partner (online/partner/puppet.lua).
    range('send_rate',10,60,5,60), -- 5 a step.
    {head='session'},
    -- At the next host. closed shows as Private. friends_ask under public and invitation only: its row reads Friends
    -- join without asking, On while friends_ask=off (ui/text.lua's friends_ask_off).
    {key='who_can_join',values={'public','friends','invitation','closed'},default='public'},
    {key='friends_ask',values={'on','off'},default='off',show=function(c)
        local who=c.values and c.values.who_can_join
        return who=='public' or who=='invitation'
    end},
    range('max_players',2,4,1,4), -- At the next host: the players the session holds, the host included.
    toggle('revive','on'), -- Yours, at once: the friend's revive of your EVE (online/group/group.lua).
    toggle('spectate','on'), -- Yours: watch a living member while you are down in a shared boss fight.
    toggle('cutscene_wait','on'), -- Yours as the guest, at once: the pause during the host's cutscene.
    -- Yours as the guest, at once: the travel to the camp nearest the host (online/group/travel.lua), offered (ask),
    -- started by itself (always) or neither (off).
    {key='follow_host',values={'ask','always','off'},default='ask'},
    toggle('shared_world','on'), -- At once: main.lua asks coop world on or off.
    toggle('shared_story','on'), -- At once: main.lua asks coop scenes on or off.
    toggle('hide_popups','on'), -- At once: main.lua's switch_pass asks the native part popups on or off.
    {head='modes'},
    toggle('scoreattack','on'), -- At each round's start: online/modes/scoreattack/game.lua reads it.
    toggle('fishing','on'), -- At each go line: online/modes/fishing reads it.
    toggle('race_match','on'), -- At once: coop race match shows it (online/modes/race/commands.lua).
    toggle('photohunt','on'), -- At each go line: online/modes/photohunt reads it.
    {head='saves'},
    {key='auto_coop_save',values={'ask','always','off'},default='ask'}, -- At the next title.
    toggle('shared_quests','on'), -- At once: main.lua asks coop quests on or off.
    {head='combat'},
    toggle('shared_enemies','on'), -- At once: main.lua asks coop fight on or off.
    -- The host's for both games: at once while shared enemies wait or run (main.lua asks coop fight pilot off or on),
    -- else from their next start.
    toggle('same_place','on'),
    -- The host's for every game: at once while shared enemies wait or run (coop fight stagger), else from their next
    -- start.
    toggle('hit_reactions','on'),toggle('stagger_resist','on'),
    -- The host's values for both games, and our own kill credit: each from the next start of shared enemies. aggro:
    -- who a same-place enemy fights (game: whoever hit it last, or else the nearer player; host: the host only).
    {key='aggro',values={'game','host'},default='game'},
    -- Same spawns (stage 4): where both players stand within 100 m in one zone, the guest's game holds the host's
    -- common enemies there. enemy_extra (stage 4b): that many more of each, used with same spawns only. bosses (stage
    -- 5): bosses and Alpha Naytibas shared too, their maximum HP times boss_hp_scale. boss_finish: whose finisher
    -- press counts on a shared boss (first: the first one on any screen; host: the host's only).
    toggle('same_spawns','on'),range('enemy_extra',0,3,1,0),toggle('bosses','on'),
    {key='boss_finish',values={'first','host'},default='first'},
    range('enemy_hp_scale',1,4,0.05,1.35),range('enemy_balance_scale',1,4,0.05,1.15),range('boss_hp_scale',1,4,0.05,2),
    {key='kill_credit',values={'together','fought'},default='together'},
    {head='display'},
    {key='status_overlay',values={'off','compact','detailed'},default='compact'}, -- At once: the HUD reads it each 250 ms.
    range('ui_scale',75,150,5,100),toggle('ui_sounds','on'),
    {key='ui_language',values={'game','english'},default='game'},
    toggle('daynight','on'), -- At once: world/daynight/daynight.lua reads it every 250 ms.
    {head='chat'},
    toggle('chat','on'),
}
-- Every key setting a rebind is checked against: the page's, and host_key, off once the menu holds Host (D-UI2).
local KEYS={bind('host_key','none')}
for _,row in ipairs(M.OPTIONS) do if row.bind then KEYS[#KEYS+1]=row end end
local DEFAULT={} -- Key setting to its default.
for _,row in ipairs(KEYS) do DEFAULT[row.key]=row.default end
-- Every setting's value from the file's text (setting name to value), as the mod takes it (link.parse_settings: the
-- last line it takes, the menu key's migration, the defaults for two actions on one key); a setting it does not read
-- yet, the model's default.
function M.read(text) return M.values(Link.parse_settings(text)) end
-- The same from settings as link.parse_settings gives them (main.lua's, the ones in effect): a key by its name, on and
-- off for a switch, a number as text.
function M.values(s)
    local values={}
    for _,rows in ipairs({M.OPTIONS,KEYS}) do
        for _,row in ipairs(rows) do
            local v=row.key and s[row.key]
            if row.key then
                if v==nil then values[row.key]=row.default
                elseif type(v)=='table' then values[row.key]=v.name
                elseif type(v)=='boolean' then values[row.key]=v and 'on' or 'off'
                else values[row.key]=tostring(v) end
            end
        end
    end
    return values
end
-- A setting row's value in w's words (a ui/text.lua table): a choice's word (<key>_<value> first: aggro_game), the
-- longest pause in minutes or seconds, the scales and the menu size in percent, any other number as it is.
function M.shown(w,row,v)
    if row.values then return w.value[row.key..'_'..v] or w.value[v] or v end
    local n=tonumber(v)
    if row.key=='photo_freeze_max' then
        return n==0 and w.no_limit or (n%60==0 and w.minutes:format(n//60) or w.seconds:format(n))
    end
    if row.key=='enemy_hp_scale' or row.key=='enemy_balance_scale' or row.key=='boss_hp_scale' then -- 1.35: 135 %.
        return w.percent:format(math.floor(n*100+0.5))
    end
    return row.key=='ui_scale' and w.percent:format(n) or v
end
-- A setting row's value one step (dir +1 or -1) from value: a choice's next, wrapping; a range's, held at its ends; nil
-- when it stays.
function M.step(row,value,dir)
    local new
    if row.values then
        local at=1
        for i,v in ipairs(row.values) do if v==value then at=i end end
        new=row.values[(at-1+dir)%#row.values+1]
    else
        local n=math.min(row.max,tonumber(value)+dir*row.step)
        if n<row.min then n=row.zero and 0 or row.min end -- zero: 0 is a value too (no limit), below min.
        new=tostring(math.tointeger(n) or n)
    end
    if new~=value then return new end
end
-- The file's text with key set to value (settings_file.set), or nil and why. The first menu_key written into a file
-- with none also turns host_key off there: the menu held host_key's key (link.parse_settings), which must not host
-- again by itself.
function M.write(text,key,value)
    if key=='menu_key' and not SF.get(text,'menu_key') then
        local why
        text,why=SF.set(text,'host_key','none')
        if not text then return nil,why end
    end
    return SF.set(text,key,value)
end
-- The file's text with every key setting at its default, host_key's none included, or nil and why.
function M.reset_keys(text)
    for _,row in ipairs(KEYS) do
        local why
        text,why=M.write(text,row.key,row.default)
        if not text then return nil,why end
    end
    return text
end
-- A key pressed for a rebind (keybind.text's), checked: 'set', key, the value to write; or nil and why: the grammar's
-- reason, or 'clash' and the other setting that holds it. Enter, which no key setting takes (the chat's), puts back
-- the key's default.
function M.rebind(values,key,text)
    if text=='Enter' then text=DEFAULT[key] end
    local new,why=K.parse(key,text)
    if not new then return nil,why end
    local keys={}
    for _,row in ipairs(KEYS) do keys[row.key]=K.parse(row.key,values[row.key] or row.default) end
    local other=K.clash(keys,key,new)
    if other then return nil,'clash',other end
    return 'set',key,new.name
end
-- start: the page it opens on, 'main' (the default) or 'line'.
function M.new(start)
    local self,page,id,index,asked={},start or 'main',nil,1,nil -- asked: {id=, at=} the first Select of a confirm row.
    local mod=nil -- The module page open (page 'module').
    local function name(row)
        return row.member and 'mute '..row.member or row.page and 'page '..row.n or row.id or row.key
    end
    function self.page() return page end
    function self.module() return mod end -- The module page open, or nil.
    -- The page's rows shown in this state, headers included. A header with no row under it is left out. Options ends
    -- with one mute row per other player of the online session, under Chat: {id='mute', member=her SteamID, name=,
    -- muted=}, the same table for her each call (the menu finds the cursor's row by identity).
    local mutes,pages={},{}
    function self.rows(ctx)
        if page=='module' then return mod.rows(ctx.words) end
        local rows={}
        for _,row in ipairs(page=='main' and M.MAIN or page=='line' and M.LINE or M.OPTIONS) do
            if row.head and rows[#rows] and rows[#rows].head then rows[#rows]=nil end
            if row.pages then
                for n,p in ipairs(ctx.pages or {}) do
                    local r=pages[p] or {id='page',page=p}
                    r.n,pages[p]=n,r
                    rows[#rows+1]=r
                end
            elseif not row.show or row.show(ctx) then rows[#rows+1]=row end
        end
        if page=='options' and (ctx.mode=='host' or ctx.mode=='guest') then
            for _,m in ipairs(ctx.members or {}) do
                if m.linked then
                    local row=mutes[m.id] or {id='mute',member=m.id}
                    row.name,row.muted,mutes[m.id]=m.name,m.muted,row
                    rows[#rows+1]=row
                end
            end
        end
        if rows[#rows].head then rows[#rows]=nil end
        return rows
    end
    -- The row under the cursor: the same row while it shows, else the one now in its place (the next, past a header).
    function self.current(ctx)
        local rows=self.rows(ctx)
        for i,row in ipairs(rows) do if id and name(row)==id then index=i; return row end end
        index=math.min(index,#rows)
        while rows[index].head do index=index%#rows+1 end
        id=name(rows[index])
        return rows[index]
    end
    -- One row up (-1) or down (1), over headers, wrapping.
    function self.move(ctx,dir)
        self.current(ctx)
        local rows=self.rows(ctx)
        repeat index=(index-1+dir)%#rows+1 until not rows[index].head
        id,asked=name(rows[index]),nil
    end
    -- The mouse on a row (one of rows(ctx)): the cursor on it, true when it moved there; a header or a row not shown,
    -- nothing. A first Select on Leave or Remove stays only when it is the same row.
    function self.point(ctx,row)
        self.current(ctx)
        for i,r in ipairs(self.rows(ctx)) do
            if (r==row or page=='module' and r.id==row.id) and not r.head then -- A module's rows: new at each call.
                if name(r)==id then return false end
                index,id,asked=i,name(r),nil
                return true
            end
        end
        return false
    end
    -- A setting row's next value: 'set', key, text; nil on a key row (rebind), a non-setting row or at a range's end.
    function self.change(ctx,values,dir)
        local row=self.current(ctx)
        if page=='module' then
            if not row.step then return nil end
            return 'run',row,dir
        end
        if not row.key or row.bind then return nil end
        local new=M.step(row,values[row.key],dir)
        if not new then return nil end
        return 'set',row.key,new
    end
    -- Select (now in seconds): the row's id for the caller ('host', 'leave', 'invite', 'copy', 'remove', 'find',
    -- 'join_code', 'chat', 'guide', 'report', 'close', which Hang up gives too, 'reset_keys'); 'mute', her SteamID and
    -- whether she is muted now (the caller mutes or unmutes her); 'confirm_leave',
    -- 'confirm_remove' or 'confirm_reset_keys' (the row runs on a second Select of it within 3 s); 'options' or
    -- 'main' (the page changed: Co-op menu gives 'main'); 'rebind', key; or a setting's next value, as change(). nil
    -- when a first Select on Leave or Remove is pending (under 3 s old) and that row went (the session ended, the
    -- player left): the press was meant for it, not for its place.
    -- On a module page: 'run' and its row (the caller runs its select). On a module page's row of the main page:
    -- 'page' (the page changed).
    function self.select(ctx,now,values)
        local row=self.current(ctx)
        if page=='module' then return 'run',row end
        if row.page then page,mod,id,index='module',row.page,nil,1; return 'page' end
        if asked and asked.id~=name(row) then
            local live=now-asked.at<=3
            asked=nil
            if live then return nil end
        end
        if row.confirm then
            if asked and asked.id==row.id and now-asked.at<=3 then asked=nil; return row.id end
            asked={id=row.id,at=now}
            return 'confirm_'..row.id
        end
        if row.id=='options' then page,id,index='options',nil,1; return 'options' end
        if row.id=='menu' then page,id,index='main',nil,1; return 'main' end
        if row.id=='hangup' then return 'close' end
        if row.bind then return 'rebind',row.key end
        if row.key then return self.change(ctx,values,1) end
        if row.member then return 'mute',row.member,row.muted end
        return row.id
    end
    -- The menu closed (by menu_key; back() calls it for Esc): a first Select on Leave or Remove is forgotten.
    function self.close() asked=nil end
    -- Back (Esc): from Options to the main page, on its Options row; from a module page to the main page, on its row;
    -- from the main page or the line, 'close'.
    function self.back()
        if page=='module' then
            for p,r in pairs(pages) do if p==mod then id=name(r) end end
            page,mod,asked='main',nil,nil
            return nil
        end
        if page~='options' then self.close(); return 'close' end
        page,id,asked='main','options',nil
        return nil
    end
    return self
end
return M
