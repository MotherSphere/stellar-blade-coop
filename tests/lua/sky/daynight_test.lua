-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- sky/daynight.lua over a fake engine: one request per change, the map read once per EVE, the menu's setting, the
-- rules' cases (cutscene, photo mode, Night Operation, the SBO lobby, Xion's story night read every 2 s), the command's
-- words, a fixed map and the title, the status with an older DLL, coop off, a refused ask, the third-party plugin's
-- file logged once.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Rule=require('sky.rule')
local Daynight=require('sky.daynight')

local W='/game/art/bg/worldmap/e03_wasteland_p/e03_wasteland_p'
local E04='/game/art/bg/worldmap/level_p/e04'
local CPS='C:\\SB\\Binaries\\Win64\\CPS\\Plugins\\activate_day_night_cycle.cps'
local NOON='sky=cycle h=12.00 el=65.0 le=65.0 ly=0.0 k=1.000 moon=0 amb=1.000 eve=1.000 ev=0.00 tint=1.00,1.00,1.00 '
    ..'n=114 lit=20 seen=1\n'
local asked,printed={},{}
local calls={map_of=0,find=0,find_flag=0,flag_reads=0}
local settings={daynight=true}
local world={cutscene=false,screen=false,photo='0',night=false,lobby=false}
local st={text='engine=on\n'..NOON}
local refuse=nil -- The ask's refusal while set.
local flag_state={bActiveVolume=false}
local flag=setmetatable({},{
    __index=function(_,k)
        if k=='bActiveVolume' then calls.flag_reads=calls.flag_reads+1 end
        return flag_state[k]
    end,
    __newindex=function(_,k,v) flag_state[k]=v end})
local objects={[Rule.MAPS[E04].flag]=flag}
local function new_eve(at,map) return {at=at,map=map} end
local eve=new_eve(0x100,W)
local o={log=function(m) printed[#printed+1]=m end,
    ask=function(line)
        if refuse then return false,refuse end
        asked[#asked+1]=line
        return true,'asked the native part: '..line
    end,
    status=function() return st.text end,settings=settings,
    her=function() return eve end,address=function(e) return e.at end,
    map_of=function(e) calls.map_of=calls.map_of+1; return e.map end,
    cutscene=function() return world.cutscene end,screen=function() return world.screen end,
    photo=function() return world.photo end,night=function() return world.night end,
    lobby=function() return world.lobby end,
    find=function(path)
        calls.find=calls.find+1
        if path==Rule.MAPS[E04].flag then calls.find_flag=calls.find_flag+1 end
        return objects[path]
    end,
    actors_of=function() return {} end,load=function() end,
    exists=function(path) return path==CPS end,cps=CPS}
local function count_logged(pattern)
    local n=0
    for _,m in ipairs(printed) do if m:find(pattern) then n=n+1 end end
    return n
end
local function logged(pattern) return count_logged(pattern)>0 end
local D=Daynight.new(o)

-- 1. First pass on the Wasteland at noon: one ask; nothing more while nothing changes; the map read once per EVE.
D.slow(false); D.slow(false)
assert(#asked==1 and asked[1]=='sky cycle 8 0' and calls.map_of==1)
assert(logged('^daynight: cycle 8 0 %(clock%)$') and count_logged('^daynight: cycle')==1)
-- 2. daynight=off from the menu: one off; back on: one cycle.
settings.daynight=false; D.slow(false); assert(asked[2]=='sky off' and logged('daynight: off %(daynight=off%)'))
settings.daynight=true; D.slow(false); assert(asked[3]=='sky cycle 8 0')
-- 3. A cutscene, photo mode, Night Operation, the SBO lobby, SB's screens.
world.cutscene=true; D.slow(false); world.cutscene=false; D.slow(false); assert(asked[4]=='sky off' and asked[5]=='sky cycle 8 0')
world.photo='1'; D.slow(false); world.photo='0'; D.slow(false); assert(asked[6]=='sky hold' and asked[7]=='sky cycle 8 0')
world.night=true; D.slow(false); assert(asked[8]=='sky hour 0 8 0'); world.night=false; D.slow(false)
world.lobby=true; D.slow(false); assert(asked[#asked]=='sky off'); world.lobby=false; D.slow(false)
world.screen=true; D.slow(false); assert(asked[#asked]=='sky off' and logged("%(the game's menu%)"))
world.screen=false; D.slow(false); assert(asked[#asked]=='sky cycle 8 0')
-- 4. The command: hour, on, off; hour refused with daynight=off or a bad hour.
assert(D.command('hour','13.5')); D.slow(false); assert(asked[#asked]=='sky hour 810 8 0')
assert(D.command('off')); D.slow(false); assert(asked[#asked]=='sky off')
assert(D.command('on')); D.slow(false); assert(asked[#asked]=='sky cycle 8 0')
settings.daynight=false; local ok,why=D.command('hour','3'); assert(not ok and why:find('daynight=off')); settings.daynight=true
ok,why=D.command('hour','24'); assert(not ok and why=='coop daynight hour: a number from 0 to under 24',why)
-- 5. A fixed map, then the title (no EVE): off each time; back on the Wasteland: the cycle.
eve=new_eve(0x200,'/game/art/bg/worldmap/level_p/c05'); D.slow(false); assert(asked[#asked]=='sky off')
eve=new_eve(0x210,W); D.slow(false); assert(asked[#asked]=='sky cycle 8 0')
eve=nil; D.slow(false); assert(asked[#asked]=='sky off' and logged('daynight: off %(no map%)'))
-- 6. Xion: the story-night flag looked up once per Xion entry, read every 2 s (8 passes), off while it is active.
eve=new_eve(0x300,E04); for _=1,8 do D.slow(false) end
assert(asked[#asked]=='sky cycle 8 205' and calls.find_flag==1 and calls.flag_reads==1)
flag.bActiveVolume=true; for _=1,8 do D.slow(false) end
assert(asked[#asked]=='sky off' and logged('Xion story night') and calls.find_flag==1 and calls.flag_reads==2)
-- 7. Status: hour, sun, row, native state, minutes to the night; Review Focus 2: an older DLL, no request loop.
st.text=NOON
assert(D.status():find('12:00') and D.status():find('20 min') and D.status():find('painted sky'),D.status())
local before=#asked
st.text='engine=on\n'; D.slow(false); assert(D.status():find('the native part gives no sky line') and #asked==before)
-- 8. coop off: one off, then nothing.
before=#asked; D.slow(true); D.slow(true); assert(#asked==before+1 and asked[#asked]=='sky off')
assert(logged('daynight: off %(coop off%)'))
-- 9. The third-party plugin found: one log line at the first pass, never again.
assert(count_logged('activate_day_night_cycle.cps')==1)
-- A refused ask: logged once, asked again at each pass until it goes through.
flag_state.bActiveVolume=false
local R=Daynight.new(o)
eve,asked,refuse=new_eve(0x320,W),{},'busy'
R.slow(false); R.slow(false)
assert(#asked==0 and count_logged('not asked: busy')==1)
refuse=nil; R.slow(false); assert(#asked==1 and asked[1]=='sky cycle 8 0')
-- A missing story-night flag: logged once in that world, not looked up again there; looked up again in the next.
objects[Rule.MAPS[E04].flag]=nil
local finds=calls.find_flag
eve=new_eve(0x340,E04); for _=1,9 do R.slow(false) end
assert(calls.find_flag==finds+1 and count_logged('no story%-night flag')==1 and asked[#asked]=='sky cycle 8 205')
eve=new_eve(0x350,E04); R.slow(false); assert(calls.find_flag==finds+2)
print('daynight_test ok')
