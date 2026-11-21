-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The wiring of Photo hunt (online/modes/photohunt/): its round on the Steam link (round.lua, M.photohunt, nil without
-- the link) with its game side (game.lua: photohunt=on, a co-op save, the targets of the host's map read from SB's
-- tables at each start, then SB's photo check of the three targets through the native part at each selfie photo from
-- GO to our end), logging [PH] lines, with coop photohunt as its console word. main/pass.lua ticks M.photohunt every
-- 250 ms after the inbox; coop off stops it (main/commands.lua). Our best photo hunt of each world goes in
-- coop-records.txt in the mod folder, written as the fishing tournament's wiring writes its records (a copy: .tmp,
-- then a rename). It reads no other module.
return {
uses={},
exports={'photohunt'},
new=function(M)
local game
if M.link then
    local log=function(m) M.print('[StellarCoop][PH] '..tostring(m)..'\n') end
    local Rec=require('online.modes.photohunt.records')
    local Game=require('online.modes.photohunt.game')
    M.photohunt=require('online.modes.photohunt.round').new({link=M.link,clock=os.time,log=log,
        check=function() return game.check() end,targets=function() return game.targets() end,
        start=function(t) game.start(t) end,stop=function(why) game.stop(why) end,pass=function() game.pass() end,
        record=M.folder and function(world,points,s)
            local fs,p=require('core.link').files,M.folder..'\\coop-records.txt'
            local text,e,code=fs.read(p)
            if text==nil and code~=2 then error(e) end -- 2: ENOENT, no such file.
            local old_points,old_s=Rec.best(text,world)
            if not Rec.better(old_points,old_s,points,s) then return false end
            local new,why=Rec.write(text,world,points,s)
            if not new then return log('record not written: '..tostring(why)) end
            if not fs.write(p..'.tmp',new) then return log('record not written: '..p..'.tmp') end
            fs.remove(p) -- rename never replaces on Windows.
            if fs.rename(p..'.tmp',p)~=true and not (not fs.read(p) and fs.write(p,new)) then
                return log('record not written: '..p)
            end
            log(string.format('new best in %s: %d points, last at %d s',world,points,s))
            return true
        end or nil})
    local Where,U=require('core.where'),require('core.unreal')
    game=Game.new({round=M.photohunt,status=function() return M.link.status() end,
        request=function(line) return M.link.request(line) end,clock=os.time,log=log,
        on=function() return M.settings.photohunt==true end,coop=function() return M.coop_slot('photohunt')==true end,
        map=function()
            if Where.world()~=true then return nil end
            local me=Where.me()
            return me and me.map
        end,
        read=function(map) return Game.read(U.find,U,map) end,fname=function(row) return M.fname(row) end})
end
return require('online.modes.photohunt.commands').new({round=M.photohunt,game=game})
end,
}
