-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet's stock suits: the game's NanoSuit item rows (read live by closet/head/stock.lua's Stock.read) as
-- pack-shaped Full outfit items (closet/cns_import.lua's item shape), listed under Original. Pure: no engine calls.
--
-- Suits.items(rows) -> items, missing
--   rows: Stock.read's rows (items, equipment, names). items = {['SB.<ItemTable row>'] = item}; missing = sorted lines
--   for suit rows left out ('BS_Gone: no equipment row BS_Gone').
-- Probe 9 (build 26123051, 27 Nov 2026): 131 ItemTable rows with Category 4 (ESBItemCategory_NanoSuit); each one's
-- EquipmentAlias names its EquipmentTable row (Type 13, MountingResourcePath the suit mesh, MaterialGroup None for all
-- 131, so no colour groups; bUseHidePonytail true on some). Colour versions are rows of their own whose alias is
-- '<base alias>_VarN' (BS_Default_Var2, BS_05_Var2 of item row BS_05_Var2_E), each with its own mesh: such a row is a
-- variant of the suit whose alias is <base alias> (the options page's Variant row, named for the row), not a fit of
-- its own. A _VarN row with no base row is a suit of its own.
local Stock = require('closet.head.stock')
local Suits = {}

local function lists()
    return {ShapeKeys = {}, MaterialToggles = {}, ScalarControls = {}, VectorControls = {}, TextureOptions = {}}
end

function Suits.items(rows)
    local items, missing = {}, {}
    local equipment, names = rows.equipment or {}, rows.names or {}
    -- Each suit row with a mesh, by its equipment alias.
    local by_alias, order, rows_in = {}, {}, {}
    for row in pairs(rows.items or {}) do rows_in[#rows_in + 1] = row end
    table.sort(rows_in) -- Of two rows on one alias the first by name is the suit, the same each read.
    for _, row in ipairs(rows_in) do
        local it = rows.items[row]
        if type(it.Category) == 'string' and it.Category:find('NanoSuit$') then
            local alias = Stock.plain(it.EquipmentAlias)
            local eq = alias and equipment[alias]
            if not alias then
                missing[#missing + 1] = row .. ': no equipment alias'
            elseif not eq then
                missing[#missing + 1] = row .. ': no equipment row ' .. alias
            elseif not Stock.plain(eq.MountingResourcePath) then
                missing[#missing + 1] = row .. ': no mesh in equipment row ' .. alias
            elseif by_alias[alias] then
                missing[#missing + 1] = row .. ': equipment row ' .. alias .. ' is ' .. by_alias[alias].row .. "'s"
            else
                by_alias[alias] = {row = row, it = it, eq = eq, name = names[row] or row}
                order[#order + 1] = alias
            end
        end
    end
    table.sort(order)
    local variants = {} -- base alias -> {{n, suit}...}
    for _, alias in ipairs(order) do
        local base, n = alias:match('^(.+)_Var(%d+)$')
        if base and by_alias[base] then
            variants[base] = variants[base] or {}
            table.insert(variants[base], {tonumber(n), by_alias[alias]})
            by_alias[alias] = nil
        end
    end
    for alias, s in pairs(by_alias) do
        local configs = lists()
        local mesh = Stock.plain(s.eq.MountingResourcePath)
        local list = {{Name = s.name, Mesh = mesh, Materials = {}, UserConfigs = configs}}
        local more = variants[alias] or {}
        table.sort(more, function(a, b) return a[1] < b[1] end)
        for _, v in ipairs(more) do
            list[#list + 1] = {Name = v[2].name, Mesh = Stock.plain(v[2].eq.MountingResourcePath), Materials = {},
                UserConfigs = configs}
        end
        local id = 'SB.' .. s.row
        -- HidePonytail: the base row's bUseHidePonytail, kept on the item (closet/dress.lua does not read it).
        items[id] = {UniqueFitID = id, Slot = 'FullOutfit', Origin = 'original', DisplayName = s.name,
            Image = Stock.plain(s.it.Asset2D), Mesh = mesh, HidePonytail = s.eq.bUseHidePonytail == true,
            Variants = list, UserConfigs = configs, PieceHints = {}}
    end
    table.sort(missing)
    return items, missing
end

return Suits
