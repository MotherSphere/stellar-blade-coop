-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet's menu screen (closet/ui/menu.lua draws it): Stellar Blade's own widget parts in the kit group
-- closet_menu, inside x 86 to EDGE (the left 55%: x EDGE to 3840 stays clear for EVE). A window of TABS tab buttons
-- between the tab keys' icons; the tab's slot rows (ui/kit/parts.lua kind option) in a window of 10, a transparent kit
-- row over each for the mouse, as the lobby does; the hair salon's grid of the focused slot's pieces, COLUMNS a row
-- (its TileView fed with data objects, as closet probe test 1 did); the NanoSuit detail panel; two rows of key hints
-- (menu, camera); the popup. Each part is made on the first draw after an open and filled again only when what it
-- shows changes. Every call on a part runs in pcall (ui/kit/parts.lua's call: a refusal is logged once). A tab, grid
-- or detail part the kit cannot make raises, so the menu closes. drop_all clears the grid and drops every part: the
-- game holds EVE still while one of its widgets is up (the probe's test 5).
-- The mouse, read by the menu: tab_hovered (a tab's Button_Action:IsHovered, the probe's test 3), row_hovered (the kit
-- row over a slot row), picked (a tile the mouse selected in the TileView, BP_GetSelectedItem as the probe's test 1),
-- hint_hovered (the kit zone over a menu or camera hint: its word), popup_hit (the popup's Button_Positive or
-- Button_Negative:IsHovered, as online/lobby/ui/lobby.lua reads them).
-- alive is false once a made part is gone (the root rebuilt by a map change).
-- Glyphs: each tile shows its glyph (closet/ui/icons/<glyph>.png, imported once with ImportFileAsTexture2D as
-- ui/kit/guide.lua imports its art) through its data object's IconAssetPath; a hidden kit image of the group holds each
-- glyph drawn, so the engine keeps its texture while the root lives. The origin badge (the original or custom glyph)
-- is a kit image beside the detail panel. tick(t) looks at the shown tiles after each fill: one that lacks its glyph
-- gets it on its own image from then on (the fallback).
-- v.draw(s), s: {tabs={labels}, tab=focused index, tab_top=the first tab shown (1 when nil), rows={{title, value,
-- locked}}, row=focused index, tiles=nil or {{name, equipped, locked, icon=its glyph or nil}}, tile=selected index,
-- detail={title, desc, equipped, badge='original', 'custom' or nil}, hints={{label, icon, icon2, word=the menu word a
-- click runs or nil}} (the menu's), camera_hints=nil or the same shape, popup=nil or {title, desc}, notice=nil or the
-- text under the rows (a kit text, wrapped at ROW_W)}.
local U=require('core.unreal')
local Parts=require('ui.kit.parts')
local Slots=require('closet.slots')
local View={}
View.GROUP='closet_menu'
View.EDGE=2112 -- Kit units: the menu's right edge (55% of 3840).
View.TABS=7 -- Tab buttons shown at once.
View.COLUMNS=5 -- Grid tiles a row: GRID_W over the entry width.
View.CHECK=0.25 -- s between two looks at the shown tiles' glyphs (v.tick).
-- The glyphs a hidden kit image may hold: None's, the origin badges' and each slot's (closet/slots.lua).
View.GLYPHS={'none','original','custom'}
for _,entry in ipairs(Slots.LIST) do
    local name,known=Slots.glyph(entry[1]),false
    for _,g in ipairs(View.GLYPHS) do known=known or g==name end
    if not known then View.GLYPHS[#View.GLYPHS+1]=name end
end
-- The folder of this file: the glyphs are icons/<glyph>.png in it (tools/closet_icons/render.py renders them).
local HERE=(package.searchpath('closet.ui.view',package.path) or ''):match('^(.*[\\/])[^\\/]+$') or ''
-- KismetRenderingLibrary's ImportFileAsTexture2D(WorldContextObject, Filename): native entry 0x1465a3180 (its name at
-- 0x14659e5c0), exec 0x1447fc790, impl FUN_144267a10: an 8-bit PNG through the ImageWrapper module (FUN_1442680a0)
-- into a new texture of FUN_1445ff7a0 (Name None, flags 0x40 RF_Transient), so its object path is read at run time
-- with GetFullName (Ghidra, build 26123051, 26 Nov 2026).
local RENDER='/Script/Engine.Default__KismetRenderingLibrary'
-- Copied from closet/ui/probe.lua (read in the widget JSON and Ghidra, build 26123051, on 25 Nov 2026):
-- The hair salon's tile data object (super /Script/SB.SBUITileViewBaseDataObject): ItemName Text, IconAssetPath Str
-- (a full object path the slot loads), Purchased bool, ItemAlias Name, Equiped bool (the game's spelling), Index int
-- (never -1: the slot fills itself only when Index differs from its own, -1 at first), RedDotState byte.
local DATA='/Game/Art/UI/Data/HairSalon/BP_HairSalonItemData_Tile.BP_HairSalonItemData_Tile_C'
-- The hair salon's grid list: child TileView_ItemList, a /Script/UMG.TileView of WB_HairSalon_GridSlot (198x262).
local GRID='/Game/Art/UI/Widget/HairSalon/WB_HairSalonGridList.WB_HairSalonGridList_C'
-- The grid slot's own default icon (256x256): a tile's icon while its glyph has no texture.
local ICON='/Game/Art/UI/Texture/Hair/HairIcon/Deco_Item_Hair_000.Deco_Item_Hair_000'
-- A tile's glyph goes in by IconAssetPath, the texture's object path: the slot's Set loads it with LoadAsset_Blocking
-- (widget JSON), whose exec 0x14482cf00 (native entry 0x1465b5cb0) first resolves the path in memory (FUN_142b82f40
-- calls StaticFindObject, FUN_142b957b0, named by its own error strings) and loads from disk only when that finds
-- nothing (FUN_142b82e50), so a texture imported at run time loads by its path (Ghidra, build 26123051, 26 Nov 2026).
-- The fallback: a shown entry (WB_HairSalon_GridSlot's Data, the tile's data object, and Image_Icon, widget JSON) that
-- lacks its glyph gets it by UImage SetBrushFromTexture(Texture, bMatchSize) (native entry 0x1461e9e70, exec
-- 0x143d46320; Ghidra, the same day).
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
local TAB_X,TAB_Y,TAB_STEP=160,120,266 -- TABS tabs from 160, a tab key's icon at each end (the lobby's settings tabs).
local TAB_ICON_X=86 -- The left tab key's icon (UI_LeftShoulder: Q, the pad's LB); the right one after the last tab.
local ROW_X,ROW_Y,ROW_W,ROW_H,PITCH,WINDOW=160,300,900,130,130,10 -- Slot rows: a window of 10.
local NOTICE_Y=1640 -- The notice's top: under the rows' window (it ends at y 1600), above the hints.
local GRID_X,GRID_Y,GRID_W,GRID_H=1100,300,1000,820
-- The TileView's entry size: 5 columns of 200 in GRID_W, 3 rows of 270 in GRID_H. SetEntryWidth and SetEntryHeight
-- (one float each) are in /Script/UMG.TileView's native table 0x1461ff110 (registered by FUN_143d66670), execs
-- 0x143d66330 and 0x143d66440 (Ghidra, build 26123051, 26 Nov 2026).
local ENTRY_W,ENTRY_H=200,270
local DETAIL_X,DETAIL_Y=1100,1160
-- The origin badge: 64 units square, by the detail panel's title, right of its 900-unit wide SizeBox_4 (widget JSON).
-- A kit image draws under every part, so it sits beside the panel, not on it.
local BADGE_X,BADGE_Y,BADGE=View.EDGE-88,DETAIL_Y+8,64
-- Key hints, right to left from EDGE (the lobby's step): the menu's row and the camera's row above it.
local HINT_STEP,HINT_Y,CAMERA_Y,HINTS=420,1990,1890,4

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
        b.shade(0,0,1700,2160,{A=0.72})
        b.image(1700,0,800,2160,'shade_left') -- online/lobby/ui/lobby.lua's left gradient: the shade fades out.
        b.image(0,1860,2560,300,'dither',{A=0.8})
        local zones={}
        for i=1,WINDOW do zones[i]=b.row(ROW_X,ROW_Y+(i-1)*PITCH+27,ROW_W) end
        -- A chip over each menu hint, then over each camera hint (the SB hint part never takes the mouse,
        -- ui/kit/parts.lua): a clear kit row.
        for i=1,HINTS do zones[WINDOW+i]=b.row(View.EDGE-HINT_STEP*i,HINT_Y,HINT_STEP-20) end
        for i=1,HINTS do zones[WINDOW+HINTS+i]=b.row(View.EDGE-HINT_STEP*i,CAMERA_Y,HINT_STEP-20) end
        -- A hidden image a glyph: its texture as the brush keeps the engine from freeing it.
        local held={}
        for _,name in ipairs(View.GLYPHS) do
            held[name]=b.image(0,0,1,1,nil)
            held[name].show(false)
        end
        local badge=b.image(BADGE_X,BADGE_Y,BADGE,BADGE,nil)
        badge.show(false)
        -- s.notice under the rows: the chat feed, where notices go, draws under this group's shade.
        return {zones=zones,notice=b.text(ROW_X,NOTICE_Y,'','name',nil,nil,{wrap=ROW_W}),held=held,badge=badge}
    end)
    -- What is made and what it shows. top: the rows above the window; count: the rows of the last draw; tab_top: the
    -- first tab shown; camera: the camera's hint row.
    local tabs,tabs_sig,focus,rows,top,hints,count,keys={},nil,nil,{},0,{},0,{}
    local tab_top,camera=1,{}
    -- The word each hint chip runs as last drawn: the menu's (s.hints[i].word), then the camera's (s.camera_hints).
    local words={}
    local grid,tiles_sig,selected,detail,detail_sig,popup
    -- glyphed: each tile's glyph as last filled (false: the game icon); checking: a fill not yet seen right;
    -- check_at: the next look; by_brush: a shown tile lacked its glyph once, so every look sets the ones that lack it.
    local glyphed,checking,check_at,by_brush=nil,false,0,false
    local function make(class,x,y,w,h,fill,hit)
        local rec,why=kit.part(View.GROUP,class,x,y,w,h,fill,hit)
        if not rec then error(why,0) end
        return rec
    end

    -- Copied from ui/kit/guide.lua's texture() (November 2026): a glyph's texture as {o=, full=, path=its object path,
    -- view=the build whose holder has it}, imported again only once the engine freed it; nil with no player controller
    -- (tried again at the next draw) or once its import failed (said once).
    local glyphs={}
    local function glyph(name)
        if glyphs[name]==false then return nil end
        local ok,got=pcall(function()
            local g=glyphs[name]
            local t=g and U.valid(g.o)
            if t and U.text(t:GetFullName())==g.full then return g end
            local pc=U.controller()
            if not pc then return nil end
            local file=HERE..'icons'..HERE:sub(-1)..name..'.png'
            local x=U.valid(U.find(RENDER):ImportFileAsTexture2D(pc,file))
            if not x then error('no texture from '..file,0) end
            local full=U.text(x:GetFullName())
            return {o=x,full=full,path=full:match('^%S+ (.+)$')}
        end)
        if not ok then
            glyphs[name]=false
            log('menu: the glyph '..name..' did not load ('..tostring(got)..'): its tiles show the game icon')
            return nil
        end
        if not got then return nil end
        glyphs[name]=got
        local view=kit.view(View.GROUP)
        local holder=view and view.held[name]
        if holder and got.view~=view and holder.texture(got.o) then got.view=view end
        return got
    end

    -- The tabs s.tab_top (1 when nil) to s.tab_top+TABS-1; tabs[i] shows tab tab_top+i-1.
    local function draw_tabs(s)
        local first=s.tab_top or 1
        local shown={table.unpack(s.tabs,first,math.min(#s.tabs,first+View.TABS-1))}
        local sig=table.concat(shown,'|')
        local whole=sig==tabs_sig and #tabs==#shown
        for _,rec in ipairs(tabs) do whole=whole and kit.alive(rec)~=nil end
        if not whole then
            for _,rec in ipairs(tabs) do kit.drop(rec) end
            tabs,tabs_sig,focus={},sig,nil
            for i,label in ipairs(shown) do
                tabs[i]=make(TAB,TAB_X+(i-1)*TAB_STEP,TAB_Y,nil,nil,nil,true) -- hit: else no hover reaches it.
                call(tabs[i],'tab label',function(w) w.TextValue=FText(label); w:RefreshDesign() end)
            end
        end
        tab_top=first
        -- The tab keys' icons, as online/lobby/ui/lobby.lua shows them beside its settings tabs; the hint shows the
        -- keyboard's key or the pad's button, whichever was used last.
        sync(keys,View.GROUP,{Parts.hint(TAB_ICON_X,TAB_Y,'','UI_LeftShoulder'),
            Parts.hint(TAB_X+#shown*TAB_STEP,TAB_Y,'','UI_RightShoulder')},2)
        if focus==s.tab then return end
        focus=s.tab
        for i,rec in ipairs(tabs) do
            call(rec,'tab focus',function(w)
                if tab_top+i-1==s.tab then w:FocusTabButton() else w:DefocusTabButton() end
            end)
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
            -- hit: a HitTestInvisible grid keeps every tile out of Slate's hit test (no click picks one).
            grid,tiles_sig,selected=make(GRID,GRID_X,GRID_Y,GRID_W,GRID_H,nil,true),nil,nil
            call(grid,'grid Set Goods',function(w) w['Set Goods'](w) end)
            call(grid,'grid list',function(w)
                local tv=w.TileView_ItemList
                tv:SetVisibility(VISIBLE)
                if tv.SelectionMode==0 then tv:SetSelectionMode(SINGLE) end
                tv:SetEntryWidth(ENTRY_W)
                tv:SetEntryHeight(ENTRY_H)
            end)
        end
        -- Each tile's glyph, looked up once a draw a glyph; its path is in the signature (a texture imported again).
        local names,shown,seen,any={},{},{},false
        for i,t in ipairs(s.tiles or {}) do
            if t.icon and seen[t.icon]==nil then seen[t.icon]=glyph(t.icon) or false end
            shown[i]=t.icon and seen[t.icon] or false
            any=any or shown[i]~=false
            local path=shown[i] and shown[i].path or ''
            names[i]=t.name..(t.equipped and '+' or '')..(t.locked and '*' or '')..'@'..path
        end
        local sig=table.concat(names,'|')
        if sig~=tiles_sig then
            tiles_sig,selected=sig,nil
            glyphed,checking,check_at=any and shown or nil,any,0 -- tick looks only at a grid with a glyph.
            call(grid,'grid fill',function(w)
                local tv=w.TileView_ItemList
                tv:ClearListItems()
                local class=#names>0 and find(DATA)
                if #names>0 and not class then error(DATA..' not found',0) end
                for i,t in ipairs(s.tiles or {}) do
                    local item=StaticConstructObject(class,tv)
                    item.ItemName=FText(t.name)
                    item.IconAssetPath=shown[i] and shown[i].path or ICON
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

    local function draw_detail(s,view)
        if not kit.alive(detail) then detail,detail_sig=make(DETAIL,DETAIL_X,DETAIL_Y),nil end
        local d=s.detail
        -- The origin badge, on change only (a build of the root starts with it hidden).
        local g=d.badge and glyph(d.badge)
        if view.badge_shown~=(g and g.full or false) then
            view.badge_shown=g and g.full or false
            view.badge.show(g~=nil and view.badge.texture(g.o))
        end
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
        if popup then call(popup,'popup RefreshAll',function(w) w:EventNotification('RefreshAll') end) end
    end

    function v.draw(s)
        local view=kit.view(View.GROUP)
        if not view then error('the UI is not up',0) end
        draw_tabs(s)
        draw_rows(s,view.zones)
        view.notice.set(s.notice)
        draw_grid(s)
        draw_detail(s,view)
        words={}
        for i=1,HINTS do
            words[i]=s.hints[i] and s.hints[i].word
            words[HINTS+i]=s.camera_hints and s.camera_hints[i] and s.camera_hints[i].word
        end
        for _,row in ipairs({{hints,s.hints,HINT_Y},{camera,s.camera_hints or {},CAMERA_Y}}) do
            local specs={}
            for i=1,HINTS do
                local h=row[2][i]
                specs[i]=h and Parts.hint(View.EDGE-HINT_STEP*i,row[3],h[1],h[2],h[3]) or false
            end
            sync(row[1],View.GROUP,specs,HINTS)
        end
        draw_popup(s)
        -- The grid's entries (a fill, a selection) and the popup's Construct take the keyboard focus; on them a key
        -- reaches EVE (E fired a skill). On the kit's root the game ignores keys (closet/ui/probe.lua test 5).
        kit.refocus()
    end

    -- Each frame while open (closet/ui/menu.lua's tick; t: its time in s). After a fill, a look at the shown tiles each
    -- View.CHECK s until one finds each with its glyph (Slate builds them on later frames). A tile that lacks it (its
    -- path did not load in the slot) gets it on its Image_Icon, and from then on every look does that, said once.
    function v.tick(t)
        if not (glyphed and (checking or by_brush)) or t<check_at then return end
        check_at=t+View.CHECK
        local seen,wrong,done=0,0,false
        call(grid,'grid glyphs',function(w)
            U.each(w.TileView_ItemList:GetDisplayedEntryWidgets(),function(_,entry)
                local g=glyphed[entry.Data.Index+1]
                if not g then return end
                seen=seen+1
                local now=U.valid(entry.Image_Icon.Brush.ResourceObject)
                if now and U.text(now:GetFullName())==g.full then return end
                wrong=wrong+1
                entry.Image_Icon:SetBrushFromTexture(g.o,false)
            end)
            done=true
        end)
        if wrong>0 and not by_brush then
            by_brush=true
            log('menu: a shown tile lacked its glyph: tiles get theirs by SetBrushFromTexture from now on')
        end
        if done and wrong==0 and seen>0 then checking=false end
    end

    -- The tab under the mouse (its index in s.tabs), or nil.
    function v.tab_hovered()
        local hit
        for i,rec in ipairs(tabs) do
            call(rec,'tab hover',function(w) if w.Button_Action:IsHovered() then hit=hit or tab_top+i-1 end end)
        end
        return hit
    end
    -- The slot row under the mouse (its index in s.rows), or nil.
    function v.row_hovered()
        local view=kit.view(View.GROUP)
        for i=1,WINDOW do -- Only the row zones: zones WINDOW+1.. are the hint chips.
            local zone=view and view.zones[i]
            if zone and top+i<=count and zone.hovered() then return top+i end
        end
    end
    -- The menu or camera hint under the mouse: its word, or nil (a hint with no word, none hovered).
    function v.hint_hovered()
        local view=kit.view(View.GROUP)
        for i=1,2*HINTS do
            local zone=view and view.zones[WINDOW+i]
            if words[i] and zone and zone.hovered() then return words[i] end
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
        for _,set in ipairs({tabs,rows,hints,keys,camera}) do
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
        for i=1,HINTS do kit.drop(hints[i]); kit.drop(camera[i]) end
        for i=1,2 do kit.drop(keys[i]) end
        kit.drop(grid)
        kit.drop(detail)
        kit.drop(popup)
        tabs,tabs_sig,focus,rows,top,hints,count,keys={},nil,nil,{},0,{},0,{}
        tab_top,camera,words=1,{},{}
        grid,tiles_sig,selected,detail,detail_sig,popup=nil,nil,nil,nil,nil,nil
        glyphed,checking=nil,false
    end
    return v
end

return View
