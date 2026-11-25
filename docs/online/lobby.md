# SBO lobby and matches

The SBO lobby is a waiting room for matches of up to 8 players. From it you search for a public match, host a private
one or join one with a code. The mod's notices and menu call it the PvP lobby. It is a test in this version. The
lobby, the search and the countdown run. Two modes play their round in the lobby room. In
[score attack](modes/scoreattack.md) every player plays the same challenge at once. In a
[Doro race](modes/race.md#races-in-a-match) every player races the same track at once. The free-for-all is not built:
when its countdown ends, nobody travels to an arena and nothing is scored. What has been tried in game is listed under
[Test status](#test-status).

An online session with friends holds 2 to 4 players (see [Playing with a friend](../players/playing-with-a-friend.md)). Join
refuses while you are in one.

## Getting there

1. Load a co-op save (see [INSTALL.md: Co-op saves](../../INSTALL.md#co-op-saves)). `coop status` shows `slot=coop`.
2. In Xion, walk to Roxanne in the Scrap Market. At each Xion load the mod brings back the recruiter that Shift Up cut
   from the game, a Xion guard, once EVE is within 50 m of his spot next to her (see
   [Night Operation previews](modes/nightop-previews.md#preview-2-the-recruiter-coop-recruiter)).
3. Talk to him and choose Join. The notice `Saving the co-op game. Leaving the lobby brings you back here.` shows, the
   game saves your co-op save where you stand, and EVE travels to the lobby.

`coop sbo enter` does the same from the console. The mod never sends the Join choice to Shift Up's servers (see
[How the original matchmaking is blocked](modes/nightop-previews.md#how-the-original-matchmaking-is-blocked)).

When Join cannot start, a notice says why and nothing changes:

| Notice | When |
| --- | --- |
| `The PvP lobby needs co-op saves (saves=coop).` | One of your own saves is loaded |
| `The PvP lobby is off (sbo_lobby=off in coop-settings.txt).` | You turned the lobby off |
| `Steam is not ready.` | The Steam link has not started |
| `End the online session first.` | You are in an online session with a friend |
| `Not during a fight.`, `Not during a Night Operation run.`, `Not during a Boss Challenge.` | One of these is under way |
| `Not now: the game is loading or travelling.` | A load or a travel is under way |
| `The game cannot save here.` | Stellar Blade's own save is refused where EVE stands |
| `The game is saving. Try again in a moment.` | The game's save queue is busy |
| `An SBO session is still open. Quit to the title to restore the co-op save.` | An earlier lobby visit did not end; at the title the mod puts that co-op save back |
| `The game did not save. Nothing changed.`, `The lobby did not load. Nothing changed.` | The save or the travel failed |

## In the lobby

Without the hall lobby pak, which no release contains yet, the lobby is Xion's hidden training room, reached through
Stellar Blade's zone `Zone_Xion_Boss_Mann`. The mod turns off that zone's boss spawn and its camp, theater and door
triggers for the visit, and puts the game's values back afterwards. Each player stands on one of 8 spots on a circle
of 8 m. If EVE goes more than 30 m from its centre, the mod puts her back on her spot.

- After the travel the screen stays black until the lobby menu is ready, 8 s at most, then fades in on the open menu.
  Stellar Blade's HUD stays hidden while a lobby screen is open.
- The mod puts Stellar Blade's own equipment preset `Preset_Eve_Max` on EVE, so every player in the lobby has the same
  build. Your difficulty stays as you set it. Your own equipment comes back with your save when you leave.
- Enter opens the [chat](../players/interface.md#session-chat). In a match lobby your lines go to every member who has finished
  connecting. With nobody connected, a line stays on your screen and is not sent.
- In a match lobby you see each other member's EVE as a [ghost](partner.md), each with her own pose rate, 30 poses a
  second at most.

### The lobby menu

The menu opens by itself at each arrival. Waiting room closes it so you can walk in the room, and F5 (your
`menu_key`) or View held for 1 s on a controller opens it again.

| Row | What it does |
| --- | --- |
| Free-for-all | A mode. Its line gives the rules planned for it: 2 to 8 players, first to 20 kills or the best score after 10 minutes, a respawn after 4 s. No round plays them yet |
| Score attack | A mode: every player plays the same challenge at once, the best score first (see [Score attack](modes/scoreattack.md)). Locked while `scoreattack=off` |
| Doro race | A mode: every player races the same track at once as a Doro, the shortest time first (see [Races in a match](modes/race.md#races-in-a-match)). Locked while `race_match=off` |
| More modes | Locked, marked soon |
| Search | A quick match: see [Search](#search) |
| Private match | Host a match lobby that only a join code opens: see [Private match](#private-match) |
| Join with a code | Type a match lobby's join code |
| Waiting room | Close the menu |
| Settings | The match's rules and the lobby's settings |
| Leave | `Go back to Xion? You return where you talked to the recruiter.` |

Select on Free-for-all, Score attack or Doro race picks that mode for Search and Private match, marked `picked`, until
the mod reloads. Score attack is picked at first while it can play. In a score attack match lobby the mode rows are
Score attack (locked), Challenge and More modes. The host's Challenge row picks the round's challenge or Random. A
guest's reads `Host's pick` (see [Starting a round](modes/scoreattack.md#starting-a-round)). In a Doro race match lobby
they are Doro race (locked), Track and More modes, with the host's track on the Track row the same way (see
[Starting a round](modes/race.md#starting-a-round)).

While a search runs, or once you are in a match lobby, Cancel takes the place of Search, Private match and Join with a
code: it stops the search or leaves the match lobby, and you stay in the SBO lobby. The host of a private match also
gets a Code row, which copies the join code. Under the rows, the members box lists each member with her ping, or
`connecting…` and `lost`, and marks you and the host.

Settings has two tabs; LB and RB change the tab on a controller. MATCH shows the rules of the lobby's mode, or of the mode picked (locked), whether
the lobby is public or private with its code, the Map row of a private match (only with the hall lobby pak) and the
mod version with its link protocol. SBO has Chat on or off, a Mute row for each other member, Menu language, Menu
sounds and Write a bug report (`coop report`).

### Search

Search asks Steam for an open public lobby of the mode picked with a free place, made by a game on the same Stellar Blade
Online protocol and game build and with the same lobby maps: players without the hall lobby pak only find lobbies made
without it. Steam limits the search to your region and the regions near it. Search joins the first lobby found, and
tries the next one if that join fails.

When no lobby is open, you host a public one: `No scoreattack match found (SBO protocol 29, build 26123051): hosting
one.` A
host alone in a public lobby searches again every 5 s and moves to an open lobby with a lower Steam lobby id, so two
players who searched in the same second are in one lobby within about 5 s.

Search never leaves you in a public lobby with a player on your [block list](../players/playing-with-a-friend.md#block-list),
nor outside matchmaking when a lobby's host has blocked you. Your game leaves that lobby with a notice, searches again
and skips that lobby for the rest of the game run.

### Private match

Private match hosts a match lobby that Search never returns, with a 7-character
[join code](../players/playing-with-a-friend.md#join-codes): `Hosting a private scoreattack match. Your join code is <code>.` The other
players choose Join with a code and type it. With the hall lobby pak, the Map row of Settings picks the hall first, or
Random.

### Match lobbies

In a match lobby, public or private, nobody waits for the host's answer, Steam friend or not. The host can still send a
player out with `coop remove <SteamID>`; the `member=` lines of `coop status` start with each member's SteamID, masked
to its last 4 digits, which `coop remove` takes too. `coop remove` also puts the player on the host's
[block list](../players/playing-with-a-friend.md#block-list), so every later game that host runs refuses them until
`coop unblock`. The host's game refuses a player whose game runs another protocol
or game build (`<name> runs another version and was refused.`). A player who sends more messages than the link allows
for 5 s is refused too (`<name> sent too many messages and was refused.`).

- Match lobbies go through Steam's relays only, so no player learns another's IP address. If Steam refuses that
  setting, your game sends nothing to the other players and asks again each second. After 3 refusals it leaves the
  match with `Left the match: Steam would not set relay only.`
- Chat stays on with players who are not your Steam friends. Mute a player in Settings > SBO, or with
  `coop mute <SteamID>`. A mute lasts until the game closes, in every lobby.
- Gifts, the Doro races of an online session (`coop race start`), the photo pause, the cutscene wait, the travel to
  the host, Night Operation and shared quests do not run in a match lobby.
- The host leads. A host who leaves from the menu first hands the lobby to the member who joined first.

### The countdown and the round

Once 2 players have linked, the host's game starts a 10 s countdown (`Starting in <n> s`). With 8 players it drops to
5 s, and under 2 it stops. At 0 the round starts: the lobby takes no new player, and a member whose link to the host was
not ready stays out of the round (`A round started without you.`). In a score attack lobby each player then plays the
round's challenge from her spot. In a Doro race lobby each player races the round's track from her slot on its start
line. The host's game ends either round 10 s after its ranking (see
[The end and the ranking](modes/scoreattack.md#the-end-and-the-ranking) and
[The end and the ranking](modes/race.md#the-end-and-the-ranking)). In a free-for-all lobby nothing else happens, since that mode is not built:
its round ends when the host types `coop match end`. A round of either mode also ends when the host leaves and the next
member becomes the host. The lobby takes players again once the round ends. Its menu then opens again for each player
of that round.

## Leaving

Leave in the menu, or `coop sbo leave`, asks first. It then leaves the match lobby and reloads the co-op save that the
game wrote at Join, so EVE is back where you talked to the recruiter. If the game saved again while you were in the
lobby, the mod puts the save from Join back first, and keeps the file it replaces as `<UTC time>-replaced.sav` in
`StellarCoopBackups\autosave\StellarBladeCoop0N\` (see [Copies before each save](../players/saves.md#copies-before-each-save)).

If the return fails, the notice reads `Could not go back to Xion. Quit to the title: the co-op save is restored there.`
At the title the mod checks the co-op save and puts the save from Join back if the game wrote over it.

## Hall lobbies

Five hall lobbies made for SBO, the Hotel, the Station, the Cloister, the Terrace and the Foyer, take the place of
Xion's training room when the hall lobby pak `zSBO_Lobby` is installed in `SB/Content/Paks/~mods`. The code for them is
in this version. The pak is not published yet and is not in the release zip, so every player lands in Xion's training
room, and `UE4SS.log` has one line that says why.

With the pak, Join draws one of the five halls. A guest warps once to the hall of the match lobby she joined, and the
host of a private match picks the hall. Players with and without the pak never meet in a match: Search keeps them
apart, and a join by code to a hall you lack ends with
`Left the match: its lobby map is missing or a different version here.` Each hall has seats: at each arrival the mod
places Stellar Blade's own chairs on them, so the game's Rest prompt (F or the right trigger) seats EVE as on Xion's
chairs. On a seat whose chair the game did not bind, and on the Cloister's two camp seats, F5 within 1.5 m seats her.
Built from source, `tools/install.py --pak <folder>` installs a pak kept on your PC (see
[Building](../dev/building.md#toolsinstallpy)).

## The PvP test

`coop pvp on` starts a test of PvP damage with the friend linked to you in an online session. Both of you type it.
Both of you need a co-op save and the shared enemies off (co-op menu, Options, Combat, or `shared_enemies=off`), since
both run on the same fight code; the shared enemies are on by default. `pvp_spike=on`, which lets the command run, is
the default.

In your game a stand-in enemy, `M_DummyA` from the game's character table, follows your friend's ghost with no HP bar
and no AI.
Each hit you land on it is healed back on the dummy and sent to your friend's game, which takes that HP off her EVE.
Her game checks each hit first: it counts only from a member of the session whose ghost is within 15 m of her EVE, at
most the cap of the move that made it, and at most half her maximum HP a second from one attacker. Her HP never goes
below 1, so nobody dies and nothing is scored. Only her HP changes: her EVE does not react to the hit, and her guard,
parry or dodge does not stop it. `coop pvp status` prints the test's counts and `coop pvp off` ends it.

## Link protocol

The match lobbies and the PvP test added lines to the Steam link in protocol 20 (0.11.0). This version uses protocol 29
and does not link with 0.11.0 or older versions, with a friend or in a match lobby. Search never finds their
lobbies. Every player has to update (see [INSTALL.md: Update](../../INSTALL.md#update)).

## Test status

- On 2026-11-12, on one PC, the recruiter's Join saved the co-op game and took EVE to Xion's training room, and Search,
  with nobody else searching, hosted a public lobby.
- On 2026-11-14, on one PC with a local hall lobby pak, the same route led to the Station hall, and Search hosted a
  lobby there. The recruiter appeared by himself at the Xion load. F5 on a seat played Stellar Blade's sit loop for 6 of
  20 tries.
- Changes made after those two runs have not run in game: the black screen held over each arrival, Xion's fence at
  30 m (it was 27 m on 2026-11-12), Stellar Blade's chairs on the hall seats and the chat with nobody connected.
- Leave and the return to Xion have not been tested in game.
- Two or more players in one match lobby have never been tested in game. Search finding another player, private
  matches, join codes for match lobbies, the countdown, the round's start, ghosts of several members, mutes and the
  rules for players who are not Steam friends are checked only by the tests, which run the link against a fake Steam
  with up to 8 games (see [Tests](../dev/tests.md)).
- Score attack has never run in game.
- Doro races in matches have never run in game.
- The PvP test has not run in game, on one PC or on two. Its limits are checked by the native tests `game_pvp_test`
  and `fight_enemies_engine_test`.
