-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The key binds, with the Steam link only: the F-keys, Enter, the navigation keys, Esc and the mouse buttons.
return function(M)
local print,log=M.print,M.log
-- The keys (N5, D-UI2), only with the Steam link. Every F-key but F10, alone or with Shift, Ctrl or Alt, is bound once
-- (UE4SS cannot take a bind back), so a key changed in the menu works at once and the menu can take any of them; at
-- each press the settings say which action holds it: the menu, Host (host_key, none unless set), the status line,
-- Leave, the follow (follow_key, coop travel host), a race checkpoint (race_key, while a track is recorded; nothing
-- otherwise) or the bike (bike_key: EVE on it or off it). The host's question takes the navigation keys, Enter and Esc first while it is open, then the SBO lobby's
-- screens while one is open (menu_key closes B or C to the room; in the lobby world, menu_key opens B in place of the
-- co-op menu; E and the left tab key are C's tabs), then the Sessions screen while it is open (menu_key closes it; E
-- and the left tab key are its tabs, F its Refresh). Enter goes to the menu's key capture, then selects; the navigation
-- keys go to the menu while it is open only (UI-DESIGN 4.1: up arrow, W or Z; down arrow or S; left arrow, A or Q;
-- right arrow or D; Enter or Space; Esc), and to the co-op saves' question while it is open. The code box takes Enter
-- (join) and Esc (cancel). With all closed, Enter opens the chat's box, then sends, and Esc cancels; while the question
-- or a box is open our F-keys do nothing. The mouse buttons are the join popups' first while one is open (a left click
-- answers with the button under the mouse, a right click declines or closes), then the lobby's screens' and the menu's
-- (a left click selects the row under the mouse, a right click goes back), then the left one the co-op saves'
-- question's (the choice under the mouse); closed, they are the game's. A left click over the pause menu's Online tab
-- closes the pause menu and opens the co-op menu (ui/kit/pause_tab.lua). A key callback runs on UE4SS's key thread: it
-- only hands the press to the game thread, where the console's checks (coop off included) apply. A modified F-key is
-- bound before the plain one, so if UE4SS also calls the plain bind for a Shift+F5, the plain press that follows at
-- once is the same press, dropped. The status key gives a one-line summary, in the log in English and on screen in the
-- menu's words; coop status keeps the full status. An XInput pad, which no bind can take, comes through the native part
-- (main/input.lua's pad_event, each frame): View held 1 s does what menu_key does, D-pad Right held 1 s what bike_key
-- does, the D-pad or the left stick, A and B navigate the join popups, the menu and the co-op saves' question, B closes
-- the chat's box and the code box.
if M.settings then
    local K=require('core.keybind')
    local ACTIONS={'menu','host','status','leave','follow','race','bike'}
    if type(IsKeyBindRegistered)=='function' then
        for _,action in ipairs(ACTIONS) do
            local key=M.settings[action..'_key']
            local taken
            if key.mod then taken=IsKeyBindRegistered(Key[key.key],{ModifierKey[key.mod]})
            elseif key.key then taken=IsKeyBindRegistered(Key[key.key]) end
            if taken then log('keys: '..key.name..' is also bound by a mod loaded earlier; both run') end
        end
    end
    local modified_at={} -- F-key to when it was last pressed with a modifier (os.clock).
    local function pressed(name)
        local base=name:match('^%a+%+(F%d+)$')
        if base then modified_at[base]=os.clock()
        elseif modified_at[name] and os.clock()-modified_at[name]<0.2 then return end
        -- Typing, or the host's question open: our keys do nothing.
        if M.box.is_open() or M.code_box.is_open() or M.approval.is_open() or M.menu.capture(name) then return end
        for _,action in ipairs(ACTIONS) do
            if M.settings[action..'_key'].name==name then
                log('key '..name..': '..action)
                if action=='status' then
                    M.report(true,M.link.summary())
                    M.tell(M.link.summary)
                elseif action=='follow' then M.run('travel','host')
                elseif action=='race' then -- A checkpoint while a track is recorded; nothing otherwise.
                    if not M.off then
                        local ok,why=M.race.key()
                        if why then M.report(ok,why) end
                    end
                elseif action=='host' then M.run('host',M.settings.who_can_join) -- host_key: at once, never the screen.
                elseif action=='bike' then M.bike_press('bike_key')
                elseif action~='menu' then M.run(action)
                elseif M.off then M.report(false,M.OFF)
                elseif M.lobby.is_open() then
                    if M.lobby.is_open()~='popup' then M.lobby_room() end
                elseif M.open_screen() then M.open_screen().close()
                elseif M.sbo.in_lobby() and not M.menu.is_open() then M.lobby_key()
                else
                    local ok,why,shown,en=M.menu.toggle(M.booth.near(require('core.where').me()))
                    if why then M.report(ok,why); M.say(shown or why,en) end
                end
                return
            end
        end
    end
    local function bind(key,modifier,f)
        if modifier then RegisterKeyBind(Key[key],{ModifierKey[modifier]},f) else RegisterKeyBind(Key[key],f) end
    end
    for n=1,12 do
        for _,modifier in ipairs(n~=10 and {'SHIFT','CONTROL','ALT',false} or {}) do
            local name=K.text('F'..n,modifier or nil)
            bind('F'..n,modifier,function() ExecuteInGameThread(function() pressed(name) end) end)
        end
    end
    -- Alt+Enter (the fullscreen toggle) first: if UE4SS also calls the plain bind for it, that press is dropped.
    local alt_enter_at=-math.huge
    bind('RETURN','ALT',function() ExecuteInGameThread(function() alt_enter_at=os.clock() end) end)
    bind('RETURN',nil,function()
        ExecuteInGameThread(function()
            if os.clock()-alt_enter_at<0.2 then return end
            if M.approval.is_open() then M.approval.nav('select')
            elseif M.lobby.is_open() then M.lobby.nav('select')
            elseif M.open_screen() then M.open_screen().nav('select')
            elseif M.menu.is_open() then
                if not M.menu.capture('Enter') then M.menu.nav('select') end
            elseif M.saves_ui.is_open() then M.saves_ui.nav('select')
            elseif M.code_box.is_open() then M.code_box.send()
            elseif M.box.is_open() then M.box.send()
            -- Paused or on a game screen at the press, or SB's interaction on EVE in a hall (an SB chair's Get up
            -- choice): that Enter was the game's (Resume, a choice), never the chat's.
            elseif not M.off and M.hud_shown and not M.kit.paused() and not (M.sbo and M.sbo.busy()) then
                M.chat_asked=os.clock()
            end
        end)
    end)
    -- The lobby's screens take them all, and on C (L4-menus-b-c 3.6) E is the right tab and Q the left one, or A on an
    -- AZERTY keyboard, where Q is left; the other of A and Q stays left. The Sessions screen takes them the same way,
    -- with F for Refresh (the key Stellar Blade binds to the UI_FaceButton_Top action its Refresh hint shows). The Create
    -- a session screen takes the navigation keys only. E and F do nothing anywhere else.
    local function lobby_key(key,word)
        local screen=M.lobby.is_open() and M.lobby or M.open_screen()
        if M.lobby.is_open()=='settings' or screen==M.sessions then
            if key=='E' then word='tab_right' elseif key==(M.kit.azerty() and 'A' or 'Q') then word='tab_left' end
        end
        if key=='F' then word=screen==M.sessions and 'refresh' or nil end
        if word and screen then screen.nav(word) end -- Closed on the game thread meanwhile: nothing.
    end
    for _,nav in ipairs({{'UP_ARROW','up'},{'W','up'},{'Z','up'},{'DOWN_ARROW','down'},{'S','down'},
            {'LEFT_ARROW','left'},{'A','left'},{'Q','left'},{'RIGHT_ARROW','right'},{'D','right'},
            {'SPACE','select'},{'E'},{'F'}}) do
        bind(nav[1],nil,function()
            -- The host's question opens on its own: the arrows only, never W, S or Space (walking, jumping, the menu).
            if M.approval.is_open() then
                if nav[1]:find('_ARROW$') then ExecuteInGameThread(function() M.approval.nav(nav[2]) end) end
            elseif M.lobby.is_open() or M.open_screen() then
                ExecuteInGameThread(function() lobby_key(nav[1],nav[2]) end)
            elseif not nav[2] then return
            elseif M.menu.is_open() then ExecuteInGameThread(function() M.menu.nav(nav[2]) end)
            elseif M.saves_ui.is_open() then ExecuteInGameThread(function() M.saves_ui.nav(nav[2]) end) end
        end)
    end
    bind('ESCAPE',nil,function()
        if M.approval.is_open() then ExecuteInGameThread(function() M.approval.nav('back') end)
        elseif M.lobby.is_open() then ExecuteInGameThread(function() M.lobby.nav('back') end)
        elseif M.open_screen() then ExecuteInGameThread(function()
            local screen=M.open_screen() -- Still open on the game thread.
            if screen then screen.nav('back') end
        end)
        elseif M.menu.is_open() then ExecuteInGameThread(function() M.menu.nav('back') end)
        elseif M.saves_ui.is_open() then ExecuteInGameThread(function() M.saves_ui.nav('back') end)
        elseif M.code_box.is_open() then ExecuteInGameThread(M.code_box.cancel)
        elseif M.box.is_open() then ExecuteInGameThread(M.box.cancel) end
    end)
    -- A left click answers a join popup with the button under the mouse while one is open, else it is the lobby's
    -- while one of its screens is open, else it selects the co-op menu's row under the mouse, or answers the co-op
    -- saves' question with the choice under it; a right click declines or closes a join popup, goes back in the
    -- lobby's screens or the menu (the kit's input leaves Slate the mouse; UE4SS calls the binds whatever has it).
    -- While our UI holds the game's input, either button first has the kit put our focus back (a click on none of our
    -- widgets gives it to the game's viewport). No gamepad button can be bound: the pad comes through the native part.
    bind('LEFT_MOUSE_BUTTON',nil,function()
        if M.pause_tab.armed() then ExecuteInGameThread(function() M.pause_tab.click(os.clock()) end) end
        if not (M.kit.holding() or M.menu.is_open() or M.saves_ui.is_open()) then return end
        ExecuteInGameThread(function()
            M.kit.click()
            if M.approval.is_open() then M.approval.nav('click')
            elseif M.lobby.is_open() then M.lobby.nav('click')
            elseif M.open_screen() then M.open_screen().nav('click')
            elseif M.menu.is_open() then M.menu.nav('click')
            elseif M.saves_ui.is_open() then M.saves_ui.nav('click') end
        end)
    end)
    bind('RIGHT_MOUSE_BUTTON',nil,function()
        if M.kit.holding() or M.menu.is_open() then
            ExecuteInGameThread(function()
                M.kit.click()
                if M.approval.is_open() then M.approval.nav('back')
                elseif M.lobby.is_open() then M.lobby.nav('back')
                elseif M.open_screen() then M.open_screen().nav('back') else M.menu.nav('back') end
            end)
        end
    end)
end
end
