-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The select widgets' pick watcher, moved out of online/modes/nightop/roxanne.lua for every module to read.
local U=require('core.unreal')
local Roxanne={}
local SELECT='/Script/SB.SBSequencerInteractionSelectWidget'
local WIDGETS='/Script/UMG.Default__WidgetBlueprintLibrary'
-- s between two looks for the widget through FindAllOf (the class lookup looks at each tick).
Roxanne.FIND_EVERY=2
local why=U.why
-- The select widgets' picks (online/modes/nightop/roxanne.lua's and world/maps/matrix13/quest/on_time.lua's):
-- o.log(text) logs, o.paused() whether the game is paused or shows one of its screens. watch(eve, now, pick) looks for
-- the widgets of EVE's world again at each call (every FIND_EVERY through FindAllOf), so a box the game builds for a
-- later dialogue is watched while an older one is still valid; a widget seen before keeps its last SelectIndex. A pick:
-- a SelectIndex turning from -1 to a line (a widget first seen on a line holds an old pick), pick(text) called with
-- that line's text. reset() forgets the widgets.
function Roxanne.watcher(o)
    local log,paused=o.log,o.paused
    local held,look_at,walk=nil,-math.huge,false -- The select widgets {obj, last}; the next look; FindAllOf's route.
    -- The select widgets of EVE's world: the widget library's lookup (the engine's class hash), or, when that call
    -- fails, FindAllOf (which walks every object) only while the game shows one of its screens.
    local function widgets(eve)
        local list={}
        if not walk then
            local out={}
            local ok,e=pcall(function() U.find(WIDGETS):GetAllWidgetsOfClass(eve,out,U.find(SELECT),false) end)
            if ok then
                U.each(out,function(_,w) w=U.valid(w); if w then list[#list+1]={obj=w} end end)
                return list
            end
            walk=true
            log('roxanne: the widget lookup failed ('..why(e)..'): the select widget is looked for while a game '
                ..'screen shows')
        end
        if not paused() then return list end
        U.each(FindAllOf('WB_Theater_InteractionSelect_Master_C') or {},function(_,w)
            w=U.valid(w)
            if w and not U.text(w:GetFullName()):find('Default__',1,true) then list[#list+1]={obj=w} end
        end)
        return list
    end
    local self={}
    function self.watch(eve,now,pick)
        if now>=look_at then
            look_at=now+(walk and Roxanne.FIND_EVERY or 0)
            local seen={}
            for _,w in ipairs(held or {}) do seen[U.address(w.obj)]=w end
            local list=widgets(eve)
            for k,w in ipairs(list) do list[k]=seen[U.address(w.obj)] or w end
            held=list
        end
        for _,w in ipairs(held or {}) do
            local ok,i=pcall(function() return U.value_of(w.obj.SelectIndex) end)
            if ok and U.valid(w.obj) then
                if w.last and w.last<0 and i>=0 then
                    local got,text=pcall(function() return U.text(w.obj.DataArray[i+1].DisplayText) end)
                    if got then pick(text) end
                end
                w.last=i
            end
        end
    end
    function self.reset() held=nil end
    return self
end
return Roxanne
