-- The between-regions teleport screen's extra tabs. WB_AreaTeleport_Set has 7 tabs, and SB's Region logic drops every
-- active Tetrapod past them. This makes tabs 8 and 9 when the screen is built, and SB fills them: the native part
-- (game/region_tabs.h) gives each one the logic node a class-property tab gets, so its camp, thumbnail, unlock and
-- travel all run SB's own code. Each tab starts collapsed and only that logic shows it, so a tab without a node (the
-- native hook refused or faulted, coop off, the screen built in another order) is never seen and can take no focus; SB
-- collapses the tabs it has no camp for. The row clips and shows a horizontal bar once it overflows, which 9 tabs do
-- (3750 units across 3528), and the engine keeps the bar collapsed until then. The bar drags with the mouse. Only UI: no
-- save, trophy or inventory call.
--
-- Tabs stop at 9 because SB's input stays locked until every unlocking tab's animation ends, and Slate neither paints nor
-- ticks a widget wholly outside the row. 9 tabs scroll 222 units and each is 410 wide, so all stay partly painted. A 10th
-- would start at 3700 and could hang the screen.
--
-- Keyboard and gamepad: focus on a tab tells the Region logic which camp a hold takes, through NotifyBlueprint with the
-- tab's name, whose last token is its 1-based place. The Set's Construct binds that for Tab_1 to Tab_7 only, so the
-- Tab's focus hook sends it for the others. Without it a hold on tab 8 would go to the last vanilla tab's camp, so a
-- failed send collapses the tab.
--
-- The game can unload a Blueprint nothing references, and a new class would have no hook. A rooted, never-shown Set
-- keeps its class and the Tab class. Every engine call runs in pcall on the game thread; the first error stops new tabs
-- until the next Lua load, with one log line. tests/lua/ui/region_tabs_test.lua covers it over fakes.
local U=require('core.unreal')
local Tabs={FIRST=8,LAST=9}
local FOLDER='/Game/Art/UI/Widget/GameMenu/Teleport/'
local SET=FOLDER..'WB_AreaTeleport_Set.WB_AreaTeleport_Set'
local TAB=FOLDER..'WB_AreaTeleport_Tab.WB_AreaTeleport_Tab'
local KEEPER=FOLDER..'WB_AreaTeleport_Set.StellarCoop_RegionTabsKeeper'
local NAME='WB_AreaTeleport_Tab_' -- A tab's TabName, as the Set's own 7 store it: an empty one crashes the notify.
local CHILDREN=9 -- Spacer_50, Tab_1 to Tab_7, Spacer.
local PUBLIC,ROOT_SET=0x1,0x40000000 -- As cut/tendril.lua: RF_Public; EInternalObjectFlags::RootSet.
local COLLAPSED,CLIP_TO_BOUNDS,BAR_VISIBLE,CENTER=1,1,0,2 -- ESlateVisibility, EWidgetClipping, EHAlign/EVAlign.
local PADDING={Left=-20,Top=20,Right=-20,Bottom=20} -- As the Set's tab slots.
local THICKNESS={X=24,Y=24}

-- A class by its asset's path, loaded when it is not in memory.
local function class_of(asset)
    local class=U.valid(StaticFindObject(asset..'_C'))
    if class then return class end
    pcall(LoadAsset,asset)
    return assert(U.valid(StaticFindObject(asset..'_C')),asset..' is not in this game build')
end

-- o: {log=function(line), ready=function() whether the game is far enough to load the screen's classes}.
function Tabs.new(o)
    local log=o.log
    local hooked,failed,stopped=false,false,false
    local function fail(e)
        failed=true
        log('STOP: '..tostring(e)..'; the teleport screen keeps its 7 tabs until the mod reloads')
    end
    local function make(set,root,class,i,made)
        local t=assert(U.valid(set:CreateDynamicChildUserWidget(class,root)),'no tab '..i)
        made[#made+1]=t
        t:SetVisibility(COLLAPSED)
        t.TabCount=i
        t.TabName=NAME..i
        assert(U.text(U.value_of(t.TabName))==NAME..i,'tab '..i..' kept no name')
        local slot=assert(U.valid(t.Slot),'tab '..i..' has no slot')
        slot:SetPadding(PADDING)
        slot:SetHorizontalAlignment(CENTER)
        slot:SetVerticalAlignment(CENTER)
        t:PreConstruct(false) -- Its number, from TabCount.
    end
    -- The trailing spacer goes back after the new tabs, whatever happened, and no half-made tab stays.
    local function add(set)
        local root=assert(U.valid(set.HB_AreaTeleportRoot),'the screen has no HB_AreaTeleportRoot')
        local n=root:GetChildrenCount()
        if n>CHILDREN then return end -- Construct again on the same screen.
        assert(n==CHILDREN,'the row has '..n..' children, not '..CHILDREN)
        local class=assert(U.valid(set.WB_AreaTeleport_Tab_1),'the screen has no Tab_1'):GetClass()
        local spacer=assert(U.valid(root:GetChildAt(n-1)),'the row has no last child')
        root:RemoveChild(spacer)
        local made={}
        local ok,e=pcall(function() for i=Tabs.FIRST,Tabs.LAST do make(set,root,class,i,made) end end)
        if not ok then
            for _,t in ipairs(made) do pcall(root.RemoveChild,root,t) end
        end
        root:AddChild(spacer)
        if not ok then error(e,0) end
        root:SetClipping(CLIP_TO_BOUNDS)
        root:SetScrollBarVisibility(BAR_VISIBLE)
        root:SetScrollbarThickness(THICKNESS)
    end
    local function on_construct(ctx)
        if failed or stopped then return end
        local ok,e=pcall(function()
            add(assert(U.valid(ctx),'Construct gave no screen'))
        end)
        if not ok then fail(e) end
    end
    -- Runs after a stop or a failure too: a tab already on screen must keep sending, or a hold would go to the wrong
    -- camp.
    local function on_focus(ctx)
        local tab=U.valid(ctx)
        if not tab then return end
        local read,count=pcall(function() return U.value_of(tab.TabCount) end)
        if not read or type(count)~='number' or count<Tabs.FIRST then return end -- A vanilla tab is never touched.
        local ok,e=pcall(function()
            assert(U.valid(tab.ParentWidget),'the tab has no parent'):NotifyBlueprint(U.text(U.value_of(tab.TabName)))
        end)
        if ok then return end
        pcall(function() tab:SetVisibility(COLLAPSED) end)
        if not failed then fail(e) end
    end
    local function install()
        local set=class_of(SET)
        class_of(TAB)
        if not U.valid(StaticFindObject(KEEPER)) then
            assert(U.valid(StaticConstructObject(set,set:GetOuter(),FName('StellarCoop_RegionTabsKeeper',1),PUBLIC,
                ROOT_SET)),'no keeper')
        end
        -- The focus hook first: tabs never exist without it.
        RegisterHook(TAB..'_C:EventWidgetFocusActive',on_focus)
        RegisterHook(SET..'_C:Construct',on_construct)
        log('hooks on: WB_AreaTeleport_Set_C:Construct, WB_AreaTeleport_Tab_C:EventWidgetFocusActive')
    end
    local self={}
    -- Once a Lua load, as soon as the game is far enough. Nothing after that.
    function self.tick()
        if hooked or stopped or not o.ready() then return end
        hooked=true
        local ok,e=pcall(install)
        if not ok then fail(e) end
    end
    -- coop off: no more tabs. The native part puts its slot back.
    function self.stop() stopped=true end
    return self
end
return Tabs
