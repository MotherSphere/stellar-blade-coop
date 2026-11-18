-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A table row edited in place and read back, moved out of online/modes/nightop/recruiter.lua for every module to read.
local U=require('core.unreal')
local why=U.why
local function find_name(text) return FName(text,EFindName.FNAME_Find) end -- None (index 0) when not a name yet.
local function index_of(name) return U.value_of(name):GetComparisonIndex() end
local function one(...) local set={}; for _,v in ipairs({...}) do set[v]=true end; return set end
-- Engine text in a log line: printable ASCII, any other byte as \xNN, so the line reads the same whatever encoding the
-- log gets under Proton, and a mangled string shows its bytes. ascii() keeps at most 80 bytes; a field read back keeps
-- all of them, since a path that differs may differ at its end.
local function escaped(s)
    return (tostring(s):gsub('[^ -~]',function(c) return string.format('\\x%02X',c:byte()) end))
end
local function ascii(s) return escaped(tostring(s):sub(1,80)) end
-- A field as compared and as shown: a number or boolean as is; an FName by comparison index ('#i'); an FString or
-- FText as text (shown escaped); an FName list as its indexes joined (shown '{text,...}'). A read that
-- raises gives nil and its error.
local function get(row,field,kind)
    local ok,v,shown=pcall(function()
        local x=U.value_of(row[field])
        if kind=='name' then local i=index_of(x); return i,'#'..i end
        if kind=='text' then local t=U.text(x); return t,escaped(t) end
        if kind=='list' then
            local ids,texts={},{}
            U.each(assert(x,'no field'),function(_,n) ids[#ids+1]=index_of(n); texts[#texts+1]=U.text(n) end)
            return table.concat(ids,','),'{'..table.concat(texts,',')..'}'
        end
        return x,tostring(x)
    end)
    if not ok then return nil,'?('..why(v)..')' end
    return v,shown
end
local KNOWN,DIFFERS='%s is not the row we know at %s (%s): no recruiter','%s read back differs at %s (%s): no recruiter'
-- Those two lines for another user of edit() (online/modes/nightop/roxanne.lua): what stops instead of the recruiter.
local function lines_for(what)
    if not what then return KNOWN,DIFFERS end
    return (KNOWN:gsub('no recruiter$','no '..what)),(DIFFERS:gsub('no recruiter$','no '..what))
end
local function check(key,row,checks,line,old) -- checks: {field, kind, set of accepted values}.
    for _,c in ipairs(checks) do
        local v,shown=get(row,c[1],c[2])
        if v==nil or not c[3][v] then return string.format(line,key,c[1],shown) end
        if old then old[c[1]]=v end
    end
end
-- One row edited in place: checked (else nothing is written), written field by field, then read back through a fresh
-- FindRow, so a copy-returning FindRow or a write that does not stick stops here. writes: {field, kind, value, value
-- as compared when it differs}; keep: checks run again on the fresh row; what: what stops (the recruiter when nil).
-- Gives the STOP line, or nil and the values read before.
local function edit(path,key,known,writes,keep,what)
    local known_line,differs_line=lines_for(what)
    local dt=U.find(path)
    local row=dt:FindRow(key)
    if row==nil then return string.format(known_line,key,'row','absent') end
    local old={}
    local stop=check(key,row,known,known_line,old)
    if stop then return stop end
    local back={}
    for _,w in ipairs(writes) do
        local ok,e=pcall(function() row[w[1]]=w[3] end) -- An unsupported field type stops with its name.
        if not ok then return string.format(differs_line,key,w[1],why(e)) end
        local want=w[4]
        if want==nil then want=w[3] end
        back[#back+1]={w[1],w[2],one(want)}
    end
    for _,c in ipairs(keep or {}) do back[#back+1]=c end
    return check(key,dt:FindRow(key),back,differs_line),old
end
return {edit=edit,one=one,find_name=find_name,index_of=index_of,ascii=ascii,get=get}
