-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The wiring of Score attack (online/modes/scoreattack/): its round on the Steam link (round.lua, M.scoreattack, nil
-- without the link) with its game side (game.lua) and our run (run.lua), logging [SA] lines, and coop scoreattack.
-- main/pass.lua ticks M.scoreattack every 250 ms after the inbox; coop off stops it (main/commands.lua). The host's
-- draw reads the challenges the lobby's room offers from online.lobby's sbo at each round's start; while that module
-- is off its target is nothing: the room offers none, so the host voids the round. A guest sits out then. A Night
-- Operation run on makes us sit out too; while that module is off none is. The run's best match runs go in
-- coop-records.txt in the mod folder, written as Night Operation's challenges write theirs.
return {
uses={'online.lobby','online.modes.nightop'},
exports={'scoreattack'},
new=function(M)
local Sa=require('online.modes.scoreattack.model')
local Loader=require('main.loader')
local sbo=Loader.view(M,'sbo')
local night=Loader.get(M,'online.modes.nightop','night')
if M.link then
    local log=function(m) M.print('[StellarCoop][SA] '..tostring(m)..'\n') end
    local game
    local run=require('online.modes.scoreattack.run').new({log=log,status=function() return M.link.status() end,
        paused=function() return M.kit~=nil and M.kit.paused(true) end,life=function() return M.link.life() end,
        ended=function(s) game.ended(s) end,
        records=M.folder and {
            read=function()
                local text,e,code=require('core.link').files.read(M.folder..'\\coop-records.txt')
                if text==nil and code~=2 then error(e) end -- 2: ENOENT, no such file.
                return text
            end,
            write=function(text)
                local fs,p=require('core.link').files,M.folder..'\\coop-records.txt'
                if not fs.write(p..'.tmp',text) then return false end
                fs.remove(p) -- rename never replaces on Windows.
                return fs.rename(p..'.tmp',p)==true or not fs.read(p) and fs.write(p,text)
            end} or nil})
    M.scoreattack=require('online.modes.scoreattack.round').new({link=M.link,clock=os.clock,log=log,
        offered=function()
            local room=sbo.target()
            return room and Sa.offered(room)
        end,
        start=function(def,seed,k) game.start(def,seed,k) end,stop=function(why) game.stop(why) end,
        pass=function() game.tick() end})
    game=require('online.modes.scoreattack.game').new({run=run,round=M.scoreattack,log=log,
        on=function() return M.settings.scoreattack==true end,riding=function() return M.riding() end,
        night=function()
            local n=night()
            return n~=nil and n.running()==true
        end,
        target=function() return sbo.target() end,seated=function() return sbo.seated()~=nil end,
        stand=function() return sbo.stand() end})
end
return require('online.modes.scoreattack.commands').new({round=M.scoreattack})
end,
}
