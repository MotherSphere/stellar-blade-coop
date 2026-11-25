-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The JSON decoder (closet/json.lua) and the *.stellarcloset.json checker (closet/manifest.lua).
local run=dofile('tests/lua/closet/run.lua')
local Json = require('closet.json')
local Manifest = require('closet.manifest')

local GOOD = [[
// Hand-written packs carry comments and trailing commas.
{
  "Format": "StellarCloset",
  "FormatVersion": 1,
  "Name": "Test pack",
  "Items": [
    {
      "Id": "test.boots",
      "DisplayName": "Test Boots",
      "Slot": "Shoes",
      "HidesBodyRegions": ["Calf", "Foot"],
      "Mesh": "/Game/Mods/StellarCloset/Test/SK_Boots.SK_Boots",
      "Materials": ["/Game/Mods/StellarCloset/Test/MI_Boots.MI_Boots", null, ""],
      "RegionMap": {"Calf": [1], "Foot": [2, 2]},
    },
    {
      "Id": "test.suit",
      "DisplayName": "Test Suit",
      "Slot": "FullOutfit",
      "KeepsSlots": ["Navel"],
      "Mesh": "/Game/Mods/StellarCloset/Test/SK_Suit.SK_Suit"
    }
  ]
}
]]

local function pack(items)
    return '{"Format":"StellarCloset","FormatVersion":1,"Items":[' .. items .. ']}'
end
local MESH = '"Mesh":"/Game/A/B.B"'

local tests={
    json_values = function()
        local v = Json.decode('{"a":[1,-2.5,1e3,true,false,null],"s":"x\\"y\\u00e9\\ud83d\\ude00"}')
        eq(v.a[1], 1) eq(v.a[2], -2.5) eq(v.a[3], 1000) eq(v.a[4], true) eq(v.a[5], false)
        eq(v.a[6], Json.null, 'null kept apart from missing')
        eq(v.s, 'x"y\u{e9}\u{1F600}', 'escapes and a surrogate pair')
    end,
    json_errors_name_the_line = function()
        local v, why = Json.decode('{\n"a": 1,\n"b" 2\n}')
        eq(v, nil, 'no value')
        ok(why:find('line 3'), why)
        eq(select(2, Json.decode('[1, 2')) ~= nil, true, 'unclosed array reported')
        eq(Json.decode('{"a":1} extra'), nil, 'text after the value')
    end,
    json_bom_and_comments = function()
        local v = Json.decode('\239\187\191/* c */ [1, /* in */ 2,] // end')
        same(v, {1, 2}, 'BOM, block and line comments, trailing comma')
    end,
    json_never_raises = function()
        for _, bad in ipairs({'', '{', '"\\x"', '[01x]', '{"a":}', string.rep('[', 100)}) do
            local good, v, why = pcall(Json.decode, bad)
            ok(good, 'raised on ' .. bad)
            eq(v, nil, bad)
            ok(type(why) == 'string', bad)
        end
    end,

    good_pack_loads = function()
        local out = Manifest.parse(GOOD, 'good')
        same(out.errors, {}, 'errors')
        same(out.warnings, {}, 'warnings')
        eq(#out.items, 2, 'items')
        local boots = out.items[1]
        eq(boots.Id, 'test.boots') eq(boots.Slot, 'Shoes') eq(boots.CharacterID, 'EVE')
        same(boots.Materials, {'/Game/Mods/StellarCloset/Test/MI_Boots.MI_Boots', false, false}, 'materials')
        same(Manifest.hidden_materials(boots, {'Calf', 'Foot', 'Thigh'}), {1, 2}, 'region map to indexes')
        same(out.items[2].KeepsSlots, {'Navel'}, 'keeps')
    end,
    wrong_format_or_version = function()
        has(Manifest.parse('{"Format":"Other","FormatVersion":1,"Items":[]}').errors, 'Format')
        has(Manifest.parse('{"Format":"StellarCloset","FormatVersion":2,"Items":[]}').errors, 'FormatVersion')
        has(Manifest.parse('[1]').errors, 'must be an object')
        has(Manifest.parse('{nope').errors, 'json')
    end,
    bad_item_skipped_rest_loads = function()
        local out = Manifest.parse(pack(
            '{"Id":"a","DisplayName":"A","Slot":"Hat",' .. MESH .. '},' ..
            '{"Id":"b","DisplayName":"B","Slot":"Belt",' .. MESH .. '}'))
        eq(#out.items, 1, 'one loads')
        eq(out.items[1].Id, 'b')
        has(out.errors, 'Items[1].Slot: unknown slot Hat')
    end,
    duplicate_ids = function()
        local out = Manifest.parse(pack(
            '{"Id":"a","DisplayName":"A","Slot":"Belt",' .. MESH .. '},' ..
            '{"Id":"a","DisplayName":"A2","Slot":"Neck",' .. MESH .. '}'))
        has(out.errors, 'repeats Items[1]')
        eq(#out.items, 1)
    end,
    slot_rules = function()
        local function errors(fields)
            return Manifest.parse(pack('{"Id":"x","DisplayName":"X",' .. MESH .. ',' .. fields .. '}')).errors
        end
        has(errors('"Slot":"FullOutfit","Occupies":["Pants"]'), 'a FullOutfit occupies nothing else')
        has(errors('"Slot":"Pants","Occupies":["Pants"]'), 'repeats Slot')
        has(errors('"Slot":"Pants","Occupies":["FullOutfit"]'), 'FullOutfit cannot be occupied')
        has(errors('"Slot":"Pants","HidesSlots":["Pants"]'), 'cannot hide its own slot')
        has(errors('"Slot":"Pants","KeepsSlots":["Navel"]'), 'only a FullOutfit keeps slots')
        has(errors('"Slot":"FullOutfit","KeepsSlots":["Hair"]'), 'only body slots')
        has(errors('"Slot":"Pants","HidesBodyRegions":["Elbow"]'), 'unknown region Elbow')
        has(errors('"Slot":"Pants","CharacterID":"LILY"'), 'only EVE')
    end,
    asset_rules = function()
        local function errors(fields)
            return Manifest.parse(pack('{"Id":"x","DisplayName":"X","Slot":"Belt",' .. fields .. '}')).errors
        end
        has(errors('"Mesh":"/Game/A/B.C"'), 'Mesh')
        has(errors('"Mesh":"C:/mods/B.B"'), 'Mesh')
        has(errors(MESH .. ',"Materials":["nope"]'), 'Materials')
        has(errors(MESH .. ',"RegionMap":{"Calf":[64]}'), 'not a material index 0 to 63')
        has(errors(MESH .. ',"RegionMap":{"Calf":[1.5]}'), 'not a material index')
        has(errors(MESH .. ',"RegionMap":{"Calf":["1"]}'), 'not a material index')
        has(errors(MESH .. ',"RegionMap":{"Knee":[1]}'), 'unknown region Knee')
    end,
    unknown_keys_warn = function()
        local out = Manifest.parse('{"Format":"StellarCloset","FormatVersion":1,"Future":1,"Items":[' ..
            '{"Id":"x","DisplayName":"X","Slot":"Belt",' .. MESH .. ',"Sparkle":true}]}')
        same(out.errors, {}, 'no errors')
        has(out.warnings, 'Future')
        has(out.warnings, 'Items[1].Sparkle')
        eq(#out.items, 1)
    end,
    soft_ref_shape = function()
        ok(Manifest.soft_ref('/Game/Mods/X/SK_A.SK_A'))
        ok(not Manifest.soft_ref('/Game/Mods//X/SK_A.SK_A'), 'empty folder')
        ok(not Manifest.soft_ref('/Game/SK_A.SK_A'), 'needs a folder')
        ok(not Manifest.soft_ref('/Game/X/SK_A.SK_B'), 'names differ')
        ok(not Manifest.soft_ref('/Game/X/' .. string.rep('a', 250) .. '.a'), 'too long')
    end,
}

run('manifest_test',tests)
