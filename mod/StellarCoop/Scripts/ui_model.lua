-- The co-op menu's model (UI-DESIGN 4.1 and its Options table), no engine call: the main page's rows by session state,
-- the Options tree (every co-op setting as a toggle, a choice, a range or a key; those whose feature is not built yet
-- wait, hidden), a cursor that skips section headers and wraps, Leave and Remove only on a second Select of that row
-- within 3 s, values read as the mod reads coop-settings.txt (link.parse_settings), and each change as the one value
-- to write there (settings_file.set). Rows and values are ids; ui_text gives their words.
local SF=require('settings_file')
local K=require('keybind')
local Link=require('link')
local M={}
-- ctx: {mode=link.mode() ('none', 'host', 'guest', nil before Steam), chat=a friend linked or the loopback running,
-- code=our join code while we host with one (link.code), stranger=a player we let in who is not our Steam friend
-- ({id=, name=}, link.stranger)}. confirm: the row runs on a second Select within 3 s.
local function none(c) return c.mode=='none' end
M.MAIN={
    {head='session'},
    {id='host',show=none},
    {id='leave',confirm=true,show=function(c) return c.mode=='host' or c.mode=='guest' end},
    {id='invite',show=function(c) return c.mode=='host' end},
    {id='copy',show=function(c) return c.code~=nil end},
    {id='remove',confirm=true,show=function(c) return c.stranger~=nil end},
    {id='join',show=none},
    {id='join_code',show=none},
    {id='chat',show=function(c) return c.chat end},
    {head='settings'},
    {id='options'},
    {head='help'},
    {id='report'},
    {id='close'},
}
local function toggle(key,default) return {key=key,values={'on','off'},default=default} end
local function range(key,min,max,step,default) return {key=key,min=min,max=max,step=step,default=tostring(default)} end
local function bind(key,default) return {key=key,bind=true,default=default} end
local function later(row) row.later=true; return row end -- Its feature is not on this branch yet: hidden.
local function reload(row) row.reload=true; return row end -- The mod takes it at its next load only.
-- Defaults as the file writes them. Keys the mod does not read yet are named here first (the milestone that brings
-- each is in UI-DESIGN's Options table); each waits as later() until its feature is built, then the mod reads it.
M.OPTIONS={
    {head='controls'},
    bind('menu_key','F5'),bind('status_key','F6'),bind('leave_key','F8'),later(bind('chat_key','Enter')),
    {head='photo'},
    {key='photo_sync',values={'both','notice','off'},default='both'},
    -- The file's range: 0 (no limit) or 30 to 3600 s; a minute a step, shown in minutes.
    {key='photo_freeze_max',min=30,max=3600,step=60,zero=true,default='600'},
    toggle('photo_ghost','on'),toggle('photo_name_tag','off'),
    {head='partner'},
    reload(toggle('name_tag','on')),toggle('partner_bar','on'),toggle('partner_arrow','on'),toggle('partner_card','on'),
    toggle('card_details','on'), -- Ping and the friend's map on the card.
    {head='ghost'},
    toggle('cloth','off'),toggle('dyes','off'),toggle('effects','off'),later(toggle('basesuit','off')),
    range('send_rate',10,60,5,60), -- 5 a step.
    {head='session'},
    {key='who_can_join',values={'friends','code','private'},default='friends'}, -- At the next host.
    later(toggle('rejoin','on')),
    {head='saves'},
    {key='auto_coop_save',values={'ask','always','off'},default='ask'}, -- At the next title.
    {head='combat'},
    toggle('shared_enemies','on'), -- At once: main.lua asks coop fight on or off.
    -- The host's for both games: at once while shared enemies wait or run (main.lua asks coop fight pilot off or on),
    -- else from their next start.
    toggle('same_place','off'),
    -- The host's values for both games, and our own kill credit: each from the next start of shared enemies. aggro:
    -- who a same-place enemy fights (game: whoever hit it last, or else the nearer player; host: the host only).
    {key='aggro',values={'game','host'},default='game'},
    -- Same spawns (stage 4): where both players stand within 100 m in one zone, the guest's game holds the host's
    -- common enemies there. enemy_extra (stage 4b): that many more of each, used with same spawns only.
    toggle('same_spawns','off'),range('enemy_extra',0,3,1,0),
    range('enemy_hp_scale',1,4,0.05,1.35),range('enemy_balance_scale',1,4,0.05,1.15),
    {key='kill_credit',values={'all','fought'},default='all'},
    {head='display'},
    later(toggle('notices','on')),later(toggle('chat_feed','on')),
    later({key='status_overlay',values={'off','compact','detailed'},default='off'}),
    range('ui_scale',75,150,5,100),toggle('ui_sounds','on'),
    {key='ui_language',values={'game','english'},default='game'},
    {head='chat'},
    toggle('chat','on'),later(range('chat_lines',20,50,5,50)),
}
-- Every key setting a rebind is checked against: the page's, and host_key, off once the menu holds Host (D-UI2).
local KEYS={bind('host_key','none')}
for _,row in ipairs(M.OPTIONS) do if row.bind then KEYS[#KEYS+1]=row end end
-- Every setting's value from the file's text (setting name to value), as the mod takes it (link.parse_settings: the
-- last line it takes, the menu key's migration, the defaults for two actions on one key); a setting it does not read
-- yet, the model's default.
function M.read(text)
    local values,s={},Link.parse_settings(text)
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
-- A key pressed for a rebind (keybind.text's), checked: 'set', key, the value to write; or nil and why: the grammar's
-- reason, or 'clash' and the other setting that holds it.
function M.rebind(values,key,text)
    local new,why=K.parse(key,text)
    if not new then return nil,why end
    local keys={}
    for _,row in ipairs(KEYS) do keys[row.key]=K.parse(row.key,values[row.key] or row.default) end
    local other=K.clash(keys,key,new)
    if other then return nil,'clash',other end
    return 'set',key,new.name
end
function M.new()
    local self,page,id,index,asked={},'main',nil,1,nil -- asked: {id=, at=} the first Select of a confirm row.
    local function name(row) return row.id or row.key end
    function self.page() return page end
    -- The page's rows shown in this state, headers included, but none with no row under it.
    function self.rows(ctx)
        local rows={}
        for _,row in ipairs(page=='main' and M.MAIN or M.OPTIONS) do
            if row.head and rows[#rows] and rows[#rows].head then rows[#rows]=nil end
            if not row.later and (not row.show or row.show(ctx)) then rows[#rows+1]=row end
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
    -- A setting row's next value: 'set', key, text; nil on a key row (rebind), a non-setting row or at a range's end.
    function self.change(ctx,values,dir)
        local row=self.current(ctx)
        if not row.key or row.bind then return nil end
        local value,new=values[row.key],nil
        if row.values then
            local at=1
            for i,v in ipairs(row.values) do if v==value then at=i end end
            new=row.values[(at-1+dir)%#row.values+1]
        else
            local n=math.min(row.max,tonumber(value)+dir*row.step)
            if n<row.min then n=row.zero and 0 or row.min end -- zero: 0 is a value too (no limit), below min.
            new=tostring(math.tointeger(n) or n)
        end
        if new==value then return nil end
        return 'set',row.key,new
    end
    -- Select (now in seconds): the row's id for the caller ('host', 'leave', 'invite', 'copy', 'remove', 'join',
    -- 'join_code', 'chat', 'report', 'close'); 'confirm_leave' or 'confirm_remove' (the row runs on a second Select of
    -- it within 3 s); 'options' (the page changed); 'rebind', key; or a setting's next value, as change().
    function self.select(ctx,now,values)
        local row=self.current(ctx)
        if row.confirm then
            if asked and asked.id==row.id and now-asked.at<=3 then asked=nil; return row.id end
            asked={id=row.id,at=now}
            return 'confirm_'..row.id
        end
        if row.id=='options' then page,id,index='options',nil,1; return 'options' end
        if row.bind then return 'rebind',row.key end
        if row.key then return self.change(ctx,values,1) end
        return row.id
    end
    -- The menu closed (by menu_key; back() calls it for Esc): a first Select on Leave or Remove is forgotten.
    function self.close() asked=nil end
    -- Back (Esc): from Options to the main page, on its Options row; from the main page, 'close'.
    function self.back()
        if page=='main' then self.close(); return 'close' end
        page,id,asked='main','options',nil
        return nil
    end
    return self
end
return M
