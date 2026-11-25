-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The module exports main/pass.lua and main/frame.lua call, each under guarded() (main/frame.lua). One that raises is
-- logged once a Lua load under its module's name. The rest of its loop still runs. With fight_asks raising, the
-- 250 ms pass still says the link's notices, starts the ghost, writes the state and runs the kit's slow pass, the focus
-- watchdog and the menu's slow pass. Then each other export the loops call raises in turn: quests_asks, world_asks,
-- scenes_asks, puppet.active, ghost_start, race.armed (in the pass and in the frame), sbo.active (before and after
-- coop off), group.photo, group.cut, booth.near, hud.marking, photo_pause and puppet.rebuild.
dofile('tests/lua/main/fixture.lua')
local Loader=require('main.loader')
local M -- main.lua's state table, as main.lua hands it to the loader.
local run=Loader.run
Loader.run=function(state,list) M=state; return run(state,list) end
load_main(true)
quarter() -- link_mode='none': no session yet, so the ghost waits.
local function errors(name,message) -- How many error lines name has for message, each with its stack traceback.
    local n,start=0,'[StellarCoop] '..name..': error (logged once until the mod reloads; the other modules go on): '
        ..message..'\nstack traceback:\n'
    for _,line in ipairs(printed) do if line:find(start,1,true)==1 then n=n+1 end end
    return n
end
local menus,menu_slow=0,M.menu.slow
M.menu.slow=function(...) menus=menus+1; return menu_slow(...) end
M.fight_asks=function() error('fight_asks boom',0) end
in_world,link_mode,link_notices,kit_lost=true,'host',{'R01 notice'},'menu'
local said_n,states_n,toggles_n,calls_n=#said,#states,toggles,#kit_calls
quarter()
assert(errors('fight','fight_asks boom')==1,'The raise logged under the module name')
local heard=false
for i=said_n+1,#said do heard=heard or said[i]=='R01 notice' end
assert(heard,"The link's notices are said")
assert(toggles==toggles_n+1 and active==true,'The ghost starts with the session')
assert(#states==states_n+1 and states[#states]=='world=1 rate=60','The state is written')
local slowed=false
for i=calls_n+1,#kit_calls do slowed=slowed or kit_calls[i]=='slow true' end
assert(slowed,"The kit's slow pass runs")
assert(logged('focus watchdog: menu lost the focus for 1 s: co-op UI closed, the game has its input back'),
    'The focus watchdog runs')
assert(menus==1,"The menu's slow pass runs")
link_notices=nil
quarter()
assert(errors('fight','fight_asks boom')==1 and menus==2,'Logged once a Lua load; the next pass runs whole too')
-- Each other export raises in two runs of its loop (the pass unless the case names the frame). No error leaves the
-- loop. One line is logged under the module's name. A case's before() sets up the call: a session that starts (the
-- ghost), a new shared mods list (its rebuild), a solid ghost wanted (sbo.active).
local function ghost_session() active,link_mode=false,'none'; quarter(); link_mode='host' end
local function shared_changed() shared_v=(shared_v or 0)+1 end
local function solid() M.settings.collide=true end -- sbo.active is read for a solid ghost only.
local CASES={{M,'quests_asks','quests'},{M,'world_asks','world'},{M,'scenes_asks','scenes'},
    {M.puppet,'active','ghost',ghost_session},{M,'ghost_start','ghost',ghost_session},{M.race,'armed','race'},
    {M.race,'armed','race',nil,loops[1].f},{M.sbo,'active','sbo',solid},{M.group,'photo','revive'},
    {M.group,'cut','revive'},{M.booth,'near','booth'},{M.hud,'marking','hud'},{M,'photo_pause','photo'},
    {M.puppet,'rebuild','ghost',shared_changed}}
for i,c in ipairs(CASES) do
    local t,key,name,before,loop=c[1],c[2],c[3],c[4],c[5] or quarter
    local was,message=t[key],key..' boom '..i
    t[key]=function() error(message,0) end
    for _=1,2 do
        if before then before() end
        local ok,why=pcall(loop)
        assert(ok,key..': the loop raised: '..tostring(why))
    end
    t[key]=was
    assert(errors(name,message)==1,key..': one line under '..name)
end
-- After coop off the pass still writes the state, with the SBO lobby read under guarded() too.
coop('off')
solid()
local was=M.sbo.active
M.sbo.active=function() error('sbo.active off boom',0) end
states_n=#states
quarter(); quarter()
M.sbo.active=was
assert(#states==states_n+2 and errors('sbo','sbo.active off boom')==1,'After coop off: logged once, the state written')
print('pass_test ok')
