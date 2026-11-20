-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The official tracks of Doro races in matches, by lobby room: {[room key]={track name,...}}, the room key as
-- online/lobby/sbo.lua's target().key gives it ('xion' or a hall's). Each name is a track file in
-- online/modes/race/match/tracks/, which ships in the mod. Lua cannot list a folder, so this list names them. Xion's
-- training room has xion_eight, a figure eight of 6 checkpoints and 5 laps computed from the room's floor and wall in
-- the paks. The halls have none yet.
return {xion={'xion_eight'}}
