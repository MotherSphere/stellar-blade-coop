-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Input: the frame and pass timing, the gap line, her chat lines, the pad's events, the Online tab, the console.
return function(M)
local print,log=M.print,M.log
local T=require('ui.text')
-- The Lua frame time of the ghost's place and of the UI's ticks (UI-DESIGN 7.3, measured in T-UI1), summed and logged
-- once a minute with the UI up. os.clock steps by whole ms under the game's C runtime: over a minute's frames the sum
-- averages out. The Doro look's frame and the race's are timed beside them. A mean hides a frozen frame, so the line
-- also gives the longest frame and the longest 250 ms pass ({longest, count over 16 ms, count over 50 ms}), and the
-- longest call of mxiii, lion and scene (each frame) and of booth and kit.slow (each 250 ms).
function M.new_timed(since)
    return {ghost=0,doro=0,race=0,ui=0,frames=0,since=since,frame={0,0,0},pass={0,0,0},mxiii=0,lion=0,scene=0,booth=0,
        slow=0}
end
M.timed=M.new_timed(nil)
-- os.clock steps by whole ms in game (the booths' slow scan lines read 31.0, 44.0, 56.0 ms): over 16 ms reads 17 or
-- more, over 50 ms 51 or more.
function M.passed(p,spent)
    if spent>p[1] then p[1]=spent end
    if spent>0.0165 then p[2]=p[2]+1 end
    if spent>0.0505 then p[3]=p[3]+1 end
end
-- The gap line, the Lua twin of the native part's (glue/tick/worker.inc's log_gap, in coop-link.log; UE4SS stamps
-- both in UTC): a frame that starts over 100 ms after the last one names the 250 ms pass that ran in between, by its
-- length and its kit.slow and booth calls (took, set by peaked), or says none did. At most GAP_LINES from the first of
-- a minute, then one line says so: each frame of a long load is a gap.
local GAP_LINES=200 -- A save load, its warp and a hall's arrival logged 25 gaps in 64 s; 600 at most fit a minute.
M.took={slow=0,booth=0} -- Each peaked call's time, as last run.
local gap_lines,gap_since=0,-math.huge
function M.gap_line(began)
    local last=M.frame_began
    M.frame_began=began
    if not last or began-last<0.1005 then return end -- os.clock's whole ms, as passed reads them: 101 or more.
    if began-gap_since>=60 then gap_since,gap_lines=began,0 end
    gap_lines=gap_lines+1
    if gap_lines>GAP_LINES then
        if gap_lines==GAP_LINES+1 then log('gap lines: '..GAP_LINES..' this minute, no more until it ends') end
        return
    end
    local function ms(v) return string.format('%.0f',v*1000) end
    if M.pass_ended>last then
        log('gap '..ms(began-last)..' ms before this frame; 250 ms pass in it: '..ms(M.pass_took)..' ms (kit.slow '
            ..ms(M.pass_slow)..', booth '..ms(M.pass_booth)..')')
    else
        log('gap '..ms(began-last)..' ms before this frame; no pass in it')
    end
end
-- coop-chat.txt, taken and deleted at once: her chat lines to the chat (on the line above EVE while the feed cannot
-- show them: the UI off or failed, or still warming), her race lines to the race, her camp rests to the group module, a
-- line of ours that could not go to the chat's fail. Every 250 ms, and each frame while a race is armed.
function M.inbox()
    for _,line in ipairs(M.link.take_chat()) do
        if line.fail then M.chat.fail()
        elseif line.race then M.race.receive(line.race)
        elseif line.gift then
            local ok,e=true,nil
            if not M.off then ok,e=pcall(M.mailbox.receive,line.gift) end
            if not ok then log('gift: '..tostring(e)) end
        elseif line.rest then
            local ok,e=true,nil
            if not M.off then ok,e=pcall(M.group.rest,line.rest,line.from) end
            if not ok then log('rest: '..tostring(e)) end
        elseif line.text then
            local m=line.from and M.link.member(line.from)
            local got=M.chat.receive((m and m.name) or (M.link.friend()) or '',line.text,M.chat_clock)
            if got and not M.kit.ready() then
                local function said(w) return w.chat.said:format(got.name~='' and got.name or w.chat.partner) end
                M.notice.say(said(M.words())..got.text,said(T.en)..got.text)
            end
        end
    end
end
-- A pad event, routed as the keys route theirs (main/keys.lua): an open lobby screen (its question, C, B) takes
-- the six navigation words, and menu (View held 1 s) closes B or C to the room; the menu open takes the six navigation
-- words, and menu closes it; the co-op saves' question takes up, down, select and back; with nothing open, in a world
-- with our HUD shown, menu sits EVE down, stands her up or opens B in the lobby world (lobby_key) and opens the co-op
-- menu elsewhere, as menu_key does, its refusals said the same way. The host's question and the joiner's wait, while
-- one is open, take every word first (A is Jump and the D-pad uses items: for 1 s after it shows a press does nothing;
-- Decline has the focus, so a stray A declines; a held stick's or D-pad's repeats never move that focus). While the menu waits for a key only back acts: it stops the wait
-- (menu.nav). The chat's box and the code box take only back, which closes them as Esc does: nothing is typed or sent.
-- A pad alone is never stuck there. LB and RB (tab_left, tab_right) change C's tabs while C is open; nothing
-- elsewhere.
-- The Sessions screen or the Create a session screen, after the lobby's, takes them all and Y (refresh, the Sessions
-- screen's only); menu closes it.
-- bike (D-pad Right held 1 s) gets EVE on the bike or off it as bike_key does, in a world with our HUD shown, none of
-- our screens open (the host's question, the Sessions screen and the Create a session screen included) and the game
-- neither paused nor showing one of its own screens, such as its inventory or map; otherwise it logs why and does
-- nothing. pause_tab (RB on the pause menu's last tab, E on the keyboard: the native part's event 12) goes to the
-- Online tab only (ui/kit/pause_tab.lua), never to one of our screens. left and right (the D-pad or the left stick)
-- that nothing above took switch the member spectate watches while our EVE is down in a shared boss fight
-- (fight/enemies/spectate.lua).
-- wheel (D-pad Left held 0.3 s, the native part's event 13) opens the emote wheel (eve/ui/wheel.lua) with
-- emote_pad=dpad_left, in a world with our HUD shown and none of our screens open; otherwise it logs why and does
-- nothing. While the wheel is open it takes LB and RB (its pages), A (play) and B (cancel); every other word is dropped.
M.PAD={'up','down','left','right','select','back','menu','tab_left','tab_right','bike','refresh','pause_tab','wheel'}
-- bike_key and the pad's bike: EVE on the bike or off it, logged as a command is. A refusal also goes on screen, in
-- English as the bike gives it, since the press shows nothing else.
function M.bike_press(by)
    if M.off then return M.report(false,M.OFF) end
    local ran,ok,message=true,false,'the bike is off until the mod reloads' -- Bike off: its stub would say nil.
    if not M.off_modules['vehicles.bike'] then ran,ok,message=pcall(M.bike.toggle,by) end
    if not ran then ok,message=false,ok end
    M.report(ok,message)
    if not ok then M.say(tostring(message)) end
end
-- menu_key's path with nothing open in a world: B in the lobby world, the co-op menu elsewhere, its refusals said.
local function open_menu()
    if M.sbo.in_lobby() then return M.lobby_key() end
    local ok,why,shown,en=M.menu.toggle(M.booth.near(require('core.where').me()))
    if why then M.report(ok,why); M.say(shown or why,en) end
end
function M.pad_event(what)
    if what=='pause_tab' then return M.pause_tab.event(os.clock()) end
    if M.wheel and M.wheel.is_open() then
        if what=='tab_left' or what=='tab_right' or what=='select' or what=='back' then M.wheel.nav(what) end
        return
    end
    if what=='wheel' then
        local why=not M.hud_shown and 'our HUD is not shown'
            or M.settings.emote_pad~='dpad_left' and 'emote_pad is off'
            or (M.approval.is_open() or M.lobby.is_open() or M.code_box.is_open() or M.box.is_open() or M.menu.is_open()
                or M.saves_ui.is_open() or M.open_screen()~=nil) and 'one of our screens is open'
        if why then log('pad: wheel ignored: '..why); return end
        log('pad: wheel')
        if M.off then return M.report(false,M.OFF) end
        return M.emote_wheel.press('pad')
    end
    if what=='bike' then
        local why=not M.hud_shown and 'our HUD is not shown'
            or (M.approval.is_open() or M.lobby.is_open() or M.code_box.is_open() or M.box.is_open() or M.menu.is_open()
                or M.saves_ui.is_open() or M.open_screen()~=nil) and 'one of our screens is open'
            or M.kit~=nil and M.kit.paused(true) and 'the game is paused or shows one of its screens'
        if why then log('pad: bike ignored: '..why); return end
        log('pad: bike')
        M.bike_press('the pad')
        return
    end
    if M.approval.is_open() then return M.approval.nav(what) end
    local screen=M.open_screen()
    if screen and not M.lobby.is_open() then
        if what~='menu' then return screen.nav(what) end
        log('pad: menu')
        return screen.close()
    end
    if what=='tab_left' or what=='tab_right' or what=='refresh' then
        if what~='refresh' and M.lobby.is_open()=='settings' then M.lobby.nav(what) end
        return
    end
    if M.lobby.is_open() then
        if what~='menu' then return M.lobby.nav(what) end
        if M.lobby.is_open()~='popup' then
            log('pad: menu')
            M.lobby_room()
        end
        return
    end
    if M.code_box.is_open() or M.box.is_open() then
        if what=='back' then (M.code_box.is_open() and M.code_box or M.box).cancel() end
        return
    end
    if M.menu.is_open() then
        if what~='menu' then return M.menu.nav(what) end
        if M.menu.capturing() then return end
        log('pad: menu')
        return M.menu.toggle()
    end
    if M.saves_ui.is_open() then
        if what=='up' or what=='down' or what=='select' or what=='back' then M.saves_ui.nav(what) end
    elseif what=='menu' and M.hud_shown then
        log('pad: menu')
        open_menu()
    elseif (what=='left' or what=='right') and M.spectate and M.spectate.watching() then
        M.spectate.switch(what)
    end
end
-- The pause menu's Online tab (ui/kit/pause_tab.lua), made after pad_event: it opens the menu. Logging [PT] lines.
-- Its button and its open run on the game thread; RB comes as pad_event's pause_tab, a click through
-- main/keys.lua's LEFT_MOUSE_BUTTON bind.
M.pause_tab=require('ui.kit.pause_tab').new({log=function(m) print('[StellarCoop][PT] '..tostring(m)..'\n') end,
    ready=function() return M.link~=nil and require('core.unreal').controller()~=nil end,
    enabled=function() return M.settings~=nil and M.settings.pause_tab==true end,
    word=function() return M.words().pause_tab.tab end,paused=function() return M.kit~=nil and M.kit.paused(true) end,
    open=open_menu,notice=function() M.say(M.words().pause_tab.stuck,T.en.pause_tab.stuck) end,
    ask=function(line) return M.ask(line)() end,close=M.pause_close})
RegisterConsoleCommandHandler('coop',function(_,parameters)
    M.typed_at=os.clock()
    -- A seventh word too, so a command that takes six (coop leviathan show) refuses one more.
    local name,a,b,c,d,e,f=parameters[1],parameters[2],parameters[3],parameters[4],parameters[5],parameters[6],
        parameters[7]
    if name=='mark' then a=table.concat(parameters,' ',2) end -- Its text, whatever the number of words.
    ExecuteInGameThread(function() M.run(name,a,b,c,d,e,f) end)
    return true
end)
end
