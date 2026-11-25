-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The frame loop: each module's frame work, guarded, in a fixed order, then the UI's ticks and the pad.
return function(M)
local print,log=M.print,M.log
assert(type(LoopInGameThreadWithDelay)=='function','This UE4SS lacks game-thread timers.')
-- Each module's work in this loop and main/pass.lua's (its tick, slow, restore and the like) runs guarded: an error
-- that escapes it is logged once a Lua load for that call, under the module's name, with its message and stack
-- traceback (most of our errors are raised at level 0, and UE4SS's own carry no line), and the modules after it still
-- run in that pass.
-- The once goes by the function, not the name: a module's other calls under the same name still log their own first
-- error. A guarded call gives back its first two results, or nothing after an error. Measured with Lua 5.4 on the build
-- machine, the xpcall adds about 40 ns a call: under 2.5 µs a frame for the per-frame loop's 38 to 59 calls (50 with
-- the UI, plus the inbox while a race is armed and up to 8 pad events).
local escaped={} -- The guarded functions whose error was logged this Lua load.
local running -- The guarded function under way: its traceback is built only for the error that gets logged.
local function traced(message)
    if escaped[running] then return message end
    return debug.traceback(message,2)
end
function M.guarded(name,f,...)
    running=f
    local ran,ok,message=xpcall(f,traced,...)
    if ran then return ok,message end
    local key=f or name -- A nil index would raise here.
    if not escaped[key] then
        escaped[key]=true
        log(name..': error (logged once until the mod reloads; the other modules go on): '..tostring(ok))
    end
end
-- A guarded call whose time goes into timed[key] when it is the longest of the minute.
function M.peaked(key,name,f,...)
    local began=os.clock()
    local ok,message=M.guarded(name,f,...)
    local spent=os.clock()-began
    if spent>M.timed[key] then M.timed[key]=spent end
    M.took[key]=spent
    return ok,message
end
LoopInGameThreadWithDelay(1,function()
    local began=os.clock()
    if not M.off then M.gap_line(began) end -- The native part's gap lines stop at coop off too.
    -- The status as of the last 250 ms pass is dropped even when that pass raised before its own settle().
    if M.link then M.link.settle() end
    -- At the first tick, coop off or not: EVE whole again after a reload with the look on.
    M.guarded('doro',M.doro.restore)
    M.guarded('leviathan',M.leviathan.restore) -- Likewise for a cut Naytiba display an earlier load left.
    M.guarded('drive',M.drive.restore) -- Likewise for her movement after a reload with the driving on.
    M.guarded('wear',M.wear.restore) -- Likewise for her own meshes after a reload with a coop wear look on.
    M.guarded('closet',M.closet.restore) -- Likewise after a reload with a coop closet mix on.
    M.guarded('flight',M.flight.restore) -- Likewise for the flight keys after a reload with coop fly on.
    -- Likewise for a scene an earlier load left playing, and the farewell take it lent.
    M.guarded('scene',M.scene.restore)
    M.guarded('glide',M.glide.restore) -- Likewise for a bGlide an earlier load left on.
    M.guarded('emote',M.emote.restore) -- Likewise for a pose's montage an earlier load left playing.
    M.guarded('gun',M.gun.restore) -- Likewise for SB's rows, the keys and her body's layer after a reload, rifle out.
    M.guarded('bike',M.bike.restore) -- Likewise for her main mesh after a reload with her on the bike.
    if M.others then M.guarded('bike',M.others.restore) end -- Likewise for the copies of other players' parked bikes.
    if M.off then if M.blocked and M.native_tick then M.native_tick() end return end
    local ok,message=M.guarded('ghost',M.puppet.tick)
    if message then M.report(ok,message) end
    if M.ghosts then M.report_each(M.guarded('ghost',M.ghosts.tick)) end
    local steered=os.clock()
    -- Before the native tick: the pose it captures has the yaw the driving writes.
    ok,message=M.guarded('race',M.race.steer)
    if message then M.report(ok,message) end
    -- The bike's frame, before the native tick too: her drive's yaw, her lean and pitch. Its end said on screen.
    ok,message=M.guarded('bike',M.bike.steer)
    if message then M.report(ok,message); M.say(message) end
    steered=os.clock()-steered -- The race column carries the bike's frame: the first ride gives its real cost.
    if M.native_tick then M.native_tick() end
    local placed=os.clock()
    ok,message=M.guarded('ghost',M.puppet.place) -- The root takes the mailbox this native tick just wrote.
    if message then M.report(ok,message) end
    if M.ghosts then M.report_each(M.guarded('ghost',M.ghosts.place)) end
    placed=os.clock()-placed
    -- Spectate's camera, from the ghosts' places just set (fight/enemies/spectate.lua).
    if M.spectate then M.guarded('spectate',M.spectate.frame) end
    local looked=os.clock()
    ok,message=M.guarded('doro',M.doro.tick) -- After the native tick: EVE's mesh is where this frame draws her.
    if message then M.report(ok,message) end
    looked=os.clock()-looked
    ok,message=M.guarded('leviathan',M.leviathan.tick) -- Outside the doro column of the frame time line.
    if message then M.report(ok,message) end
    ok,message=M.peaked('lion','lion',M.lion.tick)
    if message then M.report(ok,message) end
    ok,message=M.guarded('gardener',M.gardener.tick)
    if message then M.report(ok,message) end
    ok,message=M.guarded('tendril',M.tendril.tick)
    if message then M.report(ok,message) end
    ok,message=M.peaked('mxiii','mxiii',M.mxiii.tick)
    if message then M.report(ok,message) end
    ok,message=M.peaked('scene','scene',M.scene.tick)
    if message then M.report(ok,message) end
    M.guarded('region tabs',M.region_tabs.tick) -- Once a load: its two hooks, once there is a player controller.
    M.guarded('talks',M.talks.tick) -- Lily's talks: a hold, the Stop after the last line, the kit's lines.
    M.guarded('flight',M.flight.tick)
    ok,message=M.guarded('lines',M.cut_lines.tick)
    if message then M.report(ok,message) end
    ok,message=M.guarded('glide',M.glide.tick)
    if message then M.report(ok,message) end
    ok,message=M.guarded('emote',M.emote.tick)
    if message then M.report(ok,message) end
    ok,message=M.guarded('gun',M.gun.tick)
    if message then M.report(ok,message) end
    local raced=os.clock()
    if M.link and M.guarded('race',M.race.armed) then M.guarded('inbox',M.inbox) end
    ok,message=M.guarded('race',M.race.tick) -- After the look: its Doros and HUD from where EVE is drawn this frame.
    if message then M.report(ok,message) end
    raced=os.clock()-raced+steered
    ok,message=M.guarded('notice',M.notice.tick)
    if message then M.report(ok,message) end
    M.guarded('probe',M.nightop.tick) -- A due probe follow-up: it logs its own lines.
    M.guarded('recruiter',M.recruiter.tick) -- Likewise for coop recruiter.
    ok,message=M.guarded('wear',M.wear.tick) -- Once a second at most: a worn look the game replaced goes on again.
    if message then M.report(ok,message) end
    M.guarded('closet',M.closet.tick) -- Likewise for a coop closet mix; it logs its own lines.
    -- The open and close tweens, the game's input back after a close, the chat box focused again, the partner's marker
    -- (each frame, from the ghost's place just set).
    if M.kit then
        local now=os.clock()
        ok,message=M.guarded('kit',M.kit.tick,now)
        if message then M.report(ok,message) end
        M.guarded('menu',M.menu.tick,now)
        M.guarded('wheel',M.wheel.tick,now)
        M.guarded('lobby',M.lobby.tick,now)
        M.guarded('sessions',M.sessions.tick,now)
        M.guarded('create',M.create.tick,now)
        M.guarded('chat',M.box.tick,now)
        M.guarded('join',M.code_box.tick,now)
        M.guarded('join',M.approval.tick,now)
        M.guarded('saves',M.saves_ui.tick,now)
        M.guarded('hud',M.hud.tick,now)
        M.guarded('pause tab',M.pause_tab.tick,now)
        if M.native_pad then -- At most 8 pad events a frame, the native part's whole ring.
            for _=1,8 do
                local what=M.PAD[M.pad()]
                if not what then break end
                M.guarded('pad',M.pad_event,what)
            end
        end
        if M.chat_asked and now>=M.chat_asked+0.1 then
            local asked=M.chat_asked
            M.chat_asked=nil
            if M.typed_at<asked-0.3 and not M.menu.is_open() and not M.approval.is_open() and not M.lobby.is_open()
                and not M.open_screen() then
                local _,why,en=M.box.open() -- Said on screen only: Enter is the game's too.
                if why then M.say(why,en) end
            end
        end
        local t=os.clock()
        M.timed.since=M.timed.since or t
        M.timed.ghost,M.timed.doro,M.timed.race=M.timed.ghost+placed,M.timed.doro+looked,M.timed.race+raced
        M.timed.ui,M.timed.frames=M.timed.ui+t-now,M.timed.frames+1
        M.passed(M.timed.frame,t-began)
        if t-M.timed.since>=60 then
            if M.kit.ready() then
                local function ms(v) return v*1000/M.timed.frames end
                local f,p=M.timed.frame,M.timed.pass
                log(string.format('Lua frame time, last 60 s: ghost %.3f ms, doro %.3f ms, race %.3f ms, UI %.3f ms a '
                    ..'frame (%d frames); longest frame %.1f ms (%d over 16 ms, %d over 50 ms): mxiii %.1f ms, lion '
                    ..'%.1f ms, scene %.1f ms; longest 250 ms pass %.1f ms (%d over 16 ms, %d over 50 ms): booth %.1f '
                    ..'ms, kit.slow %.1f ms',ms(M.timed.ghost),ms(M.timed.doro),ms(M.timed.race),ms(M.timed.ui),
                    M.timed.frames,
                    f[1]*1000,f[2],f[3],M.timed.mxiii*1000,M.timed.lion*1000,M.timed.scene*1000,p[1]*1000,p[2],p[3],
                    M.timed.booth*1000,M.timed.slow*1000))
            end
            M.timed=M.new_timed(t)
        end
    end
end)
end
