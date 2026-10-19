-- The Uplink kit (ui.lua's Ui.kit) with fake UE4SS objects and clock: nothing at all until a group is added; the
-- assets warmed one lookup a 250 ms tick, the build in one call once the classes are in (default font and flat colour)
-- and again once the look's assets are in (sounds after; not while the menu is open), every group's widgets in place
-- before AddToViewport; the game's fonts, dots, cubes, key icons and colours; hit tests passing through all but the
-- menu's rows; updates only on change; groups hidden and shown again, never removed; the open (slide and flicker) and
-- close tweens in the 1 ms loop, and no engine call while none runs; the scale; the game's sounds; a new root after a
-- map change, its freed assets looked up again, the old handles never touching an address that holds another object;
-- no rebuild storm; the root an earlier Lua load left swept; the first engine error, in a build's own update too,
-- turning the kit off (off(): the notice line above EVE is the fallback); a look that cannot be had only degrading;
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
local Ui=require('ui')
local T=Ui.THEME
local PATHS={} -- Asset name to object path.
for _,a in ipairs(Ui.ASSETS) do PATHS[a[1]]=a[2] end
local function reset()
    for _,o in pairs(registry or {}) do stores[o].alive=false end -- unreal.lua's cache looks them up again.
    calls,raise,modes,viewport,registry,loadable,constructed,logs,saved,since={},{},{},{},{},{},{},{},nil,0
    clock=100
    pc=object('PC')
    registry['/Script/Engine.PlayerController']=object('PlayerController')
    registry['/Script/Engine.Default__GameplayStatics']=object('GameplayStatics')
    registry['/Script/UMG.Default__WidgetBlueprintLibrary']=object('WidgetBlueprintLibrary')
    registry['/Script/Engine.Default__KismetInternationalizationLibrary']=object('KismetInternationalizationLibrary')
    for _,c in ipairs({'UserWidget','WidgetTree','CanvasPanel','Border','TextBlock','Image','ProgressBar',
            'EditableTextBox'}) do
        registry['/Script/UMG.'..c]=object(c)
    end
    for _,a in ipairs(Ui.ASSETS) do registry[a[2]]=object(a[1]) end
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
            be=b.cubes(24,160,8,T.beta),dot=b.image(700,20,20,20,'link',T.teal)}
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
assert(PATHS.key_move_azerty=='/Game/Art/UI/Texture/Interaction/PC_ActionAssist/KeyIcon_KeyBoard_MoveAll_AZERTY.'
    ..'KeyIcon_KeyBoard_MoveAll_AZERTY' and PATHS.open=='/Game/Sound/UI/MainMenu/Ui_MoveIn_Cue.Ui_MoveIn_Cue')
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
        for _,o in ipairs(of('TextBlock')) do assert(stores[o].font.Size==24 and not stores[o].last.SetFont) end
        for _,o in ipairs(of('Image')) do assert(not stores[o].brush.ResourceObject) end
    end
end
-- Classes, the PC class and three libraries (GameplayStatics, the input modes, the language); then the assets.
assert(builds[1]==#UMG+5 and builds[2]==#UMG+5+#Ui.ASSETS-SOUNDS+1,table.concat(builds,' '))
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
assert(count('find ')==#UMG+4+#Ui.ASSETS and #calls-n==3 and calls[n+3]=='UserWidget.IsInViewport',
    'Then a still-ours, in-the-viewport check only')

-- The build: a plain UserWidget owned by the player, its tree and canvas by hand, a canvas a group; all in before
-- AddToViewport; its path kept for the next Lua load.
local root=viewport[1]
assert(stores[root].class=='UserWidget' and stores[root].outer==pc and stores[root].last.AddToViewport[1]==100)
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
assert(pos(textured('key_enter')[1])=='340,1400' and size(textured('key_enter')[1])=='48x48')
assert(pos(select(2,text('Select')))=='400,1404' and text('Select').font.Size==30,'Its label beside it')

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
menu.row.set('Host a session','','focus')
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

-- The game's sounds: PlaySound2D with our root as the world, volume, pitch 1, from the start; the chat line quieter;
-- off by the setting; a raise turns the sounds off only.
local statics=registry['/Script/Engine.Default__GameplayStatics']
k.sound('open')
local played=stores[statics].last.PlaySound2D
assert(played[1]==root and played[2]==asset('open') and played[3]==1 and played[4]==1 and played[5]==0 and #played==5)
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
    +#textured('link') and #textured('dot')==0,'Only the untiled images get their texture')
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
for _,o in ipairs(of('Image')) do if size(o)=='48x48' and vis(o)==1 then hidden_key=hidden_key+1 end end
assert(hidden_key==1,'No icon for a missing key, the label stays')
local dots={}
for _,o in ipairs(of('Image')) do if size(o)=='20x20' then dots[#dots+1]=o end end
k.view('card').dot.show(true)
assert(#dots==1 and vis(dots[1])==1,'Nor a white square for a missing image, shown or not')
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
-- No hit group (the HUD only): the root lets every hit through, as the spike's.
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
for _=1,#UMG+5 do k.slow(true) end
assert(#viewport==1 and #logs==1 and logs[1]:find('while its look warms'))
k.show('menu',true)
for _=1,60 do k.slow(true) end
assert(#logs==1,'Not built again while open')
k.show('menu',false)
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
-- Ctrl+R with the menu open: the old load's input mode stays in the game's viewport, so its path says so and the new
-- load gives the input back as it sweeps the root (or later, with no player controller yet).
reset()
k=kit()
up(k)
local root_path=saved
k.input(true)
assert(saved==root_path..' input','The input marked with the path')
k.input(false)
assert(saved==root_path)
k.input(true)
registry[root_path]=viewport[1]
local reloaded=kit()
reloaded.slow(true)
assert(#viewport==0 and count(LIB..'SetInputMode_GameOnly')==2 and saved==nil,'Swept, the input given back')
reloaded.stop()
assert(count(LIB..'SetInputMode_GameOnly')==2,'Once')
saved=root_path..' input'
pc=nil
reloaded=kit()
reloaded.slow(true)
pc=real
assert(count(LIB..'SetInputMode_GameOnly')==2)
reloaded.input(false)
assert(count(LIB..'SetInputMode_GameOnly')==3,'Still due: given back once there is a player controller')
-- The game paused or showing the mouse cursor (a screen of its own), or not (false when unread), and its language
-- (nil when unread); nothing once off.
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
assert(k.paused()==false and k.language()==nil and #calls==n)

-- The chat box (b.field): an EditableTextBox that keeps its keyboard focus on Enter and reverts on Esc, in Mideum 34,
-- white on the dark glass, with its hint, all set before AddToViewport; it takes the mouse in its hit group (a click
-- focuses it). input(true, 'chat') puts the game's input on it with its keyboard focus. Who holds the input gives it
-- back: the menu's late give-back (150 ms after its close) never takes the chat's, nor the chat's the menu's. Its text
-- read through GetText, emptied, focused again, its hint changed. A refused style or property only degrades.
local function last_at(name) for i=#calls,1,-1 do if calls[i]==name then return i end end end
local function chat_kit()
    local ck=Ui.kit({store=store,log=function(m) logs[#logs+1]=m end})
    ck.add('menu',{x=180,y=330,w=1240,h=1500,hit=true},function(b) return {row=b.row(0,0,100)} end)
    ck.add('chat',{x=96,y=330,w=1300,h=660,hit=true},function(b)
        b.panel(0,0,1300,660)
        return {box=b.field(24,572,1252,56,'Message')}
    end)
    return ck
end
reset()
k=chat_kit()
up(k)
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

print('ui_kit_test ok')
