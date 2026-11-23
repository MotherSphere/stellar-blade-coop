-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's engine reads (world/maps/sboxion/engine.lua) over fake UE4SS objects: the zone's FName index only for a
-- name the game has made; each env volume's path with its bActiveVolume read and written on the actor, a dead actor
-- raising; the streaming levels by their package's last part with what IsLevelLoaded and IsLevelVisible say; the
-- probes read again on the kept objects, a gone one reading not loaded; the characters' names; no EVE raising.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local function object(t)
    t.type=t.type or function() return 'UObject' end
    t.IsValid=t.IsValid or function(self) return not self.dead end
    return t
end
local function fname(text,index)
    return object({ToString=function() return text end,GetComparisonIndex=function() return index end})
end
package.loaded.UEHelpers={}
EFindName={FNAME_Find=0}
local made={Zone_SBO_Xion=4660}
FName=function(alias,how)
    assert(how==EFindName.FNAME_Find,'A find, never an add')
    return made[alias] and fname(alias,made[alias]) or fname('None',0)
end
local actors={}
FindAllOf=function(name) return actors[name] end
StaticFindObject=function(path) return object({path=path}) end
local function level(package,loaded,visible)
    return object({GetWorldAssetPackageFName=function() return fname(package) end,
        IsLevelLoaded=function() return loaded end,IsLevelVisible=function(self) return self.shown end,shown=visible})
end
local BG='/Game/Art/BG/WorldMap/SubLevel/E04/'
local streaming={level(BG..'E04_ENV',true,true),level(BG..'E04_DistantView_A_01',true,false),
    object({dead=true}),level(BG..'E04_DistantView_A_03',false,false)}
local eve=object({GetWorld=function() return object({StreamingLevels=streaming}) end})
package.loaded['core.player']={her=function() return eve end}
local Engine=require('world.maps.sboxion.engine')

-- zone_index: the index of a name the game has; nil for one it has not made.
assert(Engine.zone_index('Zone_SBO_Xion')==4660)
made.Zone_SBO_Xion=nil
assert(Engine.zone_index('Zone_SBO_Xion')==nil,'A name not made yet has no index')

-- volumes: the path without the class word, the property read and written on the actor.
local function vol(path,on)
    return object({GetFullName=function() return 'SBEnvControlVolume '..path end,bActiveVolume=on})
end
local a=vol(BG..'E04_ENV_VOL.E04_ENV_VOL:PersistentLevel.E04_Area_02_Sub_ENV_01****',false)
local b=vol('/Game/X.X:PersistentLevel.V',true)
actors.SBEnvControlVolume={a,object({dead=true}),b}
local list=Engine.volumes()
assert(#list==2 and list[1].path==BG..'E04_ENV_VOL.E04_ENV_VOL:PersistentLevel.E04_Area_02_Sub_ENV_01****'
    and list[2].path=='/Game/X.X:PersistentLevel.V',list[1].path)
assert(list[1].get()==false and list[2].get()==true)
list[1].set(true)
assert(a.bActiveVolume==true and list[1].get()==true and b.bActiveVolume==true,'The write goes to its own actor')
a.dead=true
assert(not pcall(list[1].get) and not pcall(list[1].set,false) and a.bActiveVolume==true,'A dead actor is not touched')

-- levels: the package's last part, loaded and visible; an invalid entry is left out.
local levels=Engine.levels()
assert(#levels==3 and levels[1].name=='E04_ENV' and levels[1].loaded and levels[1].visible)
assert(levels[2].name=='E04_DistantView_A_01' and levels[2].loaded and not levels[2].visible)
assert(levels[3].name=='E04_DistantView_A_03' and not levels[3].loaded and not levels[3].visible)
-- probes: the kept objects read again, in the order asked; a level never listed or gone reads not loaded.
streaming[2].shown=true
local probes=Engine.probes({'E04_DistantView_A_03','E04_DistantView_A_01','E04_Missing'})
assert(#probes==3 and probes[1].name=='E04_DistantView_A_03' and not probes[1].loaded)
assert(probes[2].name=='E04_DistantView_A_01' and probes[2].loaded and probes[2].visible,'Read again, not remembered')
assert(probes[3].name=='E04_Missing' and probes[3].loaded==false and probes[3].visible==false)
streaming[2].dead=true
assert(Engine.probes({'E04_DistantView_A_01'})[1].loaded==false,'A gone level reads not loaded')

-- characters: every SBCharacter's name.
actors.SBCharacter={object({GetFName=function() return fname('CH_P_EVE_01_Blueprint_C_0') end}),
    object({GetFName=function() return fname('Animal_Rat_C_3') end})}
assert(table.concat(Engine.characters(),',')=='CH_P_EVE_01_Blueprint_C_0,Animal_Rat_C_3')

-- No EVE: every world read raises, for sboxion.lua's guarded reads.
package.loaded['core.player'].her=function() return nil end
for _,read in ipairs({Engine.volumes,Engine.levels,Engine.characters}) do
    local ok,why=pcall(read)
    assert(not ok and tostring(why):find('no EVE in the world',1,true),tostring(why))
end
print('sboxion_engine_test ok')
