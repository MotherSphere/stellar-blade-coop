-- Lily's signal (story/lily.lua): the mod's words, written as FText into rows of the game in the game's language when
-- the signal rows are in. English and French; every other language takes the English. No text key is registered
-- (this UE4SS build cannot pass the languages as a map inside PolyglotDataToText's struct parameter), so a language
-- change shows once the next Lua load writes them again. Lines: L and L2 her choice's two labels (prologue, then the
-- end of "On Time"); PT, PD, PM the prologue quest's title, description and group line; T, D "On Time"'s title and
-- description; M1 to M6 its six group lines; K1 to K5 the lines of tasks 1 to 5. The prologue's task and task 6 keep
-- the shipped "Talk to Lily" text of the task they copy, in every language. EN task lines end with no full stop, FR
-- ones with one, as the shipped tables do; the descriptions' tenses follow the shipped story quests (EN past, FR passé
-- simple). The line in quotes is the MX13-Z1-01 plate's, word for word.
local NBSP='\u{A0}' -- Inside the French quotes and before French ? and !.
local TEXT={
    en={
        L="The other signal",
        L2="About Matrix 13",
        PT="A Second Signal",
        PD="While Lily searched for the signal from Adam's hover bike, she picked up something else. She wanted to "
            .."talk to EVE about it before they set off.",
        PM="Lily picked up something while tracking the bike. She is waiting by the Tetrapod.",
        T="On Time",
        D="While Lily searched for the signal from Adam's hover bike, she picked up a second one from the Great "
            .."Desert. At 18:00 exactly, an automatic announcement from Matrix 13 station played, signed by Cryo "
            .."Technology Matrix Metropolitan Railway Co., Ltd. Someone had added one line at the end.\n\n"
            ..'"This lift stays in service so that those who left can come home."\n\n'
            .."That night, a child's voice came on the same frequency. She was calling for help, over and over. "
            .."Adam's bike came first. Lily sent the location to the Tetrapod anyway, and EVE said they would be quick.",
        M1="An announcement and a child's call are coming from Matrix 13 station, under the Great Desert. The Tetrapod "
            .."has the location. Go down to the station.",
        K1="Go to Matrix 13 station",
        M2="The station is empty, but someone kept the trains running on time. Find the way down to the distribution "
            .."level.",
        K2="Reach the distribution level",
        M3="The call said the very bottom, by the pumps. Cross the distribution level and find the pump shaft.",
        K3="Reach the pump shaft",
        M4="Climb down the pump shaft. The pump hall is at the bottom.",
        K4="Reach the pump hall",
        M5="The call came from here. Get through the pump hall and find her.",
        K5="Find the child who called",
        M6="Go back up and tell Lily what you found under the sand.",
    },
    fr={
        L="L'autre signal",
        L2="À propos de la Matrice 13",
        PT="Un second signal",
        PD="Alors qu'elle cherchait le signal de la moto d'Adam, Lily capta autre chose. Elle voulut en parler à EVE "
            .."avant leur départ.",
        PM="Lily a capté quelque chose en suivant la moto. Elle attend près du tétrapode.",
        T="À l'heure",
        D="Alors qu'elle cherchait le signal de la moto d'Adam, Lily en capta un second, venu du grand désert. Pile à "
            .."18 h, une annonce automatique de la station Matrice 13 passa, signée Métropolitain urbain Cryo Technology "
            .."Co., Ltd. Quelqu'un avait ajouté une phrase à la fin.\n\n"
            .."«"..NBSP.."Cet ascenseur reste en service pour que ceux qui sont partis puissent rentrer."..NBSP.."»\n\n"
            .."Cette nuit-là, une voix d'enfant se fit entendre sur la même fréquence. Elle appelait à l'aide, en "
            .."boucle. La moto d'Adam passait d'abord. Lily envoya quand même la position au tétrapode, et EVE promit de "
            .."faire vite.",
        M1="Une annonce et l'appel d'une enfant arrivent de la station Matrice 13, sous le grand désert. Le tétrapode "
            .."a la position. Descendez jusqu'à la station.",
        K1="Allez à la station Matrice 13.",
        M2="La station est vide, mais quelqu'un faisait encore partir les trains à l'heure. Trouvez le chemin du niveau "
            .."de distribution.",
        K2="Atteignez le niveau de distribution.",
        M3="L'appel parlait du fond, près des pompes. Traversez le niveau de distribution et trouvez le puits de "
            .."pompage.",
        K3="Atteignez le puits de pompage.",
        M4="Descendez le puits de pompage. La salle des pompes est tout en bas.",
        K4="Atteignez la salle des pompes.",
        M5="L'appel venait d'ici. Traversez la salle des pompes et retrouvez-la.",
        K5="Retrouvez l'enfant qui a appelé.",
        M6="Remontez et racontez à Lily ce que vous avez trouvé sous le sable.",
    },
}
-- The talks, one entry per subtitle window of the sequence each one borrows (story/subtitles.lua): the speaker's
-- StringTable_Seq key ('' for none), then the English and French line. The prologue fills the first 17 of
-- Subtitle_POD_1stMeetAdam_01's 21 windows, the end talk all 19 of Subtitle_POD_1stMeetAdam_02's. A line runs about
-- 15 characters a second at most, so each fits its window.
local LILY,EVE,PA='Seq_Actor_Lily','Seq_Actor_EVE','Seq_Actor_Announcement'
local function q(s) return '«'..NBSP..s..NBSP..'»' end
local TALKS={
    prologue={
        {LILY,"EVE, wait.","EVE, attends."},
        {LILY,"While I was tracking the bike's signal, I picked up something else.",
            "En cherchant le signal de la moto, j'ai capté autre chose."},
        {LILY,"An automatic announcement from Matrix 13 station. Yesterday, at 18:00 sharp.",
            "Une annonce automatique de la station Matrice 13. Hier, à 18 h pile."},
        {EVE,"Go on.","Je t'écoute."},
        {LILY,"Someone added a sentence at the end.","Quelqu'un a ajouté une phrase à la fin."},
        {EVE,"What sentence?","Laquelle"..NBSP.."?"},
        {LILY,"Listen.","Écoute."},
        {PA,'"This lift stays in service..."',q("Cet ascenseur reste en service...")},
        {PA,'"...so that those who left can come home."',q("... pour que ceux qui sont partis puissent rentrer.")},
        {EVE,"That message could be very old.","Ce message peut être très ancien."},
        {LILY,"Maybe.","Peut-être."},
        {LILY,"But last night, a child's voice came on the same frequency.",
            "Mais cette nuit, une voix d'enfant est apparue sur la même fréquence."},
        {LILY,"She's calling for help. Over and over.","Elle appelle à l'aide. En boucle."},
        {EVE,"Adam's bike comes first.","La moto d'Adam passe d'abord."},
        {LILY,"I know. But if someone's still alive down there...",
            "Je sais. Mais s'il y a quelqu'un de vivant là-dessous..."},
        {EVE,"...","..."},
        {EVE,"Send the location to the Tetrapod. We'll be quick.","Envoie la position au tétrapode. On fait vite."},
    },
    -- On arrival at Matrix 13 station, all 9 windows of Subtitle_POD_ArriveDED_01.
    arrival={
        {EVE,"Lily. Give me a report.","Lily, fais-moi le point."},
        {LILY,"Uh... right. One second.","Euh... oui. Une seconde."},
        {LILY,"The signal's source is right here.","La source du signal est juste ici."},
        {LILY,"The call comes from below.","L'appel vient d'en bas."},
        {EVE,"Why not yesterday?","Pourquoi pas hier"..NBSP.."?"},
        {LILY,"I thought it was an old recording. And there was the bike...",
            "Je croyais à un vieil enregistrement. Et il y avait la moto..."},
        {LILY,"Then that voice came on. I couldn't keep it to myself.",
            "Puis cette voix est arrivée. Je ne pouvais pas me taire."},
        {EVE,"Stay focused. We'll be quick.","Reste concentrée. On fait vite."},
        {EVE,"Then Raven. And the bike.","Ensuite, Raven. Et la moto."},
    },
    finale={
        {LILY,"EVE.","EVE."},
        {LILY,"I lost you the moment you went down.","Je t'ai perdue dès que tu es descendue."},
        {LILY,"What did you find down there?","Qu'est-ce que tu as trouvé, en bas"..NBSP.."?"},
        {EVE,"A little girl. Noa.","Une petite fille. Noa."},
        {EVE,"A phone rang halfway down. It was her.","Un téléphone a sonné à mi-chemin. C'était elle."},
        {EVE,"We talked all the way down.","On a parlé jusqu'en bas."},
        {LILY,"Is she...?","Elle est..."..NBSP.."?"},
        {EVE,"By a few minutes, Lily.","À quelques minutes près, Lily."},
        {EVE,"The air went bad at midnight. She fell asleep.","L'air avait tourné à minuit. Elle s'est endormie."},
        {LILY,"...","..."},
        {LILY,"We only caught her call before dawn.","On n'a capté son appel qu'avant l'aube."},
        {EVE,"I know.","Je sais."},
        {EVE,"A man came back for them. Yohan.","Un homme était revenu pour elles. Yohan."},
        {EVE,"He asked me to find citizen 303.","Il m'a demandé de retrouver la citoyenne 303."},
        {LILY,"Then we'll find her.","Alors on la retrouvera."},
        {LILY,"And the band has changed.","Et la fréquence a changé."},
        {LILY,"A new voice, after the station's announcement.","Une nouvelle voix, après l'annonce de la station."},
        {LILY,"A woman, Mila. She says don't come back down. That she's coming up.",
            "Une femme, Mila. Elle dit de ne pas redescendre. Qu'elle remonte."},
        {EVE,"Keep listening, Lily.","Reste à l'écoute, Lily."},
    },
}
-- The game's text culture (GetCurrentLanguage) as one of TEXT's: French for any French culture, else English.
local function culture(name) return require('nightop.recruiter_text').culture(name)=='fr' and 'fr' or 'en' end
return {TEXT=TEXT,TALKS=TALKS,culture=culture}
