-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Sessions screen's model: a tab's rows and status from the native part's list, what Refresh and Select ask for
-- (one search at a time, 5 s apart, none during a match search, Refresh stops our own), the cursor, the region and camp
-- keys and the rules read back.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local M=require('session.ui.sessions_model')
local function view(o)
    o.tab,o.now=o.tab or 'public',o.now or 100
    return M.view(o)
end
local ROWS={{lobby='109775241234567890',owner='76561198000000001',players='1/2',ping=84,pal=false,zone='e04',
        camp='Xion_Camp_01',rules='ebwqr200',name='Ann'},
    {lobby='109775241234567891',owner='76561198000000003',players='1/2',pal=true,name='Bo\7b'},
    {lobby='109775241234567892',owner='76561198000000004',players='1/2',name=''}}

-- No list yet, never asked: idle; Refresh asks for this tab.
local v=view({})
assert(v.status.key=='idle' and #v.rows==0 and not v.busy and v.wait==0)
assert(M.refresh(v)=='list public' and M.refresh(view({tab='friends'}))=='list friends')
-- Asked 2 s ago, no list line yet: wait 3 s; Refresh asks nothing until 5 s have passed.
v=view({asked=98})
assert(v.status.key=='wait' and v.status.args[1]==3 and v.wait==3 and M.refresh(v)==nil)
assert(M.refresh(view({asked=95}))=='list public')
-- A search runs: searching, on either tab; Refresh stops it (ours).
v=view({search={tab='public',state='searching',rows=0},asked=99})
assert(v.status.key=='searching' and v.busy and v.ours and M.refresh(v)=='list stop')
v=view({tab='friends',search={tab='public',state='searching',rows=0},asked=99})
assert(v.status.key=='searching' and #v.rows==0 and M.refresh(v)=='list stop')
-- A match search runs: searching; Refresh asks nothing (Steam runs one search a player).
v=view({match={state='searching',mode='ffa'}})
assert(v.status.key=='searching' and v.busy and not v.ours and M.refresh(v)==nil)
-- Done: this tab's rows as the native part gave them, names cleaned (a control character dropped) and nil when empty;
-- no status while rows show.
v=view({search={tab='public',state='done',rows=3},rows=ROWS,asked=90})
assert(v.status==nil and #v.rows==3 and v.rows[1].name=='Ann' and v.rows[1].ping==84 and v.rows[1].zone=='e04')
assert(v.rows[2].name=='Bob' and v.rows[2].pal and v.rows[2].ping==nil and v.rows[3].name==nil)
assert(M.select(v,1)=='join 109775241234567890' and M.select(v,3)=='join 109775241234567892' and M.select(v,4)==nil)
assert(M.refresh(v)=='list public')
-- The other tab's rows never show there: idle, or wait while under 5 s.
v=view({tab='friends',search={tab='public',state='done',rows=3},rows=ROWS,asked=90})
assert(#v.rows==0 and v.status.key=='idle')
v=view({tab='friends',search={tab='public',state='done',rows=3},rows=ROWS,asked=97})
assert(v.status.key=='wait' and v.status.args[1]==2)
-- Done with none: empty; failed: failed.
assert(view({search={tab='public',state='done',rows=0}}).status.key=='empty')
assert(view({search={tab='public',state='failed',rows=0}}).status.key=='failed')
-- The cursor wraps; 0 with no row.
assert(M.move(3,3,1)==1 and M.move(3,1,-1)==3 and M.move(3,2,1)==3 and M.move(0,0,1)==0)
assert(M.other('public')=='friends' and M.other('friends')=='public')
-- Regions: the story maps' keys, any case; a zone with none, nil.
assert(table.concat(M.region('e04'),',')=='UI_RegionAlias_E04,UI_Map_Region_Xion')
assert(M.region('B07')[1]=='UI_RegionAlias_B07' and M.region('matrix_xi')[1]=='UI_RegionAlias_Matrix11')
assert(M.region('e03_wasteland_p')[2]=='UI_Map_Region_WasteLand' and M.region('f01')==nil and M.region(nil)==nil)
assert(M.camp('WLB10_Camp_01')=='UI_CampAlias_WLB10_Camp_01' and M.camp(nil)==nil)
-- Rules: the ids on in order, the boss HP scale with shared bosses only; any other shape, nil.
local r=M.rules('ebwqr200')
assert(table.concat(r,',')=='shared_enemies,bosses,shared_world,shared_quests,revive' and r.boss==200)
r=M.rules('wq135')
assert(table.concat(r,',')=='shared_world,shared_quests' and r.boss==nil)
assert(#M.rules('100')==0)
for _,bad in ipairs({'x200','ebw','be200','ebwqr999','<b>200',''}) do assert(M.rules(bad)==nil,bad) end
assert(M.rules(nil)==nil)
-- docs/players/interface.md's Sessions screen names every rule the right pane can show, in its English words.
local T=require('ui.text')
local f=assert(io.open('docs/players/interface.md'))
local doc=f:read('a'):match('### Sessions screen(.-)\n### '):gsub('%s+',' '):lower()
f:close()
r=M.rules('ebwsqr200')
assert(#r==6,'Every rule on')
for _,id in ipairs(r) do
    local label=(id=='revive' and T.en.sessions.revive or T.en.row[id]):gsub(' %(.-%)$','')
    assert(doc:find(label:lower(),1,true),'docs/players/interface.md leaves out '..label)
end
print('sessions_model_test ok')
