-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The HUD entry's glyph: the Right twin of the pad glyph the game shows, or the gun mode key's keyboard icon.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local D=require('fight.gunmode.ui.dpad')
local P='/Game/Art/UI/Texture/Interaction/'
assert(D.glyph_path(P..'XB/KeyIcon_XboxOne_Gamepad_DPad_Up.KeyIcon_XboxOne_Gamepad_DPad_Up','G')
    ==P..'XB/KeyIcon_XboxOne_Gamepad_DPad_Right.KeyIcon_XboxOne_Gamepad_DPad_Right')
assert(D.glyph_path(P..'PS/KeyIcon_DualShock4_Gamepad_DPad_Up.KeyIcon_DualShock4_Gamepad_DPad_Up','G')
    ==P..'PS/KeyIcon_DualShock4_Gamepad_DPad_Right.KeyIcon_DualShock4_Gamepad_DPad_Right')
assert(D.glyph_path(P..'PC/KeyIcon_KeyBoard_Q.KeyIcon_KeyBoard_Q','G')==P..'PC/KeyIcon_KeyBoard_G.KeyIcon_KeyBoard_G')
assert(D.glyph_path(P..'PC/Something.Something','G')==nil and D.glyph_path(nil,'G')==nil)
print('gunmode dpad_test ok')
