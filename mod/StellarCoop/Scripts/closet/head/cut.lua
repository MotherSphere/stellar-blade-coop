-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet's two cut hairs: Nyaaa (EVE_HR_14) and Mecha Rabbit (EVE_HR_15), hairs the game ships with no
-- ItemTable or EquipmentTable row. Schizo's one exception to "no hand-made list" (27 Nov 2026): the paths below were
-- read in the game's asset data, not taken from eve/wear.lua.
--
-- Cut.items(env) -> {['SB.Hair_024']=item, ['SB.Hair_025']=item}, in closet/head/stock.lua's item shape.
--   env.text(key): the ItemStringTable entry of key in the player's language, or nil.
-- One variant each: the mesh's own materials (the salon-like TypeB-D sets of EVE_HR_14 pair by name only, so they
-- are left out). No rotation: no table row gives one, so the hair component keeps its own. The stock ponytail rule
-- applies as for a stock hair that has one: closet/head/wear.lua wears SB.Ponytail_Short or SB.Ponytail_Long.
local Cut = {}

local HR = '/Game/Art/Character/PC/00_HR/'
local function asset(path) return path .. '.' .. path:match('[^/]+$') end

-- Asset data (base paks, cue_dump of 27 Nov 2026): SB/Content/Art/Character/PC/00_HR/EVE_HR_14/EVE_HR_14.uasset and
-- EVE_HR_15/EVE_HR_15.uasset (SkeletalMesh, SkeletalMaterials in slot order), EVE_HR_14_AnimBP.uasset and
-- EVE_HR_15_AnimBP.uasset (AnimBlueprintGeneratedClass EVE_HR_14_AnimBP_C, EVE_HR_15_AnimBP_C), EVE_HR_14_Physics and
-- EVE_HR_15_Physics (PhysicsAsset), Art/UI/Texture/Hair/HairIcon/Deco_Item_Hair_024 (no icon for 025). Names:
-- SB/Content/Local/Localize/ItemStringTable.uasset keys Item_Hair_024_Name, Item_Hair_025_Name.
local HAIRS = {
    {row = 'Hair_024', dir = HR .. 'EVE_HR_14/', mesh = 'EVE_HR_14',
        image = asset('/Game/Art/UI/Texture/Hair/HairIcon/Deco_Item_Hair_024'),
        materials = {asset(HR .. 'EVE_HR_14/Materials/MI_EVE_HR_14_TypeA'),       -- Hair
            asset(HR .. 'EVE_HR_11/Materials/MI_EVE_HR_11_Hairpin'),               -- ACC (a Material)
            asset(HR .. 'EVE_HR_14/Materials/MI_EVE_HR_14_Emissive'),             -- Material #8584
            asset(HR .. 'EVE_HR_14/Materials/MI_EVE_HR_14_Band')}},               -- Material #8583
    {row = 'Hair_025', dir = HR .. 'EVE_HR_15/', mesh = 'EVE_HR_15',
        materials = {asset(HR .. 'EVE_HR_06/Material/MI_EVE_HR_06_TypeA'),        -- EVE_HR_06
            asset(HR .. 'EVE_HR_15/Materials/MI_EVE_HR_15'),                      -- EVE_HR_15
            asset(HR .. 'EVE_HR_15/Materials/MI_EVE_HR_15_Emissive')}},           -- EVE_HR_15_Emissive
        -- Slot 3 (anisotropic1) has no material in the mesh: none set.
}

local function lists()
    return {ShapeKeys = {}, MaterialToggles = {}, ScalarControls = {}, VectorControls = {}, TextureOptions = {}}
end

function Cut.items(env)
    local items = {}
    for _, h in ipairs(HAIRS) do
        local id = 'SB.' .. h.row
        local mesh = asset(h.dir .. h.mesh)
        local ok, name = pcall(env.text, 'Item_' .. h.row .. '_Name')
        local configs = lists()
        items[id] = {UniqueFitID = id, Slot = 'Hair', Origin = 'original',
            DisplayName = ok and type(name) == 'string' and name ~= '' and name or h.row, Image = h.image,
            AnimationBP = asset(h.dir .. h.mesh .. '_AnimBP') .. '_C',
            PhysicsAsset = asset(h.dir .. h.mesh .. '_Physics'),
            HidePonytail = false, Ponytail = 'SB.Ponytail_Long', Mesh = mesh,
            Variants = {{Mesh = mesh, Materials = {table.unpack(h.materials)}, UserConfigs = configs}},
            UserConfigs = configs, PieceHints = {}}
    end
    return items
end

return Cut
