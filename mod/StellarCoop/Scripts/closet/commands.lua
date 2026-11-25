-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop closet: Stellar Closet's console words, on any save (nothing of it is saved). closet/wiring.lua builds it with
-- new(o) at each Lua load and main/loader.lua merges it into the command table. o: dress (closet/dress.lua's), fits
-- (closet/fits.lua).
--   coop closet [status]                              what is worn
--   coop closet wear <fit>[:<Slot>,<Slot>...] ...     pieces of one or more outfits by fit map; a fit alone wears
--                                                      every piece its pack shows by default (the outfit as is)
--   coop closet off                                   her own look back
--   coop closet fits                                  the fit maps and their pieces' slots
local Dress=require('closet.dress')
local Commands={}
Commands.USE='Use: coop closet [status|wear <fit>[:<Slot>,...] ...|off|fits]'
function Commands.new(o)
    local self={}
    function self.closet(sub,...)
        if sub==nil or sub=='status' then
            if select('#',...)>0 then return false,Commands.USE end
            return true,o.dress.status()
        elseif sub=='off' then
            if select('#',...)>0 then return false,Commands.USE end
            return o.dress.off()
        elseif sub=='fits' then
            if select('#',...)>0 then return false,Commands.USE end
            local lines={}
            local ids={}
            for id in pairs(o.fits.BY_ID) do ids[#ids+1]=id end
            table.sort(ids)
            for _,id in ipairs(ids) do
                local slots={}
                for _,piece in ipairs(o.fits.BY_ID[id].Pieces) do slots[#slots+1]=piece.Slot end
                lines[#lines+1]=id..': '..table.concat(slots,',')
            end
            return true,#lines>0 and table.concat(lines,'\n') or 'closet: no fit maps'
        elseif sub=='wear' then
            if select('#',...)==0 then return false,Dress.USE end
            local choices,why=Dress.parse({...})
            if not choices then return false,why end
            return o.dress.wear(choices)
        end
        return false,Commands.USE
    end
    return self
end
return Commands
