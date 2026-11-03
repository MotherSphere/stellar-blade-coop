-- Lily's prologue talk, one entry per subtitle window of the sequence it borrows (story/subtitles.lua
-- plays it): the speaker's StringTable_Seq key ('' for none), then the English and French line.
-- It fills the first 17 of Subtitle_POD_1stMeetAdam_01's 21 windows.
-- A line longer than its window can be read at about 15 characters a second gets a reading hold (story/subtitles.lua).
local NBSP='\u{A0}' -- Inside the French quotes and before French ? and !.
local LILY,EVE,PA='Seq_Actor_Lily','Seq_Actor_EVE','Seq_Actor_Announcement'
local function q(s) return '«'..NBSP..s..NBSP..'»' end
return {
    {LILY,"EVE, wait a second.","EVE, attends une seconde."},
    {LILY,"While I was tracking the bike's signal, I picked up something else on an old railway band.",
        "En cherchant le signal de la moto, j'ai capté autre chose sur une vieille fréquence ferroviaire."},
    {LILY,"An automatic announcement from Matrix 13 station, yesterday evening at 18:00 sharp.",
        "Une annonce automatique de la station Matrice 13, hier soir, à 18"..NBSP.."h pile."},
    {EVE,"Go on, I'm listening.","Continue, je t'écoute."},
    {LILY,"Someone added a sentence at the end of the message.","Quelqu'un a ajouté une phrase à la fin du message."},
    {EVE,"What sentence?","Quelle phrase"..NBSP.."?"},
    {LILY,"Here, listen.","Écoute, je te la passe."},
    {PA,'"This lift stays in service..."',q("Cet ascenseur reste en service...")},
    {PA,'"...so that those who left can come home."',q("... pour que ceux qui sont partis puissent rentrer.")},
    {EVE,"That message could be years old.","Ce message pourrait dater de plusieurs années."},
    {LILY,"Maybe, yes...","Peut-être, oui..."},
    {LILY,"But during the night, a child's voice came on the same frequency, right after the announcement.",
        "Mais cette nuit, une voix d'enfant est apparue sur la même fréquence, juste après l'annonce."},
    {LILY,"She's calling for help, again and again...","Elle appelle à l'aide, encore et encore..."},
    {EVE,"Lily, Adam's bike comes first. You know that.","Lily, la moto d'Adam passe d'abord, tu le sais."},
    {LILY,"I know, but if someone's still alive down there, we can't act like we never heard it.",
        "Je sais, mais s'il y a quelqu'un de vivant là-dessous, on ne peut pas faire comme si on n'avait rien "
        .."entendu."},
    {EVE,"... All right.","... D'accord."},
    {EVE,"Send the location to the Tetrapod. We'll be quick.","Envoie la position au tétrapode, on fera vite."},
}
