-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The friend's revive and the wait during the host's cutscene, on the game thread: main.lua ticks it every 250 ms with
-- the Steam link. The revive sends nothing: each side reads its own game and the friend's vitals and ghost.
-- The downed side (us): our EVE is revived where she lies once all of these held for 3 s with no gap: our life state
-- 3 (the death screen's), the death screen's animation playing (core/unreal.lua's death_screen()), the engine line's
-- warp=idle (no respawn or warp in flight, read by the native part), a member past the handshake with her vitals alive
-- (life 1 or 6, HP above 0) and her ghost shown on our map within 2 m across and 1 m up or down of our EVE (with more
-- than one, the nearest revives), the fight= line's boss=0 (the shared fight runs, which the native part allows on a
-- co-op save only; no boss of ours is in battle), the
-- game standalone (KismetSystemLibrary IsStandalone, as nightop/probe.lua reads it: in net mode 3 the call would go to
-- a server instead), no nightop=rule on the engine line (with a rule row the respawn spends a life count and may not
-- respawn at all), and revive=on. Then pc:ServerRequest_ActorRespawn(me, false), SB's own
-- in-place respawn (no camp warp, no zone reset, full health and the recovery items refilled as at a camp), once per
-- death; pc:ServerRequest_ActorRevival(me, false) only if our life state did not move 2 s later (no read of 1 or 6 in
-- between either) and every condition but the 3 s holds again. me is our EVE's GUID from the engine line. 2 s after the
-- last call, one line: life, HP and the death screen before and after, and whether the EVE pawn is the same. A death
-- screen that still plays once our life state reads 1 or 6 is hidden (visibility Hidden, as Survival Protocol hides its
-- parts) and shown again as it was at the next death, once our life is no longer read (no session), once the revive is
-- off for the run, or at coop off (stop()). A Lua error turns the revive off for the run. Notices: the wait (the friend
-- can revive us) once per death, once everything but the distance holds; the revived line after a revive. A link that
-- drops starts the 3 s again.
-- The friend's side, for each member past the handshake whose game can make the call: her down notice once per death
-- of hers, while our EVE is not down, she is on our map and no boss of ours is in battle; our revive of her when her
-- vitals go from down to alive while our EVE stands within 3 m of her ghost. Her revive setting reaches no line, so
-- the down notice shows whatever it says. A member's vitals are the link's (vit=, mate= for slot 0), her ghost her
-- slot's: main.lua's puppet for slot 0, o.ghost(k) for the others. In an online session of more than 2 players only
-- the host and the pair can be revived (phase 7b1): the boss=0 read comes from the shared fight, which runs between
-- them alone, so another guest's game never makes the call and nobody is told to revive her.
-- coop revive test, the solo probe: refused while linked, it makes the same call at the death screen with life 3 to 5,
-- with the same lines (commands/session.lua runs it on a co-op save only).
-- During a Night Operation run (o.night()), the run owns the revive (nightop/run.lua): the 3 s rule and its notices
-- wait, our revive of her too (the run says it when its hold was full), and night_revive(by) makes the call with
-- revive=on and coop revive test's guards, when her interact key was held next to our EVE ('friend', on her night line)
-- or for coop nightop revive ('self'), with the same fallback, result line and hidden death screen; the revived notice
-- only after the friend's revive.
-- The host's cutscene, on both PCs once a second while linked: SB's theater observers (walked for as theater() says); a
-- cutscene plays while one of them has a valid player whose IsPlaying() is true (on and off logged with its sequence's
-- name).
-- The host's photo state goes to the native part as 'c' while it plays and the host's own is '0' (photo()), so its
-- photo line pauses the guest; the guest asks for that pause with cut=1 while her cutscene_wait is on and the host's
-- ghost (his member line's slot) is on her map (cut()). Her notice comes once each time her photo line says the pause
-- holds for it.
local U=require('core.unreal')
local Where=require('core.where')
local N=require('core.player')
local G={}
local HOLD,AFTER=3,2 -- s: every condition held; then a read of our life state after each call.
local ACROSS,UP,NEAR=200,100,300 -- cm: her ghost from our EVE across and up or down; our EVE from hers, for our revive.
local LOOK=10 -- s between two lookups of the death screen while it is not found.
local HIDDEN=2 -- ESlateVisibility Hidden.
local function alive(m) return m~=nil and (m.life==1 or m.life==6) and m.hp>0 end
local function down(m) return m~=nil and (m.life>=3 and m.life<=5 or m.hp==0 and m.max_hp>0) end
local why=U.why
local weak=U.weak
-- Our EVE's mesh location (her ghost's place is the friend's mesh), or nil.
local function feet()
    local eve=N.her()
    local mesh=eve and U.valid(eve.Mesh)
    if not mesh then return nil end
    local v=U.value_of(mesh:K2_GetComponentLocation())
    return {X=v.X,Y=v.Y,Z=v.Z}
end
-- o: {link=, puppet=, settings= (revive), tell(build), name(words, name) (that name cleaned, or with none the slot-0
-- member's, else the words' friend), log(text), night() (a Night Operation run is on; nil: never), ghost(k) (ghost
-- slot k's puppet, 1 to 6, or nil)}.
function G.new(o)
    local link,puppet,settings,log=o.link,o.puppet,o.settings,o.log
    local function tell(key,name) o.tell(function(w) return w.group[key]:format(o.name(w,name)) end) end
    local self,now,off={},0,{}
    local screen,look_at,hidden=nil,-math.huge,nil -- hidden: {widget=, was=} while we hide the death screen.
    local d=nil -- This death of ours: {since=, waited=, said=, call=, before=, fallback=, probe=, night=}.
    local function night() return o.night~=nil and o.night()==true end
    local hers={} -- Each member's death as we saw it, by her SteamID: {said=}.
    local scene={playing=false,next=0,told=false} -- A cutscene: as of the last read, the next read, our notice.
    local function engine() return ('\n'..(link.status() or '')):match('\nengine=([^\r\n]*)') or '' end
    local function death_screen()
        if not U.valid(screen) then
            if now<look_at then return nil end
            look_at=now+LOOK
            screen=U.death_screen()
        end
        return screen
    end
    local function playing()
        local s=death_screen()
        return s~=nil and s:IsAnyAnimationPlaying()==true
    end
    local NONE={her_map=function() end,anchor=function() end} -- A slot whose ghost is not made yet.
    local function ghost_of(slot)
        if slot==0 then return puppet end
        return o.ghost and o.ghost(slot) or NONE
    end
    -- Each member past the handshake: {id=, name=, vit= (her vitals or nil), ghost=}, in the status's order.
    local function mates()
        local out={}
        for _,m in ipairs(link.members()) do
            if m.linked then
                out[#out+1]={id=m.id,name=m.name,vit=m.slot==0 and link.mate() or link.vitals(m.id),
                    ghost=ghost_of(m.slot)}
            end
        end
        return out
    end
    local function same_map(ghost)
        local me=Where.me()
        return me~=nil and me.map~=nil and (ghost or puppet).her_map()==me.map
    end
    -- On a guest, the host's ghost (his member line's slot; the native part gives him slot 0).
    local function host_ghost()
        local h=link.host()
        local m=h and link.member(h.id)
        return m and ghost_of(m.slot) or puppet
    end
    local function boss_free() return (link.fight() or ''):find(' boss=0',1,true)~=nil end
    -- A member whose own game can make the revive's call: outside an online session any, in one the host or the pair.
    local function revivable(m)
        local h=link.host()
        return not h or m.id==h.id or m.id==h.pair
    end
    -- The screen we hid comes back as it was.
    local function show(reason)
        local h=hidden
        hidden=nil
        if U.valid(h.widget) then h.widget:SetVisibility(h.was) end
        log('revive: death screen shown again ('..reason..')')
    end
    -- Why the revive waits, or nil when every condition holds now; 'friend far' when only the distance fails. Then our
    -- EVE's GUID, the controller, the metres to the nearest member within 2 m and her name (with 'friend far', the
    -- name of the first member alive on our map). probe: coop revive test's (life 3 to 5; nothing of the friend's or
    -- of the shared fight's).
    local function blocker(probe)
        if not probe and not settings.revive then return 'revive=off' end
        local life=link.life()
        if not life then return 'no life read (our life is read in a session only: start coop loopback 0 0 0 first)' end
        -- The death screen's life state: 3 for a co-op revive, 3 to 5 for coop revive test.
        if life.state<3 or life.state>(probe and 5 or 3) then return 'life '..life.state end
        local near={} -- The members alive on our map.
        if not probe then
            local list=mates()
            if not list[1] then return 'no friend linked' end
            local up=false
            for _,m in ipairs(list) do
                if alive(m.vit) then
                    up=true
                    if same_map(m.ghost) then near[#near+1]=m end
                end
            end
            if not up then return 'friend not alive' end
            if not near[1] then return 'friend on another map' end
            if not boss_free() then
                return (link.fight() or ''):find(' boss=',1,true) and 'boss fight' or 'no shared fight'
            end
        end
        local line=engine()
        local warp,me=line:match(' warp=(%a+) me=(%d+)')
        if not warp then return 'no warp read' end
        if warp~='idle' then return 'a respawn or a warp is under way' end
        if line:find(' nightop=rule',1,true) then return 'a coop no probe rule is set in this game run' end
        local pc=N.controller()
        if not pc then return 'no SB player controller' end
        if U.find('/Script/Engine.Default__KismetSystemLibrary'):IsStandalone(pc)~=true then
            return 'the game is not standalone'
        end
        if not N.her() then return 'no EVE' end
        if not playing() then return 'no death screen' end
        if probe then return nil,tonumber(me),pc end
        local mine,best,by=feet(),nil,nil
        for _,m in ipairs(near) do
            local _,ghost=m.ghost.anchor()
            if ghost and mine and (ghost.X-mine.X)^2+(ghost.Y-mine.Y)^2<=ACROSS^2 and math.abs(ghost.Z-mine.Z)<=UP then
                local d=math.sqrt((ghost.X-mine.X)^2+(ghost.Y-mine.Y)^2)
                if not best or d<best then best,by=d,m end
            end
        end
        if not by then return 'friend far',nil,nil,nil,near[1].name end
        return nil,tonumber(me),pc,best/100,by.name
    end
    local function snapshot()
        local life,s,eve=link.life(),death_screen(),N.her()
        return {life=life and life.state or '?',hp=life and life.hp or '?',
            screen=s and (s:IsAnyAnimationPlaying()==true and 'up' or 'off') or 'gone',pawn=eve and U.address(eve)}
    end
    local function who()
        return d.probe and 'coop revive test' or d.night=='self' and 'coop nightop revive' or d.by or (link.friend())
            or '?'
    end
    local function call(me,pc,where,by)
        d.call,d.me,d.before,d.by=now,me,snapshot(),by
        local b=d.before
        log(string.format('revive: ServerRequest_ActorRespawn(%d, false) asked (%s%s; life %s, hp %s, death screen %s)',
            me,who(),where and string.format(' %.1f m away',where) or '',b.life,b.hp,b.screen))
        pc:ServerRequest_ActorRespawn(me,false)
    end
    -- 2 s after a call: the fallback once if our life state did not move and every condition holds again (a respawn she
    -- pressed meanwhile reads warp=busy), else the result line, the screen hidden if it still plays over a living EVE,
    -- and the revived notice. Up in between and down again: a new death, from the next tick.
    local function after()
        local life=link.life()
        if not d.fallback and not d.moved and life and life.state==d.before.life then
            local reason=blocker(d.probe or d.night~=nil)
            if not reason then
                d.fallback,d.call=true,now
                log(string.format('revive: life still %d 2 s after the respawn: ServerRequest_ActorRevival(%d, false) '
                    ..'asked',life.state,d.me))
                local pc=assert(N.controller(),'no SB player controller')
                pc:ServerRequest_ActorRevival(d.me,false)
                return
            end
            log('revive: life still '..life.state..' 2 s after the respawn, no fallback call: '..reason)
        end
        local a,b=snapshot(),d.before
        local up=a.life==1 or a.life==6
        local screen_now=a.screen
        if up and a.screen=='up' then
            local s=death_screen()
            hidden={widget=s,was=s:GetVisibility()}
            s:SetVisibility(HIDDEN)
            screen_now='hidden'
        end
        log(string.format('revive result (%s): life %s/%s%s, hp %s/%s, death screen %s/%s, recovery items not read, '
            ..'EVE pawn %s',who(),b.life,a.life,d.moved and not up and ' (up in between)' or '',b.hp,a.hp,b.screen,
            screen_now,not a.pawn and 'gone' or a.pawn==b.pawn and 'same' or 'new'))
        d.call=nil
        d.done=true
        if not d.probe and d.night~='self' and (up or d.moved) then tell('revived',d.by) end
        if d.moved and not up then d=nil end
    end
    local function downed(linked)
        local life=link.life()
        if life and life.state>=3 and life.state<=5 then
            if not d then
                d={}
                if hidden then show('a new death') end
            end
        elseif life and (life.state==1 or life.state==6) and d then
            if d.call then d.moved=true else d=nil end
        end
        if not d then return end
        if d.call then
            if now-d.call>=AFTER then after() end
            return
        end
        if d.done or not linked or night() then d.since=nil; return end
        local reason,me,pc,where,by=blocker(false)
        if reason~=d.said then
            d.said=reason
            if reason then log('revive waits: '..reason) end
        end
        if (not reason or reason=='friend far') and not d.waited then
            d.waited=true
            tell('wait',by)
        end
        if reason then d.since=nil; return end
        d.since=d.since or now
        if now-d.since>=HOLD then call(me,pc,where,by) end
    end
    local function friend()
        local seen={}
        for _,m in ipairs(mates()) do
            if revivable(m) then
                seen[m.id]=true
                local h=hers[m.id]
                if down(m.vit) then
                    h=h or {}
                    hers[m.id]=h
                    local life=link.life()
                    local ours_down=life and life.state>=3 and life.state<=5
                    if not h.said and not ours_down and same_map(m.ghost) and boss_free() then
                        h.said=true
                        if not night() then tell('down',m.name) end -- The run gives its own: her key, not 3 s near.
                    end
                elseif h and alive(m.vit) then
                    hers[m.id]=nil
                    local _,ghost=m.ghost.anchor()
                    local mine=feet()
                    if not night() and ghost and mine
                        and (ghost.X-mine.X)^2+(ghost.Y-mine.Y)^2+(ghost.Z-mine.Z)^2<=NEAR^2 then
                        tell('you_revived',m.name)
                    end
                end
            end
        end
        for id in pairs(hers) do if not seen[id] then hers[id]=nil end end -- Gone, or no longer linked.
    end
    -- The cutscene's name while one plays, else nil. The observer found playing is kept while it plays. A theater plays
    -- through a level sequence actor, whose class's actors come from the engine's class hash (core/unreal.lua's
    -- actors_of): the theater observers are walked for (FindAllOf walks every object, 25 to 80 ms in game: once a
    -- second while linked, that was a frozen frame each second) only when the set of playing sequence actors changes,
    -- so a looping one with no theater costs one walk, logged with the names. A gate that raises walks.
    -- shortcut: an observer whose player starts a read after its sequence actor is missed until the set changes again;
    -- read the observer at each new set for a few reads if a grouped test shows that lag.
    -- The hash needs a world: our EVE's, else our SB controller's. With neither (a load, the title screen) no theater
    -- plays, and actors_of would walk for want of a world.
    -- last: the playing sequence actors' addresses and full names at the last read (after a map change a freed address
    -- may hold another actor; the full name has its map). world: the address of the world the observer was found in.
    local observer,last,world=nil,nil,nil
    local function name_of(ob)
        local player=ob and weak(ob.Player)
        return player and player:IsPlaying()==true and U.text(ob.SequenceName) or nil
    end
    local function theater()
        local ctx=N.her() or N.controller()
        local here=ctx and U.valid(ctx:GetWorld())
        here=here and U.address(here)
        if here~=world then observer,world=nil,here end -- The map frees it: never read it again (IsValid included).
        local kept=name_of(U.valid(observer))
        if kept then return kept end
        observer=nil -- Its cutscene over, the collector may free it.
        if not ctx then return nil end
        local read,playing,names=pcall(function()
            local keys,names={},{}
            local list=U.actors_of(U.find('/Script/LevelSequence.LevelSequenceActor'),'LevelSequenceActor',ctx)
            for _,a in ipairs(list) do
                local player=U.valid(a.SequencePlayer)
                if player and player:IsPlaying()==true then
                    local full=U.text(a:GetFullName())
                    keys[#keys+1]=U.address(a)..' '..full
                    names[#names+1]=full:match('[^.:]+$')
                end
            end
            table.sort(keys)
            return table.concat(keys,' '),names
        end)
        local same=read and playing==last
        last=read and playing or nil
        if read and (playing=='' or same) then return nil end
        local name=nil
        U.each(FindAllOf('SBTheaterLevelSequenceObserver') or {},function(_,ob)
            ob=not name and U.valid(ob)
            name=name_of(ob)
            if name then observer=ob end
        end)
        if name then last=nil -- Once it ends, the next theater may play on the same sequence actor.
        elseif read then log('cutscene: no theater for the playing sequences '..table.concat(names,', ')) end
        return name
    end
    local function watch()
        if now>=scene.next then
            scene.next=now+1
            local name=theater()
            if (name~=nil)~=scene.playing then log(name and 'cutscene on: '..name or 'cutscene off') end
            scene.playing=name~=nil
        end
        local photo=link.photo()
        if not (photo and photo.peer=='c') then scene.told=false
        elseif photo.frozen and not scene.told then
            scene.told=true
            tell('cutscene')
        end
    end
    -- One part's first Lua error turns it off for the run, with one line.
    local function guard(name,f,...)
        if off[name] then return end
        local ok,e=pcall(f,...)
        if not ok then
            off[name]=true
            log(name..' off for this run: '..why(e))
        end
    end
    -- Every 250 ms (main.lua's loop); t: its clock in seconds.
    function self.tick(t)
        now=t
        local mode=link.mode()
        local linked=(mode=='host' or mode=='guest') and link.others()>0
        guard('revive',downed,linked)
        if hidden and (off.revive or not link.life()) then
            guard('screen',show,off.revive and 'the revive is off' or 'no session')
        end
        if linked then guard('friend',friend) else hers={} end
        if linked then guard('cutscene',watch) end
        if not linked or off.cutscene then scene.playing,scene.told=false,false end
    end
    -- A cutscene plays in our game (read once a second while linked): the travel's guards read it too.
    function self.cutscene_playing() return scene.playing end
    -- Our photo state for coop-state.txt: own ('0', '1' or 's'), or 'c' on the host while its cutscene plays and own is
    -- '0'. Our own photo veils keep reading own.
    function self.photo(own)
        if own=='0' and scene.playing and link.mode()=='host' then return 'c' end
        return own
    end
    -- The guest's ask for the pause during the host's cutscene: cutscene_wait=on, the host's ghost on her map, and our
    -- read of cutscenes not off for the run (the pause would come with no notice).
    function self.cut()
        return not off.cutscene and settings.cutscene_wait==true and link.mode()=='guest' and same_map(host_ghost())
    end
    -- coop off: the death screen we hid comes back.
    function self.stop() if hidden then show('coop off') end end
    -- The Night Operation run's revive of our EVE (nightop/run.lua), by 'friend' or 'self': revive=on (the setting may
    -- turn off during the down), coop revive test's guards (life 3 to 5, the death screen, no respawn or warp in
    -- flight, no probe rule, standalone), then the call. true, or false and why not; a Lua error turns the revive off
    -- for the run.
    function self.night_revive(by)
        if off.revive then return false,'the revive is off for this run (see the log)' end
        if not settings.revive then return false,'revive=off' end
        if d and d.call then return false,'a revive call is under way' end
        local ok,reason,me,pc=pcall(blocker,true)
        if not ok then return false,why(reason) end
        if reason then return false,reason end
        if not d and hidden then show('a new death') end
        d=d or {}
        d.night=by
        ok,reason=pcall(call,me,pc)
        if not ok then
            off.revive=true
            log('revive off for this run: '..why(reason))
            return false,why(reason)
        end
        return true
    end
    -- coop revive test (the console): true and what was asked, or false and why not.
    function self.test()
        if off.revive then return false,'the revive is off for this run (see the log)' end
        local mode=link.mode()
        if mode==nil then return false,'the Steam link is not ready yet: try again in a moment' end
        if mode~='none' then return false,'coop revive test is solo only: leave the session first (coop leave)' end
        if d and d.call then return false,'a revive call is under way: its result follows in this log' end
        local ok,reason,me,pc=pcall(blocker,true)
        if not ok then return false,why(reason) end
        if reason then return false,'coop revive test works only at the death screen: '..reason end
        d={probe=true}
        ok,reason=pcall(call,me,pc)
        if not ok then
            off.revive=true
            log('revive off for this run: '..why(reason))
            return false,why(reason)
        end
        return true,'ServerRequest_ActorRespawn asked: the result follows in this log in 2 to 4 s'
    end
    return self
end
return G
