-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The lobby screens' model: the lobby menu's rows, actions, status and members by state, the mode rows and the score
-- attack's Challenge row, the cursor, the settings rows of both tabs and the countdown's resync.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local M=require('online.lobby.ui.lobby_model')
local function ids(v) local t={} for i,r in ipairs(v.rows) do t[i]=r.id..(r.locked and '*' or '') end return table.concat(t,',') end
local me={id='76561198000000002',name='Eve'}
local idle=M.view({role='none',me=me,now=0})
assert(idle.state=='idle' and ids(idle)=='ffa,scoreattack*,more*,search,private,join_code,room,settings,leave'
    and idle.status.key=='status.idle')
local s=M.view({match={state='searching',mode='ffa'},role='none',me=me,last='search',now=0})
assert(s.state=='public' and ids(s)=='ffa*,scoreattack*,more*,cancel,room,settings,leave'
    and s.status.key=='status.searching')
assert(M.act(s,'cancel').request=='match cancel')
local mem={{id='76561198000000001',linked=true,lost=false,muted=false,rtt=90,name='Ann'},
    {id='76561198000000003',linked=true,lost=false,muted=false,rtt=180,name='Bo'},
    {id='76561198000000004',linked=false,lost=false,muted=false,rtt=0,name='Cy'},
    {id='76561198000000005',linked=true,lost=true,muted=false,rtt=40,name='Di'}}
local o=M.view({match={state='open',mode='ffa',members=5,limit=8},members=mem,role='guest',me=me,
    owner='76561198000000001',last='search',now=0})
assert(o.status.key=='status.open' and o.status.args[1]==5 and o.status.args[2]==8 and M.act(o,'cancel').request=='leave')
assert(o.members[1].you and o.members[1].name=='Eve' and o.members[1].ping==nil and o.members[2].host)
assert(o.members[2].mark=='ok' and o.members[3].mark=='warn' and o.members[4].mark=='warn' and o.members[5].mark=='error')
assert(o.members[1].link=='ok' and o.members[2].link=='ok' and o.members[4].link=='connecting' and o.members[5].link=='lost')
local full=M.view({match={state='open',mode='ffa',members=8,limit=8},members=mem,role='guest',me=me,last='search',now=0})
assert(full.status.key=='status.full')
local cd=M.view({match={state='countdown',mode='ffa',members=3,limit=8,left=7},members=mem,role='guest',me=me,last='search',now=0})
assert(cd.status.key=='status.start' and cd.status.args[1]==7 and cd.left==7)
local play=M.view({match={state='playing',mode='ffa',members=3,limit=8},members=mem,role='guest',me=me,last='search',now=0})
assert(play.status.key=='status.open' and play.status.args[1]==3)
local made=M.view({match={state='open',mode='ffa',members=1,limit=8},role='host',me=me,last='search',now=0})
assert(made.status.key=='status.created')
local code=M.view({match={state='open',mode='ffa',members=2,limit=8},role='host',code='ABC-1234',me=me,last='create',now=0})
assert(ids(code)=='ffa*,scoreattack*,more*,code,cancel,room,settings,leave' and code.status.key=='status.private'
    and M.act(code,'code').copy)
local joined=M.view({match={state='open',mode='ffa',members=2,limit=8},role='guest',me=me,last='join',now=0})
assert(ids(joined)=='ffa*,scoreattack*,more*,cancel,room,settings,leave')
-- An online session: its member count over its host's max_players (limit), over 4 (the most) while it is not known.
local coop=M.view({role='guest',me=me,now=0})
assert(coop.state=='code' and coop.status.key=='status.private' and coop.status.args[1]==1 and coop.status.args[2]==4)
coop=M.view({role='guest',me=me,limit=2,now=0})
assert(coop.status.args[2]==2,'A guest: the host\'s max_players')
coop=M.view({role='host',me=me,limit=3,members={{id='5',linked=true,lost=false,muted=false,rtt=20,name='P'}},now=0})
assert(coop.status.args[1]==2 and coop.status.args[2]==3)
local long=M.view({match={state='open',mode='ffa',members=2,limit=8},members={{id='76561198000000009',linked=true,
    lost=false,muted=false,rtt=20,name='ABCDEFGHIJKLMNOPQRSTUVWXYZ\226\128\174'}},role='guest',me=me,last='search',now=0})
assert(long.members[2].name=='ABCDEFGHIJKLMNOP...')                      -- cut at 16, the bidi override cleaned
local copied=M.view({match={state='open',mode='ffa',members=2,limit=8},role='host',code='ABC-1234',me=me,last='create',copied_at=10,now=12.9})
assert(copied.status.key=='status.copied')
assert(M.act(idle,'search').request=='match search ffa' and M.act(idle,'private').request=='match create ffa')
-- Search and Private name the lobby's room and hall too (main.lua adds them); Cancel does not.
assert(M.act(idle,'search').lobby and M.act(idle,'private').lobby and not M.act(s,'cancel').lobby)
assert(M.act(idle,'join_code').open=='join' and M.act(idle,'room').close=='room' and M.act(idle,'settings').open=='settings')
assert(M.act(idle,'leave').popup=='leave' and M.act(idle,'more')==nil and M.act(s,'ffa')==nil)
assert(M.move(idle.rows,1,1)==2 and M.move(idle.rows,9,1)==1 and M.move(idle.rows,1,-1)==9)
-- Score attack (online.modes.scoreattack): picked by default while it can play (sa); a mode row's Select picks its
-- mode and marks it; Search and Private ask for the mode picked. Without sa (module off or scoreattack=off) its row is
-- locked and free-for-all is the mode, a pick of score attack too.
local sa_idle=M.view({role='none',me=me,now=0,sa={pick='random'}})
assert(ids(sa_idle)=='ffa,scoreattack,more*,search,private,join_code,room,settings,leave'
    and sa_idle.mode=='scoreattack')
assert(sa_idle.rows[2].picked and not sa_idle.rows[1].picked and not sa_idle.rows[3].picked)
assert(M.act(sa_idle,'search').request=='match search scoreattack' and M.act(sa_idle,'search').lobby)
assert(M.act(sa_idle,'private').request=='match create scoreattack' and M.act(sa_idle,'private').lobby)
assert(M.act(sa_idle,'ffa').mode=='ffa' and M.act(sa_idle,'scoreattack').mode=='scoreattack')
local ffa_pick=M.view({role='none',me=me,now=0,sa={pick='random'},pick='ffa'})
assert(ffa_pick.mode=='ffa' and ffa_pick.rows[1].picked and not ffa_pick.rows[2].picked)
assert(M.act(ffa_pick,'search').request=='match search ffa')
assert(idle.mode=='ffa' and idle.rows[1].picked and M.act(idle,'scoreattack')==nil,'No sa: locked, free-for-all')
assert(M.view({role='none',me=me,now=0,pick='scoreattack'}).mode=='ffa','A pick that cannot play')
assert(s.mode=='ffa' and s.rows[1].picked and M.act(s,'scoreattack')==nil,'A lobby keeps its mode')
-- In a score attack match lobby: its row locked and marked, then Challenge with the host's pick, which Select cycles
-- (online.modes.scoreattack's cycle); a guest's Challenge is locked and reads the host's pick; without sa it is locked.
local function sa_lobby(role,sa)
    return M.view({match={state='open',mode='scoreattack',members=2,limit=8},role=role,me=me,last='search',now=0,sa=sa})
end
local sa_host=sa_lobby('host',{pick='targets'})
assert(ids(sa_host)=='scoreattack*,challenge,more*,cancel,room,settings,leave' and sa_host.mode=='scoreattack')
assert(sa_host.rows[1].picked and sa_host.rows[2].value=='targets' and M.act(sa_host,'challenge').cycle)
local sa_guest=sa_lobby('guest',{pick='random'})
assert(ids(sa_guest)=='scoreattack*,challenge*,more*,cancel,room,settings,leave' and sa_guest.rows[2].value=='host')
assert(M.act(sa_guest,'challenge')==nil)
local sa_off=sa_lobby('host',nil)
assert(ids(sa_off)=='scoreattack*,challenge*,more*,cancel,room,settings,leave' and sa_off.rows[2].value=='random')
local c=M.count(nil,10,0)
assert(c.total==10 and c.start==0)
assert(M.count(c,8,2.5)==c)                       -- shown 7.5, off by 0.5
local r=M.count(c,5,3)                             -- shown 7, off by 2: restart
assert(r.total==5 and r.start==3)

-- After a Lua reload (last nil), a match lobby is ours by code when we hold a code, else public.
local lost_last={match={state='open',mode='ffa',members=2,limit=8},role='host',me=me,now=0}
assert(M.view(lost_last).state=='public')
lost_last.code='ABC-1234'
assert(M.view(lost_last).state=='code')
-- Before Steam is ready (role nil): idle.
assert(M.view({me=me,now=0}).state=='idle')
-- A member with an empty Steam name: '' (Join.name gives nil); our own row with none: nil, the you tag alone.
local blank=M.view({match={state='open',mode='ffa',members=2,limit=8},members={{id='76561198000000009',linked=true,
    lost=false,muted=false,rtt=20,name=''}},role='guest',me={id=me.id},last='search',now=0})
assert(blank.members[2].name=='' and blank.members[1].name==nil and blank.members[1].you)
-- The code row carries the code; tones (my call 11).
assert(code.rows[4].args[1]=='ABC-1234' and not code.rows[4].locked)
assert(idle.status.tone=='grey' and made.status.tone=='grey' and s.status.tone=='warn' and o.status.tone=='teal'
    and code.status.tone=='teal' and cd.status.tone=='teal' and copied.status.tone=='teal')
-- The copied word lasts 3 s.
assert(M.view({match={state='open',mode='ffa',members=2,limit=8},role='host',code='ABC-1234',me=me,last='create',
    copied_at=10,now=13}).status.key=='status.private')

-- Screen C. Tab match: 2 headers, 10 items, all locked.
local function keys(rows)
    local t={}
    for i,row in ipairs(rows) do t[i]=row.head and 'head:'..row.head or row.id end
    return table.concat(t,',')
end
local function find(rows,id) for _,row in ipairs(rows) do if row.id==id then return row end end end
local in_o={match={state='open',mode='ffa',members=5,limit=8},members=mem,role='guest',me=me,owner=mem[1].id,
    last='search',version='0.9.0',proto=20,now=0}
local match_rows=M.settings(M.view(in_o),'match',in_o)
assert(#match_rows==12 and keys(match_rows)
    =='head:ffa,players,finish,tie,respawn,protection,difficulty,equipment,start,head:lobby,lobby,version')
for _,row in ipairs(match_rows) do assert(row.head or row.locked,row.id) end
assert(find(match_rows,'players').value=='val.players' and find(match_rows,'lobby').value=='val.public')
local v=find(match_rows,'version')
assert(v.value=='val.version' and v.args[1]=='0.9.0' and v.args[2]==20)
local made_o={match={state='open',mode='ffa',members=2,limit=8},role='host',code='ABC-1234',me=me,last='create',now=0}
local lobby_row=find(M.settings(M.view(made_o),'match',made_o),'lobby')
assert(lobby_row.value=='val.private' and lobby_row.args[1]=='ABC-1234')
local idle_o={role='none',me=me,now=0}
assert(find(M.settings(M.view(idle_o),'match',idle_o),'lobby').value=='val.public')
local joined_o={match={state='open',mode='ffa',members=2,limit=8},role='guest',me=me,last='join',now=0}
lobby_row=find(M.settings(M.view(joined_o),'match',joined_o),'lobby')
assert(lobby_row.value=='val.private' and lobby_row.args[1]=='-') -- A guest by code holds no code.
-- private_room_row_cycles: idle with the hall lobbies in use (halls), the map of a Private match after the Lobby row:
-- Random, then the halls in online/lobby/sbo_maps.lua's order; Random until the host picks one; a hall shows its name.
-- No such row in a lobby or without the halls.
local halls_o={role='none',me=me,now=0,halls=true}
local halls_rows=M.settings(M.view(halls_o),'match',halls_o)
assert(keys(halls_rows)
    =='head:ffa,players,finish,tie,respawn,protection,difficulty,equipment,start,head:lobby,lobby,room,version',
    keys(halls_rows))
local room_row=find(halls_rows,'room')
assert(not room_row.locked and room_row.value=='random' and room_row.shown=='val.random'
    and table.concat(room_row.values,',')=='random,hotel,station,cloister,terrace,foyer')
halls_o.room='station'
room_row=find(M.settings(M.view(halls_o),'match',halls_o),'room')
assert(room_row.value=='station' and room_row.shown=='Station',room_row.shown)
assert(not find(M.settings(M.view(idle_o),'match',idle_o),'room'))
made_o.halls=true
assert(not find(M.settings(M.view(made_o),'match',made_o),'room'))
-- Tab match of a score attack lobby: its rules, the challenge as the Challenge row reads it (the host's pick, or the
-- host's for a guest); idle with score attack picked, its rules with our pick.
local sa_o={match={state='open',mode='scoreattack',members=2,limit=8},role='host',me=me,last='search',now=0,
    sa={pick='range'},version='0.9.0',proto=24}
local sa_rows=M.settings(M.view(sa_o),'match',sa_o)
assert(keys(sa_rows)=='head:scoreattack,players,challenge,ranking,damage,equipment,start,head:lobby,lobby,version',
    keys(sa_rows))
for _,row in ipairs(sa_rows) do assert(row.head or row.locked,row.id) end
assert(find(sa_rows,'challenge').pick=='range' and find(sa_rows,'ranking').value=='val.ranking')
assert(find(sa_rows,'damage').value=='val.damage')
sa_o.role='guest'
assert(find(M.settings(M.view(sa_o),'match',sa_o),'challenge').pick=='host')
local sa_idle_o={role='none',me=me,now=0,sa={pick='swarm'}}
local sa_idle_rows=M.settings(M.view(sa_idle_o),'match',sa_idle_o)
assert(sa_idle_rows[1].head=='scoreattack' and find(sa_idle_rows,'challenge').pick=='swarm')
-- Tab sbo: chat, one mute row per other member, the display rows and the bug report.
mem[2].muted=true
in_o.members={mem[1],mem[2],mem[3],mem[4],{id=me.id,linked=true,lost=false,muted=false,rtt=0,name='Eve'}}
in_o.settings={chat=false,ui_language='english',ui_sounds=true}
local sbo=M.settings(M.view(in_o),'sbo',in_o)
assert(keys(sbo)=='head:chat,chat,mute,mute,mute,mute,head:display,ui_language,ui_sounds,head:help,report',keys(sbo))
assert(sbo[2].value=='off' and sbo[8].value=='english' and sbo[9].value=='on' and sbo[11].action=='report')
assert(sbo[3].value=='off' and sbo[3].action=='mute 76561198000000001' and sbo[3].name=='Ann')
assert(sbo[4].value=='on' and sbo[4].action=='unmute 76561198000000003')
for _,row in ipairs(sbo) do assert(not row.locked) end
-- No settings read yet: the file's defaults.
in_o.settings=nil
sbo=M.settings(M.view(in_o),'sbo',in_o)
assert(sbo[2].value=='on' and sbo[8].value=='game' and sbo[9].value=='on')
print('lobby_model_test ok')
