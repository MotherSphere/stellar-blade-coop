-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The SBO lobby's screens on Stellar Blade's own widget parts (design-lobby 4.3 to 4.5, L4-menus-b-c 2 and 3): the
-- lobby menu B (SB's title-menu rows under its logo, the status beside Search or Cancel, the members box, the key
-- hints), the settings C (SB's option rows and headers in two tabs, the members and the mode on the right), the leave
-- question (SB's popup), the countdown (SB's HUD timer) and the waiting room's overlay. ui/kit/kit.lua owns the frame,
-- the input (held as 'lobby', with the mouse cursor) and the focus; the SB parts are its children (kit.part), filled
-- before they enter the canvas, HitTestInvisible but the popup, never focused, and sent only the calls L4 2 allows:
-- rows SelectAnimation, NormalAnimation and PressAccept; option rows StateNormal, StateFocus, StateSelect and
-- RefreshAppearance; hints SetText, SetResourceAction(2) and SetButtonClickable(false); the popup RefreshAll, its
-- Accept or close animation and sound; the countdown UpdateTimer and StartTimer. A transparent kit row over each row
-- takes the mouse, so no part ever sees it. A part is made on the first draw after a root build (a map change or the
-- look warmed drops them all) and again when its slot's content changes. Rows, words and actions are
-- online/lobby/ui/lobby_model.lua's over main.lua's view(); what a row asks for goes to main.lua's act(). The parts are
-- made and driven through ui/kit/parts.lua: every part call runs in pcall; a refusal is logged once; a part that cannot
-- be made is logged once and left out until the mod reloads.
-- B or C opened, both closed, the question asked and answered, and C's Back each log one line (the focus watchdog's
-- context).
-- Ruling 5's fallback then draws the same shape with the kit: B's and C's rows as kit rows (the mouse zones' own
-- label, value and focus look), the leave question as kit texts with Yes and No rows, the countdown as a kit number.
-- Key hints and C's two pane headers have no fallback.
local U=require('core.unreal')
local Model=require('online.lobby.ui.lobby_model')
local T=require('ui.text')
local Parts=require('ui.kit.parts')
local THEME=require('ui.kit.kit').THEME
local culture=require('ui.text.culture').culture
local Lobby={}
local STATICS='/Script/Engine.Default__GameplayStatics'
-- The six parts (L4 1.2), in the parts check's order (ui/kit/parts.lua's).
local ORDER,ASSET,CLASS=Parts.ORDER,Parts.ASSET,Parts.CLASS
local hint,header=Parts.hint,Parts.header
-- B's stack in units (WB_Lobby's own, L4 3.1): rows 106 apart, the mode text's block (my call 12) 20 under the mode
-- rows and 36 above the action rows, the list's bottom at 2000, the 512-unit logo 115 above the list.
local PITCH,TEXT,DESC_GAP,ACTION_GAP,BOTTOM,LOGO,LOGO_GAP=106,94,20,36,2000,512,115
local ROW_X,SIDE=172,600 -- B's rows; the status and the soon tag, that far right of a row.
local ACTIONS=6 -- The most action rows (idle's); their slots are bottom-aligned, the same in every layout.
local HINT_RIGHT,HINT_STEP,HINT_Y=3700,420,1990 -- Key hints, right to left.
local LIST_X,LIST_Y,LIST_PITCH,WINDOW=192,384,130,10 -- C's list: a window of 10 slots.
local PANE_X,PANE_W,PANE_MODE_Y=2600,1040,1010 -- C's right pane; its mode header.
local HOVER,BACK,GONE=0.1,0.15,0.25 -- Seconds: between mouse looks; to the input given back; to the popup removed.
local SHADOW={2,2,0,0,0,0.8}
local TONE={grey=THEME.grey,warn=THEME.warn,teal=THEME.teal,error=THEME.error}
local MARK={ok=THEME.teal,warn=THEME.warn,error=THEME.error}
local MODES={ffa=true,more=true}
local TABS={'match','sbo'}
-- B's layout for n_mode mode rows and n_action action rows: {top, rows={y...}, text_y (the mode text), logo_y}.
function Lobby.layout(n_mode,n_action)
    local top=BOTTOM-PITCH*(n_mode+n_action)-DESC_GAP-TEXT-ACTION_GAP
    local L={top=top,rows={},text_y=top+PITCH*n_mode+DESC_GAP,logo_y=top-LOGO_GAP-LOGO}
    for i=1,n_mode+n_action do
        L.rows[i]=i<=n_mode and top+(i-1)*PITCH or L.text_y+TEXT+ACTION_GAP+(i-n_mode-1)*PITCH
    end
    return L
end
-- The block that moves with the row count (logo, sub-logo, mode rows' mouse zones, mode text) is drawn at idle's
-- layout in its own group, which kit.move places for the others (kit texts and images have no place of their own).
local BASE=Lobby.layout(2,ACTIONS)
-- A word of a table by its dotted key ('status.open'), formatted with args when given; the key when there is none.
local function word(t,key,args)
    local w=t
    for k in key:gmatch('[^.]+') do w=type(w)=='table' and w[k] or nil end
    if type(w)~='string' then return key end
    return args and #args>0 and w:format(table.unpack(args)) or w
end
-- o: {kit=ui.kit.kit's, words=function() the ui/text.lua table to show, view=function() Model.view's input
-- (main.lua's), act=function(action) (Model.act's shapes, and C's {set=, value=}, {request=}, {run='report'}), log=}.
function Lobby.new(o)
    local kit,log=o.kit,o.log or function() end
    local self={}
    local screen,tab=nil,TABS[1] -- 'menu' (B), 'settings' (C) or nil; C's tab.
    -- B's cursor (a row index; nil: the first action row); C's (an item index); C's first item shown less one.
    local cur_b,cur_c,top=nil,0,0
    local view,input,items,modes=nil,nil,{},2 -- As last drawn: what nav acts on.
    local rows_b,hints_b,list_c,icons_c,pane_c,hints_c={},{},{},{},{},{} -- Parts by slot.
    -- The popup asking ({id, rec, on_answer, took}); one answered, removed at its time ({rec, at}).
    local ask,leaving=nil,nil
    local timer,counting=nil,nil -- The countdown part; Model.count's state.
    local room_on,back_at,hover,hover_at=false,nil,false,0
    local P=Parts.new(kit,log,'lobby')
    local call,make,sync,look,broken=P.call,P.make,P.sync,P.look,P.broken
    for _,kind in ipairs(ORDER) do kit.warm_part(ASSET[kind]) end
    local function words() return o.words and o.words() or T.en end
    local function hints(list)
        local specs={}
        for i,h in ipairs(list) do specs[i]=hint(HINT_RIGHT-HINT_STEP*i,HINT_Y,h[1],h[2],h[3]) end
        return specs
    end
    -- Eight member rows (a mark, the name, its tag, the ping or the link's word at the right edge).
    local function members_view(b,x,y,pitch,width,style)
        local list={}
        for i=1,8 do
            local ry=y+(i-1)*pitch
            list[i]={dot=b.image(x,ry+14,32,32,'link'),name=b.text(x+56,ry,'',style,THEME.white),
                tag=b.text(x+width-420,ry+10,'','status',THEME.grey),
                ping=b.text(x+width,ry+4,'','num',THEME.text,{X=1,Y=0})}
        end
        return list
    end
    -- Our row first ('you', and 'host' when we host; no name: the tag alone), then the others; where the ping would
    -- be, the link's word (connecting, lost) while it is not ok.
    local function show_members(list,t,shows)
        for i,row in ipairs(list) do
            local m=shows and view.members[i] or nil
            row.dot.show(m~=nil)
            if m then row.dot.tint(MARK[m.mark]) end
            row.name.set(m and m.name or '')
            row.tag.set(m and (m.you and t.lobby.you..(m.host and ' · '..t.lobby.host or '') or m.host and t.lobby.host)
                or '')
            row.ping.set(m and (m.link~='ok' and t.lobby[m.link] or m.ping and m.ping..' ms') or '')
            row.ping.color(m and m.mark~='ok' and MARK[m.mark] or THEME.text)
        end
    end
    -- The members box lists a lobby; idle and searching it shows why there is none.
    local function listed() return view.state~='idle' and view.status.key~='status.searching' end
    kit.add('lobby',{x=0,y=0,w=3840,h=2160,hit=true,fixed=true},function(b)
        b.image(0,0,880,2160,'shade_left')
        b.image(0,610,3840,1550,'shade_bottom')
        local v={slots={}}
        for k=1,ACTIONS do
            local y=BASE.rows[2+k]
            v.slots[k]={zone=b.row(ROW_X,y+15,624),
                status=b.text(ROW_X+SIDE,y+32,'','body',THEME.grey,nil,{shadow=SHADOW})}
        end
        b.image(2540,800,1180,1120,'more_shadow',{R=1,G=1,B=1,A=0.55})
        v.head=b.text(2660,880,'','title',THEME.grey)
        v.count=b.text(3600,880,'','title',THEME.white,{X=1,Y=0})
        v.note=b.text(2660,960,'','body')
        v.empty=b.text(2660,1040,'','item',THEME.grey,nil,{wrap=940})
        v.members=members_view(b,2660,1040,84,940,'item')
        return v
    end)
    kit.add('lobby_top',{x=0,y=0,w=3840,h=2160,hit=true,fixed=true},function(b)
        local v={logos={},slots={}}
        for _,name in ipairs({'logo','logo_hans','logo_hant'}) do
            v.logos[name]=b.image(170,BASE.logo_y,2048,LOGO,name)
        end
        v.sub=b.text(224,BASE.logo_y+LOGO-8,'','item',THEME.grey,{X=0,Y=1},{shadow=SHADOW})
        for i=1,2 do
            local y=BASE.rows[i]
            v.slots[i]={zone=b.row(ROW_X,y+15,624),
                tag=b.text(ROW_X+SIDE,y+32,'','status',THEME.dim,nil,{shadow=SHADOW})}
        end
        v.desc=b.text(ROW_X+61,BASE.text_y,'','name',THEME.grey,nil,{shadow=SHADOW,wrap=1280})
        return v
    end)
    kit.add('lobby_settings',{x=0,y=0,w=3840,h=2160,hit=true,fixed=true},function(b)
        b.shade(0,0,3840,2160,{R=0,G=0,B=0,A=0.72})
        b.image(0,1860,3840,300,'dither',{R=0,G=0,B=0,A=0.8})
        local v={tabs={},zones={}}
        v.page=b.text(3686,72,'','body',THEME.grey,{X=1,Y=0})
        for i=1,#TABS do
            local x=236+(i-1)*360
            v.tabs[i]={zone=b.row(x-20,120,320),label=b.text(x,120,'','item'),line=b.image(x,180,280,6,nil,THEME.text)}
        end
        for i=1,WINDOW do v.zones[i]=b.row(LIST_X,LIST_Y+(i-1)*LIST_PITCH+27,1640) end
        v.members=members_view(b,PANE_X+12,LIST_Y+140,60,PANE_W-12,'name')
        v.desc=b.text(PANE_X,PANE_MODE_Y+130,'','body',THEME.grey,nil,{wrap=PANE_W})
        return v
    end)
    -- The question's and the countdown's fallbacks (ruling 5), empty while SB's parts are made.
    kit.add('lobby_popup',{x=0,y=0,w=3840,h=2160,hit=true,fixed=true},function(b)
        local v={back=b.image(1220,760,1400,600,nil,{R=0,G=0,B=0,A=0.85})}
        v.title=b.text(1320,820,'','title',THEME.text)
        v.desc=b.text(1320,920,'','body',THEME.grey,nil,{wrap=1200})
        v.yes,v.no=b.row(1320,1110,1200),b.row(1320,1210,1200)
        v.back.show(false)
        return v
    end)
    kit.add('lobby_count',{x=1620,y=72,w=600,h=160,fixed=true,shown=true},function(b)
        return {num=b.text(300,20,'','title',THEME.text,{X=0.5,Y=0},{shadow=SHADOW})}
    end)
    -- x clears SB's bottom-left HUD icons (up to x 221), which the room keeps.
    kit.add('lobby_room',{x=260,y=1900,w=2000,h=160},function(b)
        return {line=b.text(0,0,'','name',THEME.text,nil,{shadow=SHADOW}),
            key=b.text(0,70,'','hint',THEME.grey,nil,{shadow=SHADOW})}
    end)
    local function show_groups()
        kit.show('lobby',screen=='menu')
        kit.show('lobby_top',screen=='menu')
        kit.show('lobby_settings',screen=='settings')
        kit.show('lobby_room',room_on and not screen)
    end
    local function read()
        input=o.view()
        view=Model.view(input)
    end
    -- B's action slot k holds the row j-th from the first action row (bottom-aligned), or none.
    local function slot_row(k)
        local j=k-(ACTIONS-(#view.rows-modes))
        return j>=1 and modes+j or nil
    end
    local function draw_menu()
        local v,tv=kit.view('lobby'),kit.view('lobby_top')
        if not (v and tv) then return end
        local t=words()
        read()
        local rows=view.rows
        modes=0
        for _,r in ipairs(rows) do if MODES[r.id] then modes=modes+1 end end
        local L=Lobby.layout(modes,#rows-modes)
        cur_b=math.max(1,math.min(cur_b or modes+1,#rows))
        kit.move('lobby_top',0,L.top-BASE.top)
        local c=culture(kit.language())
        local logo=c=='zh-Hans' and 'logo_hans' or c=='zh-Hant' and 'logo_hant' or 'logo' -- As WB_Lobby picks it.
        for name,img in pairs(tv.logos) do img.show(name==logo) end
        tv.sub.set(t.lobby.sub)
        local specs,labels={},{}
        for i,row in ipairs(rows) do -- Labels (R24): mode.ffa, row.more, row.<id>.
            local label=row.id=='ffa' and t.lobby.mode.ffa or word(t.lobby.row,row.id,row.args)
            labels[i]=label
            specs[i]={kind='row',x=ROW_X,y=L.rows[i],sig=label..(row.locked and '*' or ''),fill=function(w)
                w.Text_Value=FText(label)
                if row.locked then w:SetIsEnabled(false) end -- Before the canvas: Construct plays Disable.
            end}
        end
        sync(rows_b,'lobby',specs,modes+ACTIONS)
        for i,row in ipairs(rows) do look(rows_b[i],i==cur_b and not row.locked and 'select' or 'normal') end
        -- Ruling 5's fallback: a row with no SB part shows its label on the kit row under it.
        local function kit_row(zone,i)
            local row=i and rows[i]
            if not row or kit.alive(rows_b[i]) then return zone.set('','') end
            zone.set(labels[i],'',row.locked and 'disabled' or i==cur_b and 'focus' or 'normal')
        end
        for i,slot in ipairs(tv.slots) do kit_row(slot.zone,i<=modes and i or nil) end
        for k,slot in ipairs(v.slots) do kit_row(slot.zone,slot_row(k)) end
        local cur=rows[cur_b]
        tv.desc.set(t.lobby.desc[cur and cur.id=='more' and 'more' or 'ffa'])
        for i,slot in ipairs(tv.slots) do slot.tag.set(rows[i] and rows[i].id=='more' and t.lobby.tag.soon or '') end
        local status,tone=word(t.lobby,view.status.key,view.status.args),TONE[view.status.tone] or THEME.grey
        for k,slot in ipairs(v.slots) do
            local row=rows[slot_row(k) or 0]
            slot.status.set(row and (row.id=='search' or row.id=='cancel') and status or '')
            slot.status.color(tone)
        end
        local shows=listed()
        v.head.set(t.lobby.members)
        v.count.set(shows and t.lobby.count:format(view.count.n,view.count.limit) or '')
        v.note.set(shows and status or '')
        v.note.color(tone)
        v.empty.set(shows and '' or view.status.key=='status.searching' and t.lobby.empty_search or t.lobby.empty)
        show_members(v.members,t,shows)
        sync(hints_b,'lobby',hints({{t.hint.back,'Negative'},{t.hint.select,'Positive'},
            {t.hint.move,'UI_DPad_Up','UI_DPad_Down'}}),3)
    end
    -- C's labels (L12-R1): headers, titles and values of tab match from the lobby table, of tab sbo from the co-op
    -- menu's.
    local function head_of(t,h)
        if tab=='match' then return h=='lobby' and t.lobby.head.lobby or t.lobby.mode[h] or h end
        return t.head[h] or h
    end
    local function title_of(t,item)
        if tab=='match' then return t.lobby.set[item.id] or item.id end
        if item.id=='mute' then return t.lobby.set.mute:format(item.name or '') end
        return t.row[item.id] or item.id
    end
    local function value_of(t,item)
        if not item.value then return '' end
        if tab=='match' then return word(t.lobby,item.shown or item.value,item.args) end
        return t.value[item.value] or item.value
    end
    -- The next item from i (step +1 or -1), headers skipped, wrapping.
    local function next_item(i,step)
        for _=1,#items do
            i=(i-1+step)%#items+1
            if not items[i].head then return i end
        end
        return i
    end
    local function draw_settings()
        local v=kit.view('lobby_settings')
        if not v then return end
        local t=words()
        read()
        items=Model.settings(view,tab,input)
        if not items[cur_c] or items[cur_c].head then cur_c=next_item(cur_c,1) end
        top=math.max(0,math.min(top,#items-WINDOW))
        if cur_c<=top+1 then top=math.max(0,cur_c-2)
        elseif cur_c>=top+WINDOW then top=math.min(#items-WINDOW,cur_c-WINDOW+1) end
        local specs={}
        for i=1,WINDOW do
            local item,y=items[top+i],LIST_Y+(i-1)*LIST_PITCH
            if not item then specs[i]=false
            elseif item.head then specs[i]=header(LIST_X,y,head_of(t,item.head))
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
        sync(list_c,'lobby_settings',specs,WINDOW)
        for i=1,WINDOW do
            local rec,item=list_c[i],items[top+i]
            if rec and rec.kind=='option' then look(rec,top+i==cur_c and 'focus' or 'normal') end
            -- Ruling 5's fallback: an item with no SB part shows on the kit row under it.
            if not item or kit.alive(rec) then v.zones[i].set('','')
            elseif item.head then v.zones[i].set(head_of(t,item.head),'','disabled')
            else
                v.zones[i].set(title_of(t,item),value_of(t,item),
                    item.locked and 'disabled' or top+i==cur_c and 'focus' or 'normal')
            end
        end
        for i,id in ipairs(TABS) do
            v.tabs[i].label.set(t.lobby.tab[id])
            v.tabs[i].label.color(id==tab and THEME.text or THEME.dim)
            v.tabs[i].line.show(id==tab)
        end
        sync(icons_c,'lobby_settings',{hint(86,120,'','UI_LeftShoulder'),
            hint(236+#TABS*360,120,'','UI_RightShoulder')},2)
        v.page.set(t.lobby.page)
        local shows,mode=listed(),input.match and input.match.mode or 'ffa'
        sync(pane_c,'lobby_settings',{header(PANE_X,LIST_Y,t.lobby.members..(shows and '  '..t.lobby.count:format(
            view.count.n,view.count.limit) or '')),header(PANE_X,PANE_MODE_Y,t.lobby.mode[mode] or mode)},2)
        show_members(v.members,t,shows)
        v.desc.set(t.lobby.desc[mode] or '')
        local list={{t.hint.back,'Negative'}}
        if items[cur_c] and items[cur_c].action then list[2]={t.hint.select,'Positive'} end -- On action rows only.
        list[#list+1]={t.lobby.hint.change,'UI_DPad_Left','UI_DPad_Right'}
        list[#list+1]={t.lobby.hint.tabs,'UI_LeftShoulder','UI_RightShoulder'}
        sync(hints_c,'lobby_settings',hints(list),4)
    end
    local function draw()
        if screen=='menu' then draw_menu() elseif screen=='settings' then draw_settings() end
    end
    local function draw_room()
        local v=room_on and not screen and kit.view('lobby_room')
        if not v then return end
        local t=words()
        read()
        local mode=input.match and input.match.mode or 'ffa'
        v.line.set((t.lobby.mode[mode] or mode)..' · '..word(t.lobby,view.status.key,view.status.args))
        local key=input.settings and input.settings.menu_key
        v.key.set(t.lobby.room:format(key and key.name or 'menu_key'))
    end
    -- The row under the mouse: B's row index; C's item index, or nil and a tab id.
    local function under()
        if screen=='menu' then
            local v,tv=kit.view('lobby'),kit.view('lobby_top')
            if not (v and tv and view) then return nil end
            for i=1,math.min(modes,#tv.slots) do if tv.slots[i].zone.hovered() then return i end end
            for k,slot in ipairs(v.slots) do
                local i=slot_row(k)
                if i and view.rows[i] and slot.zone.hovered() then return i end
            end
        elseif screen=='settings' then
            local v=kit.view('lobby_settings')
            if not v then return nil end
            for i,tb in ipairs(v.tabs) do if tb.zone.hovered() then return nil,TABS[i] end end
            for i,zone in ipairs(v.zones) do
                local item=items[top+i]
                if item and not item.head and zone.hovered() then return top+i end
            end
        end
    end
    -- A value row's next value (step +1 or -1) to act; false on a row with none to change.
    local function change(item,step)
        if not item or item.locked or not item.values then return false end
        local k=1
        for i,value in ipairs(item.values) do if value==item.value then k=i end end
        kit.sound('change')
        o.act({set=item.id,value=item.values[(k-1+step)%#item.values+1]})
        return true
    end
    local function set_tab(id)
        if id==tab then return end
        tab,cur_c,top=id,0,0
        kit.sound('change')
    end
    local function nav_menu(what)
        local rows=view.rows
        if what=='click' then
            local i=under()
            if not i then return end
            cur_b,what=i,'select'
        end
        if what=='up' or what=='down' then
            cur_b=Model.move(rows,cur_b,what=='up' and -1 or 1)
            kit.sound('move')
        elseif what=='select' then -- SB's own confirm sound, from the row (no kit select sound); a locked row: nothing.
            local row=rows[cur_b]
            local action=row and Model.act(view,row.id)
            if not action then return draw() end
            call(rows_b[cur_b],'row PressAccept',function(w) w:EventNotification('PressAccept') end)
            o.act(action)
        elseif what=='back' then -- The waiting room (L4 3.1).
            kit.sound('back')
            o.act({close='room'})
        end
        draw()
    end
    local function nav_settings(what)
        if what=='click' then
            local i,id=under()
            if id then set_tab(id); return draw() end
            if not i then return end
            cur_c,what=i,'select'
        end
        local item=items[cur_c]
        if what=='up' or what=='down' then
            cur_c=next_item(cur_c,what=='up' and -1 or 1)
            kit.sound('move')
        elseif what=='left' or what=='right' then change(item,what=='left' and -1 or 1)
        elseif what=='select' then
            if item and not item.locked and item.action then -- SB's setting confirm sound, from the row.
                call(list_c[cur_c-top],'option select',function(w) w:EventNotification('StateSelect') end)
                o.act(item.id=='mute' and {request=item.action} or {run=item.action})
            else change(item,1) end
        elseif what=='back' then
            log('lobby: settings back')
            kit.sound('back')
            screen='menu'
            show_groups()
        elseif what=='tab_left' or what=='tab_right' then
            local i=tab==TABS[1] and 1 or 2
            set_tab(TABS[(i-1+(what=='tab_left' and -1 or 1))%#TABS+1])
        end
        draw()
    end
    -- The question's kit fallback (ruling 5), shown with the words of t, or emptied and hidden when t is nil. Yes is
    -- the Leave row's word, No the Back hint's: both are in every language's table.
    local function fallback_popup(v,t)
        v.back.show(t~=nil)
        v.title.set(t and t.lobby.pop.leave_title or '')
        v.desc.set(t and t.lobby.pop.leave or '')
        v.yes.set(t and t.lobby.row.leave or '','')
        v.no.set(t and t.hint.back or '','')
    end
    -- The popup's answer: on_answer(yes) after SB's own feedback (its Accept or close animation and sound, without
    -- the FadeOut path that ends in CloseSelf); removed GONE s later, the kit's focus back on its root at once (the
    -- popup's Construct and RefreshAll took it).
    local function answer(yes)
        local a=ask
        ask=nil
        log('lobby: popup '..a.id..' '..(yes and 'yes' or 'no'))
        call(a.rec,'popup answer',function(w)
            w:PlayAnimation(yes and w.Accept or w.close,0,1,0,1,false)
            U.find(STATICS):PlaySound2D(w,yes and w.PopupAcceptSound or w.PopupCloseSound,1,1,0,nil,nil,true)
        end)
        if a.kit then
            kit.sound(yes and 'select' or 'back')
            fallback_popup(a.kit,nil)
        end
        if leaving then kit.drop(leaving.rec) end
        leaving={rec=a.rec,at=os.clock()+GONE}
        kit.refocus()
        if a.took and not screen then back_at=os.clock()+BACK end
        if a.on_answer then a.on_answer(yes) end
    end
    -- A left click: Yes over the popup's Yes button, No over its No button, else nothing.
    local function popup_click()
        local yes=nil
        call(ask.rec,'popup buttons',function(w)
            if w.Button_Positive:IsHovered() then yes=true elseif w.Button_Negative:IsHovered() then yes=false end
        end)
        if ask.kit then
            if ask.kit.yes.hovered() then yes=true elseif ask.kit.no.hovered() then yes=false end
        end
        if yes~=nil then answer(yes) end
    end
    -- 'menu' (B), 'settings' (C, over B: Back returns there), 'popup' while the question asks, else nil.
    function self.is_open() return ask and 'popup' or screen end
    -- Opens B or C (which: 'menu' or 'settings'), taking the game's input with the mouse cursor. false and why
    -- (English, for the log) when the kit is off or not up.
    function self.open(which)
        if kit.off() then return false,'the lobby menu is off: the UI stopped (see the log)' end
        if not kit.ready() then return false,'the lobby menu opens in the game world only' end
        if not screen then
            kit.input(true,'lobby',true)
            kit.sound('open')
            back_at,hover,cur_b=nil,false,nil
        end
        if which=='settings' then
            if screen~='settings' then tab,cur_c,top=TABS[1],0,0 end
            screen='settings'
        else screen='menu' end
        log('lobby: open '..screen)
        show_groups()
        draw()
        return true
    end
    -- B and C closed (a question still asking goes too, unanswered); the game's input back BACK s later.
    function self.close()
        local held=screen or (ask and ask.took)
        if screen or ask then log('lobby: closed') end
        if ask then
            kit.drop(ask.rec)
            if ask.kit then fallback_popup(ask.kit,nil) end
            ask=nil
            kit.show('lobby_popup',false)
            kit.refocus()
        end
        if screen then kit.sound('close') end
        screen=nil
        show_groups()
        if held then back_at=os.clock()+BACK end
        draw_room()
    end
    -- A key or the mouse: 'up', 'down', 'left', 'right', 'select', 'back', 'tab_left', 'tab_right', or 'click' (a left
    -- click: the row under the mouse takes the cursor and Select runs). The question, while it asks, takes them all.
    function self.nav(what)
        if ask then
            if what=='select' then answer(true) elseif what=='back' then answer(false)
            elseif what=='click' then popup_click() end
            return
        end
        if not screen then return end
        if kit.off() then return self.close() end
        if not view then draw() end
        if screen=='menu' then nav_menu(what) else nav_settings(what) end
    end
    -- The question id ('leave' only: Yes and No) over whatever shows; on_answer(yes) once. false and why when it
    -- cannot show.
    function self.popup(id,on_answer)
        if id~='leave' then return false,'lobby: no question '..tostring(id) end
        if ask then return false,'lobby: a question is already open' end
        if kit.off() or not kit.ready() then return false,'lobby: the UI is not up' end
        local t=words()
        kit.show('lobby_popup',true)
        local rec=make('lobby_popup','popup',0,0,3840,2160,function(w) -- Its PreConstruct fills nothing in game.
            w.TitleText=FText(t.lobby.pop.leave_title)
            w.DescText=FText(t.lobby.pop.leave)
            w.MessageText=FText('')
            w.ButtonType=3 -- Yes and No; 4, 5 and 7 hold a button whose end calls NotifyBlueprint.
        end,true)
        local v=not rec and broken.popup and kit.view('lobby_popup') -- Left out: ruling 5's fallback.
        if not (rec or v) then
            kit.show('lobby_popup',false)
            return false,'lobby: the question could not be made (see the log)'
        end
        if rec then call(rec,'popup RefreshAll',function(w) w:EventNotification('RefreshAll') end)
        else fallback_popup(v,t) end
        ask={id=id,rec=rec,kit=v or nil,on_answer=on_answer,took=not screen}
        if not screen then kit.input(true,'lobby',true) end
        log('lobby: popup '..id..' open')
        return true
    end
    local function write_time(now)
        call(timer,'countdown',function(w)
            w.CurrentTime=math.min(counting.total,math.max(0,now-counting.start))
            w:UpdateTimer()
        end)
    end
    -- The countdown at left seconds (the status's, whole seconds), now on the clock tick gets: shown over everything,
    -- its local clock moved only when the status disagrees by more than 1 s (Model.count); StartTimer (shows it, SB's
    -- cue) once a start.
    function self.count(left,now)
        local was=counting
        counting=Model.count(counting,left,now)
        if not kit.alive(timer) then
            timer=make('lobby_count','count',0,0,600,160,function(w) w.bIgnorePause=true end) -- SB's pause menu too.
            if not timer then -- Left out: ruling 5's fallback, the seconds left as a kit number.
                local v=broken.count and kit.view('lobby_count')
                if v then v.num.set(tostring(math.max(0,math.ceil(left)))) end
                return
            end
        elseif counting==was then return end
        call(timer,'countdown',function(w) w.TotalTime=counting.total end)
        write_time(now)
        if not timer.started then
            timer.started=true
            call(timer,'countdown start',function(w) w:EventNotification('StartTimer') end)
        end
    end
    function self.stop_count()
        counting=nil
        local v=broken.count and kit.view('lobby_count')
        if v then v.num.set('') end
        if timer and timer.started then
            timer.started=false
            call(timer,'countdown stop',function(w) w:SetVisibility(1) end) -- Collapsed.
        end
    end
    -- The waiting room's overlay (the mode, the status, the menu key), shown while no lobby screen is open.
    function self.room(on)
        room_on=on==true
        show_groups()
        draw_room()
    end
    -- Each 250 ms: B or C drawn from a fresh view (parts made again after a root build), the overlay; closed when the
    -- kit turned off; while closed, the game's input given back again until the kit has given it.
    function self.slow()
        if (screen or ask) and kit.off() then self.close() end
        if not (screen or ask or back_at) then kit.input(false,'lobby') end
        draw()
        draw_room()
    end
    -- Each frame: the answered question removed once due, the input given back once due, the countdown's time; every
    -- 100 ms while B or C is open, the row the mouse moved onto takes the cursor (a resting mouse never does).
    function self.tick(now)
        if leaving and now>=leaving.at then
            kit.drop(leaving.rec)
            leaving=nil
            if not ask then kit.show('lobby_popup',false) end
        end
        if back_at and now>=back_at then
            back_at=nil
            kit.input(false,'lobby')
        end
        if counting and timer then write_time(now) end
        if screen and not ask and now>=hover_at then
            hover_at=now+HOVER
            local i,id=under()
            local key=i or id
            local moved=hover~=false and key~=hover
            hover=key
            if moved and i then
                if screen=='menu' then cur_b=i else cur_c=i end
                kit.sound('move')
                draw()
            end
        end
    end
    -- coop sbo parts (dev): each of the six parts made once and dropped, one log line each; true when all were made,
    -- and a line for the console.
    function self.parts_check()
        local made=0
        for _,kind in ipairs(ORDER) do
            local rec,why=kit.part('lobby_count',CLASS[kind],0,0)
            log('lobby parts: '..CLASS[kind]:match('[^.]+$')..' '..(rec and 'ok' or (why:gsub('^part [^:]+: ',''))))
            if rec then made=made+1; kit.drop(rec) end
        end
        kit.refocus() -- The popup's Construct took the focus.
        return made==#ORDER,string.format('lobby parts: %d of %d made (the log has each)',made,#ORDER)
    end
    return self
end
return Lobby
