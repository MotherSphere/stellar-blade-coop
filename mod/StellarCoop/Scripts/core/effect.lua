-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The ChainSpin's effect call and its target, moved out of eve/chainspin.lua for every module to read.
local N=require('core.player')
local ChainSpin={}
local MASK=0xFFFFFFFF
-- The one call: SB's cheat request, SBApplyEffectMe with an EffectTable ID as its argument, on EVE's GUID; no player
-- ID (that word reads none). ChainSpin's effect, or one of coop devmenu's.
function ChainSpin.apply(pc,guid,id)
    assert(math.type(guid)=='integer' and guid>0 and guid<=MASK,'not a GUID')
    assert(math.type(id)=='integer' and id>0 and id<=0x7FFFFFFF,'not an effect ID')
    pc:ServerRequest_Cheat(guid,0,'SBApplyEffectMe',tostring(id))
end
-- Whom the call goes to: EVE's GUID from the native engine line (me=, the key the world's player map holds, which the
-- revive uses too), with no respawn or warp under way, EVE in the world and her controller. The GUID and the
-- controller, or nil and why.
function ChainSpin.target(status)
    local warp,me=(('\n'..(status or '')):match('\nengine=([^\r\n]*)') or ''):match(' warp=(%a+) me=(%d+)')
    if not warp then return nil,'the native status has no warp read yet: try again in a moment' end
    if warp~='idle' then return nil,'a respawn or a warp is under way: try again once it ends' end
    local guid=math.tointeger(tonumber(me))
    if not guid or guid==0 then return nil,"EVE's GUID reads 0: nothing asked" end
    if not N.her() then return nil,'no EVE in the world' end
    local pc=N.controller()
    if not pc then return nil,'no SB player controller' end
    return guid,pc
end
return ChainSpin
