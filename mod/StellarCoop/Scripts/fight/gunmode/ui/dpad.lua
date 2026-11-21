-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's entry in the HUD's item column, to the right of the D-pad marker (the D-pad Right spot): the button that
-- takes the rifle out, then the NIKKE rifle icon, then "rounds | magazines" while the rifle is out. The icon is the
-- game's own texture of the NIKKE rifle (Dpad.ICON, the Asset2D of ItemTable's row Nikke_AR), held for the game run by
-- the keep (core/keep.lua) so a map change never frees it; without the keep it is looked up by its path when the entry
-- is built. No image file ships with SBO. The button follows the game's own D-pad marker: on a gamepad the D-pad Right
-- glyph of the pad the game shows (its DPad_Up glyph's Right twin), on the keyboard the gun mode key's icon on the
-- game's own key cell (btn_PcEmpty), the way the marker shows Q and R. With no icon for the key (gun_key=none) the
-- button shows nothing. Sizes come from the game's own widgets (the key icon from btn_up, the rifle icon from the heal
-- item's icon), so the entry scales with the HUD. It is a child of the marker's own overlay, so it shows and hides with
-- the HUD. Each HUD gets the entry built anew, its parts found by name in the HUD's widget trees (Dpad.PARTS). While
-- the keep holds SB's HUD class, a hook on its Construct names each new HUD: the entry is built at the first tick that
-- HUD is on screen, with no walk. Otherwise (a Lua reload, the keep off) the look for the HUD on screen walks the
-- object array every Dpad.RETRY s. A name that UE4SS's StaticFindObject does not find costs a walk too
-- (core/unreal.lua), so gun mode's own widgets are looked for by name only when an earlier Lua load's are there. Every
-- widget kept is checked by its path before it is used, as a map change frees them and another object can then sit at
-- a freed address and pass IsValid.
local Keep=require('core.keep')
local Dpad={}

Dpad.ICON='/Game/DLC_2/Art/UI/texture/HiddenReward/Icon/Icon_Nikke_LostItem_AssaultRifle.Icon_Nikke_LostItem_AssaultRifle'
Dpad.GAP=6         -- HUD units between the D-pad marker and the entry, also between its parts
Dpad.KEY_SIZE=30   -- the key or pad glyph, until the game's btn_up has a drawn size
Dpad.ICON_SIZE=34  -- the rifle icon, until the heal item's icon has a drawn size
-- Below the health bars (BU, BE, HP, SH sit right of the marker in combat and covered the entry, 11-20): the entry's
-- centre this many marker heights below the marker's centre: under SH and above the screen's bottom edge (11-20 tests: 2.0
-- touched the edge, 3.0 was off the screen)
Dpad.DOWN=1.5
-- s between two looks for the HUD while the entry is not built: each look walks the object array once (FindAllOf of
-- WB_MainHUD_Master_C). The rifle away makes no other lookup (M2). Without the Construct hook a map change shows the
-- entry again within this time. A HUD whose item column could not be used is not tried again: only a new HUD is.
Dpad.RETRY=10
-- SB's HUD class (base paks of 26123051: /Game/Art/UI/Widget/HUD/WB_MainHUD_Master holds WB_MainHUD_Master_C, an
-- SBUserWidget whose own Construct overrides UserWidget's). Kept for the game run, so its hooked Construct stays.
Dpad.HUD='/Game/Art/UI/Widget/HUD/WB_MainHUD_Master.WB_MainHUD_Master_C'
Dpad.FRESH=30 -- s a HUD named by its Construct is checked for the screen before the looks alone go on
Dpad.CROSS_LEN,Dpad.CROSS_THICK,Dpad.CROSS_GAP=7,2,4 -- the hip-fire crosshair (screen units)
-- The game's widgets the entry uses, by their names in SB's HUD (the paks of 26123051): in WB_MainHUD_Master's widget
-- tree the D-pad marker (marker, a WB_MainHUD_Dpad) and the heal item (heal, a WB_MainHUD_ItemSlot); in the marker's
-- tree its root overlay (overlay), its up button (up), its gamepad layer (pad) and that layer's key cell (cell, an
-- image of btn_PcEmpty); in the heal item's tree its refill slot (refill), whose tree holds the count's text (count).
Dpad.PARTS={marker='WB_MainHUD_Dpad',heal='WB_MainHUD_HealItem',overlay='Overlay_0',up='btn_up',pad='Overlay_ps',
    cell='btn',refill='WB_MainHUD_ItemSlotRefill',count='TextBlock_Item_Count_1'}
local COLLAPSED,HIT_TEST_INVISIBLE,SELF_HIT_TEST_INVISIBLE=1,3,4 -- ESlateVisibility (its table at 0x1461f6f20)

-- The glyph texture for our entry from the one the game shows on its D-pad marker's up button: a pad's DPad_Up becomes
-- its DPad_Right; a keyboard key icon becomes the gun mode key's (KeyIcon_KeyBoard_<key>). nil: no change known.
function Dpad.glyph_path(up_path,key)
    if type(up_path)~='string' then return nil end
    if up_path:find('DPad_Up',1,true) then return (up_path:gsub('DPad_Up','DPad_Right')) end
    local dir=up_path:match('^(.*/)KeyIcon_KeyBoard_[%w_]+%.KeyIcon_KeyBoard_[%w_]+$')
    if dir and key then return dir..'KeyIcon_KeyBoard_'..key..'.KeyIcon_KeyBoard_'..key end
    return nil
end

-- g: gun mode's shared calls (fight/gunmode/mode.lua): log, try, valid, path, find (a /Script object), get (a
-- property), asset (a /Game asset, loaded when missing).
function Dpad.new(g)
    local self={}
    local ui={}  -- the entry in the HUD it was built in, made anew for each HUD: its widgets, their paths, what it shows
    local cr={}  -- the crosshair: its canvas, its path, its visibility
    local hud,hud_at -- the HUD on screen as last looked for; its path
    local look_at,cross_at,failed=0,0,nil -- the next look, the next crosshair try; a HUD whose column was not usable
    local fresh,fresh_at,fresh_until -- the HUD its Construct named last; its path; until when it is checked
    local hooked,gone=false,false -- the Construct hook tried; the entry taken off for good (hide)
    local said={}
    Keep.want({Dpad.ICON,Dpad.HUD})

    local function say(k,m) if not said[k] then said[k]=true; g.log(m) end end
    -- o while it is still the object recorded at path
    local function alive(o,path) return path~=nil and g.path(o)==path end
    -- The widget named name in outer (a widget tree or a panel), through UE4SS's StaticFindObject. cls: its UMG class
    -- (its subclasses too), Widget unless said. core/unreal.lua: an object in memory comes back at once, a name it
    -- does not find costs 4 to 35 ms in game.
    local function inside(outer,name,cls)
        if not g.valid(outer) then return nil end
        local ok,o=pcall(StaticFindObject,g.find('/Script/UMG.'..(cls or 'Widget')),outer,name,false)
        return ok and g.valid(o) and o or nil
    end
    local function tree(w) return g.valid(w) and g.get(w,'WidgetTree') or nil end
    -- One of our widgets, named. again: an earlier Lua load's widgets may stand in this HUD (Ctrl+R). Its widget of
    -- that name in outer is then taken again, off its parent until it is added back. Made again under the same name and
    -- outer, StaticAllocateObject (0x142b9bbf0 on 26123051, the function of the message at 0x145fb7de0) would destroy
    -- the live widget in place and build a new one at its address, under SB's panels that still hold it.
    local function part(cls,outer,name,again)
        local o=again and inside(outer,name,cls)
        if o then pcall(function() o:RemoveFromParent() end); return o end
        o=StaticConstructObject(g.find('/Script/UMG.'..cls),outer,FName(name))
        return assert(g.valid(o) and o,name..' not made')
    end

    -- The HUD on screen: of the WB_MainHUD_Master instances, the one in the viewport (others are never drawn).
    local function look()
        hud=nil
        pcall(function()
            for _,w in ipairs(FindAllOf('WB_MainHUD_Master_C') or {}) do
                if not w:GetFullName():find('Default__',1,true) and w:IsInViewport()==true then hud=w; break end
            end
        end)
        hud_at=hud and g.path(hud)
        return hud_at~=nil
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
        if hooked or not Keep.serves(Dpad.HUD) then return end
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
        -- (FGeometry has no reflected fields, so UE4SS reads it as zeros). It shows and hides with the marker
        local overlay,up=inside(dt,P.overlay,'Overlay'),inside(dt,P.up,'Image')
        if not (overlay and up) then error('HUD item column not found',0) end
        local pad_layer=inside(dt,P.pad,'Overlay') -- shown while a gamepad is in use
        local cell=inside(dt,P.cell,'Image')
        local thumb=inside(ht,P.heal,'UserWidget') -- (its laid-out size is the potion icon's)
        local font_src=inside(tree(inside(tree(thumb),P.refill,'UserWidget')),P.count,'TextBlock')
        local icon=Keep.serves(Dpad.ICON) and Keep.get(Dpad.ICON) or g.asset(Dpad.ICON)
        assert(g.valid(icon),'no rifle icon '..Dpad.ICON)
        -- An earlier load's entry in this marker has its row, the first part every build makes: with no row, none of
        -- its parts is there and none is looked for.
        local again=inside(overlay,'GunModeRifleSlot','HorizontalBox')~=nil
        local box=part('HorizontalBox',overlay,'GunModeRifleSlot',again)
        local keyo=part('Overlay',box,'GunModeRifleKey',again)     -- the key cell (keyboard) under the glyph
        local bg=part('Image',keyo,'GunModeRifleKeyCell',again)
        local glyph=part('Image',keyo,'GunModeRifleKeyGlyph',again)
        local img=part('Image',box,'GunModeRifleIcon',again)
        local txt=part('TextBlock',box,'GunModeRifleCount',again)
        local holder=part('SizeBox',overlay,'GunModeRifleHolder',again)
        if cell then pcall(function() bg:SetBrush(cell.Brush) end) end
        -- the glyph takes btn_up's look. follow gives it its texture and shows it: never the marker's own key
        pcall(function() glyph:SetBrush(up.Brush) end)
        glyph:SetVisibility(COLLAPSED); bg:SetVisibility(COLLAPSED)
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
        local hs=holder:AddChild(box)
        pcall(function() hs:SetHorizontalAlignment(1); hs:SetVerticalAlignment(2) end) -- left, centred
        box:SetVisibility(SELF_HIT_TEST_INVISIBLE); holder:SetVisibility(SELF_HIT_TEST_INVISIBLE)
        local slot=overlay:AddChildToOverlay(holder) -- last: a build that fails before it adds nothing to SB's HUD
        pcall(function() slot:SetHorizontalAlignment(1); slot:SetVerticalAlignment(2) end)
        ui={holder=holder,overlay=overlay,dpad=dpad,up=up,thumb=thumb,box=box,pad_layer=pad_layer,
            keyo=keyo,bg=bg,glyph=glyph,img=img,txt=txt,k=Dpad.KEY_SIZE,i=Dpad.ICON_SIZE,
            box_at=g.path(box),overlay_at=g.path(overlay),holder_at=g.path(holder)}
    end

    -- a widget's laid-out size (its desired size: the drawn geometry is not readable through UE4SS)
    local function drawn(w)
        local s=w and g.try(function() return w:GetDesiredSize() end)
        return (s and s.X and s.X>1) and s or nil
    end
    -- The DPad_Up glyph of a pad among the loaded textures, the Xbox one first: a walk of the object array. false for
    -- none.
    local function pad_glyph()
        return g.try(function()
            local best
            for _,t in ipairs(FindAllOf('Texture2D') or {}) do
                local n=t:GetFullName():match('^%S+ (.+)$') or ''
                if n:find('Gamepad_DPad_Up',1,true) then
                    best=best or n
                    if n:find('XboxOne',1,true) then best=n; break end
                end
            end
            return best
        end) or false
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
        -- glyph: a loaded pad DPad_Up, looked for each time the layer comes up until one is found. The one found is
        -- kept for this HUD (ui is made anew for each HUD).
        local up=g.try(function() local r=ui.up.Brush.ResourceObject; return r and r:GetFullName():match('^%S+ (.+)$') end)
        local vis=ui.pad_layer and g.try(function() return ui.pad_layer:GetVisibility() end)
        local pad=vis~=nil and vis~=COLLAPSED and vis~=2 -- not Collapsed or Hidden: the gamepad layer is up
        if pad and not ui.pad and not ui.pad_up then ui.pad_up=pad_glyph() end
        ui.pad=pad
        if pad then up=ui.pad_up or up end
        if not ui.drawn or up~=ui.up_path or key~=ui.key then
            ui.drawn,ui.up_path,ui.key=true,up,key
            local path=Dpad.glyph_path(up,key)
            local t=path and g.asset(path)
            if t then pcall(function() ui.glyph:SetBrushFromTexture(t,false); ui.glyph:SetBrushSize({X=ui.k,Y=ui.k}) end) end
            -- the key cell only with the keyboard (the marker's own cells belong to its keyboard layer). No texture
            -- (gun_key=none, or no icon for the key): neither the glyph nor the cell.
            local kb=type(up)=='string' and up:find('KeyBoard',1,true)~=nil
            pcall(function() ui.glyph:SetVisibility(t and SELF_HIT_TEST_INVISIBLE or COLLAPSED) end)
            pcall(function() ui.bg:SetVisibility((t and kb) and SELF_HIT_TEST_INVISIBLE or COLLAPSED) end)
            if t then g.log('dpad: glyph '..path)
            else say('glyph','dpad: no glyph for '..tostring(path)..' (from '..tostring(up)..')') end
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
        if not ok then say('place','dpad: not placed yet: '..tostring(perr)) end
    end

    -- From gun mode's loop: the entry on the HUD with the gun mode key (key: UE's key name, 'F4'; nil for none), text (the rounds, or nil while the
    -- rifle is away) in colour c ({r,g,b}). true when it built the entry (gun mode then keeps its path in coop-gun.txt).
    function self.tick(key,text,c)
        local made=false
        hook()
        if not (alive(ui.box,ui.box_at) and alive(ui.overlay,ui.overlay_at)) then
            ui={}
            if fresh and (os.clock()>fresh_until or not alive(fresh,fresh_at)) then fresh=nil end
            local src='a look'
            if fresh and g.try(function() return fresh:IsInViewport() end)==true then
                hud,hud_at,fresh,src=fresh,fresh_at,nil,'its Construct'
            else
                if look_at>os.clock() then return false end
                look_at=os.clock()+Dpad.RETRY
                if not look() then say('hud','dpad: no HUD in the viewport'); return false end
            end
            if hud_at==failed then return false end
            local ok,err=pcall(build)
            g.log('dpad: rifle entry '..(ok and ('built (HUD from '..src..')') or ('not built: '..tostring(err))))
            if not ok then failed=hud_at; ui={}; return false end
            made=true
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
        return made
    end
    -- The hip-fire crosshair: four short bars and a dot at the screen's centre, on the root canvas of the HUD the last
    -- look found, in the HUD's white. Shown while on is true. true when it built the crosshair.
    function self.crosshair(on)
        local live=alive(cr.w,cr.at)
        if not on and not live then return false end
        local made=false
        if on and not live then
            cr={}
            if cross_at>os.clock() then return false end
            cross_at=os.clock()+2
            local ok,err=pcall(function()
                assert(alive(hud,hud_at),'no HUD in the viewport')
                local root=g.get(tree(hud),'RootWidget')
                assert(g.valid(root) and root:IsA(g.find('/Script/UMG.CanvasPanel')),'the HUD root is not a canvas')
                -- an earlier load's bars only under its canvas
                local again=inside(root,'GunModeCrosshair','CanvasPanel')~=nil
                local cross=part('CanvasPanel',root,'GunModeCrosshair',again)
                local L,T,G=Dpad.CROSS_LEN,Dpad.CROSS_THICK,Dpad.CROSS_GAP
                local bars={{0,-(G+L/2),T,L},{0,G+L/2,T,L},{-(G+L/2),0,L,T},{G+L/2,0,L,T},{0,0,T,T}}
                for i,b in ipairs(bars) do
                    local im=part('Image',cross,'GunModeCross'..i,again)
                    pcall(function() im:SetColorAndOpacity({R=1,G=1,B=1,A=0.9}) end)
                    local sl=cross:AddChildToCanvas(im)
                    sl:SetAnchors({Minimum={X=0.5,Y=0.5},Maximum={X=0.5,Y=0.5}})
                    sl:SetAlignment({X=0.5,Y=0.5}); sl:SetPosition({X=b[1],Y=b[2]}); sl:SetSize({X=b[3],Y=b[4]})
                end
                cross:SetVisibility(HIT_TEST_INVISIBLE)
                local cs=root:AddChildToCanvas(cross)
                cs:SetAnchors({Minimum={X=0.5,Y=0.5},Maximum={X=0.5,Y=0.5}})
                cs:SetAlignment({X=0.5,Y=0.5}); cs:SetSize({X=40,Y=40}); cs:SetPosition({X=0,Y=0})
                cr={w=cross,at=g.path(cross),v=HIT_TEST_INVISIBLE}
            end)
            if not ok then say('cross','dpad: no crosshair: '..tostring(err)); return false end
            made=true
        end
        local v=on and HIT_TEST_INVISIBLE or COLLAPSED
        if cr.v~=v then cr.v=v; pcall(function() cr.w:SetVisibility(v) end) end
        return made
    end

    -- Taken off the HUD (gun mode unloaded). The Construct hook stays registered: it does nothing from then on.
    function self.hide()
        if alive(ui.holder,ui.holder_at) then pcall(function() ui.holder:RemoveFromParent() end) end
        if alive(cr.w,cr.at) then pcall(function() cr.w:RemoveFromParent() end) end
        ui,cr,gone,fresh={},{},true,nil
    end

    -- coop-gun.txt's records of the entry and the crosshair on the HUD now (hud|<path>): a later Lua load takes them
    -- off, gun mode on or off (fight/gunmode/mode.lua's restore).
    function self.records()
        local out={}
        if ui.holder_at then out[#out+1]={'hud',ui.holder_at} end
        if cr.at then out[#out+1]={'hud',cr.at} end
        return out
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
