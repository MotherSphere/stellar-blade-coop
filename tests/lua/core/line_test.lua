-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- core/line.lua: a chat line cleaned, wrapped and measured, a Steam name for the screen, a feed line in SB's words and
-- an FName's number, one case each from the tests of session/chat.lua, session/join.lua and group/travel.lua.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Line=require('core.line')
assert(Line.clean('  hi  ')=='hi')
local THI,KO='ที่','กิ้'
assert(table.concat(Line.wrap(THI:rep(75),70),'|')==THI:rep(70)..'|'..THI:rep(5),'Thai, no space: 70 letters a row')
assert(Line.columns('Ab 日本'..KO..'بَ')==9,'Columns as wrap counts them')
assert(Line.name('<Orange>Kaanta</>')=='OrangeKaanta/')
local fr={UI_Night_Message_ComeBackFriend='{Name} a rejoint la partie.'}
assert(Line.feed('Kaanta joined.',function(key) return fr[key] end)=='Kaanta a rejoint la partie.')
assert(Line.number('Xion_Camp_10')==11 and Line.number('Xion_Camp_10_01')==0)
print('core/line_test: ok')
