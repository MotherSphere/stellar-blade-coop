-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The day/night cycle's map table and rules (sky/rule.lua): the rows, the order of the rules, the native status line,
-- the command's hour, the sky dressing for an elevation, SkyCreator's time and the third-party plugin's path.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Rule=require('sky.rule')

-- 1. The table: every row of the design, the fixed ones, an unknown map.
local W='/game/art/bg/worldmap/e03_wasteland_p/e03_wasteland_p'
assert(Rule.row(W).cycle=='on' and Rule.row(W).hz==8 and Rule.row(W).heading==0 and Rule.row(W).sky=='real')
assert(Rule.row('/game/art/bg/worldmap/e05_greatdesert_p/e05_greatdesert_p').hz==2)
local E04='/game/art/bg/worldmap/level_p/e04'
assert(Rule.row(E04).heading==205 and Rule.row(E04).sky=='painted')
assert(Rule.row('/game/sbo_lobby/lobby_terrace').cycle=='fixed')
assert(Rule.row('/game/dlc_2/art/bg/worldmap_nk/nk_p').cycle=='fixed')
assert(Rule.row('/game/sbo_lobby/lobby_hotel').heading==308 and Rule.row('/game/sbo_lobby/lobby_hotel').sky=='engine')
assert(Rule.row('/game/somewhere/else')==nil and Rule.row(nil)==nil)
for map,row in pairs(Rule.MAPS) do -- Keys as U.map_of gives them; each open row complete for its kind of sky.
    assert(map==map:lower(),map)
    if row.cycle=='on' then
        assert(row.hz>=0 and row.hz<=30 and row.heading>=0 and row.heading<=359,map)
        assert((row.sky=='real')==(row.domes~=nil and #row.domes>0),map)
        assert((row.sky=='engine')==(row.engine~=nil),map)
    else
        assert(row.cycle=='fixed',map)
    end
end
assert(#Rule.row('/game/art/bg/worldmap/level_p/b07').domes==4,'Spire 4: four domes')
local X=Rule.row('/game/art/bg/worldmap/level_p/e04')
assert(X.day_dome and X.night_dome and X.flag and X.stars=='night_dome')
assert(Rule.row('/game/art/bg/worldmap_dlc_01/level_p/mxiii_p').engine.ppv=='Z0_PPV_Desert')
assert(Rule.row('/game/sbo_lobby/lobby_foyer').engine.ppv==nil)
-- 2. The rules, in their order.
local s={setting=true,map=W}
assert(Rule.decide(s)=='sky cycle 8 0' and select(2,Rule.decide(s))=='clock')
assert(select(2,Rule.decide({setting=false,map=W}))=='daynight=off' and Rule.decide({setting=false,map=W})=='sky off')
assert(Rule.decide({setting=true,test='off',map=W})=='sky off' and Rule.decide({setting=true})=='sky off')
assert(select(2,Rule.decide({setting=true,test='off',map=W}))=='coop daynight off')
assert(select(2,Rule.decide({setting=true}))=='no map')
assert(Rule.decide({setting=true,map='/game/art/bg/worldmap/level_p/c05'})=='sky off')
assert(select(2,Rule.decide({setting=true,map='/game/somewhere/else'}))=='fixed map')
assert(Rule.decide({setting=true,map=W,lobby=true})=='sky off')
assert(Rule.decide({setting=true,map=W,story_night=true})=='sky off')
assert(select(2,Rule.decide({setting=true,map=W,lobby=true,story_night=true}))=='SBO lobby')
assert(select(2,Rule.decide({setting=true,map=W,story_night=true,cutscene=true}))=='Xion story night')
assert(Rule.decide({setting=true,map=W,cutscene=true,photo=true})=='sky off','A cutscene beats photo mode')
assert(Rule.decide({setting=true,map=W,screen=true})=='sky off')
assert(select(2,Rule.decide({setting=true,map=W,screen=true}))=="the game's menu")
-- SB's photo mode pauses the game, so screen reads true in it: photo mode still holds the hour.
assert(Rule.decide({setting=true,map=W,screen=true,photo=true})=='sky hold','Photo mode beats the paused game')
assert(select(2,Rule.decide({setting=true,map=W,screen=true,photo=true}))=='photo mode')
assert(Rule.decide({setting=true,map=W,screen=true,photo=true,cutscene=true})=='sky off')
assert(Rule.decide({setting=true,map=W,photo=true,night=true})=='sky hold','Photo mode holds whatever the hour')
assert(select(2,Rule.decide({setting=true,map=W,photo=true}))=='photo mode')
-- Another player's photo mode or the host's cutscene pauses us with SB's pause tag (screen reads true): it holds too.
assert(Rule.decide({setting=true,map=W,screen=true,frozen=true})=='sky hold','Our held pause beats the paused game')
assert(select(2,Rule.decide({setting=true,map=W,screen=true,frozen=true}))=="another player's pause")
assert(Rule.decide({setting=true,map=W,frozen=true,cutscene=true})=='sky off','A cutscene beats our held pause')
assert(Rule.decide({setting=true,map=W,pinned=810,night=true})=='sky hour 810 8 0','A test pin beats Night Operation')
assert(select(2,Rule.decide({setting=true,map=W,pinned=810}))=='pinned')
assert(Rule.decide({setting=true,map=W,night=true})=='sky hour 0 8 0')
assert(select(2,Rule.decide({setting=true,map=W,night=true}))=='Night Operation')
assert(Rule.decide({setting=true,map='/game/art/bg/worldmap/level_p/e04'})=='sky cycle 8 205')
-- 3. The status line; an older DLL (Review Focus 2).
local n=Rule.native('engine=on\nsky=cycle h=0.0000 el=-30.0 le=30.000 ly=0.000 k=0.150 moon=1 amb=0.200 eve=0.500 '
    ..'ev=-1.00 tint=0.70,0.80,1.00 n=114 lit=20 seen=0\nslot=none\n')
assert(n.state=='cycle' and n.el==-30 and n.le==30 and n.k==0.15 and n.moon==true and n.seen==false and n.lit==20)
assert(n.tint[1]==0.7 and n.tint[3]==1 and n.h==0 and n.n==114 and n.ev==-1 and n.amb==0.2)
assert(Rule.native('engine=on\nslot=none\n')==nil and Rule.native(nil)==nil)
n=Rule.native('sky=cycle h=13.4200 el=62.5 le=62.490 ly=215.975 k=1.000 moon=0 amb=1.000 eve=1.000 ev=0.00 '
    ..'tint=1.00,1.00,1.00 n=114 lit=20 seen=1')
assert(n.h==13.42 and n.le==62.49 and n.ly==215.975,'The decimals the Sun and SkyCreators turn with')
assert(Rule.native('sky=refused h=12.00 el=65.0 le=65.0 ly=0.0 k=1.000 moon=0 amb=1.000 eve=1.000 ev=0.00 '
    ..'tint=1.00,1.00,1.00 n=0 lit=0 seen=0').state=='refused','The first line, with no line end')
-- 4. The command's hour (Review Focus 3).
assert(Rule.minute('13.5')==810 and Rule.minute('0')==0 and Rule.minute('23.99')==1439)
for _,bad in ipairs({'24','-1','abc','','13,5','1e9','0x10',' 5','inf','nan'}) do
    local m,why=Rule.minute(bad)
    assert(m==nil and why=='hour: a number from 0 to under 24',bad)
end
assert(select(2,Rule.minute(nil))=='hour: a number from 0 to under 24')
-- 5. Dressing, the star fade, SkyCreator's time, minutes to the night.
local d=Rule.dress(Rule.row(W),20)
assert(#d.hide==1 and d.stars==false and Rule.dress(Rule.row(W),-8).stars==true)
local x=Rule.row('/game/art/bg/worldmap/level_p/e04')
assert(Rule.dress(x,-5).night_dome==true and Rule.dress(x,-3).night_dome==false and #Rule.dress(x,-5).hide==0)
assert(Rule.dress(Rule.row('/game/art/bg/worldmap/level_p/f02'),-20).stars==false,'SkyCreator draws its own stars')
assert(Rule.star_fade(-4)==0 and Rule.star_fade(-6)==0.5 and Rule.star_fade(-9)==1 and Rule.star_fade(10)==0)
assert(Rule.creator_time(4,5,21)==5 and Rule.creator_time(12,5,21)==13 and Rule.creator_time(20,5,21)==21)
assert(Rule.creator_time(0,5,21)==1)
assert(Rule.until_night(12)==20 and Rule.until_night(21)==0 and Rule.until_night(19.6)==1)
assert(Rule.until_night(2)==0)
-- 6. The third-party plugin's file, three folders up from the mod's.
assert(Rule.cps('C:\\SB\\Binaries\\Win64\\ue4ss\\Mods\\StellarCoop\\')==
    'C:\\SB\\Binaries\\Win64\\ue4ss\\Mods\\StellarCoop\\..\\..\\..\\CPS\\Plugins\\activate_day_night_cycle.cps')
assert(Rule.cps('C:\\Mods\\StellarCoop')==
    'C:\\Mods\\StellarCoop\\..\\..\\..\\CPS\\Plugins\\activate_day_night_cycle.cps')
print('rule_test ok')
