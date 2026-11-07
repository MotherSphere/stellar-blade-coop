# EVE's cut moves and looks

The commands on this page change what your own EVE can do or wear: a Tachy Mode skill cut before release (`coop
chainspin`), two hairs and four suits that no item gives (`coop wear`), animation clips played as emotes (`coop emote`),
two developer tools the game ships switched off, flight and slow motion (`coop fly` and `coop slowmo`), and a cut glide
(`coop glide`). How they work, except `coop wear`, is in [internals/cut-eve.md](internals/cut-eve.md). Cut enemies are
in [cut-enemies.md](cut-enemies.md).

## Cut Tachy skill: `coop chainspin`

The game's files hold a Tachy Mode skill for EVE that was cut before release, the ChainSpin: her animation
`P_Eve_Tachy_Skill_ChainSpin1` with its root motion, a wing animation, two move rows
(`P_Eve_Tachy_Skill_ChainSpin1_Move1` and `_Move2`) and the skill icon `SI_TachyMode_ChainSpin1`. No skill row, step or
skill presentation (Show) of EVE's uses them, so no button plays it. The prologue's Tachy NPC kept a version: its skill
`N_TachyNPC_SwingChain` plays the Show `CH_NPC_TachyNPC/Skill/N_TachyNPC_SwingChain`, which plays EVE's own ChainSpin
animation (3.25 s, nine steps) and takes the two moves.

`coop chainspin` adds EVE's version to the game's tables in memory with the [cut Lion's rows](cut-enemies.md#cut-boss-coop-lion) (11
of the 237: the skill `P_Eve_Tachy_Skill_ChainSpin1_1`, its nine steps and an effect), then asks the game to apply that
effect on EVE. The effect starts the skill only while she is in Tachy Mode; outside it, nothing happens. It is a test
command, left out of the usage line, and runs only on a [co-op save](playing-with-a-friend.md#co-op-saves). Its lines go to `UE4SS.log` as
`[StellarCoop][CS]`.

- The steps are copies of ChainStab's, the first of EVE's four Tachy skills, with the Tachy NPC's timing and moves. Its
  four hits strike through the same weapon and arm collision as ChainStab, within 10 m of her, each for a quarter of
  the skill's damage; the last one stuns for 1.5 s.
- The request is the game's own cheat request, `SBApplyEffectMe` with the effect's ID (1004500), which the game runs as
  a logic job on EVE. It goes out once the rows are in (the first time in a game run it waits for them, 30 s at most),
  and never while a respawn or a warp is under way.
- No button starts it. EVE's four Tachy skill buttons are taken. A fifth command could go at the end of the Tachy
  stance's command list, written in place as for the [Shock Bolt](night-operation-shop.md#cut-ammo-shock-bolt)'s gun stances; none was added.
- Nothing is saved: the skill has no skill tree entry, slot or achievement tag, and the rows stay in memory until the
  game exits.
- The Tachy NPC's Show plays no wing animation, so EVE's Tachy wings keep their own pose during the spin. The game has
  no name, description or preview video for the skill.
- Only your game runs it. What your friend sees of it in a session is untested.

| Line | What it answers |
| --- | --- |
| `ChainSpin asked: SBApplyEffectMe 1004500 on EVE (guid 228)` | The request went out, for EVE's GUID |
| `ChainSpin waits for its rows (...)` | The rows were asked of the native part; the request follows once they are in, and its result comes as an `OK:` or `STOP:` line then |
| `ChainSpin: its rows are not in (...)` | The rows could not be added: nothing was asked |
| `ChainSpin request failed: ...` | The game call raised: nothing was asked |

None of it has been tried in game yet. Check that EVE plays the spin in Tachy Mode and nothing outside it, that she
travels with its two moves (7.5 m, then 2.9 m), that its four hits land on enemies around her, and that the game keeps
running normally after it.

## Cut hairs and suits: `coop wear`

The game's files hold two hairs and four suits that no item gives. `coop wear` puts them on your EVE by setting the
meshes of her own hair and body components. It changes what is drawn and nothing else: your equipment, inventory, saves
and quests are never read or written, so the game's menus still show what you equipped and the next save keeps it. It
runs on any save and has not been tried in game yet. Its lines go to `UE4SS.log` as `[StellarCoop][WR]`.

| Name | Part | Mesh | What it is |
| --- | --- | --- | --- |
| `nyaaa` | Hair | `EVE_HR_14` | A bob cut with a lace headband and mechanical cat ears (Nyaaa, a hair whose name and description are in the game's text, with no item) |
| `rabbit` | Hair | `EVE_HR_15` | A bob cut with long mechanical rabbit ears (Mecha Rabbit, the same) |
| `gothic` | Suit | `CH_P_EVE_IberisCos` | Gothic Rose (`BS_1000`), the gothic dress of Iberis, Lily's late colleague |
| `rider` | Suit | `CH_P_EVE_03_Body` | Daily Rider (`BS_Leather_Jean2`), an earlier build of Daily Biker |
| `diving2` | Suit | `CH_P_EVE_01_TypeB` | Planet Diving Suit (5th) V2 (`BS_Blue_Suit_Var2`) |
| `golden` | Suit | `CH_P_EVE_InnerSuit1` | Golden Skin Suit (`BS_102_1`), with the placeholder materials of the asset |

The meshes are in `/Game/Art/Character/PC/`, the hairs under `00_HR/`. Each suit has an EquipmentTable row and no item.

- `coop wear` lists what is worn and the names.
- `coop wear <name>` puts one on. A hair and a suit can be worn together. A second hair or suit replaces the first. A
  hair also gets its own physics asset and its own animation Blueprint, which moves its ears and strands. On the part
  it changes, a slot where the game put a material of its own (your hair colour) shows the cut mesh's material.
- `coop wear off` gives the game's hair and suit back. `coop wear off hair` and `coop wear off suit` give one back.

A suit changes the body mesh alone. EVE's animations, face, ponytail and body collision stay as the game set them. The
ponytail keeps the colour and the cloth collision of what you equipped, so its strands may pass through a long dress.

The game can put its own meshes on again: after its wardrobe, a map load, a cutscene or photo mode. Once a second, while
the game is neither paused nor showing one of its screens, `coop wear` looks at the worn parts. A part that shows a mesh
of the game's again takes that look as the one to give back, then gets the cut one again, with a `re-applied` line in
the log. An outfit you pick in the wardrobe while a suit is worn therefore shows after `coop wear off suit`.

The look lasts until `coop wear off`, `coop off`, a Lua reload (Ctrl+R) or a game restart. While one is worn,
`coop-wear.txt` holds your EVE's own look, so the next Lua load gives it back if this one could not.

Your friend sees it. The capture reads the mesh of each part of your EVE every second. The ghost then loads the same
hair or suit from your friend's own game files, so nothing more is needed on that PC. The Gothic Rose dress has 385
bones, where the other suits here have 159 to 203. The capture and the ghost take up to 1024 bones a part, so the ghost
wears the dress on its own mesh, not the base suit. A cut mesh shows its own materials on both screens, with the `dyes`
look on or off.

## Emotes: `coop emote`

`coop emote <name>` plays one of EVE's animation clips on her. It runs on any save and writes nothing. It has not been
tried in game yet.

| Category | Names |
| --- | --- |
| Greetings | `salute`, `kungfu`, `toast`, `wave`, `wave2` |
| Expression | `clap`, `heart`, `thumbsup`, `victory`, `kiss` |
| Orders | `bringiton`, `giveme`, `hush`, `reach` |
| Emotion | `omg`, `what`, `worry`, `wish`, `wedidit` |
| Pose | `charm`, `confident`, `cutie`, `sweetie`, `squat`, `stretch`, `warmup`, `walk`, `shutter1`, `shutter2`, `shutter3` |
| Dance | `flow`, `nataraja`, `somersault` |
| Cut | `chariotstruggle`, `chariotcounter`, `chariotfail`, `chariottakedown`, `kalitakedown`, `kaligrab` |

- `coop emote` and `coop emote list` print the names by category.
- `coop emote <name>` starts one, and a second name replaces it. It does not start while EVE is in the air or in the
  middle of an attack or a dodge.
- Moving, a jump, a dodge or an attack ends it with a 0.25 s blend. So do `coop emote off`, `coop off`, a map change,
  photo mode and the game ending the clip itself. A Lua reload (Ctrl+R) stops a clip the earlier load left playing.

The first six categories are those of the game's cut Social Action menu, whose own gestures never shipped. Their 31
poses come from photo mode. Each one is a still of 0.2 s at most, played in a loop, so EVE takes the pose and keeps it
until she moves. The other eight clips play once and end by themselves:

- `wave` and `wave2` are the selfie mode's two waves (`Hello_Selfie_L` and `Hello_Selfie_R`, 3 s each). In selfie
  mode they sit in a blend space that follows the camera's direction; here each one plays whole.
- The Cut category holds clips of EVE's made for two enemies that have no character in the game files: no mesh, no
  `CharacterTable` row and no name in the game's text. The Chariot was removed (a test spawn row and a despawn effect
  still name it): its struggle (`chariotstruggle`, 14.8 s) and its two endings as the files name them,
  `ConfrontAttack` (`chariotcounter`, 10.0 s) and `ConfrontFail` (`chariotfail`, 1.5 s), and her takedown on it
  (`chariottakedown`, 4.9 s). Kali may be a cut enemy or an early name of one that shipped: her takedown on Kali
  (`kalitakedown`, 5.6 s) and Kali's grab (`kaligrab`, 5.8 s). In all six, EVE acts alone.

The native part plays the clip through the game's own custom animation call, the one the game uses for EVE's flight
start, so it goes through the custom animation nodes of her animation blueprint. Without the native part, on another
game build or after a fault in that call, the clip goes in as an animation montage instead, which most likely shows
nothing: her blueprint has no montage slot in the game files read for this version. A linked friend sees what your EVE
shows, through the pose stream the ghost already copies.

Its lines go to `UE4SS.log` with the `[StellarCoop][EM]` tag. With the native part:
`emote clap: Clap asked of the native part (anim 482913, loop)` when one starts (`once` for the eight clips above),
`emote clap: Clap plays (anim 482913)` once the game took it, and `emote clap ended (movement input) after 4.2 s` when
it ends. Instead of `movement input` the end line can say `in the air`, `a skill runs`, `the clip ended`,
`her animation blueprint showed nothing`, `the game refused it: <why>`, `no answer from the native part` (none in
5 s), `the native clips stopped` (a fault), `her EVE changed` (a map change), `another emote`, `coop emote off`,
`coop off` or `error`. When the clip did not show, a line also goes on screen and to the log as
`[StellarCoop] STOP: ...`: `coop emote: EVE did not show Clap`, `coop emote: the game refused Clap (<why>)` or
`coop emote stopped: <why>`.

The native part's lines go to `coop-link.log`: `anim 482913 asked: <path> in a loop` (or `once`), then
`anim 482913 playing: SB took the clip in EVE's custom animation slot 0 (ret 0)`, and at the end
`anim 482913 ended after 4.9 s, weight up to 1.00` or `anim 482913 stopped after 4.2 s, weight up to 1.00`, with
`(coop off)` or `(a new Lua load)` after the time when one of them stopped it. The weight says how much of the clip the
blueprint blended in: 1.00 is all of it.

`anim 482913 refused: no EVE of ours in the world`, `refused: EVE has no custom animation slot` and
`refused: the game played nothing (ret -1: the clip did not load, or a clip of a higher priority holds the slot)` say
why nothing played; `refused: coop off` and `refused: a new Lua load` name a play asked just before one of them.

A clip the blueprint takes no weight of for 1 s ends with
`: the slot took no weight, so EVE's animation blueprint did not show the clip`. Time while the game is paused
(`coop freeze`, or a host's photo mode holding the guest) does not count toward that second, since EVE's animation does
not move then; the `after ... s` figure is still the clock's. A fault in the game's call logs `anim fault ...`, says on
screen that the native clips stopped until the game restarts, and sends later emotes to the montage.

Without the native part the start line is
`emote clap: Clap in DefaultSlot, montage AnimMontage /Engine/Transient.AnimMontage_0, playing yes`, and
`the montage no longer plays` replaces `the clip ended`. `emote clap: no montage made for Clap` means the game refused
the montage. After a Lua reload, `emote restore: an earlier load's montage stopped` says the earlier montage was
stopped, and `emote restore failed: <why>` says it could not be. In both cases, after `error` comes
`coop emote stopped: <why>`, repeated as `[StellarCoop] STOP: coop emote stopped: <why>`, and a stop that fails adds
`: not stopped (<why>)` to the end line.

## Debug flight and slow motion: `coop fly` and `coop slowmo`

The game's code holds two developer tools that it ships switched off: a flight move and a slow-motion key. Each one
waits on a setting of the game's (`UseFlyingActionKey`, `UseTimeControlKey`) that only a cheat command sets, and that
command does nothing in the released game. `coop fly on` and `coop slowmo on` have the native part set the setting in
the game's memory, and `off` puts the game's value back. These test commands are left out of the usage line, need the
native part and run on a [co-op save](playing-with-a-friend.md#co-op-saves) only. The flight was tried in game once, with the game's Z key.
The first space bar start was tried on 2026-10-26 and started no flight, since it read a flag the game never sets; the
current one has not been tried in game.

- `coop fly on`: press the space bar a third time while EVE is in the air, and she flies. The jump and the double jump
  are the first two presses, as in the game, and holding the second one still glides with `coop glide on`. After a fall
  from a ledge, it takes three presses in the air. Z and S no longer start a flight; R2 held on a pad still does, as in
  the game.
  - The game's flight carries her along the camera's heading at 10 m/s: turn the camera to steer. Z held climbs, S held
    descends, and with neither she flies level until you press the space bar again or the flight ends on its own
    (landing, or its time pool).
  - The third press does not need to stay held: if the game is not ready to start the flight yet (an action still
    playing, or less than 0.5 s since the last flight), it starts as soon as it is, unless she lands first. The press
    that starts the flight does not drop her, even if you keep it held. After a drop the count starts over, and with
    `coop glide on` the space bar held after the drop glides.
  - Flight time comes from a pool of 90 s that drains while she flies and refills at 1 s per second, the game's own
    values.
  - During a flight the face buttons dodge up, down, left and right, and so do Shift with Z, S, Q or D on the keyboard
    (up, down, left, right). `coop fly on` writes R2 over Z (and over any third slot) in the game's flight key list and
    adds the four Shift keys to the input settings.
  - The game itself ends a flight once no flight key is held. The native part hooks the player controller's key pass
    and, right after it, counts the space bar's presses since EVE left the ground. From the third one it sets the flight
    key each frame until the game starts the flight or she lands. While EVE flies with no flight key held, it sets the
    key again each frame, until the next press. The log's `[FL]` lines say once a flight whether the level flight held.
  - The game sets the flight's velocity whole each frame, with no easing: the mod eases the climb and the descent in and
    out over 0.3 s, and starts a flight at 40 % of its speed, full after 0.6 s. Turns follow the camera at once, as in
    the game.
- `coop slowmo on`: hold R1 on a controller and time runs at 0.2 of its speed until you release it. The game binds no
  keyboard key to it. It waits while a friend is linked, since the slow time would be your game's alone.
- `coop fly off`, `coop slowmo off`, `coop off` and a Lua reload (Ctrl+R) put the game's values back. On a save that is
  not a co-op one, both wait until you are back on one. The mod saves none of it, and the game builds these settings
  again at each start, with one exception: if you change the game's key options while `coop fly` is on, the game can
  save the four Shift keys with them. The mod takes them out again at the next start. Your own key changes stay either
  way.

The keys keep their other uses. R2 is also Interact and the fishing reel, and R1 opens the Burst skills. So with
`coop fly on`, holding R2 in the air flies, and with `coop slowmo on` holding R1 for a Burst skill slows time. Flight
can carry EVE past places the game expects her to reach on foot, and the next save keeps where she is: hence the co-op
saves only.

The native part's lines go to `coop-link.log`: `coop fly on: UseFlyingActionKey set at the game thread's next pass`,
then `gate fly: on, ours, 1 writes` once the setting is set. Once a second, when one of its counts changed, the hook
logs a line such as `fly hold: 5400 steps, 7 presses, 1 armed, 12 armed writes, 1 takeoffs`: how many frames it ran,
the space bar presses it saw, the third presses in the air, the frames it set the flight key before a takeoff and the
flights it saw start. When the game's memory does not hold the setting the way the pinned build does, the native part
writes nothing, logs why and says `coop fly refused: ...` on screen. The level flight's hook goes in at the first
`coop fly on` of a game run (`level flight on: 0x145ccd738 and 0x145cd9a38 swapped from the game's input pass to our
hook`) and stays until `coop off` (`level flight off (coop off): 2 of 2 slots hold the game's input pass again`); in
between it does nothing while `coop fly` is off. If another mod already changed
those slots, it logs `level flight refused: ...` and leaves them alone: the space bar then starts no flight, and R2
flies only while held. A fault in the hook takes the hook out for the rest of the run and says so on screen.

## Cut glide: `coop glide`

EVE's movement code still holds the end of a glide that was cut: a flag that makes her fall at a tenth of the normal
gravity while it is set. Nothing in the game sets the flag any more. Its config keeps a Jump hold time for it (0.2 s)
that no code reads, so no setting or cheat turns it on. `coop glide on` has the mod set the flag itself, with that hold
time. This test command is left out of the usage line, runs on a [co-op save](playing-with-a-friend.md#co-op-saves) only and has not been tried
in game yet.

- With `coop glide on`, hold Jump (Space, or A/Cross on a controller) in the air. Once Jump has been held for 0.2 s and
  EVE is past the top of her jump, she glides until you release Jump or she lands. To glide after a double jump, hold
  the second press.
- A glide does not stop a fall. EVE keeps the downward speed she had when it started and gains speed ten times more
  slowly, so a glide started right after the top of a jump is the slowest. Her air control stays the game's.
- Only the game's default Jump keys count. A Jump key changed in the game's settings is not followed.
- She does not glide during the developer flight (`coop fly`), whose own gravity the glide would replace.
- How it looks is unknown. The game has three glide animations (`Proto_Glide`, `Proto_Glide_1`, `Proto_Glide_Start`),
  but whether its animation graph still plays them is not known, so EVE may glide in her fall pose.
- `coop glide off`, `coop off` and a Lua reload (Ctrl+R) clear the flag. On a save that is not a co-op one, she does
  not glide until you are back on one. Nothing of it is saved.

As with the flight, a glide can carry EVE to places the game expects her to reach another way, and the next save keeps
where she is. That is why it runs on co-op saves only.

Its lines go to `UE4SS.log` with the `[StellarCoop][GL]` tag: `glide on EVE (velocity Z -120 cm/s)` when a glide
starts and `glide ended (landed) after 2.4 s` when it ends, with `Jump released` or `flight or rising` instead of
`landed` when that is what ended it.
