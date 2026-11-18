# Features and test status

Each feature of the mod is listed below with what has been tested in game and when. [Matrix XIII](world/matrix13.md) and
[Lily's signal](world/lily-signal.md) have their own pages. The [README](../README.md) gives the short version, and the
[documentation index](README.md) lists the page that describes each feature in full.

## Status

Stellar Blade Online is an experimental beta. This version runs on Stellar Blade's Steam build 26123051 only, which
Steam installed on 2026-11-05; versions up to 0.8.0 run on build 24463856 only. On another build `coop status` shows
`engine=off`, and every feature that reads the game's memory stays off (see [INSTALL.md: Update](../INSTALL.md#update)).

Two-PC co-op was first played on 2026-10-17, one PC on Linux with Proton and one on Windows, between Belgium and Brazil
at about 240 ms ping. On 2026-10-21 two players on 0.4.0 played on the automatic co-op saves with shared enemies and
same place (each enemy in the same spot on both screens). On 2026-11-01 two PCs played 0.7.0-beta.1 with its ghost fix:
joining with CNS packs no longer crashed. Apart from the 2026-11-01 session, no version after 0.4 has been played on two
PCs, so nothing else added since 0.4 has been tested between two PCs: shared quests, the shared world, story together,
the friend's revive, the cutscene wait, kills that count only for a player who took part, Night Operation's run, levels,
revive and challenges, Doro races, the co-op line at camp phone booths, the .pak mod list and CNS outfits over the link,
`coop gift` and the pose rate that adapts to Steam's queue.

On one PC, the Leviathan viewer and its free camera ran on 2026-10-22, the Lion was fought on 2026-10-24, the
first-launch guide opened, and on 2026-10-27 the co-op saves loaded and `coop nightop shop` opened its shop screen. On
2026-11-12 the recruiter's Join took one PC to the SBO lobby in Xion's training room, and on 2026-11-14 to a hall lobby
with a local pak. No match lobby has held two players in game yet (see
[SBO lobby: Test status](online/lobby.md#test-status)).

0.6.0-beta.1 to beta.3 use link protocol 13. 0.7.0-beta.1 uses protocol 14 and does not link with them. 0.7.5 uses
protocol 18 and does not link with 0.7.0-beta.1 or with the first 0.7.5 test build (protocol 17). Builds after it, 0.8.0
to 0.10.0, use protocol 19, for Matrix XIII's world rows, and do not link with 0.7.5. 0.11.0 uses protocol 20, for the
PvP test and the match lobbies. It does not link with 0.10.0 or older. This version uses protocol 23, for the shared
world, story together and sessions of up to 4 players. It does not link with 0.11.0 or older: every player has to
update.

In this version every on/off setting is on by default, the experimental ones and the test tools included: the ghost's
dyes and effects, the spawn filter, the name tag in your photos, shared quests, the shared world, story together, the
revive, the solid partner, the Load Shortcut saves, the PvP test, the SBO lobby, the bike and the day and night cycle.
The status strip shows its
compact form, and F7's travel to the host is on. A `coop-settings.txt` written by 0.5.0-beta.1 to 0.10.0 that holds the
old off values is changed once at the next load (see [Settings](players/settings.md#coop-settingstxt)). Most of these features
have not been tested in game. `shortcut_load=on` lets `coop shortcut load` write a developer save that can unlock Steam
achievements, which cannot be taken back.

## Features

- F5 opens the co-op menu. Its first row opens the Create a session screen, where the host picks who can join and the
  session rules before Start. Public, the default, lists the online session in Find a session for every player of the
  same version. Friends only opens it to the host's Steam friends, Invitation to a Steam invite or a 7-character join
  code, Private to nobody. A player who is not the host's Steam friend waits until the host accepts them. With
  Friends join without asking off, the host's friends wait too. The invited friend joins once their save has loaded,
  even if Steam had to start their game. The menu also finds sessions, invites, leaves and changes the settings. F6
  shows the status and F8 leaves the session. On any controller the game reads (a DualSense with Steam Input off
  included), View held for 1 s opens the menu. The mouse works in it too.
- The game's pause menu gets an Online tab after Settings. RB on Settings (E on the keyboard) or a click on the tab
  closes the pause menu and opens the co-op menu. Not tested in game yet.
- While at least one other player is linked with you, the game's tutorial popups and record popups are off in your
  game (Hide popups online, on by default). Your own values come back when you leave. The game's settings file keeps
  them the whole time. Not tested in game yet.
- At a camp phone booth (any full camp, Xion's booths, the Wasteland and Great Desert warp phones), F5 opens the co-op
  line: the menu's session rows, Co-op menu and Hang up, and a sentence that says whether the line is free, open or
  linked with your friend. The booth's own fast travel works as before. The line is not tested in game yet.
- Your friend's EVE appears in your world as a ghost: a display-only copy that moves as she moves, wears her outfit and
  has your friend's Steam name above it. Her ponytail moves as cloth, as in solo (on by default). Her hair colour and
  her attack and skill effects are optional looks, on by default. None of the three looks is tested in game yet.
- Session notices show in a feed at the top left of the screen, for example when a friend joins or leaves, when the
  connection is lost or when the two versions do not match. If a guest loses the host's session, their game tries to
  rejoin it for 60 s.
- During a session, Enter opens a text box to chat with your friend, and in the SBO lobby with the players of your
  match lobby. Chat lines show in the same feed and are kept in memory only.
- Your friend's card at the top left shows their name with their ping and map, then their HP, shield and Beta. A
  marker over their ghost shows their name and HP, and an arrow at the edge of the screen points to them when they are
  out of view. The card, marker and arrow stay inside the screen at any resolution and menu size.
- Group play, not tested in game yet:
  - as the guest, F7 takes you to the camp nearest the host through the game's own fast travel when the host is on
    another map or more than 150 m away. The game's fast travel does not check whether your save has activated a camp,
    so the mod reads the activated camps itself and travels only to one of them; `coop travel probe` and
    `coop mxiii leave` use the same read;
  - when one EVE is down, the shared enemies near the other one fight it, and a down EVE gets no kill by standing near
    one; with the experimental revive (on by default), a friend who stands next to the downed EVE for 3 s revives it
    where it fell;
  - the guest's game pauses while a cutscene plays in the host's game;
  - in a shared area only the host's camp rest brings the enemies back, and a notice tells the guest so;
  - the experimental solid partner option (on by default) stops your EVE at your friend's ghost.
- Doro races: record a track by setting checkpoints with F9, then race it alone against the clock or against your
  friend, each racer drawn as a Doro (Dororong). The race has a countdown, a timer, checkpoint markers and a ranking.
  It gives no reward or achievement and writes nothing to a save. Doro races are not tested in game yet (see
  [online/modes/race.md](online/modes/race.md)).
- The bike: F3, D-pad Right held 1 s or `coop bike` puts EVE on a motorbike from the game's files, on any save. She
  rides it with the left stick, leans into turns, drifts with R2 or B and jumps with the game's Jump; her attacks and
  items are off while she rides. Your friend's ghost of you and the match-lobby ghosts show the bike. It stays where she
  gets off, one place for each save, where the players linked with you see it too. Its riding model adapts dCharisma1's
  Eve On Wheels, with his consent. It is not tested in game yet (see [vehicles/bike.md](vehicles/bike.md)).
- Day and night: the sun moves across the sky on the maps that can show it, by one clock that every SBO player shares
  through UTC, so players on the same map see the same sky with no network message. One real hour is one game day; the
  night runs from about :52 to :12 past each hour. It runs in solo play, in online sessions, in the hall lobbies, in
  Matrix XIII and in Night Operation, which keeps midnight. On the Wasteland, the Great Desert, Eidos 7 and 9, Matrix 11, Spire 4 and
  both NIKKE minigame maps the painted sky dome gives way to a real sky, orange near the horizon at dawn and dusk. At
  night the sun light goes off (no light through the ground), the sky, the fog and EVE's lights get darker, a cold
  moon light takes over and stars come out. Xion swaps to the game's own night dome. Rooms, caves and labs keep their
  own light, as do cutscenes and the game's menus. The NIKKE boss arena, the story places and the Terrace hall keep
  their fixed light: the Terrace stays a night hall. `daynight=off` (Options, Display) gives each map Stellar Blade's
  own fixed light, as before. `coop daynight hour <h>` pins an hour for tests. It is not tested in game yet (see
  [the day and night cycle](world/daynight-internals.md)).
- `coop leviathan` shows Leviathan, a Naytiba cut from the game whose models and animations are still in its files, as
  a display-only model in front of EVE, with a free camera for filming. `coop gardener` and `coop tendril` do the same
  for two more cut Naytibas, the Gardener and the Tendril (see
  [fight/bosses.md](fight/bosses.md#cut-enemy-preview-coop-leviathan-coop-gardener-and-coop-tendril)). In the viewer none
  of them can be fought: the game has no entry for them in its character table (`coop gardener fight` and
  `coop tendril fight`, below, add the Gardener's and the Tendril's). `coop mann`, `coop nier`, `coop orcal` and
  `coop enya`
  show the early Mann model, the NieR collaboration's three cut machines and prototype statues of Orcal and Enya the
  same way.
- `coop lion` spawns the Lion, a boss cut from the game, as a real enemy to fight on a co-op save. The game's files keep
  its model, animations and attacks but no table row, so the mod adds the 222 rows it needs to the game's tables in
  memory. `coop lion intro` plays its entrance first. It writes nothing to a save, and only your game has it (see
  [fight/bosses.md](fight/bosses.md#cut-boss-coop-lion)).
- `coop gardener fight` spawns the Gardener the same way: a cut artillery Naytiba about 20 m tall that never walks and
  shells EVE from its mouth. The mod adds the 13 rows it lacks to the game's tables in memory. It is not tested in game
  yet (see [fight/bosses.md](fight/bosses.md#cut-enemy-coop-gardener-fight)).
- `coop tendril fight` spawns the Tendril the same way, a cut Naytiba that strikes with four chains on its head. The
  game has no skill presentations for its animations either, so the mod builds them in memory from its own clips, and
  adds the 107 rows it lacks. It is not tested in game yet (see
  [fight/bosses.md](fight/bosses.md#cut-enemy-coop-tendril-fight)).
- `coop wear` puts EVE in two cut hairs (mechanical cat ears and rabbit ears) and four cut suits, Gothic Rose among
  them, by changing the meshes drawn. Your equipment and saves stay as they are, and your friend's ghost of you shows
  the look too (see [eve/eve.md](eve/eve.md#cut-hairs-and-suits-coop-wear)).
- `coop scene` plays two scenes cut from the game through its own cutscene player, each at its place in the world:
  Emil's farewell from an ending of the first DLC and Orcal's monologue from the 2022 trailer. It writes nothing to a
  save and has not been tried in game yet (see [story/scenes.md](story/scenes.md#cut-scenes-coop-scene)).
- `coop lines` shows the subtitles of four scenes cut before they were voiced in the chat's feed, timed as the game's
  sequences give them: the first meeting with Adam, Quest_Sub_015 with Mann and Orcal's last message, Quinn and Sky
  Hall. The text comes from your game, which has most of them in English and Korean only, so other languages show the
  Korean. `coop lines enya` plays seven voice takes of Enya and Su that the game never uses. Neither has been tried in
  game yet (see [story/scenes.md](story/scenes.md#cut-scene-lines-coop-lines)).
- `coop fly` and `coop slowmo` switch on the developer flight (a third press of the space bar in the air, or R2 held)
  and slow motion (R1) that the game ships turned off, on a co-op save. The flight in this form has not been tried in
  game yet (see [eve/eve.md](eve/eve.md#debug-flight-and-slow-motion-coop-fly-and-coop-slowmo)).
- `coop glide` brings back EVE's cut glide: with Jump held in the air, she falls at a tenth of the normal gravity, on a
  co-op save. It has not been tried in game yet (see [eve/eve.md](eve/eve.md#cut-glide-coop-glide)).
- `coop chainspin` asks for EVE's cut Tachy Mode ChainSpin once, while she is in Tachy Mode: a spin of four hits whose
  last one stuns, with no button and no wing animation. `coop devmenu` runs the 20 rows of the game's developer menu
  that still work (no damage, speed, attack, gauges, enemy rows), and `coop devinfo` opens its quest debugger or
  player info panel. These test commands have not been tried in game yet (see
  [eve/eve.md](eve/eve.md#cut-tachy-skill-coop-chainspin) and
  [tools/menus.md](tools/menus.md#developer-menu-coop-devmenu-and-coop-devinfo)).
- `coop emote <name>` plays one of EVE's clips through the game's own animation call: 31 photo-mode poses held until
  she moves (grouped under the categories of the game's cut Social Action menu), two waves, and six clips of hers made
  for two enemies with no character in the game files: the Chariot, which was cut (its struggle and her takedown on
  it), and Kali, possibly an early name of a shipped enemy (her takedown on Kali and Kali's grab). It has not been
  tried in game yet (see [eve/eve.md](eve/eve.md#emotes-coop-emote)).
- `coop shortcut` lists the 15 developer saves of the cut Load Shortcut menu, read from the game's files: the map and
  camp each one starts at. `coop shortcut load` writes one as co-op slot 5 for Load Game, without its achievement
  list. It needs `shortcut_load=on` (the default), and what is left of the developer's progress can still unlock
  Steam achievements. Neither has been tried in game yet (see
  [tools/menus.md](tools/menus.md#cut-load-shortcut-saves-coop-shortcut)).
- At its first run the mod opens a guide of nine pages, with art of Mother Sphere by timediffer24. The Guide row of the
  co-op menu and `coop guide` open it again (see [players/interface.md](players/interface.md#guide)).
- Each player's .pak mods are named over the link, and a notice says which ones the other player lacks. A friend's CNS
  outfit shows on your ghost of them when your own CNS packs declare its files (see
  [online/partner.md](online/partner.md#mods-and-cns-outfits)).
- If `UE4SS-settings.ini` has `HookBeginPlay` or `bUseUObjectArrayCache` on, a notice says so: the first can crash the
  game when EVE lets go of a movable crate (see [docs/players/troubleshooting.md](players/troubleshooting.md)).
- Solo test tools run the whole ghost pipeline on one PC: a network loopback, and a recording with its replay.
  `coop where` compares positions between two PCs.
- The mod never writes your unlocks or equipment, and writes your own saves only when you export a co-op save over one
  of them (`coop saves export`, after a backup). It changes the inventory only when you buy in Night Operation's shop
  or send and take a `coop gift`, on a co-op save, or pay 500 betacrystal to bring the bike back at Xion, on any save
  (see [docs/vehicles/bike.md](vehicles/bike.md#bringing-it-back-at-xion)). It reads your saves to make separate co-op copies of them (see
  [docs/players/saves.md](players/saves.md)).

The ghost is display only, and items are not shared, except the consumables sent with `coop gift`. The experimental
Shared enemies option (co-op menu, Options, Combat) is on by default and untested in game. It shares common enemies only
while both players play a co-op save (see [fight/enemies.md](fight/enemies.md#shared-enemies-experimental)). Same place, same
spawns and shared bosses build on it. They are experimental and on by default too, and the host's settings decide them
for both games. As guest, the Same place row of your co-op menu can still turn same place off on your screen. The
experimental Shared quests option (Options, Saves) is on by default and untested in game. While both players play a
co-op save, it makes the quest steps that the host and the guest make together in the guest's game too, through the
game's own quest functions (see [players/playing-with-a-friend.md](players/playing-with-a-friend.md#shared-quests-experimental)). A
quest step the guest makes first moves the host's quest too, with Story together on or off. The experimental Shared
world option (Options, Session) is on by default and untested in game. While both players play a co-op save, a door, lever, switch, crane, lift or shortcut that one player works changes in the other's game too,
while chests, supply boxes and anything else that gives an item stay each player's own (see
[world/objects.md](world/objects.md)). The experimental Story together option (Options, Session) is on by default and
untested in game. While both players play a co-op save, a cutscene or a talk the host plays plays in the guest's game
too, with the host's choices, QTE results and skips. A story trip the host starts takes the guest along (see
[story/together.md](story/together.md)).

## SBO lobby and matches

The recruiter near Roxanne in Xion now appears at each Xion load, on any save. On a co-op save, his Join choice saves
the game and takes EVE to the SBO lobby, a waiting room in Xion's hidden training room. Its menu searches for a public
free-for-all match lobby or hosts one, hosts a private one with a join code, or joins one by its code. A match lobby
holds up to 8 players, each shown to the others as a ghost, with chat and a mute for each player; nobody waits for the
host's answer, and the link goes through Steam's relays only. When 2 players have linked, a countdown of 10 s starts
(5 s when the lobby is full), but the free-for-all mode itself is not built: at 0 nobody travels to an arena and
nothing is scored. Leave reloads the save made at Join, next to the recruiter. Five hall lobbies replace the training
room when the hall lobby pak is installed; the code is in this version, but the pak is not published yet. `coop pvp`
tests PvP damage between two linked friends: hits on a stand-in at the friend's ghost take HP off her EVE, never below
1 HP. See [SBO lobby and matches](online/lobby.md).

Tested in game, on one PC only: the Join and the travel to Xion's training room (2026-11-12) and to a hall lobby with a
local pak (2026-11-14), each time with a Search that found nobody and hosted a lobby. Not tested in game: Leave and the
return, any match lobby with two or more players, private matches, the countdown and the round's start, the PvP test,
and the black screen held over each arrival.

## Night Operation

This project found Night Operation in the game files: a multiplayer wave-survival mode that Shift Up prototyped and cut
before release. Its recruiter was meant to stand next to Roxanne in Xion's Scrap Market. The plan is to bring the mode
back for friends over Steam, started from the recruiter's Join choice, for up to six players. A Night Operation run holds
two players today; the match lobbies hold eight but run no Night Operation yet, and Join takes you to the
[SBO lobby](online/lobby.md) instead. The mod never contacts the cut mode's online services (Shift Up's servers).

`coop nightop start` runs five timed waves of the game's monsters at EVE where she stands, with an 8-minute timer and a
score, on a co-op save. `coop nightop start easy`, `hard` or `nightmare` changes the number of monsters (15 to 40 in
all, 20 at normal), the time limit and the shop points. With no Steam session it is a solo run. In a session the host
types it, at his level, and both games get the same waves while both screens show one timer and one score; with shared
enemies on, each wave monster has one HP bar and one death in both games. With the experimental revive on, a dead EVE in
such a run is down for 30 s: her partner revives her with the interact key, as the cut mode planned, or she revives
herself a few times a run (`coop nightop revive`).

A run that ends in success or time up gives points for a shop of seven items: four of the game's, and three cut items
the mod adds back (two stimpacks and the Shock Bolt ammo for EVE's gun). `coop nightop shop` opens it in the game's own
shop screen, with your points shown as the cut Beta Seed, and on a co-op save Roxanne in Xion offers the run's levels
and its supplies among her choices.

The shop screen ran in game on 2026-10-27. One solo run on 2026-10-28 spawned its waves, some monsters inside walls, but
tracked none of them. The fixes for the tracking and for the spawn points are untested, and so are the levels, the
revive, the purchases and Roxanne's choices (see [docs/online/modes/nightop.md](online/modes/nightop.md#the-co-op-run)).

`coop challenge` runs five short fights on the same code, two of them against the game's target dummies, and keeps each
one's best run in `coop-records.txt`. They need a co-op save and give no shop points. Four are solo. The fifth, the
Shooting Range, rebuilds the game's cut shooting test with its score widget, and the host can start it for both players.
They have not been tested in game yet either (see [online/modes/challenges.md](online/modes/challenges.md)).

Two research previews also run only on a co-op save. `coop recruiter` brings back the cut recruiter near Roxanne, and
you can talk to him; the mod also brings him back by itself at each Xion load, on any save, and he appeared that way in
game on 2026-11-14. `coop no` tests parts of the cut mode in a solo game. Neither preview is a playable mode.
