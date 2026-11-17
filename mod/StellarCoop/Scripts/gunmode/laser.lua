-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The laser sight, after luke77's RifleStance laser: SB's NIKKE guide laser (NS_A_GuideLaser) spawned on the posed
-- rifle's muzzle socket FX_Fire. Its beam ends at the NIKKE minigame parameter collection's LaserPosition
-- (NC_NikkeMinigame), set each frame to where the rounds go: the crosshair point (GetTPSLookAtWorldLocation), else
-- the nearest hit of three traces along the muzzle (visibility, camera, and pawns other than EVE), else 80 m out.
-- LaserPosition is put back as it was when the sight goes off.
local Laser={}

local BASE='/Game/DLC_2/Art/FX/MiniGame/'
Laser.RANGE=8000

-- The nearest point along axis from origin among hits ({ImpactPoint}), at most range away, or nil.
function Laser.nearest(origin,axis,hits,range)
    local best,dist=nil,range
    for _,p in ipairs(hits) do
        local along=(p.X-origin.X)*axis.X+(p.Y-origin.Y)*axis.Y+(p.Z-origin.Z)*axis.Z
        if along>=0 and along<dist then best,dist={X=p.X,Y=p.Y,Z=p.Z},along end
    end
    return best
end

-- g: gun mode's shared state (gunmode/mode.lua).
function Laser.new(g)
    local self={}
    local beam,inst,saved,pawn,gun,lib,trace,pawn_cls,M
    local socket=FName('FX_Fire')
    local function asset(name)
        local path=BASE..name..'.'..name
        local o=g.try(function() return StaticFindObject(path) end)
        if not g.valid(o) then o=g.try(function() return LoadAsset(path) end) end
        assert(g.valid(o),'no '..path)
        return o
    end

    function self.on(p,rifle)
        if beam and g.valid(beam) then return end
        pawn,gun=p,rifle
        lib=StaticFindObject('/Script/Niagara.Default__NiagaraFunctionLibrary')
        trace=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
        M=StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
        pawn_cls=StaticFindObject('/Script/Engine.Pawn')
        assert(g.valid(lib) and g.valid(trace) and g.valid(M),'laser libraries missing')
        inst=lib:GetNiagaraParameterCollection(pawn,asset('NC_NikkeMinigame'))
        assert(g.valid(inst),'no NIKKE parameter collection')
        local v=inst:GetVectorParameter('LaserPosition')
        saved={X=v.X,Y=v.Y,Z=v.Z}
        beam=lib:SpawnSystemAttached(asset('NS_A_GuideLaser'),gun,socket,{X=0,Y=0,Z=0},{Pitch=0,Yaw=0,Roll=0},2,true,
            false,0,false)
        assert(g.valid(beam),'laser spawn failed')
        self.update()
        beam:Activate(false)
    end

    function self.update()
        if not (beam and g.valid(beam) and g.valid(gun)) then return end
        local target=g.try(function() return pawn:GetTPSLookAtWorldLocation(true) end)
        if not target then
            local o=gun:GetSocketLocation(socket)
            local a=M:GetForwardVector(gun:GetSocketRotation(socket))
            local far={X=o.X+a.X*Laser.RANGE,Y=o.Y+a.Y*Laser.RANGE,Z=o.Z+a.Z*Laser.RANGE}
            local clear={R=0,G=0,B=0,A=0}
            local hits={}
            for ch=0,1 do
                local hit={}
                if trace:LineTraceSingle(pawn,o,far,ch,false,{pawn},0,hit,true,clear,clear,0) and hit.ImpactPoint then
                    hits[#hits+1]=hit.ImpactPoint
                end
            end
            local hit={}
            if trace:LineTraceSingle(pawn,o,far,4,true,{pawn},0,hit,true,clear,clear,0) then
                local ok,actor=pcall(function() return hit.Actor:Get() end)
                if ok and g.valid(actor) and actor:IsA(pawn_cls) and actor:GetAddress()~=pawn:GetAddress() then
                    hits[#hits+1]=hit.ImpactPoint
                end
            end
            target=Laser.nearest(o,a,hits,Laser.RANGE) or far
        end
        inst:SetVectorParameter('LaserPosition',{X=target.X,Y=target.Y,Z=target.Z})
    end

    function self.off()
        pcall(function()
            if g.valid(beam) then beam:SetVisibility(false,false); beam:Deactivate(); beam:K2_DestroyComponent(beam) end
        end)
        pcall(function() if saved and g.valid(inst) then inst:SetVectorParameter('LaserPosition',saved) end end)
        beam,saved=nil,nil
    end

    return self
end

return Laser
