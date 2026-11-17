-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Create a session screen (Host a session, coop host alone): the settings of the online session about to be
-- hosted, on Stellar Blade's own widget parts as the SBO lobby's settings screen draws them (lobby/ui/lobby.lua's C). A
-- window of 10 WB_Setting_Button_Slot rows under WB_Setting_Category headers: SESSION (Who can join, with Friends join
-- without asking under Public and Invitation), SESSION RULES (Shared enemies with its sub-rows while it is on, Shared
-- world, Shared story, Shared quests, Revive), then Start and Back. The focused row's name heads the right
-- pane, over Who can join's value explained, a locked row's reason or why a change was not saved; key hints in
-- WB_Common_IndicatorBtnDefault (Back; Select on Start and Back; Change on a setting). Rows and actions are
-- session/ui/create_model.lua's over main.lua's view(); changes and Start go to main.lua's act().
-- Left and Right (Select too) change a setting: its own line of coop-settings.txt rewritten as Options does
-- (ui/kit/menu.lua's set), so the screen opens on the values in effect and Options stays in step. Start closes the
-- screen and hosts with Who can join's value shown; Back (the row, B, Esc, a right click) closes it without hosting. A
-- row that cannot change shows SB's locked look with its reason on the right: every setting while coop-settings.txt
-- cannot be read. It holds the game's input as 'create' with the mouse cursor, given back 150 ms after a close. It
-- opens in a world outside any lobby only. It closes by itself outside a world, when the game pauses or shows the mouse
-- cursor, when the kit turns off and once we are in a lobby. A transparent kit row over each row takes the mouse, so no
-- part ever sees it. Parts are ui/kit/parts.lua's: every part call runs in pcall, a refusal is logged once, a part that
-- cannot be made is logged once and left out until the mod reloads; its kit fallback draws in its place: rows as kit
-- rows, headers and hints as kit texts. Open, closed and Start each log one line.
local Model=require('session.ui.create_model')
local Options=require('ui.kit.model')
local Parts=require('ui.kit.parts')
local T=require('ui.text')
local THEME=require('ui.kit.kit').THEME
local Create={}
local KINDS={'option','header','hint'}
local HINT_RIGHT,HINT_STEP,HINT_Y=3700,420,1990 -- Key hints, right to left (the lobby's).
local LIST_X,LIST_Y,PITCH,WINDOW=192,384,130,10 -- The lobby's settings list: a window of 10 rows.
local PANE_X,PANE_W=2600,1040 -- The right pane (the lobby's settings).
local HINTS=2 -- Back, then Select or Change.
local HOVER,BACK=0.1,0.15 -- Seconds: between mouse looks; to the input given back.
-- o: {kit=ui.kit's, words=function() the ui/text.lua table to show, view=function() {values= (ui/kit/model.lua's
-- values: the settings in effect), readable= (coop-settings.txt can be read), role=link.mode() or 'none'},
-- act=function(a) (main.lua's: {set=, value=} written as Options writes, false, why and the player's note when not
-- saved; {host=word} hosts with that word), log=}.
function Create.new(o)
    local kit,log=o.kit,o.log or function() end
    local self={}
    local open,world,cur,top=false,false,0,0 -- world: the last slow's shown (a world, our HUD may show).
    local view,items=nil,{} -- As last drawn: what nav acts on.
    local list,pane,hints_p={},{},{} -- Parts by slot.
    local back_at,hover,hover_at=nil,false,0 -- hover: the slot under the mouse at the last look.
    local pointed=false -- The cursor came from the mouse: the list keeps still under it until a key moves the cursor.
    local failed=nil -- A change not saved: {at=its item, text=act's note}, on the right until the next key or click.
    local P=Parts.new(kit,log,'create')
    local call,sync,look=P.call,P.sync,P.look
    for _,kind in ipairs(KINDS) do kit.warm_part(Parts.ASSET[kind]) end
    local function words() return o.words and o.words() or T.en end
    kit.add('create',{x=0,y=0,w=3840,h=2160,hit=true,fixed=true},function(b)
        b.shade(0,0,3840,2160,{R=0,G=0,B=0,A=0.72})
        b.image(0,1860,3840,300,'dither',{R=0,G=0,B=0,A=0.8})
        local v={zones={},hints={}}
        v.page=b.text(3686,72,'','body',THEME.grey,{X=1,Y=0})
        for i=1,WINDOW do v.zones[i]=b.row(LIST_X,LIST_Y+(i-1)*PITCH+27,1640) end
        v.name=b.text(PANE_X,LIST_Y,'','title',THEME.grey)
        v.desc=b.text(PANE_X,LIST_Y+140,'','body',THEME.grey,nil,{wrap=PANE_W})
        for i=1,HINTS do v.hints[i]=b.text(HINT_RIGHT-HINT_STEP*i,HINT_Y+20,'','hint',THEME.text) end
        return v
    end)
    local function read()
        view=o.view()
        items=Model.rows(view)
    end
    local function head_of(t,h) return h=='rules' and t.create.rules or t.head[h] or h end
    local function title_of(t,item)
        if item.id=='start' then return t.create.start end
        if item.id=='back' then return t.hint.back end
        return t.row[item.key] or item.key
    end
    local function value_of(t,item) return item.row and Options.shown(t,item.row,item.value) or '' end
    -- The right pane's words: why a change there was not saved, a locked row's reason, Who can join's value explained,
    -- else none.
    local function desc_of(t,item)
        if not item then return '' end
        if failed and failed.at==cur then return failed.text end
        if item.locked then return t.create.locked end -- Its one reason today: why 'unreadable'.
        if item.key=='who_can_join' then return t.create.who[item.value] or '' end
        return ''
    end
    local function draw()
        local v=open and kit.view('create')
        if not v then return end
        local t=words()
        read()
        if not items[cur] or items[cur].head then cur=Model.move(items,cur,1) end
        top=math.max(0,math.min(top,#items-WINDOW))
        if pointed then top=math.max(0,math.min(math.max(top,cur-WINDOW),cur-1)) -- Moved only to keep cur shown.
        elseif cur<=top+1 then top=math.max(0,cur-2)
        elseif cur>=top+WINDOW then top=math.min(#items-WINDOW,cur-WINDOW+1) end
        local specs={}
        for i=1,WINDOW do
            local item,y=items[top+i],LIST_Y+(i-1)*PITCH
            if not item then specs[i]=false
            elseif item.head then specs[i]=Parts.header(LIST_X,y,head_of(t,item.head))
            else
                local title,value=title_of(t,item),value_of(t,item)
                specs[i]={kind='option',x=LIST_X,y=y,sig=title..'|'..value..(item.locked and '*' or ''),
                    after=item.locked and 'RefreshAppearance' or nil,fill=function(w) -- SB's locked look.
                        w.Text_TitleValue=FText(title)
                        w.Text_ItemValue=FText(value)
                        if item.locked then w.bLockItem=true end
                    end}
            end
        end
        sync(list,'create',specs,WINDOW)
        for i=1,WINDOW do
            local rec,item=list[i],items[top+i]
            if rec and rec.kind=='option' then look(rec,top+i==cur and 'focus' or 'normal') end
            -- The kit fallback: an item with no SB part shows on the kit row under it.
            if not item or kit.alive(rec) then v.zones[i].set('','')
            elseif item.head then v.zones[i].set(head_of(t,item.head),'','disabled')
            else
                v.zones[i].set(title_of(t,item),value_of(t,item),
                    item.locked and 'disabled' or top+i==cur and 'focus' or 'normal')
            end
        end
        v.page.set(t.create.title)
        local item=items[cur]
        local name=item and title_of(t,item) or ''
        sync(pane,'create',{item and Parts.header(PANE_X,LIST_Y,name) or false},1)
        v.name.set(item and not kit.alive(pane[1]) and name or '')
        v.desc.set(desc_of(t,item))
        -- Each hint: its label, its icons and its keyboard keys for the fallback.
        local shown={{t.hint.back,'Negative',nil,'Esc'}}
        if item and item.action then shown[2]={t.hint.select,'Positive',nil,'Enter'}
        elseif item and not item.locked then
            shown[2]={t.lobby.hint.change,'UI_DPad_Left','UI_DPad_Right',kit.azerty() and 'Q D' or 'A D'}
        end
        local specs_h={}
        for i,h in ipairs(shown) do specs_h[i]=Parts.hint(HINT_RIGHT-HINT_STEP*i,HINT_Y,h[1],h[2],h[3]) end
        sync(hints_p,'create',specs_h,HINTS)
        for i,h in ipairs(v.hints) do
            h.set(shown[i] and not kit.alive(hints_p[i]) and shown[i][4]..'  '..shown[i][1] or '')
        end
    end
    -- The item under the mouse (headers never) or nil, then its slot.
    local function under()
        local v=kit.view('create')
        if not v then return nil end
        for i,zone in ipairs(v.zones) do
            if zone.hovered() then
                local item=items[top+i]
                return item and not item.head and top+i or nil,i
            end
        end
    end
    function self.is_open() return open end
    -- Opens the screen, taking the game's input with the mouse cursor: true and a line for the console, or false and
    -- why (English, for the log) where the co-op menu would not open either (the kit off, outside a world, the game
    -- paused or showing a menu) and in a lobby (coop host then asks the native part, which opens the invite dialog
    -- again for a host).
    function self.open()
        if kit.off() then return false,'Create a session is off: the UI stopped (see the log)' end
        if not (world and kit.ready()) then return false,'Create a session opens in the game world only' end
        if kit.paused() then return false,'Create a session does not open while the game is paused or shows a menu' end
        if o.view().role~='none' then return false,'Create a session opens outside a lobby only' end
        if not open then
            kit.input(true,'create',true)
            kit.sound('open')
            open,back_at,hover,pointed,failed,cur,top=true,nil,false,false,nil,0,0
            log('create: open')
        end
        kit.show('create',true)
        draw()
        return true,'Create a session is open'
    end
    -- Closed; the game's input back BACK s later.
    function self.close()
        if not open then return end
        open=false
        log('create: closed')
        kit.sound('close')
        kit.show('create',false)
        back_at=os.clock()+BACK
    end
    -- A key or the mouse: 'up', 'down', 'left', 'right', 'select', 'back', or 'click' (a left click: the row under the
    -- mouse takes the cursor and Select runs). Any other word draws again.
    function self.nav(what)
        if not open then return end
        if kit.off() then return self.close() end
        if not view then read() end
        failed=nil
        if what=='click' then
            local i=under()
            if not i then return end
            cur,what,pointed=i,'select',true
        end
        local item=items[cur]
        if what=='up' or what=='down' then
            pointed=false
            cur=Model.move(items,cur,what=='up' and -1 or 1)
            kit.sound('move')
        elseif what=='left' or what=='right' or what=='select' then
            local a
            if what=='select' then a=Model.select(view,item) else a=Model.change(item,what=='left' and -1 or 1) end
            if a and a.host then -- SB's setting confirm sound, from the row; closed first, as the invite dialog opens.
                call(list[cur-top],'option select',function(w) w:EventNotification('StateSelect') end)
                log('create: start '..a.host)
                self.close()
                return o.act(a)
            elseif a and a.back then
                kit.sound('back')
                return self.close()
            elseif a then -- Not saved (act's false): no change sound, the reason on the right.
                local saved,why,note=o.act(a)
                if saved==false then failed={at=cur,text=note or tostring(why)} else kit.sound('change') end
            end
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
        world=shown==true
        if open then
            read()
            if not shown or kit.off() or kit.paused() or view.role~='none' then self.close() end
        end
        if not (open or back_at) then kit.input(false,'create') end
        draw()
    end
    -- Each frame: the input given back once due; every 100 ms while open, the row the mouse moved onto (another slot
    -- than at the last look) takes the cursor, the list kept still under it. A resting mouse never does, even while
    -- the keys scroll the list under it.
    function self.tick(now)
        if back_at and now>=back_at then
            back_at=nil
            kit.input(false,'create')
        end
        if open and now>=hover_at then
            hover_at=now+HOVER
            local i,slot=under()
            local moved=hover~=false and slot~=hover
            hover=slot
            if moved and i then
                cur,pointed=i,true
                kit.sound('move')
                draw()
            end
        end
    end
    return self
end
return Create
