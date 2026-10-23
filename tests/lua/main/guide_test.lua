-- The first-launch guide through main.lua (ui/guide.lua, ui/menu.lua and session/saves.lua for real on fixture.lua's
-- fake kit; ui/guide_test tests the guide alone): at the mod's first run it opens on the title screen before the co-op
-- saves' question, which shows once it closes; coop-guide.txt stops it; the keys (arrows, W A S D and Z Q S D, Enter,
-- Space, Esc), the mouse and the pad go to it while it is open, and the game's input comes back after; the co-op
-- menu's Guide row and coop guide open it in the world, where menu_key and View held do nothing while it is open, but
-- never over another co-op panel; the art imported from the mod folder; coop ui reset and coop off.
dofile('tests/lua/main/fixture.lua')
local MAIN={saves='main',convert='idle',slot='none',steamid='76561198000000001'}
local function pad(...) for _,e in ipairs({...}) do pd.q[#pd.q+1]=e end; loops[1].f() end -- 1 up ... 7 View held.
local function page() return kit_views.guide.page.s end
local function gfocus() for _,r in ipairs(kit_views.guide.rows) do if r.st=='focus' then return r.l end end end

-- The first run: no coop-guide.txt. On the title screen, once the root is up, the guide shows and the co-op saves'
-- question waits; the navigation keys are the guide's: right arrow, D turn the page on, left arrow, A and Q back.
link_files['coop-guide.txt']=nil
settings_text,status_text,link_mode,in_world,at_title='',plain,'none',false,true
saves_info=MAIN
load_main(true)
quarter(); assert(not kit_shown.guide and not kit_shown.saves,'The root not up yet: neither')
kit_ready=true; quarter()
assert(kit_shown.guide and not kit_shown.saves and kit_input and kit_holder=='guide','The guide first')
assert(logged('guide: open (first run: no coop-guide.txt)') and page()=='Page 1 of 9')
assert(kit_views.guide.title.s=='Welcome to Stellar Blade Online' and gfocus()=='Next')
assert(art.imports[#art.imports][1]==cv.PC and art.imports[#art.imports][2]=='mod/StellarCoop\\Assets\\MotherSphere.png'
    and kit_views.guide.art.t==art.texture and kit_views.guide.art.on==true,'The art from the mod folder')
quarter(); quarter(); assert(not kit_shown.saves,'The question waits while it is open')
key('RIGHT_ARROW'); assert(page()=='Page 2 of 9')
key('D'); assert(page()=='Page 3 of 9')
key('LEFT_ARROW'); key('A'); assert(page()=='Page 1 of 9')
key('D'); key('Q'); assert(page()=='Page 1 of 9','Q turns back too (AZERTY)')
key('S'); assert(gfocus()=="Don't show again")
key('W'); key('Z'); assert(gfocus()=='Close','W and Z move up')
key('DOWN_ARROW'); key('UP_ARROW'); assert(gfocus()=='Close')
key('RETURN'); assert(kit_shown.guide,'Not in its first second')
clock=clock+1
key('UP_ARROW'); key('UP_ARROW'); key('SPACE'); assert(page()=='Page 2 of 9' and gfocus()=='Next','Space runs Next')
key('RETURN'); assert(page()=='Page 3 of 9' and not kit_shown.chat,'Enter runs Next; no chat box')
-- Esc closes it: nothing written before the last page; the question shows at the next 250 ms, its own keys then.
key('ESCAPE')
assert(not kit_shown.guide and logged('guide: closed on page 3 (Esc)') and not link_files['coop-guide.txt'])
quarter()
assert(kit_shown.saves and kit_holder=='saves','Then the co-op saves\' question')
key('DOWN_ARROW'); assert(kit_views.saves.rows[2].st=='focus' and page()=='Page 3 of 9','Its keys now')
coop('ui','reset')
-- Don't show again writes coop-guide.txt (one line); at the next load, with it there, the question shows at once.
load_main(true)
kit_ready=true; quarter(); assert(kit_shown.guide and not kit_shown.saves,'Not written: shown again at the next load')
clock=clock+1
key('DOWN_ARROW'); key('RETURN')
assert(not kit_shown.guide and link_files['coop-guide.txt']:match('^[^\n]+\n$')
    and logged('guide: coop-guide.txt written: the guide no longer opens by itself'))
quarter(); assert(kit_shown.saves)
coop('ui','reset')
load_main(true)
kit_ready=true; quarter(); assert(not kit_shown.guide and kit_shown.saves,'coop-guide.txt there: the question at once')
coop('guide')
assert(not kit_shown.guide and kit_holder=='saves' and last()==
    '[StellarCoop] STOP: the guide does not open while another co-op panel is open\n','Not over the question')
coop('ui','reset')

-- The pad at the title: down and up move, A runs the row (from 1 s), B closes, View held does nothing; the mouse:
-- the row it moves onto takes the focus, a left click runs the row under it.
link_files['coop-guide.txt']=nil
load_main(true)
kit_ready=true; quarter(); assert(kit_shown.guide)
pad(2); assert(gfocus()=="Don't show again")
pad(1); pad(7); assert(gfocus()=='Next' and not kit_shown.menu and not logged('pad: menu'))
pad(5); assert(page()=='Page 1 of 9','A within 1 s: nothing')
clock=clock+1
pad(5); assert(page()=='Page 2 of 9','A runs Next')
local rows=kit_views.guide.rows
local function hover(i) for j,r in ipairs(rows) do r.hover=j==i or nil end; clock=clock+0.125; loops[1].f() end
hover(nil); hover(2); assert(gfocus()=='Back','The row the mouse moved onto')
key('LEFT_MOUSE_BUTTON'); assert(page()=='Page 1 of 9' and kit_said('click nil'),'A click runs it')
hover(nil); key('LEFT_MOUSE_BUTTON'); assert(page()=='Page 1 of 9','A click on no row: nothing')
pad(6); assert(not kit_shown.guide and logged('guide: closed on page 1 (Esc)'),'B closes it')
clock=clock+0.25; loops[1].f(); quarter()
assert(kit_shown.saves and kit_holder=='saves')
coop('ui','reset')
saves_info,at_title,kit_ready={},false,false

-- In the world: the co-op menu's Guide row closes the menu and opens the guide on its first page, its keys the
-- guide's; menu_key and View held do nothing while it is open; the game's input back 150 ms after Esc closes it. coop
-- guide opens it too; coop ui reset closes it; coop off stops it.
link_files['coop-guide.txt']='x\n'
in_world=true
load_main(true)
kit_ready=true; quarter()
assert(not kit_shown.guide,'Never by itself in the world')
key('F5'); to('Guide'); key('RETURN')
assert(not kit_shown.menu and kit_shown.guide and kit_holder=='guide' and page()=='Page 1 of 9')
assert(logged('guide: open (asked)') and logged('menu: guide open'))
clock=clock+0.25; loops[1].f(); assert(kit_input and kit_holder=='guide','The menu\'s late give-back leaves it alone')
key('F5'); assert(kit_shown.guide and not kit_shown.menu,'menu_key: nothing')
pad(7); assert(kit_shown.guide and not kit_shown.menu,'View held: nothing')
key('RIGHT_ARROW'); assert(page()=='Page 2 of 9')
key('ESCAPE'); assert(not kit_shown.guide and kit_input,'Esc closes it; the input 150 ms later')
clock=clock+0.25; loops[1].f(); assert(not kit_input,'The game has its input back')
quarter(); assert(not kit_shown.guide)
-- The host's question about a player who is not her Steam friend closes it as it opens, as it does the menu.
link_mode,link_pending='host',{id='76561198000000008',name='Two'}
coop('guide'); quarter()
assert(kit_shown.ask and kit_holder=='ask' and not kit_shown.guide
    and logged("guide: closed on page 1 (the host's question)"))
coop('ui','reset'); link_mode,link_pending='none',nil
quarter()
coop('guide'); assert(kit_shown.guide and page()=='Page 1 of 9' and last()=='[StellarCoop] OK: guide open\n')
coop('guide'); assert(last()=='[StellarCoop] OK: the guide is open\n')
coop('ui','reset'); assert(not kit_shown.guide and logged('guide: closed on page 1 (coop ui reset)'))
key('F5'); to('Join with a code'); key('RETURN')
coop('guide'); assert(kit_shown.code and not kit_shown.guide and kit_holder=='code','Nor over the code box')
coop('ui','reset')
coop('guide','x'); assert(last()=='[StellarCoop] STOP: Use: coop guide\n')
kit_paused=true
coop('guide'); assert(last()=='[StellarCoop] STOP: the guide does not open while the game is paused or shows a menu\n')
kit_paused=false
coop('guide'); assert(kit_shown.guide)
coop('off'); assert(kit_said('stop nil'),'coop off: the kit stops, the game has its input back')
key('RIGHT_ARROW'); assert(page()=='Page 1 of 9','Stopped: its keys do nothing')
coop('guide'); assert(last()=='[StellarCoop] STOP: coop off is active until the game restarts\n')
-- Without the Steam link there is no UI: coop guide says so.
load_main(false)
coop('guide'); assert(last()=='[StellarCoop] STOP: the guide needs the co-op UI, which needs the Steam link\n')
in_world,kit_ready=false,false
io.stdout:write('guide_test ok\n')
