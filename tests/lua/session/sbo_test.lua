-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- session/sbo.lua's data and pure rules: the spots, the fence, the row sets, the notices and the entry checks; then
-- Sbo.new over a fake world (the native part's sbo line as link.sbo() gives it, a player controller that counts its
-- move-input holds as UE does, the rows of the set test, the requests asked and the notice keys said): the gate, the
-- entry from a Join or coop sbo enter with its checks, a double Join, a Lua load mid-entry, each end word of the native part (the move input
-- back, the notice, the rows put back after a refused warp), the late arrival, the return and SB's own reload, the
-- title's put-back, coop off while warping, and the status line. Then the waiting room at each arrival (the room
-- shown, EVE to her spot, the fence), the spots' re-place, the rounds' ids, coop sbo hop and back, and a Lua reload in
-- the lobby. Then the menu camera (made once, the view switched to it and back, swept after a Lua reload), coop sbo
-- view and view set, and coop sbo seq. Last, the arrival's hold: the warps that arm it, the ends that disarm it, what
-- the lobby still waits for (unready) and the chairs' budget under the hold.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Sbo=require('session.sbo')
local S=Sbo.SPOTS
assert(#S==8 and S[1].X==-63228.5 and S[1].Y==151213.6 and S[1].Yaw==180)
assert(S[2].X==-63462.8 and S[2].Y==151779.3 and S[2].Yaw==-135 and S[3].Y==152013.6 and S[3].Yaw==-90)
assert(S[4].X==-64594.2 and S[4].Yaw==-45 and S[5].X==-64828.5 and S[5].Yaw==0 and S[6].Y==150647.9)
assert(S[7].Y==150413.6 and S[7].Yaw==90 and S[8].X==-63462.8 and S[8].Yaw==135)
for _,s in ipairs(S) do assert(math.abs(math.sqrt((s.X+64028.5)^2+(s.Y-151213.6)^2)-800)<0.2) end
assert(Sbo.LOBBY.zone=='Zone_Xion_Boss_Mann' and Sbo.LOBBY.point=='Xion_Boss_Mann' and Sbo.LOBBY.spot_z==-15800.4)
-- Spots: the round's order first, else the SteamID rank, capped at 8.
local me='76561198000000002'
assert(Sbo.spot(me,{})==1 and Sbo.spot(me,{'76561198000000003','76561198000000001'})==2)
assert(Sbo.spot(me,{'76561198000000002','76561198000000001'})==2)
assert(Sbo.spot(me,{'76561198000000001'},{'76561198000000003','76561198000000002'})==2)
assert(Sbo.spot(me,{'76561198000000001'},{'76561198000000003','76561198000000004'})==2)
local many={}
for i=1,9 do many[i]=tostring(76561198000000000+i) end
assert(Sbo.spot('76561198000000010',many)==8)
assert(Sbo.near_spot({X=-63228.5+70,Y=151213.6+70},1) and not Sbo.near_spot({X=-63228.5+71,Y=151213.6+71},1))
-- Fence: 30 m from the centre, inside the ring's wall (inner face 29 m), Z -16100 to -14700; three catches in 10 s
-- stop it. EVE against the inner wall (her centre near 28.9 m) is inside.
local c={X=-64028.5,Y=151213.6}
assert(not Sbo.outside({X=c.X+2999,Y=c.Y,Z=-15800}) and Sbo.outside({X=c.X+3001,Y=c.Y,Z=-15800}))
assert(not Sbo.outside({X=c.X+2890,Y=c.Y,Z=-15800}))
assert(Sbo.outside({X=c.X,Y=c.Y,Z=-16101}) and Sbo.outside({X=c.X,Y=c.Y,Z=-14699}) and not Sbo.outside({X=c.X,Y=c.Y,Z=-14700}))
local f=Sbo.fence()
assert(f.catch(0)=='back' and f.catch(4)=='back' and f.catch(9)=='stop')
local g=Sbo.fence()
assert(g.catch(0)=='back' and g.catch(6)=='back' and g.catch(11)=='back' and g.catch(12)=='stop')
-- Row sets as data, refused whole, put back from the shipped values.
assert(#Sbo.ROWS.lobby==4 and #Sbo.ROWS.NK_Boss_Scarlet==3)
local r1=Sbo.ROWS.lobby[1]
assert(r1.row=='Xion_Boss_Mann_E_CharS_001' and r1.id==1692024001 and r1.field=='SpawnType' and r1.shipped==0 and r1.session==1)
assert(Sbo.ROWS.lobby[4].row=='Xion_Boss_Mann_ZTrigger_003' and Sbo.ROWS.lobby[4].shipped==1 and Sbo.ROWS.lobby[4].session==2)
local values,writes={},{}
local rows={read=function(t,row,field) return values[row] or (field=='SpawnType' and 0 or 1) end,
    write=function(t,row,field,v) writes[#writes+1]=row..' '..field..' '..v; values[row]=v end}
assert(Sbo.edit_set('lobby',rows)==true and #writes==4 and writes[1]=='Xion_Boss_Mann_E_CharS_001 SpawnType 1')
writes={}
assert(Sbo.edit_set('lobby',rows)==true and #writes==0) -- already at the session values
values={['Xion_Boss_Mann_ZTrigger_002']=7}
local ok,why=Sbo.edit_set('lobby',rows)
assert(ok==false and #writes==0 and why=='sbo rows: ZoneTriggerTable Xion_Boss_Mann_ZTrigger_002 InitActivate reads 7 '
    ..'(another mod?): set lobby not edited')
values={['Xion_Boss_Mann_ZTrigger_001']=2,['NK_Boss_Scarlet_E_CharS_001']=1}
writes={}
Sbo.put_back(rows)
assert(#writes==2 and writes[1]=='Xion_Boss_Mann_ZTrigger_001 InitActivate 1' and writes[2]=='NK_Boss_Scarlet_E_CharS_001 SpawnType 0')
writes={}
Sbo.put_back(rows)
assert(#writes==0)
local lost={read=rows.read,write=function(t,row,field,v) if row~='Xion_Boss_Mann_ZTrigger_003' then rows.write(t,row,field,v) end end}
ok,why=Sbo.edit_set('lobby',lost)
assert(ok==false and why=='sbo rows: ZoneTriggerTable Xion_Boss_Mann_ZTrigger_003 InitActivate reads 1 after the write: '
    ..'set lobby not edited' and values['Xion_Boss_Mann_ZTrigger_001']==1) -- the rows written are put back
for why,key in pairs({flow='no.busy',reload='no.busy',busy='no.busy',nosave='no.save',build='no.save',bc='no.boss',
    queue='no.queue',record='no.record',late='no.record',coop='no.coop',slot='no.coop',manager='fail.save',
    sidecar='fail.save',saveread='fail.save',unsaved='fail.save',timeout='fail.save',rows='fail.warp',game='fail.warp',
    zone='fail.warp',type='fail.warp',guard='fail.leave',restore='fail.leave'}) do
    assert(Sbo.notice_key(why)==key,why)
end
assert(Sbo.notice_key('done')==nil and Sbo.notice_key('running')==nil)
local base={gate=true,saves={saves='coop',slot='coop'},steam=true,link='none',fight=false,nightop=false}
local function with(k,v) local o={} for a,b in pairs(base) do o[a]=b end; o[k]=v; return o end
assert(Sbo.checks(base)==nil and Sbo.checks(with('gate',false))=='off')
assert(Sbo.checks(with('saves',{saves='main',slot='coop'}))=='no.coop' and Sbo.checks(with('saves',{saves='coop',slot='main'}))=='no.coop')
assert(Sbo.checks(with('steam',false))=='no.steam' and Sbo.checks(with('link','guest'))=='no.partner')
assert(Sbo.checks(with('fight',true))=='no.fight' and Sbo.checks(with('nightop',true))=='no.nightop')

-- The fake world. status: what link.sbo() gives (S builds it); pc: UE's move-input count (SetIgnoreMoveInput adds or
-- takes one, never below 0) plus game, the holds the game itself keeps (a dialogue, its loading), each view target set
-- (views: '<target> <blend> ...'), and its camera manager's view (cm). The menu camera: each camera spawned (spawns:
-- its place and turn), each path swept, and coop-sbo.txt's line (stored).
local status,mode,saves,fight,night,eve,room,roster,round
-- The match lobby as the link= line names it (nil: none): {lobby=, owner=, room=, hall=}.
local steam
local asked,said,logs,runs={},{},{},0
local spawns,cams,sweeps,stored={},{},{},nil
local pc={}
function pc:SetIgnoreMoveInput(on) self.ours=math.max(self.ours+(on and 1 or -1),0) end
function pc:IsMoveInputIgnored() return self.ours+self.game>0 end
function pc:ResetIgnoreMoveInput() self.ours,self.game,self.resets=0,0,self.resets+1 end
function pc:K2_GetPawn() return {name='pawn'} end
function pc:SetViewTargetWithBlend(target,blend,func,exp,lock)
    local words={target.name,tostring(blend),tostring(func),tostring(exp),tostring(lock)}
    self.views[#self.views+1]=table.concat(words,' ')
end
local cm={at={X=-13000.04,Y=18000.06,Z=262.5},turn={Pitch=-7.25,Yaw=171.5,Roll=0},fov=80}
pc.PlayerCameraManager={GetCameraLocation=function() return cm.at end,GetCameraRotation=function() return cm.turn end,
    GetFOVAngle=function() return cm.fov end}
local store={save=function(path) stored=path; return true end,load=function() return stored end,
    clear=function() stored=nil end}
local function S(join,record,last,zone,arrivals)
    local n,verb,result=(last or '0 - -'):match('^(%d+) (%S+) (%S+)$')
    return {state='armed',join=join,record=record,slot=record~='closed' and 2 or nil,arrivals=arrivals or 0,
        zone=zone or '0:0',
        loader=3,copy=nil,last={n=tonumber(n),verb=verb~='-' and verb or nil,result=result~='-' and result or nil}}
end
local link={sbo=function() return status end,mode=function() return mode end,saves=function() return saves end,
    members=function() return roster end,round=function() return round end,
    lobby=function() return steam and steam.lobby end,owner=function() return steam and steam.owner end,
    room=function() return steam and steam.room end,hall=function() return steam and steam.hall end,
    store=function(name) assert(name=='coop-sbo.txt',name); return store end,
    request=function(line) asked[#asked+1]=line; return true,'asked the native part: '..line end}
local settings={}
local NAMES={Zone_Xion_Boss_Mann=1692,Xion_Boss_Mann=1693,Zone_NK_Boss_Scarlet=3191,NK_Boss_Scarlet=3192,
    Xion_10_E_Seq_011=5123}
local manager={GetAddress=function() return 0x2a0000000 end}
local ue={game_instance=function() return {SaveObjectManager=manager} end,pc=function() return pc end,
    eve=function() return eve end,find_name=function(text) return text end,
    first=function(class) return class=='BP_TrainningRoom_Common_C' and room or nil end,
    index_of=function(name) return NAMES[name] or 0 end,rows=rows,
    camera=function(at,turn)
        local n=#spawns+1
        local d={actor={name='camera '..n,alive=true},path='/Game/Camera_'..n}
        d.mesh={SetFieldOfView=function(_,fov) d.fov=fov end,
            K2_SetWorldLocationAndRotation=function(_,a,t)
                d.moved=string.format('%.1f %.1f %.1f %g %g',a.X,a.Y,a.Z,t.Pitch,t.Yaw)
            end}
        spawns[n]=string.format('%.1f %.1f %.1f %g %g %g',at.X,at.Y,at.Z,turn.Pitch,turn.Yaw,turn.Roll)
        cams[n]=d
        return d
    end,
    alive=function(d) return d.actor.alive and d.actor or nil end,
    sweep=function(path) sweeps[#sweeps+1]=path; return true end}
-- The hall chairs: each class asked (class_asks; no_class: the assets that do not load), each chair spawned
-- (chairs_made: '<class> <row> X Y Z Yaw <parts>'; refused: the rows whose spawn raises), its actor ({row=}), and what
-- SB bound it to (bind_zone and its row; the rows in unbound read None; bind_raise: the rows whose read raises, with
-- the error); left_chairs: an earlier Lua load's chairs in the world, the rows of each class's asset (left_raise:
-- what finding them raises).
local class_asks,chairs_made,no_class,refused,unbound,bind_zone,bind_raise,left_chairs,left_raise
function ue.chairs_of(class,name)
    assert(name==class.asset:match('[^.]+$')..'_C',name)
    if left_raise then error(left_raise,0) end
    local t={}
    for i,row in ipairs(left_chairs[class.asset] or {}) do t[i]={row=row} end
    return t
end
function ue.chair_class(asset)
    class_asks[#class_asks+1]=asset
    if no_class[asset] then error(asset..'_C does not load',0) end
    return {asset=asset}
end
function ue.chair(class,row,at,parts)
    if refused[row] then error('FinishSpawningActor gave nothing',0) end
    chairs_made[#chairs_made+1]=string.format('%s %s %.2f %.2f %.1f %g %s',class.asset:match('[^.]+$'),row,at.X,at.Y,
        at.Z,at.Yaw,table.concat(parts,'+'))
    return {row=row}
end
function ue.bound(a)
    if bind_raise[a.row] then error(bind_raise[a.row],0) end
    if unbound[a.row] then return 'None','None' end
    return bind_zone,a.row
end
local sb
-- The lobby pak gate's inputs (the Paks folder, nil: unknown; files.read over pak_files) and halls.ok(): no folder
-- until the hall lobby tests at the end give one.
local gate_paks,pak_files,hall_ok=nil,{},nil
local function gate_read(path,limit) return pak_files[path] and pak_files[path]:sub(1,limit) end
-- The hall lobby seats' input: coop emote's seat loops (em: on while one plays, refuse: why sit refuses, the kinds sat,
-- each stop's why and each kind whose loop was looked up ahead, found but for camp; preload_error: the kind whose
-- look-up raises, with that error); each loop started is also one of EVE's calls.
local em={}
local emote={active=function() return em.on end,
    sit=function(kind)
        if em.refuse then return false,em.refuse end
        em.on,em.sits[#em.sits+1]=true,kind
        if eve then eve.did[#eve.did+1]='loop '..kind end
        return true,'emote seat:'..kind..': move, jump, dodge or attack to stop it'
    end,
    stop=function(why) if em.on then em.on,em.stops[#em.stops+1]=false,why end end,
    preload=function(kind)
        em.preloads[#em.preloads+1]=kind
        if em.preload_error and em.preload_error[kind] then error(em.preload_error[kind],0) end
        return kind~='camp'
    end}
-- The arrival's hold (session/arrival.lua): the lobby warps armed, each disarm's why, and whether SB's black is up.
local hold={}
local arrival={arm=function() hold.arms=hold.arms+1 end,disarm=function(why) hold.disarms[#hold.disarms+1]=why end,
    held=function() return hold.on end}
-- left: coop-sbo.txt's line from an earlier Lua load.
local function fresh(gate,left)
    hold.arms,hold.disarms,hold.on=0,{},false
    status,mode,saves,fight,night,eve,room,roster,round=nil,'none',{saves='coop',slot='coop'},false,false,nil,nil,{},nil
    steam=nil
    em={on=false,sits={},stops={},preloads={}}
    class_asks,chairs_made,no_class,refused,unbound,bind_zone,bind_raise,left_chairs,left_raise={},{},{},{},{},nil,{},{},
        nil
    asked,said,logs,runs,writes,values={},{},{},0,{},{}
    spawns,cams,sweeps,stored={},{},{},left
    pc.ours,pc.game,pc.resets,pc.views=0,0,0,{}
    settings.sbo_lobby=gate~=false
    sb=Sbo.new({link=link,settings=settings,log=function(line) logs[#logs+1]=line end,
        say=function(key) said[#said+1]=key end,ue=ue,
        recruiter={run=function() runs=runs+1; return true,'recruiter asked' end},
        nightop={running=function() return night end},fight=function() return fight end,
        paks=gate_paks,read=gate_read,halls={ok=function() return hall_ok end},emote=emote,arrival=arrival})
end
local function tick(s,now) status=s; sb.tick(now or 0) end
local function list(t) return table.concat(t,',') end
local ENTER='sbo enter 0x2a0000000'
local SET={'Xion_Boss_Mann_E_CharS_001 SpawnType 1','Xion_Boss_Mann_ZTrigger_001 InitActivate 2',
    'Xion_Boss_Mann_ZTrigger_002 InitActivate 2','Xion_Boss_Mann_ZTrigger_003 InitActivate 2'}
local SHIPPED={'Xion_Boss_Mann_E_CharS_001 SpawnType 0','Xion_Boss_Mann_ZTrigger_001 InitActivate 1',
    'Xion_Boss_Mann_ZTrigger_002 InitActivate 1','Xion_Boss_Mann_ZTrigger_003 InitActivate 1'}
-- An entry under way: a Join seen, the native part saving.
local function joined()
    tick(S(0,'closed')); tick(S(1,'closed')); tick(S(1,'starting','1 enter running'))
end
-- The gate: every console word answers OFF and asks nothing; no sbo on.
fresh(false)
assert(select(2,sb.enter())==Sbo.OFF and sb.enter()==false and select(2,sb.leave())==Sbo.OFF)
assert(select(2,sb.status())==Sbo.OFF)
sb.on_load()
assert(#asked==0)
-- With it off, a Join enters nothing and says the setting is off.
tick(S(0,'closed')); tick(S(1,'closed'))
assert(#asked==0 and list(said)=='sbo.no.lobby' and pc.ours==0,list(said))
fresh()
sb.on_load(); sb.on_load()
assert(list(asked)=='sbo on','sbo on once a load')
-- Join: a rise of join=, the checks passing: EVE held, the saving notice, sbo enter with SB's save manager.
fresh()
tick(S(0,'closed'))
assert(#asked==0)
tick(S(1,'closed'))
assert(list(asked)==ENTER and pc:IsMoveInputIgnored() and list(said)=='sbo.saving',list(asked))
assert(sb.active()==false,'closed is no session')
-- A double Join in one pass: one entry; coop sbo enter while it runs is refused.
fresh()
tick(S(0,'closed')); tick(S(2,'closed'))
assert(list(asked)==ENTER and pc.ours==1)
tick(S(2,'starting','1 enter running'))
local ok,why=sb.enter()
assert(ok==false and why=='an SBO entry is already running' and #asked==1,why)
assert(sb.active()==true)
-- A Lua reload during an entry: the status line alone says one runs.
fresh()
status=S(2,'starting','1 enter running')
ok,why=sb.enter()
assert(ok==false and why=='an SBO entry is already running' and #asked==0)
-- A Lua reload with the record open after enter done (L8-R1): the first read runs E8, the rows then the warp.
fresh()
tick(S(1,'open','1 enter done'))
assert(list(writes)==list(SET) and list(asked)=='sbo warp 1692 0 1693 0',list(asked))
-- A Lua reload while the native part saves, EVE held by the controller: the end word that follows gives her back.
fresh()
pc.ours=1
tick(S(1,'starting','1 enter running'))
tick(S(1,'closed','1 enter unsaved'))
assert(said[#said]=='sbo.fail.save' and not pc:IsMoveInputIgnored() and #asked==0,list(said))
-- A record read from disk at a game start (no last from this run): nothing taken over.
fresh()
tick(S(0,'open'))
assert(#asked==0 and #writes==0)
-- A check refused: its notice, nothing asked, EVE free.
fresh()
mode='guest'
tick(S(0,'closed')); tick(S(1,'closed'))
assert(#asked==0 and list(said)=='sbo.no.partner' and pc.ours==0,list(said))
fresh()
saves={saves='main',slot='main'} -- The player's own save.
tick(S(0,'closed')); tick(S(1,'closed'))
assert(#asked==0 and list(said)=='sbo.no.coop',list(said))
fresh()
fight=true
ok,why=sb.enter()
assert(ok==false and #asked==0 and list(said)=='sbo.no.fight',list(said))
-- E8: the record open after enter done: the four rows, then the warp to the lobby's zone and point.
fresh()
joined()
tick(S(1,'open','1 enter done'))
assert(list(writes)==list(SET),list(writes))
assert(list(asked)==ENTER..',sbo warp 1692 0 1693 0',list(asked))
-- E8 refused (a row reads 7): sbo abort rows, no warp, EVE free, the notice.
fresh()
values['Xion_Boss_Mann_ZTrigger_002']=7
joined()
pc.game=1 -- The game still holds her input too: it is reset.
tick(S(1,'open','1 enter done'))
assert(#writes==0 and list(asked)==ENTER..',sbo abort rows' and pc.resets==1 and not pc:IsMoveInputIgnored())
assert(said[#said]=='sbo.fail.warp',list(said))
-- The warp refused (E9, the record closed): the rows put back to the shipped values, the notice, EVE free.
fresh()
joined()
tick(S(1,'open','1 enter done'))
writes={}
tick(S(1,'closed','2 warp game'))
assert(list(writes)==list(SHIPPED) and said[#said]=='sbo.fail.warp' and not pc:IsMoveInputIgnored(),list(writes))
-- The native part's own refusal: no save.
fresh()
joined()
tick(S(1,'closed','1 enter unsaved'))
assert(said[#said]=='sbo.fail.save' and not pc:IsMoveInputIgnored() and #writes==0)
-- An end word with no notice (R16): EVE free all the same, the word logged.
fresh()
joined()
local n=#said
tick(S(1,'starting','1 enter off'))
assert(#said==n and not pc:IsMoveInputIgnored() and logs[#logs]:find('enter off',1,true),logs[#logs])
-- on and arm: logged only, whatever they end with.
fresh()
joined()
n=#said
tick(S(1,'starting','2 arm game')); tick(S(1,'starting','3 on build'))
assert(#said==n and pc:IsMoveInputIgnored() and logs[#logs]:find('on build',1,true),logs[#logs])
-- No arrival 60 s after the warp: the notice once over three passes, nothing written.
fresh()
joined()
tick(S(1,'open','1 enter done'))
tick(S(1,'warping','2 warp done'))
assert(pc:IsMoveInputIgnored(),'Held while the warp loads')
writes={}
for _=1,3 do tick(S(1,'warping','2 warp late')) end
local records=0
for _,key in ipairs(said) do if key=='sbo.no.record' then records=records+1 end end
assert(records==1 and said[#said]=='sbo.no.record' and #writes==0 and not pc:IsMoveInputIgnored(),list(said))
-- The return in a match lobby: the Steam lobby left, the rows put back, then sbo leave, in that order.
local function arrived()
    joined()
    tick(S(1,'open','1 enter done'))
    tick(S(1,'warping','2 warp done'))
    tick(S(1,'arrived','2 warp done','1692:0'))
end
fresh()
arrived()
mode='guest'
asked,writes={},{}
local order={}
local write=rows.write
rows.write=function(...) order[#order+1]='write'; return write(...) end
link.request=function(line) order[#order+1]=line; asked[#asked+1]=line; return true,'asked' end
ok=sb.leave()
assert(ok and list(order)=='leave,write,write,write,write,sbo leave' and list(writes)==list(SHIPPED),list(order))
assert(pc:IsMoveInputIgnored(),'The return holds EVE')
rows.write=write
link.request=function(line) asked[#asked+1]=line; return true,'asked the native part: '..line end
-- Its end: the record closed after leaving: EVE free once, coop recruiter once she is back.
pc.game=1 -- SB's reload left her input held.
tick(S(1,'leaving','3 leave running','1692:0'))
tick(S(1,'closed','3 leave done','1692:0'))
assert(pc.resets==1 and not pc:IsMoveInputIgnored() and runs==0)
tick(S(1,'closed','3 leave done'))
assert(runs==0,'No EVE yet')
eve={}
tick(S(1,'closed','3 leave done')); tick(S(1,'closed','3 leave done'))
assert(runs==1 and pc.resets==1)
-- SB's own reload ends the same way, with no hold of ours to give back.
fresh()
arrived()
eve={}
tick(S(1,'leaving','3 sb running','1692:0'))
tick(S(1,'leaving','3 sb done','1692:0'))
tick(S(1,'leaving','3 sb done','1692:0'))
assert(runs==1 and pc.resets==0)
-- A failed return: fail.leave, also for a wait that ran out.
fresh()
arrived()
sb.leave()
tick(S(1,'leaving','3 leave running'))
tick(S(1,'arrived','3 leave timeout'))
assert(said[#said]=='sbo.fail.leave' and not pc:IsMoveInputIgnored(),said[#said])
-- coop sbo leave outside a session asks nothing.
fresh()
status=S(0,'warping','2 warp running')
ok,why=sb.leave()
assert(ok==false and #asked==0 and why:find('warping',1,true),why)
-- SB's own reload in the lobby: the Steam lobby left and the rows put back, no sbo leave.
fresh()
arrived()
mode='host'
asked,writes={},{}
tick(S(1,'leaving','3 sb running','1692:0'))
assert(list(asked)=='leave' and list(writes)==list(SHIPPED),list(asked))
-- SB's own reload before the arrival (warping, then with the record open) ends the entry: the next Join enters.
fresh()
joined()
tick(S(1,'open','1 enter done')); tick(S(1,'warping','2 warp done'))
tick(S(1,'leaving','3 sb running')); tick(S(1,'closed','3 sb done'))
asked={}
tick(S(2,'closed','3 sb done'))
assert(list(asked)==ENTER,list(asked))
fresh()
joined()
tick(S(1,'open','1 enter done'))
tick(S(1,'leaving','3 sb running')); tick(S(1,'closed','3 sb done'))
asked={}
tick(S(2,'closed','3 sb done'))
assert(list(asked)==ENTER,list(asked))
-- The title: any row at its session value goes back, whatever the setting.
fresh(false)
values['NK_Boss_Scarlet_ZTrigger_002']=2
sb.title()
assert(list(writes)=='NK_Boss_Scarlet_ZTrigger_002 InitActivate 1',list(writes))
-- coop off while warping: the put-back only, nothing asked, EVE free, the record's notice.
fresh()
joined()
tick(S(1,'open','1 enter done'))
tick(S(1,'warping','2 warp running'))
asked,writes={},{}
sb.off()
assert(list(writes)==list(SHIPPED) and #asked==0 and not pc:IsMoveInputIgnored() and said[#said]=='sbo.no.record')
-- The status line.
fresh()
status=S(1,'arrived','2 warp done','1692:0')
ok,why=sb.status()
assert(ok and why=='sbo: record arrived slot 2, zone lobby, loader 3, spot -, fence off, room -, copy -',why)
status=S(1,'closed','2 warp done','3191:0')
assert(select(2,sb.status())=='sbo: record closed slot -, zone arena, loader 3, spot -, fence off, room -, copy -')
status=nil
assert(sb.status()==false)

-- The waiting room. The room actor as SB's training room reads: its region name, the hidden flag, and InitRegion's two
-- platforms (stuck: one InitRegion leaves visible). EVE: where she stands, each teleport asked (refuse: how many the
-- game refuses), her mesh 97 cm under her centre, and her calls a seat makes in order (did: her collision, each
-- teleport, her movement mode, the seat's loop); collide: her actor's collision; interacting: what
-- IsRunningInteraction says (SB runs an interaction on her, a chair's sit); each EVE at an address of her own.
local function new_room(region,stuck)
    local r={UniqueRegionName=region or 'TrainningRoom_Common',bHidden=true,calls={},
        shown={Plane_Common=true,Plane_AirBreakFall=true}}
    for _,name in ipairs({'Plane_Common','Plane_AirBreakFall'}) do
        r[name]={IsVisible=function() return r.shown[name] end}
    end
    function r:SetActorHiddenInGame(on) self.calls[#self.calls+1]='hidden '..tostring(on); self.bHidden=on end
    function r:InitRegion(name)
        self.calls[#self.calls+1]='init '..name
        for k in pairs(self.shown) do self.shown[k]=k==stuck end
    end
    return r
end
local c=Sbo.LOBBY.centre
local addresses=0x7f0000000
local function new_eve(x,y,z)
    addresses=addresses+0x1000
    local e={at={X=x or c.X,Y=y or c.Y,Z=z or -15800},went={},refuse=0,did={},collide=true,
        Mesh={RelativeLocation={X=0,Y=0,Z=-97}},address=addresses}
    function e:GetAddress() return self.address end
    e.CharacterMovement={SetMovementMode=function(_,m,custom) e.did[#e.did+1]='mode '..m..' '..custom end}
    function e:SetActorEnableCollision(on,fast)
        self.collide=on
        self.did[#self.did+1]='collision '..tostring(on)..' '..tostring(fast)
    end
    function e:GetActorEnableCollision() return self.collide end
    function e:IsRunningInteraction() return self.interacting==true end
    function e:K2_GetActorLocation() return {X=self.at.X,Y=self.at.Y,Z=self.at.Z} end
    function e:K2_TeleportTo(at,rot)
        self.went[#self.went+1]=string.format('%.1f %.1f %.1f %g %g %g',at.X,at.Y,at.Z,rot.Pitch,rot.Yaw,rot.Roll)
        self.did[#self.did+1]='teleport '..self.went[#self.went]
        if self.refuse>0 then self.refuse=self.refuse-1; return false end
        self.at={X=at.X,Y=at.Y,Z=at.Z}
        return true
    end
    return e
end
local function spot_at(k) local p=Sbo.SPOTS[k]; return string.format('%.1f %.1f -15800.4 0 %g 0',p.X,p.Y,p.Yaw) end
local function ids(...) local t={} for i,id in ipairs({...}) do t[i]={id=id} end return t end
local function logged(text) for _,line in ipairs(logs) do if line==text then return true end end end
local ME='76561198000000005'
local LOBBY,ARENA='1692:0','3191:0'
local HERE=S(1,'arrived','2 warp done',LOBBY,1) -- In the lobby after its arrival.
-- A warp that lands in zone, with SteamIDs 9, 3 and ours in the lobby (rank 2).
local function landed(zone,stuck)
    fresh()
    saves.steamid,roster,room,eve=ME,ids('76561198000000009','76561198000000003',ME),new_room(nil,stuck),new_eve()
    tick(S(1,'warping','2 warp done',LOBBY,0))
    tick(S(1,'arrived','2 warp done',zone or LOBBY,1))
end
local function out(e) e.at={X=c.X+3001,Y=c.Y,Z=-15800} end -- Beyond the fence.
-- Arrival: the room shown and read back, EVE to her spot, the fence on.
landed()
assert(list(room.calls)=='hidden false,init Default' and room.bHidden==false,list(room.calls))
assert(not room.Plane_Common.IsVisible() and not room.Plane_AirBreakFall.IsVisible())
assert(list(eve.went)==spot_at(2) and spot_at(2)=='-63462.8 151779.3 -15800.4 0 -135 0',list(eve.went))
assert(sb.in_lobby() and sb.spot()==2)
assert(select(2,sb.status())=='sbo: record arrived slot 2, zone lobby, loader 3, spot 2, fence on, room shown, copy -',
    select(2,sb.status()))
assert(logs[#logs]=='lobby room: shown, fence on (3000 cm)',list(logs))
tick(HERE)
assert(#eve.went==1,'Placed once')
-- Where she stands one pass after each teleport the game took, and each fence catch that sends her back.
assert(logs[#logs]=='lobby: EVE teleported to spot 2, now at -63463 151779 -15800 (0.0 m from it)',list(logs))
out(eve); tick(HERE)
assert(logs[#logs]=='lobby fence: EVE at -61028 151214 -15800, back to spot 2',list(logs))
eve.at.X=eve.at.X+150 -- Moved 1.5 m after the teleport.
tick(HERE)
assert(logs[#logs]=='lobby: EVE teleported to spot 2, now at -63313 151779 -15800 (1.5 m from it)',list(logs))
n=#logs
tick(HERE)
assert(#logs==n,'Logged once a teleport')
-- The arrival split over two lines (L9-R1): arrivals=1 while still warping, then arrived on the next line.
fresh()
saves.steamid,roster,room,eve=ME,ids('76561198000000009','76561198000000003',ME),new_room(),new_eve()
tick(S(1,'warping','2 warp done',LOBBY,0)); tick(S(1,'warping','2 warp done',LOBBY,1))
tick(HERE); tick(HERE)
assert(list(room.calls)=='hidden false,init Default' and list(eve.went)==spot_at(2),list(eve.went))
assert(select(2,sb.status()):find('fence on, room shown',1,true),select(2,sb.status()))
-- A platform still visible after InitRegion: logged, and the lobby goes on.
landed(nil,'Plane_Common')
assert(logged('lobby room: Plane_Common still visible after InitRegion') and list(eve.went)==spot_at(2),list(logs))
out(eve); tick(HERE)
assert(#eve.went==2,'The fence on')
-- A read-back that raises (the room has no Plane_AirBreakFall): logged, the room unsure, the lobby goes on.
fresh()
saves.steamid,roster,room,eve=ME,ids('76561198000000003'),new_room(),new_eve()
room.Plane_AirBreakFall=nil
tick(S(1,'warping','2 warp done',LOBBY,0)); tick(HERE)
assert(logs[#logs-1]:find('^lobby room: ') and logs[#logs]=='lobby room: unsure, fence on (3000 cm)'
    and list(eve.went)==spot_at(2),list(logs))
assert(select(2,sb.status()):find('fence on, room unsure',1,true),select(2,sb.status()))
-- No room actor: logged, EVE still placed.
fresh()
saves.steamid,roster,eve=ME,ids('76561198000000003'),new_eve()
tick(S(1,'warping','2 warp done',LOBBY,0)); tick(HERE)
assert(logged('lobby room: BP_TrainningRoom_Common_C not found') and list(eve.went)==spot_at(2),list(logs))
-- Another region name: the room left alone.
fresh()
saves.steamid,room,eve=ME,new_room('AirBreakFall'),new_eve()
tick(S(1,'warping','2 warp done',LOBBY,0)); tick(HERE)
assert(#room.calls==0 and logged('lobby room: region reads AirBreakFall, not TrainningRoom_Common') and #eve.went==1)
-- The teleport refused: tried on the next three passes, then logged.
fresh()
saves.steamid,room,eve=ME,new_room(),new_eve()
eve.refuse=99
tick(S(1,'warping','2 warp done',LOBBY,0))
for _=1,4 do tick(HERE) end
assert(#eve.went==4 and logged('lobby: teleport to spot 1 refused 4 times'),#eve.went)
tick(HERE)
assert(#eve.went==4)
-- The fence: beyond it, back to her spot; three catches within 10 s stop it.
landed()
out(eve); tick(HERE,0)
assert(#eve.went==2 and eve.went[2]==spot_at(2))
out(eve); tick(HERE,4)
out(eve); tick(HERE,9)
assert(#eve.went==3 and logged('lobby room: no floor or ring collision'),#eve.went)
assert(select(2,sb.status()):find('fence stopped',1,true))
out(eve); tick(HERE,30)
assert(#eve.went==3,'Stopped')
-- The member set changes: within 1 m of her spot she moves to her new rank's; 3 m away she stays.
landed()
roster[#roster+1]={id='76561198000000001'}
tick(HERE)
assert(#eve.went==2 and eve.went[2]==spot_at(3) and sb.spot()==3,list(eve.went))
eve.at.X=eve.at.X+300
roster[#roster+1]={id='76561198000000002'}
tick(HERE)
assert(#eve.went==2 and sb.spot()==4)
-- An arena's arrival: no room, no teleport, no fence.
landed(ARENA)
assert(#room.calls==0 and #eve.went==0 and logged('sbo: arena arrival') and not sb.in_lobby() and sb.spot()==nil)
out(eve); tick(S(1,'arrived','2 warp done',ARENA,1))
assert(#eve.went==0 and select(2,sb.status()):find('spot -, fence off, room -',1,true))
-- A Lua reload in the lobby (Review Focus 2): the room shown again, EVE left where she stands inside the fence, the
-- fence on.
fresh()
saves.steamid,room,eve=ME,new_room(),new_eve(c.X+2600)
tick(S(1,'arrived','2 warp done',LOBBY,4)); tick(S(1,'arrived','2 warp done',LOBBY,4))
assert(list(room.calls)=='hidden false,init Default' and #eve.went==0)
assert(logged('lobby room: shown, fence on (3000 cm), EVE left where she stands'),list(logs))
out(eve); tick(S(1,'arrived','2 warp done',LOBBY,4))
assert(list(eve.went)==spot_at(1))
-- No SteamID yet (L6-R1): no spot work and no teleport, nothing raised.
fresh()
roster,room,eve=ids('76561198000000009','76561198000000003'),new_room(),new_eve(c.X+5000)
tick(S(1,'warping','2 warp done',LOBBY,0)); tick(HERE); tick(HERE)
assert(#eve.went==0 and sb.spot()==nil)
saves.steamid=ME
tick(HERE)
assert(list(eve.went)==spot_at(2),'Placed once the SteamID shows')
-- Rounds (R18): a start without us keeps the fence on; ours stops it until its end; then the spot is the round's.
landed()
round={n=1,kind='start',mode='ffa',map='NK_P',seed=7,ids={'76561198000000009','76561198000000003'}}
out(eve); tick(HERE,20)
assert(#eve.went==2,'Not our round')
round={n=2,kind='start',mode='ffa',map='NK_P',seed=8,ids={'76561198000000009','76561198000000003',ME}}
out(eve); tick(HERE,40)
assert(#eve.went==2,'Our round: no fence')
round={n=2,kind='end',why='host'}
tick(HERE,60)
assert(#eve.went==3 and eve.went[3]==spot_at(3) and sb.spot()==3,list(eve.went))
-- A new session forgets the last one's round (L9-R2): the leave closes the record, then our SteamID rank again.
tick(S(1,'leaving','3 leave running',LOBBY,1)); tick(S(1,'closed','3 leave done',LOBBY,1))
tick(S(1,'warping','4 warp done',LOBBY,1)); tick(S(1,'arrived','4 warp done',LOBBY,2))
assert(sb.spot()==2,sb.spot())
-- coop sbo hop: the arena's rows, then its warp; only from the lobby with no match lobby.
local HOP='coop sbo hop: only in the SBO lobby with no match lobby open'
local BACK='coop sbo back: only in an arena of the SBO session'
landed()
asked,writes={},{}
ok,why=sb.hop()
assert(ok and list(asked)=='sbo warp 3191 0 3192 0' and list(writes)=='NK_Boss_Scarlet_E_CharS_001 SpawnType 1,'
    ..'NK_Boss_Scarlet_ZTrigger_001 InitActivate 2,NK_Boss_Scarlet_ZTrigger_002 InitActivate 2',list(writes))
landed()
mode,asked,writes='host',{},{}
ok,why=sb.hop()
assert(ok==false and why==HOP and #asked==0 and #writes==0,why)
ok,why=sb.back()
assert(ok==false and why==BACK and #asked==0,why)
-- coop sbo back: the warp to the lobby, from an arena of the session.
landed(ARENA)
asked={}
ok,why=sb.hop()
assert(ok==false and why==HOP)
ok=sb.back()
assert(ok and list(asked)=='sbo warp 1692 0 1693 0',list(asked))
fresh(false)
assert(select(2,sb.hop())==Sbo.OFF and select(2,sb.back())==Sbo.OFF)

-- The menu camera (design-lobby 2.6, 2.7): one camera at the Agit with the camera manager's FOV, the view on it with
-- blend 0 and the move input ignored, its path kept in coop-sbo.txt; to_room gives the view back to her pawn with blend
-- 0 and the move input back; the next to_menu takes the live camera again.
local AGIT='-13413.0 18383.0 250.0 -5 175 0'
landed()
ok=sb.to_menu()
assert(ok and list(spawns)==AGIT and cams[1].fov==80 and stored=='/Game/Camera_1',list(spawns))
assert(list(pc.views)=='camera 1 0 0 0 false' and pc.ours==1,list(pc.views))
sb.to_room()
assert(pc.views[2]=='pawn 0 0 0 false' and not pc:IsMoveInputIgnored(),list(pc.views))
pc.game=1 -- A hold the game kept is reset, as cut/leviathan.lua's give_back does.
sb.to_menu(); sb.to_room()
assert(#spawns==1 and pc.views[3]=='camera 1 0 0 0 false' and pc.resets==1 and not pc:IsMoveInputIgnored())
sb.to_room()
assert(#pc.views==4,'Given back once')
-- coop off in the menu: the view and the move input back.
sb.to_menu(); sb.off()
assert(pc.views[#pc.views]=='pawn 0 0 0 false' and not pc:IsMoveInputIgnored())
-- The next arrival (a new world, a new controller): the camera made again, the move input ignored again.
sb.to_menu()
cams[1].actor.alive,pc.ours=false,0
tick(S(1,'warping','3 warp done',LOBBY,1)); tick(S(1,'arrived','3 warp done',LOBBY,2))
sb.to_menu()
assert(#spawns==2 and pc.views[#pc.views]=='camera 2 0 0 0 false' and pc.ours==1 and stored=='/Game/Camera_2')
-- A Lua reload in the lobby (Review Focus 2): the camera an earlier load left swept at the first pass, then a new one.
fresh(nil,'/Game/Camera_7')
saves.steamid,room,eve=ME,new_room(),new_eve()
tick(HERE)
assert(list(sweeps)=='/Game/Camera_7' and stored==nil and #spawns==0,list(sweeps))
sb.to_menu()
assert(#sweeps==1 and list(spawns)==AGIT and stored=='/Game/Camera_1' and pc.ours==1)
-- coop sbo view: the camera manager's view; view set keeps it for the menu camera and moves a live one.
landed()
ok,why=sb.view()
assert(ok and why=='sbo view: X=-13000.0 Y=18000.1 Z=262.5 Pitch=-7.2 Yaw=171.5 FOV=80.0',why)
cm.fov=70
ok,why=sb.view_set()
assert(ok and why:find('^sbo view: X=%-13000%.0 .* FOV=70%.0'),why)
sb.to_menu()
assert(spawns[1]=='-13000.0 18000.1 262.5 -7.25 171.5 0' and cams[1].fov==70,list(spawns))
cm.at={X=-13100,Y=18100,Z=255}
sb.view_set()
assert(cams[1].moved=='-13100.0 18100.0 255.0 -7.25 171.5' and #spawns==1,tostring(cams[1].moved))
cm.at,cm.fov={X=-13000.04,Y=18000.06,Z=262.5},80
-- coop sbo seq: four aliases, in the lobby only.
landed()
asked={}
ok=sb.seq('Xion_10_E_Seq_011')
assert(ok and list(asked)=='sbo seq 5123 0',list(asked))
ok,why=sb.seq('Other')
assert(ok==false and why=='coop sbo seq: one of Xion_10_E_Seq_011, Xion_10_E_Seq_013, Xion_10_E_Seq_012, '
    ..'Xion_10_E_Seq_019' and #asked==1,why)
landed(ARENA)
ok,why=sb.seq('Xion_10_E_Seq_011')
assert(ok==false and why=='coop sbo seq: only in the SBO lobby' and #asked==0,why)
fresh(false)
assert(select(2,sb.view())==Sbo.OFF and select(2,sb.view_set())==Sbo.OFF
    and select(2,sb.seq('Xion_10_E_Seq_011'))==Sbo.OFF)

-- The hall lobbies (session/sbo_maps.lua): the lobby pak zSBO_Lobby in ~mods (core/pak_gate_test tests the gate), the
-- hall rows' answer (halls.ok()), the hall zones and points as FNames once their rows are in. Without the pak, or with
-- the rows not in yet or refused, the lobby is Xion as above, with one line saying why (a refusal's line is
-- session/halls_rows.lua's). With both, the entry warps to a hall drawn at random, with no Xion row edited; in a hall:
-- its spots with their own Z, its fence, its menu camera and FOV, no training room, no sequence, its status word; a
-- Lua reload there takes the hall from the client zone.
local Maps=require('session.sbo_maps')
for i,key in ipairs(Maps.order) do NAMES[Maps.maps[key].zone],NAMES[Maps.maps[key].point]=9100+i,9200+i end
local PAKS='C:\\G\\SB\\Content\\Paks'
local TOC='-==--==--==--==-'..string.pack('<BBI2I4I4I4I4I4I4I4I4',2,0,0,144,2,2,12,0,32,65536,0)
TOC=TOC..('\0'):rep(144-#TOC)..('\0'):rep(2*22)..string.pack('<I5I3I3BI5I3I3B',0,4096,4096,0,4096,1000,1000,0)
    ..'SB\0Content\0SBO_Lobby\0Lobby_Hotel.umap\0Lobby_Station.umap\0Lobby_Cloister.umap\0Lobby_Terrace.umap\0'
    ..'Lobby_Foyer.umap\0'
local VERSION=#TOC..'_5096' -- A word of lobby data: the .utoc and .ucas sizes joined by '_'.
local function lines(text) local k=0; for _,l in ipairs(logs) do if l:find(text,1,true) then k=k+1 end end; return k end
local function entered() joined(); tick(S(1,'open','1 enter done')) end
local XION_WARP=ENTER..',sbo warp 1692 0 1693 0'
-- targets_fall_back_to_xion_without_pak: no game folder, then no pak in it: Xion with its rows, said once.
gate_paks,hall_ok=nil,true
fresh(); entered()
assert(list(asked)==XION_WARP and list(writes)==list(SET),list(asked))
local NO_FOLDER='sbo: lobby in Xion: the game folder is unknown (the mod folder is not under SB\\Binaries\\Win64)'
assert(sb.hall()=='xion' and sb.draw()=='xion' and lines(NO_FOLDER)==1,list(logs))
assert(sb.lobby_words()=='xion xion',sb.lobby_words()) -- A match request's room and hall words.
gate_paks=PAKS
fresh(); entered()
assert(list(asked)==XION_WARP and lines('sbo: lobby in Xion: no '..PAKS..'\\~mods\\zSBO_Lobby.utoc or '..PAKS
    ..'\\LogicMods\\zSBO_Lobby.utoc')==1,list(logs))
-- The pak, the rows not in yet: Xion, said; then in: the halls. The rows refused: Xion, said by halls_rows only.
pak_files[PAKS..'\\~mods\\zSBO_Lobby.utoc']=TOC
pak_files[PAKS..'\\~mods\\zSBO_Lobby.pak'],pak_files[PAKS..'\\~mods\\zSBO_Lobby.ucas']='',''
hall_ok=nil
fresh(); entered()
assert(list(asked)==XION_WARP and lines('sbo: lobby in Xion: the hall rows are not in yet')==1,list(logs))
assert(sb.hall()=='xion')
hall_ok=true
assert(sb.hall()==VERSION and Maps.maps[sb.draw()],sb.hall())
local words_room,words_hall=sb.lobby_words():match('^(%a+) (%S+)$') -- Outside a lobby: a hall drawn.
assert(Maps.maps[words_room] and words_hall==VERSION,sb.lobby_words())
hall_ok=false
fresh(); entered()
assert(list(asked)==XION_WARP and lines('lobby in Xion')==0 and sb.hall()=='xion',list(logs))
-- join_draws_a_hall: the pak and the rows in; the draw is math.random's, and no Xion row is edited.
hall_ok=true
math.randomseed(11)
local k=math.random(5)
math.randomseed(11)
fresh(); entered()
local m=Maps.maps[Maps.order[k]]
assert(list(asked)==ENTER..string.format(',sbo warp %d 0 %d 0',NAMES[m.zone],NAMES[m.point]) and #writes==0,
    list(asked))
assert(sb.hall()==VERSION and lines('lobby in Xion')==0,list(logs))
for _=1,20 do assert(Maps.maps[sb.draw()]) end
-- warp_line_names_the_hall: the second map drawn is Station's zone and point.
local random=math.random
math.random=function(n) assert(n==5,n); return 2 end
fresh(); entered()
assert(list(asked)==ENTER..',sbo warp 9102 0 9202 0' and sb.draw()=='station',list(asked))
-- A hall zone that is not a name in this game run: sbo abort rows, the notice, as for Xion.
NAMES.Zone_SBO_Station=nil
fresh(); entered()
NAMES.Zone_SBO_Station=9102
math.random=random
assert(list(asked)==ENTER..',sbo abort rows' and said[#said]=='sbo.fail.warp'
    and logged('sbo: Zone_SBO_Station or SBO_Station is not a name in this game run'),list(asked))
-- place_uses_spot_z and show_room_skipped_without_room: the arrival in Station.
local STATION,HOTEL='9102:0','9101:0'
local st=Maps.maps.station
local function hall_spot(k) local p=st.spots[k]; return string.format('%.1f %.1f %.1f 0 %g 0',p.X,p.Y,p.Z,p.Yaw) end
landed(STATION)
assert(#room.calls==0 and list(eve.went)==hall_spot(2) and hall_spot(2)=='-3000.0 230.0 110.3 0 0 0',list(eve.went))
assert(logs[#logs]=='lobby Station, fence on (3971 cm)' and sb.in_lobby() and sb.target().key=='station',list(logs))
assert(sb.lobby_words()=='station '..VERSION,sb.lobby_words())
assert(select(2,sb.status())=='sbo: record arrived slot 2, zone station, loader 3, spot 2, fence on, room -, copy -',
    select(2,sb.status()))
-- Its fence: centre -287.5 0, 39.71 m.
local IN_STATION=S(1,'arrived','2 warp done',STATION,1)
tick(IN_STATION)
eve.at={X=3683,Y=0,Z=110}; tick(IN_STATION)
assert(#eve.went==1,'Inside Station\'s fence')
eve.at={X=3685,Y=0,Z=110}; tick(IN_STATION)
assert(eve.went[2]==hall_spot(2) and logs[#logs]=='lobby fence: EVE at 3685 0 110, back to spot 2',list(logs))
-- to_menu_uses_target_fov: Station's camera with its FOV 70; a view set is kept for Station only.
sb.to_menu()
assert(list(spawns)=='-3750.0 0.0 500.0 -3 0 0' and cams[1].fov==70,list(spawns))
sb.view_set()
cams[1].actor.alive=false
tick(S(1,'warping','3 warp done',STATION,1)); tick(S(1,'arrived','3 warp done',HOTEL,2))
sb.to_menu()
assert(spawns[2]=='500.0 1330.0 480.0 3.72 -118.23 0' and cams[2].fov==60,list(spawns))
cams[2].actor.alive=false
tick(S(1,'warping','4 warp done',HOTEL,2)); tick(S(1,'arrived','4 warp done',STATION,3))
sb.to_menu()
assert(spawns[3]=='-13000.0 18000.1 262.5 -7.25 171.5 0' and cams[3].fov==80,list(spawns))
-- seq_xion_only: Zone_Xion_10's sequences are Xion's.
asked={}
ok,why=sb.seq('Xion_10_E_Seq_011')
assert(ok==false and why=='coop sbo seq: only in the SBO lobby in Xion' and #asked==0,why)
-- coop sbo hop from a hall, and back to that hall.
landed(STATION)
asked={}
assert(sb.hop() and list(asked)=='sbo warp 3191 0 3192 0',list(asked))
tick(S(1,'warping','3 warp done',STATION,1)); tick(S(1,'arrived','3 warp done',ARENA,2))
asked={}
assert(sb.back() and list(asked)=='sbo warp 9102 0 9202 0',list(asked))
-- reload_keeps_target_from_zone: a Lua reload in Station: Station from the client zone, no draw, EVE left where she
-- stands, Station's fence.
math.random=function() error('no draw at a reload in a hall') end
fresh()
saves.steamid,room,eve=ME,new_room(),new_eve(-1000,0,110)
tick(S(1,'arrived','2 warp done',STATION,4)); tick(S(1,'arrived','2 warp done',STATION,4))
math.random=random
assert(sb.in_lobby() and sb.target().key=='station' and #eve.went==0 and #room.calls==0)
assert(logged('lobby Station, fence on (3971 cm), EVE left where she stands'),list(logs))
eve.at={X=3685,Y=0,Z=110}; tick(S(1,'arrived','2 warp done',STATION,4))
assert(list(eve.went)==hall_spot(1),list(eve.went))
-- The match lobby's map and pak version (link.room(), link.hall()), followed by a guest only: a host's lobby names the
-- map she stood on, and a co-op lobby names none. member_on_other_hall_warps_once: a guest of a lobby in Hotel,
-- standing in Station, warps there once in that arrival, even when the native part refuses the warp; in Hotel, nothing.
landed(STATION)
asked={}
mode,steam='guest',{lobby='5'}
tick(IN_STATION)
assert(#asked==0,'A co-op lobby')
mode,steam='host',{lobby='7',owner=ME,room='hotel',hall=VERSION}
tick(IN_STATION)
assert(#asked==0,'Our own lobby')
mode,steam='guest',{lobby='7',owner='76561198000000009',room='hotel',hall=VERSION}
tick(IN_STATION); tick(IN_STATION)
assert(list(asked)=='sbo warp 9101 0 9201 0' and logged('sbo: match lobby 7: map hotel: warp there'),list(logs))
tick(S(1,'arrived','3 warp busy',STATION,1)); tick(S(1,'arrived','3 warp busy',STATION,1))
assert(#asked==1 and said[#said]=='sbo.no.busy',list(asked))
landed(STATION)
mode,steam='guest',{lobby='7',owner='76561198000000009',room='hotel',hall=VERSION}
asked={}
tick(IN_STATION)
local IN_HOTEL=S(1,'arrived','3 warp done',HOTEL,2)
tick(S(1,'warping','3 warp done',STATION,1)); tick(IN_HOTEL); tick(IN_HOTEL)
assert(list(asked)=='sbo warp 9101 0 9201 0' and sb.target().key=='hotel',list(asked))
-- regroup_to_other_room_warps_once: ruling R1 moves the lone host of that lobby into a lower lobby in Station, as
-- its guest: one warp there.
mode,steam='host',{lobby='8',owner=ME,room='hotel',hall=VERSION}
tick(IN_HOTEL)
mode,steam='guest',{lobby='6',owner='76561198000000003',room='station',hall=VERSION}
tick(IN_HOTEL); tick(IN_HOTEL)
assert(list(asked)=='sbo warp 9101 0 9201 0,sbo warp 9102 0 9202 0',list(asked))
-- room_we_lack_leaves_with_notice: a lobby on a map this game does not have, or of another pak version (a join by
-- code skips the search's filter): its line, the notice and a leave, once a lobby; nobody warps.
landed(STATION)
asked,said={},{}
mode,steam='guest',{lobby='7',owner='76561198000000009',room='garden',hall=VERSION}
tick(IN_STATION); tick(IN_STATION)
assert(list(asked)=='leave' and list(said)=='sbo.no.hall'
    and logged('sbo: match lobby 7: map garden, pak '..VERSION..' (ours '..VERSION..'): left'),list(logs))
steam={lobby='9',owner='76561198000000009',room='hotel',hall='1_2'}
tick(IN_STATION); tick(IN_STATION)
assert(list(asked)=='leave,leave' and list(said)=='sbo.no.hall,sbo.no.hall',list(asked))
-- rejoin_after_leave_leaves_again: once per joined lobby: the same lobby joined again in the same arrival (its code
-- tried again after the notice) is left again with the notice.
mode,steam='none',nil
tick(IN_STATION)
mode,steam='guest',{lobby='9',owner='76561198000000009',room='hotel',hall='1_2'}
tick(IN_STATION); tick(IN_STATION)
assert(list(asked)=='leave,leave,leave' and list(said)=='sbo.no.hall,sbo.no.hall,sbo.no.hall',list(asked))
-- xion_lobby_left_in_halls: with the halls in use, a lobby that names Xion is a map the entries here do not use.
steam={lobby='10',owner='76561198000000009',room='xion',hall=VERSION}
tick(IN_STATION)
assert(list(asked)=='leave,leave,leave,leave' and #said==4,list(asked))
-- Without the pak, in Xion: a lobby in a hall is left; one in Xion is where she stands.
gate_paks=nil
landed()
asked,said={},{}
mode,steam='guest',{lobby='7',owner='76561198000000009',room='hotel',hall=VERSION}
tick(HERE); tick(HERE)
assert(list(asked)=='leave' and list(said)=='sbo.no.hall' and sb.lobby_words()=='xion xion',list(asked))
steam={lobby='9',owner='76561198000000009',room='xion',hall='xion'}
tick(HERE)
assert(list(asked)=='leave' and #said==1,list(asked))
-- A Private match on the host's map (create): without the halls, Xion's words whatever the pick.
asked={}
assert(sb.create('match create ffa','hotel') and list(asked)=='match create ffa xion xion',list(asked))
-- private_other_room_warps_then_creates: on the hall EVE stands in, the request at once; on another, the warp there,
-- then the request with that hall's words once she arrives in it.
gate_paks=PAKS
landed(STATION)
asked={}
assert(sb.create('match create ffa','station') and list(asked)=='match create ffa station '..VERSION,list(asked))
asked={}
assert(sb.create('match create ffa','hotel') and list(asked)=='sbo warp 9101 0 9201 0',list(asked))
ok,why=sb.create('match create ffa','foyer') -- Private selected again before the warp starts: refused.
assert(ok==false and why=='a Private match waits for its warp to Hotel' and #asked==1,why)
tick(S(1,'warping','3 warp done',STATION,1))
assert(#asked==1,'Not before the arrival')
tick(IN_HOTEL); tick(IN_HOTEL)
assert(list(asked)=='sbo warp 9101 0 9201 0,match create ffa hotel '..VERSION,list(asked))
assert(logged('sbo: private match in hotel: asked the native part: match create ffa hotel '..VERSION),list(logs))
-- A warp the native part refuses (busy): its notice, and no request at a later arrival.
landed(STATION)
asked,said={},{}
sb.create('match create ffa','hotel')
tick(S(1,'arrived','3 warp busy',STATION,1))
tick(S(1,'warping','4 warp done',STATION,1)); tick(S(1,'arrived','4 warp done',HOTEL,2))
assert(list(asked)=='sbo warp 9101 0 9201 0' and said[#said]=='sbo.no.busy',list(asked))
-- A warp that lands in another lobby than the one picked (back in Station): its line, and no request.
landed(STATION)
asked={}
sb.create('match create ffa','hotel')
tick(S(1,'warping','3 warp done',STATION,1)); tick(S(1,'arrived','3 warp done',STATION,2))
assert(list(asked)=='sbo warp 9101 0 9201 0'
    and logged('sbo: private match in hotel: the warp landed elsewhere, not created'),list(logs))
-- A session that closes while the warp runs takes the pending request with it: no request at a later arrival in the
-- picked hall, and a new Private match is asked, not refused.
landed(STATION)
asked={}
sb.create('match create ffa','hotel')
tick(S(1,'leaving','3 warp done',STATION,1)); tick(S(1,'closed','3 warp done',STATION,1))
tick(S(1,'warping','3 warp done',STATION,1)); tick(S(1,'arrived','3 warp done',HOTEL,2))
assert(list(asked)=='sbo warp 9101 0 9201 0',list(asked))
assert(sb.create('match create ffa','hotel') and list(asked)=='sbo warp 9101 0 9201 0,match create ffa hotel '..VERSION,
    list(asked))
-- A warp refused on the Lua side (the hall's zone not a name in this game run): its why, no request, and a new Private
-- match is asked, not refused.
landed(STATION)
asked={}
NAMES.Zone_SBO_Hotel=nil
ok,why=sb.create('match create ffa','hotel')
NAMES.Zone_SBO_Hotel=9101
assert(ok==false and why=='Zone_SBO_Hotel or SBO_Hotel is not a name in this game run' and #asked==0,why)
assert(sb.create('match create ffa','hotel') and list(asked)=='sbo warp 9101 0 9201 0',list(asked))
-- private_random_draws: Random is a draw among the halls: Station's creates where EVE stands, Cloister's warps first.
landed(STATION)
asked={}
math.random=function(n) assert(n==5,n); return 2 end
sb.create('match create ffa','random')
math.random=function() return 3 end
sb.create('match create ffa','random')
math.random=random
assert(list(asked)=='match create ffa station '..VERSION..',sbo warp 9103 0 9203 0',list(asked))
-- SB's chairs (Sbo.CHAIRS) for the hall seats. chair_at: for each kind, the seated offset turned by the actor's yaw
-- lands on the seat's X and Y, Z is the seat's floor, and EVE's facing (actor +X, or -X for a table) is the seat's yaw.
local ZE='/Game/GameDesign/Level/ZoneEnv/'
local CH=Sbo.CHAIRS
assert(CH.outdoor.asset==ZE..'Env_Chair_05.Env_Chair_05' and CH.bar.asset==ZE..'Env_Chair_03.Env_Chair_03'
    and CH.table.asset==ZE..'Env_Chair_04.Env_Chair_04' and CH.camp==nil)
assert(list(Sbo.CHAIRS.outdoor.parts)=='079_A_SM,BoxCollision' and list(Sbo.CHAIRS.bar.parts)=='121_H_SM'
    and list(Sbo.CHAIRS.table.parts)=='Chair,Table,Capsule')
for kind,ch in pairs(Sbo.CHAIRS) do
    for _,yaw in ipairs({-90,0,37.5,180}) do
        local a=Sbo.chair_at({kind=kind,X=100,Y=-200,Z=12.5,Yaw=yaw})
        local r=math.rad(a.Yaw)
        local x=a.X+ch.seated.X*math.cos(r)-ch.seated.Y*math.sin(r)
        local y=a.Y+ch.seated.X*math.sin(r)+ch.seated.Y*math.cos(r)
        local facing=(a.Yaw+(kind=='table' and 180 or 0)-yaw)%360
        assert(math.abs(x-100)<1e-9 and math.abs(y+200)<1e-9 and a.Z==12.5 and facing==0,kind..' '..yaw)
    end
end
-- Hotel's seat 1 (outdoor, yaw -90): SB seats EVE at (-1.31, 4.54) in the actor's frame, so the actor stands 4.54 cm
-- to -X and 1.31 cm to -Y of the seat, turned as the seat.
local hotel=Maps.maps.hotel
local a1=Sbo.chair_at(hotel.seats[1])
assert(math.abs(a1.X+914.54)<1e-9 and math.abs(a1.Y-2317.69)<1e-9 and a1.Z==86.2 and a1.Yaw==-90,a1.X..' '..a1.Y)
local function at_seat(s) eve.at={X=s.X,Y=s.Y,Z=s.Z+100} end
-- The last line logged that matches pattern p, or nil.
local function matched(p)
    for i=#logs,1,-1 do if logs[i]:match(p) then return logs[i] end end
end
local AT_HOTEL=S(1,'arrived','2 warp done',HOTEL,1)
-- arrival_spawns_one_chair_per_seat: a hall arrival spawns SB's chair at each of its seats, in the arrival's pass on
-- the budget: the kind's class (looked up once a kind), the seat's row, the place chair_at gives and the kind's parts
-- to hide. A spawn that raises is logged with its seat and the rest go on. menu_key sits nowhere before the bind check.
-- landed() with setup() run on the fresh world before its two ticks.
local function landed_with(zone,setup)
    fresh()
    saves.steamid,roster,room,eve=ME,ids('76561198000000009','76561198000000003',ME),new_room(),new_eve()
    setup()
    tick(S(1,'warping','2 warp done',LOBBY,0)); tick(S(1,'arrived','2 warp done',zone,1))
end
landed(HOTEL)
tick(AT_HOTEL) -- No second spread in the same arrival.
assert(#hotel.seats==25 and #chairs_made==25 and list(class_asks)==ZE..'Env_Chair_05.Env_Chair_05,'..ZE
    ..'Env_Chair_03.Env_Chair_03,'..ZE..'Env_Chair_04.Env_Chair_04',list(class_asks))
assert(chairs_made[1]=='Env_Chair_05 SBO_Hotel_Seat001 -914.54 2317.69 86.2 -90 079_A_SM+BoxCollision',chairs_made[1])
landed_with(HOTEL,function()
    refused.SBO_Hotel_Seat013,bind_zone,unbound.SBO_Hotel_Seat012=true,'Zone_SBO_Hotel',true
end)
assert(#chairs_made==24 and logged('lobby seat 13 (bar): no chair: FinishSpawningActor gave nothing'),list(logs))
local s1,s12,s13=hotel.seats[1],hotel.seats[12],hotel.seats[13]
assert(s12.kind=='bar' and s13.kind=='bar')
at_seat(s12)
assert(sb.near_seat()==nil,'No seat before the bind check')
-- bind_check_names_fallback_seats: 1 s after the last spawn with SB's loader done, once: a chair is bound when SB gave
-- it the hall's zone and its seat's row. One line for the arrival; menu_key then sits only on the seats left (no
-- chair, or one SB did not bind), whose sit loops are looked up, once a kind.
tick(AT_HOTEL,0.9)
assert(not matched('chairs:'),list(logs))
tick(S(1,'arrived','2 warp done',HOTEL,1),1) -- loader 3 (S gives it).
local line='lobby Hotel chairs: 24 of 25 spawned in (%d+) ms %(1 pass%), 23 bound; menu_key sits on seats 12 13, '
    ..'sit loops looked up: bar'
assert(matched('^'..line..'$'),list(logs))
assert(list(em.preloads)=='bar',list(em.preloads))
local n_logs=#logs
tick(AT_HOTEL,5)
assert(#logs==n_logs and #em.preloads==1,'Checked once')
assert(sb.near_seat()==s12,'Not bound: menu_key sits there')
at_seat(s13)
assert(sb.near_seat()==s13,'No chair: menu_key sits there')
at_seat(s1)
assert(sb.near_seat()==nil,'Bound: SB seats her')
-- bind_read_error_logged: a bind read that raises leaves its seat to menu_key; the first such error of the check is
-- logged with its seat, a later one is not. A sit loop look-up that raises gives its error next to its kind.
landed_with(HOTEL,function()
    bind_zone,unbound.SBO_Hotel_Seat002='Zone_SBO_Hotel',true
    bind_raise.SBO_Hotel_Seat003,bind_raise.SBO_Hotel_Seat012='BindZoneAlias: no such property','EnvSpawnAlias: gone'
    em.preload_error={bar='Doro.resolve: boom'}
end)
tick(AT_HOTEL,1)
assert(logged('lobby seat 3 (outdoor): its chair\'s bind did not read (the first such error of this check): '
    ..'BindZoneAlias: no such property') and not matched('^lobby seat 12 '),list(logs))
assert(matched('^lobby Hotel chairs: 25 of 25 spawned in %d+ ms %(1 pass%), 22 bound; menu_key sits on seats 2 3 12, '
    ..'sit loops looked up: outdoor, bar %(error: Doro%.resolve: boom%)$'),list(logs))
-- no_fallback_seat_during_sb_interaction: SB seats EVE on seat 1's chair; seat 2, unbound and 70 cm away, is not
-- offered while SB's interaction runs (menu_key opens B), and is again once it ends.
local s2=hotel.seats[2]
at_seat(s1)
assert(sb.near_seat()==s2,'Seat 2 within reach')
assert(sb.busy()==false,'No interaction: Enter may open the chat')
eve.interacting=true
tick(AT_HOTEL,1.25)
assert(sb.near_seat()==nil,'SB seats her: menu_key opens B')
assert(sb.busy()==true,'SB\'s Get up choice takes Enter')
eve.interacting=false
tick(AT_HOTEL,1.5)
assert(sb.near_seat()==s2 and sb.busy()==false,'Offered again')
-- The check waits for SB's zone loader.
landed(HOTEL)
local loading=S(1,'arrived','2 warp done',HOTEL,1)
loading.loader=1
tick(loading,3)
assert(not matched('chairs:'),list(logs))
tick(AT_HOTEL,3)
assert(matched('^lobby Hotel chairs: 25 of 25 spawned in %d+ ms %(1 pass%), 0 bound; menu_key sits on seats 1 2 3 '),
    list(logs))
assert(list(em.preloads)=='outdoor,bar,table',list(em.preloads))
-- Loader 4 (a zone reset), which the native arrival latch takes too: the check runs.
landed(HOTEL)
local reset=S(1,'arrived','2 warp done',HOTEL,1)
reset.loader=4
tick(reset,3)
assert(matched('^lobby Hotel chairs: 25 of 25 spawned in %d+ ms %(1 pass%), 0 bound; '),list(logs))
-- chairs_spread_on_budget: past the budget, one a pass; a warp under way stops the spread, and the next arrival's
-- spread starts over in its own hall.
local budget=Sbo.CHAIR_BUDGET
Sbo.CHAIR_BUDGET=-1
landed(HOTEL)
assert(#chairs_made==1,#chairs_made)
tick(AT_HOTEL)
assert(#chairs_made==2,#chairs_made)
tick(S(1,'warping','3 warp done',HOTEL,1))
assert(#chairs_made==2,'Not while warping')
tick(S(1,'arrived','3 warp done',STATION,2))
assert(#chairs_made==3 and chairs_made[3]:find('^%S+ SBO_Station_Seat%d+ '),chairs_made[3])
Sbo.CHAIR_BUDGET=budget
-- A new arrival in the same hall spawns again (the map change took the old chairs).
landed(HOTEL)
tick(S(1,'warping','3 warp done',HOTEL,1)); tick(S(1,'arrived','3 warp done',HOTEL,2))
assert(#chairs_made==50,#chairs_made)
-- class_missing_skips_its_kind: a class that does not load is asked once; its kind's seats get no chair, each logged.
landed_with(HOTEL,function() no_class[ZE..'Env_Chair_05.Env_Chair_05']=true end)
local outdoor,asked_05=0,0
for _,s in ipairs(hotel.seats) do if s.kind=='outdoor' then outdoor=outdoor+1 end end
for _,a in ipairs(class_asks) do if a:find('Env_Chair_05',1,true) then asked_05=asked_05+1 end end
assert(asked_05==1 and #chairs_made==25-outdoor and logged('lobby seat 1 (outdoor): no chair: '..ZE
    ..'Env_Chair_05.Env_Chair_05_C does not load'),list(logs))
-- camp_seats_get_no_chair: Cloister's two camp seats have no row: no chair, and menu_key sits on them.
landed_with('9103:0',function() bind_zone='Zone_SBO_Cloister' end)
tick(S(1,'arrived','2 warp done','9103:0',1),1)
local cl=Maps.maps.cloister
assert(#chairs_made==#cl.seats-2 and not list(chairs_made):find('camp',1,true),#chairs_made)
assert(matched('^lobby Cloister chairs: 24 of 24 spawned in %d+ ms %(1 pass%), 24 bound; menu_key sits on seats 37 38, '
    ..'sit loops looked up: camp %(missing%)$'),list(logs))
-- no_chairs_in_xion_or_arena
landed()
tick(HERE,2)
assert(#chairs_made==0 and #class_asks==0 and not list(logs):find('chairs',1,true),list(logs))
landed(ARENA)
tick(S(1,'arrived','2 warp done',ARENA,1),2)
assert(#chairs_made==0 and #class_asks==0,list(chairs_made))
-- reload_spawns_no_chair: a Lua load in a hall finds the earlier load's chairs there: none spawned; their binds read
-- as the check reads them, menu_key sits on each seat none of them is bound to (12 unbound, 13's chair gone), their sit
-- loops looked up. A find that raises leaves every seat to menu_key, logged.
fresh()
saves.steamid,room,eve=ME,new_room(),new_eve(-1000,0,110)
bind_zone,unbound.SBO_Hotel_Seat012='Zone_SBO_Hotel',true
for _,x in ipairs(hotel.seats) do
    local asset=Sbo.CHAIRS[x.kind].asset
    left_chairs[asset]=left_chairs[asset] or {}
    if x.n~=13 then table.insert(left_chairs[asset],x.row) end
end
tick(AT_HOTEL); tick(AT_HOTEL,2)
assert(#chairs_made==0 and logged('lobby Hotel chairs: none spawned after a Lua load (the earlier load\'s stay), 23 '
    ..'bound; menu_key sits on seats 12 13, sit loops looked up: bar'),list(logs))
at_seat(s1)
assert(sb.near_seat()==nil,'Bound: SB seats her')
at_seat(s12)
assert(sb.near_seat()==s12,'Not bound: menu_key sits there')
fresh()
saves.steamid,room,eve=ME,new_room(),new_eve(-1000,0,110)
left_raise='GetAllActorsOfClass: boom'
tick(AT_HOTEL); tick(AT_HOTEL,2)
assert(logged('lobby Hotel chairs: the earlier load\'s binds did not read: GetAllActorsOfClass: boom')
    and matched('^lobby Hotel chairs: none spawned after a Lua load %(the earlier load\'s stay%), 0 bound; menu_key '
    ..'sits on seats 1 2 [%d ]+, sit loops looked up: outdoor, bar, table$'),list(logs))
at_seat(s1)
assert(sb.near_seat()==s1)
-- sb_interaction_logged: SB's interaction on EVE in a hall (IsRunningInteraction), logged as it starts, with the seat
-- nearest her, and as it ends; once each.
landed(HOTEL)
eve.at,eve.interacting={X=s1.X+30,Y=s1.Y+40,Z=s1.Z+100},true
tick(AT_HOTEL)
assert(logs[#logs]=='lobby seat 1 (outdoor): SB\'s interaction runs, EVE 50 cm from it',logs[#logs])
n_logs=#logs
tick(AT_HOTEL)
assert(#logs==n_logs,'Logged once')
eve.interacting=false
tick(AT_HOTEL)
assert(logs[#logs]=='lobby seat 1: SB\'s interaction ended',logs[#logs])
-- The F5 sit on a seat left to menu_key (here every seat: SB bound none). near_seat(): the nearest such seat of the
-- hall EVE stands in within 1.5 m of where she stands on it; none while EVE sits, and none in Xion. A member's copy on
-- a seat leaves it free (two EVEs may sit in one place). sit(seat): her collision off, the teleport to the seat at her
-- standing height (her mesh's 97 cm over the floor), her movement held (MOVE_None: with no collision she would fall
-- through the floor) and the seat's loop. stand(), or the loop's end (coop emote's end rules), or coop off: the loop
-- stopped, the teleport to the seat's approach point while her collision is still off (with it on the game's spot
-- test refused every stand-up of the 2026-11-14 test), then her collision back and walking, also when the teleport
-- raises; the next pass logs where she stands. A seat refused on the way is undone the same way. An arrival forgets
-- the seat (a new EVE), and so does a loop ended by a warp's new EVE; a Lua load in a hall that finds her collision off
-- stands her up at the nearest seat's approach point.
local seat1,seat2=hotel.seats[1],hotel.seats[2]
assert(seat1.n==1 and seat1.kind=='outdoor' and seat1.X==-910 and seat2.n==2 and seat2.X==-980)
local SIT_1='collision false false,teleport -910.0 2319.0 183.2 0 -90 0,mode 0 0,loop outdoor'
local UP_1='teleport -910.0 2259.0 186.1 0 -90 0,collision true false,mode 1 0'
landed()
eve.at={X=c.X,Y=c.Y,Z=-15700}
assert(sb.near_seat()==nil,'No seats in Xion')
landed(HOTEL)
tick(AT_HOTEL,1) -- The bind check: SB bound none (bind_zone nil).
eve.at,eve.did={X=-910,Y=2200,Z=183},{}
assert(sb.near_seat()==seat1,'The nearest')
-- sit_turns_collision_off_then_plays_loop
ok,why=sb.sit(seat1)
assert(ok and list(eve.did)==SIT_1 and sb.seated()==seat1 and sb.near_seat()==nil,list(eve.did))
assert(logs[#logs]=='lobby seat 1 (outdoor): sat',list(logs))
ok,why=sb.sit(seat2)
assert(ok==false and why=='EVE is already seated' and #em.sits==1,why)
tick(AT_HOTEL); tick(AT_HOTEL)
assert(list(eve.did)==SIT_1 and sb.seated()==seat1,'Seated while the loop plays')
-- stand_teleports_then_restores_collision: the loop ends (movement input, a jump, a skill): up at the approach point,
-- then her collision back and walking.
em.on=false
tick(AT_HOTEL)
assert(list(eve.did)==SIT_1..','..UP_1 and sb.seated()==nil,list(eve.did))
assert(logs[#logs]=='lobby seat 1: stood up at the approach point (the loop ended)',list(logs))
-- A pass later, her collision back since: where she stands and how far from the approach point, once.
eve.at={X=-910,Y=2262,Z=186.1}
tick(AT_HOTEL)
assert(logs[#logs]=='lobby seat 1: a pass after she stood up, EVE at -910 2262 186, 3 cm from the approach point',
    logs[#logs])
n_logs=#logs
tick(AT_HOTEL)
assert(#logs==n_logs,'Logged once')
-- stand(): the menu key while seated stops the loop first.
eve.did={}
sb.sit(seat1)
ok,why=sb.stand()
assert(ok and why=='seat 1: stood up' and em.stops[#em.stops]=='stand up' and list(eve.did)==SIT_1..','..UP_1,
    list(eve.did))
ok,why=sb.stand()
assert(ok==false and why=='EVE is not seated',why)
-- The loop refused: undone, up at the approach point.
eve.did,em.refuse={},'EVE is busy (a skill runs): try again once she stands'
ok,why=sb.sit(seat1)
em.refuse=nil
assert(ok==false and why=='seat 1: EVE is busy (a skill runs): try again once she stands' and sb.seated()==nil,why)
assert(list(eve.did)=='collision false false,teleport -910.0 2319.0 183.2 0 -90 0,mode 0 0,'..UP_1,list(eve.did))
-- The teleport to the seat refused: undone the same way.
eve.did,eve.refuse={},1
ok,why=sb.sit(seat1)
assert(ok==false and why=='seat 1: the game refused the teleport' and #em.sits==2,why)
assert(list(eve.did)=='collision false false,teleport -910.0 2319.0 183.2 0 -90 0,'..UP_1,list(eve.did))
-- A teleport to the approach point refused: her collision and walking back where she sat, logged.
sb.sit(seat1)
eve.did,eve.refuse={},1
sb.stand()
assert(list(eve.did)==UP_1 and sb.seated()==nil,list(eve.did))
assert(logs[#logs]=='lobby seat 1: stood up where she sat, the game refused the teleport to the approach point '
    ..'(stand up)',list(logs))
-- A teleport to the approach point that raises: her collision and walking back all the same, the error logged.
sb.sit(seat1)
eve.did={}
local teleport=eve.K2_TeleportTo
eve.K2_TeleportTo=function() error('TeleportTo: boom',0) end
sb.stand()
eve.K2_TeleportTo=teleport
assert(list(eve.did)=='collision true false,mode 1 0' and sb.seated()==nil,list(eve.did))
assert(logs[#logs]=='lobby seat 1: stood up with an error: TeleportTo: boom (stand up)',logs[#logs])
-- An arrival forgets the seat: no stand-up in the new world (its EVE is a new one).
sb.sit(seat1)
eve.did={}
tick(S(1,'warping','3 warp done',HOTEL,1)); tick(S(1,'arrived','3 warp done',STATION,2))
assert(sb.seated()==nil and not list(eve.did):find('collision',1,true),list(eve.did))
-- Seated when a warp starts (the regroup, a guest's follow, a Private create, hop, a round, sbo leave): coop emote ends
-- the loop on the new world's EVE before the record reads arrived. The seat is forgotten with its line, and nothing
-- is asked of that EVE, nor of none, nor of a new EVE the game put at the old one's address.
for _,next_eve in ipairs({'new','none','same'}) do
    landed(HOTEL)
    tick(AT_HOTEL,1)
    eve.at={X=-910,Y=2200,Z=183}
    sb.sit(seat1)
    tick(S(1,'warping','4 warp done',HOTEL,1))
    assert(sb.seated()==seat1,'Still seated while the warp starts')
    local old=eve.address
    eve,em.on=next_eve~='none' and new_eve(500,500,100) or nil,false
    if next_eve=='same' then eve.address=old end
    logs={}
    tick(S(1,'warping','4 warp done',HOTEL,1))
    assert(sb.seated()==nil and (not eve or #eve.did==0),eve and list(eve.did))
    assert(logs[#logs]==({new='lobby seat 1: forgotten, her EVE changed (the loop ended)',
        none='lobby seat 1: forgotten, no EVE in the world (the loop ended)',
        same='lobby seat 1: forgotten, a warp since she sat (the loop ended)'})[next_eve],list(logs))
end
-- coop off while seated: up at the approach point.
landed(HOTEL)
tick(AT_HOTEL,1)
eve.at={X=-910,Y=2200,Z=183}
sb.sit(seat1)
eve.did={}
local read=rows.read
rows.read=function() error('rows: boom',0) end -- A put-back that raises: she stood up before it.
assert(select(2,pcall(sb.off))=='rows: boom')
rows.read=read
assert(list(eve.did)==UP_1 and em.stops[#em.stops]=='coop off' and sb.seated()==nil,list(eve.did))
-- A Lua load in a hall with EVE left seated by the last one (her collision off): up at the approach point of the seat
-- nearest her, as a stand-up, once.
fresh()
saves.steamid,room,eve=ME,new_room(),new_eve(-910,2319,183.2)
eve.collide=false
tick(AT_HOTEL); tick(AT_HOTEL)
assert(list(eve.did)==UP_1 and sb.target().key=='hotel',list(eve.did))
assert(logged('lobby seat 1: an earlier Lua load left EVE seated: stood up at the approach point'),list(logs))
-- In Xion (no seats) such a load changes nothing of EVE's.
fresh()
saves.steamid,room,eve=ME,new_room(),new_eve()
eve.collide=false
tick(HERE); tick(HERE)
assert(not list(eve.did):find('collision',1,true) and eve.collide==false and sb.target()==Sbo.XION,list(eve.did))
-- skipped_seats_never_offered: Hotel's low benches 22 to 29 are not in the module (seat 22 stands at -557 -68).
for _,s in ipairs(hotel.seats) do assert(s.n<22 or s.n>29,s.n) end
landed(HOTEL)
tick(AT_HOTEL,1)
eve.at={X=-557,Y=-68,Z=97}
assert(sb.near_seat()==nil,'A skipped seat')
-- The arrival's hold: each warp into a lobby arms it (the entry's, a guest's follow, a Private match's, coop sbo back),
-- the hop to an arena does not; a lobby warp the native part ends without an arrival, SB's own reload and coop off
-- disarm it.
math.random=function() return 2 end
fresh(); entered()
assert(list(asked)==ENTER..',sbo warp 9102 0 9202 0' and hold.arms==1,list(asked))
tick(S(1,'closed','2 warp zone'))
assert(list(hold.disarms)=='the warp ended: zone',list(hold.disarms))
landed(STATION)
asked={}
sb.hop()
tick(S(1,'warping','3 warp done',STATION,1)); tick(S(1,'arrived','3 warp done',ARENA,2))
assert(list(asked)=='sbo warp 3191 0 3192 0' and hold.arms==0,list(asked))
sb.back()
assert(list(asked)=='sbo warp 3191 0 3192 0,sbo warp 9102 0 9202 0' and hold.arms==1,list(asked))
landed(STATION)
mode,steam='guest',{lobby='7',owner='76561198000000009',room='hotel',hall=VERSION}
tick(IN_STATION)
assert(hold.arms==1 and #hold.disarms==0)
tick(S(1,'arrived','3 warp busy',STATION,1))
assert(list(hold.disarms)=='the warp ended: busy',list(hold.disarms))
mode,steam='none',nil
landed(STATION)
sb.create('match create ffa','hotel')
assert(hold.arms==1)
sb.create('match create ffa','station') -- Where she stands: no warp.
assert(hold.arms==1)
sb.off()
assert(list(hold.disarms)=='coop off',list(hold.disarms))
landed(STATION)
tick(S(1,'arrived','3 sb running',STATION,1))
assert(list(hold.disarms)=='SB\'s reload',list(hold.disarms))
math.random=random
-- unready(): what the lobby waits for under the hold: the arrival, EVE on her spot, a hall's bind check, the menu
-- camera's view; none once all are done. In Xion: no chairs.
fresh()
assert(list(sb.unready())=='arrival')
tick(S(1,'warping','2 warp done',LOBBY,0))
assert(list(sb.unready())=='arrival')
landed_with(HOTEL,function() saves.steamid=nil end) -- No SteamID yet: no spot.
assert(list(sb.unready())=='spot,chairs,camera',list(sb.unready()))
saves.steamid=ME
tick(AT_HOTEL,0.5)
assert(list(sb.unready())=='chairs,camera',list(sb.unready()))
tick(AT_HOTEL,1.5)
assert(list(sb.unready())=='camera',list(sb.unready()))
sb.to_menu()
assert(#sb.unready()==0)
landed()
assert(list(sb.unready())=='camera',list(sb.unready()))
-- Under the hold the chairs spawn on HELD_BUDGET (a black hides the frames they take): all 25 in the arrival's pass
-- here, where CHAIR_BUDGET alone spawns one.
assert(Sbo.HELD_BUDGET==0.1)
Sbo.CHAIR_BUDGET=-1
landed_with(HOTEL,function() hold.on=true end)
assert(#chairs_made==25,#chairs_made)
Sbo.CHAIR_BUDGET=budget
print('sbo_test ok')
