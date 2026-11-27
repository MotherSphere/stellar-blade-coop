-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The read-only CNS-format importer (closet/cns_import.lua). Samples are written here from the public format docs;
-- no creator's pack is copied into the repo.
local run=dofile('tests/lua/closet/run.lua')
local CnsImport = require('closet.cns_import')
local Slots = require('closet.slots')

local function one(json)
    local out = CnsImport.parse(json, 'sample')
    same(out.errors, {}, 'errors')
    eq(#out.items, 1, 'items')
    return out.items[1], out
end

local tests={
    body_becomes_full_outfit = function()
        local item = one([=[[{"UniqueFitID":"me.suit","DisplayName":"Suit","Description":"d","FitMeshType":"Body",
            "OutfitPaths":["/Game/M/A.A","/Game/M/B.B"],"OutfitNames":["Red","Blue"],"CharacterID":"EVE"}]]=])
        eq(item.Id, 'cns:me.suit') eq(item.Slot, Slots.FULL_OUTFIT) eq(item.Source, 'cns')
        eq(#item.Variants, 2, 'variants') eq(item.Variants[2].Mesh, '/Game/M/B.B') eq(item.Variants[2].Name, 'Blue')
        eq(item.Mesh, '/Game/M/A.A', 'first variant')
    end,
    missing_or_empty_fit_mesh_type_is_body = function()
        eq(one('[{"UniqueFitID":"a","OutfitPaths":["/Game/M/A.A"]}]').Slot, Slots.FULL_OUTFIT, 'missing')
        eq(one('[{"UniqueFitID":"a","FitMeshType":"","OutfitPaths":["/Game/M/A.A"]}]').Slot, Slots.FULL_OUTFIT, 'empty')
    end,
    head_slots_and_ponytail = function()
        for kind, slot in pairs({Face = 'Face', Ears = 'Ears', Eyes = 'Eyes', Weapon = 'Weapon', Hair = 'Hair'}) do
            eq(one(('[{"UniqueFitID":"a","FitMeshType":"%s","OutfitPaths":["/Game/M/A.A"]}]'):format(kind)).Slot,
                slot, kind)
        end
        for _, sub in ipairs({'PonyTail', 'Ponytail', 'ponytail'}) do
            eq(one(('[{"UniqueFitID":"a","FitMeshType":"Hair","MeshSubType":"%s","OutfitPaths":["/Game/M/A.A"]}]')
                :format(sub)).Slot, 'Ponytail', sub)
        end
    end,
    character_case_and_other_characters = function()
        eq(one('[{"UniqueFitID":"a","CharacterID":"Eve","OutfitPaths":["/Game/M/A.A"]}]').CharacterID, 'EVE', 'Eve')
        local out = CnsImport.parse('[{"UniqueFitID":"l","CharacterID":"Lily","OutfitPaths":["/Game/M/A.A"]},' ..
            '{"UniqueFitID":"d","CharacterID":"DRONE","OutfitPaths":["/Game/M/A.A"]}]', 's')
        eq(#out.items, 0, 'none imported') eq(#out.skipped, 2, 'both skipped') same(out.errors, {}, 'not errors')
    end,
    outfit_datas_win = function()
        local item = one([=[[{"UniqueFitID":"a","OutfitPaths":["/Game/M/Old.Old"],
            "OutfitDatas":[{"Mesh":"/Game/M/New.New","Materials":["/Game/M/MI.MI"],"HiddenMats":[2,5],
            "Parameters":[{"MaterialIndex":0,"ParamType":"Scalar","ParamName":"Gloss","Value":0.5}]}]}]]=])
        eq(#item.Variants, 1) eq(item.Variants[1].Mesh, '/Game/M/New.New')
        same(item.Variants[1].Materials, {'/Game/M/MI.MI'}) same(item.Variants[1].HiddenMats, {2, 5})
        eq(#item.Variants[1].Parameters, 1, 'parameters kept')
    end,
    empty_outfit_datas_fall_back_to_paths = function()
        eq(one('[{"UniqueFitID":"a","OutfitDatas":[],"OutfitPaths":["/Game/M/A.A"]}]').Variants[1].Mesh, '/Game/M/A.A')
    end,
    user_configs_tolerate_missing_lists = function()
        local item = one([=[[{"UniqueFitID":"a","OutfitPaths":["/Game/M/A.A"],
            "UserConfigs":{"MaterialToggles":[{"DisplayName":"Boots","MaterialIndex":3,"Value":true}]}}]]=])
        eq(#item.UserConfigs.MaterialToggles, 1)
        same(item.UserConfigs.ShapeKeys, {}, 'missing list becomes empty')
    end,
    piece_hints_from_toggles = function()
        local item = one([=[[{"UniqueFitID":"a","OutfitPaths":["/Game/M/A.A"],"UserConfigs":{"MaterialToggles":[
            {"DisplayName":"Heels","MaterialIndex":4},{"DisplayName":"Jacket P2","MaterialIndex":6},
            {"DisplayName":"Nipple Piercing: Hoops","MaterialIndex":9},{"DisplayName":"Sparkles","MaterialIndex":11}],
            "ShapeKeys":[],"ScalarControls":[],"VectorControls":[],"TextureOptions":[]}}]]=])
        eq(#item.PieceHints, 4)
        eq(item.PieceHints[1].Slot, 'Shoes') eq(item.PieceHints[1].MaterialIndex, 4)
        eq(item.PieceHints[2].Slot, 'Outerwear') eq(item.PieceHints[3].Slot, 'NippleL')
        eq(item.PieceHints[4].Slot, nil, 'no guess for an unknown name') eq(item.PieceHints[4].Name, 'Sparkles')
    end,
    piece_words = function()
        eq(CnsImport.piece_slot('Bracer'), 'Gloves', 'bracer is not a bra')
        eq(CnsImport.piece_slot('Bracelet L'), 'BraceletL')
        eq(CnsImport.piece_slot('Sports Bra'), 'UndergarmentTop')
        eq(CnsImport.piece_slot('Stockings'), 'Legs') eq(CnsImport.piece_slot('Choker'), 'Collar')
        eq(CnsImport.piece_slot('Navel piercing: ring'), 'Navel') eq(CnsImport.piece_slot('Clit piercing: x'),
            'ClitPiercing')
        eq(CnsImport.piece_slot(nil), nil)
        -- Names from installed packs that would land wrong without the word order.
        eq(CnsImport.piece_slot('plugsuit'), 'SkinSuit', 'a plugsuit is not a plug')
        eq(CnsImport.piece_slot('Anal plug-Main'), 'AnalPlug') eq(CnsImport.piece_slot('Butt Plug'), 'AnalPlug')
        eq(CnsImport.piece_slot('Nails Foot'), 'Toenails') eq(CnsImport.piece_slot('Nails'), 'Fingernails')
        eq(CnsImport.piece_slot('Ruffled skirt'), 'Pants', 'ruffled is not an LED')
        eq(CnsImport.piece_slot('Pussy Piercing'), nil, 'no guess where the place is unclear')
        eq(CnsImport.piece_slot('Pubic Hair'), 'PubicHair') eq(CnsImport.piece_slot('Necklace'), 'Necklace')
        eq(CnsImport.piece_slot('Earrings'), 'EarringL')
        -- Every hint names a slot that exists.
        for _, pair in ipairs(CnsImport.PIECE_WORDS) do ok(Slots.known(pair[2]), pair[2]) end
    end,
    head_items_get_no_piece_hints = function()
        local item = one([=[[{"UniqueFitID":"a","FitMeshType":"Hair","OutfitPaths":["/Game/M/A.A"],
            "UserConfigs":{"MaterialToggles":[{"DisplayName":"Top Bun","MaterialIndex":1}]}}]]=])
        same(item.PieceHints, {})
    end,
    bad_entries_reported_rest_loads = function()
        local out = CnsImport.parse([=[[{"DisplayName":"no id","OutfitPaths":["/Game/M/A.A"]},
            {"UniqueFitID":"x","FitMeshType":"Tail","OutfitPaths":["/Game/M/A.A"]},
            {"UniqueFitID":"y"},
            {"UniqueFitID":"ok","OutfitPaths":["/Game/M/A.A"]},
            {"UniqueFitID":"ok","OutfitPaths":["/Game/M/B.B"]}, 7]]=], 'p')
        eq(#out.items, 1, 'one good')
        has(out.errors, 'no UniqueFitID') has(out.errors, 'unknown FitMeshType Tail')
        has(out.errors, 'no mesh') has(out.errors, 'UniqueFitID repeats') has(out.errors, 'not an outfit object')
    end,
    id_with_a_space_imported = function()
        -- The closet's files write such an id as one word (Fits.word), so "Foo Suit" is worn again after a reload
        -- (dress_test's any_pack_id_survives_the_file).
        eq(one('[{"UniqueFitID":"Foo Suit","OutfitPaths":["/Game/M/A.A"]}]').Id, 'cns:Foo Suit')
    end,
    comments_trailing_commas_and_lone_object = function()
        eq(one('// c\n{"UniqueFitID":"a","OutfitPaths":["/Game/M/A.A",],}').Slot, Slots.FULL_OUTFIT)
    end,
    unknown_keys_warn = function()
        local _, out = one('[{"UniqueFitID":"a","OutfitPaths":["/Game/M/A.A"],"MaterialOverrides":{}}]')
        has(out.warnings, 'MaterialOverrides')
    end,
    should_read_skips_dekcns_own_files = function()
        ok(CnsImport.should_read('SomePack/outfit.dekcns.json'))
        ok(CnsImport.should_read('CustomNanosuitSystem\\Repacked\\X\\X.dekcns.json'), 'repacks are creator packs')
        ok(not CnsImport.should_read('CustomNanosuitSystem/Cosmetics/DekCNS-DefaultHairs.dekcns.json'))
        ok(not CnsImport.should_read('customnanosuitsystem\\cosmetics\\dekcns-defaultfaces.DEKCNS.JSON'))
        ok(not CnsImport.should_read('SomePack/readme.json'))
    end,
    should_read_takes_the_dll_path_and_no_dot_names = function()
        ok(CnsImport.should_read('~mods\\SomePack\\outfit.dekcns.json'), 'from Content\\Paks')
        ok(CnsImport.should_read('~MODS/SomePack/outfit.dekcns.json'), 'any case, either slash')
        ok(not CnsImport.should_read('~mods\\CustomNanosuitSystem\\Cosmetics\\DekCNS-DefaultHairs.dekcns.json'),
            'DekCNS own files under ~mods')
        ok(CnsImport.should_read('~mods\\SomePack\\OutfitDekcns.json'), 'no dot before dekcns')
        ok(not CnsImport.should_read('~mods\\SomePack\\outfit.json'))
    end,
    merge_keeps_the_first_unique_fit_id_across_files = function()
        local into = {}
        local a = CnsImport.parse('[{"UniqueFitID":"x","DisplayName":"A","OutfitPaths":["/Game/M/A.A"]}]', 'a.json')
        local b = CnsImport.parse('[{"UniqueFitID":"x","DisplayName":"B","OutfitPaths":["/Game/M/B.B"]},' ..
            '{"UniqueFitID":"y","OutfitPaths":["/Game/M/Y.Y"]}]', 'b.json')
        same(CnsImport.merge(into, a.items, 'a.json'), {}, 'nothing repeats yet')
        same(CnsImport.merge(into, b.items, 'b.json'), {'b.json: UniqueFitID x repeats a.json, ignored'}, 'flagged')
        eq(into.x.DisplayName, 'A', 'first kept') eq(into.x.File, 'a.json') eq(into.y.File, 'b.json')
    end,
}

run('cns_import_test',tests)
