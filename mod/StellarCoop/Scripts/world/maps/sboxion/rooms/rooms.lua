-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's rooms (world/maps/sboxion/sboxion.lua starts this part at each arrival and ticks it each 250 ms pass
-- while EVE's map is SBO Xion).
-- The zSBO_Xion test paks of 2026-11-24 add rooms behind closed doors of SB's Xion, each a level of its own that SBO
-- Xion's persistent level always loads: five in the paks of build2, eleven in the pak of build3. A room has an open
-- doorway of ours where SB's closed door unit and wall panel stand, with street debris in front. rooms/list.lua names
-- those pieces of SB for ten rooms, 41 rows. This part hides
-- them (world.piece, world.piece_out: world/maps/sboxion/engine.lua), so EVE walks in through the door with no
-- loading screen. It puts them back with world.piece_back. Nothing is hidden in any other map and SB's own Xion is
-- never changed: the pieces are objects of SBO Xion's world, which a map change destroys.
-- The pak: o.gate is asked for each room's level on its own, so a pak opens the rooms it holds. One log line an
-- arrival says how many. The pak of 2026-11-23 holds none: one log line an arrival, no level read, no piece asked. A
-- room the pak lacks is never looked at, waited for or counted.
-- Open: a room is decided once its own level and every sublevel of its rows read loaded and visible, looked at each
-- PACE passes. Its rows are all found first, each against its mesh and place. Then all are hidden. A row that is
-- not found, or cannot be hidden, closes the room as a whole: the rows hidden before it are put back and the log
-- names the row and the reason. A facade with one piece of SB left in it is worse than a closed door. The other
-- rooms open. A room whose levels are not there after WAIT looks is closed too.
-- Close: at a map change (coop xion leave ends in one), at coop off and at coop xion rooms off, each hidden row is
-- asked of the world once, the last hidden first. world.piece_back writes only on an object that is still the one
-- found, so after a map change, which destroyed the world with its levels, nothing is called.
-- coop xion rooms [on|off]: off puts every row back until on or the next arrival, for a look at SB's closed doors.
-- on opens the rooms again.
-- A Lua reload (Ctrl+R) forgets what it hid. The values read before each hide are kept in the store, one line. The
-- first pass of a Lua load puts those rows back, until the first one that is not found, so the pass that follows
-- reads SB's own values again. A store that raises stops nothing.
-- tests/lua/world/maps/sboxion/rooms/rooms_test.lua covers it.
local U=require('core.unreal')
local Rooms={}
Rooms.PACE,Rooms.WAIT=4,30 -- Passes between two looks at the levels (one look a second) and the looks a room waits.
-- The rooms: {name=, level=, umap=<its level's game path, for the pak gate>, needs=<its level, then each sublevel of
-- its rows>, rows=}. A row: {name=, level=, actor=, component=, index=, mesh=, at=, count=}, named
-- <sublevel>.<actor>.<component> with [<index>] for an instance.
Rooms.LIST={}
local ROW={} -- A row by its name.
for i,r in ipairs(require('world.maps.sboxion.rooms.list')) do
    local room,needed={name=r.name,level=r.level,umap='/Game/SBO_World/Rooms/'..r.level,needs={r.level},rows={}},{}
    for k,v in ipairs(r.rows) do
        local component=(v[4]<0 and 'StaticMeshComponent_' or 'HierarchicalInstancedStaticMeshComponent_')..v[3]
        local row={name=v[1]..'.'..v[2]..'.'..component..(v[4]<0 and '' or '['..v[4]..']'),level=v[1],actor=v[2],
            component=component,index=v[4],mesh=v[5],at={X=v[6],Y=v[7],Z=v[8]},count=v[9]}
        room.rows[k],ROW[row.name]=row,row
        if not needed[row.level] then
            needed[row.level]=true
            room.needs[#room.needs+1]=row.level
        end
    end
    Rooms.LIST[i]=room
end
local LIST=Rooms.LIST

-- o: log(m), world, the engine calls (world/maps/sboxion/engine.lua's levels, piece, piece_out and piece_back; a fake
-- in the tests), gate(umap) (true when the pak holds the room level of that game path, else nil and why) and store
-- (core/link.lua's store: save(line), load(), clear(); optional).
function Rooms.new(o)
    local log,world=o.log,o.world
    local store=o.store or {save=function() end,load=function() end,clear=function() end}
    local on,swept=true,false
    -- By room name while the pak holds the rooms: its pieces (a table) once open, the reason (a string) once closed,
    -- nil while it waits. nil as a whole: off, or a pak with no room.
    local state=nil
    local held={} -- The rooms the pak holds, in the list's order.
    local passes,looks,waited,unread,unkept=0,0,{},false,false -- Of the arrival.
    local self={}
    local function start()
        passes,looks,waited,unread,unkept=0,0,{},false,false
        held,state={},nil
        local why=nil -- Of the first room the pak lacks.
        for _,room in ipairs(LIST) do
            local ok,has,no=pcall(o.gate,room.umap)
            if ok and has then held[#held+1]=room
            else why=why or (ok and tostring(no) or U.why(has)) end
        end
        if #held==0 then
            log('rooms: none in this pak ('..why..'): no door is opened')
            return
        end
        state={}
        local names={}
        for i,room in ipairs(held) do names[i]=room.name end
        log(string.format('rooms: this pak holds %d of %d rooms: %s',#held,#LIST,table.concat(names,', ')))
    end
    -- A room's rows all found, then all hidden: its pieces. Else nil and why, with nothing of it left hidden.
    local function open(room)
        local pieces={}
        for k,row in ipairs(room.rows) do
            local ok,p=pcall(world.piece,row)
            if not ok then return nil,row.name..': '..U.why(p) end
            pieces[k]=p
        end
        for k,p in ipairs(pieces) do
            local ok,why=pcall(world.piece_out,p)
            if not ok then
                for j=k,1,-1 do pcall(world.piece_back,pieces[j]) end -- From k: a hide can raise halfway.
                return nil,p.row.name..': '..U.why(why)
            end
        end
        return pieces
    end
    -- The store's line: <row name>=<the numbers read before the hide> for every hidden row, tab-separated. Nine
    -- digits give a float back as it was.
    local function keep()
        local entries={}
        for _,room in ipairs(LIST) do
            local pieces=state[room.name]
            for _,p in ipairs(type(pieces)=='table' and pieces or {}) do
                local words={}
                for i,n in ipairs(p.was) do words[i]=string.format('%.9g',n) end
                entries[#entries+1]=p.row.name..'='..table.concat(words,',')
            end
        end
        local ok,why=pcall(store.save,table.concat(entries,'\t'))
        if ok or unkept then return end
        unkept=true
        log('rooms: rows not kept ('..U.why(why)..'): a Lua reload could not put them back')
    end
    -- An earlier Lua load's hidden rows, by the line it kept.
    local function sweep()
        swept=true
        local ok,line=pcall(store.load)
        if not ok then
            log('rooms: an earlier Lua load\'s rows unread ('..U.why(line)..'): none put back')
            return
        end
        if not line then return end
        local left,back,found=0,0,true
        for entry in line:gmatch('[^\t]+') do
            left=left+1
            local row,was=ROW[entry:match('^(.-)=') or ''],{}
            for word in (entry:match('=(.*)$') or ''):gmatch('[^,]+') do was[#was+1]=tonumber(word) or false end
            local whole=#was==(row and row.index<0 and 2 or 10)
            for _,n in ipairs(was) do whole=whole and n end
            if row and whole and found then
                local put,done=pcall(function()
                    local p=world.piece(row)
                    p.was=was
                    return world.piece_back(p)
                end)
                found=put -- No piece at the row: the world that held them is gone.
                if put and done then back=back+1 end
            end
        end
        pcall(store.clear)
        log(string.format('rooms: an earlier Lua load left %d rows hidden: %d put back',left,back))
    end
    -- One look at the levels: each waiting room whose levels are there is opened or closed.
    local function look()
        looks=looks+1
        local seen={}
        for _,l in ipairs(world.levels()) do seen[l.name]=l.loaded and l.visible end
        local opened=false
        for _,room in ipairs(held) do
            local missing={}
            for _,name in ipairs(room.needs) do
                if not seen[name] then missing[#missing+1]=name end
            end
            if state[room.name]~=nil then -- Decided.
            elseif #missing==0 then
                local started=os.clock()
                local pieces,why=open(room)
                state[room.name],opened=pieces or why,opened or pieces~=nil
                log(pieces and string.format('rooms: %s open: %d rows hidden, %.0f ms',room.name,#pieces,
                    (os.clock()-started)*1000) or 'rooms: '..room.name..' closed: '..why)
            elseif looks>=Rooms.WAIT then
                state[room.name]=table.concat(missing,', ')..' not loaded and visible after '..Rooms.WAIT..' s'
                log('rooms: '..room.name..' closed: '..state[room.name])
            elseif not waited[room.name] then
                waited[room.name]=true
                log('rooms: '..room.name..' waits for '..table.concat(missing,', '))
            end
        end
        if opened then keep() end
    end
    local function pass()
        if not swept then sweep() end
        local waiting=false
        for _,room in ipairs(held) do waiting=waiting or state~=nil and state[room.name]==nil end
        if not waiting then return end
        passes=passes+1
        if (passes-1)%Rooms.PACE==0 then look() end
    end
    -- Each 250 ms pass while EVE's map is SBO Xion: the sweep once, then a look each PACE passes while a room waits.
    function self.tick()
        local ok,e=pcall(pass)
        if ok or unread then return end
        unread=true
        log('rooms: levels unread ('..U.why(e)..'): the rooms wait')
    end
    -- Every hidden row put back (reason: for the log). With no room open it says nothing.
    function self.close(reason)
        if not state then return end
        local back,gone,raised,why=0,0,0,nil
        for i=#LIST,1,-1 do
            local pieces=state[LIST[i].name]
            for k=type(pieces)=='table' and #pieces or 0,1,-1 do
                local ok,done=pcall(world.piece_back,pieces[k])
                if not ok then raised,why=raised+1,why or U.why(done)
                elseif done then back=back+1
                else gone=gone+1 end
            end
        end
        state=nil
        pcall(store.clear)
        if back+gone+raised==0 then return end
        log(string.format('rooms: closed (%s): %d rows put back%s%s',reason,back,
            gone>0 and ', '..gone..' gone already' or '',raised>0 and ', '..raised..' raised ('..why..')' or ''))
    end
    -- Each arrival in SBO Xion: on, with the pak asked and every room waiting. Rows still hidden are put back first.
    function self.arrive()
        self.close('an arrival')
        on=true
        start()
    end
    -- One part of coop xion status.
    function self.status()
        if not on then return 'rooms off' end
        if not state then return 'rooms none in the pak' end
        local open_ones,waiting,closed=0,0,{}
        for _,room in ipairs(held) do
            local s=state[room.name]
            if type(s)=='table' then open_ones=open_ones+1
            elseif s then closed[#closed+1]=room.name
            else waiting=waiting+1 end
        end
        return string.format('rooms %d of %d open',open_ones,#held)..(waiting>0 and ', '..waiting..' waiting' or '')
            ..(#closed>0 and ', closed: '..table.concat(closed,', ') or '')
    end
    -- coop xion rooms [on|off]: off puts every row back until on or the next arrival. on asks the pak and opens the
    -- rooms again. With no word, or on while on: the status part.
    function self.switch(word)
        if word==nil then return true,self.status() end
        if word=='off' then
            on=false
            self.close('coop xion rooms off')
            return true,'rooms off until coop xion rooms on or the next arrival'
        end
        if word~='on' then return false,'Use: coop xion rooms [on|off]' end
        if on then return true,self.status() end
        on=true
        start()
        return true,state and 'rooms on: '..#held..' to open ([SX] lines follow)' or self.status()
    end
    return self
end
return Rooms
