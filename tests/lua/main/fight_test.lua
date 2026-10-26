-- coop fight (the shared enemies, experimental) through main.lua (fixture.lua): its arguments, the co-op slot, and its
-- settings as words of its requests (fight_chars, guest_kills, kill_credit, the host's scaling, same_place, aggro,
-- same_spawns, enemy_extra, spawn_filter, bosses and boss_hp_scale); its start once a load with shared_enemies=on; the
-- reload asks of shared_enemies=off and same_place=off; coop fight pilot (same-place enemies) and coop fight spawn
-- probe; the shared enemies' on, off and stopped notices; and the notice when her .pak mods differ from ours.
dofile('tests/lua/main/fixture.lua')
in_world=true -- In a world, as the settings tests left it when all of this was one file.
-- coop fight (Phase 11, experimental). Strict arguments: anything else is the fight's usage line and asks nothing.
local FIGHT_USE='[StellarCoop] STOP: Use: coop fight on | off | status | probe | test hp|sh|st <change> | test kill | '
    ..'record | replay | pilot status|probe|on|off | pilot test freeze|cmc|drive|replay|target|exec | '
    ..'pilot test bstart|phase|finish|summon | spawn probe\n'
local FIGHT_STOP='[StellarCoop] STOP: coop fight runs only on a co-op save (INSTALL.md: Co-op saves); now '
settings_text='shared_enemies=off\n'
load_main(true)
status_text=COOP
for _,bad in ipairs({{},{'start'},{'ON'},{'on','x'},{'off','now'},{'status','x'},{'probe','1'},{'record','x'},
        {'replay','x'},{'test'},{'test','kill','x'},{'test','hp'},{'test','hp','0'},{'test','hp','-0'},
        {'test','hp','+0'},{'test','hp','1.5'},{'test','hp','10000001'},{'test','hp','-10000001'},{'test','hp','x'},
        {'test','hp','--1'},{'test','hp',' 5'},{'test','hp','5 '},{'test','hp','0x10'},{'test','hp','1e3'},
        {'test','hpx','5'},{'test','HP','5'},{'test','kill','1'},{'test','hp','-10','x'},{'test','sh','1','x','y'},
        {'test','st','1','2'},{'test','hp','-9223372036854775808'}}) do -- math.abs keeps the last one negative.
    coop('fight',table.unpack(bad))
    assert(last()==FIGHT_USE and #asked==0,table.concat(bad,' ')..': '..last())
end
-- shared_enemies=off: coop fight on refuses; the T11a tools still run. fight_chars=auto (the default)
-- asks them with no ids: the native part then takes every common enemy. record, a mode that hosts, carries the host's
-- scaling (1.35 and 1.15 by default) in whole percents. A test's change goes as a plain whole number; a test never
-- carries fight_chars.
coop('fight','on')
assert(last()=='[StellarCoop] STOP: shared enemies are off in coop-settings.txt (shared_enemies=off)\n' and #asked==0)
for _,mode in ipairs({'probe','record','replay'}) do
    coop('fight',mode)
    local line='fight '..mode..(mode=='record' and ' scale 135 115' or '')
    assert(asked[#asked]==line and last()=='[StellarCoop] OK: asked the native part: '..line..'\n',last())
end
for _,case in ipairs({{{'hp','-10'},'fight test hp -10'},{{'hp','+5'},'fight test hp 5'},
        {{'sh','-1'},'fight test sh -1'},{{'st','10000000'},'fight test st 10000000'},
        {{'st','-007'},'fight test st -7'},{{'kill'},'fight test kill'}}) do
    coop('fight','test',table.unpack(case[1])); assert(asked[#asked]==case[2],asked[#asked])
end
-- status asks the native part (its stats line) and answers with the fight= line, the way coop-status.txt has it.
local before_status=#asked
fight_text='fight=on mode=probe actors=12 eve=1 turn=40 turns_per_s=60 writes=armed sim_us=8/30 threads=1/1/2'
coop('fight','status')
assert(asked[#asked]=='fight status' and last()=='[StellarCoop] OK: '..fight_text..'\n',last())
fight_text=nil
coop('fight','status'); assert(last()=='[StellarCoop] OK: no shared fight status yet\n' and #asked==before_status+2)
-- Off the co-op slot the solo tools say the slot line and ask nothing (D2, N9); off and status run.
for _,case in ipairs({{with_slot('slot=main index=0 marker=4\n'),'slot=main index=0 marker=4'},
        {with_slot('slot=none index=4 marker=4\n'),'slot=none index=4 marker=4'},
        {with_slot('slot=unknown index=? marker=4\n'),'slot=unknown index=? marker=4'},
        {with_slot(''),'no slot status'},
        {with_slot('friend=1 0 slot=coop index=4 marker=4\n'),'no slot status'}}) do -- Not at a line start.
    status_text=case[1]
    local before=#asked
    for _,args in ipairs({{'probe'},{'record'},{'replay'},{'test','kill'},{'test','hp','-1'}}) do
        coop('fight',table.unpack(args)); assert(last()==FIGHT_STOP..case[2]..'\n' and #asked==before,last())
    end
    coop('fight','off')
    assert(asked[#asked]=='fight off' and last()=='[StellarCoop] OK: asked the native part: fight off\n',last())
    coop('fight','status'); assert(asked[#asked]=='fight status')
end
status_text=with_slot('slot=coop index=2 marker=none saves=coop\n')
coop('fight','probe'); assert(asked[#asked]=='fight probe','The co-op saves pass too')
-- coop fight pilot (same-place enemies, stages 3a to 3c), on any slot: status asks the native part (which logs its
-- stats lines at once) and answers with the pilot= line; probe, on, off and test (target, exec and the boss tests
-- too) go as typed.
-- on needs same_place=on, as on needs shared_enemies=on.
status_text=with_slot('slot=main index=0 marker=4\n')
for _,bad in ipairs({{'pilot'},{'pilot','start'},{'pilot','status','x'},{'pilot','probe','1'},{'pilot','off','now'},
        {'pilot','on','x'},{'pilot','test'},{'pilot','test','Freeze'},{'pilot','test','freeze','x'},
        {'pilot','tests','drive'},{'pilot','test','kill'},{'pilot','test','hp','5'},{'pilot','Probe'},
        {'pilot','test','exec','1'},{'pilot','test','Exec'},{'pilot','test','bstart','1'},{'pilot','test','Summon'},
        {'pilot','bstart'},{'test','phase'}}) do
    local before=#asked
    coop('fight',table.unpack(bad))
    assert(last()==FIGHT_USE and #asked==before,table.concat(bad,' ')..': '..last())
end
for _,case in ipairs({{{'probe'},'fight pilot probe'},{{'off'},'fight pilot off'},
        {{'test','freeze'},'fight pilot test freeze'},{{'test','cmc'},'fight pilot test cmc'},
        {{'test','drive'},'fight pilot test drive'},{{'test','replay'},'fight pilot test replay'},
        {{'test','target'},'fight pilot test target'},{{'test','exec'},'fight pilot test exec'},
        {{'test','bstart'},'fight pilot test bstart'},{{'test','phase'},'fight pilot test phase'},
        {{'test','finish'},'fight pilot test finish'},{{'test','summon'},'fight pilot test summon'}}) do
    coop('fight','pilot',table.unpack(case[1]))
    assert(asked[#asked]==case[2] and last()=='[StellarCoop] OK: asked the native part: '..case[2]..'\n',last())
end
local before_pilot=#asked
coop('fight','pilot','on')
assert(#asked==before_pilot and last()=='[StellarCoop] STOP: same place is off in coop-settings.txt (same_place=off)\n',
    last())
pilot_text='pilot=on piloted=3 owned=1 drawn=2 probe=on'
coop('fight','pilot','status')
assert(asked[#asked]=='fight pilot status'
    and last()=='[StellarCoop] OK: pilot=on piloted=3 owned=1 drawn=2 probe=on\n',last())
pilot_text=nil
coop('fight','pilot','status')
assert(asked[#asked]=='fight pilot status' and last()=='[StellarCoop] OK: no same-place status yet\n',last())
-- coop fight spawn probe (same spawns, stage 4): the probe with "spawns", on a co-op save only, as the probe; anything
-- else is the usage line. Its status is the fight= line's spawns= (coop fight status).
for _,bad in ipairs({{'spawn'},{'spawn','status'},{'spawn','Probe'},{'spawn','probe','x'},{'spawns','probe'},
        {'spawn','on'}}) do
    local before=#asked
    coop('fight',table.unpack(bad))
    assert(last()==FIGHT_USE and #asked==before,table.concat(bad,' ')..': '..last())
end
do
    local before_spawn=#asked
    coop('fight','spawn','probe')
    assert(#asked==before_spawn and last()==FIGHT_STOP..'slot=main index=0 marker=4\n',last())
end
status_text=with_slot('slot=coop index=2 marker=none saves=coop\n')
coop('fight','spawn','probe')
assert(asked[#asked]=='fight probe spawns' and last()=='[StellarCoop] OK: asked the native part: fight probe spawns\n',
    last())
-- shared_enemies=on with fight_chars: every mode but test carries them. coop fight on runs on any save: the native
-- part waits for a co-op save, and says what it waits for. It starts by itself once a load, as soon as the native part
-- judged the slot (coop, main, or none at the title), not before (no slot line, unknown), never again.
settings_text='shared_enemies=on\nfight_chars=15011001 2\n'
status_text=plain
load_main(true)
assert(logged('shared enemies: on (experimental), fight_chars 15011001 2, same place off (experimental), same spawns '
    ..'off (experimental), extra enemies 0, bosses off (experimental), boss HP 200 %, spawn filter off (experimental)'),
    table.concat(printed,'|'))
for _,waiting in ipairs({plain,with_slot('slot=unknown index=? marker=4\n'),
        with_slot('friend=1 0 slot=coop index=4 marker=4\n')}) do
    status_text=waiting; loops[2].f(); assert(#asked==0,'No save judged yet: it waits')
end
for _,judged in ipairs({COOP,with_slot('slot=main index=0 marker=4\n'),with_slot('slot=none index=4 marker=4\n')}) do
    load_main(true)
    status_text=judged
    loops[2].f()
    assert(#asked==1 and asked[1]=='fight on scale 135 115 15011001 2'
        and logged('OK: shared_enemies=on: asked the native part: fight on scale 135 115 15011001 2'),
        table.concat(printed,'|'))
    loops[2].f(); status_text=with_slot('slot=none index=4 marker=4\n'); loops[2].f(); status_text=COOP; loops[2].f()
    assert(#asked==1,'Once a load: a reload of the save asks nothing (the native part waits and resumes)')
end
for _,mode in ipairs({'on','probe','record','replay'}) do
    coop('fight',mode)
    assert(asked[#asked]=='fight '..mode..((mode=='on' or mode=='record') and ' scale 135 115' or '')..' 15011001 2',
        asked[#asked])
end
coop('fight','test','kill'); assert(asked[#asked]=='fight test kill')
status_text=with_slot('slot=main index=0 marker=4\n')
coop('fight','on')
assert(asked[#asked]=='fight on scale 135 115 15011001 2','By hand on your own save: the native part waits')
-- guest_kills=confirmed and kill_credit=fought go with the modes that kill on the other side's word (on, replay), as
-- one word each before the ids, in that order; the others never carry them. The host's scaling goes with the modes
-- that host (on, record), after them: each 1.0 to 4.0 setting as whole percents, rounded.
settings_text='shared_enemies=on\nguest_kills=confirmed\nkill_credit=fought\nenemy_hp_scale=2\nenemy_balance_scale=1\n'
load_main(true)
status_text=COOP
for _,case in ipairs({{'on','fight on confirmed fought scale 200 100'},{'replay','fight replay confirmed fought'},
        {'probe','fight probe'},{'record','fight record scale 200 100'}}) do
    coop('fight',case[1]); assert(asked[#asked]==case[2],asked[#asked])
end
settings_text='shared_enemies=on\nkill_credit=FOUGHT\nenemy_hp_scale=1.234\nenemy_balance_scale=1.006\n'
load_main(true)
status_text=COOP
coop('fight','on'); assert(asked[#asked]=='fight on fought scale 123 101',asked[#asked])
-- same_place=on goes with the modes that can host (on, record) as "place" after the scaling, before the ids; the
-- guest takes the host's, so replay and probe never carry it. coop fight pilot on then runs.
settings_text='shared_enemies=on\nsame_place=on\nfight_chars=15011001 2\n'
load_main(true)
assert(logged('shared enemies: on (experimental), fight_chars 15011001 2, same place on (experimental), same spawns '
    ..'off (experimental), extra enemies 0, bosses off (experimental), boss HP 200 %, spawn filter off (experimental)'),
    table.concat(printed,'|'))
status_text=COOP
loops[2].f()
assert(#asked==1 and asked[1]=='fight on scale 135 115 place 15011001 2',asked[1])
for _,case in ipairs({{'record','fight record scale 135 115 place 15011001 2'},{'replay','fight replay 15011001 2'},
        {'probe','fight probe 15011001 2'}}) do
    coop('fight',case[1]); assert(asked[#asked]==case[2],asked[#asked])
end
coop('fight','pilot','on'); assert(asked[#asked]=='fight pilot on')
-- aggro=host (the host's: enemies fight the host only) goes the same way as "aggro-host" after place, or alone.
settings_text='shared_enemies=on\nsame_place=on\naggro=host\n'
load_main(true)
status_text=COOP
for _,case in ipairs({{'on','fight on scale 135 115 place aggro-host'},{'record','fight record scale 135 115 place '
        ..'aggro-host'},{'replay','fight replay'},{'probe','fight probe'}}) do
    coop('fight',case[1]); assert(asked[#asked]==case[2],asked[#asked])
end
settings_text='shared_enemies=on\naggro=HOST\n'
load_main(true)
status_text=COOP
coop('fight','on'); assert(asked[#asked]=='fight on scale 135 115 aggro-host',asked[#asked])
-- same_spawns=on (the host's) goes with on only, as "spawns" after aggro-host, before the ids: the other modes have no
-- guest to answer.
settings_text='shared_enemies=on\nsame_place=on\naggro=host\nsame_spawns=on\nfight_chars=15011001\n'
load_main(true)
status_text=COOP
assert(logged('shared enemies: on (experimental), fight_chars 15011001, same place on (experimental), same spawns on '
    ..'(experimental), extra enemies 0, bosses off (experimental), boss HP 200 %, spawn filter off (experimental)'),table.concat(printed,'|'))
for _,case in ipairs({{'on','fight on scale 135 115 place aggro-host spawns 15011001'},{'record','fight record scale '
        ..'135 115 place aggro-host 15011001'},{'replay','fight replay 15011001'},{'probe','fight probe 15011001'}}) do
    coop('fight',case[1]); assert(asked[#asked]==case[2],asked[#asked])
end
-- coop fight spawn probe: the probe with "spawns" before the ids, whatever same_spawns says.
coop('fight','spawn','probe'); assert(asked[#asked]=='fight probe spawns 15011001',asked[#asked])
settings_text='shared_enemies=on\nsame_spawns=on\n'
load_main(true)
status_text=COOP
coop('fight','on'); assert(asked[#asked]=='fight on scale 135 115 spawns',asked[#asked])
-- enemy_extra (the host's) goes with spawns only, as "extra" and its number after it; 0 or same_spawns=off: none.
settings_text='shared_enemies=on\nsame_spawns=on\nenemy_extra=2\nfight_chars=15011001\n'
load_main(true)
status_text=COOP
assert(logged('shared enemies: on (experimental), fight_chars 15011001, same place off (experimental), same spawns on '
    ..'(experimental), extra enemies 2, bosses off (experimental), boss HP 200 %, spawn filter off (experimental)'),table.concat(printed,'|'))
for _,case in ipairs({{'on','fight on scale 135 115 spawns extra 2 15011001'},{'record','fight record scale 135 115 '
        ..'15011001'},{'replay','fight replay 15011001'},{'probe','fight probe 15011001'}}) do
    coop('fight',case[1]); assert(asked[#asked]==case[2],asked[#asked])
end
-- spawn_filter=on (the guest's own) goes with on and the spawn probe as "filter", after spawns and extra, before the
-- ids, whatever same_spawns says (the host's decides); record, replay and the plain probe never carry it.
settings_text='shared_enemies=on\nsame_spawns=on\nenemy_extra=2\nspawn_filter=on\nfight_chars=15011001\n'
load_main(true)
status_text=COOP
assert(logged('shared enemies: on (experimental), fight_chars 15011001, same place off (experimental), same spawns on '
    ..'(experimental), extra enemies 2, bosses off (experimental), boss HP 200 %, spawn filter on (experimental)'),
    table.concat(printed,'|'))
for _,case in ipairs({{'on','fight on scale 135 115 spawns extra 2 filter 15011001'},{'record','fight record scale 135 '
        ..'115 15011001'},{'replay','fight replay 15011001'},{'probe','fight probe 15011001'}}) do
    coop('fight',case[1]); assert(asked[#asked]==case[2],asked[#asked])
end
coop('fight','spawn','probe'); assert(asked[#asked]=='fight probe spawns filter 15011001',asked[#asked])
settings_text='shared_enemies=on\nspawn_filter=ON\n'
load_main(true)
status_text=COOP
coop('fight','on'); assert(asked[#asked]=='fight on scale 135 115 filter',asked[#asked])
coop('fight','spawn','probe'); assert(asked[#asked]=='fight probe spawns filter',asked[#asked])
for _,text in ipairs({'shared_enemies=on\nenemy_extra=3\n','shared_enemies=on\nsame_spawns=on\nenemy_extra=0\n'}) do
    settings_text=text
    load_main(true)
    status_text=COOP
    coop('fight','on'); assert(not asked[#asked]:find('extra',1,true) and not asked[#asked]:find('filter',1,true),
        asked[#asked])
end
-- bosses=on (the host's) goes with on and record as "bosses" and boss_hp_scale in whole percents, after aggro-host,
-- before spawns and the ids; the guest takes the host's, so replay and probe never carry it. Off: none, whatever
-- boss_hp_scale says.
settings_text='shared_enemies=on\naggro=host\nbosses=on\nboss_hp_scale=2.5\nsame_spawns=on\nfight_chars=15011001\n'
load_main(true)
status_text=COOP
assert(logged('shared enemies: on (experimental), fight_chars 15011001, same place off (experimental), same spawns on '
    ..'(experimental), extra enemies 0, bosses on (experimental), boss HP 250 %, spawn filter off (experimental)'),table.concat(printed,'|'))
for _,case in ipairs({{'on','fight on scale 135 115 aggro-host bosses 250 spawns 15011001'},{'record','fight record '
        ..'scale 135 115 aggro-host bosses 250 15011001'},{'replay','fight replay 15011001'},
        {'probe','fight probe 15011001'}}) do
    coop('fight',case[1]); assert(asked[#asked]==case[2],asked[#asked])
end
settings_text='shared_enemies=on\nbosses=on\n'
load_main(true)
status_text=COOP
coop('fight','on'); assert(asked[#asked]=='fight on scale 135 115 bosses 200',asked[#asked])
settings_text='shared_enemies=on\nboss_hp_scale=3\n'
load_main(true)
status_text=COOP
coop('fight','on'); assert(asked[#asked]=='fight on scale 135 115',asked[#asked])
settings_text='shared_enemies=on\nfight_chars=15011001 2\n'
-- coop fight off cancels the start to come; coop off too.
load_main(true)
status_text=plain; coop('fight','off'); status_text=COOP; loops[2].f()
assert(#asked==1 and asked[1]=='fight off','Only the off')
load_main(true)
coop('off'); loops[2].f()
assert(#asked==2 and asked[1]=='devinfo off' and asked[2]=='off','The developer panels closed, then nothing after coop off')
-- shared_enemies=on (the default, as in an empty file) with fight_chars=auto, or empty as in a file written before
-- auto: asked with no ids.
for _,text in ipairs({'','shared_enemies=on\n','shared_enemies=on\nfight_chars=auto\n',
        'shared_enemies=on\nfight_chars=\n'}) do
    settings_text=text
    load_main(true)
    assert(logged('shared enemies: on (experimental), fight_chars auto, same place off (experimental), same spawns '
        ..'off (experimental), extra enemies 0, bosses off (experimental), boss HP 200 %, spawn filter off (experimental)'),
        table.concat(printed,'|'))
    status_text=COOP; loops[2].f()
    assert(#asked==1 and asked[1]=='fight on scale 135 115',text)
end
-- And never with shared_enemies=off.
settings_text='shared_enemies=off\n'
load_main(true)
loops[2].f(); assert(#asked==0)
-- shared_enemies=off at a reload (Ctrl+R) ends a coop fight on an earlier load started, waiting or running, from the
-- fight= line at a line start only; a probe, record or replay goes on, and nothing is asked after coop off. (With
-- same_place=on: same_place=off has its own reload ask, below.)
settings_text='shared_enemies=off\nsame_place=on\n'
local ON_LINE='fight=on mode=on role=host enemies=3 claims=0 refused=0 kills=0 floored=0 sim_us=9/20 threads=1/1/2\n'
for _,case in ipairs({{with_slot(ON_LINE),true},{with_slot('fight=waiting mode=on why=no friend linked\n'),true},
        {with_slot('fight=waiting mode=on her=off why=not on a co-op save\n'),true},
        {with_slot('fight=on mode=record role=host enemies=1 claims=0 refused=0 kills=0 floored=0 sim_us=9/20 '
            ..'threads=1/1/2\n'),false},
        {with_slot('fight=on mode=probe actors=12 eve=1 turn=40 turns_per_s=60 writes=armed sim_us=8/30 '
            ..'threads=1/1/2\n'),false},
        {with_slot('fight=waiting mode=replay why=no save loaded\n'),false},
        {with_slot('fight=off why=coop fight off\n'),false},{with_slot('fight=stopped why=fault\n'),false},
        {with_slot('peer=2 name=x '..ON_LINE),false},
        {'mod=v proto=3 steam=ready\nlink=none lobby=0\nengine=off reason=coop_off\n'..ON_LINE,false}}) do
    status_text=case[1]
    load_main(true)
    assert(#asked==(case[2] and 1 or 0) and (not case[2] or asked[1]=='fight off'),case[1])
    assert(not case[2] or logged('OK: shared_enemies=off: asked the native part: fight off'),table.concat(printed,'|'))
end
settings_text='shared_enemies=on\nfight_chars=15011001 2\n'
status_text=with_slot(ON_LINE)
load_main(true); assert(#asked==0,'shared_enemies=on leaves it running')
settings_text=''
-- same_place=off (the default) at a reload asks coop fight pilot off on the side that hosts, running or waiting: coop
-- fight on while the link hosts, or record. Never as guest or unlinked for on, never for a probe or replay, nor after
-- coop off; same_place=on leaves it.
local function hosted(line) return (with_slot(line):gsub('\nlink=none lobby=0\n','\nlink=host lobby=7\n')) end
for _,case in ipairs({{hosted(ON_LINE),true},{hosted('fight=waiting mode=on her=off why=not on a co-op save\n'),true},
        {with_slot('fight=on mode=record role=host enemies=1 claims=0 refused=0 kills=0 floored=0 sim_us=9/20 '
            ..'threads=1/1/2\n'),true},
        {with_slot('fight=waiting mode=record why=no save loaded\n'),true},
        {with_slot('fight=waiting mode=on why=no friend linked\n'),false},
        {(with_slot('fight=on mode=on role=guest pairs=2 claims=0 corrections=0 kills=0 floored=0\n')
            :gsub('link=none lobby=0','link=guest lobby=7')),false},
        {hosted('fight=on mode=probe actors=12 eve=1 turn=40 turns_per_s=60 writes=armed sim_us=8/30 threads=1/1/2\n'),
            false},
        {hosted('fight=waiting mode=replay why=no save loaded\n'),false},
        {hosted('fight=off why=coop fight off\n'),false},{hosted('peer=2 name=x '..ON_LINE),false},
        {'mod=v proto=3 steam=ready\nlink=host lobby=7\nengine=off reason=coop_off\n'..ON_LINE,false}}) do
    status_text=case[1]
    load_main(true)
    assert(#asked==(case[2] and 1 or 0) and (not case[2] or asked[1]=='fight pilot off'),case[1])
    assert(not case[2] or logged('OK: same_place=off: asked the native part: fight pilot off'),
        table.concat(printed,'|'))
end
settings_text='same_place=on\n'
status_text=hosted(ON_LINE)
load_main(true); assert(#asked==0,'same_place=on leaves it running')
settings_text=''
-- The notices, every 250 ms from the fight= line: on when its enemies go from none to some (one enemy, or several);
-- off once it ran or waited, in any mode, but not when our own player ended it (coop fight off, coop off); a latch
-- says so; nothing for a start with no enemy yet, a pause, a resume, the same line again, or a status that was not
-- read; nothing per frame.
for _,step in ipairs({
        {nil,''},{'fight=off',''},{'fight=off why=coop fight off',''},
        {'fight=waiting mode=on why=no friend linked',''},
        {'fight=on mode=on role=host enemies=0 claims=0 refused=0 kills=0 floored=0 sim_us=0/0 threads=0/0/0',''},
        {'fight=on mode=on role=host enemies=0 claims=0 refused=0 kills=0 floored=0 sim_us=0/0 threads=0/0/0',''},
        {'fight=on mode=on role=host enemies=3 claims=0 refused=0 kills=0 floored=0 sim_us=9/20 threads=1/1/2',
            'Shared enemies on: 3 enemies linked.'},
        {'fight=on mode=on role=host enemies=2 claims=4 refused=0 kills=1 floored=0 sim_us=9/20 threads=1/1/2',''},
        {'fight=on mode=on role=host enemies=0 claims=4 refused=0 kills=3 floored=0 sim_us=9/20 threads=1/1/2',''},
        {'fight=on mode=on role=guest pairs=1 claims=0 corrections=0 kills=0 floored=0 desync=0 sim_us=5/9 '
            ..'threads=1/1/2','Shared enemies on: 1 enemy linked.'},
        {'fight=waiting mode=on why=no save loaded',''},
        {'fight=on mode=on role=guest pairs=0 claims=0 corrections=0 kills=0 floored=0 desync=0 sim_us=5/9 '
            ..'threads=1/1/2',''},
        {nil,''},
        {'fight=off why=coop off',''},
        {'fight=on mode=probe actors=12 eve=1 turn=40 turns_per_s=60 writes=armed sim_us=8/30 threads=1/1/2',''},
        {'fight=off why=coop fight off',''},
        {'fight=waiting mode=on why=no friend linked',''},
        {'fight=off why=the game build is not the pinned one','Shared enemies off. coop-link.log says why.'},
        {'fight=on mode=record role=host enemies=0 claims=0 refused=0 kills=0 floored=0 sim_us=9/20 threads=1/1/2',''},
        {'fight=off why=the recording is full (4 MB or 20000 lines)','Shared enemies off. coop-link.log says why.'},
        {'fight=on mode=replay role=guest pairs=2 claims=0 corrections=1 kills=0 floored=0 desync=0 sim_us=5/9 '
            ..'threads=1/1/2',''},
        {'fight=on mode=on role=host enemies=2 claims=0 refused=0 kills=0 floored=0 sim_us=9/20 threads=1/1/2',
            'Shared enemies on: 2 enemies linked.'},
        {'fight=stopped why=fault','Shared enemies stopped until the game restarts. coop-link.log says why.'},
        {'fight=stopped why=fault',''}}) do
    local got=fight_step(step[1])
    assert(got==step[2],tostring(step[1])..': '..got)
end
-- With the host's scaling (the line's scale=, which the guest has from the host's scale line), the on notice names it;
-- 100 % and 100 % add nothing.
for _,step in ipairs({{'fight=off why=coop fight off',''},
        {'fight=on mode=on role=guest pairs=2 claims=0 corrections=0 kills=0 floored=0 desync=0 scale=135/115 '
            ..'sim_us=5/9 threads=1/1/2',"Shared enemies on: 2 enemies linked. Enemy HP 135 %, balance 115 % (the "
            .."host's setting)."},
        {'fight=off why=coop fight off',''},
        {'fight=on mode=on role=host enemies=1 claims=0 refused=0 kills=0 floored=0 scale=100/100 sim_us=9/20 '
            ..'threads=1/1/2','Shared enemies on: 1 enemy linked.'}}) do
    local got=fight_step(step[1])
    assert(got==step[2],tostring(step[1])..': '..got)
end
-- Her .pak mods against ours: one notice when they differ, until the session ends (no link); the same say nothing.
local PAKS='Kaanta loads other .pak mods than you (1 there, 2 here). Enemies that differ stay unshared.'
link_mode='host'
assert(paks_tick(nil)=='' and paks_tick({same=true,ours=2,hers=2})=='')
assert(paks_tick({same=false,ours=2,hers=1})==PAKS and paks_tick({same=false,ours=2,hers=1})=='')
link_mode='none'
assert(paks_tick(nil)=='')
link_mode,kit_language='guest','fr-FR'
assert(paks_tick({same=false,ours=0,hers=3})=="Kaanta n'a pas les mêmes mods .pak que vous (3 en face, 0 ici). Les "
    ..'ennemis qui diffèrent ne sont pas partagés.')
link_mode,kit_language='none',nil
paks_tick(nil)
-- Her mods by name (protocol 13, link.mods()): once a session, a notice for the mods she uses and we lack, then one for
-- those we have in another version, each with the file names (no folders) of the first two that fit the feed's 200
-- bytes and (+n) for the others, which counts the names the native line left out too. With neither (only ours she
-- lacks), or without names (her mod_names=off), the two counts as above. In French too, with its English beside.
local function list(n,...) return {n=n,names={...}} end
local NONE,DIFFER=list(0),{same=false,ours=2,hers=4}
local MISSING=" uses mods you don't have: %s. Parts of their outfit from them look different here."
local OTHER=' uses other versions of mods you have: %s. Parts of their outfit from them may look different here.'
link_mode='host'
assert(mods_tick(DIFFER,{missing=list(3,'~mods/a_p','logicmods/b/b_p'),
    other=list(1,'logicmods/hd-atool_p/hd-atool_p'),extra=NONE})
    ==('Kaanta'..MISSING:format('a_p, b_p (+1)')..'|Kaanta'..OTHER:format('hd-atool_p')))
assert(mods_tick(DIFFER,{missing=list(1,'~mods/a_p'),other=NONE,extra=NONE})=='','Once a session')
link_mode='none'; assert(mods_tick(nil,nil)=='')
link_mode='guest'
assert(mods_tick(DIFFER,{missing=list(1,'~mods/a_p'),other=NONE,extra=list(2,'~mods/x','~mods/y')})
    =='Kaanta'..MISSING:format('a_p'))
link_mode='none'; mods_tick(nil,nil); link_mode='host'
assert(mods_tick(DIFFER,{missing=NONE,other=list(4,'~mods/a','~mods/b','~mods/c','~mods/d'),extra=NONE})
    =='Kaanta'..OTHER:format('a, b (+2)'))
link_mode='none'; mods_tick(nil,nil); link_mode='host'
assert(mods_tick({same=false,ours=2,hers=1},{missing=NONE,other=NONE,extra=list(1,'~mods/x')})==PAKS,'Ours only')
link_mode='none'; mods_tick(nil,nil); link_mode='host'
assert(mods_tick({same=false,ours=2,hers=1},nil)==PAKS,'No names')
link_mode='none'; mods_tick(nil,nil); link_mode='host'
assert(mods_tick({same=true,ours=2,hers=2},{missing=list(1,'a'),other=NONE,extra=NONE})=='','The same hash: nothing')
-- Long names: only those that fit the 200 bytes, else the count alone (a 64-byte name leaves no room for a 100-byte
-- mod name).
local long=('a'):rep(100)
link_mode='none'; mods_tick(nil,nil); link_mode='host'
local said_long=mods_tick(DIFFER,{missing=list(3,'~mods/'..long,'~mods/'..long..'b'),other=NONE,extra=NONE})
assert(said_long=='Kaanta'..MISSING:format(long..' (+2)') and #said_long<=200,said_long)
friend_name=('W'):rep(64)
link_mode='none'; mods_tick(nil,nil); link_mode='host'
said_long=mods_tick(DIFFER,{missing=list(3,'~mods/'..long),other=NONE,extra=NONE})
assert(said_long==friend_name..MISSING:format('(+3)') and #said_long<=200,said_long)
friend_name='Kaanta'
link_mode,kit_language='none','fr-FR'; mods_tick(nil,nil); link_mode='guest'
assert(mods_tick(DIFFER,{missing=list(2,'~mods/a_p','~mods/b_p'),other=NONE,extra=NONE})
    =="Kaanta utilise des mods que vous n'avez pas : a_p, b_p. Les parties de sa tenue qui en viennent s'affichent "
        ..'autrement ici.')
local at=#said
while not said[at]:find('mods',1,true) do at=at-1 end -- Before the fake link's own notices.
assert(said_en[at]=='Kaanta'..MISSING:format('a_p, b_p'),tostring(said_en[at]))
link_mode,kit_language='none',nil
mods_tick(nil,nil)
-- Our CNS packs (link.cns(), in words): in the log once a Lua load, and in coop status before the ghost's part.
cns_v='CNS detected (9 packs, 242 outfits)'
loops[2].f(); loops[2].f()
local _,cns_logs=table.concat(printed,'|'):gsub('%[StellarCoop%] CNS detected %(9 packs, 242 outfits%)\n','')
assert(cns_logs==1,cns_logs)
coop('status'); assert(last():find(' | CNS detected (9 packs, 242 outfits) | ghost=',1,true),last())
cns_v=nil
coop('status'); assert(not last():find('CNS',1,true),last())
-- mod_names reaches the state each pass (on by default; settings_test.lua has it off).
assert(state_names[#state_names]==true)
io.stdout:write('fight_test ok\n')
