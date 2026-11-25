-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop race: Doro races on a track the player records, on the game thread. online/modes/race/model.lua holds the track
-- file, the rules and the race lines; this file is the game side. coop race record <name> starts a track at EVE's feet
-- and facing, race_key (F9) or coop race cp drops a checkpoint at her feet, coop race save [laps] writes
-- coop-track-<name>.txt beside coop-settings.txt (through core/link.lua: a temporary file, then a rename) and coop race
-- cancel drops the recording. coop race start <name> arms a race on that file as the host, or alone with no friend
-- linked; coop race quit leaves it. With a friend linked, her game answers the host's lines as the guest. In coop
-- loopback with no friend our own lines come back as hers: a second, guest model, run by the loopback ghost's feet,
-- answers them, and its lines go straight to ours. Each player is drawn as a Doro (online/modes/race/doro.lua's look on
-- EVE, online/partner/puppet.lua's Doro mode on the ghost) from the time that side is in the race until it ends. From
-- GO until our own result EVE drives as a car (online/modes/race/drive.lua: the model's velocity and yaw fed to her
-- movement each frame), with the host's driving values, which travel on the drive line (online/modes/race/model.lua),
-- so both players race with the same. In a match round (online/modes/race/match/game.lua starts it) the race has a
-- third role, match: EVE goes to her grid slot, the countdown runs from the round's start, every round player's ghost
-- is a Doro. Our splits and end go to the round (online/modes/race/match/model.lua's racer); coop race start is
-- refused in a match lobby.
-- What a race changes in the game: its own display Doros (online/modes/race/doro.lua's plain actors, collision off: one
-- at the next checkpoint and one at the one after it, or one at the start line before GO), the look's two flags on EVE
-- and, while it drives, four values of her movement component (the native part's, online/modes/race/hold.h), her
-- velocity and her yaw. Never a pawn, a reward, an achievement, an item, a quest or a save: a race gives nothing. It
-- writes its track file only; in a match lobby a match round also teleports EVE onto her slot, at its start and at GO.
-- At GO a racer out of her slot whom SB's chair seats sits out instead of the teleport.
-- Its first Lua error ends the race and its look for this Lua load. The display Doros' paths stay in
-- coop-race-doros.txt while they stand, so the next Lua load (Ctrl+R mid-race) destroys them at its first tick; the
-- native part puts her movement values and tick option back at that load.
local UE=require('UEHelpers')
local U=require('core.unreal')
local Where=require('core.where')
local R=require('online.modes.race.model')
local Mm=require('online.modes.race.match.model')
local Doro=require('online.modes.race.doro')
local Hud=require('online.modes.race.ui.hud')
local clean=require('core.line').clean
local valid,value_of,find=U.valid,U.value_of,U.find
local Race={}
-- A skeletal mesh faces its +Y, so a Doro turned to face a yaw gets this much less, as EVE's own mesh does (a starting
-- value until the game shows it).
local MESH_YAW=-90
-- Fin flag 1: over this horizontal speed in cm/s for FAST_FOR s, not sprinting and not falling (Tachy mode has no
-- reader in the SDK; a starting value), only while the race does not drive her. Flag 2: the game paused or on one of
-- its screens for PAUSE_FOR s.
local FAST,FAST_FOR,PAUSE_FOR=550,1,2
local GONE_FOR=2 -- s with no EVE (a load, the title): she left the map.
local GO_SHOW,MISSED_SHOW=1,2 -- s a banner stays: GO, a missed checkpoint.
local NAME=20 -- Characters of her name shown, as the partner card.
local USE='Use: coop race record <name> | cp | save [laps] | cancel | start <name> | quit'
    ..' | match [status | pick <name>|<number>|random]' -- match: online/modes/race/commands.lua's.
-- coop race drive is a test and tuning tool, left out of USE (online/modes/race/drive.lua's command).
local NAMES='a track name is 1 to 24 of a-z, 0-9, _ and -'

-- A race time as the panel shows it: 1:23.45 (online/modes/race/ui/hud.lua's).
Race.clock=Hud.clock
local function eve()
    local pawn=valid(UE.GetPlayer())
    return pawn and pawn:IsA(find('/Script/SB.SBCharacter')) and pawn or nil
end
local function feet(e)
    local at=value_of(valid(e.Mesh):K2_GetComponentLocation())
    return {x=at.X,y=at.Y,z=at.Z}
end
local why_of=U.why

-- o: log (the [DR] lines), link (nil without the native part: no race), puppet (anchor, her_map, me, doro, emote,
-- drive), look (online/modes/race/doro.lua's Doro.new: on, off, emote, drive, log), drive
-- (online/modes/race/drive.lua's Drive.new), tell(build) (main.lua's notices: build(words) puts one together), night()
-- (a Night Operation run is on), slot() (true on a co-op save, else false and why), paused() (the game paused or on one
-- of its screens, read every 250 ms), settings (main.lua's: race_key, ui_language), store (coop-race-doros.txt
-- through link.store; nil without the native part) and dismount(why) (vehicles/bike/ride.lua's stop: EVE off the bike,
-- which also ends its drive), riding() (whether EVE rides the bike, which drives with its own copy of
-- online/modes/race/drive.lua). No race starts while she rides; the guest's answer to a track line takes her off the
-- bike first. Optional: match_lobby() (we are in a match lobby: coop race start is refused), round_tick() (the match
-- round's 250 ms work, online/modes/race/match/round.lua's tick), round_stop(why) (its stop, at coop off),
-- resting() (SB's own interaction runs on EVE: a hall chair of SB seats her, read at GO of a match race) and
-- saved(name) (a track saved: online/modes/race/wiring.lua adds it to coop-tracks.txt).
function Race.new(o)
    local log,link,puppet,look,tell,drive=o.log,o.link,o.puppet,o.look,o.tell,o.drive
    local store=o.store or {save=function() end,load=function() end,clear=function() end}
    local swept=false -- The Doros an earlier Lua load left: destroyed at the first tick.
    local self={}
    local rec=nil -- The track being recorded: {name, track, at (os.clock), last (her feet), path (cm)}.
    -- The race, while one is armed on this PC: role ('host' or 'guest'), m (race_model's), name (the host's track),
    -- map (the track's, or ours when a guest's track came), with (a friend's: the session's end is a DNF), loop (the
    -- loopback guest's model) and loop_in (our lines echoed for it), inbox (her lines for m), doros (key to display),
    -- banner ({build, color, til}), looked and ghost (what it turned on), the flags for the next tick and their
    -- counters, dnf and ending (quit, map or coop off: the line goes out, then the race closes here), drove (the
    -- driving went on in this start: not again until a false start), pos (our feet),
    -- stop_ms (our time frozen at a DNF), go_clock, go_time, end_clock, end_time (os.clock and os.time at GO and at
    -- our end, for the result line).
    local race=nil
    local failed=nil -- Why the race stopped on an error: none again until the mod reloads.
    local last_id=0
    local away=false -- Paused or on a game screen, as of the last 250 ms read: the HUD hides.
    local function clock() return os.clock()*1000 end
    local function her_name(w)
        local name=clean((link and link.friend()) or '')
        if name=='' then return w.chat.partner end
        if (utf8.len(name) or 0)>NAME then name=name:sub(1,utf8.offset(name,NAME+1)-1)..'…' end
        return name
    end
    -- The HUD (online/modes/race/ui/hud.lua): its groups once self.hud adds them.
    local H=Hud.new({clock=clock,name=her_name,anchor=function() return puppet.anchor() end})
    local shown,sound=H.shown,H.sound
    -- A command closes the race here (coop race quit, coop off): its reply says it, so no notice. A map change does
    -- not: its DNF or the cancel is told, as the HUD goes with the race that frame.
    local function quiet(r) return r.ending=='quit' or r.ending=='coop off' end
    -- A banner on the HUD (build(words) its text) for seconds, or until replaced; a notice instead while the kit is
    -- off, unless notice is false or a command closes the race.
    local function banner(r,build,seconds,color,notice)
        r.banner,r.wrong={build=build,color=color,til=seconds and os.clock()+seconds},nil
        if notice~=false and not quiet(r) and not shown() then tell(build) end
    end
    -- The Doros' actor paths on one line, tab-separated, for the next Lua load; the file cleared once none stands.
    local function keep(r)
        local paths={}
        for _,d in pairs(r.doros) do paths[#paths+1]=d.path end
        if paths[1] then store.save(table.concat(paths,'\t')) else store.clear() end
    end
    -- The ghosts the race drew as Doros: her ghost (puppet) in a session, the round's other players' in a match.
    local function ghosts(r) return r.role=='match' and r.ghosts or {puppet} end
    -- EVE onto slot k of track t, facing the track, her centre her mesh's height over the slot (online/lobby/sbo.lua's
    -- seat rule): true, or false and why.
    local function put(e,t,k)
        local s,up=R.slot(t,k),-value_of(valid(e.Mesh).RelativeLocation).Z
        if e:K2_TeleportTo({X=s.x,Y=s.y,Z=s.z+up},{Pitch=0,Yaw=t.grid.yaw,Roll=0})==false then
            return false,'the game refused the teleport to slot '..(k+1)
        end
        return true
    end
    -- The race gone on this PC: its Doros (one that would not go stays in coop-race-doros.txt for the next Lua load),
    -- the look and her ghost's Doro mode if it turned them on, the HUD.
    local function close(r,why)
        if race==r then race=nil end
        if drive.racing() then
            local ok,message=pcall(drive.off,'race '..why)
            log(ok and message or 'drive: '..tostring(message))
        end
        pcall(look.drive,nil)
        for _,g in ipairs(ghosts(r)) do pcall(g.drive,nil) end
        for key,d in pairs(r.doros) do
            if pcall(Doro.remove,d) then r.doros[key]=nil end
        end
        pcall(keep,r)
        if r.ghost then
            for _,g in ipairs(ghosts(r)) do
                pcall(g.emote,nil)
                pcall(g.doro,false)
            end
        end
        if r.looked then
            pcall(look.emote,nil)
            local ok,_,message=pcall(look.off,'race '..why)
            if ok and message then log(message) end
        end
        pcall(H.hide)
        log(string.format('race %s closed (%s)',tostring(r.m.id or '-'),why))
    end
    -- The race gone on an error: our quit line (an abort before GO, else our DNF) goes out first, so the other side
    -- does not wait for a line that never comes.
    local function fail(e)
        failed=why_of(e)
        local r=race
        if r then
            pcall(function()
                if r.role=='match' then for _,l in ipairs((Mm.frame(r.m,{dnf='quit'},clock()))) do r.line(l) end
                else for _,l in ipairs((R.tick(r.m,{dnf='quit'},clock()))) do link.race(l) end end
            end)
            pcall(close,r,'error')
        end
        return false,'the race stopped on an error until the mod reloads: '..failed
    end
    local mine=Hud.mine
    -- The race_model events of one frame: notices, banners, sounds, the look and her ghost, the results.
    local function event(r,e)
        local w,m=e.what,r.m
        if w=='joined' then -- Her have line: she races, her ghost as a Doro.
            r.ghost=true
            local _,why=puppet.doro(true,look.log)
            log('race '..m.id..': she joined'..(why and '; '..why or ''))
        elseif w=='refused' then
            log('race '..m.id..' refused: '..e.why)
            local group=r.role=='host' and 'refused' or 'declined'
            tell(function(t) return t.race[group][e.why]:format(her_name(t)) end)
        elseif w=='armed' then -- The guest's: the host's track came whole and checked.
            local ok,why=look.on()
            r.looked=ok
            if not ok then log('race '..m.id..': no look: '..tostring(why)) end
            r.ghost=true
            local _,ghost_why=puppet.doro(true,look.log)
            if ghost_why then log(ghost_why) end
            log('race '..m.id..' joined')
            tell(function(t) return t.race.armed_guest:format(her_name(t)) end)
        elseif w=='out' then -- She left the race (her PC closed it): her ghost is herself again.
            if r.ghost then
                r.ghost=false
                pcall(puppet.doro,false)
            end
            tell(function(t) return t.race.out:format(her_name(t)) end)
        elseif w=='cancelled' then
            if not quiet(r) then
                tell(function(t) return e.why=='crowd' and t.race.why.crowd or t.race.cancelled end)
            end
        elseif w=='count' then -- 3, 2, 1: on the HUD only, as notices they would come late.
            banner(r,function() return tostring(e.n) end,nil,'beta',false)
            sound('move')
        elseif w=='go' then
            local e=r.role=='match' and r.pos and not R.in_slot(m.track,m.slot,r.pos,true) and eve()
            -- SB's chair seated her during the countdown: a teleport would land while its interaction still runs on
            -- her (match/game.lua's sit-out at the start). She sits out: her DNF quit goes to the round, the race
            -- closes here.
            if e and o.resting and o.resting() then
                log('race '..m.id..': out of slot '..(m.slot+1)..' at GO: sit out: SB\'s chair seats EVE')
                for _,l in ipairs((Mm.frame(m,{dnf='quit'},clock()))) do r.line(l) end
                tell(function(t) return t.race.match.seat end)
                return close(r,'seat')
            end
            if e then
                local ok,why=put(e,m.track,m.slot)
                -- The runner's first step starts from her slot: the way back is no move of hers.
                if ok then m.prev=R.slot(m.track,m.slot) end
                log('race '..m.id..': out of slot '..(m.slot+1)..' at GO: '..(ok and 'put back' or why))
            end
            r.go_clock,r.go_time=os.clock(),os.time()
            banner(r,function(t) return t.race.go end,GO_SHOW,'beta')
            sound('select')
            log('race '..m.id..' go')
        elseif w=='false_start' then
            r.banner,r.drove=nil,nil
            tell(function(t) return t.race.false_start end)
            sound('alert')
        elseif w=='cp' then sound('select')
        elseif w=='missed' then
            banner(r,function(t) return t.race.missed:format(e.i) end,MISSED_SHOW,'warn')
            sound('alert')
        elseif w=='wrong_way' then
            banner(r,function(t) return t.race.wrong_way end,nil,'warn')
            r.wrong=true
            sound('alert')
        elseif w=='right_way' then
            if r.wrong then r.banner,r.wrong=nil,nil end
        elseif w=='fin' or w=='dnf' then
            r.end_clock,r.end_time=os.clock(),os.time()
            if w=='fin' then
                banner(r,function(t) return t.race.finished end,nil,'beta')
                sound('select')
            else
                r.stop_ms=m.t_go and clock()-m.t_go or 0
                banner(r,function(t) return t.race.dnf end,nil,'error')
                if not quiet(r) then tell(function(t) return t.race.why[e.why] end) end
            end
            log(string.format('race %d %s %s',m.id,w,w=='fin' and Race.clock(e.ms) or e.why))
        elseif w=='results' then
            r.banner=nil
            local ours,hers
            for _,entry in ipairs(e.list) do
                if entry.who==mine(r) then ours=entry else hers=entry end
            end
            local function emote(entry) return entry and entry.pos==1 and 'win' or 'lose' end
            if r.looked then look.emote(emote(ours)) end
            if r.ghost and r.role=='match' then
                for _,entry in ipairs(e.list) do
                    if r.by_id[entry.who] then r.by_id[entry.who].emote(emote(entry)) end
                end
            elseif r.ghost and hers then puppet.emote(emote(hers)) end
            -- A match round's place as notices while the kit is off (a DNF said its own): ours, or not ranked, then a
            -- new best.
            if r.role=='match' and not shown() and not (ours and not ours.pos) then
                tell(function(t) return ours and t.race.placed:format(ours.pos,#e.list) or t.race.unranked end)
                if r.heard and r.heard.best then tell(function(t) return t.race.best end) end
            end
            local now,t=os.clock(),os.time()
            log(string.format('result id=%d track=%s ms=%s clock=%.3f time=%d flags=%d rank=%s',m.id,r.name or '-',
                m.me.ms and tostring(m.me.ms) or '-',(r.end_clock or now)-(r.go_clock or now),
                (r.end_time or t)-(r.go_time or t),m.me.flags,ours and ours.pos and tostring(ours.pos) or '-'))
        end
    end
    -- The Doros the race shows now: before GO one at the start line's centre; in our race the next checkpoint's and the
    -- one after it, each facing the checkpoint before it, the finish's looping Evade; none once our race is over.
    local function wanted(r)
        local m,list=r.m,{}
        local t=m.track
        if not t then return list end
        local g=t.grid
        if m.phase=='ready' or m.phase=='countdown' then
            list.grid={at=g,yaw=g.yaw,asset='idle'}
            return list
        end
        local run=m.phase=='race' and m.runner
        if not run or run.done then return list end
        local n,laps=#t.cps,t.laps
        local function add(i,lap)
            local c=t.cps[i]
            local prev=i>1 and t.cps[i-1] or lap>1 and t.cps[n] or g
            local finish=i==n and lap==laps
            list[i..(finish and ' finish' or '')]={at=c,yaw=math.deg(math.atan(prev.y-c.y,prev.x-c.x)),
                asset=finish and 'evade' or 'idle'}
        end
        add(run.next,run.lap)
        if run.next<n then add(run.next+1,run.lap) elseif run.lap<laps then add(1,run.lap+1) end
        return list
    end
    local function place_doros(r,e)
        local want,changed=wanted(r),false
        for key,d in pairs(r.doros) do
            if not want[key] then
                r.doros[key],changed=nil,true
                Doro.remove(d)
            end
        end
        for key,s in pairs(e and want or {}) do
            if not r.doros[key] then
                local d=Doro.spawn(e:GetWorld(),{X=s.at.x,Y=s.at.y,Z=s.at.z},{Pitch=0,Yaw=s.yaw+MESH_YAW,Roll=0})
                r.doros[key],changed=d,true
                Doro.apply(d,{asset=s.asset,loop=true,rate=1})
            end
        end
        if changed then keep(r) end
    end
    -- The driving: on at GO with the race's values (the host's, from his drive line), off once our own result is in or
    -- the race left the race phase (a false start); self.steer drives each frame meanwhile. Once it went off by itself
    -- (her EVE gone), not again in this start.
    local function sync_drive(r)
        local m=r.m
        if m.phase=='race' and not (m.me.ms or m.me.why) then
            if not r.drove then
                r.drove=true
                local ok,why=drive.on(m.track.drive,'race')
                if not ok then error('no driving: '..why,0) end
                for _,g in ipairs(ghosts(r)) do g.drive(m.track.drive.top) end
            end
        elseif drive.racing() then
            log(drive.off('race '..(m.me.ms and 'fin' or m.me.why or m.phase)))
            look.drive(nil)
        end
    end
    -- One frame of the race: the model from EVE's feet and her lines (and the loopback guest's), our lines to the
    -- native part, the events, the driving on or off, the Doros, the HUD. A race that ends here (quit, map, coop off)
    -- sends its line first.
    local function frame(r)
        local now=clock()
        local e=eve()
        local pos=e and feet(e)
        r.pos=pos or r.pos
        local lines,flags,dnf,left=r.inbox,r.flags,r.dnf,r.left
        r.inbox,r.flags,r.dnf,r.left={},0,nil,nil
        local out,ev
        if r.role=='match' then
            local news=r.news()
            r.heard=news -- For the HUD: the racers' places, the results still to come, a new best.
            out,ev=Mm.frame(r.m,{pos=pos,flags=flags,dnf=dnf,fin=news.fin,list=news.list},now)
            for _,l in ipairs(out) do r.line(l) end
        else
            out,ev=R.tick(r.m,{pos=pos,lines=lines,rtt=link.ping(),map=r.map,flags=flags,dnf=dnf,left=left},now)
            for _,line in ipairs(out) do link.race(line) end
        end
        if r.loop then
            local _,f=puppet.anchor()
            local gout=R.tick(r.loop,{pos=f and {x=f.X,y=f.Y,z=f.Z},lines=r.loop_in,map=r.map,left=left},now)
            r.loop_in={}
            for _,line in ipairs(gout) do r.inbox[#r.inbox+1]=line end -- Straight to ours, at the next frame.
        end
        for _,item in ipairs(ev) do
            event(r,item)
            if race~=r then break end
        end
        link.race_flush()
        if race~=r then return end
        if r.ending or r.m.phase=='over' then return close(r,r.ending or 'over') end
        sync_drive(r)
        place_doros(r,e)
        H.draw(r,away)
    end
    -- Every 250 ms: the session's end (a DNF left), a third player in it (a DNF crowd: Doro races are for 2), a map
    -- change or EVE gone 2 s (a DNF map, then the race closes here). Then the fin flags.
    local function slow(r)
        local paused=o.paused()==true
        away=paused
        if r.with and link.chatting()==false then r.left=true
        elseif r.with and link.crowd()>1 then r.left='crowd' end
        if r.loop and not link.loopback() then r.left=true end
        local me=Where.me()
        r.gone=me and 0 or r.gone+0.25
        if not r.ending and (me and r.map and me.map~=r.map or r.gone>=GONE_FOR) then r.dnf,r.ending='map','map' end
        local m=r.m
        if m.phase~='race' or m.me.ms or m.me.why then return end
        r.paused_for=paused and r.paused_for+0.25 or 0
        if r.paused_for>=PAUSE_FOR then r.flags=r.flags|2 end
        drive.slow()
        local e=eve()
        if not e or r.drove then return end
        local v=value_of(e:GetVelocity())
        local fast=math.sqrt(v.X*v.X+v.Y*v.Y)>FAST and e:IsSprint()~=true
            and valid(e.CharacterMovement):IsFalling()~=true
        r.fast_for=fast and r.fast_for+0.25 or 0
        if r.fast_for>=FAST_FOR then r.flags=r.flags|1 end
    end
    local function new_race(role,m,fields)
        local r={role=role,m=m,inbox={},doros={},flags=0,gone=0,paused_for=0,fast_for=0}
        for k,v in pairs(fields) do r[k]=v end
        race=r
        return r
    end
    local function start(name)
        if failed then return false,'the race stopped on an error ('..failed..'); none until the mod reloads' end
        if not R.name_ok(name) then return false,NAMES end
        if race then return false,'a race is on: coop race quit leaves it' end
        if rec then return false,'a track is being recorded: coop race save or coop race cancel first' end
        if o.match_lobby and o.match_lobby() then return false,'In a match lobby, races start from the lobby menu.' end
        if link.mode()=='guest' then return false,'the host starts a race; yours comes when the host starts one' end
        local others=link.crowd()
        if others>1 then return false,'Doro races are for 2 players at most; this session has '..(others+1) end
        if o.night() then return false,'Night Operation is running: coop nightop stop ends it' end
        if drive.why()=='bike' or o.riding and o.riding() then
            return false,'EVE rides the bike: coop bike gets her off first'
        end
        if drive.active() then return false,'the drive probe runs: coop race drive off ends it' end
        local e=eve()
        if not e then return false,'no EVE in the world' end
        local file=R.file(name)
        local text=link.read_file(file)
        if not text then return false,'no '..file..' beside coop-settings.txt' end
        local t,why=R.parse_track(text)
        if not t then return false,file..' is not a track ('..why..')' end
        local map=U.map_of(e)
        if t.map~=map then return false,file..' is on '..t.map..'; you are on '..map end
        local _,linked=link.friend()
        local with=linked==true
        local hers=puppet.her_map()
        if with and not hers then return false,"your friend's map is not known yet: try again in a moment" end
        if with and hers~=t.map then return false,'your friend is on '..hers..'; the track is on '..t.map end
        local loop=not with and link.loopback()==true
        local ok,look_why=look.on()
        if not ok then return false,look_why end
        last_id=math.max(os.time(),last_id+1)
        local solo=not (with or loop)
        local r=new_race('host',R.host(t,last_id,clock(),solo,drive.values()),{name=name,map=t.map,with=with,
            looked=true})
        if loop then r.loop,r.loop_in=R.guest(),{} end
        tell(function(w) return w.race.armed end)
        log(string.format('race %d armed on %s: %d checkpoints, %d laps, %s',last_id,file,#t.cps,t.laps,
            with and 'with a friend' or loop and 'in loopback' or 'alone'))
        return true,'Race '..name..' armed: walk to your start (its marker); the countdown starts once every racer '
            ..'stands in their slot.'
    end
    local function record(name)
        if not R.name_ok(name) then return false,NAMES end
        if race then return false,'a race is on: coop race quit leaves it' end
        local e=eve()
        if not e then return false,'no EVE in the world' end
        local at=feet(e)
        rec={name=name,track=R.record(U.map_of(e),at,value_of(e:K2_GetActorRotation()).Yaw),at=os.clock(),last=at,
            path=0}
        local key=o.settings.race_key
        key=key.key and key.name or 'coop race cp'
        tell(function(w) return w.race.recording:format(name,key) end)
        return true,'Recording track '..name..' from here: '..key..' or coop race cp at each checkpoint, then coop '
            ..'race save [laps] (coop race cancel drops it).'
    end
    local function drop()
        if not rec then return false,'no track is being recorded: coop race record <name> starts one' end
        local e=eve()
        if not e then return false,'no EVE in the world' end
        local map=U.map_of(e) -- A recording that left its map keeps what it had: saved, it is a track of that map.
        if map~=rec.track.map then
            tell(function(w) return w.race.other_map end)
            return false,'this track is on '..rec.track.map..'; you are on '..map
        end
        local ok,why=R.drop(rec.track,feet(e))
        if not ok then
            tell(function(w) return why=='full' and w.race.full or w.race.too_close end)
            return false,why=='full' and 'the track has 64 checkpoints already: coop race save writes it'
                or 'too close: 15 m at least from the checkpoint before (the start for the first)'
        end
        local n=#rec.track.cps
        local c=rec.track.cps[n]
        tell(function(w) return w.race.dropped:format(n) end)
        return true,string.format('checkpoint %d at %d %d %d',n,c.x,c.y,c.z)
    end
    local function save(text)
        if not rec then return false,'no track is being recorded: coop race record <name> starts one' end
        local laps=text==nil and 1 or text:match('^%d$') and tonumber(text)
        if not laps or laps<1 or laps>R.MAX_LAPS then return false,'Use: coop race save [laps 1-9]' end
        local t,name=rec.track,rec.name
        t.laps=laps
        local out,why=R.format_track(t)
        t.laps=1
        if not out then
            return false,({checkpoints='a track needs 2 checkpoints at least',
                laps='laps above 1 need the last checkpoint within 30 m of the start'})[why] or why
        end
        local file=R.file(name)
        local ok,write_why=link.write_file(file,out)
        if not ok then return false,write_why end
        log(string.format('track %s saved: %d checkpoints, %d laps, path %.0f m in %.0f s',name,#t.cps,laps,
            rec.path/100,os.clock()-rec.at))
        rec=nil
        if o.saved then o.saved(name) end
        tell(function(w) return w.race.saved:format(name,#t.cps) end)
        return true,'Track saved as '..file..' beside coop-settings.txt: coop race start '..name..' races it.'
    end
    -- record <name>, cp, save [laps], cancel, start <name>, quit; drive (online/modes/race/drive.lua's).
    function self.command(sub,a,extra)
        if not link then return false,'the race needs the native part' end
        if sub=='drive' then
            if a=='probe' and race then return false,'a race is armed: coop race quit leaves it' end
            local ok,why=drive.command(a,extra)
            if not drive.active() then pcall(look.drive,nil) end -- The probe off: the look walks again.
            return ok,why
        end
        if extra~=nil then return false,USE end
        if sub=='record' and a then return record(a) end
        if sub=='start' and a then return start(a) end
        if sub=='save' then return save(a) end
        if a~=nil then return false,USE end
        if sub=='cp' then return drop() end
        if sub=='cancel' then
            if not rec then return false,'no track is being recorded' end
            rec=nil
            return true,'Recording dropped; nothing written.'
        end
        if sub=='quit' then
            local r=race
            if not r then return false,'no race to quit' end
            r.dnf,r.ending='quit','quit'
            return true,'You left the race.'
        end
        return false,USE
    end
    -- race_key: a checkpoint while a track is recorded; nothing otherwise (nil).
    function self.key()
        if rec then return drop() end
    end
    -- A race line of hers (link.take_chat's {race=}): to the race armed here (the loopback guest's while it runs), or,
    -- with none, a track line arms the guest's side. Never on the session's host (only a host sends a track). During
    -- a Night Operation run the guest does not answer (the host races alone after 10 s); off a co-op save she answers
    -- "no save" and stays out.
    function self.receive(text)
        if failed then return end
        local r=race
        if r and r.loop then r.loop_in[#r.loop_in+1]=text return end
        if r then r.inbox[#r.inbox+1]=text return end
        local l=R.decode(text)
        if not (l and l.what=='track' and link) or link.mode()=='host' then return end -- A line of a race that ended here.
        if o.night() then return log('race '..l.id..' from the host not answered: Night Operation is running') end
        if not o.slot() then
            link.race(('have %d no save'):format(l.id))
            log('race '..l.id..' from the host refused: not a co-op save')
            return tell(function(w) return w.race.declined.save:format(her_name(w)) end)
        end
        -- Her movement whole until GO: off the bike, or the probe off and the look out of its driving.
        if drive.why()=='bike' or o.riding and o.riding() then o.dismount('the host started a race')
        elseif drive.active() then
            log(drive.off('the host started a race'))
            pcall(look.drive,nil)
        end
        local me=Where.me()
        r=new_race('guest',R.guest(),{map=me and me.map,with=true})
        r.inbox[1]=text
    end
    -- Whether a race is armed here: main.lua reads the inbox each frame meanwhile, and coop nightop start refuses.
    function self.armed() return race~=nil end
    -- A match round's race (online/modes/race/match/game.lua's start): track t named name, the round's seed, our slot k
    -- from 0, the round's other players' ghosts ({[SteamID]=online/partner/puppet.lua's ghost}), line(l) for each of
    -- our texts to the round and news() ({fin=, list=} from it, each frame). An earlier match race of ours closes
    -- first, not ranked. EVE goes to her slot facing the track, the look goes on her and the Doro mode on each ghost,
    -- then the countdown runs. true, or false, the sit-out key and why: busy (a track being recorded or the drive probe
    -- on), refused (no EVE, the teleport refused, the race stopped on an error).
    function self.match(t,name,seed,k,by_id,line,news)
        if failed then return false,'refused','the race stopped on an error ('..failed..')' end
        if race and race.role=='match' then pcall(close,race,'replaced') end
        if race then return false,'busy','a race is on' end
        if rec then return false,'busy','a track is being recorded' end
        if drive.active() then return false,'busy','the drive probe runs' end
        local e=eve()
        if not e then return false,'refused','no EVE in the world' end
        local ok,why=put(e,t,k)
        if not ok then return false,'refused',why end
        local looked,look_why=look.on()
        if not looked then log('race '..seed..': no look: '..tostring(look_why)) end
        local list={}
        for _,g in pairs(by_id) do
            list[#list+1]=g
            local _,ghost_why=g.doro(true,look.log)
            if ghost_why then log(ghost_why) end
        end
        new_race('match',Mm.racer(t,seed,k,clock()),{name=name,map=t.map,looked=looked,ghost=true,ghosts=list,
            by_id=by_id,line=line,news=news})
        return true
    end
    -- The match round ended for our race (online/modes/race/match/game.lua's stop): it closes here with no line.
    function self.match_stop(why)
        local r=race
        if r and r.role=='match' then pcall(close,r,why) end
    end
    -- The Doros an earlier Lua load left standing (coop-race-doros.txt): each destroyed if it still is one.
    local function sweep()
        local line=store.load()
        if not line then return end
        local n=0
        for p in line:gmatch('[^\t]+') do
            local ok,gone=pcall(Doro.sweep,p)
            if ok and gone then n=n+1 end
        end
        store.clear()
        log(('race: %d display Doros an earlier Lua load left destroyed'):format(n))
    end
    -- Each frame before the native tick, so that the pose it captures and the look have the yaw the driving writes
    -- this frame: the race's driving from GO to our result, or the drive probe's (never the bike's, which
    -- vehicles/bike/ride.lua steers). Its first error ends the race (as a frame's) or the probe: false, why.
    function self.steer()
        if not drive.active() or drive.why()=='bike' then return end
        local ok,e=pcall(function() look.drive(drive.tick()) end)
        if ok then return end
        if race then return fail(e) end
        local message=drive.off('error')
        pcall(look.drive,nil)
        return false,'the drive probe stopped on an error: '..why_of(e)..'; '..message
    end
    -- Each frame, after the ghost and the look are placed. A first error ends the race: false, why.
    function self.tick()
        if not swept then
            swept=true
            pcall(sweep)
        end
        local r=race
        if not r then return end
        local ok,e=pcall(frame,r)
        if not ok then return fail(e) end
    end
    -- Every 250 ms: the match round's work first (its first error logged once a Lua load; the race goes on), then a
    -- track being recorded adds the path EVE ran.
    local round_failed=false
    function self.slow()
        if o.round_tick then
            local ok,e=pcall(o.round_tick)
            if not ok and not round_failed then
                round_failed=true
                log('match round: error (logged once until the mod reloads): '..why_of(e))
            end
        end
        if rec then
            pcall(function()
                local e=eve()
                if not e then return end
                local f,l=feet(e),rec.last
                rec.path,rec.last=rec.path+math.sqrt((f.x-l.x)^2+(f.y-l.y)^2+(f.z-l.z)^2),f
            end)
        end
        local r=race
        if not r then
            if drive.why()=='bike' then return end -- vehicles/bike/ride.lua's 250 ms check runs it.
            local ok,e=pcall(drive.slow)
            if ok then return end
            local message=drive.off('error')
            pcall(look.drive,nil)
            return false,'the drive probe stopped on an error: '..why_of(e)..'; '..message
        end
        local ok,e=pcall(slow,r)
        if not ok then return fail(e) end
    end
    -- coop off: a recording dropped, a race left (its DNF or abort line out first) and closed, the drive probe off,
    -- then the match round stopped. A bike drive stays: main.lua's off handler calls vehicles/bike/ride.lua's stop
    -- first.
    function self.stop()
        rec=nil
        local r=race
        if not r then
            if drive.active() and drive.why()~='bike' then log(drive.off('coop off')) end
            pcall(look.drive,nil)
        else
            r.dnf,r.ending=r.dnf or 'quit','coop off'
            if not failed then pcall(frame,r) end
            if race==r then pcall(close,r,'coop off') end
        end
        if o.round_stop then pcall(o.round_stop,'coop off') end -- After our race's DNF went to the round.
    end
    -- The HUD's groups on the Uplink kit, before its first build (main.lua, after Night Operation's): h is {kit,
    -- theme=ui.THEME, settings=main.lua's}.
    function self.hud(h) H.add(h) end
    return self
end
return Race
