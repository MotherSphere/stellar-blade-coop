-- Fusion Strider's look on SBO's bike (dev build, for SBO devs to test; its meshes are not from this game). The
-- bike's static meshes from the pak EveBike_Quantum_P hang on SB's bike part, which stays the riding part, the parked
-- bike's collision and the anchor (vehicles/bike/ride.lua, vehicles/bike/stand.lua). SB's mesh itself is made
-- invisible. Fusion Strider was exported in EVE's main mesh space, so its body sits at the inverse of the part's seat.
-- Every slot gets a dynamic copy of SB's vehicle material with the bike's textures (stock UE 4.26 materials render
-- black in this game). Wheels, suspension and rings stay at their rest pose. Data from Eve Hoverbike's bikes.lua.
local U=require('core.unreal')
local Doro=require('core.actors')
local valid,find=U.valid,U.find
local Look={}

local QU='/Game/Mods/EveBikes/Quantum/'
local function qm(n) return QU..'Mesh/SM_Quantum_'..n..'.SM_Quantum_'..n end
local TEX=QU..'Tex/'
Look.POSE=QU..'Ride/Eve_QuantumRidePose.Eve_QuantumRidePose' -- The riding clip (on her own animation, looped).
-- SB's bike part relative to her main mesh, cm and degrees: SD20's attach tracks (riders on its bone Base). Here so
-- the riding part (ride.lua) and the parked bike (stand.lua) share one value.
Look.SEAT,Look.SEAT_PITCH={X=1.53,Y=0.52,Z=2.95},0.69
Look.BODY=qm('Body')
-- Part meshes relative to the body, cm; Pitch for the rings (they lie in one plane at rest).
Look.PARTS={
    {mesh=qm('WheelFront'),X=77.36,Y=1.43,Z=26.17},{mesh=qm('WheelRear'),X=-77.36,Y=1.43,Z=26.12},
    {mesh=qm('RearArm'),X=-32.23,Y=1.43,Z=33.04},{mesh=qm('FrontHub'),X=77.36,Y=1.43,Z=26.17},
    {mesh=qm('FrontArm'),X=31.18,Y=1.43,Z=26.6},{mesh=qm('FrontElbow'),X=67.81,Y=1.43,Z=68.59},
    {mesh=qm('Ring0'),X=-5.6,Y=1.43,Z=26.91,Pitch=0},{mesh=qm('Ring1'),X=-5.6,Y=1.43,Z=26.91,Pitch=60},
    {mesh=qm('Ring2'),X=-5.6,Y=1.43,Z=26.91,Pitch=120}}
local PARENT='/Game/Art/Character/ETC/Adam_vehicle_02/Materials/MI_Adam_vehicle_02_01.MI_Adam_vehicle_02_01'
local WHITE='/Engine/EngineResources/WhiteSquareTexture.WhiteSquareTexture'
local SCALARS={Metallic=0.6,['Roughness Min']=0.4,['Roughness Max']=0.4,EmissivePower=0,GrimeMask=0,ScratchMask=0,
    ['Flake Intencity']=0.15,AOMultiply=1}
local GLASS='/Game/Art/BG/MasterMaterial/MasterMaterialInstance/LV_MMI_Glass_A04_NoTwoside.LV_MMI_Glass_A04_NoTwoside'
local function rgb(r,g,b) return {R=r,G=g,B=b} end
local AMBER,GOLD,PEARL=rgb(1,0.2863,0),rgb(1,0.5521,0),rgb(0.9167,0.909,0.8498)
local DARK=rgb(0.0628,0.0514,0.0426)
-- Slot (the imported material's name): base colour texture, normal texture, tint, metal, roughness, glow.
Look.SLOTS={
    M_Quantum_Carcass={tint=rgb(0.01,0.01,0.012),metal=0,rough=0.6},
    M_Quantum_Dash1Dials={tint=AMBER,metal=0,rough=0.6,glow=3,glow_tint=AMBER},
    M_Quantum_DashGuages={'T_Quantum_07_dash_C','T_Quantum_04_N',metal=0,rough=0.6,glow=3,glow_tint=AMBER},
    M_Quantum_Fill={tint=rgb(0.6636,0.7021,0.6798),metal=0.3,rough=0.22},
    M_Quantum_Glass={tint=DARK,metal=0.5,rough=0.11},
    M_Quantum_Glow={tint=AMBER,metal=0,rough=0.3,glow=14,glow_tint=AMBER},
    M_Quantum_Glow2={tint=GOLD,metal=0,rough=0.3,glow=16,glow_tint=GOLD},
    M_Quantum_LightF={tint=PEARL,metal=0,rough=0.3,glow=12,glow_tint=PEARL},
    M_Quantum_LightR={tint=AMBER,metal=0,rough=0.3,glow=14,glow_tint=AMBER},
    M_Quantum_Mech={tint=DARK,metal=0.965,rough=0.344},
    M_Quantum_Metal={tint=rgb(0.2035,0.1305,0.0143),metal=0.808,rough=0.325},
    M_Quantum_OrbBack={glass={Opacity=0.45,Roughness=0,Metallic=0,Specular=0.6},glass_color=rgb(0.35,0.22,0.08)},
    M_Quantum_OrbGlass={glass={Opacity=0.14,Roughness=0,Metallic=0,Specular=0.6},glass_color=PEARL},
    M_Quantum_Plasma={tint=GOLD,metal=0,rough=0.3,glow=12,glow_tint=GOLD},
    M_Quantum_RingWhite={tint=rgb(1,1,1),metal=0,rough=0.3,glow=10,glow_tint=rgb(1,1,1)},
    M_Quantum_Stripe={tint=AMBER,metal=0,rough=0.3,glow=14,glow_tint=AMBER},
    M_Quantum_Sun={'T_Quantum_09_sun_C',metal=0,rough=0.6,glow=3,glow_tint=rgb(1,1,1)},
    M_Quantum_Tyre={'T_Quantum_06_tire_C','T_Quantum_03_N',metal=0,rough=0.6},
    M_Quantum_dark_01LightCasing={'T_Quantum_08_dark_C','T_Quantum_05_N',metal=0.965,rough=0.344},
    M_Quantum_fork_01Mechanical={'T_Quantum_01_fork_C','T_Quantum_01_N',metal=0.957,rough=0.191},
    M_Quantum_fork_Base01Engine={'T_Quantum_00_fork_C','T_Quantum_00_N',metal=0.957,rough=0.191},
    M_Quantum_forkshell_sto01Fairing={'T_Quantum_04_forkshell_C','T_Quantum_02_N',metal=0,rough=0.5},
    M_Quantum_mech_01Mechanical={'T_Quantum_02_mech_C','T_Quantum_01_N',metal=0.965,rough=0.344},
    M_Quantum_mech_Mechanical001={'T_Quantum_02_mech_C','T_Quantum_01_N',metal=0.965,rough=0.344},
    M_Quantum_seat_sto01Fairing={'T_Quantum_05_seat_C','T_Quantum_02_N',metal=0,rough=0.6},
    M_Quantum_shell_sto01Fairing={'T_Quantum_03_shell_C','T_Quantum_02_N',metal=0.3,rough=0.22}}

local TEXTURE,STATIC='/Script/Engine.Texture','/Script/Engine.StaticMesh'
-- An asset by object path: core/actors.lua's resolve (memory, then LoadAsset), else the asset registry by object path,
-- which also finds a mod pak's assets: LoadAsset cannot, they are not in the game's asset registry (2026-11-19 first
-- ride: "SM_Quantum_Body is missing on this PC"; BPModLoaderMod loads LogicMods the same way). Once loaded, resolve
-- finds it in memory, so Doro.attach's own lookup works too.
function Look.load(path,class)
    local a=Doro.resolve(path,class)
    if a then return a end
    pcall(function()
        find('/Script/AssetRegistry.Default__AssetRegistryHelpers'):GetAsset({ObjectPath=FName(path,EFindName.FNAME_Add)})
    end)
    return Doro.resolve(path,class)
end
local function tex(name) return name and Look.load(TEX..name..'.'..name,TEXTURE) or nil end
local function color(c) return {R=c.R,G=c.G,B=c.B,A=1} end
local function set(m,k,v) m:SetScalarParameterValue(FName(k),v) end

-- One component's slots dressed on SB's vehicle material (or SB's glass for the orb); the slots done.
function Look.dress(c)
    local parent=Look.load(PARENT,'/Script/Engine.MaterialInterface')
    if not parent then return 0 end
    local white=Look.load(WHITE,TEXTURE)
    local done=0
    for i=0,c:GetNumMaterials()-1 do
        local m=valid(c:GetMaterial(i))
        local s=m and Look.SLOTS[m:GetFName():ToString()]
        local glass=s and s.glass and Look.load(GLASS,'/Script/Engine.MaterialInterface')
        local ok=pcall(function()
            local mid=assert(valid(c:CreateDynamicMaterialInstance(i,glass or parent,FName('None'))))
            if glass then
                for k,v in pairs(s.glass) do set(mid,k,v) end
                mid:SetVectorParameterValue(FName('GlassColor'),color(s.glass_color))
                return
            end
            for k,v in pairs(SCALARS) do set(mid,k,v) end
            if white then mid:SetTextureParameterValue(FName('ORM'),white) end
            if not s then return end
            local base,normal=tex(s[1]) or (s.tint and white),tex(s[2])
            if base then mid:SetTextureParameterValue(FName('BaseColor'),base) end
            if normal then mid:SetTextureParameterValue(FName('Baked Normal'),normal) end
            if s.tint then mid:SetVectorParameterValue(FName('Base Color Tint'),color(s.tint)) end
            set(mid,'Metallic',s.metal)
            set(mid,'Roughness Min',s.rough)
            set(mid,'Roughness Max',s.rough)
            if s.glow and base then
                mid:SetTextureParameterValue(FName('Emissive'),base)
                set(mid,'EmissivePower',s.glow)
                mid:SetVectorParameterValue(FName('EmissiveColor'),color(s.glow_tint))
            end
        end)
        if ok then done=done+1 end
    end
    return done
end

-- The body's place under SB's part: the inverse of the part's seat on her mesh (seat {X,Y,Z}, pitch in degrees).
function Look.under(seat,pitch)
    local p=math.rad(pitch)
    local c,s=math.cos(p),math.sin(p)
    -- R(-pitch) of the seat, negated: a pitch turns X toward Z.
    return {X=-(seat.X*c+seat.Z*s),Y=-seat.Y,Z=-(-seat.X*s+seat.Z*c)},{Pitch=-pitch,Yaw=0,Roll=0}
end

-- Fusion Strider on part (SB's bike component, on actor): SB's mesh invisible, the body at the inverse seat, the parts
-- on the body. Returns {comps, slots} or raises, with nothing left, when the body cannot be made. visible: the
-- body's own visibility (the riding part starts hidden; a stand shows by its actor).
function Look.build(actor,part,seat,pitch,visible)
    local made={}
    local ok,why=pcall(function()
        Look.load(Look.BODY,STATIC) -- in memory first: Doro.attach's own lookup cannot load a mod pak's asset
        local body=Doro.attach(actor,part,{path=Look.BODY,static=true}).mesh
        made[1]=body
        local at,rot=Look.under(seat,pitch)
        body:K2_SetRelativeLocationAndRotation(at,rot,false,{},false)
        for _,p in ipairs(Look.PARTS) do
            Look.load(p.mesh,STATIC)
            local okP,d=pcall(Doro.attach,actor,body,{path=p.mesh,static=true})
            if okP then
                d.mesh:K2_SetRelativeLocationAndRotation({X=p.X,Y=p.Y,Z=p.Z},{Pitch=p.Pitch or 0,Yaw=0,Roll=0},false,{},
                    false)
                made[#made+1]=d.mesh
            end
        end
        part:SetVisibility(false,false) -- SB's mesh: never drawn, its collision (a stand's) kept.
    end)
    if not ok then
        for _,c in ipairs(made) do pcall(function() c:K2_DestroyComponent(actor) end) end
        error(why,0)
    end
    local slots=0
    for _,c in ipairs(made) do
        local okD,n=pcall(Look.dress,c)
        if okD then slots=slots+n end
        c:SetVisibility(visible,false)
    end
    return {comps=made,slots=slots}
end

function Look.show(look,on)
    for _,c in ipairs(look and look.comps or {}) do pcall(function() c:SetVisibility(on,false) end) end
end

return Look
