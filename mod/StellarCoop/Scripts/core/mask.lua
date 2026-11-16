-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A line as UE4SS.log keeps it (main.lua's print), since players post it in public with their bug reports: the same
-- rule as link/protocol.h's masked() for coop-link.log and coop-report.txt. A SteamID (a run of 17 or 18 digits with
-- universe 1 and an individual or chat account type) becomes *** and its last 4 digits. A join code as the native part
-- writes it (capitals, with a check that matches) becomes its first 3 characters and ****, as does a lobby id with a
-- join code. A lobby id keeps none of its digits: its last 4 beside its code's first 3 would leave about 100
-- lobbies to try.
local DIGITS='0123456789ABCDEFGHJKMNPQRSTVWXYZ' -- link/protocol.h's kCodeDigits.
local CODE_HIGH=0x01860000

local function id(run)
    if #run~=17 and #run~=18 then return nil end
    local n=math.tointeger(tonumber(run))
    local kind=n>>52
    if kind~=0x011 and kind~=0x018 then return nil end
    if n>>32~=CODE_HIGH then return '***'..run:sub(-4) end
    local low=n&0xffffffff
    local value=(low%7)<<32|low -- link/protocol.h's join_code(): only its first 3 characters are kept.
    local first=''
    for shift=30,20,-5 do
        local at=(value>>shift&31)+1
        first=first..DIGITS:sub(at,at)
    end
    return first..'-****'
end

local function code(text)
    local value=0
    for c in (text:sub(1,3)..text:sub(5)):gmatch('.') do
        local at=DIGITS:find(c,1,true)
        if not at then return nil end
        value=value*32+at-1
    end
    if value>>32==(value&0xffffffff)%7 then return text:sub(1,3)..'-****' end
end

return function(text)
    return (text:gsub('%f[%w]%d+%f[%W]',id):gsub('%f[%w]%w%w%w%-%w%w%w%w%f[%W]',code))
end
