-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Closet's copy of tests/lua/closet/probe_test.lua's fake kit, with add and view running a group's build through a
-- builder copied from tests/lua/online/lobby/ui/lobby_test.lua:99-151 (November 2026): its own from then on.
-- The fake game side of the closet menu's tests (tests/lua/closet/menu_test.lua): the engine globals the view calls
-- (FText, FName, StaticFindObject, LoadAsset, StaticConstructObject), the rendering library's texture import and the
-- player controller, fake widget parts that record every call, the hair salon grid's TileView (probe_test.lua's, its
-- entry size kept in entry_w and entry_h, its shown entries). F.kit() gives a new fake
-- kit; k.events lists the drops and the
-- TileView's clears in order. Tab buttons and the popup's buttons answer IsHovered from their hover field.
local F = {}
FText = function(s) return {text = s, ToString = function(self) return self.text end} end
FName = function(s) return s end
LoadAsset = function() end
-- The rendering library's ImportFileAsTexture2D: each call a new transient texture, recorded in F.imports (its file);
-- a glyph named in F.refuse gives none. A texture's valid=false is the engine having freed it. F.made[glyph]: its
-- last texture; F.path(glyph): that texture's object path, as a tile's IconAssetPath names it.
F.RENDER = '/Script/Engine.Default__KismetRenderingLibrary'
F.imports, F.refuse, F.made, F.by_path = {}, {}, {}, {}
local count = 0
F.render = {IsValid = function() return true end, type = function() return 'UObject' end,
    ImportFileAsTexture2D = function(_, pc, file)
        assert(pc == F.pc, 'imported with the player controller')
        F.imports[#F.imports + 1] = file
        local glyph = file:match('([%w_]+)%.png$')
        if F.refuse[glyph] then return nil end
        count = count + 1
        local path = '/Engine/Transient.Texture2D_' .. count
        local t = {file = file, glyph = glyph, path = path, valid = true, IsValid = function(t) return t.valid end,
            type = function() return 'UObject' end, GetFullName = function() return 'Texture2D ' .. path end}
        F.made[glyph], F.by_path[path] = t, t
        return t
    end}
function F.path(glyph) return F.made[glyph].path end
-- The grid slot's own icon object, which an entry keeps when a tile's IconAssetPath does not load.
F.icon = {IsValid = function() return true end, type = function() return 'UObject' end,
    GetFullName = function() return 'Texture2D ' .. F.ICON end}
-- The player controller (core/unreal.lua's U.controller asks UEHelpers for it, then IsA PlayerController).
F.pc = {IsValid = function() return true end, type = function() return 'UObject' end, IsA = function() return true end}
-- The file names of F.imports from i on.
function F.imported(i)
    local out = {}
    for n = i or 1, #F.imports do out[#out + 1] = F.imports[n]:match('([%w_]+)%.png$') end
    return out
end
-- type: core/unreal.lua's U.valid reads it (U.her finds SBCharacter through U.find). An object at a path in F.textures
-- is a Texture2D (IsA of the Texture2D class, its full name so): an outfit's Image that loads as one.
F.TEXTURE = '/Script/Engine.Texture2D'
F.textures = {}
StaticFindObject = function(path)
    if path == F.RENDER then return F.render end
    return {path = path, IsValid = function() return true end, type = function() return 'UObject' end,
        IsA = function(self, class) return class.path == F.TEXTURE and F.textures[self.path] == true end,
        GetFullName = function(self) return (F.textures[self.path] and 'Texture2D ' or 'Object ') .. self.path end}
end
StaticConstructObject = function(class, outer)
    return {class = class, outer = outer, IsValid = function() return true end}
end

F.TAB = '/Game/Art/UI/Widget/GameMenu/Common/WB_Common_Tab_Btn.WB_Common_Tab_Btn_C'
F.GRID = '/Game/Art/UI/Widget/HairSalon/WB_HairSalonGridList.WB_HairSalonGridList_C'
F.DETAIL = '/Game/Art/UI/Widget/GameMenu/WorkShop/WB_NanoSuit_Detail.WB_NanoSuit_Detail_C'
F.ICON = '/Game/Art/UI/Texture/Hair/HairIcon/Deco_Item_Hair_000.Deco_Item_Hair_000'
F.OPTION = '/Game/Art/UI/Widget/GameMenu/Setting/Slot/WB_Setting_Button_Slot.WB_Setting_Button_Slot_C'
F.SLIDER = '/Game/Art/UI/Widget/GameMenu/Setting/Slot/WB_Setting_Slider_Slot.WB_Setting_Slider_Slot_C'
F.HINT = '/Game/Art/UI/Widget/GameMenu/Common/Indicator/WB_Common_IndicatorBtnDefault.WB_Common_IndicatorBtnDefault_C'
F.POPUP = '/Game/Art/UI/Widget/GameMenu/Common/WB_Common_Popup.WB_Common_Popup_C'

-- A widget part: fields written are kept, every method call is recorded in calls as {name, args...}.
local function widget(class)
    local w = {class = class, calls = {}}
    return setmetatable(w, {__index = function(t, k)
        return function(_, ...) local c = rawget(t, 'calls'); c[#c + 1] = {k, ...} end
    end})
end
F.widget = widget
-- Whether w got the call name (with first argument arg when given).
function F.called(w, name, arg)
    for _, c in ipairs(w.calls) do if c[1] == name and (arg == nil or c[2] == arg) then return true end end
    return false
end

-- A button the mouse is over while hover is true (IsHovered).
function F.button() return {hover = false, IsHovered = function(self) return self.hover end} end

-- The hair salon grid's TileView (probe_test.lua's game()).
local function tileview(events)
    local tv = {items = {}, SelectionMode = 0, cleared = 0, calls = {}}
    function tv:IsValid() return true end
    function tv:SetVisibility(v) self.v = v end
    function tv:SetSelectionMode(m) self.SelectionMode = m end
    function tv:SetEntryWidth(w) self.entry_w = w end
    function tv:SetEntryHeight(h) self.entry_h = h end
    function tv:ClearListItems() self.items = {}; self.cleared = self.cleared + 1; events[#events + 1] = 'clear' end
    function tv:AddItem(item) self.items[#self.items + 1] = item end
    function tv:GetNumItems() return #self.items end
    function tv:GetItemAt(i) return self.items[i + 1] end
    function tv:SetSelectedIndex(i) self.sel = self.items[i + 1] end
    function tv:GetIndexForItem(item)
        for i, it in ipairs(self.items) do if it == item then return i - 1 end end
        return -1
    end
    function tv:BP_GetSelectedItem() return self.sel end
    -- The entries Slate shows, one a shown item, kept across calls (WB_HairSalon_GridSlot's Data and Image_Icon): an
    -- entry's icon is the texture its item's IconAssetPath names (the slot's LoadAsset_Blocking), else the slot's own
    -- icon, always so while tv.path_fails. tv.hidden: none built yet. tv.displayed counts the calls.
    tv.entries, tv.displayed = {}, 0
    function tv:GetDisplayedEntryWidgets()
        self.displayed = self.displayed + 1
        local out = {}
        if self.hidden then return out end
        for k, item in ipairs(self.items) do
            local e = self.entries[item]
            if not e then
                local shown = not self.path_fails and F.by_path[item.IconAssetPath] or F.icon
                local icon = {Brush = {ResourceObject = shown}, set = {}}
                function icon:SetBrushFromTexture(t, match)
                    self.Brush.ResourceObject = t
                    self.set[#self.set + 1] = {t, match}
                end
                e = {Data = item, Image_Icon = icon}
                self.entries[item] = e
            end
            out[k] = e
        end
        return out
    end
    return tv
end

-- The lobby test's builder: texts, images and mouse zones (b.row) recorded.
local function builder(g)
    local b = {}
    function b.text(x, y, str, style, color, align, o)
        local t = {x = x, y = y, s = str or '', color = color, shown = true, style = style, o = o}
        g.texts[#g.texts + 1] = t
        return {set = function(s) t.s = s or '' end, color = function(c) t.color = c end,
            show = function(on) t.shown = on end}
    end
    -- texture(t) keeps t in the image (a run-time texture: the kit's SetBrushFromTexture).
    function b.image(x, y, w, h, tex, tint)
        local i = {x = x, y = y, w = w, h = h, tex = tex, tint = tint, shown = true}
        g.images[#g.images + 1] = i
        return {show = function(on) i.shown = on end, tint = function(c) i.tint = c end, turn = function() end,
            texture = function(t) i.texture = t; return true end}
    end
    function b.row(x, y, width)
        local z = {x = x, y = y, w = width, hover = false, label = '', value = '', state = 'normal'}
        g.zones[#g.zones + 1] = z
        return {set = function(l, v, st) z.label, z.value, z.state = l or '', v or '', st or 'normal' end,
            hovered = function() return z.hover end}
    end
    function b.shade(x, y, w, h, color) g.shade = {x = x, y = y, w = w, h = h, color = color} end
    return b
end

function F.kit()
    local k = {up = true, groups = {}, shown = {}, made = {}, dropped = 0, held = nil, inputs = {}, sounds = {},
        refocused = 0, paused_now = false, fail = {}, events = {}}
    function k.ready() return k.up end
    function k.off() return false end
    function k.add(name, place, build) k.groups[name] = {place = place, build = build, texts = {}, images = {}, zones = {}} end
    function k.view(name)
        local g = k.up and k.groups[name]
        if not g then return nil end
        if not g.view then g.view = g.build(builder(g)) or {} end
        return g.view
    end
    function k.show(name, on) k.shown[name] = on == true end
    function k.part(group, class_path, x, y, w, h, fill, hit)
        local short = class_path:match('[^.]+$')
        if not k.up or not k.groups[group] then return nil, 'part ' .. short .. ': the UI is not up' end
        if k.fail[class_path] then return nil, 'part ' .. short .. ': not in this game build' end
        local o = widget(class_path)
        if class_path == F.GRID then o.TileView_ItemList = tileview(k.events) end
        if class_path == F.DETAIL then o.WB_Common_HoldButton = widget('hold') end
        if class_path == F.TAB then o.Button_Action = F.button() end
        if class_path == F.POPUP then o.Button_Positive, o.Button_Negative = F.button(), F.button() end
        if fill then fill(o) end
        local rec = {o = o, live = true, class = class_path, x = x, y = y, w = w, h = h, hit = hit}
        k.made[#k.made + 1] = rec
        return rec
    end
    function k.alive(rec) return rec and rec.live and rec.o or nil end
    function k.drop(rec)
        if rec and rec.live then rec.live = false; k.dropped = k.dropped + 1; k.events[#k.events + 1] = 'drop' end
    end
    -- k.deaf: the kit takes no input (a refused take: no player controller).
    function k.input(on, who, mouse, again)
        k.inputs[#k.inputs + 1] = {on, who, mouse, again}
        if on then if not k.deaf then k.held = who end elseif k.held == who then k.held = nil end
    end
    function k.holding(who) return k.held ~= nil and (who == nil or k.held == who) end
    function k.refocus() k.refocused = k.refocused + 1 end
    function k.paused() return k.paused_now end
    function k.sound(name) k.sounds[#k.sounds + 1] = name end
    -- The live parts of a class, in the order made.
    function k.live(class_path)
        local out = {}
        for _, rec in ipairs(k.made) do if rec.live and rec.class == class_path then out[#out + 1] = rec end end
        return out
    end
    return k
end

return F
