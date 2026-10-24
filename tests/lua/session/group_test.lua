-- session/group.lua over fakes of the game and of core/link.lua and partner/puppet.lua. The revive on the downed side:
-- the call only once every condition held for 3 s with no gap (our life state 3, the death screen's animation,
-- warp=idle, the friend alive on our map with her ghost shown within 2 m across and 1 m up or down, boss=0, standalone,
-- no nightop=rule, revive=on), once per death, ServerRequest_ActorRevival only when our life state did not move 2 s
-- after the respawn and every condition holds again, the result line, the death screen hidden when it stays up after a
-- revive and shown again at the next death, with no session, at coop off and once the revive is off, a Lua error
-- turning the revive off for the run. Together only: no call while the friend is farther than 2 m, down or missing, a
-- dropped link starting the 3 s again, and no fallback call for a death that came after the revive took. The notices on
-- both sides: the wait once per death, the revived line after a revive, her down once per death of hers on our map
-- outside a boss fight while we are up, and our revive of her only while our EVE stands within 3 m of her ghost. coop
-- revive test: solo only, at the death screen with life 3 to 5, the same call and the same lines.
-- The host's cutscene: SB's theater observers read once a second while linked (walked for only while a level sequence
-- actor plays, the one found kept while it plays), a cutscene while one has a valid player that plays; 'c' for the photo line only on the host and only while its own photo state is '0'; cut only on the guest
-- with cutscene_wait=on, the host on her map and our read not off for the run; the notice once a pause for it, from the
-- photo line.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local T=require('ui.text')
local W -- The world of one case.
local next_address=0x1000
local function uobject(full,t)
    next_address=next_address+0x100
    local address=next_address
    t=t or {}
    t.type=function() return 'UObject' end
    t.IsValid=t.IsValid or function() return true end
    t.GetAddress=function() return address end
    t.GetFullName=function() return full end
    return t
end
local mesh=uobject('SkeletalMeshComponent /Game/Map.Map:PersistentLevel.BP_PC_EVE_C_0.Mesh',
    {K2_GetComponentLocation=function() return W.at end})
local eve=uobject('BP_PC_EVE_C /Game/Map.Map:PersistentLevel.BP_PC_EVE_C_0',{Mesh=mesh})
local pc=uobject('SBNetworkPlayerController /Game/Map.Map:PersistentLevel.SBNetworkPlayerController_0',{
    ServerRequest_ActorRespawn=function(_,guid,warp)
        W.calls[#W.calls+1]=string.format('respawn %d %s',guid,tostring(warp))
        if W.respawn then W.respawn() end
    end,
    ServerRequest_ActorRevival=function(_,guid,item)
        W.calls[#W.calls+1]=string.format('revival %d %s',guid,tostring(item))
        if W.revival then W.revival() end
    end})
local dead=uobject('WB_MainHUD_Dead_C /Engine/Transient.GameEngine_1:WB_MainHUD_Master_C_1.WB_MainHUD_Dead',{
    IsAnyAnimationPlaying=function() return W.playing end,
    GetVisibility=function() return W.vis end,
    SetVisibility=function(_,v) W.vis=v; W.sets[#W.sets+1]=v end})
local huds={uobject('WB_MainHUD_Master_C /Game/UI/WB_MainHUD_Master.Default__WB_MainHUD_Master_C',
    {WB_MainHUD_Dead=uobject('x',{IsValid=function() return false end})}),
    uobject('WB_MainHUD_Master_C /Engine/Transient.GameEngine_1:WB_MainHUD_Master_C_1',{WB_MainHUD_Dead=dead})}
local kismet=uobject('KismetSystemLibrary /Script/Engine.Default__KismetSystemLibrary',{IsStandalone=function(_,p)
    assert(p==pc,'standalone is asked of our controller')
    return W.standalone
end})
local sequence_class=uobject('Class /Script/LevelSequence.LevelSequenceActor',{})
StaticFindObject=function(path)
    if path=='/Script/LevelSequence.LevelSequenceActor' then return sequence_class end
    assert(path=='/Script/Engine.Default__KismetSystemLibrary',path)
    return kismet
end
FindAllOf=function(name)
    W.finds[name]=(W.finds[name] or 0)+1
    if name=='WB_MainHUD_Master_C' then return W.huds end
    if name=='PlayerController' then return nil end -- None: core/unreal.lua's actors_of walks.
    if name=='LevelSequenceActor' then return W.sequences end
    if name=='SBTheaterLevelSequenceObserver' then
        if W.theater_error then error(W.theater_error,0) end
        return W.observers
    end
    error('FindAllOf '..name)
end
-- A theater observer: its sequence's name, and its player as UE4SS gives a TWeakObjectPtr.
local function observer(name,player)
    return uobject('SBTheaterLevelSequenceObserver /Engine/Transient.SBTheaterLevelSequenceObserver_0',
        {SequenceName=name,Player={type=function() return 'TWeakObjectPtr' end,Get=function() return player end}})
end
local scene=uobject('LevelSequencePlayer /Engine/Transient.LevelSequencePlayer_0',
    {IsPlaying=function() return W.scene end})
local idle=uobject('LevelSequencePlayer /Engine/Transient.LevelSequencePlayer_1',{IsPlaying=function() return false end})
-- The level sequence actors: an idle one, and the theater's while W.scene says its player plays.
local function sequences()
    return {uobject('LevelSequenceActor /Game/Map.Map:PersistentLevel.Idle',{SequencePlayer=idle}),
        uobject('LevelSequenceActor /Game/Map.Map:PersistentLevel.Theater',{SequencePlayer=scene})}
end
package.loaded['nightop.probe']={her=function() return W.eve end,controller=function() return pc end}
local G=require('session.group')

local GUEST='fight=on mode=on role=guest pairs=1 claims=0 corrections=0 kills=0 floored=0 desync=0 unpaired=0 maxhp=0 '
    ..'spawns=off scale=100/100 sim_us=5/9 threads=1/1/2 bosses=off battle=0 epoch=1/1/0 boss='
local ENGINE='engine=on reason=pinned build 24463856 remote=3 1 peer'
local clock=0
local function world(change)
    W={life={state=3,hp=0},mate={life=1,hp=900,max_hp=1600},fight=GUEST..'0',engine=ENGINE..' warp=idle me=4242',
        mode='guest',linked=true,at={X=1000,Y=2000,Z=300},ghost={X=1150,Y=2000,Z=300},shown=true,map='/game/e04',
        her_map='/game/e04',standalone=true,playing=true,vis=4,huds=huds,eve=eve,
        settings={revive=true,cutscene_wait=true},calls={},said={},logs={},sets={},finds={},observers={}}
    if change then change(W) end
    clock=0
    local link={life=function() return W.life end,mate=function() return W.mate end,fight=function() return W.fight end,
        status=function()
            return 'mod=v proto=12 steam=ready\nlink='..W.mode..' lobby=7\n'..W.engine..'\nlast=#1 x\n'
        end,
        mode=function() return W.mode end,friend=function() return 'Kaanta',W.linked,false end,
        photo=function() return W.photo end}
    local puppet={her_map=function() return W.her_map end,me=function() return {at=W.at,map=W.map} end,
        anchor=function()
            if W.shown then return {X=W.ghost.X,Y=W.ghost.Y,Z=W.ghost.Z+220},W.ghost end
        end}
    return G.new({link=link,puppet=puppet,settings=W.settings,log=function(m) W.logs[#W.logs+1]=m end,
        tell=function(build) W.said[#W.said+1]=build(T.en) end,name=function() return 'Kaanta' end})
end
local function run(g,seconds) -- Ticks of 250 ms, as main.lua's loop gives them.
    for _=1,math.floor(seconds/0.25+0.5) do
        clock=clock+0.25
        g.tick(clock)
    end
end
local function logged(text)
    for _,line in ipairs(W.logs) do if line:find(text,1,true) then return line end end
end
local WAIT,REVIVED='Kaanta can revive you: wait, or respawn at a camp.','Revived by Kaanta.'
local RESPAWN,REVIVAL='respawn 4242 false','revival 4242 false'

-- Every condition held: the respawn call once 3 s held, never before; the wait notice at the first tick. A revive that
-- takes (life 1 by the next read): no fallback; the result 2 s later, the death screen hidden as it still plays, the
-- revived notice. The next death shows the screen again and can be revived again; the screen is looked up once.
local g=world(function(w) w.respawn=function() w.life={state=1,hp=1600} end end)
run(g,0.25)
assert(#W.calls==0 and W.said[1]==WAIT and #W.said==1,table.concat(W.said,'|'))
run(g,2.75)
assert(#W.calls==0,'Not before 3 s')
run(g,0.25)
assert(#W.calls==1 and W.calls[1]==RESPAWN,table.concat(W.calls,'|'))
assert(logged('revive: ServerRequest_ActorRespawn(4242, false) asked (Kaanta 1.5 m away; life 3, hp 0, death screen '
    ..'up)'),table.concat(W.logs,'|'))
run(g,1.75)
assert(#W.sets==0 and not logged('revive result'),'The result 2 s after the call')
run(g,0.25)
assert(#W.calls==1,'No fallback: the life state moved')
assert(logged('revive result (Kaanta): life 3/1, hp 0/1600, death screen up/hidden, recovery items not read, EVE pawn '
    ..'same'),table.concat(W.logs,'|'))
assert(W.sets[1]==2 and W.vis==2 and W.said[2]==REVIVED and #W.said==2,table.concat(W.said,'|'))
run(g,5)
assert(#W.calls==1 and #W.said==2,'Once per death')
W.life={state=3,hp=0} -- A new death: the screen back as it was, a new wait notice, a new call 3 s later.
run(g,0.25)
assert(W.sets[2]==4 and W.vis==4 and logged('revive: death screen shown again (a new death)') and W.said[3]==WAIT)
run(g,3)
assert(#W.calls==2 and W.calls[2]==RESPAWN and W.finds.WB_MainHUD_Master_C==1,W.finds.WB_MainHUD_Master_C)

-- A respawn that changes nothing: ServerRequest_ActorRevival 2 s later, once, then the result; no notice, and nothing
-- more for that death.
g=world()
run(g,3.25)
assert(#W.calls==1)
run(g,2)
assert(#W.calls==2 and W.calls[2]==REVIVAL and logged('revive: life still 3 2 s after the respawn: '
    ..'ServerRequest_ActorRevival(4242, false) asked'),table.concat(W.logs,'|'))
run(g,2)
assert(logged('revive result (Kaanta): life 3/3, hp 0/0, death screen up/up, recovery items not read, EVE pawn same'))
run(g,20)
assert(#W.calls==2 and #W.said==1 and #W.sets==0,'Nothing more for that death')
-- The fallback takes: the revived notice; the screen left alone once its animation stopped; a new pawn said.
local other=uobject('BP_PC_EVE_C /Game/Map.Map:PersistentLevel.BP_PC_EVE_C_1',{Mesh=mesh})
g=world(function(w) w.revival=function() w.life,w.playing,w.eve={state=6,hp=1600},false,other end end)
run(g,7.25)
assert(#W.calls==2 and W.said[2]==REVIVED and #W.sets==0)
assert(logged('revive result (Kaanta): life 3/6, hp 0/1600, death screen up/off, recovery items not read, EVE pawn '
    ..'new'),table.concat(W.logs,'|'))

-- The detector, each condition alone failing for 6 s: no call. Together only: the friend farther than 2 m across or
-- 1 m up or down, her ghost hidden or on another map, her vitals missing or down.
for _,case in ipairs({
    {'ghost 2.01 m across',function(w) w.ghost={X=1000,Y=2201,Z=300} end},
    {'ghost 1.01 m up',function(w) w.ghost={X=1000,Y=2000,Z=401} end},
    {'ghost 1.01 m down',function(w) w.ghost={X=1000,Y=2000,Z=199} end},
    {'ghost hidden',function(w) w.shown=false end},
    {'her map another',function(w) w.her_map='/game/f02' end},
    {'her vitals missing',function(w) w.mate=nil end},
    {'friend down',function(w) w.mate={life=3,hp=0,max_hp=1600} end},
    {'friend at 0 HP',function(w) w.mate={life=1,hp=0,max_hp=1600} end},
    {'death screen not playing',function(w) w.playing=false end},
    {'no death screen',function(w) w.huds={} end},
    {'warp=busy',function(w) w.engine=ENGINE..' warp=busy me=4242' end},
    {'no warp read',function(w) w.engine=ENGINE end},
    {'boss=1',function(w) w.fight=GUEST..'1' end},
    {'no fight line',function(w) w.fight=nil end},
    {'not standalone',function(w) w.standalone=false end},
    {'nightop=rule',function(w) w.engine=ENGINE..' warp=idle me=4242 nightop=rule' end},
    {'revive=off',function(w) w.settings.revive=false end},
    {'life 4',function(w) w.life={state=4,hp=0} end},
    {'alive',function(w) w.life={state=1,hp=800} end},
    {'no life read',function(w) w.life=nil end},
    {'no friend linked',function(w) w.linked=false end},
    {'no EVE',function(w) w.eve=nil end},
}) do
    g=world(case[2])
    run(g,6)
    assert(#W.calls==0,case[1])
end
-- Within 2 m across and 1 m up or down holds.
g=world(function(w) w.ghost={X=1000,Y=2200,Z=400} end)
run(g,3.25)
assert(#W.calls==1,'2 m and 1 m are in')
-- The notice waits for everything but the distance: none with revive=off, the friend down or boss=1.
for _,change in ipairs({function(w) w.settings.revive=false end,function(w) w.mate={life=4,hp=0,max_hp=1600} end,
    function(w) w.fight=GUEST..'1' end}) do
    g=world(change)
    run(g,2)
    assert(#W.said==0)
end
g=world(function(w) w.ghost={X=5000,Y=2000,Z=300} end)
run(g,5)
assert(#W.said==1 and W.said[1]==WAIT and #W.calls==0,'The friend far: the wait notice, no call')
assert(logged('revive waits: friend far'),table.concat(W.logs,'|'))

-- No gap: 2.75 s held, one tick with the friend away, then 3 s again from there.
g=world()
run(g,2.75)
W.ghost={X=1000,Y=2300,Z=300}
run(g,0.25)
W.ghost={X=1150,Y=2000,Z=300}
run(g,3)
assert(#W.calls==0,'The hold starts again')
run(g,0.25)
assert(#W.calls==1)

-- A link that drops starts the 3 s again: 2 s held, 5 s unlinked, then 3 s from the reconnect.
g=world()
run(g,2)
W.linked=false
run(g,5)
W.linked=true
run(g,3)
assert(#W.calls==0,'The hold starts again at the reconnect')
run(g,0.25)
assert(#W.calls==1)

-- Up after the respawn and down again before the 2 s read, the friend still beside her: no ServerRequest_ActorRevival,
-- the revived notice for the revive that took, and the new death waits for its own 3 s.
g=world(function(w) w.respawn=function() w.life={state=1,hp=1600} end end)
run(g,3.25)
assert(#W.calls==1)
run(g,1)
W.life={state=3,hp=0}
run(g,1)
assert(#W.calls==1,'No fallback for a new death')
assert(logged('revive result (Kaanta): life 3/3 (up in between), hp 0/0, death screen up/up'),table.concat(W.logs,'|'))
assert(#W.said==2 and W.said[2]==REVIVED and #W.sets==0,table.concat(W.said,'|'))
run(g,3)
assert(#W.calls==1 and W.said[3]==WAIT,'A new death: its own 3 s')
run(g,0.25)
assert(#W.calls==2 and W.calls[2]==RESPAWN)

-- The fallback asks every condition again: a respawn she pressed (warp=busy), the friend gone far or down, or
-- revive=off by then: no fallback call (ServerRequest_ActorRevival), one line why, then the result.
for _,case in ipairs({
    {'a respawn or a warp is under way',function(w) w.engine=ENGINE..' warp=busy me=4242' end},
    {'friend far',function(w) w.ghost={X=5000,Y=2000,Z=300} end},
    {'friend not alive',function(w) w.mate={life=3,hp=0,max_hp=1600} end},
    {'revive=off',function(w) w.settings.revive=false end},
}) do
    g=world()
    run(g,3.25)
    case[2](W)
    run(g,2)
    assert(#W.calls==1 and logged('revive: life still 3 2 s after the respawn, no fallback call: '
        ..case[1]),case[1]..': '..table.concat(W.logs,'|'))
    assert(logged('revive result (Kaanta): life 3/3, hp 0/0'),case[1])
end

-- A respawn that leaves life 6 under a death screen that still plays: hidden too.
g=world(function(w) w.respawn=function() w.life={state=6,hp=1600} end end)
run(g,5.25)
assert(#W.calls==1 and W.vis==2 and logged('death screen up/hidden'),table.concat(W.logs,'|'))
-- The screen we hid comes back as it was with no session (no life read), at coop off and once the revive is off.
for _,case in ipairs({
    {'no session',function() W.life=nil end},
    {'coop off',function(group) group.stop() end},
    {'the revive is off',function() W.life=setmetatable({},{__index=function() error('bad read',0) end}) end},
}) do
    g=world(function(w) w.respawn=function() w.life={state=1,hp=1600} end end)
    run(g,5.25)
    assert(W.vis==2,case[1])
    case[2](g)
    run(g,0.25)
    assert(W.vis==4 and logged('revive: death screen shown again ('..case[1]..')'),case[1]..': '
        ..table.concat(W.logs,'|'))
end

-- Why it waits, in the log: a boss of ours in battle, or no shared fight at all (no boss= on the fight line).
for _,case in ipairs({{GUEST..'1','boss fight'},{nil,'no shared fight'},{'fight=waiting why=x','no shared fight'}}) do
    g=world(function(w) w.fight=case[1] end)
    run(g,1)
    assert(logged('revive waits: '..case[2]) and #W.logs==1,table.concat(W.logs,'|'))
end

-- A Lua error in the call: one line, and the revive off for the run, the next death included.
g=world(function(w) w.respawn=function() error('no such function',0) end end)
run(g,3.25)
assert(logged('revive off for this run: no such function'),table.concat(W.logs,'|'))
W.respawn=nil
W.life={state=1,hp=1600}
run(g,1)
W.life={state=3,hp=0}
run(g,6)
assert(#W.calls==1,'Off for the run')

-- The friend's side: her down notice once per death of hers, on our map and outside a boss fight of ours; our revive
-- of her once her vitals go from down to alive while our EVE stands within 3 m of her ghost.
local DOWN,YOU='Kaanta is down. Stand next to them for 3 s to revive them.','You revived Kaanta.'
g=world(function(w) w.mode,w.life,w.mate='host',{state=1,hp=1600},{life=3,hp=0,max_hp=1600} end)
run(g,5)
assert(#W.said==1 and W.said[1]==DOWN and #W.calls==0,table.concat(W.said,'|'))
W.mate={life=1,hp=1600,max_hp=1600}
W.ghost={X=1000,Y=2290,Z=300} -- 2.9 m.
run(g,0.25)
assert(W.said[2]==YOU and #W.said==2)
run(g,3)
W.mate={life=4,hp=0,max_hp=1600} -- Her next death, then up again while we stand 3.1 m away.
run(g,0.25)
assert(W.said[3]==DOWN)
W.ghost={X=1000,Y=2310,Z=300}
W.mate={life=1,hp=1600,max_hp=1600}
run(g,1)
assert(#W.said==3,'Farther than 3 m: not ours')
for _,change in ipairs({function(w) w.her_map='/game/f02' end,function(w) w.fight=GUEST..'1' end,
    function(w) w.fight=nil end,function(w) w.linked=false end,function(w) w.life={state=3,hp=0} end}) do
    g=world(function(w) w.mode,w.life,w.mate='host',{state=1,hp=1600},{life=3,hp=0,max_hp=1600}; change(w) end)
    run(g,2)
    assert(#W.said==0)
end

-- coop revive test: refused while linked or before Steam, without a life read (a session: coop loopback), alive, off
-- the death screen or while a respawn runs; at the death screen with life 3 to 5 alone, the same call and lines.
for _,case in ipairs({
    {function(w) w.mode='guest' end,'coop revive test is solo only: leave the session first (coop leave)'},
    {function(w) w.mode=nil end,'the Steam link is not ready yet: try again in a moment'},
    {function(w) w.mode,w.life='none',nil end,'coop revive test works only at the death screen: no life read (our '
        ..'life is read in a session only: start coop loopback 0 0 0 first)'},
    {function(w) w.mode,w.life='none',{state=1,hp=100} end,'coop revive test works only at the death screen: life 1'},
    {function(w) w.mode,w.life='none',{state=6,hp=100} end,'coop revive test works only at the death screen: life 6'},
    {function(w) w.mode,w.playing='none',false end,'coop revive test works only at the death screen: no death screen'},
    {function(w) w.mode,w.engine='none',ENGINE..' warp=busy me=4242' end,
        'coop revive test works only at the death screen: a respawn or a warp is under way'},
    {function(w) w.mode,w.standalone='none',false end,
        'coop revive test works only at the death screen: the game is not standalone'},
}) do
    g=world(case[1])
    local ok,why=g.test()
    assert(not ok and why==case[2] and #W.calls==0,tostring(why))
end
for _,state in ipairs({3,4,5}) do
    g=world(function(w) w.mode,w.life,w.mate,w.linked='none',{state=state,hp=0},nil,false end)
    local ok,why=g.test()
    assert(ok and why=='ServerRequest_ActorRespawn asked: the result follows in this log in 2 to 4 s' and #W.calls==1
        and W.calls[1]==RESPAWN,tostring(why))
    assert(logged('revive: ServerRequest_ActorRespawn(4242, false) asked (coop revive test; life '..state..', hp 0, '
        ..'death screen up)'),table.concat(W.logs,'|'))
    ok,why=g.test()
    assert(not ok and why=='a revive call is under way: its result follows in this log')
    run(g,4)
    assert(#W.calls==2 and W.calls[2]==REVIVAL and logged('revive result (coop revive test): life '..state..'/'..state))
    assert(#W.said==0,'The probe says nothing on screen')
end

-- The host's cutscene, read once a second while linked: 'c' in place of its own '0' only; a guest's game reads it too
-- (for its own guards) and sends nothing; off with no valid playing player, or not linked. No level sequence actor
-- playing: no observer walk. One playing: one walk, then the observer found is kept while it plays (no walk at all).
g=world(function(w)
    w.mode,w.life,w.scene='host',{state=1,hp=1600},false
    w.observers,w.sequences={observer('Theater_Idle',nil),observer('Mann_Entrance',scene)},sequences()
end)
run(g,2.25)
assert(not g.cutscene_playing() and (W.finds.SBTheaterLevelSequenceObserver or 0)==0
    and W.finds.LevelSequenceActor==3,'Gated: '..tostring(W.finds.SBTheaterLevelSequenceObserver))
W.scene=true
run(g,1)
assert(g.cutscene_playing() and g.photo('0')=='c' and g.photo('1')=='1' and g.photo('s')=='s')
assert(logged('cutscene on: Mann_Entrance'),table.concat(W.logs,'|'))
run(g,2)
assert(W.finds.SBTheaterLevelSequenceObserver==1 and W.finds.LevelSequenceActor==4,'Kept: '
    ..W.finds.SBTheaterLevelSequenceObserver)
W.scene=false
run(g,1)
assert(not g.cutscene_playing() and g.photo('0')=='0' and logged('cutscene off')
    and W.finds.SBTheaterLevelSequenceObserver==1)
W.scene,W.mode=true,'guest'
run(g,1)
assert(g.cutscene_playing() and g.photo('0')=='0','A guest sends no cutscene')
W.linked=false
run(g,1)
assert(not g.cutscene_playing() and g.photo('0')=='0' and W.finds.SBTheaterLevelSequenceObserver==1,'Not linked')
-- A read that fails: one line, and no cutscene for the run.
g=world(function(w)
    w.mode,w.life,w.theater_error,w.scene,w.sequences='host',{state=1,hp=1600},'no such property',true,sequences()
end)
run(g,3)
assert(not g.cutscene_playing() and logged('cutscene off for this run: no such property')
    and W.finds.SBTheaterLevelSequenceObserver==1)
-- The guest's ask for the pause: cutscene_wait=on and the host on her map, as the guest only, and never once our
-- cutscene read is off for the run (her notice would not come).
g=world(function(w) w.life={state=1,hp=1600} end)
assert(g.cut()==true)
W.settings.cutscene_wait=false
assert(g.cut()==false)
W.settings.cutscene_wait,W.her_map=true,'/game/f02'
assert(g.cut()==false)
W.her_map,W.mode=W.map,'host'
assert(g.cut()==false)
W.mode,W.her_map='guest',nil
assert(g.cut()==false)
g=world(function(w)
    w.life,w.theater_error,w.scene,w.sequences={state=1,hp=1600},'no such property',true,sequences()
end)
assert(g.cut()==true)
run(g,1)
assert(g.cut()==false and logged('cutscene off for this run'))
-- Her notice: once each time the photo line says her game holds the pause for the host's cutscene.
local CUT='Kaanta is watching a cutscene. Your game waits until it ends.'
g=world(function(w) w.life,w.photo={state=1,hp=1600},{mine='0',peer='c',frozen=false} end)
run(g,1)
assert(#W.said==0,'Not before the pause holds')
W.photo.frozen=true
run(g,3)
assert(#W.said==1 and W.said[1]==CUT)
W.photo={mine='0',peer='0',frozen=false}
run(g,0.25)
W.photo={mine='0',peer='c',frozen=true}
run(g,0.25)
assert(#W.said==2 and W.said[2]==CUT)
print('group_test ok')
