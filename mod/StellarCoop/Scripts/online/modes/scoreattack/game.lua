-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The game side of a score attack round, between the round on the link (online/modes/scoreattack/round.lua) and our
-- run (online/modes/scoreattack/run.lua). At the round's challenge our run starts at our lobby spot, facing the ring
-- centre, then the ready line goes. While it plays, its score and wave go as now lines; at its end, its result goes as
-- the done line. A player who cannot play sits out the round with one log line and one notice and sends nothing:
-- scoreattack=off, EVE on the bike, a Night Operation run on, EVE not in the lobby room, SB's own hall chair seating
-- her or the run's own start check refuses. EVE gets up from the mod's hall seat first. The lobby's stand cannot end
-- SB's chair interaction, so the run's teleport to her spot would land while it still runs on her.
-- tests/lua/online/modes/scoreattack/game_test.lua covers it on fakes.
local Sa=require('online.modes.scoreattack.model')
local G={}
-- o: run (run.lua's), round (round.lua's), log(text), on() (scoreattack=on), riding(), night() (a Night Operation
-- run is on), target() (the lobby room EVE stands in, as online/lobby/sbo.lua gives it, or nil), resting() (SB's own
-- interaction runs on EVE: a hall chair of SB seats her), seated() (the mod's seat), stand(), out(key) (the sit-out
-- notice: off, bike, night, room, seat or refused, ui/text.lua's scoreattack.out), optional.
function G.new(o)
    local self={}
    local function sit(key,why)
        o.log('sit out: '..why)
        if o.out then o.out(key) end
        return false,why
    end
    -- The round's challenge def is known: our run on its seed at spot k (our place in the round's players).
    function self.start(def,seed,k)
        if not o.on() then return sit('off','scoreattack=off') end
        if o.riding() then return sit('bike','EVE rides the bike') end
        if o.night() then return sit('night','a Night Operation run is on') end
        local t=o.target()
        local p=t and t.spots[k]
        if not p then return sit('room',t and 'this room has no spot '..k or 'EVE is not in the lobby room') end
        if o.resting() then return sit('seat','SB\'s chair seats EVE') end
        if o.seated() then o.stand() end
        local ok,why=o.run.start(def,seed,{X=p.X,Y=p.Y,Z=p.Z},p.Yaw)
        if not ok then return sit('refused',why) end
        o.round.ready()
        return true
    end
    -- The round ended for us (round.lua's reasons, coop off included): our run stops.
    function self.stop(why) o.run.stop(why) end
    -- Each pass after the round's: the run, then its score and wave while its waves play.
    function self.tick()
        o.run.tick()
        local s=o.run.state()
        if s and (s.phase=='wave' or s.phase=='breather') then o.round.now(s.score,s.wave) end
    end
    -- The run's end (run.lua's ended): its done line.
    function self.ended(s) o.round.done(Sa.result(s.def,s.outcome,s.score,s.time)) end
    return self
end
return G
