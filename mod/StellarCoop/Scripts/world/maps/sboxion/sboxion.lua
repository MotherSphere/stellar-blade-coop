-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion (a test tool, experimental, left out of the usage line): a world of SBO's own whose persistent level
-- /Game/SBO_World/Xion_P streams sublevels of SB's Xion from the player's own game files: the look-only ones. With
-- the full test pak of 2026-11-24 it streams the level-design ones too, as SB ships them. The level is in the
-- zSBO_Xion test pak, built outside the mod and never shipped with it. SB's world row Xion, its zones and its
-- sublevels are not touched: story mode and online sessions keep SB's Xion.
-- The pak gate (core/pak_gate.lua), once a Lua load: the container's .utoc must name SBO_World and Xion_P.umap, with
-- its .pak and .ucas beside it. With no pak nothing is asked and nothing is said: most players have none.
-- The rows (native/src/world/maps/sboxion/sboxion_rows.h's sboxion batch, world/maps/sboxion/data.lua): one world row
-- and one type-5 zone row, asked at the title while the game uses the co-op save files (core/enemy.lua's title_batch,
-- from main/pass.lua), then read back. A refusal is logged once a Lua load.
-- coop xion [city|gate]: on a co-op save, solo, with the pak and the rows in, the request "sboxion enter <zone FName
-- index> <x> <y> <z> <yaw>" for the native part (native/src/world/maps/sboxion/sboxion.h), which runs its guards and
-- SB's URL warp in one frame and puts EVE at one of data.lua's two points. The zone is of type 5 (Boss Challenge): SB
-- keeps it as the arrival's zone with no zone volume in the level. SB's in-game save queues nothing in it. EVE inside
-- is the EVE SB builds for a Boss Challenge zone, from the newest save of the list.
-- Arrival, once a load of SBO Xion: the day table (41 bActiveVolume values of E04_ENV_VOL's volumes, matched by level
-- and name), read back 2 s and 10 s later, the streaming levels' state (the always-loaded ones apart from the volume
-- streamed ones of data.lua's VOLUMED), the two probe levels' state, the characters counted by class with the five
-- nearest to EVE, the zone and area of the status text's engine line and EVE's life state of its sboxionwarp line,
-- each as a log line a test reads. The levels and the characters again 10 s later. While EVE stays, once a second:
-- each change of the two probe levels, of the zone and area and of her life state. It logs each waypoint she
-- stands at. Then every LOOK s a look: the characters line again when the count by class or the five nearest
-- changed. It also logs the levels whose loaded or visible state changed since the look before. Nothing is read in
-- any other map.
-- The full test pak of 2026-11-24 loads SB's level-design sublevels as SB ships them: these lines are its test's eyes
-- (what wakes up in Zone_SBO_Xion and whether the zone changes).
-- Falls and deaths, each pass of the stay (world/maps/sboxion/recover.lua): the paks of 2026-11-23 and of the rooms
-- have none of SB's fall volumes. The full test pak's city ones act in Zone_Xion_10 by their rows. So EVE under
-- data.lua's FLOOR is put back on the last place she walked on, or on the arrival point of this stay.
-- SB's death screen cannot respawn her in this zone, so a dead EVE gets SB's in-place respawn.
-- The rooms, each pass of the stay (world/maps/sboxion/rooms/rooms.lua): the test paks of 2026-11-24 add five or eleven
-- rooms behind closed doors of SB's Xion, each a level of the persistent level. The pak gate is asked once a Lua load
-- for each room's level beside Xion_P. Each arrival hides the pieces of SB in the doorway of each room the pak holds
-- once the room's levels are loaded and visible, all rows of a room or none. A map change, coop off and coop xion rooms
-- off put them back. The pak of 2026-11-23 holds no room: one log line an arrival and nothing else.
-- coop xion leave: the request "sboxion leave <zone FName index>". The native part compares the zone with the
-- client's and calls SB's reload of the co-op save only from SBO Xion, so the request is sent from any map.
-- coop xion status: the pak, the rows, the native part's last answer, EVE's place, the nearest waypoint, the
-- recovery's state, the rooms' state and the last look.
-- coop xion recover [on|death|off], inside SBO Xion: the recovery's mode until the next arrival, which sets it to on.
-- death leaves falls alone, so EVE can die of one on purpose. off does nothing, as before the recovery existed.
-- coop xion rooms [on|off], inside SBO Xion: off puts SB's pieces back in the doorways until on or the next
-- arrival, so a test sees SB's closed doors again. Alone, it prints the rooms' state.
-- The Tetrapod's door, each pass of the stay (world/maps/sboxion/tetrapod.lua): EVE standing in the doorway of the
-- Tetrapod of the hangar is put inside SB's own Tetrapod interior, 540 m away, and standing at its right door she is
-- put back in front of the ship. SB ships that interior with no collision: the way in makes its parts solid and the
-- way out and coop off put them back. coop xion tetrapod [in|out], inside SBO Xion, asks the same move from
-- anywhere. Alone, it says whether she is inside.
-- The threshold doors, each pass of the stay (world/maps/sboxion/rooms/threshold.lua): a threshold room of
-- rooms/list.lua stands behind a door of SB that stays shut. EVE pushing that door for three passes is moved inside
-- under SB's black. A push on the inner door moves her out. The pak gate is asked for each such room as for the
-- others. A way in also needs the room's level loaded and visible on the streaming list. The doors a player opened
-- are kept in the door file. coop xion rooms off turns these doors off too. They and the Tetrapod's door never
-- move her in the same pass.
-- The NPCs, each pass of the stay (world/maps/sboxion/npcs/npcs.lua): a display body in a room while EVE is near and
-- the room's level is there. Its line shows when she comes close inside the room. coop xion npc picks its clip and
-- its turn.
local Enemy=require('core.enemy')
local PakGate=require('core.pak_gate')
local D=require('world.maps.sboxion.data')
local Recover=require('world.maps.sboxion.recover')
local Rooms=require('world.maps.sboxion.rooms.rooms')
local Tetrapod=require('world.maps.sboxion.tetrapod')
local Threshold=require('world.maps.sboxion.rooms.threshold')
local Npcs=require('world.maps.sboxion.npcs.npcs')
local Xion={}
Xion.ROWS=Enemy.rows(D.ROWS)
-- rows/rows.h's refusals of a gate that stayed shut (busy, net, unread): the title asks again, so nothing is decided.
local SHUT={busy=true,net=true,unread=true}

local WANT,NAMED={},#D.DAY.on+#D.DAY.off -- The day table by name. NAMED: its 41.
for _,name in ipairs(D.DAY.on) do WANT[name]=true end
for _,name in ipairs(D.DAY.off) do WANT[name]=false end
local VOLUMED={}
for _,name in ipairs(D.VOLUMED) do VOLUMED[name]=true end
-- The waypoints: data.lua's, then the street door of each threshold room, so coop xion status names the nearest of
-- those doors too and the watch logs a stay at one.
local WAYPOINTS={table.unpack(D.WAYPOINTS)}
for _,room in ipairs(Threshold.LIST) do
    WAYPOINTS[#WAYPOINTS+1]={name=room.name,X=room.street.X,Y=room.street.Y,Z=room.street.Z}
end
local BACK,AGAIN,WATCH,ANSWER=2,10,1,10 -- s: the read-back, the second look, the watch's pace, the native answer.
local LOOK,NEAREST=10,5 -- s between two looks after the second one; characters named in a characters line.
local function place(at) return string.format('(%.0f, %.0f, %.0f)',at.X,at.Y,at.Z) end
local function round(v) return math.floor(v+0.5) end

-- o: log(m), status() the native status text, ask(line) its request (ok, why), paks (SB/Content/Paks, or nil) and
-- read (core/link.lua's files.read) for the pak gate; slot(command) the co-op save check (ok, why), mode() the link's
-- mode ('none' alone), me() our EVE as core/where.lua last read her ({at=, map=}, or nil), photo() main/base.lua's
-- photo_state (optional), world, the engine reads (world/maps/sboxion/engine.lua; a fake in the tests),
-- rooms_store, core/link.lua's store for the rooms' hidden rows (optional), doors_store, its store for the
-- threshold doors a player opened (optional), npcs_store, its store for the NPC bodies' actor paths (optional) and
-- say(name), which shows an NPC's line (optional).
function Xion.new(o)
    local log=o.log
    local world=o.world
    local recover=Recover.new({log=function(m) log('sboxion: '..m) end,status=o.status,photo=o.photo,world=world})
    local tetrapod=Tetrapod.new({log=function(m) log('sboxion: '..m) end,world=world})
    local asked_point=nil -- The arrival point of the last coop xion asked, for the recovery of the stay it starts.
    local e=Enemy.new({log=function(m) log('sboxion '..m) end,ask=o.ask,status=o.status},
        {word='sboxion',name='SBO Xion',command='coop xion',tag='[SX]',rows=Xion.ROWS,ids={}})
    local pak,pak_why=nil,nil -- The test pak's version (false: none, with why), looked for once a Lua load.
    local verdict=nil -- true: the rows in and read back; false: refused (said); nil: nothing decided yet.
    local self={}
    -- The test pak's version, or nil and why there is none.
    function self.gate()
        if pak==nil then
            pak,pak_why=PakGate.find(o.paks,o.read,D.PAK,{D.UMAP})
            pak=pak or false
        end
        return pak or nil,pak_why
    end
    -- Whether the test pak holds one room's level (its game path) beside Xion_P, or nil and why, asked once a room a
    -- Lua load. The gate above stays as it is: the pak of 2026-11-23 passes it and holds no room.
    local roomy={} -- By game path: true, or why the pak does not hold it.
    local function room_gate(umap)
        if roomy[umap]==nil then
            local version,why=PakGate.find(o.paks,o.read,D.PAK,{D.UMAP,umap})
            roomy[umap]=version~=nil or why
        end
        if roomy[umap]==true then return true end
        return nil,roomy[umap]
    end
    local rooms=Rooms.new({log=function(m) log('sboxion: '..m) end,world=world,store=o.rooms_store,gate=room_gate})
    local doors=Threshold.new({log=function(m) log('sboxion: '..m) end,world=world,store=o.doors_store,
        gate=room_gate})
    local npcs=Npcs.new({log=function(m) log('sboxion: '..m) end,world=world,say=o.say,store=o.npcs_store,
        gate=room_gate})
    local function refused(why)
        log('sboxion rows: refused ('..why..'): coop xion stays off')
        verdict=false
    end
    -- How an ask of the batch ended: the rows in and read back, or a refusal that stays (a shut gate decides nothing).
    local function decided(fine)
        if fine then
            if verdict~=true then log('sboxion rows: '..#Xion.ROWS..'/'..#Xion.ROWS..' in') end
            verdict=true
            return
        end
        local s=Enemy.parse(o.status(),'sboxion')
        if s and s.state=='rows' then refused('they read back other than written')
        elseif s and (s.state=='fault' or s.state=='refused' and not SHUT[s.why]) then refused(s.line) end
    end
    local title,title_stop=e.title_batch(function()
        return self.gate() and 'the co-op save files and test pak '..pak or nil
    end,'coop xion',decided)
    -- title(at_title, coop): at each 250 ms pass while the title shows (main/pass.lua).
    self.title=title
    -- true once the rows are in and read back, false when refused, nil while nothing is decided.
    function self.ok() return verdict end
    -- An engine read that raises is logged and stops nothing.
    local function guarded(what,f,...)
        local ok,a=pcall(f,...)
        if ok then return a end
        log('sboxion: '..what..': unread ('..Enemy.why(a)..')')
    end
    -- The day table: each named volume of E04_ENV_VOL written when it differs. A volume of another level is left
    -- alone, whatever its name. Returns what was written, for the read-back.
    local function light()
        local volumes=world.volumes()
        local in_level,changed,tied,written,failed=0,0,'not found',{},nil
        for _,v in ipairs(volumes) do
            local at,to=v.path:find(D.ENV_LEVEL,1,true)
            if at and (at==1 or v.path:sub(at-1,at-1)=='/') then
                in_level=in_level+1
                local name=v.path:sub(to+1)
                local on=WANT[name]
                if on~=nil then
                    local ok,why=pcall(function()
                        if v.get()~=on then
                            v.set(on)
                            changed=changed+1
                        end
                    end)
                    if not ok then failed=failed or name..': '..Enemy.why(why) end
                    written[#written+1]={v=v,on=on,name=name}
                end
            elseif v.path:sub(-#D.TIED-1)=='.'..D.TIED then
                local ok,on=pcall(v.get)
                tied=ok and tostring(on) or 'unread'
            end
        end
        log(string.format('sboxion: light: %d env volumes found, %d in E04_ENV_VOL, %d named, %d changed, %s active %s',
            #volumes,in_level,#written,changed,D.TIED,tied))
        if failed then log('sboxion: light: a write failed: '..failed) end
        return written
    end
    local function read_back(written)
        local same,wrong=0,{}
        for _,w in ipairs(written) do
            local ok,on=pcall(w.v.get)
            if ok and on==w.on then same=same+1 elseif #wrong<5 then wrong[#wrong+1]=w.name end
        end
        log(string.format('sboxion: light: %d of %d read back as written%s',same,NAMED,
            wrong[1] and ', not '..table.concat(wrong,', ') or ''))
    end
    -- A level's state as text, whole or by the name's last part (A_01).
    local function probe_text(p,name)
        return string.format('%s loaded %s visible %s',name or p.name,tostring(p.loaded),tostring(p.visible))
    end
    -- The stay in SBO Xion, one world load: {probes=, near=, said=, written=, back=, again=, next=, look=, view=}; nil
    -- elsewhere. view, what the last look saw: {seen=<each level's state by name>, levels=, crowd=, key=, nearest=,
    -- time=, zone=, life=}.
    local stay=nil
    -- The listed levels with the state of each by name kept for the next look. Their counts are for the status: the
    -- always-loaded ones loaded and visible, the volume streamed ones counted apart, since those load and show only
    -- where SB's volumes say. Returns the list, the states the look before kept (nil with none) and the levels line.
    local function tally()
        local list=world.levels()
        local always,fine,missing,by,loaded,shown,seen=0,0,{},0,0,0,{}
        for _,l in ipairs(list) do
            seen[l.name]={loaded=l.loaded,visible=l.visible}
            if VOLUMED[l.name] then
                by,loaded,shown=by+1,loaded+(l.loaded and 1 or 0),shown+(l.visible and 1 or 0)
            else
                always=always+1
                if l.loaded and l.visible then fine=fine+1 else missing[#missing+1]=l.name end
            end
        end
        local was=stay.view.seen
        stay.view.seen,stay.view.time=seen,os.clock()
        stay.view.levels=string.format('levels %d of %d always-loaded, %d of %d by volume loaded, %d visible',fine,
            always,loaded,by,shown)
        return list,was,string.format('%d listed, %d of %d always-loaded ones loaded and visible, missing: %s; by '
            ..'volume: %d listed, %d loaded, %d visible',#list,fine,always,
            missing[1] and table.concat(missing,', ') or 'none',by,loaded,shown)
    end
    local function levels()
        local _,_,line=tally()
        log('sboxion: levels: '..line)
    end
    -- A look's levels: each one whose loaded or visible state differs from the look before, in the list's order, then
    -- the ones gone from the list. With no look before, the whole levels line.
    local function changed(me)
        local list,was,line=tally()
        if not was then return log('sboxion: levels: '..line) end
        local said,now={},{}
        for _,l in ipairs(list) do
            now[l.name]=true
            local w=was[l.name]
            if not w or w.loaded~=l.loaded or w.visible~=l.visible then said[#said+1]=probe_text(l) end
        end
        local gone={}
        for name in pairs(was) do if not now[name] then gone[#gone+1]=name..' gone from the list' end end
        table.sort(gone)
        for _,g in ipairs(gone) do said[#said+1]=g end
        if said[1] then log('sboxion: levels changed: '..table.concat(said,', ')..'; EVE at '..place(me.at)) end
    end
    -- The characters by class, the most first: with SB's spawn rows in a pak there can be many, so no name is listed.
    local function by_class(list)
        local n,classes={},{}
        for _,c in ipairs(list) do
            if not n[c.class] then classes[#classes+1]=c.class end
            n[c.class]=(n[c.class] or 0)+1
        end
        table.sort(classes,function(a,b) return n[a]>n[b] or n[a]==n[b] and a<b end)
        for i,class in ipairs(classes) do classes[i]=class..' '..n[class] end
        return table.concat(classes,', ')
    end
    -- The characters line: the count, by class, then the NEAREST nearest to EVE (name, class, metres). EVE is counted,
    -- never among the nearest. Her place is her own entry's, else me's. said: always logged; else only when the count
    -- by class or the names of the nearest changed since the look before.
    local function characters(me,said)
        local list,here=world.characters(),me and me.at
        for _,c in ipairs(list) do if c.eve and c.at then here=c.at end end
        local near={}
        for _,c in ipairs(list) do
            if not c.eve and c.at and here then
                near[#near+1]={c=c,d=math.sqrt((c.at.X-here.X)^2+(c.at.Y-here.Y)^2+(c.at.Z-here.Z)^2)/100}
            end
        end
        table.sort(near,function(a,b) return a.d<b.d or a.d==b.d and a.c.name<b.c.name end)
        local named,who={},{}
        for i=1,math.min(NEAREST,#near) do
            named[i]=string.format('%s (%s) %.1f m',near[i].c.name,near[i].c.class,near[i].d)
            who[i]=near[i].c.name
        end
        local classes=#list>1 and by_class(list) or ''
        local v=stay.view
        local key=classes..'|'..table.concat(who,',')
        v.crowd,v.nearest,v.time=#list,named[1],os.clock()
        if key==v.key and not said then return end
        v.key=key
        log('sboxion: characters: '..#list..(classes~='' and ' by class: '..classes or '')
            ..(named[1] and '; nearest: '..table.concat(named,', ') or ''))
    end
    -- The zone and area of the engine line and EVE's life state of the sboxionwarp line, as the log and the status say
    -- them. Text only: no engine read.
    local function words()
        local text='\n'..(o.status() or '')
        local kind,area=(text:match('\nengine=([^\r\n]*)') or ''):match(' zonetype=(%d+) area=(%S+)')
        local life=text:match('\nsboxionwarp=[^\r\n]- life=(%d+)')
        return kind and 'zonetype '..kind..' area '..area or 'zone unread (the engine line has no zonetype= word)',
            life or 'unread (the sboxionwarp line has no life= word)'
    end
    -- Each change of the two, logged; at the arrival (first) both, with no place.
    local function zone_and_life(me,first)
        local zone,life=words()
        local v,at=stay.view,first and '' or ', EVE at '..place(me.at)
        if zone~=v.zone then
            v.zone=zone
            log('sboxion: zone: '..zone..at)
        end
        if life~=v.life then
            v.life=life
            log('sboxion: life: '..life..at)
        end
    end
    -- The two probe levels by name.
    local function probes()
        local now={}
        for _,p in ipairs(world.probes(D.PROBES)) do now[p.name]=p end
        return now
    end
    local function both(now,short)
        local said={}
        for _,name in ipairs(D.PROBES) do
            if now[name] then said[#said+1]=probe_text(now[name],short and name:match('[^_]+_%d+$')) end
        end
        return table.concat(said,', ')
    end
    local function arrive(me,now)
        stay={near={},said={},back=now+BACK,again=now+AGAIN,next=now+WATCH,look=now+AGAIN,view={}}
        log(string.format('sboxion: arrived, map %s, zone %s, EVE at %s',D.UMAP,D.ZONE,place(me.at)))
        recover.arrive(asked_point or 'city')
        stay.written=guarded('light',light) or {}
        guarded('levels',levels)
        stay.probes=guarded('probe',probes)
        if stay.probes then log('sboxion: probe: start: '..both(stay.probes)) end
        guarded('characters',characters,me,true)
        zone_and_life(me,true)
        rooms.arrive()
        tetrapod.arrive()
        doors.arrive()
        npcs.arrive()
    end
    local function watch(me,now)
        if stay.back and now>=stay.back then
            stay.back=nil
            read_back(stay.written)
        end
        if stay.again and now>=stay.again then
            stay.again,stay.look=nil,now+LOOK
            guarded('levels',levels)
            read_back(stay.written)
            guarded('characters',characters,me,true)
        end
        if now>=stay.look then
            stay.look=now+LOOK
            guarded('levels',changed,me)
            guarded('characters',characters,me,false)
        end
        if now<stay.next then return end
        stay.next=now+WATCH
        zone_and_life(me,false)
        local seen=guarded('probe',probes)
        if seen then
            for _,name in ipairs(D.PROBES) do
                local was,is=stay.probes and stay.probes[name],seen[name]
                if was and is and (was.loaded~=is.loaded or was.visible~=is.visible) then
                    log('sboxion: probe: '..probe_text(is)..', EVE at '..place(me.at))
                end
            end
            stay.probes=seen
        end
        for _,w in ipairs(WAYPOINTS) do
            if math.sqrt((me.at.X-w.X)^2+(me.at.Y-w.Y)^2)>D.NEAR then
                stay.near[w.name],stay.said[w.name]=nil,nil
            else
                stay.near[w.name]=stay.near[w.name] or now
                if not stay.said[w.name] and now-stay.near[w.name]>=D.STAY and seen then
                    stay.said[w.name]=true
                    log('sboxion: at '..w.name..': '..both(seen,true))
                end
            end
        end
    end
    -- A request for the native part. Its answer comes from the sboxionwarp line once its asks= grew.
    local awaited=nil -- {asks=<the line's asks at the request>, due=}
    local function request(line,now)
        local s=Enemy.parse(o.status(),'sboxionwarp')
        if not s then
            return false,'coop-status.txt has no sboxionwarp line: the native part is off, or older than coop xion'
        end
        if s.state=='fault' then return false,'stopped by a fault this game run ('..tostring(s.where)..')' end
        local asked,said=o.ask(line)
        if not asked then return false,'not asked: '..tostring(said) end
        awaited={asks=s.asks,due=now+ANSWER}
        log('sboxion: asked of the native part: '..line)
        return true
    end
    local function answer(now)
        local s=Enemy.parse(o.status(),'sboxionwarp')
        if s and (s.asks>awaited.asks or s.state=='fault') then
            awaited=nil
            log('sboxion: the native part answers: '..s.line)
        elseif now>=awaited.due then
            awaited=nil
            log('sboxion: no answer of the native part in '..ANSWER..' s ('..(s and s.line or 'no sboxionwarp line')
                ..'): coop-link.log says why')
        end
    end
    local function alone(command)
        local ok,why=o.slot(command)
        if not ok then return false,why end
        local mode=o.mode()
        if mode==nil then return false,command..': the Steam link is not ready yet: try again in a moment' end
        if mode~='none' then return false,command..' is solo only: leave the session first (coop leave)' end
        return true
    end
    -- coop xion [city|gate]: the checks, the rows (asked when they are not in yet), then the native request.
    function self.enter(name)
        local at=D.ARRIVALS[name]
        if not at then return false,'coop xion: no arrival point '..tostring(name) end
        local ok,why=alone('coop xion')
        if not ok then return false,why end
        local version,none=self.gate()
        if not version then
            return false,'coop xion needs the zSBO_Xion test pak in Paks\\~mods or Paks\\LogicMods ('..tostring(none)
                ..'): nothing was asked'
        end
        if verdict==false then
            return false,'coop xion: the SBO Xion rows were refused this game run ([SX] lines): nothing was asked'
        end
        if stay then return false,'coop xion: EVE is in SBO Xion already; way out: coop xion leave' end
        local busy=e.busy()
        if busy then return false,busy end
        return e.rows(function(fine,message)
            decided(fine)
            if not fine then return false,message end
            local index=guarded('zone name',world.zone_index,D.ZONE)
            if not index then
                return false,'coop xion: the rows are in. '..D.ZONE..' is no name in this game: nothing was asked'
            end
            local asked,said=request(string.format('sboxion enter %d %d %d %d %d',index,round(at.X),round(at.Y),
                round(at.Z),round(at.Yaw)),os.clock())
            if not asked then return false,'coop xion: '..said end
            asked_point=name
            return true,'coop xion: the rows are in and the warp to the '..name..' point is asked ([SX] lines follow); '
                ..'way out: coop xion leave'
        end)
    end
    -- coop xion leave: the native part reloads the co-op save only from SBO Xion and refuses with zone elsewhere.
    function self.leave()
        local ok,why=alone('coop xion leave')
        if not ok then return false,why end
        local index=guarded('zone name',world.zone_index,D.ZONE)
        if not index then
            return false,'coop xion leave: '..D.ZONE..' is no name in this game (its rows are not in): nothing was '
                ..'asked'
        end
        local asked,said=request('sboxion leave '..index,os.clock())
        if not asked then return false,'coop xion leave: '..said end
        return true,'coop xion leave: SB\'s reload of the co-op save is asked; the native part refuses it outside SBO '
            ..'Xion ([SX] lines follow)'
    end
    -- The last look as one part of coop xion status: its age, the characters with the nearest one, the levels, then the
    -- zone, area and life state read at the last watch pass.
    local function seen()
        local v=stay.view
        if not v.time then return 'look none yet' end
        local n=v.crowd and v.crowd..' character'..(v.crowd==1 and '' or 's') or 'characters unread'
        return string.format('look %.0f s ago: %s%s, %s, %s, life %s',os.clock()-v.time,n,
            v.nearest and ', nearest '..v.nearest or '',v.levels or 'levels unread',v.zone or 'zone unread',
            v.life or 'unread')
    end
    -- coop xion status: one line.
    function self.status()
        local version,none=self.gate()
        local rows,native=Enemy.parse(o.status(),'sboxion'),Enemy.parse(o.status(),'sboxionwarp')
        local parts={'pak '..(version or 'none ('..tostring(none)..')'),
            'rows '..(verdict==false and 'refused' or (verdict or rows and rows.state=='rows') and 'in'
                or rows and rows.state or 'no line'),
            native and native.line or 'no sboxionwarp line'}
        local me=o.me()
        if me and me.map==D.MAP then
            local best,far=nil,math.huge
            for _,w in ipairs(WAYPOINTS) do
                local d=math.sqrt((me.at.X-w.X)^2+(me.at.Y-w.Y)^2)
                if d<far then best,far=w.name,d end
            end
            parts[#parts+1]=string.format('EVE at %s, nearest waypoint %s %.1f m',place(me.at),best,far/100)
            if stay then
                for _,part in ipairs({recover.status(),rooms.status(),doors.status(),npcs.status(),seen()}) do
                    parts[#parts+1]=part
                end
            end
        else
            parts[#parts+1]='EVE is not in SBO Xion'..(me and ' (map '..me.map..')' or '')
        end
        return true,'sboxion: '..table.concat(parts,'; ')
    end
    -- coop xion recover [on|death|off]: the recovery's mode, or its state with no word. on and death start a stopped
    -- recovery again.
    function self.recover(word)
        if not stay then return false,'coop xion recover: EVE is not in SBO Xion' end
        local ok,line=recover.mode(word)
        return ok,ok and 'coop xion recover: '..line or line
    end
    -- coop xion rooms [on|off]: SB's pieces put back in the doorways or hidden again, with the threshold doors off or
    -- on, or the state of both with no word.
    function self.rooms(word)
        if not stay then return false,'coop xion rooms: EVE is not in SBO Xion' end
        local ok,line=rooms.switch(word)
        if ok and word then doors.switch(word=='on') end
        return ok,ok and 'coop xion rooms: '..line..(word and '' or '; '..doors.status()) or line
    end
    -- coop xion tetrapod [in|out]: EVE put inside the Tetrapod or back in front of it, or where she is with no word.
    function self.tetrapod(word)
        if not stay then return false,'coop xion tetrapod: EVE is not in SBO Xion' end
        if word and doors.busy() then return false,'coop xion tetrapod: a threshold door is moving EVE' end
        local ok,line=tetrapod.go(word)
        return ok,ok and 'coop xion tetrapod: '..line or line
    end
    -- coop xion npc [<n> | turn <degrees>]: the clip or the turn of the NPC nearest to EVE, or its state with no word.
    function self.npc(what,value)
        if not stay then return false,'coop xion npc: EVE is not in SBO Xion' end
        local ok,line=npcs.command(what,value)
        return ok,ok and 'coop xion npc: '..line or line
    end
    -- Each 250 ms pass: the wait for the rows and their read-back, the native answer awaited, then the arrival, the
    -- watch, the recovery, the Tetrapod's door, the threshold doors and the rooms while EVE's map is SBO Xion. In any
    -- other map, with nothing asked, it reads nothing. A map change ends the recovery first, then closes the rooms: a
    -- put-back that raises leaves no recovery running. A row of a world that is gone is not called. The doors are
    -- not ticked in another map and each arrival resets them. Each of the two door parts counts nothing while the
    -- other one moves EVE. The Tetrapod's door comes first, so the two never start a move in the same pass.
    local off=false
    function self.tick()
        if off then return end
        local now=os.clock()
        local _,message=e.tick()
        if message then log('sboxion: '..tostring(message)) end
        if awaited then answer(now) end
        local me=o.me()
        if me and me.map==D.MAP then
            if not stay then arrive(me,now) end
            watch(me,now)
            guarded('recovery',recover.tick)
            local busy,read=recover.busy()
            tetrapod.tick(busy or doors.busy(),read)
            doors.tick(busy or tetrapod.busy(),read)
            rooms.tick()
            npcs.tick(me.at)
        elseif stay then
            stay=nil
            npcs.stop() -- First: it cannot raise, so a stop that raises below leaves no body.
            recover.stop('a map change')
            rooms.close('a map change')
            log('sboxion: left, map '..(me and me.map or 'none'))
        end
    end
    -- coop off: the title's wait, the watch and the recovery ended, the Tetrapod's parts as SB ships them when the door
    -- made them solid, then the rooms' rows put back. The rooms come last, so a put-back that raises skips none of
    -- the others. Rows already in stay for the game run. No pass comes after it, so a threshold door's move that
    -- waits is never made.
    function self.stop()
        off,stay,awaited=true,nil,nil
        npcs.stop()
        recover.stop('coop off')
        tetrapod.stop()
        title_stop()
        e.stop()
        rooms.close('coop off')
    end
    return self
end
return Xion
