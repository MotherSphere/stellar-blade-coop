-- The Uplink kit (ui/kit.lua's Ui.kit) with fake UE4SS objects and clock: nothing at all until a group is added; the
-- assets warmed one lookup a 250 ms tick, the build in one call once the classes are in (default font and flat colour)
-- and again once the look's assets are in (sounds after; not while the menu is open), every group's widgets in place
-- before AddToViewport; the game's fonts, dots, cubes, key icons and colours; hit tests passing through all but the
-- menu's rows; updates only on change; groups hidden and shown again, never removed; the open (slide and flicker) and
-- close tweens in the 1 ms loop, and no engine call while none runs; the scale; the game's sounds; a new root after a
-- map change, its freed assets looked up again, the old handles never touching an address that holds another object;
-- no rebuild storm; the root an earlier Lua load left swept; the first engine error, in a build's own update too,
-- turning the kit off (off(): the notice line above EVE is the fallback); a look that cannot be had only degrading;
-- an image's texture made at run time, refused without turning the kit off; the mouse cursor for a group that asks;
-- nothing while the world is hidden or after coop off.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
-- UE4SS refuses any call from a lua_State it did not create (a coroutine is one); the tests run on the main thread.
local function ue4ss()
    local _,main=coroutine.running()
    if main then return end
    error('[process_lua_function] The lua state has no instance inside lua_instances unordered map',3)
end
local calls,stores,raise,modes,special={},{},{},{},{}
local viewport,registry,loadable,constructed,logs,saved,pc
local since=0 -- of() looks at the widgets constructed after this many: the last full build's (up sets it).
local next_address=0x1000
local function call(name) ue4ss(); calls[#calls+1]=name end
-- A struct property as UE4SS gives it: a view on the object's memory ('raise': writes raise; 'copy': they do not stick).
local function struct(name,data)
    return setmetatable({},{__index=data,__newindex=function(_,k,v)
        call('set '..name..'.'..k)
        if modes[name]=='raise' then error(name..' is read-only here',0) end
        if modes[name]~='copy' then data[k]=v end
    end})
end
-- Any UObject: every method is recorded with its arguments (last[method]); special ones behave.
local function object(class)
    local s={class=class,alive=true,props={},last={},get={}}
    next_address=next_address+0x10
    s.full=string.format('%s /Engine/Transient.%s_%x',class,class,next_address)
    local o
    o=setmetatable({},{__index=function(_,k)
        if k=='type' then return function() return 'UObject' end end
        if k=='IsValid' then return function() call(class..'.IsValid'); return s.alive end end
        if k=='GetFullName' then return function() call(class..'.GetFullName'); return s.full end end
        if s.get[k] then ue4ss(); return s.get[k]() end
        if s.props[k]~=nil then ue4ss(); return s.props[k] end
        return function(_,...)
            local name=class..'.'..k
            call(name)
            s.last[k]={...}
            if raise[name] then error(raise[name],0) end
            local f=special[name] or special['*.'..k]
            if f then return f(s,o,...) end
        end
    end,__newindex=function(_,k,v)
        call('set '..class..'.'..k)
        if raise['set '..class..'.'..k] then error(raise['set '..class..'.'..k],0) end
        s.props[k]=v
    end})
    stores[o]=s
    return o
end
local invalid=object('Invalid')
stores[invalid].alive=false
local function in_viewport(o) for _,r in ipairs(viewport) do if r==o then return true end end return false end
special['CanvasPanel.AddChildToCanvas']=function(s,_,child)
    s.children=s.children or {}
    s.children[#s.children+1]=child
    local slot=object('CanvasPanelSlot')
    stores[child].slot=slot
    return slot
end
special['UserWidget.AddToViewport']=function(_,o) viewport[#viewport+1]=o end
special['UserWidget.IsInViewport']=function(_,o) return in_viewport(o) end
special['UserWidget.RemoveFromParent']=function(_,o)
    for i,r in ipairs(viewport) do if r==o then table.remove(viewport,i); break end end
end
special['PC.IsA']=function(_,_,class) return stores[class].class=='PlayerController' end
special['TextBlock.SetText']=function(s,_,t) s.text=t.text end
special['EditableTextBox.SetText']=function(s,_,t) s.text=t.text end
special['EditableTextBox.GetText']=function(s) return {ToString=function() return s.text end} end
special['Image.IsHovered']=function(s) return s.hovered end
special['TextBlock.SetFont']=function(s,_,info)
    if modes.SetFont then error(modes.SetFont,0) end
    s.font.FontObject,s.font.Size=info.FontObject,info.Size
end
special['Image.SetBrushFromTexture']=function(s,_,texture,match) assert(match==true); s.brush.ResourceObject=texture end
-- As this engine's UE4SS: PlaySound2D takes all 8 parameters (WorldContextObject, Sound, VolumeMultiplier,
-- PitchMultiplier, StartTime, ConcurrencySettings, OwningActor, bIsUISound), nil ones included.
special['GameplayStatics.PlaySound2D']=function(_,_,...)
    local n=select('#',...)
    if n~=8 then error('UFunction expected 8 parameters, received '..n,0) end
end
StaticFindObject=function(path) call('find '..path); return registry[path] or invalid end
LoadAsset=function(path) call('load '..path); if loadable[path] then registry[path]=loadable[path] end end
StaticConstructObject=function(class,outer)
    local name=stores[class].class
    call('construct '..name)
    if raise['construct '..name] then return invalid end
    local o=object(name)
    local s=stores[o]
    s.outer=outer
    if name=='TextBlock' then
        s.font={Size=24}
        s.get.Font=function() return struct('Font',s.font) end
    elseif name=='Image' then
        s.brush={Tiling=0}
        s.get.Brush=function() return struct('Brush',s.brush) end
    elseif name=='EditableTextBox' then -- Its style as Slate's default box: dark text on white.
        s.text=''
        s.style={Font={Size=10},ForegroundColor={ColorUseRule=1,SpecifiedColor={R=0,G=0,B=0,A=1}},
            BackgroundColor={ColorUseRule=1,SpecifiedColor={R=1,G=1,B=1,A=1}}}
        local view={}
        for key,data in pairs(s.style) do view[key]=struct(key=='Font' and 'BoxFont' or key,data) end
        s.get.WidgetStyle=function()
            if modes.WidgetStyle then error(modes.WidgetStyle,0) end
            return struct('WidgetStyle',view)
        end
    end
    constructed[#constructed+1]=o
    return o
end
FText=function(text) ue4ss(); return {text=text} end
package.loaded.UEHelpers={GetPlayerController=function() ue4ss(); return pc end}
local Ui=require('ui.kit')
local T=Ui.THEME
local PATHS={} -- Asset name to object path.
for _,a in ipairs(Ui.ASSETS) do PATHS[a[1]]=a[2] end
local function reset()
    for _,o in pairs(registry or {}) do stores[o].alive=false end -- core/unreal.lua's cache looks them up again.
    calls,raise,modes,viewport,registry,loadable,constructed,logs,saved,since={},{},{},{},{},{},{},{},nil,0
    clock=100
    pc=object('PC')
    registry['/Script/Engine.PlayerController']=object('PlayerController')
    registry['/Script/Engine.Default__GameplayStatics']=object('GameplayStatics')
    registry['/Script/UMG.Default__WidgetBlueprintLibrary']=object('WidgetBlueprintLibrary')
    registry['/Script/Engine.Default__KismetInternationalizationLibrary']=object('KismetInternationalizationLibrary')
    registry['/Script/UMG.Default__WidgetLayoutLibrary']=object('WidgetLayoutLibrary')
    for _,c in ipairs({'UserWidget','WidgetTree','CanvasPanel','Border','TextBlock','Image','ProgressBar',
            'EditableTextBox'}) do
        registry['/Script/UMG.'..c]=object(c)
    end
    for _,a in ipairs(Ui.ASSETS) do
        registry[a[2]]=object(a[1])
        if a.alt then registry[a.alt]=object(a[1]..'_alt') end
    end
end
local store={save=function(path) saved=path end,load=function() return saved end,clear=function() saved=nil end}
local function count(prefix)
    local n=0
    for _,c in ipairs(calls) do if c:sub(1,#prefix)==prefix then n=n+1 end end
    return n
end
local function at(name,after) for i=(after or 0)+1,#calls do if calls[i]==name then return i end end end
local function of(class)
    local list={}
    for i=since+1,#constructed do if stores[constructed[i]].class==class then list[#list+1]=constructed[i] end end
    return list
end
local function asset(name) return registry[PATHS[name]] end
local function size(o) local s=stores[stores[o].slot].last.SetSize; return s and s[1].X..'x'..s[1].Y end
local function pos(o) local p=stores[stores[o].slot].last.SetPosition[1]; return p.X..','..p.Y end
local function vis(o) local v=stores[o].last.SetVisibility; return v and v[1] end
local views={}
-- Two groups using every builder: a card (shown) and a menu (hidden until shown; its rows take the mouse).
local function kit(options)
    options=options or {}
    options.store,options.log=store,function(m) logs[#logs+1]=m end
    local k=Ui.kit(options)
    k.add('card',{x=96,y=96,w=760,h=210,shown=true},function(b)
        views.card_built=(views.card_built or 0)+1
        b.panel(0,0,760,210)
        return {name=b.text(24,20,'Alex','name',T.teal),hp=b.hp(24,80,40,3,'big'),sh=b.shield(24,130,'small'),
            be=b.cubes(24,160,8,T.beta),dot=b.image(700,20,20,20,'link',T.teal),
            arrow=b.image(600,20,32,32,'chevron',T.teal,{X=0.5,Y=2})}
    end)
    k.add('menu',{x=180,y=330,w=1240,h=1500,hit=true},function(b)
        b.panel(0,0,1240,1500)
        local v={title=b.text(40,30,'CO-OP','title'),row=b.row(40,200,760),bar=b.bar(40,900,400,12,T.teal)}
        b.hints(40,1400,300,{{'move','Move'},{'enter','Select'},{'escape','Close'}})
        return v
    end)
    return k
end
-- Slow ticks until the root is built with its look (after one built while it warms); of() then looks at its widgets.
local function up(k)
    for i=1,200 do
        local first=#constructed
        k.slow(true)
        if #constructed>first and logs[#logs]:find('^UI built: ') then since=first; return i end
    end
    error('never built')
end
local UMG={'UserWidget','WidgetTree','CanvasPanel','Border','TextBlock','Image','ProgressBar','EditableTextBox'}
local SOUNDS=0
for _,a in ipairs(Ui.ASSETS) do if a.volume then SOUNDS=SOUNDS+1 end end

-- The asset paths are the game's (a few, verbatim).
assert(PATHS.Bold=='/Game/Art/Font/Bold.Bold' and PATHS.FZSHANGYTJW=='/Game/Art/Font/English/FZSHANGYTJW_Font.'
    ..'FZSHANGYTJW_Font' and PATHS.dot=='/Game/Art/UI/Texture/HUD/Gauge/Hp_Dot1_5x.Hp_Dot1_5x')
assert(PATHS.open=='/Game/Sound/UI/MainMenu/Ui_MoveIn_Cue.Ui_MoveIn_Cue')
-- The key icons of the game's own menus (Interaction/PC, 80 by 80), and every path in the case of the game's files as a
-- pak export gives them (UE4SS.log of 2026-10-19: key_arrows, PC_ActionAssist's 'directionAll', and chevron, in
-- 'WorkShop', missing with another case). The chevron falls back to the HUD's triangle (it points up too), the arrows
-- to PC_ActionAssist's 'directionAll'.
for name,file in pairs({key_enter='Enter',key_escape='Escape',key_space='SpaceBar',key_up='Up',
        key_arrows='DirectionAll',key_move='MoveAll',key_move_azerty='MoveAll_AZERTY'}) do
    assert(PATHS[name]=='/Game/Art/UI/Texture/Interaction/PC/KeyIcon_KeyBoard_'..file..'.KeyIcon_KeyBoard_'..file,
        PATHS[name])
end
local ALT={}
for _,a in ipairs(Ui.ASSETS) do ALT[a[1]]=a.alt end
assert(PATHS.chevron=='/Game/Art/UI/Texture/WorkShop/TriPatternUp.TriPatternUp'
    and ALT.chevron=='/Game/Art/UI/Texture/HUD/triangle.triangle',PATHS.chevron)
assert(ALT.key_arrows=='/Game/Art/UI/Texture/Interaction/PC_ActionAssist/KeyIcon_KeyBoard_directionAll.'
    ..'KeyIcon_KeyBoard_directionAll',ALT.key_arrows)
-- Colours as the engine takes them: linear, from the hex Slate shows (#ADD1C4).
assert(math.abs(T.teal.R-0.418)<0.001 and math.abs(T.teal.G-0.637)<0.001 and T.teal.A==1 and T.panel.A==0.78)

-- No group: nothing at all, however long.
reset()
local k=Ui.kit({store=store})
for _=1,60 do k.slow(true); k.tick(clock) end
assert(#calls==0 and k.view('card')==nil and not k.ready(),'No engine call without a group')

-- The warm-up: one class or asset a tick. The build, which looks nothing up, as soon as the classes are in: the
-- default font, flat colour, no texture (the menu works from the start); built again once the assets it uses are in
-- (not the sounds), the first root out; then the sounds, one a tick.
reset()
k=kit({azerty=true})
local builds,roots={},{}
for i=1,200 do
    local before,first=#calls,#constructed
    k.slow(true)
    local finds,loads=0,0
    for j=before+1,#calls do
        if calls[j]:find('^find ') then finds=finds+1 end
        if calls[j]:find('^load ') then loads=loads+1 end
    end
    assert(finds<=1 and loads==0,'One lookup a tick at most')
    if #constructed>first then
        assert(finds==0 and #viewport==1,'The build looks nothing up')
        builds[#builds+1],roots[#roots+1],since=i,viewport[1],first
        if #builds==2 then break end
        assert(k.view('menu') and logs[1]:find('^UI built while its look warms: %d+ widgets in 0%.0 ms$'),logs[1])
        assert(k.ready() and not k.whole(),'Up, but not with its whole look yet')
        for _,o in ipairs(of('TextBlock')) do assert(stores[o].font.Size==24 and not stores[o].last.SetFont) end
        for _,o in ipairs(of('Image')) do assert(not stores[o].brush.ResourceObject) end
    end
end
-- Classes, the PC class and four libraries (GameplayStatics, the input modes, the language, the viewport's size); then
-- the assets.
assert(builds[1]==#UMG+6 and builds[2]==#UMG+6+#Ui.ASSETS-SOUNDS+1,table.concat(builds,' '))
assert(stores[roots[1]].last.RemoveFromParent and roots[2]~=roots[1],'The first root out')
for i=1,SOUNDS do
    local before=#calls
    assert(k.slow(true)==nil)
    local finds=0
    for j=before+1,#calls do if calls[j]:find('^find ') then finds=finds+1 end end
    assert(finds==1,'Sound '..i..' warmed after the build')
end
local n=#calls
k.slow(true)
assert(count('find ')==#UMG+5+#Ui.ASSETS and #calls-n==3 and calls[n+3]=='UserWidget.IsInViewport',
    'Then a still-ours, in-the-viewport check only')

-- The build: a plain UserWidget owned by the player, its tree and canvas by hand, a canvas a group; all in before
-- AddToViewport; its path kept for the next Lua load.
local root=viewport[1]
assert(stores[root].class=='UserWidget' and stores[root].outer==pc and stores[root].last.AddToViewport[1]==100)
assert(k.whole(),'Its whole look')
local tree,canvas=stores[root].props.WidgetTree,nil
canvas=stores[tree].props.RootWidget
assert(stores[tree].outer==root and stores[canvas].class=='CanvasPanel' and stores[canvas].outer==tree)
local first=at('UserWidget.AddToViewport') -- The build while the look warms.
local add=at('UserWidget.AddToViewport',first)
for _,before in ipairs({'set UserWidget.WidgetTree','set WidgetTree.RootWidget','UserWidget.SetOwningPlayer',
        'UserWidget.SetVisibility','TextBlock.SetText','Image.SetBrushFromTexture','set Font.FontObject'}) do
    assert(at(before,first) and at(before,first)<add,before..' before AddToViewport')
end
assert(stores[root].last.SetOwningPlayer[1]==pc and vis(root)==4,"Owned, hit tests pass through but the menu's")
assert(saved==stores[root].full:match('^%S+ (.+)$'),'Its path kept')
assert(#logs==2 and logs[2]:find('^UI built: %d+ widgets in 0%.0 ms$'),logs[2])
local groups=stores[canvas].children
assert(#groups==2 and pos(groups[1])=='96,96' and size(groups[1])=='760x210' and pos(groups[2])=='180,330')
assert(vis(groups[1])==3 and vis(groups[2])==1,'The card shown, the menu hidden')
assert(stores[groups[1]].last.SetRenderTransformPivot[1].X==0 and not stores[groups[1]].last.SetRenderScale,
    'Scaled from the top left; 100 % needs no call')
local card,menu=k.view('card'),k.view('menu')
assert(card and menu and k.ready() and views.card_built==2) -- Once while the look warmed.

-- The look: the panel's glass and dotted rails; text in the game's fonts and colours; the gauges' dots; the cubes;
-- the key icons, AZERTY's moves.
local borders=of('Border')
assert(#borders==2 and stores[borders[1]].last.SetBrushColor[1]==T.panel)
local function text(t) for _,o in ipairs(of('TextBlock')) do if stores[o].text==t then return stores[o],o end end end
assert(text('Alex').font.FontObject==asset('Bold') and text('Alex').font.Size==36)
assert(text('Alex').last.SetColorAndOpacity[1].SpecifiedColor==T.teal and
    text('Alex').last.SetColorAndOpacity[1].ColorUseRule==0,'Teal, the partner colour')
assert(text('CO-OP').font.Size==56 and text('Move').font.FontObject==asset('Bold') and text('Move').font.Size==30)
assert(text('CO-OP').last.SetColorAndOpacity[1].SpecifiedColor==T.text)
assert(vis(select(2,text('CO-OP')))==3 and vis(borders[2])==3 and vis(select(2,text('Alex')))==nil,
    "In the menu hit tests pass through all but its rows; the card's group lets them all through")
local function textured(name)
    local list={}
    for _,o in ipairs(of('Image')) do if stores[o].brush.ResourceObject==asset(name) then list[#list+1]=o end end
    return list
end
local rails=textured('small')
assert(#rails>=4 and size(rails[1])=='710x10' and pos(rails[1])=='24,12' and pos(rails[2])=='24,188')
assert(stores[rails[1]].brush.Tiling==3 and stores[rails[1]].last.SetColorAndOpacity[1]==T.rail,'Dotted rails')
local hp_bg,hp=textured('dot_bg')[1],textured('dot')[1]
assert(size(hp_bg)=='600x45' and size(hp)=='0x45' and stores[hp].brush.Tiling==3 and pos(hp)=='24,80')
assert(stores[hp].last.SetColorAndOpacity[1]==T.teal and stores[hp_bg].last.SetColorAndOpacity[1]==T.white)
local shield_bg=textured('small_bg')
assert(#shield_bg==5 and pos(shield_bg[2])=='144,130' and size(shield_bg[5])=='110x20','Five blocks of 11 by 2')
assert(#textured('cube0')==8 and #textured('cube4')==8 and pos(textured('cube0')[2])=='65,160')
for _,o in ipairs(textured('cube0')) do assert(vis(o)==1,'No cube before her values') end
assert(#textured('key_move_azerty')==1 and #textured('key_move')==0 and #textured('key_escape')==1)
-- 66 units square, as the game's photo mode draws these icons beside its text; the label after it, on its middle.
assert(pos(textured('key_enter')[1])=='340,1400' and size(textured('key_enter')[1])=='66x66')
assert(pos(select(2,text('Select')))=='418,1409' and text('Select').font.Size==30,'Its label beside it')

-- Reuse: updates touch the engine only on change; the gauges follow the player cluster's rules.
n=#calls
card.hp.set(50,100)
assert(size(hp)=='300x45' and count('CanvasPanelSlot.SetSize')>0)
local m=#calls
card.hp.set(50,100); card.name.set('Alex'); card.name.color(T.teal)
assert(#calls==m,'No change, no call')
card.sh.set(150,300,3)
assert(size(textured('small')[3])=='110x20' and size(textured('small')[4])=='60x20','Block 1 full, block 2 at 6')
assert(size(shield_bg[4])=='0x20' and size(shield_bg[5])=='0x20','Blocks 4 and 5 not shown')
card.be.set(450,1000)
local base,q1,q3=textured('cube0'),textured('cube1'),textured('cube3')
assert(vis(base[5])==3 and vis(base[6])==1 and vis(q1[3])==3 and vis(q3[3])==1 and vis(q3[1])==3)
card.name.set('Alexandra')
assert(text('Alexandra'))
menu.row.set('Host a session','On','focus')
assert(pos(select(2,text('Host a session')))=='76,212' and pos(select(2,text('On')))=='500,212',
    'The label 36 units in, the value in the last 300 units unless said')
local flats={}
for _,o in ipairs(of('Image')) do if not stores[o].brush.ResourceObject then flats[#flats+1]=o end end
assert(#flats==2 and vis(flats[1])==0 and size(flats[1])=='760x76','The row takes the mouse')
assert(stores[flats[1]].last.SetColorAndOpacity[1]==T.focus and vis(flats[2])==3 and size(flats[2])=='6x76',
    'The Beta-blue focus bar')
assert(stores[flats[2]].last.SetColorAndOpacity[1]==T.beta and text('Host a session').font.Size==40)
assert(menu.row.hovered()==false)
stores[flats[1]].hovered=true
assert(menu.row.hovered()==true,'Under the mouse')
menu.row.set('Join a friend','','disabled')
assert(vis(flats[2])==1 and text('Join a friend').last.SetColorAndOpacity[1].SpecifiedColor==T.dim)
assert(stores[flats[1]].last.SetColorAndOpacity[1]==T.clear and vis(flats[1])==0)
menu.bar.set(0.5)
assert(stores[of('ProgressBar')[1]].last.SetPercent[1]==0.5)
card.dot.show(false)
assert(vis(textured('link')[1])==1)
-- The first root went: the one built while the look warmed.
assert(k.view('card')==card and count('construct ')==#constructed and count('UserWidget.RemoveFromParent')==1)

-- Hidden and shown again, never rebuilt: instant, or with the open tween (160 ms: slide from -32 and a two-frame
-- flicker at 0.6) and the close tween (120 ms, then collapsed); no engine call while none runs.
local menu_canvas=groups[2]
local ms=stores[menu_canvas]
k.show('menu',true)
assert(vis(menu_canvas)==4 and ms.last.SetRenderOpacity[1]==1 and ms.last.SetRenderTranslation[1].X==0)
n=#calls; k.show('menu',true); assert(#calls==n,'Already shown')
k.show('menu',false)
assert(vis(menu_canvas)==1)
n=#calls; k.tick(clock); assert(#calls==n,'No tween, no call')
k.show('menu',true,clock)
assert(vis(menu_canvas)==4 and ms.last.SetRenderOpacity[1]==0 and ms.last.SetRenderTranslation[1].X==-32)
local function frame(dt) clock=clock+dt; assert(k.tick(clock)==nil) return ms.last.SetRenderOpacity[1],
    ms.last.SetRenderTranslation[1].X end
local function near(v,want) return math.abs(v-want)<1e-6 end
local a,x=frame(0.08)
assert(near(a,0.5/0.6) and near(x,-8),a..' '..x)
a=frame(0.034); assert(a==0.6,'Flicker 1') -- Past 70 %.
a=frame(0.008); assert(a==0.6,'Flicker 2')
a,x=frame(0.008); assert(a==1 and near(x,-32*(1-0.13/0.16)^2),'Back to full')
a,x=frame(0.04); assert(a==1 and x==0)
n=#calls; frame(0.1); assert(#calls==n,'Done: no call')
k.show('menu',false,clock)
assert(vis(menu_canvas)==4,'Visible while it closes')
a,x=frame(0.06); assert(near(a,0.5) and near(x,-8))
frame(0.06); assert(vis(menu_canvas)==1,'Collapsed at the end')
n=#calls; frame(0.1); assert(#calls==n)
-- Shown at once while it closes: the close tween dropped, shown it stays.
k.show('menu',true,clock); frame(0.2); k.show('menu',false,clock); frame(0.06); k.show('menu',true); frame(0.2)
assert(vis(menu_canvas)==4 and ms.last.SetRenderOpacity[1]==1 and ms.last.SetRenderTranslation[1].X==0)
k.show('menu',false)
-- The scale: every group, on change only, 75 to 150 %.
k.scale(120)
assert(stores[groups[1]].last.SetRenderScale[1].X==1.2 and ms.last.SetRenderScale[1].Y==1.2)
n=#calls; k.scale(120); assert(#calls==n)
k.scale(400); assert(ms.last.SetRenderScale[1].X==1.5)
k.scale(10); assert(ms.last.SetRenderScale[1].X==0.75)
-- move: the group's slot, on change only.
k.move('menu',200,300); assert(pos(menu_canvas)=='200,300')
n=#calls; k.move('menu',200,300); assert(#calls==n)
-- fade: a group's opacity (the partner card greyed), on change only, kept across builds. turn: an image's angle around
-- the pivot it was made with (the arrow's chevron around its diamond), on change only.
k.fade('card',0.45)
assert(stores[groups[1]].last.SetRenderOpacity[1]==0.45)
n=#calls; k.fade('card',0.45); assert(#calls==n)
local chevron=textured('chevron')[1]
assert(chevron and stores[chevron].last.SetRenderTransformPivot[1].Y==2 and stores[chevron].brush.Tiling==0)
card.arrow.turn(90); assert(stores[chevron].last.SetRenderTransformAngle[1]==90)
n=#calls; card.arrow.turn(90); assert(#calls==n)
-- project: a world point's view for partner.place, in layout units (the viewport's pixels over its DPI scale): the
-- player's camera, the viewport read once a second, and the engine's projection; the field of view when the engine
-- gives no point (behind the camera, or an out-table left empty), and from then on once it raises (said once, the kit
-- stays); nil with no camera or no scale.
local cam=object('PlayerCameraManager')
stores[pc].props.PlayerCameraManager=cam
special['WidgetLayoutLibrary.GetViewportSize']=function() return {X=2560,Y=1440} end
special['WidgetLayoutLibrary.GetViewportScale']=function() return 1440/2160 end
special['PlayerCameraManager.GetCameraLocation']=function() return {X=1,Y=2,Z=3} end
special['PlayerCameraManager.GetCameraRotation']=function() return {Pitch=-10,Yaw=45,Roll=0} end
special['PlayerCameraManager.GetFOVAngle']=function() return 80 end
special['PC.ProjectWorldLocationToScreen']=function(_,_,_,out,relative)
    assert(relative==false)
    out.X,out.Y=1280,720
    return true
end
local anchor={X=500,Y=0,Z=220}
local view=k.project(anchor,clock)
assert(math.abs(view.width-3840)<1e-9 and math.abs(view.height-2160)<1e-9 and math.abs(view.screen.x-1920)<1e-9
    and math.abs(view.screen.y-1080)<1e-9 and view.anchor==anchor and view.fov==nil)
assert(view.camera.X==1 and view.camera.Z==3 and view.rotation.Yaw==45 and view.rotation.Pitch==-10)
assert(stores[pc].last.ProjectWorldLocationToScreen[1]==anchor)
n=count('WidgetLayoutLibrary.GetViewport')
k.project(anchor,clock+0.5)
assert(count('WidgetLayoutLibrary.GetViewport')==n,'The viewport read once a second')
k.project(anchor,clock+1)
assert(count('WidgetLayoutLibrary.GetViewport')==n+2)
special['PC.ProjectWorldLocationToScreen']=function() return false end
view=k.project(anchor,clock+1)
assert(view.screen==nil and view.fov==80,'Behind the camera')
special['PC.ProjectWorldLocationToScreen']=function() return true end
assert(k.project(anchor,clock+1).fov==80,'An out-table left empty')
raise['PC.ProjectWorldLocationToScreen']='no such out param'
n=#logs
assert(k.project(anchor,clock+1).fov==80 and #logs==n+1 and logs[#logs]:find('no such out param',1,true),logs[#logs])
raise={}
n=count('PC.ProjectWorldLocationToScreen')
assert(k.project(anchor,clock+1).fov==80 and count('PC.ProjectWorldLocationToScreen')==n and k.ready())
special['WidgetLayoutLibrary.GetViewportScale']=function() return 0 end
assert(k.project(anchor,clock+2)==nil,'No scale yet')
special['WidgetLayoutLibrary.GetViewportScale']=function() return 1 end
stores[pc].props.PlayerCameraManager=nil
assert(k.project(anchor,clock+3)==nil,'No camera')
stores[pc].props.PlayerCameraManager=cam

-- The game's sounds: PlaySound2D with all its 8 parameters (the fake refuses fewer, as the game's UE4SS does): our
-- root as the world, volume, pitch 1, from the start, no concurrency or owner, a UI sound; the chat line quieter; off
-- by the setting; a raise turns the sounds off only.
local statics=registry['/Script/Engine.Default__GameplayStatics']
n=#logs
k.sound('open')
local played=stores[statics].last.PlaySound2D
assert(#logs==n,logs[#logs])
assert(played[1]==root and played[2]==asset('open') and played[3]==1 and played[4]==1 and played[5]==0
    and played[6]==nil and played[7]==nil and played[8]==true)
k.sound('chat'); assert(stores[statics].last.PlaySound2D[3]==0.5)
n=#calls; k.sound('link'); assert(#calls==n,'A texture is no sound')
k.sounds(false); n=#calls; k.sound('move'); assert(#calls==n)
-- A sound freed (its address reused): silent, looked up again by the next slow.
k.sounds(true)
stores[asset('back')].full='SoundWave /Game/Maps/Next.Other'
registry[PATHS.back]=object('back')
n=#calls; k.sound('back'); assert(not at('GameplayStatics.PlaySound2D',n),'Not played')
k.slow(true); k.sound('back')
assert(stores[statics].last.PlaySound2D[2]==asset('back'),'Found again')
k.sounds(true); raise['GameplayStatics.PlaySound2D']='no audio device'
k.sound('move')
assert(logs[#logs]=='UI sounds off until the mod reloads: no audio device',logs[#logs])
n=#calls; k.sound('move'); assert(#calls==n,'Off for good')
assert(k.ready() and k.slow(true)==nil,'The UI stays')
raise={}

-- A map change: the viewport and every widget gone. The next tick builds a new root, the groups as they were; the old
-- handles touch nothing, even where an address now holds another object.
local old_card=card
k.show('menu',true,clock) -- Its open tween running as the map goes.
for _,o in ipairs(constructed) do stores[o].alive=false end
viewport={}
local reused=of('TextBlock')[1]
stores[reused].alive,stores[reused].full=true,'TextBlock /Game/Maps/Next.Other'
n=#calls
old_card.name.set('Someone'); old_card.hp.set(10,100)
assert(stores[reused].text~='Someone')
for j=n+1,#calls do assert(not calls[j]:find('^TextBlock%.Set') and not calls[j]:find('^CanvasPanelSlot'),calls[j]) end
local before,card_built=#constructed,views.card_built
assert(k.view('card')==old_card,'Until the next tick')
k.slow(true)
assert(#viewport==1 and viewport[1]~=root and #constructed>before and views.card_built==card_built+1,'Built again')
local root2=viewport[1]
n=#calls; k.tick(clock+0.05); assert(#calls==n,'The tween went with the old root')
assert(k.view('card')~=old_card and saved==stores[root2].full:match('^%S+ (.+)$'))
local groups2=stores[stores[stores[root2].props.WidgetTree].props.RootWidget].children
assert(vis(groups2[1])==3 and vis(groups2[2])==4 and stores[groups2[2]].last.SetRenderScale[1].X==0.75,
    'Shown as before, scaled as before')
assert(stores[groups2[1]].last.SetRenderOpacity[1]==0.45,'Faded as before')
k.show('menu',false)
-- Out of the viewport but not freed yet: taken out, one new root.
viewport={}
k.slow(true)
assert(#viewport==1 and viewport[1]~=root2 and stores[root2].last.RemoveFromParent)
-- Assets freed with the map (one's address now holding another object): the new root at once, flat where it uses
-- one (the dots); they are looked up again, one a tick, then it is built again with them.
local root3=viewport[1]
viewport={}
stores[asset('Mideum')].alive=false
registry[PATHS.Mideum]=object('Mideum')
stores[asset('dot')].full='Texture2D /Game/Maps/Next.Other'
registry[PATHS.dot]=object('dot')
k.slow(true)
assert(#viewport==1 and viewport[1]~=root3 and #textured('dot')==0 and logs[#logs]:find('while its look warms'))
local root4=viewport[1]
k.slow(true)
assert(calls[#calls]=='Mideum.GetFullName','The font looked up again')
k.slow(true)
assert(calls[#calls]=='dot.GetFullName','The dots')
k.slow(true)
assert(#viewport==1 and viewport[1]~=root4 and #textured('dot')==1 and stores[root4].last.RemoveFromParent,
    'Built again with the dots found again')
-- One no group uses freed (the QWERTY move icon): built at once with its look, found again later.
viewport={}
stores[asset('key_move')].alive=false
k.slow(true)
assert(#viewport==1 and logs[#logs]:find('^UI built: '),logs[#logs])
-- A group added later: built again with it.
k.add('feed',{x=96,y=330,w=1200,h=400,shown=true},function(b) return {line=b.text(0,0,'Alex joined.','body')} end)
k.slow(true)
assert(#viewport==1 and k.view('feed') and text('Alex joined.').font.FontObject==asset('Mideum'))
assert(text('Alex joined.').font.Size==34)

-- Hidden (no world: the title screen, a pause, photo mode): the root collapsed once, no views, no build; back, shown.
local r=viewport[1]
k.slow(false)
assert(vis(r)==1 and k.view('card')==nil and not k.ready() and not k.off(),'Hidden, not off: no fallback')
n=#calls; k.slow(false); assert(#calls==n,'Nothing while hidden')
k.slow(true)
assert(vis(r)==4 and k.view('card') and viewport[1]==r)

-- coop off: the root goes, its path too; nothing after.
k.stop()
assert(#viewport==0 and saved==nil and k.view('card')==nil)
n=#calls; k.slow(true); k.tick(clock+1); k.sound('open'); k.show('menu',true,clock); k.scale(90); k.stop()
assert(#calls==n and k.slow(true)==nil,'Nothing after coop off')

-- Ctrl+R: the root an earlier Lua load left is swept by its path (the tick's one lookup), only when it is one.
reset()
local left=object('UserWidget')
viewport[1]=left
registry['/Engine/Transient.Left']=left
saved='/Engine/Transient.Left'
k=kit()
k.slow(true)
assert(#viewport==0 and saved==nil and logs[1]=='removed the UI an earlier Lua load left on screen',logs[1])
assert(count('find ')==1 and #constructed==0)
up(k)
assert(#viewport==1)
reset()
local actor=object('Actor')
registry['/Game/Maps/E04.Actor_1']=actor
saved='/Game/Maps/E04.Actor_1'
k=kit()
k.slow(true)
assert(not stores[actor].last.RemoveFromParent and saved==nil and #logs==0,'Not a widget: left alone')

-- The first engine error turns the kit off: the root out, its path forgotten, views nil (the callers keep the line
-- above EVE and the name tag), the reason once; then no engine call at all.
local OFF='UI off until the mod reloads: %s; notices stay on the line above EVE'
for _,case in ipairs({{'CanvasPanelSlot.SetPosition','bad slot'},{'UserWidget.AddToViewport','no game viewport'},
        {'construct Image',nil}}) do
    reset()
    raise[case[1]]=case[2] or true
    k=kit()
    local ok,why
    for _=1,100 do
        ok,why=k.slow(true)
        if ok~=nil then break end
    end
    assert(ok==false and why==OFF:format(case[2] or 'Image not constructed'),tostring(why))
    assert(#viewport==0 and saved==nil and k.view('card')==nil and not k.ready() and k.off())
    n=#calls
    assert(k.slow(true)==nil and k.tick(clock)==nil,'Said once')
    k.sound('open'); k.show('menu',true,clock); k.scale(130)
    assert(#calls==n,'Nothing after')
end
-- In an update: off at once, said at the next tick of either loop.
reset()
k=kit()
up(k)
raise['TextBlock.SetText']='stale text'
k.view('card').name.set('Kaanta')
assert(#viewport==0 and saved==nil and k.view('card')==nil)
local ok,why=k.tick(clock)
assert(ok==false and why==OFF:format('stale text') and k.slow(true)==nil and k.off())
-- In a projection: off, and no half a view (partner.place would raise in the 1 ms loop).
reset()
k=kit()
up(k)
stores[pc].props.PlayerCameraManager=object('PlayerCameraManager')
special['WidgetLayoutLibrary.GetViewportSize']=function() return {X=1920,Y=1080} end
special['WidgetLayoutLibrary.GetViewportScale']=function() return 0.5 end
special['*.GetCameraLocation']=function() return {X=0,Y=0,Z=0} end
special['*.GetCameraRotation']=function() return {Pitch=0,Yaw=0,Roll=0} end
raise['PlayerCameraManager.GetFOVAngle']='no FOV'
assert(k.project({X=1,Y=0,Z=0},clock)==nil and k.off() and select(2,k.tick(clock))==OFF:format('no FOV'))
special['*.GetCameraLocation'],special['*.GetCameraRotation']=nil,nil
-- In a view's own build (a set there): the build stops at once; nothing reaches the viewport or is kept.
reset()
k=kit()
k.add('bad',{x=0,y=0,w=10,h=10,shown=true},function(b)
    local t=b.text(0,0,'a','body')
    raise['TextBlock.SetText']='no FText'
    t.set('b')
    raise['TextBlock.SetText']=nil
end)
for _=1,20 do ok,why=k.slow(true); if ok~=nil then break end end
assert(ok==false and why==OFF:format('no FText') and k.off(),tostring(why))
assert(#viewport==0 and saved==nil and not at('UserWidget.SetOwningPlayer') and not at('UserWidget.AddToViewport'))
n=#calls; k.stop(); k.slow(true); assert(#calls==n)
-- A UMG class missing: off before anything is constructed.
reset()
registry['/Script/UMG.ProgressBar']=nil
k=kit()
for _=1,20 do ok,why=k.slow(true); if ok~=nil then break end end
assert(ok==false and why:find('ProgressBar') and #constructed==0,tostring(why))

-- A look that cannot be had only degrades, said once a build: Roboto for a missing font, SetFont when the in-place
-- write raises, the default font when neither takes; white text when its colour cannot be set; flat colour for a
-- missing texture or a brush that does not tile; no image for a missing key icon or rail.
reset()
registry[PATHS.Bold]=nil
modes.Brush='copy'
registry[PATHS.key_escape]=nil
k=kit()
up(k)
assert(text('CO-OP').font.FontObject==asset('Roboto') and text('CO-OP').font.Size==56,'Roboto for Bold')
assert(text('Alex').font.FontObject==asset('Roboto'))
assert(logs[#logs]:find('; look: Bold missing %(Roboto%), brush tiling did not take, key_escape missing$'),
    logs[#logs])
assert(count('Image.SetBrushFromTexture')==#textured('cube0')*5+#textured('key_enter')+#textured('key_move')
    +#textured('link')+#textured('chevron') and #textured('dot')==0,'Only the untiled images get their texture')
reset()
modes.Font='raise'
k=kit()
up(k)
assert(text('CO-OP').font.FontObject==asset('Bold') and count('TextBlock.SetFont')==#of('TextBlock'),'Through SetFont')
reset()
modes.Font='raise'; modes.SetFont='no overload'
raise['TextBlock.SetColorAndOpacity']='no FSlateColor'
k=kit()
up(k)
assert(text('CO-OP').font.Size==24 and k.ready(),'The default font stays')
assert(logs[#logs]:find('font writes refused %(default font%)') and logs[#logs]:find('text colour refused %(white%)'),
    logs[#logs])
assert(count('TextBlock.SetColorAndOpacity')==1,'Tried once')
k.view('menu').row.set('Host a session','','disabled')
assert(count('TextBlock.SetColorAndOpacity')==1 and k.ready(),'Not again, and the UI stays')
reset()
registry[PATHS.dot]=nil; registry[PATHS.dot_bg]=nil; registry[PATHS.key_move_azerty]=nil; registry[PATHS.link]=nil
k=kit({azerty=true})
up(k)
local flat=0
for _,o in ipairs(of('Image')) do
    local s=stores[o]
    if not s.brush.ResourceObject and s.last.SetColorAndOpacity[1]==T.teal and size(o)=='0x45' then flat=flat+1 end
end
assert(flat==1,'The HP dots as flat teal')
local hidden_key=0
for _,o in ipairs(of('Image')) do if size(o)=='66x66' and vis(o)==1 then hidden_key=hidden_key+1 end end
assert(hidden_key==1,'No icon for a missing key, the label stays')
local dots={}
for _,o in ipairs(of('Image')) do if size(o)=='20x20' then dots[#dots+1]=o end end
k.view('card').dot.show(true)
assert(#dots==1 and vis(dots[1])==1,'Nor a white square for a missing image, shown or not')
-- The move keys' icon without azerty=: ZQSD when the game's language is French (its players' AZERTY keyboards), WASD
-- in any other language or when it is unread. Both are true on any layout: W, A and Z, Q all move. azerty= decides
-- when given.
for _,case in ipairs({{'fr-FR',nil,'key_move_azerty'},{'fr',nil,'key_move_azerty'},{'en-US',nil,'key_move'},
        {false,nil,'key_move'},{'fr-FR',false,'key_move'},{'en-US',true,'key_move_azerty'}}) do
    reset()
    special['KismetInternationalizationLibrary.GetCurrentLanguage']=function()
        if not case[1] then error('unread',0) end
        return case[1]
    end
    k=kit({azerty=case[2]})
    up(k)
    local other=case[3]=='key_move' and 'key_move_azerty' or 'key_move'
    assert(#textured(case[3])==1 and #textured(other)==0,tostring(case[1])..' '..tostring(case[2]))
end
special['KismetInternationalizationLibrary.GetCurrentLanguage']=nil
-- A sound not in this build: silent, never looked up again.
reset()
registry[PATHS.alert]=nil
k=kit()
up(k)
for _=1,SOUNDS+2 do k.slow(true) end
n=count('find ')
k.sound('alert')
for _=1,5 do k.slow(true) end
assert(count('find ')==n and not stores[registry['/Script/Engine.Default__GameplayStatics']].last.PlaySound2D)

-- A missing cube texture: that quarter never shows, even lit (no flat square).
reset()
registry[PATHS.cube4]=nil
k=kit()
up(k)
k.view('card').be.set(800,1600)
local lit=0
for _,o in ipairs(of('Image')) do
    if size(o)=='30x30' and vis(o)==3 then lit=lit+1; assert(stores[o].brush.ResourceObject,'No textureless cube') end
end
assert(lit==8+4*3,'8 bases, and 3 quarters on each of the 4 full cubes')

-- The chevron missing: the HUD's triangle instead, no look note; neither: none (no white square).
reset()
registry[PATHS.chevron]=nil
k=kit()
up(k)
local alt=registry[ALT.chevron]
local found=0
for _,o in ipairs(of('Image')) do if stores[o].brush.ResourceObject==alt then found=found+1 end end
assert(found==1 and not logs[#logs]:find('chevron'),logs[#logs])
reset()
registry[PATHS.chevron],registry[ALT.chevron]=nil,nil
k=kit()
up(k)
assert(logs[#logs]:find('chevron missing'),logs[#logs])

-- An inside group (the partner HUD's card, marker and arrow): where it is moved, but its box, scaled around its pivot
-- by ui_scale, kept 48 units inside the viewport in layout units (its left and top edges win when it does not fit);
-- on change only; as asked while the viewport is unread. The viewport is read once a second and logged when its size
-- changes. A text's alignment is its slot's.
reset()
special['WidgetLayoutLibrary.GetViewportSize']=function() return {X=1920,Y=1080} end
special['WidgetLayoutLibrary.GetViewportScale']=function() return 0.5 end
k=Ui.kit({store=store,log=function(m) logs[#logs+1]=m end})
k.add('tag',{x=0,y=0,w=320,h=120,pivot={X=0.5,Y=1},shown=true,inside=true},function(b)
    b.text(10,22,'Alex','name',T.teal,{X=0,Y=0.5})
end)
up(k)
local tag=stores[stores[stores[viewport[1]].props.WidgetTree].props.RootWidget].children[1]
local function placed(x,y) local p=stores[stores[tag].slot].last.SetPosition[1]; return p.X==x and p.Y==y end
assert(stores[stores[of('TextBlock')[1]].slot].last.SetAlignment[1].Y==0.5,'Centred on its line')
k.move('tag',1000,500)
assert(placed(1000,500) and logs[#logs]=='UI viewport: 3840x2160 units (1920x1080 pixels at DPI scale 0.5)',
    logs[#logs])
k.move('tag',-100,-50); assert(placed(48,48))
k.move('tag',3800,2100); assert(placed(3840-48-320,2160-48-120),pos(tag))
n=#calls; k.move('tag',3800,2100); assert(#calls==n,'On change only')
k.scale(150) -- 480 by 180 around its bottom centre: 80 units more each side, 60 more above.
k.move('tag',3800,2100); assert(placed(3392,1992),pos(tag))
k.move('tag',0,0); assert(placed(128,108),pos(tag))
special['WidgetLayoutLibrary.GetViewportSize']=function() return {X=200,Y=100} end
special['WidgetLayoutLibrary.GetViewportScale']=function() return 1 end
k.move('tag',500,500); assert(placed(500,500),'Read once a second')
clock=clock+1
k.move('tag',500,500); assert(placed(128,108),'Too small: its left and top edges win')
special['WidgetLayoutLibrary.GetViewportScale']=function() return 0 end
clock=clock+1
k.move('tag',700,600); assert(placed(700,600) and k.ready(),'Unread: as asked')
-- most: a group's largest scale (the status strip above the partner card): ui_scale past it draws it at most, at a
-- build and on change, and only on a change of its own scale.
reset()
k=Ui.kit({store=store,scale=150,log=function(m) logs[#logs+1]=m end})
k.add('strip',{x=96,y=8,w=744,h=84,most=1,shown=true},function() end)
k.add('box',{x=0,y=0,w=10,h=10,shown=true},function() end)
up(k)
local strip,box=table.unpack(stores[stores[stores[viewport[1]].props.WidgetTree].props.RootWidget].children)
assert(not stores[strip].last.SetRenderScale and stores[box].last.SetRenderScale[1].X==1.5,'Built at most 100 %')
k.scale(120)
assert(not stores[strip].last.SetRenderScale and stores[box].last.SetRenderScale[1].X==1.2,'Still past it: no call')
k.scale(80); assert(stores[strip].last.SetRenderScale[1].X==0.8 and stores[box].last.SetRenderScale[1].X==0.8)
k.scale(150); assert(stores[strip].last.SetRenderScale[1].X==1 and stores[box].last.SetRenderScale[1].Y==1.5)

-- Hidden from the start (the title screen): nothing looked up or built, however long.
reset()
k=kit()
for _=1,50 do k.slow(false) end
assert(#constructed==0 and count('find ')==0 and not k.off())
-- A player controller handle that now holds another object: no build.
reset()
pc=object('Actor')
k=kit()
for _=1,60 do k.slow(true) end
assert(#constructed==0 and #viewport==0)
-- No hit group (the HUD only): the root lets every hit through.
reset()
k=Ui.kit({store=store,log=function(m) logs[#logs+1]=m end})
k.add('card',{x=96,y=96,w=760,h=210,shown=true},function(b) b.panel(0,0,760,210) end)
up(k)
assert(vis(viewport[1])==3 and vis(of('Border')[1])==nil)

-- Addresses reused after a map change (the root and the menu's canvas now other objects): a sound, hidden, moved,
-- shown with its tween, coop off: not one call reaches them.
reset()
k=kit()
up(k)
for _=1,SOUNDS do k.slow(true) end
local r0=viewport[1]
local menu0=stores[stores[stores[r0].props.WidgetTree].props.RootWidget].children[2]
for _,o in ipairs(constructed) do stores[o].alive=false end
for _,o in ipairs({r0,menu0}) do
    local s=stores[o]
    s.alive,s.full,s.last=true,s.class..' /Game/Maps/Next.Other',{}
end
stores[stores[menu0].slot].last={}
n=#calls
k.sound('open'); k.slow(false); k.move('menu',10,10); k.show('menu',true,clock)
clock=clock+0.05; k.tick(clock); k.stop()
assert(next(stores[r0].last)==nil and next(stores[menu0].last)==nil and next(stores[stores[menu0].slot].last)==nil)
assert(not at('GameplayStatics.PlaySound2D',n),'No root of ours: no sound')

-- A root that keeps leaving the viewport: built again 3 times in a row, then off (no rebuild storm); one lost every
-- other tick never trips it.
reset()
k=kit()
up(k)
for _=1,10 do viewport={}; k.slow(true); assert(#viewport==1); k.slow(true) end
local card_builds=views.card_built
for _=1,3 do viewport={}; assert(k.slow(true)==nil and #viewport==1) end
viewport={}
ok,why=k.slow(true)
assert(ok==false and why==OFF:format('the UI root keeps leaving the viewport') and views.card_built==card_builds+3)
-- The build with the look waits while the menu is open (its rows under the mouse), and comes once it closes.
reset()
k=kit()
for _=1,#UMG+6 do k.slow(true) end
assert(#viewport==1 and #logs==1 and logs[1]:find('while its look warms'))
k.show('menu',true)
for _=1,60 do k.slow(true) end
assert(#logs==1,'Not built again while open')
k.show('menu',false)
k.slow(true)
assert(#logs==2 and logs[2]:find('^UI built: '),logs[2])
-- Nor while our UI holds the game's input with no hit group shown (the host's question): the input focused that root.
reset()
k=kit()
for _=1,#UMG+6 do k.slow(true) end
assert(#viewport==1 and #logs==1 and k.holding()==false)
k.input(true,'card')
assert(k.holding()==true)
for _=1,60 do k.slow(true) end
assert(#logs==1 and #viewport==1,'Not built again while it holds the input')
k.input(false,'card')
k.slow(true)
assert(#logs==2 and logs[2]:find('^UI built: '),logs[2])


-- The menu's input: the game's keys off while open (UIOnlyEx on our root, no mouse lock), back on at close; each once;
-- not before the root is up; back on when the kit turns off by a fault, or at coop off.
reset()
k=kit()
local LIB='WidgetBlueprintLibrary.'
k.input(true)
assert(count(LIB..'SetInputMode')==0,'No root yet: nothing')
up(k)
k.input(true); k.input(true)
local uionly=stores[registry['/Script/UMG.Default__WidgetBlueprintLibrary']].last.SetInputMode_UIOnlyEx
assert(count(LIB..'SetInputMode_UIOnlyEx')==1 and uionly[1]==pc and uionly[2]==viewport[1] and uionly[3]==0)
k.input(false); k.input(false)
assert(count(LIB..'SetInputMode_GameOnly')==1
    and stores[registry['/Script/UMG.Default__WidgetBlueprintLibrary']].last.SetInputMode_GameOnly[1]==pc)
k.input(true)
raise['ProgressBar.SetPercent']='boom'
k.view('menu').bar.set(0.5)
assert(k.off() and count(LIB..'SetInputMode_GameOnly')==2,'A fault gives the game its input back')
k.input(true); k.input(false)
assert(count(LIB..'SetInputMode')==4,'Nothing once off')
reset()
k=kit()
up(k)
k.input(true); k.stop()
assert(count(LIB..'SetInputMode_GameOnly')==1,'coop off too')
-- coop ui reset: given back now whoever holds it, even when the kit thinks the game has it; without a player
-- controller, still due (the menu's next input(false) tries again); the kit off too.
reset()
k=kit()
up(k)
k.input(true,'chat'); k.reset()
assert(count(LIB..'SetInputMode_GameOnly')==1,'The chat held it')
k.input(false,'chat')
assert(count(LIB..'SetInputMode_GameOnly')==1,"The chat's late give-back: nothing left to give")
k.reset()
assert(count(LIB..'SetInputMode_GameOnly')==2,'Again, though the game had it')
local held=pc
pc=nil
k.reset(); k.input(false)
assert(count(LIB..'SetInputMode_GameOnly')==2,'No player controller: due')
pc=held
k.input(false); k.input(false)
assert(count(LIB..'SetInputMode_GameOnly')==3,'Given back once there is one, once')
k.stop(); k.reset()
assert(count(LIB..'SetInputMode_GameOnly')==4,'The kit off too')
reset()
k=kit()
up(k)
k.input(true)
raise[LIB..'SetInputMode_GameOnly']='refused'
k.input(false)
assert(k.off(),'A refused input change turns the kit off, once')
assert(count(LIB..'SetInputMode_GameOnly')==1,'Not tried again by the fault')
-- Given back only to a player controller (after a map change UEHelpers' cached address may hold another object), and
-- still due while there is none: tried again at the next input(false), the kit off too.
reset()
k=kit()
up(k)
k.input(true)
local real=pc
pc=object('Actor')
k.input(false)
pc=nil
k.input(false)
assert(count(LIB..'SetInputMode_GameOnly')==0,'Not on an Actor, nor without a player controller')
pc=real
k.input(false); k.input(false)
assert(count(LIB..'SetInputMode_GameOnly')==1,'Given back once there is one')
k.input(true)
pc=nil
raise['ProgressBar.SetPercent']='boom'
k.view('menu').bar.set(0.5)
assert(k.off() and count(LIB..'SetInputMode_GameOnly')==1)
pc=real
k.input(false); k.input(false)
assert(count(LIB..'SetInputMode_GameOnly')==2,'Still given back once the kit is off')
-- Ctrl+R with the menu open: the old load's input mode and mouse cursor stay in the game, so its path says so and the
-- new load gives the input back and puts the cursor back as it found it, as it sweeps the root (or later, with no
-- player controller yet).
-- A record from before the cursor: the input only.
reset()
k=kit()
up(k)
local root_path=saved
pc.bShowMouseCursor=false
k.input(true)
assert(saved==root_path..' input cursor','The input and the cursor marked with the path')
k.input(false)
assert(saved==root_path)
k.input(true)
registry[root_path]=viewport[1]
local reloaded=kit()
reloaded.slow(true)
assert(#viewport==0 and count(LIB..'SetInputMode_GameOnly')==2 and saved==nil,'Swept, the input given back')
assert(pc.bShowMouseCursor==false,'The cursor hidden again')
reloaded.stop()
assert(count(LIB..'SetInputMode_GameOnly')==2,'Once')
saved=root_path..' input cursor'
pc=nil
reloaded=kit()
reloaded.slow(true)
pc=real
pc.bShowMouseCursor=true
assert(count(LIB..'SetInputMode_GameOnly')==2)
reloaded.input(false)
assert(count(LIB..'SetInputMode_GameOnly')==3 and pc.bShowMouseCursor==false,
    'Still due: given back, the cursor hidden, once there is a player controller')
saved=root_path..' input'
reloaded=kit()
reloaded.slow(true)
pc.bShowMouseCursor=true
reloaded.input(false)
assert(count(LIB..'SetInputMode_GameOnly')==4 and pc.bShowMouseCursor==true,'An older record: the cursor untouched')
-- The guide on the title screen, whose menu shows the mouse cursor: the record says the cursor was shown, and the next
-- load leaves it shown as it gives the input back.
reset()
k=kit()
up(k)
root_path=saved
k.slow(true,true)
pc.bShowMouseCursor=true
k.input(true,'guide',true)
assert(saved==root_path..' input cursor shown','The cursor shown before: said')
registry[root_path]=viewport[1]
reloaded=kit()
reloaded.slow(true,true)
assert(#viewport==0 and count(LIB..'SetInputMode_GameAndUIEx')==1 and pc.bShowMouseCursor==true,'Shown again')
-- At the title (the co-op saves' question), given back as GameAndUIEx with no widget, no mouse lock and the cursor
-- kept, so the title menu keeps its mouse; GameOnly when the engine refuses it (the kit stays on); in a world GameOnly.
reset()
k=kit()
up(k)
k.slow(true,true)
k.input(true); k.input(false)
local gameui=stores[registry['/Script/UMG.Default__WidgetBlueprintLibrary']].last.SetInputMode_GameAndUIEx
assert(count(LIB..'SetInputMode_GameAndUIEx')==1 and count(LIB..'SetInputMode_GameOnly')==0 and gameui[1]==pc
    and gameui[2]==nil and gameui[3]==0 and gameui[4]==false,'The title: GameAndUI')
raise[LIB..'SetInputMode_GameAndUIEx']='no overload'
k.input(true); k.input(false)
assert(not k.off() and count(LIB..'SetInputMode_GameOnly')==1,'Refused: GameOnly, the kit still on')
k.slow(true,false)
k.input(true); k.input(false)
assert(count(LIB..'SetInputMode_GameAndUIEx')==2 and count(LIB..'SetInputMode_GameOnly')==2,'A world: GameOnly')
k.slow(true,true)
k.input(true); k.reset()
assert(count(LIB..'SetInputMode_GameAndUIEx')==3,'coop ui reset at the title too')
-- The menu's mouse cursor: shown while the menu holds the game's input (set after its input mode), never for a group's
-- field; the value found put back when it gives the input back, when a field takes it, at coop ui reset and when the
-- kit stops. paused() never reads our own cursor as a game screen.
reset()
k=kit()
up(k)
pc.bShowMouseCursor=false
n=#calls
k.input(true)
assert(pc.bShowMouseCursor==true and at('set PC.bShowMouseCursor',n)>at(LIB..'SetInputMode_UIOnlyEx',n),
    'Shown after the input mode')
assert(k.paused()==false,'Our own cursor is no game screen')
special['GameplayStatics.IsGamePaused']=function() return true end
assert(k.paused()==true,'The game paused still reads')
special['GameplayStatics.IsGamePaused']=nil
k.input(false)
assert(pc.bShowMouseCursor==false and k.paused()==false,'Hidden again')
k.input(true,'chat'); assert(pc.bShowMouseCursor==false,"Not for the chat's box")
k.input(true); assert(pc.bShowMouseCursor==true,'The menu over a closing chat')
k.input(true,'chat'); assert(pc.bShowMouseCursor==false,'The chat took it from the menu: hidden')
k.input(false,'chat')
pc.bShowMouseCursor=true
k.input(true); k.input(false); assert(pc.bShowMouseCursor==true,'The value found: shown stays shown')
assert(k.paused()==true,'Not ours: a game screen')
pc.bShowMouseCursor=false
k.input(true); k.reset(); assert(pc.bShowMouseCursor==false,'coop ui reset')
-- A group that asks for it (the guide, in a world) shows it too; one that takes the input from it without asking hides
-- it again.
k.input(true,'guide',true); assert(pc.bShowMouseCursor==true and k.paused()==false,'The guide asks: shown')
k.input(true,'chat'); assert(pc.bShowMouseCursor==false,'The chat took it from the guide: hidden')
k.input(false,'chat')
-- An image's texture made at run time (the guide's art): its brush takes it, matched (true); a refused call only
-- returns false, the kit stays on.
local made,dot=object('Texture2D'),nil
for _,o in ipairs(of('Image')) do if stores[o].brush.ResourceObject==asset('link') then dot=o end end
assert(dot and k.view('card').dot.texture(made)==true and stores[dot].brush.ResourceObject==made)
raise['Image.SetBrushFromTexture']='refused'
assert(k.view('card').dot.texture(made)==false and not k.off() and k.view('card'),'Refused: false, the kit on')
raise['Image.SetBrushFromTexture']=nil
k.input(true); k.stop(); assert(pc.bShowMouseCursor==false,'coop off')
-- The game paused or showing the mouse cursor (a screen of its own), or not (false when unread), and its language
-- (nil when unread); nothing once off, where the language is the last one read (the fallback notices keep it), and
-- the pause only when asked always.
reset()
k=kit()
pc.bShowMouseCursor=false
assert(k.paused()==false)
pc.bShowMouseCursor=true
assert(k.paused()==true,'A screen of the game that does not pause')
pc.bShowMouseCursor=false
special['GameplayStatics.IsGamePaused']=function(_,_,context) assert(context==pc); return true end
special['KismetInternationalizationLibrary.GetCurrentLanguage']=function() return 'fr-FR' end
assert(k.paused()==true and k.language()=='fr-FR')
raise['GameplayStatics.IsGamePaused']='no world'
raise['KismetInternationalizationLibrary.GetCurrentLanguage']='gone'
assert(k.paused()==false and k.language()==nil)
special['GameplayStatics.IsGamePaused'],special['KismetInternationalizationLibrary.GetCurrentLanguage']=nil,nil
k.stop()
n=#calls
assert(k.paused()==false and k.language()=='fr-FR' and #calls==n)
raise['GameplayStatics.IsGamePaused']=nil
special['GameplayStatics.IsGamePaused']=function() return true end
assert(k.paused(true)==true,'Off, always still reads the pause')
special['GameplayStatics.IsGamePaused']=nil

-- The focus watchdog. The root is made focusable before AddToViewport, so the input mode focuses it. While our UI
-- holds the game's input and the world shows, each slow reads whether the root or a widget in it has the focus: armed
-- by a first yes since the input was taken, then 1 s of no (a yes starts it over) fires it once: lost() is true once,
-- with who held the input. Never armed 2 s after the take: one log line a Lua load, nothing fires. A read that raises
-- counts for nothing. A refused bIsFocusable: one log line a Lua load, nothing read.
;(function()
    local has,below=false,false -- The root's own focus, a widget's in it (the chat's box), as the engine reads them.
    special['UserWidget.HasAnyUserFocus']=function() return has end
    special['UserWidget.HasFocusedDescendants']=function() return below end
    local function last(name) for i=#calls,1,-1 do if calls[i]==name then return i end end end
    local function lines(text) local c=0; for _,m in ipairs(logs) do if m==text then c=c+1 end end return c end
    local NEVER='focus watchdog: our root never took the focus'
    reset()
    local k=kit()
    local function quarter() clock=clock+0.25; k.slow(true) end
    up(k)
    assert(stores[viewport[1]].props.bIsFocusable==true and last('set UserWidget.bIsFocusable')<last('UserWidget.'
        ..'AddToViewport') and last('set UserWidget.bIsFocusable')>last('construct UserWidget'),
        'Focusable, set before AddToViewport')
    for _=1,8 do quarter() end
    assert(count('UserWidget.HasAnyUserFocus')==0,'The game has its input: nothing read')
    k.input(true)
    has=true; quarter(); has=false
    for _=1,4 do quarter() end
    assert(k.lost()==false,'Not before 1 s')
    quarter()
    local lost,who=k.lost()
    assert(lost==true and who=='menu','1 s without the focus')
    assert(k.lost()==false,'Once')
    for _=1,8 do quarter() end
    assert(k.lost()==false,'Not again for that take')
    -- A yes in between starts the second over; the chat's box (a widget in the root) holds the focus too.
    k.input(true,'chat')
    below=true; quarter(); below=false; quarter(); quarter(); below=true; quarter(); below=false
    for _=1,4 do quarter() end
    assert(k.lost()==false,'Started over')
    quarter()
    lost,who=k.lost()
    assert(lost and who=='chat')
    -- Never armed: nothing fires; one line 2 s after the take, once a Lua load.
    k.input(false,'chat'); k.input(true)
    for _=1,7 do quarter() end
    assert(lines(NEVER)==0,'Not before 2 s')
    quarter()
    assert(lines(NEVER)==1)
    for _=1,12 do quarter() end
    k.input(false); k.input(true)
    for _=1,12 do quarter() end
    assert(k.lost()==false and lines(NEVER)==1,'Never armed: nothing fires, said once')
    -- A read that raises, the world hidden, the input given back: nothing read or counted.
    has=true; quarter(); has=false
    raise['UserWidget.HasAnyUserFocus']='no slate widget'
    for _=1,8 do quarter() end
    raise['UserWidget.HasAnyUserFocus']=nil
    assert(k.lost()==false and not k.off(),'A raise: nothing')
    local n=count('UserWidget.HasAnyUserFocus')
    for _=1,8 do clock=clock+0.25; k.slow(false) end
    assert(count('UserWidget.HasAnyUserFocus')==n and k.lost()==false,'Hidden: nothing read')
    k.input(false)
    for _=1,8 do quarter() end
    assert(count('UserWidget.HasAnyUserFocus')==n and k.lost()==false,'Given back: nothing read')
    -- A mouse button while our UI holds the input (Slate gives a click on none of our widgets to the game's viewport):
    -- the root focused again 50 ms later, once, and the second starts over; nothing while the game has its input.
    k.click(); clock=clock+0.0625; k.tick(clock)
    assert(count('UserWidget.SetKeyboardFocus')==0,'The game has its input: nothing')
    k.input(true)
    has=true; quarter(); has=false
    for _=1,3 do quarter() end
    k.click(); clock=clock+0.03125; k.tick(clock)
    assert(count('UserWidget.SetKeyboardFocus')==0,'Not before 50 ms')
    clock=clock+0.03125; k.tick(clock)
    assert(count('UserWidget.SetKeyboardFocus')==1 and stores[viewport[1]].last.SetKeyboardFocus,'Our root focused')
    clock=clock+0.0625; k.tick(clock)
    assert(count('UserWidget.SetKeyboardFocus')==1,'Once a click')
    for _=1,4 do quarter() end
    assert(k.lost()==false,'1 s from the click only')
    quarter()
    assert(k.lost()==true,'Still lost: fired')
    k.input(false)
    -- Refused: said once a Lua load (two builds), the watchdog unarmed, nothing read.
    reset()
    raise['set UserWidget.bIsFocusable']='no such property'
    k=kit()
    up(k)
    assert(not k.off() and lines('focus watchdog off: the UI root refused bIsFocusable (no such property)')==1,
        table.concat(logs,'|'))
    k.input(true)
    for _=1,20 do quarter() end
    assert(count('UserWidget.HasAnyUserFocus')==0 and lines(NEVER)==0 and k.lost()==false)
    special['UserWidget.HasAnyUserFocus'],special['UserWidget.HasFocusedDescendants']=nil,nil
end)()

-- The chat box (b.field): an EditableTextBox that keeps its keyboard focus on Enter and reverts on Esc, in Mideum 34,
-- white on the dark glass, with its hint, all set before AddToViewport; it takes the mouse in its hit group (a click
-- focuses it). input(true, 'chat') puts the game's input on it with its keyboard focus. Who holds the input gives it
-- back: the menu's late give-back (150 ms after its close) never takes the chat's, nor the chat's the menu's. Its text
-- read through GetText, emptied, focused again, its hint changed. A refused style or property only degrades.
local function last_at(name) for i=#calls,1,-1 do if calls[i]==name then return i end end end
local function chat_kit()
    local ck=Ui.kit({store=store,log=function(m) logs[#logs+1]=m end})
    ck.add('menu',{x=180,y=330,w=1500,h=1500,hit=true},function(b) return {row=b.row(24,130,1452,600)} end)
    ck.add('chat',{x=96,y=330,w=1300,h=660,hit=true},function(b)
        b.panel(0,0,1300,660)
        return {box=b.field(24,572,1252,56,'Message')}
    end)
    return ck
end
reset()
k=chat_kit()
up(k)
local cells={}
for _,o in ipairs(of('TextBlock')) do cells[#cells+1]=pos(o) end
assert(table.concat(cells,' ')=='60,142 876,142','The co-op menu\'s row: its value in its last 600 units')
local box=of('EditableTextBox')[1]
local bs=stores[box]
assert(bs.props.ClearKeyboardFocusOnCommit==false and bs.props.RevertTextOnEscape==true)
assert(bs.style.Font.FontObject==asset('Mideum') and bs.style.Font.Size==34)
local fg,bg=bs.style.ForegroundColor,bs.style.BackgroundColor
assert(fg.ColorUseRule==0 and fg.SpecifiedColor.R==T.text.R and fg.SpecifiedColor.A==1)
assert(bg.ColorUseRule==0 and bg.SpecifiedColor.B==T.panel.B and bg.SpecifiedColor.A==T.panel.A)
assert(bs.last.SetHintText[1].text=='Message' and vis(box)==0 and pos(box)=='24,572' and size(box)=='1252x56')
local added=last_at('UserWidget.AddToViewport')
for _,c in ipairs({'set EditableTextBox.ClearKeyboardFocusOnCommit','set EditableTextBox.RevertTextOnEscape',
        'EditableTextBox.SetHintText','EditableTextBox.SetVisibility'}) do
    assert(last_at(c)<added,c..' before AddToViewport')
end
assert(logs[#logs]:find('^UI built: %d+ widgets in 0%.0 ms$'),logs[#logs])
local LIB='WidgetBlueprintLibrary.'
local lib=stores[registry['/Script/UMG.Default__WidgetBlueprintLibrary']]
k.input(true,'chat'); k.input(true,'chat')
assert(count(LIB..'SetInputMode_UIOnlyEx')==1 and lib.last.SetInputMode_UIOnlyEx[1]==pc
    and lib.last.SetInputMode_UIOnlyEx[2]==box and lib.last.SetInputMode_UIOnlyEx[3]==0)
assert(count('EditableTextBox.SetKeyboardFocus')==1
    and at('EditableTextBox.SetKeyboardFocus')>at(LIB..'SetInputMode_UIOnlyEx'))
k.input(false)
assert(count(LIB..'SetInputMode_GameOnly')==0,"The menu's late give-back: the chat holds the input")
k.input(true)
assert(count(LIB..'SetInputMode_UIOnlyEx')==2 and lib.last.SetInputMode_UIOnlyEx[2]==viewport[1],
    'The menu opened over a closing chat: the input on our root')
k.input(false,'chat')
assert(count(LIB..'SetInputMode_GameOnly')==0,"The chat's late give-back: the menu holds it")
k.input(false); k.input(false); k.input(false,'chat')
assert(count(LIB..'SetInputMode_GameOnly')==1 and lib.last.SetInputMode_GameOnly[1]==pc)
local root_path=saved
k.input(true,'chat')
assert(saved==root_path..' input','Ctrl+R with the box open gives the input back too')
k.input(false,'chat')
assert(count(LIB..'SetInputMode_GameOnly')==2 and saved==root_path)
local field=k.view('chat').box
bs.text='Bonjour é à ç'
assert(field.text()=='Bonjour é à ç')
field.set('')
assert(bs.text=='' and bs.last.SetText[1].text=='')
local focused=count('EditableTextBox.SetKeyboardFocus')
field.focus()
assert(count('EditableTextBox.SetKeyboardFocus')==focused+1)
field.hint('Indice')
assert(bs.last.SetHintText[1].text=='Indice')
-- A mouse button while the chat holds the input: its box focused again 50 ms later, not our root.
k.input(true,'chat')
focused=count('EditableTextBox.SetKeyboardFocus')
k.click(); clock=clock+0.0625; k.tick(clock)
assert(count('EditableTextBox.SetKeyboardFocus')==focused+1 and count('UserWidget.SetKeyboardFocus')==0)
k.input(false,'chat')
-- A root rebuilt (a map change): the box's handles never touch the freed one.
for _,o in ipairs(constructed) do stores[o].alive=false end
local n=#calls
field.set('x'); field.focus()
assert(field.text()=='' and not at('EditableTextBox.SetText',n) and not at('EditableTextBox.SetKeyboardFocus',n))
-- Refused: the colours (the background white again: Slate's own box, dark text on white, readable), the behaviour
-- flags, the hint; each said in the look line, the box built all the same.
reset()
modes.ForegroundColor='raise'
raise['set EditableTextBox.ClearKeyboardFocusOnCommit']='no such property'
raise['EditableTextBox.SetHintText']='no such function'
k=chat_kit()
up(k)
bs=stores[of('EditableTextBox')[1]]
assert(bs.style.BackgroundColor.SpecifiedColor.R==1 and bs.style.BackgroundColor.SpecifiedColor.A==1
    and bs.style.Font.Size==34 and not k.off())
assert(logs[#logs]:find('text box behaviour refused',1,true) and logs[#logs]:find('text box hint refused',1,true)
    and logs[#logs]:find('text box style refused (default box)',1,true),logs[#logs])
reset()
modes.WidgetStyle='no such property'
k=chat_kit()
up(k)
assert(stores[of('EditableTextBox')[1]].style.Font.Size==10 and not k.off()
    and logs[#logs]:find('text box style refused (default box)',1,true),logs[#logs])

-- A shade: flat colour that takes the mouse in a hit group (the co-op saves' question: no click reaches the title menu
-- under it), and lets it through elsewhere. Hidden with its group, never removed; whole() false while hidden.
reset()
k=Ui.kit({store=store,log=function(m) logs[#logs+1]=m end})
k.add('saves',{x=0,y=0,w=3840,h=2160,hit=true,pivot={X=0.5,Y=0.5}},function(b) b.shade(-1920,-1080,7680,4320,T.shade) end)
k.add('card',{x=96,y=96,w=760,h=210,shown=true},function(b) b.shade(0,0,10,10,T.panel) end)
up(k)
local shades=of('Image')
assert(#shades==2 and vis(shades[1])==0 and vis(shades[2])==nil,
    "It takes the mouse in the hit group only; the card's group lets hit tests through all it holds")
assert(pos(shades[1])=='-1920,-1080' and size(shades[1])=='7680x4320'
    and stores[shades[1]].last.SetColorAndOpacity[1]==T.shade)
assert(T.shade.A>0 and T.shade.A<1,'See-through')
k.slow(false)
assert(not k.whole() and not k.ready(),'Hidden')

print('ui_kit_test ok')
