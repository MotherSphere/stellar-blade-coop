-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- online/modes/race/commands.lua: coop race look on is refused while EVE rides the bike, with nothing asked of the Doro
-- look; once she is off, the look starts. coop race match, alone or with status, says race_match and the count of
-- official tracks (online/modes/race/match/tracks.lua); other words after it get its use why.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local looks=0
local rides=true
local match=true
local Cmd=require('online.modes.race.commands').new({puppet={doro=function() return true end},
    doro={on=function() looks=looks+1; return true,'look on' end,off=function() return true,'look off' end},
    coop_slot=function() return true end,race={command=function() return false,'race' end},
    riding=function() return rides end,match_on=function() return match end})
local ok,why=Cmd.race('look','on')
assert(not ok and why=='EVE rides the bike: coop bike gets her off first' and looks==0,why)
rides=false
assert(Cmd.race('look','on') and looks==1)
-- coop race match: the setting read at each call; the race's own words never see it.
local STATUS='Doro races in matches: race_match=%s, official tracks: 1. Match rounds are not built yet.'
ok,why=Cmd.race('match')
assert(ok and why==STATUS:format('on'),why)
match=false
ok,why=Cmd.race('match','status')
assert(ok and why==STATUS:format('off'),why)
for _,args in ipairs({{'match','pick'},{'match','status','x'},{'match','x'}}) do
    ok,why=Cmd.race(table.unpack(args))
    assert(not ok and why=='Use: coop race match [status]',why)
end
print('race_commands_test ok')
