-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The SBO lobby (sbo_lobby, on by default): the PvP lobby in Xion's own world. The recruiter's Join warps EVE there as
-- SB's type-5 zone Zone_Xion_Boss_Mann, where the hidden training room is the waiting room: eight spots and a fence.
-- Its data and pure rules, with no engine call: where the lobby is, the spots, the fence, the table rows edited for a
-- session and put back, the native part's end words as notice keys, and the checks before the entry. Then Sbo.new,
-- the entry, the return, the waiting room at each arrival, the arena hop from the native part's sbo line, the menu
-- camera at the Agit and the view and sequence tools, through an engine adapter. Units are cm and degrees.
-- With the hall lobby pak zSBO_Lobby (core/pak_gate.lua finds it) and its maps' rows in (lobby/halls_rows.lua), the
-- lobby is one of the five hall lobbies of lobby/sbo_maps.lua instead, drawn at random at each entry; without them it
-- stays in Xion, with one log line saying why. Which lobby EVE stands in always comes from the client zone. A match
-- lobby names its lobby and the pak's version (link.room(), link.hall()): a guest warps to it, or leaves a lobby on a
-- map she lacks. The host of a Private match picks its lobby (or a draw) and warps there before it is created.
-- In a hall, each seat with a row gets SB's own chair blueprint at each arrival (Sbo.CHAIRS), its meshes hidden, bound
-- to the seat's ZoneEnvSpawnTable row (lobby/halls_rows.lua): SB shows its Rest prompt and seats EVE itself. A seat
-- whose chair did not bind, and a camp seat (no row), keeps the mod's sit on menu_key with its sit loop
-- (cut/eve/emote.lua): her collision off and her movement held while she sits, so no table or volume over the seat
-- point pushes her off, and up at the seat's approach point with both back. Another member's EVE never holds a seat.
local U=require('core.unreal')
local PakGate=require('core.pak_gate')
local Maps=require('lobby.sbo_maps')
local Sbo={}
Sbo.OFF='the SBO lobby is off in coop-settings.txt (sbo_lobby=off)'
-- Xion's lobby: world row, zone, start point, the room actor and its region, the ring centre, the spots' Z (SB's arrow
-- plus 50 cm, so EVE drops onto the floor), the fence and the menu camera at the Agit. sequence: none yet.
Sbo.LOBBY={world='Xion',zone='Zone_Xion_Boss_Mann',point='Xion_Boss_Mann',room='BP_TrainningRoom_Common_C',
    region='TrainningRoom_Common',centre={X=-64028.5,Y=151213.6},spot_z=-15800.4,
    fence={radius=3000,zmin=-16100,zmax=-14700},camera={X=-13413,Y=18383,Z=250,Pitch=-5,Yaw=175},sequence=nil}
-- Eight spots on a circle of 8 m around the ring centre, each facing it.
Sbo.SPOTS={{X=-63228.5,Y=151213.6,Yaw=180},{X=-63462.8,Y=151779.3,Yaw=-135},{X=-64028.5,Y=152013.6,Yaw=-90},
    {X=-64594.2,Y=151779.3,Yaw=-45},{X=-64828.5,Y=151213.6,Yaw=0},{X=-64594.2,Y=150647.9,Yaw=45},
    {X=-64028.5,Y=150413.6,Yaw=90},{X=-63462.8,Y=150647.9,Yaw=135}}
Sbo.ARENA={zone='Zone_NK_Boss_Scarlet',point='NK_Boss_Scarlet'} -- coop sbo hop's.
-- The lobby targets, each in lobby/sbo_maps.lua's shape: key, name, zone, start point, spots with their Z, the fence
-- (centre X, Y, radius R, Z range) and the menu camera (FOV: the camera manager's when it has none). Xion's adds what
-- only it has: its row set, the training room and its region, and coop sbo seq's sequences.
local L=Sbo.LOBBY
Sbo.XION={key='xion',name='Xion',zone=L.zone,point=L.point,spots={},camera=L.camera,rows='lobby',room=L.room,
    region=L.region,seqs=true,fence={X=L.centre.X,Y=L.centre.Y,R=L.fence.radius,zmin=L.fence.zmin,zmax=L.fence.zmax}}
for i,p in ipairs(Sbo.SPOTS) do Sbo.XION.spots[i]={X=p.X,Y=p.Y,Z=L.spot_z,Yaw=p.Yaw} end
-- The hall lobbies in the maps' order, and the pak that holds their levels.
Sbo.PAK='zSBO_Lobby'
Sbo.HALLS={}
local UMAPS,ALL,XION_ONLY={},{Sbo.XION},{Sbo.XION}
for i,key in ipairs(Maps.order) do
    local t={key=key}
    for k,v in pairs(Maps.maps[key]) do t[k]=v end
    Sbo.HALLS[i],UMAPS[i],ALL[i+1]=t,t.umap,t
end
-- The rows a session edits, by set, each with its shipped and session value (tables at /Game/Local/Data/<t>.<t>).
-- SpawnType 0 EnterZone, 1 ZoneEvent: the boss no longer spawns on entry; InitActivate 1 Enable, 2 Disable: the camp,
-- theater and door triggers stay off.
local SPAWN,TRIGGER='EventSpawnTable','ZoneTriggerTable'
local function spawn(row,id) return {t=SPAWN,row=row,id=id,field='SpawnType',shipped=0,session=1} end
local function trigger(row,id) return {t=TRIGGER,row=row,id=id,field='InitActivate',shipped=1,session=2} end
Sbo.ROWS={
    lobby={spawn('Xion_Boss_Mann_E_CharS_001',1692024001),trigger('Xion_Boss_Mann_ZTrigger_001',169201001),
        trigger('Xion_Boss_Mann_ZTrigger_002',169201002),trigger('Xion_Boss_Mann_ZTrigger_003',169201003)},
    NK_Boss_Scarlet={spawn('NK_Boss_Scarlet_E_CharS_001',3191024001),trigger('NK_Boss_Scarlet_ZTrigger_001',319101001),
        trigger('NK_Boss_Scarlet_ZTrigger_002',319101002)},
}
Sbo.SETS={'lobby','NK_Boss_Scarlet'}
-- The spot of SteamID me, 1 to 8: its place in the round's ids when they list it, else 1 plus the number of other
-- SteamIDs (digits, compared as integers, each once) below it. Every game gets the same answer from the same ids.
function Sbo.spot(me,ids,round_ids)
    for i,id in ipairs(round_ids or {}) do
        if id==me then return math.min(i,8) end
    end
    local mine,below=tonumber(me),{}
    for _,id in ipairs(ids) do
        local n=tonumber(id)
        if n and n<mine then below[n]=true end
    end
    local rank=1
    for _ in pairs(below) do rank=rank+1 end
    return math.min(rank,8)
end
local function within(at,c,r) return (at.X-c.X)^2+(at.Y-c.Y)^2<=r*r end
-- Within 1 m (2D) of spot k of lobby t (Xion when nil).
function Sbo.near_spot(at,k,t) return within(at,(t or Sbo.XION).spots[k],100) end
-- Beyond the fence of lobby t (Xion when nil): more than its radius (2D) from its centre, or outside its Z range.
-- Xion's 30 m lies inside the ring's wall (SM_Barrier_04 at scale 0.8, inner face 29 m): EVE against the wall (her
-- centre near 28.9 m) is not caught, and a player whose centre is more than 1 m into the wall, or through it, is.
function Sbo.outside(at,t)
    local f=(t or Sbo.XION).fence
    return not within(at,f,f.R) or at.Z<f.zmin or at.Z>f.zmax
end
-- Each catch (now in seconds) sends her back to her spot, until three fall within 10 s: then stop.
function Sbo.fence()
    local times={}
    return {catch=function(now)
        times[#times+1]=now
        if #times>3 then table.remove(times,1) end
        return #times>=3 and now-times[#times-2]<=10 and 'stop' or 'back'
    end}
end
local function line(r,v,why,name)
    return string.format('sbo rows: %s %s %s reads %s %s: set %s not edited',r.t,r.row,r.field,tostring(v),why,name)
end
-- Writes every set's shipped value wherever a row reads otherwise (rows: {read=, write=}, see edit_set).
function Sbo.put_back(rows)
    for _,name in ipairs(Sbo.SETS) do
        for _,r in ipairs(Sbo.ROWS[name]) do
            if rows.read(r.t,r.row,r.field)~=r.shipped then rows.write(r.t,r.row,r.field,r.shipped) end
        end
    end
end
-- Edits set name to its session values: rows.read(t,row,field) gives a field's value and rows.write(t,row,field,value)
-- writes it. Every row is read first and the whole set refused when one holds neither its shipped nor its session value
-- (another mod changed it); then each row not at its session value is written and read back. A read-back that differs
-- puts every set back. true, or false and the log line.
function Sbo.edit_set(name,rows)
    local set,was=Sbo.ROWS[name],{}
    for i,r in ipairs(set) do
        was[i]=rows.read(r.t,r.row,r.field)
        if was[i]~=r.shipped and was[i]~=r.session then return false,line(r,was[i],'(another mod?)',name) end
    end
    for i,r in ipairs(set) do
        if was[i]~=r.session then
            rows.write(r.t,r.row,r.field,r.session)
            local v=rows.read(r.t,r.row,r.field)
            if v~=r.session then
                Sbo.put_back(rows)
                return false,line(r,v,'after the write',name)
            end
        end
    end
    return true
end
-- The native part's end words (L1's Why) as notice keys; other words (none, off, stale, running, done) show nothing.
local KEYS={flow='no.busy',phase='no.busy',warp='no.busy',camp='no.busy',reload='no.busy',busy='no.busy',
    nosave='no.save',build='no.save',bc='no.boss',queue='no.queue',record='no.record',late='no.record',coop='no.coop',
    slot='no.coop',manager='fail.save',sidecar='fail.save',saveread='fail.save',unsaved='fail.save',timeout='fail.save',
    rows='fail.warp',game='fail.warp',zone='fail.warp',type='fail.warp',guard='fail.leave',restore='fail.leave'}
function Sbo.notice_key(why) return KEYS[why] end
-- The Lua checks before the entry, o={gate=sbo_lobby, saves=link.saves(), steam=Steam ready, link=link.mode(),
-- fight=a fight near EVE, nightop=a Night Operation run}: nil, or the first that fails as its word.
function Sbo.checks(o)
    if not o.gate then return 'off' end
    if o.saves.saves~='coop' or o.saves.slot~='coop' then return 'no.coop' end
    if not o.steam then return 'no.steam' end
    if o.link~='none' then return 'no.partner' end
    if o.fight then return 'no.fight' end
    if o.nightop then return 'no.nightop' end
end
-- The verbs whose end gives the move input back and says a notice (R16): the requests Lua asks for a session and SB's
-- own reload; on, arm and abort are logged only.
local VERBS={enter=true,warp=true,leave=true,sb=true}
local ACTIVE={starting=true,open=true,warping=true,arrived=true,leaving=true}
local BUSY='an SBO entry is already running'
local HOP='coop sbo hop: only in the SBO lobby with no match lobby open'
local BACK='coop sbo back: only in an arena of the SBO session'
-- coop sbo seq's aliases: Zone_Xion_10's light phases (design-lobby 2.6). Their FName number is 0: a suffix with a
-- leading zero stays in the name.
local SEQS={'Xion_10_E_Seq_011','Xion_10_E_Seq_013','Xion_10_E_Seq_012','Xion_10_E_Seq_019'}
local SEQ_USE='coop sbo seq: one of '..table.concat(SEQS,', ')
local SEQ_WHERE='coop sbo seq: only in the SBO lobby'
local SEQ_XION='coop sbo seq: only in the SBO lobby in Xion'
-- cm: a seat's reach for menu_key (from EVE to where she stands on it: the seat point plus 100).
local NEAR=150
local NONE,WALKING=0,1 -- EMovementMode.
-- SB's chair blueprint for each seat kind of lobby/sbo_maps.lua, as build 26123051 ships them: its asset (the class
-- is <asset>_C), the actor's yaw from the seat's (EVE faces actor +X seated in an outdoor or bar chair, -X at a table),
-- where the end of SB's Start root motion seats her in the actor's frame, and the blueprint's own meshes and blocking
-- shapes, hidden with their collision off: our map draws the seat. Left alone: the root capsule, and the
-- MeshClipingBox_* SB clips EVE's mesh with (hidden, no collision already).
local ZONE_ENV='/Game/GameDesign/Level/ZoneEnv/'
Sbo.CHAIRS={outdoor={asset=ZONE_ENV..'Env_Chair_05.Env_Chair_05',turn=0,seated={X=-1.31,Y=4.54},
        parts={'079_A_SM','BoxCollision'}},
    bar={asset=ZONE_ENV..'Env_Chair_03.Env_Chair_03',turn=0,seated={X=-0.7,Y=0.8},parts={'121_H_SM'}},
    table={asset=ZONE_ENV..'Env_Chair_04.Env_Chair_04',turn=180,seated={X=-14.5,Y=3},
        parts={'Chair','Table','Capsule'}}}
-- The chair actor's place for seat s, a kind of CHAIRS: its yaw, X and Y where the seated offset turned by that yaw
-- lands on the seat, Z the seat's floor (the blueprints' roots sit at the floor).
function Sbo.chair_at(s)
    local c=Sbo.CHAIRS[s.kind]
    local yaw=s.Yaw+c.turn
    local cos,sin=math.cos(math.rad(yaw)),math.sin(math.rad(yaw))
    return {X=s.X-(c.seated.X*cos-c.seated.Y*sin),Y=s.Y-(c.seated.X*sin+c.seated.Y*cos),Z=s.Z,Yaw=yaw}
end
-- s of chair spawns a 250 ms pass: at least one, then more until this is spent (one spawn took 8 to 13 ms in game,
-- matrix13/world/breakables.lua's BUDGET), HELD_BUDGET under the arrival's hold (SB's black hides the frames they
-- take); and s from the last spawn to the bind check (SB makes a zone's env objects over several frames after the zone
-- entry).
Sbo.CHAIR_BUDGET=0.004
Sbo.HELD_BUDGET=0.1
local CHECK=1
-- Stage 2 at run time (the 250 ms loop), from link.sbo(), link.members() and link.round(). o: link, settings,
-- log(line), say(key) (a notice by its dotted key in ui/text.lua, 'sbo.saving'), ue (the engine: game_instance(),
-- pc(), eve(), first(class) (its first actor or nil), find_name(text), index_of(fname), rows={read=,write=} as
-- edit_set takes them, camera(at, rotation) (a camera actor: core/actors.lua's spawn, {actor=, path=, mesh=}, raises
-- when it cannot be made), alive(camera) (its actor while it is still that camera) and sweep(path) (a camera an earlier
-- Lua load left, gone), and the hall chairs: chair_class(asset) (its class, in memory or loaded; raises when neither),
-- chair(class, row, at, parts) (SB's chair spawned at {X, Y, Z, Yaw} for that ZoneEnvSpawnTable row, its parts hidden
-- with their collision off; raises when a step fails) and bound(actor) (the zone and row SB bound it to: its
-- BindZoneAlias and EnvSpawnAlias, nil when it is gone)), recruiter (its run()), nightop (its running()) and fight() (a
-- fight near EVE), and the hall lobbies' gate: paks (SB/Content/Paks, nil when unknown), read (core/link.lua's
-- files.read) and halls (the hall rows' lobby/halls_rows.lua, its ok()), and the hall seats' emote (cut/eve/emote.lua's
-- sit(kind), active(), stop(why) and preload(kind)), riding() (bike/ride.lua's: EVE rides the bike; nil when there is
-- none) and the arrival's hold (lobby/arrival.lua's arm(), disarm(why) and held(); none when nil). link.store
-- ('coop-sbo.txt') keeps the menu camera's path across Lua loads. Each console method returns ok and its text.
local NO_HOLD={arm=function() end,disarm=function() end,held=function() return false end}
function Sbo.new(o)
    local link,settings,log,say,ue=o.link,o.settings,o.log,o.say,o.ue
    local arrival=o.arrival or NO_HOLD
    local self={}
    local seen=nil -- The sbo line as last read: {join=, record=, n=, verb=, result=}; nil before the first.
    local entry=false -- An entry runs: from its start to the arrival or its end word.
    local held=false -- Our move-input hold is on (an entry's or a return's).
    local rerun=false -- The return closed: coop recruiter once EVE is back.
    local turned_on=false
    -- The waiting room: our spot (nil before one is known), a teleport asked {k=spot, tries=refusals}, EVE to be placed
    -- once her spot is known, the fence and its word (off, on, stopped), the room's word for coop sbo status, and the
    -- ids of the last round start seen in this Lua run (R18).
    local spot,want,placing,fence,fenced,room_word,kept=nil,nil,false,nil,'off','-',nil
    local placed=nil -- The spot of the last teleport the game took: where EVE stands is logged on the next pass.
    -- The menu camera (design-lobby 2.6): ue.camera's, nil before the first; viewing: to_menu has the view and the
    -- move input; framed: the views coop sbo view set kept, by lobby key ({X=, Y=, Z=, Pitch=, Yaw=, FOV=}, until the
    -- mod reloads); left: coop-sbo.txt's path from an earlier Lua load, swept at the first pass on the game thread.
    local cam,viewing,framed=nil,false,{}
    local store=link.store('coop-sbo.txt')
    local left=store.load()
    local arrived_in=nil -- The lobby of the last lobby arrival, where coop sbo back returns from an arena.
    local creating=nil -- A Private match asked on another lobby, {request=, to=}: its warp runs.
    local pak=nil -- The lobby pak gate's answer, {version} or {nil, why}, read once a Lua load.
    local fallback=nil -- Why the lobby is Xion, as last logged.
    -- The seat EVE sits on, the address of the EVE that sat, and the sbo line's arrivals count when she sat (after a
    -- travel a new EVE can stand at the freed one's address).
    local seated,sat_at,sat_in=nil,nil,nil
    -- The chairs of the last hall arrival: its lobby and arrivals count, the seats that get one (a kind of CHAIRS and a
    -- row), the next to spawn, each kind's class lookup ({true, class} or {false, why}), the actors by seat, the
    -- spawns that failed, the time spent and the passes, when the last spawn ended, and spare: the seats menu_key sits
    -- on (no chair, or one SB did not bind), nil before the bind check. nil outside a hall.
    local chairs=nil
    local interacting=nil -- The seat nearest EVE when SB's interaction on her started; nil while none runs.
    -- The last stand-up, for its line a pass later: the seat's number, the address of the EVE that stood up and the
    -- approach point. nil once logged.
    local stood=nil
    -- The hall lobby pak's version, or nil and why (core/pak_gate.lua, read once a Lua load).
    function self.gate()
        pak=pak or {PakGate.find(o.paks,o.read,Sbo.PAK,UMAPS)}
        return pak[1],pak[2]
    end
    -- The lobbies an entry draws from: the halls once the pak gate passed and their rows are in, else Xion, with one
    -- log line saying why (a refusal of the rows is lobby/halls_rows.lua's line).
    local function targets()
        local version,why=self.gate()
        local rows=version and o.halls and o.halls.ok()
        if rows then return Sbo.HALLS end
        if version then why=rows==nil and 'the hall rows are not in yet' or nil end
        if why and why~=fallback then fallback=why; log('sbo: lobby in Xion: '..why) end
        return XION_ONLY
    end
    local function pick()
        local set=targets()
        return set[math.random(#set)]
    end
    local function hold()
        local pc=ue.pc()
        if pc then pc:SetIgnoreMoveInput(true); held=true end
    end
    -- The move input back as cut/enemies/leviathan.lua gives it, reset when the game still ignores it: no end word,
    -- mapped or not, leaves EVE frozen.
    local function release()
        held=false
        local pc=ue.pc()
        if not pc then return end
        pc:SetIgnoreMoveInput(false)
        if pc:IsMoveInputIgnored()==true then pc:ResetIgnoreMoveInput() end
    end
    local function running(s)
        return entry or s~=nil and s.last.result=='running' and (s.last.verb=='enter' or s.last.verb=='warp')
    end
    -- R9 seen (leave or sb done, or the record closed after leaving): EVE back, and coop recruiter once she is in Xion.
    local function home()
        if held then release() end
        rerun=true
    end
    -- R2 and R3: the Steam lobby left when one is open, then every row set as shipped.
    local function back_out()
        local mode=link.mode()
        if mode and mode~='none' then link.request('leave') end
        Sbo.put_back(ue.rows)
    end
    -- design-lobby 3.3: the checks, then EVE held, the saving notice and sbo enter with SB's save manager. A refusal
    -- says its notice (the gate's too, for coop sbo enter with sbo_lobby=off) and asks nothing.
    local function start()
        if running(link.sbo()) then return false,BUSY end
        local key=Sbo.checks({gate=settings.sbo_lobby,saves=link.saves() or {},steam=link.mode()~=nil,link=link.mode(),
            fight=o.fight(),nightop=o.nightop.running()})
        if key=='off' then key='no.lobby' end
        local found,manager=false,0
        if not key then found,manager=pcall(function() return U.address(ue.game_instance().SaveObjectManager) end) end
        if not key and not (found and manager~=0) then key='fail.save' end -- No manager to save with.
        if key then
            log('sbo: no entry: '..key)
            say('sbo.'..key)
            return false,'no entry: sbo.'..key
        end
        entry=true
        hold()
        say('sbo.saving')
        local asked,why=link.request(string.format('sbo enter 0x%x',manager))
        if not asked then entry=false; release() end
        return asked,why
    end
    -- E8 once the record reads open after enter done: a lobby drawn, its rows (Xion's; a hall edits none), then the
    -- warp to its zone and start point. A refusal closes the record (sbo abort rows) and gives EVE back. A Lua load
    -- that takes the step over draws again: nothing was warped yet.
    local function lobby(record)
        local t=pick()
        local zone,point=ue.index_of(ue.find_name(t.zone)),ue.index_of(ue.find_name(t.point))
        local ok,why=record=='open',string.format('sbo: enter done with the record %s: no warp',record)
        if ok and (zone==0 or point==0) then
            ok,why=false,'sbo: '..t.zone..' or '..t.point..' is not a name in this game run'
        end
        if ok and t.rows then ok,why=Sbo.edit_set(t.rows,ue.rows) end
        if ok then
            local asked,refused=link.request(string.format('sbo warp %d 0 %d 0',zone,point))
            if asked then arrival.arm() end
            return asked,refused
        end
        log(why)
        link.request('sbo abort rows')
        entry=false
        release()
        say('sbo.fail.warp')
    end
    -- A new result of the native part: logged; for the four verbs, anything but running and done ends what it was
    -- (EVE back, its notice, the rows put back after a warp the native part refused and closed: E9's undo of E8).
    local function result(s)
        local verb,word=s.last.verb,s.last.result
        if not verb or not word then return end
        log(string.format('sbo: %s %s, record %s',verb,word,s.record))
        if not VERBS[verb] then return end
        if word=='running' then
            -- SB's own reload: R2 and R3 (the native part runs R7 to R9). Its sb job starts only once any enter or
            -- warp job has ended, so an entry still waiting for its arrival ends here.
            if verb=='sb' then entry=false; arrival.disarm('SB\'s reload'); back_out() end
            return
        end
        if word=='done' then
            if verb=='enter' then lobby(s.record) elseif verb~='warp' then home() end
            return
        end
        if verb=='enter' or verb=='warp' then entry=false end
        if verb=='warp' then
            creating=nil -- A Private match's warp refused: no match lobby.
            arrival.disarm('the warp ended: '..word)
        end
        if held then release() end
        if verb=='warp' and s.record=='closed' then Sbo.put_back(ue.rows) end
        local key=Sbo.notice_key(word)
        if (verb=='leave' or verb=='sb') and (word=='timeout' or word=='sidecar') then key='fail.leave' end
        if key then say('sbo.'..key) end
    end
    -- L8-R1: the first read after a Lua load counts no Join, but takes over a step this native run left under way. The
    -- move-input hold sits on the controller and outlasts the load, and an open record has no native timeout.
    local function adopt(s)
        local verb,word=s.last.verb,s.last.result
        local step=verb and word and verb..' '..word
        if step=='enter running' or step=='warp running' or step=='enter done' and s.record=='open' then entry=true
        elseif step~='leave running' then return end
        held=true
        log('sbo: Lua load during '..step..', record '..s.record..': taken over')
        if step=='enter done' then lobby(s.record) end
    end
    local function at_zone(s,zone)
        if not (s and s.record=='arrived') then return false end
        local index=ue.index_of(ue.find_name(zone))
        return index~=0 and s.zone==index..':0'
    end
    -- The lobby of the last arrival, from its zone (a Lua reload finds it too), or nil.
    local function lobby_at(s)
        for _,t in ipairs(ALL) do
            if at_zone(s,t.zone) then return t end
        end
    end
    -- A warp from the lobby world to zone and point (FName texts): coop sbo hop and back, and a match lobby's map. All
    -- but the hop's go to a lobby and arm the arrival's hold.
    local function warp(zone,point)
        local z,p=ue.index_of(ue.find_name(zone)),ue.index_of(ue.find_name(point))
        if z==0 or p==0 then return false,zone..' or '..point..' is not a name in this game run' end
        local asked,why=link.request(string.format('sbo warp %d 0 %d 0',z,p))
        if asked and zone~=Sbo.ARENA.zone then arrival.arm() end
        return asked,why
    end
    -- In lobby t, a guest of a match lobby goes where it waits (link.room()): a warp there when it is another lobby
    -- an entry here draws from, else, when it names a map we lack or another pak version (link.hall(); a join by code
    -- skips the search's filter), its line, the notice and a leave. A host's lobby names the map she stood on, a co-op
    -- lobby none. Once per arrival and joined lobby: a refused warp waits for the next arrival or a new join.
    local followed=nil
    local function follow(s,t)
        if entry then return end
        if link.mode()~='guest' or not link.owner() then followed=nil; return end
        local room,hall,ours=link.room(),link.hall(),self.hall()
        local key=table.concat({s.arrivals,link.lobby() or '-',room or '-',hall or '-'},' ')
        if key==followed then return end
        followed=key
        local to=nil
        for _,x in ipairs(hall==ours and targets() or {}) do
            if x.key==room then to=x end
        end
        if to==t then return end
        if to then
            local ok,why=warp(to.zone,to.point)
            return log(string.format('sbo: match lobby %s: map %s: %s',link.lobby(),room,ok and 'warp there' or why))
        end
        log(string.format('sbo: match lobby %s: map %s, pak %s (ours %s): left',link.lobby(),tostring(room),
            tostring(hall),ours))
        say('sbo.no.hall')
        link.request('leave')
    end
    -- A Private match's warp arrived: its request with this lobby's words, unless the warp landed elsewhere.
    local function created(s)
        local c,t=creating,lobby_at(s)
        creating=nil
        if t~=c.to then return log('sbo: private match in '..c.to.key..': the warp landed elsewhere, not created') end
        log(string.format('sbo: private match in %s: %s',t.key,
            select(2,link.request(c.request..' '..t.key..' '..self.hall()))))
    end
    -- design-lobby 2.2 step 2: SB's training room shown as SB shows it (SetActorHiddenInGame, as 0x1422ace00 calls
    -- it) and its two platforms hidden (InitRegion with any name but AirBreakFall or AirDropAttack). A read-back that
    -- fails is logged and the lobby goes on: the platforms sit over the centre, away from the spots. L: Xion's target.
    local function show_room(L)
        local room=ue.first(L.room)
        if not room then room_word='missing'; return log('lobby room: '..L.room..' not found') end
        local region=U.text(room.UniqueRegionName)
        if region~=L.region then
            room_word='other'
            return log('lobby room: region reads '..region..', not '..L.region)
        end
        room:SetActorHiddenInGame(false)
        room:InitRegion(ue.find_name('Default'))
        room_word='shown'
        if room.bHidden~=false then room_word='unsure'; log('lobby room: still hidden after SetActorHiddenInGame') end
        for _,plane in ipairs({'Plane_Common','Plane_AirBreakFall'}) do
            if room[plane]:IsVisible()~=false then
                room_word='unsure'
                log('lobby room: '..plane..' still visible after InitRegion')
            end
        end
    end
    -- her up from seat s: the teleport to the seat's approach point while her collision is still off, then her
    -- collision back and walking; where she stood up, for the log. K2_TeleportTo is AActor::TeleportTo (vtable +0x548,
    -- 0x143f60390, the same entry in SBCharacter's vtable), which in a game that is not a client always runs
    -- UWorld::FindTeleportSpot (0x1442cd4e0): with her collision on it refuses a spot where her standing capsule meets
    -- blocking geometry and no nudge frees it, as at every stand-up of the 2026-11-14 test; with it off the spot test
    -- finds nothing to meet, as at every sit. A teleport that raises still gets her collision and walking back, then
    -- raises. Why the spot test refused those spots is not settled, so the next pass logs where she stands (after_up).
    local function get_up(her,s)
        local a=s.approach
        local ok,went=pcall(function() return her:K2_TeleportTo({X=a.X,Y=a.Y,Z=a.Z},{Pitch=0,Yaw=s.Yaw,Roll=0}) end)
        her:SetActorEnableCollision(true,false)
        her.CharacterMovement:SetMovementMode(WALKING,0)
        if not ok then error(went,0) end
        stood={n=s.n,at=U.address(her),a=a}
        return went~=false and 'at the approach point'
            or 'where she sat, the game refused the teleport to the approach point'
    end
    -- A pass after a stand-up, with her collision back since: where that EVE stands and how far from the approach
    -- point, so the log shows whether the engine moved her out of something there. Nothing for another EVE or none.
    local function after_up()
        local x,her=stood,ue.eve()
        stood=nil
        if not (her and U.address(her)==x.at) then return end
        local p,a=U.value_of(her:K2_GetActorLocation()),x.a
        log(string.format('lobby seat %d: a pass after she stood up, EVE at %.0f %.0f %.0f, %.0f cm from the approach '
            ..'point',x.n,p.X,p.Y,p.Z,math.sqrt((p.X-a.X)^2+(p.Y-a.Y)^2+(p.Z-a.Z)^2)))
    end
    -- EVE up from her seat, logged with why: the loop stopped, then get_up(). An EVE other than the one that sat (a warp
    -- under way ended the loop), none, or a record that is no longer the arrival she sat in (a new EVE at the old
    -- address): the seat forgotten, no engine call.
    local function rise(why)
        local s,at,n=seated,sat_at,sat_in
        seated=nil
        o.emote.stop(why)
        local her,now=ue.eve(),link.sbo()
        local gone=not her and 'no EVE in the world' or U.address(her)~=at and 'her EVE changed'
            or not (now and now.record=='arrived' and now.arrivals==n) and 'a warp since she sat'
        if gone then return log(string.format('lobby seat %d: forgotten, %s (%s)',s.n,gone,why)) end
        local ok,where_up=pcall(get_up,her,s)
        log(string.format('lobby seat %d: stood up %s (%s)',s.n,ok and where_up or 'with an error: '..tostring(where_up),
            why))
    end
    -- After a Lua load in hall t: EVE left seated by the last load (her collision off; the native part stopped the
    -- loop) stands up at the approach point of the seat nearest her, as rise does.
    local function left_seated(t)
        local her=ue.eve()
        if not (t.seats and her and her:GetActorEnableCollision()==false) then return end
        local at,s,d2=U.value_of(her:K2_GetActorLocation()),nil,math.huge
        for _,x in ipairs(t.seats) do
            local d=(at.X-x.X)^2+(at.Y-x.Y)^2+(at.Z-x.Z-100)^2
            if d<d2 then s,d2=x,d end
        end
        log(string.format('lobby seat %d: an earlier Lua load left EVE seated: stood up %s',s.n,get_up(her,s)))
    end
    -- The sit loops of seats (those menu_key sits on) looked up now, once a kind, so the first sit finds its clip in
    -- memory (cut/eve/emote.lua's preload): the kinds, for the log line, each with its error when the look-up raised.
    local function preload(seats)
        local kinds,seen={},{}
        for _,x in ipairs(seats) do
            if not seen[x.kind] then
                seen[x.kind]=true
                local ok,found=pcall(o.emote.preload,x.kind)
                kinds[#kinds+1]=x.kind..(not ok and ' (error: '..tostring(found)..')' or found and '' or ' (missing)')
            end
        end
        return #kinds>0 and ', sit loops looked up: '..table.concat(kinds,', ') or ''
    end
    -- After a Lua load in hall t: the rows of t's zone the earlier load's chairs are bound to (each kind of the hall's
    -- chairs found in EVE's world, its bind read as the check reads it). Raises with why.
    local function bound_rows(t)
        local rows,seen={},{}
        for _,x in ipairs(chairs.list) do
            local k=Sbo.CHAIRS[x.kind]
            if not seen[k] then
                seen[k]=true
                for _,a in ipairs(ue.chairs_of(ue.chair_class(k.asset),k.asset:match('[^.]+$')..'_C')) do
                    local zone,row=ue.bound(a)
                    if zone==t.zone then rows[row]=true end
                end
            end
        end
        return rows
    end
    -- At a hall arrival: its seats that get a chair, spawned over the next passes. After a Lua load in the hall the
    -- earlier load's chairs stand there already: no new ones, and menu_key sits on each seat none of them is bound to
    -- (every seat when that read raises, logged).
    local function chairs_for(s,t,reloaded)
        chairs={t=t,arrivals=s.arrivals,list={},next=1,classes={},made={},failed=0,spent=0,passes=0}
        for _,x in ipairs(t.seats) do
            if Sbo.CHAIRS[x.kind] and x.row then chairs.list[#chairs.list+1]=x end
        end
        if not reloaded then return end
        local ok,rows=pcall(bound_rows,t)
        if not ok then log('lobby '..t.name..' chairs: the earlier load\'s binds did not read: '..tostring(rows)) end
        local left,ns={},{}
        chairs.spare={}
        for _,x in ipairs(t.seats) do
            if not (ok and x.row and rows[x.row]) then chairs.spare[x],left[#left+1],ns[#ns+1]=true,x,x.n end
        end
        log(string.format('lobby %s chairs: none spawned after a Lua load (the earlier load\'s stay), %d bound; '
            ..'menu_key sits on %s%s',t.name,#t.seats-#ns,#ns>0 and 'seats '..table.concat(ns,' ') or 'none',
            preload(left)))
    end
    -- One seat's chair: its kind's class (looked up once an arrival), then ue.chair. Raises with why.
    local function chair(x)
        local k,c=Sbo.CHAIRS[x.kind],chairs
        c.classes[x.kind]=c.classes[x.kind] or {pcall(ue.chair_class,k.asset)}
        local got=c.classes[x.kind]
        if not got[1] then error(tostring(got[2]),0) end
        return ue.chair(got[2],x.row,Sbo.chair_at(x),k.parts)
    end
    -- Each pass of the arrival the chairs belong to: the spawns on the budget (a failed one logged), then, CHECK s
    -- after the last one and with SB's zone loader done (loader 3, or 4 after a zone reset, the states the native
    -- arrival latch takes: game/sbo.h), the bind check once. A chair is bound when SB gave it its row: BindZoneAlias
    -- the hall's zone and EnvSpawnAlias the seat's row, both written by the bind (FUN_1422bacc0 for an actor spawned
    -- after its row's env object, the zone entry's FUN_142281550 for one spawned before). A bind read that raises
    -- leaves its seat to menu_key; the first such error of the check is logged with its seat. One line, then the sit
    -- loops of the seats left to menu_key looked up.
    local function chair_pass(s,now)
        local c=chairs
        if not c or c.spare or s.record~='arrived' or s.arrivals~=c.arrivals then return end
        if c.next<=#c.list then
            local start=os.clock()
            repeat
                local x=c.list[c.next]
                c.next=c.next+1
                local ok,a=pcall(chair,x)
                if ok then c.made[x]=a else
                    c.failed=c.failed+1
                    log(string.format('lobby seat %d (%s): no chair: %s',x.n,x.kind,tostring(a)))
                end
            until c.next>#c.list or os.clock()-start>=(arrival.held() and Sbo.HELD_BUDGET or Sbo.CHAIR_BUDGET)
            c.spent,c.passes=c.spent+os.clock()-start,c.passes+1
            if c.next>#c.list then c.ended=now end
            return
        end
        c.ended=c.ended or now
        if now-c.ended<CHECK or not (s.loader==3 or s.loader==4) then return end
        local bound,spare,left,ns,told=0,{},{},{},false
        for _,x in ipairs(c.t.seats) do
            local ok,zone,row=false,nil,nil
            if c.made[x] then
                ok,zone,row=pcall(ue.bound,c.made[x])
                if not ok and not told then
                    told=true
                    log(string.format('lobby seat %d (%s): its chair\'s bind did not read (the first such error of '
                        ..'this check): %s',x.n,x.kind,tostring(zone)))
                end
            end
            if ok and zone==c.t.zone and row==x.row then bound=bound+1 else
                spare[x],left[#left+1],ns[#ns+1]=true,x,x.n
            end
        end
        c.spare=spare
        log(string.format('lobby %s chairs: %d of %d spawned in %.0f ms (%d pass%s), %d bound; menu_key sits on %s%s',
            c.t.name,#c.list-c.failed,#c.list,c.spent*1000,c.passes,c.passes==1 and '' or 'es',bound,
            #ns>0 and 'seats '..table.concat(ns,' ') or 'none',preload(left)))
    end
    -- SB's interaction on EVE in hall t (SBCharacter's IsRunningInteraction: its exec 0x14268cc20 reads +0x3493),
    -- logged as it starts, with the seat nearest her, and as it ends, so the log shows SB's sit.
    local function watch(t)
        local her=ue.eve()
        local on=her~=nil and her:IsRunningInteraction()==true
        if on==(interacting~=nil) then return end
        if not on then
            log(string.format('lobby seat %d: SB\'s interaction ended',interacting.n))
            interacting=nil
            return
        end
        local at,d2=U.value_of(her:K2_GetActorLocation()),math.huge
        for _,x in ipairs(t.seats) do
            local d=(at.X-x.X)^2+(at.Y-x.Y)^2
            if d<d2 then interacting,d2=x,d end
        end
        log(string.format('lobby seat %d (%s): SB\'s interaction runs, EVE %.0f cm from it',interacting.n,
            interacting.kind,math.sqrt(d2)))
    end
    -- design-lobby 2.2 steps 2 to 4 at each type-5 arrival of the session: in a lobby, Xion's room, EVE to her spot and
    -- the fence; after a Lua load there (plan call 9), the same with EVE left where she stands inside the fence.
    local function arrive(s,reloaded)
        spot,want,placing,fenced,room_word,placed=nil,nil,false,'off','-',nil
        viewing=false -- A new world: the old camera is gone and the controller is a new one.
        seated=nil -- Her EVE is a new one too.
        chairs,interacting=nil,nil -- The map change took the chairs.
        if at_zone(s,Sbo.ARENA.zone) then return log('sbo: arena arrival') end
        local t=lobby_at(s)
        if not t then return end
        arrived_in=t
        if reloaded then
            local ok,err=pcall(left_seated,t)
            if not ok then log('lobby seat: '..tostring(err)) end
        end
        if t.seats then chairs_for(s,t,reloaded) end
        if t.room then
            -- A room field that raises (a name not checked on a live room) stops nothing.
            local ok,err=pcall(show_room,t)
            if not ok then room_word='unsure'; log('lobby room: '..tostring(err)) end
        end
        placing,fence,fenced=not reloaded,Sbo.fence(),'on'
        log(string.format('%s, fence on (%d cm)%s',t.room and 'lobby room: '..room_word or 'lobby '..t.name,t.fence.R,
            reloaded and ', EVE left where she stands' or ''))
    end
    -- EVE to the spot asked in lobby t, as matrix13/world/travel.lua teleports her. A refusal is tried again on the
    -- next three passes, then logged (plan call 10, R19: no notice).
    local function place(t)
        local her,p=ue.eve(),t.spots[want.k]
        if her and her:K2_TeleportTo({X=p.X,Y=p.Y,Z=p.Z},{Pitch=0,Yaw=p.Yaw,Roll=0})~=false then
            placed,want=want.k,nil
            return
        end
        want.tries=want.tries+1
        if want.tries==4 then
            log(string.format('lobby: teleport to spot %d refused 4 times',want.k))
            want=nil
        end
    end
    local function where()
        local her=ue.eve()
        return her and U.value_of(her:K2_GetActorLocation())
    end
    -- Each pass in lobby t while no round of ours plays: the spot from our SteamID, the members' and the last
    -- round's ids (2.4); EVE moved to a new spot when she still stands on her old one (12.7); the teleport asked; the
    -- fence (2.5).
    local function waiting_room(now,t)
        if placed then -- 2D distance, as near_spot measures it: a move back by the game shows here.
            local at,p=where(),t.spots[placed]
            if at then
                log(string.format('lobby: EVE teleported to spot %d, now at %.0f %.0f %.0f (%.1f m from it)',placed,
                    at.X,at.Y,at.Z,math.sqrt((at.X-p.X)^2+(at.Y-p.Y)^2)/100))
                placed=nil
            end
        end
        local me=link.saves().steamid
        if not me then return end -- L6-R1: no SteamID read yet (a fresh link after a Lua load, or Steam not ready).
        local r=link.round()
        if r and r.kind=='start' then
            for _,id in ipairs(r.ids) do if id==me then return end end -- Our round: stage 4's (R18).
        end
        local ids={}
        for _,m in ipairs(link.members()) do ids[#ids+1]=m.id end
        local k=Sbo.spot(me,ids,kept)
        if spot and k~=spot and not want then
            local at=where()
            if at and Sbo.near_spot(at,spot,t) then want={k=k,tries=0} end
        end
        spot=k
        if placing then placing,want=false,{k=k,tries=0} end
        if want then
            want.k=k
            return place(t)
        end
        local at=fenced=='on' and where()
        if not at or not Sbo.outside(at,t) then return end
        if fence.catch(now)=='stop' then
            fenced='stopped'
            return log('lobby room: no floor or ring collision')
        end
        log(string.format('lobby fence: EVE at %.0f %.0f %.0f, back to spot %d',at.X,at.Y,at.Z,k))
        want={k=k,tries=0}
        place(t)
    end
    -- The camera an earlier Lua load left (Review Focus 2): swept by its path, once, before any new camera.
    local function sweep_left()
        if not left then return end
        local path=left
        left=nil
        local ok,gone=pcall(ue.sweep,path)
        store.clear()
        log('lobby camera: an earlier Lua load\'s camera '..(not ok and 'not swept: '..tostring(gone)
            or gone and 'swept' or 'already gone'))
    end
    -- Every 250 ms (now: os.clock, in seconds).
    function self.tick(now)
        sweep_left()
        local s=link.sbo()
        if not s then return end
        local was=seen
        seen={join=s.join,record=s.record,n=s.last.n,verb=s.last.verb,result=s.last.result,arrivals=s.arrivals}
        local r=link.round()
        if r and r.kind=='start' then kept=r.ids end
        if rerun and ue.eve() then
            rerun=false
            log('sbo: back in Xion: coop recruiter: '..tostring(select(2,o.recruiter.run())))
        end
        if not was then -- The first line read: what came before this Lua load is not new.
            if s.record=='arrived' then arrive(s,true) end -- Review Focus 2.
            return adopt(s)
        end
        if s.join>was.join then
            if running(s) then log('sbo: Join while an entry runs: no second entry') else start() end
        end
        if s.last.n~=was.n or s.last.result~=was.result then result(s) end
        if s.record~=was.record then
            if s.record=='arrived' then entry,held=false,false end -- The warp's load made a new controller.
            if s.record=='closed' and was.record=='leaving' then home() end
            if s.record=='closed' then kept,creating=nil,nil end -- L9-R2: a round's ids belong to one session.
        end
        -- L9-R1: the native part can show the new arrivals= one line before record=arrived. Not leaving to arrived:
        -- a leave stopped before its reload places nobody again.
        if s.record=='arrived' and (s.arrivals~=was.arrivals or was.record=='warping') then
            arrive(s)
            if creating then created(s) end
        end
        if stood then
            local ok,err=pcall(after_up)
            if not ok then log('lobby seat: where she stood up did not read: '..tostring(err)) end
        end
        if seated and not o.emote.active() then rise('the loop ended') end -- coop emote's end rules ended it.
        chair_pass(s,now)
        local t=self.target()
        if t then
            follow(s,t)
            waiting_room(now,t)
            if t.seats then watch(t) end
        end
    end
    -- sbo on once a Lua load with sbo_lobby=on: the co-op saves' copies for this game run.
    function self.on_load()
        if not settings.sbo_lobby or turned_on then return end
        turned_on=true
        log('sbo: '..tostring(select(2,link.request('sbo on'))))
    end
    function self.enter()
        if not settings.sbo_lobby then return false,Sbo.OFF end
        return start()
    end
    -- The return (L3 R1 to R9): EVE held, R2 and R3 here, then sbo leave; only from the lobby world (record arrived).
    function self.leave()
        if not settings.sbo_lobby then return false,Sbo.OFF end
        local s=link.sbo()
        if not s or s.record~='arrived' then
            return false,'no SBO session to leave here (record '..(s and s.record or 'unread')..')'
        end
        hold()
        back_out()
        local asked,why=link.request('sbo leave')
        if not asked then release() end
        return asked,why
    end
    -- design-lobby 3.7's hop and back: the stand-in round trip of stage 4, the arena's rows then the warp there, and
    -- the warp back to the lobby (its rows stay edited for the session).
    function self.hop()
        if not settings.sbo_lobby then return false,Sbo.OFF end
        if not self.in_lobby() or link.mode()~='none' then return false,HOP end
        local ok,why=Sbo.edit_set('NK_Boss_Scarlet',ue.rows)
        if not ok then log(why); return false,'coop sbo hop: '..why end
        return warp(Sbo.ARENA.zone,Sbo.ARENA.point)
    end
    function self.back()
        if not settings.sbo_lobby then return false,Sbo.OFF end
        if not at_zone(link.sbo(),Sbo.ARENA.zone) then return false,BACK end
        local t=arrived_in or pick() -- The lobby hopped from; after a Lua load in the arena, one an entry would draw.
        return warp(t.zone,t.point)
    end
    -- The camera manager's view now; raises when the controller has none.
    local function view_of(pc)
        local m=pc.PlayerCameraManager
        local at,r=U.value_of(m:GetCameraLocation()),U.value_of(m:GetCameraRotation())
        return {X=at.X,Y=at.Y,Z=at.Z,Pitch=r.Pitch,Yaw=r.Yaw,FOV=U.value_of(m:GetFOVAngle())}
    end
    -- design-lobby 2.6 and 2.7: the menu camera made when none lives (at the view kept for this lobby, else its
    -- camera, with its FOV, else the camera manager's), its path kept for the next Lua load, then the view on it with
    -- blend 0 (a cut) and the move input ignored. ok, or false and why.
    function self.to_menu()
        local pc=ue.pc()
        if not pc then return false,'no player controller' end
        sweep_left()
        local ok,why=pcall(function()
            if not (cam and ue.alive(cam)) then
                local lobby_t=self.target() or Sbo.XION
                local t=framed[lobby_t.key] or lobby_t.camera
                local fov=t.FOV or U.value_of(pc.PlayerCameraManager:GetFOVAngle())
                cam=ue.camera({X=t.X,Y=t.Y,Z=t.Z},{Pitch=t.Pitch,Yaw=t.Yaw,Roll=0})
                local saved,save_why=store.save(cam.path)
                if saved==false then log('lobby camera: coop-sbo.txt not written: '..tostring(save_why)) end
                cam.mesh:SetFieldOfView(fov)
                log(string.format('lobby camera: made at %.0f %.0f %.0f pitch %.1f yaw %.1f, FOV %.1f',t.X,t.Y,t.Z,
                    t.Pitch,t.Yaw,fov))
            end
            pc:SetViewTargetWithBlend(cam.actor,0,0,0,false)
            if not viewing then pc:SetIgnoreMoveInput(true) end
            viewing=true
        end)
        if not ok then log('lobby camera: '..tostring(why)) end
        return ok,why
    end
    -- The view back to EVE's pawn with blend 0 and the move input back, as cut/enemies/leviathan.lua's give_back gives
    -- it; nothing unless to_menu has them.
    function self.to_room()
        if not viewing then return end
        viewing=false
        local pc=ue.pc()
        if not pc then return end
        local ok,why=pcall(function()
            local pawn=pc:K2_GetPawn()
            if pawn then pc:SetViewTargetWithBlend(pawn,0,0,0,false) end
        end)
        if not ok then log('lobby camera: the view not given back: '..tostring(why)) end
        release()
    end
    function self.view()
        if not settings.sbo_lobby then return false,Sbo.OFF end
        local pc=ue.pc()
        if not pc then return false,'coop sbo view: no player controller' end
        local ok,v=pcall(view_of,pc)
        if not ok then return false,'coop sbo view: '..tostring(v) end
        return true,string.format('sbo view: X=%.1f Y=%.1f Z=%.1f Pitch=%.1f Yaw=%.1f FOV=%.1f',v.X,v.Y,v.Z,v.Pitch,
            v.Yaw,v.FOV),v
    end
    -- The view now kept as the menu camera's of this lobby (Xion outside one) until the mod reloads (design-lobby 2.6),
    -- a live menu camera moved to it.
    function self.view_set()
        local ok,line,v=self.view()
        if not ok then return ok,line end
        framed[(self.target() or Sbo.XION).key]=v
        if cam and ue.alive(cam) then
            local moved,why=pcall(function()
                cam.mesh:K2_SetWorldLocationAndRotation({X=v.X,Y=v.Y,Z=v.Z},{Pitch=v.Pitch,Yaw=v.Yaw,Roll=0},false,{},
                    false)
                cam.mesh:SetFieldOfView(v.FOV)
            end)
            if not moved then log('lobby camera: not moved: '..tostring(why)) end
        end
        return true,line..', kept as the menu camera until the mod reloads'
    end
    -- design-lobby 2.6's light test: one of Zone_Xion_10's sequences, asked of the native part as sbo seq, in Xion.
    function self.seq(alias)
        if not settings.sbo_lobby then return false,Sbo.OFF end
        local known=false
        for _,a in ipairs(SEQS) do known=known or a==alias end
        if not known then return false,SEQ_USE end
        local t=self.target()
        if not t then return false,SEQ_WHERE end
        if not t.seqs then return false,SEQ_XION end
        local index=ue.index_of(ue.find_name(alias))
        if index==0 then return false,'coop sbo seq: '..alias..' is not a name in this game run' end
        return link.request(string.format('sbo seq %d 0',index))
    end
    function self.status()
        if not settings.sbo_lobby then return false,Sbo.OFF end
        local s=link.sbo()
        if not s then return false,'no sbo line from the native part yet' end
        -- The zone word: lobby (Xion's), a hall's key, arena or other.
        local index,zone=tonumber(s.zone:match('^(%d+)')),'other'
        if index~=0 then
            for _,t in ipairs(ALL) do
                if index==ue.index_of(ue.find_name(t.zone)) then zone=t==Sbo.XION and 'lobby' or t.key end
            end
            if index==ue.index_of(ue.find_name(Sbo.ARENA.zone)) then zone='arena' end
        end
        local here=self.in_lobby()
        return true,string.format('sbo: record %s slot %s, zone %s, loader %d, spot %s, fence %s, room %s, copy %s',
            s.record,s.slot or '-',zone,s.loader,self.spot() or '-',here and fenced or 'off',here and room_word or '-',
            s.copy or '-')
    end
    -- Each time the title shows, whatever sbo_lobby says.
    function self.title() Sbo.put_back(ue.rows) end
    -- coop off: the rows put back and EVE given back; the record stays for C1 at the title (the native off logs it).
    function self.off()
        arrival.disarm('coop off')
        if seated then rise('coop off') end -- Before the rows: a put-back that raises leaves her standing.
        Sbo.put_back(ue.rows)
        entry=false
        self.to_room()
        if held then release() end
        local s=link.sbo()
        if s and ACTIVE[s.record] and s.record~='starting' then say('sbo.no.record') end
    end
    function self.active()
        local s=link.sbo()
        return s~=nil and ACTIVE[s.record]==true
    end
    -- The lobby EVE stands in, from the client zone (the record arrived, the last arrival's zone a lobby's), or nil.
    function self.target() return lobby_at(link.sbo()) end
    -- In the lobby world: in Xion's or a hall's.
    function self.in_lobby() return self.target()~=nil end
    -- A lobby drawn at random among those an entry would use: a hall's key, or 'xion'.
    function self.draw() return pick().key end
    -- The hall lobby pak's version when the halls are in use, else 'xion'.
    function self.hall() return targets()==Sbo.HALLS and (self.gate()) or 'xion' end
    -- A match request's room and hall words: the lobby EVE stands in (else one an entry would draw), then hall().
    function self.lobby_words() return (self.target() or pick()).key..' '..self.hall() end
    -- A Private match's request (match create <mode>) on room, a key of the lobbies an entry draws from or 'random' (a
    -- draw): asked at once with that lobby's words when EVE stands in it, else after a warp there, at her arrival. A
    -- room not in that set is the lobby she stands in (lobby_words()). ok and why.
    function self.create(request,room)
        if creating then return false,'a Private match waits for its warp to '..creating.to.name end
        local t,to=self.target(),room=='random' and pick() or nil
        for _,x in ipairs(targets()) do if x.key==room then to=x end end
        if t and to and to~=t then
            local ok,why=warp(to.zone,to.point)
            creating=ok and {request=request,to=to} or nil
            return ok,why
        end
        return link.request(request..' '..(to or t or pick()).key..' '..self.hall())
    end
    -- Our spot in the lobby, 1 to 8, or nil.
    function self.spot() return self.in_lobby() and spot or nil end
    -- The nearest seat menu_key sits on (no SB chair bound there) of the hall EVE stands in, within NEAR of her (to
    -- where she stands on it); nil while she sits, while SB's interaction runs on her (an SB chair seating her, with an
    -- unbound seat as close as 69 cm), before the bind check, and in Xion (no seats).
    function self.near_seat()
        local t=not seated and not interacting and self.target()
        local spare=t and chairs and chairs.t==t and chairs.spare
        local at=spare and next(spare) and where()
        if not at then return nil end
        local best,d2=nil,NEAR*NEAR
        for _,s in ipairs(t.seats) do
            local d=(at.X-s.X)^2+(at.Y-s.Y)^2+(at.Z-s.Z-100)^2
            if spare[s] and d<=d2 then best,d2=s,d end
        end
        return best
    end
    -- EVE onto seat, a seat of the hall she stands in: refused while she sits. Else her collision off, the teleport to
    -- the seat point at her standing height (her centre over her feet), her movement held (with no collision a fall
    -- would never land, and nothing pushes her) and the seat's loop. A step refused stands her up again. Refused while
    -- she rides the bike, before anything is written. ok and why.
    function self.sit(seat)
        if seated then return false,'EVE is already seated' end
        if o.riding and o.riding() then return false,'EVE rides the bike: coop bike gets her off first' end
        local her=ue.eve()
        if not her then return false,'no EVE in the world' end
        local now=link.sbo()
        seated,sat_at,sat_in=seat,U.address(her),now and now.arrivals
        local ok,why=pcall(function()
            local up=-U.value_of(her.Mesh.RelativeLocation).Z
            her:SetActorEnableCollision(false,false) -- SB's Actor takes (bNewActorEnableCollision, inFastUpdate).
            if her:K2_TeleportTo({X=seat.X,Y=seat.Y,Z=seat.Z+up},{Pitch=0,Yaw=seat.Yaw,Roll=0})==false then
                error('the game refused the teleport',0)
            end
            her.CharacterMovement:SetMovementMode(NONE,0)
            local played,refused=o.emote.sit(seat.kind)
            if not played then error(refused,0) end
        end)
        if not ok then
            rise(tostring(why))
            return false,string.format('seat %d: %s',seat.n,tostring(why))
        end
        log(string.format('lobby seat %d (%s): sat',seat.n,seat.kind))
        return true,string.format('seat %d: sat',seat.n)
    end
    -- EVE up from her seat (the menu key while she sits); she also stands up when the loop ends and at coop off.
    function self.stand()
        if not seated then return false,'EVE is not seated' end
        local n=seated.n
        rise('stand up')
        return true,string.format('seat %d: stood up',n)
    end
    -- The seat EVE sits on, or nil.
    function self.seated() return seated end
    -- Whether SB's interaction ran on EVE in a hall at the last pass (watch): an SB chair's Get up choice then takes
    -- Enter (UI_FaceButton_Bottom), so the chat leaves that press to the game.
    function self.busy() return interacting~=nil end
    -- What the lobby still waits for under the arrival's hold, as words: 'arrival' until the record reads arrived in a
    -- lobby, then 'spot' while EVE's teleport to her spot is due, 'chairs' before a hall's bind check and 'camera'
    -- before to_menu has the view; empty once all are done.
    function self.unready()
        local t=self.target()
        if not t then return {'arrival'} end
        local out={}
        if placing or want then out[#out+1]='spot' end
        if t.seats and not (chairs and chairs.spare) then out[#out+1]='chairs' end
        if not viewing then out[#out+1]='camera' end
        return out
    end
    return self
end
return Sbo
