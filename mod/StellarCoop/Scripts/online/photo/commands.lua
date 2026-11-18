-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The photo pause's console command: coop freeze, the photo pause alone. online/photo/wiring.lua builds it with new(o)
-- at each Lua load and main/loader.lua merges it into the command table. o: native_tick (nil without the native part)
-- and ask (a line for the native part).
local Photo={}
local function whole(text,max) -- A whole number from 0 to max, or nil.
    local n=type(text)=='string' and text:match('^%d+$') and tonumber(text)
    return n and n<=max and n or nil
end
function Photo.new(o)
    local native_tick,ask=o.native_tick,o.ask
    local self={}
    -- The photo pause alone (the solo tests): our pause tag held for 1 to 3600 s, or until off; the native part refuses
    -- it off the pinned build and says why in the log.
    function self.freeze(arg,extra)
        local seconds=arg~='off' and whole(arg,3600)
        if extra~=nil or not (arg=='off' or seconds and seconds>0) then
            return false,'Use: coop freeze <1-3600 seconds> | off'
        end
        if not native_tick then return false,'the native tick is unavailable' end
        return ask(seconds and 'freeze '..seconds or 'freeze off')()
    end
    return self
end
return Photo
