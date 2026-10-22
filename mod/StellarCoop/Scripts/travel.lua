-- Follow the host's fast travel, on the game thread: main.lua ticks it every 250 ms with the Steam link; follow_key,
-- coop travel host and coop travel probe reach it.
-- The guest. When the host's map changes to another than hers, or he stands more than 150 m from her EVE on hers, an
-- offer comes once (follow_host=ask, the default) and follow_key starts the travel; always starts it by itself 5 s
-- later, after a notice, and follow_key then cancels it; off does neither, and follow_key does nothing. With
-- follow_key=none neither ask nor always shows or starts anything (a log line only): coop travel host still travels.
-- No offer comes for the place a travel brought her to. The travel: the guards (check), then camps? <id> to
-- the host's game, whose answer names his world and up to 8 camps nearest his EVE. She takes the first that is in this
-- table under that world, that her save has activated (o.activated) and that this game knows as a name (FName with
-- FNAME_Find, which never makes one), checks the guards again, and asks the native part to call SB's own fast travel
-- with it; after SB's refusal (a return of 0) the next one, 3 calls at most. SB's fast travel does not check activation
-- (travel.h), and a travel that activated a camp would count toward its achievements: without o.activated, which
-- main.lua does not pass yet (no read of the activated camps exists), a guard refuses every travel and no offer shows.
-- Notices: going (the call was taken), none (no camp passed, or SB refused each), busy (a guard of the moment, or the
-- host's game busy or loading), failed (the native part refused, no answer came, the warp never started, or no read of
-- the activated camps; UE4SS.log says why).
-- The host. Its game answers each new camps? from the link's status: its world and the 8 camps of this table under it
-- nearest its EVE, in whole metres, or none and why (title, loading, nocamp, busy). The camps are the map's
-- SBSpawnPoint actors named after a camp of its world, read once a map (FindAllOf walks every object), never during a
-- load.
-- Only the 120 camps of this table are ever sent or taken: no autosave volume, no camp of a developer test world, none
-- that leads to several worlds. The travel moves her EVE only; nothing changes in the host's game.
-- coop travel probe <camp> (a test tool): solo, on a co-op save only, any camp of the table, without the host's
-- answer; it does not check that this save found the camp. A Lua error turns the follow off for the run.
local U=require('unreal')
local Travel={}
-- Each story world's map, as unreal.lua's map_of() names it, from WorldTable's UMapPath.
Travel.WORLDS={AbyssLab='/game/art/bg/worldmap/dungeon_p/abysslab_p',
    AltesLab='/game/art/bg/worldmap/dungeon_p/alteslab_p',Arden='/game/art/bg/worldmap_dlc_01/level_p/ard_p',
    DEDA='/game/art/bg/worldmap/level_p/f01',DrownedEidosDistrict='/game/art/bg/worldmap/level_p/f02',
    MatrixEleven='/game/art/bg/worldmap/dungeon_p/matrix_xi',
    Metropolitan='/game/art/bg/worldmap_dlc_01/level_p/met_p',Nest='/game/art/bg/worldmap/level_p/c05',
    SpaceElevator='/game/art/bg/worldmap/level_p/b07',
    WasteLandA='/game/art/bg/worldmap/e03_wasteland_p/e03_wasteland_p',
    WasteLandB='/game/art/bg/worldmap/e05_greatdesert_p/e05_greatdesert_p',Xion='/game/art/bg/worldmap/level_p/e04'}
-- The travel camps, {alias, type, world}: the ZoneCampTable rows of type FullCamp, SimplyCamp, PhoneBooth or Tetrapod
-- whose ZoneEnvSpawnTable rows (TargetCamp), through each row's zone and ZoneTable's WorldAlias, lead to exactly one
-- world, in the tables of the game's Steam build 24463856. Left out: the SaveVolume rows, the camps that lead to
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
-- s: always's delay; after an accepted call; for an answer; for a result; between two camps? (the host's game takes one
-- each 2 s, and the network can bring two closer together).
local AUTO,WAIT,ANSWER,RESULT,ASK=5,10,10,5,2.5
local CALLS,SENT=3,8 -- Calls a travel at most; camps an answer sends at most.
-- The native part's refusals that pass by themselves (busy); any other is failed.
local BUSY={wait=true,calls=true,warp=true,camp=true,respawn=true,flow=true,phase=true}
-- The FName number UE splits off a name: a trailing _<digits> with no leading zero (or a lone 0), plus 1;
-- Xion_Camp_10 is Xion_Camp with 11, Xion_Camp_10_01 keeps its digits (0).
function Travel.number(alias)
    local digits=alias:match('_(%d+)$')
    if digits and #digits<=10 and (#digits==1 or digits:sub(1,1)~='0') and tonumber(digits)<2147483647 then
        return math.tointeger(tonumber(digits)+1)
    end
    return 0
end
local function why(e) return (tostring(e):gsub('^.-:%d+: ','')) end -- Without the file and line.
-- o: {link=, puppet=, settings= (follow_host, follow_key), tell(build), name(words) (her name, or the words' friend),
-- log(text), paused() (the game paused, photo mode or a menu), night() (a Night Operation run), cutscene() (one plays
-- in our game), activated(alias) (true when her save has activated that camp; nil: no read, no travel)}.
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
    local id=os.time()%65536 -- The guest's last camps? (a new Lua load starts elsewhere, so the host answers again).
    local req=nil -- The travel under way: {id=, at=, probe=, list=, i=, calls=, handled=, call_at=}.
    local accepted,watch,stuck=-math.huge,nil,nil -- The last accepted call; its warp, until it ran; a map it stuck on.
    local asked_at=-math.huge -- Our last camps?: one each ASK s.
    -- The offer: key, the place offered (the host's map, or far on ours); due, always's start; quiet, no offer for the
    -- next place (the one a travel brought her to).
    local offer={}
    local answered,cache=nil,{} -- The host's: the last camps? answered; its camps on cache.map.
    -- The host's map, ours, and the metres between his ghost and our EVE when both are on one map and it shows.
    local function where()
        local me,host=puppet.me(),puppet.her_map()
        local mine=me and me.map
        if not (host and mine) or host~=mine then return host,mine,nil end
        local _,feet=puppet.anchor()
        return host,mine,feet and math.sqrt((feet.X-me.at.X)^2+(feet.Y-me.at.Y)^2+(feet.Z-me.at.Z)^2)/100
    end
    local function guest()
        local _,linked=link.friend()
        return link.mode()=='guest' and linked==true
    end
    -- Why a travel cannot start now, and the notice for it (nil: the log only), or nil when it can. calling: again
    -- right before a call, inside the travel under way.
    local function check(calling)
        if not guest() then return 'not a guest in a session' end
        if settings.follow_host=='off' then return 'follow_host=off' end
        if not o.activated then return 'no read of the camps this save has activated','failed' end
        if not line('slot'):find('^slot=coop ') then return 'not on a co-op save' end
        local state=native()
        if not state then return 'no travel in the native part (engine off, or coop off)' end
        if state=='refused:fault' then return 'the native travel stopped by a fault (coop-link.log)','failed' end
        local host,mine,m=where()
        if stuck and stuck==mine then return 'the last warp never started on this map','failed' end
        if not host then return "the host's map is unknown" end
        if not mine then return 'no EVE (a load)' end
        if host==mine and not (m and m>FAR) then return 'the host is within 150 m' end
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
    local function finish(key,text) -- key nil: the log only.
        log('travel'..(req and req.alias and ' '..req.alias or '')..': '..text)
        if key and not req.probe then tell(key,named) end
        req=nil
    end
    -- The next camp of the list, or none once the list or the 3 calls ran out. The guards again first: the host's
    -- answer can come seconds after the press.
    local function call_next()
        req.i=req.i+1
        local c=req.list[req.i]
        if not c or req.calls>=CALLS then return finish('none','no camp of the answer was taken') end
        if not req.probe then
            local text,kind=check(true)
            if text then return finish(kind,'refused at the call: '..text) end
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
            if not (CAMP[alias] and CAMP[alias].world==world) then
                log('travel: '..alias..' is no travel camp of '..world)
            elseif not o.activated(alias) then
                log('travel: '..alias..' is not activated in this save')
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
            accepted,watch,offer.quiet=now,{n=n,map=(puppet.me() or {}).map,probe=req.probe},true
            log('travel accepted: '..req.alias..(state=='refused:cleared' and ', its warp block already gone' or ''))
            return finish('going','SB took the travel')
        end
        local reason=state:match('^refused:(.+)$') or state
        if reason=='game' then -- SB's refusal: the next camp.
            log('travel: SB refused '..req.alias)
            return call_next()
        end
        finish(BUSY[reason] and 'busy' or 'failed','the native part refused: '..reason)
    end
    local function pump()
        if req and not req.probe and not guest() then -- The session ended: the travel with it, without a notice.
            log('travel'..(req.alias and ' '..req.alias or '')..': dropped, the session ended')
            req=nil
        end
        if req and not req.list then
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
                if not watch.probe then tell('failed') end
                stuck,watch=watch.map,nil
            elseif n~=watch.n or state~='pending' and state~='warping' then watch=nil end
        end
        local me=puppet.me()
        if stuck and me and me.map and me.map~=stuck then stuck=nil end
    end
    local function start()
        local text,kind=check()
        if text then
            log('travel refused: '..text)
            if kind then tell(kind) end
            return false,text
        end
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
                local host=puppet.her_map():match('([^/]+)$')
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
    local function host()
        local _,linked=link.friend()
        if link.mode()~='host' or linked~=true then answered=nil; return end
        local asked=link.camps()
        if not asked or asked==answered then return end
        answered=asked
        local _,title=puppet.world()
        local me=puppet.me()
        local world=me and WORLD[me.map]
        local reason=title and 'title' or not me and 'loading' or not world and 'nocamp'
            or not line('engine'):find(' warp=idle',1,true) and 'busy' or nil
        local camps={}
        if not reason then
            if cache.map~=me.map then -- Once a map: the spawn points named after a camp of its world.
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
                cache={map=me.map,list=list}
                log(string.format('travel: %d travel camps among the spawn points of %s',#list,me.map))
            end
            for _,c in ipairs(cache.list) do
                local m=math.sqrt((c.at.X-me.at.X)^2+(c.at.Y-me.at.Y)^2+(c.at.Z-me.at.Z)^2)/100
                camps[#camps+1]={alias=c.alias,m=math.min(65535,math.floor(m+0.5))}
            end
            table.sort(camps,function(a,b) return a.m<b.m or a.m==b.m and a.alias<b.alias end)
            if #camps==0 then reason='nocamp' end
        end
        local text='camps '..asked..' '..(reason and 'none '..reason or world)
        for i=1,math.min(#camps,SENT) do text=text..' '..camps[i].alias..':'..camps[i].m end
        link.request(text)
        log('travel: answered '..text)
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
        guard(function() host(); follow(); pump() end)
    end
    -- follow_key and coop travel host: always's start cancelled, or the travel started.
    function self.press()
        return guard(function()
            if offer.due then
                offer.due=nil
                log('travel: the travel 5 s after the host settled was cancelled (follow_key)')
                return true,'travel cancelled'
            end
            return start()
        end)
    end
    -- coop travel probe <camp>: the native call alone, for one of the table's camps.
    function self.probe(alias)
        return guard(function()
            local mode=link.mode()
            if mode==nil then return false,'the Steam link is not ready yet: try again in a moment' end
            if mode~='none' then return false,'coop travel probe is solo only: leave the session first (coop leave)' end
            local slot=line('slot')
            if not slot:find('^slot=coop ') then
                return false,'coop travel probe runs on a co-op save only (name slot 04 in StellarCoopSlot.txt); now '
                    ..(slot~='' and slot or 'no slot status')
            end
            if type(alias)~='string' or not CAMP[alias] then
                return false,'not one of the 120 travel camps: '..tostring(alias)
            end
            if not native() then return false,'no travel in the native part (engine off, or coop off)' end
            if req then return false,'a travel is under way' end
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
