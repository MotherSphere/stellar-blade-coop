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
-- playing or not, hidden and shown again as it was (4, not 0), a dead widget left as it is. SB's black, with the call
-- case of tests/lua/online/lobby/wiring_test.lua and the raise of tests/lua/online/lobby/arrival_test.lua for this
-- module's copy: one LoadingScreenFadeAuto call with the hold, the fade-in from 0 to 1, the fade-out from 1 to 0 and
-- tag 0; with a fade-in of 0 the start block is 0 s from 1 to 1; true for a GUID that is not zero, false for a zero
-- GUID, nil for one that does not read; a raise of the call is not caught. Then a wall (world/maps/sboxion/walls/
-- walls.lua) through core/actors.lua: one plain Actor in EVE's world with the engine's cube as its root, at the box's
-- place and yaw, hidden, scaled to the box, never a step, SB's profile SB_InvisiblewallIgnoreCamera found by name and
-- set once the actor's collision is on (the engine makes the component's body only then) and the read-back in the
-- answer; with no such name nothing is spawned; a cube the component did not take, a profile that did not take (object
-- type other than 20), a raise of its call and a missing cube each raise with the actor destroyed; unwall destroys
-- only the actor it made; a sweep takes only an actor whose root shows the cube.
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

-- SB's black. The fake library records each LoadingScreenFadeAuto call's eight arguments, raises with fade_error and
-- returns guid.
local fades,guid,fade_error={},nil,nil
statics['/Script/SB.Default__SBBlueprintLibrary']=object({LoadingScreenFadeAuto=function(_,...)
    fades[#fades+1]=table.concat({...},' ')
    if fade_error then error(fade_error) end
    return guid
end})
-- black_call: SB's own fade (0x141b1b8e0): a start block of fade s from 0 to 1, an end block of out s from 1 to 0,
-- tag 0, with the time the black stands first.
guid=value({A=0,B=0,C=7,D=0})
assert(Engine.black(1,0.3,0.5)==true and #fades==1 and fades[1]=='1 0.3 0 1 0.5 1 0 0',fades[1])
-- black_at_once: with a fade-in of 0 the start block is 0 s from 1 to 1, black inside the call.
assert(Engine.black(1,0,0.5)==true and #fades==2 and fades[2]=='1 0 1 1 0.5 1 0 0',fades[2])
-- black_none: a zero GUID is no black.
guid=value({A=0,B=0,C=0,D=0})
assert(Engine.black(1,0.3,0.5)==false,'A zero GUID: SB made no loading screen')
-- black_unread: a GUID that does not read gives nil and raises nothing.
for _,g in ipairs({value({A=0,B=0}),'x',false}) do
    guid=g or nil -- false stands for a call that returns nothing.
    local ok,up=pcall(Engine.black,1,0.3,0.5)
    assert(ok and up==nil,'A GUID that does not read: '..tostring(g))
end
-- black_raises: a raise of the call reaches the caller (recover.lua takes it and logs why).
fade_error='LoadingScreenFadeAuto: no such function'
local ok,why=pcall(Engine.black,1,0.3,0.5)
assert(not ok and tostring(why):find('LoadingScreenFadeAuto: no such function',1,true),tostring(why))
assert(#fades==7,'One call a black: '..#fades)

-- A wall. The fake world spawns plain actors. Each records its calls in order.
local CUBE,PROFILE='/Engine/BasicShapes/Cube.Cube','SB_InvisiblewallIgnoreCamera'
local function cube_mesh(path)
    return object({GetFullName=function() return 'StaticMesh '..path end,
        IsA=function(_,c) return c.path=='/Script/Engine.StaticMesh' end})
end
statics[CUBE]=cube_mesh(CUBE)
statics['/Script/Engine.Default__KismetMathLibrary']=object({MakeTransform=function() return 'identity' end})
made[PROFILE]=991
local spawned,took,profile_error={},20,nil -- took: the object type the component reads back after the profile call.
local static=false -- A component of Static mobility: the engine refuses its mesh.
local function order(a,what) a.order[#a.order+1]=what end
local wall_world=object({SpawnActor=function(_,class,at,turn)
    assert(class.path=='/Script/Engine.Actor','A plain Actor only')
    local n=#spawned+1
    local a=object({order={},at=at,turn=turn,collision=true,
        GetFullName=function() return 'Actor /Game/SBO_World/Xion_P.Xion_P:PersistentLevel.Actor_'..n end})
    function a:SetActorEnableCollision(on,fast)
        assert(fast==false)
        self.collision=on
        order(self,'actor '..tostring(on))
    end
    function a:SetActorHiddenInGame(on) self.hidden=on end
    function a:K2_DestroyActor() self.dead=true end
    function a:K2_GetRootComponent() return self.root end
    function a:AddComponentByClass(k,manual,transform,deferred)
        assert(k.path=='/Script/Engine.StaticMeshComponent' and manual==false and transform=='identity'
            and deferred==false,'One StaticMeshComponent')
        local c=object({IsA=function(_,x) return x.path=='/Script/Engine.StaticMeshComponent' end})
        function c:SetStaticMesh(m) if not static then self.StaticMesh=m end end
        function c:SetRelativeScale3D(v) self.scale=v end
        function c:SetCollisionEnabled(v) self.enabled=v end
        function c:K2_SetWorldLocationAndRotation(to,rot) self.at,self.turn=to,rot end
        function c:SetCollisionProfileName(name,update)
            assert(update==true,'The overlaps are updated')
            if profile_error then error(profile_error) end
            order(a,'profile over '..tostring(self.enabled))
            self.profile,self.kind,self.enabled=name:ToString(),took,3
        end
        function c:GetCollisionObjectType() return self.kind end
        function c:K2_IsCollisionEnabled() return self.enabled~=0 and a.collision end
        self.root=c
        return c
    end
    spawned[n]=a
    return a
end})
package.loaded['core.player'].her=function() return object({GetWorld=function() return wall_world end}) end
local BOX={at={X=3900,Y=-9200,Z=1100},yaw=40,size={X=175,Y=30,Z=950}}
local d=Engine.wall(BOX)
local a,c=spawned[1],spawned[1].root
assert(#spawned==1 and d.actor==a and d.path=='/Game/SBO_World/Xion_P.Xion_P:PersistentLevel.Actor_1')
assert(a.at.X==3900 and a.at.Y==-9200 and a.at.Z==1100 and a.turn.Yaw==40 and a.turn.Pitch==0 and a.turn.Roll==0)
assert(c.at.X==3900 and c.turn.Yaw==40,'The root goes to the place: it was added at the origin')
assert(c.StaticMesh==statics[CUBE] and a.hidden==true and c.CanCharacterStepUpOn==0)
assert(c.scale.X==1.75 and c.scale.Y==0.3 and c.scale.Z==9.5,'The cube is 100 cm a side')
assert(c.profile==PROFILE and c.kind==20)
-- The engine makes the body when the profile call changes the collision it reads with the actor's own: so the actor
-- is on first, over a component still closed (0, NoCollision), which blocks nothing until the profile is on.
assert(table.concat(a.order,',')=='actor false,actor true,profile over 0',table.concat(a.order,','))
assert(d.read=='object type 20, collision on',d.read)
-- wall_no_mesh: a component that did not take the cube has no shape, so the wall is taken out again.
static=true
ok,why=pcall(Engine.wall,BOX)
assert(not ok and tostring(why):find('the cube is not on the component',1,true) and #spawned==2 and spawned[2].dead
    and #spawned[2].order==1,tostring(why))
static=false
-- wall_profile_not_taken: the read-back is not SB's object type, so the wall is taken out again.
took=0
ok,why=pcall(Engine.wall,BOX)
assert(not ok and tostring(why):find('did not take: object type 0',1,true) and #spawned==3 and spawned[3].dead,
    tostring(why))
took=20
-- wall_profile_raises: the same for a raise of the call.
profile_error='SetCollisionProfileName: no such function'
ok,why=pcall(Engine.wall,BOX)
assert(not ok and tostring(why):find('no such function',1,true) and #spawned==4 and spawned[4].dead,tostring(why))
profile_error=nil
-- wall_no_name: a game that has no such name spawns nothing.
made[PROFILE]=nil
ok,why=pcall(Engine.wall,BOX)
assert(not ok and tostring(why):find('no name '..PROFILE,1,true) and #spawned==4,tostring(why))
made[PROFILE]=991
-- wall_name_case: the game's name table gives a name back in the case it first met. The profile is the same one.
local find_name=FName
FName=function(alias,how) return fname(find_name(alias,how):ToString():upper(),991) end
local shout=Engine.wall(BOX)
assert(shout.read=='object type 20, collision on' and Engine.unwall(shout)==true)
FName=find_name
-- unwall: the actor it made, once; never another object met at its handle.
assert(Engine.unwall(d)==true and a.dead==true)
assert(Engine.unwall(d)==false,'A wall that is gone is not called')
local e=Engine.wall(BOX)
local other=spawned[6]
other.GetFullName=function() return 'Actor /Game/Other.Other:PersistentLevel.Lamp_3' end
assert(Engine.unwall(e)==false and not other.dead,'Another object at the handle is left alone')
-- wall_swept: an earlier Lua load's wall by its path, only while its root shows the cube.
local old=Engine.wall(BOX)
statics[old.path]=old.actor
assert(Engine.wall_swept(old.path)==true and old.actor.dead)
local chair=Engine.wall(BOX)
chair.mesh.StaticMesh=cube_mesh('/Game/Art/Chair.Chair')
statics[chair.path]=chair.actor
assert(Engine.wall_swept(chair.path)==false and not chair.actor.dead,'Another mesh at that path is left alone')
statics['/Game/Gone.Gone:PersistentLevel.Actor_9']=object({dead=true})
assert(Engine.wall_swept('/Game/Gone.Gone:PersistentLevel.Actor_9')==false)
-- wall_no_cube: with no cube in memory and none loaded, nothing is left.
statics[CUBE].dead=true -- core/actors.lua keeps the mesh it found while it lives.
LoadAsset=function() return object({dead=true}) end
ok,why=pcall(Engine.wall,{at={X=1,Y=2,Z=3},yaw=0,size={X=100,Y=30,Z=950}})
assert(not ok and tostring(why):find('Cube is missing on this PC',1,true) and spawned[#spawned].dead,tostring(why))

-- No EVE: move gives nil, put and wall raise.
package.loaded['core.player'].her=function() return nil end
assert(Engine.move()==nil)
assert(not pcall(Engine.put,{X=0,Y=0,Z=0},0))
statics[CUBE]=cube_mesh(CUBE)
ok,why=pcall(Engine.wall,BOX)
assert(not ok and tostring(why):find('no EVE in the world',1,true),tostring(why))
print('sboxion_engine_test ok')
