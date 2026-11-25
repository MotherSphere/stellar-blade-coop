-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A pak of ours in SB/Content/Paks, found with no engine call: the Matrix XIII test pak
-- (world/maps/matrix13/level/travel.lua), the hall lobby pak (online/lobby/sbo.lua) and the zSBO_Xion test pak
-- (world/maps/sboxion/sboxion.lua). No StaticFindObject: a package
-- that is not loaded is never found that way, and each miss costs 4 to 35 ms. The container's .utoc in ~mods, else
-- LogicMods, read once a call (its first 1 MB), must name the names asked in its directory index (plain text in a .utoc
-- that is not encrypted, as retoc writes it), with its .pak and .ucas beside it (UE 4.26 mounts an IoStore container
-- through its .pak).
-- shortcut: the live folder, not what the engine mounted at start, so a pak copied in while the game runs passes;
-- upgrade to the native part's start list (link/pak_list.h) if that happens in a test.
local PakGate={}
PakGate.DIRS={'~mods','LogicMods'}
local LIMIT=1<<20 -- Bytes read of a .utoc: its directory index comes last, 18 KB of the full map's 47 KB .utoc.
-- The .ucas's size as the .utoc's compression blocks give it (the furthest offset plus compressed size), or nil when
-- the text does not read as a .utoc header (UE 4.26's FIoStoreTocHeader, version 2 as retoc writes it: the block count
-- and entry size, after the chunk IDs and offsets).
function PakGate.ucas_size(utoc)
    if #utoc<144 or utoc:sub(1,16)~='-==--==--==--==-' then return nil end
    local header,entries,blocks,size=string.unpack('<I4I4I4I4',utoc,21)
    local first=header+entries*22+1 -- Past the chunk IDs (12 bytes each) and their offsets and lengths (10).
    if header~=144 or size~=12 or blocks<1 or first+blocks*12-1>#utoc then return nil end
    local last=0
    for k=0,blocks-1 do
        local at=first+k*12
        local offset=string.unpack('<I5',utoc,at)
        last=math.max(last,offset+string.unpack('<I3',utoc,at+5))
    end
    return last
end
-- Container name's .utoc that holds every name of index, beside its .pak and .ucas: its path, its text and the first
-- window bytes of its .ucas; or nil and why. paks: SB/Content/Paks (nil: unknown); read(path, limit, offset):
-- core/link.lua's files.read (the text, or nil when the file cannot be opened).
function PakGate.container(paks,read,name,index,window)
    if not paks then return nil,'the game folder is unknown (the mod folder is not under SB\\Binaries\\Win64)' end
    local tried={}
    for _,dir in ipairs(PakGate.DIRS) do
        local path=paks..'\\'..dir..'\\'..name..'.utoc'
        local text=read(path,LIMIT)
        if text then
            for _,word in ipairs(index) do
                if not text:find(word,1,true) then return nil,path..' does not hold '..word end
            end
            local got={}
            for _,ext in ipairs({'.pak','.ucas'}) do
                local other=path:sub(1,-6)..ext
                got[ext]=read(other,ext=='.ucas' and window or 1)
                if not got[ext] then return nil,'no '..other..' beside '..path end
            end
            return path,text,got['.ucas']
        end
        tried[#tried+1]=path
    end
    return nil,'no '..table.concat(tried,' or ')
end
-- Container name holding every map of umaps (game paths, /Game/<folders>/<map>: each folder and <map>.umap in its
-- directory index): its version, '<.utoc bytes>_<.ucas bytes>', which two builds of the pak share only by chance and
-- which a match lobby carries as a word of its data (letters, digits and '_'); or nil and why.
function PakGate.find(paks,read,name,umaps)
    local index={}
    for _,umap in ipairs(umaps) do
        for part in umap:gsub('^/Game/',''):gmatch('[^/]+') do index[#index+1]=part end
        index[#index]=index[#index]..'.umap'
    end
    local path,text=PakGate.container(paks,read,name,index,1)
    if not path then return nil,text end
    local size=PakGate.ucas_size(text)
    if not size then return nil,path..' does not read as a .utoc header' end
    return #text..'_'..size
end
-- SB/Content/Paks from the mod's folder (...\SB\Binaries\Win64\[ue4ss\]Mods\StellarCoop), or nil.
function PakGate.paks_of(folder)
    local sb=type(folder)=='string' and folder:match('^(.*)[\\/][Bb]inaries[\\/][Ww]in64[\\/]')
    return sb and sb..'\\Content\\Paks' or nil
end
return PakGate
