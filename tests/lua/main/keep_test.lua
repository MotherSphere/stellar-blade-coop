-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The keep (core/keep.lua; core/keep_test tests it) through main.lua: set up once the link exists, coop-keep.txt
-- written through link.write_file by the 250 ms pass, which runs it after coop off too, so the status line's
-- reason=coop_off turns it off and a talk asked then never waits for good.
dofile('tests/lua/main/fixture.lua')
local Keep=require('core.keep')
local PATH='/Game/T/Kept.Kept'
Keep.reset()
settings_text,status_text,in_world='',plain,true
load_main(true)
Keep.want({PATH})
status_text='mod=v proto=3 steam=ready\nengine=on keep=0 0 0\nlink=none lobby=0\nlast=#1 ready\n'
quarter()
assert((link_files['coop-keep.txt'] or ''):find(PATH..'\n',1,true),'The pass wrote coop-keep.txt')
assert(Keep.wanted(PATH) and not Keep.ready(),'Waits for the native part')
coop('off')
status_text='mod=v proto=3 steam=ready\nengine=off reason=coop_off\nlink=none lobby=0\nlast=#1 ready\n'
quarter()
assert(Keep.ready() and not Keep.wanted(PATH),'Off after coop off')
assert(logged('keep: off for this Lua load (the native part is off: coop_off); assets load as before'))
Keep.reset()
io.stdout:write('main keep_test ok\n')
