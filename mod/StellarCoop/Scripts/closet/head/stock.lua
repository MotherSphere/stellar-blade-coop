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

-- lost(why) is called for a colour no material of the chain has: its control is left out.
local function colour_controls(slots, mats, lost)
    local controls = {}
    local last = 0
    for i in pairs(slots) do if i > last then last = i end end
    for i = 1, last do
        local mat = slots[i] and mats[slots[i]]
        if mat and under_hair_master(mats, slots[i]) then
            for _, c in ipairs(COLOURS) do
                local name = c[1]
                -- Dye is only a control where the instance itself sets it.
                local v = name == 'DyeColor' and mat.vectors and mat.vectors[name] or
                    name ~= 'DyeColor' and vector_of(mats, slots[i], name)
                if v then
                    controls[#controls + 1] = {DisplayName = c[2], ParamName = name, MaterialIndex = i - 1,
                        Value = {v.R, v.G, v.B, v.A or 1}}
                elseif name ~= 'DyeColor' then
                    lost(('no %s on %s or its parents'):format(name, slots[i]))
                end
            end
        end
    end
    return controls
end

local function variants_of(rows, group, mesh, lost)
    local variants = {}
    for _, v in ipairs(group_variations(rows.materials or {}, group)) do
        local configs = lists()
        configs.VectorControls = colour_controls(v.slots, rows.mats or {}, lost)
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

local function item_of(rows, id, slot, name, image, eq, extra, lost)
    local mesh = plain(eq.MountingResourcePath)
    local variants = variants_of(rows, eq.MaterialGroup, mesh, lost)
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
        if is_hair(it) and not alias then
            lost(row, 'no equipment alias')
        elseif alias then
            local eq = equipment[alias]
            if not eq then
                lost(row, 'no equipment row ' .. alias)
            elseif not plain(eq.MountingResourcePath) then
                lost(row, 'no mesh in equipment row ' .. alias)
            else
                local hide = plain(it.EquipmentAlias2) == nil or eq.bUseHidePonytail == true
                local id = 'SB.' .. row
                items[id] = item_of(rows, id, 'Hair', names[it.Name] or row, plain(it.Asset2D), eq,
                    {HidePonytail = hide, Ponytail = (not hide and have_long) and 'SB.Ponytail_Long' or nil},
                    function(why) lost(row, why) end)
            end
        end
    end
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
local HAIR_CATEGORY = 21

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

-- A material and its parents up to the master into mats, keyed by object path: {parent=path, vectors}. Engine
-- facts as closet/ui/probe.lua's test 6 cites them: UMaterialInstance.VectorParameterValues
-- TArray<FVectorParameterValue> (params 0x1465da110), its ParameterInfo.Name an FName; Parent and ParameterValue
-- (FLinearColor) as the MI_EVE_HR_14_TypeA asset dump holds them. A master has neither: pcall gives none.
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
        local ok, parent = pcall(function() return U.value_of(object.Parent) end)
        parent = ok and parent or nil
        local parent_path = parent and path_of(parent)
        mats[path] = {parent = parent_path, vectors = vectors}
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
            c = type(c) == 'number' and (c == HAIR_CATEGORY and 'ESBItemCategory_Hair' or 'ESBItemCategory_' .. c)
                or str(c)
            if c and c:find('Hair$') then
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
    for _, m in ipairs(rows.materials) do
        local path = groups[m.Group] and plain(m.MaterialAssetPath)
        if path and not rows.mats[path] then
            local ok, object = pcall(env.load, path)
            if ok and object ~= nil then
                add_chain(rows.mats, path, object)
            else
                say(env, 'stock: ' .. path .. ' did not load')
            end
        end
    end
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

function Stock.build(env)
    local rows, why = Stock.read(env)
    local ok, items, missing = false, nil, nil
    if rows then
        ok, items, missing = pcall(Stock.items, rows)
        if not ok then why = 'stock: ' .. tostring(items) end
    end
    -- A failed read leaves the stock rows out; the two cut hairs stay (the spec's one exception).
    if not ok then say(env, why) return Cut.items(env), why end
    for _, line in ipairs(missing) do say(env, 'stock: ' .. line) end
    for id, it in pairs(Cut.items(env)) do items[id] = it end
    return items
end

return Stock
