-- Get-on suit transform (2026-11-19): instead of the riding outfit snapping on, two looks taken from the game itself.
--  prologue: the drop-pod scene (MV_Prologue_DropPodOpen_QTE_02_Complete, 6.3-10.8 s). The game puts the master
--    MA_BodySuit_Masking on both outfits and moves one HeightMask value: the new suit (MaskDirection 1) and the old one
--    (MaskDirection 0) meet at the same line. Plus its cyan scan-band decal, shrinking ring, body flash and particles.
--  tachy: the Tachy Mode start show FX_TachyModeStartFX played on Eve (lightning, burst, outline, slow motion, screen
--    warp), the swap hidden in its flash. Coloured (2026-11-19, after Saroj's ride: the rebuilt copy only lit the
--    ground): the game's own show still plays; its two decal keys point at our tinted MIDs, its lightning gets its
--    own colour inputs (User.CustomColor / User.Color) and its sparks and trail MIDs of their materials. The keys are
--    put back at the end, so the real Tachy Mode in combat keeps its gold.
-- Outfit colours (2026-11-19): the effect takes the palette of the outfit she turns INTO (suit_palettes.lua, made by
-- tools/gen_suit_palettes.py from the game's data): Fusion Rider at get on, her own outfit at get off (the same
-- transform backwards). Every asset is loaded once on foot (M.Preload) and held by a hidden keeper; a transform only
-- sets colour numbers. Game outfits only (CNS outfits are not considered): anything else gets a neutral ice blue.
-- All game assets; our own materials would render black. Untested in game.
local M = {}
local D

M.Style = "tachy"       -- "prologue", "tachy", "off", or "cycle" (test build: every get on plays the other one)
M.Match = true          -- outfit colours (the game's own show, recoloured); false = the game's own gold / cyan look
M.Time = 1.6            -- prologue wipe, seconds (the scene took 1.5 s)
M.H0, M.H1 = 2.0, -0.2  -- HeightMask start and end; the scene ran 2.0 -> 0.9 on a kneeling Eve (unit unknown, see log)
M.TachySwap = 0.12      -- tachy: seconds into the show before the outfit changes
M.TachyTime = 0.9       -- tachy without the show (fallback particles): runs as long as the show's depth-shade decal
M.ShowScan = 2.5        -- coloured show: real seconds its new parts are looked for (0.2x slow motion stretches it)

local PRO = "/Game/Art/FX/Enviroment/Beach/Cinematic/Prologue_DropPodOpen/"
local MASK = "/Game/Art/Character/Generic/MF/BodySuit/MA_BodySuit_Masking.MA_BodySuit_Masking"
local SHOW = "/Game/Art/FX/Show/Common/FX_TachyModeStartFX.FX_TachyModeStartFX"
local EX = "/Game/Art/FX/Char/PC/Common/ExMode/"
local CLOTH = "/Game/Art/FX/Char/PC/Common/Cloth/"
local function Asset(dir, n) return dir .. n .. "." .. n end
local SKILL = "/Game/Art/FX/Char/PC/Common/SkillFX/"
local NS = { ring = Asset(PRO, "NS_A_TransformRing"), flash = Asset(PRO, "NS_A_BodyChangeFlash_1"),
    parts = Asset(PRO, "NS_A_BodyParticleTest"), burst = Asset(EX, "NS_A_ModeChangeParticle_1"),
    boom = Asset(EX, "NS_A_TachyModeStartBoom"), spin = Asset(SKILL .. "Wind/", "NS_PC_SpinTrail_01"),
    ground = Asset(SKILL .. "Lightning/", "NE_A_LightingGround"), force = Asset(EX, "NS_A_LightningForce") }
local DECAL = { change = Asset(PRO, "MI_ChangeDecal_1"), outline = Asset(CLOTH, "MI_A_CharOutlineDecal_01_3"),
    depth = Asset(CLOTH, "MI_DepthShadeDecal_TachyMode") }
-- FX_TachyModeStartFX keys (FModelCli 2026-11-19). Decals: outline Color (5, 2, 0), depth shade (2, 0.8, 0.05), both
-- target-only (they paint only Eve). Particle keys 0 (boom) and 7 (lightning force) spawn unattached: attached for the
-- coloured show so they can be found among her parts.
local DKEY = { outline = "SBShowDecalKey_0", depth = "SBShowDecalKey_1" }
local AKEY = { "SBShowParticleKey_0", "SBShowParticleKey_7" }
-- the show's systems; lightning has Niagara colour inputs (the show sets ground (1, 0.5, 0.1..0.2), force (2, 1.2, 0.6))
local SHOWSYS = { NS_A_ModeChangeParticle_1 = true, NS_A_TachyModeStartBoom = true, NS_PC_SpinTrail_01 = true,
    NE_A_LightingGround = { "User.CustomColor", 1 }, NS_A_LightningForce = { "User.Color", 2 } }
-- material name part -> vector params set on a MID of it (defaults: sparks ColorTest (5, 2.5, 0.5), trail (1,1,1) / 0.5).
-- MI_A_Electric_01_1 (the burst's lightning) and the ribbons have no colour param: their colour is baked.
local MATCOL = { { "Spark", { { "ColorTest", "main", 5 } } },
    { "ShockWv", { { "HighlightColor", "accent", 5 }, { "EdgeColor", "main", 5 } } },
    { "WindRibbon", { { "HighlightColor", "accent", 1 }, { "EdgeColor", "main", 0.5 } } } }
local KIND = {} -- our MIDs by address -> MATCOL entry (later transforms only set numbers)

local PAL = {}
local P = {} -- the preload: keeper actor, held materials, decal MIDs, inactive Niagara components

function M.Setup(deps)
    D = deps
    local dir = debug.getinfo(1, "S").source:sub(2):match("^(.*[\\/])") or ""
    local ok, t = pcall(dofile, dir .. "suit_palettes.lua")
    PAL = (ok and type(t) == "table") and t or {}
    M.PalCount = 0
    for _ in pairs(PAL) do M.PalCount = M.PalCount + 1 end
end

-- ---------------------------------------------------------------- colours
local function Lin(c) -- sRGB 0-255 -> linear colour, brightest channel 1 (a glow needs the hue, not the shade)
    local r, g, b = (c[1] / 255) ^ 2.2, (c[2] / 255) ^ 2.2, (c[3] / 255) ^ 2.2
    local m = math.max(r, g, b)
    if m < 0.001 then return { R = 1, G = 1, B = 1, A = 1 } end
    return { R = r / m, G = g / m, B = b / m, A = 1 }
end
local function Mul(c, k) return { R = c.R * k, G = c.G * k, B = c.B * k, A = 1 } end
local NEUTRAL = { main = { 170, 230, 255 }, edge = { 120, 180, 255 }, accent = { 255, 255, 255 } }

local function Key(o)
    if not D.Valid(o) then return nil end
    local ok, n = pcall(function() return o:GetFName():ToString() end)
    if ok and n then return n end
    ok, n = pcall(function() return o:GetFullName() end)
    return ok and tostring(n):match("([%w_]+)$") or nil
end

-- the target outfit's palette: table by body mesh name (game outfits only, Saroj 2026-11-19), else neutral. nil = Match off.
function M.PaletteFor(mesh)
    if not M.Match then return nil end
    local id = Key(mesh) or "?"
    local p = PAL[id]
    if p then return { id = id, name = p.name, src = "table", main = Lin(p.main), edge = Lin(p.edge), accent = Lin(p.accent) } end
    return { id = id, name = id, src = "default", main = Lin(NEUTRAL.main), edge = Lin(NEUTRAL.edge), accent = Lin(NEUTRAL.accent) }
end

local function Txt(c) return string.format("%.2f,%.2f,%.2f", c.R, c.G, c.B) end

-- ---------------------------------------------------------------- preload (on foot, game thread, never in Init)
-- One step per call from ride_body.Hold. The keeper's mesh slots hold the masking master and the decal MIDs
-- (OverrideMaterials grow with SetMaterial); inactive Niagara components attached to it hold the systems.
local STEPS = { "keeper", "mask", "change", "outline", "depth", "ring", "flash", "parts", "burst", "boom", "spin", "ground", "force" }
local NFL, GS

function M.Ready() return P.done == true and D.Valid(P.keep) end

function M.Preload(S, pawn)
    if P.done and D.Valid(P.keep) then return end
    if P.keep ~= nil and not D.Valid(P.keep) then P = {} end -- a level change took the keeper: start again
    P.i = (P.i or 0) + 1
    P.t0 = P.t0 or os.clock()
    local step = STEPS[P.i]
    if step == "keeper" then
        P.keep = D.SpawnHidden(pawn)
        if not P.keep then P.i = 0 return end
        P.comp, P.mid, P.ns, P.slot, P.miss = P.keep.SkeletalMeshComponent, {}, {}, 0, 0
    elseif step == "mask" then
        P.mask = D.LoadObj(MASK)
        if D.Valid(P.mask) then P.comp:SetMaterial(P.slot, P.mask) P.slot = P.slot + 1 else P.miss = P.miss + 1 end
    elseif DECAL[step] then
        local m = D.LoadObj(DECAL[step])
        local mid = D.Valid(m) and P.comp:CreateDynamicMaterialInstance(P.slot, m, FName("None"))
        if D.Valid(mid) then P.mid[step] = mid P.slot = P.slot + 1 else P.miss = P.miss + 1 end
    elseif NS[step] then
        local sys = D.LoadObj(NS[step])
        NFL = NFL or StaticFindObject("/Script/Niagara.Default__NiagaraFunctionLibrary")
        local ok, c = false, nil
        if D.Valid(sys) then
            ok, c = pcall(function() -- auto destroy off, auto activate off: it only holds the system
                return NFL:SpawnSystemAttached(sys, P.comp, FName("None"), D.V(0, 0, 0), D.R(0, 0, 0), 0, false, false, 0, false)
            end)
        end
        if ok and D.Valid(c) then P.ns[step] = c else P.miss = P.miss + 1 end
    else
        P.done = true
        D.Rec(S, string.format("suit fx: preloaded %d of %d assets in %.0f ms (%d palettes)",
            #STEPS - 1 - P.miss, #STEPS - 1, (os.clock() - P.t0) * 1000, M.PalCount or 0))
    end
end

-- ---------------------------------------------------------------- outfit textures on the masking master
-- game param names vary (Basecolor, Base Color, Diffuse, Baked NormalMap, ORM ...): map them to the masking master's
local function Target(name)
    local n = name:lower():gsub("[%s_]", "")
    if n:find("pattern", 1, true) or n:find("detail", 1, true) then return nil end
    if n:find("basecolor", 1, true) or n:find("diffuse", 1, true) or n:find("albedo", 1, true) then return "BaseColor" end
    if n:find("normal", 1, true) then return "BaseNormal" end
    if n:find("orm", 1, true) then return "BaseORM" end
    if n:find("emiss", 1, true) then return "EmissiveMask" end
end

-- The masking master's textures for a material: its own first, then its parents' (an instance only overrides some)
local function Textures(mi)
    local out = {}
    for _ = 1, 8 do
        if not D.Valid(mi) then break end
        local ok, arr = pcall(function() return mi.TextureParameterValues end)
        if not ok or not arr then break end -- a base material: no instance arrays
        pcall(function() arr:ForEach(function(_, e)
            local v = e:get()
            local k = Target(v.ParameterInfo.Name:ToString())
            if k and out[k] == nil and D.Valid(v.ParameterValue) then out[k] = v.ParameterValue end
        end) end)
        local okP, p = pcall(function() return mi.Parent end)
        mi = okP and p or nil
    end
    return out
end

-- every slot of a component gets a masking MID dressed in that slot's old material's textures
local function Mask(comp, mats, master, dir, list)
    for i, src in ipairs(mats) do
        local mid = comp:CreateDynamicMaterialInstance(i - 1, master, FName("None"))
        if D.Valid(mid) then
            for k, t in pairs(Textures(src)) do mid:SetTextureParameterValue(FName(k), t) end
            mid:SetScalarParameterValue(FName("MaskDirection"), dir)
            mid:SetScalarParameterValue(FName("HeightMask"), M.H0)
            list[#list + 1] = mid
        end
    end
end

-- ---------------------------------------------------------------- effects: preloaded first, loaded as a fallback
local function Spawn(F, path, parent, sock)
    local sys = D.LoadObj(path)
    if not D.Valid(sys) then return nil end
    NFL = NFL or StaticFindObject("/Script/Niagara.Default__NiagaraFunctionLibrary")
    local ok, c = pcall(function()
        return NFL:SpawnSystemAttached(sys, parent, FName(sock or "None"), D.V(0, 0, 0), D.R(0, 0, 0), 0, false, true, 0, false)
    end)
    if ok and D.Valid(c) then F.ns[#F.ns + 1] = c return c end
end

local function Fx(F, name, parent, sock)
    local c = P.ns and P.ns[name]
    if c and D.Valid(c) then
        local ok = pcall(function()
            c:K2_AttachToComponent(parent, FName(sock or "None"), 2, 2, 2, false)
            c:Activate(true)
        end)
        if ok then F.pooled[#F.pooled + 1] = c F.fx[#F.fx + 1] = c return c end
    end
    c = Spawn(F, NS[name], parent, sock)
    if c then F.fx[#F.fx + 1] = c end
    return c
end

-- a decal on Eve with the preloaded MID (only numbers change), else a freshly loaded one
local function Decal(F, name, parent, sock, size, loc, rot, life)
    local mid = P.mid and P.mid[name]
    local mat = D.Valid(mid) and mid or D.LoadObj(DECAL[name])
    if not D.Valid(mat) then return nil end
    GS = GS or StaticFindObject("/Script/Engine.Default__GameplayStatics")
    local ok, dc = pcall(function()
        return GS:SpawnDecalAttached(mat, size, parent, FName(sock or "None"), loc, rot, 0, life)
    end)
    if not (ok and D.Valid(dc)) then return nil end
    F.decals[#F.decals + 1] = dc
    if not D.Valid(mid) then mid = dc:CreateDynamicMaterialInstance() end
    return dc, D.Valid(mid) and mid or nil
end

-- Probe (untested): colour one effect component. Show lightning: its own colour input. Sparks, shockwave, trail: a MID
-- of the slot's material with the palette (Niagara lists emitter materials once active). Counts go in F.
local function TintComp(F, c, an)
    F.found[an] = (F.found[an] or 0) + 1
    local u = SHOWSYS[an]
    if type(u) == "table" then
        c:SetVariableLinearColor(FName(u[1]), Mul(F.pal.main, u[2]))
        if u[1] == "User.CustomColor" then c:SetVariableBool(FName("User.UseCustomColor"), true) end
        F.user = F.user + 1
    end
    for i = 0, c:GetNumMaterials() - 1 do
        local m = c:GetMaterial(i)
        if D.Valid(m) then
            local mid, kind = m, KIND[m:GetAddress()] -- shortcut: a freed address reused by another MID could match; harmless
            if not kind then
                local k = Key(m) or "?"
                for _, e in ipairs(MATCOL) do if k:find(e[1], 1, true) then kind = e break end end
                if kind then
                    mid = c:CreateDynamicMaterialInstance(i, m, FName("None"))
                    if D.Valid(mid) then KIND[mid:GetAddress()] = kind end
                else
                    F.left[k] = true
                end
            end
            if kind and D.Valid(mid) then
                for _, p in ipairs(kind[2]) do mid:SetVectorParameterValue(FName(p[1]), Mul(F.pal[p[2]], p[3])) end
                F.mats = F.mats + 1
            end
        end
    end
end

local function Kids(parent, f)
    if not D.Valid(parent) then return end
    local kids = parent.AttachChildren
    for i = 1, kids:GetArrayNum() do
        local k = kids[i]
        if type(k) == "userdata" and k.get and not k.IsA then k = k:get() end
        if D.Valid(k) then f(k) end
    end
end

-- every tick of the coloured show: its new parts on her body or capsule (parts there before the show are skipped)
local function Scan(F, pawn)
    local function look(k)
        local a = k:GetAddress()
        if F.seen[a] then return end
        F.seen[a] = true
        local ok, asset = pcall(function() return k.Asset end)
        local an = ok and D.Valid(asset) and Key(asset) or nil
        if not (an and SHOWSYS[an]) then return end
        local okT, err = pcall(TintComp, F, k, an)
        if not okT and not F.err then F.err = tostring(err) end
    end
    pcall(Kids, pawn.Mesh, look)
    pcall(Kids, pawn.RootComponent, look)
end

-- ---------------------------------------------------------------- the two looks
local function Prologue(S, pawn, F)
    local master = D.Valid(P.mask) and P.mask or D.LoadObj(MASK)
    if not D.Valid(master) then return nil, "no MA_BodySuit_Masking" end
    local c, old = F.c, {}
    for i = 0, c:GetNumMaterials() - 1 do old[i + 1] = c:GetMaterial(i) end
    D.Rec(S, "suit fx: first call, prologue wipe") -- written before the calls: new in this game
    -- the outfit she leaves on a visible copy that copies her pose (from the riding puppet if it already drives her)
    local a = D.SpawnHidden(pawn)
    if not a then return nil, "copy not spawned" end
    F.copy = a
    local cc = a.SkeletalMeshComponent
    cc:SetSkeletalMesh(c.SkeletalMesh, true)
    a:K2_AttachToComponent(pawn.Mesh, FName("None"), 2, 2, 2, false)
    pcall(function() cc:SetComponentTickEnabled(true) end)
    local lead = pawn.Mesh
    if S.AdamCopy and D.Valid(S.Puppet) then
        lead = S.Puppet.SkeletalMeshComponent
        if S.CopyFollowers then table.insert(S.CopyFollowers, cc) F.follower = cc end
    end
    cc:SetMasterPoseComponent(lead, true)
    Mask(cc, old, master, 0, F.mids)
    F.wear(c, F.B) -- the new outfit's mesh, then masking MIDs over its real materials (they go back at the end)
    Mask(c, F.B.mats, master, 1, F.mids)
    a:SetActorHiddenInGame(false)
    -- scene: 70 x 70 x 85 box, rolled -90 so the band runs along her height; made a bit taller for standing Eve
    local _, dm = Decal(F, "change", pawn.Mesh, nil, D.V(70, 100, 100), D.V(0, 0, 95), D.R(0, 90, -90), M.Time + 1)
    F.decalMid = dm
    if dm then
        dm:SetScalarParameterValue(FName("OffsetY (S)"), 0) -- a preloaded MID keeps the last transform's value
        if F.pal then dm:SetVectorParameterValue(FName("Color"), Mul(F.pal.main, 5)) end
    end
    F.ring = Fx(F, "ring", pawn.Mesh)
    Fx(F, "flash", pawn.Mesh)
    Fx(F, "parts", pawn.Mesh)
    D.Rec(S, string.format("suit fx: prologue started, %d masking MIDs, HeightMask %.2f -> %.2f in %.1f s, decal %s",
        #F.mids, M.H0, M.H1, M.Time, dm and "on" or "missing"))
    return true
end

-- the show's keys point at our tinted decal MIDs and attach its two loose effects; Finish puts them back
local function ShowKeys(S, F)
    local d, a = 0, 0
    for name, kn in pairs(DKEY) do
        local k, mid = StaticFindObject(SHOW .. ":" .. kn), P.mid and P.mid[name]
        if D.Valid(k) and D.Valid(mid) then
            F.keys[#F.keys + 1] = { k, "DecalMaterial", k.DecalMaterial }
            mid:SetVectorParameterValue(FName("Color"), name == "outline" and Mul(F.pal.main, 5) or Mul(F.pal.edge, 2))
            k.DecalMaterial = mid
            d = d + 1
        end
    end
    for _, kn in ipairs(AKEY) do
        local k = StaticFindObject(SHOW .. ":" .. kn)
        if D.Valid(k) then
            F.keys[#F.keys + 1] = { k, "bAttach", k.bAttach }
            k.bAttach = true
            a = a + 1
        end
    end
    D.Rec(S, string.format("suit fx: show keys set, %d of 2 decals tinted, %d of 2 loose effects attached", d, a))
end

local function Tachy(S, pawn, F)
    F.swapAt, F.tEnd = M.TachySwap, M.TachySwap
    local lib, show = StaticFindObject("/Script/SB.Default__SBBlueprintLibrary"), D.LoadObj(SHOW)
    if D.Valid(lib) and D.Valid(show) then
        if F.pal then
            D.Rec(S, "suit fx: first call, show recoloured (key swap)") -- new in this game
            F.tEnd = M.ShowScan
            local function mark(k) F.seen[k:GetAddress()] = true end -- her parts from before the show
            pcall(Kids, pawn.Mesh, mark)
            pcall(Kids, pawn.RootComponent, mark)
            local okK, errK = pcall(ShowKeys, S, F)
            if not okK then D.Rec(S, "suit fx: show keys error " .. tostring(errK)) end
        end
        D.Rec(S, "suit fx: first call, PlaySBShowToPlayerCharacter(FX_TachyModeStartFX)") -- new in this game
        local ok, err = pcall(function() lib:PlaySBShowToPlayerCharacter(show) end)
        if ok then
            F.show = show -- held so the show asset is not collected while it plays
            if F.pal then Scan(F, pawn) end -- parts spawned inside the call
            return true
        end
        D.Rec(S, "suit fx: show error " .. tostring(err) .. ", spawning its particles")
    end
    -- the show's own two main effects
    F.tEnd = M.TachyTime
    Fx(F, "burst", pawn.Mesh, "FX_CenterofMass")
    Fx(F, "boom", pawn.Mesh)
    D.Rec(S, string.format("suit fx: tachy particles, %d spawned", #F.fx))
    return true
end

local function Finish(S, F, why)
    for i = #F.keys, 1, -1 do -- the show's keys back as the game had them
        local k = F.keys[i]
        if D.Valid(k[1]) then pcall(function() k[1][k[2]] = k[3] end) end
    end
    F.keys = {}
    if F.pal and (next(F.found) or F.err) then
        local t, l = {}, {}
        for n, c in pairs(F.found) do t[#t + 1] = n .. " x" .. c end
        for n in pairs(F.left) do l[#l + 1] = n end
        table.sort(t) table.sort(l)
        D.Rec(S, string.format("suit fx: recolour probe, parts %s; %d colour inputs, %d material MIDs set; left as they are: %s%s",
            table.concat(t, ", "), F.user, F.mats, #l > 0 and table.concat(l, ", ") or "none", F.err and (", first error " .. F.err) or ""))
        F.found, F.err = {}, nil
    end
    if F.copy and D.Valid(F.copy) then pcall(function() F.copy:K2_DestroyActor() end) end
    for _, c in ipairs(F.ns) do -- loaded at the start (no preload): destroyed
        if D.Valid(c) then pcall(function() c:Deactivate() end) pcall(function() c:K2_DestroyComponent(c) end) end
    end
    for _, c in ipairs(F.pooled) do -- preloaded: switched off and back on the keeper for the next transform
        if D.Valid(c) then
            pcall(function() c:Deactivate() end)
            if D.Valid(P.comp) then pcall(function() c:K2_AttachToComponent(P.comp, FName("None"), 2, 2, 2, false) end) end
        end
    end
    for _, d in ipairs(F.decals) do if D.Valid(d) then pcall(function() d:K2_DestroyComponent(d) end) end end
    if F.follower and S.CopyFollowers then
        for i = #S.CopyFollowers, 1, -1 do if S.CopyFollowers[i] == F.follower then table.remove(S.CopyFollowers, i) end end
    end
    if S.SuitFX == F then S.SuitFX = nil end
    if why then D.Rec(S, string.format("suit fx: %s %s after %.2f s", F.style, why, D.Now() - F.t0)) end
    if F.onEnd then pcall(F.onEnd) end
end

-- true = the transform swaps the outfit itself (now or soon); false = the caller swaps as before.
-- B = the outfit she turns into ({ mesh, mats }); off = the get-off transform back to her own outfit;
-- onEnd = called once when it is over (get off: frees the keeper holding her own outfit).
function M.Start(S, pawn, c, B, wear, onEnd, off)
    local style = M.Style
    if style == "off" then return false end
    if S.SuitFX then M.Stop(S) end -- a get on right after a get off (or back): the old one ends first
    if style == "cycle" then M.n = (M.n or 0) + 1 style = (M.n % 2 == 1) and "prologue" or "tachy" end
    local okP, pal = pcall(M.PaletteFor, B.mesh)
    pal = okP and pal or nil
    local function New(st)
        return { t0 = D.Now(), style = st, c = c, B = B, wear = wear, mids = {}, ns = {}, pooled = {}, fx = {}, decals = {},
            pal = pal, off = off, onEnd = onEnd, keys = {}, seen = {}, found = {}, left = {}, user = 0, mats = 0 }
    end
    D.Rec(S, string.format("suit fx: %s, %s, outfit %s (%s), palette %s%s", off and "get off" or "get on", style,
        pal and pal.id or "-", pal and tostring(pal.name) or "-", pal and pal.src or "game look",
        pal and string.format(": main %s edge %s accent %s", Txt(pal.main), Txt(pal.edge), Txt(pal.accent)) or "")
        .. (M.Ready() and ", preloaded" or ", not preloaded"))
    local F = New(style)
    if style == "prologue" then
        local ok, done, why = pcall(Prologue, S, pawn, F)
        if ok and done then S.SuitFX = F return true end
        D.Rec(S, "suit fx: prologue failed (" .. tostring(ok and why or done) .. "), using tachy")
        F.onEnd = nil
        Finish(S, F)
        F = New("tachy")
    end
    F.style = "tachy"
    local ok, err = pcall(Tachy, S, pawn, F)
    if not ok then D.Rec(S, "suit fx: tachy error " .. tostring(err)) F.onEnd = nil Finish(S, F) return false end
    S.SuitFX = F
    return true
end

-- SetSkeletalMesh(.., true) restarts her own animation: once the riding pose is hooked (mount step), a swap after it
-- left her standing and walking inside the bike (2026-11-19 ride). Hook her body and parts to the riding copy again.
-- Not at get off: the riding pose is already gone.
local function Wear(S, pawn, F)
    F.worn = true
    if not D.Valid(F.c) then return end -- level change: nothing left to dress
    F.wear(F.c, F.B)
    if not F.off and S.AdamCopy and D.Valid(S.Puppet) and D.Valid(pawn) then
        local n = D.Rehook(S, pawn)
        D.Rec(S, string.format("suit fx: riding pose hooked again after the swap (%d parts)", n or 0))
    end
end

-- every game tick while it runs
function M.Tick(S, pawn)
    local F = S.SuitFX
    if not F then return end
    local el = D.Now() - F.t0
    if F.pal and not F.tinted and el > 0 then -- our own effects (the wipe's, or the show's fallback particles)
        F.tinted = true
        for _, c in ipairs(F.fx) do
            if D.Valid(c) then
                local ok, err = pcall(function() TintComp(F, c, Key(c.Asset) or "?") end)
                if not ok and not F.err then F.err = tostring(err) end
            end
        end
    end
    if F.style == "tachy" then
        if F.show and F.pal then Scan(F, pawn) end
        if not F.worn and el >= F.swapAt then Wear(S, pawn, F) end
        if el >= F.tEnd then Finish(S, F, "swapped") end
        return
    end
    -- the old-outfit copy started on her body; once her body copies the riding puppet it must copy the puppet too
    if not F.off and not F.follower and F.copy and D.Valid(F.copy) and S.AdamCopy and D.Valid(S.Puppet) then
        local cc = F.copy.SkeletalMeshComponent
        pcall(function() cc:SetMasterPoseComponent(S.Puppet.SkeletalMeshComponent, true) end)
        if S.CopyFollowers then table.insert(S.CopyFollowers, cc) end
        F.follower = cc
    end
    local k = math.min(1, el / M.Time)
    local h = M.H0 + (M.H1 - M.H0) * k
    local g = k > 0.7 and math.sin((k - 0.7) / 0.3 * math.pi) * 4 or 0 -- the scene's glow as the suit settles
    local glow = F.em
    if g > 0 then -- one reused table, no garbage per frame
        local c = F.pal and F.pal.main or { R = 0.025, G = 1, B = 0.625 } -- no palette: the scene's cyan
        glow = glow or { A = 1 }
        glow.R, glow.G, glow.B = c.R * g, c.G * g, c.B * g
        F.em = glow
    end
    for _, m in ipairs(F.mids) do
        if D.Valid(m) then
            m:SetScalarParameterValue(FName("HeightMask"), h)
            if g > 0 then m:SetVectorParameterValue(FName("EmissiveColor"), glow) end
        end
    end
    if F.decalMid and D.Valid(F.decalMid) then F.decalMid:SetScalarParameterValue(FName("OffsetY (S)"), -1.375 * k) end
    if F.ring and D.Valid(F.ring) then pcall(function() F.ring:SetNiagaraVariableFloat("Scale", 2 * (1 - k)) end) end
    if k < 1 then return end
    Wear(S, pawn, F) -- the new outfit's real materials back
    Finish(S, F, "done")
end

-- Ctrl+H, level change, a new get on: drop whatever still runs. A get-on transform: her own outfit comes back by
-- the caller. A get-off transform: her own outfit goes on now (nothing else would put it back).
function M.Stop(S)
    local F = S.SuitFX
    if not F then return end
    if F.off and not F.worn then pcall(Wear, S, nil, F) end
    Finish(S, F, "stopped")
end

return M
