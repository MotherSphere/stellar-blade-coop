-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The closet's head part (closet/head/wear.lua) with fake UE4SS objects, copied from tests/lua/eve/wear_test.lua (a
-- strict EVE, part(), asset/mesh/colour, calls/since, the store, the clock) with SBPonytail and SBPonytailShort fakes
-- that keep their visibility and OverrideClothPhysicsAsset. The store stands for closet/dress.lua, which writes
-- head.line() as field 6 before each wear ('save' in the calls).
local run = dofile('tests/lua/closet/run.lua')

local function fname(t) return {type = function() return 'FName' end, ToString = function() return t end} end
local next_address = 0x1000
local function object(fields)
    next_address = next_address + 0x100
    local at = next_address
    local o = fields or {}
    o.type = function() return 'UObject' end
    o.IsValid = o.IsValid or function(self) return not rawget(self, 'destroyed') end
    o.GetAddress = function() return at end
    return o
end
local invalid = object({destroyed = true})
local classes = {}
local function class(path)
    classes[path] = classes[path] or object({path = path})
    return classes[path]
end
local assets, packages, by_path = {}, {}, {}
-- A mod pack's package only the asset registry loads (not LoadAsset): its object path -> the class it brings.
local registry = {}
local HELPERS = {IsValid = function() return true end}
function HELPERS:GetAsset(data)
    local c = registry[data.ObjectPath]
    if c then assets[c.at_path] = c end
    return invalid
end
StaticFindObject = function(path)
    if by_path[path] then return by_path[path] end
    if path == '/Script/AssetRegistry.Default__AssetRegistryHelpers' then return HELPERS end
    if path:find('^/Script/') then return class(path) end
    return assets[path] or invalid
end
LoadAsset = function(path) -- A class shows once its Blueprint's package is loaded.
    local c = packages[path]
    if c then assets[c.at_path] = c end
    return invalid
end
FName = function(s) return s end -- UE4SS's FName, as the asset registry lookup takes it.
local player
package.loaded.UEHelpers = {GetPlayer = function() return player end}
local Head = require('closet.head.wear')

local function asset(path, kinds, fields)
    local o = object(fields or {})
    o.at_path = path
    o.GetFullName = function() return kinds[1]:match('[^.]+$') .. ' ' .. path end
    o.IsA = function(_, c)
        if c.path == '/Script/CoreUObject.Object' then return true end
        for _, k in ipairs(kinds) do if k == c.path then return true end end
        return false
    end
    assets[path] = o
    return o
end
local PC = '/Game/Art/Character/PC/'
local function p(rel) return PC .. rel .. '.' .. rel:match('[^/]+$') end
local MAT = {'/Script/Engine.MaterialInstanceConstant', '/Script/Engine.MaterialInterface'}
local PHYS, ANIM = {'/Script/Engine.PhysicsAsset'}, {'/Script/Engine.AnimBlueprintGeneratedClass'}
local skeleton = asset('/Game/S.S', {'/Script/Engine.Skeleton'})
local function material(rel) return asset(p(rel), MAT) end
local function mesh(rel, slots, fields)
    local f = fields or {}
    f.Skeleton, f.Materials = skeleton, {}
    for k, m in ipairs(slots) do f.Materials[k] = {MaterialInterface = m, MaterialSlotName = fname('slot' .. k)} end
    return asset(p(rel), {'/Script/Engine.SkeletalMesh'}, f)
end

-- The game's own hair (CH_P_EVE_Hair01 in its colour, a dynamic material) and ponytail, the body, the stock hair H07
-- (SB.Hair_001, four salon colours), the ponytails, a pack hair and a cut hair.
local hr01 = mesh('00_HR/EVE_HR_01/CH_P_EVE_Hair01', {material('00_HR/EVE_HR_01/MI_HR01_TypeA')})
local hr01_type_b = material('00_HR/EVE_HR_01/MI_HR01_TypeB')
local hr01_anim = asset(p('00_HR/EVE_HR_01/HR01_AnimBP') .. '_C', ANIM)
local hr01_phys = asset(p('00_HR/EVE_HR_01/HR01_PhysicsAsset'), PHYS)
local pony2 = mesh('CH_P_EVE_Hair/CH_P_EVE_Hair_PonyTail_2', {material('CH_P_EVE_Hair/MI_Pony_Default')})
local pony_short = mesh('CH_P_EVE_Hair/CH_P_EVE_Hair_PonyTail_Short', {material('CH_P_EVE_Hair/MI_Pony_Default')})
local eve08 = mesh('CH_P_EVE_08/CH_P_EVE_08', {material('CH_P_EVE_08/MI_CH_P_EVE_08_01')})
local eve08_pony = asset(p('CH_P_EVE_08/CH_P_EVE_08_PonytailPhysicsAsset'), PHYS)
local h07_types, tails = {}, {}
for i, t in ipairs({'A', 'B', 'C', 'D'}) do
    h07_types[i] = material('H07/MI_H07_Type' .. t)
    tails[i] = material('H07/MI_H07_Tail_Type' .. t)
end
local h07 = mesh('H07/H07', {h07_types[1]})
local h07_anim = asset(p('H07/H07_AnimBP') .. '_C', ANIM)
local nier = mesh('Nier/Nier', {material('Nier/MI_Nier')})
asset(p('Nier/Nier_PhysicsAsset'), PHYS) -- Named by the game's rule: the mesh has none of its own.
local PACK = '/Game/OutfitMods/P/'
local ph_phys = asset(PACK .. 'PH_Phys.PH_Phys', PHYS)
local ph = asset(PACK .. 'PH.PH', {'/Script/Engine.SkeletalMesh'}, {Skeleton = skeleton, PhysicsAsset = ph_phys,
    Materials = {{MaterialInterface = material('P/MI_PH')}}})
local ph_anim = asset(PACK .. 'PH_BP.PH_BP_C', ANIM)
-- A pack names its AnimationBP by the Blueprint's asset path (no _C, as the installed BG3 hair packs do): the class
-- shows once that package is loaded.
packages[PACK .. 'PH_BP.PH_BP'] = ph_anim
assets[ph_anim.at_path] = nil
local ph_pony = asset(PACK .. 'PH_Pony.PH_Pony', PHYS)
-- Two three-slot pack hairs: the first's variant paints a tech band on slot 2 (Klukai's, Schizo's video of 27 Nov
-- 2026), the second names no materials.
local band = asset(PACK .. 'MI_Band.MI_Band', MAT)
local tri_mats = {material('P/MI_Tri_0'), material('P/MI_Tri_1'), material('P/MI_Tri_2')}
local tri = asset(PACK .. 'Tri.Tri', {'/Script/Engine.SkeletalMesh'}, {Skeleton = skeleton, Materials = {
    {MaterialInterface = tri_mats[1]}, {MaterialInterface = tri_mats[2]}, {MaterialInterface = tri_mats[3]}}})
local banded = asset(PACK .. 'Banded.Banded', {'/Script/Engine.SkeletalMesh'}, {Skeleton = skeleton, Materials = {
    {MaterialInterface = material('P/MI_Banded_0')}, {MaterialInterface = material('P/MI_Banded_1')},
    {MaterialInterface = material('P/MI_Banded_2')}}})
local hr14 = mesh('00_HR/EVE_HR_14/EVE_HR_14', {material('00_HR/EVE_HR_14/MI_EVE_HR_14_TypeA')})
local hr14_phys = asset(p('00_HR/EVE_HR_14/EVE_HR_14_Physics'), PHYS)
do -- EVE_HR_14's AnimBP class shows once its Blueprint's package is loaded.
    local path = p('00_HR/EVE_HR_14/EVE_HR_14_AnimBP') .. '_C'
    packages[path:sub(1, -3)] = asset(path, ANIM)
    assets[path] = nil
end

-- EVE's own face (eight slots: 4 her eyes, 7 her brows), a pack face on her face mesh, a pack face of its own mesh on
-- the body's skeleton and one on another skeleton (raven_face's, probe 8), a stock earring and its AnimBP.
local face_mats = {}
for i = 0, 7 do face_mats[i + 1] = material('CH_P_EVE_Head/MI_Face_' .. i) end
local jali = mesh('CH_P_EVE_Head/CH_P_EVE_Face_Jali3', face_mats)
local klukai_mat = asset(PACK .. 'MI_Klukai.MI_Klukai', MAT)
local fit_face = asset(PACK .. 'SK_fbface.SK_fbface', {'/Script/Engine.SkeletalMesh'}, {Skeleton = skeleton,
    Materials = {{MaterialInterface = material('P/MI_fb_0')}, {MaterialInterface = material('P/MI_fb_1')}}})
local raven_skeleton = asset('/Game/R/CH_M_NA_53_Skeleton.CH_M_NA_53_Skeleton', {'/Script/Engine.Skeleton'})
local raven = asset(PACK .. 'CH_M_NA_53_Facial.CH_M_NA_53_Facial', {'/Script/Engine.SkeletalMesh'},
    {Skeleton = raven_skeleton, Materials = {{MaterialInterface = material('P/MI_raven')}}})
local ear01 = mesh('00_ACC/ACC_EAR_01/ACC_EAR_01M', {material('00_ACC/ACC_EAR_01/MI_EAR_01')})
local ear01_anim = asset(p('00_ACC/ACC_EAR_01/ACC_EAR_01M_AnimBP') .. '_C', ANIM)
-- Stock glasses on their own one-bone skeleton (ACC_GLA_01M_Skeleton), two of them, and a pack hat on the body's.
local glasses = mesh('00_ACC/ACC_GLA_01/ACC_GLA_01M', {material('00_ACC/ACC_GLA_01/MI_GLA_01'),
    material('00_ACC/ACC_GLA_01/MI_ACC_Glass_Base')})
local glasses2 = mesh('00_ACC/ACC_GLA_29/ACC_GLA_29M', {material('00_ACC/ACC_GLA_29/MI_GLA_29')})
glasses.Skeleton = asset('/Game/G/ACC_GLA_01M_Skeleton.ACC_GLA_01M_Skeleton', {'/Script/Engine.Skeleton'})
glasses2.Skeleton = glasses.Skeleton
local hat = mesh('P/Hat', {material('P/MI_Hat')})

-- The head fits as closet/fits.lua gives them (Fits.get), in each outfit's chosen variant.
local chosen = {}
local function variants(m, list)
    local out = {}
    for i, x in ipairs(list) do out[i] = {Mesh = m, Materials = {x.at_path}} end
    return out
end
local ITEMS = {
    ['SB.Hair_001'] = {Slot = 'Hair', Origin = 'original', Mesh = h07.at_path, AnimationBP = h07_anim.at_path,
        Rotation = {Pitch = 0, Yaw = 90, Roll = 0}, HidePonytail = false, Ponytail = 'SB.Ponytail_Long',
        Controls = {VectorControls = {{ParamName = 'RootColor', MaterialIndex = 0}}},
        Variants = variants(h07.at_path, h07_types)},
    ['SB.Hair_Nier_001'] = {Slot = 'Hair', Origin = 'original', Mesh = nier.at_path, HidePonytail = true,
        Rotation = {Pitch = -90, Yaw = 0, Roll = -90}, Variants = {{Mesh = nier.at_path, Materials = {}}}},
    ['SB.Hair_024'] = {Slot = 'Hair', Origin = 'original', Mesh = hr14.at_path,
        AnimationBP = p('00_HR/EVE_HR_14/EVE_HR_14_AnimBP') .. '_C', PhysicsAsset = hr14_phys.at_path,
        HidePonytail = false, Ponytail = 'SB.Ponytail_Long', Variants = {{Mesh = hr14.at_path, Materials = {}}}},
    ['SB.Ponytail_Long'] = {Slot = 'Ponytail', Origin = 'original', Mesh = pony2.at_path,
        Variants = variants(pony2.at_path, tails)},
    ['SB.Ponytail_Short'] = {Slot = 'Ponytail', Origin = 'original', Mesh = pony_short.at_path,
        Variants = variants(pony_short.at_path, tails)},
    ['SB.Ponytail_None'] = {Slot = 'Ponytail', Origin = 'original', Mesh = '',
        Variants = {{Mesh = '', Materials = {}}}},
    ['p.banded'] = {Slot = 'Hair', Origin = 'custom', Mesh = banded.at_path,
        Variants = {{Mesh = banded.at_path, Materials = {'', '', band.at_path}}}},
    ['p.tri'] = {Slot = 'Hair', Origin = 'custom', Mesh = tri.at_path,
        Variants = {{Mesh = tri.at_path, Materials = {}}}},
    ['p.hair'] = {Slot = 'Hair', Origin = 'custom', Mesh = ph.at_path, AnimationBP = PACK .. 'PH_BP.PH_BP',
        Variants = {{Mesh = ph.at_path, Materials = {}, PonyPhysics = ph_pony.at_path}}},
    ['p.klukai'] = {Slot = 'Face', Origin = 'custom', Mesh = jali.at_path,
        Variants = {{Mesh = jali.at_path, Materials = {klukai_mat.at_path}}}},
    ['p.fitface'] = {Slot = 'Face', Origin = 'custom', Mesh = fit_face.at_path,
        Variants = {{Mesh = fit_face.at_path, Materials = {}}}},
    ['p.raven'] = {Slot = 'Face', Origin = 'custom', Mesh = raven.at_path,
        Variants = {{Mesh = raven.at_path, Materials = {}}}},
    ['SB.Earring_001'] = {Slot = 'EarringL', Origin = 'original', Mesh = ear01.at_path,
        AnimationBP = ear01_anim.at_path, Variants = {{Mesh = ear01.at_path, Materials = {}}}},
    ['SB.Eyes_Own'] = {Slot = 'Eyes', Origin = 'original', Mesh = '', Variants = {{Mesh = '', Materials = {}}},
        Controls = {VectorControls = {{ParamName = 'IrisHueTint', MaterialIndex = 4},
            {ParamName = 'BaseColour', MaterialIndex = 7}}, ScalarControls = {{ParamName = 'IrisBrightness',
            MaterialIndex = 4}}}},
    ['SB.FaceAccessory_001'] = {Slot = 'Glasses', Origin = 'original', Mesh = glasses.at_path,
        Variants = {{Mesh = glasses.at_path, Materials = {}}}},
    ['SB.FaceAccessory_029'] = {Slot = 'Glasses', Origin = 'original', Mesh = glasses2.at_path,
        Variants = {{Mesh = glasses2.at_path, Materials = {}}}},
    ['p.hat'] = {Slot = 'Headwear', Origin = 'custom', Mesh = hat.at_path,
        Variants = {{Mesh = hat.at_path, Materials = {}}, {Mesh = hat.at_path, Materials = {band.at_path}}}},
    ['p.mask'] = {Slot = 'Mask', Origin = 'custom', Mesh = glasses.at_path,
        Variants = {{Mesh = glasses.at_path, Materials = {}}}},
}
local fits = {get = function(id)
    local it = ITEMS[id]
    if not it then return nil end
    local v = chosen[id] or 1
    local f = {}
    for k, x in pairs(it) do f[k] = x end
    f.Variant, f.Materials, f.PonyPhysics = v, it.Variants[v].Materials, it.Variants[v].PonyPhysics
    return f
end, heads = function(slot)
    local out = {}
    for id, it in pairs(ITEMS) do if it.Slot == slot then out[#out + 1] = id end end
    table.sort(out)
    return out
end}

-- Every call on a component, in order with the store's, as words.
local calls = {}
local function said(...) calls[#calls + 1] = table.concat({...}, ' ') end
local function since(n) return table.concat(calls, '|', n + 1) end
local function short(o) return o.at_path and o.at_path:match('[^.]+$') or o:GetFullName():match('[^.]+$') end
local MID = '/Script/Engine.MaterialInstanceDynamic'
-- Her hair colour: a dynamic instance SB made at run time from MI_HR01_TypeB.
local function colour(name)
    local path = '/Game/Map.Map:PersistentLevel.' .. name .. '.SBHair.MaterialInstanceDynamic_0'
    local o = object({Parent = hr01_type_b, at_path = path})
    o.GetFullName = function() return 'MaterialInstanceDynamic ' .. path end
    o.IsA = function(_, c) return c.path == MID or c.path == '/Script/Engine.MaterialInterface' end
    return o
end
-- A component of hers: its mesh, AnimBP class, physics asset override, overridden materials, visibility, rotation and
-- cloth collision (a write of OverrideClothPhysicsAsset is a call).
local function part(eve_name, name, fields)
    local c = object(fields)
    c.name, c.OverrideMaterials = name, c.OverrideMaterials or {}
    if c.visible == nil then c.visible = true end
    c.RelativeRotation = c.RelativeRotation or {Pitch = 0, Yaw = 0, Roll = 0}
    local path = '/Game/Map.Map:PersistentLevel.' .. eve_name .. '.' .. name
    function c:GetFName() return fname(name) end
    function c:GetFullName() return 'SBSkeletalMeshComponent ' .. path end
    function c:SetSkeletalMesh(m, reinit)
        if rawget(self, 'mesh_raises') then error('no mesh', 0) end
        assert(reinit == true, 'A new pose, as SB sets a mesh')
        rawset(self, 'SkeletalMesh', m); said(name, 'mesh', m and short(m) or 'none', tostring(reinit))
    end
    function c:SetAnimClass(k)
        local raise = rawget(self, 'anim_raises')
        rawset(self, 'anim_raises', nil)
        if raise then error(raise, 0) end
        rawset(self, 'AnimClass', k); said(name, 'anim', k and short(k) or 'none')
    end
    function c:SetPhysicsAsset(a, force)
        rawset(self, 'PhysicsAssetOverride', a); said(name, 'physics', a and short(a) or 'none', tostring(force))
    end
    function c:SetMaterial(i, m)
        assert(math.type(i) == 'integer' and i >= 0)
        for k = #self.OverrideMaterials + 1, i do self.OverrideMaterials[k] = invalid end
        self.OverrideMaterials[i + 1] = m or invalid; said(name, 'material', i, m and short(m) or 'none')
    end
    function c:SetVisibility(v, children)
        assert(children == false, 'Its children stay as they are')
        rawset(self, 'visible', v); said(name, 'visible', tostring(v))
    end
    function c:IsVisible() return rawget(self, 'visible') end
    -- A made component's calls (closet/head/made.lua) and its tags (a write at 1 lands, as UE4SS's).
    c.ComponentTags = c.ComponentTags or {}
    function c:ComponentHasTag(t)
        for _, x in ipairs(rawget(self, 'ComponentTags')) do if x == t then return true end end
        return false
    end
    function c:SetCollisionEnabled() end
    function c:K2_AttachToComponent(parent, socket) said(name, 'attach', parent.name, socket) end
    function c:SetMasterPoseComponent(x) said(name, 'master', x.name) end
    function c:K2_DestroyComponent(x) assert(x == self); rawset(self, 'destroyed', true); said(name, 'destroy') end
    function c:K2_SetRelativeRotation(r, sweep, _, teleport)
        assert(sweep == false and teleport == false)
        rawset(self, 'RelativeRotation', {Pitch = r.Pitch, Yaw = r.Yaw, Roll = r.Roll})
        said(name, 'rotation', r.Pitch, r.Yaw, r.Roll)
    end
    local cloth = rawget(c, 'cloth')
    c.cloth = nil
    return setmetatable(c, {__index = function(_, k) if k == 'OverrideClothPhysicsAsset' then return cloth end end,
        __newindex = function(t, k, v)
            if k ~= 'OverrideClothPhysicsAsset' then return rawset(t, k, v) end
            cloth = v; said(name, 'cloth', v and short(v) or 'none')
        end})
end
-- EVE: strict, so a read of anything but these fails the test (her equipment and saves among them).
local ALLOWED = {Mesh = true, K2_GetComponentsByClass = true, IsA = true, GetFullName = true, IsValid = true,
    type = true, GetAddress = true, destroyed = true, AddComponentByClass = true,
    mesh_raises = true}
local function eve_of(name, o)
    o = o or {}
    local e = object()
    local parts = {part(name, 'CharacterMesh0', {SkeletalMesh = eve08}),
        part(name, 'Mesh_Face', {SkeletalMesh = jali}),
        part(name, 'SBHair', {SkeletalMesh = hr01, AnimClass = hr01_anim, PhysicsAssetOverride = o.physics,
            OverrideMaterials = {colour(name)}}),
        part(name, 'SBPonytail', {SkeletalMesh = o.pony or pony2, cloth = eve08_pony}),
        part(name, 'SBPonytailShort', {visible = false}),
        part(name, 'SBAccSlot1', {})} -- No earring: no mesh (probe 8).
    e.Mesh = parts[1]
    function e:IsA(k) return k.path == '/Script/SB.SBCharacter' end
    function e:GetFullName() return 'CH_P_EVE_01_Blueprint_C /Game/Map.Map:PersistentLevel.' .. name end
    function e:K2_GetComponentsByClass(k)
        assert(k.path == '/Script/Engine.SkeletalMeshComponent')
        return parts
    end
    -- Each made component gets the next name of its class (SBSkeletalMeshComponent_<n>).
    e.made = {}
    function e:AddComponentByClass(k, manual, _, deferred)
        assert(k.path == '/Script/SB.SBSkeletalMeshComponent' and manual == true and deferred == false)
        local c = part(name, 'SBSkeletalMeshComponent_' .. #e.made, {mesh_raises = e.mesh_raises})
        e.made[#e.made + 1], parts[#parts + 1] = c, c
        return c
    end
    e.parts, e.hair, e.pony, e.short, e.read = parts, parts[3], parts[4], parts[5], {}
    e.face, e.acc = parts[2], parts[6]
    by_path['/Game/Map.Map:PersistentLevel.' .. name] = e
    return setmetatable(e, {__index = function(_, k)
        if ALLOWED[k] then return nil end
        e.read[#e.read + 1] = k
        error('EVE.' .. tostring(k) .. ' read', 0)
    end})
end

-- A new world: an EVE, a head part on her, the dress's store and clock. o: eve_of's options.
local function world(o)
    calls, chosen = {}, {}
    local w = {logs = {}, now = 0, paused = false, told = {}}
    w.eve = eve_of('EVE_1', o)
    player = w.eve
    local words = {closet = {head = {face_rig = 'FACE_RIG'}}}
    w.head = Head.new({log = function(m) w.logs[#w.logs + 1] = m end, fits = fits,
        paused = function() return w.paused end, clock = function() return w.now end,
        tell = function(build) w.told[#w.told + 1] = build(words) end})
    -- closet/dress.lua's order: the file first (field 6), then the head part's wear, then the file again (the marks).
    function w.wear(list)
        w.file = w.head.line(); said('save')
        local good, why = w.head.wear(list)
        if good then w.file = w.head.line(); said('save') end
        return good, why
    end
    function w.tick(s) w.now = w.now + (s or 1); w.head.tick() end
    function w.last() return w.logs[#w.logs] end
    return w
end
local function hair(id) return {fit = id, slot = 'Hair'} end
local function tail(id) return {fit = id, slot = 'Ponytail'} end
-- Her followers never got a call. Nothing read anything else on EVE.
local function clean(e)
    eq(#e.read, 0, 'EVE read: ' .. table.concat(e.read, ' '))
    for _, line in ipairs(calls) do
        ok(not line:find('^CharacterMesh0 ') and not line:find('^Mesh_Face '), line)
    end
end

local tests = {
    a_stock_hair_goes_on_sbhair = function()
        local w = world()
        ok(w.wear({hair('SB.Hair_001')}))
        local trace = since(0)
        local want = 'save|SBHair mesh H07 true|SBHair anim H07_AnimBP_C|SBHair material 0 MI_H07_TypeA|'
        eq(trace:sub(1, #want), want, trace)
        ok(trace:find('|SBHair rotation 0 90 0|', 1, true), 'the row\'s rotation: ' .. trace)
        eq(w.head.applied(), 1)
        same(w.head.worn(), {['SB.Hair_001'] = 'Hair'})
        clean(w.eve)
    end,

    a_stock_hair_brings_its_ponytail_in_its_colour = function()
        local w = world()
        chosen['SB.Hair_001'] = 3
        ok(w.wear({hair('SB.Hair_001')}))
        local trace = since(0)
        ok(trace:find('SBHair material 0 MI_H07_TypeC', 1, true), trace)
        ok(trace:find('SBPonytail cloth CH_P_EVE_08_PonytailPhysicsAsset|SBPonytail mesh CH_P_EVE_Hair_PonyTail_2 '
            .. 'true|SBPonytail material 0 MI_H07_Tail_TypeC|SBPonytail visible true|SBPonytailShort visible false',
            1, true), trace)
        eq(w.eve.pony.SkeletalMesh, pony2)
        -- The game's ponytail is the short one (its length option): the hair brings the short ponytail.
        w = world({pony = pony_short})
        ok(w.wear({hair('SB.Hair_001')}))
        ok(since(0):find('SBPonytail mesh CH_P_EVE_Hair_PonyTail_Short true', 1, true), since(0))
        -- The body's collision asset does not resolve: none set.
        local saved = assets[eve08_pony.at_path]
        assets[eve08_pony.at_path] = nil
        w = world()
        ok(w.wear({hair('SB.Hair_001')}))
        ok(not since(0):find('cloth', 1, true), since(0))
        assets[eve08_pony.at_path] = saved
    end,

    a_pack_hair_takes_its_animbp_and_pony_physics = function()
        local w = world()
        ok(w.wear({hair('p.hair')}))
        local trace = since(0)
        ok(trace:find('save|SBHair mesh PH true|SBHair anim PH_BP_C|', 1, true), trace)
        ok(trace:find('SBPonytail cloth PH_Pony', 1, true), trace)
        ok(not trace:find('rotation', 1, true), 'its transform left as the component had it: ' .. trace)
        eq(w.eve.pony.OverrideClothPhysicsAsset, ph_pony)
    end,

    the_last_hair_s_materials_never_stay_on_the_next = function()
        -- A slot an earlier hair's variant painted kept that material on the next hair's mesh: Klukai's tech band
        -- showed on the BG3 hairs (Schizo's video of 27 Nov 2026). Every slot of the new mesh gets its variant's
        -- material, else the mesh's own.
        local w = world()
        ok(w.wear({hair('p.banded')}))
        eq(w.eve.hair.OverrideMaterials[3], band, 'the band on the first hair')
        ok(w.wear({hair('p.tri')}))
        eq(w.eve.hair.OverrideMaterials[3], tri_mats[3], 'the next hair\'s own slot 2, not the band')
        eq(w.eve.hair.OverrideMaterials[2], tri_mats[2], 'its own slot 1')
    end,

    a_pack_animbp_only_the_registry_loads = function()
        -- In game LoadAsset did not bring a BG3 hair pack's AnimBP ("BG3Hair_Orin_AnimBP is missing on this PC",
        -- Schizo's test of 27 Nov 2026): its package loads through the asset registry.
        local was = packages[PACK .. 'PH_BP.PH_BP']
        packages[PACK .. 'PH_BP.PH_BP'] = nil
        registry[PACK .. 'PH_BP.PH_BP'] = ph_anim
        assets[ph_anim.at_path] = nil
        local good, why = pcall(function()
            local w = world()
            ok(w.wear({hair('p.hair')}))
            ok(since(0):find('SBHair anim PH_BP_C|', 1, true), since(0))
        end)
        packages[PACK .. 'PH_BP.PH_BP'], registry[PACK .. 'PH_BP.PH_BP'] = was, nil
        assets[ph_anim.at_path] = nil
        ok(good, why)
    end,

    a_pack_hair_hides_both_ponytails = function()
        local w = world({pony = pony_short}) -- The length option says short.
        w.eve.short.visible = true
        ok(w.wear({hair('p.hair')}))
        eq(w.eve.pony.visible, false, 'SBPonytail hidden') eq(w.eve.short.visible, false, 'SBPonytailShort hidden')
        local n = #calls
        ok(w.wear({hair('p.hair'), tail('SB.Ponytail_Long')}))
        eq(w.eve.pony.visible, true, 'the picked ponytail shows') eq(w.eve.short.visible, false, 'only one')
        eq(w.eve.pony.SkeletalMesh, pony2, 'long, as picked')
        ok(since(n):find('SBPonytail material 0 MI_H07_Tail_TypeA', 1, true), 'its own colour: ' .. since(n))
    end,

    no_ponytail_hides_it = function()
        local w = world()
        ok(w.wear({hair('SB.Hair_001'), tail('SB.Ponytail_None')}))
        eq(w.eve.pony.visible, false) eq(w.eve.short.visible, false)
        eq(w.eve.pony.SkeletalMesh, pony2, 'no mesh to load')
        w = world()
        ok(w.wear({hair('SB.Hair_Nier_001')}))
        eq(w.eve.pony.visible, false, 'HidePonytail') eq(w.eve.short.visible, false)
        ok(since(0):find('SBHair rotation -90 0 -90', 1, true), since(0))
        -- A pack hair after it: the component's own rotation back, no row's.
        local n = #calls
        ok(w.wear({hair('p.hair')}))
        ok(since(n):find('SBHair rotation 0 0 0', 1, true), since(n))
        eq(w.eve.pony.visible, false, 'still hidden under a pack hair')
    end,

    off_gives_her_game_hair_back = function()
        local w = world()
        local game_colour = w.eve.hair.OverrideMaterials[1]
        ok(w.wear({hair('p.hair')}))
        local n = #calls
        ok(w.head.give_back())
        eq(since(n), 'SBHair mesh CH_P_EVE_Hair01 true|SBHair anim HR01_AnimBP_C|SBHair physics none false|'
            .. 'SBHair material 0 MaterialInstanceDynamic_0|SBPonytail cloth CH_P_EVE_08_PonytailPhysicsAsset|'
            .. 'SBPonytail mesh CH_P_EVE_Hair_PonyTail_2 true|SBPonytail visible true|SBPonytailShort visible false')
        eq(w.eve.hair.OverrideMaterials[1], game_colour, 'the colour itself while it lives')
        eq(w.eve.pony.OverrideClothPhysicsAsset, eve08_pony) eq(w.eve.pony.visible, true)
        eq(w.head.applied(), 2) same(w.head.parts(), {}) same(w.head.worn(), {})
        n = #calls
        ok(w.head.give_back())
        eq(#calls, n, 'nothing worn: no call')
        -- A stock hair's rotation goes back; a physics asset override the game set comes back.
        w = world({physics = hr01_phys})
        ok(w.wear({hair('SB.Hair_001')}))
        ok(since(0):find('SBHair physics none false', 1, true), 'H07 has no physics asset of its own')
        n = #calls
        ok(w.head.wear({}))
        ok(since(n):find('SBHair physics HR01_PhysicsAsset false', 1, true), since(n))
        ok(since(n):find('SBHair rotation 0 0 0', 1, true), since(n))
        -- coop off: everything back.
        w = world()
        ok(w.wear({hair('SB.Hair_001')}))
        w.head.stop()
        eq(w.eve.hair.SkeletalMesh, hr01) eq(w.head.applied(), 2)
        eq(w.eve.pony.OverrideMaterials[1], pony2.Materials[1].MaterialInterface, 'no closet colour left on it')
        clean(w.eve)
    end,

    the_line_and_restore_round_trip = function()
        -- The dress writes line() before each wear: field 6 holds the game's own pieces.
        local w = world()
        ok(w.wear({hair('SB.Hair_001')}))
        local line = w.file
        local f = {}
        for x in (line .. '|'):gmatch('([^|]*)|') do f[#f + 1] = x end
        eq(f[1], '/Game/Map.Map:PersistentLevel.EVE_1')
        eq(f[2], 'SBHair;+;' .. hr01.at_path .. ';' .. hr01_anim.at_path .. ';;0=' .. hr01_type_b.at_path .. ';;;0,0,0')
        ok(not line:find('\t', 1, true), 'one field of the dress\'s line')
        -- The next Lua load: a new head part gives the game's pieces back (her colour as the asset it was made from).
        local logs = {}
        local h2 = Head.new({log = function(m) logs[#logs + 1] = m end, fits = fits})
        local n = #calls
        h2.restore(line)
        local trace = since(n)
        ok(trace:find('^SBHair mesh CH_P_EVE_Hair01 true|SBHair anim HR01_AnimBP_C|SBHair physics none false|'
            .. 'SBHair material 0 MI_HR01_TypeB|SBHair rotation 0 0 0|'), trace)
        ok(trace:find('SBPonytail mesh CH_P_EVE_Hair_PonyTail_2 true', 1, true), trace)
        ok(logs[1]:find('^head: restore from coop%-closet%.txt: SBHair back; SBPonytail back'), logs[1])
        -- A component that no longer shows a closet piece is left alone. The log says so.
        w = world()
        ok(w.wear({hair('SB.Hair_001')}))
        line = w.file
        w.eve.hair.SkeletalMesh = hr01 -- The game set its own before the reload.
        w.eve.hair.OverrideMaterials[1] = colour('EVE_1')
        logs = {}
        h2 = Head.new({log = function(m) logs[#logs + 1] = m end, fits = fits})
        n = #calls
        h2.restore(line)
        ok(not since(n):find('SBHair', 1, true), since(n))
        ok(logs[1]:find('SBHair: nothing to give back', 1, true), logs[1])
        -- A mesh no head fit has is left alone too.
        w = world()
        ok(w.wear({hair('SB.Hair_001')}))
        line = w.file
        local other = mesh('Other/Other', {material('Other/MI_Other')})
        w.eve.hair.SkeletalMesh = other
        Head.new({log = function() end, fits = fits}).restore(line)
        eq(w.eve.hair.SkeletalMesh, other)
        -- No head fit known at the restore (the catalogue is not read): the components are left, and said.
        w = world()
        ok(w.wear({hair('SB.Hair_001')}))
        logs = {}
        Head.new({log = function(m) logs[#logs + 1] = m end, fits = {get = function() end,
            heads = function() return {} end}}).restore(w.file)
        eq(w.eve.hair.SkeletalMesh, h07)
        ok(logs[1] and logs[1]:find('no head fit is known', 1, true), tostring(logs[1]))
        -- Nothing to restore: no call.
        n = #calls
        Head.new({log = function() end, fits = fits}).restore(nil)
        Head.new({log = function() end, fits = fits}).restore('')
        eq(#calls, n)
    end,

    restore_after_two_wears_gives_her_own_hair_back = function()
        local w = world()
        ok(w.wear({hair('SB.Hair_001')}))
        ok(w.wear({hair('p.hair')})) -- The file still names the game's own pieces, not H07.
        eq(w.eve.hair.SkeletalMesh, ph)
        local logs = {}
        Head.new({log = function(m) logs[#logs + 1] = m end, fits = fits}).restore(w.file)
        eq(w.eve.hair.SkeletalMesh, hr01, 'her own hair: ' .. tostring(logs[1]))
        eq(w.eve.pony.visible, true, 'her ponytail shown again')
        -- The same hair worn twice in another colour, its stock ponytail on her own ponytail's mesh: both go back.
        w = world()
        ok(w.wear({hair('SB.Hair_001')}))
        chosen['SB.Hair_001'] = 3
        ok(w.wear({hair('SB.Hair_001')}))
        Head.new({log = function() end, fits = fits}).restore(w.file)
        eq(w.eve.hair.SkeletalMesh, hr01)
        eq(w.eve.pony.OverrideMaterials[1], pony2.Materials[1].MaterialInterface, 'the ponytail mesh\'s own colour')
    end,

    a_salon_hair_with_nothing_worn_stays = function()
        -- Nothing worn on her head: no component is marked, so a reload leaves the salon's hair.
        local w = world()
        local line = w.head.line()
        w.eve.hair.SkeletalMesh = h07 -- The salon: a stock hair the closet also lists.
        Head.new({log = function() end, fits = fits}).restore(line)
        eq(w.eve.hair.SkeletalMesh, h07, 'the salon hair stays')
        -- A closet body look only (the dress wears an empty head list and keeps field 6), then the salon.
        w = world()
        ok(w.wear({}))
        w.eve.hair.SkeletalMesh = h07
        local n = #calls
        Head.new({log = function() end, fits = fits}).restore(w.file)
        eq(w.eve.hair.SkeletalMesh, h07) eq(#calls, n, 'no call')
        -- Worn, then off: the file after off marks nothing.
        w = world()
        ok(w.wear({hair('SB.Hair_001')}))
        ok(w.head.give_back())
        line = w.head.line()
        w.eve.hair.SkeletalMesh = h07
        Head.new({log = function() end, fits = fits}).restore(line)
        eq(w.eve.hair.SkeletalMesh, h07)
    end,

    the_salon_taken_in_is_written_at_the_next_line = function()
        local w = world()
        ok(w.wear({hair('SB.Hair_001'), tail('SB.Ponytail_None')}))
        w.eve.hair.SkeletalMesh = nier -- The salon: her own hair from now on.
        w.tick(1) w.tick(1)
        eq(w.eve.hair.SkeletalMesh, h07)
        ok(w.head.line():find('|SBHair;+;' .. nier.at_path, 1, true), 'the next keep writes it')
        -- Nothing worn: the line follows her head as it is now.
        w = world()
        ok(w.wear({hair('SB.Hair_001')}))
        ok(w.head.give_back())
        w.eve.hair.SkeletalMesh = nier
        ok(w.head.line():find('|SBHair;;' .. nier.at_path, 1, true), w.head.line())
        -- Read before any wear, then the salon: the next line has the new hair.
        w = world()
        ok(w.head.line():find('|SBHair;;' .. hr01.at_path, 1, true))
        w.eve.hair.SkeletalMesh = nier
        ok(w.head.line():find('|SBHair;;' .. nier.at_path, 1, true), w.head.line())
    end,

    the_game_hair_comes_back_after_two_seconds = function()
        local w = world()
        ok(w.wear({hair('SB.Hair_001'), tail('SB.Ponytail_None')}))
        w.eve.hair.SkeletalMesh = nier -- The salon.
        local n = #calls
        w.tick(1)
        eq(#calls, n, 'after 1 s nothing')
        w.tick(1)
        ok(since(n):find('^SBHair mesh H07 true'), since(n))
        eq(w.eve.hair.SkeletalMesh, h07)
        ok(w.last():find('the game changed her head', 1, true), w.last())
        -- Nothing while the game is paused.
        w.eve.hair.SkeletalMesh = nier
        w.paused = true
        n = #calls
        w.tick(1) w.tick(1) w.tick(1)
        eq(#calls, n, 'paused')
        w.paused = false
        w.tick(1) w.tick(1)
        eq(w.eve.hair.SkeletalMesh, h07)
        -- The game's mesh is the one to give back now.
        n = #calls
        ok(w.head.give_back())
        ok(since(n):find('^SBHair mesh Nier true'), since(n))
        -- A ponytail the game shows again under the closet's No ponytail is hidden again.
        w = world()
        ok(w.wear({hair('SB.Hair_001'), tail('SB.Ponytail_None')}))
        w.eve.pony.visible = true
        w.tick(1) w.tick(1)
        eq(w.eve.pony.visible, false)
        clean(w.eve)
    end,

    a_hair_fight_stops_after_the_limit = function()
        local w = world()
        ok(w.wear({hair('SB.Hair_001'), tail('SB.Ponytail_None')}))
        for i = 1, Head.FIGHT.mixes - 1 do
            w.eve.hair.SkeletalMesh = nier
            w.tick(1) w.tick(1)
            eq(w.eve.hair.SkeletalMesh, h07, 're-wear ' .. i)
            -- The dress mixes again with the same list: the count goes on.
            ok(w.wear({hair('SB.Hair_001'), tail('SB.Ponytail_None')}))
        end
        w.eve.hair.SkeletalMesh = nier
        local n = #calls
        w.tick(1) w.tick(1)
        ok(w.last():find('^something outside keeps changing her hair'), w.last())
        eq(w.eve.hair.SkeletalMesh, nier, 'the outside hair stays')
        eq(#calls, n)
        w.tick(1) w.tick(1) w.tick(1)
        eq(#calls, n, 'stopped')
        -- The next wear starts again.
        ok(w.wear({hair('SB.Hair_001'), tail('SB.Ponytail_None')}))
        eq(w.eve.hair.SkeletalMesh, h07)
        -- Slower than the limit: never stops.
        w = world()
        ok(w.wear({hair('SB.Hair_001'), tail('SB.Ponytail_None')}))
        for _ = 1, 8 do
            w.eve.hair.SkeletalMesh = nier
            w.tick(1) w.tick(1) w.tick(4)
            eq(w.eve.hair.SkeletalMesh, h07)
        end
    end,

    -- The same EVE with a new SBHair (the old component gone): the watchdog reads the new one and wears on it.
    a_new_component_on_the_same_eve_gets_the_hair_again = function()
        local w = world()
        ok(w.wear({hair('SB.Hair_001')}))
        local old = w.eve.hair
        old.destroyed = true
        local new = part('EVE_1', 'SBHair', {SkeletalMesh = hr01, AnimClass = hr01_anim,
            OverrideMaterials = {colour('EVE_1')}})
        w.eve.parts[3], w.eve.hair = new, new
        w.tick(1) w.tick(1)
        eq(new.SkeletalMesh, h07, 'the new SBHair wears the hair')
        ok(w.head.give_back())
        eq(new.SkeletalMesh, hr01, "off: the new component's own hair")
    end,

    a_new_eve_gets_the_hair_again = function()
        local w = world()
        ok(w.wear({hair('SB.Hair_001')}))
        local old = w.eve
        local eve2 = eve_of('EVE_2')
        player = nil
        local n = #calls
        w.tick(1) w.tick(1)
        eq(#calls, n, 'no EVE: the pieces wait')
        player = eve2
        w.tick(1)
        eq(#calls, n, 'after 1 s nothing')
        w.tick(1)
        eq(eve2.hair.SkeletalMesh, h07, 'SBHair found again')
        eq(eve2.pony.SkeletalMesh, pony2)
        for i = n + 1, #calls do ok(not calls[i]:find('EVE_1', 1, true), calls[i]) end
        eq(old.hair.SkeletalMesh, h07, 'the old one left alone')
        local line = w.head.line()
        ok(line:find('^/Game/Map.Map:PersistentLevel.EVE_2|'), line)
        -- Off gives the new EVE's game hair back.
        n = #calls
        ok(w.head.give_back())
        eq(eve2.hair.SkeletalMesh, hr01)
        clean(old) clean(eve2)
    end,

    parts_list_the_worn_components = function()
        local w = world()
        ok(w.wear({hair('SB.Hair_001')}))
        same(w.head.parts(), {
            {c = w.eve.hair, fit = 'SB.Hair_001', mesh = h07.at_path, slots = {[0] = 'Hair'}, head = true},
            {c = w.eve.pony, fit = 'SB.Ponytail_Long', mesh = pony2.at_path, slots = {[0] = 'Ponytail'}, head = true}})
        ok(w.wear({hair('SB.Hair_001'), tail('SB.Ponytail_None')}))
        eq(#w.head.parts(), 1, 'a hidden ponytail is no part')
    end,

    rewear_changes_one_component = function()
        local w = world()
        ok(w.wear({hair('SB.Hair_001'), tail('SB.Ponytail_None')}))
        local applied = w.head.applied()
        chosen['SB.Hair_001'] = 2
        local n = #calls
        ok(w.head.rewear('SB.Hair_001'))
        eq(since(n), 'SBHair material 0 MI_H07_TypeB')
        eq(w.head.applied(), applied + 1)
        local good, why = w.head.rewear('p.hair')
        eq(good, nil) eq(why, 'p.hair is not worn')
        -- After off nothing is worn: a rewear puts nothing back.
        ok(w.head.give_back())
        n = #calls
        good, why = w.head.rewear('SB.Hair_001')
        eq(good, nil) eq(why, 'SB.Hair_001 is not worn') eq(#calls, n)
        eq(w.eve.hair.SkeletalMesh, hr01)
        -- A stock ponytail follows its hair's new colour.
        w = world()
        ok(w.wear({hair('SB.Hair_001')}))
        chosen['SB.Hair_001'] = 4
        n = #calls
        ok(w.head.rewear('SB.Hair_001'))
        ok(since(n):find('^SBHair material 0 MI_H07_TypeD|SBPonytail material 0 MI_H07_Tail_TypeD'), since(n))
    end,

    the_same_list_again_changes_nothing = function()
        local w = world()
        ok(w.wear({hair('SB.Hair_001')}))
        local applied, n = w.head.applied(), #calls
        ok(w.wear({hair('SB.Hair_001')}))
        eq(since(n), 'save|save', 'the file only') eq(w.head.applied(), applied)
        -- A variant change shows at the next wear as materials only.
        chosen['SB.Hair_001'] = 2
        n = #calls
        ok(w.wear({hair('SB.Hair_001')}))
        ok(since(n):find('^save|SBHair material 0 MI_H07_TypeB|SBPonytail material 0 MI_H07_Tail_TypeB'), since(n))
        ok(w.file:find('|SBHair;+;', 1, true) and w.file:find('|SBPonytail;+;', 1, true), w.file)
        ok(w.file:find('|SBPonytailShort;-;', 1, true), 'hidden by the closet: ' .. w.file)
    end,

    a_refusal_changes_nothing = function()
        local w = world()
        local saved = assets[h07.at_path]
        assets[h07.at_path] = nil
        local good, why = w.wear({hair('SB.Hair_001')})
        assets[h07.at_path] = saved
        eq(good, nil) ok(why:find('H07', 1, true), why)
        eq(since(0), 'save', 'no call')
        good, why = w.wear({hair('nope')})
        eq(good, nil) eq(why, 'nope is not installed')
        player = nil
        good, why = w.wear({hair('SB.Hair_001')})
        eq(good, nil) eq(why, 'no EVE in the world')
        player = w.eve
        -- A failing call gives the game's pieces back.
        w.eve.hair.anim_raises = 'no class'
        good, why = w.wear({hair('SB.Hair_001')})
        eq(good, nil) ok(why:find('no class', 1, true), why)
        eq(w.eve.hair.SkeletalMesh, hr01, 'given back')
        same(w.head.parts(), {})
    end,

    the_hair_physics_follows_the_game_rule = function()
        -- A mesh's own physics asset, else <dir>/<name>_PhysicsAsset when it loads, else none.
        local w = world()
        ok(w.wear({hair('p.hair')}))
        ok(since(0):find('SBHair physics PH_Phys false', 1, true), since(0))
        local n = #calls
        ok(w.wear({hair('SB.Hair_Nier_001')}))
        ok(since(n):find('SBHair physics Nier_PhysicsAsset false', 1, true), since(n))
        n = #calls
        ok(w.wear({hair('SB.Hair_001')}))
        ok(since(n):find('SBHair physics none false', 1, true), since(n))
    end,

    a_cut_hair_sets_its_physics_asset = function()
        local w = world()
        ok(w.wear({hair('SB.Hair_024')}))
        ok(since(0):find('^save|SBHair mesh EVE_HR_14 true|SBHair anim EVE_HR_14_AnimBP_C|SBHair physics '
            .. 'EVE_HR_14_Physics false|'), since(0))
    end,

    -- A stock ponytail follows a stock hair's salon colour only when the hair has colour controls (Fits.follows):
    -- under a cut hair (none) it keeps its own variant.
    a_cut_hair_leaves_the_stock_ponytail_its_own_colour = function()
        local w = world()
        chosen['SB.Ponytail_Long'] = 3
        ok(w.wear({hair('SB.Hair_024'), tail('SB.Ponytail_Long')}))
        ok(since(0):find('SBPonytail material 0 MI_H07_Tail_TypeC', 1, true), 'its own variant: ' .. since(0))
        w = world()
        chosen['SB.Ponytail_Long'] = 3
        ok(w.wear({hair('SB.Hair_001'), tail('SB.Ponytail_Long')}))
        ok(since(0):find('SBPonytail material 0 MI_H07_Tail_TypeA', 1, true), "the hair's variant: " .. since(0))
    end,

    -- Every head slot goes on its own component: Face on Mesh_Face (every slot of the new mesh painted), EarringL on
    -- SBAccSlot1 with its AnimBP. Neither touches SBHair or the ponytails.
    each_head_slot_goes_on_its_component = function()
        local w = world()
        ok(w.wear({{fit = 'p.fitface', slot = 'Face'}}))
        eq(since(0),
            'save|Mesh_Face mesh SK_fbface true|Mesh_Face material 0 MI_fb_0|Mesh_Face material 1 MI_fb_1|save')
        eq(w.eve.face.SkeletalMesh, fit_face)
        same(w.head.worn(), {['p.fitface'] = 'Face'})
        eq(#w.told, 0, 'on the body\'s skeleton: nothing to say')
        w = world()
        ok(w.wear({{fit = 'SB.Earring_001', slot = 'EarringL'}}))
        eq(since(0), 'save|SBAccSlot1 mesh ACC_EAR_01M true|SBAccSlot1 anim ACC_EAR_01M_AnimBP_C|'
            .. 'SBAccSlot1 material 0 MI_EAR_01|save')
        same(w.head.parts(), {{c = w.eve.acc, fit = 'SB.Earring_001', mesh = ear01.at_path, slots = {[0] = 'EarringL'},
            head = true}})
        -- A pack face on her own face mesh: its material, her mesh's own on every other slot.
        w = world()
        ok(w.wear({{fit = 'p.klukai', slot = 'Face'}}))
        ok(since(0):find('^save|Mesh_Face mesh CH_P_EVE_Face_Jali3 true|Mesh_Face material 0 MI_Klukai|Mesh_Face '
            .. 'material 1 MI_Face_1|'), since(0))
        ok(since(0):find('Mesh_Face material 7 MI_Face_7|save$'), since(0))
    end,

    a_non_hair_slot_never_touches_the_ponytail = function()
        local w = world()
        ok(w.wear({hair('SB.Hair_001'), {fit = 'SB.Earring_001', slot = 'EarringL'}}))
        local n = #calls
        ok(w.head.rewear('SB.Earring_001'))
        eq(since(n), 'SBAccSlot1 material 0 MI_EAR_01', 'the earring only')
        -- A face or an earring alone: her ponytail never gets a call.
        w = world()
        ok(w.wear({{fit = 'p.fitface', slot = 'Face'}, {fit = 'SB.Earring_001', slot = 'EarringL'}}))
        ok(not since(0):find('SBPonytail', 1, true), since(0))
        ok(w.head.give_back())
        ok(not since(0):find('SBPonytail', 1, true), since(0))
    end,

    -- Glasses, Headwear and Mask go on a component the closet makes: a piece on another skeleton than the body's on the
    -- head socket with SBAccSlot1's rotation, one on the body's skeleton master-posed to her body.
    made_slots_wear_on_a_made_component = function()
        local w = world()
        local GLA = {fit = 'SB.FaceAccessory_001', slot = 'Glasses'}
        ok(w.wear({hair('SB.Hair_001'), GLA}))
        eq(w.eve.hair.SkeletalMesh, h07, 'the hair worn')
        ok(since(0):find('|SBSkeletalMeshComponent_0 attach CharacterMesh0 Bip001-Head|SBSkeletalMeshComponent_0 '
            .. 'rotation -90 180 90|SBSkeletalMeshComponent_0 mesh ACC_GLA_01M true|SBSkeletalMeshComponent_0 '
            .. 'material 0 MI_GLA_01|SBSkeletalMeshComponent_0 material 1 MI_ACC_Glass_Base|save', 1, true), since(0))
        local c = w.eve.made[1]
        eq(#w.eve.made, 1) eq(c.SkeletalMesh, glasses)
        same(w.head.worn(), {['SB.Hair_001'] = 'Hair', ['SB.FaceAccessory_001'] = 'Glasses'})
        same(w.head.unworn(), {})
        local parts = w.head.parts()
        same(parts[#parts], {c = c, fit = 'SB.FaceAccessory_001', mesh = glasses.at_path,
            slots = {[0] = 'Glasses', [1] = 'Glasses'}, head = true})
        -- The same list again: no call.
        local n = #calls
        ok(w.wear({hair('SB.Hair_001'), GLA}))
        eq(since(n), 'save|save')
        -- A body-skeleton piece follows her pose, no socket.
        w = world()
        ok(w.wear({{fit = 'p.hat', slot = 'Headwear'}}))
        eq(since(0), 'save|SBSkeletalMeshComponent_0 attach CharacterMesh0 None|SBSkeletalMeshComponent_0 mesh Hat '
            .. 'true|SBSkeletalMeshComponent_0 master CharacterMesh0|SBSkeletalMeshComponent_0 material 0 MI_Hat|save')
        chosen['p.hat'] = 2 -- A variant change: its materials only, on the same component.
        n = #calls
        ok(w.head.rewear('p.hat'))
        eq(since(n), 'SBSkeletalMeshComponent_0 material 0 MI_Band') eq(#w.eve.made, 1)
        clean(w.eve)
    end,

    -- Never two of one slot: the next piece makes a new component and destroys the last, with all its materials.
    never_two_of_one_made_slot = function()
        local w = world()
        ok(w.wear({{fit = 'SB.FaceAccessory_001', slot = 'Glasses'}}))
        local n = #calls
        ok(w.wear({{fit = 'SB.FaceAccessory_029', slot = 'Glasses'}}))
        ok(since(n):find('^save|SBSkeletalMeshComponent_0 destroy|SBSkeletalMeshComponent_1 attach'), since(n))
        eq(w.eve.made[1]:IsValid(), false) eq(w.eve.made[2].SkeletalMesh, glasses2)
        eq(#w.eve.made[2].OverrideMaterials, 1, 'no material of the last piece')
        -- Glasses and a mask together: one component each.
        ok(w.wear({{fit = 'SB.FaceAccessory_029', slot = 'Glasses'}, {fit = 'p.mask', slot = 'Mask'}}))
        eq(#w.eve.made, 3) eq(w.eve.made[2]:IsValid(), true) eq(w.eve.made[3]:IsValid(), true)
    end,

    -- Taken off (its None tile), closet off and coop off destroy a made component.
    a_made_piece_off_is_destroyed = function()
        local w = world()
        ok(w.wear({hair('SB.Hair_001'), {fit = 'p.mask', slot = 'Mask'}}))
        local n = #calls
        ok(w.wear({hair('SB.Hair_001')}))
        eq(since(n), 'save|SBSkeletalMeshComponent_0 destroy|save')
        same(w.head.worn(), {['SB.Hair_001'] = 'Hair'})
        ok(w.wear({{fit = 'p.mask', slot = 'Mask'}}))
        n = #calls
        ok(w.head.give_back())
        eq(since(n), 'SBSkeletalMeshComponent_1 destroy') same(w.head.parts(), {})
        ok(w.wear({{fit = 'p.mask', slot = 'Mask'}}))
        w.head.stop()
        eq(w.eve.made[3]:IsValid(), false)
        ok(not w.head.line():find('Mask', 1, true), 'off: no made piece in the line')
    end,

    -- The line names the made piece's mesh; the next Lua load sweeps the leftover by its name prefix and that mesh,
    -- then the dress's restore wears the kept look again: one component.
    a_made_leftover_is_swept_at_the_next_load = function()
        local w = world()
        ok(w.wear({{fit = 'SB.FaceAccessory_001', slot = 'Glasses'}}))
        ok(w.file:find('|Glasses;+;' .. glasses.at_path, 1, true), w.file)
        local logs = {}
        local h2 = Head.new({log = function(m) logs[#logs + 1] = m end, fits = fits})
        h2.restore(w.file)
        eq(w.eve.made[1]:IsValid(), false)
        ok(logs[1]:find('Glasses removed', 1, true), tostring(logs[1]))
        ok(h2.wear({{fit = 'SB.FaceAccessory_001', slot = 'Glasses'}}))
        local live = 0
        for _, c in ipairs(w.eve.made) do if c:IsValid() then live = live + 1 end end
        eq(live, 1)
        -- No head fit known at the restore: the leftover still goes (the line names its mesh).
        w = world()
        ok(w.wear({{fit = 'SB.FaceAccessory_001', slot = 'Glasses'}}))
        Head.new({log = function() end, fits = {get = function() end, heads = function() return {} end}})
            .restore(w.file)
        eq(w.eve.made[1]:IsValid(), false)
    end,

    -- A made component whose step fails is destroyed: the wear fails and nothing is left on EVE.
    a_failed_made_piece_leaves_nothing = function()
        local w = world()
        w.eve.mesh_raises = true
        local good, why = w.wear({hair('SB.Hair_001'), {fit = 'p.hat', slot = 'Headwear'}})
        eq(good, nil) ok(why:find('no mesh', 1, true), why)
        eq(w.eve.made[1]:IsValid(), false, 'destroyed')
        eq(w.eve.hair.SkeletalMesh, hr01, 'the rest given back')
    end,

    -- A made component gone (something destroyed it, a new EVE) is made again by the watchdog.
    a_lost_made_piece_comes_back = function()
        local w = world()
        ok(w.wear({{fit = 'p.mask', slot = 'Mask'}}))
        w.eve.made[1].destroyed = true
        w.tick(1) w.tick(1)
        eq(#w.eve.made, 2) eq(w.eve.made[2].SkeletalMesh, glasses)
        local eve2 = eve_of('EVE_2')
        player = eve2
        w.tick(1) w.tick(1)
        eq(#eve2.made, 1, 'made on the new EVE') eq(w.eve.made[2]:IsValid(), false, 'the old EVE\'s destroyed')
    end,

    -- Off gives each component the game's own back: no closet AnimBP or material left behind.
    an_earring_off_leaves_nothing_behind = function()
        local w = world()
        ok(w.wear({{fit = 'SB.Earring_001', slot = 'EarringL'}}))
        local n = #calls
        ok(w.head.give_back())
        eq(since(n), 'SBAccSlot1 mesh none true|SBAccSlot1 anim none|SBAccSlot1 physics none false|'
            .. 'SBAccSlot1 material 0 none')
        eq(w.eve.acc.AnimClass, nil)
        -- A game earring before: its mesh, class and material back.
        local ear02 = mesh('00_ACC/ACC_EAR_02/ACC_EAR_02M', {material('00_ACC/ACC_EAR_02/MI_EAR_02')})
        local ear02_anim = asset(p('00_ACC/ACC_EAR_02/ACC_EAR_02M_AnimBP') .. '_C', ANIM)
        w = world()
        w.eve.acc.SkeletalMesh, w.eve.acc.AnimClass = ear02, ear02_anim
        ok(w.wear({{fit = 'SB.Earring_001', slot = 'EarringL'}}))
        n = #calls
        ok(w.wear({hair('SB.Hair_001')})) -- The None tile on the earring row.
        ok(since(n):find('SBAccSlot1 mesh ACC_EAR_02M true|SBAccSlot1 anim ACC_EAR_02M_AnimBP_C|', 1, true), since(n))
        ok(since(n):find('SBAccSlot1 material 0 MI_EAR_02', 1, true), since(n))
        eq(w.eve.acc.AnimClass, ear02_anim)
        -- The next Lua load's restore does the same.
        w = world()
        ok(w.wear({{fit = 'SB.Earring_001', slot = 'EarringL'}}))
        Head.new({log = function() end, fits = fits}).restore(w.file)
        eq(w.eve.acc.SkeletalMesh, nil) eq(w.eve.acc.AnimClass, nil)
        eq(w.eve.acc.OverrideMaterials[1], invalid, 'no override left')
    end,

    restore_gives_each_component_back = function()
        local w = world()
        ok(w.wear({{fit = 'p.fitface', slot = 'Face'}, {fit = 'SB.Earring_001', slot = 'EarringL'}}))
        local n = #calls
        ok(w.head.give_back())
        ok(since(n):find('Mesh_Face mesh CH_P_EVE_Face_Jali3 true', 1, true), since(n))
        ok(since(n):find('SBAccSlot1 mesh none true', 1, true), since(n))
        eq(w.eve.face.SkeletalMesh, jali) eq(w.eve.acc.SkeletalMesh, nil)
        ok(not since(n):find('SBPonytail', 1, true), since(n))
        -- Field 6 keeps each component the closet changed; the next Lua load gives each back.
        w = world()
        ok(w.wear({{fit = 'p.fitface', slot = 'Face'}, {fit = 'SB.Earring_001', slot = 'EarringL'}}))
        ok(w.file:find('|Mesh_Face;+;' .. jali.at_path, 1, true), w.file)
        ok(w.file:find('|SBAccSlot1;+;;', 1, true), w.file)
        local logs = {}
        Head.new({log = function(m) logs[#logs + 1] = m end, fits = fits}).restore(w.file)
        eq(w.eve.face.SkeletalMesh, jali, tostring(logs[1])) eq(w.eve.acc.SkeletalMesh, nil, tostring(logs[1]))
        eq(w.eve.hair.SkeletalMesh, hr01)
    end,

    -- A face whose mesh is not on the body's skeleton is worn and said once per wear.
    a_face_on_another_skeleton_is_said_once = function()
        local w = world()
        ok(w.wear({{fit = 'p.raven', slot = 'Face'}}))
        eq(w.eve.face.SkeletalMesh, raven)
        same(w.told, {'FACE_RIG'})
        ok(w.wear({{fit = 'p.raven', slot = 'Face'}}))
        same(w.told, {'FACE_RIG'}, 'the same look again: not said again')
        w.eve.face.SkeletalMesh = jali
        w.tick(1) w.tick(1)
        eq(w.eve.face.SkeletalMesh, raven, 'worn again by the watchdog')
        same(w.told, {'FACE_RIG'}, 'the watchdog says nothing')
    end,

    -- EVE's own eyes: a colour-only part on Mesh_Face (its controls paint slots 4 and 7), while her face is her own.
    the_eyes_part_paints_mesh_face_slot_4 = function()
        local w = world()
        ok(w.wear({{fit = 'SB.Eyes_Own', slot = 'Eyes'}}))
        eq(since(0), 'save|save', 'no mesh call')
        same(w.head.parts(), {{c = w.eve.face, fit = 'SB.Eyes_Own', mesh = jali.at_path, slots = {[4] = 'Eyes',
            [7] = 'Eyes'}, head = true}})
        eq(w.head.eyes_locked(), false)
        -- Off: a slot painted since gets the mesh's own material.
        w.eve.face:SetMaterial(4, material('P/MID_eyes'))
        local n = #calls
        ok(w.head.give_back())
        ok(since(n):find('Mesh_Face material 4 MI_Face_4', 1, true), since(n))
        -- With a pack face on her own mesh: both parts, the eyes' slots not the face's.
        w = world()
        ok(w.wear({{fit = 'p.klukai', slot = 'Face'}, {fit = 'SB.Eyes_Own', slot = 'Eyes'}}))
        local parts = w.head.parts()
        eq(#parts, 2)
        eq(parts[1].fit, 'p.klukai') eq(parts[1].slots[4], nil) eq(parts[1].slots[0], 'Face')
        same(parts[2].slots, {[4] = 'Eyes', [7] = 'Eyes'}) eq(parts[2].c, w.eve.face)
        -- Another face mesh locks them: the eyes skipped and said once, the face worn.
        w = world()
        eq(w.head.eyes_locked('p.fitface'), true) eq(w.head.eyes_locked('p.klukai'), false)
        ok(w.wear({{fit = 'p.fitface', slot = 'Face'}, {fit = 'SB.Eyes_Own', slot = 'Eyes'}}))
        eq(w.eve.face.SkeletalMesh, fit_face)
        same(w.head.worn(), {['p.fitface'] = 'Face'}) same(w.head.unworn(), {['SB.Eyes_Own'] = 'Eyes'})
        eq(#w.head.parts(), 1, 'no Eyes part')
        local count = 0
        w.eve.face.SkeletalMesh = jali
        w.tick(1) w.tick(1)
        for _, l in ipairs(w.logs) do if l:find('not worn: SB.Eyes_Own', 1, true) then count = count + 1 end end
        eq(count, 1, 'said once: ' .. table.concat(w.logs, ' / '))
        eq(w.head.eyes_locked(), true, 'the worn face is not hers')
    end,
}

run('head_wear_test', tests)
