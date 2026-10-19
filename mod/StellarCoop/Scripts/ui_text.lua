-- The co-op menu's, the chat's, the partner HUD's and the co-op saves' words (D-UI8): English and French. The game's language picks them
-- (GetCurrentLanguage, as the recruiter reads it) unless ui_language=english; any other language reads English until
-- translated. Row ids and setting names are ui_model.lua's; a value's word is its id's (on, both, game...).
local T={}
T.en={
    title='CO-OP',
    head={session='SESSION',settings='SETTINGS',help='HELP',controls='CONTROLS',photo='PHOTO MODE',partner='PARTNER',
        ghost='GHOST',saves='SAVES',combat='COMBAT',display='DISPLAY',chat='CHAT'},
    row={host='Host a session',leave='Leave the session',invite='Invite a friend (Steam)',join='Join a friend',
        chat='Chat',options='Options',report='Write a bug report',close='Close',
        menu_key='Open this menu',host_key='Host at once',status_key='Show the status',leave_key='Leave the session',
        photo_sync='Photo sync',photo_freeze_max='Longest pause',photo_ghost='Ghost in my photos',
        photo_name_tag='Name tag in my photos',name_tag='Name tag',cloth='Ponytail cloth',dyes='Outfit colours',
        effects='Attack effects',send_rate='Poses sent a second',shared_enemies='Shared enemies (experimental)',
        ui_scale='Menu size',ui_sounds='Menu sounds',ui_language='Menu language',partner_bar='HP marker',
        partner_arrow='Off-screen arrow',partner_card='Partner card',card_details='Ping and map on the card',
        who_can_join='Who can join',auto_coop_save='Co-op saves'},
    value={on='On',off='Off',both='Both',notice='Notice only',game='Game language',english='English',friends='Friends',
        private='Invited only',ask='Ask',always='Always'},
    no_limit='No limit',minutes='%d min',seconds='%d s',percent='%d %%',press='Press a key',
    hint={move='Move',select='Select',back='Back'},
    confirm_leave='Select again within 3 s to leave.',
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
    -- The question at the title (saves.lua), its notices, and the one in a session on your own save.
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
        off='Co-op saves off for this load: %s. You play your own saves.',
        session='You play your own save, and shared enemies run on co-op saves only. Quit to the title to switch; the '
            ..'ghost works now.'},
}
T.fr={
    title='CO-OP',
    head={session='SESSION',settings='RÉGLAGES',help='AIDE',controls='TOUCHES',photo='MODE PHOTO',partner='PARTENAIRE',
        ghost='FANTÔME',saves='SAUVEGARDES',combat='COMBAT',display='AFFICHAGE',chat='DISCUSSION'},
    row={host='Héberger une session',leave='Quitter la session',invite='Inviter un ami (Steam)',
        join='Rejoindre un ami',chat='Discussion',options='Options',report='Écrire un rapport de bug',close='Fermer',
        menu_key='Ouvrir ce menu',host_key='Héberger directement',status_key="Afficher l'état",
        leave_key='Quitter la session',photo_sync='Photo synchronisée',photo_freeze_max='Pause la plus longue',
        photo_ghost='Fantôme sur mes photos',photo_name_tag='Nom sur mes photos',name_tag='Nom au-dessus',
        cloth='Queue de cheval',dyes='Couleurs de tenue',effects="Effets d'attaque",
        send_rate='Poses envoyées par seconde',shared_enemies='Ennemis partagés (expérimental)',
        ui_scale='Taille du menu',ui_sounds='Sons du menu',ui_language='Langue du menu',partner_bar='Marqueur de vie',
        partner_arrow='Flèche hors écran',partner_card='Fiche du partenaire',card_details='Ping et zone sur la fiche',
        who_can_join='Qui peut rejoindre',auto_coop_save='Sauvegardes co-op'},
    value={on='Oui',off='Non',both='Les deux',notice='Avis seul',game='Langue du jeu',english='Anglais',friends='Amis',
        private='Sur invitation',ask='Demander',always='Toujours'},
    no_limit='Sans limite',minutes='%d min',seconds='%d s',percent='%d %%',press='Appuyez sur une touche',
    hint={move='Déplacer',select='Choisir',back='Retour'},
    confirm_leave='Choisissez encore dans les 3 s pour quitter.',
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
        off='Sauvegardes co-op inactives pour ce chargement : %s. Vous jouez sur vos propres sauvegardes.',
        session='Vous jouez sur votre propre sauvegarde, et les ennemis partagés ne fonctionnent que sur les '
            .."sauvegardes co-op. Revenez à l'écran titre pour changer ; le fantôme fonctionne déjà."},
}
-- The words for the game's culture (nil when unread) and ui_language.
function T.pick(culture,setting)
    if setting~='english' and type(culture)=='string' and culture:lower():find('^fr') then return T.fr end
    return T.en
end
return T
