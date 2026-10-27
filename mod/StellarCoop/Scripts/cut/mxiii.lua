-- coop mxiii (a test tool, experimental, left out of the usage line): SB's own camp travel into Zone_DLC02_10, the
-- first zone of the cut Matrix XIII dungeon (WorldTable DLCMatrix13, ID 2800), and a camp there. No pak of the game
-- holds its map, /Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P, and no row of the game leads to its world. The zMXIII_P
-- test pak, built outside the mod and never shipped with it, adds a map at that path. On the game thread, in order: the
-- checks the travel needs, once a command (the follow's own guards: solo, a co-op save, the native travel there and
-- none under way; then the test pak, v1, v2 or v3); the native part's mxiii rows batch (lion/rows.h: the 8 rows of the
-- camp, ZoneCampTable DLC02_10_Camp_01, then 7 ZoneEnvSpawnTable rows in Zone_DLC02_10 whose TargetCamp names it:
-- DLC02_10_EnvS_900, which leads the travel there, and the kit 901 to 906, which SB spawns at the v2 pak's spawn points
-- of those names, through the game's own row call with no logic task in flight; then zone 30's camp with no kit,
-- DLC02_30_Camp_01 and its row DLC02_30_EnvS_900 in Zone_DLC02_30; then 5 shipped ZoneTriggerTable rows patched in
-- place, so the zone 20 waves and the zone 40 chains of spawns fire without the cut map's gates and drain devices),
-- through cut/enemy.lua's rows flow (the tables, the ask, the wait, the read-back); then SB's camp travel to
-- DLC02_10_Camp_01 through the follow's probe (session/travel.lua; the native part's game/travel.h). coop mxiii 30 is
-- the same with the travel to DLC02_30_Camp_01, which reaches the dungeon's upper half without the zone 20 climb (it
-- runs on Matrix 11 triggers and sequences the test pak leaves out); it needs the v3 pak, the only one with that camp's
-- spawn point, and asks nothing on v1 or v2. Each step logs an [MX] line, the travel's result a [TR] line. A warp into
-- a world the save has never been in may write that world into the save: main.lua lets it run on a co-op save only. The
-- rows stay for the game run; a second coop mxiii reads them back and travels again. The same batch goes in on its own
-- at the title, before any save loads, while the game uses the co-op save files and the test pak is there (title()
-- below), so a co-op save that names a mod camp or row (the respawn camp at FSBActor +0x26d0, the save's activated
-- camps and last camp rows) loads with them, and coop mxiii then only reads them back and travels. The way out is
-- coop mxiii leave: the follow's probe, under its guards and its activation read (game/camps.h), to a travel camp the
-- read lists: the camp EVE respawned at when coop mxiii asked its travel, else the one she respawns at now, else the
-- read's first. Her respawn camp is that of her last rest or fast-travel arrival (FSBActor +0x26d0): the arrival in
-- the dungeon (FUN_141a8afe0) makes it DLC02_10_Camp_01 or DLC02_30_Camp_01, which are in no travel table, and so does
-- a rest at the zone 10 camp.
-- The test pak's check makes no StaticFindObject (a package that is not loaded is never found that way, and each miss
-- costs 4 to 35 ms): the container's .utoc in SB/Content/Paks/~mods or LogicMods, read once a command, must name the
-- map's folders and MXIII_P.umap in its directory index (plain text in a .utoc that is not encrypted, as retoc writes
-- it), with its .pak and .ucas beside it (UE 4.26 mounts an IoStore container through its .pak). v2 is the pak whose
-- .ucas names the kit's spawn points: their FName base DLC02_10_EnvS (DLC02_10_EnvS_901 is that name with the number
-- 902) is in its MXIII_10_LD package's name map, plain text in an uncompressed container; v1 has no such name. v3 is
-- the pak whose .ucas names the zone 30 camp's spawn point DLC02_30_Camp_01 (in MXIII_30_LD's name map whole: FName
-- keeps a number written with a leading zero as text); v1 and v2 have no such name.
-- shortcut: the live folder, not what the engine mounted at start, so a pak copied in while the game runs passes;
-- upgrade to the native part's start list (game/pak_list.h) if that happens in a test.
-- shortcut: the .ucas's first 16 MB, uncompressed as retoc writes it; an Oodle-compressed container, or one whose
-- MXIII_10_LD or MXIII_30_LD lies past 16 MB, reads as an older version. Upgrade to the .utoc's chunk offsets if a
-- build does either.
local Enemy=require('cut.enemy')
local Mxiii={}
Mxiii.CAMP='DLC02_10_Camp_01'
Mxiii.CAMP30='DLC02_30_Camp_01' -- coop mxiii 30's camp, and the name of its spawn point in the v3 pak.
Mxiii.EXIT='coop mxiii leave'
Mxiii.PAK='zMXIII_P'
Mxiii.MAP='MXIII_P.umap'
-- The directory index's names of the WorldTable path /Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P, the map last.
Mxiii.INDEX={'WorldMap_DLC_01','Level_P',Mxiii.MAP}
Mxiii.DIRS={'~mods','LogicMods'}
Mxiii.KIT='DLC02_10_EnvS'
-- What the checks line says of each test pak: the camp's spawn point, where SB's arrival puts EVE.
Mxiii.VERSIONS={
    'v1 (no '..Mxiii.KIT..' point in its .ucas: the camp has no objects; arrival at the dungeon start, 40368 35663 '
        ..'-846)',
    'v2 ('..Mxiii.KIT..' points in its .ucas: the camp kit stands at the spawn points; arrival at the kit, 36624 16140 '
        ..'-2136)',
    'v3 ('..Mxiii.CAMP30..' point in its .ucas: v2 and a zone 30 camp with no kit; coop mxiii 30 arrives at 26392 '
        ..'-23650 4414)'}
local LIMIT=1<<20 -- Bytes read of a .utoc: its directory index comes last, under 1 KB for the test pak's two maps.
local UCAS=1<<24 -- Bytes read of a .ucas: v1's is 793 KB, with the names 9 KB in; v3's 2.2 MB.
-- SB lists every camp's env-spawn rows in FSBGameWorld::Init (FUN_141c97ca0 makes the zone manager, whose setup runs
-- FUN_141d18100 over ZoneEnvSpawnTable), so the world the rows went in on may know neither camp until the next one
-- (not when they went in at the title). Read from the code, untested.
local function hint(camp,command)
    return 'if [TR] says SB refused '..camp..': SB lists the camps when its world starts, maybe before these rows; '
        ..'load the save or travel to a camp, then run '..command..' again (the rows stay in)'
end
-- The rows as cut/enemy.lua reads them back (rows.h's kMxiiiRecipe and kMxiiiPatches; mxiii_test checks them against
-- it). The camp copies ME01_Camp_03 (a FullCamp, shown in the camp list once activated) with the coin's spawn point;
-- DLC02_10_EnvS_900 copies the kit's activation-only row DLC02_10_EnvS_425 (ZoneList Zone_DLC02_10) under its own actor
-- name, with the new camp; each kit row copies its kit row (420 to 424, then the vending machine 426) and spawns its
-- blueprint at the spawn point of its own name; the vending machine switches the other five kit objects on once
-- activated (not 900, which has no object). Zone 30's camp copies ME03_Camp_03 (a FullCamp with no coin) and its row
-- is DLC02_10_EnvS_900's recipe in Zone_DLC02_30. The trigger rows are SB's own, so their read-back proves the patch:
-- none of those values is the shipped one.
local ENV='/Game/GameDesign/Level/ZoneEnv/'
local function kit(n,blueprint,links)
    local name='DLC02_10_EnvS_'..n
    local checks={{'EnvActorName','n',name,true},{'EnvBPPath','s',ENV..blueprint,true},
        {'SpawnPointName','n',name,true},{'TargetCamp','n',Mxiii.CAMP,true}}
    if links then checks[#checks+1]={'LinkEnvSpawnList','N',links,true} end
    return {'ZoneEnvSpawnTable',name,2800032000+n,checks}
end
-- The shipped trigger rows patched in place, under their shipped IDs: zone 20's three touch their wave's zone events
-- (DLC02_20_ZoneE_022 to 032, which the cut gates ran) after the events they ship with; zone 40's two start enabled
-- (InitActivate 1, shipped 2) instead of waiting for the drain devices.
local function trigger(zone,n,touch)
    local checks=touch and {{'TouchEvents','N',touch,true}} or {{'InitActivate','e',1,true}}
    return {'ZoneTriggerTable',string.format('DLC02_%d_ZTrigger_%03d',zone,n),(zone==20 and 280501000 or 281501000)+n,
        checks}
end
Mxiii.ROWS=Enemy.rows({
    {'ZoneCampTable',Mxiii.CAMP,280001,
        {{'CampType','e',3,false},{'CoinSpawnPointName','n','DLC02_10_E_ItemS_001',true}}},
    {'ZoneEnvSpawnTable','DLC02_10_EnvS_900',2800032900,
        {{'EnvActorName','n','DLC02_10_EnvS_900',true},{'TargetCamp','n',Mxiii.CAMP,true}}},
    kit(901,'Env_Camp_SkillMachine.Env_Camp_SkillMachine_C'),
    kit(902,'Env_Camp_Chair.Env_Camp_Chair_C'),
    kit(903,'Env_Camp_Storage.Env_Camp_Storage_C'),
    kit(904,'Env_Camp_Turntable.Env_Camp_Turntable_C'),
    kit(905,'Env_Camp_TeleportMachine.Env_Camp_TeleportMachine_C'),
    kit(906,'Env_VendingMachine.Env_VendingMachine_C',
        'DLC02_10_EnvS_901|DLC02_10_EnvS_902|DLC02_10_EnvS_903|DLC02_10_EnvS_904|DLC02_10_EnvS_905'),
    {'ZoneCampTable',Mxiii.CAMP30,281001,{{'CampType','e',3,false}}},
    {'ZoneEnvSpawnTable','DLC02_30_EnvS_900',2810032900,
        {{'ZoneList','N','Zone_DLC02_30',true},{'EnvActorName','n','DLC02_30_EnvS_900',true},
            {'TargetCamp','n',Mxiii.CAMP30,true}}},
    trigger(20,1,'DLC02_20_ZoneE_022|DLC02_20_ZoneE_023|DLC02_20_ZoneE_024|DLC02_20_ZoneE_025'),
    trigger(20,5,'DLC02_20_E_EnvC_030|DLC02_20_ZoneE_026|DLC02_20_ZoneE_027|DLC02_20_ZoneE_028'),
    trigger(20,6,'DLC02_20_E_EnvC_031|DLC02_20_ZoneE_029|DLC02_20_ZoneE_030|DLC02_20_ZoneE_031|DLC02_20_ZoneE_032'),
    trigger(40,1),
    trigger(40,2),
})
-- SB/Content/Paks from the mod's folder (...\SB\Binaries\Win64\[ue4ss\]Mods\StellarCoop), or nil.
function Mxiii.paks_of(folder)
    local sb=type(folder)=='string' and folder:match('^(.*)[\\/][Bb]inaries[\\/][Ww]in64[\\/]')
    return sb and sb..'\\Content\\Paks' or nil
end
-- The test pak's .utoc that names the map, beside its .pak and .ucas, and its version (1, 2 or 3), or nil and why.
-- paks: SB/Content/Paks (nil: unknown); read(path, limit): core/link.lua's files.read (the text, or nil when the file
-- cannot be opened).
function Mxiii.find_map(paks,read)
    if not paks then return nil,'the game folder is unknown (the mod folder is not under SB\\Binaries\\Win64)' end
    local tried={}
    for _,dir in ipairs(Mxiii.DIRS) do
        local path=paks..'\\'..dir..'\\'..Mxiii.PAK..'.utoc'
        local text=read(path,LIMIT)
        if text then
            for _,name in ipairs(Mxiii.INDEX) do
                if not text:find(name,1,true) then return nil,path..' does not hold '..name end
            end
            local got={}
            for _,ext in ipairs({'.pak','.ucas'}) do
                local other=path:sub(1,-6)..ext
                got[ext]=read(other,ext=='.ucas' and UCAS or 1)
                if not got[ext] then return nil,'no '..other..' beside '..path end
            end
            local ucas=got['.ucas']
            return path,ucas:find(Mxiii.CAMP30,1,true) and 3 or ucas:find(Mxiii.KIT,1,true) and 2 or 1
        end
        tried[#tried+1]=path
    end
    return nil,'no '..table.concat(tried,' or ')
end

-- The title's batch: asks at most TRIES times a visit of the title, each RETRY s after the last answer, while the gate
-- stays shut. GATE: the refusals of a gate that stayed shut (lion/rows.h's busy, net, unread), which a later frame may
-- open; any other refusal would come back the same.
local TRIES,RETRY=4,10
local GATE={busy=true,net=true,unread=true}

-- o: log (the [MX] lines), ask(line) the native request, status() the native status text, travel() the follow
-- (session/travel.lua's, nil without the Steam link), paks (SB/Content/Paks, nil when unknown), read (files.read).
function Mxiii.new(o)
    local log=o.log
    local e=Enemy.new({log=log,ask=o.ask,status=o.status},
        {word='mxiii',name='Matrix XIII',command='coop mxiii',tag='[MX]',rows=Mxiii.ROWS,ids={}})
    local self={}
    -- The travel camp EVE respawned at when coop mxiii last asked its travel: once there, she respawns at Matrix XIII.
    -- shortcut: kept in this Lua state only, so a Lua reload in the dungeon loses it and leave takes the read's first
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
    -- coop mxiii [30]: the checks, the rows, then the travel to the zone 10 camp, or with 30 to the zone 30 camp.
    function self.command(extra)
        if extra=='leave' then return leave() end
        if extra~=nil and extra~='30' then return false,'Use: coop mxiii [30|leave]' end
        local camp,command=Mxiii.CAMP,'coop mxiii'
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
        -- Without the v3 pak SB finds no spawn point of that name, and an arrival that finds none was never traced.
        if camp==Mxiii.CAMP30 and said<3 then
            log('refused: test pak v'..said..' has no '..camp..' spawn point')
            return false,command..' needs the v3 zMXIII_P test pak: '..map..' is v'..said..', with no '..camp
                ..' spawn point for the arrival: nothing was asked'
        end
        return e.rows(function(ok,message) return warp(camp,command,ok,message) end)
    end
    -- The title's batch, from main.lua's 250 ms loop: at_title (the title screen shown, no save loaded) and coop (the
    -- game on the co-op save files, saves=coop; never your own saves). Once a game run: the mxiii line already reading
    -- rows (a Lua reload, a coop mxiii before a return to the title) ends it, and so do no test pak (looked for once a
    -- Lua load), a fault, or an answer that is no shut gate. The rows flow is coop mxiii's (the tables, the native
    -- part's gate and latch, the read-back), with no EVE and no map to keep, and no travel after.
    local early,pak,tries,again=nil,nil,0,0 -- early: 'asked', then 'in' or 'off'; nil: free to ask.
    function self.title(at_title,coop)
        if not (at_title and coop) then tries=0 return end
        if early or tries>=TRIES or os.clock()<again or e.busy() then return end
        local s=Enemy.parse(o.status and o.status(),'mxiii')
        if not s or s.state=='fault' then return end -- No native part, or the rows stopped for the run.
        if s.state=='rows' then
            early='in'
            return log('title: the rows are in already ('..s.line..')')
        end
        if pak==nil then pak=select(2,Mxiii.find_map(o.paks,o.read)) end
        if type(pak)~='number' then
            early='off' -- No test pak: nothing to add, and nothing said (most players have none).
            return
        end
        tries,early=tries+1,'asked'
        log('title: the co-op save files and test pak v'..pak..': the rows asked before any save loads (try '..tries
            ..' of '..TRIES..')')
        -- The end, said here only (nothing returned, so main.lua reports nothing): a shut gate, no answer yet, or an
        -- end before the ask (the tables not all loaded) may pass at a later try.
        e.rows(function(ok,message)
            local line=Enemy.parse(o.status and o.status(),'mxiii')
            local again_later=not ok and line and (line.state=='off' or line.state=='waiting'
                or line.state=='refused' and GATE[line.why])
            early,again=ok and 'in' or not again_later and 'off' or nil,os.clock()+RETRY
            local next_try=tries<TRIES and ' (asked again in '..RETRY..' s if the title still shows)'
                or ' (no more tries this visit of the title: coop mxiii adds them)'
            log('title: '..(ok and 'the rows are in, before any save loads' or tostring(message))
                ..(again_later and next_try or ''))
        end,nil,true)
    end
    self.tick,self.stop=e.tick,e.stop
    return self
end
return Mxiii
