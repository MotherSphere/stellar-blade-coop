-- matrix13/quest/zone_talks.lua over fakes: every scene has one trigger, its box holds its design point, a box, a boss's
-- death, an env state and a way out latch a scene; a fight or a screen delays it and sets the kit's gate shut; 3B before
-- 3C, 3I before 3J, nothing of Lily after 3K; fight scenes wait for a fight or 25 s in the box; oblivion lines only with
-- oblivion=1; once per co-op slot through its file, cleared by restart; one log line a scene; at most one look a second,
-- no object walk; a theater of the game delays a scene; leaving the world drops the one playing.
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

local function new_world(files)
    local lines,played={},{}
    local talks={now=nil,cut=nil,walks=0}
    function talks.playing() return talks.now end
    function talks.cutscene() talks.walks=talks.walks+1; return talks.cut end
    function talks.stop(why) talks.dropped=why; talks.now=nil end
    function talks.lines(name,l,gate,done) talks.now,talks.gate,talks.done,talks.got=name,gate,done,l; return true end
    function talks.finish(how)
        local d=talks.done
        played[#played+1]=talks.now
        talks.now,talks.done=nil,nil
        d(how or 'kit')
    end
    local z=Z.new({log=function(m) lines[#lines+1]=m end,talks=talks,plan=function() return plan_of end,
        read=function(n) return files[n] end,write=function(n,t) files[n]=t; return true end})
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
assert(talks.now=='zone 1A' and #lines==1 and lines[1]=='zone talk 1A (R03): 5 of 5 lines, on the kit',lines[1])
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
-- A theater of the game: looked for once at the start, then every AGAIN s.
talks.cut='Subtitle_X'
local w=talks.walks
for _=1,Z.CALM do tick(z) end
assert(talks.walks==w+1 and talks.now==nil,'One theater look')
tick(z)
assert(talks.walks==w+1,'Not every second')
talks.cut=nil
for _=1,Z.AGAIN do tick(z) end
assert(talks.now=='zone 1D')
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
state='B'
calm(z); tick(z)
assert(talks.now=='zone 4J')
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
-- A kit that is not up: not marked, said, and tried again.
talks.finish('none')
assert(lines[#lines]:find('the kit is not up',1,true))
assert(not files['coop-mxiii-talks-3.txt']:find('4A',1,true))
calm(z)
assert(talks.now=='zone 4A')
talks.finish()

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
-- An error is said once and stops nothing else.
do
    local y,_,l=new_world({})
    local bad=object({K2_GetActorLocation=function() error('no location',0) end})
    tick(y,{eve=bad}); tick(y,{eve=bad})
    assert(#l==1 and l[1]=='STOP: zone talks: no location',l[1])
end
assert(walks<=1,'One FindAllOf: U.actors_of proving its class hash')
print('matrix13/quest/zone_talks_test: ok')
