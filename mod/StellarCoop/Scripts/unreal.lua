-- Helpers over UE4SS objects, shared by the capture (capture.lua) and the ghost (puppet.lua).
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
function U.address(object) return U.value_of(object):GetAddress() end
function U.hex(object) return string.format('0x%x',U.address(object)) end
-- A word of the component table (native/src/pose_table.h): printable ASCII, '_' for any other byte, at most max bytes
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
return U
