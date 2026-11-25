-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Doro races' wiring (online/modes/race/): the Doro look, the races' driving, the race and its HUD, and the round
-- of Doro races in matches.
return {
uses={'online.partner','online.modes.nightop','vehicles.bike','online.lobby'},
exports={'doro','drive','race','race_match'},
new=function(M)
local print,log=M.print,M.log
local Loader=require('main.loader')
local sbo=Loader.view(M,'sbo')
local puppet=Loader.view(M,'puppet')
-- The race's asks to its native part (online/modes/race/hold.h: race hold, race tick) and the engine line's fields it
-- answers with (race_hold=, race_retick=); none without the native part.
local function ask(text) return M.link.request(text) end
local function engine() return ('\n'..(M.link.status() or '')):match('\nengine=([^\r\n]*)') or '' end
-- The Doro look and probe (online/modes/race/doro.lua), logging [DR] lines. coop-look.txt lets the next Lua load
-- show EVE's parts again; her tick option is the native part's (race tick).
M.doro=require('online.modes.race.doro').new({log=function(m) print('[StellarCoop][DR] '..tostring(m)..'\n') end,
    store=M.link and M.link.store('coop-look.txt'),ask=M.link and ask,
    retick=M.link and function() return tonumber(engine():match(' race_retick=(%d+)')) end})
-- Whether EVE rides the bike (main/base.lua's riding, read at each call): the races' drive and the race refuse
-- their probe, off and start while she does.
local function riding() return M.riding() end
-- The races' driving (online/modes/race/drive.lua), logging [DR] lines: the native part holds EVE's movement values
-- while it drives (race hold) and puts them back at a new Lua load.
M.drive=require('online.modes.race.drive').new({log=M.doro.log,settings=M.settings,riding=riding,ask=M.link and ask,
    held=M.link and function()
        local h=engine():match(' race_hold=(%w+)')
        if h then return h=='1' end
    end})
-- The host's own tracks a match lobby may offer: coop-tracks.txt in the mod folder (match/model.lua's index), each
-- name with its coop-track file. A name whose file is gone or broken is dropped from the file as it is read.
local Mm=require('online.modes.race.match.model')
local R=require('online.modes.race.model')
local INDEX='coop-tracks.txt'
local function index(name)
    if not M.link then return end
    local ok,why=M.link.write_file(INDEX,Mm.indexed(M.link.read_file(INDEX),name))
    if not ok then M.doro.log('coop-tracks.txt: '..tostring(why)) end
end
local function own()
    local names,list=Mm.index(M.link.read_file(INDEX)),{}
    for _,name in ipairs(names) do
        local t=R.parse_track(M.link.read_file(R.file(name)) or '')
        if t then list[#list+1]={name=name,track=t} end
    end
    if #list<#names then
        local kept={}
        for i,e in ipairs(list) do kept[i]=e.name end
        M.link.write_file(INDEX,Mm.index_text(kept))
        M.doro.log(string.format('coop-tracks.txt: %d names without a track file dropped',#names-#list))
    end
    return list
end
-- The official tracks of a lobby room (match/tracks.lua's names), read only from match/tracks/ beside it in the
-- Scripts folder; one that does not parse is left out with a log line.
local folder=(package.searchpath('online.modes.race.match.tracks',package.path) or ''):match('^(.*[\\/])[^\\/]+$')
local function official(key)
    local list={}
    for _,name in ipairs(require('online.modes.race.match.tracks')[key] or {}) do
        local f=folder and io.open(folder..'tracks/'..name..'.txt','rb')
        local t,why=nil,'no file'
        if f then
            t,why=R.parse_track(f:read('a') or '')
            f:close()
        end
        if t then list[#list+1]={name=name,track=t} else M.doro.log('official track '..name..': '..tostring(why)) end
    end
    return list
end
-- Whether we are in a match lobby (the link's match line, past the search): coop race start is refused there.
local function match_lobby()
    local m=M.link and M.link.match()
    return m~=nil and m.state~='searching'
end
-- Whether SB's own hall chair seats EVE, for a match round's start and its GO. The lobby's busy():
-- SBCharacter's IsRunningInteraction (its exec 0x14268cc20 reads byte +0x3493) at its pass.
local function resting() return sbo.busy()==true end
-- Doro races (online/modes/race/run.lua), logging [DR] lines: the look above on EVE and the ghost's Doro mode while one
-- runs, and the driving from GO. Its start and the guest's answer need a co-op save; it never arms during a Night
-- Operation run.
-- No race starts while EVE rides the bike; the guest's answer to a track line takes her off it first (dismount).
-- Its 250 ms pass ticks the match round first; coop off stops the round after our race.
M.race=require('online.modes.race.run').new({log=M.doro.log,link=M.link,puppet=puppet,
    look=M.doro,
    drive=M.drive,tell=M.tell,night=function() return M.night.running() end,
    slot=function() return M.coop_slot('coop race') end,paused=function() return M.kit~=nil and M.kit.paused(true) end,
    settings=M.settings,store=M.link and M.link.store('coop-race-doros.txt'),
    dismount=function(why) return M.bike.stop(why) end,riding=riding,
    match_lobby=match_lobby,resting=resting,saved=index,
    round_tick=function() if M.race_match then M.race_match.tick() end end,
    round_stop=function(why) if M.race_match then M.race_match.stop(why) end end})
-- Doro races in matches: the round on the Steam link (online/modes/race/match/round.lua, M.race_match, nil without
-- the link), logging [DR] lines, on the race's clock in milliseconds, with its game side (match/game.lua). The tracks
-- the lobby room EVE stands in offers on her map, read at each call; while online.lobby is off its room is nothing,
-- so the host voids the round and a guest sits out. Our best times go in coop-records.txt in the mod folder, written
-- as score attack writes its own.
if M.link then
    local game
    M.race_match=require('online.modes.race.match.round').new({link=M.link,
        clock=function() return os.clock()*1000 end,log=M.doro.log,
        offered=function()
            local room,me=sbo.target(),require('core.where').me()
            return room and me and Mm.offered(room,me.map,official(room.key),own()) or nil
        end,
        start=function(t,name,seed,k) game.start(t,name,seed,k) end,
        stop=function(why) game.stop(why) end})
    game=require('online.modes.race.match.game').new({run=M.race,round=M.race_match,log=M.doro.log,
        on=function() return M.settings~=nil and M.settings.race_match==true end,riding=riding,
        night=function() return M.night.running()==true end,
        slot=function() return M.coop_slot('coop race') end,
        target=function() return sbo.target() end,
        map=function()
            local me=require('core.where').me()
            return me and me.map
        end,
        resting=resting,
        seated=function() return sbo.seated()~=nil end,stand=function() return sbo.stand() end,
        me=function() return (M.link.saves() or {}).steamid end,
        ghost=function(id)
            for _,m in ipairs(M.link.members()) do
                if m.id==id then return m.slot==0 and puppet or M.ghost_of(m.slot) end
            end
        end,
        name=function(id)
            local m=M.link.member(id)
            return m and m.name~='' and m.name or nil
        end,
        tell=function(key) M.tell(function(w) return w.race.match[key] end) end,
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
end
return require('online.modes.race.commands').new({puppet=puppet,doro=M.doro,
    coop_slot=M.coop_slot,
    race=M.race,riding=riding,match_on=function() return M.settings~=nil and M.settings.race_match==true end,
    round=M.race_match,index=index})
end,
build={
hud=function(M,Ui)
    M.race.hud({kit=M.kit,theme=Ui.THEME,settings=M.settings})
end,
},
}
