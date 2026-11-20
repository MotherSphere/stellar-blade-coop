-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The bike through main.lua (fixture.lua's fake vehicles/bike/ride.lua; vehicles/bike/ride_test tests the ride): the
-- load log line, what the ride is built with (its native asks, coop-bike.txt, the races' driving, the settings, the
-- checks it reads), coop bike and its words, bike_key (F3) and the pad's D-pad Right held 1 s with a refusal on screen,
-- the first tick's restore, its frame before the native tick, its 250 ms pass, coop off (the stop, then the parked bike
-- out of the world), the Options rows; riding() as coop emote, the race, the hall seats, coop fly on and coop glide on
-- read it; its idle_part as the capture's leave_out; the menu's words, a notice, SB's text (game_text) and the travel
-- worlds for the parked bike; its bike line through link.bike; its paid fetch at a Xion camp (a fake
-- vehicles/bike/fetch.lua: what it is built with, coop gift's FName and pause rules) and the follow's camp_near. Other
-- players' parked bikes (fixture.lua's fake vehicles/bike/others.lua): what they are built with, their restore at the
-- first tick, their pass after the ride's, their clear at coop off.
dofile('tests/lua/main/fixture.lua')
-- coop fly's keys: eve/flight.lua for real, with fly_on in place of its active() (on() needs SB's player input).
local Flight,fly_on=require('eve.flight'),nil
package.loaded['eve.flight']={new=function(o)
    local f=Flight.new(o)
    f.active=function() return fly_on end
    return f
end}
local USE='[StellarCoop] STOP: Use: coop bike [status | tune [<name> <value>]]\n'
settings_text,status_text,in_world='',plain,true
package.loaded['core.worlds']={Xion='/game/art/bg/worldmap/level_p/e04'}
-- The paid fetch: what vehicles/bike/fetch.lua's new got (fe.o); the follow answers camp_near with its arguments.
local fe={}
package.loaded['vehicles.bike.fetch']={new=function(o) fe.o=o; return {name='fetch'} end}
local travel_new=package.loaded['online.group.travel'].new
package.loaded['online.group.travel'].new=function(o)
    local t=travel_new(o)
    t.camp_near=function(w,m) return w..' '..m end
    return t
end
load_main(true)
assert(logged('bike: on, bike_key F3'),table.concat(printed,'|'))
local o=bk.o
assert(o.store=='store coop-bike.txt' and o.drive.name=='bike drive' and o.settings.bike==true)
assert(o.drove()==false and bdv.o.store=='store coop-drive.txt' and bdv.o.settings==o.settings,
    'Its own drive: coop-drive.txt through the link, the drift keys; the races\' drive read through drove')
-- The parked bike's path for the next Lua load (swept after a Ctrl+R).
assert(o.stand_store=='store coop-bike-stand.txt',tostring(o.stand_store))
-- The parked bike's words: the menu's, a notice in them and in English, the travel worlds for a map's name.
assert(o.words().bike.not_back=='Your bike is not back yet.' and o.worlds.Xion=='/game/art/bg/worldmap/level_p/e04')
o.tell(function(w) return w.bike.prompt:format('F3') end)
assert(said[#said]=='F3: get on the bike' and said_en[#said]=='F3: get on the bike',tostring(said[#said]))
-- The money's name for the paid fetch: SB's text for a key of the table at a path (core/unreal.lua's game_text).
local unreal=require('core.unreal')
local game_text=unreal.game_text
unreal.game_text=function(key,path) return key..' '..tostring(path) end
assert(o.game_text('Item_BetaCrystal_Name','/T.T')=='Item_BetaCrystal_Name /T.T')
unreal.game_text=game_text
-- Its place per save through the link's own files; none written while an SBO lobby is open.
assert(o.file.read==fake_link.read_file and o.file.write==fake_link.write_file and o.lobby()==false)
sb.active=true; assert(o.lobby()==true); sb.active=false
-- Her bike line goes to the link (coop-parked.txt), its answer back to the ride.
local parked={}
fake_link.bike=function(payload) parked[#parked+1]=payload; return true end
assert(o.send('none')==true and parked[1]=='none')
fake_link.bike=function() return false,'cannot write' end
assert(o.send('none')==false)
fake_link.bike=nil
-- The paid fetch: vehicles/bike/fetch.lua with the native asks, the status and [BK] lines, coop gift's own FName and
-- pause rules; the camp from the follow's camp_near.
assert(o.fetch.name=='fetch' and fe.o.name==gf.o.name and fe.o.paused==gf.o.paused and fe.o.status()==status_text)
assert(fe.o.ask('items 1 BetaCrystal 77 0') and asked[#asked]=='items 1 BetaCrystal 77 0')
fe.o.log('x'); assert(last()=='[StellarCoop][BK] x\n',last())
assert(o.camp('Xion',10)=='Xion 10')
-- Other players' parked bikes: the members' bike lines, names and our SteamID from the link, our EVE, the native
-- status, the settings, coop-bike-copies.txt for the next Lua load's sweep.
local b=bo.o
assert(b.store=='store coop-bike-copies.txt' and b.settings==o.settings and b.members==fake_link.members
    and b.status==fake_link.status)
fake_link.bikes=function() return {['2002']='none'} end
assert(b.bikes()['2002']=='none')
fake_link.bikes=nil
saves_info.steamid='1'; assert(b.me()=='1'); saves_info.steamid=nil
package.loaded.UEHelpers.GetPlayer=function() return nil end
assert(b.eve()==nil,'No player: no EVE')
package.loaded.UEHelpers.GetPlayer=nil
b.log('x'); assert(last()=='[StellarCoop][BK] x\n',last())
-- Its native asks and status, the game's checks.
assert(o.ask('bike load x') and asked[#asked]=='bike load x' and o.status()==status_text)
assert(o.paused()==false and o.photo()=='0' and o.frozen()==false and o.life()==nil and o.armed()==false)
kit_paused,photo_mode,fake_link.Q.life,ra.armed=true,true,{state=4,hp=0},true
assert(o.paused()==true and o.photo()=='1' and o.life().state==4 and o.armed()==true)
kit_paused,photo_mode,fake_link.Q.life,ra.armed=false,false,nil,false
-- SBO's own state that holds EVE: each with its reason, none when nothing does.
assert(o.busy()==nil)
for _,case in ipairs({{function(on) dr.active=on end,'the Doro look is on: coop race look off ends it'},
        {function(on) em.active=on end,'coop emote plays: coop emote off ends it'},
        {function(on) sb.sitting=on end,'EVE sits on a hall seat: stand her up first'},
        {function(on) fly_on=on end,'coop fly is on: coop fly off ends it'},
        {function(on) gl.active=on end,'coop glide is on: coop glide off ends it'},
        {function(on) nr.running=on end,'Night Operation is running: coop nightop stop ends it'},
        {function(on) gm.out=on end,'the rifle is out: put it away first'}}) do
    case[1](true)
    assert(o.busy()==case[2],tostring(o.busy()))
    case[1](nil)
end
assert(o.busy()==nil)
-- riding(): coop emote, the race's dismount, the hall seats and the Doro look read it.
assert(em.o.riding()==false and sb.o.riding()==false)
bk.riding=true
assert(em.o.riding()==true and sb.o.riding()==true)
ra.o.dismount('the host started a race')
assert(bk.stops[1]=='the host started a race')
-- The capture asks the ride at each look which part of hers to leave out: its idle_part (vehicles/bike/ride_test,
-- capture_test).
assert(capture_leave_out(0x40)==nil and bk.idle_part_at==0x40)
bk.idle_part=0x7100
assert(capture_leave_out(0x40)==0x7100)
bk.idle_part=nil
-- coop fly on and coop glide on are refused while she rides (on a co-op save, where both would start); off is not.
status_text=COOP
local n_asked,n_glide=#asked,#gl.cmds
coop('fly','on')
assert(#asked==n_asked and last()=='[StellarCoop] STOP: EVE rides the bike: coop bike gets her off first\n',last())
coop('glide','on')
assert(#gl.cmds==n_glide and last()=='[StellarCoop] STOP: EVE rides the bike: coop bike gets her off first\n',last())
coop('fly','off'); coop('glide','off')
assert(asked[#asked]=='fly off' and #gl.cmds==n_glide+1 and gl.cmds[#gl.cmds][1]=='off')
coop('slowmo','on')
assert(asked[#asked]=='slowmo on','coop slowmo stays free while she rides')
coop('slowmo','off')
status_text=plain
bk.riding=false

-- coop bike: on or off, status, tune with no words or a name and a value; anything else is its usage line.
coop('bike')
assert(bk.toggles[1]=='coop bike' and last()=='[StellarCoop] OK: On the bike: coop bike gets her off.\n',last())
coop('bike','status')
assert(last()=='[StellarCoop] OK: bike: preload ready\n',last())
coop('bike','tune')
assert(#bk.tunes==1 and bk.tunes[1][1]==nil and last()=='[StellarCoop] OK: bk tune nil\n',last())
coop('bike','tune','top','3000')
assert(bk.tunes[2][1]=='top' and bk.tunes[2][2]=='3000',last())
for _,bad in ipairs({{'tune','top'},{'tune','top','1','2'},{'status','x'},{'on'},{'off'}}) do
    local n=#bk.toggles
    coop('bike',table.unpack(bad))
    assert(last()==USE and #bk.toggles==n and #bk.tunes==2,table.concat(bad,' ')..': '..last())
end

-- bike_key: F3 unless set, on the game thread; a refusal is logged and said on screen.
key('F3')
assert(bk.toggles[#bk.toggles]=='bike_key' and logged('key F3: bike'),table.concat(bk.toggles,'|'))
local n=#said
bk.answer={false,'EVE is swimming'}
key('F3')
assert(last()=='[StellarCoop] STOP: EVE is swimming\n' and said[#said]=='EVE is swimming' and #said==n+1,last())
bk.answer,bk.raise=nil,'boom'
key('F3')
assert(last()=='[StellarCoop] STOP: boom\n' and said[#said]=='boom','An error: refused, said')
bk.raise=nil

-- The first tick restores; each frame its steer runs before the native tick; every 250 ms its slow. An end of the ride
-- is logged and said.
assert(bk.restores==0 and bo.restores==0)
loops[1].f()
assert(bk.restores==1 and bk.steers==1 and bo.restores==1)
bk.says={false,'Off the bike: EVE is swimming'}
loops[1].f()
assert(last()=='[StellarCoop] STOP: Off the bike: EVE is swimming\n' and said[#said]=='Off the bike: EVE is swimming')
bk.says=nil
quarter()
assert(bk.slows==1 and bo.slows==1)
bk.slow_says={false,'Off the bike: a cutscene holds EVE'}
quarter()
assert(logged('STOP: Off the bike: a cutscene holds EVE') and said[#said]==bk.slow_says[2] and bo.slows==2)
bk.slow_says=nil

-- Our screens: the co-op menu, the lobby's screens, the guide in front of the co-op saves' question.
kit_ready=true; quarter()
local SCREEN='an SBO menu or the chat is open'
key('F5'); assert(kit_shown.menu and o.busy()==SCREEN,tostring(o.busy()))
-- F3 with the menu open still reaches the ride, which refuses a mount while busy() says why (vehicles/bike/ride_test).
key('F3'); assert(kit_shown.menu and bk.toggles[#bk.toggles]=='bike_key' and o.busy()==SCREEN)
key('F5'); assert(not kit_shown.menu and o.busy()==nil)
lb.screen='menu'; assert(o.busy()==SCREEN); lb.screen=nil
coop('guide'); assert(kit_shown.guide and o.busy()==SCREEN,tostring(o.busy()))
coop('ui','reset'); assert(not kit_shown.guide and o.busy()==nil)
-- The Sessions and Create a session screens: the menu closes for them and the game does not pause, so busy() says it.
for _,screen in ipairs({ss,cr}) do
    screen.open=true; assert(o.busy()==SCREEN,tostring(o.busy()))
    key('F3'); assert(bk.toggles[#bk.toggles]=='bike_key' and o.busy()==SCREEN)
    screen.open=false; assert(o.busy()==nil)
end

-- The pad: D-pad Right held 1 s (the native part's tenth event) as bike_key, in a world with our HUD shown, none of
-- our screens open and the game not paused; otherwise nothing, with the reason logged.
local function pad(...) for _,e in ipairs({...}) do pd.q[#pd.q+1]=e end; loops[1].f() end
n=#bk.toggles
in_world,at_title=false,true; quarter()
pad(10)
assert(#bk.toggles==n and not logged('pad: bike') and logged('pad: bike ignored: our HUD is not shown'),
    'At the title: nothing')
in_world,at_title,kit_ready=true,false,true; quarter()
pad(10)
assert(#bk.toggles==n+1 and bk.toggles[#bk.toggles]=='the pad' and logged('pad: bike'))
key('F5'); assert(kit_shown.menu)
pad(10)
assert(#bk.toggles==n+1 and kit_shown.menu and logged('pad: bike ignored: one of our screens is open'),
    'The co-op menu open: nothing')
key('F5')
kit_paused=true
pad(10)
assert(#bk.toggles==n+1 and logged('pad: bike ignored: the game is paused or shows one of its screens'),
    'The game paused or one of its screens: nothing')
kit_paused=false
-- The Options rows: bike off at once in the settings the ride reads (its 250 ms pass acts on it).
key('F5'); to('Options'); key('RETURN'); to('Bike')
assert(select(2,focus())=='On')
key('RIGHT_ARROW')
assert(select(2,focus())=='Off' and ('\n'..settings_text):find('\nbike=off\n',1,true) and o.settings.bike==false,
    settings_text)
key('LEFT_ARROW')
assert(o.settings.bike==true)
to('Get on or off the bike')
assert(select(2,focus())=='F3')
key('ESCAPE'); key('ESCAPE')

-- coop off: the ride's stop first, then its parked bike out of the world (the place kept), the other players' copies
-- with it, then the race's stop.
local stops=ra.stops
coop('off')
assert(bk.stops[#bk.stops]=='coop off' and bk.left=='coop off' and ra.stops==stops+1,tostring(bk.left))
assert(bo.cleared=='coop off',tostring(bo.cleared))
n=#bk.toggles
key('F3')
assert(#bk.toggles==n and last()=='[StellarCoop] STOP: coop off is active until the game restarts\n',last())

-- bike=off and another key in the file: the load line says so.
settings_text='bike=off\nbike_key=Shift+F2\n'
load_main(true)
assert(logged('bike: off, bike_key Shift+F2') and bk.o.settings.bike==false)
io.stdout:write('main bike_test ok\n')
