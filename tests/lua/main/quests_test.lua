-- coop quests (the shared quests, experimental) through main.lua (fixture.lua): its arguments, the co-op slot and its
-- settings, quest_deny carried, force asked of the native part only when typed twice, its start once a load with
-- shared_quests=on, its end at a reload with shared_quests=off, and its notices on screen in the menu's words.
dofile('tests/lua/main/fixture.lua')
-- coop quests (the shared quests, experimental). Strict arguments: anything else is its usage line and asks nothing.
do
local Q=fake_link
local USE='[StellarCoop] STOP: Use: coop quests on | off | status | probe | record | replay | force <quest number>\n'
settings_text,status_text='shared_quests=off\nshared_enemies=off\n',COOP
load_main(true)
assert(logged('shared quests: off (experimental)'),table.concat(printed,'|'))
for _,bad in ipairs({{},{'start'},{'ON'},{'on','x'},{'off','now'},{'status','1'},{'probe','x'},{'force'},
        {'force','0'},{'force','65536'},{'force','x'},{'force','-1'},{'force','5','6'},{'force',' 5'},
        {'record','1'},{'replay','off'}}) do
    coop('quests',table.unpack(bad))
    assert(last()==USE and #asked==0,table.concat(bad,' ')..': '..last())
end
-- shared_quests=off: on refuses; probe, record and replay run on a co-op save; off and status on any.
coop('quests','on')
assert(last()=='[StellarCoop] STOP: shared quests are off in coop-settings.txt (shared_quests=off)\n' and #asked==0)
for _,sub in ipairs({'probe','record','replay','off'}) do
    coop('quests',sub)
    assert(asked[#asked]=='quests '..sub and last()=='[StellarCoop] OK: asked the native part: quests '..sub..'\n',
        last())
end
-- status asks the native part, whose whole answer follows in the log, and answers with the quests= line.
Q.Q.line='quests=on mode=probe role=probe'
coop('quests','status')
assert(asked[#asked]=='quests status' and last()=='[StellarCoop] OK: quests=on mode=probe role=probe (the whole '
    ..'status follows in this log as quests_status lines)\n',last())
Q.Q.line=nil
coop('quests','status')
assert(last():find('OK: no shared quests status yet',1,true),last())
-- Off a co-op save the solo tools say the slot line and ask nothing; off and status still go.
status_text=with_slot('slot=main index=0 marker=4\n')
local before=#asked
for _,sub in ipairs({'probe','record','replay'}) do
    coop('quests',sub)
    assert(#asked==before and last()=='[StellarCoop] STOP: coop quests runs only on a co-op save (INSTALL.md: Co-op '
        ..'saves); now slot=main index=0 marker=4\n',last())
end
coop('quests','off'); assert(asked[#asked]=='quests off')
-- force <number>: asked of the native part only when typed twice for the same quest within 10 s; the first says what
-- it does, its trophies included. On any save: the native part refuses it off the guest's side.
local FORCE='[StellarCoop] STOP: coop quests force 54 makes the step that quest 54 holds for your own kill, or for a '
    .."place the host's game could not read, where you stand now; the game may then unlock that quest's trophies: "
    ..'type it again within 10 s to go on\n'
before=#asked
coop('quests','force','54'); assert(#asked==before and last()==FORCE,last())
clock=clock+11
coop('quests','force','54'); assert(#asked==before and last()==FORCE,'Over 10 s: asked again')
coop('quests','force','55'); assert(#asked==before,'Another quest: asked again')
clock=clock+5
coop('quests','force','55')
assert(asked[#asked]=='quests force 55' and last()=='[StellarCoop] OK: asked the native part: quests force 55\n')
coop('quests','force','55'); assert(#asked==before+1,'Each force asks again')
-- quest_deny goes with on, probe and record, never with replay; shared_quests=on asks on once a load as soon as the
-- native part judged the slot (coop, main, or none at the title), not before; coop quests off before then cancels it.
settings_text='shared_quests=on\nquest_deny=Quest_Sub_016, 54\nshared_enemies=off\n'
status_text=plain
load_main(true)
assert(logged('shared quests: on (experimental), quest_deny Quest_Sub_016, 54'),table.concat(printed,'|'))
loops[2].f(); assert(#asked==0,'No save judged yet: it waits')
status_text=with_slot('slot=main index=0 marker=4\n')
loops[2].f()
assert(#asked==1 and asked[1]=='quests on deny Quest_Sub_016, 54'
    and logged('OK: shared_quests=on: asked the native part: quests on deny Quest_Sub_016, 54'),table.concat(asked,'|'))
loops[2].f(); status_text=COOP; loops[2].f(); assert(#asked==1,'Once a load')
for _,sub in ipairs({'probe','record','replay'}) do
    coop('quests',sub); assert(asked[#asked]=='quests '..sub..(sub~='replay' and ' deny Quest_Sub_016, 54' or ''))
end
load_main(true)
status_text=plain; coop('quests','off'); status_text=COOP; loops[2].f()
assert(#asked==1 and asked[1]=='quests off','Only the off')
settings_text='shared_quests=off\nshared_enemies=off\n'
load_main(true)
loops[2].f(); assert(#asked==0,'Never with shared_quests=off')
-- shared_quests=off at a reload (Ctrl+R) ends a coop quests on an earlier load asked, waiting or running, from the
-- quests= line at a line start only; a probe, record or replay goes on.
for _,case in ipairs({{'quests=on mode=on role=host partner=on\n',true},{'quests=waiting mode=on why=friend\n',true},
        {'quests=on mode=record role=recorder\n',false},{'quests=waiting mode=replay why=save\n',false},
        {'quests=off\n',false},{'quests=stopped\n',false},{'peer=2 name=x quests=on mode=on role=host\n',false}}) do
    status_text=with_slot(case[1])
    load_main(true)
    assert(#asked==(case[2] and 1 or 0) and (not case[2] or asked[1]=='quests off'),case[1])
    assert(not case[2] or logged('OK: shared_quests=off: asked the native part: quests off'),table.concat(printed,'|'))
end
-- The notices, every 250 ms: on with her each time both sides come on, her side off, a wait for a co-op save (coop
-- quests on, a friend linked) and stopped for the run, each once as it starts; each note once, in the menu's words.
-- A Request not on her board yet and a step no zone can place say nothing.
settings_text,status_text,fight_text,pilot_text,paks_v='shared_enemies=off\n',COOP,nil,nil,nil
load_main(true)
local function step(line,notes)
    Q.Q.line,Q.Q.notes=line,notes or {}
    local n,out=#said,{}
    loops[2].f()
    for i=n+1,#said do
        if said[i]~='Kaanta joined.' and said[i]~='Kaanta: connection lost.' then out[#out+1]=said[i] end
    end
    return table.concat(out,'|')
end
local function note(kind,id,alias,zone) return {kind=kind,id=id,alias=alias,zone=zone} end
local ON='quests=on mode=on role=guest partner=on'
-- The co-op save one only once a main save is loaded: not at the title or during a load (case[4]: the status).
for _,case in ipairs({{nil,''},{'quests=waiting mode=on why=friend',''},
        {'quests=waiting mode=on why=save','',nil,with_slot('slot=none index=? marker=none\n')},
        {'quests=waiting mode=on why=save','',nil,with_slot('slot=unknown index=? marker=?\n')},
        {'quests=waiting mode=on why=save',
            'Shared quests need a co-op save, not your own. They start once you load one.',nil,
            with_slot('slot=main index=1 marker=2\n')},
        {'quests=waiting mode=on why=save','',nil,with_slot('slot=main index=1 marker=2\n')},
        {'quests=waiting mode=on why=game',''},
        {'quests=on mode=on role=guest partner=off',''},{ON,'Shared quests on with Kaanta.'},{ON,''},
        {ON,"Kaanta's step on Quest_Sub_001 waits until you reach Zone_WLA_30.",
            {note('zone','41','Quest_Sub_001','Zone_WLA_30')}},
        {ON,'Quest_Sub_017 waits until you kill its target yourself. coop quests force 54 skips that step.',
            {note('kill','54','Quest_Sub_017')}},
        {ON,'You are ahead of Kaanta on Quest_Sub_017. Nothing is undone; the step stays in your save.|You are behind '
            ..'Kaanta on Quest_Sub_002. Finish it in your own game to share it again.',
            {note('ahead','54','Quest_Sub_017'),note('behind','42','Quest_Sub_002')}},
        {ON,'Quest_Request_023 is ready: hand it in at your request board.',{note('board','80','Quest_Request_023')}},
        {ON,'',{note('locked','81','Quest_Request_024'),note('unseen','45','Quest_Sub_006')}},
        {ON,'Quest_Sub_017: the held step was applied.|Quest_WALN10_001: the held step was applied, and the game moves '
            ..'you for it.|Quest_Sub_002: nothing to force. coop quests status lists what each quest waits for.',
            {note('forced','54','Quest_Sub_017'),note('forced_warp','66','Quest_WALN10_001'),
                note('not_forced','42','Quest_Sub_002')}},
        {'quests=on mode=on role=guest partner=off','Kaanta stopped sharing quests.'},
        {'quests=on mode=on role=guest partner=off',''},
        {'quests=stopped','Shared quests stopped until the game restarts. coop-quests.log says why.'},
        {'quests=stopped',''},{'quests=off',''},
        {'quests=on mode=on role=host partner=on','Shared quests on with Kaanta.'},
        {'quests=on mode=on role=host partner=on','Kaanta is ahead of you on Quest_Sub_017. Nothing is undone; the '
            ..'step stays in their save.',{note('ahead','54','Quest_Sub_017')}},
        {'quests=waiting mode=on why=friend',''},{'quests=waiting mode=probe why=save',''}}) do
    status_text=case[4] or COOP
    local got=step(case[1],case[3])
    assert(got==case[2],tostring(case[1])..': '..got)
end
kit_language='fr-FR'
assert(step('quests=on mode=on role=guest partner=on',{note('board','80','Quest_Request_023')})=='Quêtes partagées '
    ..'actives avec Kaanta.|Quest_Request_023 est prête : rendez-la à votre tableau des requêtes.')
kit_language=nil
end
io.stdout:write('quests_test ok\n')
