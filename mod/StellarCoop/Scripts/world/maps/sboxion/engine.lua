-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Holds SBO Xion's copy of the black call of online/lobby/wiring.lua (Engine.black) and of the hidden, blocking actor
-- of vehicles/bike/stand.lua (Engine.wall): sboxion owns them; a fix here does not reach theirs.
-- SBO Xion's engine reads and writes (world/maps/sboxion/sboxion.lua's world), on the game thread: the zone's FName
-- index for the native request, the SBEnvControlVolume actors with their bActiveVolume, the world's streaming levels
-- through the three functions SB's exe exposes by name (GetWorldAssetPackageFName, IsLevelLoaded, IsLevelVisible),
-- the characters, the recovery's calls (world/maps/sboxion/recover.lua): EVE's place and movement mode, the put-back,
-- SB's black, SB's respawn request and the death screen, then a wall made, removed and swept
-- (world/maps/sboxion/walls/walls.lua) and a piece of SB in a room's doorway found, hidden and put back
-- (world/maps/sboxion/rooms/rooms.lua). sboxion.lua, recover.lua, walls.lua and rooms.lua call them only while EVE is
-- in SBO Xion or for a command.
-- bActiveVolume is a plain bool of ASBEnvControlVolume (+0x320 on build 26123051: its set-bit stub 0x14265b310 is
-- mov byte ptr [rcx+0x320],1). SB's env pass 0x1425c99b0, run from its registry's tick 0x142272930, skips a volume
-- whose byte is 0 each time it runs, so a write needs no call.
local U=require('core.unreal')
local N=require('core.player')
local Actors=require('core.actors')
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
-- EVE's place, yaw, movement mode, her world's time and her address, all from one EVE in one call; nil with no EVE.
-- recover.lua reads her through this alone: core/where.lua's me() is refreshed after sboxion.tick in main/pass.lua,
-- so it is one pass old. mode is CharacterMovement.MovementMode (EMovementMode: 1 Walking, 2 NavWalking, 3 Falling),
-- nil with no movement component. time is UGameplayStatics::GetTimeSeconds (exec 0x14475bc80 on build 26123051: the
-- context's world, then the float at world +0x748).
function Engine.move()
    local e=N.her()
    if not e then return nil end
    local at,turn=U.value_of(e:K2_GetActorLocation()),U.value_of(e:K2_GetActorRotation())
    local move=U.valid(e.CharacterMovement)
    return {at={X=at.X,Y=at.Y,Z=at.Z},yaw=turn.Yaw,mode=move and move.MovementMode or nil,
        time=U.find('/Script/Engine.Default__GameplayStatics'):GetTimeSeconds(e),pawn=U.address(e)}
end
-- Puts EVE at a place facing yaw; false when the game refused. K2_TeleportTo's exec 0x1446b65a0 calls the actor's
-- vtable +0x548 with (location, rotation, 0, 0): the two zeros leave the engine's test of the spot on, so the call
-- can refuse. Then StopMovementImmediately (exec 0x14488dd80, a jump to the movement component's vtable +0x440), so a
-- fall's speed does not go on at the new place. No stop call follows a refusal. The movement mode is left alone.
function Engine.put(at,yaw)
    local e=eve()
    if e:K2_TeleportTo({X=at.X,Y=at.Y,Z=at.Z},{Pitch=0,Yaw=yaw,Roll=0})==false then return false end
    local move=U.valid(e.CharacterMovement)
    if move then move:StopMovementImmediately() end
    return true
end
-- SB's black over a put-back: USBBlueprintLibrary::LoadingScreenFadeAuto (exec 0x1426641e0 on build 26123051). It
-- reads the time the black stands, then a start block and an end block (each a duration and the two values the
-- widget's fade runs between), then a tag. Its impl 0x14c91ad10 is the one SB's own fall warp calls for its fade
-- (0x141b1b8e0, FSBActorShowFadeUI::Execute), with a start block from 0 to 1 and an end block from 1 to 0. Here the
-- widget fades in over fade s, stands hold s and fades out over out s: SB's two blocks there, with its tag 0
-- (ESBUILoadingScreenTag None). With fade 0 it is full inside the call (start 0 s, 1 to 1, the block SB's move
-- 0x141bb1300 starts its own black with: StartFade 0x1424eb950 sets the end value at once for 0 s). SB's loading
-- controller ends it by itself (its tick 0x1424ea330 counts hold from the end of the fade-in). The call returns the
-- black's FGuid, four ints A, B, C and D (the property list of its struct data 0x146dde670). true when SB made the
-- black, false when it made none (the exec gives a zero GUID with no UI manager and so does CreateLoadingScreen
-- 0x1424ebd00 with no widget), nil when the GUID did not read. A raise of the call itself is the caller's to take.
function Engine.black(hold,fade,out)
    local id=U.find('/Script/SB.Default__SBBlueprintLibrary'):LoadingScreenFadeAuto(hold,fade,fade>0 and 0 or 1,1,out,
        1,0,0)
    local read,up=pcall(function()
        local g=U.value_of(id)
        return (g.A|g.B|g.C|g.D)~=0 -- Raises on a field that is no integer: the GUID did not read.
    end)
    if read then return up end
end
-- The respawn's pieces: the SB player controller (or nil), whether the game is standalone and SB's in-place respawn
-- of the actor of GUID me. ServerRequest_ActorRespawn's exec 0x1427639f0 reads an int and a bool and calls the
-- controller's vtable +0x1488 (0x1423bf600), which queues the job FSBActorRespawn. With the bool false the job's
-- Simulate 0x141b10b30 does not move the actor to a camp. It reads no zone type.
function Engine.controller() return N.controller() end
function Engine.standalone(pc)
    return U.find('/Script/Engine.Default__KismetSystemLibrary'):IsStandalone(pc)==true
end
function Engine.respawn(pc,me) pc:ServerRequest_ActorRespawn(me,false) end
-- The death screen (core/unreal.lua's death_screen), kept while its widget lives. screen(look): true while one of its
-- animations plays, false when none does, nil with no widget; it is looked for only when look is true, since the
-- search walks the object array. hide(): hides the kept widget and returns the call that shows it again as it was,
-- or nil with no widget.
local HIDDEN=2 -- ESlateVisibility Hidden.
local dead_screen=nil
function Engine.screen(look)
    if not U.valid(dead_screen) then dead_screen=look and U.death_screen() or nil end
    if not dead_screen then return nil end
    return dead_screen:IsAnyAnimationPlaying()==true
end
function Engine.hide()
    local s=U.valid(dead_screen)
    if not s then return nil end
    local was=s:GetVisibility()
    s:SetVisibility(HIDDEN)
    return function() if U.valid(s) then s:SetVisibility(was) end end
end
-- A wall: core/actors.lua's plain Actor whose root is one StaticMeshComponent showing the engine's cube, hidden in game
-- and scaled to the box. The cube, /Engine/BasicShapes/Cube, is in memory in SBO Xion: 38 StaticMeshActors of the
-- kept, always loaded level E04_NAVI_VOL show it. Its simple collision is one box of 100 cm a side, so the scale is
-- the size over 100 and nothing is cooked. The component then gets SB's collision profile SB_InvisiblewallIgnoreCamera
-- (DefaultEngine.ini of build 26123051: object type BlockVolume, ECC_GameTraceChannel7; it ignores Visibility, Camera,
-- PhysicsBody, Vehicle, Destructible, PhysicsStatic, Projectile, EventMoveObject, DragonIK and Item and blocks the
-- rest, EVE's capsule channel PawnCollision among them). SB's own BP_BlockWall sets that profile on its PM_Pawn with
-- the same call, SetCollisionProfileName(name, true), in statement 58 of its construction script. CanCharacterStepUpOn
-- is ECB_No, as on PM_Pawn. A wall is SB's profile on an engine actor. It is not SB's blueprint: a spawned
-- BP_BlockWall_C runs that script, which builds its mesh from two spline components the cooked class has no template
-- for, so it comes out with no collision.
-- The order of the two collision calls is the engine's, read on build 26123051. core/actors.lua hands the actor over
-- with its collision off and the component closed (NoCollision), so the component was registered with no body.
-- SetActorEnableCollision (exec 0x1446b97c0, then 0x143f6eba0) sets the actor's bit and calls each component's
-- vtable +0x398. The component's handler 0x144495e20 updates the body's filter and makes no body. The profile call
-- (exec 0x1448f0300, the component's vtable +0x670: 0x144145240, then 0x144495cf0) reads the collision before and
-- after through 0x14441e250, which answers NoCollision while the owner's collision is off. It makes the body
-- (0x1440e84c0) only when the two differ. So the actor's collision goes on first, over a component that blocks
-- nothing yet. The profile call then opens the component and makes its body.
-- b: {at={X,Y,Z} the box's centre, yaw of its long side, size={X length, Y thickness, Z height}} in cm and degrees.
-- The profile's name is looked up, never added. The cube must be on the component. SetStaticMesh (0x1441449f0)
-- refuses a component that is registered and of Static mobility (its byte +0x173 is 0) once the world plays, with
-- the text "Calling SetStaticMesh on '{0}' but Mobility is Static." core/actors.lua adds the component registered
-- and a StaticMeshComponent is Static by its class, so its call set no mesh: in the first game run all 145 walls
-- failed there. So the wall makes the component Movable first (SetMobility, exec 0x14490a6c0, the component's vtable
-- +0x520), then sets the cube itself. The component must read back SB's object type. Returns core/actors.lua's
-- display with read, that read-back as text. Raises, with no actor left, when a step fails.
local CUBE='/Engine/BasicShapes/Cube.Cube'
local MOVABLE=2 -- EComponentMobility::Movable (Static 0, Stationary 1).
local PROFILE='SB_InvisiblewallIgnoreCamera'
local BLOCK_VOLUME=20 -- ECC_GameTraceChannel7, named BlockVolume in SB's DefaultEngine.ini.
function Engine.wall(b)
    local name=U.value_of(FName(PROFILE,EFindName.FNAME_Find))
    assert(U.text(name):lower()==PROFILE:lower(),'the game has no name '..PROFILE)
    local d=Actors.spawn(eve():GetWorld(),b.at,{Pitch=0,Yaw=b.yaw,Roll=0},{path=CUBE,static=true})
    local ok,why=pcall(function()
        local c=d.mesh
        if not Actors.same(c.StaticMesh,CUBE) then
            c:SetMobility(MOVABLE)
            c:SetStaticMesh(Actors.resolve(CUBE,'/Script/Engine.StaticMesh'))
        end
        assert(Actors.same(c.StaticMesh,CUBE),'the cube is not on the component')
        d.actor:SetActorHiddenInGame(true)
        c:SetRelativeScale3D({X=b.size.X/100,Y=b.size.Y/100,Z=b.size.Z/100})
        c.CanCharacterStepUpOn=0 -- ECB_No
        d.actor:SetActorEnableCollision(true,false) -- SB's Actor takes (bNewActorEnableCollision, inFastUpdate).
        c:SetCollisionProfileName(name,true)
        local kind=c:GetCollisionObjectType()
        assert(kind==BLOCK_VOLUME,'SB\'s profile '..PROFILE..' did not take: object type '..tostring(kind))
        d.read=string.format('object type %s, collision %s',tostring(kind),c:K2_IsCollisionEnabled() and 'on' or 'off')
    end)
    if not ok then
        Actors.remove(d)
        error(why,0)
    end
    return d
end
-- A wall of wall() gone: true when its actor was still the one made and K2_DestroyActor was called, false when it is
-- gone already, with its world or before. Never a call on another object.
function Engine.unwall(d)
    if not Actors.same(d.actor,d.path) then return false end
    Actors.remove(d)
    return true
end
-- A wall an earlier Lua load made, by its actor's path: destroyed, and true, only while that actor's root still shows
-- the cube.
function Engine.wall_swept(path) return Actors.sweep(path,CUBE)==true end
-- A room's pieces (world/maps/sboxion/rooms/rooms.lua): a component of one of SB's art sublevels, or one instance of
-- an instanced component, in a room's doorway. All of it was read on build 26123051. None of it has run in game.
-- The path. The level dumps give a component's outers: the package /Game/Art/BG/WorldMap/SubLevel/E04/<sublevel>,
-- its World of the same name, the Level PersistentLevel, the actor, the component. SBO Xion's level lists the
-- sublevel by that package name, so the path is <package>.<sublevel>:PersistentLevel.<actor>.<component>, the shape
-- the day table's volumes are matched by.
-- A whole component. SetVisibility (exec 0x14490b360, then 0x14410dfb0) flips the component's visible bit and calls
-- its vtable +0x478, a jump to MarkRenderStateDirty 0x14408e490. Neither tests the mobility. The engine makes the
-- render state again at the frame's end: 0x1440e7a10 adds the primitive to the scene only when 0x1440e8fb0 says so,
-- whose ShouldRender 0x14410de00 needs that bit. So the hidden component has no scene proxy and its baked lightmap is
-- not drawn. The shadow baked onto its neighbours stays. SetCollisionEnabled (exec 0x1448f0470, the component's
-- vtable +0x668: 0x144495c70) writes the value into the body instance (0x14441d820, which also names its profile
-- Custom and keeps its responses), then 0x1440e84c0 ends the physics state: ShouldCreatePhysicsState 0x1440e9000
-- answers no with NoCollision, so OnDestroyPhysicsState 0x144143960 ends the body (0x14441f950). The value read
-- before, written back, makes the body again (0x14408de70). The reads: IsVisible (exec 0x14490b4d0, vtable +0x460:
-- 0x14410df80, the visible bit while the component is not hidden in game) and GetCollisionEnabled (exec 0x1448ede80,
-- vtable +0x508: 0x144496280, the body instance's value while the actor's collision is on).
-- An instance. UpdateInstanceTransform (exec 0x14478d690) calls the component's vtable +0x988: for the hierarchical
-- class 0x14424e0c0, which calls the instanced class's 0x14427eeb0. That one writes the instance's matrix and, with
-- the physics state made, calls 0x14427ed70: a scale of 0.0001 or less on each axis ends the instance's body and
-- deletes it, a larger one makes a new body. So an instance is hidden where it stands with a scale of nothing: the
-- engine's own state for an instance with no body. RemoveInstance is never used: it moves the last instance into the
-- hole and the baked lightmap rows go by index. What is drawn then depends on the component. When the place is
-- unchanged, the instance is in the built tree and the render data kept its CPU copy, the hierarchical class queues
-- the new matrix for the instance buffer and marks the render state dirty: the tree cooked with the level stays. The
-- CPU copy is kept (0x144281ec0) by a component that casts a shadow and affects distance field lighting while
-- r.GenerateMeshDistanceFields is on, as SB's DefaultEngine.ini sets it. 4 of the 9 instanced components of
-- rooms/list.lua store CastShadow false. Without the CPU copy the class calls BuildTreeIfOutdated 0x1442511b0, which
-- starts an async build of a new tree and a new instance buffer from the instances (0x144251400, taken over by
-- 0x144250d90 some frames later): the instance is drawn until then. The queued matrix is applied only with the CPU
-- copy (0x144251c90, the scene proxy's making, and 0x144251400). The reads: GetInstanceCount (exec 0x14478cde0, the
-- instance count at +0x5e8, the one both transform calls test the index against) and GetInstanceTransform (exec
-- 0x14478da10, then 0x14427e150: the matrix as an FTransform).
local E04,ART='/Game/Art/BG/WorldMap/SubLevel/E04/','/Game/Art/BG/Actor/'
local SOLID,MANY='/Script/Engine.StaticMeshComponent','/Script/Engine.InstancedStaticMeshComponent'
local NEAR,NOTHING=1,0.0001 -- cm a row's place may differ by on each axis; the engine's scale of no instance.
-- Instance index of c inside its component as ten numbers: the rotation's X, Y, Z and W, the place, the scale.
local function instance(c,index)
    local t={}
    assert(c:GetInstanceTransform(index,t,false)==true and t.Rotation and t.Translation and t.Scale3D,
        'its instance did not read')
    local turn,at,scale=U.value_of(t.Rotation),U.value_of(t.Translation),U.value_of(t.Scale3D)
    return {turn.X,turn.Y,turn.Z,turn.W,at.X,at.Y,at.Z,scale.X,scale.Y,scale.Z}
end
local function nothing(n)
    return math.abs(n[8])<=NOTHING and math.abs(n[9])<=NOTHING and math.abs(n[10])<=NOTHING
end
-- Instance index of c at the ten numbers n with its scale times by (0: nothing): true when the engine took it.
local function placed(c,index,n,by)
    return c:UpdateInstanceTransform(index,{Rotation={X=n[1],Y=n[2],Z=n[3],W=n[4]},
        Translation={X=n[5],Y=n[6],Z=n[7]},Scale3D={X=n[8]*by,Y=n[9]*by,Z=n[10]*by}},false,true,true)==true
end
-- The piece of a row of rooms.lua ({level=, actor=, component=, index=, mesh=, at=, count=}): {row=, c=<the
-- component>, path=<as it reads>}. Raises when no object is at the row's path, when its class is not the row's kind
-- (index -1: a StaticMeshComponent that holds no instances), when it shows another mesh, when it stores a place more
-- than NEAR from the row's or holds another number of instances. So a game update that reorders a level hides no
-- other piece. Names are compared without their case: the game gives one back in the case it first met.
function Engine.piece(row)
    local c=U.valid(StaticFindObject(E04..row.level..'.'..row.level..':PersistentLevel.'..row.actor..'.'
        ..row.component))
    assert(c,'not found')
    local many=c:IsA(U.find(MANY))==true
    assert(c:IsA(U.find(SOLID))==true and many==(row.index>=0),'not the class listed')
    local mesh=U.valid(c.StaticMesh)
    assert(mesh and path_of(mesh):lower()==(ART..row.mesh..'.'..row.mesh:match('[^/]+$')):lower(),'another mesh')
    local at
    if many then
        assert(c:GetInstanceCount()==row.count,'another number of instances')
        local n=instance(c,row.index)
        at={X=n[5],Y=n[6],Z=n[7]}
    else at=U.value_of(c.RelativeLocation) end
    assert(math.abs(at.X-row.at.X)<=NEAR and math.abs(at.Y-row.at.Y)<=NEAR and math.abs(at.Z-row.at.Z)<=NEAR,
        'another place')
    return {row=row,c=c,path=path_of(c)}
end
-- Hides a piece of piece(). What it reads first is kept in p.was, numbers only, for piece_back() and for rooms.lua's
-- store: a whole component's visible bit (1 or 0) and collision value, an instance's ten numbers. Raises when the
-- piece reads hidden already (nothing to put back would be known), when the engine refuses the instance and when
-- the piece does not read hidden afterwards. p.was is set before the first write, so piece_back() undoes a hide that
-- raised halfway.
function Engine.piece_out(p)
    local c,index=p.c,p.row.index
    if index<0 then
        local was={c:IsVisible()==true and 1 or 0,tonumber(U.value_of(c:GetCollisionEnabled()))}
        assert(was[1]==1,'it is hidden already')
        assert(was[2],'its collision did not read')
        p.was=was
        c:SetVisibility(false,false)
        c:SetCollisionEnabled(0) -- ECollisionEnabled NoCollision.
        assert(c:IsVisible()~=true and tonumber(U.value_of(c:GetCollisionEnabled()))==0,'it did not hide')
    else
        local was=instance(c,index)
        assert(not nothing(was),'it is hidden already')
        p.was=was
        assert(placed(c,index,was,0),'the engine refused its instance')
        assert(nothing(instance(c,index)),'it did not hide')
    end
end
-- Puts a piece back as p.was says: true. false, with nothing called, when it has no p.was or when its object is gone
-- (with its world) or is another one. An instance that does not read hidden is left as it is, so the numbers an
-- earlier game run kept change nothing in a new world.
function Engine.piece_back(p)
    local c,was=p.was and Actors.same(p.c,p.path),p.was
    if not c then return false end
    if p.row.index<0 then
        c:SetVisibility(was[1]==1,false)
        c:SetCollisionEnabled(was[2])
    elseif nothing(instance(c,p.row.index)) then
        assert(placed(c,p.row.index,was,1),'the engine refused its instance')
    end
    return true
end
return Engine
