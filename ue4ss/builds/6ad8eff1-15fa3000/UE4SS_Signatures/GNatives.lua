-- GNatives for Stellar Blade build 26123051 (executable TimeDateStamp 0x6ad8eff1, SizeOfImage 0x15fa3000).
-- From https://github.com/Rev-OG-UwU/SB-UE4SS at a63c3f8e (assets/UE4SS_Signatures/GNatives.lua). The file first
-- appears in https://github.com/Chrisr0/RE-UE4SS at e6e59de9. MIT License, Copyright (c) 2022 Narknon. The full
-- notice is in NOTICE. The code below is the fork's, unchanged.
-- Ghidra on 26123051: the pattern matches 83 times (0x140960297 to 0x1409697b7). Each match is lea rax (48 8D 05) of
-- 0x146f17900, the GNatives table. The exec thunks index it with the next script byte (FUN_1446be280 calls
-- (&DAT_146f17900)[opcode]), as does ProcessLocalScriptFunction (FUN_142b79420). UE4SS takes the first match.
function Register()
    return "48 8D ? ? ? ? ? B9 20 00 00 00 0F 1F 40 00 66 0F 1F 84 00 00 00 00 00 48 89 10 48 89 50 08 48 89 50 10 48 8D 40 40 48 89 50 D8 48 89 50 E0 48 89 50 E8 48 89 50 F0 48 89 50 F8 48 83 E9 01"
end

function OnMatchFound(MatchAddress)
    local LeaInstr = MatchAddress
    local NextInstr = LeaInstr + 0x7
    local Offset = LeaInstr + 0x3
    local AddressLoaded = NextInstr + DerefToInt32(Offset)
    return AddressLoaded
end
