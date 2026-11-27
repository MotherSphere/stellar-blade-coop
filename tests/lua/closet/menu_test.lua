-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The closet menu (closet/ui/menu.lua over closet/ui/view.lua) on menu_fakes.lua's fake kit and parts: open draws the
-- tab row, the slot rows, the grid with the None tile first, the detail panel and the hints; coop closet menu opens
-- and closes it; every close path drops every part and gives the input back; coop off does not revert; a draw that
-- raises closes the menu; the Body row, the origin line, the body switch notices, the Clear preview pictures row and
-- the Reset Stellar Closet row.
local run = dofile('tests/lua/closet/run.lua')
local F = dofile('tests/lua/closet/menu_fakes.lua')
package.loaded.UEHelpers = {GetPlayer = function() return nil end, GetPlayerController = function() return F.pc end}
local Slots = require('closet.slots')
local T = require('ui.text')
local Fits = require('closet.fits')
-- No enemy near EVE in these tests: core/player.lua's engaged walks the game's actors.
require('core.player').engaged = function() return false end
-- A tab's English label: the fitting tabs (Head..Body and Intimate) go through closet.beta.
local BETA = {head = true, torso = true, arms = true, hips = true, intimate = true, legs = true, body = true}
local function tab_label(id)
    return BETA[id] and T.en.closet.beta:format(T.en.closet.tabs[id]) or T.en.closet.tabs[id]
end

local function rig(o)
    o = o or {}
    local r = {told = {}, log = {}, reverted = 0, confirmed = 0, offs = 0, previews = {}, previewing = false, t = 0,
        world = true, photo = '0', status = 'mod=1 theater=none', kit = F.kit(), dev = o.uidev}
    if o.before then o.before(r) end
    package.loaded['closet.ui.menu'], package.loaded['closet.ui.view'] = nil, nil
    local Menu = require('closet.ui.menu')
    -- The dress: a preview wears its choices and starts previewing; confirm and revert end it.
    r.dress = {installed = o.installed or function() return true end, choices = function() return r.choices end,
        preview = function(c) -- An empty look is her own look (closet/dress.lua's own_look).
            r.previews[#r.previews + 1] = c; r.choices, r.previewing = c, true; return true
        end,
        previewing = function() return r.previewing end, plan = function() return r.plan end,
        confirm = function() r.confirmed = r.confirmed + 1; r.previewing = false; return true, 'closet: confirmed' end,
        revert = function() r.reverted = r.reverted + 1; r.previewing = false; return true, 'closet: reverted' end,
        off = function() r.offs = r.offs + 1; r.choices, r.previewing = nil, false; return true, 'closet: off' end,
        game_look = function() return r.game_look end, loads = o.loads or function() return true end}
    r.menu = Menu.new({kit = r.kit, dress = r.dress, words = function() return T.en end,
        tell = function(build) r.told[#r.told + 1] = build(T.en) end, log = function(m) r.log[#r.log + 1] = m end,
        world = function() return r.world end, photo = function() return r.photo end,
        status = function() return r.status end, now = function() return r.t end, adult = o.adult,
        camera = o.camera, folder = o.folder, thumbs = o.thumbs, colour = o.colour, shape = o.shape,
        options = o.options, presets = o.presets, uidev = function() return r.dev end,
        nav_held = function() return r.held end, busy = function() return r.busy, r.busy and 'busy: ' .. r.busy end})
    return r
end
-- A pack suit named Aria (first by name on the Full tab) with two variants, the second's mesh missing when the rig
-- says so: Jacket (3, on) leads Lining (5), Boots (4, on), Bag (6, off).
local ARIA = 'aria.suit'
local function aria()
    return {UniqueFitID = ARIA, DisplayName = 'Aria', Slot = 'FullOutfit', File = '~mods\\A\\aria.dekcns.json',
        Variants = {{Mesh = '/Game/A/V1.V1', Name = 'Short', HiddenMats = {}, Materials = {}, Parameters = {}},
            {Mesh = '/Game/A/V2.V2', HiddenMats = {}, Materials = {}, Parameters = {}},
            {Mesh = '/Game/A/V3.V3', Name = 'Long', HiddenMats = {}, Materials = {}, Parameters = {}}},
        PieceHints = {{MaterialIndex = 3, Name = 'Bolero', Slot = 'Outerwear'},
            {MaterialIndex = 4, Name = 'Boots', Slot = 'Shoes'}, {MaterialIndex = 6, Name = 'Bag'}},
        UserConfigs = {MaterialToggles = {
            {DisplayName = 'Bolero', Description = 'The cropped jacket', MaterialIndex = 3, Value = true},
            {DisplayName = 'Lining', MaterialIndex = 5, Value = true, ControlledBy = 'Bolero'},
            {DisplayName = 'Boots', MaterialIndex = 4, Value = true},
            {DisplayName = 'Bag', MaterialIndex = 6, Value = false}}}}
end
-- f(r) on a rig with Aria in the catalogue and a real options layer (closet/options.lua) on a fake store.
local function with_aria(f, o)
    Fits.use({[ARIA] = aria()})
    local good, why = pcall(function()
        o = o or {}
        local store = {file = nil}
        store.save = function(l) store.file = l; return true end
        store.load = function() return store.file end
        store.clear = function() store.file = nil end
        o.options = require('closet.options').new({store = store, dress = {plan = function() end,
            loads = function() return true end}, log = function() end})
        if o.with then o.with(o) end
        local r = rig(o)
        r.store, r.options = store, o.options
        local ran, failed = pcall(f, r)
        if not ran then error(tostring(failed) .. '\nlog: ' .. table.concat(r.log, ' | '), 0) end
    end)
    Fits.use(nil)
    Fits.CHOSEN = {}
    ok(good, why)
end
-- with_aria's o for a rig whose EVE wears Aria at the open: its options page previews nothing.
local function wearing_aria() return {before = function(r) r.choices = {{fit = ARIA}} end} end
-- f(r) as with_aria's, with real presets (closet/presets.lua, r.presets) on a fake store (r.pstore) over the rig's
-- dress: the Full tab's rows Save look as preset, the presets, the filter, then the outfits.
local function with_presets(f)
    local box, pstore = {}, {}
    pstore.save = function(l) pstore.file = l; return true end
    pstore.load = function() return pstore.file end
    pstore.clear = function() pstore.file = nil end
    with_aria(function(r)
        r.presets, r.pstore = box.p, pstore
        box.r = r
        f(r)
    end, {with = function(o)
        box.p = require('closet.presets').new({store = pstore, options = o.options, log = function() end,
            dress = {choices = function() return box.r.dress.choices() end, installed = function() return true end,
                wear = function() error('the menu wears through its preview') end}})
        o.presets = box.p
    end})
end
-- The menu row's SB hint parts as drawn now: {label, icon, icon2} right to left.
local function menu_hints(r)
    local out = {}
    for _, h in ipairs(r.kit.live(F.HINT)) do
        if h.y == 1990 then
            local one = {x = h.x}
            for _, c in ipairs(h.o.calls) do
                if c[1] == 'SetText' then one[1] = c[2].text
                elseif c[1] == 'SetResourceAction' then one[2] = c[2]
                elseif c[1] == 'SetResourceAction2' then one[3] = c[2] end
            end
            out[#out + 1] = one
        end
    end
    table.sort(out, function(a, b) return a.x > b.x end)
    for _, one in ipairs(out) do one.x = nil end
    return out
end
-- A row title as the options page writes a child row: its lead mark at depth (1: a piece under its section).
local function child(depth, title) return string.rep('    ', depth - 1) .. '- ' .. title end
-- A value as the SB row shows it: cut to its value box (closet/ui/view.lua's fit).
local function fit(value) return require('closet.ui.view').fit(value) end
-- The value of the shown setting row titled title, or nil.
local function row_value(r, title)
    for _, rec in ipairs(r.kit.live(F.OPTION)) do
        if rec.o.Text_TitleValue.text == title then return rec.o.Text_ItemValue.text end
    end
    -- A slider row (WB_Setting_Slider_Slot): the number its own value text shows, ItemTextRange at CurrentPercent with
    -- ItemTextFractionalDigits.
    for _, rec in ipairs(r.kit.live(F.SLIDER)) do
        local w = rec.o
        if w.TextTitleValue.text == title then
            local lo, hi = w.ItemTextRange.Min, w.ItemTextRange.Max
            return ('%.' .. w.ItemTextFractionalDigits .. 'f'):format(lo + (hi - lo) * w.CurrentPercent)
        end
    end
end
-- The slider row titled title, or nil.
local function slider(r, title)
    for _, rec in ipairs(r.kit.live(F.SLIDER)) do if rec.o.TextTitleValue.text == title then return rec end end
end
-- The labels of the shown header rows (WB_Setting_Category).
local function headers(r)
    local out = {}
    for _, rec in ipairs(r.kit.live(require('ui.kit.parts').CLASS.header)) do
        out[#out + 1] = rec.o.Category_Name.text
    end
    return out
end
-- A fake shape layer (closet/shape.lua's face): its rows (names), values, sets and offs.
local function fake_shape(names)
    local s = {names = names or {}, values = {}, sets = {}, offs = 0}
    s.rows = function() return s.names end
    s.get = function(n) return s.values[n] or 0 end
    s.set = function(n, v)
        s.sets[#s.sets + 1] = n .. ' ' .. v
        s.values[n] = math.max(0, math.min(100, v))
        return true
    end
    s.step = function(n, dir) return s.set(n, s.get(n) + 10 * dir) end
    s.off = function() s.offs = s.offs + 1; s.values = {}; return true end
    return s
end
-- A fake colour layer (closet/colour.lua's face): its palette, its steps and offs.
local function fake_colour()
    local Colour = require('closet.colour')
    local c = {palette = {}, steps = {}, offs = 0}
    c.get = function(role) return c.palette[role] or 'off' end
    c.step = function(role, dir)
        c.steps[#c.steps + 1] = role .. ' ' .. dir
        c.palette[role] = Colour.cycle(c.get(role), dir)
        return true
    end
    c.off = function() c.offs = c.offs + 1; c.palette = {}; return true end
    return c
end
-- A fake closet camera (closet/ui/camera.lua's face): its calls in order, its ticks' dt and region.
local function fake_camera()
    local c = {calls = {}, ticks = {}, on = false, now = 'region', preset = 'game', factor = 1}
    c.open = function() c.calls[#c.calls + 1] = 'open'; c.on = true end
    c.close = function() c.calls[#c.calls + 1] = 'close'; c.on = false end
    c.stop = function() c.calls[#c.calls + 1] = 'stop'; c.on = false end
    c.tick = function(dt, region) c.ticks[#c.ticks + 1] = {dt = dt, region = region} end
    c.word = function(w) c.calls[#c.calls + 1] = w end
    c.forget = function() c.calls[#c.calls + 1] = 'forget'; c.now = 'region' end
    c.running = function() return c.on end
    c.mode = function() return c.now end
    c.light = function() return c.preset, c.factor end
    -- held: right mouse held at a Back (its release decides); due: that release was a click, taken once.
    c.held, c.due = false, false
    c.hold_back = function() return c.held end
    c.take_back = function() local d = c.due; c.due = false; return d end
    return c
end

-- Menu words at time t (s after the open at 0).
local function at(r, t, ...)
    r.t = t
    for _, word in ipairs({...}) do r.menu.nav(word) end
end
-- A tick at time t.
local function tick(r, t) r.t = t; r.menu.tick() end
-- The detail panel's title and description now.
local function detail(r)
    local d = r.kit.live(F.DETAIL)[1].o
    return d.TitleText.text, d.DescriptionText.text
end
local function grid(r) return r.kit.live(F.GRID)[1].o.TileView_ItemList end
local function popups(r) return #r.kit.live(F.POPUP) end
-- The kit images of the menu's group as last built that are size by size (1: the holders).
local function images(r, size)
    local out = {}
    for _, i in ipairs(r.kit.groups.closet_menu.images) do if i.w == size and i.h == size then out[#out + 1] = i end end
    return out
end
-- The origin badge's kit image: the one square image larger than a holder.
local function badge_image(r)
    local out = {}
    for _, i in ipairs(r.kit.groups.closet_menu.images) do if i.w == i.h and i.w > 1 then out[#out + 1] = i end end
    eq(#out, 1, 'one badge')
    return out[1]
end
-- The glyph the origin badge shows, nil while it is hidden.
local function badge(r)
    local b = badge_image(r)
    return b.shown and b.texture and b.texture.glyph or nil
end
-- The glyphs the hidden holders keep, sorted.
local function held(r)
    local out = {}
    for _, i in ipairs(images(r, 1)) do
        eq(i.shown, false, 'a holder is hidden')
        if i.texture then out[#out + 1] = i.texture.glyph end
    end
    table.sort(out)
    return out
end
-- The Top row (Chest, the 6th) of the torso tab (the 3rd), open: tiles None, Maid top (Ocean Maid), Kunoichi top
-- (Kunoichi Shadow).
local MAID, KUNOICHI = 'AiK_CH27_14595', 'AiK_CH46_xSH_14462'
local function on_top(r)
    r.menu.open()
    at(r, 0.05, 'tab_right', 'tab_right', 'tab_right', 'down', 'down', 'down', 'down', 'down')
    eq((detail(r)), 'Top', 'on the Top row')
end

-- Every part dropped, the group hidden, the menu closed; the input given back by a tick 150 ms later.
local function all_gone(r)
    eq(r.kit.dropped, #r.kit.made, 'parts dropped')
    eq(r.kit.shown.closet_menu, false, 'group shown')
    eq(r.menu.is_open(), false, 'is_open')
    tick(r, r.t + 0.15)
    eq(r.kit.held, nil, 'input held')
    eq(r.kit.inputs[#r.kit.inputs][1], false, 'last input call')
end
-- A kit with no player controller while r.kit.no_pc: its give-back is refused, the input stays held (ui/kit/kit.lua's
-- input_mode returns before it changes anything).
local function no_pc(r)
    local input = r.kit.input
    r.kit.no_pc = true
    r.kit.input = function(on, who, mouse, again)
        if not on and r.kit.no_pc then r.kit.inputs[#r.kit.inputs + 1] = {on, who, mouse, again}; return end
        input(on, who, mouse, again)
    end
end
-- The camera row as drawn now, left to right: its SB hint parts at y 1890 ({x, text, icon}) and its kit texts at
-- y 1899 that show something ({x, s}).
local function camera_row(r)
    local parts, texts = {}, {}
    for _, h in ipairs(r.kit.live(F.HINT)) do
        if h.y == 1890 then
            local text, icon
            for _, c in ipairs(h.o.calls) do
                if c[1] == 'SetText' then text = c[2].text elseif c[1] == 'SetResourceAction' then icon = c[2] end
            end
            parts[#parts + 1] = {x = h.x, text = text, icon = icon}
        end
    end
    for _, t in ipairs(r.kit.groups.closet_menu.texts) do
        if t.y == 1899 and t.s ~= '' then texts[#texts + 1] = {x = t.x, s = t.s} end
    end
    table.sort(parts, function(a, b) return a.x < b.x end)
    table.sort(texts, function(a, b) return a.x < b.x end)
    return parts, texts
end
-- The width estimate of a Bold 30 hint text in kit units: 30 a CJK character, 17 any other.
local function text_width(s)
    local n = 0
    for _, c in utf8.codes(s) do n = n + ((c >= 0x2E80 and c < 0xFB00 or c >= 0xFF00 and c < 0xFFF0) and 30 or 17) end
    return n
end
local SB_ICON = 62 -- The SB hint part's icon and gap before its label (hints.md's estimate, not measured).

local tests = {
    opens_and_draws_the_parts = function()
        local r = rig()
        local good, line = r.menu.open()
        ok(good, line)
        eq(r.menu.is_open(), true, 'is_open')
        same(r.kit.inputs[1], {true, 'closet_menu', true, true}, 'input: the cursor shown, taken again (again)')
        eq(r.kit.sounds[1], 'open', 'sound')
        eq(r.kit.shown.closet_menu, true, 'group shown')
        local g = r.kit.groups.closet_menu
        same(g.place, {x = 0, y = 0, w = 3840, h = 2160, fixed = true, hit = true}, 'group place')
        local View = require('closet.ui.view')
        eq(View.EDGE, 2112, 'the menu edge') eq(View.COLUMNS, 5, 'grid columns')
        -- A flat shade to x 2162: past the right tab key's icon (art at 2028 to 2070) by the left one's margin (its
        -- art starts at x 92). Then the lobby's left gradient to x 2562; the dither under the hints.
        same(g.shade, {x = 0, y = 0, w = 2162, h = 2160, color = {A = 0.72}}, 'shade')
        eq(g.images[1].tex, 'shade_left', 'gradient') eq(g.images[1].x, 2162, 'gradient x')
        eq(g.images[1].x + g.images[1].w, 2562, 'gradient end')
        eq(g.images[2].tex, 'dither', 'dither') eq(g.images[2].y, 1860, 'dither y') eq(g.images[2].w, 2560, 'dither w')
        same(g.images[2].tint, {A = 0.8}, 'dither tint')
        -- The tab row: a window of 7 tab buttons, labelled; the Full outfit tab first and focused.
        local tabs = r.kit.live(F.TAB)
        eq(#tabs, 7, 'tabs')
        for i, id in ipairs({'full', 'colour', 'head', 'torso', 'arms', 'hips', 'legs'}) do
            eq(tabs[i].o.TextValue.text, tab_label(id), 'tab ' .. i)
            ok(F.called(tabs[i].o, 'RefreshDesign'), 'tab RefreshDesign ' .. i)
            ok(F.called(tabs[i].o, i == 1 and 'FocusTabButton' or 'DefocusTabButton'), 'tab focus ' .. i)
            eq(tabs[i].x, 160 + (i - 1) * 266, 'tab x ' .. i)
        end
        -- The Full tab's rows: one an outfit by name, then Reset Stellar Closet, Kunoichi Shadow focused; the hints
        -- Back, Whole outfit, Move.
        local rows = r.kit.live(F.OPTION)
        eq(#rows, 3, 'outfit rows and the Reset row')
        eq(rows[3].o.Text_TitleValue.text, T.en.closet.row.reset, 'the Reset row last')
        eq(rows[1].o.Text_TitleValue.text, 'Kunoichi Shadow', 'outfit row 1, first by name')
        eq(rows[1].o.Text_ItemValue.text, 'AiK', 'outfit row 1 pack')
        eq(rows[2].o.Text_TitleValue.text, 'Ocean Maid', 'outfit row 2')
        eq((detail(r)), 'Kunoichi Shadow', 'the outfit detail')
        local function said(h, call)
            for _, c in ipairs(h.o.calls) do if c[1] == call then return c[2].text or c[2] end end
        end
        local hints = r.kit.live(F.HINT)
        eq(#hints, 5, 'Full tab hints')
        eq(said(hints[4], 'SetText'), T.en.closet.hints.whole, 'Whole outfit hint')
        -- The torso tab's rows (three tabs right), on Bra (row 5): its grid.
        at(r, 0.05, 'tab_right', 'tab_right', 'tab_right', 'down', 'down', 'down', 'down')
        -- The torso rows in a window of 10: a soon row locked, Bra focused with Leotard worn nowhere (None).
        rows = r.kit.live(F.OPTION) -- Remade on the tab change: in screen order.
        table.sort(rows, function(a, b) return a.y < b.y end)
        eq(#rows, 10, 'rows')
        eq(rows[1].o.Text_TitleValue.text, 'Chest tattoo', 'row 1')
        eq(rows[1].o.Text_ItemValue.text, T.en.closet.row.soon, 'row 1 value')
        eq(rows[1].o.bLockItem, true, 'row 1 locked')
        ok(F.called(rows[1].o, 'EventNotification', 'RefreshAppearance'), 'row 1 locked look')
        eq(rows[5].o.Text_TitleValue.text, 'Bra', 'row 5')
        eq(rows[5].o.Text_ItemValue.text, 'None', 'row 5 value')
        ok(F.called(rows[5].o, 'EventNotification', 'StateFocus'), 'row 5 focused')
        local looks = {}
        for _, c in ipairs(rows[4].o.calls) do if c[1] == 'EventNotification' then looks[#looks + 1] = c[2] end end
        eq(looks[#looks], 'StateNormal', 'row 4 left: not focused')
        -- A transparent kit row over each slot row takes the mouse; it shows nothing while the part is there.
        eq(#g.zones, 19, 'zones: 10 rows, 5 hint chips, 4 camera hint chips')
        for i, z in ipairs(g.zones) do
            eq(z.label, '', 'zone label ' .. i)
            if i <= 10 then eq(z.y, rows[i].y + 27, 'zone y ' .. i) end
        end
        -- The grid: the hair salon's TileView, cleared, then the None tile and Ocean Maid's leotard, None selected.
        local grids = r.kit.live(F.GRID)
        eq(#grids, 1, 'grid')
        same({grids[1].x, grids[1].y, grids[1].w, grids[1].h}, {1161, 300, 1000, 820}, 'grid place: left-aligned with the detail panel')
        ok(F.called(grids[1].o, 'Set Goods'), 'Set Goods')
        local tv = grids[1].o.TileView_ItemList
        eq(tv.entry_w, 200, 'entry width: 5 columns') eq(tv.entry_h, 270, 'entry height: 3 rows')
        eq(tv.cleared, 3, 'cleared before each fill: Ocean Maid\'s tile on the Full tab, empty on the torso tab\'s ' ..
            'first row (soon), then Bra')
        eq(#tv.items, 2, 'tiles')
        eq(tv.items[1].ItemName.text, 'None', 'None first')
        eq(tv.items[2].ItemName.text, Fits.piece('AiK_CH27_14595', 'UndergarmentTop').Name, 'leotard')
        for i, item in ipairs(tv.items) do
            eq(item.IconAssetPath, F.path(i == 1 and 'none' or 'bra'), 'glyph ' .. i)
            eq(item.Index, i - 1, 'index ' .. i)
            eq(item.Purchased, true, 'purchased ' .. i)
        end
        eq(tv.items[1].Equiped, true, 'None worn') eq(tv.items[2].Equiped, false, 'leotard not worn')
        eq(tv:BP_GetSelectedItem(), tv.items[1], 'None selected')
        -- The detail panel: the focused slot, craft state 0, refreshed, the hold button hidden after it.
        local details = r.kit.live(F.DETAIL)
        eq(#details, 1, 'detail')
        same({details[1].x, details[1].y}, {1161, 1160}, 'detail place: right of a swatch')
        local d = details[1].o
        eq(d.TitleText.text, 'Bra', 'detail title')
        eq(d.CraftState, 0, 'craft state')
        ok(F.called(d, 'EventNotification', 'Refresh'), 'detail Refresh')
        ok(F.called(d.WB_Common_HoldButton, 'SetVisibility', 1), 'hold button hidden')
        -- The tab keys' icons at both ends of the tab row (86, after the 7th tab), then the menu hints right to left
        -- from x 2112 at y 1990: Back, Wear on a row with pieces, Move.
        hints = r.kit.live(F.HINT)
        eq(#hints, 5, 'hints')
        eq(said(hints[1], 'SetResourceAction'), 'UI_LeftShoulder', 'left tab key') eq(said(hints[1], 'SetText'), '', 'no label')
        eq(said(hints[2], 'SetResourceAction'), 'UI_RightShoulder', 'right tab key')
        eq(hints[1].x, 86, 'left tab key x') eq(hints[2].x, 160 + 7 * 266, 'right tab key x')
        local place = {}
        for _, h in ipairs(hints) do place[said(h, 'SetText')] = h end
        same({place[T.en.hint.back].x, place[T.en.hint.back].y}, {2112 - 400, 1990}, 'Back hint place')
        same({place[T.en.closet.hints.wear].x, place[T.en.closet.hints.wear].y}, {2112 - 2 * 400, 1990}, 'Wear hint')
        local move = place[T.en.hint.move]
        same({move.x, move.y}, {2112 - 3 * 400, 1990}, 'Move hint place')
        eq(said(move, 'SetResourceAction'), 'UI_DPad_Up', 'Move icon')
        eq(said(move, 'SetResourceAction2'), 'UI_DPad_Down', 'Move icon 2')
        for _, rec in ipairs(r.kit.made) do ok(rec.x >= 0 and rec.x < 2112, 'part x ' .. tostring(rec.x)) end
    end,

    tabs_and_grid_take_the_mouse = function()
        -- kit.part makes a part HitTestInvisible unless hit: Slate then keeps its whole subtree out of the hit test, so
        -- no tab hover and no tile click would reach them (closet/ui/probe.lua tests 1 and 3 made them with hit).
        local r = rig()
        r.menu.open()
        at(r, 0.05, 'tab_right', 'tab_right', 'tab_right', 'down', 'down', 'down', 'down')
        local tabs, grids = r.kit.live(F.TAB), r.kit.live(F.GRID)
        eq(#tabs, 7, 'tabs') eq(#grids, 1, 'grid')
        for i, rec in ipairs(tabs) do eq(rec.hit, true, 'tab ' .. i .. ' takes the mouse') end
        eq(grids[1].hit, true, 'the grid takes the mouse')
    end,

    -- The layout keeps the list clear: a value fits the SB row's value box (cut with '...'), the detail panel and a
    -- colour row's swatch sit right of that box, the menu's five hints start right of the menu's left edge (x 86).
    layout_keeps_the_list_clear = function()
        local View = require('closet.ui.view')
        ok(type(View.ROW_RIGHT) == 'number' and type(View.VALUE_COLS) == 'number', 'the value box is known')
        -- fit: whole up to VALUE_COLS columns, else cut with '...' within them (a CJK character takes two, a narrow
        -- one a half). The in-game test saw 'Reshape 50%' run out of the box, 'Pack colour' and 'No Reshape' fit.
        eq(View.fit('Pack colour'), 'Pack colour', 'Pack colour fits')
        eq(View.fit('No Reshape'), 'No Reshape', 'No Reshape fits')
        eq(View.fit(T.en.closet.row.soon), T.en.closet.row.soon, 'Coming soon fits')
        eq(View.fit('Reshape 50%'), 'Reshape 5...', 'Reshape 50% is cut')
        eq(View.fit('LKE_SF6_Mai_BikerOutfit'), 'LKE_SF6_...', 'a pack id is cut')
        -- A favourite's value leads with its mark, so a cut pack id keeps it, in every language.
        for code, L in pairs(T) do
            if type(L) == 'table' and L.closet then
                local fav = L.closet.presets.fav
                local lead = fav:match('^(.-)%%s')
                ok(lead and lead ~= '', code .. ': the favourite mark leads: ' .. fav)
                eq(View.fit(fav:format('LKE_SF6_Mai_BikerOutfit')):sub(1, #lead), lead, code .. ': the mark survives')
            end
        end
        eq(View.fit('外观外观外'), '外观外观外', 'five CJK characters fit')
        eq(View.fit('外观外观外观'), '外观外观...', 'six are cut')
        local e = string.char(0xE9) -- Latin-1, not UTF-8.
        eq(View.fit(e .. 't' .. e .. ' tenue longue'), e .. 't' .. e .. ' tenu...', 'not UTF-8: cut by bytes')
        eq(View.fit(''), '', 'empty')
        with_presets(function(r)
            r.menu.open()
            at(r, 0.5, 'down', 'down') -- Aria: Back, Whole outfit, Options, Favourite, Move.
            eq((detail(r)), 'Aria', 'on Aria')
            local hints = {}
            for _, h in ipairs(r.kit.live(F.HINT)) do if h.y == 1990 then hints[#hints + 1] = h end end
            eq(#hints, 5, 'five hints')
            for _, h in ipairs(hints) do ok(h.x >= 86, 'a hint starts right of the menu\'s left edge: ' .. h.x) end
            local d = r.kit.live(F.DETAIL)[1]
            ok(d.x >= View.ROW_RIGHT, 'the detail panel starts right of the value box: ' .. d.x)
            ok(d.y > 300, 'the detail panel under the grid')
            -- The origin badge right of the panel's 900-unit wide SizeBox_4 (a kit image draws under the panel), inside
            -- the menu's edge.
            local b = badge_image(r)
            ok(b.x >= d.x + 900, 'the badge right of the detail panel: ' .. b.x .. ' < ' .. d.x + 900)
            ok(b.x + b.w <= View.EDGE, 'the badge inside the menu: ' .. b.x + b.w)
            for _, z in ipairs(r.kit.groups.closet_menu.images) do
                if z.w == 28 then -- A colour row's swatch: right of the value box, left of the detail panel.
                    ok(z.x >= View.ROW_RIGHT and z.x + z.w <= d.x, 'swatch x ' .. z.x)
                end
            end
        end)
        -- A long pack id on the Full tab shows cut in the SB row and on the kit row under it when the SB part fails.
        Fits.use({['long.suit'] = {UniqueFitID = 'long.suit', DisplayName = 'Long', Slot = 'FullOutfit',
            File = '~mods/L/LKE_SF6_Mai_BikerOutfit.dekcns.json', UserConfigs = {MaterialToggles = {}},
            Variants = {{Mesh = '/Game/L/V.V', HiddenMats = {}, Materials = {}, Parameters = {}}}}})
        local good, why = pcall(function()
            for _, broken in ipairs({false, true}) do
                local r = rig({before = function(r) r.kit.fail[F.OPTION] = broken end})
                r.menu.open()
                if broken then
                    local shown = {}
                    for i = 1, 10 do shown[i] = r.kit.groups.closet_menu.zones[i].value end
                    ok(table.concat(shown, '|'):find('LKE_SF6_...', 1, true), 'the kit row: ' .. table.concat(shown, '|'))
                else
                    eq(row_value(r, 'Long'), 'LKE_SF6_...', 'the SB row')
                end
            end
        end)
        Fits.use(nil)
        ok(good, why)
    end,

    typed_menu_toggles = function()
        local r = rig()
        local Cmd = require('closet.commands').new({dress = r.dress, fits = Fits, probe = {},
            menu = function() return r.menu end})
        local good, line = Cmd.closet('menu')
        ok(good and r.menu.is_open(), line)
        good, line = Cmd.closet('menu')
        ok(good and not r.menu.is_open(), line)
        eq(r.reverted, 1, 'closed with a revert')
        all_gone(r)
        good, line = Cmd.closet('menu', 'now')
        eq(good, false, 'extra word') eq(line, require('closet.commands').USE, 'use line')
        ok(line:find('|menu|', 1, true), 'use line names menu')
        -- Without the menu (no Steam link): refused.
        good = require('closet.commands').new({dress = r.dress, fits = Fits, probe = {},
            menu = function() return nil end}).closet('menu')
        eq(good, false, 'no menu')
        -- The UI not up: refused with one notice, nothing made, no input taken.
        r.kit.up = false
        local made = #r.kit.made
        good = Cmd.closet('menu')
        eq(good, false, 'refused')
        same(r.told, {T.en.closet.refused.ui}, 'notice')
        eq(#r.kit.made, made, 'nothing made') eq(r.kit.held, nil, 'no input')
    end,

    close_drops_every_part_and_gives_input_back = function()
        local r = rig()
        r.menu.open()
        local tv = r.kit.live(F.GRID)[1].o.TileView_ItemList
        -- The Full tab: 7 tabs, 2 outfit rows, the Reset row, the grid, the detail, 2 tab keys and 3 hints.
        eq(#r.kit.made, 17, 'parts made')
        local good = r.menu.close()
        ok(good, 'close')
        all_gone(r)
        eq(r.reverted, 1, 'reverted')
        eq(r.kit.sounds[#r.kit.sounds], 'close', 'close sound')
        eq(tv.cleared, 2, 'grid cleared on close')
        local first_drop
        for i, e in ipairs(r.kit.events) do if e == 'drop' then first_drop = first_drop or i end end
        eq(r.kit.events[first_drop - 1], 'clear', 'cleared before the first drop')
        -- keep: dropped, no revert. The next open draws the same tab again.
        r.menu.open()
        r.menu.close('keep')
        all_gone(r)
        eq(r.reverted, 1, 'keep does not revert')
        -- Back closes with a revert.
        r.menu.open()
        r.menu.nav('tab_right')
        r.menu.nav('up')
        eq(r.menu.is_open(), true, 'up leaves it open')
        r.menu.nav('back')
        all_gone(r)
        eq(r.reverted, 2, 'back reverts')
        r.menu.open()
        ok(F.called(r.kit.live(F.TAB)[2].o, 'FocusTabButton'), 'last tab again')
        -- The popup part goes too.
        local View = require('closet.ui.view')
        local k = F.kit()
        local v = View.new(k, function() end)
        v.draw({tabs = {'A'}, tab = 1, rows = {{title = 'B', value = ''}}, row = 1, tiles = {{name = 'None'}}, tile = 1,
            detail = {title = 'B', desc = ''}, hints = {{'Back', 'Negative'}}, popup = {title = 'Keep?', desc = 'D'}})
        local pops = k.live(F.POPUP)
        eq(#pops, 1, 'popup') eq(pops[1].o.TitleText.text, 'Keep?', 'popup title') eq(pops[1].o.ButtonType, 3, 'YesNo')
        ok(F.called(pops[1].o, 'EventNotification', 'RefreshAll'), 'popup RefreshAll') eq(k.refocused, 1, 'refocus')
        v.drop_all()
        eq(k.dropped, #k.made, 'view parts dropped')
    end,

    input_comes_back_150_ms_after_a_close = function()
        local r = rig()
        r.menu.open()
        at(r, 1, 'back')
        eq(r.menu.is_open(), false, 'closed')
        eq(r.kit.held, 'closet_menu', 'the Esc that closed it does not reach the game')
        tick(r, 1.1)
        eq(r.kit.held, 'closet_menu', 'still held before 150 ms')
        tick(r, 1.15)
        eq(r.kit.held, nil, 'given back after 150 ms')
        -- An open before the give-back cancels it.
        at(r, 2, 'back')
        r.t = 2.05
        ok(r.menu.open(), 'open again at once')
        tick(r, 2.3)
        eq(r.kit.held, 'closet_menu', 'the open menu keeps the input')
        ok(r.menu.is_open(), 'still open')
    end,

    a_refused_give_back_is_asked_again = function()
        local r = rig()
        no_pc(r)
        r.menu.open()
        at(r, 1, 'back')
        tick(r, 1.2)
        eq(r.kit.held, 'closet_menu', 'refused: no player controller')
        local calls = #r.kit.inputs
        tick(r, 1.3)
        eq(#r.kit.inputs, calls + 1, 'asked again on the next tick')
        r.kit.no_pc = false
        tick(r, 1.4)
        eq(r.kit.held, nil, 'given back once the kit can')
        calls = #r.kit.inputs
        tick(r, 1.5)
        eq(#r.kit.inputs, calls, 'not asked after that')
    end,

    open_after_a_refused_give_back_is_not_refused = function()
        local r = rig()
        no_pc(r)
        r.menu.open()
        at(r, 1, 'back')
        tick(r, 1.2)
        eq(r.kit.held, 'closet_menu', 'still held for the closet')
        r.t = 2
        local good, line = r.menu.open()
        ok(good, line)
        ok(r.menu.is_open(), 'open')
        same(r.told, {}, 'no another-menu notice')
    end,

    stop_drops_without_revert = function()
        local r = rig()
        r.menu.open()
        local sounds = #r.kit.sounds
        r.menu.stop()
        eq(r.kit.held, nil, 'coop off gives the input back at once')
        all_gone(r)
        eq(r.reverted, 0, 'no revert')
        eq(#r.kit.sounds, sounds, 'no sound')
        r.menu.stop() -- Closed already: nothing.
        eq(r.reverted, 0, 'still no revert')
    end,

    a_draw_error_closes_and_drops = function()
        local r = rig({before = function(r) r.kit.fail[F.DETAIL] = true end})
        local good, line = r.menu.open()
        eq(good, false, 'open')
        ok(line:find('UE4SS.log', 1, true), line)
        ok(#r.kit.made > 0, 'parts made before the error')
        all_gone(r)
        has(r.log, 'draw failed', 'log')
        has(r.log, 'WB_NanoSuit_Detail', 'log names the part')
    end,

    a_failed_grid_fill_is_filled_again = function()
        local r = rig()
        local construct, failed = StaticConstructObject, false
        StaticConstructObject = function(...)
            if not failed then failed = true; error('construct refused', 0) end
            return construct(...)
        end
        local good, why = pcall(function()
            r.menu.open()
            local tv = grid(r)
            eq(#tv.items, 0, 'the first fill failed')
            local cleared = tv.cleared
            at(r, 0.1, 'left')
            ok(#tv.items > 0, 'the next draw fills the grid with the same tiles')
            eq(tv.cleared, cleared + 1, 'cleared before the second fill')
            at(r, 0.2, 'left')
            eq(tv.cleared, cleared + 1, 'a filled grid is not filled again')
        end)
        StaticConstructObject = construct
        if not good then error(why, 0) end
    end,

    tabs_rows_and_grid_move_with_their_keys = function()
        local r = rig()
        r.menu.open()
        -- Tabs: E and Q change the tab, its first row focused, with the change sound.
        at(r, 0.1, 'tab_right', 'tab_right', 'tab_right', 'tab_right')
        eq(r.kit.sounds[#r.kit.sounds], 'change', 'tab sound')
        eq((detail(r)), 'Upper arm tattoo', 'arms tab, first row')
        ok(F.called(r.kit.live(F.TAB)[5].o, 'FocusTabButton'), 'arms tab focused')
        at(r, 0.1, 'tab_left')
        local title, desc = detail(r)
        eq(title, 'Chest tattoo', 'torso tab, first row')
        eq(desc, T.en.closet.row.soon, 'a soon row shows its text')
        -- Rows: up and down, skipping nothing, with the move sound. A soon row has no grid.
        at(r, 0.4, 'right', 'select')
        at(r, 0.4, 'down')
        eq(r.kit.sounds[#r.kit.sounds], 'move', 'row sound')
        eq((detail(r)), 'Stomach tattoo', 'right and select on a soon row stay in the rows')
        at(r, 0.4, 'down', 'down', 'down', 'down')
        eq((detail(r)), 'Top', 'row 6')
        -- The grid: right goes in on the worn tile (None), right and left walk one row of tiles.
        at(r, 0.4, 'right')
        local tv = grid(r)
        eq(#tv.items, 3, 'tiles')
        eq(tv:BP_GetSelectedItem(), tv.items[1], 'None focused')
        eq((detail(r)), 'None', 'the detail shows the tile')
        at(r, 0.4, 'right')
        eq(tv:BP_GetSelectedItem(), tv.items[2], 'Maid top focused')
        title, desc = detail(r)
        eq(title, 'Maid top', 'tile detail')
        ok(desc:find('Outfit: Ocean Maid', 1, true) and desc:find('Slot: Top', 1, true), desc)
        at(r, 0.4, 'right', 'right', 'up', 'down')
        eq(tv:BP_GetSelectedItem(), tv.items[3], 'last tile kept; up and down do nothing in a grid of one row')
        at(r, 0.4, 'left', 'left', 'left')
        at(r, 0.4, 'down')
        eq((detail(r)), 'Jacket', 'left on the first tile went back to the rows')
        -- Back in the grid goes back to the rows, the menu stays.
        at(r, 0.4, 'select', 'back')
        ok(r.menu.is_open(), 'back in the grid keeps the menu')
        at(r, 0.4, 'down')
        eq((detail(r)), 'Cape', 'back to the rows')
        -- Up on the first row wraps to the last, down on the last back to the first.
        at(r, 0.4, 'tab_left', 'tab_right')
        eq((detail(r)), 'Chest tattoo', 'the first row')
        at(r, 0.4, 'up')
        eq((detail(r)), 'Navel piercing', 'up on the first row wraps to the last')
        at(r, 0.4, 'down')
        eq((detail(r)), 'Chest tattoo', 'down on the last row wraps to the first')
        -- The mouse: a click on a tab, on a row; a tile picked in the TileView.
        local tabs = r.kit.live(F.TAB)
        tabs[6].o.Button_Action.hover = true
        at(r, 0.4, 'click')
        tabs[6].o.Button_Action.hover = false
        eq((detail(r)), 'Hip tattoo', 'a click on the hips tab')
        local zones = r.kit.groups.closet_menu.zones
        zones[2].hover = true
        at(r, 0.4, 'click')
        zones[2].hover = false
        eq((detail(r)), 'Lower back tattoo', 'a click on row 2')
        at(r, 0.4, 'tab_left', 'tab_left')
        zones[6].hover = true
        at(r, 0.4, 'click')
        zones[6].hover = false
        eq((detail(r)), 'None', 'a click on a row of pieces goes into its grid')
        at(r, 0.4, 'back')
        grid(r):SetSelectedIndex(1)
        tick(r, 0.45)
        eq((detail(r)), 'Maid top', 'a tile picked by the mouse takes the focus')
        at(r, 0.45, 'left')
        eq((detail(r)), 'None', 'and the keys go on from it')
    end,

    preview_waits_250_ms_and_takes_the_last_focus = function()
        local r = rig()
        on_top(r)
        at(r, 0.1, 'right', 'right')
        tick(r, 0.3)
        eq(#r.previews, 0, 'not before 250 ms')
        at(r, 0.3, 'right')
        tick(r, 0.5)
        eq(#r.previews, 0, 'the timer starts again on each move')
        tick(r, 0.56)
        same(r.previews, {{{fit = KUNOICHI, slots = {'Chest'}}}}, 'the last focus worn')
        tick(r, 1.2)
        eq(#r.previews, 1, 'once')
        -- The worn tile again: nothing to wear.
        at(r, 1.2, 'left', 'right')
        tick(r, 1.5)
        eq(#r.previews, 1, 'the worn tile is not worn again')
        -- Leaving the grid before 250 ms wears nothing.
        at(r, 2, 'left')
        at(r, 2.1, 'back')
        tick(r, 2.5)
        eq(#r.previews, 1, 'left the grid')
    end,

    a_click_on_a_tile_previews_at_once = function()
        local r = rig()
        on_top(r)
        at(r, 0.6, 'click') -- Over the grid: no tab, chip or row under the mouse.
        grid(r):SetSelectedIndex(1)
        tick(r, 0.6)
        same(r.previews, {{{fit = MAID, slots = {'Chest'}}}}, 'the clicked tile is worn in the same tick')
        -- The click bind and Slate's selection can land a frame apart: a click the frame before counts too.
        at(r, 0.7, 'click')
        tick(r, 0.7)
        grid(r):SetSelectedIndex(2)
        tick(r, 0.71)
        same(r.previews[2], {{fit = KUNOICHI, slots = {'Chest'}}}, 'a click the frame before: at once')
    end,

    -- SB's grid may select a tile on hover or keyboard focus: with no click, the selection waits PREVIEW s as the
    -- keys do, so a tile passed over is never worn.
    a_selection_without_a_click_waits_250_ms = function()
        local r = rig()
        on_top(r)
        grid(r):SetSelectedIndex(1)
        tick(r, 0.6)
        eq((detail(r)), 'Maid top', 'the selected tile takes the focus')
        eq(#r.previews, 0, 'no click: not worn at once')
        grid(r):SetSelectedIndex(2) -- Passed over: the timer starts again.
        tick(r, 0.7)
        tick(r, 0.9)
        eq(#r.previews, 0, 'not before 250 ms')
        tick(r, 0.95)
        same(r.previews, {{{fit = KUNOICHI, slots = {'Chest'}}}}, 'the last tile worn after 250 ms')
        -- A click two frames before the selection is not this one's.
        at(r, 1, 'click')
        tick(r, 1) tick(r, 1.01)
        grid(r):SetSelectedIndex(1)
        tick(r, 1.02)
        eq(#r.previews, 1, 'an older click: the wait')
        tick(r, 1.3)
        eq(#r.previews, 2, 'worn after it')
    end,

    a_click_on_a_hint_runs_it = function()
        local r = rig()
        on_top(r)
        at(r, 0.5, 'right', 'right', 'right') -- Kunoichi top focused in the grid: Back, Wear, Whole outfit, Move.
        r.previews = {}
        local zones = r.kit.groups.closet_menu.zones
        local chips = {} -- The chip zones follow the 10 row zones, right to left from the menu's edge.
        for i = 1, 4 do chips[i] = zones[10 + i] end
        eq(chips[1].x, 2112 - 400, 'first chip place') eq(chips[1].y, 1990, 'chip row')
        chips[3].hover = true -- The third hint: Whole outfit (refresh).
        at(r, 0.6, 'click')
        chips[3].hover = false
        same(r.previews, {{{fit = KUNOICHI}}}, 'a click on Whole outfit wears the whole outfit')
        chips[4].hover = true -- Move: no word, nothing.
        at(r, 0.7, 'click')
        chips[4].hover = false
        eq(#r.previews, 1, 'a click on Move does nothing')
        chips[1].hover = true -- Back leaves the grid.
        at(r, 0.8, 'click')
        chips[1].hover = false
        eq(r.menu.is_open(), true, 'Back in the grid stays open')
        at(r, 0.8, 'click')
        eq(r.menu.is_open(), true, 'a click on no chip does nothing')
    end,

    a_click_on_a_chip_never_hits_a_row = function()
        -- The torso tab has 14 rows: chip zone 12 (Move, no word) must not read as row 12.
        local r = rig()
        r.menu.open()
        at(r, 0.1, 'tab_right', 'tab_right', 'tab_right')
        eq((detail(r)), 'Chest tattoo', 'the torso tab, row 1')
        local before = #r.previews
        local zones = r.kit.groups.closet_menu.zones
        zones[12].hover = true
        at(r, 0.6, 'click')
        zones[12].hover = false
        eq((detail(r)), 'Chest tattoo', 'a click on the Move chip keeps the focused row')
        eq(#r.previews, before, 'a click on the Move chip selects nothing')
    end,

    a_locked_tile_is_never_previewed = function()
        local r = rig({installed = function(fit) return fit ~= KUNOICHI end})
        on_top(r)
        at(r, 0.5, 'right', 'right', 'right')
        eq(grid(r).items[3].Purchased, false, 'Kunoichi top locked')
        local title, desc = detail(r)
        eq(title, 'Kunoichi top', 'locked tile detail')
        ok(desc:find(T.en.closet.row.locked:format('AiK'), 1, true), desc)
        tick(r, 1)
        at(r, 1, 'refresh', 'select')
        tick(r, 2)
        eq(#r.previews, 0, 'never previewed')
        at(r, 2, 'down')
        eq((detail(r)), 'Jacket', 'select went back to the rows')
        -- A soon row and a locked whole outfit: refresh wears nothing.
        at(r, 2, 'tab_left')
        at(r, 2, 'refresh')
        at(r, 2, 'tab_left', 'tab_left', 'refresh') -- Colour, then Full outfit: Kunoichi Shadow first by name.
        eq(#r.previews, 0, 'soon row, locked outfit')
        at(r, 2, 'down', 'refresh')
        same(r.previews, {{{fit = MAID}}}, 'the installed outfit is worn')
    end,

    -- installed loads an outfit's mesh on the game thread: the Full tab asks it for the rows in the window only.
    full_tab_loads_only_the_shown_outfits = function()
        local catalogue = {}
        for i = 1, 30 do
            local id = ('p%02d.suit'):format(i)
            catalogue[id] = {UniqueFitID = id, DisplayName = id, Slot = 'FullOutfit', File = '~mods\\P\\p.dekcns.json',
                Variants = {{Mesh = '/Game/P/' .. i .. '.' .. i, HiddenMats = {}, Materials = {}, Parameters = {}}},
                UserConfigs = {MaterialToggles = {}}}
        end
        Fits.use(catalogue)
        local good, why = pcall(function()
            local asked = {}
            local r = rig({installed = function(fit) asked[fit] = (asked[fit] or 0) + 1; return true end})
            r.menu.open()
            tick(r, 0.1)
            at(r, 0.2, 'down')
            tick(r, 0.3)
            local n = 0
            for _ in pairs(asked) do n = n + 1 end
            ok(n > 0 and n <= 11, ('outfits asked: %d of %d'):format(n, 32))
        end)
        Fits.use(nil)
        ok(good, why)
    end,

    none_tile_takes_the_slot_off = function()
        local r = rig({before = function(r) r.choices = {{fit = MAID}} end})
        on_top(r)
        at(r, 0.5, 'right')
        eq(grid(r):BP_GetSelectedItem(), grid(r).items[2], 'the worn Maid top focused')
        at(r, 0.5, 'left', 'select')
        local m = require('closet.ui.model').new({slots = require('closet.slots'), fits = Fits,
            installed = function() return true end})
        same(r.previews, {m.choose({{fit = MAID}}, 'Chest', nil)}, 'select wears the None tile at once')
        ok(m.worn(r.previews[1], 'Chest') == nil and m.worn(r.previews[1], 'Collar') == MAID, 'Top off, the rest on')
        at(r, 0.5, 'down')
        eq((detail(r)), 'Jacket', 'back to the rows')
        tick(r, 2)
        eq(#r.previews, 1, 'the timer was dropped')
    end,

    none_tile_on_the_only_piece_gives_the_open_look_back = function()
        local r = rig()
        on_top(r)
        at(r, 0.5, 'right', 'right', 'select')
        same(r.previews, {{{fit = MAID, slots = {'Chest'}}}}, 'Maid top worn on a bare look')
        at(r, 0.5, 'right', 'left', 'select')
        eq(r.reverted, 1, 'None on the only piece: the bare look the menu opened on')
        eq(#r.previews, 1, 'no empty preview')
        same(r.told, {}, 'no failed notice')
        tick(r, 1)
        ok(r.menu.is_open(), 'the revert does not close the menu')
        at(r, 1, 'back')
        eq(popups(r), 0, 'nothing changed since the open: no popup')
        all_gone(r)
    end,

    none_tile_on_the_only_piece_of_a_confirmed_look_previews_her_own_look = function()
        local r = rig({before = function(r) r.choices = {{fit = MAID, slots = {'Chest'}}} end})
        on_top(r)
        at(r, 0.5, 'right')
        eq(grid(r):BP_GetSelectedItem(), grid(r).items[2], 'the worn Maid top focused')
        at(r, 0.5, 'left', 'select')
        same(r.previews, {{}}, 'her own look previewed')
        eq(r.reverted, 0, 'no revert')
        same(r.told, {}, 'no failed notice')
        at(r, 0.5, 'back')
        eq(popups(r), 1, 'Back asks Keep this look?')
        ok(r.menu.is_open(), 'still open')
    end,

    refresh_wears_the_whole_outfit = function()
        local r = rig()
        on_top(r)
        at(r, 0.5, 'right', 'right', 'right', 'refresh')
        same(r.previews, {{{fit = KUNOICHI}}}, 'the focused tile outfit')
        tick(r, 2)
        eq(#r.previews, 1, 'no timer after it')
        -- In the rows: the worn tile's outfit.
        at(r, 2, 'back', 'refresh')
        same(r.previews[2], {{fit = KUNOICHI}}, 'the worn tile outfit in the rows')
        -- The Full tab: the row's outfit.
        at(r, 2, 'tab_left', 'tab_left', 'tab_left')
        local title = detail(r)
        eq(title, 'Kunoichi Shadow', 'the Full tab')
        at(r, 2, 'refresh', 'down', 'refresh')
        same(r.previews[3], {{fit = KUNOICHI}}, 'row 1')
        same(r.previews[4], {{fit = MAID}}, 'row 2')
    end,

    select_on_a_full_outfit_row_wears_it = function()
        local r = rig()
        on_top(r)
        -- The hint texts drawn now, right to left (the hints' order), the tab keys' unlabelled icons left out; icon:
        -- each hint's first icon by its text.
        local icon
        local function shown()
            local list, out = {}, {}
            icon = {}
            for _, h in ipairs(r.kit.live(F.HINT)) do
                local text, first
                for _, c in ipairs(h.o.calls) do
                    if c[1] == 'SetText' then text = c[2].text elseif c[1] == 'SetResourceAction' then first = c[2] end
                end
                if text ~= '' then list[#list + 1] = {x = h.x, text = text}; icon[text] = first end
            end
            table.sort(list, function(a, b) return a.x > b.x end)
            for i, h in ipairs(list) do out[i] = h.text end
            return out
        end
        local back, wear, whole, move = T.en.hint.back, T.en.closet.hints.wear, T.en.closet.hints.whole, T.en.hint.move
        same(shown(), {back, wear, move}, 'a row of pieces: Back, Wear, Move')
        at(r, 0.5, 'right')
        same(shown(), {back, wear, move}, 'the grid on None: Back, Wear, Move')
        at(r, 0.5, 'right')
        same(shown(), {back, wear, whole, move}, 'a piece tile: Back, Wear, Whole outfit (refresh), Move')
        eq(tostring(icon[whole]), 'UI_FaceButton_Top', 'refresh shows the top face button')
        at(r, 0.5, 'back', 'tab_left', 'tab_left', 'tab_left')
        eq((detail(r)), 'Kunoichi Shadow', 'the Full tab')
        same(shown(), {back, whole, move}, 'the Full tab: Back, Whole outfit, Move')
        at(r, 0.5, 'select')
        same(r.previews, {{{fit = KUNOICHI}}}, 'select wears the whole outfit')
        -- A click on the second row too.
        local zones = r.kit.groups.closet_menu.zones
        zones[2].hover = true
        at(r, 0.5, 'click')
        same(r.previews[2], {{fit = MAID}}, 'a click wears row 2')
    end,

    back_without_changes_closes = function()
        local r = rig()
        on_top(r)
        at(r, 0.5, 'right', 'back')
        ok(r.menu.is_open(), 'back in the grid')
        at(r, 0.5, 'back')
        all_gone(r)
        eq(r.reverted, 1, 'closed with a revert')
        for _, rec in ipairs(r.kit.made) do ok(rec.class ~= F.POPUP, 'no popup made') end
    end,

    back_with_changes_asks = function()
        local r = rig()
        on_top(r)
        at(r, 0.5, 'right', 'right', 'select')
        local refocused = r.kit.refocused
        at(r, 0.5, 'back')
        ok(r.menu.is_open(), 'still open')
        eq(popups(r), 1, 'the popup')
        local p = r.kit.live(F.POPUP)[1].o
        eq(p.TitleText.text, T.en.closet.popup.title, 'title')
        eq(p.DescText.text, T.en.closet.popup.desc, 'desc')
        eq(p.ButtonType, 3, 'Yes and No')
        eq(r.kit.refocused, refocused + 1, 'focus back to the kit')
        -- Other words do nothing while it asks.
        at(r, 0.5, 'down', 'tab_left', 'left', 'right', 'up')
        eq(#r.previews, 1, 'nothing worn')
        eq(popups(r), 1, 'still asking')
        eq(r.reverted + r.confirmed, 0, 'no answer')
    end,

    -- closet_key (main/keys.lua): closed, it opens; open, it is the Back of the rows level, from the grid too.
    closet_key_toggles_like_back = function()
        local r = rig()
        r.menu.toggle()
        ok(r.menu.is_open(), 'toggle opens')
        at(r, 0.05, 'tab_right', 'tab_right', 'tab_right', 'down', 'down', 'down', 'down', 'down', 'right', 'right')
        tick(r, 1)
        eq(#r.previews, 1, 'the focused tile previewed')
        r.menu.toggle()
        ok(r.menu.is_open(), 'still open')
        eq(popups(r), 1, 'a preview: toggle in the grid asks Keep this look?')
        eq(r.reverted + r.confirmed, 0, 'no answer')
        r.menu.toggle()
        eq(popups(r), 0, 'toggle on the popup is its Back')
        ok(r.menu.is_open(), 'open after the popup Back')
        -- A tile preview due when toggle leaves the grid: dropped, as the grid's Back drops it.
        r = rig()
        r.menu.toggle()
        at(r, 0.05, 'tab_right', 'tab_right', 'tab_right', 'down', 'down', 'down', 'down', 'down', 'right', 'right')
        tick(r, 1)
        at(r, 1.1, 'right')
        r.t = 1.2
        r.menu.toggle()
        eq(popups(r), 1, 'toggle with a tile due asks')
        r.menu.toggle()
        tick(r, 2)
        eq(#r.previews, 1, 'the tile left by toggle is not worn after the popup Back')
        -- No preview: toggle closes with a revert, no popup.
        r = rig()
        r.menu.toggle()
        at(r, 0.5, 'right')
        r.menu.toggle()
        eq(r.reverted, 1, 'closed with a revert')
        for _, rec in ipairs(r.kit.made) do ok(rec.class ~= F.POPUP, 'no popup made') end
        all_gone(r)
    end,

    -- The pad chord LB + D-pad Left (main/input.lua's closet): LB's press reaches the open menu first as tab_left;
    -- frames later D-pad Left's press comes as left, then the toggle, in one frame (native pad.h: kCloset after its
    -- kLeft). The close leaves the tab, the row and the focus where they were; Q then F1 (closet_key) keeps Q's move.
    the_pad_chord_that_closes_keeps_the_tab = function()
        local r = rig()
        r.menu.open()
        at(r, 0.4, 'tab_right', 'tab_right', 'tab_right', 'down', 'down')
        local title = detail(r)
        local function chord(t)
            at(r, t, 'tab_left') -- LB down.
            tick(r, t + 0.1) -- LB held.
            r.t = t + 0.2
            r.menu.nav('left') -- D-pad Left: left, then closet, before the next frame.
            r.menu.toggle()
        end
        chord(0.5)
        all_gone(r)
        r.t = 1
        r.menu.open()
        eq((detail(r)), title, 'the same tab and row after a reopen')
        ok(F.called(r.kit.live(F.TAB)[4].o, 'FocusTabButton'), 'the torso tab focused')
        -- Again from the rows (up wraps to the last row, so the tab row is the mouse's and Q / E's): the chord keeps
        -- the tab and the row.
        chord(1.5)
        all_gone(r)
        r.t = 2
        r.menu.open()
        eq((detail(r)), title, 'the torso tab again, the same row')
        at(r, 2.1, 'up', 'up', 'up', 'down', 'down', 'down')
        eq((detail(r)), title, 'three up and three down across the wrap: the same row')
        at(r, 2.2, 'tab_left', 'tab_right')
        eq((detail(r)), 'Chest tattoo', 'a tab change starts on its first row')
        -- In the grid with a preview: the chord's Back asks Keep this look? on the same tab and tile.
        at(r, 2.4, 'down', 'down', 'down', 'down', 'down', 'right', 'right', 'select', 'right')
        eq((detail(r)), 'Maid top', 'on the worn tile')
        chord(2.5)
        eq(popups(r), 1, 'the chord asks')
        at(r, 2.7, 'back')
        eq((detail(r)), 'Top', 'the popup Back: the Top row of the torso tab')
        -- Q, then F1 a frame later: the tab Q chose stays.
        at(r, 3, 'tab_left')
        tick(r, 3.1)
        r.menu.toggle()
        at(r, 3.1, 'no')
        all_gone(r)
        r.t = 4
        r.menu.open()
        eq((detail(r)), 'Face', 'Q then F1: the head tab')
        -- left and F1 in other frames: no chord either.
        at(r, 4.4, 'tab_right', 'tab_left')
        tick(r, 4.5)
        at(r, 4.5, 'left')
        tick(r, 4.6)
        r.menu.toggle()
        all_gone(r)
        r.t = 5
        r.menu.open()
        eq((detail(r)), 'Face', 'Q, left, then F1: the head tab')
        -- LB and D-pad Left pressed in one poll: left, tab_left, then closet (pad.h's event order).
        at(r, 5.4, 'tab_right')
        at(r, 5.5, 'left', 'tab_left')
        r.menu.toggle()
        all_gone(r)
        r.t = 6
        r.menu.open()
        eq((detail(r)), 'Chest tattoo', 'one poll: the torso tab kept')
        -- On a Colour row the chord's left steps the role's swatch (colour.step, saved at once): the close steps it
        -- back, so the palette and coop-closet-colour.txt stay as they were. From the Head tab, LB lands on the Colour
        -- tab's Primary row: the frames-later left steps the swatch.
        local col = fake_colour()
        r = rig({colour = col})
        r.menu.open()
        at(r, 0.4, 'tab_right', 'tab_right') -- Full, Colour, Head.
        title = detail(r)
        chord(0.5)
        all_gone(r)
        eq(#col.steps, 2, 'from the Head tab: the left stepped the swatch, the close stepped it back')
        eq(col.get('primary'), 'off', 'from the Head tab: the palette as it was')
        r.t = 1
        r.menu.open()
        eq((detail(r)), title, 'the Head tab kept')
        -- On the Colour tab, both pressed in one poll: left, tab_left, then closet.
        col.palette.primary = 'crimson'
        at(r, 1.4, 'tab_left') -- Head, Colour.
        tick(r, 1.45)
        eq((detail(r)), T.en.closet.colour.roles.primary, 'on the Primary row')
        at(r, 1.5, 'left', 'tab_left')
        r.menu.toggle()
        all_gone(r)
        eq(col.get('primary'), 'crimson', 'one poll on the Colour tab: the palette as it was')
        r.t = 2
        r.menu.open()
        eq((detail(r)), T.en.closet.colour.roles.primary, 'the Colour tab kept')
        -- left, then F1 a frame later: no chord, the step stays.
        at(r, 2.4, 'left')
        tick(r, 2.5)
        r.menu.toggle()
        all_gone(r)
        eq(col.get('primary'), 'gold', 'left, then F1: the swatch before crimson')
        -- On a shape row of the Body tab, both pressed in one poll: the chord's left stepped the value down (saved at
        -- once); the close sets it back, so the shape and coop-closet-shape.txt stay as they were.
        local sh = fake_shape({'Butt'})
        sh.values.Butt = 50
        r = rig({shape = sh})
        r.menu.open()
        at(r, 0.4, 'tab_left', 'tab_left', 'down') -- Weapon, Body; the Butt row.
        eq((detail(r)), 'Butt', 'on the Butt row')
        at(r, 0.5, 'left', 'tab_left')
        r.menu.toggle()
        all_gone(r)
        eq(sh.get('Butt'), 50, 'one poll on a shape row: the value as it was')
        r.t = 1
        r.menu.open()
        eq((detail(r)), 'Butt', 'the Butt row kept')
        -- left, then F1 a frame later: no chord, the step stays.
        at(r, 1.4, 'left')
        tick(r, 1.5)
        r.menu.toggle()
        all_gone(r)
        eq(sh.get('Butt'), 40, 'left, then F1: one step down')
    end,

    popup_yes_keeps_and_saves = function()
        local r = rig()
        on_top(r)
        at(r, 0.5, 'right', 'right', 'select', 'back', 'select')
        eq(r.confirmed, 1, 'confirmed')
        eq(r.reverted, 0, 'not reverted')
        same(r.told, {T.en.closet.saved}, 'saved notice')
        all_gone(r)
        -- The yes word too.
        r.t = 1
        r.menu.open()
        at(r, 1.5, 'right', 'right', 'select', 'back', 'yes')
        eq(r.confirmed, 2, 'yes')
        all_gone(r)
    end,

    popup_no_reverts = function()
        local r = rig()
        on_top(r)
        at(r, 0.5, 'right', 'right', 'select', 'back', 'no')
        eq(r.reverted, 1, 'reverted')
        eq(r.confirmed, 0, 'not confirmed')
        same(r.told, {}, 'no notice')
        all_gone(r)
        -- refresh (F, the pad's Y) is No for the keyboard and the pad: select is Yes and back stays.
        r.t = 1
        r.menu.open()
        at(r, 1.5, 'right', 'right', 'select', 'back', 'refresh')
        eq(r.reverted, 2, 'refresh reverts')
        eq(r.confirmed, 0, 'refresh does not confirm')
        all_gone(r)
    end,

    popup_back_stays = function()
        local r = rig()
        on_top(r)
        at(r, 0.5, 'right', 'right', 'select', 'back', 'back')
        ok(r.menu.is_open(), 'the menu stays')
        eq(popups(r), 0, 'the popup is gone')
        eq(r.reverted + r.confirmed, 0, 'no answer')
        at(r, 0.5, 'down')
        eq((detail(r)), 'Jacket', 'the rows take the keys again')
        at(r, 0.5, 'back')
        eq(popups(r), 1, 'back asks again')
        at(r, 0.5, 'select')
        eq(r.confirmed, 1, 'then yes')
        all_gone(r)
    end,

    popup_answers_by_mouse = function()
        for _, case in ipairs({{'Button_Positive', 1, 0}, {'Button_Negative', 0, 1}}) do
            local r = rig()
            on_top(r)
            at(r, 0.5, 'right', 'right', 'select', 'back', 'click')
            eq(popups(r), 1, 'a click on no button: nothing')
            r.kit.live(F.POPUP)[1].o[case[1]].hover = true
            at(r, 0.5, 'click')
            eq(r.confirmed, case[2], case[1] .. ' confirmed')
            eq(r.reverted, case[3], case[1] .. ' reverted')
            all_gone(r)
        end
    end,

    -- Reset Stellar Closet, the Full tab's last row: the game's Yes/No popup; Yes runs coop closet off and closes the
    -- menu without the Keep popup or a revert, so nothing of the closet stays on EVE for its watchdog.
    reset_row_clears_and_stops_the_watchdog = function()
        local col, sh = fake_colour(), fake_shape({'Butt'})
        col.palette.primary = 'crimson'
        sh.values.Butt = 50
        local r = rig({colour = col, shape = sh, before = function(r) r.choices = {{fit = MAID}} end})
        r.menu.open()
        at(r, 0.5, 'down', 'down')
        local title, desc = detail(r)
        eq(title, T.en.closet.row.reset, 'the last row of the Full tab')
        eq(desc, T.en.closet.popup.reset_desc, 'its detail')
        at(r, 0.5, 'refresh')
        eq(#r.previews, 0, 'refresh wears nothing on it')
        -- Select asks; No and Back leave the menu and the look as they are.
        at(r, 0.5, 'select')
        eq(popups(r), 1, 'the popup')
        local p = r.kit.live(F.POPUP)[1].o
        eq(p.TitleText.text, T.en.closet.popup.reset_title, 'title') eq(p.DescText.text, T.en.closet.popup.reset_desc)
        eq(p.ButtonType, 3, 'Yes and No')
        at(r, 0.5, 'no')
        eq(popups(r), 0, 'No: the popup goes') ok(r.menu.is_open(), 'No: the menu stays')
        at(r, 0.5, 'select', 'back')
        eq(popups(r), 0, 'Back: the popup goes') ok(r.menu.is_open(), 'Back: the menu stays')
        eq(r.offs, 0, 'nothing reset yet') eq(col.offs, 0, 'the palette kept') eq(sh.offs, 0, 'the shape kept')
        -- A preview, then Yes.
        at(r, 0.5, 'up', 'refresh', 'down', 'select', 'select')
        same(r.previews, {{{fit = MAID}}}, 'previewed before the reset (row 2 by name)')
        eq(r.offs, 1, 'coop closet off ran')
        eq(col.offs, 1, 'the palette cleared (coop-closet-colour.txt)') eq(col.get('primary'), 'off')
        eq(sh.offs, 1, 'the shape cleared (coop-closet-shape.txt)') eq(sh.get('Butt'), 0)
        eq(r.reverted + r.confirmed, 0, 'no revert, no confirm')
        same(r.told, {T.en.closet.reset_done}, 'the notice')
        for _, rec in ipairs(r.kit.made) do
            if rec.class == F.POPUP then eq(rec.o.TitleText.text, T.en.closet.popup.reset_title, 'no Keep popup') end
        end
        has(r.log, 'closed (reset)', 'log')
        eq(r.kit.sounds[#r.kit.sounds], 'close', 'the close sound')
        all_gone(r)
        tick(r, 2) tick(r, 3)
        eq(r.reverted, 0, 'no revert owed after it')
    end,

    -- A held up or down key (the native read: 1 up, 2 down) repeats its move after REPEAT_DELAY s, then every
    -- REPEAT_EVERY s, as the pad's D-pad does; the press itself moves once, from the key's bind. No read: no repeat.
    held_keys_repeat_the_move = function()
        local Menu = require('closet.ui.menu')
        local r = rig()
        r.menu.open()
        tick(r, 0.5)
        local first = detail(r)
        r.held = 2
        at(r, 0.5, 'down') -- The bind's press.
        tick(r, 0.5)
        local second = detail(r)
        ok(second ~= first, 'the press moved once')
        tick(r, 0.5 + Menu.REPEAT_DELAY - 0.01)
        eq((detail(r)), second, 'no repeat before the delay')
        tick(r, 0.5 + Menu.REPEAT_DELAY)
        ok(detail(r) ~= second, 'the first repeat after the delay')
        local third = detail(r)
        tick(r, 0.5 + Menu.REPEAT_DELAY + Menu.REPEAT_EVERY / 2)
        eq((detail(r)), third, 'not again before REPEAT_EVERY')
        r.held = 1
        tick(r, 0.5 + Menu.REPEAT_DELAY + Menu.REPEAT_EVERY)
        eq((detail(r)), third, 'a new key starts its own delay')
        tick(r, 1 + 2 * Menu.REPEAT_DELAY)
        eq((detail(r)), second, 'up held repeats up')
        r.held = 0
        tick(r, 3)
        eq((detail(r)), second, 'let go: no repeat')
        r.held = nil
        tick(r, 4)
        eq((detail(r)), second, 'no read: no repeat')
    end,

    -- Clear preview pictures, after the outfits: Select asks with the game's Yes/No popup. No keeps them; Yes
    -- deletes them (closet/thumbs.lua's clear), tells it and re-reads which pictures are there; a run going refuses.
    the_clear_row_asks_then_deletes_the_pictures = function()
        local th = {cleared = 0, answer = {true}}
        th.running = function() return false end
        th.run = function() return true end
        th.clear = function() th.cleared = th.cleared + 1; return table.unpack(th.answer) end
        local r = rig({thumbs = th})
        r.menu.open()
        at(r, 0.5, 'down', 'down')
        local title, desc = detail(r)
        eq(title, T.en.closet.row.clear_thumbs, 'the row after the outfits')
        eq(desc, T.en.closet.row.clear_thumbs_desc, 'its detail')
        at(r, 0.6, 'select')
        eq(popups(r), 1, 'Clear preview pictures? asks')
        eq(th.cleared, 0, 'nothing deleted yet')
        at(r, 0.7, 'no')
        eq(popups(r), 0, 'No: the popup goes') eq(th.cleared, 0, 'kept')
        at(r, 0.8, 'select', 'yes')
        eq(th.cleared, 1, 'Yes: deleted') eq(popups(r), 0, 'the popup goes')
        eq(r.told[#r.told], T.en.closet.thumbs.cleared, 'told') ok(r.menu.is_open(), 'the menu stays open')
        th.answer = {false, 'closet thumbs: running'}
        th.running = function() return true end
        at(r, 0.9, 'select', 'yes')
        eq(r.told[#r.told], T.en.closet.thumbs.busy, 'a run going: told to wait')
        has(r.log, 'closet thumbs: running', 'its reason logged')
        th.answer = {false, 'closet thumbs: the mod folder is not known'}
        th.running = function() return false end
        at(r, 1.0, 'select', 'yes')
        eq(r.told[#r.told], T.en.closet.thumbs.failed, 'no run going: told it failed')
        has(r.log, 'closet thumbs: the mod folder is not known', 'that reason logged')
    end,

    the_detail_names_the_origin = function()
        local custom = T.en.closet.origin.custom:format('AiK')
        eq(custom, 'Custom: AiK', 'the custom origin names the pack')
        local r = rig()
        r.menu.open()
        local title, desc = detail(r)
        ok(desc:find(custom, 1, true), 'a Full outfit row: ' .. desc)
        eq(badge(r), 'custom', 'the custom badge beside the origin line')
        -- The Body tab's Body row: None (the body rule) then each outfit with skin, named after the outfit.
        at(r, 0.5, 'tab_left', 'tab_left') -- Full, Weapon, Body.
        eq((detail(r)), T.en.closet.slots.BaseBody, 'the Body row first')
        eq(badge(r), nil, 'no origin line, no badge')
        at(r, 0.5, 'right')
        eq((detail(r)), 'None', 'the None tile') eq(badge(r), nil, 'the None tile has no origin')
        at(r, 0.5, 'right')
        title, desc = detail(r)
        eq(title, 'Ocean Maid', 'a body tile')
        ok(desc:find('Slot: Body', 1, true) and desc:find(custom, 1, true), 'a body tile: ' .. desc)
        eq(badge(r), 'custom', 'a tile of a custom outfit')
        at(r, 0.5, 'select')
        same(r.previews, {{{fit = MAID, slots = {'BaseBody'}}}}, 'the body picked')
        local rows = r.kit.live(F.OPTION)
        table.sort(rows, function(a, b) return a.y < b.y end)
        eq(rows[1].o.Text_ItemValue.text, 'Ocean Maid', 'the Body row shows the picked body')
        title, desc = detail(r)
        ok(desc:find('Outfit: Ocean Maid', 1, true) and desc:find(custom, 1, true), 'the worn body: ' .. desc)
        eq(badge(r), 'custom', 'the worn piece of a row')
        -- Shift Up's own suits are Original, worn whole only: their Full outfit row names it.
        eq(Fits.origin(MAID), 'custom', 'custom by default')
        Fits.BY_ID[MAID].Origin = 'original'
        local good, why = pcall(function()
            eq(Fits.origin(MAID), 'original')
            -- Kunoichi Shadow, the Original header, then Ocean Maid under it.
            at(r, 0.5, 'tab_right', 'tab_right', 'down')
            eq((detail(r)), T.en.closet.original, 'the Original header after the Custom suits')
            eq(badge(r), nil, 'the header has no origin')
            local n = #r.previews
            at(r, 0.5, 'select', 'refresh')
            eq(#r.previews, n, 'the header wears nothing')
            at(r, 0.5, 'down')
            title, desc = detail(r)
            eq(title, 'Ocean Maid', 'the Full outfit row')
            ok(desc:find(T.en.closet.origin.original, 1, true) and not desc:find('Custom', 1, true), desc)
            eq(badge(r), 'original', 'the original badge')
            at(r, 0.5, 'down')
            eq((detail(r)), T.en.closet.row.reset, 'the Reset row') eq(badge(r), nil, 'the Reset row has no origin')
        end)
        Fits.BY_ID[MAID].Origin = nil
        ok(good, why)
    end,

    tiles_show_their_slot_glyph = function()
        -- A tile's IconAssetPath is the object path of its glyph's imported texture: None's on the None tile, else
        -- its slot's (closet/slots.lua's glyph). The Top row (Chest): None, Maid top, Kunoichi top.
        local r = rig()
        on_top(r)
        eq(Slots.glyph('Chest'), 'top', 'the Top row glyph')
        local tv = grid(r)
        eq(#tv.items, 3, 'tiles')
        eq(tv.items[1].IconAssetPath, F.path('none'), 'None')
        for i = 2, 3 do eq(tv.items[i].IconAssetPath, F.path('top'), 'tile ' .. i) end
        -- The Jacket row (Outerwear) below it: its own glyph.
        at(r, 0.5, 'down')
        eq((detail(r)), 'Jacket', 'the Jacket row')
        eq(Slots.glyph('Outerwear'), 'jacket', 'the Jacket row glyph')
        tv = grid(r)
        ok(#tv.items > 1, 'jacket tiles')
        eq(tv.items[1].IconAssetPath, F.path('none'), 'None again')
        for i = 2, #tv.items do eq(tv.items[i].IconAssetPath, F.path('jacket'), 'jacket tile ' .. i) end
    end,

    glyphs_are_imported_once_and_kept = function()
        -- ImportFileAsTexture2D once a glyph (closet/ui/icons/<glyph>.png beside view.lua) as it is first drawn; a
        -- hidden kit image of the group holds each texture, so the engine keeps it while the menu shows.
        local from = #F.imports + 1
        local r = rig()
        on_top(r)
        -- The Full tab's outfit tile (the Full outfit glyph, no picture cached), its badge, then the torso tab's.
        same(F.imported(from), {'full_outfit', 'custom', 'none', 'bra', 'top'}, 'imported as first drawn')
        -- package.searchpath writes the folder with the system's separator.
        local file = F.imports[from + 2]
        ok(file:find('^mod/StellarCoop/Scripts/closet[\\/]ui[\\/]icons[\\/]none%.png$'), file)
        same(held(r), {'bra', 'custom', 'full_outfit', 'none', 'top'}, 'held')
        at(r, 0.5, 'up', 'down', 'up', 'down')
        r.menu.close()
        r.menu.open()
        eq((detail(r)), 'Top', 'the Top row again')
        same(F.imported(from), {'full_outfit', 'custom', 'none', 'bra', 'top'}, 'kept: never imported again')
        -- A root built again (a map change) has new holders; a texture the engine freed meanwhile is imported again,
        -- the others are held by the new build as they are drawn.
        r.menu.close()
        F.made.top.valid = false
        r.kit.groups.closet_menu.view, r.kit.groups.closet_menu.images = nil, {}
        r.menu.open()
        same(F.imported(from), {'full_outfit', 'custom', 'none', 'bra', 'top', 'top'}, 'only the freed one again')
        eq(grid(r).items[2].IconAssetPath, F.path('top'), 'the tiles name the new texture')
        same(held(r), {'none', 'top'}, 'held by the new build')
        at(r, 0.5, 'up')
        same(held(r), {'bra', 'none', 'top'}, 'the Bra glyph held again, not imported')
        same(F.imported(from), {'full_outfit', 'custom', 'none', 'bra', 'top', 'top'}, 'no more imports')
    end,

    a_refused_glyph_shows_the_game_icon = function()
        -- An import that gives nothing: its tiles keep the grid slot's own icon, said once, never tried again.
        local from = #F.imports + 1
        F.refuse.top = true
        local r = rig()
        local good, why = pcall(function()
            on_top(r)
            local tv = grid(r)
            eq(tv.items[1].IconAssetPath, F.path('none'), 'None has its glyph')
            eq(tv.items[2].IconAssetPath, F.ICON, 'the game icon instead')
            at(r, 0.5, 'up', 'down')
            same(F.imported(from), {'full_outfit', 'custom', 'none', 'bra', 'top'}, 'not tried again')
            local said = 0
            for _, line in ipairs(r.log) do if line:find('glyph top', 1, true) then said = said + 1 end end
            eq(said, 1, 'said once')
        end)
        F.refuse.top = nil
        ok(good, why)
    end,

    a_glyph_waits_for_the_player_controller = function()
        -- No player controller (a map loads): the game icon meanwhile, the import at a later draw.
        local from = #F.imports + 1
        package.loaded.UEHelpers.GetPlayerController = function() return nil end
        local r = rig()
        local good, why = pcall(function()
            on_top(r)
            eq(grid(r).items[2].IconAssetPath, F.ICON, 'the game icon meanwhile')
            same(F.imported(from), {}, 'nothing imported')
        end)
        package.loaded.UEHelpers.GetPlayerController = function() return F.pc end
        ok(good, why)
        at(r, 0.5, 'up', 'down')
        eq(grid(r).items[2].IconAssetPath, F.path('top'), 'imported at a later draw')
    end,

    a_tile_without_its_glyph_gets_it_on_the_tile = function()
        -- The path works (the slot's LoadAsset_Blocking finds the texture): a look at the shown tiles each CHECK s
        -- after a fill until one finds them all right, then none until the next fill.
        local View = require('closet.ui.view')
        eq(View.CHECK, 0.25, 'CHECK')
        local r = rig()
        on_top(r)
        local tv = grid(r)
        tv.hidden = true -- Slate builds the entries on a later frame.
        tick(r, 1)
        eq(tv.displayed, 1, 'a look after the fill')
        tv.hidden = false
        tick(r, 1.1)
        eq(tv.displayed, 1, 'not before CHECK s')
        tick(r, 1.25)
        eq(tv.displayed, 2, 'a look CHECK s later')
        for _, e in pairs(tv.entries) do eq(#e.Image_Icon.set, 0, 'nothing set on a right tile') end
        tick(r, 2)
        eq(tv.displayed, 2, 'no look once every shown tile was right')
        at(r, 2, 'down')
        tick(r, 3)
        eq(tv.displayed, 3, 'a fill looks again')
        -- The path fails: each shown tile gets its glyph on its Image_Icon (SetBrushFromTexture, no size match),
        -- said once; from then on every look sets the tiles still wrong.
        r = rig()
        on_top(r)
        tv = grid(r)
        tv.path_fails = true
        tick(r, 1)
        local n = 0
        for _, e in pairs(tv.entries) do
            n = n + 1
            local want = e.Data.Index == 0 and F.made.none or F.made.top
            same(e.Image_Icon.set, {{want, false}}, 'set on tile ' .. e.Data.Index)
        end
        eq(n, 3, 'three tiles shown')
        tick(r, 1.25)
        tick(r, 1.5)
        eq(tv.displayed, 3, 'it keeps looking')
        for _, e in pairs(tv.entries) do eq(#e.Image_Icon.set, 1, 'set once while it stays right') end
        local said = 0
        for _, line in ipairs(r.log) do if line:find('SetBrushFromTexture', 1, true) then said = said + 1 end end
        eq(said, 1, 'said once')
        -- A grid with no glyph to show (the Reset row's, empty): never looked at.
        r = rig()
        r.menu.open()
        at(r, 0.05, 'down', 'down')
        eq(#grid(r).items, 0, 'the Reset row has no tile')
        tick(r, 1)
        tick(r, 2)
        eq(grid(r).displayed, 0, 'no look at a grid without glyphs')
    end,

    tiles_show_the_picture_then_the_image_then_the_glyph = function()
        -- Each tile shows its piece's cached picture (closet/thumbs.lua's file, imported once), else its outfit's
        -- Image when that loads as a Texture2D, else its slot's glyph.
        local Thumbs = require('closet.thumbs')
        local exists = Thumbs.fs.exists
        local files = {[Thumbs.file('F', MAID, 'Chest')] = true}
        Thumbs.fs.exists = function(p) return files[p] == true end
        F.textures[Fits.get(KUNOICHI).Image] = true
        local good, why = pcall(function()
            local r = rig({folder = 'F'})
            on_top(r)
            local tv = grid(r)
            eq(tv.items[1].IconAssetPath, F.path('none'), 'None: its glyph')
            eq(tv.items[2].IconAssetPath, F.path('Chest'), 'Ocean Maid\'s top: its picture')
            eq(F.made.Chest.file, Thumbs.file('F', MAID, 'Chest'), 'imported from the cache')
            eq(tv.items[3].IconAssetPath, Fits.get(KUNOICHI).Image, 'Kunoichi Shadow\'s top: its outfit\'s Image')
            -- A hidden holder of the group keeps the imported picture, so the engine does not free it.
            local kept = false
            for _, i in ipairs(images(r, 1)) do
                eq(i.shown, false, 'a holder is hidden')
                kept = kept or i.texture == F.made.Chest
            end
            ok(kept, 'the picture held')
            -- No picture, an Image that is no texture: the glyph, said once.
            F.textures[Fits.get(KUNOICHI).Image] = nil
            files = {}
            r = rig({folder = 'F'})
            on_top(r)
            tv = grid(r)
            eq(tv.items[2].IconAssetPath, F.path('top'), 'Ocean Maid: no picture, no texture: the glyph')
            eq(tv.items[3].IconAssetPath, F.path('top'), 'Kunoichi Shadow: the glyph')
            at(r, 0.5, 'up', 'down')
            local said = 0
            for _, line in ipairs(r.log) do if line:find(Fits.get(KUNOICHI).Image, 1, true) then said = said + 1 end end
            eq(said, 1, 'said once')
            -- An Image that is no object path (a pack's template text) is never looked up.
            local image = Fits.get(MAID).Image
            Fits.get(MAID).Image = '{SoftReferenceToYourOutfitIcon}'
            local looked = false
            local find = StaticFindObject
            StaticFindObject = function(p) looked = looked or p == Fits.get(MAID).Image; return find(p) end
            r = rig({folder = 'F'})
            on_top(r)
            StaticFindObject = find
            Fits.get(MAID).Image = image
            eq(looked, false, 'not looked up')
            eq(grid(r).items[2].IconAssetPath, F.path('top'), 'the glyph')
        end)
        Thumbs.fs.exists = exists
        F.textures = {}
        ok(good, why)
    end,

    a_full_outfit_row_shows_its_whole_picture = function()
        -- The Full tab's outfit row shows one tile: its outfit's full.png when cached, else its Image, else the Full
        -- outfit glyph. The Reset row shows none.
        local Thumbs = require('closet.thumbs')
        local exists = Thumbs.fs.exists
        Thumbs.fs.exists = function(p) return p == Thumbs.file('F', MAID, Thumbs.FULL) end
        local good, why = pcall(function()
            local r = rig({folder = 'F'})
            r.menu.open()
            local tv = grid(r)
            eq(#tv.items, 1, 'one tile')
            eq(tv.items[1].ItemName.text, 'Kunoichi Shadow', 'the first outfit by name')
            eq(tv.items[1].IconAssetPath, F.path('full_outfit'), 'no picture, no texture: the glyph')
            local function preview()
                for _, i in ipairs(r.kit.groups.closet_menu.images) do
                    if i.h == 820 and i.w == 656 then return i end
                end
            end
            ok(preview() and not preview().shown, 'no picture: no preview')
            at(r, 0.05, 'down')
            eq((detail(r)), 'Ocean Maid', 'the next outfit')
            eq(#grid(r).items, 0, 'a picture: no tile')
            ok(preview().shown and preview().texture, 'its whole picture large, above the detail')
            eq(F.made.full.file, Thumbs.file('F', MAID, 'full'), 'from full.png')
            same({preview().x, preview().y}, {1308, 300}, 'centred between the detail panel\'s left and the edge')
            at(r, 0.05, 'down')
            eq(#grid(r).items, 0, 'the Reset row: no tile')
            -- Select on an outfit row still wears it whole (the tile is only its picture).
            at(r, 0.5, 'up', 'select')
            same(r.previews[#r.previews], {{fit = MAID}}, 'worn whole')
        end)
        Thumbs.fs.exists = exists
        ok(good, why)
    end,

    -- Preview picture: the camera row's last chip (P on the keyboard; on a pad SB's View glyph, held), and the word
    -- picture, take the one whole outfit EVE wears as the screen shows her (thumbs.snap with the camera's shot), tell
    -- it and show it; with pieces or nothing worn they tell why; a failed snap tells it failed.
    preview_picture_takes_the_worn_outfit = function()
        local Thumbs = require('closet.thumbs')
        local exists = Thumbs.fs.exists
        local files = {}
        Thumbs.fs.exists = function(p) return files[p] == true end
        local good, why = pcall(function()
            local snaps, answer = {}, {true}
            local th = {running = function() return false end, clear = function() return true end}
            th.snap = function(fit, shot)
                snaps[#snaps + 1] = {fit, shot}
                if answer[1] then files[Thumbs.file('F', fit, Thumbs.FULL)] = true end
                return table.unpack(answer)
            end
            local r = rig({folder = 'F', thumbs = th})
            r.menu.open()
            local P = T.en.closet.picture
            r.choices = {{fit = MAID}}
            at(r, 0.5, 'picture')
            eq(snaps[1][1], MAID, 'the worn whole outfit') eq(r.told[#r.told], P.saved:format('Ocean Maid'), 'told')
            at(r, 0.6, 'down')
            eq((detail(r)), 'Ocean Maid', 'its row')
            eq(#grid(r).items, 0, 'its new picture in place of the tile')
            r.choices = {{fit = MAID, slots = {'Chest'}}}
            at(r, 0.7, 'picture')
            eq(#snaps, 1, 'pieces: no picture') eq(r.told[#r.told], P.none, 'told why')
            r.choices = nil
            at(r, 0.8, 'picture')
            eq(r.told[#r.told], P.none, 'nothing worn: told why')
            r.choices, answer = {{fit = MAID}}, {false, 'closet thumbs: no closet camera'}
            at(r, 0.9, 'picture')
            eq(r.told[#r.told], P.failed, 'a failed snap: told') has(r.log, 'no closet camera', 'its reason logged')
        end)
        Thumbs.fs.exists = exists
        ok(good, why)
    end,

    the_menu_reads_the_pictures_again_at_each_open = function()
        -- A picture made while the menu was closed shows at the next open; a picture made again is imported again.
        local Thumbs = require('closet.thumbs')
        local exists = Thumbs.fs.exists
        local files = {}
        Thumbs.fs.exists = function(p) return files[p] == true end
        local good, why = pcall(function()
            local r = rig({folder = 'F'})
            on_top(r)
            eq(grid(r).items[2].IconAssetPath, F.path('top'), 'no picture yet: the glyph')
            files[Thumbs.file('F', MAID, 'Chest')] = true
            at(r, 0.5, 'up', 'down')
            eq(grid(r).items[2].IconAssetPath, F.path('top'), 'not read again while open')
            r.menu.close()
            r.menu.open()
            eq((detail(r)), 'Top', 'the Top row again')
            local first = F.path('Chest')
            eq(grid(r).items[2].IconAssetPath, first, 'the picture at the next open')
            r.menu.close()
            r.menu.open()
            ok(grid(r).items[2].IconAssetPath ~= first, 'imported again at the next open')
            eq(grid(r).items[2].IconAssetPath, F.path('Chest'), 'the new import')
        end)
        Thumbs.fs.exists = exists
        ok(good, why)
    end,

    switched_and_clips_are_told = function()
        local r = rig()
        local plan = {switched = KUNOICHI, clips = {'Calf', 'Foot'}}
        local preview = r.dress.preview
        r.dress.preview = function(c) preview(c); return true, 'closet: previewing', plan end
        on_top(r)
        at(r, 0.5, 'right', 'right', 'select')
        same(r.told, {T.en.closet.switched:format('Kunoichi Shadow'), T.en.closet.clips:format('Calves, Feet')},
            'the switch and the clipping regions')
        at(r, 0.5, 'right', 'right', 'select')
        eq(#r.previews, 2, 'a second preview')
        eq(#r.told, 2, 'the same switch is told once')
        plan = {}
        at(r, 0.5, 'right', 'left', 'select')
        eq(#r.told, 2, 'no switch: nothing told')
        plan = {switched = KUNOICHI}
        at(r, 0.5, 'right', 'right', 'select')
        eq(#r.previews, 4, 'a fourth preview')
        same(r.told[3], T.en.closet.switched:format('Kunoichi Shadow'), 'the switch again: told again')
    end,

    -- The chat feed draws under the closet's shade: the switch and clips show in the menu itself, under the rows, as
    -- long as the look on EVE has them; the Body row names the body in use.
    the_menu_shows_the_body_in_use_and_its_notice = function()
        local r = rig()
        local preview = r.dress.preview
        r.dress.preview = function(c) preview(c); r.plan = r.next; return true, 'closet: previewing', r.plan end
        r.menu.open()
        local text = r.kit.groups.closet_menu.texts[1]
        ok(text and text.x >= 0 and text.x + text.o.wrap <= 2112, 'the notice inside the menu, left of x 2112')
        eq(text.s, '', 'no look: no notice')
        local function body_row()
            at(r, r.t, 'tab_left', 'tab_left') -- The Body tab, from the Full tab (Weapon, Body).
            eq((detail(r)), T.en.closet.slots.BaseBody, 'the Body row')
            local rows = r.kit.live(F.OPTION)
            table.sort(rows, function(a, b) return a.y < b.y end)
            local value = rows[1].o.Text_ItemValue.text
            at(r, r.t, 'tab_right', 'tab_right') -- Back on the Full tab.
            return value
        end
        eq(body_row(), T.en.closet.row.none, 'no look: None')
        -- Ocean Maid whole, with a plan that switched the body to Kunoichi Shadow.
        r.next = {body = {fit = KUNOICHI}, switched = KUNOICHI}
        at(r, 0.5, 'select')
        eq(#r.previews, 1, 'worn')
        eq(text.s, T.en.closet.switched:format('Kunoichi Shadow'), 'the switch shown in the menu')
        eq(body_row(), fit('Kunoichi Shadow'), 'the Body row names the switched body, not None')
        tick(r, 20)
        eq(text.s, T.en.closet.switched:format('Kunoichi Shadow'), 'no fade while the plan has it')
        -- A plan that leaves skin showing: the clips line; the Body row the plan's body.
        r.next = {body = {fit = MAID}, clips = {'Calf', 'Foot'}}
        at(r, 20, 'select')
        eq(text.s, T.en.closet.clips:format('Calves, Feet'), 'the clips line')
        eq(body_row(), 'Ocean Maid', "the plan's body")
        r.next = {body = {fit = MAID}, switched = KUNOICHI, clips = {'Foot'}}
        at(r, 20, 'select')
        eq(text.s, T.en.closet.switched:format('Kunoichi Shadow') .. '\n' .. T.en.closet.clips:format('Feet'), 'both')
        -- Neither: no notice.
        r.next = {body = {fit = MAID}}
        at(r, 20, 'select')
        eq(text.s, '', 'no switch, no clips: no notice')
        eq(body_row(), 'Ocean Maid', 'the body in use')
    end,

    select_is_ignored_right_after_open = function()
        local r = rig()
        r.menu.open()
        at(r, 0.1, 'select')
        eq(#r.previews, 0, 'the console Enter did not wear the Full tab outfit')
        at(r, 0.31, 'select')
        same(r.previews, {{{fit = KUNOICHI}}}, 'select works 0.3 s after the open')
    end,

    full_outfit_is_the_first_tab = function()
        local m = require('closet.ui.model').new({slots = require('closet.slots'), fits = Fits,
            installed = function() return true end})
        eq(m.tabs()[1], 'full', 'the first tab')
        -- The first open shows it on its first outfit, even with rows of pieces in other tabs.
        local r = rig()
        r.menu.open()
        ok(F.called(r.kit.live(F.TAB)[1].o, 'FocusTabButton'), 'Full outfit focused')
        eq(r.kit.live(F.TAB)[1].o.TextValue.text, T.en.closet.tabs.full, 'its label')
        eq((detail(r)), 'Kunoichi Shadow', 'its first outfit by name')
    end,

    -- Colour right after Full outfit; Head..Body and Intimate labelled through closet.beta, the others plain.
    fitting_tabs_carry_beta = function()
        local r = rig({adult = true})
        r.menu.open()
        local ids = {'full', 'colour', 'head', 'torso', 'arms', 'hips', 'intimate', 'legs', 'body', 'weapon'}
        local seen = {}
        for i = 1, #ids do
            local tabs = r.kit.live(F.TAB)
            for _, rec in ipairs(tabs) do
                if F.called(rec.o, 'FocusTabButton') then seen[i] = rec.o.TextValue.text end
            end
            at(r, 0.1, 'tab_right')
        end
        for i, id in ipairs(ids) do eq(seen[i], tab_label(id), 'tab ' .. i .. ' ' .. id) end
        eq(T.en.closet.beta:format(T.en.closet.tabs.head), 'Head (Beta)', 'the English Beta word')
        eq(seen[2], T.en.closet.tabs.colour, 'Colour second, not Beta')
    end,

    the_tab_window_follows_the_focus = function()
        local r = rig({adult = true})
        r.menu.open()
        local function labels()
            local out = {}
            for i, rec in ipairs(r.kit.live(F.TAB)) do out[i] = rec.o.TextValue.text end
            return out
        end
        local ids = {'full', 'colour', 'head', 'torso', 'arms', 'hips', 'intimate', 'legs', 'body', 'weapon'}
        local function names(from, to)
            local out = {}
            for i = from, to do out[#out + 1] = tab_label(ids[i]) end
            return out
        end
        same(labels(), names(1, 7), 'tabs 1-7 at the open')
        -- Tab 10 (Q from the first wraps): tabs 4-10 shown, the last focused, every button inside the window's x.
        at(r, 0.1, 'tab_left')
        same(labels(), names(4, 10), 'tabs 4-10')
        local tabs = r.kit.live(F.TAB)
        ok(F.called(tabs[7].o, 'FocusTabButton'), 'tab 10 focused')
        for i, rec in ipairs(tabs) do eq(rec.x, 160 + (i - 1) * 266, 'tab x ' .. i) end
        -- Back to 9 and 4: the window stays until the focus leaves it.
        at(r, 0.1, 'tab_left')
        same(labels(), names(4, 10), 'tab 9: the window stays')
        -- A click on the first button shown is tab 4 (torso).
        r.kit.live(F.TAB)[1].o.Button_Action.hover = true
        at(r, 0.1, 'click')
        eq((detail(r)), 'Chest tattoo', 'a click on the first shown tab: torso')
        same(labels(), names(4, 10), 'tab 4: the window stays')
        at(r, 0.1, 'tab_left')
        same(labels(), names(3, 9), 'tab 3: the window follows')
        at(r, 0.1, 'tab_left', 'tab_left', 'tab_left')
        same(labels(), names(4, 10), 'tab 10 again after the wrap')
    end,

    -- The Colour tab (after Full outfit): a row for each role of closet/colour.lua, its value the swatch's name. Left,
    -- right, Select and a click on the row pick the swatch; nothing is previewed, so Back asks nothing. The camera
    -- frames her whole body.
    the_colour_tab_picks_a_swatch_per_role = function()
        local col, cam = fake_colour(), fake_camera()
        local r = rig({colour = col, camera = cam})
        r.menu.open()
        at(r, 0.5, 'tab_right') -- Full, Colour.
        local function rows()
            local out = r.kit.live(F.OPTION)
            table.sort(out, function(a, b) return a.y < b.y end)
            local list = {}
            for i, rec in ipairs(out) do list[i] = rec.o.Text_TitleValue.text .. '=' .. rec.o.Text_ItemValue.text end
            return list
        end
        local w = T.en.closet.colour
        same(rows(), {w.roles.primary .. '=Off', w.roles.secondary .. '=Off', w.roles.accent .. '=Off',
            w.roles.glow .. '=Off'}, 'the four rows, each Off')
        local title, desc = detail(r)
        eq(title, w.roles.primary, 'the detail names the role')
        local camera = T.en.closet.camera
        eq(desc, w.about.primary .. '\n' .. w.help .. '\n' .. camera.title:format(camera.moves.region.key),
            'what it colours and how to pick, then the camera line (the keyboard\'s)')
        -- The menu's hint row (y 1990, under the camera's), each part's last text, in screen order (right to left):
        -- the parts are pooled, so their list order follows the tabs shown before.
        local parts = {}
        for _, h in ipairs(r.kit.live(F.HINT)) do
            local text
            for _, c in ipairs(h.o.calls) do if c[1] == 'SetText' then text = c[2].text or c[2] end end
            if h.y == 1990 then parts[#parts + 1] = {x = h.x, text = text} end
        end
        table.sort(parts, function(a, b) return a.x > b.x end)
        local hints = {}
        for i, h in ipairs(parts) do hints[i] = h.text end
        same(hints, {T.en.hint.back, T.en.hint.select, T.en.hint.move}, 'Back, Select, Move')
        at(r, 0.5, 'right')
        eq(rows()[1], w.roles.primary .. '=' .. w.swatches.white, 'right: the next swatch')
        at(r, 0.5, 'select')
        eq(rows()[1], w.roles.primary .. '=' .. w.swatches.black, 'Select: the next swatch')
        at(r, 0.5, 'left')
        eq(rows()[1], w.roles.primary .. '=' .. w.swatches.white, 'left: the one before')
        at(r, 0.5, 'down', 'left')
        eq(rows()[2], w.roles.secondary .. '=' .. w.swatches.sand, 'left from Off: the last swatch')
        eq((detail(r)), w.roles.secondary, 'the Secondary row focused')
        same(col.steps, {'primary 1', 'primary 1', 'primary -1', 'secondary -1'}, 'the steps')
        eq(#r.previews, 0, 'nothing previewed')
        tick(r, 0.6)
        eq(cam.ticks[#cam.ticks].region, 'full', 'her whole body framed')
        at(r, 0.7, 'back')
        eq(popups(r), 0, 'no Keep popup') eq(r.menu.is_open(), false, 'closed')
        eq(col.palette.primary, 'white', 'the palette stays: it is saved apart from the look')
        -- Without a colour layer the rows show Off and pick nothing.
        r = rig()
        r.menu.open()
        at(r, 0.5, 'tab_right', 'right', 'select')
        same(rows(), {w.roles.primary .. '=Off', w.roles.secondary .. '=Off', w.roles.accent .. '=Off',
            w.roles.glow .. '=Off'}, 'no layer: Off')
    end,

    -- The Body tab: below the Body row, one row per shape name of closet/shape.lua, its value in percent. Left and
    -- right step it by 10 (from 0 to 100), Select and a click take the next step (after 100: 0). Nothing is previewed,
    -- so Back asks nothing. The rows follow the look: a change shows at the next tick.
    the_body_tab_lists_the_shape_rows = function()
        local sh = fake_shape({'Butt', 'Hips'})
        local r = rig({shape = sh})
        r.menu.open()
        at(r, 0.5, 'tab_left', 'tab_left') -- Full, Weapon, Body.
        local function rows()
            local out = r.kit.live(F.OPTION)
            table.sort(out, function(a, b) return a.y < b.y end)
            local list = {}
            for i, rec in ipairs(out) do list[i] = rec.o.Text_TitleValue.text .. '=' .. rec.o.Text_ItemValue.text end
            return list
        end
        local w = T.en.closet
        local shown = rows()
        eq(shown[1]:match('^[^=]+'), w.slots.BaseBody, 'the Body row first')
        eq(shown[2], 'Butt=0%', 'then the shape rows') eq(shown[3], 'Hips=0%')
        eq(shown[4]:match('^[^=]+'), w.slots.SkinSuit, 'then the other body slots')
        at(r, 0.5, 'down')
        local title, desc = detail(r)
        eq(title, 'Butt', 'the detail names the shape')
        eq(desc, w.shape.about .. '\n' .. w.shape.help, 'what it does and how to change it')
        local hints = {} -- The menu's hint row (y 1990) right to left from the menu's edge, each part's last text.
        local live = r.kit.live(F.HINT)
        table.sort(live, function(a, b) return a.x > b.x end)
        for _, h in ipairs(live) do
            local text
            for _, c in ipairs(h.o.calls) do if c[1] == 'SetText' then text = c[2].text or c[2] end end
            if h.y == 1990 then hints[#hints + 1] = text end
        end
        same(hints, {T.en.hint.back, T.en.hint.select, T.en.hint.move}, 'Back, Select, Move')
        at(r, 0.5, 'right')
        eq(rows()[2], 'Butt=10%', 'right: up a step')
        at(r, 0.5, 'left', 'left')
        eq(rows()[2], 'Butt=0%', 'left: down a step, never under 0')
        at(r, 0.5, 'select')
        eq(rows()[2], 'Butt=10%', 'Select: up a step')
        sh.values.Butt = 100
        at(r, 0.5, 'select')
        eq(rows()[2], 'Butt=0%', 'Select after 100: 0')
        eq(#r.previews, 0, 'nothing previewed')
        -- A click on the Hips row takes the focus and steps it.
        r.kit.groups.closet_menu.zones[3].hover = true
        at(r, 0.5, 'click')
        r.kit.groups.closet_menu.zones[3].hover = false
        eq((detail(r)), 'Hips', 'the clicked row focused') eq(rows()[3], 'Hips=10%', 'and stepped')
        -- The look changed: the next tick shows its rows.
        sh.names = {'Legs'}
        tick(r, 0.6)
        eq(rows()[2], 'Legs=0%', 'the new look\'s rows')
        at(r, 0.7, 'back')
        eq(popups(r), 0, 'no Keep popup') eq(r.menu.is_open(), false, 'closed')
        eq(sh.values.Hips, 10, 'the shape stays: it is saved apart from the look')
        -- Without a shape layer: no shape row.
        r = rig()
        r.menu.open()
        at(r, 0.5, 'tab_left', 'tab_left')
        eq(rows()[2]:match('^[^=]+'), w.slots.SkinSuit, 'no layer: no shape row')
    end,

    grid_up_down_walk_rows_of_five = function()
        -- 9 more outfits with a top: the Top row's grid has 12 tiles (None, Maid, Kunoichi, Top 1-9), 3 rows of 5.
        local added = {}
        for i = 1, 9 do
            local id = 'ZZ_' .. i
            Fits.BY_ID[id] = {Outfit = 'Outfit ' .. i, Pack = 'ZZ', Pieces = {{Slot = 'Chest', Name = 'Top ' .. i}}}
            added[#added + 1] = id
        end
        local good, why = pcall(function()
            local r = rig()
            on_top(r)
            local tv = grid(r)
            local function on(n, what) eq(tv:GetIndexForItem(tv:BP_GetSelectedItem()) + 1, n, what) end
            at(r, 0.5, 'right', 'right', 'right')
            eq(#tv.items, 12, 'tiles')
            on(3, 'tile 3')
            at(r, 0.5, 'down')
            on(8, 'down: tile 8')
            eq(r.kit.sounds[#r.kit.sounds], 'move', 'move sound')
            at(r, 0.5, 'down')
            on(12, 'down: tile 12, the last')
            at(r, 0.5, 'down')
            on(12, 'down on the last row stays')
            at(r, 0.5, 'up')
            on(7, 'up: tile 7')
            at(r, 0.5, 'up')
            on(2, 'up: tile 2')
            at(r, 0.5, 'up')
            on(2, 'up on the first row stays in the grid')
            ok(r.menu.is_open(), 'open')
            tick(r, 0.8)
            same(r.previews, {{{fit = MAID, slots = {'Chest'}}}}, 'the tile reached by up and down is previewed')
            -- Down on the last row, short of its 5th tile, stays: tile 11 has no tile under it.
            at(r, 1, 'down', 'down', 'left')
            on(11, 'tile 11, on the last row')
            at(r, 1, 'down')
            on(11, 'down on the last row stays on tile 11')
        end)
        for _, id in ipairs(added) do Fits.BY_ID[id] = nil end
        ok(good, why)
    end,

    refused_opens_make_nothing = function()
        local eve = {IsA = function() return true end}
        local cases = {
            {'ui', function(r) r.kit.up = false end},
            {'loading', function(r) r.world = false end},
            {'panel', function(r) r.kit.held = 'lobby' end},
            {'screen', function(r) r.kit.paused_now = true end},
            {'photo', function(r) r.photo = '1' end},
            {'cutscene', function(r) r.status = 'mod=1 theater=intro' end},
            {'cutscene', function() eve.IsAttachedToLevelSequenceWithoutPlayable = function() return true end end},
            {'combat', function() eve.IsBattle = function() return true end end},
            {'tachy', function(r) r.game_look = '/Game/Art/Character/PC/CH_P_EVE_10/CH_P_EVE_10.CH_P_EVE_10' end},
            -- SBO's own state that holds EVE's body (closet/wiring.lua's busy gives the key).
            {'bike', function(r) r.busy = 'bike' end},
            {'doro', function(r) r.busy = 'doro' end},
            {'rifle', function(r) r.busy = 'rifle' end},
            {'emote', function(r) r.busy = 'emote' end},
            {'wear', function(r) r.busy = 'wear' end},
        }
        package.loaded.UEHelpers.GetPlayer = function() return eve end
        for _, case in ipairs(cases) do
            eve.IsBattle = function() return false end
            eve.IsAttachedToLevelSequenceWithoutPlayable = function() return false end
            local r = rig()
            case[2](r)
            local held = r.kit.held
            local good, line = r.menu.open()
            eq(good, false, case[1])
            eq(type(T.en.closet.refused[case[1]]), 'string', case[1] .. ': its text')
            eq(line, T.en.closet.refused[case[1]], case[1] .. ' line')
            same(r.told, {T.en.closet.refused[case[1]]}, case[1] .. ' notice')
            eq(#r.kit.made, 0, case[1] .. ': nothing made')
            eq(#r.kit.inputs, 0, case[1] .. ': no input taken')
            eq(r.kit.held, held, case[1] .. ': input untouched')
            eq(r.menu.is_open(), false, case[1] .. ': closed')
        end
        package.loaded.UEHelpers.GetPlayer = function() return nil end
    end,

    -- Another panel that takes the input within BACK after a close (F5 twice: the co-op menu) has it: the closet's
    -- give-back owes nothing then, so its open refuses on the panel guard, before BACK and after it.
    a_panel_that_took_the_input_after_a_close_refuses_the_open = function()
        local r = rig()
        r.menu.open()
        r.menu.close('revert')
        ok(r.kit.holding('closet_menu'), 'still ours for BACK s')
        r.kit.input(true, 'menu')
        local good, line = r.menu.open()
        eq(good, false, 'refused before BACK') eq(line, T.en.closet.refused.panel, 'the panel line')
        tick(r, 0.2)
        eq(r.kit.held, 'menu', 'the give-back leaves the other panel\'s input')
        local asked = #r.kit.inputs
        tick(r, 0.4)
        eq(#r.kit.inputs, asked, 'nothing owed: the give-back is not asked again')
        good, line = r.menu.open()
        eq(good, false, 'refused after BACK') eq(line, T.en.closet.refused.panel, 'the panel line again')
        eq(r.menu.is_open(), false, 'closed')
        -- Still ours at the close (no other panel): the next open takes it on.
        r = rig()
        r.menu.open()
        r.menu.close('revert')
        ok(r.menu.open(), 'an open while it is still ours')
    end,

    -- The host's question opens over the menu (its own holder, drawn over the closet, main/ui.lua) and gives the input
    -- to the game at its answer: the menu takes it again at its next guard and stays open, nothing reverted.
    the_input_comes_back_after_the_host_question = function()
        local r = rig()
        on_top(r)
        tick(r, 0.25)
        r.kit.input(true, 'ask', true)
        tick(r, 0.5)
        ok(r.menu.is_open(), 'open under the question') eq(r.kit.held, 'ask', 'the question holds the input')
        r.held = 2 -- Down held: the question's key, never a repeat of the menu's.
        tick(r, 1) tick(r, 1.5) tick(r, 1.7)
        eq((detail(r)), 'Top', 'no repeat under the question')
        r.held = nil
        r.kit.input(false, 'ask')
        tick(r, 2)
        ok(r.menu.is_open(), 'still open') eq(r.kit.held, 'closet_menu', 'taken again')
        same(r.kit.inputs[#r.kit.inputs], {true, 'closet_menu', true, true}, 'as at the open')
        eq(r.reverted, 0, 'nothing reverted') same(r.told, {}, 'no notice')
    end,

    -- A guard that raises while open closes the menu with a revert, the log naming it.
    an_unread_guard_closes_and_says_so = function()
        local r = rig()
        on_top(r)
        tick(r, 0.25)
        package.loaded.UEHelpers.GetPlayer = function() error('no player read') end
        tick(r, 0.5)
        package.loaded.UEHelpers.GetPlayer = function() return nil end
        ok(not r.menu.is_open(), 'closed') eq(r.reverted, 1, 'reverted')
        has(r.log, 'menu: a guard could not be read', 'the error')
        has(r.log, 'menu: closed (revert, guard unread)', 'the close names it')
    end,
    combat_cutscene_photo_and_map_change_close_and_revert = function()
        local eve = {IsA = function() return true end, IsBattle = function() return false end}
        package.loaded.UEHelpers.GetPlayer = function() return eve end
        local cases = {
            {'map', function(r) r.world = false end},
            {'map', function(r) r.kit.up = false end},
            {'photo', function(r) r.photo = '2' end},
            {'cutscene', function(r) r.status = 'mod=1 theater=boss' end},
            {'cutscene', function() eve.IsAttachedToLevelSequenceWithoutPlayable = function() return true end end},
            {'input', function(r) r.kit.held, r.kit.deaf = nil, true end}, -- Given to the game, not taken again.
        }
        for _, case in ipairs(cases) do
            eve.IsAttachedToLevelSequenceWithoutPlayable = function() return false end
            local r = rig()
            on_top(r)
            tick(r, 0.25)
            ok(r.menu.is_open(), case[1] .. ': open before')
            case[2](r)
            tick(r, 0.4)
            ok(r.menu.is_open(), case[1] .. ': checked each 250 ms')
            tick(r, 0.5)
            eq(r.reverted, 1, case[1] .. ' reverted')
            same(r.told, {T.en.closet.closed[case[1]]}, case[1] .. ' notice')
            has(r.log, 'menu: closed (revert, ' .. case[1] .. ')', case[1] .. ': the guard is in the log')
            all_gone(r)
        end
        eve.IsAttachedToLevelSequenceWithoutPlayable = function() return false end
        -- Combat: checked once a second.
        local r = rig()
        on_top(r)
        eve.IsBattle = function() return true end
        tick(r, 0.25) tick(r, 0.5) tick(r, 0.75)
        ok(r.menu.is_open(), 'combat waits for its second')
        tick(r, 1)
        eq(r.reverted, 1, 'combat reverted')
        same(r.told, {T.en.closet.closed.combat}, 'combat notice')
        has(r.log, 'menu: closed (revert, combat)', 'combat: the guard is in the log')
        all_gone(r)
        eve.IsBattle = function() return false end
        -- A part gone (the root rebuilt by a map change): closed, every other part dropped.
        r = rig()
        on_top(r)
        r.kit.made[1].live = false
        tick(r, 0.25)
        same(r.told, {T.en.closet.closed.map}, 'part gone notice')
        eq(r.reverted, 1, 'part gone reverted')
        eq(r.kit.dropped, #r.kit.made - 1, 'the others dropped')
        eq(r.menu.is_open(), false, 'closed')
        eq(r.kit.held, 'closet_menu', 'input kept 150 ms')
        tick(r, 0.4)
        eq(r.kit.held, nil, 'input back')
        package.loaded.UEHelpers.GetPlayer = function() return nil end
    end,

    a_revert_the_dress_refuses_is_asked_again_while_closed = function()
        -- A map change closes the menu: no EVE, so the revert fails and the preview stays on (closet/dress.lua's
        -- revert). Each GUARD s while closed the menu asks again until the confirmed look is back.
        local r = rig()
        local fails = 3
        r.dress.revert = function()
            r.reverted = r.reverted + 1
            if fails > 0 then fails = fails - 1; return false, 'no EVE' end
            r.previewing = false; return true, 'closet: reverted'
        end
        on_top(r)
        at(r, 0.5, 'right', 'right', 'select')
        ok(r.previewing, 'previewing')
        r.world = false
        tick(r, 0.75)
        eq(r.menu.is_open(), false, 'closed by the map change')
        eq(r.reverted, 1, 'reverted once at the close')
        tick(r, 0.8)
        eq(r.reverted, 1, 'not again before GUARD s')
        tick(r, 1.0)
        eq(r.reverted, 2, 'asked again')
        tick(r, 1.25)
        eq(r.reverted, 2, 'not again before RETRY s')
        -- A loading screen pauses the game: no ask, as the dress's restore waits too.
        r.kit.paused_now = true
        tick(r, 2.0)
        eq(r.reverted, 2, 'not while paused')
        r.kit.paused_now = false
        tick(r, 2.0)
        eq(r.reverted, 3, 'asked again once the screen is gone')
        tick(r, 3.0)
        eq(r.reverted, 4, 'the confirmed look is back')
        eq(r.previewing, false, 'preview over')
        tick(r, 4.0) tick(r, 5.0)
        eq(r.reverted, 4, 'no more asks once it worked')
        -- coop off and an open drop the owed revert: off ends the look, the open shows the preview again.
        for _, how in ipairs({'stop', 'open'}) do
            r = rig()
            r.dress.revert = function() r.reverted = r.reverted + 1; return false, 'no EVE' end
            on_top(r)
            at(r, 0.5, 'right', 'right', 'select')
            r.world = false
            tick(r, 0.75)
            r.world = true
            if how == 'stop' then r.menu.stop() else r.t = 0.8; ok(r.menu.open(), 'reopened') end
            tick(r, 1.0)
            if how == 'open' then ok(r.menu.is_open(), 'open') end
            eq(r.reverted, 1, how .. ': no revert asked after it')
        end
    end,

    the_kit_keeps_the_keyboard_focus = function()
        -- SB's grid entries take the keyboard focus when the grid is filled (closet/ui/probe.lua test 5): a key then
        -- reaches EVE (E fired a skill, combat closed the menu). Each draw and each tick while open give it back to the
        -- kit's root, where the game ignores keys.
        local r = rig()
        on_top(r)
        local n = r.kit.refocused
        at(r, 0.5, 'tab_right')
        eq(r.kit.refocused, n + 1, 'the tab change refills the grid: focus back at once')
        tick(r, 0.51)
        eq(r.kit.refocused, n + 2, 'each tick while open')
        r.menu.close()
        n = r.kit.refocused
        tick(r, 0.6) tick(r, 0.7)
        eq(r.kit.refocused, n, 'never while closed')
    end,

    a_typed_wear_closes_the_menu_without_revert = function()
        local r = rig()
        on_top(r)
        tick(r, 0.25)
        ok(r.menu.is_open(), 'no change made: previewing false is fine')
        at(r, 0.5, 'right', 'right', 'select')
        tick(r, 0.75)
        ok(r.menu.is_open(), 'previewing')
        r.previewing = false -- coop closet wear typed in the console.
        tick(r, 1)
        eq(r.reverted, 0, 'no revert')
        eq(r.confirmed, 0, 'no confirm')
        same(r.told, {}, 'no notice')
        all_gone(r)
    end,

    -- Right on a pack outfit's row opens its options page (Select still wears it); Back closes the page, the focus back
    -- on the outfit's row; the pad chord that leaves the page puts it back before its Back. Every prompt follows the
    -- device: SB's hint parts draw the keys or the pad's buttons, the detail's help names the keys or the buttons.
    right_opens_back_closes_and_undo_restores_the_page = function()
        local O, H = T.en.closet.options, T.en.closet.hints
        with_aria(function(r)
            r.menu.open()
            local title, desc = detail(r)
            eq(title, 'Aria', 'the first outfit') ok(desc:find(O.open.key, 1, true), desc)
            same(menu_hints(r), {{T.en.hint.back, 'Negative', 'None'}, {H.whole, 'Positive', 'None'},
                {H.options, 'UI_DPad_Right', 'None'}, {T.en.hint.move, 'UI_DPad_Up', 'UI_DPad_Down'}}, 'Options hint')
            at(r, 0.5, 'right')
            eq((detail(r)), O.variant, 'the page opens on its first setting')
            same(headers(r), {'Aria'}, 'the outfit\'s name as a header row')
            eq(row_value(r, O.variant), 'Short') eq(row_value(r, T.en.closet.slots.Shoes), '1/1')
            eq(row_value(r, child(1, 'Bolero')), O.on) eq(row_value(r, child(1, 'Bag')), O.off)
            eq(row_value(r, child(1, 'Lining')), nil, 'a follower')
            eq(row_value(r, O.other), '0/1', 'the Other section')
            same(menu_hints(r), {{T.en.hint.back, 'Negative', 'None'}, {H.change, 'UI_DPad_Left', 'UI_DPad_Right'},
                {H.reset, 'UI_FaceButton_Top', 'None'}, {T.en.hint.move, 'UI_DPad_Up', 'UI_DPad_Down'}},
                'the page\'s hints')
            at(r, 0.6, 'up')
            eq((detail(r)), 'Aria', 'up reaches the header')
            at(r, 0.6, 'up')
            eq((detail(r)), O.reset, 'up on the header wraps to the last row')
            at(r, 0.6, 'down')
            eq((detail(r)), 'Aria', 'down on the last row wraps to the header') eq(r.menu.is_open(), true)
            at(r, 0.7, 'back')
            eq((detail(r)), 'Aria', 'Back: the outfit\'s row') eq(headers(r)[1], nil, 'the page closed')
            eq(r.menu.is_open(), true) eq(#r.previews, 0, 'nothing worn')
            r.dev = 4 -- A pad input: the detail says the pad's buttons.
            at(r, 0.8, 'right', 'down', 'down', 'down', 'down')
            title, desc = detail(r)
            eq(title, 'Bolero') ok(desc:find('The cropped jacket', 1, true), 'the pack\'s description')
            ok(desc:find(O.help.pad, 1, true) and not desc:find(O.help.key, 1, true), desc)
            r.dev = 1 -- A key press: the next tick draws the keys.
            tick(r, 0.85)
            title, desc = detail(r)
            ok(desc:find(O.help.key, 1, true) and not desc:find(O.help.pad, 1, true), desc)
            -- The chord: LB (tab_left), then D-pad Left and the closet key in one frame.
            at(r, 0.9, 'tab_left', 'left')
            r.menu.toggle()
            eq(r.menu.is_open(), true, 'the page came back: its Back closed it, not the menu')
            eq((detail(r)), 'Aria', 'on the outfit\'s row')
            at(r, 1, 'back')
            eq(r.menu.is_open(), false, 'Back on the rows: closed, nothing changed')
        end, wearing_aria())
    end,
    a_section_row_turns_its_pieces = function()
        local O = T.en.closet.options
        with_aria(function(r)
            r.menu.open()
            at(r, 0.5, 'right', 'down', 'down', 'down') -- The Jacket section (Outerwear).
            eq((detail(r)), T.en.closet.slots.Outerwear)
            at(r, 0.6, 'right')
            eq(r.options.get(ARIA, 1, 'toggle:3'), false, 'its piece off') eq(row_value(r, child(1, 'Bolero')), O.off)
            eq(row_value(r, T.en.closet.slots.Outerwear), '0/1')
            eq(r.store.file, ARIA .. ' 1 toggle:3=off', 'saved at once')
            at(r, 0.7, 'select')
            eq(r.options.get(ARIA, 1, 'toggle:3'), true, 'and on again') eq(r.store.file, nil)
            at(r, 0.8, 'down', 'left')
            eq(row_value(r, child(1, 'Bolero')), O.off, 'a piece row turns its piece')
            at(r, 0.9, 'down', 'down', 'right')
            eq(r.options.get(ARIA, 1, 'toggle:6'), true, 'Bag on') eq(row_value(r, O.other), '1/1')
            eq(#r.previews, 0, 'no preview')
            at(r, 1, 'back', 'back')
            eq(r.menu.is_open(), false, 'no Keep popup: the options are saved apart from the look')
        end, wearing_aria())
    end,
    the_variant_row_skips_a_variant_whose_mesh_does_not_load = function()
        local O = T.en.closet.options
        with_aria(function(r)
            r.menu.open()
            at(r, 0.5, 'right', 'right')
            eq(row_value(r, O.variant), 'Long', 'variant 2 does not load: variant 3')
            eq(r.options.variant(ARIA), 3) eq(Fits.get(ARIA).Mesh, '/Game/A/V3.V3')
            at(r, 0.6, 'right')
            eq(row_value(r, O.variant), 'Short', 'round to the first')
            at(r, 0.7, 'left')
            eq(row_value(r, O.variant), 'Long')
        end, {loads = function(path) return path ~= '/Game/A/V2.V2' end})
        with_aria(function(r)
            r.menu.open()
            at(r, 0.5, 'right', 'right')
            eq(row_value(r, O.variant), '2/3', 'a variant with no name: its number')
        end)
    end,
    -- Select on a piece opens its controls below it (a colour with a kit swatch right of the row, a number); the
    -- Shape section and Reset this outfit close the page. F (the pad's Y) gives the focused row its pack value back.
    -- Every prompt follows the device.
    refresh_resets_the_focused_row_to_the_pack_value = function()
        local O, H = T.en.closet.options, T.en.closet.hints
        -- A control row says its kind, then its name when that differs from its piece's.
        local COLOUR, SHINE = child(2, O.named:format(O.kinds.colour, 'Bolero colour')),
            child(2, O.named:format(O.kinds.number, 'Bolero shine'))
        with_aria(function(r)
            local item = aria()
            item.UserConfigs.VectorControls = {{DisplayName = 'Bolero colour', Description = 'Its cloth',
                ParamName = 'Base Color Tint', MaterialIndex = 3, Value = {0.5, 0.5, 0.5, 1}}}
            item.UserConfigs.ScalarControls = {{DisplayName = 'Bolero shine', ParamName = 'Metallic', MaterialIndex = 3,
                Value = 0.5, Step = 0.1}}
            item.UserConfigs.ShapeKeys = {{DisplayName = 'Hips', Min = -1, Max = 1, Step = 0.25, Value = 0}}
            Fits.use({[ARIA] = item})
            -- The swatch beside visible row i: a kit image right of the rows.
            local function swatch()
                for _, i in ipairs(r.kit.groups.closet_menu.images) do
                    if i.x == 1129 and i.shown then return i end
                end
            end
            r.menu.open()
            at(r, 0.5, 'right', 'down', 'down', 'down', 'down')
            eq((detail(r)), 'Bolero')
            same(menu_hints(r), {{T.en.hint.back, 'Negative', 'None'}, {T.en.hint.select, 'Positive', 'None'},
                {H.change, 'UI_DPad_Left', 'UI_DPad_Right'}, {T.en.hint.move, 'UI_DPad_Up', 'UI_DPad_Down'}},
                'a piece with controls: Select opens them')
            eq(row_value(r, COLOUR), nil, 'closed') eq(swatch(), nil, 'no swatch')
            at(r, 0.6, 'select')
            eq(row_value(r, child(1, 'Bolero')), O.on, 'Select opens, it does not turn the piece')
            eq(row_value(r, COLOUR), O.pack) eq(row_value(r, SHINE), '0.5')
            same(swatch().tint, {R = 0.5, G = 0.5, B = 0.5, A = 1}, 'the swatch shows the colour')
            at(r, 0.7, 'down')
            local title, desc = detail(r)
            eq(title, O.named:format(O.kinds.colour, 'Bolero colour'), 'the detail title has no lead mark')
            ok(desc:find('Its cloth', 1, true), 'the pack\'s description')
            ok(desc:find(O.help.key, 1, true), desc)
            same(menu_hints(r), {{T.en.hint.back, 'Negative', 'None'}, {H.change, 'UI_DPad_Left', 'UI_DPad_Right'},
                {H.reset, 'UI_FaceButton_Top', 'None'}, {T.en.hint.move, 'UI_DPad_Up', 'UI_DPad_Down'}}, 'Reset on F')
            r.dev = 4
            tick(r, 0.75)
            desc = select(2, detail(r))
            ok(desc:find(O.help.pad, 1, true) and not desc:find(O.help.key, 1, true), desc)
            at(r, 0.8, 'right')
            eq(row_value(r, COLOUR), T.en.closet.colour.swatches.white)
            same(swatch().tint, {R = 0.888, G = 0.888, B = 0.888, A = 1})
            ok(r.store.file:find('colour:1=0.888', 1, true), r.store.file)
            at(r, 0.9, 'refresh')
            eq(row_value(r, COLOUR), O.pack, 'F: the pack value') eq(r.store.file, nil)
            at(r, 1, 'left')
            eq(row_value(r, COLOUR), '128 128 128', 'Custom before Pack colour: its R G B')
            eq(row_value(r, child(3, O.channels.r)), '128', 'its channels in 0-255, children of the colour')
            -- Channels, numbers and shape keys are the game's slider slot: its value text shows the number in the
            -- range, its slider the place; Focus or Normal as the focus moves.
            local red = slider(r, child(3, O.channels.r))
            ok(red, 'the Red channel is a slider row')
            same(red.o.ItemTextRange, {Min = 0, Max = 255}, 'its range 0-255') eq(red.o.ItemTextFractionalDigits, 0)
            ok(F.called(red.o, 'UpdatePercentOffset'), 'its slider placed')
            ok(slider(r, SHINE), 'a number is a slider row')
            -- A click on a slider's bar sets the value at that place (View.SLIDER_X0 to View.SLIDER_X1); a click on
            -- the row elsewhere runs Select as on any row.
            local View = require('closet.ui.view')
            local zone = r.kit.groups.closet_menu.zones[(red.y - 300) // 130 + 1]
            r.kit.pointer = function() return View.SLIDER_X0 + (View.SLIDER_X1 - View.SLIDER_X0) * 0.2, red.y + 60 end
            zone.hover = true
            at(r, 1.05, 'click')
            eq(row_value(r, child(3, O.channels.r)), '51', 'a click a fifth along the bar: 51 of 255')
            r.kit.pointer = function() return View.SLIDER_X1 + 500, red.y + 60 end
            at(r, 1.06, 'click')
            eq(row_value(r, child(3, O.channels.r)), '64', 'a click right of the bar: Select, a step')
            r.kit.pointer = function() return View.SLIDER_X0 + (View.SLIDER_X1 - View.SLIDER_X0) * 0.5, red.y + 60 end
            at(r, 1.07, 'click')
            zone.hover = false
            r.kit.pointer = nil
            eq(row_value(r, child(3, O.channels.r)), '128', 'back to the middle')
            at(r, 1.08, 'up') -- The focus back on the colour, where the clicks found it.
            eq(row_value(r, child(3, O.channels.a)), nil, 'no alpha slider')
            at(r, 1.1, 'down', 'right')
            eq(row_value(r, child(3, O.channels.r)), '140', 'a step of 1/20') eq(row_value(r, COLOUR), '140 128 128')
            at(r, 1.2, 'down', 'down', 'down', 'right')
            eq(row_value(r, SHINE), '0.6', 'the pack step')
            at(r, 1.3, 'refresh')
            eq(row_value(r, SHINE), '0.5')
            at(r, 1.4, 'back')
            eq(row_value(r, COLOUR), nil, 'Back closes the controls') eq((detail(r)), 'Bolero')
            eq(r.menu.is_open(), true)
            at(r, 1.5, 'down', 'down', 'down', 'down')
            eq((detail(r)), 'Hips') eq(row_value(r, O.shape), '', 'the Shape section')
            at(r, 1.6, 'left')
            eq(row_value(r, child(1, 'Hips')), '-0.25')
            at(r, 1.7, 'down')
            eq((detail(r)), O.reset)
            at(r, 1.8, 'select')
            eq(row_value(r, child(1, 'Hips')), '0.00', 'every pack value back') eq(r.store.file, nil)
            eq(#r.previews, 0, 'nothing worn')
        end, wearing_aria())
    end,
    -- A row says what it is: a control its kind, then its name when that differs from its piece's; a piece reads as
    -- a child of its section, a control as a child of its piece, a channel as a child of its colour (a lead mark at
    -- each depth). A section row has none: it reads as the header of the pieces below it.
    options_rows_say_their_kind_and_read_as_children = function()
        local O = T.en.closet.options
        with_aria(function(r)
            local item = aria()
            item.UserConfigs.VectorControls = {{DisplayName = 'Bolero', ParamName = 'Tint', MaterialIndex = 3,
                Value = {0.5, 0.5, 0.5, 1}}}
            item.UserConfigs.ScalarControls = {{DisplayName = 'Shine', ParamName = 'Metallic', MaterialIndex = 3,
                Value = 0.5}}
            item.UserConfigs.TextureOptions = {{DisplayName = '', MaterialIndex = 3, Textures = {}, Value = 0}}
            Fits.use({[ARIA] = item})
            r.menu.open()
            at(r, 0.5, 'right', 'down', 'down', 'down', 'down', 'select')
            eq((detail(r)), 'Bolero', 'the piece, its detail title with no lead mark')
            eq(row_value(r, T.en.closet.slots.Outerwear), '1/1', 'the section row: no lead mark')
            eq(row_value(r, child(1, 'Bolero')), O.on, 'the piece: a child of its section')
            eq(row_value(r, child(2, O.kinds.colour)), O.pack, 'named as its piece: its kind only')
            eq(row_value(r, child(2, O.named:format(O.kinds.number, 'Shine'))), '0.50', 'its kind and its name')
            eq(row_value(r, child(2, O.kinds.finish)), '1', 'no name: its kind only')
            at(r, 0.6, 'down', 'down', 'left')
            eq(row_value(r, child(3, O.channels.r)), '128', 'a Custom colour channel: a child of the colour')
            eq((detail(r)), O.kinds.colour, 'the detail title has no lead mark')
        end, wearing_aria())
    end,
    -- The options page of an outfit EVE does not wear previews it (as Select does), so each change shows at once; the
    -- menu's Back then asks Keep this look? and No reverts. On the worn outfit it previews nothing.
    the_options_page_previews_an_outfit_eve_does_not_wear = function()
        with_aria(function(r)
            r.menu.open()
            at(r, 0.5, 'right')
            same(r.previews, {{{fit = ARIA}}}, 'previewed whole at the open of the page')
            at(r, 0.6, 'back')
            eq(#r.previews, 1, 'Back closes the page: no second preview')
            at(r, 0.7, 'back')
            eq(popups(r), 1, 'Back asks Keep this look?') eq(r.menu.is_open(), true)
            at(r, 0.8, 'no')
            eq(r.reverted, 1, 'No reverts') eq(r.menu.is_open(), false)
        end)
        with_aria(function(r)
            r.menu.open()
            at(r, 0.5, 'right', 'back')
            eq(#r.previews, 0, 'the worn outfit: nothing previewed')
        end, wearing_aria())
    end,
    -- Select on a piece whose controls open below the window scrolls them into view; the piece keeps the focus, shown.
    opened_controls_scroll_into_view = function()
        local O = T.en.closet.options
        with_aria(function(r)
            local item = aria()
            item.UserConfigs.ScalarControls = {{DisplayName = 'Strap 1', MaterialIndex = 6, Value = 0},
                {DisplayName = 'Strap 2', MaterialIndex = 6, Value = 0},
                {DisplayName = 'Strap 3', MaterialIndex = 6, Value = 0}}
            Fits.use({[ARIA] = item})
            r.menu.open()
            -- Header, Variant, two sections with one piece each, Other, Bag (row 8): Bag's three numbers are rows 9-11.
            at(r, 0.5, 'right', 'down', 'down', 'down', 'down', 'down', 'down')
            eq((detail(r)), 'Bag')
            at(r, 0.6, 'select')
            eq((detail(r)), 'Bag', 'the piece keeps the focus')
            eq(row_value(r, child(2, O.named:format(O.kinds.number, 'Strap 3'))), '0.00', 'its last control shown')
            eq(row_value(r, child(1, 'Bag')), O.off, 'the focused piece still shown')
            local looks = {}
            for _, rec in ipairs(r.kit.live(F.OPTION)) do
                if rec.o.Text_TitleValue.text == child(1, 'Bag') then
                    for _, c in ipairs(rec.o.calls) do
                        if c[1] == 'EventNotification' and c[2]:find('^State') then looks[#looks + 1] = c[2] end
                    end
                end
            end
            eq(looks[#looks], 'StateFocus', 'drawn focused')
        end, wearing_aria())
    end,
    reset_stellar_closet_clears_the_options = function()
        with_aria(function(r)
            ok(r.options.set(ARIA, 1, 'toggle:4', false)) ok(r.options.set_variant(ARIA, 3))
            ok(r.store.file ~= nil, 'kept')
            r.menu.open()
            at(r, 0.5, 'down', 'down', 'down', 'select', 'select')
            eq(r.menu.is_open(), false, 'reset') eq(r.offs, 1)
            eq(r.store.file, nil, 'the options file cleared') eq(r.options.variant(ARIA), 1)
            eq(r.options.get(ARIA, 1, 'toggle:4'), true)
        end)
    end,

    a_raising_dress_tick_still_runs_the_menu_tick = function()
        -- closet/wiring.lua's frame tick under main/frame.lua's guard (run below as frame.lua runs it: an error is
        -- logged, the frame goes on).
        -- Each fake is put back as it was, a module not loaded before included (nil: pairs would skip it).
        local saved, faked = {}, {'closet.dress', 'closet.ui.probe', 'closet.colour', 'closet.shape', 'closet.wiring',
            'closet.options', 'closet.commands'}
        for _, name in ipairs(faked) do saved[name] = package.loaded[name] end
        local runs, errors = {}, {}
        package.loaded['closet.commands'] = nil -- Made again over the fake options layer.
        package.loaded['closet.options'] = {FILE = 'coop-closet-options.txt', new = function()
            return {tick = function() runs[#runs + 1] = 'options' end, stop = function() end}
        end}
        package.loaded['closet.shape'] = {FILE = 'coop-closet-shape.txt', new = function()
            return {tick = function() runs[#runs + 1] = 'shape' end, stop = function() end}
        end}
        package.loaded['closet.dress'] = {new = function()
            return {tick = function() runs[#runs + 1] = 'dress'; error('dress broke') end, stop = function() end}
        end}
        package.loaded['closet.ui.probe'] = {new = function()
            return {tick = function() runs[#runs + 1] = 'probe'; error('probe broke') end, stop = function() end}
        end}
        package.loaded['closet.colour'] = {FILE = 'coop-closet-colour.txt', new = function()
            return {tick = function() runs[#runs + 1] = 'colour' end, stop = function() end}
        end}
        package.loaded['closet.wiring'] = nil
        local M = {print = function() end}
        function M.guarded(name, f, ...)
            local ran, why = pcall(f, ...)
            if not ran then errors[#errors + 1] = name .. ': ' .. tostring(why) end
        end
        require('closet.wiring').new(M)
        M.closet_menu = {tick = function() runs[#runs + 1] = 'menu' end}
        M.guarded('closet', M.closet.tick)
        for _, name in ipairs(faked) do package.loaded[name] = saved[name] end
        same(runs, {'dress', 'options', 'colour', 'shape', 'probe', 'menu'}, 'every tick ran, options before colour')
        eq(#errors, 2, 'both errors reported: ' .. table.concat(errors, ' | '))
        ok(errors[1]:find('dress broke', 1, true) and errors[2]:find('probe broke', 1, true),
            table.concat(errors, ' | '))
    end,

    the_camera_opens_and_closes_with_the_menu = function()
        -- A refused open makes no camera; a good one opens it after the draw; every close path closes it, coop off
        -- stops it (also when the menu is closed, for a camera still blending out).
        local cam = fake_camera()
        local r = rig({camera = cam, before = function(r) r.photo = '1' end})
        r.menu.open()
        same(cam.calls, {}, 'refused: no camera')
        local paths = {
            back = function(r) at(r, 1, 'back') end,
            yes = function(r) at(r, 1, 'right', 'right', 'select', 'back', 'select') end,
            no = function(r) at(r, 1, 'right', 'right', 'select', 'back', 'no') end,
            guard = function(r) r.photo = '1'; tick(r, 1) end,
            typed = function(r) at(r, 1, 'right', 'right', 'select'); r.previewing = false; tick(r, 1.5) end,
            close = function(r) r.menu.close() end,
            keep = function(r) r.menu.close('keep') end,
            reset = function(r)
                at(r, 1, 'tab_left', 'tab_left', 'tab_left', 'down', 'down', 'select', 'select')
            end,
            draw = function(r) r.kit.up = false; at(r, 1, 'up') end,
            stop = function(r) r.menu.stop() end,
        }
        for name, path in pairs(paths) do
            cam = fake_camera()
            r = rig({camera = cam})
            on_top(r)
            eq(cam.calls[1], 'open', name .. ': opened')
            path(r)
            eq(r.menu.is_open(), false, name .. ': closed')
            -- Reset Stellar Closet clears the camera file too: the camera forgets its mode and pose after its close.
            local tail = name == 'reset' and 1 or 0
            eq(cam.calls[#cam.calls - tail], name == 'stop' and 'stop' or 'close', name .. ': the camera closed')
            local forgot = 0
            for _, call in ipairs(cam.calls) do if call == 'forget' then forgot = forgot + 1 end end
            eq(forgot, tail, name .. ': forgotten on Reset Stellar Closet only')
            if tail == 1 then eq(cam.calls[#cam.calls], 'forget', 'reset: forgotten after the close') end
        end
        cam = fake_camera()
        r = rig({camera = cam})
        r.menu.stop()
        same(cam.calls, {'stop'}, 'coop off with the menu closed still stops the camera')
        -- A draw that fails at the open never opens the camera.
        cam = fake_camera()
        r = rig({camera = cam, before = function(r) r.kit.fail[F.DETAIL] = true end})
        r.menu.open()
        same(cam.calls, {'close'}, 'no camera on a failed open')
    end,

    the_camera_ticks_with_the_focused_region = function()
        local cam = fake_camera()
        local r = rig({camera = cam})
        tick(r, 0.5)
        eq(cam.ticks[1].region, nil, 'closed: no region')
        r.t = 0.5
        r.menu.open()
        tick(r, 1)
        eq(cam.ticks[2].region, 'full', 'the Full outfit tab')
        ok(math.abs(cam.ticks[2].dt - 0.5) < 1e-9, 'dt since the last tick')
        at(r, 1, 'tab_right', 'tab_right', 'tab_right', 'down', 'down', 'down', 'down', 'down') -- Torso, Top.
        tick(r, 1.1)
        eq(cam.ticks[#cam.ticks].region, 'torso', 'Top: torso')
        at(r, 1.2, 'tab_right', 'down', 'down') -- Arms, Hand tattoo.
        tick(r, 1.3)
        eq(cam.ticks[#cam.ticks].region, 'hands', 'Hand tattoo: hands')
        at(r, 1.4, 'up', 'up', 'up') -- The tabs: the tab's region.
        tick(r, 1.5)
        eq(cam.ticks[#cam.ticks].region, 'arms', 'the Arms tab')
        r.menu.close()
        tick(r, 1.6)
        eq(cam.ticks[#cam.ticks].region, nil, 'closed: ticked without a region')
    end,

    a_back_while_right_mouse_is_held_waits_for_the_camera = function()
        -- A right press may start a camera drag: its Back waits until the camera says the release was a click.
        local cam = fake_camera()
        local r = rig({camera = cam})
        r.menu.open()
        cam.held = true
        at(r, 0.5, 'back')
        ok(r.menu.is_open(), 'right mouse held: no Back yet')
        tick(r, 0.6)
        ok(r.menu.is_open(), 'still held or dragged: no Back')
        cam.held, cam.due = false, true
        tick(r, 0.7)
        ok(not r.menu.is_open(), 'released with no drag: Back closes the unchanged menu')
        r.t = 1
        r.menu.open()
        at(r, 1.5, 'back')
        ok(not r.menu.is_open(), 'right mouse not held (Esc, B): Back at once')
    end,

    camera_words_and_hints_reach_the_camera = function()
        local cam = fake_camera()
        local r = rig({camera = cam})
        r.menu.nav('cam_left')
        same(cam.calls, {}, 'closed: no word')
        r.menu.open()
        at(r, 0.1, 'cam_left', 'cam_right', 'cam_up', 'cam_down', 'cam_in', 'cam_out', 'cam_mode', 'cam_reset',
            'light_next', 'light_up', 'light_down')
        same(cam.calls, {'open', 'cam_left', 'cam_right', 'cam_up', 'cam_down', 'cam_in', 'cam_out', 'cam_mode',
            'cam_reset', 'light_next', 'light_up', 'light_down'}, 'every camera and light word')
        ok(r.menu.is_open(), 'still open')
        -- On the pad, the camera hint row at y 1890 left to right: Preview picture on View (held), the light preset on
        -- L3, the mode on X, Reset on R3.
        r.dev = 3
        tick(r, 0.2)
        local w = T.en.closet
        local function camera_hints() return (camera_row(r)) end
        same(camera_hints(), {{x = 112, text = w.picture.pad, icon = 'UI_SpecialLeft'},
            {x = 600, text = w.light.title:format(w.light.game), icon = 'UI_LeftThumbstick'},
            {x = 1162, text = w.camera.title:format(w.camera.region), icon = 'UI_FaceButton_Left'},
            {x = 1672, text = w.camera.reset_hint, icon = 'UI_RightThumbstick'}}, 'camera hints')
        -- A click on a camera chip runs its word: the mode's, the reset's, then the light's zone.
        local zones = r.kit.groups.closet_menu.zones
        eq(#zones, 19, 'ten rows, five menu hints, four camera chips')
        same({zones[16].x, zones[16].y, zones[16].w}, {1162, 1890, 420}, 'the mode chip zone')
        same({zones[17].x, zones[17].y, zones[17].w}, {1672, 1890, 440}, 'the reset chip zone')
        same({zones[18].x, zones[18].y, zones[18].w}, {600, 1890, 560}, 'the light chip zone')
        zones[16].hover = true
        at(r, 0.5, 'click')
        eq(cam.calls[#cam.calls], 'cam_mode', 'the mode chip')
        zones[16].hover, zones[17].hover = false, true
        at(r, 0.6, 'click')
        eq(cam.calls[#cam.calls], 'cam_reset', 'the reset chip')
        zones[17].hover, zones[18].hover = false, true
        at(r, 0.65, 'click')
        eq(cam.calls[#cam.calls], 'light_next', 'the light chip')
        zones[18].hover = false
        -- The pad's X switched the mode inside the camera: the next tick shows it.
        cam.now = 'free'
        tick(r, 0.7)
        eq(camera_hints()[3].text, w.camera.title:format(w.camera.free), 'the mode word follows the camera')
        -- The pad's L3 changed the preset, Shift+O the intensity: the next tick shows them.
        cam.preset, cam.factor = 'studio', 1.25
        tick(r, 0.75)
        eq(camera_hints()[2].text, w.light.title:format(w.light.studio .. ' x1.25'), 'the preset and its intensity')
        cam.factor = 1
        tick(r, 0.76)
        eq(camera_hints()[2].text, w.light.title:format(w.light.studio .. ' x1'), 'x1')
        -- A camera that stopped (the game took the view) shows no hints.
        cam.on = false
        tick(r, 0.8)
        same(camera_hints(), {}, 'no camera: no camera hints')
    end,

    keyboard_hints_show_kit_keys_and_no_sb_glyph = function()
        -- On the keyboard (SB's device byte 1 or 2, or 0 / nil before its first report) the camera row is kit text:
        -- the closet's own key, then its label. No SB part: SB would draw its own key for the action (T, G).
        for _, byte in ipairs({1, 2, 0, false}) do
            local dev = tostring(byte)
            local cam = fake_camera()
            local r = rig({camera = cam, uidev = byte or nil})
            r.menu.open()
            local w = T.en.closet
            local parts, texts = camera_row(r)
            same(parts, {}, dev .. ': no SB part in the camera row')
            eq(#texts, 8, dev .. ': four keys and four labels')
            same({texts[1].x, texts[1].s}, {112, w.keys.picture}, dev .. ': the picture key')
            eq(texts[2].s, w.picture.hint, dev .. ': the picture label')
            ok(texts[2].x >= 112 + text_width(w.keys.picture), dev .. ': the label after its key')
            same({texts[3].x, texts[3].s}, {600, w.keys.light}, dev .. ': the light key')
            eq(texts[4].s, w.light.title:format(w.light.game), dev .. ': the light label')
            ok(texts[4].x >= 600 + text_width(w.keys.light), dev .. ': the label after its key')
            same({texts[5].x, texts[5].s}, {1162, w.keys.mode}, dev .. ': the mode key')
            eq(texts[6].s, w.camera.title:format(w.camera.region), dev .. ': the mode label')
            ok(texts[6].x >= 1162 + text_width(w.keys.mode), dev .. ': the label after its key')
            same({texts[7].x, texts[7].s}, {1672, w.keys.reset}, dev .. ': the reset key')
            eq(texts[8].s, w.camera.reset_hint, dev .. ': the reset label')
            ok(texts[8].x >= 1672 + text_width(w.keys.reset), dev .. ': the label after its key')
            for _, t in ipairs(r.kit.groups.closet_menu.texts) do
                if t.y == 1899 then eq(t.style, 'hint', 'the hint style') end
            end
            -- A click on a chip still runs its word.
            local zones = r.kit.groups.closet_menu.zones
            zones[18].hover = true
            at(r, 0.5, 'click')
            eq(cam.calls[#cam.calls], 'light_next', dev .. ': the light chip')
            zones[18].hover = false
            -- The camera stopped: the row shows nothing.
            cam.on = false
            tick(r, 0.6)
            parts, texts = camera_row(r)
            same(texts, {}, dev .. ': no camera: no key texts')
        end
    end,

    pad_hints_use_sb_parts = function()
        -- On a pad (device byte 3 to 6) the camera row is SB's hint parts, which draw the pad's glyphs; the kit texts
        -- show nothing.
        for dev = 3, 6 do
            local r = rig({camera = fake_camera(), uidev = dev})
            r.menu.open()
            local w = T.en.closet
            local parts, texts = camera_row(r)
            same(parts, {{x = 112, text = w.picture.pad, icon = 'UI_SpecialLeft'},
                {x = 600, text = w.light.title:format(w.light.game), icon = 'UI_LeftThumbstick'},
                {x = 1162, text = w.camera.title:format(w.camera.region), icon = 'UI_FaceButton_Left'},
                {x = 1672, text = w.camera.reset_hint, icon = 'UI_RightThumbstick'}}, dev .. ': SB parts')
            same(texts, {}, dev .. ': no kit text')
        end
    end,

    a_device_switch_redraws_the_hints = function()
        local cam = fake_camera()
        local r = rig({camera = cam, uidev = 1})
        r.menu.open()
        local w = T.en.closet
        local parts, texts = camera_row(r)
        eq(#parts, 0, 'keyboard: no SB part') eq(#texts, 8, 'keyboard: kit texts')
        ok(r.kit.live(F.DETAIL)[1].o.DescriptionText.text:find(w.camera.moves.region.key, 1, true),
            'keyboard: the keyboard camera line')
        r.dev = 4 -- The pad used: SB reports it.
        tick(r, 0.1)
        parts, texts = camera_row(r)
        eq(#parts, 4, 'pad: SB parts') eq(#texts, 0, 'pad: no kit text')
        local desc = r.kit.live(F.DETAIL)[1].o.DescriptionText.text
        ok(desc:find(w.camera.moves.region.pad, 1, true), 'pad: the pad camera line')
        ok(not desc:find(w.camera.moves.region.key, 1, true), 'pad: no keyboard camera line')
        r.dev = 2 -- Back on the keyboard.
        tick(r, 0.2)
        parts, texts = camera_row(r)
        eq(#parts, 0, 'keyboard again: no SB part') eq(#texts, 8, 'keyboard again: kit texts')
        -- The Free mode's line on each device.
        cam.now = 'free'
        tick(r, 0.3)
        ok(r.kit.live(F.DETAIL)[1].o.DescriptionText.text:find(w.camera.moves.free.key, 1, true), 'Free: keyboard')
        r.dev = 3
        tick(r, 0.4)
        ok(r.kit.live(F.DETAIL)[1].o.DescriptionText.text:find(w.camera.moves.free.pad, 1, true), 'Free: pad')
    end,

    camera_chips_never_overlap = function()
        -- Each camera chip's estimated width (Bold 30 at 17 units a character, 30 a CJK one) fits its click zone, the
        -- zones keep apart and end by the menu's edge, on both devices, in every language.
        local r = rig({camera = fake_camera(), uidev = 1})
        r.menu.open()
        local zones = r.kit.groups.closet_menu.zones
        local slots = {light = zones[18], mode = zones[16], reset = zones[17], picture = zones[19]}
        ok(slots.picture.x + slots.picture.w <= slots.light.x, 'picture zone before light zone')
        ok(slots.light.x + slots.light.w <= slots.mode.x, 'light zone before mode zone')
        ok(slots.mode.x + slots.mode.w <= slots.reset.x, 'mode zone before reset zone')
        ok(slots.reset.x + slots.reset.w <= 2112, 'reset zone by the edge')
        -- Where each keyboard label starts after its slot's left edge, as drawn.
        local _, texts = camera_row(r)
        local col = {picture = texts[2].x - slots.picture.x, light = texts[4].x - slots.light.x,
            mode = texts[6].x - slots.mode.x, reset = texts[8].x - slots.reset.x}
        local checked = 0
        for lang, t in pairs(T) do
            local w = type(t) == 'table' and t.closet
            if w then
                checked = checked + 1
                local labels = {light = {}, mode = {w.camera.title:format(w.camera.region),
                    w.camera.title:format(w.camera.free)}, reset = {w.camera.reset_hint},
                    picture = {w.picture.hint, w.picture.pad}}
                for preset, name in pairs(w.light) do
                    if preset ~= 'title' then
                        labels.light[#labels.light + 1] = w.light.title:format(name .. (preset ~= 'game' and ' x1.25' or ''))
                    end
                end
                for slot, list in pairs(labels) do
                    ok(text_width(w.keys[slot]) + 12 <= col[slot], lang .. ' ' .. slot .. ' key before its label')
                    for _, label in ipairs(list) do
                        local key = col[slot] + text_width(label)
                        local pad = SB_ICON + text_width(label)
                        -- The picture chip's labels differ by device: its keyboard one, its pad one (View held).
                        if label ~= w.picture.pad then
                            ok(key <= slots[slot].w,
                                lang .. ' keyboard ' .. slot .. ': ' .. label .. ' (' .. key .. ')')
                        end
                        if label ~= w.picture.hint then
                            ok(pad <= slots[slot].w, lang .. ' pad ' .. slot .. ': ' .. label .. ' (' .. pad .. ')')
                        end
                    end
                end
            end
        end
        eq(checked, 22, 'every language table checked (ui/text.lua\'s 22)')
    end,

    every_prompt_follows_the_device = function()
        -- Walk every tab, row and grid, then both popups, on the keyboard and on a pad: after each step the camera row
        -- and the detail's camera line are the device's. No SB part's label names a keyboard key. On the keyboard each
        -- SB part is one whose action SB maps to the closet's own key (Back, Select, F, the D-pad, Q / E).
        local MAPPED = {Negative = true, Positive = true, UI_FaceButton_Top = true, UI_DPad_Up = true,
            UI_DPad_Down = true, UI_LeftShoulder = true, UI_RightShoulder = true}
        local CAMERA = {UI_LeftThumbstick = true, UI_FaceButton_Left = true, UI_RightThumbstick = true,
            UI_SpecialLeft = true}
        for _, dev in ipairs({1, 3}) do
            local pad = dev >= 3
            local cam = fake_camera()
            local r = rig({camera = cam, uidev = dev})
            local w = T.en.closet
            local steps = 0
            local function no_key(text, what)
                for _, key in pairs(w.keys) do
                    ok(not (text or ''):find('%f[%w]' .. key .. '%f[%W]'), what .. ' names the key ' .. key .. ': ' ..
                        tostring(text))
                end
            end
            local function check(what)
                steps = steps + 1
                what = dev .. ' ' .. what
                for _, h in ipairs(r.kit.live(F.HINT)) do
                    local text, icon
                    for _, c in ipairs(h.o.calls) do
                        if c[1] == 'SetText' then text = c[2].text elseif c[1] == 'SetResourceAction' then icon = c[2] end
                    end
                    no_key(text, what .. ' SB part')
                    if pad then ok(MAPPED[icon] or CAMERA[icon], what .. ': pad part ' .. tostring(icon))
                    else ok(MAPPED[icon], what .. ': keyboard part ' .. tostring(icon)) end
                end
                local parts, texts = camera_row(r)
                eq(#parts, pad and 4 or 0, what .. ': camera SB parts')
                eq(#texts, pad and 0 or 8, what .. ': camera kit texts')
                local d = r.kit.live(F.DETAIL)[1]
                local desc = d and d.o.DescriptionText and d.o.DescriptionText.text or ''
                local mine, other = w.camera.moves[cam.now], nil
                mine, other = mine[pad and 'pad' or 'key'], mine[pad and 'key' or 'pad']
                ok(desc:find(w.camera.title:format(mine), 1, true), what .. ': the device\'s camera line')
                ok(not desc:find(other, 1, true), what .. ': not the other device\'s line')
                for _, p in ipairs(r.kit.live(F.POPUP)) do
                    no_key(p.o.TitleText.text, what .. ' popup title')
                    no_key(p.o.DescText.text, what .. ' popup text')
                end
            end
            r.menu.open()
            check('open')
            local tabs = 0
            for _ in pairs(w.tabs) do tabs = tabs + 1 end
            for t = 1, tabs do
                for _ = 1, 20 do at(r, 0.05, 'up') end -- The tab row.
                check('tab ' .. t .. ' tabs')
                -- Each row; on a row of pieces, into its grid and a tile on, then back out (left on the first tile).
                for i = 1, 16 do
                    at(r, 0.05, 'down') check('tab ' .. t .. ' row ' .. i)
                    at(r, 0.05, 'right') check('tab ' .. t .. ' row ' .. i .. ' right')
                    at(r, 0.05, 'right') check('tab ' .. t .. ' row ' .. i .. ' right 2')
                    at(r, 0.05, 'left', 'left') check('tab ' .. t .. ' row ' .. i .. ' left')
                end
                cam.now = cam.now == 'region' and 'free' or 'region' -- Both modes' lines.
                at(r, 0.05, 'tab_right') check('tab ' .. t)
            end
            -- The Keep popup (a piece worn, then Back), then the Reset popup.
            -- A new menu (its first open shows the Full tab): a top worn on the torso tab, then Back.
            r.menu.close('keep')
            r = rig({camera = cam, uidev = dev})
            on_top(r)
            at(r, 0.5, 'right', 'right', 'select', 'back')
            eq(popups(r), 1, dev .. ': Keep this look?') check('keep popup')
            at(r, 0.6, 'no')
            r.t = 1
            r.menu.open()
            -- The Full tab's Reset row.
            at(r, 1.5, 'tab_left', 'tab_left', 'tab_left', 'down', 'down', 'select')
            eq(popups(r), 1, dev .. ': Reset Stellar Closet?') check('reset popup')
            ok(steps > 100, dev .. ': every step checked')
        end
    end,

    the_wiring_gives_the_menu_its_camera = function()
        -- closet/wiring.lua's menu step: the camera with coop-closet-camera.txt through the link, the kit's screen and
        -- main/boot.lua's pad reads read at each call (nil with an older DLL), handed to the menu.
        local dress = rig().dress -- First: rig loads the menu again.
        local Camera, Menu = require('closet.ui.camera'), require('closet.ui.menu')
        local camera_new, menu_new = Camera.new, Menu.new
        local got, menu_got
        Camera.new = function(o) got = o; return camera_new(o) end
        Menu.new = function(o) menu_got = o; return menu_new(o) end
        package.loaded['closet.wiring'] = nil
        local stored = {}
        local kit = F.kit()
        kit.screen = function() return {w = 3840, h = 2160} end
        local M = {print = function() end, kit = kit, closet = dress, words = function() return T.en end,
            tell = function() end, photo_state = function() return '0' end, closet_thumbs = {run = function() end},
            closet_colour = fake_colour(), closet_shape = fake_shape(),
            link = {status = function() return '' end, uidev = function() return 4 end, store = function(name)
                stored[#stored + 1] = name
                return {save = function() return true end, load = function() end, clear = function() end}
            end}}
        local ran, why = pcall(require('closet.wiring').build.menu, M)
        Camera.new, Menu.new = camera_new, menu_new
        ok(ran, tostring(why))
        same(stored, {'coop-closet-camera.txt'}, 'the camera file through the link')
        ok(got.screen == kit.screen, 'the kit\'s screen')
        eq(got.pad_bits(), nil, 'no pad bits with an older DLL')
        eq(got.pad_levels(), nil, 'no pad levels with an older DLL')
        M.pad_bits, M.pad_levels = function() return 5 end, function() return 0.5, -0.5, 0, 1 end
        eq(got.pad_bits(), 5, 'the pad bits')
        same({got.pad_levels()}, {0.5, -0.5, 0, 1}, 'the pad levels')
        ok(menu_got.camera ~= nil and menu_got.camera.word ~= nil, 'the menu has the camera')
        ok(menu_got.thumbs == M.closet_thumbs, 'the menu has coop closet thumbs (its Clear preview pictures row)')
        ok(menu_got.colour == M.closet_colour, 'the menu has the colour layer (its Colour tab)')
        ok(menu_got.shape == M.closet_shape, 'the menu has the shape layer (the Body tab\'s shape rows)')
        ok(menu_got.uidev == M.link.uidev, 'the menu reads SB\'s input device through the link (its prompts follow it)')
    end,

    the_wiring_builds_the_shape_layer = function()
        -- closet/wiring.lua's new: the shape layer over the dress with coop-closet-shape.txt through the link, as
        -- M.closet_shape; ticked each frame right after the colour layer (menu open or not), stopped by coop off; the
        -- values of coop closet shape.
        local saved = {}
        for _, name in ipairs({'closet.dress', 'closet.ui.probe', 'closet.wiring'}) do
            saved[name] = package.loaded[name]
        end
        local runs = {}
        package.loaded['closet.dress'] = {new = function()
            return {tick = function() runs[#runs + 1] = 'dress' end, stop = function() end,
                installed = function() return true end, applied = function() return 0 end,
                parts = function() return {} end}
        end}
        package.loaded['closet.ui.probe'] = {new = function()
            return {tick = function() end, stop = function() end}
        end}
        package.loaded['closet.wiring'] = nil
        local Shape = require('closet.shape')
        local shape_new, got = Shape.new, nil
        Shape.new = function(o) got = o; return shape_new(o) end
        local stored, files = {}, {}
        local M = {print = function() end, guarded = function(_, f, ...) return f(...) end,
            link = {status = function() return '' end, store = function(name)
                stored[#stored + 1] = name
                return {save = function(line) files[name] = line; return true end,
                    load = function() return files[name] end, clear = function() files[name] = nil end}
            end}}
        local ran, why = pcall(function()
            local commands = require('closet.wiring').new(M)
            ok(M.closet_shape ~= nil, 'M.closet_shape')
            ok(got.dress == M.closet, 'over the dress')
            local named = false
            for _, name in ipairs(stored) do named = named or name == 'coop-closet-shape.txt' end
            ok(named, 'coop-closet-shape.txt through the link: ' .. table.concat(stored, ', '))
            local colour_tick, shape_tick = M.closet_colour.tick, M.closet_shape.tick
            M.closet_colour.tick = function() runs[#runs + 1] = 'colour'; return colour_tick() end
            M.closet_shape.tick = function() runs[#runs + 1] = 'shape'; return shape_tick() end
            M.closet.tick()
            same({runs[1], runs[2], runs[3]}, {'dress', 'colour', 'shape'}, 'the shape tick right after the colour')
            local good, line = commands.closet('shape', 'Butt', '50', nil, nil, nil)
            ok(good, line)
            eq(files['coop-closet-shape.txt'], 'Butt=50', 'coop closet shape sets the value')
            local stop = M.closet_shape.stop
            M.closet_shape.stop = function() runs[#runs + 1] = 'shape stop'; return stop() end
            M.closet.stop()
            local stopped = false
            for _, r in ipairs(runs) do stopped = stopped or r == 'shape stop' end
            ok(stopped, 'coop off stops it')
        end)
        Shape.new = shape_new
        for name, mod in pairs(saved) do package.loaded[name] = mod end
        ok(ran, tostring(why))
    end,

    the_wiring_builds_the_colour_layer = function()
        -- closet/wiring.lua's new: the colour layer over the dress with coop-closet-colour.txt through the link, as
        -- M.closet_colour; ticked each frame right after the dress (menu open or not), stopped by coop off; the palette
        -- of coop closet colour.
        local saved = {}
        for _, name in ipairs({'closet.dress', 'closet.ui.probe', 'closet.wiring'}) do
            saved[name] = package.loaded[name]
        end
        local runs = {}
        package.loaded['closet.dress'] = {new = function()
            return {tick = function() runs[#runs + 1] = 'dress' end,
                stop = function() runs[#runs + 1] = 'dress stop' end,
                installed = function() return true end, applied = function() return 0 end,
                parts = function() return {} end}
        end}
        package.loaded['closet.ui.probe'] = {new = function()
            return {tick = function() end, stop = function() end}
        end}
        package.loaded['closet.wiring'] = nil
        local Colour = require('closet.colour')
        local colour_new, got = Colour.new, nil
        Colour.new = function(o) got = o; return colour_new(o) end
        local stored, files = {}, {}
        local M = {print = function() end, guarded = function(_, f, ...) return f(...) end,
            link = {status = function() return '' end, store = function(name)
                stored[#stored + 1] = name
                return {save = function(line) files[name] = line; return true end,
                    load = function() return files[name] end, clear = function() files[name] = nil end}
            end}}
        local ran, why = pcall(function()
            local commands = require('closet.wiring').new(M)
            ok(M.closet_colour ~= nil, 'M.closet_colour')
            ok(got.dress == M.closet, 'over the dress')
            local named = false
            for _, name in ipairs(stored) do named = named or name == 'coop-closet-colour.txt' end
            ok(named, 'coop-closet-colour.txt through the link: ' .. table.concat(stored, ', '))
            local tick = M.closet_colour.tick
            M.closet_colour.tick = function() runs[#runs + 1] = 'colour'; return tick() end
            M.closet.tick()
            eq(runs[1], 'dress') eq(runs[2], 'colour', 'the colour tick right after the dress\'s')
            local good, line = commands.closet('colour', 'accent', 'gold', nil, nil, nil)
            ok(good, line)
            eq(files['coop-closet-colour.txt'], 'accent=gold', 'coop closet colour sets the palette')
            local stop = M.closet_colour.stop
            M.closet_colour.stop = function() runs[#runs + 1] = 'colour stop'; return stop() end
            M.closet.stop()
            local stopped = false
            for _, r in ipairs(runs) do stopped = stopped or r == 'colour stop' end
            ok(stopped, 'coop off stops it')
        end)
        Colour.new = colour_new
        for name, mod in pairs(saved) do package.loaded[name] = mod end
        ok(ran, tostring(why))
    end,

    every_close_path_drops_every_part = function()
        local paths = {
            back = function(r) at(r, 1, 'back') end,
            yes = function(r) at(r, 1, 'right', 'right', 'select', 'back', 'select') end,
            no = function(r) at(r, 1, 'right', 'right', 'select', 'back', 'no') end,
            popup_then_reset = function(r) at(r, 1, 'right', 'right', 'select', 'back'); r.menu.close() end,
            guard = function(r) r.photo = '1'; tick(r, 1) end,
            typed = function(r) at(r, 1, 'right', 'right', 'select'); r.previewing = false; tick(r, 1.5) end,
            stop = function(r) r.menu.stop() end,
            close = function(r) r.menu.close() end,
            keep = function(r) r.menu.close('keep') end,
            reset = function(r)
                at(r, 1, 'tab_left', 'tab_left', 'tab_left', 'down', 'down', 'select', 'select')
            end,
        }
        for name, path in pairs(paths) do
            local r = rig()
            on_top(r)
            path(r)
            local good, why = pcall(all_gone, r)
            ok(good, name .. ': ' .. tostring(why))
            local calls = #r.kit.inputs
            r.menu.tick() -- Closed: nothing.
            r.menu.nav('back')
            eq(#r.kit.inputs, calls, name .. ': nothing after the close')
        end
    end,

    -- F on an outfit's row marks it as a favourite (Select still wears it); the hint says Favourite, then Unfavourite,
    -- on the top face button's action (SB draws F on the keyboard, the pad's button on a pad). The filter row turns
    -- All / Favourites.
    f_toggles_the_focused_favourite = function()
        local P, H = T.en.closet.presets, T.en.closet.hints
        with_presets(function(r)
            r.menu.open()
            eq((detail(r)), P.save, 'Save look as preset first')
            at(r, 0.5, 'down')
            eq((detail(r)), P.filter, 'then the filter row') eq(row_value(r, P.filter), P.all, 'All at first')
            same(menu_hints(r), {{T.en.hint.back, 'Negative', 'None'}, {H.change, 'UI_DPad_Left', 'UI_DPad_Right'},
                {T.en.hint.move, 'UI_DPad_Up', 'UI_DPad_Down'}}, 'the filter row\'s hints')
            at(r, 0.6, 'down')
            eq((detail(r)), 'Aria', 'the first outfit')
            same(menu_hints(r), {{T.en.hint.back, 'Negative', 'None'}, {H.whole, 'Positive', 'None'},
                {H.options, 'UI_DPad_Right', 'None'}, {H.fav, 'UI_FaceButton_Top', 'None'},
                {T.en.hint.move, 'UI_DPad_Up', 'UI_DPad_Down'}}, 'the Favourite hint, Move still shown')
            at(r, 0.7, 'refresh')
            eq(r.presets.is_fav(ARIA), true, 'F marks it') eq(#r.previews, 0, 'F wears nothing')
            eq(row_value(r, 'Aria'), P.fav:format('aria'), 'the row says it, whole')
            eq(menu_hints(r)[4][1], H.unfav, 'the hint turns')
            r.dev = 4 -- A pad: the same action, SB draws the pad's button.
            tick(r, 0.75)
            eq(menu_hints(r)[4][2], 'UI_FaceButton_Top', 'the pad\'s top face button')
            at(r, 0.8, 'up', 'right')
            eq(row_value(r, P.filter), P.favourites, 'the filter on Favourites')
            at(r, 0.9, 'down')
            eq((detail(r)), 'Aria', 'the favourite listed')
            at(r, 1, 'down')
            eq((detail(r)), T.en.closet.row.reset, 'no other outfit: Reset Stellar Closet next')
            at(r, 1.1, 'up', 'select')
            same(r.previews[1], {{fit = ARIA}}, 'Select still wears the outfit')
            at(r, 1.2, 'refresh')
            eq(r.presets.is_fav(ARIA), false, 'F again: not a favourite')
            eq((detail(r)), T.en.closet.row.reset, 'it leaves the Favourites list')
        end)
    end,
    -- The filter row turns All, Favourites, Original, Custom with right or Select, back with left; Original lists
    -- Shift Up's own suits under their header, Custom the pack and hand outfits.
    the_filter_turns_through_four_lists = function()
        local P, O = T.en.closet.presets, T.en.closet.origin
        Fits.BY_ID[MAID].Origin = 'original'
        local good, why = pcall(function()
            with_presets(function(r)
                r.menu.open()
                at(r, 0.5, 'down')
                eq(row_value(r, P.filter), P.all, 'All at first')
                at(r, 0.6, 'right')
                eq(row_value(r, P.filter), P.favourites, 'then Favourites')
                at(r, 0.7, 'select')
                eq(row_value(r, P.filter), O.original, 'then Original')
                at(r, 0.8, 'down')
                eq((detail(r)), T.en.closet.original, 'Original: the header first')
                at(r, 0.9, 'down')
                eq((detail(r)), 'Ocean Maid', 'the Original suit')
                at(r, 1, 'down')
                eq((detail(r)), T.en.closet.row.reset, 'no Custom suit')
                at(r, 1.1, 'up', 'up', 'up', 'right')
                eq(row_value(r, P.filter), P.custom, 'then Custom')
                at(r, 1.2, 'down')
                eq((detail(r)), 'Aria', 'Custom: a pack outfit, no header')
                at(r, 1.3, 'up', 'right')
                eq(row_value(r, P.filter), P.all, 'round to All')
                at(r, 1.4, 'left')
                eq(row_value(r, P.filter), P.custom, 'left from All: Custom')
                at(r, 1.5, 'left')
                eq(row_value(r, P.filter), O.original, 'left again: Original')
            end)
        end)
        Fits.BY_ID[MAID].Origin = nil
        ok(good, why)
    end,
    -- Save look as preset keeps the worn outfit as Preset n; Select on a preset wears it as a preview; F asks Delete
    -- this preset? with the game's Yes/No popup: No keeps it, Yes deletes it.
    delete_asks_yes_no = function()
        local P, H = T.en.closet.presets, T.en.closet.hints
        with_presets(function(r)
            r.choices = {{fit = 'AiK_CH27_14595', slots = {'Chest'}}}
            r.menu.open()
            at(r, 0.5, 'select')
            eq(#r.presets.list(), 0, 'pieces of an outfit: no preset')
            eq(r.told[#r.told], P.none, 'said why')
            r.choices = {{fit = ARIA}}
            r.options.set_variant(ARIA, 3)
            at(r, 0.6, 'select')
            eq(#r.presets.list(), 1, 'saved') eq(r.told[#r.told], P.saved:format(P.name:format(1)), 'told')
            at(r, 0.7, 'down')
            local title, desc = detail(r)
            eq(title, P.name:format(1), 'Preset 1') ok(desc:find('Aria', 1, true), desc)
            eq(row_value(r, P.name:format(1)), 'Aria', 'its outfit as the value')
            same(menu_hints(r), {{T.en.hint.back, 'Negative', 'None'}, {H.wear, 'Positive', 'None'},
                {H.delete, 'UI_FaceButton_Top', 'None'}, {T.en.hint.move, 'UI_DPad_Up', 'UI_DPad_Down'}},
                'the preset\'s hints')
            r.options.set_variant(ARIA, 1)
            r.choices = nil
            at(r, 0.8, 'select')
            same(r.previews[1], {{fit = ARIA}}, 'Select wears it as a preview')
            eq(r.options.variant(ARIA), 3, 'with its variant')
            at(r, 0.9, 'refresh')
            eq(popups(r), 1, 'Delete this preset? asks')
            at(r, 1, 'no')
            eq(popups(r), 0, 'No: the popup goes') eq(#r.presets.list(), 1, 'kept')
            at(r, 1.1, 'refresh', 'yes')
            eq(#r.presets.list(), 0, 'Yes: deleted') eq(r.menu.is_open(), true, 'the menu stays open')
            eq((detail(r)), P.filter, 'the focus on the row that took its place')
        end)
    end,
    -- A preset worn as a preview and turned down (No at Keep this look?, a guard's close, coop off) gives its outfit
    -- the variant and values it had before; Yes keeps the preset's.
    -- A preset whose preview fails (dress.preview false: no EVE during a map change) gives its outfit the variant and
    -- values it had before, at once; told once.
    a_failed_preset_preview_gives_the_options_back = function()
        with_presets(function(r)
            r.choices = {{fit = ARIA}}
            ok(r.options.set_variant(ARIA, 3)) ok(r.options.set(ARIA, 3, 'toggle:4', false))
            eq(r.presets.save(), 1, 'Preset 1: variant 3, Boots off')
            ok(r.options.set(ARIA, 3, 'toggle:4', true)) ok(r.options.set_variant(ARIA, 1))
            r.choices = nil
            r.dress.preview = function() return false, 'closet: no EVE in the world' end
            r.menu.open()
            local told = #r.told
            at(r, 0.5, 'down', 'select')
            eq(r.options.variant(ARIA), 1, 'the variant from before')
            same(r.options.words(ARIA, 3), {}, 'variant 3\'s values from before')
            eq(#r.told, told + 1, 'told once')
        end)
    end,
    turned_down_preset_gives_the_options_back = function()
        local function worn(r, t)
            r.choices = {{fit = ARIA}}
            ok(r.options.set_variant(ARIA, 3)) ok(r.options.set(ARIA, 3, 'toggle:4', false))
            eq(r.presets.save(), 1, 'Preset 1: variant 3, Boots off')
            ok(r.options.set(ARIA, 3, 'toggle:4', true)) ok(r.options.set(ARIA, 3, 'toggle:6', true))
            ok(r.options.set_variant(ARIA, 1))
            r.choices = nil
            r.menu.open()
            at(r, t, 'down', 'select')
            eq(r.options.variant(ARIA), 3, 'the preview wears its variant')
            same(r.options.words(ARIA, 3), {'toggle:4=off'}, 'and its values')
        end
        with_presets(function(r)
            worn(r, 0.5)
            at(r, 0.6, 'back', 'no')
            eq(r.menu.is_open(), false, 'No closes')
            eq(r.options.variant(ARIA), 1, 'No: the variant from before')
            same(r.options.words(ARIA, 3), {'toggle:6=on'}, 'No: variant 3\'s values from before')
        end)
        with_presets(function(r)
            worn(r, 0.5)
            r.world = false
            tick(r, 2)
            eq(r.menu.is_open(), false, 'a guard closes')
            eq(r.options.variant(ARIA), 1, 'a guard\'s close: the variant from before')
            same(r.options.words(ARIA, 3), {'toggle:6=on'}, 'a guard\'s close: the values from before')
        end)
        with_presets(function(r)
            worn(r, 0.5)
            r.menu.stop()
            eq(r.options.variant(ARIA), 1, 'coop off: the variant from before')
        end)
        with_presets(function(r)
            worn(r, 0.5)
            at(r, 0.6, 'back', 'yes')
            eq(r.confirmed, 1, 'Yes confirms')
            eq(r.options.variant(ARIA), 3, 'Yes: the preset\'s variant kept')
            same(r.options.words(ARIA, 3), {'toggle:4=off'}, 'Yes: its values kept')
        end)
    end,
}

run('menu_test', tests)
