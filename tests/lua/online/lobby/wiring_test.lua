-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop sbo and the SBO lobby's wiring (online/lobby/wiring.lua), with online/lobby/sbo.lua stubbed by the fixture
-- (online/lobby/sbo_test tests the module): what sbo.new gets, the console words and the gate, sbo on at load, the 250
-- ms tick, the title's put-back, coop off, the recruiter's Join armed once he stands there (with sbo_lobby=on only: the
-- arm swaps a slot in the game's image), his auto spawn every 250 ms on any save and the say that turns a notice key
-- into words (main/collide_test tests the ghost's collision during a session). Then the lobby screens
-- (online/lobby/ui/lobby.lua stubbed by the fixture, online/lobby/ui/lobby_test tests them): their view and act, the
-- input routed to them (keys, pad, mouse), the arrival, the countdown feed, the round's start line and the focus
-- watchdog. Last, the arrival's hold under SB's black.
dofile('tests/lua/main/fixture.lua')
local T=require('ui.text')
local OFF='the SBO lobby is off in coop-settings.txt (sbo_lobby=off)'
local USE='Use: coop sbo enter | leave | status | hop | back | view [set] | seq <alias> | parts'
settings_text='sbo_lobby=on\n'
load_main(true)
assert(sb.o and sb.o.settings.sbo_lobby==true and sb.o.link==fake_link and sb.o.recruiter and sb.o.nightop)
assert(type(sb.o.fight)=='function' and type(sb.o.say)=='function' and type(sb.o.log)=='function')
local ue=sb.o.ue
assert(ue and type(ue.pc)=='function' and type(ue.eve)=='function' and type(ue.game_instance)=='function')
assert(type(ue.find_name)=='function' and type(ue.index_of)=='function' and type(ue.rows.read)=='function'
    and type(ue.rows.write)=='function')
-- The hall lobby pak gate's inputs (the Paks folder, files.read) and the hall rows (online/lobby/halls_rows.lua), whose
-- own gate is the SBO lobby's.
assert(sb.o.paks=='mod/StellarCoop|paks' and sb.o.read==require('core.link').files.read
    and type(sb.o.halls.ok)=='function' and type(sb.o.halls.title)=='function')
-- The hall lobby seats' inputs: coop emote (its seat loops, looked up ahead) and SB's chairs, through the engine.
assert(type(sb.o.emote.sit)=='function' and type(sb.o.emote.active)=='function'
    and type(sb.o.emote.preload)=='function' and sb.o.copies==nil)
assert(type(ue.chair_class)=='function' and type(ue.chair)=='function' and type(ue.bound)=='function'
    and type(ue.chairs_of)=='function')
-- chair_class: the class in memory, else its asset loaded and looked up again; neither raises (with LoadAsset's error
-- when it raised). chair: SB's chair
-- spawned deferred in EVE's world, AlwaysSpawn, at the seat's transform, its EnvActorName the row before
-- FinishSpawningActor, then each part hidden with its collision off; a step that raises destroys it and raises.
-- bound: its BindZoneAlias and EnvSpawnAlias, nothing once it is gone.
do
    local function obj(t)
        t.type=function() return 'UObject' end
        t.IsValid=function() return t.alive~=false end
        return t
    end
    local calls,memory,loads={},{},{}
    local class,her,character=obj({}),obj({IsA=function() return true end}),obj({})
    local ZE='/Game/GameDesign/Level/ZoneEnv/'
    local CLASS,ASSET=ZE..'Env_Chair_05.Env_Chair_05_C',ZE..'Env_Chair_05.Env_Chair_05'
    local refuse_name,missing=false,nil
    local function actor()
        local a=obj({K2_DestroyActor=function() calls[#calls+1]='destroy' end})
        for _,name in ipairs({'079_A_SM','BoxCollision'}) do
            if name~=missing then
                a[name]=obj({SetVisibility=function(_,on,children)
                        calls[#calls+1]=string.format('%s visible %s %s',name,tostring(on),tostring(children))
                    end,
                    SetCollisionEnabled=function(_,v) calls[#calls+1]=name..' collision '..v end})
            end
        end
        return setmetatable(a,{__newindex=function(t,k,v)
            if refuse_name and k=='EnvActorName' then error('no property EnvActorName',0) end
            rawset(t,k,v)
        end})
    end
    local gs=obj({BeginDeferredActorSpawnFromClass=function(_,context,c,t,how,owner)
            calls[#calls+1]=string.format('begin %s %s %s %d %s',context==her and 'eve' or '?',c==class and 'class'
                or '?',t.at,how,tostring(owner))
            return actor()
        end,
        FinishSpawningActor=function(_,a,t)
            calls[#calls+1]='finish '..tostring(a.EnvActorName)..' '..t.at
            return a
        end})
    local math_lib=obj({MakeTransform=function(_,l,r,s)
        return {at=string.format('%g,%g,%g/%g,%g,%g/%g,%g,%g',l.X,l.Y,l.Z,r.Pitch,r.Yaw,r.Roll,s.X,s.Y,s.Z)}
    end})
    local find,helpers=StaticFindObject,package.loaded.UEHelpers
    StaticFindObject=function(path)
        if path:find('^/Game/GameDesign/Level/ZoneEnv/Env_Chair') then return memory[path] end
        if path=='/Script/SB.SBCharacter' then return character end
        if path=='/Script/Engine.Default__GameplayStatics' then return gs end
        if path=='/Script/Engine.Default__KismetMathLibrary' then return math_lib end
        return find(path)
    end
    helpers.GetPlayer=function() return her end
    FName=function(text) return 'FName:'..text end
    local loadable,load_error=false,nil
    LoadAsset=function(path)
        loads[#loads+1]=path
        if load_error then error(load_error,0) end
        if loadable and path==ASSET then memory[CLASS]=class end
    end
    local ok,why=pcall(ue.chair_class,ASSET)
    assert(ok==false and why==CLASS..' does not load' and #loads==1,tostring(why))
    loads,load_error={},'LoadAsset: no such package' -- LoadAsset's own error goes into the line.
    ok,why=pcall(ue.chair_class,ASSET)
    assert(ok==false and why==CLASS..' does not load: LoadAsset: no such package' and #loads==1,tostring(why))
    load_error=nil
    loads,loadable={},true
    assert(ue.chair_class(ASSET)==class and #loads==1 and loads[1]==ASSET,#loads) -- Loaded once, then in memory.
    assert(ue.chair_class(ASSET)==class and #loads==1)
    local a=ue.chair(class,'SBO_Hotel_Seat001',{X=-914.54,Y=2317.69,Z=86.2,Yaw=-90},{'079_A_SM','BoxCollision'})
    local T='-914.54,2317.69,86.2/0,-90,0/1,1,1'
    assert(table.concat(calls,'|')=='begin eve class '..T..' 1 nil|finish FName:SBO_Hotel_Seat001 '..T
        ..'|079_A_SM visible false false|079_A_SM collision 0|BoxCollision visible false false'
        ..'|BoxCollision collision 0',
        table.concat(calls,'|'))
    a.BindZoneAlias,a.EnvSpawnAlias='Zone_SBO_Hotel','SBO_Hotel_Seat001'
    local zone,row=ue.bound(a)
    assert(zone=='Zone_SBO_Hotel' and row=='SBO_Hotel_Seat001',tostring(zone))
    a.alive=false
    assert(ue.bound(a)==nil,'Gone')
    calls,missing={},'BoxCollision'
    ok,why=pcall(ue.chair,class,'SBO_Hotel_Seat001',{X=0,Y=0,Z=0,Yaw=0},{'079_A_SM','BoxCollision'})
    assert(ok==false and why=='no component BoxCollision' and calls[#calls]=='destroy',tostring(why))
    calls,missing,refuse_name={},nil,true
    ok,why=pcall(ue.chair,class,'SBO_Hotel_Seat001',{X=0,Y=0,Z=0,Yaw=0},{'079_A_SM'})
    assert(ok==false and why=='no property EnvActorName' and table.concat(calls,'|'):find('^begin [^|]+|destroy$'),
        table.concat(calls,'|'))
    gs.alive,math_lib.alive,character.alive=false,false,false -- Out of U.find's cache for the tests below.
    StaticFindObject,helpers.GetPlayer,FName,LoadAsset=find,nil,nil,nil
end
assert(sb.on_loads==1,'sbo on at load')
-- The words: enter, leave, status, hop and back reach the module; anything else is the usage line, and coop's own
-- usage line leaves coop sbo out.
coop('sbo','enter'); assert(sb.calls[#sb.calls]=='enter' and last()=='[StellarCoop] OK: sb enter\n',last())
coop('sbo','leave'); coop('sbo','status'); coop('sbo','hop'); coop('sbo','back')
coop('sbo','view'); coop('sbo','view','set'); coop('sbo','seq','Xion_10_E_Seq_011')
assert(table.concat(sb.calls,',')=='enter,leave,status,hop,back,view,view set,seq Xion_10_E_Seq_011',
    table.concat(sb.calls,','))
coop('sbo','parts')
assert(lb.calls[#lb.calls]=='parts' and last()=='[StellarCoop] OK: lobby parts: 6 of 6 made (the log has each)\n',
    last())
for _,words in ipairs({{'sbo'},{'sbo','fly'},{'sbo','enter','x'},{'sbo','hop','x'},{'sbo','tick'},{'sbo','view','x'},
        {'sbo','view','set','x'},{'sbo','seq'},{'sbo','seq','a','b'},{'sbo','parts','x'}}) do
    coop(table.unpack(words))
    assert(#sb.calls==8 and last()=='[StellarCoop] STOP: '..USE..'\n',last())
end
assert(not USAGE:find('sbo',1,true))
-- The 250 ms loop ticks it; the title's put-back runs once each time the title shows.
local n=sb.ticks
quarter(); quarter()
assert(sb.ticks==n+2 and sb.titles==0)
at_title=true
quarter(); quarter()
assert(sb.titles==1,'Once a title visit')
at_title=false; quarter(); at_title=true; quarter()
assert(sb.titles==2)
at_title=false
-- The say it got: a dotted key in the menu's words, English for the line above EVE.
sb.o.say('sbo.no.partner')
assert(said_en[#said]==T.en.sbo.no.partner,tostring(said_en[#said]))
sb.o.say('sbo.no.lobby')
assert(said_en[#said]==T.en.sbo.no.lobby and said[#said]==T.en.sbo.no.lobby)
-- The recruiter's Join armed once he stands there.
asked={}
rc_ready()
assert(asked[#asked]=='sbo arm 4242 0',tostring(asked[#asked]))
-- His auto spawn: every 250 ms, solo or in a session, on a co-op save or the player's own.
local OWN=with_slot('slot=main index=0 marker=none\n') -- The player's own save.
for _,case in ipairs({{plain,'none'},{COOP,'none'},{COOP,'host'},{OWN,'guest'}}) do
    status_text,link_mode=case[1],case[2]
    local autos=rc_autos
    quarter()
    assert(rc_autos==autos+1)
end
status_text,link_mode=plain,'none'
-- coop off: its put-back before the native off; then no tick and no auto spawn.
coop('off')
assert(sb.offs==1 and sb.asked_at_off<#asked and asked[#asked]=='off')
n,autos=sb.ticks,rc_autos
quarter()
assert(sb.ticks==n and rc_autos==autos)
-- sbo_lobby=off: no sbo on; every word, hop and status included, says the lobby is off; the title's put-back still
-- runs; the recruiter's Join is not armed.
settings_text='sbo_lobby=off\n'
load_main(true)
assert(sb.on_loads==0 and sb.o.settings.sbo_lobby==false)
for _,word in ipairs({'enter','leave','status','hop','x'}) do
    coop('sbo',word)
    assert(#sb.calls==0 and last()=='[StellarCoop] STOP: '..OFF..'\n',last())
end
at_title=true
quarter()
assert(sb.titles==1,'The put-back whatever the setting')
at_title=false
asked={}
rc_ready()
for _,line in ipairs(asked) do assert(not line:match('^sbo arm'),'No arm with the lobby off: '..line) end
-- The lobby screens (L4-menus-b-c 3.6, design-lobby 2.7, 2.8). Their view: Model.view's input, fresh at each call.
settings_text='sbo_lobby=on\n'
load_main(true)
kit_ready,in_world=true,true
local ME,HER='76561198000000005','76561198000000009'
saves_info.steamid,link_me,link_owner,link_code,link_mode=ME,'Eve',HER,'ABC-1234','guest'
local v=lb.o.view()
assert(v.role=='guest' and v.code=='ABC-1234' and v.me.id==ME and v.me.name=='Eve' and v.owner==HER)
assert(v.version=='v' and v.proto==3 and v.now==clock and v.settings==sb.o.settings and v.last==nil)
assert(type(v.members)=='table' and v.match==nil and lb.o.words().lobby)
link_mode=nil
assert(lb.o.view().role=='none','None before Steam is ready')
link_mode='none'
-- SB's HUD under the screens: off at the first pass after a load, then on and off once each as B, C or the leave
-- question opens and every one closes (the fixture keeps the hud requests in huds).
local function hud() return table.concat(huds,',') end
-- The arrival in the lobby world: B opens and the menu camera takes the view, once; tried again while B cannot open.
lb.refuse='the lobby menu opens in the game world only'
sb.here=true
quarter()
assert(lb.calls[#lb.calls]=='open menu' and sb.to_menus==0,table.concat(lb.calls,','))
assert(hud()=='hud hide off',hud())
lb.refuse=nil
-- Nor while the UI root is a build whose look still warms: the kit builds no new root while B shows, so B would keep
-- the logo and shades missing. B opens with the menu camera at the first pass on the whole look, once.
kit_whole,lb.calls=false,{}
quarter(); quarter()
assert(#lb.calls==0 and lb.screen==nil and sb.to_menus==0,table.concat(lb.calls,','))
kit_whole=nil
-- A hud request that cannot be written: logged once, not at each pass, and asked again until it goes through.
hud_refuse='cannot write coop-request.txt.tmp'
quarter(); quarter()
assert(table.concat(lb.calls,',')=='open menu' and lb.screen=='menu' and sb.to_menus==1,table.concat(lb.calls,','))
assert(hud()=='hud hide off',hud())
local refused=0
for _,line in ipairs(printed) do
    if line=='[StellarCoop] hud: hud hide on not asked: cannot write coop-request.txt.tmp\n' then refused=refused+1 end
end
assert(refused==1,'Logged once: '..refused)
hud_refuse=nil
quarter()
assert(hud()=='hud hide off,hud hide on',hud())
-- Back (act close room): B closed, the view back to EVE, the room's overlay on.
lb.calls={}
lb.o.act({close='room'})
assert(table.concat(lb.calls,',')=='close,room true' and sb.to_rooms==1,table.concat(lb.calls,','))
quarter(); quarter()
assert(hud()=='hud hide off,hud hide on,hud hide off',hud())
-- menu_key in the lobby world opens B with the menu camera; open, it goes back to the room.
key('F5')
assert(lb.screen=='menu' and sb.to_menus==2 and not kit_shown.menu)
key('F5')
assert(lb.screen==nil and sb.to_rooms==2)
-- The mouse with B open: a left click is its click, a right click its back.
key('F5'); lb.calls={}
key('LEFT_MOUSE_BUTTON'); key('RIGHT_MOUSE_BUTTON')
assert(table.concat(lb.calls,',')=='nav click,nav back',table.concat(lb.calls,','))
-- Each frame: the lobby's tick with the clock.
loops[1].f()
assert(lb.ticks[#lb.ticks]==clock and lb.slows>0)
-- The keys. B: A and Q are both left, E nothing; Esc back, Enter select, the arrows theirs.
lb.calls={}
link_uidev=2
key('A'); key('Q'); key('E'); key('ESCAPE'); key('RETURN'); key('UP_ARROW')
assert(table.concat(lb.calls,',')=='nav left,nav left,nav back,nav select,nav up',table.concat(lb.calls,','))
-- C on AZERTY: A is the left tab, Q left, E the right tab; on QWERTY Q is the left tab and A left.
lb.o.act({open='settings'})
assert(lb.screen=='settings')
lb.calls={}
key('A'); key('Q'); key('E')
link_uidev=1
key('Q'); key('A')
assert(table.concat(lb.calls,',')=='nav tab_left,nav left,nav tab_right,nav tab_left,nav left',
    table.concat(lb.calls,','))
-- LB and RB on the pad: C's tabs while C is open, nothing on B.
local function pad(...) for _,e in ipairs({...}) do pd.q[#pd.q+1]=e end; loops[1].f() end
lb.calls={}
pad(8,9)
assert(table.concat(lb.calls,',')=='nav tab_left,nav tab_right',table.concat(lb.calls,','))
lb.screen='menu'; lb.calls={}
pad(8,9,2)
assert(table.concat(lb.calls,',')=='nav down',table.concat(lb.calls,','))
-- menu_key_sits_near_seat_else_opens_b: in the lobby world with no lobby screen open, menu_key and View held 1 s stand
-- EVE up while she sits, sit her on a seat within reach that SB's chairs left to menu_key (online/lobby/sbo.lua's
-- near_seat), else open B. The hint at the bottom centre says Sit, or Stand up while she sits, after the menu key's
-- name; none while B is open.
lb.o.act({close='room'})
local SEAT,to_menus={n=3,kind='bar'},sb.to_menus
sb.seat=SEAT
quarter()
assert(kit_shown.line_hint and kit_views.line_hint.text.s=='F5  '..T.en.sit,kit_views.line_hint.text.s)
key('F5')
assert(sb.sat==SEAT and lb.screen==nil and sb.to_menus==to_menus and last()=='[StellarCoop] OK: sb sit\n',last())
sb.sitting,sb.seat=SEAT,nil
quarter()
assert(kit_shown.line_hint and kit_views.line_hint.text.s=='F5  '..T.en.stand,kit_views.line_hint.text.s)
key('F5')
assert(sb.stands==1 and lb.screen==nil and last()=='[StellarCoop] OK: sb stand\n',last())
pad(7)
assert(sb.stands==2 and lb.screen==nil,'View held 1 s: likewise')
sb.sitting,sb.seat,sb.sat=nil,SEAT,nil
pad(7)
assert(sb.sat==SEAT and lb.screen==nil)
sb.seat=nil
quarter()
assert(not kit_shown.line_hint,'Away from a seat: no hint')
-- A seat read that raises: logged once, no hint, and the rest of the 250 ms pass runs.
sb.seat_error='near_seat: boom'
local slows=lb.slows
quarter()
assert(not kit_shown.line_hint and lb.slows==slows+1,'The pass goes on')
assert(logged('sbo: error (logged once until the mod reloads; the other modules go on): near_seat: boom'),last())
sb.seat_error=nil
key('F5')
assert(lb.screen=='menu' and sb.to_menus==to_menus+1 and sb.stands==2)
sb.seat=SEAT
quarter()
assert(not kit_shown.line_hint,'No hint while B is open')
sb.seat=nil
-- Outside the lobby world menu_key opens the co-op menu as before.
lb.o.act({close='room'})
sb.here=false
quarter()
key('F5')
assert(kit_shown.menu and lb.screen==nil)
key('ESCAPE')
-- What B and C ask for (act).
sb.here=true
quarter()
lb.o.act({popup='leave'})
assert(lb.calls[#lb.calls]=='popup leave' and lb.o.view().last==nil)
lb.ask(false)
assert(#sb.calls==0,'No leaves nothing')
local to_rooms=sb.to_rooms
lb.o.act({popup='leave'}); lb.ask(true)
assert(table.concat(sb.calls,',')=='leave' and sb.to_rooms==to_rooms+1 and lb.screen==nil,
    'Yes: the view back, then the return')
asked={}
lb.o.act({request='match search ffa'})
assert(asked[1]=='match search ffa' and lb.o.view().last=='search')
lb.o.act({request='match create ffa'})
assert(lb.o.view().last=='create')
-- Search names the lobby's room and hall (the SBO lobby's lobby_words()); Private goes to its create() with the map
-- picked on C (private_room_row_cycles: Random until one is picked, the halls shown only with them in use).
lb.o.act({request='match search ffa',lobby=true})
assert(asked[#asked]=='match search ffa hotel 47101_5096' and lb.o.view().last=='search',asked[#asked])
local n_asked=#asked
lb.o.act({request='match create ffa',lobby=true})
assert(sb.created=='match create ffa random' and #asked==n_asked and lb.o.view().last=='create',sb.created)
assert(lb.o.view().room=='random' and lb.o.view().halls==false)
sb.hall='47101_5096'
assert(lb.o.view().halls==true)
local settings_before=settings_text
lb.o.act({set='room',value='station'})
assert(lb.o.view().room=='station' and settings_text==settings_before,'Not a coop-settings.txt setting')
lb.o.act({request='match search ffa',lobby=true})
lb.o.act({request='match create ffa',lobby=true})
assert(sb.created=='match create ffa station' and asked[#asked]=='match search ffa hotel 47101_5096',sb.created)
sb.hall=nil
lb.o.act({request='mute '..HER})
assert(asked[#asked]=='mute '..HER and lb.o.view().last=='create')
lb.o.act({copy=true})
v=lb.o.view()
assert(asked[#asked]=='copy' and v.copied_at==clock and v.now==clock)
lb.o.act({set='chat',value='off'})
assert(settings_text:find('chat=off',1,true),settings_text)
lb.o.act({run='report'})
assert(asked[#asked]=='report')
to_rooms=sb.to_rooms
lb.o.act({open='join'})
assert(lb.screen==nil and kit_said('show code true') and sb.to_rooms==to_rooms+1)
key('ESCAPE')
-- The countdown: fed from the match line each 250 ms, stopped once it ends.
lb.calls={}
link_match={state='countdown',mode='ffa',members=2,limit=8,left=7}
quarter()
assert(lb.calls[#lb.calls]=='count 7 '..clock,table.concat(lb.calls,','))
link_match={state='open',mode='ffa',members=2,limit=8}
quarter()
assert(lb.calls[#lb.calls]=='stop_count')
-- Our round's start line over the leave question (Review Focus 5): the question, C and B closed, the countdown stopped,
-- the view back to EVE (the fence is online/lobby/sbo.lua's, which stops it for a round that lists us), logged once.
key('F5'); lb.o.act({popup='leave'})
to_rooms,lb.calls=sb.to_rooms,{}
link_round={n=1,kind='start',mode='ffa',map='NK_Boss_Scarlet',seed=99,ids={ME,HER}}
quarter(); quarter()
assert(table.concat(lb.calls,',')=='close,stop_count' and lb.ask==nil and lb.screen==nil
    and sb.to_rooms==to_rooms+1,table.concat(lb.calls,','))
assert(logged('round start: stage 4 not built'))
-- A start line without us changes nothing.
link_round={n=2,kind='start',mode='ffa',map='NK_Boss_Scarlet',seed=7,ids={HER}}
key('F5'); lb.calls,to_rooms={},sb.to_rooms
quarter()
assert(#lb.calls==0 and lb.screen=='menu' and sb.to_rooms==to_rooms)
-- The focus watchdog with B open in the lobby world: closed, the view back to EVE, the overlay on, SB's HUD back.
huds={}
kit_lost='lobby'
quarter()
assert(table.concat(lb.calls,',')=='close,room true' and sb.to_rooms==to_rooms+1,table.concat(lb.calls,','))
assert(hud()=='hud hide off',hud())
-- Leaving the lobby world closes the screens and the overlay.
lb.calls={}
sb.here=false
quarter()
assert(table.concat(lb.calls,',')=='close,room false',table.concat(lb.calls,','))
-- The arrival's hold (online/lobby/arrival.lua, whose rules online/lobby/arrival_test tests): sbo gets it;
-- ClientRestart's hook after a lobby warp puts SB's black up at the next pass (LoadingScreenFadeAuto: lifetime 10 s,
-- fade in 0.5 s from 0 to 1, fade out 0.5 s from 1 to 0, tag 5 Load) and veils the kit. Under it the menu camera takes
-- the view once and B waits; once sbo.unready() is empty with the kit's whole look, the native part's loading lift, the
-- veil off and B opens in that pass.
settings_text='sbo_lobby=on\n'
load_main(true)
kit_ready,in_world=true,true
local restart=hooks['/Script/Engine.PlayerController:ClientRestart']
assert(sb.o.arrival and type(restart)=='function')
restart() -- No lobby warp: nothing.
quarter()
assert(#fades.calls==0)
sb.o.arrival.arm()
quarter()
assert(#fades.calls==0,'Not before the new controller')
restart()
asked,huds,kit_calls,lb.calls,sb.unready={},{},{},{},{'arrival'}
quarter()
assert(table.concat(fades.calls,'|')=='10 0.5 0 1 0.5 1 0 5' and kit_said('veil true') and #lb.calls==0,
    table.concat(fades.calls,'|'))
assert(hud()=='','No HUD hide before the arrival: '..hud())
-- SB's HUD hide is asked under the black at the arrival, passes before the lift, so it is in before SB's fade-out.
sb.here,sb.unready,kit_whole=true,{'chairs','camera'},false
quarter()
assert(sb.to_menus==0 and #lb.calls==0,'No camera before the whole look')
assert(hud()=='hud hide on' and #asked==0,hud())
kit_whole=nil
quarter(); quarter()
assert(sb.to_menus==1 and lb.screen==nil and #asked==0,table.concat(lb.calls,','))
sb.unready={}
quarter()
assert(table.concat(asked,',')=='loading lift' and kit_said('veil false') and lb.screen=='menu' and sb.to_menus==2,
    table.concat(asked,','))
assert(table.concat(printed,'|'):find('[StellarCoop][SB] arrival: lifted after 1.0 s (ready)\n',1,true),
    table.concat(printed,'|'))
assert(hud()=='hud hide on','Kept on through the lift: '..hud())
-- A Lua load under an earlier load's hold: its first pass in the lobby world asks the lift, once; none before it
-- (the record still reads warping).
load_main(true)
kit_ready,in_world,asked=true,true,{}
quarter()
assert(#asked==0,table.concat(asked,','))
sb.here=true
quarter(); quarter()
assert(table.concat(asked,',')=='loading lift',table.concat(asked,','))
assert(table.concat(printed,'|'):find(
    '[StellarCoop][SB] arrival: loading lift asked at the first lobby pass of this Lua load\n',1,true),
    table.concat(printed,'|'))
-- The new controller and the record's arrival in the same first lobby pass of a Lua load (a long game-thread block
-- from ClientRestart to the arrival): the black this pass puts up is this load's own, so one fade and no lift.
load_main(true)
kit_ready,in_world=true,true
restart=hooks['/Script/Engine.PlayerController:ClientRestart']
quarter()
sb.o.arrival.arm()
quarter()
restart()
asked,fades.calls,sb.here,sb.unready={},{},true,{'camera'}
quarter()
assert(#asked==0 and table.concat(fades.calls,'|')=='10 0.5 0 1 0.5 1 0 5' and sb.o.arrival.held(),
    table.concat(asked,',')..' / '..table.concat(fades.calls,'|'))
-- Without the hook (an older UE4SS): one line, and no lobby warp holds anything.
RegisterHook=nil
load_main(true)
RegisterHook=function(path,f) hooks[path]=f end
assert(table.concat(printed,'|'):find('arrival: no hold at the lobby arrivals: ClientRestart not hooked: ',1,true))
-- Without the native part: no module, and coop sbo says why.
load_main(false)
assert(sb.o==nil)
coop('sbo','status')
assert(last()=='[StellarCoop] STOP: the Steam link needs the native part\n',last())
io.stdout:write('main_sbo_test ok\n') -- The fixture's print keeps lines for last().
