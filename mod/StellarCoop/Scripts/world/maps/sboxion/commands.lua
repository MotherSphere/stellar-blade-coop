-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop xion (a test tool left out of the usage line, needing the zSBO_Xion test pak): SB's URL warp into SBO Xion at
-- the city point, coop xion gate at the gate point, coop xion leave its way out, coop xion status its status line,
-- coop xion recover [on|death|off] the mode of its recovery after a fall or a death, coop xion rooms [on|off] SB's
-- pieces put back in the doorways of its rooms or hidden again and coop xion tetrapod [in|out] EVE put inside the
-- Tetrapod or back in front of it. coop xion tetrapod probe [<n>|only <n>] looks for the ship's part that kills her.
-- coop xion npc [<n> | turn <degrees>] sets the clip or the turn of the NPC nearest to EVE
-- (world/maps/sboxion/sboxion.lua, o.xion; nil without the Steam link).
-- world/maps/sboxion/wiring.lua builds it with new(o) at each Lua load and main/loader.lua merges it into the command
-- table.
local Commands={}
local USE='Use: coop xion [city|gate|leave|status|recover [on|death|off]|rooms [on|off]'
    ..'|tetrapod [in|out|probe [<n>|only <n>]]|npc [<n>|turn <degrees>]]'
local MODE={on=true,death=true,off=true}
local SWITCH={on=true,off=true}
local WAY={['in']=true,out=true}
function Commands.new(o)
    local self={}
    function self.xion(sub,extra,more,last,over)
        if sub=='npc' then
            if not o.xion then return false,'coop xion needs the Steam link and the native part' end
            return o.xion.npc(extra,more)
        end
        if sub=='tetrapod' and extra=='probe' then -- Its words are the module's to check.
            if not o.xion then return false,'coop xion needs the Steam link and the native part' end
            return o.xion.tetrapod(extra,more,last,over)
        end
        local second=sub=='recover' and MODE[extra] or sub=='rooms' and SWITCH[extra] or sub=='tetrapod' and WAY[extra]
        if more~=nil or extra~=nil and not second then return false,USE end
        if not o.xion then return false,'coop xion needs the Steam link and the native part' end
        if sub=='recover' then return o.xion.recover(extra) end
        if sub=='rooms' then return o.xion.rooms(extra) end
        if sub=='tetrapod' then return o.xion.tetrapod(extra) end
        if sub=='status' then return o.xion.status() end
        if sub=='leave' then return o.xion.leave() end
        if sub==nil or sub=='city' or sub=='gate' then return o.xion.enter(sub or 'city') end
        return false,USE
    end
    return self
end
return Commands
