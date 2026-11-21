-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The wiring of Photo hunt (online/modes/photohunt/): its round on the Steam link (round.lua, M.photohunt, nil without
-- the link), logging [PH] lines, with coop photohunt as its console word. Our best photo hunt of each world goes in
-- coop-records.txt in the mod folder, written as the fishing tournament's wiring writes its records (a copy: .tmp,
-- then a rename). It reads no other module.
return {
uses={},
exports={'photohunt'},
new=function(M)
if M.link then
    local log=function(m) M.print('[StellarCoop][PH] '..tostring(m)..'\n') end
    local Rec=require('online.modes.photohunt.records')
    M.photohunt=require('online.modes.photohunt.round').new({link=M.link,clock=os.time,log=log,
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
end
return require('online.modes.photohunt.commands').new({round=M.photohunt})
end,
}
