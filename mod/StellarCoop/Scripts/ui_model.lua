-- The co-op menu's model (UI-DESIGN 4.1 and its Options table), no engine call: the main page's rows by session state,
-- the Options tree (every co-op setting as a toggle, a choice, a range or a key), a cursor that skips section headers
-- and wraps, Leave only on a second Select within 3 s, values read as the mod reads coop-settings.txt, and each change
-- as the one value to write there (settings_file.set). Rows and values are ids; ui_text gives their words.
local SF=require('settings_file')
local K=require('keybind')
local M={}
-- ctx: {mode=link.mode() ('none', 'host', 'guest', nil before Steam), chat=a friend linked or the loopback running}.
M.MAIN={
    {head='session'},
    {id='host',show=function(c) return c.mode=='none' end},
    {id='leave',show=function(c) return c.mode=='host' or c.mode=='guest' end},
    {id='invite',show=function(c) return c.mode=='host' end},
    {id='join',show=function(c) return c.mode=='none' end},
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
-- Defaults as the file writes them. Keys the mod does not read yet are named here first (the milestone that brings
-- each is in UI-DESIGN's Options table).
M.OPTIONS={
    {head='controls'},
    bind('menu_key','F5'),bind('status_key','F6'),bind('leave_key','F8'),bind('chat_key','Enter'),
    {head='photo'},
    {key='photo_sync',values={'both','notice','off'},default='both'},
    range('photo_freeze_max',60,1800,60,600), -- Seconds, shown in minutes: 1 to 30.
    toggle('photo_ghost','on'),toggle('photo_name_tag','off'),
    {head='partner'},
    toggle('name_tag','on'),toggle('partner_bar','on'),toggle('partner_arrow','on'),toggle('partner_card','on'),
    toggle('card_details','on'), -- Ping and the friend's map on the card.
    {head='ghost'},
    toggle('cloth','off'),toggle('dyes','off'),toggle('effects','off'),toggle('basesuit','off'),
    range('send_rate',10,30,1,20),
    {head='session'},
    {key='who_can_join',values={'friends','private'},default='friends'},
    toggle('rejoin','on'),
    {head='combat'},
    toggle('shared_enemies','off'),
    {head='display'},
    toggle('notices','on'),toggle('chat_feed','on'),
    {key='status_overlay',values={'off','compact','detailed'},default='off'},
    range('ui_scale',75,150,5,100),toggle('ui_sounds','on'),
    {key='ui_language',values={'game','english'},default='game'},
    {head='chat'},
    toggle('chat','on'),range('chat_lines',20,50,5,50),
}
-- Every key setting a rebind is checked against: the page's, and host_key, off once the menu holds Host (D-UI2).
local KEYS={bind('host_key','none')}
for _,row in ipairs(M.OPTIONS) do if row.bind then KEYS[#KEYS+1]=row end end
-- A file value as the menu shows it, or nil when the mod would refuse it.
local function shown(row,value)
    if row.bind then
        local key=K.parse(row.key,value)
        return key and key.name
    end
    if row.values then
        value=value:lower()
        for _,v in ipairs(row.values) do if v==value then return v end end
        return nil
    end
    local n=value:match('^%d+$') and tonumber(value)
    return n and n>=row.min and n<=row.max and tostring(n) or nil
end
-- Every setting's value from the file's text (setting name to value): the last line the mod takes, else the default.
function M.read(text)
    local values={}
    for _,rows in ipairs({M.OPTIONS,KEYS}) do
        for _,row in ipairs(rows) do
            if row.key then
                local value=SF.get(text,row.key,function(v) return shown(row,v)~=nil end)
                values[row.key]=value and shown(row,value) or row.default
            end
        end
    end
    return values
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
    local self,page,id,index,asked={},'main',nil,1,nil -- asked: when Leave was first selected.
    local function name(row) return row.id or row.key end
    function self.page() return page end
    -- The page's rows shown in this state, headers included.
    function self.rows(ctx)
        local rows={}
        for _,row in ipairs(page=='main' and M.MAIN or M.OPTIONS) do
            if not row.show or row.show(ctx) then rows[#rows+1]=row end
        end
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
            new=tostring(math.max(row.min,math.min(row.max,tonumber(value)+dir*row.step)))
        end
        if new==value then return nil end
        return 'set',row.key,new
    end
    -- Select (now in seconds): the row's id for the caller ('host', 'leave', 'invite', 'join', 'chat', 'report',
    -- 'close'); 'confirm_leave' (Leave runs on a second Select within 3 s); 'options' (the page changed); 'rebind',
    -- key; or a setting's next value, as change().
    function self.select(ctx,now,values)
        local row=self.current(ctx)
        if row.id=='leave' then
            if asked and now-asked<=3 then asked=nil; return 'leave' end
            asked=now
            return 'confirm_leave'
        end
        if row.id=='options' then page,id,index='options',nil,1; return 'options' end
        if row.bind then return 'rebind',row.key end
        if row.key then return self.change(ctx,values,1) end
        return row.id
    end
    -- Back (Esc): from Options to the main page, on its Options row; from the main page, 'close'.
    function self.back()
        if page=='main' then return 'close' end
        page,id,asked='main','options',nil
        return nil
    end
    return self
end
return M
