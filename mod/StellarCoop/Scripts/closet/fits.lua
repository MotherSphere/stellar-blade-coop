-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet: fit maps, which split a CNS-format full outfit into pieces. Pure data, no engine calls.
--
-- A fit map is keyed by the outfit's UniqueFitID and names, for its mesh, which material slots make each piece and
-- which show the skin. It holds only slot numbers and names: nothing of the creator's pack is copied. The numbers come
-- from the mesh's material slots, read in game on 25 Nov 2026 (coop closet skin <fit> <n> on refuses an n past the
-- mesh's last slot), and the names from the pack's own UserConfigs.MaterialToggles.
--   Outfit   the outfit's name on screen, Pack the pack that makes it
--   Origin   'original' (Shift Up's own suits, CH_P_EVE_*) or 'custom' (an installed pack's outfit, the default when
--            left out: Fits.origin)
--   Mesh     the outfit's mesh, as its pack names it
--   Image    the outfit's picture, as its pack names it (its OutfitImage object path); the menu's tiles show it when it
--            loads as a Texture2D and no picture of closet/thumbs.lua's is cached
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
        Image = '/Game/Art/UI/Texture/Item/NanoSuit/NanoSuit_Icon_BS_56.NanoSuit_Icon_BS_56',
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
        Image = '/Game/Art/UI/Texture/Item/NanoSuit/NanoSuit_Icon_BS_SilverKunoichi.NanoSuit_Icon_BS_SilverKunoichi',
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

-- The pack fits of the catalogue last given to Fits.use (closet/wiring.lua, at each pack scan), by UniqueFitID.
Fits.PACKS = {}

-- A pack's name for the menu: its file name without the .dekcns.json ending (with or without the dot).
local function pack_name(file)
    local name = (file or ''):match('([^\\/]*)$')
    return (name:gsub('%.?[Dd][Ee][Kk][Cc][Nn][Ss]%.[Jj][Ss][Oo][Nn]$', ''))
end

-- The fit of a pack item (closet/packs.lua's catalogue, closet/cns_import.lua's item) in its variant v, or nil when it
-- has no such variant. It is worn whole (Whole): every material section shows but Hidden (the variant's HiddenMats)
-- and the slots whose toggle is off (Toggles, MaterialToggles' MaterialIndex = Value; of two toggles on one slot an
-- off one wins). A hand fit with the same UniqueFitID keeps its piece map (Skin, Pieces, Unknown) and its Pack name
-- for the fitting tabs.
function Fits.pack(item, v)
    local variant = item.Variants[v]
    if not variant then return nil end
    local hand = Fits.BY_ID[item.UniqueFitID] or {}
    local toggles = {}
    for _, t in ipairs(item.UserConfigs.MaterialToggles) do
        local index = type(t) == 'table' and type(t.MaterialIndex) == 'number' and math.tointeger(t.MaterialIndex)
        if index and index >= 0 then toggles[index] = toggles[index] ~= false and t.Value ~= false end
    end
    -- Variants: the item's list (the options page's Variant row); Materials and Parameters: the variant's, which
    -- closet/dress.lua puts on the mesh it wears; Hints: the item's PieceHints (the options page's sections).
    return {Outfit = item.DisplayName, Pack = hand.Pack or pack_name(item.File or item.Pack), Origin = 'custom',
        Mesh = variant.Mesh, Image = item.Image or hand.Image, Variant = v, Hidden = variant.HiddenMats,
        Materials = variant.Materials, Parameters = variant.Parameters, Variants = item.Variants,
        Toggles = toggles, Controls = item.UserConfigs, Hints = item.PieceHints, Whole = true, Skin = hand.Skin,
        Pieces = hand.Pieces or {}, Unknown = hand.Unknown}
end

-- The variant chosen for an outfit (closet/options.lua's, Fits.choose), by UniqueFitID; left out: the first. Kept
-- across scans: a pack scan wears it again, the first when the pack no longer has it.
Fits.CHOSEN = {}
-- The suits of the catalogue last given to Fits.use, by UniqueFitID (Fits.choose builds a variant's fit from them).
Fits.ITEMS = {}

-- The catalogue's suits (FitMeshType Body or none) as pack fits in their chosen variant.
local function packs_of(catalogue)
    local out = {}
    for id, item in pairs(catalogue) do
        if item.Slot == 'FullOutfit' then out[id] = Fits.pack(item, Fits.CHOSEN[id] or 1) or Fits.pack(item, 1) end
    end
    return out
end

-- Variant v of an outfit from now on (its pack fit made again when its pack is read); false when its pack is read
-- and has no such variant.
function Fits.choose(fit_id, v)
    local item = Fits.ITEMS[fit_id]
    local fit = item and Fits.pack(item, v)
    if item and not fit then return false end
    Fits.CHOSEN[fit_id] = v ~= 1 and v or nil
    if fit then Fits.PACKS[fit_id] = fit end
    return true
end

-- The control of a UserConfigs list that control follows (its ControlledBy names another one's DisplayName, the first
-- of that name; followed on through a chain), or control itself when it follows none or the chain loops.
function Fits.leader(list, control)
    local seen, at = {}, control
    while type(at.ControlledBy) == 'string' and at.ControlledBy ~= '' and not seen[at] do
        seen[at] = true
        local next_one
        for _, c in ipairs(list) do
            if type(c) == 'table' and c.DisplayName == at.ControlledBy and c ~= at then next_one = c; break end
        end
        if not next_one then return at end
        at = next_one
    end
    return seen[at] and control or at
end

-- Every fit by UniqueFitID: the hand fits, then the pack fits of catalogue (Fits.PACKS when nil) over them.
function Fits.all(catalogue)
    local out = {}
    for id, fit in pairs(Fits.BY_ID) do out[id] = fit end
    for id, fit in pairs(catalogue and packs_of(catalogue) or Fits.PACKS) do out[id] = fit end
    return out
end

-- The catalogue's pack fits become Fits.PACKS (nil: none).
function Fits.use(catalogue)
    Fits.ITEMS = catalogue or {}
    Fits.PACKS = packs_of(Fits.ITEMS)
end

-- The material sections a Whole fit shows on a mesh of count slots: {[index] = true}.
function Fits.shows(fit, count)
    local hide = {}
    for _, index in ipairs(fit.Hidden or {}) do hide[index] = true end
    for index, on in pairs(fit.Toggles or {}) do hide[index] = hide[index] or not on end
    local out = {}
    for index = 0, count - 1 do out[index] = not hide[index] or nil end
    return out
end

-- The fit of an outfit (a pack fit first, then a hand fit), or nil.
function Fits.get(fit_id) return Fits.PACKS[fit_id] or Fits.BY_ID[fit_id] end

-- An outfit's origin: 'original' or 'custom' (the default).
function Fits.origin(fit_id) return (Fits.get(fit_id) or {}).Origin or 'custom' end

-- The piece of a fit map in a slot, or nil.
function Fits.piece(fit_id, slot)
    local fit = Fits.get(fit_id)
    for _, piece in ipairs(fit and fit.Pieces or {}) do
        if piece.Slot == slot then return piece end
    end
    return nil
end

-- A fit id as a word of the closet's files and back: each byte outside [A-Za-z0-9_.-] is %XX, so a pack's UniqueFitID
-- with a space, ':', ',', a tab or a non-ASCII letter survives the files' splits. A plain id is its own word.
function Fits.word(fit_id)
    return (tostring(fit_id):gsub('[^%w_%.%-]', function(c) return ('%%%02X'):format(c:byte()) end))
end
function Fits.unword(word)
    return (tostring(word):gsub('%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end))
end

return Fits
