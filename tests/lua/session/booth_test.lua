-- Camp phone booths (session/booth.lua) with strict recording fakes, as recruiter_test: a fake booth raises on a member
-- it does not declare and on any write, FindAllOf raises on any class but the two booth classes (and gives nil for
-- none, as UE4SS does), reading or writing any other global raises, and os.clock is a fake clock that a scan advances.
-- Covered: no scan without EVE, the list kept; the first scan, both classes once; no FindAllOf between scans; a rescan
-- after 4 s and at once on a new map; a due scan put off while EVE moves faster than 3 m/s, never on a new map; near (2.9 m in, 3 m in, 3.1 m out in 3D, another map, the nearest of two, the
-- position copied at the scan); a booth whose name read raises and an invalid one skipped; a scan that raises (one
-- line, nothing near, the next try 4 s later); the count line once per change and the slow-scan line, byte-exact;
-- FindAllOf absent; each class found by its path once a map (again 30 s after it was not in memory); and the only game
-- calls made, all reads: nothing in the game is granted or changed. With no player controller (as here) the class hash
-- is never tried and each scan walks with FindAllOf (core/unreal.lua's actors_of).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
package.loaded.UEHelpers={GetPlayerController=function() return nil end}
local B=require('session.booth')
local CAMP,PHONE='Env_Camp_TeleportMachine_C','Env_Camp_TeleportMachine_Standalone_C'
local XION,WASTE='/game/art/bg/worldmap/level_p/e04','/game/art/bg/worldmap/level_p/e03'
assert(#B.CLASSES==2 and B.CLASSES[1]==CAMP and B.CLASSES[2]==PHONE)
assert(B.NEAR==3 and B.EVERY==4 and B.SLOW==5 and B.PACE==300 and B.RETRY==30)
assert(B.PATHS[CAMP]=='/Game/GameDesign/Level/ZoneEnv/Env_Camp_TeleportMachine.Env_Camp_TeleportMachine_C')

local clock,cost=0,0.001 -- os.clock in seconds; what one scan costs (the first class's FindAllOf adds it).
os.clock=function() return clock end
local calls,every={},{} -- Every game call since the last reset, and all of them; in order.
local function record(what) calls[#calls+1]=what; every[#every+1]=what end
local function reset() calls={} end
local function count(what)
    local n=0
    for _,c in ipairs(calls) do if c==what then n=n+1 end end
    return n
end
local function fname(text)
    return setmetatable({},{__index=function(_,key)
        if key=='type' then return function() return 'FName' end end
        if key=='ToString' then return function() return text end end
        record('FName:'..tostring(key))
        error('FName has no '..tostring(key),2)
    end,__newindex=function(_,key)
        record('FName:write '..tostring(key))
        error('booth wrote '..tostring(key)..' on an FName',2)
    end})
end
-- A placed booth: type and IsValid are UE4SS's own checks on the wrapper (quiet); its location and its name are the
-- game reads (recorded). The location is at itself, as a struct the game may reuse: session/booth.lua must copy it. Any
-- other member or a write is recorded before it raises, so a pcall cannot hide it from the last check. how: 'raise'
-- (the name read raises) or 'invalid'.
local function booth(id,at,how)
    local methods={type=function() return 'UObject' end,IsValid=function() return how~='invalid' end,
        K2_GetActorLocation=function() record(id..':K2_GetActorLocation'); return at end}
    return setmetatable({},{__index=function(_,key)
        if methods[key] then return methods[key] end
        if key=='EnvActorName' then
            record(id..':EnvActorName')
            if how=='raise' then error('unreadable name') end
            return fname(id)
        end
        record(id..':'..tostring(key))
        error(id..' has no '..tostring(key),2)
    end,__newindex=function(_,key)
        record(id..':write '..tostring(key))
        error('booth wrote '..tostring(key)..' on '..id,2)
    end})
end
local world,broken -- class -> the booths FindAllOf finds; class -> how many more FindAllOf of it raise
FindAllOf=function(class)
    record('FindAllOf '..tostring(class))
    local list=world[class]
    if list==nil then error('FindAllOf of '..tostring(class),2) end
    if (broken[class] or 0)>0 then broken[class]=broken[class]-1; error('FindAllOf broke',0) end
    if class==CAMP then clock=clock+cost end
    return #list>0 and list or nil
end
local loaded -- class -> false while its class object is not in memory
StaticFindObject=function(path)
    local class=path:match('%.([%w_]+)$')
    record('class '..class)
    if loaded[class]==false then return nil end
    return {type=function() return 'UClass' end,IsValid=function() return true end}
end
setmetatable(_G,{__index=function(_,key)
    if key=='FindAllOf' then return nil end
    record('global '..tostring(key)) -- Seen by the last check even when a pcall hides the error.
    error('read of the global '..tostring(key),2)
end,__newindex=function(t,key,v)
    if key~='FindAllOf' then record('global write '..tostring(key)); error('write of the global '..tostring(key),2) end
    rawset(t,key,v)
end})

local P={X=-13470.1,Y=18237.5,Z=-18.1} -- Xion_10_EnvS_016, a full camp's booth in Xion.
local function off(dx,dy,dz) return {X=P.X+dx,Y=P.Y+(dy or 0),Z=P.Z+(dz or 0)} end
local function eve(at,map) return {at=at,map=map or XION} end
local lines
local function fresh(camps,phones)
    world,broken,loaded={[CAMP]=camps or {},[PHONE]=phones or {}},{},{}
    lines,clock,cost={},0,0.001
    reset()
    return B.new(function(m) lines[#lines+1]=m end)
end
local function scans() return count('FindAllOf '..CAMP) end

-- No EVE (a load, the title screen): no scan, no line.
local b=fresh({booth('Xion_10_EnvS_016',P)})
b.tick(100,nil)
assert(#calls==0 and #lines==0 and b.near(nil)==nil)

-- The first tick scans both classes once, in order, and reads each booth once.
local me=eve(off(120,160,210)) -- 2.9 m in 3D (2.0 m on the ground).
b.tick(100,me)
assert(#calls==6 and calls[1]=='class '..CAMP and calls[2]=='FindAllOf '..CAMP and calls[5]=='class '..PHONE
    and calls[6]=='FindAllOf '..PHONE,table.concat(calls,','))
assert(count('Xion_10_EnvS_016:K2_GetActorLocation')==1 and count('Xion_10_EnvS_016:EnvActorName')==1)
assert(#lines==1 and lines[1]=='booths: 1 on '..XION..' (1.0 ms)',lines[1])
local near=b.near(me)
assert(near.id=='Xion_10_EnvS_016' and near.class==CAMP and math.abs(near.d-2.9)<1e-9,near and near.d)
local keys=0
for _ in pairs(near) do keys=keys+1 end
assert(keys==3,'id, class and d only')

-- 1000 ticks before the 4 s are up, near asked on each: no FindAllOf and no booth read.
reset()
for i=1,1000 do b.tick(100+i*0.0039,me); b.near(me) end
assert(#calls==0,table.concat(calls,','))
-- No EVE for a while: no scan, and the list is kept.
b.tick(200,nil)
assert(#calls==0 and b.near(me).id=='Xion_10_EnvS_016')

-- At 4 s, one scan again; no new line (same count, same map).
b=fresh({booth('Xion_10_EnvS_016',P)})
b.tick(100,me)
reset()
b.tick(103.999,me)
assert(scans()==0)
b.tick(104,me)
assert(scans()==1 and count('FindAllOf '..PHONE)==1 and #lines==1 and count('class '..CAMP)==0,'Kept on its map')
-- A new map scans at once; the next scan waits 4 s from there.
world={[CAMP]={booth('WLA_10_EnvS_007',P)},[PHONE]={booth('WLA_10_EnvS_191',off(5000))}}
reset()
b.tick(104.5,eve(P,WASTE))
assert(scans()==1 and #lines==2 and lines[2]=='booths: 2 on '..WASTE..' (1.0 ms)',lines[2])
assert(count('class '..CAMP)==1 and count('class '..PHONE)==1,'Found again on a new map')
b.tick(108.4,eve(P,WASTE))
assert(scans()==1)
b.tick(108.5,eve(P,WASTE))
assert(scans()==2)

-- A due scan waits while EVE moves faster than 3 m/s (4 m/s here, 1 m each 250 ms tick), and runs at her first slower
-- tick; at 2.8 m/s it runs when due. A new map scans at once, however fast she moves.
b=fresh({booth('Xion_10_EnvS_016',P)})
b.tick(100,eve(off(0)))
reset()
for i=1,40 do b.tick(100+i*0.25,eve(off(i*100))) end
assert(scans()==0,'Not while she runs')
b.tick(110.25,eve(off(4000)))
assert(scans()==1,'Once she stops')
reset()
for i=1,17 do b.tick(110.25+i*0.25,eve(off(4000+i*70))) end
assert(scans()==1,'At 2.8 m/s, when due')
reset()
b.tick(114.75,eve(off(5375),WASTE))
assert(scans()==1,'A new map at once')

-- near: 3.1 m in 3D is out although the ground distance is 2.0 m; 3 m is in; another map; the nearest of two, either
-- way round; the positions were copied at the scan (the game reusing its struct moves nothing).
local spot=off(-100)
b=fresh({booth('Xion_10_EnvS_016',P)},{booth('Xion_Phone',spot)})
b.tick(100,me)
spot.X,spot.Y,spot.Z=0,0,0
assert(b.near(eve(off(300))).d==3) -- Exactly 3 m from the camp's booth, 4 m from the phone.
assert(b.near(eve(off(120,160,math.sqrt(310^2-200^2))))==nil) -- 3.6 m from the phone.
assert(b.near(eve(P,WASTE))==nil,'another map')
near=b.near(eve(off(-60)))
assert(near.id=='Xion_Phone' and near.class==PHONE and math.abs(near.d-0.4)<1e-9)
near=b.near(eve(off(-40)))
assert(near.id=='Xion_10_EnvS_016' and near.class==CAMP and math.abs(near.d-0.4)<1e-9)
assert(b.near(nil)==nil)

-- A booth whose name read raises is skipped, and so is an invalid one (never read); the others are kept.
b=fresh({booth('Raises',off(1000),'raise'),booth('Xion_10_EnvS_016',P),booth('Invalid',off(2000),'invalid')})
b.tick(100,me)
assert(#lines==1 and lines[1]=='booths: 1 on '..XION..' (1.0 ms)',lines[1])
assert(b.near(eve(off(1000)))==nil and b.near(eve(off(2000)))==nil and b.near(me).id=='Xion_10_EnvS_016')
assert(count('Invalid:K2_GetActorLocation')==0 and count('Invalid:EnvActorName')==0)

-- A scan that raises (here FindAllOf of the phones, after the camp's booth was read): tick does not raise, nothing is
-- near, and one line says why however often it fails; the next try waits 4 s, and the count line comes back with it.
b=fresh({booth('Xion_10_EnvS_016',P)})
broken[PHONE]=2
assert(pcall(b.tick,100,me) and b.near(me)==nil)
assert(#lines==1 and lines[1]=='booths: scan failed on '..XION..': FindAllOf broke (1.0 ms)',lines[1])
b.tick(103.9,me)
assert(scans()==1)
b.tick(104,me)
assert(scans()==2 and #lines==1 and b.near(me)==nil,table.concat(lines,'|'))
b.tick(108,me)
assert(scans()==3 and #lines==2 and lines[2]=='booths: 1 on '..XION..' (1.0 ms)' and b.near(me).id=='Xion_10_EnvS_016',
    table.concat(lines,'|'))

-- The count line: once per change of the count or the map, byte-exact.
b=fresh({booth('A',P),booth('B',off(1000))})
local function at(now,map) clock=0; b.tick(now,eve(P,map)) end
at(100,XION); at(104,XION)
world[CAMP][3]=booth('C',off(2000))
at(108,XION); at(112,XION); at(112.5,WASTE); at(116.5,WASTE)
local want={'booths: 2 on '..XION..' (1.0 ms)','booths: 3 on '..XION..' (1.0 ms)','booths: 3 on '..WASTE..' (1.0 ms)'}
assert(#lines==#want,table.concat(lines,'|'))
for i,line in ipairs(want) do assert(lines[i]==line,lines[i]) end

-- The slow-scan line: at 5.0 ms, not at 4.9 ms.
b=fresh({booth('A',P)},{booth('B',off(1000))})
cost=0.005
b.tick(100,me)
assert(#lines==2 and lines[1]=='booths: 2 on '..XION..' (5.0 ms)'
    and lines[2]=='booths: slow scan 5.0 ms (2 found, walk)',table.concat(lines,'|'))
b=fresh({booth('A',P)},{booth('B',off(1000))})
cost=0.0049
b.tick(100,me)
assert(#lines==1 and lines[1]=='booths: 2 on '..XION..' (4.9 ms)',table.concat(lines,'|'))

-- A class not in memory: none of its booths, no list of it, looked up again 30 s later only (the scans between ask
-- nothing of it).
b=fresh({booth('A',P)},{booth('B',off(1000))})
loaded[PHONE]=false
b.tick(100,me)
assert(count('FindAllOf '..PHONE)==0 and lines[1]=='booths: 1 on '..XION..' (1.0 ms)',lines[1])
reset()
for t=104,128,4 do b.tick(t,me) end
assert(count("class "..PHONE)==0 and count("FindAllOf "..PHONE)==0 and scans()==7,table.concat(calls,","))
loaded[PHONE]=nil
b.tick(132,me)
assert(count('class '..PHONE)==1 and count('FindAllOf '..PHONE)==1 and lines[2]=='booths: 2 on '..XION..' (1.0 ms)',
    tostring(lines[2]))

-- No FindAllOf in this UE4SS: an empty list, no error.
b=fresh({booth('A',P)})
FindAllOf=nil
b.tick(100,me)
assert(#calls==2 and #lines==1 and lines[1]=='booths: 0 on '..XION..' (0.0 ms)' and b.near(me)==nil,lines[1])

-- Over the whole run, the only game calls were FindAllOf on the two classes, the location read and the name read (and
-- each kind happened): nothing is granted or changed.
local seen={}
for _,c in ipairs(every) do
    local kind=c=='FindAllOf '..CAMP and 'camp' or c=='FindAllOf '..PHONE and 'phone'
        or (c=='class '..CAMP or c=='class '..PHONE) and 'class'
        or c:match(':K2_GetActorLocation$') and 'location' or c:match(':EnvActorName$') and 'name'
    assert(kind,'game call '..c)
    seen[kind]=true
end
assert(seen.camp and seen.phone and seen.location and seen.name and seen.class)
print('booth_test ok')
