-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode through main.lua (fixture.lua's fake fight/gunmode/mode.lua; fight/gunmode/stop_test tests the mode): its
-- coop-gun.txt through the link's store (none without the native part), the photo mode as the runtime reads it, the
-- other modules' states that hold EVE (busy), D-pad Right taken while spectate watches (pad_taken), its restore at the
-- first tick before its tick, coop off's stop and after a Lua reload with coop off still on its restore alone. Its hud
-- build step gets the kit and its theme (the D-pad rifle slot), with the Steam link only.
dofile('tests/lua/main/fixture.lua')
-- coop fly's keys: eve/flight.lua for real, with fly_on in place of its active() (on() needs SB's player input).
local Flight,fly_on=require('eve.flight'),nil
package.loaded['eve.flight']={new=function(o)
    local f=Flight.new(o)
    f.active=function() return fly_on end
    return f
end}
settings_text,status_text,in_world='',plain,true
load_main(true)
assert(gm.o.store=='store coop-gun.txt',tostring(gm.o.store))
assert(gm.hud and gm.hud.kit~=nil and gm.hud.theme==require('ui.kit.kit').THEME,'the hud step gets the kit')
-- The photo mode as the runtime reads it: no rifle in the photo or selfie mode.
assert(gm.o.photo()=='0')
photo_mode=true; assert(gm.o.photo()=='1')
selfie_mode=true; assert(gm.o.photo()=='s')
photo_mode,selfie_mode=false,false
-- What other modules hold EVE in, each with its reason; none when nothing does.
assert(gm.o.busy()==nil)
for _,case in ipairs({{function(on) bk.riding=on end,'EVE rides the bike'},
        {function(on) dr.active=on end,'the Doro look is on'},
        {function(on) em.active=on end,'coop emote plays'},
        {function(on) sb.sitting=on end,'EVE sits on a hall seat'},
        {function(on) fly_on=on end,'coop fly is on'},
        {function(on) gl.active=on end,'coop glide is on'}}) do
    case[1](true)
    assert(gm.o.busy()==case[2],tostring(gm.o.busy()))
    case[1](nil)
end
assert(gm.o.busy()==nil)
-- An SBO match: a round in play (the link's match line) or the PvP test (coop pvp: the fight line's mode).
assert(gm.o.match()==false)
for _,case in ipairs({{{state='playing',mode='ffa'},nil,true},{{state='countdown',mode='ffa'},nil,false},
        {{state='open',mode='ffa'},nil,false},{{state='searching',mode='ffa'},nil,false},
        {nil,'fight=on mode=pvp proxy=0 sent=0 unnamed=0 lines=0',true},
        {nil,'fight=waiting mode=pvp why=no friend linked',true},
        {nil,'fight=on mode=on role=host enemies=0 claims=0',false},{nil,'fight=off',false}}) do
    link_match,fight_text=case[1],case[2]
    assert(gm.o.match()==case[3],tostring(fight_text or link_match.state))
end
link_match,fight_text=nil,nil
-- D-pad Right's tap is spectate's while it watches (fight/enemies/spectate.lua's switch): gun mode then takes none.
assert(gm.o.pad_taken()==false)
sp.watching=true; assert(gm.o.pad_taken()==true)
sp.watching=false
-- Its notices in the menu's words: the rebuilding one by default, the match one and each refusal by its key.
gm.o.notice()
assert(said_en[#said_en]=='Gun mode: rebuilding',tostring(said_en[#said_en]))
gm.o.notice('match')
assert(said_en[#said_en]:find('^Gun mode: not during a match%.'),tostring(said_en[#said_en]))
for _,key in ipairs({'aim','eve','busy','failed'}) do
    gm.o.notice(key)
    assert(said_en[#said_en]==require('ui.text').en.gun[key],key..': '..tostring(said_en[#said_en]))
end
-- Its settings as main.lua read them (gun_mode and gun_key among SBO's own; no unknown-setting line for its test lines)
-- and the menu's words for its HUD.
assert(gm.o.settings.gun_key.name=='F4' and gm.o.settings.gun_mode==true,'gun mode gets M.settings')
assert(gm.o.words().gun.reload=='RELOADING','gun mode gets the menu\'s words')
settings_text='gun_key=F11\ngun_zoom=toggle\ngun_trace=on\n'
load_main(true)
assert(gm.o.settings.gun_key.name=='F11' and gm.o.settings.gun_zoom=='toggle')
assert(not logged('unknown setting'),table.concat(printed,'|'))
settings_text=''
load_main(true)
assert(gm.restores==0 and gm.ticks==0)
loops[1].f()
assert(gm.restores==1 and gm.ticks==1)
coop('off')
assert(#gm.stops==1 and gm.stops[1]=='coop off',table.concat(gm.stops,'|'))
loops[1].f()
assert(gm.ticks==1,'No tick after coop off')
-- coop off survives a Lua reload: the first tick still restores what an earlier load left; no tick.
status_text='mod=v proto=3 steam=ready\nlink=none lobby=0\nengine=off reason=coop_off\nlast=#9 coop off\n'
load_main(true)
loops[1].f()
assert(gm.restores==1 and gm.ticks==0)
-- No native part: no coop-gun.txt.
status_text=plain
load_main(false)
assert(gm.o and gm.o.store==nil)
assert(gm.hud==nil,'No native part: no kit, no slot')
assert(gm.o.match()==false,'No native part: no match')
-- No native part: main.lua reads no settings, so gun mode reads coop-settings.txt itself. gun_mode=off still holds.
assert(gm.o.settings.gun_mode==true and gm.o.settings.gun_key.name=='F4','no file: the defaults')
disk.files['mod/StellarCoop\\coop-settings.txt']='gun_mode=off\ngun_key=F11\n'
load_main(false)
assert(gm.o.settings.gun_mode==false and gm.o.settings.gun_key.name=='F11','no native part: the file read')
disk.files['mod/StellarCoop\\coop-settings.txt']=nil
io.stdout:write('main gun_test ok\n')
