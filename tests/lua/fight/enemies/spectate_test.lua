-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- fight/enemies/spectate.lua over fakes of the link, the controller, core/actors.lua and core/unreal.lua: the camera
-- (made at spec=1 after an earlier Lua load's is swept, the view taken from our pawn only and given back from our
-- camera only, its place each frame, over our EVE with no ghost anchor), the respawn once per reason with its fallback
-- 2 s later (the wait stopped while the fight= line reads waiting, refused with one log line), the native fault's
-- fallback, the switch, the two notices and coop spectate test. Members by link id: Ana id 7 slot 0, Bo id 9 slot 1.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local T=require('ui.text')
local W -- One case's world.
local eve={K2_GetActorLocation=function() return W.at end,GetWorld=function() return 'world' end}
local theater={} -- A theater's camera actor.
local cam_actor,old_cam={},{}
local pc={GetViewTarget=function() return W.view end,
    SetViewTargetWithBlend=function(_,target,blend,f,e,lock)
        W.views[#W.views+1]={target=target,blend=blend,f=f,e=e,lock=lock}
        W.view=target
    end,
    ServerRequest_ActorRespawn=function(_,guid,warp)
        W.calls[#W.calls+1]=string.format('respawn %d %s',guid,tostring(warp))
        if W.respawn then W.respawn() end
    end,
    ServerRequest_ActorRevival=function(_,guid,item)
        W.calls[#W.calls+1]=string.format('revival %d %s',guid,tostring(item))
    end}
local function ghost(k)
    return {anchor=function()
        local f=W.anchors[k]
        if f then return {X=f.X,Y=f.Y,Z=f.Z+100},f end
    end,her_map=function() return W.maps[k] end}
end
local function fake_link()
    return {fight=function() return W.fight end,
        status=function() return W.engine and 'mod=v proto=3\n'..W.engine..'\nlast=#1 ready\n' or nil end,
        life=function() return W.life end,mode=function() return W.mode end,members=function() return W.members end,
        member=function(id) for _,m in ipairs(W.members) do if m.id==id then return m end end end,
        host=function() return W.host end,mate=function() return W.mate end,vitals=function(id) return W.vitals[id] end,
        request=function(line) W.requests[#W.requests+1]=line; return true,'asked the native part: '..line end,
        store=function(name)
            assert(name=='coop-spectate.txt',name)
            return {save=function(p) W.stored=p; return true end,load=function() return W.stored end,
                clear=function() W.stored=nil end}
        end}
end
local function cam_mesh()
    return {K2_SetWorldLocationAndRotation=function(_,at,rot,sweep,hit,teleport)
        assert(sweep==false and teleport==false)
        W.moves[#W.moves+1]={at=at,rot=rot}
    end}
end
local actors={
    spawn=function(world,at,rot,look)
        assert(world=='world' and look.camera==true and at and rot)
        W.spawned[#W.spawned+1]={at=at,rot=rot}
        return {actor=cam_actor,path='cam path',mesh=cam_mesh()}
    end,
    same=function(o,path)
        if o==cam_actor and path=='cam path' and not W.cam_gone then return o end
        if o==old_cam and path=='old path' then return o end
    end,
    sweep=function(p,kind) W.swept[#W.swept+1]=p..' '..kind; return W.old_exists end}
local kismet={IsStandalone=function(_,p) assert(p==pc); return W.standalone end}
local unreal={valid=function(o) return o end,address=function(o) return o end,value_of=function(v) return v end,
    map_of=function(a) assert(a==eve); return W.map end,
    find=function(path) assert(path=='/Script/Engine.Default__KismetSystemLibrary',path); return kismet end,
    -- Lua hides no widget: no death screen is ever looked up.
    death_screen=function() error('spectate touched the death screen widget') end}
local player={her=function() return W.eve end,controller=function() return pc end}
local ENGINE='engine=on reason=pinned build 26123051 warp=idle me=228 spectate=on hud=1'
local function world(change)
    W={fight=nil,engine=ENGINE,life={state=3,hp=0},mode='host',host={id=1,pair=7},
        members={{id=7,name='Ana',slot=0,linked=true}},mate={life=1,hp=900},vitals={},
        anchors={[0]={X=1000,Y=0,Z=0}},maps={[0]='/game/e04'},map='/game/e04',at={X=0,Y=0,Z=0},eve=eve,view=eve,
        standalone=true,calls={},views={},logs={},told={},spawned={},swept={},requests={},moves={}}
    if change then change(W) end
    return require('fight.enemies.spectate').new({link=fake_link(),settings={spectate=true},
        log=function(m) W.logs[#W.logs+1]=m end,tell=function(build) W.told[#W.told+1]=build(T.en) end,
        name=function(w,name) return name or w.fight.friend end,puppet=ghost(0),
        ghost=function(k) return k>0 and ghost(k) or nil end,actors=actors,player=player,unreal=unreal})
end
-- The fight= line with spectate's words, as fight::Worker writes them.
local function line(on,watch,upn,her,mem,head)
    return (head or 'fight=on mode=on role=host enemies=1 boss=1')..(on and ' spec=1 watch='..(watch or '-')
        or ' spec=0 watch=-')..' up=- upn='..(upn or 0)..' her_spec='..(her or '-')..' mem='..(mem or 0)
end
local function logged(text,from)
    local n=0
    for i=(from or 0)+1,#W.logs do if W.logs[i]:find(text,1,true) then n=n+1 end end
    return n
end
local SPECTATE='You are down. Watching Ana. You get up when the boss falls or reaches its next phase.'

do -- enter: an earlier Lua load's camera swept, one camera, the view taken once, one notice.
    local s=world(function(w) w.stored='old path'; w.old_exists=true end)
    W.fight=line(true,1,0)
    s.tick(0)
    assert(W.swept[1]=='old path camera' and #W.swept==1,table.concat(W.swept,'|'))
    assert(#W.spawned==1 and W.stored=='cam path','One camera, its path kept for the next Lua load')
    local v=W.views[1]
    assert(#W.views==1 and v.target==cam_actor and v.blend==0.5 and v.f==0 and v.e==0 and v.lock==false)
    assert(#W.told==1 and W.told[1]==SPECTATE,tostring(W.told[1]))
    assert(s.watching()==true and s.status():find('watching Ana',1,true),s.status())
    s.tick(0.25); s.tick(0.5)
    assert(#W.spawned==1 and #W.views==1 and #W.told==1 and #W.swept==1,'Once')
end
do -- An earlier Lua load's camera that holds the view gives it back on our EVE before its sweep.
    world(function(w) w.stored='old path'; w.view=old_cam; w.old_exists=true end).tick(0)
    assert(W.views[1].target==eve and W.views[1].blend==0 and W.swept[1]=='old path camera' and W.stored==nil)
end
do -- theater_kept: a theater's camera keeps the view on both edges.
    local s=world(function(w) w.view=theater end)
    W.fight=line(true,1,0)
    s.tick(0)
    assert(#W.spawned==1 and #W.views==0,'No SetViewTargetWithBlend while a theater has the view')
    s.tick(0.25); assert(#W.views==0)
    W.view=eve
    s.tick(0.5)
    assert(#W.views==1 and W.views[1].target==cam_actor and W.views[1].blend==0.5,'Taken once the theater ended')
    s.tick(0.75); assert(#W.views==1)
    W.view,W.fight=theater,line(false)
    s.tick(1); s.tick(1.25)
    assert(#W.views==1 and W.view==theater,'No call back to the pawn from a theater camera')
end
do -- frame: 400 cm from her feet toward our EVE, 160 cm up, aimed at 130 cm above her feet; it keeps its direction.
    local s=world()
    W.fight=line(true,1,0)
    s.tick(0); s.frame()
    local m=W.moves[#W.moves]
    assert(m.at.X==600 and m.at.Y==0 and m.at.Z==160,string.format('%s %s %s',m.at.X,m.at.Y,m.at.Z))
    assert(m.rot.Yaw==0 and m.rot.Roll==0 and string.format('%.2f',m.rot.Pitch)=='-4.29',m.rot.Pitch)
    W.anchors[0]={X=1000,Y=500,Z=0}
    s.frame()
    m=W.moves[#W.moves]
    assert(m.at.X==600 and m.at.Y==500 and m.at.Z==160,string.format('%s %s %s',m.at.X,m.at.Y,m.at.Z))
    W.fight=line(false); s.tick(0.25)
    local n=#W.moves
    s.frame(); assert(#W.moves==n,'No move once spectate is off')
    -- The next spectate takes its direction again, from her feet toward our EVE.
    W.anchors[0]={X=0,Y=1000,Z=0}
    W.fight=line(true,1,0); s.tick(0.5); s.frame()
    m=W.moves[#W.moves]
    assert(m.at.X==0 and m.at.Y==600 and m.at.Z==160,string.format('%s %s %s',m.at.X,m.at.Y,m.at.Z))
end
do -- one_call_per_upn (Review Focus 2): one respawn per reason, the revival once 2 s later while life did not move.
    local s=world()
    W.fight=line(true,1,0); s.tick(0)
    W.fight=line(true,1,1); s.tick(0.25)
    assert(#W.calls==1 and W.calls[1]=='respawn 228 false',table.concat(W.calls,'|'))
    assert(logged('ServerRequest_ActorRespawn(228, false) asked (reason 1; life 3)')==1,table.concat(W.logs,'|'))
    s.tick(0.5); s.tick(0.75)
    assert(#W.calls==1,'The same reason makes no second call')
    for t=1,2,0.25 do s.tick(t) end
    assert(#W.calls==1,'Before 2 s: no revival')
    s.tick(2.25)
    assert(#W.calls==2 and W.calls[2]=='revival 228 false',table.concat(W.calls,'|'))
    for t=2.5,5,0.25 do s.tick(t) end
    assert(#W.calls==2,'Once')
    W.fight=line(true,1,2); s.tick(5.25)
    assert(#W.calls==3 and W.calls[3]=='respawn 228 false','A new reason: one more call')
    -- Up within the 2 s: no revival.
    W.life={state=1,hp=900}; s.tick(5.5)
    W.life={state=3,hp=0}
    for t=5.75,8,0.25 do s.tick(t) end
    assert(#W.calls==3,'Up in between: no revival')
    -- From Coma (life 2).
    s=world(function(w) w.life={state=2,hp=0} end)
    W.fight=line(true,1,0); s.tick(0)
    W.fight=line(true,1,1); s.tick(0.25)
    assert(#W.calls==1 and W.calls[1]=='respawn 228 false','Life 2 too')
    -- Its life moved to 3 (the Coma ended in death): no revival.
    W.life={state=3,hp=0}
    for t=0.5,3,0.25 do s.tick(t) end
    assert(#W.calls==1,'Life moved: no revival')
    -- A Lua load that first reads upn 3 makes no call for it.
    s=world()
    W.fight=line(true,1,3); s.tick(0); s.tick(0.25)
    assert(#W.calls==0,'The first read is the baseline')
end
do -- paused: the 2 s wait stops while the fight= line reads waiting.
    local s=world()
    W.fight=line(true,1,0); s.tick(-0.25)
    W.fight=line(true,1,1); s.tick(0)
    assert(#W.calls==1)
    s.tick(0.25)
    W.fight=line(true,1,1,nil,nil,'fight=waiting mode=on her=on')
    for t=0.5,9.75,0.25 do s.tick(t) end
    W.fight=line(true,1,1)
    for t=10,11.25,0.25 do s.tick(t) end
    assert(#W.calls==1,'No revival before +11.5 s: '..table.concat(W.calls,'|'))
    s.tick(11.5)
    assert(#W.calls==2 and W.calls[2]=='revival 228 false',table.concat(W.calls,'|'))
end
do -- refused: no call, one log line each naming the reason.
    for _,case in ipairs({{function(w) w.engine=ENGINE:gsub('warp=idle','warp=busy') end,'a respawn or a warp'},
            {function(w) w.engine=ENGINE..' nightop=rule' end,'a coop no probe rule'},
            {function(w) w.standalone=false end,'the game is not standalone'},
            {function(w) w.life={state=4,hp=0} end,'life 4'}}) do
        local s=world(case[1])
        W.fight=line(true,1,0); s.tick(0)
        W.fight=line(true,1,1); s.tick(0.25); s.tick(0.5)
        for t=0.75,3,0.25 do s.tick(t) end
        assert(#W.calls==0 and logged('no respawn (reason 1): '..case[2])==1 and logged('no respawn')==1,
            case[2]..': '..table.concat(W.logs,'|'))
    end
end
do -- leave: the view back on our pawn once, the camera kept for the next time.
    local s=world()
    W.fight=line(true,1,0); s.tick(0)
    assert(W.view==cam_actor)
    W.fight=line(false); s.tick(0.25); s.tick(0.5)
    local v=W.views[2]
    assert(#W.views==2 and v.target==eve and v.blend==0.5 and v.f==0 and v.e==0 and v.lock==false)
    assert(s.watching()==false and #W.calls==0,'A leave makes no call')
    W.fight=line(true,1,0); s.tick(0.75)
    assert(#W.spawned==1 and #W.views==3 and W.view==cam_actor,'The same camera')
    -- Its actor gone with its world: a new one.
    W.fight=line(false); s.tick(1)
    W.cam_gone=true
    W.fight=line(true,1,0); s.tick(1.25)
    assert(#W.spawned==2)
end
do -- native_fault: spectate=faulted at life 3 with our camera on: the view back, one respawn call, one log line.
    local s=world()
    W.fight=line(true,1,0); s.tick(0)
    local n=#W.logs
    W.engine=ENGINE:gsub('spectate=on','spectate=faulted')
    s.tick(0.25)
    assert(W.view==eve and W.views[#W.views].blend==0.5 and #W.calls==1 and W.calls[1]=='respawn 228 false',
        table.concat(W.calls,'|'))
    assert(#W.logs==n+1 and W.logs[n+1]:find('the native spectate faulted',1,true),table.concat(W.logs,'|'))
    assert(s.watching()==false)
    s.tick(0.5); s.tick(0.75)
    assert(#W.calls==1 and #W.logs==n+1,'Once')
    -- The word lost (coop off): the same.
    s=world()
    W.fight=line(true,1,0); s.tick(0)
    W.engine='engine=on reason=pinned build 26123051 warp=idle me=228'
    s.tick(0.25)
    assert(W.view==eve and #W.calls==1 and logged('the native spectate is gone')==1)
    -- The word back: spectate again.
    W.engine=ENGINE
    s.tick(0.5)
    assert(s.watching()==true and W.view==cam_actor)
    -- Our camera not on: the view stays, no call.
    s=world(function(w) w.view=theater end)
    W.fight=line(true,1,0); s.tick(0)
    W.engine=ENGINE:gsub('spectate=on','spectate=faulted')
    s.tick(0.25)
    assert(W.view==theater and #W.calls==0)
    -- No status read is no loss.
    s=world()
    W.fight=line(true,1,0); s.tick(0)
    W.engine=nil
    s.tick(0.25)
    assert(W.view==cam_actor and #W.calls==0)
end
do -- no_ghost: no anchor, the camera 400 cm over our EVE; spectate goes on.
    local s=world(function(w) w.anchors={}; w.at={X=50,Y=60,Z=70} end)
    W.fight=line(true,1,0); s.tick(0); s.frame()
    local m=W.moves[#W.moves]
    assert(m.at.X==50 and m.at.Y==60 and m.at.Z==470 and m.rot.Pitch==-90 and s.watching()==true)
    assert(W.spawned[1].at.Z==470,'Made there too')
end
do -- switch: among the members alive on our map, camera only.
    local s=world(function(w)
        w.members={{id=7,name='Ana',slot=0,linked=true},{id=9,name='Bo',slot=1,linked=true}}
        w.vitals[9]={life=1,hp=900}
        w.maps[1]='/game/e04'
        w.anchors[1]={X=-1000,Y=0,Z=0}
    end)
    W.fight=line(true,1,0); s.tick(0)
    assert(s.status():find('watching Ana',1,true))
    s.switch('right')
    assert(s.status():find('watching Bo',1,true) and logged('watching Bo (right)')==1,s.status())
    s.frame()
    local m=W.moves[#W.moves]
    assert(m.at.X==-1400 and m.at.Y==0,'Her camera: '..m.at.X) -- The direction from Ana's feet toward our EVE.
    s.switch('right'); assert(s.status():find('watching Ana',1,true))
    s.switch('left'); assert(s.status():find('watching Bo',1,true))
    assert(#W.requests==0 and #W.calls==0,'Camera only')
    W.vitals[9]={life=3,hp=0}
    s.switch('left'); assert(s.status():find('watching Ana',1,true),'Bo down: Ana is the one left')
    local n=#W.logs
    s.switch('right')
    assert(s.status():find('watching Ana',1,true) and #W.logs==n+1 and W.logs[n+1]=='spectate: nobody else to watch')
    -- Bo on another map: not a choice either.
    W.vitals[9]={life=1,hp=900}; W.maps[1]='/game/e05'
    s.switch('right'); assert(s.status():find('watching Ana',1,true))
    -- The native part's watch changing ends the switch's choice.
    W.maps[1]='/game/e04'
    s.switch('right'); assert(s.status():find('watching Bo',1,true))
    W.fight=line(true,0,0); s.tick(0.25)
    assert(not s.status():find('watching Bo',1,true),s.status())
    s.switch('right'); assert(#W.requests==0)
    W.fight=line(false); s.tick(0.5)
    local before=#W.logs
    s.switch('right'); assert(#W.logs==before,'Not watching: nothing')
end
do -- watching_notice: once, when her spec turns from - to our member number.
    local s=world()
    W.fight=line(false,nil,0,'-',0); s.tick(0)
    W.fight=line(false,nil,0,'0',0); s.tick(0.25); s.tick(0.5)
    assert(#W.told==1 and W.told[1]=='Ana is down and watching.',tostring(W.told[1]))
    W.fight=line(false,nil,0,'-',0); s.tick(0.75)
    W.fight=line(false,nil,0,'1',0); s.tick(1)
    assert(#W.told==1,'She watches someone else: none')
    -- On the guest (mem 1): the host's name.
    s=world(function(w)
        w.host={id=3,pair=8}
        w.members={{id=3,name='Hal',slot=0,linked=true}}
    end)
    W.fight=line(false,nil,0,'-',1); s.tick(0)
    W.fight=line(false,nil,0,'1',1); s.tick(0.25)
    assert(#W.told==1 and W.told[1]=='Hal is down and watching.',tostring(W.told[1]))
    -- Outside an online session the other member is slot 0's.
    s=world(function(w) w.host=nil end)
    W.fight=line(false,nil,0,'-',0); s.tick(0)
    W.fight=line(false,nil,0,'0',0); s.tick(0.25)
    assert(#W.told==1 and W.told[1]=='Ana is down and watching.')
end
do -- test_probe: alone at life 3, the ask, the camera over our EVE, 10 s later the respawn and one result line.
    local s=world()
    local ok,why=s.test()
    assert(not ok and why=='coop spectate test runs alone: leave the online session first' and #W.requests==0,why)
    s=world(function(w) w.mode='none'; w.life={state=1,hp=900} end)
    ok,why=s.test(); assert(not ok and why:find('life 1',1,true) and #W.requests==0,why)
    s=world(function(w) w.mode='none'; w.host=nil end)
    s.tick(0)
    ok,why=s.test()
    assert(ok and W.requests[1]=='spectate test' and #W.requests==1
        and why=='spectate test asked: its line follows in this log in 12 s',tostring(why))
    ok,why=s.test(); assert(not ok and #W.requests==1,'One at a time')
    s.tick(0.25); s.frame()
    assert(#W.spawned==1 and W.view==cam_actor and W.moves[#W.moves].at.Z==400,'Our camera over our EVE')
    W.respawn=function() W.life={state=1,hp=900} end
    W.engine=ENGINE:gsub('hud=1','hud=0')
    for t=0.5,9.75,0.25 do s.tick(t) end
    assert(#W.calls==0,'Not before 10 s')
    s.tick(10)
    assert(#W.calls==1 and W.calls[1]=='respawn 228 false' and W.view==eve,table.concat(W.calls,'|'))
    W.engine=ENGINE:gsub('hud=1','hud=-')
    for t=10.25,11.75,0.25 do s.tick(t) end
    assert(logged('spectate test:')==0 and W.view==eve,'The line 2 s after the call; the view stays on EVE')
    s.tick(12)
    assert(logged('spectate test: hud 1 -> 0, life 1, camera ours, respawn asked')==1,table.concat(W.logs,'|'))
    s.tick(12.25); s.tick(14.5)
    assert(#W.calls==1 and logged('spectate test:')==1,'No fallback for the test')
    -- A refused respawn names why.
    s=world(function(w) w.mode='none'; w.standalone=false end)
    s.tick(0); s.test()
    for t=0.25,12,0.25 do s.tick(t) end
    assert(#W.calls==0 and logged('camera ours, respawn refused: the game is not standalone')==1,
        table.concat(W.logs,'|'))
end
io.stdout:write('spectate_test ok\n')
