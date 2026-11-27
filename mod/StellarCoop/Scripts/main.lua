-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- StellarCoop, Stellar Blade Online: the file UE4SS runs. docs/usage.md lists the keys and the coop console commands.
-- main/ holds the runtime every module plugs into: boot, base, the module loader, coop ui and coop off, the UI kit,
-- input, the two loops and the key binds. Each module's <module>/wiring.lua holds its part of the startup: what it
-- builds, what it reads later of other modules and the fields of M it sets.
-- Every line of ours in UE4SS.log goes through this print, with SteamIDs and join codes masked (core/mask.lua): players
-- post that log in public. coop-status.txt keeps them whole.
local mask=require('core.mask')
local print=function(text) _G.print(mask(text)) end
local function log(message) print('[StellarCoop] '..tostring(message)..'\n') end
local has_version,VERSION=pcall(require,'version') -- Written by tools/install.py; absent in the source tree.
if not has_version or type(VERSION)~='string' then VERSION='dev' end
-- The native part starts its own worker when Windows loads it; '*' only links the DLL and calls nothing. It pins
-- itself, so a Lua reload that frees this state's libraries never unloads it.
local folder=debug.getinfo(1,'S').source:match('^@(.*)[\\/]Scripts[\\/][^\\/]*$')
-- M: what the runtime files and the modules share (each wiring.lua lists the fields its module sets).
local M={print=print,log=log,VERSION=VERSION,folder=folder,commands={}}
-- The modules in the order their constructors run (the same as before the split; no module depends on it).
local MODULES={'online.partner','online.modes.nightop','fight.bosses','online.group','online.modes.race','eve',
    'story.scenes','world.maps.matrix13','online.session','online.photo','fight.enemies','story.quests','world.objects',
    'story.together','online.lobby','vehicles.bike','world.daynight','cutmenus','online.saves','world.teamshop',
    'fight.gunmode','online.modes.scoreattack','online.modes.fishing','online.modes.photohunt','world.maps.sboxion',
    'closet'}
require('main.boot')(M)
require('main.base')(M)
require('main.loader').run(M,MODULES)
require('main.commands')(M)
require('main.ui')(M)
require('main.input')(M)
require('main.frame')(M)
require('main.pass')(M)
require('main.keys')(M)
log('Loaded version '..VERSION..'. '..M.USAGE)
