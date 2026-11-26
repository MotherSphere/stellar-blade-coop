-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- What gun mode looks up, over a fake UE4SS (fake.lua) that counts its engine calls: UE4SS 3.0.1's StaticFindObject
-- and FindAllOf walk the object array, FindFirstOf too. Each case counts the finds of one walk that luke's gun mode
-- made each frame, each round or at each rifle out. It fails when that walk comes back.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Fake=dofile('tests/lua/fight/gunmode/fake.lua')
-- The laser sight needs Niagara's objects, which the fake lacks: here a laser that draws nothing.
package.loaded['fight.gunmode.laser']=function() return function() end,function() end end
local GunMode=require('fight.gunmode.mode')
local clock=100
os.clock=function() return clock end
local function frames(gun,n) for _=1,n do clock=clock+1/60; gun.tick() end end

-- The fake world with its engine calls counted: script (StaticFindObject of a /Script path), asset[path] (the other
-- StaticFindObject calls), first (FindFirstOf), all[class] (FindAllOf), load[path] (LoadAsset). The camera manager and
-- the trace library let the crosshair reach its traces.
local function world()
    local w=Fake.new(); w.install()
    FText=function(s) return s end
    local n={script=0,first=0,all={},asset={},load={}}
    w.n=n
    local find,first,all,load=StaticFindObject,FindFirstOf,FindAllOf,LoadAsset
    StaticFindObject=function(path,...)
        if type(path)~='string' then return find(path,...) end
        if path:sub(1,8)=='/Script/' then n.script=n.script+1 else n.asset[path]=(n.asset[path] or 0)+1 end
        return find(path)
    end
    FindFirstOf=function(class) n.first=n.first+1; return first(class) end
    FindAllOf=function(class)
        n.all[class]=(n.all[class] or 0)+1
        return all(class)
    end
    LoadAsset=function(path) n.load[path]=(n.load[path] or 0)+1; return load(path) end
    local valid=function() return true end
    w.pc.PlayerCameraManager={IsValid=valid,GetCameraLocation=function() return {X=0,Y=0,Z=0} end,
        GetCameraRotation=function() return {Pitch=0,Yaw=0,Roll=0} end,GetFOVAngle=function() return 45 end}
    return w
end
local function count(w,class) return w.n.all[class] or 0 end
local function quiet() return GunMode.new({log=function() end}) end
-- The rifle out through the command.
local function out(gun)
    clock=clock+1
    gun.toggle_now()
    assert(gun.state.on,'the rifle is out')
end

-- 1. No player controller (a map loading): FindFirstOf walks the object array, so once a second at most (468f7ab6).
do
    local w=world()
    FindFirstOf=function() w.n.first=w.n.first+1 end
    local gun=quiet()
    frames(gun,600)
    assert(w.n.first<=11,w.n.first..' FindFirstOf in 10 s')
    assert(w.n.first>=9,'still looked for once a second: '..w.n.first)
end

-- 2. The first rifle out on a map froze the game 100 to 340 ms (2026-11-21 test, 17a166fa): each asset not in memory
--    was looked for with UE4SS's StaticFindObject (a walk of the object array) and some were loaded on the frame. With
--    the soft path proven and the keep holding gun mode's assets, the rifle out, its arrival, the aim, the rounds
--    through reloads and the departure, twice, look for no asset with StaticFindObject (SB's data tables aside,
--    always in memory) and load none of the kept ones. The layer's rebuild takes a body already in memory
--    (Overlay.BASES[1] here) over loading one. The reload sounds, the cube and the morph effect are kept (b812f708).
local Overlay=require('fight.gunmode.overlay')
local Config=require('fight.gunmode.config')
local function typed(o) if o then o.type=o.type or function() return 'UObject' end end; return o end
-- The world of case 2: every kept asset in memory under its own path, the soft path and the keep faked.
local function kept_world()
    local U=require('core.unreal')
    local w=world()
    local mem={[Fake.RIFLE]=w.rifle}
    local cfg=Config.DEFAULTS
    local paths={Fake.BASE,'/Game/Mods/NGM/BP_NGM_CamMod.BP_NGM_CamMod_C',cfg.cube_mesh,cfg.muzzle_fx,cfg.morph_fx}
    for _,c in pairs(Overlay.CLIPS) do paths[#paths+1]=c end
    for _,e in ipairs(cfg.reload_sounds) do paths[#paths+1]=e[1] end
    for _,p in ipairs(paths) do
        mem[p]=mem[p] or w.find(p)
            or {IsValid=function() return true end,GetFullName=function() return 'Object '..p end}
    end
    local seen=w.find
    function w.find(path) return mem[path] or seen(path) end
    local registry=w.find('/Script/AssetRegistry.Default__AssetRegistryHelpers')
    local get=registry.GetAsset
    registry.GetAsset=function(o,d)
        local path=d.ObjectPath:ToString(); w.n.load[path]=(w.n.load[path] or 0)+1; return get(o,d)
    end
    local object_at=U.object_at
    U.object_at=function(path) return typed(mem[path] or seen(path)),true end
    w.keep=dofile('tests/lua/core/keep_fake.lua')(function(path) return typed(mem[path] or seen(path)),true end)
    function w.done() U.object_at,registry.GetAsset=object_at,get; require('core.keep').reset() end
    return w
end
do
    local Keep=require('core.keep')
    local w=kept_world()
    local gun=quiet()
    Keep.slow(); w.keep.settle()
    assert(Keep.serves(Overlay.CLASS) and Keep.serves(Overlay.CLIPS.aim),'the keep serves the layer')
    frames(gun,1)
    w.n.asset,w.n.load={},{}
    for _=1,2 do
        out(gun)
        frames(gun,60)
        w.pawn.bTPSMode,w.down.RightMouseButton=true,true
        frames(gun,60)
        w.down.LeftMouseButton=true
        frames(gun,600)
        w.down.LeftMouseButton=nil
        w.pawn.bTPSMode,w.down.RightMouseButton=false,nil
        frames(gun,30)
        clock=clock+1; gun.toggle_now(); frames(gun,60)
        assert(not gun.state.on,'the rifle is away')
    end
    local walked={}
    for path,c in pairs(w.n.asset) do
        if not path:find('^/Game/Local/Data/') then walked[#walked+1]=path..' x'..c end
    end
    table.sort(walked)
    assert(#walked==0,'assets looked for with StaticFindObject: '..table.concat(walked,', '))
    local loaded={}
    for path,c in pairs(w.n.load) do if Keep.wanted(path) then loaded[#loaded+1]=path..' x'..c end end
    table.sort(loaded)
    assert(#loaded==0,'kept assets loaded on the frame: '..table.concat(loaded,', '))
    assert(w.mesh.SkeletalMesh==w.body,'her own body back after the rebuild')
    w.done()
end

-- 3. A layer clip the installed pak lacks (an older zNGMSpike_P) is looked up once a Lua load, not at each frame that
--    asks for it (6057c7a5). The same for a rebuild body the paks lack: with her in CH_P_EVE_29 the layer's rebuild
--    asks for Overlay.BASES[2] at each rifle out, which no pak of 26123051 holds (3ae65f67's message).
do
    local w=world()
    local gun=quiet()
    frames(gun,1)
    out(gun)
    frames(gun,120)
    local carry=Overlay.CLIPS.carry
    assert(gun.state.layer==true,'the layer is on')
    assert((w.n.load[carry] or 0)==1,'the missing carry clip loaded '..tostring(w.n.load[carry])..' times')
    assert((w.n.asset[carry] or 0)<=2,'the missing carry clip looked up '..tostring(w.n.asset[carry])..' times')
    clock=clock+1; gun.toggle_now(); frames(gun,60)
    assert(not gun.state.on,'the rifle is away')
    w.mesh.SkeletalMesh=w.base
    local missing=Overlay.BASES[2]
    local first
    for i=1,3 do
        out(gun); frames(gun,30)
        assert(gun.state.layer==false,'no layer without a second body')
        clock=clock+1; gun.toggle_now(); frames(gun,30)
        if i==1 then first=w.n.asset[missing] or 0 end
    end
    assert((w.n.load[missing] or 0)==1,'the missing body loaded '..tostring(w.n.load[missing])..' times')
    assert(w.n.asset[missing]==first,('the missing body looked up %d times at the first rifle out, %d after three')
        :format(first,w.n.asset[missing] or 0))
end

-- 4. The camera modifier is tried once a rifle out (b812f708): a throw while adding it (here the camera manager has
--    no AddNewCameraModifier) no longer looks the class up again on each frame. The next rifle out tries again.
do
    local w=world()
    local CAMMOD='/Game/Mods/NGM/BP_NGM_CamMod.BP_NGM_CamMod_C'
    w.paths[CAMMOD]={IsValid=function() return true end,GetFullName=function() return 'Class '..CAMMOD end}
    local gun=quiet()
    frames(gun,1)
    out(gun)
    frames(gun,600)
    local n=w.n.asset[CAMMOD] or 0
    assert(n>=1 and n<=2,n..' camera modifier class lookups in 600 frames')
    clock=clock+1; gun.toggle_now(); frames(gun,60)
    out(gun); frames(gun,60)
    assert((w.n.asset[CAMMOD] or 0)>n,'the next rifle out tries again')
end

-- 5. No reticle text in the HUD: its text blocks are walked for at the rifle out and after firing mode, at most once
--    in 10 s (468f7ab6, b812f708), not once a second while the rifle is out. No walk in firing mode: one at its start
--    landed where she watches her body turn to the front. Only the reticle's round slot is looked for, with no list
--    of the bottom-left texts that grew at each walk (a5556d87).
do
    local w=world()
    local logs={}
    local gun=GunMode.new({log=function(m) logs[#logs+1]=m end})
    frames(gun,1)
    out(gun)
    frames(gun,60)
    assert(count(w,'TextBlock')==1,count(w,'TextBlock')..' text walks at the rifle out')
    frames(gun,60*60)
    assert(count(w,'TextBlock')==1,count(w,'TextBlock')..' text walks in 60 s carried')
    for i=1,2 do -- (two aims 4 s apart: one walk after the first, none after the second within 10 s)
        w.pawn.bTPSMode,w.down.RightMouseButton=true,true
        frames(gun,120)
        assert(count(w,'TextBlock')==i,count(w,'TextBlock')..' text walks in firing mode '..i)
        w.pawn.bTPSMode,w.down.RightMouseButton=false,nil
        frames(gun,120)
        assert(count(w,'TextBlock')==2,count(w,'TextBlock')..' text walks after aim '..i)
    end
    local said=table.concat(logs,'\n')
    assert(not said:find('bottom-left',1,true),said)
end

-- 6. The laser sight's assets (fight/gunmode/laser.lua's Niagara system and parameter collection) are asked of the
--    keep with the others (e0038fcc). Nothing held them between two aims: after a collection each aim start loaded
--    the system on its frame.
do
    local Keep=require('core.keep')
    local src=assert(io.open('mod/StellarCoop/Scripts/fight/gunmode/laser.lua')):read('a')
    local base=assert(src:match("local base='([^']+)'"),'laser.lua names its assets\' folder')
    local want,wanted=Keep.want,{}
    Keep.want=function(paths) for _,p in ipairs(paths) do wanted[p]=true end end
    world()
    quiet()
    Keep.want=want
    local n=0
    for name in src:gmatch("resource%('([%w_]+)'%)") do
        n=n+1
        assert(wanted[base..name..'.'..name],'the keep does not hold the laser\'s '..name)
    end
    assert(n==2,n..' laser assets')
end

-- 7. A drone near EVE is hidden at the rifle out and held: no look while it lives. The rifle out again finds the same
--    drone with no list of every drone (e9b6f439), unless that drone is now 3000 or more from her (1cad571f). A drone
--    that goes is looked for again.
do
    local w=world()
    local function drone(name,x)
        local part={IsValid=function() return true end,bHiddenInGame=false,
            SetHiddenInGame=function(o,h) o.bHiddenInGame=h end,SetVisibility=function() end,
            IsVisible=function() return true end,
            GetFullName=function() return 'StaticMeshComponent /Game/Map.'..name..'.Mesh' end}
        local d={IsValid=function(o) return not o.dead end,K2_GetActorLocation=function() return {X=x,Y=0,Z=0} end,
            K2_GetComponentsByClass=function() return {part} end,
            GetFullName=function() return 'CH_Drone_BP_C /Game/Map.'..name end}
        return d,part
    end
    local d1,p1=drone('Drone_1',100)
    w.drones={d1}
    local gun=quiet()
    frames(gun,1)
    out(gun)
    assert(p1.bHiddenInGame==true,'the drone is hidden')
    frames(gun,60*30)
    assert(count(w,'CH_Drone_BP_C')==1,count(w,'CH_Drone_BP_C')..' drone walks while it lives')
    clock=clock+1; gun.toggle_now(); frames(gun,120) -- (the departure's morph)
    assert(not gun.state.on and p1.bHiddenInGame==false,'the rifle away, the drone shown')
    out(gun); frames(gun,60)
    assert(p1.bHiddenInGame==true,'the drone hidden again')
    assert(count(w,'CH_Drone_BP_C')==1,count(w,'CH_Drone_BP_C')..' drone walks after the rifle came out again')
    clock=clock+1; gun.toggle_now(); frames(gun,120)
    d1.K2_GetActorLocation=function() return {X=9000,Y=0,Z=0} end
    local d2,p2=drone('Drone_2',50)
    w.drones={d1,d2}
    out(gun); frames(gun,60)
    assert(count(w,'CH_Drone_BP_C')==2,count(w,'CH_Drone_BP_C')..' drone walks with the kept drone far away')
    assert(p2.bHiddenInGame==true,'the near drone hidden')
    d2.dead=true; w.drones={}
    frames(gun,60*6)
    assert(count(w,'CH_Drone_BP_C')>=3,'a drone that went is looked for again')
end

-- 8. The drone's class by its path (GunMode.DRONE_CLASS, in the base paks of 26123051, 235542ea): the rifle out lists
--    the drones through the engine's class hash (core/unreal.lua's class_at and actors_of) with no FindAllOf walk
--    (36 ms at the first F4 of the 2026-11-21 test), as does a rifle out on a new map. Each drone is hidden.
do
    local U=require('core.unreal')
    local w=world()
    local path=GunMode.DRONE_CLASS
    assert(path=='/Game/Art/Character/NPC/CH_NPC_Drone/BluePrints/CH_Drone_BP.CH_Drone_BP_C',tostring(path))
    local cls={IsValid=function() return true end,GetFullName=function() return 'BlueprintGeneratedClass '..path end}
    local d,part=w.drone()
    local class_at,actors_of=U.class_at,U.actors_of
    local hashed=0
    U.class_at=function(p) assert(p==path,p); return cls,'soft path' end
    U.actors_of=function(c,name)
        assert(c==cls and name=='CH_Drone_BP_C'); hashed=hashed+1; return w.drones,'class hash'
    end
    local gun=quiet()
    frames(gun,1)
    out(gun)
    frames(gun,60)
    assert(count(w,'CH_Drone_BP_C')==0,count(w,'CH_Drone_BP_C')..' drone walks at the first rifle out')
    assert(hashed==1 and part.bHiddenInGame==true,'the drone listed by the class hash and hidden')
    gun.new_controller(w.pc) -- a new map: its own drone, the old one gone
    frames(gun,5*60)
    d.dead=true; w.drones={}
    local _,part2=w.drone()
    out(gun)
    frames(gun,60)
    assert(count(w,'CH_Drone_BP_C')==0,count(w,'CH_Drone_BP_C')..' drone walks after a new map')
    assert(hashed==2 and part2.bHiddenInGame==true,'the new drone listed by the class hash and hidden')
    U.class_at,U.actors_of=class_at,actors_of
end

-- 9. The rifle's mesh and the aim stance's two turn clips (hip fire's shuffle) are kept by the keep too (17a166fa):
--    the rifle out takes the mesh in memory with no LoadAsset (a walk in UE4SS for a path not in memory). The mesh
--    and the clips are the same: only their lookup changed (rifle.lua and the turn code are lookup-only here).
do
    local Keep=require('core.keep')
    local Rifle=require('fight.gunmode.rifle')
    local want,wanted=Keep.want,{}
    Keep.want=function(paths) for _,p in ipairs(paths) do wanted[p]=true end end
    world()
    quiet()
    Keep.want=want
    local clip='/Game/Art/Character/PC/CH_P_EVE_01/Animation/%s.%s'
    for _,p in ipairs({Rifle.WEAPON,clip:format('P_Eve_Gun_RotateLw','P_Eve_Gun_RotateLw'),
            clip:format('P_Eve_Gun_RotateRw','P_Eve_Gun_RotateRw')}) do
        assert(wanted[p],'the keep does not hold '..tostring(p))
    end
    assert(Fake.RIFLE==Rifle.WEAPON,'the fake\'s rifle is the rifle\'s mesh')
    local w=kept_world()
    local gun=quiet()
    Keep.slow(); w.keep.settle()
    frames(gun,1)
    w.n.load={}
    for _=1,2 do out(gun); frames(gun,30); clock=clock+1; gun.toggle_now(); frames(gun,60) end
    assert((w.n.load[Rifle.WEAPON] or 0)==0,'the rifle loaded '..tostring(w.n.load[Rifle.WEAPON])..' times')
    assert(#w.rifles()==0,'the rifle taken off')
    w.done()
end

-- 10. Names made once (b812f708): the muzzle flash's socket FX_Fire in mode.lua and the layer's DefaultSlot in
--     overlay.lua, not at each flash or each clip played.
do
    local w=world()
    local spawned=0
    local lib={IsValid=function() return true end,
        GetFullName=function() return 'NiagaraFunctionLibrary /Script/Niagara.Default__NiagaraFunctionLibrary' end,
        SpawnSystemAttached=function() spawned=spawned+1 end}
    w.paths['/Script/Niagara.Default__NiagaraFunctionLibrary']=lib
    local fx=Config.DEFAULTS.muzzle_fx
    w.paths[fx]={IsValid=function() return true end,GetFullName=function() return 'NiagaraSystem '..fx end}
    for _,c in pairs(Overlay.CLIPS) do
        w.paths[c]={IsValid=function() return true end,GetFullName=function() return 'AnimSequence '..c end}
    end
    local made={}
    local fname=FName
    FName=function(text,...)
        local src=debug.getinfo(2,'S').source:match('([%w_]+)%.lua$') or '?'
        made[src..' '..text]=(made[src..' '..text] or 0)+1
        return fname(text,...)
    end
    local gun=quiet()
    frames(gun,1)
    out(gun); frames(gun,60)
    w.mesh.pp.PlaySlotAnimationAsDynamicMontage=function() return {} end
    w.mesh.pp.IsPlayingSlotAnimation=function() return true end
    for _=1,3 do
        w.pawn.bTPSMode,w.down.RightMouseButton=true,true
        w.down.LeftMouseButton=true
        frames(gun,120)
        w.down.LeftMouseButton=nil
        w.pawn.bTPSMode,w.down.RightMouseButton=false,nil
        frames(gun,60)
    end
    FName=fname
    assert(spawned>3,spawned..' flashes')
    assert((made['mode FX_Fire'] or 0)<=1,tostring(made['mode FX_Fire'])..' FX_Fire names made in mode.lua')
    local slots=made['overlay DefaultSlot'] or 0
    assert(slots<=1,slots..' DefaultSlot names made in overlay.lua')
end

-- 11. An asset that never loads (here the muzzle flash, asked at each round) is looked for and loaded once in 5 s, not
--     at each use: each miss was a StaticFindObject walk and a LoadAsset (b812f708).
do
    local w=world()
    local fx=Config.DEFAULTS.muzzle_fx
    local gun=quiet()
    frames(gun,1)
    out(gun); frames(gun,60)
    w.pawn.bTPSMode,w.down.RightMouseButton,w.down.LeftMouseButton=true,true,true
    w.n.load[fx]=0
    frames(gun,120)
    assert(w.n.load[fx]==1,w.n.load[fx]..' loads of a missing asset in 2 s of fire')
    frames(gun,240)
    assert(w.n.load[fx]==2,w.n.load[fx]..' loads of a missing asset in 6 s of fire')
    w.down.LeftMouseButton=nil
    w.pawn.bTPSMode,w.down.RightMouseButton=false,nil
end

print('gunmode cost_test ok')
