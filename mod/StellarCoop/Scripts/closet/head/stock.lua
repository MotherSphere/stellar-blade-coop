-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet's stock head catalogue: the game's hair and ponytail rows (ItemTable, EquipmentTable,
-- EquipmentMaterialTable, read by the caller) as pack-shaped items (closet/cns_import.lua's item shape), so the
-- Head tab, fits and options treat a stock piece like a pack piece. Pure: no engine call.
--
-- Stock.items(rows) -> items, missing
--   rows = {items={[row]={Category, Name, Asset2D, EquipmentAlias, EquipmentAlias2}},
--           equipment={[alias]={Type, MountingResourcePath, AnimAssetPath, MaterialGroup, RelativeRotation,
--                               bUseHidePonytail}},
--           materials={{Group, VariationIndex, MaterialIndex, MaterialAssetPath, IconColorAssetPath}...},
--           names={[key]=text}, mats={[path]={parent=path, vectors={[name]={R,G,B,A}}}}}
--   items = {['SB.<row>'] = item}; missing = sorted lines for rows left out, 'Hair_Nikke_02: no equipment row ...'.
-- Every hair row of the game whose parts exist is listed. Colour: a variant's material that has MA_CH_Hair as its
-- parent gets RootColor and TipColor controls (DyeColor too when the instance sets one); any other master (the Nikke
-- hair, a hairpin) gets none. The ponytail a stock hair brings is SB.Ponytail_Long: which length shows is for the
-- wear part, not here.
local Stock = {}

-- Asset data: SB/Content/Art/Character/Generic/GlobalMasterMaterials/MA_CH_Hair.uasset, the parent of every stock
-- hair material instance (read 27 Nov 2026 in the dumps of MA_CH_Hair and of MI_EVE_HR_01_TypeA).
Stock.HAIR_MASTER = '/Game/Art/Character/Generic/GlobalMasterMaterials/MA_CH_Hair'

-- EquipmentTable rows (SB/Content/Local/Data/EquipmentTable.uasset, read 27 Nov 2026): the default hair's ponytail,
-- long (Hair_Default_Part2, CH_P_EVE_Hair_PonyTail_2) and short (Hair_Default_Part2_Short, ..._PonyTail_Short), both
-- in material group EM_Hair_Default_Part2. Every stock hair's ponytail is the same mesh: only its group changes.
local PONYTAILS = {{id = 'SB.Ponytail_Long', alias = 'Hair_Default_Part2'},
    {id = 'SB.Ponytail_Short', alias = 'Hair_Default_Part2_Short'}}
Stock.PONYTAIL_NONE = 'SB.Ponytail_None'

-- MA_CH_Hair's own defaults of RootColor and TipColor (the master's parameter list), for an instance that leaves
-- one to its parent.
local MASTER_VALUE = {RootColor = {0.1098, 0.0745, 0.0471, 1}, TipColor = {0.1098, 0.0745, 0.051, 1}}
local COLOURS = {{'RootColor', 'Root colour'}, {'TipColor', 'Tip colour'}, {'DyeColor', 'Dye colour'}}

-- A table's path "Class'/Game/X.X'" -> '/Game/X.X'; 'None' and '' -> nil.
local function plain(p)
    if type(p) ~= 'string' then return nil end
    p = p:match("^%w+'(.*)'$") or p
    if p == '' or p == 'None' then return nil end
    return p
end

-- A package path with its '.Object' part cut: a parent is written either way.
local function package_of(p) return (plain(p) or ''):gsub('%.[^./]*$', '') end

local function lists()
    return {ShapeKeys = {}, MaterialToggles = {}, ScalarControls = {}, VectorControls = {}, TextureOptions = {}}
end

-- The variations of a material group in order: {slots={[MaterialIndex+1]=path}, icon=}.
local function group_variations(materials, group)
    local by, order = {}, {}
    for _, m in ipairs(materials) do
        if m.Group == group then
            local v = by[m.VariationIndex]
            if not v then v = {slots = {}} by[m.VariationIndex] = v order[#order + 1] = m.VariationIndex end
            local path = plain(m.MaterialAssetPath)
            if path then v.slots[m.MaterialIndex + 1] = path end
            v.icon = v.icon or plain(m.IconColorAssetPath)
        end
    end
    table.sort(order)
    local out = {}
    for _, index in ipairs(order) do out[#out + 1] = by[index] end
    return out
end

local function colour_controls(slots, mats)
    local controls = {}
    local last = 0
    for i in pairs(slots) do if i > last then last = i end end
    for i = 1, last do
        local mat = slots[i] and mats[slots[i]]
        if mat and package_of(mat.parent) == Stock.HAIR_MASTER then
            for _, c in ipairs(COLOURS) do
                local name = c[1]
                local v = mat.vectors and mat.vectors[name]
                if v or name ~= 'DyeColor' then
                    local value = v and {v.R, v.G, v.B, v.A or 1} or {table.unpack(MASTER_VALUE[name])}
                    controls[#controls + 1] = {DisplayName = c[2], ParamName = name, MaterialIndex = i - 1,
                        Value = value}
                end
            end
        end
    end
    return controls
end

local function variants_of(rows, group, mesh)
    local variants = {}
    for _, v in ipairs(group_variations(rows.materials or {}, group)) do
        local configs = lists()
        configs.VectorControls = colour_controls(v.slots, rows.mats or {})
        variants[#variants + 1] = {Mesh = mesh, Materials = v.slots, Icon = v.icon, UserConfigs = configs}
    end
    if #variants == 0 then variants[1] = {Mesh = mesh, Materials = {}, UserConfigs = lists()} end
    return variants
end

local function rotation_of(eq)
    local r = eq.RelativeRotation
    if type(r) ~= 'table' then return nil end
    return {Pitch = r.Pitch or 0, Yaw = r.Yaw or 0, Roll = r.Roll or 0}
end

local function item_of(rows, id, slot, name, image, eq, extra)
    local mesh = plain(eq.MountingResourcePath)
    local variants = variants_of(rows, eq.MaterialGroup, mesh)
    local item = {UniqueFitID = id, Slot = slot, Origin = 'original', DisplayName = name, Image = image,
        AnimationBP = plain(eq.AnimAssetPath), Rotation = rotation_of(eq), HidePonytail = false, Mesh = mesh,
        Variants = variants, UserConfigs = variants[1].UserConfigs, PieceHints = {}}
    for k, v in pairs(extra or {}) do item[k] = v end
    return item
end

-- A row not in the Hair category (earrings, glasses, ...) is not ours; a fake row without one is taken.
local function is_hair(row)
    return type(row.Category) ~= 'string' or row.Category:find('Hair$') ~= nil
end

function Stock.items(rows)
    local items, missing = {}, {}
    local equipment = rows.equipment or {}
    local names = rows.names or {}
    local function lost(row, why) missing[#missing + 1] = row .. ': ' .. why end

    local have_long = false
    for _, p in ipairs(PONYTAILS) do
        local eq = equipment[p.alias]
        if eq and plain(eq.MountingResourcePath) then
            items[p.id] = item_of(rows, p.id, 'Ponytail', names[p.id] or p.alias, nil, eq)
            have_long = have_long or p.id == 'SB.Ponytail_Long'
        else
            lost((p.id:gsub('^SB%.', '')), 'no equipment row ' .. p.alias)
        end
    end
    local none = lists()
    items[Stock.PONYTAIL_NONE] = {UniqueFitID = Stock.PONYTAIL_NONE, Slot = 'Ponytail', Origin = 'original',
        DisplayName = names[Stock.PONYTAIL_NONE] or 'Ponytail_None', HidePonytail = false, Mesh = '',
        Variants = {{Mesh = '', Materials = {}, UserConfigs = none}}, UserConfigs = none, PieceHints = {}}

    for row, it in pairs(rows.items or {}) do
        local alias = is_hair(it) and plain(it.EquipmentAlias)
        if alias then
            local eq = equipment[alias]
            if not eq then
                lost(row, 'no equipment row ' .. alias)
            elseif not plain(eq.MountingResourcePath) then
                lost(row, 'no mesh in equipment row ' .. alias)
            else
                local hide = plain(it.EquipmentAlias2) == nil or eq.bUseHidePonytail == true
                local id = 'SB.' .. row
                items[id] = item_of(rows, id, 'Hair', names[it.Name] or row, plain(it.Asset2D), eq,
                    {HidePonytail = hide, Ponytail = (not hide and have_long) and 'SB.Ponytail_Long' or nil})
            end
        end
    end
    table.sort(missing)
    return items, missing
end

return Stock
