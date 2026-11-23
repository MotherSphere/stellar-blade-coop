-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion (a test tool, experimental, left out of the usage line): a world of SBO's own whose persistent level
-- /Game/SBO_World/Xion_P streams the look-only sublevels of SB's Xion from the player's own game files. The level is
-- in the zSBO_Xion test pak, built outside the mod and never shipped with it. SB's world row Xion, its zones and its
-- level-design sublevels are not touched: story mode and online sessions keep SB's Xion.
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
-- and name), read back 2 s and 10 s later, the streaming levels' state, the two probe levels' state and the
-- characters, each as a log line a test reads. While EVE stays, once a second: each change of the two probe levels
-- and each waypoint she stands at. Nothing is read in any other map.
-- coop xion leave: the request "sboxion leave <zone FName index>". The native part compares the zone with the
-- client's and calls SB's reload of the co-op save only from SBO Xion, so the request is sent from any map.
-- coop xion status: the pak, the rows, the native part's last answer, EVE's place and the nearest waypoint.
local Enemy=require('core.enemy')
local PakGate=require('core.pak_gate')
local D=require('world.maps.sboxion.data')
local Xion={}
Xion.ROWS=Enemy.rows(D.ROWS)
-- rows/rows.h's refusals of a gate that stayed shut (busy, net, unread): the title asks again, so nothing is decided.
local SHUT={busy=true,net=true,unread=true}

local WANT,NAMED={},#D.DAY.on+#D.DAY.off -- The day table by name. NAMED: its 41.
for _,name in ipairs(D.DAY.on) do WANT[name]=true end
for _,name in ipairs(D.DAY.off) do WANT[name]=false end
local PROBE={}
for _,name in ipairs(D.PROBES) do PROBE[name]=true end
local BACK,AGAIN,WATCH,ANSWER=2,10,1,10 -- s: the read-back, the second look, the watch's pace, the native answer.
local function place(at) return string.format('(%.0f, %.0f, %.0f)',at.X,at.Y,at.Z) end
local function round(v) return math.floor(v+0.5) end

-- o: log(m), status() the native status text, ask(line) its request (ok, why), paks (SB/Content/Paks, or nil) and
-- read (core/link.lua's files.read) for the pak gate; slot(command) the co-op save check (ok, why), mode() the link's
-- mode ('none' alone), me() our EVE as core/where.lua last read her ({at=, map=}, or nil) and world, the engine reads
-- (world/maps/sboxion/engine.lua; a fake in the tests).
function Xion.new(o)
    local log=o.log
    local world=o.world
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
    local function levels()
        local list=world.levels()
        local always,fine,missing=0,0,{}
        for _,l in ipairs(list) do
            if not PROBE[l.name] then
                always=always+1
                if l.loaded and l.visible then fine=fine+1 else missing[#missing+1]=l.name end
            end
        end
        log(string.format('sboxion: levels: %d listed, %d of %d always-loaded ones loaded and visible, missing: %s',
            #list,fine,always,missing[1] and table.concat(missing,', ') or 'none'))
    end
    local function characters()
        local names=world.characters()
        log('sboxion: characters: '..#names..(#names>1 and ' ('..table.concat(names,', ')..')' or ''))
    end
    -- The two probe levels by name. Then their state as text, whole or by the name's last part (A_01).
    local function probes()
        local now={}
        for _,p in ipairs(world.probes(D.PROBES)) do now[p.name]=p end
        return now
    end
    local function probe_text(p,name)
        return string.format('%s loaded %s visible %s',name or p.name,tostring(p.loaded),tostring(p.visible))
    end
    local function both(now,short)
        local said={}
        for _,name in ipairs(D.PROBES) do
            if now[name] then said[#said+1]=probe_text(now[name],short and name:match('[^_]+_%d+$')) end
        end
        return table.concat(said,', ')
    end
    -- The stay in SBO Xion, one world load: {probes=, near=, said=, written=, back=, again=, next=}; nil elsewhere.
    local stay=nil
    local function arrive(me,now)
        stay={near={},said={},back=now+BACK,again=now+AGAIN,next=now+WATCH}
        log(string.format('sboxion: arrived, map %s, zone %s, EVE at %s',D.UMAP,D.ZONE,place(me.at)))
        stay.written=guarded('light',light) or {}
        guarded('levels',levels)
        stay.probes=guarded('probe',probes)
        if stay.probes then log('sboxion: probe: start: '..both(stay.probes)) end
        guarded('characters',characters)
    end
    local function watch(me,now)
        if stay.back and now>=stay.back then
            stay.back=nil
            read_back(stay.written)
        end
        if stay.again and now>=stay.again then
            stay.again=nil
            guarded('levels',levels)
            read_back(stay.written)
            guarded('characters',characters)
        end
        if now<stay.next then return end
        stay.next=now+WATCH
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
        for _,w in ipairs(D.WAYPOINTS) do
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
            for _,w in ipairs(D.WAYPOINTS) do
                local d=math.sqrt((me.at.X-w.X)^2+(me.at.Y-w.Y)^2)
                if d<far then best,far=w.name,d end
            end
            parts[#parts+1]=string.format('EVE at %s, nearest waypoint %s %.1f m',place(me.at),best,far/100)
        else
            parts[#parts+1]='EVE is not in SBO Xion'..(me and ' (map '..me.map..')' or '')
        end
        return true,'sboxion: '..table.concat(parts,'; ')
    end
    -- Each 250 ms pass: the wait for the rows and their read-back, the native answer awaited, then the arrival and
    -- the watch while EVE's map is SBO Xion. In any other map, with nothing asked, it reads nothing.
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
        elseif stay then
            stay=nil
            log('sboxion: left, map '..(me and me.map or 'none'))
        end
    end
    -- coop off: the title's wait and the watch ended. Rows already in stay for the game run.
    function self.stop()
        off,stay,awaited=true,nil,nil
        title_stop()
        e.stop()
    end
    return self
end
return Xion
