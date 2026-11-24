-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's engine reads (world/maps/sboxion/engine.lua) over fake UE4SS objects: the zone's FName index only for a
-- name the game has made; each env volume's path with its bActiveVolume read and written on the actor, a dead actor
-- raising; the streaming levels by their package's last part with what IsLevelLoaded and IsLevelVisible say; the
-- probes read again on the kept objects, a gone one reading not loaded; the characters' names; no EVE raising. Then
-- the recovery's calls (world/maps/sboxion/recover.lua): move gives EVE's place, yaw, movement mode, world time and
-- address from one EVE with each read made once, nil with no EVE; put teleports then stops her movement, with no stop
-- call after a refusal; the respawn's controller, standalone test and call; the death screen found once, read
-- playing or not, hidden and shown again as it was (4, not 0), a dead widget left as it is.
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
local statics={} -- The class default objects the recovery's calls go through, by path.
StaticFindObject=function(path) return statics[path] or object({path=path}) end
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

-- move: one EVE, each of her reads made once; the world time is asked with her as the context.
local reads={}
local function count(what) reads[what]=(reads[what] or 0)+1 end
local function value(v) return object({type=function() return 'RemoteUnrealParam' end,get=function() return v end}) end
local teleport,stops,went=true,0,nil
local walker=object({GetAddress=function() return 0x7000 end,
    K2_GetActorLocation=function() count('location'); return value({X=3931.4,Y=-9086.2,Z=-25367.6}) end,
    K2_GetActorRotation=function() count('rotation'); return value({Pitch=1,Yaw=40.5,Roll=2}) end,
    K2_TeleportTo=function(_,at,turn) went={at=at,turn=turn}; return teleport end,
    CharacterMovement=object({MovementMode=3,StopMovementImmediately=function() stops=stops+1 end})})
statics['/Script/Engine.Default__GameplayStatics']=object({GetTimeSeconds=function(_,context)
    assert(context==walker,'The clock reads EVE\'s world')
    count('time')
    return 812.25
end})
package.loaded['core.player'].her=function() count('her'); return walker end
local m=Engine.move()
assert(m.at.X==3931.4 and m.at.Y==-9086.2 and m.at.Z==-25367.6 and m.yaw==40.5 and m.mode==3 and m.time==812.25
    and m.pawn==0x7000,'The five values')
assert(reads.her==1 and reads.location==1 and reads.rotation==1 and reads.time==1,'One EVE, each read once')
walker.CharacterMovement.dead=true
assert(Engine.move().mode==nil,'No movement component: no mode')
walker.CharacterMovement.dead=nil
-- put: the teleport to the place facing yaw, then the stop; a refusal makes no stop call.
assert(Engine.put({X=1,Y=2,Z=3},-233.4)==true and stops==1)
assert(went.at.X==1 and went.at.Y==2 and went.at.Z==3 and went.turn.Pitch==0 and went.turn.Yaw==-233.4
    and went.turn.Roll==0,'The place and the yaw alone')
teleport=nil -- A game call that returns nothing is no refusal.
assert(Engine.put({X=1,Y=2,Z=3},0)==true and stops==2)
teleport=false
assert(Engine.put({X=1,Y=2,Z=3},0)==false and stops==2,'No stop call after a refusal')
-- The respawn's pieces: the controller, the standalone test on it and SB's request with the GUID and false.
local asked={}
local pc=object({ServerRequest_ActorRespawn=function(_,me,camp) asked[#asked+1]={me,camp} end})
local standalone=true
statics['/Script/Engine.Default__KismetSystemLibrary']=object({IsStandalone=function(_,context)
    assert(context==pc,'The test is asked on the controller')
    return standalone
end})
package.loaded['core.player'].controller=function() return pc end
assert(Engine.controller()==pc and Engine.standalone(pc)==true)
standalone=false
assert(Engine.standalone(pc)==false)
Engine.respawn(pc,2610)
assert(#asked==1 and asked[1][1]==2610 and asked[1][2]==false,'ServerRequest_ActorRespawn(GUID, false)')
-- The death screen: not looked for unless asked; found once and kept; playing or not; hidden, then shown as it was.
-- It starts at 4 (ESlateVisibility SelfHitTestInvisible), so a show that writes 0 (Visible) is seen.
local looks,playing,visibility=0,true,4
local dead=object({IsAnyAnimationPlaying=function() return playing end,GetVisibility=function() return visibility end,
    SetVisibility=function(_,v) visibility=v end})
local hud=object({GetFullName=function() return 'WB_MainHUD_Master_C /Engine/Transient.GameEngine_1:X' end,
    WB_MainHUD_Dead=dead})
local all=FindAllOf
FindAllOf=function(name)
    if name~='WB_MainHUD_Master_C' then return all(name) end
    looks=looks+1
    return {hud}
end
assert(Engine.screen(false)==nil and looks==0 and Engine.hide()==nil,'No look unless asked')
assert(Engine.screen(true)==true and looks==1)
playing=false
assert(Engine.screen(true)==false and Engine.screen(false)==false and looks==1,'The widget is kept while it lives')
local show=Engine.hide()
assert(visibility==2 and type(show)=='function','Hidden: ESlateVisibility 2')
show()
assert(visibility==4,'Shown as it was')
dead.dead=true
assert(Engine.screen(false)==nil and Engine.screen(true)==nil and looks==2,'A dead widget is looked for again')
visibility=2
show()
assert(visibility==2,'A dead widget is not touched')

-- No EVE: move gives nil, put raises.
package.loaded['core.player'].her=function() return nil end
assert(Engine.move()==nil)
assert(not pcall(Engine.put,{X=0,Y=0,Z=0},0))
print('sboxion_engine_test ok')
