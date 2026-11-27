-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet's stock head catalogue: the game's hair and ponytail rows (ItemTable, EquipmentTable,
-- EquipmentMaterialTable, read by the caller) as pack-shaped items (closet/cns_import.lua's item shape), so the
-- Head tab, fits and options treat a stock piece like a pack piece. Stock.items is pure; Stock.read reaches the game
-- only through env.
--
-- Stock.read(env) -> rows | nil, why: the three live tables as the rows below, each engine call in a pcall.
--   env = {find(path) -> UDataTable or nil (StaticFindObject-like), load(path) -> object or nil (LoadAsset-like),
--          text(v) -> string (an FText's words; a string is an ItemStringTable key, closet/head/cut.lua's), log(line)}
-- Stock.build(env) -> items[, why]: Stock.items(Stock.read(env)) plus Cut.items(env). A failed read (or a raise in
-- Stock.items) gives the cut hairs alone and its why. The why and each row left out are logged once a Lua load.
--
-- Stock.items(rows) -> items, missing
--   rows = {items={[row]={Category, Name, Asset2D, EquipmentAlias, EquipmentAlias2}},
--           equipment={[alias]={Type, MountingResourcePath, AnimAssetPath, MaterialGroup, RelativeRotation,
--                               bUseHidePonytail}},
--           materials={{Group, VariationIndex, MaterialIndex, MaterialAssetPath, IconColorAssetPath}...},
--           names={[key]=text}, mats={[path]={parent=path, vectors={[name]={R,G,B,A}}, scalars={[name]=x}}},
--           mesh_mats={[mesh]={[slot+1]=path}} (a one-colour hair's mesh materials)}
--   items = {['SB.<row>'] = item}; missing = sorted lines for rows left out, 'Hair_Nikke_02: no equipment row ...'.
-- Every hair row of the game whose parts exist is listed. Controls (Schizo, 27 Nov 2026: every hair adjustable,
-- colour, scatter, gloss and every main parameter it sets): a variant's material under MA_CH_Hair gets RootColor and
-- TipColor, then every other colour and number its instance chain sets (not its master's own; DyeColor where the
-- instance sets it). Other slots of that hair (a hairpin) get none. A hair with no slot under MA_CH_Hair (the Nikke
-- hairs' own master) gets every colour and number its instances set. A one-colour hair (a salon row with no
-- material) takes these from its mesh's own materials (rows.mesh_mats), which it keeps. The ponytail a stock hair
-- brings is SB.Ponytail_Long: which length shows is for the
-- wear part, not here.
local Stock = {}

-- Asset data: SB/Content/Art/Character/Generic/GlobalMasterMaterials/MA_CH_Hair.uasset, the parent of every stock
-- hair material instance (read 27 Nov 2026 in the dumps of MA_CH_Hair and of MI_EVE_HR_01_TypeA).
Stock.HAIR_MASTER = '/Game/Art/Character/Generic/GlobalMasterMaterials/MA_CH_Hair'

-- EquipmentTable rows (SB/Content/Local/Data/EquipmentTable.uasset, read 27 Nov 2026): the default hair's ponytail,
-- long (Hair_Default_Part2, CH_P_EVE_Hair_PonyTail_2) and short (Hair_Default_Part2_Short, ..._PonyTail_Short), both
-- in material group EM_Hair_Default_Part2. Every stock hair's ponytail is the same mesh: only its group changes.
-- Glyph: its tile's picture (closet/ui/icons/<glyph>.png): each stock ponytail its own (Schizo, 27 Nov 2026).
local PONYTAILS = {{id = 'SB.Ponytail_Long', alias = 'Hair_Default_Part2', glyph = 'ponytail_long'},
    {id = 'SB.Ponytail_Short', alias = 'Hair_Default_Part2_Short', glyph = 'ponytail_short'}}
Stock.PONYTAIL_NONE = 'SB.Ponytail_None'

local COLOURS = {{'RootColor', 'Root colour'}, {'TipColor', 'Tip colour'}, {'DyeColor', 'Dye colour'}}
-- The hair's main numbers (MA_CH_Hair's scalar parameters that change its look): only these are controls; the
-- technical ones (MipBias, MaskedAlpha, EdgeMask*, Occlusion*, LowQualityScatter) crowded the options page (Schizo,
-- 27 Nov 2026). Their on-screen names are ui/text's closet.head.params, by parameter name.
local NUMBERS = {Brightness = true, Scatter = true, Roughness = true, Specular = true, TipPower = true,
    DyeRoughness = true, DyeScatter = true}
-- Vectors that place or clip the hair, not colour it (MA_CH_Hair's ClipMask*, ExclusivePlane*, Tangent*): no control.
local function layout(name)
    return name:find('^ClipMask') or name:find('^ExclusivePlane') or name:find('^Tangent') or name:find('Pivot')
        or name:find('Axis$')
end

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

-- A vector's value on a material: its own, else its parent's (up the chain the caller loaded into mats, the master
-- last), else nil.
local function vector_of(mats, path, name)
    for _ = 1, 8 do
        local mat = mats[path] or mats[package_of(path)]
        if not mat then return nil end
        local v = mat.vectors and mat.vectors[name]
        if v then return v end
        path = mat.parent
        if not plain(path) then return nil end
    end
end

-- True when the chain of parents from a material reaches MA_CH_Hair (the master itself need not be in mats).
local function under_hair_master(mats, path)
    for _ = 1, 8 do
        local mat = mats[path] or mats[package_of(path)]
        if not mat or not plain(mat.parent) then return false end
        if package_of(mat.parent) == Stock.HAIR_MASTER then return true end
        path = mat.parent
    end
    return false
end

-- Every vector and scalar the instances of a material's chain set, the nearest instance's value first: {vectors=
-- {[name]=v}, scalars={[name]=x}}. The master itself sets none (its own values are not read).
local function set_by_chain(mats, path)
    local out = {vectors = {}, scalars = {}}
    for _ = 1, 8 do
        local mat = mats[path] or mats[package_of(path)]
        if not mat then break end
        for k, v in pairs(mat.vectors or {}) do if out.vectors[k] == nil then out.vectors[k] = v end end
        for k, x in pairs(mat.scalars or {}) do if out.scalars[k] == nil then out.scalars[k] = x end end
        path = mat.parent
        if not plain(path) then break end
    end
    return out
end
local function sorted_keys(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = k end
    table.sort(out)
    return out
end
-- lost(why) is called for a root or tip colour no material of a hair chain has: its control is left out.
-- The controls of one ParamName and one value on several slots made one, its MaterialIndices every such slot (YoRHa's
-- four alike slots listed each control four times, Schizo's video of 27 Nov 2026). A slot whose value differs keeps
-- its own control, so a value left alone paints each slot as it was.
local function alike(a, b)
    if type(a) == 'table' and type(b) == 'table' then
        for k = 1, 4 do if math.abs((a[k] or 0) - (b[k] or 0)) > 1e-6 then return false end end
        return true
    end
    return type(a) == 'number' and type(b) == 'number' and math.abs(a - b) <= 1e-6
end
local function merged(list)
    local out = {}
    for _, c in ipairs(list) do
        local into
        for _, o in ipairs(out) do
            if o.ParamName == c.ParamName and alike(o.Value, c.Value) then into = o; break end
        end
        if into then
            into.MaterialIndices = into.MaterialIndices or {into.MaterialIndex}
            into.MaterialIndices[#into.MaterialIndices + 1] = c.MaterialIndex
        else
            out[#out + 1] = c
        end
    end
    return out
end
local function hair_controls(slots, mats, lost)
    local configs = lists()
    local vectors, scalars = configs.VectorControls, configs.ScalarControls
    local last = 0
    for i in pairs(slots) do if i > last then last = i end end
    local any_hair = false
    for i = 1, last do any_hair = any_hair or (slots[i] and mats[slots[i]] and under_hair_master(mats, slots[i])) end
    for i = 1, last do
        local mat = slots[i] and mats[slots[i]]
        local hair = mat and under_hair_master(mats, slots[i])
        if mat and (hair or not any_hair) then
            local set = set_by_chain(mats, slots[i])
            local done = {}
            if hair then
                for _, c in ipairs(COLOURS) do
                    local name = c[1]
                    -- Dye is only a control where the instance itself sets it.
                    local v = name == 'DyeColor' and mat.vectors and mat.vectors[name] or
                        name ~= 'DyeColor' and vector_of(mats, slots[i], name)
                    if v then
                        vectors[#vectors + 1] = {DisplayName = c[2], ParamName = name, MaterialIndex = i - 1,
                            Value = {v.R, v.G, v.B, v.A or 1}}
                    elseif name ~= 'DyeColor' then
                        lost(('no %s on %s or its parents'):format(name, slots[i]))
                    end
                    done[name] = true
                end
            end
            for _, name in ipairs(sorted_keys(set.vectors)) do
                local v = set.vectors[name]
                -- A hair's colours are root, tip and dye alone; another material's every colour.
                if not hair and not done[name] and not layout(name) and type(v.R) == 'number' then
                    vectors[#vectors + 1] = {DisplayName = name, ParamName = name, MaterialIndex = i - 1,
                        Value = {v.R, v.G or 0, v.B or 0, v.A or 1}}
                end
            end
            for _, name in ipairs(sorted_keys(set.scalars)) do
                local x = set.scalars[name]
                if type(x) == 'number' and NUMBERS[name] then
                    scalars[#scalars + 1] = {DisplayName = name, ParamName = name,
                        MaterialIndex = i - 1, Value = x, Min = math.min(0, x * 2), Max = math.max(1, x * 2)}
                end
            end
        end
    end
    configs.VectorControls, configs.ScalarControls = merged(vectors), merged(scalars)
    return configs
end
Stock.hair_controls = hair_controls

-- The master a material's chain ends at, by its object name ('MA_ACC'), '' when unknown.
local function master_of(mats, path)
    for _ = 1, 8 do
        local mat = mats[path] or mats[package_of(path)]
        if not mat or not plain(mat.parent) then break end
        path = mat.parent
    end
    return (plain(path) or ''):match('([^./]+)$') or ''
end

-- Earrings and glasses: the look-changing colours and numbers of their masters (MA_ACC, MA_ACC_Glass; names as the
-- asset dumps list them, 27 Nov 2026). Each is a control on the slot whose material chain ends at that master and
-- sets it; the other parameters (flake, AO, textures, glass fresnel and HDR) are not.
local ACC_PARAMS = {
    MA_ACC = {vectors = {'Base Color Tint', 'MetalTint', 'GemTint', 'Gem02_Tint'},
        scalars = {'Brightness', 'Metallic', 'GlobalRoughness'}},
    MA_ACC_Glass = {vectors = {'GlassColor In', 'GlassColor Out'}, scalars = {'Opacity Inner', 'Opacity Out'}},
}
local function accessory_controls(slots, mats, lost)
    local configs = lists()
    local last = 0
    for i in pairs(slots) do if i > last then last = i end end
    for i = 1, last do
        local allow = slots[i] and mats[slots[i]] and ACC_PARAMS[master_of(mats, slots[i])]
        if allow then
            local set = set_by_chain(mats, slots[i])
            for _, name in ipairs(allow.vectors) do
                local v = set.vectors[name]
                if type(v) == 'table' and type(v.R) == 'number' then
                    configs.VectorControls[#configs.VectorControls + 1] = {DisplayName = name, ParamName = name,
                        MaterialIndex = i - 1, Value = {v.R, v.G or 0, v.B or 0, v.A or 1}}
                end
            end
            for _, name in ipairs(allow.scalars) do
                local x = set.scalars[name]
                if type(x) == 'number' then
                    configs.ScalarControls[#configs.ScalarControls + 1] = {DisplayName = name, ParamName = name,
                        MaterialIndex = i - 1, Value = x, Min = math.min(0, x * 2), Max = math.max(1, x * 2)}
                end
            end
        end
    end
    configs.VectorControls, configs.ScalarControls = merged(configs.VectorControls), merged(configs.ScalarControls)
    return configs
end
Stock.accessory_controls = accessory_controls

-- EVE's own eyes: Mesh_Face's mesh, from the asset dump of CH_P_EVE_Face_Jali3 (27 Nov 2026): material slot 4 EyeBall =
-- MI_EyeRefractive1 and slot 7 brow = MI_EyeBrow1. The colour parameters that change the look, per slot.
Stock.FACE_MESH = '/Game/Art/Character/PC/CH_P_EVE_Head/CH_P_EVE_Face_Jali3.CH_P_EVE_Face_Jali3'
Stock.EYES_ID = 'SB.Eyes_Own'
local EYES = {
    {slot = 4, vectors = {{'IrisHueTint', 'Iris colour'}, {'ScleraTint', 'Sclera colour'}},
        scalars = {'IrisHueShift', 'IrisBrightness'}},
    {slot = 7, vectors = {{'BaseColour', 'Brow colour'}}, scalars = {}},
}
local function eyes_controls(rows, lost)
    local configs = lists()
    local slots, mats = (rows.mesh_mats or {})[Stock.FACE_MESH] or {}, rows.mats or {}
    for _, e in ipairs(EYES) do
        local path = slots[e.slot + 1]
        if not (path and mats[path]) then
            lost('no material in slot ' .. e.slot .. ' of ' .. Stock.FACE_MESH)
        else
            local set = set_by_chain(mats, path)
            for _, p in ipairs(e.vectors) do
                local v = vector_of(mats, path, p[1])
                if v then
                    configs.VectorControls[#configs.VectorControls + 1] = {DisplayName = p[2], ParamName = p[1],
                        MaterialIndex = e.slot, Value = {v.R, v.G, v.B, v.A or 1}}
                else
                    lost('no ' .. p[1] .. ' on ' .. path .. ' or its parents')
                end
            end
            for _, name in ipairs(e.scalars) do
                local x = set.scalars[name]
                if type(x) == 'number' then
                    configs.ScalarControls[#configs.ScalarControls + 1] = {DisplayName = name, ParamName = name,
                        MaterialIndex = e.slot, Value = x, Min = math.min(0, x * 2), Max = math.max(1, x * 2)}
                end
            end
        end
    end
    return configs
end

-- controls(slots, mats, lost) builds a variant's controls from its materials by slot: hair_controls for hair.
local function variants_of(rows, group, mesh, lost, controls)
    local variants = {}
    for _, v in ipairs(group_variations(rows.materials or {}, group)) do
        -- A variation with no material of its own (a one-colour hair) keeps its mesh's materials: its controls come
        -- from those (rows.mesh_mats), none while they are not known.
        local own = next(v.slots) ~= nil
        local slots = own and v.slots or (rows.mesh_mats or {})[mesh] or {}
        variants[#variants + 1] = {Mesh = mesh, Materials = v.slots, Icon = v.icon,
            UserConfigs = controls(slots, rows.mats or {}, lost)}
    end
    if #variants == 0 then
        variants[1] = {Mesh = mesh, Materials = {},
            UserConfigs = controls((rows.mesh_mats or {})[mesh] or {}, rows.mats or {}, lost)}
    end
    return variants
end

local function rotation_of(eq)
    local r = eq.RelativeRotation
    if type(r) ~= 'table' then return nil end
    return {Pitch = r.Pitch or 0, Yaw = r.Yaw or 0, Roll = r.Roll or 0}
end

local function item_of(rows, id, slot, name, image, eq, extra, lost, controls)
    local mesh = plain(eq.MountingResourcePath)
    local variants = variants_of(rows, eq.MaterialGroup, mesh, lost, controls or hair_controls)
    local item = {UniqueFitID = id, Slot = slot, Origin = 'original', DisplayName = name, Image = image,
        AnimationBP = plain(eq.AnimAssetPath), Rotation = rotation_of(eq), HidePonytail = false, Mesh = mesh,
        Variants = variants, UserConfigs = variants[1].UserConfigs, PieceHints = {}}
    for k, v in pairs(extra or {}) do item[k] = v end
    return item
end

-- A row's closet slot by its category: Hair, EarRing -> EarringL (one mesh carries both ears), FaceAccessory ->
-- Glasses. Another category is not ours; a fake row without one is taken as hair.
local function slot_of(row)
    local c = row.Category
    if type(c) ~= 'string' then return 'Hair' end
    return c:find('Hair$') and 'Hair' or c:find('EarRing$') and 'EarringL' or c:find('FaceAccessory$') and 'Glasses'
        or nil
end

function Stock.items(rows)
    local items, missing = {}, {}
    local equipment = rows.equipment or {}
    local names = rows.names or {}
    local said = {}
    local function lost(row, why)
        local line = row .. ': ' .. why
        if not said[line] then said[line] = true missing[#missing + 1] = line end
    end

    local have_long = false
    for _, p in ipairs(PONYTAILS) do
        local eq = equipment[p.alias]
        if eq and plain(eq.MountingResourcePath) then
            items[p.id] = item_of(rows, p.id, 'Ponytail', names[p.id] or p.alias, nil, eq, nil,
                function(why) lost(p.id:gsub('^SB%.', ''), why) end)
            items[p.id].Glyph = p.glyph
            have_long = have_long or p.id == 'SB.Ponytail_Long'
        else
            lost((p.id:gsub('^SB%.', '')), 'no equipment row ' .. p.alias)
        end
    end
    local none = lists()
    items[Stock.PONYTAIL_NONE] = {UniqueFitID = Stock.PONYTAIL_NONE, Slot = 'Ponytail', Origin = 'original',
        DisplayName = names[Stock.PONYTAIL_NONE] or 'Ponytail_None', HidePonytail = false, Mesh = '',
        Glyph = 'ponytail_none',
        Variants = {{Mesh = '', Materials = {}, UserConfigs = none}}, UserConfigs = none, PieceHints = {}}

    for row, it in pairs(rows.items or {}) do
        local slot = slot_of(it)
        local alias = slot and plain(it.EquipmentAlias)
        if slot and not alias then
            lost(row, 'no equipment alias')
        elseif alias then
            local eq = equipment[alias]
            if not eq then
                lost(row, 'no equipment row ' .. alias)
            elseif not plain(eq.MountingResourcePath) then
                lost(row, 'no mesh in equipment row ' .. alias)
            else
                local id = 'SB.' .. row
                local function why(w) lost(row, w) end
                if slot == 'Hair' then
                    local hide = plain(it.EquipmentAlias2) == nil or eq.bUseHidePonytail == true
                    items[id] = item_of(rows, id, slot, names[it.Name] or row, plain(it.Asset2D), eq,
                        {HidePonytail = hide, Ponytail = (not hide and have_long) and 'SB.Ponytail_Long' or nil}, why)
                else -- Earrings carry their AnimAssetPath (KawaiiPhysics, probe 8); glasses have none.
                    items[id] = item_of(rows, id, slot, names[it.Name] or row, plain(it.Asset2D), eq, nil, why,
                        accessory_controls)
                end
            end
        end
    end

    -- EVE's own eyes: no mesh swap, colours on Mesh_Face's slots 4 and 7 (the menu locks the row for another face).
    local configs = eyes_controls(rows, function(why) lost('Eyes_Own', why) end)
    items[Stock.EYES_ID] = {UniqueFitID = Stock.EYES_ID, Slot = 'Eyes', Origin = 'original',
        DisplayName = names[Stock.EYES_ID] or 'Eyes_Own', HidePonytail = false, Mesh = '',
        Variants = {{Mesh = '', Materials = {}, UserConfigs = configs}}, UserConfigs = configs, PieceHints = {}}
    table.sort(missing)
    return items, missing
end

-- The live tables (build 26123051): FUN_14262edd0 loads L"/Game/Local/" joined with an entry of DAT_146f68d30, among
-- them "Data/ItemTable.ItemTable" 0x145bf6dc0, "Data/EquipmentTable.EquipmentTable" 0x145bf7240 and
-- "Data/EquipmentMaterialTable.EquipmentMaterialTable" 0x145bf7208.
Stock.TABLES = {'/Game/Local/Data/ItemTable.ItemTable', '/Game/Local/Data/EquipmentTable.EquipmentTable',
    '/Game/Local/Data/EquipmentMaterialTable.EquipmentMaterialTable'}
-- ESBItemCategory_Hair = 21: the enumerator array 0x145e2b9a0 pairs the name 0x145e49098 with 21 (a UE4SS enum
-- property reads as its number). A string category (a fake, a future UE4SS) passes as it is.
-- Read again 27 Nov 2026 (the same array, 16-byte entries of name pointer and value): 0x145e49110 "ESBItemCategory_
-- FaceAccessory" pairs with 22 and 0x145e49130 "ESBItemCategory_EarRing" with 23 (the number probe 8 read in game).
-- Read again 27 Nov 2026: 0x145e48ec8 "ESBItemCategory_NanoSuit" pairs with 4 (the entry at 0x145e2b9e0: name pointer
-- 0x145e48ec8, value 4); probe 9 compares the live Category with it.
Stock.NANOSUIT = 4
local CATEGORIES = {[4] = 'ESBItemCategory_NanoSuit', [21] = 'ESBItemCategory_Hair',
    [22] = 'ESBItemCategory_FaceAccessory', [23] = 'ESBItemCategory_EarRing'}

-- Row fields and their reflected types (EPropertyGenFlags in the FGenericPropertyParams that name them): ItemTable
-- (SBItemTableProperty) Asset2D Str (0x145e0edf0), EquipmentAlias and EquipmentAlias2 Name (0x145e0d818, 0x145e0d7f0),
-- Name an FText (the asset dump: an ItemStringTable key); EquipmentTable (SBEquipmentTableProperty)
-- MountingResourcePath Str (0x145dfcb60), MaterialGroup Name (0x145dfca98), bUseHidePonytail Bool (0x145dfc2d0);
-- EquipmentMaterialTable (SBEquipmentMaterialTableProperty) MaterialAssetPath Str (0x145dfb308), IconColorAssetPath
-- Str (0x145dfb380). Checked against SB/Content/Local/Data/{ItemTable,EquipmentTable,EquipmentMaterialTable}.uasset.
local ITEM_FIELDS = {'Asset2D', 'EquipmentAlias', 'EquipmentAlias2'}
local EQUIPMENT_FIELDS = {'MountingResourcePath', 'AnimAssetPath', 'MaterialGroup'}
local MATERIAL_FIELDS = {'Group', 'MaterialAssetPath', 'IconColorAssetPath'}

local U = require('core.unreal')
local Cut = require('closet.head.cut')

local function str(v)
    local ok, s = pcall(U.text, v)
    return ok and type(s) == 'string' and s or nil
end
local function num(v) return tonumber(U.value_of(v)) end
local function copy(row, fields, out)
    for _, f in ipairs(fields) do out[f] = str(row[f]) end
    return out
end

-- Every row of a table as fn(name, row). How UE4SS's Lua reaches the rows, from this repo's in-game use: ForEachRow
-- gives each row's name (fight/gunmode/data.lua), FindRow(string) gives the row whose fields read by name
-- (fight/gunmode/aim.lua: "Only FindRow(string) is used: another lookup crashed"). Raises on an engine error.
local function each_row(dt, fn)
    local names = {}
    dt:ForEachRow(function(key) names[#names + 1] = str(key) end)
    for _, n in ipairs(names) do
        local row = U.value_of(dt:FindRow(n))
        if row ~= nil then fn(n, row) end
    end
    return #names
end

-- A material and its parents up to the master into mats, keyed by object path: {parent=path, vectors, scalars}.
-- Engine facts as closet/ui/probe.lua's test 6 cites them: UMaterialInstance.VectorParameterValues
-- TArray<FVectorParameterValue> at 0xf0 (params 0x1465da110), its ParameterInfo.Name an FName; Parent and
-- ParameterValue (FLinearColor) as the MI_EVE_HR_14_TypeA asset dump holds them. ScalarParameterValues
-- TArray<FScalarParameterValue> at 0xe0 (params 0x1465d9fe8, name 0x145b52468, its struct's params 0x1465da018),
-- ParameterValue a float (Ghidra, build 26123051, 27 Nov 2026). A master has neither: pcall gives none.
local function path_of(o)
    local ok, p = pcall(function() return str(o:GetFullName()):match('^%S+ (.+)$') end)
    return ok and p or nil
end
local function add_chain(mats, path, object)
    for _ = 1, 8 do
        if not path or not object or mats[path] then return end
        local vectors = {}
        pcall(U.each, object.VectorParameterValues, function(_, p)
            local ok, name = pcall(function() return str(p.ParameterInfo.Name) end)
            local v = U.value_of(p.ParameterValue)
            if ok and name and v ~= nil then
                vectors[name] = {R = num(v.R), G = num(v.G), B = num(v.B), A = num(v.A)}
            end
        end)
        local scalars = {}
        pcall(U.each, object.ScalarParameterValues, function(_, p)
            local ok, name = pcall(function() return str(p.ParameterInfo.Name) end)
            local x = num(p.ParameterValue)
            if ok and name and x ~= nil then scalars[name] = x end
        end)
        local ok, parent = pcall(function() return U.value_of(object.Parent) end)
        parent = ok and parent or nil
        local parent_path = parent and path_of(parent)
        mats[path] = {parent = parent_path, vectors = vectors, scalars = scalars}
        path, object = parent_path, parent
    end
end

local said = {}
local function say(env, line)
    if said[line] then return end
    said[line] = true
    pcall(env.log, line)
end

function Stock.read(env)
    local tables = {}
    for i, path in ipairs(Stock.TABLES) do
        local ok, dt = pcall(env.find, path)
        if not ok or dt == nil then return nil, 'stock: ' .. path .. ' not found' end
        tables[i] = dt
    end
    local rows = {items = {}, equipment = {}, materials = {}, names = {}, mats = {}}
    local readers = {
        function(n, row)
            local c = U.value_of(row.Category)
            c = type(c) == 'number' and (CATEGORIES[c] or 'ESBItemCategory_' .. c) or str(c)
            if c and (c:find('Hair$') or c:find('EarRing$') or c:find('FaceAccessory$')) then
                rows.items[n] = copy(row, ITEM_FIELDS, {Category = c, Name = n})
                local ok, words = pcall(env.text, U.value_of(row.Name))
                -- The live FText gave back its own ItemStringTable key in game (Item_Hair_003_Name on the tiles, 27
                -- Nov 2026): such words are looked up as a key, the key kept when the table has no entry.
                if ok and type(words) == 'string' and words:match('^Item_[%w_]+_Name$') then
                    local found, named = pcall(env.text, words)
                    if found and named then words = named end
                end
                rows.names[n] = ok and words or nil
            end
        end,
        function(n, row)
            local eq = copy(row, EQUIPMENT_FIELDS, {Type = U.value_of(row.Type),
                bUseHidePonytail = U.value_of(row.bUseHidePonytail) == true})
            local r = U.value_of(row.RelativeRotation)
            if r ~= nil then eq.RelativeRotation = {Pitch = num(r.Pitch), Yaw = num(r.Yaw), Roll = num(r.Roll)} end
            rows.equipment[n] = eq
        end,
        function(n, row)
            local m = copy(row, MATERIAL_FIELDS,
                {VariationIndex = num(row.VariationIndex), MaterialIndex = num(row.MaterialIndex)})
            -- Stock.items groups by these three: a row without one is left out.
            if m.Group and m.VariationIndex and m.MaterialIndex then
                rows.materials[#rows.materials + 1] = m
            else
                say(env, 'stock: EquipmentMaterialTable row ' .. n ..
                    ' skipped: no Group, VariationIndex or MaterialIndex')
            end
        end,
    }
    for i, dt in ipairs(tables) do
        local ok, n = pcall(each_row, dt, readers[i])
        if not ok then return nil, 'stock: ' .. Stock.TABLES[i] .. ': ' .. tostring(n) end
        if n == 0 then return nil, 'stock: ' .. Stock.TABLES[i] .. ' has no rows' end
    end
    -- Only the hair and ponytail groups' materials load: those of a hair row's equipment and the stock ponytails.
    local groups = {}
    local function want(alias)
        local eq = alias and rows.equipment[alias]
        if eq and eq.MaterialGroup then groups[eq.MaterialGroup] = true end
    end
    for _, it in pairs(rows.items) do want(it.EquipmentAlias) want(it.EquipmentAlias2) end
    for _, p in ipairs(PONYTAILS) do want(p.alias) end
    local with_material = {}
    for _, m in ipairs(rows.materials) do
        local path = groups[m.Group] and plain(m.MaterialAssetPath)
        if path then with_material[m.Group] = true end
        if path and not rows.mats[path] then
            local ok, object = pcall(env.load, path)
            if ok and object ~= nil then
                add_chain(rows.mats, path, object)
            else
                say(env, 'stock: ' .. path .. ' did not load')
            end
        end
    end
    -- A hair whose group has no material (a one-colour hair: Nier, Nikke) keeps its mesh's: those load for its
    -- controls. USkeletalMesh.Materials, each FSkeletalMaterial's MaterialInterface, as closet/dress.lua's
    -- own_materials reads them.
    -- Earrings and glasses have no group either: their meshes' materials load the same way, and EVE's face mesh
    -- (Stock.FACE_MESH) for the eyes.
    rows.mesh_mats = {}
    local function load_mesh(mesh)
        if rows.mesh_mats[mesh] then return end
        local ok, object = pcall(env.load, mesh)
        local slots = {}
        if ok and object ~= nil then
            pcall(U.each, object.Materials, function(index, slot)
                local m = U.value_of(U.value_of(slot).MaterialInterface)
                local path = m and path_of(m)
                if path then
                    slots[index] = path
                    if not rows.mats[path] then add_chain(rows.mats, path, m) end
                end
            end)
        else
            say(env, 'stock: ' .. mesh .. ' did not load')
        end
        rows.mesh_mats[mesh] = slots
    end
    for _, it in pairs(rows.items) do
        local eq = rows.equipment[it.EquipmentAlias or '']
        local mesh = eq and plain(eq.MountingResourcePath)
        if mesh and not with_material[eq.MaterialGroup or ''] then load_mesh(mesh) end
    end
    load_mesh(Stock.FACE_MESH)
    return rows
end

-- The game's env, on the game thread: a table only while in memory, a material loaded when it is not, an FText's
-- words, an ItemStringTable key in the player's language through core/unreal.lua's game_text (KismetStringTableLibrary
-- IsRegisteredTableEntry, then KismetTextLibrary TextFromStringTable, its name string 0x1465b6d28).
local ITEM_STRINGS = '/Game/Local/Localize/ItemStringTable.ItemStringTable'
function Stock.env(log)
    local function find(path) return U.valid(StaticFindObject(path)) end
    return {find = find, log = log,
        load = function(path)
            local o = find(path)
            if o then return o end
            pcall(LoadAsset, path)
            return find(path)
        end,
        text = function(v)
            if type(v) == 'string' then return U.game_text(v, ITEM_STRINGS) end
            return U.text(v)
        end}
end

-- The two cut hairs with the stock hairs' controls: their materials (and parents) loaded, then hair_controls.
local function cut_items(env)
    local items = Cut.items(env)
    local mats = {}
    for _, it in pairs(items) do
        local v = it.Variants and it.Variants[1]
        if v then
            local slots = {}
            for i, path in pairs(v.Materials or {}) do
                path = plain(path)
                if path then
                    slots[i] = path
                    if not mats[path] then
                        local ok, object = pcall(env.load, path)
                        if ok and object ~= nil then add_chain(mats, path, object) end
                    end
                end
            end
            local configs = hair_controls(slots, mats, function(line) say(env, 'stock: ' .. line) end)
            v.UserConfigs, it.UserConfigs = configs, configs
        end
    end
    return items
end

function Stock.build(env)
    local rows, why = Stock.read(env)
    local ok, items, missing = false, nil, nil
    if rows then
        ok, items, missing = pcall(Stock.items, rows)
        if not ok then why = 'stock: ' .. tostring(items) end
    end
    -- A failed read leaves the stock rows out; the two cut hairs stay (the spec's one exception).
    if not ok then say(env, why) return cut_items(env), why end
    for _, line in ipairs(missing) do say(env, 'stock: ' .. line) end
    for id, it in pairs(cut_items(env)) do items[id] = it end
    return items
end

return Stock
