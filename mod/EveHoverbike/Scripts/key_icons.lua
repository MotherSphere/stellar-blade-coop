-- HUD button icons after the button table changes (2026-11-18). Loaded by handling.lua.
--
-- The game redraws its button icons only when the input device changes (build 26123051: the refresh
-- broadcast at 0x143D26FF0 is not reached from ForceRebuildKeymaps, and the SBInputKeyMapping cheats
-- are empty). So a prompt drawn during a ride kept the bike's RB after get-off, while RT was the
-- button that worked. After every table change (get on, get off, drone on, drone off) the HUD widgets
-- that show buttons are told to redraw, in three passes: a prompt the game redraws while the change
-- is settling is corrected by a later pass. A few widgets per frame, so there is no hitch.
local M = {}

M.Delays = { 0.1, 0.6, 2.0 } -- seconds after the table changed
M.PerFrame = 8

-- the widgets with a keymapping handler, as property paths from WB_MainHUD_Master_C
local PATHS = {
    { "WB_MainHUD_ActionAssist" }, { "WB_MainHUD_Dpad" }, { "WB_MainHUD_EnemyInfo" }, { "WB_MainHUD_Hint" }, { "WB_MainHUD_Skill" },
    { "WB_MainHUD_GuideMessage", "GuideMessage_Slot0" }, { "WB_MainHUD_GuideMessage", "GuideMessage_Slot1" },
    { "WB_MainHUD_Fishing" }, { "WB_MainHUD_Fishing", "WB_Fishing_HItbtn" }, { "WB_MainHUD_Fishing", "WB_MainHUD_FishingHold" },
    { "WB_MainHUD_Fishing", "WB_MainHUD_FishingHOOKbtn" }, { "WB_MainHUD_TpsMaster", "WB_Tps_Bullet3", "Slot_Bullet" },
}

function M.Ask(S, why)
    S.Icons = { why = why, pass = 0, t0 = os.clock() } -- a new change starts the passes again
end

local function Child(w, name, Valid)
    local ok, c = pcall(function() return w[name] end)
    if ok and Valid(c) then return c end
    return nil
end

local function List(master, Valid)
    local out = { { w = master } }
    for _, path in ipairs(PATHS) do
        local w = master
        for _, name in ipairs(path) do
            w = w and Child(w, name, Valid)
        end
        if w then out[#out + 1] = { w = w } end
    end
    local box = Child(master, "WB_MainHUD_Interactable", Valid)
    for i = 1, 10 do
        local s = box and Child(box, "WB_Slot_" .. i, Valid)
        if s then out[#out + 1] = { w = s, slot = true } end
    end
    return out
end

local function IconName(slot, Valid)
    local name
    pcall(function()
        local tex = slot.icon.Brush.ResourceObject
        if Valid(tex) then name = tex:GetFullName():match("([^%.]+)$") end
    end)
    return name
end

local function Names(set)
    local t = {}
    for k in pairs(set) do t[#t + 1] = k end
    table.sort(t)
    return #t > 0 and table.concat(t, ", ") or "none"
end

local function FindMaster(S, Valid)
    if Valid(S.IconMaster) then return S.IconMaster end
    S.IconMaster = nil
    local m = FindFirstOf("WB_MainHUD_Master_C")
    if Valid(m) then
        S.IconMaster = m
        return m
    end
    return nil
end

function M.Tick(S, Rec, Valid)
    local I = S.Icons
    if not I then return end
    if not I.queue then
        if os.clock() - I.t0 < M.Delays[I.pass + 1] then return end
        local master = FindMaster(S, Valid)
        if not master then
            Rec(S, string.format("key icons: the HUD was not found (%s)", I.why))
            S.Icons = nil
            return
        end
        I.pass, I.queue, I.at, I.done, I.before, I.after = I.pass + 1, List(master, Valid), 0, 0, {}, {}
    end
    for _ = 1, M.PerFrame do
        I.at = I.at + 1
        local e = I.queue[I.at]
        if not e then break end
        if Valid(e.w) then
            local was = e.slot and IconName(e.w, Valid)
            if pcall(function() e.w:NotifyKeymappingChanged() end) then I.done = I.done + 1 end
            if e.slot then
                pcall(function() e.w:UpdateInteractionIcon() end)
                local now = IconName(e.w, Valid)
                if was then I.before[was] = true end
                if now then I.after[now] = true end
            end
        end
    end
    if I.at >= #I.queue then
        Rec(S, string.format("key icons (%s): pass %d of %d, %d of %d widgets told; prompt icons before: %s; now: %s",
            I.why, I.pass, #M.Delays, I.done, #I.queue, Names(I.before), Names(I.after)))
        I.queue = nil
        if I.pass >= #M.Delays then S.Icons = nil end
    end
end

return M
