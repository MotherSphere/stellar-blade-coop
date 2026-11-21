-- GUObjectArray for Stellar Blade build 26123051 (executable TimeDateStamp 0x6ad8eff1, SizeOfImage 0x15fa3000).
-- From https://github.com/Rev-OG-UwU/SB-UE4SS at a63c3f8e, where the file is named GUObjectArracy.lua. UE4SS v4.0.0
-- loads only UE4SS_Signatures/GUObjectArray.lua, the name the file has in https://github.com/Chrisr0/RE-UE4SS at
-- e6e59de9, where it first appears. MIT License, Copyright (c) 2022 Narknon. The full notice is in NOTICE. The code
-- below is the fork's, unchanged.
-- Ghidra on 26123051: one match, at 0x142b8c4e3 in FUN_142b8bc20 (89 05 57 0d 25 04, mov [rip + 0x4250d57], eax).
-- Its target 0x146ddd240 is GUObjectArray: AllocateUObjectIndex (FUN_142b890d0) reads its fields from there.
function Register()
    return "89 05 ?? ?? ?? ?? 85 DB 7F 36 4C 8D 05 ?? ?? ?? ?? "
end

function OnMatchFound(matchAddress)
    local displacement = DerefToInt32(matchAddress+2)
    local rip = matchAddress + 4 + 2
    return rip + displacement
end
