-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The HUD entry's glyph: the Right twin of the pad glyph the game shows, or the gun mode key's keyboard icon. The real
-- entry over a fake UMG: on the keyboard the key's glyph sits on the D-pad marker's own key cell (its Image btn); with
-- no such cell the entry shows none (an Image with no brush draws a white square).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local D=require('fight.gunmode.ui.dpad')
local P='/Game/Art/UI/Texture/Interaction/'
assert(D.glyph_path(P..'XB/KeyIcon_XboxOne_Gamepad_DPad_Up.KeyIcon_XboxOne_Gamepad_DPad_Up','G')
    ==P..'XB/KeyIcon_XboxOne_Gamepad_DPad_Right.KeyIcon_XboxOne_Gamepad_DPad_Right')
assert(D.glyph_path(P..'PS/KeyIcon_DualShock4_Gamepad_DPad_Up.KeyIcon_DualShock4_Gamepad_DPad_Up','G')
    ==P..'PS/KeyIcon_DualShock4_Gamepad_DPad_Right.KeyIcon_DualShock4_Gamepad_DPad_Right')
assert(D.glyph_path(P..'PC/KeyIcon_KeyBoard_Q.KeyIcon_KeyBoard_Q','G')==P..'PC/KeyIcon_KeyBoard_G.KeyIcon_KeyBoard_G')
assert(D.glyph_path(P..'PC/Something.Something','G')==nil and D.glyph_path(nil,'G')==nil)

-- A fake UMG, cut down from dev's dpad_test. An object has a class (its short name), an outer, a name and a full name
-- ("<class> <path>", its path the outer's path, a dot and its name). StaticFindObject in an outer finds a live child
-- of that name in any case, as the engine's FName lookup does. FindAllOf gives every live widget of a class.
local W
local function world()
    W={paths={},classes={}}
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
    function Obj.IsA(o,c) return c.short==o.class or c.short=='Widget' or (c.short=='UserWidget' and o.user==true) end
    local function add(p,c) p.kids[#p.kids+1]=c; return any() end
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
    for _,c in ipairs({'Widget','UserWidget','Overlay','Image','TextBlock','HorizontalBox','SizeBox'}) do
        W.classes['/Script/UMG.'..c]={short=c}
    end
    StaticFindObject=function(a,outer,name)
        if outer==nil then return W.paths[a] or W.classes[a] end
        local o=outer.named and outer.named[name:lower()]
        if o and not o.dead and o:IsA(a) then return o end
    end
    StaticConstructObject=function(cls,outer,name) return W.new(cls.short,outer,name) end
    FindAllOf=function(class)
        local out={}
        for _,o in pairs(W.paths) do
            if not o.dead and (o.class==class or (o.kids and o:IsA({short=class}))) then out[#out+1]=o end
        end
        return out
    end
    FName=function(s) return s end
    FText=function(s) return s end
    LoadAsset=function() end
    W.icon=W.new('Texture2D',nil,D.ICON)
    W.kq=W.new('Texture2D',nil,P..'PC/KeyIcon_KeyBoard_Q.KeyIcon_KeyBoard_Q')
    W.kg=W.new('Texture2D',nil,P..'PC/KeyIcon_KeyBoard_G.KeyIcon_KeyBoard_G')
    W.cell_tex=W.new('Texture2D',nil,'/Game/Art/UI/Texture/HUD/btn_PcEmpty.btn_PcEmpty')
end
-- SB's HUD on screen with its D-pad marker, the marker's parts named as in the paks (btn: its key cell).
local function hud()
    local inst=W.new('GameInstance',nil,'/Engine/Transient.GameEngine_0:Instance_0')
    local h=W.new('WB_MainHUD_Master_C',inst,'WB_MainHUD_Master_C_1',{user=true,viewport=true})
    local ht=W.new('WidgetTree',h,'WidgetTree'); h.WidgetTree=ht
    h.heal=W.new('WB_MainHUD_ItemSlot_C',ht,'WB_MainHUD_HealItem',{user=true,size={X=256,Y=256}})
    local dpad=W.new('WB_MainHUD_Dpad_C',ht,'WB_MainHUD_Dpad',{user=true,size={X=256,Y=256}})
    local dt=W.new('WidgetTree',dpad,'WidgetTree'); dpad.WidgetTree=dt
    h.overlay=W.new('Overlay',dt,'Overlay_0')
    h.up=W.new('Image',dt,'btn_up',{Brush={ResourceObject=W.kq,ImageSize={X=150,Y=150}}})
    W.new('Overlay',dt,'Overlay_ps',{vis=1})
    h.cell=W.new('Image',dt,'btn',{Brush={ResourceObject=W.cell_tex}})
    return h
end
local function key_of(h)
    local key=h.overlay.named.gunmoderifleslot.named.gunmoderiflekey.named
    return key.gunmoderiflekeycell,key.gunmoderiflekeyglyph
end
local function new_g(logs)
    local g={log=function(m) logs[#logs+1]=m end}
    function g.valid(o) if o==nil then return false end local ok,r=pcall(function() return o:IsValid() end); return ok and r==true end
    function g.try(f) local ok,r=pcall(f); if ok then return r end end
    return g
end
-- One tick with the keyboard and key G: the entry's key cell, its glyph and the log. prep(h) changes the HUD first.
local function entry(no_cell,prep)
    world()
    local h=hud()
    if no_cell then h.cell.dead=true end
    if prep then prep(h) end
    local logs={}
    D.new(new_g(logs)).tick('G','60 | 5',{1,1,1})
    local cell,glyph=key_of(h)
    return h,cell,glyph,table.concat(logs,'\n')
end
do
    local h,cell,glyph,log=entry()
    assert(glyph.tex==W.kg and glyph.vis~=1,'the G key icon')
    assert(cell.brush==h.cell.Brush and cell.vis==4,'the G icon on the marker\'s key cell: '..tostring(cell.brush)..' '..cell.vis)
    assert(log:find('dpad: rifle entry built, key cell found',1,true),log)
end
do
    local _,cell,glyph,log=entry(true)
    assert(glyph.tex==W.kg,'the G key icon without the cell too')
    assert(cell.vis==1,'no cell shown without the marker\'s: an empty Image is a white square')
    assert(log:find('dpad: rifle entry built, key cell not found',1,true),log)
end
-- The marker's up button with no texture yet: no glyph is known, so the cell stays collapsed.
do
    local _,cell=entry(false,function(h) h.up.Brush.ResourceObject=nil end)
    assert(cell.vis==1,'no cell shown before a glyph is known: '..cell.vis)
end
-- A new HUD (map change): SB frees the first one, the entry is built again 0.3 s after the last follow. The new
-- widgets get the G glyph, the cell, the sizes and the place in that same tick. The new HUD's key and icon have the
-- entry's default sizes (Dpad.KEY_SIZE, Dpad.ICON_SIZE), so no size change asks for the sizing.
local clock=os.clock
for _,no_cell in ipairs({false,true}) do
    local now=0
    os.clock=function() return now end
    world()
    local h=hud()
    if no_cell then h.cell.dead=true end
    local logs={}
    local d=D.new(new_g(logs))
    for _,t in ipairs({0,1.8}) do now=t; d.tick('G','60 | 5',{1,1,1}) end
    for _,o in pairs(W.paths) do if o.class~='Texture2D' then o.dead=true end end
    local h2=hud()
    if no_cell then h2.cell.dead=true end
    h2.up.Brush.ImageSize={X=D.KEY_SIZE,Y=D.KEY_SIZE}; h2.heal.size={X=D.ICON_SIZE,Y=D.ICON_SIZE}
    now=2.1; d.tick('G','60 | 5',{1,1,1})
    local cell,glyph=key_of(h2)
    local log=table.concat(logs,'\n')
    assert(glyph.tex==W.kg,'the G key icon on the new HUD')
    if no_cell then assert(cell.vis==1,'no cell on the new HUD without the marker\'s: '..cell.vis)
    else assert(cell.brush==h2.cell.Brush and cell.vis==4,'the new HUD\'s key cell: '..tostring(cell.brush)..' '..cell.vis) end
    assert(cell.bsize and cell.bsize.X==D.KEY_SIZE*1.25,'the cell sized from btn_up on the new HUD')
    local _,placed=log:gsub('dpad: placed ','')
    assert(placed==2,'placed on each HUD: '..log)
end
os.clock=clock
print('gunmode dpad_test ok')
