# Changelog

## [0.9.0](https://github.com/MotherSphere/stellar-blade-coop/compare/v0.8.0...v0.9.0) (2026-11-09)

Both players need 0.9.0 and Stellar Blade's Steam build 26123051.

Game update
- Steam's update of Stellar Blade on 2026-11-05 (build 26123051, the Bayonetta collaboration) moved every address the
  mod reads in the game. This version is ported to that build and does not run on the old build 24463856.
- 0.8.0 does not run on the new build: its native part turns itself off (`coop status` shows `engine=off`), so the
  partner's movements, shared fights, shared quests and the co-op saves stop working.
- The link protocol stays 19. A player on 0.8.0 can still join a 0.9.0 session, but with the native part off, so
  both players should update.
- Checked on one PC on 2026-11-09: the native part starts on the new build, the co-op saves switch on and load, and
  every table row the mod adds goes in with none refused. It has not been played between two PCs on this build yet.

Documentation
- The README and the guides are split into one page per subject, with an index in docs/README.md and the technical
  pages under docs/internals/.

Report problems on the Discord with coop-report.txt, coop-link.log and UE4SS.log.


## [0.8.0](https://github.com/MotherSphere/stellar-blade-coop/compare/v0.7.5...v0.8.0) (2026-11-03)


### Features

* **debug:** add coop near to list the zone objects around EVE ([51acd4d](https://github.com/MotherSphere/stellar-blade-coop/commit/51acd4dc39da18699651c35e40d3f9f0344748db))
* **mxiii:** add five Matrix 11 Naytibas to zone 2 ([c8894fd](https://github.com/MotherSphere/stellar-blade-coop/commit/c8894fddc4d64eea998d141d36d032f6666dd2ed))
* **mxiii:** add the 25 records to the Data Bank ([05da12b](https://github.com/MotherSphere/stellar-blade-coop/commit/05da12ba498e1fbf655799554cb64cbfa332fc57))
* **mxiii:** add the final pass loot of zones 1, 3 and 4 ([b1504a9](https://github.com/MotherSphere/stellar-blade-coop/commit/b1504a9cd77cd07853be656b80add27cd43adacd))
* **mxiii:** add two hidden zone 0 pickups ([cf0c82d](https://github.com/MotherSphere/stellar-blade-coop/commit/cf0c82d9695a66786766a04b25404075bacea529))
* **mxiii:** give Mila a body at the shelf recess and the drive room ([9672873](https://github.com/MotherSphere/stellar-blade-coop/commit/9672873b4bf9b174ec97aeb800cb360b98bcbbc5))
* **mxiii:** hold the fans still until their levers after the Lion ([16bbfdd](https://github.com/MotherSphere/stellar-blade-coop/commit/16bbfdd706f43fa796bd2748f6f88d2385461c41))
* **mxiii:** let coop mxiii mila pick Mila's pose and scale ([c43934b](https://github.com/MotherSphere/stellar-blade-coop/commit/c43934b50bae53cb715df0928691508c3b2326fa))
* **mxiii:** lift the Z2P07 grille, move lever 434 to a wall switch, add an R16 exit ledge ([7aa9f6b](https://github.com/MotherSphere/stellar-blade-coop/commit/7aa9f6b476ea84f9dd9416634f370b4045e10ba3))
* **mxiii:** play the zone talks in game ([8f25c5c](https://github.com/MotherSphere/stellar-blade-coop/commit/8f25c5cbc8a926c5df34c3726f576dc204470cea))
* **mxiii:** spawn real breakable boxes and barrels ([4bf81c1](https://github.com/MotherSphere/stellar-blade-coop/commit/4bf81c1122cf3afbcfca6b955daa5849e22a912c))
* **story:** play Matrix XIII zone talks in the game's subtitle box ([e230450](https://github.com/MotherSphere/stellar-blade-coop/commit/e230450e81c1cdacdba871ecba417c172acbecec))


### Bug Fixes

* **ghost:** name every mesh with no skeleton in the build line ([f8d4202](https://github.com/MotherSphere/stellar-blade-coop/commit/f8d420290423b605cae99a73490abb0de5c5a9c4))
* **mxiii:** check what a held address holds for Mila and the fans ([1503ba9](https://github.com/MotherSphere/stellar-blade-coop/commit/1503ba9df7774a6f14c371bd9c8d18e5df15c4c8))
* **mxiii:** clear the memorysticks' reward, order the board, refill a reloaded table ([022e4f5](https://github.com/MotherSphere/stellar-blade-coop/commit/022e4f5c5d62aae6a3a5f9cd5be63182ac5684b9))
* **mxiii:** enable the fan levers when the fallback Lion dies ([3e6b625](https://github.com/MotherSphere/stellar-blade-coop/commit/3e6b625e8a1d16e4516dc183081d6df718577f49))
* **mxiii:** find ladder meshes and box classes again in each world ([83e03ee](https://github.com/MotherSphere/stellar-blade-coop/commit/83e03ee52881209f601e128c54adde8f461a21ed))
* **mxiii:** have Noa come home with Yohan on the 18:40 ([ca73967](https://github.com/MotherSphere/stellar-blade-coop/commit/ca73967a5b6bd5c5be938a24d394cf34474a18a5))
* **mxiii:** hold the zone talks to their room, their save and solo play ([401a1b4](https://github.com/MotherSphere/stellar-blade-coop/commit/401a1b438596f64f36cb7e6f846e9968aa54d2ed))
* **mxiii:** pass inFastUpdate to SetActorEnableCollision on break proxies ([f2bfdd1](https://github.com/MotherSphere/stellar-blade-coop/commit/f2bfdd19f2607ba441bd6c36df287619b8ca4027))
* **mxiii:** regenerate the rows after the 18:40 title ([20e3a28](https://github.com/MotherSphere/stellar-blade-coop/commit/20e3a28da5078d6a8b766708449ea0f156d63c0b))
* stop reading game objects kept across a map change ([f922838](https://github.com/MotherSphere/stellar-blade-coop/commit/f922838519ce8cc12d9aebad54c7887edeb1bf7f))
