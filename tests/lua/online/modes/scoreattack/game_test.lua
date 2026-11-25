-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The game side of a score attack round (online/modes/scoreattack/game.lua) on a fake run and round: each sit-out
-- reason in order (SB's own chair among them), with one log line, its notice key and no ready; a hall seat left
-- first; the run at our spot facing the ring centre on the round's seed, then ready; the now lines while its waves
-- play only; its end as the done line of each outcome; a stop reaches the run.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local G=require('online.modes.scoreattack.game')
local C=require('online.modes.scoreattack.challenges')
local targets=C.find('targets')
local env={on=true,riding=false,night=false,resting=false,seated=false,refuse=nil}
local room={key='xion',spots={{X=100,Y=200,Z=300,Yaw=180},{X=-100,Y=-200,Z=300,Yaw=0}}}
local calls,logs,sent,outs={},{},{},{}
local state=nil -- What the fake run's state() gives.
local run={start=function(def,seed,at,yaw)
        calls[#calls+1]=string.format('start %s %d %d,%d,%d %d',def.id,seed,at.X,at.Y,at.Z,yaw)
        if env.refuse then return false,env.refuse end
        return true
    end,
    stop=function(why) calls[#calls+1]='stop '..why end,
    tick=function() calls[#calls+1]='tick' end,
    state=function() return state end}
local round={ready=function() sent[#sent+1]='ready' end,
    now=function(score,wave) sent[#sent+1]='now '..score..' '..wave end,
    done=function(r) sent[#sent+1]=string.format('done %s %d %d',r.ending,r.score,r.tenths) end}
local game=G.new({run=run,round=round,log=function(m) logs[#logs+1]=m end,
    on=function() return env.on end,riding=function() return env.riding end,night=function() return env.night end,
    target=function() return env.room end,resting=function() return env.resting end,
    seated=function() return env.seated end,
    stand=function() calls[#calls+1]='stand'; env.seated=false end,out=function(key) outs[#outs+1]=key end})
local function clear() calls,logs,sent,outs={},{},{},{} end
-- tried: the run's start was asked (and refused); else nothing reached it. key: the notice's (ui/text.lua's
-- scoreattack.out), once.
local function sat(why,key,tried)
    local ok,said=game.start(targets,7,1)
    assert(ok==false and said==why and logs[#logs]=='sit out: '..why and #sent==0,tostring(said))
    assert(#outs==1 and outs[1]==key,tostring(outs[1]))
    assert(#calls==(tried and 1 or 0) and (not tried or calls[1]=='start targets 7 100,200,300 180'),calls[1])
    clear()
end

-- Each reason, the first that holds.
env.on,env.riding,env.night=false,true,true
sat('scoreattack=off','off')
env.on=true
sat('EVE rides the bike','bike')
env.riding=false
sat('a Night Operation run is on','night')
env.night=false
sat('EVE is not in the lobby room','room')
env.room=room
assert(not game.start(targets,7,3) and logs[1]=='sit out: this room has no spot 3' and outs[1]=='room')
clear()
-- SB's own hall chair seats EVE: she sits out, not stood up and not teleported (its interaction still runs on her).
env.resting,env.seated=true,true
sat('SB\'s chair seats EVE','seat')
env.resting,env.seated=false,false
env.refuse='census: 1 living within 40 m (nearest 12.0 m); 0 wave bodies'
sat(env.refuse,'refused',true)
env.refuse=nil

-- A seat first, then the run at spot 2 facing the ring centre on the round's seed, then ready.
env.seated=true
assert(game.start(targets,7,2)==true)
assert(calls[1]=='stand' and calls[2]=='start targets 7 -100,-200,300 0' and sent[1]=='ready' and #sent==1 and #outs==0)
clear()

-- The now line while its waves play only.
for _,phase in ipairs({'countdown','wave','breather','result','idle'}) do
    state={phase=phase,score=40,wave=2}
    game.tick()
end
assert(#calls==5 and calls[1]=='tick' and table.concat(sent,'|')=='now 40 2|now 40 2',table.concat(sent,'|'))
state=nil
game.tick()
assert(#sent==2)
clear()

-- The end as the done line: a win's time in tenths rounded down; any other end reports the limit.
game.ended({def=targets,outcome='success',score=800,time=40.08})
game.ended({def=targets,outcome='time',score=300,time=90})
game.ended({def=targets,outcome='failed',score=120,time=12.3})
game.ended({def=targets,outcome='aborted',reason='map change',score=40,time=3})
assert(table.concat(sent,'|')=='done win 800 400|done time 300 900|done dead 120 900|done stop 40 900',
    table.concat(sent,'|'))

-- The round's end reaches the run.
game.stop('left')
assert(calls[#calls]=='stop left')
print('scoreattack_game_test: ok')
