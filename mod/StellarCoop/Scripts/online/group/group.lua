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
-- game standalone (KismetSystemLibrary IsStandalone, as online/modes/nightop/probe.lua reads it: in net mode 3 the call
-- would go to a server instead), no nightop=rule on the engine line (with a rule row the respawn spends a life count
-- and may not respawn at all), and revive=on. Then pc:ServerRequest_ActorRespawn(me, false), SB's own
-- in-place respawn (no camp warp, no zone reset, full health and the recovery items refilled as at a camp), once per
-- death; pc:ServerRequest_ActorRevival(me, false) only if our life state did not move 2 s later (no read of 1 or 6 in
-- between either) and every condition but the 3 s holds again. me is our EVE's GUID from the engine line. 2 s after the
-- last call, one line: life, HP and the death screen before and after, and whether the EVE pawn is the same. A death
-- screen that still plays once our life state reads 1 or 6 is hidden (visibility Hidden, as Survival Protocol hides its
-- parts) and shown again as it was at the next death, once our life is no longer read (no session), once the revive is
-- off for the run, or at coop off (stop()). Its visibility before and its address stay in coop-death-screen.txt while
-- it is hidden. The first tick of the next Lua load (Ctrl+R) takes the screen over from it while SB's death screen has
-- that address and reads Hidden, then shows it at the same moments. A Lua error turns the revive off for the run.
-- Notices: the wait (the friend can revive us) once per death, once everything but the distance holds; the revived line
-- after a revive. A link that drops starts the 3 s again.
-- The friend's side, for each member past the handshake whose game can make the call: her down notice once per death
-- of hers, while our EVE is not down, she is on our map and no boss of ours is in battle; our revive of her when her
-- vitals go from down to alive while our EVE stands within 3 m of her ghost. Her revive setting reaches no line, so
-- the down notice shows whatever it says. A member's vitals are the link's (vit=, mate= for slot 0), her ghost her
-- slot's: main.lua's puppet for slot 0, o.ghost(k) for the others. In an online session of more than 2 players only
-- the host and the pair can be revived (phase 7b1): the boss=0 read comes from the shared fight, which runs between
-- them alone, so another guest's game never makes the call and nobody is told to revive her.
-- The return after our death (follow_key on the death screen: online/group/travel.lua's press asks back() first). The
-- offer comes once per death while all of these hold: our life state 3 under the playing death screen, a co-op save
-- (the status line slot=coop), revive=on, no Night Operation run, the fight= line's boss=0, the target alive by her
-- vitals on our map with no solo area on either side, no respawn call of ours in this death yet and none in the 10 s
-- before it started. follow_key=none or follow_host=off: one log line in its place. follow_host=always: its notice,
-- then the call 5 s later; follow_key within those 5 s cancels it. The target: on a guest the host (his host line's
-- member, else slot 0's); on the host the living guest on his map nearest his EVE (her ghost's feet). back() runs the
-- guards of coop revive test held to life 3 (a refusal: one log line, no call), then the revive's call with its
-- fallback, result line and hidden screen (no revived notice: nobody revived us). Once our life reads 1 or 6 with
-- warp=idle, the game not paused (10 s at most): o.go(her id), the spot warp next to her, if she is still linked,
-- alive, on our map and outside a solo area; else one log line. The friend's 3 s revive marks nothing: no warp after it.
-- Solo areas (core/link.lua's Link.solo: ZoneTable's zone type 2 to 6, ours from link.zone(), hers from her vitals):
-- each other member in one is said once a stay, then back once her type reads public (1); no vitals and type 0 keep
-- the last state. The revive waits while we are in one and leaves out a member in one. The guest asks no cutscene
-- pause while the host or she is in one. Her down notice waits while either side is in one.
-- coop revive test, the solo probe: refused while linked, it makes the same call at the death screen with life 3 to 5,
-- with the same lines (online/group/commands.lua runs it on a co-op save only).
-- During a Night Operation run (o.night()), the run owns the revive (online/modes/nightop/run.lua): the 3 s rule and
-- its notices wait, our revive of her too (the run says it when its hold was full), and night_revive(by) makes the call
-- with revive=on and coop revive test's guards, when her interact key was held next to our EVE ('friend', on her night
-- line) or for coop nightop revive ('self'), with the same fallback, result line and hidden death screen; the revived
-- notice only after the friend's revive.
-- The host's cutscene, on both PCs once a second while linked: from the status line's theater= field when the native
-- part gives it; else SB's theater observers (walked for as theater() says), a cutscene playing while one of them has
-- a valid player whose IsPlaying() is true (on and off logged with its sequence's name).
-- The host's photo state goes to the native part as 'c' while it plays and the host's own is '0' (photo()), so its
-- photo line pauses the guest; the guest asks for that pause with cut=1 while her cutscene_wait is on and the host's
-- ghost (his member line's slot) is on her map (cut()). Her notice comes once each time her photo line says the pause
-- holds for it.
-- Camp rests (shared_world=on, linked, a co-op save, not in a solo area of ours): each start of our own zone reset on
-- the engine line's rest=<ours>:<area>:<type> (the first read of a Lua load is the baseline) sends rest <area> with type
-- 1, or with type 2 once our life read alive for 10 s before it (else a death's camp respawn), never within 10 s after
-- our own ResetZone call (SB's echo of that call carries GUID 0 and never moves ours: a guard only). Each rest received
-- from another member (rest(zone,from)) waits in a queue, one per zone; a zone reset in our game in the last 30 s (our
-- own rest, an applied call) drops it, when it comes or while it waits. Each second while queued: dropped once the
-- session ended, without shared_world, off a co-op save, outside that zone (the engine line's area=), with no life
-- read, in a solo area of ours, with no boss= and battle= on the fight line (no shared fight in this game), in a game
-- that is not standalone, or for a zone FNAME_Find does not know; waiting through a fight, a cutscene, a pause, no EVE,
-- a respawn or warp, our EVE down, no controller, 60 s at most (then the skipped notice). Then
-- pc:ServerRequest_ResetZone(our GUID, the zone's FName) with the rested notice: SB's own reset of that zone for our
-- EVE (FSBResetZone resets it only where the logic's zone is the same). More than 3 starts within 30 s after one call
-- stop the calls for the Lua load, with a notice.
local U=require('core.unreal')
local Where=require('core.where')
local N=require('core.player')
local Link=require('core.link')
local G={}
local HOLD,AFTER=3,2 -- s: every condition held; then a read of our life state after each call.
-- s: no return offer for a death this soon after our last respawn call; always's delay; the warp's wait while paused.
local RECENT,AUTO,PAUSE=10,5,10
-- ESBZoneType 2 to 6 (Zone_TrainningRoom, Zone_SpiritRoom, Zone_TestZone, Zone_BossChallenge, Zone_Nikke; its value
-- table at 0x145e29730 on 26123051) to ui/text's group.places.
local PLACE={[2]='training',[3]='spirit',[4]='test',[5]='boss',[6]='nikke'}
local ACROSS,UP,NEAR=200,100,300 -- cm: her ghost from our EVE across and up or down; our EVE from hers, for our revive.
local LOOK=10 -- s between two lookups of the death screen while it is not found.
local HIDDEN=2 -- ESlateVisibility Hidden.
-- Camp rests, s: alive before a type-2 start of ours counts, also the guard after our own ResetZone call; the retry
-- step; the wait for a busy game; starts after one call that stop the calls; their window; a zone just reset.
local CALM,RETRY,GIVE_UP,STOP_N,STOP_S,SAME=10,1,60,3,30,30
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
-- o: {link=, puppet=, settings= (revive, cutscene_wait, follow_host, follow_key), tell(build), name(words, name) (that
-- name cleaned, or with none the slot-0 member's, else the words' friend), log(text), night() (a Night Operation run
-- is on; nil: never), ghost(k) (ghost slot k's puppet, 1 to 6, or nil), go(id) (online/group/travel.lua's spot warp
-- next to member id: true, or false and why), paused() (the game paused, in photo mode or in a menu)}.
function G.new(o)
    local link,puppet,settings,log=o.link,o.puppet,o.settings,o.log
    local function tell(key,name,...) -- Her name first, then the other arguments of the word.
        local args={...}
        o.tell(function(w) return w.group[key]:format(o.name(w,name),table.unpack(args)) end)
    end
    local self,now,off={},0,{}
    local screen,look_at,hidden=nil,-math.huge,nil -- hidden: {widget=, was=} while we hide the death screen.
    local store=link.store('coop-death-screen.txt') -- hidden's was and the widget's address, for the next Lua load.
    -- This death of ours: {at=, since=, waited=, said=, call=, before=, fallback=, probe=, night=, offered= ('shown' or
    -- 'quiet'), due= (always's call), back= (back()'s call: the target's name)}.
    local d=nil
    local respawned,ret=-math.huge,nil -- Our last respawn call; after back()'s call: {id=, name=, up=}.
    local solos={} -- Each member in a solo area as we last read her, by her SteamID: true once said.
    local function night() return o.night~=nil and o.night()==true end
    local hers={} -- Each member's death as we saw it, by her SteamID: {said=}.
    local scene={playing=false,next=0,told=false} -- A cutscene: as of the last read, the next read, our notice.
    -- Camp rests: the engine line's last counts (nil before the first read), since when our life reads alive, our last
    -- ResetZone call {at=, starts=}, each zone's last reset in our game by alias, the received rests waiting ({zone=,
    -- from=, at=, next=, why=}, oldest first), the stop latch.
    local rests={ours=nil,starts=nil,alive=nil,call=nil,reset={},queue={},stopped=false}
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
    local function entry(m)
        return {id=m.id,name=m.name,vit=m.slot==0 and link.mate() or link.vitals(m.id),ghost=ghost_of(m.slot)}
    end
    -- Each member past the handshake: {id=, name=, vit= (her vitals or nil), ghost=}, in the status's order.
    local function mates()
        local out={}
        for _,m in ipairs(link.members()) do
            if m.linked then out[#out+1]=entry(m) end
        end
        return out
    end
    -- Member id past the handshake, as mates() gives her, or nil.
    local function member(id)
        local m=id and link.member(id)
        return m and m.linked and entry(m) or nil
    end
    -- On a guest, the host as mates() gives him: his host line's member, else slot 0's (travel.lua's guest() rule).
    local function host_mate()
        local h=link.host()
        if h then return member(h.id) end
        for _,m in ipairs(link.members()) do if m.slot==0 then return member(m.id) end end
    end
    -- A solo area on our side, or on member m's (her vitals' zone type; none read: not hers).
    local function away(m)
        return Link.solo((link.zone())) or (m~=nil and m.vit~=nil and Link.solo(m.vit.zone))
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
    local function coop_save() return ('\n'..(link.status() or '')):find('\nslot=coop ',1,true)~=nil end
    -- A member whose own game can make the revive's call: outside an online session any, in one the host or the pair.
    local function revivable(m)
        local h=link.host()
        return not h or m.id==h.id or m.id==h.pair
    end
    -- The screen we hid comes back as it was.
    local function show(reason)
        local h=hidden
        hidden=nil
        store.clear()
        if U.valid(h.widget) then h.widget:SetVisibility(h.was) end
        log('revive: death screen shown again ('..reason..')')
    end
    -- At the first tick, a death screen an earlier Lua load hid (Ctrl+R while it was hidden): taken over as ours while
    -- SB's death screen is the widget at the file's address and reads Hidden, so it comes back as it was at the same
    -- moments; else the file goes. Any other widget (a rebuilt HUD, a new game run) is left as it is, as show() leaves
    -- it. No revive of this load has hidden it yet: after() runs from the tick, after this.
    local swept=false
    local function sweep()
        swept=true
        local was,at=(store.load() or ''):match('^(%S+) (%S+)$')
        was,at=tonumber(was),tonumber(at)
        local s=was and at and U.death_screen()
        if s and U.address(s)==at and s:GetVisibility()==HIDDEN then
            screen,hidden=s,{widget=s,was=was}
            return log('revive: death screen hidden by an earlier Lua load, taken over')
        end
        store.clear()
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
        local near={} -- The members alive on our map, outside a solo area.
        if not probe then
            if Link.solo((link.zone())) then return 'solo area' end
            local list=mates()
            if not list[1] then return 'no friend linked' end
            local up,solo=false,false
            for _,m in ipairs(list) do
                if alive(m.vit) then
                    up=true
                    if same_map(m.ghost) then
                        if away(m) then solo=true else near[#near+1]=m end
                    end
                end
            end
            if not up then return 'friend not alive' end
            if not near[1] then return solo and 'friend in a solo area' or 'friend on another map' end
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
        return d.probe and 'coop revive test' or d.night=='self' and 'coop nightop revive'
            or d.back and 'follow_key return to '..d.back or d.by or (link.friend()) or '?'
    end
    local function call(me,pc,where,by)
        d.call,d.me,d.before,d.by,respawned=now,me,snapshot(),by,now
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
            local reason=blocker(d.probe or d.night~=nil or d.back~=nil)
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
            local saved,e=store.save(tostring(hidden.was)..' '..U.address(s))
            if not saved then log('revive: coop-death-screen.txt not written: '..tostring(e)) end
        end
        log(string.format('revive result (%s): life %s/%s%s, hp %s/%s, death screen %s/%s, recovery items not read, '
            ..'EVE pawn %s',who(),b.life,a.life,d.moved and not up and ' (up in between)' or '',b.hp,a.hp,b.screen,
            screen_now,not a.pawn and 'gone' or a.pawn==b.pawn and 'same' or 'new'))
        d.call=nil
        d.done=true
        if not d.probe and d.night~='self' and not d.back and (up or d.moved) then tell('revived',d.by) end
        if ret and not up and not d.moved then
            ret=nil
            log('return: no warp, the respawn did not take')
        end
        if d.moved and not up then d=nil end
    end
    local function downed(linked)
        local life=link.life()
        if life and life.state>=3 and life.state<=5 then
            if not d then
                d={at=now}
                if hidden then show('a new death') end
                if ret then
                    ret=nil
                    log('return: no warp, down again before it')
                end
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
                    if not h.said and not ours_down and same_map(m.ghost) and boss_free() and not away(m) then
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
    -- Why the return cannot go toward member m now, or nil.
    local function why_not(m)
        if not alive(m.vit) then return 'they are down' end
        if not same_map(m.ghost) then return 'they are on another map' end
        if away(m) then return 'a solo area on their side or ours' end
    end
    -- The return's target: on a guest the host; on the host the living guest on his map nearest his EVE, outside a
    -- solo area. nil without one.
    local function target()
        local mode=link.mode()
        if mode=='guest' then return host_mate() end
        if mode~='host' then return nil end
        local mine,best,by=feet(),nil,nil
        for _,m in ipairs(mates()) do
            local _,f=m.ghost.anchor()
            if f and mine and not why_not(m) then
                local far=(f.X-mine.X)^2+(f.Y-mine.Y)^2+(f.Z-mine.Z)^2
                if not best or far<best then best,by=far,m end
            end
        end
        return by
    end
    -- The return's target while its offer holds (see the header), else nil.
    local function open()
        if off.revive or not d or not d.at or d.call or d.done or d.back or d.at-respawned<RECENT then return nil end
        local life=link.life()
        if not (life and life.state==3) or not coop_save() or not settings.revive or night() or not boss_free() then
            return nil
        end
        local m=target()
        if not m or why_not(m) or not playing() then return nil end
        return m
    end
    -- The call of back() and of always's 5 s: the offer still holds, then coop revive test's guards (open() held them
    -- to life 3), the revive's call with the death marked for the warp. nil when the offer no longer holds.
    local function go_back()
        local m=open()
        if not m then return nil end
        local reason,me,pc=blocker(true)
        if reason then
            log('return refused: '..reason)
            return false,reason
        end
        d.back=m.name and m.name~='' and m.name or 'member '..m.id
        call(me,pc)
        ret={id=m.id,name=d.back}
        return true,'going back to '..d.back
    end
    -- The offer once per death, after the revive's tick; always's call 5 s after its notice while the offer holds.
    local function offering()
        if not d then return end
        if d.offered then
            if d.due and (settings.follow_host~='always' or not open()) then d.due=nil end
            if d.due and now>=d.due then
                d.due=nil
                go_back()
            end
            return
        end
        local m=open()
        if not m then return end
        local key=settings.follow_key or {}
        d.offered='quiet'
        if not key.key then return log('return: no notice (follow_key=none)') end
        if settings.follow_host=='off' then return log('return: no notice (follow_host=off)') end
        d.offered='shown'
        if settings.follow_host=='always' then d.due=now+AUTO end
        tell(d.due and 'back_auto' or 'back',m.name,key.name)
    end
    -- After back()'s call, once our life reads 1 or 6 with warp=idle and the game not paused (PAUSE s at most): the
    -- warp next to the target if she still holds, else one line why not.
    local function returning()
        local life=link.life()
        if not (ret and life and (life.state==1 or life.state==6)) then return end
        if not engine():find(' warp=idle',1,true) then return end
        ret.up=ret.up or now
        if o.paused() and now-ret.up<PAUSE then return end
        local r=ret
        ret=nil
        local m=member(r.id)
        local no=not m and 'they are no longer linked' or why_not(m)
        if no then return log('return: no warp, '..no) end
        local ok,text=o.go(r.id)
        log('return: '..(ok and 'the warp next to '..r.name..' asked' or 'no warp, '..tostring(text)))
    end
    -- Each other member's stay in a solo area, from her vitals' zone type: said once on the way in, back once a public
    -- type (1) reads after it; no vitals and type 0 keep the last state.
    local function stays()
        local seen={}
        for _,m in ipairs(mates()) do
            seen[m.id]=true
            local t=m.vit and m.vit.zone
            if Link.solo(t) and not solos[m.id] then
                solos[m.id]=true
                o.tell(function(w) return w.group.solo:format(o.name(w,m.name),w.group.places[PLACE[t]]) end)
            elseif t==1 and solos[m.id] then
                solos[m.id]=nil
                tell('solo_back',m.name)
            end
        end
        for id in pairs(solos) do if not seen[id] then solos[id]=nil end end -- Gone, or no longer linked.
    end
    -- The cutscene's name while one plays, else nil: the theater= field's when the native part gives it; else the
    -- observer found playing, kept while it plays. A theater plays through a level sequence actor, whose class's actors
    -- come from the engine's class hash (core/unreal.lua's actors_of): the theater observers are walked for (FindAllOf
    -- walks every object, 25 to 80 ms in game: once a second while linked, that was a frozen frame each second) only
    -- when the set of playing sequence actors changes, so a looping one with no theater costs one walk, logged with the
    -- names. A gate that raises walks.
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
        local f=(link.status() or ''):match('theater=(%S+)')
        if f and f~='fault' then -- SB's own theater read (glue/tick/theater_game.inc): no actor list, no walk.
            observer,last=nil,nil
            if f=='none' then return nil end
            return f=='-' and 'a theater' or f
        end
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
    -- The rest line's member: her name, else the words' someone.
    local function rest_tell(key,from)
        local m=link.member(from)
        local name=m and m.name or ''
        o.tell(function(w) return w.group[key]:format(name~='' and o.name(w,name) or w.group.someone) end)
    end
    -- Our own zone reset start on the engine line: send its area when it counts as a rest (see the header).
    local function send_rest(linked,area,kind)
        if rests.call and now-rests.call.at<CALM then
            return log('rest: our own reset within 10 s of a ResetZone call, not sent')
        end
        local why=not settings.shared_world and 'shared_world=off' or not linked and 'no session'
            or not coop_save() and 'not a co-op save' or Link.solo((link.zone())) and 'a solo area of ours'
            or area=='none' and 'no area read'
            or kind==2 and not (rests.alive and now-rests.alive>=CALM) and 'type 2 within 10 s of getting up'
        if why then return log('rest: our own reset of '..area..' not sent: '..why) end
        local ok,e=link.request('rest '..area)
        log(ok and 'rest: our own reset of '..area..' sent'
            or 'rest: our own reset of '..area..' not sent: '..tostring(e))
    end
    -- Whether zone was reset in our game in the last SAME s (our own rest, an applied call), with one log line then.
    local function reset_lately(zone)
        local last=rests.reset[zone]
        if not (last and now-last<SAME) then return false end
        log(string.format('rest: %s already reset %d s ago',zone,math.floor(now-last)))
        return true
    end
    -- Why received rest r is dropped ('drop', why) or waits ('busy', why); else nil, our GUID, the controller and the
    -- zone's FName.
    local function rest_check(r)
        if not settings.shared_world then return 'drop','shared_world=off' end
        if not coop_save() then return 'drop','not a co-op save' end
        local life=link.life()
        if not life then return 'drop','no life read' end
        local kind,area=link.zone()
        if area~=r.zone then return 'drop','our area is '..(area or 'none') end
        if Link.solo(kind) then return 'drop','a solo area of ours' end
        local f=link.fight() or ''
        local battle,boss=f:match(' battle=(%d+)'),f:match(' boss=(%-?%d+)')
        if not battle and not boss then return 'drop','no fight read in this game' end
        if (battle or '0')~='0' or (boss or '0')~='0' then return 'busy','a fight' end
        if scene.playing then return 'busy','a cutscene' end
        if o.paused() then return 'busy','the game is paused' end
        if not N.her() then return 'busy','no EVE' end
        local warp,me=engine():match(' warp=(%a+) me=(%d+)')
        if warp~='idle' then return 'busy','a respawn or a warp is under way' end
        if me=='0' then return 'busy','no GUID of our EVE read' end
        if not (life.state==1 or life.state==6) or life.hp<=0 then return 'busy','down' end
        local pc=N.controller()
        if not pc then return 'busy','no SB player controller' end
        if U.find('/Script/Engine.Default__KismetSystemLibrary'):IsStandalone(pc)~=true then
            return 'drop','the game is not standalone'
        end
        -- FNAME_Find gives NAME_None for a name the game does not know; the name must read back as the zone.
        local name=U.value_of(FName(r.zone,EFindName.FNAME_Find))
        local index=name:GetComparisonIndex()
        if not index or index==0 or U.text(name):lower()~=r.zone:lower() then return 'drop',r.zone..' is not a name' end
        return nil,tonumber(me),pc,name
    end
    -- Received rest r: true once done with (applied, dropped or skipped), false to try again later.
    local function apply_rest(r)
        if reset_lately(r.zone) then return true end -- Our own rest while this one waited.
        local verdict,a,pc,name=rest_check(r)
        if verdict=='drop' then
            log('rest: '..a..' ('..r.zone..' of member '..r.from..' dropped)')
            return true
        elseif verdict=='busy' then
            if now-r.at<GIVE_UP then
                if a~=r.why then log('rest: '..r.zone..' waits: '..a) end
                r.why,r.next=a,now+RETRY
                return false
            end
            log('rest: '..r.zone..' not reset, busy for a minute ('..a..')')
            rest_tell('rest_skipped',r.from)
            return true
        end
        rests.reset[r.zone],rests.call=now,{at=now,starts=rests.starts}
        log(string.format('rest: ServerRequest_ResetZone(%d, %s) asked (rest of member %s)',a,r.zone,r.from))
        -- 26123051: its exec 0x14275eae0 reads a uint32 GUID then an FName; its impl 0x1423c02b0 pushes SB's ResetZone.
        pc:ServerRequest_ResetZone(a,name)
        rest_tell('rested',r.from)
        return true
    end
    -- Every tick: our life, the engine line's rest counts (our own rest sent, the stop latch), then the queue.
    local function resting(linked)
        local life=link.life()
        if life and (life.state==1 or life.state==6) and life.hp>0 then rests.alive=rests.alive or now
        else rests.alive=nil end
        local ours,area,kind,starts=engine():match(' rest=(%d+):([%w_]+):(%-?%d+) starts=(%d+)')
        if ours then
            ours,kind,starts=tonumber(ours),tonumber(kind),tonumber(starts)
            local was=rests.ours
            rests.ours,rests.starts=ours,starts
            if was and ours~=was then
                if area~='none' then rests.reset[area]=now end
                send_rest(linked,area,kind)
            end
            local c=rests.call
            if c and c.starts and not rests.stopped and now-c.at<=STOP_S and starts-c.starts>STOP_N then
                rests.stopped,rests.queue=true,{}
                log(string.format('rest: %d zone reset starts within %d s after our last ResetZone call: no more '
                    ..'calls this run',starts-c.starts,STOP_S))
                o.tell(function(w) return w.group.rest_stopped end)
            end
        end
        if not rests.queue[1] then return end
        if not linked then
            rests.queue={}
            return log('rest: dropped, the session ended')
        end
        local left={}
        for _,r in ipairs(rests.queue) do
            if now<r.next or not apply_rest(r) then left[#left+1]=r end
        end
        rests.queue=left
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
        if not swept then guard('screen',sweep) end
        guard('revive',downed,linked)
        guard('return',function() offering(); returning() end)
        if hidden and (off.revive or not link.life()) then
            guard('screen',show,off.revive and 'the revive is off' or 'no session')
        end
        if linked then guard('friend',friend) else hers={} end
        if linked then guard('solo',stays) else solos={} end
        if linked then guard('cutscene',watch) end
        if not linked or off.cutscene then scene.playing,scene.told=false,false end
        guard('rest',resting,linked) -- After the cutscene's read, which a received rest waits for.
    end
    -- A cutscene plays in our game (read once a second while linked): the travel's guards read it too.
    function self.cutscene_playing() return scene.playing end
    -- Our photo state for coop-state.txt: own ('0', '1' or 's'), or 'c' on the host while its cutscene plays and own is
    -- '0'. Our own photo veils keep reading own.
    function self.photo(own)
        if own=='0' and scene.playing and link.mode()=='host' then return 'c' end
        return own
    end
    -- The guest's ask for the pause during the host's cutscene: cutscene_wait=on, the host's ghost on her map, no solo
    -- area on his side or hers, and our read of cutscenes not off for the run (the pause would come with no notice).
    function self.cut()
        return not off.cutscene and settings.cutscene_wait==true and link.mode()=='guest' and same_map(host_ghost())
            and not away(host_mate())
    end
    -- follow_key on the death screen (online/group/travel.lua's press asks here first): with the offer shown, always's
    -- 5 s cancelled while they run, else go_back(). true or false and the text; nil without an offer that holds
    -- (follow_key is the follow then). A Lua error turns the return off for the run.
    function self.back()
        if off['return'] or not (d and d.offered=='shown') then return nil end
        local ok,a,b=pcall(function()
            if d.due then
                d.due=nil
                log('return: cancelled (follow_key)')
                return true,'return cancelled'
            end
            return go_back()
        end)
        if ok then return a,b end
        off['return']=true
        log('return off for this run: '..why(a))
        return false,why(a)
    end
    -- A camp rest of member from (her SteamID as digits) in zone (its alias), from the runtime's inbox: queued, unless
    -- that zone was reset in our game in the last 30 s, one waits for it already or the calls are stopped.
    function self.rest(zone,from)
        if off.rest then return end
        if rests.stopped then return log('rest: '..zone..' of member '..from..' dropped, the calls are stopped') end
        if reset_lately(zone) then return end
        for _,r in ipairs(rests.queue) do
            if r.zone==zone then return log('rest: '..zone..' already waits, member '..from..' dropped') end
        end
        rests.queue[#rests.queue+1]={zone=zone,from=from,at=now,next=now}
    end
    -- coop off: the death screen we hid comes back.
    function self.stop() if hidden then show('coop off') end end
    -- The Night Operation run's revive of our EVE (online/modes/nightop/run.lua), by 'friend' or 'self': revive=on (the
    -- setting may turn off during the down), coop revive test's guards (life 3 to 5, the death screen, no respawn or
    -- warp in flight, no probe rule, standalone), then the call. true, or false and why not; a Lua error turns the
    -- revive off for the run.
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
