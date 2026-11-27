-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Copied from fight/gunmode/ui/dpad.lua (November 2026), cut to the closet's entry.
-- Stellar Closet's entry in the HUD's item column, right of gun mode's entry: the buttons that open the closet, then
-- the closet's hanger glyph (icons/full_outfit.png, Slots.glyph(Slots.FULL_OUTFIT)), imported at run time with
-- ImportFileAsTexture2D as closet/ui/view.lua imports its glyphs. The buttons follow the game's own D-pad marker: on a
-- gamepad the LB glyph, then the D-pad Left glyph, of the pad the game shows (the LeftShoulder and DPad_Left twins of
-- its DPad_Up glyph), for the LB + D-pad Left chord that opens the closet (ui/pad.h). D-pad Left alone stays the
-- game's: its DefaultInput.ini on 26123051 maps Gamepad_DPad_Left to the action CrossKey_Left, which the player's input
-- setup FUN_1420473b0 binds pressed (0x1420477d0) and released (0x142047bc8) with ESBKeyEvent_CrossKey_Left (4). On the
-- keyboard the closet key's icon on the game's own key cell (btn_PcEmpty), the way the marker shows Q and R. Sizes
-- come from the game's own widgets (the key icon from btn_up, the hanger from the heal item's icon), so the entry
-- scales with the HUD. It is the HUD's own child (Overlay_ItemSlot), so it shows and hides with the HUD. Its parts are
-- found by name in the HUD's widget trees (Hud.PARTS, ed6385e6), so the look for the HUD on screen is the only walk of
-- the object array, made again only when no HUD was usable, every Hud.RETRY s. While the keep holds SB's HUD class, a
-- hook on its Construct names each new HUD: the entry is built at the first tick that HUD is on screen, with no walk
-- (d2de021b). An earlier Lua load's widgets in that HUD (Ctrl+R) are taken again, never made over. Every widget kept is
-- checked by its path before it is used, as a map change frees them and another object can then sit at a freed address
-- and pass IsValid (ed6385e6).
local Keep=require('core.keep')
local U=require('core.unreal')
local Hud={}

Hud.GAP=6         -- HUD units between the D-pad marker and gun mode's entry. The same gap separates its parts
Hud.KEY_SIZE=30   -- the key or pad glyph, until the game's btn_up has a drawn size
Hud.ICON_SIZE=34  -- the hanger icon, until the heal item's icon has a drawn size
-- Between gun mode's entry and ours: the distance from the marker's right edge to the gun key. A starting value to
-- tune in game.
Hud.SPACE=Hud.GAP
-- Room right of the rifle icon for gun mode's "rounds | magazines" text, so it never runs under our entry. A starting
-- value to tune in game.
Hud.TEXT_ROOM=60
-- Below the health bars, on gun mode's row: the entry's centre this many marker heights below the marker's centre.
Hud.DOWN=1.5
-- s between two looks for the HUD while none on screen could take the entry: each look walks the object array once
-- (FindAllOf of WB_MainHUD_Master_C). A HUD whose item column could not be used is not tried again: only a new HUD is.
-- After a build the next look waits Hud.AGAIN s: a new HUD (a map change) gets the entry within that time.
Hud.RETRY,Hud.AGAIN=10,2
-- SB's HUD class (base paks of 26123051: /Game/Art/UI/Widget/HUD/WB_MainHUD_Master holds WB_MainHUD_Master_C, an
-- SBUserWidget whose own Construct overrides UserWidget's). Kept for the game run, so its hooked Construct stays.
Hud.HUD='/Game/Art/UI/Widget/HUD/WB_MainHUD_Master.WB_MainHUD_Master_C'
Hud.FRESH=30 -- s a HUD named by its Construct is checked for the screen before the looks alone go on
-- The game's widgets the entry uses, by their names in SB's HUD (the paks of 26123051): in WB_MainHUD_Master's widget
-- tree the D-pad marker (marker, a WB_MainHUD_Dpad) and the heal item (heal, a WB_MainHUD_ItemSlot); in the marker's
-- tree its root overlay (overlay), its up button (up), its gamepad layer (pad) and that layer's key cell (cell, an
-- image of btn_PcEmpty).
Hud.PARTS={marker='WB_MainHUD_Dpad',heal='WB_MainHUD_HealItem',overlay='Overlay_0',up='btn_up',pad='Overlay_ps',
    cell='btn'}
-- The hanger glyph: closet/ui/icons/<Slots.glyph(Slots.FULL_OUTFIT)>.png, next to this file's folder.
Hud.ICON='full_outfit'
local HERE=(package.searchpath('closet.ui.hud',package.path) or ''):match('^(.*[\\/])[^\\/]+$') or ''
Hud.ICON_FILE=HERE..'icons'..HERE:sub(-1)..Hud.ICON..'.png'
-- Copied from closet/ui/view.lua (November 2026):
-- KismetRenderingLibrary's ImportFileAsTexture2D(WorldContextObject, Filename): native entry 0x1465a3180 (its name at
-- 0x14659e5c0), exec 0x1447fc790, impl FUN_144267a10: an 8-bit PNG through the ImageWrapper module (FUN_1442680a0)
-- into a new texture of FUN_1445ff7a0 (Name None, flags 0x40 RF_Transient), so its object path is read at run time
-- with GetFullName (Ghidra, build 26123051, 26 Nov 2026).
local RENDER='/Script/Engine.Default__KismetRenderingLibrary'

-- The glyph textures for our entry from the one the game shows on its D-pad marker's up button: a pad's DPad_Up gives
-- its DPad_Left, then its LeftShoulder (LB) second; a keyboard key icon gives the closet key's (KeyIcon_KeyBoard_<key>)
-- alone. nil: no change known, or no closet key on the keyboard. In pakchunk0 of 26123051 (listed with retoc on 27 Nov
-- 2026) every folder of /Game/Art/UI/Texture/Interaction/ that holds a KeyIcon_<pad>_Gamepad_DPad_Up holds its
-- _DPad_Left and _LeftShoulder too, for the pads XboxOne (XBOX), DualShock4 (DualShock) and DualSense (DualSense):
-- /Game/Art/UI/Texture/Interaction/XBOX/KeyIcon_XboxOne_Gamepad_DPad_Left.KeyIcon_XboxOne_Gamepad_DPad_Left and
-- /Game/Art/UI/Texture/Interaction/XBOX/KeyIcon_XboxOne_Gamepad_LeftShoulder.KeyIcon_XboxOne_Gamepad_LeftShoulder.
function Hud.glyph_path(up_path,key)
    if type(up_path)~='string' then return nil end
    if up_path:find('DPad_Up',1,true) then
        return (up_path:gsub('DPad_Up','DPad_Left')),(up_path:gsub('DPad_Up','LeftShoulder'))
    end
    local dir=up_path:match('^(.*/)KeyIcon_KeyBoard_[%w_]+%.KeyIcon_KeyBoard_[%w_]+$')
    if dir and key then return dir..'KeyIcon_KeyBoard_'..key..'.KeyIcon_KeyBoard_'..key end
    return nil
end

-- Copied from fight/gunmode/mode.lua's g (November 2026), cut to what the entry uses. env: {log, hook_hud (path,
-- callback: a hook on the Construct of the widget class at path, registered by closet/wiring.lua; nil: the looks
-- alone)}.
function Hud.helpers(env)
    local g={}
    function g.log(m) env.log(m) end
    g.hook_hud=env.hook_hud
    local function is_valid(o) return o:IsValid() end
    local function get_field(o,k) return o[k] end
    function g.valid(o)
        if o==nil then return false end
        local ok,r=pcall(is_valid,o)
        return ok and r==true
    end
    function g.try(fn) local ok,r=pcall(fn); if ok then return r end end
    -- a property read without a closure
    function g.get(o,k) local ok,r=pcall(get_field,o,k); if ok then return r end end
    -- An object's path (its full name without its class), as core/actors.lua's path_of: StaticFindObject finds it by
    -- that path while it lives. nil when it cannot be read.
    function g.path(o)
        local f=g.valid(o) and g.try(function() return o:GetFullName() end)
        return type(f)=='string' and f:match('^%S+ (.+)$') or nil
    end
    -- An asset (/Game, /Engine) while it is in memory, else nil, with no walk of the object array: the keep's
    -- (core/keep.lua: loaded off the frame and held for the game run), else the engine's name hash through the soft
    -- path (core/unreal.lua's object_at). Before the soft path is proven (no pawn yet), or where it fails,
    -- StaticFindObject.
    function g.loaded(path)
        local ok_k,o=false,nil
        if Keep.serves(path) then ok_k,o=pcall(Keep.get,path) end -- (a raise here must not stop the tick: b34ce23e)
        if ok_k and g.valid(o) then return o end
        local ok,x,known=pcall(U.object_at,path,g.pc())
        if not (ok and known~=nil) then x=StaticFindObject(path) end
        if g.valid(x) then return x end
    end
    -- An asset by its path, loaded when missing (b812f708). The reference is kept and checked against its path at each
    -- use: nothing of the game may hold the asset, so the engine can collect it. Another object can then sit at the
    -- freed address and pass IsValid. nil when it cannot be found or loaded. A miss is not looked for again for 5 s.
    local assets,asset_missed={},{}
    function g.asset(path)
        local o=assets[path]
        if o and g.path(o)==path then return o end
        if (asset_missed[path] or -1)>os.clock() then return nil end
        o=g.loaded(path)
        if not g.valid(o) then o=g.try(function() return LoadAsset(path) end) end
        if g.valid(o) then assets[path]=o; return o end
        assets[path]=nil; asset_missed[path]=os.clock()+5.0
    end
    -- The controller: FindFirstOf walks the whole object array, so once a second at most while there is none
    -- (468f7ab6).
    local cached,pc_wait
    local cdos={}
    -- a class default object ('/Script/...Default__X') found once: they live as long as the game
    function g.cdo(path) local o=cdos[path]; if not o then o=StaticFindObject(path); cdos[path]=o end; return o end
    function g.pc()
        if g.valid(cached) then return cached end
        if (pc_wait or -1)>os.clock() then return nil end
        local pc=FindFirstOf('SBPlayerController')
        if g.valid(pc) then cached=pc; return pc end
        pc_wait=os.clock()+1.0
    end
    -- A PNG imported with the player controller, nil without one (closet/ui/view.lua's import).
    function g.import(file)
        local pc=U.controller()
        if not pc then return nil end
        return U.valid(U.find(RENDER):ImportFileAsTexture2D(pc,file)) or error('no texture from '..file,0)
    end
    return g
end

-- g: Hud.helpers(env), or the same calls.
function Hud.new(g)
    local self={}
    local ui={}
    local hud -- the HUD on screen the entry was built in, or the last look found
    local look_at,failed=0,nil -- the next look; the path of a HUD whose column was not usable
    local fresh,fresh_at,fresh_until -- the HUD its Construct named last; its path; until when it is checked
    local hooked,gone=false,false -- the Construct hook tried; the entry taken off for good (hide)
    Keep.want({Hud.HUD})

    -- The widget named name in outer (a widget tree or a panel), through UE4SS's StaticFindObject. cls: its UMG class
    -- (its subclasses too), Widget unless said. Names match in any case, as FNames do.
    local function inside(outer,name,cls)
        if not g.valid(outer) then return nil end
        local ok,o=pcall(StaticFindObject,g.cdo('/Script/UMG.'..(cls or 'Widget')),outer,name,false)
        return ok and g.valid(o) and o or nil
    end
    local function tree(w) return g.valid(w) and g.get(w,'WidgetTree') or nil end
    -- o while it is still the object recorded at path
    local function alive(o,path) return path~=nil and g.path(o)==path end
    -- One of our widgets, named. again: an earlier Lua load's widgets may stand in this HUD (Ctrl+R). Its widget of
    -- that name in outer is then taken again, off its parent until it is added back. Made again under the same name and
    -- outer, StaticAllocateObject (0x142b9bbf0 on 26123051, the function of the message at 0x145fb7de0) would destroy
    -- the live widget in place and build a new one at its address, under SB's panels that still hold it (ed6385e6).
    local function part(cls,outer,name,again)
        local o=again and inside(outer,name,cls)
        if o then pcall(function() o:RemoveFromParent() end); return o end
        return StaticConstructObject(g.cdo('/Script/UMG.'..cls),outer,FName(name))
    end
    -- The HUD on screen: of the WB_MainHUD_Master instances, the one in the viewport (others are never drawn).
    local function look()
        hud=nil
        pcall(function()
            for _,w in ipairs(FindAllOf('WB_MainHUD_Master_C') or {}) do
                if not w:GetFullName():find('Default__',1,true) and w:IsInViewport()==true then hud=w; break end
            end
        end)
        return hud~=nil
    end
    -- SB's HUD built (its Construct, on the game thread): only noted. It may not be on screen yet. tick builds.
    local function on_construct(ctx)
        if gone then return end
        local w=g.try(function() return ctx:get() end)
        local at=g.path(w)
        if at then fresh,fresh_at,fresh_until=w,at,os.clock()+Hud.FRESH end
    end
    -- Once a Lua load, as soon as the keep holds the HUD class (its Construct is then never freed). The closet's
    -- g.hook_hud registers it in closet/wiring.lua. A hook that fails leaves the looks alone.
    local function hook()
        if hooked or not g.hook_hud or not Keep.serves(Hud.HUD) then return end
        hooked=true
        local ok,e=pcall(g.hook_hud,Hud.HUD,on_construct)
        g.log(ok and 'hud: hook on: WB_MainHUD_Master_C:Construct' or ('hud: no Construct hook: '..tostring(e)))
    end

    -- The UMG enums passed as numbers (their tables read in Ghidra, build 26123051): ESlateVisibility at 0x1461f6f20
    -- (Visible 0, Collapsed 1, Hidden 2, HitTestInvisible 3, SelfHitTestInvisible 4), EHorizontalAlignment at
    -- 0x145fe1450 (Fill 0, Left 1, Center 2, Right 3) and EVerticalAlignment at 0x145fe1410 (Fill 0, Top 1, Center 2,
    -- Bottom 3).
    local function build()
        local P=Hud.PARTS
        local ht=tree(hud)
        local dpad=inside(ht,P.marker,'UserWidget')
        local dt=tree(dpad)
        -- the entry lives in the marker's own root overlay: placed against the marker without reading Slate geometry
        -- (FGeometry has no reflected fields, so UE4SS reads it as zeros). It is shown or hidden with the marker
        local overlay,up=inside(dt,P.overlay,'Overlay'),inside(dt,P.up,'Image')
        local pad_layer=inside(dt,P.pad,'Overlay') -- shown while a gamepad is in use
        -- the marker's key cell: its Image btn (the name in the paks of 26123051), found by name in the marker's
        -- widget tree
        local cell=inside(dt,P.cell,'Image')
        if not (overlay and dpad and up) then error('HUD item column not found',0) end
        local thumb=inside(ht,P.heal,'UserWidget') -- (its laid-out size is the potion icon's)
        local ok,err=pcall(function()
            -- An earlier load's entry in this marker has its row, the first part every build makes: with no row, none
            -- of its parts is there and none is looked for (4cdf5d4a).
            local again=inside(overlay,'ClosetSlot','HorizontalBox')~=nil
            local C=function(cls,outer,name) return part(cls,outer,name,again) end
            local box=C('HorizontalBox',overlay,'ClosetSlot')
            local lb=C('Image',box,'ClosetPadLB')       -- the pad's LB glyph, before the D-pad Left one
            local keyo=C('Overlay',box,'ClosetKey')     -- the key cell (keyboard) under the glyph
            local bg=C('Image',keyo,'ClosetKeyCell')
            local glyph=C('Image',keyo,'ClosetKeyGlyph')
            local img=C('Image',box,'ClosetIcon')
            if cell then pcall(function() bg:SetBrush(cell.Brush) end) end
            -- HAlign_Center, VAlign_Center
            local function center(sl) pcall(function() sl:SetHorizontalAlignment(2); sl:SetVerticalAlignment(2) end) end
            center(keyo:AddChildToOverlay(bg)); center(keyo:AddChildToOverlay(glyph))
            local sl=box:AddChildToHorizontalBox(lb)
            local sk=box:AddChildToHorizontalBox(keyo)
            local si=box:AddChildToHorizontalBox(img)
            for _,s in ipairs({sl,sk,si}) do pcall(function() s:SetVerticalAlignment(2) end) end -- VAlign_Center
            pcall(function() si:SetPadding({Left=Hud.GAP,Top=0,Right=0,Bottom=0}) end)
            -- held in a size box exactly the marker's laid-out size, so the marker never grows (a larger child, or a
            -- canvas, grew it and pushed the whole item column off the screen). The row inside keeps its own sizes and
            -- runs past the box to the right (nothing clips it); a render translation, outside layout, puts it beside
            -- gun mode's entry.
            local holder=C('SizeBox',overlay,'ClosetHolder')
            local hs=holder:AddChild(box)
            pcall(function() hs:SetHorizontalAlignment(1); hs:SetVerticalAlignment(2) end) -- left, centred
            local slot=overlay:AddChildToOverlay(holder)
            pcall(function() slot:SetHorizontalAlignment(1); slot:SetVerticalAlignment(2) end) -- left, centred
            box:SetVisibility(4); holder:SetVisibility(4) -- SelfHitTestInvisible
            -- Collapsed until follow shows them: a new Image with no brush draws a white square
            bg:SetVisibility(1); glyph:SetVisibility(1); img:SetVisibility(1); lb:SetVisibility(1)
            ui.holder=holder
            ui.overlay,ui.dpad,ui.up,ui.thumb,ui.box,ui.slot=overlay,dpad,up,thumb,box,slot
            ui.box_at,ui.overlay_at,ui.holder_at=g.path(box),g.path(overlay),g.path(holder)
            ui.pad_layer=pad_layer
            ui.keyo,ui.bg,ui.glyph,ui.img,ui.lb=keyo,bg,glyph,img,lb
            ui.cell=cell~=nil
            ui.k,ui.i=Hud.KEY_SIZE,Hud.ICON_SIZE
            -- what follow last applied was applied to the last HUD's widgets: a new HUD gets its glyph, cell, icon,
            -- sizes and place at once. The pad glyph found is kept for its HUD (0e51255f).
            ui.up_path,ui.sized,ui.x,ui.placed,ui.follow_at,ui.pad,ui.pad_up,ui.icon=nil,nil,nil,nil,nil,nil,nil,nil
        end)
        if not ok then error(err,0) end
    end
    -- The entry built in the HUD on screen: the one its Construct named once it is on screen, else the one a look
    -- finds.
    local function make()
        if fresh and (os.clock()>fresh_until or g.path(fresh)~=fresh_at) then fresh=nil end
        local src='a look'
        if fresh and g.try(function() return fresh:IsInViewport() end)==true then
            hud,fresh,src=fresh,nil,'its Construct'
        else
            if look_at>os.clock() then return false end
            look_at=os.clock()+Hud.RETRY
            if not look() then
                if not ui.logged then ui.logged=true; g.log('hud: no HUD in the viewport') end
                return false
            end
        end
        local at=g.path(hud)
        if at==failed then return false end
        local ok,err=pcall(build)
        local built='built, key cell '..(ui.cell and 'found' or 'not found')..' (HUD from '..src..')'
        g.log('hud: closet entry '..(ok and built or ('not built: '..tostring(err))))
        if not ok then failed=at; return false end
        look_at=os.clock()+Hud.AGAIN
        return true
    end

    -- a widget's laid-out size (its desired size: the drawn geometry is not readable through UE4SS)
    local function drawn(w)
        local s=w and g.try(function() return w:GetDesiredSize() end)
        return (s and s.X and s.X>1) and s or nil
    end

    -- Sizes from the game's widgets, the glyph from its D-pad marker, the hanger icon, the place right of gun mode's
    -- entry (twice a second).
    local function follow(key)
        if (ui.follow_at or 0)>os.clock() then return end
        ui.follow_at=os.clock()+0.5
        local ks=g.try(function() local z=ui.up.Brush.ImageSize; return z.X>1 and z or nil end) or drawn(ui.up)
        local is=drawn(ui.thumb)
        local k=ks and math.floor(ks.X+0.5) or Hud.KEY_SIZE
        local i=is and math.floor(is.X+0.5) or Hud.ICON_SIZE
        if ui.k~=k or ui.i~=i or not ui.sized then
            ui.k,ui.i,ui.sized=k,i,true
            pcall(function() ui.glyph:SetBrushSize({X=k,Y=k}) end)
            pcall(function() ui.lb:SetBrushSize({X=k,Y=k}) end)
            pcall(function() ui.bg:SetBrushSize({X=k*1.25,Y=k*1.25}) end)
            pcall(function() ui.img:SetBrushSize({X=i,Y=i}) end)
        end
        -- the hanger: imported once a HUD (the image's brush holds the texture while the HUD lives), tried again at
        -- each follow until a controller exists and the file imports
        if not ui.icon then
            local ok,t=pcall(g.import,Hud.ICON_FILE)
            if ok and t then
                ui.icon=true
                pcall(function() ui.img:SetBrushFromTexture(t,false); ui.img:SetBrushSize({X=ui.i,Y=ui.i}) end)
                pcall(function() ui.img:SetVisibility(4) end) -- SelfHitTestInvisible
            elseif not ok and not ui.icon_logged then
                ui.icon_logged=true; g.log('hud: no hanger icon: '..tostring(t))
            end
        end
        -- the glyphs: the Left and LB twins of what the game's marker shows. The marker's keyboard icons stay set while
        -- a gamepad is used (its gamepad layer, Overlay_ps, is shown instead), so a shown gamepad layer picks the pad
        -- glyph: the loaded DPad_Up of the pad the game shows (DualShock or Xbox), else the Xbox one. It is a walk of
        -- every texture, made once each time the layer comes up until one is found (0e51255f, ed6385e6).
        local up=g.try(function()
            local r=ui.up.Brush.ResourceObject
            return r and r:GetFullName():match('^%S+ (.+)$')
        end)
        local vis=ui.pad_layer and g.try(function() return ui.pad_layer:GetVisibility() end)
        local pad=vis~=nil and vis~=1 and vis~=2 -- not Collapsed or Hidden: the gamepad layer is up
        if pad and not ui.pad and not ui.pad_up then
            ui.pad_up=g.try(function()
                local best
                for _,t in ipairs(FindAllOf('Texture2D') or {}) do
                    local n=t:GetFullName():match('^%S+ (.+)$') or ''
                    if n:find('Gamepad_DPad_Up',1,true) then
                        if n:find('DualShock',1,true) and ui.dualshock then best=n end
                        best=best or n
                        if n:find('XboxOne',1,true) and not ui.dualshock then best=n; break end
                    end
                end
                return best
            end) or false
        end
        ui.pad=pad
        if pad then
            up=ui.pad_up or up
        end
        if up and (up~=ui.up_path or key~=ui.key) then
            ui.up_path,ui.key=up,key
            local path,lb_path=Hud.glyph_path(up,key)
            local t=path and g.asset(path)
            local lt=lb_path and g.asset(lb_path)
            -- on a pad both glyphs or none: D-pad Left alone would point at the game's CrossKey_Left
            if lb_path and not lt then t=nil end
            if t then
                pcall(function() ui.glyph:SetBrushFromTexture(t,false); ui.glyph:SetBrushSize({X=ui.k,Y=ui.k}) end)
            end
            if lt and t then
                pcall(function() ui.lb:SetBrushFromTexture(lt,false); ui.lb:SetBrushSize({X=ui.k,Y=ui.k}) end)
            end
            if path and not t and not ui.glyph_logged then
                ui.glyph_logged=true
                g.log('hud: no glyph for '..tostring(lt==nil and lb_path or path)..' (from '..up..')')
            end
            -- no glyph (no closet key on the keyboard, or no texture): neither glyph nor cell shows. The key cell only
            -- with the keyboard (the marker's own cells belong to its keyboard layer). Never without the marker's
            -- cell: an Image with no brush draws a white square
            local kb=up:find('KeyBoard',1,true)~=nil
            pcall(function() ui.glyph:SetVisibility(t and 4 or 1) end) -- SelfHitTestInvisible or Collapsed
            pcall(function() ui.lb:SetVisibility((t and lt) and 4 or 1) end) -- the same
            pcall(function() ui.bg:SetVisibility((t and kb and ui.cell) and 4 or 1) end) -- the same
            g.log('hud: glyph '..tostring(path)..(lb_path and (' after '..lb_path) or '')..(t and '' or ' (missing)'))
        end
        -- place: the holder takes the marker's size, the row is moved right of gun mode's entry by a render
        -- translation. Gun mode's row starts at the marker's width + GAP and holds its key cell (k*1.25), GAP, its
        -- rifle icon (i, the same sizes as ours) and its rounds text (TEXT_ROOM).
        local ok,perr=pcall(function()
            local ds=ui.dpad:GetDesiredSize()
            assert(ds and ds.X>0,'no desired size yet')
            local x=ds.X+Hud.GAP+(ui.k*1.25+Hud.GAP+ui.i)+Hud.TEXT_ROOM+Hud.SPACE
            if not ui.x or math.abs(ui.x-x)>0.5 then
                ui.holder:SetWidthOverride(ds.X); ui.holder:SetHeightOverride(ds.Y)
                ui.box:SetRenderTranslation({X=x,Y=ds.Y*Hud.DOWN}); ui.x=x
                if not ui.placed then
                    ui.placed=true
                    g.log(('hud: placed %.0f right of the marker (marker %.0fx%.0f, key %d, icon %d)')
                        :format(x,ds.X,ds.Y,ui.k,ui.i))
                end
            end
        end)
        if not ok and not ui.place_logged then ui.place_logged=true; g.log('hud: not placed yet: '..tostring(perr)) end
    end

    -- From the closet's tick: the entry on the HUD with the closet key (key: 'F1'; nil: no closet key or one with
    -- Shift, Ctrl or Alt, the pad glyphs only). Nothing once hide took the entry off (coop off).
    function self.tick(key)
        if gone then return end
        hook()
        if not (alive(ui.box,ui.box_at) and alive(ui.overlay,ui.overlay_at)) then
            ui.box=nil
            if not make() then return end
        end
        follow(key)
    end

    -- Taken off the HUD (coop off). The Construct hook stays registered: it does nothing from then on.
    function self.hide()
        if alive(ui.holder,ui.holder_at) then pcall(function() ui.holder:RemoveFromParent() end) end
        ui,gone,fresh={},true,nil
    end

    return self
end

return Hud
