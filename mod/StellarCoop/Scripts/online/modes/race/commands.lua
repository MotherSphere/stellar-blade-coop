-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Doro races' console command, coop race: look on|off and probe doro here (online/modes/race/doro.lua), the co-op
-- save check of start and drive probe, match (alone or with status: race_match, the count of official tracks in
-- online/modes/race/match/tracks.lua and the round's state line; pick: the host's pick for the next round by word,
-- random, a track's name or the number of a track the room offers, as the lobby menu's Track row will), and the rest
-- in online/modes/race/run.lua's command. online/modes/race/wiring.lua builds it with new(o) at each Lua load and
-- main/loader.lua merges it into the command table. o: puppet (the ghost, online/partner/puppet.lua's, read at each
-- call), doro, coop_slot, race (online/modes/race/run.lua's), riding (main/base.lua's riding, read at each call: EVE
-- rides the bike), match_on (race_match=on, read at each call) and round (online/modes/race/match/round.lua's, nil
-- without the Steam link).
local Tracks=require('online.modes.race.match.tracks')
local Race={}
function Race.new(o)
    local puppet,doro,coop_slot,race=o.puppet,o.doro,o.coop_slot,o.race
    local self={}
    -- The look and the ghost's Doro mode go on together; off ends both, whether the look is on or not, on any save.
    -- The look and the probe start on a co-op save only: the look writes to the player actor. The look does not start
    -- while EVE rides the bike: it would hide the bike with her.
    function self.race(sub,a,extra)
        if sub=='look' and (a=='on' or a=='off') and extra==nil then
            if a=='off' then
                puppet.doro(false)
                return doro.off('coop race look off')
            end
            local ok,why=coop_slot('coop race look')
            if not ok then return false,why end
            if o.riding and o.riding() then return false,'EVE rides the bike: coop bike gets her off first' end
            ok,why=doro.on()
            if not ok then return false,why end
            local _,ghost_why=puppet.doro(true,doro.log)
            return true,why..(ghost_why and ' '..ghost_why or '')
        end
        if sub=='probe' and a=='doro' and extra==nil then
            local ok,why=coop_slot('coop race probe')
            if not ok then return false,why end
            return doro.probe()
        end
        if sub=='look' or sub=='probe' then return false,'Use: coop race look on|off | probe doro' end
        if sub=='match' then
            local use='Use: coop race match [status | pick <name>|<number>|random]'
            if a=='pick' and extra==nil or a~='pick' and extra~=nil or a~=nil and a~='status' and a~='pick' then
                return false,use
            end
            if a=='pick' then
                if not o.round then return false,'Doro races in matches need the Steam link.' end
                if not o.round.pick(extra) then return false,use end
                return true,'Doro race: next track '..o.round.pick()
            end
            local n=0
            for _,names in pairs(Tracks) do n=n+#names end
            return true,('Doro races in matches: race_match=%s, official tracks: %d%s')
                :format(o.match_on() and 'on' or 'off',n,o.round and '; '..o.round.status() or '; no Steam link.')
        end
        if sub=='start' and a~=nil and extra==nil or sub=='drive' and a=='probe' and extra==nil then
            local ok,why=coop_slot('coop race '..sub)
            if not ok then return false,why end
        end
        return race.command(sub,a,extra)
    end
    return self
end
return Race
