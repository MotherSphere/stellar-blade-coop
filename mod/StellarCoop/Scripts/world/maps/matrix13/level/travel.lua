-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop mxiii (a test tool, experimental, left out of the usage line): SB's own camp travel into Zone_DLC02_10, the
-- first zone of the cut Matrix XIII area (WorldTable DLCMatrix13, ID 2800), and a camp there. No pak of the game
-- holds its map, /Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P, and no row of the game leads to its world. The zMXIII_P
-- test pak, built outside the mod and never shipped with it, adds a map at that path. On the game thread, in order: the
-- checks the travel needs, once a command (the follow's own guards: solo, a co-op save, the native travel there and
-- none under way; then the test pak, v5); the native part's mxiii rows batch (world/maps/matrix13/mxiii_rows.h, written
-- by tools/mxiii_rows.py from data/mxiii-world.json: the zone 10 camp DLC02_10_Camp_01 with DLC02_10_EnvS_900, which
-- leads the travel there and is the camp base, and its kit 901 to 906, which SB binds by name to the objects the pak
-- places in its MXIII_Camps_A level, as it does the zone 10 simple camp's 420, 421, 423 and 426; zone 30's
-- rest stop DLC02_30_Camp_01; 5 shipped ZoneTriggerTable rows patched in place, so the zone 20 waves and the zone 40
-- chains of spawns fire without the cut map's gates and drain devices; then the map's other camps, their kits and
-- coins, and zone 0's Tetrapod with Lily), added by SB's own row call with no logic task in flight,
-- through core/enemy.lua's rows flow (the tables, the ask, the wait, the read-back); then SB's camp travel to the
-- Tetrapod camp DLC02_00_Camp_00, beside Lily, through the follow's probe (online/group/travel.lua; the native part's
-- game/travel.h). The travel activates no camp: only a coin at a vending machine does. coop mxiii 30 is
-- the same with the travel to DLC02_30_Camp_01, which reaches the area's upper half without the zone 20 climb (it
-- runs on Matrix 11 triggers and sequences the test pak leaves out). Both ask nothing on a pak before v5: its two
-- zone 10 camps would have no kit. Each step logs an [MX] line, the travel's result a [TR] line. A warp into
-- a world the save has never been in may write that world into the save: main.lua lets it run on a co-op save only. The
-- rows stay for the game run; a second coop mxiii reads them back and travels again. The same batch goes in on its own
-- at the title, before any save loads, while the game uses the co-op save files and the test pak is there (title()
-- below), so a co-op save that names a mod camp or row (the respawn camp at FSBActor +0x26d0, the save's activated
-- camps and last camp rows) loads with them, and coop mxiii then only reads them back and travels. At the title the
-- other batches follow it, one after the other (Mxiii.BATCHES: the spawn rows, the loot, the mechanisms of zones 0 to
-- 2, 3 and 4, then the Lion's and the Gardener's own rows that the boss spawn rows name); coop mxiii asks no travel
-- until they all read rows. In world 2800 the tick spawns the ladders, ledges and ropes
-- (world/maps/matrix13/level/move.lua) and the boxes and barrels (world/maps/matrix13/level/breakables.lua), and fixes
-- the Lion and Gardener the game spawns (world/maps/matrix13/level/boss.lua); coop mxiii boss spawns the key-0 boss of
-- the arena EVE stands in. Each arrival in world 2800 runs the world's setup under SB's own black (the lobby's
-- LoadingScreenFadeAuto), lifted once the ladders, boxes and walks are done, so none of it shows in play. coop mxiii
-- warp lists the arrival points of the old warp switches. coop mxiii warp <n|name> puts EVE on one (a test
-- fallback: no switch stands in the map, as in Matrix 11). The way out is coop mxiii
-- leave: the follow's probe, under its guards and its activation read (game/camps.h), to a travel camp the read lists:
-- the camp EVE respawned at when coop mxiii asked its travel, else the one she respawns at now, else the read's first.
-- Her respawn camp is that of her last rest or fast-travel arrival (FSBActor +0x26d0): the arrival in the area
-- (FUN_141a8bef0) makes it DLC02_00_Camp_00, DLC02_10_Camp_01 or DLC02_30_Camp_01, which are in no travel table, and so
-- does a rest at the zone 10 camp.
-- The test pak's check makes no StaticFindObject (a package that is not loaded is never found that way, and each miss
-- costs 4 to 35 ms): the container's .utoc in SB/Content/Paks/~mods or LogicMods, read once a command, must name the
-- map's folders and MXIII_P.umap in its directory index (plain text in a .utoc that is not encrypted, as retoc writes
-- it), with its .pak and .ucas beside it (UE 4.26 mounts an IoStore container through its .pak). v2 is the pak whose
-- .ucas names the kit's spawn points: their FName base DLC02_10_EnvS (DLC02_10_EnvS_901 is that name with the number
-- 902) is in its MXIII_10_LD package's name map, plain text in an uncompressed container; v1 has no such name. v3 is
-- the pak whose .ucas names the zone 30 camp's spawn point DLC02_30_Camp_01 (in MXIII_30_LD's name map whole: FName
-- keeps a number written with a leading zero as text); v1 and v2 have no such name. v4 is the pak whose .ucas names the
-- Tetrapod camp's spawn point DLC02_00_Camp_00, and v5 a v4 pak whose .utoc also names MXIII_Camps_A.umap, the level
-- that places the two zone 10 camps' kits, in its directory index.
-- shortcut: the live folder, not what the engine mounted at start, so a pak copied in while the game runs passes;
-- upgrade to the native part's start list (link/pak_list.h) if that happens in a test.
-- The .ucas is read in windows of 16 MB up to its end as the .utoc's compression blocks give it (the header's block
-- count and entry size, after the chunk IDs and offsets; UE 4.26's FIoStoreTocHeader, version 2 as retoc writes it),
-- so a full map's container of 30 MB or more is read whole, never more than a window at a time, and the reads stop
-- once both names are found. A .utoc whose header does not read as one gives the first window only.
-- shortcut: an Oodle-compressed container (a compression method in the .utoc) reads as v1 or as what its compressed
-- bytes happen to hold; retoc writes ours uncompressed.
local U=require('core.unreal')
local Enemy=require('core.enemy')
local PakGate=require('core.pak_gate')
local Mxiii={}
Mxiii.CAMP='DLC02_10_Camp_01'
Mxiii.ARRIVAL='DLC02_00_Camp_00' -- coop mxiii's camp, and the name of its spawn point from the v4 pak on.
Mxiii.CAMP30='DLC02_30_Camp_01' -- coop mxiii 30's camp, and the name of its spawn point from the v3 pak on.
Mxiii.EXIT='coop mxiii leave'
Mxiii.PAK='zMXIII_P'
Mxiii.MAP='MXIII_P.umap'
-- The directory index's names of the WorldTable path /Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P, the map last.
Mxiii.INDEX={'WorldMap_DLC_01','Level_P',Mxiii.MAP}
-- SB's black over world 2800's setup: s a tick while it hides the frames (Sbo.HELD_BUDGET's); its fades (SB's own black
-- fade); SB's own end of it after its fade-in; only for a world younger than FRESH s; s between reads of EVE's world by
-- the tick, which runs each frame in every world.
Mxiii.HELD_BUDGET,Mxiii.FADE,Mxiii.LIFETIME,Mxiii.FRESH,Mxiii.LOOK=0.1,0.5,10,20,0.25
Mxiii.KIT='DLC02_10_EnvS'
-- The level whose placed actors the zone 10 camps' 11 kit rows bind, in the directory index from the v5 pak on.
Mxiii.CAMPS_MAP='MXIII_Camps_A.umap'
-- What the checks line says of each test pak: the camp's spawn point, where SB's arrival puts EVE.
Mxiii.VERSIONS={
    'v1 (no '..Mxiii.KIT..' point in its .ucas: the camp has no objects; arrival at the dungeon start, 40368 35663 '
        ..'-846)',
    'v2 ('..Mxiii.KIT..' points in its .ucas: the zone 10 camp kit stood at them on paks v2 to v4; arrival at the kit, '
        ..'36624 16140 -2136)',
    'v3 ('..Mxiii.CAMP30..' point in its .ucas: v2 and a zone 30 camp with no kit; coop mxiii 30 arrives at 26392 '
        ..'-23650 4414)',
    'v4 ('..Mxiii.ARRIVAL..' point in its .ucas: coop mxiii arrives beside Lily at the Tetrapod, 38290 36221 715)',
    'v5 ('..Mxiii.CAMPS_MAP..' in its .utoc: v4, and the zone 10 camp kits are placed objects of MXIII_Camps_A)'}
Mxiii.WINDOW=1<<24 -- Bytes a read of the .ucas takes: v1's is 793 KB, with the names 9 KB in; v3's 2.2 MB.
local OVERLAP=64 -- Bytes each window repeats of the last one, so a name across two windows is found.
-- The .ucas's size as the .utoc's compression blocks give it (core/pak_gate.lua's, shared with the hall lobby pak).
Mxiii.ucas_size=PakGate.ucas_size
-- SB lists every camp's env-spawn rows in FSBGameWorld::Init (FUN_141c98ef0 makes the zone manager, whose setup runs
-- FUN_141d1a310 over ZoneEnvSpawnTable), so the world the rows went in on may know neither camp until the next one
-- (not when they went in at the title). Read from the code. In game on 2026-10-27 (build v0.6.0-beta.3-250-g51dbdf1)
-- SB refused the first travel and took it after a reload. On 2026-11-18 (build v0.11.0-277-gd9bb23bf, v5 pak) the
-- first world after the title took it: the save loaded at 10:37:20, Lily's pick asked the travel to DLC02_00_Camp_00
-- at 10:39:01 and it arrived at 10:39:10 (UE4SS.log times). command() asks only on v5 and once the seven batches that
-- go in at the title only read rows.
local function hint(camp,command)
    return 'if [TR] says SB refused '..camp..': SB lists the camps when its world starts, maybe before these rows; '
        ..'load the save or travel to a camp, then run '..command..' again (the rows stay in)'
end
-- The rows as core/enemy.lua reads them back: world/maps/matrix13/level/rows.lua, which tools/mxiii_rows.py writes from
-- data/mxiii-world.json with world/maps/matrix13/mxiii_rows.h (world/maps/matrix13/level/travel_test checks the two
-- agree). The mxiii batch holds the camps and what they need (their env rows, coins, zone 0's Tetrapod and Lily); the
-- dev rows come first, in their order.
local Rows=require('world.maps.matrix13.level.rows')
Mxiii.ROWS=Enemy.rows(Rows.MXIII)
-- coop mxiii warp's points: the arrival points the cooked map keeps from the removed warp switches.
Mxiii.WARP=Rows.WARP
-- A point by its number in the list or by its name (any case), or nil.
function Mxiii.warp_point(point)
    local n=math.tointeger(tonumber(point))
    for _,w in ipairs(Mxiii.WARP) do
        if w.n==n or w.name:lower()==tostring(point):lower() then return w end
    end
    return nil
end
-- The other batches, each its own ask: Matrix XIII's spawn rows, loot (supply boxes and pickups) with the device
-- rows dev patched first, the doors, gates, lifts, arena locks and water of zones 0 to 2, of zone 3 and of zone 4
-- (world/maps/matrix13/mxiii_rows.h), then the Lion's and the Gardener's own batches, whose CharacterTable rows M_LionC
-- and M_Gardener the boss spawn rows name, then Lily's menu in this world, then the camps' display keys. At the title
-- they go in once the mxiii rows are in, one after the other, and coop mxiii travels only once every one of them but an
-- optional one reads rows.
-- optional: the travel never waits for it. ready: the title asks it only when this holds on the status text, here once
-- the native part has made the keys' entries (game/camp_text.h), so a row can never name a key with no text: SB would
-- show <key>. A fault, or a table that never loads, leaves the rows with their donors' names.
Mxiii.BATCHES={
    {word='mxspawn',name='Matrix XIII Naytiba',rows=Enemy.rows(Rows.MXSPAWN)},
    {word='mxenv',name='Matrix XIII loot',rows=Enemy.rows(Rows.MXENV)},
    {word='mxupper',name='Matrix XIII zones 0 to 2 mechanism',rows=Enemy.rows(Rows.MXUPPER)},
    {word='mxmiddle',name='Matrix XIII zone 3 mechanism',rows=Enemy.rows(Rows.MXMIDDLE)},
    {word='mxlower',name='Matrix XIII zone 4 mechanism',rows=Enemy.rows(Rows.MXLOWER)},
    {word='lion',name='Lion',rows=Enemy.rows(require('world.maps.matrix13.level.boss_rows').ROWS)},
    {word='gardener',name='Gardener',rows=Enemy.rows(require('world.maps.matrix13.level.boss_rows').GARDENER)},
    {word='mxlily',name='Lily at the Matrix XIII Tetrapod',rows=Enemy.rows(Rows.MXLILY),optional=true},
    {word='mxnames',name='Matrix XIII camp names',rows=Enemy.rows(Rows.MXNAMES),optional=true,ready=function(status)
        local s=Enemy.parse(status,'camptext')
        return s~=nil and s.state=='ready'
    end},
    -- The 25 records (data/mxiii-world.json): their puzzle text rows, unlocks, Data Bank rows and env rows at the map's
    -- spawn points. Waits for game/camp_text.h's words, and loads StringTable_Records once for them: nothing else may
    -- have loaded it at the title. At the title on the co-op save files only, with the test pak only, like every batch
    -- here. Reading a record is the game's own path: env state CallPuzzle completes the unlock [inference: no row added
    -- at run time has fired an achievement yet]. Its unlocks progress no trophy.
    {word='mxrecords',name='Matrix XIII records',rows=Enemy.rows(Rows.MXRECORDS),optional=true,ready=function(status)
        local s=Enemy.parse(status,'recordtext')
        if s and s.state=='wait' and not Mxiii.records_loaded then
            Mxiii.records_loaded=true
            pcall(require('core.actors').resolve,'/Game/Local/Localize/StringTable_Records.StringTable_Records',
                '/Script/CoreUObject.Object')
        end
        local names=Enemy.parse(status,'camptext') -- The memorystick group's header is the camp names' MX13_Region.
        return s~=nil and s.state=='ready' and names~=nil and names.state=='ready'
    end},
}
Mxiii.paks_of=PakGate.paks_of
-- The test pak's .utoc that names the map, beside its .pak and .ucas (core/pak_gate.lua's container), and its version
-- (1 to 5), or nil and why. paks: SB/Content/Paks (nil: unknown); read(path, limit, offset): core/link.lua's files.read
-- (the text, or nil when the file cannot be opened).
function Mxiii.find_map(paks,read)
    local path,text,first=PakGate.container(paks,read,Mxiii.PAK,Mxiii.INDEX,Mxiii.WINDOW)
    if not path then return nil,text end
    -- The .ucas, window after window (the first one read by the container), while a name is still unseen.
    local ucas,size=path:sub(1,-6)..'.ucas',Mxiii.ucas_size(text) or Mxiii.WINDOW
    local arrival,camp30,kit,at=false,false,false,0
    repeat
        local window=at==0 and first or read(ucas,Mxiii.WINDOW,at) or ''
        arrival=arrival or window:find(Mxiii.ARRIVAL,1,true)~=nil
        camp30=camp30 or window:find(Mxiii.CAMP30,1,true)~=nil
        kit=kit or window:find(Mxiii.KIT,1,true)~=nil
        at=at+Mxiii.WINDOW-OVERLAP
    until (arrival and camp30 and kit) or at>=size or #window<Mxiii.WINDOW
    local version=arrival and 4 or camp30 and 3 or kit and 2 or 1
    return path,version==4 and text:find(Mxiii.CAMPS_MAP,1,true) and 5 or version
end

-- o: log (the [MX] lines), ask(line) the native request, status() the native status text, travel() the follow
-- (online/group/travel.lua's, nil without the Steam link), paks (SB/Content/Paks, nil when unknown), read (files.read).
-- The tests replace: here() (EVE in world 2800), parts ({move=,breakables=,boss=,drone=,fans=} in place of the made
-- ones), black() (puts up SB's black; raises when it cannot), world_time(eve) (the world's real time in s).
function Mxiii.new(o)
    local log=o.log
    local e=Enemy.new({log=log,ask=o.ask,status=o.status},
        {word='mxiii',name='Matrix XIII',command='coop mxiii',tag='[MX]',rows=Mxiii.ROWS,ids={}})
    local self={}
    -- The travel camp EVE respawned at when coop mxiii last asked its travel: once there, she respawns at Matrix XIII.
    -- shortcut: kept in this Lua state only, so a Lua reload in the area loses it and leave takes the read's first
    -- camp; upgrade to a native read of a camp the arrival leaves alone if a test needs it.
    local back=nil
    -- Once the rows are in (ok, message: the rows flow's end): the camp travel to camp, coop mxiii's or coop mxiii
    -- 30's (command), through the follow's probe.
    local function warp(camp,command,ok,message)
        if not ok then return false,(tostring(message):gsub(': no spawn%.$',': no travel.')) end
        local travel=o.travel()
        if not travel then return false,command..': no follow to travel with (the Steam link is gone)' end
        local camps,rested=travel.camps() -- No read, or a respawn camp in no travel table: back stays as it was.
        for _,alias in ipairs(camps or {}) do if alias==rested then back=rested end end
        local asked,said=travel.probe(camp,true)
        log('travel to '..camp..(asked and ' asked: ' or ' refused: ')..tostring(said))
        if not asked then return false,command..': the rows are in, but no travel: '..tostring(said) end
        log(hint(camp,command))
        return true,command..': the rows are in and the travel to '..camp..' is asked ([TR] lines follow); way out: '
            ..Mxiii.EXIT
    end
    -- coop mxiii leave: back, else the camp EVE respawns at, when the read lists it among its travel camps, else the
    -- read's first travel camp.
    local function leave()
        local travel=o.travel()
        if not travel then return false,'coop mxiii leave needs the Steam link' end
        local camps,rested=travel.camps()
        if not camps then
            return false,'coop mxiii leave: no read of the camps this save has activated ('..tostring(rested)..')'
        end
        local pick=camps[1]
        for _,alias in ipairs(camps) do if alias==rested then pick=alias end end
        for _,alias in ipairs(camps) do if alias==back then pick=alias end end
        if not pick then return false,'coop mxiii leave: this save has activated none of the 120 travel camps' end
        local asked,said=travel.probe(pick)
        log('leave: travel to '..pick..(pick==back and ', the camp EVE respawned at before coop mxiii,'
            or pick==rested and ', the camp EVE respawns at,' or '')
            ..(asked and ' asked: ' or ' refused: ')..tostring(said))
        if not asked then return false,'coop mxiii leave: '..tostring(said) end
        return true,'coop mxiii leave: the travel to '..pick..' is asked ([TR] lines follow)'
    end
    -- coop mxiii [30]: the checks, the rows, then the travel to the Tetrapod camp, or with 30 to the zone 30 camp.
    function self.command(extra,point)
        if extra=='leave' then return leave() end
        if extra=='boss' then return self.boss() end
        if extra=='warp' then return self.warp(point) end
        if extra~=nil and extra~='30' then return false,'Use: coop mxiii [30|leave|boss|warp [n|name]]' end
        local camp,command=Mxiii.ARRIVAL,'coop mxiii'
        if extra then camp,command=Mxiii.CAMP30,'coop mxiii 30' end
        local busy=e.busy()
        if busy then return false,busy end
        local travel=o.travel()
        if not travel then return false,command..' needs the Steam link' end
        local ready,why=travel.ready()
        if not ready then
            log('refused: '..tostring(why))
            return false,command..': '..tostring(why)..': nothing was asked'
        end
        local map,said=Mxiii.find_map(o.paks,o.read) -- said: its version, or why there is none.
        if not map then
            log('refused: no test pak: '..said)
            return false,command..' needs the zMXIII_P test pak in Paks\\~mods or Paks\\LogicMods ('..said
                ..'): nothing was asked'
        end
        log('checks: solo on a co-op save, the native travel idle, '..map..' holds '..table.concat(Mxiii.INDEX,'/')
            ..' beside its .pak and .ucas; test pak '..Mxiii.VERSIONS[said])
        -- The zone 10 camps' 11 kit rows set no EnvBPPath, so SB binds each to the placed actor whose EnvActorName
        -- equals the row's (FUN_141d207c0 calls FUN_142281550). Before v5 no placed actor holds those names: the miss
        -- makes a new GUID there, so FUN_141d207c0 still makes the env object, with no actor and no "++ Fail" line.
        -- Each version holds the spawn points of the ones before it, so v5 has both commands' camps.
        if said<5 then
            log('refused: test pak v'..said..' has no '..Mxiii.CAMPS_MAP)
            return false,command..' needs the v5 zMXIII_P test pak: '..map..' is v'..said..', with no '..Mxiii.CAMPS_MAP
                ..' for the zone 10 camps\' objects: nothing was asked'
        end
        -- The other batches go in at the title only. Without them world 2800 has no Naytibas, loot, doors, gates or
        -- lifts, and a peer's shared Naytibas match no spawn row.
        for _,b in ipairs(Mxiii.BATCHES) do
            local s=Enemy.parse(o.status and o.status(),b.word)
            if not b.optional and not (s and s.state=='rows') then
                log('refused: '..b.word..' rows not in')
                return false,command..': the '..b.name..' rows are not in ('..(s and s.state or 'no line')
                    ..'): return to the title with the co-op save files, then run '..command..' again'
            end
        end
        return e.rows(function(ok,message) return warp(camp,command,ok,message) end)
    end
    -- The title's batch (core/enemy.lua's title_batch): while the game uses the co-op save files and the test pak is
    -- there (looked for once a Lua load; with none there is nothing to add, and nothing is said: most players have
    -- none). A pak before v5 gets the rows all the same, for a co-op save that names them, and one line says so.
    local pak=nil
    local function ready()
        if pak==nil then
            pak=select(2,Mxiii.find_map(o.paks,o.read))
            if type(pak)=='number' and pak<5 then
                log('title: test pak v'..pak..' has no '..Mxiii.CAMPS_MAP..': the rows go in, but the two zone 10 '
                    ..'camps will have no kit, and coop mxiii refuses this pak')
            end
        end
        return type(pak)=='number' and 'the co-op save files and test pak v'..pak or nil
    end
    local title,title_stop=e.title_batch(ready,'coop mxiii')
    -- The other batches at the title, each once the batch before it has an answer (its line reads rows, or refused:
    -- a refusal in one never holds the others back), so one ask runs at a time and the mxiii rows keep the first one.
    -- An optional batch holds no batch back: the ones after it wait for the batch before it, and for its ask to end.
    local others,previous={},'mxiii'
    for _,b in ipairs(Mxiii.BATCHES) do
        local x=Enemy.new({log=function(m) log(b.word..' '..m) end,ask=o.ask,status=o.status},
            {word=b.word,name=b.name,command='coop mxiii',tag='[MX]',rows=b.rows,ids={}})
        local t,stop=x.title_batch(ready,'a return to the title')
        others[#others+1]={e=x,title=t,stop=stop,after=previous,ready=b.ready}
        if not b.optional then previous=b.word end
    end
    -- The ladders, ledges and ropes (world/maps/matrix13/level/move.lua), the boxes and barrels
    -- (world/maps/matrix13/level/breakables.lua) and the bosses the game spawns (world/maps/matrix13/level/boss.lua),
    -- in world 2800 only. boss.lua and fans.lua find an object again by its path (a name-hash find, never a walk).
    local parts=o.parts or {}
    local function find(p) return (U.object_at(p,U.controller())) end
    local move=parts.move or require('world.maps.matrix13.level.move').new({log=function(m) log('[MXMOVE] '..m) end})
    local breakables=parts.breakables
        or require('world.maps.matrix13.level.breakables').new({log=function(m) log('[MXBREAK] '..m) end})
    local boss=parts.boss or require('world.maps.matrix13.level.boss').new({log=function(m) log('[MXBOSS] '..m) end,
        lion=o.lion,gardener=o.gardener,find=find})
    function self.title(at_title,coop)
        title(at_title,coop)
        local busy=false
        for _,x in ipairs(others) do
            local s=Enemy.parse(o.status and o.status(),x.after)
            -- Before x.title: a title_batch whose own ready says no never asks again.
            if not busy and s and (s.state=='rows' or s.state=='refused')
                and (not x.ready or x.ready(o.status and o.status())) then
                x.title(at_title,coop)
            end
            busy=busy or x.e.busy()
        end
    end
    -- coop mxiii boss: the key-0 boss of the arena EVE stands in, when the game spawned none there.
    self.boss=boss.command
    -- EVE when she stands in world 2800 (world/maps/matrix13/level/move.lua's map check), else nil; o.here replaces it
    -- in the tests.
    local here=o.here or function()
        local N=require('core.player')
        local ok,eve=pcall(function()
            local x=U.valid(N.her())
            local map=x and U.map_of(x)
            local want=require('world.maps.matrix13.level.move').MAP
            return map and map:sub(-#want)==want and x or nil
        end)
        return ok and eve or nil
    end
    local drone=parts.drone
        or require('world.maps.matrix13.level.drone').new({log=function(m) log('[MXDRONE] '..m) end,here=here})
    local fans=parts.fans
        or require('world.maps.matrix13.level.fans').new({log=function(m) log('[MXFAN] '..m) end,here=here,find=find})
    local black=nil -- {world=<address>, at=<os.clock of the call>, up=}
    local primed=nil -- The world the walks were primed in.
    -- here()'s last read (its os.clock, EVE, her world's address): it makes reflected calls, so once every LOOK s.
    local seen_at,seen_eve,seen_w=-math.huge,nil,nil
    -- UGameplayStatics::GetRealTimeSeconds (exec 0x14475baa0: the context's world, then its RealTimeSeconds at +0x750).
    local world_time=o.world_time or function(eve)
        return U.find('/Script/Engine.Default__GameplayStatics'):GetRealTimeSeconds(eve)
    end
    -- As the lobby's hold (online/lobby/wiring.lua): USBBlueprintLibrary::LoadingScreenFadeAuto (exec 0x1426641e0) with
    -- its lifetime, start fade, end fade and tag 5 Load, which the native lift ends.
    local put_up=o.black or function()
        local sb=U.find('/Script/SB.Default__SBBlueprintLibrary')
        sb:LoadingScreenFadeAuto(Mxiii.LIFETIME,Mxiii.FADE,0,1,Mxiii.FADE,1,0,5)
    end
    -- At the first look in a new world 2800 younger than FRESH s (SB's travel screen still shows), SB's black up; SB
    -- ends it itself LIFETIME s later. EVE and her world's address as of the last look, or nil out of world 2800.
    local function arrival(now)
        if now-seen_at>=Mxiii.LOOK then
            seen_at=now
            local eve=here()
            local ok,w=pcall(function() return eve and U.address(eve:GetWorld()) end)
            seen_eve,seen_w=eve,ok and w or nil
        end
        local eve,w=seen_eve,seen_w
        if not w then
            black=nil
            return nil
        end
        if not black or black.world~=w then
            local read,t=pcall(world_time,eve)
            black={world=w,at=now,up=false}
            if read and type(t)=='number' and t<Mxiii.FRESH then
                local shown,e=pcall(put_up)
                black.up=shown
                log(shown and "arrival: SB's black up for world 2800's setup"
                    or "arrival: SB's black not shown ("..tostring(e).."): the setup goes on in play")
            end
        end
        if black.up and now-black.at>=Mxiii.LIFETIME then
            black.up=false
            log(string.format("arrival: SB's black ended by itself after %d s; the setup goes on in play",
                Mxiii.LIFETIME))
        end
        return eve,w
    end
    -- SB's black is up over world 2800's setup (world/maps/matrix13/quest/on_time.lua waits while it is).
    function self.held() return black~=nil and black.up end
    -- coop mxiii warp [n|name]: the list, or EVE put on that arrival point, under the follow's guards (solo, a co-op
    -- save, no travel under way) and in world 2800 only.
    function self.warp(point)
        if point==nil then
            for _,w in ipairs(Mxiii.WARP) do log(string.format('warp %d %s (%s)',w.n,w.name,w.mover)) end
            return true,'coop mxiii warp: '..#Mxiii.WARP..' points listed in the log; coop mxiii warp <n|name> goes '
                ..'to one'
        end
        local w=Mxiii.warp_point(point)
        if not w then return false,'coop mxiii warp: no point '..tostring(point)..' (coop mxiii warp lists them)' end
        local travel=o.travel()
        if not travel then return false,'coop mxiii warp needs the Steam link' end
        local ready,why=travel.ready()
        if not ready then return false,'coop mxiii warp: '..tostring(why) end
        local eve=here()
        if not eve then return false,'coop mxiii warp works in Matrix XIII only' end
        local at={X=w.at[1],Y=w.at[2],Z=w.at[3]}
        local refused=eve:K2_TeleportTo(at,{Pitch=0,Yaw=w.yaw,Roll=0})==false
        log(string.format('warp %d %s (%s) to %.0f %.0f %.0f yaw %.0f%s',w.n,w.name,w.mover,at.X,at.Y,at.Z,w.yaw,
            refused and ': the game refused the teleport' or ''))
        if refused then return false,'coop mxiii warp: the game refused the teleport to '..w.name end
        return true,'coop mxiii warp: EVE is at '..w.name..' ('..w.mover..')'
    end
    function self.tick()
        local ok,message=e.tick()
        for _,x in ipairs(others) do x.e.tick() end
        local now=os.clock()
        local _,w=arrival(now)
        local held=self.held()
        if not (held and now-black.at<Mxiii.FADE) then -- Nothing runs while the black fades in.
            if held and primed~=w then
                primed=w
                local fresh=here() -- Read now: the last look's EVE may be up to LOOK s old.
                boss.prime(fresh)
                fans.prime(fresh)
            end
            local budget=held and Mxiii.HELD_BUDGET or nil
            -- One spawn a frame over both lists in play: each spends 4 ms a tick. A ladder (10 to 13 ms) and a box
            -- (8 to 13 ms) in one frame took it to 18 to 26 ms, so the boxes and barrels wait while the ladders spawn.
            if not move.tick(budget) then breakables.tick(budget) end
            if held and move.done(w) and breakables.done(w) then
                black.up=false
                local lifted,why=o.ask('loading lift')
                log(string.format("arrival: SB's black lifted after %.1f s, world 2800's setup done%s",now-black.at,
                    lifted and '' or string.format(' (the lift: %s; SB ends its black within %d s)',tostring(why),
                        Mxiii.LIFETIME)))
            end
        end
        boss.tick()
        drone.tick()
        fans.tick()
        return ok,message
    end
    -- coop off ends the waits without their end, so a title batch asked is free to ask again at the next call.
    function self.stop()
        drone.stop()
        title_stop()
        for _,x in ipairs(others) do
            x.stop()
            x.e.stop()
        end
        return e.stop()
    end
    return self
end
return Mxiii
