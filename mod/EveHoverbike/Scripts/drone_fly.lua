-- Direct drone control (2026-11-18). Loaded by logic.lua (K3.DroneFlyCall), reloads with F5.
--
-- Eve's drone is its own AI character (CH_Drone_BP_C) that chases her, and its speed depends on how
-- far behind it is, so it lagged behind the invisible pilot. Now the pilot stays the body (collision,
-- aiming, shooting) and the drone is placed on her every frame. Design and sources:
-- docs/drone-control-research.md
--
-- R3, the right stick click (keyboard Num 8), switches how the drone is held, for the test ride.
-- Not a D-pad key: the game keeps its own D-pad actions on the bike, and D-pad up uses a heal item.
-- The methods:
--   A    place it every frame, its AI keeps running but cannot move it (the gun needs the AI)
--   B    the same with its AI stopped
--   C    steer the game's own fly mode through its follow point
--   Old  the game's own chase, to compare
-- Every first call is written to events.txt before it is made. telemetry\drone_fly_<time>.csv has
-- one row per frame; off_cm is how far the drone was from where the mod wanted it.
local M = {}
local E

M.C = {
    CapPin = 1,            -- cm/s: the drone's own speed while it is placed by the mod
    CapC = 6000, PowC = 2, -- method C: speed cap and distance exponent
    CruiseTilt = 8,        -- degrees at full speed
    AccelTilt = 17,        -- degrees more at full acceleration
    MaxTilt = 25,
    AccelRef = 3000,       -- cm/s2 that counts as full acceleration
    TiltHalf = 0.08, YawHalf = 0.08, LeadHalf = 0.08, -- spring halflife, seconds
    LeadTime = 0.05,       -- the drone sits ahead of the body by velocity x this
    LeadMax = 60,          -- cm
    WallGap = 30,          -- cm kept from a wall in the way of the lead
    HoldZ = 0,             -- cm above the body
    LagSpeed = 12, LagMax = 80, -- camera boom lag
    FindRadius = 6000,     -- cm: her drone is the nearest one within this
    SwitchKey = "Gamepad_RightThumbstick", SwitchKeyBoard = "NumPadEight",
    AimKey = "Gamepad_LeftShoulder", AimKeyBoard = "RightMouseButton",
    MaxRows = 20000,
}

local METHODS = {
    A = { next = "B", name = "placed every frame, AI running" },
    B = { next = "C", name = "placed every frame, AI stopped" },
    C = { next = "Old", name = "steering the game's fly mode" },
    Old = { next = "A", name = "the game's own chase" },
}

function M.Setup(env) E = env return true end

-- Critically damped spring, exact for any frame time (theorangeduck.com/page/spring-roll-call)
function M.Spring(x, v, goal, half, dt)
    local y = 1.3862944 / (half + 1e-5)
    local j0, e = x - goal, math.exp(-y * dt)
    local j1 = v + j0 * y
    return e * (j0 + j1 * dt) + goal, e * (v - j1 * y * dt)
end

local function Clamp(x, lo, hi) return math.max(lo, math.min(hi, x)) end
local function Wrap(a) return ((a + 180) % 360) - 180 end
local function Dist(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Y - b.Y) ^ 2 + (a.Z - b.Z) ^ 2) end

local function Flush(F)
    if not F.csv or #F.rows == 0 then return end
    local f = io.open(F.csv, "a")
    if f then
        f:write(table.concat(F.rows, "\n"), "\n")
        f:close()
    end
    F.rows = {}
end

local function SetCaps(F)
    local c, C = F.cmc, M.C
    if not E.Valid(c) then return end
    if F.method == "A" or F.method == "B" then
        if c.MaxCustomMovementSpeed ~= C.CapPin then c.MaxCustomMovementSpeed = C.CapPin end
        if c.MaxFlySpeed ~= C.CapPin then c.MaxFlySpeed = C.CapPin end
    elseif F.method == "C" then
        if c.MaxCustomMovementSpeed ~= C.CapC then c.MaxCustomMovementSpeed = C.CapC end
        if c.CustomFlyMoveSpeedPow ~= C.PowC then c.CustomFlyMoveSpeedPow = C.PowC end
    end
end

local function GiveBackMovement(F)
    local c = F.cmc
    if not E.Valid(c) then return end
    for k, v in pairs(F.saved) do c[k] = v end
end

local function Brain(F)
    local b
    pcall(function()
        local c = F.drone.Controller
        if E.Valid(c) and E.Valid(c.BrainComponent) then b = c.BrainComponent end
    end)
    return b
end

local function Enter(S, F, method)
    F.method = method
    F.st = { n = 0, sum = 0, max = 0, over = 0, us = 0 }
    F.last = nil
    SetCaps(F)
    if method == "B" then
        local b = E.Valid(F.drone) and Brain(F)
        E.Rec(S, "drone fly: first call, stopping the drone's AI" .. (b and "" or " (no AI found)"))
        if b then
            local ok, err = pcall(function() b:StopLogic("drone piloting") end)
            if ok then F.brain = b else E.Rec(S, "drone fly: the AI could not be stopped: " .. tostring(err)) end
        end
    end
    E.Rec(S, string.format("drone fly: method %s now (%s)", method, METHODS[method].name))
end

local function Leave(S, F)
    local st = F.st
    if st and st.n > 0 then
        E.Rec(S, string.format("drone fly: method %s result: %d frames, off target %.1f cm on average, at most %.1f cm, %d frames over 5 cm; code %.0f us per frame",
            F.method, st.n, st.sum / st.n, st.max, st.over, st.us / st.n))
    end
    if F.brain then
        local b = F.brain
        F.brain = nil
        if E.Valid(b) then pcall(function() b:RestartLogic() end) end
    end
    GiveBackMovement(F)
end

local function FindDrone(pawn)
    local list = FindAllOf("CH_Drone_BP_C")
    if not list then return nil, 0 end
    local p, best, bestD, n = pawn:K2_GetActorLocation(), nil, M.C.FindRadius, 0
    for _, a in ipairs(list) do
        if E.Valid(a) and not a:GetFullName():find("Default__", 1, true) then
            n = n + 1
            local d = Dist(a:K2_GetActorLocation(), p)
            if d < bestD then best, bestD = a, d end
        end
    end
    return best, n
end

function M.Start(S, D, pawn)
    if E.Config.Drone.DirectControl == false then return end
    local drone, n = FindDrone(pawn)
    if not E.Valid(drone) then
        E.Rec(S, string.format("drone fly: Eve's drone not found (%d seen), it will chase her as before", n))
        return
    end
    local cmc = drone.CharacterMovement
    local F = { mod = M, drone = drone, cmc = cmc, fr = 0, rows = {}, nrows = 0, keys = {},
        saved = { MaxCustomMovementSpeed = cmc.MaxCustomMovementSpeed, MaxFlySpeed = cmc.MaxFlySpeed,
            CustomFlyMoveSpeedPow = cmc.CustomFlyMoveSpeedPow },
        pitch = 0, pitchV = 0, roll = 0, rollV = 0, yaw = drone:K2_GetActorRotation().Yaw, yawV = 0,
        lxV = 0, lyV = 0, lzV = 0, vx = 0, vy = 0, leadScale = 1 }
    -- starts from where the drone is, so it glides onto the body instead of jumping
    local p, d = pawn:K2_GetActorLocation(), drone:K2_GetActorLocation()
    local gap, s = Dist(p, d), 1
    if gap > 500 then s = 500 / gap end
    F.lx, F.ly, F.lz = (d.X - p.X) * s, (d.Y - p.Y) * s, (d.Z - p.Z) * s
    local okB, errB = pcall(function() -- the camera lag is a nicety: flying goes on without it
        local boom = pawn.CameraBoom
        if not E.Valid(boom) then return end
        local was = { bEnableCameraLag = boom.bEnableCameraLag, CameraLagSpeed = boom.CameraLagSpeed,
            CameraLagMaxDistance = boom.CameraLagMaxDistance }
        E.Rec(S, string.format("drone fly: first call, camera lag on (it was %s, speed %.1f, max %.0f cm)",
            tostring(was.bEnableCameraLag), was.CameraLagSpeed, was.CameraLagMaxDistance))
        F.boom, F.boomSaved = boom, was
        boom.bEnableCameraLag = true
        boom.CameraLagSpeed = M.C.LagSpeed
        boom.CameraLagMaxDistance = M.C.LagMax
    end)
    if not okB then E.Rec(S, "drone fly: camera lag not set: " .. tostring(errB)) end
    F.csv = (S.Dir or "") .. "..\\telemetry\\drone_fly_" .. os.date("%Y%m%d_%H%M%S") .. ".csv"
    F.rows[1] = "t,method,dt_ms,off_cm,speed_cms,body_x,body_y,body_z,drone_x,drone_y,drone_z,pitch,yaw,roll,aim,us"
    D.fly = F
    E.Rec(S, string.format("drone fly: on, %d drone(s) in the world, speed cap was %.0f, fly speed %.0f, exponent %.2f",
        n, F.saved.MaxCustomMovementSpeed, F.saved.MaxFlySpeed, F.saved.CustomFlyMoveSpeedPow))
    Enter(S, F, "A")
end

local function Key(F, pc, name)
    local k = F.keys[name]
    if not k then
        k = { KeyName = FName(name) }
        F.keys[name] = k
    end
    return pc:IsInputKeyDown(k) == true
end

function M.Frame(S, D, pc, pawn, rot, dt)
    local F = D.fly
    if not F then return end
    local t0, C = os.clock(), M.C
    F.fr = F.fr + 1
    dt = math.max(dt, 1 / 240)
    if F.fr % 2 == 1 then
        local sw = Key(F, pc, C.SwitchKey) or Key(F, pc, C.SwitchKeyBoard)
        if sw and not F.swDown and E.Valid(F.drone) then
            Leave(S, F)
            Enter(S, F, METHODS[F.method].next)
        end
        F.swDown = sw
        F.aim = Key(F, pc, C.AimKey) or Key(F, pc, C.AimKeyBoard)
    end
    if not E.Valid(F.drone) then
        if not F.lost then
            F.lost = true
            E.Rec(S, "drone fly: the drone is gone, piloting goes on without it")
        end
        return
    end
    if F.fr % 20 == 0 then SetCaps(F) end
    -- how far the drone is from where it was meant to be
    local now, off = F.drone:K2_GetActorLocation(), 0
    if F.last then off = Dist(now, F.last) end
    -- the body, where it will be once the game has moved it this frame
    local p, v = pawn:K2_GetActorLocation(), pawn:GetVelocity()
    local bx, by, bz = p.X + v.X * dt, p.Y + v.Y * dt, p.Z + v.Z * dt
    -- lean: from speed and acceleration in the drone's own frame
    local cy, sy = math.cos(math.rad(F.yaw)), math.sin(math.rad(F.yaw))
    local ax, ay = (v.X - F.vx) / dt, (v.Y - F.vy) / dt
    F.vx, F.vy = v.X, v.Y
    local top = math.max(E.Config.Drone.Speed or 1200, 1)
    local vF, vR = v.X * cy + v.Y * sy, -v.X * sy + v.Y * cy
    local aF, aR = ax * cy + ay * sy, -ax * sy + ay * cy
    local wantP = -(C.CruiseTilt * Clamp(vF / top, -1, 1) + C.AccelTilt * Clamp(aF / C.AccelRef, -1, 1))
    local wantR = C.CruiseTilt * Clamp(vR / top, -1, 1) + C.AccelTilt * Clamp(aR / C.AccelRef, -1, 1)
    wantP, wantR = Clamp(wantP, -C.MaxTilt, C.MaxTilt), Clamp(wantR, -C.MaxTilt, C.MaxTilt)
    if F.aim then wantP, wantR = Wrap(rot.Pitch), 0 end -- aiming: it looks where the camera looks
    F.pitch, F.pitchV = M.Spring(F.pitch, F.pitchV, wantP, C.TiltHalf, dt)
    F.roll, F.rollV = M.Spring(F.roll, F.rollV, wantR, C.TiltHalf, dt)
    F.yaw, F.yawV = M.Spring(F.yaw, F.yawV, F.yaw + Wrap(rot.Yaw - F.yaw), C.YawHalf, dt)
    F.yaw = Wrap(F.yaw)
    -- lead: the drone moves first on screen, but never into a wall
    local gx, gy, gz = v.X * C.LeadTime, v.Y * C.LeadTime, v.Z * C.LeadTime
    local len = math.sqrt(gx * gx + gy * gy + gz * gz)
    if len > C.LeadMax then
        local s = C.LeadMax / len
        gx, gy, gz, len = gx * s, gy * s, gz * s, C.LeadMax
    end
    if F.fr % 3 == 0 then
        F.leadScale = 1
        if len > 1 then
            local hit = E.Trace(pawn, E.V(bx, by, bz), E.V(bx + gx, by + gy, bz + gz))
            if hit then
                local room = math.sqrt((hit.X - bx) ^ 2 + (hit.Y - by) ^ 2 + (hit.Z - bz) ^ 2) - C.WallGap
                F.leadScale = Clamp(room / len, 0, 1)
            end
        end
    end
    local k = F.leadScale
    F.lx, F.lxV = M.Spring(F.lx, F.lxV, gx * k, C.LeadHalf, dt)
    F.ly, F.lyV = M.Spring(F.ly, F.lyV, gy * k, C.LeadHalf, dt)
    F.lz, F.lzV = M.Spring(F.lz, F.lzV, gz * k, C.LeadHalf, dt)
    local want = E.V(bx + F.lx, by + F.ly, bz + F.lz + C.HoldZ)
    local turn = E.R(F.pitch, F.yaw, F.roll)
    if F.method == "A" or F.method == "B" then
        F.drone:K2_SetActorLocationAndRotation(want, turn, false, {}, true)
    elseif F.method == "C" then
        F.cmc.CustomFlyFollowLocation = want
        F.drone:K2_SetActorRotation(turn, false)
    end
    F.last = want
    -- recorder
    local us, st = (os.clock() - t0) * 1000000, F.st
    st.n, st.sum, st.max, st.us = st.n + 1, st.sum + off, math.max(st.max, off), st.us + us
    if off > 5 then st.over = st.over + 1 end
    if F.nrows < C.MaxRows then
        F.nrows = F.nrows + 1
        F.rows[#F.rows + 1] = string.format("%.3f,%s,%.2f,%.1f,%.0f,%.0f,%.0f,%.0f,%.0f,%.0f,%.0f,%.1f,%.1f,%.1f,%d,%.0f",
            E.Now(), F.method, dt * 1000, off, math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z), bx, by, bz, now.X, now.Y, now.Z,
            F.pitch, F.yaw, F.roll, F.aim and 1 or 0, us)
        if #F.rows >= 60 then Flush(F) end
    end
end

-- Every way out of piloting comes through here (logic.lua DroneStop)
function M.Stop(S, D)
    local F = D and D.fly
    if not F then return end
    D.fly = nil
    pcall(Leave, S, F)
    if E.Valid(F.boom) then
        pcall(function() for k, v in pairs(F.boomSaved) do F.boom[k] = v end end)
    end
    if E.Valid(F.drone) and D.home then -- upright, beside the bike, ready to follow her again
        S.LastDroneHome = E.V(D.home.X, D.home.Y, D.home.Z + 120)
        pcall(function() F.drone:K2_SetActorLocationAndRotation(S.LastDroneHome, E.R(0, F.yaw, 0), false, {}, true) end)
    end
    pcall(Flush, F)
    E.Rec(S, "drone fly: off, the drone is the game's again")
end

return M
