-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The HUD entry's glyph: the Right twin of the pad glyph the game shows, or the gun mode key's keyboard icon. The real
-- entry over a fake UMG: on the keyboard the key's glyph sits on the D-pad marker's own key cell (its Image btn); with
-- no such cell the entry shows none (an Image with no brush draws a white square). After a map change or a Lua reload
-- the entry touches only its own live widgets and makes none over an earlier load's.
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
-- StaticConstructObject over a live object of the same name, class and outer replaces it in place (W.replaced), as
-- StaticAllocateObject does: the panel that held it keeps it. Panels hold their children in kids; RemoveFromParent
-- takes a widget out of its parent's. SetText counts its writes.
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
    function Obj.IsA(o,c) return c.short==o.class or c.short=='Widget' or (c.short=='UserWidget' and o.user==true) end
    function Obj.SetText(o,t) o.text=t; o.writes=(o.writes or 0)+1 end
    function Obj.RemoveFromParent(o)
        o.removed=(o.removed or 0)+1
        local p=o.parent
        if not p then return end
        for i=#p.kids,1,-1 do if p.kids[i]==o then table.remove(p.kids,i) end end
        o.parent=nil
    end
    local function add(p,c) p.kids[#p.kids+1]=c; c.parent=p; return any() end
    Obj.AddChildToOverlay,Obj.AddChildToHorizontalBox,Obj.AddChildToCanvas,Obj.AddChild=add,add,add,add
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
    FText=function(s) return s end
    LoadAsset=function() end
    W.icon=W.new('Texture2D',nil,D.ICON)
    W.kq=W.new('Texture2D',nil,P..'PC/KeyIcon_KeyBoard_Q.KeyIcon_KeyBoard_Q')
    W.kg=W.new('Texture2D',nil,P..'PC/KeyIcon_KeyBoard_G.KeyIcon_KeyBoard_G')
    W.cell_tex=W.new('Texture2D',nil,'/Game/Art/UI/Texture/HUD/btn_PcEmpty.btn_PcEmpty')
end
-- SB's HUD on screen with its D-pad marker, the marker's parts named as in the paks (btn: its key cell). n: the HUD's
-- number in its name (1 unless given).
local function hud(n)
    local inst=W.new('GameInstance',nil,'/Engine/Transient.GameEngine_0:Instance_0')
    local h=W.new('WB_MainHUD_Master_C',inst,'WB_MainHUD_Master_C_'..(n or 1),{user=true,viewport=true})
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
    function g.valid(o)
        if o==nil then return false end
        local ok,r=pcall(function() return o:IsValid() end); return ok and r==true
    end
    function g.try(f) local ok,r=pcall(f); if ok then return r end end
    -- gun mode's other calls as fight/gunmode/mode.lua makes them, over the fake's objects
    function g.path(o)
        local f=g.valid(o) and o:GetFullName(); return type(f)=='string' and f:match('^%S+ (.+)$') or nil
    end
    function g.cdo(p) return W.classes[p] end
    function g.get(o,k) local ok,r=pcall(function() return o[k] end); if ok then return r end end
    function g.asset(p) return W.paths[p] end
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
local now
-- The walks of the object array: FindAllOf of each class, counted. One walk builds the entry, the look for the HUD on
-- screen; its parts are found by name in the HUD's widget trees (ed6385e6). ticks(d,n): n ticks 0.1 s apart.
local walks
local function counted()
    walks={}
    local all=FindAllOf
    FindAllOf=function(class) walks[class]=(walks[class] or 0)+1; return all(class) end
end
local function ticks(d,n) for _=1,n do now=now+0.1; d.tick('G','60 | 5',{1,1,1}) end end
local function said(logs,text)
    local n=0
    for _,m in ipairs(logs) do if m:find(text,1,true) then n=n+1 end end
    return n
end
-- 1. Built in the HUD on screen with one walk, nothing walked again while it lives (30 s). The crosshair goes on the
--    HUD the entry was built in, with no walk.
do
    now=0; os.clock=function() return now end
    world(); counted()
    W.classes['/Script/UMG.CanvasPanel']={short='CanvasPanel'}
    local h=hud()
    h.WidgetTree.RootWidget=W.new('CanvasPanel',h.WidgetTree,'CanvasPanel_Root')
    local logs={}
    local d=D.new(new_g(logs))
    ticks(d,300)
    assert(h.overlay.named.gunmoderifleholder,'built')
    assert(walks.WB_MainHUD_Master_C==1,tostring(walks.WB_MainHUD_Master_C)..' looks for the HUD in 30 s')
    local n=0; for _,c in pairs(walks) do n=n+c end
    assert(n==1,n..' walks in 30 s')
    assert(said(logs,'dpad: rifle entry built, key cell found (HUD from a look)')==1,table.concat(logs,'\n'))
    d.crosshair(true)
    assert(h.WidgetTree.RootWidget.named.gunmodecrosshair,'the crosshair on the HUD\'s canvas')
    n=0; for _,c in pairs(walks) do n=n+c end
    assert(n==1,n..' walks after the crosshair')
end
-- 2. No HUD on screen (the title, a load): a look every Dpad.RETRY s, one log line.
do
    now=0
    world(); counted()
    local logs={}
    local d=D.new(new_g(logs))
    ticks(d,305) -- 30.5 s
    assert(walks.WB_MainHUD_Master_C==4,tostring(walks.WB_MainHUD_Master_C)..' looks in 30.5 s')
    assert(said(logs,'dpad: no HUD in the viewport')==1,table.concat(logs,'\n'))
end
-- 3. A HUD without the item column: tried once and logged once, a look every Dpad.RETRY s. A new HUD is tried.
do
    now=0
    world(); counted()
    local h=hud()
    h.overlay.dead=true
    local logs={}
    local d=D.new(new_g(logs))
    ticks(d,305)
    assert(said(logs,'not built')==1,said(logs,'not built')..' "not built" lines in 30 s')
    assert(walks.WB_MainHUD_Master_C==4,tostring(walks.WB_MainHUD_Master_C)..' looks in 30.5 s')
    for _,o in pairs(W.paths) do if o.class~='Texture2D' then o.dead=true end end
    local h2=hud(2)
    ticks(d,100)
    assert(h2.overlay.named and h2.overlay.named.gunmoderifleholder,'the next HUD is tried')
end
-- 4. The pad: its layer up, the loaded pad glyph looked for once (none loaded: still once), again when the layer
--    comes up again (0e51255f). Its Right twin then shows, without the key cell. Once found it is kept for the HUD: a
--    switch to the keyboard and back walks no more.
do
    now=0
    world(); counted()
    local h=hud()
    local pad=h.overlay.outer.named.overlay_ps
    local d=D.new(new_g({}))
    ticks(d,10)
    pad.vis=4
    ticks(d,30)
    assert(walks.Texture2D==1,'one glyph walk while the pad layer stays up: '..tostring(walks.Texture2D))
    W.new('Texture2D',nil,P..'XB/KeyIcon_XboxOne_Gamepad_DPad_Up.KeyIcon_XboxOne_Gamepad_DPad_Up')
    local xb_right=W.new('Texture2D',nil,P..'XB/KeyIcon_XboxOne_Gamepad_DPad_Right.KeyIcon_XboxOne_Gamepad_DPad_Right')
    pad.vis=1; ticks(d,10)
    pad.vis=4; ticks(d,10)
    assert(walks.Texture2D==2,'again when the layer comes up again: '..tostring(walks.Texture2D))
    local cell,glyph=key_of(h)
    assert(glyph.tex==xb_right and cell.vis==1,'the pad\'s D-pad Right, no key cell')
    for _=1,3 do pad.vis=1; ticks(d,10); pad.vis=4; ticks(d,10) end
    assert(walks.Texture2D==2,'a walk at each switch to the pad: '..tostring(walks.Texture2D))
    assert(glyph.tex==xb_right,'the pad\'s D-pad Right kept')
end
-- 5. The keep holds SB's HUD class: its Construct is hooked once (gun mode's g.hook_hud, d2de021b). A HUD seen by its
--    Construct gets the entry at the first tick it is on screen, with no walk. Once the entry is taken off (coop off),
--    a Construct makes no engine call. A hook that cannot be registered: one line, tried once, the looks go on.
do
    now=0
    world(); counted()
    local Keep=require('core.keep')
    local serves=Keep.serves
    Keep.serves=function(p) return p==D.HUD end
    local hooks={}
    local logs={}
    local g=new_g(logs)
    g.hook_hud=function(p,cb) hooks[#hooks+1]={p,cb} end
    local d=D.new(g)
    ticks(d,1) -- the title: no HUD yet
    assert(#hooks==1 and hooks[1][1]==D.HUD,'the Construct hooked once: '..#hooks)
    assert(walks.WB_MainHUD_Master_C==1,'one look at the title')
    local h=hud(); h.viewport=false
    hooks[1][2]({get=function() return h end})
    ticks(d,5)
    assert(not h.overlay.named,'nothing built before the HUD is on screen')
    h.viewport=true
    ticks(d,1)
    assert(h.overlay.named.gunmoderifleholder and said(logs,'(HUD from its Construct)')==1,'built at once')
    assert(walks.WB_MainHUD_Master_C==1 and #hooks==1,'no walk for it: '..walks.WB_MainHUD_Master_C)
    d.hide()
    local read=false
    hooks[1][2]({get=function() read=true end})
    assert(not read,'no engine call from a Construct once the entry is taken off')
    world(); counted()
    local tries=0
    logs={}
    g=new_g(logs)
    g.hook_hud=function() tries=tries+1; error('no such function',0) end
    d=D.new(g)
    ticks(d,1)
    local h2=hud()
    ticks(d,110)
    assert(tries==1 and said(logs,'dpad: no Construct hook: no such function')==1,tries..' tries')
    assert(h2.overlay.named.gunmoderifleholder,'built by a look')
    Keep.serves=serves
end
-- 6. Another object at the old address (a freed HUD): it passes IsValid but gets no write. The entry is built anew in
--    the next HUD (ed6385e6).
do
    now=0
    world(); counted()
    local h=hud()
    local d=D.new(new_g({}))
    ticks(d,10)
    local box=h.overlay.named.gunmoderifleslot
    local txt=box.named.gunmoderiflecount
    for _,o in pairs(W.paths) do if o.class~='Texture2D' then o.dead=true end end
    box.full,box.dead='HorizontalBox /Engine/Transient.Other_C_9.HorizontalBox_3',false -- other widgets there
    h.overlay.full,h.overlay.dead='Overlay /Engine/Transient.Other_C_9.Overlay_2',false
    txt.full,txt.dead,txt.writes='TextBlock /Engine/Transient.Other_C_9.TextBlock_7',false,0
    local h2=hud(2)
    ticks(d,30)
    assert(txt.writes==0,'no write to another object at the old address: '..txt.writes)
    assert(h2.overlay.named and h2.overlay.named.gunmoderifleholder,'the entry built anew in the next HUD')
end
-- 7. A Lua reload (Ctrl+R): a new load's entry over the live HUD takes the earlier load's widgets again. Nothing is
--    made over a live widget. The marker's overlay holds the entry once. The crosshair the same way (ed6385e6).
do
    now=0
    world(); counted()
    W.classes['/Script/UMG.CanvasPanel']={short='CanvasPanel'}
    local h=hud()
    local root=W.new('CanvasPanel',h.WidgetTree,'CanvasPanel_Root')
    h.WidgetTree.RootWidget=root
    local d=D.new(new_g({}))
    ticks(d,10)
    d.crosshair(true)
    local cross=root.named.gunmodecrosshair
    assert(cross and cross.vis==3 and #cross.kids==5,'the crosshair: 4 bars and a dot')
    local again=D.new(new_g({}))
    ticks(again,10)
    again.crosshair(true)
    assert(W.replaced==0,W.replaced..' widgets made over live ones')
    local holder=h.overlay.named.gunmoderifleholder
    assert(#h.overlay.kids==1 and h.overlay.kids[1]==holder and #holder.kids==1,'the entry once in the overlay')
    assert(#root.kids==1 and #cross.kids==5,'the crosshair once on the root')
    assert(h.overlay.named.gunmoderifleslot.named.gunmoderiflecount.text=='60 | 5')
    again.crosshair(false)
    assert(cross.vis==1,'the crosshair off')
end
-- 8. hide (coop off): the entry and the crosshair off the HUD. A freed entry whose address another object took is not
--    touched (ed6385e6).
do
    now=0
    world(); counted()
    W.classes['/Script/UMG.CanvasPanel']={short='CanvasPanel'}
    local h=hud()
    local root=W.new('CanvasPanel',h.WidgetTree,'CanvasPanel_Root')
    h.WidgetTree.RootWidget=root
    local d=D.new(new_g({}))
    ticks(d,10)
    d.crosshair(true)
    d.hide()
    assert(#h.overlay.kids==0 and #root.kids==0,'the entry and the crosshair off the HUD')
    world(); counted()
    h=hud()
    d=D.new(new_g({}))
    ticks(d,10)
    local holder=h.overlay.named.gunmoderifleholder
    holder.full='SizeBox /Engine/Transient.Other_C_9.SizeBox_1' -- another widget at its address
    d.hide()
    assert((holder.removed or 0)==0,'no call on another object at the old address')
end
os.clock=clock
print('gunmode dpad_test ok')
