-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet: the menu's data model. Pure Lua, no engine calls: what the tabs, rows and tiles list, and the edits
-- of a list of choices {{fit=<UniqueFitID>, slots=<Slot ids, or nil for every piece the fit shows by default>}}
-- (the shape of Dress.plan's input). Edits never touch their input. The Colour tab lists closet/colour.lua's roles.
-- The Body tab lists a shape row for each name of o.shapes (closet/shape.lua's rows) right below its Body row.
-- Full outfit lists every suit of closet/fits.lua's Fits.all (the installed packs' and the hand fits); the fitting tabs
-- list the hand fits' pieces only.
local Colour = require('closet.colour')
local Model = {}
-- Words (lower case, in a toggle's name) -> the section of a piece with no hand map slot and no piece hint
-- (closet/cns_import.lua's PIECE_WORDS found none), checked in order.
Model.SECTION_WORDS = {{'skin', 'BaseBody'}, {'body', 'BaseBody'}, {'hair', 'Hair'}, {'hood', 'Headwear'},
    {'mask', 'Mask'}, {'strap', 'ChestHardware'}, {'chain', 'Necklace'}}

-- custom: Custom fits only (the region tabs and the Body tab: Original suits are worn whole only, from Full outfit).
local function sorted_fits(fits, custom)
    local ids = {}
    for id in pairs(fits.BY_ID) do
        if not custom or fits.origin(id) == 'custom' then ids[#ids + 1] = id end
    end
    table.sort(ids)
    return ids
end

-- o = {slots=closet.slots, fits=closet.fits, installed=function(fit)->bool, adult=bool,
-- shapes=function()->morph names or nil, presets=closet/presets.lua's or nil (no Presets rows, filter or favourite
-- marks then), filter=function()->the filter row's list: 'all', 'favourites', 'original' (Shift Up's own suits) or
-- 'custom' (the pack and hand outfits), pictures=true with coop closet thumbs (a Clear preview pictures row then)}
function Model.new(o)
    local Slots, Fits = o.slots, o.fits
    local m = {}

    -- The slots a choice wears: its own list, or the pieces its fit shows by default.
    local function slots_of(choice)
        if choice.slots then return choice.slots end
        local out = {}
        for _, piece in ipairs(Fits.get(choice.fit).Pieces) do
            if not piece.Off then out[#out + 1] = piece.Slot end
        end
        return out
    end

    -- A fit's piece in a slot, or nil. The pseudo slot BaseBody has no piece: a fit with Skin gives one named after
    -- its outfit (closet/dress.lua's Dress.plan wears that outfit's body).
    function m.piece(fit_id, slot)
        local fit = Fits.get(fit_id)
        if slot == 'BaseBody' and fit and next(fit.Skin or {}) ~= nil then return {Name = fit.Outfit} end
        return Fits.piece(fit_id, slot)
    end

    function m.tabs()
        local out = {beta = {}} -- beta: the ids of the fitting tabs, labelled "(Beta)".
        for _, menu in ipairs(Slots.MENUS) do
            if o.adult or not menu[2] then
                out[#out + 1] = menu[1]
                out.beta[menu[1]] = menu[3] or nil
            end
        end
        return out
    end

    function m.rows(tab)
        local out = {}
        if tab == 'full' then
            -- With presets: Save look as preset, each preset (locked: its outfit is not installed), the filter row.
            local presets = o.presets
            if presets then
                out[1] = {save_preset = true}
                for _, p in ipairs(presets.list()) do
                    out[#out + 1] = {preset = p.n, name = p.name, fit = p.fit, locked = p.gone}
                end
                out[#out + 1] = {filter = true}
            end
            local show = presets and o.filter and o.filter() or 'all'
            -- Every suit (the pack fits and the hand fits, Fits.all) by name in any case, then by id; Shift Up's own
            -- suits after the others, under the Original header. The filter on Favourites keeps the favourites only,
            -- on Original or Custom the suits of that origin only.
            local all, ids = Fits.all(), {custom = {}, original = {}}
            for id in pairs(all) do
                local origin = Fits.origin(id)
                if show == 'all' or show == origin or show == 'favourites' and presets.is_fav(id) then
                    table.insert(ids[origin], id)
                end
            end
            local function by_name(a, b)
                local x, y = all[a].Outfit:lower(), all[b].Outfit:lower()
                if x ~= y then return x < y end
                return a < b
            end
            for _, origin in ipairs({'custom', 'original'}) do
                table.sort(ids[origin], by_name)
                if origin == 'original' and #ids.original > 0 then out[#out + 1] = {header = 'original'} end
                for _, id in ipairs(ids[origin]) do
                    local fit = all[id]
                    -- locked is read on first use, once: o.installed loads the outfit's mesh on the game thread,
                    -- so a menu of many packs loads only the rows it shows.
                    out[#out + 1] = setmetatable({whole = id, outfit = fit.Outfit, pack = fit.Pack,
                        fav = presets and presets.is_fav(id) or nil}, {__index = function(row, k)
                            if k ~= 'locked' then return nil end
                            rawset(row, 'locked', not o.installed(id))
                            return row.locked
                        end})
                end
            end
            -- Clear preview pictures (the camera hint row's Preview picture makes them, closet/ui/menu.lua).
            if o.pictures then out[#out + 1] = {clear_thumbs = true} end
            out[#out + 1] = {reset = true} -- Reset Stellar Closet, last.
            return out
        end
        if tab == 'colour' then
            for _, role in ipairs(Colour.ROLES) do out[#out + 1] = {role = role} end
            return out
        end
        for _, slot in ipairs(Slots.in_menu(tab)) do
            local has = false
            for _, id in ipairs(sorted_fits(Fits, true)) do
                if m.piece(id, slot) then has = true break end
            end
            local state = has and 'pieces' or (Slots.kind(slot) == 'mesh' and 'empty' or 'soon')
            out[#out + 1] = {slot = slot, state = state}
            if slot == 'BaseBody' and o.shapes then
                for _, name in ipairs(o.shapes()) do out[#out + 1] = {morph = name} end
            end
        end
        return out
    end

    -- The options page of a pack outfit ({} for an outfit with no pack controls and one variant): {header=its name},
    -- {variant=true} with two variants or more, then each section ({section=<Slot id or 'Other'>, toggles={slots}})
    -- followed by its pieces ({toggle=<material slot>, name=, desc=, controls=true when a material control is on its
    -- slots}), sections in closet/slots.lua's order, Other last. A follower (ControlledBy) and a second toggle on one
    -- material slot get no row. A piece's section: the hand map's piece (or skin: Body) on its slot, else its piece
    -- hint's slot, else a word of Model.SECTION_WORDS in its name, else Other.
    -- The piece whose toggle is open (open: its material slot) has its controls as rows right below it: each finish
    -- ({finish=n}, TextureOptions), colour ({colour=n}, VectorControls) and, when custom(n) says its colour is Custom,
    -- its channels ({channel=n, c='r'|'g'|'b'|'a'}, those its Sliders show: R, G, B when left out), each number
    -- ({number=n}, ScalarControls); n is the control's place in its list. A piece's slots: its own and its followers'.
    -- The controls on a slot no piece has close the Other section, always shown. The Shape section ({section='Shape',
    -- toggles={}}) lists each shape key ({shape=n}), then {reset_fit=true} (Reset this outfit) is the last row.
    -- Control rows carry name= and desc= (the pack's DisplayName and Description); followers get no row.
    -- depth= says how deep a row sits under its section row (none: the header, Variant, a section, Reset this outfit):
    -- a piece, a loose control and a shape key 1, a piece's control 2 (of=its piece's name), a channel one more than
    -- its colour.
    function m.options(fit_id, open, custom)
        local fit = Fits.get(fit_id)
        local cfg = fit and fit.Controls
        if not cfg then return {} end
        local function list_of(kind) return type(cfg[kind]) == 'table' and cfg[kind] or {} end
        local list = list_of('MaterialToggles')
        local function text(v) return type(v) == 'string' and v ~= '' and v or nil end
        -- The control rows of each material slot: finishes, colours (with their channels), numbers.
        local on_slot, any = {}, #list > 0 or #(fit.Variants or {}) > 1
        for _, kind in ipairs({{'TextureOptions', 'finish'}, {'VectorControls', 'colour'}, {'ScalarControls', 'number'},
            {'ShapeKeys', 'shape'}}) do
            local controls = list_of(kind[1])
            for n, c in ipairs(controls) do
                local index = type(c) == 'table' and type(c.MaterialIndex) == 'number'
                    and math.tointeger(c.MaterialIndex)
                if type(c) == 'table' and Fits.leader(controls, c) == c and (index or kind[2] == 'shape') then
                    any = true
                    local key = index or 'shape'
                    on_slot[key] = on_slot[key] or {}
                    table.insert(on_slot[key],
                        {[kind[2]] = n, name = text(c.DisplayName) or '', desc = text(c.Description)})
                    if kind[2] == 'colour' and custom and custom(n) then
                        local sliders = type(c.Sliders) == 'table' and c.Sliders or {true, true, true, false}
                        for i, ch in ipairs({'r', 'g', 'b', 'a'}) do
                            if sliders[i] then table.insert(on_slot[key], {channel = n, c = ch}) end
                        end
                    end
                end
            end
        end
        if not any then return {} end
        local hand, hints = {}, {}
        for index in pairs(fit.Skin or {}) do hand[index] = 'BaseBody' end
        for _, piece in ipairs(fit.Pieces or {}) do
            for _, index in ipairs(piece.Materials) do hand[index] = piece.Slot end
        end
        for _, h in ipairs(fit.Hints or {}) do hints[h.MaterialIndex] = hints[h.MaterialIndex] or h.Slot end
        local function index_of(t)
            local i = type(t) == 'table' and type(t.MaterialIndex) == 'number' and math.tointeger(t.MaterialIndex)
            return i and i >= 0 and i or nil
        end
        -- Each piece's slots: its own, then its followers'.
        local covers, covered = {}, {}
        for _, t in ipairs(list) do
            local index, lead = index_of(t), type(t) == 'table' and index_of(Fits.leader(list, t))
            if index and lead and not covered[index] then
                covers[lead] = covers[lead] or {}
                table.insert(covers[lead], index)
                covered[index] = true
            end
        end
        local sections, seen = {}, {}
        for _, t in ipairs(list) do
            local index = index_of(t)
            if index and not seen[index] and Fits.leader(list, t) == t then
                seen[index] = true
                local name = type(t.DisplayName) == 'string' and t.DisplayName or ''
                local id = hand[index] or hints[index]
                for _, pair in ipairs(Model.SECTION_WORDS) do
                    if not id and name:lower():find(pair[1], 1, true) then id = pair[2] end
                end
                id = id or 'Other'
                if not sections[id] then sections[id] = {}; sections[#sections + 1] = id end
                local piece = {toggle = index, name = name, section = id, desc = text(t.Description), depth = 1}
                local rows = {}
                for _, i in ipairs(covers[index] or {}) do
                    for _, row in ipairs(on_slot[i] or {}) do
                        row.depth, row.of = row.channel and 3 or 2, not row.channel and name or nil
                        rows[#rows + 1] = row
                    end
                end
                piece.controls = #rows > 0 or nil
                table.insert(sections[id], piece)
                if open == index then
                    for _, row in ipairs(rows) do table.insert(sections[id], row) end
                end
            end
        end
        -- The controls of the slots no piece has: at the end of Other.
        local loose = {}
        for index, rows in pairs(on_slot) do
            if index ~= 'shape' and not covered[index] then loose[#loose + 1] = index end
        end
        table.sort(loose)
        for _, index in ipairs(loose) do
            if not sections.Other then sections.Other = {}; sections[#sections + 1] = 'Other' end
            for _, row in ipairs(on_slot[index]) do
                row.depth = row.channel and 2 or 1
                table.insert(sections.Other, row)
            end
        end
        table.sort(sections, function(a, b) return (Slots.order(a) or math.huge) < (Slots.order(b) or math.huge) end)
        if on_slot.shape then
            for _, row in ipairs(on_slot.shape) do row.depth = 1 end
            sections[#sections + 1], sections.Shape = 'Shape', on_slot.shape
        end
        local out = {{header = fit.Outfit}}
        if #(fit.Variants or {}) > 1 then out[2] = {variant = true} end
        for _, id in ipairs(sections) do
            local row = {section = id, toggles = {}}
            out[#out + 1] = row
            for _, piece in ipairs(sections[id]) do
                if piece.toggle then row.toggles[#row.toggles + 1] = piece.toggle end
                out[#out + 1] = piece
            end
        end
        out[#out + 1] = {reset_fit = true}
        return out
    end

    function m.tiles(slot)
        local out = {{none = true}}
        for _, id in ipairs(sorted_fits(Fits, true)) do
            local piece = m.piece(id, slot)
            if piece then
                local fit = Fits.get(id)
                out[#out + 1] = {fit = id, name = piece.Name, outfit = fit.Outfit, pack = fit.Pack, off = piece.Off,
                    locked = not o.installed(id), covers = piece.Covers, also = piece.Occupies}
            end
        end
        return out
    end

    function m.worn(choices, slot)
        for _, choice in ipairs(choices) do
            for _, s in ipairs(slots_of(choice)) do
                if s == slot then return choice.fit end
            end
        end
        return nil
    end

    function m.whole(fit) return {{fit = fit}} end

    -- Wear fit's piece in slot (fit=nil: wear nothing there). Every worn piece that uses slot, or a slot the new piece
    -- occupies, comes off, whatever outfit it belongs to. A whole-outfit choice that loses a piece becomes an explicit
    -- list of its slots first. slot BaseBody picks fit's body (nil: the body rule's).
    function m.choose(choices, slot, fit)
        local piece = fit and m.piece(fit, slot)
        assert(not fit or piece, tostring(fit) .. ' has no piece in ' .. tostring(slot))
        local taken = {[slot] = true}
        for _, s in ipairs(piece and piece.Occupies or {}) do taken[s] = true end
        local function clashes(fit_id, s)
            local p = Fits.piece(fit_id, s)
            if taken[s] then return true end
            for _, occupied in ipairs(p and p.Occupies or {}) do
                if taken[occupied] then return true end
            end
            return false
        end
        local out, target = {}, nil
        for _, choice in ipairs(choices) do
            -- A whole outfit with no piece map (a pack fit, closet/fits.lua) cannot be split: it comes off whole.
            local kept, lost = {}, not choice.slots and #Fits.get(choice.fit).Pieces == 0
            for _, s in ipairs(slots_of(choice)) do
                if clashes(choice.fit, s) then lost = true else kept[#kept + 1] = s end
            end
            local copy
            if choice.fit == fit then
                target, copy = #out + 1, {fit = choice.fit, slots = kept}
            elseif lost or choice.slots then
                copy = {fit = choice.fit, slots = lost and kept or {table.unpack(choice.slots)}}
            else
                copy = {fit = choice.fit}
            end
            if not copy.slots or #copy.slots > 0 or choice.fit == fit then out[#out + 1] = copy end
        end
        if fit then
            if not target then out[#out + 1] = {fit = fit, slots = {}} target = #out end
            table.insert(out[target].slots, slot)
        end
        for i = #out, 1, -1 do
            if out[i].slots and #out[i].slots == 0 then table.remove(out, i) end
        end
        return out
    end

    return m
end

return Model
