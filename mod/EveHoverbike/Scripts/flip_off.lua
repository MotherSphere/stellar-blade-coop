-- Squat and backflip get-off (2026-11-17).
--
-- Bike key while riding, at any speed: Eve hops up to a squat on the seat, jumps off in a backward somersault and
-- lands on the road (the game's Eve_Landing_Stiff) while the bike rides on by itself and despawns out of shot.
-- The animation is made in the ground's space (Batcycle\blender\make_flip_dismount.py), so her capsule stands
-- still, and a free bike follows flip_off_track.lua, which also holds the camera for every animation frame.
--
-- Where this can't work (no room, no animation in the pak) Plan says no and the old get-off runs.
-- Every way out goes through O.Stop, which gives the player's view and the riding bike back.
local O = {}
local E, T = nil, nil

local CAMERA_CLASS = "/Script/Engine.CameraActor"
local SNAP, KEEP_WORLD = 2, 1          -- EAttachmentRule
local EASE_IN_OUT = 4                  -- EViewTargetBlendFunction
local BOUNDS_SCALE = 12                -- she is metres from her capsule: never culled on screen
local HOLD = 0.25                      -- seconds on the first frame, while the free bike's hitch passes
local LEVEL_DIFF = 30                  -- the road under the seat phase and the landing must be this level (cm)
local LEVEL_AT = { 100, 200, 300 }
local ROAD = 700                       -- the free bike needs this much clear road (cm)
local HEADROOM = 420                   -- she flies this high above the ground (cm)
local CAMERA_ROWS = { 1, 40, 80, 110 } -- animation frames where the camera must see her
local HEADINGS = { 0, 30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180 } -- the cut to the camera hides the turn
local LAND_FRAME = 74                  -- animation frame where her feet hit the road (F_LAND in make_flip_dismount.py)

function O.Setup(env)
    E = env
    local chunk, err = loadfile(env.Dir .. "flip_off_track.lua")
    local ok, t = false, err
    if chunk then ok, t = pcall(chunk) end
    T = (ok and type(t) == "table" and t.rows and #t.rows == t.frames) and t or nil
    return T ~= nil, t
end

local function No(S, why)
    E.Rec(S, "flip off: not here (" .. why .. "), the old get-off")
    return false
end

local function Road(S, pawn, p, feet, yaw)
    local F = E.Flip
    local fx, fy = math.cos(math.rad(yaw)), math.sin(math.rad(yaw))
    for _, d in ipairs(LEVEL_AT) do
        local x, y = p.X + fx * d, p.Y + fy * d
        local g = F.Cast(S, pawn, E.V(x, y, feet + 150), E.V(x, y, feet - 150))
        if not g or math.abs(g.Z - feet) > LEVEL_DIFF then return nil, string.format("road not level %.0f m ahead", d / 100) end
    end
    local z, why = F.Walk(S, pawn, p, feet, fx, fy, ROAD, "ahead")
    if not z then return nil, why end
    for _, d in ipairs({ T.land, LEVEL_AT[3] }) do
        local x, y = p.X + fx * d, p.Y + fy * d
        local _, name = F.Cast(S, pawn, E.V(x, y, feet + 150), E.V(x, y, feet + HEADROOM))
        if name then return nil, name .. " overhead" end
    end
    local tx, ty = p.X + fx * T.land, p.Y + fy * T.land
    for _, i in ipairs(CAMERA_ROWS) do
        local r = T.rows[i]
        local cam = E.V(p.X + fx * r[1] - fy * r[2], p.Y + fy * r[1] + fx * r[2], feet + r[3])
        local _, name = F.Cast(S, pawn, E.V(tx, ty, feet + 100), cam)
        if name then return nil, name .. " in front of the camera" end
    end
    return { x = p.X, y = p.Y, z = feet, yaw = yaw }
end

-- Decides at the key press, before anything changes.
function O.Plan(S, pawn)
    local C = E.Config
    S.FlipOffPlan = nil
    if C.FlipOn == false or not C.GetOffFlip or C.BlackSwitch == true then return false end
    if not T then return No(S, "flip_off_track.lua not loaded") end
    if not E.Flip then return No(S, "flip.lua not loaded") end
    if not S.BatActors or #S.BatActors == 0 then return No(S, "no bike to swap") end
    local falling = false
    pcall(function() falling = pawn.CharacterMovement:IsFalling() == true end)
    if falling then return No(S, "she is in the air") end
    if not E.LoadAnim(S, C.GetOffFlip) then return No(S, "animation not in the pak") end
    local p, yaw = pawn:K2_GetActorLocation(), (S.Hd and S.Hd.heading) or pawn:K2_GetActorRotation().Yaw
    local feet = p.Z - E.HalfHeight(pawn)
    local refused = {}
    for _, turn in ipairs(HEADINGS) do
        local plan, why = Road(S, pawn, p, feet, yaw + turn)
        if plan then
            S.FlipOffPlan = plan
            if turn ~= 0 then
                E.Rec(S, string.format("flip off: road turned %d deg (straight on: %s)", turn, tostring(refused[1])))
            end
            return true
        end
        refused[#refused + 1] = why
    end
    return No(S, "no clear road any way: " .. table.concat(refused, "; ", 1, math.min(#refused, 4)))
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

-- Her capsule stays on the free bike's spot. At speed the game kept sliding her on (77 to 126 cm at 20 to 31 m/s,
-- rides of 2026-11-18), which left the bike behind and had her flip off an invisible one.
local function Hold(f, pawn)
    pcall(function()
        local cmc = pawn.CharacterMovement
        cmc.Velocity = { X = 0, Y = 0, Z = cmc.Velocity.Z }
    end)
    local p = pawn:K2_GetActorLocation()
    local off = math.sqrt((p.X - f.x) ^ 2 + (p.Y - f.y) ^ 2)
    if off > 1 then
        f.pulls, f.worst = f.pulls + 1, math.max(f.worst, off)
        pawn:K2_SetActorLocationAndRotation(E.V(f.x, f.y, p.Z), E.R(0, f.yaw, 0), false, {}, true)
    end
end

-- The first frame of the animation is the riding pose, so nothing shows until the camera cuts.
function O.Begin(S, pawn)
    local P = S.FlipOffPlan
    if not P then return false end
    local anim = E.LoadAnim(S, E.Config.GetOffFlip)
    if not anim then return false end
    local B = E.Build(S, pawn, nil)
    if not B then return No(S, "free bike not built") end
    local len = E.Play(S, anim, "get-off")
    if not len then
        E.Destroy(B)
        return No(S, "animation did not start")
    end
    local comp = S.Puppet.SkeletalMeshComponent
    comp:SetPosition(0.0, false)
    comp:Stop()
    local f = { bounds = {}, zoff = -E.HalfHeight(pawn), fr = 0, retargets = 0, yaw = P.yaw, x = P.x, y = P.y, feet = P.z,
        fx = math.cos(math.rad(P.yaw)), fy = math.sin(math.rad(P.yaw)), born = E.Now(), g = 1, dist = 0, pulls = 0, worst = 0 }
    S.FlipOff = f
    S.Anim = { kind = "off", flipoff = true, held = true, len = len, anim = anim, t0 = E.Now(), pre = true }
    pcall(function() f.zoff = pawn.Mesh.RelativeLocation.Z end)
    local hd = E.Hd()
    if hd then
        pcall(hd.Lock, S, true)
        pcall(hd.Script, S, 0)
        pcall(hd.ScriptYaw, S, P.yaw)
        pcall(hd.SoundOff, S)
    end
    pcall(function() pawn.CharacterMovement:StopMovementImmediately() end)
    pawn:K2_SetActorLocationAndRotation(E.V(P.x, P.y, P.z + E.HalfHeight(pawn) + 2), E.R(0, P.yaw, 0), false, {}, true)
    Hold(f, pawn)
    S.Auto = { kind = "flipoff", B = B, x = P.x, y = P.y, z = P.z, zT = P.z, yaw = P.yaw, v = T.seat, t = E.Now(), last = E.Now(), fr = 0 }
    E.AutoPlace(S.Auto, 0)
    E.Show(B, true)
    E.Show({ actors = S.BatActors }, false)
    if hd and hd.LampMove then
        local okL, lit, col = pcall(hd.LampMove, S, B.actors[1].RootComponent)
        if okL and lit then E.LampGlow(B.mids, true, col) end
    end
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
        local cam = pawn:GetWorld():SpawnActor(StaticFindObject(CAMERA_CLASS), pawn:K2_GetActorLocation(), E.R(0, 0, 0))
        f.cam = cam
        cam.CameraComponent:SetFieldOfView(T.fov)
        cam.CameraComponent.bConstrainAspectRatio = false
        cam:K2_AttachToActor(pawn, FName("None"), SNAP, SNAP, KEEP_WORLD, false)
        Place(f, 1)
        E.GetPC(S):SetViewTargetWithBlend(cam, 0.0, 0, 0.0, false)
    end)
    if not ok then E.Rec(S, "flip off: camera failed, the game camera stays: " .. tostring(err)) end
    S.FlipOffPlan = nil
    return true
end

local function ViewIsCamera(pc, cam)
    local v = pc:GetViewTarget()
    return E.Valid(v) and v:GetAddress() == cam:GetAddress()
end

-- the free bike at its place on the road
local function DriveBike(S, f, pawn, g)
    local A = S.Auto
    if not (A and A.kind == "flipoff") then return end
    if g >= T.despawn then
        local hd = E.Hd()
        if hd and hd.LampHide then pcall(hd.LampHide, S) end -- before its bike goes
        E.AutoStop(S)
        E.Rec(S, string.format("flip off: bike despawned %.0f m down the road", f.dist / 100))
        return
    end
    local _, _, _, _, _, dist = Row(g)
    local moved = dist - f.dist
    local now = E.Now()
    local dt = math.max(now - A.last, 0.001)
    A.last = now
    f.dist = dist
    A.x, A.y = f.x + f.fx * dist, f.y + f.fy * dist
    A.v = moved / dt
    A.fr = A.fr + 1
    if A.fr % 4 == 0 then E.AutoGround(pawn, A) end
    A.z = A.z + (A.zT - A.z) * math.min(dt * 10, 1)
    E.AutoPlace(A, moved)
    E.AutoSound(A, pawn, dist)
end

-- Every frame, before the ride's own frame.
function O.Frame(S, pc, pawn)
    local f = S.FlipOff
    if not f or f.landing then return end
    Hold(f, pawn)
    local hd = E.Hd()
    if hd then pcall(hd.Script, S, 0) end
    if not f.t0 then
        local A = S.Anim
        if A and A.held and E.Now() - f.born >= HOLD then E.GetOnGo(S) end
        A = S.Anim
        if A and A.held then return end
        f.t0 = E.Now()
        E.Rec(S, string.format("flip off: plays (%.2f s)", (T.frames - 1) / T.fps))
    end
    local el = E.Now() - f.t0
    local g = math.min(el * T.fps + 1, T.frames)
    f.g = g
    if not f.grunted and g >= LAND_FRAME then
        f.grunted = true
        if hd and hd.GruntNow then pcall(hd.GruntNow, S, pawn, 2, "get-off: feet on the road") end
    end
    DriveBike(S, f, pawn, g)
    if E.Valid(f.cam) then
        Place(f, g)
        f.fr = f.fr + 1
        if f.fr % 30 == 0 and not ViewIsCamera(pc, f.cam) then
            f.retargets = f.retargets + 1
            if f.retargets == 1 then E.Rec(S, "flip off: the game took the view back, setting the camera again") end
            if f.retargets <= 5 then pc:SetViewTargetWithBlend(f.cam, 0.0, 0, 0.0, false) end
        end
    end
end

-- The animation has ended: just before she gets off, her capsule goes to where the animation has put her.
function O.Land(S, pawn)
    local f = S.FlipOff
    if not f then return end
    f.landing = true
    if E.Valid(f.cam) then pcall(function() f.cam:K2_DetachFromActor(KEEP_WORLD, KEEP_WORLD, KEEP_WORLD) end) end
    local x, y = f.x + f.fx * T.land, f.y + f.fy * T.land
    local g = E.Trace(pawn, E.V(x, y, f.feet + 100), E.V(x, y, f.feet - 150))
    local z = (g and g.Z or f.feet) + E.HalfHeight(pawn) + 2
    pawn:K2_SetActorLocationAndRotation(E.V(x, y, z), E.R(0, f.yaw, 0), false, {}, true)
end

local function Clean(f)
    if E.Valid(f.cam) then pcall(function() f.cam:K2_DestroyActor() end) end
    for _, b in ipairs(f.bounds) do
        if E.Valid(b.c) then pcall(function() b.c:SetBoundsScale(b.was) end) end
    end
end

-- after the landing: the camera stays until the view has blended back to the game's
function O.After(S)
    local e = S.FlipOffEnd
    if e and E.Now() >= e.t then
        S.FlipOffEnd = nil
        Clean(e.f)
    end
end

function O.Stop(S, why)
    local e = S.FlipOffEnd
    if e and why ~= "got off" then
        S.FlipOffEnd = nil
        Clean(e.f)
    end
    local f = S.FlipOff
    S.FlipOff, S.FlipOffPlan = nil, nil
    if not f then return end
    local hd = E.Hd()
    if f.landing and why == "got off" then
        pcall(function()
            local pc = E.GetPC(S)
            pc:SetViewTargetWithBlend(pc.Pawn, T.blend, EASE_IN_OUT, 2.0, false)
        end)
        S.FlipOffEnd = { f = f, t = E.Now() + T.blend + 0.1 }
        E.Rec(S, string.format("flip off: landed (view reset %d time(s), pulled back %d time(s), worst %.0f cm)", f.retargets, f.pulls, f.worst))
        return
    end
    if hd and hd.LampBack and S.Riding then
        pcall(function() hd.LampBack(S, E.GetPC(S).Pawn) end) -- before the free bike it hangs on goes
    end
    if S.Auto and S.Auto.kind == "flipoff" then pcall(E.AutoStop, S) end
    pcall(function()
        local pc = E.GetPC(S)
        if E.Valid(pc.Pawn) then pc:SetViewTargetWithBlend(pc.Pawn, 0.0, 0, 0.0, false) end
    end)
    Clean(f)
    if S.BatActors then E.Show({ actors = S.BatActors }, true) end
    if S.Riding and S.Anim and S.Anim.flipoff then
        S.Anim = nil
        if E.Valid(S.Puppet) and E.Valid(S.PoseAnim) then pcall(E.RidePlay, S, S.Puppet.SkeletalMeshComponent, S.PoseAnim) end
        if hd then pcall(hd.Lock, S, false) end
    end
    E.Rec(S, "flip off: stopped (" .. tostring(why) .. ")")
end

return O
