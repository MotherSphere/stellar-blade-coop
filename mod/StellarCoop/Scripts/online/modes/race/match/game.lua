-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The game side of a Doro race round, between the round on the link (online/modes/race/match/round.lua) and our race
-- (online/modes/race/run.lua's match role). Once the round's track is known our race starts on our grid slot, then the
-- ready line goes; each split and our end go to the round as cp and done; a finish faster than our best on that track
-- is written to coop-records.txt. A player who cannot race sits out the round with one log line and one notice and
-- sends nothing: race_match=off, EVE on the bike, a Night Operation run on, not a co-op save, EVE not in the lobby
-- room, the track on another map or outside the room's fence, or the race's own start refuses (a track being
-- recorded, the drive probe on, no EVE, the teleport refused). EVE gets up from a hall seat first. When the round ends
-- our race closes: the host leaving or a round cancelled before its ranking is told. A player who sat out sees only
-- her notice. tests/lua/online/modes/race/match/game_test.lua covers it on fakes.
local Mm=require('online.modes.race.match.model')
local G={}
-- o: run (run.lua's), round (round.lua's), log(text), on() (race_match=on), riding(), night() (a Night Operation run
-- is on), slot() (a co-op save: true, or false and why), target() (the lobby room EVE stands in, as
-- online/lobby/sbo.lua gives it, or nil), map() (EVE's map as core/unreal.lua's U.map_of gives it, or nil), seated(),
-- stand(), me() (our SteamID), ghost(id) (a round player's ghost, or nil), name(id) (a member's name), tell(key) (a
-- notice: off, bike, night, save, room, fence, map, busy, refused and track for a sit-out; notrack, host_left and
-- cancelled; ui/text's race.match), records ({read() the text of coop-records.txt or nil, write(text) true when
-- written}, or nil).
function G.new(o)
    local self={}
    local playing=false -- Our race started in the round under way.
    local best=false -- Our finish in this round wrote a new best.
    local function sit(key,why)
        o.log('sit out: '..why)
        o.tell(key)
        return false,why
    end
    -- Our best on the track of sum: written when ms beats it (true). A file that cannot be read or written is logged.
    local function record(sum,ms,name)
        if not o.records then return end
        local ok,text=pcall(o.records.read)
        if not ok then return o.log('records: '..tostring(text)) end
        local best=Mm.best(text,sum)
        if not Mm.better(best,ms) then return end
        local new,why=Mm.write(text,sum,ms,name)
        if not new or not o.records.write(new) then
            return o.log('records: not written: '..tostring(why or 'the file write failed'))
        end
        o.log(string.format('best on %s: %d ms (was %s)',name,ms,best and tostring(best) or 'none'))
        return true
    end
    -- The round's track is known: our race on slot k (our place in the round's players, from 0).
    function self.start(t,name,seed,k)
        playing,best=false,false
        if not o.on() then return sit('off','race_match=off') end
        if o.riding() then return sit('bike','EVE rides the bike') end
        if o.night() then return sit('night','a Night Operation run is on') end
        local saved,save_why=o.slot()
        if not saved then return sit('save',save_why or 'not a co-op save') end
        local room,map=o.target(),o.map()
        if not room then return sit('room','EVE is not in the lobby room') end
        if t.map~=map then return sit('map','the track is on '..t.map..'; EVE is on '..tostring(map)) end
        if not Mm.fits(t,room,map) then return sit('fence','the track runs outside the room '..room.key) end
        if o.seated() then o.stand() end
        local cur=o.round.round()
        local me,by_id=o.me(),{}
        for _,id in ipairs(cur and cur.ids or {}) do
            local g=id~=me and o.ghost(id)
            if g then by_id[id]=g end
        end
        local sum=Mm.sum(t)
        local function line(l)
            if l.word=='cp' then o.round.cp(l.lap,l.i,l.ms) return end
            o.round.done(l)
            if l.ending=='fin' then best=record(sum,l.ms,name)==true end
        end
        -- What the round says each frame: a finish came (the late rule), the host's ranking once it came, with names;
        -- for the HUD, the round's players still racing (ready, no end yet), whether our finish wrote a new best and
        -- each other racer's place in the race ({ms= at her finish, why= at her DNF, passed= checkpoints by her last
        -- split, pos= her ghost's feet or nil}).
        local n=#t.cps
        local function news()
            local now=o.round.round()
            local fin,waiting,racers=false,0,{}
            for _,id in ipairs(now and now.ids or {}) do
                local b=now.board[id]
                if b then
                    fin=fin or b.ending=='fin'
                    if b.ready and not b.ending then waiting=waiting+1 end
                    if b.ready and id~=me then
                        local g=by_id[id]
                        local f=g and g.anchor and select(2,g.anchor())
                        racers[#racers+1]={ms=b.ending=='fin' and b.ms or nil,why=b.ending=='dnf' and (b.why or 'dnf')
                            or nil,passed=b.lap and (b.lap-1)*n+b.i or 0,pos=f and {x=f.X,y=f.Y,z=f.Z} or nil}
                    end
                end
            end
            local list
            if now and now.list then
                list={}
                for i,r in ipairs(now.list) do
                    list[i]={who=r.id==me and 'me' or r.id,ms=r.ms,pos=r.pos,name=r.id~=me and o.name(r.id) or nil}
                end
            end
            return {fin=fin,list=list,waiting=waiting,best=best,racers=racers}
        end
        local ok,key,why=o.run.match(t,name,seed,k,by_id,line,news)
        if not ok then return sit(key,why) end
        playing=true
        o.round.ready()
        return true
    end
    -- The round ended for us (round.lua's reasons): our race closes. A host who left, or a round cancelled or voided
    -- before its ranking, is told to a player who raced; the host's notrack and a guest's track are her sit-out.
    function self.stop(why)
        local raced=playing
        playing=false
        o.run.match_stop(why)
        if why=='notrack' then return o.tell('notrack') end
        if why=='track' then return sit('track','the track did not come whole') end
        local cur=o.round.round()
        if not raced or cur and cur.list then return end
        if why=='host_left' or why=='host_lost' then o.tell('host_left')
        elseif why=='host' or why=='void' then o.tell('cancelled') end
    end
    return self
end
return G
