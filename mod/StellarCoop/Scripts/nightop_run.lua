-- coop nightop: Night Operation's run on a co-op save (main.lua checks the slot), on the game thread. Five timed
-- waves of the game's base monsters come at EVE where she stands. nightop_waves.lua holds the schedule, the keys and
-- the run's states; this file is the game side: the start checks and the census, the one spawn call, the bodies it
-- tracks, their aggro and stuck moves, the abort watch and the end, and what the player sees: a card at the top centre
-- and a result panel on the Uplink kit (ui.lua), or notices while the kit is off. The run has no rule row: its clock is
-- game time and it ends itself. Solo when no Steam session holds; linked, the host starts a run for both players: the
-- night line (one full state from each side through the native part, link.lua's night) carries his ask, her answer,
-- his clock, waves, score and end, and her world's kills and bodies, so both worlds run the same seeded waves around
-- his start point and both cards show one timer and one score. Each world fights its own monsters, unless the shared
-- fight pairs their copies by key: then the guest leaves the aggro and stuck moves of a key the host tracks and has
-- not done to the pilot while same-place enemies draw at least one copy. A run of ours that went from its countdown to
-- a success or a time up credits its final score as points to this player's wallet; coop nightop shop and buy spend
-- them (nightop_shop.lua, which holds the one grant call). Never called here:
-- a table row added, a rule or remain-time request, EndRule, ResetZone, a zone event other than nightop.lua's heal,
-- EnterZone, a hide, a collision or pool flag write, a destroy, a save, inventory, equip or quest call, RegisterHook,
-- NotifyOnNewObject. No console word reaches a game call here: start's words only set flags; buy's words go through
-- nightop_shop.lua's checked grant. Beyond the kit (ui.lua), the HUD calls the game for one thing only: its own result
-- words (StringTable_UI).
-- Parts of this file adapt Survival Protocol by SchizoEffective (nexusmods.com/stellarblade/mods/4009), used with
-- permission given on 2026-10-20 and distributed here under GPL-3.0-or-later.
local U=require('unreal')
local W=require('nightop_waves')
local N=require('nightop')
local T=require('ui_text')
local Shop=require('nightop_shop')
local Run={}
local MASK=0xFFFFFFFF
local XION='/game/art/bg/worldmap/level_p/e04' -- Its people and quest scripts stay out of a fight.
local TICK=0.25 -- Seconds between two ticks (main.lua's loop). The abort watch counts ticks: game time stops in a load.
local CLEAR=40 -- Metres: no living character but EVE this close at the start.
local LEAVE,LEAVE_FOR,GONE_FOR=80,10,2 -- EVE farther than LEAVE m from the start for LEAVE_FOR s, or gone GONE_FOR s.
-- Seconds after a wave's last spawn call: its bodies are looked for; one not found by the last is missing.
local FINDS={1,2.5}
-- Seconds after a body is found: a controller if it has none, before the aggro so that a new one gets the focus and the
-- move (the second aggro skips a body in battle); aggro, and again later.
local ADOPT,AGGRO,AGAIN=0.5,0.6,4
local STUCK,EVERY,BELOW,AWAY,NEAR,MOVES=2.5,3,10,40,7,2 -- The stuck rule: seconds, then metres, then moves per body.
local SLOW=5 -- ms: a live-list refresh this slow gets its own line.
-- The HUD in the kit's layout units (3840 by 2160), both groups at the top centre and scaled from there: the card
-- (its title over one line) and, in its place once the run ends, the result panel (a heading, a line under it, then
-- four rows: a label at the left, its value at the right).
local HUD_W,CARD_H,RESULT_H,HUD_Y=1040,160,450,96 -- 1040: clear of the chat's feed (x 96 to 1396).
local MIDDLE,LEFT,RIGHT={X=0.5,Y=0.5},{X=0,Y=0.5},{X=1,Y=0.5}
-- The game's own words for the result (StringTable_UI, in its 23 cultures), and ui_text.lua's words for each abort
-- reason (stop and coop off: stop).
local STRINGS='/Game/Local/Localize/StringTable_UI.StringTable_UI'
-- The same word names an abort reason on the night line (a stop and coop off: stop).
local WHY={['map change']='map',left='left',slot='slot',link='link',error='error',lost='lost',mate='mate'}
-- A co-op run: ticks the host waits for her answer (and she for his countdown), ticks a partner's line may stay the
-- same before the link counts as lost, ticks between two lines that say the same, and metres the guest may stand from
-- his start point to join.
local ASK,QUIET,EVERY_LINE,FAR=20,20,4,50
local function metres(a,b) return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)/100 end
local function xyz(v) return string.format('%.0f,%.0f,%.0f',v.X,v.Y,v.Z) end
local function why(e) return (tostring(e):gsub('^.-:%d+: ','')) end -- Without the file and line.
local function location(actor)
    local v=U.value_of(actor:K2_GetActorLocation())
    return {X=v.X,Y=v.Y,Z=v.Z}
end
local function hex(key) return string.format('0x%08X',key) end
local function alias(b) return W.POOL[b.id].alias end
-- Adapted from Survival Protocol's wave lookup, which reads the same field.
local function key_of(c) -- BroadcastSpawnInfo.EventSpawnId, which the spawn sets from the call's key; unsigned.
    local k=math.tointeger(c.BroadcastSpawnInfo.EventSpawnId)
    return k and k&MASK
end
local function living(c) return c.InteractionState==0 and U.valid(c.Controller)~=nil end
-- Adapted from Survival Protocol rlIsDeadNow and rlBodyDead. InteractionState turns non-zero at death, but 1 alone
-- means "can be executed"; a dying body loses its controller at once. Killed: non-zero with no controller. Down, for
-- the wave check: non-zero or hidden by the game (read only).
local function signals(c)
    local st=c.InteractionState
    local killed=st~=0 and U.valid(c.Controller)==nil
    return killed,killed or st~=0 or c.bCharacterHiddenInGame==true
end
-- The one spawn call: a pool row and a wave key, its low byte as the spawn index. cheat=true takes any CharacterTable
-- ID at any transform; not a player, player 0, no spawn point, no possess.
function Run.spawn(pc,id,at,yaw,key)
    assert(W.POOL[id],'not a pool row')
    assert(math.type(key)=='integer' and key>=0 and W.decode(key),'not a wave key')
    pc:ServerRequest_CreateActor(id,at,{Pitch=0,Yaw=yaw,Roll=0},false,true,0,key,key&0xFF,FName('None'),false)
end
-- Adapted from Survival Protocol rlAggro. A 0.01 damage event from EVE and a noise at her wake the body's perception;
-- not in battle yet, it gets the game's battle state, its controller's focus on EVE and a move towards her. Each step
-- on its own; the text says which worked.
local function aggro(c,eve)
    local function try(f) return pcall(f) and 'ok' or 'failed' end
    local e,l=location(eve),location(c)
    local damage=try(function()
        U.find('/Script/AIModule.Default__AISense_Damage'):ReportDamageEvent(eve,c,eve,0.01,e,l)
    end)
    local noise=try(function()
        U.find('/Script/AIModule.Default__AISense_Hearing'):ReportNoiseEvent(eve,e,1.0,eve,0.0,FName('None'))
    end)
    local text='damage '..damage..', noise '..noise
    local ok,battle=pcall(function() return c:IsBattle() end)
    if ok and battle==true then return text..', in battle' end
    local state=try(function() c:Event_ChangeBattleState(true) end)
    local ctl=U.valid(c.Controller)
    if not ctl then return text..', battle '..state..', no controller' end
    local focus=try(function() ctl:K2_SetFocus(eve) end)
    local move=try(function()
        U.find('/Script/AIModule.Default__AIBlueprintHelperLibrary'):SimpleMoveToActor(ctl,eve)
    end)
    return text..', battle '..state..', focus '..focus..', move '..move
end
-- Adapted from Survival Protocol's stuck rule: K2_TeleportTo only (no hit result to fill), NEAR m from EVE on her line
-- to the body, half a metre up, facing her. Also whether the game refused the teleport (it returned false).
local function move(c,e,l)
    local d=math.max(1,math.sqrt((l.X-e.X)^2+(l.Y-e.Y)^2))
    local to={X=e.X+(l.X-e.X)/d*NEAR*100,Y=e.Y+(l.Y-e.Y)/d*NEAR*100,Z=e.Z+50}
    return to,c:K2_TeleportTo(to,{Pitch=0,Yaw=U.yaw_to(to,e),Roll=0})==false
end
-- One FindAllOf: the living characters but EVE within CLEAR m and the nearest of them, and every body that carries a
-- wave key (at most 8 named), with its run byte.
local function census(eve)
    local at,me,c=location(eve),U.address(eve),{near=0,keys={},taken={}}
    U.each(FindAllOf('SBCharacter') or {},function(_,o)
        o=U.valid(o)
        if not o or U.address(o)==me then return end
        local ok,key=pcall(key_of,o)
        local run=ok and W.decode(key)
        if run then
            c.taken[run]=true
            c.keys[#c.keys+1]=key
        end
        local up,alive=pcall(living,o)
        if up and alive then
            local d=metres(location(o),at)
            if d<=CLEAR then c.near=c.near+1 end
            if not c.nearest or d<c.nearest then c.nearest=d end
        end
    end)
    local named={}
    for i=1,math.min(8,#c.keys) do named[i]=hex(c.keys[i])..' run '..(c.keys[i]>>16&0xFF) end
    c.text=string.format('census: %d living within %d m (nearest %s); %d wave bodies%s',c.near,CLEAR,
        c.nearest and string.format('%.1f m',c.nearest) or 'none',#c.keys,
        #named>0 and ': '..table.concat(named,', ')..(#c.keys>8 and ', ...' or '') or '')
    return c
end
local function clock_text(seconds) return string.format('%d:%02d',seconds//60,seconds%60) end
-- The card's title and line for the run's state s at game time now, in words w (ui_text.lua's): the host's wait for
-- her answer, the countdown (hers from her answer on), then the wave or, once it is down, the next one's countdown
-- (the wave again once it is due and the cap holds it), each with the run time left and the score.
function Run.card(s,now,w)
    local n=w.night
    if s.phase=='ask' and s.role=='host' then return n.title,n.waiting end
    if s.phase=='countdown' or s.phase=='ask' then return n.title,n.starts:format(math.max(0,math.ceil(s.t0-now))) end
    local rt=now-s.t0
    local wait=s.phase=='breather' and s.next_at and math.ceil(s.next_at-rt)
    local head=wait and wait>0 and n.next:format(wait) or n.wave:format(s.wave,#W.SCHEDULE)
    return n.title,head..'  '..clock_text(math.max(0,math.ceil(W.LIMIT-rt)))..'  '..n.score:format(s.score)
end
-- An ended run's heading, the line under it ('' after a success) and its rows {label, value}, in words w. game(key):
-- the game's own text for a StringTable_UI key, or nil; read for the heading and a solo death's line only. A co-op run
-- (s.role 'host' or 'guest') says whose EVE died: its reason names the side.
function Run.result(s,w,game)
    local n=w.night
    local won=s.outcome=='success'
    local head=game(won and 'UI_Night_OperationSuccess' or 'UI_Night_OperationFail') or (won and n.success or n.fail)
    local sub=''
    if s.outcome=='failed' and s.reason then sub=s.reason==s.role and n.you_died or n.mate_died
    elseif s.outcome=='failed' then sub=game('UI_Night_OperationFail_Des') or n.died
    elseif s.outcome=='time' then sub=n.time_up
    elseif s.outcome=='aborted' then sub=n.why[WHY[s.reason] or 'stop'] end
    return head,sub,{{n.waves,s.clears..'/'..#W.SCHEDULE},{n.kills,tostring(s.kills)},{n.points,tostring(s.score)},
        {n.time,clock_text(math.floor(s.time))}}
end
local function no_text() return nil end
-- The game's text for a StringTable_UI key in its own language, as its menus show it; nil while that table is not
-- loaded or its id not a name (nothing is called then, so nothing loads it) or the key not registered, or on any error.
local function game_text(key)
    local ok,text=pcall(function()
        if not U.valid(StaticFindObject(STRINGS)) then return nil end
        local id=FName(STRINGS,EFindName.FNAME_Find)
        if id:GetComparisonIndex()==0
            or not U.find('/Script/Engine.Default__KismetStringTableLibrary'):IsRegisteredTableEntry(id,key) then
            return nil
        end
        return U.text(U.find('/Script/Engine.Default__KismetTextLibrary'):TextFromStringTable(id,key))
    end)
    return ok and text~='' and text or nil
end
-- log(text) writes an [NR] line; status() is the native part's status text; paused() whether the game is paused or
-- shows one of its screens (the UI kit's), when no body is read; tell(build) a notice that build(words) puts together
-- (main.lua's: the chat's feed, else the line above EVE), for what the HUD would show while the kit is off and for
-- what the partner did; send(line) writes our night line (link.lua's night); friend() the partner's Steam name;
-- store(name) link.lua's one-line file, for the shop's wallet.
function Run.new(o)
    local log,status,paused,tell=o.log,o.status,o.paused or function() return false end,o.tell
    local send,friend=o.send,o.friend or function() return nil end
    local hud=nil -- self.hud's {kit, theme, settings}; nil without one, or after a HUD error.
    -- The result panel: {s=the ended run's state, left=ticks it still shows}; it counts only the ticks it is seen.
    local panel=nil
    -- What the HUD shows goes to the notices instead while there is no kit or it is off.
    local function shown() return hud~=nil and not hud.kit.off() end
    local function notify(build) if tell and not shown() then tell(build) end end
    -- An ended run's state s as notices: the result, then what ended it unless it was a success.
    local function notify_end(s)
        local more=false
        notify(function(w)
            local head,line,rows=Run.result(s,w,no_text)
            more=line~=''
            return w.night.end_notice:format(head,s.clears,#W.SCHEDULE,s.kills,s.score,rows[4][2])
        end)
        if more then notify(function(w) return select(2,Run.result(s,w,no_text)) end) end
    end
    local r=nil -- The run, nil when idle: s is nightop_waves.lua's state; role 'host' or 'guest' in a co-op run.
    local shop=Shop.new({log=log,status=status,store=o.store,paused=paused,
        busy=function() return r~=nil and r.s.phase~='result' end})
    -- The night line. Ours: n (one up a line), the last line's words but n and rt, ticks since it went. Hers: the last
    -- night= text read. Each (run byte, seed) the guest answered, her refusal while she sends it, and the run bytes she
    -- refused as taken (the host skips them until the next Lua load).
    local out,heard,answered,answer,taken={n=0,ago=0},nil,{},nil,{}
    local function clock(eve) return U.find('/Script/Engine.Default__GameplayStatics'):GetTimeSeconds(eve) end
    -- The live list: the addresses of the latest FindAllOf('SBCharacter'), timed. Returns the characters.
    local function refresh()
        local t,set,list=os.clock(),{},{}
        U.each(FindAllOf('SBCharacter') or {},function(_,c)
            local ok,a=pcall(U.address,c)
            if ok and a then set[a],list[#list+1]=true,c end
        end)
        local ms=(os.clock()-t)*1000
        r.live,r.live_at,r.stale=set,r.now,false
        r.ms_n,r.ms_sum,r.ms_max=r.ms_n+1,r.ms_sum+ms,math.max(r.ms_max,ms)
        if ms>=SLOW then log(string.format('find: %.1f ms',ms)) end
        return list
    end
    -- Adapted from Survival Protocol valid(): a tracked body is read only while its address is in the live list, then
    -- through IsValid, with the name (comparison index) and the key it was found with.
    local function touch(b)
        if not r.live[b.addr] then return nil,'not in the live list' end
        local c=U.valid(b.obj)
        if not c then return nil,'not valid' end
        if c:GetFName():GetComparisonIndex()~=b.name then return nil,'another object at its address' end
        if key_of(c)~=b.key then return nil,'another key' end
        return c
    end
    -- A body leaves tracking for good (tombstoned: never read again) and its wave stops waiting for it. kill: it
    -- scores. leave: killed if it was seen down, else lost.
    local function kill(b)
        r.bodies[b.key]=nil
        r.input.killed[#r.input.killed+1]=b.key
        r.killed[#r.killed+1]=b
    end
    local function leave(b,reason)
        if b.down then return kill(b) end
        r.bodies[b.key]=nil
        r.input.done[#r.input.done+1]=b.key
        log(string.format('lost %s %s (%s)',hex(b.key),alias(b),reason))
    end
    -- f(c) on a tracked body that passes the guard; any failure, its own included, tombstones it.
    local function with(b,f)
        if r.bodies[b.key]~=b then return end
        local ok,c,reason=pcall(touch,b)
        if not ok then c,reason=nil,why(c) end
        if not c then return leave(b,reason) end
        local fine,e=pcall(f,c)
        if not fine then leave(b,why(e)) end
    end
    -- Adapted from Survival Protocol's adopt rule: a living body with no controller never moves; it gets its default.
    local function adopt(b)
        with(b,function(c)
            if c.InteractionState~=0 or U.valid(c.Controller) then return end
            local ok=pcall(function() c:SpawnDefaultController() end)
            log(string.format('controller %s: SpawnDefaultController %s',hex(b.key),
                ok and U.valid(c.Controller) and 'gave one' or 'failed'))
        end)
    end
    -- The guest's copy of a key the host tracks and has not done (his line's found), while her shared fight runs as the
    -- guest and the pilot draws at least one copy: frozen and drawn from his stream, so an aggro or a teleport would
    -- fight the pilot. Said once a key. Once he kills or writes off the key, her rules come back for her copy.
    local function piloted(b)
        if r.bodies[b.key]~=b or not (r.piloted and r.found[b.key]) then return false end
        if not b.piloted then
            b.piloted=true
            log(string.format('aggro %s: left to the pilot',hex(b.key)))
        end
        return true
    end
    local function push(b,again)
        if piloted(b) then return end
        with(b,function(c)
            if again and c:IsBattle()==true then return end
            log(string.format('aggro %s%s: %s',hex(b.key),again and ' again' or '',aggro(c,r.eve)))
        end)
    end
    -- Below the start point and EVE, or far from both (a body chasing her where she fights is left alone): moved next
    -- to EVE, at most MOVES times and never twice within EVERY s (one check each EVERY s); still out after that,
    -- written off for the wave check (a later kill still scores).
    local function stuck(b)
        local function check(now)
            if piloted(b) then return r.timers.add(now+EVERY,check) end
            with(b,function(c)
                local _,down=signals(c)
                local l,e=location(c),location(r.eve)
                if not down and (l.Z<math.min(r.p0.Z,e.Z)-BELOW*100 or metres(l,r.p0)>AWAY and metres(l,e)>AWAY) then
                    if b.moves>=MOVES then
                        r.input.done[#r.input.done+1]=b.key
                        log(string.format('written off %s %s at %s after %d moves',hex(b.key),alias(b),xyz(l),b.moves))
                        return
                    end
                    b.moves=b.moves+1 -- A refused teleport counts too.
                    local to,refused=move(c,e,l)
                    log(string.format('%s %s %s from %s (%.1f m from the start) to %s (%d/%d)',
                        refused and 'move refused' or 'moved',hex(b.key),alias(b),xyz(l),metres(l,r.p0),xyz(to),b.moves,
                        MOVES))
                end
                r.timers.add(now+EVERY,check)
            end)
        end
        return check
    end
    local function track(c,key,k,slot)
        local b={key=key,id=W.SCHEDULE[k].ids[slot+1],obj=c,addr=U.address(c),moves=0,
            name=c:GetFName():GetComparisonIndex()}
        r.bodies[key],r.seen[key]=b,true
        local t=r.now
        r.timers.add(t+ADOPT,function() adopt(b) end)
        if not r.noaggro then
            r.timers.add(t+AGGRO,function() push(b,false) end)
            r.timers.add(t+AGGRO+AGAIN,function() push(b,true) end)
        end
        if not r.nomove then r.timers.add(t+STUCK,stuck(b)) end
    end
    -- Wave k's bodies by key, in one FindAllOf that is also a refresh; at the last find, a slot never seen is missing.
    local function find(k,last,after)
        return function()
            local ids=W.SCHEDULE[k].ids
            for _,c in ipairs(refresh()) do
                pcall(function()
                    c=U.valid(c)
                    local key=c and key_of(c)
                    local run,wave,slot=W.decode(key)
                    if run==r.s.run and wave==k and slot<#ids and not r.seen[key] then track(c,key,k,slot) end
                end)
            end
            local n=0
            for slot=0,#ids-1 do
                local key=W.key(r.s.run,k,slot)
                if r.seen[key] then n=n+1
                elseif last then
                    r.input.done[#r.input.done+1]=key
                    log(string.format('missing %s %s',hex(key),W.POOL[ids[slot+1]].alias))
                end
            end
            log(string.format('wave %d find +%g s: tracked %d/%d',k,after,n,#ids))
        end
    end
    local function spawn_next()
        local q=table.remove(r.queue,1)
        if not q then return end
        local ids=W.SCHEDULE[q.k].ids
        local key,id=W.key(r.s.run,q.k,q.slot),ids[q.slot+1]
        local at,yaw=W.spot(r.p0,r.yaw,r.s.order[q.k],q.slot)
        local ok,e=pcall(function() Run.spawn(assert(N.controller(),'no SB player controller'),id,at,yaw,key) end)
        log(string.format('spawn %s %s at %s yaw %.0f%s',hex(key),W.POOL[id].alias,xyz(at),yaw,
            ok and '' or ' failed: '..why(e)))
        if q.slot==#ids-1 then
            for i,after in ipairs(FINDS) do r.timers.add(r.now+after,find(q.k,i==#FINDS,after)) end
        end
    end
    -- Every tracked body, once a tick: killed ones leave at once, before the game's remove-dead pass can free them.
    local function read()
        local keys={}
        for key in pairs(r.bodies) do keys[#keys+1]=key end
        table.sort(keys)
        for _,key in ipairs(keys) do
            local b=r.bodies[key]
            with(b,function(c)
                local killed,down=signals(c)
                if killed then return kill(b) end
                if down and not b.down then
                    b.down=true
                    r.input.done[#r.input.done+1]=key
                    log(string.format('down %s %s',hex(key),alias(b)))
                end
            end)
        end
    end
    -- The end: every handle dropped without a read, nothing more spawned, the result line.
    local function finish()
        local s=r.s
        r.bodies,r.queue,r.timers,r.live,r.screen={},{},W.timers(),{},nil
        local t=math.floor(s.time)
        log(string.format('result: %s%s waves=%d/%d kills=%d score=%d time=%d:%02d find_ms=%.1f/%.1f',s.outcome,
            s.reason and ' ('..s.reason..')' or '',s.clears,#W.SCHEDULE,s.kills,s.score,t//60,t%60,
            r.ms_n>0 and r.ms_sum/r.ms_n or 0,r.ms_max))
    end
    -- Together only: points for a success or a time up of a run of ours that went through its countdown (a guest's
    -- run whose first line from the host was past it gets none), credited by this game to its own wallet. No line
    -- carries points; the shop caps what a score gives. A credit that fails (no SteamID yet, a wallet not written, an
    -- error) is a notice too; the log says why.
    local function unpaid(text)
        log(text)
        if tell then tell(function(w) return w.night.unpaid end) end
    end
    local function earn()
        local s=r.s
        if s.outcome~='success' and s.outcome~='time' then return end
        if not r.counted then return log('no points: this run did not go through its countdown') end
        local got,total=shop.credit(s.score)
        if not got then return unpaid('no points: '..total) end
        if tell then tell(function(w) return w.night.earned:format(got,total) end) end
    end
    -- One tick of the run's states: the host's (solo or with her line as input.mate), or the guest's following his
    -- line (r.line, this tick's new one). A key she killed first scores nothing here.
    local function step(input)
        r.counted=r.counted or r.s.phase=='countdown'
        local before,fresh=r.s.score,{}
        for _,b in ipairs(r.killed) do fresh[b]=not r.s.killed[b.key] end
        local events=r.role=='guest' and W.follow(r.s,r.line,r.now,input) or W.step(r.s,input,r.now)
        r.counted=r.counted or r.s.phase=='countdown'
        for _,b in ipairs(r.killed) do
            if r.role=='guest' then log(string.format('kill %s %s',hex(b.key),alias(b)))
            else
                local p=fresh[b] and W.points(b.id) or 0
                before=before+p
                log(string.format('kill %s %s +%d = %d',hex(b.key),alias(b),p,before))
            end
        end
        r.killed={}
        for k=1,r.s.wave do
            if r.s.clear_at[k] and not r.told[k] then
                r.told[k]=true
                notify(function(w) return w.night.clear_notice:format(k) end)
            end
        end
        for _,e in ipairs(events) do
            if e.what=='wave' then
                local ids=W.SCHEDULE[e.wave].ids
                for slot=0,#ids-1 do r.queue[#r.queue+1]={k=e.wave,slot=slot} end
                log(string.format('wave %d/%d at run time %.1f s: %d monsters',e.wave,#W.SCHEDULE,r.now-r.s.t0,#ids))
                notify(function(w) return w.night.wave_notice:format(e.wave,#W.SCHEDULE) end)
            elseif e.what=='heal' then
                local ok,healed=pcall(N.heal)
                log(string.format('heal after wave %d: %s',e.wave,ok and healed and 'asked'
                    or 'not asked ('..(ok and 'the heal row is not a name in this game run' or why(healed))..')'))
            elseif e.what=='end' then
                finish()
                if shown() then panel={s=r.s,left=W.RESULT/TICK} else notify_end(r.s) end
                local paid,pe=pcall(earn) -- Its error must not keep the end from the partner.
                if not paid then pcall(unpaid,'STOP: points: '..why(pe)) end
            end
        end
    end
    -- Adapted from Survival Protocol's death watch: once a second, a death when the screen's animation starts. The
    -- screen is looked for again at most every 10 s while not found. A screen found playing is a death too (start
    -- throws its first look away).
    local function died()
        if not U.valid(r.screen) then
            if r.ticks<r.look_at then return false end
            r.look_at,r.playing=r.ticks+40,nil
            r.screen=U.death_screen()
            if not r.screen then return false end
        end
        local playing,was=r.screen:IsAnyAnimationPlaying()==true,r.playing
        r.playing=playing
        return playing and was~=true
    end
    -- The host's ask: her ready within ASK ticks starts the countdown; her refusal, or silence, drops the run with no
    -- result and a notice that says why. A run byte she found taken is skipped from then on.
    local function host_ask(eve,mode,line)
        r.asked=r.asked+1
        local name=friend() or '?'
        if line and line.state=='ready' then
            r.now=eve and clock(eve) or r.now
            r.s.t0,r.s.phase,r.quiet,r.mate=r.now+W.COUNTDOWN,'countdown',0,line
            log(string.format('%s is ready: run 0x%02X starts in %d s',name,r.s.run,W.COUNTDOWN))
            notify(function(w) return w.night.start_notice:format(W.COUNTDOWN) end)
            return
        end
        local why=line and line.state=='refuse' and line.why or (r.asked>=ASK or mode and mode~='host') and 'none'
        if not why then return end
        if why=='taken' then taken[r.s.run]=true end
        log(string.format('%s cannot join run 0x%02X: %s',name,r.s.run,why))
        r=nil
        if tell then tell(function(w) return w.night.refused:format(name,w.night.refuse[why]) end) end
    end
    -- The guest's ask: his countdown within ASK ticks starts her run (with a notice), else it is dropped.
    local function guest_ask(mode,line)
        if line and line.phase~='ask' then
            r.quiet=0
            local name=friend() or '?'
            local left=math.max(0,math.ceil(-line.rt/1000))
            log(string.format('%s started run 0x%02X: it begins in %d s',name,r.s.run,left))
            if tell then tell(function(w) return w.night.coop_notice:format(name,left) end) end
            return true
        end
        r.asked=r.asked+1
        if r.asked>=ASK or mode and mode~='guest' then
            log(string.format('run 0x%02X dropped: no countdown from the host',r.s.run))
            r=nil
        end
    end
    -- raw: the status text; mode: its link= word; fresh: her or his night line, new this tick, decoded (or nil).
    local function tick(raw,mode,fresh)
        r.ticks=r.ticks+1
        local eve=N.her()
        if r.s.phase=='result' then -- 10 s for the result, then idle; a new world ends it at once.
            if not eve then r=nil; return end
            r.now=clock(eve)
            if W.step(r.s,{},r.now)[1] then r=nil end
            return
        end
        -- A co-op run hears only its own run's lines; each one tells the partner is there.
        local line=r.role and fresh and fresh.run==r.s.run and (r.role=='host' or fresh.seed==r.seed) and fresh or nil
        if r.role then r.quiet=line and 0 or r.quiet+1 end
        if r.role=='host' and line then r.mate=line end
        if r.s.phase=='ask' then
            if r.role=='host' then return host_ask(eve,mode,line) end
            if not guest_ask(mode,line) then return end
        end
        -- Her run time: his, plus half the round trip (none before the first pong). His end line's rt is his final
        -- time, not a clock: it stays as it is.
        if r.role=='guest' and line and line.phase~='end' then
            local rtt=math.tointeger(tonumber(raw:match('\npeer=[^\r\n]* rtt_ms=(%-?%d+)') or '')) or 0
            line.rt=line.rt+math.max(0,rtt)//2
        end
        r.line=line
        if r.role=='guest' then -- For piloted(), as of this tick.
            if line then r.found=line.found end
            r.piloted=(raw:match('\n(fight=on[^\r\n]*)') or ''):find(' role=guest ',1,true)~=nil
                and raw:find('\npilot=on piloted=[1-9]')~=nil
        end
        local input={killed={},done={},mate=r.role=='host' and r.mate or nil}
        r.input,r.eve=input,eve
        -- The abort watch, every tick, paused or not. Adapted from Survival Protocol's arena exit (80 m for 10 s) and
        -- its map-load hygiene: a map change or a death drops every handle without a read. slot=none means no EVE
        -- (a load, the title): the gone rule decides. A new world on the same map restarts the game clock. A solo run
        -- ends when a Steam session starts; a co-op one when the session ends or the partner's line stops. A status not
        -- read (no link= word) ends nothing: the partner's line still has to come within QUIET ticks.
        local slot=raw:match('\nslot=(%a+)')
        local now
        if slot and slot~='coop' and slot~='none' then input.abort='slot'
        elseif not r.role and mode and mode~='none' then input.abort='link'
        elseif r.role and (mode and mode~=r.role or r.quiet>=QUIET) then input.abort='lost'
        elseif not eve then
            r.gone=r.gone+1
            if r.gone*TICK>=GONE_FOR then input.abort='map change' end
        else
            r.gone,now=0,clock(eve)
            if U.map_of(eve)~=r.map or now<r.now then input.abort='map change'
            else
                r.far=metres(location(eve),r.p0)>LEAVE and r.far+1 or 0
                if r.far*TICK>=LEAVE_FOR then input.abort='left' end
            end
        end
        if not input.abort and eve then
            if r.ticks%4==0 then
                local ok,dead=pcall(died)
                if ok then input.dead=dead else r.screen=nil end -- Looked for again.
            end
            r.now=now
        end
        if not (input.abort or input.dead) then
            if not eve or paused() then r.stale=true
            else
                if next(r.bodies) and (r.stale or r.now-r.live_at>=W.REFRESH) then refresh() end
                r.timers.drain(r.now)
                spawn_next()
                read()
            end
        end
        step(input)
    end
    local USE='Use: coop nightop [start [noaggro|nomove] | stop | shop | buy <n> [count]]'
    -- A new run at game time now around at (whole cm) facing yaw (whole degrees): the run byte and seed give the gate
    -- order, so the host's and the guest's runs put each monster on the same spot.
    local function begin(run,seed,now,at,yaw,map,flag)
        r={s=W.new{run=run,seed=seed,now=now},seed=seed,p0=at,yaw=yaw,map=map,noaggro=flag=='noaggro',
            nomove=flag=='nomove',timers=W.timers(),bodies={},seen={},queue={},killed={},live={},live_at=-math.huge,
            now=now,found={},ticks=0,gone=0,far=0,ms_n=0,ms_sum=0,ms_max=0,look_at=0,told={},asked=0,quiet=0}
        panel=nil
        pcall(died) -- The death screen's first look, while EVE lives.
    end
    local function start(flag)
        if r and r.s.phase~='result' then return false,'a run is on: coop nightop stop ends it' end
        local raw='\n'..(status() or '')
        local linked=raw:match('\nlink=(%a+)')
        if not linked then return false,'the Steam link is not ready yet: try again in a moment' end
        if linked=='guest' then return false,'the host starts a co-op run' end
        if linked=='host' and not raw:find('\nfriend=1 0 ',1,true) then
            return false,'no partner linked yet: a co-op run starts once they are'
        end
        -- The token goes with the probe's poller (capped at 4 MB); the rule's row stays in the table.
        local token=(raw:match('\nengine=[^\r\n]*') or ''):match(' nightop=(%a+)')
        local read,row=pcall(N.rule_row)
        if token=='rule' or (read and row) then
            return false,'a coop no probe rule is set in this game run: restart the game first'
        end
        local eve=N.her()
        if not eve then return false,'no EVE in the world' end
        if not N.controller() then return false,'no SB player controller' end
        local map=U.map_of(eve)
        if map==XION then return false,'not in Xion: its people and quests stay out of a fight' end
        local c=census(eve)
        if c.near>0 then return false,c.text..': go where no one is within '..CLEAR..' m' end
        local t=os.time()
        local skip={}
        for b in pairs(c.taken) do skip[b]=true end
        for b in pairs(taken) do skip[b]=true end
        local run=W.run_byte(skip,t)
        if not run then return false,c.text..': every run byte is taken, load another map first' end
        local now,v=clock(eve),location(eve)
        local at={X=math.floor(v.X+0.5),Y=math.floor(v.Y+0.5),Z=math.floor(v.Z+0.5)} -- As the night line carries it.
        local yaw=math.floor(U.value_of(eve:K2_GetActorRotation()).Yaw+0.5)
        begin(run,W.seed(t,run),now,at,yaw,map,flag)
        log(string.format('start: run 0x%02X seed 0x%08X at %s yaw %.0f map %s%s; %s',run,W.seed(t,run),xyz(at),yaw,
            map,flag and ' '..flag or '',c.text))
        if linked=='host' then
            local name=friend() or '?'
            r.role,r.s.role,r.s.phase='host','host','ask'
            log(string.format('co-op with %s: waiting for their answer',name))
            return true,string.format('Night Operation: waiting for %s to join (run 0x%02X)',name,run)
        end
        notify(function(w) return w.night.start_notice:format(W.COUNTDOWN) end)
        return true,string.format('Night Operation starts in %d s (run 0x%02X)',W.COUNTDOWN,run)
    end
    -- The guest's side of the host's ask, once per run byte and seed: her checks in order, the first that fails refuses
    -- with its word; else she is ready, and her run takes his run byte, seed, start point and yaw.
    local function join(h,raw)
        if answer and (h.run~=answer.run or h.seed~=answer.seed or h.phase~='ask') then answer=nil end
        if r and r.role=='guest' and r.s.phase=='ask' and (h.run~=r.s.run or h.seed~=r.seed) then
            log(string.format('run 0x%02X dropped: the host asks for another',r.s.run))
            r=nil
        end
        local id=h.run..' '..h.seed
        if h.phase~='ask' or answered[id] then return end
        answered[id]=true
        local eve,why,text=N.her(),nil,''
        if raw:match('\nslot=(%a+)')~='coop' then why='slot'
        elseif r and r.s.phase~='result' or paused() then why='busy' -- Paused: no body is read for the census.
        elseif not eve or not N.controller() or U.map_of(eve)~=h.map then why='map'
        elseif metres(location(eve),{X=h.x,Y=h.y,Z=h.z})>FAR then why='far'
        else
            local c=census(eve)
            why,text=c.near>0 and 'near' or c.taken[h.run] and 'taken' or nil,'; '..c.text
        end
        if why then
            answer={run=h.run,seed=h.seed,why=why,ticks=0}
            log(string.format('ask for run 0x%02X refused: %s%s',h.run,why,text))
            return
        end
        begin(h.run,h.seed,clock(eve),{X=h.x,Y=h.y,Z=h.z},h.yaw,h.map)
        r.role,r.s.role,r.s.phase='guest','guest','ask'
        log(string.format('join: run 0x%02X seed 0x%08X at %s yaw %d map %s%s',h.run,h.seed,xyz(r.p0),h.yaw,h.map,
            text))
    end
    -- The host's ask has no run yet: dropped, with no result. The guest's ask ends as an abort, so her line tells a
    -- host already counting down at once.
    local function stop(reason)
        if not r or r.s.phase=='result' then return false end
        if r.s.phase=='ask' and r.role=='host' then
            log(string.format('run 0x%02X dropped: %s',r.s.run,reason))
            r=nil
            return true
        end
        r.input,r.killed={killed={},done={}},{}
        step({killed={},done={},abort=reason})
        return true
    end
    -- Our side of the night line as W.encode_host's or W.encode_mate's table (n and rt left to night_out), or nil when
    -- we have none to send: the guest's refusal while she sends it (a host who asks has left any run of hers behind),
    -- else the host's run until it goes idle, the guest's too.
    local PHASE={ask='ask',countdown='count',wave='wave',breather='rest',result='end'}
    local function ours()
        if answer then return {run=answer.run,state='refuse',up=0,killed={},done={},why=answer.why} end
        if r and r.role=='host' then
            local s=r.s
            local reason=s.outcome=='aborted' and (WHY[s.reason] or 'stop') or s.reason
            local rt=s.phase=='ask' and -W.COUNTDOWN or s.phase=='result' and s.time or r.now-s.t0
            local found={} -- Found and not done here: a key he killed or wrote off goes back to her own rules.
            for key in pairs(r.seen) do if not s.done[key] then found[key]=true end end
            return {run=s.run,seed=r.seed,phase=PHASE[s.phase],wave=s.wave,rt=math.max(-10000,
                math.min(600000,math.floor(rt*1000+0.5))),score=s.score,kills=s.kills,clears=s.clears,found=found,
                x=r.p0.X,y=r.p0.Y,z=r.p0.Z,yaw=r.yaw,map=r.map,outcome=s.outcome,reason=reason}
        end
        if r and r.role=='guest' then
            local s=r.s
            local state,why='run',nil
            if s.phase=='ask' then state='ready'
            elseif s.outcome=='failed' and s.reason=='guest' then state='dead'
            elseif s.outcome=='aborted' and s.reason~='mate' then state,why='abort',WHY[s.reason] or 'stop' end
            return {run=s.run,state=state,up=s.up,killed=s.killed,done=s.done,why=why}
        end
    end
    -- The night line goes when what it says changes and at least once a second, never twice in a tick; n counts the
    -- lines, so the partner sees a new one even when nothing changed. [NR] logs each line out.
    local function night_out()
        local t=send and ours()
        if not t then out.key=nil; return end
        local encode=t.phase and W.encode_host or W.encode_mate
        local rt=t.rt
        t.n,t.rt=0,0
        local key=encode(t)
        out.ago=out.ago+1
        if key==out.key and out.ago<EVERY_LINE then return end
        out.n,out.key,out.ago=(out.n+1)%65536,key,0
        t.n,t.rt=out.n,rt
        local line=encode(t)
        local ok,e=send(line)
        log('night out: '..line..(ok==false and ' (not written: '..tostring(e)..')' or ''))
    end
    -- Her or his last night line from the status, decoded for our side, once when it is new; nil otherwise. [NR] logs
    -- each new one, and says when it is refused.
    local function hear(raw,mode)
        local text=raw:match('\nnight=([^\r\n]+)')
        if text==heard then return nil end
        heard=text
        if not text then return nil end
        local line=mode=='host' and W.decode_mate(text) or mode=='guest' and W.decode_host(text) or nil
        log('night in: '..text..(line and '' or ' (refused)'))
        return line
    end
    local self={}
    -- start [noaggro|nomove], stop, shop, buy <n> [count], or nothing: the run's state, if any, and the census.
    function self.command(sub,flag,extra,more)
        if sub=='buy' then return shop.buy(flag,extra,more) end
        if extra~=nil then return false,USE end
        if sub=='start' and (flag==nil or flag=='noaggro' or flag=='nomove') then return start(flag) end
        if flag~=nil then return false,USE end
        if sub=='stop' then
            if not stop('stop') then return false,'no Night Operation run to stop' end
            return true,'Night Operation stopped'
        end
        if sub=='shop' then return shop.list() end
        if sub~=nil then return false,USE end
        local eve=N.her()
        if not eve then return false,'no EVE in the world' end
        local text=census(eve).text
        if r and r.s.phase~='result' then
            local s=r.s
            text=string.format('run 0x%02X: %s, wave %d/%d, run time %.0f s, score %d, kills %d; %s',s.run,s.phase,
                s.wave,#W.SCHEDULE,r.now-s.t0,s.score,s.kills,text)
        end
        return true,text
    end
    -- The HUD each tick, after the run's: the card while a run is on, else the result panel until it was seen for its
    -- 10 s (a death screen, a pause or a load hide it meanwhile), both hidden while the game is paused or shows one of
    -- its screens, as the partner card. The words follow the game's language unless ui_language=english, picked again
    -- at each build of the kit's root; the panel reads the game's own heading once for those words.
    local picked,lang,words=nil,nil,nil
    local function draw()
        local kit=hud.kit
        if kit.off() then -- The notices say it, and the result the panel still held.
            if panel then notify_end(panel.s) end
            panel=nil
            return
        end
        local running=r~=nil and r.s.phase~='result'
        local away=(running or panel~=nil) and kit.paused()
        local card,res=kit.view('night'),kit.view('night_result')
        local result=panel~=nil and not running and not away and res~=nil
        kit.show('night',running and not away)
        kit.show('night_result',result)
        if not (card and (running and not away or result)) then return end
        if card~=picked or hud.settings.ui_language~=lang then
            picked,lang=card,hud.settings.ui_language
            words=T.pick(kit.language(),lang)
        end
        if running then
            local title,line=Run.card(r.s,r.now,words)
            card.title.set(title)
            card.line.set(line)
            return
        end
        if panel.words~=words then
            panel.words,panel.head,panel.sub,panel.rows=words,
                Run.result(panel.s,words,lang~='english' and game_text or no_text)
        end
        res.head.set(panel.head)
        res.head.color(panel.s.outcome=='success' and hud.theme.teal or hud.theme.warn)
        res.sub.set(panel.sub)
        for i,v in ipairs(panel.rows) do
            res.rows[i].label.set(v[1])
            res.rows[i].value.set(v[2])
        end
        panel.left=panel.left-1
        if panel.left<=0 then panel=nil end
    end
    -- Every 250 ms. First the partner's night line (a guest answers a host's ask here, run or not), then the run. A Lua
    -- error ends the run as aborted (error), with one STOP line and no retry; in the result's 10 s, it drops the run
    -- at once. Then our night line, and the HUD: an error in it gives one STOP line, and notices from then on (the
    -- result too, if the panel still held it).
    function self.tick()
        local got,text=pcall(status)
        local raw='\n'..(got and text or '')
        local mode=raw:match('\nlink=(%a+)')
        local fresh=nil
        local heard_ok,he=pcall(function()
            fresh=hear(raw,mode)
            if fresh and mode=='guest' then join(fresh,raw) end
            if answer then
                answer.ticks=answer.ticks+1
                if answer.ticks>ASK then answer=nil end
            end
        end)
        if not heard_ok then log('STOP: night line: '..why(he)) end
        if r then
            local ok,e=pcall(tick,raw,mode,fresh)
            if not ok and r then
                log('STOP: '..why(e))
                r.killed={} -- Kills of the failed tick are not counted: none is logged.
                local ended,e2=pcall(function()
                    if r.s.phase~='result' then step({killed={},done={},abort='error'}) else r=nil end
                end)
                if not ended then
                    log('STOP: '..why(e2))
                    r=nil
                end
            end
        end
        local sent,se=pcall(night_out)
        if not sent then log('STOP: night line: '..why(se)) end
        if not hud then return end
        local ok,e=pcall(draw)
        if not ok then
            log('STOP: HUD: '..why(e))
            pcall(function() hud.kit.show('night',false); hud.kit.show('night_result',false) end)
            hud=nil
            local p=panel
            panel=nil
            if p then pcall(notify_end,p.s) end -- The result the panel still held.
        end
    end
    -- The HUD's two groups on the Uplink kit, before its first build (main.lua, after the partner HUD): o is {kit,
    -- theme=ui.THEME, settings= (main.lua's, ui_language read at each update)}.
    function self.hud(o)
        hud=o
        local kit,theme=o.kit,o.theme
        local x=(3840-HUD_W)/2
        kit.add('night',{x=x,y=HUD_Y,w=HUD_W,h=CARD_H,pivot={X=0.5,Y=0}},function(b)
            b.panel(0,0,HUD_W,CARD_H)
            return {title=b.text(HUD_W/2,48,'','name',theme.warn,MIDDLE),
                line=b.text(HUD_W/2,104,'','item',theme.text,MIDDLE)}
        end)
        kit.add('night_result',{x=x,y=HUD_Y,w=HUD_W,h=RESULT_H,pivot={X=0.5,Y=0}},function(b)
            b.panel(0,0,HUD_W,RESULT_H)
            local v={head=b.text(HUD_W/2,70,'','title',theme.teal,MIDDLE),
                sub=b.text(HUD_W/2,136,'','body',theme.grey,MIDDLE),rows={}}
            for i=1,4 do
                local y=200+(i-1)*56
                v.rows[i]={label=b.text(96,y,'','body',theme.text,LEFT),
                    value=b.text(HUD_W-96,y,'','item',theme.text,RIGHT)}
            end
            return v
        end)
    end
    -- coop off (or any reason): the run ends as aborted.
    function self.stop(reason) return stop(reason or 'stop') end
    -- A run is under way (its result panel aside): the follow's travel waits for its end.
    function self.running() return r~=nil and r.s.phase~='result' end
    return self
end
return Run
