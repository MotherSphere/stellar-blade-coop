-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The wardrobe resolver's rules (closet/resolver.lua): occupancy, FullOutfit, HidesSlots, regions, loadouts.
local run=dofile('tests/lua/closet/run.lua')
local Resolver = require('closet.resolver')
local Slots = require('closet.slots')

local function item(id, slot, extra)
    local t = {Id = id, Slot = slot, Occupies = {}, HidesSlots = {}, HidesBodyRegions = {}, KeepsSlots = {}}
    for k, v in pairs(extra or {}) do t[k] = v end
    return t
end

local function ids(list)
    local out = {}
    for _, x in ipairs(list) do out[#out + 1] = x.Id end
    return out
end

local function entry(state, id)
    for _, e in ipairs(state) do if e.item.Id == id then return e end end
    error('no entry ' .. id)
end

local body = item('horsen.body', 'BaseBody')
local boots = item('a.boots', 'Shoes', {HidesBodyRegions = {'Calf', 'Foot'}})
local jeans = item('b.jeans', 'Pants', {HidesBodyRegions = {'Pelvis', 'Thigh', 'Calf'}})
local dress = item('c.dress', 'Chest',
    {Occupies = {'Pants'}, HidesBodyRegions = {'TorsoUpper', 'TorsoLower', 'Pelvis'}})
local belt = item('d.belt', 'Belt')
local coat = item('e.coat', 'Outerwear', {HidesSlots = {'Belt'}, HidesBodyRegions = {'ArmUpper', 'Forearm'}})
local stockings = item('f.stockings', 'Legs', {HidesBodyRegions = {'Thigh', 'Calf', 'Foot'}})
local navel = item('g.navel', 'Navel')
local hair = item('h.hair', 'Hair')
local sword = item('i.sword', 'Weapon')
local suit = item('cns.suit', Slots.FULL_OUTFIT)
local suit_keeps = item('cns.suit2', Slots.FULL_OUTFIT, {KeepsSlots = {'Navel'}})

local tests={
    -- Conflict replacement
    same_slot_replaces = function()
        local w = Resolver.new()
        w:equip(jeans)
        local good, removed = w:equip(item('z.shorts', 'Pants'))
        ok(good, 'equip')
        same(ids(removed), {'b.jeans'}, 'removed')
        same(w:loadout(), {'z.shorts'}, 'worn')
    end,
    occupies_replaces_both_ways = function()
        local w = Resolver.new()
        w:equip(jeans)
        w:equip(item('y.top', 'Chest'))
        local _, removed = w:equip(dress)
        same(ids(removed), {'y.top', 'b.jeans'}, 'a dress takes off the top and the jeans')
        _, removed = w:equip(jeans)
        same(ids(removed), {'c.dress'}, 'jeans take off the dress')
    end,
    block_policy_refuses_and_names = function()
        local w = Resolver.new({policy = 'block'})
        w:equip(jeans)
        local good, why, blockers = w:equip(dress)
        eq(good, false, 'refused')
        eq(why, 'blocked', 'reason')
        same(ids(blockers), {'b.jeans'}, 'blockers')
        same(w:loadout(), {'b.jeans'}, 'nothing changed')
    end,
    reequip_same_item_is_not_a_removal = function()
        local w = Resolver.new({policy = 'block'})
        w:equip(boots)
        local good, removed = w:equip(boots)
        ok(good, 'equip again')
        same(removed, {}, 'nothing reported removed')
    end,
    unequip_by_slot_or_id = function()
        local w = Resolver.new()
        w:equip(dress)
        eq(w:unequip('Pants'), dress, 'by occupied slot')
        w:equip(boots)
        eq(w:unequip('a.boots'), boots, 'by id')
        eq(w:unequip('Shoes'), nil, 'empty slot')
    end,
    unknown_slot_raises = function()
        raises(function() Resolver.new():equip(item('x', 'Hat')) end, 'unknown slot')
    end,

    -- FullOutfit override
    full_outfit_suppresses_body_keeps_head = function()
        local w = Resolver.new()
        for _, x in ipairs({body, jeans, boots, navel, hair, sword}) do w:equip(x) end
        local _, removed = w:equip(suit)
        same(removed, {}, 'nothing taken off')
        local s = w:resolve()
        for _, id in ipairs({'horsen.body', 'b.jeans', 'a.boots', 'g.navel'}) do
            eq(entry(s, id).shown, false, id .. ' shown')
            eq(entry(s, id).why, 'suppressed', id .. ' why')
            eq(entry(s, id).by, 'cns.suit', id .. ' by')
        end
        eq(entry(s, 'h.hair').shown, true, 'hair')
        eq(entry(s, 'i.sword').shown, true, 'weapon')
        eq(entry(s, 'cns.suit').shown, true, 'suit')
    end,
    full_outfit_off_restores = function()
        local w = Resolver.new()
        w:equip(jeans) w:equip(suit)
        w:unequip(Slots.FULL_OUTFIT)
        eq(entry(w:resolve(), 'b.jeans').shown, true, 'jeans back')
    end,
    body_piece_takes_full_outfit_off = function()
        local w = Resolver.new()
        w:equip(jeans) w:equip(suit)
        local _, removed = w:equip(boots)
        same(ids(removed), {'cns.suit'}, 'suit off')
        local s = w:resolve()
        eq(entry(s, 'b.jeans').shown, true, 'jeans show again')
        eq(entry(s, 'a.boots').shown, true, 'boots')
    end,
    head_piece_leaves_full_outfit_on = function()
        local w = Resolver.new()
        w:equip(suit)
        local _, removed = w:equip(hair)
        same(removed, {}, 'suit stays')
    end,
    full_outfit_keeps_slots = function()
        local w = Resolver.new()
        w:equip(navel) w:equip(jeans) w:equip(suit_keeps)
        local s = w:resolve()
        eq(entry(s, 'g.navel').shown, true, 'kept navel')
        eq(entry(s, 'b.jeans').why, 'suppressed', 'jeans')
    end,
    new_full_outfit_replaces_old = function()
        local w = Resolver.new()
        w:equip(suit)
        local _, removed = w:equip(suit_keeps)
        same(ids(removed), {'cns.suit'}, 'one full outfit at a time')
    end,

    -- HidesSlots: non-destructive
    coat_hides_belt_and_restores = function()
        local w = Resolver.new()
        w:equip(belt) w:equip(coat)
        local s = w:resolve()
        eq(entry(s, 'd.belt').shown, false, 'belt hidden')
        eq(entry(s, 'd.belt').why, 'hidden', 'why')
        eq(entry(s, 'd.belt').by, 'e.coat', 'by')
        same(w:loadout(), {'d.belt', 'e.coat'}, 'belt still worn')
        w:unequip('e.coat')
        eq(entry(w:resolve(), 'd.belt').shown, true, 'belt back')
    end,
    hides_slot_reaches_occupied_slot = function()
        local w = Resolver.new()
        w:equip(dress)
        w:equip(item('x.longcoat', 'Outerwear', {HidesSlots = {'Pants'}}))
        eq(entry(w:resolve(), 'c.dress').why, 'hidden', 'dress claims Pants, so it is hidden')
    end,
    mutual_hiding_does_not_depend_on_order = function()
        local a = item('m.a', 'Gloves', {HidesSlots = {'Belt'}})
        local b = item('m.b', 'Belt', {HidesSlots = {'Gloves'}})
        local w1, w2 = Resolver.new(), Resolver.new()
        w1:equip(a) w1:equip(b)
        w2:equip(b) w2:equip(a)
        local s1, s2 = w1:resolve(), w2:resolve()
        for _, id in ipairs({'m.a', 'm.b'}) do
            eq(entry(s1, id).shown, entry(s2, id).shown, id .. ' same either order')
        end
    end,
    suppressed_pieces_hide_nothing = function()
        local w = Resolver.new()
        w:equip(item('k.keep', 'Navel'))
        w:equip(item('k.hider', 'Belt', {HidesSlots = {'Navel'}}))
        w:equip(item('k.suit', Slots.FULL_OUTFIT, {KeepsSlots = {'Navel'}}))
        eq(entry(w:resolve(), 'k.keep').shown, true, 'a suppressed belt cannot hide the kept navel piece')
    end,

    -- Body regions
    regions_come_from_higher_layers_only = function()
        local w = Resolver.new()
        for _, x in ipairs({body, stockings, jeans, boots}) do w:equip(x) end
        local s = w:resolve()
        same(entry(s, 'horsen.body').regions, {'Pelvis', 'Thigh', 'Calf', 'Foot'}, 'body under all')
        same(entry(s, 'f.stockings').regions, {'Pelvis', 'Thigh', 'Calf', 'Foot'}, 'stockings under layer 2')
        same(entry(s, 'b.jeans').regions, {}, 'same layer as boots: nothing')
        same(entry(s, 'a.boots').regions, {}, 'top')
    end,
    hidden_pieces_give_no_regions = function()
        local w = Resolver.new()
        local cover = item('r.cover', 'Belt', {HidesBodyRegions = {'TorsoLower'}})
        w:equip(body) w:equip(cover) w:equip(item('r.coat', 'Outerwear', {HidesSlots = {'Belt'}}))
        same(entry(w:resolve(), 'horsen.body').regions, {}, 'hidden belt hides no skin')
    end,
    full_outfit_regions_reach_kept_pieces = function()
        local w = Resolver.new()
        local pierce = item('p.navel', 'Navel')
        w:equip(pierce)
        w:equip(item('p.suit', Slots.FULL_OUTFIT, {KeepsSlots = {'Navel'}, HidesBodyRegions = {'TorsoLower'}}))
        same(entry(w:resolve(), 'p.navel').regions, {'TorsoLower'}, 'regions apply to kept pieces below')
    end,

    -- Deterministic order and loadouts
    apply_order_is_layer_then_slot = function()
        local w = Resolver.new()
        for _, x in ipairs({sword, boots, hair, body, stockings, suit}) do w:equip(x) end
        same(w:loadout(), {'horsen.body', 'f.stockings', 'a.boots', 'h.hair', 'i.sword', 'cns.suit'}, 'order')
    end,
    loadout_round_trip = function()
        local w = Resolver.new()
        for _, x in ipairs({body, jeans, boots, belt, coat, suit, hair}) do w:equip(x) end
        local catalog = {}
        for _, x in ipairs({body, jeans, boots, belt, coat, suit, hair}) do catalog[x.Id] = x end
        local saved = w:loadout()
        local back, missing, dropped = Resolver.from_loadout(saved, catalog)
        same(back:loadout(), saved, 'same pieces')
        same(missing, {}, 'none missing')
        same(dropped, {}, 'none dropped')
        eq(entry(back:resolve(), 'b.jeans').why, 'suppressed', 'full outfit still suppresses')
    end,
    loadout_reports_missing_and_dropped = function()
        local catalog = {[jeans.Id] = jeans, [dress.Id] = dress}
        local back, missing, dropped = Resolver.from_loadout({'b.jeans', 'gone.pack', 'c.dress'}, catalog)
        same(missing, {'gone.pack'}, 'missing')
        eq(#back:loadout(), 1, 'one of the two clashing pieces kept')
        eq(#dropped, 1, 'the other reported')
    end,
    loadout_order_in_file_does_not_matter = function()
        local catalog = {[jeans.Id] = jeans, [dress.Id] = dress, [boots.Id] = boots}
        local a = Resolver.from_loadout({'b.jeans', 'c.dress', 'a.boots'}, catalog)
        local b = Resolver.from_loadout({'a.boots', 'c.dress', 'b.jeans'}, catalog)
        same(a:loadout(), b:loadout(), 'same result')
    end,
}

run('resolver_test',tests)
