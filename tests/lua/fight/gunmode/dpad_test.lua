-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's HUD entry (fight/gunmode/ui/dpad.lua). Its glyph: the Right twin of the pad glyph the game shows, or the
-- gun mode key's keyboard icon. The real entry over a fake UMG (SB's HUD as the paks name its widgets): built with one
-- walk (the look for the HUD) and one name not found (the look for an earlier load's row), the crosshair with one
-- name not found too; placed and sized, the key's glyph on the key cell, none with gun_key=none; built anew in
-- a new HUD with nothing of the old one kept; a widget whose address another object took gets no write; after a Lua
-- reload the earlier load's widgets are taken again, never made over; a HUD without the item column is tried once;
-- the pad glyph walk once each time the pad layer comes up; the crosshair on the HUD's root without a walk; records
-- and hide; the HUD named by its Construct hook built on screen with no walk; a hook that fails. Through gun mode over fake.lua, with a stub entry: ticked ten times a second with the configured key (F4
-- unless set; nil for none), the rounds as "rounds | magazines" while the rifle is out and no text while it is away,
-- the hip-fire crosshair off while the rifle is away; taken off the HUD at coop off. None with gun_mode=off or
-- hud_entry=false. A built entry goes into coop-gun.txt. A later load takes it off, gun mode on or off. The
-- rifle icon is the game's own texture, wanted from the keep.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local D=require('fight.gunmode.ui.dpad')
local P='/Game/Art/UI/Texture/Interaction/'
assert(D.glyph_path(P..'XB/KeyIcon_XboxOne_Gamepad_DPad_Up.KeyIcon_XboxOne_Gamepad_DPad_Up','F4')
    ==P..'XB/KeyIcon_XboxOne_Gamepad_DPad_Right.KeyIcon_XboxOne_Gamepad_DPad_Right')
assert(D.glyph_path(P..'PS/KeyIcon_DualShock4_Gamepad_DPad_Up.KeyIcon_DualShock4_Gamepad_DPad_Up','F4')
    ==P..'PS/KeyIcon_DualShock4_Gamepad_DPad_Right.KeyIcon_DualShock4_Gamepad_DPad_Right')
assert(D.glyph_path(P..'PC/KeyIcon_KeyBoard_Q.KeyIcon_KeyBoard_Q','F4')==P..'PC/KeyIcon_KeyBoard_F4.KeyIcon_KeyBoard_F4')
assert(D.glyph_path(P..'PC/KeyIcon_KeyBoard_Q.KeyIcon_KeyBoard_Q',nil)==nil)
assert(D.glyph_path(P..'PC/Something.Something','F4')==nil and D.glyph_path(nil,'F4')==nil)
assert(D.ICON:match('^/Game/.+/([%w_]+)%.([%w_]+)$'),'the icon is a game texture path, no file')
do
    local Keep=require('core.keep')
    local want=Keep.want
    local wanted={}
    Keep.want=function(paths) for _,p in ipairs(paths) do wanted[p]=true end end
    D.new({log=function() end,valid=function() return false end,try=function() end})
    assert(wanted[D.ICON],'the keep wants the rifle icon')
    assert(wanted[D.HUD],'the keep wants SB\'s HUD class: its Construct is hooked only while the keep holds it')
    Keep.want=want
end

local clock=100
local real_clock=os.clock
os.clock=function() return clock end

-- A fake UMG. An object has a class (its short name), an outer, a name and a full name ("<class> <path>", its path
-- the outer's path, a dot and its name). The engine's StaticFindObject in an outer finds a live child of that name
-- (any case) whose class is the one asked or under it. StaticConstructObject over a live object of the same name,
-- class and outer replaces it in place (W.replaced), as StaticAllocateObject does: the panel that held it keeps it.
-- Panels hold their children in kids; RemoveFromParent takes a widget out of its parent's.
local W
local USER={UserWidget=true}
local function world()
    W={paths={},classes={},walks={},replaced=0,textures={},huds={}}
    local function path_of(o) return o.outer and (path_of(o.outer)..'.'..o.name) or o.name end
    local Obj={}
    Obj.__index=function(o,k)
        local m=rawget(Obj,k)
        if m or type(k)~='string' or not k:match('^%u') then return m end
        -- every other engine call is recorded and answers a slot that takes any call
        return function(self,...)
            self.calls[#self.calls+1]=k
            return setmetatable({},{__index=function() return function() end end})
        end
    end
    function Obj.IsValid(o) return not o.dead end
    function Obj.GetFullName(o) return o.full end
    function Obj.GetVisibility(o) return o.vis end
    function Obj.SetVisibility(o,v) o.vis=v; o.calls[#o.calls+1]='SetVisibility' end
    function Obj.GetDesiredSize(o) return o.size or {X=0,Y=0} end
    function Obj.IsInViewport(o) return o.viewport==true end
    function Obj.SetText(o,t) o.text=t; o.calls[#o.calls+1]='SetText' end
    function Obj.SetBrushFromTexture(o,t) o.tex=t; o.calls[#o.calls+1]='SetBrushFromTexture' end
    function Obj.SetBrush(o,b) o.brush=b; o.calls[#o.calls+1]='SetBrush' end
    function Obj.IsA(o,c) return c~=nil and (c.short==o.class or c.short=='Widget' or (USER[c.short] and o.user)) end
    function Obj.RemoveFromParent(o)
        o.calls[#o.calls+1]='RemoveFromParent'
        local p=o.parent
        if not p then return end
        for i=#p.kids,1,-1 do if p.kids[i]==o then table.remove(p.kids,i) end end
        o.parent=nil
    end
    local function add(p,c)
        p.kids[#p.kids+1]=c; c.parent=p
        return setmetatable({},{__index=function() return function() end end})
    end
    Obj.AddChildToOverlay,Obj.AddChildToHorizontalBox,Obj.AddChildToCanvas,Obj.AddChild=add,add,add,add
    local function new(class,outer,name,t)
        local o=t or {}
        o.class,o.outer,o.name,o.kids,o.calls=class,outer,name,{},{}
        o.vis=o.vis or 0
        o.full=class..' '..path_of(o)
        W.paths[path_of(o)]=o
        if outer then outer.named=outer.named or {}; outer.named[name:lower()]=o end
        return setmetatable(o,Obj)
    end
    W.new=new
    for _,c in ipairs({'Widget','UserWidget','Overlay','Image','TextBlock','HorizontalBox','SizeBox','CanvasPanel'}) do
        W.classes['/Script/UMG.'..c]={short=c,IsValid=function() return true end,GetFullName=function() return 'Class /Script/UMG.'..c end}
    end
    local function tex(path) local t=new('Texture2D',nil,path); W.textures[#W.textures+1]=t; return t end
    W.icon=tex(D.ICON)
    W.kq=tex(P..'PC/KeyIcon_KeyBoard_Q.KeyIcon_KeyBoard_Q')
    W.kf4=tex(P..'PC/KeyIcon_KeyBoard_F4.KeyIcon_KeyBoard_F4')
    W.cell_tex=tex('/Game/Art/UI/Texture/HUD/btn_PcEmpty.btn_PcEmpty')
    W.inst=new('GameInstance',nil,'/Engine/Transient.GameEngine_0:Instance_0')
    StaticFindObject=function(a,outer,name)
        if outer==nil then return W.paths[a] or W.classes[a] end
        local o=outer.named and outer.named[name:lower()]
        if o and not o.dead and o:IsA(a) then return o end
        W.misses=(W.misses or 0)+1 -- in UE4SS a name not found walks the object array (core/unreal.lua)
        return nil
    end
    StaticConstructObject=function(cls,outer,name)
        local old=outer.named and outer.named[name:lower()]
        if old and not old.dead and old.class==cls.short then
            W.replaced=W.replaced+1 -- destroyed and built again at the same address: its parent still holds it
            old.kids,old.calls={},{}
            return old
        end
        return new(cls.short,outer,name)
    end
    FindAllOf=function(class)
        W.walks[class]=(W.walks[class] or 0)+1
        if class=='WB_MainHUD_Master_C' then
            local out={}
            for _,h in ipairs(W.huds) do if not h.dead then out[#out+1]=h end end
            return out
        end
        if class=='Texture2D' then return W.textures end
        local out,c={},{short=class} -- every live widget of that class
        for _,o in pairs(W.paths) do if not o.dead and o.kids and o:IsA(c) then out[#out+1]=o end end
        return out
    end
    FName=function(s) return s end
    FText=function(s) return s end
    LoadAsset=function() end
    return W
end
-- SB's HUD as WB_MainHUD_Master's widget trees name its parts (fight/gunmode/ui/dpad.lua's Dpad.PARTS). no_column:
-- without the D-pad marker.
local function hud(n,no_column)
    local h=W.new('WB_MainHUD_Master_C',W.inst,'WB_MainHUD_Master_C_'..n,{user=true,viewport=true})
    local ht=W.new('WidgetTree',h,'WidgetTree'); h.WidgetTree=ht
    ht.RootWidget=W.new('CanvasPanel',ht,'CanvasPanel_Root')
    local heal=W.new('WB_MainHUD_ItemSlot_C',ht,'WB_MainHUD_HealItem',{user=true,size={X=256,Y=256}})
    heal.WidgetTree=W.new('WidgetTree',heal,'WidgetTree')
    local refill=W.new('WB_MainHUD_ItemSlotRefill_C',heal.WidgetTree,'WB_MainHUD_ItemSlotRefill',{user=true})
    refill.WidgetTree=W.new('WidgetTree',refill,'WidgetTree')
    W.new('TextBlock',refill.WidgetTree,'TextBlock_Item_Count_1',{Font='HUD font'})
    if not no_column then
        local dpad=W.new('WB_MainHUD_Dpad_C',ht,'WB_MainHUD_Dpad',{user=true,size={X=256,Y=256}})
        local dt=W.new('WidgetTree',dpad,'WidgetTree'); dpad.WidgetTree=dt
        h.overlay=W.new('Overlay',dt,'Overlay_0')
        h.up=W.new('Image',dt,'btn_up',{Brush={ResourceObject=W.kq,ImageSize={X=150,Y=150}}})
        h.pad=W.new('Overlay',dt,'Overlay_ps',{vis=1})
        W.new('Image',dt,'btn',{Brush={ResourceObject=W.cell_tex}})
    end
    W.huds[#W.huds+1]=h
    return h
end
local logs={}
local function gee()
    local g={log=function(m) logs[#logs+1]=m end}
    function g.valid(o) if o==nil then return false end local ok,r=pcall(function() return o:IsValid() end); return ok and r==true end
    function g.try(f) local ok,r=pcall(f); if ok then return r end end
    function g.path(o) local f=g.valid(o) and o:GetFullName(); return type(f)=='string' and f:match('^%S+ (.+)$') or nil end
    function g.find(p) return W.classes[p] end
    function g.get(o,k) local ok,r=pcall(function() return o[k] end); if ok then return r end end
    function g.asset(p) return W.paths[p] end
    return g
end
-- A map change frees a HUD with every widget in it.
local function free(h)
    local at=h.full:match('^%S+ (.+)$')
    for path,o in pairs(W.paths) do if path==at or path:sub(1,#at+1)==at..'.' then o.dead=true end end
end
local function ours(h,name) return h.overlay.named and h.overlay.named[name:lower()] end
local function has(o,call) for _,c in ipairs(o.calls) do if c==call then return true end end return false end
local function count(o,call) local n=0 for _,c in ipairs(o.calls) do if c==call then n=n+1 end end return n end
local function ticks(e,n,key,text) for _=1,n do clock=clock+0.1; e.tick(key,text,{1,1,1}) end end

-- 1. Built in the HUD on screen with one walk: the holder the marker's size, the row beside the marker, the F4 glyph
--    on the key cell, the rounds.
do
    world(); logs={}
    local a=hud(1)
    local e=D.new(gee())
    ticks(e,10,'F4','60 | 5')
    local holder,box=ours(a,'GunModeRifleHolder'),ours(a,'GunModeRifleSlot')
    assert(holder and box and #a.overlay.kids==1 and a.overlay.kids[1]==holder,'the holder in the marker\'s overlay')
    assert(W.walks.WB_MainHUD_Master_C==1 and W.walks.Texture2D==nil and next(W.walks,next(W.walks))==nil,
        'one walk: the look for the HUD')
    assert(has(holder,'SetWidthOverride') and has(box,'SetRenderTranslation'),'sized and placed')
    local glyph=box.named.gunmoderiflekey.named.gunmoderiflekeyglyph
    local cell=box.named.gunmoderiflekey.named.gunmoderiflekeycell
    assert(glyph.tex==W.kf4 and glyph.vis==4 and cell.vis==4 and cell.brush==a.pad.outer.named.btn.Brush,
        'the F4 glyph on the game\'s key cell')
    assert(box.named.gunmoderiflecount.text=='60 | 5')
    assert(e.records()[1][1]=='hud' and e.records()[1][2]==holder.full:match('^%S+ (.+)$'),'the holder recorded')
    assert(W.misses==1,'one name not found (the look for an earlier load\'s row): '..tostring(W.misses))
    e.crosshair(true)
    assert(a.WidgetTree.RootWidget.named.gunmodecrosshair and W.misses==2,
        'the crosshair: one name not found (the look for an earlier load\'s canvas): '..tostring(W.misses))
end

-- 2. gun_key=none on the keyboard: no glyph and no cell, never the marker's own key.
do
    world(); logs={}
    local a=hud(1)
    local e=D.new(gee())
    ticks(e,10,nil,nil)
    local key=ours(a,'GunModeRifleSlot').named.gunmoderiflekey
    assert(key.named.gunmoderiflekeyglyph.vis==1 and key.named.gunmoderiflekeycell.vis==1,
        'no glyph for gun_key=none: '..key.named.gunmoderiflekeyglyph.vis)
    assert(key.named.gunmoderiflekeyglyph.tex==nil)
end

-- 3. A new HUD (a map change): the entry built anew there, sized, placed and with its glyph again.
do
    world(); logs={}
    local a=hud(1)
    local e=D.new(gee())
    ticks(e,10,'F4',nil)
    free(a)
    local b=hud(2)
    ticks(e,110,'F4',nil)
    local holder,box=ours(b,'GunModeRifleHolder'),ours(b,'GunModeRifleSlot')
    assert(holder and has(holder,'SetWidthOverride') and has(box,'SetRenderTranslation'),'sized and placed again')
    local glyph=box.named.gunmoderiflekey.named.gunmoderiflekeyglyph
    assert(glyph.tex==W.kf4 and glyph.vis==4,'the F4 glyph again, not the marker\'s Q')
end

-- 4. Another object at the old address (a freed HUD): it passes IsValid but gets no write. The entry is built anew.
do
    world(); logs={}
    local a=hud(1)
    local e=D.new(gee())
    ticks(e,10,'F4','60 | 5')
    local txt=ours(a,'GunModeRifleSlot').named.gunmoderiflecount
    free(a)
    local box=ours(a,'GunModeRifleSlot')
    box.full='HorizontalBox /Engine/Transient.Other_C_9.HorizontalBox_3' -- other widgets at those addresses
    box.dead=false
    a.overlay.full='Overlay /Engine/Transient.Other_C_9.Overlay_2'
    a.overlay.dead=false
    txt.full='TextBlock /Engine/Transient.Other_C_9.TextBlock_7'
    txt.dead,txt.calls=false,{}
    ticks(e,5,'F4','59 | 5')
    assert(not has(txt,'SetText'),'no write to another object at the old address')
end

-- 5. A Lua reload (Ctrl+R): a new load's entry over the live HUD takes the earlier load's widgets again. Nothing is
--    made over a live widget. The marker's overlay holds the entry once. The crosshair the same way.
do
    world(); logs={}
    local a=hud(1)
    local e=D.new(gee())
    ticks(e,10,'F4','60 | 5')
    e.crosshair(true)
    local cross=a.WidgetTree.RootWidget.named.gunmodecrosshair
    assert(cross and cross.vis==3 and #cross.kids==5,'the crosshair: 4 bars and a dot')
    local again=D.new(gee())
    ticks(again,10,'F4','60 | 5')
    again.crosshair(true)
    assert(W.replaced==0,W.replaced..' widgets made over live ones')
    local holder=ours(a,'GunModeRifleHolder')
    assert(#a.overlay.kids==1 and a.overlay.kids[1]==holder and #holder.kids==1,'the entry once in the overlay')
    assert(#a.WidgetTree.RootWidget.kids==1 and #cross.kids==5,'the crosshair once on the root')
    assert(ours(a,'GunModeRifleSlot').named.gunmoderiflecount.text=='60 | 5')
    again.crosshair(false)
    assert(cross.vis==1,'the crosshair off')
end

-- 6. A HUD without the item column: tried once and logged once. A look for the HUD every Dpad.RETRY s, nothing more.
--    A new HUD is tried.
do
    world(); logs={}
    local a=hud(1,true)
    local e=D.new(gee())
    ticks(e,305,'F4',nil) -- 30.5 s
    local n=0
    for _,m in ipairs(logs) do if m:find('not built',1,true) then n=n+1 end end
    assert(n==1,n..' "not built" lines in 30 s')
    assert(W.walks.WB_MainHUD_Master_C==4,W.walks.WB_MainHUD_Master_C..' looks in 30 s')
    free(a)
    local b=hud(2)
    ticks(e,100,'F4',nil)
    assert(ours(b,'GunModeRifleHolder'),'the next HUD is tried')
end

-- 7. The pad: its layer up, the loaded pad glyph looked for once (none loaded: still once), again when the layer
--    comes up again. Its Right twin then shows, without the key cell.
do
    world(); logs={}
    local a=hud(1)
    local e=D.new(gee())
    ticks(e,10,'F4',nil)
    a.pad.vis=4
    ticks(e,30,'F4',nil)
    assert(W.walks.Texture2D==1,'one glyph walk while the pad layer stays up: '..tostring(W.walks.Texture2D))
    local xb_up=W.new('Texture2D',nil,P..'XB/KeyIcon_XboxOne_Gamepad_DPad_Up.KeyIcon_XboxOne_Gamepad_DPad_Up')
    local xb_right=W.new('Texture2D',nil,P..'XB/KeyIcon_XboxOne_Gamepad_DPad_Right.KeyIcon_XboxOne_Gamepad_DPad_Right')
    W.textures[#W.textures+1]=xb_up; W.textures[#W.textures+1]=xb_right
    a.pad.vis=1; ticks(e,10,'F4',nil)
    a.pad.vis=4; ticks(e,10,'F4',nil)
    assert(W.walks.Texture2D==2,'again when the layer comes up again: '..tostring(W.walks.Texture2D))
    local key=ours(a,'GunModeRifleSlot').named.gunmoderiflekey
    assert(key.named.gunmoderiflekeyglyph.tex==xb_right and key.named.gunmoderiflekeycell.vis==1,'the pad\'s D-pad Right')
end

-- 8. hide: the entry and the crosshair off the HUD, nothing recorded after.
do
    world(); logs={}
    local a=hud(1)
    local e=D.new(gee())
    ticks(e,10,'F4',nil)
    e.crosshair(true)
    assert(#e.records()==2,'the entry and the crosshair recorded')
    e.hide()
    assert(#a.overlay.kids==0 and #a.WidgetTree.RootWidget.kids==0 and #e.records()==0,'taken off the HUD')
end

-- 9. The keep holds SB's HUD class: its Construct is hooked once (gun mode's g.hook_hud). A HUD seen by its Construct
--    gets the entry at the first tick it is on screen, with no walk. One never on screen for D.FRESH s is dropped:
--    a look builds it then. Once the entry is taken off (coop off), a Construct makes no engine call.
do
    world(); logs={}
    local Keep=require('core.keep')
    local serves=Keep.serves
    Keep.serves=function(p) return p==D.HUD end
    local hooks={}
    local g=gee()
    g.hook_hud=function(p,cb) hooks[#hooks+1]={p,cb} end
    local e=D.new(g)
    local function built_from(src)
        local n=0
        for _,m in ipairs(logs) do if m=='dpad: rifle entry built (HUD from '..src..')' then n=n+1 end end
        return n
    end
    ticks(e,1,'F4',nil) -- the title: no HUD yet
    assert(#hooks==1 and hooks[1][1]==D.HUD,'the Construct hooked once: '..#hooks)
    assert(W.walks.WB_MainHUD_Master_C==1,'one look at the title')
    local a=hud(1); a.viewport=false
    hooks[1][2]({get=function() return a end})
    ticks(e,5,'F4',nil)
    assert(not ours(a,'GunModeRifleHolder'),'nothing built before the HUD is on screen')
    a.viewport=true
    ticks(e,1,'F4',nil)
    assert(ours(a,'GunModeRifleHolder') and built_from('its Construct')==1,'built at the first tick on screen')
    assert(W.walks.WB_MainHUD_Master_C==1 and #hooks==1,'no walk for it: '..W.walks.WB_MainHUD_Master_C)
    free(a) -- a map change: the next HUD's Construct
    local b=hud(2)
    hooks[1][2]({get=function() return b end})
    ticks(e,1,'F4',nil)
    assert(ours(b,'GunModeRifleHolder') and built_from('its Construct')==2,'built in the next HUD at once')
    assert(W.walks.WB_MainHUD_Master_C==1,'still no walk: '..W.walks.WB_MainHUD_Master_C)
    free(b) -- a HUD seen by its Construct but kept off the screen
    local c=hud(3); c.viewport=false
    hooks[1][2]({get=function() return c end})
    ticks(e,(D.FRESH+1)*10,'F4',nil)
    c.viewport=true
    ticks(e,1,'F4',nil)
    assert(not ours(c,'GunModeRifleHolder'),'dropped after D.FRESH s: the next look builds it')
    ticks(e,100,'F4',nil)
    assert(ours(c,'GunModeRifleHolder') and built_from('a look')==1,'built by a look')
    local n=0
    for _,m in ipairs(logs) do if m=='dpad: no HUD in the viewport' then n=n+1 end end
    assert(n==1,n..' "no HUD" lines')
    e.hide()
    local read=false
    hooks[1][2]({get=function() read=true end})
    assert(not read,'no engine call from a Construct once the entry is taken off')
    Keep.serves=serves
end

-- 10. A Construct hook that cannot be registered: one line, tried once. The look still builds the entry.
do
    world(); logs={}
    local Keep=require('core.keep')
    local serves=Keep.serves
    Keep.serves=function(p) return p==D.HUD end
    local tries=0
    local g=gee()
    g.hook_hud=function() tries=tries+1; error('no such function',0) end
    local e=D.new(g)
    ticks(e,1,'F4',nil)
    local a=hud(1)
    ticks(e,110,'F4',nil)
    local n=0
    for _,m in ipairs(logs) do if m=='dpad: no Construct hook: no such function' then n=n+1 end end
    assert(tries==1 and n==1,tries..' tries, '..n..' lines')
    assert(ours(a,'GunModeRifleHolder'),'built by the look')
    Keep.serves=serves
end
os.clock=real_clock

-- Through gun mode: a stub entry records each tick.
local Fake=dofile('tests/lua/fight/gunmode/fake.lua')
local made,ticked,cross,hidden={},{},{},0
local built=false -- the stub's next tick says it built the entry
package.loaded['fight.gunmode.ui.dpad']={new=function()
    local e={}
    function e.tick(key,text,c)
        ticked[#ticked+1]={key=key,text=text,c=c}
        local b=built; built=false; return b
    end
    function e.crosshair(on) cross[#cross+1]=on; return false end
    function e.hide() hidden=hidden+1 end
    function e.records() return hidden==0 and {{'hud','/Test/HUD.WidgetTree.Overlay_0.GunModeRifleHolder'}} or {} end
    made[#made+1]=e
    return e
end}
package.loaded['fight.gunmode.laser']=function() return function() end,function() end end
package.loaded['fight.gunmode.mode']=nil
local GunMode=require('fight.gunmode.mode')
local Link=require('core.link')
clock=100
os.clock=function() return clock end
local function frames(gun,n) for _=1,n do clock=clock+1/60; gun.tick() end end

do
    local w=Fake.new(); w.install()
    local gun=GunMode.new({log=function() end})
    frames(gun,60)
    assert(#made==1,'one entry')
    assert(#ticked>=9 and #ticked<=11,#ticked..' ticks in 1 s')
    assert(ticked[#ticked].key=='F4' and ticked[#ticked].text==nil,'the key, no rounds while the rifle is away')
    assert(cross[#cross]==false,'no crosshair while the rifle is away')
    clock=clock+1; gun.toggle_now()
    assert(gun.state.on)
    frames(gun,30)
    assert(ticked[#ticked].text=='60 | 5','the rounds while the rifle is out: '..tostring(ticked[#ticked].text))
    gun.stop('coop off')
    assert(hidden==1,'taken off the HUD at coop off')
    local n=#ticked
    frames(gun,60)
    assert(#ticked==n,'no tick after coop off')
end
do
    local w=Fake.new(); w.install()
    ticked={}
    local gun=GunMode.new({log=function() end,settings=Link.parse_settings('gun_key=F2\n')})
    frames(gun,10)
    assert(ticked[#ticked].key=='F2','the configured key: '..tostring(ticked[#ticked].key))
    ticked={}
    gun=GunMode.new({log=function() end,settings=Link.parse_settings('gun_key=none\n')})
    frames(gun,10)
    assert(#ticked>0 and ticked[#ticked].key==nil,'no key with gun_key=none')
    ticked={}
    gun=GunMode.new({log=function() end,settings=Link.parse_settings('gun_mode=off\n')})
    frames(gun,60)
    assert(#ticked==0,'no entry with gun_mode=off')
    local Config=require('fight.gunmode.config')
    Config.DEFAULTS.hud_entry=false
    gun=GunMode.new({log=function() end})
    frames(gun,60)
    assert(#ticked==0,'no entry with hud_entry=false')
    Config.DEFAULTS.hud_entry=true
end
-- coop-gun.txt: a built entry is named in it. A later load takes the entry off SB's HUD, gun mode on or off.
do
    local w=Fake.new(); w.install()
    hidden=0
    local line
    local store={save=function(l) line=l; return true end,load=function() return line end,clear=function() line=nil end}
    local gun=GunMode.new({log=function() end,store=store})
    gun.restore()
    built=true
    frames(gun,10)
    assert(line and line:find('hud|/Test/HUD.WidgetTree.Overlay_0.GunModeRifleHolder',1,true),
        'the entry in coop-gun.txt: '..tostring(line))
    local kept=line
    for _,off in ipairs({false,true}) do
        line=kept
        local holder={removed=0,full='SizeBox /Test/HUD.WidgetTree.Overlay_0.GunModeRifleHolder'}
        function holder.IsValid() return true end
        function holder.GetFullName(o) return o.full end
        function holder.RemoveFromParent(o) o.removed=o.removed+1 end
        w.paths['/Test/HUD.WidgetTree.Overlay_0.GunModeRifleHolder']=holder
        local later=GunMode.new({log=function() end,store=store,
            settings=off and Link.parse_settings('gun_mode=off\n') or nil})
        later.restore()
        assert(holder.removed==1,'taken off by the next load (gun_mode '..(off and 'off' or 'on')..')')
    end
end
os.clock=real_clock
print('gunmode dpad_test ok')
