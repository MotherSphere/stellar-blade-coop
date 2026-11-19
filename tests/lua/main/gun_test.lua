-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode through main.lua (fixture.lua's fake fight/gunmode/mode.lua; fight/gunmode/stop_test tests the mode): its
-- coop-gun.txt through the link's store (none without the native part), the photo mode as the runtime reads it, its
-- restore at the first tick before its tick, coop off's stop and after a Lua reload with coop off still on its restore
-- alone.
dofile('tests/lua/main/fixture.lua')
settings_text,status_text,in_world='',plain,true
load_main(true)
assert(gm.o.store=='store coop-gun.txt',tostring(gm.o.store))
-- The photo mode as the runtime reads it: no rifle in the photo or selfie mode.
assert(gm.o.photo()=='0')
photo_mode=true; assert(gm.o.photo()=='1')
selfie_mode=true; assert(gm.o.photo()=='s')
photo_mode,selfie_mode=false,false
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
-- No native part: no coop-gun.txt.
status_text=plain
load_main(false)
assert(gm.o and gm.o.store==nil)
io.stdout:write('main gun_test ok\n')
