-- coop race: Doro races on a track the player records, on the game thread. race_model.lua holds the track file, the
-- rules and the race lines; this file is the game side. coop race record <name> starts a track at EVE's feet and
-- facing, race_key (F9) or coop race cp drops a checkpoint at her feet, coop race save [laps] writes
-- coop-track-<name>.txt beside coop-settings.txt (through link.lua: a temporary file, then a rename) and coop race
-- cancel drops the recording. coop race start <name> arms a race on that file as the host, or alone with no friend
-- linked; coop race quit leaves it. With a friend linked, her game answers the host's lines as the guest. In coop
-- loopback with no friend our own lines come back as hers: a second, guest model, run by the loopback ghost's feet,
-- answers them, and its lines go straight to ours. Each player is drawn as a Doro (doro.lua's look on EVE, puppet.lua's
-- Doro mode on the ghost) from the time that side is in the race until it ends.
-- What a race changes in the game: its own display Doros (doro.lua's plain actors, collision off: one at the next
-- checkpoint and one at the one after it, or one at the start line before GO) and the look's two flags on EVE. Never a
-- pawn, a reward, an achievement, an item, a quest or a save: a race gives nothing and writes nothing but its track
-- file. Its first Lua error ends the race and its look for this Lua load.
local UE=require('UEHelpers')
local U=require('unreal')
local R=require('race_model')
local Doro=require('doro')
local P=require('partner')
local T=require('ui_text')
local clean=require('chat').clean
local valid,value_of,find=U.valid,U.value_of,U.find
local Race={}
local ABOVE=220 -- cm over a checkpoint's centre (EVE's feet there) for its marker: about her head.
-- A skeletal mesh faces its +Y, so a Doro turned to face a yaw gets this much less, as EVE's own mesh does (a starting
-- value until the game shows it).
local MESH_YAW=-90
-- Fin flag 1: over this horizontal speed in cm/s for FAST_FOR s, not sprinting and not falling (Tachy mode has no
-- reader in the SDK; a starting value). Flag 2: the game paused or on one of its screens for PAUSE_FOR s.
local FAST,FAST_FOR,PAUSE_FOR=550,1,2
local GONE_FOR=2 -- s with no EVE (a load, the title): she left the map.
local GO_SHOW,MISSED_SHOW=1,2 -- s a banner stays: GO, a missed checkpoint.
local NAME=20 -- Characters of her name shown, as the partner card.
-- The HUD in the kit's layout units (3840 by 2160). The panel and, in its place once the race ends, the results at the
-- top centre, where Night Operation's card goes (a race never arms during a run); the banner over the middle; the
-- marker and the edge arrow as the partner's (partner.lua), in Beta blue.
local HUD_W,PANEL_H,RESULT_H,HUD_Y=1040,160,330,96
local BANNER_W,BANNER_H,BANNER_Y=1600,160,520
local MW,MH,AW,AH,AC=320,120,160,180,80
local MIDDLE,LEFT,RIGHT={X=0.5,Y=0.5},{X=0,Y=0.5},{X=1,Y=0.5}
local GROUPS={'race_panel','race_results','race_banner','race_marker','race_arrow'}
local USE='Use: coop race record <name> | cp | save [laps] | cancel | start <name> | quit'
local NAMES='a track name is 1 to 24 of a-z, 0-9, _ and -'

-- A race time as the panel shows it: 1:23.45.
function Race.clock(ms)
    local cs=math.max(0,math.floor(ms/10))
    return string.format('%d:%02d.%02d',cs//6000,cs//100%60,cs%100)
end
-- The panel's line in words w: the time, then CP, LAP and POS, two spaces apart.
function Race.line(w,ms,cp,cps,lap,laps,pos,of)
    local r=w.race
    return Race.clock(ms)..'  '..r.cp:format(cp,cps)..'  '..r.lap:format(lap,laps)..'  '..r.pos:format(pos,of)
end
local function eve()
    local pawn=valid(UE.GetPlayer())
    return pawn and pawn:IsA(find('/Script/SB.SBCharacter')) and pawn or nil
end
local function feet(e)
    local at=value_of(valid(e.Mesh):K2_GetComponentLocation())
    return {x=at.X,y=at.Y,z=at.Z}
end
local function why_of(e) return (tostring(e):gsub('^.-:%d+: ','')) end -- Without the file and line.

-- o: log (the [DR] lines), link (nil without the native part: no race), puppet (anchor, her_map, me, doro, emote), look
-- (doro.lua's Doro.new: on, off, emote, log), tell(build) (main.lua's notices: build(words) puts one together), night()
-- (a Night Operation run is on), slot() (true on a co-op save, else false and why), paused() (the game paused or on one
-- of its screens, read every 250 ms) and settings (main.lua's: race_key, ui_language).
function Race.new(o)
    local log,link,puppet,look,tell=o.log,o.link,o.puppet,o.look,o.tell
    local self={}
    local rec=nil -- The track being recorded: {name, track, at (os.clock), last (her feet), path (cm)}.
    -- The race, while one is armed on this PC: role ('host' or 'guest'), m (race_model's), name (the host's track),
    -- map (the track's, or ours when a guest's track came), with (a friend's: the session's end is a DNF), loop (the
    -- loopback guest's model) and loop_in (our lines echoed for it), inbox (her lines for m), doros (key to display),
    -- banner ({build, color, til}), looked and ghost (what it turned on), the flags for the next tick and their
    -- counters, dnf and ending (quit, map or coop off: the line goes out, then the race closes here), pos (our feet),
    -- stop_ms (our time frozen at a DNF), go_clock, go_time, end_clock, end_time (os.clock and os.time at GO and at
    -- our end, for the result line).
    local race=nil
    local failed=nil -- Why the race stopped on an error: none again until the mod reloads.
    local last_id=0
    local hud=nil -- self.hud's {kit, theme, settings}.
    local away=false -- Paused or on a game screen, as of the last 250 ms read: the HUD hides.
    local picked,lang,words,was_on=nil,nil,T.en,false
    local function clock() return os.clock()*1000 end
    local function shown() return hud~=nil and not hud.kit.off() end
    local function sound(name) if hud then hud.kit.sound(name) end end
    local function her_name(w)
        local name=clean((link and link.friend()) or '')
        if name=='' then return w.chat.partner end
        if (utf8.len(name) or 0)>NAME then name=name:sub(1,utf8.offset(name,NAME+1)-1)..'…' end
        return name
    end
    -- A banner on the HUD (build(words) its text) for seconds, or until replaced; a notice instead while the kit is
    -- off, unless notice is false or the race is closing here (its reply says it).
    local function banner(r,build,seconds,color,notice)
        r.banner,r.wrong={build=build,color=color,til=seconds and os.clock()+seconds},nil
        if notice~=false and not r.ending and not shown() then tell(build) end
    end
    -- The race gone on this PC: its Doros, the look and her ghost's Doro mode if it turned them on, the HUD.
    local function close(r,why)
        if race==r then race=nil end
        for key,d in pairs(r.doros) do
            r.doros[key]=nil
            pcall(Doro.remove,d)
        end
        if r.ghost then
            pcall(puppet.emote,nil)
            pcall(puppet.doro,false)
        end
        if r.looked then
            pcall(look.emote,nil)
            local ok,_,message=pcall(look.off,'race '..why)
            if ok and message then log(message) end
        end
        if hud then pcall(function() for _,g in ipairs(GROUPS) do hud.kit.show(g,false) end end) end
        log(string.format('race %s closed (%s)',tostring(r.m.id or '-'),why))
    end
    local function fail(e)
        failed=why_of(e)
        local r=race
        if r then pcall(close,r,'error') end
        return false,'the race stopped on an error until the mod reloads: '..failed
    end
    local function mine(r) return r.role=='host' and 'host' or 'guest' end
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
            if not r.ending then tell(function(t) return t.race.cancelled end) end
        elseif w=='count' then -- 3, 2, 1: on the HUD only, as notices they would come late.
            banner(r,function() return tostring(e.n) end,nil,'beta',false)
            sound('move')
        elseif w=='go' then
            r.go_clock,r.go_time=os.clock(),os.time()
            banner(r,function(t) return t.race.go end,GO_SHOW,'beta')
            sound('select')
            log('race '..m.id..' go')
        elseif w=='false_start' then
            r.banner=nil
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
                if not r.ending then tell(function(t) return t.race.why[e.why] end) end
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
            if r.ghost and hers then puppet.emote(emote(hers)) end
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
        local want=wanted(r)
        for key,d in pairs(r.doros) do
            if not want[key] then
                r.doros[key]=nil
                Doro.remove(d)
            end
        end
        if not e then return end
        for key,s in pairs(want) do
            if not r.doros[key] then
                local d=Doro.spawn(e:GetWorld(),{X=s.at.x,Y=s.at.y,Z=s.at.z},{Pitch=0,Yaw=s.yaw+MESH_YAW,Roll=0})
                r.doros[key]=d
                Doro.apply(d,{asset=s.asset,loop=true,rate=1})
            end
        end
    end
    -- The HUD each frame: the panel (the time, CP, LAP and POS, or the wait for her) or the results in its place, the
    -- banner, and the marker on our start before GO, then on the next checkpoint (the edge arrow when it is off screen
    -- or behind). All hidden while the game is paused or on one of its screens. Its words follow the game's language
    -- unless ui_language=english, picked again at each build of the kit's root.
    local function draw(r)
        if not hud or hud.kit.off() then return end
        local kit=hud.kit
        local panel=kit.view('race_panel')
        if panel and (panel~=picked or hud.settings.ui_language~=lang) then
            picked,lang=panel,hud.settings.ui_language
            words=T.pick(kit.language(),lang)
        end
        local w,m=words,r.m
        local t=m.track
        local up=t~=nil and not away
        local results=up and m.phase=='results'
        kit.show('race_panel',up and not results)
        kit.show('race_results',results)
        local b=r.banner
        if b and b.til and os.clock()>=b.til then r.banner,b=nil,nil end
        kit.show('race_banner',up and b~=nil)
        local bv=kit.view('race_banner')
        if bv and b then
            bv.text.set(b.build(w))
            bv.text.color(hud.theme[b.color] or hud.theme.text)
        end
        if panel and up and not results then
            local n,run,me,her=#t.cps,m.runner,m.me,m.her
            local ms=me.ms or r.stop_ms or (m.phase=='race' and clock()-m.t_go) or 0
            local cp=me.ms and n or run and run.next-1 or 0
            local lap=math.min(run and run.lap or 1,t.laps)
            local _,her_feet=puppet.anchor()
            local pos,of=R.place(m,her_feet and {x=her_feet.X,y=her_feet.Y,z=her_feet.Z})
            panel.title.set(w.race.title)
            if m.phase=='ready' and me.ready and her.joined and not her.ready and not her.out then
                panel.line.set(w.race.waiting:format(her_name(w)))
            else
                panel.line.set(Race.line(w,ms,cp,n,lap,t.laps,pos,of))
            end
        end
        if results then
            local res=kit.view('race_results')
            if res then
                local f,flags=m.me.flags,{}
                if f&1~=0 then flags[#flags+1]=w.race.fast end
                if f&2~=0 then flags[#flags+1]=w.race.pause end
                res.head.set(w.race.results)
                res.sub.set(table.concat(flags,' · '))
                local list={}
                for _,entry in ipairs(m.results) do list[#list+1]=entry end
                table.sort(list,function(a,c) return (a.pos or 99)<(c.pos or 99) end)
                for i=1,2 do
                    local entry,row=list[i],res.rows[i]
                    row.label.set(entry and (entry.pos and tostring(entry.pos) or '-')..'  '
                        ..(entry.who==mine(r) and w.chat.you or her_name(w)) or '')
                    row.value.set(entry and (entry.ms and Race.clock(entry.ms) or w.race.dnf) or '')
                end
            end
        end
        local target,label
        if up and (m.phase=='ready' or m.phase=='countdown') then
            local s=R.slot(t,r.role=='host' and 0 or 1)
            target,label={X=s.x,Y=s.y,Z=s.z},w.race.slot
        elseif up and m.phase=='race' and m.runner and not m.runner.done then
            local c=t.cps[m.runner.next]
            target,label={X=c.x,Y=c.y,Z=c.z},''
        end
        local mk,ar=kit.view('race_marker'),kit.view('race_arrow')
        local v=target and mk and ar and kit.project({X=target.X,Y=target.Y,Z=target.Z+ABOVE},os.clock())
        if not v then
            kit.show('race_marker',false)
            kit.show('race_arrow',false)
            return
        end
        local on,x,y,angle=P.place(v,was_on)
        was_on=on
        local far=r.pos and P.distance({X=r.pos.x,Y=r.pos.y,Z=r.pos.z},target,on) or ''
        if on then
            kit.show('race_arrow',false)
            kit.move('race_marker',x-MW/2,y-MH)
            mk.label.set(label)
            mk.far.set(far)
            kit.show('race_marker',true)
        else
            kit.show('race_marker',false)
            kit.move('race_arrow',x-AC,y-AC)
            ar.chevron.turn(angle+90) -- Its art points up.
            ar.far.set(far)
            kit.show('race_arrow',true)
        end
    end
    -- One frame of the race: the model from EVE's feet and her lines (and the loopback guest's), our lines to the
    -- native part, the events, the Doros, the HUD. A race that ends here (quit, map, coop off) sends its line first.
    local function frame(r)
        local now=clock()
        local e=eve()
        local pos=e and feet(e)
        r.pos=pos or r.pos
        local lines,flags,dnf,left=r.inbox,r.flags,r.dnf,r.left
        r.inbox,r.flags,r.dnf,r.left={},0,nil,nil
        local out,ev=R.tick(r.m,{pos=pos,lines=lines,rtt=link.ping(),map=r.map,flags=flags,dnf=dnf,left=left},now)
        for _,line in ipairs(out) do link.race(line) end
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
        place_doros(r,e)
        draw(r)
    end
    -- Every 250 ms: the session's end (a DNF left), a map change or EVE gone 2 s (a DNF map, then the race closes
    -- here), and the fin flags.
    local function slow(r)
        local paused=o.paused()==true
        away=paused
        if r.with and link.chatting()==false then r.left=true end
        if r.loop and not link.loopback() then r.left=true end
        local me=puppet.me()
        r.gone=me and 0 or r.gone+0.25
        if not r.ending and (me and r.map and me.map~=r.map or r.gone>=GONE_FOR) then r.dnf,r.ending='map','map' end
        local m=r.m
        if m.phase~='race' or m.me.ms or m.me.why then return end
        r.paused_for=paused and r.paused_for+0.25 or 0
        if r.paused_for>=PAUSE_FOR then r.flags=r.flags|2 end
        local e=eve()
        if not e then return end
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
        if link.mode()=='guest' then return false,'the host starts a race; yours comes when the host starts one' end
        if o.night() then return false,'Night Operation is running: coop nightop stop ends it' end
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
        local r=new_race('host',R.host(t,last_id,clock(),solo),{name=name,map=t.map,with=with,looked=true})
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
        tell(function(w) return w.race.saved:format(name,#t.cps) end)
        return true,'Track saved as '..file..' beside coop-settings.txt: coop race start '..name..' races it.'
    end
    -- record <name>, cp, save [laps], cancel, start <name>, quit.
    function self.command(sub,a,extra)
        if extra~=nil then return false,USE end
        if not link then return false,'the race needs the native part' end
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
    -- with none, a track line arms the guest's side. Off a co-op save the guest answers "no save" and stays out.
    function self.receive(text)
        if failed then return end
        local r=race
        if r and r.loop then r.loop_in[#r.loop_in+1]=text return end
        if r then r.inbox[#r.inbox+1]=text return end
        local l=R.decode(text)
        if not (l and l.what=='track' and link) then return end -- A line of a race that ended here.
        if not o.slot() then
            link.race(('have %d no save'):format(l.id))
            log('race '..l.id..' from the host refused: not a co-op save')
            return tell(function(w) return w.race.declined.save:format(her_name(w)) end)
        end
        local me=puppet.me()
        r=new_race('guest',R.guest(),{map=me and me.map,with=true})
        r.inbox[1]=text
    end
    -- Whether a race is armed here: main.lua reads the inbox each frame meanwhile, and coop nightop start refuses.
    function self.armed() return race~=nil end
    -- Each frame, after the ghost and the look are placed. A first error ends the race: false, why.
    function self.tick()
        local r=race
        if not r then return end
        local ok,e=pcall(frame,r)
        if not ok then return fail(e) end
    end
    -- Every 250 ms; a track being recorded adds the path EVE ran.
    function self.slow()
        if rec then
            pcall(function()
                local e=eve()
                if not e then return end
                local f,l=feet(e),rec.last
                rec.path,rec.last=rec.path+math.sqrt((f.x-l.x)^2+(f.y-l.y)^2+(f.z-l.z)^2),f
            end)
        end
        local r=race
        if not r then return end
        local ok,e=pcall(slow,r)
        if not ok then return fail(e) end
    end
    -- coop off: a recording dropped, a race left (its DNF or abort line out first) and closed.
    function self.stop()
        rec=nil
        local r=race
        if not r then return end
        r.dnf,r.ending=r.dnf or 'quit','coop off'
        if not failed then pcall(frame,r) end
        if race==r then pcall(close,r,'coop off') end
    end
    -- The HUD's groups on the Uplink kit, before its first build (main.lua, after Night Operation's): o is {kit,
    -- theme=ui.THEME, settings=main.lua's}.
    function self.hud(h)
        hud=h
        local kit,theme=h.kit,h.theme
        local x=(3840-HUD_W)/2
        kit.add('race_panel',{x=x,y=HUD_Y,w=HUD_W,h=PANEL_H,pivot={X=0.5,Y=0}},function(b)
            b.panel(0,0,HUD_W,PANEL_H)
            return {title=b.text(HUD_W/2,48,'','name',theme.beta,MIDDLE),
                line=b.text(HUD_W/2,104,'','item',theme.text,MIDDLE)}
        end)
        kit.add('race_results',{x=x,y=HUD_Y,w=HUD_W,h=RESULT_H,pivot={X=0.5,Y=0}},function(b)
            b.panel(0,0,HUD_W,RESULT_H)
            local v={head=b.text(HUD_W/2,70,'','title',theme.beta,MIDDLE),
                sub=b.text(HUD_W/2,136,'','body',theme.grey,MIDDLE),rows={}}
            for i=1,2 do
                local y=200+(i-1)*56
                v.rows[i]={label=b.text(96,y,'','body',theme.text,LEFT),
                    value=b.text(HUD_W-96,y,'','item',theme.text,RIGHT)}
            end
            return v
        end)
        kit.add('race_banner',{x=(3840-BANNER_W)/2,y=BANNER_Y,w=BANNER_W,h=BANNER_H,pivot={X=0.5,Y=0.5}},function(b)
            b.panel(0,0,BANNER_W,BANNER_H)
            return {text=b.text(BANNER_W/2,BANNER_H/2,'','title',theme.beta,MIDDLE)}
        end)
        -- Scaled from its bottom centre, over the checkpoint.
        kit.add('race_marker',{x=0,y=0,w=MW,h=MH,pivot={X=0.5,Y=1},inside=true},function(b)
            return {label=b.text(MW/2,22,'','hint',theme.beta,MIDDLE),
                diamond=b.image(MW/2-16,40,32,32,'diamond',theme.beta),far=b.text(MW/2,96,'','num',nil,MIDDLE)}
        end)
        -- The chevron turns around the diamond, at the group's (80, 80): the point on the edge.
        kit.add('race_arrow',{x=0,y=0,w=AW,h=AH,pivot={X=0.5,Y=AC/AH},inside=true},function(b)
            return {chevron=b.image(64,16,32,32,'chevron',theme.beta,{X=0.5,Y=2}),
                diamond=b.image(64,64,32,32,'diamond',theme.beta),far=b.text(52,116,'','num')}
        end)
    end
    return self
end
return Race
