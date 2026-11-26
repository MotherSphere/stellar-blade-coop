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

print('gunmode cost_test ok')
