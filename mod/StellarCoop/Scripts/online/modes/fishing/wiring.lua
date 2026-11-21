-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The wiring of Fishing tournament (online/modes/fishing/): its tournament on the Steam link (round.lua, M.fishing, nil
-- without the link) with its game side (game.lua: the fish table read from SB's tables at the first go of a Lua load,
-- fishing=on, a co-op save, then SB's fishing log book read through the native part once a second from GO to our end),
-- logging [FT] lines, with coop fish as its console word. main/pass.lua ticks M.fishing every 250 ms after the inbox;
-- coop off stops it (main/commands.lua). Our best tournament of each length goes in coop-records.txt in the mod
-- folder, written as score attack's wiring writes its records (a copy: .tmp, then a rename). Its screens
-- (ui/board.lua, M.fishing_board): the corner board and the result panel, drawn after each pass; the round's notices
-- come in the menu's words (M.tell).
return {
uses={},
exports={'fishing','fishing_board'},
new=function(M)
if M.link then
    local log=function(m) M.print('[StellarCoop][FT] '..tostring(m)..'\n') end
    local Rec=require('online.modes.fishing.records')
    local Game=require('online.modes.fishing.game')
    local game,board
    M.fishing=require('online.modes.fishing.round').new({link=M.link,clock=os.time,log=log,
        fish=function() return game.fish() end,start=function(t) game.start(t) end,
        stop=function(why)
            game.stop(why)
            board.stop()
        end,
        pass=function()
            game.tick()
            board.tick()
        end,
        tell=function(...) board.notice(...) end,
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
    local Where,U=require('core.where'),require('core.unreal')
    board=require('online.modes.fishing.ui.board').new({round=M.fishing.round,clock=os.time,log=log,tell=M.tell,
        name=function(id)
            if id==(M.link.saves() or {}).steamid then return M.link.me() end
            local m=M.link.member(id)
            return m and m.name
        end,
        title=function() return select(2,Where.world())==true end})
    M.fishing_board=board
    game=Game.new({round=M.fishing,status=function() return M.link.status() end,
        request=function(line) return M.link.request(line) end,clock=os.time,log=log,
        on=function() return M.settings.fishing==true end,coop=function() return M.coop_slot('fishing')==true end,
        world=function()
            if Where.world()~=true then return nil end
            local me=Where.me()
            return me and me.map
        end,
        rows=function() return Game.rows(U.find,U.value_of) end})
end
return require('online.modes.fishing.commands').new({round=M.fishing})
end,
build={
hud=function(M,Ui)
    if M.fishing_board then M.fishing_board.hud({kit=M.kit,theme=Ui.THEME,settings=M.settings}) end
end,
},
}
