-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Copied from tests/lua/fight/gunmode/dpad_test.lua (November 2026), cut to the closet's entry.
-- The closet's HUD entry: the LB and D-pad Left twins of the pad glyph the game shows (the LB + D-pad Left chord), or
-- the closet key's keyboard icon, then the hanger icon, right of gun mode's entry. The real entry over a fake UMG: on
-- the keyboard the key's glyph sits on the D-pad marker's own key cell; with no such cell or no closet key the entry
-- shows none (an Image with no brush draws a white square). A pad shows both glyphs or none, never D-pad Left alone.
-- After a Lua reload the entry takes an earlier load's widgets again and makes none over them.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local H=require('closet.ui.hud')
local P='/Game/Art/UI/Texture/Interaction/'
-- A pad glyph's path as the paks of 26123051 name it: folder, pad, button.
local function pad(dir,name,button)
    local n='KeyIcon_'..name..'_Gamepad_'..button
    return P..dir..'/'..n..'.'..n
end
local left,lb=H.glyph_path(pad('XBOX','XboxOne','DPad_Up'),'F1')
assert(left==pad('XBOX','XboxOne','DPad_Left') and lb==pad('XBOX','XboxOne','LeftShoulder'),
    'the pad\'s D-pad Left, then its LB: '..tostring(left)..' '..tostring(lb))
left,lb=H.glyph_path(pad('DualShock','DualShock4','DPad_Up'),nil)
assert(left==pad('DualShock','DualShock4','DPad_Left') and lb==pad('DualShock','DualShock4','LeftShoulder'),
    'the pad glyphs with no key')
left,lb=H.glyph_path(P..'PC/KeyIcon_KeyBoard_Q.KeyIcon_KeyBoard_Q','F1')
assert(left==P..'PC/KeyIcon_KeyBoard_F1.KeyIcon_KeyBoard_F1' and lb==nil,'one glyph on the keyboard')
assert(H.glyph_path(P..'PC/KeyIcon_KeyBoard_Q.KeyIcon_KeyBoard_Q',nil)==nil,'no keyboard glyph with no closet key')
assert(H.glyph_path(P..'PC/Something.Something','F1')==nil and H.glyph_path(nil,'F1')==nil)
assert(H.ICON_FILE:find('closet[\\/]ui[\\/]icons[\\/]full_outfit%.png$'),H.ICON_FILE)
assert(require('closet.slots').glyph(require('closet.slots').FULL_OUTFIT)==H.ICON,'the Full outfit slot\'s glyph')

-- A fake UMG, as dpad_test's. An object has a class (its short name), an outer, a name and a full name ("<class>
-- <path>"). StaticFindObject in an outer finds a live child of that name in any case. StaticConstructObject over a
-- live object of the same name, class and outer replaces it in place (W.replaced). Panels hold their children in kids.
local W
local function world()
    W={paths={},classes={},replaced=0}
    local function path_of(o) return o.outer and (path_of(o.outer)..'.'..o.name) or o.name end
    local any=function() return setmetatable({},{__index=function() return function() end end}) end
    local Obj={}
    Obj.__index=function(o,k)
        local m=rawget(Obj,k)
        if m or type(k)~='string' or not k:match('^%u') then return m end
        return any -- every other engine call answers a slot that takes any call
    end
    function Obj.IsValid(o) return not o.dead end
    function Obj.GetFullName(o) return o.full end
    function Obj.GetVisibility(o) return o.vis end
    function Obj.SetVisibility(o,v) o.vis=v end
    function Obj.GetDesiredSize(o) return o.size or {X=0,Y=0} end
    function Obj.IsInViewport(o) return o.viewport==true end
    function Obj.SetBrushFromTexture(o,t) o.tex=t end
    function Obj.SetBrush(o,b) o.brush=b end
    function Obj.SetBrushSize(o,s) o.bsize=s end
    function Obj.SetRenderTranslation(o,t) o.at=t end
    function Obj.IsA(o,c) return c.short==o.class or c.short=='Widget' or (c.short=='UserWidget' and o.user==true) end
    function Obj.RemoveFromParent(o)
        o.removed=(o.removed or 0)+1
        local p=o.parent
        if not p then return end
        for i=#p.kids,1,-1 do if p.kids[i]==o then table.remove(p.kids,i) end end
        o.parent=nil
    end
    local function add(p,c) p.kids[#p.kids+1]=c; c.parent=p; return any() end
    Obj.AddChildToOverlay,Obj.AddChildToHorizontalBox,Obj.AddChild=add,add,add
    function W.new(class,outer,name,t)
        local o=t or {}
        o.class,o.outer,o.name,o.kids=class,outer,name,{}
        o.vis=o.vis or 0
        o.full=class..' '..path_of(o)
        W.paths[path_of(o)]=o
        if outer then outer.named=outer.named or {}; outer.named[name:lower()]=o end
        return setmetatable(o,Obj)
    end
    for _,c in ipairs({'Widget','UserWidget','Overlay','Image','HorizontalBox','SizeBox'}) do
        W.classes['/Script/UMG.'..c]={short=c}
    end
    StaticFindObject=function(a,outer,name)
        if outer==nil then return W.paths[a] or W.classes[a] end
        local o=outer.named and outer.named[name:lower()]
        if o and not o.dead and o:IsA(a) then return o end
    end
    StaticConstructObject=function(cls,outer,name)
        local old=outer.named and outer.named[name:lower()]
        if old and not old.dead and old.class==cls.short then
            W.replaced=W.replaced+1 -- destroyed and built again at the same address: its parent still holds it
            old.kids={}
            return old
        end
        return W.new(cls.short,outer,name)
    end
    FindAllOf=function(class)
        local out={}
        for _,o in pairs(W.paths) do
            if not o.dead and (o.class==class or (o.kids and o:IsA({short=class}))) then out[#out+1]=o end
        end
        return out
    end
    FName=function(s) return s end
    W.hanger=W.new('Texture2D',nil,'/Engine/Transient.Texture2D_0')
    W.kq=W.new('Texture2D',nil,P..'PC/KeyIcon_KeyBoard_Q.KeyIcon_KeyBoard_Q')
    W.kf1=W.new('Texture2D',nil,P..'PC/KeyIcon_KeyBoard_F1.KeyIcon_KeyBoard_F1')
    W.cell_tex=W.new('Texture2D',nil,'/Game/Art/UI/Texture/HUD/btn_PcEmpty.btn_PcEmpty')
end
-- SB's HUD on screen with its D-pad marker, the marker's parts named as in the paks (btn: its key cell).
local function hud(n)
    local inst=W.new('GameInstance',nil,'/Engine/Transient.GameEngine_0:Instance_0')
    local h=W.new('WB_MainHUD_Master_C',inst,'WB_MainHUD_Master_C_'..(n or 1),{user=true,viewport=true})
    local ht=W.new('WidgetTree',h,'WidgetTree'); h.WidgetTree=ht
    h.heal=W.new('WB_MainHUD_ItemSlot_C',ht,'WB_MainHUD_HealItem',{user=true,size={X=40,Y=40}})
    local dpad=W.new('WB_MainHUD_Dpad_C',ht,'WB_MainHUD_Dpad',{user=true,size={X=100,Y=80}})
    local dt=W.new('WidgetTree',dpad,'WidgetTree'); dpad.WidgetTree=dt
    h.overlay=W.new('Overlay',dt,'Overlay_0')
    h.up=W.new('Image',dt,'btn_up',{Brush={ResourceObject=W.kq,ImageSize={X=32,Y=32}}})
    h.pad=W.new('Overlay',dt,'Overlay_ps',{vis=1})
    h.cell=W.new('Image',dt,'btn',{Brush={ResourceObject=W.cell_tex}})
    return h
end
local function parts(h)
    local box=h.overlay.named.closetslot
    local key=box.named.closetkey.named
    return key.closetkeycell,key.closetkeyglyph,box.named.closeticon,box,box.named.closetpadlb
end
local function new_g(logs)
    local g={log=function(m) logs[#logs+1]=m end}
    function g.valid(o)
        if o==nil then return false end
        local ok,r=pcall(function() return o:IsValid() end); return ok and r==true
    end
    function g.try(f) local ok,r=pcall(f); if ok then return r end end
    function g.path(o)
        local f=g.valid(o) and o:GetFullName(); return type(f)=='string' and f:match('^%S+ (.+)$') or nil
    end
    function g.cdo(p) return W.classes[p] end
    function g.get(o,k) local ok,r=pcall(function() return o[k] end); if ok then return r end end
    function g.asset(p) return W.paths[p] end
    function g.import(file) g.imported=file; return W.hanger end
    return g
end
local clock=os.clock
local now=0
os.clock=function() return now end
local function ticks(d,n,key) for _=1,n do now=now+0.1; d.tick(key) end end
local function said(logs,text)
    local n=0
    for _,m in ipairs(logs) do if m:find(text,1,true) then n=n+1 end end
    return n
end

-- 1. The keyboard with F1: the F1 icon on the marker's key cell, the hanger icon from icons/full_outfit.png, the row
--    right of gun mode's entry and its rounds text, on gun mode's row.
do
    now=0; world()
    local h=hud()
    local logs={}
    local g=new_g(logs)
    local d=H.new(g)
    ticks(d,1,'F1')
    local cell,glyph,img,box,lb=parts(h)
    assert(glyph.tex==W.kf1 and glyph.vis==4,'the F1 key icon')
    assert(lb.vis==1 and not lb.tex,'no LB glyph on the keyboard')
    assert(cell.brush==h.cell.Brush and cell.vis==4,'the F1 icon on the marker\'s key cell')
    assert(img.tex==W.hanger and img.vis==4 and g.imported==H.ICON_FILE,'the hanger icon')
    assert(said(logs,'hud: closet entry built, key cell found')==1,table.concat(logs,'\n'))
    -- marker 100 wide, key 32 (cell 40), icon 40: 100+6+(40+6+40)+TEXT_ROOM+SPACE
    local x=100+H.GAP+(32*1.25+H.GAP+40)+H.TEXT_ROOM+H.SPACE
    assert(box.at and math.abs(box.at.X-x)<0.01 and box.at.Y==80*H.DOWN,'placed right of the gun entry: '
        ..tostring(box.at and box.at.X))
    assert(h.overlay.named.closetholder and not h.overlay.named.gunmoderifleslot,'Closet-named widgets only')
end
-- 2. No closet key (none): the keyboard shows neither glyph nor key cell. The pad shows its LB, then its D-pad Left.
do
    now=0; world()
    local h=hud()
    local d=H.new(new_g({}))
    ticks(d,1,nil)
    local cell,glyph,img,box,lb=parts(h)
    assert(glyph.vis==1 and cell.vis==1 and lb.vis==1,'no glyph or key cell on the keyboard without a closet key')
    local xb_left=W.new('Texture2D',nil,pad('XBOX','XboxOne','DPad_Left'))
    local xb_lb=W.new('Texture2D',nil,pad('XBOX','XboxOne','LeftShoulder'))
    W.new('Texture2D',nil,pad('XBOX','XboxOne','DPad_Up'))
    h.pad.vis=4
    ticks(d,10,nil)
    assert(glyph.tex==xb_left and glyph.vis==4,'the pad\'s D-pad Left with no closet key')
    assert(lb.tex==xb_lb and lb.vis==4,'the pad\'s LB with it')
    assert(box.kids[1]==lb and box.kids[2]==box.named.closetkey and box.kids[3]==img,'LB, D-pad Left, the hanger')
    assert(cell.vis==1,'no key cell on the pad')
end
-- 2b. A pad whose LB glyph is not found: neither pad glyph shows. D-pad Left alone is the game's, not the closet's.
do
    now=0; world()
    local h=hud()
    local logs={}
    local d=H.new(new_g(logs))
    W.new('Texture2D',nil,pad('DualShock','DualShock4','DPad_Left'))
    W.new('Texture2D',nil,pad('DualShock','DualShock4','DPad_Up'))
    h.pad.vis=4
    ticks(d,10,'F1')
    local _,glyph,_,_,lb=parts(h)
    assert(glyph.vis==1 and lb.vis==1,'no D-pad Left glyph alone')
    assert(said(logs,'hud: no glyph for '..pad('DualShock','DualShock4','LeftShoulder'))==1,table.concat(logs,'\n'))
end
-- 3. No marker key cell: the glyph shows alone, never an empty cell (a white square).
do
    now=0; world()
    local h=hud()
    h.cell.dead=true
    local logs={}
    local d=H.new(new_g(logs))
    ticks(d,1,'F1')
    local cell,glyph=parts(h)
    assert(glyph.tex==W.kf1 and cell.vis==1,'no cell shown without the marker\'s')
    assert(said(logs,'key cell not found')==1,table.concat(logs,'\n'))
end
-- 4. No controller yet: the hanger stays collapsed and is imported at a later follow.
do
    now=0; world()
    local h=hud()
    local g=new_g({})
    local import=g.import
    g.import=function() return nil end
    local d=H.new(g)
    ticks(d,1,'F1')
    local _,_,img=parts(h)
    assert(img.vis==1 and not img.tex,'no hanger before a controller: no white square')
    g.import=import
    ticks(d,6,'F1')
    assert(img.tex==W.hanger and img.vis==4,'the hanger once it imports')
end
-- 5. A Lua reload (Ctrl+R): a new load's entry takes the earlier load's widgets again. Nothing is made over a live
--    widget. The marker's overlay holds the entry once.
do
    now=0; world()
    local h=hud()
    local d=H.new(new_g({}))
    ticks(d,10,'F1')
    local again=H.new(new_g({}))
    ticks(again,10,'F1')
    assert(W.replaced==0,W.replaced..' widgets made over live ones')
    local holder=h.overlay.named.closetholder
    assert(#h.overlay.kids==1 and h.overlay.kids[1]==holder and #holder.kids==1,'the entry once in the overlay')
end
-- 6. hide (coop off): the entry off the HUD, never built again by a later tick. A freed entry whose address another
--    object took is not touched.
do
    now=0; world()
    local h=hud()
    local d=H.new(new_g({}))
    ticks(d,10,'F1')
    d.hide()
    assert(#h.overlay.kids==0,'the entry off the HUD')
    ticks(d,40,'F1')
    assert(#h.overlay.kids==0,'not built again after hide')
    world()
    h=hud()
    d=H.new(new_g({}))
    ticks(d,10,'F1')
    local holder=h.overlay.named.closetholder
    holder.full='SizeBox /Engine/Transient.Other_C_9.SizeBox_1' -- another widget at its address
    d.hide()
    assert((holder.removed or 0)==0,'no call on another object at the old address')
end
-- 7. The keep holds SB's HUD class: its Construct is hooked once through g.hook_hud. A HUD seen by its Construct gets
--    the entry at the first tick it is on screen, with no walk.
do
    now=0; world()
    local Keep=require('core.keep')
    local serves=Keep.serves
    Keep.serves=function(p) return p==H.HUD end
    local hooks,walks={},0
    local all=FindAllOf
    FindAllOf=function(c) if c=='WB_MainHUD_Master_C' then walks=walks+1 end; return all(c) end
    local logs={}
    local g=new_g(logs)
    g.hook_hud=function(p,cb) hooks[#hooks+1]={p,cb} end
    local d=H.new(g)
    ticks(d,1,'F1')
    assert(#hooks==1 and hooks[1][1]==H.HUD,'the Construct hooked once')
    local h=hud()
    hooks[1][2]({get=function() return h end})
    ticks(d,1,'F1')
    assert(h.overlay.named.closetholder and said(logs,'(HUD from its Construct)')==1,'built at once')
    assert(walks==1 and #hooks==1,'no walk for it: '..walks)
    Keep.serves=serves
end
os.clock=clock
print('closet hud_test ok')
