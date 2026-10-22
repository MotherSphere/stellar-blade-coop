-- race.lua over fakes of the game, the link, the ghost, the look and the UI kit (as nightop_run_test.lua's):
-- recording (refusals, race_key and coop race cp, the 15 m rule, save and the file's text, cancel); a solo race from
-- arming to its results (the start's refusals, the look on, the checkpoint Doros, the countdown, the banners and their
-- sounds, a wrong way and a missed checkpoint, the result line, the emote, everything off at the end); two laps of a
-- circuit; the HUD groups shown and hidden (paused, the panel's line, the marker and the edge arrow, the results), and
-- notices in their place with the UI off, with the fin flags; a host and a guest joined by a fake link (a whole race,
-- a false start, a teleport DNF, the host's quit during the race, after his finish and before GO, the session's end, a
-- map change, the guest's map and co-op save refusals, her Night Operation run); the loopback guest instance; F9 while
-- recording and not, and on another map; coop off; a first error ends the race until the mod reloads, its quit line
-- out first; the driving (on at GO with the host's values, off at each way out, no fast flag meanwhile, its errors,
-- the drive probe with no race); the Doros an earlier Lua load left; and the together-only scan.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local T=require('ui_text')
local R=require('race_model')
local clock=0
os.clock=function() return clock end
local wall=1760000000
os.time=function() return wall end
local MAP='/game/art/bg/worldmap/e03_wasteland_p/e03_wasteland_p'
local function uobj(o)
    o.type=function() return 'UObject' end
    o.IsValid=o.IsValid or function(self) return not self.gone end
    return o
end
local SBC=uobj({})
StaticFindObject=function(path) assert(path=='/Script/SB.SBCharacter',path); return SBC end
local worlds={}
local function world_of(map)
    worlds[map]=worlds[map] or uobj({GetFullName=function() return 'World '..map..'.x' end})
    return worlds[map]
end
local function make_eve()
    local e=uobj({at={X=0,Y=0,Z=0},yaw=0,velocity={X=0,Y=0,Z=0},sprint=false,falling=false,map=MAP})
    e.Mesh=uobj({K2_GetComponentLocation=function() return {X=e.at.X,Y=e.at.Y,Z=e.at.Z} end})
    e.CharacterMovement=uobj({IsFalling=function() return e.falling end})
    function e:IsA(c) return c==SBC end
    function e:GetWorld() return world_of(self.map) end
    function e:K2_GetActorRotation() return {Pitch=0,Yaw=self.yaw,Roll=0} end
    function e:GetVelocity() return self.velocity end
    function e:IsSprint() return self.sprint end
    return e
end
local player=nil
package.loaded.UEHelpers={GetPlayer=function() return player end}
-- The display Doros (doro.lua's spawn, apply, remove and sweep): each spawned one with its path, its asset and whether
-- it is gone; the paths swept (a Doro: those under /Doro/). remove_error makes remove raise.
local doros,spawn_error,remove_error,swept={},nil,nil,{}
package.loaded.doro={spawn=function(w,at,rot)
        if spawn_error then error(spawn_error,0) end
        local d={world=w,at=at,rot=rot,path='/Doro/'..(#doros+1)}
        doros[#doros+1]=d
        return d
    end,apply=function(d,c) d.asset,d.loop=c.asset,c.loop end,
    remove=function(d)
        if remove_error then error(remove_error,0) end
        assert(not d.removed,'removed twice')
        d.removed=true
    end,
    sweep=function(p) swept[#swept+1]=p; return p:find('^/Doro/')~=nil end}
local function alive()
    local list={}
    for _,d in ipairs(doros) do if not d.removed then list[#list+1]=d end end
    return list
end
local Race=require('race')

-- A fake UI kit: its groups, what each shows, where they move, its sounds; off, the game's language, a projection that
-- puts the camera 10 m behind the point (on screen) or past it (behind you: the edge arrow).
local function fake_kit()
    local kit={groups={},shown={},moved={},sounds={},is_off=false,lang=nil,behind=false}
    function kit.add(name,place,build)
        local g={place=place}
        local b={}
        function b.panel(...) g.panel={...} end
        function b.text(x,y,str)
            local e={text=str}
            function e.set(t) e.text=t end
            function e.color(c) e.c=c end
            return e
        end
        function b.image(_,_,_,_,tex)
            local e={tex=tex}
            function e.turn(a) e.angle=a end
            return e
        end
        g.view=build(b)
        kit.groups[name]=g
    end
    function kit.view(name) return not kit.is_off and kit.groups[name] and kit.groups[name].view or nil end
    function kit.show(name,on) kit.shown[name]=on==true end
    function kit.move(name,x,y) kit.moved[name]={x,y} end
    function kit.off() return kit.is_off end
    function kit.language() return kit.lang end
    function kit.sound(name) kit.sounds[#kit.sounds+1]=name end
    function kit.project(at)
        kit.projected=at
        return {camera={X=at.X+(kit.behind and 1000 or -1000),Y=at.Y,Z=at.Z},rotation={Pitch=0,Yaw=0},fov=90,
            anchor=at,width=3840,height=2160}
    end
    return kit
end
-- One PC: its files, the lines it sent (wire: all of them), its notices in English, its log, the look and the ghost's
-- Doro mode with their emotes, its session (friend, mode, loopback, chatting), its map and EVE.
local function side(o)
    o=o or {}
    local s={files={},sent={},wire={},told={},logs={},errors={},inbox={},look={on=false,ons=0,offs=0},ghost={},
        friend=o.friend,linked=o.friend~=nil,mode=o.mode or 'none',loopback=false,chatting=o.friend~=nil,
        her_map=MAP,slot_ok=true,paused=false,night=false,eve=make_eve(),speed=o.speed or 900,read=0}
    s.me={map=MAP}
    s.link={race=function(line) s.sent[#s.sent+1]=line end,race_flush=function() s.flushes=(s.flushes or 0)+1 end,
        read_file=function(name) return s.files[name] end,
        write_file=function(name,text)
            if s.write_fails then return false,'cannot write '..name end
            s.files[name]=text
            return true
        end,
        friend=function() if s.friend then return s.friend,s.linked,false end end,mode=function() return s.mode end,
        loopback=function() return s.loopback end,ping=function() return s.ping end,
        chatting=function() return s.chatting end}
    -- The driving (drive.lua's): on and off with why and the values, its frames, its 250 ms checks, the look it gives;
    -- refuse makes on fail, error makes a frame raise.
    s.drive={on=false,ons=0,ticks=0,slows=0,values={top=2600,accel=1200,brake=2000,coast=300,grip=70,drift_grip=20,
        turn_slow=200,turn_fast=90,drift_angle=40}}
    local function copy(t) local c={} for k,v in pairs(t) do c[k]=v end return c end
    s.drive_api={values=function() return copy(s.drive.values) end,
        on=function(P,why)
            if s.drive.refuse then return false,s.drive.refuse end
            s.drive.on,s.drive.P,s.drive.ons=why,copy(P),s.drive.ons+1
            return true
        end,
        off=function(why)
            local was=s.drive.on
            s.drive.on,s.drive.why=false,why
            return was and 'drive off ('..why..')' or 'drive off already'
        end,
        racing=function() return s.drive.on=='race' end,active=function() return s.drive.on~=false end,
        tick=function()
            s.drive.ticks=s.drive.ticks+1
            if s.drive.error then error(s.drive.error,0) end
            return {top=s.drive.P.top,stumble=false}
        end,
        slow=function() s.drive.slows=s.drive.slows+1 end,
        restore=function() s.drive.restored=(s.drive.restored or 0)+1 end,
        command=function(a,b) s.drive.said={a,b}; return true,'drive '..tostring(a) end}
    s.look_api={log=function(m) s.logs[#s.logs+1]='look: '..m end,
        drive=function(d) if s.look.on then s.look.drive=d end end,
        on=function()
            if s.look_refuses then return false,s.look_refuses end
            s.look.on,s.look.ons=true,s.look.ons+1
            return true,'look on'
        end,
        off=function(why)
            local was=s.look.on
            s.look.on,s.look.emote,s.look.drive,s.look.offs,s.look.why=false,nil,nil,s.look.offs+1,why
            return true,was and 'Doro look off ('..why..')' or 'The Doro look is off already.'
        end,
        emote=function(e) if s.look.on then s.look.emote=e end end}
    s.puppet={anchor=function()
            local f=s.ghost_feet
            if f then return {X=f.X,Y=f.Y,Z=f.Z+220},f end
        end,
        her_map=function() return s.her_map end,me=function() return s.me end,
        doro=function(on,log)
            assert(not on or log==s.look_api.log,'Its lines in the look\'s log')
            s.ghost.doro=on==true
        end,
        emote=function(e) s.ghost.emote=e end,drive=function(top) s.ghost.top=top end}
    s.settings={race_key={key='F9',name='F9'},ui_language='game'}
    s.stored=o.stored -- coop-race-doros.txt's line.
    s.store={save=function(line) s.stored=line; return true end,load=function() return s.stored end,
        clear=function() s.stored=nil end}
    s.race=Race.new({log=function(m) s.logs[#s.logs+1]=m end,link=s.link,puppet=s.puppet,look=s.look_api,store=s.store,
        drive=s.drive_api,
        tell=function(build) s.told[#s.told+1]=build(T.en) end,night=function() return s.night end,
        slot=function() if s.slot_ok then return true end return false,'not a co-op save' end,
        paused=function() return s.paused end,settings=s.settings})
    return s
end
local function has(list,text) for _,l in ipairs(list) do if l==text then return true end end end
local function find(list,pattern) for _,l in ipairs(list) do if l:find(pattern) then return l end end end
local function count(list,pattern)
    local n=0
    for _,l in ipairs(list) do if l:find(pattern) then n=n+1 end end
    return n
end
local function at_distance(points,d)
    for k=2,#points do
        local a,b=points[k-1],points[k]
        local len=math.sqrt((b.x-a.x)^2+(b.y-a.y)^2+(b.z-a.z)^2)
        if d<=len then return {x=a.x+(b.x-a.x)*d/len,y=a.y+(b.y-a.y)*d/len,z=a.z+(b.z-a.z)*d/len} end
        d=d-len
    end
    return points[#points]
end
local function put(s,p) s.eve.at={X=p.x,Y=p.y,Z=p.z} end
-- The frames: each side gets the lines the other sent the frame before (her inbox, as main.lua reads coop-chat.txt),
-- moves (s.move), ticks; every 250 ms each side's slow. A side with echo gets its own lines back (the loopback).
local FRAME=1/30
local function step(list)
    clock=clock+FRAME
    for _,s in ipairs(list) do
        local lines=s.inbox
        s.inbox={}
        for _,line in ipairs(lines) do s.race.receive(line) end
        if s.move then s.move(s) end
        player=s.eve
        local _,why=s.race.tick()
        if why then s.errors[#s.errors+1]=why end
        for k=s.read+1,#s.logs do -- Its GO, as its own clock had it.
            if s.logs[k]:find('^race %d+ go$') then s.go_at=clock end
        end
        s.read=#s.logs
        for _,line in ipairs(s.sent) do
            s.wire[#s.wire+1]=line
            if s.peer then table.insert(s.peer.inbox,line) elseif s.echo then table.insert(s.inbox,line) end
        end
        s.sent={}
    end
    if math.floor(clock*4+1e-9)~=math.floor((clock-FRAME)*4+1e-9) then
        for _,s in ipairs(list) do
            player=s.eve
            local _,why=s.race.slow()
            if why then s.errors[#s.errors+1]=why end
        end
    end
end
local function run(list,done,limit)
    for _=1,limit or 3000 do
        step(list)
        if done() then return end
    end
    error('the race never got there')
end
local function frames(list,n) for _=1,n do step(list) end end

-- A straight track recorded with race_key and coop race cp: the start at EVE's feet and facing, four checkpoints.
local CPS={{x=4000,y=0,z=0},{x=8000,y=2000,z=100},{x=12000,y=0,z=0},{x=16000,y=0,z=0}}
local FILE='coop-track-quest.txt'
local TEXT='SBR 1\nmap '..MAP..'\nlaps 1\ngrid 0 0 0 0\ncp 4000 0 0 1200\ncp 8000 2000 100 1200\ncp 12000 0 0 1200\n'
    ..'cp 16000 0 0 1200\n'
local TRACK=assert(R.parse_track(TEXT))
local function path(k,stops)
    local list={R.slot(TRACK,k)}
    for _,p in ipairs(stops or CPS) do list[#list+1]=p end
    return list
end
-- Each racer stands in her slot until her GO, then runs her path at her speed.
local function racer(k,stops)
    return function(s)
        if s.go_at then put(s,at_distance(path(k,stops),s.speed*(clock-s.go_at))) else put(s,R.slot(TRACK,k)) end
    end
end

-- 1. Recording, and the native part missing.
local ok,message
do
    local none=Race.new({log=print,link=nil,puppet={},look={},tell=function() end,night=function() return false end,
        slot=function() return true end,paused=function() return false end,settings=nil})
    ok,message=none.command('record','quest')
    assert(not ok and message=='the race needs the native part',message)
end
local A=side()
player=A.eve
local USE='Use: coop race record <name> | cp | save [laps] | cancel | start <name> | quit'
for _,args in ipairs({{},{'go'},{'record'},{'cp','x'},{'cancel','x'},{'quit','x'},{'record','a','b'},{'start'}}) do
    ok,message=A.race.command(table.unpack(args,1,3))
    assert(not ok and message==USE,tostring(message))
end
for _,bad in ipairs({'Quest','a b','../x',('z'):rep(25)}) do
    ok,message=A.race.command('record',bad)
    assert(not ok and message=='a track name is 1 to 24 of a-z, 0-9, _ and -',bad)
end
ok,message=A.race.command('cp')
assert(not ok and message=='no track is being recorded: coop race record <name> starts one',message)
assert(A.race.key()==nil and #A.told==0,'F9 with no recording: nothing')
player=nil
ok,message=A.race.command('record','quest')
assert(not ok and message=='no EVE in the world')
player=A.eve
A.eve.at,A.eve.yaw={X=0.4,Y=-0.3,Z=0.2},0
ok,message=A.race.command('record','quest')
assert(ok and message:find('^Recording track quest from here: F9 or coop race cp'),message)
assert(A.told[1]=='Recording quest: press F9 at each checkpoint.',A.told[1])
A.eve.at={X=1400,Y=0,Z=0}
ok,message=A.race.key()
assert(not ok and message:find('^too close') and A.told[2]=='Too close: 15 m at least between checkpoints.',message)
ok,message=A.race.command('save')
assert(not ok and message=='a track needs 2 checkpoints at least',message)
for i,c in ipairs(CPS) do
    A.eve.at={X=c.x,Y=c.y,Z=c.z}
    A.race.slow() -- The path it ran.
    if i%2==1 then ok,message=A.race.key() else ok,message=A.race.command('cp') end
    assert(ok and message==('checkpoint %d at %d %d %d'):format(i,c.x,c.y,c.z),message)
    assert(A.told[#A.told]==('Checkpoint %d set.'):format(i))
end
-- On another map (a fast travel while recording): no checkpoint, and said.
A.eve.map='/game/e04'
ok,message=A.race.key()
assert(not ok and message=='this track is on '..MAP..'; you are on /game/e04',message) -- The saved file below has 4.
assert(A.told[#A.told]=='This track is on another map.')
A.eve.map=MAP
ok,message=A.race.command('save','2')
assert(not ok and message=='laps above 1 need the last checkpoint within 30 m of the start',message)
for _,bad in ipairs({'0','10','x'}) do
    ok,message=A.race.command('save',bad)
    assert(not ok and message=='Use: coop race save [laps 1-9]',message)
end
A.write_fails=true
ok,message=A.race.command('save')
assert(not ok and message=='cannot write coop-track-quest.txt' and not A.files[FILE],message)
A.write_fails=nil
ok,message=A.race.command('save')
assert(ok and message=='Track saved as coop-track-quest.txt beside coop-settings.txt: coop race start quest races it.')
assert(A.files[FILE]==TEXT,A.files[FILE])
assert(A.told[#A.told]=='Track quest saved, 4 checkpoints.')
assert(A.logs[#A.logs]=='track quest saved: 4 checkpoints, 1 laps, path 169 m in 0 s',A.logs[#A.logs])
assert(A.race.key()==nil,'Saved: F9 does nothing again')
ok,message=A.race.command('cancel')
assert(not ok and message=='no track is being recorded')
A.race.command('record','other')
ok,message=A.race.command('cancel')
assert(ok and message=='Recording dropped; nothing written.' and not A.files['coop-track-other.txt'])
assert(#A.sent==0 and #doros==0 and A.look.ons==0,'Recording sends nothing and shows nothing')

-- 2. The start's refusals: nothing armed, the look untouched.
local function refused(s,name,text)
    ok,message=s.race.command('start',name)
    assert(not ok and message==text,tostring(message))
    assert(not s.race.armed() and s.look.ons==0 and #s.sent==0)
end
refused(A,'nope','no coop-track-nope.txt beside coop-settings.txt')
A.files['coop-track-bad.txt']='SBR 1\nmap '..MAP..'\n'
refused(A,'bad','coop-track-bad.txt is not a track (laps)')
A.files['coop-track-far.txt']=TEXT:gsub('e03_wasteland_p/e03_wasteland_p','e04/e04')
refused(A,'far','coop-track-far.txt is on /game/art/bg/worldmap/e04/e04; you are on '..MAP)
A.night=true
refused(A,'quest','Night Operation is running: coop nightop stop ends it')
A.night=false
A.mode='guest'
refused(A,'quest','the host starts a race; yours comes when the host starts one')
A.mode='none'
A.race.command('record','x')
refused(A,'quest','a track is being recorded: coop race save or coop race cancel first')
A.race.command('cancel')
A.friend,A.linked,A.her_map='Kaanta',true,'/game/e04'
refused(A,'quest','your friend is on /game/e04; the track is on '..MAP)
A.her_map=nil
refused(A,'quest',"your friend's map is not known yet: try again in a moment")
A.friend,A.linked,A.her_map=nil,false,MAP
A.look_refuses='no EVE in the world'
ok,message=A.race.command('start','quest')
assert(not ok and message=='no EVE in the world' and not A.race.armed())
A.look_refuses=nil
player=nil
refused(A,'quest','no EVE in the world')
player=A.eve

-- 3. A solo race from arming to results, with the HUD on a fake kit.
local kit=fake_kit()
A.race.hud({kit=kit,theme={beta='beta',warn='warn',error='error',text='text',grey='grey'},settings=A.settings})
for _,name in ipairs({'race_panel','race_results'}) do
    local p=kit.groups[name].place
    assert(p.x+p.w/2==1920 and p.y==96 and p.pivot.X==0.5 and p.pivot.Y==0,name)
end
assert(kit.groups.race_banner.place.x+kit.groups.race_banner.place.w/2==1920)
assert(kit.groups.race_marker.place.inside and kit.groups.race_arrow.place.inside,'Kept on screen')
A.told={}
put(A,{x=0,y=-3000,z=0}) -- Off the start: she walks there.
ok,message=A.race.command('start','quest')
assert(ok and message:find('^Race quest armed: walk to your start'),message)
assert(A.race.armed() and A.look.on and A.told[1]=='Race ready: walk to your start.')
assert(A.logs[#A.logs]=='race 1760000000 armed on coop-track-quest.txt: 4 checkpoints, 1 laps, alone',A.logs[#A.logs])
ok,message=A.race.command('start','quest')
assert(not ok and message=='a race is on: coop race quit leaves it')
ok,message=A.race.command('record','x')
assert(not ok and message=='a race is on: coop race quit leaves it')
step({A})
-- Before GO: one Doro at the start line's centre, facing down the track; the marker over her slot with its distance.
assert(#alive()==1 and alive()[1].at.X==0 and alive()[1].rot.Yaw==-90 and alive()[1].asset=='idle')
assert(A.stored==alive()[1].path,'Its path kept for the next Lua load')
assert(kit.shown.race_panel and kit.groups.race_panel.view.title.text=='DORO RACE')
assert(kit.groups.race_panel.view.line.text=='0:00.00  CP 0/4  LAP 1/1  POS 1/1',kit.groups.race_panel.view.line.text)
local slot0=R.slot(TRACK,0)
assert(kit.shown.race_marker and not kit.shown.race_arrow and kit.projected.X==slot0.x and kit.projected.Z==220)
local mk=kit.groups.race_marker.view
assert(mk.label.text=='Your start' and mk.far.text=='29 m',mk.far.text)
kit.behind=true
step({A})
assert(kit.shown.race_arrow and not kit.shown.race_marker and kit.groups.race_arrow.view.far.text=='29 m')
kit.behind=false
-- Paused: everything hidden, back after.
A.paused=true
frames({A},8)
assert(not kit.shown.race_panel and not kit.shown.race_marker)
A.paused=false
frames({A},8)
assert(kit.shown.race_panel)
A.move=racer(0,{CPS[1],{x=500,y=0,z=0},CPS[2],{x=12000,y=6000,z=0},CPS[4],CPS[3],CPS[4]})
run({A},function() return A.go_at end)
assert(table.concat(kit.sounds,' ')=='move move move select',table.concat(kit.sounds,' '))
assert(A.drive.on=='race' and A.drive.P.top==2600 and A.look.drive.top==2600,'Driving from GO, alone too')
assert(kit.shown.race_banner and kit.groups.race_banner.view.text.text=='GO!')
assert(#A.sent==0,'Alone: no line')
step({A})
-- In the race: the next checkpoint's Doro and the one after it, each facing the one before; the marker on the next.
local list=alive()
table.sort(list,function(a,b) return a.at.X<b.at.X end)
assert(#list==2 and list[1].at.X==4000 and list[1].rot.Yaw==90 and list[2].at.X==8000,#list)
assert(A.stored==list[1].path..'\t'..list[2].path or A.stored==list[2].path..'\t'..list[1].path,A.stored)
assert(math.abs(list[2].rot.Yaw-(math.deg(math.atan(-2000,-4000))-90))<1e-9 and list[2].asset=='idle')
assert(kit.projected.X==4000 and mk.label.text=='' and kit.groups.race_panel.view.line.text:find('^0:00%.%d%d  CP 0/4'))
frames({A},32)
assert(not kit.shown.race_banner,'GO for 1 s')
-- Back towards the start after checkpoint 1: wrong way, then right again on the way to checkpoint 2.
run({A},function() return kit.shown.race_banner and kit.groups.race_banner.view.text.text=='WRONG WAY' end)
assert(kit.groups.race_banner.view.text.c=='warn' and kit.sounds[#kit.sounds]=='alert')
assert(kit.groups.race_panel.view.line.text:find('  CP 1/4  LAP 1/1  POS 1/1$'),kit.groups.race_panel.view.line.text)
run({A},function() return not kit.shown.race_banner end)
-- Past checkpoint 3 into the finish's radius: missed checkpoint 3, then back for it.
run({A},function() return kit.shown.race_banner and kit.groups.race_banner.view.text.text=='MISSED CHECKPOINT 3' end)
local finish
for _,d in ipairs(alive()) do if d.at.X==16000 then finish=d end end
assert(finish and finish.asset=='evade' and finish.loop==true,'The finish Doro loops Evade')
run({A},function() return find(A.logs,'^result ') end)
local result=find(A.logs,'^result ')
local ms=tonumber(result:match(' ms=(%d+) '))
assert(result==('result id=1760000000 track=quest ms=%d clock=%.3f time=0 flags=0 rank=1'):format(ms,
    tonumber(result:match(' clock=([%d.]+) '))),result)
assert(math.abs(tonumber(result:match(' clock=([%d.]+) '))*1000-ms)<=40,'The os.clock span is the race time')
assert(find(A.logs,'^race 1760000000 fin %d:%d%d%.%d%d$'))
assert(A.look.emote=='win' and A.ghost.emote==nil,'Alone: the winner')
assert(not A.drive.on and A.drive.why=='race fin' and A.look.drive==nil,'Off at her result')
assert(kit.shown.race_results and not kit.shown.race_panel and not kit.shown.race_banner and not kit.shown.race_marker)
local res=kit.groups.race_results.view
assert(res.head.text=='RESULTS' and res.sub.text=='' and res.rows[1].label.text=='1  You'
    and res.rows[1].value.text==Race.clock(ms) and res.rows[2].label.text=='' and res.rows[2].value.text=='')
assert(#alive()==0,'No Doro once she finished')
run({A},function() return not A.race.armed() end,400)
assert(not A.look.on and A.look.why=='race over' and #alive()==0 and A.stored==nil)
for _,g in ipairs({'race_panel','race_results','race_banner','race_marker','race_arrow'}) do
    assert(not kit.shown[g],g)
end
assert(count(A.told,'.')==1,'Only the armed notice: the HUD showed the rest')
assert(#A.errors==0,A.errors[1])
-- Race.clock: m:ss.cc, never 60 seconds.
assert(Race.clock(83450)=='1:23.45' and Race.clock(59999)=='0:59.99' and Race.clock(0)=='0:00.00')

-- 3b. Two laps of a circuit: at lap 1's last checkpoint the one after is lap 2's first, now facing the last; the
-- finish's Doro loops Evade on the last lap only.
do
    local C=side()
    local text='SBR 1\nmap '..MAP..'\nlaps 2\ngrid 0 0 0 0\ncp 4000 0 0 1200\ncp 4000 4000 0 1200\ncp 0 4000 0 1200\n'
        ..'cp 500 500 0 1200\n'
    local circuit=assert(R.parse_track(text))
    C.files['coop-track-loop.txt']=text
    local route={R.slot(circuit,0)}
    for _=1,2 do for _,c in ipairs(circuit.cps) do route[#route+1]={x=c.x,y=c.y,z=c.z} end end
    C.move=function(c)
        if c.go_at then put(c,at_distance(route,c.speed*(clock-c.go_at))) else put(c,R.slot(circuit,0)) end
    end
    player=C.eve
    assert(C.race.command('start','loop'))
    local next_lap,lap_one_idle,finish=false,false,false
    run({C},function()
        for _,d in ipairs(alive()) do
            if d.at.X==4000 and d.at.Y==0 and math.abs(d.rot.Yaw-(math.deg(math.atan(500,-3500))-90))<1e-9 then
                next_lap=true
            end
            if d.at.X==500 and d.asset=='idle' then lap_one_idle=true end
            if d.at.X==500 and d.asset=='evade' then finish=true end
        end
        return not C.race.armed()
    end)
    assert(next_lap and lap_one_idle and finish and find(C.logs,'^result .* rank=1$'))
end

-- 4. With the UI off, the banners come as notices: GO, a DNF and why (a teleport). Also the fin flags: 2 s paused
-- sets flag 2; 1 s over 550 cm/s with no sprint sets no flag 1 while the race drives her.
kit.is_off=true
A.told,A.go_at,A.move={},nil,racer(0)
A.race.command('start','quest')
run({A},function() return A.go_at end)
frames({A},40)
A.eve.velocity={X=600,Y=0,Z=0}
frames({A},40)
A.eve.velocity={X=0,Y=0,Z=0}
A.paused=true
frames({A},70)
A.paused=false
A.move=function(s) put(s,{x=s.eve.at.X,y=s.eve.at.Y+3000,z=0}) end -- 30 m in a frame.
step({A})
A.move=nil
assert(A.told[1]=='Race ready: walk to your start.' and A.told[2]=='GO!' and A.told[3]=='DNF'
    and A.told[4]=='Moved more than 20 m at once.',table.concat(A.told,'|'))
assert(not A.drive.on and A.drive.why=='race teleport')
run({A},function() return find(A.logs,'^result id=1760000001') end)
assert(find(A.logs,'^result id=1760000001 track=quest ms=%- clock=[%d.]+ time=0 flags=2 rank=%-$'),A.logs[#A.logs])
assert(A.look.emote=='lose')
run({A},function() return not A.race.armed() end,400)
kit.is_off=false

-- 5. A host and a guest through a fake link: the whole race. Her have line turns the host's ghost into a Doro, the
-- host's track turns hers; the same ranking on both; the winner's emote win, the other's lose; all off at the end.
local function pair()
    local H,G=side({friend='Kaanta',mode='host'}),side({friend='Host',mode='guest',speed=850})
    H.files[FILE],H.peer,G.peer=TEXT,G,H
    H.move,G.move=racer(0),racer(1)
    clock=clock+100
    wall=wall+100
    return H,G
end
local H,G=pair()
player=H.eve
ok,message=H.race.command('start','quest')
assert(ok and H.logs[#H.logs]:find('with a friend$'))
step({H,G})
assert(H.wire[1]=='track '..wall..' 4 1 0 0 0 0 '..MAP and H.wire[2]:find('^cps '..wall..' 1 4000 0 0 1200 '))
assert(H.wire[3]=='drive '..wall..' 2600 1200 2000 300 70 20 200 90 40','The host\'s driving values',H.wire[3])
step({H,G})
assert(G.race.armed() and G.look.on and G.ghost.doro and G.told[1]=='Host starts a race: walk to your start.')
local driven=assert(R.parse_track(TEXT))
driven.drive=H.drive.values
assert(G.wire[1]=='have '..wall..' '..R.sum(driven),'Her sum with his values')
step({H,G})
assert(H.ghost.doro,'Her have: her ghost runs as a Doro')
assert(not H.drive.on and not G.drive.on,'No driving before GO')
-- From GO both drive with the host's values, each frame; their ghosts' Doros by its top speed; the looks get it.
run({H,G},function() return H.go_at and G.go_at end)
step({H,G})
for _,s in ipairs({H,G}) do
    assert(s.drive.on=='race' and s.drive.ons==1 and s.drive.P.top==2600 and s.drive.P.drift_angle==40)
    assert(s.ghost.top==2600 and s.look.drive.top==2600 and s.drive.ticks>0)
end
-- Each side's driving ends at its own result; all of it gone once the race closes.
run({H,G},function() return find(H.logs,'^race %d+ fin ') end)
assert(not H.drive.on and H.drive.why=='race fin' and has(H.logs,'drive off (race fin)') and H.look.drive==nil)
assert(H.ghost.top==2600,'Her Doro keeps the race\'s speed while she races')
run({H,G},function() return not H.race.armed() and not G.race.armed() end)
assert(not G.drive.on and G.drive.why=='race fin' and H.ghost.top==nil and G.ghost.top==nil)
local hr,gr=find(H.logs,'^result '),find(G.logs,'^result ')
assert(hr:find(' track=quest ') and hr:find(' rank=1$') and gr:find(' track=%- ') and gr:find(' rank=2$'),hr..' / '..gr)
assert(H.wire[#H.wire]=='end '..wall and find(H.wire,'^rank '..wall..' %d+ %d+$'))
assert(not H.look.on and not G.look.on and not H.ghost.doro and not G.ghost.doro and #alive()==0)
assert(H.look.offs==1 and G.look.offs==1)
assert(#H.errors==0 and #G.errors==0)
-- The emotes, caught at the results.
H,G=pair()
player=H.eve
H.race.command('start','quest')
run({H,G},function() return find(G.logs,'^result ') and find(H.logs,'^result ') end)
assert(H.look.emote=='win' and H.ghost.emote=='lose' and G.look.emote=='lose' and G.ghost.emote=='win')
run({H,G},function() return not H.race.armed() and not G.race.armed() end)
assert(H.ghost.emote==nil and G.look.emote==nil)

-- 6. A false start: she leaves her slot in the countdown; both hear it, and the race starts again from the ready check.
H,G=pair()
player=H.eve
H.race.command('start','quest')
local left=false
G.move=function(s)
    if not left and find(s.wire,'^ready %d+ 1$') and count(H.wire,'^go ')==1 then
        left=true
        put(s,{x=0,y=2000,z=0})
    elseif not s.go_at or count(H.wire,'^go ')<2 then put(s,R.slot(TRACK,1))
    else put(s,at_distance(path(1),s.speed*(clock-s.go_at))) end
end
run({H,G},function() return left and count(H.wire,'^abort %d+ false_start$')==1 end)
frames({H,G},3)
assert(has(H.told,'False start: back to your start.') and has(G.told,'False start: back to your start.'))
run({H,G},function() return count(H.wire,'^go ')==2 end)
assert(not G.drive.on and G.drive.ons<=1,'No driving while back at the start')
-- 7. The host quits mid-race: his DNF goes out, his race closes at once; she finishes and ranks herself.
run({H,G},function() return H.go_at end) -- The first countdown never reached GO.
frames({H,G},90)
assert(H.drive.on=='race' and G.drive.on=='race','Driving after the second GO')
ok,message=H.race.command('quit')
assert(ok and message=='You left the race.')
step({H,G})
assert(not H.race.armed() and not H.look.on and H.look.why=='race quit' and H.wire[#H.wire]:find('^dnf %d+ quit$'))
assert(not H.drive.on and H.drive.why=='race quit' and H.ghost.top==nil)
assert(H.stored==nil,'Its Doros gone, their file too')
assert(not has(H.told,'Quit the race.'),'Its own reply says it')
step({H,G})
assert(not G.ghost.doro and G.told[#G.told]=='Host left the race.','His ghost is himself again')
run({H,G},function() return find(G.logs,'^result ') end)
assert(find(G.logs,'^result .* rank=1$'))
run({H,G},function() return not G.race.armed() end)
ok,message=H.race.command('quit')
assert(not ok and message=='no race to quit')
-- 7b. The host finishes, then quits before she does: his dnf line still goes out, so she ranks herself at her finish
-- (no 60 s wait), second behind his time.
H,G=pair()
player=H.eve
H.race.command('start','quest')
run({H,G},function() return find(H.logs,'^race %d+ fin ') end)
H.race.command('quit')
step({H,G})
assert(not H.race.armed() and H.wire[#H.wire]:find('^dnf %d+ quit$') and not G.ghost.doro)
local fin_at
run({H,G},function()
    fin_at=fin_at or find(G.logs,'^race %d+ fin ') and clock
    return find(G.logs,'^result ')
end)
assert(clock-fin_at<0.1 and find(G.logs,'^result .* rank=2$'),clock-fin_at)
run({H,G},function() return not G.race.armed() end)

-- 8. A teleport DNF of hers: the host wins alone.
H,G=pair()
player=H.eve
H.race.command('start','quest')
G.move=function(s)
    racer(1)(s)
    if s.go_at and clock-s.go_at>6 then s.eve.at.Y=s.eve.at.Y+3000 end
end
run({H,G},function() return not H.race.armed() and not G.race.armed() end)
assert(has(G.told,'Moved more than 20 m at once.') and find(H.logs,'^result .* rank=1$'))
assert(find(G.logs,'^result .* ms=%- .* rank=%-$'))

-- 9. The session ends mid-race on her PC: her DNF (left), her results at once, then her race closes.
H,G=pair()
player=H.eve
H.race.command('start','quest')
run({H,G},function() return G.go_at and clock-G.go_at>3 end)
G.chatting,G.peer,H.peer=false,nil,nil
run({G},function() return find(G.logs,'^result ') end,20)
assert(find(G.logs,'^race %d+ dnf left$') and has(G.told,'The session ended.'))
assert(not G.drive.on and G.drive.why=='race left')
run({G},function() return not G.race.armed() end,400)
H.race.command('quit')
step({H})

-- 10. A map change on her PC: her DNF (map) goes out, her race closes; the host finishes and wins.
H,G=pair()
player=H.eve
H.race.command('start','quest')
run({H,G},function() return G.go_at and clock-G.go_at>3 end)
G.me={map='/game/e04'}
run({H,G},function() return not G.race.armed() end,10)
assert(G.wire[#G.wire]:find('^dnf %d+ map$') and not G.look.on and G.look.why=='race map')
assert(not G.drive.on and G.drive.why=='race map')
assert(G.told[#G.told]=='Left the map.','Said, as the HUD goes with the race')
run({H,G},function() return not H.race.armed() end)
assert(find(H.logs,'^result .* rank=1$'))
-- EVE gone 2 s (a load): the same.
H,G=pair()
player=H.eve
H.race.command('start','quest')
run({H,G},function() return G.go_at end)
G.me=nil
run({H,G},function() return not G.race.armed() end,80)
assert(G.wire[#G.wire]:find('^dnf %d+ map$') and G.told[#G.told]=='Left the map.')
G.me={map=MAP}
H.race.command('quit')
step({H,G})
-- Before GO: the race is cancelled on her PC, and said; the host races alone.
H,G=pair()
player=H.eve
H.race.command('start','quest')
frames({H,G},6)
G.me={map='/game/e04'}
run({H,G},function() return not G.race.armed() end,10)
assert(G.wire[#G.wire]:find('^dnf %d+ map$') and G.told[#G.told]=='Race cancelled.')
G.me={map=MAP}
H.race.command('quit')
step({H,G})

-- 11. The guest's refusals: another map (her have line says it, and the host races alone), then off a co-op save.
H,G=pair()
G.me={map='/game/e04'}
player=H.eve
H.race.command('start','quest')
frames({H,G},4)
assert(G.wire[1]:find('^have %d+ no map$') and not G.race.armed() and not G.look.on and not G.ghost.doro)
assert(G.told[1]=='Host started a race on another map.' and has(H.told,'Kaanta is on another map. You race alone.'))
assert(not H.ghost.doro,'Her ghost stays her')
H.race.command('quit')
step({H,G})
H,G=pair()
G.slot_ok=false
player=H.eve
H.race.command('start','quest')
frames({H,G},4)
assert(G.wire[1]:find('^have %d+ no save$') and G.told[1]=='Host started a race. Races need a co-op save.')
assert(has(H.told,'Kaanta is not on a co-op save. You race alone.') and not G.race.armed())
H.race.command('quit')
step({H,G})
-- During her Night Operation run she does not answer: no line, no look; the host races alone after 10 s.
H,G=pair()
G.night=true
player=H.eve
H.race.command('start','quest')
frames({H,G},4)
assert(#G.wire==0 and not G.race.armed() and not G.look.on and #G.told==0)
assert(find(G.logs,'^race %d+ from the host not answered: Night Operation is running$'))
run({H,G},function() return has(H.told,'Kaanta did not answer. You race alone.') end,400)
H.race.command('quit')
step({H,G})
-- The session's host never arms as a guest, whatever line comes.
H.race.receive('track 7 4 1 0 0 0 0 '..MAP)
assert(not H.race.armed() and #H.sent==0)

-- The host quits before GO: the race is cancelled for her, her look off again.
H,G=pair()
player=H.eve
H.race.command('start','quest')
frames({H,G},6)
assert(G.race.armed() and G.look.on)
H.race.command('quit')
frames({H,G},3)
assert(H.wire[#H.wire]:find('^abort %d+ quit$') and not G.race.armed() and not G.look.on and not G.ghost.doro)
assert(G.told[#G.told]=='Race cancelled.' and not has(H.told,'Race cancelled.'),G.told[#G.told])

-- 12. The loopback: no friend, our lines come back as hers to a guest instance run by the loopback ghost's feet,
-- whose lines go straight to ours. Both race; two rows in the results; her ghost a Doro meanwhile.
local L=side()
L.files[FILE],L.echo,L.loopback=TEXT,true,true
L.move=function(s)
    racer(0)(s)
    local g=s.go_at and at_distance(path(1),850*(clock-s.go_at)) or R.slot(TRACK,1)
    s.ghost_feet={X=g.x,Y=g.y,Z=g.z}
end
clock,wall=clock+100,wall+100
player=L.eve
ok,message=L.race.command('start','quest')
assert(ok and L.logs[#L.logs]:find('in loopback$'))
run({L},function() return L.ghost.doro end,30)
run({L},function() return find(L.logs,'^result ') end)
assert(find(L.logs,'^result .* rank=1$') and L.ghost.emote=='lose' and L.look.emote=='win')
run({L},function() return not L.race.armed() end)
assert(not L.ghost.doro and not find(L.wire,'^have %d+ no'))

-- 13. coop off mid-race: its DNF out, the race closed.
H,G=pair()
player=H.eve
H.race.command('start','quest')
run({H,G},function() return H.go_at end)
frames({H,G},10)
player=H.eve
H.race.stop()
assert(not H.race.armed() and not H.look.on and H.look.why=='race coop off' and H.sent[#H.sent]:find('^dnf %d+ quit$'))
assert(not H.drive.on and H.drive.why=='race coop off')
frames({H,G},3)
G.race.stop()
assert(not G.race.armed() and #alive()==0)
-- A recording too.
H.race.command('record','x')
H.race.stop()
assert(H.race.key()==nil)

-- 14. A first error ends the race and its look until the mod reloads.
H,G=pair()
player=H.eve
H.race.command('start','quest')
spawn_error='the Doro could not be spawned'
step({H,G})
spawn_error=nil
assert(H.errors[1]=='the race stopped on an error until the mod reloads: the Doro could not be spawned',H.errors[1])
assert(not H.race.armed() and not H.look.on and H.look.why=='race error')
ok,message=H.race.command('start','quest')
assert(not ok and message=='the race stopped on an error (the Doro could not be spawned); none until the mod reloads')
H.race.receive('track 7 4 1 0 0 0 0 '..MAP)
assert(not H.race.armed(),'Nor a guest\'s')
-- Its quit line went out first: the race is cancelled on her PC too.
assert(H.wire[#H.wire]:find('^abort %d+ quit$'),H.wire[#H.wire])
frames({H,G},3)
assert(not G.race.armed() and not G.look.on and G.told[#G.told]=='Race cancelled.')
-- An error on her PC mid-race: her DNF goes out, the host's ghost of her is herself again, and he ranks alone.
H,G=pair()
player=H.eve
H.race.command('start','quest')
run({H,G},function() return G.go_at and clock-G.go_at>3 end)
G.puppet.me=function() error('the ghost is gone',0) end
run({H,G},function() return #G.errors>0 end,10)
assert(G.errors[1]=='the race stopped on an error until the mod reloads: the ghost is gone' and not G.race.armed())
assert(G.sent[#G.sent]:find('^dnf %d+ quit$') and not G.look.on) -- Sent at the next frame.
run({H,G},function() return not H.race.armed() end)
assert(not H.ghost.doro and has(H.told,'Kaanta left the race.') and find(H.logs,'^result .* rank=1$'))

-- 14a. The driving's errors: a drive that cannot go on at GO ends the race; so does a frame of it that raises, the
-- driving off.
do
    local S=side()
    S.files[FILE],S.move=TEXT,racer(0)
    player=S.eve
    S.drive.refuse='EVE has no movement component'
    assert(S.race.command('start','quest'))
    run({S},function() return #S.errors>0 end)
    assert(S.errors[1]=='the race stopped on an error until the mod reloads: no driving: EVE has no movement component',
        S.errors[1])
    assert(not S.race.armed() and not S.look.on and not S.drive.on)
    S=side()
    S.files[FILE],S.move=TEXT,racer(0)
    player=S.eve
    assert(S.race.command('start','quest'))
    run({S},function() return S.drive.on end)
    S.drive.error='no velocity'
    step({S})
    assert(S.errors[1]=='the race stopped on an error until the mod reloads: no velocity',S.errors[1])
    assert(not S.drive.on and S.drive.why=='race error' and S.ghost.top==nil)
end
-- 14b. The drive probe, with no race: coop race drive reaches drive.lua; no race starts while it runs; each frame
-- drives it and gives the look its values, every 250 ms its check; its error ends it, and so does coop off. The first
-- frame restores what an earlier Lua load's drive left, once.
do
    local S=side()
    S.files[FILE]=TEXT
    player=S.eve
    ok,message=S.race.command('drive','top','2600')
    assert(ok and S.drive.said[1]=='top' and S.drive.said[2]=='2600')
    S.move=racer(0)
    assert(S.race.command('start','quest'))
    ok,message=S.race.command('drive','probe')
    assert(not ok and message=='a race is armed: coop race quit leaves it' and S.drive.said[1]=='top')
    S.race.command('quit')
    step({S})
    assert(not S.race.armed())
    S.drive_api.on({top=2200},'probe') -- What drive.lua's coop race drive probe does.
    ok,message=S.race.command('start','quest')
    assert(not ok and message=='the drive probe runs: coop race drive off ends it')
    S.look.on=true
    S.race.tick()
    assert(S.drive.ticks==1 and S.look.drive.top==2200 and S.drive.restored==1)
    S.race.tick()
    S.race.slow()
    assert(S.drive.restored==1 and S.drive.slows==1,'Restored once')
    S.drive.error='no stick'
    local _,why=S.race.tick()
    assert(why=='the drive probe stopped on an error: no stick; drive off (error)' and not S.drive.on,tostring(why))
    assert(S.look.drive==nil)
    S.drive.error=nil
    S.drive_api.on({top=2200},'probe')
    S.race.stop()
    assert(not S.drive.on and S.drive.why=='coop off')
end
-- 14c. Display Doros an earlier Lua load left (Ctrl+R mid-race): swept at the first tick, once, the file cleared.
do
    local S=side({stored='/Doro/old1\t/Game/Other'})
    S.race.tick()
    assert(#swept==2 and swept[1]=='/Doro/old1' and swept[2]=='/Game/Other' and S.stored==nil)
    assert(S.logs[#S.logs]=='race: 1 display Doros an earlier Lua load left destroyed',S.logs[#S.logs])
    S.stored='/Doro/later'
    S.race.tick()
    assert(#swept==2 and S.stored=='/Doro/later','Once a Lua load')
end
-- A Doro that would not go when its race closed stays in the file for the next Lua load's sweep.
do
    local S=side()
    S.files[FILE],S.move=TEXT,racer(0)
    player=S.eve
    assert(S.race.command('start','quest'))
    step({S})
    local d=doros[#doros]
    assert(not d.removed and S.stored==d.path,tostring(S.stored))
    remove_error='destroy failed'
    assert(S.race.command('quit'))
    step({S}) -- Closed at the next frame.
    remove_error=nil
    assert(not S.race.armed() and S.stored==d.path,tostring(S.stored))
    d.removed=true
end

-- 15. Together only: race.lua, race_model.lua, doro.lua, drive.lua and drive_model.lua name no achievement, reward,
-- item, quest, save, possession or console command call, and spawn a plain /Script/Engine.Actor only (doro.lua's one
-- SpawnActor).
for _,name in ipairs({'race','race_model','doro','drive','drive_model'}) do
    local f=assert(io.open('mod/StellarCoop/Scripts/'..name..'.lua','rb'))
    local src=f:read('a')
    f:close()
    for call in src:gmatch('[:.]([%a_][%w_]*)%s*%(') do
        for _,word in ipairs({'Achiev','Reward','Item','Quest','Save','ExecuteConsoleCommand','Possess','Spawn',
            'CreateActor','Destroy'}) do
            if call:find(word) then
                assert(call=='SpawnActor' and name=='doro' or call:find('^K2_Destroy') and name=='doro'
                    or call=='spawn' or call=='remove',name..': '..call)
            end
        end
    end
    local spawns=0
    for class in src:gmatch(':SpawnActor%(find%(\'([^\']+)\'%)') do
        spawns=spawns+1
        assert(class=='/Script/Engine.Actor',name..': '..class)
    end
    assert(select(2,src:gsub(':SpawnActor%(',''))==spawns,name..': a SpawnActor of another form')
    assert(name~='doro' or spawns==1)
    assert(not src:find('ExecuteConsoleCommand') and not src:find('Achievement') and not src:find('Reward'),name)
end
print('race_test ok')
