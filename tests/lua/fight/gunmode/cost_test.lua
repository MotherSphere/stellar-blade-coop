-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- What gun mode looks up, over a fake UE4SS (fake.lua) that counts its engine calls: UE4SS 3.0.1's StaticFindObject
-- and FindAllOf walk the object array, FindFirstOf too. Each case counts the finds of one walk that today's gun mode
-- made each frame, each round or at each rifle out, and fails when that walk comes back.
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
    local mem={}
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

print('gunmode cost_test ok')
