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

local function rig(o)
    o = o or {}
    local r = {told = {}, log = {}, reverted = 0, kit = F.kit()}
    if o.before then o.before(r) end
    package.loaded['closet.ui.menu'], package.loaded['closet.ui.view'] = nil, nil
    local Menu = require('closet.ui.menu')
    r.dress = {installed = function() return true end, choices = function() return r.choices end,
        revert = function() r.reverted = r.reverted + 1; return true, 'closet: nothing to revert' end,
        game_look = function() return nil end}
    r.menu = Menu.new({kit = r.kit, dress = r.dress, words = function() return T.en end,
        tell = function(build) r.told[#r.told + 1] = build(T.en) end, log = function(m) r.log[#r.log + 1] = m end,
        world = function() return true end, photo = function() return '0' end,
        status = function() return 'mod=1 theater=none' end})
    return r
end

-- Every part dropped, the input given back, the group hidden, the menu closed.
local function all_gone(r)
    eq(r.kit.dropped, #r.kit.made, 'parts dropped')
    eq(r.kit.held, nil, 'input held')
    eq(r.kit.inputs[#r.kit.inputs][1], false, 'last input call')
    eq(r.kit.shown.closet_menu, false, 'group shown')
    eq(r.menu.is_open(), false, 'is_open')
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
        -- The hints: Back, then Select on a row with pieces.
        local hints = r.kit.live(F.HINT)
        eq(#hints, 2, 'hints')
        ok(F.called(hints[1].o, 'SetText') and hints[1].o.calls[1][2].text == T.en.hint.back, 'Back hint')
        ok(hints[2].o.calls[1][2].text == T.en.hint.select, 'Select hint')
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

    stop_drops_without_revert = function()
        local r = rig()
        r.menu.open()
        local sounds = #r.kit.sounds
        r.menu.stop()
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
}

run('menu_test', tests)
