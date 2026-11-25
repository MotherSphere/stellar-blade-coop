-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's entry in the HUD's item column, to the right of the D-pad marker (the D-pad Right spot): the button that
-- takes the rifle out, then the NIKKE rifle icon, then "rounds | magazines" while the rifle is out. The icon is the
-- game's own texture of the NIKKE rifle (Dpad.ICON, the Asset2D of ItemTable's row Nikke_AR), held for the game run by
-- the keep (core/keep.lua) so a map change never frees it; without the keep it is looked up by its path when the entry
-- is built. No image file ships with SBO. The button follows the game's own D-pad marker: on a gamepad the D-pad Right glyph of the pad the game
-- shows (its DPad_Up glyph's Right twin), on the keyboard the gun mode key's icon on the game's own key cell
-- (btn_PcEmpty), the way the marker shows Q and R. Sizes come from the game's own widgets (the key icon from btn_up, the
-- rifle icon from the heal item's icon), so the entry scales with the HUD. It is the HUD's own child (Overlay_ItemSlot),
-- so it shows and hides with the HUD.
local Keep=require('core.keep')
local Dpad={}

Dpad.ICON='/Game/DLC_2/Art/UI/texture/HiddenReward/Icon/Icon_Nikke_LostItem_AssaultRifle.Icon_Nikke_LostItem_AssaultRifle'
Dpad.GAP=6         -- HUD units between the D-pad marker and the entry. The same gap separates its parts
Dpad.KEY_SIZE=30   -- the key or pad glyph, until the game's btn_up has a drawn size
Dpad.ICON_SIZE=34  -- the rifle icon, until the heal item's icon has a drawn size
-- Below the health bars (BU, BE, HP, SH sit right of the marker in combat and covered the entry, 11-20): the entry's
-- centre this many marker heights below the marker's centre: under SH and above the screen's bottom edge (11-20 tests: 2.0
-- touched the edge, 3.0 was off the screen)
Dpad.DOWN=1.5
Dpad.CROSS_LEN,Dpad.CROSS_THICK,Dpad.CROSS_GAP=7,2,4 -- the hip-fire crosshair (screen units)

-- The glyph texture for our entry from the one the game shows on its D-pad marker's up button: a pad's DPad_Up becomes
-- its DPad_Right; a keyboard key icon becomes the gun mode key's (KeyIcon_KeyBoard_<key>). nil: no change known.
function Dpad.glyph_path(up_path,key)
    if type(up_path)~='string' then return nil end
    if up_path:find('DPad_Up',1,true) then return (up_path:gsub('DPad_Up','DPad_Right')) end
    local dir=up_path:match('^(.*/)KeyIcon_KeyBoard_[%w_]+%.KeyIcon_KeyBoard_[%w_]+$')
    if dir and key then return dir..'KeyIcon_KeyBoard_'..key..'.KeyIcon_KeyBoard_'..key end
    return nil
end

function Dpad.new(g)
    local self={}
    local ui={}
    Keep.want({Dpad.ICON})

    -- the HUD on screen: of the WB_MainHUD_Master instances, the one in the viewport (others are never drawn)
    local function hud_name()
        local name
        pcall(function()
            for _,w in ipairs(FindAllOf('WB_MainHUD_Master_C') or {}) do
                local full=w:GetFullName()
                if not full:find('Default__',1,true) and w:IsInViewport()==true then name=full:match('(WB_MainHUD_Master_C_%d+)'); break end
            end
        end)
        return name
    end
    local function leaf_find(kind,leaf,inside)
        local found
        local hud=ui.hud
        pcall(function()
            for _,w in ipairs(FindAllOf(kind) or {}) do
                local full=w:GetFullName()
                if hud and not full:find(hud..'.',1,true) then goto next end
                -- the live HUD only: the class's template tree (...WB_MainHUD_Master_C:WidgetTree...) is never drawn
                if full:find('WB_MainHUD_Master_C_',1,true) and not full:find(':WidgetTree',1,true)
                    and (not inside or full:find(inside,1,true)) and full:match('([%w_]+)$')==leaf then found=w; break end
                ::next::
            end
        end)
        return found
    end
    local function tex(path)
        local t=StaticFindObject(path)
        if not (t and t:IsValid()) then pcall(LoadAsset,path); t=StaticFindObject(path) end
        return (t and t:IsValid()) and t or nil
    end

    local function build()
        if (ui.retry or 0)>os.clock() then return false end
        ui.retry=os.clock()+2
        ui.hud=hud_name()
        if not ui.hud then
            if not ui.logged then ui.logged=true; g.log('dpad: no HUD in the viewport') end
            return false
        end
        -- the entry lives in the marker's own root overlay: placed against the marker without reading Slate geometry
        -- (FGeometry has no reflected fields, so UE4SS reads it as zeros). It is shown or hidden with the marker
        local overlay=leaf_find('Overlay','Overlay_0','WB_MainHUD_Dpad.WidgetTree.Overlay_0')
        local dpad=leaf_find('UserWidget','WB_MainHUD_Dpad')
        local up=leaf_find('Image','btn_up','WB_MainHUD_Dpad')
        local pad_layer=leaf_find('Overlay','Overlay_ps','WB_MainHUD_Dpad') -- shown while a gamepad is in use
        -- the marker's key cell: its Image btn (the name in the paks of 26123051), found by name in the marker's
        -- widget tree, where names match in any case as FNames do
        local cell=g.try(function()
            local o=StaticFindObject(StaticFindObject('/Script/UMG.Image'),dpad.WidgetTree,'btn',false)
            return g.valid(o) and o or nil
        end)
        if not (overlay and dpad and up) then
            if not ui.logged then ui.logged=true; g.log('dpad: HUD item column not found') end
            return false
        end
        local thumb=leaf_find('UserWidget','WB_MainHUD_HealItem') -- (its laid-out size is the potion icon's)
        local font_src=leaf_find('TextBlock','TextBlock_Item_Count_1')
        local ok,err=pcall(function()
            local icon=Keep.serves(Dpad.ICON) and Keep.get(Dpad.ICON) or tex(Dpad.ICON)
            assert(icon and icon:IsValid(),'no rifle icon '..Dpad.ICON)
            local C=function(cls,outer,name) return StaticConstructObject(StaticFindObject('/Script/UMG.'..cls),outer,FName(name)) end
            local box=C('HorizontalBox',overlay,'GunModeRifleSlot')
            local keyo=C('Overlay',box,'GunModeRifleKey')     -- the key cell (keyboard) under the glyph
            local bg=C('Image',keyo,'GunModeRifleKeyCell')
            local glyph=C('Image',keyo,'GunModeRifleKeyGlyph')
            local img=C('Image',box,'GunModeRifleIcon')
            local txt=C('TextBlock',box,'GunModeRifleCount')
            if cell then pcall(function() bg:SetBrush(cell.Brush) end) end
            pcall(function() glyph:SetBrush(up.Brush) end)
            img:SetBrushFromTexture(icon,false)
            if font_src then
                pcall(function() txt:SetFont(font_src.Font) end)
                pcall(function() txt:SetShadowOffset(font_src.ShadowOffset) end)
                pcall(function() txt:SetShadowColorAndOpacity(font_src.ShadowColorAndOpacity) end)
            end
            local function center(sl) pcall(function() sl:SetHorizontalAlignment(2); sl:SetVerticalAlignment(2) end) end
            center(keyo:AddChildToOverlay(bg)); center(keyo:AddChildToOverlay(glyph))
            local sk=box:AddChildToHorizontalBox(keyo)
            local si=box:AddChildToHorizontalBox(img)
            local st=box:AddChildToHorizontalBox(txt)
            for _,sl in ipairs({sk,si,st}) do pcall(function() sl:SetVerticalAlignment(2) end) end
            pcall(function() si:SetPadding({Left=Dpad.GAP,Top=0,Right=0,Bottom=0}) end)
            pcall(function() st:SetPadding({Left=4,Top=0,Right=0,Bottom=0}) end)
            -- held in a size box exactly the marker's laid-out size, so the marker never grows (a larger child, or a
            -- canvas, grew it and pushed the whole item column off the screen). The row inside keeps its own sizes and
            -- runs past the box to the right (nothing clips it); a render translation, outside layout, puts it beside
            -- the marker.
            local holder=C('SizeBox',overlay,'GunModeRifleHolder')
            local hs=holder:AddChild(box)
            pcall(function() hs:SetHorizontalAlignment(1); hs:SetVerticalAlignment(2) end) -- left, centred
            local slot=overlay:AddChildToOverlay(holder)
            pcall(function() slot:SetHorizontalAlignment(1); slot:SetVerticalAlignment(2) end)
            box:SetVisibility(4); holder:SetVisibility(4) -- SelfHitTestInvisible
            bg:SetVisibility(1) -- Collapsed until follow shows it: a new Image with no brush draws a white square
            ui.holder=holder
            ui.overlay,ui.dpad,ui.up,ui.thumb,ui.box,ui.slot=overlay,dpad,up,thumb,box,slot
            ui.pad_layer=pad_layer
            ui.keyo,ui.bg,ui.glyph,ui.img,ui.txt=keyo,bg,glyph,img,txt
            ui.cell=cell~=nil
            ui.k,ui.i=Dpad.KEY_SIZE,Dpad.ICON_SIZE
            -- what follow last applied was applied to the last HUD's widgets: a new HUD gets its glyph, cell, sizes
            -- and place at once
            ui.up_path,ui.sized,ui.x,ui.placed,ui.follow_at=nil,nil,nil,nil,nil
        end)
        g.log('dpad: rifle entry '..(ok and ('built, key cell '..(ui.cell and 'found' or 'not found')) or ('not built: '..tostring(err))))
        return ok
    end

    -- a widget's laid-out size (its desired size: the drawn geometry is not readable through UE4SS)
    local function drawn(w)
        local s=w and g.try(function() return w:GetDesiredSize() end)
        return (s and s.X and s.X>1) and s or nil
    end

    -- Sizes from the game's widgets, the glyph from its D-pad marker, the place beside the marker (twice a second).
    local function follow(key)
        if (ui.follow_at or 0)>os.clock() then return end
        ui.follow_at=os.clock()+0.5
        local ks=g.try(function() local z=ui.up.Brush.ImageSize; return z.X>1 and z or nil end) or drawn(ui.up)
        local is=drawn(ui.thumb)
        local k=ks and math.floor(ks.X+0.5) or Dpad.KEY_SIZE
        local i=is and math.floor(is.X+0.5) or Dpad.ICON_SIZE
        if ui.k~=k or ui.i~=i or not ui.sized then
            ui.k,ui.i,ui.sized=k,i,true
            pcall(function() ui.glyph:SetBrushSize({X=k,Y=k}) end)
            pcall(function() ui.bg:SetBrushSize({X=k*1.25,Y=k*1.25}) end)
            pcall(function() ui.img:SetBrushSize({X=i,Y=i}) end)
        end
        -- the glyph: the Right twin of what the game's marker shows. The marker's keyboard icons stay set while a
        -- gamepad is used (its gamepad layer, Overlay_ps, is shown instead), so a shown gamepad layer picks the pad
        -- glyph: the loaded DPad_Up of the pad the game shows (DualShock or Xbox), else the Xbox one.
        local up=g.try(function() local r=ui.up.Brush.ResourceObject; return r and r:GetFullName():match('^%S+ (.+)$') end)
        local pad=ui.pad_layer and g.try(function() return ui.pad_layer:GetVisibility() end)
        if pad~=nil and pad~=1 and pad~=2 then -- not Collapsed or Hidden: the gamepad layer is up
            ui.pad_up=ui.pad_up or g.try(function()
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
            end)
            up=ui.pad_up or up
        end
        if up and (up~=ui.up_path or key~=ui.key) then
            ui.up_path,ui.key=up,key
            local path=Dpad.glyph_path(up,key)
            local t=path and tex(path)
            if t then pcall(function() ui.glyph:SetBrushFromTexture(t,false); ui.glyph:SetBrushSize({X=ui.k,Y=ui.k}) end) end
            if not t and not ui.glyph_logged then ui.glyph_logged=true; g.log('dpad: no glyph for '..tostring(path)..' (from '..up..')') end
            -- the key cell only with the keyboard (the marker's own cells belong to its keyboard layer). Never without
            -- the marker's cell: an Image with no brush draws a white square
            local kb=up:find('KeyBoard',1,true)~=nil
            pcall(function() ui.bg:SetVisibility((kb and ui.cell) and 4 or 1) end)
            g.log('dpad: glyph '..tostring(path)..(t and '' or ' (missing)'))
        end
        -- place: the holder takes the marker's size, the row is moved right of the marker by a render translation
        local ok,perr=pcall(function()
            local ds=ui.dpad:GetDesiredSize()
            assert(ds and ds.X>0,'no desired size yet')
            local x=ds.X+Dpad.GAP
            if not ui.x or math.abs(ui.x-x)>0.5 then
                ui.holder:SetWidthOverride(ds.X); ui.holder:SetHeightOverride(ds.Y)
                ui.box:SetRenderTranslation({X=x,Y=ds.Y*Dpad.DOWN}); ui.x=x
                if not ui.placed then ui.placed=true; g.log(('dpad: placed %.0f right of the marker (marker %.0fx%.0f, key %d, icon %d)'):format(x,ds.X,ds.Y,ui.k,ui.i)) end
            end
        end)
        if not ok and not ui.place_logged then ui.place_logged=true; g.log('dpad: not placed yet: '..tostring(perr)) end
    end

    -- From gun mode's loop: the entry on the HUD with the gun mode key (key: 'G'), text (the rounds, or nil while the
    -- rifle is away) in colour c ({r,g,b}).
    function self.tick(key,text,c)
        if not (g.valid(ui.box) and g.valid(ui.overlay)) then
            ui.box=nil
            if not build() then return end
        end
        follow(key)
        text=text or ''
        if ui.text~=text then
            if pcall(function() ui.txt:SetText(FText(text)) end) then ui.text=text end
        end
        local col=c and table.concat(c,',') or ''
        if c and ui.col~=col then
            ui.col=col
            pcall(function() ui.txt:SetColorAndOpacity({SpecifiedColor={R=c[1],G=c[2],B=c[3],A=1},ColorUseRule=0}) end)
        end
    end
    -- (the old interface) shown with text while the rifle is out
    function self.show(text,c) self.tick(ui.key or 'G',text,c) end

    -- The hip-fire crosshair: four short bars and a dot at the screen's centre, on the HUD's root canvas, in the
    -- HUD's white. Shown while on is true.
    function self.crosshair(on)
        if not on and not g.valid(ui.cross) then return end
        if on and not g.valid(ui.cross) then
            if (ui.cross_retry or 0)>os.clock() then return end
            ui.cross_retry=os.clock()+2
            local ok,err=pcall(function()
                local hud
                for _,w in ipairs(FindAllOf('WB_MainHUD_Master_C') or {}) do
                    if not w:GetFullName():find('Default__',1,true) and w:IsInViewport()==true then hud=w; break end
                end
                assert(hud,'no HUD in the viewport')
                local root=hud.WidgetTree.RootWidget
                assert(root and root:IsA(StaticFindObject('/Script/UMG.CanvasPanel')),'the HUD root is not a canvas')
                local C=function(cls,outer,name) return StaticConstructObject(StaticFindObject('/Script/UMG.'..cls),outer,FName(name)) end
                local cross=C('CanvasPanel',root,'GunModeCrosshair')
                local cs=root:AddChildToCanvas(cross)
                cs:SetAnchors({Minimum={X=0.5,Y=0.5},Maximum={X=0.5,Y=0.5}})
                cs:SetAlignment({X=0.5,Y=0.5}); cs:SetSize({X=40,Y=40}); cs:SetPosition({X=0,Y=0})
                local L,T,G=Dpad.CROSS_LEN,Dpad.CROSS_THICK,Dpad.CROSS_GAP
                local bars={{0,-(G+L/2),T,L},{0,G+L/2,T,L},{-(G+L/2),0,L,T},{G+L/2,0,L,T},{0,0,T,T}}
                for i,b in ipairs(bars) do
                    local im=C('Image',cross,'GunModeCross'..i)
                    pcall(function() im:SetColorAndOpacity({R=1,G=1,B=1,A=0.9}) end)
                    local sl=cross:AddChildToCanvas(im)
                    sl:SetAnchors({Minimum={X=0.5,Y=0.5},Maximum={X=0.5,Y=0.5}})
                    sl:SetAlignment({X=0.5,Y=0.5}); sl:SetPosition({X=b[1],Y=b[2]}); sl:SetSize({X=b[3],Y=b[4]})
                end
                cross:SetVisibility(3) -- HitTestInvisible
                ui.cross=cross
            end)
            if not ok and not ui.cross_logged then ui.cross_logged=true; g.log('dpad: no crosshair: '..tostring(err)) end
            if not ok then return end
        end
        local v=on and 3 or 1 -- HitTestInvisible / Collapsed
        if ui.cross_v~=v then ui.cross_v=v; pcall(function() ui.cross:SetVisibility(v) end) end
    end

    -- Taken off the HUD (gun mode unloaded).
    function self.hide()
        if g.valid(ui.holder) then pcall(function() ui.holder:RemoveFromParent() end) end
        if g.valid(ui.cross) then pcall(function() ui.cross:RemoveFromParent() end) end
        ui={}
    end

    -- (dev, gun_trace=on) the D-pad marker's widgets with their class, visibility and brush or text, one log line each.
    function self.dump()
        local n=0
        pcall(function()
            for _,kind in ipairs({'Image','TextBlock','Overlay','HorizontalBox','UserWidget'}) do
                for _,w in ipairs(FindAllOf(kind) or {}) do
                    local full=w:GetFullName()
                    if full:find('WB_MainHUD_Master',1,true) and full:find('Dpad',1,true) then
                        local extra=''
                        if kind=='Image' then pcall(function() local r=w.Brush.ResourceObject; extra=' brush '..(r and r:GetFullName() or 'nil') end)
                        elseif kind=='TextBlock' then pcall(function() extra=' text "'..w:GetText():ToString()..'"' end) end
                        local vis=''; pcall(function() vis=' vis '..tostring(w:GetVisibility()) end)
                        g.log('dpad dump: '..kind..' '..full:match('WB_MainHUD_Master.*$')..vis..extra)
                        n=n+1
                    end
                end
            end
        end)
        g.log('dpad dump: '..n..' widgets')
    end

    return self
end

return Dpad
