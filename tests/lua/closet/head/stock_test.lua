-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The stock head catalogue (closet/head/stock.lua): hair and ponytail rows of the game's tables as pack-shaped items.
local run = dofile('tests/lua/closet/run.lua')
local Stock = require('closet.head.stock')

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

local tests = {
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
        same(it.UserConfigs.VectorControls, {}, 'no colour controls')
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
