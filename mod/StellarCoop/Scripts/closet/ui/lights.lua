-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet's preview lights, run by closet/ui/camera.lua on its camera actor while the menu is open. A preset is
-- Game (no added light, the default), Studio (a soft key and a fill), Warm, Cool or Rim (a back light and a weak key):
-- up to three point light components added to the camera actor, so they follow the camera in both of its modes and
-- leave with the actor on every close path. Each is added deferred, made Movable before its setters (candelas, the
-- preset's colour and intensity times the factor, a SOURCE cm source, no shadow), then finished: attached to the
-- actor's root, the camera component. A preset change removes the lights and adds the new preset's; Game adds none.
-- The factor steps by STEP from LOW to HIGH; Game has none to step. place(d, k) puts each light in the camera's frame
-- around EVE's look point, d cm away at NDC tangent k (closet/ui/camera.lua's), at the same distance from that point
-- whatever d is: a point light's brightness grows as its distance shrinks, so lights that came with the zoom glared on
-- a close view. Their radius is 2.5 REACH. It moves them again only once d moved 1 cm. The first engine error logs once and turns the lights off until
-- the next camera.
-- o: {unreal=core/unreal.lua's (tests), log=}.
--
-- The game's parts, read in Ghidra (SB-Win64-Shipping.exe, build 26123051) on 26 Nov 2026:
--   /Script/Engine.PointLightComponent: registered by FUN_1448e6280 (L"PointLightComponent", L"/Script/Engine"), its
--     super ULocalLightComponent (FUN_144846500), whose super is ULightComponent (FUN_144842800), whose super is
--     ULightComponentBase (FUN_144843c10), whose super is USceneComponent (FUN_144910e30).
--   AActor.AddComponentByClass(Class +0x0, bManualAttachment, RelativeTransform +0x10, bDeferredFinish) -> Object +0x48:
--     FFunctionParams 0x146e19150; its exec 0x1446b9010 finishes the add (FUN_143f745c0) only when bDeferredFinish is
--     false.
--   AActor.FinishAddComponent(Component +0x0, bManualAttachment, RelativeTransform +0x10): FFunctionParams 0x146e193d0;
--     FUN_143f745c0 attaches a scene component with bManualAttachment false to the actor's root (actor+0x178), sets
--     its relative transform, then registers it.
--   KismetMathLibrary.MakeTransform(Location, Rotation, Scale) -> FTransform: FFunctionParams 0x146e42e90.
--   USceneComponent.SetMobility(NewMobility byte): FFunctionParams 0x146e68870; EComponentMobility Static 0,
--     Stationary 1, Movable 2 (enumerators 0x146549d60).
--   USceneComponent.K2_SetRelativeLocation(NewLocation +0x0, bSweep, SweepHitResult +0x10, bTeleport): FFunctionParams
--     0x146e68370.
--   ULocalLightComponent.SetIntensityUnits(NewIntensityUnits enum byte): FFunctionParams 0x146e53700; ELightUnits
--     Unitless 0, Candelas 1, Lumens 2 (enumerators 0x146646f10).
--   ULocalLightComponent.SetAttenuationRadius(NewRadius float): FFunctionParams 0x146e536b0; its exec 0x144846310
--     writes +0x3e0 on a registered component only when its Mobility (+0x173) is above 1 (Movable).
--   ULightComponent.SetIntensity(NewIntensity float): FFunctionParams 0x146e52ca0; its exec 0x144842110 writes +0x274
--     on a registered component only when its Mobility is not Static.
--   ULightComponent.SetLightColor(NewLightColor FLinearColor +0x0, bSRGB bool): FFunctionParams 0x146e52cf0.
--   ULightComponentBase.SetCastShadows(bNewValue bool): FFunctionParams 0x146e53350.
--   UPointLightComponent.SetSourceRadius(bNewValue float): FFunctionParams 0x146e62140.
--   UActorComponent.K2_DestroyComponent(Object): FFunctionParams 0x146e1be50.
local Lights={}
Lights.ORDER={'game','studio','warm','cool','rim'}
Lights.STEP,Lights.LOW,Lights.HIGH=0.25,0.25,2 -- The intensity factor.
Lights.SOURCE=20 -- cm: each light's source radius, a soft highlight.
Lights.REACH=300 -- cm: the key and fill offsets are parts of this, the look point's distance in a full view.
-- Each preset's lights (starting values, to tune in game: SB uses auto exposure): {place, colour R G B, candelas}.
Lights.PRESETS={game={},
    studio={{'key',{1,1,1},30},{'fill',{0.85,0.92,1},10}},
    warm={{'key',{1,0.8,0.6},30},{'fill',{1,0.8,0.6},8}},
    cool={{'key',{0.7,0.85,1},30},{'fill',{0.7,0.85,1},8}},
    rim={{'rim',{1,1,1},40},{'key',{1,1,1},10}}}
-- Each place from EVE's look point in the camera's frame (X ahead, Y right, Z up): key and fill in parts of REACH
-- (the key above, left and nearer; the fill right), the rim in cm past her.
local PLACES={key={-0.7,-0.6,0.5,far=true},fill={-0.8,0.7,0,far=true},rim={150,-50,100}}
local POINT='/Script/Engine.PointLightComponent'

-- Where place puts its light for a look point d cm away at NDC tangent k: the look point is level with the camera,
-- k times its depth to the right.
function Lights.where(place,d,k)
    local s=1/math.sqrt(1+k*k)
    local o=PLACES[place]
    local m=o.far and Lights.REACH or 1
    return {X=d*s+o[1]*m,Y=d*k*s+o[2]*m,Z=o[3]*m}
end

function Lights.new(o)
    local U=o.unreal or require('core.unreal')
    local log=o.log or function() end
    local self={}
    local preset,factor='game',1
    -- actor: the camera actor the lights are on; made: {c=component, def=its preset line}; placed: the d of the last
    -- place; broken: an engine error turned them off until the next camera.
    local actor,made,placed,broken=nil,{},nil,false

    local function clear()
        for _,l in ipairs(made) do pcall(function() l.c:K2_DestroyComponent(actor) end) end
        made,placed={},nil
    end
    -- f's engine calls; the first error logs, removes the lights and turns them off for this camera.
    local function guard(f,...)
        if not actor or broken then return end
        local ran,why=pcall(f,...)
        if ran then return end
        broken=true
        log('camera: lights off: '..tostring(why))
        clear()
    end
    local function build()
        clear()
        guard(function()
            local defs=Lights.PRESETS[preset]
            if #defs==0 then return end
            local identity=U.find('/Script/Engine.Default__KismetMathLibrary'):MakeTransform({X=0,Y=0,Z=0},
                {Pitch=0,Yaw=0,Roll=0},{X=1,Y=1,Z=1})
            for _,def in ipairs(defs) do
                local c=assert(U.valid(actor:AddComponentByClass(U.find(POINT),false,identity,true)),'no light added')
                made[#made+1]={c=c,def=def}
                c:SetMobility(2) -- Movable: before the setters, which a registered Static light refuses.
                c:SetIntensityUnits(1) -- Candelas.
                c:SetIntensity(def[3]*factor)
                c:SetLightColor({R=def[2][1],G=def[2][2],B=def[2][3],A=1},true)
                c:SetSourceRadius(Lights.SOURCE)
                c:SetCastShadows(false)
                actor:FinishAddComponent(c,false,identity)
            end
        end)
    end

    -- The camera's new actor: the preset's lights on it.
    function self.on(a)
        actor,made,placed,broken=a,{},nil,false
        build()
    end
    -- The camera actor goes (every close path): its lights go with it, nothing is called on them.
    function self.off() actor,made,placed=nil,{},nil end
    function self.next()
        for i,p in ipairs(Lights.ORDER) do
            if p==preset then preset=Lights.ORDER[i%#Lights.ORDER+1]; break end
        end
        build()
    end
    -- One STEP up (sign 1) or down (-1), within LOW and HIGH.
    function self.step(sign)
        if preset=='game' then return end
        factor=math.max(Lights.LOW,math.min(Lights.HIGH,factor+sign*Lights.STEP))
        guard(function() for _,l in ipairs(made) do l.c:SetIntensity(l.def[3]*factor) end end)
    end
    function self.place(d,k)
        if #made==0 or placed and math.abs(d-placed)<1 then return end
        placed=d
        guard(function()
            for _,l in ipairs(made) do
                l.c:K2_SetRelativeLocation(Lights.where(l.def[1],d,k),false,{},false)
                l.c:SetAttenuationRadius(2.5*Lights.REACH)
            end
        end)
    end
    -- A saved preset and factor (camera's file): an unknown preset is Game, the factor snapped to STEP within LOW and
    -- HIGH (1 when missing).
    function self.set(p,f)
        preset=Lights.PRESETS[p] and p or 'game'
        f=tonumber(f)
        if not f or f~=f then f=1 end
        factor=math.max(Lights.LOW,math.min(Lights.HIGH,math.floor(f/Lights.STEP+0.5)*Lights.STEP))
    end
    function self.preset() return preset end
    function self.factor() return factor end
    return self
end

return Lights
