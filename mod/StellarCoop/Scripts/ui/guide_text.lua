-- The first-launch guide's words (ui/guide.lua) and its co-op menu row's (ui/menu.lua), kept apart from ui/text.lua.
-- G.en is English: nine pages, each a title and a body (\n starts a new line), then the rows, the page line and the
-- menu row. Another language's table sits under the culture name ui/text.lua gives it (G.fr, G['zh-Hans']...), with
-- G.en's keys at every level and ui/text.lua's words for what the guide names: the menu's rows and values, Night
-- Operation (night.title) and the Doro race (race.title). Keys, console commands, file names and the Discord address
-- are inside the strings and stay as written in every language, but for Space, Ctrl, Shift and Enter where the
-- language's keyboard names them its own way, as ui/text.lua writes Strg, Maiusc and Invio. The game's language picks
-- the table (G.pick, as T.pick) unless ui_language=english; a language with no table, or a word missing from one (a
-- page included), reads English.
local G={}
G.en={
    pages={
        {title='Welcome to Stellar Blade Online',
         body="Stellar Blade Online lets a friend's EVE join your world over Steam. A session holds 2 players for "
            ..'now. The goal is 100 players.\nOpen this guide again at any time from the co-op menu (F5).'},
        {title='Play together',
         body='Press F5 in the world to open the co-op menu (hold View on a controller). Its first row, Host a '
            ..'session, opens the Steam invite window.\nSomeone who is not on your Steam friends list can join with '
            ..'a code. Before you host, set Who can join to With a code in the Options. Then send them the '
            ..'7-character code from Copy my code. You accept them when they join.\nF6: status\nF8: leave the '
            ..'session\nEnter: chat\nAt a camp phone booth, F5 opens the co-op line instead of the menu.'},
        {title='Co-op saves',
         body='Shared enemies, shared quests, Night Operation, Doro races and Leviathan run on co-op saves. These '
            ..'are copies of your saves made by the mod. It never writes to your own save files and backs them up '
            ..'before the first copy.\nOn the title screen you pick co-op (the copies) or solo (your own saves).'},
        {title='A shared world',
         body='On the same map, common enemies have one HP bar for both of you and die on both screens at once. '
            ..'They stand in the same spot in both games and go after whoever hit them last. Bosses share their HP '
            ..'and their phases.\nBy default a kill counts for you if you fought or stood within 30 m.\nWhile the '
            .."host watches a cutscene, the guest's game waits. Shared quests and revives by your friend are off "
            ..'by default. Turn them on in the Options.'},
        {title='Night Operation',
         body='Night Operation is a wave survival mode that Shift Up cut before release. A run has five timed '
            ..'waves. When the host starts it during a session, you share the timer and the score. Points from a '
            ..'run buy items.\nType these in the console (F10 or ~) on a co-op save:\ncoop nightop start: start a '
            ..'run\ncoop nightop shop: list the items\ncoop nightop buy <n>: buy item n\ncoop challenge: four graded '
            ..'challenges'},
        {title='Doro races',
         body='In a Doro race both EVEs turn into Doro. Record a track first, then race on it:\ncoop race record '
            ..'<name>: start recording\nF9: add a checkpoint where you stand\ncoop race save: save the track\ncoop '
            ..'race start <name>: start the race (co-op save)\nThe race starts after a countdown. After GO, Doro '
            ..'handles like a car and speeds up over time. R2 or the B key drifts. Steering hard at speed drifts '
            ..'too. The ranking shows at the end.'},
        {title='Leviathan and the free camera',
         body='Leviathan is a Naytiba cut from the game. On a co-op save, coop leviathan show places it in front '
            ..'of you and starts a free camera for filming. coop leviathan off removes both.\nW A S D or Z Q S D: '
            ..'fly\nSpace or E: up\nCtrl or C: down\nShift: faster\nMouse: look around'},
        {title='Settings',
         body='The Options page of the co-op menu sets the keys, the partner HUD, who can join, the co-op saves, '
            .."the combat rules, the menu's size and its sounds. The values are stored in coop-settings.txt.\nSet "
            ..'Menu language to English to read the mod in English.'},
        {title='Help',
         body='Ask questions or find a co-op partner on the Discord: discord.gg/tvFApEEVfj\nTo report a bug, close '
            ..'the game. Before you start it again, send coop-report.txt, coop-link.log and UE4SS.log.\nMother '
            ..'Sphere art by timediffer24.'},
    },
    -- The rows, the page line (the page's number, then how many) and the co-op menu's row.
    next='Next',back='Back',close='Close',never="Don't show again",page='Page %d of %d',row='Guide',
}
G.fr={
    pages={
        {title='Bienvenue dans Stellar Blade Online',
         body="Stellar Blade Online permet à l'EVE d'un ami de rejoindre votre monde via Steam. Une session "
            .."accueille 2 joueurs pour l'instant. Le but est d'atteindre 100 joueurs.\nRouvrez ce guide à tout "
            ..'moment depuis le menu co-op (F5).'},
        {title='Jouer ensemble',
         body='Dans le monde du jeu, appuyez sur F5 pour ouvrir le menu co-op (maintenez View à la manette). Sa '
            .."première ligne, Héberger une session, ouvre la fenêtre d'invitation Steam.\nUne personne absente de "
            .."votre liste d'amis Steam peut rejoindre avec un code. Avant d'héberger, réglez Qui peut rejoindre sur "
            ..'Avec un code dans les Options. Envoyez-lui ensuite le code de 7 caractères donné par Copier mon code. '
            .."Vous l'acceptez à son arrivée.\nF6 : état\nF8 : quitter la session\nEnter : discussion\nÀ une cabine "
            ..'téléphonique de camp, F5 ouvre la ligne co-op au lieu du menu.'},
        {title='Sauvegardes co-op',
         body="Les ennemis partagés, les quêtes partagées, l'opération nocturne, les courses de Doro et Leviathan "
            ..'fonctionnent sur des sauvegardes co-op. Ce sont des copies de vos sauvegardes faites par le mod. Il '
            .."n'écrit jamais dans vos propres fichiers de sauvegarde et en fait une copie de secours avant la "
            .."première conversion.\nÀ l'écran titre, vous choisissez le co-op (les copies) ou le solo (vos propres "
            ..'sauvegardes).'},
        {title='Un monde partagé',
         body='Sur la même carte, les ennemis communs ont une seule barre de PV pour vous deux et meurent en même '
            ..'temps sur les deux écrans. Ils se tiennent au même endroit dans les deux parties et attaquent celui '
            ..'qui les a frappés en dernier. Les boss partagent leurs PV et leurs phases.\nPar défaut, un ennemi tué '
            .."compte pour vous si vous l'avez combattu ou si vous étiez à moins de 30 m.\nQuand l'hôte regarde une "
            .."cinématique, la partie de l'invité attend. Par défaut, les quêtes partagées sont coupées et votre "
            ..'partenaire ne peut pas vous relever. Les deux se règlent dans les Options.'},
        {title='Opération nocturne',
         body="L'opération nocturne est un mode de survie par vagues que Shift Up a retiré avant la sortie. Une "
            .."opération compte cinq vagues chronométrées. Quand l'hôte la lance pendant une session, vous partagez "
            .."le chrono et le score. Les points d'une opération servent à acheter des objets.\nTapez ces commandes "
            ..'dans la console (F10 ou ~) sur une sauvegarde co-op :\ncoop nightop start : lancer une '
            .."opération\ncoop nightop shop : lister les objets\ncoop nightop buy <n> : acheter l'objet n\ncoop "
            ..'challenge : quatre défis notés'},
        {title='Courses de Doro',
         body="Dans une course de Doro, les deux EVE se changent en Doro. Enregistrez d'abord un circuit, puis "
            .."faites la course dessus :\ncoop race record <name> : lancer l'enregistrement\nF9 : poser un point de "
            ..'contrôle là où vous êtes\ncoop race save : enregistrer le circuit\ncoop race start <name> : lancer la '
            ..'course (sauvegarde co-op)\nLa course part après un compte à rebours. Ensuite, Doro se conduit comme '
            ..'une voiture et prend de la vitesse avec le temps. R2 ou la touche B fait déraper. Braquer fort à '
            .."grande vitesse fait aussi déraper. Le classement s'affiche à la fin."},
        {title='Leviathan et la caméra libre',
         body='Leviathan est un Naytiba retiré du jeu. Sur une sauvegarde co-op, coop leviathan show le place devant '
            ..'vous et lance une caméra libre pour filmer. coop leviathan off retire les deux.\nW A S D ou Z Q S D : '
            ..'voler\nSpace ou E : monter\nCtrl ou C : descendre\nShift : plus vite\nSouris : regarder autour'},
        {title='Réglages',
         body="La page Options du menu co-op règle les touches, l'affichage du partenaire, qui peut rejoindre, les "
            ..'sauvegardes co-op, les règles de combat, la taille du menu et ses sons. Les valeurs sont enregistrées '
            ..'dans coop-settings.txt.\nRéglez Langue du menu sur Anglais pour lire le mod en anglais.'},
        {title='Aide',
         body='Posez vos questions ou trouvez un partenaire de co-op sur le Discord : discord.gg/tvFApEEVfj\nPour '
            ..'signaler un bug, fermez le jeu. Avant de le relancer, envoyez coop-report.txt, coop-link.log et '
            ..'UE4SS.log.\nIllustration de Mother Sphere par timediffer24.'},
    },
    next='Suivant',back='Retour',close='Fermer',never='Ne plus afficher',page='Page %d sur %d',row='Guide',
}
G.ar={
    pages={
        {title='مرحبًا بك في Stellar Blade Online',
         body='يتيح Stellar Blade Online لـ EVE صديقك الانضمام إلى عالمك عبر Steam. تتسع الجلسة حاليًا للاعبَين اثنين. '
            ..'والهدف هو 100 لاعب.\nيمكنك فتح هذا الدليل مجددًا في أي وقت من قائمة اللعب التعاوني (F5).'},
        {title='اللعب معًا',
         body='اضغط F5 في عالم اللعبة لفتح قائمة اللعب التعاوني (أو اضغط مطولًا على View في يد التحكم). الخيار الأول، '
            ..'"استضافة جلسة"، يفتح نافذة دعوات Steam.\nيمكن لمن ليس في قائمة أصدقائك على Steam الانضمام برمز. قبل '
            ..'الاستضافة، اضبط "من يمكنه الانضمام" على "برمز الانضمام" في "الخيارات". ثم استخدم "نسخ رمز الانضمام" '
            ..'وأرسل إليه الرمز المكوّن من 7 أحرف وأرقام. وعندما يحاول الانضمام، اقبل طلبه.\nF6: الحالة\nF8: مغادرة '
            ..'الجلسة\nEnter: الدردشة\nعند كشك الهاتف في المخيم، يفتح F5 خط اللعب التعاوني بدلًا من القائمة.'},
        {title='ملفات الحفظ التعاونية',
         body='تعمل مشاركة الأعداء ومشاركة المهام والتشغيل الليلي وسباقات دورو وLeviathan على ملفات الحفظ التعاونية. '
            ..'وهي نسخ من ملفات حفظك يصنعها التعديل. لا يكتب التعديل أبدًا في ملفات حفظك الأصلية، ويأخذ نسخة احتياطية '
            ..'منها قبل أول نسخ.\nفي القائمة الرئيسية تختار اللعب التعاوني (النسخ) أو اللعب منفردًا (ملفات حفظك '
            ..'الأصلية).'},
        {title='عالم مشترك',
         body='في الخريطة نفسها، يملك الأعداء العاديون شريط نقاط صحة واحدًا لكما معًا، ويموتون على الشاشتين في اللحظة '
            ..'نفسها. يقفون في الموضع نفسه في اللعبتين ويلاحقون آخر من ضربهم. ويتشارك الزعماء نقاط صحتهم '
            ..'ومراحلهم.\nافتراضيًا، يُحتسب العدو المهزوم لك إن قاتلته أو كنت ضمن 30 م.\nأثناء مشاهدة المضيف مشهدًا '
            ..'سينمائيًا، تنتظر لعبة الضيف. مشاركة المهام وإنعاش صديقك لك متوقفان افتراضيًا. فعّلهما من "الخيارات".'},
        {title='التشغيل الليلي',
         body='التشغيل الليلي طور بقاء بالموجات حذفته Shift Up قبل الإصدار. يتكون كل تشغيل من خمس موجات محددة الوقت. '
            ..'عندما يبدأه المضيف أثناء جلسة، تتشاركان المؤقت والنقاط. وبنقاط التشغيل تشتري عناصر.\nاكتب هذه الأوامر '
            ..'في سطر الأوامر (F10 أو ~) على حفظ تعاوني:\ncoop nightop start: بدء تشغيل\ncoop nightop shop: عرض '
            ..'العناصر\ncoop nightop buy <n>: شراء العنصر n\ncoop challenge: أربعة تحديات بتقييم'},
        {title='سباقات دورو',
         body='في سباق دورو تتحول EVE لدى كل منكما إلى دورو. سجّل مسارًا أولًا، ثم تسابق عليه:\ncoop race record <name>: '
            ..'بدء التسجيل\nF9: إضافة نقطة تفتيش حيث تقف\ncoop race save: حفظ المسار\ncoop race start <name>: بدء '
            ..'السباق (حفظ تعاوني)\nيبدأ السباق بعد عد تنازلي. بعد "انطلق!" يُقاد دورو كالسيارة وتزداد سرعته مع الوقت. '
            ..'اضغط R2 أو المفتاح B للانجراف. والانعطاف بقوة في السرعة العالية يسبب الانجراف أيضًا. يظهر الترتيب في '
            ..'النهاية.'},
        {title='Leviathan والكاميرا الحرة',
         body='Leviathan هو Naytiba حُذف من اللعبة. على حفظ تعاوني، يضعه الأمر coop leviathan show أمامك ويشغّل كاميرا '
            ..'حرة للتصوير. ويزيل الأمر coop leviathan off الاثنين.\nW A S D أو Z Q S D: الطيران\nSpace أو E: '
            ..'صعود\nCtrl أو C: نزول\nShift: أسرع\nالفأرة: النظر حولك'},
        {title='الإعدادات',
         body='تضبط صفحة "الخيارات" في قائمة اللعب التعاوني المفاتيح وواجهة الشريك ومن يمكنه الانضمام وملفات الحفظ '
            ..'التعاونية وقواعد القتال وحجم القائمة وأصواتها. تُخزَّن القيم في coop-settings.txt.\nاضبط "لغة القائمة" على '
            ..'"English" لقراءة التعديل بالإنجليزية.'},
        {title='المساعدة',
         body='اطرح أسئلتك أو ابحث عن شريك لعب تعاوني على Discord: discord.gg/tvFApEEVfj\nللإبلاغ عن خطأ، أغلق اللعبة. '
            ..'وقبل تشغيلها مجددًا، أرسل coop-report.txt وcoop-link.log وUE4SS.log.\nرسم Mother Sphere: timediffer24.'},
    },
    next='التالي',back='رجوع',close='إغلاق',never='عدم العرض مجددًا',page='الصفحة %d من %d',row='الدليل',
}
G.da={
    pages={
        {title='Velkommen til Stellar Blade Online',
         body='Stellar Blade Online lader en vens EVE komme ind i din verden via Steam. En session har plads til 2 '
            ..'spillere indtil videre. Målet er 100 spillere.\nÅbn denne guide igen når som helst fra co-op-menuen '
            ..'(F5).'},
        {title='Spil sammen',
         body='Tryk på F5 i spilverdenen for at åbne co-op-menuen (hold View nede på en controller). Det første '
            ..'punkt, Vær vært for en session, åbner Steams invitationsvindue.\nSpillere, der ikke er på din '
            ..'Steam-venneliste, kan deltage med en kode. Før du bliver vært, skal du sætte Hvem kan deltage til Med '
            ..'en kode i Indstillinger. Send dem derefter koden på 7 tegn fra Kopiér min kode. Du accepterer dem, '
            ..'når de deltager.\nF6: status\nF8: forlad sessionen\nEnter: chat\nVed en lejrs telefonboks åbner F5 '
            ..'co-op-linjen i stedet for menuen.'},
        {title='Gemte co-op-spil',
         body='Delte fjender, delte quests, Natmission, Doro-løb og Leviathan kører på gemte co-op-spil. Det er '
            ..'kopier af dine gemte spil, som modden laver. Den skriver aldrig til dine egne gemte spil og tager en '
            ..'sikkerhedskopi af dem før den første kopi.\nI hovedmenuen vælger du co-op (kopierne) eller solo (dine '
            ..'egne gemte spil).'},
        {title='En delt verden',
         body='I samme område har almindelige fjender én HP-bjælke for jer begge og dør på begge skærme på samme '
            ..'tid. De står samme sted i begge spil og går efter den, der ramte dem sidst. Bosser deler HP og '
            ..'faser.\nSom standard tæller et drab for dig, hvis du kæmpede eller stod inden for 30 m.\nMens værten '
            ..'ser en mellemsekvens, venter gæstens spil. Delte quests og genoplivning fra din ven er slået fra som '
            ..'standard. Slå dem til i Indstillinger.'},
        {title='Natmission',
         body='Natmission er en overlevelsestilstand med bølger, som Shift Up fjernede før udgivelsen. En mission '
            ..'har fem bølger på tid. Når værten starter den under en session, deler I tiden og pointene. Pointene '
            ..'fra en mission bruges til at købe genstande.\nSkriv disse i konsollen (F10 eller ~) på et gemt '
            ..'co-op-spil:\ncoop nightop start: start en mission\ncoop nightop shop: vis genstandene\ncoop nightop '
            ..'buy <n>: køb genstand n\ncoop challenge: fire udfordringer med bedømmelse'},
        {title='Doro-løb',
         body='I et Doro-løb bliver begge spilleres EVE til Doro. Optag først en rute, og kør derefter løbet på '
            ..'den:\ncoop race record <name>: start optagelsen\nF9: sæt et checkpoint, hvor du står\ncoop race save: '
            ..'gem ruten\ncoop race start <name>: start løbet (gemt co-op-spil)\nLøbet starter efter en nedtælling. '
            ..'Efter AF STED! styrer Doro som en bil og bliver hurtigere med tiden. R2 eller B-tasten får Doro til '
            ..'at drifte. Skarp styring i høj fart giver også drift. Placeringerne vises til sidst.'},
        {title='Leviathan og det frie kamera',
         body='Leviathan er en Naytiba, der blev fjernet fra spillet. På et gemt co-op-spil placerer coop leviathan '
            ..'show den foran dig og starter et frit kamera til optagelser. coop leviathan off fjerner begge.\nW A S '
            ..'D eller Z Q S D: flyv\nSpace eller E: op\nCtrl eller C: ned\nShift: hurtigere\nMus: se dig omkring'},
        {title='Indstillinger',
         body="Siden Indstillinger i co-op-menuen styrer tasterne, partner-HUD'en, hvem der kan deltage, de gemte "
            ..'co-op-spil, kampreglerne samt menuens størrelse og lyde. Værdierne gemmes i coop-settings.txt.\nSæt '
            ..'Menusprog til Engelsk for at læse modden på engelsk.'},
        {title='Hjælp',
         body='Stil spørgsmål eller find en co-op-partner på Discord: discord.gg/tvFApEEVfj\nLuk spillet for at '
            ..'rapportere en fejl. Send coop-report.txt, coop-link.log og UE4SS.log, før du starter det '
            ..'igen.\nMother Sphere-illustrationen er af timediffer24.'},
    },
    next='Næste',back='Tilbage',close='Luk',never='Vis ikke igen',page='Side %d af %d',row='Guide',
}
G.de={
    pages={
        {title='Willkommen bei Stellar Blade Online',
         body='Mit Stellar Blade Online kann die EVE eines Freundes über Steam deiner Welt beitreten. Eine Sitzung '
            ..'fasst vorerst 2 Spieler. Das Ziel sind 100 Spieler.\nDiese Anleitung kannst du jederzeit im Koop-Menü '
            ..'(F5) wieder öffnen.'},
        {title='Zusammen spielen',
         body='Drück in der Spielwelt F5, um das Koop-Menü zu öffnen (am Controller View gedrückt halten). Die erste '
            ..'Zeile, „Sitzung hosten“, öffnet das Steam-Einladungsfenster.\nWer nicht auf deiner '
            ..'Steam-Freundesliste steht, kann mit einem Code beitreten. Stell vor dem Hosten in den Optionen „Wer '
            ..'darf beitreten“ auf „Mit Code“. Schick der Person dann den 7-stelligen Code aus „Meinen Code '
            ..'kopieren“. Wenn sie beitritt, nimmst du sie an.\nF6: Status\nF8: Sitzung verlassen\nEnter: Chat\nAn '
            ..'der Telefonzelle eines Lagers öffnet F5 die Koop-Leitung statt des Menüs.'},
        {title='Koop-Speicherstände',
         body='Gemeinsame Gegner, gemeinsame Quests, der nächtliche Einsatz, Doro-Rennen und Leviathan brauchen '
            ..'Koop-Speicherstände. Das sind Kopien deiner Speicherstände, die der Mod anlegt. Er schreibt nie in '
            ..'deine eigenen Speicherdateien und sichert sie vor der ersten Kopie.\nIm Hauptmenü wählst du Koop (die '
            ..'Kopien) oder solo (deine eigenen Speicherstände).'},
        {title='Eine gemeinsame Welt',
         body='Im selben Gebiet haben normale Gegner eine LP-Leiste für euch beide und sterben auf beiden '
            ..'Bildschirmen gleichzeitig. Sie stehen in beiden Spielen an derselben Stelle und greifen den an, der '
            ..'sie zuletzt getroffen hat. Bosse teilen ihre LP und ihre Phasen.\nStandardmäßig zählt ein Kill für '
            ..'dich, wenn du mitgekämpft hast oder höchstens 30 m entfernt warst.\nWährend der Host eine '
            ..'Zwischensequenz sieht, wartet das Spiel des Gastes. Gemeinsame Quests und das Wiederbeleben durch den '
            ..'Partner sind standardmäßig aus. Du schaltest sie in den Optionen ein.'},
        {title='Nächtlicher Einsatz',
         body='Der nächtliche Einsatz ist ein Überlebensmodus in Wellen, den Shift Up vor dem Release gestrichen '
            ..'hat. Ein Einsatz hat fünf Wellen mit Zeitlimit. Startet der Host ihn in einer Sitzung, teilt ihr Zeit '
            ..'und Punkte. Mit den Punkten aus Einsätzen kaufst du Gegenstände.\nGib in der Konsole (F10 oder ~) auf '
            ..'einem Koop-Speicherstand ein:\ncoop nightop start: Einsatz starten\ncoop nightop shop: Gegenstände '
            ..'auflisten\ncoop nightop buy <n>: Gegenstand n kaufen\ncoop challenge: vier Herausforderungen mit '
            ..'Wertung'},
        {title='Doro-Rennen',
         body='In einem Doro-Rennen werden beide EVEs zu Doro. Zeichne zuerst eine Strecke auf und tritt dann darauf '
            ..'an:\ncoop race record <name>: Aufnahme starten\nF9: Checkpoint an deiner Position setzen\ncoop race '
            ..'save: Strecke speichern\ncoop race start <name>: Rennen starten (Koop-Speicherstand)\nDas Rennen '
            ..'beginnt nach einem Countdown. Ab LOS! steuert sich Doro wie ein Auto und wird mit der Zeit schneller. '
            ..'Mit R2 oder der Taste B driftest du. Scharfes Lenken bei hohem Tempo löst ebenfalls einen Drift aus. '
            ..'Am Ende erscheint die Rangliste.'},
        {title='Leviathan und die freie Kamera',
         body='Leviathan ist ein Naytiba, der aus dem Spiel gestrichen wurde. Auf einem Koop-Speicherstand stellt '
            ..'coop leviathan show ihn vor dich und startet eine freie Kamera zum Filmen. coop leviathan off '
            ..'entfernt beides.\nW A S D oder Z Q S D: fliegen\nLeertaste oder E: hoch\nStrg oder C: runter\nShift: '
            ..'schneller\nMaus: umsehen'},
        {title='Einstellungen',
         body='Auf der Seite Optionen im Koop-Menü stellst du die Tasten, das Partner-HUD, wer beitreten darf, die '
            ..'Koop-Speicherstände, die Kampfregeln sowie Größe und Töne des Menüs ein. Die Werte stehen in '
            ..'coop-settings.txt.\nStell „Menüsprache“ auf „Englisch“, um den Mod auf Englisch zu lesen.'},
        {title='Hilfe',
         body='Stell Fragen oder finde einen Koop-Partner auf dem Discord: discord.gg/tvFApEEVfj\nUm einen Fehler zu '
            ..'melden, schließ das Spiel. Schick vor dem nächsten Start coop-report.txt, coop-link.log und '
            ..'UE4SS.log.\nBild der Mother Sphere von timediffer24.'},
    },
    next='Weiter',back='Zurück',close='Schließen',never='Nicht mehr anzeigen',page='Seite %d von %d',row='Anleitung',
}
G.es={
    pages={
        {title='Bienvenido a Stellar Blade Online',
         body='Stellar Blade Online permite que la EVE de un amigo se una a tu mundo a través de Steam. Por ahora, '
            ..'una sesión admite 2 jugadores. El objetivo es llegar a 100.\nPuedes volver a abrir esta guía en '
            ..'cualquier momento desde el menú co-op (F5).'},
        {title='Jugar juntos',
         body='Pulsa F5 en el mundo del juego para abrir el menú co-op (en el mando, mantén View). Su primera '
            ..'opción, Crear una sesión, abre la ventana de invitaciones de Steam.\nAlguien que no esté en tu lista '
            ..'de amigos de Steam puede unirse con un código. Antes de crear la sesión, ajusta Quién puede unirse a '
            ..'Con un código en las Opciones. Luego envíale el código de 7 caracteres que da Copiar mi código. '
            ..'Cuando se una, tendrás que aceptarlo.\nF6: estado\nF8: salir de la sesión\nEnter: chat\nEn una cabina '
            ..'telefónica de campamento, F5 abre la línea co-op en lugar del menú.'},
        {title='Partidas co-op',
         body='Los enemigos compartidos, las misiones compartidas, la operación nocturna, las carreras de Doro y '
            ..'Leviathan usan partidas co-op. Son copias de tus partidas que crea el mod. Nunca escribe en tus '
            ..'propios archivos de guardado y hace una copia de seguridad de ellos antes de la primera '
            ..'conversión.\nEn el menú principal eliges co-op (las copias) o solo (tus propias partidas).'},
        {title='Un mundo compartido',
         body='En el mismo mapa, los enemigos comunes tienen una sola barra de PS para los dos y mueren a la vez en '
            ..'ambas pantallas. Están en el mismo sitio en las dos partidas y atacan a quien los golpeó por última '
            ..'vez. Los jefes comparten sus PS y sus fases.\nPor defecto, una baja cuenta para ti si combatiste o '
            ..'estabas a menos de 30 m.\nMientras el anfitrión ve una cinemática, la partida del invitado espera. '
            ..'Por defecto, las misiones compartidas están desactivadas y tu compañero no puede reanimarte. Ambas '
            ..'cosas se activan en las Opciones.'},
        {title='Operación nocturna',
         body='La operación nocturna es un modo de supervivencia por oleadas que Shift Up eliminó antes del '
            ..'lanzamiento. Una operación tiene cinco oleadas con tiempo límite. Si el anfitrión la inicia durante '
            ..'una sesión, compartís el tiempo y la puntuación. Los puntos de una operación sirven para comprar '
            ..'objetos.\nEscribe esto en la consola (F10 o ~) en una partida co-op:\ncoop nightop start: iniciar una '
            ..'operación\ncoop nightop shop: ver los objetos\ncoop nightop buy <n>: comprar el objeto n\ncoop '
            ..'challenge: cuatro desafíos con nota'},
        {title='Carreras de Doro',
         body='En una carrera de Doro, las dos EVE se convierten en Doro. Primero graba un circuito y luego corre en '
            ..'él:\ncoop race record <name>: empezar a grabar\nF9: poner un punto de control donde estás\ncoop race '
            ..'save: guardar el circuito\ncoop race start <name>: iniciar la carrera (partida co-op)\nLa carrera '
            ..'empieza tras una cuenta atrás. Luego, Doro se conduce como un coche y acelera con el tiempo. R2 o la '
            ..'tecla B sirven para derrapar. Girar bruscamente a gran velocidad también hace derrapar. La '
            ..'clasificación aparece al final.'},
        {title='Leviathan y la cámara libre',
         body='Leviathan es un Naytiba eliminado del juego. En una partida co-op, coop leviathan show lo coloca '
            ..'delante de ti y activa una cámara libre para grabar. coop leviathan off quita las dos cosas.\nW A S D '
            ..'o Z Q S D: volar\nSpace o E: subir\nCtrl o C: bajar\nShift: más rápido\nRatón: mirar alrededor'},
        {title='Ajustes',
         body='La página Opciones del menú co-op ajusta las teclas, el HUD del compañero, quién puede unirse, las '
            ..'partidas co-op, las reglas de combate, el tamaño del menú y sus sonidos. Los valores se guardan en '
            ..'coop-settings.txt.\nPon Idioma del menú en Inglés para ver el mod en inglés.'},
        {title='Ayuda',
         body='Haz preguntas o busca compañero de co-op en el Discord: discord.gg/tvFApEEVfj\nPara informar de un '
            ..'error, cierra el juego. Antes de volver a iniciarlo, envía coop-report.txt, coop-link.log y '
            ..'UE4SS.log.\nIlustración de Mother Sphere por timediffer24.'},
    },
    next='Siguiente',back='Atrás',close='Cerrar',never='No volver a mostrar',page='Página %d de %d',row='Guía',
}
G['es-MX']={
    pages={
        {title='Bienvenido a Stellar Blade Online',
         body='Con Stellar Blade Online, la EVE de un amigo se une a tu mundo a través de Steam. Por ahora, una sesión '
            ..'admite 2 jugadores. La meta es llegar a 100 jugadores.\nPuedes volver a abrir esta guía cuando quieras '
            ..'desde el menú co-op (F5).'},
        {title='Jugar juntos',
         body='Presiona F5 en el mundo para abrir el menú co-op (en un control, mantén presionado View). La primera '
            ..'opción, Crear una sesión, abre la ventana de invitaciones de Steam.\nQuien no esté en tu lista de '
            ..'amigos de Steam puede unirse con un código. Antes de crear la sesión, en Opciones cambia Quién puede '
            ..'unirse a Con un código. Después usa Copiar mi código y envíale el código de 7 caracteres. Cuando '
            ..'intente unirse, acepta la solicitud.\nF6: estado\nF8: salir de la sesión\nEnter: chat\nEn la cabina '
            ..'telefónica de un campamento, F5 abre la línea co-op en lugar del menú.'},
        {title='Partidas co-op',
         body='Los enemigos compartidos, las misiones compartidas, la operación nocturna, las carreras de Doro y '
            ..'Leviathan funcionan con partidas co-op. Son copias de tus partidas guardadas que hace el mod. El mod '
            ..'nunca escribe en tus propios archivos de guardado y los respalda antes de la primera copia.\nEn el menú '
            ..'principal eliges jugar en co-op (las copias) o en solitario (tus propias partidas).'},
        {title='Un mundo compartido',
         body='En el mismo mapa, los enemigos comunes tienen una sola barra de salud para los dos y mueren en ambas '
            ..'pantallas a la vez. Están en el mismo lugar en ambas partidas y van tras quien los golpeó por última '
            ..'vez. Los jefes comparten su salud y sus fases.\nDe forma predeterminada, un enemigo derrotado cuenta '
            ..'para ti si lo combatiste o estabas a menos de 30 m.\nMientras el anfitrión ve una cinemática, la '
            ..'partida del invitado espera. Las misiones compartidas y la reanimación por tu amigo están desactivadas '
            ..'de forma predeterminada. Actívalas en Opciones.'},
        {title='Operación nocturna',
         body='La operación nocturna es un modo de supervivencia por oleadas que Shift Up quitó antes del lanzamiento. '
            ..'Cada operación tiene cinco oleadas con tiempo límite. Si el anfitrión la inicia durante una sesión, '
            ..'comparten el tiempo y los puntos. Con los puntos de una operación compras objetos.\nEscribe esto en la '
            ..'consola (F10 o ~) con una partida co-op:\ncoop nightop start: iniciar una operación\ncoop nightop shop: '
            ..'ver los objetos\ncoop nightop buy <n>: comprar el objeto n\ncoop challenge: cuatro desafíos con '
            ..'calificación'},
        {title='Carreras de Doro',
         body='En una carrera de Doro, las dos EVE se convierten en Doro. Primero graba un circuito y luego compite en '
            ..'él:\ncoop race record <name>: empezar a grabar\nF9: poner un punto de control donde estás\ncoop race '
            ..'save: guardar el circuito\ncoop race start <name>: iniciar la carrera (partida co-op)\nLa carrera '
            ..'empieza tras una cuenta regresiva. Después de ¡ARRANCA!, Doro se maneja como un auto y acelera con el '
            ..'tiempo. Con R2 o la tecla B derrapas. Girar fuerte a alta velocidad también te hace derrapar. Al final '
            ..'se muestra la clasificación.'},
        {title='Leviathan y la cámara libre',
         body='Leviathan es un Naytiba que se quitó del juego. En una partida co-op, coop leviathan show lo coloca '
            ..'frente a ti y activa una cámara libre para grabar. coop leviathan off quita ambos.\nW A S D o Z Q S D: '
            ..'volar\nSpace o E: subir\nCtrl o C: bajar\nShift: más rápido\nMouse: mirar alrededor'},
        {title='Configuración',
         body='La página Opciones del menú co-op ajusta las teclas, el HUD del compañero, quién puede unirse, las '
            ..'partidas co-op, las reglas de combate, y el tamaño y los sonidos del menú. Los valores se guardan en '
            ..'coop-settings.txt.\nPon Idioma del menú en Inglés para leer el mod en inglés.'},
        {title='Ayuda',
         body='Haz preguntas o busca un compañero de co-op en el Discord: discord.gg/tvFApEEVfj\nPara reportar un '
            ..'error, cierra el juego. Antes de volver a iniciarlo, envía coop-report.txt, coop-link.log y '
            ..'UE4SS.log.\nArte de Mother Sphere por timediffer24.'},
    },
    next='Siguiente',back='Atrás',close='Cerrar',never='No volver a mostrar',page='Página %d de %d',row='Guía',
}
G.fi={
    pages={
        {title='Tervetuloa Stellar Blade Onlineen',
         body='Stellar Blade Onlinen avulla kaverin EVE voi liittyä maailmaasi Steamin kautta. Istuntoon mahtuu '
            ..'toistaiseksi 2 pelaajaa. Tavoite on 100 pelaajaa.\nVoit avata tämän oppaan milloin tahansa uudelleen '
            ..'co-op-valikosta (F5).'},
        {title='Pelatkaa yhdessä',
         body='Avaa co-op-valikko painamalla pelimaailmassa F5 (ohjaimella pidä View-painiketta pohjassa). Sen '
            ..'ensimmäinen rivi, Isännöi istuntoa, avaa Steamin kutsuikkunan.\nPelaaja, joka ei ole '
            ..'Steam-kaverilistallasi, voi liittyä koodilla. Valitse ennen isännöintiä Asetuksissa kohtaan Kuka voi '
            ..'liittyä arvo Koodilla. Lähetä hänelle sitten 7-merkkinen koodi kohdasta Kopioi koodini. Hyväksyt '
            ..'hänet, kun hän liittyy.\nF6: tila\nF8: poistu istunnosta\nEnter: keskustelu\nLeirin puhelinkopilla F5 '
            ..'avaa co-op-linjan valikon sijaan.'},
        {title='Co-op-tallennukset',
         body='Jaetut viholliset, jaetut tehtävät, Yöoperaatio, Doro-kilvat ja Leviathan toimivat '
            ..'co-op-tallennuksilla. Ne ovat modin tekemiä kopioita tallennuksistasi. Modi ei koskaan kirjoita omiin '
            ..'tallennuksiisi ja varmuuskopioi ne ennen ensimmäistä kopiota.\nPäävalikossa valitset co-opin (kopiot) '
            ..'tai yksinpelin (omat tallennuksesi).'},
        {title='Jaettu maailma',
         body='Samalla kartalla tavallisilla vihollisilla on teille yksi yhteinen HP-palkki, ja ne kuolevat '
            ..'kummallakin ruudulla yhtä aikaa. Ne seisovat samassa paikassa kummassakin pelissä ja käyvät sen '
            ..'kimppuun, joka osui niihin viimeksi. Pomot jakavat HP:nsa ja vaiheensa.\nOletuksena tappo lasketaan '
            ..'sinulle, jos taistelit tai olit alle 30 m:n päässä.\nKun isäntä katsoo välianimaatiota, vieraan peli '
            ..'odottaa. Jaetut tehtävät ja kumppanin elvytykset ovat oletuksena pois päältä. Ota ne käyttöön '
            ..'Asetuksissa.'},
        {title='Yöoperaatio',
         body='Yöoperaatio on aaltoihin perustuva selviytymistila, jonka Shift Up poisti ennen julkaisua. '
            ..'Operaatiossa on viisi ajastettua aaltoa. Kun isäntä aloittaa sen istunnon aikana, jaatte ajastimen ja '
            ..'pisteet. Operaatioiden pisteillä ostetaan tavaroita.\nKirjoita nämä konsoliin (F10 tai ~) '
            ..'co-op-tallennuksella:\ncoop nightop start: aloita operaatio\ncoop nightop shop: näytä tavarat\ncoop '
            ..'nightop buy <n>: osta tavara n\ncoop challenge: neljä arvosteltua haastetta'},
        {title='Doro-kilvat',
         body='Doro-kilvassa kummankin pelaajan EVE muuttuu Doroksi. Tallenna ensin rata ja kilpaile sitten '
            ..'sillä:\ncoop race record <name>: aloita tallennus\nF9: lisää rastipiste kohtaan, jossa seisot\ncoop '
            ..'race save: tallenna rata\ncoop race start <name>: aloita kilpa (co-op-tallennus)\nKilpa alkaa '
            ..'lähtölaskennan jälkeen. MENE!-merkin jälkeen Doro ohjautuu kuin auto ja kiihtyy ajan myötä. R2 tai '
            ..'B-näppäin saa Doron driftaamaan. Jyrkkä ohjaus kovassa vauhdissa saa sen myös driftaamaan. '
            ..'Sijoitukset näkyvät lopussa.'},
        {title='Leviathan ja vapaa kamera',
         body='Leviathan on pelistä poistettu Naytiba. Co-op-tallennuksella coop leviathan show tuo sen eteesi ja '
            ..'käynnistää vapaan kameran kuvaamista varten. coop leviathan off poistaa molemmat.\nW A S D tai Z Q S '
            ..'D: lennä\nSpace tai E: ylös\nCtrl tai C: alas\nShift: nopeammin\nHiiri: katsele ympärillesi'},
        {title='Asetukset',
         body='Co-op-valikon Asetukset-sivulla säädetään näppäimet, kumppanin HUD, kuka voi liittyä, '
            ..'co-op-tallennukset, taistelusäännöt sekä valikon koko ja äänet. Arvot tallentuvat tiedostoon '
            ..'coop-settings.txt.\nValitse kohtaan Valikon kieli arvo Englanti, niin modi näkyy englanniksi.'},
        {title='Ohje',
         body='Kysy kysymyksiä tai etsi co-op-kumppani Discordista: discord.gg/tvFApEEVfj\nIlmoita virheestä '
            ..'sulkemalla ensin peli. Lähetä coop-report.txt, coop-link.log ja UE4SS.log ennen kuin käynnistät sen '
            ..'uudelleen.\nMother Sphere -kuvitus: timediffer24.'},
    },
    next='Seuraava',back='Takaisin',close='Sulje',never='Älä näytä uudelleen',page='Sivu %d/%d',row='Opas',
}
G.it={
    pages={
        {title='Benvenuti in Stellar Blade Online',
         body="Con Stellar Blade Online l'EVE di un amico entra nel tuo mondo tramite Steam. Per ora una sessione "
            .."ospita 2 giocatori. L'obiettivo è 100 giocatori.\nPuoi riaprire questa guida in qualsiasi momento dal "
            ..'menu co-op (F5).'},
        {title='Giocare insieme',
         body='Nel mondo di gioco premi F5 per aprire il menu co-op (sul controller tieni premuto View). La prima '
            ..'riga, «Ospita una sessione», apre la finestra degli inviti di Steam.\nChi non è tra i tuoi amici di '
            ..'Steam può unirsi con un codice. Prima di ospitare, nelle Opzioni imposta «Chi può unirsi» su «Con un '
            ..'codice». Poi invia a quel giocatore il codice di 7 caratteri preso con «Copia il mio codice». Quando '
            ..'prova a unirsi, lo accetti tu.\nF6: stato\nF8: lascia la sessione\nInvio: chat\nVicino alla cabina '
            ..'telefonica di un accampamento, F5 apre la linea co-op al posto del menu.'},
        {title='Salvataggi co-op',
         body="Nemici condivisi, missioni condivise, l'operazione notturna, gare di Doro e Leviathan richiedono i "
            ..'salvataggi co-op. Sono copie dei tuoi salvataggi create dalla mod. La mod non scrive mai sui tuoi '
            ..'file di salvataggio e ne fa un backup prima della prima copia.\nNel menu principale scegli co-op (le '
            ..'copie) o da solo (i tuoi salvataggi).'},
        {title='Un mondo condiviso',
         body='Sulla stessa mappa i nemici comuni hanno una sola barra dei PS per entrambi e muoiono su tutti e due '
            ..'gli schermi nello stesso istante. Stanno nello stesso punto in entrambe le partite e attaccano chi li '
            .."ha colpiti per ultimo. I boss condividono PS e fasi.\nPer impostazione predefinita, un'uccisione "
            .."conta per te se hai combattuto o eri entro 30 m.\nMentre l'host guarda un filmato, la partita di chi "
            .."si è unito resta in attesa. Missioni condivise e rianimazione da parte dell'amico sono disattivate "
            ..'per impostazione predefinita. Attivale nelle Opzioni.'},
        {title='Operazione notturna',
         body="L'operazione notturna è una modalità di sopravvivenza a ondate che Shift Up ha tagliato prima "
            .."dell'uscita. Un'operazione ha cinque ondate a tempo. Se l'host la avvia durante una sessione, "
            ..'condividete timer e punteggio. Con i punti delle operazioni compri oggetti.\nScrivi nella console '
            .."(F10 o ~) su un salvataggio co-op:\ncoop nightop start: avvia un'operazione\ncoop nightop shop: "
            .."elenca gli oggetti\ncoop nightop buy <n>: compra l'oggetto n\ncoop challenge: quattro sfide con "
            ..'valutazione'},
        {title='Gare di Doro',
         body='In una gara di Doro entrambe le EVE diventano Doro. Prima registra un percorso, poi gareggiaci '
            ..'sopra:\ncoop race record <name>: avvia la registrazione\nF9: piazza un checkpoint dove ti trovi\ncoop '
            ..'race save: salva il percorso\ncoop race start <name>: avvia la gara (salvataggio co-op)\nLa gara '
            .."parte dopo un conto alla rovescia. Dopo il VIA!, Doro si guida come un'auto e accelera col tempo. R2 "
            ..'o il tasto B fanno derapare. Anche sterzare forte ad alta velocità fa derapare. Alla fine compare la '
            ..'classifica.'},
        {title='Leviathan e la telecamera libera',
         body='Leviathan è un Naytiba tagliato dal gioco. Su un salvataggio co-op, coop leviathan show lo piazza '
            ..'davanti a te e avvia una telecamera libera per le riprese. coop leviathan off li rimuove entrambi.\nW '
            ..'A S D o Z Q S D: vola\nSpazio o E: su\nCtrl o C: giù\nMaiusc: più veloce\nMouse: guardati intorno'},
        {title='Impostazioni',
         body="La pagina Opzioni del menu co-op imposta i tasti, l'HUD del partner, chi può unirsi, i salvataggi "
            ..'co-op, le regole di combattimento, la dimensione e i suoni del menu. I valori sono salvati in '
            ..'coop-settings.txt.\nImposta «Lingua del menu» su «Inglese» per leggere la mod in inglese.'},
        {title='Aiuto',
         body='Fai domande o trova un partner per il co-op sul Discord: discord.gg/tvFApEEVfj\nPer segnalare un bug, '
            ..'chiudi il gioco. Prima di riavviarlo, invia coop-report.txt, coop-link.log e '
            ..'UE4SS.log.\nIllustrazione della Mother Sphere di timediffer24.'},
    },
    next='Avanti',back='Indietro',close='Chiudi',never='Non mostrare più',page='Pagina %d di %d',row='Guida',
}
G.ja={
    pages={
        {title='Stellar Blade Onlineへようこそ',
         body='Stellar Blade Onlineでは、フレンドのEVEがSteam経由であなたの世界に参加できます。現在、'
            ..'1セッションの人数は2人です。目標は100人です。\nこのガイドは協力プレイメニュー（F5）'
            ..'からいつでも開けます。'},
        {title='一緒に遊ぶ',
         body='ゲームプレイ中にF5を押すと協力プレイメニューが開きます（コントローラーではViewを長押し）。'
            ..'最初の項目「セッションをホスト」でSteamの招待画面が開きます。\nSteamのフレンドでない人も、'
            ..'コードで参加できます。ホストする前に、「オプション」で「参加できる人」を「コードを持つ人」'
            ..'にしてください。次に「自分のコードをコピー」で7文字のコードを相手に送ります。相手が参加するときに、'
            ..'あなたが承認します。\nF6：状態\nF8：セッションから退出\nEnter：チャット\nキャンプの電話ボックスでは、'
            ..'F5でメニューではなく協力プレイ回線が開きます。'},
        {title='協力プレイ用セーブ',
         body='敵の共有、クエスト共有、夜間オペレーション、ドロレース、Leviathanは協力プレイ用セーブで動きます。'
            ..'協力プレイ用セーブは、MODが作るセーブデータのコピーです。MODは元のセーブデータに書き込まず、'
            ..'最初の変換の前にバックアップを作ります。\nメインメニューで、協力プレイ（コピー）'
            ..'かソロ（元のセーブデータ）を選びます。'},
        {title='世界の共有',
         body='同じマップでは、通常の敵のHPバーが2人で1本になり、両方の画面で同時に倒れます。'
            ..'敵は両方のゲームで同じ位置に立ち、最後に攻撃した人を狙います。ボスもHPとフェーズを共有します。'
            ..'\n初期設定では、交戦したか30m以内にいた場合、あなたの撃破としてカウントされます。'
            ..'\nホストがイベントシーンを見ている間、ゲストのゲームは待機します。'
            ..'クエスト共有とパートナーによる蘇生は初期設定でオフです。「オプション」でオンにできます。'},
        {title='夜間オペレーション',
         body='夜間オペレーションは、Shift Upが発売前にカットしたウェーブ制のサバイバルモードです。'
            ..'1回のオペレーションは、制限時間付きの5ウェーブです。セッション中にホストが開始すると、'
            ..'タイマーとスコアを共有します。オペレーションで得たポイントでアイテムを買えます。'
            ..'\n協力プレイ用セーブで、コンソール（F10か~）に次のコマンドを入力します：\ncoop nightop start：'
            ..'オペレーションを開始\ncoop nightop shop：アイテム一覧\ncoop nightop buy <n>：アイテムnを購入\ncoop '
            ..'challenge：評価付きの4つのチャレンジ'},
        {title='ドロレース',
         body='ドロレースでは、2人のEVEがドロに変身します。まずコースを記録し、そのコースでレースします：\ncoop race '
            ..'record <name>：記録を開始\nF9：今いる場所にチェックポイントを設置\ncoop race save：コースを保存\ncoop '
            ..'race start <name>：レースを開始（協力プレイ用セーブ）\nカウントダウンのあとにレースが始まります。'
            ..'GO!のあと、ドロは車のように走り、時間とともに加速します。R2かBキーでドリフトします。'
            ..'高速で大きくハンドルを切ってもドリフトします。最後に順位が表示されます。'},
        {title='Leviathanとフリーカメラ',
         body='LeviathanはゲームからカットされたNaytibaです。協力プレイ用セーブでcoop leviathan showを入力すると、'
            ..'目の前にLeviathanが現れ、撮影用のフリーカメラが始まります。coop leviathan offで両方を消します。\nW A '
            ..'S DかZ Q S D：飛行\nSpaceかE：上昇\nCtrlかC：下降\nShift：高速\nマウス：視点移動'},
        {title='設定',
         body='協力プレイメニューの「オプション」では、キー、パートナー表示、参加できる人、協力プレイ用セーブ、'
            ..'戦闘ルール、メニューのサイズと効果音を設定します。設定値はcoop-settings.txtに保存されます。'
            ..'\n「メニューの言語」を「English」にすると、MODが英語で表示されます。'},
        {title='ヘルプ',
         body='質問や協力プレイの相手探しはDiscordへ：discord.gg/tvFApEEVfj\nバグを報告するときは、'
            ..'ゲームを終了してください。再び起動する前に、coop-report.txt、coop-link.log、'
            ..'UE4SS.logを送ってください。\nMother Sphereのイラスト：timediffer24'},
    },
    next='次へ',back='戻る',close='閉じる',never='今後は表示しない',page='ページ %d/%d',row='ガイド',
}
G.ko={
    pages={
        {title='Stellar Blade Online에 어서 오세요',
         body='Stellar Blade Online에서는 친구의 EVE가 Steam을 통해 내 월드에 참가합니다. 현재 세션 하나에 2명까지 '
            ..'플레이할 수 있습니다. 목표는 100명입니다.\n이 가이드는 언제든 코옵 메뉴(F5)에서 다시 열 수 있습니다.'},
        {title='함께 플레이하기',
         body="월드에서 F5를 누르면 코옵 메뉴가 열립니다(컨트롤러는 View 길게 누르기). 첫 번째 항목 '세션 열기'는 "
            .."Steam 초대 창을 엽니다.\nSteam 친구가 아닌 사람도 코드로 참가할 수 있습니다. 세션을 열기 전에 "
            .."'옵션'에서 '참가 가능 대상'을 '코드 보유자'로 설정하세요. 그다음 '내 코드 복사'로 7자리 코드를 복사해 "
            .."보내세요. 참가 요청이 오면 수락하세요.\nF6: 상태\nF8: 세션 나가기\nEnter: 채팅\n캠프의 공중전화에서는 "
            .."F5를 누르면 메뉴 대신 코옵 회선이 열립니다."},
        {title='코옵 세이브',
         body='적 공유, 퀘스트 공유, 야간 작전, 도로 레이스, Leviathan은 코옵 세이브에서 작동합니다. 코옵 세이브는 '
            ..'모드가 만든 세이브 사본입니다. 모드는 원래 세이브 파일에 절대 쓰지 않으며, 첫 사본을 만들기 전에 원래 '
            ..'세이브를 백업합니다.\n메인 화면에서 코옵 플레이(사본) 또는 혼자 플레이(원래 세이브)를 고릅니다.'},
        {title='공유되는 세계',
         body="같은 맵에서는 일반 적의 생명력 바 하나를 두 사람이 공유하고, 적은 두 화면에서 동시에 처치됩니다. 적은 "
            .."두 게임에서 같은 위치에 있고, 마지막으로 공격한 사람을 노립니다. 보스는 생명력과 페이즈를 "
            .."공유합니다.\n기본 설정에서는 교전했거나 30m 이내에 있었다면 처치 보상을 받습니다.\n호스트가 컷신을 보는 "
            .."동안 게스트의 게임은 대기합니다. 퀘스트 공유와 친구의 부활은 기본적으로 꺼져 있습니다. '옵션'에서 "
            .."켜세요."},
        {title='야간 작전',
         body='야간 작전은 Shift Up이 출시 전에 삭제한 웨이브 생존 모드입니다. 한 번의 작전은 제한 시간이 있는 웨이브 '
            ..'5개로 이루어집니다. 세션 중에 호스트가 시작하면 타이머와 점수를 공유합니다. 작전에서 얻은 포인트로 '
            ..'아이템을 삽니다.\n코옵 세이브에서 콘솔(F10 또는 ~)에 다음을 입력하세요:\ncoop nightop start: 작전 '
            ..'시작\ncoop nightop shop: 아이템 목록\ncoop nightop buy <n>: n번 아이템 구매\ncoop challenge: 등급이 '
            ..'매겨지는 도전 4종'},
        {title='도로 레이스',
         body="도로 레이스에서는 두 EVE가 모두 도로로 변합니다. 먼저 코스를 기록한 뒤 그 코스에서 레이스하세요:\ncoop "
            .."race record <name>: 기록 시작\nF9: 서 있는 곳에 체크포인트 추가\ncoop race save: 코스 저장\ncoop race "
            .."start <name>: 레이스 시작(코옵 세이브)\n카운트다운이 끝나면 레이스가 시작됩니다. '출발!' 이후 도로는 "
            .."자동차처럼 움직이고 시간이 지날수록 빨라집니다. R2 또는 B 키로 드리프트합니다. 빠른 속도에서 크게 "
            .."꺾어도 드리프트합니다. 마지막에 순위가 표시됩니다."},
        {title='Leviathan과 자유 카메라',
         body='Leviathan은 게임에서 삭제된 Naytiba입니다. 코옵 세이브에서 coop leviathan show를 입력하면 눈앞에 '
            ..'Leviathan이 나타나고 촬영용 자유 카메라가 켜집니다. coop leviathan off는 둘 다 없앱니다.\nW A S D 또는 '
            ..'Z Q S D: 비행\nSpace 또는 E: 위로\nCtrl 또는 C: 아래로\nShift: 빠르게\n마우스: 둘러보기'},
        {title='설정',
         body="코옵 메뉴의 '옵션' 페이지에서 키, 파트너 HUD, 참가 가능 대상, 코옵 세이브, 전투 규칙, 메뉴 크기와 "
            .."효과음을 설정합니다. 설정값은 coop-settings.txt에 저장됩니다.\n모드를 영어로 보려면 '메뉴 언어'를 "
            .."'English'로 설정하세요."},
        {title='도움말',
         body='Discord에서 질문하거나 코옵 파트너를 찾을 수 있습니다: discord.gg/tvFApEEVfj\n버그를 제보하려면 게임을 '
            ..'종료하세요. 게임을 다시 시작하기 전에 coop-report.txt, coop-link.log, UE4SS.log를 보내 주세요.\nMother '
            ..'Sphere 아트: timediffer24.'},
    },
    next='다음',back='뒤로',close='닫기',never='다시 보지 않기',page='페이지 %d/%d',row='가이드',
}
G.nl={
    pages={
        {title='Welkom bij Stellar Blade Online',
         body='Met Stellar Blade Online komt de EVE van een vriend via Steam in jouw wereld. Een sessie heeft '
            ..'voorlopig plaats voor 2 spelers. Het doel is 100 spelers.\nJe kunt deze gids altijd opnieuw openen '
            ..'via het co-opmenu (F5).'},
        {title='Samen spelen',
         body='Druk in de gamewereld op F5 om het co-opmenu te openen (houd View ingedrukt op een controller). De '
            ..'eerste regel, Een sessie hosten, opent het uitnodigingsvenster van Steam.\nIemand die niet in je '
            ..'Steam-vriendenlijst staat, kan meedoen met een code. Zet voor het hosten Wie mag meedoen op Met een '
            ..'code in de Opties. Stuur die speler daarna de code van 7 tekens uit Mijn code kopiëren. Je accepteert '
            ..'de speler zodra die meedoet.\nF6: status\nF8: sessie verlaten\nEnter: chat\nBij een telefooncel in '
            ..'een kamp opent F5 de co-oplijn in plaats van het menu.'},
        {title='Opgeslagen co-opgames',
         body='Gedeelde vijanden, gedeelde quests, de nachtelijke missie, Dororaces en Leviathan werken op '
            ..'opgeslagen co-opgames. Dat zijn kopieën van je opgeslagen games die de mod maakt. De mod schrijft '
            ..'nooit naar je eigen opgeslagen games en maakt er een back-up van vóór de eerste kopie.\nIn het '
            ..'hoofdmenu kies je co-op (de kopieën) of solo (je eigen opgeslagen games).'},
        {title='Een gedeelde wereld',
         body='In hetzelfde gebied hebben gewone vijanden één HP-balk voor jullie allebei en sterven ze tegelijk op '
            ..'beide schermen. Ze staan in beide games op dezelfde plek en gaan achter degene aan die ze het laatst '
            ..'raakte. Bazen delen hun HP en hun fases.\nStandaard telt een verslagen vijand voor jou als je '
            ..'meevocht of binnen 30 m stond.\nTerwijl de host een tussenfilmpje kijkt, wacht de game van de gast. '
            ..'Gedeelde quests en reanimeren door je vriend staan standaard uit. Zet ze aan in de Opties.'},
        {title='Nachtelijke missie',
         body='De nachtelijke missie is een survivalmodus met golven die Shift Up vóór de release heeft geschrapt. '
            ..'Een missie heeft vijf golven op tijd. Als de host er een start tijdens een sessie, delen jullie de '
            ..'timer en de score. Met de punten uit een missie koop je items.\nTyp deze in de console (F10 of ~) op '
            ..'een opgeslagen co-opgame:\ncoop nightop start: een missie starten\ncoop nightop shop: de items '
            ..'tonen\ncoop nightop buy <n>: item n kopen\ncoop challenge: vier uitdagingen met beoordeling'},
        {title='Dororaces',
         body="In een Dororace veranderen beide EVE's in Doro. Neem eerst een route op en race daar dan op:\ncoop "
            ..'race record <name>: opname starten\nF9: checkpoint plaatsen waar je staat\ncoop race save: route '
            ..'opslaan\ncoop race start <name>: race starten (opgeslagen co-opgame)\nDe race start na een aftelling. '
            ..'Na GA! stuurt Doro als een auto en gaat hij steeds sneller. R2 of de B-toets laat hem driften. Hard '
            ..'sturen op hoge snelheid laat hem ook driften. De uitslag verschijnt aan het eind.'},
        {title='Leviathan en de vrije camera',
         body='Leviathan is een Naytiba die uit de game is geschrapt. Op een opgeslagen co-opgame zet coop leviathan '
            ..'show hem voor je neer en start een vrije camera om te filmen. coop leviathan off haalt beide weg.\nW '
            ..'A S D of Z Q S D: vliegen\nSpace of E: omhoog\nCtrl of C: omlaag\nShift: sneller\nMuis: rondkijken'},
        {title='Instellingen',
         body='Op de pagina Opties van het co-opmenu stel je de toetsen in, de partner-HUD, wie mag meedoen, de '
            ..'opgeslagen co-opgames, de vechtregels en het formaat en de geluiden van het menu. De waarden staan in '
            ..'coop-settings.txt.\nZet Taal menu op Engels om de mod in het Engels te lezen.'},
        {title='Hulp',
         body='Stel vragen of zoek een co-oppartner op de Discord: discord.gg/tvFApEEVfj\nSluit de game om een bug '
            ..'te melden. Stuur coop-report.txt, coop-link.log en UE4SS.log voordat je de game weer start.\nMother '
            ..'Sphere-illustratie door timediffer24.'},
    },
    next='Volgende',back='Terug',close='Sluiten',never='Niet meer tonen',page='Pagina %d van %d',row='Gids',
}
G.no={
    pages={
        {title='Velkommen til Stellar Blade Online',
         body='Med Stellar Blade Online kan en venns EVE bli med i verdenen din via Steam. Foreløpig har en økt '
            ..'plass til 2 spillere. Målet er 100 spillere.\nDu kan åpne denne veiledningen igjen når som helst fra '
            ..'co-op-menyen (F5).'},
        {title='Spill sammen',
         body='Trykk på F5 i spillverdenen for å åpne co-op-menyen (hold inne View på en kontroller). Den første '
            ..'raden, «Vær vert for en økt», åpner invitasjonsvinduet i Steam.\nEn som ikke står på '
            ..'Steam-vennelisten din, kan bli med via kode. Før du blir vert, sett «Hvem kan bli med» til «Med kode» '
            ..'under Alternativer. Send så koden på 7 tegn fra «Kopier koden min». Når spilleren blir med, må du '
            ..'godta forespørselen.\nF6: status\nF8: forlat økten\nEnter: chat\nVed telefonkiosken i en leir åpner '
            ..'F5 co-op-linjen i stedet for menyen.'},
        {title='Co-op-lagringer',
         body='Delte fiender, delte oppdrag, nattoperasjonen, Doro-løp og Leviathan krever co-op-lagringer. Det er '
            ..'kopier av lagringene dine som modden lager. Modden skriver aldri til dine egne lagringsfiler og tar '
            ..'sikkerhetskopi av dem før den første kopien.\nI hovedmenyen velger du co-op (kopiene) eller solo '
            ..'(dine egne lagringer).'},
        {title='En delt verden',
         body='I samme område har vanlige fiender én HP-måler for dere begge og dør på begge skjermene samtidig. De '
            ..'står på samme sted i begge spillene og går etter den som traff dem sist. Bosser deler HP og '
            ..'faser.\nSom standard teller et drap for deg hvis du kjempet eller sto innen 30 m.\nMens verten ser en '
            ..'mellomsekvens, venter gjestens spill. Delte oppdrag og gjenoppliving fra vennen er slått av som '
            ..'standard. Slå dem på under Alternativer.'},
        {title='Nattoperasjon',
         body='Nattoperasjon er en overlevelsesmodus i bølger som Shift Up kuttet før lansering. En operasjon har '
            ..'fem bølger på tid. Når verten starter den under en økt, deler dere tiden og poengene. For poengene '
            ..'fra en operasjon kjøper du gjenstander.\nSkriv dette i konsollen (F10 eller ~) på en '
            ..'co-op-lagring:\ncoop nightop start: start en operasjon\ncoop nightop shop: vis gjenstandene\ncoop '
            ..'nightop buy <n>: kjøp gjenstand n\ncoop challenge: fire utfordringer med karakter'},
        {title='Doro-løp',
         body='I et Doro-løp blir begge EVE-ene til Doro. Ta først opp en løype, og løp den etterpå:\ncoop race '
            ..'record <name>: start opptaket\nF9: sett et sjekkpunkt der du står\ncoop race save: lagre løypa\ncoop '
            ..'race start <name>: start løpet (co-op-lagring)\nLøpet starter etter en nedtelling. Etter LØP! styres '
            ..'Doro som en bil og blir raskere over tid. R2 eller B-tasten gir drift. Krapp styring i høy fart gir '
            ..'også drift. Til slutt vises rangeringen.'},
        {title='Leviathan og frikameraet',
         body='Leviathan er en Naytiba som ble kuttet fra spillet. På en co-op-lagring setter coop leviathan show '
            ..'den foran deg og starter et frikamera for filming. coop leviathan off fjerner begge.\nW A S D eller Z '
            ..'Q S D: fly\nMellomrom eller E: opp\nCtrl eller C: ned\nShift: raskere\nMus: se deg rundt'},
        {title='Innstillinger',
         body='Siden Alternativer i co-op-menyen stiller inn tastene, partner-HUD-en, hvem som kan bli med, '
            ..'co-op-lagringene, kampreglene og menyens størrelse og lyder. Verdiene lagres i '
            ..'coop-settings.txt.\nSett «Menyspråk» til «Engelsk» for å lese modden på engelsk.'},
        {title='Hjelp',
         body='Still spørsmål eller finn en co-op-partner på Discord: discord.gg/tvFApEEVfj\nFor å melde en feil, '
            ..'lukk spillet. Send coop-report.txt, coop-link.log og UE4SS.log før du starter det igjen.\nMother '
            ..'Sphere-illustrasjon av timediffer24.'},
    },
    next='Neste',back='Tilbake',close='Lukk',never='Ikke vis igjen',page='Side %d av %d',row='Veiledning',
}
G.pl={
    pages={
        {title='Witaj w Stellar Blade Online',
         body='Stellar Blade Online pozwala EVE znajomego dołączyć do twojego świata przez Steam. Na razie sesja '
            ..'mieści 2 graczy. Celem jest 100 graczy.\nTen poradnik możesz otworzyć ponownie w każdej chwili z menu '
            ..'co-op (F5).'},
        {title='Wspólna gra',
         body='W świecie gry naciśnij F5, aby otworzyć menu co-op (na padzie przytrzymaj View). Pierwsza pozycja, '
            ..'„Utwórz sesję”, otwiera okno zaproszeń Steam.\nOsoba spoza twojej listy znajomych Steam może dołączyć '
            ..'za pomocą kodu. Zanim utworzysz sesję, w sekcji Opcje ustaw „Kto może dołączyć” na „Osoby z kodem”. '
            ..'Potem wyślij jej 7-znakowy kod z „Kopiuj mój kod”. Gdy ta osoba dołącza, musisz ją przyjąć.\nF6: '
            ..'status\nF8: opuść sesję\nEnter: czat\nPrzy budce telefonicznej w obozie F5 otwiera linię co-op '
            ..'zamiast menu.'},
        {title='Zapisy co-op',
         body='Wspólni wrogowie, wspólne zadania, nocna operacja, wyścigi Doro i Leviathan działają na zapisach '
            ..'co-op. To kopie twoich zapisów zrobione przez moda. Mod nigdy nie zapisuje niczego w twoich plikach '
            ..'zapisu i przed pierwszą konwersją robi ich kopię zapasową.\nW menu głównym wybierasz co-op (kopie) '
            ..'albo solo (własne zapisy).'},
        {title='Wspólny świat',
         body='Na tej samej mapie zwykli wrogowie mają jeden pasek PŻ dla was obojga i giną jednocześnie na obu '
            ..'ekranach. Stoją w tym samym miejscu w obu grach i atakują tego, kto uderzył ich ostatni. Bossowie '
            ..'dzielą PŻ i fazy.\nDomyślnie zabójstwo liczy się dla ciebie, jeśli walczysz z wrogiem lub stoisz do '
            ..'30 m od niego.\nGdy host ogląda przerywnik, gra gościa czeka. Wspólne zadania i ożywianie przez '
            ..'partnera są domyślnie wyłączone. Włącz je w sekcji Opcje.'},
        {title='Nocna operacja',
         body='Nocna operacja to tryb przetrwania z falami wrogów, który Shift Up wyciął przed premierą. Operacja to '
            ..'pięć fal na czas. Gdy host rozpocznie ją podczas sesji, dzielicie licznik czasu i punkty. Za punkty z '
            ..'operacji kupujesz przedmioty.\nWpisz te komendy w konsoli (F10 lub ~) na zapisie co-op:\ncoop nightop '
            ..'start: rozpocznij operację\ncoop nightop shop: lista przedmiotów\ncoop nightop buy <n>: kup przedmiot '
            ..'n\ncoop challenge: cztery oceniane wyzwania'},
        {title='Wyścigi Doro',
         body='W wyścigu Doro obie EVE zmieniają się w Doro. Najpierw nagraj trasę, potem ścigaj się na niej:\ncoop '
            ..'race record <name>: zacznij nagrywanie\nF9: dodaj punkt kontrolny tam, gdzie stoisz\ncoop race save: '
            ..'zapisz trasę\ncoop race start <name>: rozpocznij wyścig (zapis co-op)\nWyścig rusza po odliczaniu. Po '
            ..'sygnale START! Doro prowadzi się jak samochód i z czasem przyspiesza. R2 lub klawisz B włącza drift. '
            ..'Ostry skręt przy dużej prędkości też powoduje drift. Na koniec pojawia się klasyfikacja.'},
        {title='Leviathan i wolna kamera',
         body='Leviathan to Naytiba. Został wycięty z gry. Na zapisie co-op komenda coop leviathan show stawia go '
            ..'przed tobą i włącza wolną kamerę do filmowania. coop leviathan off usuwa jedno i drugie.\nW A S D lub '
            ..'Z Q S D: lot\nSpace lub E: w górę\nCtrl lub C: w dół\nShift: szybciej\nMysz: rozglądanie się'},
        {title='Ustawienia',
         body='Na stronie Opcje w menu co-op ustawisz klawisze, HUD partnera, to, kto może dołączyć, zapisy co-op, '
            ..'zasady walki oraz rozmiar i dźwięki menu. Wartości trafiają do coop-settings.txt.\nUstaw „Język menu” '
            ..'na „English”, aby czytać moda po angielsku.'},
        {title='Pomoc',
         body='Zadawaj pytania lub znajdź partnera do co-opa na Discordzie: discord.gg/tvFApEEVfj\nAby zgłosić błąd, '
            ..'zamknij grę. Zanim uruchomisz ją ponownie, wyślij coop-report.txt, coop-link.log i '
            ..'UE4SS.log.\nGrafika Mother Sphere: timediffer24.'},
    },
    next='Dalej',back='Wstecz',close='Zamknij',never='Nie pokazuj więcej',page='Strona %d z %d',row='Poradnik',
}
G.pt={
    pages={
        {title='Bem-vindo ao Stellar Blade Online',
         body='O Stellar Blade Online permite que a EVE de um amigo entre no teu mundo através do Steam. Por agora, '
            ..'uma sessão aceita 2 jogadores. O objetivo é chegar aos 100 jogadores.\nPodes voltar a abrir este guia a '
            ..'qualquer momento no menu co-op (F5).'},
        {title='Jogar em conjunto',
         body='Prime F5 no mundo para abrir o menu co-op (num comando, mantém View premido). A primeira opção, Criar '
            ..'uma sessão, abre a janela de convites do Steam.\nQuem não estiver na tua lista de amigos Steam pode '
            ..'entrar com um código. Antes de criar a sessão, define Quem pode entrar como Com um código nas Opções. '
            ..'Depois usa Copiar o meu código e envia-lhe o código de 7 caracteres. Quando tentar entrar, aceita o '
            ..'pedido.\nF6: estado\nF8: sair da sessão\nEnter: chat\nNa cabine telefónica de um acampamento, F5 abre a '
            ..'linha co-op em vez do menu.'},
        {title='Dados guardados co-op',
         body='Os inimigos partilhados, as missões partilhadas, a operação noturna, as corridas de Doro e Leviathan '
            ..'funcionam com dados guardados co-op. São cópias dos teus dados guardados feitas pelo mod. O mod nunca '
            ..'escreve nos teus ficheiros de dados guardados e faz uma cópia de segurança deles antes da primeira '
            ..'cópia.\nNo menu principal escolhes jogar em co-op (as cópias) ou a solo (os teus dados guardados).'},
        {title='Um mundo partilhado',
         body='No mesmo mapa, os inimigos comuns têm uma só barra de PV para os dois e morrem nos dois ecrãs ao mesmo '
            ..'tempo. Ficam no mesmo sítio nos dois jogos e vão atrás de quem lhes acertou por último. Os bosses '
            ..'partilham os PV e as fases.\nPor predefinição, um inimigo abatido conta para ti se o combateste ou '
            ..'estavas a menos de 30 m.\nEnquanto o anfitrião vê uma cinemática, o jogo do convidado espera. As '
            ..'missões partilhadas e a reanimação pelo teu parceiro estão desativadas por predefinição. Ativa-as nas '
            ..'Opções.'},
        {title='Operação noturna',
         body='A operação noturna é um modo de sobrevivência por vagas que a Shift Up cortou antes do lançamento. Cada '
            ..'operação tem cinco vagas cronometradas. Se o anfitrião a iniciar durante uma sessão, partilham o '
            ..'cronómetro e a pontuação. Com os pontos de uma operação compras objetos.\nEscreve isto na consola (F10 '
            ..'ou ~) com dados guardados co-op:\ncoop nightop start: iniciar uma operação\ncoop nightop shop: ver os '
            ..'objetos\ncoop nightop buy <n>: comprar o objeto n\ncoop challenge: quatro desafios com classificação'},
        {title='Corridas de Doro',
         body='Numa corrida de Doro, as duas EVE transformam-se em Doro. Primeiro grava um percurso e depois corre '
            ..'nele:\ncoop race record <name>: começar a gravar\nF9: colocar um ponto de controlo onde estás\ncoop '
            ..'race save: guardar o percurso\ncoop race start <name>: iniciar a corrida (dados guardados co-op)\nA '
            ..'corrida começa após uma contagem decrescente. Depois do JÁ!, o Doro comporta-se como um carro e acelera '
            ..'com o tempo. R2 ou a tecla B fazem derrapar. Virar com força a alta velocidade também faz derrapar. A '
            ..'classificação aparece no fim.'},
        {title='Leviathan e a câmara livre',
         body='Leviathan é um Naytiba cortado do jogo. Com dados guardados co-op, coop leviathan show coloca-o à tua '
            ..'frente e liga uma câmara livre para filmar. coop leviathan off remove os dois.\nW A S D ou Z Q S D: '
            ..'voar\nSpace ou E: subir\nCtrl ou C: descer\nShift: mais rápido\nRato: olhar em volta'},
        {title='Definições',
         body='A página Opções do menu co-op define as teclas, o HUD do parceiro, quem pode entrar, os dados guardados '
            ..'co-op, as regras de combate e o tamanho e os sons do menu. Os valores ficam guardados em '
            ..'coop-settings.txt.\nMuda Idioma do menu para Inglês para ler o mod em inglês.'},
        {title='Ajuda',
         body='Faz perguntas ou encontra um parceiro de co-op no Discord: discord.gg/tvFApEEVfj\nPara comunicar um '
            ..'erro, fecha o jogo. Antes de o voltares a iniciar, envia coop-report.txt, coop-link.log e '
            ..'UE4SS.log.\nArte da Mother Sphere por timediffer24.'},
    },
    next='Seguinte',back='Retroceder',close='Fechar',never='Não voltar a mostrar',page='Página %d de %d',row='Guia',
}
G['pt-BR']={
    pages={
        {title='Boas-vindas ao Stellar Blade Online',
         body='O Stellar Blade Online deixa a EVE de um amigo entrar no seu mundo pelo Steam. Por enquanto, uma '
            ..'sessão tem 2 jogadores. A meta é chegar a 100 jogadores.\nAbra este guia de novo quando quiser pelo '
            ..'menu co-op (F5).'},
        {title='Jogar junto',
         body='Aperte F5 no mundo do jogo para abrir o menu co-op (segure View no controle). A primeira linha, '
            ..'Hospedar uma sessão, abre a janela de convite do Steam.\nQuem não está na sua lista de amigos do '
            ..'Steam pode entrar com um código. Antes de hospedar, mude Quem pode entrar para Com um código nas '
            ..'Opções. Depois, envie a essa pessoa o código de 7 caracteres de Copiar meu código. Você aceita a '
            ..'pessoa quando ela entra.\nF6: status\nF8: sair da sessão\nEnter: chat\nNa cabine telefônica de um '
            ..'acampamento, F5 abre a linha co-op em vez do menu.'},
        {title='Jogos salvos co-op',
         body='Inimigos compartilhados, missões compartilhadas, Operação Noturna, corridas de Doro e Leviathan usam '
            ..'jogos salvos co-op. São cópias dos seus jogos salvos feitas pelo mod. Ele nunca grava nos seus '
            ..'próprios jogos salvos e faz um backup deles antes da primeira cópia.\nNo Menu Principal, você escolhe '
            ..'co-op (as cópias) ou solo (seus próprios jogos salvos).'},
        {title='Um mundo compartilhado',
         body='No mesmo mapa, inimigos comuns têm uma barra de PV para vocês dois e morrem nas duas telas ao mesmo '
            ..'tempo. Eles ficam no mesmo lugar nos dois jogos e vão atrás de quem os atingiu por último. Chefes '
            ..'compartilham os PV e as fases.\nPor padrão, um abate conta para você se você combateu ou estava a até '
            ..'30 m.\nEnquanto o anfitrião assiste a uma cinemática, o jogo do convidado espera. Missões '
            ..'compartilhadas e reanimação pelo seu amigo vêm desativadas por padrão. Ative-as nas Opções.'},
        {title='Operação Noturna',
         body='A Operação Noturna é um modo de sobrevivência em ondas que a Shift Up cortou antes do lançamento. Uma '
            ..'operação tem cinco ondas cronometradas. Quando o anfitrião inicia uma durante a sessão, vocês dividem '
            ..'o cronômetro e a pontuação. Os pontos de uma operação servem para comprar itens.\nDigite estes '
            ..'comandos no console (F10 ou ~) em um jogo salvo co-op:\ncoop nightop start: iniciar uma '
            ..'operação\ncoop nightop shop: listar os itens\ncoop nightop buy <n>: comprar o item n\ncoop challenge: '
            ..'quatro desafios com nota'},
        {title='Corridas de Doro',
         body='Na corrida de Doro, as duas EVEs viram Doro. Grave um percurso primeiro e depois corra nele:\ncoop '
            ..'race record <name>: começar a gravar\nF9: colocar um checkpoint onde você está\ncoop race save: '
            ..'salvar o percurso\ncoop race start <name>: começar a corrida (jogo salvo co-op)\nA corrida começa '
            ..'após uma contagem regressiva. Depois do VAI!, o Doro se controla como um carro e acelera com o tempo. '
            ..'R2 ou a tecla B faz drift. Virar forte em alta velocidade também faz drift. A classificação aparece '
            ..'no final.'},
        {title='Leviathan e a câmera livre',
         body='Leviathan é um Naytiba cortado do jogo. Em um jogo salvo co-op, coop leviathan show coloca o '
            ..'Leviathan na sua frente e inicia uma câmera livre para filmar. coop leviathan off remove os dois.\nW '
            ..'A S D ou Z Q S D: voar\nSpace ou E: subir\nCtrl ou C: descer\nShift: mais rápido\nMouse: olhar em '
            ..'volta'},
        {title='Configurações',
         body='A página Opções do menu co-op define as teclas, o HUD do parceiro, quem pode entrar, os jogos salvos '
            ..'co-op, as regras de combate e o tamanho e os sons do menu. Os valores ficam em '
            ..'coop-settings.txt.\nMude Idioma do menu para Inglês para ler o mod em inglês.'},
        {title='Ajuda',
         body='Tire dúvidas ou encontre um parceiro de co-op no Discord: discord.gg/tvFApEEVfj\nPara relatar um bug, '
            ..'feche o jogo. Antes de abrir de novo, envie coop-report.txt, coop-link.log e UE4SS.log.\nArte da '
            ..'Mother Sphere por timediffer24.'},
    },
    next='Avançar',back='Voltar',close='Fechar',never='Não mostrar de novo',page='Página %d de %d',row='Guia',
}
G.ru={
    pages={
        {title='Добро пожаловать в Stellar Blade Online',
         body='Stellar Blade Online позволяет EVE вашего друга присоединиться к вашему миру через Steam. Пока в '
            ..'сессии может быть 2 игрока. Цель — 100 игроков.\nЭто руководство можно снова открыть в любой момент в '
            ..'меню кооператива (F5).'},
        {title='Совместная игра',
         body='Нажмите F5 в игровом мире, чтобы открыть меню кооператива (на контроллере удерживайте View). Первая '
            ..'строка, "Создать сессию", открывает окно приглашений Steam.\nИгрок не из вашего списка друзей Steam '
            ..'может присоединиться по коду. Перед созданием сессии в разделе "Настройки" выберите для "Кто может '
            ..'присоединиться" значение "По коду". Затем отправьте ему код из 7 символов, полученный через '
            ..'"Скопировать мой код". Когда игрок подключается, вы принимаете его запрос.\nF6: статус\nF8: покинуть '
            ..'сессию\nEnter: чат\nУ телефонной будки в лагере F5 открывает линию кооператива вместо меню.'},
        {title='Кооперативные сохранения',
         body='Общие враги, общие задания, ночная операция, гонки Доро и Leviathan требуют кооперативных сохранений. '
            ..'Это копии ваших сохранений, которые создает мод. Он никогда не записывает в ваши собственные файлы '
            ..'сохранений и делает их резервную копию перед первым копированием.\nВ главном меню вы выбираете '
            ..'кооператив (копии) или одиночную игру (свои сохранения).'},
        {title='Общий мир',
         body='В одной локации у обычных врагов одна полоска ОЗ на вас обоих, и они погибают на обоих экранах сразу. '
            ..'Они стоят на одном и том же месте в обеих играх и атакуют того, кто ударил их последним. Боссы делят '
            ..'ОЗ и фазы.\nПо умолчанию убийство засчитывается вам, если вы сражались или были не дальше 30 м.\nПока '
            ..'хост смотрит заставку, игра гостя ждет. Общие задания и оживление другом по умолчанию выключены. '
            ..'Включите их в настройках.'},
        {title='Ночная операция',
         body='Ночная операция — режим выживания против волн врагов, который Shift Up вырезала до релиза. В операции '
            ..'пять волн на время. Если хост запускает ее во время сессии, у вас общие таймер и очки. За очки из '
            ..'операций можно купить предметы.\nВведите в консоли (F10 или ~) на кооперативном сохранении:\ncoop '
            ..'nightop start: начать операцию\ncoop nightop shop: список предметов\ncoop nightop buy <n>: купить '
            ..'предмет n\ncoop challenge: четыре испытания с оценкой'},
        {title='Гонки Доро',
         body='В гонке Доро обе EVE превращаются в Доро. Сначала запишите трассу, затем проведите на ней '
            ..'гонку:\ncoop race record <name>: начать запись\nF9: поставить контрольную точку там, где вы '
            ..'стоите\ncoop race save: сохранить трассу\ncoop race start <name>: начать гонку (кооперативное '
            ..'сохранение)\nГонка начинается после обратного отсчета. После "МАРШ!" Доро управляется как машина и со '
            ..'временем разгоняется. R2 или клавиша B: занос. Резкий поворот на скорости тоже вызывает занос. В '
            ..'конце показывается таблица мест.'},
        {title='Leviathan и свободная камера',
         body='Leviathan — это Naytiba, вырезанная из игры. На кооперативном сохранении coop leviathan show ставит '
            ..'Leviathan перед вами и включает свободную камеру для съемки. coop leviathan off убирает и то, и '
            ..'другое.\nW A S D или Z Q S D: полет\nПробел или E: вверх\nCtrl или C: вниз\nShift: быстрее\nМышь: '
            ..'обзор'},
        {title='Настройки',
         body='Раздел "Настройки" в меню кооператива задает клавиши, HUD партнера, кто может присоединиться, '
            ..'кооперативные сохранения, правила боя, размер меню и его звуки. Значения хранятся в '
            ..'coop-settings.txt.\nЧтобы читать мод на английском, выберите для "Язык меню" значение "English".'},
        {title='Помощь',
         body='Задавайте вопросы или ищите партнера для кооператива в Discord: discord.gg/tvFApEEVfj\nЧтобы сообщить '
            ..'об ошибке, закройте игру. Перед следующим запуском отправьте coop-report.txt, coop-link.log и '
            ..'UE4SS.log.\nАрт Mother Sphere: timediffer24.'},
    },
    next='Далее',back='Назад',close='Закрыть',never='Больше не показывать',page='Страница %d из %d',row='Руководство',
}
G.sv={
    pages={
        {title='Välkommen till Stellar Blade Online',
         body='Med Stellar Blade Online kan en väns EVE gå med i din värld via Steam. Just nu rymmer en session 2 '
            ..'spelare. Målet är 100 spelare.\nÖppna den här guiden igen när som helst från co-op-menyn (F5).'},
        {title='Spela tillsammans',
         body='Tryck på F5 i spelvärlden för att öppna co-op-menyn (håll in View på handkontrollen). Första raden, '
            ..'Bli värd för en session, öppnar Steams inbjudningsfönster.\nNågon som inte finns bland dina '
            ..'Steam-vänner kan gå med via kod. Ställ in Vem kan gå med på Med en kod under Alternativ innan du blir '
            ..'värd. Skicka sedan den 7 tecken långa koden från Kopiera min kod. Du accepterar personen när den går '
            ..'med.\nF6: status\nF8: lämna sessionen\nEnter: chatt\nVid en telefonkiosk i ett läger öppnar F5 '
            ..'co-op-linjen i stället för menyn.'},
        {title='Sparfiler för co-op',
         body='Delade fiender, delade uppdrag, nattinsatsen, Dorolopp och Leviathan körs på co-op-sparfiler. Det är '
            ..'kopior av dina sparfiler som modden gör. Modden skriver aldrig till dina egna sparfiler och '
            ..'säkerhetskopierar dem före den första konverteringen.\nI huvudmenyn väljer du co-op (kopiorna) eller '
            ..'solo (dina egna sparfiler).'},
        {title='En delad värld',
         body='På samma karta har vanliga fiender en gemensam hälsomätare för er båda och dör på båda skärmarna '
            ..'samtidigt. De står på samma plats i båda spelen och går efter den som träffade dem sist. Bossar delar '
            ..'hälsa och faser.\nSom standard räknas en dödad fiende som din om du bekämpade den eller stod inom 30 '
            ..'m.\nNär värden tittar på en mellansekvens väntar gästens spel. Som standard är delade uppdrag av och '
            ..'din vän kan inte återuppliva dig. Båda slås på under Alternativ.'},
        {title='Nattinsats',
         body='Nattinsatsen är ett överlevnadsläge med vågor som Shift Up tog bort före lanseringen. En insats har '
            ..'fem tidsbegränsade vågor. När värden startar den under en session delar ni tiden och poängen. För '
            ..'poängen från en insats kan du köpa föremål.\nSkriv detta i konsolen (F10 eller ~) på en '
            ..'co-op-sparfil:\ncoop nightop start: starta en insats\ncoop nightop shop: visa föremålen\ncoop nightop '
            ..'buy <n>: köp föremål n\ncoop challenge: fyra betygsatta utmaningar'},
        {title='Dorolopp',
         body='I ett Dorolopp förvandlas båda EVE till Doro. Spela först in en bana och kör sedan på den:\ncoop race '
            ..'record <name>: börja spela in\nF9: sätt en checkpoint där du står\ncoop race save: spara banan\ncoop '
            ..'race start <name>: starta loppet (co-op-sparfil)\nLoppet startar efter en nedräkning. Efter KÖR! '
            ..'styrs Doro som en bil och blir snabbare med tiden. R2 eller tangenten B ger drift. Att svänga hårt i '
            ..'hög fart ger också drift. Placeringarna visas i slutet.'},
        {title='Leviathan och den fria kameran',
         body='Leviathan är en Naytiba som togs bort ur spelet. På en co-op-sparfil placerar coop leviathan show den '
            ..'framför dig och startar en fri kamera för filmning. coop leviathan off tar bort båda.\nW A S D eller '
            ..'Z Q S D: flyg\nSpace eller E: upp\nCtrl eller C: ner\nShift: snabbare\nMus: se dig omkring'},
        {title='Inställningar',
         body='Sidan Alternativ i co-op-menyn ställer in tangenterna, medspelarens HUD, vem som kan gå med, '
            ..'co-op-sparfilerna, stridsreglerna, menyns storlek och dess ljud. Värdena sparas i '
            ..'coop-settings.txt.\nSätt Menyspråk till Engelska för att läsa modden på engelska.'},
        {title='Hjälp',
         body='Ställ frågor eller hitta en medspelare för co-op på Discord: discord.gg/tvFApEEVfj\nStäng spelet om '
            ..'du vill rapportera ett fel. Skicka coop-report.txt, coop-link.log och UE4SS.log innan du startar det '
            ..'igen.\nMother Sphere-illustration av timediffer24.'},
    },
    next='Nästa',back='Tillbaka',close='Stäng',never='Visa inte igen',page='Sida %d av %d',row='Guide',
}
G.th={
    pages={
        {title='ยินดีต้อนรับสู่ Stellar Blade Online',
         body='Stellar Blade Online ให้ EVE ของเพื่อนเข้ามาในโลกของคุณผ่าน Steam ตอนนี้เซสชันหนึ่งรองรับผู้เล่น 2 คน เป้าหมายคือ 100 '
            ..'คน\nเปิดคู่มือนี้อีกครั้งได้ทุกเมื่อจากเมนู co-op (F5)'},
        {title='เล่นด้วยกัน',
         body='กด F5 ในโลกของเกมเพื่อเปิดเมนู co-op (บนคอนโทรลเลอร์ให้กด View ค้างไว้) แถวแรก [โฮสต์เซสชัน] จะเปิดหน้าต่างเชิญของ '
            ..'Steam\nคนที่ไม่ได้อยู่ในรายชื่อเพื่อน Steam ของคุณเข้าร่วมด้วยโค้ดได้ ก่อนโฮสต์ ให้ตั้ง [ใครเข้าร่วมได้] เป็น [ใช้โค้ด] ใน '
            ..'[ตัวเลือก] จากนั้นใช้ [คัดลอกโค้ดของฉัน] แล้วส่งโค้ด 7 ตัวให้เขา เมื่อเขาขอเข้าร่วม ให้กดรับ\nF6: สถานะ\nF8: '
            ..'ออกจากเซสชัน\nEnter: แชท\nที่ตู้โทรศัพท์ในแคมป์ F5 จะเปิดสาย Co-op แทนเมนู'},
        {title='เซฟ co-op',
         body='ศัตรูร่วม แชร์เควสต์ ปฏิบัติการกลางคืน โดโรเรซ และ Leviathan ทำงานบนเซฟ co-op ซึ่งเป็นสำเนาเซฟของคุณที่ม็อดสร้างขึ้น '
            ..'ม็อดไม่เขียนลงไฟล์เซฟของคุณเองเลย และสำรองไฟล์เหล่านั้นไว้ก่อนคัดลอกครั้งแรก\nที่เมนูหลัก ให้เลือกเล่น co-op (สำเนา) '
            ..'หรือเล่นคนเดียว (เซฟของคุณเอง)'},
        {title='โลกร่วมกัน',
         body='ในแผนที่เดียวกัน ศัตรูทั่วไปมีแถบ HP เดียวสำหรับทั้งสองคน และตายบนทั้งสองจอพร้อมกัน ศัตรูอยู่ตำแหน่งเดียวกันในทั้งสองเกม '
            ..'และไล่ตามคนที่ตีมันล่าสุด บอสใช้ HP และเฟสร่วมกัน\nโดยค่าเริ่มต้น คุณจะได้รางวัลจากศัตรูที่ตาย ถ้าคุณได้ต่อสู้หรืออยู่ในระยะ 30 '
            ..'ม.\nขณะที่โฮสต์ดูคัตซีน เกมของผู้เข้าร่วมจะรอ แชร์เควสต์และการให้เพื่อนชุบชีวิตปิดอยู่โดยค่าเริ่มต้น เปิดได้ใน [ตัวเลือก]'},
        {title='ปฏิบัติการกลางคืน',
         body='ปฏิบัติการกลางคืนคือโหมดเอาชีวิตรอดแบบเป็นคลื่นที่ Shift Up ตัดออกก่อนวางจำหน่าย หนึ่งรอบมี 5 คลื่นแบบจับเวลา '
            ..'เมื่อโฮสต์เริ่มระหว่างเซสชัน คุณทั้งสองจะใช้ตัวจับเวลาและคะแนนร่วมกัน แต้มจากแต่ละรอบใช้ซื้อไอเท็ม\nพิมพ์คำสั่งเหล่านี้ในคอนโซล '
            ..'(F10 หรือ ~) บนเซฟ co-op:\ncoop nightop start: เริ่มรอบ\ncoop nightop shop: ดูรายการไอเท็ม\ncoop nightop buy '
            ..'<n>: ซื้อไอเท็มลำดับ n\ncoop challenge: ชาเลนจ์ 4 แบบที่ให้เกรด'},
        {title='โดโรเรซ',
         body='ในโดโรเรซ EVE ทั้งสองคนจะกลายเป็นโดโร บันทึกเส้นทางก่อน แล้วแข่งบนเส้นทางนั้น:\ncoop race record <name>: '
            ..'เริ่มบันทึก\nF9: เพิ่มเช็กพอยต์ตรงที่คุณยืน\ncoop race save: บันทึกเส้นทาง\ncoop race start <name>: เริ่มการแข่ง (เซฟ '
            ..'co-op)\nการแข่งเริ่มหลังนับถอยหลัง หลังขึ้น "ไป!" โดโรจะบังคับเหมือนรถและเร็วขึ้นเรื่อยๆ กด R2 หรือปุ่ม B เพื่อดริฟต์ '
            ..'เลี้ยวแรงตอนเร็วก็ดริฟต์ได้เหมือนกัน อันดับจะแสดงตอนจบ'},
        {title='Leviathan และกล้องอิสระ',
         body='Leviathan คือ Naytiba ที่ถูกตัดออกจากเกม บนเซฟ co-op คำสั่ง coop leviathan show '
            ..'จะวางมันไว้ตรงหน้าคุณและเปิดกล้องอิสระสำหรับถ่ายวิดีโอ คำสั่ง coop leviathan off จะเอาทั้งสองอย่างออก\nW A S D หรือ Z Q '
            ..'S D: บิน\nSpace หรือ E: ขึ้น\nCtrl หรือ C: ลง\nShift: เร็วขึ้น\nเมาส์: มองรอบๆ'},
        {title='ตั้งค่า',
         body='หน้า [ตัวเลือก] ของเมนู co-op ใช้ตั้งปุ่ม HUD ของคู่หู ใครเข้าร่วมได้ เซฟ co-op กฎการต่อสู้ ขนาดเมนู และเสียงเมนู ค่าต่างๆ '
            ..'เก็บไว้ใน coop-settings.txt\nตั้ง [ภาษาเมนู] เป็น [English] เพื่ออ่านม็อดเป็นภาษาอังกฤษ'},
        {title='ช่วยเหลือ',
         body='ถามคำถามหรือหาคู่หู co-op ได้ใน Discord: discord.gg/tvFApEEVfj\nหากจะรายงานบั๊ก ให้ปิดเกมก่อน และก่อนเปิดเกมอีกครั้ง '
            ..'ให้ส่ง coop-report.txt, coop-link.log และ UE4SS.log\nภาพ Mother Sphere โดย timediffer24'},
    },
    next='ถัดไป',back='กลับ',close='ปิด',never='ไม่ต้องแสดงอีก',page='หน้า %d จาก %d',row='คู่มือ',
}
G.tr={
    pages={
        {title="Stellar Blade Online'a hoş geldin",
         body="Stellar Blade Online, bir arkadaşının EVE'sinin Steam üzerinden senin dünyana katılmasını sağlar. "
            ..'Şimdilik bir oturumda 2 oyuncu olabilir. Hedef 100 oyuncu.\nBu rehberi istediğin zaman co-op '
            ..'menüsünden (F5) yeniden açabilirsin.'},
        {title='Birlikte oyna',
         body="Co-op menüsünü açmak için oyun dünyasında F5'e bas (kumandada View'u basılı tut). İlk satırdaki "
            ..'Oturum kur, Steam davet penceresini açar.\nSteam arkadaş listende olmayan biri kodla katılabilir. '
            .."Oturum kurmadan önce Seçenekler'de Kimler katılabilir ayarını Kodu olanlar yap. Sonra Kodumu kopyala "
            ..'ile aldığın 7 karakterlik kodu ona gönder. Katıldığında onu kabul edersin.\nF6: durum\nF8: oturumdan '
            ..'ayrıl\nEnter: sohbet\nBir kampın telefon kulübesinde F5, menü yerine co-op hattını açar.'},
        {title='Co-op kayıtları',
         body='Ortak düşmanlar, ortak görevler, Gece Operasyonu, Doro yarışları ve Leviathan co-op kayıtlarında '
            ..'çalışır. Bunlar, modun senin kayıtlarından aldığı kopyalardır. Mod senin kayıt dosyalarına asla '
            ..'yazmaz ve ilk kopyadan önce onları yedekler.\nAna menüde co-op (kopyalar) ile tek başına (kendi '
            ..'kayıtların) arasında seçim yaparsın.'},
        {title='Ortak bir dünya',
         body='Aynı haritada sıradan düşmanların ikiniz için tek bir can çubuğu vardır ve iki ekranda aynı anda '
            ..'ölürler. İki oyunda da aynı yerde durur ve onlara en son kim vurduysa onun peşine düşerler. Baş '
            ..'düşmanlar canlarını ve aşamalarını paylaşır.\nVarsayılan olarak, savaştıysan ya da 30 m içindeysen '
            ..'öldürme sana sayılır.\nEv sahibi ara sahne izlerken misafirin oyunu bekler. Ortak görevler ve '
            .."arkadaşının seni diriltmesi varsayılan olarak kapalıdır. Bunları Seçenekler'den aç."},
        {title='Gece Operasyonu',
         body="Gece Operasyonu, Shift Up'ın oyun çıkmadan önce kaldırdığı, dalgalara karşı hayatta kalma modudur. "
            ..'Bir operasyonda süreli beş dalga vardır. Ev sahibi oturum sırasında başlatınca süreyi ve puanı '
            ..'paylaşırsınız. Operasyondan kazanılan puanlarla eşya alınır.\nBunları bir co-op kaydındayken konsola '
            ..'(F10 ya da ~) yaz:\ncoop nightop start: operasyon başlat\ncoop nightop shop: eşyaları listele\ncoop '
            ..'nightop buy <n>: n numaralı eşyayı al\ncoop challenge: puanlanan dört meydan okuma'},
        {title='Doro yarışları',
         body="Doro yarışında iki oyuncunun EVE'si de Doro'ya dönüşür. Önce bir parkur kaydet, sonra o parkurda "
            ..'yarış:\ncoop race record <name>: kaydı başlat\nF9: durduğun yere kontrol noktası koy\ncoop race save: '
            ..'parkuru kaydet\ncoop race start <name>: yarışı başlat (co-op kaydı)\nYarış bir geri sayımdan sonra '
            ..'başlar. BAŞLA! yazısından sonra Doro araba gibi sürülür ve zamanla hızlanır. R2 ya da B tuşu drift '
            ..'yaptırır. Hızlıyken sert dönmek de drift yaptırır. Sıralama sonda görünür.'},
        {title='Leviathan ve serbest kamera',
         body="Leviathan, oyundan çıkarılmış bir Naytiba'dır. Bir co-op kaydında coop leviathan show onu önüne "
            ..'yerleştirir ve çekim için serbest kamerayı başlatır. coop leviathan off ikisini de kaldırır.\nW A S D '
            ..'ya da Z Q S D: uç\nSpace ya da E: yukarı\nCtrl ya da C: aşağı\nShift: daha hızlı\nFare: etrafa bak'},
        {title='Ayarlar',
         body="Co-op menüsünün Seçenekler sayfası tuşları, takım arkadaşı HUD'unu, kimlerin katılabileceğini, co-op "
            ..'kayıtlarını, çatışma kurallarını, menünün boyutunu ve seslerini ayarlar. Değerler coop-settings.txt '
            ..'dosyasında saklanır.\nModu İngilizce okumak için Menü dili ayarını English yap.'},
        {title='Yardım',
         body="Discord'da soru sor ya da co-op arkadaşı bul: discord.gg/tvFApEEVfj\nHata bildirmek için oyunu kapat. "
            ..'Oyunu yeniden başlatmadan önce coop-report.txt, coop-link.log ve UE4SS.log dosyalarını '
            ..'gönder.\nMother Sphere çizimi: timediffer24.'},
    },
    next='İleri',back='Geri',close='Kapat',never='Bir daha gösterme',page='Sayfa %d / %d',row='Rehber',
}
G['zh-Hans']={
    pages={
        {title='欢迎来到Stellar Blade Online',
         body='Stellar Blade Online让好友的EVE通过Steam加入你的世界。目前一个房间最多2名玩家，目标是100名。\n'
            ..'随时可在合作菜单（F5）中再次打开本指南。'},
        {title='一起玩',
         body='在游戏世界中按F5打开合作菜单（手柄上按住View）。第一行“创建房间”会打开Steam邀请窗口。\n'
            ..'不在你Steam好友列表中的玩家可以用房间码加入。创建房间前，在“选项”中将“谁可以加入”设为“凭房间码”。'
            ..'然后用“复制我的房间码”复制7位房间码，发给对方。对方加入时由你接受。\nF6：状态\nF8：离开房间\nEnter：'
            ..'聊天\n在营地的电话亭旁，F5会打开合作线路而不是菜单。'},
        {title='合作存档',
         body='共享敌人、共享任务、暗夜行动、Doro竞速和Leviathan都需要合作存档。合作存档是模组复制的存档副本。'
            ..'模组从不写入你自己的存档文件，并会在首次复制前备份它们。\n在主菜单中选择合作（使用副本）'
            ..'或单人（使用你自己的存档）。'},
        {title='共享世界',
         body='在同一地图上，普通敌人的生命条由你们两人共享，并在两边屏幕上同时死亡。它们在两边游戏中位于同一位置，'
            ..'并攻击最后击中它们的人。首领共享生命和阶段。\n默认情况下，只要你参与交战或在30米内，击杀就算你的。\n'
            ..'房主观看过场动画时，加入者的游戏会等待。共享任务和队友救起默认关闭，可在“选项”中开启。'},
        {title='暗夜行动',
         body='暗夜行动是Shift Up在发售前删减的波次生存模式。一次行动有五个限时波次。房主在房间中发起行动时，'
            ..'你们共享计时和得分。行动获得的点数可以购买物品。\n在合作存档中，于控制台（F10或~）输入：\ncoop '
            ..'nightop start：开始一次行动\ncoop nightop shop：列出物品\ncoop nightop buy <n>：购买第n件物品\ncoop '
            ..'challenge：四项评级挑战'},
        {title='Doro竞速',
         body='在Doro竞速中，两名EVE都会变成Doro。先录制赛道，再在赛道上比赛：\ncoop race record <name>：开始录制\n'
            ..'F9：在你所站的位置设置检查点\ncoop race save：保存赛道\ncoop race start <name>：开始比赛（合作存档）\n'
            ..'倒计时结束后比赛开始。“出发！”之后，Doro像汽车一样操控，并随时间加速。按R2或B键漂移。'
            ..'高速急转也会漂移。比赛结束时显示排名。'},
        {title='Leviathan与自由镜头',
         body='Leviathan是被游戏删减的Naytiba。在合作存档中，coop leviathan show会把它放在你面前，'
            ..'并开启用于拍摄的自由镜头。coop leviathan off会移除两者。\nW A S D或Z Q S D：飞行\n空格键或E：上升\n'
            ..'Ctrl或C：下降\nShift：加速\n鼠标：环顾四周'},
        {title='设置',
         body='合作菜单的“选项”页可设置按键、队友HUD、谁可以加入、合作存档、战斗规则，以及菜单的大小和音效。'
            ..'这些值保存在coop-settings.txt中。\n将“菜单语言”设为“English”即可用英文显示模组。'},
        {title='帮助',
         body='可在Discord提问或寻找合作队友：discord.gg/tvFApEEVfj\n报告错误时，请先关闭游戏，'
            ..'并在再次启动前发送coop-report.txt、coop-link.log和UE4SS.log。\nMother Sphere插画：timediffer24。'},
    },
    next='下一页',back='上一页',close='关闭',never='不再显示',page='第%d页，共%d页',row='指南',
}
G['zh-Hant']={
    pages={
        {title='歡迎來到Stellar Blade Online',
         body='Stellar Blade Online讓好友的EVE透過Steam加入你的世界。目前一個房間最多2名玩家。目標是100名玩家。'
            ..'\n隨時可從合作選單（F5）再次開啟本指南。'},
        {title='一起遊玩',
         body='在遊戲世界中按F5開啟合作選單（控制器請長按View）。第一項「建立房間」會開啟Steam邀請視窗。'
            ..'\n不在你Steam好友名單中的人可以用代碼加入。建立房間前，請先在「選項」中將「誰可以加入」'
            ..'設為「使用代碼」，再把「複製我的代碼」取得的7字元代碼傳給對方。對方加入時需要你接受。\nF6：狀態\nF8：'
            ..'離開房間\nEnter：聊天\n在營地的電話亭，F5會開啟合作線路，而不是選單。'},
        {title='合作存檔',
         body='共享敵人、共享任務、夜間行動、Doro競速和Leviathan都使用合作存檔。合作存檔是模組製作的存檔複本。'
            ..'模組絕不會寫入你自己的存檔檔案，並會在第一次轉換前先備份。\n在主選單可選擇合作（複本）'
            ..'或單人（自己的存檔）。'},
        {title='共享的世界',
         body='在同一張地圖上，一般敵人只有一條你們共用的生命值條，並在雙方畫面同時死亡。'
            ..'敵人在雙方遊戲中站在同一位置，並追擊最後打中它的人。頭目共享生命值與階段。\n預設情況下，'
            ..'只要你與敵人交戰過或在30公尺內，擊殺就會算你一份。\n主機觀看過場動畫時，加入者的遊戲會等待。'
            ..'預設會關閉共享任務，隊友也無法救起你。兩者都可在「選項」中開啟。'},
        {title='夜間行動',
         body='夜間行動是Shift Up在發售前刪除的波次生存模式。一場行動有五個限時波次。在房間中由主機發起時，'
            ..'你們共享計時與得分。行動獲得的點數可用來購買道具。\n在合作存檔中，於主控台（F10或~）輸入：\ncoop '
            ..'nightop start：開始一場行動\ncoop nightop shop：列出道具\ncoop nightop buy <n>：購買第n項道具\ncoop '
            ..'challenge：四個有評分的挑戰'},
        {title='Doro競速',
         body='在Doro競速中，兩位EVE都會變成Doro。先錄製賽道，再在賽道上比賽：\ncoop race record <name>：'
            ..'開始錄製\nF9：在你站的位置設置檢查點\ncoop race save：儲存賽道\ncoop race start <name>：'
            ..'開始比賽（合作存檔）\n比賽在倒數後開始。「出發！」之後，Doro會像汽車一樣操控，並隨時間加速。'
            ..'R2或B鍵可甩尾。高速時大幅轉向也會甩尾。結束時會顯示名次。'},
        {title='Leviathan與自由鏡頭',
         body='Leviathan是從遊戲中刪除的Naytiba。在合作存檔中，coop leviathan show會把它放在你面前，'
            ..'並開啟用於拍攝的自由鏡頭。coop leviathan off會將兩者移除。\nW A S D或Z Q S D：飛行\nSpace或E：'
            ..'上升\nCtrl或C：下降\nShift：加速\n滑鼠：環顧四周'},
        {title='設定',
         body='合作選單的「選項」頁可設定按鍵、隊友介面、誰可以加入、合作存檔、戰鬥規則，以及選單的大小與音效。'
            ..'設定值會存入coop-settings.txt。\n將「選單語言」設為「English」，模組就會以英文顯示。'},
        {title='說明',
         body='有問題或想找合作隊友，請到Discord：discord.gg/tvFApEEVfj\n要回報錯誤，請先關閉遊戲。再次啟動前，'
            ..'請傳送coop-report.txt、coop-link.log和UE4SS.log。\nMother Sphere插圖：timediffer24。'},
    },
    next='下一頁',back='上一頁',close='關閉',never='不再顯示',page='第%d頁，共%d頁',row='指南',
}
local culture=require('nightop.recruiter_text').culture
-- A table and the tables in it read G.en's word for a key they lack.
local function fallback(t,en)
    for k,v in pairs(t) do if type(v)=='table' and type(en[k])=='table' then fallback(v,en[k]) end end
    return setmetatable(t,{__index=en})
end
-- The words for the game's culture (nil when unread) and ui_language.
function G.pick(name,setting)
    local t=setting~='english' and G[culture(name)] or G.en
    if t~=G.en and not getmetatable(t) then fallback(t,G.en) end
    return t
end
return G
