-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop world (the shared world, experimental) through main.lua (fixture.lua): its arguments, on and off whatever
-- shared_world says, status, its start once a load with shared_world=on, its end at a reload with shared_world=off, and
-- its notices on screen in the menu's words.
dofile('tests/lua/main/fixture.lua')
in_world=true
local Q=fake_link
local USE='[StellarCoop] STOP: Use: coop world on | off | status\n'
settings_text,status_text='shared_world=off\nshared_enemies=off\n',COOP
load_main(true)
assert(logged('shared world: off (experimental)'),table.concat(printed,'|'))
loops[2].f(); assert(#asked==0,'Never with shared_world=off')
-- Strict arguments: anything else is its usage line and asks nothing.
for _,bad in ipairs({{},{'start'},{'ON'},{'on','x'},{'off','now'},{'status','1'},{'probe'}}) do
    coop('world',table.unpack(bad))
    assert(last()==USE and #asked==0,table.concat(bad,' ')..': '..last())
end
-- on and off go to the native part whatever shared_world says (until the mod reloads); the loop does not undo them.
coop('world','on')
assert(asked[1]=='world on' and last()=='[StellarCoop] OK: asked the native part: world on\n',last())
coop('world','off')
assert(asked[2]=='world off' and last()=='[StellarCoop] OK: asked the native part: world off\n',last())
loops[2].f(); assert(#asked==2,'The loop leaves them alone')
-- status asks the native part, whose answer follows in the log, and answers with the world= line.
Q.Q.world='world=waiting why=partner sent=0 skipped=0'
coop('world','status')
assert(asked[3]=='world status' and last()=='[StellarCoop] OK: world=waiting why=partner sent=0 skipped=0\n',last())
Q.Q.world=nil
coop('world','status')
assert(last()=='[StellarCoop] OK: no shared world status yet\n',last())
-- shared_world=on asks on once a load as soon as the native part judged the slot (coop, main, or none at the title),
-- not before; coop world off before then cancels it.
settings_text,status_text='shared_world=on\nshared_enemies=off\n',plain
load_main(true)
assert(logged('shared world: on (experimental)'),table.concat(printed,'|'))
loops[2].f(); assert(#asked==0,'No save judged yet: it waits')
status_text=with_slot('slot=none index=? marker=none\n')
loops[2].f()
assert(#asked==1 and asked[1]=='world on' and logged('OK: shared_world=on: asked the native part: world on'),
    table.concat(asked,'|'))
loops[2].f(); status_text=COOP; loops[2].f(); assert(#asked==1,'Once a load')
load_main(true)
status_text=plain; coop('world','off'); status_text=COOP; loops[2].f()
assert(#asked==1 and asked[1]=='world off','Only the off')
-- shared_world=off at a reload (Ctrl+R) ends a coop world on an earlier load asked, waiting or running, from the
-- world= line at a line start only.
for _,case in ipairs({{'world=on sent=0\n',true},{'world=waiting why=friend sent=0\n',true},{'world=off sent=0\n',false},
        {'world=off why=build\n',false},{'world=stopped\n',false},{'peer=2 name=world=on x\n',false}}) do
    settings_text,status_text='shared_world=off\nshared_enemies=off\n',with_slot(case[1])
    load_main(true)
    assert(#asked==(case[2] and 1 or 0) and (not case[2] or asked[1]=='world off'),case[1])
    assert(not case[2] or logged('OK: shared_world=off: asked the native part: world off'),table.concat(printed,'|'))
end
-- The notices, every 250 ms: on with her each time both sides come on, and stopped for the run, each once as it starts,
-- in the menu's words.
settings_text,status_text,fight_text,pilot_text,paks_v='shared_enemies=off\n',COOP,nil,nil,nil
load_main(true)
local function step(line)
    Q.Q.world=line
    local n,out=#said,{}
    loops[2].f()
    for i=n+1,#said do
        if said[i]~='Kaanta joined.' and said[i]~='Kaanta: connection lost.' then out[#out+1]=said[i] end
    end
    return table.concat(out,'|')
end
for _,case in ipairs({{nil,''},{'world=stopped',''},{'world=off sent=0',''},{'world=waiting why=friend sent=0',''},
        {'world=waiting why=partner sent=0',''},{'world=on sent=0','Shared world on with Kaanta.'},{'world=on sent=4',''},
        {'world=waiting why=partner sent=4',''},{'world=on sent=4','Shared world on with Kaanta.'},
        {'world=stopped','Shared world stopped until the game restarts. coop-link.log says why.'},
        {'world=stopped',''}}) do
    local got=step(case[1])
    assert(got==case[2],tostring(case[1])..': '..got)
end
kit_language='fr-FR'
assert(step('world=off sent=0')=='' and step('world=on sent=0')=='Monde partagé actif avec Kaanta.')
kit_language=nil
io.stdout:write('world_test ok\n')
