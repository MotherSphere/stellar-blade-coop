-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode through main.lua (fixture.lua's fake fight/gunmode/mode.lua; fight/gunmode/hosted_test tests the mode): the
-- mod folder it reads its gun_ lines from, the rounds' store (none without the native part), the menu's words, its
-- notice, its start, the new-controller hook, its restore at the first tick before its tick, coop off's stop and after
-- a Lua reload with coop off still on its restore alone. It has no hud build step: its HUD entry
-- (fight/gunmode/ui/dpad.lua) lives in SB's own HUD, not on the kit.
dofile('tests/lua/main/fixture.lua')
settings_text,status_text,in_world='',plain,true
load_main(true)
assert(gm.o.folder=='mod/StellarCoop',tostring(gm.o.folder))
assert(gm.o.stock==nil,'no round store: free magazines')
assert(gm.starts==1,'wiring starts gun mode once')
assert(gm.hud==nil,'no hud build step')
-- The menu's words for its reticle slot, its notice in them (the rebuilding one by default).
assert(gm.o.words().gun.reload=='RELOADING','gun mode gets the menu words')
gm.o.notice()
assert(said_en[#said_en]=='Gun mode: rebuilding',tostring(said_en[#said_en]))
-- A new controller reaches gun mode through wiring.lua's hook.
local pc={}
news['/Script/SB.SBPlayerController'](pc)
assert(gm.controllers[#gm.controllers]==pc,'the hook passes the controller on')
-- No unknown-setting line for gun mode's test lines: gun mode reads them itself.
settings_text='gun_trace=on\ngun_zoom=toggle\ngun_g1_tag=v4n\ngun_airtrace=off\n'
load_main(true)
assert(not table.concat(printed,'|'):find('unknown setting',1,true),table.concat(printed,'|'))
settings_text=''
load_main(true)
assert(gm.restores==0 and gm.ticks==0)
loops[1].f()
assert(gm.restores==1 and gm.ticks==1)
coop('off')
assert(#gm.stops==1 and gm.stops[1]=='coop off',table.concat(gm.stops,'|'))
loops[1].f()
assert(gm.ticks==1,'No tick after coop off')
-- coop off survives a Lua reload: the first tick still restores what an earlier load left; no tick.
status_text='mod=v proto=3 steam=ready\nlink=none lobby=0\nengine=off reason=coop_off\nlast=#9 coop off\n'
load_main(true)
loops[1].f()
assert(gm.restores==1 and gm.ticks==0)
-- No native part: no rounds' store; gun mode still reads its own lines from the mod folder.
status_text=plain
load_main(false)
assert(gm.o and gm.o.stock==nil)
assert(gm.o.folder=='mod/StellarCoop')
assert(gm.hud==nil,'No native part: no hud build step')
io.stdout:write('main gun_test ok\n')
