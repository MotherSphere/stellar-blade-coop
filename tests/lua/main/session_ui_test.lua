-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The session UI on fixture.lua's fake kit, through main.lua: the session chat (online/session/chat.lua's view) opens
-- on Enter, sends, cancels on Esc, hands its lines to the native part and takes the notices into its feed while the UI
-- is up; join codes (online/session/join.lua: who_can_join=invitation, the menu's Copy my code, Join with a code and
-- Remove rows, the code box and the host's question taking the keys); the partner HUD (online/partner/hud.lua); and the
-- co-op saves' question (online/saves/saves.lua), which shows on the title screen and takes the menu's keys while open.
-- While the chat box, the code box, the host's question or the saves' question is open, coop leviathan's free camera
-- reads no key.
dofile('tests/lua/main/fixture.lua')
local n
-- The session chat (online/session/chat.lua's view for real on the fake kit; its model a spy). Enter, queued to the
-- game thread: outside a session it says why on screen (into the feed, its root up; never in the log); in one it opens
-- the box with the game's input on it; Enter sends what was typed, Esc cancels and the game's input comes back 150 ms
-- later; our F-keys do nothing while it is open. Each 250 ms a line waiting goes to the native part (a refused write
-- marks it not sent, nothing logged). Notices go into the feed while the root is up, else to the line above EVE. The
-- menu hides the feed while open, and its Chat row opens the box, the input passing from the menu to the box. coop off
-- closes it.
settings_text,status_text,link_mode,chat_active='chat=off\n',plain,'host',false
load_main(true)
assert(chat_new[2]==false,'chat=off reaches the model')
-- The kit off in a French game: why the box cannot open goes on the line above EVE, with its English.
kit_language,in_world,kit_ready=('fr-FR'),true,true; quarter()
kit_off=true; key('RETURN'); clock=clock+0.1; loops[1].f()
assert(said[#said]=='La discussion demande une session ou le lobby JcJ.'
    and said_en[#said]=='Chat needs a session or the PvP lobby.',said[#said])
settings_text=''
load_main(true)
chat_feed={}
in_world,kit_ready=true,true; quarter()
local feed=kit_views.feed
assert(kit_views.chat and feed and #feed.rows==12)
-- Enter with the box closed: it opens 0.1 s later, unless a coop command came from the console around that Enter
-- (UE4SS calls our bind whatever has the keyboard: that Enter was the console's), in either order.
local function enter() key('RETURN'); clock=clock+0.1; loops[1].f() end
local printed_before=#printed
enter()
assert(chat_calls[#chat_calls]:find('^system Chat needs a session or the PvP lobby%. ')
    and not kit_said('show chat true') and #printed==printed_before,'On screen only')
chat_active=true
local calls_at=#chat_calls
key('RETURN'); coop('status'); clock=clock+0.2; loops[1].f()
handler(nil,{'status'}); clock=clock+0.2; key('RETURN'); clock=clock+0.2; loops[1].f() -- A slow frame between.
assert(not kit_said('show chat true') and #chat_calls==calls_at,"The console's Enter: no box, nothing said")
-- Alt+Enter (the fullscreen toggle), if UE4SS also calls the plain bind for it: no box.
clock=clock+0.5
key('RETURN','ALT'); key('RETURN'); clock=clock+0.1; loops[1].f()
assert(not kit_said('show chat true') and #chat_calls==calls_at,'Alt+Enter: no box')
-- Enter while the game is paused or on one of its screens (Resume, a choice): the game's, even once it resumes.
clock=clock+0.5
kit_paused=true; key('RETURN'); kit_paused=false; clock=clock+0.1; loops[1].f()
assert(not kit_said('show chat true') and #chat_calls==calls_at,'Paused at the press: no box, nothing said')
clock=clock+0.5
key('RETURN'); clock=clock+0.09; loops[1].f()
assert(not kit_said('show chat true'),'Not before 0.1 s')
clock=clock+0.02; loops[1].f()
assert(kit_said('show chat true') and kit_said('input true chat') and box_text=='')
assert(lv.o.blocked()==true,'The chat box open: the free camera reads no key')
clock=clock+0.1; loops[1].f(); assert(box_focuses==1,'The box focused again 50 ms after')
box_text='Bonjour é'
key('RETURN')
assert(chat_calls[#chat_calls]:find('^send Bonjour é ') and box_text=='' and not logged('Bonjour'))
n=#printed
key('F6'); key('F5'); key('F8')
assert(#printed==n and #asked==0 and not kit_said('show true'),'Our F-keys do nothing while typing')
box_text='brouillon'
key('ESCAPE')
assert(kit_calls[#kit_calls]=='show chat false' and box_text=='','Esc: closed, the draft gone')
assert(lv.o.blocked()==false)
clock=clock+0.1; loops[1].f(); assert(not kit_said('input false chat'))
clock=clock+0.1; loops[1].f(); assert(kit_calls[#kit_calls]=='input false chat','The game gets its keys 150 ms after')
chat_out={'bonjour'}; quarter()
assert(said_lines[#said_lines]=='bonjour' and not logged('bonjour'),'To the native part through coop-say.txt')
local calls_before=#chat_calls
say_refusal,chat_out='busy',{'encore'}; quarter()
assert(table.concat(chat_calls,'|',calls_before+1):find('|fail|',1,true) and not logged('encore'),
    'Refused: marked not sent')
say_refusal=nil
-- Notices: into the feed while the root is up (the line above EVE untouched), else on that line.
local said_before=#said
quarter()
assert(#said==said_before and table.concat(chat_calls,'|'):find('|system Kaanta joined%. [%d.]+|system Kaanta: '
    ..'connection lost%. [%d.]+$'))
kit_ready=false; quarter(); assert(said[#said]=='Kaanta: connection lost.','No root: the line above EVE')
kit_ready=true; quarter()
-- The menu over the feed hides it and shows the newest notice instead; its Chat row opens the box, and the menu's late
-- give-back leaves the box its input.
key('F5'); quarter()
assert(kit_said('show feed false') and focus()=='Leave the session' and menu_view.note.s=='Kaanta: connection lost.')
to('Chat'); key('RETURN')
assert(kit_said('show false')<kit_said('show chat true') and kit_said('show chat true')<kit_said('input true chat')
    and kit_said('input true chat')<kit_said('show feed true'),'The menu closed, the box open, the feed back')
clock=clock+0.2; loops[1].f(); quarter()
assert(kit_said('input true chat')>(kit_said('input false') or 0),"The menu's late give-back leaves the box its keys")
-- The session ends while it is open: closed, the game's input back 150 ms later.
chat_active=false; quarter()
assert(kit_said('show chat false'))
clock=clock+0.2; loops[1].f(); assert(kit_calls[#kit_calls]=='input false chat')
-- coop off with the box open: closed, the kit stopped (it gives the input back); Enter does nothing after.
chat_active=true; enter(); assert(kit_calls[#kit_calls]=='input true chat')
coop('off')
assert(kit_calls[#kit_calls]=='stop nil')
n=#kit_calls
enter(); key('ESCAPE')
assert(#kit_calls==n,'Nothing after coop off')
chat_active,in_world,kit_ready,link_mode=false,false,false,'none'

-- Alone in an SBO lobby (a hall or Xion's room: sb.here) the chat holds a session with nobody linked, and Enter opens
-- the box. A line typed there stays on our screen: no coop-say.txt, not marked not sent, and one chat.alone notice an
-- alone stretch. A member past the handshake, in any ghost slot (no friend= line), hears it; one before the handshake
-- does not. Out of the lobby, or after coop off, no session.
settings_text,status_text,link_mode='',plain,'none'
load_main(true)
in_world,kit_ready=true,true
local ALONE='system No other player is connected yet: your messages stay on your screen. '
local function last_session()
    for i=#chat_calls,1,-1 do local s=chat_calls[i]:match('^session (%a+)$') if s then return s end end
end
local function alones(from)
    local count=0
    for i=from+1,#chat_calls do if chat_calls[i]:sub(1,#ALONE)==ALONE then count=count+1 end end
    return count
end
local function fails(from) return (table.concat(chat_calls,'|',from+1)..'|'):find('|fail|',1,true)~=nil end
chatting,sb.here=false,true; quarter()
assert(last_session()=='true','Alone in the lobby: a session')
lb.screen=nil -- B, opened at the arrival, closed.
-- SB's interaction on EVE in a hall (sb.busy): that Enter is its Get up choice's, no box.
chat_active,sb.busy=true,true; enter()
assert(not kit_said('show chat true'),"SB's Get up: no box")
sb.busy=false; clock=clock+0.5
enter()
assert(kit_said('show chat true'),'Enter opens the box')
key('ESCAPE')
local calls_at,said_at=#chat_calls,#said_lines
chat_out={'salut'}; quarter()
assert(#said_lines==said_at and not fails(calls_at) and alones(calls_at)==1,'Alone: on our screen, one notice')
calls_at=#chat_calls
chat_out={'encore'}; quarter()
assert(#said_lines==said_at and not fails(calls_at) and alones(calls_at)==0,'No second notice')
fake_link.members=function() return {{id='4003',slot=2,linked=true,lost=false,muted=false,rtt=30,name='P3'}} end
quarter()
assert(last_session()=='true')
chat_out={'hello'}; quarter()
assert(said_lines[#said_lines]=='hello','A member in slot 2 hears it, with no friend= line')
fake_link.members=function() return {} end
calls_at,said_at=#chat_calls,#said_lines
chat_out={'seule'}; quarter()
assert(#said_lines==said_at and alones(calls_at)==1,'Alone again: the notice again')
sb.here=false; quarter()
assert(last_session()=='false','Out of the lobby: no session')
sb.here=true
fake_link.members=function() return {{id='4003',slot=2,linked=false,lost=false,muted=false,rtt=-1,name='P3'}} end
quarter()
calls_at,said_at=#chat_calls,#said_lines
chat_out={'attente'}; quarter()
assert(#said_lines==said_at and not fails(calls_at) and alones(calls_at)==1,'Before the handshake: on our screen')
fake_link.members=function() return {} end
coop('off'); quarter()
assert(last_session()=='false','coop off: no session')
chat_active,in_world,kit_ready,sb.here=false,false,false,false

-- Join codes (online/session/join.lua for real on the fake kit; join_test tests it). who_can_join=invitation hosts with
-- a code (0.11's code reads as invitation). Join
-- with a code closes the menu and opens the code box, the input passing from the menu to the box; while it is open the
-- navigation keys and our F-keys do nothing; Enter joins, Esc cancels. While we host, Copy my code shows our code and
-- asks the native part to copy it (the menu stays), Remove <name> asks a second Select. The host's question closes the
-- menu as it opens and takes the navigation keys, Enter and Esc (no chat box, no F-key); coop ui reset denies an open
-- question; coop off ends it.
settings_text,status_text,link_mode='who_can_join=code\n',plain,'none'
load_main(true)
coop('host'); assert(asked[#asked]=='host invitation 4' and logged('OK: asked the native part: host invitation 4'))
in_world,kit_ready=true,true; quarter()
key('F5'); to('Join with a code'); key('RETURN')
assert(not kit_shown.menu and kit_shown.code and kit_holder=='code' and kit_views.code.title.s=='JOIN WITH A CODE')
assert(lv.o.blocked()==true,'The code box open')
n=#asked
key('S'); key('SPACE'); key('F6'); key('F5')
assert(kit_shown.code and not kit_shown.menu and #asked==n and not logged('key F6: status'),'Typing: our keys rest')
code_text='0cs-cbmh'; key('RETURN')
assert(asked[#asked]=='join 0CS-CBMH' and not kit_shown.code and kit_input)
clock=clock+0.25; loops[1].f(); assert(not kit_input,'The game gets its keys back 150 ms after')
key('F5'); to('Join with a code'); key('RETURN'); code_text='0CS'
key('ESCAPE'); assert(not kit_shown.code and code_text=='' and asked[#asked]=='join 0CS-CBMH','Esc: nothing asked')
link_mode,link_code,link_refused,link_lobby='host','0CS-CBMH',0,'7000'
key('F5'); to('Copy my code'); assert(select(2,focus())=='0CS-CBMH')
key('RETURN'); assert(asked[#asked]=='copy' and kit_shown.menu,'Copied: the menu stays')
link_stranger={id='76561198000000009',name='Stranger'}
key('DOWN_ARROW'); assert(focus()=='Remove Stranger')
key('RETURN'); assert(menu_view.note.s=='Select again within 3 s to remove and block Stranger.' and asked[#asked]=='copy')
key('RETURN'); assert(asked[#asked]=='remove 76561198000000009')
link_pending={id='76561198000000008',name='Two'}
quarter()
assert(not kit_shown.menu and kit_shown.ask and kit_holder=='ask' and kit_views.ask.title.s=='Two wants to join')
assert(lv.o.blocked()==true,"The host's question open")
n=#asked
key('F5'); key('F6'); assert(not kit_shown.menu and #asked==n and not logged('key F6: status'),'Our keys rest')
-- It opened on its own: a walk forward and a jump, then any key for 1 s, answer nothing; later W, S and Space still
-- do nothing there.
key('W'); key('SPACE'); key('UP_ARROW'); key('RETURN'); key('ESCAPE')
clock=clock+1; key('W'); key('Z'); key('SPACE'); key('S'); key('SPACE')
assert(#asked==n and kit_shown.ask and not kit_shown.chat,'Stray keys: nothing')
key('UP_ARROW'); key('RETURN')
clock=clock+0.25; loops[1].f()
assert(asked[#asked]=='allow 76561198000000008' and not kit_shown.ask and not kit_shown.chat,'Enter: let in, no chat')
link_pending={id='76561198000000007',name='Three'}
quarter(); assert(kit_shown.ask)
clock=clock+1; key('ESCAPE'); assert(asked[#asked]=='deny 76561198000000007' and not kit_shown.ask)
link_pending={id='76561198000000006',name='Four'}
quarter(); assert(kit_shown.ask)
coop('ui','reset'); assert(asked[#asked]=='deny 76561198000000006' and not kit_shown.ask,'Reset: denied')
link_pending={id='76561198000000005',name='Five'}
coop('off')
n=#asked
for _=1,130 do quarter() end
assert(#asked==n and not kit_shown.ask,'Nothing after coop off')
link_mode,link_code,link_refused,link_pending,link_stranger,link_lobby='none',nil,nil,nil,nil,'0'
settings_text,in_world,kit_ready='',false,false

-- The partner HUD (online/partner/hud.lua's view for real on the fake kit; partner_test tests it): added after the feed
-- and before the menu, which draws over it, the status strip after the card and before her marker and arrow, which draw
-- over it; each 250 ms in a world its card follows the session and her vitals, and the ghost hides its name tag while
-- the marker carries her name (partner_bar on, the root up); each frame only its marker and arrow, projected through
-- the kit each frame and never without her anchor; nothing after coop off. The guide (ui/kit/guide.lua) under the menu,
-- which never shows with it. The members' rows (a session of more than 2 players) after the arrow. Score attack's card,
-- board and result panel (online/modes/scoreattack/ui/board.lua), then the fishing tournament's corner board and result
-- panel (online/modes/fishing/ui/board.lua), then the photo hunt's card and result panel
-- (online/modes/photohunt/ui/board.lua), after the HUDs, under the menu. The closet menu (closet/ui/view.lua) after the
-- wheel, before the host's question, which draws over it.
settings_text,status_text,link_mode='',plain,'host'
load_main(true)
assert(table.concat(kit_order,' ')=='chat feed card status marker arrow member1 member2 member3 member4 member5 member6 '
    ..'scoreattack scoreattack_board scoreattack_result fishing fishing_result photohunt photohunt_result code guide '
    ..'menu line_hint wheel closet_menu ask ask_popup badge saves',
    table.concat(kit_order,' '))
in_world,kit_ready,chatting=true,true,true
mate_v={hp=500,max_hp=1000,shield=0,max_shield=0,blocks=0,beta=0,max_beta=0,burst=0,max_burst=0,tachy=0,max_tachy=0,
    life=1}
quarter()
assert(kit_said('show card true') and markers[#markers]==true,'The card up; the marker carries her name')
loops[1].f(); clock=clock+0.05; loops[1].f()
assert(kit_projects==0,'No anchor: no projection')
her_anchor={X=1000,Y=0,Z=220}
clock=clock+0.05; loops[1].f(); loops[1].f()
assert(kit_projects==2 and kit_said('show marker true'),'Each frame')
clock=clock+0.04; loops[1].f()
assert(kit_projects==3)
kit_ready=false; quarter()
assert(markers[#markers]==false,'No root: the name tag is the fallback')
settings_text='partner_bar=off\n'
load_main(true)
in_world,kit_ready=true,true; quarter()
assert(markers[#markers]==false,'partner_bar=off: the name tag stays')
coop('off')
n=#markers; kit_projects=0; her_anchor={X=1000,Y=0,Z=220}
quarter(); clock=clock+0.1; loops[1].f()
assert(#markers==n and kit_projects==0,'Nothing after coop off')
chatting,in_world,kit_ready,link_mode,settings_text=false,false,false,'none',''

-- The co-op saves' question (online/saves/saves.lua for real on the fake kit; saves_test tests it). On the title screen
-- the kit's root comes up too (the kit told it is the title); once the question shows, the navigation keys, Enter, Esc
-- and a left click on a choice are its own (not the chat's, not the menu's); coop ui reset closes it as Decide later,
-- coop off stops it; coop ui off leaves auto_coop_save=always asking.
settings_text,status_text,link_mode,in_world,at_title,chatting,chat_active='',plain,'none',false,true,true,true
saves_info={saves='main',convert='idle',slot='none',steamid='76561198000000001'}
load_main(true)
local saves_view=kit_views.saves
assert(kit_order[#kit_order]=='saves' and saves_view,'Added last: drawn over the menu')
quarter()
assert(kit_said('slow true title') and not kit_shown.saves,'The title: the root up, its look warming')
kit_ready=true; quarter()
assert(kit_shown.saves and kit_input and kit_holder=='saves' and saves_view.rows[1].st=='focus')
assert(lv.o.blocked()==true,"The saves' question open")
key('DOWN_ARROW'); assert(saves_view.rows[2].st=='focus' and not kit_shown.menu)
clock=clock+1 -- It takes a choice 1 s after it shows.
key('UP_ARROW'); key('RETURN')
clock=clock+0.25; loops[1].f()
assert(asked[#asked]=='saves coop' and not kit_shown.chat and kit_holder=='saves','Enter chose; no chat box')
key('ESCAPE'); assert(asked[#asked]=='saves main' and not kit_shown.saves,'Esc: withdrawn, closed')
clock=clock+0.25; loops[1].f(); assert(not kit_input,'The game has its input back 150 ms later')
key('RETURN'); clock=clock+0.25; loops[1].f()
assert(not kit_shown.chat and not kit_input,'On the title screen Enter is the game\'s: no chat box, in a session too')
in_world,at_title=true,false; quarter(); in_world,at_title=false,true; quarter()
assert(kit_shown.saves,'A new visit of the title: asked again')
local n_asked=#asked
coop('ui','reset'); assert(not kit_shown.saves and #asked==n_asked,'Closed as Decide later, nothing asked')
in_world,at_title=true,false; quarter(); in_world,at_title=false,true; quarter()
assert(kit_shown.saves)
key('LEFT_MOUSE_BUTTON'); assert(kit_shown.saves,'A click on no choice: nothing')
saves_view.rows[2].hover=true
clock=clock+1
key('LEFT_MOUSE_BUTTON'); assert(not kit_shown.saves and #asked==n_asked,'A click on Play solo normally')
saves_view.rows[2].hover=nil
in_world,at_title=true,false; quarter(); in_world,at_title=false,true; quarter()
assert(kit_shown.saves)
-- The focus watchdog while a pass runs: the question hidden, the pass not withdrawn (coop ui reset withdraws it).
clock=clock+1; key('RETURN'); quarter()
n_asked=#asked
assert(asked[n_asked]=='saves coop')
kit_lost='saves'; quarter()
assert(not kit_shown.saves and #asked==n_asked,'Hidden, nothing withdrawn')
saves_info.saves='coop'; quarter(); saves_info.saves='main'
in_world,at_title=true,false; quarter(); in_world,at_title=false,true; quarter()
assert(kit_shown.saves)
clock=clock+1; key('RETURN'); quarter(); assert(asked[#asked]=='saves coop')
coop('ui','reset'); assert(asked[#asked]=='saves main','coop ui reset withdraws the pass')
in_world,at_title=true,false; quarter(); in_world,at_title=false,true; quarter()
assert(kit_shown.saves)
coop('off')
key('RETURN'); assert(asked[#asked]=='off','Stopped: its keys do nothing')
settings_text='auto_coop_save=always\n'
load_main(true)
coop('ui','off'); kit_off=true
quarter(); assert(asked[#asked]=='saves coop','coop ui off: always still asks')
kit_off,settings_text=false,''
saves_info,at_title,chatting,chat_active={},false,false,false
io.stdout:write('session_ui_test ok\n')
