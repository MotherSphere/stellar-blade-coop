-- The arrival talk, one entry per subtitle window of the sequence it borrows (story/subtitles.lua
-- plays it): the speaker's StringTable_Seq key ('' for none), then the English and French line.
-- On arrival at Matrix 13 station, all 9 windows of Subtitle_POD_ArriveDED_01. The French is the user's own.
local LILY,EVE='Seq_Actor_Lily','Seq_Actor_EVE'
return {
    {EVE,"Lily, give me a report on that signal.","Lily, fais-moi un rapport sur ce signal."},
    {LILY,"Uh... right. One second.","Euh... oui. Une seconde."},
    {LILY,"The signal's source is right here.","La source du signal est juste ici."},
    {LILY,"The call comes from below, it's a lot like Matrix 11...",
        "L'appel vient d'en bas, c'est très similaire à Matrice 11..."},
    {EVE,"I'd like to know why you didn't mention it sooner.",
        "J'aimerais savoir pourquoi tu n'en as pas parlé plus tôt."},
    {LILY,"I thought it was an old recording. And there was the bike...",
        "Je croyais à un vieil enregistrement. Et il y avait la moto..."},
    {LILY,"Then that voice came on, and I couldn't keep quiet.",
        "Puis cette voix est arrivée et je ne pouvais pas me taire."},
    {EVE,"... Lily, stay focused. We have to be quick.","... Lily, reste concentrée. On doit faire vite."},
    {EVE,"And then, Raven and the bike.","Et ensuite, Raven et la moto."},
}
