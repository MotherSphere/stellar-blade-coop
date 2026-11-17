-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- UE4SS.log's masking (core/mask.lua), on the cases of tests/native/link/protocol_test.cpp for link/protocol.h's
-- masked(): *** and the last 4 digits of a SteamID, the first 3 characters of a join code written as a code or as its
-- lobby id, a lobby id with no code masked as a SteamID; other numbers and words of the same shape left whole.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local mask=require('core.mask')

local cases={
    ['allow 76561198000000009 ignored: not in the lobby']='allow ***0009 ignored: not in the lobby',
    ['hosting lobby 109775241346428561, join code CCS-CBMH']='hosting lobby CCS-****, join code CCS-****',
    ['join RAN-GTGX']='join RAN-****',
    ['lobby 109775241275271709']='lobby RAN-****',
    ['lobby 109775245212123136']='lobby ***3136',
    ['steam=ready steamid=76561198012345678 appid=3489700']='steam=ready steamid=***5678 appid=3489700',
    ['76561198012345678\\StellarBladeSave00.sav _76561198012345678_']='***5678\\StellarBladeSave00.sav _***5678_',
    ['round=1 start ffa map 5 76561198000000001,76561198000000002']='round=1 start ffa map 5 ***0001,***0002',
    ['76561193665298432 81064793292668927 112589990684262399']='***8432 ***8927 ***2399',
    ['[StellarCoop] link: pending=76561198000000009 Kaanta\n']='[StellarCoop] link: pending=***0009 Kaanta\n',
}
for line,want in pairs(cases) do
    assert(mask(line)==want,mask(line))
    assert(mask(mask(line))==want,'masked once only')
end
for _,kept in ipairs({'','fight_chars 15011001 2, appid=3489700, hash 12345678901234567',
    '76561193665298431 81064793292668928 765611980123456789 7656119801234567',
    'a76561198012345678 76561198012345678b 2026-11-16T19:34:00.000Z',
    'ccs-cbmh ZZZ-ZZZZ XCCS-CBMH CCS-CBMHX CCS-CBM non-zero UTF-8 one-shot'}) do
    assert(mask(kept)==kept,mask(kept))
end
print('mask_test ok')
