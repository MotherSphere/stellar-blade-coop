-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The closet menu (closet/ui/menu.lua over closet/ui/view.lua) on menu_fakes.lua's fake kit and parts: open draws the
-- tab row, the slot rows, the grid with the None tile first, the detail panel and the hints; coop closet menu opens
-- and closes it; every close path drops every part and gives the input back; coop off does not revert; a draw that
-- raises closes the menu.
local run = dofile('tests/lua/closet/run.lua')
package.loaded.UEHelpers = {GetPlayer = function() return nil end}
local F = dofile('tests/lua/closet/menu_fakes.lua')
local T = require('ui.text')
local Fits = require('closet.fits')
-- No enemy near EVE in these tests: core/player.lua's engaged walks the game's actors.
require('core.player').engaged = function() return false end

local function rig(o)
    o = o or {}
    local r = {told = {}, log = {}, reverted = 0, confirmed = 0, previews = {}, previewing = false, t = 0,
        world = true, photo = '0', status = 'mod=1 theater=none', kit = F.kit()}
    if o.before then o.before(r) end
    package.loaded['closet.ui.menu'], package.loaded['closet.ui.view'] = nil, nil
    local Menu = require('closet.ui.menu')
    -- The dress: a preview wears its choices and starts previewing; confirm and revert end it.
    r.dress = {installed = o.installed or function() return true end, choices = function() return r.choices end,
        preview = function(c)
            if #c == 0 then return false, 'nothing to wear' end -- closet/dress.lua's Dress.plan refuses an empty look.
            r.previews[#r.previews + 1] = c; r.choices, r.previewing = c, true; return true
        end,
        previewing = function() return r.previewing end,
        confirm = function() r.confirmed = r.confirmed + 1; r.previewing = false; return true, 'closet: confirmed' end,
        revert = function() r.reverted = r.reverted + 1; r.previewing = false; return true, 'closet: reverted' end,
        game_look = function() return r.game_look end}
    r.menu = Menu.new({kit = r.kit, dress = r.dress, words = function() return T.en end,
        tell = function(build) r.told[#r.told + 1] = build(T.en) end, log = function(m) r.log[#r.log + 1] = m end,
        world = function() return r.world end, photo = function() return r.photo end,
        status = function() return r.status end, now = function() return r.t end})
    return r
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
-- The Top row (Chest) of the torso tab, open: tiles None, Maid top (Ocean Maid), Kunoichi top (Kunoichi Shadow).
local MAID, KUNOICHI = 'AiK_CH27_14595', 'AiK_CH46_xSH_14462'
local function on_top(r)
    r.menu.open()
    at(r, 0.05, 'down')
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
    r.kit.input = function(on, who, mouse)
        if not on and r.kit.no_pc then r.kit.inputs[#r.kit.inputs + 1] = {on, who, mouse}; return end
        input(on, who, mouse)
    end
end

local tests = {
    opens_and_draws_the_parts = function()
        local r = rig()
        local good, line = r.menu.open()
        ok(good, line)
        eq(r.menu.is_open(), true, 'is_open')
        same(r.kit.inputs[1], {true, 'closet_menu', true}, 'input')
        eq(r.kit.sounds[1], 'open', 'sound')
        eq(r.kit.shown.closet_menu, true, 'group shown')
        local g = r.kit.groups.closet_menu
        same(g.place, {x = 0, y = 0, w = 3840, h = 2160, fixed = true, hit = true}, 'group place')
        same(g.shade, {x = 0, y = 0, w = 2560, h = 2160, color = {A = 0.72}}, 'shade')
        eq(g.images[1].tex, 'dither', 'dither') eq(g.images[1].y, 1860, 'dither y') eq(g.images[1].w, 2560, 'dither w')
        same(g.images[1].tint, {A = 0.8}, 'dither tint')
        -- The tab row: one tab button a tab, labelled; the first tab with pieces (torso) focused.
        local tabs = r.kit.live(F.TAB)
        eq(#tabs, 8, 'tabs')
        for i, id in ipairs({'head', 'torso', 'arms', 'hips', 'legs', 'body', 'weapon', 'full'}) do
            eq(tabs[i].o.TextValue.text, T.en.closet.tabs[id], 'tab ' .. i)
            ok(F.called(tabs[i].o, 'RefreshDesign'), 'tab RefreshDesign ' .. i)
            ok(F.called(tabs[i].o, i == 2 and 'FocusTabButton' or 'DefocusTabButton'), 'tab focus ' .. i)
            ok(tabs[i].x >= 160 and tabs[i].x < 2560, 'tab x ' .. i)
        end
        -- The torso rows in a window of 10: a soon row locked, Bra focused with Leotard worn nowhere (None).
        local rows = r.kit.live(F.OPTION)
        eq(#rows, 10, 'rows')
        eq(rows[1].o.Text_TitleValue.text, 'Chest tattoo', 'row 1')
        eq(rows[1].o.Text_ItemValue.text, T.en.closet.row.soon, 'row 1 value')
        eq(rows[1].o.bLockItem, true, 'row 1 locked')
        ok(F.called(rows[1].o, 'EventNotification', 'RefreshAppearance'), 'row 1 locked look')
        eq(rows[5].o.Text_TitleValue.text, 'Bra', 'row 5')
        eq(rows[5].o.Text_ItemValue.text, 'None', 'row 5 value')
        ok(F.called(rows[5].o, 'EventNotification', 'StateFocus'), 'row 5 focused')
        ok(not F.called(rows[4].o, 'EventNotification', 'StateFocus'), 'row 4 not focused')
        -- A transparent kit row over each slot row takes the mouse; it shows nothing while the part is there.
        eq(#g.zones, 10, 'zones')
        for i, z in ipairs(g.zones) do eq(z.label, '', 'zone label ' .. i) eq(z.y, rows[i].y + 27, 'zone y ' .. i) end
        -- The grid: the hair salon's TileView, cleared, then the None tile and Ocean Maid's leotard, None selected.
        local grids = r.kit.live(F.GRID)
        eq(#grids, 1, 'grid')
        ok(F.called(grids[1].o, 'Set Goods'), 'Set Goods')
        local tv = grids[1].o.TileView_ItemList
        eq(tv.cleared, 1, 'cleared before the fill')
        eq(#tv.items, 2, 'tiles')
        eq(tv.items[1].ItemName.text, 'None', 'None first')
        eq(tv.items[2].ItemName.text, Fits.piece('AiK_CH27_14595', 'UndergarmentTop').Name, 'leotard')
        for i, item in ipairs(tv.items) do
            eq(item.IconAssetPath, F.ICON, 'icon ' .. i) eq(item.Index, i - 1, 'index ' .. i)
            eq(item.Purchased, true, 'purchased ' .. i)
        end
        eq(tv.items[1].Equiped, true, 'None worn') eq(tv.items[2].Equiped, false, 'leotard not worn')
        eq(tv:BP_GetSelectedItem(), tv.items[1], 'None selected')
        -- The detail panel: the focused slot, craft state 0, refreshed, the hold button hidden after it.
        local details = r.kit.live(F.DETAIL)
        eq(#details, 1, 'detail')
        local d = details[1].o
        eq(d.TitleText.text, 'Bra', 'detail title')
        eq(d.CraftState, 0, 'craft state')
        ok(F.called(d, 'EventNotification', 'Refresh'), 'detail Refresh')
        ok(F.called(d.WB_Common_HoldButton, 'SetVisibility', 1), 'hold button hidden')
        -- The hints: Back, then Wear on a row with pieces.
        local hints = r.kit.live(F.HINT)
        eq(#hints, 2, 'hints')
        ok(F.called(hints[1].o, 'SetText') and hints[1].o.calls[1][2].text == T.en.hint.back, 'Back hint')
        ok(hints[2].o.calls[1][2].text == T.en.closet.hints.wear, 'Wear hint')
        for _, rec in ipairs(r.kit.made) do ok(rec.x >= 0 and rec.x < 2560, 'part x ' .. tostring(rec.x)) end
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
        ok(#r.kit.made >= 22, 'parts made: ' .. #r.kit.made)
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

    tabs_rows_and_grid_move_with_their_keys = function()
        local r = rig()
        r.menu.open()
        -- Tabs: E and Q change the tab, its first row focused, with the change sound.
        at(r, 0.1, 'tab_right')
        eq(r.kit.sounds[#r.kit.sounds], 'change', 'tab sound')
        eq((detail(r)), 'Upper arm tattoo', 'arms tab, first row')
        ok(F.called(r.kit.live(F.TAB)[3].o, 'FocusTabButton'), 'arms tab focused')
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
        eq(tv:BP_GetSelectedItem(), tv.items[3], 'last tile kept; up and down do nothing in the grid')
        at(r, 0.4, 'left', 'left', 'left')
        at(r, 0.4, 'down')
        eq((detail(r)), 'Jacket', 'left on the first tile went back to the rows')
        -- Back in the grid goes back to the rows, the menu stays.
        at(r, 0.4, 'select', 'back')
        ok(r.menu.is_open(), 'back in the grid keeps the menu')
        at(r, 0.4, 'down')
        eq((detail(r)), 'Cape', 'back to the rows')
        -- Up on the first row reaches the tabs; left and right change the tab there, down comes back.
        at(r, 0.4, 'tab_left', 'tab_right', 'up', 'right')
        eq((detail(r)), 'Upper arm tattoo', 'right in the tabs changes the tab')
        at(r, 0.4, 'left', 'down', 'down')
        eq((detail(r)), 'Stomach tattoo', 'down from the tabs to the rows')
        -- The mouse: a click on a tab, on a row; a tile picked in the TileView.
        local tabs = r.kit.live(F.TAB)
        tabs[4].o.Button_Action.hover = true
        at(r, 0.4, 'click')
        tabs[4].o.Button_Action.hover = false
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
        -- A tile the mouse picked waits the same.
        grid(r):SetSelectedIndex(1)
        tick(r, 1.6)
        eq(#r.previews, 1, 'mouse: not yet')
        tick(r, 1.9)
        same(r.previews[2], {{fit = MAID, slots = {'Chest'}}}, 'mouse: Maid top worn')
        -- Leaving the grid before 250 ms wears nothing.
        at(r, 2, 'left')
        at(r, 2.1, 'back')
        tick(r, 2.5)
        eq(#r.previews, 2, 'left the grid')
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
        at(r, 2, 'tab_left', 'down', 'refresh')
        eq(#r.previews, 0, 'soon row, locked outfit')
        at(r, 2, 'up', 'refresh')
        same(r.previews, {{{fit = MAID}}}, 'the installed outfit is worn')
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
        at(r, 2, 'tab_left', 'tab_left')
        local title = detail(r)
        eq(title, 'Ocean Maid', 'the Full tab')
        at(r, 2, 'refresh', 'down', 'refresh')
        same(r.previews[3], {{fit = MAID}}, 'row 1')
        same(r.previews[4], {{fit = KUNOICHI}}, 'row 2')
    end,

    select_on_a_full_outfit_row_wears_it = function()
        local r = rig()
        on_top(r)
        -- The hint texts drawn now, in order.
        local function shown()
            local out = {}
            for _, h in ipairs(r.kit.live(F.HINT)) do
                local text
                for _, c in ipairs(h.o.calls) do if c[1] == 'SetText' then text = c[2].text end end
                out[#out + 1] = text
            end
            return out
        end
        same(shown(), {T.en.hint.back, T.en.closet.hints.wear}, 'a row of pieces: Back, Wear')
        at(r, 0.5, 'right')
        same(shown(), {T.en.hint.back, T.en.closet.hints.wear}, 'the grid: Back, Wear')
        at(r, 0.5, 'back', 'tab_left', 'tab_left')
        eq((detail(r)), 'Ocean Maid', 'the Full tab')
        same(shown(), {T.en.hint.back, T.en.closet.hints.whole}, 'the Full tab: Back, Whole outfit')
        at(r, 0.5, 'select')
        same(r.previews, {{{fit = MAID}}}, 'select wears the whole outfit')
        -- A click on the second row too.
        local zones = r.kit.groups.closet_menu.zones
        zones[2].hover = true
        at(r, 0.5, 'click')
        same(r.previews[2], {{fit = KUNOICHI}}, 'a click wears row 2')
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

    select_is_ignored_right_after_open = function()
        local r = rig()
        r.menu.open()
        at(r, 0.1, 'select')
        at(r, 0.1, 'down')
        eq((detail(r)), 'Top', 'the console Enter did not go into the grid')
        at(r, 0.31, 'select', 'down')
        eq((detail(r)), 'None', 'select works 0.3 s after the open')
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
            eq(line, T.en.closet.refused[case[1]], case[1] .. ' line')
            same(r.told, {T.en.closet.refused[case[1]]}, case[1] .. ' notice')
            eq(#r.kit.made, 0, case[1] .. ': nothing made')
            eq(#r.kit.inputs, 0, case[1] .. ': no input taken')
            eq(r.kit.held, held, case[1] .. ': input untouched')
            eq(r.menu.is_open(), false, case[1] .. ': closed')
        end
        package.loaded.UEHelpers.GetPlayer = function() return nil end
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
            {'input', function(r) r.kit.held = nil end},
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
}

run('menu_test', tests)
