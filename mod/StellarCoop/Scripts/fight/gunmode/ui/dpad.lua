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
-- so it shows and hides with the HUD. Its parts are found by name in the HUD's widget trees (Dpad.PARTS, ed6385e6), so
-- the look for the HUD on screen is the only walk of the object array, made again only when no HUD was usable, every
-- Dpad.RETRY s. While the keep holds SB's HUD class, a hook on its Construct names each new HUD: the entry is built at
-- the first tick that HUD is on screen, with no walk (d2de021b). An earlier Lua load's widgets in that HUD (Ctrl+R) are
-- taken again, never made over. Every widget kept is checked by its path before it is used, as a map change frees them
-- and another object can then sit at a freed address and pass IsValid (ed6385e6).
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
-- s between two looks for the HUD while none on screen could take the entry: each look walks the object array once
-- (FindAllOf of WB_MainHUD_Master_C). A HUD whose item column could not be used is not tried again: only a new HUD is.
-- After a build the next look waits Dpad.AGAIN s: a new HUD (a map change) gets the entry within that time.
Dpad.RETRY,Dpad.AGAIN=10,2
-- SB's HUD class (base paks of 26123051: /Game/Art/UI/Widget/HUD/WB_MainHUD_Master holds WB_MainHUD_Master_C, an
-- SBUserWidget whose own Construct overrides UserWidget's). Kept for the game run, so its hooked Construct stays.
Dpad.HUD='/Game/Art/UI/Widget/HUD/WB_MainHUD_Master.WB_MainHUD_Master_C'
Dpad.FRESH=30 -- s a HUD named by its Construct is checked for the screen before the looks alone go on
-- The game's widgets the entry uses, by their names in SB's HUD (the paks of 26123051): in WB_MainHUD_Master's widget
-- tree the D-pad marker (marker, a WB_MainHUD_Dpad) and the heal item (heal, a WB_MainHUD_ItemSlot); in the marker's
-- tree its root overlay (overlay), its up button (up), its gamepad layer (pad) and that layer's key cell (cell, an
-- image of btn_PcEmpty); in the heal item's tree its refill slot (refill), whose tree holds the count's text (count).
Dpad.PARTS={marker='WB_MainHUD_Dpad',heal='WB_MainHUD_HealItem',overlay='Overlay_0',up='btn_up',pad='Overlay_ps',
    cell='btn',refill='WB_MainHUD_ItemSlotRefill',count='TextBlock_Item_Count_1'}

-- The glyph texture for our entry from the one the game shows on its D-pad marker's up button: a pad's DPad_Up becomes
-- its DPad_Right; a keyboard key icon becomes the gun mode key's (KeyIcon_KeyBoard_<key>). nil: no change known.
function Dpad.glyph_path(up_path,key)
    if type(up_path)~='string' then return nil end
    if up_path:find('DPad_Up',1,true) then return (up_path:gsub('DPad_Up','DPad_Right')) end
    local dir=up_path:match('^(.*/)KeyIcon_KeyBoard_[%w_]+%.KeyIcon_KeyBoard_[%w_]+$')
    if dir and key then return dir..'KeyIcon_KeyBoard_'..key..'.KeyIcon_KeyBoard_'..key end
    return nil
end

-- g: gun mode's shared calls (fight/gunmode/mode.lua): log, try, valid, path, cdo (a /Script object), get (a
-- property), asset (a /Game asset, loaded when missing), hook_hud (path, callback: a hook on the Construct of the
-- widget class at path; nil: the looks alone).
function Dpad.new(g)
    local self={}
    local ui={}
    local hud -- the HUD on screen the entry was built in, or the last look found
    local look_at,failed=0,nil -- the next look; the path of a HUD whose column was not usable
    local fresh,fresh_at,fresh_until -- the HUD its Construct named last; its path; until when it is checked
    local hooked,gone=false,false -- the Construct hook tried; the entry taken off for good (hide)
    Keep.want({Dpad.ICON,Dpad.HUD})

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
        if at then fresh,fresh_at,fresh_until=w,at,os.clock()+Dpad.FRESH end
    end
    -- Once a Lua load, as soon as the keep holds the HUD class (its Construct is then never freed). gun mode's
    -- g.hook_hud registers it in fight/gunmode/wiring.lua. A hook that fails leaves the looks alone.
    local function hook()
        if hooked or not g.hook_hud or not Keep.serves(Dpad.HUD) then return end
        hooked=true
        local ok,e=pcall(g.hook_hud,Dpad.HUD,on_construct)
        g.log(ok and 'dpad: hook on: WB_MainHUD_Master_C:Construct' or ('dpad: no Construct hook: '..tostring(e)))
    end

    local function build()
        local P=Dpad.PARTS
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
        local font_src=inside(tree(inside(tree(thumb),P.refill,'UserWidget')),P.count,'TextBlock')
        local ok,err=pcall(function()
            local icon=Keep.serves(Dpad.ICON) and Keep.get(Dpad.ICON) or g.asset(Dpad.ICON)
            assert(icon and icon:IsValid(),'no rifle icon '..Dpad.ICON)
            -- An earlier load's entry in this marker has its row, the first part every build makes: with no row, none
            -- of its parts is there and none is looked for (4cdf5d4a).
            local again=inside(overlay,'GunModeRifleSlot','HorizontalBox')~=nil
            local C=function(cls,outer,name) return part(cls,outer,name,again) end
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
            ui.box_at,ui.overlay_at,ui.holder_at=g.path(box),g.path(overlay),g.path(holder)
            ui.pad_layer=pad_layer
            ui.keyo,ui.bg,ui.glyph,ui.img,ui.txt=keyo,bg,glyph,img,txt
            ui.cell=cell~=nil
            ui.k,ui.i=Dpad.KEY_SIZE,Dpad.ICON_SIZE
            -- what follow last applied was applied to the last HUD's widgets: a new HUD gets its glyph, cell, sizes
            -- and place at once. The pad glyph found is kept for its HUD (0e51255f).
            ui.up_path,ui.sized,ui.x,ui.placed,ui.follow_at,ui.pad,ui.pad_up=nil,nil,nil,nil,nil,nil,nil
            ui.text,ui.col=nil,nil -- (written to these widgets at the next tick)
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
            look_at=os.clock()+Dpad.RETRY
            if not look() then
                if not ui.logged then ui.logged=true; g.log('dpad: no HUD in the viewport') end
                return false
            end
        end
        local at=g.path(hud)
        if at==failed then return false end
        local ok,err=pcall(build)
        local built='built, key cell '..(ui.cell and 'found' or 'not found')..' (HUD from '..src..')'
        g.log('dpad: rifle entry '..(ok and built or ('not built: '..tostring(err))))
        if not ok then failed=at; return false end
        look_at=os.clock()+Dpad.AGAIN
        return true
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
        -- glyph: the loaded DPad_Up of the pad the game shows (DualShock or Xbox), else the Xbox one. It is a walk of
        -- every texture, made once each time the layer comes up until one is found (0e51255f, ed6385e6).
        local up=g.try(function() local r=ui.up.Brush.ResourceObject; return r and r:GetFullName():match('^%S+ (.+)$') end)
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
            local path=Dpad.glyph_path(up,key)
            local t=path and g.asset(path)
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
        hook()
        if not (alive(ui.box,ui.box_at) and alive(ui.overlay,ui.overlay_at)) then
            ui.box=nil
            if not make() then return end
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

    -- The hip-fire crosshair: four short bars and a dot at the screen's centre, on the root canvas of the HUD the entry
    -- was built in (no walk: ed6385e6), in the HUD's white. Shown while on is true.
    function self.crosshair(on)
        local live=alive(ui.cross,ui.cross_at)
        if not on and not live then return end
        if on and not live then
            if (ui.cross_retry or 0)>os.clock() then return end
            ui.cross_retry=os.clock()+2
            local ok,err=pcall(function()
                assert(g.valid(hud),'no HUD in the viewport')
                local root=hud.WidgetTree.RootWidget
                assert(root and root:IsA(g.cdo('/Script/UMG.CanvasPanel')),'the HUD root is not a canvas')
                -- an earlier load's bars only under its canvas (ed6385e6)
                local again=inside(root,'GunModeCrosshair','CanvasPanel')~=nil
                local C=function(cls,outer,name) return part(cls,outer,name,again) end
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
                ui.cross,ui.cross_at,ui.cross_v=cross,g.path(cross),nil
            end)
            if not ok and not ui.cross_logged then ui.cross_logged=true; g.log('dpad: no crosshair: '..tostring(err)) end
            if not ok then return end
        end
        local v=on and 3 or 1 -- HitTestInvisible / Collapsed
        if ui.cross_v~=v then ui.cross_v=v; pcall(function() ui.cross:SetVisibility(v) end) end
    end

    -- Taken off the HUD (gun mode unloaded). The Construct hook stays registered: it does nothing from then on.
    function self.hide()
        if alive(ui.holder,ui.holder_at) then pcall(function() ui.holder:RemoveFromParent() end) end
        if alive(ui.cross,ui.cross_at) then pcall(function() ui.cross:RemoveFromParent() end) end
        ui,gone,fresh={},true,nil
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
