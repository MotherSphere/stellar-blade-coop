-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's engine reads (world/maps/sboxion/engine.lua) over fake UE4SS objects: the zone's FName index only for a
-- name the game has made; each env volume's path with its bActiveVolume read and written on the actor, a dead actor
-- raising; the streaming levels by their package's last part with what IsLevelLoaded and IsLevelVisible say; the
-- probes read again on the kept objects, a gone one reading not loaded; the characters' names, classes and places,
-- EVE told apart by her address, one that does not read given as unread; no EVE raising. Then
-- the recovery's calls (world/maps/sboxion/recover.lua): move gives EVE's place, yaw, movement mode, world time and
-- address from one EVE with each read made once, nil with no EVE; put teleports then stops her movement, with no stop
-- call after a refusal; the respawn's controller, standalone test and call; the death screen found once, read
-- playing or not, hidden and shown again as it was (4, not 0), a dead widget left as it is; the widget told once that
-- its revival ended, by SB's event name, a dead widget looked for again and not told. SB's black, with the call
-- case of tests/lua/online/lobby/wiring_test.lua and the raise of tests/lua/online/lobby/arrival_test.lua for this
-- module's copy: one LoadingScreenFadeAuto call with the hold, the fade-in from 0 to 1, the fade-out from 1 to 0 and
-- tag 0; with a fade-in of 0 the start block is 0 s from 1 to 1; true for a GUID that is not zero, false for a zero
-- GUID, nil for one that does not read; a raise of the call is not caught. The walls of 24 November 2026 are gone: no
-- wall call is left. Then a piece of SB in a room's doorway
-- (world/maps/sboxion/rooms/rooms.lua): found by its sublevel, actor and component names and taken only when its
-- class, mesh, place and instance count are the row's; a whole component hidden with SetVisibility(false, false) and
-- SetCollisionEnabled(0) after both values are read; an instance scaled to nothing where it stands through
-- UpdateInstanceTransform, its ten numbers read first; a piece that reads hidden already, an instance the engine
-- refuses and a call that changes nothing each raise; the put-back writes what was read, leaves an instance alone that
-- is not hidden and calls nothing on an object that is gone or another one. Then SB's Tetrapod interior
-- (world/maps/sboxion/tetrapod.lua): its static mesh parts made solid and put back as SB ships them.
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

-- characters: every SBCharacter's name, its class's name, its place and whether it is EVE (her own object, by
-- address); one whose reads raise is given as unread with no place.
local function character(name,class,at,address)
    return object({GetFName=function() return fname(name) end,GetAddress=function() return address end,
        GetClass=function() return class and object({GetFName=function() return fname(class) end}) end,
        K2_GetActorLocation=function() return object({type=function() return 'RemoteUnrealParam' end,
            get=function() return at end}) end})
end
eve.GetAddress=function() return 0x5000 end
actors.SBCharacter={character('CH_P_EVE_01_Blueprint_C_0','CH_P_EVE_01_Blueprint_C',{X=1,Y=2,Z=3},0x5000),
    character('Animal_Rat_C_3','Animal_Rat_C',{X=-8061,Y=7181,Z=280},0x5100),
    character('N_Gone_C_1',nil,{X=0,Y=0,Z=0},0x5200),object({GetFName=function() error('it is gone') end})}
local chars=Engine.characters()
assert(#chars==4 and chars[1].name=='CH_P_EVE_01_Blueprint_C_0' and chars[1].class=='CH_P_EVE_01_Blueprint_C'
    and chars[1].eve==true and chars[1].at.X==1 and chars[1].at.Y==2 and chars[1].at.Z==3,'EVE, with her place')
assert(chars[2].name=='Animal_Rat_C_3' and chars[2].class=='Animal_Rat_C' and chars[2].eve==false
    and chars[2].at.X==-8061 and chars[2].at.Y==7181 and chars[2].at.Z==280,'Another character, with its place')
assert(chars[3].name=='?' and chars[3].class=='unread' and chars[3].at==nil and chars[3].eve==false
    and chars[4].name=='?' and chars[4].class=='unread' and chars[4].at==nil,'No class or a read that raises: unread')

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
-- revived: the kept widget is told the event SB's revival animation ends with, by the name SB's dead HUD compares.
local notes={}
dead.NotifyBlueprint=function(_,name) notes[#notes+1]=name end
assert(Engine.revived()==true and #notes==1 and notes[1]=='FinishComaRevivalAnimation' and looks==1,notes[1])
dead.dead=true
assert(Engine.screen(false)==nil and Engine.screen(true)==nil and looks==2,'A dead widget is looked for again')
assert(Engine.revived()==nil and looks==3 and #notes==1,'A dead widget is looked for again and not told')
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

-- A mesh object at path, for the pieces' meshes.
local function mesh_at(path)
    return object({GetFullName=function() return 'StaticMesh '..path end,
        IsA=function(_,c) return c.path=='/Script/Engine.StaticMesh' end})
end
assert(Engine.wall==nil and Engine.unwall==nil and Engine.wall_swept==nil,'No wall call is left')

-- A room's pieces. The fake sublevel holds one whole component and one instanced component of three instances.
local E04,ACTORS='/Game/Art/BG/WorldMap/SubLevel/E04/','/Game/Art/BG/Actor/'
local DOOR=E04..'E04_Area02_Object_F_01.E04_Area02_Object_F_01:PersistentLevel.Actor_0.StaticMeshComponent_6'
local RUBBLE=E04..'E04_Area02_Object_F_01.E04_Area02_Object_F_01:PersistentLevel.Actor_0.'
    ..'HierarchicalInstancedStaticMeshComponent_34'
local function component(path,class,mesh)
    local c=object({calls={},StaticMesh=mesh_at(ACTORS..mesh..'.'..mesh:match('[^/]+$')),
        GetFullName=function() return class..' '..path end,
        IsA=function(_,x)
            return x.path=='/Script/Engine.StaticMeshComponent'
                or x.path=='/Script/Engine.InstancedStaticMeshComponent' and class~='StaticMeshComponent'
        end})
    statics[path]=c
    return c
end
local door=component(DOOR,'StaticMeshComponent','Architecture/Door/031_A_SM')
door.RelativeLocation,door.visible,door.collision=value({X=-457.874,Y=-486.76,Z=-79.113}),true,3
function door:IsVisible() return self.visible end
function door:GetCollisionEnabled() return self.collision end
function door:SetVisibility(on,children)
    self.calls[#self.calls+1]='visible '..tostring(on)..' '..tostring(children)
    if not self.stuck then self.visible=on end
end
function door:SetCollisionEnabled(kind)
    self.calls[#self.calls+1]='collision '..tostring(kind)
    self.collision=kind
end
local rubble=component(RUBBLE,'HierarchicalInstancedStaticMeshComponent','Deco/Rubble/027_A_SM')
rubble.instances={{0,0,0.6,0.8,-314.739,-635.928,-78.641,1.227,1.227,0.481},
    {0,0,0,1,-503.915,-283.841,-78.641,1.227,1.227,0.481},{0,0,1,0,-731.058,-85.583,-78.641,1.227,1.227,0.481}}
function rubble:GetInstanceCount() return #self.instances end
function rubble:GetInstanceTransform(index,out,world)
    assert(world==false,'The place inside the component, not in the world')
    local n=self.instances[index+1]
    if not n or self.unread then return false end
    out.Rotation,out.Translation=value({X=n[1],Y=n[2],Z=n[3],W=n[4]}),value({X=n[5],Y=n[6],Z=n[7]})
    out.Scale3D=value({X=n[8],Y=n[9],Z=n[10]})
    return true
end
function rubble:UpdateInstanceTransform(index,t,world,dirty,teleport)
    assert(world==false and dirty==true and teleport==true,'Inside the component, the render state dirty')
    self.calls[#self.calls+1]='instance '..index
    if self.refuses then return false end
    if not self.stuck then
        self.instances[index+1]={t.Rotation.X,t.Rotation.Y,t.Rotation.Z,t.Rotation.W,t.Translation.X,t.Translation.Y,
            t.Translation.Z,t.Scale3D.X,t.Scale3D.Y,t.Scale3D.Z}
    end
    return true
end
local function row(component_name,index,mesh,x,y,z,count)
    return {level='E04_Area02_Object_F_01',actor='Actor_0',component=component_name,index=index,mesh=mesh,
        at={X=x,Y=y,Z=z},count=count}
end
local DOOR_ROW=row('StaticMeshComponent_6',-1,'Architecture/Door/031_A_SM',-457.874,-486.76,-79.113)
local RUBBLE_ROW=row('HierarchicalInstancedStaticMeshComponent_34',1,'Deco/Rubble/027_A_SM',-503.915,-283.841,-78.641,
    3)
local function refused(r,text)
    local fine,said=pcall(Engine.piece,r)
    assert(not fine and tostring(said):find(text,1,true),text..': '..tostring(said))
end
-- piece: the object at the row's path, with the path it reads.
local dp,rp=Engine.piece(DOOR_ROW),Engine.piece(RUBBLE_ROW)
assert(dp.c==door and dp.path==DOOR and dp.row==DOOR_ROW and rp.c==rubble and rp.path==RUBBLE)
-- piece_not_found: no object, or a dead one, at the path.
statics[E04..'E04_Area02_Object_F_01.E04_Area02_Object_F_01:PersistentLevel.Actor_0.StaticMeshComponent_7']=
    object({dead=true})
refused(row('StaticMeshComponent_7',-1,'Architecture/Door/031_A_SM',0,0,0),'not found')
-- piece_class: a whole row names no instanced component and an instance row names one.
refused(row('HierarchicalInstancedStaticMeshComponent_34',-1,'Deco/Rubble/027_A_SM',0,0,0),'not the class listed')
refused(row('StaticMeshComponent_6',0,'Architecture/Door/031_A_SM',-457.874,-486.76,-79.113,1),
    'not the class listed')
-- piece_mesh, piece_place, piece_count: another mesh, a place more than 1 cm off, another number of instances.
refused(row('StaticMeshComponent_6',-1,'Architecture/Door/031_B_SM',-457.874,-486.76,-79.113),'another mesh')
refused(row('StaticMeshComponent_6',-1,'Architecture/Door/031_A_SM',-457.874,-485.7,-79.113),'another place')
refused(row('HierarchicalInstancedStaticMeshComponent_34',1,'Deco/Rubble/027_A_SM',-503.915,-283.841,-76.5,3),
    'another place')
refused(row('HierarchicalInstancedStaticMeshComponent_34',1,'Deco/Rubble/027_A_SM',-503.915,-283.841,-78.641,9),
    'another number of instances')
assert(Engine.piece(row('StaticMeshComponent_6',-1,'Architecture/Door/031_A_SM',-457,-487.5,-79.9)).c==door,
    'A place within 1 cm on each axis is the row\'s')
-- piece_name_case: the game gives a name back in the case it first met.
door.StaticMesh=mesh_at((ACTORS..'Architecture/Door/031_A_SM.031_A_SM'):upper())
assert(Engine.piece(DOOR_ROW).c==door)
rubble.unread=true
refused(RUBBLE_ROW,'its instance did not read')
rubble.unread=nil
assert(#door.calls==0 and #rubble.calls==0,'A look changes nothing')
-- hide_whole: both values read first, then SetVisibility(false, false) and SetCollisionEnabled(0).
Engine.piece_out(dp)
assert(table.concat(door.calls,',')=='visible false false,collision 0' and door.visible==false and door.collision==0)
assert(dp.was[1]==1 and dp.was[2]==3,'What was read is kept')
-- hide_whole_twice: a component that reads hidden already has no values to keep.
local again=Engine.piece(DOOR_ROW)
ok,why=pcall(Engine.piece_out,again)
assert(not ok and tostring(why):find('it is hidden already',1,true) and again.was==nil and #door.calls==2,
    tostring(why))
-- show_whole: what was read is written back.
assert(Engine.piece_back(dp)==true and door.visible==true and door.collision==3)
assert(table.concat(door.calls,',',3)=='visible true false,collision 3',table.concat(door.calls,',',3))
assert(Engine.piece_back(again)==false and #door.calls==4,'A piece never hidden is not called')
-- hide_whole_stuck: a call that changes nothing raises with the values kept, so the caller can put back.
door.stuck=true
local stuck=Engine.piece(DOOR_ROW)
ok,why=pcall(Engine.piece_out,stuck)
assert(not ok and tostring(why):find('it did not hide',1,true) and stuck.was[1]==1 and stuck.was[2]==3,tostring(why))
door.stuck=nil
assert(Engine.piece_back(stuck)==true and door.visible==true and door.collision==3)
-- A QueryOnly component (collision 1, the one Custom piece of D158) gets its own value back.
door.collision=1
local query=Engine.piece(DOOR_ROW)
Engine.piece_out(query)
assert(door.collision==0 and Engine.piece_back(query)==true and door.collision==1)
-- hide_instance: the ten numbers read first, then the same rotation and place with a scale of nothing.
Engine.piece_out(rp)
local n=rubble.instances[2]
assert(table.concat(rubble.calls,',')=='instance 1' and n[8]==0 and n[9]==0 and n[10]==0,'Scaled to nothing')
assert(n[4]==1 and n[5]==-503.915 and n[6]==-283.841 and n[7]==-78.641,'Where it stands')
assert(#rp.was==10 and rp.was[4]==1 and rp.was[5]==-503.915 and rp.was[8]==1.227 and rp.was[10]==0.481)
assert(rubble.instances[1][8]==1.227 and rubble.instances[3][8]==1.227,'The other instances are left alone')
assert(Engine.piece(RUBBLE_ROW).c==rubble,'A hidden instance still reads at its place')
-- hide_instance_twice: an instance that reads hidden already has no numbers to keep.
local twice=Engine.piece(RUBBLE_ROW)
ok,why=pcall(Engine.piece_out,twice)
assert(not ok and tostring(why):find('it is hidden already',1,true) and twice.was==nil and #rubble.calls==1,
    tostring(why))
-- show_instance: the ten numbers go back; an instance that is not hidden is left alone.
assert(Engine.piece_back(rp)==true and #rubble.calls==2 and rubble.instances[2][8]==1.227
    and rubble.instances[2][10]==0.481)
assert(Engine.piece_back(rp)==true and #rubble.calls==2,'An instance that is not hidden gets no call')
-- hide_instance_refused, hide_instance_stuck: the engine's no and a call that changes nothing both raise.
rubble.refuses=true
local no=Engine.piece(RUBBLE_ROW)
ok,why=pcall(Engine.piece_out,no)
assert(not ok and tostring(why):find('the engine refused its instance',1,true) and #no.was==10,tostring(why))
rubble.refuses,rubble.stuck=nil,true
ok,why=pcall(Engine.piece_out,no)
assert(not ok and tostring(why):find('it did not hide',1,true),tostring(why))
rubble.stuck=nil
-- show_gone: an object that is gone, or another one at the handle, is never called.
Engine.piece_out(rp)
Engine.piece_out(dp)
local calls=#door.calls+#rubble.calls
door.dead=true
rubble.GetFullName=function() return 'HierarchicalInstancedStaticMeshComponent /Game/O.O:PersistentLevel.A.B' end
assert(Engine.piece_back(dp)==false and Engine.piece_back(rp)==false and #door.calls+#rubble.calls==calls)
assert(rubble.instances[2][8]==0,'Left as it was')

-- ship: SB's Tetrapod interior made solid and put back. Each living static mesh part of the actor gets SB's own
-- collision profile BlockAll, by a name the game has made, with its overlaps updated; false gives NoCollision, the
-- profile SB ships it with; a dead part is not called; a part that keeps another profile is not counted; a profile
-- name the game has not made raises before any write; with no actor in memory (its level is not loaded) nothing is
-- written and the answer is nil.
local SHIP=BG..'E04_Area05_B_LD.E04_Area05_B_LD:PersistentLevel.BP_Env_TetraPod3_2'
local function part(stuck)
    local p=object({calls={},profile='NoCollision'})
    p.SetCollisionProfileName=function(self,name,overlaps)
        self.calls[#self.calls+1]=name:ToString()..' '..tostring(overlaps)
        if not stuck then self.profile=name:ToString() end
    end
    p.GetCollisionProfileName=function(self) return fname(self.profile,1) end
    return p
end
local floor,wall,gone,odd=part(),part(),part(),part(true)
gone.dead=true
local asked_class
statics[SHIP]=object({K2_GetComponentsByClass=function(_,class)
    asked_class=class.path
    return {floor,wall,gone,odd}
end})
made.BlockAll,made.NoCollision=77,78
assert(Engine.ship(true)==2 and asked_class=='/Script/Engine.StaticMeshComponent',tostring(asked_class))
assert(table.concat(floor.calls,', ')=='BlockAll true' and table.concat(wall.calls,', ')=='BlockAll true'
    and #gone.calls==0 and #odd.calls==1,table.concat(floor.calls,', '))
assert(Engine.ship(false)==3 and floor.calls[2]=='NoCollision true' and floor.profile=='NoCollision','As SB ships it')
made.BlockAll=nil
assert(not pcall(Engine.ship,true) and #floor.calls==2,'No such profile name in this game: nothing written')
made.BlockAll=77
statics[SHIP]=object({dead=true})
assert(Engine.ship(true)==nil and #floor.calls==2,'No actor in memory: nothing written')
statics[SHIP]=nil

-- No EVE: move gives nil, put raises.
package.loaded['core.player'].her=function() return nil end
assert(Engine.move()==nil)
assert(not pcall(Engine.put,{X=0,Y=0,Z=0},0))
print('sboxion_engine_test ok')
