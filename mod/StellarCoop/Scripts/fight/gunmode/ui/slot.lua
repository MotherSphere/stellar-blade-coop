-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's D-pad rifle slot: a group of the kit (ui/kit/kit.lua) beside SB's D-pad marker while the rifle is out. It is
-- drawn on this player's screen only; nothing of it goes over the link. Its part is SB's own item slot leaf
-- (WB_MainHUD_ItemSlotGeneral_C, the widget that draws the icon and count of each D-pad item), fed through its
-- BlueprintCallable Set(Tex) and UpdateItemCount(ItemCount, bInfinity) once it is in the group. It draws at render scale
-- 0.6, as SB draws its item column (VB_ItemSlot). Its TextBlock_Item_Count reads "rounds | magazines"
-- (fight/gunmode/ammo.lua's lower_text). The icon is the NIKKE rifle's texture (the Asset2D of ItemTable's row
-- Nikke_AR), held for the game run by the keep (core/keep.lua) so a map change never frees it. Without the keep it is
-- looked up by its path each time a part is made, never on a frame. The leaf's class is warmed through kit.warm_part.
-- When kit.part refuses, the group's own image and a text in the num style stand in. kit.part is tried again at each
-- new kit build. Without the icon only the text shows. A root rebuild (a map change, a look rebuild, a group added
-- later) leaves the part behind: it is made again at the next show. The kit's pause (SB's
-- pause or one of its screens with the mouse cursor) is read every 0.25 s and hides it; fight/gunmode/mode.lua hides
-- it at a pause, in the photo mode and at every put-away. Each frame writes only numbers that changed.
local Keep=require('core.keep')
local Slot={}
Slot.GROUP='gun_slot'
Slot.CLASS='/Game/Art/UI/Widget/HUD/WB_MainHUD_ItemSlotGeneral.WB_MainHUD_ItemSlotGeneral_C'
Slot.ICON='/Game/DLC_2/Art/UI/texture/HiddenReward/Icon/Icon_Nikke_LostItem_AssaultRifle.Icon_Nikke_LostItem_AssaultRifle'
Slot.SCALE=0.6
local W,H,ICON=420,240,154 -- The group's box; the stand-in icon's side (the leaf's 256 brush at 0.6), layout units.
local CHECK=0.25 -- s between two reads of the kit's pause.

local function valid(o)
    if o==nil then return false end
    local ok,r=pcall(function() return o:IsValid() end)
    return ok and r==true
end

-- o: {kit (ui/kit/kit.lua's), theme (its THEME), log, x, y (the group's top left in layout units)}. Returns show(text,
-- color, rounds) and hide(): the shape fight/gunmode/ammo.lua's Ammo.new takes as its D-pad slot.
function Slot.new(o)
    local kit,log,theme=o.kit,o.log,o.theme
    local self={}
    local said={}
    local view,part,mode=nil,nil,nil -- The kit build's view, the part's record, 'part' or 'kit' once made for it.
    local up,check_at,blocked=false,-1,false
    local last_text,last_color=nil,nil
    Keep.want({Slot.ICON})
    kit.warm_part(Slot.CLASS:sub(1,-3))
    kit.add(Slot.GROUP,{x=o.x,y=o.y,w=W,h=H,fixed=true},function(b)
        -- The stand-ins, hidden until a show needs them: an image with no asset draws a flat square.
        local v={icon=b.image(0,0,ICON,ICON,nil,theme.white),
            count=b.text(ICON+16,ICON/2,'','num',theme.text,{X=0,Y=0.5})}
        v.icon.show(false)
        v.count.show(false)
        return v
    end)
    local function once(key,line) if not said[key] then said[key]=true; log('slot: '..line) end end
    -- The rifle's texture: the keep's while it serves it, else by its path (found in memory, else loaded). nil (said
    -- once) when neither.
    local function icon()
        local ok,t=pcall(function()
            if Keep.serves(Slot.ICON) then return Keep.get(Slot.ICON) end
            local x=StaticFindObject(Slot.ICON)
            if not valid(x) then pcall(LoadAsset,Slot.ICON); x=StaticFindObject(Slot.ICON) end
            return valid(x) and x or nil
        end)
        if ok and t then return t end
        once('icon','no rifle icon ('..(ok and 'not found' or tostring(t))..'): the counts show alone')
    end
    -- The part for this kit build, else the stand-ins. mode stays nil while the kit is not up.
    local function make(v)
        part,mode=nil,nil
        local t=icon()
        if t then -- Tried at each new kit build: a refusal said once does not stop the next build's try.
            local rec,why=kit.part(Slot.GROUP,Slot.CLASS,0,0,nil,nil,function(w)
                w:SetRenderTransformPivot({X=0,Y=0})
                w:SetRenderScale({X=Slot.SCALE,Y=Slot.SCALE})
            end)
            if not rec and why:find('not up',1,true) then return end
            if rec then
                -- Set after the part is in the group: its Construct has run by then.
                local w=kit.alive(rec)
                local ok,e=pcall(function() w:Set(t) end)
                if ok then part,mode=rec,'part'; return end
                kit.drop(rec)
                why='Set refused: '..tostring(e)
            end
            once('part',tostring(why)..'; the kit image and text stand in')
        end
        v.icon.show(t~=nil and v.icon.texture(t))
        v.count.show(true)
        mode='kit'
    end
    local function write(text,color,rounds)
        if mode=='part' then
            local w=kit.alive(part)
            if not w then mode=nil; return false end
            local ok,e=pcall(function()
                w:UpdateItemCount(rounds,false)
                w.TextBlock_Item_Count:SetText(FText(text))
                w.TextBlock_Item_Count:SetColorAndOpacity({SpecifiedColor={R=color[1],G=color[2],B=color[3],A=1},
                    ColorUseRule=0})
            end)
            if not ok then once('count','count refused: '..tostring(e)) end
        else
            view.count.set(text)
            view.count.color({R=color[1],G=color[2],B=color[3],A=1})
        end
        return true
    end
    -- Each frame while the rifle is out. text: "rounds | magazines"; color: {r, g, b}; rounds: in the magazine.
    function self.show(text,color,rounds)
        local now=os.clock()
        if now>=check_at then check_at,blocked=now+CHECK,kit.paused() end
        if blocked then self.hide(); return end
        local v=kit.view(Slot.GROUP)
        if not v then return end
        if v~=view then view,mode=v,nil end
        if mode=='part' and not up and not kit.alive(part) then mode=nil end
        if not mode then
            make(v)
            if not mode then return end
            last_text,last_color=nil,nil
        end
        if text~=last_text or color~=last_color then
            if not write(text,color,rounds) then return end
            last_text,last_color=text,color
        end
        up=true
        kit.show(Slot.GROUP,true)
    end
    function self.hide()
        up=false
        kit.show(Slot.GROUP,false)
    end
    return self
end

return Slot
