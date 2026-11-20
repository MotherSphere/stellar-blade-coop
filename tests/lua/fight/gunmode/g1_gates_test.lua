-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode G1 gates with lua5.4 alone: limits, pitch-only gates and log-only gates.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Gates=require('fight.gunmode.g1_gates')
assert(Gates.check('butt_pocket',1.0)==true and Gates.check('butt_pocket',1.01)==false)
assert(Gates.check('rwrist_neck',5.9)==false and Gates.check('elbow_R',150)==true and Gates.check('elbow_R',59)==false)
assert(Gates.check('eye_sight',9,40)==nil and Gates.check('eye_sight',9,0)==false)
assert(Gates.check('breast_clear_40',-0.5,40)==true and Gates.check('breast_clear_0',-0.5,40)==nil)
local pass,fail=Gates.judge({butt_pocket=0.5,rwrist_neck=2,fingertip=9},0)
assert(#pass==1 and pass[1]=='butt_pocket' and #fail==1 and fail[1]=='rwrist_neck')
assert(not pcall(Gates.check,'nope',1))
print('g1_gates_test ok')
