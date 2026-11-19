-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The pause menu's Online tab. SB's pause menu (WB_GameMenu_Master) has 8 tabs; this adds a 9th button after them that
-- opens the co-op menu. SB's GameMenu logic serves 8 tabs only, so the button has no tab data: it is HitTestInvisible
-- (SB's click code never sees it) and only shows the word. RB on Settings reaches it through the native part
-- (ui/pause_tab.h: RB on the highest enabled tab becomes coop_pad's event 12, E on the keyboard too, as SB maps it
-- to the same action), a left click through main.lua's mouse bind and the button's cached geometry. Either closes the
-- pause menu through the native part's coop_pause_close, which runs SB's own close (what SB's Back runs, with its
-- menu-close save and the shown tab's deactivate), then opens the co-op menu once the game is unpaused, as menu_key
-- does; still paused after WAIT s, it gives up with one log line and one notice. A close the native part cannot make
-- at all stops the tab as an error does. The tab bar's own right arrow on Settings still wraps to Equipment: SB binds
-- it straight to its next-tab function.
--
-- The button copies its text style from SB's last button. A container rebuilt without it gets it again from the 250 ms
-- loop while the game is paused. A rooted, never-shown master keeps the class in memory, so the hook stays on it. Every
-- engine call runs in pcall on the game thread; the first error stops the tab until the next Lua load with one STOP
-- line. The native part is then asked pausetab off, so RB on Settings wraps to Equipment as in the game. Only UI: no
-- save, trophy or inventory call of its own (SB's close saves only as it does on Back).
-- tests/lua/ui/kit/pause_tab_test.lua covers it over fakes.
local U=require('core.unreal')
local Keep=require('core.keep')
local Tab={WAIT=2}
local MASTER='/Game/Art/UI/Widget/GameMenu/WB_GameMenu_Master.WB_GameMenu_Master'
local KEEPER=MASTER..'.StellarCoop_PauseTabKeeper'
local PUBLIC,ROOT_SET=0x1,0x40000000 -- As online/group/region_tabs.lua: RF_Public; EInternalObjectFlags::RootSet.
local HIT_TEST_INVISIBLE=3 -- ESlateVisibility.
local STYLE={'TextWidthValue','MinTextMargin','TextColor','TextFont','TextShadowColor'}
local LAYOUT,SLATE='/Script/UMG.Default__WidgetLayoutLibrary','/Script/UMG.Default__SlateBlueprintLibrary'

-- A class by its asset's path: the keep's (core/keep.lua) when it serves it, else loaded when it is not in memory.
local function class_of(asset)
    if Keep.serves(asset..'_C') then return assert(Keep.get(asset..'_C'),asset..' is not in memory') end
    local class=U.valid(StaticFindObject(asset..'_C'))
    if class then return class end
    pcall(LoadAsset,asset)
    return assert(U.valid(StaticFindObject(asset..'_C')),asset..' is not in this game build')
end

-- o: {log=function(line), ready=function() the game is far enough to load the menu's class, enabled=function() the
-- pause_tab setting, word=function() the tab's word in the menu's language, paused=function() the game is paused,
-- open=function() the co-op menu as menu_key opens it, notice=function() the give-up notice on screen,
-- ask=function(line) the native ask: ok, why, close=function() SB's close of the pause menu through the native part:
-- true, or false and why with lasting true when no later close can work}.
function Tab.new(o)
    local log=o.log
    local hooked,failed,stopped=false,false,false
    local master,button,closed_at=nil,nil,nil
    local asked,refused=nil,nil -- The last ask written (true: on); the last refusal logged.
    Keep.want({MASTER..'_C'})
    local function fail(e)
        failed=true
        log('STOP: '..tostring(e)..'; the pause menu keeps its 8 tabs until the mod reloads')
    end
    -- Ours after SB's buttons, unless it is already the last one. No half-made button stays.
    local function add()
        local tabs=assert(U.valid(master.WB_Tap_Set),'the pause menu has no WB_Tap_Set')
        tabs=assert(U.valid(tabs.WB_Common_Tabs),'WB_Tap_Set has no WB_Common_Tabs')
        local row=assert(U.valid(tabs.TabButtonContainer),'the tabs have no TabButtonContainer')
        local n=row:GetChildrenCount()
        assert(n>0,'the tab row is empty')
        local last=assert(U.valid(row:GetChildAt(n-1)),'the tab row has no last button')
        if button and U.address(last)==U.address(button) then return end
        local made=assert(U.valid(tabs:CreateDynamicChildUserWidget(tabs.TabButtonClass,row)),'no tab button')
        local ok,e=pcall(function()
            for _,k in ipairs(STYLE) do made[k]=last[k] end
            local word=o.word()
            made.TextValue=FText(word)
            assert(U.valid(made.TextBlock),'the tab button has no TextBlock'):SetText(FText(word))
            made:RefreshDesign()
            made:SetVisibility(HIT_TEST_INVISIBLE)
        end)
        if not ok then
            pcall(row.RemoveChild,row,made)
            error(e,0)
        end
        button=made
    end
    local function on_construct(ctx)
        if failed or stopped or not o.enabled() then return end
        local ok,e=pcall(function()
            master=assert(U.valid(ctx),'Construct gave no pause menu')
            add()
        end)
        if not ok then fail(e) end
    end
    local function install()
        local class=class_of(MASTER)
        if not U.valid(StaticFindObject(KEEPER)) then
            assert(U.valid(StaticConstructObject(class,class:GetOuter(),FName('StellarCoop_PauseTabKeeper',1),PUBLIC,
                ROOT_SET)),'no keeper')
        end
        RegisterHook(MASTER..'_C:Construct',on_construct)
        log('hook on: WB_GameMenu_Master_C:Construct')
    end
    -- The pause menu closed through SB's own close; the co-op menu opens from tick once the game runs again.
    local function close(now)
        local shown=U.valid(master)
        master=nil
        if not shown then return log('pause tab: the pause menu was gone; nothing closed') end
        local ok,why,lasting=o.close()
        if lasting then return fail(why) end
        if not ok then return log('pause tab: nothing closed: '..tostring(why)) end
        closed_at=now
    end
    local self={}
    -- Whether a left click may be ours: a pause menu got our button. No engine call: the key thread reads it.
    function self.armed() return master~=nil and button~=nil and not failed and not stopped and o.enabled() end
    -- Each frame: the hook once a Lua load, as soon as the game is far enough and the keep settled; then, after a
    -- close, the co-op menu once the game is unpaused, or the give-up after WAIT s.
    function self.tick(now)
        if not hooked and not stopped and o.ready() and (not Keep.wanted(MASTER..'_C') or Keep.ready()) then
            hooked=true
            local ok,e=pcall(install)
            if not ok then fail(e) end
        end
        if not closed_at then return end
        if not o.paused() then
            closed_at=nil
            return o.open()
        end
        if now-closed_at<Tab.WAIT then return end
        closed_at=nil
        log("pause tab: the game stayed paused for 2 s; the pause menu is the player's")
        o.notice()
    end
    -- Every 250 ms: the native part asked on or off whenever that changes (a refused ask again at the next pass, logged
    -- once), then ours back after SB's buttons if a rebuild dropped it while the game is paused.
    function self.slow()
        if stopped then return end
        local want=o.enabled() and not failed
        if want~=asked then
            local line=want and 'pausetab on' or 'pausetab off'
            local ok,why=o.ask(line)
            if ok then
                asked,refused=want,nil
            else
                local text='pause tab: '..line..' not asked: '..tostring(why)
                if text~=refused then refused=text; log(text) end
            end
        end
        if not (want and master and o.paused()) then return end
        local ok,e=pcall(function()
            master=U.valid(master)
            if master then add() end
        end)
        if not ok then fail(e) end
    end
    -- RB on Settings (coop_pad's event 12): the pause menu closed. With the tab on, no button made (no Construct seen
    -- yet) and no close waiting, one line each time: the native part took the press.
    function self.event(now)
        if self.armed() then return close(now) end
        if not (failed or stopped or closed_at) and o.enabled() then
            log('pause tab: RB on Settings with no Online tab shown; nothing opened')
        end
    end
    -- A left click while armed: the pause menu closed when the mouse is over our button.
    function self.click(now)
        if not self.armed() or not o.paused() then return end
        local ok,under=pcall(function()
            local at=StaticFindObject(LAYOUT):GetMousePositionOnPlatform()
            return StaticFindObject(SLATE):IsUnderLocation(button:GetCachedGeometry(),at)
        end)
        if not ok then return fail(under) end
        if under then close(now) end
    end
    -- coop off: no more buttons. The native part puts its slot back.
    function self.stop() stopped=true end
    return self
end
return Tab
