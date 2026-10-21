-- The co-op menu's, the chat's, the partner HUD's, the co-op saves', the join codes', the shared enemies', same
-- place's, same spawns', the status line's and the notices' words that the Lua side writes (D-UI8): English and French.
-- The game's language picks them (GetCurrentLanguage, as the recruiter reads it) unless ui_language=english; any other
-- language reads English until translated. Row ids and setting names are ui_model.lua's; a value's word is its id's
-- (on, both, game...), or <setting>_<id> where one setting's value needs other words (aggro_game).
local T={}
T.en={
    title='CO-OP',
    head={session='SESSION',settings='SETTINGS',help='HELP',controls='CONTROLS',photo='PHOTO MODE',partner='PARTNER',
        ghost='GHOST',saves='SAVES',combat='COMBAT',display='DISPLAY',chat='CHAT'},
    row={host='Host a session',leave='Leave the session',invite='Invite a friend (Steam)',join='Join a friend',
        copy='Copy my code',remove='Remove %s',join_code='Join with a code',
        chat='Chat',options='Options',report='Write a bug report',close='Close',
        menu_key='Open this menu',host_key='Host at once',status_key='Show the status',leave_key='Leave the session',
        photo_sync='Photo sync',photo_freeze_max='Longest pause',photo_ghost='Ghost in my photos',
        photo_name_tag='Name tag in my photos',name_tag='Name tag',cloth='Ponytail cloth',dyes='Outfit colours',
        effects='Attack effects',send_rate='Poses sent a second',shared_enemies='Shared enemies (experimental)',
        ui_scale='Menu size',ui_sounds='Menu sounds',ui_language='Menu language',partner_bar='HP marker',
        partner_arrow='Off-screen arrow',partner_card='Partner card',card_details='Ping and map on the card',
        who_can_join='Who can join',auto_coop_save='Co-op saves',enemy_hp_scale="Enemy HP (host's)",
        enemy_balance_scale="Enemy balance (host's)",kill_credit='My kill rewards',
        same_place='Same place (experimental)',aggro="Enemies attack (host's)",
        same_spawns='Same spawns (experimental)',enemy_extra="Extra enemies (host's)"},
    value={on='On',off='Off',both='Both',notice='Notice only',game='Game language',english='English',friends='Friends',
        code='With a code',private='Invited only',ask='Ask',always='Always',all='Every shared enemy',
        fought='Enemies I hit',aggro_game='Both players',aggro_host='The host only'},
    no_limit='No limit',minutes='%d min',seconds='%d s',percent='%d %%',press='Press a key',
    hint={move='Move',select='Select',back='Back'},
    confirm_leave='Select again within 3 s to leave.',confirm_remove='Select again within 3 s to remove %s.',
    reload='Saved. It takes effect when the mod reloads (game start or Ctrl+R).',
    capture='Press F1 to F12, with Shift, Ctrl or Alt if you like. Esc cancels.',
    clash='%s already uses this key.',f10='F10 opens the console.',
    keys='Use F1 to F12, with at most one of Shift, Ctrl, Alt.',
    unreadable='Not saved: coop-settings.txt cannot be read.',not_saved='Not saved: %s',
    report='The bug report goes to coop-report.txt in the mod folder.',
    chat={you='You',partner='Partner',said='%s: ',hint='Message · Enter to send · Esc to close',
        no_session='Chat needs a session.',off='Chat is off (Options > Chat).',not_sent=' (not sent)',
        ui_off='The chat box is off (the UI stopped, see UE4SS.log).'},
    partner={partner='Partner',down='DOWN',lost='connection lost',elsewhere='elsewhere · %s'},
    -- The code box and the host's question (join.lua).
    join={title='JOIN WITH A CODE',hint='XXX-XXXX',join='Join',cancel='Cancel',
        bad='A join code is 7 letters and digits, like XXX-XXXX.'},
    ask={title='%s wants to join',someone='A player',accept='Accept',deny='Deny',
        about='Not on your Steam friends list. Denied in %d s if you do not answer.'},
    -- The question at the title (saves.lua) and its notices.
    saves={title='CO-OP SAVES',new='Play co-op on copies of your saves?',
        new_about='StellarCoop copies your saves to separate co-op files, and Continue and Load Game then use those '
            ..'copies. Your own saves are not changed.',
        old='Play co-op on your co-op saves?',
        old_about='Continue and Load Game then use your co-op copies. Your own saves are not changed.',
        convert='Convert and play co-op',play='Play co-op',solo='Play solo normally',later='Decide later',
        always="Don't ask again",always_value='Always co-op',
        switching='Switching to the co-op saves.',copying='Making the co-op copies: step %d of %d.',
        failed='The co-op saves could not be switched on. Your own saves were not changed.',
        see_log='coop-link.log says why',
        on='Co-op saves on: you play co-op copies of your saves. Your own saves are not changed.',
        off='Co-op saves off for this load: %s. You play your own saves.'},
    -- The status line (link.lua's summary(): under the menu, and the status key's notice); %s: her Steam name, or
    -- friend.
    summary={stopped='Co-op: the Steam link stopped; coop status says why.',waiting='Co-op: waiting for Steam.',
        held='Co-op: invite held until your save has loaded.',rejoin="Co-op: rejoining your friend's game (try %s/3).",
        none='Co-op: not in a session.',alone='Co-op: hosting, no friend yet.',connecting='Co-op: %s is connecting.',
        friend='your friend',hosting='Co-op: hosting %s.',guest="Co-op: in %s's game.",paused=' Paused by %s.',
        lost=' Connection lost.'},
    -- Why the menu key did not open the menu (menu.lua).
    refused={off='The co-op menu is off (the UI stopped, see UE4SS.log): use the coop commands.',
        world='The co-op menu opens in the game world only.',
        paused='The co-op menu does not open while the game is paused or shows a menu.'},
    -- The ghost's notices (puppet.lua): her name, her map, yours.
    ghost={failed='Ghost failed 3 times: the reason is in UE4SS.log.',away='%s is in %s, you are in %s.'},
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
        paks='%s loads other .pak mods than you (%d there, %d here). Enemies that differ stay unshared.'},
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
}
T.fr={
    title='CO-OP',
    head={session='SESSION',settings='RÉGLAGES',help='AIDE',controls='TOUCHES',photo='MODE PHOTO',partner='PARTENAIRE',
        ghost='FANTÔME',saves='SAUVEGARDES',combat='COMBAT',display='AFFICHAGE',chat='DISCUSSION'},
    row={host='Héberger une session',leave='Quitter la session',invite='Inviter un ami (Steam)',
        join='Rejoindre un ami',copy='Copier mon code',remove='Retirer %s',join_code='Rejoindre avec un code',
        chat='Discussion',options='Options',report='Écrire un rapport de bug',close='Fermer',
        menu_key='Ouvrir ce menu',host_key='Héberger directement',status_key="Afficher l'état",
        leave_key='Quitter la session',photo_sync='Photo synchronisée',photo_freeze_max='Pause la plus longue',
        photo_ghost='Fantôme sur mes photos',photo_name_tag='Nom sur mes photos',name_tag='Nom au-dessus',
        cloth='Queue de cheval',dyes='Couleurs de tenue',effects="Effets d'attaque",
        send_rate='Poses envoyées par seconde',shared_enemies='Ennemis partagés (expérimental)',
        ui_scale='Taille du menu',ui_sounds='Sons du menu',ui_language='Langue du menu',partner_bar='Marqueur de vie',
        partner_arrow='Flèche hors écran',partner_card='Fiche du partenaire',card_details='Ping et zone sur la fiche',
        who_can_join='Qui peut rejoindre',auto_coop_save='Sauvegardes co-op',enemy_hp_scale='PV des ennemis (hôte)',
        enemy_balance_scale='Équilibre des ennemis (hôte)',kill_credit='Mes récompenses',
        same_place='Même position (expérimental)',aggro='Les ennemis attaquent (hôte)',
        same_spawns='Mêmes apparitions (expérimental)',enemy_extra='Ennemis en plus (hôte)'},
    value={on='Oui',off='Non',both='Les deux',notice='Avis seul',game='Langue du jeu',english='Anglais',friends='Amis',
        code='Avec un code',private='Sur invitation',ask='Demander',always='Toujours',all='Tous les ennemis partagés',
        fought='Ceux que je frappe',aggro_game='Les deux joueurs',aggro_host="L'hôte seulement"},
    no_limit='Sans limite',minutes='%d min',seconds='%d s',percent='%d %%',press='Appuyez sur une touche',
    hint={move='Déplacer',select='Choisir',back='Retour'},
    confirm_leave='Choisissez encore dans les 3 s pour quitter.',
    confirm_remove='Choisissez encore dans les 3 s pour retirer %s.',
    reload='Enregistré. Pris en compte au rechargement du mod (lancement du jeu ou Ctrl+R).',
    capture='Appuyez sur F1 à F12, avec Maj, Ctrl ou Alt si vous voulez. Échap annule.',
    clash='%s utilise déjà cette touche.',f10='F10 ouvre la console.',
    keys="Utilisez F1 à F12, avec au plus l'une de Maj, Ctrl, Alt.",
    unreadable='Non enregistré : coop-settings.txt est illisible.',not_saved='Non enregistré : %s',
    report='Le rapport de bug va dans coop-report.txt, dans le dossier du mod.',
    chat={you='Vous',partner='Partenaire',said='%s : ',hint='Message · Entrée pour envoyer · Échap pour fermer',
        no_session='La discussion demande une session.',off='La discussion est coupée (Options > Discussion).',
        not_sent=' (non envoyé)',
        ui_off="La zone de discussion est coupée (l'interface s'est arrêtée, voir UE4SS.log)."},
    partner={partner='Partenaire',down='À TERRE',lost='connexion perdue',elsewhere='ailleurs · %s'},
    join={title='REJOINDRE AVEC UN CODE',hint='XXX-XXXX',join='Rejoindre',cancel='Annuler',
        bad='Un code compte 7 lettres et chiffres, comme XXX-XXXX.'},
    ask={title='%s veut rejoindre la partie',someone='Un joueur',accept='Accepter',deny='Refuser',
        about='Pas dans vos amis Steam. Refusé dans %d s si vous ne répondez pas.'},
    saves={title='SAUVEGARDES CO-OP',new='Jouer en co-op sur des copies de vos sauvegardes ?',
        new_about='StellarCoop copie vos sauvegardes dans des fichiers co-op séparés, et la partie que vous chargez '
            ..'ensuite est une de ces copies. Vos propres sauvegardes ne changent pas.',
        old='Jouer en co-op sur vos sauvegardes co-op ?',
        old_about='La partie que vous chargez ensuite est une de vos copies co-op. Vos propres sauvegardes ne changent '
            ..'pas.',
        convert='Convertir et jouer en co-op',play='Jouer en co-op',solo='Jouer en solo normalement',
        later='Décider plus tard',always='Ne plus demander',always_value='Toujours co-op',
        switching='Passage aux sauvegardes co-op.',copying='Copie des sauvegardes co-op : étape %d sur %d.',
        failed="Les sauvegardes co-op n'ont pas pu être activées. Vos propres sauvegardes n'ont pas changé.",
        see_log='coop-link.log dit pourquoi',
        on='Sauvegardes co-op actives : vous jouez sur des copies co-op de vos sauvegardes. Vos propres sauvegardes '
            ..'ne changent pas.',
        off='Sauvegardes co-op inactives pour ce chargement : %s. Vous jouez sur vos propres sauvegardes.'},
    summary={stopped="Co-op : le lien Steam s'est arrêté ; coop status dit pourquoi.",
        waiting='Co-op : en attente de Steam.',held='Co-op : invitation en attente du chargement de votre sauvegarde.',
        rejoin='Co-op : reconnexion à la partie de votre partenaire (essai %s/3).',
        none='Co-op : aucune session en cours.',alone="Co-op : vous hébergez, personne n'a encore rejoint.",
        connecting='Co-op : %s se connecte.',friend='votre partenaire',hosting='Co-op : vous hébergez %s.',
        guest='Co-op : dans la partie de %s.',paused=' Jeu mis en pause par %s.',lost=' Connexion perdue.'},
    refused={off="Le menu co-op est coupé (l'interface s'est arrêtée, voir UE4SS.log) : utilisez les commandes coop.",
        world="Le menu co-op ne s'ouvre que dans le monde du jeu.",
        paused="Le menu co-op ne s'ouvre pas quand le jeu est en pause ou affiche un menu."},
    ghost={failed='Le fantôme a échoué 3 fois : la raison est dans UE4SS.log.',away='%s est dans %s, vous êtes dans %s.'},
    fight={on='Ennemis partagés actifs : %d ennemis liés.',one='Ennemis partagés actifs : 1 ennemi lié.',
        scale="PV des ennemis %d %%, équilibre %d %% (réglage de l'hôte).",
        off='Ennemis partagés coupés. coop-link.log dit pourquoi.',
        stopped="Ennemis partagés arrêtés jusqu'au redémarrage du jeu. coop-link.log dit pourquoi.",
        friend='votre partenaire',
        you="Les ennemis partagés demandent une sauvegarde co-op, pas la vôtre. À l'écran titre, choisissez Convertir "
            ..'et jouer en co-op (ou Jouer en co-op), puis Continuer ou chargez le même emplacement.',
        you_manual='Les ennemis partagés demandent une sauvegarde co-op, pas la vôtre. Avec les copies co-op coupées, '
            .."seul l'emplacement co-op manuel compte (voir INSTALL.md).",
        her_save="Ennemis partagés en attente : %s joue sur sa propre sauvegarde. Le passage se fait à l'écran titre "
            ..'avec Convertir et jouer en co-op (ou Jouer en co-op).',
        her_off='Ennemis partagés en attente : ils sont coupés chez %s (menu co-op, Options, Combat).',
        her_stopped='Ennemis partagés arrêtés pour cette partie chez %s. Son coop-link.log dit pourquoi.',
        map="Ennemis partagés en attente : vous et %s n'êtes pas sur la même zone.",
        maxhp="Ennemis partagés : certains ennemis ont d'autres PV max dans la partie de %s (autre difficulté ou New "
            ..'Game+). Ils ne sont pas partagés.',
        host_down='Ennemis partagés : %s est à terre. Après sa réapparition, vos ennemis partagés reviennent à pleine '
            ..'santé.',
        paks="%s n'a pas les mêmes mods .pak que vous (%d en face, %d ici). Les ennemis qui diffèrent ne sont pas "
            ..'partagés.'},
    pilot={on='Même position : %d ennemis pilotés.',one='Même position : 1 ennemi piloté.',
        off='Même position coupée : %s',host="la partie de %s l'a désactivée.",
        stopped="arrêtée par une erreur jusqu'au redémarrage du jeu. coop-link.log dit pourquoi."},
    spawns={host="Mêmes apparitions actives : là où vous et %s êtes à moins de 100 m l'un de l'autre dans une même "
            ..'zone, sa partie a les mêmes ennemis communs que la vôtre.',
        guest="Mêmes apparitions actives : là où vous et %s êtes à moins de 100 m l'un de l'autre dans une même "
            ..'zone, votre partie a les mêmes ennemis communs que la sienne.',
        stopped="Mêmes apparitions arrêtées par une erreur jusqu'au redémarrage du jeu. coop-link.log dit pourquoi.",
        differ='Mêmes apparitions : certains ennemis diffèrent entre votre partie et celle de %s (autres mods .pak ou '
            ..'fight_chars) et restent tels quels. coop-link.log les nomme.'},
}
-- The words for the game's culture (nil when unread) and ui_language.
function T.pick(culture,setting)
    if setting~='english' and type(culture)=='string' and culture:lower():find('^fr') then return T.fr end
    return T.en
end
return T
