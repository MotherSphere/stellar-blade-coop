-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Sessions screen (Find a session, INTEGRATION 7a): the open online sessions the native part's list found, on
-- Stellar Blade's own widget parts as the SBO lobby's settings screen draws them (ui/lobby.lua's C). Two tabs, Public
-- and Friends (SB's UI_Friends), on the shoulder buttons, Q and E (A and E on AZERTY) or a click; a WB_Setting_Category
-- header naming the tab over a window of 8 WB_Setting_Button_Slot rows (the host's name; the region, the players and
-- the ping), focused by StateFocus and StateNormal; the status line under them (SB's UI_Night_SearchPartner while a
-- search runs); the focused row's details on the right (its host's name as a header, the region, the camp, the players
-- and ping, the session rules, a Steam friend mark, the version); the player's own protocol and game build at the
-- bottom left; key hints (Select: Ask to join, Refresh, Back) in WB_Common_IndicatorBtnDefault. Rows, statuses and
-- requests are ui/sessions_model.lua's over main.lua's view(); requests go to main.lua's act().
-- It opens on the last tab of this Lua load and asks for a search of it, as a tab change and Refresh (Y, F) do, one at
-- a time and 5 s apart at least; there is no search by itself. Refresh while our search runs stops it (its hint then
-- reads SB's UI_Cancel); a tab change leaves it running. Select on a row asks to join its lobby at once and closes
-- the screen. Back (B, Esc, a right click) closes it. It holds the game's input as 'sessions' with the mouse cursor,
-- given back 150 ms after a close; it closes by itself outside a world, when the game pauses or shows the mouse
-- cursor, when the kit turns off and once we are in a lobby. A transparent kit row over each row and tab takes the
-- mouse, so no part ever sees it.
-- SB's words come from its StringTable_UI through game_text (o.game_text, nil under ui_language=english), read once a
-- key while the screen is open; SBO's words are ui/text.lua's. Parts are ui/parts.lua's: every part call runs in pcall,
-- a refusal is logged once, a part that cannot be made is logged once and left out until the mod reloads. Its kit
-- fallback draws in its place: rows as kit rows, headers and hints as kit texts.
-- Open, closed and a join asked each log one line.
local Model=require('ui.sessions_model')
local Parts=require('ui.parts')
local T=require('ui.text')
local THEME=require('ui.kit').THEME
local Sessions={}
local KINDS={'option','header','hint'}
local HINT_RIGHT,HINT_STEP,HINT_Y=3700,420,1990 -- Key hints, right to left (the lobby's).
local LIST_X,LIST_Y,PITCH,WINDOW=192,384,130,8 -- The list's header, then a window of 8 rows under it.
local ROWS_Y=LIST_Y+PITCH
local STATUS_Y=ROWS_Y+WINDOW*PITCH+20
local PANE_X,PANE_W=2600,1040 -- The details pane (C's right pane).
local TAB_X,TAB_STEP=236,360
local HOVER,BACK=0.1,0.15 -- Seconds: between mouse looks; to the input given back.
-- The hints' keyboard keys, in their fallback (right to left: Back, Refresh, Select).
local KEYS={'Esc','F','Enter'}
-- o: {kit=ui.kit's, words=function() the ui/text.lua table to show, view=function() {search=, rows= (link.list()'s),
-- match=link.match(), role=link.mode() or 'none', proto=, build= (ours, from the status)}, act=function({request=})
-- (main.lua's: a link request, logged), game_text=function(key) SB's word or nil, log=}.
function Sessions.new(o)
    local kit,log=o.kit,o.log or function() end
    local self={}
    local open,tab,cur,top=false,Model.TABS[1],0,0
    local asked=nil -- When we last asked for a search (os.clock).
    local view,input=nil,nil -- As last drawn: what nav acts on.
    local icons,head,list,pane,hints_p={},{},{},{},{} -- Parts by slot.
    local back_at,hover,hover_at=nil,false,0
    local said={} -- SB's words read while open (false: none).
    local P=Parts.new(kit,log,'sessions')
    local call,sync,look=P.call,P.sync,P.look
    for _,kind in ipairs(KINDS) do kit.warm_part(Parts.ASSET[kind]) end
    local function words() return o.words and o.words() or T.en end
    local function game(key)
        if said[key]==nil then said[key]=o.game_text and o.game_text(key) or false end
        return said[key] or nil
    end
    kit.add('sessions',{x=0,y=0,w=3840,h=2160,hit=true,fixed=true},function(b)
        b.shade(0,0,3840,2160,{R=0,G=0,B=0,A=0.72})
        b.image(0,1860,3840,300,'dither',{R=0,G=0,B=0,A=0.8})
        local v={tabs={},zones={},hints={}}
        v.page=b.text(3686,72,'','body',THEME.grey,{X=1,Y=0})
        for i=1,#Model.TABS do
            local x=TAB_X+(i-1)*TAB_STEP
            v.tabs[i]={zone=b.row(x-20,120,320),label=b.text(x,120,'','item'),line=b.image(x,180,280,6,nil,THEME.text)}
        end
        v.keys={b.text(86,120,'','item',THEME.grey),b.text(TAB_X+#Model.TABS*TAB_STEP,120,'','item',THEME.grey)}
        v.head=b.text(LIST_X,LIST_Y,'','title',THEME.grey)
        for i=1,WINDOW do v.zones[i]=b.row(LIST_X,ROWS_Y+(i-1)*PITCH+27,1640) end
        v.status=b.text(LIST_X+36,STATUS_Y,'','name',THEME.grey,nil,{wrap=1600})
        v.name=b.text(PANE_X,LIST_Y,'','title',THEME.grey)
        v.region=b.text(PANE_X,LIST_Y+140,'','item',THEME.white)
        v.camp=b.text(PANE_X,LIST_Y+210,'','body',THEME.grey)
        v.players=b.text(PANE_X,LIST_Y+280,'','body',THEME.text)
        v.rules=b.text(PANE_X,LIST_Y+350,'','body',THEME.text,nil,{wrap=PANE_W})
        v.dot=b.image(PANE_X,LIST_Y+574,32,32,'link',THEME.teal)
        v.friend=b.text(PANE_X+56,LIST_Y+560,'','body',THEME.teal)
        v.version=b.text(PANE_X,LIST_Y+630,'','body',THEME.grey,nil,{wrap=PANE_W})
        for i=1,#KEYS do v.hints[i]=b.text(HINT_RIGHT-HINT_STEP*i,HINT_Y+20,'','hint',THEME.text) end
        v.foot=b.text(LIST_X,HINT_Y+10,'','status',THEME.grey,nil,{wrap=2200})
        v.dot.show(false)
        return v
    end)
    local function read()
        input=o.view()
        view=Model.view({tab=tab,search=input.search,rows=input.rows,match=input.match,asked=asked,now=os.clock()})
    end
    -- A tab's name: SB's own for Friends, else the Options words for Public and Friends only.
    local function tab_name(t,id)
        if id=='friends' then return game('UI_Friends') or t.value.who_can_join_friends end
        return t.value.who_can_join_public
    end
    local function name_of(t,r) return r.name or t.ask.someone end
    -- A row's region in the game's words, else its zone word as written.
    local function region(r)
        for _,key in ipairs(Model.region(r.zone) or {}) do
            local w=game(key)
            if w then return w end
        end
        return r.zone or ''
    end
    local function players(r) return r.players..' · '..(r.ping and r.ping..' ms' or '-') end -- '-': no ping known.
    local function value_of(r)
        local where=region(r)
        return (where~='' and where..' · ' or '')..players(r)
    end
    -- The rules on, by their Options names, then the boss HP scale with shared bosses.
    local function rules_of(t,r)
        local ids=Model.rules(r.rules)
        if not ids then return '' end
        local out={}
        for i,id in ipairs(ids) do out[i]=t.row[id] or id end
        if ids.boss then out[#out+1]=t.row.boss_hp_scale..' '..t.percent:format(ids.boss) end
        return table.concat(out,' · ')
    end
    local function status_of(t)
        local s=view.status
        if not s then return '' end
        if s.key=='searching' then return game('UI_Night_SearchPartner') or t.lobby.status.searching end
        if s.key=='wait' then return t.sessions.wait:format(s.args[1]) end
        return t.sessions[s.key]
    end
    local function hints(specs)
        local out={}
        for i,h in ipairs(specs) do out[i]=Parts.hint(HINT_RIGHT-HINT_STEP*i,HINT_Y,h[1],h[2]) end
        return out
    end
    local function draw()
        local v=open and kit.view('sessions')
        if not v then return end
        local t=words()
        read()
        local rows=view.rows
        cur=#rows==0 and 0 or math.max(1,math.min(cur,#rows))
        top=math.max(0,math.min(top,#rows-WINDOW))
        if cur>0 and cur<=top+1 then top=math.max(0,cur-2)
        elseif cur>=top+WINDOW then top=math.min(#rows-WINDOW,cur-WINDOW+1) end
        v.page.set(t.row.find)
        for i,id in ipairs(Model.TABS) do
            v.tabs[i].label.set(tab_name(t,id))
            v.tabs[i].label.color(id==tab and THEME.text or THEME.dim)
            v.tabs[i].line.show(id==tab)
        end
        sync(icons,'sessions',{Parts.hint(86,120,'','UI_LeftShoulder'),
            Parts.hint(TAB_X+#Model.TABS*TAB_STEP,120,'','UI_RightShoulder')},2)
        v.keys[1].set(kit.alive(icons[1]) and '' or kit.azerty() and 'A' or 'Q')
        v.keys[2].set(kit.alive(icons[2]) and '' or 'E')
        sync(head,'sessions',{Parts.header(LIST_X,LIST_Y,tab_name(t,tab))},1)
        v.head.set(kit.alive(head[1]) and '' or tab_name(t,tab))
        local specs={}
        for i=1,WINDOW do
            local r=rows[top+i]
            if r then
                local title,value=name_of(t,r),value_of(r)
                specs[i]={kind='option',x=LIST_X,y=ROWS_Y+(i-1)*PITCH,sig=title..'|'..value,fill=function(w)
                    w.Text_TitleValue=FText(title)
                    w.Text_ItemValue=FText(value)
                end}
            else specs[i]=false end
        end
        sync(list,'sessions',specs,WINDOW)
        for i=1,WINDOW do
            local rec,r=list[i],rows[top+i]
            if rec then look(rec,top+i==cur and 'focus' or 'normal') end
            if not r or kit.alive(rec) then v.zones[i].set('','') -- The kit's row under a part takes the mouse only.
            else v.zones[i].set(name_of(t,r),value_of(r),top+i==cur and 'focus' or 'normal') end
        end
        v.status.set(status_of(t))
        local r=rows[cur]
        sync(pane,'sessions',{r and Parts.header(PANE_X,LIST_Y,name_of(t,r)) or false},1)
        v.name.set(r and not kit.alive(pane[1]) and name_of(t,r) or '')
        local camp=r and r.camp and game(Model.camp(r.camp))
        v.region.set(r and region(r) or '')
        v.camp.set(camp or '')
        v.players.set(r and players(r) or '')
        v.rules.set(r and rules_of(t,r) or '')
        v.dot.show(r~=nil and r.pal)
        v.friend.set(r and r.pal and t.sessions.friend or '')
        local proto,build=tostring(input.proto or '-'),tostring(input.build or '-')
        v.version.set(r and t.sessions.version:format(proto,build) or '')
        v.foot.set(t.sessions.footer:format(proto,build))
        local refresh=view.ours and (game('UI_Cancel') or t.lobby.row.cancel) or t.sessions.refresh
        -- Y's icon: UI_FaceButton_Top, SB's UI action for the top face button. The 26123051 exe names it beside
        -- UI_FaceButton_Bottom (WB_Common_Popup's hint action) and UI_LeftShoulder (our tab hint) in one switch
        -- (FUN_14254baf0); SB's key map binds it to the pad's Y and the keyboard's F, so F is our Refresh key.
        local shown={{t.hint.back,'Negative'},{refresh,'UI_FaceButton_Top'},r and {t.sessions.ask,'Positive'} or nil}
        sync(hints_p,'sessions',hints(shown),#KEYS)
        for i,h in ipairs(v.hints) do
            h.set(shown[i] and not kit.alive(hints_p[i]) and KEYS[i]..'  '..shown[i][1] or '')
        end
    end
    -- Refresh: a search of this tab, or our running one stopped, from a fresh view; true when one was asked.
    local function search()
        read()
        local request=Model.refresh(view)
        if not request then return false end
        if request~='list stop' then asked=os.clock() end
        o.act({request=request})
        return true
    end
    -- A tab change asks for the new tab's search. Our running search goes on (Refresh alone stops it): stopping it
    -- here would lose its rows while the 5 s gap held the new one back.
    local function set_tab(id)
        if id~=tab then
            tab,cur,top=id,1,0
            kit.sound('change')
            read()
            if not view.ours then search() end
        end
        draw()
    end
    -- The row under the mouse, or nil and a tab id.
    local function under()
        local v=kit.view('sessions')
        if not (v and view) then return nil end
        for i,tb in ipairs(v.tabs) do if tb.zone.hovered() then return nil,Model.TABS[i] end end
        for i,zone in ipairs(v.zones) do
            if view.rows[top+i] and zone.hovered() then return top+i end
        end
    end
    function self.is_open() return open end
    -- Opens the screen, taking the game's input with the mouse cursor; asks for a search of its tab when it may.
    -- false and why (English, for the log) when the kit is off or not up.
    function self.open()
        if kit.off() then return false,'Find a session is off: the UI stopped (see the log)' end
        if not kit.ready() then return false,'Find a session opens in the game world only' end
        if not open then
            kit.input(true,'sessions',true)
            kit.sound('open')
            open,back_at,hover,cur,top,said=true,nil,false,1,0,{}
            log('sessions: open '..tab)
        end
        kit.show('sessions',true)
        search()
        draw()
        return true
    end
    -- Closed; the game's input back BACK s later.
    function self.close()
        if not open then return end
        open=false
        log('sessions: closed')
        kit.sound('close')
        kit.show('sessions',false)
        back_at=os.clock()+BACK
    end
    -- A key or the mouse: 'up', 'down', 'select', 'back', 'tab_left', 'tab_right', 'refresh', or 'click' (a left click:
    -- a tab under the mouse is picked; a row takes the cursor and Select runs).
    function self.nav(what)
        if not open then return end
        if kit.off() then return self.close() end
        if not view then read() end
        if what=='click' then
            local i,id=under()
            if id then return set_tab(id) end
            if not i then return end
            cur,what=i,'select'
        end
        if what=='up' or what=='down' then
            if #view.rows>0 then
                cur=Model.move(#view.rows,cur,what=='up' and -1 or 1)
                kit.sound('move')
            end
        elseif what=='tab_left' or what=='tab_right' then return set_tab(Model.other(tab))
        elseif what=='refresh' then
            if search() then kit.sound('change') end
        elseif what=='select' then -- SB's setting confirm sound, from the row.
            local request=Model.select(view,cur)
            if not request then return draw() end
            call(list[cur-top],'option select',function(w) w:EventNotification('StateSelect') end)
            log('sessions: ask to join lobby '..view.rows[cur].lobby)
            o.act({request=request})
            return self.close()
        elseif what=='back' then
            kit.sound('back')
            return self.close()
        end
        draw()
    end
    -- Each 250 ms: closed outside a world (shown false), when the game pauses or shows its cursor, when the kit turned
    -- off and once we are in a lobby; else drawn from a fresh view (parts made again after a root build). While closed,
    -- the game's input given back again until the kit has given it.
    function self.slow(shown)
        if open then
            read()
            if not shown or kit.off() or kit.paused() or input.role~='none' then self.close() end
        end
        if not (open or back_at) then kit.input(false,'sessions') end
        draw()
    end
    -- Each frame: the input given back once due; every 100 ms while open, the row the mouse moved onto takes the cursor
    -- (a resting mouse never does).
    function self.tick(now)
        if back_at and now>=back_at then
            back_at=nil
            kit.input(false,'sessions')
        end
        if open and now>=hover_at then
            hover_at=now+HOVER
            local i,id=under()
            local key=i or id
            local moved=hover~=false and key~=hover
            hover=key
            if moved and i then
                cur=i
                kit.sound('move')
                draw()
            end
        end
    end
    return self
end
return Sessions
