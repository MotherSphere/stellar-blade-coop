-- The cut shooting test's score widget (nightop/board.lua) over strict fakes: an object raises on a member it does not
-- declare and every call is recorded. Covered: nothing called before a first score or while there is no player
-- controller; the class loaded once when it is not in memory, the widget made with CreateWidget for the player
-- controller, collapsed, drawn at half size from its top left corner and added to the viewport under the kit, then its
-- Score text set and the widget shown so that it takes no mouse; the engine called again only on a change; hidden and
-- shown again with the same text; built again once a map change freed it or its address holds another object; the
-- first error turns it off with one log line and takes the widget off the screen; a class the build lacks and a
-- CreateWidget that gives nothing turn it off before any widget call.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local calls={}
local function record(what,...) calls[#calls+1]={what=what,args=table.pack(...)} end
local function names() local out={}; for i,c in ipairs(calls) do out[i]=c.what end; return table.concat(out,' ') end
local function strict(tag,full,methods,fields)
    local state={valid=true,full=full}
    methods.type=function() return 'UObject' end
    methods.IsValid=function() return state.valid end
    methods.GetFullName=function() return state.full end
    local o=setmetatable({},{__index=function(_,key)
        local m=methods[key]
        if m then
            return function(_,...)
                if key~='type' and key~='IsValid' and key~='GetFullName' then record(tag..':'..key,...) end
                return m(_,...)
            end
        end
        if fields and fields[key]~=nil then return fields[key] end
        error(tag..' has no '..tostring(key),2)
    end,__newindex=function(_,key) error('wrote '..tostring(key)..' on '..tag,2) end})
    return o,state
end
local PCClass=strict('Class','Class /Script/Engine.PlayerController',{})
local pc=strict('PC','PlayerController /Game/Map.Map:PersistentLevel.PC_0',{IsA=function(_,c) return c==PCClass end})
local player_controller=nil
package.loaded.UEHelpers={GetPlayerController=function() return player_controller end}
local missing=setmetatable({},{__index=function(_,k)
    if k=='type' then return function() return 'UObject' end end
    if k=='IsValid' then return function() return false end end
    error('missing has no '..k)
end})
local made,raise_on,create_gives={},nil,nil
-- A widget as CreateWidget makes it: its Score text and the calls the board makes; raise_on names one that raises.
local function widget(n)
    local text={}
    local score=strict('Score','TextBlock /Engine/Transient.WB_'..n..'.Score',{SetText=function(_,t)
        if raise_on=='SetText' then error('text refused',0) end
        text.now=t.text
    end})
    local methods={}
    for _,m in ipairs({'SetVisibility','SetRenderTransformPivot','SetRenderScale','AddToViewport',
            'RemoveFromParent'}) do
        methods[m]=function() if raise_on==m then error(m..' refused',0) end end
    end
    local w,state=strict('W'..n,'WB_ShootingTrainingTest_C /Engine/Transient.WB_ShootingTrainingTest_C_'..n,methods,
        {Score=score})
    made[n]={w=w,state=state,text=text}
    return w
end
local class_in_memory,class_in_build=false,true
local CLASS='/Game/Art/UI/Widget/Test/WB_ShootingTrainingTest.WB_ShootingTrainingTest_C'
local class=strict('WBClass','WidgetBlueprintGeneratedClass '..CLASS,{})
local library=strict('WBL','WidgetBlueprintLibrary',{Create=function(_,context,cls,owner)
    assert(context==pc and cls==class and owner==pc,'CreateWidget for the player controller')
    if create_gives then return create_gives end
    return widget(#made+1)
end})
StaticFindObject=function(path)
    record('StaticFindObject',path)
    if path=='/Script/Engine.PlayerController' then return PCClass end
    if path=='/Script/UMG.Default__WidgetBlueprintLibrary' then return library end
    assert(path==CLASS,'unexpected StaticFindObject '..path)
    return class_in_memory and class or missing
end
-- UE4SS's LoadAsset looks its argument up in the asset registry by object path (<package>.<asset>): a package path
-- finds nothing and loads nothing.
LoadAsset=function(path)
    record('LoadAsset',path)
    assert(path=='/Game/Art/UI/Widget/Test/WB_ShootingTrainingTest.WB_ShootingTrainingTest','LoadAsset '..path)
    if class_in_build then class_in_memory=true end
end
FText=function(s) return {text=s} end
local lines={}
local Board=require('nightop.board')
local board=Board.new({log=function(text) lines[#lines+1]=text end})

-- Nothing before a first score, nor while there is no player controller (a load).
board.set(nil)
assert(#calls==0)
board.set('SCORE 0')
assert(#calls==0 and #lines==0,names())
-- The first score: the class loaded once, the widget built and set up, its text set and shown.
player_controller=pc
board.set('SCORE 0')
assert(names()=='StaticFindObject PC:IsA StaticFindObject LoadAsset StaticFindObject StaticFindObject WBL:Create '
    ..'W1:SetVisibility W1:SetRenderTransformPivot W1:SetRenderScale W1:AddToViewport Score:SetText W1:SetVisibility',
    names())
local function args(i) return calls[i].args end
assert(args(8)[1]==1 and args(9)[1].X==0 and args(9)[1].Y==0 and args(10)[1].X==0.5 and args(10)[1].Y==0.5)
assert(args(11)[1]==99 and args(13)[1]==3 and made[1].text.now=='SCORE 0')
assert(#lines==1 and lines[1]=='board: WB_ShootingTrainingTest shows the score',lines[1])
-- The same text: no call; a new one: SetText alone.
calls={}
board.set('SCORE 0')
assert(#calls==0,names())
board.set('SCORE 40')
assert(names()=='Score:SetText' and made[1].text.now=='SCORE 40',names())
-- Hidden once, then shown again with the text it holds.
calls={}
board.set(nil)
board.set(nil)
assert(names()=='W1:SetVisibility' and args(1)[1]==1,names())
calls={}
board.set('SCORE 40')
assert(names()=='W1:SetVisibility' and args(1)[1]==3,names())
-- A map change freed it: built again, the class now in memory (no load), the text set on the new one.
made[1].state.valid=false
calls={}
board.set('SCORE 40')
assert(names()=='PC:IsA StaticFindObject WBL:Create W2:SetVisibility W2:SetRenderTransformPivot W2:SetRenderScale '
    ..'W2:AddToViewport Score:SetText W2:SetVisibility' and made[2].text.now=='SCORE 40',names())
-- Its address now holds another object: built again too.
made[2].state.full='SBCharacter /Game/Map.Map:PersistentLevel.Other_1'
calls={}
board.set('SCORE 80')
assert(#made==3 and made[3].text.now=='SCORE 80',names())
-- The first error: off with one line, the widget taken off the screen, nothing called after.
raise_on='SetText'
calls={}
board.set('SCORE 120')
assert(names()=='Score:SetText W3:RemoveFromParent',names())
assert(#lines==4 and lines[4]=='board: off until the mod reloads (text refused); the card still shows the score',
    lines[4])
raise_on=nil
calls={}
board.set('SCORE 160')
board.set(nil)
assert(#calls==0 and #lines==4,names())

-- A build without the class: the load is tried once, then off before any widget call.
class_in_memory,class_in_build=false,false
calls,lines={},{}
board=Board.new({log=function(text) lines[#lines+1]=text end})
board.set('SCORE 0')
assert(names()=='PC:IsA StaticFindObject LoadAsset StaticFindObject',names())
assert(lines[1]:find('^board: off until the mod reloads %(.*WB_ShootingTrainingTest is not in this game build%)'),
    lines[1])
board.set('SCORE 0')
assert(#lines==1)
-- CreateWidget that gives nothing: off, and no widget is touched.
class_in_memory,create_gives=true,missing
calls,lines={},{}
board=Board.new({log=function(text) lines[#lines+1]=text end})
board.set('SCORE 0')
assert(names()=='PC:IsA StaticFindObject WBL:Create',names())
assert(lines[1]:find('CreateWidget gave nothing',1,true),lines[1])
print('board_test: ok')
