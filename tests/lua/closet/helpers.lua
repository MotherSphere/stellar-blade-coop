-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Assertions for the closet tests (tests/lua/closet/*_test.lua): each test loads them with run.lua.
local H = {}

local function show(v)
    if type(v) ~= 'table' then return type(v) == 'string' and ('%q'):format(v) or tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    local array = #v == #keys
    for _, k in ipairs(keys) do
        parts[#parts + 1] = array and show(v[k]) or (tostring(k) .. '=' .. show(v[k]))
    end
    return '{' .. table.concat(parts, ', ') .. '}'
end
H.show = show

local function deep(a, b)
    if type(a) ~= 'table' or type(b) ~= 'table' then return a == b end
    for k, v in pairs(a) do if not deep(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

function H.eq(got, want, what)
    if got ~= want then error(('%s: got %s, want %s'):format(what or 'eq', show(got), show(want)), 2) end
end

function H.same(got, want, what)
    if not deep(got, want) then error(('%s: got %s, want %s'):format(what or 'same', show(got), show(want)), 2) end
end

function H.ok(cond, what)
    if not cond then error((what or 'expected true'), 2) end
end

function H.raises(fn, pattern, what)
    local good, why = pcall(fn)
    if good then error((what or 'raises') .. ': did not raise', 2) end
    if pattern and not tostring(why):find(pattern) then
        error(('%s: raised %s, want %s'):format(what or 'raises', tostring(why), pattern), 2)
    end
end

-- Any error line containing `needle`.
function H.has(lines, needle, what)
    for _, line in ipairs(lines) do
        if line:find(needle, 1, true) then return end
    end
    error(('%s: no line with %q in %s'):format(what or 'has', needle, show(lines)), 2)
end

return H
