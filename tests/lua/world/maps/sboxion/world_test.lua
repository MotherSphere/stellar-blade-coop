-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's commands, arrival, day table and watch (world/maps/sboxion/sboxion.lua) over a fake world: 72 env volumes
-- (65 in E04_ENV_VOL with the 41 of the day table, 21 of them stored other than the table), 95 streaming levels with
-- the two probe levels, EVE's map and place, the status text and the clock. Covered: coop xion's refusals (not a co-op
-- save, in a session, no pak, rows refused, a fault, already inside) and its request for each point, coop xion leave's
-- request from any map and the native answer relayed once; at an arrival the 41 writes matched by level and name, a
-- volume of the same name in another level left alone, the counts 72, 65 and 41, the read-back, the levels line and the
-- characters; nothing read in another map; a second arrival writes again; a probe level's change logged once; a
-- waypoint logged once a visit; the watch ended by a map change and by coop off. The recovery
-- (world/maps/sboxion/recover.lua): ticked only in SBO Xion, reset at each arrival with the point coop xion asked, fed
-- by the engine's read of EVE and not by me(), SB's black asked through the module's own wiring at a fall with the move
-- two passes later, ended by a map change and by coop off, each showing again a death screen the recovery hid; coop
-- xion recover refused out of SBO Xion, its three modes inside, the mode death back to on at the next arrival and the
-- recovery's part of the status. The walls of 24 November 2026 are gone: no wall call, no walls word and no walls part
-- of the status. The rooms (world/maps/sboxion/rooms/rooms.lua): with a pak that holds no room level, one line an
-- arrival, the pak's files read once a room a Lua load, no piece asked and the status part saying none; with the five
-- room levels in the pak one line says so and the arrival's pass opens the five rooms through the module's own wiring,
-- their part of the status, coop xion rooms refused out of SBO Xion, alone, off and on, every row put back at coop off,
-- none called once a map change took the world, the hidden rows kept in the rooms' own store; with two of them in the
-- pak those two open, the pak asked once a room a Lua load. At a map change and at coop off the recovery ends before
-- the rooms close. The threshold doors (world/maps/sboxion/rooms/threshold.lua): one line an arrival and their part
-- of the status with the pak of 2026-11-23 (none), with the eleven rooms of build3 (D039's alone) and with a pak that
-- holds every room; a push through the module's own wiring with the recovery's read of EVE, the black, the move two
-- passes later and the opened door in the doors' own store; off and on with coop xion rooms; a threshold door and
-- the Tetrapod's door never moving her at once; a cutscene and a death that make the doors wait; a door kept shut
-- while its room's level does not show on the streaming list; nothing after coop off.
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
local ROOMS={'Rooms','Xion_Rooms_D011.umap','Xion_Rooms_D031.umap','Xion_Rooms_D081.umap','Xion_Rooms_D107.umap',
    'Xion_Rooms_D158.umap'}
local ROOMS3={'Rooms'} -- The pak of build3: every room of the list, D039 too.
for _,room in ipairs({'D011','D031','D081','D107','D158','D009','D039','D049','D092','D036','D106'}) do
    ROOMS3[#ROOMS3+1]='Xion_Rooms_'..room..'.umap'
end
local opens=0 -- Each time the .utoc is opened.
local function read(path,limit,offset)
    if path:sub(-5)=='.utoc' then opens=opens+1 end
    return files[path] and files[path]:sub((offset or 0)+1,(offset or 0)+limit)
end
-- on: the pak of 2026-11-23; 'rooms': the pak with the five room levels; a table: the pak with those room files.
local function pak(on)
    files[PAKS..'\\~mods\\zSBO_Xion.utoc']=on and utoc({'SBO_World','Xion_P.umap',
        table.unpack(on=='rooms' and ROOMS or type(on)=='table' and on or {})}) or nil
    files[PAKS..'\\~mods\\zSBO_Xion.pak'],files[PAKS..'\\~mods\\zSBO_Xion.ucas']='',('\0'):rep(64)
end

-- The fake world. calls counts every engine read, by name.
local BG='/Game/Art/BG/WorldMap/SubLevel/E04/'
local calls,volumes,levels,names,zone_index={},{},{},{},4660
-- EVE's map and place as core/where.lua gives them (me), her place as the engine reads her in the same pass (her_at,
-- me.at unless set).
local me,her_at=nil,nil
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
    names={{name='CH_P_EVE_01_Blueprint_C_0',class='CH_P_EVE_01_Blueprint_C',eve=true}}
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
    -- names: {name=, class=, eve=, at=} each; EVE's entry stands where the engine reads her.
    characters=function()
        count('characters')
        local out={}
        for i,c in ipairs(names) do
            out[i]={name=c.name,class=c.class,eve=c.eve,at=c.eve and (her_at or me.at) or c.at}
        end
        return out
    end,
}
local function total() local n=0; for _,c in pairs(calls) do n=n+c end; return n end

local logs,asked={},{}
local rows_line,warp_line='sboxion=rows added=2/2 asks=1 spawns=? char=0/0 skills=0/0 stance=0/0','sboxionwarp=off'
local ENGINE='engine=on remote=0 0 none warp=idle me=2610 zonetype=5 area=Zone_SBO_Xion rest=0::0 starts=0 theater=none'
local slot_ok,mode=true,'none'
-- EVE as the engine reads her in the same pass: at her_at (me.at unless set), in mode her_mode. puts: each put-back.
local her_mode,her_yaw,puts=1,30,{}
world.move=function()
    count('move')
    local p=her_at or me.at
    return {at={X=p.X,Y=p.Y,Z=p.Z},yaw=her_yaw,mode=her_mode,time=clock,pawn=0x7000}
end
world.put=function(to,yaw) puts[#puts+1]={at=to,yaw=yaw}; her_at,her_mode={X=to.X,Y=to.Y,Z=to.Z},1; return true end
world.black=function() count('black'); return true end -- SB's black over a put-back: SB made it.
local ships={} -- Each ask to make the Tetrapod's parts solid (true) or to put them back (false).
world.ship=function(solid) ships[#ships+1]=solid; return 124 end
-- The respawn's fakes: SB's request sets the life word to 1; the death screen plays until hidden.
local PC,respawns,screen_shown={},{},true
world.controller=function() return PC end
world.standalone=function() return true end
world.screen=function() return true end
world.hide=function() screen_shown=false; return function() screen_shown=true end end
local tolds=0 -- Each time SB's death screen is told its revival ended.
world.revived=function() tolds=tolds+1; return true end
local world_gone=false -- A map change destroyed SBO Xion's world.
-- The rooms' fakes: each piece asked by its row's name, the rows hidden now and the rooms' own store.
local pieces_asked,rows_hidden,rooms_kept=0,{},nil
world.piece=function(row) pieces_asked=pieces_asked+1; return {row=row} end
world.piece_out=function(p) p.was={1,3}; rows_hidden[p.row.name]=true end
world.piece_back=function(p)
    if world_gone or not rows_hidden[p.row.name] then return false end
    rows_hidden[p.row.name]=nil
    return true
end
local rooms_store={save=function(line) rooms_kept=line end,load=function() return rooms_kept end,
    clear=function() rooms_kept=nil end}
-- The threshold doors: the rooms of the list that have one and the doors' own store, the door file.
local Threshold=require('world.maps.sboxion.rooms.threshold')
local DOORS=#Threshold.LIST
local doors_kept=nil
local doors_store={save=function(line) doors_kept=line; return true end,load=function() return doors_kept end}
local function hidden_rows() local n=0; for _ in pairs(rows_hidden) do n=n+1 end; return n end
local SB_XION='/game/art/bg/worldmap/level_p/e04'
local function new()
    logs,asked,calls={},{},{}
    return Xion.new({log=function(m) logs[#logs+1]=m end,
        status=function() return 'mod=v\n'..ENGINE..'\n'..rows_line..'\n'..warp_line..'\nlast=x\n' end,
        ask=function(l) asked[#asked+1]=l; return true,'asked the native part: '..l end,paks=PAKS,read=read,
        slot=function(what) if slot_ok then return true end return false,what..' runs only on a co-op save' end,
        mode=function() return mode end,me=function() return me end,world=world,rooms_store=rooms_store,
        doors_store=doors_store})
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

-- arrival: the day table, the levels, the probes and the characters, once.
fresh()
me=at(D.ARRIVALS.city)
pass(x,0.25)
assert(logs[1]=='sboxion: arrived, map /Game/SBO_World/Xion_P, zone Zone_SBO_Xion, EVE at (-8304, 7201, 225)',logs[1])
assert(logs[2]=='sboxion: recovery on: floor Z -3275, arrival point city (-8304, 7201, 225)' and calls.move==1,logs[2])
assert(x.walls==nil and not logged('walls'),'No wall at an arrival')
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
assert(logged('sboxion: characters: 1') and not logged('characters: 1 (') and not logged('by class'))
assert(not logged('read back'),'The read-back comes 2 s later')
-- rooms_old_pak: the pak of 2026-11-23 holds no room level. One line an arrival and no piece asked.
assert(logged('sboxion: rooms: none in this pak ('..PAKS..'\\~mods\\zSBO_Xion.utoc does not hold Rooms): no door '
    ..'is opened') and times('sboxion: rooms:')==1,'One line: '..times('sboxion: rooms:'))
-- doors_old_pak: it holds no threshold room either. One calm line an arrival.
assert(times('sboxion: threshold:')==1 and logged('sboxion: threshold: none of the '..DOORS..' rooms is in this pak'),
    'One line: '..times('sboxion: threshold:'))
x.status() -- Asks the gate for Xion_P, once a Lua load too.
local opened=opens
pass(x,2)
assert(times('sboxion: light: 41 of 41 read back as written')==1,logs[#logs])
assert(calls.volumes==1 and #sets==21,'One pass over the volumes an arrival')
pass(x,8) -- 10 s after the arrival: the levels, the read-back and the characters again.
assert(times('sboxion: light: 41 of 41 read back as written')==2 and times('sboxion: levels: 95 listed')==2
    and times('sboxion: characters: 1')==2 and calls.levels==2,logs[#logs])
assert(times('sboxion: rooms:')==1 and pieces_asked==0 and rooms_kept==nil,'No hide pass with the old pak')
ok,why=x.rooms()
assert(ok and why=='coop xion rooms: rooms none in the pak; threshold doors none in the pak',why)
ok,why=x.rooms('off')
assert(ok and why=='coop xion rooms: rooms off until coop xion rooms on or the next arrival' and pieces_asked==0,why)
ok,why=x.rooms('on')
assert(ok and why=='coop xion rooms: rooms none in the pak' and times('sboxion: rooms: none in this pak')==2,why)
assert(opens==opened,'The pak is asked for the rooms once a Lua load')

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
    ..'waypoint kaya 5.0 m; recovery on, ground (3000, -9000, 1222) 1.8 s old, failures 0; rooms none in the pak; '
    ..'threshold doors none in the pak',1,true) and why:find('^sboxion: pak %d+_4096; ')
    and why:find('; rooms none in the pak; threshold doors none in the pak; look 5 s ago: 1 character, '
    ..'levels 93 of 93 always%-loaded, 2 of 2 by volume loaded, 0 visible, zonetype 5 area Zone_SBO_Xion, life '
    ..'unread %(the sboxionwarp line has no life= word%)$'),why)
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
world_gone=true -- The map change destroyed SBO Xion's world.
pass(x,0.25)
assert(logs[#logs]=='sboxion: left, map '..SB_XION,logs[#logs])
world_gone=false
ok,why=x.rooms('off')
assert(not ok and why=='coop xion rooms: EVE is not in SBO Xion',why)
ok,why=x.status()
assert(ok and why:find('EVE is not in SBO Xion (map '..SB_XION..')',1,true) and not why:find('recovery',1,true)
    and not why:find('walls',1,true) and not why:find('rooms',1,true) and not why:find('threshold',1,true),why)
ok,why=x.recover('on')
assert(not ok and why=='coop xion recover: EVE is not in SBO Xion',why)
pass(x,20)
assert(total()==reads and times('sboxion: left')==1,'Nothing is read after a map change')
fresh()
me=at(D.ARRIVALS.gate) -- No coop xion was asked for this arrival, as after a Lua reload.
pass(x,0.25)
assert(times('sboxion: arrived')==2 and #sets==21 and times('41 named, 21 changed')==2,'A second arrival writes again')
assert(times('sboxion: rooms: none in this pak')==3 and opens==opened and pieces_asked==0,'One line an arrival')
assert(times('sboxion: threshold: none of the')==2,'The threshold doors too')
assert(times('sboxion: recovery on: floor Z -3275, arrival point city')==2,'The recovery starts again at each arrival')
assert(select(2,x.status()):find('; recovery on, no ground point, failures 0',1,true),'The mode is on again')
pass(x,5)
assert(not logged('put back failed') and times('put back: EVE walks')==1,'The check of the stay before is gone')
-- A loading screen (no EVE) ends the stay too.
me=nil
pass(x,0.25)
assert(logs[#logs]=='sboxion: left, map none',logs[#logs])

-- A volume whose write does not hold shows in the read-back; a level not loaded is named.
fresh()
by['E04_Area_02_Sub_ENV_01****'].on,by['E04_Area_02_Sub_ENV_01****'].stuck=false,true
levels[7].visible,names=false,{{name='CH_P_EVE_01_Blueprint_C_0',class='CH_P_EVE_01_Blueprint_C'},
    {name='Animal_Rat_C_3',class='Animal_Rat_C'}}
me=at(D.ARRIVALS.city)
pass(x,2.25)
assert(logged('sboxion: light: 40 of 41 read back as written, not E04_Area_02_Sub_ENV_01****'),logs[#logs])
assert(logged('sboxion: levels: 95 listed, 92 of 93 always-loaded ones loaded and visible, missing: E04_Level_7'))
assert(logged('sboxion: characters: 2 by class: Animal_Rat_C 1, CH_P_EVE_01_Blueprint_C 1'))
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

-- A death in SBO Xion: the life word of the sboxionwarp line starts SB's in-place respawn with the GUID of the
-- engine line. The death screen the recovery hid is shown again when EVE leaves the map.
warp_line='sboxionwarp=entered asks=3 life=3'
pass(x,0.25)
assert(#respawns==1 and respawns[1]==2610 and logged('sboxion: death: life 3, EVE at (-23393, 17287, 1285)'),
    logs[#logs])
pass(x,2)
assert(logged('sboxion: respawn result: life 3/1, death screen up/hidden, EVE pawn same, mode 1') and not screen_shown,
    logs[#logs])
assert(tolds==1 and logged('sboxion: respawn: death screen told its revival ended'),'The engine call is wired')
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
local lines=#logs
x.stop()
assert(#logs==lines,'With no room open and no death screen hidden coop off says nothing: '..tostring(logs[#logs]))
levels[94].visible=not levels[94].visible
pass(x,30)
assert(total()==reads and #logs==lines,'Nothing after coop off')

-- coop_off_screen: coop off shows again a death screen the recovery hid.
x=new()
her_at,her_mode=nil,1
me=at(D.ARRIVALS.city)
warp_line='sboxionwarp=entered asks=5 life=3'
pass(x,2.5)
assert(not screen_shown and logged('sboxion: respawn result: life 3/1, death screen up/hidden'),logs[#logs])
x.stop()
assert(screen_shown and logs[#logs]=='sboxion: respawn: death screen shown again (coop off)',logs[#logs])

-- rooms_open: with the five room levels in the pak, and their levels and their rows' sublevels on the list, the
-- arrival's pass opens the five rooms. Nothing says none.
local Rooms=require('world.maps.sboxion.rooms.rooms')
pak('rooms')
fresh()
for _,room in ipairs(Rooms.LIST) do
    for _,name in ipairs(room.needs) do levels[#levels+1]={name=name,loaded=true,visible=true} end
end
x=new()
her_at,her_mode,world_gone,pieces_asked=nil,1,false,0
warp_line='sboxionwarp=entered asks=7 life=1'
me=at(D.ARRIVALS.city)
pass(x,0.25)
assert(not logged('none in this pak') and times('sboxion: rooms: D')==5 and pieces_asked==23 and hidden_rows()==23)
assert(times('sboxion: rooms: this pak holds 5 of 10 rooms: D011, D031, D081, D107, D158')==1)
assert(logged('sboxion: rooms: D011 open: 4 rows hidden, 0 ms') and logged('sboxion: rooms: D158 open: 8 rows hidden'))
assert(select(2,rooms_kept:gsub('\t',''))==22,'The hidden rows go to the rooms\' own store')
assert(select(2,x.status()):find('; recovery on, [^;]+; rooms 5 of 5 open; threshold doors none in the pak; look '
    ..'[^;]+$'),select(2,x.status()))
-- coop xion rooms: alone, off and on.
ok,why=x.rooms()
assert(ok and why=='coop xion rooms: rooms 5 of 5 open; threshold doors none in the pak',why)
ok,why=x.rooms('off')
assert(ok and why=='coop xion rooms: rooms off until coop xion rooms on or the next arrival' and hidden_rows()==0
    and logs[#logs]=='sboxion: rooms: closed (coop xion rooms off): 23 rows put back' and rooms_kept==nil,why)
assert(select(2,x.status()):find('; rooms off; threshold doors off; look [^;]+$'),select(2,x.status()))
pass(x,2)
assert(hidden_rows()==0 and pieces_asked==23,'Off stays off')
ok,why=x.rooms('on')
assert(ok and why=='coop xion rooms: rooms on: 5 to open ([SX] lines follow)' and hidden_rows()==0,why)
pass(x,0.25)
assert(hidden_rows()==23 and times('sboxion: rooms: D011 open')==2)
ok,why=x.rooms('up')
assert(not ok and why=='Use: coop xion rooms [on|off]',why)
-- rooms_map_change: a map change took the world with its levels. No row is called and the store is cleared.
me={at={X=0,Y=0,Z=0},map=SB_XION}
world_gone=true
pass(x,0.25)
assert(logs[#logs]=='sboxion: left, map '..SB_XION
    and logs[#logs-1]=='sboxion: rooms: closed (a map change): 0 rows put back, 23 gone already'
    and hidden_rows()==23 and rooms_kept==nil,logs[#logs-1])
world_gone,rows_hidden=false,{}
-- rooms_coop_off: every row is put back.
me=at(D.ARRIVALS.city)
pass(x,0.25)
assert(hidden_rows()==23 and select(2,x.status()):find('; rooms 5 of 5 open; threshold doors none in the pak; look '
    ..'[^;]+$'))
x.stop()
assert(hidden_rows()==0 and logs[#logs]=='sboxion: rooms: closed (coop off): 23 rows put back',logs[#logs])
pass(x,5)
assert(hidden_rows()==0,'Nothing after coop off')
-- stop_order: at coop off and at a map change the recovery ends before the rooms close. Its death screen line comes
-- first.
for _,how in ipairs({'coop off','a map change'}) do
    x=new()
    rows_hidden,her_at,her_mode={},nil,1
    me=at(D.ARRIVALS.city)
    warp_line='sboxionwarp=entered asks=8 life=3'
    pass(x,2.5)
    assert(not screen_shown and hidden_rows()==23,'The recovery hid the death screen and the rooms are open')
    if how=='coop off' then x.stop() else me={at={X=0,Y=0,Z=0},map=SB_XION}; x.tick() end
    local shown,closed
    for i,l in ipairs(logs) do
        if l=='sboxion: respawn: death screen shown again ('..how..')' then shown=i end
        if l=='sboxion: rooms: closed ('..how..'): 23 rows put back' then closed=closed or i end
    end
    assert(screen_shown and shown and closed and shown<closed,how..': '..tostring(shown)..' '..tostring(closed))
end

-- rooms_some: a pak that holds two of the room levels. Each room is asked on its own: those two open.
pak({'Rooms','Xion_Rooms_D011.umap','Xion_Rooms_D158.umap'})
x=new()
rows_hidden,her_at,her_mode,pieces_asked,opens={},nil,1,0,0
warp_line='sboxionwarp=entered asks=8 life=1'
me=at(D.ARRIVALS.city)
pass(x,0.25)
assert(logged('sboxion: rooms: this pak holds 2 of 10 rooms: D011, D158') and pieces_asked==12 and hidden_rows()==12
    and times('sboxion: rooms: D')==2 and not logged('waits'),logs[#logs])
assert(select(2,x.status()):find('; rooms 2 of 2 open; threshold doors none in the pak; look [^;]+$'),
    select(2,x.status()))
opened=opens
me,world_gone={at={X=0,Y=0,Z=0},map=SB_XION},true
pass(x,0.25)
me,world_gone,rows_hidden=at(D.ARRIVALS.city),false,{}
pass(x,0.25)
assert(opens==opened and hidden_rows()==12 and times('this pak holds 2 of 10')==2,
    'The pak is asked once a room a Lua load')
x.stop()
pak('rooms')

-- full_pak: the full test pak lists 161 levels. The 34 of data.lua's VOLUMED load and show where SB's volumes say:
-- they are counted, never named as missing. Only the other 127 must read loaded and visible. 155 characters of SB's
-- spawn rows beside EVE are counted by class, the most first. Only the five nearest are named, with class and
-- distance. The pak of build3 holds every room of the list: the ten open.
pak(ROOMS3)
fresh()
levels={}
local needed={}
for _,room in ipairs(Rooms.LIST) do
    for _,name in ipairs(room.needs) do
        if not needed[name] then
            needed[name]=true
            levels[#levels+1]={name=name,loaded=true,visible=true}
        end
    end
end
for i=#levels+1,161-#D.VOLUMED do levels[i]={name='E04_Level_'..i,loaded=true,visible=true} end
for i,name in ipairs(D.VOLUMED) do levels[#levels+1]={name=name,loaded=i<=20,visible=i<=8} end
assert(#levels==161 and #D.VOLUMED==34)
local city=D.ARRIVALS.city
for i=1,155 do -- NPC_i stands i m east of the city point.
    names[#names+1]={name='NPC_'..i,class=i<=100 and 'N_CitizenMaleA_C' or i<=150 and 'N_XionGuardA_C' or 'N_Kaya_C',
        at={X=city.X+i*100,Y=city.Y,Z=city.Z}}
end
x=new()
rows_hidden,her_at,her_mode={},nil,1
warp_line='sboxionwarp=entered asks=9 life=1'
me=at(D.ARRIVALS.city)
pass(x,0.25)
assert(logged('sboxion: levels: 161 listed, 127 of 127 always-loaded ones loaded and visible, missing: none; by '
    ..'volume: 34 listed, 20 loaded, 8 visible'),logs[#logs])
local CROWD='sboxion: characters: 156 by class: N_CitizenMaleA_C 100, N_XionGuardA_C 50, N_Kaya_C 5, '
    ..'CH_P_EVE_01_Blueprint_C 1; nearest: NPC_1 (N_CitizenMaleA_C) 1.0 m, NPC_2 (N_CitizenMaleA_C) 2.0 m, NPC_3 '
    ..'(N_CitizenMaleA_C) 3.0 m, NPC_4 (N_CitizenMaleA_C) 4.0 m, NPC_5 (N_CitizenMaleA_C) 5.0 m'
assert(times(CROWD)==1 and not logged('NPC_6'),'Counted by class, the five nearest named')
-- doors_build3: of the threshold rooms that pak holds D039's alone.
assert(hidden_rows()==41 and select(2,x.status()):find('; rooms 10 of 10 open; threshold doors 1 in the pak, 0 opened; '
    ..'look [^;]+$'),select(2,x.status()))
assert(times('sboxion: threshold: this pak holds 1 of '..DOORS..' rooms: D039; opened: none')==1,'D039 is in that pak')
assert(logged('sboxion: rooms: this pak holds 10 of 10 rooms: D011, D031, D081, D107, D158, D009, D049, D092, D036, '
    ..'D106') and times('sboxion: rooms: D')==10,'Every room the pak holds opens')
-- eyes_arrival: the zone and area of the engine line and EVE's life state, once each.
assert(times('sboxion: zone: zonetype 5 area Zone_SBO_Xion')==1 and times('sboxion: life: 1')==1,logs[#logs])
-- eyes_second_look: 10 s after the arrival the levels line and the characters line again, whole. 10 s later nothing
-- changed, so the look says nothing.
pass(x,10)
assert(times('sboxion: levels: 161 listed')==2 and times(CROWD)==2,'The second look')
local said,looked,listed=#logs,calls.characters,calls.levels
pass(x,10)
assert(#logs==said and calls.characters==looked+1 and calls.levels==listed+1,
    'A look reads once and says nothing when nothing changed: '..logs[#logs])
-- eyes_change: a level streamed in by SB's volumes, an always-loaded one gone, two characters that spawned near EVE,
-- the zone of Xion's own volume and a dead EVE. The zone and the life state are said within a second, the rest at
-- the next look, once each.
local volumed,always
for _,l in ipairs(levels) do
    if l.name=='E04_Area05_A_LD' then volumed=l end
    if l.name=='E04_Level_100' then always=l end
end
assert(not volumed.visible and volumed.loaded and always.loaded,'E04_Area05_A_LD loaded and hidden at the start')
volumed.visible,always.loaded,always.visible=true,false,false
names[#names+1]={name='Lyle_1',class='N_Lyle_C',at={X=city.X+50,Y=city.Y,Z=city.Z}}
names[#names+1]={name='Lyle_2',class='N_Lyle_C',at={X=city.X,Y=city.Y+150,Z=city.Z}}
ENGINE=ENGINE:gsub('zonetype=5 area=Zone_SBO_Xion','zonetype=1 area=Zone_Xion_10')
warp_line='sboxionwarp=entered asks=9 life=3'
local respawned=#respawns
pass(x,1)
assert(times('sboxion: zone: zonetype 1 area Zone_Xion_10, EVE at (-8304, 7201, 225)')==1
    and times('sboxion: life: 3, EVE at (-8304, 7201, 225)')==1 and not logged('levels changed'),logs[#logs])
assert(logged('sboxion: recovery waits: zone Zone_Xion_10 type 1') and #respawns==respawned,'The recovery waits')
pass(x,9)
assert(times('sboxion: levels changed: E04_Level_100 loaded false visible false, E04_Area05_A_LD loaded true visible '
    ..'true; EVE at (-8304, 7201, 225)')==1,logs[#logs])
assert(times('sboxion: characters: 158 by class: N_CitizenMaleA_C 100, N_XionGuardA_C 50, N_Kaya_C 5, N_Lyle_C 2, '
    ..'CH_P_EVE_01_Blueprint_C 1; nearest: Lyle_1 (N_Lyle_C) 0.5 m, NPC_1 (N_CitizenMaleA_C) 1.0 m, Lyle_2 (N_Lyle_C) '
    ..'1.5 m, NPC_2 (N_CitizenMaleA_C) 2.0 m, NPC_3 (N_CitizenMaleA_C) 3.0 m')==1,logs[#logs])
-- eyes_status: the last look as the status line's last part.
ok,why=x.status()
assert(why:find('; rooms 10 of 10 open; threshold doors 1 in the pak, 0 opened; look %d+ s ago: 158 characters, '
    ..'nearest Lyle_1 %(N_Lyle_C%) 0%.5 m, levels '
    ..'126 of 127 always%-loaded, 20 of 34 by volume loaded, 9 visible, zonetype 1 area Zone_Xion_10, life 3$'),why)
-- eyes_quiet: nothing changes for 30 s, nothing more is said.
said=#logs
pass(x,30)
assert(#logs==said,'Said once: '..logs[#logs])
ENGINE=ENGINE:gsub('zonetype=1 area=Zone_Xion_10','zonetype=5 area=Zone_SBO_Xion')
x.stop()

-- tetrapod_door: the module's own wiring ticks the door (world/maps/sboxion/tetrapod.lua) after the recovery, with
-- the recovery's read of EVE, so a pass reads her once. Two passes in the doorway of the Tetrapod of the hangar ask
-- SB's black and two more put her inside. coop xion tetrapod says where she is and is refused out of SBO Xion. A map
-- change and the arrival after it drop a move that waits. The way in makes the ship solid and coop off puts it back.
x=new()
puts,her_at,her_mode={},nil,1
warp_line='sboxionwarp=entered asks=6 life=1'
me=at(D.ARRIVALS.city)
ok,why=x.tetrapod()
assert(not ok and why=='coop xion tetrapod: EVE is not in SBO Xion',why)
pass(x,0.25)
assert(logged('sboxion: tetrapod: door on: in at (16638, -24558, -1852), out at (-13413, 18383, 82)'),logs[#logs])
ok,why=x.tetrapod()
assert(ok and why=='coop xion tetrapod: EVE is outside the Tetrapod, door on',why)
local moves,blacks=calls.move,calls.black or 0
her_at={X=-13265,Y=19600,Z=347}
pass(x,0.5)
assert(calls.move==moves+2,'One engine read of EVE a pass: '..(calls.move-moves))
assert(calls.black==blacks+1 and #puts==0 and logged('sboxion: tetrapod: in asked (EVE stood 2 passes at (-13265, '
    ..'19600, 347)); black up in 0.3 s; EVE moves in 2 passes'),logs[#logs])
pass(x,0.5)
assert(#puts==1 and math.abs(puts[1].at.X-16637.5)<0.5 and math.abs(puts[1].at.Y+24557.9)<0.5
    and math.abs(puts[1].at.Z+1841.7)<0.1 and math.abs(puts[1].yaw+132.19)<0.01,'Inside, 10 cm over the point')
assert(#ships==1 and ships[1]==true,'The way in made the ship solid')
her_at=puts[1].at -- This file's put leaves her where she was since the fall right before the map change.
pass(x,0.25)
assert(logged('sboxion: tetrapod: in: EVE stands in the ship after 1 passes, 124 parts solid'),logs[#logs])
ok,why=x.tetrapod()
assert(ok and why=='coop xion tetrapod: EVE is inside the Tetrapod, door on',why)
ok,why=x.tetrapod('out')
assert(ok and why=='coop xion tetrapod: out: the move is asked' and calls.black==blacks+2,why)
me={at={X=0,Y=0,Z=0},map=SB_XION}
pass(x,1)
assert(#puts==1 and logged('sboxion: left, map'),'The door is not ticked in another map')
her_at=nil
me=at(D.ARRIVALS.city)
pass(x,1)
assert(#puts==1 and times('sboxion: tetrapod: door on')==2,'The next arrival dropped the move that waited')
-- coop off puts the ship back as SB ships it when the stay made it solid.
her_at={X=-13265,Y=19600,Z=347}
pass(x,1)
assert(#puts==2 and #ships==2 and ships[2]==true,'In again')
x.stop()
assert(#ships==3 and ships[3]==false and logged('sboxion: tetrapod: ship as SB ships it again: 124 parts'),logs[#logs])
her_at=nil

-- threshold_doors: a pak that holds every room of the list. The module's own wiring asks the pak for each threshold
-- room, ticks the doors after the Tetrapod's door with the recovery's read of EVE and hands them the engine's black
-- and move and the doors' own store.
local ROOMS6={table.unpack(ROOMS3)}
for _,room in ipairs(Threshold.LIST) do
    if room.name~='D039' then ROOMS6[#ROOMS6+1]=room.level..'.umap' end
end
pak(ROOMS6)
-- That pak lists each threshold room's level on Xion_P. The game loads and shows them with the map.
local listed={}
for _,room in ipairs(Threshold.LIST) do
    listed[room.name]={name=room.level,loaded=true,visible=true}
    levels[#levels+1]=listed[room.name]
end
x=new()
puts,ships,doors_kept,her_mode={},{},nil,1
world.put=function(to,yaw) puts[#puts+1]={at=to,yaw=yaw}; her_at,her_mode={X=to.X,Y=to.Y,Z=to.Z},1; return true end
me=at(D.ARRIVALS.city)
pass(x,0.25)
local held={}
for i,room in ipairs(Threshold.LIST) do held[i]=room.name end
assert(logged('sboxion: threshold: this pak holds '..DOORS..' of '..DOORS..' rooms: '..table.concat(held,', ')
    ..'; opened: none'),'Every threshold room is in this pak')
assert(select(2,x.status()):find('; threshold doors '..DOORS..' in the pak, 0 opened; look ',1,true),
    select(2,x.status()))
-- Each threshold room's street door is a waypoint: the status names the nearest one, here 3 m away.
for _,room in ipairs(Threshold.LIST) do
    me=at({X=room.street.X+300,Y=room.street.Y,Z=room.street.Z})
    assert(select(2,x.status()):find('nearest waypoint '..room.name..' 3.0 m; ',1,true),select(2,x.status()))
end
me=at(D.ARRIVALS.city)
-- EVE 60 cm in front of the first room's street door, turned toward it, 97 cm over the street.
local R=Threshold.LIST[1]
local function before(room,p,d,turn)
    her_at={X=p.X+d*room.cos,Y=p.Y+d*room.sin,Z=p.Z+97}
    her_yaw=(room.yaw+turn+180)%360-180
end
local function blacked() return calls.black or 0 end
-- The doors wait with the recovery: during a cutscene and while a death is handled a push counts nothing.
before(R,R.street,-60,0)
ENGINE=ENGINE:gsub('theater=none','theater=Cine_01')
pass(x,2)
assert(blacked()==0 and logged('sboxion: recovery waits: cutscene Cine_01'),'A cutscene: the doors wait')
ENGINE=ENGINE:gsub('theater=Cine_01','theater=none')
warp_line='sboxionwarp=entered asks=6 life=3'
pass(x,1.5)
assert(blacked()==0 and logged('sboxion: death: life 3, EVE at '),'A death: the doors wait')
her_at=nil
pass(x,3)
assert(blacked()==0 and logged('sboxion: respawn result: life 3/1'),'The death is over')
-- The module hands the doors the engine's streaming list: a room whose level does not show keeps its door shut.
listed[R.name].visible=false
before(R,R.street,-60,0)
pass(x,1)
assert(blacked()==0 and #puts==0 and doors_kept==nil and logged('sboxion: threshold: '..R.name
    ..' stays shut: its level '..R.level..' reads loaded true visible false'),logs[#logs])
listed[R.name].visible=true
her_at=nil
pass(x,0.25)
before(R,R.street,-60,0)
moves,blacks=calls.move,blacked()
pass(x,0.5)
assert(blacked()==blacks and #puts==0,'Two passes are no push')
pass(x,0.25)
assert(calls.move==moves+3,'One engine read of EVE a pass: '..(calls.move-moves))
assert(blacked()==blacks+1 and #puts==0 and logged('sboxion: threshold: '..R.name..' in asked (EVE pushed 3 passes '
    ..'at ') and logged('sboxion: threshold: '..R.name..' opened for good (kept in the door file)'),logs[#logs])
assert(doors_kept==R.name,'The opened door goes to the doors\' own store: '..tostring(doors_kept))
-- While a threshold door moves her the Tetrapod's command is refused and its door counts nothing: here the engine
-- reads her in the doorway of the Tetrapod for the two passes the move waits.
ok,why=x.tetrapod('in')
assert(not ok and why=='coop xion tetrapod: a threshold door is moving EVE' and blacked()==blacks+1,why)
her_at={X=-13265,Y=19600,Z=347}
pass(x,0.5)
assert(not logged('sboxion: tetrapod: in asked') and blacked()==blacks+1,'One door moves her at a time')
assert(#puts==1 and puts[1].at.X==R.inside.X and puts[1].at.Y==R.inside.Y
    and math.abs(puts[1].at.Z-(R.inside.Z+97+10))<0.01 and math.abs(puts[1].yaw-R.yaw)<0.01,
    'Inside, turned into the room')
pass(x,0.25)
assert(logged('sboxion: threshold: '..R.name..' in: EVE stands on the room floor after 1 passes'),logs[#logs])
assert(select(2,x.status()):find('; threshold doors '..DOORS..' in the pak, 1 opened; look ',1,true),
    select(2,x.status()))
ok,why=x.rooms()
assert(ok and why:find('; threshold doors '..DOORS..' in the pak, 1 opened$'),why)
-- coop xion rooms off turns the threshold doors off too. on turns them on again.
ok=x.rooms('off')
assert(ok and select(2,x.status()):find('; rooms off; threshold doors off; look ',1,true),select(2,x.status()))
before(R,R.inner,60,180)
blacks=blacked()
pass(x,2)
assert(blacked()==blacks and #puts==1,'Off: a push on the inner door does nothing')
ok=x.rooms('on')
pass(x,0.75)
assert(ok and blacked()==blacks+1 and logged('sboxion: threshold: '..R.name..' out asked'),'On again')
pass(x,0.5)
assert(#puts==2 and puts[2].at.X==R.outside.X and puts[2].at.Y==R.outside.Y,'Outside, in front of the street door')
pass(x,0.25)
assert(logged('sboxion: threshold: '..R.name..' out: EVE stands on the street after 1 passes'),logs[#logs])
-- While the Tetrapod's door moves her a push counts nothing: here its move waits two passes, is made and its watch
-- ends on the next pass, since this file's EVE is not in the ship.
before(R,R.street,-60,0)
ok=x.tetrapod('in')
blacks=blacked()
world.put=function(to,yaw) puts[#puts+1]={at=to,yaw=yaw}; return true end -- She stays at the door.
pass(x,0.75)
assert(ok and blacked()==blacks and #puts==3 and times('sboxion: threshold: '..R.name..' in asked')==1,
    'Three passes at the door count nothing while the Tetrapod\'s door moves her')
pass(x,0.75)
assert(blacked()==blacks+1 and times('sboxion: threshold: '..R.name..' in asked')==2,'Then they count')
-- coop off: the move that waits is not made.
x.stop()
pass(x,2)
assert(#puts==3,'Nothing after coop off')
-- A new Lua load reads the doors' own store: the door is opened still.
x=new()
her_at,her_yaw=nil,30
pass(x,0.25)
assert(logged('sboxion: threshold: this pak holds '..DOORS..' of '..DOORS..' rooms: '..table.concat(held,', ')
    ..'; opened: '..R.name),logs[#logs])
x.stop()
print('sboxion_world_test ok')
