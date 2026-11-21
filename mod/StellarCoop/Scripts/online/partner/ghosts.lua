-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- One ghost per remote member past slot 0, in ghost slots 1 to 6 (slot 0 is main.lua's puppet): the members of a match
-- lobby or the guests of an online session of more than 2 players (on a guest, the host holds slot 0).
-- A slot's ghost is made the first time a member holds it, toggled on once and kept for the Lua load, so a member who
-- leaves and the next one in her slot share it: her table gone clears it, the next one's builds it again.
-- link: core/link.lua's (members(), slot(k), remote(k), vitals(id)). make(files, k, solo): a online/partner/puppet.lua
-- ghost on slot k's files; solo() is true while the member in slot k now has a solo area's zone type in her vitals.
-- sync() every 250 ms after link.changes(), tick() each frame before the native tick, place() after it, off() at coop
-- off, get(k) slot k's ghost (nil before a member held it: the HUD rows, the revive and the follow read it). Each
-- returns what the ghosts said, a {ok, message} each with its slot. A ghost that raises is said once a Lua
-- load for that call, and the other ghosts still run.
local Link=require('core.link')
local Ghosts={}
local SLOTS=6
function Ghosts.new(link,make)
    local self,ghosts,raised,current={},{},{},nil
    local function traced(e) return raised[current] and e or debug.traceback(e,2) end
    local function call(out,k,name,...)
        current=name..k
        local ran,ok,message=xpcall(ghosts[k][name],traced,...)
        if not ran then
            if raised[current] then return end
            raised[current]=true
            ok,message=false,'error (said once until the mod reloads): '..tostring(ok)
        end
        if message then out[#out+1]={ok,'slot '..k..': '..tostring(message)} end
    end
    local function each(name)
        local out={}
        for k=1,SLOTS do if ghosts[k] then call(out,k,name) end end
        return out
    end
    function self.sync()
        local out={}
        for _,m in ipairs(link.members()) do
            local k=m.slot
            if k>=1 and k<=SLOTS and not ghosts[k] then
                ghosts[k]=make(link.slot(k),k,function()
                    for _,held in ipairs(link.members()) do
                        if held.slot==k then return Link.solo((link.vitals(held.id) or {}).zone) end
                    end
                    return false
                end)
                call(out,k,'toggle')
            end
        end
        for k=1,SLOTS do if ghosts[k] then call(out,k,'remote',link.remote(k)) end end
        return out
    end
    function self.get(k) return ghosts[k] end
    function self.tick() return each('tick') end
    function self.place() return each('place') end
    function self.off()
        local out={}
        for k=1,SLOTS do if ghosts[k] and ghosts[k].active() then call(out,k,'toggle') end end
        return out
    end
    return self
end
return Ghosts
