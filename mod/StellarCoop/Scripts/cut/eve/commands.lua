-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- EVE's cut moves' console commands: coop wear, coop emote, coop fly, coop slowmo, coop glide and coop chainspin.
-- cut/eve/wiring.lua builds it with new(o) at each Lua load and main/loader.lua merges it into the command table. o:
-- coop_slot, wear (cut/eve/wear.lua's), flight (cut/eve/flight.lua's keys for coop fly), chainspin
-- (cut/eve/chainspin.lua's), glide (cut/eve/glide.lua's), ask (a native request; coop fly and coop slowmo) and riding
-- (main/base.lua's riding, read at each call: EVE rides the bike). coop chainspin, EVE's cut Tachy Mode ChainSpin (a
-- test tool, left out of the usage line), runs on a co-op save only. coop emote, one of EVE's clips (cut/eve/emote.lua,
-- o.emote), runs on any save.
local Eve={}
function Eve.new(o)
    local coop_slot=o.coop_slot
    local self={}
    -- coop wear (cut/eve/wear.lua, o.wear): every word to it, on any save, as nothing of it is saved.
    function self.wear(...) return o.wear.command(...) end
    -- coop emote (cut/eve/emote.lua, o.emote): every word to it, on any save, as nothing of it is saved.
    function self.emote(...) return o.emote.command(...) end
    -- coop fly and coop slowmo (the native part's cut/debug_keys.h, test tools left out of the usage line): SB's
    -- developer flight and slow motion. on is asked on a co-op save only, off anywhere; coop off and the next Lua load
    -- end both in the native part. coop fly on is refused while EVE rides the bike: its R2 is the bike's drift key.
    local RIDING='EVE rides the bike: coop bike gets her off first'
    for _,name in ipairs({'fly','slowmo'}) do
        self[name]=function(sub,a)
            if a~=nil or sub~='on' and sub~='off' then return false,'Use: coop '..name..' on|off' end
            local ok,why=true,nil
            if sub=='on' then ok,why=coop_slot('coop '..name..' on') end
            if not ok then return false,why end
            if sub=='on' and name=='fly' and o.riding and o.riding() then return false,RIDING end
            ok,why=o.ask(name..' '..sub)()
            if name=='fly' and o.flight then -- Its keys: R2 only flies, Shift with a direction evades.
                if sub=='off' then o.flight.off() elseif ok then why=tostring(why)..'; '..o.flight.on() end
            end
            return ok,why
        end
    end
    -- coop glide (cut/eve/glide.lua, o.glide, a test tool left out of the usage line): EVE's cut glide, on asked on a
    -- co-op save only, off anywhere (cut/eve/glide.lua checks the save again once a second while on). on is refused
    -- while EVE rides the bike: Jump stays SB's in the saddle.
    function self.glide(sub,extra)
        if sub=='on' and extra==nil then
            local ok,why=coop_slot('coop glide on')
            if not ok then return false,why end
            if o.riding and o.riding() then return false,RIDING end
        end
        return o.glide.command(sub,extra)
    end
    function self.chainspin(extra)
        local ok,why=coop_slot('coop chainspin')
        if not ok then return false,why end
        return o.chainspin.command(extra)
    end
    return self
end
return Eve
