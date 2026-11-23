-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's commands, arrival, day table and watch (world/maps/sboxion/sboxion.lua) over a fake world: 72 env volumes
-- (65 in E04_ENV_VOL with the 41 of the day table, 21 of them stored other than the table), 95 streaming levels with
-- the two probe levels, EVE's map and place, the status text and the clock. Covered: coop xion's refusals (not a
-- co-op save, in a session, no pak, rows refused, a fault, already inside) and its request for each point, coop xion
-- leave's request from any map and the native answer relayed once; at an arrival the 41 writes matched by level and
-- name, a volume of the same name in another level left alone, the counts 72, 65 and 41, the read-back, the levels
-- line and the characters; nothing read in another map; a second arrival writes again; a probe level's change logged
-- once; a waypoint logged once a visit; the watch ended by a map change and by coop off. The recovery
-- (world/maps/sboxion/recover.lua): ticked only in SBO Xion, reset at each arrival with the point coop xion asked, fed
-- by the engine's read of EVE and not by me(), ended by a map change and by coop off.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=100
os.clock=function() return clock end
local next_address=0x70000
local function object(t)
    next_address=next_address+0x100
    local at=next_address
    t.type=t.type or function() return 'UObject' end
    t.IsValid=t.IsValid or function() return true end
    t.GetAddress=t.GetAddress or function() return at end
    return t
end
package.loaded.UEHelpers={}
-- EVE for core/enemy.lua's rows flow: a map to keep while the rows are asked.
local eve=object({GetWorld=function()
    return {GetFullName=function() return 'World /Game/Art/BG/WorldMap/Level_P/E04.E04' end}
end})
package.loaded['core.player']={her=function() return eve end}
local Xion=require('world.maps.sboxion.sboxion')
local D=require('world.maps.sboxion.data')

-- The two tables with the rows in, as the native part writes them.
local tables={}
for _,t in ipairs({'WorldTable','ZoneTable'}) do
    local rows={}
    for _,r in ipairs(Xion.ROWS) do
        if r.table==t then
            rows[r.name]={ID=r.id}
            for _,c in ipairs(r.checks) do rows[r.name][c[1]]=c[3] end
        end
    end
    tables[t]=object({rows=rows,IsA=function(_,c) return c.path=='/Script/Engine.DataTable' end,
        FindRow=function(self,name) return self.rows[name] end})
end
local classes={}
StaticFindObject=function(path)
    local t=path:match('^/Game/Local/Data/(%a+)%.%a+$')
    if t then return tables[t] end
    if path:find('^/Script/') then
        classes[path]=classes[path] or object({path=path})
        return classes[path]
    end
end
-- The pak's three files (title_test.lua's).
local function utoc(names)
    local t='-==--==--==--==-'..string.pack('<BBI2I4I4I4I4I4I4I4I4',2,0,0,144,2,1,12,0,32,65536,0)
    t=t..('\0'):rep(144-#t)..('\0'):rep(2*22)..string.pack('<I5I3I3B',0,4096,4096,0)
    return t..'../../../\0SB\0Content\0'..table.concat(names,'\0')..'\0'
end
local PAKS='C:\\G\\SB\\Content\\Paks'
local files={}
local function read(path,limit,offset) return files[path] and files[path]:sub((offset or 0)+1,(offset or 0)+limit) end
local function pak(on)
    files[PAKS..'\\~mods\\zSBO_Xion.utoc']=on and utoc({'SBO_World','Xion_P.umap'}) or nil
    files[PAKS..'\\~mods\\zSBO_Xion.pak'],files[PAKS..'\\~mods\\zSBO_Xion.ucas']='',('\0'):rep(64)
end

-- The fake world. calls counts every engine read, by name.
local BG='/Game/Art/BG/WorldMap/SubLevel/E04/'
local calls,volumes,levels,names,zone_index={},{},{},{},4660
local sets={} -- Each write: the volume's path.
local function volume(path,on)
    local v={path=path,on=on}
    v.get=function() return v.on end
    v.set=function(to) sets[#sets+1]=path; if not v.stuck then v.on=to end end
    volumes[#volumes+1]=v
    return v
end
local by={} -- The volumes of E04_ENV_VOL by name.
local function fresh()
    volumes,sets,by={},{},{}
    local ENV=BG..D.ENV_LEVEL
    for i,name in ipairs(D.DAY.on) do by[name]=volume(ENV..name,i>10) end -- 10 of the 15 stored off.
    for i,name in ipairs(D.DAY.off) do by[name]=volume(ENV..name,i<=11) end -- 11 of the 26 stored on.
    for i=1,24 do volume(ENV..'E04_Other_ENV_'..i,i%2==0) end -- 65 in E04_ENV_VOL.
    volume('/Game/SBO_World/Xion_P.Xion_P:PersistentLevel.SBEnvControlVolume_1',true)
    volume('/Game/SBO_World/Xion_P.Xion_P:PersistentLevel.SBEnvControlVolume5_3',true)
    volume('/Game/SBO_World/Xion_P.Xion_P:PersistentLevel.BP_TrainingRoomSBEnvControlVolume',true)
    -- The same names as two of the day table's, in other levels: never written.
    by.other=volume(BG..'E04_Area01_Sequence_A_01.E04_Area01_Sequence_A_01:PersistentLevel.E04_Area_01_Global_ENV_01',
        false)
    by.near=volume(BG..'XE04_ENV_VOL.E04_ENV_VOL:PersistentLevel.E04_Area_02_Sub_ENV_04_NIGHT',true)
    volume(BG..'E04_Area01_Sequence_A_01.E04_Area01_Sequence_A_01:PersistentLevel.SBEnvControlVolume4_5',true)
    by.tied=volume(BG..'E04_Area02_Light_A_01.E04_Area02_Light_A_01:PersistentLevel.'..D.TIED,true)
    levels={}
    for i=1,93 do levels[i]={name='E04_Level_'..i,loaded=true,visible=true} end
    for _,name in ipairs(D.PROBES) do levels[#levels+1]={name=name,loaded=true,visible=true} end
    names={'CH_P_EVE_01_Blueprint_C_0'}
end
local function count(what) calls[what]=(calls[what] or 0)+1 end
local world={
    zone_index=function(alias) count('zone_index'); assert(alias==D.ZONE); return zone_index end,
    volumes=function() count('volumes'); return volumes end,
    levels=function() count('levels'); return levels end,
    probes=function(list)
        count('probes')
        local out={}
        for _,name in ipairs(list) do
            for _,l in ipairs(levels) do
                if l.name==name then out[#out+1]={name=name,loaded=l.loaded,visible=l.visible} end
            end
        end
        return out
    end,
    characters=function() count('characters'); return names end,
}
local function total() local n=0; for _,c in pairs(calls) do n=n+c end; return n end

local logs,asked={},{}
local rows_line,warp_line='sboxion=rows added=2/2 asks=1 spawns=? char=0/0 skills=0/0 stance=0/0','sboxionwarp=off'
local ENGINE='engine=on remote=0 0 none warp=idle me=2610 zonetype=5 area=Zone_SBO_Xion rest=0::0 starts=0 theater=none'
local slot_ok,mode,me=true,'none',nil
-- EVE as the engine reads her in the same pass: at her_at (me.at unless set), in mode her_mode. puts: each put-back.
local her_at,her_mode,puts=nil,1,{}
world.move=function()
    count('move')
    local p=her_at or me.at
    return {at={X=p.X,Y=p.Y,Z=p.Z},yaw=30,mode=her_mode,time=clock,pawn=0x7000}
end
world.put=function(to,yaw) puts[#puts+1]={at=to,yaw=yaw}; her_at,her_mode={X=to.X,Y=to.Y,Z=to.Z},1; return true end
local SB_XION='/game/art/bg/worldmap/level_p/e04'
local function new()
    logs,asked,calls={},{},{}
    return Xion.new({log=function(m) logs[#logs+1]=m end,
        status=function() return 'mod=v\n'..ENGINE..'\n'..rows_line..'\n'..warp_line..'\nlast=x\n' end,
        ask=function(l) asked[#asked+1]=l; return true,'asked the native part: '..l end,paks=PAKS,read=read,
        slot=function(what) if slot_ok then return true end return false,what..' runs only on a co-op save' end,
        mode=function() return mode end,me=function() return me end,world=world})
end
local function logged(text) for _,l in ipairs(logs) do if l:find(text,1,true) then return l end end end
local function times(text) local n=0; for _,l in ipairs(logs) do if l:find(text,1,true) then n=n+1 end end; return n end
-- Seconds of 250 ms passes.
local function pass(x,seconds) for _=1,math.floor(seconds*4+0.5) do clock=clock+0.25; x.tick() end end
local function at(p) return {at={X=p.X,Y=p.Y,Z=p.Z},map=D.MAP} end
fresh()
pak(true)

-- command_refusals: each guard of coop xion, with nothing asked.
me={at={X=0,Y=0,Z=0},map=SB_XION}
local x=new()
slot_ok=false
local ok,why=x.enter('city')
assert(not ok and why=='coop xion runs only on a co-op save',why)
ok,why=x.leave()
assert(not ok and why=='coop xion leave runs only on a co-op save',why)
slot_ok,mode=true,'host'
ok,why=x.enter('city')
assert(not ok and why=='coop xion is solo only: leave the session first (coop leave)',why)
mode=nil
ok,why=x.enter('city')
assert(not ok and why:find('the Steam link is not ready yet',1,true),why)
mode='none'
ok,why=x.enter('roof')
assert(not ok and why=='coop xion: no arrival point roof',why)
pak(false)
x=new()
ok,why=x.enter('city')
assert(not ok and why:find('coop xion needs the zSBO_Xion test pak',1,true) and why:find('nothing was asked',1,true),
    why)
pak(true)
x=new()
rows_line='sboxion=off'
x.title(true,true) -- The title's ask ends on a refusal.
rows_line='sboxion=refused added=1/2 asks=1 spawns=? why=id table=ZoneTable row=Zone_SBO_Xion'
clock=clock+0.5
x.tick()
ok,why=x.enter('city')
assert(not ok and why:find('rows were refused this game run',1,true) and times('coop xion stays off')==1,why)
ok,why=x.enter('gate')
assert(not ok and times('coop xion stays off')==1,'The refusal is said once')
rows_line='sboxion=rows added=2/2 asks=1 spawns=? char=0/0 skills=0/0 stance=0/0'
x=new()
warp_line='sboxionwarp=fault asks=1 where=SB.exe+0x10 (a read)'
ok,why=x.enter('city')
assert(not ok and why=='coop xion: stopped by a fault this game run (SB.exe+0x10 (a read))',why)
warp_line=''
ok,why=x.leave()
assert(not ok and why:find('no sboxionwarp line',1,true),why)
warp_line='sboxionwarp=off'
zone_index=nil
ok,why=x.leave()
assert(not ok and why:find('Zone_SBO_Xion is no name in this game',1,true),why)
zone_index=4660
assert(#asked==0,'A refused command asks nothing')

-- enter_city, enter_gate: the request holds the zone's index, the point in whole centimetres and the yaw.
x=new()
ok,why=x.enter('city')
assert(ok and asked[1]=='sboxion enter 4660 -8304 7201 225 -233',tostring(asked[1])..' '..tostring(why))
assert(why:find('the warp to the city point is asked',1,true) and logged('sboxion rows: 2/2 in'),why)
assert(logged('sboxion: asked of the native part: sboxion enter 4660 -8304 7201 225 -233'))
-- The native answer is relayed once its asks= grew, once.
pass(x,1)
assert(not logged('the native part answers'))
warp_line='sboxionwarp=entered asks=1'
pass(x,1)
assert(times('sboxion: the native part answers: sboxionwarp=entered asks=1')==1,logs[#logs])
ok=x.enter('gate') -- A second command reads the rows back again and says them in once.
assert(ok and asked[2]=='sboxion enter 4660 -23393 17287 1285 -8' and times('sboxion rows: 2/2 in')==1,asked[2])
pass(x,11) -- No answer: said once after 10 s.
assert(times('sboxion: no answer of the native part in 10 s (sboxionwarp=entered asks=1)')==1,logs[#logs])
-- leave: asked from any map, here SB's Xion. The native part's refusal is relayed.
x=new()
ok,why=x.leave()
assert(ok and asked[1]=='sboxion leave 4660' and why:find('refuses it outside SBO Xion',1,true),why)
warp_line='sboxionwarp=refused asks=2 verb=leave why=zone'
pass(x,0.5)
assert(logged('sboxion: the native part answers: sboxionwarp=refused asks=2 verb=leave why=zone'))

-- nothing_outside: in SB's Xion, with nothing asked, no engine read and no line.
x=new()
pass(x,30)
assert(total()==0 and #logs==0,'Nothing outside SBO Xion: '..total()..' reads, '..#logs..' lines')

-- arrival: the day table, the levels, the probes and the characters, once.
fresh()
me=at(D.ARRIVALS.city)
pass(x,0.25)
assert(logs[1]=='sboxion: arrived, map /Game/SBO_World/Xion_P, zone Zone_SBO_Xion, EVE at (-8304, 7201, 225)',logs[1])
assert(logs[2]=='sboxion: recovery on: floor Z -3275, arrival point city (-8304, 7201, 225)' and calls.move==1,logs[2])
assert(logged('sboxion: light: 72 env volumes found, 65 in E04_ENV_VOL, 41 named, 21 changed, CountDown_Posing_ENV '
    ..'active true'),logs[2])
assert(#sets==21,#sets..' writes')
for _,name in ipairs(D.DAY.on) do assert(by[name].on==true,name) end
for _,name in ipairs(D.DAY.off) do assert(by[name].on==false,name) end
-- Two volumes are left: one of the same name in another level, one in a level whose name only ends like E04_ENV_VOL.
assert(by.other.on==false and by.near.on==true and by.tied.on==true,'Another level\'s volume was written')
for _,path in ipairs(sets) do assert(path:find('/E04_ENV_VOL.E04_ENV_VOL:PersistentLevel.',1,true),path) end
assert(logged('sboxion: levels: 95 listed, 93 of 93 always-loaded ones loaded and visible, missing: none'))
assert(logged('sboxion: probe: start: E04_DistantView_A_01 loaded true visible true, E04_DistantView_A_03 loaded '
    ..'true visible true'))
assert(logged('sboxion: characters: 1') and not logged('characters: 1 ('))
assert(not logged('read back'),'The read-back comes 2 s later')
pass(x,2)
assert(times('sboxion: light: 41 of 41 read back as written')==1,logs[#logs])
assert(calls.volumes==1 and #sets==21,'One pass over the volumes an arrival')
pass(x,8) -- 10 s after the arrival: the levels, the read-back and the characters again.
assert(times('sboxion: light: 41 of 41 read back as written')==2 and times('sboxion: levels: 95 listed')==2
    and times('sboxion: characters: 1')==2 and calls.levels==2,logs[#logs])

-- probe_change: a change of a probe level is logged once, with EVE's place. The change back is logged once too.
me=at({X=-8000,Y=7000,Z=225})
levels[94].visible=false
pass(x,3)
assert(times('sboxion: probe: E04_DistantView_A_01 loaded true visible false, EVE at (-8000, 7000, 225)')==1,
    logs[#logs])
assert(times('sboxion: probe: E04_DistantView_A_03')==0)
levels[94].visible=true
pass(x,3)
assert(times('sboxion: probe: E04_DistantView_A_01 loaded true visible true, EVE at (-8000, 7000, 225)')==1)

-- waypoint_once: logged once EVE has stood within 3 m for 5 s, once a visit.
local kaya=D.WAYPOINTS[2]
assert(kaya.name=='kaya')
me=at({X=kaya.X+200,Y=kaya.Y+200,Z=kaya.Z+900}) -- 2.8 m away on the flat, whatever the height.
levels[94].visible,levels[95].visible=false,false
pass(x,4)
assert(not logged('sboxion: at kaya'),'Not before 5 s')
pass(x,10)
assert(times('sboxion: at kaya: A_01 loaded true visible false, A_03 loaded true visible false')==1,logs[#logs])
me=at({X=kaya.X+400,Y=kaya.Y,Z=kaya.Z}) -- Out of the 3 m, then back: a new visit.
pass(x,2)
me=at({X=kaya.X,Y=kaya.Y,Z=kaya.Z})
pass(x,7)
assert(times('sboxion: at kaya:')==2,'Once a visit')
me=at({X=kaya.X+250,Y=kaya.Y,Z=kaya.Z}) -- A passage of under 5 s at another waypoint says nothing.
pass(x,1)
local tie=D.WAYPOINTS[1]
me=at({X=tie.X,Y=tie.Y,Z=tie.Z})
pass(x,3)
me=at({X=0,Y=0,Z=0})
pass(x,10)
assert(not logged('sboxion: at tie'),'A short passage is no visit')

-- recovery_engine_place: the ground point and the fall use the engine's read of EVE in the pass, not me(), which is
-- one pass old. Here me() stays at the waypoint while the engine reads her elsewhere.
assert(#puts==0 and logged('sboxion: ground: first point (-8304, 7201, 225)'),'No put-back on the walk so far')
her_at={X=3000,Y=-9000,Z=1222}
pass(x,1)
her_at,her_mode={X=3931,Y=-9086,Z=-3400},3
pass(x,0.25)
assert(logs[#logs]=='sboxion: fall: EVE at (3931, -9086, -3400) under the floor, mode 3, life ?: to the ground point '
    ..'(3000, -9000, 1222) read 1.0 s ago',logs[#logs])
assert(#puts==1 and puts[1].at.X==3000 and puts[1].at.Y==-9000 and puts[1].at.Z==1232 and puts[1].yaw==30)
pass(x,0.25)
assert(logs[#logs]=='sboxion: put back: EVE walks at (3000, -9000, 1232), 0.2 s after the move',logs[#logs])
her_at=nil

-- status: the pak, the rows, the native line, EVE's place and the nearest waypoint.
me=at({X=kaya.X+300,Y=kaya.Y+400,Z=kaya.Z})
ok,why=x.status()
assert(ok and why:find('rows in; sboxionwarp=refused asks=2 verb=leave why=zone; EVE at (-7877, -1413, 44), nearest '
    ..'waypoint kaya 5.0 m',1,true) and why:find('^sboxion: pak %d+_4096; '),why)
-- Inside, coop xion is refused: the way in is for another map.
ok,why=x.enter('gate')
assert(not ok and why=='coop xion: EVE is in SBO Xion already; way out: coop xion leave' and #asked==0,why)

-- map_change: the watch and the recovery end and nothing is read after. A put-back being checked is dropped. The
-- next arrival writes the day table again.
her_at,her_mode={X=0,Y=0,Z=-5000},3
world.put=function(to,yaw) puts[#puts+1]={at=to,yaw=yaw}; return true end -- She keeps falling after this one.
pass(x,0.25)
assert(#puts==2,'A fall right before the map change')
her_at,her_mode=nil,1
local reads=total()
me={at={X=0,Y=0,Z=0},map=SB_XION}
pass(x,0.25)
assert(logs[#logs]=='sboxion: left, map '..SB_XION,logs[#logs])
ok,why=x.status()
assert(ok and why:find('EVE is not in SBO Xion (map '..SB_XION..')',1,true),why)
pass(x,20)
assert(total()==reads and times('sboxion: left')==1,'Nothing is read after a map change')
fresh()
me=at(D.ARRIVALS.gate)
pass(x,0.25)
assert(times('sboxion: arrived')==2 and #sets==21 and times('41 named, 21 changed')==2,'A second arrival writes again')
assert(times('sboxion: recovery on: floor Z -3275, arrival point city')==2,'The recovery starts again at each arrival')
pass(x,5)
assert(not logged('put back failed') and times('put back: EVE walks')==1,'The check of the stay before is gone')
-- A loading screen (no EVE) ends the stay too.
me=nil
pass(x,0.25)
assert(logs[#logs]=='sboxion: left, map none',logs[#logs])

-- A volume whose write does not hold shows in the read-back; a level not loaded is named.
fresh()
by['E04_Area_02_Sub_ENV_01****'].on,by['E04_Area_02_Sub_ENV_01****'].stuck=false,true
levels[7].visible,names=false,{'CH_P_EVE_01_Blueprint_C_0','Animal_Rat_C_3'}
me=at(D.ARRIVALS.city)
pass(x,2.25)
assert(logged('sboxion: light: 40 of 41 read back as written, not E04_Area_02_Sub_ENV_01****'),logs[#logs])
assert(logged('sboxion: levels: 95 listed, 92 of 93 always-loaded ones loaded and visible, missing: E04_Level_7'))
assert(logged('sboxion: characters: 2 (CH_P_EVE_01_Blueprint_C_0, Animal_Rat_C_3)'))
-- An engine read that raises is logged and stops nothing.
me=nil
pass(x,0.25)
world.volumes=function() error('no EVE in the world') end
fresh()
me=at(D.ARRIVALS.city)
pass(x,0.25)
assert(logged('sboxion: light: unread (no EVE in the world)') and times('sboxion: arrived')==4,logs[#logs])

-- The arrival point coop xion asked is the recovery's point of the stay it starts.
me={at={X=0,Y=0,Z=0},map=SB_XION}
pass(x,0.25)
world.volumes=function() count('volumes'); return volumes end
warp_line='sboxionwarp=off'
ok=x.enter('gate')
assert(ok)
me=at(D.ARRIVALS.gate)
pass(x,0.25)
assert(logged('sboxion: recovery on: floor Z -3275, arrival point gate (-23393, 17287, 1285)'),logs[#logs])

-- coop_off: the watch and the recovery end, nothing is read or said after.
her_at,her_mode={X=0,Y=0,Z=-5000},3
reads=total()
local lines=#logs
x.stop()
levels[94].visible=not levels[94].visible
pass(x,30)
assert(total()==reads and #logs==lines,'Nothing after coop off')
print('sboxion_world_test ok')
