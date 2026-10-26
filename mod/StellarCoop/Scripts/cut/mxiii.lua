-- coop mxiii (a test tool, experimental, left out of the usage line): SB's own camp travel into Zone_DLC02_10, the
-- first zone of the cut Matrix XIII dungeon (WorldTable DLCMatrix13, ID 2800). No pak of the game holds its map,
-- /Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P, and no row of the game leads to its world. The zMXIII_P test pak, built
-- outside the mod and never shipped with it, adds a map at that path. On the game thread, in order: the checks the
-- travel needs, once a command (the follow's own guards: solo, a co-op save, the native travel there and none under
-- way; then the test pak); the 2 rows the camp travel lacks, the native part's mxiii rows batch (lion/rows.h:
-- ZoneCampTable DLC02_10_Camp_01, then the ZoneEnvSpawnTable row DLC02_10_EnvS_900 in Zone_DLC02_10 whose TargetCamp
-- names it, through the game's own row call with no logic task in flight), through cut/enemy.lua's rows flow (the
-- tables, the ask, the wait, the read-back); then SB's camp travel to DLC02_10_Camp_01 through the follow's probe
-- (session/travel.lua; the native part's game/travel.h). Each step logs an [MX] line, the travel's result a [TR] line.
-- A warp into a world the save has never been in may write that world into the save: main.lua lets it run on a co-op
-- save only. The rows stay for the game run; a second coop mxiii reads them back and travels again.
-- The test pak's check makes no StaticFindObject (a package that is not loaded is never found that way, and each miss
-- costs 4 to 35 ms): the container's .utoc in SB/Content/Paks/~mods or LogicMods, read once a command, must name the
-- map's folders and MXIII_P.umap in its directory index (plain text in a .utoc that is not encrypted, as retoc writes
-- it), with its .pak and .ucas beside it (UE 4.26 mounts an IoStore container through its .pak).
-- shortcut: the live folder, not what the engine mounted at start, so a pak copied in while the game runs passes;
-- upgrade to the native part's start list (game/pak_list.h) if that happens in a test.
local Enemy=require('cut.enemy')
local Mxiii={}
Mxiii.CAMP='DLC02_10_Camp_01'
Mxiii.PAK='zMXIII_P'
Mxiii.MAP='MXIII_P.umap'
-- The directory index's names of the WorldTable path /Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P, the map last.
Mxiii.INDEX={'WorldMap_DLC_01','Level_P',Mxiii.MAP}
Mxiii.DIRS={'~mods','LogicMods'}
local LIMIT=1<<20 -- Bytes read of a .utoc: its directory index comes last, under 1 KB for the test pak's two maps.
-- SB lists every camp's env-spawn rows in FSBGameWorld::Init (FUN_141c97ca0 makes the zone manager, whose setup runs
-- FUN_141d18100 over ZoneEnvSpawnTable), so the world the rows went in on may know no DLC02_10_Camp_01 until the next
-- one. Read from the code, untested.
local HINT='if [TR] says SB refused DLC02_10_Camp_01: SB lists the camps when its world starts, maybe before these '
    ..'rows; load the save or travel to a camp, then run coop mxiii again (the rows stay in)'
-- The rows as cut/enemy.lua reads them back (rows.h's kMxiiiRecipe and kMxiiiPatches; mxiii_test checks them against
-- it): the camp copies ME01_Camp_03 (a FullCamp too) and never shows on the world map (CampDisplayType Never, 5); the
-- env-spawn row copies DLC02_10_EnvS_425 (ZoneList Zone_DLC02_10) under its own actor name, with the new camp.
Mxiii.ROWS=Enemy.rows({
    {'ZoneCampTable','DLC02_10_Camp_01',280001,{{'CampType','e',3,false},{'CampDisplayType','e',5,true}}},
    {'ZoneEnvSpawnTable','DLC02_10_EnvS_900',2800032900,
        {{'EnvActorName','n','DLC02_10_EnvS_900',true},{'TargetCamp','n','DLC02_10_Camp_01',true}}},
})
-- SB/Content/Paks from the mod's folder (...\SB\Binaries\Win64\[ue4ss\]Mods\StellarCoop), or nil.
function Mxiii.paks_of(folder)
    local sb=type(folder)=='string' and folder:match('^(.*)[\\/][Bb]inaries[\\/][Ww]in64[\\/]')
    return sb and sb..'\\Content\\Paks' or nil
end
-- The test pak's .utoc that names the map, beside its .pak and .ucas, or nil and why. paks: SB/Content/Paks (nil: unknown); read(path, limit):
-- core/link.lua's files.read (the text, or nil when the file cannot be opened).
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
            for _,ext in ipairs({'.pak','.ucas'}) do
                local other=path:sub(1,-6)..ext
                if not read(other,1) then return nil,'no '..other..' beside '..path end
            end
            return path
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
    -- Once the rows are in (ok, message: the rows flow's end): the camp travel, through the follow's probe.
    local function warp(ok,message)
        if not ok then return false,(tostring(message):gsub(': no spawn%.$',': no travel.')) end
        local travel=o.travel()
        if not travel then return false,'coop mxiii: no follow to travel with (the Steam link is gone)' end
        local asked,said=travel.probe(Mxiii.CAMP,true)
        log('travel to '..Mxiii.CAMP..(asked and ' asked: ' or ' refused: ')..tostring(said))
        if not asked then return false,'coop mxiii: the rows are in, but no travel: '..tostring(said) end
        log(HINT)
        return true,'coop mxiii: the rows are in and the travel to '..Mxiii.CAMP..' is asked ([TR] lines follow)'
    end
    function self.command(extra)
        if extra~=nil then return false,'Use: coop mxiii' end
        local busy=e.busy()
        if busy then return false,busy end
        local travel=o.travel()
        if not travel then return false,'coop mxiii needs the Steam link' end
        local ready,why=travel.ready()
        if not ready then
            log('refused: '..tostring(why))
            return false,'coop mxiii: '..tostring(why)..': nothing was asked'
        end
        local map,missing=Mxiii.find_map(o.paks,o.read)
        if not map then
            log('refused: no test pak: '..missing)
            return false,'coop mxiii needs the zMXIII_P test pak in Paks\\~mods or Paks\\LogicMods ('..missing
                ..'): nothing was asked'
        end
        log('checks: solo on a co-op save, the native travel idle, '..map..' holds '..table.concat(Mxiii.INDEX,'/')
            ..' beside its .pak and .ucas')
        return e.rows(warp)
    end
    self.tick,self.stop=e.tick,e.stop
    return self
end
return Mxiii
