-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Its respawn call (blocker(), call() and the fallback in after()) is a copy of online/group/group.lua's, made for
-- spectate.
-- Spectate's Lua side (phase 3): the camera, the respawn, the switch and coop spectate test. The native part decides
-- (fight/enemies/spectate.h): it holds the death screen hidden while our EVE is down in a shared boss fight. It writes
-- spec=, watch=, up=, upn=, her_spec= and mem= on the fight= line, with spectate= and hud= on the engine line. Lua
-- hides no widget: the hold keeps SB's own Hidden state. online/group/group.lua stays the only module that touches the
-- death screen widget.
-- The camera: at spec=1, a camera actor of core/actors.lua (one made before by an earlier Lua load is swept at the
-- first tick, its path kept in coop-spectate.txt). The view goes to it only from our pawn and back to our pawn only
-- from it, each tick, with a BLEND s blend: a theater's camera (an HP scene) keeps the view on both edges. Each frame
-- the camera stands BACK cm from the watched ghost's feet along its own horizontal direction from her (the first one:
-- from her feet toward our EVE), UP cm above her feet, aimed at CHEST cm above them. With no ghost anchor (partner
-- off, a ghost not drawn) it stands BACK cm over our EVE, looking down.
-- The respawn: each time upn rises (a reason to get up), once, our life 2 or 3, warp=idle, no nightop=rule, the
-- controller, the game standalone and our EVE: pc:ServerRequest_ActorRespawn(me, false), SB's in-place respawn (full
-- health, the recovery items refilled as at a camp). AFTER s later, our life not moved and those checks holding again:
-- pc:ServerRequest_ActorRevival(me, false) once. The AFTER wait stops while the fight= line reads fight=waiting (a
-- pause): the respawn waits with the game. me is our EVE's GUID from the engine line.
-- The fallback: the engine line reads spectate=faulted, or loses the word it had (coop off): the view goes back to our
-- pawn. With our camera on and our life 2 or 3, one respawn call is made too, logged.
-- Members: mem is ours; member 0 is link.host()'s id, member 1 its pair; outside an online session the other member is
-- slot 0's. switch(dir) watches the next or the previous member alive on our map, camera only, logged.
-- o: {link=, settings=, log(text), tell(build), name(words, name), puppet= (a view of the partner's puppet), ghost(k)
-- (ghost slot k's puppet, or nil), actors= (core/actors.lua), player= (core/player.lua), unreal= (core/unreal.lua)}.
local Spectate={}
local BACK,UP,CHEST,BLEND=400,160,130,0.5 -- cm, cm, cm, s.
local AFTER=2 -- s: the fallback's wait, as online/group/group.lua's.
local PROBE=10 -- s: coop spectate test's camera before its respawn.
function Spectate.new(o)
    local link,log,actors,player,U=o.link,o.log,o.actors,o.player,o.unreal
    local self={}
    local store=link.store('coop-spectate.txt') -- The camera's path, for the next Lua load's sweep.
    local swept=false
    local last,clock=nil,0 -- The last tick's time; the AFTER clock, stopped while the fight= line reads waiting.
    local on,watch,chosen,dir=false,nil,nil,nil -- spec=1 as last read; watch=; the switch's SteamID; the camera's way.
    local last_upn,her_was=nil,nil
    local had,fell=false,false -- The engine line had a spectate= word; its loss or fault was acted on.
    local cam=nil -- {actor=, path=, mesh=}: core/actors.lua's spawn, kept for the next spectate.
    local d=nil -- The last respawn call: {at= (clock), me=, before= (life), moved=}.
    -- coop spectate test: {at= (now), hud=, after= (hud at the call), kind= (the view then), call= (now), why=}.
    local probe=nil
    local failed=nil -- The camera's last error, logged once.
    local function engine()
        local s=link.status()
        return s and ('\n'..s):match('\nengine=([^\r\n]*)') or nil
    end
    local function is(a,b) return a~=nil and b~=nil and U.address(a)==U.address(b) end
    -- Member m's SteamID. shortcut: the map knows members 0 and 1 only, until 7b2 numbers every guest.
    local function id_of(m,mem)
        if not m then return nil end
        local h=link.host()
        if h then return m==0 and h.id or m==1 and h.pair or nil end
        if m==mem then return nil end
        for _,x in ipairs(link.members()) do if x.slot==0 then return x.id end end
    end
    local function ghost_of(id)
        local m=id and link.member(id)
        if not m then return nil end
        if m.slot==0 then return o.puppet end
        return o.ghost(m.slot)
    end
    local function name_of(id) local m=id and link.member(id); return m and m.name end
    local function watched() return chosen or id_of(tonumber(watch)) end
    -- Where the camera stands and how it turns this frame, or nil without our EVE.
    local function place()
        local eve=player.her()
        local mine=eve and U.value_of(eve:K2_GetActorLocation())
        local g=not probe and ghost_of(watched())
        local feet=g and select(2,g.anchor())
        if feet then
            if not dir then
                local dx,dy=mine and mine.X-feet.X or 1,mine and mine.Y-feet.Y or 0
                local n=math.sqrt(dx*dx+dy*dy)
                dir=n>1 and {dx/n,dy/n} or {1,0}
            end
            local at={X=feet.X+dir[1]*BACK,Y=feet.Y+dir[2]*BACK,Z=feet.Z+UP}
            local dx,dy,dz=feet.X-at.X,feet.Y-at.Y,feet.Z+CHEST-at.Z
            return at,{Pitch=math.deg(math.atan(dz,math.sqrt(dx*dx+dy*dy))),Yaw=math.deg(math.atan(dy,dx)),Roll=0}
        end
        if mine then return {X=mine.X,Y=mine.Y,Z=mine.Z+BACK},{Pitch=-90,Yaw=0,Roll=0} end
    end
    local function filming() return on or (probe~=nil and not probe.call) end
    local function alive_cam()
        if cam and not actors.same(cam.actor,cam.path) then cam=nil end -- Gone with its world.
        return cam
    end
    -- The view target as ours (our camera), pawn (our EVE), other or none.
    local function view_kind()
        local pc=player.controller()
        local view=pc and U.valid(pc:GetViewTarget())
        if not view then return 'none' end
        if alive_cam() and is(view,cam.actor) then return 'ours' end
        return is(view,player.her()) and 'pawn' or 'other'
    end
    -- The view back on our EVE from our camera only. true when it was given back.
    local function give_back()
        local pc,eve=player.controller(),player.her()
        if not (pc and eve and view_kind()=='ours') then return false end
        pc:SetViewTargetWithBlend(eve,BLEND,0,0,false)
        return true
    end
    -- The camera made when none lives, then the view taken from our pawn only.
    local function take()
        local pc,eve=player.controller(),player.her()
        if not (pc and eve) then return end
        if not alive_cam() then
            local at,rot=place()
            cam=actors.spawn(eve:GetWorld(),at,rot,{camera=true})
            local saved,why=store.save(cam.path)
            if saved==false then log('spectate: coop-spectate.txt not written: '..tostring(why)) end
        end
        if view_kind()=='pawn' then
            pc:SetViewTargetWithBlend(cam.actor,BLEND,0,0,false)
            log('spectate: camera on')
        end
    end
    -- Why the respawn cannot be asked now (group's blocker, held to what applies here), else nil, our EVE's GUID and
    -- the controller.
    local function blocker()
        local life=link.life()
        if not life then return 'no life read' end
        if life.state~=2 and life.state~=3 then return 'life '..life.state end
        local warp,me=(engine() or ''):match(' warp=(%a+) me=(%d+)')
        if not warp then return 'no warp read' end
        if warp~='idle' then return 'a respawn or a warp is under way' end
        if (engine() or ''):find(' nightop=rule',1,true) then return 'a coop no probe rule is set in this game run' end
        local pc=player.controller()
        if not pc then return 'no SB player controller' end
        if U.find('/Script/Engine.Default__KismetSystemLibrary'):IsStandalone(pc)~=true then
            return 'the game is not standalone'
        end
        if not player.her() then return 'no EVE' end
        return nil,tonumber(me),pc
    end
    local function call(why)
        local reason,me,pc=blocker()
        if reason then return log('spectate: no respawn ('..why..'): '..reason) end
        local life=link.life()
        d={at=clock,me=me,before=life.state,moved=false}
        log(string.format('spectate: ServerRequest_ActorRespawn(%d, false) asked (%s; life %d)',me,why,life.state))
        pc:ServerRequest_ActorRespawn(me,false)
    end
    -- AFTER s after a call: the fallback once if our life did not move and the checks hold again.
    local function after()
        local life=link.life()
        if life and (life.state==1 or life.state==6) then d.moved=true end
        if clock-d.at<AFTER then return end
        local c=d
        d=nil
        if c.moved or not life or life.state~=c.before then return end
        local reason,_,pc=blocker()
        if reason then
            return log('spectate: life still '..life.state..' 2 s after the respawn, no fallback: '..reason)
        end
        log(string.format('spectate: life still %d 2 s after the respawn: ServerRequest_ActorRevival(%d, false) asked',
            life.state,c.me))
        pc:ServerRequest_ActorRevival(c.me,false)
    end
    -- An earlier Lua load's camera: the view back on our EVE if it had it, then swept.
    local function sweep()
        swept=true
        local p=store.load()
        if not p then return end
        local pc,eve=player.controller(),player.her()
        local view=pc and U.valid(pc:GetViewTarget())
        if view and eve and actors.same(view,p) then pc:SetViewTargetWithBlend(eve,0,0,0,false) end
        log('spectate: an earlier Lua load\'s camera '..(actors.sweep(p,'camera') and 'swept' or 'not found'))
        store.clear()
    end
    -- The members alive on our map, as link.members() lists them: their SteamIDs.
    local function candidates()
        local eve=player.her()
        local map=eve and U.map_of(eve)
        local out={}
        for _,m in ipairs(link.members()) do
            local v=m.slot==0 and link.mate() or link.vitals(m.id)
            local g=m.linked and ghost_of(m.id)
            if g and v and (v.life==1 or v.life==6) and v.hp>0 and map and g.her_map()==map then out[#out+1]=m.id end
        end
        return out
    end
    function self.tick(now)
        local dt=last and math.max(now-last,0) or 0
        last=now
        local line=link.fight()
        if not (line and line:find('^fight=waiting')) then clock=clock+dt end
        if not swept then sweep() end
        local word=nil
        local eng=engine()
        if eng then
            word=eng:match(' spectate=(%a+)')
            if word=='on' or word=='off' then fell=false end
            local lost=word=='faulted' or (word==nil and had)
            had=had or word~=nil
            if lost and not fell then
                fell=true
                local ours=give_back()
                local life=link.life()
                if ours and life and (life.state==2 or life.state==3) then
                    call('the native spectate '..(word and 'faulted' or 'is gone')..', the view back on EVE')
                end
            end
        end
        local was=on
        on=line~=nil and line:find(' spec=1',1,true)~=nil and not fell
        local mem=line and tonumber(line:match(' mem=(%d+)'))
        local w=line and line:match(' watch=(%S+)')
        if w~=watch then watch,chosen=w,nil end
        if on and not was then
            dir,chosen=nil,nil
            local name=name_of(watched())
            o.tell(function(t) return t.fight.spectate:format(o.name(t,name)) end)
        end
        local upn=line and tonumber(line:match(' upn=(%d+)'))
        if upn then
            -- A fault drops upn to 0 (the native word reset): no reason to get up, the fallback above is the only call.
            if last_upn and upn>last_upn then call('reason '..upn) end
            last_upn=upn
        end
        local her=line and line:match(' her_spec=(%S+)')
        if her and mem and her_was=='-' and her==tostring(mem) then
            local name=name_of(id_of(mem==0 and 1 or 0,mem))
            o.tell(function(t) return t.fight.watching:format(o.name(t,name)) end)
        end
        if her then her_was=her end
        if d then after() end
        if probe and not probe.call and now-probe.at>=PROBE then
            probe.after,probe.kind,probe.call=(engine() or ''):match(' hud=(%S+)') or '-',view_kind(),now
            give_back()
            local reason,me,pc=blocker()
            probe.why=reason
            if not reason then pc:ServerRequest_ActorRespawn(me,false) end
        end
        if probe and probe.call and now-probe.call>=AFTER then -- Our life as the respawn left it.
            local p,life=probe,link.life()
            probe=nil
            log(string.format('spectate test: hud %s -> %s, life %s, camera %s, respawn %s',p.hud,p.after,
                life and life.state or '?',p.kind,p.why and 'refused: '..p.why or 'asked'))
        end
        local ok,why=pcall(function()
            if filming() then take() elseif give_back() then log('spectate: the view back on EVE') end
        end)
        if not ok and why~=failed then log('spectate: camera: '..tostring(why)) end
        failed=not ok and why or nil
    end
    function self.frame()
        if not filming() or not alive_cam() then return end
        local at,rot=place()
        if at then cam.mesh:K2_SetWorldLocationAndRotation(at,rot,false,{},false) end
    end
    function self.watching() return on end
    function self.switch(way)
        if not on then return end
        local list,now=candidates(),watched()
        local at=0
        for i,id in ipairs(list) do if id==now then at=i end end
        local pick=list[(at-1+(way=='left' and -1 or 1))%math.max(#list,1)+1]
        if not pick or pick==now then return log('spectate: nobody else to watch') end
        chosen=pick
        log('spectate: watching '..tostring(name_of(pick))..' ('..way..')')
    end
    -- coop spectate test: alone at life 3, the native part's test hold, our camera over our EVE for PROBE s, then the
    -- respawn and, AFTER s later, one result line.
    function self.test()
        local mode=link.mode()
        if mode==nil then return false,'the Steam link is not ready yet: try again in a moment' end
        if mode~='none' then return false,'coop spectate test runs alone: leave the online session first' end
        if probe then return false,'coop spectate test runs: its line follows in this log' end
        local life=link.life()
        if not (life and life.state==3) then
            return false,'coop spectate test works only at the death screen (life 3); now '
                ..(life and 'life '..life.state or 'no life read')
        end
        local ok,why=link.request('spectate test')
        if not ok then return false,why end
        probe={at=last or 0,hud=(engine() or ''):match(' hud=(%S+)') or '-'}
        return true,'spectate test asked: its line follows in this log in '..(PROBE+AFTER)..' s'
    end
    function self.status()
        local eng=engine() or ''
        local name=on and name_of(watched())
        return string.format('spectate: native %s, hud %s, %s, camera %s',eng:match(' spectate=(%a+)') or '-',
            eng:match(' hud=(%S+)') or '-',on and 'watching '..tostring(name or '-') or 'not watching',view_kind())
    end
    return self
end
return Spectate
