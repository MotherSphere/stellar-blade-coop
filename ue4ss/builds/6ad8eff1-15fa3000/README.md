# UE4SS files for Stellar Blade build 26123051

UE4SS v4.0.0 reads these files from its `ue4ss/` folder in the game's `SB/Binaries/Win64`. The folder name is the
game executable's PE TimeDateStamp and SizeOfImage in lower-case hex (`6ad8eff1-15fa3000`), the two values that
`check_build()` in `native/src/game/partner/engine.h` pins. Every address below was read in Ghidra on
`SB-Win64-Shipping.exe` of build 26123051 on 2026-11-21. `tests/tools/ue4ss_test.py` checks each file.

| File | Source | License | How it was checked |
| --- | --- | --- | --- |
| `UE4SS_Signatures/GNatives.lua` | Rev-OG-UwU/SB-UE4SS at a63c3f8e. It first appears in Chrisr0/RE-UE4SS at e6e59de9. Code unchanged, header added. | MIT, notice in NOTICE | The pattern matches 83 times. Each match is a LEA of 0x146f17900, the table that every exec thunk calls through. The test runs the script on each match in the executable. |
| `UE4SS_Signatures/GUObjectArray.lua` | The same fork, where the file is named `GUObjectArracy.lua`. Renamed to the name UE4SS v4.0.0 loads (Chrisr0's name). Code unchanged, header added. | MIT, notice in NOTICE | One match, at 0x142b8c4e3 in FUN_142b8bc20. Its target 0x146ddd240 is the base that AllocateUObjectIndex (FUN_142b890d0) reads. The test runs the script on the executable. |
| `VTableLayout.ini` | The same fork (`assets/UE4SS_Signatures/VTableLayout.ini`). It first appears in Chrisr0/RE-UE4SS at e6e59de9. Three AActor lines moved, header added. | MIT, notice in NOTICE | The fork has OnRep_Owner 4 slots early. It puts two unknown slots after NotifyHit, where build 26123051 has them next to IsReplicationPausedForConnection, so BeginPlay and EndPlay came out 2 slots early. 42 offsets were read in Ghidra: AActor's exec thunks and the slots of the vtable 0x1459535f0, AGameModeBase's exec thunks, ProcessEvent, UStruct::Link and UGameEngine::Tick. The test compares each with the offset UE4SS computes from the file. |
