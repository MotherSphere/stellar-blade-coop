-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The wiring of Fishing tournament (online/modes/fishing/): its tournament on the Steam link (round.lua, M.fishing, nil
-- without the link), logging [FT] lines, with coop fish as its console word. Our best tournament of each length goes
-- in coop-records.txt in the mod folder, written as score attack's wiring writes its records (a copy: .tmp, then a
-- rename). To come: the game side that reads the fishing log book and the fish table (fish and catches), the pass
-- line, coop off and the screens.
return {
uses={},
exports={'fishing'},
new=function(M)
if M.link then
    local log=function(m) M.print('[StellarCoop][FT] '..tostring(m)..'\n') end
    local Rec=require('online.modes.fishing.records')
    M.fishing=require('online.modes.fishing.round').new({link=M.link,clock=os.time,log=log,
        record=M.folder and function(minutes,points,catches)
            local fs,p=require('core.link').files,M.folder..'\\coop-records.txt'
            local text,e,code=fs.read(p)
            if text==nil and code~=2 then error(e) end -- 2: ENOENT, no such file.
            local old_points,old_catches=Rec.best(text,minutes)
            if not Rec.better(old_points,old_catches,points,catches) then return false end
            local new,why=Rec.write(text,minutes,points,catches)
            if not new then return log('record not written: '..tostring(why)) end
            if not fs.write(p..'.tmp',new) then return log('record not written: '..p..'.tmp') end
            fs.remove(p) -- rename never replaces on Windows.
            if fs.rename(p..'.tmp',p)~=true and not (not fs.read(p) and fs.write(p,new)) then
                return log('record not written: '..p)
            end
            log(string.format('new best of %d minutes: %d points, %d fish',minutes,points,catches))
            return true
        end or nil})
end
return require('online.modes.fishing.commands').new({round=M.fishing})
end,
}
