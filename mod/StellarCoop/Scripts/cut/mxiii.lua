-- coop mxiii (a test tool, experimental, left out of the usage line): SB's own camp travel into Zone_DLC02_10, the
-- first zone of the cut Matrix XIII dungeon (WorldTable DLCMatrix13, ID 2800), and a camp there. No pak of the game
-- holds its map, /Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P, and no row of the game leads to its world. The zMXIII_P
-- test pak, built outside the mod and never shipped with it, adds a map at that path. On the game thread, in order: the
-- checks the travel needs, once a command (the follow's own guards: solo, a co-op save, the native travel there and
-- none under way; then the test pak, v1, v2 or v3); the native part's mxiii rows batch (lion/mxiii_rows.h, written by
-- tools/mxiii_rows.py from data/mxiii-world.json: the zone 10 camp DLC02_10_Camp_01 with DLC02_10_EnvS_900, which
-- leads the travel there, and its kit 901 to 906, which SB spawns at the pak's spawn points of those names; zone 30's
-- rest stop DLC02_30_Camp_01; 5 shipped ZoneTriggerTable rows patched in place, so the zone 20 waves and the zone 40
-- chains of spawns fire without the cut map's gates and drain devices; then the map's other camps, their kits and
-- coins, and zone 0's Tetrapod with Lily), added by SB's own row call with no logic task in flight,
-- through cut/enemy.lua's rows flow (the tables, the ask, the wait, the read-back); then SB's camp travel to
-- DLC02_10_Camp_01 through the follow's probe (session/travel.lua; the native part's game/travel.h). coop mxiii 30 is
-- the same with the travel to DLC02_30_Camp_01, which reaches the dungeon's upper half without the zone 20 climb (it
-- runs on Matrix 11 triggers and sequences the test pak leaves out); it needs the v3 pak, the only one with that camp's
-- spawn point, and asks nothing on v1 or v2. Each step logs an [MX] line, the travel's result a [TR] line. A warp into
-- a world the save has never been in may write that world into the save: main.lua lets it run on a co-op save only. The
-- rows stay for the game run; a second coop mxiii reads them back and travels again. The same batch goes in on its own
-- at the title, before any save loads, while the game uses the co-op save files and the test pak is there (title()
-- below), so a co-op save that names a mod camp or row (the respawn camp at FSBActor +0x26d0, the save's activated
-- camps and last camp rows) loads with them, and coop mxiii then only reads them back and travels. At the title the
-- other batches follow it, one after the other (Mxiii.BATCHES: the spawn rows, the doors and lifts, the warps, then
-- the Lion's and the Gardener's own rows that the boss spawn rows name). In world 2800 the tick spawns the ladders and
-- ledges (cut/mxmove.lua) and fixes the Lion and Gardener the game spawns (cut/mxboss.lua); coop mxiii boss spawns
-- the key-0 boss of the arena EVE stands in. The way out is
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
-- The rows as cut/enemy.lua reads them back: cut/mxiii_rows.lua, which tools/mxiii_rows.py writes from
-- data/mxiii-world.json with lion/mxiii_rows.h (mxiii_test checks the two agree). The mxiii batch holds the camps and
-- what they need (their env rows, coins, zone 0's Tetrapod and Lily); the dev rows come first, in their order.
local Rows=require('cut.mxiii_rows')
Mxiii.ROWS=Enemy.rows(Rows.MXIII)
-- The other batches, each its own ask: Matrix XIII's spawn rows, doors and lifts, warps (lion/mxiii_rows.h), then the
-- Lion's and the Gardener's own batches, whose CharacterTable rows M_LionC and M_Gardener the boss spawn rows name.
-- At the title they go in once the mxiii rows are in, one after the other.
Mxiii.BATCHES={
    {word='mxspawn',name='Matrix XIII Naytiba',rows=Enemy.rows(Rows.MXSPAWN)},
    {word='mxenv',name='Matrix XIII door and lift',rows=Enemy.rows(Rows.MXENV)},
    {word='mxwarp',name='Matrix XIII warp',rows=Enemy.rows(Rows.MXWARP)},
    {word='lion',name='Lion',rows=Enemy.rows(require('cut.lion_rows').ROWS)},
    {word='gardener',name='Gardener',rows=Enemy.rows(require('cut.lion_rows').GARDENER)},
}
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
        if extra=='boss' then return self.boss() end
        if extra~=nil and extra~='30' then return false,'Use: coop mxiii [30|leave|boss]' end
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
    -- The title's batch (cut/enemy.lua's title_batch): while the game uses the co-op save files and the test pak is
    -- there (looked for once a Lua load; with none there is nothing to add, and nothing is said: most players have
    -- none).
    local pak=nil
    local function ready()
        if pak==nil then pak=select(2,Mxiii.find_map(o.paks,o.read)) end
        return type(pak)=='number' and 'the co-op save files and test pak v'..pak or nil
    end
    local title,title_stop=e.title_batch(ready,'coop mxiii')
    -- The other batches at the title, each once the batch before it has an answer (its line reads rows, or refused:
    -- a refusal in one never holds the others back), so one ask runs at a time and the mxiii rows keep the first one.
    local others,previous={},'mxiii'
    for _,b in ipairs(Mxiii.BATCHES) do
        local x=Enemy.new({log=function(m) log(b.word..' '..m) end,ask=o.ask,status=o.status},
            {word=b.word,name=b.name,command='coop mxiii',tag='[MX]',rows=b.rows,ids={}})
        local t,stop=x.title_batch(ready,'a return to the title')
        others[#others+1]={e=x,title=t,stop=stop,after=previous}
        previous=b.word
    end
    -- The ladders and ledges (cut/mxmove.lua) and the bosses the game spawns (cut/mxboss.lua), in world 2800 only.
    local move=require('cut.mxmove').new({log=function(m) log('[MXMOVE] '..m) end})
    local boss=require('cut.mxboss').new({log=function(m) log('[MXBOSS] '..m) end,lion=o.lion,gardener=o.gardener})
    function self.title(at_title,coop)
        title(at_title,coop)
        for _,x in ipairs(others) do
            local s=Enemy.parse(o.status and o.status(),x.after)
            if s and (s.state=='rows' or s.state=='refused') then x.title(at_title,coop) end
        end
    end
    -- coop mxiii boss: the key-0 boss of the arena EVE stands in, when the game spawned none there.
    self.boss=boss.command
    function self.tick()
        local ok,message=e.tick()
        for _,x in ipairs(others) do x.e.tick() end
        move.tick()
        boss.tick()
        return ok,message
    end
    -- coop off ends the waits without their end, so a title batch asked is free to ask again at the next call.
    function self.stop()
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
