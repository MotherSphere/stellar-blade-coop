-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- core/row_edit.lua: a set of accepted values; engine text in a log line as printable ASCII (the Korean label
-- online/modes/nightop/roxanne_test.lua reads back escaped).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local R=require('core.row_edit')
local set=R.one(1,2)
assert(set[1] and set[2] and not set[3])
assert(R.ascii('2번 선택')=='2\\xEB\\xB2\\x88 \\xEC\\x84\\xA0\\xED\\x83\\x9D',R.ascii('2번 선택'))
for _,k in ipairs({'edit','get','find_name','index_of'}) do assert(type(R[k])=='function',k) end
print('core/row_edit_test: ok')
