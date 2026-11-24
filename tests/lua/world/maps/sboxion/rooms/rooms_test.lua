-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's rooms (world/maps/sboxion/rooms/rooms.lua) over a fake store and a fake world that lists levels and
-- finds, hides and puts back pieces. The list: ten rooms with their rows named by sublevel, actor, component and instance,
-- the levels each needs and the game path the pak gate is asked for, one room at a time. A pak without the rooms: one
-- log line an arrival, no level read, no piece asked. With the rooms, one line an arrival says how many the pak holds.
-- With every level loaded and visible the arrival's first pass checks the rows of a room, hides them all and logs the
-- room open, for each room the pak holds, then reads no level again. A room the pak lacks is never looked at, waited
-- for or counted in the status. A gate that raises for one room leaves that room out. A room whose own level or one of
-- its rows' sublevels is not loaded and visible waits: said once, looked at every fourth pass, opened when the level
-- shows and closed after 30 looks. A row that is not found closes its room before anything of it is hidden. A row that
-- cannot be hidden closes its room with the rows hidden before it put back, the failed one included. The other rooms
-- open. Close: every hidden row asked back once in reverse order, counted as put back, gone already or raised, the
-- store cleared. coop xion rooms: off puts everything back and stays off, on opens again, on while on changes nothing,
-- another word gets the use line. An arrival closes what is open and sets off back to on. The store: the kept values of
-- every hidden row in one line; the first pass of a Lua load puts back what an earlier load kept, until the first row
-- that is not found; a load or a save that raises is logged and stops nothing. A level read that raises is logged once
-- and the rooms wait.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=50
os.clock=function() return clock end
package.loaded.UEHelpers={}
local Rooms=require('world.maps.sboxion.rooms.rooms')
local LIST=Rooms.LIST
assert(#LIST==10 and Rooms.PACE==4 and Rooms.WAIT==30)
for _,room in ipairs(LIST) do
    assert(room.umap=='/Game/SBO_World/Rooms/Xion_Rooms_'..room.name,'The game path the pak gate is asked for')
end
local D011,D031,D158=LIST[1],LIST[2],LIST[5]
assert(D011.name=='D011' and D011.level=='Xion_Rooms_D011' and #D011.rows==4)
assert(table.concat(D011.needs,' ')=='Xion_Rooms_D011 E04_Area02_Architecture_A_02 E04_Area02_Object_A_02',
    'A room needs its own level and each sublevel of its rows once')
local door,panel=D011.rows[1],D011.rows[2]
assert(door.name=='E04_Area02_Architecture_A_02.Actor_0.StaticMeshComponent_3' and door.index==-1
    and door.component=='StaticMeshComponent_3' and door.level=='E04_Area02_Architecture_A_02'
    and door.actor=='Actor_0' and door.mesh=='Architecture/Door/031_A_SM' and door.at.X==692.966
    and door.at.Y==113.135 and door.at.Z==-549.798 and door.count==nil,'A whole component\'s row')
assert(panel.name=='E04_Area02_Architecture_A_02.Actor_0.HierarchicalInstancedStaticMeshComponent_0[1]'
    and panel.component=='HierarchicalInstancedStaticMeshComponent_0' and panel.index==1 and panel.count==2,
    'An instance\'s row')
local names,total={},0
for _,room in ipairs(LIST) do
    for _,r in ipairs(room.rows) do
        assert(not names[r.name],r.name..' twice')
        names[r.name],total=true,total+1
    end
end
assert(total==41)
local FIVE={} -- The game paths of the five rooms the paks of 24 November hold.
for i=1,5 do FIVE[LIST[i].umap]=true end

-- The fake world. hidden: the rows hidden now, by name. order: each call. A row of missing is not found, a row of
-- stuck cannot be hidden (the engine's piece_out sets was before it raises).
local logs,order,hidden,missing,stuck,levels,reads={},{},{},{},{},{},0
local alive,level_error,back_error=true,nil,nil
local function was_of(row)
    return row.index<0 and {1,3} or {0,0,0.6,0.8,row.at.X,row.at.Y,row.at.Z,1.5837991,1.227,0.481}
end
local world={
    levels=function()
        reads=reads+1
        if level_error then error(level_error) end
        return levels
    end,
    piece=function(row)
        order[#order+1]='piece '..row.name
        if missing[row.name] then error(missing[row.name]) end
        return {row=row}
    end,
    piece_out=function(p)
        order[#order+1]='out '..p.row.name
        p.was=was_of(p.row)
        if stuck[p.row.name] then error(stuck[p.row.name]) end
        hidden[p.row.name]=true
    end,
    piece_back=function(p)
        order[#order+1]='back '..p.row.name
        if back_error then error(back_error) end
        if not alive or not p.was then return false end
        hidden[p.row.name]=nil
        return true
    end,
}
local stored,saves,clears=nil,0,0
local store={save=function(line) stored=line; saves=saves+1 end,load=function() return stored end,
    clear=function() stored=nil; clears=clears+1 end}
local held,none,asked=FIVE,nil,{} -- held: true for every room, or the game paths the pak holds. asked: each ask.
local function all_levels(without)
    local list={{name='E04_ENV',loaded=true,visible=true}}
    for _,room in ipairs(LIST) do
        for _,name in ipairs(room.needs) do
            list[#list+1]={name=name,loaded=true,visible=name~=without}
        end
    end
    return list
end
local function fresh(with_store)
    logs,order,hidden,missing,stuck,levels,reads={},{},{},{},{},all_levels(),0
    alive,level_error,back_error,held,none,asked=true,nil,nil,FIVE,nil,{}
    stored,saves,clears=nil,0,0
    return Rooms.new({log=function(m) logs[#logs+1]=m end,world=world,gate=function(umap)
        asked[#asked+1]=umap
        if held==true or type(held)=='table' and held[umap] then return true end
        return nil,none
    end,store=with_store~=false and store or nil})
end
local function said(text)
    for _,l in ipairs(logs) do if l:find(text,1,true) then return l end end
end
local function count(text)
    local n=0
    for _,l in ipairs(order) do if l:find(text,1,true)==1 then n=n+1 end end
    return n
end
local function size(t) local n=0 for _ in pairs(t) do n=n+1 end return n end
local function ticks(r,n) for _=1,n do r.tick() end end

-- no_rooms: a pak that holds no room level gets one line an arrival and nothing else.
local r=fresh()
held,none=nil,'C:\\SB\\Content\\Paks\\~mods\\zSBO_Xion.utoc does not hold Rooms'
r.arrive()
ticks(r,8)
assert(#logs==1 and logs[1]=='rooms: none in this pak (C:\\SB\\Content\\Paks\\~mods\\zSBO_Xion.utoc does not hold '
    ..'Rooms): no door is opened',logs[1])
assert(reads==0 and #order==0 and saves==0,'No level read, no piece asked')
assert(r.status()=='rooms none in the pak')
r.close('coop off')
assert(#logs==1 and #order==0,'Nothing to put back')
local ok,line=r.switch('on')
assert(ok and line=='rooms none in the pak' and #logs==1,'on while on asks the gate no second time')
-- A gate that raises is a pak with no room.
r=fresh()
r=Rooms.new({log=function(m) logs[#logs+1]=m end,world=world,gate=function() error('the folder does not read') end})
r.arrive()
assert(#logs==1 and logs[1]=='rooms: none in this pak (the folder does not read): no door is opened',logs[1])

-- open_all: with a pak of 24 November the first pass of an arrival opens its five rooms, each row checked before any
-- of its room is hidden. The five rooms it lacks are asked of the pak only.
r=fresh()
r.arrive()
assert(#logs==1 and logs[1]=='rooms: this pak holds 5 of 10 rooms: D011, D031, D081, D107, D158' and #order==0,
    'An arrival with the rooms in the pak says so and waits for the pass')
assert(#asked==10 and asked[1]==D011.umap and asked[10]==LIST[10].umap,'Each room asked on its own')
r.tick()
assert(reads==1 and count('piece ')==23 and count('out ')==23 and size(hidden)==23)
assert(order[1]=='piece '..D011.rows[1].name and order[4]=='piece '..D011.rows[4].name
    and order[5]=='out '..D011.rows[1].name and order[8]=='out '..D011.rows[4].name
    and order[9]=='piece '..D031.rows[1].name,'A room\'s rows are all found before one is hidden')
assert(#logs==6 and logs[2]=='rooms: D011 open: 4 rows hidden, 0 ms'
    and logs[6]=='rooms: D158 open: 8 rows hidden, 0 ms',logs[2])
assert(r.status()=='rooms 5 of 5 open')
ticks(r,20)
assert(reads==1 and #order==46,'With every room decided no level is read again')
-- kept: one line, a row's name and what was read before it was hidden, numbers that read back as the same floats.
assert(saves==1 and select(2,stored:gsub('\t',''))==22,'The 23 rows in one line')
assert(stored:find(door.name..'=1,3\t',1,true)==1,stored:sub(1,80))
assert(stored:find('\t'..panel.name..'=0,0,0.6,0.8,539.729,45.778,-515.988,1.5837991,1.227,0.481\t',1,true),
    'An instance\'s ten numbers')
assert(string.format('%.9g',string.unpack('f',string.pack('f',0.6)))=='0.600000024','Nine digits give a float back')

-- close: every row asked back once, the last hidden first, and the store cleared.
r.close('coop off')
assert(count('back ')==23 and size(hidden)==0 and clears==1 and stored==nil)
assert(order[47]=='back '..D158.rows[8].name and order[69]=='back '..D011.rows[1].name,'In reverse order')
assert(logs[7]=='rooms: closed (coop off): 23 rows put back',logs[7])
r.close('coop off')
assert(#logs==7 and count('back ')==23,'Nothing is asked twice')
-- close_gone: a world that is gone took its rows. Nothing is called on them and nothing is said to be put back.
r=fresh()
r.arrive()
r.tick()
alive=false
r.close('a map change')
assert(logs[7]=='rooms: closed (a map change): 0 rows put back, 23 gone already' and clears==1,logs[7])
-- close_raises: a put-back that raises is counted with its reason and stops no other.
r=fresh()
r.arrive()
r.tick()
back_error='SetVisibility: no such function'
r.close('coop off')
assert(count('back ')==23 and logs[7]=='rooms: closed (coop off): 0 rows put back, 23 raised (SetVisibility: no such '
    ..'function)',logs[7])

-- wait_room_level: a room whose own level is not shown waits, looked at every fourth pass. The others open.
r=fresh()
levels=all_levels('Xion_Rooms_D031')
r.arrive()
r.tick()
assert(#logs==6 and logs[3]=='rooms: D031 waits for Xion_Rooms_D031' and size(hidden)==19,logs[3])
assert(count('piece '..D031.rows[1].name)==0,'No row of a waiting room is asked')
assert(r.status()=='rooms 4 of 5 open, 1 waiting')
ticks(r,3)
assert(reads==1,'No look in the three passes between')
r.tick()
assert(reads==2 and #logs==6,'A look a second, the wait said once')
levels=all_levels()
ticks(r,4)
assert(reads==3 and logs[7]=='rooms: D031 open: 4 rows hidden, 0 ms' and size(hidden)==23 and saves==2,logs[7])
assert(select(2,stored:gsub('\t',''))==22 and r.status()=='rooms 5 of 5 open','The line holds the late room too')
-- wait_sublevel: the same for a sublevel one of its rows is in. Two rooms have rows in E04_Area02_Object_B_02.
r=fresh()
levels=all_levels('E04_Area02_Object_B_02')
r.arrive()
r.tick()
assert(said('rooms: D031 waits for E04_Area02_Object_B_02') and said('rooms: D081 waits for E04_Area02_Object_B_02')
    and size(hidden)==15 and r.status()=='rooms 3 of 5 open, 2 waiting')
-- wait_ends: after 30 looks the room is closed with the levels it waited for.
ticks(r,4*28)
assert(reads==29 and r.status()=='rooms 3 of 5 open, 2 waiting')
ticks(r,4)
assert(reads==30 and said('rooms: D031 closed: E04_Area02_Object_B_02 not loaded and visible after 30 s')
    and said('rooms: D081 closed: E04_Area02_Object_B_02 not loaded and visible after 30 s'))
assert(r.status()=='rooms 3 of 5 open, closed: D031, D081')
ticks(r,40)
assert(reads==30 and size(hidden)==15,'A closed room is not looked at again')
-- A level that is loaded and not visible, or listed nowhere, is not there.
r=fresh()
levels=all_levels()
for _,l in ipairs(levels) do if l.name=='Xion_Rooms_D158' then l.loaded,l.visible=false,false end end
table.remove(levels,2) -- Xion_Rooms_D011
r.arrive()
r.tick()
assert(said('rooms: D011 waits for Xion_Rooms_D011') and said('rooms: D158 waits for Xion_Rooms_D158'))

-- row_not_found: the room stays closed as a whole, with nothing of it hidden. The other rooms open.
r=fresh()
missing[D031.rows[3].name]='not found'
r.arrive()
r.tick()
assert(said('rooms: D031 closed: '..D031.rows[3].name..': not found'),logs[3])
assert(count('out E04_Area02_Architecture_A_01.Actor_3')==0 and count('out E04_Area02_Object_B_02.Actor_2')==0
    and size(hidden)==19,'No row of the room is hidden')
assert(count('piece '..D031.rows[4].name)==0,'The first row that fails ends the check')
assert(r.status()=='rooms 4 of 5 open, closed: D031')
assert(not stored:find(D031.rows[1].name,1,true),'A closed room keeps nothing')
ticks(r,12)
assert(reads==1,'A closed room is decided')
-- row_not_hidden: the rows hidden before it are put back, the failed one too (a hide can raise halfway).
r=fresh()
stuck[D158.rows[3].name]='it did not hide'
r.arrive()
r.tick()
assert(said('rooms: D158 closed: '..D158.rows[3].name..': it did not hide'))
local n=#order
assert(order[n-2]=='back '..D158.rows[3].name and order[n-1]=='back '..D158.rows[2].name
    and order[n]=='back '..D158.rows[1].name and count('out E04_Area02_Object_F_01')==3,'Three hidden, three back')
assert(size(hidden)==15 and r.status()=='rooms 4 of 5 open, closed: D158')
r.close('coop off')
assert(said('rooms: closed (coop off): 15 rows put back'))

-- switch: off puts everything back and stays off; on opens again; on while on changes nothing.
r=fresh()
r.arrive()
r.tick()
ok,line=r.switch()
assert(ok and line=='rooms 5 of 5 open')
ok,line=r.switch('off')
assert(ok and line=='rooms off until coop xion rooms on or the next arrival' and size(hidden)==0)
assert(said('rooms: closed (coop xion rooms off): 23 rows put back') and r.status()=='rooms off')
ticks(r,8)
assert(reads==1 and size(hidden)==0,'Off stays off')
ok,line=r.switch('off')
assert(ok and count('back ')==23,'Off again puts nothing back twice')
ok,line=r.switch('on')
assert(ok and line=='rooms on: 5 to open ([SX] lines follow)' and size(hidden)==0)
r.tick()
assert(reads==2 and size(hidden)==23 and r.status()=='rooms 5 of 5 open')
ok,line=r.switch('on')
assert(ok and line=='rooms 5 of 5 open' and count('out ')==46,'On while on hides nothing again')
ok,line=r.switch('up')
assert(not ok and line=='Use: coop xion rooms [on|off]')
-- arrive: an arrival puts back what is still hidden and sets off back to on.
r.switch('off')
r.arrive()
r.tick()
assert(r.status()=='rooms 5 of 5 open' and size(hidden)==23)
r.arrive()
assert(said('rooms: closed (an arrival): 23 rows put back') and size(hidden)==0)

-- sweep: the first pass of a Lua load puts back what an earlier load kept, then the rooms open as on any arrival.
r=fresh()
r.arrive()
r.tick()
local kept=stored
r=Rooms.new({log=function(m) logs[#logs+1]=m end,world=world,gate=function(umap) return FIVE[umap] end,store=store})
logs,order,reads={},{},0
r.arrive()
r.tick()
assert(logs[2]=='rooms: an earlier Lua load left 23 rows hidden: 23 put back',logs[2])
assert(order[1]=='piece '..door.name and order[2]=='back '..door.name and count('back ')==23,order[2])
assert(count('out ')==23 and size(hidden)==23 and r.status()=='rooms 5 of 5 open','Then hidden again by this load')
r.tick()
assert(count('back ')==23,'Swept once a Lua load')
-- sweep_values: a row gets back the numbers the line holds for it.
local got={}
local back=world.piece_back
world.piece_back=function(p) got[p.row.name]=p.was; return back(p) end
stored=kept
r=Rooms.new({log=function(m) logs[#logs+1]=m end,world=world,gate=function() return nil,'no pak' end,store=store})
r.tick()
world.piece_back=back
assert(#got[door.name]==2 and got[door.name][1]==1 and got[door.name][2]==3)
local p=got[panel.name]
assert(#p==10 and p[3]==0.6 and p[5]==539.729 and p[8]==1.5837991 and p[10]==0.481,'The ten numbers of an instance')
assert(stored==nil,'The line is cleared once it is read')
-- sweep_gone: the first row that is not found ends it (the world that held them is gone). Entries that name no row
-- or hold another count of numbers are passed over.
stored='nope=1,3\t'..door.name..'=1\t'..door.name..'=1,x\t'..door.name..'=1,3\t'..panel.name..'=1,3\t'..kept
missing[D011.rows[3].name]='not found'
logs,order={},{}
r=Rooms.new({log=function(m) logs[#logs+1]=m end,world=world,gate=function() return nil,'no pak' end,store=store})
r.tick()
assert(logs[1]=='rooms: an earlier Lua load left 28 rows hidden: 3 put back' and count('back ')==3,logs[1])
assert(count('piece ')==4 and order[#order]=='piece '..D011.rows[3].name,'Nothing is asked after the first miss')
-- sweep_unread: a load that raises is logged and nothing is put back. A save that raises is logged once.
r=fresh()
store.load=function() error('the file is locked') end
store.save=function() saves=saves+1; error('the disk is full') end
levels=all_levels('Xion_Rooms_D107')
r.arrive()
r.tick()
assert(logs[2]=='rooms: an earlier Lua load\'s rows unread (the file is locked): none put back',logs[2])
assert(said('rooms: rows not kept (the disk is full): a Lua reload could not put them back') and size(hidden)==20)
levels=all_levels()
ticks(r,4)
assert(saves==2 and size(hidden)==23 and #logs==9,'Said once: '..#logs)
store.load=function() return stored end
store.save=function(text) stored=text; saves=saves+1 end
-- no_store: without a store the rooms open and close all the same.
r=fresh(false)
r.arrive()
r.tick()
r.close('coop off')
assert(size(hidden)==0 and said('rooms: closed (coop off): 23 rows put back') and saves==0)

-- levels_raise: a level read that raises (no EVE for a pass) is logged once and the rooms wait for the next look.
r=fresh()
level_error='no EVE in the world'
r.arrive()
ticks(r,5)
assert(reads==2 and #logs==2 and logs[2]=='rooms: levels unread (no EVE in the world): the rooms wait',logs[2])
assert(r.status()=='rooms 0 of 5 open, 5 waiting')
level_error=nil
ticks(r,4)
assert(size(hidden)==23 and r.status()=='rooms 5 of 5 open')

-- some_rooms: a pak that holds two of the rooms. The line names them. Only they are looked at and opened. The others
-- are never waited for, closed or counted.
r=fresh()
held={[D011.umap]=true,[D158.umap]=true}
r.arrive()
assert(#logs==1 and logs[1]=='rooms: this pak holds 2 of 10 rooms: D011, D158',logs[1])
r.tick()
assert(count('piece ')==12 and size(hidden)==12 and #logs==3 and logs[3]=='rooms: D158 open: 8 rows hidden, 0 ms')
assert(not said('waits') and r.status()=='rooms 2 of 2 open',r.status())
ticks(r,4*31)
assert(reads==1 and not said('closed'),'No look while every room the pak holds is decided')
r.close('coop off')
assert(said('rooms: closed (coop off): 12 rows put back'))
ok,line=r.switch('off')
ok,line=r.switch('on')
assert(ok and line=='rooms on: 2 to open ([SX] lines follow)',line)
-- A room whose ask raises is left out. The others open.
r=fresh()
r=Rooms.new({log=function(m) logs[#logs+1]=m end,world=world,gate=function(umap)
    if umap==D031.umap then error('the .utoc does not read') end
    return FIVE[umap]
end})
r.arrive()
assert(logs[1]=='rooms: this pak holds 4 of 10 rooms: D011, D081, D107, D158',logs[1])
r.tick()
assert(size(hidden)==19 and r.status()=='rooms 4 of 4 open',r.status())
-- No room in the pak: the reason of the first room asked.
r=fresh()
held={}
none='no Xion_Rooms_D011.umap'
r.arrive()
assert(#logs==1 and logs[1]=='rooms: none in this pak (no Xion_Rooms_D011.umap): no door is opened',logs[1])
assert(#asked==10,'Each room is asked')

-- all_rooms: the pak of build3 holds the ten. Each opens. D036 and D158 hide other instances of one component.
r=fresh()
held=true
r.arrive()
assert(logs[1]=='rooms: this pak holds 10 of 10 rooms: D011, D031, D081, D107, D158, D009, D049, D092, D036, D106',
    logs[1])
r.tick()
assert(reads==1 and count('piece ')==41 and size(hidden)==41 and #logs==11,#logs)
assert(logs[7]=='rooms: D009 open: 4 rows hidden, 0 ms' and logs[8]=='rooms: D049 open: 5 rows hidden, 0 ms'
    and logs[9]=='rooms: D092 open: 2 rows hidden, 0 ms' and logs[10]=='rooms: D036 open: 3 rows hidden, 0 ms'
    and logs[11]=='rooms: D106 open: 4 rows hidden, 0 ms',logs[11])
local F34='E04_Area02_Object_F_01.Actor_0.HierarchicalInstancedStaticMeshComponent_34'
assert(hidden[F34..'[6]'] and hidden[F34..'[3]'],'One component, two rooms')
assert(r.status()=='rooms 10 of 10 open' and select(2,stored:gsub('\t',''))==40,r.status())
r.close('coop off')
assert(logs[12]=='rooms: closed (coop off): 41 rows put back' and size(hidden)==0,logs[12])
print('sboxion_rooms_test ok')
