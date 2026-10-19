-- The co-op menu's, the chat's and the partner HUD's words (D-UI8): English and French. The game's language picks them
-- (GetCurrentLanguage, as the recruiter reads it) unless ui_language=english; any other language reads English until
-- translated. Row ids and setting names are ui_model.lua's; a value's word is its id's (on, both, game...).
local T={}
T.en={
    title='CO-OP',
    head={session='SESSION',settings='SETTINGS',help='HELP',controls='CONTROLS',photo='PHOTO MODE',partner='PARTNER',
        ghost='GHOST',combat='COMBAT',display='DISPLAY',chat='CHAT'},
    row={host='Host a session',leave='Leave the session',invite='Invite a friend (Steam)',join='Join a friend',
        chat='Chat',options='Options',report='Write a bug report',close='Close',
        menu_key='Open this menu',host_key='Host at once',status_key='Show the status',leave_key='Leave the session',
        photo_sync='Photo sync',photo_freeze_max='Longest pause',photo_ghost='Ghost in my photos',
        photo_name_tag='Name tag in my photos',name_tag='Name tag',cloth='Ponytail cloth',dyes='Outfit colours',
        effects='Attack effects',send_rate='Poses sent a second',shared_enemies='Shared enemies (experimental)',
        ui_scale='Menu size',ui_sounds='Menu sounds',ui_language='Menu language',partner_bar='HP marker',
        partner_arrow='Off-screen arrow',partner_card='Partner card',card_details='Ping and map on the card'},
    value={on='On',off='Off',both='Both',notice='Notice only',game='Game language',english='English'},
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
}
T.fr={
    title='CO-OP',
    head={session='SESSION',settings='RÉGLAGES',help='AIDE',controls='TOUCHES',photo='MODE PHOTO',partner='PARTENAIRE',
        ghost='FANTÔME',combat='COMBAT',display='AFFICHAGE',chat='DISCUSSION'},
    row={host='Héberger une session',leave='Quitter la session',invite='Inviter un ami (Steam)',
        join='Rejoindre un ami',chat='Discussion',options='Options',report='Écrire un rapport de bug',close='Fermer',
        menu_key='Ouvrir ce menu',host_key='Héberger directement',status_key="Afficher l'état",
        leave_key='Quitter la session',photo_sync='Photo synchronisée',photo_freeze_max='Pause la plus longue',
        photo_ghost='Fantôme sur mes photos',photo_name_tag='Nom sur mes photos',name_tag='Nom au-dessus',
        cloth='Queue de cheval',dyes='Couleurs de tenue',effects="Effets d'attaque",
        send_rate='Poses envoyées par seconde',shared_enemies='Ennemis partagés (expérimental)',
        ui_scale='Taille du menu',ui_sounds='Sons du menu',ui_language='Langue du menu',partner_bar='Marqueur de vie',
        partner_arrow='Flèche hors écran',partner_card='Fiche du partenaire',card_details='Ping et zone sur la fiche'},
    value={on='Oui',off='Non',both='Les deux',notice='Avis seul',game='Langue du jeu',english='Anglais'},
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
}
-- The words for the game's culture (nil when unread) and ui_language.
function T.pick(culture,setting)
    if setting~='english' and type(culture)=='string' and culture:lower():find('^fr') then return T.fr end
    return T.en
end
return T
