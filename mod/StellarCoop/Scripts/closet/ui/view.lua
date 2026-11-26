-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet's menu screen (closet/ui/menu.lua draws it): Stellar Blade's own widget parts in the kit group
-- closet_menu, inside x 160 to 2560 (the right third stays clear for EVE). A row of tab buttons; the tab's slot rows
-- (ui/kit/parts.lua kind option) in a window of 10, a transparent kit row over each for the mouse, as the lobby does;
-- the hair salon's grid of the focused slot's pieces (its TileView fed with data objects, as closet probe test 1 did);
-- the NanoSuit detail panel; the key hints; the popup. Each part is made on the first draw after an open and filled
-- again only when what it shows changes. Every call on a part runs in pcall (ui/kit/parts.lua's call: a refusal is
-- logged once). A tab, grid or detail part the kit cannot make raises, so the menu closes. drop_all clears the grid
-- and drops every part: the game holds EVE still while one of its widgets is up (the probe's test 5).
-- The mouse, read by the menu: tab_hovered (a tab's Button_Action:IsHovered, the probe's test 3), row_hovered (the kit
-- row over a slot row), picked (a tile the mouse selected in the TileView, BP_GetSelectedItem as the probe's test 1),
-- popup_hit (the popup's Button_Positive or Button_Negative:IsHovered, as online/lobby/ui/lobby.lua reads them).
-- alive is false once a made part is gone (the root rebuilt by a map change).
-- v.draw(s), s: {tabs={labels}, tab=focused index, rows={{title, value, locked}}, row=focused index, tiles=nil or
-- {{name, equipped, locked}}, tile=selected index, detail={title, desc, equipped}, hints={{label, icon, icon2}},
-- popup=nil or {title, desc}}.
local Parts=require('ui.kit.parts')
local View={}
View.GROUP='closet_menu'
-- Copied from closet/ui/probe.lua (read in the widget JSON and Ghidra, build 26123051, on 25 Nov 2026):
-- The hair salon's tile data object (super /Script/SB.SBUITileViewBaseDataObject): ItemName Text, IconAssetPath Str
-- (a full object path the slot loads), Purchased bool, ItemAlias Name, Equiped bool (the game's spelling), Index int
-- (never -1: the slot fills itself only when Index differs from its own, -1 at first), RedDotState byte.
local DATA='/Game/Art/UI/Data/HairSalon/BP_HairSalonItemData_Tile.BP_HairSalonItemData_Tile_C'
-- The hair salon's grid list: child TileView_ItemList, a /Script/UMG.TileView of WB_HairSalon_GridSlot (198x262).
local GRID='/Game/Art/UI/Widget/HairSalon/WB_HairSalonGridList.WB_HairSalonGridList_C'
-- The grid slot's own default icon (256x256): every tile's icon until the packs give thumbnails.
local ICON='/Game/Art/UI/Texture/Hair/HairIcon/Deco_Item_Hair_000.Deco_Item_Hair_000'
-- The pause menu's tab button (super /Script/SB.SBCommonTabButtonWidget): TextValue Text, then the native
-- RefreshDesign() puts it in TextBlock; FocusTabButton() and DefocusTabButton() set bFocused.
local TAB='/Game/Art/UI/Widget/GameMenu/Common/WB_Common_Tab_Btn.WB_Common_Tab_Btn_C'
-- The workshop's NanoSuit detail panel: TitleText, DescriptionText, MaterialText1..5 (Text), ItemRarity
-- (ESBItemRarityType), bEquip, CraftState (ESBUINanoSuitCraftState Enable 0, Disable 1, Complete 2); only
-- EventNotification('Refresh') acts. Child WB_Common_HoldButton.
local DETAIL='/Game/Art/UI/Widget/GameMenu/WorkShop/WB_NanoSuit_Detail.WB_NanoSuit_Detail_C'
local RARE=3 -- ESBItemRarityType Rare (the probe's).
local VISIBLE,COLLAPSED=0,1 -- ESlateVisibility.
local SINGLE=1 -- ESelectionMode Single (None is 0).
-- The builder's layout in kit units.
local TAB_X,TAB_Y,TAB_STEP=160,120,266 -- 9 tabs fit in 160 to 2560.
local ROW_X,ROW_Y,ROW_W,ROW_H,PITCH,WINDOW=160,300,900,130,130,10 -- Slot rows: a window of 10.
local GRID_X,GRID_Y,GRID_W,GRID_H=1100,300,1460,1000
local DETAIL_X,DETAIL_Y=1100,1340
local HINT_RIGHT,HINT_STEP,HINT_Y,HINTS=2560,420,1990,4 -- Key hints, right to left (the lobby's step and y).

-- A game object by path: in memory, else after a synchronous LoadAsset (closet/ui/probe.lua's default_find).
local function find(path)
    local o=StaticFindObject(path)
    if o and o:IsValid() then return o end
    pcall(LoadAsset,path:match('^(.*)_C$') or path)
    o=StaticFindObject(path)
    return o and o:IsValid() and o or nil
end

function View.new(kit,log)
    local P=Parts.new(kit,log,'closet')
    local call,sync,look=P.call,P.sync,P.look
    local v={}
    kit.add(View.GROUP,{x=0,y=0,w=3840,h=2160,fixed=true,hit=true},function(b)
        b.shade(0,0,2560,2160,{A=0.72})
        b.image(0,1860,2560,300,'dither',{A=0.8})
        local zones={}
        for i=1,WINDOW do zones[i]=b.row(ROW_X,ROW_Y+(i-1)*PITCH+27,ROW_W) end
        return {zones=zones}
    end)
    -- What is made and what it shows. top: the rows above the window; count: the rows of the last draw.
    local tabs,tabs_sig,focus,rows,top,hints,count={},nil,nil,{},0,{},0
    local grid,tiles_sig,selected,detail,detail_sig,popup
    local function make(class,x,y,w,h,fill,hit)
        local rec,why=kit.part(View.GROUP,class,x,y,w,h,fill,hit)
        if not rec then error(why,0) end
        return rec
    end

    local function draw_tabs(s)
        local sig=table.concat(s.tabs,'|')
        local whole=sig==tabs_sig and #tabs==#s.tabs
        for _,rec in ipairs(tabs) do whole=whole and kit.alive(rec)~=nil end
        if not whole then
            for _,rec in ipairs(tabs) do kit.drop(rec) end
            tabs,tabs_sig,focus={},sig,nil
            for i,label in ipairs(s.tabs) do
                tabs[i]=make(TAB,TAB_X+(i-1)*TAB_STEP,TAB_Y)
                call(tabs[i],'tab label',function(w) w.TextValue=FText(label); w:RefreshDesign() end)
            end
        end
        if focus==s.tab then return end
        focus=s.tab
        for i,rec in ipairs(tabs) do
            call(rec,'tab focus',function(w) if i==s.tab then w:FocusTabButton() else w:DefocusTabButton() end end)
        end
    end

    local function draw_rows(s,zones)
        local n=#s.rows
        count=n
        top=math.max(0,math.min(top,n-WINDOW))
        if s.row then
            if s.row>top+WINDOW then top=s.row-WINDOW elseif s.row<=top then top=s.row-1 end
        end
        local specs={}
        for i=1,WINDOW do
            local row=s.rows[top+i]
            specs[i]=row and {kind='option',x=ROW_X,y=ROW_Y+(i-1)*PITCH,w=ROW_W,h=ROW_H,
                sig=row.title..'|'..row.value..(row.locked and '*' or ''),
                after=row.locked and 'RefreshAppearance' or nil,fill=function(w) -- SB's locked look.
                    w.Text_TitleValue=FText(row.title)
                    w.Text_ItemValue=FText(row.value)
                    if row.locked then w.bLockItem=true end
                end} or false
        end
        sync(rows,View.GROUP,specs,WINDOW)
        for i=1,WINDOW do
            local rec,row=rows[i],s.rows[top+i]
            if rec then look(rec,top+i==s.row and 'focus' or 'normal') end
            -- The kit fallback: a row with no SB part shows on the kit row under it.
            if not row or kit.alive(rec) then zones[i].set('','')
            else zones[i].set(row.title,row.value,row.locked and 'disabled' or top+i==s.row and 'focus' or 'normal') end
        end
    end

    local function draw_grid(s)
        if not kit.alive(grid) then
            grid,tiles_sig,selected=make(GRID,GRID_X,GRID_Y,GRID_W,GRID_H),nil,nil
            call(grid,'grid Set Goods',function(w) w['Set Goods'](w) end)
            call(grid,'grid list',function(w)
                local tv=w.TileView_ItemList
                tv:SetVisibility(VISIBLE)
                if tv.SelectionMode==0 then tv:SetSelectionMode(SINGLE) end
            end)
        end
        local names={}
        for i,t in ipairs(s.tiles or {}) do
            names[i]=t.name..(t.equipped and '+' or '')..(t.locked and '*' or '')
        end
        local sig=table.concat(names,'|')
        if sig~=tiles_sig then
            tiles_sig,selected=sig,nil
            call(grid,'grid fill',function(w)
                local tv=w.TileView_ItemList
                tv:ClearListItems()
                local class=#names>0 and find(DATA)
                if #names>0 and not class then error(DATA..' not found',0) end
                for i,t in ipairs(s.tiles or {}) do
                    local item=StaticConstructObject(class,tv)
                    item.ItemName=FText(t.name)
                    item.IconAssetPath=ICON
                    item.ItemAlias=FName('closet'..i)
                    item.Purchased=not t.locked -- false shows the lock.
                    item.Equiped=t.equipped==true
                    item.RedDotState=0
                    item.Index=i-1
                    tv:AddItem(item)
                end
            end)
        end
        if s.tiles and s.tile and s.tile~=selected then
            selected=s.tile
            call(grid,'grid select',function(w) w.TileView_ItemList:SetSelectedIndex(s.tile-1) end)
        end
    end

    local function draw_detail(s)
        if not kit.alive(detail) then detail,detail_sig=make(DETAIL,DETAIL_X,DETAIL_Y),nil end
        local d=s.detail
        local sig=d.title..'|'..d.desc..(d.equipped and '+' or '')
        if sig==detail_sig then return end
        detail_sig=sig
        call(detail,'detail Refresh',function(w)
            w.TitleText=FText(d.title)
            w.DescriptionText=FText(d.desc)
            w.ItemRarity=RARE
            w.bEquip=d.equipped==true
            for i=1,5 do w['MaterialText'..i]=FText('') end -- Empty: no material rows.
            w.CraftState=0
            w:EventNotification('Refresh')
            w.WB_Common_HoldButton:SetVisibility(COLLAPSED) -- Refresh shows it again each time.
        end)
    end

    local function draw_popup(s)
        if not s.popup then
            if popup then kit.drop(popup); popup=nil end
            return
        end
        if kit.alive(popup) then return end
        -- online/lobby/ui/lobby.lua's popup fill: its PreConstruct fills nothing in game.
        popup=P.make(View.GROUP,'popup',0,0,3840,2160,function(w)
            w.TitleText=FText(s.popup.title)
            w.DescText=FText(s.popup.desc)
            w.MessageText=FText('')
            w.ButtonType=3 -- Yes and No.
        end,true)
        if popup then
            call(popup,'popup RefreshAll',function(w) w:EventNotification('RefreshAll') end)
            kit.refocus() -- The popup's Construct took the focus.
        end
    end

    function v.draw(s)
        local view=kit.view(View.GROUP)
        if not view then error('the UI is not up',0) end
        draw_tabs(s)
        draw_rows(s,view.zones)
        draw_grid(s)
        draw_detail(s)
        local specs={}
        for i=1,HINTS do
            local h=s.hints[i]
            specs[i]=h and Parts.hint(HINT_RIGHT-HINT_STEP*i,HINT_Y,h[1],h[2],h[3]) or false
        end
        sync(hints,View.GROUP,specs,HINTS)
        draw_popup(s)
    end

    -- The tab under the mouse, or nil.
    function v.tab_hovered()
        local hit
        for i,rec in ipairs(tabs) do
            call(rec,'tab hover',function(w) if w.Button_Action:IsHovered() then hit=hit or i end end)
        end
        return hit
    end
    -- The slot row under the mouse (its index in s.rows), or nil.
    function v.row_hovered()
        local view=kit.view(View.GROUP)
        for i,zone in ipairs(view and view.zones or {}) do
            if top+i<=count and zone.hovered() then return top+i end
        end
    end
    -- The tile the mouse selected since the last draw or pick (its index in s.tiles), or nil.
    function v.picked()
        local at
        call(grid,'grid picked',function(w)
            local tv=w.TileView_ItemList
            local item=tv:BP_GetSelectedItem()
            at=item and tv:GetIndexForItem(item)
        end)
        if not at or at<0 or at+1==selected then return nil end
        selected=at+1
        return selected
    end
    -- 'yes' or 'no': the popup button under the mouse, else nil.
    function v.popup_hit()
        local hit
        call(popup,'popup buttons',function(w)
            if w.Button_Positive:IsHovered() then hit='yes' elseif w.Button_Negative:IsHovered() then hit='no' end
        end)
        return hit
    end
    -- false once a part made since the open is gone.
    function v.alive()
        for _,set in ipairs({tabs,rows,hints}) do
            for i=1,math.max(#set,WINDOW) do if set[i] and not kit.alive(set[i]) then return false end end
        end
        for _,rec in ipairs({grid or false,detail or false,popup or false}) do
            if rec and not kit.alive(rec) then return false end
        end
        return true
    end

    -- Every part gone, the grid's items first: the first thing each close runs.
    function v.drop_all()
        if grid then call(grid,'grid clear',function(w) w.TileView_ItemList:ClearListItems() end) end
        for _,rec in ipairs(tabs) do kit.drop(rec) end
        for i=1,WINDOW do kit.drop(rows[i]) end
        for i=1,HINTS do kit.drop(hints[i]) end
        kit.drop(grid)
        kit.drop(detail)
        kit.drop(popup)
        tabs,tabs_sig,focus,rows,top,hints,count={},nil,nil,{},0,{},0
        grid,tiles_sig,selected,detail,detail_sig,popup=nil,nil,nil,nil,nil,nil
    end
    return v
end

return View
