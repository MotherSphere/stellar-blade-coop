-- session/travel.lua over fakes of the game, core/link.lua and partner/puppet.lua. The camp table: 120 travel camps,
-- each on one of the 12 story worlds, no autosave volume, no camp of a developer test world and none that leads to
-- several worlds (together only: such a camp is never sent by the host's game nor accepted by the guest's). The host's
-- answer: its cache of the map's spawn points named after a camp of its world, built once a map and never during a
-- load, the 8 nearest its EVE first, and none with why (title, loading, nocamp, busy). The guest's choice: the first
-- camp of the answer in her table under the host's world that her save has activated and that this game knows as a name
-- (FNAME_Find, never a new name; UE's trailing number split off), the next one after SB's refusal, 3 calls at most,
-- then the notices. Without a read of her activated camps: no offer, and every travel refused. The offer: once per host
-- map change or once the host stands more than 150 m away on her map (follow_host=ask), the travel by itself 5 s later
-- with follow_key to cancel (always), nothing with off or with follow_key=none; no new offer for the place the travel
-- brought her to, and his next move offered again after it. The guards, each refusing on its own (silent, busy or
-- failed), again right before the call; the stuck warp; and coop travel probe: solo, on a co-op save only, any of the
-- 120 camps, only an activated one, and for coop mxiii its guards alone (ready: also the native warp, the 10 s after a
-- travel SB took and the travel's fault) and a camp in no table, without the activation read.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local T=require('ui.text')
local W -- The world of one case.
local function uobject(t)
    t.type=function() return 'UObject' end
    t.IsValid=t.IsValid or function() return true end
    return t
end
EFindName={FNAME_Find=1}
FName=function(text,find)
    assert(find==EFindName.FNAME_Find,'never a new name')
    W.fnames[#W.fnames+1]=text
    local index=W.names[text] or 0
    return uobject({GetComparisonIndex=function() return index end,
        ToString=function() return index==0 and 'None' or text end})
end
FindAllOf=function(class)
    assert(class=='SBSpawnPoint',class)
    W.finds=W.finds+1
    local list={}
    for _,s in ipairs(W.spawns) do
        list[#list+1]=uobject({SpawnPointName=s[1],K2_GetActorLocation=function() return {X=s[2],Y=s[3],Z=s[4]} end})
    end
    return list
end
local Travel=require('session.travel')
local XION=Travel.WORLDS.Xion
local DEDA=Travel.WORLDS.DrownedEidosDistrict
local ENGINE='engine=on reason=pinned build 24463856 remote=3 1 peer'
local FIGHT='fight=on mode=on role=guest pairs=1 kills=0 bosses=off boss=0 battle=0 epoch=1/1/0'
local clock=0
local function world(change)
    W={mode='guest',linked=true,slot='slot=coop index=1 marker=1 saves=coop',travel='idle',calls=0,
        warp='idle',life={state=1,hp=1600},fight=FIGHT,me={at={X=0,Y=0,Z=0},map=DEDA},her_map=XION,ghost=nil,
        settings={follow_host='ask',follow_key={key='F7',name='F7'}},names={},fnames={},spawns={},finds=0,
        requests={},said={},logs={},paused=false,night=false,cutscene=false,activated=function() return true end}
    if change then change(W) end
    clock=0
    local link={mode=function() return W.mode end,friend=function() return 'Kaanta',W.linked,false end,
        status=function()
            local engine=W.engine or ENGINE..' warp='..W.warp..' me=4242 travel='..W.travel..' travel_calls='..W.calls
            return 'mod=v proto=12 steam=ready\nlink='..W.mode..' lobby=7\n'..W.slot..'\n'..engine..'\n'
        end,
        camps=function() return W.asked,W.answer end,
        request=function(line) W.requests[#W.requests+1]=line; return true,'asked the native part: '..line end,
        life=function() return W.life end,fight=function() return W.fight end}
    local puppet={me=function() return W.me end,her_map=function() return W.her_map end,
        anchor=function() if W.ghost then return {X=W.ghost.X,Y=W.ghost.Y,Z=W.ghost.Z+220},W.ghost end end,
        world=function() return W.me~=nil,W.title==true end}
    return Travel.new({link=link,puppet=puppet,settings=W.settings,
        tell=function(build) W.said[#W.said+1]=build(T.en) end,
        name=function() return 'Kaanta' end,log=function(m) W.logs[#W.logs+1]=m end,
        paused=function() return W.paused end,night=function() return W.night end,
        cutscene=function() return W.cutscene end,activated=W.activated})
end
local function run(t,seconds) -- Ticks of 250 ms, as main.lua's loop gives them.
    for _=1,math.floor(seconds/0.25+0.5) do
        clock=clock+0.25
        t.tick(clock)
    end
end
local function logged(text)
    for _,line in ipairs(W.logs) do if line:find(text,1,true) then return line end end
end
local function last(list) return list[#list] end
-- The id of the last camps? asked.
local function asked_id() return tonumber(last(W.requests):match('^camps%? (%d+)$')) end
local W_ = T.en.travel
local OFFER=W_.offer:format('Kaanta','e04','F7')
local GOING,NONE,BUSY,FAILED=W_.going:format('Kaanta'),W_.none:format('Kaanta'),W_.busy,W_.failed

-- The table: 120 rows, each alias once, a travel camp type, one of the 12 story worlds (each with its map, as
-- core/unreal.lua's map_of names it). No autosave volume, no developer test world, none that leads to several worlds or
-- to none.
local types,worlds,seen={},{},{}
for _,row in ipairs(Travel.CAMPS) do
    local alias,kind,w=row[1],row[2],row[3]
    assert(#row==3 and not seen[alias] and alias:match('^[%w_]+$') and #alias<=64,alias)
    seen[alias]=true
    types[kind]=(types[kind] or 0)+1
    assert(Travel.WORLDS[w],alias..': '..tostring(w))
    worlds[w]=true
    assert(not alias:find('_SV') and not alias:find('SysTest') and not alias:find('CombatTest'),alias)
end
assert(#Travel.CAMPS==120 and types.FullCamp==44 and types.SimplyCamp==52 and types.PhoneBooth==17
    and types.Tetrapod==7 and not types.SaveVolume)
local nworlds=0
for w,map in pairs(Travel.WORLDS) do
    nworlds=nworlds+1
    assert(worlds[w] and map==map:lower() and map:match('^/game/[%w_/]+$') and not map:find('test',1,true),w)
end
assert(nworlds==12)
for _,gone in ipairs({'SE02_Camp_02','WLB10_Camp_05','SysTest_Camp_00','SysTest_Camp_01','SysTest_Nikke_Camp_00',
    'CombatTestMapMk2_Camp_01','SE01_Camp_01','SE08_Camp_02','ATL_Camp_01_05_SV'}) do assert(not seen[gone],gone) end
assert(seen.Xion_Camp_10 and seen.Xion_Camp_10_01 and seen.DED10_Camp_07 and seen.SE01_Camp_00)
-- UE's number: a trailing _<digits> without a leading zero is split off (number + 1); '_01' is not.
assert(Travel.number('Xion_Camp_10')==11 and Travel.number('Xion_Camp_10_01')==0 and Travel.number('A_0')==1
    and Travel.number('ABC')==0 and Travel.number('A_99999999999')==0)

-- The host: camps?=<id> answered once with its world and the 8 travel camps of its world nearest its EVE, in whole
-- metres, nearest first. Spawn points that are no travel camp of its world (another world's camp, an autosave volume,
-- a developer test world's camp, a plain spawn point) are never sent. The cache is built once a map: a second
-- camps? reads no spawn point, a new map builds it again.
local t=world(function(w)
    w.mode='host'
    w.me={at={X=0,Y=0,Z=0},map=XION}
    w.spawns={{'Xion_Camp_10',1000,0,0},{'Xion_Camp_10_01',300,400,0},{'DED10_Camp_07',50,0,0},
        {'ATL_Camp_01_05_SV',60,0,0},{'SysTest_Camp_01',70,0,0},{'PlayerStart_01',80,0,0}}
    for i=1,9 do w.spawns[#w.spawns+1]={'Xion_'..i,0,0,0} end -- Names the table does not hold.
end)
local xion={} -- Every Xion camp of the table, 20 m apart from 100 m on.
for _,row in ipairs(Travel.CAMPS) do if row[3]=='Xion' then xion[#xion+1]=row[1] end end
assert(#xion==8)
for i,alias in ipairs(xion) do
    if alias~='Xion_Camp_10' and alias~='Xion_Camp_10_01' then W.spawns[#W.spawns+1]={alias,10000+i*2000,0,0} end
end
run(t,0.25)
assert(#W.requests==0 and W.finds==0,'Nothing asked: nothing read')
W.asked=41
run(t,0.25)
local answer=last(W.requests)
assert(#W.requests==1 and W.finds==1 and answer:find('^camps 41 Xion Xion_Camp_10_01:5 Xion_Camp_10:10 '),answer)
local n=0
for alias,m in answer:gmatch(' ([%w_]+):(%d+)') do
    n=n+1
    local found=false
    for _,x in ipairs(xion) do found=found or x==alias end
    assert(found and tonumber(m)<=65535,alias)
end
assert(n==8 and not answer:find('DED10') and not answer:find('_SV') and not answer:find('SysTest'),answer)
run(t,1)
assert(#W.requests==1,'Each id once')
W.asked=42
run(t,0.25)
assert(#W.requests==2 and W.finds==1 and last(W.requests):find('^camps 42 Xion '),'The cache holds for the map')
W.me={at={X=0,Y=0,Z=0},map=DEDA}
W.spawns={{'DED10_Camp_07',200000000,0,0}}
W.asked=43
run(t,0.25)
assert(W.finds==2 and last(W.requests)=='camps 43 DrownedEidosDistrict DED10_Camp_07:65535',last(W.requests))
-- None and why: no EVE (a load, and no spawn point read then), the title, a map no travel camp is on, its own warp in
-- flight, a map with none of its camps loaded.
for _,case in ipairs({{function(w) w.me=nil end,'loading'},{function(w) w.me=nil; w.title=true end,'title'},
    {function(w) w.me.map='/game/gamedesign/test/level/systest/systest_p' end,'nocamp'},
    {function(w) w.warp='busy' end,'busy'},{function(w) w.spawns={{'PlayerStart_01',0,0,0}} end,'nocamp'}}) do
    t=world(function(w) w.mode='host'; w.me={at={X=0,Y=0,Z=0},map=XION} end)
    case[1](W)
    W.asked=7
    run(t,0.25)
    assert(last(W.requests)=='camps 7 none '..case[2],tostring(last(W.requests)))
    assert(case[2]=='busy' or case[2]=='nocamp' and W.me and W.me.map==XION or W.finds==0)
end

-- The guest: the host on another map, an offer once (follow_host=ask), follow_key asks the host's camps. Of the
-- answer, a name not in her table, a camp of another world and one this game does not know (FNAME_Find gives None)
-- are skipped; the first that passes is asked of the native part with its FName (Xion_Camp_10: Xion_Camp and 11).
-- An accepted call: the going notice, and no other offer for the place it brings her to.
t=world(function(w) w.names={Xion_Camp_10=4096,SE01_Camp_00=77} end)
run(t,1)
assert(#W.said==1 and W.said[1]==OFFER and #W.requests==0,table.concat(W.said,'|'))
run(t,5)
assert(#W.said==1,'Once a host map')
W.me=nil -- A load of hers: no new offer after it.
run(t,1)
W.me={at={X=0,Y=0,Z=0},map=DEDA}
run(t,1)
assert(#W.said==1,'Once a host map, her loads aside')
assert(t.press())
local id=asked_id()
assert(id and #W.requests==1)
W.answer=(id+1)..' Xion Xion_Camp_10:1' -- Another id: never taken.
run(t,1)
assert(#W.requests==1)
W.answer=id..' Xion X1:5 SE01_Camp_00:8 Xion_Camp_20:9 Xion_Camp_10:30 Xion_Camp_10_01:40'
run(t,0.25)
assert(last(W.requests)=='travel Xion_Camp_10 4096 11',last(W.requests))
assert(logged('X1 is no travel camp of Xion') and logged('SE01_Camp_00 is no travel camp of Xion')
    and logged('Xion_Camp_20 is not a name in this game yet'))
for _,name in ipairs(W.fnames) do assert(name~='X1' and name~='SE01_Camp_00','Only her own table reaches FName') end
run(t,1)
assert(#W.said==1,'Waiting for the native part')
W.travel,W.calls='pending',1
run(t,0.25)
assert(last(W.said)==GOING and #W.said==2,last(W.said))
W.me={at={X=0,Y=0,Z=0},map=XION} -- She arrives 300 m from him: no new offer.
W.ghost={X=30000,Y=0,Z=0}
W.travel='arrived'
run(t,2)
assert(#W.said==2,last(W.said))
W.ghost={X=500,Y=0,Z=0} -- She walks to him, he walks away again: a new offer.
run(t,0.5)
W.ghost={X=20000,Y=0,Z=0}
run(t,0.5)
assert(#W.said==3 and last(W.said)==OFFER,last(W.said))
-- Within 10 s of the accepted call: busy.
assert(not t.press() and last(W.said)==BUSY)

-- SB refuses (a return of 0): the next camp at once, 3 calls at most, then none.
t=world(function(w) w.names={Xion_Camp_10=1,Xion_Camp_10_01=2,Xion_Camp_20=3,Xion_Camp_10_02=4} end)
assert(t.press())
id=asked_id()
W.answer=id..' Xion Xion_Camp_10:1 Xion_Camp_10_01:2 Xion_Camp_20:3 Xion_Camp_10_02:4'
run(t,0.25)
assert(last(W.requests)=='travel Xion_Camp_10 1 11')
W.travel,W.calls='refused:game',1
run(t,0.25)
assert(last(W.requests)=='travel Xion_Camp_10_01 2 0')
W.calls=2
run(t,0.25)
assert(last(W.requests)=='travel Xion_Camp_20 3 21')
W.calls=3
run(t,0.25)
assert(#W.requests==4 and last(W.said)==NONE,last(W.said))
-- None of the answer passes: none at once. The host has none: none for nocamp, busy while its game is busy or loading,
-- failed for the title.
t=world()
assert(t.press())
W.answer=asked_id()..' Xion Xion_Camp_10:1'
run(t,0.25)
assert(#W.requests==1 and last(W.said)==NONE)
for _,case in ipairs({{'nocamp',NONE},{'busy',BUSY},{'loading',BUSY},{'title',FAILED}}) do
    t=world()
    assert(t.press())
    W.answer=asked_id()..' none '..case[1]
    run(t,0.25)
    assert(last(W.said)==case[2] and #W.requests==1,case[1])
end
-- A camp her save has not activated is never asked of the native part: SB's fast travel does not check it, and a
-- travel that activated it would count toward the camp achievements. None activated: none.
t=world(function(w)
    w.names={Xion_Camp_10=1,Xion_Camp_10_01=2}
    w.activated=function(alias) return alias=='Xion_Camp_10_01' end
end)
assert(t.press())
W.answer=asked_id()..' Xion Xion_Camp_10:1 Xion_Camp_10_01:2'
run(t,0.25)
assert(last(W.requests)=='travel Xion_Camp_10_01 2 0' and logged('Xion_Camp_10 is not activated in this save'))
for _,name in ipairs(W.fnames) do assert(name~='Xion_Camp_10','An unactivated camp never reaches FName') end
t=world(function(w) w.names={Xion_Camp_10=1}; w.activated=function() return false end end)
assert(t.press())
W.answer=asked_id()..' Xion Xion_Camp_10:1'
run(t,0.25)
assert(#W.requests==1 and last(W.said)==NONE)
-- No read of her activated camps (main.lua passes none yet): no offer with ask or always, and F7 or coop travel host
-- is refused with the failed notice before anything is asked.
for _,mode in ipairs({'ask','always'}) do
    t=world(function(w) w.settings.follow_host=mode; w.activated=nil; w.names={Xion_Camp_10=1} end)
    run(t,10)
    assert(#W.said==0 and #W.requests==0,mode)
    local ok,why=t.press()
    assert(not ok and why:find('no read of the camps',1,true) and #W.requests==0 and last(W.said)==FAILED,mode)
end
-- One camps? each 2.5 s (the host's game takes one each 2 s; the margin is for the network): a press sooner is
-- refused in the log only.
t=world()
assert(t.press())
W.answer=asked_id()..' none nocamp'
run(t,2.25)
local ok2,why2=t.press()
assert(not ok2 and why2:find('each 2.5 s',1,true) and #W.requests==1 and last(W.said)==NONE)
run(t,0.25)
assert(t.press() and #W.requests==2)
-- An answer from a test world, or a camp of another world, is never asked of the native part.
t=world(function(w) w.names={SysTest_Camp_01=9,DED10_Camp_07=8} end)
assert(t.press())
W.answer=asked_id()..' SysTest_P SysTest_Camp_01:1 DED10_Camp_07:2'
run(t,0.25)
assert(#W.requests==1 and last(W.said)==NONE)
-- The session ends while the host's answer is awaited: the travel is dropped, with no notice.
t=world()
assert(t.press())
W.linked=false
run(t,11)
assert(#W.said==0 and logged('dropped, the session ended'))
-- No answer in 10 s, or no word from the native part in 5 s: failed.
t=world()
assert(t.press())
run(t,9.75)
assert(#W.said==1 and W.said[1]==OFFER)
run(t,0.25)
assert(last(W.said)==FAILED)
t=world(function(w) w.names={Xion_Camp_10=1} end)
assert(t.press())
W.answer=asked_id()..' Xion Xion_Camp_10:1'
run(t,5.25)
assert(last(W.said)==FAILED and #W.requests==2)
-- The native part's own refusals: busy for the wait, the count, a warp or respawn in flight and the client not in game;
-- failed for the rest.
for _,case in ipairs({{'refused:warp',BUSY},{'refused:calls',BUSY},{'refused:flow',BUSY},{'refused:player',FAILED},
    {'refused:tables',FAILED}}) do
    t=world(function(w) w.names={Xion_Camp_10=1} end)
    assert(t.press())
    W.answer=asked_id()..' Xion Xion_Camp_10:1'
    run(t,0.25)
    W.travel,W.calls=case[1],1
    run(t,0.25)
    assert(last(W.said)==case[2] and #W.requests==2,case[1])
end
-- A warp that never starts (refused:stuck): failed, and no travel on this map until she is on another.
t=world(function(w) w.names={Xion_Camp_10=1} end)
assert(t.press())
W.answer=asked_id()..' Xion Xion_Camp_10:1'
run(t,0.25)
W.travel,W.calls='pending',1
run(t,0.25)
W.travel='refused:stuck'
run(t,0.25)
assert(last(W.said)==FAILED)
run(t,10)
local said=#W.said
assert(not t.press() and #W.said==said+1 and last(W.said)==FAILED and #W.requests==2)
W.me={at={X=0,Y=0,Z=0},map='/game/art/bg/worldmap/level_p/f01'}
assert(t.press() and #W.requests==3)
-- The stuck warp ends the travel's quiet too: on another map of hers, his next map change is offered.
t=world(function(w) w.names={Xion_Camp_10=1} end)
run(t,0.25)
assert(t.press())
W.answer=asked_id()..' Xion Xion_Camp_10:1'
run(t,0.25)
W.travel,W.calls='pending',1
run(t,0.25)
W.travel='refused:stuck'
run(t,0.25)
assert(#W.said==3 and last(W.said)==FAILED,last(W.said))
W.me={at={X=0,Y=0,Z=0},map='/game/art/bg/worldmap/level_p/f01'}
run(t,0.5)
W.her_map=Travel.WORLDS.SpaceElevator
run(t,3)
assert(#W.said==4 and last(W.said)==W_.offer:format('Kaanta','b07','F7'),last(W.said))
-- The place a travel brought her to is taken as seen also when it reads as the place before: her camp 120 m from him
-- on his map keeps the far offer's place (100 to 150 m), and his next map change is still offered.
t=world(function(w) w.her_map=DEDA; w.ghost={X=40000,Y=0,Z=0}; w.names={DED10_Camp_07=8} end)
run(t,0.25)
assert(#W.said==1 and W.said[1]==W_.offer:format('Kaanta','f02','F7'),W.said[1])
assert(t.press())
W.answer=asked_id()..' DrownedEidosDistrict DED10_Camp_07:3'
run(t,0.25)
assert(last(W.requests)=='travel DED10_Camp_07 8 0',last(W.requests))
W.travel,W.calls='pending',1
run(t,0.25)
assert(last(W.said)==GOING)
W.travel,W.ghost='arrived',{X=12000,Y=0,Z=0}
run(t,1)
assert(#W.said==2,last(W.said))
W.her_map,W.ghost=XION,nil
run(t,2)
assert(#W.said==3 and last(W.said)==OFFER,last(W.said))
-- A warp block gone before the first read (refused:cleared follows an accepted call only): going, then the 10 s wait.
t=world(function(w) w.names={Xion_Camp_10=1} end)
assert(t.press())
W.answer=asked_id()..' Xion Xion_Camp_10:1'
run(t,0.25)
W.travel,W.calls='refused:cleared',1
run(t,0.25)
assert(last(W.said)==GOING and logged('already gone'),last(W.said))
run(t,3)
assert(not t.press() and last(W.said)==BUSY)
-- The guards again right before the call, as the answer can come seconds after the press: a menu opened meanwhile, no
-- call and busy; the host back within 150 m, no call and the log only.
t=world(function(w) w.names={Xion_Camp_10=1} end)
assert(t.press())
W.paused=true
W.answer=asked_id()..' Xion Xion_Camp_10:1'
run(t,0.25)
assert(#W.requests==1 and last(W.said)==BUSY and logged('refused at the call'),last(W.said))
t=world(function(w) w.names={Xion_Camp_10=1} end)
assert(t.press())
W.her_map,W.ghost=DEDA,{X=5000,Y=0,Z=0}
W.answer=asked_id()..' Xion Xion_Camp_10:1'
run(t,0.25)
assert(#W.requests==1 and #W.said==0 and logged('refused at the call: the host is within 150 m')
    and not logged('travel off for this run'))

-- The guards, each refusing on its own. Silent (the log only): not a linked guest, follow_host=off, not a co-op save,
-- no travel in the native part, the host's map unknown or the host within 150 m on hers. Busy: our EVE down, a warp or
-- respawn in flight, the game paused (or photo mode, or a menu), Night Operation, a cutscene, a boss or an enemy in
-- battle near us (while the shared fight runs). Failed: the native part's travel stopped by a fault.
local cases={
    {function(w) w.mode='host' end,'not a guest',nil},
    {function(w) w.linked=false end,'not a guest',nil},
    {function(w) w.settings.follow_host='off' end,'follow_host=off',nil},
    {function(w) w.slot='slot=main index=1 marker=1 saves=main' end,'co-op save',nil},
    {function(w) w.engine=ENGINE end,'no travel in the native part',nil},
    {function(w) w.her_map=nil end,"host's map",nil},
    {function(w) w.her_map=DEDA; w.ghost={X=14000,Y=0,Z=0} end,'within 150 m',nil},
    {function(w) w.her_map=DEDA end,'within 150 m',nil}, -- No ghost on her map: no distance.
    {function(w) w.life={state=3,hp=0} end,'our EVE is down',BUSY},
    {function(w) w.life=nil end,'our EVE is down',BUSY},
    {function(w) w.warp='busy' end,'warp',BUSY},
    {function(w) w.paused=true end,'paused',BUSY},
    {function(w) w.night=true end,'Night Operation',BUSY},
    {function(w) w.cutscene=true end,'cutscene',BUSY},
    {function(w) w.fight=FIGHT:gsub('boss=0','boss=1') end,'boss',BUSY},
    {function(w) w.fight=FIGHT:gsub('battle=0','battle=2') end,'battle',BUSY},
    {function(w) w.travel='refused:fault' end,'stopped by a fault',FAILED},
}
for _,case in ipairs(cases) do
    t=world(case[1])
    local ok,why=t.press()
    assert(not ok and why:find(case[2],1,true) and #W.requests==0,case[2]..': '..tostring(why))
    if case[3] then assert(last(W.said)==case[3],case[2]) else assert(#W.said==0 or W.said[1]~=BUSY,case[2]) end
end
-- The shared fight off: no boss= field, no battle guard. The host 151 m away on her map: allowed.
t=world(function(w) w.fight=nil end)
assert(t.press())
t=world(function(w) w.her_map=DEDA; w.ghost={X=15100,Y=0,Z=0} end)
assert(t.press())

-- The far offer ends only once the host is back within 100 m: none again while he walks between 100 and 150 m.
t=world(function(w) w.her_map=DEDA; w.ghost={X=20000,Y=0,Z=0} end)
run(t,0.25)
assert(#W.said==1 and W.said[1]==W_.offer:format('Kaanta','f02','F7'),W.said[1])
W.ghost={X=12000,Y=0,Z=0}
run(t,0.5)
W.ghost={X=16000,Y=0,Z=0}
run(t,0.5)
assert(#W.said==1)
W.ghost={X=9000,Y=0,Z=0}
run(t,0.5)
W.ghost={X=16000,Y=0,Z=0}
run(t,0.5)
assert(#W.said==2)

-- follow_host=always: the auto notice, the travel 5 s later; follow_key in between cancels it. off: no offer, no
-- travel.
local AUTO=W_.auto:format('Kaanta','F7')
t=world(function(w) w.settings.follow_host='always' end)
run(t,0.25)
assert(W.said[1]==AUTO and #W.requests==0)
run(t,4.75)
assert(#W.requests==0)
run(t,0.25)
assert(asked_id(),'Asked 5 s after the host settled')
t=world(function(w) w.settings.follow_host='always' end)
run(t,2)
assert(t.press() and #W.requests==0 and logged('cancelled'))
run(t,10)
assert(#W.requests==0 and #W.said==1)
t=world(function(w) w.settings.follow_host='always'; w.cutscene=true end)
run(t,5.25)
assert(#W.requests==0 and last(W.said)==BUSY,'A guard at the time: busy, no retry')
run(t,10)
assert(#W.said==2)
t=world(function(w) w.settings.follow_host='off' end)
run(t,10)
assert(#W.said==0 and #W.requests==0)
-- always switched to ask, or follow_key to none, during the 5 s: nothing starts.
local switches={function() W.settings.follow_host='ask' end,function() W.settings.follow_key={name='none'} end}
for _,switch in ipairs(switches) do
    t=world(function(w) w.settings.follow_host='always' end)
    run(t,2)
    switch()
    run(t,5)
    assert(#W.said==1 and #W.requests==0)
end
-- follow_key=none: no notice names a key, always starts nothing; coop travel host still asks.
for _,mode in ipairs({'ask','always'}) do
    t=world(function(w) w.settings.follow_host=mode; w.settings.follow_key={name='none'} end)
    run(t,6)
    assert(#W.said==0 and #W.requests==0 and logged('(follow_key=none)'),mode)
    assert(t.press() and asked_id())
end
-- The offer waits for the silent guards (a co-op save), and comes again when the host's map changes.
t=world(function(w) w.slot='slot=unknown index=? marker=? saves=?' end)
run(t,2)
assert(#W.said==0)
W.slot='slot=coop index=1 marker=1 saves=coop'
run(t,0.25)
assert(#W.said==1 and W.said[1]==OFFER)
W.her_map='/game/art/bg/worldmap/level_p/b07'
run(t,0.25)
assert(#W.said==2 and W.said[2]==W_.offer:format('Kaanta','b07','F7'))

-- coop travel probe: solo only, on a co-op save only (slot 04 of her own saves is refused: StellarCoopSlot.txt makes it
-- one), one of the 120 camps that her save has activated, as the follow takes them, and a name this game knows; it
-- skips the host's answer: the camp is asked of the native part as it is. Its result is logged. Without a read of the
-- activated camps (main.lua passes none yet) every camp is refused: a travel that activated one would count toward the
-- camp achievements.
t=world(function(w) w.mode='none'; w.linked=false; w.names={DED10_Camp_07=55}; w.activated=nil end)
local ok,why=t.probe('DED10_Camp_07')
assert(not ok and why=='no read of the camps this save has activated' and #W.requests==0,tostring(why))
t=world(function(w) w.mode='none'; w.linked=false; w.names={DED10_Camp_07=55}
    w.activated=function(alias) return alias~='DED10_Camp_07' end end)
ok,why=t.probe('DED10_Camp_07')
assert(not ok and why=='DED10_Camp_07 is not activated in this save' and #W.requests==0,tostring(why))
assert(#W.fnames==0,'An unactivated camp never reaches FName')
t=world(function(w) w.mode='none'; w.linked=false; w.names={DED10_Camp_07=55} end)
ok,why=t.probe('DED10_Camp_07')
assert(ok and last(W.requests)=='travel DED10_Camp_07 55 0',why)
W.travel,W.calls='pending',1
run(t,0.25)
assert(logged('travel accepted: DED10_Camp_07') and #W.said==0,'The probe logs, no notice')
for _,case in ipairs({{function(w) w.mode='guest' end,'solo only'},{function(w) w.mode='host' end,'solo only'},
    {function(w) w.mode=nil end,'not ready'},
    {function(w) w.slot='slot=main index=1 marker=4 saves=main' end,'co-op save only'},
    {function(w) w.slot='slot=main index=4 marker=1 saves=main' end,'co-op save only'},
    {function(w) w.names={} end,'not a name'}}) do
    t=world(function(w) w.mode='none'; w.linked=false; w.names={DED10_Camp_07=55}; case[1](w) end)
    ok,why=t.probe('DED10_Camp_07')
    assert(not ok and why:find(case[2],1,true) and #W.requests==0,case[2]..': '..tostring(why))
end
for _,alias in ipairs({'SysTest_Camp_01','ATL_Camp_01_05_SV','SE02_Camp_02','x'}) do
    t=world(function(w) w.mode='none'; w.linked=false; w.names={[alias]=9} end)
    ok,why=t.probe(alias)
    assert(not ok and why:find('120 travel camps',1,true) and #W.requests==0,alias)
end
-- coop mxiii's use (cut/mxiii.lua): ready says whether a probe would pass its guards now, asking nothing; probe with
-- any takes a camp in no table (the name must still be one this game knows), under the same guards but the activation
-- read: no AchievementTable row names its env-spawn row.
t=world(function(w) w.mode='none'; w.linked=false; w.names={DLC02_10_Camp_01=77}; w.activated=nil end)
ok,why=t.ready()
assert(ok==true and why==nil and #W.requests==0 and #W.fnames==0,tostring(why))
ok,why=t.probe('DLC02_10_Camp_01')
assert(not ok and why:find('120 travel camps',1,true) and #W.requests==0,'Not without any')
ok,why=t.probe('DLC02_10_Camp_01',true)
assert(ok and last(W.requests)=='travel DLC02_10_Camp_01 77 0',why)
ok,why=t.ready()
assert(ok==false and why=='a travel is under way','One at a time')
-- Once SB took it: the native warp, then the 10 s the native part waits after an accepted call.
W.travel,W.calls='warping',1
run(t,0.25)
assert(logged('travel accepted: DLC02_10_Camp_01'))
ok,why=t.ready(); assert(ok==false and why=='a travel is under way','The native warp: '..tostring(why))
W.travel='arrived'
ok,why=t.ready(); assert(ok==false and why=='the last travel was under 10 s ago',tostring(why))
run(t,10)
ok,why=t.ready(); assert(ok==true,tostring(why))
for _,case in ipairs({{function(w) w.mode='guest' end,'solo only'},{function(w) w.mode=nil end,'not ready'},
    {function(w) w.slot='slot=main index=1 marker=4 saves=main' end,'co-op save only'},
    {function(w) w.engine='engine=off reason=coop_off' end,'no travel in the native part'},
    {function(w) w.travel='refused:fault' end,'stopped by a fault'}}) do
    t=world(function(w) w.mode='none'; w.linked=false; w.names={DLC02_10_Camp_01=77}; case[1](w) end)
    ok,why=t.ready()
    assert(ok==false and why:find(case[2],1,true) and #W.requests==0,case[2]..': '..tostring(why))
    ok,why=t.probe('DLC02_10_Camp_01',true)
    assert(not ok and why:find(case[2],1,true) and #W.requests==0,case[2]..': '..tostring(why))
end
t=world(function(w) w.mode='none'; w.linked=false end)
ok,why=t.probe('DLC02_10_Camp_01',true)
assert(not ok and why:find('not a name in this game yet',1,true) and #W.requests==0,why)
-- A Lua error turns the follow off for the run, with one line.
t=world(function(w) w.names={Xion_Camp_10=1} end)
FName=nil
assert(t.press())
W.answer=asked_id()..' Xion Xion_Camp_10:1'
run(t,0.25)
assert(logged('travel off for this run') and #W.requests==1)
assert(not t.press())
print('travel_test ok')
