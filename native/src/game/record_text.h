// Matrix XIII's 25 records, the words game/camp_text.h adds to SB's live StringTable_Records: each record's title and text
// in French and English. Copied from the lore bible (v3) and its story file by a one-off script, line breaks kept, with
// the Yohan and Noa canon edits on MX13-Z3-04 and MX13-Z4-04. Memorysticks open and close on "... ... ...", documents do
// not. Every non-ASCII character is a \u escape so the compiler's source charset never matters. The keys must never
// change: the album and puzzle rows name them (data/mxiii-world.json, the mxrecords batch).
#pragma once

namespace coop::camp_text {
constexpr Entry kRecordEntries[] = {
    {u"Records_MX13_Z1_04_Title", u"Souvenirs du citoyen 157", u"Citizen 157's Memory"},
    {u"Records_MX13_Z1_04_Desc",
     u"... ... ...\n"
     u"L'ascenseur de 6 h 20 est encore descendu plein. Des larves. Quatre, cette fois.\n"
     u"Le chef de gare refuse de couper l'ascenseur. Il dit que les vingt-quatre rentreront par l\u00e0.\n"
     u"Je lui ai dit que personne ne rentrerait.\n"
     u"Il a quand m\u00eame chang\u00e9 le jour sur le tableau.\n"
     u"... ... ...",
     u"... ... ...\n"
     u"The 06:20 lift came down full again. Creepers. Four this time.\n"
     u"The station master won't switch the lift off. He says the twenty-four will come home on it.\n"
     u"I told him nobody is coming home.\n"
     u"He changed the day on the board anyway.\n"
     u"... ... ..."},
    {u"Records_MX13_Z2_03_Title", u"Souvenirs de la citoyenne 76", u"Citizen 76's Memory"},
    {u"Records_MX13_Z2_03_Desc",
     u"... ... ...\n"
     u"L'avis nous disait d'attendre dans le train. Alors on a attendu dans le train.\n"
     u"Six ans dans la voiture 14. Deux enfants sont n\u00e9s dans la voiture 11.\n"
     u"Quand le chef de gare a besoin de la voie, il nous avance d'une longueur de voiture. Les tasses glissent au bout de la table, on les rattrape et on rit.\n"
     u"Chaque matin, le train de 7 h 10 passe \u00e0 l'heure. On pourrait r\u00e9gler sa montre dessus.\n"
     u"... ... ...",
     u"... ... ...\n"
     u"The notice told us to wait in the train. So we waited in the train.\n"
     u"Six years in car 14. Two children were born in car 11.\n"
     u"When the station master needs the siding, he moves us forward one car length. The cups slide to the end of the table, and we catch them and laugh.\n"
     u"Every morning the 07:10 goes by on time. You could set a watch by it.\n"
     u"... ... ..."},
    {u"Records_MX13_Z3_03_Title", u"Souvenirs de Bram", u"Bram's Memory"},
    {u"Records_MX13_Z3_03_Desc",
     u"... ... ...\n"
     u"La passerelle a c\u00e9d\u00e9 sous moi. D'ici, je vois la lampe de la deuxi\u00e8me halte.\n"
     u"Ma jambe ne bouge plus. Les grillons se taisent pour l'instant.\n"
     u"Ines, les filtres neufs sont dans mon sac. Troisi\u00e8me baie, c\u00f4t\u00e9 gauche.\n"
     u"Dites \u00e0 Pia que j'ai fini le service de nuit.\n"
     u"... ... ...",
     u"... ... ...\n"
     u"The walkway gave way under me. From here I can see the lamp of the second rest stop.\n"
     u"My leg won't move. The Crickets are quiet for now.\n"
     u"Ines, the new filters are in my bag. Third bay, left side.\n"
     u"Tell Pia I finished the night shift.\n"
     u"... ... ..."},
    {u"Records_MX13_Z3_05_Title", u"Le doute de Silas", u"Silas's Doubt"},
    {u"Records_MX13_Z3_05_Desc",
     u"... ... ...\n"
     u"Fr\u00e8re Aldo dit que l'eau, en bas, est l'\u00e9preuve, et que le Chapitre attend de l'autre c\u00f4t\u00e9.\n"
     u"J'ai mesur\u00e9 les marques sur le mur. L'eau monte d'une main par jour. C'est une pompe en panne.\n"
     u"Le chef de gare nous a donn\u00e9 des canettes et nous a mis dans le train. Il a demand\u00e9 \u00e0 chacun de nous si nous avions vu vingt-trois personnes dans le d\u00e9sert.\n"
     u"Je suis rest\u00e9 \u00e0 l'ascenseur. Je ne me noierai pas pour une pompe en panne.\n"
     u"M\u00e8re, pardonne-moi d'\u00eatre rest\u00e9 en arri\u00e8re.\n"
     u"... ... ...",
     u"... ... ...\n"
     u"Brother Aldo says the water below is the trial, and the Chapter waits on the other side.\n"
     u"I measured the marks on the wall. The water rises a hand's width a day. That is a broken pump.\n"
     u"The station master gave us cans and put us on the train. He asked each of us if we had seen twenty-three people in the desert.\n"
     u"I stayed at the lift. I will not drown for a broken pump.\n"
     u"Mother, forgive me for staying behind.\n"
     u"... ... ..."},
    {u"Records_MX13_Z4_06_Title", u"Souvenirs de Mila", u"Mila's Memory"},
    {u"Records_MX13_Z4_06_Desc",
     u"... ... ...\n"
     u"Jour 2495, 2 h 10. Salle des ventilateurs. Ils sont arr\u00eat\u00e9s depuis 23 h 50.\n"
     u"Le premier mur est juste \u00e0 c\u00f4t\u00e9 de la porte. La chose de la vidange 1 dort au milieu de la salle.\n"
     u"J'ai dit \u00e0 Noa de compter jusqu'\u00e0 mille. \u00c7a m'a pris bien plus longtemps.\n"
     u"Continue de compter, Noa.\n"
     u"... ... ...",
     u"... ... ...\n"
     u"Day 2,495, 02:10. Fan room. The fans have been off since 23:50.\n"
     u"The first wall is right by the door. The thing from drain 1 is asleep in the middle of the room.\n"
     u"I told Noa to count to a thousand. It took me much longer than that.\n"
     u"Keep counting, Noa.\n"
     u"... ... ..."},
    {u"Records_MX13_Z4_04_Title", u"Souvenirs de Yohan", u"Yohan's Memory"},
    {u"Records_MX13_Z4_04_Desc",
     u"... ... ...\n"
     u"L'eau a quitt\u00e9 la porte, Noa. EVE a lanc\u00e9 les vidanges, comme tu l'avais dit.\n"
     u"Tu ne r\u00e9ponds plus depuis 16 h 50. Je t'ai couverte avec le manteau de Ruben.\n"
     u"Ta maman est vivante. Elle va venir.\n"
     u"Si j'ouvre la porte, le bon air va rentrer. Alors tu te r\u00e9veilleras.\n"
     u"Quelqu'un m'attend dans les Terres d\u00e9sol\u00e9es. J'avais dit que je serais rentr\u00e9 avant le lever du soleil. \u00c7a fait sept levers de soleil.\n"
     u"Tu as gard\u00e9 le secret de la lettre, comme je te l'avais demand\u00e9.\n"
     u"... ... ...",
     u"... ... ...\n"
     u"The water's off the door, Noa. EVE ran the drains, like you said she would.\n"
     u"You stopped answering at 16:50. I put Ruben's coat over you.\n"
     u"Your mom's alive. She's coming.\n"
     u"If I open the door, the good air comes in. Then you'll wake up.\n"
     u"Someone is waiting for me in the Wasteland. I said I'd be back before sunrise. That's seven sunrises now.\n"
     u"You kept the secret of the letter, like I asked.\n"
     u"... ... ..."},
    {u"Records_MX13_Z4_05_Title", u"Souvenirs du chef de gare Ruben", u"Station Master Ruben's Memory"},
    {u"Records_MX13_Z4_05_Desc",
     u"... ... ...\n"
     u"Jour 2495. Le relais affiche un d\u00e9faut sur la voie 1 \u00e0 7 h 10. Personne n'a d\u00e9gag\u00e9 la voie ce matin.\n"
     u"Quelqu'un est descendu par l'ascenseur de 6 h 20. Les secteurs du niveau 2 se rallument l'un apr\u00e8s l'autre.\n"
     u"J'ai r\u00e9gl\u00e9 l'horaire pour qu'il tourne sans moi. L'ascenseur monte \u00e0 6 h et \u00e0 18 h. Le train de 7 h 10 arrive sur la voie 1.\n"
     u"Yohan a port\u00e9 Noa jusqu'ici. L'air est meilleur pr\u00e8s du r\u00e9acteur.\n"
     u"Quand ils rentreront, le train sera \u00e0 l'heure.\n"
     u"... ... ...",
     u"... ... ...\n"
     u"Day 2,495. The relay shows a fault on track 1 at 07:10. Nobody cleared the track this morning.\n"
     u"Someone came down on the 06:20. The sectors of level 2 are coming on one after another.\n"
     u"I have set the timetable to run without me. The lift goes up at 06:00 and 18:00. The 07:10 comes in on track 1.\n"
     u"Yohan has carried Noa in here. The air is better by the drive.\n"
     u"When they come home, the train will be on time.\n"
     u"... ... ..."},
    {u"Records_MX13_00_Title", u"Des trains sous le sable", u"Trains Under the Sand"},
    {u"Records_MX13_00_Desc",
     u"J'ai encore entendu des trains cette nuit, sous les dunes, ici.\n"
     u"Les trains de la matrice 11 sont arr\u00eat\u00e9s depuis longtemps. Ceux-l\u00e0 roulent encore.\n"
     u"J'ai trouv\u00e9 une t\u00eate d'ascenseur \u00e0 moiti\u00e9 ensabl\u00e9e. Elle a du courant, et une antenne.\n"
     u"Sur l'ancienne fr\u00e9quence de la ligne, un homme lit des horaires d'ascenseur. Mont\u00e9e \u00e0 6 h et \u00e0 18 h.\n"
     u"Cette nuit, une deuxi\u00e8me voix est venue apr\u00e8s la sienne. Une enfant, toujours les m\u00eames mots.\n"
     u"Je ne descends pas seul.",
     u"I heard trains again last night, under the dunes, right here.\n"
     u"The trains in Matrix 11 stopped long ago. These ones still run.\n"
     u"Found a lift head half buried in the sand. It has power, and a mast.\n"
     u"On the line's old frequency a man reads out lift times. Up at 06:00 and 18:00.\n"
     u"Tonight a second voice came on after his. A child, the same words over and over.\n"
     u"I'm not going down alone."},
    {u"Records_MX13_Z1_05_Title", u"Le bout de la ligne", u"End of the Line"},
    {u"Records_MX13_Z1_05_Desc",
     u"Mes fr\u00e8res et mes s\u0153urs,\n"
     u"le Chapitre nous attend au bout de la ligne, l\u00e0 o\u00f9 l'eau dort.\n"
     u"Nous prenons le prochain train vers le bas. Marquez chaque arr\u00eat pour ceux qui suivront.\n"
     u"Aldo",
     u"Brothers and Sisters,\n"
     u"the Chapter waits at the end of the line, where the water sleeps.\n"
     u"We take the next train down. Mark every stop for those who follow.\n"
     u"Aldo"},
    {u"Records_MX13_Z1_07_Title", u"Pour Yohan", u"For Yohan"},
    {u"Records_MX13_Z1_07_Desc",
     u"Pour Yohan.\n"
     u"Maman et moi, on est descendues aider aux pompes. Le chef de gare dit que tu rentreras par l'ascenseur de 18 h 20. J'ai compt\u00e9\u00a0: \u00e7a fait 35 jours que tu es parti.\n"
     u"Tu as vu la ville\u00a0? Rapporte-moi quelque chose de l\u00e0-bas. Une vraie feuille, s'il y a des arbres.\n"
     u"Je t'ai gard\u00e9 ma canette.\n"
     u"Noa\n"
     u"\n"
     u"En dessous, d'une autre \u00e9criture\u00a0:\n"
     u"Je suis rentr\u00e9. Il n'y a pas de ville. Je descends vous chercher. Y.",
     u"For Yohan.\n"
     u"Mom and I went down to help with the pumps. The station master says you will come back on the 18:20 lift. I counted. You've been gone 35 days.\n"
     u"Did you see the city? Bring me something from there. A real leaf, if they have trees.\n"
     u"I saved you my can.\n"
     u"Noa\n"
     u"\n"
     u"Below, in another hand:\n"
     u"I'm back. There is no city. I'm coming down to get you. Y."},
    {u"Records_MX13_Z2_05_Title", u"Gardez cette porte ferm\u00e9e", u"Keep This Door Shut"},
    {u"Records_MX13_Z2_05_Desc",
     u"\u00c9quipe des pompes.\n"
     u"Cette porte ne s'ouvre que de ce c\u00f4t\u00e9. Refermez-la derri\u00e8re vous.\n"
     u"Les larves descendent avec l'ascenseur maintenant. La nuit, elles sont \u00e0 ce niveau.\n"
     u"Les caisses de cellules des secteurs du haut ne sont jamais descendues. Si vous en croisez une, prenez-la.\n"
     u"Ines",
     u"Pump team.\n"
     u"This door only opens from this side. Close it behind you.\n"
     u"The Creepers come down with the lift now. At night they are on this level.\n"
     u"The crates of cells from the upper sectors never came down. If you pass one, bring it.\n"
     u"Ines"},
    {u"Records_MX13_Z3_04_Title", u"Tableau de la halte", u"Rest Stop Board"},
    {u"Records_MX13_Z3_04_Desc",
     u"2455. Bram n'est pas revenu du service de nuit. Pia\n"
     u"2466. L'eau atteint la deuxi\u00e8me marque. Mila est l\u00e0 avec Noa. Trop jeune pour le puits, je l'ai dit. Ines\n"
     u"2472. Yohan est pass\u00e9 chercher Noa. Mila a dit oui, pour deux semaines. Pia\n"
     u"2478. Toujours pas de caisses de cellules d'en haut. Oren\n"
     u"2488. Yohan est pass\u00e9 \u00e0 21 h 10, il descendait, avec Noa. Pia\n"
     u"2491. Cinq adeptes sont pass\u00e9s. Ils cherchaient le bout de la ligne. Oren\n"
     u"2493. Les adeptes sont entr\u00e9s dans la salle des pompes ce matin. Ils n'ont pas attendu Ines. Pia\n"
     u"2494. Troisi\u00e8me marque cette nuit. Tout le monde \u00e0 la salle des pompes. Ines\n"
     u"2494. Chef de gare, 21 h 40, je descends. Ruben",
     u"2,455. Bram did not come back from the night shift. Pia\n"
     u"2,466. Water at the second mark. Mila is here with Noa. Too young for the shaft, I said. Ines\n"
     u"2,472. Yohan came by for Noa. Mila said yes, for two weeks. Pia\n"
     u"2,478. Still no crates of cells from upstairs. Oren\n"
     u"2,488. Yohan went by at 21:10, going down, with Noa. Pia\n"
     u"2,491. Five believers went by. They asked for the end of the line. Oren\n"
     u"2,493. The believers went into the pump hall this morning. They did not wait for Ines. Pia\n"
     u"2,494. Third mark tonight. Everyone to the pump hall. Ines\n"
     u"2,494. Station master, 21:40, going down. Ruben"},
    {u"Records_MX13_Z1_01_Title", u"Horaires de l'ascenseur de surface", u"Surface Lift Times"},
    {u"Records_MX13_Z1_01_Desc",
     u"Ascenseur de surface, station Matrice 13.\n"
     u"Mont\u00e9e \u00e0 6 h et \u00e0 18 h. Descente \u00e0 6 h 20 et \u00e0 18 h 20.\n"
     u"Cet ascenseur reste en service pour que ceux qui sont partis puissent rentrer.\n"
     u"La t\u00eate d'ascenseur diffuse ces horaires sur la fr\u00e9quence de la ligne, pour ceux qui sont dehors.\n"
     u"Ne bloquez pas les portes. Ne le coupez pas.\n"
     u"Ruben, chef de gare",
     u"Surface lift, Matrix 13 station.\n"
     u"Up at 06:00 and 18:00. Down at 06:20 and 18:20.\n"
     u"This lift stays in service so that those who left can come home.\n"
     u"The lift head reads these times out on the line frequency, for anyone outside.\n"
     u"Do not block the doors. Do not switch it off.\n"
     u"Ruben, station master"},
    {u"Records_MX13_Z1_02_Title", u"Consignes du chef de gare", u"Station Master's Orders"},
    {u"Records_MX13_Z1_02_Desc",
     u"M\u00e9tropolitain urbain Cryo Technology Co., Ltd.\n"
     u"Station Matrice 13. Consignes du jour.\n"
     u"1. Changer le jour de service sur le tableau du hall.\n"
     u"2. D\u00e9gager la voie 1 jusqu'au butoir avant le train de 7 h 10.\n"
     u"3. Relever les jauges du r\u00e9acteur \u00e0 fusion sur le tableau de ligne.\n"
     u"4. Une canette par citoyen au distributeur. Vitcoins uniquement.\n"
     u"Le R\u00c9SEAU reviendra. Ce jour-l\u00e0, cette ligne sera \u00e0 l'heure.\n"
     u"Ruben, chef de gare\n"
     u"\n"
     u"Au stylo, en dessous\u00a0:\n"
     u"Jour 2494, 18 h 30. Troisi\u00e8me marque cette nuit. Je descends garder la salle du r\u00e9acteur au sec. Les plaques de demain sont sur l'escabeau. De retour avant le train de 7 h 10. R.",
     u"Cryo Technology Matrix Metropolitan Railway Co., Ltd.\n"
     u"Matrix 13 station. Daily orders.\n"
     u"1. Change the service day on the hall board.\n"
     u"2. Clear track 1 up to the buffer before the 07:10 train.\n"
     u"3. Read the Fusion Drive gauges on the line board.\n"
     u"4. One can per citizen from the vending machine. Vitcoins only.\n"
     u"The NETWORK will come back. On that day this line will be on time.\n"
     u"Ruben, station master\n"
     u"\n"
     u"In pen, below:\n"
     u"Day 2,494, 18:30. Third mark tonight. Going down to keep the drive room dry. Tomorrow's plates are on the ladder. Back before the 07:10. R."},
    {u"Records_MX13_Z2_01_Title", u"D\u00e9lestage", u"Load Shedding"},
    {u"Records_MX13_Z2_01_Desc",
     u"Jour 2470. D\u00e9lestage.\n"
     u"Cinq secteurs de ce niveau sont coup\u00e9s jusqu'\u00e0 nouvel ordre. Leurs cellules \u00e0 fusion partent aux pompes.\n"
     u"Les cellules sont rang\u00e9es dans les caisses de ce niveau, marqu\u00e9es POMPES. Descendez-les au prochain service.\n"
     u"Quatre secteurs restent aliment\u00e9s\u00a0: l'ascenseur, la ligne, l'eau et les voitures-lits.\n"
     u"Une cellule remise dans sa prise rallume son secteur.\n"
     u"Ruben, chef de gare",
     u"Day 2,470. Load shedding.\n"
     u"Five sectors of this level are cut until further notice. Their Fusion Cells go to the pumps.\n"
     u"The cells are in the supply crates on this level, marked PUMPS. Take them down on the next shift.\n"
     u"Four sectors stay on: the lift, the line, the water and the sleeping cars.\n"
     u"A cell put back in its socket turns its sector on again.\n"
     u"Ruben, station master"},
    {u"Records_MX13_Z3_01_Title", u"Tableau de l'\u00e9quipe des pompes", u"Pump Team Rota"},
    {u"Records_MX13_Z3_01_Desc",
     u"\u00c9quipe des pompes. Services de douze heures.\n"
     u"Jour\u00a0: Ines, Oren. Nuit\u00a0: Pia, Bram.\n"
     u"L'ascenseur reste en bas. L'appel du haut est coup\u00e9 pour que les grillons ne puissent pas monter avec.\n"
     u"Pour descendre, il faut grimper. Pour remonter, prenez l'interrupteur du bas\u00a0: l'ascenseur vous monte.\n"
     u"Haltes au premier et au deuxi\u00e8me palier. Dormez \u00e0 l'une d'elles avant de continuer.\n"
     u"Le t\u00e9l\u00e9phone de chaque halte sonne \u00e0 la salle des pompes.",
     u"Pump team. Twelve-hour shifts.\n"
     u"Day: Ines, Oren. Night: Pia, Bram.\n"
     u"The lift stays at the bottom. The top call is cut so the Crickets cannot ride it up.\n"
     u"To go down, climb. To come back, use the lower switch and the lift takes you up.\n"
     u"Rest stops on the first and second landings. Sleep at one before you go on.\n"
     u"The phone at each rest stop rings through to the pump hall."},
    {u"Records_MX13_Z4_02_Title", u"Proc\u00e9dure de vidange", u"Drain Procedure"},
    {u"Records_MX13_Z4_02_Desc",
     u"Vidanges de la salle des pompes. Maintenance Cryo Technology.\n"
     u"1. Ouvrir la vidange 1.\n"
     u"2. R\u00e9gler le premier panneau des tuyaux. Le niveau baisse d'une marque.\n"
     u"3. Ouvrir la vidange 2.\n"
     u"4. R\u00e9gler le second panneau des tuyaux. Le niveau descend jusqu'au sol.\n"
     u"Ouvrir une vidange ouvre les grilles des anciens tuyaux. Ce qui vit dedans en sort. D\u00e9gagez la salle avant l'\u00e9tape suivante.\n"
     u"\n"
     u"Au stylo, en dessous\u00a0:\n"
     u"Les adeptes ont ouvert la vidange 1 avant que nous soyons pr\u00eats. Oren est entr\u00e9 derri\u00e8re eux. Ines",
     u"Pump hall drains. Cryo Technology maintenance.\n"
     u"1. Open drain 1.\n"
     u"2. Set the first pipe panel. The level drops one mark.\n"
     u"3. Open drain 2.\n"
     u"4. Set the second pipe panel. The level drops to the floor.\n"
     u"Opening a drain opens the grates of the old pipes. Whatever lives in them comes out. Clear the hall before the next step.\n"
     u"\n"
     u"In pen, below:\n"
     u"The believers opened drain 1 before we were ready. Oren went in after them. Ines"},
    {u"Records_MX13_Z1_03_Title", u"Registre de l'abri\u00a0: d\u00e9parts", u"Shelter Register: Departures"},
    {u"Records_MX13_Z1_03_Desc",
     u"Registre de l'abri, station Matrice 13. Jour 2431.\n"
     u"Partis par l'ascenseur de 6 h vers la ville des survivants\u00a0: 24 citoyens.\n"
     u"Num\u00e9ros 41, 58, 59, 112, 130, 131, 176, 190, 204, 205, 221, 233, 240, 251, 266, 270, 284, 291, 296, 298, 301, 303, 310, 322.\n"
     u"Le n\u00b0 301, Yohan, m\u00e9canicien du d\u00e9p\u00f4t, m\u00e8ne le groupe. Il m'a demand\u00e9 d'inscrire le 303 \u00e0 c\u00f4t\u00e9 de son num\u00e9ro. C'est fait.\n"
     u"Restent\u00a0: 38. L'ascenseur garde ses horaires.\n"
     u"Jour 2490. 26 autres sont partis par l'ascenseur de 6 h, avec de l'eau et des cellules pour les vingt-trois des Terres d\u00e9sol\u00e9es.\n"
     u"Restent\u00a0: l'\u00e9quipe des pompes, Mila, Noa, le n\u00b0 301 et moi.",
     u"Shelter register, Matrix 13 station. Day 2,431.\n"
     u"Left on the 06:00 lift for the survivors' city: 24 citizens.\n"
     u"Nos. 41, 58, 59, 112, 130, 131, 176, 190, 204, 205, 221, 233, 240, 251, 266, 270, 284, 291, 296, 298, 301, 303, 310, 322.\n"
     u"No. 301, Yohan, depot mechanic, leads the group. He asked me to write 303 next to his number. I did.\n"
     u"Staying: 38. The lift keeps its times.\n"
     u"Day 2,490. 26 more left on the 06:00 lift, with water and cells for the twenty-three in the Wasteland.\n"
     u"Staying: the pump team, Mila, Noa, No. 301 and me."},
    {u"Records_MX13_Z1_06_Title", u"Journal de la gruti\u00e8re", u"Crane Operator's Log"},
    {u"Records_MX13_Z1_06_Desc",
     u"Jour 2466. Mila, grue et monte-trains.\n"
     u"Monte-trains v\u00e9rifi\u00e9. Voiture 3 mont\u00e9e \u00e0 7 h 02, \u00e0 l'heure.\n"
     u"La porte de la cabine de grue coince. Noa est encore mont\u00e9e l\u00e0-haut. Elle dit que de la cabine, elle voit toute la ligne.\n"
     u"Le drone \u00e0 reliques est revenu dans l'atelier des roues. Noa lui donne des boulons. Laissez-le, il garde le sol propre.\n"
     u"L'eau atteint la deuxi\u00e8me marque. Ines a besoin de bras aux pompes. Je descends, et Noa vient avec moi.",
     u"Day 2,466. Mila, crane and train lift.\n"
     u"Train lift checked. Car 3 up at 07:02, on time.\n"
     u"The crane cab door sticks. Noa climbed up there again. She says she can see the whole line from the cab.\n"
     u"The relic drone is back in the wheel shop. Noa feeds it bolts. Leave it alone, it keeps the floor clean.\n"
     u"Water at the second mark. Ines needs hands at the pumps. I'm going down, and Noa comes with me."},
    {u"Records_MX13_Z1_08_Title", u"Service de 18 h 40, un voyageur", u"Service 18:40, One Passenger"},
    {u"Records_MX13_Z1_08_Desc",
     u"Jour 2488.\n"
     u"Ascenseur de 18 h 20\u00a0: un voyageur. N\u00b0 301, Yohan. Il est revenu seul.\n"
     u"Il dit qu'il n'y a pas de ville. Les vingt-trois autres campent dans les Terres d\u00e9sol\u00e9es. Il est venu chercher des cellules et de l'eau pour eux, et voir Noa.\n"
     u"Il doit \u00eatre remont\u00e9 \u00e0 la surface avant le lever du soleil. Quelqu'un l'attend l\u00e0-haut.\n"
     u"Il voulait le prochain train vers les pompes. Il n'y a pas de train \u00e0 cette heure-l\u00e0. J'en ai fait partir un.\n"
     u"Service sp\u00e9cial de 18 h 40, ligne descendante. Un voyageur. Parti \u00e0 l'heure.\n"
     u"Ruben",
     u"Day 2,488.\n"
     u"18:20 lift: one passenger. No. 301, Yohan. He came back alone.\n"
     u"He says there is no city. The other twenty-three are camped in the Wasteland. He came for cells and water for them, and to see Noa.\n"
     u"He has to be back on the surface before sunrise. Someone is waiting for him up there.\n"
     u"He asked for the next train down to the pumps. There is no train at this hour. I ran one.\n"
     u"18:40 special service, line down. One passenger. Left on time.\n"
     u"Ruben"},
    {u"Records_MX13_Z2_02_Title", u"R\u00e9union, voiture 9", u"Meeting, Car 9"},
    {u"Records_MX13_Z2_02_Desc",
     u"R\u00e9union dans la voiture 9. Jour 2429. 62 pr\u00e9sents.\n"
     u"Yohan\u00a0: le recycleur descendu le mois dernier dit que la ville des survivants existe et qu'il y a des m\u00e9decins. D\u00e9part par l'ascenseur de 6 h dans deux jours.\n"
     u"Ines\u00a0: si l'\u00e9quipe des pompes s'en va, l'eau monte. L'\u00e9quipe des pompes reste.\n"
     u"Mila\u00a0: Noa a neuf ans. Elle ne traversera pas un d\u00e9sert. Nous restons.\n"
     u"Le chef de gare\u00a0: la ligne roule. Ceux qui partent pourront revenir par l'ascenseur.\n"
     u"Vote\u00a0: 24 partent, 38 restent.",
     u"Meeting in car 9. Day 2,429. 62 present.\n"
     u"Yohan: the scavenger who came down last month says the survivors' city is real and has doctors. We leave on the 06:00 lift in two days.\n"
     u"Ines: if the pump team leaves, the water comes up. The pump team stays.\n"
     u"Mila: Noa is nine. She is not crossing a desert. We stay.\n"
     u"The station master: the line runs. Anyone who leaves can come back on the lift.\n"
     u"Vote: 24 leave, 38 stay."},
    {u"Records_MX13_Z2_04_Title", u"Cycle des drones \u00e0 d\u00e9chets", u"Waste Drone Cycle"},
    {u"Records_MX13_Z2_04_Desc",
     u"Aire de tri, drones 1 \u00e0 4.\n"
     u"Les drones d\u00e9marrent quand quelqu'un met le pied sur l'aire et s'arr\u00eatent \u00e0 la porte du fond.\n"
     u"Ils portent les d\u00e9chets tri\u00e9s des voitures jusqu'aux goulottes. Une charge tombe de plus de vingt m\u00e8tres.\n"
     u"Ne passez pas sous un drone charg\u00e9. Le drone 3 l\u00e2che trop t\u00f4t.\n"
     u"Personne n'a eu \u00e0 les r\u00e9parer en six ans.\n"
     u"Maintenance du d\u00e9p\u00f4t",
     u"Sorting floor, drones 1 to 4.\n"
     u"The drones start when someone steps onto the floor and stop at the far gate.\n"
     u"They carry the sorted waste from the cars to the chutes. A load falls more than twenty metres.\n"
     u"Do not walk under a loaded drone. Drone 3 drops early.\n"
     u"Nobody has had to repair them in six years.\n"
     u"Depot maintenance"},
    {u"Records_MX13_Z3_02_Title", u"Rapport sur les grillons", u"Cricket Report"},
    {u"Records_MX13_Z3_02_Desc",
     u"Jour 2452. Ines.\n"
     u"Les grillons nichent dans les tuyaux chauds le long du puits. Ils montent quand l'eau monte.\n"
     u"Les gros \u00e9clatent en mourant. N'en achevez jamais un au bord d'une passerelle. Bram a failli tomber hier.\n"
     u"Aujourd'hui, ils \u00e9taient au-dessus du premier palier. Le mois dernier, ils restaient sous le deuxi\u00e8me.",
     u"Day 2,452. Ines.\n"
     u"The Crickets nest in the warm pipes along the shaft. They come up when the water rises.\n"
     u"The big ones burst when they die. Never finish one at the edge of a walkway. Bram nearly went over yesterday.\n"
     u"Today they were above the first landing. Last month they stayed below the second."},
    {u"Records_MX13_Z4_01_Title", u"Niveaux d'eau", u"Water Levels"},
    {u"Records_MX13_Z4_01_Desc",
     u"Jauge de la salle des pompes. Ines.\n"
     u"Jour 2350\u00a0: premi\u00e8re marque. L'usine de traitement ne filtre plus et l'eau devient toxique.\n"
     u"Jour 2466\u00a0: deuxi\u00e8me marque. Deux pompes en panne. \u00c0 partir de maintenant, les vidanges se font \u00e0 la main.\n"
     u"Jour 2494\u00a0: troisi\u00e8me marque cette nuit. La porte du poste de commande sera \u00e0 moiti\u00e9 sous l'eau. Tout le monde dort au poste de commande.\n"
     u"\u00c0 la troisi\u00e8me marque, les ventilateurs s'arr\u00eatent et l'air au-dessus de l'eau devient mauvais. Lancez-les depuis les murs d'escalade avant de monter dans les gaines.\n"
     u"Depuis la vidange 1, quelque chose de gros vit dans la salle des ventilateurs. Personne n'y va seul.",
     u"Pump hall gauge. Ines.\n"
     u"Day 2,350: first mark. The treatment plant stops filtering, and the water turns toxic.\n"
     u"Day 2,466: second mark. Two pumps down. From now on the drains are run by hand.\n"
     u"Day 2,494: third mark tonight. The control room door will be half under. Everyone sleeps in the control room.\n"
     u"At the third mark the fans stop and the air over the water goes bad. Start them from the climbing walls before you go up into the ducts.\n"
     u"Since drain 1, something big lives in the fan room. Nobody goes in there alone."},
    {u"Records_MX13_Z4_03_Title", u"Le dernier abri", u"The Last Shelter"},
    {u"Records_MX13_Z4_03_Desc",
     u"Poste de commande, salle des pompes. Jour 2494, 23 h 50. Troisi\u00e8me marque. Les ventilateurs se sont arr\u00eat\u00e9s. Porte scell\u00e9e.\n"
     u"\u00c0 l'int\u00e9rieur\u00a0: Ines, Mila, Noa, Yohan, un adepte qui n'a pas donn\u00e9 son nom, et moi. Le chef de gare est dans la salle du r\u00e9acteur.\n"
     u"0 h 20. Mila est sortie par le toit pour lancer les ventilateurs.\n"
     u"3 h. Yohan est parti la chercher. Il est revenu seul \u00e0 5 h 20. Trappe soud\u00e9e.\n"
     u"Perdus \u00e0 la vidange 1\u00a0: Oren et trois adeptes.\n"
     u"Pia\n"
     u"\n"
     u"En dessous, d'une autre \u00e9criture\u00a0:\n"
     u"Noa \u00e0 la salle du r\u00e9acteur, 7 h 30. Ines 9 h 50. Pia 11 h 20. L'adepte 12 h 05. Je monte rejoindre Noa. Y.",
     u"Control room, pump hall. Day 2,494, 23:50. Third mark. The fans have stopped. Door sealed.\n"
     u"Inside: Ines, Mila, Noa, Yohan, one believer who did not give his name, and me. The station master is in the drive room.\n"
     u"00:20. Mila went out over the roof to start the fans.\n"
     u"03:00. Yohan went to find her. He came back alone at 05:20. Hatch welded.\n"
     u"Lost at drain 1: Oren and three believers.\n"
     u"Pia\n"
     u"\n"
     u"Below, in another hand:\n"
     u"Noa to the drive room, 07:30. Ines 09:50. Pia 11:20. The believer 12:05. Going up to Noa. Y."},
};
} // namespace coop::camp_text
