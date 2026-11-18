-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- core/pak_gate.lua over fake files (core/link.lua's files.read: at most limit bytes, nil when the file cannot be
-- opened): the hall lobby pak zSBO_Lobby found in ~mods, else LogicMods, its .utoc naming each map's folder and .umap
-- in its directory index, its .pak and .ucas beside it, each read bounded; its version from the .utoc's size and the
-- .ucas's size as the .utoc's compression blocks give it. Refused: no game folder, no .utoc, a missing .pak or .ucas,
-- a map missing from the index, a .utoc whose header does not read as one. The size reader itself (shared with
-- matrix13/world/travel.lua) is checked in matrix13/world/travel_test.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local PakGate=require('core.pak_gate')
local PAKS='C:\\G\\SB\\Content\\Paks'
local MODS,LOGIC=PAKS..'\\~mods\\zSBO_Lobby.utoc',PAKS..'\\LogicMods\\zSBO_Lobby.utoc'
local UMAPS={'/Game/SBO_Lobby/Lobby_Hotel','/Game/SBO_Lobby/Lobby_Station','/Game/SBO_Lobby/Lobby_Cloister',
    '/Game/SBO_Lobby/Lobby_Terrace','/Game/SBO_Lobby/Lobby_Foyer'}
-- A UE 4.26 .utoc as retoc writes it: the 144-byte header, 2 chunks, the compression blocks, then the directory index
-- with the names given.
local function utoc(blocks,names)
    local t='-==--==--==--==-'..string.pack('<BBI2I4I4I4I4I4I4I4I4',2,0,0,144,2,#blocks,12,0,32,65536,0)
    t=t..('\0'):rep(144-#t)..('\0'):rep(2*22)
    for _,b in ipairs(blocks) do t=t..string.pack('<I5I3I3B',b[1],b[2],b[2],0) end
    return t..'../../../\0SB\0Content\0'..table.concat(names,'\0')..'\0'
end
local ALL={'SBO_Lobby','Lobby_Hotel.umap','Lobby_Station.umap','Lobby_Cloister.umap','Lobby_Terrace.umap',
    'Lobby_Foyer.umap'}
local files,reads={},{}
local function read(path,limit,offset)
    assert(limit and limit>=1 and limit<=1<<20,'A bounded read')
    reads[#reads+1]=path
    offset=offset or 0
    return files[path] and files[path]:sub(offset+1,offset+limit)
end
local function put(path,text) -- The three files of the container.
    files[path]=text
    files[path:sub(1,-6)..'.pak'],files[path:sub(1,-6)..'.ucas']='',('\0'):rep(64)
end
-- No game folder, then no .utoc in either folder.
local version,why=PakGate.find(nil,read,'zSBO_Lobby',UMAPS)
assert(version==nil and why=='the game folder is unknown (the mod folder is not under SB\\Binaries\\Win64)'
    and #reads==0)
version,why=PakGate.find(PAKS,read,'zSBO_Lobby',UMAPS)
assert(version==nil and why=='no '..MODS..' or '..LOGIC and #reads==2,why)
-- finds_version: in LogicMods, the five maps named; '<.utoc bytes>_<.ucas bytes>'.
local TOC=utoc({{0,4096},{4096,1000}},ALL)
put(LOGIC,TOC)
reads={}
version,why=PakGate.find(PAKS,read,'zSBO_Lobby',UMAPS)
assert(version==#TOC..'_5096' and why==nil,tostring(version)..' '..tostring(why))
assert(table.concat(reads,',')==MODS..','..LOGIC..','..PAKS..'\\LogicMods\\zSBO_Lobby.pak,'
    ..PAKS..'\\LogicMods\\zSBO_Lobby.ucas',table.concat(reads,','))
-- ~mods first, and another build of the pak gives another version.
local TOC2=utoc({{0,4096},{4096,1200}},ALL)
put(MODS,TOC2)
assert(PakGate.find(PAKS,read,'zSBO_Lobby',UMAPS)==#TOC2..'_5296')
-- refuses_missing_ucas, and a missing .pak likewise.
files[PAKS..'\\~mods\\zSBO_Lobby.ucas']=nil
version,why=PakGate.find(PAKS,read,'zSBO_Lobby',UMAPS)
assert(version==nil and why=='no '..PAKS..'\\~mods\\zSBO_Lobby.ucas beside '..MODS,why)
put(MODS,TOC2)
files[PAKS..'\\~mods\\zSBO_Lobby.pak']=nil
version,why=PakGate.find(PAKS,read,'zSBO_Lobby',UMAPS)
assert(version==nil and why=='no '..PAKS..'\\~mods\\zSBO_Lobby.pak beside '..MODS,why)
-- refuses_wrong_umaps: a pak without Foyer, or with the maps in another folder.
put(MODS,utoc({{0,4096}},{'SBO_Lobby','Lobby_Hotel.umap','Lobby_Station.umap','Lobby_Cloister.umap',
    'Lobby_Terrace.umap'}))
version,why=PakGate.find(PAKS,read,'zSBO_Lobby',UMAPS)
assert(version==nil and why==MODS..' does not hold Lobby_Foyer.umap',why)
put(MODS,utoc({{0,4096}},{'Lobbies','Lobby_Hotel.umap','Lobby_Station.umap','Lobby_Cloister.umap',
    'Lobby_Terrace.umap','Lobby_Foyer.umap'}))
version,why=PakGate.find(PAKS,read,'zSBO_Lobby',UMAPS)
assert(version==nil and why==MODS..' does not hold SBO_Lobby',why)
-- A .utoc whose header does not read as one: no size, no version.
put(MODS,'-==--==--==--==-\0'..table.concat(ALL,'\0')..'\0')
version,why=PakGate.find(PAKS,read,'zSBO_Lobby',UMAPS)
assert(version==nil and why==MODS..' does not read as a .utoc header',why)
-- SB/Content/Paks from the mod's folder, as matrix13/world/travel_test.lua read it.
assert(PakGate.paks_of('C:\\G\\SB\\Binaries\\Win64\\ue4ss\\Mods\\StellarCoop')=='C:\\G\\SB\\Content\\Paks')
assert(PakGate.paks_of('D:/Steam/SB/Binaries/Win64/Mods/StellarCoop')=='D:/Steam/SB\\Content\\Paks')
assert(PakGate.paks_of('mod/StellarCoop')==nil and PakGate.paks_of(nil)==nil)
print('core/pak_gate_test: ok')
