-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop scenes (story together, experimental) through main.lua (fixture.lua): its arguments, on and off whatever
-- shared_story says, status and the ask once a load where the story= line and shared_story differ. Then its notices
-- on screen in the menu's words.
dofile('tests/lua/main/fixture.lua')
in_world=true
local Q=fake_link
local USE='[StellarCoop] STOP: Use: coop scenes on | off | status\n'
-- The native part starts with it on: shared_story=off asks coop scenes off once a load, as soon as the native part
-- judged the slot.
settings_text,status_text='shared_story=off\nshared_enemies=off\n',COOP
load_main(true)
assert(logged('story together: off (experimental)'),table.concat(printed,'|'))
-- Strict arguments: anything else is its usage line, asks nothing and leaves the load's ask alone.
for _,bad in ipairs({{},{'start'},{'ON'},{'on','x'},{'off','now'},{'status','1'},{'probe'}}) do
    coop('scenes',table.unpack(bad))
    assert(last()==USE and #asked==0,table.concat(bad,' ')..': '..last())
end
loops[2].f()
assert(#asked==1 and asked[1]=='scenes off' and logged('OK: shared_story=off: asked the native part: scenes off'),
    table.concat(asked,'|'))
loops[2].f(); assert(#asked==1,'Once a load')
-- on and off go to the native part whatever shared_story says (until the mod reloads); the loop does not undo them.
coop('scenes','on')
assert(asked[2]=='scenes on' and last()=='[StellarCoop] OK: asked the native part: scenes on\n',last())
coop('scenes','off')
assert(asked[3]=='scenes off' and last()=='[StellarCoop] OK: asked the native part: scenes off\n',last())
loops[2].f(); assert(#asked==3,'The loop leaves them alone')
-- status asks the native part (whose answer follows in the log) and answers with the story= line.
Q.Q.story='story=waiting why=partner scene=none sent=0'
coop('scenes','status')
assert(asked[4]=='scenes status' and last()=='[StellarCoop] OK: story=waiting why=partner scene=none sent=0\n',last())
Q.Q.story=nil
coop('scenes','status')
assert(last()=='[StellarCoop] OK: no story together status yet\n',last())
-- The load's ask waits for the judged slot (coop, main, or none at the title); coop scenes on before then cancels it.
settings_text,status_text='shared_story=off\nshared_enemies=off\n',plain
load_main(true)
assert(logged('story together: off (experimental)'),table.concat(printed,'|'))
loops[2].f(); assert(#asked==0,'No save judged yet: it waits')
coop('scenes','on'); status_text=with_slot('slot=none index=? marker=none\n'); loops[2].f()
assert(#asked==1 and asked[1]=='scenes on','Only the on')
-- At each load the story= line decides: nothing while it agrees with shared_story, an ask where it does not; nothing
-- off the pinned build or after coop off, where the native part refuses any ask.
for _,case in ipairs({{'on',nil,nil},{'on','story=on scene=none sent=0',nil},
        {'on','story=waiting why=friend scene=none sent=0',nil},{'on','story=off scene=none sent=0','scenes on'},
        {'on','story=off why=build',nil},{'on','story=stopped',nil},{'off',nil,'scenes off'},
        {'off','story=on scene=shared sent=4','scenes off'},{'off','story=off scene=none sent=0',nil},
        {'off','story=off why=coop_off',nil},{'off','story=stopped','scenes off'}}) do
    settings_text,status_text='shared_story='..case[1]..'\nshared_enemies=off\n',COOP
    load_main(true)
    Q.Q.story=case[2]
    loops[2].f(); loops[2].f()
    assert(#asked==(case[3] and 1 or 0) and asked[1]==case[3],case[1]..' '..tostring(case[2])..': '
        ..table.concat(asked,'|'))
    assert(not case[3] or logged('OK: shared_story='..case[1]..': asked the native part: '..case[3]),
        table.concat(printed,'|'))
end
-- The notices, every 250 ms: on with her each time both sides come on; stopped for the run. Each comes once as it
-- starts, in the menu's words.
settings_text,status_text,fight_text,pilot_text,paks_v='shared_enemies=off\n',COOP,nil,nil,nil
load_main(true)
local function step(line)
    Q.Q.story=line
    local n,out=#said,{}
    loops[2].f()
    for i=n+1,#said do
        if said[i]~='Kaanta joined.' and said[i]~='Kaanta: connection lost.' then out[#out+1]=said[i] end
    end
    return table.concat(out,'|')
end
for _,case in ipairs({{nil,''},{'story=stopped',''},{'story=off scene=none sent=0',''},
        {'story=waiting why=friend scene=none',''},{'story=waiting why=partner scene=none',''},
        {'story=on scene=none sent=0','Story together on with Kaanta.'},{'story=on scene=shared sent=4',''},
        {'story=waiting why=partner scene=none sent=4',''},
        {'story=on scene=none sent=4','Story together on with Kaanta.'},
        {'story=stopped','Story together stopped until the game restarts. coop-link.log says why.'},
        {'story=stopped',''}}) do
    local got=step(case[1])
    assert(got==case[2],tostring(case[1])..': '..got)
end
kit_language='fr-FR'
assert(step('story=off scene=none sent=0')==''
    and step('story=on scene=none sent=0')=='Histoire partagée active avec Kaanta.')
kit_language=nil
io.stdout:write('scenes_test ok\n')
