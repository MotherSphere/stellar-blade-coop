-- Helpers over UE4SS objects, shared by the capture (partner/capture.lua), the ghost (partner/puppet.lua) and the
-- game-side scripts (nightop/run.lua, session/group.lua).
local U={}
function U.kind(value)
    if type(value)~='userdata' and type(value)~='table' then return nil end
    local ok,result=pcall(function() return value:type() end)
    return ok and result or nil
end
-- UE4SS may wrap values as RemoteUnrealParam/LocalUnrealParam; open them before use.
function U.value_of(value)
    for _=1,3 do
        local k=U.kind(value)
        if k~='RemoteUnrealParam' and k~='LocalUnrealParam' then return value end
        value=value:get()
    end
    return value
end
function U.valid(object)
    object=U.value_of(object)
    return object~=nil and U.kind(object)~=nil and object:IsValid() and object or nil
end
-- A TWeakObjectPtr property's object (UE4SS gives the pointer, whose Get() reads it), or nil.
function U.weak(v)
    v=U.value_of(v)
    local kind=U.kind(v)
    if kind and kind:find('Weak',1,true) then v=v:Get() end
    return U.valid(v)
end
-- Arrays arrive as converted Lua lists or TArray userdata; elements may be wrapped.
function U.each(array,callback)
    array=U.value_of(array)
    if array==nil then return end
    if type(array)=='table' and rawget(array,'ForEach')==nil then
        for index,value in ipairs(array) do callback(index,U.value_of(value)) end
        return
    end
    array:ForEach(function(index,element) callback(index,U.value_of(element:get())) end)
end
function U.text(name)
    name=U.value_of(name)
    return type(name)=='string' and name or name:ToString()
end
-- StaticFindObject costs about 4 ms a call in this build: each path is looked up once while its object lives.
local found={}
function U.find(path)
    local object=U.valid(found[path])
    if not object then
        object=assert(U.valid(StaticFindObject(path)),path..' is unavailable in this game build.')
        found[path]=object
    end
    return object
end
-- The player controller while it is one: UEHelpers keeps its last one while that address is valid, and after a map
-- change the address may hold another object (an input mode set on that one is a native fault).
function U.controller()
    local pc=U.valid(require('UEHelpers').GetPlayerController())
    return pc and pc:IsA(U.find('/Script/Engine.PlayerController')) and pc or nil
end
function U.address(object) return U.value_of(object):GetAddress() end
function U.hex(object) return string.format('0x%x',U.address(object)) end
-- A word of the component table (native/src/pose/table.h): printable ASCII, '_' for any other byte, at most max bytes
-- (64 unless said), '-' when empty.
function U.word(value,max)
    local w=tostring(value or ''):gsub('[^!-~]','_'):sub(1,max or 64)
    return w~='' and w or '-'
end
-- The package path of the world an actor is in, lowercased (FName casing depends on who registered it first), as the
-- table's map line takes it: '/game/art/bg/worldmap/level_p/e04'.
function U.map_of(actor)
    local full=U.text(actor:GetWorld():GetFullName())
    local map=(full:match('^%S+ ([^.:]+)') or '/'):lower():gsub('[^a-z0-9_/%-]','_')
    if map:sub(1,1)~='/' then map='/'..map end
    return map:sub(1,128)
end
-- A line of text on an actor (a TextRenderComponent, its root when it is the first component): centred, white, size
-- in cm. Its rotation is the world's, so it can be turned to the camera whatever its parent does.
function U.label(actor,size)
    local identity=U.find('/Script/Engine.Default__KismetMathLibrary'):MakeTransform({X=0,Y=0,Z=0},
        {Pitch=0,Yaw=0,Roll=0},{X=1,Y=1,Z=1})
    local label=U.valid(actor:AddComponentByClass(U.find('/Script/Engine.TextRenderComponent'),false,identity,false))
    assert(label,'a text line could not be added')
    local ok,why=pcall(function()
        label:SetWorldSize(size)
        label:SetHorizontalAlignment(1) -- EHTA_Center
        label:SetTextRenderColor({R=255,G=255,B=255,A=255})
        label:SetAbsolute(false,true,false)
    end)
    if not ok then -- Else a half-made line stays on the actor, reading the engine's 'Text'.
        pcall(function() label:K2_DestroyComponent(actor) end)
        error(why,0)
    end
    return label
end
-- The live HUD's death screen (the copy under GameEngine), whose animation plays from EVE's death on and none while she
-- lives; nil when not found. FindAllOf walks every object: its callers keep what it returns and look again only while
-- it is gone. Adapted from Survival Protocol's death watch, by SchizoEffective (nexusmods.com/stellarblade/mods/4009),
-- used with permission given on 2026-10-20 and distributed here under GPL-3.0-or-later.
function U.death_screen()
    local found=nil
    U.each(FindAllOf('WB_MainHUD_Master_C') or {},function(_,m)
        m=not found and U.valid(m)
        if m and U.text(m:GetFullName()):find('GameEngine',1,true) then found=U.valid(m.WB_MainHUD_Dead) end
    end)
    return found
end
-- The yaw in degrees that turns something at from towards to (a TextRender's text reads from its +X side).
function U.yaw_to(from,to) return math.deg(math.atan(to.Y-from.Y,to.X-from.X)) end
return U
