-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The New Game+ notice through main.lua (fixture.lua): the guest compares with the host, the host with each member;
-- one notice a member a session, one more on a change; none for the same values, before ours is read, in a match
-- lobby or in the SBO lobby; in the menu's words with its English beside.
dofile('tests/lua/main/fixture.lua')
in_world=true
settings_text,status_text='shared_enemies=off\n',COOP
link_notices={}
load_main(true)
local TAIL=' Enemies with another max HP stay unshared.'
local function c(n,d) return {count=n,difficulty=d} end
local function m(id,name,n,d) return {id=id,name=name,count=n,difficulty=d} end
link_mode='guest'
fake_link.host=function() return {id='1001'} end
assert(cycles_tick(nil,{m('1001','Kaanta',1,2)})=='','Ours unread: nothing yet')            -- Review Focus 5
local got=cycles_tick(c(0,0),{m('1001','Kaanta',1,2),m('2002','Lily',3,0)})
assert(got=='Kaanta is on New Game+ 1 (Hard); you are on your first playthrough (Normal).'..TAIL,got)
assert(cycles_tick(c(0,0),{m('1001','Kaanta',1,2)})=='','Once a session')
got=cycles_tick(c(0,1),{m('1001','Kaanta',1,2)})
assert(got=='Kaanta is on New Game+ 1 (Hard); you are on your first playthrough (Story).'..TAIL,'A change: one more')
assert(cycles_tick(c(1,2),{m('1001','Kaanta',1,2)})=='','The same values: none')
got=cycles_tick(c(0,1),{m('1001','Kaanta',1,2)})
assert(got=='Kaanta is on New Game+ 1 (Hard); you are on your first playthrough (Story).'..TAIL,
    'Back to values that differ: one more')
link_mode='none'; cycles_tick(nil,{})
link_mode='host'
fake_link.host=function() return {id='9'} end
got=cycles_tick(c(2,0),{m('1001','Kaanta',0,0),m('2002','Lily',2,0),m('3003','Rose',2,2)})
assert(got=='Kaanta is on their first playthrough (Normal); you are on New Game+ 2 (Normal).'..TAIL
    ..'|Rose is on New Game+ 2 (Hard); you are on New Game+ 2 (Normal).'..TAIL,got)
link_mode='none'; cycles_tick(nil,{})
link_mode,link_match='host',{state='open'}
assert(cycles_tick(c(0,0),{m('1001','Kaanta',1,2)})=='','Not in a match lobby')
link_match,sb.here=nil,true
assert(cycles_tick(c(0,0),{m('1001','Kaanta',1,2)})=='','Not in the SBO lobby')
sb.here=false
link_mode='none'; cycles_tick(nil,{})
link_mode,kit_language='guest','fr-FR'
fake_link.host=function() return {id='1001'} end
got=cycles_tick(c(0,0),{m('1001','Kaanta',1,2)})
assert(got~='' and said_en[#said_en]=='Kaanta is on New Game+ 1 (Hard); you are on your first playthrough (Normal).'
    ..TAIL,tostring(said_en[#said_en]))
io.stdout:write('cycle_test ok\n')
