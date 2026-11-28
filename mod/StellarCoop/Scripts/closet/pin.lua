-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The hairpin band on her ponytail (closet/dress.lua's o.pin). EVE's ACC_HairPin component (the black band and sword
-- clip) is attached to CharacterMesh0 at socket SC_HairACC. A pack body mesh with no socket of that name leaves it at
-- the body's origin (Schizo, 27 Nov 2026: the band is gone under a pack suit, back with coop closet off). After the
-- dress puts a body mesh with no SC_HairACC on, fit puts the pin on the bone her own body's socket sits on, with that
-- socket's relative transform after the pin's own place on the socket, read at run time. give_back puts it on
-- SC_HairACC with its own place again once her own body is back. A body with the socket: nothing changes. The pin's
-- visibility and bHidePonyTail stay the game's (the game shows and hides the pin with SBPonytail from that flag:
-- FUN_14203bb10 -> FUN_14203bca0, by the component's FName "ACC_HairPin"). A socket, bone or transform that does not
-- read leaves the pin as it is, said once.
-- shortcut: a Lua reload while the pin sits on the bone forgets its own place; it stays on the bone (the same spot)
-- until the next map load makes a new EVE. Keep its place in coop-closet.txt if that shows in game.
--
-- The game's parts (SB-Win64-Shipping.exe, build 26123051, read 27 Nov 2026):
--   USceneComponent.DoesSocketExist(InSocketName): native entry 0x14664b910 (name 0x146648b28), exec 0x14490b540
--     reads the name and calls vtable +0x440 (the component's own DoesSocketExist).
--   USkeletalMesh.FindSocket(InSocketName) -> USkeletalMeshSocket: entry 0x146650230 (name 0x14664e658) in
--     USkeletalMesh's native table (FUN_144917a50 registers it with "SkeletalMesh", "/Script/Engine"), exec 0x144917100
--     looks the name up in the mesh's socket map (+0x110, 0x60-byte entries) and returns the entry's socket (+0x40),
--     else null.
--   USkeletalMeshSocket properties (list from 0x146660448; the class's UFunction InitializeSocketFromLocation
--     0x14665acf8 is beside them): SocketName FName +0x28 (params 0x146660448), BoneName FName +0x30 (0x146660470),
--     RelativeLocation FVector +0x38 (0x1466603e8), RelativeRotation FRotator +0x44 (0x146660418), RelativeScale
--     FVector +0x50 (0x1466604d0).
--   USceneComponent.K2_AttachToComponent(Parent, SocketName, LocationRule, RotationRule, ScaleRule, bWeldSimulated
--     Bodies): entry 0x14664bb10 (name 0x1464d1500), exec 0x14490c190 -> AttachToComponent 0x1441090b0. Rule 2
--     (SnapToTarget) for all three, as the dress's added meshes: the relative place becomes zero, set next.
--   USceneComponent.K2_SetRelativeTransform(NewTransform, bSweep, SweepHitResult, bTeleport): entry 0x14664bba0 (name
--     0x1466487a8), exec 0x14490f650 reads them in that order and calls FUN_144107620.
--   USceneComponent.RelativeLocation, RelativeRotation (closet/head/wear.lua's reads) and RelativeScale3D (property
--     params 0x146649188, name 0x146540580, offset +0x154): the pin's own place on the socket.
--   UKismetMathLibrary.MakeTransform(Location, Rotation FRotator, Scale): entry 0x14659c0b0 (name 0x14657d020), exec
--     0x1447b6fd0 reads the three in that order and builds the quaternion from the rotator.
--   UKismetMathLibrary.ComposeTransforms(A, B): entry 0x14659af80 (name 0x14657ba78), exec 0x1447b63c0 ->
--     FUN_1447adce0(out, A, B): rotation B.Rotation * A.Rotation, scale A * B, translation B applied to A's: A first,
--     then B. So the pin's own place goes first, then the socket's transform on the bone.
local U=require('core.unreal')
local valid,each,text=U.valid,U.each,U.text
local Pin={}
Pin.NAME,Pin.SOCKET='ACC_HairPin','SC_HairACC'
Pin.CLASS='/Script/Engine.SkeletalMeshComponent'
local MATH='/Script/Engine.Default__KismetMathLibrary'
local SNAP=2 -- EAttachmentRule::SnapToTarget.
local function vec(v) v=U.value_of(v); return {X=v.X,Y=v.Y,Z=v.Z} end
local function rot(r) r=U.value_of(r); return {Pitch=r.Pitch,Yaw=r.Yaw,Roll=r.Roll} end

-- EVE's ACC_HairPin component (found by its name, as the game does), or nil. class: Pin.CLASS's object.
function Pin.find(eve,class)
    local found
    each(eve:K2_GetComponentsByClass(class),function(_,c)
        c=valid(c)
        if c and not found and text(c:GetFName())==Pin.NAME then found=c end
    end)
    return found
end
-- SC_HairACC of a body mesh: {bone=, loc=, rot=, scale=}, or nil and why.
function Pin.socket(mesh)
    if not mesh then return nil,'no mesh' end
    local ok,got=pcall(function()
        local s=valid(mesh:FindSocket(FName(Pin.SOCKET)))
        if not s then return nil end
        return {bone=text(s.BoneName),loc=vec(s.RelativeLocation),rot=rot(s.RelativeRotation),
            scale=vec(s.RelativeScale)}
    end)
    if not ok then return nil,'its read failed: '..tostring(got) end
    if not got then return nil,'no '..Pin.SOCKET end
    if got.bone=='' or got.bone=='None' then return nil,Pin.SOCKET..' names no bone' end
    return got
end

-- o: log, math (the KismetMathLibrary default object; fakes in tests).
function Pin.new(o)
    local log=o.log
    local lib=o.math or function() return StaticFindObject(MATH) end
    local self={}
    local moved -- While the pin sits on the bone: {c=, loc=, rot=, scale=} (its own place on the socket).
    local said=false
    local function leave(why)
        if not said then said=true; log('hairpin: '..why..': the pin is left as it is') end
    end
    -- After her own body (or a body with the socket) is on: the pin back on SC_HairACC with its own place.
    function self.give_back(body)
        local m=moved
        moved=nil
        local c=m and valid(m.c)
        if not (c and body) then return false end
        c:K2_AttachToComponent(body,FName(Pin.SOCKET),SNAP,SNAP,SNAP,false)
        c:K2_SetRelativeTransform(lib():MakeTransform(m.loc,m.rot,m.scale),false,{},true)
        log('hairpin: back on '..Pin.SOCKET)
        return true
    end
    -- After the dress put a body mesh on body (CharacterMesh0); own: her own body mesh (the dress's kept one).
    function self.fit(eve,body,own)
        if moved and not valid(moved.c) then moved=nil end -- A new EVE: her new pin sits on its socket.
        if body:DoesSocketExist(FName(Pin.SOCKET)) then return self.give_back(body) end
        local pin=Pin.find(eve,StaticFindObject(Pin.CLASS))
        if not pin then return leave('EVE has no '..Pin.NAME) end
        local s,why=Pin.socket(own)
        if not s then return leave('her own body mesh: '..why) end
        local m=moved or {c=pin,loc=vec(pin.RelativeLocation),rot=rot(pin.RelativeRotation),
            scale=vec(pin.RelativeScale3D)}
        local math_lib=lib()
        local t=math_lib:ComposeTransforms(math_lib:MakeTransform(m.loc,m.rot,m.scale),
            math_lib:MakeTransform(s.loc,s.rot,s.scale))
        pin:K2_AttachToComponent(body,FName(s.bone),SNAP,SNAP,SNAP,false)
        pin:K2_SetRelativeTransform(t,false,{},true)
        if not moved then log('hairpin: the worn body has no '..Pin.SOCKET..': on bone '..s.bone) end
        moved=m
        return true
    end
    return self
end

return Pin
