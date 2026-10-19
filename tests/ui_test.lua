-- The UI spike (coop ui test) with fake UE4SS objects, engine GC and clock: the classes looked up; the root, its tree and
-- widgets built by hand and put in the viewport in the one game-thread call, with the tree, the font, the dots, the owner
-- and the hit-test setting all in before AddToViewport; shown 5 s, then checked and removed, one log line per check and a
-- verdict; a GC that runs (its canary freed, the tree kept by the viewport) or not, and one that loses the tree; the
-- fallbacks: the game's root class when the plain root fails to construct, add or show (and alone with game), the
-- verdict naming the next routes when no root shows, the engine font, the default font, flat colour; no input taken;
-- the timing budget; nothing left in the viewport whatever fails (a raise, coop off, a map change); no engine call while
-- idle; every call on UE4SS's own Lua state, never in a coroutine; a new test after each, nothing kept between them;
-- each read-back failing on its own (the tree, the canvas, the bar, the dots, the layout, the viewport, the hit tests,
-- a link); an address that holds another object after a map change is never touched, the player controller included.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
-- UE4SS refuses any call from a lua_State it did not create (a coroutine is one); the tests run on the main thread.
local function ue4ss()
    local _,main=coroutine.running()
    if main then return end
    error('[process_lua_function] The lua state has no instance inside lua_instances unordered map',3)
end
local calls={} -- Every engine call, in order: 'Class.Method', 'set Class.Field', 'construct Class in Outer'.
local function call(name) ue4ss(); calls[#calls+1]=name end
local modes={} -- 'raise': a write into that struct raises; 'copy': each read is a copy, so writes do not stick.
local stuck={} -- 'Class.Field': that write is made but not kept, so its read-back fails.
-- A struct property as UE4SS gives it: a view on the object's memory, its writes recorded.
local function struct(name,data,copy)
    local target=data
    if copy then target={}; for k,v in pairs(data) do target[k]=v end end
    return setmetatable({},{__index=target,__newindex=function(_,k,v)
        call('set '..name..'.'..k)
        if modes[name]=='raise' then error(name..' is read-only here',0) end
        target[k]=v
    end})
end
local stores,next_address={},0x1000 -- Each fake's fields, by fake.
local function object(name,fields,methods,getters)
    local store={name=name}
    for k,v in pairs(fields or {}) do store[k]=v end
    next_address=next_address+0x100
    local at=next_address
    store.full=string.format('%s /Engine/Transient.%s_%x',name,name,at) -- Unique, as the engine's object names are.
    store.type=function() return 'UObject' end
    store.IsValid=function() ue4ss(); return not store.destroyed end
    store.GetFullName=function() ue4ss(); return store.full end
    store.GetAddress=function() return at end
    for k,f in pairs(methods or {}) do store[k]=function(self,...) call(name..'.'..k); return f(self,...) end end
    local o=setmetatable({},{__index=function(_,k) if getters and getters[k] then return getters[k]() end
        return store[k] end,__newindex=function(_,k,v)
            call('set '..name..'.'..k)
            if not stuck[name..'.'..k] then store[k]=v end
        end})
    stores[o]=store
    return o
end
local invalid=object('Invalid',{destroyed=true}) -- What UE4SS returns for nothing found.
local BOLD,ROBOTO='/Game/Art/Font/Bold.Bold','/Engine/EngineFonts/Roboto.Roboto'
local DOTS='/Game/Art/UI/Texture/HUD/Gauge/Hp_Dot1_5x.Hp_Dot1_5x'
local GAME='/Game/Art/UI/Widget/GameMenu/Setting/Slot/WB_Setting_Category'
local GAME_CLASS=GAME..'.WB_Setting_Category_C'
local TEAL={R=0.678,G=0.82,B=0.769,A=1}
local registry,loadable,loads,constructed,viewport,laid_out
local fail_construct,fail_add,hidden,fail_remove,fail_size,focus_taken,gc_runs,gc_eats,gc_queued,add_cost,no_layout
local pc,lines
local function find(path) return registry[path] end
-- The widgets UE4SS would construct, by class name.
local makers={}
local function root(name)
    return function()
        local o
        o=object(name,{Visibility=0},{
            SetOwningPlayer=function(_,p) stores[o].owner=p end,
            SetVisibility=function(_,v) stores[o].Visibility=v end,
            GetVisibility=function() return stores[o].Visibility end,
            AddToViewport=function(_,z)
                clock=clock+add_cost
                if fail_add[name] then error(fail_add[name],0) end
                stores[o].z=z
                viewport[#viewport+1]=o
            end,
            IsInViewport=function() for _,r in ipairs(viewport) do if r==o then return true end end return false end,
            IsVisible=function() return not hidden[name] and o:IsInViewport() end,
            GetDesiredSize=function()
                if fail_size then error(fail_size,0) end
                return laid_out[o] and {X=1420,Y=1160} or {X=0,Y=0}
            end,
            HasAnyUserFocus=function() return focus_taken end,
            HasFocusedDescendants=function() return false end,
            RemoveFromParent=function()
                if fail_remove then error(fail_remove,0) end
                for i,r in ipairs(viewport) do if r==o then table.remove(viewport,i) end end
            end,
        })
        return o
    end
end
makers.UserWidget=root('UserWidget')
makers.WB_Setting_Category_C=root('WB_Setting_Category_C')
makers.WidgetTree=function() return object('WidgetTree') end
makers.CanvasPanel=function()
    local o
    o=object('CanvasPanel',{children={}},{
        AddChildToCanvas=function(_,child)
            local list=stores[o].children
            if not stuck['CanvasPanel.children'] then list[#list+1]=child end
            local slot
            slot=object('CanvasPanelSlot',{content=child},{
                SetPosition=function(_,at) stores[slot].at=at end,
                SetSize=function(_,size) stores[slot].size=size end,
                SetAutoSize=function(_,on) stores[slot].auto=on end})
            stores[child].slot=slot
            return slot
        end,
        GetChildrenCount=function() return #stores[o].children end})
    return o
end
makers.Border=function()
    local o
    o=object('Border',{},{SetBrushColor=function(_,c) stores[o].color=c end})
    return o
end
makers.TextBlock=function()
    local o
    local font={FontObject=registry[ROBOTO],Size=24} -- UTextBlock's default.
    o=object('TextBlock',{font=font},{
        SetText=function(_,t) stores[o].text=t.text end,
        SetFont=function(_,info)
            if modes.SetFont then error(modes.SetFont,0) end
            font.FontObject,font.Size=info.FontObject,info.Size
        end},
        {Font=function() return struct('Font',font,modes.Font=='copy') end})
    return o
end
makers.Image=function()
    local o
    local brush={Tiling=0,DrawAs=3}
    o=object('Image',{brush=brush},{
        SetColorAndOpacity=function(_,c) stores[o].tint=c end,
        SetBrushFromTexture=function(_,texture,match)
            assert(match==true)
            if not stuck['Image.ResourceObject'] then brush.ResourceObject=texture end
        end},
        {Brush=function() return struct('Brush',brush,modes.Brush=='copy') end})
    return o
end
makers.ProgressBar=function()
    local o
    o=object('ProgressBar',{Percent=0},{
        SetPercent=function(_,p) if not stuck['ProgressBar.Percent'] then stores[o].Percent=p end end,
        SetFillColorAndOpacity=function(_,c) stores[o].fill=c end})
    return o
end
StaticFindObject=function(path) ue4ss(); return registry[path] or invalid end
LoadAsset=function(path)
    call('LoadAsset '..path)
    loads[#loads+1]=path
    local o=loadable[path]
    if o then registry[o[1]]=o[2] end
end
StaticConstructObject=function(class,outer)
    call('construct '..stores[class].name..' in '..stores[outer].name)
    if fail_construct[stores[class].name] then return invalid end
    local o=makers[stores[class].name]()
    constructed[#constructed+1]=o
    return o
end
FText=function(text) ue4ss(); return {text=text} end
package.loaded.UEHelpers={GetPlayerController=function() ue4ss(); return pc end}
-- The engine's GC: whatever no viewport root reaches through its tree goes (gc_eats='WidgetTree': the root's link to
-- its tree is not seen, so the tree and its widgets go).
local function collect()
    local keep={}
    local function mark(o)
        if o==nil or keep[o] then return end
        keep[o]=true
        local s=stores[o]
        if gc_eats~='WidgetTree' then mark(s.WidgetTree) end
        mark(s.RootWidget)
        for _,child in ipairs(s.children or {}) do mark(child) end
    end
    for _,r in ipairs(viewport) do mark(r) end
    for _,o in ipairs(constructed) do if not keep[o] then stores[o].destroyed=true end end
end
-- A frame's end: the GC asked, if this build runs it, and Slate's layout of what the viewport holds.
local function frame()
    if gc_queued and gc_runs then collect() end
    gc_queued=false
    if not no_layout then for _,r in ipairs(viewport) do laid_out[r]=true end end
end
local function reset()
    for _,o in pairs(registry or {}) do stores[o].destroyed=true end -- unreal.lua's cache looks them up again.
    registry,loadable,loads,constructed,viewport,laid_out={},{},{},{},{},{}
    fail_construct,fail_add,hidden,fail_remove,fail_size={},{},{},nil,nil
    focus_taken,gc_runs,gc_eats,gc_queued,add_cost,no_layout=false,true,nil,false,0,false
    for k in pairs(modes) do modes[k]=nil end
    for k in pairs(stuck) do stuck[k]=nil end
    calls,lines={},{}
    clock=100
    pc=object('PC',{bShowMouseCursor=false},{IsA=function(_,class) return stores[class].name=='PlayerController' end})
    registry['/Script/Engine.PlayerController']=object('PlayerController')
    for _,name in ipairs({'UserWidget','WidgetTree','CanvasPanel','Border','TextBlock','Image','ProgressBar'}) do
        registry['/Script/UMG.'..name]=object(name)
    end
    registry[BOLD]=object('Bold')
    registry[ROBOTO]=object('Roboto')
    registry[DOTS]=object('Hp_Dot1_5x')
    loadable[GAME..'.WB_Setting_Category']={GAME_CLASS,object('WB_Setting_Category_C')} -- Its package, loaded.
    registry['/Script/Engine.Default__KismetSystemLibrary']=object('KismetSystemLibrary',{},
        {CollectGarbage=function() gc_queued=true end})
end
local Ui=require('ui')
local function new() return Ui.new(function(m) ue4ss(); lines[#lines+1]=m end) end
local function at(name) for i,c in ipairs(calls) do if c==name then return i end end end
local function count(name) local n=0; for _,c in ipairs(calls) do if c==name then n=n+1 end end return n end
local function line(prefix) for _,l in ipairs(lines) do if l:sub(1,#prefix)==prefix then return l end end end
local function all() return table.concat(lines,'\n') end
local function constructs()
    local list={}
    for _,c in ipairs(calls) do if c:find('^construct ') then list[#list+1]=c:sub(11) end end
    return table.concat(list,', ')
end
local function finish(ui) frame(); clock=clock+5; ui.tick() end
local VERDICT='verdict: route A works with a plain UserWidget root; look: Bold, dots tiled. On screen for 5 s: a dark '
    ..'panel left of centre, the title, a teal row of dots, a bar at 60 %'
local NEXT='verdict: no runtime UMG widget here. Next: fallback 2, a Canvas draw in a ReceiveDrawHUD post-hook, then '
    ..'route B, a cooked widget pak; the keys, the notice line and the console work as before'

-- The plain root: built by hand, all in before AddToViewport, in this one call.
reset()
local ui=new()
local ok,why=ui.test(false)
assert(ok and why=='UI test on screen for 5 s (plain root); its checks follow in the log',why)
assert(constructs()=='UserWidget in PC, WidgetTree in UserWidget, CanvasPanel in WidgetTree, Border in WidgetTree, '
    ..'TextBlock in WidgetTree, Image in WidgetTree, ProgressBar in WidgetTree, TextBlock in WidgetTree',constructs())
local add=at('UserWidget.AddToViewport')
assert(add and count('UserWidget.AddToViewport')==1,'Added once, in this call')
for _,before in ipairs({'set UserWidget.WidgetTree','set WidgetTree.RootWidget','set Font.FontObject','set Font.Size',
        'set Brush.Tiling','Image.SetBrushFromTexture','UserWidget.SetOwningPlayer','UserWidget.SetVisibility'}) do
    assert(at(before) and at(before)<add,before..' before AddToViewport')
end
assert(at('KismetSystemLibrary.CollectGarbage')>add,'One GC asked while it shows')
assert(lines[1]=='check 1/10 classes: ok (all 7 UMG classes)',lines[1])
assert(lines[2]=='check 2/10 construct: ok (root, tree and 6 widgets)',lines[2])
assert(lines[3]=='check 3/10 tree: ok (canvas: panel, title, dots tiled, bar at 60 %)',lines[3])
assert(lines[4]=='check 4/10 font: ok (Bold 40, written in place)',lines[4])
assert(lines[5]=='check 5/10 viewport: ok (z 100, hit tests pass through)',lines[5])
assert(#lines==5,all())
local first=viewport[1]
local s=stores[first]
assert(#viewport==1 and s.z==100 and s.owner==pc and s.Visibility==3,'Owned by the player, no hit tests, z 100')
local tree=s.WidgetTree
local canvas=stores[tree].RootWidget
local kids=stores[canvas].children
assert(#kids==4 and stores[kids[1]].name=='Border' and stores[kids[2]].name=='TextBlock' and stores[kids[3]].name=='Image'
    and stores[kids[4]].name=='ProgressBar','The panel first, under the rest')
local function slot(k) return stores[stores[kids[k]].slot] end
assert(slot(1).at.X==180 and slot(1).size.X==1240 and slot(2).auto==true and slot(3).size.X==600 and slot(4).at.Y==1050)
assert(stores[kids[1]].color.A==0.78 and stores[kids[2]].text=='StellarCoop UI test')
assert(stores[kids[2]].font.FontObject==registry[BOLD] and stores[kids[2]].font.Size==40,'The game font, 40')
local brush=stores[kids[3]].brush
assert(brush.ResourceObject==registry[DOTS] and brush.Tiling==3 and stores[kids[3]].tint.G==TEAL.G,'Teal dots, tiled')
assert(stores[kids[4]].Percent==0.6 and stores[kids[4]].fill.R==TEAL.R,'A teal bar at 60 %')
-- Nothing while it shows, before its time.
local n=#calls
clock=clock+4.9; ui.tick()
assert(#calls==n and #lines==5,'No engine call before the 5 s are up')
clock=clock-4.9
local again,busy=ui.test(false)
assert(not again and busy=='a UI test is on screen already; its checks follow within 5 s' and #calls==n,busy)
finish(ui)
assert(lines[6]=='check 6/10 visible: ok (visible true, laid out at 1420x1160)',lines[6])
assert(lines[7]=='check 7/10 input: ok (keyboard focus none, hit tests pass through, mouse cursor as before)',lines[7])
assert(lines[8]=='check 8/10 gc: ok (a GC ran, the tree is whole)',lines[8])
assert(lines[9]=='check 9/10 removed: ok (RemoveFromParent)',lines[9])
assert(lines[10]=='check 10/10 timing: ok (0.0 ms in one frame: classes 0.0, build and assets 0.0, viewport 0.0; '
    ..'budget 50 ms)',lines[10])
assert(lines[11]==VERDICT and #lines==11,all())
assert(#viewport==0,'Removed')
assert(stores[constructed[8]].destroyed and not stores[canvas].destroyed,'The loose canary went, the tree stayed')
n=#calls
clock=clock+60; ui.tick(); frame(); ui.tick()
assert(#calls==n,'Idle: no engine call')
-- Nothing kept: the next test builds a new root.
lines={}
assert(ui.test(false))
assert(viewport[1]~=first and #viewport==1 and lines[1]=='check 1/10 classes: ok (all 7 UMG classes)')
finish(ui)
assert(#viewport==0 and lines[#lines]==VERDICT,all())

-- No GC in those 5 s: the canary lives, so GC loss is untested.
reset(); gc_runs=false
ui=new(); assert(ui.test(false)); finish(ui)
assert(line('check 8/')=='check 8/10 gc: untested (no GC ran in 5 s (the loose canary lives); the tree is whole)',all())
assert(lines[#lines]==VERDICT,'Untested is no failure')
-- A GC that loses the tree is a failure.
reset(); gc_eats='WidgetTree'
ui=new(); assert(ui.test(false)); finish(ui)
assert(line('check 8/')=='check 8/10 gc: FAIL (lost: tree CanvasPanel Border TextBlock Image ProgressBar)',all())
assert(lines[#lines]=='verdict: route A built a plain UserWidget root, but check 8 gc failed' and #viewport==0,all())
-- The lost tree's address taken by another object by then: still lost.
reset(); gc_eats='WidgetTree'
ui=new(); assert(ui.test(false)); frame()
local lost_tree=stores[viewport[1]].WidgetTree
stores[lost_tree].destroyed,stores[lost_tree].full=false,'WidgetTree /Game/Maps/Next.Other'
clock=clock+5; ui.tick()
assert(line('check 8/')=='check 8/10 gc: FAIL (lost: tree CanvasPanel Border TextBlock Image ProgressBar)',all())

-- Fonts: the engine's when the game's is missing; SetFont when the in-place write raises; the default when neither
-- takes, which only degrades the look.
reset(); registry[BOLD]=nil
ui=new(); assert(ui.test(false))
assert(lines[4]=='check 4/10 font: fallback (Roboto (the game font is missing) 40, written in place)',lines[4])
assert(loads[1]==BOLD,'Loaded before giving up on it')
finish(ui)
assert(lines[#lines]==VERDICT:gsub('Bold','Roboto'),lines[#lines])
reset(); registry[BOLD]=nil; loadable[BOLD]={BOLD,object('Bold')}
ui=new(); assert(ui.test(false)); assert(lines[4]=='check 4/10 font: ok (Bold 40, written in place)',lines[4])
reset(); modes.Font='raise'
ui=new(); assert(ui.test(false))
assert(lines[4]=='check 4/10 font: ok (Bold 40, through SetFont (in place: Font is read-only here))',lines[4])
assert(stores[stores[stores[stores[viewport[1]].WidgetTree].RootWidget].children[2]].font.FontObject==registry[BOLD])
reset(); modes.Font='copy'; modes.SetFont='no overload for SetFont'
ui=new(); assert(ui.test(false))
assert(lines[4]=='check 4/10 font: FAIL (neither the in-place write nor SetFont took (no overload for SetFont); the '
    ..'default font stays)',lines[4])
assert(lines[5]=='check 5/10 viewport: ok (z 100, hit tests pass through)','The font never stops the build')
finish(ui)
assert(lines[#lines]==VERDICT:gsub('Bold','default font'),lines[#lines])
reset(); modes.Font='copy'
ui=new(); assert(ui.test(false))
assert(lines[4]=='check 4/10 font: ok (Bold 40, through SetFont (in place: did not stick))',lines[4])
-- Dots: flat colour when the tiling does not take (and then the texture is never set) or the texture is missing.
for _,case in ipairs({{'raise','flat colour: the brush tiling raised Brush is read-only here'},
        {'copy','flat colour: the brush tiling did not stick'},{nil,'flat colour: no Hp_Dot1_5x texture'}}) do
    reset(); modes.Brush=case[1]
    if not case[1] then registry[DOTS]=nil end
    ui=new(); assert(ui.test(false))
    assert(lines[3]=='check 3/10 tree: ok (canvas: panel, title, '..case[2]..', bar at 60 %)',lines[3])
    assert(not at('Image.SetBrushFromTexture') and stores[constructed[6]].tint.B==TEAL.B,'Flat teal')
    assert(case[1] or loads[1]==DOTS)
    finish(ui)
    assert(lines[#lines]=='verdict: route A works with a plain UserWidget root; look: Bold, '..case[2]..'. On screen for '
        ..'5 s: a dark panel left of centre, the title, a teal row of dots, a bar at 60 %',lines[#lines])
end

-- Fallback 1: the plain root fails to add, to show or to be constructed; the game's plain widget class is the root
-- (its package loaded first), with the same tree; the failed root never stays in the viewport.
for _,case in ipairs({
        {function() fail_add.UserWidget='AddToViewport: no game viewport' end,
            'check 5/10 viewport: FAIL (AddToViewport: no game viewport)'},
        {function() hidden.UserWidget=true end,'check 5/10 viewport: FAIL (in the viewport but not visible)'},
        {function() fail_construct.UserWidget=true end,'check 2/10 construct: FAIL (the root was not constructed)'}}) do
    reset(); case[1]()
    ui=new(); ok,why=ui.test(false)
    assert(ok and why=='UI test on screen for 5 s (game root); its checks follow in the log',why)
    assert(line(case[2]:sub(1,12))==case[2],all())
    assert(line('fallback 1')=="fallback 1: the game's WB_Setting_Category_C as the root",all())
    assert(loads[#loads]==GAME..'.WB_Setting_Category' and at('construct WB_Setting_Category_C in PC'))
    assert(#viewport==1 and stores[viewport[1]].name=='WB_Setting_Category_C','Only the game root shows')
    assert(stores[stores[stores[viewport[1]].WidgetTree].RootWidget].name=='CanvasPanel','Our tree in it')
    finish(ui)
    assert(lines[#lines]=="verdict: route A works with fallback 1, the game's WB_Setting_Category_C as the root; look: "
        ..'Bold, dots tiled. On screen for 5 s: a dark panel left of centre, the title, a teal row of dots, a bar at '
        ..'60 %',all())
    assert(#viewport==0)
end
-- coop ui test game: the game root alone.
reset()
ui=new(); assert(ui.test(true))
assert(not at('construct UserWidget in PC') and at('construct WB_Setting_Category_C in PC') and not line('fallback'))
finish(ui); assert(#viewport==0 and lines[#lines]:find("^verdict: route A works with fallback 1"),all())
-- Neither root shows: the verdict names the next routes, nothing stays, and a new test may run.
for _,case in ipairs({
        {function() fail_add.UserWidget='no'; fail_add.WB_Setting_Category_C='no' end,'check 5/10 viewport: FAIL (no)'},
        {function() fail_add.UserWidget='no'; loadable={} end,
            'check 2/10 construct: FAIL (WB_Setting_Category_C is not in this build)'}}) do
    reset(); case[1]()
    ui=new(); ok,why=ui.test(false)
    assert(not ok and why=='UI test failed: see the [StellarCoop][UI] lines',why)
    assert(lines[#lines-1]==case[2] and lines[#lines]==NEXT,all())
    assert(#viewport==0 and count('UserWidget.RemoveFromParent')==1,'The failed root is taken out')
    n=#calls; clock=clock+60; ui.tick(); assert(#calls==n,'Nothing pending')
    fail_add={}; lines={}
    assert(ui.test(false),'A new test may run')
end
-- A UMG class missing: nothing is constructed.
reset(); registry['/Script/UMG.ProgressBar']=nil
ui=new(); ok=ui.test(false)
assert(not ok and lines[1]=='check 1/10 classes: FAIL (missing: ProgressBar)' and lines[2]==NEXT and #lines==2,all())
assert(constructs()=='','Nothing constructed')

-- Input: focus taken or the cursor changed fails check 7.
reset(); focus_taken=true
ui=new(); assert(ui.test(false)); finish(ui)
assert(line('check 7/')=='check 7/10 input: FAIL (keyboard focus taken, hit tests pass through, mouse cursor as before)')
assert(lines[#lines]=='verdict: route A built a plain UserWidget root, but check 7 input failed',lines[#lines])
reset()
ui=new(); assert(ui.test(false)); stores[pc].bShowMouseCursor=true; finish(ui)
assert(line('check 7/')=='check 7/10 input: FAIL (keyboard focus none, hit tests pass through, mouse cursor changed)')
-- Over the 50 ms budget: slow, said, not a failure.
reset(); add_cost=0.06
ui=new(); assert(ui.test(false)); finish(ui)
assert(line('check 10/')=='check 10/10 timing: slow (60.0 ms in one frame: classes 0.0, build and assets 0.0, viewport '
    ..'60.0; budget 50 ms)',all())
assert(lines[#lines]==VERDICT,lines[#lines])

-- Every way out leaves nothing in the viewport: coop off, a map change, a raise during the checks; a removal that
-- raises is said.
reset()
ui=new(); assert(ui.test(false)); ui.stop()
assert(#viewport==0 and lines[#lines]=='the test stopped with coop off; the widget is removed',all())
n=#calls; finish(ui); ui.stop(); assert(#calls==n,'Nothing after it')
reset()
ui=new(); assert(ui.test(false))
for _,o in ipairs(constructed) do stores[o].destroyed=true end
viewport={} -- The level went with its viewport widgets.
finish(ui)
assert(line('check 6/')=='check 6/10 visible: FAIL (gone before the check: a map change removes viewport widgets)')
assert(line('check 7/')=='check 7/10 input: skipped' and line('check 8/')=='check 8/10 gc: skipped')
assert(line('check 9/')=='check 9/10 removed: ok (the engine removed it with the map)',all())
assert(lines[#lines]=='verdict: route A built a plain UserWidget root, but check 6 visible failed',lines[#lines])
reset(); fail_size='GetDesiredSize: bad struct'
ui=new(); assert(ui.test(false)); finish(ui)
assert(lines[#lines]=='the checks stopped: GetDesiredSize: bad struct; the widget is removed' and #viewport==0,all())
reset()
ui=new(); assert(ui.test(false)); fail_remove='RemoveFromParent: no parent'; finish(ui)
assert(line('check 9/')=='check 9/10 removed: FAIL (RemoveFromParent: no parent; still in the viewport)',all())
-- No player controller: nothing at all.
reset(); pc=nil
ui=new(); ok,why=ui.test(false)
assert(not ok and why=='no player controller yet: load a save first' and #calls==0 and #lines==0)
-- The player controller UEHelpers keeps, its address now another object's: nothing at all.
reset(); pc=object('HUD',{},{IsA=function() return false end})
ui=new(); ok,why=ui.test(false)
assert(not ok and why=='no player controller yet: load a save first' and constructs()=='' and #lines==0,why)

-- Each read-back on its own. Check 3: the root's tree link (the game root then shows), the canvas's children, the bar.
for _,case in ipairs({{'UserWidget.WidgetTree','the tree did not read back',true},
        {'CanvasPanel.children','the canvas holds 0 widgets, not 4'},
        {'ProgressBar.Percent',"the bar's value did not read back"}}) do
    reset(); stuck[case[1]]=true
    ui=new(); ok=ui.test(false)
    assert(lines[3]=='check 3/10 tree: FAIL ('..case[2]..')' and line('fallback 1'),all())
    if case[3] then
        assert(ok and #viewport==1 and stores[viewport[1]].name=='WB_Setting_Category_C',all())
        finish(ui); assert(lines[#lines]:find('^verdict: route A works with fallback 1'),all())
    else
        assert(not ok and lines[#lines]==NEXT and #viewport==0,all())
    end
end
-- The dots set but not read back.
reset(); stuck['Image.ResourceObject']=true
ui=new(); assert(ui.test(false))
assert(lines[3]=='check 3/10 tree: ok (canvas: panel, title, dots set, not read back, bar at 60 %)',lines[3])
-- Check 6: shown but never laid out; taken out of the viewport while it lives (not a map change).
reset(); no_layout=true
ui=new(); assert(ui.test(false)); finish(ui)
assert(line('check 6/')=='check 6/10 visible: FAIL (visible true, laid out at 0x0)',all())
assert(lines[#lines]=='verdict: route A built a plain UserWidget root, but check 6 visible failed',lines[#lines])
reset()
ui=new(); assert(ui.test(false)); frame(); viewport={}; clock=clock+5; ui.tick()
assert(line('check 6/')=='check 6/10 visible: FAIL (out of the viewport but not freed: the game took it out)',all())
assert(line('check 7/')=='check 7/10 input: skipped' and line('check 9/')=='check 9/10 removed: ok (RemoveFromParent)')
-- Check 7: hit tests caught again. Check 8: the tree's link to its canvas gone after the GC.
reset()
ui=new(); assert(ui.test(false)); stores[viewport[1]].Visibility=0; finish(ui)
assert(line('check 7/')=='check 7/10 input: FAIL (keyboard focus none, hit tests caught, mouse cursor as before)',all())
reset()
ui=new(); assert(ui.test(false)); frame()
stores[stores[viewport[1]].WidgetTree].RootWidget=nil; clock=clock+5; ui.tick()
assert(line('check 8/')=='check 8/10 gc: FAIL (lost: a link)',all())

-- After a map change, the root's address holds a HUD widget of the new map: it is never removed (at the check, at
-- coop off). The canary's address taken by another object after the GC freed it: the GC still counts as run.
for i,leave in ipairs({function(u) clock=clock+5; u.tick() end,function(u) u.stop() end}) do
    reset()
    ui=new(); assert(ui.test(false))
    local r=viewport[1]
    for _,o in ipairs(constructed) do stores[o].destroyed=true end
    stores[r].destroyed,stores[r].full=false,'UserWidget /Game/Maps/Next.Next:PersistentLevel.HUD_Hp'
    leave(ui)
    assert(#viewport==1 and viewport[1]==r and count('UserWidget.RemoveFromParent')==0,all())
    assert(i==2 or line('check 6/')=='check 6/10 visible: FAIL (gone before the check: a map change removes viewport '
        ..'widgets)' and line('check 9/')=='check 9/10 removed: ok (the engine removed it with the map)',all())
end
reset()
ui=new(); assert(ui.test(false)); frame()
local canary=constructed[8]
assert(stores[canary].destroyed)
stores[canary].destroyed,stores[canary].full=false,'TextBlock /Game/Maps/Next.Next:PersistentLevel.Other'
clock=clock+5; ui.tick()
assert(line('check 8/')=='check 8/10 gc: ok (a GC ran, the tree is whole)',all())
io.stdout:write('ui_test ok\n')
