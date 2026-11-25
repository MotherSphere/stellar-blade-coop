-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- online/group/group.lua over fakes of the game and of core/link.lua and online/partner/puppet.lua. The revive on the
-- downed side: the call only once every condition held for 3 s with no gap (our life state 3, the death screen's
-- animation, warp=idle, the friend alive on our map with her ghost shown within 2 m across and 1 m up or down, boss=0,
-- standalone, no nightop=rule, revive=on), once per death, ServerRequest_ActorRevival only when our life state did not
-- move 2 s after the respawn and every condition holds again, the result line, the death screen hidden when it stays up
-- after a revive and shown again at the next death, with no session, at coop off and once the revive is off (after a
-- Lua reload too, through coop-death-screen.txt), a Lua error turning the revive off for the run. Together only: no
-- call while the friend is farther than 2 m, down or missing, a dropped link starting the 3 s again, and no fallback
-- call for a death that came after the revive took. The
-- notices on both sides: the wait once per death, the revived line after a revive, her down once per death of hers on
-- our map outside a boss fight while we are up, and our revive of her only while our EVE stands within 3 m of her
-- ghost. coop revive test: solo only, at the death screen with life 3 to 5, the same call and the same lines. During a
-- Night Operation run: no 3 s rule and none of its notices on either side, our revive of her included (the run says
-- it); night_revive's call with revive=on and coop revive test's guards, its fallback with them too (the friend far
-- changes nothing), refused with revive=off, the revived notice after the friend's only.
-- The host's cutscene: SB's theater observers read once a second while linked (walked for only when the set of playing
-- level sequence actors changes, the one found kept; no world, no read), a cutscene while one has a valid player that
-- plays; 'c' for the photo line only on the host and only while its own photo state is '0'; cut only on the guest
-- with cutscene_wait=on, the host on her map and our read not off for the run; the notice once a pause for it, from the
-- photo line.
-- Camp rests (shared_world=on): our own rest sends rest <zone> (type 2 only after 10 s alive, none within 10 s of our
-- own ResetZone call); a received rest calls ResetZone for our EVE in that zone once we are free, within a minute, once
-- per zone each 30 s (a rest that waits included), with no more calls after 4 starts within 30 s of one.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local T=require('ui.text')
local U=require('core.unreal')
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
local eve=uobject('BP_PC_EVE_C /Game/Map.Map:PersistentLevel.BP_PC_EVE_C_0',{Mesh=mesh,
    GetWorld=function() return W.world end})
local pc=uobject('SBNetworkPlayerController /Game/Map.Map:PersistentLevel.SBNetworkPlayerController_0',{
    GetWorld=function() return W.world end,
    ServerRequest_ActorRespawn=function(_,guid,warp)
        W.calls[#W.calls+1]=string.format('respawn %d %s',guid,tostring(warp))
        if W.respawn then W.respawn() end
    end,
    ServerRequest_ActorRevival=function(_,guid,item)
        W.calls[#W.calls+1]=string.format('revival %d %s',guid,tostring(item))
        if W.revival then W.revival() end
    end,
    ServerRequest_ResetZone=function(_,guid,zone) W.resets[#W.resets+1]={guid=guid,zone=U.text(zone)} end})
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
-- FName with FNAME_Find, as online/group/travel_test.lua has it: a name W.names holds, else NAME_None.
EFindName={FNAME_Find=1}
FName=function(text,find)
    assert(find==EFindName.FNAME_Find,'never a new name')
    local index=(W.names or {})[text] or 0
    return uobject('FName',{GetComparisonIndex=function() return index end,
        ToString=function() return index==0 and 'None' or text end})
end
package.loaded['core.player']={her=function() return W.eve end,controller=function() return pc end}
package.loaded['core.where']={me=function() return {at=W.at,map=W.map} end}
local G=require('online.group.group')

local GUEST='fight=on mode=on role=guest pairs=1 claims=0 corrections=0 kills=0 floored=0 desync=0 unpaired=0 maxhp=0 '
    ..'spawns=off scale=100/100 sim_us=5/9 threads=1/1/2 bosses=off battle=0 epoch=1/1/0 boss='
local ENGINE='engine=on reason=pinned build 26123051 remote=3 1 peer'
local clock=0
local map=uobject('World /Game/Map.Map',{})
-- reload: a new Lua load over the same game (W and its clock kept), as Ctrl+R gives it.
local function world(change,reload)
    if not reload then
        W={life={state=3,hp=0},mate={life=1,hp=900,max_hp=1600,zone=1},fight=GUEST..'0',
            engine=ENGINE..' warp=idle me=4242',mode='guest',linked=true,at={X=1000,Y=2000,Z=300},
            ghost={X=1150,Y=2000,Z=300},shown=true,map='/game/e04',her_map='/game/e04',standalone=true,playing=true,
            vis=4,huds=huds,eve=eve,world=map,
            settings={revive=true,cutscene_wait=true,follow_host='ask',follow_key={key='F7',name='F7'}},calls={},
            said={},logs={},sets={},finds={},observers={},gone={},requests={},resets={}}
        clock=0
    end
    if change then change(W) end
    -- The status: the slot line (W.slot, none unless set) before the engine line, which ends with W.rest when set.
    -- request() keeps each line asked of the native part.
    local link={life=function() return W.life end,mate=function() return W.mate end,fight=function() return W.fight end,
        status=function()
            return 'mod=v proto=12 steam=ready\nlink='..W.mode..' lobby=7\n'..(W.slot and W.slot..'\n' or '')
                ..W.engine..(W.rest and ' '..W.rest or '')..'\nlast=#1 x\n'
        end,
        request=function(line) W.requests[#W.requests+1]=line; return true end,
        mode=function() return W.mode end,friend=function() return 'Kaanta',W.linked,false end,
        photo=function() return W.photo end,zone=function() return W.zonetype or 1,W.area end}
    -- The member lines (W.members; without them Kaanta alone in slot 0, linked as W.linked says), each one's vitals
    -- (W.vits by SteamID), the session's host (W.host).
    function link.members() return W.members or {{id='2',slot=0,linked=W.linked,name='Kaanta'}} end
    function link.vitals(id) return W.vits and W.vits[id] end
    -- coop-death-screen.txt: its first line in W.file (nil: no file), which a Lua reload keeps.
    function link.store(name)
        assert(name=='coop-death-screen.txt',name)
        return {save=function(text)
                if W.unsaved then return false,W.unsaved end
                W.file=text
                return true
            end,load=function() return W.file end,
            clear=function() W.file=nil end}
    end
    function link.host() return W.host end
    function link.member(id) for _,m in ipairs(link.members()) do if m.id==id then return m end end end
    function link.others()
        local n=0
        for _,m in ipairs(link.members()) do if m.linked then n=n+1 end end
        return n
    end
    local puppet={her_map=function() return W.her_map end,
        anchor=function()
            if W.shown then return {X=W.ghost.X,Y=W.ghost.Y,Z=W.ghost.Z+220},W.ghost end
        end}
    return G.new({link=link,puppet=puppet,settings=W.settings,log=function(m) W.logs[#W.logs+1]=m end,
        tell=function(build) W.said[#W.said+1]=build(T.en) end,
        name=function(_,name) return name and name~='' and name or 'Kaanta' end,night=function() return W.night end,
        -- The return's warp (online/group/travel.lua's go) and the follow's pause read.
        go=function(id) W.gone[#W.gone+1]=id; return true end,paused=function() return W.paused end,
        -- Ghost slot k (W.ghosts[k]: {map=, feet=}), as main.lua's ghost(k) gives it.
        ghost=function(k)
            local gh=W.ghosts and W.ghosts[k]
            return gh and {her_map=function() return gh.map end,
                anchor=function() return {X=gh.feet.X,Y=gh.feet.Y,Z=gh.feet.Z+220},gh.feet end}
        end})
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
-- A Lua reload (Ctrl+R) while the screen is hidden: its visibility before (0 here, Visible) and its address are in
-- coop-death-screen.txt. The new load's first tick looks the screen up once and takes it over while it has that address
-- and reads Hidden; a second reload does the same. It is shown again as it was at the next death, with no session or at
-- coop off. The file goes then.
local KEPT='0 '..U.address(dead)
for _,case in ipairs({
    {'a new death',function() W.life={state=3,hp=0} end},
    {'no session',function() W.life=nil end},
    {'coop off',function(group) group.stop() end},
}) do
    g=world(function(w) w.vis,w.respawn=0,function() w.life={state=1,hp=1600} end end)
    run(g,5.25)
    assert(W.vis==2 and W.file==KEPT,case[1]..': '..tostring(W.file))
    for _=1,2 do
        g=world(nil,true)
        W.logs,W.finds={},{}
        run(g,0.25)
        assert(W.vis==2 and W.file==KEPT and W.finds.WB_MainHUD_Master_C==1
            and logged('revive: death screen hidden by an earlier Lua load, taken over'),case[1]..': '
            ..table.concat(W.logs,'|'))
    end
    case[2](g)
    run(g,0.25)
    assert(W.vis==0 and W.file==nil and logged('revive: death screen shown again ('..case[1]..')'),case[1]..': '
        ..table.concat(W.logs,'|'))
end
-- A file whose screen no longer reads Hidden (SB showed it, a new game run): the file goes, the screen untouched.
g=world(function(w) w.life,w.file={state=1,hp=1600},KEPT end)
run(g,0.25)
assert(W.file==nil and #W.sets==0 and W.finds.WB_MainHUD_Master_C==1 and not logged('taken over'),
    table.concat(W.logs,'|'))
-- SB's death screen is another widget that reads Hidden (a rebuilt HUD, a new game run): the file goes, that widget is
-- left as it is, with no session too.
local other=uobject('WB_MainHUD_Dead_C /Engine/Transient.GameEngine_1:WB_MainHUD_Master_C_2.WB_MainHUD_Dead',{
    IsAnyAnimationPlaying=function() return false end,
    GetVisibility=function() return 2 end,
    SetVisibility=function(_,v) W.sets[#W.sets+1]=v end})
g=world(function(w)
    w.life,w.file={state=1,hp=1600},KEPT
    w.huds={uobject('WB_MainHUD_Master_C /Engine/Transient.GameEngine_1:WB_MainHUD_Master_C_2',
        {WB_MainHUD_Dead=other})}
end)
run(g,0.25)
W.life=nil
run(g,0.25)
assert(W.file==nil and #W.sets==0 and W.finds.WB_MainHUD_Master_C==1 and not logged('taken over')
    and not logged('shown again'),table.concat(W.logs,'|'))
-- A file without both numbers (words, the visibility alone, no address) goes with no lookup; no file, no lookup.
for _,file in ipairs({'x','4','4 x',false}) do
    g=world(function(w) w.life,w.file={state=1,hp=1600},file or nil end)
    run(g,0.25)
    assert(W.file==nil and not W.finds.WB_MainHUD_Master_C,tostring(file))
end
-- A file that cannot be written: one line, the screen hidden all the same.
g=world(function(w) w.respawn,w.unsaved=function() w.life={state=1,hp=1600} end,'cannot write x.tmp' end)
run(g,5.25)
assert(W.vis==2 and logged('revive: coop-death-screen.txt not written: cannot write x.tmp'),table.concat(W.logs,'|'))

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

-- A Night Operation run owns the revive: every condition of the 3 s rule held for 6 s makes no call and no notice.
g=world(function(w) w.night=true; w.respawn=function() w.life={state=1,hp=1600} end end)
run(g,6)
assert(#W.calls==0 and #W.said==0,'The run asks')
-- Its friend's revive: the call, said with her name, the result 2 s later, the screen hidden, her revived notice.
local ok,no=g.night_revive('friend')
assert(ok and no==nil and #W.calls==1 and W.calls[1]==RESPAWN,tostring(no))
assert(logged('revive: ServerRequest_ActorRespawn(4242, false) asked (Kaanta; life 3, hp 0, death screen up)'),
    table.concat(W.logs,'|'))
ok,no=g.night_revive('friend')
assert(not ok and no=='a revive call is under way' and #W.calls==1)
run(g,2)
assert(logged('revive result (Kaanta): life 3/1') and W.vis==2 and W.said[1]==REVIVED and #W.said==1)
-- revive=off (the downed player's opt-in): no call, by the friend or by herself.
g=world(function(w) w.night,w.settings.revive=true,false end)
for _,by in ipairs({'friend','self'}) do
    ok,no=g.night_revive(by)
    assert(not ok and no=='revive=off' and #W.calls==0,tostring(no))
end
-- Its self revive, with the friend far: the call, its fallback with the same guards, no notice.
g=world(function(w) w.night,w.ghost=true,{X=9000,Y=2000,Z=300} end)
ok=g.night_revive('self')
assert(ok and W.calls[1]==RESPAWN and logged('asked (coop nightop revive; life 3'),table.concat(W.logs,'|'))
run(g,2)
assert(W.calls[2]==REVIVAL,'The fallback: coop revive test\'s guards')
run(g,2)
assert(logged('revive result (coop nightop revive): life 3/3') and #W.said==0 and #W.calls==2)
-- Refused: alive, or a respawn under way.
for _,case in ipairs({{function(w) w.life={state=1,hp=1600} end,'life 1'},
        {function(w) w.engine=ENGINE..' warp=busy me=4242' end,'a respawn or a warp is under way'}}) do
    g=world(function(w) w.night=true; case[1](w) end)
    ok,no=g.night_revive('friend')
    assert(not ok and no==case[2] and #W.calls==0,tostring(no))
end
-- The friend's side: no down notice of hers and no revived notice of ours (the run gives its own: her own revive with
-- us next to her is not ours), both back once the run is over.
g=world(function(w) w.night,w.mode,w.life,w.mate=true,'host',{state=1,hp=1600},{life=3,hp=0,max_hp=1600} end)
run(g,5)
assert(#W.said==0)
W.mate={life=1,hp=1600,max_hp=1600}
run(g,0.25)
assert(#W.said==0,'The run says ours')
W.night,W.mate=false,{life=3,hp=0,max_hp=1600}
run(g,0.25)
W.mate={life=1,hp=1600,max_hp=1600}
run(g,0.25)
assert(W.said[1]==DOWN and W.said[2]==YOU and #W.said==2,table.concat(W.said,'|'))

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
assert(W.finds.SBTheaterLevelSequenceObserver==2,'An ended one is not kept: '..W.finds.SBTheaterLevelSequenceObserver)
W.linked=false
run(g,1)
assert(not g.cutscene_playing() and g.photo('0')=='0' and W.finds.SBTheaterLevelSequenceObserver==2,'Not linked')
-- A looping sequence actor with no theater: one walk for that set of playing actors, logged with its name, not one a
-- second. The theater starting changes the set: one walk, found. Once it ends, one walk for the set left, then none;
-- the next theater on the same actor, with an observer of its own, is walked for again.
local loop=uobject('LevelSequencePlayer /Engine/Transient.LevelSequencePlayer_2',{IsPlaying=function() return true end})
local first=observer('Mann_Entrance',scene)
g=world(function(w)
    w.mode,w.life,w.scene='host',{state=1,hp=1600},false
    w.observers,w.sequences={first},sequences()
    w.sequences[3]=uobject('LevelSequenceActor /Game/Map.Map:PersistentLevel.Lift_Loop',{SequencePlayer=loop})
end)
run(g,5)
assert(W.finds.SBTheaterLevelSequenceObserver==1 and W.finds.LevelSequenceActor==5,'One walk a set: '
    ..W.finds.SBTheaterLevelSequenceObserver)
assert(logged('cutscene: no theater for the playing sequences Lift_Loop'),table.concat(W.logs,'|'))
W.scene=true
run(g,2)
assert(g.cutscene_playing() and W.finds.SBTheaterLevelSequenceObserver==2)
W.scene=false
run(g,3)
assert(not g.cutscene_playing() and W.finds.SBTheaterLevelSequenceObserver==3)
first.Player=nil
W.scene,W.observers=true,{observer('Mann_Exit',scene)}
run(g,1)
assert(g.cutscene_playing() and logged('cutscene on: Mann_Exit') and W.finds.SBTheaterLevelSequenceObserver==4)
-- After a map change a freed address may hold another sequence actor: the new map's theater actor at the address of
-- the last set's only one is a new set, walked for.
local theater=uobject('LevelSequenceActor /Game/MapB.MapB:PersistentLevel.Theater',{SequencePlayer=scene})
g=world(function(w)
    w.mode,w.life,w.scene='host',{state=1,hp=1600},true
    w.sequences={uobject('LevelSequenceActor /Game/Map.Map:PersistentLevel.Lift_Loop',{SequencePlayer=loop})}
end)
run(g,1)
assert(not g.cutscene_playing() and W.finds.SBTheaterLevelSequenceObserver==1)
theater.GetAddress=W.sequences[1].GetAddress
W.sequences,W.observers={theater},{observer('Mann_Entrance',scene)}
run(g,1)
assert(g.cutscene_playing() and W.finds.SBTheaterLevelSequenceObserver==2,'Same address, another actor: '
    ..W.finds.SBTheaterLevelSequenceObserver)
-- The observer kept is not read again once its cutscene ended (the collector may free it), nor after a map change (the
-- map frees it), even when it played at the last read: a read of one freed here errors, which turns the read off.
local function freed(ob) ob.IsValid=function() error('a freed observer was read',0) end end
local ended,last_one=observer('Mann_Entrance',scene),observer('Mann_Exit',scene)
g=world(function(w)
    w.mode,w.life,w.scene='host',{state=1,hp=1600},true
    w.observers,w.sequences={ended},sequences()
end)
run(g,1)
W.scene=false
run(g,1)
assert(logged('cutscene off') and not g.cutscene_playing())
freed(ended)
run(g,2)
assert(not logged('off for this run'),'Read after its end: '..table.concat(W.logs,'|'))
W.scene,W.observers=true,{last_one}
run(g,1)
assert(g.cutscene_playing() and logged('cutscene on: Mann_Exit'))
freed(last_one)
W.world,W.scene,W.observers=uobject('World /Game/MapB.MapB',{}),false,{}
run(g,2)
assert(not g.cutscene_playing() and not logged('off for this run'),'Read after a map change: '
    ..table.concat(W.logs,'|'))
-- No EVE (the title screen, a load): the class hash takes our SB controller's world (the hash's proof is asked); with
-- no controller either, no sequence actor is looked up at all (actors_of with no world walks every object).
local probe=package.loaded['core.player']
g=world(function(w)
    w.mode,w.life,w.scene,w.eve='host',{state=1,hp=1600},false,nil
    w.observers,w.sequences={observer('Mann_Entrance',scene)},sequences()
end)
run(g,1)
assert(W.finds.PlayerController==1 and W.finds.LevelSequenceActor==1,'The controller is the world')
probe.controller=function() return nil end
run(g,3)
probe.controller=function() return pc end
assert(not g.cutscene_playing() and W.finds.LevelSequenceActor==1 and W.finds.PlayerController==1
    and (W.finds.SBTheaterLevelSequenceObserver or 0)==0,'No world, no walk: '..W.finds.LevelSequenceActor)
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

-- Three players. Down, with Kaanta (slot 0) on another map and Lucas (slot 1) alive 1 m away: Lucas revives, named in
-- the wait, the call and the revived notices. Lucas far too: the wait names him, as the member alive on our map;
-- no call. Lucas down as well: no member alive.
local THREE={{id='2',slot=0,linked=true,name='Kaanta'},{id='3',slot=1,linked=true,name='Lucas'}}
g=world(function(w)
    w.members,w.her_map,w.vits=THREE,'/game/f02',{['3']={life=1,hp=500,max_hp=1600}}
    w.ghosts={[1]={map='/game/e04',feet={X=1100,Y=2000,Z=300}}}
    w.respawn=function() w.life={state=1,hp=1600} end
end)
run(g,0.25)
assert(W.said[1]=='Lucas can revive you: wait, or respawn at a camp.',W.said[1])
run(g,3)
assert(#W.calls==1 and logged('asked (Lucas 1.0 m away; life 3'),table.concat(W.logs,'|'))
run(g,2)
assert(logged('revive result (Lucas): life 3/1') and W.said[2]=='Revived by Lucas.',table.concat(W.said,'|'))
g=world(function(w)
    w.members,w.her_map,w.vits=THREE,'/game/f02',{['3']={life=1,hp=500,max_hp=1600}}
    w.ghosts={[1]={map='/game/e04',feet={X=9000,Y=2000,Z=300}}}
end)
run(g,4)
assert(#W.calls==0 and W.said[1]=='Lucas can revive you: wait, or respawn at a camp.' and logged('revive waits: friend far'))
g=world(function(w)
    w.members,w.mate,w.vits=THREE,{life=3,hp=0,max_hp=1600},{['3']={life=4,hp=0,max_hp=1600}}
    w.ghosts={[1]={map='/game/e04',feet={X=1100,Y=2000,Z=300}}}
end)
run(g,4)
assert(#W.calls==0 and logged('revive waits: friend not alive'))
-- Each member's down notice once per death of hers, on our map; our revive of her, named; one on another map unsaid.
g=world(function(w)
    w.mode,w.life,w.members=w.mode,{state=1,hp=1600},{THREE[1],THREE[2],{id='4',slot=2,linked=true,name='Mo'}}
    w.vits={['3']={life=3,hp=0,max_hp=1600},['4']={life=3,hp=0,max_hp=1600}}
    w.ghosts={[1]={map='/game/e04',feet={X=1100,Y=2000,Z=300}},[2]={map='/game/f02',feet={X=0,Y=0,Z=0}}}
end)
run(g,2)
assert(#W.said==1 and W.said[1]=='Lucas is down. Stand next to them for 3 s to revive them.',table.concat(W.said,'|'))
W.vits['3']={life=1,hp=1600,max_hp=1600}
run(g,0.25)
assert(#W.said==2 and W.said[2]=='You revived Lucas.',table.concat(W.said,'|'))
-- In an online session only the host and the pair can be revived (their shared fight gives boss=0): on the host and
-- on the pair, a guest outside the pair who goes down is never said down, nor revived by us when she is up again;
-- the other one of the pair is. Her own game waits on 'no shared fight', with no wait notice and no call.
local CARA={id='3',slot=1,linked=true,name='Cara'}
for _,side in ipairs({{mode='host',members={THREE[1],CARA}},
        {mode='guest',members={{id='1',slot=0,linked=true,name='Kaanta'},CARA}}}) do
    g=world(function(w)
        w.mode,w.life,w.members,w.host=side.mode,{state=1,hp=1600},side.members,{id='1',pair='2'}
        w.mate,w.vits={life=1,hp=1600,max_hp=1600},{['3']={life=3,hp=0,max_hp=1600}}
        w.ghosts={[1]={map='/game/e04',feet={X=1100,Y=2000,Z=300}}}
    end)
    run(g,2)
    W.vits['3']={life=1,hp=1600,max_hp=1600}
    run(g,1)
    assert(#W.said==0,side.mode..': '..table.concat(W.said,'|'))
    W.mate={life=3,hp=0,max_hp=1600}
    run(g,0.25)
    assert(#W.said==1 and W.said[1]=='Kaanta is down. Stand next to them for 3 s to revive them.',W.said[1])
end
g=world(function(w)
    w.host,w.fight=({id='1',pair='2'}),'fight=waiting mode=on why=no friend linked'
    w.members={{id='1',slot=0,linked=true,name='Kaanta'},{id='2',slot=1,linked=true,name='Ana'}}
end)
run(g,4)
assert(#W.calls==0 and #W.said==0 and logged('revive waits: no shared fight'),table.concat(W.said,'|'))
-- The guest's pause: the host's ghost is the one of his member line's slot.
g=world(function(w)
    w.life,w.host,w.her_map={state=1,hp=1600},{id='5'},'/game/f02'
    w.members={THREE[1],{id='5',slot=2,linked=true,name='Host'}}
    w.ghosts={[2]={map='/game/e04',feet={X=0,Y=0,Z=0}}}
end)
assert(g.cut()==true)
W.ghosts[2].map='/game/f02'
assert(g.cut()==false)
-- SB's theater from the status line (glue/tick/theater_game.inc): the theater= field gives the cutscene with no
-- sequence actor list and no walk; theater=none ends it; theater=fault reads the actors as before.
g=world(function(w)
    w.mode,w.life,w.engine='host',{state=1,hp=1600},ENGINE..' warp=idle me=4242 theater=none'
end)
run(g,2)
assert(not g.cutscene_playing() and (W.finds.SBTheaterLevelSequenceObserver or 0)==0
    and (W.finds.LevelSequenceActor or 0)==0,'No actor list, no walk')
W.engine=ENGINE..' warp=idle me=4242 theater=Mann_Entrance_0123456789ABCDEF0123456789ABCDEF'
run(g,1)
assert(g.cutscene_playing() and g.photo('0')=='c' and logged('cutscene on: Mann_Entrance_0123456789ABCDEF'))
W.engine=ENGINE..' warp=idle me=4242 theater=none'
run(g,1)
assert(not g.cutscene_playing() and logged('cutscene off') and (W.finds.LevelSequenceActor or 0)==0
    and (W.finds.SBTheaterLevelSequenceObserver or 0)==0)
W.engine=ENGINE..' warp=idle me=4242 theater=fault'
run(g,1)
assert((W.finds.LevelSequenceActor or 0)>0,'A faulted read: the actors as before')

local COOP='slot=coop index=1 marker=1 saves=coop'
local BACK='Kaanta is alive. Press F7 to go back to them.'
local function far(w) w.slot=COOP; w.ghost={X=3000,Y=2000,Z=300} end -- The host alive on our map, 20 m away.
local function respawns()
    local n=0
    for _,c in ipairs(W.calls) do if c==RESPAWN then n=n+1 end end
    return n
end
-- The offer once per death; back() makes the in-place respawn call, then go() to the host (slot 0's member, no host
-- line) once up and idle.
g=world(far); run(g,0.5)
assert(W.said[#W.said]==BACK and #W.calls==0,table.concat(W.said,'|'))
run(g,5); assert(#W.said==2,'Once per death (the wait notice, then the offer)')
assert(g.back()==true and #W.calls==1 and W.calls[1]==RESPAWN)
W.life={state=1,hp=1600}; run(g,0.25)
assert(#W.gone==1 and W.gone[1]=='2')
run(g,2); assert(#W.gone==1,'Once')
for _,s in ipairs(W.said) do assert(s~=REVIVED,'Nobody revived us') end
assert(g.back()==nil,'No offer: F7 is the follow again')
-- The revive's guards first: a game that is not standalone gets no call.
g=world(function(w) far(w); w.standalone=false end); run(g,0.5)
local ok,why=g.back()
assert(ok==false and why=='the game is not standalone' and #W.calls==0
    and logged('return refused: the game is not standalone'))
-- one call per death (Review Focus 5): the friend's 3 s revive first, then back() has no offer and no warp follows;
-- back() first, then the friend's revive makes no second call.
g=world(function(w) w.slot=COOP end); run(g,3.5)
assert(respawns()==1 and g.back()==nil); W.life={state=1,hp=1600}; run(g,1); assert(#W.gone==0)
g=world(function(w) w.slot=COOP; w.respawn=function() w.life={state=1,hp=1600} end end); run(g,2)
assert(g.back()==true); run(g,2); assert(respawns()==1 and #W.gone==1)
-- target gone (Review Focus 3): after the call the host leaves, goes down or enters a solo area: no warp, one line.
for _,change in ipairs({function() W.members={}; W.mate=nil end,function() W.mate.life=3; W.mate.hp=0 end,
    function() W.mate.zone=5 end}) do
    g=world(far); run(g,0.5); assert(g.back()==true)
    change(); W.life={state=1,hp=1600}; run(g,0.5)
    assert(#W.gone==0 and #W.calls==1 and logged('return: no warp, '),table.concat(W.logs,'|'))
end
-- Down again within 10 s of the in-place respawn: no offer for that death.
g=world(far); run(g,0.5); g.back()
W.life={state=1,hp=1600}; run(g,0.5); W.life={state=3,hp=0}; run(g,1)
local backs=0
for _,s in ipairs(W.said) do if s==BACK then backs=backs+1 end end
assert(backs==1,'No offer for a death within 10 s of the in-place respawn')
-- No offer: the host on another map, a boss fight, no shared fight, a Night Operation run, revive=off, the host in a
-- solo area, we in one, no co-op save, follow_key=none, follow_host=off.
for _,change in ipairs({function(w) w.her_map='/game/other' end,function(w) w.fight=w.fight:gsub('boss=0','boss=1') end,
    function(w) w.fight=nil end,function(w) w.night=true end,function(w) w.settings.revive=false end,
    function(w) w.mate.zone=5 end,function(w) w.zonetype=5 end,function(w) w.slot=nil end,function(w) w.settings.follow_key={name='none'} end,
    function(w) w.settings.follow_host='off' end}) do
    g=world(function(w) far(w); change(w) end); run(g,1)
    for _,s in ipairs(W.said) do assert(s~=BACK) end
    assert(g.back()==nil)
end
assert(logged('return: no notice (follow_host=off)'))
g=world(function(w) far(w); w.settings.follow_key={name='none'} end); run(g,1)
assert(logged('return: no notice (follow_key=none)') and g.back()==nil,'No notice: no return either')
-- always: the call 5 s after the notice; back() within the 5 s cancels.
g=world(function(w) far(w); w.settings.follow_host='always' end); run(g,0.5)
assert(W.said[#W.said]=='Going back to Kaanta in 5 s. Press F7 to stay.'); run(g,5); assert(#W.calls==1)
g=world(function(w) far(w); w.settings.follow_host='always' end); run(g,0.5)
assert(select(2,g.back())=='return cancelled'); run(g,6); assert(#W.calls==0)
-- The host's death: the living guest on his map nearest his EVE (member 3 at 10 m before member 2 at 30 m).
g=world(function(w) w.mode='host'; w.slot=COOP
    w.members={{id='2',slot=0,linked=true},{id='3',slot=1,linked=true}}
    w.ghost={X=4000,Y=2000,Z=300}
    w.ghosts={[1]={map='/game/e04',feet={X=2000,Y=2000,Z=300}}}
    w.vits={['3']={life=1,hp=900,max_hp=1600,zone=1}} end)
run(g,0.5); assert(g.back()==true); W.life={state=1,hp=1600}; run(g,0.5)
assert(W.gone[1]=='3',tostring(W.gone[1]))
-- The warp waits while the game is paused (a menu, photo mode), 10 s at most after our EVE is up.
g=world(far); run(g,0.5); g.back(); W.paused=true; W.life={state=1,hp=1600}; run(g,1); assert(#W.gone==0)
W.paused=false; run(g,0.25); assert(#W.gone==1)
g=world(far); run(g,0.5); g.back(); W.paused=true; W.life={state=1,hp=1600}; run(g,9.75); assert(#W.gone==0)
run(g,0.5); assert(#W.gone==1,'Paused 10 s: the warp is asked, its own guards refuse it')
-- A return whose respawn and fallback both leave our life at 3: the fallback under the return's guards, then no warp
-- once SB's own camp respawn gets her up.
g=world(far); run(g,0.5); g.back(); run(g,4.5)
assert(W.calls[2]==REVIVAL and logged('return: no warp, the respawn did not take'),table.concat(W.logs,'|'))
W.life={state=1,hp=1600}; run(g,1); assert(#W.gone==0)
-- Solo notices for the others: in, back; none for ourselves.
g=world(function(w) w.life={state=1,hp=1600} end)
W.mate.zone=5; run(g,0.25)
assert(W.said[#W.said]=='Kaanta is in a Boss Challenge. Online play waits until they are back.')
-- vitals gap (Review Focus 4): no vitals for 3 s, then the same type: no back, no second notice.
local n=#W.said; local m=W.mate; W.mate=nil; run(g,3); W.mate=m; run(g,0.5); assert(#W.said==n)
W.mate.zone=1; run(g,0.25); assert(W.said[#W.said]=='Kaanta is back.')
W.zonetype=2; run(g,0.5); assert(W.said[#W.said]=='Kaanta is back.','Our own stay says nothing to us')
-- The revive and the cutscene wait leave a member in a solo area out.
g=world(function(w) w.mate.zone=6 end); run(g,4); assert(#W.calls==0 and logged('revive waits: friend in a solo area'))
g=world(function(w) w.zonetype=3 end); run(g,4); assert(#W.calls==0 and logged('revive waits: solo area'))
g=world(function(w) w.mode='guest'; w.life={state=1,hp=1600}; w.mate.zone=5 end); assert(g.cut()==false)
g=world(function(w) w.mode='guest'; w.life={state=1,hp=1600}; w.zonetype=5 end)
assert(g.cut()==false,'No pause for his cutscene while we stand in a solo area')
-- Her down notice: none while she or we stand in a solo area.
g=world(function(w) w.mode,w.life,w.mate='host',{state=1,hp=1600},{life=3,hp=0,max_hp=1600,zone=5} end); run(g,2)
for _,s in ipairs(W.said) do assert(s~=DOWN,'No down notice for a member in a solo area') end
g=world(function(w) w.mode,w.life,w.mate,w.zonetype='host',{state=1,hp=1600},{life=3,hp=0,max_hp=1600,zone=1},5 end)
run(g,2)
for _,s in ipairs(W.said) do assert(s~=DOWN,'No down notice while we stand in a solo area') end
-- Camp rests (shared_world=on, a co-op save, alive in Zone_A, the engine line's rest counts at 0).
local function ready(w) w.slot=COOP; w.life={state=1,hp=1600}; w.settings.shared_world=true; w.area='Zone_A'
    w.names={Zone_A=55}; w.rest='rest=0:none:0 starts=0' end
-- Sending: the baseline never sends; our rest (type 1) sends rest <area>; type 2 only after 10 s alive; nothing with
-- shared_world=off or in a solo area of ours.
g=world(function(w) ready(w); w.rest='rest=4:Zone_A:1 starts=9' end); run(g,0.5); assert(#W.requests==0,'The baseline')
W.rest='rest=5:Zone_A:1 starts=10'; run(g,0.25); assert(W.requests[1]=='rest Zone_A')
g=world(ready); run(g,5); W.rest='rest=1:Zone_A:2 starts=1'; run(g,0.25); assert(#W.requests==0,'Type 2 within 10 s')
run(g,6); W.rest='rest=2:Zone_A:2 starts=2'; run(g,0.25); assert(W.requests[1]=='rest Zone_A')
for _,change in ipairs({function(w) w.settings.shared_world=false end,function(w) w.zonetype=5 end}) do
    g=world(function(w) ready(w); change(w) end); run(g,0.25)
    W.rest='rest=1:Zone_A:1 starts=1'; run(g,0.25); assert(#W.requests==0)
end
-- Applying: our area, alive, standalone: one ResetZone call with our GUID and the zone, the rested notice with the
-- member line's name; a SteamID with no member line reads A player.
g=world(ready); g.rest('Zone_A','2'); run(g,0.25)
assert(#W.resets==1 and W.resets[1].guid==4242 and W.resets[1].zone=='Zone_A')
assert(W.said[#W.said]=='Kaanta rested at a camp. The enemies of this area are back.')
g=world(ready); g.rest('Zone_A','77'); run(g,0.25)
assert(W.said[#W.said]=='A player rested at a camp. The enemies of this area are back.')
-- echo (Review Focus 1): after our call, SB's own type-2 start (GUID 0) moves starts only: no rest line and no stop
-- notice. Our own edge within 10 s of the call (the guard): not sent, its log line.
g=world(ready); run(g,11); g.rest('Zone_A','2'); run(g,0.25)
assert(#W.resets==1)
W.rest='rest=0:none:0 starts=1'; run(g,1)
assert(#W.requests==0 and W.said[#W.said]=='Kaanta rested at a camp. The enemies of this area are back.')
W.rest='rest=1:Zone_A:2 starts=2'; run(g,0.25)
assert(#W.requests==0 and logged('rest: our own reset within 10 s of a ResetZone call, not sent'))
-- Players resting together: 4 rests for Zone_A within 5 s give one call and no stop notice; our own rest of Zone_A
-- leaves none to apply.
g=world(ready)
for _,id in ipairs({'2','3','4','5'}) do g.rest('Zone_A',id); run(g,1.25) end
assert(#W.resets==1 and logged('rest: Zone_A already reset') and not W.said[#W.said]:find('no longer',1,true))
g=world(ready); run(g,0.25); W.rest='rest=1:Zone_A:1 starts=1'; run(g,0.25); g.rest('Zone_A','2'); run(g,0.25)
assert(#W.requests==1 and #W.resets==0,'Our own rest already reset Zone_A')
-- Another area: nothing. A name the game does not hold: dropped. Our zone type solo: not applied. No fight read in
-- this game: dropped, log only.
g=world(function(w) ready(w); w.area='Zone_B' end); g.rest('Zone_A','2'); run(g,0.25); assert(#W.resets==0 and #W.said==0)
g=world(function(w) ready(w); w.area='Zone_C' end); g.rest('Zone_C','2'); run(g,0.25)
assert(#W.resets==0 and logged('rest: Zone_C is not a name'))
g=world(function(w) ready(w); w.zonetype=5 end); g.rest('Zone_A','2'); run(g,1); assert(#W.resets==0)
g=world(function(w) ready(w); w.fight='fight=waiting mode=on' end); g.rest('Zone_A','2'); run(g,1)
assert(#W.resets==0 and #W.said==0 and logged('rest: no fight read in this game'))
-- Busy: applied once free; busy for 60 s (a cutscene): skipped with its notice; the session ends: the queue goes.
g=world(function(w) ready(w); w.fight=w.fight:gsub('battle=0','battle=2') end)
g.rest('Zone_A','2'); run(g,20); assert(#W.resets==0)
W.fight=W.fight:gsub('battle=2','battle=0'); run(g,1); assert(#W.resets==1)
g=world(function(w) ready(w); w.scene=true; w.observers,w.sequences={observer('Mann_Entrance',scene)},sequences() end)
g.rest('Zone_A','2'); run(g,61)
assert(#W.resets==0 and W.said[#W.said]=='Kaanta rested at a camp. This area did not reset in your game: you were busy for a minute.')
g=world(function(w) ready(w); w.fight=w.fight:gsub('battle=0','battle=2') end)
g.rest('Zone_A','2'); run(g,2); W.linked=false; run(g,1)
assert(#W.resets==0 and logged('rest: dropped, the session ended'))
-- Stop latch: 4 starts within 30 s after a call: the next rest (another zone) is not applied.
g=world(function(w) ready(w); w.names={Zone_A=55,Zone_B=56} end); run(g,0.25); g.rest('Zone_A','2'); run(g,0.25)
W.rest='rest=0:none:0 starts=4'; run(g,5); W.area='Zone_B'; g.rest('Zone_B','2'); run(g,1)
assert(#W.resets==1 and W.said[#W.said]=="Other players' camp rests no longer reset your area until the game restarts. UE4SS.log says why.")
-- The same 4 starts more than 30 s after the call: the calls go on.
g=world(function(w) ready(w); w.names={Zone_A=55,Zone_B=56} end); run(g,0.25); g.rest('Zone_A','2'); run(g,31)
W.rest='rest=0:none:0 starts=4'; run(g,1); W.area='Zone_B'; g.rest('Zone_B','2'); run(g,1)
assert(#W.resets==2 and W.said[#W.said]=='Kaanta rested at a camp. The enemies of this area are back.','Past 30 s')
-- Our own rest is not sent without a session, off a co-op save or with no area read; each with its log line.
for _,c in ipairs({{'no session',function(w) w.linked=false end},{'not a co-op save',function(w) w.slot=nil end}}) do
    g=world(function(w) ready(w); c[2](w) end); run(g,0.25)
    W.rest='rest=1:Zone_A:1 starts=1'; run(g,0.25)
    assert(#W.requests==0 and logged('rest: our own reset of Zone_A not sent: '..c[1]),c[1])
end
g=world(ready); run(g,0.25); W.rest='rest=1:none:1 starts=1'; run(g,0.25)
assert(#W.requests==0 and logged('rest: our own reset of none not sent: no area read'))
-- A received rest is dropped, its log line and no notice even after a minute: shared_world=off, off a co-op save, no
-- life read, a game that is not standalone.
local function rest_said()
    for _,s in ipairs(W.said) do if s:find('rested at a camp',1,true) then return s end end
end
for _,c in ipairs({{'shared_world=off',function(w) w.settings.shared_world=false end},
    {'not a co-op save',function(w) w.slot=nil end},{'no life read',function(w) w.life=nil end},
    {'the game is not standalone',function(w) w.standalone=false end}}) do
    g=world(function(w) ready(w); c[2](w) end); g.rest('Zone_A','2'); run(g,61)
    assert(#W.resets==0 and not rest_said() and logged('rest: '..c[1]..' (Zone_A of member 2 dropped)'),c[1])
end
-- It waits, its log line and no call, while the game is paused, with no EVE, a respawn or warp, no GUID read, our EVE
-- down or a boss fight; the call comes once that ends.
for _,c in ipairs({{'the game is paused',function(w) w.paused=true end,function(w) w.paused=false end},
    {'no EVE',function(w) w.eve=nil end,function(w) w.eve=eve end},
    {'a respawn or a warp',function(w) w.engine=ENGINE..' warp=busy me=4242' end,
        function(w) w.engine=ENGINE..' warp=idle me=4242' end},
    {'no GUID',function(w) w.engine=ENGINE..' warp=idle me=0' end,
        function(w) w.engine=ENGINE..' warp=idle me=4242' end},
    {'down',function(w) w.life={state=3,hp=0} end,function(w) w.life={state=1,hp=1600} end},
    {'a fight',function(w) w.fight=GUEST..'7' end,function(w) w.fight=GUEST..'0' end}}) do
    g=world(function(w) ready(w); c[2](w) end); g.rest('Zone_A','2'); run(g,30)
    assert(#W.resets==0 and not rest_said() and logged('rest: Zone_A waits: '..c[1]),c[1])
    c[3](W); run(g,1)
    assert(#W.resets==1 and W.resets[1].guid==4242 and rest_said()=='Kaanta rested at a camp. The enemies of this area '
        ..'are back.',c[1]..', then free')
end
-- One rest waits per zone: another for that zone is dropped with its log line. A rest that waits is dropped once our
-- own rest reset its zone meanwhile (players resting together at a camp, the camp's menu open).
g=world(function(w) ready(w); w.paused=true end); g.rest('Zone_A','2'); g.rest('Zone_A','3'); run(g,1)
assert(logged('rest: Zone_A already waits, member 3 dropped'))
W.paused=false; run(g,1); assert(#W.resets==1)
g=world(function(w) ready(w); w.paused=true end); run(g,0.25); g.rest('Zone_A','2'); run(g,2)
W.rest='rest=1:Zone_A:1 starts=1'; run(g,0.25); W.paused=false; run(g,1)
assert(#W.requests==1 and #W.resets==0 and logged('rest: Zone_A already reset'),'Our own rest while hers waited')
print('group_test ok')
