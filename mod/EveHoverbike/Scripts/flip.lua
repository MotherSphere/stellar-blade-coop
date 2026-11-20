-- Run-up and somersault get-on (2026-11-17).
--
-- Bike key: the bike starts behind Eve and rolls on without stopping. Her animation (made in the bike's
-- space, Batcycle\blender\make_flip_mount.py) shows her jogging ahead of it, looking back, jumping and
-- landing on the seat. A cutscene camera opens on her front, which hides the jump to the riding copy.
-- flip_track.lua holds the camera and the bike's speed for every animation frame.
--
-- Where this can't work (wall, drop, no animation in the pak) Plan says no and the old get-on runs.
-- Every way out goes through F.Stop, which gives the player's view back.
local F = {}
local E, T = nil, nil

local CAMERA_CLASS = "/Script/Engine.CameraActor"
local SNAP, KEEP_WORLD = 2, 1          -- EAttachmentRule
local EASE_IN_OUT = 4                  -- EViewTargetBlendFunction
local BOUNDS_SCALE = 12                -- she is metres from the bike's origin: never culled on screen
local GROUND_STEP, STEP_DIFF = 200, 90 -- the road is checked every 2 m; a bigger step than this stops the bike
local CLEAR_HEIGHTS = { 70, 140 }      -- above the ground under the road: low rocks don't count, the bike rides over them
local HEADINGS = { 0, 30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180 } -- the cutscene cut hides her turning
local SEAT_FRAME = 145                 -- animation frame where she lands on the seat (F_LAND in make_flip_mount.py, after its slow motion)
local KSL = nil

function F.Setup(env)
    E = env
    local chunk, err = loadfile(env.Dir .. "flip_track.lua")
    local ok, t = false, err
    if chunk then ok, t = pcall(chunk) end
    T = (ok and type(t) == "table" and t.rows and #t.rows == t.frames) and t or nil
    return T ~= nil, t
end

local function No(S, why)
    E.Rec(S, "flip: not here (" .. why .. "), the old get-on")
    return false
end

-- A line trace that also says what it hit. The hidden preload bike is never in the way.
local function Cast(S, pawn, a, b)
    if not E.Valid(KSL) then KSL = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary") end
    local hit, color = {}, { R = 0, G = 0, B = 0, A = 0 }
    local ok, was = pcall(function() return KSL:LineTraceSingle(pawn, a, b, 0, false, {}, 0, hit, true, color, color, 0.0) end)
    if not ok or not was then return nil end
    local p = hit.ImpactPoint or hit.Location
    if not p then return nil end
    local name, mine = "something", false
    pcall(function()
        local actor = hit.Actor:Get()
        name = actor:GetFName():ToString()
        for _, k in ipairs((S.Keeper and S.Keeper.actors) or {}) do
            if E.Valid(k) and k:GetAddress() == actor:GetAddress() then mine = true end
        end
        for _, k in ipairs(S.BatActors or {}) do -- the bike she is riding (the get-off looks from the seat)
            if E.Valid(k) and k:GetAddress() == actor:GetAddress() then mine = true end
        end
    end)
    if mine then return nil end
    return E.V(p.X, p.Y, p.Z), name
end

-- Walks the ground from Eve one way, following its height. Returns the last ground height, or nil and why.
local function Walk(S, pawn, p, feet, fx, fy, length, label)
    local z, px, py = feet, p.X, p.Y
    local d = 0
    while d < length do
        d = math.min(d + GROUND_STEP, length)
        local x, y = p.X + fx * d, p.Y + fy * d
        local g = Cast(S, pawn, E.V(x, y, z + 200), E.V(x, y, z - 250))
        if not g or math.abs(g.Z - z) > STEP_DIFF then
            return nil, string.format("no road %.0f m %s", d / 100, label)
        end
        for _, h in ipairs(CLEAR_HEIGHTS) do
            local _, name = Cast(S, pawn, E.V(px, py, z + h), E.V(x, y, g.Z + h))
            if name then return nil, string.format("%s %.0f m %s", name, d / 100, label) end
        end
        z, px, py = g.Z, x, y
    end
    return z
end
F.Cast, F.Walk = Cast, Walk -- flip_off.lua checks its road the same way

-- The whole road along one heading: where the bike starts and where it is when she has landed.
local function Road(S, pawn, p, feet, yaw)
    local fx, fy = math.cos(math.rad(yaw)), math.sin(math.rad(yaw))
    local startZ, why = Walk(S, pawn, p, feet, -fx, -fy, T.gap, "behind")
    if not startZ then return nil, why end
    local endZ, why2 = Walk(S, pawn, p, feet, fx, fy, T.travel - T.gap, "ahead")
    if not endZ then return nil, why2 end
    return { x = p.X - fx * T.gap, y = p.Y - fy * T.gap, z = startZ, yaw = yaw }
end

-- Decides at the key press, before anything changes.
function F.Plan(S, pawn)
    local C = E.Config
    S.FlipPlan = nil
    if C.FlipOn == false or not C.GetOnFlip or C.BlackSwitch == true then return false end
    if not T then return No(S, "flip_track.lua not loaded") end
    if not E.LoadAnim(S, C.GetOnFlip) then return No(S, "animation not in the pak") end
    local falling = false
    pcall(function() falling = pawn.CharacterMovement:IsFalling() == true end)
    if falling then return No(S, "she is in the air") end
    local p, yaw = pawn:K2_GetActorLocation(), pawn:K2_GetActorRotation().Yaw
    local feet = p.Z - E.HalfHeight(pawn)
    local refused = {}
    for _, turn in ipairs(HEADINGS) do
        local plan, why = Road(S, pawn, p, feet, yaw + turn)
        if plan then
            S.FlipPlan = plan
            if turn ~= 0 then
                E.Rec(S, string.format("flip: road turned %d deg (straight on: %s)", turn, tostring(refused[1])))
            end
            if E.CampShow then pcall(E.CampShow, S, false) end -- the parked bike gives way to the rolling one
            return true
        end
        refused[#refused + 1] = why
    end
    return No(S, "no clear road any way: " .. table.concat(refused, "; ", 1, math.min(#refused, 4)))
end

-- Just before she is put on the bike: the bike's start point, behind where she stands.
function F.Seat(S, pawn)
    local P = S.FlipPlan
    if not P then return end
    pawn:K2_SetActorLocationAndRotation(E.V(P.x, P.y, P.z + E.HalfHeight(pawn) + 2), E.R(0, P.yaw, 0), false, {}, true)
end

local function Row(g)
    local i = math.max(math.min(math.floor(g), T.frames - 1), 1)
    local a, b, w = T.rows[i], T.rows[i + 1], g - i
    local function mix(n) return a[n] + (b[n] - a[n]) * w end
    local dyaw = ((b[4] - a[4] + 180) % 360) - 180
    return mix(1), mix(2), mix(3), a[4] + dyaw * w, mix(5), mix(6)
end

local function Place(f, g)
    if not E.Valid(f.cam) then return end
    local x, y, z, yaw, pitch = Row(g)
    f.cam:K2_SetActorRelativeLocation(E.V(x, y, z + f.zoff), false, {}, true)
    f.cam:K2_SetActorRelativeRotation(E.R(pitch, yaw, 0), false, {}, true)
end

-- She is on the bike and on the animation's first frame.
function F.Begin(S, pawn)
    local f = { bounds = {}, zoff = -E.HalfHeight(pawn), fr = 0, retargets = 0 }
    S.Flip = f
    pcall(function() f.zoff = pawn.Mesh.RelativeLocation.Z end)
    local meshes = { pawn.Mesh }
    if E.Valid(S.Puppet) then meshes[2] = S.Puppet.SkeletalMeshComponent end
    for _, c in ipairs(meshes) do
        pcall(function()
            local was = c.BoundsScale
            c:SetBoundsScale(BOUNDS_SCALE)
            f.bounds[#f.bounds + 1] = { c = c, was = type(was) == "number" and was or 1 }
        end)
    end
    local ok, err = pcall(function()
        local p = pawn:K2_GetActorLocation()
        local cam = pawn:GetWorld():SpawnActor(StaticFindObject(CAMERA_CLASS), p, E.R(0, 0, 0))
        f.cam = cam
        cam.CameraComponent:SetFieldOfView(T.fov)
        cam.CameraComponent.bConstrainAspectRatio = false
        cam:K2_AttachToActor(pawn, FName("None"), SNAP, SNAP, KEEP_WORLD, false)
        Place(f, 1)
        E.GetPC(S):SetViewTargetWithBlend(cam, 0.0, 0, 0.0, false)
    end)
    if not ok then E.Rec(S, "flip: camera failed, the game camera stays: " .. tostring(err)) end
    local hd = E.Hd()
    if hd and hd.SoundNow then pcall(hd.SoundNow, S) end -- the bike is already rolling
end

-- The first frame was held until the game ran smoothly: now it all moves.
function F.Go(S)
    local f = S.Flip
    if not f then return end
    f.t0 = E.Now()
    E.Rec(S, string.format("flip: plays (%.2f s, bike %.1f m/s)", (T.frames - 1) / T.fps, T.bike / 100))
end

local function ViewIsCamera(pc, cam)
    local v = pc:GetViewTarget()
    return E.Valid(v) and v:GetAddress() == cam:GetAddress()
end

-- Every frame, before the ride's own frame.
function F.Frame(S, pc, pawn)
    local f = S.Flip
    if not f or not f.t0 then return end
    local el = E.Now() - f.t0
    local g = math.min(el * T.fps + 1, T.frames)
    f.g = g
    local hd = E.Hd()
    if not f.grunted and g >= SEAT_FRAME then
        f.grunted = true
        if hd and hd.GruntNow then pcall(hd.GruntNow, S, pawn, 1, "get-on: on the seat") end
    end
    if S.Anim and S.Anim.flip and hd and hd.Script then
        local _, _, _, _, _, rate = Row(g)
        hd.Script(S, T.bike * rate)
    end
    if not f.back then
        if g >= T.back then
            f.back = true
            pc:SetViewTargetWithBlend(pawn, T.blend, EASE_IN_OUT, 2.0, false)
        elseif E.Valid(f.cam) then
            Place(f, g)
            f.fr = f.fr + 1
            if f.fr % 30 == 0 and not ViewIsCamera(pc, f.cam) then
                f.retargets = f.retargets + 1
                if f.retargets == 1 then E.Rec(S, "flip: the game took the view back, setting the camera again") end
                if f.retargets <= 5 then pc:SetViewTargetWithBlend(f.cam, 0.0, 0, 0.0, false) end
            end
        end
    end
    if g >= T.frames and el >= (T.frames - 1) / T.fps + 0.1 and not S.Anim then F.Stop(S, "finished") end
end

function F.Stop(S, why)
    local f = S.Flip
    S.Flip, S.FlipPlan = nil, nil
    if not f then return end
    local hd = E.Hd()
    if hd and hd.Script then pcall(hd.Script, S, nil) end
    if not f.back then
        pcall(function()
            local pc = E.GetPC(S)
            local pawn = pc.Pawn
            if E.Valid(pawn) then pc:SetViewTargetWithBlend(pawn, 0.0, 0, 0.0, false) end
        end)
    end
    if E.Valid(f.cam) then pcall(function() f.cam:K2_DestroyActor() end) end
    for _, b in ipairs(f.bounds) do
        if E.Valid(b.c) then pcall(function() b.c:SetBoundsScale(b.was) end) end
    end
    E.Rec(S, why == "finished" and string.format("flip: finished (view reset %d time(s))", f.retargets)
        or ("flip: stopped (" .. tostring(why) .. ")"))
end

return F
