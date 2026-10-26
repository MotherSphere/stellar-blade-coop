-- The cut shooting test's score widget: /Game/Art/UI/Widget/Test/WB_ShootingTrainingTest, an SBUserWidget holding one
-- TextBlock, Score, which reads '점수 76점 (^^*)' ("76 points (^^*)") in pink at font size 191 on a canvas, 472 by 380
-- units from its top left corner. The exe never names it. A run whose definition says board (the
-- Shooting Range, nightop/challenges.lua) shows its score there through nightop/run.lua's HUD, beside the card, which
-- shows it too. The widget keeps the game's place, font and colour; the mod sets its text, draws it at half size from
-- the top left corner and never lets it take the mouse. Built on the first score with the engine's CreateWidget
-- (WidgetBlueprintLibrary's Create; the class is looked up and, when not in memory, loaded then, never per tick),
-- collapsed while unused, built again once a map change took it. Every engine call runs in pcall on the game thread,
-- from the run's tick; the first error turns it off until the next Lua load, with one log line, and the card goes on
-- alone. tests/lua/nightop/board_test.lua covers it over fakes.
-- shortcut: a Lua reload (Ctrl+R) while it shows leaves that widget on screen until the next map change; sweep it by
-- its path as ui/kit.lua sweeps its root if a test shows it.
local U=require('core.unreal')
local Board={}
-- LoadAsset takes the Blueprint's object path (<package>.<asset>): UE4SS looks it up in the asset registry, where a
-- package path finds nothing.
local ASSET='/Game/Art/UI/Widget/Test/WB_ShootingTrainingTest.WB_ShootingTrainingTest'
local CLASS=ASSET..'_C'
local WIDGETS='/Script/UMG.Default__WidgetBlueprintLibrary'
local Z=99 -- Under the Uplink kit's root (ui/kit.lua's 100).
local COLLAPSED,HIT_TEST_INVISIBLE=1,3 -- ESlateVisibility.
-- o: {log=function(line)}.
function Board.new(o)
    local log=o.log
    local w,name,text,shown,off=nil,nil,nil,false,false
    -- The widget while it is still ours: a map change frees it, and its address may hold another object by then.
    local function alive()
        local x=w and U.valid(w)
        return x and U.text(x:GetFullName())==name and x or nil
    end
    -- The widget, built now if it is not there; nil while there is no player controller (a load).
    local function get()
        local x=alive()
        if x then return x end
        local pc=U.controller()
        if not pc then return nil end
        local class=U.valid(StaticFindObject(CLASS))
        if not class then
            pcall(LoadAsset,ASSET)
            class=assert(U.valid(StaticFindObject(CLASS)),'WB_ShootingTrainingTest is not in this game build')
        end
        x=assert(U.valid(U.find(WIDGETS):Create(pc,class,pc)),'CreateWidget gave nothing')
        w,name,text,shown=x,U.text(x:GetFullName()),nil,false
        x:SetVisibility(COLLAPSED)
        x:SetRenderTransformPivot({X=0,Y=0})
        x:SetRenderScale({X=0.5,Y=0.5})
        x:AddToViewport(Z)
        log('board: WB_ShootingTrainingTest shows the score')
        return x
    end
    local function run(f)
        if off then return end
        local ok,e=pcall(f)
        if ok then return end
        off=true
        log('board: off until the mod reloads ('..tostring(e)..'); the card still shows the score')
        pcall(function() local x=alive(); if x then x:RemoveFromParent() end end)
    end
    local self={}
    -- s: the text to show, or nil to hide it. The engine is called only on a change.
    function self.set(s)
        if s==nil then
            if shown then run(function() local x=alive(); if x then x:SetVisibility(COLLAPSED) end end) end
            shown=false
            return
        end
        run(function()
            local x=get()
            if not x then return end
            if s~=text then
                x.Score:SetText(FText(s))
                text=s
            end
            if not shown then
                x:SetVisibility(HIT_TEST_INVISIBLE)
                shown=true
            end
        end)
    end
    return self
end
return Board
