-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode and the engine objects it keeps across frames, over a fake UE4SS (fake.lua): the input mask gives the keys
-- back after coop fly's AddActionMapping moved the action mappings to a new buffer (M1); the muzzle flash finds its
-- asset again once the engine collected it (H5).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Fake=dofile('tests/lua/fight/gunmode/fake.lua')
local GunMode=require('fight.gunmode.mode')
local clock=100
os.clock=function() return clock end
local function out(gun)
    clock=clock+1
    gun.toggle_now()
    assert(gun.state.on,'the rifle is out')
end

-- 1. M1: rifle out, then coop fly adds its mappings and the array moves (the old buffer freed). Putting the rifle away
--    writes the keys into the array as it is now, nothing into the old buffer.
do
    local w=Fake.new(); w.install()
    local keys=w.keys()
    local gun=GunMode.new({log=function() end})
    out(gun)
    assert(w.keys()~=keys,'keys masked')
    local freed=false
    local moved={}
    for i,r in ipairs(w.mappings) do
        moved[i]={ActionName=r.ActionName,Key={KeyName=r.Key.KeyName}}
        r.Key=setmetatable({},{__newindex=function() freed=true end})
    end
    moved[#moved+1]={ActionName=Fake.name('FlyUp'),Key={KeyName=Fake.name('SpaceBar')}}
    w.mappings=moved
    clock=clock+1; gun.toggle_now()
    assert(not gun.state.on,'the rifle is away')
    assert(not freed,'a key written into the freed buffer')
    assert(w.keys()==keys..' FlyUp=SpaceBar',w.keys())
end

-- 2. H5: the muzzle flash's Niagara system collected between two shots is loaded again, never spawned freed.
do
    local w=Fake.new(); w.install()
    local spawned,live={},nil
    local niagara={IsValid=function() return true end,SpawnSystemAttached=function(_,fx) spawned[#spawned+1]=fx end}
    local find=w.find
    w.find=function(path)
        if path=='/Script/Niagara.Default__NiagaraFunctionLibrary' then return niagara end
        if path:find('NS_A_NikkeGunFire',1,true) then
            if not live or live.dead then
                live={IsValid=function(o) return not o.dead end,GetFullName=function() return 'NiagaraSystem '..path end}
            end
            return live
        end
        return find(path)
    end
    local gun=GunMode.new({log=function() end})
    out(gun)
    w.pawn.bTPSMode=true; w.down.LeftMouseButton=true -- firing mode, fire held
    clock=clock+0.2; gun.tick()
    assert(#spawned==1 and spawned[1]:IsValid(),'the first flash')
    spawned[1].dead=true -- the engine's collector
    clock=clock+0.2; gun.tick()
    assert(#spawned==2,'the second flash')
    assert(spawned[2]:IsValid(),'a collected flash asset spawned')
end


print('gunmode engine: ok')
