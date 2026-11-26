-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop closet probe <1-5|off>: the closet menu design's five in-game tests of Stellar Blade's own widget parts (the
-- piece grid, a grid slot alone, the tab buttons, the detail panel, focus and input), one at a time, each check a
-- "probe: PASS <n> <check>" or "probe: FAIL <n> <check>: <why>" line in UE4SS.log. Their results decide how the closet
-- menu builds its piece grid. Only UI: EVE, saves and the closet's look are never touched.
-- A test is a list of steps {frames=<frames to wait after the step before>, name=<check>, run=function(ctx)}. run
-- returns true (PASS), false and why (FAIL), or 'wait' (run again next frame: a check that watches the mouse or a map
-- change). The first FAIL ends the test. Before each step every part the test made must still be ours (kit.alive),
-- unless a step set ctx.free_parts (a map change it waits for). A test ends by itself after TIMEOUT s (or its own
-- timeout), on coop closet probe off, a second run, coop off (stop) or coop ui reset (the kit gives the input back).
-- Each end runs the test's cleanup, drops its parts, gives the kit's input back and logs "probe: END <n> <passed>/
-- <total>". The parts go in the kit group closet_probe (screen-sized, added once a Lua load at the first run). Every
-- step runs in pcall on the game thread (closet/wiring.lua runs tick each frame through main/frame.lua's guard).
local U=require('core.unreal')
local text,each=U.text,U.each
local Probe={}
Probe.TIMEOUT=30 -- Seconds a test may run unless it sets its own.
Probe.WATCH=10 -- Seconds a check watches the mouse.
Probe.USE='Use: coop closet probe <1-5|off>'
Probe.GROUP='closet_probe'
Probe.TESTS={}
-- The game's parts and assets, read in the widget JSON and Ghidra (build 26123051) on 25 Nov 2026.
-- The hair salon's tile data object (super /Script/SB.SBUITileViewBaseDataObject): ItemName Text, IconAssetPath Str
-- (a full object path the slot loads), Purchased bool, ItemAlias Name, Equiped bool (the game's spelling), Index int
-- (never -1: the slot fills itself only when Index differs from its own, -1 at first), RedDotState byte.
local DATA='/Game/Art/UI/Data/HairSalon/BP_HairSalonItemData_Tile.BP_HairSalonItemData_Tile_C'
-- The hair salon's grid list: child TileView_ItemList, a /Script/UMG.TileView of WB_HairSalon_GridSlot (198x262).
local GRID='/Game/Art/UI/Widget/HairSalon/WB_HairSalonGridList.WB_HairSalonGridList_C'
-- One grid slot: Image_Icon, Text_ItemName, Image_Focus, badge_equip; BP 'Set Focus', 'Set Nomal' (each collapses
-- Text_ItemName), UpdateEquip(bool), UpdateLock(bool). FocusSelf, PlaySpawnAnim and ResetProgress read the list that
-- owns the slot: never called on a slot alone.
local SLOT='/Game/Art/UI/Widget/HairSalon/WB_HairSalon_GridSlot.WB_HairSalon_GridSlot_C'
local SLOT_W,SLOT_H=198,262
-- The grid slot's own default icon (256x256): the test icon.
local ICON='/Game/Art/UI/Texture/Hair/HairIcon/Deco_Item_Hair_000.Deco_Item_Hair_000'
-- KismetSystemLibrary's default object: CollectGarbage() asks for a GC that runs at a later engine tick.
local KSL='/Script/Engine.Default__KismetSystemLibrary'
-- ESlateVisibility.
local VISIBLE,COLLAPSED,SELF_HIT_TEST_INVISIBLE=0,1,4
local SINGLE=1 -- ESelectionMode Single (None is 0).
local ITEMS=8

local function live(o)
    local ok,valid=pcall(function() return o:IsValid() end)
    return ok and valid and o or nil
end
local function name_of(o) local ok,n=pcall(function() return text(o:GetFullName()) end); return ok and n or '?' end

-- Test 1: the piece grid as the game fills it: data objects in the hair salon's TileView. Its steps 1-3 are also
-- test 5's.
local grid_steps={
    {frames=0,name='classes',run=function(ctx)
        local missing={}
        for _,p in ipairs({DATA,GRID}) do if not ctx.find(p) then missing[#missing+1]=p end end
        if #missing>0 then return false,'not found: '..table.concat(missing,' ') end
        return true
    end},
    {frames=0,name='grid',run=function(ctx)
        local w=ctx.make(GRID,200,300,1600,1100,nil,true)
        local tv=live(w.TileView_ItemList)
        if not tv then return false,'no TileView_ItemList' end
        ctx.data.tv=tv
        local ran,e=pcall(function() w['Set Goods'](w) end)
        tv:SetVisibility(VISIBLE)
        return true,'Set Goods '..(ran and 'ran' or ('refused: '..tostring(e)))
    end},
    {frames=0,name='items',run=function(ctx)
        local tv=ctx.data.tv
        local mode=tv.SelectionMode
        if mode==0 then tv:SetSelectionMode(SINGLE) end
        tv:ClearListItems()
        local class=ctx.find(DATA)
        for i=1,ITEMS do
            local item=ctx.construct(class,tv)
            if not item then return false,'StaticConstructObject gave nothing for item '..i end
            item.ItemName=FText(tostring(i))
            item.IconAssetPath=ICON
            item.ItemAlias=FName('probe'..i)
            item.Purchased=true
            item.Equiped=(i==1)
            item.RedDotState=0
            item.Index=i-1
            tv:AddItem(item)
        end
        local n=tv:GetNumItems()
        return n==ITEMS,'items '..tostring(n)..', selection mode was '..tostring(mode)
    end},
}
Probe.TESTS['1']={steps={grid_steps[1],grid_steps[2],grid_steps[3],
    {frames=3,name='tiles',run=function(ctx)
        local tv=ctx.data.tv
        local names,shown,right={},0,0
        for i=1,ITEMS do names[tostring(i)]=true end
        each(tv:GetDisplayedEntryWidgets(),function(_,entry)
            shown=shown+1
            if names[text(entry.Text_ItemName:GetText())] then right=right+1 end
        end)
        tv:SetSelectedIndex(2)
        return shown>0 and right==shown,shown..' tiles shown, '..right..' with an item name'
    end},
    {frames=1,name='select',run=function(ctx)
        local tv=ctx.data.tv
        local sel=tv:BP_GetSelectedItem()
        local at=sel and tv:GetIndexForItem(sel)
        return at==2 and name_of(sel)==name_of(tv:GetItemAt(2)),'selected index '..tostring(at)
    end},
    {frames=0,name='gc',run=function(ctx)
        local ksl=ctx.find(KSL)
        if not ksl then return false,KSL..' not found' end
        ksl:CollectGarbage()
        return true
    end},
    {frames=5,name='gc_survived',run=function(ctx)
        local tv=ctx.data.tv
        local n=tv:GetNumItems()
        if n~=ITEMS then return false,'items '..tostring(n)..' after the GC' end
        for i=0,ITEMS-1 do if not live(tv:GetItemAt(i)) then return false,'item '..i..' freed' end end
        return true
    end},
    {frames=1,name='mouse',run=function(ctx)
        local d=ctx.data
        if not d.watch then
            ctx.kit.input(true,Probe.GROUP,true)
            d.watch=ctx.now()+Probe.WATCH
            ctx.log('NOTE 1 mouse: click tiles for '..Probe.WATCH..' s')
        end
        local sel=d.tv:BP_GetSelectedItem()
        local at=sel and d.tv:GetIndexForItem(sel)
        if at~=d.last then d.last=at; ctx.log('NOTE 1 mouse: selected '..tostring(at)) end
        if ctx.now()<d.watch then return 'wait' end
        return true,'watched '..Probe.WATCH..' s'
    end}},
    cleanup=function(ctx) if ctx.data.tv and live(ctx.data.tv) then ctx.data.tv:ClearListItems() end end}

-- Test 2: one grid slot alone, set by hand (the fallback when test 1 fails).
Probe.TESTS['2']={steps={
    {frames=0,name='class',run=function(ctx) return ctx.find(SLOT)~=nil,SLOT end},
    {frames=0,name='slot',run=function(ctx) ctx.data.slot=ctx.make(SLOT,400,400,SLOT_W,SLOT_H); return true end},
    {frames=1,name='icon',run=function(ctx)
        local tex=ctx.find(ICON)
        if not tex then return false,ICON..' not found' end
        local slot=ctx.data.slot
        slot.Image_Icon:SetBrushFromTexture(tex,false)
        local size=tostring(tex:Blueprint_GetSizeX())..'x'..tostring(tex:Blueprint_GetSizeY())
        local got=slot.Image_Icon.Brush.ResourceObject
        return got~=nil and name_of(got)==name_of(tex),'texture '..size
    end},
    {frames=0,name='name',run=function(ctx)
        local t=ctx.data.slot.Text_ItemName
        t:SetText(FText('1'))
        local got=text(t:GetText())
        return got=='1','read '..tostring(got)
    end},
    {frames=0,name='spaced_names',run=function(ctx)
        local slot=ctx.data.slot
        local ran,e=pcall(function() slot['Set Focus'](slot) end)
        if not ran then return false,"slot['Set Focus'](slot): "..tostring(e) end
        local focus=slot.Image_Focus:GetVisibility()
        slot.Text_ItemName:SetVisibility(SELF_HIT_TEST_INVISIBLE)
        ran,e=pcall(function() slot['Set Nomal'](slot) end)
        if not ran then return false,"slot['Set Nomal'](slot): "..tostring(e) end
        local normal=slot.Image_Focus:GetVisibility()
        slot.Text_ItemName:SetVisibility(SELF_HIT_TEST_INVISIBLE)
        return focus==SELF_HIT_TEST_INVISIBLE and normal==COLLAPSED,
            "slot['Set Focus'](slot) form; focus glow "..tostring(focus)..' then '..tostring(normal)
    end},
    {frames=0,name='equip_lock',run=function(ctx)
        local slot=ctx.data.slot
        slot:UpdateEquip(true)
        slot:UpdateLock(true)
        local on=slot.badge_equip:GetVisibility()
        slot:UpdateEquip(false)
        slot:UpdateLock(false)
        local off=slot.badge_equip:GetVisibility()
        return true,'equipped badge '..tostring(on)..' then '..tostring(off)
    end}}}

-- The pause menu's tab button (super /Script/SB.SBCommonTabButtonWidget): TextValue Text, then the native
-- RefreshDesign() puts it in TextBlock; FocusTabButton() and DefocusTabButton() set bFocused; Button_Action takes the
-- mouse. SetDotState and SetDotData are BlueprintEvents a caller cannot call.
local TAB='/Game/Art/UI/Widget/GameMenu/Common/WB_Common_Tab_Btn.WB_Common_Tab_Btn_C'
local TABS=9
-- The workshop's NanoSuit detail panel: TitleText, DescriptionText, MaterialText1..5 (Text), ItemRarity
-- (ESBItemRarityType), bEquip, CraftState (ESBUINanoSuitCraftState Enable 0, Disable 1, Complete 2); only
-- EventNotification('Refresh') acts. Children Text_Name, Badge_Equip, WB_Common_HoldButton (GetCurrnetState, the
-- game's spelling: ESBUIHoldButtonStateType), VerticalBox_Material.
local DETAIL='/Game/Art/UI/Widget/GameMenu/WorkShop/WB_NanoSuit_Detail.WB_NanoSuit_Detail_C'
local RARE=3 -- ESBItemRarityType Rare.
-- What the widget JSON says Refresh shows per CraftState: the hold button's state (Ready 3, Lock 5) and the material
-- list's visibility. A mismatch is a finding about the panel, logged with the values read.
local CRAFT_HOLD,CRAFT_MATERIALS={[0]=3,5,5},{[0]=VISIBLE,VISIBLE,2}

-- Test 3: a row of the game's tab buttons, labelled, the focus walked along them, the mouse watched.
local tab_steps={
    {frames=0,name='class',run=function(ctx) return ctx.find(TAB)~=nil,TAB end},
    {frames=0,name='tabs',run=function(ctx)
        ctx.data.tabs={}
        local wrong={}
        for i=1,TABS do
            local tab=ctx.make(TAB,200+(i-1)*360,120,nil,nil,nil,true)
            tab.TextValue=FText(tostring(i))
            tab:RefreshDesign()
            ctx.data.tabs[i]=tab
            local got=tab.TextBlock and tab.TextBlock:GetText()
            if not got or text(got)~=tostring(i) then wrong[#wrong+1]=i..'='..tostring(got and text(got)) end
        end
        return #wrong==0,#wrong==0 and (TABS..' labels set') or ('labels: '..table.concat(wrong,' '))
    end},
}
for k=1,TABS do
    tab_steps[#tab_steps+1]={frames=10,name='focus'..k,run=function(ctx)
        local tabs=ctx.data.tabs
        for i,tab in ipairs(tabs) do
            if i==k then tab:FocusTabButton() else tab:DefocusTabButton() end
        end
        local focused={}
        for i,tab in ipairs(tabs) do if tab.bFocused then focused[#focused+1]=i end end
        return #focused==1 and focused[1]==k,'focused '..table.concat(focused,',')
    end}
end
tab_steps[#tab_steps+1]={frames=1,name='hover',run=function(ctx)
    local d=ctx.data
    if not d.watch then
        ctx.kit.input(true,Probe.GROUP,true)
        d.watch=ctx.now()+Probe.WATCH
        ctx.log('NOTE 3 hover: move the mouse over the tabs for '..Probe.WATCH..' s')
    end
    local over
    for i,tab in ipairs(d.tabs) do
        local ok,hovered=pcall(function() return tab.Button_Action:IsHovered() end)
        if ok and hovered then over=i end
    end
    if over~=d.over then d.over=over; ctx.log('NOTE 3 hover: '..tostring(over)) end
    if ctx.now()<d.watch then return 'wait' end
    return true,'watched '..Probe.WATCH..' s'
end}
Probe.TESTS['3']={steps=tab_steps}

-- Test 4: the detail panel in its three craft states.
local detail_steps={
    {frames=0,name='class',run=function(ctx) return ctx.find(DETAIL)~=nil,DETAIL end},
    {frames=0,name='detail',run=function(ctx) ctx.data.detail=ctx.make(DETAIL,2200,300); return true end},
    {frames=0,name='fill',run=function(ctx)
        local d=ctx.data.detail
        d.TitleText=FText('1')
        d.DescriptionText=FText('2')
        d.ItemRarity=RARE
        d.bEquip=true
        d.MaterialText1=FText('3')
        for i=2,5 do d['MaterialText'..i]=FText('') end
        return true
    end},
}
for c=0,2 do
    detail_steps[#detail_steps+1]={frames=0,name='craft'..c,run=function(ctx)
        ctx.data.detail.CraftState=c
        ctx.data.detail:EventNotification('Refresh')
        return true
    end}
    detail_steps[#detail_steps+1]={frames=2,name='craft'..c..'_read',run=function(ctx)
        local d=ctx.data.detail
        local title=text(d.Text_Name:GetText())
        local badge=d.Badge_Equip:GetVisibility()
        local hold=d.WB_Common_HoldButton:GetCurrnetState()
        local materials=d.VerticalBox_Material:GetVisibility()
        local read=string.format('name %s badge %s hold %s materials %s',tostring(title),tostring(badge),
            tostring(hold),tostring(materials))
        return title=='1' and badge==SELF_HIT_TEST_INVISIBLE and hold==CRAFT_HOLD[c] and materials==CRAFT_MATERIALS[c],
            read
    end}
end
detail_steps[#detail_steps+1]={frames=0,name='other_event',run=function(ctx)
    local d=ctx.data.detail
    d:EventNotification('Other')
    local title=text(d.Text_Name:GetText())
    return title=='1','name '..tostring(title)
end}
Probe.TESTS['4']={steps=detail_steps}
-- A game object by path: in memory, else after a synchronous LoadAsset (a class path loads its asset path without
-- _C), as ui/kit/kit.lua's load does.
local function default_find(path)
    local o=StaticFindObject(path)
    if o and o:IsValid() then return o end
    pcall(LoadAsset,path:match('^(.*)_C$') or path)
    o=StaticFindObject(path)
    return o and o:IsValid() and o or nil
end

function Probe.new(o)
    local log=function(m) o.log('probe: '..m) end
    local clock=o.clock or os.clock
    local tests=o.tests or Probe.TESTS
    local find=o.find or default_find
    local construct=o.construct or function(class,outer) return StaticConstructObject(class,outer) end
    local self={}
    local added=false
    local cur -- The running test: {n, test, i, wait, parts, passed, total, deadline, shown, ctx}

    local function finish()
        local c=cur
        if not c then return end
        cur=nil
        if c.test.cleanup then
            local ok,e=pcall(c.test.cleanup,c.ctx)
            if not ok then log('cleanup '..c.n..': '..tostring(e)) end
        end
        local kit=o.kit()
        if kit then
            for _,rec in ipairs(c.parts) do pcall(kit.drop,rec) end
            pcall(kit.input,false,Probe.GROUP)
        end
        log(string.format('END %s %d/%d',c.n,c.passed,c.total))
    end
    local function fail(name,why)
        log(string.format('FAIL %s %s: %s',cur.n,name,tostring(why)))
        finish()
    end

    -- coop closet probe <n>: starts test n (ending one that runs).
    function self.run(n)
        local test=tests[n]
        if not test then return false,Probe.USE end
        finish()
        local kit=o.kit()
        if not (kit and kit.ready() and not kit.off()) then
            log('FAIL '..n..' kit: the UI is not up')
            return false,'closet probe: the UI is not up (it needs the Steam link and the game world)'
        end
        if not added then
            kit.add(Probe.GROUP,{x=0,y=0,w=3840,h=2160,fixed=true,hit=true},function() return {} end)
            added=true
        end
        local c={n=n,test=test,i=1,wait=test.steps[1].frames or 0,parts={},passed=0,total=#test.steps,
            deadline=clock()+(test.timeout or Probe.TIMEOUT),shown=false}
        c.ctx={log=log,find=find,construct=construct,data={},kit=kit,now=clock}
        -- A game widget made in the probe's group, kept for the end; it throws when the kit refuses.
        function c.ctx.make(class_path,x,y,w,h,fill,hit)
            local rec,why=kit.part(Probe.GROUP,class_path,x,y,w,h,fill,hit)
            if not rec then error(why,0) end
            c.parts[#c.parts+1]=rec
            return rec.o
        end
        -- Forgets the parts (a map change freed them).
        function c.ctx.forget() c.parts={} end
        cur=c
        log('START '..n..' ('..c.total..' checks)')
        return true,'closet probe '..n..': running, its lines go to UE4SS.log'
    end
    function self.off()
        if not cur then return true,'probe: nothing running' end
        finish()
        return true,'probe: off'
    end
    -- coop off.
    function self.stop() finish() end
    function self.running() return cur and cur.n or nil end
    -- Each frame, on the game thread.
    function self.tick()
        if not cur then return end
        local kit=o.kit()
        if clock()>cur.deadline then return fail('timeout','after '..(cur.test.timeout or Probe.TIMEOUT)..' s') end
        if not kit then return fail('kit','gone') end
        cur.ctx.kit=kit
        if not cur.shown then
            if not kit.view(Probe.GROUP) then return end
            kit.show(Probe.GROUP,true)
            cur.shown=true
        end
        if cur.wait>0 then cur.wait=cur.wait-1; return end
        if not cur.ctx.free_parts then
            for _,rec in ipairs(cur.parts) do
                if not kit.alive(rec) then return fail('parts','gone') end
            end
        end
        local step=cur.test.steps[cur.i]
        local ran,result,why=pcall(step.run,cur.ctx)
        if not ran then return fail(step.name,result) end
        if result=='wait' then return end
        if not result then return fail(step.name,why or 'no') end
        log(string.format('PASS %s %s%s',cur.n,step.name,why and (': '..tostring(why)) or ''))
        cur.passed=cur.passed+1
        cur.i=cur.i+1
        local next_step=cur.test.steps[cur.i]
        if not next_step then return finish() end
        cur.wait=next_step.frames or 0
    end
    return self
end

return Probe
