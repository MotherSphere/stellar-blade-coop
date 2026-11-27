-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Runs a closet test file's table of named checks in name order, with helpers.lua's assertions as globals. Any
-- failure raises, so lua5.4 exits with an error.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local H=dofile('tests/lua/closet/helpers.lua')
for k,v in pairs(H) do _G[k]=v end
return function(name,tests)
    local names={}
    for n in pairs(tests) do names[#names+1]=n end
    table.sort(names)
    for _,n in ipairs(names) do
        local ok,why=xpcall(tests[n],debug.traceback)
        if not ok then error(name..': '..n..': '..tostring(why),0) end
    end
    assert(#names>0,name..': no checks')
    print(name..' ok')
end
