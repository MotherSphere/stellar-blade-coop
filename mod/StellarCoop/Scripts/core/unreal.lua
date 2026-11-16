-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Helpers over UE4SS objects, shared by the capture (partner/capture.lua), the ghost (partner/puppet.lua) and the
-- game-side scripts (nightop/run.lua, session/group.lua), with the game's own words (game_text) for the Lua screens.
local U={}
-- Made once: a function made in each call was 80 B of garbage, twice per U.valid. The method is looked up inside the
-- pcall, so an object whose __index raises still gives nil (pcall(value.type,value) would raise out of U.kind).
local function type_of(value) return value:type() end
function U.kind(value)
    if type(value)~='userdata' and type(value)~='table' then return nil end
    local ok,result=pcall(type_of,value)
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
-- StaticFindObject finds an object in memory at once, but a path that is not in memory cost 4 to 35 ms a call in game
-- (2026-10-24, more as the session loads more): each path is looked up once while its object lives.
local found={}
function U.find(path)
    local object=U.valid(found[path])
    if not object then
        object=assert(U.valid(StaticFindObject(path)),path..' is unavailable in this game build.')
        found[path]=object
    end
    return object
end
-- The class at path while it is in memory, else nil, and the route ('soft path', or 'walk' with the reason the soft
-- path is not used). The soft path asks the engine, which finds the class by its name hash and never loads anything
-- (execConv_SoftClassReferenceToClass 0x14482c370 calls FSoftObjectPath::ResolveObject 0x142b82f40, then
-- StaticFindObject 0x142b957b0, whose ResolveName 0x142b96d70 creates and loads nothing when asked not to; build
-- 26123051). UE4SS's StaticFindObject walks the object array: 25 to 35 ms in game for a path not in memory, and a
-- class loaded with the map can sit far down the array. Proven once a Lua load: the pawn's class must come back by its
-- own path. Until there is a pawn, and for good if that fails, StaticFindObject as before.
local soft_ok,soft_why=nil,nil
local function soft(path)
    local k=U.find('/Script/Engine.Default__KismetSystemLibrary')
    return U.valid(k:Conv_SoftClassReferenceToClass(k:Conv_SoftClassPathToSoftClassRef(k:MakeSoftClassPath(path))))
end
function U.class_at(path,ctx)
    local pawn=soft_ok==nil and ctx and U.valid(ctx:K2_GetPawn())
    if pawn then
        local cls=U.valid(pawn:GetClass())
        local ok,back=pcall(soft,U.text(cls:GetFullName()):match('^%S+ (.+)$'))
        soft_ok=ok and back~=nil and U.address(back)==U.address(cls)
        if not soft_ok then
            soft_why=ok and 'its pawn class came back as '..(back and U.hex(back) or 'nil') or tostring(back)
        end
    end
    if soft_ok then return soft(path),'soft path' end
    return U.valid(StaticFindObject(path)),soft_why and 'walk ('..soft_why..')' or 'walk'
end
-- The player controller while it is one: UEHelpers keeps its last one while that address is valid, and after a map
-- change the address may hold another object (an input mode set on that one is a native fault).
function U.controller()
    local pc=U.valid(require('UEHelpers').GetPlayerController())
    return pc and pc:IsA(U.find('/Script/Engine.PlayerController')) and pc or nil
end
-- The actors of class cls (a class object; name, its short name) in ctx's world, subclasses included, through
-- UGameplayStatics::GetAllActorsOfClass, which reads the engine's class hash in a fraction of a millisecond, where
-- FindAllOf walks every object (25 to 80 ms in game, a frozen frame). Proven once a Lua load: the hash must give at
-- least one PlayerController when FindAllOf gives one (UE4SS fills the out array); until then, and for good if it
-- does not, each call walks with FindAllOf(name) as before. Returns the list and the route ('class hash' or 'walk').
local hash_ok=nil
local function hashed(cls,ctx)
    local out,list={},{}
    U.find('/Script/Engine.Default__GameplayStatics'):GetAllActorsOfClass(ctx,cls,out)
    U.each(out,function(_,a) a=U.valid(a); if a then list[#list+1]=a end end)
    return list
end
function U.actors_of(cls,name,ctx)
    if hash_ok==nil and ctx then
        local walked=0
        U.each(FindAllOf and FindAllOf('PlayerController') or {},function(_,pc)
            if U.valid(pc) then walked=walked+1 end
        end)
        if walked>0 then
            local ok,list=pcall(hashed,U.find('/Script/Engine.PlayerController'),ctx)
            hash_ok=ok and #list>0
        end
    end
    if hash_ok and ctx then
        local ok,list=pcall(hashed,cls,ctx)
        if ok then return list,'class hash' end
    end
    local list={}
    U.each(FindAllOf and FindAllOf(name) or {},function(_,a) a=U.valid(a); if a then list[#list+1]=a end end)
    return list,'walk'
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
-- used with permission given on 2026-10-20 and licensed here under the SBO License (NOTICE).
function U.death_screen()
    local found=nil
    U.each(FindAllOf('WB_MainHUD_Master_C') or {},function(_,m)
        m=not found and U.valid(m)
        if m and U.text(m:GetFullName()):find('GameEngine',1,true) then found=U.valid(m.WB_MainHUD_Dead) end
    end)
    return found
end
-- The game's text for a StringTable_UI key in its own language, as its menus show it; nil while that table is not
-- loaded or its id not a name (nothing is called then, so nothing loads it) or the key not registered, or on any error.
local STRINGS='/Game/Local/Localize/StringTable_UI.StringTable_UI'
function U.game_text(key)
    local ok,text=pcall(function()
        if not U.valid(StaticFindObject(STRINGS)) then return nil end
        local id=FName(STRINGS,EFindName.FNAME_Find)
        if id:GetComparisonIndex()==0
            or not U.find('/Script/Engine.Default__KismetStringTableLibrary'):IsRegisteredTableEntry(id,key) then
            return nil
        end
        return U.text(U.find('/Script/Engine.Default__KismetTextLibrary'):TextFromStringTable(id,key))
    end)
    return ok and text~='' and text or nil
end
-- An error's message without the file and line.
function U.why(e) return (tostring(e):gsub('^.-:%d+: ','')) end
-- The distance in metres between two points in cm.
function U.metres(a,b) return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)/100 end
-- The pawn when it is EVE (an SBCharacter), else nil.
function U.her(pawn) return pawn and pawn:IsA(U.find('/Script/SB.SBCharacter')) and pawn or nil end
-- The yaw in degrees that turns something at from towards to (a TextRender's text reads from its +X side).
function U.yaw_to(from,to) return math.deg(math.atan(to.Y-from.Y,to.X-from.X)) end
return U
