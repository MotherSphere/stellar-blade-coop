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
-- by the engine's read of EVE and not by me(), SB's black asked through the module's own wiring at a fall with the
-- move two passes later, ended by a map change and by coop off, each showing again a death
-- screen the recovery hid; coop xion recover refused out of SBO Xion, its three modes inside, the mode death back to
-- on at the next arrival and the recovery's part of the status. The walls (world/maps/sboxion/walls/walls.lua): queued
-- at each arrival nearest to the point coop xion asked, made 10 a pass through the module's own wiring and only in SBO
-- Xion, their part of the status, taken down by a map change (none called once the world is gone, each destroyed
-- while it still stands) and by coop off, kept in the store the wiring hands over; coop xion walls refused out of SBO
-- Xion, inside its count alone, off and on.
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
world.black=function() count('black'); return true end -- SB's black over a put-back: SB made it.
-- The respawn's fakes: SB's request sets the life word to 1; the death screen plays until hidden.
local PC,respawns,screen_shown={},{},true
world.controller=function() return PC end
world.standalone=function() return true end
world.screen=function() return true end
world.hide=function() screen_shown=false; return function() screen_shown=true end end
-- The walls' fakes, counted apart from the reads: each wall made by name, each removal, a world that is gone.
local walls_made,walls_removed,world_gone={},0,false
world.wall=function(b)
    walls_made[#walls_made+1]=b.name
    return {path='/Game/SBO_World/Xion_P.Xion_P:PersistentLevel.Actor_'..#walls_made,
        read='object type 20, collision on'}
end
world.unwall=function(d)
    if world_gone or d.gone then return false end
    d.gone=true
    walls_removed=walls_removed+1
    return true
end
world.wall_swept=function() return false end
local kept=nil -- The store's line.
local store={save=function(line) kept=line end,load=function() return kept end,clear=function() kept=nil end}
local SB_XION='/game/art/bg/worldmap/level_p/e04'
local function new()
    logs,asked,calls={},{},{}
    return Xion.new({log=function(m) logs[#logs+1]=m end,
        status=function() return 'mod=v\n'..ENGINE..'\n'..rows_line..'\n'..warp_line..'\nlast=x\n' end,
        ask=function(l) asked[#asked+1]=l; return true,'asked the native part: '..l end,paks=PAKS,read=read,
        slot=function(what) if slot_ok then return true end return false,what..' runs only on a co-op save' end,
        mode=function() return mode end,me=function() return me end,world=world,store=store})
end
world.respawn=function(_,guid) respawns[#respawns+1]=guid; warp_line='sboxionwarp=entered asks=3 life=1' end
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
assert(#walls_made==0,'No wall outside SBO Xion')

-- arrival: the day table, the levels, the probes and the characters, once.
fresh()
me=at(D.ARRIVALS.city)
pass(x,0.25)
assert(logs[1]=='sboxion: arrived, map /Game/SBO_World/Xion_P, zone Zone_SBO_Xion, EVE at (-8304, 7201, 225)',logs[1])
assert(logs[2]=='sboxion: recovery on: floor Z -3275, arrival point city (-8304, 7201, 225)' and calls.move==1,logs[2])
-- walls_arrival: queued at the arrival, the first 10 made in its pass, all 178 up 18 passes later.
assert(logs[3]=='sboxion: walls: 178 to put up, 10 a pass, nearest to the city point first',logs[3])
assert(#walls_made==10 and logged('sboxion: walls: first wall '..walls_made[1]..' up: object type 20, collision on'))
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
assert(#walls_made==90 and not logged('walls: 178 of 178 up'),'Nine passes: '..#walls_made)
pass(x,8) -- 10 s after the arrival: the levels, the read-back and the characters again.
assert(times('sboxion: light: 41 of 41 read back as written')==2 and times('sboxion: levels: 95 listed')==2
    and times('sboxion: characters: 1')==2 and calls.levels==2,logs[#logs])
assert(#walls_made==178 and times('sboxion: walls: 178 of 178 up in 18 passes, 0 ms')==1,'The walls are up')
local _,tabs=kept:gsub('\t','')
assert(tabs==177,'The wiring\'s store holds the 178 paths')

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
-- recovery_black: the module's own wiring hands the recovery the engine's black. It is asked at the catch and the move
-- comes two passes later.
assert(calls.black==1 and #puts==0 and logs[#logs]=='sboxion: black: up in 0.3 s; EVE at (3931, -9086, -3400) moves '
    ..'in 2 passes',logs[#logs])
pass(x,0.5)
assert(logs[#logs]=='sboxion: fall: EVE at (3931, -9086, -3400) under the floor, mode 3, life ?: to the ground point '
    ..'(3000, -9000, 1222) read 1.5 s ago',logs[#logs])
assert(#puts==1 and puts[1].at.X==3000 and puts[1].at.Y==-9000 and puts[1].at.Z==1232 and puts[1].yaw==30)
assert(calls.black==1,'One black a put-back')
pass(x,0.25)
assert(logs[#logs]=='sboxion: put back: EVE walks at (3000, -9000, 1232), 0.2 s after the move',logs[#logs])
her_at=nil

-- status: the pak, the rows, the native line, EVE's place and the nearest waypoint.
me=at({X=kaya.X+300,Y=kaya.Y+400,Z=kaya.Z})
ok,why=x.status()
assert(ok and why:find('rows in; sboxionwarp=refused asks=2 verb=leave why=zone; EVE at (-7877, -1413, 44), nearest '
    ..'waypoint kaya 5.0 m; recovery on, ground (3000, -9000, 1222) 1.8 s old, failures 0; walls 178 of 178 up',1,
    true) and why:find('^sboxion: pak %d+_4096; ') and why:find('walls 178 of 178 up$'),why)
-- coop xion recover: the three modes, said in the log too; alone, the recovery's state; another word refused.
ok,why=x.recover('death')
assert(ok and why=='coop xion recover: recovery mode death: falls are not caught, deaths are'
    and logs[#logs]=='sboxion: recovery mode death: falls are not caught, deaths are',why)
ok,why=x.recover()
assert(ok and why=='coop xion recover: recovery death, ground (3000, -9000, 1222) 1.8 s old, failures 0',why)
ok,why=x.recover('off')
assert(ok and x.status and select(2,x.status()):find('; recovery off, ',1,true),why)
ok,why=x.recover('up')
assert(not ok and why=='Use: coop xion recover [on|death|off]',why)
assert(x.recover('on'))
-- Inside, coop xion is refused: the way in is for another map.
ok,why=x.enter('gate')
assert(not ok and why=='coop xion: EVE is in SBO Xion already; way out: coop xion leave' and #asked==0,why)

-- coop xion walls: the count alone; off takes them down and none is made; on builds them again, nearest to EVE.
ok,why=x.walls()
assert(ok and why=='coop xion walls: walls 178 of 178 up',why)
ok,why=x.walls('off')
assert(ok and why=='coop xion walls: walls off until coop xion walls on or the next arrival' and walls_removed==178
    and logs[#logs]=='sboxion: walls: down (coop xion walls off): 178 removed' and kept==nil,why)
assert(select(2,x.status()):find('; walls off$'),select(2,x.status()))
pass(x,1)
assert(#walls_made==178,'Off makes none')
ok,why=x.walls('on')
assert(ok and why=='coop xion walls: walls on: 178 to put up ([SX] lines follow)'
    and logs[#logs]=='sboxion: walls: 178 to put up, 10 a pass, nearest to EVE first',why)
pass(x,4.5)
assert(#walls_made==356 and times('sboxion: walls: 178 of 178 up in 18 passes')==2,'Up again: '..#walls_made)
ok,why=x.walls('up')
assert(not ok and why=='Use: coop xion walls [on|off]',why)

-- map_change: the watch and the recovery end and nothing is read after. A put-back being checked is dropped. The
-- next arrival writes the day table again.
her_at,her_mode={X=0,Y=0,Z=-5000},3
world.put=function(to,yaw) puts[#puts+1]={at=to,yaw=yaw}; return true end -- She keeps falling after this one.
pass(x,0.75) -- The black, then the move two passes later.
assert(#puts==2 and calls.black==2,'A fall right before the map change')
assert(x.recover('death')) -- The stay ends in the mode death: the next arrival sets it back to on.
her_at,her_mode=nil,1
local reads=total()
me={at={X=0,Y=0,Z=0},map=SB_XION}
world_gone=true -- The map change destroyed SBO Xion's world with its walls.
pass(x,0.25)
assert(logs[#logs]=='sboxion: left, map '..SB_XION,logs[#logs])
-- walls_map_change: no wall of a world that is gone is destroyed and the store is cleared.
assert(logs[#logs-1]=='sboxion: walls: down (a map change): 0 removed, 178 gone already' and walls_removed==178
    and kept==nil,logs[#logs-1])
world_gone=false
ok,why=x.walls('on')
assert(not ok and why=='coop xion walls: EVE is not in SBO Xion',why)
ok,why=x.status()
assert(ok and why:find('EVE is not in SBO Xion (map '..SB_XION..')',1,true) and not why:find('recovery',1,true)
    and not why:find('walls',1,true),why)
ok,why=x.recover('on')
assert(not ok and why=='coop xion recover: EVE is not in SBO Xion',why)
pass(x,20)
assert(total()==reads and times('sboxion: left')==1,'Nothing is read after a map change')
assert(#walls_made==356,'No wall is made in another map')
fresh()
me=at(D.ARRIVALS.gate)
pass(x,0.25)
assert(#walls_made==366 and times('sboxion: walls: 178 to put up, 10 a pass, nearest to the city point first')==2,
    'Each arrival builds the walls again')
assert(times('sboxion: arrived')==2 and #sets==21 and times('41 named, 21 changed')==2,'A second arrival writes again')
assert(times('sboxion: recovery on: floor Z -3275, arrival point city')==2,'The recovery starts again at each arrival')
assert(select(2,x.status()):find('; recovery on, no ground point, failures 0',1,true),'The mode is on again')
pass(x,5)
assert(not logged('put back failed') and times('put back: EVE walks')==1,'The check of the stay before is gone')
-- A loading screen (no EVE) ends the stay too. Walls of a world that still stands are destroyed.
me=nil
pass(x,0.25)
assert(logs[#logs]=='sboxion: left, map none',logs[#logs])
assert(logs[#logs-1]=='sboxion: walls: down (a map change): 178 removed' and walls_removed==356,logs[#logs-1])

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
-- walls_gate: the walls are queued from the point coop xion asked, so the cave wall is made first.
assert(logged('sboxion: walls: 178 to put up, 10 a pass, nearest to the gate point first')
    and logged('sboxion: walls: first wall CAVE.1 up: object type 20, collision on'),logs[#logs])

-- A death in SBO Xion: the life word of the sboxionwarp line starts SB's in-place respawn with the GUID of the
-- engine line. The death screen the recovery hid is shown again when EVE leaves the map.
warp_line='sboxionwarp=entered asks=3 life=3'
pass(x,0.25)
assert(#respawns==1 and respawns[1]==2610 and logged('sboxion: death: life 3, EVE at (-23393, 17287, 1285)'),
    logs[#logs])
pass(x,2)
assert(logged('sboxion: respawn result: life 3/1, death screen up/hidden, EVE pawn same, mode 1') and not screen_shown,
    logs[#logs])
me={at={X=0,Y=0,Z=0},map=SB_XION}
pass(x,0.25)
assert(screen_shown and logs[#logs-1]=='sboxion: respawn: death screen shown again (a map change)'
    and logs[#logs]=='sboxion: left, map '..SB_XION,logs[#logs-1])
warp_line='sboxionwarp=left asks=4'
ok=x.enter('city')
me=at(D.ARRIVALS.city)
pass(x,0.25)

-- coop_off: the watch and the recovery end, nothing is read or said after.
her_at,her_mode={X=0,Y=0,Z=-5000},3
reads=total()
local lines,before=#logs,walls_removed
x.stop()
-- walls_coop_off: the 10 walls of the arrival's pass are destroyed. That line is coop off's only one.
assert(#logs==lines+1 and logs[#logs]=='sboxion: walls: down (coop off): 10 removed, 168 never made'
    and walls_removed==before+10,logs[#logs])
lines=#logs
local built=#walls_made
levels[94].visible=not levels[94].visible
pass(x,30)
assert(total()==reads and #logs==lines and #walls_made==built,'Nothing after coop off')

-- coop_off_screen: coop off shows again a death screen the recovery hid.
x=new()
her_at,her_mode=nil,1
me=at(D.ARRIVALS.city)
warp_line='sboxionwarp=entered asks=5 life=3'
pass(x,2.5)
assert(not screen_shown and logged('sboxion: respawn result: life 3/1, death screen up/hidden'),logs[#logs])
x.stop()
assert(screen_shown and logs[#logs]=='sboxion: respawn: death screen shown again (coop off)',logs[#logs])
print('sboxion_world_test ok')
