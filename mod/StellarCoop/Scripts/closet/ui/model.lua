-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet: the menu's data model. Pure Lua, no engine calls: what the tabs, rows and tiles list, and the edits
-- of a list of choices {{fit=<UniqueFitID>, slots=<Slot ids, or nil for every piece the fit shows by default>}}
-- (the shape of Dress.plan's input). Edits never touch their input.
local Model = {}

local function sorted_fits(fits)
    local ids = {}
    for id in pairs(fits.BY_ID) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

-- o = {slots=closet.slots, fits=closet.fits, installed=function(fit)->bool, adult=bool}
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

    function m.tabs()
        local out = {}
        for _, menu in ipairs(Slots.MENUS) do
            if o.adult or not menu[2] then out[#out + 1] = menu[1] end
        end
        return out
    end

    function m.rows(tab)
        local out = {}
        if tab == 'full' then
            for _, id in ipairs(sorted_fits(Fits)) do
                local fit = Fits.get(id)
                out[#out + 1] = {whole = id, outfit = fit.Outfit, pack = fit.Pack, locked = not o.installed(id)}
            end
            return out
        end
        for _, slot in ipairs(Slots.in_menu(tab)) do
            local has = false
            for _, id in ipairs(sorted_fits(Fits)) do
                if Fits.piece(id, slot) then has = true break end
            end
            local state = has and 'pieces' or (Slots.kind(slot) == 'mesh' and 'empty' or 'soon')
            out[#out + 1] = {slot = slot, state = state}
        end
        return out
    end

    function m.tiles(slot)
        local out = {{none = true}}
        for _, id in ipairs(sorted_fits(Fits)) do
            local piece = Fits.piece(id, slot)
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
    -- list of its slots first.
    function m.choose(choices, slot, fit)
        local piece = fit and Fits.piece(fit, slot)
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
            local kept, lost = {}, false
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
