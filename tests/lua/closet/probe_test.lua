-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop closet probe (closet/ui/probe.lua) over a fake kit and fake widgets: the runner (steps frames apart, PASS and
-- FAIL lines, the first FAIL ends a test, parts that die, calls that throw, the timeout, off, a second run, coop off,
-- the group added once, input always given back), its console words, and the five tests of the game's parts.
local run = dofile('tests/lua/closet/run.lua')
package.loaded.UEHelpers = {GetPlayer = function() return nil end}
FText = function(s) return {text = s, ToString = function(self) return self.text end} end
FName = function(s) return s end

local function fake_kit()
    local k = {up = true, added = {}, shown = {}, made = {}, dropped = 0, held = nil, inputs = {}, views = {},
        widgets = {}, paused_now = false, refocused = 0}
    function k.ready() return k.up end
    function k.off() return false end
    function k.add(name) k.added[#k.added + 1] = name; k.views[name] = {} end
    function k.view(name) return k.up and k.views[name] or nil end
    function k.show(name, on) k.shown[name] = on end
    function k.part(group, class_path, x, y, w, h, fill, hit)
        if not k.up or not k.views[group] then return nil, 'part: the UI is not up' end
        local make = k.widgets[class_path]
        if not make then return nil, 'part: not in this game build' end
        local widget = make()
        if fill then fill(widget) end
        local rec = {o = widget, live = true, class = class_path, x = x, y = y, hit = hit}
        k.made[#k.made + 1] = rec
        return rec
    end
    -- As the real kit: a part stays ours while the root is only hidden (a pause); a rebuild (live=false) ends it.
    function k.alive(rec) return rec and rec.live and rec.o or nil end
    function k.drop(rec) if rec.live then rec.live = false; k.dropped = k.dropped + 1 end end
    function k.input(on, who)
        k.inputs[#k.inputs + 1] = {on, who}
        if not on and k.ignore_release and k.ignore_release > 0 then -- no player controller yet: input_mode returns
            k.ignore_release = k.ignore_release - 1
            return
        end
        if on then k.held = who elseif k.held == who then k.held = nil end
    end
    function k.holding() return k.held ~= nil end
    function k.refocus() k.refocused = k.refocused + 1 end
    function k.paused() return k.paused_now end
    function k.screen() return {w = 3840, h = 2160, s = 1.5} end
    return k
end

local function rig(tests, kit)
    local r = {log = {}, now = 10, kit = kit or fake_kit(), found = {}, made = {}, world = true}
    package.loaded['closet.ui.probe'] = nil
    local Probe = require('closet.ui.probe')
    r.Probe = Probe
    r.p = Probe.new({kit = function() return r.kit end, log = function(m) r.log[#r.log + 1] = m end,
        clock = function() return r.now end, tests = tests, find = function(path) return r.found[path] end,
        world = function() return r.world end,
        eve = function() return r.eve end, controller = function() return r.pc end,
        construct = function(class, outer)
            local item = {class = class, outer = outer, IsValid = function(self) return not self.lost end}
            r.made[#r.made + 1] = item
            return item
        end})
    r.ticks = function(n) for _ = 1, n or 1 do r.p.tick() end end
    return r
end

-- The game's side for tests 1 and 2: the classes, the test icon, the grid list with its TileView, a grid slot.
local DATA = '/Game/Art/UI/Data/HairSalon/BP_HairSalonItemData_Tile.BP_HairSalonItemData_Tile_C'
local GRID = '/Game/Art/UI/Widget/HairSalon/WB_HairSalonGridList.WB_HairSalonGridList_C'
local SLOT = '/Game/Art/UI/Widget/HairSalon/WB_HairSalon_GridSlot.WB_HairSalon_GridSlot_C'
local ICON = '/Game/Art/UI/Texture/Hair/HairIcon/Deco_Item_Hair_000.Deco_Item_Hair_000'
local KSL = '/Script/Engine.Default__KismetSystemLibrary'
local function uobj(name, fields)
    local o = fields or {}
    o.name = name
    function o:IsValid() return true end
    function o:GetFullName() return 'Object ' .. self.name end
    return o
end
local function vis(v) return {v = v, SetVisibility = function(self, x) self.v = x end,
    GetVisibility = function(self) return self.v end} end
local function game(r, opts)
    opts = opts or {}
    r.found[DATA] = uobj(DATA)
    r.found[GRID] = uobj(GRID)
    r.found[SLOT] = uobj(SLOT)
    r.found[ICON] = uobj(ICON, {Blueprint_GetSizeX = function() return 256 end,
        Blueprint_GetSizeY = function() return 256 end})
    local tv = uobj('TileView_ItemList', {items = {}, SelectionMode = 0, cleared = 0})
    function tv:SetVisibility(v) self.v = v end
    function tv:SetSelectionMode(m) self.SelectionMode = m end
    function tv:ClearListItems() self.items = {}; self.cleared = self.cleared + 1 end
    function tv:AddItem(item) self.items[#self.items + 1] = item end
    function tv:GetNumItems() return #self.items end
    function tv:GetItemAt(i) return self.items[i + 1] end
    function tv:GetIndexForItem(item)
        for k, v in ipairs(self.items) do if v == item then return k - 1 end end
        return -1
    end
    function tv:SetSelectedIndex(i) self.sel = self.items[i + 1] end
    function tv:BP_GetSelectedItem() return self.sel end
    function tv:GetDisplayedEntryWidgets()
        local out = {}
        for k, item in ipairs(self.items) do
            out[k] = {Text_ItemName = {GetText = function() return item.ItemName end}}
        end
        return out
    end
    r.tv = tv
    r.found[KSL] = uobj(KSL, {CollectGarbage = function()
        r.gc = true
        if opts.gc_loses then tv.items = {} end
    end})
    r.kit.widgets[GRID] = function()
        return {TileView_ItemList = tv, ['Set Goods'] = function(self) self.goods = true end}
    end
    r.kit.widgets[SLOT] = function()
        local s = {Image_Icon = {Brush = {}}, Text_ItemName = vis(4), Image_Focus = vis(1), badge_equip = vis(1)}
        function s.Image_Icon:SetBrushFromTexture(t) self.Brush.ResourceObject = t end
        function s.Text_ItemName:SetText(t) self.t = t end
        function s.Text_ItemName:GetText() return self.t end
        if not opts.no_spaced then
            s['Set Focus'] = function(self) self.Image_Focus.v = 4; self.Text_ItemName.v = 1 end
            s['Set Nomal'] = function(self) self.Image_Focus.v = 1; self.Text_ItemName.v = 1 end
        end
        function s:UpdateEquip(on) self.badge_equip.v = on and 4 or 1 end
        function s:UpdateLock() end
        r.slot = s
        return s
    end
end
-- The game's side for tests 3 and 4: the tab button and the NanoSuit detail panel.
local TAB = '/Game/Art/UI/Widget/GameMenu/Common/WB_Common_Tab_Btn.WB_Common_Tab_Btn_C'
local DETAIL = '/Game/Art/UI/Widget/GameMenu/WorkShop/WB_NanoSuit_Detail.WB_NanoSuit_Detail_C'
local function panels(r, opts)
    opts = opts or {}
    r.found[TAB] = uobj(TAB)
    r.found[DETAIL] = uobj(DETAIL)
    r.tabs = {}
    r.kit.widgets[TAB] = function()
        local t = {TextBlock = {GetText = function(self) return self.t end}, bFocused = false,
            Button_Action = {IsHovered = function() return false end}}
        function t:RefreshDesign() if not opts.no_label then self.TextBlock.t = self.TextValue end end
        function t:FocusTabButton() self.bFocused = true end
        function t:DefocusTabButton() self.bFocused = false end
        r.tabs[#r.tabs + 1] = t
        return t
    end
    r.kit.widgets[DETAIL] = function()
        local d = {Text_Name = {GetText = function(self) return self.t end}, Badge_Equip = vis(1),
            VerticalBox_Material = vis(0), WB_Common_HoldButton = {s = 0}}
        function d.WB_Common_HoldButton:GetCurrnetState() return self.s end
        function d:EventNotification(e)
            if e ~= 'Refresh' then return end
            self.Text_Name.t = self.TitleText
            self.Badge_Equip.v = self.bEquip and 4 or 1
            self.WB_Common_HoldButton.s = opts.hold or ({3, 5, 5})[self.CraftState + 1]
            self.VerticalBox_Material.v = ({0, 0, 2})[self.CraftState + 1]
        end
        r.detail = d
        return d
    end
end
-- The game's side for test 6: EVE with three named bones in Ocean Maid's mesh, the player's camera, every mesh path
-- loading as a mesh with two slots and two LODs, a skin material with one texture parameter.
local OCEAN_MAID = '/Game/OutfitMods/AiK_CH27/CH27_NRS.CH27_NRS'
local function reads(r)
    local bones = {'pelvis', 'Head', 'upperarm_l'}
    local skin = uobj('MI_Skin', {TextureParameterValues = {{ParameterInfo = {Name = 'Body_A'}}},
        VectorParameterValues = {}})
    local body = {SkeletalMesh = uobj(OCEAN_MAID)}
    function body:GetNumBones() return #bones end
    function body:GetBoneName(i) return bones[i + 1] end
    function body:GetMaterial(i) return i == 14 and skin or nil end
    r.eve = {Mesh = body}
    r.pc = {Player = {AspectRatioAxisConstraint = 1},
        PlayerCameraManager = {GetFOVAngle = function() return 70 end}}
    setmetatable(r.found, {__index = function(_, path)
        return uobj(path, {Materials = {{MaterialSlotName = 'Body'}, {MaterialSlotName = 'Skin'}},
            LODInfo = {{LODMaterialMap = {}}, {LODMaterialMap = {0, 1}}}})
    end})
end
-- Runs a test to its end: frames, then the clock past any watch window.
local function play(r, n)
    r.p.run(n)
    for _ = 1, 2 do
        for _ = 1, 150 do r.p.tick() end
        r.now = r.now + 11
    end
    for _ = 1, 50 do r.p.tick() end
end
local function has(r, needle)
    for _, line in ipairs(r.log) do if line:find(needle, 1, true) then return true end end
    return false
end
local function count(r, needle)
    local n = 0
    for _, line in ipairs(r.log) do if line:find(needle, 1, true) then n = n + 1 end end
    return n
end
local function released(r)
    local last = r.kit.inputs[#r.kit.inputs]
    return last ~= nil and last[1] == false and last[2] == 'closet_probe' and not r.kit.holding()
end
local PASS = function() return true end
local WIDGET = '/Game/Probe/WB_Fake.WB_Fake_C'

local tests = {
    refuses_when_the_kit_is_not_up = function()
        local r = rig({['1'] = {steps = {{frames = 0, name = 'a', run = PASS}}}})
        r.kit = nil
        local ok_, line = r.p.run('1')
        eq(ok_, false) ok(line:find('not up'), line)
        r.kit = fake_kit()
        r.kit.up = false
        eq((r.p.run('1')), false)
        eq(#r.log, 2) eq(r.log[1], 'probe: FAIL 1 kit: the UI is not up') eq(#r.kit.made, 0)
    end,
    runs_steps_frames_apart_and_logs = function()
        local ran = {}
        local r = rig({['1'] = {steps = {
            {frames = 0, name = 'a', run = function(ctx) ctx.make(WIDGET, 0, 0); ran[#ran + 1] = 'a'; return true end},
            {frames = 2, name = 'b', run = function() ran[#ran + 1] = 'b'; return true end}}}})
        r.kit.widgets[WIDGET] = function() return {} end
        ok((r.p.run('1')))
        same(r.kit.added, {'closet_probe'})
        r.ticks(1)
        eq(r.kit.shown.closet_probe, true) same(ran, {'a'})
        r.ticks(2)
        same(ran, {'a'}, 'b waits two frames')
        r.ticks(1)
        same(ran, {'a', 'b'})
        ok(has(r, 'probe: PASS 1 a')) ok(has(r, 'probe: PASS 1 b')) ok(has(r, 'probe: END 1 2/2'))
        eq(r.kit.dropped, 1) ok(released(r)) eq(r.p.running(), nil)
    end,
    a_part_gone_mid_test_fails_and_cleans_up = function()
        local r = rig({['1'] = {steps = {
            {frames = 0, name = 'a', run = function(ctx) ctx.make(WIDGET, 0, 0); return true end},
            {frames = 1, name = 'b', run = PASS}}}})
        r.kit.widgets[WIDGET] = function() return {} end
        r.p.run('1')
        r.ticks(1)
        r.kit.made[1].live = false -- a map change took it
        r.ticks(3)
        ok(has(r, 'probe: FAIL 1 parts: gone')) ok(not has(r, 'PASS 1 b')) ok(has(r, 'probe: END 1 1/2'))
        ok(released(r))
    end,
    a_throwing_call_fails_the_check = function()
        local r = rig({['1'] = {steps = {{frames = 0, name = 'a', run = function() error('boom') end}}}})
        r.p.run('1')
        r.ticks(2)
        ok(has(r, 'probe: FAIL 1 a:')) ok(has(r, 'boom')) ok(has(r, 'probe: END 1 0/1'))
    end,
    a_step_can_wait_and_fail_with_why = function()
        local polls = 0
        local r = rig({['1'] = {steps = {
            {frames = 0, name = 'poll', run = function() polls = polls + 1; if polls < 3 then return 'wait' end
                return true end},
            {frames = 0, name = 'no', run = function() return false, 'got 2' end}}}})
        r.p.run('1')
        r.ticks(5)
        eq(polls, 3) ok(has(r, 'probe: PASS 1 poll')) ok(has(r, 'probe: FAIL 1 no: got 2'))
        ok(has(r, 'probe: END 1 1/2'))
    end,
    times_out = function()
        local r = rig({['1'] = {steps = {{frames = 100000, name = 'a', run = PASS}}}})
        r.p.run('1')
        r.ticks(3)
        r.now = r.now + r.Probe.TIMEOUT + 1
        r.ticks(1)
        ok(has(r, 'probe: FAIL 1 timeout')) ok(has(r, 'probe: END 1 0/1')) eq(r.p.running(), nil)
    end,
    a_test_can_set_its_own_timeout = function()
        local r = rig({['5'] = {timeout = 90, steps = {{frames = 100000, name = 'a', run = PASS}}}})
        r.p.run('5')
        r.now = r.now + r.Probe.TIMEOUT + 1
        r.ticks(1)
        eq(r.p.running(), '5')
        r.now = r.now + 60
        r.ticks(1)
        ok(has(r, 'probe: FAIL 5 timeout'))
    end,
    off_ends_the_running_test = function()
        local cleaned = false
        local r = rig({['1'] = {cleanup = function() cleaned = true end,
            steps = {{frames = 50, name = 'a', run = PASS}, {frames = 0, name = 'b', run = PASS}}}})
        local ok_, line = r.p.off()
        ok(ok_) eq(line, 'probe: nothing running')
        r.p.run('1')
        r.ticks(1)
        r.kit.input(true, 'closet_probe')
        r.p.off()
        ok(has(r, 'probe: END 1 0/2')) ok(cleaned) ok(released(r)) eq(r.p.running(), nil)
    end,
    a_new_run_ends_the_running_one = function()
        local r = rig({['1'] = {steps = {{frames = 50, name = 'a', run = PASS}}},
            ['2'] = {steps = {{frames = 0, name = 'b', run = PASS}}}})
        r.p.run('1')
        r.p.run('2')
        ok(has(r, 'probe: END 1 0/1')) eq(r.p.running(), '2')
        r.ticks(2)
        ok(has(r, 'probe: END 2 1/1'))
    end,
    coop_off_stops_the_probe = function()
        local r = rig({['1'] = {steps = {{frames = 50, name = 'a', run = PASS}}}})
        r.p.run('1')
        r.kit.input(true, 'closet_probe')
        r.p.stop()
        eq(r.p.running(), nil) ok(released(r)) ok(has(r, 'probe: END 1 0/1'))
        r.p.stop() -- idle: nothing more
        eq(count(r, 'END'), 1)
    end,
    the_group_is_added_once = function()
        local r = rig({['1'] = {steps = {{frames = 0, name = 'a', run = PASS}}}})
        r.p.run('1')
        r.ticks(2)
        r.p.run('1')
        r.ticks(2)
        same(r.kit.added, {'closet_probe'})
    end,
    unknown_test_is_refused = function()
        local r = rig({})
        local ok_, line = r.p.run('9')
        eq(ok_, false) eq(line, r.Probe.USE)
    end,
    test1_happy_path = function()
        local r = rig()
        game(r)
        play(r, '1')
        for _, check in ipairs({'classes', 'grid', 'items', 'tiles', 'select', 'gc', 'gc_survived', 'mouse'}) do
            ok(has(r, 'probe: PASS 1 ' .. check), check)
        end
        ok(has(r, 'probe: END 1 8/8')) eq(r.tv.v, 0, 'TileView made visible') eq(r.tv.SelectionMode, 1)
        ok(r.gc, 'a GC was asked for') ok(r.tv.cleared >= 2, 'cleanup emptied the list') ok(released(r))
        eq(#r.made, 8)
        for i, item in ipairs(r.made) do
            eq(item.class, r.found[DATA]) eq(item.outer, r.tv) eq(item.Index, i - 1) eq(item.IconAssetPath, ICON)
        end
    end,
    test1_items_lost_after_gc = function()
        local r = rig()
        game(r, {gc_loses = true})
        play(r, '1')
        ok(has(r, 'probe: FAIL 1 gc_survived')) ok(has(r, 'probe: END 1 6/8')) ok(released(r))
    end,
    test1_missing_class = function()
        local r = rig()
        game(r)
        r.found[DATA] = nil
        play(r, '1')
        ok(has(r, 'probe: FAIL 1 classes')) ok(has(r, DATA))
    end,
    test2_happy_path = function()
        local r = rig()
        game(r)
        play(r, '2')
        for _, check in ipairs({'class', 'slot', 'icon', 'name', 'spaced_names', 'equip_lock'}) do
            ok(has(r, 'probe: PASS 2 ' .. check), check)
        end
        ok(has(r, 'probe: END 2 6/6')) ok(has(r, '256x256'))
        eq(r.slot.Text_ItemName.v, 4, 'name shown again after the state calls')
    end,
    test2_spaced_name_missing = function()
        local r = rig()
        game(r, {no_spaced = true})
        play(r, '2')
        ok(has(r, 'probe: FAIL 2 spaced_names')) ok(has(r, 'probe: END 2 4/6'))
    end,
    test3_happy_path = function()
        local r = rig()
        panels(r)
        play(r, '3')
        ok(has(r, 'probe: PASS 3 tabs')) ok(has(r, 'probe: PASS 3 focus9')) ok(has(r, 'probe: PASS 3 hover'))
        ok(has(r, 'probe: END 3 12/12')) eq(#r.tabs, 9) eq(r.tabs[9].TextBlock.t.text, '9')
        eq(r.kit.made[1].hit, true, 'tabs take the mouse')
    end,
    test3_label_not_set = function()
        local r = rig()
        panels(r, {no_label = true})
        play(r, '3')
        ok(has(r, 'probe: FAIL 3 tabs')) ok(has(r, 'probe: END 3 1/12'))
    end,
    test4_reads_expected_states = function()
        local r = rig()
        panels(r)
        play(r, '4')
        for _, check in ipairs({'class', 'detail', 'fill', 'craft0', 'craft0_read', 'craft1_read', 'craft2_read',
            'other_event'}) do ok(has(r, 'probe: PASS 4 ' .. check), check) end
        ok(has(r, 'probe: END 4 10/10')) eq(r.detail.ItemRarity, 3) eq(r.detail.MaterialText2.text, '')
    end,
    test4_mismatch_reports_values = function()
        local r = rig()
        panels(r, {hold = 1})
        play(r, '4')
        ok(has(r, 'probe: FAIL 4 craft0_read:')) ok(has(r, 'hold 1 materials 0'))
    end,
    test5_map_change = function()
        local r = rig()
        game(r)
        r.tv.SetKeyboardFocus = function() end
        r.p.run('5')
        r.ticks(30)
        ok(r.kit.holding(), 'input held') ok(has(r, 'probe: PASS 5 focus'))
        r.now = r.now + 9
        r.ticks(5)
        ok(has(r, 'probe: PASS 5 game_ignores_keys')) ok(has(r, 'NOTE 5 map_change'))
        ok(not r.kit.holding(), 'input given back before asking for a fast travel')
        r.kit.up = false -- a pause first: the root hides, its parts stay
        r.ticks(3)
        r.kit.up = true
        r.ticks(3)
        ok(has(r, 'not a map change')) ok(not has(r, 'FAIL'))
        r.kit.up = false -- the map change: the root goes, its parts with it
        for _, rec in ipairs(r.kit.made) do rec.live = false end
        r.ticks(3)
        ok(not has(r, 'FAIL'))
        r.kit.up = true
        r.ticks(3)
        ok(has(r, 'probe: PASS 5 map_change')) ok(has(r, 'probe: END 5 7/7')) ok(released(r))
    end,
    test5_game_took_the_key = function()
        local r = rig()
        game(r)
        r.tv.SetKeyboardFocus = function() end
        r.p.run('5')
        r.ticks(30)
        r.kit.paused_now = true
        r.ticks(2)
        ok(has(r, 'probe: FAIL 5 game_ignores_keys')) ok(released(r))
    end,
    test5_has_a_long_timeout = function()
        local r = rig()
        eq(r.Probe.TESTS['5'].timeout, 90)
    end,
    test6_logs_bones_fov_slots_lods_skin = function()
        local r = rig()
        reads(r)
        play(r, '6')
        ok(has(r, 'probe: END 6 5/5'))
        ok(has(r, 'probe: PASS 6 bones: 3 bones; head=1 neck=- spine=- upperarm_l=2 upperarm_r=-'))
        ok(has(r, 'pelvis=0'))
        ok(has(r, 'probe: NOTE 6 bones 0-2: pelvis Head upperarm_l'))
        ok(has(r, 'probe: PASS 6 fov: aspect ratio axis constraint 1, camera FOV 70, UI viewport 3840x2160 units at DPI scale 1.5'))
        ok(has(r, 'probe: NOTE 6 slots: ' .. OCEAN_MAID .. ' 0=Body 1=Skin') == false, 'Ocean Maid is not in the slot list')
        ok(has(r, 'probe: NOTE 6 slots: /Game/Art/Character/PC/CH_P_EVE_10/CH_P_EVE_10.CH_P_EVE_10 0=Body 1=Skin'))
        ok(has(r, 'probe: NOTE 6 slots: /Game/OutfitMods/FitBase/fitbase/SK_fitbase_v1.SK_fitbase_v1 0=Body 1=Skin'))
        ok(has(r, 'probe: PASS 6 slots: ' .. #r.Probe.MESHES .. ' meshes, 0 not found'))
        ok(has(r, 'probe: PASS 6 lods: Ocean Maid ' .. OCEAN_MAID .. ' 2 LODs, LOD1 map 2; Kunoichi Shadow '))
        ok(has(r, 'probe: PASS 6 skin: AiK_CH27_14595 14 Object MI_Skin tex=Body_A vec='))
        eq(#r.kit.made, 0, 'no game widget made')
    end,
    test6_unverified_step_skips = function()
        local r = rig()
        reads(r)
        r.eve.Mesh.GetNumBones = function() error('no GetNumBones') end
        play(r, '6')
        ok(has(r, 'probe: SKIP 6 bones: not verified: '))
        ok(has(r, 'no GetNumBones'))
        ok(has(r, 'probe: PASS 6 skin')) ok(has(r, 'probe: END 6 4/5'))
    end,
    test6_fov_on_a_kit_without_a_screen_read = function() -- an older kit (no kit.screen): the camera reads still pass
        local r = rig()
        reads(r)
        r.kit.screen = nil
        play(r, '6')
        ok(has(r, 'probe: PASS 6 fov: aspect ratio axis constraint 1, camera FOV 70, UI viewport unread'))
        ok(has(r, 'probe: END 6 5/5'))
    end,
    test6_skin_without_a_closet_fit = function()
        local r = rig()
        reads(r)
        r.eve.Mesh.SkeletalMesh = uobj('/Game/Art/Character/PC/CH_P_EVE_10/CH_P_EVE_10.CH_P_EVE_10')
        play(r, '6')
        ok(has(r, 'probe: PASS 6 skin: no closet fit on the body (/Game/Art/Character/PC/CH_P_EVE_10/CH_P_EVE_10.CH_P_EVE_10)'))
    end,
    refuses_on_the_title = function()
        local r = rig({['1'] = {steps = {{frames = 0, name = 'a', run = PASS}}}})
        r.world = false
        eq((r.p.run('1')), false) eq(r.log[1], 'probe: FAIL 1 world: not in the game world') eq(#r.kit.added, 0)
    end,
    refuses_while_another_screen_holds_input = function()
        local r = rig({['1'] = {steps = {{frames = 0, name = 'a', run = PASS}}}})
        r.kit.held = 'lobby'
        eq((r.p.run('1')), false) ok(has(r, 'probe: FAIL 1 kit: another screen holds the input'))
        eq(r.kit.held, 'lobby')
    end,
    a_reset_of_the_input_ends_the_test = function()
        local r = rig({['1'] = {steps = {
            {frames = 0, name = 'take', run = function(ctx) ctx.take_input(); return true end},
            {frames = 50, name = 'b', run = PASS}}}})
        r.p.run('1')
        r.ticks(2)
        ok(r.kit.holding())
        r.kit.held = nil -- coop ui reset, or the focus watchdog
        r.ticks(1)
        ok(has(r, 'probe: FAIL 1 input: taken back')) eq(r.p.running(), nil)
    end,
    steps_wait_while_the_ui_is_hidden = function()
        local ran = 0
        local r = rig({['1'] = {steps = {{frames = 2, name = 'a', run = function() ran = ran + 1; return true end}}}})
        r.p.run('1')
        r.ticks(1) -- shown, waiting its frames
        r.kit.up = false -- paused before the first step
        r.ticks(5)
        eq(ran, 0)
        r.kit.up = true
        r.ticks(2)
        eq(ran, 1)
    end,
    a_lost_input_release_is_tried_again = function()
        local r = rig({['1'] = {steps = {
            {frames = 0, name = 'take', run = function(ctx) ctx.take_input(); return true end},
            {frames = 50, name = 'b', run = PASS}}}})
        r.p.run('1')
        r.ticks(2)
        r.kit.ignore_release = 2
        r.p.off()
        ok(r.kit.holding(), 'the first release was lost')
        r.ticks(3)
        ok(not r.kit.holding(), 'tried again until it held')
    end,
    the_group_hides_at_the_end = function()
        local r = rig({['1'] = {steps = {{frames = 0, name = 'a', run = PASS}}}})
        r.p.run('1')
        r.ticks(2)
        eq(r.kit.shown.closet_probe, false)
    end,
    test5_drops_its_parts = function()
        local r = rig()
        game(r)
        r.tv.SetKeyboardFocus = function() end
        r.p.run('5')
        r.ticks(30)
        r.p.off()
        eq(r.kit.dropped, #r.kit.made) ok(#r.kit.made > 0)
    end,
    commands = function()
        local calls = {}
        local probe = {run = function(n) calls[#calls + 1] = 'run ' .. n; return true, 'ran' end,
            off = function() calls[#calls + 1] = 'off'; return true, 'off' end}
        package.loaded['closet.commands'] = nil
        local Probe = require('closet.ui.probe')
        local C = require('closet.commands').new({dress = {}, fits = {BY_ID = {}}, probe = probe})
        -- As main/commands.lua's M.run calls it: six words, nil-padded.
        eq(select(2, C.closet('probe', nil, nil, nil, nil, nil)), Probe.USE)
        ok((C.closet('probe', '3', nil, nil, nil, nil)))
        ok((C.closet('probe', 'off', nil, nil, nil, nil)))
        eq((C.closet('probe', '3', 'x', nil, nil, nil)), false)
        same(calls, {'run 3', 'off'})
        ok(require('closet.commands').USE:find('probe <1-6|off>', 1, true))
        eq(Probe.USE, 'Use: coop closet probe <1-6|off>')
    end,
}
run('probe_test', tests)
