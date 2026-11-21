-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Follow the host's fast travel, on the game thread: main.lua ticks it every 250 ms with the Steam link; follow_key,
-- coop travel host, coop travel probe and coop travel spot reach it, the group's return through go().
-- The guest. When the host's map changes to another than hers, or he stands more than 150 m from her EVE on hers, an
-- offer comes once (follow_host=ask, the default) and follow_key starts the travel; always starts it by itself 5 s
-- later, after a notice, and follow_key then cancels it; off does neither, and follow_key does nothing. With
-- follow_key=none neither ask nor always shows or starts anything (a log line only): coop travel host still travels.
-- No offer comes for the place a travel brought her to. On his map the travel is the spot warp: the guards (check:
-- refused within 5 m of him, or with no distance when his ghost does not show), then spot? <id> <his SteamID> to his
-- game, whose answer is his last ground point (whole cm, whole degrees of yaw) or none and why; the guards again, then
-- the native part's call of SB's own position warp there (travel spot, no camp). On another map it is the camp travel:
-- the guards (check), then camps? <id> to the host's game, whose answer names his world and up to 8 camps nearest his
-- EVE. She takes the first that is in this table under that world, that her save has activated and that this game
-- knows as a name (FName with FNAME_Find, which never makes one), checks the guards again, and asks the native part to
-- call SB's own fast travel with it; after SB's refusal (a return of 0) the next one, 3 calls at most. SB's fast travel
-- does not check activation (game/travel.h),
-- and a travel that activated a camp would count toward its achievements, so a camp counts only when the native part's
-- read of SB's own camp list (game/camps.h, the activated status line) lists it; no read, no travel. main.lua passes
-- o.follow=true; without it a guard refuses every travel and no offer shows. A camp travel whose host came to her map
-- before the call asks his spot instead. Once a camp travel to his map arrived, his spot is asked by itself (the second
-- hop, no notice) as soon as the guards pass, the native 10 s after the accepted call among them, for 30 s at most.
-- Notices: going (the call was taken), none (no camp passed, or SB refused each), busy (a guard of the moment, a solo
-- area on either side, the host's game busy, loading or in a solo area, no spot answer in 10 s), air (his last ground
-- point is missing or too old), failed (the native part refused, no camps answer came, the warp never started, no read
-- of the activated camps, or the follow off; UE4SS.log says why).
-- Every member, host or guest, while linked: her last ground point (EVE walking on a floor, read each tick, dropped on
-- a map change or a new EVE) and an answer to each new spot? from the status, at most 10 s old, else none and the
-- first reason of title, loading, busy (a cutscene), solo, boss, busy (a warp), air.
-- go(id), the group's return: the spot warp next to member id on our map, its refusals and answers in the log only.
-- The guest reads the host's map and feet from the host's ghost: the slot the host's member line names (the native
-- part gives the host slot 0, main.lua's puppet, on every guest), through o.ghost(k) for another slot.
-- The host. While any guest is linked, its game answers each new camps? from the link's status (the native part
-- sends each answer to the guests who asked): its world and the 8 camps of this table under it
-- nearest its EVE, in whole metres, or none and why (title, loading, nocamp, busy). The camps are the map's
-- SBSpawnPoint actors named after a camp of its world, read once a map (FindAllOf walks every object; a read that found
-- none, again a minute later), never during a load.
-- The host's row in the session list (outside a match lobby, a guest linked or not): its map's last path part and the
-- camp of this table nearest its EVE (core/link.lua's where), at once on each map and again at most once a minute;
-- its rules word (Link.rules) whenever a setting changes it. The link asks each only when it changed.
-- Only the 120 camps of this table are ever sent or taken: no autosave volume, no camp of a developer test world, none
-- that leads to several worlds. The travel moves her EVE only; nothing changes in the host's game.
-- coop travel probe <camp> (a test tool): solo, on a co-op save only, a camp of the table that the read lists as
-- activated, without the host's answer. coop mxiii (world/maps/matrix13/level/travel.lua) asks the same guards first
-- (ready), then probes its own camp, which is in no table, without the activation read: the camp achievements count
-- only named ZoneEnvSpawn rows turned On, and none names its row. coop mxiii leave takes camps() (the read's travel
-- camps and the camp EVE respawns at) and probes one of them as coop travel probe does. A Lua error turns the follow
-- off for the run.
-- coop travel spot [<world>] <x> <y> <z> (a test tool): the spot warp alone, under coop travel probe's guards; a world
-- of core/worlds.lua puts its FName in the warp's record.
local U=require('core.unreal')
local P=require('core.player')
local Where=require('core.where')
local Link=require('core.link')
local Line=require('core.line')
local Travel={}
Travel.WORLDS=require('core.worlds')
-- The travel camps, {alias, type, world}: the ZoneCampTable rows of type FullCamp, SimplyCamp, PhoneBooth or Tetrapod
-- whose ZoneEnvSpawnTable rows (TargetCamp), through each row's zone and ZoneTable's WorldAlias, lead to exactly one
-- world, in the tables of the game's Steam build 26123051. Left out: the SaveVolume rows, the camps that lead to
-- several worlds or to none, and the camps of the developer test worlds (CombatTestMapMk2, SysTest_P,
-- SysTest_Nikke_P).
Travel.CAMPS={
    {'AYL01_Camp_01','FullCamp','AbyssLab'},{'AYL01_Camp_02','SimplyCamp','AbyssLab'},
    {'AYL03_Camp_01','SimplyCamp','AbyssLab'},{'AYL04_Camp_01','SimplyCamp','AbyssLab'},
    {'AYL04_Camp_02','SimplyCamp','AbyssLab'},{'AYL05_Camp_01','SimplyCamp','AbyssLab'},
    {'AYL06_Camp_01','FullCamp','AbyssLab'},{'ATL01_Camp_01','SimplyCamp','AltesLab'},
    {'ATL01_Camp_02','SimplyCamp','AltesLab'},{'ATL02_Camp_01','SimplyCamp','AltesLab'},
    {'ATL03_Camp_01','SimplyCamp','AltesLab'},{'ATL03_Camp_02','FullCamp','AltesLab'},
    {'ATL_Camp_Maelstrom','SimplyCamp','AltesLab'},{'ARD10_Camp_01','FullCamp','Arden'},
    {'DEDA_Camp_00','Tetrapod','DEDA'},{'DEDA_Camp_01','SimplyCamp','DEDA'},{'DEDA_Camp_02','FullCamp','DEDA'},
    {'DEDA_Camp_03','SimplyCamp','DEDA'},{'DEDA_Camp_04','SimplyCamp','DEDA'},{'DEDA_Camp_05','SimplyCamp','DEDA'},
    {'DEDA_Camp_06','SimplyCamp','DEDA'},{'DED10_Camp_00','Tetrapod','DrownedEidosDistrict'},
    {'DED10_Camp_01','SimplyCamp','DrownedEidosDistrict'},{'DED10_Camp_02','SimplyCamp','DrownedEidosDistrict'},
    {'DED10_Camp_03','FullCamp','DrownedEidosDistrict'},{'DED10_Camp_04','SimplyCamp','DrownedEidosDistrict'},
    {'DED10_Camp_05','SimplyCamp','DrownedEidosDistrict'},{'DED10_Camp_06','FullCamp','DrownedEidosDistrict'},
    {'DED10_Camp_07','FullCamp','DrownedEidosDistrict'},{'DED20_Camp_01','SimplyCamp','DrownedEidosDistrict'},
    {'DED20_Camp_02','FullCamp','DrownedEidosDistrict'},{'DED20_Camp_03','SimplyCamp','DrownedEidosDistrict'},
    {'DED20_Camp_04','SimplyCamp','DrownedEidosDistrict'},{'DED20_Camp_05','FullCamp','DrownedEidosDistrict'},
    {'DED20_Camp_06','SimplyCamp','DrownedEidosDistrict'},{'DED30_Camp_01','SimplyCamp','DrownedEidosDistrict'},
    {'DED30_Camp_02','FullCamp','DrownedEidosDistrict'},{'ME01_Camp_01','SimplyCamp','MatrixEleven'},
    {'ME01_Camp_02','SimplyCamp','MatrixEleven'},{'ME01_Camp_03','FullCamp','MatrixEleven'},
    {'ME03_Camp_01','FullCamp','MatrixEleven'},{'ME03_Camp_02','SimplyCamp','MatrixEleven'},
    {'ME03_Camp_03','FullCamp','MatrixEleven'},{'ME04_Camp_01','SimplyCamp','MatrixEleven'},
    {'ME04_Camp_02','SimplyCamp','MatrixEleven'},{'ME05_Camp_01','FullCamp','MatrixEleven'},
    {'ME05_Camp_02','SimplyCamp','MatrixEleven'},{'ME06_Camp_01','SimplyCamp','MatrixEleven'},
    {'ME06_Camp_02','FullCamp','MatrixEleven'},{'MET10_Camp_01','FullCamp','Metropolitan'},
    {'Nest30_Camp_01','FullCamp','Nest'},{'SE01_Camp_00','Tetrapod','SpaceElevator'},
    {'SE01_Camp_01_Re','FullCamp','SpaceElevator'},{'SE01_Camp_02','SimplyCamp','SpaceElevator'},
    {'SE04_Camp_01','SimplyCamp','SpaceElevator'},{'SE05_Camp_01','FullCamp','SpaceElevator'},
    {'SE05_Camp_02','SimplyCamp','SpaceElevator'},{'SE05_Camp_03','FullCamp','SpaceElevator'},
    {'SE05_Camp_04','SimplyCamp','SpaceElevator'},{'SE06_Camp_01','SimplyCamp','SpaceElevator'},
    {'SE06_Camp_02','FullCamp','SpaceElevator'},{'SE07_Camp_01','SimplyCamp','SpaceElevator'},
    {'SE07_Camp_02','SimplyCamp','SpaceElevator'},{'SE08_Camp_01','SimplyCamp','SpaceElevator'},
    {'SE08_Camp_02_Re','FullCamp','SpaceElevator'},{'SE09_Camp_01','FullCamp','SpaceElevator'},
    {'WLA10_Camp_01','FullCamp','WasteLandA'},{'WLA10_Camp_01_01','PhoneBooth','WasteLandA'},
    {'WLA10_Camp_01_02','PhoneBooth','WasteLandA'},{'WLA10_Camp_02','FullCamp','WasteLandA'},
    {'WLA10_Camp_04','SimplyCamp','WasteLandA'},{'WLA10_Camp_05','SimplyCamp','WasteLandA'},
    {'WLA10_Camp_06','FullCamp','WasteLandA'},{'WLA10_Camp_07','SimplyCamp','WasteLandA'},
    {'WLA30_Camp_00','Tetrapod','WasteLandA'},{'WLA30_Camp_01','FullCamp','WasteLandA'},
    {'WLA30_Camp_02','SimplyCamp','WasteLandA'},{'WLA30_Camp_03','FullCamp','WasteLandA'},
    {'WLA40_Camp_01','FullCamp','WasteLandA'},{'WLA40_Camp_01_01','PhoneBooth','WasteLandA'},
    {'WLA40_Camp_01_02','PhoneBooth','WasteLandA'},{'WLA40_Camp_01_03','PhoneBooth','WasteLandA'},
    {'WLA40_Camp_01_04','PhoneBooth','WasteLandA'},{'WLA40_Camp_02','SimplyCamp','WasteLandA'},
    {'WLA50_Camp_01','FullCamp','WasteLandA'},{'ME01_Camp_00','Tetrapod','WasteLandB'},
    {'WLB10_Camp_00','Tetrapod','WasteLandB'},{'WLB10_Camp_01','FullCamp','WasteLandB'},
    {'WLB10_Camp_01_01','PhoneBooth','WasteLandB'},{'WLB10_Camp_01_02','PhoneBooth','WasteLandB'},
    {'WLB10_Camp_01_03','PhoneBooth','WasteLandB'},{'WLB10_Camp_02','FullCamp','WasteLandB'},
    {'WLB10_Camp_03','SimplyCamp','WasteLandB'},{'WLB10_Camp_04','FullCamp','WasteLandB'},
    {'WLB10_Camp_06','SimplyCamp','WasteLandB'},{'WLB10_Camp_07','FullCamp','WasteLandB'},
    {'WLB10_Camp_08','FullCamp','WasteLandB'},{'WLB20_Camp_01','FullCamp','WasteLandB'},
    {'WLB20_Camp_02','SimplyCamp','WasteLandB'},{'WLB20_Camp_02_01','PhoneBooth','WasteLandB'},
    {'WLB20_Camp_03','FullCamp','WasteLandB'},{'WLB20_Camp_04','FullCamp','WasteLandB'},
    {'WLB20_Camp_05','FullCamp','WasteLandB'},{'WLB30_Camp_01','FullCamp','WasteLandB'},
    {'WLB30_Camp_02','SimplyCamp','WasteLandB'},{'WLB30_Camp_03','FullCamp','WasteLandB'},
    {'WLB50_Camp_01','SimplyCamp','WasteLandB'},{'WLB50_Camp_01_01','PhoneBooth','WasteLandB'},
    {'WLB50_Camp_01_02','PhoneBooth','WasteLandB'},{'WLB50_Camp_02','SimplyCamp','WasteLandB'},
    {'WLB50_Camp_03','SimplyCamp','WasteLandB'},{'WLB50_Camp_06','FullCamp','WasteLandB'},
    {'Xion_Camp_00','Tetrapod','Xion'},{'Xion_Camp_10','FullCamp','Xion'},{'Xion_Camp_10_01','PhoneBooth','Xion'},
    {'Xion_Camp_10_02','PhoneBooth','Xion'},{'Xion_Camp_10_03','PhoneBooth','Xion'},
    {'Xion_Camp_10_04','PhoneBooth','Xion'},{'Xion_Camp_10_05','PhoneBooth','Xion'},
    {'Xion_Camp_20','SimplyCamp','Xion'},
}
local CAMP={} -- Alias to {type=, world=}.
for _,row in ipairs(Travel.CAMPS) do CAMP[row[1]]={type=row[2],world=row[3]} end
local WORLD={} -- Map to world.
for world,map in pairs(Travel.WORLDS) do WORLD[map]=world end
local FAR,NEAR=150,100 -- m: the host this far on her map starts an offer, which ends once he is back within NEAR.
-- m: the host this close refuses the follow's spot warp; s: a ground point this old at most in a spot answer; s after
-- the arrival that the second hop keeps trying.
local NEAR_SPOT,FRESH,HOP=5,10,30
local GROUND={[1]=true,[2]=true} -- online/modes/nightop/run.lua's copy. EMovementMode: Walking, NavWalking.
local MAX_AT,MAX_YAW=10000000,360 -- cm, degrees: link/protocol.h's kMaxSpotAt and kMaxSpotYaw.
-- s: always's delay; after an accepted call; for an answer; for a result; between two camps? (the host's game takes one
-- each 2 s, and the network can bring two closer together).
local AUTO,WAIT,ANSWER,RESULT,ASK=5,10,10,5,2.5
local PLACE=60 -- s: the host's camp for the session list, chosen again at most this often on one map.
local CALLS,SENT=3,8 -- Calls a travel at most; camps an answer sends at most.
-- The native part's refusals that pass by themselves (busy); any other is failed.
local BUSY={wait=true,calls=true,warp=true,camp=true,respawn=true,flow=true,phase=true,solo=true}
Travel.number=Line.number
local why=U.why
-- o: {link=, puppet=, settings= (follow_host, follow_key), tell(build), name(words) (her name, or the words' friend),
-- log(text), paused() (the game paused, photo mode or a menu), night() (a Night Operation run), cutscene() (one plays
-- in our game), follow (true: the follow may travel; main.lua passes it), ghost(k) (ghost slot k's puppet, 1 to 6, or
-- nil), back() (the group's return on the death screen: true or false and its text when it took follow_key, else
-- nil)}.
function Travel.new(o)
    local link,puppet,settings,log=o.link,o.puppet,o.settings,o.log
    local self,now,off={},0,false
    local function tell(key,args)
        o.tell(function(w) return w.travel[key]:format(table.unpack(args and args(w) or {})) end)
    end
    local function named(w) return {o.name(w)} end
    local function line(name) return ('\n'..(link.status() or '')):match('\n('..name..'=[^\r\n]*)') or '' end
    -- The native part's travel: the watch's state and the asks handled, or nil without them (engine off, coop off).
    local function native()
        local state,n=line('engine'):match(' travel=(%S+) travel_calls=(%d+)')
        return state,tonumber(n)
    end
    -- The native part's read of the camps this save has activated (game/camps.h), its status line
    -- activated=<n>:<alias>,... rested=<alias>. The list and the camp EVE respawns at (nil when unknown), or nil and
    -- why.
    local function read()
        local text=line('activated')
        local n,list_text=text:match('^activated=(%d+):(%S*)')
        if not n then return nil,text:match('^activated=none:(%S+)') or 'no read yet' end
        local list={}
        for alias in list_text:gmatch('[^,]+') do list[#list+1]=alias end
        if #list~=tonumber(n) then return nil,'unread' end
        return list,text:match(' rested=(%S+)')
    end
    -- Whether the read lists the camp: true or false, or nil and why without a read.
    local function activated(alias)
        local list,unread=read()
        if not list then return nil,unread end
        for _,a in ipairs(list) do if a==alias then return true end end
        return false
    end
    local id=os.time()%65536 -- The guest's last camps? (a new Lua load starts elsewhere, so the host answers again).
    local req=nil -- The travel under way: {id=, at=, probe=, list=, i=, calls=, handled=, call_at=}.
    local accepted,watch,stuck=-math.huge,nil,nil -- The last accepted call; its warp, until it ran; a map it stuck on.
    local hop=nil -- After an accepted camp travel of the follow: {n=its ask, at=the arrival on his map}.
    -- Our last ground point ({x=,y=,z=,yaw=,at=,map=,pawn=}, whole cm and degrees) and the last spot? answered.
    local point,spotted=nil,nil
    local asked_at=-math.huge -- Our last camps?: one each ASK s.
    -- The offer: key, the place offered (the host's map, or far on ours); due, always's start; quiet, no offer for the
    -- next place (the one a travel brought her to).
    local offer={}
    local answered,cache=nil,{} -- The host's: the last camps? answered; its camps on cache.map, read at cache.at.
    local placed=nil -- The host's last place for the session list: {map=, at=}.
    -- On a guest: the host's member line (nil before the status names the host) and the host's ghost, main.lua's
    -- puppet in slot 0, else slot k's ghost (none until it is made).
    local NONE={her_map=function() end,anchor=function() end}
    local function host_member()
        local h=link.host()
        return h and link.member(h.id)
    end
    -- A member's ghost: slot 0 main.lua's puppet, else slot k's.
    local function ghost_of(m)
        if not m or m.slot==0 then return puppet end
        return o.ghost and o.ghost(m.slot) or NONE
    end
    local function host_ghost() return ghost_of(host_member()) end
    -- The host's SteamID: his host line's, else slot 0's member (guest()'s rule).
    local function host_id()
        local h=link.host()
        if h then return h.id end
        for _,m in ipairs(link.members() or {}) do if m.slot==0 then return m.id end end
    end
    -- The target's map (target nil: the host's, else member target's), ours, and the metres between her ghost and our
    -- EVE when both are on one map and it shows.
    local function where(target)
        local m=target and link.member(target)
        local ghost=not target and host_ghost() or m and ghost_of(m) or NONE
        local me,host=Where.me(),ghost.her_map()
        local mine=me and me.map
        if not (host and mine) or host~=mine then return host,mine,nil end
        local _,feet=ghost.anchor()
        return host,mine,feet and math.sqrt((feet.X-me.at.X)^2+(feet.Y-me.at.Y)^2+(feet.Z-me.at.Z)^2)/100
    end
    -- A guest linked with the host: her member line, else (no host line) the slot-0 member's.
    local function guest()
        if link.mode()~='guest' then return false end
        local m=host_member()
        if m then return m.linked end
        local _,linked=link.friend()
        return linked==true
    end
    -- Whether the travel's target holds: the host for the follow (target nil, a guest), else member target linked.
    local function linked(target)
        if not target then return guest() end
        local mode,m=link.mode(),link.member(target)
        return (mode=='host' or mode=='guest') and m~=nil and m.linked==true
    end
    -- The target's vitals (target nil: the host's): slot 0's from the mate= line, another's from her vit= line.
    local function vitals(target)
        local m=host_member()
        if target then
            m=link.member(target)
            if not m then return nil end
        end
        if not m or m.slot==0 then return link.mate() end
        return link.vitals(m.id)
    end
    -- Why a travel cannot start now, and the notice for it (nil: the log only), or nil when it can. calling: again
    -- right before a call, inside the travel under way. target: nil for the follow (a guest toward the host), else
    -- go()'s member, on our map only.
    local function check(calling,target)
        if not linked(target) then return target and 'not a linked member of a session' or 'not a guest in a session' end
        if settings.follow_host=='off' then return 'follow_host=off' end
        if not o.follow then return 'the follow is off (no o.follow)','failed' end
        local host,mine,m=where(target)
        if not target and not (host and host==mine) then -- A camp travel: the camps this save has activated.
            local list,unread=read()
            if not list then return 'no read of the camps this save has activated ('..unread..')','failed' end
        end
        if not line('slot'):find('^slot=coop ') then return 'not on a co-op save' end
        local state=native()
        if not state then return 'no travel in the native part (engine off, or coop off)' end
        if state=='refused:fault' then return 'the native travel stopped by a fault (coop-link.log)','failed' end
        if stuck and stuck==mine then return 'the last warp never started on this map','failed' end
        if not host then return target and 'their map is unknown' or "the host's map is unknown" end
        if not mine then return 'no EVE (a load)' end
        if target and host~=mine then return 'they are on another map' end
        if host==mine and not m then return (target and 'their' or "the host's")..' place on this map is unknown' end
        if not target and host==mine and m<=NEAR_SPOT then return 'the host is within 5 m' end
        local v=vitals(target)
        if Link.solo(v and v.zone) then return (target and 'they are' or 'the host is')..' in a solo area','busy' end
        if Link.solo(link.zone()) then return 'we are in a solo area','busy' end
        if target and not (v and (v.life==1 or v.life==6) and v.hp>0) then return 'they are down','busy' end
        if req and not calling then return 'a travel is under way' end
        if now-asked_at<ASK and not calling then return 'one request to the host each 2.5 s' end
        local life=link.life()
        if not (life and (life.state==1 or life.state==6) and life.hp>0) then return 'our EVE is down','busy' end
        if not line('engine'):find(' warp=idle',1,true) then return 'a warp or respawn is under way','busy' end
        if o.paused() then return 'the game is paused, in photo mode or in a menu','busy' end
        if o.night() then return 'a Night Operation run is under way','busy' end
        if o.cutscene() then return 'a cutscene plays','busy' end
        local fight=link.fight() or '' -- While the shared fight runs: its boss= and battle= fields.
        if fight:find(' boss=',1,true) and not fight:find(' boss=0',1,true) then
            return 'a boss fight on our side','busy'
        end
        if fight:find(' battle=',1,true) and not fight:find(' battle=0',1,true) then
            return 'an enemy in battle near our EVE','busy'
        end
        if now-accepted<WAIT then return 'the last travel was under 10 s ago','busy' end
    end
    local function finish(key,text) -- key nil: the log only, as for a probe and a quiet travel (go, the second hop).
        log('travel'..(req and req.alias and ' '..req.alias or '')..': '..text)
        if key and not req.probe and not req.quiet then tell(key,named) end
        req=nil
    end
    -- spot? to the target's game (nil: the host's); on success the spot travel under way replaces any other.
    local function ask(target,quiet)
        local to=target or host_id()
        if not to then return false,'no member to ask' end
        id=(id+1)%65536
        local ok,e=link.request('spot? '..id..' '..to)
        if not ok then return false,e end
        req,asked_at={spot=true,id=id,at=now,target=target,quiet=quiet},now
        return true,"asked the game of "..(target and 'member '..target or 'the host')..' for its place (spot? '..id..')'
    end
    -- The native call of the spot warp: '<x> <y> <z> <yaw>[ <world> <index> <number>]'.
    local function call_spot(text)
        local _,n=native()
        req.handled,req.call_at,req.alias=n or 0,now,'spot'
        local ok,e=link.request('travel spot '..text)
        if not ok then finish('failed',e) end
    end
    -- The target's answer to our spot?: '<x> <y> <z> <yaw>' or 'none <why>'. The guards again first, then her map.
    local function landed(rest)
        local none=rest:match('^none (%S+)$')
        if none then
            local who=req.target and 'member '..req.target or 'the host'
            return finish(({air='air',title='failed'})[none] or 'busy','no spot from '..who..': none '..none)
        end
        local x,y,z,yaw=rest:match('^(%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+)$')
        if not x then return finish('failed','an answer that is no spot: '..rest) end
        local text,kind=check(true,req.target)
        if text then return finish(kind,'refused at the call: '..text) end
        local host,mine=where(req.target)
        if host~=mine then return finish('busy','refused at the call: the host left this map') end
        call_spot(x..' '..y..' '..z..' '..yaw)
    end
    -- The next camp of the list, or none once the list or the 3 calls ran out. The guards again first: the host's
    -- answer can come seconds after the press. The host on her map now: his spot asked instead.
    local function call_next()
        req.i=req.i+1
        local c=req.list[req.i]
        if not c or req.calls>=CALLS then return finish('none','no camp of the answer was taken') end
        if not req.probe then
            local text,kind=check(true)
            if text then return finish(kind,'refused at the call: '..text) end
            local host,mine=where()
            if host==mine then
                log('travel: the host is on this map now: his spot asked')
                local ok,e=ask()
                if not ok then finish('failed',e) end
                return
            end
        end
        local _,n=native()
        req.handled,req.calls,req.call_at,req.alias=n or 0,req.calls+1,now,c.alias
        local ok,e=link.request(string.format('travel %s %d %d',c.alias,c.index,c.number))
        if not ok then finish('failed',e) end
    end
    -- The name this game holds for a camp ({index=, number=}), or nil: FNAME_Find gives NAME_None for a name it does
    -- not know, and the name must read back as the alias.
    local function name_of(alias)
        local n=U.value_of(FName(alias,EFindName.FNAME_Find))
        local index=n:GetComparisonIndex()
        if not index or index==0 or U.text(n):lower()~=alias:lower() then return nil end
        return {alias=alias,index=index,number=Travel.number(alias)}
    end
    -- The host's answer to our camps?: "<world> <alias>:<m> ..." or "none <why>".
    local function choose(rest)
        local world,tail=rest:match('^(%S+) (.+)$')
        if world=='none' then
            return finish(({nocamp='none',busy='busy',loading='busy'})[tail] or 'failed','the host has none: '..tail)
        end
        local list={}
        for alias in (tail or ''):gmatch('([%w_]+):%d+') do
            local on,unread=activated(alias)
            if not (CAMP[alias] and CAMP[alias].world==world) then
                log('travel: '..alias..' is no travel camp of '..world)
            elseif not on then
                log('travel: '..alias..(on==nil and ': no read of the camps this save has activated ('..unread..')'
                    or ' is not activated in this save'))
            else
                local c=name_of(alias)
                if c then list[#list+1]=c else log('travel: '..alias..' is not a name in this game yet') end
            end
        end
        req.list,req.i,req.calls=list,0,0
        call_next()
    end
    -- cleared follows only an accepted call (the block went before it started: a quick warp, or SB dropped it).
    local function result(state,n)
        if state=='pending' or state=='warping' or state=='arrived' or state=='refused:cleared' then
            accepted,watch,offer.quiet=now,{n=n,map=(Where.me() or {}).map,quiet=req.probe or req.quiet},true
            hop=not req.probe and not req.spot and {n=n} or nil
            log('travel accepted: '..req.alias..(state=='refused:cleared' and ', its warp block already gone' or ''))
            return finish('going','SB took the travel')
        end
        local reason=state:match('^refused:(.+)$') or state
        if reason=='game' and req.list then -- SB's refusal of a camp: the next camp.
            log('travel: SB refused '..req.alias)
            return call_next()
        end
        finish(BUSY[reason] and 'busy' or 'failed','the native part refused: '..reason)
    end
    local function pump()
        if req and not req.probe and not linked(req.target) then -- The session ended: the travel with it, no notice.
            log('travel'..(req.alias and ' '..req.alias or '')..': dropped, the session ended')
            req=nil
        end
        if req and req.spot and not req.call_at then
            local _,answer=link.spots()
            local got,rest=(answer or ''):match('^(%d+) (.+)$')
            if tonumber(got)==req.id then landed(rest)
            elseif now-req.at>=ANSWER then
                finish('busy','no answer from '..(req.target and 'member '..req.target or 'the host')..' in 10 s')
            end
        elseif req and not req.spot and not req.list then
            local _,answer=link.camps()
            local got,rest=(answer or ''):match('^(%d+) (.+)$')
            if tonumber(got)==req.id then choose(rest)
            elseif now-req.at>=ANSWER then finish('failed','no answer from the host in 10 s') end
        elseif req then
            local state,n=native()
            if n and n>req.handled then result(state,n)
            elseif now-req.call_at>=RESULT then finish('failed','no answer from the native part in 5 s') end
        end
        if watch then -- After an accepted call: a warp that never started, once.
            local state,n=native()
            if n==watch.n and state=='refused:stuck' then
                log('travel: the warp never started (refused:stuck)')
                if not watch.quiet then tell('failed') end
                stuck,watch=watch.map,nil
            elseif n~=watch.n or state~='pending' and state~='warping' then watch=nil end
        end
        local me=Where.me()
        if stuck and me and me.map and me.map~=stuck then stuck=nil end
    end
    local function start()
        local text,kind=check()
        if text then
            log('travel refused: '..text)
            if kind then tell(kind) end
            return false,text
        end
        local host,mine=where()
        if host==mine then return ask() end
        id=(id+1)%65536
        local ok,e=link.request('camps? '..id)
        if not ok then return false,e end
        req,asked_at={id=id,at=now},now
        return true,"asked the host's game for the camps nearest them (camps? "..id..')'
    end
    -- The offer's place: the host's map while it differs from ours, far on ours, nil when neither, or false while it
    -- cannot be told (a load on either side, his ghost not shown on our map): the offer then waits as it is.
    local function place()
        local host,mine,m=where()
        if not (host and mine) or host==mine and not m then return false end
        if host~=mine then return 'map '..host end
        if m>FAR or offer.key=='far '..mine and m>NEAR then return 'far '..mine end
        return nil
    end
    -- An offer shows once nothing but a guard of the moment (busy) or a travel under way stands in the way.
    local function offerable()
        local text,kind=check()
        return not text or kind=='busy' or text=='a travel is under way'
    end
    local function follow()
        if not guest() or settings.follow_host=='off' then offer={}; return end
        local key=place()
        if key==false then return end
        -- The travel over: the place it brought her to is taken as seen, also when it reads as the one before (her
        -- camp 100 to 150 m from him on his map) or the warp never started.
        if offer.quiet and not req and not watch then offer.key,offer.quiet=key,false end
        if key~=offer.key and (not key or offerable()) then
            offer.key,offer.due=key,nil
            if not key or offer.quiet then offer.quiet=false -- The place a travel brought her to: no offer.
            elseif not settings.follow_key.key then log('travel: no notice for '..key..' (follow_key=none)')
            elseif settings.follow_host=='always' then
                offer.due=now+AUTO
                tell('auto',function(w) return {o.name(w),settings.follow_key.name} end)
            else
                local host=host_ghost().her_map():match('([^/]+)$')
                tell('offer',function(w) return {o.name(w),host,settings.follow_key.name} end)
            end
        end
        -- Switched to ask, or the key to none, during the 5 s: nothing starts.
        if offer.due and (settings.follow_host~='always' or not settings.follow_key.key) then offer.due=nil end
        if offer.due and now>=offer.due then
            offer.due=nil
            start()
        end
    end
    -- The camps of world on our EVE's map, nearest first ({alias=, m=whole metres}). Once a map, the spawn points named
    -- after a camp of its world; a read that found none again a minute later, since a map's spawn points may not all be
    -- loaded when its EVE first shows.
    local function nearest(me,world)
        if cache.map~=me.map or #cache.list==0 and now-cache.at>=PLACE then
            local list,seen={},{}
            U.each(FindAllOf('SBSpawnPoint') or {},function(_,sp)
                sp=U.valid(sp)
                local alias=sp and U.text(sp.SpawnPointName)
                if alias and not seen[alias] and CAMP[alias] and CAMP[alias].world==world then
                    seen[alias]=true
                    local p=U.value_of(sp:K2_GetActorLocation())
                    list[#list+1]={alias=alias,at={X=p.X,Y=p.Y,Z=p.Z}}
                end
            end)
            cache={map=me.map,list=list,at=now}
            log(string.format('travel: %d travel camps among the spawn points of %s',#list,me.map))
        end
        local camps={}
        for _,c in ipairs(cache.list) do
            local m=math.sqrt((c.at.X-me.at.X)^2+(c.at.Y-me.at.Y)^2+(c.at.Z-me.at.Z)^2)/100
            camps[#camps+1]={alias=c.alias,m=math.min(65535,math.floor(m+0.5))}
        end
        table.sort(camps,function(a,b) return a.m<b.m or a.m==b.m and a.alias<b.alias end)
        return camps
    end
    local function host()
        if link.mode()~='host' or link.others()==0 then answered=nil; return end
        local asked=link.camps()
        if not asked or asked==answered then return end
        answered=asked
        local _,title=Where.world()
        local me=Where.me()
        local world=me and WORLD[me.map]
        local reason=title and 'title' or not me and 'loading' or not world and 'nocamp'
            or not line('engine'):find(' warp=idle',1,true) and 'busy' or nil
        local camps={}
        if not reason then
            camps=nearest(me,world)
            if #camps==0 then reason='nocamp' end
        end
        local text='camps '..asked..' '..(reason and 'none '..reason or world)
        for i=1,math.min(#camps,SENT) do text=text..' '..camps[i].alias..':'..camps[i].m end
        link.request(text)
        log('travel: answered '..text)
    end
    -- The host's row in the session list: the rules word, then its place once EVE stands on a map (none at the title or
    -- in a load); a map outside the camp table goes with no camp.
    -- A refusal is logged once until it changes or the ask goes through (a request file that cannot be written would
    -- come back every 250 ms).
    local refused={}
    local function said(kind,ok,why)
        if ok~=false then refused[kind]=nil
        elseif refused[kind]~=why then refused[kind]=why; log(kind..' not asked: '..tostring(why)) end
    end
    local function rows()
        if link.mode()~='host' or link.match() then return end
        said('rules',link.rules(Link.rules(settings)))
        local me=Where.me()
        if not me or placed and placed.map==me.map and now-placed.at<PLACE then return end
        placed={map=me.map,at=now}
        local world=WORLD[me.map]
        local camp=world and nearest(me,world)[1]
        said('where',link.where(me.map:match('([^/]+)$') or '',camp and camp.alias))
    end
    -- A whole number within most (a coordinate or a yaw), or nil: one not finite or past most is none.
    local function whole(v,most)
        local r=math.floor(v+0.5)
        if math.abs(r)<=most then return r end
    end
    local function linked_any()
        local mode=link.mode()
        return (mode=='host' or mode=='guest') and link.others()>0
    end
    -- Every member while linked: our last ground point, kept while EVE walks on a floor; another map or EVE drops it.
    local function ground()
        if not linked_any() then return end
        local eve,me=P.her(),Where.me()
        local pawn=eve and U.address(eve)
        if point and (me and me.map~=point.map or pawn and pawn~=point.pawn) then point=nil end
        local move=eve and me and U.valid(eve.CharacterMovement)
        if not (move and GROUND[move.MovementMode]) then return end
        local at,turn=U.value_of(eve:K2_GetActorLocation()),U.value_of(eve:K2_GetActorRotation())
        local x,y,z,yaw=whole(at.X,MAX_AT),whole(at.Y,MAX_AT),whole(at.Z,MAX_AT),whole(turn.Yaw,MAX_YAW)
        if x and y and z and yaw then point={x=x,y=y,z=z,yaw=yaw,at=now,map=me.map,pawn=pawn} end
    end
    -- Every member while linked: each new spot? of the status answered once (the native part sends it to the asker).
    local function answer()
        if not linked_any() then spotted=nil; return end
        local asked=link.spots()
        if not asked or asked==spotted then return end
        spotted=asked
        local _,title=Where.world()
        local me=Where.me()
        local fight=link.fight() or ''
        local reason=title and 'title' or not (me and P.her()) and 'loading' or o.cutscene() and 'busy'
            or Link.solo(link.zone()) and 'solo'
            or fight:find(' boss=',1,true) and not fight:find(' boss=0',1,true) and 'boss'
            or not line('engine'):find(' warp=idle',1,true) and 'busy'
            or not (point and point.map==me.map and now-point.at<FRESH) and 'air' or nil
        local text='spot '..asked..' '..(reason and 'none '..reason or point.x..' '..point.y..' '..point.z..' '..point.yaw)
        link.request(text)
        log('travel: answered '..text)
    end
    -- The second hop: once a camp travel of the follow arrived on the host's map, his spot asked by itself as soon as
    -- the guards pass, until HOP s after the arrival.
    local function second_hop()
        if not hop then return end
        if not hop.at then
            local state,n=native()
            if n~=hop.n or state~='pending' and state~='warping' and state~='arrived' then hop=nil; return end
            local host,mine=where()
            if state~='arrived' or not (host and mine) then return end -- Not there yet, or a load on either side.
            if host~=mine then hop=nil; return end
            hop.at=now
        end
        local text=check()
        if not text then
            hop=nil
            local ok,e=ask(nil,true)
            if not ok then log('travel: no second hop: '..e) end
        elseif now-hop.at>=HOP then
            hop=nil
            log('travel: no second hop: '..text)
        end
    end
    -- One part's Lua error turns the follow off for the run, with one line.
    local function guard(f,...)
        if off then return false,'the follow is off for this run (see the log)' end
        local ok,a,b=pcall(f,...)
        if ok then return a,b end
        off,req=true,nil
        log('travel off for this run: '..why(a))
        return false,why(a)
    end
    -- Every 250 ms (main.lua's loop); t: its clock in seconds.
    function self.tick(t)
        now=t
        guard(function() ground(); answer(); host(); rows(); follow(); second_hop(); pump() end)
    end
    -- follow_key and coop travel host: the group's return first (o.back), then always's start cancelled, or the travel
    -- started.
    function self.press()
        if o.back then
            local ok,text=o.back()
            if ok~=nil then return ok,text end
        end
        return guard(function()
            if offer.due then
                offer.due=nil
                log('travel: the travel 5 s after the host settled was cancelled (follow_key)')
                return true,'travel cancelled'
            end
            return start()
        end)
    end
    -- Why coop travel probe cannot call now, or nil. any: a camp outside the table (coop mxiii's,
    -- world/maps/matrix13/level/travel.lua).
    local function refusal(alias,any)
        local mode=link.mode()
        if mode==nil then return 'the Steam link is not ready yet: try again in a moment' end
        if mode~='none' then return 'coop travel probe is solo only: leave the session first (coop leave)' end
        local slot=line('slot')
        if not slot:find('^slot=coop ') then
            return 'coop travel probe runs on a co-op save only (name slot 04 in StellarCoopSlot.txt); now '
                ..(slot~='' and slot or 'no slot status')
        end
        if not any and (type(alias)~='string' or not CAMP[alias]) then
            return 'not one of the 120 travel camps: '..tostring(alias)
        end
        -- The follow's activation guard: a table camp may be one of the camp achievements' rows.
        if not any then
            local on,unread=activated(alias)
            if on==nil then return 'no read of the camps this save has activated ('..unread..')' end
            if not on then return alias..' is not activated in this save' end
        end
        local state=native()
        if not state then return 'no travel in the native part (engine off, or coop off)' end
        if state=='refused:fault' then return 'the native travel stopped by a fault (coop-link.log)' end
        if req or state=='pending' or state=='warping' then return 'a travel is under way' end
        if now-accepted<WAIT then return 'the last travel was under 10 s ago' end
    end
    -- The group's return (online/group/group.lua): the spot warp next to member id on our map. true and what was asked,
    -- or false and why; refusals, none answers and silence go to the log only (the return says its own notices).
    function self.go(target)
        return guard(function()
            local text=check(false,target)
            if text then
                log('travel refused: '..text)
                return false,text
            end
            return ask(target,true)
        end)
    end
    -- coop travel spot [<world>] <x> <y> <z>: the spot warp alone (yaw 0), under coop travel probe's guards; a world of
    -- core/worlds.lua goes as its FName, which FNAME_Find must know.
    function self.spot(a,b,c,d)
        return guard(function()
            local text=refusal(nil,true)
            if text then return false,text end
            local world,words=nil,{a,b,c}
            if d~=nil then world,words=a,{b,c,d} end
            local at={}
            for i,w in ipairs(words) do
                local v=tonumber(w)
                at[i]=v and math.tointeger(v)
                if not at[i] or math.abs(at[i])>MAX_AT then
                    return false,'x, y and z are whole centimetres within 10000000: '..tostring(w)
                end
            end
            local tail=''
            if world then
                if not Travel.WORLDS[world] then return false,world..' is not a world of core/worlds.lua' end
                local n=name_of(world)
                if not n then return false,world..' is not a name in this game yet (FNAME_Find)' end
                tail=' '..world..' '..n.index..' '..n.number
            end
            req={probe=true,spot=true,at=now}
            call_spot(table.concat(at,' ')..' 0'..tail)
            return true,'travel spot asked: the result follows in this log and in coop-link.log'
        end)
    end
    -- coop mxiii leave's choice: the travel camps the read lists as activated, in its order, and the camp EVE respawns
    -- at (any alias, nil when unknown); or nil and why without a read.
    function self.camps()
        return guard(function()
            local list,rested=read()
            if not list then return nil,rested end
            local camps={}
            for _,alias in ipairs(list) do if CAMP[alias] then camps[#camps+1]=alias end end
            return camps,rested
        end)
    end
    -- The bike's paid fetch (vehicles/bike/ride.lua): the camp of the table under world, on that world's map, that the
    -- read lists as activated and whose spawn point stands within metres of our EVE, nearest first; else nil. It walks
    -- the spawn points once a map, as nearest() does.
    function self.camp_near(world,metres)
        return guard(function()
            local me=Where.me()
            if not (me and me.map==Travel.WORLDS[world]) then return nil end
            for _,c in ipairs(nearest(me,world)) do
                if c.m>metres then return nil end
                if activated(c.alias) then return c.alias end
            end
        end)
    end
    -- coop mxiii's check before it adds its rows: true, or false and why a probe would be refused now.
    function self.ready()
        return guard(function()
            local text=refusal(nil,true)
            return text==nil,text
        end)
    end
    -- coop travel probe <camp>: the native call alone, for one of the table's camps (any: any camp, coop mxiii's).
    function self.probe(alias,any)
        return guard(function()
            local text=refusal(alias,any)
            if text then return false,text end
            local c=name_of(alias)
            if not c then return false,alias..' is not a name in this game yet (FNAME_Find)' end
            req={probe=true,at=now,list={c},i=0,calls=0}
            call_next()
            return true,'travel '..alias..' asked: the result follows in this log and in coop-link.log'
        end)
    end
    return self
end
return Travel
