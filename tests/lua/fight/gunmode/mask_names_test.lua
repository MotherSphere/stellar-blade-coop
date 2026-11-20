-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The input mask's names: Luke's combat names masked in both modes, dry or not; native mode keeps the game's aim and
-- fire, except TPSFire while dry; own mode masks both; native_mask_triggers=false keeps the trigger names live.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local GunMode=require('fight.gunmode.mode')
local cfg=setmetatable({native_mask_triggers=true},{__index=require('fight.gunmode.config').DEFAULTS})
local melee={'AttackLight','AttackStrong','SpecialCommand1','SpecialCommand2','CommandKey7','CommandKey8','LeftTriggerKey','RightTriggerKey'}
for _,native in ipairs({true,false}) do for _,dry in ipairs({false,true}) do
    local on=GunMode.mask_names(cfg,native,dry)
    for _,n in ipairs(melee) do assert(on[n],n..' live with the rifle out (native '..tostring(native)..', dry '..tostring(dry)..')') end
end end
local _,any=GunMode.mask_names(cfg,true,false)
assert(not any.TPSFire and not any.TPSMode,'native with rounds: the game aims and fires')
_,any=GunMode.mask_names(cfg,true,true)
assert(any.TPSFire and not any.TPSMode,'native dry: the trigger reaches nothing, the aim stays')
_,any=GunMode.mask_names(cfg,false,false)
assert(any.TPSFire and any.TPSMode)
-- native_mask_triggers=false: the trigger names stay live in native mode only
local c2=setmetatable({native_mask_triggers=false},{__index=cfg})
local on=GunMode.mask_names(c2,true,false)
assert(not on.LeftTriggerKey and not on.RightTriggerKey and on.CommandKey7 and on.AttackLight)
on=GunMode.mask_names(c2,false,false)
assert(on.LeftTriggerKey and on.RightTriggerKey)
print('gunmode mask_names_test ok')
