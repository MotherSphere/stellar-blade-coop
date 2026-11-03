-- matrix13/quest/zone_talks.lua over fakes: every scene has one trigger, its box holds its design point, a box, a boss's
-- death, an env state and a way out latch a scene; a fight or a screen delays it and sets the kit's gate shut, and a
-- fight cuts a scene that waits for its theater or plays through it (not marked, said once, again from its start after
-- RETRY s, not while its scene still ends); a drop leaves a talk whose Stop row was sent to end, marked at its end but
-- not on a co-op slot loaded since; the lines asked of the game's subtitle box (play_lines), a theater, sequence or kit
-- end marked; 3B before 3C, 3I before 3J, nothing of Lily after 3K; fight scenes wait for a fight or 25 s in the box;
-- oblivion lines only with oblivion=1; once per co-op slot through its file, cleared by restart; one log line a scene;
-- at most one look a second, no object walk, no theater look (the talk player waits for a theater of the game);
-- leaving the world drops the one playing.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local function object(t)
    t=t or {}
    t.type=t.type or function() return 'UObject' end
    t.IsValid=t.IsValid or function() return true end
    t.GetAddress=t.GetAddress or function(self) return tonumber(tostring(self):match('0x(%x+)'),16) end
    return t
end
FName=function(s) return s end
package.loaded.UEHelpers={GetPlayer=function() return nil end,GetPlayerController=function() return nil end}
local plan_of={x=0,y=0,z=500} -- Where EVE stands: nowhere of the map.
local eve=object({K2_GetActorLocation=function() return {X=0,Y=0,Z=0} end})
local chars,looks,walks={},0,0
FindAllOf=function(name)
    walks=walks+1
    if name=='PlayerController' then return {object()} end
    return {}
end
local envs={}
local gs=object({GetAllActorsOfClass=function(_,_,cls,out)
    looks=looks+1
    local from=cls.path:find('EnvActor') and envs or cls.path:find('SBCharacter') and chars or {object()}
    for i,a in ipairs(from) do out[i]=a end
end})
StaticFindObject=function(path)
    if path=='/Script/Engine.Default__GameplayStatics' then return gs end
    return object({path=path})
end
local Boss=require('matrix13.world.boss')
local Z=require('matrix13.quest.zone_talks')

local function scene(id)
    for _,s in ipairs(Z.SCENES) do
        if s.id==id then return s end
    end
end
-- The data: 36 scenes, in the talks' files and back, one trigger each; a point in each box from the design notes.
do
    local n=0
    for _,s in ipairs(Z.SCENES) do
        n=n+1
        assert(Z.LINES[s.id],s.id)
        local count=(s.box and 1 or 0)+(s.boss and 1 or 0)+(s.env and 1 or 0)+(s.leave and 1 or 0)
        assert(count==1,s.id)
        assert(s.boss==nil or require('matrix13.world.rows').BOSS[s.boss],s.id)
    end
    for id in pairs(Z.LINES) do assert(scene(id),id) end
    assert(n==36,n)
    for id,p in pairs({['1B']={23.5,25.4,1.1},['1C']={-16.0,43.8,-2.3},['3I']={-174.5,-262.3,-114.8},
            ['4E']={-162.05,-4.35,-151},['4B']={-164,-91,-151},['4M']={-90,-130,-155}}) do
        assert(Z.inside({x=p[1],y=p[2],z=p[3]},scene(id).box),id)
    end
    assert(not Z.inside({x=-162,y=-4,z=-144},scene('4E').box),'The lamp box stops under shelf 1')
    assert(Z.inside({x=-162,y=-4,z=-144},scene('4F').box))
    assert(#Z.lines_of('3B',true)==#Z.LINES['3B'] and #Z.lines_of('3B',false)==#Z.LINES['3B']-3)
    assert(#Z.lines_of('3J',false)==#Z.LINES['3J']-5)
end

-- The lamp's box touches the corridor to the Lion's room, so 4E needs 4D before its box counts.
assert(scene('4E').needs=='4D')
-- Mila's body: nothing before 4E (so not during the Lion's fight), the shelf from 4E playing until 4M played, nothing
-- between 4M and 4N, the floor from 4N playing, only with EVE in zone 4.
do
    local place=Z.mila_place
    assert(place({},nil,true)==nil and place({['4D']=true},nil,true)==nil)
    assert(place({},'4E',true)=='shelf' and place({['4E']=true},nil,true)=='shelf')
    assert(place({['4E']=true},'4F',true)=='shelf' and place({['4E']=true,['4M']=false},nil,true)=='shelf')
    assert(place({['4E']=true,['4M']=true},nil,true)==nil)
    assert(place({['4E']=true,['4M']=true},'4N',true)=='floor' and place({['4N']=true},nil,true)=='floor')
    assert(place({['4N']=true},nil,false)==nil and place({},'4E',false)==nil)
end

local function new_world(files,mila)
    local lines,played={},{}
    local talks={now=nil,scene=nil,walks=0}
    function talks.playing() return talks.now end
    function talks.cutscene() talks.walks=talks.walks+1; return talks.scene end
    function talks.stop(why) talks.dropped=why; talks.now=nil end
    function talks.play_lines(name,l,gate,done) talks.now,talks.gate,talks.done,talks.got=name,gate,done,l; return true end
    -- subtitles' cut(): a talk on its theater (talks.theater) ends as cut, kept (talks.now) until its scene ends
    -- (talks.ended()); one already stopping (talks.stopping) is ending: true, no done; on the kit it goes on.
    function talks.cut(why)
        talks.cut_why=why
        if talks.stopping then return true end
        if not talks.theater then return false end
        local d=talks.done
        talks.done=nil
        d('cut')
        return true
    end
    function talks.ended() talks.now=nil end
    function talks.finish(how)
        local d=talks.done
        played[#played+1]=talks.now
        talks.now,talks.done=nil,nil
        d(how or 'kit')
    end
    local z=Z.new({log=function(m) lines[#lines+1]=m end,talks=talks,plan=function() return plan_of end,
        read=function(n) return files[n] end,write=function(n,t) files[n]=t; return true end,mila=mila})
    return z,talks,lines,played
end
local clock=0
local function tick(z,extra)
    clock=clock+1
    local t={eve=eve,q={oblivion=0},now=clock,quiet=true,there=true,held=true,raw='\nslot=coop index=3 marker=1\n'}
    for k,v in pairs(extra or {}) do t[k]=v end
    z.tick(t)
end
local function stand(id)
    local b=scene(id).box or scene(id).leave
    plan_of={x=(b[1]+b[2])/2,y=(b[3]+b[4])/2,z=(b[5]+b[6])/2}
end
local function away() plan_of={x=0,y=0,z=500} end
local function calm(z,extra) for _=1,Z.CALM+1 do tick(z,extra) end end
local files={}
local z,talks,lines,played=new_world(files)

-- Away from everything: only EVE's position is read.
looks=0
tick(z); tick(z)
assert(looks==0 and talks.now==nil and #lines==0,'No look with no scene latched')
-- At most one look a second: 250 ms calls change nothing.
stand('1A')
tick(z)
local after=looks
z.tick({eve=eve,q={},now=clock+0.25,quiet=true,there=true,held=true,raw='\nslot=coop index=3\n'})
assert(looks==after,'At most one look a second')
assert(talks.now==nil,'CALM s first')
-- 1A plays after CALM s of calm, one line, and once.
calm(z)
assert(talks.now=='zone 1A' and #lines==1 and lines[1]=='zone talk 1A (R03): 5 of 5 lines, in the game\'s subtitle box',lines[1])
assert(talks.gate()==true)
talks.finish()
assert(files['coop-mxiii-talks-3.txt']=='1A\n',files['coop-mxiii-talks-3.txt'])
calm(z)
assert(talks.now==nil and #played==1,'Once')
away()

-- A fight: the box latches, nothing starts while an enemy is engaged, then it plays with no line skipped.
local foe=object({IsBattle=function() return true end,InteractionState=0,Controller=object(),
    K2_GetActorLocation=function() return {X=100,Y=0,Z=0} end})
chars[1]=foe
stand('1B'); tick(z); away()
for _=1,5 do tick(z) end
assert(talks.now==nil,'Never during a fight')
-- A body far off, dead or hidden is no fight.
foe.K2_GetActorLocation=function() return {X=Z.NEAR+1,Y=0,Z=0} end
tick(z); calm(z)
assert(talks.now=='zone 1B','A far enemy is no fight, and the latch outlives the box')
-- A fight during a scene shuts the gate at the next look, and it opens after.
foe.K2_GetActorLocation=function() return {X=100,Y=0,Z=0} end
tick(z); assert(talks.gate()==false,'A fight shuts the gate')
foe.IsBattle=function() return false end
tick(z); assert(talks.gate()==true)
tick(z,{quiet=false}); assert(talks.gate()==false,'A game screen shuts the gate')
tick(z)
talks.finish()
foe.InteractionState,foe.Controller=3,nil
foe.IsBattle=function() return true end

-- A game screen or a quest step delays a start.
stand('1D'); tick(z,{quiet=false}); away()
for _=1,5 do tick(z,{quiet=false}) end
assert(talks.now==nil)
for _=1,5 do tick(z,{busy=true}) end
assert(talks.now==nil)
-- A theater of the game: not looked for here (a walk of every object); the talk player waits for its end.
talks.scene='Subtitle_X'
for _=1,Z.CALM do tick(z) end
assert(talks.now=='zone 1D' and talks.walks==0,'No theater look of ours')
talks.scene=nil
talks.finish()

-- Order: 3C latches in its box but waits for 3B; 3J plays on leaving once 3I played.
stand('3C'); calm(z)
assert(talks.now==nil,'3B before 3C')
stand('3B'); calm(z)
assert(talks.now=='zone 3B')
assert(#talks.got==#Z.LINES['3B']-3,'No oblivion line without oblivion=1')
talks.finish()
away(); calm(z)
assert(talks.now=='zone 3C')
talks.finish()
away(); calm(z)
assert(talks.now==nil,'3I before 3J: leaving before 3I latches nothing')
stand('3I'); calm(z,{q={oblivion=1}})
assert(talks.now=='zone 3I')
talks.finish()
calm(z)
assert(talks.now==nil,'3J waits for EVE to leave')
away(); tick(z); calm(z,{q={oblivion=1}})
assert(talks.now=='zone 3J' and #talks.got==#Z.LINES['3J'],'With Oblivion complete, every line')
talks.finish()

-- Fight scenes: not on entry; after a fight seen, or SETTLE s in the box.
stand('2B'); calm(z)
assert(talks.now==nil,'2B waits for its fight')
foe.InteractionState,foe.Controller=0,object()
tick(z); tick(z)
foe.InteractionState,foe.Controller=3,nil
calm(z)
assert(talks.now=='zone 2B')
talks.finish()
-- A fight scene crossed with no fight lets go on leaving: a fight elsewhere does not play it there.
stand('2G'); calm(z); talks.finish()
stand('3D'); calm(z); talks.finish()
stand('3H'); tick(z); away(); tick(z)
foe.InteractionState,foe.Controller=0,object()
tick(z); tick(z)
foe.InteractionState,foe.Controller=3,nil
calm(z)
assert(talks.now==nil,'3H is about its own room')
stand('3H')
for _=1,Z.SETTLE-1 do tick(z) end
assert(talks.now==nil)
for _=1,3 do tick(z) end
assert(talks.now=='zone 3H','SETTLE s in the box with no fight')
talks.finish()

-- A boss's death.
away()
Boss.dead['DLC02_20_E_CharS_904']=true
calm(z); tick(z)
assert(talks.now=='zone 2F')
talks.finish()
Boss.dead['DLC02_40_E_CharS_051']=true
calm(z); tick(z)
assert(talks.now=='zone 4D')
talks.finish()
Boss.dead['DLC02_30_E_CharS_029']=true
calm(z); tick(z)
assert(talks.now=='zone 3G')
talks.finish()

-- The water: looked at only in zone 4; A plays 4H, B plays 4J; the actor is searched once and held.
local state,reads='Off',0
local water=object({EnvActorName='DLC02_40_EnvS_001',GetStateTagname=function() reads=reads+1; return state end})
local fan=object({EnvActorName='DLC02_40_EnvS_023',GetStateTagname=function() return 'Off' end})
envs[1],envs[2]=water,fan
state='A'
tick(z); tick(z)
assert(reads==0 and talks.now==nil,'No env look out of zone 4')
plan_of={x=-108,y=-34,z=-149}
calm(z); tick(z)
assert(reads>0 and talks.now=='zone 4H',tostring(talks.now))
talks.finish()
calm(z)
assert(talks.now==nil,'4J waits for B')
-- World 2800 loaded again with no tick out of it: another object at the held water's address is never read, and the
-- new water is looked for at the next search.
local stale=reads
water.EnvActorName='DLC02_40_EnvS_999'
envs[1]=object({EnvActorName='DLC02_40_EnvS_001',GetStateTagname=function() return state end})
state='B'
for _=1,Z.FIND+Z.CALM+1 do tick(z) end
assert(reads==stale and talks.now=='zone 4J',tostring(talks.now))
talks.finish()
-- A switch not on: 4G waits; on but 4F not played, it still waits.
fan.GetStateTagname=function() return 'On' end
calm(z)
assert(talks.now==nil,'4F before 4G')

-- 3K ends Lily: a Lily scene latched after it never plays, one line says so; Noa's 4A still plays.
stand('3K'); calm(z)
assert(talks.now=='zone 3K')
talks.finish()
stand('2C'); calm(z)
assert(talks.now==nil,'No Lily line after 3K')
assert(lines[#lines]=='zone talk 2C never plays: 3K ended Lily',lines[#lines])
stand('4A'); calm(z)
assert(talks.now=='zone 4A')
-- Out of the world: the scene dropped, not marked; it plays again from its start.
tick(z,{there=false})
assert(talks.dropped=='out of Matrix XIII' and talks.now==nil)
assert(not files['coop-mxiii-talks-3.txt']:find('4A',1,true))
calm(z)
assert(talks.now=='zone 4A','A dropped scene plays again')
-- A kit that is not up: not marked, said once, and tried again every RETRY s, not every second.
talks.finish('none')
assert(lines[#lines]=='STOP: zone talk 4A: none: it plays again from its start in 30 s at the earliest',lines[#lines])
assert(not files['coop-mxiii-talks-3.txt']:find('4A',1,true))
local said_lines=#lines
calm(z)
assert(talks.now==nil and #lines==said_lines,'No retry before RETRY s')
for _=1,Z.RETRY do tick(z) end
assert(talks.now=='zone 4A','Tried again')
talks.finish('none')
assert(#lines==said_lines,'Said once')
for _=1,Z.RETRY+1 do tick(z) end
assert(talks.now=='zone 4A')
talks.finish()

-- Through the theater: a fight cuts the scene, not marked, said once; nothing starts while its scene still ends, even
-- past RETRY s; again from its start once it ended, RETRY s after the cut at the earliest. Its last line shown and its
-- Stop row sent, a drop leaves it ending and its theater end marks it, but not on a co-op slot loaded since.
do
    local f={}
    local y,t,said=new_world(f)
    t.theater=true
    chars[1]=foe
    foe.InteractionState,foe.Controller=0,object()
    foe.IsBattle=function() return true end
    foe.K2_GetActorLocation=function() return {X=Z.NEAR+1,Y=0,Z=0} end -- Far: no fight yet.
    stand('1A'); calm(y)
    assert(t.now=='zone 1A' and t.got and #t.got==5,'Asked of the subtitle box')
    foe.K2_GetActorLocation=function() return {X=100,Y=0,Z=0} end
    tick(y)
    assert(t.done==nil and t.cut_why=='a fight' and not (f['coop-mxiii-talks-3.txt'] or ''):find('1A',1,true),'Cut')
    assert(said[#said]=='STOP: zone talk 1A: cut: it plays again from its start in 30 s at the earliest',said[#said])
    foe.IsBattle=function() return false end
    for _=1,Z.RETRY+Z.CALM do tick(y) end
    assert(t.now=='zone 1A' and t.done==nil,'No start while its scene ends')
    t.ended()
    tick(y)
    assert(t.now=='zone 1A' and t.done,'Again from its start')
    -- Leaving the world during its theater: cut (the Stop row), not only dropped.
    tick(y,{there=false})
    assert(t.cut_why=='out of Matrix XIII' and t.dropped==nil and t.done==nil,'Cut on leaving')
    t.ended()
    calm(y)
    assert(t.now==nil,'No retry before RETRY s')
    for _=1,Z.RETRY do tick(y) end
    assert(t.now=='zone 1A')
    t.stopping=true
    y.drop('a quest step')
    assert(t.dropped==nil and t.now=='zone 1A','Left to end')
    t.finish('theater')
    assert(f['coop-mxiii-talks-3.txt']:find('^1A\n'),tostring(f['coop-mxiii-talks-3.txt']))
    stand('1B'); calm(y)
    assert(t.now=='zone 1B')
    y.leave('a load')
    tick(y,{raw='\nslot=coop index=4\n'})
    t.finish('theater')
    assert(not f['coop-mxiii-talks-3.txt']:find('1B',1,true) and f['coop-mxiii-talks-4.txt']==nil,'Another slot since')
    t.stopping=nil
    chars[1]=nil
end
-- On Time not held: nothing starts.
do
    local f={}
    local y,t=new_world(f)
    stand('1A')
    for _=1,6 do tick(y,{held=false}) end
    assert(t.now==nil,'On Time held only')
    -- No co-op slot: nothing.
    for _=1,6 do tick(y,{raw='\nslot=main index=0\n'}) end
    assert(t.now==nil,'A co-op save only')
end
-- Once per save: a new Lua load reads the file; another slot has its own; restart clears it.
do
    local a=files['coop-mxiii-talks-3.txt']
    assert(a:find('1A\n',1,true) and a:find('4A\n',1,true))
    local y,t=new_world(files)
    stand('1A')
    calm(y); tick(y)
    assert(t.now==nil,'Played in an earlier Lua load')
    calm(y,{raw='\nslot=coop index=4\n'})
    assert(t.now=='zone 1A','Another slot has its own scenes')
    t.finish()
    assert(files['coop-mxiii-talks-4.txt']=='1A\n')
    y.restart()
    assert(files['coop-mxiii-talks-4.txt']=='')
    calm(y,{raw='\nslot=coop index=4\n'})
    assert(t.now=='zone 1A','A new On Time plays its scenes again')
end
-- The lamp before the Lion's death latches nothing, even when she comes back after 4D with no new crossing; the lamp
-- after it plays 4E. A death read goes in the file, so 4D survives a new Lua load, once; another slot forgets it.
envs[1],envs[2]=nil,nil -- The water's states of the block above stay out of these.
do
    Boss.dead={}
    local f={}
    local y,t=new_world(f)
    stand('4E'); calm(y); tick(y)
    assert(t.now==nil,tostring(t.now)..': 4E needs 4D')
    away()
    Boss.dead['DLC02_40_E_CharS_051']=true
    tick(y)
    assert(f['coop-mxiii-talks-3.txt']=='dead 4D\n',f['coop-mxiii-talks-3.txt'])
    -- Ctrl+R during the calm: Boss.dead is gone, the Lion stays dead.
    Boss.dead={}
    local y2,t2=new_world(f)
    calm(y2); tick(y2)
    assert(t2.now=='zone 4D','The death outlives the Lua load')
    t2.finish()
    assert(f['coop-mxiii-talks-3.txt']=='4D\n','Played: the mark goes')
    calm(y2); tick(y2)
    assert(t2.now==nil,'No crossing since 4D: 4E waits for the lamp')
    stand('4E'); calm(y2); tick(y2)
    assert(t2.now=='zone 4E')
    t2.finish()
    away()
    -- Another save: a death read on slot 3 proves nothing on slot 4.
    Boss.dead['DLC02_20_E_CharS_904']=true
    calm(y2,{raw='\nslot=coop index=4\n'}); tick(y2,{raw='\nslot=coop index=4\n'})
    assert(t2.now==nil and not next(Boss.dead),'Another slot: no 2F')
end
-- 4M closes 4K and 4L: they say nothing after it, one line each when latched.
do
    Boss.dead={}
    local y,t,l=new_world({})
    stand('4M'); calm(y); tick(y)
    assert(t.now=='zone 4M')
    t.finish()
    stand('4N'); calm(y); tick(y)
    assert(t.now=='zone 4N')
    t.finish()
    stand('4K')
    for _=1,Z.SETTLE+3 do tick(y) end
    assert(t.now==nil and l[#l]=='zone talk 4K never plays: 4M played',l[#l])
end
-- leave and drop: the scene dropped and not marked, Mila's body gone only when placed; drop keeps her.
do
    Boss.dead={}
    local wanted,calls={},0
    local mila={set=function(where) calls=calls+1; wanted[#wanted+1]=tostring(where) end}
    local f={['coop-mxiii-talks-3.txt']='4D\n'}
    local y,t=new_world(f,mila)
    y.leave('a load')
    assert(calls==0,'Nothing placed, nothing to do on a main save')
    stand('4E'); calm(y); tick(y)
    assert(t.now=='zone 4E')
    assert(wanted[#wanted]=='shelf')
    y.drop('a quest step')
    assert(t.dropped=='a quest step' and t.now==nil and not f['coop-mxiii-talks-3.txt']:find('4E',1,true))
    calm(y); tick(y)
    assert(t.now=='zone 4E','Plays again')
    y.leave('not solo on a co-op save')
    assert(t.dropped=='not solo on a co-op save' and t.now==nil and wanted[#wanted]=='nil')
    calm(y); tick(y)
    assert(t.now=='zone 4E','A leave marks nothing')
end
-- An error is said once and stops nothing else.
do
    local y,_,l=new_world({})
    local bad=object({K2_GetActorLocation=function() error('no location',0) end})
    tick(y,{eve=bad}); tick(y,{eve=bad})
    assert(#l==1 and l[1]=='STOP: zone talks: no location',l[1])
end
assert(walks<=1,'One FindAllOf: U.actors_of proving its class hash')
print('matrix13/quest/zone_talks_test: ok')
