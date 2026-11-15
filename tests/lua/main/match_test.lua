-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop match (search, create, cancel, end, join with a code, leave), coop mute and coop unmute through main.lua: each
-- asks the native part its request line, search and create with the SBO lobby's room and hall words (lobby_words());
-- anything else gets the usage line and asks nothing.
dofile('tests/lua/main/fixture.lua')
load_main(true)
coop('match','search','ffa'); assert(asked[#asked]=='match search ffa hotel 47101_5096',asked[#asked])
coop('match','create','ffa'); assert(asked[#asked]=='match create ffa hotel 47101_5096')
coop('match','cancel'); assert(asked[#asked]=='match cancel')
coop('match','end'); assert(asked[#asked]=='match end')
coop('join','ccs-cbmh'); local by_join=asked[#asked]
coop('match','join','ccs-cbmh'); assert(asked[#asked]==by_join)
coop('match','leave'); assert(asked[#asked]=='leave')
coop('mute','76561198000000001'); assert(asked[#asked]=='mute 76561198000000001')
coop('unmute','76561198000000001'); assert(asked[#asked]=='unmute 76561198000000001')
local n=#asked
coop('match','search'); coop('match','fly'); coop('mute','x')
assert(#asked==n and last():find('Use: coop mute <SteamID>',1,true))
io.stdout:write('match_test ok\n') -- The fixture's print keeps lines for last().
