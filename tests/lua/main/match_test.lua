-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop match (search, create, cancel, end, join with a code, leave), coop mute, unmute, block, unblock and blocked
-- through main.lua: each asks the native part its request line (blocked asks nothing), search and create with the SBO
-- lobby's room and hall words (lobby_words()); anything else gets the usage line and asks nothing.
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
-- UE4SS.log masks SteamIDs and join codes (core/mask.lua); the 4 digits it shows after *** name the one player in the
-- lobby whose SteamID ends in them, for coop mute, unmute, allow, deny and remove.
coop('mute','76561198000000001'); assert(last()=='[StellarCoop] OK: asked the native part: mute ***0001\n',last())
coop('join','ccs-cbmh'); assert(not table.concat(printed,'|'):find('CCS-CBMH',1,true),'no whole code in the log')
local members=fake_link.members
fake_link.members=function() return {{id='76561198000000001'},{id='76561198000000002'},{id='76561198000010002'}} end
coop('mute','0001'); assert(asked[#asked]=='mute 76561198000000001')
coop('remove','0001'); assert(asked[#asked]=='remove 76561198000000001')
n=#asked
coop('allow','0002'); assert(#asked==n and last():find('STOP: two players have a SteamID ending in 0002',1,true))
coop('deny','0003'); assert(#asked==n and last():find('STOP: no player in the lobby has a SteamID ending in 0003',1,true))
fake_link.members=members
coop('unmute','0001'); assert(#asked==n,'no lobby: no player')
-- The block list: block takes a SteamID (or a lobby member's 4 digits), unblock a SteamID or all; blocked reads the
-- count from the status, as the file holds only hashes.
coop('block','76561198000000009'); assert(asked[#asked]=='block 76561198000000009')
coop('unblock','76561198000000009'); assert(asked[#asked]=='unblock 76561198000000009')
coop('unblock','all'); assert(asked[#asked]=='unblock all')
n=#asked
coop('unblock'); assert(#asked==n and last():find('Use: coop unblock <SteamID>|all',1,true))
coop('unblock','x'); coop('block','all'); assert(#asked==n and last():find('Use: coop block <SteamID>',1,true))
coop('blocked'); assert(last():find('STOP: no Steam link status yet',1,true),last())
local before=status_text
status_text='mod=v proto=3 steam=ready\nme=Me\nblocked=2\nlink=none lobby=0\n'
coop('blocked'); assert(last()=='[StellarCoop] OK: 2 players are on your block list\n',last())
status_text='mod=v proto=3 steam=ready\nme=Me\nblocked=1\nlink=none lobby=0\n'
coop('blocked'); assert(last()=='[StellarCoop] OK: 1 player is on your block list\n',last())
-- unblock takes the 4 digits the logs show for a player blocked in this game run (the status's block= lines).
status_text='mod=v proto=3 steam=ready\nme=Me\nblocked=3\nblock=76561198000000002 Kaanta\n'
    ..'block=76561198000010007 A\nblock=76561198000000007 B\nlink=none lobby=0\n'
coop('unblock','0002'); assert(asked[#asked]=='unblock 76561198000000002',asked[#asked])
n=#asked
coop('unblock','0007'); assert(#asked==n and last():find('STOP: two players blocked in this game run have a SteamID '
    ..'ending in 0007',1,true),last())
coop('unblock','0009'); assert(#asked==n and last():find('STOP: no player blocked in this game run has a SteamID '
    ..'ending in 0009',1,true),last())
status_text=before
assert(#asked==n,'blocked asks nothing')
io.stdout:write('match_test ok\n') -- The fixture's print keeps lines for last().
