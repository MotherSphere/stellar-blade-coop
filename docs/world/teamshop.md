# Team shop

The team shop sells outfits made by SBO team members for gold, in Stellar Blade's own shop screen. Type
`coop teamshop` in the console on a [co-op save](../players/saves.md#co-op-saves). The screen is the one the vending
machines open. It lists the team's items with their prices in gold. Its lines go to `UE4SS.log` as
`[StellarCoop][TS]`. It has not been tested in game yet.

The shop sells one item for now: the Gothic Rose suit (`SBOTeam_GothicRose`, the game's cut `BS_1000` outfit), for
5000 gold. It shows in the screen's All tab. Whether the game also lists it under Look was not checked.

## Buying and wearing

The game does the buy: it takes the gold and puts the suit in EVE's inventory. Equip it in the game's own menu like
any other suit. The buy counts toward no achievement.

A suit EVE already holds is not sold again. The screen refuses the buy with the game's full inventory message and
keeps your gold.

Each player buys in their own game. Nothing of the shop goes over the Steam link.

## The rows

The shop's items and the shop itself are rows the mod adds to the game's tables (ItemTable, ShopItemTable and
ShopTable). They go in at the title screen, once a game run, when the co-op save files are picked. Your own saves
never get them. The mod then reads every row back. Rows refused, stopped on a fault or read back other than written
keep the shop shut for the game run. The log says why once.

`coop saves export` refuses a save that names a team item anywhere: in the inventory, in a pickup left in the world,
on a quick slot or in the game's record of limited buys (`SBShopHistory`). That record may keep the item's name after
the buy. Nobody has checked yet. A save with a team item bought may then stay a co-op save for good.

## When `coop teamshop` refuses

- On your own saves: the shop opens on a co-op save only.
- The rows are not in: load the co-op save from the title, where they go in first.
- The rows were refused, stopped on a fault or read back other than written: the message names the reason.
- Without the Steam link, or with a native part older than the shop.
- After the shop screen's fault this game run.
- While the game is paused or shows one of its screens.
- While an earlier `coop teamshop` waits for its answer (5 s at most).

After `coop off` a team shop screen left open stays the game's own screen until you close it.
