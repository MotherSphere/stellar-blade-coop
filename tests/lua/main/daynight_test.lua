-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The day/night cycle through main.lua (fixture.lua's fake sky/daynight.lua; sky/daynight_test tests the module): what
-- it is built with (the native asks and status, the setting, SB's state it reads, the plugin's path), its 250 ms pass
-- with coop off, coop daynight and its words.
dofile('tests/lua/main/fixture.lua')
local USE='[StellarCoop] STOP: Use: coop daynight [on | off | status | hour <h>]\n'
settings_text,status_text,in_world='',plain,true
load_main(true)
local o=dn.o
assert(o.settings.daynight==true and o.status()==status_text)
assert(o.ask('sky off') and asked[#asked]=='sky off')
assert(o.cps=='mod/StellarCoop\\..\\..\\..\\CPS\\Plugins\\activate_day_night_cycle.cps',o.cps)
-- SB's state it reads: a cutscene, its screens, photo mode, Night Operation, the lobby in Xion's training room only.
assert(o.cutscene()==false and o.screen()==false and o.photo()=='0' and o.night()==false and o.lobby()==false)
gr.playing,kit_paused,photo_mode,nr.running=true,true,true,true
assert(o.cutscene()==true and o.screen()==true and o.photo()=='1' and o.night()==true)
gr.playing,kit_paused,photo_mode,nr.running=nil,false,false,nil
sb.target={key='xion'}; assert(o.lobby()==true)
sb.target={key='hotel'}; assert(o.lobby()==false,'A hall lobby has its own row')
sb.target=nil
-- Each 250 ms pass, with coop off as it stands.
quarter(); assert(dn.slows[#dn.slows]==false)
-- coop daynight: alone or status, on, off, hour <h>; anything else is its usage line.
coop('daynight'); assert(last()=='[StellarCoop] OK: daynight: test\n',last())
coop('daynight','status'); assert(last()=='[StellarCoop] OK: daynight: test\n',last())
coop('daynight','hour','13.5'); assert(dn.words[1][1]=='hour' and dn.words[1][2]=='13.5' and last()=='[StellarCoop] OK: dn hour\n')
coop('daynight','off'); coop('daynight','on')
assert(dn.words[2][1]=='off' and dn.words[3][1]=='on' and #dn.words==3)
for _,bad in ipairs({{'hour'},{'on','x'},{'status','x'},{'sometimes'},{'hour','3','x'}}) do
    coop('daynight',table.unpack(bad))
    assert(last()==USE and #dn.words==3,last())
end
-- coop off: the next passes give off.
coop('off'); quarter(); assert(dn.slows[#dn.slows]==true)
io.stdout:write('main daynight_test ok\n')
