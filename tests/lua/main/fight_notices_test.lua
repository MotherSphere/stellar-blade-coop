-- The shared fight's notices on screen through main.lua (fixture.lua), in English and in French: as the guest, enemies
-- with another max HP and the host down; camp rests in a shared area; the French ones with their English for the line
-- above EVE; same place's (stage 3a) and same spawns' (stage 4) notices; what keeps coop fight on from sharing; and
-- every notice in both languages within the feed's 200 bytes a line.
dofile('tests/lua/main/fixture.lua')
in_world=true -- In a world, as the settings tests left it when all of this was one file.
-- A co-op save loaded with shared_enemies=off, as for quests_test.lua's notices.
settings_text,status_text,fight_text,pilot_text,paks_v='shared_enemies=off\n',COOP,nil,nil,nil
load_main(true)
paks_tick(nil)
-- Sharing as the guest: once when the host has enemies we cannot pair for their MaxHP (until it stops or the friend
-- leaves); each time the host goes down while enemies are linked (her vitals: HP 0, or a life state 3-5).
local GUEST_ON='fight=on mode=on role=guest claims=0 corrections=0 kills=0 floored=0 desync=0 unpaired=1 sim_us=5/9 '
    ..'threads=1/1/2 pairs='
local MAXHP="Shared enemies: some enemies have another max HP in Kaanta's game (another difficulty or New Game+). They "
    ..'stay unshared.'
local DOWN='Shared enemies: Kaanta is down. Once they respawn, the enemies you share go back to full health.'
local function vitals(hp,life) return {hp=hp,max_hp=1000,life=life} end
for _,step in ipairs({{'fight=off why=coop fight off',''},
        {GUEST_ON..'2 maxhp=0','Shared enemies on: 2 enemies linked.'},
        {GUEST_ON..'2 maxhp=1',MAXHP},{GUEST_ON..'2 maxhp=2',''},
        {GUEST_ON..'2 maxhp=2',DOWN,vitals(0,1)},{GUEST_ON..'2 maxhp=2','',vitals(0,1)},
        {GUEST_ON..'2 maxhp=2','',vitals(1000,1)},{GUEST_ON..'2 maxhp=2',DOWN,vitals(500,3)},
        {GUEST_ON..'0 maxhp=2','',vitals(1000,1)},{GUEST_ON..'0 maxhp=2','',vitals(0,1)}, -- None linked: nothing.
        {'fight=waiting mode=on why=photo mode',''},{GUEST_ON..'0 maxhp=2',''},
        {'fight=waiting mode=on why=no friend linked',''},{GUEST_ON..'0 maxhp=1',MAXHP},
        {'fight=off why=coop fight off',''},{GUEST_ON..'1 maxhp=1','Shared enemies on: 1 enemy linked.|'..MAXHP},
        {'fight=on mode=on role=host enemies=2 claims=0 refused=0 kills=0 floored=0 sim_us=9/20 threads=1/1/2','',
            vitals(0,3)}, -- The host hears nothing of either.
        {'fight=off why=coop fight off',''}}) do
    mate_v=step[3]
    local got=fight_step(step[1])
    assert(got==step[2],tostring(step[1])..': '..got)
end
mate_v=nil
kit_language='fr-FR'
assert(fight_step(GUEST_ON..'1 maxhp=1')=="Ennemis partagés actifs : 1 ennemi lié.|Ennemis partagés : certains "
    .."ennemis ont d'autres PV max dans la partie de Kaanta (autre difficulté ou New Game+). Ils ne sont pas partagés.")
mate_v=vitals(0,3)
assert(fight_step(GUEST_ON..'1 maxhp=1')=='Ennemis partagés : Kaanta est à terre. Après sa réapparition, vos '
    ..'ennemis partagés reviennent à pleine santé.')
mate_v=nil
fight_step('fight=off why=coop fight off')
-- Camp rests in a shared area, as the guest, from the line's epoch=<zone>/<n>/<resets>: the host's n moving in the same
-- zone while their vitals read alive and they were not down in the last 10 s says their game reset the area; our own
-- resets moving with spawns=on and our life alive for the 10 s before says only their rest brings the enemies back.
-- Nothing for the first epoch line, another zone, a respawn of either player, no life read, spawns off, or as the host.
do
    local REST,MINE="Enemies are back: the area reset in Kaanta's game.",
        "Shared area: only Kaanta's camp rest brings its enemies back."
    local function guest(zone,n,resets,spawns)
        return 'fight=on mode=on role=guest pairs=2 claims=0 corrections=0 kills=0 floored=0 desync=0 unpaired=0 '
            ..'maxhp=0'..(spawns=='off' and ' spawns=off' or ' spawns=on spawned=0 despawned=0 spawns_differ=0')
            ..' scale=100/100 sim_us=5/9 threads=1/1/2 bosses=off boss=0 battle=0 epoch='..zone..'/'..n..'/'..resets
    end
    local function rest_tick(text,ticks) -- The rest notices said in ticks of 250 ms (one by default).
        fight_text=text
        local n,out=#said,{}
        for _=1,ticks or 1 do loops[2].f() end
        for i=n+1,#said do
            if said[i]:find('^Enemies are back') or said[i]:find('^Shared area') or said[i]:find('^Les ennemis')
                or said[i]:find('^Zone partagée') then out[#out+1]=said[i] end
        end
        return table.concat(out,'|')
    end
    local up,down,language={state=1,hp=500},{state=3,hp=0},kit_language
    mate_v,fake_link.Q.life,kit_language=vitals(1000,1),up,nil
    for _,step in ipairs({{guest(40,1,0),'',41},{guest(40,2,0),REST},{guest(40,2,0),''},{guest(41,3,0),''},
            {guest(41,3,1),MINE},{guest(41,4,2),REST..'|'..MINE},
            {guest(41,4,2),'',2,vitals(0,4)},{guest(41,5,2),'',36},{guest(41,6,2),''}, -- Their respawn: nothing.
            {guest(41,6,2),'',3},{guest(41,7,2),REST},
            {guest(41,7,2),'',4,nil,down},{guest(41,7,3),'',36},{guest(41,7,4),''}, -- Our respawn: nothing.
            {guest(41,7,4),'',3},{guest(41,7,5),MINE},
            {guest(41,7,6),'',1,nil,false},{guest(41,7,6),'',41},{guest(41,7,7),MINE}, -- No read, then 10 s up.
            {guest(41,7,8,'off'),''},
            {'fight=on mode=on role=host enemies=2 claims=0 refused=0 kills=0 floored=0 sim_us=9/20 threads=1/1/2 '
                ..'bosses=off boss=0 battle=0 epoch=41/8/9',''},
            {'fight=on mode=on role=host enemies=2 claims=0 refused=0 kills=0 floored=0 sim_us=9/20 threads=1/1/2 '
                ..'bosses=off boss=0 battle=0 epoch=41/9/10',''}}) do
        if step[4] then mate_v=step[4] end
        if step[5]~=nil then fake_link.Q.life=step[5] or nil end
        local got=rest_tick(step[1],step[3])
        assert(got==step[2],step[1]..': '..got)
        mate_v,fake_link.Q.life=vitals(1000,1),up
    end
    fight_step('fight=off why=coop fight off')
    kit_language='fr-FR'
    assert(rest_tick(guest(40,1,0),41)=='' and rest_tick(guest(40,2,1))=='Les ennemis sont revenus : la zone a été '
        ..'réinitialisée dans la partie de Kaanta.|Zone partagée : seul le repos de Kaanta au camp fait revenir ses '
        ..'ennemis.')
    mate_v,fake_link.Q.life,kit_language=nil,nil,language
    fight_step('fight=off why=coop fight off')
end
-- The same notices in the game's language (French: 0 and 1 singular), each with its English for the line above EVE.
local HOST_N='fight=on mode=on role=host claims=0 refused=0 kills=0 floored=0 sim_us=9/20 threads=1/1/2 enemies='
for _,step in ipairs({{'fight=off why=coop fight off',''},{HOST_N..'0',''},
        {HOST_N..'3','Ennemis partagés actifs : 3 ennemis liés.'},
        {'fight=stopped why=fault',"Ennemis partagés arrêtés jusqu'au redémarrage du jeu. coop-link.log dit pourquoi."},
        {HOST_N..'1','Ennemis partagés actifs : 1 ennemi lié.'},
        {'fight=off why=coop fight off',''},
        {'fight=waiting mode=on why=no friend linked',''},
        {'fight=off','Ennemis partagés coupés. coop-link.log dit pourquoi.'},
        {HOST_N..'2 scale=150/100',"Ennemis partagés actifs : 2 ennemis liés. PV des ennemis 150 %, équilibre 100 % "
            .."(réglage de l'hôte).","Shared enemies on: 2 enemies linked. Enemy HP 150 %, balance 100 % (the host's "
            .."setting)."},{'fight=off why=coop fight off',''}}) do
    fight_text=step[1]
    local n=#said
    loops[2].f()
    local got,en={},{}
    for i=n+1,#said do
        if said[i]:find('^Ennemis partagés') then got[#got+1],en[#en+1]=said[i],said_en[i] end
    end
    assert(table.concat(got,'|')==step[2],step[1]..': '..table.concat(got,'|'))
    assert(not step[3] or table.concat(en,'|')==step[3],table.concat(en,'|'))
end
kit_language=nil
local reads=fight_reads
loops[1].f(); loops[1].f(); assert(fight_reads==reads,'No shared fight work in the per-frame loop')
local languages=language_reads
fight_step('fight=stopped why=fault')
assert(language_reads==languages,'The language is read only to say a notice')
-- Same place's notices (stage 3a), every 250 ms from the pilot= line, in the menu's language: on with the count when
-- its enemies go from none to some; off with why once it was on, when the host's game turned it off or an error
-- stopped it; never for our own coop fight pilot off (why=asked), the host's own setting (why=setting) or the shared
-- fight not running (why=fight: its own notices say so), nor for a status that was not read; nothing per frame.
local function pilot_step(text)
    pilot_text=text
    local n,out=#said,{}
    loops[2].f()
    for i=n+1,#said do
        if said[i]:find('^Same place') or said[i]:find('^Même position') then out[#out+1]=said[i] end
    end
    return table.concat(out,'|')
end
local OFF_BY_ERROR='Same place off: stopped by an error until the game restarts. coop-link.log says why.'
for _,step in ipairs({{nil,''},{'pilot=off why=fight',''},{'pilot=off why=host',''},{'pilot=on piloted=0',''},
        {'pilot=on piloted=3','Same place: 3 enemies piloted.'},{'pilot=on piloted=2',''},{'pilot=on piloted=0',''},
        {'pilot=on piloted=1','Same place: 1 enemy piloted.'},{nil,''},
        {'pilot=off why=host',"Same place off: Kaanta's game turned it off."},{'pilot=off why=host',''},
        {'pilot=on piloted=2 probe=on','Same place: 2 enemies piloted.'},{'pilot=off why=asked',''},
        {'pilot=on piloted=2 test=cmc','Same place: 2 enemies piloted.'},{'pilot=off why=fight',''},
        {'pilot=on piloted=2','Same place: 2 enemies piloted.'},{'pilot=off why=setting',''},
        {'pilot=on piloted=0',''},{'pilot=off why=host',"Same place off: Kaanta's game turned it off."},
        {'pilot=on piloted=1','Same place: 1 enemy piloted.'},{'pilot=stopped',OFF_BY_ERROR},{'pilot=stopped',''},
        {'pilot=refused why=coop off',''}}) do
    local got=pilot_step(step[1])
    assert(got==step[2],tostring(step[1])..': '..got)
end
kit_language='fr-FR'
for _,step in ipairs({{'pilot=on piloted=3','Même position : 3 ennemis pilotés.'},
        {'pilot=off why=host',"Même position coupée : la partie de Kaanta l'a désactivée."},
        {'pilot=on piloted=1','Même position : 1 ennemi piloté.'},
        {'pilot=stopped',"Même position coupée : arrêtée par une erreur jusqu'au redémarrage du jeu. coop-link.log dit "
            ..'pourquoi.'}}) do
    local got=pilot_step(step[1])
    assert(got==step[2],tostring(step[1])..': '..got)
end
kit_language=nil
friend_name=''
pilot_step('pilot=on piloted=1')
assert(pilot_step('pilot=off why=host')=="Same place off: your friend's game turned it off.")
friend_name='Kaanta'
pilot_step(nil)
local pilots=pilot_reads
loops[1].f(); loops[1].f(); assert(pilot_reads==pilots,'No same-place work in the per-frame loop')
-- Same spawns' notices (stage 4), every 250 ms from the fight= line while coop fight on runs, in the menu's language:
-- on once a session when its spawns= first reads on, in the host's words or the guest's; stopped once when it reads
-- stopped (the same-place error stops same spawns too); as guest, once a session when its spawns_differ= first counts
-- an enemy. Nothing for spawns=off or a probe. Shared enemies off or stopped, or the friend gone, forget them.
do
    local function spawn_step(text)
        fight_text=text
        local n,out=#said,{}
        loops[2].f()
        for i=n+1,#said do
            if said[i]:find('^Same spawns') or said[i]:find('^Mêmes apparitions') then out[#out+1]=said[i] end
        end
        return table.concat(out,'|')
    end
    local SP_HOST='fight=on mode=on role=host enemies=2 claims=0 refused=0 kills=0 floored=0 spawns='
    local SP_GUEST='fight=on mode=on role=guest pairs=2 claims=0 corrections=0 kills=0 floored=0 desync=0 unpaired=0 '
        ..'maxhp=0 spawns='
    local SP_TAIL=' scale=135/115 sim_us=9/20 threads=1/1/2'
    local SP_ON_HOST='Same spawns on: where you and Kaanta stand within 100 m of each other in one zone, their game '
        ..'holds the same common enemies as yours.'
    local SP_ON_GUEST='Same spawns on: where you and Kaanta stand within 100 m of each other in one zone, your game '
        ..'holds the same common enemies as theirs.'
    local SP_STOPPED='Same spawns stopped by an error until the game restarts. coop-link.log says why.'
    local SP_DIFFER="Same spawns: some enemies differ between your game and Kaanta's (other .pak mods or "
        ..'fight_chars) and stay as they are. coop-link.log names them.'
    for _,step in ipairs({{nil,''},{SP_HOST..'off'..SP_TAIL,''},{SP_HOST..'on'..SP_TAIL,SP_ON_HOST},
            {SP_HOST..'on'..SP_TAIL,''},{SP_HOST..'off'..SP_TAIL,''},{SP_HOST..'on'..SP_TAIL,''},
            {SP_HOST..'stopped'..SP_TAIL,SP_STOPPED},{SP_HOST..'stopped'..SP_TAIL,''},
            {'fight=off why=coop fight off',''},
            {'fight=on mode=probe actors=12 eve=1 turn=40 turns_per_s=60 writes=armed spawns=probe sim_us=8/30 '
                ..'threads=1/1/2',''},
            {SP_GUEST..'off'..SP_TAIL,''},
            {SP_GUEST..'on spawned=0 despawned=0 spawns_differ=0'..SP_TAIL,SP_ON_GUEST},
            {SP_GUEST..'on spawned=3 despawned=1 spawns_differ=0'..SP_TAIL,''},
            {SP_GUEST..'off'..SP_TAIL,''}, -- The host's map loads: its next epoch line turns it on again.
            {SP_GUEST..'on spawned=3 despawned=1 spawns_differ=2'..SP_TAIL,SP_DIFFER},
            {SP_GUEST..'on spawned=3 despawned=1 spawns_differ=3'..SP_TAIL,''},
            {'fight=waiting mode=on why=no friend linked',''},
            {SP_GUEST..'on spawned=0 despawned=0 spawns_differ=1'..SP_TAIL,SP_ON_GUEST..'|'..SP_DIFFER},
            {'fight=stopped why=fault',''}}) do
        local got=spawn_step(step[1])
        assert(got==step[2],tostring(step[1])..': '..got)
    end
    kit_language='fr-FR'
    for _,step in ipairs({{SP_HOST..'on'..SP_TAIL,"Mêmes apparitions actives : là où vous et Kaanta êtes à moins de "
                .."100 m l'un de l'autre dans une même zone, sa partie a les mêmes ennemis communs que la vôtre."},
            {SP_HOST..'stopped'..SP_TAIL,"Mêmes apparitions arrêtées par une erreur jusqu'au redémarrage du jeu. "
                ..'coop-link.log dit pourquoi.'},
            {'fight=off why=coop fight off',''},
            {SP_GUEST..'on spawned=0 despawned=0 spawns_differ=1'..SP_TAIL,"Mêmes apparitions actives : là où vous et "
                .."Kaanta êtes à moins de 100 m l'un de l'autre dans une même zone, votre partie a les mêmes ennemis "
                ..'communs que la sienne.|Mêmes apparitions : certains ennemis diffèrent entre votre partie et celle de '
                ..'Kaanta (autres mods .pak ou fight_chars) et restent tels quels. coop-link.log les nomme.'},
            {'fight=off why=coop fight off',''}}) do
        local got=spawn_step(step[1])
        assert(got==step[2],tostring(step[1])..': '..got)
    end
    kit_language=nil
    fight_text=nil
end
-- What keeps coop fight on from sharing, one notice each time it changes: your own save (how to switch to the co-op
-- copy, or the manual slot when the co-op copies are off), her own save, her shared enemies off or stopped, the two of
-- you on different maps. Waits that end by themselves (no friend, a load, photo mode) say nothing and forget nothing;
-- sharing with her on the same map forgets what was said, and so does the session's end. Never for a solo tool.
local HOST_ON='fight=on mode=on role=host enemies=0 claims=0 refused=0 kills=0 floored=0 sim_us=0/0 threads=0/0/0'
local YOU='Shared enemies need a co-op save, not your own. Quit to the title screen, choose Convert and play co-op (or '
    ..'Play co-op), then Continue or load the same slot.'
local YOU_MANUAL='Shared enemies need a co-op save, not your own. With the co-op copies off, only the manual co-op '
    ..'slot counts (see INSTALL.md).'
fight_text=nil
link_mode,saves_info='host',{slot='main',saves='main'}
loops[2].f()
for _,step in ipairs({
        {'fight=waiting mode=on her=? why=not on a co-op save',YOU},
        {'fight=waiting mode=on her=? why=not on a co-op save',''},
        {'fight=waiting mode=on her=? why=no save loaded',''},
        {'fight=waiting mode=on her=own-save why=not on a co-op save',''},
        {HOST_ON..' her=own-save','Shared enemies wait: Kaanta plays their own save. They can switch at the title '
            ..'screen with Convert and play co-op (or Play co-op).'},
        {HOST_ON..' her=own-save',''},
        {HOST_ON..' her=off','Shared enemies wait: Kaanta has them off (co-op menu, Options, Combat).'},
        {HOST_ON..' her=stopped',"Shared enemies stopped for this run in Kaanta's game. Their coop-link.log says why."},
        {HOST_ON..' her=waiting',''},
        {HOST_ON..' her=?',''},
        {HOST_ON..' her=on',''},
        {HOST_ON..' her=stopped',"Shared enemies stopped for this run in Kaanta's game. Their coop-link.log says why."},
        {HOST_ON..' her=on',''},
        {'fight=waiting mode=on her=on why=photo mode',''},
        {'fight=on mode=probe actors=12 eve=1 turn=40 turns_per_s=60 writes=armed sim_us=8/30 threads=1/1/2 '
            ..'her=own-save',''}}) do
    local got=fight_step(step[1])
    assert(got==step[2],tostring(step[1])..': '..got)
end
her_map_v='/game/b07'
assert(fight_step(HOST_ON..' her=on')=='Shared enemies wait until you and Kaanta are on the same map.')
assert(fight_step(HOST_ON..' her=on')=='')
her_map_v=nil
assert(fight_step(HOST_ON..' her=on')=='','Her map unknown: nothing said, nothing forgotten')
her_map_v='/game/b07'
assert(fight_step(HOST_ON..' her=on')=='')
her_map_v='/game/e04'
assert(fight_step(HOST_ON..' her=on')=='')
-- The next session says it again; with the co-op copies off (auto_coop_save=off, or saves=off: another build), the
-- manual slot; in French with the game's language.
assert(fight_step('fight=waiting mode=on her=? why=not on a co-op save')==YOU)
link_mode='none'; assert(fight_step('fight=waiting mode=on why=no friend linked')=='')
link_mode,saves_info='guest',{slot='main',saves='off'}
assert(fight_step('fight=waiting mode=on her=? why=not on a co-op save (slot=main index=0 marker=4 saves=off)')
    ==YOU_MANUAL)
link_mode='none'; fight_step('fight=waiting mode=on why=no friend linked')
link_mode,saves_info,kit_language='guest',{slot='main',saves='main'},'fr-FR'
assert(fight_step('fight=waiting mode=on her=? why=not on a co-op save')=='Les ennemis partagés demandent une '
    ..'sauvegarde co-op, pas la vôtre. À l\'écran titre, choisissez Convertir et jouer en co-op (ou Jouer en co-op), '
    ..'puis Continuer ou chargez le même emplacement.')
assert(fight_step(HOST_ON..' her=own-save')=='Ennemis partagés en attente : Kaanta joue sur sa propre sauvegarde. Le '
    ..'passage se fait à l\'écran titre avec Convertir et jouer en co-op (ou Jouer en co-op).')
assert(fight_step('fight=stopped why=fault')=='Ennemis partagés arrêtés jusqu\'au redémarrage du jeu. coop-link.log '
    ..'dit pourquoi.')
-- A friend flipping her state every 250 ms: one notice, then the cause as it stands once 5 s passed, and so on.
link_mode,kit_language='host',nil
fight_step(HOST_ON..' her=on')
local flips={}
for i=1,40 do
    local got=fight_tick(HOST_ON..(i%2==1 and ' her=own-save' or ' her=off'))
    if got~='' then flips[#flips+1]=i end
end
assert(#flips==2 and flips[1]==1 and flips[2]>=21,table.concat(flips,','))
-- No name known (a stranger who joined with a code, or a name of controls only): your friend, in lower case.
for _,name in ipairs({'','\u{202E}'}) do
    friend_name=name
    local got=fight_step(HOST_ON..(name=='' and ' her=stopped' or ' her=off'))
    assert(got==(name=='' and "Shared enemies stopped for this run in your friend's game. Their coop-link.log says why."
        or 'Shared enemies wait: your friend has them off (co-op menu, Options, Combat).'),got)
end
friend_name='Kaanta'
link_mode,saves_info,kit_language='none',{},nil
settings_text='shared_enemies=on\nauto_coop_save=off\n'
load_main(true)
link_mode,saves_info='host',{slot='main',saves='main'}
assert(fight_step('fight=waiting mode=on her=? why=not on a co-op save')==YOU_MANUAL)
link_mode,saves_info,settings_text='none',{},''
fight_text=nil
status_text=plain
local Words=require('ui.text') -- Both languages complete.
for _,group in ipairs({'fight','spawns'}) do
    for k in pairs(Words.en[group]) do assert(Words.fr[group][k],group..'.'..k) end
    for k in pairs(Words.fr[group]) do assert(Words.en[group][k],group..'.'..k) end
end
-- Every notice fits the feed's 200 bytes a line (Chat.clean cuts the rest) with a 32-character Steam name.
for _,lang in ipairs({'en','fr'}) do
    for _,group in ipairs({'fight','spawns'}) do
        for k,text in pairs(Words[lang][group]) do
            local full=text:gsub('%%s',string.rep('W',32)):gsub('%%d','16')
            assert(Chat.clean(full)==full,lang..'.'..group..'.'..k..': '..#full..' bytes')
        end
    end
    local scaled=Words[lang].fight.on:format(16)..' '..Words[lang].fight.scale:format(200,200) -- The longest on.
    assert(Chat.clean(scaled)==scaled,lang..': '..#scaled..' bytes')
    -- The co-op saves notices (session/saves.lua's o.say), with their own words or a slot digit.
    for k,args in pairs({on={},off={Words[lang].saves.see_log},build={},manual={'4','4'}}) do
        local full=Words[lang].saves[k]:format(table.unpack(args))
        assert(Chat.clean(full)==full,lang..'.saves.'..k..': '..#full..' bytes')
    end
end
io.stdout:write('fight_notices_test ok\n')
