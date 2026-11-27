-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The stock head catalogue (closet/head/stock.lua): hair and ponytail rows of the game's tables as pack-shaped items.
local run = dofile('tests/lua/closet/run.lua')
local Stock = require('closet.head.stock')
local Cut = require('closet.head.cut')

local MASTER = Stock.HAIR_MASTER
local KINDS = {'ShapeKeys', 'MaterialToggles', 'ScalarControls', 'VectorControls', 'TextureOptions'}

local function mat(r, g, b, extra)
    local v = {RootColor = {R = r, G = g, B = b, A = 1}, TipColor = {R = b, G = g, B = r, A = 1}}
    for k, x in pairs(extra or {}) do v[k] = x end
    return {parent = MASTER, vectors = v}
end

-- Hair_001: 4 variations on M0 (the hair); Hair_Default's ponytail group has 4 on M0 too.
local function rows()
    local r = {
        items = {
            Hair_001 = {Category = 'ESBItemCategory::ESBItemCategory_Hair', Name = 'Item_Hair_001_Name',
                Asset2D = "Texture2D'/Game/UI/Hair_001.Hair_001'", EquipmentAlias = 'Hair_001_Part1',
                EquipmentAlias2 = 'Hair_001_Part2'},
            Earring_001 = {Category = 'ESBItemCategory::ESBItemCategory_EarRing', Name = 'x',
                EquipmentAlias = 'Earring_001', EquipmentAlias2 = 'None'},
        },
        equipment = {
            Hair_001_Part1 = {Type = 'EquipmentType_Hair1', MountingResourcePath = '/Game/A/H07.H07',
                AnimAssetPath = '/Game/A/H07_AnimBP.H07_AnimBP_C', MaterialGroup = 'EM_Hair_001_Part1',
                RelativeRotation = {Pitch = -90, Yaw = 0, Roll = -90}, bUseHidePonytail = false},
            Hair_Default_Part2 = {Type = 'EquipmentType_Ponytail', MountingResourcePath = '/Game/A/Pony.Pony',
                AnimAssetPath = 'None', MaterialGroup = 'EM_Hair_Default_Part2'},
            Hair_Default_Part2_Short = {Type = 'EquipmentType_Ponytail',
                MountingResourcePath = "SkeletalMesh'/Game/A/PonyShort.PonyShort'", AnimAssetPath = 'None',
                MaterialGroup = 'EM_Hair_Default_Part2'},
        },
        materials = {}, names = {Item_Hair_001_Name = 'Hair 1'}, mats = {},
    }
    for v = 0, 3 do
        local p = '/Game/A/MI_H07_V' .. v
        r.materials[#r.materials + 1] = {Group = 'EM_Hair_001_Part1', VariationIndex = v, MaterialIndex = 0,
            MaterialAssetPath = p, IconColorAssetPath = '/Game/I/V' .. v}
        r.mats[p] = mat(v, 0.5, 0.25)
        local t = '/Game/A/MI_Tail_V' .. v
        r.materials[#r.materials + 1] = {Group = 'EM_Hair_Default_Part2', VariationIndex = v, MaterialIndex = 0,
            MaterialAssetPath = t}
        r.mats[t] = mat(v, 0.1, 0.2)
    end
    return r
end

-- The live side as UE4SS gives it: DataTables walked by ForEachRow (row names) and read by FindRow, FNames and
-- FStrings with ToString, an FText the text reader turns into words, the Category enum as a number, material objects
-- with Parent and VectorParameterValues.
local function name(s) return {ToString = function() return s end} end
local function table_of(rows)
    local dt = {}
    function dt:ForEachRow(fn) for _, k in ipairs(rows.order) do fn(name(k), rows[k]) end end
    function dt:FindRow(k) return rows[k] end
    return dt
end
local function object(path, parent, vectors)
    local o = {Parent = parent, VectorParameterValues = vectors or {}}
    function o:GetFullName() return name('MaterialInstanceConstant ' .. path) end
    return o
end
local function live()
    local master = {GetFullName = function() return name('Material ' .. MASTER .. '.MA_CH_Hair') end}
    local mid = object('/Game/A/Mid.Mid', master,
        {{ParameterInfo = {Name = name('TipColor')}, ParameterValue = {R = 0.5, G = 0.6, B = 0.7, A = 1}}})
    local mi = object('/Game/A/MI.MI', mid,
        {{ParameterInfo = {Name = name('RootColor')}, ParameterValue = {R = 0.1, G = 0.2, B = 0.3, A = 1}}})
    mi.ScalarParameterValues = {{ParameterInfo = {Name = name('Scatter')}, ParameterValue = 0.25}}
    local log = {}
    local env = {log = function(m) log[#log + 1] = m end, loaded = {},
        text = function(v) if type(v) == 'string' then return v == 'Item_Hair_024_Name' and 'Nyaaa' or nil end
            return 'said ' .. v:ToString() end}
    env.tables = {
        [Stock.TABLES[1]] = table_of({order = {'Hair_001', 'Earring_001'},
            Hair_001 = {Category = 21, Name = name('Item_Hair_001_Name'),
                Asset2D = name("Texture2D'/Game/UI/Hair_001.Hair_001'"), EquipmentAlias = name('Hair_001_Part1'),
                EquipmentAlias2 = name('Hair_001_Part2')},
            Earring_001 = {Category = 23, Name = name('E'), EquipmentAlias = name('Earring_001')}}),
        [Stock.TABLES[2]] = table_of({order = {'Hair_001_Part1'},
            Hair_001_Part1 = {Type = 5, MountingResourcePath = name("SkeletalMesh'/Game/A/H07.H07'"),
                AnimAssetPath = name('/Game/A/H07_AnimBP.H07_AnimBP_C'), MaterialGroup = name('EM_Hair_001_Part1'),
                RelativeRotation = {Pitch = -90, Yaw = 0, Roll = -90}, bUseHidePonytail = false}}),
        [Stock.TABLES[3]] = table_of({order = {'EM_Hair_001_Part1_V0_M0'},
            EM_Hair_001_Part1_V0_M0 = {Group = name('EM_Hair_001_Part1'), VariationIndex = 0, MaterialIndex = 0,
                MaterialAssetPath = name("MaterialInstanceConstant'/Game/A/MI.MI'"),
                IconColorAssetPath = name("Texture2D'/Game/I/V0.V0'")}}),
    }
    env.find = function(path) return env.tables[path] end
    env.load = function(path) env.loaded[#env.loaded + 1] = path; return path == '/Game/A/MI.MI' and mi or nil end
    return env, log
end

local tests = {
    a_row_text_that_is_its_key_is_looked_up = function()
        -- In game the live row's FText gave back its ItemStringTable key (Item_Hair_003_Name on the tiles, Schizo's
        -- screenshot of 27 Nov 2026): such words are looked up as a key; a key the table lacks keeps the key.
        local env = live()
        env.text = function(v)
            if type(v) == 'string' then return v == 'Item_Hair_001_Name' and 'Sharp Bob' or nil end
            return v:ToString()
        end
        local r = assert(Stock.read(env))
        same(r.names, {Hair_001 = 'Sharp Bob'}, 'the key looked up')
        env.text = function(v) if type(v) == 'string' then return nil end return v:ToString() end
        r = assert(Stock.read(env))
        same(r.names, {Hair_001 = 'Item_Hair_001_Name'}, 'no entry: the key stays')
    end,
    the_reader_loads_a_one_colour_hairs_mesh_materials = function()
        local env = live()
        local mi_y = object('/Game/Y/MI_Y.MI_Y', nil,
            {{ParameterInfo = {Name = name('RootColor')}, ParameterValue = {R = 0.9, G = 0.9, B = 0.9, A = 1}}})
        mi_y.ScalarParameterValues = {{ParameterInfo = {Name = name('Roughness')}, ParameterValue = 0.4}}
        local mesh_y = {Materials = {{MaterialInterface = mi_y}}}
        env.tables[Stock.TABLES[1]] = table_of({order = {'Hair_Nier_001'},
            Hair_Nier_001 = {Category = 21, Name = name('Item_Hair_Nier_001_Name'),
                EquipmentAlias = name('Hair_Nier_001_Part1'), EquipmentAlias2 = name('None')}})
        env.tables[Stock.TABLES[2]] = table_of({order = {'Hair_Nier_001_Part1'},
            Hair_Nier_001_Part1 = {Type = 5, MountingResourcePath = name("SkeletalMesh'/Game/Y/Y.Y'"),
                AnimAssetPath = name('None'), MaterialGroup = name('EM_Hair_Nier_001_Part1')}})
        env.tables[Stock.TABLES[3]] = table_of({order = {'EM_Nier_V0'},
            EM_Nier_V0 = {Group = name('EM_Hair_Nier_001_Part1'), VariationIndex = 0, MaterialIndex = 0,
                MaterialAssetPath = name('')}})
        env.load = function(path) env.loaded[#env.loaded + 1] = path; return path == '/Game/Y/Y.Y' and mesh_y or nil end
        local r = assert(Stock.read(env))
        same(env.loaded, {'/Game/Y/Y.Y'}, 'the one-colour hair\'s mesh loaded')
        same(r.mesh_mats['/Game/Y/Y.Y'], {[1] = '/Game/Y/MI_Y.MI_Y'}, 'its material slots')
        eq(r.mats['/Game/Y/MI_Y.MI_Y'].scalars.Roughness, 0.4, 'its numbers read')
        local it = Stock.items(r)['SB.Hair_Nier_001']
        eq(it.UserConfigs.ScalarControls[1].ParamName, 'Roughness', 'a roughness control')
    end,

    the_cut_hairs_get_controls_too = function()
        -- Nyaaa and Mecha Rabbit had no controls; like every stock hair they get those their materials set.
        local env = live()
        local cut = require('closet.head.cut')
        local items = cut.items(env)
        local hair_mat = items['SB.Hair_024'].Variants[1].Materials[1]
        local path = hair_mat:match("^%w+'(.*)'$") or hair_mat
        local master = {GetFullName = function() return name('Material ' .. MASTER .. '.MA_CH_Hair') end}
        local mi = object(path, master,
            {{ParameterInfo = {Name = name('RootColor')}, ParameterValue = {R = 0.2, G = 0.2, B = 0.2, A = 1}},
             {ParameterInfo = {Name = name('TipColor')}, ParameterValue = {R = 0.3, G = 0.3, B = 0.3, A = 1}}})
        mi.ScalarParameterValues = {{ParameterInfo = {Name = name('Scatter')}, ParameterValue = 0.1}}
        local load = env.load
        env.load = function(p) if p == path then return mi end return load(p) end
        local built = Stock.build(env)
        local c = built['SB.Hair_024'].UserConfigs
        eq(c.VectorControls[1] and c.VectorControls[1].ParamName, 'RootColor', 'a root colour control')
        eq(c.ScalarControls[1] and c.ScalarControls[1].ParamName, 'Scatter', 'a scatter control')
        eq(built['SB.Hair_024'].Variants[1].UserConfigs, c, 'on its variant too')
    end,

    the_reader_turns_fake_tables_into_rows = function()
        local env = live()
        local r = assert(Stock.read(env))
        same(r.items, {Hair_001 = {Category = 'ESBItemCategory_Hair', Name = 'Hair_001',
            Asset2D = "Texture2D'/Game/UI/Hair_001.Hair_001'", EquipmentAlias = 'Hair_001_Part1',
            EquipmentAlias2 = 'Hair_001_Part2'}}, 'hair rows only, the enum named')
        same(r.names, {Hair_001 = 'said Item_Hair_001_Name'}, 'name through the text reader')
        same(r.equipment.Hair_001_Part1, {Type = 5, MountingResourcePath = "SkeletalMesh'/Game/A/H07.H07'",
            AnimAssetPath = '/Game/A/H07_AnimBP.H07_AnimBP_C', MaterialGroup = 'EM_Hair_001_Part1',
            RelativeRotation = {Pitch = -90, Yaw = 0, Roll = -90}, bUseHidePonytail = false}, 'equipment row')
        same(r.materials, {{Group = 'EM_Hair_001_Part1', VariationIndex = 0, MaterialIndex = 0,
            MaterialAssetPath = "MaterialInstanceConstant'/Game/A/MI.MI'",
            IconColorAssetPath = "Texture2D'/Game/I/V0.V0'"}}, 'material row')
        same(env.loaded, {'/Game/A/MI.MI'}, 'the hair group material loaded by its plain path')
        same(r.mats['/Game/A/MI.MI'], {parent = '/Game/A/Mid.Mid',
            vectors = {RootColor = {R = 0.1, G = 0.2, B = 0.3, A = 1}}, scalars = {Scatter = 0.25}}, 'the instance')
        same(r.mats['/Game/A/Mid.Mid'], {parent = MASTER .. '.MA_CH_Hair',
            vectors = {TipColor = {R = 0.5, G = 0.6, B = 0.7, A = 1}}, scalars = {}}, 'its parent')
        same(r.mats[MASTER .. '.MA_CH_Hair'], {vectors = {}, scalars = {}}, 'the master ends the chain')
        local c = Stock.items(r)['SB.Hair_001'].UserConfigs.VectorControls
        eq(#c, 2, 'root and tip through the chain')
        same(c[2].Value, {0.5, 0.6, 0.7, 1}, 'tip from the parent')
    end,

    a_missing_table_is_said_and_gives_nothing = function()
        local env, log = live()
        env.tables[Stock.TABLES[2]] = nil
        local rows, why = Stock.read(env)
        eq(rows, nil, 'no rows')
        eq(why, 'stock: /Game/Local/Data/EquipmentTable.EquipmentTable not found', 'why')
        local items, why2 = Stock.build(env)
        eq(why2, why, 'the build says why')
        local ids = {}
        for id in pairs(items) do ids[#ids + 1] = id end
        table.sort(ids)
        same(ids, {'SB.Hair_024', 'SB.Hair_025'}, 'only the cut hairs stay')
        Stock.build(env)
        eq(#log, 1, 'said once') eq(log[1], why, 'the why')
    end,

    a_material_row_with_a_missing_index_is_skipped = function()
        local env, log = live()
        local mt = env.tables[Stock.TABLES[3]]
        local good = mt:FindRow('EM_Hair_001_Part1_V0_M0')
        env.tables[Stock.TABLES[3]] = table_of({order = {'Bad', 'EM_Hair_001_Part1_V0_M0'},
            Bad = {Group = name('EM_Hair_001_Part1'), MaterialIndex = 1,
                MaterialAssetPath = name("MaterialInstanceConstant'/Game/A/Bad.Bad'")},
            EM_Hair_001_Part1_V0_M0 = good})
        local r = assert(Stock.read(env))
        eq(#r.materials, 1, 'the bad row left out')
        same(log, {'stock: EquipmentMaterialTable row Bad skipped: no Group, VariationIndex or MaterialIndex'}, 'said')
        ok(Stock.items(r)['SB.Hair_001'], 'the hair stays, no raise')
    end,

    a_raising_catalogue_is_a_failed_read = function()
        local env = live()
        local items_was = Stock.items
        Stock.items = function() error('bad row', 0) end
        local items, why = Stock.build(env)
        Stock.items = items_was
        eq(why, 'stock: bad row', 'why')
        ok(items['SB.Hair_024'] and items['SB.Hair_025'] and not items['SB.Hair_001'], 'the cut hairs only')
    end,

    a_throwing_table_is_a_why = function()
        local env = live()
        env.tables[Stock.TABLES[3]].ForEachRow = function() error('boom', 0) end
        local rows, why = Stock.read(env)
        eq(rows, nil, 'no rows')
        eq(why, 'stock: /Game/Local/Data/EquipmentMaterialTable.EquipmentMaterialTable: boom', 'why')
        env.tables[Stock.TABLES[3]] = table_of({order = {}})
        rows, why = Stock.read(env)
        eq(why, 'stock: /Game/Local/Data/EquipmentMaterialTable.EquipmentMaterialTable has no rows', 'empty')
    end,

    the_cut_hairs_are_items = function()
        local items = Cut.items(live())
        local a, b = items['SB.Hair_024'], items['SB.Hair_025']
        for _, it in ipairs({a, b}) do
            eq(it.Slot, 'Hair', 'slot') eq(it.Origin, 'original', 'origin') eq(#it.Variants, 1, 'one variant')
            eq(it.Variants[1].Mesh, it.Mesh, 'variant mesh')
        end
        eq(a.DisplayName, 'Nyaaa', 'name from ItemStringTable') eq(b.DisplayName, 'Hair_025', 'row when unnamed')
        local HR = '/Game/Art/Character/PC/00_HR/'
        eq(a.Mesh, HR .. 'EVE_HR_14/EVE_HR_14.EVE_HR_14', 'mesh 24')
        eq(a.AnimationBP, HR .. 'EVE_HR_14/EVE_HR_14_AnimBP.EVE_HR_14_AnimBP_C', 'anim class 24')
        eq(a.PhysicsAsset, HR .. 'EVE_HR_14/EVE_HR_14_Physics.EVE_HR_14_Physics', 'physics 24')
        same(a.Variants[1].Materials, {HR .. 'EVE_HR_14/Materials/MI_EVE_HR_14_TypeA.MI_EVE_HR_14_TypeA',
            HR .. 'EVE_HR_11/Materials/MI_EVE_HR_11_Hairpin.MI_EVE_HR_11_Hairpin',
            HR .. 'EVE_HR_14/Materials/MI_EVE_HR_14_Emissive.MI_EVE_HR_14_Emissive',
            HR .. 'EVE_HR_14/Materials/MI_EVE_HR_14_Band.MI_EVE_HR_14_Band'}, 'materials 24')
        eq(b.Mesh, HR .. 'EVE_HR_15/EVE_HR_15.EVE_HR_15', 'mesh 25')
        eq(b.AnimationBP, HR .. 'EVE_HR_15/EVE_HR_15_AnimBP.EVE_HR_15_AnimBP_C', 'anim class 25')
        eq(b.PhysicsAsset, HR .. 'EVE_HR_15/EVE_HR_15_Physics.EVE_HR_15_Physics', 'physics 25')
        same(b.Variants[1].Materials, {HR .. 'EVE_HR_06/Material/MI_EVE_HR_06_TypeA.MI_EVE_HR_06_TypeA',
            HR .. 'EVE_HR_15/Materials/MI_EVE_HR_15.MI_EVE_HR_15',
            HR .. 'EVE_HR_15/Materials/MI_EVE_HR_15_Emissive.MI_EVE_HR_15_Emissive'}, 'materials 25')
    end,

    the_build_is_the_stock_items_and_the_cut_hairs = function()
        local env, log = live()
        local items = assert(Stock.build(env))
        ok(items['SB.Hair_001'] and items['SB.Ponytail_None'] and items['SB.Hair_024'] and items['SB.Hair_025'],
            'stock and cut')
        same(log, {'stock: Ponytail_Long: no equipment row Hair_Default_Part2',
            'stock: Ponytail_Short: no equipment row Hair_Default_Part2_Short'}, 'rows left out are said')
        Stock.build(env)
        eq(#log, 2, 'said once')
    end,

    a_stock_hair_becomes_a_hair_item = function()
        local items = Stock.items(rows())
        local it = items['SB.Hair_001']
        eq(it.Slot, 'Hair', 'slot')
        eq(it.Origin, 'original', 'origin')
        eq(it.UniqueFitID, 'SB.Hair_001', 'id')
        eq(it.DisplayName, 'Hair 1', 'name from names')
        eq(it.Image, '/Game/UI/Hair_001.Hair_001', 'table path cut to the asset path')
        eq(#it.Variants, 4, 'variants')
        eq(it.Variants[2].Materials[1], '/Game/A/MI_H07_V1', 'variant 2 material')
        eq(it.Variants[2].Mesh, '/Game/A/H07.H07', 'variant mesh')
        eq(it.Mesh, '/Game/A/H07.H07', 'item mesh')
        eq(it.AnimationBP, '/Game/A/H07_AnimBP.H07_AnimBP_C', 'anim class')
        same(it.Rotation, {Pitch = -90, Yaw = 0, Roll = -90}, 'rotation')
        eq(it.UserConfigs, it.Variants[1].UserConfigs, 'item configs are the first variant\'s')
        ok(items['SB.Earring_001'] == nil, 'an earring is not hair')
        for _, v in ipairs(it.Variants) do
            for _, k in ipairs(KINDS) do ok(type(v.UserConfigs[k]) == 'table', k .. ' list') end
        end
    end,

    colour_controls_only_for_hair_materials = function()
        local r = rows()
        r.materials = {
            {Group = 'EM_Hair_001_Part1', VariationIndex = 0, MaterialIndex = 0, MaterialAssetPath = '/Game/A/Pin'},
            {Group = 'EM_Hair_001_Part1', VariationIndex = 0, MaterialIndex = 1, MaterialAssetPath = '/Game/A/Hair'},
            {Group = 'EM_Hair_001_Part1', VariationIndex = 1, MaterialIndex = 0, MaterialAssetPath = '/Game/A/Pin'},
            {Group = 'EM_Hair_001_Part1', VariationIndex = 1, MaterialIndex = 1, MaterialAssetPath = '/Game/A/Dyed'},
        }
        r.mats = {['/Game/A/Pin'] = {parent = '/Game/Other/MA_Pin',
                vectors = {RootColor = {R = 9, G = 9, B = 9, A = 1}}},
            ['/Game/A/Hair'] = mat(0.1, 0.2, 0.3),
            ['/Game/A/Dyed'] = mat(0.4, 0.5, 0.6, {DyeColor = {R = 0.7, G = 0.8, B = 0.9, A = 1}})}
        local v = Stock.items(r)['SB.Hair_001'].Variants
        local c = v[1].UserConfigs.VectorControls
        eq(#c, 2, 'root and tip on the hair material only')
        eq(c[1].ParamName, 'RootColor', 'first')
        eq(c[2].ParamName, 'TipColor', 'second')
        eq(c[1].MaterialIndex, 1, 'the hair slot, not the pin')
        eq(c[2].MaterialIndex, 1, 'the hair slot, not the pin')
        same(c[1].Value, {0.1, 0.2, 0.3, 1}, 'root value')
        same(c[2].Value, {0.3, 0.2, 0.1, 1}, 'tip value')
        local d = v[2].UserConfigs.VectorControls
        eq(#d, 3, 'dye added where the instance sets it')
        eq(d[3].ParamName, 'DyeColor', 'dye')
        same(d[3].Value, {0.7, 0.8, 0.9, 1}, 'dye value')
        same(d[1].Value, {0.4, 0.5, 0.6, 1}, 'values follow the variant')
    end,

    a_one_colour_hair_keeps_its_mesh_materials = function()
        local r = rows()
        r.items.Hair_Nikke_01 = {Category = 'ESBItemCategory_Hair', Name = 'N', EquipmentAlias = 'Hair_Nikke_01_Part1',
            EquipmentAlias2 = 'None'}
        r.equipment.Hair_Nikke_01_Part1 = {MountingResourcePath = '/Game/N/N.N',
            MaterialGroup = 'EM_Hair_Nikke_01_Part1'}
        r.materials[#r.materials + 1] = {Group = 'EM_Hair_Nikke_01_Part1', VariationIndex = 0, MaterialIndex = 0,
            MaterialAssetPath = '', IconColorAssetPath = '/Game/I/N'}
        local it = Stock.items(r)['SB.Hair_Nikke_01']
        eq(#it.Variants, 1, 'one variant')
        same(it.Variants[1].Materials, {}, 'no material override')
        same(it.UserConfigs.VectorControls, {}, 'no controls while its mesh materials are not known')
    end,

    a_one_colour_hair_gets_controls_from_its_mesh = function()
        -- YoRHa (Nier) and Nikke hairs have one salon row with no material (Schizo, 27 Nov 2026: "they should all
        -- have adjustable color/scatter/gloss"): their controls come from the mesh's own materials; the mesh keeps
        -- them (no override).
        local r = rows()
        r.items.Hair_Nier_001 = {Category = 'ESBItemCategory_Hair', Name = 'Y', EquipmentAlias = 'Hair_Nier_001_Part1',
            EquipmentAlias2 = 'None'}
        r.equipment.Hair_Nier_001_Part1 = {MountingResourcePath = '/Game/Y/Y.Y',
            MaterialGroup = 'EM_Hair_Nier_001_Part1'}
        r.materials[#r.materials + 1] = {Group = 'EM_Hair_Nier_001_Part1', VariationIndex = 0, MaterialIndex = 0,
            MaterialAssetPath = ''}
        r.mesh_mats = {['/Game/Y/Y.Y'] = {[1] = '/Game/Y/MI_Y'}}
        r.mats['/Game/Y/MI_Y'] = mat(0.4, 0.3, 0.2)
        r.mats['/Game/Y/MI_Y'].scalars = {Scatter = 0.2, Roughness = 0.5}
        local it = Stock.items(r)['SB.Hair_Nier_001']
        same(it.Variants[1].Materials, {}, 'the mesh keeps its materials')
        local names = {}
        for _, c in ipairs(it.UserConfigs.VectorControls) do names[#names + 1] = c.ParamName end
        same(names, {'RootColor', 'TipColor'}, 'root and tip from the mesh material')
        local s = it.UserConfigs.ScalarControls
        eq(#s, 2, 'scatter and roughness')
        eq(s[1].ParamName, 'Roughness') eq(s[1].Value, 0.5) eq(s[1].MaterialIndex, 0)
        eq(s[2].ParamName, 'Scatter') eq(s[2].Value, 0.2)
        ok(s[2].Min <= 0 and s[2].Max >= 1, 'a range around its value')
    end,

    every_parameter_the_instance_sets_is_a_control = function()
        -- Every colour and number a hair's material instance sets (not its master's own) is a control: scatter,
        -- brightness and the like, not only root and tip. Layout vectors (ClipMask...) are left out.
        local r = rows()
        local m = mat(0.1, 0.2, 0.3, {DyeColor = {R = 0.7, G = 0.8, B = 0.9, A = 1},
            ClipMaskPlane = {R = 1, G = 0, B = 0, A = 0}})
        m.scalars = {Brightness = 0.381, Scatter = 0.076, RandomHueVariation = -1.345}
        r.mats['/Game/A/MI_H07_V0'] = m
        local c = Stock.items(r)['SB.Hair_001'].Variants[1].UserConfigs
        local vec = {}
        for _, x in ipairs(c.VectorControls) do vec[#vec + 1] = x.ParamName end
        same(vec, {'RootColor', 'TipColor', 'DyeColor'}, 'colours: root, tip, then dye; no layout vector')
        local sc = {}
        for _, x in ipairs(c.ScalarControls) do sc[#sc + 1] = x.ParamName end
        same(sc, {'Brightness', 'RandomHueVariation', 'Scatter'}, 'every number it sets, by name')
        for _, x in ipairs(c.ScalarControls) do
            ok(x.Min <= x.Value and x.Value <= x.Max, x.ParamName .. ' within its range')
        end
    end,

    stock_ponytails_have_their_own_glyphs = function()
        local items = Stock.items(rows())
        eq(items['SB.Ponytail_Long'].Glyph, 'ponytail_long') eq(items['SB.Ponytail_Short'].Glyph, 'ponytail_short')
        eq(items['SB.Ponytail_None'].Glyph, 'ponytail_none')
    end,

    stock_ponytails_follow_their_hair = function()
        local items = Stock.items(rows())
        eq(items['SB.Hair_001'].Ponytail, 'SB.Ponytail_Long', 'the hair brings the long ponytail')
        eq(items['SB.Hair_001'].HidePonytail, false, 'not hidden')
        local long, short = items['SB.Ponytail_Long'], items['SB.Ponytail_Short']
        eq(long.Slot, 'Ponytail', 'slot')
        eq(long.Mesh, '/Game/A/Pony.Pony', 'long mesh')
        eq(short.Mesh, '/Game/A/PonyShort.PonyShort', 'short mesh, class wrapper cut')
        eq(#long.Variants, 4, 'long variants')
        eq(#short.Variants, 4, 'short variants')
        eq(long.Variants[3].Materials[1], '/Game/A/MI_Tail_V2', 'group of the default ponytail')
        eq(items['SB.Ponytail_None'].Variants[1].Mesh, '', 'none has no mesh')
        eq(items['SB.Ponytail_None'].Slot, 'Ponytail', 'none slot')
    end,

    a_hair_with_no_ponytail_hides_it = function()
        local r = rows()
        r.items.Hair_002 = {Category = 'ESBItemCategory_Hair', Name = 'B', EquipmentAlias = 'Hair_002_Part1',
            EquipmentAlias2 = 'None'}
        r.items.Hair_003 = {Category = 'ESBItemCategory_Hair', Name = 'C', EquipmentAlias = 'Hair_003_Part1',
            EquipmentAlias2 = 'Hair_003_Part2'}
        r.equipment.Hair_002_Part1 = {MountingResourcePath = '/Game/B/B.B', MaterialGroup = 'G2'}
        r.equipment.Hair_003_Part1 = {MountingResourcePath = '/Game/C/C.C', MaterialGroup = 'G3',
            bUseHidePonytail = true}
        local items = Stock.items(r)
        for _, id in ipairs({'SB.Hair_002', 'SB.Hair_003'}) do
            eq(items[id].HidePonytail, true, id .. ' hides')
            eq(items[id].Ponytail, nil, id .. ' brings none')
        end
    end,

    a_colour_the_instance_leaves_out_comes_from_its_parents = function()
        local r = rows()
        r.materials = {{Group = 'EM_Hair_001_Part1', VariationIndex = 0, MaterialIndex = 0,
            MaterialAssetPath = '/Game/A/Child'}}
        r.mats = {['/Game/A/Child'] = {parent = '/Game/A/Mid', vectors = {RootColor = {R = 1, G = 2, B = 3, A = 1}}},
            ['/Game/A/Mid'] = {parent = MASTER .. '.MA_CH_Hair', vectors = {}},
            [MASTER] = {vectors = {TipColor = {R = 0.5, G = 0.6, B = 0.7, A = 1}}}}
        local items, missing = Stock.items(r)
        local c = items['SB.Hair_001'].UserConfigs.VectorControls
        eq(#c, 2, 'both controls')
        same(c[1].Value, {1, 2, 3, 1}, 'root from the instance')
        same(c[2].Value, {0.5, 0.6, 0.7, 1}, 'tip from the master')
        same(missing, {}, 'nothing lost')
        r.mats[MASTER] = nil
        items, missing = Stock.items(r)
        c = items['SB.Hair_001'].UserConfigs.VectorControls
        eq(#c, 1, 'no tip without a value')
        eq(c[1].ParamName, 'RootColor', 'root stays')
        same(missing, {'Hair_001: no TipColor on /Game/A/Child or its parents'}, 'said once')
    end,

    a_hair_row_with_no_alias_is_reported = function()
        local r = rows()
        r.items.Hair_009 = {Category = 'ESBItemCategory_Hair', Name = 'Z', EquipmentAlias = 'None'}
        local items, missing = Stock.items(r)
        eq(items['SB.Hair_009'], nil, 'left out')
        same(missing, {'Hair_009: no equipment alias'}, 'said')
    end,

    rows_with_missing_parts_are_left_out = function()
        local r = rows()
        r.items.Hair_Nikke_02 = {Category = 'ESBItemCategory_Hair', Name = 'N2', EquipmentAlias = 'Hair_Nikke_02_Part1',
            EquipmentAlias2 = 'None'}
        local items, missing = Stock.items(r)
        eq(items['SB.Hair_Nikke_02'], nil, 'left out')
        same(missing, {'Hair_Nikke_02: no equipment row Hair_Nikke_02_Part1'}, 'said')
        ok(items['SB.Hair_001'] ~= nil, 'the rest stays')
    end,
}

run('stock_test', tests)
