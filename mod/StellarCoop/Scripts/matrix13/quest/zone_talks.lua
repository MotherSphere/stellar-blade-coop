-- The zone talks of Matrix XIII (matrix13/talks/zone1.lua to zone4.lua) in game (experimental, untested in game): on a
-- co-op save, solo, in world 2800 with "On Time" in progress (matrix13/quest/on_time.lua's look calls tick). Each scene
-- has one trigger: a box around its room in the plan frame (Lily.plan; the design plans' rooms, markers and routes), a
-- boss's death (matrix13/world/boss.lua's Boss.dead), an env actor's state (GetStateTagname: the water row 001 that
-- pipe panels 006 and 007 set, the fan 1 switch 023), or leaving a box once an earlier scene played. A trigger latches,
-- so a box crossed during a fight still plays. A latched scene starts when no talk or quest step runs, no screen of
-- the game shows, no enemy has been engaged for CALM s and no theater of the game plays. Scenes marked fight also need
-- a fight seen since they latched, or SETTLE s in their box: they are "after the fight" scenes.
-- Order: after names the scene that must have played first (3B before 3C, 3I before 3J; 4L after 4K, 4N after 4M). 3K
-- ends Lily: a scene with a Lily line that has not played before it never plays. Lines with oblivion=true play only
-- when the signalquest line reads oblivion=1 (native quest/own.h, the read of Quest_Sub_005 on Quest_Sub_030).
-- The lines go on the kit (story/subtitles.lua's lines()): no theater, no sequence, no input change, so EVE keeps
-- control. The game's subtitle box is not used: its talks borrow a sequence with a fixed window count, through a theater
-- whose template allows walking only. A fight or a game screen holds the next line and hides the kit's group, so no
-- line is skipped and none shows during a fight.
-- Looks: at most one a second, and only what is needed. EVE's position always; the engaged look (GetAllActorsOfClass,
-- no object walk once U.actors_of proved its class hash) only while a scene is latched or playing; env actors only in
-- zone 4 with their scene waiting, searched once and then held; the theater look (a walk of every object, 25 to 80 ms)
-- once when a scene is about to start, then every AGAIN s while a theater plays.
-- Once per save: the played scenes are kept in coop-mxiii-talks-<co-op slot index>.txt beside coop-settings.txt, as the
-- shared quests keep one record per co-op slot. Nothing of it reaches the game's save, so loading an older save of
-- that slot does not bring a scene back; a new "On Time" on that slot (restart) clears the file. One [LY] line a scene.
-- Mila's body follows the scenes (o.mila, matrix13/world/mila.lua), with EVE in zone 4 only: the shelf recess from 4E, so
-- never during the Lion's fight, until 4M played, then the drive room floor from 4N.
local U=require('core.unreal')
local Boss=require('matrix13.world.boss')
local Zones={}
-- s between two looks; calm before a scene starts; in the box before a fight scene with no fight; between two theater
-- looks; between two env searches. cm: an engaged enemy farther than this is no fight [inference].
Zones.EVERY,Zones.CALM,Zones.SETTLE,Zones.AGAIN,Zones.FIND,Zones.NEAR=1,3,25,5,30,5000
local LILY='Seq_Actor_Lily'
-- x, y of its south-west corner, its widths, its floor and height above it, in plan metres.
local function box(x,y,w,d,z,h) return {x,x+w,y,y+d,z-1,z+h} end
local WATER,FAN='DLC02_40_EnvS_001','DLC02_40_EnvS_023'
-- Play order, also the order latched scenes are tried in. A height under the room's keeps a floor above out.
Zones.SCENES={
    {id='1A',place='R03',box=box(-13.52,8.76,27.04,20.28,0,4.06)},
    {id='1B',place='R04',box=box(13.52,12.14,13.52,13.52,0,4.06)},
    {id='1C',place='R08, citizen 157',box=box(-18.68,42.56,8.48,12,-3.18,3)},
    {id='1D',place='R09',box=box(-10.2,35.8,20.4,49.8,-4.89,3)},
    {id='1E',place='R29',box=box(-16.96,22.28,13.52,13.52,-27.31,6)},
    {id='2A',place='Z2R05',box=box(-30,-60,23.68,10,-27.31,6)},
    {id='2B',place='Z2R16',box=box(10.2,-60,29.8,23,-27.31,8.6),fight=true},
    {id='2C',place='Z2R17',box=box(23.72,-98,16.28,18,-27.31,6.5)},
    {id='2D',place='Z2R21',box=box(24,-152,16,12,-31.31,12)},
    {id='2E',place='Z2R23',box=box(-36,-147.69,60,3.38,-31.31,6)},
    {id='2F',place='the Gardener dead',boss='DLC02_20_E_CharS_904'},
    {id='2G',place='Z2R32',box=box(-80,-164,34,23,-31.31,10)},
    {id='3A',place='Z3R03',box=box(-175,-180,25,30,-85.94,5.94)},
    {id='3B',place='Z3R06',box=box(-240,-192,50,12,-97.94,6)},
    {id='3C',place='Z3P02',box=box(-262,-183,23,15,-97.94,6),after='3B'},
    {id='3D',place='Z3R10',box=box(-285,-194,30,34,-101.94,21.94)},
    {id='3F',place='Z3R18',box=box(-160,-252,14,16,-106.94,6)},
    {id='3G',place='the Stalker dead',boss='DLC02_30_E_CharS_029'},
    {id='3H',place='Z3R22',box=box(-96,-296,14,120,-115.94,17),fight=true},
    {id='3I',place='Z3R28',box=box(-195,-275,35,15,-115.94,8)},
    {id='3J',place='leaving Z3R28',leave=box(-195,-275,35,15,-115.94,8),after='3I'},
    {id='3K',place='Z3R32',box=box(-215,-180,20,30,-151.94,24)},
    {id='4A',place='Z4R02',box=box(-198,-130,28,40,-162.79,25)},
    {id='4B',place='Z4R03',box=box(-170,-110,13,36.76,-151.94,5.94)},
    {id='4C',place='Z4P04',box=box(-173,-41,8,33,-151.94,5)},
    {id='4D',place='the Lion dead',boss='DLC02_40_E_CharS_051'},
    {id='4E',place='the yellow lamp',box=box(-168,-10,12,12,-151.94,5)}, -- Around Mila's lamp at (-162.05, -4.35).
    {id='4F',place='shelf 1',box=box(-170,-10,14,8,-144.94,4),after='4E'}, -- Climbing wall 1's top, x -164.
    {id='4G',place='fan 1 on',env=FAN,states={On=true},after='4F'},
    {id='4H',place='the water at P2',env=WATER,states={A=true,B=true}},
    {id='4I',place='Z4R16',box=box(-168,-140,23,20,-149.94,6)},
    {id='4J',place='the water at P3',env=WATER,states={B=true}},
    {id='4K',place='the apron, after the last fight',box=box(-122,-118,30,33,-159.79,6),fight=true},
    {id='4L',place='the control room door',box=box(-113,-121,9,7,-159.79,5),after='4K'},
    {id='4M',place='Z4R18',box=box(-95,-150,15,40,-156.29,16.29)},
    {id='4N',place='Mila arrives',box=box(-95,-150,15,40,-156.29,16.29),after='4M'},
}
Zones.ZONE4=box(-285,-150,205,190,-176,96)
local LINES={}
for z=1,4 do
    for name,lines in pairs(require('matrix13.talks.zone'..z)) do LINES[name]=lines end
end
Zones.LINES=LINES
local function inside(p,b)
    return p.x>=b[1] and p.x<=b[2] and p.y>=b[3] and p.y<=b[4] and p.z>=b[5] and p.z<=b[6]
end
Zones.inside=inside
-- A scene's lines: oblivion=true ones only when the quest is complete.
function Zones.lines_of(id,oblivion)
    local out={}
    for _,l in ipairs(LINES[id]) do
        if oblivion or not l.oblivion then out[#out+1]=l end
    end
    return out
end
-- Where Mila's body is: played (scene id -> true), playing (the scene the kit plays), zone4 (EVE is in the zone).
function Zones.mila_place(played,playing,zone4)
    if not zone4 then return nil end
    if playing=='4N' or played['4N'] then return 'floor' end
    if (playing=='4E' or played['4E']) and not played['4M'] then return 'shelf' end
end
local function has_lily(id)
    for _,l in ipairs(LINES[id]) do
        if l[1]==LILY then return true end
    end
    return false
end
-- Whether an enemy within NEAR of EVE fights: IsBattle, standing, shown, with a controller.
local function engaged(eve)
    local here=U.value_of(eve:K2_GetActorLocation())
    local mine=U.address(eve)
    for _,c in ipairs((U.actors_of(U.find('/Script/SB.SBCharacter'),'SBCharacter',eve))) do
        local ok,fights=pcall(function()
            if U.address(c)==mine or c:IsBattle()~=true or c.bCharacterHiddenInGame==true then return false end
            local st,at=c.InteractionState,U.value_of(c:K2_GetActorLocation())
            local d=math.sqrt((at.X-here.X)^2+(at.Y-here.Y)^2+(at.Z-here.Z)^2)
            return (st==0 or st==1) and U.valid(c.Controller)~=nil and d<=Zones.NEAR
        end)
        if ok and fights then return true end
    end
    return false
end

-- o: log (the [LY] lines), talks (story/subtitles.lua's player), plan (world cm to plan m), read(name) and write(name,
-- text) (a file of ours beside coop-settings.txt).
function Zones.new(o)
    local log,talks=o.log,o.talks
    local self={}
    local next_at=-math.huge
    local slot=nil -- The co-op slot index whose file is read.
    local played={} -- Scene id -> true, in the file.
    local state={} -- Scene id -> {latched=, fought=, in_box= (s in its box since it latched), last=}.
    local playing=nil -- The scene the kit plays.
    local open=true -- The kit's gate: no fight, no screen.
    local calm_since,theater_at=nil,-math.huge
    local envs,find_at,env_said={},-math.huge,false -- Env actors by name, held; the next search.
    local failed=nil -- The last error said.
    local function file() return 'coop-mxiii-talks-'..slot..'.txt' end
    local function save()
        local ids={}
        for id in pairs(played) do ids[#ids+1]=id end
        table.sort(ids)
        if slot and not o.write(file(),table.concat(ids,'\n')..'\n') then
            log('STOP: zone talks: '..file()..' not written: once a Lua load only until it can be')
        end
    end
    local function load_slot(raw)
        local n=tonumber((raw or ''):match('\nslot=coop index=(%d+)'))
        if n==slot then return end
        slot,played,state=n,{},{}
        if n then
            for id in tostring(o.read(file()) or ''):gmatch('[1-4]%u') do played[id]=true end
        end
    end
    local function state_of(env,eve,now)
        local a=U.valid(envs[env])
        if not a and now>=find_at then
            find_at=now+Zones.FIND
            for _,x in ipairs((U.actors_of(U.find('/Script/SB.SBZoneEnvActor'),'SBZoneEnvActor',eve))) do
                local ok,name=pcall(function() return U.text(x.EnvActorName) end)
                if ok and (name==WATER or name==FAN) then envs[name]=x end
            end
            a=U.valid(envs[env])
            if not a and not env_said then
                env_said=true
                log('STOP: zone talks: no env actor '..env..' in this world yet: looked for again every '..Zones.FIND..' s')
            end
        end
        return a and U.text(a:GetStateTagname())
    end
    local function latch(s,st,p,t)
        local hit=false
        if s.box then hit=inside(p,s.box)
        elseif s.leave then hit=played[s.after] and not inside(p,s.leave)
        elseif s.boss then hit=Boss.dead[s.boss]
        elseif s.env and inside(p,Zones.ZONE4) then hit=s.states[state_of(s.env,t.eve,t.now) or '']
        end
        if hit then st.latched,st.last=true,t.now end
    end
    local function start(s,t)
        local lines=Zones.lines_of(s.id,t.q and t.q.oblivion==1)
        playing=s.id
        log(string.format('zone talk %s (%s): %d of %d lines, on the kit',s.id,s.place,#lines,#LINES[s.id]))
        talks.lines('zone '..s.id,lines,function() return open end,function(how)
            playing=nil
            if how=='kit' then
                played[s.id]=true
                save()
            else
                log('STOP: zone talk '..s.id..': the kit is not up: it plays when the kit is back')
            end
        end)
    end
    local function mila(where,eve)
        if not o.mila then return end
        local ok,why=pcall(o.mila.set,where,eve)
        if not ok then log('STOP: Mila: '..tostring(why)) end
    end
    local function step(t)
        if t.now<next_at then return end
        next_at=t.now+Zones.EVERY
        load_slot(t.raw)
        if playing and not talks.playing() then playing=nil end
        if not (t.there and t.held and t.eve and slot) then
            if playing then talks.stop('out of Matrix XIII') playing=nil end
            calm_since=nil
            mila(nil)
            return
        end
        local p=o.plan(U.value_of(t.eve:K2_GetActorLocation()))
        mila(Zones.mila_place(played,playing,inside(p,Zones.ZONE4)),t.eve)
        local waiting=false
        for _,s in ipairs(Zones.SCENES) do
            if not played[s.id] and s.id~=playing then
                state[s.id]=state[s.id] or {}
                local st=state[s.id]
                if not st.latched and not st.closed then latch(s,st,p,t) end
                if st.latched and played['3K'] and has_lily(s.id) then
                    st.latched,st.closed=false,true
                    log('zone talk '..s.id..' never plays: 3K ended Lily')
                end
                if st.latched then
                    waiting=true
                    if s.fight and inside(p,s.box) then
                        st.in_box=(st.in_box or 0)+(t.now-(st.last or t.now))
                    end
                    st.last=t.now
                end
            end
        end
        if not waiting and not playing then
            calm_since,open=nil,true
            return
        end
        local fights=engaged(t.eve)
        open=t.quiet and not fights
        if fights then
            calm_since=nil
            for _,s in ipairs(Zones.SCENES) do
                local st=state[s.id]
                if s.fight and st and st.latched then st.fought=true end
            end
            return
        end
        calm_since=calm_since or t.now
        if playing or t.busy or talks.playing() or not t.quiet or t.now-calm_since<Zones.CALM then return end
        for _,s in ipairs(Zones.SCENES) do
            local st=state[s.id]
            if not played[s.id] and st and st.latched then
                if (not s.after or played[s.after])
                    and (not s.fight or st.fought or (st.in_box or 0)>=Zones.SETTLE) then
                    if t.now<theater_at then return end
                    local ran,busy=pcall(talks.cutscene)
                    if ran and busy then
                        theater_at=t.now+Zones.AGAIN
                        return
                    end
                    return start(s,t)
                end
            end
        end
    end
    -- From on_time.lua's look, every 250 ms: t.eve, t.q (its signalquest fields), t.now, t.quiet (no screen of the game),
    -- t.there (in world 2800), t.held (On Time in progress), t.busy (a quest step runs), t.raw (the status text).
    function self.tick(t)
        local ok,e=pcall(step,t)
        if not ok and tostring(e)~=failed then
            failed=tostring(e)
            log('STOP: zone talks: '..failed)
        end
    end
    -- A new "On Time" on this slot: every scene plays again.
    function self.restart()
        played,state={},{}
        for row in pairs(Boss.dead) do Boss.dead[row]=nil end
        if slot then o.write(file(),'') end
    end
    return self
end
return Zones
