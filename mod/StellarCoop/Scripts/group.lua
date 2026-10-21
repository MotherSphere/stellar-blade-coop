-- The friend's revive and the wait during the host's cutscene, on the game thread: main.lua ticks it every 250 ms with
-- the Steam link. The revive sends nothing: each side reads its own game and the friend's vitals and ghost.
-- The downed side (us): our EVE is revived where she lies once all of these held for 3 s with no gap: our life state in
-- G.DOWN (the death screen's), the death screen's animation playing (unreal.lua's death_screen()), the engine line's
-- warp=idle (no respawn or warp in flight, read by the native part), the friend linked with her vitals alive (life 1 or
-- 6, HP above 0), her ghost shown on our map within 2 m across and 1 m up or down of our EVE, the fight= line's boss=0
-- (no boss of ours in battle), the game standalone (KismetSystemLibrary IsStandalone, as nightop.lua reads it: in net
-- mode 3 the call would go to a server instead), no nightop=rule on the engine line (with a rule row the respawn spends
-- a life count and may not respawn at all), and revive=on. Then pc:ServerRequest_ActorRespawn(me, false), SB's own
-- in-place respawn (no camp warp, no zone reset, full health and the recovery items refilled as at a camp), once per
-- death; pc:ServerRequest_ActorRevival(me, false) only if our life state did not move 2 s later. me is our EVE's GUID
-- from the engine line. 2 s after the last call, one line: life, HP and the death screen before and after, and whether
-- the EVE pawn is the same. A death screen that still plays once our life state reads 1 is hidden (visibility Hidden,
-- as Survival Protocol hides its parts) and shown again as it was at the next death. A Lua error turns the revive off
-- for the run. Notices: the wait (the friend can revive us) once per death, once everything but the distance holds;
-- the revived line after a revive.
-- The friend's side: her down notice once per death of hers, while our EVE is not down, she is on our map and no boss
-- of ours is in battle; our revive of her when her vitals go from down to alive while our EVE stands within 3 m of her
-- ghost. Her revive setting reaches no line, so the down notice shows whatever it says.
-- coop revive test, the solo probe: refused while linked, it makes the same call at the death screen with life 3 to 5,
-- with the same lines.
-- The host's cutscene, on both PCs once a second while linked: one FindAllOf of SB's theater observers; a cutscene
-- plays while one of them has a valid player whose IsPlaying() is true (on and off logged with its sequence's name).
-- The host's photo state goes to the native part as 'c' while it plays and the host's own is '0' (photo()), so its
-- photo line pauses the guest; the guest asks for that pause with cut=1 while her cutscene_wait is on and the host's
-- ghost is on her map (cut()). Her notice comes once each time her photo line says the pause holds for it.
local U=require('unreal')
local N=require('nightop')
local G={}
G.DOWN={3,3} -- Our life states that count as the death screen's for a co-op revive; coop revive test takes 3 to 5.
local HOLD,AFTER=3,2 -- s: every condition held; then a read of our life state after each call.
local ACROSS,UP,NEAR=200,100,300 -- cm: her ghost from our EVE across and up or down; our EVE from hers, for our revive.
local LOOK=10 -- s between two lookups of the death screen while it is not found.
local HIDDEN=2 -- ESlateVisibility Hidden.
local function alive(m) return m~=nil and (m.life==1 or m.life==6) and m.hp>0 end
local function down(m) return m~=nil and (m.life>=3 and m.life<=5 or m.hp==0 and m.max_hp>0) end
local function why(e) return (tostring(e):gsub('^.-:%d+: ','')) end -- Without the file and line.
-- A TWeakObjectPtr property's object (UE4SS gives the pointer, whose Get() reads it), or nil.
local function weak(v)
    v=U.value_of(v)
    local kind=U.kind(v)
    if kind and kind:find('Weak',1,true) then v=v:Get() end
    return U.valid(v)
end
-- Our EVE's mesh location (her ghost's place is the friend's mesh), or nil.
local function feet()
    local eve=N.her()
    local mesh=eve and U.valid(eve.Mesh)
    if not mesh then return nil end
    local v=U.value_of(mesh:K2_GetComponentLocation())
    return {X=v.X,Y=v.Y,Z=v.Z}
end
-- o: {link=, puppet=, settings= (revive), tell(build), name(words) (her name, or the words' friend), log(text)}.
function G.new(o)
    local link,puppet,settings,log=o.link,o.puppet,o.settings,o.log
    local function tell(key) o.tell(function(w) return w.group[key]:format(o.name(w)) end) end
    local self,now,off={},0,{}
    local screen,look_at,hidden=nil,-math.huge,nil -- hidden: {widget=, was=} while we hide the death screen.
    local d=nil -- This death of ours: {since=, waited=, said=, call=, before=, fallback=, probe=}.
    local hers=nil -- Her death as we saw it: {said=}.
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
    local function same_map()
        local me=puppet.me()
        return me~=nil and me.map~=nil and puppet.her_map()==me.map
    end
    local function boss_free() return (link.fight() or ''):find(' boss=0',1,true)~=nil end
    -- Why the revive waits, or nil when every condition holds now; 'friend far' when only the distance fails. probe:
    -- coop revive test's (life 3 to 5, and nothing of the friend's or of the shared fight's).
    local function blocker(probe)
        if not probe and not settings.revive then return 'revive=off' end
        local life=link.life()
        if not life then return 'no life read (our life is read in a session only: start coop loopback 0 0 0 first)' end
        local lo,hi=G.DOWN[1],G.DOWN[2]
        if probe then lo,hi=3,5 end
        if life.state<lo or life.state>hi then return 'life '..life.state end
        local _,linked=link.friend()
        if not probe then
            if not linked then return 'no friend linked' end
            if not alive(link.mate()) then return 'friend not alive' end
            if not same_map() then return 'friend on another map' end
            if not boss_free() then return 'boss fight' end
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
        local _,ghost=puppet.anchor()
        local mine=feet()
        if not (ghost and mine) or (ghost.X-mine.X)^2+(ghost.Y-mine.Y)^2>ACROSS^2 or math.abs(ghost.Z-mine.Z)>UP then
            return 'friend far'
        end
        return nil,tonumber(me),pc,math.sqrt((ghost.X-mine.X)^2+(ghost.Y-mine.Y)^2)/100
    end
    local function snapshot()
        local life,s,eve=link.life(),death_screen(),N.her()
        return {life=life and life.state or '?',hp=life and life.hp or '?',
            screen=s and (s:IsAnyAnimationPlaying()==true and 'up' or 'off') or 'gone',pawn=eve and U.address(eve)}
    end
    local function who() return d.probe and 'coop revive test' or (link.friend()) or '?' end
    local function call(me,pc,where)
        d.call,d.me,d.before=now,me,snapshot()
        local b=d.before
        log(string.format('revive: ServerRequest_ActorRespawn(%d, false) asked (%s%s; life %s, hp %s, death screen %s)',
            me,who(),where and string.format(' %.1f m away',where) or '',b.life,b.hp,b.screen))
        pc:ServerRequest_ActorRespawn(me,false)
    end
    -- 2 s after a call: the fallback once if our life state did not move, else the result line, the screen hidden if it
    -- still plays over a living EVE, and the revived notice.
    local function after()
        local life=link.life()
        if not d.fallback and life and life.state==d.before.life then
            d.fallback,d.call=true,now
            log(string.format('revive: life still %d 2 s after the respawn: ServerRequest_ActorRevival(%d, false) '
                ..'asked',life.state,d.me))
            local pc=assert(N.controller(),'no SB player controller')
            pc:ServerRequest_ActorRevival(d.me,false)
            return
        end
        local a,b=snapshot(),d.before
        local screen_now=a.screen
        if a.life==1 and a.screen=='up' then
            local s=death_screen()
            hidden={widget=s,was=s:GetVisibility()}
            s:SetVisibility(HIDDEN)
            screen_now='hidden'
        end
        log(string.format('revive result (%s): life %s/%s, hp %s/%s, death screen %s/%s, recovery items not read, '
            ..'EVE pawn %s',who(),b.life,a.life,b.hp,a.hp,b.screen,screen_now,
            not a.pawn and 'gone' or a.pawn==b.pawn and 'same' or 'new'))
        d.call=nil
        d.done=true
        if not d.probe and (a.life==1 or a.life==6) then tell('revived') end
    end
    local function downed(linked)
        local life=link.life()
        if life and life.state>=3 and life.state<=5 then
            if not d then
                d={}
                if hidden then -- The screen we hid comes back as it was, for this death.
                    local h=hidden
                    hidden=nil
                    if U.valid(h.widget) then h.widget:SetVisibility(h.was) end
                    log('revive: death screen shown again (a new death)')
                end
            end
        elseif life and (life.state==1 or life.state==6) and d and not d.call then
            d=nil
        end
        if not d then return end
        if d.call then
            if now-d.call>=AFTER then after() end
            return
        end
        if d.done or not linked then return end
        local reason,me,pc,where=blocker(false)
        if reason~=d.said then
            d.said=reason
            if reason then log('revive waits: '..reason) end
        end
        if (not reason or reason=='friend far') and not d.waited then
            d.waited=true
            tell('wait')
        end
        if reason then d.since=nil; return end
        d.since=d.since or now
        if now-d.since>=HOLD then call(me,pc,where) end
    end
    local function friend()
        local m=link.mate()
        if down(m) then
            hers=hers or {}
            local life=link.life()
            if not hers.said and not (life and life.state>=3 and life.state<=5) and same_map() and boss_free() then
                hers.said=true
                tell('down')
            end
        elseif hers and alive(m) then
            hers=nil
            local _,ghost=puppet.anchor()
            local mine=feet()
            if ghost and mine and (ghost.X-mine.X)^2+(ghost.Y-mine.Y)^2+(ghost.Z-mine.Z)^2<=NEAR^2 then
                tell('you_revived')
            end
        end
    end
    -- The cutscene's name while one plays, else nil.
    local function theater()
        local name=nil
        U.each(FindAllOf('SBTheaterLevelSequenceObserver') or {},function(_,ob)
            ob=not name and U.valid(ob)
            local player=ob and weak(ob.Player)
            if player and player:IsPlaying()==true then name=U.text(ob.SequenceName) end
        end)
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
        local _,with=link.friend()
        local linked=(mode=='host' or mode=='guest') and with==true
        guard('revive',downed,linked)
        if linked then guard('friend',friend) else hers=nil end
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
    -- The guest's ask for the pause during the host's cutscene: cutscene_wait=on and the host's ghost on her map.
    function self.cut() return settings.cutscene_wait==true and link.mode()=='guest' and same_map() end
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
