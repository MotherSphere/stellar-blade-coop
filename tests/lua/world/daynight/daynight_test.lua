-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- world/daynight/daynight.lua over a fake engine: one request per change, the map read once per EVE, the menu's
-- setting, the rules' cases (photo mode, Night Operation, the SBO lobby, Xion's story night read every 2 s),
-- the command's words, a fixed map and the title, the status with an older DLL, coop off, a refused ask, the
-- third-party plugin's file logged once; the sky dressing: the domes looked up once per world and hidden once, a
-- missing one logged once, the star layer made once with its material loaded once a world and faded on change, the
-- SkyCreators' time on change and back at an off, Xion's night dome, coop off, a Lua reload that finds the layer by its
-- tag, an earlier load's dressing put back by a new load that starts off; SBO's own maps: the Sun turned, its intensity
-- and colour and the SkyLight's scaled, Matrix XIII's exposure bias lowered, each written on change only and put back
-- at an off; the Terrace hall left alone.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Rule=require('world.daynight.rule')
local Daynight=require('world.daynight.daynight')
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
    actors_of_creator=0,actors_of_lights=0,rotate=0,set_intensity=0,set_color=0,bias_writes=0,level=0}
local streamed={} -- SB's streaming levels by package, for GetStreamingLevel: none unless a test sets one.
local creator_list=nil -- The SkyCreators listed, when a test sets them.
local settings={daynight=true}
local world={photo='0',frozen=false,night=false,lobby=false}
-- The native status: text as it is, else a sky= line from the fields.
local st={text='engine=on\n'..NOON,state='cycle',h=12,el=65}
local function status()
    if st.text then return st.text end
    local t=st.tint or {1,1,1}
    return string.format('engine=on\nsky=%s h=%.4f el=%.1f le=%.3f ly=%.3f k=%.3f moon=0 amb=%.3f eve=1.000 ev=%.2f '
        ..'tint=%.2f,%.2f,%.2f n=114 lit=20 seen=1\n',st.state,st.h,st.el,st.le or math.abs(st.el),st.ly or 0,
        st.k or 1,st.amb or 1,st.ev or 0,t[1],t[2],t[3])
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
    return setmetatable(uobj({hidden=hidden,vis_calls=0,StaticMesh='SM_SkySphere',
        SetVisibility=function(self,v,children)
            assert(children==false,'Never to the children: the star layer is one')
            self.vis_calls,self.hidden=self.vis_calls+1,not v
        end}),{__index=function(self,k) if k=='bVisible' then return not rawget(self,'hidden') end end})
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
-- Xion's domes as SB ships them (the pak dump): the day dome shown; the night dome's mesh visible, its actor hidden.
local xion_day,xion_night=new_root(false),new_root(false)
local night_actor=uobj({RootComponent=xion_night,bHidden=true,
    SetActorHiddenInGame=function(self,v) self.bHidden=v end})
local material=uobj({ScalarParameterValues={{ParameterInfo={Name=FName('Tint')}},
    {ParameterInfo={Name=FName('StarEmissive')}}}})
local creator=uobj({at=0xC0,SunriseTime=5,SunsetTime=21,times={},time=12,GetTime=function(self) return self.time end,
    SetTime=function(self,t) self.times[#self.times+1]=t; self.time=t end})
local objects={[Rule.MAPS[E04].flag]=flag,
    ['/Script/Engine.StaticMeshComponent']=uobj({path='/Script/Engine.StaticMeshComponent'}),
    ['/Script/Engine.Default__KismetMathLibrary']=uobj({MakeTransform=function() return {} end}),
    [Rule.MAPS[E04].day_dome]=uobj({RootComponent=xion_day}),
    [Rule.MAPS[E04].night_dome]=night_actor}
-- SBO's own maps: a light actor is its own light component here (rotation, intensity, colour in one record).
local HOTEL,MX='/game/sbo_lobby/lobby_hotel','/game/art/bg/worldmap_dlc_01/level_p/mxiii_p'
local SUN,SKY_LIGHT='/Script/Engine.DirectionalLight','/Script/Engine.SkyLight'
local VOLUME='/Script/Engine.PostProcessVolume'
local function new_light(name,intensity,pitch,yaw,rgb)
    local a=uobj({name=name,Intensity=intensity,intensity=intensity,rot={Pitch=pitch,Yaw=yaw,Roll=0},
        LightColor=rgb or {R=255,G=255,B=255,A=255},
        GetFName=function(self) return FName(self.name) end,
        K2_GetActorRotation=function(self) return {Pitch=self.rot.Pitch,Yaw=self.rot.Yaw,Roll=0} end,
        K2_SetActorRotation=function(self,r,teleport)
            assert(teleport==false and r.Roll==0)
            calls.rotate=calls.rotate+1
            self.rot=r
        end,
        SetIntensity=function(self,v) calls.set_intensity=calls.set_intensity+1; self.intensity,self.Intensity=v,v end,
        SetLightColor=function(self,c,srgb) -- Kept as the engine keeps it: an 8-bit sRGB FColor.
            assert(srgb==true and c.A==1)
            calls.set_color=calls.set_color+1
            local function byte(x) return math.floor(255*(x<=0.0031308 and 12.92*x or 1.055*x^(1/2.4)-0.055)+0.5) end
            self.color,self.LightColor=c,{R=byte(c.R),G=byte(c.G),B=byte(c.B),A=255}
        end})
    a.LightComponent=a
    return a
end
local sun,fill,skylight=new_light('Sun',7.5,-58,-52),new_light('Fill',3,-20,10),new_light('SkyLight',1,0,0)
local mx_sun=new_light('DirectionalLight_0',4,-8,85,{R=255,G=192,B=138,A=255})
local settings_bias=setmetatable({},{__index={AutoExposureBias=1.0},__newindex=function(t,k,v)
    calls.bias_writes=calls.bias_writes+1
    getmetatable(t).__index[k]=v
end})
local ppv=uobj({name='Z0_PPV_Desert',Settings=settings_bias,GetFName=function(self) return FName(self.name) end})
local zone1=uobj({name='Z1_PPV',GetFName=function(self) return FName(self.name) end})
local lists={[HOTEL]={[SUN]={fill,sun},[SKY_LIGHT]={skylight}},
    [MX]={[SUN]={mx_sun},[SKY_LIGHT]={new_light('SkyLight',0,0,0)},[VOLUME]={zone1,ppv}}}
-- EVE at address at in a world of map; each EVE in a world of her own unless world says it.
local function new_eve(at,map,world) return {at=at,map=map,world=world or at} end
-- coop-sky.txt: its line and whether a write fails.
local sky_file={line=nil,fails=nil,writes=0}
local eve=new_eve(0x100,W)
local o={log=function(m) printed[#printed+1]=m end,
    ask=function(line)
        if refuse then return false,refuse end
        asked[#asked+1]=line
        return true,'asked the native part: '..line
    end,
    status=status,settings=settings,
    her=function() return eve end,address=function(e) return e.at end,world=function(e) return e.world end,
    store={save=function(line)
        if sky_file.fails then return false,sky_file.fails end
        sky_file.line,sky_file.writes=line,sky_file.writes+1
        return true
    end,load=function() return sky_file.line end},
    map_of=function(e) calls.map_of=calls.map_of+1; return e.map end,
    photo=function() return world.photo end,frozen=function() return world.frozen end,
    night=function() return world.night end,
    lobby=function() return world.lobby end,stars_ready=function() return not world.stars_wait end,
    find=function(path)
        calls.find=calls.find+1
        if path==Rule.MAPS[E04].flag then calls.find_flag=calls.find_flag+1 end
        if path==DOME then calls.find_dome=calls.find_dome+1 end
        return objects[path]
    end,
    actors_of=function(path)
        if path==Rule.CREATOR then
            calls.actors_of_creator=calls.actors_of_creator+1
            return creator_list or {creator}
        end
        assert(path==SUN or path==SKY_LIGHT or path==VOLUME,path)
        calls.actors_of_lights=calls.actors_of_lights+1
        return (lists[eve.map] or {})[path] or {}
    end,
    load=function(path)
        assert(path==Rule.STARS)
        calls.load=calls.load+1
        objects[path]=material
    end,
    level=function(package) calls.level=calls.level+1; return streamed[package] end,
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
-- 3. Photo mode, Night Operation, the SBO lobby. SB's screens, talks and cutscenes are no input
--    (world/daynight/daynight.lua would raise on a call to o.cutscene or o.screen, which this o no longer has). A pass
--    with nothing new asks nothing.
local quiet=#asked; D.slow(false); assert(#asked==quiet)
world.photo='1'; D.slow(false); world.photo='0'; D.slow(false)
assert(asked[4]=='sky hold' and asked[5]=='sky cycle 8 0' and logged('daynight: hold %(photo mode%)'))
world.night=true; D.slow(false); assert(asked[6]=='sky hour 0 8 0'); world.night=false; D.slow(false)
world.lobby=true; D.slow(false); assert(asked[#asked]=='sky off'); world.lobby=false; D.slow(false)
-- Another player's photo mode or the host's cutscene pauses us with SB's pause tag: the hour holds.
world.frozen=true; D.slow(false)
assert(asked[#asked]=='sky hold' and logged("daynight: hold %(another player's pause%)"))
world.frozen=false; D.slow(false); assert(asked[#asked]=='sky cycle 8 0')
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
-- 10b. Review Focus 5: SB shows the dome behind Lua's back (a sequence may). The next 2 s look hides it again with
--      one line. Shown again at the next look (a sequence that keys it each frame): left to SB with one line, no
--      second flip, tried once more 15 looks (30 s) later. A look that finds it hidden starts over.
local function look() for _=1,8 do D.slow(false) end end
dome.hidden=false; look()
assert(dome.hidden==true and dome.vis_calls==2 and count_logged('SB showed Sky_Sphere, hidden again')==1)
dome.hidden=false; look()
assert(dome.hidden==false and dome.vis_calls==2 and count_logged('SB keeps Sky_Sphere shown; left to it')==1)
for _=3,14 do look() end
assert(dome.hidden==false and dome.vis_calls==2,'Left to SB for 30 s')
look()
assert(dome.hidden==true and dome.vis_calls==3 and count_logged('SB showed Sky_Sphere, hidden again')==1)
look()
dome.hidden=false; look()
assert(dome.hidden==true and dome.vis_calls==4 and count_logged('SB keeps Sky_Sphere shown; left to it')==1)
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
st.h=12.0117; D.slow(false); assert(#creator.times==3,'A 250 ms step of the hour turns the SkyCreator')
table.remove(creator.times)
settings.daynight=false; D.slow(false); D.slow(false)
assert(#creator.times==3 and creator.times[3]==12); settings.daynight=true
-- 15. Xion: at el -5 the day dome hides and the night dome shows (its actor, which SB ships hidden); at el -3 both go
--     back. The night dome's mesh is never touched.
eve=new_eve(0x600,E04); st.el=-5; D.slow(false)
assert(xion_day.hidden==true and night_actor.bHidden==false and xion_night.vis_calls==0)
st.el=-3; D.slow(false); assert(xion_day.hidden==false and night_actor.bHidden==true and xion_night.hidden==false)
-- Review Focus 5 for the night dome, read through its actor: SB shows it by day, the next look hides it again with
-- one line; a look that finds it hidden says nothing more.
night_actor.bHidden=false; for _=1,8 do D.slow(false) end
assert(night_actor.bHidden==true and count_logged('SB showed SM_SkySphere_NIGHT, hidden again')==1)
for _=1,8 do D.slow(false) end; assert(count_logged('SB keeps SM_SkySphere_NIGHT')==0)
-- 16. Off: Xion's domes back to SB's shipped state; with Xion's story night on, they are left as they are.
st.el=-5; D.slow(false); D.slow(true)
assert(xion_day.hidden==false and night_actor.bHidden==true and xion_night.hidden==false and xion_night.vis_calls==0)
D=Daynight.new(o); D.slow(false); st.el=-5; D.slow(false); flag.bActiveVolume=true; for _=1,8 do D.slow(false) end
assert(asked[#asked]=='sky off' and xion_day.hidden==true and night_actor.bHidden==false,
    'SB owns them during its story night')
-- SB hides its night dome at the end of its story night: our night shows it again.
night_actor.bHidden,xion_day.hidden=true,false
flag.bActiveVolume=false; for _=1,8 do D.slow(false) end
assert(asked[#asked]=='sky cycle 8 205' and night_actor.bHidden==false and xion_day.hidden==true)
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
-- 18. Hotel hall at noon then midnight: each class listed once per world, the Sun found by its name; rotation
--     {Pitch=-le,Yaw=ly} only when either moved 0.01 degree or more; SetIntensity(7.5*k), SetLightColor(tint), sky
--     light SetIntensity(1*amb) only when the value changes (at noon each is the value it had: no write).
D=Daynight.new(o); st.el,st.le,st.ly=65,65,308
eve=new_eve(0x7A0,HOTEL); D.slow(false); D.slow(false)
assert(asked[#asked]=='sky cycle 8 308' and calls.actors_of_lights==2)
assert(sun.rot.Pitch==-65 and sun.rot.Yaw==308 and sun.intensity==7.5 and fill.rot.Pitch==-20)
assert(calls.rotate==1 and calls.set_intensity==0 and calls.set_color==0)
assert(logged('lobby_hotel: 0 of 0 domes, 0 SkyCreators, Sun found, SkyLight found, lookups'))
local rots=calls.rotate; st.le=65.005; D.slow(false); assert(calls.rotate==rots,'Under 0.01 degree: no write')
st.le=65.021; D.slow(false); assert(calls.rotate==rots+1 and sun.rot.Pitch==-65.021,'A 250 ms step turns the Sun')
st.le=65; D.slow(false)
st.el,st.le,st.ly,st.k,st.amb,st.tint=-30,30,128,0.15,0.2,{0.7,0.8,1}; D.slow(false); D.slow(false)
assert(sun.rot.Pitch==-30 and sun.rot.Yaw==128 and math.abs(sun.intensity-1.125)<1e-9 and skylight.intensity==0.2)
assert(sun.color.R==0.7 and sun.color.G==0.8 and calls.set_intensity==2 and calls.set_color==1)
-- 19. Matrix XIII zone 0 at full night: bias 1.0 + 2 * ev = -1.0, written once; its only DirectionalLight is its Sun.
eve=new_eve(0x800,MX); st.ev=-1; D.slow(false); D.slow(false)
assert(ppv.Settings.AutoExposureBias==-1.0 and calls.bias_writes==1 and calls.actors_of_lights==5)
assert(mx_sun.rot.Pitch==-30 and math.abs(mx_sun.intensity-0.6)<1e-9)
assert(math.abs(mx_sun.color.G-0.8*((192/255+0.055)/1.055)^2.4)<1e-9)
-- 20. Off: intensity, colour, rotation and bias back to what the first find read.
D.slow(true)
assert(ppv.Settings.AutoExposureBias==1.0 and mx_sun.intensity==4 and mx_sun.rot.Pitch==-8 and mx_sun.rot.Yaw==85)
assert(math.abs(mx_sun.color.G-((192/255+0.055)/1.055)^2.4)<1e-9 and mx_sun.color.R==1)
-- 21. A Lua reload in the Hotel hall at full night (Ctrl+R). The new load takes the originals from coop-sky.txt, not
--     the light the earlier one dimmed: the night stays 0.15 times 7.5 (no compounding), the day gives 7.5 back and an
--     off the map's rotation and colour. A new EVE in the same world finds the load's own copy.
local function night() st.state,st.el,st.le,st.ly,st.k,st.amb,st.ev,st.tint='cycle',-30,30,128,0.15,0.2,-1,{0.7,0.8,1} end
local function day() st.state,st.el,st.le,st.ly,st.k,st.amb,st.ev,st.tint='cycle',65,65,308,1,1,0,{1,1,1} end
sun.rot,sun.intensity,sun.Intensity,sun.LightColor={Pitch=-58,Yaw=-52,Roll=0},7.5,7.5,{R=255,G=255,B=255,A=255}
skylight.intensity,skylight.Intensity=1,1
night(); D=Daynight.new(o); eve=new_eve(0x7C0,HOTEL); D.slow(false); D.slow(false)
assert(math.abs(sun.intensity-1.125)<1e-9 and math.abs(skylight.intensity-0.2)<1e-9)
assert(sky_file.line=='/game/sbo_lobby/lobby_hotel 1984\tSkyLight=1,1,1,1,0,0\tSun=7.5,1,1,1,-58,-52',sky_file.line)
local writes=sky_file.writes
D=Daynight.new(o); D.slow(false); D.slow(false)
assert(math.abs(sun.intensity-1.125)<1e-9 and math.abs(skylight.intensity-0.2)<1e-9,'No compounding')
assert(sky_file.writes==writes,'Nothing new to keep')
eve=new_eve(0x7D0,HOTEL,0x7C0); D.slow(false); assert(math.abs(sun.intensity-1.125)<1e-9,'A new EVE, the same world')
day(); D.slow(false); assert(sun.intensity==7.5 and skylight.intensity==1)
night(); D.slow(false); D.slow(true)
assert(sun.intensity==7.5 and skylight.intensity==1 and sun.rot.Pitch==-58 and sun.rot.Yaw==-52)
assert(sun.LightColor.R==255 and sun.LightColor.G==255 and sun.LightColor.B==255)
-- Matrix XIII at full night, then a reload: its bias stays 2 EV under 1.0 and comes back to 1.0 at an off.
ppv.Settings.AutoExposureBias=1.0
night(); D=Daynight.new(o); eve=new_eve(0x810,MX); D.slow(false); D.slow(false)
assert(ppv.Settings.AutoExposureBias==-1.0)
D=Daynight.new(o); D.slow(false); D.slow(false); assert(ppv.Settings.AutoExposureBias==-1.0,'Not -3')
D.slow(true); assert(ppv.Settings.AutoExposureBias==1.0)
-- Eidos 7 at night, then a reload: an off gives the SkyCreator SB's own time back, not the cycle's last.
creator.time=12
night(); st.h=0; D=Daynight.new(o); eve=new_eve(0x520,F02); D.slow(false); D.slow(false)
assert(creator.time==Rule.creator_time(0,5,21))
D=Daynight.new(o); D.slow(false); D.slow(true); assert(creator.time==12)
D=Daynight.new(o); D.slow(false); D.slow(false); settings.daynight=false
D=Daynight.new(o); D.slow(false); assert(creator.time==12,'A reload that starts off puts it back too')
settings.daynight=true
-- A game started again (the native part off at the first pass): coop-sky.txt is an older run's, so the light is read.
sun.intensity,sun.Intensity=6,6
st.state='off'; D=Daynight.new(o); eve=new_eve(0x7C0,HOTEL); D.slow(false)
night(); D.slow(false); D.slow(false); assert(math.abs(sun.intensity-0.9)<1e-9,'0.15 times the 6 read')
D.slow(true); sun.intensity,sun.Intensity=7.5,7.5
-- A damaged coop-sky.txt line for this world (a number short): the light is read instead.
sun.intensity,sun.Intensity=7.5,7.5
sky_file.line='/game/sbo_lobby/lobby_hotel 1984\tSkyLight=1,1,1,1,0,0\tSun=0.5,1,1,x,-58,-52'
st.state='cycle'; day(); D=Daynight.new(o); eve=new_eve(0x7C0,HOTEL); D.slow(false)
night(); D.slow(false); assert(math.abs(sun.intensity-1.125)<1e-9 and sky_file.line:find('Sun=7.5,',1,true))
D.slow(true)
-- coop-sky.txt that cannot be written: one line, the cycle goes on.
sky_file.fails='disk full'; D=Daynight.new(o); eve=new_eve(0x7E0,HOTEL); D.slow(false); D.slow(false)
assert(count_logged('coop%-sky%.txt not written %(disk full%)')==1 and math.abs(sun.intensity-1.125)<1e-9)
D.slow(true); sky_file.fails=nil
day()
-- 22. Spire 4: its sky sublevels stream. A dome waits for its sublevel with no lookup (a miss costs 25 to 35 ms);
--     every 2 s live, a sublevel that came gets its dome looked up and hidden and the SkyCreators listed again, one
--     that went drops its dome, one that went and came back between two looks is looked up again; an off shows the
--     domes found and gives each SkyCreator its own time.
local B07='/game/art/bg/worldmap/level_p/b07'
local function level(on) return uobj({visible=on,IsLevelVisible=function(self) return self.visible end}) end
local function package(path) return path:match('^[^.]+') end
local paths,b07=Rule.MAPS[B07].domes,{}
for i,path in ipairs(paths) do
    b07[i]=uobj({RootComponent=new_root(false)})
    streamed[package(path)]=level(i==1)
end
streamed[Rule.MAPS[B07].levels[1]]=level(false)
local function stream(i,on) -- Sublevel _0i comes (a new actor) or goes.
    local pkg=i<=4 and package(paths[i]) or Rule.MAPS[B07].levels[1]
    streamed[pkg].visible=on
    if i<=4 then
        if b07[i] then b07[i].gone,b07[i].RootComponent.gone=true,true end -- Its components die with it.
        b07[i]=on and uobj({RootComponent=new_root(false)}) or nil
        objects[paths[i]]=b07[i]
    end
end
local function new_creator(at,time)
    return uobj({at=at,SunriseTime=5,SunsetTime=21,times={},time=time,GetTime=function(self) return self.time end,
        SetTime=function(self,t) self.times[#self.times+1]=t; self.time=t end})
end
local c02,c05=new_creator(0xC2,10),new_creator(0xC5,11)
objects[paths[1]],creator_list=b07[1],{}
day(); st.h=12
D=Daynight.new(o); eve=new_eve(0xB00,B07); local finds,levels=calls.find,calls.level; D.slow(false)
assert(calls.find==finds+1 and calls.level==levels+5 and b07[1].RootComponent.hidden==true,calls.find-finds)
assert(logged('level_p/b07: 1 of 4 domes %(3 wait for their sublevel%), 0 SkyCreators'))
stream(2,true); creator_list={c02}; finds=calls.find
for _=1,7 do D.slow(false) end; assert(b07[2].RootComponent.hidden==false and calls.find==finds,'Not before 2 s')
D.slow(false)
assert(b07[2].RootComponent.hidden==true and calls.find==finds+1 and c02.time==Rule.creator_time(12,5,21))
assert(logged('a sublevel came or went: 2 of 4 domes %(2 wait for their sublevel%), 1 SkyCreators'))
stream(2,false); for _=1,8 do D.slow(false) end
assert(calls.find==finds+1 and logged('a sublevel came or went: 1 of 4 domes %(3 wait'))
stream(2,true); for _=1,8 do D.slow(false) end; assert(b07[2].RootComponent.hidden==true and calls.find==finds+2)
local old=b07[2]; stream(2,true); assert(old.gone and streamed[package(paths[2])].visible) -- Out and in between looks.
for _=1,8 do D.slow(false) end; assert(b07[2].RootComponent.hidden==true and calls.find==finds+3)
-- Review Focus 5 across a sublevel's return: one line per dome and world, not one per lookup.
local showed='SB showed '..paths[2]:match('[^.:]+$')..', hidden again'
local said=count_logged(showed)
b07[2].RootComponent.hidden=false; for _=1,8 do D.slow(false) end
assert(b07[2].RootComponent.hidden==true and count_logged(showed)==said+1)
stream(2,false); for _=1,8 do D.slow(false) end; stream(2,true); for _=1,8 do D.slow(false) end
b07[2].RootComponent.hidden=false; for _=1,8 do D.slow(false) end
assert(b07[2].RootComponent.hidden==true and count_logged(showed)==said+1,'Told once in this world')
stream(5,true); creator_list={c02,c05}; for _=1,8 do D.slow(false) end
assert(c05.time==Rule.creator_time(12,5,21) and #c02.times==1,'The SkyCreator already listed keeps its state')
settings.daynight=false; D.slow(false)
assert(b07[1].RootComponent.hidden==false and b07[2].RootComponent.hidden==false and c02.time==10 and c05.time==11)
settings.daynight=true
-- Off the live passes nothing is looked at; a sublevel that came meanwhile is looked up at the first live pass.
D.command('off'); D.slow(false); levels=calls.level; stream(3,true); for _=1,8 do D.slow(false) end
assert(calls.level==levels and b07[3].RootComponent.hidden==false)
D.command('on'); D.slow(false); assert(b07[3].RootComponent.hidden==true)
-- A streaming level whose read raises: logged, its dome looked up once.
streamed[package(Rule.MAPS[E04].day_dome)]=uobj({IsLevelVisible=function() error('gone',0) end})
D=Daynight.new(o); eve=new_eve(0x610,E04); st.el=20; D.slow(false)
assert(logged('the sublevel of .*SM_SkySphere2 is unreadable: gone; looked up once') and xion_day.hidden==false)
-- A streaming level kept from the world entry that is no longer valid: never read (an access violation inside
-- ProcessEvent is not caught by pcall), logged once, dropped.
local dead=uobj({visible=true,reads=0,IsLevelVisible=function(self) self.reads=self.reads+1; return self.visible end})
streamed[package(Rule.MAPS[E04].day_dome)]=dead
D=Daynight.new(o); eve=new_eve(0x611,E04); D.slow(false)
local reads=dead.reads
dead.gone=true; for _=1,16 do D.slow(false) end
assert(dead.reads==reads,'A level that is no longer valid is never read')
assert(count_logged('the sublevel of .*SM_SkySphere2 is unreadable: it is gone; looked up once')==1)
assert(xion_day.hidden==false)
streamed[package(Rule.MAPS[E04].day_dome)],creator_list=nil,nil
-- 23. The Terrace hall: nothing looked up, nothing written.
D=Daynight.new(o); local seen,writes=calls.actors_of_lights,calls.set_intensity+calls.rotate
eve=new_eve(0x900,'/game/sbo_lobby/lobby_terrace'); D.slow(false)
assert(calls.actors_of_lights==seen and calls.set_intensity+calls.rotate==writes and asked[#asked]=='sky off')
-- 24. The keep: while the star material is wanted and not in (stars_ready false), dusk makes no load and no lookup
--     of it; once it is in, the next pass loads the layer's material once.
do
    local loads=calls.load
    eve=new_eve(0x900,W); st.el=-10; world.stars_wait=true
    local D4=Daynight.new(o)
    for _=1,3 do D4.slow(false) end
    assert(calls.load==loads,'No star material before the keep has it')
    world.stars_wait=false
    D4.slow(false)
    assert(calls.load==loads+1)
end
-- 25. A star-layer map whose dome's sublevel goes and comes back between two looks, the new dome actor at the freed
--     one's address: its star layer is looked for again and, gone with the old actor, made again. UE4SS 4.0.0 compares
--     two objects by address (its UObject __eq), as these fakes do.
do
    local adds=calls.add_component
    local root=new_root(false)
    local actor=uobj({RootComponent=root,components={},AddComponentByClass=dome_actor.AddComponentByClass,
        K2_GetComponentsByClass=dome_actor.K2_GetComponentsByClass})
    objects[DOME],streamed[package(DOME)]=actor,level(true)
    eve,st.el=new_eve(0xA00,W),-10
    local D5=Daynight.new(o)
    D5.slow(false); D5.slow(false)
    local first=actor.components[1]
    assert(calls.add_component==adds+1 and first.visible==true)
    root.gone,first.gone=true,true -- Its components die with the old actor.
    actor.RootComponent,actor.components=new_root(false),{}
    for _=1,8 do D5.slow(false) end
    assert(calls.add_component==adds+2 and actor.components[1].visible==true,
        'The dome found again at the same address gets a star layer again')
    objects[DOME],streamed[package(DOME)]=dome_actor,nil
end
print('daynight_test ok')
