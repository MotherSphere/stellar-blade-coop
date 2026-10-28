-- A cut monster spawned as a real enemy to fight, on the game thread: the flow coop lion (cut/lion.lua), coop gardener
-- fight (cut/gardener.lua) and coop tendril fight (cut/tendril.lua) share, each giving its own spec (coop mxiii,
-- cut/mxiii.lua, uses its rows part only, as do the Night Operation shop's cut items, its Shock Bolt and its screen,
-- through cut/lion.lua). The monster's rows
-- are a batch of the native part (lion/rows.h, glue/tick/lion_game.inc: SB's own AddRow on the game thread with no
-- logic task in flight). This file finds the 20 tables by their fixed paths and sends their addresses (the spec's
-- "<word> rows" request: no console word reaches an address), waits for the answer in coop-status.txt's <word> line,
-- then reads every row of the batch back through FindRow by field name, independent of the SDK's offsets, and stops at
-- the first value that differs, then runs the spec's prepare (the Tendril's Shows). Then one spawn call,
-- nightop/run.lua's ServerRequest_CreateActor with cheat on and key 0 (no EventSpawn row: no zone storage, no quest
-- event, no respawn, nothing saved), the spec's distance ahead of EVE and height, facing her, for one of the spec's
-- CharacterTable IDs only. Its body is the new character nearest the spot (of the spec's blueprint class), or a body SB
-- sent far away and moved back there (it reuses one: a Lion at 466 m came back for the next spawn on 2026-10-23), given
-- its default controller when it has none, its mesh turned by the spec's yaw when it has one (turned again, and said,
-- if the game turns it back) and given the spec's material on every slot when it has one, then followed: a line a
-- second while it lives (distance, place, the anim graph's speed, a skill running, the custom anim alphas the AnimBP
-- blends a Show's clip by, how far a hand moved in the body's own frame, with its mesh's engine switches before the
-- first line and at each change), its death (InteractionState not 0 with no controller, killed below) and its body's
-- despawn, with the spawn manager's counter (the line's spawns=) before, while it lives and after. While one lives,
-- once a second, the boss bar's name where it reads <row name> (no text of the monster in CharacterStringTable) set to
-- the spec's (the TextBlock SB writes once a boss bind, through FText::FromStringTable on the row's Name;
-- FindAllOf('TextBlock') walks every object, so the live blocks found are kept and looked for again at most every
-- BOSS_LOOK s while none is held). Nothing looks its Shows or clips up: a StaticFindObject of one took about 30 ms
-- here, a 50 ms frame each second (the frame rate check of 2026-10-24). Never called here: UE4SS's AddRow or RemoveRow
-- (a raw RowMap insert or free that SB's ID maps miss), a despawn, a save, quest or inventory call. The monster goes
-- when it dies or with the map; the rows stay for the game run, and a later command only reads them back. coop off ends
-- what this file does (a wait, a search, the lines) and leaves a living monster to the game. The entrance: a
-- single-node clip on the real mesh would replace the anim instance SB plays its skills on while its AI runs, so the
-- spawn comes at once, or, with intro, after the spec's entrance clip played on a display copy (race/doro.lua's plain
-- actor with the spec's mesh, as cut/leviathan.lua shows its meshes); the monster then spawns where the copy's root
-- ended and the copy goes as soon as the body shows. A map change during the entrance spawns nothing.
--
-- spec: word (the status line's, the request's and the follow lines' word: lion, gardener, tendril), name (its
-- messages: Lion), command (its console words: coop lion), tag (its log tag: [LI]), rows (its batch, as Enemy.rows
-- gives them), ids ({[id]=row name}: the only IDs the spawn call takes), class (its body's blueprint class), ahead(id)
-- (cm ahead of EVE), up (cm above her middle, or above her feet with feet true), mesh_yaw (degrees the body's mesh
-- turns once found; nil: none), material (a material's object path set on every slot of the body's mesh once found;
-- nil: none), boss ({shown, name}: a Lua pattern of the boss bar's text and the name written over it; nil: none),
-- entrance ({mesh, clip, scale, yaw (degrees the copy turns from facing EVE), seconds (when the clip's length is
-- unread)}; nil: none), skipped (why the entrance is off, for its log line), and optional hooks: prepare() (once the
-- rows read back, before the spawn or the end of a rows-only command; its error stops the spawn), follow(f, c, mesh)
-- (once a second before the follow line, the mesh line said), frame(f) (each frame for each followed body) and alive
-- ({name, run(now)}: once a second while a spawned body lives, timed in the frame part).
local U=require('core.unreal')
local N=require('nightop.probe')
local Doro=require('race.doro')
local valid,value_of,text=U.valid,U.value_of,U.text
local Enemy={}
-- The 20 tables, in the native part's order (link/protocol.h's kLionTables), each at /Game/Local/Data/<T>.<T>.
Enemy.TABLES={'CharacterTable','CharacterAppearanceTable','CharacterDeadTable','CharacterStanceTable',
    'CharacterAnimSetTable','SkillCommandTable','SkillTable','SkillActiveStepTable','CharacterMoveTable',
    'TargetFilterTable','SkillResultTable','EffectTable','ItemTable','ItemConsumableTable','ProjectileTable',
    'ZoneCampTable','ZoneEnvSpawnTable','ShopTable','ShopItemTable','ZoneTriggerTable'}
local DATA='/Game/Local/Data/'
local ROOT_FAR=2000 -- cm: the copy's root ending farther from the spot than this spawns at the spot.
local POLL,WAIT=0.25,30 -- s: the status line read while the rows are asked, and how long before giving up.
local FINDS={0.3,1,2,3.5,5} -- s after the call: the body looked for (bodies(): a few tries only).
local NEAR=30 -- m: a new body farther than this from the spot is not the one spawned.
-- s after the call: a body still without a controller gets its default one (run.lua's adopt comes 0.5 s after a find
-- at 1 s at the earliest), so the game's own controller has time to come first.
local ADOPT=1.5
local FOLLOW,GONE=1,60 -- s: a line a second while it lives; a body still there this long after its death is let go.
-- m: a body that stood farther than this from the spot at the call and stands within NEAR of it after is one SB moved
-- back for this spawn (no enemy runs the difference in 5 s).
local FAR=100
local MASK=0xFFFFFFFF
-- The bone whose place in the body's own frame the follow line compares from one second to the next: a frozen pose
-- keeps it still while the body runs and attacks (the in-game test of 2026-10-24: frame 1 of its idle, alphas 0). The
-- Lion's and the Gardener's skeletons both have it.
local BONE='Bip001-L-Hand'
-- The boss bar's name: the TextBlock SB writes once a boss bind (FUN_141e4c3f0), the live ones (under
-- /Engine/Transient, not a widget class's template), and how often (s) the blocks are looked for again while none is
-- held.
local BOSS_TEXT,BOSS_LOOK,LIVE='TextBlock_BossName',10,'/Engine/Transient'
local MATERIAL='/Script/Engine.MaterialInterface'

function Enemy.why(e) return (tostring(e):gsub('^.-:%d+: ','')) end -- Without the file and line.
local why=Enemy.why
-- The generated rows (cut/lion_rows.lua's R.ROWS or R.GARDENER, {table, name, ID, checks}) as {table=, name=, id=
-- <nil in the dead table>, checks={{field, kind, value, changed}}}. kind: f a float, i an int32, b a bool (0 or 1), e
-- an enum's number, n an FName (compared in any case: its text is whichever casing the game registered first), N a
-- list of FNames, s an FString, S a list of FStrings (lists joined by |). changed: the value differs from the row's
-- template (the shipped row the native part copies before its patches), so reading it back proves the patch landed;
-- the other checks restate a value the template holds, and a read-back cannot tell them from the copy.
function Enemy.rows(list)
    local rows={}
    for _,r in ipairs(list) do rows[#rows+1]={table=r[1],name=r[2],id=r[3],checks=r[4]} end
    return rows
end
-- The status line's counts once every row of rows is in: added=, and SB's lookups by ID (char=, skills=, stance=).
function Enemy.counts(rows)
    local function count(t)
        local n=0
        for _,r in ipairs(rows) do if r.table==t or not t then n=n+1 end end
        return n..'/'..n
    end
    return {added=count(),char=count('CharacterTable'),skills=count('SkillTable'),stance=count('CharacterStanceTable')}
end
-- A batch's line (glue's rows_status) as fields: state (off, waiting, rows, refused, fault), asks (a number), spawns (a
-- number, nil while '?'), and the others as written (added, char, skills, stance, why, table, row, detail; where, the
-- rest of the line). nil without one: no native part, or one older than the batch.
function Enemy.parse(status,word)
    local line=('\n'..(status or '')):match('\n'..word..'=([^\r\n]*)')
    if not line then return nil end
    local s={state=line:match('^(%a+)'),line=word..'='..line}
    for k,v in line:gmatch(' (%a+)=(%S+)') do s[k]=v end
    s.where=line:match(' where=(.*)$')
    s.asks,s.spawns=tonumber(s.asks) or 0,tonumber(s.spawns)
    return s
end
-- A field of a row as compared: a number (a bool as 0 or 1), or text (an FName lower-cased), a list joined by |. Raises
-- when unread.
local function get(r,field,kind)
    local x=value_of(r[field])
    if kind=='b' and type(x)=='boolean' then return x and 1 or 0 end
    if kind=='f' or kind=='i' or kind=='e' or kind=='b' then return assert(tonumber(x),'not a number') end
    if kind=='n' then return text(x):lower() end
    if kind=='s' then return text(x) end
    local items={}
    U.each(assert(x,'no field'),function(_,v) items[#items+1]=text(v) end)
    local joined=table.concat(items,'|')
    return kind=='N' and joined:lower() or joined
end
local function same_value(kind,got,want)
    if kind=='f' then return math.abs(got-want)<1e-4 end
    -- An int32 or uint32 by its 32 bits: an ID above 2^31 (coop mxiii's 2800032900) reads the same signed or not.
    if kind=='i' then return math.tointeger(got)~=nil and math.tointeger(got)&MASK==want&MASK end
    return got==((kind=='n' or kind=='N') and want:lower() or want)
end
-- R4: every row of rows read back through its table's FindRow (tables: by name, as found), its ID then its checks, in
-- order. Returns the count that match and, at the first that does not, what it reads; with every row matching, also
-- the fields read and how many of them differ from the template. ponytail: about 3000 field reads in one frame, once a
-- coop lion; a read-back spread over frames if that hitch shows in game.
local function read_back(rows,tables)
    local fields,changed=0,0
    for n,r in ipairs(rows) do
        local found=tables[r.table]:FindRow(r.name)
        if found==nil then return n-1,r.name..' is not in '..r.table end
        local checks={table.unpack(r.checks)}
        if r.id then table.insert(checks,1,{'ID','i',r.id}) end
        for _,c in ipairs(checks) do
            local ok,got=pcall(get,found,c[1],c[2])
            if not ok then return n-1,string.format('%s %s unread (%s)',r.name,c[1],why(got)) end
            if not same_value(c[2],got,c[3]) then
                return n-1,string.format('%s %s reads "%s", not "%s"',r.name,c[1],tostring(got),tostring(c[3]))
            end
        end
        fields=fields+#r.checks
        for _,c in ipairs(r.checks) do changed=changed+(c[4] and 1 or 0) end
    end
    return #rows,nil,fields,changed
end

local function xyz(v) return string.format('%.0f,%.0f,%.0f',v.X,v.Y,v.Z) end
local function metres(a,b) return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)/100 end
local function location(actor) local v=value_of(actor:K2_GetActorLocation()); return {X=v.X,Y=v.Y,Z=v.Z} end
local function class_of(o) return text(o:GetFullName()):match('^%S+') end
local function path_of(o) return text(o:GetFullName()):match('^%S+ (.+)$') end
local function key_of(c) -- BroadcastSpawnInfo.EventSpawnId, which the spawn sets from the call's key; unsigned.
    local k=math.tointeger(c.BroadcastSpawnInfo.EventSpawnId)
    return k and k&MASK
end
-- Killed: InteractionState not 0 with no controller; a dying body loses its controller at once. A key-0 body reads 1
-- from its first second (how-it-works.md), so this rule and the adopt at 0 below hold only while the game gives it a
-- controller at spawn, as it did on 2026-10-23.
local function killed(c) return c.InteractionState~=0 and valid(c.Controller)==nil end

-- o: log (the spec's tag lines), ask(line) the native request (ok, message), status() the native status text.
function Enemy.new(o,spec)
    local log,ask,status=o.log,o.ask,o.status
    local self={}
    local word,name,command,tag=spec.word,spec.name,spec.command,spec.tag
    local IN=Enemy.counts(spec.rows)
    local job=nil -- The command under way: {what=<for a busy refusal>, step=f(job, now), at=<os.clock when due>, ...}.
    local followed={} -- The bodies spawned this Lua load and not let go: {n=, id=, obj=, path=, since=, before=, ...}.
    local spawned,next_follow=0,0
    -- The frame time while a command runs or a body lives (UGameplayStatics' world delta, read each frame), and what
    -- this file's tick costs (os.clock is wall time in the game's CRT), its longest tick, and what the last
    -- once-a-second pass took by part (parts): the follow line's frame part, and the spawn's before line to compare
    -- with. gs: the GameplayStatics default object; ctx: its world context (EVE).
    local perf,gs,ctx={frames=0,sum=0,worst=0,lua=0,tick=0},nil,nil
    local parts='none yet'
    local function perf_take() -- The frame part since the last take, then the counters back to 0.
        local said=(perf.frames>0 and string.format('frame %.1f ms (worst %.1f), ',perf.sum/perf.frames*1000,
            perf.worst*1000) or 'frame ? ms, ')..string.format('%s Lua %.1f ms/s, longest tick %.1f ms (last pass: %s)',
            word,perf.lua,perf.tick,parts)
        perf.frames,perf.sum,perf.worst,perf.lua,perf.tick=0,0,0,0,0
        return said
    end
    local frame_said=string.format('frame ? ms, %s Lua 0.0 ms/s',word) -- The last second's, for each follow line.
    local failed={} -- The boss name's and the alive hook's last errors, each said once.
    local boss,next_boss={},0 -- The boss name TextBlocks held, and when to look for them again.
    local function my_line() return Enemy.parse(status and status(),word) end
    local her=N.her
    -- The 20 tables by name, and those missing.
    local function tables()
        local found,missing,words={},{},{}
        for _,t in ipairs(Enemy.TABLES) do
            local dt=valid(StaticFindObject(DATA..t..'.'..t))
            if dt and dt:IsA(U.find('/Script/Engine.DataTable')) then
                found[t]=dt
                words[#words+1]=string.format('%s=0x%x',t,U.address(dt))
            else missing[#missing+1]=t end
        end
        return found,missing,words
    end
    -- The one spawn call: an ID of the spec's only; cheat on (any CharacterTable ID at any transform), not a player,
    -- player 0, key 0 and spawn index 0 (EventSpawnId 0, as SB's own summons), no spawn point, no possess.
    local function create(id,at,yaw)
        assert(spec.ids[id],'not a '..name..' ID')
        local pc=assert(N.controller(),'no SB player controller')
        pc:ServerRequest_CreateActor(id,at,{Pitch=0,Yaw=yaw,Roll=0},false,true,0,0,0,FName('None'),false)
    end
    -- The objects of class (a Blueprint class's short name, or SBCharacter) but EVE, by address: the SBCharacters of
    -- EVE's world from the engine's class hash (core/unreal.lua's actors_of), of that class by its full name's first
    -- word; FindAllOf(class) where the hash is not proven (it walks every object, 25 to 80 ms in game).
    local function bodies(class)
        local eve=her()
        local list,me={},eve and U.address(eve)
        local found,route=U.actors_of(U.find('/Script/SB.SBCharacter'),class,eve)
        local exact=route=='class hash' and class~='SBCharacter'
        for _,c in ipairs(found) do
            local ok,a=pcall(function()
                if exact and U.text(c:GetFullName()):match('^%S+')~=class then return nil end
                return U.address(c)
            end)
            if ok and a and a~=me then list[a]=c end
        end
        return list
    end
    local function spawn_count() local s=my_line(); return s and s.spawns end
    local function counted(n) return n and tostring(n) or '?' end
    -- A followed body's end: D1 (its death, then its despawn or why it was let go) and D2 (the spawn manager's counter
    -- before the spawn, when the body was found and now).
    local function let_go(f,said)
        for k,g in ipairs(followed) do
            if g==f then
                table.remove(followed,k)
                break
            end
        end
        log(said)
        log(string.format('%s %d spawn count: before %s, alive %s, %s %s',word,f.n,counted(f.before),counted(f.alive),
            f.dead and 'after death' or 'after',counted(spawn_count())))
    end
    -- The body's mesh, as the engine ticks it: what could keep its pose still while its logic runs. A field that
    -- cannot be read is a ?.
    local function named(x) local a=valid(x); return a and text(a:GetFName()) or 'none' end
    function self.mesh_state(c)
        local m=valid(c.Mesh)
        if not m then return 'no mesh' end
        local function read(get_it)
            local fine,v=pcall(get_it)
            if not fine then return '?' end
            v=value_of(v)
            return v==nil and '?' or tostring(v)
        end
        return string.format('anim instance %s, anim class %s, its skeleton %s, mesh skeleton %s, mode %s, '
            ..'leader %s, anim set sync %s, mesh %s, tick %s, pause %s, rate %s, '
            ..'no skeleton update %s, visibility tick %s, rate optimizations %s, actor dilation %s, '
            ..'sequencer anim mode %s',
            read(function() local a=valid(m:GetAnimInstance()); return a and class_of(a) or 'none' end),
            read(function() local a=valid(m.AnimClass); return a and text(a:GetFName()) or 'none' end),
            read(function() return named(valid(m.AnimClass).TargetSkeleton) end),
            read(function() return named(valid(m.SkeletalMesh).Skeleton) end),
            read(function() return m:GetAnimationMode() end),
            read(function() local l=valid(U.weak(m.MasterPoseComponent)); return l and path_of(l) or 'none' end),
            read(function() return c.bInitAnimSetSyncData end),
            read(function() local a=valid(m.SkeletalMesh); return a and text(a:GetFName()) or 'none' end),
            read(function() return m:IsComponentTickEnabled() end),read(function() return m.bPauseAnims end),
            read(function() return m.GlobalAnimRateScale end),read(function() return m.bNoSkeletonUpdate end),
            read(function() return m.VisibilityBasedAnimTickOption end),
            read(function() return m.bEnableUpdateRateOptimizations end),
            read(function() return c.CustomTimeDilation end),read(function() return c.bSequencerAnimMode end))
    end
    local mesh_state=self.mesh_state
    -- While a body lives, once a second: the boss bar's name as the spec's where it reads its pattern (SB writes it
    -- again at its next boss bind, and this puts it back).
    local function boss_name(now)
        local held=false
        for _,t in ipairs(boss) do held=held or valid(t)~=nil end
        if not held and now>=next_boss then
            next_boss,boss=now+BOSS_LOOK,{}
            U.each(FindAllOf('TextBlock') or {},function(_,t)
                t=valid(t)
                if t and text(t:GetFName())==BOSS_TEXT and text(t:GetFullName()):find(LIVE,1,true) then
                    boss[#boss+1]=t
                end
            end)
        end
        for _,t in ipairs(boss) do
            local shown=valid(t) and text(t:GetText())
            if shown and shown:find(spec.boss.shown) then
                t:SetText(FText(spec.boss.name))
                log(string.format('boss name: %s -> %s',shown,spec.boss.name))
            end
        end
    end
    -- The spec's material on every slot of a body's mesh: how many slots.
    local function paint(c)
        local m=valid(c.Mesh)
        local material=assert(Doro.resolve(spec.material,MATERIAL),spec.material:match('[^/]+$')..' does not load')
        local n=math.floor(tonumber(value_of(m:GetNumMaterials())) or 0)
        for i=0,n-1 do m:SetMaterial(i,material) end
        return n
    end
    -- The spec's mesh yaw on a body (its mesh's relative rotation, a turn about its root): what it read before.
    local function turn(c)
        local m=valid(c.Mesh)
        local fine,was=pcall(function() return value_of(m.RelativeRotation).Yaw end)
        m:K2_SetRelativeRotation({Pitch=0,Yaw=spec.mesh_yaw,Roll=0},false,{},false)
        return fine and tonumber(was) and string.format('%.0f',was) or '?'
    end
    -- BONE in the body's own frame (cm, yaw only): it moves when the mesh plays anything, and not when its actor moves.
    local function hand(c)
        local p=value_of(valid(c.Mesh):GetSocketLocation(FName(BONE)))
        local at,yaw=location(c),math.rad(value_of(c:K2_GetActorRotation()).Yaw)
        local x,y=p.X-at.X,p.Y-at.Y
        return {X=x*math.cos(yaw)+y*math.sin(yaw),Y=y*math.cos(yaw)-x*math.sin(yaw),Z=p.Z-at.Z}
    end
    local function follow_one(f,now)
        local ok,c=pcall(Doro.same,f.obj,f.path)
        local said=string.format('%s %d (%d)',word,f.n,f.id)
        if not (ok and c) then
            if f.dead then
                return let_go(f,string.format('%s dead after %.0f s (InteractionState %s, no controller); body gone '
                    ..'after %.1f s',said,f.dead-f.since,tostring(f.state),now-f.dead))
            end
            return let_go(f,string.format('%s gone while alive after %.0f s (a map change, or the game removed it)',
                said,now-f.since))
        end
        if not f.dead and killed(c) then f.dead,f.state=now,c.InteractionState end
        if f.dead then
            if now-f.dead<GONE then return end
            return let_go(f,string.format('%s dead after %.0f s (InteractionState %s, no controller); body still there '
                ..'after %d s, no longer followed',said,f.dead-f.since,tostring(f.state),GONE))
        end
        local eve=her()
        local read,battle=pcall(function() return c:IsBattle()==true end)
        local function num(fmt,read_it) -- A number read off the body, or ? when the call fails.
            local fine,v=pcall(read_it)
            v=fine and tonumber(value_of(v))
            return v and string.format(fmt,v) or '?'
        end
        local skill_read,skill=pcall(function() return c:IsRunningSkill()==true end)
        local at_read,at=pcall(function() return xyz(location(c)) end)
        local state=mesh_state(c)
        if state~=f.mesh then log(string.format('%s mesh: %s',said,state)) end
        f.mesh=state
        -- The game turning the mesh back: turned again, said each time (270 reads as -90 turned once round).
        if spec.mesh_yaw and f.turned then
            local fine,yaw=pcall(function() return tonumber(value_of(valid(c.Mesh).RelativeRotation).Yaw) end)
            local off=fine and yaw and (yaw-spec.mesh_yaw)%360
            if off and off>1 and off<359 then
                local turned,e=pcall(turn,c)
                log(string.format('%s: mesh yaw %.0f, not %d (the game turned it back): %s',said,yaw,spec.mesh_yaw,
                    turned and 'set again' or 'not set again ('..why(e)..')'))
            end
        end
        if spec.follow then spec.follow(f,c,state) end
        local hand_read,p=pcall(hand,c)
        local moved=hand_read and f.hand and string.format('%.0f cm',metres(p,f.hand)*100) or '?'
        f.hand=hand_read and p or nil
        log(string.format('%s: %s m, xyz %s, speed %s, skill %s, anim alpha %s/%s, hand moved %s, battle %s, state %s, '
            ..'controller %s, spawn count %s, %s',said,
            eve and string.format('%.1f',metres(location(c),location(eve))) or '?',
            at_read and at or '?',num('%.0f',function() return c:GetSBSpeedForAnimGraph() end),
            skill_read and (skill and 'yes' or 'no') or '?',
            num('%.2f',function() return c:GetCurrentCustomAnimAlpha(0) end),
            num('%.2f',function() return c:GetCurrentCustomAnimAlpha(1) end),moved,read and (battle and 1 or 0) or '?',
            tostring(c.InteractionState),valid(c.Controller) and 'yes' or 'no',counted(spawn_count()),frame_said))
    end
    -- A spawn's search (job.id, job.spot, job.before, job.class, job.display): at each of FINDS, the new body nearest
    -- the spot. Seen: the entrance copy removed at once, so the two never stand together. Found with no controller
    -- before ADOPT: looked at again then. Found: its default controller when it has none, S1 (with when it was first
    -- seen), its mesh turned (S3), the entrance line, followed from then on.
    local function search(j,now)
        local best,best_m,best_a=nil,nil,nil
        for a,c in pairs(bodies(j.class)) do
            if not j.taken[a] or j.taken[a]>FAR then
                local ok,d=pcall(function() return metres(location(c),j.spot) end)
                if ok and d<=NEAR and (not best_m or d<best_m) then best,best_m,best_a=c,d,a end
            end
        end
        local after=now-j.called
        j.seen=best and (j.seen or after)
        if best and j.display then
            pcall(Doro.remove,j.display)
            j.display=nil
        end
        if best and best.InteractionState==0 and not valid(best.Controller) and after<ADOPT then
            j.at=j.called+ADOPT
            return
        end
        if not best then
            j.tries=j.tries+1
            if j.tries<#FINDS then
                j.at=j.called+FINDS[j.tries+1]
                return
            end
            if j.display then pcall(Doro.remove,j.display) end
            log(string.format('spawn %d: CreateActor returned; no body after %g s',j.id,FINDS[#FINDS]))
            return false,string.format('%s %d: the spawn call returned but no body showed in %g s (%s lines in '
                ..'UE4SS.log).',spec.ids[j.id],j.id,FINDS[#FINDS],tag)
        end
        local adopted=''
        if best.InteractionState==0 and not valid(best.Controller) then
            local ok=pcall(function() best:SpawnDefaultController() end)
            adopted=ok and valid(best.Controller) and ' (SpawnDefaultController gave it)'
                or ' (SpawnDefaultController failed)'
        end
        local ctl=valid(best.Controller)
        local read,key=pcall(key_of,best)
        local eve=her()
        local from=eve and metres(location(best),location(eve))
        local reused=j.taken[best_a] and string.format('; a body SB reused (%.0f m from the spot at the call)',
            j.taken[best_a]) or ''
        for _,f in ipairs(j.taken[best_a] and {table.unpack(followed)} or {}) do
            if f.address==best_a then
                let_go(f,string.format('%s %d (%d) recycled: SB moved its body back for this spawn',word,f.n,f.id))
            end
        end
        log('before the spawn: '..perf_take()) -- While the command ran, the monster not there yet: to compare with.
        log(string.format('spawn %d: CreateActor returned; body %s %s m from EVE, %.1f m from the spot, after %.1f s; '
            ..'controller %s%s; EventSpawnId %s%s',j.id,class_of(best),from and string.format('%.1f',from) or '?',
            best_m,j.seen,ctl and class_of(ctl) or 'none',adopted,read and tostring(key) or '?',reused))
        spawned=spawned+1
        local f={n=spawned,id=j.id,obj=best,path=path_of(best),address=best_a,since=now,before=j.before,
            alive=spawn_count(),control=j.control}
        if spec.mesh_yaw and not j.control then
            local turned,was=pcall(turn,best)
            f.turned=turned or nil
            log(string.format('%s %d: mesh yaw set to %d (was %s)',word,f.n,spec.mesh_yaw,turned and was or '?')..
                (turned and '' or ': the call failed ('..why(was)..')'))
        end
        if spec.material and not j.control then
            local painted,n=pcall(paint,best)
            log(string.format('%s %d: %s',word,f.n,painted and string.format('material %s on its %d slots',
                spec.material:match('[^.]+$'),n) or 'material not set ('..why(n)..')'))
        end
        if not j.intro and not j.control then log('entrance: skipped ('..spec.skipped..')') end
        followed[#followed+1]=f
        if not followed[2] then next_follow=now+FOLLOW end -- Its first line a second from now.
        return true,string.format('%s %d is here, %s m from EVE: %s %d in the %s lines.',spec.ids[j.id],j.id,
            from and string.format('%.1f',from) or '?',word,spawned,tag)
    end
    -- The spawn call at at, facing EVE, then the search; raises with nothing called when there is no EVE or controller.
    local function spawn(j,at,now)
        local eve=assert(her(),'no EVE in the world')
        j.spot,j.class=at,j.control and 'SBCharacter' or spec.class
        j.taken={} -- The bodies there before the call, each with its distance to the spot (m; 0 when unread).
        for a,c in pairs(bodies(j.class)) do
            local ok,d=pcall(function() return metres(location(c),at) end)
            j.taken[a]=ok and d or 0
        end
        j.before=spawn_count()
        local yaw=U.yaw_to(at,location(eve))
        create(j.id,at,yaw)
        j.called,j.tries,j.at,j.step=now,0,now+FINDS[1],search
        j.what='the search for its body'
        log(string.format('spawn %d (%s) at %s, %.1f m from EVE, yaw %.1f; spawn count %s',j.id,spec.ids[j.id],
            xyz(at),metres(at,location(eve)),yaw,counted(j.before)))
    end
    -- The spot ahead(id) of EVE along her facing, up above her middle (or her feet); and where her feet are (her
    -- mesh's root).
    local function spot(id)
        local eve=assert(her(),'no EVE in the world')
        local at,yaw=location(eve),math.rad(value_of(eve:K2_GetActorRotation()).Yaw)
        local feet=value_of(valid(eve.Mesh):K2_GetComponentLocation())
        local ahead=spec.ahead(id)
        return {X=at.X+ahead*math.cos(yaw),Y=at.Y+ahead*math.sin(yaw),Z=(spec.feet and feet.Z or at.Z)+spec.up},feet.Z
    end
    local clip_name=spec.entrance and spec.entrance.clip:match('%.([%w_]+)$')
    -- The entrance's end: the monster spawned where the copy's root is now (its bone 0, on the spot's height), or at
    -- the spot when that is unread or more than ROOT_FAR away; the copy stays on its last frame until the body shows.
    -- A map change meanwhile: no spawn (the spot is the old map's).
    local function intro_done(j,now)
        local eve=her()
        if not eve or U.map_of(eve)~=j.map then
            pcall(Doro.remove,j.display)
            log('entrance: the map changed during it: no spawn')
            return false,'The map changed during the '..name..'\'s entrance: no spawn.'
        end
        local ok,p=pcall(function()
            return value_of(j.display.mesh:GetSocketLocation(j.display.mesh:GetBoneName(0)))
        end)
        local at,said=j.spot,'its root unread ('..why(p)..')'
        if ok and type(p)=='table' and tonumber(p.X) and tonumber(p.Y) then
            local d=math.sqrt((p.X-j.spot.X)^2+(p.Y-j.spot.Y)^2)/100
            said=string.format('its root ended %.1f m from the spot',d)
            if d*100<=ROOT_FAR then at={X=p.X,Y=p.Y,Z=j.spot.Z} else said=said..', too far' end
        end
        log(string.format('entrance: played on a display copy for %.1f s; %s: the %s spawns %s',now-j.played,said,
            name,at==j.spot and 'at the spot' or 'there'))
        spawn(j,at,now)
    end
    -- The display copy at the spot, on EVE's feet, facing her (turned by the entrance's yaw), playing the clip once;
    -- then intro_done when it ends. Any failure: the copy gone, the entrance skipped, the monster spawned at once.
    local function intro(j,now,feet)
        local e=spec.entrance
        local made,d=pcall(function()
            local eve=her()
            local at={X=j.spot.X,Y=j.spot.Y,Z=feet}
            local d=Doro.spawn(eve:GetWorld(),at,{Pitch=0,Yaw=U.yaw_to(at,location(eve))+e.yaw,Roll=0},{path=e.mesh})
            local fine,err=pcall(function()
                d.mesh:SetRelativeScale3D({X=e.scale,Y=e.scale,Z=e.scale})
                Doro.apply(d,{asset=e.clip,loop=false,rate=1,at=0})
            end)
            if not fine then
                pcall(Doro.remove,d)
                error(err,0)
            end
            return d
        end)
        if not made then
            log('entrance: skipped ('..why(d)..')')
            return spawn(j,j.spot,now)
        end
        local length=tonumber(select(2,pcall(function() return value_of(Doro.resolve(e.clip).SequenceLength) end)))
        length=length and length>0 and length or e.seconds
        -- ponytail: the copy is in no file, so a Lua reload during its entrance leaves it until the map changes; a
        -- coop-lion.txt swept at the next load (as coop-leviathan.txt) if that shows up.
        j.display,j.played,j.at,j.step,j.what=d,now,now+length,intro_done,'the entrance'
        log(string.format('entrance: playing %s (%.1f s) on a display copy at %s',clip_name,length,
            xyz({X=j.spot.X,Y=j.spot.Y,Z=feet})))
    end
    -- Once the rows are in (s: the batch's line): the read-back (R4), then the spawn (or the entrance first); a
    -- rows-only job ends there. Returns ok, message when the job ends; nil once the spawn is under way.
    local function rows_in(j,s,now)
        for _,k in ipairs({'added','char','skills','stance'}) do
            if s[k]~=IN[k] then
                return false,string.format('The %s rows are not all usable: %s (%s=%s, %s expected): no spawn.',
                    name,s.line,k,tostring(s[k]),IN[k])
            end
        end
        local n,wrong,fields,changed=read_back(spec.rows,j.tables)
        if wrong then
            log(string.format('rows read back through FindRow: %s (%d/%d match before it): no spawn',wrong,n,
                #spec.rows))
            return false,'A '..name..' row reads back wrong ('..wrong..'): no spawn.'
        end
        log(string.format('rows read back through FindRow: %d/%d authored rows, %d fields as written (%d differ from '
            ..'the template row)',n,#spec.rows,fields,changed))
        if spec.prepare then
            local ready,e=pcall(spec.prepare)
            if not ready then
                log('not ready: '..why(e)..': no spawn')
                return false,string.format('The %s rows are in, but %s: no spawn.',name,why(e))
            end
        end
        if j.rows_only then
            return true,string.format('%s rows in: %s added, SB finds them by ID (char %s, skills %s, stance %s) and '
                ..'they read back as written; %s spawns one.',name,s.added,s.char,s.skills,s.stance,command)
        end
        local ok,e=pcall(function()
            local at,feet=spot(j.id)
            j.spot=at
            if j.intro then intro(j,now,feet) else spawn(j,at,now) end
        end)
        if not ok then return false,'No spawn: '..why(e) end
    end
    -- The wait for the native part's answer: the rows in, a refusal finished after the ask (asks grown), or a fault with
    -- or without asks grown (the latch holds for the game run and turns every batch not in to fault, also one whose ask
    -- the game thread never took; start() asks only while the line reads no fault). A waiting line goes on waiting
    -- even with asks grown: an earlier ask finished, then the game thread took ours. A job asked at the title has no
    -- map to keep: a save loaded meanwhile changes nothing for rows only.
    local function wait(j,now)
        local eve=her()
        if j.map and (not eve or U.map_of(eve)~=j.map) then
            return false,'The map changed while the '..name..' rows were asked: no spawn.'
        end
        local s=my_line()
        if s and (s.state=='rows' or s.state=='fault' or s.asks>j.asks and s.state=='refused') then
            log('rows answer: '..s.line)
            if s.state=='rows' then return rows_in(j,s,now) end
            if s.state=='fault' then
                return false,'The '..name..' rows stopped on a fault ('..tostring(s.where)..').'
            end
            return false,string.format('The native part refused the %s rows (why=%s, table=%s, row=%s): '
                ..'coop-link.log says why; asking again skips the rows already in.',name,tostring(s.why),
                tostring(s.table),tostring(s.row))
        end
        if now-j.asked>=WAIT then
            return false,string.format('No answer on the %s rows in %d s (%s): coop-link.log says why.',name,WAIT,
                s and s.line or 'no '..word..' line')
        end
        if s and s.state=='waiting' and not j.said then
            j.said=true
            log('rows wait for the game thread: '..s.line)
        end
        j.at=now+POLL
    end
    -- What a second command while one runs gets, or nil when none runs.
    function self.busy()
        return job and command..' is busy ('..job.what..'): try again in a few seconds' or nil
    end
    -- A spawn of id (or, with rows_only, the rows only; intro: the entrance first): the tables (R1), then the rows
    -- already in (R5) or asked. title (rows only): asked at the title, so with no EVE and no map to keep. Returns ok,
    -- message; the job goes on in tick() when it waits.
    function self.start(id,intro_wanted,rows_only,title)
        local eve=her()
        if not eve and not title then return false,'no EVE in the world (load a save first): nothing was asked' end
        local found,missing,words=tables()
        if #missing>0 then
            log(string.format('tables: %d/%d found, missing %s: nothing asked',#words,#Enemy.TABLES,
                table.concat(missing,', ')))
            return false,'The game has no '..table.concat(missing,', ')..' loaded: nothing was asked.'
        end
        log(string.format('tables: %d/%d found: %s',#words,#Enemy.TABLES,table.concat(words,' ')))
        local s=my_line()
        if not s then
            return false,'coop-status.txt has no '..word..' line: the native part is off, or older than '..command
                ..' (coop-link.log): nothing was asked'
        end
        if s.state=='fault' then
            return false,'The '..name..' rows stopped on a fault this game run ('..tostring(s.where)..').'
        end
        local now=os.clock()
        local j={id=id,intro=intro_wanted,rows_only=rows_only,tables=found,map=not title and U.map_of(eve) or nil}
        if s.state=='rows' then
            log(string.format('rows already in (%s; SB\'s lookups by ID: char %s, skills %s, stance %s): not added '
                ..'again',tostring(s.added),tostring(s.char),tostring(s.skills),tostring(s.stance)))
            local ok,message=rows_in(j,s,now)
            if ok~=nil then return ok,message end
            job=j
            return true,string.format('%s %d asked: %s lines follow.',spec.ids[j.id],j.id,tag)
        end
        local asked,said=ask(word..' rows '..table.concat(words,' '))
        if not asked then return false,name..' rows not asked: '..tostring(said) end
        j.asks,j.asked,j.at,j.step,j.what=s.asks,now,now+POLL,wait,'the wait for the '..name..' rows'
        job=j
        log(string.format('rows asked of the native part (%s): its answer is the next asks= past %d',s.line,s.asks))
        return true,name..' rows asked of the native part: the '..(rows_only and 'read-back' or 'spawn')
            ..' follows once they are in ('..tag..' lines).'
    end
    -- A spawn of id through the same call and search with no rows asked (coop lion control's shipped Naytiba, found
    -- among every SB character): ok, message.
    function self.control(id)
        local ok,e=pcall(function()
            local j={id=id,control=true}
            spawn(j,(spot(id)),os.clock())
            job=j
        end)
        if not ok then return false,'No spawn: '..why(e) end
        return true,string.format('%s %d asked: %s lines follow.',spec.ids[id],id,tag)
    end
    -- The rows only, for another file's own use of them (the Night Operation shop's cut items, nightop/shop.lua): the
    -- rows-only steps (the tables, the rows already in or the ask, the wait, the read-back), then done(ok, message)
    -- with how they ended; what done returns is the end said. Returns done's ok, message when it ends at once, or ok,
    -- message, true while it waits: done then follows from tick() (not after coop off, which drops the wait). title:
    -- start()'s (cut/mxiii.lua's batch at the title).
    function self.rows(done,id,title)
        if job then return done(false,self.busy()) end
        local ok,message=self.start(id,false,true,title)
        if job and ok then
            job.done=done
            return ok,message,true
        end
        return done(ok,message)
    end
    -- The bodies followed, for the spec's own commands (coop lion unfreeze).
    function self.followed() return followed end
    -- Each frame, on the game thread: the job's step when due (ok, message when it ends, also on its first error), the
    -- spec's frame hook on each followed body, and each followed body once a second.
    function self.tick()
        local now=os.clock()
        local ok,message
        if job or followed[1] then
            local fine,dt=pcall(function()
                if not valid(ctx) then ctx=her() end
                gs=gs or valid(StaticFindObject('/Script/Engine.Default__GameplayStatics'))
                return tonumber(value_of(gs:GetWorldDeltaSeconds(ctx)))
            end)
            if fine and dt then perf.frames,perf.sum,perf.worst=perf.frames+1,perf.sum+dt,math.max(perf.worst,dt) end
        end
        if job and now>=job.at then
            local j=job
            local ran,done,said=pcall(j.step,j,now)
            if not ran then
                if j.display then pcall(Doro.remove,j.display) end
                ok,message=false,command..' stopped on an error: '..why(done)
            elseif done~=nil then ok,message=done,said end
            if ok~=nil and job==j then job=nil end
            if ok~=nil and j.done then -- The rows' caller says the end.
                local fine,a,b=pcall(j.done,ok,message)
                if fine then ok,message=a,b else ok,message=false,'after the '..name..' rows: '..why(a) end
            end
        end
        if spec.frame then
            for _,f in ipairs(followed) do spec.frame(f) end
        end
        if followed[1] and now>=next_follow then
            next_follow=now+FOLLOW
            frame_said=perf_take()
            local took={}
            local t=os.clock()
            for _,f in ipairs({table.unpack(followed)}) do
                local fine,e=pcall(follow_one,f,now)
                if not fine then let_go(f,string.format('%s %d no longer followed: %s',word,f.n,why(e))) end
            end
            took[1]=string.format('follow %.1f ms',(os.clock()-t)*1000)
            local lives=false
            for _,f in ipairs(followed) do lives=lives or (not f.control and not f.dead) end
            -- The boss name, then the spec's own pass, each timed and its error said once.
            for _,part in ipairs({spec.boss and {name='boss name',run=boss_name,key='boss'} or false,
                spec.alive and {name=spec.alive.name,run=spec.alive.run,key='alive'} or false}) do
                if lives and part then
                    t=os.clock()
                    local fine,e=pcall(part.run,now)
                    took[#took+1]=string.format('%s %.1f ms',part.name,(os.clock()-t)*1000)
                    e=not fine and string.format('%s: unread (%s)',part.name,why(e))
                    if e and e~=failed[part.key] then log(e) end
                    failed[part.key]=e
                end
            end
            parts=table.concat(took,', ')
        end
        local spent=(os.clock()-now)*1000
        perf.lua,perf.tick=perf.lua+spent,math.max(perf.tick,spent)
        return ok,message
    end
    -- coop off: the job ended (an entrance copy removed), the bodies no longer followed. A living monster stays: it is
    -- the game's enemy now, and nothing here despawns one.
    function self.stop()
        if job and job.display then pcall(Doro.remove,job.display) end
        local said=job and 'coop off: '..job.what..' ended' or nil
        job=nil
        if followed[1] then
            said=(said and said..'; ' or 'coop off: ')..#followed..' '..name..' bodies no longer followed (they stay)'
        end
        followed={}
        if said then log(said) end
    end
    return self
end
return Enemy
