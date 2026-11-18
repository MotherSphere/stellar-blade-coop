-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The rifle's place in the HUD's item column: to the right of the D-pad marker (the D-pad Right spot, the key that
-- takes the rifle out), the NIKKE rifle icon (nikke_rifle.png beside this file) and the rounds, "rounds | magazines",
-- in the potion count's font. It is the game's HUD's own child (Overlay_ItemSlot), so it shows and hides with the HUD.
local Dpad={}

Dpad.ICON='nikke_rifle.png'
Dpad.SIZE=34      -- The icon's size in the HUD's units (the potion icon is about this tall).
Dpad.GAP=6        -- Between the D-pad marker and the icon.

-- This file's folder (the icon sits beside it).
local function here()
    local src=debug.getinfo(1,'S').source or ''
    return (src:gsub('^@',''):match('^(.*[/\\])') or '')
end

function Dpad.new(g)
    local self={}
    local ui={}

    local function leaf_find(kind,leaf)
        local found
        pcall(function()
            for _,w in ipairs(FindAllOf(kind) or {}) do
                local full=w:GetFullName()
                if full:find('WB_MainHUD_Master',1,true) and full:match('([%w_]+)$')==leaf then found=w; break end
            end
        end)
        return found
    end

    local function build()
        if (ui.retry or 0)>os.clock() then return false end
        ui.retry=os.clock()+2
        local overlay=leaf_find('Overlay','Overlay_ItemSlot')
        local dpad=leaf_find('UserWidget','WB_MainHUD_Dpad')
        if not (overlay and dpad) then
            if not ui.logged then ui.logged=true; g.log('dpad: HUD item column not found') end
            return false
        end
        local font_src=leaf_find('TextBlock','TextBlock_Item_Count_1')
        local ok,err=pcall(function()
            local lib=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary')
            local tex=lib:ImportFileAsTexture2D(g.pawn(),here()..Dpad.ICON)
            assert(tex and tex:IsValid(),'icon not loaded from '..here()..Dpad.ICON)
            local box=StaticConstructObject(StaticFindObject('/Script/UMG.HorizontalBox'),overlay,FName('GunModeRifleSlot'))
            local img=StaticConstructObject(StaticFindObject('/Script/UMG.Image'),box,FName('GunModeRifleIcon'))
            local txt=StaticConstructObject(StaticFindObject('/Script/UMG.TextBlock'),box,FName('GunModeRifleCount'))
            img:SetBrushFromTexture(tex,false)
            img:SetBrushSize({X=Dpad.SIZE,Y=Dpad.SIZE})
            if font_src then
                pcall(function() txt:SetFont(font_src.Font) end)
                pcall(function() txt:SetShadowOffset(font_src.ShadowOffset) end)
                pcall(function() txt:SetShadowColorAndOpacity(font_src.ShadowColorAndOpacity) end)
            end
            local s1=box:AddChildToHorizontalBox(img)
            local s2=box:AddChildToHorizontalBox(txt)
            pcall(function() s1:SetVerticalAlignment(2) end) -- VAlign_Center
            pcall(function() s2:SetVerticalAlignment(2) end)
            pcall(function() s2:SetPadding({Left=4,Top=0,Right=0,Bottom=0}) end)
            local slot=overlay:AddChildToOverlay(box)
            slot:SetHorizontalAlignment(1) -- HAlign_Left
            slot:SetVerticalAlignment(1)   -- VAlign_Top
            box:SetVisibility(4)           -- SelfHitTestInvisible
            ui.overlay,ui.dpad,ui.box,ui.slot,ui.img,ui.txt=overlay,dpad,box,slot,img,txt
        end)
        g.log('dpad: rifle slot '..(ok and 'built' or ('not built: '..tostring(err))))
        return ok
    end

    -- Beside the D-pad marker: its place in the item column's overlay. From both widgets' last drawn geometry when
    -- that can be read; otherwise from the column's laid-out sizes (the heal item's row above it, the marker's size).
    local function place()
        if (ui.place_at or 0)>os.clock() then return end
        ui.place_at=os.clock()+0.5
        local pad,how
        local ok,err=pcall(function()
            local lib=StaticFindObject('/Script/UMG.Default__SlateBlueprintLibrary')
            local dg,og=ui.dpad:GetCachedGeometry(),ui.overlay:GetCachedGeometry()
            local abs=lib:LocalToAbsolute(dg,{X=0,Y=0})
            local loc=lib:AbsoluteToLocal(og,abs)
            local size=lib:GetLocalSize(dg)
            assert(size.X>0,'no drawn size yet')
            pad={Left=loc.X+size.X+Dpad.GAP,Top=loc.Y+size.Y*0.5-Dpad.SIZE*0.5,Right=0,Bottom=0}
            how='geometry'
        end)
        if not pad then
            local ok2,err2=pcall(function()
                local upper=leaf_find('Overlay','Overlay_ItemUpper')
                local us=upper and upper:GetDesiredSize() or {X=0,Y=0}
                local ds=ui.dpad:GetDesiredSize()
                assert(ds.X>0,'no desired size yet')
                pad={Left=ds.X+Dpad.GAP,Top=us.Y+ds.Y*0.5-Dpad.SIZE*0.5,Right=0,Bottom=0}
                how=('sizes (row above %.0fx%.0f, marker %.0fx%.0f)'):format(us.X,us.Y,ds.X,ds.Y)
            end)
            if not pad then
                if not ui.place_logged then ui.place_logged=true; g.log('dpad: not placed: '..tostring(err)..' / '..tostring(err2)) end
                return
            end
        end
        if not ui.pad or math.abs(ui.pad.Left-pad.Left)>0.5 or math.abs(ui.pad.Top-pad.Top)>0.5 then
            pcall(function() ui.slot:SetPadding(pad) end)
            ui.pad=pad
            if not ui.placed then ui.placed=true; g.log(('dpad: placed at %.0f, %.0f from %s'):format(pad.Left,pad.Top,how)) end
        end
    end

    -- Shown with text (in colour c, {r,g,b}) while the rifle is out.
    function self.show(text,c)
        if not (g.valid(ui.box) and g.valid(ui.overlay)) then
            ui.box=nil
            if not build() then return end
        end
        place()
        if ui.text~=text then
            if pcall(function() ui.txt:SetText(FText(text)) end) then ui.text=text end
        end
        local key=c and table.concat(c,',') or ''
        if ui.col~=key then
            ui.col=key
            pcall(function() ui.txt:SetColorAndOpacity({SpecifiedColor={R=c[1],G=c[2],B=c[3],A=1},ColorUseRule=0}) end)
        end
        if ui.hidden then ui.hidden=false; pcall(function() ui.box:SetVisibility(4) end) end
    end

    -- Taken off the HUD (the rifle put away).
    function self.hide()
        if g.valid(ui.box) then pcall(function() ui.box:RemoveFromParent() end) end
        ui.box,ui.slot,ui.img,ui.txt,ui.pad,ui.text,ui.col=nil,nil,nil,nil,nil,nil,nil
        ui.retry=nil
    end

    return self
end

return Dpad
