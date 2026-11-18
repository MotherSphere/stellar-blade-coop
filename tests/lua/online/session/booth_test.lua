-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Camp phone booths (online/session/booth.lua) with strict recording fakes, as recruiter_test: a fake booth raises on a
-- member it does not declare and on any write, FindAllOf raises on any class but the two booth classes (and gives nil
-- for none, as UE4SS does), reading or writing any other global raises, and os.clock is a fake clock that a scan
-- advances.
-- Covered: no scan without EVE, the list kept; the first scan, both classes once; no FindAllOf while EVE stays where
-- the last scan ran, however long; a rescan once she is 100 m from there and 30 s after it, and at once on a new map; a
-- due scan put off while EVE moves faster than 3 m/s, never on a new map; the scans of a map adding up (a booth that
-- streamed out still near, one found twice counted once, kept through a scan that raises) and cleared on a new map;
-- near (2.9 m in, 3 m in, 3.1 m out in 3D, another map, the nearest of two, the position copied at the scan); a booth
-- whose name read raises and an invalid one skipped; a scan that raises (one line, nothing near, the next try 30 s
-- later where it ran); the count line once per change and the slow-scan line, byte-exact; FindAllOf absent; each
-- class found by its path at every scan, never kept across a reload of the same map (one not in memory looked up again
-- at the next scan, or at once on a new map); each class found through the engine's soft class path once EVE's class
-- came back by it (core/unreal.lua's class_at), with no StaticFindObject of a booth class; the lookup route's line once
-- it is decided, on a slow scan or a fast one (a failed check with its reason); and the only game calls
-- made, all reads: nothing in the game is granted or changed. With no player controller (as in every case but the soft
-- path's) the class hash is never tried and each scan walks with FindAllOf (core/unreal.lua's actors_of), and the
-- classes are found with StaticFindObject.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
package.loaded.UEHelpers={GetPlayerController=function() return nil end}
local B=require('online.session.booth')
local CAMP,PHONE='Env_Camp_TeleportMachine_C','Env_Camp_TeleportMachine_Standalone_C'
local XION,WASTE='/game/art/bg/worldmap/level_p/e04','/game/art/bg/worldmap/level_p/e03'
assert(#B.CLASSES==2 and B.CLASSES[1]==CAMP and B.CLASSES[2]==PHONE)
assert(B.NEAR==3 and B.EVERY==30 and B.FAR==100 and B.SLOW==5 and B.PACE==300)
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
-- game reads (recorded). The location is at itself, as a struct the game may reuse: online/session/booth.lua must copy
-- it. Any other member or a write is recorded before it raises, so a pcall cannot hide it from the last check. how:
-- 'raise' (the name read raises) or 'invalid'.
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
local loaded,issued -- class -> false while its class object is not in memory; every class object given
local engine={} -- path -> the object given for it instead (the soft path case's player controller class and library)
-- A freed class object still passes IsValid (a new object at its address), but any read of it is recorded.
StaticFindObject=function(path)
    local class=path:match('%.([%w_]+)$')
    record('class '..class)
    if engine[path] then return engine[path] end
    if loaded[class]==false then return nil end
    local cls={}
    local function read() if cls.freed then record('freed class read') end end
    cls.type=function() read(); return 'UClass' end
    cls.IsValid=function() read(); return true end
    issued[#issued+1]=cls
    return cls
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
    world,broken,loaded,issued={[CAMP]=camps or {},[PHONE]=phones or {}},{},{},{}
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

-- 1000 ticks over 40 s with EVE where the scan ran, near asked on each: no FindAllOf and no booth read.
reset()
for i=1,1000 do b.tick(100+i*0.04,me); b.near(me) end
assert(#calls==0,table.concat(calls,','))
-- No EVE for a while: no scan, and the list is kept.
b.tick(200,nil)
assert(#calls==0 and b.near(me).id=='Xion_10_EnvS_016')

-- Once EVE has walked 100 m from where the last scan ran, one scan again (not at 99.9 m); no new line (same count,
-- same map).
b=fresh({booth('Xion_10_EnvS_016',P)})
b.tick(100,eve(P))
reset()
b.tick(140,eve(off(9990)))
assert(scans()==0,'99.9 m')
b.tick(180,eve(off(10000)))
assert(scans()==1 and count('FindAllOf '..PHONE)==1 and #lines==1 and count('class '..CAMP)==1,'Found at each scan')
-- 100 m on within 30 s of that scan (a dash, then a stop): the scan waits for the 30 s.
reset()
b.tick(181,eve(off(20000)))
b.tick(209.9,eve(off(20000)))
assert(scans()==0,'Not within 30 s')
b.tick(210,eve(off(20000)))
assert(scans()==1,'30 s after the last scan')
-- A new map scans at once; the next scan waits 30 s from there.
world={[CAMP]={booth('WLA_10_EnvS_007',P)},[PHONE]={booth('WLA_10_EnvS_191',off(5000))}}
reset()
b.tick(210.5,eve(P,WASTE))
assert(scans()==1 and #lines==2 and lines[2]=='booths: 2 on '..WASTE..' (1.0 ms)',lines[2])
assert(count('class '..CAMP)==1 and count('class '..PHONE)==1,'Found again on a new map')
b.tick(240.4,eve(off(10000),WASTE))
assert(scans()==1)
b.tick(240.5,eve(off(10000),WASTE))
assert(scans()==2)

-- A due scan waits while EVE moves faster than 3 m/s (4 m/s here, 1 m each 250 ms tick), and runs at her first slower
-- tick; at 2.8 m/s it runs once she is 100 m on. A new map scans at once, however fast she moves.
b=fresh({booth('Xion_10_EnvS_016',P)})
b.tick(100,eve(off(0)))
reset()
for i=1,160 do b.tick(100+i*0.25,eve(off(i*100))) end
assert(scans()==0,'Not while she runs')
b.tick(140.25,eve(off(16000)))
assert(scans()==1,'Once she stops')
reset()
for i=1,142 do b.tick(140.25+i*0.25,eve(off(16000+i*70))) end
assert(scans()==0,'99.4 m on')
b.tick(176,eve(off(16000+143*70)))
assert(scans()==1,'At 2.8 m/s, 100.1 m on')
reset()
b.tick(176.25,eve(off(28000),WASTE))
assert(scans()==1,'A new map at once')

-- The scans of a map add up: a booth that streamed out after one scan is still near at its spot, one found by two
-- scans counts once, and a scan that raises keeps them. A new map clears them, and so does the way back.
b=fresh({booth('Xion_10_EnvS_016',P)})
b.tick(100,eve(P))
world[CAMP]={booth('Xion_10_EnvS_016',P),booth('Far',off(20000))}
b.tick(140,eve(off(10000)))
assert(#lines==2 and lines[2]=='booths: 2 on '..XION..' (1.0 ms)',lines[2])
world[CAMP]={booth('Far',off(20000))}
b.tick(180,eve(off(20000)))
assert(scans()==3 and #lines==2,'Far found twice, counted once')
near=b.near(eve(P))
assert(near.id=='Xion_10_EnvS_016' and near.class==CAMP and near.d==0,'Found by an earlier scan')
assert(b.near(eve(off(20000))).id=='Far')
broken[PHONE]=1
b.tick(220,eve(off(30000)))
assert(#lines==3 and lines[3]=='booths: scan failed on '..XION..': FindAllOf broke (1.0 ms)',lines[3])
assert(b.near(eve(P)).id=='Xion_10_EnvS_016' and b.near(eve(off(20000))).id=='Far','Kept through a failed scan')
world[CAMP]={}
b.tick(220.5,eve(off(30000),WASTE))
assert(lines[4]=='booths: 0 on '..WASTE..' (1.0 ms)' and b.near(eve(P,WASTE))==nil,lines[4])
world[CAMP]={booth('Far',off(20000))}
b.tick(221,eve(off(20000)))
assert(lines[5]=='booths: 1 on '..XION..' (1.0 ms)' and b.near(eve(P))==nil and b.near(eve(off(20000))).id=='Far',
    'Cleared on the map change: '..lines[5])

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
-- near, and one line says why however often it fails; the next try waits 30 s (a failed scan's spot does not count as
-- scanned), and the count line comes back with it. After a good scan, the next one waits for her 100 m again.
b=fresh({booth('Xion_10_EnvS_016',P)})
broken[PHONE]=2
assert(pcall(b.tick,100,me) and b.near(me)==nil)
assert(#lines==1 and lines[1]=='booths: scan failed on '..XION..': FindAllOf broke (1.0 ms)',lines[1])
b.tick(129.9,me)
assert(scans()==1)
b.tick(130,me)
assert(scans()==2 and #lines==1 and b.near(me)==nil,table.concat(lines,'|'))
b.tick(160,me)
assert(scans()==3 and #lines==2 and lines[2]=='booths: 1 on '..XION..' (1.0 ms)' and b.near(me).id=='Xion_10_EnvS_016',
    table.concat(lines,'|'))
b.tick(200,me)
assert(scans()==3)

-- The count line: once per change of the count or the map, byte-exact.
b=fresh({booth('A',P),booth('B',off(1000))})
local function at(now,x,map) clock=0; b.tick(now,eve(off(x),map)) end
at(100,0,XION); at(140,10000,XION)
world[CAMP][3]=booth('C',off(2000))
at(180,20000,XION); at(220,30000,XION); at(220.5,30000,WASTE); at(260.5,40000,WASTE)
assert(scans()==6)
local want={'booths: 2 on '..XION..' (1.0 ms)','booths: 3 on '..XION..' (1.0 ms)','booths: 3 on '..WASTE..' (1.0 ms)'}
assert(#lines==#want,table.concat(lines,'|'))
for i,line in ipairs(want) do assert(lines[i]==line,lines[i]) end

-- The slow-scan line: at 5.0 ms, not at 4.9 ms.
b=fresh({booth('A',P)},{booth('B',off(1000))})
cost=0.005
b.tick(100,me)
assert(#lines==2 and lines[1]=='booths: 2 on '..XION..' (5.0 ms)'
    and lines[2]=='booths: slow scan 5.0 ms (2 found, walk, walk)',table.concat(lines,'|'))
b=fresh({booth('A',P)},{booth('B',off(1000))})
cost=0.0049
b.tick(100,me)
assert(#lines==1 and lines[1]=='booths: 2 on '..XION..' (4.9 ms)',table.concat(lines,'|'))

-- A class not in memory: none of its booths, no list of it, looked up again at the next scan (30 s later at least).
b=fresh({booth('A',P)},{booth('B',off(1000))})
loaded[PHONE]=false
b.tick(100,eve(P))
assert(count('FindAllOf '..PHONE)==0 and lines[1]=='booths: 1 on '..XION..' (1.0 ms)',lines[1])
loaded[PHONE]=nil
reset()
b.tick(140,eve(off(10000)))
assert(count('class '..PHONE)==1 and count('FindAllOf '..PHONE)==1 and lines[2]=='booths: 2 on '..XION..' (1.0 ms)',
    tostring(lines[2]))
-- A class not in memory on one map is looked up at once on the next.
b=fresh({booth('A',P)},{booth('B',off(1000))})
loaded[PHONE]=false
b.tick(100,me)
reset()
b.tick(104.5,eve(P,WASTE))
assert(count('class '..PHONE)==1,'Looked up at once on a new map')

-- The title, then a save on the same map 100 m away: the old world's class objects are freed and none is read again;
-- the scan finds both classes by path.
b=fresh({booth('Xion_10_EnvS_016',P)})
b.tick(100,me)
for _,cls in ipairs(issued) do cls.freed=true end
b.tick(101,nil)
reset()
b.tick(140,eve(off(10200)))
assert(count('freed class read')==0 and count('class '..CAMP)==1 and count('class '..PHONE)==1
    and b.near(me).id=='Xion_10_EnvS_016',table.concat(calls,','))

-- The engine's soft class path, from a fresh Lua load with a player controller: EVE's class checked once at the first
-- scan (it comes back by its own path), then three library calls a class at each scan and no StaticFindObject of a
-- booth class at any scan; a class the engine does not hold gives no actor list of it, and is found at the next scan
-- once it is in memory; the slow-scan line says 'soft path'. No player controller is walked, so the actors are walked.
package.loaded['core.unreal'],package.loaded['online.session.booth']=nil,nil
B=require('online.session.booth')
local function thing(fields)
    fields.type=function() return 'UObject' end
    fields.IsValid=function() return true end
    return fields
end
local EVE_CLASS='/Game/Test/EVE.EVE_C'
local held={[EVE_CLASS]=thing{GetAddress=function() return 0x100 end,
    GetFullName=function() record('soft:GetFullName'); return 'BlueprintGeneratedClass '..EVE_CLASS end},
    [B.PATHS[CAMP]]=thing{GetAddress=function() return 0x200 end}}
local pc_class=thing{}
local pawn=thing{GetClass=function() record('soft:GetClass'); return held[EVE_CLASS] end}
local pc=thing{IsA=function(_,c) return c==pc_class end,
    K2_GetPawn=function() record('soft:K2_GetPawn'); return pawn end}
engine={['/Script/Engine.PlayerController']=pc_class,['/Script/Engine.Default__KismetSystemLibrary']=thing{
    MakeSoftClassPath=function(_,path) record('soft:MakeSoftClassPath'); return {path=path} end,
    Conv_SoftClassPathToSoftClassRef=function(_,path)
        record('soft:Conv_SoftClassPathToSoftClassRef')
        return {ref=path.path}
    end,
    Conv_SoftClassReferenceToClass=function(_,r) record('soft:Conv_SoftClassReferenceToClass'); return held[r.ref] end}}
package.loaded.UEHelpers.GetPlayerController=function() return pc end
b=fresh({booth('Xion_10_EnvS_016',P)},{booth('Xion_Phone',off(1000))})
world.PlayerController={}
cost=0.005
b.tick(100,me)
assert(count('class '..CAMP)==0 and count('class '..PHONE)==0 and count('soft:K2_GetPawn')==1
    and count('soft:MakeSoftClassPath')==3 and count('soft:Conv_SoftClassReferenceToClass')==3
    and count('FindAllOf '..CAMP)==1 and count('FindAllOf '..PHONE)==0,table.concat(calls,','))
assert(#lines==3 and lines[1]=='booths: 1 on '..XION..' (5.0 ms)'
    and lines[2]=='booths: slow scan 5.0 ms (1 found, walk, soft path)'
    and lines[3]=='booths: class lookup route: soft path',table.concat(lines,'|'))
assert(b.near(me).id=='Xion_10_EnvS_016')
held[B.PATHS[PHONE]]=thing{}
reset()
b.tick(140,eve(off(10200)))
assert(count('soft:K2_GetPawn')==0 and count('soft:MakeSoftClassPath')==2 and count('soft:GetFullName')==0
    and count('class '..CAMP)==0 and count('class '..PHONE)==0 and count('FindAllOf '..PHONE)==1
    and lines[4]=='booths: 2 on '..XION..' (5.0 ms)' and lines[5]=='booths: slow scan 5.0 ms (2 found, walk, soft path)'
    and #lines==5,table.concat(lines,'|'))
-- A soft path check that fails, in a fresh Lua load, on scans under SLOW: the walk, and its reason in a line of its
-- own once, though no slow-scan line comes.
package.loaded['core.unreal'],package.loaded['online.session.booth']=nil,nil
B=require('online.session.booth')
local convert=engine['/Script/Engine.Default__KismetSystemLibrary'].Conv_SoftClassReferenceToClass
engine['/Script/Engine.Default__KismetSystemLibrary'].Conv_SoftClassReferenceToClass=function()
    error('no such function',0)
end
b=fresh({booth('Xion_10_EnvS_016',P)})
world.PlayerController={}
b.tick(100,me)
b.tick(140,eve(off(10200)))
assert(#lines==2 and lines[1]=='booths: 1 on '..XION..' (1.0 ms)'
    and lines[2]=='booths: class lookup route: walk (no such function)' and count('class '..CAMP)==2,
    table.concat(lines,'|'))
engine['/Script/Engine.Default__KismetSystemLibrary'].Conv_SoftClassReferenceToClass=convert
package.loaded.UEHelpers.GetPlayerController=function() return nil end
engine={}
package.loaded['core.unreal'],package.loaded['online.session.booth']=nil,nil
B=require('online.session.booth')

-- No FindAllOf in this UE4SS: an empty list, no error.
b=fresh({booth('A',P)})
FindAllOf=nil
b.tick(100,me)
assert(#calls==2 and #lines==1 and lines[1]=='booths: 0 on '..XION..' (0.0 ms)' and b.near(me)==nil,lines[1])

-- Over the whole run, the only game calls were FindAllOf on the two classes, the location read and the name read, the
-- class lookups, and in the soft path case the player controller's class, the library, EVE's pawn and class, the
-- library's three soft path calls and the walk for player controllers (and each kind happened): nothing is granted or
-- changed.
local seen={}
for _,c in ipairs(every) do
    local kind=c=='FindAllOf '..CAMP and 'camp' or c=='FindAllOf '..PHONE and 'phone'
        or (c=='class '..CAMP or c=='class '..PHONE) and 'class'
        or c:match(':K2_GetActorLocation$') and 'location' or c:match(':EnvActorName$') and 'name'
        or (c=='class PlayerController' or c=='class Default__KismetSystemLibrary'
            or c=='FindAllOf PlayerController' or c:match('^soft:')) and 'soft'
    assert(kind,'game call '..c)
    seen[kind]=true
end
assert(seen.camp and seen.phone and seen.location and seen.name and seen.class and seen.soft)
print('booth_test ok')
