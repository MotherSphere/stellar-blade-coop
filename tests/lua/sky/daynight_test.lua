-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- sky/daynight.lua over a fake engine: one request per change, the map read once per EVE, the menu's setting, the
-- rules' cases (cutscene, photo mode, Night Operation, the SBO lobby, Xion's story night read every 2 s), the command's
-- words, a fixed map and the title, the status with an older DLL, coop off, a refused ask, the third-party plugin's
-- file logged once; the sky dressing: the domes looked up once per world and hidden once, a missing one logged once,
-- the star layer made once with its material loaded once a world and faded on change, the SkyCreators' time on change
-- and back at an off, Xion's night dome, coop off, a Lua reload that finds the layer by its tag, an earlier load's
-- dressing put back by a new load that starts off.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Rule=require('sky.rule')
local Daynight=require('sky.daynight')
FName=function(t) return {type=function() return 'FName' end,ToString=function() return t end} end
local function uobj(t)
    t.type=function() return 'UObject' end
    t.IsValid=t.IsValid or function(self) return not self.gone end
    return t
end

local W='/game/art/bg/worldmap/e03_wasteland_p/e03_wasteland_p'
local E04='/game/art/bg/worldmap/level_p/e04'
local F02='/game/art/bg/worldmap/level_p/f02'
local DOME=Rule.MAPS[W].domes[1]
local CPS='C:\\SB\\Binaries\\Win64\\CPS\\Plugins\\activate_day_night_cycle.cps'
local NOON='sky=cycle h=12.00 el=65.0 le=65.0 ly=0.0 k=1.000 moon=0 amb=1.000 eve=1.000 ev=0.00 tint=1.00,1.00,1.00 '
    ..'n=114 lit=20 seen=1\n'
local asked,printed={},{}
local calls={map_of=0,find=0,find_flag=0,flag_reads=0,find_dome=0,load=0,add_component=0,make_mid=0,
    actors_of_creator=0}
local settings={daynight=true}
local world={cutscene=false,screen=false,photo='0',night=false,lobby=false}
-- The native status: text as it is, else a sky= line from the fields.
local st={text='engine=on\n'..NOON,state='cycle',h=12,el=65}
local function status()
    if st.text then return st.text end
    return string.format('engine=on\nsky=%s h=%.2f el=%.1f le=%.1f ly=0.0 k=1.000 moon=0 amb=1.000 eve=1.000 '
        ..'ev=0.00 tint=1.00,1.00,1.00 n=114 lit=20 seen=1\n',st.state,st.h,st.el,math.abs(st.el))
end
local refuse=nil -- The ask's refusal while set.
local flag_state=uobj({bActiveVolume=false})
local flag=setmetatable({},{
    __index=function(_,k)
        if k=='bActiveVolume' then calls.flag_reads=calls.flag_reads+1 end
        return flag_state[k]
    end,
    __newindex=function(_,k,v) flag_state[k]=v end})
-- A dome's root component: its SetVisibility calls (never propagated) and whether it is hidden.
local function new_root(hidden)
    return uobj({hidden=hidden,vis_calls=0,StaticMesh='SM_SkySphere',
        SetVisibility=function(self,v,children)
            assert(children==false,'Never to the children: the star layer is one')
            self.vis_calls,self.hidden=self.vis_calls+1,not v
        end})
end
local emissive={} -- The star fade's writes.
local mid=uobj({SetScalarParameterValue=function(_,name,v)
    assert(name:ToString()=='StarEmissive')
    emissive[#emissive+1]=v
end})
local function new_component()
    return uobj({visible=true,ComponentTags={},
        SetStaticMesh=function(self,m) self.mesh=m end,SetMaterial=function(self,i,m) self.material=m; self.slot=i end,
        SetCollisionEnabled=function(self,v) self.collision=v end,SetCastShadow=function(self,v) self.shadow=v end,
        ComponentHasTag=function(self,tag)
            return self.ComponentTags[1]~=nil and self.ComponentTags[1]:ToString()==tag:ToString()
        end,
        SetVisibility=function(self,v) self.visible=v end,
        CreateDynamicMaterialInstance=function(_,i,m)
            assert(i==0 and m)
            calls.make_mid=calls.make_mid+1
            return mid
        end})
end
local dome=new_root(false)
local dome_actor=uobj({RootComponent=dome,components={}})
function dome_actor:AddComponentByClass(class,manual,transform,deferred)
    assert(class.path=='/Script/Engine.StaticMeshComponent' and manual==false and transform and deferred==false)
    calls.add_component=calls.add_component+1
    local c=new_component()
    self.components[#self.components+1]=c
    return c
end
function dome_actor:K2_GetComponentsByClass(class)
    assert(class.path=='/Script/Engine.StaticMeshComponent')
    return self.components
end
local xion_day,xion_night=new_root(false),new_root(true)
local material=uobj({ScalarParameterValues={{ParameterInfo={Name=FName('Tint')}},
    {ParameterInfo={Name=FName('StarEmissive')}}}})
local creator=uobj({SunriseTime=5,SunsetTime=21,times={},GetTime=function() return 12 end,
    SetTime=function(self,t) self.times[#self.times+1]=t end})
local objects={[Rule.MAPS[E04].flag]=flag,
    ['/Script/Engine.StaticMeshComponent']=uobj({path='/Script/Engine.StaticMeshComponent'}),
    ['/Script/Engine.Default__KismetMathLibrary']=uobj({MakeTransform=function() return {} end}),
    [Rule.MAPS[E04].day_dome]=uobj({RootComponent=xion_day}),
    [Rule.MAPS[E04].night_dome]=uobj({RootComponent=xion_night})}
local function new_eve(at,map) return {at=at,map=map} end
local eve=new_eve(0x100,W)
local o={log=function(m) printed[#printed+1]=m end,
    ask=function(line)
        if refuse then return false,refuse end
        asked[#asked+1]=line
        return true,'asked the native part: '..line
    end,
    status=status,settings=settings,
    her=function() return eve end,address=function(e) return e.at end,
    map_of=function(e) calls.map_of=calls.map_of+1; return e.map end,
    cutscene=function() return world.cutscene end,screen=function() return world.screen end,
    photo=function() return world.photo end,night=function() return world.night end,
    lobby=function() return world.lobby end,
    find=function(path)
        calls.find=calls.find+1
        if path==Rule.MAPS[E04].flag then calls.find_flag=calls.find_flag+1 end
        if path==DOME then calls.find_dome=calls.find_dome+1 end
        return objects[path]
    end,
    actors_of=function(path)
        assert(path==Rule.CREATOR,path)
        calls.actors_of_creator=calls.actors_of_creator+1
        return {creator}
    end,
    load=function(path)
        assert(path==Rule.STARS)
        calls.load=calls.load+1
        objects[path]=material
    end,
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
world.cutscene=true; D.slow(false); world.cutscene=false; D.slow(false)
assert(asked[4]=='sky off' and asked[5]=='sky cycle 8 0')
world.photo='1'; D.slow(false); world.photo='0'; D.slow(false)
assert(asked[6]=='sky hold' and asked[7]=='sky cycle 8 0')
world.night=true; D.slow(false); assert(asked[8]=='sky hour 0 8 0'); world.night=false; D.slow(false)
world.lobby=true; D.slow(false); assert(asked[#asked]=='sky off'); world.lobby=false; D.slow(false)
world.screen=true; D.slow(false); assert(asked[#asked]=='sky off' and logged("%(the game's menu%)"))
world.screen=false; D.slow(false); assert(asked[#asked]=='sky cycle 8 0')
-- 4. The command: hour, on, off; hour refused with daynight=off or a bad hour.
assert(D.command('hour','13.5')); D.slow(false); assert(asked[#asked]=='sky hour 810 8 0')
assert(D.command('off')); D.slow(false); assert(asked[#asked]=='sky off')
assert(D.command('on')); D.slow(false); assert(asked[#asked]=='sky cycle 8 0')
settings.daynight=false; local ok,why=D.command('hour','3'); assert(not ok and why:find('daynight=off'))
settings.daynight=true
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

-- The sky dressing, on a new load with the status from st's fields.
printed,asked,st.text=({}),({}),nil
for k in pairs(calls) do calls[k]=0 end
flag.bActiveVolume=false
objects[DOME],objects[Rule.MAPS[E04].flag]=dome_actor,flag
st.state,st.h,st.el=nil,12,20
-- An earlier load that asked nothing (a game start: the native part is off): a new load that starts off looks up
-- nothing.
st.state='off'; settings.daynight=false
eve=new_eve(0x380,W); D=Daynight.new(o); D.slow(false); D.slow(false)
assert(calls.find==0 and not logged(' domes, '))
settings.daynight=true; st.state='cycle'
-- 10. A real-sky map by day: each dome looked up once per world, hidden once; the next passes call nothing.
D.slow(false)
assert(calls.find_dome==1 and dome.hidden==true and dome.vis_calls==1 and logged('^daynight: '..W..': 1 of 1 domes'))
D.slow(false); assert(dome.vis_calls==1 and calls.find_dome==1 and calls.load==0)
-- 11. A dome that is not there: logged once, not looked up again in this world; looked up again in the next.
objects[DOME]=nil; eve=new_eve(0x400,W); for _=1,8 do D.slow(false) end
assert(calls.find_dome==2 and count_logged('no dome')==1)
eve=new_eve(0x410,W); D.slow(false); assert(calls.find_dome==3)
-- 12. Night (el -10) on a star-layer map: the material loaded once this world, the layer added once and shown; dawn
--     hides it.
objects[DOME]=dome_actor; eve=new_eve(0x420,W); st.el=-10; D.slow(false); D.slow(false)
local layer=dome_actor.components[1]
assert(calls.load==1 and calls.add_component==1 and layer.visible==true)
assert(layer.ComponentTags[1]:ToString()=='SBO_Stars')
assert(layer.mesh=='SM_SkySphere' and layer.material==material and layer.shadow==false and layer.collision==0)
assert(logged('star material loaded in .* ms, faded by StarEmissive'))
st.el=2; D.slow(false); assert(layer.visible==false and calls.load==1 and dome.hidden==true)
-- 13. The fade: a dynamic instance made once; the scalar written only when the fade changed.
emissive={}; st.el=-5; D.slow(false); st.el=-6; D.slow(false); D.slow(false)
assert(calls.make_mid==1 and #emissive==2 and emissive[1]==0.25 and emissive[2]==0.5 and layer.visible==true)
-- 14. SkyCreator maps: the actors listed once per world; SetTime(Rule.creator_time(h,5,21)) only when the hour moved;
--     its own time back at an off.
eve=new_eve(0x500,F02); st.h=12; D.slow(false); D.slow(false); st.h=12.01; D.slow(false)
assert(calls.actors_of_creator==1 and #creator.times==2 and creator.times[1]==13)
settings.daynight=false; D.slow(false); D.slow(false)
assert(#creator.times==3 and creator.times[3]==12); settings.daynight=true
-- 15. Xion: at el -5 the day dome hides and the night dome shows; at el -3 both go back.
eve=new_eve(0x600,E04); st.el=-5; D.slow(false)
assert(xion_day.hidden==true and xion_night.hidden==false)
st.el=-3; D.slow(false); assert(xion_day.hidden==false and xion_night.hidden==true)
-- 16. Off: Xion's domes back to SB's shipped state; with Xion's story night on, they are left as they are.
st.el=-5; D.slow(false); D.slow(true); assert(xion_day.hidden==false and xion_night.hidden==true)
D=Daynight.new(o); D.slow(false); st.el=-5; D.slow(false); flag.bActiveVolume=true; for _=1,8 do D.slow(false) end
assert(asked[#asked]=='sky off' and xion_day.hidden==true and xion_night.hidden==false,
    'SB owns them during its story night')
flag.bActiveVolume=false
-- 17. Review Focus 1: a new load at night finds the tagged layer (no second AddComponentByClass), hides the domes
--     again; coop off after that reload shows every dome.
eve=new_eve(0x700,W); st.el=-10; D.slow(false); local added=calls.add_component
assert(added==1 and logged("an earlier load's star layer"))
local D2=Daynight.new(o); D2.slow(false)
assert(calls.add_component==added and dome.hidden==true and layer.visible==true)
D2.slow(true); assert(dome.hidden==false and layer.visible==false)
-- A new load that starts off while the native part still holds an earlier load's cycle puts that load's dressing back.
dome.hidden,layer.visible=true,true
settings.daynight=false
local D3=Daynight.new(o); D3.slow(false); assert(dome.hidden==false and layer.visible==false)
settings.daynight=true
print('daynight_test ok')
