-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Uplink kit (UI-DESIGN 3.2, 7.1-7.6): one root a world, a plain UserWidget built by hand, holding every group the
-- views add (the menu, the feed, the card, the marker), each a canvas of its own, hidden (Collapsed) when unused, never
-- removed. Hit tests pass through every group but one marked hit (the menu: its rows take the mouse). Each 250 ms
-- (slow): the root an earlier Lua load left (Ctrl+R) is swept by its path; the classes and the game's fonts, textures
-- and sounds warm one lookup a tick (about 4 ms each; more while veiled; none until the keep settled), those assets
-- being the keep's (core/keep.lua), so a map change frees none of them; the root is built in one call once the
-- classes are in (in the default font and flat colour while an asset it uses still warms: the menu works from the
-- start; each texture it wanted held by a collapsed image of it once warmed, so the engine's GC cannot free it first),
-- built once again when those are in (not while the menu is open), checked to be still ours and in the viewport each
-- tick, and built again, as it was, once a map change took it (off after 4 losses in a row: no rebuild storm). Each
-- frame (tick): only the open and close tweens, while one runs. Updates touch the engine only on change, and only a
-- widget still ours: a map change frees them, and an address may hold another object by then. Every engine call runs in
-- pcall on the game thread, never in a coroutine; the first error in a build or an update turns the kit off for this
-- Lua load (off(): the callers go back to the notice line above EVE and the name tag), said once by the next slow or
-- tick. A look that cannot be had (a font, a texture, a text colour) only degrades, with one log line a build.
local U=require('core.unreal')
local Keep=require('core.keep')
local valid,value_of=U.valid,U.value_of
local Ui={}
local Z=100 -- The root's viewport z.
-- s of warm-up lookups a 250 ms tick while veiled (veil): at least one, then more until this is spent. The 7 assets a
-- map change frees took up to 36 ms each to load again.
Ui.VEIL_BUDGET=0.1
local UMG={'UserWidget','WidgetTree','CanvasPanel','Border','TextBlock','Image','ProgressBar','EditableTextBox'}
local GAME_FONT,ENGINE_FONT='/Game/Art/Font/Bold.Bold','/Engine/EngineFonts/Roboto.Roboto'
local DOTS='/Game/Art/UI/Texture/HUD/Gauge/Hp_Dot1_5x.Hp_Dot1_5x'
local HIT_TEST_INVISIBLE,TILE_BOTH=3,3 -- ESlateVisibility, ESlateBrushTileType.
local function ms(since) return (os.clock()-since)*1000 end
local function need(value,why) -- assert's check, its message without a source position (it goes to the log as is).
    if not value then error(why,0) end
    return value
end
-- The keep's object for a path it serves; else an object in memory, else after LoadAsset (synchronous; via: the asset
-- whose package holds it); nil when neither.
local function load(path,via)
    if Keep.serves(path) then return Keep.get(path) end
    local found=valid(StaticFindObject(path))
    if found then return found end
    pcall(LoadAsset,via or path)
    return valid(StaticFindObject(path))
end
local P=require('ui.kit.hud_parts')
local function linear(byte) local c=byte/255; return c<=0.04045 and c/12.92 or ((c+0.055)/1.055)^2.4 end
-- A colour as Slate shows it ('ADD1C4') to the linear one the engine takes.
local function hex(h,a)
    return {R=linear(tonumber(h:sub(1,2),16)),G=linear(tonumber(h:sub(3,4),16)),B=linear(tonumber(h:sub(5,6),16)),
        A=a or 1}
end
-- Uplink: the game's palette, teal for everything partner (the game's shield teal; enemies are red), Beta blue focus.
Ui.THEME={text=hex('ECECEC'),grey=hex('B5B5B5'),dim=hex('6E6E6E'),teal=hex('ADD1C4'),beta=hex('CCE9F4'),
    burst=hex('DD8874'),warn=hex('DC8834'),error=hex('D85045'),white=hex('FFFFFF'),panel=hex('0A0E12',0.78),
    rail=hex('DEDBDE',0.25),focus=hex('CCE9F4',0.12),empty=hex('6E6E6E',0.5),clear=hex('000000',0),
    shade=hex('000000',0.55)}
local THEME=Ui.THEME
local function path(p) return p..'.'..p:match('[^/]+$') end
local TEX,GAUGE='/Game/Art/UI/Texture/','/Game/Art/UI/Texture/HUD/Gauge/'
-- The key icons of the game's own menus (80 by 80; PC_ActionAssist's are 128 with a shadow, two of them named in
-- another case).
local KEY,SOUND=TEX..'Interaction/PC/KeyIcon_KeyBoard_','/Game/Sound/UI/'
-- Name and object path, in warm-up order; the sounds (with their volume) last: the build does not wait for them. alt:
-- the one tried when it is missing. Each path in the case of the game's files as a pak export gives them (the chevron's
-- 'WorkShop'; a pak listing says 'Workshop'). key_arrows and chevron were missing in game with another case; that the
-- case was the cause is unproven (the engine's name lookups ignore case), so both have a fallback.
Ui.ASSETS={{'Bold',GAME_FONT},{'Mideum',path('/Game/Art/Font/Mideum')},{'AGENCYB',path('/Game/Art/Font/AGENCYB')},
    {'FZSHANGYTJW',path('/Game/Art/Font/English/FZSHANGYTJW_Font')},{'Roboto',ENGINE_FONT},{'dot',DOTS},
    {'dot_bg',path(GAUGE..'Hp_Dot1_5x_bg')},{'small',path(GAUGE..'Hp_Dot_12')},{'small_bg',path(GAUGE..'Hp_Dot_12bg')}}
for i=0,4 do table.insert(Ui.ASSETS,{'cube'..i,path(GAUGE..'Beta_cube_0'..i)}) end
for _,a in ipairs({{'mark',TEX..'Item/CommonIcon/4DotMark'},{'link',TEX..'Common/selectdot'},
        {'chevron',TEX..'WorkShop/TriPatternUp',alt=TEX..'HUD/triangle'},
        {'diamond',TEX..'HUD/Tracking_Icon/TrackingMarker'},
        {'key_enter',KEY..'Enter'},{'key_escape',KEY..'Escape'},{'key_space',KEY..'SpaceBar'},{'key_up',KEY..'Up'},
        {'key_arrows',KEY..'DirectionAll',alt=TEX..'Interaction/PC_ActionAssist/KeyIcon_KeyBoard_directionAll'},
        {'key_move',KEY..'MoveAll'},{'key_move_azerty',KEY..'MoveAll_AZERTY'},
        -- The lobby screens': SB's title logo (WB_Lobby's Chinese ones), its shades, the HUD's soft shadow, a dither.
        {'logo',TEX..'Splash/Main_title'},{'logo_hans',TEX..'Splash/Main_title_hans'},
        {'logo_hant',TEX..'Splash/Main_title_hant'},{'shade_left',TEX..'Common/lobby_menu_gra'},
        {'shade_bottom',TEX..'Common/theater_subtitle_gra'},{'more_shadow',TEX..'HUD/HUD_MoreShadow'},
        {'dither',TEX..'Common/gradation_dithering_white'},
        -- The emote wheel's (ui/kit/wheel.lua): WB_MainHUD_ItemEquip's slot pieces for 6, 5, 4 and 3 slots and their
        -- lit look, its centre's dotted circle, pointer arc and soft disc; the mouse's key icons (the F-keys' below).
        {'wheel6',TEX..'HUD/Wheel/ItemEquipWheel6Bg_Cut'},{'wheel6_focus',TEX..'HUD/Wheel/ItemEquipWheel6Focus_Cut'},
        {'wheel5',TEX..'HUD/Wheel/ItemEquipWheel5Bg'},{'wheel5_focus',TEX..'HUD/Wheel/ItemEquipWheelFocusRing_5bg'},
        {'wheel4',TEX..'HUD/Wheel/ItemEquipWheel4Bg_Cut'},{'wheel4_focus',TEX..'HUD/Wheel/ItemEquipWheel4Focus_Cut'},
        {'wheel3',TEX..'HUD/Wheel/ItemEquipWheel3Bg_Cut'},{'wheel3_focus',TEX..'HUD/Wheel/ItemEquipWheel3Focus_Cut'},
        {'wheel_dots',TEX..'HUD/Wheel/ItemEquipWheelDotLines'},
        {'wheel_pointer',TEX..'HUD/Wheel/ItemEquipWheelPositionDotLine'},{'wheel_blur',TEX..'Common/blur_circle2'},
        {'key_mouse',TEX..'Interaction/PC/KeyIcon_Mouse_Mouse2D'},
        {'key_mouse_right',TEX..'Interaction/PC/KeyIcon_Mouse_RightMouseButton'},
        {'open',SOUND..'MainMenu/Ui_MoveIn_Cue',1},{'close',SOUND..'MainMenu/UI_MoveOut_Cue',1},
        {'move',SOUND..'UI_Common_Hover_Cue',1},{'select',SOUND..'ui_button_Confirm_Cue',1},
        {'back',SOUND..'ui_button_cancel',1},{'change',SOUND..'MainMenu/UI_Setting_Select_Cue',1},
        {'chat',SOUND..'ui_notice_Cue',0.5},{'alert',SOUND..'ui_SystemNotice_Cue',1},
        -- SB's popup cues (WB_Common_Popup's PopupOpenSound, PopupCloseSound and PopupAcceptSound): the join popups'.
        {'popup_open',SOUND..'CommonPopup/UI_Common_Popup_Open_Cue',1},
        {'popup_close',SOUND..'CommonPopup/UI_Common_Popup_Close_Cue',1},
        {'popup_confirm',SOUND..'CommonPopup/UI_Common_Popup_Confirm_Cue',1},
        -- The item wheel's open and focus sounds (WB_MainHUD_ItemEquip's): the emote wheel's.
        {'wheel_open',SOUND..'UI_BodySuit_Open',1},{'wheel_move',SOUND..'ui_move',1}}) do
    table.insert(Ui.ASSETS,{a[1],path(a[2]),volume=a[3],alt=a.alt and path(a.alt)})
end
-- The F-key icons but F10's (the console's), key_f1 to key_f12, for the emote wheel's key: before the sounds.
local first_sound=1
while not Ui.ASSETS[first_sound].volume do first_sound=first_sound+1 end
for n=1,12 do
    if n~=10 then
        table.insert(Ui.ASSETS,first_sound,{'key_f'..n,path(KEY..'F'..n)})
        first_sound=first_sound+1
    end
end
local VOLUME={}
for _,a in ipairs(Ui.ASSETS) do VOLUME[a[1]]=a.volume end
local CLASSES={}
for _,name in ipairs(UMG) do CLASSES[#CLASSES+1]='/Script/UMG.'..name end
local STATICS,WIDGETS='/Script/Engine.Default__GameplayStatics','/Script/UMG.Default__WidgetBlueprintLibrary'
local LANGUAGE='/Script/Engine.Default__KismetInternationalizationLibrary'
local LAYOUT='/Script/UMG.Default__WidgetLayoutLibrary'
for _,class in ipairs({'/Script/Engine.PlayerController',STATICS,WIDGETS,LANGUAGE,LAYOUT}) do
    CLASSES[#CLASSES+1]=class
end
-- Text styles: font and size in layout units (UI-DESIGN 3.2's typography).
local STYLES={title={'Bold',56},item={'Bold',40},name={'Bold',36},hint={'Bold',30},body={'Mideum',34},
    status={'Mideum',30},head={'Mideum',28},num={'AGENCYB',30},label={'FZSHANGYTJW',30}}
local VISIBLE,COLLAPSED,SELF_HIT=0,1,4 -- ESlateVisibility: hit, none, children only.
-- Row height; tween seconds; slide units; rebuilds in a row for a root that left the viewport, then off; units an
-- inside group keeps from the viewport's edges.
local ROW,OPEN,CLOSE,SLIDE,LOSSES,SAFE=76,0.16,0.12,32,3,48
local REFOCUS=0.05 -- Seconds from a mouse button to our focus put back (Slate moves the focus as it takes the press).
-- A key hint's icon, square, as the game's photo mode draws these icons beside its text; its label's top below the
-- icon's, so the hint style's line sits on the icon's middle.
local KEY_ICON,KEY_TEXT=66,9
local function make(n,class,outer)
    local x=valid(StaticConstructObject(n.classes[class],outer))
    if not x then error(class..' not constructed',0) end
    n.count=n.count+1
    return {o=x,name=U.text(x:GetFullName())}
end
local function put(canvas,w,x,y,width,height) -- Layout units: the HUD's 3840x2160.
    -- In a hit group, hit tests pass through every widget not said otherwise (a row's own area takes them).
    if canvas.hit and w.v==nil then w.v=HIT_TEST_INVISIBLE; w.o:SetVisibility(w.v) end
    w.slot=need(valid(canvas.o:AddChildToCanvas(w.o)),'no canvas slot')
    w.slot:SetPosition({X=x,Y=y})
    if width then w.slot:SetSize({X=width,Y=height}) else w.slot:SetAutoSize(true) end
    return w
end
local function hide(w) w.v=COLLAPSED; w.o:SetVisibility(COLLAPSED) end
local controller=U.controller
-- opts: {log=function(line), store={save,load,clear} (link.store('coop-ui.txt')), azerty=true or false for the AZERTY
-- move keys (unset: azerty() at each build), uidev=function returning SB's input device byte or nil (link.uidev),
-- scale=ui_scale (75 to 150 %), sounds=false for ui_sounds=off}.
function Ui.kit(opts)
    opts=opts or {}
    local log=opts.log or function() end
    local store=opts.store or {save=function() end,load=function() end,clear=function() end}
    local self,order,by,cache,found={},{},{},{},{} -- cache: asset name to {o=, full=} or false (not in this build).
    local built,pending,off,said,hidden,swept,lost,holder=nil,nil,false,nil,false,false,0,nil
    local veiled=false -- veil(): the root collapsed under SB's black while the lobby gets ready.
    local pointing=false -- The holder asked for the mouse cursor (the guide's, input's mouse).
    local quiet,no_color,sounding,tweens,inputting=false,false,opts.sounds~=false,{},false
    local screen,projecting=nil,true -- The viewport in layout units, read once a second; the engine's projection.
    local titled=false -- The title screen shows (slow's title): the input given back there is the title menu's.
    local cursor=nil -- While the menu shows the mouse cursor: whether the game showed it before (put back after).
    -- The focus watchdog: since the input was taken ({at=, armed=a yes read, since=the first no after it}), who it
    -- fired for (lost() takes it), and its two lines said.
    local watch,fired,unfocusable_said,never_said=nil,nil,false,false
    local refocus_at=nil -- A mouse button pressed while our UI holds the game's input: when our focus goes back.
    local clicked_at=nil -- That button's clock, for the watchdog's focus line.
    local parts,warmed={},{} -- warm_part's object paths in order; those looked up.
    -- SB's last keyboard answer, AZERTY or not: its device byte (opts.uidev) reads 1 for a QWERTY keyboard and 2 for one
    -- whose scan code 0x10 types A; 3 to 6 are pads, 0 is before SB's first device report (L10-R1).
    local keyboard=nil
    for _,a in ipairs(Ui.ASSETS) do Keep.want({a[2],a.alt}) end -- A no-op once kept: each kit made wants them.
    local function device()
        local d=opts.uidev and opts.uidev()
        if d==1 or d==2 then keyboard=d==2 end
    end
    local function clamp(pct) return math.max(75,math.min(150,tonumber(pct) or 100))/100 end
    local scale=clamp(opts.scale)
    -- A group's scale at ui_scale s (the current one unless said): 1 for a fixed group, else s up to its most.
    local function scale_of(p,s) return p.fixed and 1 or math.min(s or scale,p.most or math.huge) end
    -- A widget record ({o=, name=, slot=, v=its visibility as last set}): its object while it is still ours.
    local function alive(w)
        local x=w and valid(w.o)
        return x and U.text(x:GetFullName())==w.name and x or nil
    end
    -- The root's path for the next Lua load's sweep (Ctrl+R), with ' input' while the game's input is ours and
    -- ' cursor' while we show the mouse cursor (' cursor shown' when the game showed it before, as the title menu
    -- does): that load gives the input back and puts the cursor back as it was (the ignore-input flag lives in the
    -- game's viewport and the cursor in its player controller, which a Lua reload keeps).
    local function keep()
        if built then
            store.save(built.root.name:match('^%S+ (.+)$')..(inputting and ' input' or '')..(cursor~=nil and ' cursor'
                or '')..(cursor and ' shown' or ''))
        end
    end
    -- The game's input (UI-DESIGN 7.5): on, the game ignores its keys and mouse (SetInputMode_UIOnlyEx with our root
    -- focused, the menu's keys being UE4SS binds, which read the keyboard whatever has focus; or with a text box and
    -- its keyboard focus, the chat's); off, the game's again: GameOnly in a world; at the title GameAndUIEx with no
    -- mouse capture, so the title menu keeps its mouse cursor (GameOnly when the engine refuses it). The menu (holder
    -- nil), and a holder that asks for it (the guide), also show the mouse cursor, after the input mode; the value
    -- found goes back once a holder that does not ask takes the input, or it is given back. With no player controller
    -- (a map loads) or no root: nothing, and the change still due (input tries again). inputting changes before the
    -- engine call: a refused call is not tried again by the fault it raises.
    local function input_mode(on,field)
        local pc,root=controller(),on and alive(built.root)
        if not pc or (on and not root) then return end
        local box=on and field and alive(field)
        inputting=on
        if on then
            U.find(WIDGETS):SetInputMode_UIOnlyEx(pc,box or root,0)
            if box then box:SetKeyboardFocus() end
        else
            local lib=U.find(WIDGETS)
            if not (titled and pcall(function() lib:SetInputMode_GameAndUIEx(pc,nil,0,false) end)) then
                lib:SetInputMode_GameOnly(pc)
            end
        end
        watch=on and {at=os.clock()} or nil
        if on and (holder==nil or pointing) then
            if cursor==nil then cursor=pc.bShowMouseCursor==true end
            pc.bShowMouseCursor=true
        elseif cursor~=nil then
            pc.bShowMouseCursor=cursor
            cursor=nil
        end
        keep()
    end
    local function close_all()
        if inputting then pcall(input_mode,false) end -- A fault or coop off never leaves the game deaf.
        off,tweens=true,{}
        for _,n in ipairs({built or false,pending or false}) do
            if n then pcall(function() local r=alive(n.root); if r then r:RemoveFromParent() end end) end
        end
        built,pending=nil,nil
        pcall(store.clear)
    end
    local function fail(why)
        if off then return end
        close_all()
        said='UI off until the mod reloads: '..tostring(why)..'; notices stay on the line above EVE'
    end
    local function said_once()
        local m=said
        said=nil
        if m then return false,m end
    end
    local function run(f,...)
        if off then return end
        if pending then return f(...) end -- In a build (a view's set): an error stops the build, in its own run.
        local ok,why=pcall(f,...)
        if not ok then fail(why) end
    end
    local function upd(w,f) run(function() local x=alive(w); if x then f(x) end end) end -- Only while still ours.
    -- Shown (w.on: its visibility shown, hit tests passing through unless said) or collapsed; never an image whose
    -- texture is missing (gone).
    local function show_w(w,on)
        if w.gone then return end
        local v=on and (w.on or HIT_TEST_INVISIBLE) or COLLAPSED
        if w.v==v then return end
        w.v=v
        upd(w,function(x) x:SetVisibility(v) end)
    end
    -- A text colour; white for good once the engine refuses one.
    local function paint(x,c,n)
        if not no_color and pcall(function() x:SetColorAndOpacity({SpecifiedColor=c,ColorUseRule=0}) end) then
            return
        end
        if n then n.look['text colour refused (white)']=true -- In each build's look line.
        elseif not no_color then log('UI text colours off: refused') end
        no_color=true
    end
    -- The widgets of one group (g: its canvas), made while build n runs.
    local function builder(n,g)
        local b={}
        -- An asset of the look; a build that wants one still warming is partial (built again once it is in).
        local function get(name)
            if cache[name]==nil and not n.assets[name] then n.partial=true end
            return n.assets[name]
        end
        -- An image: tex (an asset name, nil for flat colour) tiled or not, else flat colour (flat: that colour, tint
        -- unless said; false: hidden instead).
        local function image(x,y,width,height,tex,tint,tiled,flat)
            local w=make(n,'Image',n.tree.o)
            local t=tex and get(tex)
            if tex and not t then n.look[tex..' missing']=true end
            if t and tiled then
                local wrote=pcall(function() value_of(w.o.Brush).Tiling=TILE_BOTH end)
                if not (wrote and value_of(w.o.Brush).Tiling==TILE_BOTH) then
                    n.look['brush tiling did not take']=true
                    t=nil
                end
            end
            if t then w.o:SetBrushFromTexture(t,true) end
            w.o:SetColorAndOpacity((t or not flat) and tint or flat)
            if tex and not t and flat==false then hide(w); w.gone=true end
            return put(g,w,x,y,width,height)
        end
        -- A line of text in a style (STYLES) and colour, its point (x, y) at align of its box (top left unless said;
        -- {X=0, Y=0.5}: centred on that line); o: {shadow={x, y, r, g, b, a} (its offset and linear colour), wrap=its
        -- width in layout units, written as is, like the font size}. set(text), color(c), show(on).
        local function text(x,y,str,style,color,align,o)
            local w=make(n,'TextBlock',n.tree.o)
            local st=STYLES[style] or STYLES.body
            local f=get(st[1]) or get('Roboto')
            if not f then n.look['no font (default font)']=true
            elseif not pcall(function() local v=value_of(w.o.Font); v.FontObject=f; v.Size=st[2] end)
                and not pcall(function() w.o:SetFont({FontObject=f,Size=st[2]}) end) then
                n.look['font writes refused (default font)']=true
            elseif f~=n.assets[st[1]] then n.look[st[1]..' missing (Roboto)']=true end
            str,color=str or '',color or THEME.text
            w.o:SetText(FText(str))
            paint(w.o,color,n)
            local sh=o and o.shadow
            if sh and not pcall(function()
                w.o:SetShadowOffset({X=sh[1],Y=sh[2]})
                w.o:SetShadowColorAndOpacity({R=sh[3],G=sh[4],B=sh[5],A=sh[6]})
            end) then n.look['text shadow refused']=true end
            -- WrapTextAt alone: with AutoWrapText the engine wraps at min(WrapTextAt, last drawn width), and an
            -- auto-sized slot never grows back (UE 4.26 FSlateTextBlockLayout::CalculateWrappingWidth).
            if o and o.wrap and not pcall(function() w.o.WrapTextAt=o.wrap end) then
                n.look['text wrap refused']=true
            end
            put(g,w,x,y)
            if align then w.slot:SetAlignment(align) end
            return {set=function(s) s=s or ''; if s~=str then str=s; upd(w,function(x2) x2:SetText(FText(s)) end) end end,
                color=function(c) if c~=color then color=c; upd(w,function(x2) paint(x2,c) end) end end,
                show=function(on) show_w(w,on) end}
        end
        b.text=text
        -- The panel: cold glass, and the game's dotted rails along its top and bottom.
        function b.panel(x,y,width,height)
            local w=make(n,'Border',n.tree.o)
            w.o:SetBrushColor(THEME.panel)
            put(g,w,x,y,width,height)
            local rail=math.floor((width-48)/10)*10
            image(x+24,y+12,rail,10,'small',THEME.rail,true,false)
            image(x+24,y+height-22,rail,10,'small',THEME.rail,true,false)
        end
        -- Flat colour that takes the mouse in a hit group, so no click reaches what lies under it (the co-op saves'
        -- question over the title menu); hit tests pass through it elsewhere.
        function b.shade(x,y,width,height,color)
            local w=image(x,y,width,height,nil,color)
            if g.hit then w.v,w.on=VISIBLE,VISIBLE; w.o:SetVisibility(VISIBLE) end
        end
        -- An image by asset name (nil: flat colour; missing: none, never a white square): show(on), tint(c),
        -- turn(degrees, clockwise) around pivot (its own size's fraction; its centre unless said) and texture(t).
        function b.image(x,y,width,height,tex,tint,pivot)
            tint=tint or THEME.white
            local w=image(x,y,width,height,tex,tint,nil,false)
            if pivot then w.o:SetRenderTransformPivot(pivot) end
            local angle=0
            return {show=function(on) show_w(w,on) end,
                tint=function(c) if c~=tint then tint=c; upd(w,function(x2) x2:SetColorAndOpacity(c) end) end end,
                turn=function(a)
                    if a~=angle then angle=a; upd(w,function(x2) x2:SetRenderTransformAngle(a) end) end
                end,
                -- A texture made at run time (the guide's art): true once its brush has it; a refused call only
                -- returns false, the kit stays on.
                texture=function(t)
                    local x2=alive(w)
                    return x2~=nil and pcall(function() x2:SetBrushFromTexture(t,true) end)
                end}
        end
        -- Dots of the HUD's gauges ('big': its 15-unit dots, 'small': the 10-unit ones), cols by rows, tiled, lit over
        -- empty: set(lit, shown), lit columns of the shown ones (all unless said).
        function b.dots(x,y,cols,rows,size,tint)
            local pitch,tex=15,'dot'
            if size=='small' then pitch,tex=10,'small' end
            local bg=image(x,y,cols*pitch,rows*pitch,tex..'_bg',THEME.white,true,THEME.empty)
            local lit=image(x,y,0,rows*pitch,tex,tint or THEME.teal,true)
            local now_lit,now_shown=0,cols
            return {set=function(l,shown)
                shown=shown or cols
                l=math.max(0,math.min(l,shown))
                if shown~=now_shown then
                    now_shown=shown
                    upd(bg,function() bg.slot:SetSize({X=shown*pitch,Y=rows*pitch}) end)
                end
                if l~=now_lit then
                    now_lit=l
                    upd(lit,function() lit.slot:SetSize({X=l*pitch,Y=rows*pitch}) end)
                end
            end}
        end
        -- Her HP (the player cluster's rule, online/partner/hud.lua): set(hp, max).
        function b.hp(x,y,cols,rows,size,tint)
            local d=b.dots(x,y,cols,rows,size,tint)
            return {set=function(hp,max) d.set(P.hp_columns(hp,max,cols)) end}
        end
        -- Her shield: five blocks of 11 by 2 dots, a dot apart: set(shield, max, ShieldBlock).
        function b.shield(x,y,size,tint)
            local pitch=size=='small' and 10 or 15
            local blocks={}
            for i=1,5 do blocks[i]=b.dots(x+(i-1)*12*pitch,y,11,2,size,tint) end
            return {set=function(shield,max,count)
                for i,d in ipairs(blocks) do
                    local lit=P.shield_block(i,shield,max,count,11)
                    d.set(lit or 0,lit and 11 or 0)
                end
            end}
        end
        -- A Beta or Burst row of count cubes, 41 units apart, quarters in tint; none shown before set(value, max).
        function b.cubes(x,y,count,tint)
            local cubes={}
            for i=1,count do
                local c={image(x+(i-1)*41,y,30,30,'cube0',THEME.white,false,THEME.dim)}
                for q=1,4 do c[q+1]=image(x+(i-1)*41,y,30,30,'cube'..q,tint,false,false) end
                for _,w in ipairs(c) do if w.v~=COLLAPSED then hide(w) end end
                cubes[i]=c
            end
            return {set=function(value,max)
                for i,c in ipairs(cubes) do
                    local lit=P.cube(i,value,max,count)
                    show_w(c[1],lit~=nil)
                    for q=1,4 do show_w(c[q+1],lit~=nil and q<=lit) end
                end
            end}
        end
        -- A bar: set(fraction).
        function b.bar(x,y,width,height,color)
            local w=make(n,'ProgressBar',n.tree.o)
            w.o:SetFillColorAndOpacity(color or THEME.teal)
            w.o:SetPercent(0)
            put(g,w,x,y,width,height)
            local now=0
            return {set=function(p)
                p=math.max(0,math.min(1,p))
                if p~=now then now=p; upd(w,function(x2) x2:SetPercent(p) end) end
            end}
        end
        -- A list row 76 units high: a label, a value in the last cell units of it (300 unless said); on focus the
        -- Beta-blue bar and a faint Beta tint. set(label, value, 'normal'|'focus'|'disabled'); hovered() in a hit
        -- group: the mouse is over it.
        function b.row(x,y,width,cell)
            local back,bar=image(x,y,width,ROW,nil,THEME.clear),image(x,y,6,ROW,nil,THEME.beta)
            if g.hit then back.v=VISIBLE; back.o:SetVisibility(VISIBLE) end -- The row's area takes the mouse.
            hide(bar)
            local label,value=text(x+36,y+12,'','item'),text(x+width-(cell or 300),y+12,'','item')
            local state='normal'
            return {set=function(l,v,st)
                label.set(l)
                value.set(v)
                st=st or 'normal'
                if st==state then return end
                state=st
                upd(back,function(x2) x2:SetColorAndOpacity(st=='focus' and THEME.focus or THEME.clear) end)
                show_w(bar,st=='focus')
                label.color(st=='disabled' and THEME.dim or THEME.text)
                value.color(st=='disabled' and THEME.dim or THEME.text)
            end,hovered=function()
                local on=false
                upd(back,function(x2) on=x2:IsHovered()==true end)
                return on
            end}
        end
        -- The chat's text box (one a group; input(true, its group) gives it the keys): Slate turns keys into
        -- characters, so any layout, accents and dead keys work. It keeps its keyboard focus on Enter and reverts on
        -- Esc, Mideum 34 white on the dark glass, all set before AddToViewport; a style the engine refuses leaves
        -- Slate's own box (dark text on white), a refused flag or hint only that. It takes the mouse: a click focuses
        -- it. text(), set(s), focus(), hint(s).
        function b.field(x,y,width,height,hint)
            local w=make(n,'EditableTextBox',n.tree.o)
            if not pcall(function() w.o.ClearKeyboardFocusOnCommit=false; w.o.RevertTextOnEscape=true end) then
                n.look['text box behaviour refused']=true
            end
            local f=get('Mideum') or get('Roboto')
            local function color(slate,c)
                slate.ColorUseRule=0
                local v=value_of(slate.SpecifiedColor)
                v.R,v.G,v.B,v.A=c.R,c.G,c.B,c.A
            end
            local style=nil
            if not pcall(function()
                style=value_of(w.o.WidgetStyle)
                if f then local font=value_of(style.Font); font.FontObject=f; font.Size=34 end
                color(value_of(style.BackgroundColor),THEME.panel)
                color(value_of(style.ForegroundColor),THEME.text)
            end) then
                n.look['text box style refused (default box)']=true
                if style then pcall(color,value_of(style.BackgroundColor),THEME.white) end -- Never white on white.
            end
            local function set_hint(x2,s)
                if not pcall(function() x2:SetHintText(FText(s)) end) then n.look['text box hint refused']=true end
            end
            set_hint(w.o,hint or '')
            w.v,w.on=VISIBLE,VISIBLE
            w.o:SetVisibility(VISIBLE)
            put(g,w,x,y,width,height)
            g.field=w
            return {text=function()
                    local s=''
                    upd(w,function(x2) s=U.text(x2:GetText()) end)
                    return s
                end,
                set=function(s) upd(w,function(x2) x2:SetText(FText(s)) end) end,
                focus=function() upd(w,function(x2) x2:SetKeyboardFocus() end) end,
                hint=function(s) upd(w,function(x2) set_hint(x2,s) end) end}
        end
        -- Key hints cell units apart, {{key, label}, ...}; keys: move (WASD, ZQSD with azerty), arrows, up, enter,
        -- space, escape. A missing icon leaves its label. Returns the labels (text's views: the language may change),
        -- and in labels.icons each icon's view with show(on) (hidden under one of SB's own hint parts).
        function b.hints(x,y,cell,list)
            local labels={icons={}}
            for i,hint in ipairs(list) do
                local key=(hint[1]=='move' and n.azerty) and 'move_azerty' or hint[1]
                local icon=image(x+(i-1)*cell,y,KEY_ICON,KEY_ICON,'key_'..key,THEME.white,false,false)
                labels.icons[i]={show=function(on) show_w(icon,on) end}
                labels[i]=text(x+(i-1)*cell+KEY_ICON+12,y+KEY_TEXT,hint[2],'hint')
            end
            return labels
        end
        return b
    end
    -- The build, all in this one game-thread call; nothing when there is no player controller yet. An asset a map
    -- change freed is looked up again by warm (a build using it is partial meanwhile).
    local function build()
        local pc=controller()
        if not pc then return end
        local assets={}
        for name,e in pairs(cache) do
            local x=e and valid(e.o)
            if x and U.text(x:GetFullName())==e.full then assets[name]=x elseif e then cache[name]=nil end
        end
        local started=os.clock()
        local n={classes={},assets=assets,count=0,look={},groups={},views={},size=#order,azerty=self.azerty()}
        for _,name in ipairs(UMG) do n.classes[name]=U.find('/Script/UMG.'..name) end
        pending=n
        n.root=make(n,'UserWidget',pc)
        n.tree=make(n,'WidgetTree',n.root.o)
        local canvas=make(n,'CanvasPanel',n.tree.o)
        n.canvas=canvas
        n.root.o.WidgetTree=n.tree.o
        n.tree.o.RootWidget=canvas.o
        local hit=false
        for _,def in ipairs(order) do
            local p=def.place
            local g=put(canvas,make(n,'CanvasPanel',n.tree.o),p.x,p.y,p.w,p.h)
            g.x,g.y,g.hit,g.on=p.x,p.y,p.hit,p.hit and SELF_HIT or HIT_TEST_INVISIBLE
            hit=hit or p.hit
            g.o:SetRenderTransformPivot(p.pivot or {X=0,Y=0})
            local s=scale_of(p)
            if s~=1 then g.o:SetRenderScale({X=s,Y=s}) end
            g.v=def.shown and g.on or COLLAPSED
            g.o:SetVisibility(g.v)
            if def.alpha then g.o:SetRenderOpacity(def.alpha) end
            n.groups[def.name]=g
            n.views[def.name]=def.build(builder(n,g)) or {}
        end
        n.root.o:SetOwningPlayer(pc)
        n.root.on=hit and SELF_HIT or HIT_TEST_INVISIBLE -- Mouse hits pass through, but a hit group's.
        n.root.v=veiled and COLLAPSED or n.root.on
        n.root.o:SetVisibility(n.root.v)
        -- Focusable, so the input mode focuses our root and the focus watchdog can read it.
        local why
        n.focusable,why=pcall(function() n.root.o.bIsFocusable=true end)
        if not (n.focusable or unfocusable_said) then
            unfocusable_said=true
            log('focus watchdog off: the UI root refused bIsFocusable ('..tostring(why)..')')
        end
        n.root.o:AddToViewport(Z)
        need(n.root.o:IsInViewport(),'the UI root is not in the viewport')
        pending,built=nil,n
        keep()
        if n.partial then return log(string.format('UI built while its look warms: %d widgets in %.1f ms',n.count,
            ms(started))) end
        local look={}
        for note in pairs(n.look) do look[#look+1]=note end
        table.sort(look)
        log(string.format('UI built: %d widgets in %.1f ms%s',n.count,ms(started),
            #look>0 and '; look: '..table.concat(look,', ') or ''))
    end
    -- One class not looked up yet looked up: true when one was.
    local function classes()
        for _,class in ipairs(CLASSES) do
            if not found[class] then U.find(class); found[class]=true; return true end
        end
        return false
    end
    -- A texture the partial root wanted (its look note), warmed while that root is up: held by a collapsed image of it
    -- until the build that uses it. Nothing else may hold what LoadAsset brought in, and SB's GC would free it before
    -- then (that build partial again, the texture loaded again). A refusal ends the holding for this Lua load, said
    -- once.
    local holding=true
    local function hold(name,x)
        local n=built
        local canvas=holding and n and n.partial and n.look[name..' missing'] and alive(n.canvas)
        if not canvas then return end
        local ok,why=pcall(function()
            local w=make(n,'Image',n.tree.o)
            hide(w)
            w.o:SetBrushFromTexture(x,true)
            need(valid(canvas:AddChildToCanvas(w.o)),'no canvas slot')
        end)
        if not ok then
            holding=false
            log('warmed textures not held from now on: '..tostring(why))
        end
    end
    -- One class or asset not tried yet looked up (look: all but the sounds and parts): true when one was. Then the
    -- parts' (warm_part), one LoadAsset each.
    local function warm(look)
        if classes() then return true end
        for _,a in ipairs(Ui.ASSETS) do
            if cache[a[1]]==nil and not (look and a.volume) then
                local x=load(a[2]) or a.alt and load(a.alt)
                cache[a[1]]=x and {o=x,full=U.text(x:GetFullName())} or false
                if x then hold(a[1],x) end
                return true
            end
        end
        if look then return false end
        -- The keep holds each part's class for the game run (warm_part wants it), so part() finds it after a map
        -- change; without the keep, part() loads it then.
        for _,p in ipairs(parts) do
            if not (warmed[p] or Keep.wanted(p..'_C')) then warmed[p]=true; load(p); return true end
        end
        return false
    end
    -- warm once; while veiled, again until VEIL_BUDGET is spent: true when one lookup ran, or while the keep has not
    -- settled (no lookup: the partial root waits for it).
    local function warming(look)
        if not Keep.ready() then return true end
        local started,any=os.clock(),false
        while warm(look) do
            any=true
            if not veiled or os.clock()-started>=Ui.VEIL_BUDGET then break end
        end
        return any
    end
    -- The root an earlier Lua load left (Ctrl+R): true when its path was looked up. That load's menu or guide open, the
    -- game's input is given back first and the mouse cursor put back as that load found it (or once there is a player
    -- controller: input(false) tries again).
    local function sweep()
        local left=store.load()
        store.clear()
        if not left then return false end
        if left:find(' cursor',1,true) then cursor=left:find(' cursor shown',1,true)~=nil end
        if left:find(' input',1,true) then inputting=true; input_mode(false) end
        local x=valid(StaticFindObject(left:match('^%S+')))
        if x and U.text(x:GetFullName()):find('^UserWidget ') and x:IsInViewport() then
            x:RemoveFromParent()
            log('removed the UI an earlier Lua load left on screen')
        end
        return true
    end
    local function step(world)
        if not swept then
            swept=true
            if sweep() then return end
        end
        hidden=not world
        if hidden then
            lost=0
            if built and built.root.v~=COLLAPSED then
                built.root.v=COLLAPSED
                local r=alive(built.root)
                if r then r:SetVisibility(COLLAPSED) end
            end
            return
        end
        if built then
            local r=alive(built.root)
            local kept=r and r:IsInViewport()
            if kept and built.size==#order then
                lost=0
                local v=veiled and COLLAPSED or built.root.on
                if built.root.v~=v then built.root.v=v; r:SetVisibility(v) end
                if warming(built.partial) or not built.partial then return end
                for _,def in ipairs(order) do if def.shown and def.place.hit then return end end -- Not under the mouse.
                if inputting then return end -- Nor the root the input focused (its holder may show no hit group).
            elseif built.size==#order then
                lost=lost+1 -- A map change took it out, or the game, or another mod.
                need(lost<=LOSSES,'the UI root keeps leaving the viewport')
            end
            if r then r:RemoveFromParent() end -- Out of the viewport, a group came, or the look is in.
            built,tweens=nil,{}
        end
        if not classes() then build() end
    end
    -- The watchdog's focus line, as it fires: the class of each top-level UserWidget but our root that holds the focus
    -- or a widget with it, whether the game is paused or shows its cursor, and the seconds since the last mouse button.
    local function focus_line(now)
        local pc=need(controller(),'no player controller')
        local out,held={},{}
        U.find(WIDGETS):GetAllWidgetsOfClass(pc,out,U.find('/Script/UMG.UserWidget'),true)
        U.each(out,function(_,w)
            w=valid(w)
            local name=w and U.text(w:GetFullName())
            if name and name~=built.root.name and (w:HasAnyUserFocus() or w:HasFocusedDescendants()) then
                held[#held+1]=name:match('^%S+')
            end
        end)
        log(string.format('focus watchdog: focus on %s; game paused or its cursor shown: %s; %s',
            #held>0 and table.concat(held,', ') or 'none (the game viewport, a Slate-only widget or another window '
            ..'has it)',tostring(self.paused(true)),clicked_at and string.format('last mouse button %.1f s before',
            now-clicked_at) or 'no mouse button since the Lua load'))
    end
    -- The focus watchdog, each 250 ms while our UI holds the game's input and shows: whether our root or a widget in it
    -- has the focus. Armed by a first yes since the input was taken; armed, 1 s of no fires it (lost()), once a take; a
    -- mouse button starts that second over (click). Never armed 2 s after the take: said once a Lua load, nothing
    -- fires. A read that raises counts for nothing. The Steam overlay keeps Slate's focus, so it never fires it; the
    -- game or another mod moving the focus does.
    local function guard()
        local r=watch and not hidden and built and built.focusable and alive(built.root)
        if not r then return end
        local read,yes=pcall(function() return r:HasAnyUserFocus() or r:HasFocusedDescendants() end)
        if not read then return end
        local now=os.clock()
        if yes then watch.armed,watch.since=true,nil
        elseif watch.armed then
            watch.since=watch.since or now
            if now-watch.since>=1 then
                fired,watch=holder or 'menu',nil
                -- Its own pcall: an error here in run() would turn the UI off.
                local ok,why=pcall(focus_line,now)
                if not ok then log('focus watchdog: focus not read ('..tostring(why)..')') end
            end
        elseif now-watch.at>=2 and not never_said then
            never_said=true
            log('focus watchdog: our root never took the focus')
        end
    end
    -- Each 250 ms with whether our HUD may show (a world with EVE, not paused, the game's HUD up, no photo mode, or
    -- the title screen) and whether the title screen shows. Returns false and why once, when the kit turned off.
    function self.slow(world,title)
        device()
        titled=title==true
        if not off and order[1] then run(step,world) end
        if not off and watch then run(guard) end
        return said_once()
    end
    -- Once the focus watchdog fired: true and who held the game's input ('menu', or a group's name), once; else
    -- false.
    function self.lost()
        local who=fired
        fired=nil
        return who~=nil,who
    end
    -- Whether our UI holds the game's input (main.lua's mouse binds read it on UE4SS's key thread).
    function self.holding() return inputting end
    -- A mouse button pressed (main.lua's binds, on the game thread): while our UI holds the game's input, our focus
    -- goes back where the input put it (the root, or the holder's box) REFOCUS later, and the focus watchdog's second
    -- starts over. Slate gives a click that no widget of ours takes (off the menu's rows or the chat's box, any click
    -- under the host's question) to the game's viewport.
    -- ponytail: the left and right buttons only; the middle and side ones move the focus too (the watchdog then closes
    -- our UI): bind them in main.lua if a tester trips it.
    function self.click()
        clicked_at=os.clock()
        refocus_at=clicked_at+REFOCUS
        if watch then watch.since=nil end
    end
    -- Our focus back now where the input put it (the root, or the holder's box), while the input is ours and the world
    -- shows: a click's, and a popup part's that took it in its Construct and left (the focus watchdog would fire).
    function self.refocus()
        if inputting and not hidden and built then
            local g=holder and built.groups[holder]
            upd(g and g.field or built.root,function(x) x:SetKeyboardFocus() end)
        end
    end
    -- Each frame: our focus back once due, while the input is still ours and the world shows; the open and close
    -- tweens, only while one runs.
    function self.tick(now)
        if refocus_at and now>=refocus_at then
            refocus_at=nil
            self.refocus()
        end
        if not off and next(tweens) then
            run(function()
                for name,t in pairs(tweens) do
                    local x=alive(built and built.groups[name])
                    if not x then tweens[name]=nil else
                        local p=math.min(1,(now-t.at)/(t.open and OPEN or CLOSE))
                        local a,dx=1-p,-SLIDE*p*p
                        if t.open then
                            a,dx=math.min(1,p/0.6),-SLIDE*(1-p)^2
                            if p<1 and p>=0.7 and t.flick<2 then a,t.flick=0.6,t.flick+1 end -- A signal flicker.
                        end
                        x:SetRenderOpacity(a)
                        x:SetRenderTranslation({X=dx,Y=0})
                        if p>=1 then
                            tweens[name]=nil
                            if not t.open then built.groups[name].v=COLLAPSED; x:SetVisibility(COLLAPSED) end
                        end
                    end
                end
            end)
        end
        return said_once()
    end
    -- A group: place {x, y, w, h in layout units, pivot (of the scale, top left unless said), shown, hit (its rows take
    -- the mouse: the menu), inside (move keeps it on screen: the partner HUD's), most (its largest scale: ui_scale
    -- past it draws it at that; the status strip above the partner card)}; build(b) makes its widgets with the
    -- builders above at each root build and returns its view. Added before the first slow, or the root is built again.
    function self.add(name,place,build_view)
        local def={name=name,place=place,shown=place.shown==true,build=build_view}
        order[#order+1]=def
        by[name]=def
    end
    -- A group's view while the root is up, shown and ours; nil otherwise: hidden, before the first build or between a
    -- map change and the next slow (callers skip or queue), or off.
    function self.view(name) return not off and not hidden and built and built.views[name] or nil end
    function self.ready() return not off and not hidden and built~=nil end
    -- Up with its whole look: no asset it uses still warming (one missing from this build counts as in).
    function self.whole() return self.ready() and not built.partial end
    -- Turned off for this Lua load: only then do the callers go back to the notice line above EVE and the name tag.
    function self.off() return off end
    -- The root collapsed (on) or shown again, at once when it is up in a world shown, and so at each build and slow
    -- until veil(false); the build and the warm-up go on, faster (VEIL_BUDGET). online/lobby/arrival.lua's hold: our
    -- root (z-order 100) would draw over SB's black (10).
    function self.veil(on)
        veiled=on==true
        local v=built and (veiled and COLLAPSED or built.root.on)
        if hidden or not v or built.root.v==v then return end
        run(function()
            local r=alive(built.root)
            if r then built.root.v=v; r:SetVisibility(v) end
        end)
    end
    -- Shown or hidden; with now (the 1 ms loop's clock), the open tween (160 ms: a slide from the left with a
    -- flicker) or the close one (120 ms).
    function self.show(name,on,now)
        local def=by[name]
        on=on==true
        if not def or def.shown==on then return end
        def.shown=on
        local g=built and built.groups[name]
        if not g or off then return end
        tweens[name]=now and {at=now,open=on,flick=0} or nil
        if not on and now then return end
        g.v=on and g.on or COLLAPSED
        upd(g,function(x)
            x:SetVisibility(g.v)
            if on then
                x:SetRenderOpacity(now and 0 or def.alpha or 1)
                x:SetRenderTranslation({X=now and -SLIDE or 0,Y=0})
            end
        end)
    end
    -- The viewport in layout units ({w, h, s=its DPI scale}): its pixels over its DPI scale, read at most once a second
    -- (logged when its size changes); nil with no player controller or scale (a map loads). In a run: a raise turns
    -- the kit off.
    local function viewport(now)
        if screen and now<screen.at+1 then return screen end
        local pc=controller()
        if not pc then return nil end
        local lib,was=U.find(LAYOUT),screen
        local px,s=value_of(lib:GetViewportSize(pc)),tonumber(lib:GetViewportScale(pc))
        screen=s and s>0 and px.X>0 and px.Y>0 and {w=px.X/s,h=px.Y/s,s=s,at=now} or nil
        if screen and not (was and was.w==screen.w and was.h==screen.h) then
            log(string.format('UI viewport: %.0fx%.0f units (%.0fx%.0f pixels at DPI scale %.3g)',screen.w,screen.h,
                px.X,px.Y,s))
        end
        return screen
    end
    -- Where an inside group goes for x, y: its box, scaled around its pivot, SAFE units inside the viewport, its left
    -- and top edges winning when it does not fit; x, y while the viewport is unread.
    local function inside(p,x,y)
        local v=viewport(os.clock())
        if not v then return x,y end
        local pivot,s=p.pivot or {X=0,Y=0},scale_of(p)
        local left,top=x+pivot.X*p.w*(1-s),y+pivot.Y*p.h*(1-s)
        local function fit(at,size,room) return math.max(SAFE,math.min(at,room-SAFE-size*s)) end
        return x+fit(left,p.w,v.w)-left,y+fit(top,p.h,v.h)-top
    end
    -- The viewport in layout units ({w, h, s=its DPI scale}, read at most once a second) while the root is up; nil
    -- otherwise. The emote wheel centres itself on it.
    function self.screen()
        if off or hidden or not built then return nil end
        local v=nil
        run(function() v=viewport(os.clock()) end)
        return not off and v or nil
    end
    -- The mouse in the viewport's layout units (WidgetLayoutLibrary's GetMousePositionOnViewport: the cursor's place
    -- even while hidden, outside the window too), x and y; nil while the root is not up. A refused call only degrades:
    -- nil from then on, said once, the kit stays on.
    local mouse_said=false
    local function mouse_refused(what,why)
        if not mouse_said then mouse_said=true; log('emote wheel: '..what..' refused: '..tostring(why)) end
    end
    function self.pointer()
        if off or hidden or not built then return nil end
        local ok,p=pcall(function()
            return value_of(U.find(LAYOUT):GetMousePositionOnViewport(need(controller(),'no player controller')))
        end)
        if ok and p and tonumber(p.X) and tonumber(p.Y) then return p.X,p.Y end
        mouse_refused('the mouse read',ok and 'no position' or p)
    end
    -- The mouse put at the viewport's centre (PlayerController's SetMouseLocation, in pixels): true once done. A
    -- refused call only degrades, said once.
    function self.centre_pointer()
        local v=self.screen()
        if not v then return false end
        local ok,why=pcall(function()
            need(controller(),'no player controller'):SetMouseLocation(math.floor(v.w*v.s/2),math.floor(v.h*v.s/2))
        end)
        if not ok then mouse_refused('the mouse move',why) end
        return ok
    end
    -- A group's place (the marker follows her), kept on screen for an inside one: on change only.
    function self.move(name,x,y)
        local g=built and built.groups[name]
        if not g then return end
        if by[name].place.inside then run(function() x,y=inside(by[name].place,x,y) end) end
        if off or (g.x==x and g.y==y) then return end
        g.x,g.y=x,y
        upd(g,function() g.slot:SetPosition({X=x,Y=y}) end)
    end
    -- A group's opacity (the partner card greyed), on change only, kept across builds; not for a group that tweens.
    function self.fade(name,a)
        local def=by[name]
        if not def or def.alpha==a then return end
        def.alpha=a
        local g=built and built.groups[name]
        if g then upd(g,function(x) x:SetRenderOpacity(a) end) end
    end
    -- A world point (her marker's anchor) as partner.place wants it: {camera, rotation, anchor=at, width, height, and
    -- screen={x, y} (the engine's projection) or fov (the camera's, for partner.place's own)}, in layout units: the
    -- viewport's pixels over its DPI scale, both read once a second. nil while the root is not up, or with no camera
    -- or scale (a map loads). The engine's projection gives no point behind the camera (or none in an out-table
    -- UE4SS left empty): the field of view then; once it raises, the field of view from then on, said once.
    function self.project(at,now)
        if off or hidden or not built then return nil end
        local v=nil
        run(function()
            local pc=controller()
            local camera=pc and valid(pc.PlayerCameraManager)
            if not (camera and viewport(now)) then return end
            local c,r=value_of(camera:GetCameraLocation()),value_of(camera:GetCameraRotation())
            v={camera={X=c.X,Y=c.Y,Z=c.Z},rotation={Pitch=r.Pitch,Yaw=r.Yaw},anchor=at,width=screen.w,
                height=screen.h}
            if projecting then
                local out={}
                local ok,on=pcall(function() return pc:ProjectWorldLocationToScreen(at,out,false) end)
                if not ok then
                    projecting=false
                    log('UI marker: the engine projection raised ('..tostring(on)..'); the field of view places it')
                elseif on and tonumber(out.X) and tonumber(out.Y) then
                    v.screen={x=out.X/screen.s,y=out.Y/screen.s}
                end
            end
            if not v.screen then v.fov=camera:GetFOVAngle() end
        end)
        return not off and v or nil -- Never half a view: a raise turned the kit off.
    end
    -- ui_scale, applied at once to every group, from its pivot, up to its most; on change only.
    function self.scale(pct)
        local s,was=clamp(pct),scale
        if s==scale then return end
        scale=s
        for name,g in pairs(built and built.groups or {}) do
            local t=scale_of(by[name].place,s)
            if t~=scale_of(by[name].place,was) then upd(g,function(x) x:SetRenderScale({X=t,Y=t}) end) end
        end
    end
    function self.sounds(on) sounding=on end -- ui_sounds.
    -- One of the game's UI sounds (Ui.ASSETS' with a volume), as a UI sound of our root's world. This engine's
    -- PlaySound2D takes all its 8 parameters: world, sound, volume, pitch, start time, concurrency, owner, UI sound.
    function self.sound(name)
        if off or quiet or not sounding or not built then return end
        local e=VOLUME[name] and cache[name]
        if not e then return end -- Not a sound, not warmed yet, or not in this build.
        local ok,why=pcall(function()
            local root,s=alive(built.root),valid(e.o)
            if not (s and U.text(s:GetFullName())==e.full) then cache[name]=nil; return end -- Freed: a later slow finds it.
            if root then U.find(STATICS):PlaySound2D(root,s,VOLUME[name],1,0,nil,nil,true) end
        end)
        if not ok then
            quiet=true
            log('UI sounds off until the mod reloads: '..tostring(why))
        end
    end
    -- The game's input for who: nil, the menu's (on our root), or a group's name, its field's (the chat box, with its
    -- keyboard focus); mouse: the mouse cursor shown, as for the menu. On (only while the root is up) or off; each
    -- once. Only who holds it gives it back: the menu's late give-back (150 ms after its close) never takes the chat's
    -- that opened meanwhile, nor the reverse. Off while still due is tried again at each call, the kit off too: the
    -- game never stays deaf.
    function self.input(on,who,mouse)
        if on==true then
            if off or not self.ready() or (inputting and holder==who) then return end
            holder,pointing=who,mouse==true
            local g=who and built.groups[who]
            run(input_mode,true,g and g.field)
        elseif inputting and holder==who then
            if off then pcall(input_mode,false) else run(input_mode,false) end
        end
    end
    -- Whether the game is paused (its own menu, a cutscene) or shows the mouse cursor (one of its screens that does
    -- not pause: a shop, a dialogue choice; never the cursor our menu shows): the menu does not open then. false when
    -- unread. Off, false too, unless always (Night Operation's run reads no body under a game screen, kit or not).
    function self.paused(always)
        if off and not always then return false end
        local ok,paused=pcall(function()
            local pc=controller()
            return pc and (U.find(STATICS):IsGamePaused(pc) or cursor==nil and pc.bShowMouseCursor)
        end)
        return ok and paused==true
    end
    -- The game's text culture ('fr-FR'...; ui/text.lua picks the words), or nil when unread. Once off, the last one
    -- read with no engine call: the notices that fall back to the line above EVE keep the game's language.
    local culture_seen
    function self.language()
        if off then return culture_seen end
        local ok,culture=pcall(function() return U.text(U.find(LANGUAGE):GetCurrentLanguage()) end)
        if ok and culture then culture_seen=culture end
        return ok and culture or nil
    end
    -- AZERTY or not (the move keys' icon, the settings screen's tab keys): azerty= when given, else SB's last keyboard
    -- answer, else the game's language (French players type on AZERTY keyboards).
    function self.azerty()
        if opts.azerty~=nil then return opts.azerty end
        device()
        if keyboard~=nil then return keyboard end
        return (self.language() or ''):lower():find('^fr')~=nil
    end
    -- An SB widget part (L4 2) from its class path ('/Game/.../WB_X.WB_X_C', loaded now when warm_part has not):
    -- made with WidgetBlueprintLibrary:Create, HitTestInvisible unless hit, fill(widget) before it enters the group's
    -- canvas at x, y (width by height in layout units). Returns its record {o=, name=}, or nil and why; a failure leaves
    -- the kit on (the screen draws its own instead).
    function self.part(group,class_path,x,y,width,height,fill,hit)
        local short=class_path:match('[^.]+$')
        local g=self.ready() and alive(built.groups[group])
        local pc=g and controller()
        if not pc then return nil,'part '..short..': the UI is not up' end
        local class=load(class_path,class_path:sub(1,-3))
        if not class then return nil,'part '..short..': not in this game build' end
        local made,w=pcall(function() return valid(U.find(WIDGETS):Create(pc,class,pc)) end)
        if not (made and w) then return nil,'part '..short..': Create failed: '..tostring(w or 'no widget') end
        local rec={o=w,name=U.text(w:GetFullName()),build=built,v=false} -- v false: put() leaves its visibility.
        local ok,why=pcall(function()
            if not hit then rec.v=HIT_TEST_INVISIBLE; w:SetVisibility(rec.v) end
            if fill then fill(w) end
            put(built.groups[group],rec,x,y,width,height)
        end)
        if ok then return rec end
        pcall(function() w:RemoveFromParent() end)
        return nil,'part '..short..': '..tostring(why)
    end
    -- A part's widget while it is still ours and in the root that made it; nil once that root went (a rebuild).
    function self.alive(rec) return rec and built and rec.build==built and alive(rec) or nil end
    -- A part out of its group now, once.
    function self.drop(rec)
        local x=self.alive(rec)
        if not x then return end
        rec.build=nil
        run(function() x:RemoveFromParent() end)
    end
    -- A part's class (its object path) wanted by the keep; without the keep, loaded ahead, one LoadAsset a slow tick
    -- after the look and its sounds.
    function self.warm_part(object_path)
        Keep.want({object_path..'_C'})
        for _,p in ipairs(parts) do if p==object_path then return end end
        parts[#parts+1]=object_path
    end
    -- coop ui reset, the escape hatch (UI-DESIGN 7.5): the game's input given back now whoever holds it, even when this
    -- load thinks the game has it, and the menu's mouse cursor put back (a later input(false) tries again while there
    -- is no player controller).
    function self.reset()
        inputting,holder=true,nil
        if off then pcall(input_mode,false) else run(input_mode,false) end
    end
    -- coop off and coop ui off: the root goes now (the game's input back first); no engine call after.
    function self.stop()
        if off then return end
        close_all()
    end
    return self
end
return Ui
