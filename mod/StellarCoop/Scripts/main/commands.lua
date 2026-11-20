-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop ui and coop off with the guide's and the keys' words, then report and run, which every word goes through.
return function(M)
local print,log=M.print,M.log
-- coop ui and coop off stay here: they reach the UI objects main/ui.lua builds and the photo pause
-- (online/photo/wiring.lua).
-- ui/kit/commands.lua's coop guide and coop keys join them; each module's words are in M.commands already.
for _,list in ipairs({{
    -- reset, the escape hatch (UI-DESIGN 7.5): the menu and the chat's box closed, the game's input back now; off
    -- (7.6): the co-op UI gone until the mod reloads, the notice line above EVE and the ghost's name tag back (the
    -- co-op saves' question with it; auto_coop_save=always still asks at the title).
    ui=function(sub,arg)
        if (sub=='reset' or sub=='off') and arg==nil then
            if not M.kit then return false,'the co-op UI needs the Steam link' end
            if sub=='off' then -- The host's question waits for its 30 s: no answer from a UI that is gone.
                M.menu.stop(); M.box.stop(); M.code_box.stop(); M.kit.stop()
                return true,'co-op UI off until the mod reloads: notices on the line above EVE'
            end
            M.ui_reset()
            return true,'co-op UI reset: menu and chat closed, the game has its input back'
        end
        return false,'Use: coop ui reset | off'
    end,
    off=function()
        M.off=true
        M.ghosts_off() -- The ghost and the members' ghosts off, each line they say logged (online/partner/wiring.lua).
        M.notice.stop()
        if M.menu then M.menu.stop() end
        if M.box then M.box.stop() end
        if M.saves_ui then M.saves_ui.stop() end
        if M.code_box then M.code_box.stop(); M.approval.stop() end
        if M.kit then M.kit.stop() end -- The game's input back, the menu's root gone.
        M.chat.clear()
        M.photo_off() -- The game's own photo pause back (online/photo/wiring.lua).
        -- A failing despawn or run end is logged and never stops the rest of coop off.
        local stopped,e=pcall(M.recruiter.stop)
        if not stopped then log('recruiter: '..tostring(e)) end
        if M.sbo then -- The rows as shipped and EVE given back; the native off below logs an open record.
            stopped,e=pcall(M.sbo.off)
            if not stopped then log('sbo: '..tostring(e)) end
        end
        if M.halls then -- The title's wait for the hall rows ended; rows already in stay for the game run.
            stopped,e=pcall(M.halls.stop)
            if not stopped then log('halls: '..tostring(e)) end
        end
        if M.teamshop then -- The team shop's title wait and open wait ended; rows already in stay for the game run.
            stopped,e=pcall(M.teamshop.stop)
            if not stopped then log('teamshop: '..tostring(e)) end
        end
        if M.gunrounds then -- Gun mode's rounds: the title wait and the inventory reads ended; rows already in stay.
            stopped,e=pcall(M.gunrounds.stop)
            if not stopped then log('gun rounds: '..tostring(e)) end
        end
        M.region_tabs.stop() -- No more tabs: only a flag.
        M.pause_tab.stop() -- Likewise; the native part gives its slot back.
        stopped,e=pcall(M.wear.stop) -- EVE's own meshes back.
        if not stopped then log('wear: '..tostring(e)) end
        if M.roxanne then -- Her two choices back before the native part stops taking requests.
            stopped,e=pcall(M.roxanne.stop)
            if not stopped then log('roxanne: '..tostring(e)) end
        end
        if M.lily then -- Lily's eight choices back too.
            stopped,e=pcall(M.lily.stop)
            if not stopped then log('lily: '..tostring(e)) end
        end
        stopped,e=pcall(M.night.stop,'coop off') -- The shop's screen closes first.
        if not stopped then log('nightop: '..tostring(e)) end
        if M.group then -- A death screen the revive hid comes back.
            stopped,e=pcall(M.group.stop)
            if not stopped then log('revive: '..tostring(e)) end
        end
        stopped,e=pcall(M.bike.stop,'coop off') -- Before the race's stop, which leaves a bike drive to it.
        if not stopped then log('bike: '..tostring(e)) end
        stopped,e=pcall(M.bike.leave) -- Her parked bike out of the world, its place kept.
        if not stopped then log('bike: '..tostring(e)) end
        if M.others then -- The other players' copies too.
            stopped,e=pcall(M.others.clear,'coop off')
            if not stopped then log('bike: '..tostring(e)) end
        end
        stopped,e=pcall(M.race.stop)
        if not stopped then log('race: '..tostring(e)) end
        stopped,e=pcall(M.doro.stop)
        if not stopped then log('doro: '..tostring(e)) end
        stopped,e=pcall(M.leviathan.stop)
        if not stopped then log('leviathan: '..tostring(e)) end
        stopped,e=pcall(M.lion.stop)
        if not stopped then log('lion: '..tostring(e)) end
        stopped,e=pcall(M.gardener.stop)
        if not stopped then log('gardener: '..tostring(e)) end
        stopped,e=pcall(M.tendril.stop)
        if not stopped then log('tendril: '..tostring(e)) end
        stopped,e=pcall(M.mxiii.stop)
        if not stopped then log('mxiii: '..tostring(e)) end
        stopped,e=pcall(M.scene.stop) -- The Stop row: the game's camera, input and HUD back.
        if not stopped then log('scene: '..tostring(e)) end
        stopped,e=pcall(M.cut_lines.stop)
        if not stopped then log('lines: '..tostring(e)) end
        stopped,e=pcall(M.flight.off) -- The game's flight keys back.
        if not stopped then log('flight: '..tostring(e)) end
        stopped,e=pcall(M.glide.stop) -- bGlide false again on EVE.
        if not stopped then log('glide: '..tostring(e)) end
        stopped,e=pcall(M.emote.stop) -- Her clip stopped: anim stop, asked before off, or the montage's stop.
        if not stopped then log('emote: '..tostring(e)) end
        stopped,e=pcall(M.gun.stop,'coop off') -- The rifle away, SB's rows and her keys back (fight/gunmode/mode.lua).
        if not stopped then log('gun: '..tostring(e)) end
        stopped,e=pcall(M.devmenu.stop) -- clear and lockswitch, while the engine line still names EVE.
        if not stopped then log('devmenu: '..tostring(e)) end
        if M.mailbox then -- The gift toast off the screen.
            stopped,e=pcall(M.mailbox.stop)
            if not stopped then log('gift: '..tostring(e)) end
        end
        if not M.link then return true,'everything is off until the game restarts' end
        stopped,e=pcall(M.ask('devinfo off')) -- The game's developer panels closed, if open.
        if not stopped then log('devinfo: '..tostring(e)) end
        return M.ask('off')()
    end,
},require('ui.kit.commands').new(M)}) do
    for name,handler in pairs(list) do
        assert(M.commands[name]==nil,'coop '..name..' is defined twice')
        M.commands[name]=handler
    end
end
function M.report(ok,message) log((ok and 'OK: ' or 'STOP: ')..tostring(message)) end
-- What online/partner/ghosts.lua's calls said: a list of {ok, message}.
function M.report_each(said) for _,r in ipairs(said or {}) do M.report(r[1],r[2]) end end
-- A console command, a key or a menu row, on the game thread: logged, and its result returned.
function M.run(name,a,b,c,d,e,f)
    local command=M.commands[name or '']
    if not command then log(M.USAGE); return false,M.USAGE end
    if M.off and command~=M.commands.status and command~=M.commands.report then
        M.report(false,M.OFF)
        return false,M.OFF
    end
    local ran,ok,message=pcall(command,a,b,c,d,e,f)
    if not ran then ok,message=false,ok end
    M.report(ok,message)
    return ok,message
end
end
