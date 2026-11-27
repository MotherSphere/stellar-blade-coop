-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The closet's colour layer (closet/colour.lua) over a fake dress and fake components and materials: a role for every
-- slot of closet/slots.lua, the swatch cycle with Off, dynamic instances only on the slots a set role reaches, the
-- parameter names (Base Color Tint, EmissiveColor on a glow only), the palette applied again when dress.applied()
-- changes and when it changes, Off giving the materials from before back, a slot that fails left alone, the palette
-- kept in its file and read back, off() clearing it; coop closet colour (closet/commands.lua).
local run = dofile('tests/lua/closet/run.lua')
package.loaded.UEHelpers = {GetPlayer = function() return nil end} -- closet/dress.lua (commands.lua) needs it to load
local Slots = require('closet.slots')

local addresses = 0
local function obj(name)
    addresses = addresses + 1
    local o = {name = name, alive = true, address = addresses}
    o.type = function() return 'UObject' end
    function o:IsValid() return self.alive end
    function o:GetAddress() return self.address end
    return o
end
local function material(name, defaults)
    local m = obj(name)
    m.defaults = defaults or {}
    return m
end
-- A dynamic instance: its own values, else its parent's defaults, else (0,0,0,1) as K2_GetVectorParameterValue
-- answers (Ghidra, build 26123051: exec 0x144883460).
local function instance_of(parent)
    local m = obj('MID of ' .. parent.name)
    m.mid, m.Parent, m.values, m.sets = true, parent, {}, {}
    function m:SetVectorParameterValue(name, v)
        if not self.alive then self.freed_use = true end
        self.values[name] = {R = v.R, G = v.G, B = v.B, A = v.A}
        self.sets[#self.sets + 1] = name
    end
    function m:K2_GetVectorParameterValue(name)
        local v = self.values[name] or self.Parent.defaults[name] or {R = 0, G = 0, B = 0, A = 1}
        return {R = v.R, G = v.G, B = v.B, A = v.A}
    end
    return m
end
-- A mesh component: CreateDynamicMaterialInstance as FUN_1440e9330 does it (Ghidra, build 26123051): the source set
-- on the slot first, an instance already there given back, else a new one made and set on the slot.
local function component(name, mats)
    local c = obj(name)
    c.mats, c.creates = mats, 0
    function c:GetMaterial(i) return self.mats[i] end
    function c:SetMaterial(i, m)
        if not self.alive then self.freed_use = true end
        self.mats[i] = m
    end
    function c:CreateDynamicMaterialInstance(i, source, optional)
        if source then self.mats[i] = source end
        local now = self.mats[i]
        if not now then return nil end
        if now.mid then return now end
        local m = instance_of(now)
        self.mats[i], self.creates, self.named = m, self.creates + 1, optional
        return m
    end
    return c
end

local TINT, GLOW = 'Base Color Tint', 'EmissiveColor'
-- EVE's body wearing a top (slot 3, a grey tint), gloves (4, a red glow of 8) and a necklace (5), with her skin (0).
local function rig(file)
    local r = {gen = 1, log = {}, file = file}
    r.store = {save = function(line) r.file = line; return true end, load = function() return r.file end,
        clear = function() r.file = nil end}
    r.skin, r.top = material('Skin'), material('Top', {[TINT] = {R = 0.75, G = 0.75, B = 0.75, A = 1}})
    r.glove, r.chain = material('Glove', {[GLOW] = {R = 8, G = 0, B = 0, A = 0}}), material('Chain')
    r.body = component('Body', {[0] = r.skin, [3] = r.top, [4] = r.glove, [5] = r.chain})
    r.parts = {{c = r.body, slots = {[0] = 'BaseBody', [3] = 'Chest', [4] = 'Gloves', [5] = 'Necklace'}}}
    r.dress = {applied = function() return r.gen end, parts = function() return r.parts end}
    FName = function(s) return s end
    package.loaded['closet.colour'] = nil
    r.Colour = require('closet.colour')
    r.c = r.Colour.new({dress = r.dress, store = r.store, log = function(m) r.log[#r.log + 1] = m end})
    return r
end
local function rgb(id)
    for _, s in ipairs(require('closet.colour').SWATCHES) do if s[1] == id then return s[2], s[3], s[4] end end
end
local function near(got, want, what)
    for _, k in ipairs({'R', 'G', 'B', 'A'}) do
        ok(got and math.abs(got[k] - want[k]) < 1e-6, ('%s: %s %s, want %s'):format(what, k,
            tostring(got and got[k]), tostring(want[k])))
    end
end

local tests = {
    -- A slot with a pack colour control belongs to the options layer (closet/options.lua's owns): the palette never
    -- paints it; a record the palette made there before is forgotten, its material left to the options layer.
    the_palette_never_paints_a_slot_with_a_pack_colour = function()
        local r = rig()
        local owned = {}
        r.c = r.Colour.new({dress = r.dress, store = r.store, log = function(m) r.log[#r.log + 1] = m end,
            options = {owns = function(c, i) return c == r.body and owned[i] == true end}})
        r.c.set('primary', 'crimson')
        r.c.tick()
        local top = r.body.mats[3]
        ok(top.mid, 'no pack colour yet: the top tinted')
        owned[3], owned[4] = true, true
        r.c.set('primary', 'azure') r.c.set('secondary', 'navy')
        r.c.tick()
        ok(r.body.mats[3] == top, 'the instance stays: no material given back')
        near(top.values[TINT], {R = 0.515, G = 0.007, B = 0.021, A = 1}, 'the palette wrote no more on it')
        ok(r.body.mats[4] == r.glove, 'the gloves never painted')
        r.gen = 2
        r.body.mats[3] = r.top
        r.c.tick()
        ok(r.body.mats[3] == r.top, 'a new look: the top never painted')
    end,
    -- A slot whose instance the options layer also writes (holds: a pack colour control on the pack's colour) gets the
    -- palette; a role turned off gives back its values only: the material stays, so the options layer's instance and
    -- values stay.
    a_held_slot_gets_its_values_back_not_its_material = function()
        local r = rig()
        r.c = r.Colour.new({dress = r.dress, store = r.store, log = function(m) r.log[#r.log + 1] = m end,
            options = {owns = function() return false end, holds = function(c, i) return c == r.body and i == 3 end}})
        r.c.set('primary', 'crimson')
        r.c.tick()
        local top = r.body.mats[3]
        ok(top.mid, 'a held slot on the pack colour: tinted')
        r.c.set('primary', 'off')
        r.c.tick()
        ok(r.body.mats[3] == top, 'off: the instance stays on the slot')
        near(top.values[TINT], top.was and top.was[TINT] or top.values[TINT], 'its value from before')
    end,
    -- The options layer paints with no new look and no palette change (options.revision grows): a slot set to a
    -- custom colour keeps it. Set back to the pack's colour, it gets the palette again.
    a_slot_back_on_the_pack_colour_gets_the_palette_again = function()
        local r = rig()
        local owned, rev = {}, 0
        r.c = r.Colour.new({dress = r.dress, store = r.store, log = function(m) r.log[#r.log + 1] = m end,
            options = {owns = function(c, i) return c == r.body and owned[i] == true end,
                holds = function(c, i) return c == r.body and i == 3 end, revision = function() return rev end}})
        r.c.set('primary', 'crimson')
        r.c.tick()
        local top = r.body.mats[3]
        local cr, cg, cb = rgb('crimson')
        near(top.values[TINT], {R = cr, G = cg, B = cb, A = 1}, 'the top tinted crimson')
        local custom, pack = {R = 0, G = 1, B = 0, A = 1}, {R = 0.75, G = 0.75, B = 0.75, A = 1}
        owned[3], top.values[TINT], rev = true, custom, rev + 1
        r.c.tick()
        near(top.values[TINT], custom, 'a custom colour: the palette leaves it')
        owned[3], top.values[TINT], rev = false, pack, rev + 1
        r.c.tick()
        near(top.values[TINT], {R = cr, G = cg, B = cb, A = 1}, 'back on the pack colour: crimson again')
        -- An options repaint of the pack value that never owned the slot (a pack rescan, a lost instance record):
        -- the palette writes its colour again, though its own record already holds it.
        top.values[TINT], rev = pack, rev + 1
        r.c.tick()
        near(top.values[TINT], {R = cr, G = cg, B = cb, A = 1}, 'an options repaint: crimson again')
        r.c.tick()
        near(top.values[TINT], {R = cr, G = cg, B = cb, A = 1}, 'no repaint: kept')
        -- A repaint that skipped the unchanged pack tint while the role turns off on the same tick: the value from
        -- before still comes back.
        rev = rev + 1
        r.c.set('primary', 'off')
        r.c.tick()
        near(top.values[TINT], pack, 'the role off during a repaint: the pack value back')
    end,
    -- dress.reshow (an options toggle) shows a slot without a new look: the palette reaches it, the other instances
    -- kept.
    a_slot_shown_again_gets_the_palette_and_keeps_the_others = function()
        local r = rig()
        local shown = 1
        r.dress.shown = function() return shown end
        r.c.set('primary', 'crimson')
        r.c.tick()
        local top = r.body.mats[3]
        ok(top.mid, 'the top tinted')
        local cape = material('Cape')
        r.body.mats[6] = cape
        r.parts[1].slots[6] = 'Cape'
        shown = 2
        r.c.tick()
        ok(r.body.mats[6].mid, 'the shown cape tinted') ok(r.body.mats[3] == top, 'the top keeps its instance')
        eq(r.body.creates, 2, 'one new instance')
    end,
    every_slot_has_one_role = function()
        local Colour = require('closet.colour')
        local seen, roles = {}, {primary = true, secondary = true, accent = true, glow = true, none = true}
        for role, list in pairs(Colour.SLOTS) do
            ok(roles[role], 'role ' .. role)
            for _, id in ipairs(list) do
                ok(Slots.known(id), role .. ': no slot ' .. id)
                ok(not seen[id], id .. ' has two roles')
                seen[id] = role
            end
        end
        for _, entry in ipairs(Slots.LIST) do ok(seen[entry[1]], entry[1] .. ' has no role') end
        same(Colour.ROLES, {'primary', 'secondary', 'accent', 'glow'}, 'the rows in order')
        eq(Colour.role('Chest'), 'primary') eq(Colour.role('FullOutfit'), 'primary')
        eq(Colour.role('Gloves'), 'secondary') eq(Colour.role('Shoes'), 'secondary')
        eq(Colour.role('Belt'), 'secondary')
        eq(Colour.role('Necklace'), 'accent') eq(Colour.role('Rings'), 'accent')
        eq(Colour.role('NosePiercing'), 'accent')
        eq(Colour.role('Dermal'), 'glow')
        eq(Colour.role('BaseBody'), nil, 'her skin has no role') eq(Colour.role('Hair'), nil)
        eq(Colour.role('Fingernails'), nil) eq(Colour.role('Nope'), nil)
    end,

    swatches_cycle_through_off = function()
        local Colour = require('closet.colour')
        local ids = {}
        for i, s in ipairs(Colour.SWATCHES) do
            ids[i] = s[1]
            for k = 2, 4 do ok(s[k] >= 0 and s[k] <= 1, s[1] .. ' linear value ' .. k) end
            same({Colour.swatch(s[1])}, {s[2], s[3], s[4]}, s[1])
        end
        same(ids, {'white', 'black', 'charcoal', 'silver', 'gold', 'crimson', 'wine', 'rose', 'violet', 'navy', 'azure',
            'teal', 'emerald', 'sand'}, 'the 14 swatches')
        eq(Colour.cycle('off', 1), 'white') eq(Colour.cycle('white', 1), 'black') eq(Colour.cycle('sand', 1), 'off')
        eq(Colour.cycle('off', -1), 'sand') eq(Colour.cycle('white', -1), 'off')
        eq(Colour.swatch('off'), nil) eq(Colour.swatch('pink'), nil)
        local r = rig()
        eq(r.c.get('primary'), 'off', 'off at first')
        local steps = {}
        for i = 1, 16 do r.c.step('primary', 1); steps[i] = r.c.get('primary') end
        eq(steps[14], 'sand') eq(steps[15], 'off', 'back to off after the last') eq(steps[16], 'white')
        r.c.step('primary', -1)
        eq(r.c.get('primary'), 'off', 'left from the first: off')
    end,

    instances_only_where_a_set_role_reaches = function()
        local r = rig()
        r.c.tick()
        eq(r.body.creates, 0, 'nothing set: no instance')
        -- Glow alone reaches the glow role's slots only (Dermal): none is worn here, the gloves' glow included.
        ok(r.c.set('glow', 'azure'))
        r.c.tick()
        eq(r.body.creates, 0, 'glow alone, no Dermal worn: no instance')
        ok(r.body.mats[4] == r.glove, 'the gloves (secondary, off) keep their material')
        ok(r.c.set('glow', 'off'))
        ok(r.c.set('primary', 'crimson'))
        eq(r.body.creates, 0, 'the palette goes on in the tick')
        r.c.tick()
        eq(r.body.creates, 1, 'one instance: the top')
        ok(r.body.mats[3].mid and r.body.mats[3].Parent == r.top, 'the top wears an instance of its material')
        eq(r.body.named, 'None', 'OptionalName None')
        ok(r.body.mats[0] == r.skin and r.body.mats[4] == r.glove and r.body.mats[5] == r.chain,
            'the others as they were')
        local mid = r.body.mats[3]
        ok(r.c.set('accent', 'gold'))
        r.c.tick()
        eq(r.body.creates, 2, 'the necklace too')
        ok(r.body.mats[3] == mid, 'the top keeps its instance')
        ok(r.body.mats[0] == r.skin and r.body.mats[4] == r.glove, 'skin and gloves untouched')
        r.c.tick() r.c.tick()
        eq(r.body.creates, 2, 'nothing changed: no work')
        eq(#mid.sets, 1, 'the top set once')
    end,

    the_parameter_names = function()
        local r = rig()
        r.c.set('primary', 'crimson')
        r.c.set('secondary', 'navy')
        r.c.tick()
        local R, G, B = rgb('crimson')
        near(r.body.mats[3].values[TINT], {R = R, G = G, B = B, A = 1}, 'the top: Base Color Tint, its own alpha')
        R, G, B = rgb('navy')
        near(r.body.mats[4].values[TINT], {R = R, G = G, B = B, A = 1}, 'the gloves: Base Color Tint')
        eq(r.body.mats[3].values[GLOW], nil, 'no glow set')
        -- Glow: EmissiveColor on the glow role's slots only (Dermal: body glows), the swatch times its brightness.
        r.c.set('glow', 'azure')
        r.c.tick()
        eq(r.body.mats[4].values[GLOW], nil, 'the gloves are secondary: their own glow (8) left as it is')
        eq(r.body.mats[3].values[GLOW], nil, 'the top is primary: no glow set')
        ok(r.body.mats[5] == r.chain, 'accent off: the necklace keeps its material')
        ok(r.body.mats[0] == r.skin, 'never her skin')
        -- Dermal takes the glow only, never a tint.
        local dermal = material('Glow', {[GLOW] = {R = 0, G = 2, B = 0, A = 1}})
        r.body.mats[7] = dermal
        r.parts[1].slots[7] = 'Dermal'
        r.c.set('accent', 'gold') -- A palette change: the tick runs again.
        r.c.tick()
        R, G, B = rgb('azure')
        near(r.body.mats[7].values[GLOW], {R = 2 * R, G = 2 * G, B = 2 * B, A = 1}, 'Dermal glows azure')
        eq(r.body.mats[7].values[TINT], nil, 'Dermal: no tint')
        eq(r.body.mats[4].values[GLOW], nil, 'still no glow on the gloves')
        eq(r.body.mats[5].values[GLOW], nil, 'nor on the necklace')
        -- A Dermal piece whose glow is off keeps it off (its instance made, nothing set).
        local dark = material('Dark')
        r.body.mats[8] = dark
        r.parts[1].slots[8] = 'Dermal'
        r.c.set('secondary', 'off')
        r.c.tick()
        ok(r.body.mats[8].mid, 'the dark Dermal piece has an instance')
        same(r.body.mats[8].sets, {}, 'its glow left off')
    end,

    applied_again_when_the_dress_applies = function()
        local r = rig()
        r.c.set('primary', 'crimson')
        r.c.tick()
        local old, old_top = r.body, r.body.mats[3]
        -- A wear: the dress puts new components and materials on (its applied() grows).
        r.gen = 2
        r.body = component('Body2', {[3] = r.top})
        local added = component('Added', {[1] = material('Jacket'), [2] = material('Boot')})
        r.parts = {{c = r.body, slots = {[3] = 'Chest'}}, {c = added, slots = {[1] = 'Outerwear', [2] = 'Shoes'}}}
        r.c.tick()
        eq(r.body.creates, 1, 'the new body\'s top coloured') eq(added.creates, 1, 'the jacket coloured')
        ok(added.mats[2].name == 'Boot', 'secondary off: the boots untouched')
        ok(old.mats[3] == old_top, 'the old component is the dress\'s: never given back')
        -- Her own look (the dress's own_look or off): nothing worn, nothing coloured.
        r.gen, r.parts = 3, {}
        r.c.tick()
        ok(r.body.mats[3].mid, 'the dress gave her look back: the closet sets nothing')
    end,

    off_gives_back_the_materials = function()
        local r = rig()
        r.c.set('primary', 'crimson')
        r.c.set('secondary', 'navy')
        r.c.tick()
        local gloves = r.body.mats[4]
        r.c.set('primary', 'off')
        r.c.tick()
        ok(r.body.mats[3] == r.top, 'primary off: the top\'s own material back')
        ok(r.body.mats[4] == gloves, 'the gloves keep theirs')
        -- The glow reaches the glow role's slots only: no instance again for the top, none for the necklace.
        r.c.set('glow', 'azure')
        r.c.tick()
        eq(r.body.creates, 2, 'no instance for the glow: no Dermal worn')
        ok(r.body.mats[3] == r.top and r.body.mats[5] == r.chain, 'the top and the necklace keep their materials')
        r.c.set('secondary', 'off')
        r.c.tick()
        ok(r.body.mats[4] == r.glove, 'secondary off: the gloves\' own material back')
        ok(r.c.off())
        r.c.tick()
        ok(r.body.mats[3] == r.top and r.body.mats[4] == r.glove and r.body.mats[5] == r.chain, 'every material back')
        -- An instance the game put there is reused: Off sets its values back.
        local game = instance_of(r.top)
        game.values[TINT] = {R = 0.2, G = 0.3, B = 0.4, A = 1}
        r.body.mats[3] = game
        r.c.set('primary', 'crimson')
        r.c.tick()
        ok(r.body.mats[3] == game, 'the game\'s instance reused') eq(r.body.creates, 2, 'no new one for it')
        r.c.set('primary', 'off')
        r.c.tick()
        ok(r.body.mats[3] == game, 'still the game\'s')
        near(game.values[TINT], {R = 0.2, G = 0.3, B = 0.4, A = 1}, 'its values back')
    end,

    a_map_change_before_the_watchdog_never_touches_the_old_body = function()
        local r = rig()
        r.c.set('primary', 'crimson')
        r.c.tick()
        local old, old_mid = r.body, r.body.mats[3]
        -- A map change: the old world's objects are gone, dress.parts() gives the new EVE's Mesh at once while
        -- applied() stays the same until the dress's watchdog mixes again.
        old.alive, old_mid.alive = false, false
        r.body = component('NewBody', {[3] = r.top, [4] = r.glove})
        r.parts = {{c = r.body, slots = {[3] = 'Chest', [4] = 'Gloves'}}}
        r.c.set('primary', 'navy')
        r.c.tick()
        ok(not old.freed_use and not old_mid.freed_use, 'nothing sent to the old body or its instance')
        eq(r.body.creates, 1, 'the top of the new body coloured')
        near(r.body.mats[3].values[TINT], {R = rgb('navy'), G = select(2, rgb('navy')), B = select(3, rgb('navy')),
            A = 1}, 'navy on the new top')
        -- The same with a slot given back: the old record of a gone component is dropped, not given back.
        r.c.tick()
        local gone = r.body
        gone.alive, gone.mats[3].alive = false, false
        r.body = component('ThirdBody', {[3] = r.top})
        r.parts = {{c = r.body, slots = {[3] = 'Chest'}}}
        r.c.set('primary', 'off')
        r.c.tick()
        ok(not gone.freed_use and not gone.mats[3].freed_use, 'Off sends nothing to a gone component')
    end,

    a_slot_that_fails_is_left_alone = function()
        local r = rig()
        r.body.mats[4] = nil -- No material on the gloves' slot.
        local added = component('Added', {[1] = material('Jacket')})
        function added:CreateDynamicMaterialInstance() error('engine said no') end
        r.parts[2] = {c = added, slots = {[1] = 'Outerwear'}}
        r.c.set('primary', 'crimson')
        r.c.set('secondary', 'navy')
        r.c.tick()
        eq(r.body.mats[4], nil, 'nothing on an empty slot')
        ok(r.body.mats[3].mid, 'the top still coloured')
        has(r.log, 'engine said no', 'the failure logged')
        eq(added.mats[1].name, 'Jacket', 'its material stays')
    end,

    waits_while_the_dress_is_paused = function()
        local r = rig()
        r.c.set('primary', 'crimson')
        local parts = r.parts
        r.parts = nil -- Tachy Mode or an outside fight: the body wears another look.
        r.c.tick()
        eq(r.body.creates, 0, 'nothing while paused')
        r.parts = parts
        r.c.tick()
        eq(r.body.creates, 1, 'coloured once the mix is back')
    end,

    the_palette_is_kept = function()
        local r = rig()
        r.c.set('glow', 'azure')
        r.c.set('primary', 'crimson')
        eq(r.file, 'primary=crimson glow=azure', 'the file in role order')
        local again = r.Colour.new({dress = r.dress, store = r.store, log = function() end})
        eq(again.get('primary'), 'crimson', 'read back') eq(again.get('glow'), 'azure')
        eq(again.get('secondary'), 'off')
        again.tick()
        ok(r.body.mats[3].mid, 'worn again after a restart')
        r.c.set('primary', 'off')
        eq(r.file, 'glow=azure')
        ok(r.c.off())
        eq(r.file, nil, 'off clears the file')
        eq(r.c.get('glow'), 'off')
        -- Words it does not know are left out.
        r.file = 'primary=pink nope=gold accent=gold'
        local odd = r.Colour.new({dress = r.dress, store = r.store, log = function() end})
        eq(odd.get('primary'), 'off') eq(odd.get('accent'), 'gold')
        -- A file that cannot be written: logged, the palette still on.
        r.store.save = function() return false, 'disk full' end
        ok(r.c.set('accent', 'wine'))
        has(r.log, 'disk full', 'logged') eq(r.c.get('accent'), 'wine')
    end,

    refusals = function()
        local r = rig()
        local good, why = r.c.set('nope', 'gold')
        eq(good, false) ok(why:find('Use: coop closet colour', 1, true), why)
        good, why = r.c.set('primary', 'pink')
        eq(good, false) ok(why:find('pink', 1, true) and why:find('crimson', 1, true), why)
        eq(r.file, nil, 'nothing written')
    end,

    stop_forgets_the_instances = function()
        local r = rig()
        r.c.set('primary', 'crimson')
        r.c.tick()
        r.c.stop() -- coop off: the dress gave her look back first.
        r.body.mats[3] = r.top
        r.c.tick()
        eq(r.body.creates, 2, 'coloured again at the next tick')
        eq(r.file, 'primary=crimson', 'the palette stays')
    end,

    commands = function()
        local r = rig()
        local C = require('closet.commands').new({dress = {}, fits = require('closet.fits'), colour = r.c})
        local good, line = C.closet('colour', 'primary', 'crimson', nil, nil, nil)
        ok(good and line == 'closet: colour primary crimson', line)
        eq(r.c.get('primary'), 'crimson')
        good, line = C.closet('colour', 'glow', 'off', nil, nil, nil)
        ok(good and line == 'closet: colour glow off', line)
        good, line = C.closet('colour', 'off', nil, nil, nil, nil)
        ok(good and line == 'closet: colours off', line)
        eq(r.c.get('primary'), 'off')
        for _, words in ipairs({{}, {'primary'}, {'primary', 'crimson', 'x'}, {'off', 'x'}}) do
            good, line = C.closet('colour', table.unpack(words))
            ok(not good and line == r.Colour.USE, table.concat(words, ' ') .. ': ' .. tostring(line))
        end
        good, line = C.closet('colour', 'primary', 'pink')
        ok(not good and line:find('pink', 1, true), line)
    end,
}
run('colour_test', tests)
