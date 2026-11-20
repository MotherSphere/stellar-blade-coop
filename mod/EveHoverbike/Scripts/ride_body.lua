-- Built-in riding outfit (2026-11-18): a bike can bring its own body mesh, with no CNS involved. It goes on under
-- the get-on black screen and her own body and materials come back at get off. Dev build: Fusion Rider is a recolour
-- of the Night Rider mod (Nexus 2479): for SBO devs to test, not for a public release without its author's permission.
local M = {}
local D, S_ride

local DIR = "/Game/Mods/EveBikes/Quantum/FusionRider/"
M.Bodies = {
    fusion = { Name = "Fusion Rider", Mesh = DIR .. "FusionRider.FusionRider", Materials = { -- mesh slot order
        DIR .. "missberave_skin/misberave_skin.misberave_skin", DIR .. "PartB.PartB",
        DIR .. "missberave_skin/NellSkin.NellSkin", DIR .. "PartA.PartA" },
        -- wings (2026-11-19): the Fusion suit's waist, triceps and head wings cut from the game's CH_P_EVE_Fusion, on
        -- Eve's skeleton, using the game's own Suit02 / Suit04 materials. Their wing bones are not in her body, so the
        -- engine keeps them at their rest pose off the parent bone (spine, upper arm, head).
        Wings = DIR .. "FusionWings.FusionWings",
        Skin = { 1, 3 } }, -- the Materials that are her skin (SkinTone below)
}

local FX -- suit_fx.lua: the get-on suit transform (2026-11-19)

-- Skin tone (2026-11-19): the Skin Tone Editor plugin tones her face and her own outfits through dynamic material
-- copies, but it never sees a body this mod swaps in, so the suit's skin stayed darker than her face. The face's
-- colour and brightness values are copied onto the suit's skin slots; its gloss values are left out.
local function FullName(o)
    local ok, n = pcall(function() return o:GetFullName() end)
    return ok and tostring(n) or "?"
end
local function Params(m, field)
    local out = {}
    pcall(function() m[field]:ForEach(function(_, e)
        local v = e:get()
        out[#out + 1] = { v.ParameterInfo.Name:ToString(), v.ParameterValue }
    end) end)
    return out
end
local function FaceSkin(c)
    local seen = {}
    local kids = c.AttachChildren
    for i = 1, kids:GetArrayNum() do
        local found, first
        pcall(function()
            local k = kids[i]
            if type(k) == "userdata" and k.get and not k.IsA then k = k:get() end
            local mesh = D.Valid(k) and k.SkeletalMesh
            local mn = D.Valid(mesh) and FullName(mesh):lower() or ""
            if not (mn:find("face", 1, true) or mn:find("head", 1, true)) then return end
            for j = 0, k:GetNumMaterials() - 1 do
                local m = k:GetMaterial(j)
                if D.Valid(m) then
                    -- the game's face skin is a run-time copy with no name of its own (MaterialInstanceDynamic_N,
                    -- 2026-11-19 log): its parents carry the name
                    local n, p = FullName(m):match("([%w_]+)$") or "?", m
                    for _ = 1, 4 do
                        local ok, up = pcall(function() return p.Parent end)
                        if not (ok and D.Valid(up)) then break end
                        p = up
                        n = n .. " < " .. (FullName(p):match("([%w_]+)$") or "?")
                    end
                    seen[#seen + 1] = n
                    if #Params(m, "VectorParameterValues") > 0 then
                        local low = n:lower()
                        if not found and (low:find("skin", 1, true) or low:find("face", 1, true)) then found = m end
                        first = first or m
                    end
                end
            end
        end)
        found = found or first -- no skin / face name anywhere: the first toned material of the face mesh
        if found then return found, seen end
    end
    return nil, seen
end
local function SkinTone(c, B)
    if not B.skin then return nil end
    local face, seen = FaceSkin(c)
    if not face then return "skin tone: no toned face skin found, suit skin left as it is (face materials: " .. table.concat(seen, ", ") .. ")" end
    local vec, sca, slots, names = Params(face, "VectorParameterValues"), Params(face, "ScalarParameterValues"), 0, {}
    for _, slot in ipairs(B.skin) do
        local mid = c:CreateDynamicMaterialInstance(slot - 1, B.mats[slot], FName("None"))
        if D.Valid(mid) then
            slots = slots + 1
            for _, p in ipairs(vec) do
                local v = p[2]
                mid:SetVectorParameterValue(FName(p[1]), { R = v.R, G = v.G, B = v.B, A = v.A })
                if slots == 1 then names[#names + 1] = p[1] end
            end
            for _, p in ipairs(sca) do
                local n = p[1]:lower()
                if not (n:find("rough", 1, true) or n:find("specular", 1, true) or n:find("gloss", 1, true) or n:find("fresnel", 1, true)) then
                    mid:SetScalarParameterValue(FName(p[1]), p[2])
                    if slots == 1 then names[#names + 1] = p[1] end
                end
            end
        end
    end
    return string.format("skin tone: face values copied onto %d skin slot(s): %s (face materials: %s)", slots,
        table.concat(names, ", "), table.concat(seen, ", "))
end

local function Wear(c, B)
    c:SetSkeletalMesh(B.mesh, true)
    for i, m in ipairs(B.mats) do c:SetMaterial(i - 1, m) end
    local ok, line = pcall(SkinTone, c, B)
    if not ok then line = "skin tone: error " .. tostring(line) end
    if line and line ~= B.toneSaid then -- once per ride unless it changes
        B.toneSaid = line
        D.Rec(B.S, line)
    end
end

local function LoadBody(def)
    local mesh, mats = D.LoadObj(def.Mesh), {}
    for i, p in ipairs(def.Materials) do mats[i] = D.LoadObj(p) end
    if D.Valid(mesh) and #mats == #def.Materials then return mesh, mats end
    return nil
end

local function SpawnHidden(pawn)
    local p = pawn:K2_GetActorLocation()
    local a = pawn:GetWorld():SpawnActor(StaticFindObject("/Script/Engine.SkeletalMeshActor"), D.V(p.X, p.Y, p.Z), D.R(0, 0, 0))
    if not D.Valid(a) then return nil end
    pcall(function() a:SetActorHiddenInGame(true) end)
    pcall(function() a:SetActorEnableCollision(false, false) end)
    pcall(function() a.SkeletalMeshComponent:SetComponentTickEnabled(false) end) -- nobody sees it, nothing to animate
    return a
end

function M.Setup(deps)
    D = deps
    local dir = debug.getinfo(1, "S").source:sub(2):match("^(.*[\\/])") or ""
    local ok, fx = pcall(dofile, dir .. "suit_fx.lua")
    if ok and type(fx) == "table" then
        FX, M.FX = fx, fx
        FX.Setup(setmetatable({ SpawnHidden = SpawnHidden }, { __index = deps }))
    end
end

-- logic.lua calls this every frame while a transform runs
function M.FxTick(S, pawn) if FX then FX.Tick(S, pawn) end end

-- A hidden actor wearing her own body and materials: nothing else may hold them while the outfit is on, and the
-- garbage collector would free them (game materials made at run time cannot be loaded again by path).
local function SpawnKeeper(pawn, c)
    local a = SpawnHidden(pawn)
    if not a then return nil end
    local kc = a.SkeletalMeshComponent
    kc:SetSkeletalMesh(c.SkeletalMesh, false)
    local n = c:GetNumMaterials()
    for i = 0, n - 1 do kc:SetMaterial(i, c:GetMaterial(i)) end
    return a, n
end

local function DropKeeper(B)
    for _, a in ipairs({ B.keeper, B.wings }) do
        if D.Valid(a) then pcall(function() a:K2_DestroyActor() end) end
    end
end

local function LoadWings(def)
    local w = def.Wings
    local m = w and D.LoadObj(w)
    return D.Valid(m) and m or nil
end

-- Visible, snapped to her body, copying the pose that drives her body (the riding copy, if it already runs)
local function WearWings(S, pawn, mesh)
    local a = SpawnHidden(pawn)
    if not a then return nil end
    local c = a.SkeletalMeshComponent
    c:SetSkeletalMesh(mesh, true)
    a:K2_AttachToComponent(pawn.Mesh, FName("None"), 2, 2, 2, false)
    pcall(function() c:SetComponentTickEnabled(true) end)
    local lead = pawn.Mesh
    if S.AdamCopy and D.Valid(S.Puppet) then
        lead = S.Puppet.SkeletalMeshComponent
        if S.CopyFollowers then table.insert(S.CopyFollowers, c) end
    end
    c:SetMasterPoseComponent(lead, true)
    a:SetActorHiddenInGame(false)
    return a
end

-- Extra parts for logic.lua's outfit part list, so every rehook, photo and drone step treats the wings like her own
function M.Extras(pawn)
    local B = S_ride
    if B and D.Valid(B.wings) and D.Valid(pawn) and pawn:GetAddress() == B.pawn then return { B.wings.SkeletalMeshComponent } end
    return {}
end

-- On foot, game thread only (never from Init): the picked bike's outfit waits in memory on a hidden actor, so the
-- get on only swaps the body. Picking a bike without an outfit frees it again.
function M.Hold(S, pawn, bike)
    local H, def = S.RideHold, M.Bodies[bike]
    if H and H.bike ~= bike then
        DropKeeper(H)
        S.RideHold, H = nil, nil
    end
    if def and FX and H and D.Valid(H.keeper) and not FX.Ready() then -- suit-up effects next, one step per tick
        FX.Preload(S, pawn)
        return
    end
    if not def or (H and D.Valid(H.keeper)) then return end
    if H then DropKeeper(H) end -- a level change took the body keeper, the wings keeper goes too
    if S.RideHoldT and D.Now() - S.RideHoldT < 5 then return end
    S.RideHoldT = D.Now()
    local t0 = os.clock()
    local mesh, mats = LoadBody(def)
    if not mesh then
        if not S.RideHoldMissing then
            S.RideHoldMissing = true
            D.Rec(S, "ride body: preload found no " .. def.Name .. " (is EveBike_FusionRider_P in ~mods?)")
        end
        return
    end
    local wm, wa = LoadWings(def), nil
    if wm then
        wa = SpawnHidden(pawn)
        if wa then wa.SkeletalMeshComponent:SetSkeletalMesh(wm, false) end
    end
    local a = SpawnHidden(pawn)
    if not a then return end
    local kc = a.SkeletalMeshComponent
    kc:SetSkeletalMesh(mesh, false)
    for i, m in ipairs(mats) do kc:SetMaterial(i - 1, m) end
    S.RideHold = { bike = bike, keeper = a, wings = wa }
    D.Rec(S, string.format("ride body: %s preloaded in %.0f ms", def.Name, (os.clock() - t0) * 1000))
end

-- true = this bike has its own outfit, so the CNS riding outfit is skipped (even if the pak is missing)
function M.On(S, pawn, bike)
    local def = M.Bodies[bike]
    if not def then return false end
    local addr = pawn:GetAddress()
    if S.RideBody then
        if S.RideBody.pawn == addr then return true end
        DropKeeper(S.RideBody) -- left over from a pawn of another level
        S.RideBody = nil
    end
    local t0 = os.clock()
    local mesh, mats = LoadBody(def)
    if not mesh then
        D.Rec(S, "ride body: " .. def.Name .. " not found (is EveBike_FusionRider_P in ~mods?), riding in her own outfit")
        return true
    end
    local c = pawn.Mesh
    D.Rec(S, "ride body: first call, putting on " .. def.Name) -- written before the calls: new in this game
    local keeper, n = SpawnKeeper(pawn, c)
    if not keeper then
        D.Rec(S, "ride body: keeper not spawned, riding in her own outfit")
        return true
    end
    local B = { pawn = addr, keeper = keeper, n = n, mesh = mesh, meshAddr = mesh:GetAddress(), mats = mats, name = def.Name,
        skin = def.Skin, S = S }
    S.RideBody, S_ride = B, B
    local okF, took = pcall(function() return FX and FX.Start(S, pawn, c, B, Wear) end)
    if not okF then D.Rec(S, "suit fx error: " .. tostring(took)) end
    if not (okF and took) then Wear(c, B) end
    local wm = LoadWings(def)
    if wm then
        D.Rec(S, "ride body: first call, wings on") -- written before the calls: new in this game
        local ok, a = pcall(WearWings, S, pawn, wm)
        if ok then B.wings = a else D.Rec(S, "ride body: wings error " .. tostring(a)) end
    end
    D.Rec(S, string.format("ride body: %s on in %.0f ms, %d of her own materials kept", def.Name, (os.clock() - t0) * 1000, n))
    return true
end

local function WearOwn(c, own)
    c:SetSkeletalMesh(own.mesh, true)
    for i, m in ipairs(own.mats) do
        if D.Valid(m) then c:SetMaterial(i - 1, m) end
    end
end

-- anim = the normal get off: the suit transform runs backwards in her own outfit's colours (2026-11-19). The
-- keeper holding her own materials stays until it is over. Ctrl+H, level change, spawn fail: at once, as before.
function M.Off(S, pawn, anim)
    if FX then pcall(FX.Stop, S) end
    local B = S.RideBody
    if not B then return end
    S.RideBody, S_ride = nil, nil
    if D.Valid(pawn) and pawn:GetAddress() == B.pawn and D.Valid(B.keeper) then
        local kc, c = B.keeper.SkeletalMeshComponent, pawn.Mesh
        local own = { mesh = kc.SkeletalMesh, mats = {} }
        for i = 0, B.n - 1 do own.mats[i + 1] = kc:GetMaterial(i) end
        local ok, took = false, false
        if anim and FX then ok, took = pcall(FX.Start, S, pawn, c, own, WearOwn, function() DropKeeper(B) end, true) end
        if not ok and took then D.Rec(S, "suit fx error at get off: " .. tostring(took)) end
        if ok and took then
            D.Rec(S, "ride body: " .. B.name .. " off by the suit transform")
            return
        end
        WearOwn(c, own)
        D.Rec(S, "ride body: " .. B.name .. " off, her own body is back")
    end
    DropKeeper(B)
end

-- While riding: an outfit change from anywhere is undone, at most once a second
function M.Tick(S, pawn)
    local B = S.RideBody
    if not B or S.SuitFX or pawn:GetAddress() ~= B.pawn then return end -- a running transform swaps the outfit itself
    local cur = pawn.Mesh.SkeletalMesh
    if D.Valid(cur) and cur:GetAddress() == B.meshAddr then return end
    if B.fixT and D.Now() - B.fixT < 1 then return end
    B.fixT = D.Now()
    Wear(pawn.Mesh, B)
    D.Rehook(S, pawn)
    D.Rec(S, "ride body: body changed while riding, " .. B.name .. " put back")
end

return M
