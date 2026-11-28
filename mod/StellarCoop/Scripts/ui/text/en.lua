-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- T.en of ui/text.lua (see there).
return {
    title='CO-OP',
    head={tools='TEST TOOLS',
        modes='MODES',
        session='SESSION',settings='SETTINGS',help='HELP',controls='CONTROLS',photo='PHOTO MODE',partner='PARTNER',
        ghost='GHOST',saves='SAVES',combat='COMBAT',display='DISPLAY',chat='CHAT',line='CO-OP LINE'},
    row={closet_key='Open Stellar Closet',
        emote_key='Emote wheel key',emote_pad='Emote wheel on a controller',
        scoreattack='Score attack',fishing='Fishing tournament',race_match='Doro race',
        photohunt='Photo hunt',
        host='Host a session',leave='Leave the session',invite='Invite a friend (Steam)',find='Find a session',
        copy='Copy my code',remove='Remove %s',join_code='Join with a code',
        chat='Chat',options='Options',report='Write a bug report',close='Close',
        menu_key='Open this menu',host_key='Host at once',status_key='Show the status',leave_key='Leave the session',
        photo_sync='Photo sync',photo_freeze_max='Longest pause',photo_ghost='Ghost in my photos',
        photo_name_tag='Name tag in my photos',photo_pause='Photo mode pause (experimental)',name_tag='Name tag',
        cloth='Ponytail cloth',dyes='Outfit colours',
        effects='Attack effects',send_rate='Poses sent a second',shared_enemies='Shared enemies (experimental)',
        drone='Her drone',sounds='Her sounds',faces='Face and shape keys',
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
        bike='Bike',bike_key='Get on or off the bike',bike_pose='Riding pose (test)',
        gun_mode='Gun mode',gun_key='Bring out or put away the rifle',daynight='Day and night',
        pause_tab='Online tab in the pause menu',
        hide_popups='Hide popups online',
        spectate='Watch a friend when I fall',
        boss_finish="Boss finisher (host's)",
        reset_keys='Reset all keys'},
    value={emote_pad_dpad_left='D-pad Left held',
        on='On',off='Off',both='Both',notice='Notice only',game='Game language',english='English',
        ask='Ask',always='Always',together='Fought or within 30 m',
        fought='Only enemies I fought',aggro_game='Both players',aggro_host='The host only',photo_pause_full='Full',
        photo_pause_scenery='Scenery live',compact='Compact',detailed='Detailed',
        boss_finish_first='First press',
        boss_finish_host='The host only',
        bike_pose_rig='Hidden copy',bike_pose_hold='On EVE',
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
        ['world.teamshop']='Team shop',['fight.gunmode']='Gun mode',['online.modes.scoreattack']='Score attack',
        ['online.modes.fishing']='Fishing tournament',['online.modes.photohunt']='Photo hunt',
        ['world.maps.sboxion']='SBO Xion',['closet']='Stellar Closet'},
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
        spectate='You are down. Watching %s. You get up when the boss falls or reaches its next phase.',
        watching='%s is down and watching.',
        qte_you='QTE for you.',
        qte_other='QTE for %s.',
        qte_missed='%s failed the QTE. QTE for you.',
        finisher='%s finishes the boss.',
        host_down='Shared enemies: %s is down. If they respawn at a camp, the enemies you share go back to full '
            ..'health.',
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
    -- name, or fight.friend.) The return after our death: the offer and always's notice (her name, follow_key). A
    -- member in a solo area (her name, then one of places by the zone type) and back from it (her name). A member's
    -- camp rest (online/group/group.lua, %s: her name, or someone): it reset this area in our game, or did not while we
    -- were busy for a minute; then the stop after too many resets.
    group={rest="Enemies are back: the area reset in %s's game.",
        rest_guest="Shared area: only %s's camp rest brings its enemies back.",
        down='%s is down. Stand next to them for 3 s to revive them.',
        wait='%s can revive you: wait, or respawn at a camp.',
        revived='Revived by %s.',
        you_revived='You revived %s.',
        cutscene='%s is watching a cutscene. Your game waits until it ends.',
        back='%s is alive. Press %s to go back to them.',
        back_auto='Going back to %s in 5 s. Press %s to stay.',
        solo='%s is in %s. Online play waits until they are back.',
        places={training='the training room',spirit='the Matrix 11 demo room',test='a test zone',
            boss='a Boss Challenge',nikke='a NIKKE stage'},
        solo_back='%s is back.',
        rested='%s rested at a camp. The enemies of this area are back.',
        rest_skipped='%s rested at a camp. This area did not reset in your game: you were busy for a minute.',
        rest_stopped="Other players' camp rests no longer reset your area until the game restarts. UE4SS.log says why.",
        someone='A player'},
    -- The follow (online/group/travel.lua), the guest's: the offer when the host is on another map or far on hers (%s:
    -- her name, her map, follow_key), always's notice (her name, follow_key), the travel taken, no camp found, a
    -- guard of the moment, the host's last ground point missing or too old (her name), and the native part's refusal
    -- or a warp that never started.
    travel={offer='%s is in %s. Press %s to travel to them.',
        auto='Following %s in 5 s. Press %s to stay.',going='Travelling to %s.',
        none='No camp you have found is near %s.',busy='You cannot travel now. Try again in a moment.',
        air='%s is not on solid ground. Try again in a moment.',
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
    -- coop gift (cutmenus/mailbox.lua): a send that went (%d, %s: the count and the item's alias); one stopped with the
    -- items still there, with too few of them (the count carried, the alias), with the items maybe gone after the
    -- remove, with the items given back or not given back; a gift back in the inventory; her gift (%s: her name, or
    -- friend), or one to ourselves in coop loopback; our gift kept by her (the same) or by ourselves, or refused. The
    -- log keeps why.
    gift={sent="Gift sent: %d %s. It waits for your friend's answer.",failed='Gift not sent. UE4SS.log says why.',
        few='Gift not sent: you carry %d %s.',gone='Gift not sent. The items may be gone. UE4SS.log says why.',
        back='Gift not sent. The items came back. UE4SS.log says why.',
        lost='Gift not sent. The items could not be given back. UE4SS.log says why.',
        returned='Gift returned: %d %s are back in your inventory.',
        got='%s sent you %d %s: coop gift take puts them in your inventory.',
        got_self='You sent yourself %d %s: coop gift take puts them in your inventory.',kept='%s got your %d %s.',
        kept_self='You got your %d %s.',refused='Gift refused: the %d %s come back. UE4SS.log says why.',
        friend='your friend'},
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
    -- players: her card's title with the host's level (title_level, %s: one of levels, each level's word), the host's
    -- card while he waits for her answer, her notice when his countdown starts (%s his name, then his level), his
    -- notice when she cannot join (%s her name, then refuse's word), and whose EVE died (named, so no word agrees with
    -- a player's gender). earned: the points a run gave for the shop (online/modes/nightop/shop.lua), then the player's
    -- total; unpaid: a run's points that could not be credited (UE4SS.log says why).
    -- panel reads from the game when it can; why: what ended a stopped run, by its reason. A challenge (coop challenge)
    -- uses the same card, panel and end notice, with challenge's words: names, its name, the card's title in place of
    -- night.title and the %s of its notices (start, wave, clear); best, the panel's fifth row, which Night Operation
    -- shows too; record, the line under the heading after a success that wrote a new best; stopped, what ended a
    -- challenge stopped with coop challenge stop; coop_notice, her notice when the host starts a co-op challenge (the
    -- Shooting Range): its name, then his.
    night={title='NIGHT OPERATION',title_level='NIGHT OPERATION (%s)',
        levels={easy='Easy',normal='Normal',hard='Hard',nightmare='Nightmare'},
        starts='STARTS IN %d',wave='WAVE %d/%d',next='NEXT WAVE IN %d',score='SCORE %d',
        success='Operation Successful',fail='Operation Failed',died='All players have died.',time_up='Time is up.',
        why={stop='Stopped with coop nightop stop.',map='Ended by a map change or a load.',
            left='You were more than 80 m from the start for 10 s.',slot='This save is no longer a co-op save.',
            link='A Steam session started during a solo run.',
            mate='Your partner left the run.',lost='The link to your partner was lost.',
            error='Stopped by an error. UE4SS.log says why.'},
        waves='Waves cleared',kills='Kills',points='Score',time='Time',start_notice='Night Operation starts in %d s.',
        wave_notice='Night Operation: wave %d/%d.',clear_notice='Night Operation: wave %d cleared.',
        end_notice='%s: %d/%d waves cleared, %d kills, score %d, time %s.',
        waiting='WAITING FOR PARTNER',coop_notice='%s started Night Operation (%s). It begins in %d s.',
        refused='%s cannot join the run: %s.',refuse={far='more than 50 m from you',map='on another map',
        slot='not on a co-op save',busy='already in a run',near='enemies or people within 40 m',
        taken='monsters of an earlier run are still there',none='no answer'},mate_died="Your partner's EVE died.",
        you_died='Your EVE died.',
        earned='Night Operation: +%d points, %d in all.',
        unpaid='Night Operation: the points could not be saved. UE4SS.log says why.',
        booked='Night Operation starts once you leave Xion and no one is within 40 m.',
        host_only='In an online session, only the host starts Night Operation.',
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
            seat='Get up from your seat to race in the next round.',
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
            partner='End the online session first.',fight='Not during a fight.',
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
    -- stage 4) and value (val; race_ranking: the Doro race's ranking); the Leave question (pop). Outside English and
    -- French, Settings, Cancel, Difficulty, Equipment and Change are the game's own StringTable_UI words
    -- (UI_Lobby_Options, UI_Cancel, UI_Setting_GamePlay_Mode, UI_Equipment, UI_Setting_Rolling), and Search, Start and
    -- Normal Mode (UI_Interaction_T_Search, UI_BossRush_Start, UI_NormalMode) where the game's word means the same thing
    -- there.
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
            seat='Get up from your seat to play the next round.',
            night='A Night Operation run is on: you sit out this round.',
            room='You are not in the waiting room: you sit out this round.',
            refused='Your game could not start the challenge: you sit out this round. UE4SS.log says why.'},
        end_notice='%s: %s, score %d, time %s.',
        placed='Score attack: you placed %d of %d.'},
    -- The fishing tournament (online/modes/fishing/ui/board.lua): the corner board's title line (head, then the
    -- countdown, the time left or up); the result panel's heading (title), the line under it (mine: our points and
    -- fish), a ranking row's fish and its notes (waiting, unranked, best, norank); the notices: the start (start: the
    -- host's name, the minutes), why a player sits out (out: off, slot, table), why a tournament ends with no ranking
    -- (host_left, cancelled), a reloaded game (reloaded). With the UI off: GO (go: the minutes), each change of our
    -- place and points (standing), our end (end_notice: points, fish), the first three (top: their entries, each
    -- place, name and points, joined by sep) and our place (placed: ours, of how many).
    fishing={head='FISHING',count='Starts in %d',up='Time up',title='Fishing tournament',mine='%d points · %d fish',
        fish='%d fish',waiting="Waiting for the host's ranking.",unranked='Not ranked.',best='New personal best.',
        norank='No ranking came from the host.',start='%s starts a fishing tournament: %d min.',
        out={off='Fishing tournament is off in Options.',
            slot='Load a co-op save to fish in the tournament.',
            table='Could not read the fish table.'},
        host_left='The host left. This tournament has no ranking.',cancelled='The tournament was cancelled.',
        reloaded='Your game reloaded: your catches no longer count in this tournament.',
        go='Fishing tournament: start fishing. %d min left.',standing='Fishing tournament: place %d, %d points.',
        end_notice='Fishing tournament: time up, %d points, %d fish.',top='Fishing tournament: %s.',entry='%d. %s %d',
        sep=', ',placed='You placed %d of %d.'},
    -- The photo hunt (online/modes/photohunt/ui/board.lua): the card's title line (head, then the countdown, the time
    -- left or up), each target's taker (open, you or her name) and its last line (card: our points and place); the
    -- targets' names (cat, butterfly and fish with the row's number, memory); a world's name with its preposition
    -- (places: Xion, WasteLandA, WasteLandB, other with the alias); the result panel's heading (title), the line under
    -- it (points) and its notes (waiting, unranked, best, norank); the notices: the start (start: the host's name, the
    -- world, the three targets joined by sep, the minutes) and the Camera's after it (camera), a target taken (took:
    -- the taker's name and the target; you_took), why a player sits out (out: off, slot, checks), why our photo checks
    -- stopped (stopped: fault, unpinned, names), why a photo hunt ends with no ranking (host_left, cancelled), a
    -- reloaded game (reloaded), a shot's words for a drawn target once the selfie mode closes (shot: counts, yours,
    -- close with the target; taken with the target and the taker's name). With the UI off: GO (go: the minutes), our
    -- end (end_notice: our points), the first three (top: their entries, each place, name and points, joined by sep)
    -- and our place (placed: ours, of how many). one: card, points and end_notice for 1 point, with no number.
    photohunt={head='PHOTO HUNT',count='Starts in %d',up='Time up',open='open',you='you',card='%d points · place %d',
        cat='Cat %d',butterfly='Butterfly %d',fish='Fish %d',memory='Memory of Xion',
        places={Xion='in Xion',WasteLandA='in the Wasteland',WasteLandB='in the Great Desert',other='in %s'},
        title='Photo hunt',points='%d points',waiting="Waiting for the host's ranking.",unranked='Not ranked.',
        best='New personal best.',norank='No ranking came from the host.',
        start='%s starts a photo hunt %s: %s. %d min.',camera='Use the Camera to take the photos.',
        took='%s took %s.',you_took='You took %s.',
        out={off='Photo hunt is off in Options.',
            slot='Load a co-op save to play the photo hunt.',
            checks='Photo checks are off in this game.'},
        stopped={fault='Photo checks stopped in this game: restart the game to play.',
            unpinned='Photo checks are off in this game.',
            names="This game does not know this photo hunt's targets: your photos do not count."},
        host_left='The host left. This photo hunt has no ranking.',cancelled='The photo hunt was cancelled.',
        reloaded='Your game reloaded: your photos no longer count in this photo hunt.',
        shot={counts='%s counts: 1 point.',yours='%s is yours already.',taken='%s was taken by %s.',
            close='%s was in your photo: get closer, centre it and face it.'},
        one={card='1 point · place %d',points='1 point',end_notice='Photo hunt over: 1 point.'},
        go='Photo hunt: take your photos. %d min left.',end_notice='Photo hunt over: %d points.',
        top='Photo hunt: %s.',entry='%d. %s %d',sep=', ',placed='You placed %d of %d.'},
    -- The pause menu's Online tab (ui/kit/pause_tab.lua): its word and the notice when the game stays paused.
    pause_tab={tab='Online',stuck='The game stayed paused, so the co-op menu did not open.'},
    -- The emote wheel (ui/kit/wheel.lua, eve/ui/wheel.lua): its hints, the centre's word while nothing is pointed at
    -- (after StringTable_UI's UI_HUD_Gesture) and why it did not open.
    wheel={title='Social action',release='Release: play',point='Point',next='Next category',
        world='The emote wheel opens in the game world only, with no menu open.',busy='No emote now: EVE is busy.',
        native='The emote wheel needs the native part of this version.',
        off='The emote wheel is off (the UI stopped): use coop emote.'},
    -- The emote wheel's page and slot names where the game has none (the Cut clips) or gives none (ui_language),
    -- after StringTable_UI's UI_Gesture_Category_* and UI_PhotoMode_Pose_*; left and right: the two waves.
    emote={cats={greetings='Greeting',expression='Expression',orders='Orders',emotion='Emotions',pose='Pose',
        dance='Dance',cut='Cut'},
        left='%s (left)',right='%s (right)',
        names={hello='Wave',salute='Salute',kungfu='Kung fu salute',toast='Toast',clap='Clap',heart='Heart hands',
        thumbsup='Thumbs up',victory='Victory',kiss='Kiss',bringiton='Bring it on',giveme='Give me',hush='Hush',
        reach='Reach',omg='OMG',what='What?',worry='Worry',wish='Wish',wedidit='We did it',charm='Charm',
        confident='Confident',cutie='Cutie',sweetie='Sweetie',squat='Squat',stretch='Stretch',warmup='Warm-up',
        walk='Walk',shutter1='Shutter chance 1',shutter2='Shutter chance 2',shutter3='Shutter chance 3',flow='Flow',
        nataraja='Natarajasana',somersault='Somersault',chariotstruggle='Chariot struggle',
        chariotcounter='Chariot counter',chariotfail='Chariot fail',chariottakedown='Chariot takedown',
        kalitakedown='Kali takedown',kaligrab='Kali grab'}},
    -- The co-op menu's TEST TOOLS pages (eve/ui/tools.lua, cutmenus/ui/devmenu.lua, fight/bosses/ui/viewer.lua).
    tools={done='Asked of the game.',
        eve={fly='Debug flight',slowmo='Slow motion',glide='Glide'},
        dev={title='Developer menu',eve='EVE',enemies='ENEMIES NEAR EVE',panels='PANELS',nodamage='No damage',
        stealth='Hidden from enemies',speed150='Speed x1.5',speed200='Speed x2',attack5='Damage x5 (adds up)',
        attack30='Damage x30 (adds up)',gauges='Beta and Burst refill',tachy='Tachy refills',tachyfull='Fill Tachy',
        heal='Full health',hp1='Health to 1',nolockswitch='Lock-on stays off',enemynodamage='Take no damage',
        enemynoai='Stop acting',enemyimmortal='Cannot die',enemyshield1='Shield to 1',enemybalance1='Balance to 1',
        enemyclear='Clear the enemies',clear='Clear all',devinfo='Developer panel',quest='Quests',
        player='Player info'},
        viewer={title='Cut models',model='Model',part='Part',skin='Skin',show='Show',cam='Free camera',
        remove='Remove',nothing='Nothing shown',leviathan='Leviathan',gardener='Gardener',tendril='Tendril',
        mann='Mann',nier='NieR machine',orcal='Orcal prototype',enya='Enya prototype'}},
    -- Stellar Closet's menu (closet/ui/): a tab for each closet/slots.lua Slots.MENUS id, a name for each Slots.LIST
    -- slot and Slots.REGIONS region, its rows (reset: the Full tab's last row; thumbs: the one before it), detail
    -- panel, an outfit's origin (Original, or Custom and its pack), key hints (Back and Select are hint.back,
    -- hint.select), the Keep this look? and Reset Stellar Closet? popups, why it does not open (refused) and why it
    -- closed (closed), the answers of Make preview pictures (thumbs), the body switched to an outfit (switched), the
    -- regions whose skin shows on a picked body (clips), the reset done, the Colour tab's words (colour) and the Body
    -- tab's shape rows (shape). Outfit, pack, piece and morph names stay as their pack writes them.
    closet={
        beta='%s (Beta)', -- a fitting tab's label (Head..Body, Intimate): its tabs word in %s
        original='Original suits', -- Full outfit's header row above Shift Up's own suits
        tabs={head='Head',torso='Torso',arms='Arms',hips='Hips',intimate='Intimate',legs='Legs',body='Body',
            colour='Colour',weapon='Weapon',full='Full outfit'},
        slots={Face='Face',Hair='Hair',Ponytail='Ponytail',Ears='Ears',Eyes='Eyes',Makeup='Makeup',
            FaceTattoo='Face tattoo',HairAccessory='Hair accessory',Headwear='Headwear',Mask='Mask',Glasses='Glasses',
            EarringL='Earring L',EarringR='Earring R',BrowPiercing='Eyebrow piercing',NosePiercing='Nose piercing',
            SeptumPiercing='Septum piercing',LipPiercing='Lip piercing',TonguePiercing='Tongue piercing',
            TattooChest='Chest tattoo',TattooStomach='Stomach tattoo',TattooBack='Back tattoo',
            TattooShoulders='Shoulder tattoo',UndergarmentTop='Bra',Chest='Top',Outerwear='Jacket',Cape='Cape',
            Collar='Collar',Necklace='Necklace',ChestHardware='Harness',NippleL='Nipple piercing L',
            NippleR='Nipple piercing R',Navel='Navel piercing',
            TattooUpperArm='Upper arm tattoo',TattooForearm='Forearm tattoo',TattooHand='Hand tattoo',
            Fingernails='Fingernails',Gloves='Gloves',Sleeves='Sleeves',BraceletL='Bracelet L',BraceletR='Bracelet R',
            Rings='Rings',Armbands='Armbands',
            TattooHips='Hip tattoo',TattooLowerBack='Lower back tattoo',TattooButt='Buttocks tattoo',
            UndergarmentBottom='Underwear',Pants='Bottoms',Belt='Belt',Garter='Garter',
            PubicHair='Pubic hair',Anus='Anus',TattooPubic='Pubic tattoo',ClitPiercing='Clit piercing',
            LabiaPiercing='Labia piercing',AnalPlug='Anal plug',
            TattooThigh='Thigh tattoo',TattooCalf='Calf tattoo',TattooFoot='Foot tattoo',Toenails='Toenails',
            Legs='Legwear',Shoes='Shoes',ThighStraps='Thigh straps',AnkletL='Anklet L',AnkletR='Anklet R',
            BaseBody='Body',SkinSuit='Skin suit',SkinTone='Skin tone',TanLines='Tan lines',SkinShine='Skin shine',
            Dermal='Body glow',TattooFull='Full-body tattoo',Weapon='Weapon',FullOutfit='Full outfit'},
        regions={HeadNeck='Head and neck',TorsoUpper='Upper torso',TorsoLower='Lower torso',Pelvis='Pelvis',
            ArmUpper='Upper arms',Forearm='Forearms',Hand='Hands',Thigh='Thighs',Calf='Calves',Foot='Feet'},
        row={whole='Wear whole outfit',soon='Coming soon',empty='No installed outfit has a piece for this slot.',
            none='None',locked='Locked: %s is not installed.',
            broken='Locked: this piece does not load in this game version (its skeleton is missing).',reset='Reset Stellar Closet',
            clear_thumbs='Clear preview pictures',
            clear_thumbs_desc="Deletes every preview picture. The tiles show the outfits' own images again. "
                ..'Preview picture takes one again.'},
        detail={outfit='Outfit: %s',slot='Slot: %s',covers='Covers: %s',also='Also takes: %s',
            off='Hidden by default in its outfit'},
        origin={original='Original',custom='Custom: %s'},
        -- The Head tab's Hair and Ponytail rows: the None tile and an empty row (the game's own piece stays), the
        -- stock ponytails (No ponytail, long, short: the game names them only by table row), a stock hair's colour
        -- rows by parameter name, a pack ponytail tile's line.
        head={earrings='Earrings',
            own="Game's own",no_ponytail='No ponytail',
            long_ponytail='Long ponytail',short_ponytail='Short ponytail',
            colours={RootColor='Root colour',TipColor='Tip colour',DyeColor='Dye colour',
                IrisHueTint='Iris colour',ScleraTint='Sclera colour',BaseColour='Brow colour'},
            params={Brightness='Brightness',Scatter='Scatter',Roughness='Roughness',Specular='Shine',
                TipPower='Tip blend',DyeRoughness='Dye roughness',DyeScatter='Dye scatter',
                IrisHueShift='Iris hue shift',IrisBrightness='Iris brightness'},
            pack_ponytail='Pack hairs usually carry their own ponytail.',
            eyes_own='Own eyes',
            eyes_face="Eyes can only be coloured on EVE's own face. Wear the game's own face first.",
            face_rig="This face is not built on EVE's skeleton, so it may not move."},
        hints={wear='Wear',take_off='Take off',whole='Whole outfit',options='Options',change='Change',
            reset='Reset',fav='Favourite',unfav='Unfavourite',delete='Delete'},
        -- The Full outfit tab's presets and favourites (closet/presets.lua): the Save look as preset row and its line,
        -- a preset with no name, the filter row and its two values, a favourite outfit's value (its pack in %s after a
        -- lead mark: the value box cuts a long pack id at its end, so the mark stays), the
        -- notices of a save and of a save with no whole outfit, the Delete popup (the preset's name in %s).
        presets={save='Save look as preset',
            save_desc='Keeps the worn outfit, its variant and its options as a new preset. Rename it with coop closet '
                ..'preset rename.',
            name='Preset %d',filter='Show',all='All',favourites='Favourites',custom='Custom',
            filter_desc='Lists every outfit, your favourites, the original suits only or the custom outfits only.',
            fav='* %s',
            saved='Saved as %s.',none='Wear one whole outfit first: a preset keeps one outfit.',
            delete_title='Delete this preset?',delete_desc='%s is deleted. The outfit and its options stay.'},
        -- An outfit's options page (closet/options.lua): the Variant row, a piece's value, the Other section, a
        -- control row's kind and the title of one whose name differs from its piece's (the kind, then the name), the
        -- Shape section, the Reset this outfit row and its line, a colour's Pack colour value, the Custom colour's
        -- channel rows, the line on a piece with controls, the line on an outfit's row that opens the page and the
        -- help of the page's rows, on the keyboard (key) and a pad (pad).
        options={variant='Variant',on='On',off='Off',other='Other',
            kinds={finish='Finish',colour='Colour',number='Number'},named='%s: %s',
            shape='Shape',reset='Reset this outfit',pack='Pack colour',channels={r='Red',g='Green',b='Blue',a='Alpha'},
            reset_desc='Every option of this outfit goes back to its pack value. It is saved at once.',
            piece_help={key='Enter or a click shows its colours, finishes and numbers. '
                    ..'The left and right arrows turn it on or off.',
                pad='A shows its colours, finishes and numbers. D-pad Left and Right turn it on or off.'},
            open={key='Right arrow or D: this outfit\'s options (variant and pieces).',
                pad='D-pad Right: this outfit\'s options (variant and pieces).'},
            help={key='The left and right arrows or a click change it. It is saved at once.',
                pad='D-pad Left and Right change it. It is saved at once.'}},
        -- The camera's modes, its hint row's mode chip and Reset chip. title formatted with moves is the detail's
        -- camera line: the moves of each mode on the keyboard (key) and on a pad (pad).
        camera={region='Region',free='Free',title='Camera: %s',reset_hint='Reset',
            moves={region={key='I J K L or a middle drag pan the framing. A right drag or the mouse wheel goes to '
                    ..'Free mode. Light level: Shift+U / Shift+O.',
                pad='The right stick pans the framing. Light level: hold L3, then LT / RT.'},
                free={key='I J K L or a right drag orbit. Shift+I J K L or a middle drag pan. U / O or the '
                    ..'mouse wheel zoom. Light level: Shift+U / Shift+O.',
                pad='The right stick orbits. Hold X with the right stick to pan. LT / RT zoom. '
                    ..'Light level: hold L3, then LT / RT.'}}},
        -- The preview light presets and the light chip (title formatted with the preset).
        light={game='Game',studio='Studio',warm='Warm',cool='Cool',rim='Rim',title='Lighting: %s'},
        keys={mode='C',reset='Backspace',light='V',picture='P'}, -- The camera chips' keyboard keys (main/keys.lua).
        -- The camera row's Preview picture chip (closet/thumbs.lua's snap: the worn outfit as the screen shows EVE),
        -- its label on a pad (View held), the notices of a picture taken, of no whole outfit worn and of a failure.
        picture={hint='Preview picture',pad='Hold: Preview picture',saved='Preview picture saved for %s.',
            none='Wear one whole outfit first: a preview picture shows one outfit.',
            failed='The preview picture could not be taken. UE4SS.log says why.'},
        -- The Colour tab (closet/colour.lua): each role's row and what it colours, how to pick, each swatch's name.
        colour={roles={primary='Primary',secondary='Secondary',accent='Accent',glow='Glow'},
            about={primary='Main garments: tops, bottoms, bras, underwear, jackets, capes, hats and full outfits.',
                secondary='Gloves, sleeves, shoes, legwear, belts, garters, straps, bands and masks.',
                accent='Jewellery, piercings, rings, collars, glasses and hair accessories.',
                glow='The glow of body glow pieces. Its brightness stays.'},
            help='Select, left or right turns it on or off. On shows its Red, Green and Blue sliders. Off keeps the '
                ..'colours of the pack.',
            channel_help='Left and right change it. A click on the bar sets it there.',
            swatches={off='Off',white='White',black='Black',charcoal='Charcoal',silver='Silver',gold='Gold',
                crimson='Crimson',wine='Wine',rose='Rose',violet='Violet',navy='Navy',azure='Azure',teal='Teal',
                emerald='Emerald',sand='Sand'}},
        -- The Body tab's shape rows (closet/shape.lua): a value in percent, what a row changes and how to change it.
        shape={value='%d%%',
            about='Changes the shape of her body and of each worn piece made with this shape. A piece without it '
                ..'keeps its shape.',
            help='Left and right change it in steps of 10. It is saved apart from the look.'},
        popup={title='Keep this look?',desc='Yes saves it. No gives EVE the look she had before.',yes='Keep',no='Undo',
            reset_title='Reset Stellar Closet?',
            reset_desc='Every closet piece comes off EVE and the saved look is deleted. Stellar Closet changes nothing '
                ..'until you wear a look again.',
            clear_title='Clear preview pictures?',
            clear_desc='Every preview picture is deleted from the mod folder. Preview picture takes one again.'},
        refused={combat='Stellar Closet does not open in combat.',
            cutscene='Stellar Closet does not open during a cutscene.',
            photo='Stellar Closet does not open in photo mode.',tachy='Stellar Closet does not open in Tachy Mode.',
            screen='Stellar Closet does not open while a game menu is open.',
            loading='Stellar Closet does not open while a map loads.',
            panel='Stellar Closet does not open while another SBO menu is open.',
            bike='Stellar Closet does not open while EVE rides the bike.',
            doro='Stellar Closet does not open while the Doro look is on.',
            rifle='Stellar Closet does not open while the rifle is out.',
            emote='Stellar Closet does not open while an emote plays.',
            wear='Stellar Closet does not open while EVE wears a coop wear suit.',
            ui='Stellar Closet needs the menu UI. It is off or not ready yet.'},
        closed={combat='Combat started: Stellar Closet closed without saving.',
            cutscene='A cutscene started: Stellar Closet closed without saving.',
            map='The map changed: Stellar Closet closed without saving.',
            photo='Photo mode opened: Stellar Closet closed without saving.',
            input='The game took the controls back: Stellar Closet closed without saving.'},
        saved='Look saved.',failed='Could not wear this piece. UE4SS.log says why.',
        switched='Body switched to %s so no skin shows through the pieces.',
        clips='Skin of this body shows through the pieces on: %s.',
        thumbs={cleared='Every preview picture is deleted.',
            busy='Preview pictures are being made. Clear them once that is done.',
            failed='The preview pictures could not be deleted. UE4SS.log says why.'},
        reset_done='Stellar Closet is reset. EVE wears her own look.'},
    -- SBO Xion's NPCs (world/maps/sboxion/npcs/npcs.lua): says is the line with its speaker (%s the name, %s the
    -- words), then each NPC's name and what it says when EVE comes close.
    xion={says='%s: %s',repairer='Repairer',
        repairer_hello='If it hums or throws sparks, bring it over. I can usually get it running again.',
        plate_gate_guard='Gate guard',plate_gate_guard_hello='You came down the arch stair? Then you found us.',
        plate_storyteller='Storyteller',plate_storyteller_hello='Before the city was hung here, this was all falling air.',
        plate_porter='Porter',plate_porter_hello='Everything that comes down, comes down that stair.',
        plate_welder='Welder',plate_welder_hello='Stand back from the sparks.',
        plate_stall_keeper_1='Stall keeper',plate_stall_keeper_1_hello='Fresh from the upper streets.',
        plate_stall_keeper_2='Stall keeper',plate_stall_keeper_2_hello='Cells, cable, anything that still works.',
        plate_stall_keeper_3='Cook',plate_stall_keeper_3_hello='Find yourself a seat and I\'ll be right with you.',
        plate_resident_a='Resident',plate_resident_a_hello='Come in if you like. Just keep clear of the dartboard.',
        plate_mechanic='Mechanic',plate_mechanic_hello='Bring me what the upper streets threw away.',
        plate_resident_b='Resident',plate_resident_b_hello='We came down when the stairs were finished.'},
}
