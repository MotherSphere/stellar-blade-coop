-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- T.en of ui/text.lua (see there).
return {
    title='CO-OP',
    head={modes='MODES',
        session='SESSION',settings='SETTINGS',help='HELP',controls='CONTROLS',photo='PHOTO MODE',partner='PARTNER',
        ghost='GHOST',saves='SAVES',combat='COMBAT',display='DISPLAY',chat='CHAT',line='CO-OP LINE'},
    row={scoreattack='Score attack',race_match='Doro race',
        host='Host a session',leave='Leave the session',invite='Invite a friend (Steam)',find='Find a session',
        copy='Copy my code',remove='Remove %s',join_code='Join with a code',
        chat='Chat',options='Options',report='Write a bug report',close='Close',
        menu_key='Open this menu',host_key='Host at once',status_key='Show the status',leave_key='Leave the session',
        photo_sync='Photo sync',photo_freeze_max='Longest pause',photo_ghost='Ghost in my photos',
        photo_name_tag='Name tag in my photos',photo_pause='Photo mode pause (experimental)',name_tag='Name tag',
        cloth='Ponytail cloth',dyes='Outfit colours',
        effects='Attack effects',send_rate='Poses sent a second',shared_enemies='Shared enemies (experimental)',
        ui_scale='Menu size',ui_sounds='Menu sounds',ui_language='Menu language',partner_bar='HP marker',
        partner_arrow='Off-screen arrow',partner_card='Partner card',card_details='Ping and map on the card',
        who_can_join='Who can join',friends_ask='Friends join without asking',
        max_players='Players',auto_coop_save='Co-op saves',enemy_hp_scale="Enemy HP (host's)",
        enemy_balance_scale="Enemy balance (host's)",kill_credit='My kill rewards',
        same_place='Same place (experimental)',aggro="Enemies attack (host's)",
        hit_reactions='Shared flinches (experimental)',stagger_resist='Stagger resistance (experimental)',
        same_spawns='Same spawns (experimental)',enemy_extra="Extra enemies (host's)",
        bosses='Shared bosses (experimental)',boss_hp_scale="Boss HP (host's)",
        shared_quests='Shared quests (experimental)',
        shared_world='Shared world (experimental)',
        shared_story='Story together (experimental)',
        revive='Friend can revive me',
        cutscene_wait='Wait for host cutscenes',
        collide='Solid partner',
        follow_host='Follow the host',follow_key='Travel to the host',menu='Co-op menu',hangup='Hang up',
        status_overlay='Status line',race_key='Set a race checkpoint',
        bike='Bike',bike_key='Get on or off the bike',
        gun_mode='Gun mode',gun_key='Bring out or put away the rifle',daynight='Day and night',
        pause_tab='Online tab in the pause menu',
        hide_popups='Hide popups online',
        reset_keys='Reset all keys'},
    value={on='On',off='Off',both='Both',notice='Notice only',game='Game language',english='English',
        ask='Ask',always='Always',together='Fought or within 30 m',
        fought='Only enemies I fought',aggro_game='Both players',aggro_host='The host only',photo_pause_full='Full',
        photo_pause_scenery='Scenery live',compact='Compact',detailed='Detailed',
        who_can_join_public='Public',who_can_join_friends='Friends only',who_can_join_invitation='Invitation',
        who_can_join_closed='Private',friends_ask_on='Off',friends_ask_off='On'},
    no_limit='No limit',minutes='%d min',seconds='%d s',percent='%d %%',press='Press a key',
    hint={move='Move',select='Select',back='Back',default='Default'},
    sit='Sit',stand='Stand up',
    line={prompt='Co-op line',free='The line is free. Host a session or join a friend.',
        open='Your session is open. Invite a friend from here.',linked='On the line with %s.'},
    confirm_leave='Select again within 3 s to leave.',confirm_remove='Select again within 3 s to remove and block %s.',
    confirm_reset_keys='Select again within 3 s to reset every key.',
    reload='Saved. It takes effect when the mod reloads (game start or Ctrl+R).',
    capture='Press F1 to F12, with Shift, Ctrl or Alt if you like. Esc cancels.',
    clash='%s already uses this key.',f10='F10 opens the console.',
    keys='Use F1 to F12, with at most one of Shift, Ctrl, Alt.',
    unreadable='Not saved: coop-settings.txt cannot be read.',not_saved='Not saved: %s',
    report='The bug report goes to coop-report.txt in the mod folder.',
    chat={you='You',partner='Partner',said='%s: ',hint='Message · Enter to send · Esc to close',
        no_session='Chat needs a session or the PvP lobby.',
        alone='No other player is connected yet: your messages stay on your screen.',
        off='Chat is off (Options > Chat).',not_sent=' (not sent)',
        ui_off='The chat box is off (the UI stopped, see UE4SS.log).'},
    partner={partner='Partner',down='DOWN',lost='connection lost',elsewhere='elsewhere · %s'},
    -- The status strip above the partner card (online/partner/hud.lua, status_overlay): its second row (detailed) holds
    -- the shared enemies, the same-place enemies (%d: how many), shared quests on and the poses sent a second (%d); its
    -- top row starts with paused while her photo mode pauses your game.
    overlay={enemies='Enemies %d',place='Same place %d',quests='Quests on',rate='%d/s',paused='paused'},
    -- The code box and the host's question (online/session/join.lua).
    join={title='JOIN WITH A CODE',hint='XXX-XXXX',join='Join',cancel='Cancel',
        bad='A join code is 7 letters and digits, like XXX-XXXX.'},
    -- A join Steam refused (T.join_refused, link/core.h's join_refusal() by EChatRoomEnterResponse): 2 gone, 3 closed,
    -- 4 full, 5 error, 6 banned, 7 limited, 8 group, 9 community, 10 blocked_you, 11 you_blocked, 15 rate; other: any
    -- other number (%d).
    join_refused={gone='Could not join: that game no longer exists.',
        closed='Could not join: that game is closed (a private session, or a match that started).',
        full='Could not join: that game is full.',
        error='Could not join: Steam had an unexpected error. Try again.',
        banned="Could not join: Steam has banned you from that game's lobby.",
        limited='Could not join: your Steam account is limited. Spending 5 USD on Steam lifts the limit.',
        group='Could not join: that Steam group is locked or disabled.',
        community='Could not join: your Steam account has a community ban.',
        blocked_you='Could not join: a player in that game has blocked you on Steam.',
        you_blocked='Could not join: you have blocked a player in that game on Steam.',
        rate='Could not join: too many tries in a short time. Wait a moment and try again.',
        other='Could not join: Steam response %d.'},
    -- The join popups (online/session/join.lua): the host's question (title, desc, left, accept and deny when SB's own
    -- words are missing) and the joiner's wait (wait_title with host when the host's name is empty, wait_desc,
    -- wait_left, close when SB's Close is missing).
    ask={title='%s wants to join',someone='A player',accept='Accept',deny='Deny',
        desc='They wait for your answer before they enter your game.',left='Declined in %d s if you do not answer.',
        wait_title="Waiting for %s's answer",host='the host',wait_desc='Close cancels your request to join.',
        wait_left='The host has %d s left to answer.',queue='Players waiting after this one: %d.',close='Close'},
    -- The question at the title (online/saves/saves.lua) and its notices.
    saves={title='CO-OP SAVES',new='Play co-op on copies of your saves?',
        new_about='StellarCoop copies your saves to separate co-op files, and Continue and Load Game then use those '
            ..'copies. Your own saves are not changed.',
        invite="Your friend's invite waits until your save loads.",
        old='Play co-op on your co-op saves?',
        old_about='Continue and Load Game then use your co-op copies. Your own saves are not changed.',
        convert='Convert and play co-op',play='Play co-op',solo='Play solo normally',later='Decide later',
        always="Don't ask again",always_value='Always co-op',
        switching='Switching to the co-op saves.',copying='Making the co-op copies: step %d of %d.',
        failed='The co-op saves could not be switched on. Your own saves were not changed.',
        see_log='coop-link.log says why',
        on='Co-op saves on: you play co-op copies of your saves. Your own saves are not changed.',
        off='Co-op saves off for this load: %s. You play your own saves.',
        build='Co-op saves are off: StellarCoop does not support this version of the game. You play your own saves '
            ..'until StellarCoop is updated.',
        -- The manual co-op slot's digit, twice.
        manual='Co-op now plays StellarBladeCoop0%s.sav. With the game closed, you can move StellarCoopSlot.txt out of '
            ..'the save folder, and StellarBladeSave0%s.sav unless you played it after that copy was made.'},
    -- The status line (core/link.lua's summary(): under the menu, and the status key's notice); %s: her Steam name, or
    -- friend.
    summary={stopped='Co-op: the Steam link stopped; coop status says why.',waiting='Co-op: waiting for Steam.',
        held='Co-op: invite held until your save has loaded.',rejoin="Co-op: rejoining your friend's game (try %s/3).",
        none='Co-op: not in a session.',alone='Co-op: hosting, no friend yet.',connecting='Co-op: %s is connecting.',
        friend='your friend',hosting='Co-op: hosting %s.',guest="Co-op: in %s's game.",paused=' Paused by %s.',
        lost=' Connection lost.'},
    -- Why the menu key did not open the menu (ui/kit/menu.lua).
    refused={off='The co-op menu is off (the UI stopped, see UE4SS.log): use the coop commands.',
        world='The co-op menu opens in the game world only.',
        paused='The co-op menu does not open while the game is paused or shows a menu.'},
    -- The ghost's notices (online/partner/puppet.lua): her name, her map, yours.
    ghost={failed='Ghost failed 3 times: the reason is in UE4SS.log.',away='%s is in %s, you are in %s.',
        mods='%s wears parts from mods your game cannot load: %s. They show on the base suit or are left out.',
        aside='The game crashed last time while the ghost used the mod asset %s. It stays off the ghost until coop cns '
            ..'reset.'},
    -- UE4SS-settings.ini's notices (main.lua, core/ue4ss_settings.lua): HookBeginPlay or bUseUObjectArrayCache on.
    ue4ss={hook='In UE4SS-settings.ini, HookBeginPlay is on: Stellar Blade can crash when EVE lets go of a movable '
            ..'crate. Set it to 0 (the Stellar Blade UE4SS 1.3 value).',
        cache='In UE4SS-settings.ini, bUseUObjectArrayCache is on: it can cause stutter and crashes at startup. Set it '
            ..'to false (the Stellar Blade UE4SS 1.3 value).'},
    -- The notice for a module that failed to load (main/loader.lua), said once by main/pass.lua: %s is its name in
    -- modules, which holds one for each module of main.lua's list.
    module_off='%s is off until the mod reloads: it failed to load. UE4SS.log says why.',
    modules={['online.partner']='The ghost',['online.modes.nightop']='Night Operation',['fight.bosses']='Cut enemies',
        ['online.group']='Group play',['online.modes.race']='Doro races',['eve']="EVE's cut moves",
        ['story.scenes']='Cut scenes',['world.maps.matrix13']='Matrix XIII',['online.session']='Online sessions',
        ['online.photo']='Synced photo mode',['fight.enemies']='Shared enemies',['story.quests']='Shared quests',
        ['world.objects']='Shared world',['story.together']='Story together',['online.lobby']='The SBO lobby',
        ['vehicles.bike']='The bike',['world.daynight']='Day and night',['cutmenus']='Cut menus',
        ['online.saves']='Co-op saves',
        ['world.teamshop']='Team shop',['fight.gunmode']='Gun mode',['online.modes.scoreattack']='Score attack'},
    -- The shared enemies' notices (main.lua): on, off, stopped, and what keeps coop fight on from sharing (%s: her
    -- name). The title question's buttons are saves.convert and saves.play.
    fight={on='Shared enemies on: %d enemies linked.',one='Shared enemies on: 1 enemy linked.',
        scale="Enemy HP %d %%, balance %d %% (the host's setting).",
        off='Shared enemies off. coop-link.log says why.',
        stopped='Shared enemies stopped until the game restarts. coop-link.log says why.',friend='your friend',
        you='Shared enemies need a co-op save, not your own. Quit to the title screen, choose Convert and play co-op '
            ..'(or Play co-op), then Continue or load the same slot.',
        you_manual='Shared enemies need a co-op save, not your own. With the co-op copies off, only the manual co-op '
            ..'slot counts (see INSTALL.md).',
        her_save='Shared enemies wait: %s plays their own save. They can switch at the title screen with Convert and '
            ..'play co-op (or Play co-op).',
        her_off='Shared enemies wait: %s has them off (co-op menu, Options, Combat).',
        her_stopped="Shared enemies stopped for this run in %s's game. Their coop-link.log says why.",
        map='Shared enemies wait until you and %s are on the same map.',
        maxhp="Shared enemies: some enemies have another max HP in %s's game (another difficulty or New Game+). They "
            ..'stay unshared.',
        host_down='Shared enemies: %s is down. Once they respawn, the enemies you share go back to full health.',
        paks='%s loads other .pak mods than you (%d there, %d here). Enemies that differ stay unshared.',
        mods_missing="%s uses mods you don't have: %s. Parts of their outfit from them look different here.",
        mods_other='%s uses other versions of mods you have: %s. Parts of their outfit from them may look different '
            ..'here.'},
    -- The DLC notice (main.lua, T.dlcs): the DLCs she has and you lack (theirs), those you have and she lacks (yours);
    -- %s: her name, then the DLCs' names.
    dlc={theirs="%s has DLCs you don't have: %s.",yours="You have DLCs %s doesn't have: %s."},
    -- The New Game+ notice (main.lua, T.cycle): %s her name, her cycle, her difficulty, your cycle, your difficulty.
    cycle={notice='%s is on %s (%s); you are on %s (%s). Enemies with another max HP stay unshared.',
        their_first='their first playthrough',your_first='your first playthrough',plus='New Game+ %d',
        normal='Normal',story='Story',hard='Hard'},
    -- Same place's notices (main.lua): how many enemies it moves, and why it went off (off with host or stopped; %s
    -- in host: her name, or fight.friend).
    pilot={on='Same place: %d enemies piloted.',one='Same place: 1 enemy piloted.',off='Same place off: %s',
        host="%s's game turned it off.",stopped='stopped by an error until the game restarts. coop-link.log says why.'},
    -- Same spawns' notices (main.lua): on, in the host's words or the guest's, stopped by same place's error, and
    -- enemies that differ between the two games (%s: her name, or fight.friend).
    spawns={host='Same spawns on: where you and %s stand within 100 m of each other in one zone, their game holds '
            ..'the same common enemies as yours.',
        guest='Same spawns on: where you and %s stand within 100 m of each other in one zone, your game holds the '
            ..'same common enemies as theirs.',
        stopped='Same spawns stopped by an error until the game restarts. coop-link.log says why.',
        differ="Same spawns: some enemies differ between your game and %s's (other .pak mods or fight_chars) and "
            ..'stay as they are. coop-link.log names them.'},
    -- Camp rests in a shared area, as the guest (main.lua): the host's rest reset the area in their game, or ours
    -- reset our own only. The revive by the friend (online/group/group.lua): she is down near us, we are down and she
    -- can revive us, she revived us, we revived her; and our game waiting while the host watches a cutscene. (%s: her
    -- name, or fight.friend.)
    group={rest="Enemies are back: the area reset in %s's game.",
        rest_guest="Shared area: only %s's camp rest brings its enemies back.",
        down='%s is down. Stand next to them for 3 s to revive them.',
        wait='%s can revive you: wait, or respawn at a camp.',
        revived='Revived by %s.',
        you_revived='You revived %s.',
        cutscene='%s is watching a cutscene. Your game waits until it ends.'},
    -- The follow (online/group/travel.lua), the guest's: the offer when the host is on another map or far on hers (%s:
    -- her name, her map, follow_key), always's notice (her name, follow_key), the travel taken, no camp found, a
    -- guard of the moment, and the native part's refusal or a warp that never started.
    travel={offer='%s is in %s. Press %s to travel to the camp nearest them.',
        auto='Following %s in 5 s. Press %s to stay.',going='Travelling to %s.',
        none='No camp you have found is near %s.',busy='You cannot travel now. Try again in a moment.',
        failed='The travel did not start. UE4SS.log says why.'},
    -- The parked bike (vehicles/bike/ride.lua): a mount refused with the bike's distance and side from her camera (%d
    -- metres, then one of the four side words), refused before it is back on her map (2 s after her arrival) or while
    -- it is on another (%s: the map's name); the prompt once she comes within reach of it (%s: bike_key). At a Xion
    -- camp the paid fetch (vehicles/bike/fetch.lua): its offer after the far or another-map refusal (%s: bike_key, %d:
    -- the price, %s: the money's name as SB writes it in the game's language, else betacrystal), the payment under way
    -- and paid (the price, the name), too little money (the name, the price, then her count) and a failure.
    bike={far='Your bike is %d m away, %s.',ahead='ahead of you',behind='behind you',left='to your left',
        right='to your right',not_back='Your bike is not back yet.',other_map='Your bike is on another map: %s.',
        prompt='%s: get on the bike',
        offer='Press %s again within 5 s to pay %d %s to bring it here.',
        paying='Paying %d %s for your bike.',paid='Your bike was brought here for %d %s.',
        poor='Not enough %s: %d needed, you carry %d.',
        unpaid='Your bike was not brought here. UE4SS.log says why.'},
    -- Gun mode (fight/gunmode/mode.lua): its notices while it is parked for its rebuild (gun_key shows it and does
    -- nothing else) or during an SBO match; one for each refused toggle: the drone aim held, no EVE, a state of hers or
    -- another module that holds her, a start that failed. round, reload and empty go on the reticle's round slot
    -- (fight/gunmode/ammo.lua): the round's name (NIKKE RAPID, a name, kept in every language), the reload, no round
    -- left.
    gun={rebuilding='Gun mode: rebuilding',
        match='Gun mode: not during a match. Rifle hits past 15 m do not count there yet.',
        round='NIKKE RAPID',reload='RELOADING',empty='NO AMMO',
        aim='Gun mode: release the drone aim first.',
        eve='Gun mode: EVE is not in the game world.',
        busy='Gun mode: EVE cannot take the rifle now. UE4SS.log says why.',
        failed='Gun mode: the start failed. UE4SS.log says why.'},
    -- Night Operation's run (online/modes/nightop/run.lua): its card at the top centre (the title, then the countdown,
    -- the wave or the next wave's countdown, each with the time left and the score), its result panel (the heading, the
    -- line under it, the rows) and its notices while the UI is off. success, fail and died are the game's own words,
    -- its StringTable_UI rows UI_Night_OperationSuccess, UI_Night_OperationFail and UI_Night_OperationFail_Des, which
    -- the panel reads from the game when it can; why: what ended a stopped run, by its reason. A run for two linked
    -- players: the host's card while he waits for her answer, her notice when his countdown starts (%s his name), his
    -- notice when she cannot join (%s her name, then refuse's word), and whose EVE died (named, so no word agrees with
    -- a player's gender). earned: the points a run gave for the shop (online/modes/nightop/shop.lua), then the player's
    -- total; unpaid: a run's points that could not be credited (UE4SS.log says why).
    -- panel reads from the game when it can; why: what ended a stopped run, by its reason. A challenge (coop challenge)
    -- uses the same card, panel and end notice, with challenge's words: names, its name, the card's title in place of
    -- night.title and the %s of its notices (start, wave, clear); best, the panel's fifth row, which Night Operation
    -- shows too; record, the line under the heading after a success that wrote a new best; stopped, what ended a
    -- challenge stopped with coop challenge stop; coop_notice, her notice when the host starts a co-op challenge (the
    -- Shooting Range): its name, then his.
    night={title='NIGHT OPERATION',starts='STARTS IN %d',wave='WAVE %d/%d',next='NEXT WAVE IN %d',score='SCORE %d',
        success='Operation Successful',fail='Operation Failed',died='All players have died.',time_up='Time is up.',
        why={stop='Stopped with coop nightop stop.',map='Ended by a map change or a load.',
            left='You were more than 80 m from the start for 10 s.',slot='This save is no longer a co-op save.',
            link='A Steam session started during a solo run.',
            mate='Your partner left the run.',lost='The link to your partner was lost.',
            error='Stopped by an error. UE4SS.log says why.'},
        waves='Waves cleared',kills='Kills',points='Score',time='Time',start_notice='Night Operation starts in %d s.',
        wave_notice='Night Operation: wave %d/%d.',clear_notice='Night Operation: wave %d cleared.',
        end_notice='%s: %d/%d waves cleared, %d kills, score %d, time %s.',
        waiting='WAITING FOR PARTNER',coop_notice='%s started Night Operation. It begins in %d s.',
        refused='%s cannot join the run: %s.',refuse={far='more than 50 m from you',map='on another map',
        slot='not on a co-op save',busy='already in a run',near='enemies or people within 40 m',
        taken='monsters of an earlier run are still there',none='no answer'},mate_died="Your partner's EVE died.",
        you_died='Your EVE died.',
        earned='Night Operation: +%d points, %d in all.',
        unpaid='Night Operation: the points could not be saved. UE4SS.log says why.',
        booked='Night Operation starts once you leave Xion and no one is within 40 m.',
        host_only='In a co-op session, only the host starts Night Operation.',
        pair_only='Night Operation does not run in a session of more than 2 players.',
        shop_failed='The Night Operation shop could not open. UE4SS.log says why.'},
    challenge={names={swarm='Antlion Swarm',skulls='Skull Squad',gauntlet='Gauntlet',targets='Target Practice',
        range='Shooting Range'},
        best='Best',record='New personal best.',stopped='Stopped with coop challenge stop.',
        start_notice='%s starts in %d s.',wave_notice='%s: wave %d/%d.',clear_notice='%s: wave %d cleared.',
        coop_notice='%s: %s started the challenge. It begins in %d s.'},
    -- The shared quests' notices (main.lua): on with her, waiting for a co-op save, stopped, her side off, and one
    -- per quest note; %s: her name (or fight.friend), the quest's row name, a zone or the quest's number, in that
    -- order where they appear.
    quests={on='Shared quests on with %s.',
        save='Shared quests need a co-op save, not your own. They start once you load one.',
        stopped='Shared quests stopped until the game restarts. coop-quests.log says why.',
        partner_off='%s stopped sharing quests.',
        ahead_host='%s is ahead of you on %s. Nothing is undone; the step stays in their save.',
        ahead_guest='You are ahead of %s on %s. Nothing is undone; the step stays in your save.',
        behind='You are behind %s on %s. Finish it in your own game to share it again.',
        zone="%s's step on %s waits until you reach %s.",
        board='%s is ready: hand it in at your request board.',
        kill='%s waits until you kill its target yourself. coop quests force %s skips that step.',
        forced='%s: the held step was applied.',
        forced_warp='%s: the held step was applied, and the game moves you for it.',
        not_forced='%s: nothing to force. coop quests status lists what each quest waits for.'},
    world={on='Shared world on with %s.',
        stopped='Shared world stopped until the game restarts. coop-link.log says why.'},
    story={on='Story together on with %s.',
        stopped='Story together stopped until the game restarts. coop-link.log says why.'},
    -- The Doro race's words (online/modes/race/run.lua, ui/hud.lua): its panel, banners and results on the HUD, its
    -- notices (the feed, or the line above EVE), and why a race ended early for you (why), was raced alone (refused:
    -- the host's, her answer) or was not joined (declined: the guest's, the host's track); %s: her name, a track's name
    -- or a key's, in order. A match round's results note (still: the players still racing; best; unranked) and, with
    -- the UI off, our place (placed: ours, of how many). match: the notices of a Doro race round in a match lobby
    -- (online/modes/race/match/game.lua): why we sit out the round, the host's room with no track, the host who left
    -- and a round cancelled before its ranking.
    race={title='DORO RACE',cp='CP %d/%d',lap='LAP %d/%d',pos='POS %d/%d',go='GO!',wrong_way='WRONG WAY',
        missed='MISSED CHECKPOINT %d',finished='FINISHED',dnf='DNF',slot='Your start',waiting='Waiting for %s',
        results='RESULTS',fast='fast run',pause='paused',why={teleport='Moved more than 20 m at once.',
        map='Left the map.',quit='Quit the race.',left='The session ended.',late='Not finished 60 s after the winner.',
        time='Over the 15 min limit.',
        crowd='Doro races do not run in a session of more than 2 players.'},armed='Race ready: walk to your start.',
        armed_guest='%s starts a race: walk to your start.',false_start='False start: back to your start.',
        cancelled='Race cancelled.',out='%s left the race.',refused={map='%s is on another map. You race alone.',
        track='%s could not read the track. You race alone.',save='%s is not on a co-op save. You race alone.',
        silent='%s did not answer. You race alone.'},declined={map='%s started a race on another map.',
        track="%s's track could not be read.",save='%s started a race. Races need a co-op save.'},
        recording='Recording %s: press %s at each checkpoint.',dropped='Checkpoint %d set.',
        too_close='Too close: 15 m at least between checkpoints.',full='64 checkpoints already: save the track.',
        other_map='This track is on another map.',
        saved='Track %s saved, %d checkpoints.',
        still='Results still to come: %d.',best='New personal best.',unranked='Not ranked.',
        placed='Doro race: you placed %d of %d.',
        match={off='Doro races are off in Options: you sit out this round.',
            bike='Get off the bike to race in the next round.',
            night='A Night Operation run is on: you sit out this round.',
            save='Doro races need a co-op save: you sit out this round.',
            room='You are not in the waiting room: you sit out this round.',
            fence='The track runs outside this room: you sit out this round.',
            map='The track is on another map: you sit out this round.',
            busy='You are recording a track or testing the drive: you sit out this round.',
            refused='Your game could not start the race: you sit out this round. UE4SS.log says why.',
            track='The track did not arrive whole: you sit out this round.',
            notrack='No track here: record one in this room with coop race record.',
            host_left='The host left. This round has no ranking.',cancelled='The round was cancelled.'}},
    -- The SBO lobby's notices (online/lobby/sbo.lua): the co-op save before the entry, why an entry is refused (no),
    -- and what failed (fail). nightop and boss use the game's own name for each mode in each language, its
    -- StringTable_UI rows UI_Night and UI_BossRush_Title.
    sbo={saving='Saving the co-op game. Leaving the lobby brings you back here.',
        no={coop='The PvP lobby needs co-op saves (saves=coop).',
            lobby='The PvP lobby is off (sbo_lobby=off in coop-settings.txt).',steam='Steam is not ready.',
            partner='End the co-op session first.',fight='Not during a fight.',
            nightop='Not during a Night Operation run.',busy='Not now: the game is loading or travelling.',
            save='The game cannot save here.',boss='Not during a Boss Challenge.',
            queue='The game is saving. Try again in a moment.',
            record='An SBO session is still open. Quit to the title to restore the co-op save.',
            hall='Left the match: its lobby map is missing or a different version here.'},
        fail={save='The game did not save. Nothing changed.',warp='The lobby did not load. Nothing changed.',
            leave='Could not go back to Xion. Quit to the title: the co-op save is restored there.'}},
    -- The lobby menu (mockup B, online/lobby/ui/lobby.lua): its sub and page lines, a mode's name and line (desc), the
    -- rows (more and its tag for the modes not built yet), the status line under them, the members box and the waiting
    -- room's notice (room, %s: the menu key); the settings (mockup C): tabs, each setting's title (set; arena waits for
    -- stage 4) and value (val); the Leave question (pop). Outside English and French, Settings, Cancel, Difficulty,
    -- Equipment and Change are the game's own StringTable_UI words (UI_Lobby_Options, UI_Cancel,
    -- UI_Setting_GamePlay_Mode, UI_Equipment, UI_Setting_Rolling), and Search, Start and Normal Mode
    -- (UI_Interaction_T_Search, UI_BossRush_Start, UI_NormalMode) where the game's word means the same thing there.
    lobby={sub='PvP LOBBY · SBO',page='LOBBY · SBO',mode={race='Doro race',
            scoreattack='Score attack',
            ffa='Free-for-all'},
        desc={
            race='2 to 8 players race as Doros on the same track. The shortest time wins.',
            scoreattack='2 to 8 players play the same challenge at once. The best score wins, then the shortest time.',
            ffa='2 to 8 players. First to 20 kills, or the best score after 10 minutes. You respawn after 4 s.',
            more='More modes come in later versions.'},row={track='Track',
            challenge='Challenge',
            search='Search',cancel='Cancel',private='Private match',
            code='Code %s',join_code='Join with a code',room='Waiting room',settings='Settings',leave='Leave',
            more='More modes'},tag={picked='picked',
            soon='soon'},status={idle='Pick a mode, then Search.',searching='Searching…',
            open='In the lobby, %d of %d',full='Lobby full, %d of %d',start='Starting in %d s',
            private='Private match, %d of %d',created='No lobby found. Yours is open.',copied='Code copied.'},
        members='Members',count='%d of %d',you='you',host='host',connecting='connecting…',lost='lost',
        empty='No lobby yet. Search finds one or opens one.',empty_search='Looking for a public lobby of this mode.',
        hint={change='Change',tabs='Tabs'},room='Lobby menu: %s, or hold View',tab={match='MATCH',sbo='SBO'},
        head={lobby='LOBBY'},set={track='Track',
            challenge='Challenge',ranking='Ranking',
            damage='Damage between players',
            room='Map',players='Players',finish='End',tie='Tie',respawn='Respawn',
            protection='Spawn protection',difficulty='Difficulty',equipment='Equipment',arena='Arena',start='Start',
            lobby='Lobby',version='Version',mute='Mute %s'},val={
            race_ranking='Shortest time, ties within 0.01 s',
            ranking='Best score, then shortest time',
            damage='None',host_pick="Host's pick",
            random='Random',
            players='2 to 8',finish='20 kills or 10 min',
            tie='Sudden death, 60 s at most',respawn='4 s',protection='6 s, ends when you attack',
            difficulty='Normal for everyone',equipment='The same for everyone',
            start='10 s from 2 players, 5 s when full',public='Public',private='Private, code %s',
            version='%s, protocol %d'},pop={leave_title='LEAVE THE LOBBY',
            leave='Go back to Xion? You return where you talked to the recruiter.'}},
    -- Find a session (online/session/ui/sessions.lua): the Select and Refresh hints, the host's revive rule as the
    -- joiner reads it, the status line, the friend mark, the version in the details (protocol, game build) and the
    -- footer with ours.
    sessions={ask='Ask to join',refresh='Refresh',empty='No open session.',
        revive='You can revive the host',
        failed='The search failed. Refresh to try again.',idle='Press Refresh to search.',
        wait='You can search again in %d s.',friend='Steam friend',version='Protocol %s, game build %s',
        footer='Your version: protocol %s, game build %s. Sessions of other versions are not listed.'},
    -- Create a session (online/session/ui/create.lua): its page title, the rules header, the Start row, why a locked
    -- row cannot change and Who can join's value explained in the right pane.
    create={title='Create a session',rules='SESSION RULES',start='Start',
        locked='coop-settings.txt cannot be read: this setting cannot change now.',
        who={public='Listed in Find a session for players of your version. Players who are not your Steam friends ask '
            ..'to join.',
            friends='Only your Steam friends can join. They find it in Find a session or in Steam.',
            invitation='Not listed. Players join with a Steam invite or your join code.',
            closed='Nobody can join, not even with an invite or a code.'}},
    -- Score attack (online/modes/scoreattack/ui/board.lua, game.lua): the in-round board's wave and end words (ending:
    -- win, time, dead, stop); the result panel's line under its heading (mine: the end word, the score, the time); its
    -- note (waiting, unranked; the record line is challenge.record); why a round ends without a ranking (host_left,
    -- cancelled); why a player sits out a round (out: off, bike, night, room, refused). With the UI off: her run's end
    -- (end_notice: the challenge, the end word, the score, the time) and her place (placed: hers, of how many).
    scoreattack={wave='Wave %d/%d',ending={win='Cleared',time='Time up',dead='Died',stop='Stopped'},
        mine='%s · score %d · %s',
        waiting='Results still to come: %d.',
        unranked='Not ranked.',
        host_left='The host left. This round has no ranking.',
        cancelled='The round was cancelled.',
        out={off='Score attack is off in Options: you sit out this round.',
            bike='Get off the bike to play the next round.',
            night='A Night Operation run is on: you sit out this round.',
            room='You are not in the waiting room: you sit out this round.',
            refused='Your game could not start the challenge: you sit out this round. UE4SS.log says why.'},
        end_notice='%s: %s, score %d, time %s.',
        placed='Score attack: you placed %d of %d.'},
    -- The pause menu's Online tab (ui/kit/pause_tab.lua): its word and the notice when the game stays paused.
    pause_tab={tab='Online',stuck='The game stayed paused, so the co-op menu did not open.'},
}
