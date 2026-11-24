-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- An XInput pad (the native part's coop_pad) and the mouse in the co-op UI, through main.lua on fixture.lua's fake kit;
-- the focus watchdog; coop ui reset and coop ui off; the Lua frame time, logged once a minute with the UI up; and the
-- gap lines.
dofile('tests/lua/main/fixture.lua')
-- An XInput pad (the native part reads it; pad_test tests its events): each frame up to 8 events, routed as the keys
-- route theirs. With nothing open in a world, View held opens the co-op menu as menu_key does, its refusals said the
-- same way; the menu takes the six navigation words and View held closes it; the co-op saves' question takes up, down,
-- select and back; LB, RB and Y are taken and do nothing, as nothing here has tabs or a Refresh; the Online tab's
-- event (12) goes to the pause tab only. The host's question
-- takes the D-pad, A and B from 1 s after it shows (a left or right click too), never View held. Nothing while the menu
-- waits for a key (B still stops the wait, A puts back its default), at the title with nothing open, or after coop off;
-- the chat box and the code box take only B, which closes them. An older DLL: one log line, no pad. The Online tab's
-- close goes to the native part's coop_pause_close; an older DLL without it: no close can work.
;(function()
    local function pad(...) for _,e in ipairs({...}) do pd.q[#pd.q+1]=e end; loops[1].f() end
    settings_text,status_text,link_mode,in_world,photo_mode='',plain,'none',false,false
    load_main(true)
    assert(not logged('Native pad unavailable'),'The export found')
    pad(7); assert(#pd.q==0 and not kit_shown.menu and not logged('pad: menu'),'No world: nothing')
    in_world,kit_ready,kit_paused=true,true,true; quarter()
    pad(7)
    assert(logged('pad: menu') and last()=='[StellarCoop] STOP: the co-op menu does not open while the game is paused '
        ..'or shows a menu\n' and fed()=='The co-op menu does not open while the game is paused or shows a menu.',last())
    kit_paused=false
    pad(7); assert(kit_shown.menu and kit_input and focus()=='Host a session' and kit_sounds[#kit_sounds]=='open')
    pad(2); assert(focus()=='Find a session' and kit_sounds[#kit_sounds]=='move')
    pad(1); assert(focus()=='Host a session')
    pad(7); assert(not kit_shown.menu,'View held again closes it')
    pad(7); pad(6); assert(not kit_shown.menu and kit_sounds[#kit_sounds-1]=='back','B on the main page closes it')
    -- LB, RB and Y (8, 9 and 11 values back: tab_left, tab_right and refresh) are taken like the others; the co-op
    -- menu has no tabs and no Refresh, so they change nothing there. The down after them in the same frame still
    -- moves.
    pad(7); assert(kit_shown.menu and focus()=='Host a session')
    local sounds=#kit_sounds
    pad(8,9,11,2)
    assert(#pd.q==0 and focus()=='Find a session' and #kit_sounds==sounds+1 and not logged('pad: error'),
        'LB, RB and Y taken, nothing done')
    pad(7); assert(not kit_shown.menu)
    -- 12 (pause_tab, the Online tab's RB from the native part) goes to the pause tab only, never to a screen's nav.
    pad(7); assert(kit_shown.menu and focus()=='Host a session')
    pad(12)
    assert(kit_shown.menu and focus()=='Host a session' and #pt.events==1
        and not table.concat(printed,'|'):find('pad: error',1,true),
        'The Online tab event changes nothing in the open co-op menu')
    -- 13 (wheel, D-pad Left held 0.3 s) never reaches a screen's nav either.
    local moved=#kit_sounds
    pad(13)
    assert(kit_shown.menu and focus()=='Host a session' and #kit_sounds==moved and not logged('pad: error'),
        'The wheel event changes nothing in the open co-op menu')
    pad(7)
    -- The tab's close: the native part's coop_pause_close, its answer read from how many of three arguments come back.
    pc.answer=1; assert(pt.o.close()==true and pc.calls==1,'1: SB closed it')
    pc.answer=2
    local ok,why,lasting=pt.o.close()
    assert(not ok and why=='the game has no pause menu open' and not lasting,'2: none open, for now')
    pc.answer=3; ok,why,lasting=pt.o.close()
    assert(not ok and why:find('refused the close',1,true) and lasting,'3: off for good')
    pc.answer=1
    -- At most 8 a frame: the rest the next frame, where a 0 ends the taking.
    pad(7); assert(kit_shown.menu)
    local calls=pd.calls
    for _=1,10 do pd.q[#pd.q+1]=2 end
    loops[1].f(); assert(pd.calls==calls+8 and #pd.q==2,pd.calls-calls)
    loops[1].f(); assert(pd.calls==calls+11 and #pd.q==0,pd.calls-calls)
    -- A selects; left and right change a value row; a key row waiting for a key takes no pad event but B and A.
    to('Options'); pad(5)
    assert(focus()=='Open this menu')
    pad(5); assert(select(2,focus())=='Press a key')
    pad(2,1,3,4,7); assert(kit_shown.menu and focus()=='Open this menu' and select(2,focus())=='Press a key',
        'Waiting: the pad does nothing')
    pad(6); assert(select(2,focus())=='F5' and kit_shown.menu,'B: not waiting')
    pad(5,5); assert(select(2,focus())=='F5' and kit_shown.menu and settings_text:find('menu_key=F5',1,true),
        'A: the default')
    to('Photo sync'); assert(select(2,focus())=='Both')
    pad(4); assert(select(2,focus())=='Notice only' and settings_text:find('photo_sync=notice',1,true))
    pad(3); assert(select(2,focus())=='Both')
    pad(6); assert(focus()=='Options' and kit_shown.menu,'B: back to the main page')
    pad(6); assert(not kit_shown.menu)
    -- The code box (Join with a code): typing, the pad takes only B, which closes it as Esc does.
    key('F5'); to('Join with a code'); key('RETURN'); assert(kit_shown.code and not kit_shown.menu)
    pad(5,2,7); assert(kit_shown.code and not kit_shown.menu,'The code box: A, down and View held do nothing')
    pad(6); assert(not kit_shown.code and not kit_shown.menu,'B closes it')
    -- The chat's box, in a session: the same.
    link_mode,chat_active='host',true
    key('RETURN'); clock=clock+0.25; loops[1].f(); assert(kit_shown.chat) -- Quarters: the frame time test below.
    pad(5,7); assert(kit_shown.chat and not kit_shown.menu,'The chat box: A and View held do nothing')
    pad(6); assert(not kit_shown.chat and not kit_shown.menu,'B closes it')
    -- The host's question: for 1 s after it shows every pad event does nothing (its buttons are the game's in a fight);
    -- then the D-pad moves, A answers with the focused button and B declines. View held never does anything there.
    link_pending={id='76561198000000008',name='Two'}
    quarter(); assert(kit_shown.ask)
    local n=#asked
    pad(5,6,1,2,7); assert(kit_shown.ask and #asked==n and not kit_shown.menu,'The host\'s question: 1 s with nothing')
    clock=clock+1
    pad(7); assert(kit_shown.ask and #asked==n and not kit_shown.menu,'View held: nothing')
    pad(5); assert(not kit_shown.ask and asked[#asked]=='deny 76561198000000008','A on Decline, focused: denied')
    link_pending={id='76561198000000009',name='Three'}
    quarter(); clock=clock+1
    pad(1,5); assert(not kit_shown.ask and asked[#asked]=='allow 76561198000000009','Up, then A: let in')
    -- The Online tab's event under the question: the pause tab's only; the focus stays on Decline.
    link_pending={id='76561198000000020',name='Eight'}
    quarter(); clock=clock+1
    pad(12); assert(kit_shown.ask and #pt.events==2,'The question stays')
    pad(5); assert(not kit_shown.ask and asked[#asked]=='deny 76561198000000020','A on Decline, still focused: denied')
    link_pending={id='76561198000000010',name='Four'}
    quarter(); clock=clock+1
    pad(6); assert(not kit_shown.ask and asked[#asked]=='deny 76561198000000010','B: denied')
    -- The mouse on it: a left click on its Accept row lets the player in, a right click declines.
    link_pending={id='76561198000000011',name='Five'}
    quarter(); clock=clock+1
    kit_views.ask.rows[1].hover=true; key('LEFT_MOUSE_BUTTON'); kit_views.ask.rows[1].hover=nil
    assert(not kit_shown.ask and asked[#asked]=='allow 76561198000000011','A click on Accept: let in')
    link_pending={id='76561198000000012',name='Six'}
    quarter(); clock=clock+1
    key('RIGHT_MOUSE_BUTTON'); assert(not kit_shown.ask and asked[#asked]=='deny 76561198000000012','Right click: denied')
    link_pending={id='76561198000000013',name='Seven'}
    quarter(); assert(kit_shown.ask)
    coop('ui','reset'); assert(not kit_shown.ask and asked[#asked]=='deny 76561198000000013')
    link_mode,chat_active,link_pending='none',false,nil
    -- coop off: no event taken.
    coop('off'); calls=pd.calls
    pad(7); assert(pd.calls==calls and not kit_shown.menu,'Off: the pad is not read')
    pd.q={}
    -- The co-op saves' question at the title: up, down, select and back; View held, left and right do nothing.
    in_world,at_title=false,true
    saves_info={saves='main',convert='idle',slot='none',steamid='76561198000000001'}
    load_main(true)
    local saves_view=kit_views.saves
    kit_ready=true; quarter(); quarter()
    assert(kit_shown.saves and saves_view.rows[1].st=='focus')
    pad(7,3,4,8,9); assert(kit_shown.saves and saves_view.rows[1].st=='focus' and not kit_shown.menu
        and not logged('pad: menu'))
    pad(2); assert(saves_view.rows[2].st=='focus')
    local before=#asked
    pad(5); assert(kit_shown.saves and #asked==before,'A within 1 s of the question showing: nothing')
    clock=clock+1
    pad(1); pad(5); clock=clock+0.25; loops[1].f()
    assert(asked[#asked]=='saves coop' and kit_holder=='saves','A chose')
    pad(6); assert(asked[#asked]=='saves main' and not kit_shown.saves,'B: withdrawn, closed')
    pad(7); assert(not kit_shown.menu and not logged('pad: menu'),'The title, nothing open: View held does nothing')
    saves_info,at_title,kit_ready={},false,false
    -- An older DLL without coop_pad: one log line, the rest as before.
    pd.missing=true
    load_main(true)
    local lines=0
    for _,line in ipairs(printed) do if line:find('Native pad unavailable',1,true) then lines=lines+1 end end
    assert(lines==1 and logged('Native pad unavailable (no controller in the co-op menu): not exported'),
        table.concat(printed,'|'))
    -- One without coop_pause_close: the Online tab's close can never work.
    pc.missing=true
    load_main(true)
    local ok,why,lasting=pt.o.close()
    assert(not ok and why=='the native part has no coop_pause_close (not exported)' and lasting and pc.calls==0)
    pc.missing=false
    in_world,kit_ready=true,true; quarter()
    loops[1].f(); key('F5'); assert(kit_shown.menu and pd.calls==0,'The keys still work')
    pd.missing,in_world,kit_ready=false,false,false
end)()

-- The mouse in the co-op menu (ui/kit/menu.lua for real; the fake kit's rows say whether the mouse is over them). Each
-- 100 ms the row the mouse moved onto takes the focus (the move sound, drawn); the row under it as the menu opens, or a
-- mouse resting while the keys move, never takes it; a header or an empty slot, nothing. A left click selects the row
-- under the mouse as Enter does (Leave still asks twice), on a header or no row nothing; a right click goes back,
-- closing it on the main page. Closed, both buttons are the game's: nothing queued (the left one is the saves'
-- question's, or the pause menu's Online tab's while a pause menu holds it).
;(function()
    settings_text,status_text,link_mode,in_world,photo_mode='',plain,'none',true,false
    load_main(true)
    kit_ready=true; quarter()
    -- Clock steps in binary fractions: the frame time test below needs sums it can take back exactly.
    local rows=menu_view.rows -- Drawn: SESSION, Host, Find a session, Join with a code, SETTINGS, Options, HELP,
    local function hover(i) -- report, Close. The mouse over slot i (nil: none), then a frame.
        for j,r in ipairs(rows) do r.hover=j==i or nil end
        loops[1].f()
    end
    local queued_at=executes
    press('LEFT_MOUSE_BUTTON'); press('RIGHT_MOUSE_BUTTON'); assert(executes==queued_at,'Closed: not queued')
    -- A pause menu holding the Online tab arms it: a left click then goes to the tab on the game thread.
    pt.armed=true
    key('LEFT_MOUSE_BUTTON'); assert(#pt.clicks==1 and not kit_shown.menu,'The Online tab takes the click')
    pt.armed=false
    rows[3].hover=true
    key('F5'); hover(3); assert(focus()=='Host a session','Under the mouse as it opens: not taken')
    local sounds=#kit_sounds
    clock=clock+0.125; hover(4)
    assert(focus()=='Join with a code' and #kit_sounds==sounds+1 and kit_sounds[#kit_sounds]=='move','Moved onto')
    key('DOWN_ARROW'); assert(focus()=='Options')
    for _=1,3 do clock=clock+0.125; hover(4) end
    assert(focus()=='Options','A resting mouse leaves the keys alone')
    clock=clock+0.125; hover(2); assert(focus()=='Host a session')
    clock=clock+0.0625; hover(3); assert(focus()=='Host a session','Every 100 ms only')
    clock=clock+0.0625; hover(3); assert(focus()=='Find a session')
    sounds=#kit_sounds
    for _,i in ipairs({5,15,false}) do clock=clock+0.125; hover(i or nil) end
    assert(focus()=='Find a session' and #kit_sounds==sounds,'A header, an empty slot, no row: nothing')
    -- Clicks: on a header or no row nothing; on a row, that row selected (Options opens its page), wherever the keys
    -- left the focus.
    hover(5); key('LEFT_MOUSE_BUTTON'); hover(nil); key('LEFT_MOUSE_BUTTON')
    assert(kit_shown.menu and focus()=='Find a session' and #kit_sounds==sounds,'A click on no row: nothing')
    local clicks=#kit_calls
    hover(6); key('LEFT_MOUSE_BUTTON')
    assert(focus()=='Open this menu' and kit_sounds[#kit_sounds]=='select','A click selects the row under the mouse')
    assert(kit_said('click nil')>clicks,'The kit puts our focus back')
    -- A key row waiting for a key: the mouse moves nothing, and the row it moved onto meanwhile is not taken after; a
    -- right click stops the wait.
    key('RETURN'); assert(select(2,focus())=='Press a key')
    clock=clock+0.125; hover(3); clock=clock+0.125; hover(4)
    assert(focus()=='Open this menu' and select(2,focus())=='Press a key','Waiting: the mouse moves nothing')
    key('RIGHT_MOUSE_BUTTON'); clock=clock+0.125; hover(4)
    assert(focus()=='Open this menu' and select(2,focus())~='Press a key','Right click: not waiting, nothing taken')
    -- The mouse onto the last slot scrolls the page down by one, onto the first up by one. The keys take the page one
    -- row down first: the last slot then holds a row, not the PARTNER header.
    for _=1,19 do key('DOWN_ARROW') end
    assert(focus()=='Name tag' and rows[1].l=='Gun mode',focus()..' / '..tostring(rows[1].l))
    local last=rows[15].l
    clock=clock+0.125; hover(15)
    assert(focus()==last and rows[14].l==last and rows[15].l~=last,'The last slot: one row down')
    clock=clock+0.125; hover(1)
    assert(focus()=='Bring out or put away the rifle' and rows[1].l=='Gun mode' and rows[2].st=='focus',
        'The first slot: one row up')
    key('RIGHT_MOUSE_BUTTON'); assert(kit_shown.menu and focus()=='Options','Right click: back to the main page')
    key('RIGHT_MOUSE_BUTTON'); assert(not kit_shown.menu and kit_sounds[#kit_sounds-1]=='back','And it closes')
    -- Hosting: Leave on two clicks within 3 s, as with Enter.
    link_mode='host'
    key('F5'); hover(2)
    local n=#asked
    key('LEFT_MOUSE_BUTTON'); assert(#asked==n and menu_view.note.s=='Select again within 3 s to leave.')
    clock=clock+1; key('LEFT_MOUSE_BUTTON'); assert(asked[#asked]=='leave','The second click leaves')
    for i,r in ipairs(rows) do if r.l=='Close' then hover(i) end end
    key('LEFT_MOUSE_BUTTON'); assert(not kit_shown.menu,'Close')
    link_mode,in_world,kit_ready='none',false,false
end)()

-- Spectate (fight/enemies/spectate.lua) while our EVE is down in a shared boss fight: the pad's left and right that
-- nothing else took switch the member it watches; the co-op menu open takes them first. The left and right arrows the
-- same way, never A, Q or D, nor while the code box or the chat box is open; nothing while it does not watch.
;(function()
    local function pad(...) for _,e in ipairs({...}) do pd.q[#pd.q+1]=e end; loops[1].f() end
    settings_text,status_text,link_mode,in_world,photo_mode='',plain,'none',true,false
    load_main(true)
    kit_ready=true; quarter()
    pad(3,4); assert(#sp.switches==0,'Not watching: nothing')
    key('LEFT_ARROW'); assert(#sp.switches==0)
    sp.watching=true
    pad(3); assert(table.concat(sp.switches,'|')=='left','left: '..table.concat(sp.switches,'|'))
    pad(4); assert(table.concat(sp.switches,'|')=='left|right')
    pad(1,2); assert(#sp.switches==2,'up and down: nothing')
    key('F5'); assert(kit_shown.menu and focus()=='Host a session')
    pad(3,4); assert(#sp.switches==2 and kit_shown.menu,'The menu takes them')
    key('LEFT_ARROW'); assert(#sp.switches==2 and kit_shown.menu,'The menu takes the arrow')
    key('F5'); assert(not kit_shown.menu)
    key('LEFT_ARROW'); key('RIGHT_ARROW')
    assert(table.concat(sp.switches,'|')=='left|right|left|right',table.concat(sp.switches,'|'))
    key('A'); key('Q'); key('D'); key('UP_ARROW'); key('DOWN_ARROW')
    assert(#sp.switches==4,'A, Q, D and the up and down arrows: no switch')
    -- A box that takes typing keeps the arrows for its cursor: the code box (Join with a code), then the chat box.
    key('F5'); to('Join with a code'); key('RETURN'); assert(kit_shown.code and not kit_shown.menu)
    key('LEFT_ARROW'); key('RIGHT_ARROW')
    assert(#sp.switches==4 and kit_shown.code,'The code box keeps the arrows: '..table.concat(sp.switches,'|'))
    pad(6); assert(not kit_shown.code)
    link_mode,chat_active='host',true
    key('RETURN'); clock=clock+0.25; loops[1].f(); assert(kit_shown.chat)
    key('LEFT_ARROW'); key('RIGHT_ARROW')
    assert(#sp.switches==4 and kit_shown.chat,'The chat box keeps the arrows: '..table.concat(sp.switches,'|'))
    pad(6); assert(not kit_shown.chat)
    key('RIGHT_ARROW')
    assert(table.concat(sp.switches,'|')=='left|right|left|right|right','The box closed: the arrow switches')
    link_mode,chat_active='none',false
    -- The camera's frame each frame, right after the ghost's place (main/frame.lua).
    local frames=sp.frames
    loops[1].f()
    assert(sp.frames==frames+1 and sp.placed==frames,
        'One frame call after the place: '..sp.frames..' '..tostring(sp.placed))
    sp.watching=false
    in_world,kit_ready=false,false
end)()

-- The focus watchdog (the kit's lost(); ui_kit_test tests when it fires): the 250 ms loop then runs what coop ui reset
-- runs, before the menu's slow (the menu closed, an open host's question denied, the game's input given back now), and
-- logs who lost the focus; no notice on screen.
;(function()
    settings_text,status_text,link_mode,in_world,photo_mode='',plain,'none',true,false
    load_main(true)
    kit_ready=true; quarter()
    key('F5'); assert(kit_shown.menu and kit_input)
    local calls,feed,lines=#kit_calls,#chat_calls,#said
    quarter(); assert(kit_shown.menu and not kit_said('reset nil'),'Not fired: nothing')
    kit_lost='menu'; quarter()
    assert(not kit_shown.menu and kit_said('reset nil')>kit_said('slow true') and kit_said('slow true')>calls,
        'Closed after the kit\'s slow, the input given back now')
    assert(logged('focus watchdog: menu lost the focus for 1 s: co-op UI closed, the game has its input back'),
        'Logged')
    for i=feed+1,#chat_calls do assert(not chat_calls[i]:find('focus',1,true),'Nothing in the feed') end
    for i=lines+1,#said do assert(not said[i]:find('focus',1,true),'Nothing on the line above EVE') end
    link_mode='host'
    link_pending={id='76561198000000004',name='Six'}
    quarter(); assert(kit_shown.ask and kit_holder=='ask')
    -- Under the host's question, in the second after it shows, either mouse button only has the kit put our focus back.
    local asks,clicks=#asked,0
    calls=#kit_calls
    key('LEFT_MOUSE_BUTTON'); key('RIGHT_MOUSE_BUTTON')
    for i=calls+1,#kit_calls do if kit_calls[i]=='click nil' then clicks=clicks+1 end end
    assert(clicks==2 and kit_shown.ask and #asked==asks,'Our focus back, nothing answered')
    kit_lost='ask'; quarter()
    assert(asked[#asked]=='deny 76561198000000004' and not kit_shown.ask
        and logged('focus watchdog: ask lost the focus for 1 s: co-op UI closed, the game has its input back'))
    link_mode,link_pending,in_world,kit_ready='none',nil,false,false
end)()

-- coop ui reset (UI-DESIGN 7.5): the menu (or the chat's box) closed and the game's input given back at once, whoever
-- holds it; coop ui off (7.6): the kit stopped, the menu and the box with it.
settings_text,status_text,link_mode,in_world,photo_mode='',plain,'none',true,false
load_main(true)
kit_ready=true; quarter()
-- Once a minute with the UI up: the Lua frame time of the ghost's place, the Doro look and the UI's ticks, over the
-- minute's frames; then the longest frame and 250 ms pass with their counts over 16 ms and over 50 ms, and the longest
-- call of mxiii, lion, scene, booth and kit.slow. Here one frame's lion tick takes 20 ms and one pass's kit.slow 62.5
-- ms; the next minute starts from nothing.
local start=clock
loops[1].f(); clock=clock+30; li.cost=0.02; loops[1].f(); li.cost=nil
kit_slow_cost=0.0625; quarter(); kit_slow_cost=nil
assert(not logged('Lua frame time'),'Not before a minute')
clock=start+60; loops[1].f()
assert(last()=='[StellarCoop] Lua frame time, last 60 s: ghost 0.000 ms, doro 0.000 ms, race 0.000 ms, UI 0.000 ms a '
    ..'frame (3 frames); longest frame 20.0 ms (1 over 16 ms, 0 over 50 ms): mxiii 0.0 ms, lion 20.0 ms, scene 0.0 ms; '
    ..'longest 250 ms pass 62.5 ms (1 over 16 ms, 1 over 50 ms): booth 0.0 ms, kit.slow 62.5 ms\n',last())
clock=start+120; loops[1].f()
assert(last()=='[StellarCoop] Lua frame time, last 60 s: ghost 0.000 ms, doro 0.000 ms, race 0.000 ms, UI 0.000 ms a '
    ..'frame (1 frames); longest frame 0.0 ms (0 over 16 ms, 0 over 50 ms): mxiii 0.0 ms, lion 0.0 ms, scene 0.0 ms; '
    ..'longest 250 ms pass 0.0 ms (0 over 16 ms, 0 over 50 ms): booth 0.0 ms, kit.slow 0.0 ms\n',last())
start=clock
local lines=#printed
kit_ready=false; clock=start+120; loops[1].f(); kit_ready=true
assert(not table.concat(printed,'|',lines+1):find('Lua frame time',1,true),'Not while the UI is down (a map loads, '
    ..'warming)')
-- A frame that starts over 100 ms after the last one logs a gap line, the Lua twin of the native part's
-- (coop-link.log): the 250 ms pass that ran in between, with its kit.slow and booth calls, or none. A pass before the
-- last frame is not in the gap. At most 200 lines a minute from the first, then one line says so; the next minute logs
-- again.
lines=#printed
clock=clock+60; loops[1].f() -- A minute after the lines above: this one starts a minute of its own.
assert(printed[lines+1]=='[StellarCoop] gap 60000 ms before this frame; no pass in it\n',printed[lines+1])
clock=clock+0.1; loops[1].f()
assert(not last():find('gap',1,true),'100 ms is no gap')
kit_slow_cost=0.125; quarter(); kit_slow_cost=nil
loops[1].f()
assert(last()=='[StellarCoop] gap 375 ms before this frame; 250 ms pass in it: 125 ms (kit.slow 125, booth 0)\n',last())
clock=clock+0.25; loops[1].f()
assert(last()=='[StellarCoop] gap 250 ms before this frame; no pass in it\n',last())
quarter(); loops[1].f(); clock=clock+0.5; loops[1].f()
assert(last()=='[StellarCoop] gap 500 ms before this frame; no pass in it\n',last())
lines=#printed
for _=1,200 do clock=clock+0.2; loops[1].f() end -- 40 s of a load at 5 frames a second.
local gaps={}
for i=lines+1,#printed do if printed[i]:find('gap',1,true) then gaps[#gaps+1]=printed[i] end end
assert(#gaps==196 and gaps[196]=='[StellarCoop] gap lines: 200 this minute, no more until it ends\n',#gaps..' '..
    tostring(gaps[196]))
lines=#printed
clock=clock+60; loops[1].f()
assert(printed[lines+1]=='[StellarCoop] gap 60000 ms before this frame; no pass in it\n',printed[lines+1])
key('F5'); assert(kit_shown.menu and kit_input)
coop('ui','reset')
assert(not kit_shown.menu and kit_calls[#kit_calls]=='reset nil' and last()=='[StellarCoop] OK: co-op UI reset: menu '
    ..'and chat closed, the game has its input back\n',last())
key('F5'); assert(kit_shown.menu)
coop('ui','off')
assert(kit_calls[#kit_calls]=='stop nil' and last():find('OK: co-op UI off until the mod reloads',1,true),last())
in_world=false

-- The emote wheel (eve/ui/wheel.lua on ui/kit/wheel.lua): emote_key (F2) opens it in a world with nothing open; while
-- it is open the F-keys, Enter and the navigation keys do nothing but Q, A and E (its pages), Esc (cancel) and the
-- mouse buttons (a left click plays, a right click is the next page); the release of F2 plays the slot pointed at
-- through coop emote. D-pad Left held (the native part's 13) opens it with emote_pad=dpad_left; LB, RB, A and B are
-- its own then; the rest is dropped. EVE busy: not opened, said. emote_key=none and emote_pad=off turn each off;
-- after coop off, F2 is refused as a command is. An older DLL without the reads: refused, said once a press.
;(function()
    local function pad(...) for _,e in ipairs({...}) do pd.q[#pd.q+1]=e end; loops[1].f() end
    local function frame() loops[1].f() end
    local function em_logged(text) return table.concat(printed,'|'):find('[StellarCoop][EM] '..text..'\n',1,true)~=nil end
    settings_text,status_text,link_mode,in_world,photo_mode='',plain,'none',true,false
    load_main(true)
    kit_ready=true; quarter()
    wh.fkey=2
    key('F2')
    assert(logged('key F2: emote') and kit_shown.wheel and kit_holder=='wheel' and wh.centred==1
        and kit_sounds[#kit_sounds]=='wheel_open' and em_logged('wheel: open on Greeting (F2)'))
    key('F5'); key('RETURN'); key('S')
    assert(not kit_shown.menu and not logged('key F5: menu'),'Its keys only')
    key('E'); assert(kit_sounds[#kit_sounds]=='change' and kit_views.wheel.page.s=='Cut','E: the next page')
    key('Q'); assert(kit_views.wheel.page.s=='Greeting','Q: the previous one')
    key('RIGHT_MOUSE_BUTTON'); assert(kit_views.wheel.page.s=='Cut','A right click: the next page')
    key('A'); assert(kit_views.wheel.page.s=='Greeting','A: the previous one too')
    wh.stick=19 -- 92.5 degrees: slot 2 of a 3-slot ring, the left wave.
    frame()
    assert(kit_sounds[#kit_sounds]=='wheel_move' and kit_views.wheel.name.s=='Wave (left)')
    wh.stick,wh.fkey=0,0
    frame()
    assert(not kit_shown.wheel and em.cmds[#em.cmds][1]=='wave' and logged('OK: em wave')
        and em_logged('wheel: emote wave (release)'))
    clock=clock+0.2; frame()
    assert(kit_input==false,'The game\'s input back 150 ms after')
    -- Esc cancels; a left click plays the slot pointed at.
    wh.fkey=2
    key('F2'); key('ESCAPE')
    assert(not kit_shown.wheel and em_logged('wheel: closed (cancelled)'))
    clock=clock+0.2; frame()
    local cmds=#em.cmds
    key('F2'); wh.stick=1; frame(); key('LEFT_MOUSE_BUTTON')
    assert(not kit_shown.wheel and #em.cmds==cmds+1 and em.cmds[#em.cmds][1]=='salute','A left click plays')
    wh.stick=0; clock=clock+0.2; frame()
    -- The pad: D-pad Left held opens it; LB and RB its pages; B cancels; the stick and A play; menu is dropped.
    wh.held=1
    pad(13)
    assert(kit_shown.wheel and logged('pad: wheel') and em_logged('wheel: open on Greeting (pad)'))
    pad(9); assert(kit_views.wheel.page.s=='Cut','RB')
    pad(7,1); assert(kit_shown.wheel and not kit_shown.menu,'View held and up: dropped')
    pad(6); assert(not kit_shown.wheel,'B')
    clock=clock+0.2; frame()
    pad(13); wh.stick=1; frame(); pad(5)
    assert(not kit_shown.wheel and em.cmds[#em.cmds][1]=='kaligrab','A plays, on the page last used')
    wh.stick=0; clock=clock+0.2; frame()
    pad(13); wh.held=0; frame()
    assert(not kit_shown.wheel and em_logged('wheel: closed (released with nothing pointed at)'))
    clock=clock+0.2; frame()
    -- EVE busy: not opened, said.
    em.busy='EVE is in combat'
    key('F2')
    assert(not kit_shown.wheel and em_logged('wheel: not opened: EVE is in combat')
        and fed()=='No emote now: EVE is busy.')
    em.busy=nil
    -- D-pad Left held in one of the game's own screens: no wheel, no notice in the feed, one log line.
    do
        local before=fed()
        kit_paused=true
        pad(13)
        assert(not kit_shown.wheel and fed()==before
            and logged('pad: wheel ignored: the game is paused or shows one of its screens'),'The game\'s own menu')
        kit_paused=false
    end
    -- emote_pad=off and emote_key=none.
    settings_text='emote_pad=off\nemote_key=none\n'
    load_main(true)
    kit_ready=true; quarter()
    pad(13); key('F2')
    assert(not kit_shown.wheel and logged('pad: wheel ignored: emote_pad is off') and not logged('key F2: emote'))
    -- An older DLL without the reads: one log line, the wheel refused with its notice.
    settings_text=''
    wh.missing=true
    load_main(true)
    kit_ready=true; quarter()
    assert(logged('Native emote wheel reads unavailable (no emote wheel): coop_stick: not exported'))
    key('F2')
    assert(not kit_shown.wheel and em_logged('wheel: not opened: the native part has no coop_stick, coop_held or '
        ..'coop_fkey') and fed()=='The emote wheel needs the native part of this version.')
    wh.missing=false
    -- coop off: F2 refused as a command is.
    load_main(true)
    kit_ready=true; quarter()
    coop('off')
    key('F2')
    assert(last()=='[StellarCoop] STOP: '..'coop off is active until the game restarts\n' and not kit_shown.wheel)
end)()

-- The controllers the mod reads, said the same way in INSTALL.md and docs/players/interface.md (any controller the game
-- reads, XInput only as the fallback); no comment still says only an XInput pad can answer the saves' question or the
-- guide.
local function text(path) local f=assert(io.open(path)); local t=f:read('a'); f:close(); return t end
for _,doc in ipairs({'INSTALL.md','docs/players/interface.md'}) do
    assert(text(doc):find('any controller the game reads',1,true),doc..' still says only XInput controllers work')
end
for _,lua in ipairs({'online/saves/saves.lua','ui/kit/guide.lua'}) do
    assert(not text('mod/StellarCoop/Scripts/'..lua):find('not XInput',1,true),lua..': a stale XInput note')
end
io.stdout:write('input_test ok\n')
