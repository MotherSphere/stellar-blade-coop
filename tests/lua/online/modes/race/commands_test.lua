-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- online/modes/race/commands.lua: coop race look on is refused while EVE rides the bike, with nothing asked of the Doro
-- look; once she is off, the look starts. coop race match, alone or with status, says race_match, the count of
-- official tracks (online/modes/race/match/tracks.lua) and the round's state line; pick sets the round's pick and
-- puts a name (not random or a number) into coop-tracks.txt; other words after it get its use why. Without the Steam link there is no round: the status says so, pick is refused.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local looks=0
local rides=true
local match=true
local picks,indexed={},{}
local round={status=function() return 'pick random; no round yet' end,
    pick=function(word)
        if word==nil then return picks[#picks] or 'random' end
        if word=='Bad' then return false end
        picks[#picks+1]=word
        return true
    end}
local o={puppet={doro=function() return true end},
    doro={on=function() looks=looks+1; return true,'look on' end,off=function() return true,'look off' end},
    coop_slot=function() return true end,race={command=function() return false,'race' end},
    riding=function() return rides end,match_on=function() return match end,round=round,
    index=function(name) indexed[#indexed+1]=name end}
local Cmd=require('online.modes.race.commands').new(o)
local ok,why=Cmd.race('look','on')
assert(not ok and why=='EVE rides the bike: coop bike gets her off first' and looks==0,why)
rides=false
assert(Cmd.race('look','on') and looks==1)
-- coop race match: the setting read at each call; the race's own words never see it.
local STATUS='Doro races in matches: race_match=%s, official tracks: 1; %s'
ok,why=Cmd.race('match')
assert(ok and why==STATUS:format('on','pick random; no round yet'),why)
match=false
ok,why=Cmd.race('match','status')
assert(ok and why==STATUS:format('off','pick random; no round yet'),why)
ok,why=Cmd.race('match','pick','xion_eight')
assert(ok and why=='Doro race: next track xion_eight' and picks[1]=='xion_eight',why)
-- A pick by name goes into coop-tracks.txt (the host's own tracks a room may offer); random and a number do not.
assert(indexed[1]=='xion_eight' and #indexed==1)
assert(Cmd.race('match','pick','random') and Cmd.race('match','pick','2') and #indexed==1)
picks={picks[1]}
local USE='Use: coop race match [status | pick <name>|<number>|random]'
local wrong={{'match','pick'},{'match','pick','Bad'},{'match','status','x'},{'match','x'},{'match','x','y'}}
for _,args in ipairs(wrong) do
    ok,why=Cmd.race(table.unpack(args))
    assert(not ok and why==USE,why)
end
assert(#picks==1 and #indexed==1,'A refused pick is not indexed')
o.round=nil
Cmd=require('online.modes.race.commands').new(o)
ok,why=Cmd.race('match')
assert(ok and why==STATUS:format('off','no Steam link.'),why)
ok,why=Cmd.race('match','pick','random')
assert(not ok and why=='Doro races in matches need the Steam link.',why)
print('race_commands_test ok')
