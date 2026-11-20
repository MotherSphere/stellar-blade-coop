-- Eve Hoverbike (dev build, made for Saroj, 2026-11-12)
-- Spawns Adam's hoverbike (Adam_Vehicle_02 from the intro cutscene) out of the camera's view
-- and lets Eve ride it.
--
-- This file is a fixed loader. The real work is in logic.lua, which can be edited while the game
-- runs: save it, press F5 in game, and only this mod reloads (UE4SS hot reload stays off).
-- If logic.lua has an error, the old copy keeps running and the error goes to UE4SS.log.
--
-- Keys:
--   H             screen fades to black, Eve is on the bike, ready to go
--                 riding: fades to black, bike gone, Eve on foot
--   Ctrl + H      emergency: remove the bike at once, clear a stuck black screen
--   D-pad right   (controller) same as H. Was L3 + R3 until 2026-11-15 (that is the game's Tachy mode).
--                 Not while LB or LT is held (the game's item / ammo wheel).
--   F5            reload logic.lua (and handling.lua)
--
-- Since 2026-11-15 (all set on the CPS page "Eve Hoverbike"):
--   The bike drives itself to Eve's side and away again; a short black blink seats her.
--   Headlight on with the menu switch, B (pad and keyboard) toggles it; hold Y (pad and keyboard) nitro,
--   left stick back / forward (keyboard Down / Up arrow) wheelie, in the air the same stick flips.
--   Her blade stays folded while riding. Photo mode faces show in the bike pose.
--   L3 (keyboard C) arms wall climbing: drive into a wall with the throttle held.
--   D-pad left (keyboard U) while riding = drone piloting, again = back to Eve (see logic.lua). Was D-pad up.
--   Drone: left stick flies, RT up, LT down. F8 there writes a marker to events.txt.
--   No black screen any more (2026-11-15): the bike drives in, Eve gets on with her animation,
--   and the engine starts when the animation has ended.
--
-- While riding (2026-11-14): Eve wears the Night Rider CNS outfit if installed (optional, needs CNS) (Night Rider by its author,
--   https://www.nexusmods.com/stellarblade/mods/2479, thank you), outfit changes are undone, the old
--   outfit comes back when she gets off. Photo mode keeps the bike pose (pose 'None' = bike pose).
--   Tyre dust on skids / drifts is Emil's wheel smoke from the NieR:Automata DLC.
--   Events (switch timing, outfit, photo mode) go to EveHoverbike\telemetry\events.txt.
--
-- Riding (handling.lua): RT / W throttle, LT / S brake (hold when stopped = reverse),
--   left stick / A D steer. F6 = stick-only controls, F7 = other drive method,
--   F8 = marker in the ride recording (EveHoverbike\telemetry\ride_*.csv)
--
-- Tuning keys (numpad, saved to tuning.txt next to this file):
--   8 / 2  bike forward / back under Eve      4 / 6  bike left / right
--   9 / 3  bike up / down                     7 / 1  turn bike left / right
--   Ctrl + 8 / 2 (or Page Up / Down)  tilt nose up / down
--   Ctrl + 6 / 4 (or Numpad * / Numpad /)  roll
--   5      next riding pose                   .      next animation slot
--   + / -  riding speed up / down

local TAG = "[EveHoverbike] "
local Dir = debug.getinfo(1, "S").source:sub(2):match("^(.*[\\/])") or ""
local State = { Dir = Dir }   -- survives reloads
local M = nil                 -- current logic table

local function Log(msg) print(TAG .. msg .. "\n") end

local function Load()
    local chunk, err = loadfile(Dir .. "logic.lua")
    if not chunk then
        Log("reload FAILED (syntax), old logic kept: " .. tostring(err))
        return false
    end
    local ok, mod = pcall(chunk)
    if not ok or type(mod) ~= "table" then
        Log("reload FAILED (run error), old logic kept: " .. tostring(mod))
        return false
    end
    if M and M.Unload then pcall(M.Unload, State) end
    M = mod
    if M.Init then
        local ok2, e2 = pcall(M.Init, State)
        if not ok2 then Log("Init error: " .. tostring(e2)) end
    end
    return true
end

local function Call(name, ...)
    if M and M[name] then
        local ok, err = pcall(M[name], State, ...)
        if not ok then Log(name .. " error: " .. tostring(err)) end
    end
end

local function Bind(key, mods, name, ...)
    local args = { ... }
    local fn = function() ExecuteInGameThread(function() Call(name, table.unpack(args)) end) end
    if mods then RegisterKeyBind(key, mods, fn) else RegisterKeyBind(key, fn) end
end

Load()

-- Tick: hooked on Eve's own per-frame Blueprint tick, so it runs on the game thread.
-- It used to be LoopAsync(50): UE4SS 3.0.1 runs that on a second thread in the same Lua state
-- as the game-thread code, and with longer get-on work the two collided: heap corruption crash
-- (0xc0000374, 2026-11-13). Logic still runs about every 50 ms (every 3rd frame).
local EVE_TICK = "/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C:ReceiveTick"
local TickHooked = false
local Frame = 0
local function TryHookTick()
    if TickHooked then return end
    if not StaticFindObject(EVE_TICK):IsValid() then return end -- Eve's Blueprint not loaded yet
    local ok, err = pcall(RegisterHook, EVE_TICK, function()
        Frame = Frame + 1
        Call("FastTick") -- every frame: bike physics while riding (returns at once on foot)
        if Frame % 3 == 0 then Call("Tick") end
    end)
    if ok then
        TickHooked = true
        Log("tick hooked on Eve's Blueprint tick (game thread)")
    else
        Log("tick hook failed: " .. tostring(err))
    end
end

-- Photo mode pauses the world, and Eve's own tick with it. Her animation blueprint still updates
-- (the game shows photo mode faces live), so its update event is the tick for photo mode on the
-- bike: logic.lua copies the face shapes there (L.AnimTick). Costs nothing outside photo mode:
-- the callback returns at once unless photo mode is open while riding (State.Photo).
local EVE_ANIM = "/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_AnimBP_New.CH_P_EVE_01_AnimBP_New_C:BlueprintUpdateAnimation"
local AnimHooked = false
local function TryHookAnim()
    if AnimHooked then return end
    if not StaticFindObject(EVE_ANIM):IsValid() then return end
    local ok, err = pcall(RegisterHook, EVE_ANIM, function()
        if State.Photo then Call("AnimTick") end
    end)
    if ok then
        AnimHooked = true
        Log("photo mode tick hooked on Eve's animation blueprint update")
    else
        Log("animation blueprint hook failed: " .. tostring(err))
    end
end

-- Drone piloting (logic.lua) listens to the game's own events: ammo changes (they carry Eve's id and
-- the ammo names), health changes, and "an enemy targets this actor". They are functions on the
-- player controller that the game calls for every such event. Ammo changes are always passed on
-- (rare), the others only while Eve rides (State.Riding), so on foot they cost next to nothing.
local NET = "/Script/SB.SBNetworkPlayerController:ClientBroadcast_"
local NetHooked = false
local function TryHookNet()
    if NetHooked then return end
    if not StaticFindObject(NET .. "ActorApplyStat"):IsValid() then return end
    NetHooked = true
    for _, n in ipairs({ "ActorSetBulletItem", "ActorApplyStat", "ActorAddTargetedByEnemy" }) do
        local ok, err = pcall(RegisterHook, NET .. n, function(ctx, ...)
            if State.Riding or n == "ActorSetBulletItem" then Call("OnNet", n, ...) end
        end)
        Log("game event " .. n .. (ok and " hooked" or (" hook FAILED: " .. tostring(err))))
    end
    -- 2026-11-15: hooks on the ServerRequest_ functions (ChangeBulletItem, ActorJump, ActorLanded,
    -- UseSkill) were tried to learn Eve's id. They never passed anything to Lua and crashed the game
    -- twice inside UE4SS (unhandled C++ exception in a hooked game call). Removed; do not hook them.
end

-- Drone piloting hides the ambush prompt on the enemy info widgets (logic.lua, DronePrompt). The game
-- makes new ones as enemies show up; this only raises a flag so logic.lua looks for them again.
-- Nothing else happens here, and nothing at all unless the drone is being piloted.
local ENEMY_INFO = "/Game/Art/UI/Widget/HUD/WB_MainHUD_EnemyInfo.WB_MainHUD_EnemyInfo_C"
local PromptHooked = false
local function TryHookPrompt()
    if PromptHooked then return end
    if not StaticFindObject(ENEMY_INFO):IsValid() then return end -- the HUD is not loaded yet
    local ok, err = pcall(NotifyOnNewObject, ENEMY_INFO, function()
        local D = State.Drone
        if D then D.promptDirty = true end
    end)
    PromptHooked = true -- one try only
    State.PromptHook = ok
    Log("enemy info widget watch " .. (ok and "on" or ("FAILED: " .. tostring(err))))
end

local TryHookTickOnly = TryHookTick
TryHookTick = function()
    TryHookTickOnly()
    TryHookAnim()
    TryHookNet()
    TryHookPrompt()
end
TryHookTick()

pcall(RegisterHook, "/Script/Engine.PlayerController:ClientRestart", function()
    TryHookTick()
    Call("OnRestart")
end)

-- Eve's Blueprint loads with the first level: hook the tick as soon as a character appears
pcall(NotifyOnNewObject, "/Script/SB.SBCharacter", function()
    if not TickHooked or not AnimHooked or not NetHooked or not PromptHooked then TryHookTick() end
end)

-- Photo mode crashed while riding (2026-11-13). Its camera pawn is created right as photo
-- mode opens: get Eve off the bike cleanly at that moment (runs at once, not next tick).
pcall(NotifyOnNewObject, "/Script/SB.SBPhotoModePawn", function()
    Call("OnPhotoMode")
end)

Bind(Key.F3, nil, "ActionKey") -- F3 since 2026-11-19 (was H; SBO's own bike key is off); a 0.5 s hold
Bind(Key.F3, { ModifierKey.CONTROL }, "Remove")

Bind(Key.NUM_EIGHT, nil, "Nudge", "X", 5)
Bind(Key.NUM_TWO, nil, "Nudge", "X", -5)
Bind(Key.NUM_SIX, nil, "Nudge", "Y", 5)
Bind(Key.NUM_FOUR, nil, "Nudge", "Y", -5)
Bind(Key.NUM_NINE, nil, "Nudge", "Z", 5)
Bind(Key.NUM_THREE, nil, "Nudge", "Z", -5)
Bind(Key.NUM_SEVEN, nil, "Nudge", "Yaw", -15)
Bind(Key.NUM_ONE, nil, "Nudge", "Yaw", 15)
-- Tilt: Ctrl + numpad (works) and spare keys (load on the next restart). Step size is TiltStep in logic.lua.
Bind(Key.NUM_EIGHT, { ModifierKey.CONTROL }, "Nudge", "Pitch", 1)
Bind(Key.NUM_TWO, { ModifierKey.CONTROL }, "Nudge", "Pitch", -1)
Bind(Key.NUM_SIX, { ModifierKey.CONTROL }, "Nudge", "Roll", 1)
Bind(Key.NUM_FOUR, { ModifierKey.CONTROL }, "Nudge", "Roll", -1)
Bind(Key.PAGE_UP, nil, "Nudge", "Pitch", 15)
Bind(Key.PAGE_DOWN, nil, "Nudge", "Pitch", -15)
Bind(Key.MULTIPLY, nil, "Nudge", "Roll", 15)
Bind(Key.DIVIDE, nil, "Nudge", "Roll", -15)
Bind(Key.NUM_FIVE, nil, "NextPose")
Bind(Key.DECIMAL, nil, "NextSlot")
Bind(Key.ADD, nil, "Nudge", "Speed", 200)
Bind(Key.SUBTRACT, nil, "Nudge", "Speed", -200)

-- Handling (handling.lua): F2 trigger / stick controls, F11 drive method, F4 marker in the ride recording.
-- Moved off F5-F8 on 2026-11-19: those are Stellar Blade Online's keys (menu, status, follow, leave).
Bind(Key.F2, nil, "HandlingKey", "scheme")
Bind(Key.F11, nil, "HandlingKey", "method")
Bind(Key.F4, nil, "HandlingKey", "mark")

RegisterKeyBind(Key.F1, function()
    ExecuteInGameThread(function()
        if Load() then Log("logic.lua reloaded") end
    end)
end)

Log("loaded. Hold F3 0.5 s = get on / get off, Ctrl+F3 = emergency remove, hold D-pad right = same as F3, "
    .. "F1 = reload logic.lua")
