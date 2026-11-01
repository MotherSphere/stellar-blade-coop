-- The end talk, one entry per subtitle window of the sequence it borrows (story/subtitles.lua
-- plays it): the speaker's StringTable_Seq key ('' for none), then the English and French line.
-- A line longer than its window can be read at about 15 characters a second gets a reading hold (story/subtitles.lua).
-- Lily heard EVE up to the stair down into zone 4, where the comm cut for good: she knows Noa's and Yohan's calls,
-- not what came after. All 19 windows of Subtitle_POD_1stMeetAdam_02; Mila's broadcast has no speaker.
local NBSP='\u{A0}' -- Inside the French quotes and before French ? and !.
local LILY,EVE='Seq_Actor_Lily','Seq_Actor_EVE'
local function q(s) return '«'..NBSP..s..NBSP..'»' end
return {
    {LILY,"EVE, there you are!","EVE, te voilà"..NBSP.."!"},
    {LILY,"I lost you on the stairs, nothing was getting through.",
        "Je t'ai perdue dans l'escalier, plus rien ne passait."},
    {LILY,"And Noa? Did you get there in time?","Et Noa"..NBSP.."? Tu es arrivée à temps"..NBSP.."?"},
    {EVE,"...","..."},
    {EVE,"No... by a few minutes, Lily.","Non... à quelques minutes près, Lily."},
    {LILY,"...","..."},
    {EVE,"She fell asleep by the radio, counting.","Elle s'est endormie près de la radio, en comptant."},
    {LILY,"And Yohan?","Et Yohan"..NBSP.."?"},
    {EVE,"He tried to open the door to get her some air, but he never got up.",
        "Il a voulu ouvrir la porte pour lui donner de l'air, mais il ne s'est pas relevé."},
    {LILY,"We only heard her before dawn...","On ne l'a entendue qu'avant l'aube..."},
    {LILY,"And the first lift didn't go down until 06:20. We couldn't have been faster.",
        "Et le premier ascenseur ne descendait qu'à 6"..NBSP.."h"..NBSP.."20. On ne pouvait pas faire plus vite."},
    {EVE,"I know.","Je sais."},
    {EVE,"There's still citizen 303, the one Yohan wanted us to tell.",
        "Il reste la citoyenne 303, celle que Yohan voulait prévenir."},
    {LILY,"Then we'll find her, I promise.","Alors on la retrouvera, je te le promets."},
    {LILY,"There's something else... the band changed after you came out.",
        "Il y a autre chose... la fréquence a changé depuis ta sortie."},
    {LILY,"Listen.","Écoute."},
    {'','"This is Mila, crane operator, Matrix 13."',q("Ici Mila, grutière à la Matrice 13.")},
    {'','"Yohan came back for us. Don\'t come back down... I\'m coming up."',
        q("Yohan est revenu pour nous. Ne redescendez pas... je remonte.")},
    {EVE,"Keep listening, Lily.","Reste à l'écoute, Lily."},
}
