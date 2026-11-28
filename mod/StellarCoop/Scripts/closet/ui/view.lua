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
-- Pictures: a tile shows, the first that loads, its picture (a PNG of closet/thumbs.lua's cache, imported as the glyphs
-- are and held by hidden kit image i while it is tile i's), its Image (an outfit's object path, used only when it
-- loads as a Texture2D: a slot whose path does not load keeps the icon it had), its glyph. A source that fails is said
-- once. reread() drops the imported pictures: the next draws import them again (a capture may have made them anew).
-- v.draw(s), s: {tabs={labels}, tab=focused index, tab_top=the first tab shown (1 when nil), rows={{title, value,
-- locked, header=drawn as SB's settings category header with its title, swatch={R, G, B} shown right of the row}},
-- row=focused index, grid=true while the grid has the focus (the row then drawn normal), show=nil or a row index
-- brought into the window too while row stays in it, tiles=nil or {{name,
-- equipped, locked, picture=a PNG file or nil, image=an object path or nil, icon=its glyph or nil}}, tile=selected
-- index or nil,
-- detail={title, desc, equipped, badge='original', 'custom' or nil}, hints={{label, icon, icon2, word=the menu word a
-- click runs or nil}} (the menu's), camera_hints=nil or the same shape with key=the keyboard key (mode, reset, light),
-- pad=SB's last input came from a pad (the camera row then shows SB's hint parts, else the kit's key and label
-- texts), popup=nil or {title, desc}, notice=nil or the text under the rows (a kit text, wrapped at ROW_W)}.
local U=require('core.unreal')
local Parts=require('ui.kit.parts')
local THEME=require('ui.kit.kit').THEME
local Slots=require('closet.slots')
local View={}
View.GROUP='closet_menu'
View.EDGE=2112 -- Kit units: the menu's right edge (55% of 3840).
View.TABS=7 -- Tab buttons shown at once.
-- Grid tiles a row: the TileView lays out 4 entries a row in GRID_W (Schizo's screenshot of the Head tab, 27 Nov
-- 2026), not GRID_W over the entry width.
View.COLUMNS=4
View.CHECK=0.25 -- s between two looks at the shown tiles' glyphs (v.tick).
-- A small tile's picture (a pack's head piece) is drawn at this render scale: the slot's Image_Icon keeps a 256x256
-- brush (its Set calls SetBrushFromTexture with bMatchSize false, widget JSON), so an opaque picture filled the tile
-- past its frame while the game's hair icons are white art in a clear margin (Schizo's screenshots of 27 Nov 2026).
View.PICTURE_SCALE=0.55
View.HOLD=64 -- Hidden kit images that hold the shown tiles' pictures (a grid of 64 tiles).
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
-- UTexture2D (class registered by FUN_140def0d0; Ghidra, build 26123051, 26 Nov 2026): an outfit's Image is used only
-- when it is one.
local TEXTURE='/Script/Engine.Texture2D'
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
-- The flat shade's right edge: past the right tab key's icon art by the left one's margin. Measured on Schizo's
-- screenshot of 27 Nov 2026 (2000x1123): a tab key's art starts 6 units right of its hint's x and is 42 wide, so the
-- left art starts at x 92 and the right art (hint at 2022) ends at x 2070.
local KEY_ART_X,KEY_ART_W=6,42
local SHADE_W=TAB_X+View.TABS*TAB_STEP+KEY_ART_X+KEY_ART_W+TAB_ICON_X+KEY_ART_X
local FADE_W=400 -- The lobby's left gradient after it, ending at x 2562, left of EVE (framed at NDC 0.55).
local ROW_X,ROW_Y,ROW_W,ROW_H,PITCH,WINDOW=160,300,900,130,130,10 -- Slot rows: a window of 10.
-- The settings menu's slider slot (WB_Setting_Slider_Slot) is laid out for 1640-unit rows: its root SizeBox_0 1640,
-- the title's SizeBox_3 580 and the slider's SizeBox_1 960 (widget JSON). In a ROW_W row the slider bar had no room
-- (in game, 27 Nov 2026), so each slider row gets ROW_W, SLIDER_TITLE and SLIDER_BAR (SetWidthOverride).
-- USizeBox.SetWidthOverride: native table entry 0x1461efaa0, exec 0x143d5be10; UWidget.GetParent: entry 0x146202f00,
-- exec 0x143d73260; UOverlaySlot.SetPadding (FMargin): entry 0x1461ed5c0 in the table FUN_143d527d0 registers, exec
-- 0x143d525d0 (Ghidra, build 26123051, 27 Nov 2026). The bar's own padding (Left 70, Right 170: OverlaySlot_1) left it
-- 220 of 460 units: SLIDER_PAD keeps room for the value text (SizeBox_2, 112 wide, 20 from the right) only.
local SLIDER_TITLE,SLIDER_BAR=420,460
local SLIDER_PAD={Left=20,Top=0,Right=130,Bottom=0}
-- The bar's ends on screen with those sizes, in kit units (measured in game at 1920x1080, 27 Nov 2026): a click
-- between them sets the value at that place (closet/ui/menu.lua).
View.SLIDER_X0,View.SLIDER_X1=706,974
-- The SB row's value box (WB_Setting_Button_Slot in a 900-unit slot at x 160), measured on the in-game screenshots of
-- build 65b52c49 at 1456x819: its focused white box spans x 828 to 1121. Its value and copy icon are centred in it.
-- A longer value starts at the box's left and runs out of it: 'Reshape 50%' ran out, 'Pack colour', 'No Reshape' and
-- 'Coming soon' fit. So a value shows whole up to VALUE_COLS columns, else cut with '...' (View.fit).
View.ROW_RIGHT,View.VALUE_COLS=1121,10
-- A colour row's swatch: a flat kit image right of the row's value box (a kit image draws under the SB row part, so a
-- swatch inside the box is hidden by the focused white box), 28 by 76 units at the height of the kit row over it.
local SWATCH_X,SWATCH_W,SWATCH_H=View.ROW_RIGHT+8,28,76
local NOTICE_Y=1640 -- The notice's top: under the rows' window (it ends at y 1600), above the hints.
-- The grid starts where the detail panel does, right of a colour row's swatch: at x 1100 the Full tab's tile sat on the
-- value box's copy icon (Schizo's screenshots, 27 Nov 2026).
local GRID_X,GRID_Y,GRID_W,GRID_H=SWATCH_X+SWATCH_W+4,300,1000,820
-- The TileView's entry size: 5 columns of 200 in GRID_W, 3 rows of 270 in GRID_H. SetEntryWidth and SetEntryHeight
-- (one float each) are in /Script/UMG.TileView's native table 0x1461ff110 (registered by FUN_143d66670), execs
-- 0x143d66330 and 0x143d66440 (Ghidra, build 26123051, 26 Nov 2026).
local ENTRY_W,ENTRY_H=200,270
-- The detail panel right of a colour row's swatch, so it never covers a row's value box.
local DETAIL_X,DETAIL_Y=SWATCH_X+SWATCH_W+4,1160
-- The origin badge: 48 units square, by the detail panel's title, right of its 900-unit wide SizeBox_4 (widget JSON).
-- A kit image draws under every part, so it sits beside the panel, not on it. The panel ends at x 2061: 48 units end
-- the badge at EDGE with 3 units between them.
local BADGE=48
local BADGE_X,BADGE_Y=View.EDGE-BADGE,DETAIL_Y+8
-- An outfit row's preview picture (closet/thumbs.lua's snap: SNAP_W x SNAP_H, 0.8 as wide as tall) in the space
-- between the tabs and the detail panel (y 300 to DETAIL_Y, x DETAIL_X to EDGE), as tall as it fits, centred.
local PREVIEW_H=DETAIL_Y-40-300
local PREVIEW_W=math.floor(PREVIEW_H*0.8)
local PREVIEW_X,PREVIEW_Y=math.floor(DETAIL_X+(View.EDGE-DETAIL_X-PREVIEW_W)/2),300
-- Key hints, right to left from EDGE: the menu's row. Five (an outfit's row shows Back, Whole outfit, Options,
-- Favourite, Move) at the lobby's step of 420 would start at x 12, at the screen's edge: 400 starts them at x 112,
-- right of the left tab key's icon (TAB_ICON_X).
local HINT_STEP,HINT_Y,HINTS=400,1990,5
-- The camera's row above it: a fixed slot per chip in s.camera_hints' order (mode, reset, light, picture), the reset
-- chip ending at EDGE, Preview picture first at the row's left (x 112, the hints' left). x and w: the chip's left
-- edge and its click zone's width; col: where the label starts after the keyboard key (C, Backspace, V, P at about 17
-- units a Bold 30 character, plus 12). KEY_Y: the kit text's y in the row,
-- as ui/kit/kit.lua's hints put theirs (KEY_TEXT 9).
local CAMERA_Y,KEY_Y=1890,1899
local CAMERA={{x=1162,w=420,col=62},{x=1672,w=440,col=182},{x=600,w=560,col=62},{x=112,w=480,col=62}}

-- A value cut to VALUE_COLS columns: a CJK character takes two (as the menu test's width estimate counts them), a
-- narrow one (NARROW: a space, i, l, punctuation) a half, any other one. Whole when it fits, else its first characters
-- and '...' (three narrow ones) within them. Text that is not UTF-8 (a pack's own name) is cut by bytes: utf8.codes
-- raises on it.
local NARROW=" ilIjtfr.,:;'|!()-1"
local function cols(c)
    if c>=0x2E80 and c<0xFB00 or c>=0xFF00 and c<0xFFF0 then return 2 end
    return c<128 and NARROW:find(string.char(c),1,true) and 0.5 or 1
end
function View.fit(value)
    if not utf8.len(value) then return #value<=View.VALUE_COLS and value or value:sub(1,View.VALUE_COLS-2)..'...' end
    local n=0
    for _,c in utf8.codes(value) do n=n+cols(c) end
    if n<=View.VALUE_COLS then return value end
    local out,used={},1.5
    for _,c in utf8.codes(value) do
        if used+cols(c)>View.VALUE_COLS then break end
        used=used+cols(c)
        out[#out+1]=utf8.char(c)
    end
    return table.concat(out)..'...'
end

-- A game object by path: in memory, else after a synchronous LoadAsset (closet/ui/probe.lua's default_find), else
-- the asset registry helpers' GetAsset: a mod pack's asset that the cooked registry does not list (pack outfit images
-- were not found before, 27 Nov 2026). The registry step is a copy of closet/dress.lua's resolve.
local function find(path)
    local o=StaticFindObject(path)
    if o and o:IsValid() then return o end
    pcall(LoadAsset,path:match('^(.*)_C$') or path)
    o=StaticFindObject(path)
    if o and o:IsValid() then return o end
    local got,asset=pcall(function()
        local helpers=StaticFindObject('/Script/AssetRegistry.Default__AssetRegistryHelpers')
        return helpers:GetAsset({ObjectPath=FName(path)})
    end)
    return got and asset and asset:IsValid() and asset or nil
end

function View.new(kit,log)
    local P=Parts.new(kit,log,'closet')
    local call,sync,look=P.call,P.sync,P.look
    local v={}
    kit.add(View.GROUP,{x=0,y=0,w=3840,h=2160,fixed=true,hit=true},function(b)
        b.shade(0,0,SHADE_W,2160,{A=0.72})
        b.image(SHADE_W,0,FADE_W,2160,'shade_left') -- online/lobby/ui/lobby.lua's left gradient: the shade fades out.
        -- The dither under the hints ends with the shade: past it, beside EVE, it showed as a dark box.
        b.image(0,1860,SHADE_W,300,'dither',{A=0.8})
        local zones,swatches={},{}
        for i=1,WINDOW do zones[i]=b.row(ROW_X,ROW_Y+(i-1)*PITCH+27,ROW_W) end
        for i=1,WINDOW do
            swatches[i]=b.image(SWATCH_X,ROW_Y+(i-1)*PITCH+27,SWATCH_W,SWATCH_H,nil)
            swatches[i].show(false)
        end
        -- A chip over each menu hint, then over each camera hint (the SB hint part never takes the mouse,
        -- ui/kit/parts.lua): a clear kit row.
        for i=1,HINTS do zones[WINDOW+i]=b.row(View.EDGE-HINT_STEP*i,HINT_Y,HINT_STEP-20) end
        for i,c in ipairs(CAMERA) do zones[WINDOW+HINTS+i]=b.row(c.x,CAMERA_Y,c.w) end
        -- A hidden image a glyph: its texture as the brush keeps the engine from freeing it.
        local held={}
        for _,name in ipairs(View.GLYPHS) do
            held[name]=b.image(0,0,1,1,nil)
            held[name].show(false)
        end
        local badge=b.image(BADGE_X,BADGE_Y,BADGE,BADGE,nil)
        badge.show(false)
        local preview=b.image(PREVIEW_X,PREVIEW_Y,PREVIEW_W,PREVIEW_H,nil)
        preview.show(false)
        -- A hidden image a tile: tile i's picture, kept from the engine while the grid lists it.
        local pics={}
        for i=1,View.HOLD do
            pics[i]=b.image(0,0,1,1,nil)
            pics[i].show(false)
        end
        -- s.notice under the rows: the chat feed, where notices go, draws under this group's shade.
        local notice=b.text(ROW_X,NOTICE_Y,'','name',nil,nil,{wrap=ROW_W})
        -- The camera chips on the keyboard: the key in white, then the label, in the kit's hint style (wheel.lua's
        -- keyboard cells). Empty on a pad: SB's hint parts show the chips there.
        local cam_keys,cam_labels={},{}
        for i,c in ipairs(CAMERA) do
            cam_keys[i]=b.text(c.x,KEY_Y,'','hint',THEME.white)
            cam_labels[i]=b.text(c.x+c.col,KEY_Y,'','hint')
        end
        return {zones=zones,notice=notice,held=held,badge=badge,pics=pics,cam_keys=cam_keys,cam_labels=cam_labels,
            swatches=swatches,preview=preview}
    end)
    -- What is made and what it shows. top: the rows above the window; count: the rows of the last draw; tab_top: the
    -- first tab shown; camera: the camera's hint row.
    local tabs,tabs_sig,focus,rows,top,hints,count,keys={},nil,nil,{},0,{},0,{}
    local tab_top,camera=1,{}
    -- The word each hint chip runs as last drawn: the menu's (s.hints[i].word), then the camera's (s.camera_hints).
    local words={}
    local grid,tiles_sig,selected,detail,detail_sig,popup
    -- The grid's data objects as last filled, and their equipped marks (a mark that moves alone is set in place).
    local tile_items,equip_sig={},nil
    -- glyphed: each tile's glyph as last filled (false: the game icon); checking: a fill not yet seen right;
    -- check_at: the next look; by_brush: a shown tile lacked its glyph once, so every look sets the ones that lack it.
    local glyphed,checking,check_at,by_brush=nil,false,0,false
    -- scaled: each tile's icon scale as last filled (nil while no tile is small). The TileView hands its entry widgets
    -- to other tiles as it scrolls, so each look sets every shown entry's scale.
    local scaled,scale_at=nil,-1
    -- fills: grid fills since check_fills; fill_note: the last fill's changed tiles; filled_names: its tiles. A grid
    -- filled more than 3 times in 5 s is said with its last change (the picture glitch of 27 Nov 2026).
    local fills,fill_note,filled_names,check_fills=0,'',{},0
    local brushed={} -- Tile indices set by brush since the last fill, each said once.
    -- show_due: a fill or a move in the grid since the last tick (a look at once); show_at: the next look for slots
    -- left mid spawn animation; unstuck: such slots said, once a fill.
    local show_due,show_at,unstuck=false,0,0
    local has_tiles=false -- The grid's last fill had tiles: the stuck-slot look runs only then.
    local function make(class,x,y,w,h,fill,hit)
        local rec,why=kit.part(View.GROUP,class,x,y,w,h,fill,hit)
        if not rec then error(why,0) end
        return rec
    end

    -- Copied from ui/kit/guide.lua's texture() (November 2026): cache[key]'s texture as {o=, full=, path=its object
    -- path}, made again by make() only once the engine freed it; nil while make() gives nil (no player controller:
    -- tried again at the next draw) or once make() raised (said once with what and after).
    local function texture(cache,key,what,after,make)
        if cache[key]==false then return nil end
        local ok,got=pcall(function()
            local g=cache[key]
            local t=g and U.valid(g.o)
            if t and U.text(t:GetFullName())==g.full then return g end
            local x=make()
            if not x then return nil end
            local full=U.text(x:GetFullName())
            return {o=x,full=full,path=full:match('^%S+ (.+)$')}
        end)
        if not ok then
            cache[key]=false
            log('menu: '..what..' did not load ('..tostring(got)..')'..after)
            return nil
        end
        if got then cache[key]=got end
        return got
    end
    -- A PNG imported with the player controller, nil without one.
    local function import(file)
        local pc=U.controller()
        if not pc then return nil end
        return U.valid(U.find(RENDER):ImportFileAsTexture2D(pc,file)) or error('no texture from '..file,0)
    end
    -- A glyph's texture, its record's view the build whose holder has it.
    local glyphs={}
    local function glyph(name)
        local got=texture(glyphs,name,'the glyph '..name,': its tiles show the game icon',
            function() return import(HERE..'icons'..HERE:sub(-1)..name..'.png') end)
        if not got then return nil end
        local view=kit.view(View.GROUP)
        local holder=view and view.held[name]
        if holder and got.view~=view and holder.texture(got.o) then got.view=view end
        return got
    end
    -- A cached picture's texture (held by the grid fill), dropped by reread; an outfit's Image when it is a Texture2D
    -- (a cooked asset: the slot loads it again by its path).
    local pics,images,reads={},{},0
    -- Each import said (a preview picture taken twice showed white, then no tile: Schizo, 27 Nov 2026).
    local function picture(file)
        return texture(pics,file,'the picture '..file,': its tile shows its outfit\'s image or its glyph',
            function()
                local x=import(file)
                if x then log('menu: picture '..file..' imported as '..U.text(x:GetFullName())) end
                return x
            end)
    end
    local function image(path)
        return texture(images,path,'the image '..path,': its tiles show their picture or glyph',function()
            if path:sub(1,1)~='/' then error('not an object path',0) end
            local o=find(path) or error('not found',0)
            if not o:IsA(U.find(TEXTURE)) then error('not a Texture2D',0) end
            return o
        end)
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

    local function draw_rows(s,zones,swatches)
        local n=#s.rows
        count=n
        top=math.max(0,math.min(top,n-WINDOW))
        if s.row then
            if s.row>top+WINDOW then top=s.row-WINDOW elseif s.row<=top then top=s.row-1 end
            -- s.show below the window comes into it as far as the focused row stays in it.
            if s.show and s.show>top+WINDOW then top=math.max(top,math.min(s.show-WINDOW,s.row-1)) end
        end
        local specs={}
        for i=1,WINDOW do
            local row=s.rows[top+i]
            local value=row and not row.header and View.fit(row.value)
            -- A header row: SB's settings category header (ui/kit/parts.lua's header, as
            -- online/session/ui/create.lua shows its sections).
            if row and row.header then specs[i]=Parts.header(ROW_X,ROW_Y+(i-1)*PITCH+27,row.title)
            elseif row and row.slider then -- The settings menu's slider slot: its value text shows the number.
                local sl=row.slider
                specs[i]={kind='slider',x=ROW_X,y=ROW_Y+(i-1)*PITCH,w=ROW_W,h=ROW_H,
                    sig=row.title..'|'..sl.lo..'|'..sl.hi..'|'..sl.digits,fill=function(w)
                        w.TextTitleValue=FText(row.title)
                        w.ItemTextRange={Min=sl.lo,Max=sl.hi}
                        w.ItemTextFractionalDigits=sl.digits
                    end}
            else specs[i]=row and {kind='option',x=ROW_X,y=ROW_Y+(i-1)*PITCH,w=ROW_W,h=ROW_H,
                sig=row.title..'|'..value..(row.locked and '*' or ''),
                after=row.locked and 'RefreshAppearance' or nil,fill=function(w) -- SB's locked look.
                    w.Text_TitleValue=FText(row.title)
                    w.Text_ItemValue=FText(value)
                    if row.locked then w.bLockItem=true end
                end} or false end
        end
        sync(rows,View.GROUP,specs,WINDOW)
        for i=1,WINDOW do
            local rec,row=rows[i],s.rows[top+i]
            -- While the grid has the focus (s.grid) the focused tile is the only highlight: the row goes normal.
            local lit=top+i==s.row and not s.grid
            if rec and not (row and row.header) then look(rec,lit and 'focus' or 'normal') end
            -- A slider's place, on change only: CurrentPercent (its value text's) and UpdatePercentOffset (its bar).
            local sl=rec and row and row.slider
            if sl and not rec.sized then -- Once a part: its boxes sized to the row (see SLIDER_TITLE).
                rec.sized=true
                call(rec,'slider size',function(w)
                    w.WidgetSwitcher_0:GetParent():GetParent():SetWidthOverride(ROW_W) -- Overlay_0, then SizeBox_0.
                    w.Text_Title:GetParent():GetParent():SetWidthOverride(SLIDER_TITLE) -- HorizontalBox_0, SizeBox_3.
                    w.Slider_50:GetParent():GetParent():SetWidthOverride(SLIDER_BAR) -- Overlay_37, then SizeBox_1.
                    w.Slider_50.Slot:SetPadding(SLIDER_PAD)
                end)
            end
            if sl and rec.pct~=sl.pct then
                rec.pct=sl.pct
                call(rec,'slider place',function(w) w.CurrentPercent=sl.pct; w:UpdatePercentOffset(sl.pct) end)
            end
            -- The kit fallback: a row with no SB part shows on the kit row under it.
            if not row or kit.alive(rec) then zones[i].set('','')
            else
                zones[i].set(row.title,View.fit(row.value or ''),
                    row.locked and 'disabled' or lit and 'focus' or 'normal')
            end
            -- The swatch shows the colour as a tint (linear; an HDR channel shows at 1).
            local c=row and row.swatch
            swatches[i].show(c~=nil)
            if c then swatches[i].tint({R=math.min(1,c.R),G=math.min(1,c.G),B=math.min(1,c.B),A=1}) end
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
        -- Each tile's texture: its picture, else its image, else its glyph (looked up once a draw a glyph); its path is
        -- in the signature (a texture imported again).
        local names,shown,seen,any,pictured={},{},{},false,{}
        local small,any_small={},false
        for i,t in ipairs(s.tiles or {}) do
            local g=t.picture and picture(t.picture)
            pictured[i]=g
            g=g or t.image and image(t.image)
            if not g and t.icon then
                if seen[t.icon]==nil then seen[t.icon]=glyph(t.icon) or false end
                g=seen[t.icon]
            end
            shown[i]=g or false
            small[i]=t.small and (pictured[i] or t.image and g and g~=seen[t.icon]) and View.PICTURE_SCALE or 1
            any_small=any_small or small[i]~=1
            any=any or shown[i]~=false
            local path=shown[i] and shown[i].path or ''
            names[i]=t.name..(t.locked and '*' or '')..'@'..path..(small[i]~=1 and '~' or '')
        end
        -- The equipped marks apart from the rest: a preview moves the mark at each move in the grid, and a fill for
        -- it built every tile anew, so the tiles blinked (Schizo's video of 27 Nov 2026). WB_HairSalon_GridSlot's
        -- UpdateEquip(bEquip) sets a shown slot's mark in place (widget JSON).
        local marks={}
        for i,t in ipairs(s.tiles or {}) do marks[i]=t.equipped and '+' or '-' end
        local marks_sig=table.concat(marks)
        local sig=table.concat(names,'|')
        if sig==tiles_sig and marks_sig~=equip_sig then
            equip_sig=marks_sig
            call(grid,'grid equip',function(w)
                for i,t in ipairs(s.tiles or {}) do
                    if tile_items[i] then tile_items[i].Equiped=t.equipped==true end
                end
                U.each(w.TileView_ItemList:GetDisplayedEntryWidgets(),function(_,entry)
                    local item=tile_items[entry.Data.Index+1]
                    if item then entry:UpdateEquip(item.Equiped==true) end
                end)
            end)
        end
        -- Only pictures changed (the same tiles, names and locks: a preview picture taken, the pictures read again):
        -- those tiles get theirs in place, through their data objects and shown slots' brushes. A fill made every slot
        -- replay its spawn animation and left some see-through (Schizo, 27 Nov 2026).
        if sig~=tiles_sig and tiles_sig and #names>0 and #names==#filled_names then
            local changed={}
            for i,n in ipairs(names) do
                if (n:gsub('@.*$',''))~=(filled_names[i]:gsub('@.*$','')) then changed=nil; break end
                if n~=filled_names[i] then changed[#changed+1]=i end
            end
            if changed then
                tiles_sig,filled_names=sig,names
                glyphed,checking,check_at=any and shown or nil,any,0
                scaled,scale_at=any_small and small or nil,0
                local view=kit.view(View.GROUP)
                local now={}
                for _,i in ipairs(changed) do
                    now[i]=true
                    if pictured[i] and view and view.pics[i] then view.pics[i].texture(pictured[i].o) end
                    if tile_items[i] then tile_items[i].IconAssetPath=shown[i] and shown[i].path or ICON end
                end
                call(grid,'grid pictures',function(w)
                    U.each(w.TileView_ItemList:GetDisplayedEntryWidgets(),function(_,entry)
                        local i=entry.Data.Index+1
                        if now[i] and shown[i] then entry.Image_Icon:SetBrushFromTexture(shown[i].o,false) end
                    end)
                end)
            end
        end
        if sig~=tiles_sig then
            tiles_sig,selected=sig,nil
            fills,brushed,show_due,unstuck=fills+1,{},#names>0,0
            has_tiles=#names>0
            local changed={}
            for i=1,math.max(#names,#filled_names) do
                if names[i]~=filled_names[i] and #changed<4 then
                    changed[#changed+1]=i..': '..tostring(filled_names[i])..' -> '..tostring(names[i])
                end
            end
            fill_note,filled_names=table.concat(changed,'; '),names
            glyphed,checking,check_at=any and shown or nil,any,0 -- tick looks only at a grid with a glyph.
            -- A look at once when a tile is small or was (its entries then go back to full size once).
            scaled,scale_at=any_small and small or nil,(any_small or scaled) and 0 or -1
            local view=kit.view(View.GROUP)
            for i,g in pairs(pictured) do
                if view and view.pics[i] then view.pics[i].texture(g.o) end
            end
            local filled=false
            tile_items,equip_sig={},marks_sig
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
                    tile_items[i]=item
                    tv:AddItem(item)
                end
                filled=true
            end)
            -- A fill that raised leaves the grid empty or partial: the next draw fills it again.
            if not filled then tiles_sig=nil end
        end
        if s.tiles and s.tile and s.tile~=selected then
            selected,show_due=s.tile,true
            -- UListView.ScrollIndexIntoView(Index int): native table entry 0x1461e8850 (name 0x1461e6f90), exec
            -- 0x143d4b0d0 reads the index, checks it against the list's items (+0x810, count +0x818) and gives that
            -- item to the Slate list to scroll to (+0x728, then FUN_142e28210) (Ghidra, build 26123051, 27 Nov 2026).
            -- Without it the focus ran past the rows on screen.
            call(grid,'grid select',function(w)
                w.TileView_ItemList:SetSelectedIndex(s.tile-1)
                w.TileView_ItemList:ScrollIndexIntoView(s.tile-1)
            end)
        end
    end

    -- The focused outfit's preview picture, on change only (reads: a picture taken anew is the same file).
    local function draw_preview(s,view)
        local want=s.preview and s.preview..'#'..reads or false
        if view.preview_shown==want then return end
        local g=s.preview and picture(s.preview)
        view.preview_shown=g and want or false
        view.preview.show(g~=nil and view.preview.texture(g.o))
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
        draw_rows(s,view.zones,view.swatches)
        view.notice.set(s.notice)
        draw_grid(s)
        draw_detail(s,view)
        draw_preview(s,view)
        words={}
        local specs={}
        for i=1,HINTS do
            local h=s.hints[i]
            words[i]=h and h.word
            specs[i]=h and Parts.hint(View.EDGE-HINT_STEP*i,HINT_Y,h[1],h[2],h[3]) or false
        end
        sync(hints,View.GROUP,specs,HINTS)
        -- The camera row: SB's hint parts on a pad (its glyphs), the kit's key and label texts on the keyboard.
        local cams=s.camera_hints or {}
        specs={}
        for i,c in ipairs(CAMERA) do
            local h=cams[i]
            words[HINTS+i]=h and h.word
            specs[i]=h and s.pad and Parts.hint(c.x,CAMERA_Y,h[1],h[2]) or false
            view.cam_keys[i].set(h and not s.pad and h.key or '')
            view.cam_labels[i].set(h and not s.pad and h[1] or '')
        end
        sync(camera,View.GROUP,specs,#CAMERA)
        draw_popup(s)
        -- The grid's entries (a fill, a selection) and the popup's Construct take the keyboard focus; on them a key
        -- reaches EVE (E fired a skill). On the kit's root the game ignores keys (closet/ui/probe.lua test 5).
        kit.refocus()
    end

    -- Each frame while open (closet/ui/menu.lua's tick; t: its time in s). After a fill, a look at the shown tiles each
    -- View.CHECK s until one finds each with its glyph (Slate builds them on later frames). A tile that lacks it (its
    -- path did not load in the slot) gets it on its Image_Icon. From then on every look does that, said once.
    -- A slot the TileView took back mid ListSpawn (WB_HairSalon_GridSlot's animation: SizeBox_20's RenderOpacity from 0
    -- and a RenderTransform slide, widget JSON) stays see-through: with no animation playing it is shown whole.
    -- UUserWidget IsAnyAnimationPlaying (native entry 0x1461fe0c0, exec 0x143d69990: its active players at +0x1c8 > 0),
    -- UWidget.RenderOpacity, a float at +0xc4 (property params 0x146200c08), read as a property: GetRenderOpacity
    -- called through UE4SS gave "attempt to call a TrivialObject value" in game. SetRenderOpacity (entry 0x1462030d0,
    -- exec 0x143d74f80), SetRenderTranslation (entry 0x146203130, exec 0x143d758b0 writes the FVector2D at +0x90)
    -- (Ghidra, build 26123051, 27 Nov 2026). A refused call is said once and never stops the glyph look.
    local unstick_said=false
    local shown_note=nil -- The last 'the grid draws' line.
    -- A drawn slot as words: its tile number, then what is off (UWidget Visibility and RenderOpacity, read as
    -- properties; SizeBox_20's opacity), for the log. ESlateVisibility: Visible 0, Collapsed 1, Hidden 2,
    -- HitTestInvisible 3, SelfHitTestInvisible 4 (enumerator array 0x1461f6f20, Ghidra, build 26123051).
    local function slot_note(entry)
        local ok,i=pcall(function() return entry.Data.Index+1 end)
        i=ok and tonumber(i) or 0
        local off={}
        local function read(f) local r,v=pcall(f); return r and v or nil end
        local vis=tonumber(read(function() return U.value_of(entry.Visibility) end))
        if vis and vis~=0 and vis~=3 and vis~=4 then off[#off+1]='vis'..vis end
        local own=tonumber(read(function() return U.value_of(entry.RenderOpacity) end))
        if own and own<0.99 then off[#off+1]=string.format('op%.2f',own) end
        local box=tonumber(read(function() return U.value_of(entry.SizeBox_20.RenderOpacity) end))
        if box and box<0.99 then off[#off+1]=string.format('box%.2f',box) end
        return {i=i,text=#off>0 and i..'('..table.concat(off,',')..')' or tostring(i)}
    end
    local function unstick(entry)
        local ran,why=pcall(function()
            local box=entry.SizeBox_20
            if not box or entry:IsAnyAnimationPlaying() then return end
            local o=tonumber(U.value_of(box.RenderOpacity))
            -- The slot itself too: a whole hair tile, frame and all, stayed hidden with SizeBox_20 whole (27 Nov 2026).
            local own=tonumber(U.value_of(entry.RenderOpacity))
            local moved=box.RenderTransform and box.RenderTransform.Translation
            local slid=moved and ((tonumber(moved.X) or 0)~=0 or (tonumber(moved.Y) or 0)~=0)
            local fixed={}
            if o and o<0.99 then box:SetRenderOpacity(1); fixed[#fixed+1]='SizeBox_20 opacity '..o end
            if own and own<0.99 then entry:SetRenderOpacity(1); fixed[#fixed+1]='slot opacity '..own end
            if slid or #fixed>0 then box:SetRenderTranslation({X=0,Y=0}) end
            if slid then fixed[#fixed+1]='slid '..tostring(moved.X)..','..tostring(moved.Y) end
            if #fixed==0 then return end
            unstuck=unstuck+1
            if unstuck==1 then
                log('menu: tile '..(entry.Data.Index+1)..' was left mid spawn animation ('..table.concat(fixed,', ')
                    ..'): shown')
            end
        end)
        if not ran and not unstick_said then
            unstick_said=true
            log('menu: a stuck slot could not be shown: '..tostring(why))
        end
    end
    function v.tick(t)
        if show_due then show_due,show_at=false,0 end
        -- Every CHECK s while the grid has tiles, not only 1 s after a change: earring tiles stayed see-through past it
        -- in game (27 Nov 2026).
        local show=grid~=nil and has_tiles and t>=show_at
        if show then show_at=t+View.CHECK end
        local glyph_look=glyphed and (checking or by_brush) and t>=check_at
        -- A look for stuck slots on its own only when the glyph look below does not run this tick.
        if show and not glyph_look then
            call(grid,'grid show',function(w)
                local shown={}
                U.each(w.TileView_ItemList:GetDisplayedEntryWidgets(),function(_,entry)
                    unstick(entry)
                    shown[#shown+1]=slot_note(entry)
                end)
                table.sort(shown,function(x,y) return x.i<y.i end)
                local words={}
                for _,n in ipairs(shown) do words[#words+1]=n.text end
                local note=table.concat(words,' ')
                -- Said when it changes: a hair tile stayed missing with no slot left see-through (27 Nov 2026).
                if note~=shown_note then shown_note=note; log('menu: the grid draws '..#shown..' slots: '..note) end
            end)
        end
        if t>=check_fills then
            if fills>3 then log('menu: the grid filled '..fills..' times in 5 s; last change '..fill_note) end
            fills,check_fills=0,t+5
        end
        -- UWidget SetRenderScale(Scale) (native entry 0x1462030e0, exec 0x143d75b50 writes the FVector2D at +0x98,
        -- RenderTransform.Scale; Ghidra, build 26123051, 27 Nov 2026).
        if scaled and t>=scale_at then
            scale_at=t+View.CHECK
            call(grid,'grid scale',function(w)
                U.each(w.TileView_ItemList:GetDisplayedEntryWidgets(),function(_,entry)
                    local want=scaled[entry.Data.Index+1] or 1
                    local icon=entry.Image_Icon
                    if icon.RenderTransform.Scale.X~=want then icon:SetRenderScale({X=want,Y=want}) end
                end)
            end)
        elseif not scaled and scale_at>=0 then
            -- The last small tile gone: the entries the TileView keeps go back to full size once.
            scale_at=-1
            call(grid,'grid scale',function(w)
                U.each(w.TileView_ItemList:GetDisplayedEntryWidgets(),function(_,entry)
                    if entry.Image_Icon.RenderTransform.Scale.X~=1 then entry.Image_Icon:SetRenderScale({X=1,Y=1}) end
                end)
            end)
        end
        if not glyph_look then return end
        check_at=t+View.CHECK
        local seen,wrong,done=0,0,false
        call(grid,'grid glyphs',function(w)
            U.each(w.TileView_ItemList:GetDisplayedEntryWidgets(),function(_,entry)
                if show then unstick(entry) end
                local g=glyphed[entry.Data.Index+1]
                if not g then return end
                seen=seen+1
                local now=U.valid(entry.Image_Icon.Brush.ResourceObject)
                if now and U.text(now:GetFullName())==g.full then return end
                wrong=wrong+1
                local i=entry.Data.Index+1
                if not brushed[i] then
                    brushed[i]=true
                    log('menu: tile '..i..' set by brush: it had '..(now and U.text(now:GetFullName()) or 'none')
                        ..', wants '..g.full..(U.valid(g.o) and '' or ' (gone)'))
                end
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
        for i=1,HINTS+#CAMERA do
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
    -- The imported pictures dropped: imported again as next drawn (the menu's open).
    function v.reread() pics,reads={},reads+1 end
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
        tile_items,equip_sig={},nil
        glyphed,checking=nil,false
    end
    return v
end

return View
