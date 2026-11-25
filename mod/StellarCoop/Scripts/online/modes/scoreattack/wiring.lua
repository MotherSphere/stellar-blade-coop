-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The wiring of Score attack (online/modes/scoreattack/): its round on the Steam link (round.lua, M.scoreattack, nil
-- without the link) with its game side (game.lua) and our run (run.lua), logging [SA] lines, and coop scoreattack.
-- main/pass.lua ticks M.scoreattack every 250 ms after the inbox; coop off stops it (main/commands.lua). The host's
-- draw reads the challenges the lobby's room offers from online.lobby's sbo at each round's start; while that module
-- is off its target is nothing: the room offers none, so the host voids the round. A guest sits out then. A Night
-- Operation run on makes us sit out too; while that module is off none is. A death in a score attack match's lobby
-- room (link.match(), sbo.target()) gets the run's in-place respawn, run or not. The run's best match runs go in
-- coop-records.txt in the mod folder, written as Night Operation's challenges write theirs. Its screens
-- (ui/board.lua, M.scoreattack_board): the card, the in-round board and the result panel, drawn after each pass; the
-- sit-out notices and a round's why come in the menu's words (M.tell).
return {
uses={'online.lobby','online.modes.nightop'},
exports={'scoreattack','scoreattack_board'},
new=function(M)
local Sa=require('online.modes.scoreattack.model')
local Loader=require('main.loader')
local sbo=Loader.view(M,'sbo')
local night=Loader.get(M,'online.modes.nightop','night')
if M.link then
    local log=function(m) M.print('[StellarCoop][SA] '..tostring(m)..'\n') end
    local game,board
    local run=require('online.modes.scoreattack.run').new({log=log,status=function() return M.link.status() end,
        paused=function() return M.kit~=nil and M.kit.paused(true) end,life=function() return M.link.life() end,
        ended=function(s) game.ended(s) end,
        room=function()
            local m=M.link.match()
            return m~=nil and m.mode=='scoreattack' and m.state~='searching' and sbo.target()~=nil
        end,
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
        start=function(def,seed,k) game.start(def,seed,k) end,
        stop=function(why)
            game.stop(why)
            board.stop()
        end,
        pass=function()
            game.tick()
            board.tick()
        end})
    board=require('online.modes.scoreattack.ui.board').new({round=M.scoreattack.round,
        run=run.state,clock=os.clock,log=log,tell=M.tell,
        name=function(id)
            if id==(M.link.saves() or {}).steamid then return M.link.me() end
            local m=M.link.member(id)
            return m and m.name
        end,
        level=function(id)
            local mine,list=M.link.cycles()
            if id==(M.link.saves() or {}).steamid then return mine and mine.difficulty end
            for _,c in ipairs(list or {}) do if c.id==id then return c.difficulty end end
        end})
    M.scoreattack_board=board
    game=require('online.modes.scoreattack.game').new({run=run,round=M.scoreattack,log=log,
        on=function() return M.settings.scoreattack==true end,riding=function() return M.riding() end,
        night=function()
            local n=night()
            return n~=nil and n.running()==true
        end,
        target=function() return sbo.target() end,
        -- The lobby's busy(): SBCharacter's IsRunningInteraction (its exec 0x14268cc20 reads byte +0x3493) at its pass.
        resting=function() return sbo.busy()==true end,
        seated=function() return sbo.seated()~=nil end,
        stand=function() return sbo.stand() end,
        out=function(key) M.tell(function(w) return w.scoreattack.out[key] end) end})
end
return require('online.modes.scoreattack.commands').new({round=M.scoreattack})
end,
build={
hud=function(M,Ui)
    if M.scoreattack_board then M.scoreattack_board.hud({kit=M.kit,theme=Ui.THEME,settings=M.settings}) end
end,
},
}
