-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The game's own suits (closet/suits.lua): NanoSuit item rows as Full outfit fits under Original.
local run = dofile('tests/lua/closet/run.lua')
local Suits = require('closet.suits')
local Stock = require('closet.head.stock')
local Fits = require('closet.fits')

local NANO = 'ESBItemCategory_NanoSuit'
local function icon(n) return "Texture2D'/Game/Art/UI/Texture/Item/NanoSuit/" .. n .. '.' .. n .. "'" end

-- Rows as Stock.read gives them, shaped like probe 9's (27 Nov 2026): BS_05_E's alias is BS_05, its colour version
-- BS_05_Var2_E's BS_05_Var2; BS_Default has two colour versions; BS_Lone_Var2 has no base row.
local function rows()
    return {
        items = {
            BS_Default = {Category = NANO, Name = 'BS_Default', Asset2D = icon('BS_Default'),
                EquipmentAlias = 'BS_Default', EquipmentAlias2 = 'None'},
            BS_Default_Var3 = {Category = NANO, Name = 'BS_Default_Var3', Asset2D = icon('BS_Default'),
                EquipmentAlias = 'BS_Default_Var3'},
            BS_Default_Var2 = {Category = NANO, Name = 'BS_Default_Var2', Asset2D = icon('BS_Default'),
                EquipmentAlias = 'BS_Default_Var2'},
            BS_05_E = {Category = NANO, Name = 'BS_05_E', Asset2D = icon('BS_05'), EquipmentAlias = 'BS_05'},
            BS_05_Var2_E = {Category = NANO, Name = 'BS_05_Var2_E', EquipmentAlias = 'BS_05_Var2'},
            BS_Lone_Var2 = {Category = NANO, Name = 'BS_Lone_Var2', EquipmentAlias = 'BS_Lone_Var2'},
            BS_Bayo = {Category = NANO, Name = 'BS_Bayo', EquipmentAlias = 'BS_Bayo'},
            BS_Gone = {Category = NANO, Name = 'BS_Gone', EquipmentAlias = 'BS_Gone'},
            BS_Bare = {Category = NANO, Name = 'BS_Bare', EquipmentAlias = 'BS_Bare'},
            Hair_001 = {Category = 'ESBItemCategory_Hair', Name = 'Hair_001', EquipmentAlias = 'Hair_001_Part1'},
        },
        equipment = {
            BS_Default = {Type = 13, MountingResourcePath = '/Game/C/E08/E08.E08', MaterialGroup = 'None'},
            BS_Default_Var2 = {Type = 13, MountingResourcePath = "SkeletalMesh'/Game/C/E08/E08_B.E08_B'"},
            BS_Default_Var3 = {Type = 13, MountingResourcePath = "SkeletalMesh'/Game/C/E08/E08_C.E08_C'"},
            BS_05 = {Type = 13, MountingResourcePath = '/Game/C/E09/V02.V02'},
            BS_05_Var2 = {Type = 13, MountingResourcePath = '/Game/C/E09/V02_B.V02_B'},
            BS_Lone_Var2 = {Type = 13, MountingResourcePath = '/Game/C/L/L.L'},
            BS_Bayo = {Type = 13, MountingResourcePath = '/Game/C/B/B.B', bUseHidePonytail = true},
            BS_Bare = {Type = 13, MountingResourcePath = 'None'},
            Hair_001_Part1 = {Type = 5, MountingResourcePath = '/Game/A/H.H'},
        },
        names = {BS_Default = 'Planet Diving Suit', BS_Default_Var2 = 'Planet Diving Suit (Orange)',
            BS_Default_Var3 = 'Planet Diving Suit (C)', BS_05_E = 'Skin Suit', BS_05_Var2_E = 'Skin Suit (B)'},
    }
end

local function ids(t)
    local out = {}
    for id in pairs(t) do out[#out + 1] = id end
    table.sort(out)
    return out
end

local tests = {
    each_suit_row_is_an_original_full_outfit = function()
        local items, missing = Suits.items(rows())
        same(ids(items), {'SB.BS_05_E', 'SB.BS_Bayo', 'SB.BS_Default', 'SB.BS_Lone_Var2'},
            'suits only; colour versions are no fits of their own; a VarN without its base is one')
        local it = items['SB.BS_Default']
        eq(it.UniqueFitID, 'SB.BS_Default', 'id') eq(it.Slot, 'FullOutfit', 'slot') eq(it.Origin, 'original', 'origin')
        eq(it.DisplayName, 'Planet Diving Suit', 'resolved name')
        eq(it.Image, '/Game/Art/UI/Texture/Item/NanoSuit/BS_Default.BS_Default', 'the game icon, plain')
        eq(it.Mesh, '/Game/C/E08/E08.E08', 'mesh')
        eq(it.HidePonytail, false, 'keeps its ponytail')
        eq(items['SB.BS_Bayo'].HidePonytail, true, 'bUseHidePonytail kept on the item')
        eq(items['SB.BS_Bayo'].DisplayName, 'BS_Bayo', 'no name: the row')
        same(missing, {'BS_Bare: no mesh in equipment row BS_Bare', 'BS_Gone: no equipment row BS_Gone'}, 'said')
    end,

    colour_versions_are_variants_of_their_base = function()
        local items = Suits.items(rows())
        local v = items['SB.BS_Default'].Variants
        eq(#v, 3, 'base, Var2, Var3')
        same({v[1].Mesh, v[2].Mesh, v[3].Mesh}, {'/Game/C/E08/E08.E08', '/Game/C/E08/E08_B.E08_B',
            '/Game/C/E08/E08_C.E08_C'}, 'each its own mesh, in VarN order')
        same({v[1].Name, v[2].Name, v[3].Name}, {'Planet Diving Suit', 'Planet Diving Suit (Orange)',
            'Planet Diving Suit (C)'}, 'each named for the Variant row')
        local s = items['SB.BS_05_E'].Variants
        eq(#s, 2, 'by equipment alias: BS_05_Var2_E is BS_05_E\'s')
        eq(s[2].Mesh, '/Game/C/E09/V02_B.V02_B', 'its mesh')
    end,

    a_suit_variant_swaps_the_mesh_through_fits = function()
        local saved = {Fits.ITEMS, Fits.PACKS, Fits.CHOSEN}
        Fits.CHOSEN = {}
        Fits.use(Suits.items(rows()))
        eq(Fits.origin('SB.BS_Default'), 'original', 'under Original')
        ok(Fits.all()['SB.BS_Default'], 'listed on Full outfit')
        eq(Fits.get('SB.BS_Default').Mesh, '/Game/C/E08/E08.E08', 'first variant worn')
        ok(Fits.choose('SB.BS_Default', 2), 'variant 2 chosen')
        eq(Fits.get('SB.BS_Default').Mesh, '/Game/C/E08/E08_B.E08_B', 'its mesh worn')
        eq(Fits.get('SB.BS_Default').Image, '/Game/Art/UI/Texture/Item/NanoSuit/BS_Default.BS_Default', 'icon')
        Fits.ITEMS, Fits.PACKS, Fits.CHOSEN = saved[1], saved[2], saved[3]
    end,

    the_stock_build_reads_suits_without_loading_their_meshes = function()
        -- ESBItemCategory_NanoSuit = 4 (closet/head/stock.lua's Stock.NANOSUIT, Ghidra entry 0x145e2b9e0).
        local function name(s) return {ToString = function() return s end} end
        local function table_of(t)
            local dt = {}
            function dt:ForEachRow(fn) for _, k in ipairs(t.order) do fn(name(k), t[k]) end end
            function dt:FindRow(k) return t[k] end
            return dt
        end
        local loaded, log = {}, {}
        local env = {log = function(m) log[#log + 1] = m end,
            text = function(v) if type(v) == 'string' then return v == 'Item_BS_1_Name' and 'Suit One' or nil end
                return v:ToString() end,
            load = function(p) loaded[#loaded + 1] = p end}
        local tables = {
            [Stock.TABLES[1]] = table_of({order = {'BS_1', 'BS_1_Var2'},
                BS_1 = {Category = Stock.NANOSUIT, Name = name('Item_BS_1_Name'), Asset2D = name(icon('BS_1')),
                    EquipmentAlias = name('BS_1'), EquipmentAlias2 = name('None')},
                BS_1_Var2 = {Category = Stock.NANOSUIT, Name = name('Item_BS_1_Var2_Name'),
                    Asset2D = name(icon('BS_1')), EquipmentAlias = name('BS_1_Var2')}}),
            [Stock.TABLES[2]] = table_of({order = {'BS_1', 'BS_1_Var2'},
                BS_1 = {Type = 13, MountingResourcePath = name('/Game/S/S1.S1'), MaterialGroup = name('None'),
                    bUseHidePonytail = true},
                BS_1_Var2 = {Type = 13, MountingResourcePath = name("SkeletalMesh'/Game/S/S1B.S1B'"),
                    MaterialGroup = name('None'), bUseHidePonytail = false}}),
            [Stock.TABLES[3]] = table_of({order = {'X'}, X = {Group = name('EM_X'), VariationIndex = 0,
                MaterialIndex = 0, MaterialAssetPath = name('')}}),
        }
        env.find = function(p) return tables[p] end
        local items = Stock.build(env)
        local it = items['SB.BS_1']
        ok(it, 'the suit is built')
        eq(it.DisplayName, 'Suit One', 'name looked up as a key')
        eq(it.HidePonytail, true, 'bUseHidePonytail read')
        eq(#it.Variants, 2, 'its colour version')
        eq(it.Variants[2].Mesh, '/Game/S/S1B.S1B', 'plain mesh')
        eq(items['SB.BS_1_Var2'], nil, 'no fit of its own')
        for _, p in ipairs(loaded) do ok(not p:find('^/Game/S/'), 'no suit mesh loaded at the read: ' .. p) end
    end,
}

run('suits', tests)
