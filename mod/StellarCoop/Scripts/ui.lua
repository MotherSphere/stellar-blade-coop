-- coop ui test: the UI-layer spike, a console command only (not for players yet), never on by itself. It builds a small
-- widget the way the UI layer would: a plain UserWidget whose WidgetTree and canvas are made by hand, holding a dark
-- panel, a title in the game's font, a row of the HUD's HP dots and a bar at 60 %; added to the viewport in the same
-- game-thread call, shown 5 s without taking any input, then removed. One [StellarCoop][UI] line per check (classes,
-- construct, tree, font, viewport, visible, input, GC, removed, timing), then a verdict. Fallbacks: a game widget class
-- with no logic as the root when the plain one fails (coop ui test game tries it alone), the engine font when the
-- game's is missing, the default font when none can be set, flat colour when the dots cannot be. Every engine step runs
-- in pcall on the game thread (the console handler, the 1 ms loop), never in a coroutine; nothing stays once removed.
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
local function clean(w) pcall(function() if valid(w.root) then w.root:RemoveFromParent() end end) end
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
            local function make(of,outer,what)
                return need(valid(StaticConstructObject(of,outer)),what..' was not constructed')
            end
            w.root=make(class,pc,'the root')
            w.tree=make(c.WidgetTree,w.root,'its WidgetTree')
            for _,name in ipairs(KIDS) do w[name]=make(c[name],w.tree,'a '..name) end
            w.canary=make(c.TextBlock,w.tree,'the canary') -- In no tree: the next GC frees it, which shows one ran.
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
            local w,class={kind=kind},c.UserWidget
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
        local root=w.root
        local there=valid(root)~=nil and root:IsInViewport()
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
                if not valid(w[name]) then lost[#lost+1]=name end
            end
            if #lost==0 and not (same(root.WidgetTree,w.tree) and same(w.tree.RootWidget,w.CanvasPanel)
                and w.CanvasPanel:GetChildrenCount()==4) then lost[1]='a link' end
            local ran=valid(w.canary)==nil
            check(8,'gc',#lost==0 and (ran or 'untested'),#lost>0 and 'lost: '..table.concat(lost,' ')
                or ran and 'a GC ran, the tree is whole' or 'no GC ran in '..SHOW..' s (the loose canary lives); '
                ..'the tree is whole')
        else
            check(6,'visible',false,'gone before the check: a map change removes viewport widgets')
            check(7,'input','skipped')
            check(8,'gc','skipped')
        end
        local removed,why=true,'the engine removed it with the map'
        if valid(root) then
            removed,why=pcall(function() root:RemoveFromParent() end)
            why=removed and 'RemoveFromParent' or tostring(why)
        end
        local out=not (valid(root) and root:IsInViewport())
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
return Ui
