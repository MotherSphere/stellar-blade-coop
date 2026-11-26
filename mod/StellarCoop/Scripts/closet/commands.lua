-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop closet: Stellar Closet's console words, on any save (nothing of it is saved). closet/wiring.lua builds it with
-- new(o) at each Lua load and main/loader.lua merges it into the command table. o: dress (closet/dress.lua's), fits
-- (closet/fits.lua), probe (closet/ui/probe.lua's), menu (a function giving closet/ui/menu.lua's, nil without the
-- Steam link: main/ui.lua builds it later), thumbs (closet/thumbs.lua's), colour (closet/colour.lua's), shape
-- (closet/shape.lua's).
--   coop closet [status]                              what is worn
--   coop closet wear <fit>[:<Slot>,<Slot>...] ...     pieces of one or more outfits by fit map; a fit alone wears
--                                                      every piece its pack shows by default (the outfit as is)
--   coop closet off                                   her own look back
--   coop closet fits                                  the fit maps and their pieces' slots
--   coop closet menu                                  opens the closet menu, or closes it with the look undone
--   coop closet thumbs [redo] [<fit>]                 a picture of each piece of every installed outfit (or one),
--                                                      the ones not cached yet, or all again with redo
--   coop closet probe <1-6|off>                       one in-game test of the game's widget parts or reads (UE4SS.log)
--   coop closet body <auto|shoes|first|<fit>>         the body rule of the next wears in this Lua load (dress.lua)
--   coop closet skin <fit> <slot> on|off              shows or hides one material slot of that outfit's mesh now,
--                                                      until the next wear (for trying setups in game)
--   coop closet colour <role> <swatch|off>            one role's colour on every worn piece (closet/colour.lua),
--                                                      kept in coop-closet-colour.txt
--   coop closet colour off                            every role back to the packs' own colours
--   coop closet shape <morph> <0-100>                 one body shape value in % (steps of 10) on the worn meshes
--                                                      (closet/shape.lua), kept in coop-closet-shape.txt
--   coop closet shape off                             every body shape value back to 0
local Dress=require('closet.dress')
local Probe=require('closet.ui.probe')
local Colour=require('closet.colour')
local Shape=require('closet.shape')
local Commands={}
-- main/commands.lua's M.run passes six words, nil-padded: an extra word is a first one that is not nil.
Commands.USE='Use: coop closet [status|wear <fit>[:<Slot>,...] ...|off|fits|menu|thumbs [redo] [<fit>]|'..
    'probe <1-6|off>|body <auto|shoes|first|<fit>>|skin <fit> <slot> on|off|colour <role> <swatch|off>|colour off|'..
    'shape <morph> <0-100>|shape off]'
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
        elseif sub=='thumbs' then
            local redo=(...)=='redo'
            local fit=select(redo and 2 or 1,...)
            if select(redo and 3 or 2,...)~=nil then return false,Commands.USE end
            return o.thumbs.run(redo,fit)
        elseif sub=='probe' then
            local word=(...)
            if word==nil or select(2,...)~=nil then return false,Probe.USE end
            if word=='off' then return o.probe.off() end
            return o.probe.run(word)
        elseif sub=='body' then
            local word=(...)
            if word==nil or select(2,...)~=nil then return false,Commands.USE end
            return o.dress.body_mode(word)
        elseif sub=='skin' then
            local fit,slot,word=...
            if not (fit and slot and slot:match('^%d+$') and (word=='on' or word=='off')) or select(4,...)~=nil then
                return false,Commands.USE
            end
            return o.dress.skin(fit,tonumber(slot),word=='on')
        elseif sub=='colour' then
            local role,word=...
            if role=='off' and word==nil then return o.colour.off() end
            if not (role and word) or select(3,...)~=nil then return false,Colour.USE end
            return o.colour.set(role,word)
        elseif sub=='shape' then
            local name,word=...
            if name=='off' and word==nil then return o.shape.off() end
            local value=tonumber(word)
            if not (name and value) or select(3,...)~=nil then return false,Shape.USE end
            return o.shape.set(name,value)
        end
        return false,Commands.USE
    end
    return self
end
return Commands
