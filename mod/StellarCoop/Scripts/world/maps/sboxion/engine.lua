-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's engine reads and its one write (world/maps/sboxion/sboxion.lua's world), on the game thread: the zone's
-- FName index for the native request, the SBEnvControlVolume actors with their bActiveVolume, the world's streaming
-- levels through the three functions SB's exe exposes by name (GetWorldAssetPackageFName, IsLevelLoaded,
-- IsLevelVisible) and the characters. sboxion.lua calls them only while EVE is in SBO Xion or for a command.
-- bActiveVolume is a plain bool of ASBEnvControlVolume (+0x320 on build 26123051). SB's env pass reads it again each
-- frame, so a write takes effect on the next frame with no call.
local U=require('core.unreal')
local N=require('core.player')
local Engine={}
local function eve() return assert(N.her(),'no EVE in the world') end
local function path_of(o) return U.text(o:GetFullName()):match('^%S+ (.+)$') or '' end
-- An FName's index, or nil when this game run has not made the name yet (a row name exists once its row is in).
function Engine.zone_index(alias)
    local n=U.value_of(FName(alias,EFindName.FNAME_Find))
    local index=n:GetComparisonIndex()
    if not index or index==0 or U.text(n):lower()~=alias:lower() then return nil end
    return index
end
-- Every SBEnvControlVolume of EVE's world: its path, get() and set(on) of bActiveVolume on the actor while it lives.
function Engine.volumes()
    local out={}
    for _,a in ipairs((U.actors_of(U.find('/Script/SB.SBEnvControlVolume'),'SBEnvControlVolume',eve()))) do
        local function live() return assert(U.valid(a),'it is gone') end
        out[#out+1]={path=path_of(a),get=function() return live().bActiveVolume==true end,
            set=function(on) live().bActiveVolume=on end}
    end
    return out
end
-- The world's streaming levels: each one's package name without its folders, whether it is loaded and visible. The
-- objects are kept for probes().
local held={}
local function state(name,l) return {name=name,loaded=l:IsLevelLoaded()==true,visible=l:IsLevelVisible()==true} end
function Engine.levels()
    local out={}
    held={}
    U.each(eve():GetWorld().StreamingLevels,function(_,l)
        l=U.valid(l)
        if l then
            local name=U.text(l:GetWorldAssetPackageFName()):match('[^/]+$') or '?'
            held[name]=l
            out[#out+1]=state(name,l)
        end
    end)
    return out
end
-- The levels of names as levels() last listed them, read again: two calls a level. One that is gone reads not loaded.
function Engine.probes(names)
    local out={}
    for _,name in ipairs(names) do
        local l=U.valid(held[name])
        out[#out+1]=l and state(name,l) or {name=name,loaded=false,visible=false}
    end
    return out
end
-- The names of the SBCharacter actors of EVE's world, EVE included.
function Engine.characters()
    local out={}
    for _,c in ipairs((U.actors_of(U.find('/Script/SB.SBCharacter'),'SBCharacter',eve()))) do
        out[#out+1]=U.text(c:GetFName())
    end
    return out
end
return Engine
