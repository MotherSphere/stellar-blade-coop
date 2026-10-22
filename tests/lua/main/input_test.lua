-- An XInput pad (the native part's coop_pad) and the mouse in the co-op UI, through main.lua on fixture.lua's fake kit;
-- the focus watchdog; coop ui reset and coop ui off; and the Lua frame time, logged once a minute with the UI up.
dofile('tests/lua/main/fixture.lua')
-- An XInput pad (the native part reads it; pad_test tests its events): each frame up to 8 events, routed as the keys
-- route theirs. With nothing open in a world, View held opens the co-op menu as menu_key does, its refusals said the
-- same way; the menu takes the six navigation words and View held closes it; the co-op saves' question takes up, down,
-- select and back. Nothing while the host's question is open, while the menu waits for a key (B still stops the wait),
-- at the title with nothing open, or after coop off; the chat box and the code box take only B, which closes them. An
-- older DLL: one log line, no pad.
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
    pad(2); assert(focus()=='Join a friend' and kit_sounds[#kit_sounds]=='move')
    pad(1); assert(focus()=='Host a session')
    pad(7); assert(not kit_shown.menu,'View held again closes it')
    pad(7); pad(6); assert(not kit_shown.menu and kit_sounds[#kit_sounds-1]=='back','B on the main page closes it')
    -- At most 8 a frame: the rest the next frame, where a 0 ends the taking.
    pad(7); assert(kit_shown.menu)
    local calls=pd.calls
    for _=1,10 do pd.q[#pd.q+1]=2 end
    loops[1].f(); assert(pd.calls==calls+8 and #pd.q==2,pd.calls-calls)
    loops[1].f(); assert(pd.calls==calls+11 and #pd.q==0,pd.calls-calls)
    -- A selects; left and right change a value row; a key row waiting for a key takes no pad event but B.
    to('Options'); pad(5)
    assert(focus()=='Open this menu')
    pad(5); assert(select(2,focus())=='Press a key')
    pad(2,1,3,4,5,7); assert(kit_shown.menu and focus()=='Open this menu' and select(2,focus())=='Press a key',
        'Waiting: the pad does nothing')
    pad(6); assert(select(2,focus())=='F5' and kit_shown.menu,'B: not waiting')
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
    -- The host's question: never answered with the pad (its buttons are the game's in a fight).
    link_pending={id='76561198000000008',name='Two'}
    quarter(); assert(kit_shown.ask)
    local n=#asked
    clock=clock+2
    pad(5,6,1,2,7); assert(kit_shown.ask and #asked==n and not kit_shown.menu,'The host\'s question: nothing')
    coop('ui','reset'); assert(not kit_shown.ask and asked[#asked]=='deny 76561198000000008')
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
    pad(7,3,4); assert(kit_shown.saves and saves_view.rows[1].st=='focus' and not kit_shown.menu
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
    in_world,kit_ready=true,true; quarter()
    loops[1].f(); key('F5'); assert(kit_shown.menu and pd.calls==0,'The keys still work')
    pd.missing,in_world,kit_ready=false,false,false
end)()

-- The mouse in the co-op menu (ui/menu.lua for real; the fake kit's rows say whether the mouse is over them). Each 100
-- ms the row the mouse moved onto takes the focus (the move sound, drawn); the row under it as the menu opens, or a
-- mouse resting while the keys move, never takes it; a header or an empty slot, nothing. A left click selects the row
-- under the mouse as Enter does (Leave still asks twice), on a header or no row nothing; a right click goes back,
-- closing it on the main page. Closed, both buttons are the game's: nothing queued (the left one is the saves'
-- question's).
;(function()
    settings_text,status_text,link_mode,in_world,photo_mode='',plain,'none',true,false
    load_main(true)
    kit_ready=true; quarter()
    -- Clock steps in binary fractions: the frame time test below needs sums it can take back exactly.
    local rows=menu_view.rows -- Drawn: SESSION, Host, Join a friend, Join with a code, SETTINGS, Options, HELP,
    local function hover(i) -- report, Close. The mouse over slot i (nil: none), then a frame.
        for j,r in ipairs(rows) do r.hover=j==i or nil end
        loops[1].f()
    end
    local queued_at=executes
    press('LEFT_MOUSE_BUTTON'); press('RIGHT_MOUSE_BUTTON'); assert(executes==queued_at,'Closed: not queued')
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
    clock=clock+0.0625; hover(3); assert(focus()=='Join a friend')
    sounds=#kit_sounds
    for _,i in ipairs({5,12,false}) do clock=clock+0.125; hover(i or nil) end
    assert(focus()=='Join a friend' and #kit_sounds==sounds,'A header, an empty slot, no row: nothing')
    -- Clicks: on a header or no row nothing; on a row, that row selected (Options opens its page), wherever the keys
    -- left the focus.
    hover(5); key('LEFT_MOUSE_BUTTON'); hover(nil); key('LEFT_MOUSE_BUTTON')
    assert(kit_shown.menu and focus()=='Join a friend' and #kit_sounds==sounds,'A click on no row: nothing')
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
    -- The mouse onto the last slot scrolls the page down by one, onto the first up by one.
    local last=rows[15].l
    clock=clock+0.125; hover(15)
    assert(focus()==last and rows[14].l==last and rows[15].l~=last,'The last slot: one row down')
    clock=clock+0.125; hover(1)
    assert(focus()=='Open this menu' and rows[1].l=='CONTROLS' and rows[2].st=='focus','The first slot: one row up')
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
    -- Under the host's question (no hit group), either mouse button only has the kit put our focus back.
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
-- minute's frames.
local start=clock
loops[1].f(); clock=clock+30; loops[1].f()
assert(not logged('Lua frame time'),'Not before a minute')
clock=start+60; loops[1].f()
assert(last():find('^%[StellarCoop%] Lua frame time, last 60 s: ghost 0%.000 ms, doro 0%.000 ms, race 0%.000 ms, UI '
    ..'0%.000 ms a frame %(3 frames%)'),
    last())
local lines=#printed
kit_ready=false; clock=start+120; loops[1].f(); kit_ready=true
assert(#printed==lines,'Not while the UI is down (a map loads, warming)')
key('F5'); assert(kit_shown.menu and kit_input)
coop('ui','reset')
assert(not kit_shown.menu and kit_calls[#kit_calls]=='reset nil' and last()=='[StellarCoop] OK: co-op UI reset: menu '
    ..'and chat closed, the game has its input back\n',last())
key('F5'); assert(kit_shown.menu)
coop('ui','off')
assert(kit_calls[#kit_calls]=='stop nil' and last():find('OK: co-op UI off until the mod reloads',1,true),last())
in_world=false
io.stdout:write('input_test ok\n')
