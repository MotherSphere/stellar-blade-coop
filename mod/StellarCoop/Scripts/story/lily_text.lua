-- Lily's signal (story/lily.lua): the mod's words, written as FText into rows of the game in the game's language when
-- the signal rows are in. English and French; every other language takes the English. No text key is registered
-- (this UE4SS build cannot pass the languages as a map inside PolyglotDataToText's struct parameter), so a language
-- change shows once the next Lua load writes them again. Lines: L her choice's label, T the quest's title, D its
-- description, M1 and M2 its two group lines, K1 task 1's line. Task 2 keeps the shipped "Talk to Lily" text of the
-- task it copies, in every language. EN task lines end with no full stop, FR ones with one, as the shipped tables do;
-- the description's tenses follow the shipped story quests (EN past, FR passé simple). The line in quotes is the
-- MX13-Z1-01 plate's, word for word.
local NBSP='\u{A0}' -- Inside the French quotes.
local TEXT={
    en={
        L="The other signal",
        T="On Time",
        D="While Lily searched for the signal from Adam's hover bike, she picked up a second one. It came from the "
            .."Great Desert at 18:00 exactly. It was a service announcement from Matrix 13 station, signed by Cryo "
            .."Technology Matrix Metropolitan Railway Co., Ltd. Someone had added one line at the end.\n\n"
            ..'"This lift stays in service so that those who left can come home."\n\n'
            .."Lily sent the location to the Tetrapod. Adam came first, she said, and the choice was EVE's.",
        M1="An announcement from Matrix 13 station is coming from the Great Desert. The Tetrapod has the location. "
            .."Go down to the station.",
        K1="Go to Matrix 13 station",
        M2="Go back up and tell Lily what you found under the sand.",
    },
    fr={
        L="L'autre signal",
        T="À l'heure",
        D="Alors qu'elle cherchait le signal de la moto d'Adam, Lily en capta un second. Il venait du grand désert, "
            .."pile à 18 h. C'était une annonce de service de la station Matrice 13, signée Métropolitain urbain Cryo "
            .."Technology Co., Ltd. Quelqu'un avait ajouté une phrase à la fin.\n\n"
            .."«"..NBSP.."Cet ascenseur reste en service pour que ceux qui sont partis puissent rentrer."..NBSP.."»\n\n"
            .."Lily envoya la position au tétrapode. Adam passait d'abord, dit-elle, et le choix revenait à EVE.",
        M1="Une annonce de la station Matrice 13 arrive du grand désert. Le tétrapode a la position. Descendez "
            .."jusqu'à la station.",
        K1="Allez à la station Matrice 13.",
        M2="Remontez et racontez à Lily ce que vous avez trouvé sous le sable.",
    },
}
-- The game's text culture (GetCurrentLanguage) as one of TEXT's: French for any French culture, else English.
local function culture(name) return require('nightop.recruiter_text').culture(name)=='fr' and 'fr' or 'en' end
return {TEXT=TEXT,culture=culture}
