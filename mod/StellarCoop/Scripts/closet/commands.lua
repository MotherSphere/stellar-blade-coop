-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop closet: Stellar Closet's console words, on any save (nothing of it is saved). closet/wiring.lua builds it with
-- new(o) at each Lua load and main/loader.lua merges it into the command table. o: dress (closet/dress.lua's), fits
-- (closet/fits.lua), probe (closet/ui/probe.lua's), menu (a function giving closet/ui/menu.lua's, nil without the
-- Steam link: main/ui.lua builds it later).
--   coop closet [status]                              what is worn
--   coop closet wear <fit>[:<Slot>,<Slot>...] ...     pieces of one or more outfits by fit map; a fit alone wears
--                                                      every piece its pack shows by default (the outfit as is)
--   coop closet off                                   her own look back
--   coop closet fits                                  the fit maps and their pieces' slots
--   coop closet menu                                  opens the closet menu, or closes it with the look undone
--   coop closet probe <1-5|off>                       one in-game test of the game's widget parts (UE4SS.log)
local Dress=require('closet.dress')
local Probe=require('closet.ui.probe')
local Commands={}
-- main/commands.lua's M.run passes six words, nil-padded: an extra word is a first one that is not nil.
Commands.USE='Use: coop closet [status|wear <fit>[:<Slot>,...] ...|off|fits|menu|probe <1-5|off>]'
function Commands.new(o)
    local self={}
    function self.closet(sub,...)
        local extra=(...)~=nil
        if sub==nil or sub=='status' then
            if extra then return false,Commands.USE end
            return true,o.dress.status()
        elseif sub=='off' then
            if extra then return false,Commands.USE end
            return o.dress.off()
        elseif sub=='fits' then
            if extra then return false,Commands.USE end
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
            if not extra then return false,Dress.USE end
            local choices,why=Dress.parse({...})
            if not choices then return false,why end
            return o.dress.wear(choices)
        elseif sub=='menu' then
            if extra then return false,Commands.USE end
            local menu=o.menu and o.menu()
            if not menu then return false,'closet menu: the UI is not up (it needs the Steam link)' end
            if menu.is_open() then return menu.close('revert') end
            return menu.open()
        elseif sub=='probe' then
            local word=(...)
            if word==nil or select(2,...)~=nil then return false,Probe.USE end
            if word=='off' then return o.probe.off() end
            return o.probe.run(word)
        end
        return false,Commands.USE
    end
    return self
end
return Commands
