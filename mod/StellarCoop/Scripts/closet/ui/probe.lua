-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop closet probe <1-6|off>: the closet menu design's five in-game tests of Stellar Blade's own widget parts (the
-- piece grid, a grid slot alone, the tab buttons, the detail panel, focus and input) and test 6, the reads for the
-- camera and fit work (EVE's bones, the camera's FOV, mesh slot names, LODs, skin parameters), one at a time, each
-- check a "probe: PASS <n> <check>" or "probe: FAIL <n> <check>: <why>" line in UE4SS.log. Their results decide how the
-- closet menu builds its piece grid. Tests 1-5 touch only UI. Test 6 reads EVE and loads meshes. No test writes to EVE,
-- saves or the closet's look.
-- A test is a list of steps {frames=<frames to wait after the step before>, name=<check>, run=function(ctx)}. run
-- returns true (PASS), false and why (FAIL), 'skip' and why (SKIP: the test goes on) or 'wait' (run again next frame:
-- a check that watches the mouse or a map change). The first FAIL ends the test. Before each step every part the
-- test made must still be ours (kit.alive), unless a step set ctx.free_parts (a map change it waits for). A test
-- ends by itself after TIMEOUT s (or its own timeout), on coop closet probe off, a second run or coop off (stop).
-- While a step holds the kit's input, coop ui reset or the focus watchdog taking it back ends the test too. It runs
-- only in the game world (world()), never while another SBO screen holds the input. Its steps wait while the world
-- is hidden (a pause, a load, a game screen). Each end runs the test's cleanup, drops its parts, gives the kit's
-- input back and logs "probe: END <n> <passed>/<total>". The parts go in the kit group closet_probe (screen-sized,
-- added once a Lua load at the first run). Every step runs in pcall on the game thread (closet/wiring.lua runs tick
-- each frame through main/frame.lua's guard).
local U=require('core.unreal')
local text,each=U.text,U.each
local Probe={}
Probe.TIMEOUT=30 -- Seconds a test may run unless it sets its own.
Probe.WATCH=10 -- Seconds a check watches the mouse.
Probe.RELEASE_TRIES=600 -- Frames the probe tries again to give the input back (about 10 s).
Probe.USE='Use: coop closet probe <1-6|off>'
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
-- Text_ItemName), UpdateEquip(bool), UpdateLock(bool: purchased, true hides the lock). FocusSelf, PlaySpawnAnim and
-- ResetProgress read the list that owns the slot: never called on a slot alone.
local SLOT='/Game/Art/UI/Widget/HairSalon/WB_HairSalon_GridSlot.WB_HairSalon_GridSlot_C'
local SLOT_W,SLOT_H=198,262
-- The grid slot's own default icon (256x256): the test icon. Its size is read with UTexture2D's Blueprint_GetSizeX
-- (native entry 0x146684e30, exec 0x144964fb0) and Blueprint_GetSizeY (0x146684e40, exec 0x144964f80; Ghidra, build
-- 26123051, table of /Script/Engine Texture2D, FUN_1449650f0).
local ICON='/Game/Art/UI/Texture/Hair/HairIcon/Deco_Item_Hair_000.Deco_Item_Hair_000'
-- KismetSystemLibrary's default object: CollectGarbage() asks for a GC that runs at a later engine tick (Ghidra, build
-- 26123051: native entry 0x1465b5310, exec 0x14480ed30 sets the engine's +0xa64 to 1 and +0xa60 to the time plus 1 s,
-- the engine at DAT_1470e7eb8).
local KSL='/Script/Engine.Default__KismetSystemLibrary'
-- ESlateVisibility.
local VISIBLE,COLLAPSED,SELF_HIT_TEST_INVISIBLE=0,1,4
-- UListView's natives (Ghidra, build 26123051: table 0x1461e8710, registered with /Script/UMG ListView by
-- FUN_143d4bd20), native entry then exec: SetSelectionMode 0x1461e8870 (0x143d4b260), ClearListItems 0x1461e87d0
-- (0x143d4b3c0), AddItem 0x1461e8710 (0x143d4b710), BP_GetSelectedItem 0x1461e8750 (0x143d4a530), GetIndexForItem
-- 0x1461e87e0 (0x143d4b3e0), SetSelectedIndex 0x1461e8860 (0x143d4afc0), GetNumItems 0x1461e8810 (0x143d4b500), GetItemAt 0x1461e87f0 (0x143d4b520); the property SelectionMode is the byte at
-- 0x7fd (params 0x1461e7df8). UListViewBase's GetDisplayedEntryWidgets 0x1461eedf0 (exec 0x143d4cad0; table
-- 0x1461eede0, FUN_143d4cd50).
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
        ctx.data.tv,ctx.data.grid=tv,w
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
            ctx.take_input()
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
-- mouse. SetDotState and SetDotData are BlueprintEvents (not BlueprintCallable, as EventNotification): the probe
-- leaves them alone.
local TAB='/Game/Art/UI/Widget/GameMenu/Common/WB_Common_Tab_Btn.WB_Common_Tab_Btn_C'
local TABS=9
-- The workshop's NanoSuit detail panel: TitleText, DescriptionText, MaterialText1..5 (Text), ItemRarity
-- (ESBItemRarityType), bEquip, CraftState (ESBUINanoSuitCraftState Enable 0, Disable 1, Complete 2); only
-- EventNotification('Refresh') acts. Children Text_Name, Badge_Equip, WB_Common_HoldButton (GetCurrnetState, the
-- game's spelling: ESBUIHoldButtonStateType), VerticalBox_Material. GetCurrnetState is a native of /Script/SB
-- SBHoldButton (Ghidra, build 26123051: native entry 0x145e695a0, exec 0x142712220; table 0x145e69590,
-- FUN_142712510).
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
        ctx.take_input()
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

-- Test 5: focus and input with the game's parts in the kit, then a map change while the probe holds the input.
Probe.KEY_WATCH=8 -- Seconds the probe waits for Esc.
local function focus_line(w)
    local out={}
    for _,f in ipairs({'HasKeyboardFocus','HasAnyUserFocus','HasFocusedDescendants'}) do
        local ok,v=pcall(function() return w[f](w) end)
        out[#out+1]=f..' '..(ok and tostring(v) or '?')
    end
    return table.concat(out,', ')
end
Probe.TESTS['5']={timeout=90,steps={grid_steps[1],grid_steps[2],grid_steps[3],
    {frames=0,name='input',run=function(ctx)
        ctx.take_input()
        return ctx.kit.holding()==true,'holding '..tostring(ctx.kit.holding())
    end},
    {frames=0,name='focus',run=function(ctx)
        local d=ctx.data
        if not d.focus_wait then
            d.tv:SetKeyboardFocus()
            d.focus_wait=2
            return 'wait'
        end
        if d.focus_wait>0 then d.focus_wait=d.focus_wait-1; return 'wait' end
        local before=focus_line(d.grid)
        ctx.kit.refocus()
        return true,'grid: '..before..'; after the kit took it back: '..focus_line(d.grid)
    end},
    {frames=1,name='game_ignores_keys',run=function(ctx)
        local d=ctx.data
        if not d.keys then
            d.keys=ctx.now()+Probe.KEY_WATCH
            ctx.log('NOTE 5 game_ignores_keys: press Esc now ('..Probe.KEY_WATCH..' s)')
        end
        if ctx.kit.paused(true) then return false,'the game paused: it took the key' end
        if ctx.now()<d.keys then return 'wait' end
        return true
    end},
    -- The input goes back to the game first, so the player can open the map. A UI that hides and comes back with its
    -- parts was a pause or a game screen, not a map change: the step waits on. After a map change the parts are gone
    -- (the kit rebuilt its root) and the probe holds no input.
    {frames=0,name='map_change',run=function(ctx)
        local d,kit=ctx.data,ctx.kit
        if not d.phase then
            d.phase='before'
            ctx.free_parts=true
            ctx.give_input()
            ctx.log('NOTE 5 map_change: fast travel now (the game has its keys back)')
        end
        if d.phase=='before' then
            if kit.ready() then return 'wait' end
            d.phase='during'
            ctx.log('NOTE 5 map_change: the UI went')
            return 'wait'
        end
        if not kit.ready() then return 'wait' end
        if ctx.parts_alive()>0 then
            d.phase='before'
            ctx.log('NOTE 5 map_change: the UI came back with its parts, not a map change (a pause or a game screen); '
                ..'waiting for a fast travel')
            return 'wait'
        end
        d.tv=nil
        return not kit.holding(),'parts gone with the old root; input held after the change: '..tostring(kit.holding())
    end}},
    cleanup=function(ctx) if ctx.data.tv and live(ctx.data.tv) then ctx.data.tv:ClearListItems() end end}

-- Test 6: the reads the camera and fit work needs, each check a PASS line with its data (NOTE lines hold the long
-- lists): EVE's bones, the camera's FOV, the material slot names of the body-only and game suit meshes, the LODs of the
-- fit-mapped outfits and the skin slots' material parameters. It only reads: nothing of the game is written. A read
-- that raises logs "probe: SKIP 6 <check>: not verified: <why>" and the test goes on.
-- The game's parts, read in Ghidra (SB-Win64-Shipping.exe, build 26123051) on 26 Nov 2026:
--   ACharacter.Mesh: object property (SkeletalMeshComponent) at 0x328, params 0x14651b540 in Character's ClassParams
--     0x14651b720.
--   USkinnedMeshComponent natives GetNumBones (exec 0x14492a8d0) and GetBoneName(int) (exec 0x14492a680: the FName of
--     bone i of its SkeletalMesh, None out of range), native table 0x14665efd0; its SkeletalMesh: object property at
--     0x568, params 0x14665d7e0 in its ClassParams 0x14665e3f0.
--   UPrimitiveComponent native GetMaterial(int), native table 0x14662ad40 (entry 0x14662af60).
--   APlayerController.Player (object, UPlayer, at 0x340, params 0x1466164d0) and .PlayerCameraManager (object at
--     0x360, params 0x146616598), ClassParams 0x1466169a0.
--   ULocalPlayer.AspectRatioAxisConstraint: byte enum (EAspectRatioAxisConstraint) at 0x94, params 0x1465c49e8 in
--     LocalPlayer's ClassParams 0x1465c4a20.
--   APlayerCameraManager native GetFOVAngle, native table 0x14661c960 (exec 0x1448d35b0).
--   USkeletalMesh.Materials: TArray<FSkeletalMaterial> at 0xe0 (params 0x146650de0);
--     FSkeletalMaterial.MaterialSlotName: FName at 0x8 (params 0x146650eb8).
--   USkeletalMesh.LODInfo: TArray<FSkeletalMeshLODInfo> at 0x100 (params 0x146650908);
--     FSkeletalMeshLODInfo.LODMaterialMap: TArray<int32> at 0x8 (params 0x146651270). USkeletalMesh's ClassParams
--     0x14664fac0.
--   UMaterialInstance.TextureParameterValues: TArray<FTextureParameterValue> at 0x100 (params 0x1465da0b0) and
--     .VectorParameterValues: TArray<FVectorParameterValue> at 0xf0 (params 0x1465da110), ClassParams 0x1465da670.
--     Both structs' ParameterInfo: FMaterialParameterInfo at 0x0 (params 0x1465d9d50, 0x1465d9f88);
--     FMaterialParameterInfo.Name: FName at 0x0 (params 0x1465e0d48).
local Fits=require('closet.fits')
local PC,DLC='/Game/Art/Character/PC/','/Game/DLC_2/Art/Character/PC/'
-- The four body-only fits' meshes, as the packs' body table names them (research of 26 Nov 2026).
local BODIES={
    '/Game/CNSRepacked/f2e1960b2ec3c99d/Art/Character/PC/CH_P_EVE_09/CH_P_EVE_09.CH_P_EVE_09',
    '/Game/OutfitMods/FitBase/fitbase/SK_fitbase_v1.SK_fitbase_v1',
    '/Game/OutfitMods/MuseBody/muse_body/SK_muse_body_v1.SK_muse_body_v1',
    '/Game/OutfitMods/UnifiedProjectionSuit/Body/SK_UPS_Skin.SK_UPS_Skin',
}
-- The game suits' meshes: every CH_P_EVE_* mesh asset in the base paks' listing (pakchunk0) less the hair, face,
-- teeth, shadow, IK and cloth assets, as {folder, {asset names}}. A path that is no skeletal mesh logs its reason.
local SUITS={
    {PC..'CH_P_EVE_01',{'CH_P_EVE_01_Body','CH_P_EVE_01_TypeB','CH_P_EVE_01_Var01_Body'}},
    {PC..'CH_P_EVE_02',{'CH_P_EVE_02_Body','CH_P_EVE_02_TypeB'}},
    {PC..'CH_P_EVE_03',{'CH_P_EVE_03_Body'}},
    {PC..'CH_P_EVE_04',{'CH_P_EVE_04_Body','CH_P_EVE_04_TypeB'}},
    {PC..'CH_P_EVE_05',{'CH_P_EVE_05NH','CH_P_EVE_05_Body','CH_P_EVE_05_TypeB','CH_P_EVE_05_TypeBNH'}},
    {PC..'CH_P_EVE_06',{'CH_P_EVE_06NH','CH_P_EVE_06_Body','CH_P_EVE_06_TypeB','CH_P_EVE_06_TypeBNH'}},
    {PC..'CH_P_EVE_07',{'CH_P_EVE_07','CH_P_EVE_07_Type_B'}},
    {PC..'CH_P_EVE_08',{'CH_P_EVE_08','CH_P_EVE_08_TypeC','CH_P_EVE_08_Type_B_OrangeRed','CH_P_EVE_08_sample'}},
    {PC..'CH_P_EVE_09',{'CH_P_EVE_09','CH_P_EVE_09_Taper','CH_P_EVE_09_TypeB','CH_P_EVE_09_TypeC'}},
    {PC..'CH_P_EVE_09_V02',{'CH_P_EVE_09_V02','CH_P_EVE_09_V02_TypeB'}},
    {PC..'CH_P_EVE_10',{'CH_P_EVE_10'}},
    {PC..'CH_P_EVE_11',{'CH_P_EVE_11','CH_P_EVE_11_1','CH_P_EVE_11_SkirtTest'}},
    {PC..'CH_P_EVE_14',{'CH_P_EVE_14','CH_P_EVE_14_1','CH_P_EVE_14_1_TypeB','CH_P_EVE_14_TypeB'}},
    {PC..'CH_P_EVE_15',{'CH_P_EVE_15','CH_P_EVE_15_V02','CH_P_EVE_15_V02_TypeB'}},
    {PC..'CH_P_EVE_16',{'CH_P_EVE_16','CH_P_EVE_16_TypeB'}},
    {PC..'CH_P_EVE_17',{'CH_P_EVE_17','CH_P_EVE_17NH','CH_P_EVE_17NH_TypeB','CH_P_EVE_17_TypeB'}},
    {PC..'CH_P_EVE_18',{'CH_P_EVE_18','CH_P_EVE_18_TypeB'}},
    {PC..'CH_P_EVE_19',{'CH_P_EVE_19','CH_P_EVE_19_TypeB'}},
    {PC..'CH_P_EVE_20',{'CH_P_EVE_20','CH_P_EVE_20_TypeB','CH_P_EVE_20_TypeC'}},
    {PC..'CH_P_EVE_21',{'CH_P_EVE_21','CH_P_EVE_21_TypeB'}},
    {PC..'CH_P_EVE_22',{'CH_P_EVE_22'}},
    {PC..'CH_P_EVE_23',{'CH_P_EVE_23'}},
    {PC..'CH_P_EVE_24',{'CH_P_EVE_24','CH_P_EVE_24_TypeB'}},
    {PC..'CH_P_EVE_25',{'CH_P_EVE_25','CH_P_EVE_25_TypeB'}},
    {PC..'CH_P_EVE_26',{'CH_P_EVE_26','CH_P_EVE_26_TypeB'}},
    {PC..'CH_P_EVE_27',{'CH_P_EVE_27','CH_P_EVE_27_TypeB'}},
    {PC..'CH_P_EVE_28',{'CH_P_EVE_28','CH_P_EVE_28NH','CH_P_EVE_28NH_typeB','CH_P_EVE_28_typeB'}},
    {PC..'CH_P_EVE_29',{'CH_P_EVE_29','CH_P_EVE_29_TypeB','CH_P_EVE_29_TypeC'}},
    {PC..'CH_P_EVE_30',{'CH_P_EVE_30','CH_P_EVE_30_TypeB'}},
    {PC..'CH_P_EVE_31',{'CH_P_EVE_31','CH_P_EVE_31_TypeB'}},
    {PC..'CH_P_EVE_32',{'CH_P_EVE_32','CH_P_EVE_32_TypeB'}},
    {PC..'CH_P_EVE_33',{'CH_P_EVE_33_Body','CH_P_EVE_33_Body_02'}},
    {PC..'CH_P_EVE_34',{'CH_P_EVE_34_body','CH_P_EVE_34_body_02'}},
    {PC..'CH_P_EVE_35',{'CH_P_EVE_35','CH_P_EVE_35_TypeB'}},
    {PC..'CH_P_EVE_36',{'CH_P_EVE_36','CH_P_EVE_36_TypeB'}},
    {PC..'CH_P_EVE_37',{'CH_P_EVE_37','CH_P_EVE_37_TypeB'}},
    {PC..'CH_P_EVE_39',{'CH_P_EVE_39','CH_P_EVE_39_TypeB'}},
    {PC..'CH_P_EVE_40',{'CH_P_EVE_40','CH_P_EVE_40_TypeB','CH_P_EVE_40_TypeC'}},
    {PC..'CH_P_EVE_41',{'CH_P_EVE_41','CH_P_EVE_41NH','CH_P_EVE_41NH_TypeB','CH_P_EVE_41_TypeB'}},
    {PC..'CH_P_EVE_42',{'CH_P_EVE_42','CH_P_EVE_42_TypeB'}},
    {PC..'CH_P_EVE_43',{'CH_P_EVE_43','CH_P_EVE_43_TypeB'}},
    {PC..'CH_P_EVE_45',{'CH_P_EVE_45','CH_P_EVE_45_TypeB'}},
    {PC..'CH_P_EVE_46',{'CH_P_EVE_46','CH_P_EVE_46_TypeB'}},
    {PC..'CH_P_EVE_47',{'CH_P_EVE_47'}},
    {PC..'CH_P_EVE_48',{'CH_P_EVE_48'}},
    {PC..'CH_P_EVE_49',{'CH_P_EVE_49','CH_P_EVE_49_TypeB'}},
    {PC..'CH_P_EVE_50',{'CH_P_EVE_50','CH_P_EVE_50_TypeB'}},
    {PC..'CH_P_EVE_51',{'CH_P_EVE_51'}},
    {PC..'CH_P_EVE_52',{'CH_P_EVE_52','CH_P_EVE_52_TypeB'}},
    {PC..'CH_P_EVE_53',{'CH_P_EVE_53','CH_P_EVE_53_TypeB'}},
    {PC..'CH_P_EVE_54',{'CH_P_EVE_54'}},
    {PC..'CH_P_EVE_55',{'CH_P_EVE_55','CH_P_EVE_55_TypeB'}},
    {PC..'CH_P_EVE_56',{'CH_P_EVE_56'}},
    {PC..'CH_P_EVE_57',{'CH_P_EVE_57','CH_P_EVE_57_TypeB'}},
    {PC..'CH_P_EVE_58',{'CH_P_EVE_58'}},
    {PC..'CH_P_EVE_59',{'CH_P_EVE_59','CH_P_EVE_59_TypeB'}},
    {PC..'CH_P_EVE_60',{'CH_P_EVE_60','CH_P_EVE_60NH'}},
    {PC..'CH_P_EVE_61',{'CH_P_EVE_61'}},
    {PC..'CH_P_EVE_62',{'CH_P_EVE_62'}},
    {PC..'CH_P_EVE_63',{'CH_P_EVE_63'}},
    {PC..'CH_P_EVE_Bayonetta_01',{'CH_P_EVE_Bayonetta_01'}},
    {PC..'CH_P_EVE_Bayonetta_02',{'CH_P_EVE_Bayonetta_02'}},
    {PC..'CH_P_EVE_Bayonetta_03',{'CH_P_EVE_Bayonetta_03'}},
    {PC..'CH_P_EVE_Bayonetta_04',{'CH_P_EVE_Bayonetta_04'}},
    {PC..'CH_P_EVE_Christmas_01',{'CH_P_EVE_Christmas_01'}},
    {PC..'CH_P_EVE_DX',{'CH_P_EVE_DX','CH_P_EVE_DX_TypeB'}},
    {PC..'CH_P_EVE_Fusion',{'CH_P_EVE_Fusion','CH_P_EVE_Fusion_NoAcc'}},
    {PC..'CH_P_EVE_IberisCostume',{'CH_P_EVE_IberisCos'}},
    {PC..'CH_P_EVE_InnerSuit',{'CH_P_EVE_InnerSuit','CH_P_EVE_InnerSuit1'}},
    {PC..'CH_P_EVE_OneMillion_01',{'CH_P_EVE_OneMillion_01'}},
    {PC..'CH_P_EVE_RoyalGuard_01',{'CH_P_EVE_RoyalGuard_01'}},
    {DLC..'CH_P_EVE_Nikke_01',{'CH_P_EVE_Nikke_01'}},
}
-- The object paths the slots check reads, the body-only meshes first.
Probe.MESHES={table.unpack(BODIES)}
for _,s in ipairs(SUITS) do
    for _,n in ipairs(s[2]) do Probe.MESHES[#Probe.MESHES+1]=s[1]..'/'..n..'.'..n end
end
-- The bone parts the bones check finds by the first name that holds the word (case-insensitive); true: one per side.
local PARTS={{'head'},{'neck'},{'spine'},{'upperarm',true},{'hand',true},{'pelvis'},{'thigh',true},{'calf',true},
    {'foot',true}}
local BONE_LINE=40 -- Bone names per NOTE line.
local function path_of(o) return text(o:GetFullName()):match('^%S+ (.+)$') end
local function count(array) local n=0; each(array,function() n=n+1 end); return n end
-- The side of a lower-case bone name: a word l/left or r/right in it (upperarm_l, bip001 l upperarm), else nil.
local function side(name)
    for word in name:gmatch('%a+') do
        if word=='l' or word=='left' then return 'l' end
        if word=='r' or word=='right' then return 'r' end
    end
end
-- A check whose reads run in pcall: a raise is a SKIP with its reason, the test goes on.
local function soft(name,read)
    return {frames=0,name=name,run=function(ctx)
        local ok,result,why=pcall(read,ctx)
        if not ok then return 'skip','not verified: '..tostring(result) end
        return result,why
    end}
end
local function her_body(ctx) return assert(ctx.eve(),'no EVE').Mesh end -- ACharacter.Mesh
Probe.TESTS['6']={timeout=300,steps={
    soft('bones',function(ctx)
        local body=her_body(ctx)
        local n=body:GetNumBones()
        local all,at={},{}
        for i=0,n-1 do
            local name=text(body:GetBoneName(i))
            all[#all+1]=name
            local low=name:lower()
            for _,part in ipairs(PARTS) do
                local key=part[2] and side(low) and part[1]..'_'..side(low) or not part[2] and part[1]
                if key and at[key]==nil and low:find(part[1],1,true) then at[key]=i end
            end
        end
        for i=1,#all,BONE_LINE do
            local last=math.min(i+BONE_LINE-1,#all)
            ctx.log(string.format('NOTE 6 bones %d-%d: %s',i-1,last-1,table.concat(all,' ',i,last)))
        end
        local out={}
        for _,part in ipairs(PARTS) do
            for _,key in ipairs(part[2] and {part[1]..'_l',part[1]..'_r'} or {part[1]}) do
                out[#out+1]=key..'='..tostring(at[key] or '-')
            end
        end
        return true,n..' bones; '..table.concat(out,' ')
    end),
    soft('fov',function(ctx)
        local pc=assert(ctx.controller(),'no player controller')
        local axis=U.value_of(pc.Player.AspectRatioAxisConstraint)
        local fov=U.value_of(pc.PlayerCameraManager:GetFOVAngle())
        -- The kit's own read of the viewport (ui/kit/kit.lua); an older kit has none, so the camera reads still log.
        local v=ctx.kit.screen and ctx.kit.screen()
        return true,string.format('aspect ratio axis constraint %s, camera FOV %s, UI viewport %s',tostring(axis),
            tostring(fov),v and string.format('%.0fx%.0f units at DPI scale %.3g',v.w,v.h,v.s) or 'unread')
    end),
    -- One mesh a frame: each load is synchronous.
    soft('slots',function(ctx)
        local d=ctx.data
        d.slot=(d.slot or 0)+1
        local path=Probe.MESHES[d.slot]
        if not path then return true,#Probe.MESHES..' meshes, '..(d.missing or 0)..' not found' end
        local mesh=ctx.find(path)
        if not mesh then
            d.missing=(d.missing or 0)+1
            ctx.log('NOTE 6 slots: '..path..' not found')
            return 'wait'
        end
        local ok,why=pcall(function()
            local out={}
            each(mesh.Materials,function(i,slot) out[#out+1]=(i-1)..'='..text(slot.MaterialSlotName) end)
            return table.concat(out,' ')
        end)
        ctx.log('NOTE 6 slots: '..path..' '..(ok and why or ('unreadable: '..tostring(why))))
        return 'wait'
    end),
    soft('lods',function(ctx)
        local ids={}
        for id in pairs(Fits.BY_ID) do ids[#ids+1]=id end
        table.sort(ids)
        local out={}
        for _,id in ipairs(ids) do
            local fit=Fits.BY_ID[id]
            local mesh=ctx.find(fit.Mesh)
            local line=fit.Outfit..' '..fit.Mesh..' not found'
            if mesh then
                local n,maps=0,{}
                each(mesh.LODInfo,function(i,lod)
                    n=n+1
                    if i>1 then maps[#maps+1]='LOD'..(i-1)..' map '..count(lod.LODMaterialMap) end
                end)
                line=fit.Outfit..' '..fit.Mesh..' '..n..' LODs'..(#maps>0 and ', '..table.concat(maps,', ') or '')
            end
            out[#out+1]=line
        end
        return true,table.concat(out,'; ')
    end),
    soft('skin',function(ctx)
        local body=her_body(ctx)
        local mesh=path_of(body.SkeletalMesh)
        local id,fit
        for k,f in pairs(Fits.BY_ID) do if f.Mesh==mesh then id,fit=k,f end end
        if not fit then return true,'no closet fit on the body ('..tostring(mesh)..')' end
        local slots={}
        for i in pairs(fit.Skin) do slots[#slots+1]=i end
        table.sort(slots)
        local out={}
        for _,i in ipairs(slots) do
            local ok,why=pcall(function()
                local m=body:GetMaterial(i)
                local tex,vec={},{}
                each(m.TextureParameterValues,function(_,p) tex[#tex+1]=text(p.ParameterInfo.Name) end)
                each(m.VectorParameterValues,function(_,p) vec[#vec+1]=text(p.ParameterInfo.Name) end)
                return string.format('%s tex=%s vec=%s',text(m:GetFullName()),table.concat(tex,','),
                    table.concat(vec,','))
            end)
            out[#out+1]=i..' '..(ok and why or ('unreadable: '..tostring(why)))
        end
        return true,id..' '..table.concat(out,'; ')
    end)}}

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
    local world=o.world or function() return true end
    -- EVE (test 6 reads her body) and the player controller (her camera).
    local eve=o.eve or function() return U.her(U.valid(require('UEHelpers').GetPlayer())) end
    local controller=o.controller or U.controller
    local self={}
    local added=false
    local cur -- The running test: {n, test, i, wait, parts, passed, total, deadline, shown, held, ctx}
    -- Frames left to try the input's give-back again: the kit drops one made with no player controller (a load).
    local releasing=0
    local function release(kit)
        pcall(kit.input,false,Probe.GROUP)
        releasing=kit.holding() and Probe.RELEASE_TRIES or 0
    end

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
            pcall(kit.show,Probe.GROUP,false)
            if c.held then release(kit) else pcall(kit.input,false,Probe.GROUP) end
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
        if not world() then
            log('FAIL '..n..' world: not in the game world')
            return false,'closet probe: load a save first (not on the title screen)'
        end
        if kit.holding() then
            log('FAIL '..n..' kit: another screen holds the input')
            return false,'closet probe: close the open SBO screen first'
        end
        if not added then
            kit.add(Probe.GROUP,{x=0,y=0,w=3840,h=2160,fixed=true,hit=true},function() return {} end)
            added=true
        end
        local c={n=n,test=test,i=1,wait=test.steps[1].frames or 0,parts={},passed=0,total=#test.steps,
            deadline=clock()+(test.timeout or Probe.TIMEOUT),shown=false}
        c.ctx={log=log,find=find,construct=construct,data={},kit=kit,now=clock,eve=eve,controller=controller}
        -- A game widget made in the probe's group, kept for the end; it throws when the kit refuses.
        function c.ctx.make(class_path,x,y,w,h,fill,hit)
            local rec,why=kit.part(Probe.GROUP,class_path,x,y,w,h,fill,hit)
            if not rec then error(why,0) end
            c.parts[#c.parts+1]=rec
            return rec.o
        end
        -- How many of the parts are still ours (a map change frees them; a pause keeps them).
        function c.ctx.parts_alive()
            local n=0
            for _,rec in ipairs(c.parts) do if c.ctx.kit.alive(rec) then n=n+1 end end
            return n
        end
        -- The kit's input for the probe (the mouse shown) and back. A reset of it (coop ui reset, the focus watchdog)
        -- ends the test.
        function c.ctx.take_input() c.ctx.kit.input(true,Probe.GROUP,true); c.held=true end
        function c.ctx.give_input() c.held=false; release(c.ctx.kit) end
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
        local kit=o.kit()
        if releasing>0 and kit then
            releasing=releasing-1
            if kit.holding() then pcall(kit.input,false,Probe.GROUP) else releasing=0 end
        end
        if not cur then return end
        if clock()>cur.deadline then return fail('timeout','after '..(cur.test.timeout or Probe.TIMEOUT)..' s') end
        if not kit then return fail('kit','gone') end
        cur.ctx.kit=kit
        if cur.held and not kit.holding() then
            return fail('input','taken back (coop ui reset or the focus watchdog)')
        end
        -- While the world is hidden (a pause, a load, a game screen) the steps wait, unless one watches for that.
        if not cur.ctx.free_parts and not kit.ready() then return end
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
        if result=='skip' then
            log(string.format('SKIP %s %s: %s',cur.n,step.name,tostring(why)))
        else
            log(string.format('PASS %s %s%s',cur.n,step.name,why and (': '..tostring(why)) or ''))
            cur.passed=cur.passed+1
        end
        cur.i=cur.i+1
        local next_step=cur.test.steps[cur.i]
        if not next_step then return finish() end
        cur.wait=next_step.frames or 0
    end
    return self
end

return Probe
