-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The score attack's copy of online/modes/nightop/run.lua (2026-11-20), with the heal of online/modes/nightop/probe.lua
-- and the in-place respawn of online/group/group.lua: scoreattack owns it; a fix here does not reach theirs. One
-- challenge run of a match round, on the game thread: EVE goes to the point the round gives her (her lobby spot,
-- facing the ring centre), then the run plays there on the round's seed, so every game draws the same spots. This file
-- is the game side: the start checks and the census, the one spawn call and the navmesh ground of its spots, the bodies
-- it tracks, their aggro and stuck moves, the heal after a wave, the abort watch and the end. A run that ends calls
-- o.ended once with its state; online/modes/scoreattack/game.lua sends the done line from it. A death ends the run as
-- failed and asks SB's in-place respawn at once, so EVE stays in the lobby room: every exit of the death screen takes
-- her out of the match (FACTS 8). online/modes/scoreattack/waves.lua holds the waves, the keys and the run's states.
-- The run has no rule row: its clock is game time and it ends itself. Dropped from the solo copy: the Xion refusal
-- (the lobby room is in Xion), every check of the Steam session (a match lobby is one), the co-op night line, the
-- down and its revive, the shop and its points, the cut shooting test's score widget, the console words and the HUD.
-- Never called here: a table row added, a rule or remain-time request, EndRule, ResetZone, a zone event other than the
-- heal, EnterZone, a collision or pool flag write, a destroy, a save, inventory, equip or quest call, RegisterHook,
-- NotifyOnNewObject. The three game requests, each read in Ghidra on build 26123051 (2026-11-20, T1 and T6), none of
-- which reaches SB's matchmaking: ServerRequest_CreateActor (FUN_1423bdd20, its log string at 0x145cd38f0) queues its
-- job on SB's local logic queue (FUN_141af4b70) and sends it only in the UE client net mode 3; the heal's
-- CreateSBZoneEvent of SE_10_E_ActorEff_011, kind 2 (ZoneEvent_AttachActorEffect, its name at 0x145e4e1b0), which
-- RunEvent (FUN_141ca5a10) hands to FUN_141c9e690 at 0x141ca627d; ServerRequest_ActorRespawn, whose job
-- (FSBActorRespawn::Simulate, FUN_141b10b30, its log string at 0x145c01c80) finds EVE by her GUID and refills her
-- recovery items where she lies, reading no zone type. tests/lua/online/modes/scoreattack/run_test.lua covers it.
-- Parts of this file adapt Survival Protocol by SchizoEffective (nexusmods.com/stellarblade/mods/4009), used with
-- permission given on 2026-10-20. SchizoEffective agreed on 2026-11-14 to the project's license change, and they are
-- licensed here under the SBO License 1.0 or any later version the Licensor publishes (NOTICE).
local U=require('core.unreal')
local N=require('core.player')
local W=require('online.modes.scoreattack.waves')
local C=require('online.modes.scoreattack.challenges')
local Run={}
local MASK=0xFFFFFFFF
local TICK=0.25 -- Seconds between two ticks (main.lua's loop). The abort watch counts ticks: game time stops in a load.
local CLEAR=40 -- Metres: no living character but EVE this close at the start.
local LEAVE,LEAVE_FOR,GONE_FOR=80,10,2 -- EVE farther than LEAVE m from the start for LEAVE_FOR s, or gone GONE_FOR s.
-- Seconds after a wave's last spawn call: its bodies are looked for; one not found by the last is missing.
local FINDS={1,2.5}
-- Metres on the ground from where a slot's spawn call stood it within which a new body is taken for it (W.match).
local MATCH=5
-- A spot's ground (W.settle): NavigationSystemV1's static calls, and how far from a point they look for the navmesh
-- (cm across, then up or down; TALL when EXTENT finds no floor).
local NAV='/Script/NavigationSystem.Default__NavigationSystemV1'
local EXTENT,TALL={X=100,Y=100,Z=500},{X=100,Y=100,Z=1500}
-- Metres: a character up before a wave that stands this far or more from where it stood then is one the game took back
-- from its pool for a spawn, so it can be new.
local REUSED=50
-- Seconds after a body is found: a controller if it has none; aggro, and again later.
local ADOPT,AGGRO,AGAIN=0.5,0.6,4
local STUCK,EVERY,BELOW,AWAY,NEAR=2.5,3,10,40,7 -- The stuck rule: seconds, then metres (its moves: the definition's).
local SLOW=5 -- ms: a live-list refresh this slow gets its own line.
-- The respawn after a death: seconds it is tried for, then seconds after the call before its result line.
local TRY,AFTER=10,2
local HIDDEN=2 -- ESlateVisibility Hidden.
-- The heal: its ZoneEventTable row (ID 2476, kind 2, FACTS 4) and the probe rule's table (a coop no rule set in this
-- game run spends a life at each respawn and may refuse it: no run then).
local HEAL='SE_10_E_ActorEff_011'
local TABLE,RULE='/Game/Local/Data/MultiPlayRuleTable.MultiPlayRuleTable','CoopProbeRule'
local metres=U.metres
local why=U.why
local function xyz(v) return string.format('%.0f,%.0f,%.0f',v.X,v.Y,v.Z) end
local function location(actor)
    local v=U.value_of(actor:K2_GetActorLocation())
    return {X=v.X,Y=v.Y,Z=v.Z}
end
local function hex(key) return string.format('0x%08X',key) end
local function alias(b) return W.POOL[b.id].alias end
local function find_name(text) return FName(text,EFindName.FNAME_Find) end -- None (index 0) when not a name yet.
-- The only zone event this file may fire: the heal.
function Run.allowed(kind,name) return kind==2 and name==HEAL end
local function zone_event(kind,name)
    assert(Run.allowed(kind,name),'zone event refused')
    U.find('/Script/SB.Default__SBBlueprintLibrary'):CreateSBZoneEvent(kind,find_name(name))
end
-- The heal: false, with nothing called, while its row is not a name in this game run.
function Run.heal()
    if U.value_of(find_name(HEAL)):GetComparisonIndex()==0 then return false end
    zone_event(2,HEAL)
    return true
end
-- BroadcastSpawnInfo.EventSpawnId, unsigned: SB fills it only in a networked game, so it reads 0 in ours. The run finds
-- its bodies by place. Only the census still reads it, for a key a body might carry.
local function key_of(c)
    local k=math.tointeger(c.BroadcastSpawnInfo.EventSpawnId)
    return k and k&MASK
end
-- InteractionState 0 or 1 stands (a body of our spawn reads 1 until its death reads 3).
local function standing(st) return st==0 or st==1 end
local function living(c) return c.InteractionState==0 and U.valid(c.Controller)~=nil end
local function up(c) return standing(c.InteractionState) and c.bCharacterHiddenInGame~=true end
-- Every SBCharacter in EVE's world, through the engine's class hash.
local function characters(eve) return (U.actors_of(U.find('/Script/SB.SBCharacter'),'SBCharacter',eve)) end
-- Killed: not standing with no controller. Down, for the wave check: not standing or hidden by the game (read only).
local function signals(c)
    local st=c.InteractionState
    local killed=not standing(st) and U.valid(c.Controller)==nil
    return killed,killed or not standing(st) or c.bCharacterHiddenInGame==true
end
-- The one spawn call: a pool row and a wave key, its low byte as the spawn index. cheat=true takes any CharacterTable
-- ID at any transform; not a player, player 0, no spawn point, no possess.
function Run.spawn(pc,id,at,yaw,key)
    assert(W.POOL[id],'not a pool row')
    assert(math.type(key)=='integer' and key>=0 and W.decode(key),'not a wave key')
    pc:ServerRequest_CreateActor(id,at,{Pitch=0,Yaw=yaw,Roll=0},false,true,0,key,key&0xFF,FName('None'),false)
end
-- A 0.01 damage event from EVE and a noise at her wake the body's perception; not in battle yet, it gets the game's
-- battle state, its controller's focus on EVE and a move towards her. Each step on its own; the text says which worked.
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
-- The stuck rule's move: K2_TeleportTo only, NEAR m from EVE on her line to the body, half a metre up, facing her.
-- Also whether the game refused the teleport.
local function move(c,e,l)
    local d=math.max(1,math.sqrt((l.X-e.X)^2+(l.Y-e.Y)^2))
    local to={X=e.X+(l.X-e.X)/d*NEAR*100,Y=e.Y+(l.Y-e.Y)/d*NEAR*100,Z=e.Z+50}
    return to,c:K2_TeleportTo(to,{Pitch=0,Yaw=U.yaw_to(to,e),Roll=0})==false
end
-- One list of the characters: the living ones but EVE within CLEAR m and the nearest of them, and every body that
-- carries a wave key (at most 8 named), with its run byte.
local function census(eve)
    local at,me,c=location(eve),U.address(eve),{near=0,keys={},taken={}}
    U.each(characters(eve),function(_,o)
        o=U.valid(o)
        if not o or U.address(o)==me then return end
        local ok,key=pcall(key_of,o)
        local run=ok and W.decode(key)
        if run then
            c.taken[run]=true
            c.keys[#c.keys+1]=key
        end
        local fine,alive=pcall(living,o)
        if fine and alive then
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
-- log(text) writes a line; status() is the native part's status text; paused() whether the game is paused or shows
-- one of its screens; life() core/link.lua's life ({state=, hp=}, or nil); ended(s) hears each run's end once, with
-- its waves state (def, outcome, reason, score, kills, time); records: {read() the text of coop-records.txt, nil when
-- there is none (it raises when the file cannot be read), write(text) true once written}, or nil for no bests.
function Run.new(o)
    local log,status,paused,records=o.log,o.status,o.paused,o.records
    local r=nil -- The run, nil when idle: s is online/modes/scoreattack/waves.lua's state.
    -- After a death: {ticks=, said=, call= the tick of the call, me=, before=}, until the respawn's result line.
    -- hidden: {widget=, was=} while we hide a death screen that still plays over a living EVE.
    local dead,hidden=nil,nil
    local ticks=0 -- Every tick, run or not: the respawn counts them.
    local screen,look_at=nil,0 -- The death screen for the respawn, looked for again at most every 10 s.
    local function clock(eve) return U.find('/Script/Engine.Default__GameplayStatics'):GetTimeSeconds(eve) end
    local function raw() return '\n'..(status() or '') end
    -- The live list: the addresses of the latest list of the characters in EVE's world, timed. Returns the characters.
    local function refresh()
        local t,set,list=os.clock(),{},{}
        for _,c in ipairs(characters(r.eve)) do
            local ok,a=pcall(U.address,c)
            if ok and a then set[a],list[#list+1]=true,c end
        end
        local ms=(os.clock()-t)*1000
        r.live,r.live_at,r.stale=set,r.now,false
        r.ms_n,r.ms_sum,r.ms_max=r.ms_n+1,r.ms_sum+ms,math.max(r.ms_max,ms)
        if ms>=SLOW then log(string.format('find: %.1f ms',ms)) end
        return list
    end
    -- A tracked body is read only while its address is in the live list, then through IsValid, with the name
    -- (comparison index) it was found with.
    local function touch(b)
        if not r.live[b.addr] then return nil,'not in the live list' end
        local c=U.valid(b.obj)
        if not c then return nil,'not valid' end
        if c:GetFName():GetComparisonIndex()~=b.name then return nil,'another object at its address' end
        return c
    end
    -- A body leaves tracking for good and its wave stops waiting for it. kill: it scores. leave: killed if it was seen
    -- down, else lost.
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
    -- A living body with no controller never moves; it gets its default.
    local function adopt(b)
        with(b,function(c)
            if not standing(c.InteractionState) or U.valid(c.Controller) then return end
            local ok=pcall(function() c:SpawnDefaultController() end)
            log(string.format('controller %s: SpawnDefaultController %s',hex(b.key),
                ok and U.valid(c.Controller) and 'gave one' or 'failed'))
        end)
    end
    local function push(b,again)
        with(b,function(c)
            if again and c:IsBattle()==true then return end
            log(string.format('aggro %s%s: %s',hex(b.key),again and ' again' or '',aggro(c,r.eve)))
        end)
    end
    -- Below the start point and EVE, or far from both: moved next to EVE, at most the definition's moves times and
    -- never twice within EVERY s; still out after that, written off for the wave check (a later kill still scores).
    -- With 0 moves, written off where it is.
    local function stuck(b)
        local moves=r.s.def.moves
        local function check(now)
            with(b,function(c)
                local _,down=signals(c)
                local l,e=location(c),location(r.eve)
                if not down and (l.Z<math.min(r.p0.Z,e.Z)-BELOW*100 or metres(l,r.p0)>AWAY and metres(l,e)>AWAY) then
                    if b.moves>=moves then
                        r.input.done[#r.input.done+1]=b.key
                        log(string.format('written off %s %s at %s after %d moves',hex(b.key),alias(b),xyz(l),b.moves))
                        return
                    end
                    b.moves=b.moves+1 -- A refused teleport counts too.
                    local to,refused=move(c,e,l)
                    log(string.format('%s %s %s from %s (%.1f m from the start) to %s (%d/%d)',
                        refused and 'move refused' or 'moved',hex(b.key),alias(b),xyz(l),metres(l,r.p0),xyz(to),b.moves,
                        moves))
                end
                r.timers.add(now+EVERY,check)
            end)
        end
        return check
    end
    -- A definition with aggro off (the target dummies) gets neither the default controller nor the aggro.
    local function track(c,key,k,slot)
        local b={key=key,id=r.s.def.waves[k].ids[slot+1],obj=c,addr=U.address(c),moves=0,
            name=c:GetFName():GetComparisonIndex()}
        r.bodies[key],r.seen[key]=b,true
        local t=r.now
        if r.s.def.aggro then
            r.timers.add(t+ADOPT,function() adopt(b) end)
            r.timers.add(t+AGGRO,function() push(b,false) end)
            r.timers.add(t+AGGRO+AGAIN,function() push(b,true) end)
        end
        r.timers.add(t+STUCK,stuck(b))
    end
    -- Where each character of a list that is up stands, by address.
    local function ups(list)
        local set={}
        for _,c in ipairs(list) do pcall(function() if up(c) then set[U.address(c)]=location(c) end end) end
        return set
    end
    -- Wave k's bodies by place: a character up now, not EVE, that no tracked body holds and that was not up within
    -- REUSED m of where it stands before the wave's first spawn call is a new body; each goes to the nearest slot not
    -- found yet within MATCH m of the slot's spot (W.match). At the last find, a slot never found is missing.
    local function find(k,last,after)
        return function()
            local ids,list=r.s.def.waves[k].ids,refresh()
            local slots,spots,fresh,held,taken,before,me={},{},{},{},{},r.before[k] or {},U.address(r.eve)
            for slot=0,#ids-1 do
                local key=W.key(r.s.run,k,slot)
                spots[slot]=r.at[key] or W.spot(r.p0,r.yaw,r.s.order[k],slot,r.s.def)
                if not r.seen[key] then slots[#slots+1]={key=key,slot=slot,at=spots[slot]} end
            end
            for _,b in pairs(r.bodies) do held[b.addr]=true end
            if #slots>0 then
                for _,c in ipairs(list) do
                    pcall(function()
                        local a=U.address(c)
                        if a==me or held[a] or not up(c) then return end
                        local at,was=location(c),before[a]
                        if was and math.sqrt((at.X-was.X)^2+(at.Y-was.Y)^2)<REUSED*100 then return end
                        fresh[#fresh+1]={obj=c,at=at}
                    end)
                end
                for _,p in ipairs(W.match(slots,fresh,MATCH*100)) do
                    local s=slots[p.slot]
                    taken[p.body]=true
                    local ok,e=pcall(track,fresh[p.body].obj,s.key,k,s.slot)
                    if not ok then log(string.format('find %s: %s',hex(s.key),why(e))) end
                end
            end
            local n=0
            for slot=0,#ids-1 do
                local key=W.key(r.s.run,k,slot)
                if r.seen[key] then n=n+1
                elseif last then
                    r.missing=true -- Its wave clears without it: no best for this run (finish).
                    r.input.done[#r.input.done+1]=key
                    local at,nearest=spots[slot],nil
                    for i,f in ipairs(fresh) do
                        local d=math.sqrt((f.at.X-at.X)^2+(f.at.Y-at.Y)^2)/100
                        if not taken[i] and (not nearest or d<nearest) then nearest=d end
                    end
                    log(string.format('missing %s %s (%s)',hex(key),W.POOL[ids[slot+1]].alias,
                        nearest and string.format('nearest new body %.1f m',nearest) or 'no new body'))
                end
            end
            log(string.format('wave %d find +%g s: tracked %d/%d',k,after,n,#ids))
        end
    end
    -- The navmesh calls W.settle asks for, in EVE's world.
    local function navmesh(lib)
        return {project=function(p,tall)
                local out={}
                return lib:K2_ProjectPointToNavigation(r.eve,p,out,nil,nil,tall and TALL or EXTENT)==true
                    and {X=out.X,Y=out.Y,Z=out.Z} or nil
            end,
            ray=function(a,b)
                local out={}
                return lib:NavigationRaycast(r.eve,a,b,out,nil,nil)==true,{X=out.X,Y=out.Y,Z=out.Z}
            end}
    end
    -- Where wave k's slot spawns, its yaw (facing the start) and the spawn line's note: its spot settled on the navmesh
    -- (W.settle). When that drops its gate (or spot), the slot goes to the next one that holds, first among those no
    -- slot of the wave stands at, then 2.5 m beside another's point. When none holds, the farthest point a dropped gate
    -- would have had, else its raw spot. With no navmesh calls, raw spots for the rest of the run, said once.
    local function place(k,slot)
        local def,order,ids=r.s.def,r.s.order[k],r.s.def.waves[k].ids
        local raw_at,yaw=W.spot(r.p0,r.yaw,order,slot,def)
        local function unchecked(e)
            r.nav=false
            return raw_at,yaw,' (ground: unchecked: '..e..')'
        end
        if r.nav==nil then
            local found,lib=pcall(U.find,NAV)
            if not found then return unchecked(why(lib)) end
            r.nav=navmesh(lib)
        end
        if not r.nav then return raw_at,yaw,'' end
        local n,word=def.spots and #def.spots or 4,def.spots and 'spot' or 'gate'
        local took=r.took[k] or {}
        r.took[k]=took
        local function index(q)
            local s=q
            while s<#ids or took[s] do s=s+n end
            return s
        end
        local tries={slot}
        for pass=1,2 do
            for i=1,n-1 do
                local q=(slot+i)%n
                local s=index(q)
                if (s==q)==(pass==1) then tries[#tries+1]=s end
            end
        end
        local first,near,far,from
        for i,s in ipairs(tries) do
            local spot=W.spot(r.p0,r.yaw,order,s,def)
            local fine,at,e,short=pcall(W.settle,r.p0,spot,r.nav)
            if not fine then return unchecked(why(at)) end
            if e=='no navmesh under the start' then return unchecked(e) end
            if at then
                took[s]=true
                local d=math.sqrt((at.X-spot.X)^2+(at.Y-spot.Y)^2)/100
                local note=i>1 and string.format(' (ground: %s %d %s, %s %d)',word,order[slot%n+1],first,word,
                    order[s%n+1]) or d>=1 and string.format(' (ground: moved %.1f m)',d) or ''
                return at,U.yaw_to(at,r.p0),note
            end
            first=first or e
            local m=short and math.sqrt((short.X-r.p0.X)^2+(short.Y-r.p0.Y)^2)/100
            if m and (not far or m>far) then near,far,from=short,m,s end
        end
        local note=string.format(' (ground: %s %d %s, no other %s holds: ',word,order[slot%n+1],first,word)
        if not near then return raw_at,yaw,note..'raw spot)' end
        took[from]=true
        return near,U.yaw_to(near,r.p0),note..string.format('%.1f m out)',far)
    end
    local function spawn_next()
        local q=table.remove(r.queue,1)
        if not q then return end
        if q.slot==0 then r.before[q.k]=ups(refresh()) end -- What stands before the wave, read before its first call.
        local ids=r.s.def.waves[q.k].ids
        local key,id=W.key(r.s.run,q.k,q.slot),ids[q.slot+1]
        local at,yaw,note=place(q.k,q.slot)
        r.at[key]=at -- Where find looks for its body.
        local ok,e=pcall(function() Run.spawn(assert(N.controller(),'no SB player controller'),id,at,yaw,key) end)
        log(string.format('spawn %s %s at %s yaw %.0f%s%s',hex(key),W.POOL[id].alias,xyz(at),yaw,note,
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
    -- The records file's text: nil when there is none (or no records), false when reading it failed (logged).
    local function stored()
        if not records then return nil end
        local ok,text=pcall(records.read)
        if ok then return text end
        log('record: cannot read coop-records.txt ('..why(text)..')')
        return false
    end
    -- After a success: the records file read again and, when this run beats its best match run, rewritten. r.best is
    -- then the best the file holds, with new=true when this run wrote it. A read or a write that fails is logged.
    local function keep(s)
        local text=stored()
        r.best=nil
        if text==false then return end
        local score,secs=C.best(text,s.def.id)
        r.best=score and {score=score,s=secs} or nil
        if not C.better(score,secs,s.score,s.time) then return end
        local new,e=C.write(text,s.def.id,s.score,s.time)
        if new then
            local ok,wrote=pcall(records.write,new)
            e=not ok and wrote or wrote~=true and 'the write failed' or nil
        end
        if e then return log('record: cannot write coop-records.txt ('..why(e)..')') end
        r.best={score=math.floor(s.score),s=math.floor(s.time),new=true}
    end
    -- The end: every handle dropped without a read, nothing more spawned, a better success's best kept, the result
    -- line, then o.ended. A success keeps no best with a monster that never came or with no kill.
    local function finish()
        local s=r.s
        r.bodies,r.queue,r.timers,r.live,r.screen={},{},W.timers(),{},nil
        if s.outcome=='success' and records then
            local no=r.missing and 'a monster never came' or s.kills==0 and 'no kill'
            if no then log('record: not kept ('..no..')') else keep(s) end
        end
        local t=math.floor(s.time)
        log(string.format('result: %s%s waves=%d/%d kills=%d score=%d time=%d:%02d find_ms=%.1f/%.1f challenge=%s '
            ..'best=%s',s.outcome,s.reason and ' ('..s.reason..')' or '',s.clears,#s.def.waves,s.kills,s.score,t//60,
            t%60,r.ms_n>0 and r.ms_sum/r.ms_n or 0,r.ms_max,s.def.id,
            r.best and string.format('%d/%d %s',r.best.score,r.best.s,r.best.new and 'new' or 'kept') or 'none'))
        if s.outcome=='failed' then dead={ticks=0} end -- The respawn, from the next tick.
        local ok,e=pcall(o.ended,s)
        if not ok then log('STOP: end: '..why(e)) end
    end
    -- One tick of the run's states.
    local function step(input)
        local before=r.s.score
        local events=W.step(r.s,input,r.now)
        for _,b in ipairs(r.killed) do
            local p=W.points(b.id)
            before=before+p
            log(string.format('kill %s %s +%d = %d',hex(b.key),alias(b),p,before))
        end
        r.killed={}
        for _,e in ipairs(events) do
            if e.what=='wave' then
                local ids=r.s.def.waves[e.wave].ids
                for slot=0,#ids-1 do r.queue[#r.queue+1]={k=e.wave,slot=slot} end
                log(string.format('wave %d/%d at run time %.1f s: %d monsters',e.wave,#r.s.def.waves,r.now-r.s.t0,
                    #ids))
            elseif e.what=='heal' then
                local ok,healed=pcall(Run.heal)
                log(string.format('heal after wave %d: %s',e.wave,ok and healed and 'asked'
                    or 'not asked ('..(ok and 'the heal row is not a name in this game run' or why(healed))..')'))
            elseif e.what=='end' then
                finish()
            end
        end
    end
    -- Once a second, a death when the death screen's animation starts. The screen is looked for again at most every
    -- 10 s while not found. A screen found playing is a death too (start throws its first look away).
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
    local function tick(text)
        r.ticks=r.ticks+1
        local eve=N.her()
        if r.s.phase=='result' then -- 10 s for the result, then idle; a new world ends it at once.
            if not eve then r=nil; return end
            r.now=clock(eve)
            if W.step(r.s,{},r.now)[1] then r=nil end
            return
        end
        local input={killed={},done={}}
        r.input,r.eve=input,eve
        -- The abort watch, every tick, paused or not: a map change or a death drops every handle without a read.
        -- slot=none means no EVE (a load, the title): the gone rule decides. A new world on the same map restarts the
        -- game clock.
        local slot=text:match('\nslot=(%a+)')
        local now
        if slot and slot~='coop' and slot~='none' then input.abort='slot'
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
                local ok,d=pcall(died)
                if ok then input.dead=d else r.screen=nil end -- Looked for again.
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
    -- The death screen we hid comes back as it was.
    local function show(reason)
        local h=hidden
        hidden=nil
        if U.valid(h.widget) then h.widget:SetVisibility(h.was) end
        log('respawn: death screen shown again ('..reason..')')
    end
    local function death_screen()
        if not U.valid(screen) then
            if ticks<look_at then return nil end
            look_at=ticks+40
            screen=U.death_screen()
        end
        return screen
    end
    local function playing()
        local s=death_screen()
        return s~=nil and s:IsAnyAnimationPlaying()==true
    end
    -- Why the respawn waits, or nil, our EVE's GUID and the controller: online/group/group.lua's checks for its probe
    -- (life 3 to 5, no respawn or warp in flight, no probe rule, a standalone game, EVE, the death screen playing).
    local function blocker()
        local life=o.life()
        if not life then return 'no life read' end
        if life.state<3 or life.state>5 then return 'life '..life.state end
        local line=raw():match('\nengine=([^\r\n]*)') or ''
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
        return nil,tonumber(me),pc
    end
    local function snapshot()
        local life,s,eve=o.life(),death_screen(),N.her()
        return {life=life and life.state or '?',hp=life and life.hp or '?',
            screen=s and (s:IsAnyAnimationPlaying()==true and 'up' or 'off') or 'gone',pawn=eve and U.address(eve)}
    end
    -- After a death: SB's in-place respawn of our EVE, once, as soon as every check holds, tried for TRY s (each
    -- reason logged once). AFTER s after the call, one result line, and the death screen hidden while it still plays
    -- over a living EVE.
    local function respawn()
        dead.ticks=dead.ticks+1
        if not dead.call then
            if hidden then show('a new death') end
            local reason,me,pc=blocker()
            if reason then
                if reason~=dead.said then
                    dead.said=reason
                    log('respawn waits: '..reason)
                end
                if dead.ticks*TICK>=TRY then
                    log(string.format('respawn not asked in %d s: %s',TRY,reason))
                    dead=nil
                end
                return
            end
            dead.call,dead.me,dead.before=dead.ticks,me,snapshot()
            local b=dead.before
            log(string.format('respawn: ServerRequest_ActorRespawn(%d, false) asked (life %s, hp %s, death screen %s)',
                me,b.life,b.hp,b.screen))
            pc:ServerRequest_ActorRespawn(me,false)
            return
        end
        if (dead.ticks-dead.call)*TICK<AFTER then return end
        local a,b=snapshot(),dead.before
        local screen_now=a.screen
        if (a.life==1 or a.life==6) and a.screen=='up' then
            local s=death_screen()
            hidden={widget=s,was=s:GetVisibility()}
            s:SetVisibility(HIDDEN)
            screen_now='hidden'
        end
        log(string.format('respawn result: life %s/%s, hp %s/%s, death screen %s/%s, EVE pawn %s',b.life,a.life,b.hp,
            a.hp,b.screen,screen_now,not a.pawn and 'gone' or a.pawn==b.pawn and 'same' or 'new'))
        dead=nil
    end
    -- A new run of def at game time now around at facing yaw, on the round's seed (the spot orders come from it).
    local function begin(run,seed,now,at,yaw,map,def)
        r={s=W.new{run=run,seed=seed,now=now,def=def},seed=seed,p0=at,yaw=yaw,map=map,timers=W.timers(),bodies={},
            seen={},queue={},killed={},live={},before={},at={},took={},live_at=-math.huge,now=now,ticks=0,gone=0,far=0,
            ms_n=0,ms_sum=0,ms_max=0,look_at=0}
        local score,secs=C.best(stored(),def.id)
        r.best=score and {score=score,s=secs} or nil
        pcall(died) -- The death screen's first look, while EVE lives.
    end
    local self={}
    -- A run of def on seed, EVE first moved to at (whole cm or not) facing yaw: true, or false and why not. Refused
    -- while a run is on, while a death's respawn is under way, with a coop no probe rule, with no EVE or controller,
    -- when the game refuses the teleport, with a living character within CLEAR m of the point, or every run byte taken.
    function self.start(def,seed,at,yaw)
        if r and r.s.phase~='result' then return false,'a run is on' end
        if dead then return false,'your EVE is down' end
        local text=raw()
        local token=(text:match('\nengine=[^\r\n]*') or ''):match(' nightop=(%a+)')
        local looked,row=pcall(function() return U.find(TABLE):FindRow(RULE)~=nil end)
        if token=='rule' or (looked and row) then return false,'a coop no probe rule is set in this game run' end
        local eve=N.her()
        if not eve then return false,'no EVE in the world' end
        if not N.controller() then return false,'no SB player controller' end
        if eve:K2_TeleportTo({X=at.X,Y=at.Y,Z=at.Z},{Pitch=0,Yaw=yaw,Roll=0})==false then
            return false,'the game refused the teleport to '..xyz(at)
        end
        local c=census(eve)
        if c.near>0 then return false,c.text end
        local t=os.time()
        local run=W.run_byte(c.taken,t)
        if not run then return false,c.text..': every run byte is taken' end
        local map=U.map_of(eve)
        local p0={X=at.X,Y=at.Y,Z=at.Z}
        begin(run,seed,clock(eve),p0,yaw,map,def)
        log(string.format('start: run 0x%02X seed 0x%08X at %s yaw %.0f map %s challenge %s; %s',run,seed,xyz(p0),yaw,
            map,def.id,c.text))
        return true
    end
    -- Every 250 ms: the run, then a death's respawn. A Lua error ends the run as aborted (error), with one STOP line;
    -- in the result's 10 s, it drops the run at once. An error in the respawn drops it with one STOP line.
    function self.tick()
        ticks=ticks+1
        if r then
            local ok,e=pcall(tick,raw())
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
        if dead then
            local ok,e=pcall(respawn)
            if not ok then
                log('STOP: respawn: '..why(e))
                dead=nil
            end
        end
    end
    -- Ends the run that is on as aborted for reason; true when one was on. coop off also drops a respawn not asked
    -- yet and shows a death screen we hid.
    function self.stop(reason)
        if reason=='coop off' then
            dead=nil
            if hidden then show('coop off') end
        end
        if not r or r.s.phase=='result' then return false end
        r.input,r.killed={killed={},done={}},{}
        step({killed={},done={},abort=reason})
        return true
    end
    -- The run's waves state (its definition, phase, wave, score, t0) and game time as of its last tick, or nil.
    function self.state()
        if not r then return nil end
        return r.s,r.now
    end
    -- A run is under way (its result aside).
    function self.running() return r~=nil and r.s.phase~='result' end
    return self
end
return Run
