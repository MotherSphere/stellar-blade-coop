-- coop ui test: the UI-layer spike, a console command only (not for players yet), never on by itself. It builds a small
-- widget the way the UI layer would: a plain UserWidget whose WidgetTree and canvas are made by hand, holding a dark
-- panel, a title in the game's font, a row of the HUD's HP dots and a bar at 60 %; added to the viewport in the same
-- game-thread call, shown 5 s without taking any input, then removed. One [StellarCoop][UI] line per check (classes,
-- construct, tree, font, viewport, visible, input, GC, removed, timing), then a verdict. Fallbacks: a game widget class
-- with no logic as the root when the plain one fails (coop ui test game tries it alone), the engine font when the
-- game's is missing, the default font when none can be set, flat colour when the dots cannot be. Every engine step runs
-- in pcall on the game thread (the console handler, the 1 ms loop), never in a coroutine; nothing stays once removed.
-- Below it, Ui.kit: the Uplink kit the UI layer builds on, from the same construction.
local UE=require('UEHelpers')
local U=require('unreal')
local valid,value_of=U.valid,U.value_of
local Ui={}
local SHOW,BUDGET,Z,SIZE=5,50,100,40 -- Seconds on screen; ms the build may take in one frame; viewport z; font size.
local UMG={'UserWidget','WidgetTree','CanvasPanel','Border','TextBlock','Image','ProgressBar'}
local KIDS={'CanvasPanel','Border','TextBlock','Image','ProgressBar'} -- Made with the tree as their outer.
local GAME_ROOT='/Game/Art/UI/Widget/GameMenu/Setting/Slot/WB_Setting_Category' -- Plain UMG, no SB logic.
local GAME_FONT,ENGINE_FONT='/Game/Art/Font/Bold.Bold','/Engine/EngineFonts/Roboto.Roboto'
local DOTS='/Game/Art/UI/Texture/HUD/Gauge/Hp_Dot1_5x.Hp_Dot1_5x'
local PANEL={R=0.039,G=0.055,B=0.071,A=0.78} -- #0A0E12 at 0.78.
local TEAL={R=0.678,G=0.82,B=0.769,A=1} -- The partner colour, the game's shield teal #ADD1C4.
local HIT_TEST_INVISIBLE,TILE_BOTH=3,3 -- ESlateVisibility, ESlateBrushTileType.
local FAILED='UI test failed: see the [StellarCoop][UI] lines'
local NEXT='no runtime UMG widget here. Next: fallback 2, a Canvas draw in a ReceiveDrawHUD post-hook, then route B, '
    ..'a cooked widget pak; the keys, the notice line and the console work as before'
local function ms(since) return (os.clock()-since)*1000 end
local function need(value,why) -- assert's check, its message without a source position (it goes to the log as is).
    if not value then error(why,0) end
    return value
end
local function same(a,b)
    a,b=valid(a),valid(b)
    return a~=nil and b~=nil and a:GetAddress()==b:GetAddress()
end
-- An object in memory, else after LoadAsset (synchronous; via: the asset whose package holds it); nil when neither.
local function load(path,via)
    local found=valid(StaticFindObject(path))
    if found then return found end
    pcall(LoadAsset,via or path)
    return valid(StaticFindObject(path))
end
-- The game's Bold (Rajdhani), else the engine's Roboto, written in place into the TextBlock's Font struct, else through
-- SetFont, and read back. true with the game's font, 'fallback' with Roboto, false when neither write took (the
-- TextBlock's default font stays): only the look degrades.
local function font(text)
    local name,object='Bold',load(GAME_FONT)
    if not object then name,object='Roboto (the game font is missing)',load(ENGINE_FONT) end
    if not object then return false,'neither Bold nor Roboto found; the default font stays' end
    local function took()
        local ok,yes=pcall(function()
            local f=value_of(text.Font)
            return same(f.FontObject,object) and f.Size==SIZE
        end)
        return ok and yes
    end
    local wrote,why=pcall(function() local f=value_of(text.Font); f.FontObject=object; f.Size=SIZE end)
    local how='written in place'
    if not took() then
        how='through SetFont (in place: '..(wrote and 'did not stick' or tostring(why))..')'
        local set,set_why=pcall(function() text:SetFont({FontObject=object,Size=SIZE}) end)
        if not took() then
            return false,'neither the in-place write nor SetFont took ('..(set and 'did not stick' or tostring(set_why))
                ..'); the default font stays'
        end
    end
    return name=='Bold' or 'fallback',name..' '..SIZE..', '..how
end
-- The HUD's HP dot tiled along the row, tinted teal. The tiling goes in place into the brush first; only once it reads
-- back does the texture go on, else the row stays flat teal.
local function dots(image)
    image:SetColorAndOpacity(TEAL)
    local wrote,why=pcall(function() value_of(image.Brush).Tiling=TILE_BOTH end)
    if not (wrote and value_of(image.Brush).Tiling==TILE_BOTH) then
        return 'flat colour: the brush tiling '..(wrote and 'did not stick' or 'raised '..tostring(why))
    end
    local texture=load(DOTS)
    if not texture then return 'flat colour: no Hp_Dot1_5x texture' end
    image:SetBrushFromTexture(texture,true)
    return same(value_of(image.Brush).ResourceObject,texture) and 'dots tiled' or 'dots set, not read back'
end
-- One of the test's own widgets while it is still that object: a map change frees them, and the address of a freed one
-- may hold another object by the time it is used (puppet.lua's resolve guards its cache the same way).
local function ours(w,key)
    local o=valid(w[key])
    return o and U.text(o:GetFullName())==w.names[key] and o or nil
end
local function clean(w) pcall(function() local root=ours(w,'root'); if root then root:RemoveFromParent() end end) end
function Ui.new(log)
    local self={}
    local test -- The test on screen: its widgets, the player controller, when it is due, its timing.
    local fails={} -- The checks failed by the root on trial, the font aside (only the look).
    local function check(n,name,state,detail)
        if state==false and name~='font' then fails[#fails+1]=n..' '..name end
        log(string.format('check %d/10 %s: %s%s',n,name,state==true and 'ok' or state==false and 'FAIL' or state,
            detail and ' ('..detail..')' or ''))
    end
    local function verdict(t)
        if not t then return log('verdict: '..NEXT) end
        local root=t.w.kind=='plain' and 'a plain UserWidget root' or "fallback 1, the game's WB_Setting_Category_C as "
            ..'the root'
        if #fails>0 then
            return log('verdict: route A built '..root..', but check '..table.concat(fails,', ')..' failed')
        end
        log('verdict: route A works with '..root..'; look: '..t.w.look..'. On screen for '..SHOW..' s: a dark panel '
            ..'left of centre, the title, a teal row of dots, a bar at 60 %')
    end
    -- Checks 2 to 5 for one root class, all in this one game-thread call: the root (outer: the player controller), its
    -- tree, the canvas and its widgets, the font, then the owner, no hit test and the viewport. False once a check
    -- fails; w keeps what was made, for the clean-up.
    local function build(w,class,pc,c)
        local step,names=2,{'construct','tree','font','viewport'}
        local ok,why=pcall(function()
            local function make(key,of,outer,what)
                w[key]=need(valid(StaticConstructObject(of,outer)),what..' was not constructed')
                w.names[key]=U.text(w[key]:GetFullName())
            end
            make('root',class,pc,'the root')
            make('tree',c.WidgetTree,w.root,'its WidgetTree')
            for _,name in ipairs(KIDS) do make(name,c[name],w.tree,'a '..name) end
            make('canary',c.TextBlock,w.tree,'the canary') -- In no tree: the next GC frees it, which shows one ran.
            check(2,'construct',true,'root, tree and '..(#KIDS+1)..' widgets')
            step=3
            w.root.WidgetTree=w.tree
            w.tree.RootWidget=w.CanvasPanel
            local function put(widget,x,y,width,height) -- Layout units: the HUD's 3840x2160.
                local slot=need(valid(w.CanvasPanel:AddChildToCanvas(widget)),'no canvas slot')
                slot:SetPosition({X=x,Y=y})
                if width then slot:SetSize({X=width,Y=height}) else slot:SetAutoSize(true) end
            end
            w.Border:SetBrushColor(PANEL)
            put(w.Border,180,860,1240,300)
            w.TextBlock:SetText(FText('StellarCoop UI test'))
            put(w.TextBlock,220,890)
            local dotted,look=pcall(dots,w.Image)
            w.look=dotted and look or 'flat colour: '..tostring(look)
            put(w.Image,220,970,600,45)
            w.ProgressBar:SetFillColorAndOpacity(TEAL)
            w.ProgressBar:SetPercent(0.6)
            put(w.ProgressBar,220,1050,600,24)
            need(same(w.root.WidgetTree,w.tree) and same(w.tree.RootWidget,w.CanvasPanel),
                'the tree did not read back')
            local count=w.CanvasPanel:GetChildrenCount()
            need(count==4,'the canvas holds '..tostring(count)..' widgets, not 4')
            need(math.abs(value_of(w.ProgressBar.Percent)-0.6)<0.001,"the bar's value did not read back")
            check(3,'tree',true,'canvas: panel, title, '..w.look..', bar at 60 %')
            step=4
            local ran,state,detail=pcall(font,w.TextBlock)
            if not ran then state,detail=false,tostring(state) end
            w.look=(state and detail:match('^%S+') or 'default font')..', '..w.look
            check(4,'font',state,detail)
            step=5
            local added=os.clock()
            w.root:SetOwningPlayer(pc)
            w.root:SetVisibility(HIT_TEST_INVISIBLE) -- Mouse hits pass through; a UserWidget is not focusable.
            w.root:AddToViewport(Z)
            w.add_ms=ms(added)
            need(w.root:IsInViewport(),'not in the viewport')
            need(w.root:IsVisible(),'in the viewport but not visible')
            check(5,'viewport',true,'z '..Z..', hit tests pass through')
        end)
        if not ok then check(step,names[step-1],false,tostring(why)) end
        return ok
    end
    -- coop ui test [game]: false and why when it cannot start or no root shows; the checks go to the log.
    function self.test(game_only)
        if test then return false,'a UI test is on screen already; its checks follow within '..SHOW..' s' end
        local pc=valid(UE.GetPlayerController())
        -- UEHelpers keeps the last one while its address is valid: after a map change it may be another object.
        if pc and not pc:IsA(U.find('/Script/Engine.PlayerController')) then pc=nil end
        if not pc then return false,'no player controller yet: load a save first' end
        local cursor=pc.bShowMouseCursor -- Before anything is built: a raise here leaves nothing behind.
        local started=os.clock()
        fails={}
        local c,missing={},{}
        for _,name in ipairs(UMG) do
            local found,class=pcall(U.find,'/Script/UMG.'..name)
            if found then c[name]=class else missing[#missing+1]=name end
        end
        local classes_ms=ms(started)
        check(1,'classes',#missing==0,#missing==0 and 'all '..#UMG..' UMG classes'
            or 'missing: '..table.concat(missing,' '))
        if #missing>0 then verdict(); return false,FAILED end
        for _,kind in ipairs(game_only and {'game'} or {'plain','game'}) do
            local w,class={kind=kind,names={}},c.UserWidget
            if kind=='game' then
                if not game_only then log("fallback 1: the game's WB_Setting_Category_C as the root") end
                fails={}
                class=load(GAME_ROOT..'.WB_Setting_Category_C',GAME_ROOT..'.WB_Setting_Category')
            end
            if not class then
                check(2,'construct',false,'WB_Setting_Category_C is not in this build')
            elseif build(w,class,pc,c) then
                -- One engine GC at this frame's end, while the widget shows: check 8 sees whether it ran.
                local gc,gc_why=pcall(function()
                    U.find('/Script/Engine.Default__KismetSystemLibrary'):CollectGarbage()
                end)
                if not gc then log('no GC asked: '..tostring(gc_why)) end
                -- ponytail: a Ctrl+R within these 5 s leaves the widget until the next map change; the UI layer sweeps
                -- its root by path (UI-DESIGN 7.2), the spike does not.
                test={w=w,pc=pc,cursor=cursor,due=os.clock()+SHOW,ms=ms(started),classes_ms=classes_ms}
                return true,'UI test on screen for '..SHOW..' s ('..(kind=='plain' and 'plain root' or 'game root')
                    ..'); its checks follow in the log'
            end
            clean(w)
        end
        verdict()
        return false,FAILED
    end
    -- Checks 6 to 10, when the 5 s are up.
    local function finish(t)
        local w=t.w
        local root=ours(w,'root')
        local there=root~=nil and root:IsInViewport()
        if there then
            local size,shown=value_of(root:GetDesiredSize()),root:IsVisible()
            check(6,'visible',shown and size.X>0 and size.Y>0,string.format('visible %s, laid out at %.0fx%.0f',
                tostring(shown),size.X,size.Y))
            local focus=root:HasAnyUserFocus() or root:HasFocusedDescendants()
            local through=root:GetVisibility()==HIT_TEST_INVISIBLE
            local cursor=valid(t.pc) and t.pc.bShowMouseCursor
            check(7,'input',not focus and through and cursor==t.cursor,string.format(
                'keyboard focus %s, hit tests %s, mouse cursor %s',focus and 'taken' or 'none',
                through and 'pass through' or 'caught',cursor==t.cursor and 'as before' or 'changed'))
            local lost={}
            for _,name in ipairs({'root','tree',table.unpack(KIDS)}) do
                if not ours(w,name) then lost[#lost+1]=name end
            end
            if #lost==0 and not (same(root.WidgetTree,w.tree) and same(w.tree.RootWidget,w.CanvasPanel)
                and w.CanvasPanel:GetChildrenCount()==4) then lost[1]='a link' end
            local ran=ours(w,'canary')==nil
            check(8,'gc',#lost==0 and (ran or 'untested'),#lost>0 and 'lost: '..table.concat(lost,' ')
                or ran and 'a GC ran, the tree is whole' or 'no GC ran in '..SHOW..' s (the loose canary lives); '
                ..'the tree is whole')
        else
            check(6,'visible',false,root and 'out of the viewport but not freed: the game took it out'
                or 'gone before the check: a map change removes viewport widgets')
            check(7,'input','skipped')
            check(8,'gc','skipped')
        end
        local removed,why=true,'the engine removed it with the map'
        if root then
            removed,why=pcall(function() root:RemoveFromParent() end)
            why=removed and 'RemoveFromParent' or tostring(why)
        end
        local out=not (root and root:IsInViewport())
        check(9,'removed',removed and out,out and why or why..'; still in the viewport')
        check(10,'timing',t.ms<=BUDGET or 'slow',string.format('%.1f ms in one frame: classes %.1f, build and assets '
            ..'%.1f, viewport %.1f; budget %d ms',t.ms,t.classes_ms,t.ms-t.classes_ms-w.add_ms,w.add_ms,BUDGET))
        verdict(t)
    end
    -- Each frame (main.lua's 1 ms loop): nothing but this test unless one is due.
    function self.tick()
        if not test or os.clock()<test.due then return end
        local t=test
        test=nil
        local ok,why=pcall(finish,t)
        if not ok then
            clean(t.w)
            log('the checks stopped: '..tostring(why)..'; the widget is removed')
        end
    end
    -- coop off: a test on screen goes now, as the 1 ms loop stops.
    function self.stop()
        local t=test
        test=nil
        if not t then return end
        clean(t.w)
        log('the test stopped with coop off; the widget is removed')
    end
    return self
end
-- The Uplink kit (UI-DESIGN 3.2, 7.1-7.6): one root a world, a plain UserWidget built by hand as coop ui test proved,
-- holding every group the views add (the menu, the feed, the card, the marker), each a canvas of its own, hidden
-- (Collapsed) when unused, never removed. Hit tests pass through every group but one marked hit (the menu: its rows
-- take the mouse). Each 250 ms (slow): the root an earlier Lua load left (Ctrl+R) is swept by its path; the classes and
-- the game's fonts, textures and sounds warm one lookup a tick (about 4 ms each); the root is built in one call once
-- the classes are in (in the default font and flat colour while an asset it uses still warms: the menu works from the
-- start), built once again when those are in (not while the menu is open), checked to be still ours and in the
-- viewport each tick, and built again, as it was, once a map change took it (off after 4 losses in a row: no rebuild
-- storm). Each frame (tick): only the open and close tweens, while one runs. Updates touch the engine only on change,
-- and only a widget still ours: a map change frees them, and an address may hold another object by then. Every engine
-- call runs in pcall on the game thread, never in a coroutine; the first error in a build or an update turns the kit
-- off for this Lua load (off(): the callers go back to the notice line above EVE and the name tag), said once by the
-- next slow or tick. A look that cannot be had (a font, a texture, a text colour) only degrades, with one log line a
-- build.
local P=require('partner')
local function linear(byte) local c=byte/255; return c<=0.04045 and c/12.92 or ((c+0.055)/1.055)^2.4 end
-- A colour as Slate shows it ('ADD1C4') to the linear one the engine takes.
local function hex(h,a)
    return {R=linear(tonumber(h:sub(1,2),16)),G=linear(tonumber(h:sub(3,4),16)),B=linear(tonumber(h:sub(5,6),16)),
        A=a or 1}
end
-- Uplink: the game's palette, teal for everything partner (the game's shield teal; enemies are red), Beta blue focus.
Ui.THEME={text=hex('ECECEC'),grey=hex('B5B5B5'),dim=hex('6E6E6E'),teal=hex('ADD1C4'),beta=hex('CCE9F4'),
    burst=hex('DD8874'),warn=hex('DC8834'),error=hex('D85045'),white=hex('FFFFFF'),panel=hex('0A0E12',0.78),
    rail=hex('DEDBDE',0.25),focus=hex('CCE9F4',0.12),empty=hex('6E6E6E',0.5),clear=hex('000000',0)}
local THEME=Ui.THEME
local function path(p) return p..'.'..p:match('[^/]+$') end
local TEX,GAUGE='/Game/Art/UI/Texture/','/Game/Art/UI/Texture/HUD/Gauge/'
local KEY,SOUND=TEX..'Interaction/PC_ActionAssist/KeyIcon_KeyBoard_','/Game/Sound/UI/'
-- Name and object path, in warm-up order; the sounds (with their volume) last: the build does not wait for them.
Ui.ASSETS={{'Bold',GAME_FONT},{'Mideum',path('/Game/Art/Font/Mideum')},{'AGENCYB',path('/Game/Art/Font/AGENCYB')},
    {'FZSHANGYTJW',path('/Game/Art/Font/English/FZSHANGYTJW_Font')},{'Roboto',ENGINE_FONT},{'dot',DOTS},
    {'dot_bg',path(GAUGE..'Hp_Dot1_5x_bg')},{'small',path(GAUGE..'Hp_Dot_12')},{'small_bg',path(GAUGE..'Hp_Dot_12bg')}}
for i=0,4 do table.insert(Ui.ASSETS,{'cube'..i,path(GAUGE..'Beta_cube_0'..i)}) end
for _,a in ipairs({{'mark',TEX..'Item/CommonIcon/4DotMark'},{'link',TEX..'Common/selectdot'},
        {'key_enter',KEY..'Enter'},{'key_escape',KEY..'Escape'},{'key_space',KEY..'SpaceBar'},{'key_up',KEY..'Up'},
        {'key_arrows',KEY..'DirectionAll'},{'key_move',KEY..'MoveAll'},{'key_move_azerty',KEY..'MoveAll_AZERTY'},
        {'open',SOUND..'MainMenu/Ui_MoveIn_Cue',1},{'close',SOUND..'MainMenu/UI_MoveOut_Cue',1},
        {'move',SOUND..'UI_Common_Hover_Cue',1},{'select',SOUND..'ui_button_Confirm_Cue',1},
        {'back',SOUND..'ui_button_cancel',1},{'change',SOUND..'MainMenu/UI_Setting_Select_Cue',1},
        {'chat',SOUND..'ui_notice_Cue',0.5},{'alert',SOUND..'ui_SystemNotice_Cue',1}}) do
    table.insert(Ui.ASSETS,{a[1],path(a[2]),volume=a[3]})
end
local VOLUME={}
for _,a in ipairs(Ui.ASSETS) do VOLUME[a[1]]=a.volume end
local CLASSES={}
for _,name in ipairs(UMG) do CLASSES[#CLASSES+1]='/Script/UMG.'..name end
local STATICS,WIDGETS='/Script/Engine.Default__GameplayStatics','/Script/UMG.Default__WidgetBlueprintLibrary'
local LANGUAGE='/Script/Engine.Default__KismetInternationalizationLibrary'
for _,class in ipairs({'/Script/Engine.PlayerController',STATICS,WIDGETS,LANGUAGE}) do CLASSES[#CLASSES+1]=class end
-- Text styles: font and size in layout units (UI-DESIGN 3.2's typography).
local STYLES={title={'Bold',56},item={'Bold',40},name={'Bold',36},hint={'Bold',30},body={'Mideum',34},
    status={'Mideum',30},head={'Mideum',28},num={'AGENCYB',30},label={'FZSHANGYTJW',30}}
local VISIBLE,COLLAPSED,SELF_HIT=0,1,4 -- ESlateVisibility: hit, none, children only.
-- Row height; tween seconds; slide units; rebuilds in a row for a root that left the viewport, then off.
local ROW,OPEN,CLOSE,SLIDE,LOSSES=76,0.16,0.12,32,3
local function make(n,class,outer)
    local x=valid(StaticConstructObject(n.classes[class],outer))
    if not x then error(class..' not constructed',0) end
    n.count=n.count+1
    return {o=x,name=U.text(x:GetFullName())}
end
local function put(canvas,w,x,y,width,height) -- Layout units: the HUD's 3840x2160.
    -- In a hit group, hit tests pass through every widget not said otherwise (a row's own area takes them).
    if canvas.hit and not w.v then w.v=HIT_TEST_INVISIBLE; w.o:SetVisibility(w.v) end
    w.slot=need(valid(canvas.o:AddChildToCanvas(w.o)),'no canvas slot')
    w.slot:SetPosition({X=x,Y=y})
    if width then w.slot:SetSize({X=width,Y=height}) else w.slot:SetAutoSize(true) end
    return w
end
local function hide(w) w.v=COLLAPSED; w.o:SetVisibility(COLLAPSED) end
-- opts: {log=function(line), store={save,load,clear} (link.store('coop-ui.txt')), azerty=true for the AZERTY move
-- keys, scale=ui_scale (75 to 150 %), sounds=false for ui_sounds=off}.
function Ui.kit(opts)
    opts=opts or {}
    local log=opts.log or function() end
    local store=opts.store or {save=function() end,load=function() end,clear=function() end}
    local self,order,by,cache,found={},{},{},{},{} -- cache: asset name to {o=, full=} or false (not in this build).
    local built,pending,off,said,hidden,swept,lost=nil,nil,false,nil,false,false,0
    local quiet,no_color,sounding,tweens,inputting=false,false,opts.sounds~=false,{},false
    local function clamp(pct) return math.max(75,math.min(150,tonumber(pct) or 100))/100 end
    local scale=clamp(opts.scale)
    -- A widget record ({o=, name=, slot=, v=its visibility as last set}): its object while it is still ours.
    local function alive(w)
        local x=w and valid(w.o)
        return x and U.text(x:GetFullName())==w.name and x or nil
    end
    -- The game's input (UI-DESIGN 7.5): on, the game ignores its keys and mouse (SetInputMode_UIOnlyEx, our root
    -- focused; the menu's keys are UE4SS binds, which read the keyboard whatever has focus); off, the game's again.
    local function input_mode(on)
        local pc,root=valid(UE.GetPlayerController()),on and alive(built.root)
        inputting=on
        if not pc or (on and not root) then return end
        if on then U.find(WIDGETS):SetInputMode_UIOnlyEx(pc,root,0) else U.find(WIDGETS):SetInputMode_GameOnly(pc) end
    end
    local function close_all()
        if inputting then pcall(input_mode,false) end -- A fault or coop off never leaves the game deaf.
        off,tweens=true,{}
        for _,n in ipairs({built or false,pending or false}) do
            if n then pcall(function() local r=alive(n.root); if r then r:RemoveFromParent() end end) end
        end
        built,pending=nil,nil
        pcall(store.clear)
    end
    local function fail(why)
        if off then return end
        close_all()
        said='UI off until the mod reloads: '..tostring(why)..'; notices stay on the line above EVE'
    end
    local function said_once()
        local m=said
        said=nil
        if m then return false,m end
    end
    local function run(f,...)
        if off then return end
        if pending then return f(...) end -- In a build (a view's set): an error stops the build, in its own run.
        local ok,why=pcall(f,...)
        if not ok then fail(why) end
    end
    local function upd(w,f) run(function() local x=alive(w); if x then f(x) end end) end -- Only while still ours.
    -- Shown (w.on: its visibility shown, hit tests passing through unless said) or collapsed; never an image whose
    -- texture is missing (gone).
    local function show_w(w,on)
        if w.gone then return end
        local v=on and (w.on or HIT_TEST_INVISIBLE) or COLLAPSED
        if w.v==v then return end
        w.v=v
        upd(w,function(x) x:SetVisibility(v) end)
    end
    -- A text colour; white for good once the engine refuses one.
    local function paint(x,c,n)
        if not no_color and pcall(function() x:SetColorAndOpacity({SpecifiedColor=c,ColorUseRule=0}) end) then
            return
        end
        if n then n.look['text colour refused (white)']=true -- In each build's look line.
        elseif not no_color then log('UI text colours off: refused') end
        no_color=true
    end
    -- The widgets of one group (g: its canvas), made while build n runs.
    local function builder(n,g)
        local b={}
        -- An asset of the look; a build that wants one still warming is partial (built again once it is in).
        local function get(name)
            if cache[name]==nil and not n.assets[name] then n.partial=true end
            return n.assets[name]
        end
        -- An image: tex (an asset name, nil for flat colour) tiled or not, else flat colour (flat: that colour, tint
        -- unless said; false: hidden instead).
        local function image(x,y,width,height,tex,tint,tiled,flat)
            local w=make(n,'Image',n.tree.o)
            local t=tex and get(tex)
            if tex and not t then n.look[tex..' missing']=true end
            if t and tiled then
                local wrote=pcall(function() value_of(w.o.Brush).Tiling=TILE_BOTH end)
                if not (wrote and value_of(w.o.Brush).Tiling==TILE_BOTH) then
                    n.look['brush tiling did not take']=true
                    t=nil
                end
            end
            if t then w.o:SetBrushFromTexture(t,true) end
            w.o:SetColorAndOpacity((t or not flat) and tint or flat)
            if tex and not t and flat==false then hide(w); w.gone=true end
            return put(g,w,x,y,width,height)
        end
        -- A line of text in a style (STYLES) and colour: set(text), color(c), show(on).
        local function text(x,y,str,style,color)
            local w=make(n,'TextBlock',n.tree.o)
            local st=STYLES[style] or STYLES.body
            local f=get(st[1]) or get('Roboto')
            if not f then n.look['no font (default font)']=true
            elseif not pcall(function() local v=value_of(w.o.Font); v.FontObject=f; v.Size=st[2] end)
                and not pcall(function() w.o:SetFont({FontObject=f,Size=st[2]}) end) then
                n.look['font writes refused (default font)']=true
            elseif f~=n.assets[st[1]] then n.look[st[1]..' missing (Roboto)']=true end
            str,color=str or '',color or THEME.text
            w.o:SetText(FText(str))
            paint(w.o,color,n)
            put(g,w,x,y)
            return {set=function(s) s=s or ''; if s~=str then str=s; upd(w,function(x2) x2:SetText(FText(s)) end) end end,
                color=function(c) if c~=color then color=c; upd(w,function(x2) paint(x2,c) end) end end,
                show=function(on) show_w(w,on) end}
        end
        b.text=text
        -- The panel: cold glass, and the game's dotted rails along its top and bottom.
        function b.panel(x,y,width,height)
            local w=make(n,'Border',n.tree.o)
            w.o:SetBrushColor(THEME.panel)
            put(g,w,x,y,width,height)
            local rail=math.floor((width-48)/10)*10
            image(x+24,y+12,rail,10,'small',THEME.rail,true,false)
            image(x+24,y+height-22,rail,10,'small',THEME.rail,true,false)
        end
        -- An image by asset name (nil: flat colour): show(on), tint(c).
        function b.image(x,y,width,height,tex,tint)
            tint=tint or THEME.white
            local w=image(x,y,width,height,tex,tint)
            return {show=function(on) show_w(w,on) end,
                tint=function(c) if c~=tint then tint=c; upd(w,function(x2) x2:SetColorAndOpacity(c) end) end end}
        end
        -- Dots of the HUD's gauges ('big': its 15-unit dots, 'small': the 10-unit ones), cols by rows, tiled, lit over
        -- empty: set(lit, shown), lit columns of the shown ones (all unless said).
        function b.dots(x,y,cols,rows,size,tint)
            local pitch,tex=15,'dot'
            if size=='small' then pitch,tex=10,'small' end
            local bg=image(x,y,cols*pitch,rows*pitch,tex..'_bg',THEME.white,true,THEME.empty)
            local lit=image(x,y,0,rows*pitch,tex,tint or THEME.teal,true)
            local now_lit,now_shown=0,cols
            return {set=function(l,shown)
                shown=shown or cols
                l=math.max(0,math.min(l,shown))
                if shown~=now_shown then
                    now_shown=shown
                    upd(bg,function() bg.slot:SetSize({X=shown*pitch,Y=rows*pitch}) end)
                end
                if l~=now_lit then
                    now_lit=l
                    upd(lit,function() lit.slot:SetSize({X=l*pitch,Y=rows*pitch}) end)
                end
            end}
        end
        -- Her HP (the player cluster's rule, partner.lua): set(hp, max).
        function b.hp(x,y,cols,rows,size,tint)
            local d=b.dots(x,y,cols,rows,size,tint)
            return {set=function(hp,max) d.set(P.hp_columns(hp,max,cols)) end}
        end
        -- Her shield: five blocks of 11 by 2 dots, a dot apart: set(shield, max, ShieldBlock).
        function b.shield(x,y,size,tint)
            local pitch=size=='small' and 10 or 15
            local blocks={}
            for i=1,5 do blocks[i]=b.dots(x+(i-1)*12*pitch,y,11,2,size,tint) end
            return {set=function(shield,max,count)
                for i,d in ipairs(blocks) do
                    local lit=P.shield_block(i,shield,max,count,11)
                    d.set(lit or 0,lit and 11 or 0)
                end
            end}
        end
        -- A Beta or Burst row of count cubes, 41 units apart, quarters in tint; none shown before set(value, max).
        function b.cubes(x,y,count,tint)
            local cubes={}
            for i=1,count do
                local c={image(x+(i-1)*41,y,30,30,'cube0',THEME.white,false,THEME.dim)}
                for q=1,4 do c[q+1]=image(x+(i-1)*41,y,30,30,'cube'..q,tint,false,false) end
                for _,w in ipairs(c) do if w.v~=COLLAPSED then hide(w) end end
                cubes[i]=c
            end
            return {set=function(value,max)
                for i,c in ipairs(cubes) do
                    local lit=P.cube(i,value,max,count)
                    show_w(c[1],lit~=nil)
                    for q=1,4 do show_w(c[q+1],lit~=nil and q<=lit) end
                end
            end}
        end
        -- A bar: set(fraction).
        function b.bar(x,y,width,height,color)
            local w=make(n,'ProgressBar',n.tree.o)
            w.o:SetFillColorAndOpacity(color or THEME.teal)
            w.o:SetPercent(0)
            put(g,w,x,y,width,height)
            local now=0
            return {set=function(p)
                p=math.max(0,math.min(1,p))
                if p~=now then now=p; upd(w,function(x2) x2:SetPercent(p) end) end
            end}
        end
        -- A list row 76 units high: a label, a value 300 units from its end; on focus the Beta-blue bar and a faint
        -- Beta tint. set(label, value, 'normal'|'focus'|'disabled'); hovered() in a hit group: the mouse is over it.
        function b.row(x,y,width)
            local back,bar=image(x,y,width,ROW,nil,THEME.clear),image(x,y,6,ROW,nil,THEME.beta)
            if g.hit then back.v=VISIBLE; back.o:SetVisibility(VISIBLE) end -- The row's area takes the mouse.
            hide(bar)
            local label,value=text(x+36,y+12,'','item'),text(x+width-300,y+12,'','item')
            local state='normal'
            return {set=function(l,v,st)
                label.set(l)
                value.set(v)
                st=st or 'normal'
                if st==state then return end
                state=st
                upd(back,function(x2) x2:SetColorAndOpacity(st=='focus' and THEME.focus or THEME.clear) end)
                show_w(bar,st=='focus')
                label.color(st=='disabled' and THEME.dim or THEME.text)
                value.color(st=='disabled' and THEME.dim or THEME.text)
            end,hovered=function()
                local on=false
                upd(back,function(x2) on=x2:IsHovered()==true end)
                return on
            end}
        end
        -- Key hints cell units apart, {{key, label}, ...}; keys: move (ZQSD with azerty), arrows, up, enter, space,
        -- escape. A missing icon leaves its label.
        function b.hints(x,y,cell,list)
            for i,hint in ipairs(list) do
                local key=(hint[1]=='move' and opts.azerty) and 'move_azerty' or hint[1]
                image(x+(i-1)*cell,y,48,48,'key_'..key,THEME.white,false,false)
                text(x+(i-1)*cell+60,y+4,hint[2],'hint')
            end
        end
        return b
    end
    -- The build, all in this one game-thread call; nothing when there is no player controller yet. An asset a map
    -- change freed is looked up again by warm (a build using it is partial meanwhile).
    local function build()
        local pc=valid(UE.GetPlayerController())
        if not (pc and pc:IsA(U.find('/Script/Engine.PlayerController'))) then return end
        local assets={}
        for name,e in pairs(cache) do
            local x=e and valid(e.o)
            if x and U.text(x:GetFullName())==e.full then assets[name]=x elseif e then cache[name]=nil end
        end
        local started=os.clock()
        local n={classes={},assets=assets,count=0,look={},groups={},views={},size=#order}
        for _,name in ipairs(UMG) do n.classes[name]=U.find('/Script/UMG.'..name) end
        pending=n
        n.root=make(n,'UserWidget',pc)
        n.tree=make(n,'WidgetTree',n.root.o)
        local canvas=make(n,'CanvasPanel',n.tree.o)
        n.root.o.WidgetTree=n.tree.o
        n.tree.o.RootWidget=canvas.o
        local hit=false
        for _,def in ipairs(order) do
            local p=def.place
            local g=put(canvas,make(n,'CanvasPanel',n.tree.o),p.x,p.y,p.w,p.h)
            g.x,g.y,g.hit,g.on=p.x,p.y,p.hit,p.hit and SELF_HIT or HIT_TEST_INVISIBLE
            hit=hit or p.hit
            g.o:SetRenderTransformPivot(p.pivot or {X=0,Y=0})
            if scale~=1 then g.o:SetRenderScale({X=scale,Y=scale}) end
            g.v=def.shown and g.on or COLLAPSED
            g.o:SetVisibility(g.v)
            n.groups[def.name]=g
            n.views[def.name]=def.build(builder(n,g)) or {}
        end
        n.root.o:SetOwningPlayer(pc)
        n.root.on=hit and SELF_HIT or HIT_TEST_INVISIBLE -- Mouse hits pass through, as the spike's, but a hit group's.
        n.root.v=n.root.on
        n.root.o:SetVisibility(n.root.on)
        n.root.o:AddToViewport(Z)
        need(n.root.o:IsInViewport(),'the UI root is not in the viewport')
        pending,built=nil,n
        store.save(n.root.name:match('^%S+ (.+)$'))
        if n.partial then return log(string.format('UI built while its look warms: %d widgets in %.1f ms',n.count,
            ms(started))) end
        local look={}
        for note in pairs(n.look) do look[#look+1]=note end
        table.sort(look)
        log(string.format('UI built: %d widgets in %.1f ms%s',n.count,ms(started),
            #look>0 and '; look: '..table.concat(look,', ') or ''))
    end
    -- One class not looked up yet looked up: true when one was.
    local function classes()
        for _,class in ipairs(CLASSES) do
            if not found[class] then U.find(class); found[class]=true; return true end
        end
        return false
    end
    -- One class or asset not tried yet looked up (look: all but the sounds): true when one was.
    local function warm(look)
        if classes() then return true end
        for _,a in ipairs(Ui.ASSETS) do
            if cache[a[1]]==nil and not (look and a.volume) then
                local x=load(a[2])
                cache[a[1]]=x and {o=x,full=U.text(x:GetFullName())} or false
                return true
            end
        end
        return false
    end
    -- The root an earlier Lua load left (Ctrl+R): true when its path was looked up.
    local function sweep()
        local left=store.load()
        store.clear()
        if not left then return false end
        local x=valid(StaticFindObject(left))
        if x and U.text(x:GetFullName()):find('^UserWidget ') and x:IsInViewport() then
            x:RemoveFromParent()
            log('removed the UI an earlier Lua load left on screen')
        end
        return true
    end
    local function step(world)
        if not swept then
            swept=true
            if sweep() then return end
        end
        hidden=not world
        if hidden then
            lost=0
            if built and built.root.v~=COLLAPSED then
                built.root.v=COLLAPSED
                local r=alive(built.root)
                if r then r:SetVisibility(COLLAPSED) end
            end
            return
        end
        if built then
            local r=alive(built.root)
            local kept=r and r:IsInViewport()
            if kept and built.size==#order then
                lost=0
                if built.root.v~=built.root.on then built.root.v=built.root.on; r:SetVisibility(built.root.on) end
                if warm(built.partial) or not built.partial then return end
                for _,def in ipairs(order) do if def.shown and def.place.hit then return end end -- Not under the mouse.
            elseif built.size==#order then
                lost=lost+1 -- A map change took it out, or the game, or another mod.
                need(lost<=LOSSES,'the UI root keeps leaving the viewport')
            end
            if r then r:RemoveFromParent() end -- Out of the viewport, a group came, or the look is in.
            built,tweens=nil,{}
        end
        if not classes() then build() end
    end
    -- Each 250 ms with whether our HUD may show (a world with EVE, not paused, the game's HUD up, no photo mode).
    -- Returns false and why once, when the kit turned off.
    function self.slow(world)
        if not off and order[1] then run(step,world) end
        return said_once()
    end
    -- Each frame: the open and close tweens, only while one runs.
    function self.tick(now)
        if not off and next(tweens) then
            run(function()
                for name,t in pairs(tweens) do
                    local x=alive(built and built.groups[name])
                    if not x then tweens[name]=nil else
                        local p=math.min(1,(now-t.at)/(t.open and OPEN or CLOSE))
                        local a,dx=1-p,-SLIDE*p*p
                        if t.open then
                            a,dx=math.min(1,p/0.6),-SLIDE*(1-p)^2
                            if p<1 and p>=0.7 and t.flick<2 then a,t.flick=0.6,t.flick+1 end -- A signal flicker.
                        end
                        x:SetRenderOpacity(a)
                        x:SetRenderTranslation({X=dx,Y=0})
                        if p>=1 then
                            tweens[name]=nil
                            if not t.open then built.groups[name].v=COLLAPSED; x:SetVisibility(COLLAPSED) end
                        end
                    end
                end
            end)
        end
        return said_once()
    end
    -- A group: place {x, y, w, h in layout units, pivot (of the scale, top left unless said), shown, hit (its rows
    -- take the mouse: the menu)}; build(b) makes its widgets with the builders above at each root build and returns
    -- its view. Added before the first slow, or the root is built again.
    function self.add(name,place,build_view)
        local def={name=name,place=place,shown=place.shown==true,build=build_view}
        order[#order+1]=def
        by[name]=def
    end
    -- A group's view while the root is up, shown and ours; nil otherwise: hidden, before the first build or between a
    -- map change and the next slow (callers skip or queue), or off.
    function self.view(name) return not off and not hidden and built and built.views[name] or nil end
    function self.ready() return not off and not hidden and built~=nil end
    -- Turned off for this Lua load: only then do the callers go back to the notice line above EVE and the name tag.
    function self.off() return off end
    -- Shown or hidden; with now (the 1 ms loop's clock), the open tween (160 ms: a slide from the left with a
    -- flicker) or the close one (120 ms).
    function self.show(name,on,now)
        local def=by[name]
        on=on==true
        if not def or def.shown==on then return end
        def.shown=on
        local g=built and built.groups[name]
        if not g or off then return end
        tweens[name]=now and {at=now,open=on,flick=0} or nil
        if not on and now then return end
        g.v=on and g.on or COLLAPSED
        upd(g,function(x)
            x:SetVisibility(g.v)
            if on then
                x:SetRenderOpacity(now and 0 or 1)
                x:SetRenderTranslation({X=now and -SLIDE or 0,Y=0})
            end
        end)
    end
    -- A group's place (the marker follows her): on change only.
    function self.move(name,x,y)
        local g=built and built.groups[name]
        if not g or (g.x==x and g.y==y) then return end
        g.x,g.y=x,y
        upd(g,function() g.slot:SetPosition({X=x,Y=y}) end)
    end
    -- ui_scale, applied at once to every group, from its pivot.
    function self.scale(pct)
        local s=clamp(pct)
        if s==scale then return end
        scale=s
        for _,g in pairs(built and built.groups or {}) do upd(g,function(x) x:SetRenderScale({X=s,Y=s}) end) end
    end
    function self.sounds(on) sounding=on end -- ui_sounds.
    -- One of the game's UI sounds (Ui.ASSETS' with a volume), as a UI sound of our root's world.
    function self.sound(name)
        if off or quiet or not sounding or not built then return end
        local e=VOLUME[name] and cache[name]
        if not e then return end -- Not a sound, not warmed yet, or not in this build.
        local ok,why=pcall(function()
            local root,s=alive(built.root),valid(e.o)
            if not (s and U.text(s:GetFullName())==e.full) then cache[name]=nil; return end -- Freed: a later slow finds it.
            if root then U.find(STATICS):PlaySound2D(root,s,VOLUME[name],1,0) end
        end)
        if not ok then
            quiet=true
            log('UI sounds off until the mod reloads: '..tostring(why))
        end
    end
    -- The menu's input: on (only while the root is up) or off; each once.
    function self.input(on)
        on=on==true
        if on==inputting or off or (on and not self.ready()) then return end
        run(input_mode,on)
    end
    -- Whether the game is paused (its own menu, a cutscene): the menu does not open then. false when unread.
    function self.paused()
        if off then return false end
        local ok,paused=pcall(function() return U.find(STATICS):IsGamePaused(valid(UE.GetPlayerController())) end)
        return ok and paused==true
    end
    -- The game's text culture ('fr-FR'...; ui_text.lua picks the words), or nil when unread.
    function self.language()
        if off then return nil end
        local ok,culture=pcall(function() return U.text(U.find(LANGUAGE):GetCurrentLanguage()) end)
        return ok and culture or nil
    end
    -- coop off: the root goes now (the game's input back first); no engine call after.
    function self.stop()
        if off then return end
        close_all()
    end
    return self
end
return Ui
