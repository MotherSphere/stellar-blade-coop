-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet: fit maps, which split a CNS-format full outfit into pieces. Pure data, no engine calls.
--
-- A fit map is keyed by the outfit's UniqueFitID and names, for its mesh, which material slots make each piece and
-- which show the skin. It holds only slot numbers and names: nothing of the creator's pack is copied. The numbers come
-- from the mesh's material slots (the spike's slot dump, 25 Nov 2026) and the names from the pack's own
-- UserConfigs.MaterialToggles.
--   Outfit   the outfit's name on screen, Pack the pack that makes it
--   Origin   'original' (Shift Up's own suits, CH_P_EVE_*) or 'custom' (an installed pack's outfit); nil is custom
--   Mesh     the outfit's mesh, as its pack names it
--   Skin     {material index = {regions it shows}}: the outfit's own skin, which supplies the body whenever this
--            outfit is the body (closet/dress.lua's Dress.plan: picked as <fit>:BaseBody, else its body rule). A fit
--            with Skin has the pseudo slot BaseBody, which no piece fills
--   Pieces   {Slot, Name, Materials = {indexes}, Off = true when the pack hides it by default, Occupies = {slots},
--            Covers = {regions}: the regions it covers, whose skin slots go when all theirs are covered}
--   Unknown  {indexes}: slots whose piece and place are not known yet (no toggle name says it); they stay hidden
--            when the outfit is worn as pieces
local Fits = {}

local ALL_SKIN = {'HeadNeck', 'TorsoUpper', 'TorsoLower', 'Pelvis', 'ArmUpper', 'Forearm', 'Hand', 'Thigh', 'Calf',
    'Foot'}

Fits.BY_ID = {
    -- AiK: Ocean Maid. One skin slot (Body_P1, 14) for the whole body.
    AiK_CH27_14595 = {
        Outfit = 'Ocean Maid',
        Pack = 'AiK',
        Mesh = '/Game/OutfitMods/AiK_CH27/CH27_NRS.CH27_NRS',
        Skin = {[14] = ALL_SKIN},
        Pieces = {
            {Slot = 'UndergarmentTop', Name = 'Leotard', Materials = {40, 41}, Occupies = {'UndergarmentBottom'}},
            {Slot = 'Chest', Name = 'Maid top', Materials = {15, 44, 19, 47, 18, 16, 29, 30, 20, 22, 21, 31}},
            {Slot = 'Collar', Name = 'Bow tie collar', Materials = {26, 27, 28}},
            {Slot = 'Armbands', Name = 'Arm accents', Materials = {23, 32}},
            {Slot = 'Gloves', Name = 'Ruffled cuffs', Materials = {17, 24, 25}},
            {Slot = 'ThighStraps', Name = 'Leg accents', Materials = {38, 34}},
            {Slot = 'Shoes', Name = 'Ruffled heels', Materials = {35, 36, 37}},
            {Slot = 'Legs', Name = 'Stockings', Materials = {42, 43}, Off = true},
            {Slot = 'Fingernails', Name = 'Nails', Materials = {0}},
            {Slot = 'Toenails', Name = 'Toenails', Materials = {46}},
            {Slot = 'PubicHair', Name = 'Pubic hair', Materials = {10, 11, 12, 13}, Off = true},
        },
        -- 1-9: piercings A1-A5, B1, C1, D1, D2 (place not named); 33: a glow; 39, 45: vinyl looks of the leotard and
        -- the top (default off).
        Unknown = {1, 2, 3, 4, 5, 6, 7, 8, 9, 33, 39, 45},
    },
    -- AiK: Kunoichi Shadow. Skin in three slots: body (0), arms (1) and hands (2); the pack hides the arms and hands
    -- skin while its gloves are on.
    AiK_CH46_xSH_14462 = {
        Outfit = 'Kunoichi Shadow',
        Pack = 'AiK',
        Mesh = '/Game/OutfitMods/AiK_CH46/CH46_xSH_NRS.CH46_xSH_NRS',
        Skin = {[0] = {'HeadNeck', 'TorsoUpper', 'TorsoLower', 'Pelvis', 'Thigh', 'Calf', 'Foot'},
            [1] = {'ArmUpper', 'Forearm'}, [2] = {'Hand'}},
        Pieces = {
            {Slot = 'Outerwear', Name = 'Shadow jacket', Materials = {3, 4, 5}},
            {Slot = 'Chest', Name = 'Kunoichi top', Materials = {6, 7, 8}},
            {Slot = 'ChestHardware', Name = 'Harness', Materials = {9, 13, 10, 11, 14, 12, 15}},
            {Slot = 'Gloves', Name = 'Long gloves', Materials = {16, 17}, Covers = {'ArmUpper', 'Forearm', 'Hand'}},
            {Slot = 'BraceletL', Name = 'Watch', Materials = {18}},
            {Slot = 'AnkletL', Name = 'Anklet L', Materials = {22}},
            {Slot = 'AnkletR', Name = 'Anklet R', Materials = {21}},
            {Slot = 'Shoes', Name = 'Shadow heel boots', Materials = {19, 20, 33, 35}},
            {Slot = 'Legs', Name = 'Stockings', Materials = {42, 43}, Off = true},
            {Slot = 'Fingernails', Name = 'Nails', Materials = {25}, Off = true},
            {Slot = 'PubicHair', Name = 'Pubic hair', Materials = {38, 39, 40, 41}, Off = true},
        },
        -- 23, 24: "Brew" P1, P2 (piece not named); 26-32, 36, 37: piercings A1-A5, B1, C1, D2, D1 (place not
        -- named); 34: the top's vinyl look (default off).
        Unknown = {23, 24, 26, 27, 28, 29, 30, 31, 32, 34, 36, 37},
    },
}

-- The fit map of an outfit, or nil.
function Fits.get(fit_id) return Fits.BY_ID[fit_id] end

-- The piece of a fit map in a slot, or nil.
function Fits.piece(fit_id, slot)
    local fit = Fits.BY_ID[fit_id]
    for _, piece in ipairs(fit and fit.Pieces or {}) do
        if piece.Slot == slot then return piece end
    end
    return nil
end

return Fits
