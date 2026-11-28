-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The JSON decoder (closet/json.lua) that closet/cns_import.lua reads packs with.
local run=dofile('tests/lua/closet/run.lua')
local Json = require('closet.json')

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
}

run('json_test',tests)
