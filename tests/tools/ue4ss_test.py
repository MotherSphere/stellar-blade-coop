#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""ue4ss/builds/: one folder of UE4SS files per Stellar Blade build, named <TimeDateStamp>-<SizeOfImage> of the game's
executable in lower-case hex. The set of the pinned build (26123051): its README names every file; its two signature
scripts run under lua5.4 on made-up matches and on Ghidra's copy of the executable when this PC has it. No
FText_Constructor.lua anywhere under ue4ss/. ue4ss/UE4SS-settings.ini has every key of UE4SS v4.0.0's file, with
HookBeginPlay off and bUseUObjectArrayCache false. NOTICE credits the sources.
Run: python3 tests/tools/ue4ss_test.py"""
import hashlib
import io
import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/port'))
import make_signatures as ms  # noqa: E402

UE4SS = ROOT / 'ue4ss'
STAMP, SIZE = ms.pinned()
SET = UE4SS / 'builds' / f'{STAMP:08x}-{SIZE:08x}'
SIGS = SET / 'UE4SS_Signatures'
EXE = Path.home() / 'Ghidra/stellar-blade/input/26123051/SB-Win64-Shipping.exe'

# Every build folder is named after the executable it serves.
builds = sorted(p.name for p in (UE4SS / 'builds').iterdir())
assert all(re.fullmatch(r'[0-9a-f]{8}-[0-9a-f]{8}', b) for b in builds), builds
assert SET.is_dir(), f'no set for the pinned build: {SET}'

# UE4SS v4.0.0 reads UE4SS_Signatures/<name>.lua only (Signatures.cpp): the fork's GUObjectArracy.lua would never
# load. FText_Constructor.lua stops some games from starting and v4.0.0 does not read it.
every = sorted(p.relative_to(UE4SS).as_posix() for p in UE4SS.rglob('*') if p.is_file())
assert not [f for f in every if f.endswith(('FText_Constructor.lua', 'GUObjectArracy.lua'))], every
assert sorted(p.name for p in SIGS.iterdir()) == ['GNatives.lua', 'GUObjectArray.lua'], list(SIGS.iterdir())

# The README has a line for each file of the set.
readme = (SET / 'README.md').read_text(encoding='utf-8')
for f in sorted(p.relative_to(SET).as_posix() for p in SET.rglob('*') if p.is_file() and p.name != 'README.md'):
    assert f'`{f}`' in readme, f'README.md has no line for {f}'

# Runs a signature script as UE4SS does: Register() gives the pattern, OnMatchFound(match) the address. Each match
# comes with the bytes from it on, which DerefToInt32 reads.
DRIVER = r'''
local window = {}
function DerefToInt32(address)
  local i = address - window.base + 1
  local b = window.bytes
  local v = b[i] | b[i + 1] << 8 | b[i + 2] << 16 | b[i + 3] << 24
  return v >= 0x80000000 and v - 0x100000000 or v
end
dofile(arg[1])
print(Register())
for k = 2, #arg, 2 do
  window.base, window.bytes = tonumber(arg[k], 16), {}
  for h in arg[k + 1]:gmatch('%x%x') do window.bytes[#window.bytes + 1] = tonumber(h, 16) end
  print(string.format('%x', OnMatchFound(window.base)))
end
'''


def run(script, matches):
    """The script's pattern and its OnMatchFound result for each (address, bytes from it on)."""
    args = [x for va, blob in matches for x in (f'{va:x}', blob.hex())]
    out = subprocess.run(['lua5.4', '-', str(script), *args], input=DRIVER, capture_output=True, text=True,
                         timeout=60)
    assert out.returncode == 0, out.stderr
    lines = out.stdout.splitlines()
    return lines[0], [int(x, 16) for x in lines[1:]]


def regex(pattern):
    """UE4SS's pattern syntax: hex bytes, ? or ?? for any byte."""
    return re.compile(b''.join(b'.' if t in ('?', '??') else re.escape(bytes([int(t, 16)])) for t in pattern.split()),
                      re.DOTALL)


def fill(pattern, disp_at, disp):
    """The pattern's bytes, wildcards 00, with a little-endian int32 at disp_at."""
    b = bytearray(0 if t in ('?', '??') else int(t, 16) for t in pattern.split())
    b[disp_at:disp_at + 4] = disp.to_bytes(4, 'little', signed=True)
    return bytes(b)


GNATIVES, GUOBJECTARRAY = SIGS / 'GNatives.lua', SIGS / 'GUObjectArray.lua'
for script in (GNATIVES, GUOBJECTARRAY):
    head = script.read_text(encoding='utf-8')
    assert 'MIT' in head and 'function Register()' in head and 'function OnMatchFound(' in head, script

# Made-up matches. GNatives: lea rax, [rip + disp32] (48 8D 05), the target is the next instruction + disp32.
# GUObjectArray: mov [rip + disp32], eax (89 05), the same rule.
pattern, _ = run(GNATIVES, [])
base = 0x140001000
_, got = run(GNATIVES, [(base, fill(pattern, 3, 0x100)), (base, fill(pattern, 3, -0x20))])
assert got == [base + 7 + 0x100, base + 7 - 0x20], [hex(g) for g in got]
pattern, _ = run(GUOBJECTARRAY, [])
_, got = run(GUOBJECTARRAY, [(base, fill(pattern, 2, 0x4250d57)), (base, fill(pattern, 2, -0x40))])
assert got == [base + 6 + 0x4250d57, base + 6 - 0x40], [hex(g) for g in got]

# Build 26123051 itself (Ghidra, 2026-11-21): GUObjectArray's pattern matches once (0x142b8c4e3) and gives
# 0x146ddd240. GNatives' pattern matches 83 times; every match gives 0x146f17900. Both are UE4SS.log's values.
if EXE.is_file():
    image = ms.Image(EXE.read_bytes())
    assert (image.stamp, image.size) == (STAMP, SIZE), f'{EXE} is not the executable of the pinned build'
    found = {}
    for script in (GNATIVES, GUOBJECTARRAY):
        pattern, _ = run(script, [])
        hits = [start + m.start() for _, start, blob, _ in image.sections for m in regex(pattern).finditer(blob)]
        _, got = run(script, [(va, image.at(va, 16)) for va in hits])
        found[script.name] = (hits, got)
    hits, got = found['GUObjectArray.lua']
    assert hits == [0x142b8c4e3] and got == [0x146ddd240], ([hex(h) for h in hits], [hex(g) for g in got])
    hits, got = found['GNatives.lua']
    assert len(hits) == 83 and set(got) == {0x146f17900}, (len(hits), {hex(g) for g in got})
    real = 'build 26123051: GUObjectArray 1 match, GNatives 83 matches'
else:
    real = f'build 26123051 skipped: no {EXE}'



def ordered_lists(path):
    """Each section's lines in order, without comments: what UE4SS's get_ordered_list returns."""
    sections, current = {}, None
    for line in path.read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if not line or line.startswith(';'):
            continue
        if line.startswith('['):
            current = sections.setdefault(line[1:-1], [])
        else:
            current.append(line)
    return sections


# The classes before each section in its vtable, as UE4SSProgram.cpp (v4.0.0) adds them up for engine 4.26.
BASES = {'UObject': ['UObjectBase', 'UObjectBaseUtility'], 'UField': ['UObjectBase', 'UObjectBaseUtility', 'UObject'],
         'UStruct': ['UObjectBase', 'UObjectBaseUtility', 'UObject', 'UField'],
         'UEngine': ['UObjectBase', 'UObjectBaseUtility', 'UObject'],
         'AActor': ['UObjectBase', 'UObjectBaseUtility', 'UObject'],
         'AGameModeBase': ['UObjectBase', 'UObjectBaseUtility', 'UObject', 'AActor']}


def vtable_offset(sections, section, name):
    """The offset UE4SS gives a virtual: (index + the sizes of the sections before it) * 8, where a section's size
    is its line count less one (its first line is the destructor). Index 0 gives 0. A repeated name keeps its first
    index (UE4SS emplaces)."""
    index = sections[section].index(name)
    return 0 if index == 0 else (index + sum(len(sections[b]) - 1 for b in BASES[section])) * 8


# Offsets read in Ghidra on build 26123051 (2026-11-21). "thunk" is the exec function of that UFunction in the
# natives table (AActor's at 0x1464ceee0, AGameModeBase's at 0x14655c210): it calls or jumps through this offset.
# "vtable" is a slot of the vtable 0x1459535f0 (an AActor class that FUN_1411413f0 constructs).
GHIDRA_VTABLE = {
    ('UObject', 'ProcessEvent'): 0x218,  # AActor::BeginPlay (0x143f6cc00) calls ReceiveBeginPlay through it
    ('UStruct', 'Link'): 0x280,  # 0x1429d82d0 at +0x280 of the vtable 0x145fa5e98
    ('UEngine', 'Tick'): 0x2a8,  # UGameEngine::Tick 0x1441e28d0 at +0x2a8 of the vtable 0x1464184d0
    ('AActor', 'OnRep_ReplicateMovement'): 0x268,  # thunk 0x1437d4a20
    ('AActor', 'TearOff'): 0x270,  # thunk 0x1437d4a00
    ('AActor', 'OnRep_Owner'): 0x2b0,  # thunk 0x1446be680
    ('AActor', 'SetReplicateMovement'): 0x2b8,  # thunk 0x1446be4c0
    ('AActor', 'OnRep_AttachmentReplication'): 0x2c0,  # thunk 0x1446be460
    ('AActor', 'IsReplicationPausedForConnection'): 0x2d0,  # vtable: xor al, al; ret (returns false)
    ('AActor', 'ReplicateSubobjects'): 0x2e8,  # vtable: 0x143f76610 calls each component's ReplicateSubobjects
    ('AActor', 'OnSubobjectCreatedFromReplication'): 0x2f0,  # vtable: 0x143f76b70 registers the component
    ('AActor', 'OnSubobjectDestroyFromReplication'): 0x2f8,  # vtable: 0x143f76bc0 destroys the component
    ('AActor', 'PreReplication'): 0x300,  # vtable: 0x143f61e40 gathers movement, then ReplicatedMovement
    ('AActor', 'OnRep_Instigator'): 0x318,  # thunk 0x1446be440
    ('AActor', 'EnableInput'): 0x320,  # vtable: 0x143f6d150 makes the InputComponent, pushes it on the controller
    ('AActor', 'DisableInput'): 0x328,  # thunk 0x1446be280
    ('AActor', 'GetVelocity'): 0x330,  # thunk 0x1446bd2d0
    ('AActor', 'SetActorHiddenInGame'): 0x338,  # thunk 0x1446b9920
    ('AActor', 'K2_DestroyActor'): 0x340,  # thunk 0x1446b9770
    # vtable: four wrappers on PrimaryActorTick (+0x28) that jump to AddPrerequisite (0x144612460) or
    # RemovePrerequisite (0x1446124e0) with the other actor's tick (+0x28) or the component's (+0x30).
    ('AActor', 'AddTickPrerequisiteActor'): 0x348,  # 0x143f60b90
    ('AActor', 'AddTickPrerequisiteComponent'): 0x350,  # 0x143f60bb0
    ('AActor', 'RemoveTickPrerequisiteActor'): 0x358,  # 0x143f60bd0
    ('AActor', 'RemoveTickPrerequisiteComponent'): 0x360,  # 0x143f60bf0
    ('AActor', 'BeginPlay'): 0x368,  # vtable: 0x143f6cc00 calls ReceiveBeginPlay (FName 0x147000aa0)
    ('AActor', 'EndPlay'): 0x370,  # vtable: 0x143f66060 calls ReceiveEndPlay (FName 0x147000ab0)
    ('AActor', 'SetLifeSpan'): 0x3d0,  # thunk 0x1446b6ec0; BeginPlay calls it with InitialLifeSpan
    ('AActor', 'GetLifeSpan'): 0x3d8,  # thunk 0x1446b6e80
    ('AActor', 'GatherCurrentMovement'): 0x3e0,  # PreReplication calls it
    ('AActor', 'TickActor'): 0x450,  # vtable: 0x143f61ce0 calls Tick through +0x4a8
    ('AActor', 'OnRep_ReplicatedMovement'): 0x478,  # thunk 0x1446b6c70
    ('AActor', 'SetOwner'): 0x498,  # thunk 0x1446b6b90
    ('AActor', 'Tick'): 0x4a8,  # vtable: 0x143f61d60 calls ReceiveTick (FName 0x147000ad0)
    ('AActor', 'TeleportTo'): 0x548,  # K2_TeleportTo's thunk 0x1446b65a0
    ('AActor', 'ForceNetUpdate'): 0x640,  # thunk 0x1446b6190
    ('AActor', 'GetActorEyesViewPoint'): 0x650,  # thunk 0x1446b5e20
    ('AGameModeBase', 'GetNumPlayers'): 0x6f8,  # thunk 0x144756760
    ('AGameModeBase', 'GetNumSpectators'): 0x700,  # thunk 0x144756730
    ('AGameModeBase', 'StartPlay'): 0x708,  # thunk 0x144756710
    ('AGameModeBase', 'HasMatchStarted'): 0x710,  # thunk 0x144728f00
    ('AGameModeBase', 'HasMatchEnded'): 0x718,  # thunk 0x1447566e0
    ('AGameModeBase', 'ResetLevel'): 0x740,  # thunk 0x1447565d0
    ('AGameModeBase', 'ReturnToMainMenuHost'): 0x748,  # thunk 0x14276be50
}
vtables = ordered_lists(SET / 'VTableLayout.ini')
wrong = {f'{s}::{n}': f'{vtable_offset(vtables, s, n):#x}, Ghidra {o:#x}' for (s, n), o in GHIDRA_VTABLE.items()
         if vtable_offset(vtables, s, n) != o}
assert not wrong, wrong
# AActor has 132 lines: AGameModeBase's offsets above count its 131 slots.
assert len(vtables['AActor']) == 132, len(vtables['AActor'])
# The sections UE4SS v4.0.0 reads (UE4SSProgram.cpp), less UClass, which neither the fork nor the 1.3 file has.
need = {'UObjectBase', 'UObjectBaseUtility', 'UObject', 'UField', 'UEngine', 'UScriptStruct::ICppStructOps', 'FField',
        'FProperty', 'FNumericProperty', 'FMulticastDelegateProperty', 'FObjectPropertyBase', 'UStruct',
        'UGameViewportClient', 'FOutputDevice', 'FMalloc', 'AActor', 'AGameModeBase', 'AGameMode', 'UPlayer',
        'ULocalPlayer', 'UDataTable'}
assert need <= set(vtables), need - set(vtables)

# MemberVariableLayout.ini holds only FUObjectArray, the one struct where build 26123051 differs from UE 4.26's
# layout that UE4SS v4.0.0 has built in (listeners at 0xE0 and 0xF0, MasterSerialNumber at 0x128, size 0x130).
# v4.0.0 always adds a delete listener (UnrealInitializer.cpp:468). Read in Ghidra on 26123051, GUObjectArray at
# 0x146ddd240: AllocateUObjectIndex (FUN_142b890d0) reads the first five and calls the create listeners;
# AddUObjectDeleteListener (FUN_142b89390) appends at +0x78 under the lock at +0x88; FUObjectArray's constructor
# (FUN_140969fd0) sets +0xB0 to 1000; AllocateSerialNumber, inlined in FWeakObjectPtr's assignment (FUN_142ba93c0)
# and in FUN_1427f9330, increments it.
FUOBJECTARRAY = {'ObjFirstGCIndex': 0x0, 'ObjLastNonGCIndex': 0x4, 'MaxObjectsNotConsideredByGC': 0x8,
                 'OpenForDisregardForGC': 0xC, 'ObjObjects': 0x10, 'UObjectCreateListeners': 0x68,
                 'UObjectDeleteListeners': 0x78, 'MasterSerialNumber': 0xB0, 'UEP_TotalSize': 0xB8}
layout, section, comment = {}, None, ''
for line in (SET / 'MemberVariableLayout.ini').read_text(encoding='utf-8').splitlines():
    line = line.strip()
    if line.startswith(';'):
        comment += line
    elif line.startswith('['):
        section, comment = layout.setdefault(line[1:-1], {}), ''
    elif line:
        key, value = (x.strip() for x in line.split('='))
        # Each value has comment lines right above it with the address it was read at.
        assert re.search(r'0x14[0-9a-f]{7}', comment), f'no address above {key}'
        section[key], comment = int(value, 16), ''
assert layout == {'FUObjectArray': FUOBJECTARRAY}, layout

# UE4SS-settings.ini: the settings file of the UE4SS v4.0.0 release zip with SBO's values. OFFICIAL holds that file's
# keys and values, plus EnableDebugKeyBindings, which SettingsManager.cpp reads although the file lacks it.
OFFICIAL = {
    'Overrides': {'ModsFolderPath': '', 'ControllingModsTxt': ''},
    'General': {'EnableHotReloadSystem': '0', 'HotReloadKey': 'R', 'EnableAutoReloadingLuaMods': '0', 'UseCache': '1',
                'InvalidateCacheIfDLLDiffers': '1', 'EnableDebugKeyBindings': None,
                'SecondsToScanBeforeGivingUp': '120', 'bUseUObjectArrayCache': 'false',
                'bForceGUObjectArrayForIteration': 'false', 'DoEarlyScan': '0', 'bEnableSeachByMemoryAddress': 'false',
                'DefaultExecuteInGameThreadMethod': 'EngineTick', 'DefaultFNameToStringMethod': 'Scan'},
    'EngineVersionOverride': {'MajorVersion': '', 'MinorVersion': '', 'DebugBuild': '', 'Stats': '',
                              'PointerHash': 'Auto'},
    'ObjectDumper': {'LoadAllAssetsBeforeDumpingObjects': '0', 'UseModuleOffsets': '0'},
    'CXXHeaderGenerator': {'DumpOffsetsAndSizes': '1', 'KeepMemoryLayout': '0',
                           'LoadAllAssetsBeforeGeneratingCXXHeaders': '0'},
    'UHTHeaderGenerator': {'IgnoreAllCoreEngineModules': '0', 'IgnoreEngineAndCoreUObject': '0',
                           'MakeAllFunctionsBlueprintCallable': '1', 'MakeAllPropertyBlueprintsReadWrite': '1',
                           'MakeEnumClassesBlueprintType': '1', 'MakeAllConfigsEngineConfig': '1'},
    'SDKGenerator': {'OutputPath': ''},
    'Debug': {'ConsoleEnabled': '0', 'GuiConsoleEnabled': '0', 'GuiConsoleVisible': '0', 'GuiConsoleFontScaling': '1',
              'GuiConsoleMonospaceTextEditors': '0', 'GraphicsAPI': 'opengl', 'RenderMode': 'ExternalThread',
              'ToggleGuiKey': 'O'},
    'Threads': {'SigScannerNumThreads': '8', 'SigScannerMultithreadingModuleSizeThreshold': '16777216'},
    'Memory': {'MaxMemoryUsageDuringAssetLoading': '80'},
    'Hooks': {'HookProcessInternal': '1', 'HookProcessLocalScriptFunction': '1', 'HookInitGameState': '1',
              'HookLoadMap': '1', 'HookCallFunctionByNameWithArguments': '1', 'HookBeginPlay': '1', 'HookEndPlay': '1',
              'HookLocalPlayerExec': '1', 'HookAActorTick': '1', 'HookEngineTick': '1',
              'EngineTickResolveMethod': 'Scan', 'HookGameViewportClientTick': '1', 'HookUObjectProcessEvent': '1',
              'HookProcessConsoleExec': '1', 'HookUStructLink': '1', 'FExecVTableOffsetInLocalPlayer': '0x28'},
    'CrashDump': {'EnableDumping': '1', 'FullMemoryDump': '0'},
    'ExperimentalFeatures': {},
}
# SBO's values. Each has a line starting '; SBO:' right above it that says why. The game facts among them name the
# address they were read at in Ghidra on build 26123051.
SBO = {('General', 'bUseUObjectArrayCache'): 'false', ('Hooks', 'HookBeginPlay'): '0',
       ('General', 'EnableHotReloadSystem'): '1', ('General', 'EnableDebugKeyBindings'): '0',
       ('EngineVersionOverride', 'MajorVersion'): '4', ('EngineVersionOverride', 'MinorVersion'): '26',
       ('EngineVersionOverride', 'DebugBuild'): 'false', ('EngineVersionOverride', 'Stats'): 'false',
       ('Debug', 'ConsoleEnabled'): '0', ('Debug', 'GuiConsoleEnabled'): '0', ('Debug', 'GuiConsoleVisible'): '0',
       ('Hooks', 'FExecVTableOffsetInLocalPlayer'): '0x28'}
FACTS = {('EngineVersionOverride', 'MajorVersion'), ('EngineVersionOverride', 'Stats'),
         ('Hooks', 'FExecVTableOffsetInLocalPlayer')}


def settings(text):
    """{section: {key: (value, the comment lines right above it)}}, read as UE4SS's IniParser does: ';' opens a
    comment only at the start of a line, a value runs to the end of its line."""
    sections, section, above = {}, None, []
    for line in text.splitlines():
        line = line.strip()
        if line.startswith(';'):
            above.append(line)
            continue
        if line.startswith('['):
            section = sections.setdefault(line[1:-1], {})
        elif line:
            key, eq, value = line.partition('=')
            assert eq and section is not None, f'not a key = value line: {line}'
            section[key.strip()] = (value.strip(), above)
        above = []
    return sections


SETTINGS = UE4SS / 'UE4SS-settings.ini'
text = SETTINGS.read_text(encoding='utf-8')
# UE4SS reads a comment line up to its line end: a comment on the last line without one would never end.
assert text.endswith('\n'), f'{SETTINGS} lacks a line end at its end'
got = settings(text)
want = {s: {k: SBO.get((s, k), v) for k, v in keys.items()} for s, keys in OFFICIAL.items()}
assert {s: {k: v for k, (v, _) in keys.items()} for s, keys in got.items()} == want, \
    {f'{s}.{k}': (got.get(s, {}).get(k, ('missing',))[0], v) for s, keys in want.items() for k, v in keys.items()
     if got.get(s, {}).get(k, (None,))[0] != v}
for (s, k) in SBO:
    why = [c for c in got[s][k][1] if c.startswith('; SBO:')]
    assert why, f'{s}.{k} has no "; SBO:" line above it'
    assert (s, k) not in FACTS or re.search(r'0x14[0-9a-f]{7}', ' '.join(why)), f'{s}.{k}: no Ghidra address'
assert not [k for keys in got.values() for k, (v, _) in keys.items() if ';' in v or '#' in v], 'a comment after a value'
# NOTICE sends readers to the header for what was changed: it names each value that differs from the release file.
header = text.split('\n[', 1)[0]
assert not [k for (s, k), v in SBO.items() if OFFICIAL[s][k] not in (v, None) and k not in header], header
# SBO's own check at each load (core/ue4ss_settings.lua) finds no key that makes Stellar Blade unstable.
CHECK = "local S=dofile(arg[1]); local f=assert(io.open(arg[2],'rb')); print(#S.check(f:read('a')))"
out = subprocess.run(['lua5.4', '-', str(ROOT / 'mod/StellarCoop/Scripts/core/ue4ss_settings.lua'), str(SETTINGS)],
                     input=CHECK, capture_output=True, text=True, timeout=60)
assert out.returncode == 0 and out.stdout.strip() == '0', (out.stdout, out.stderr)
# The pinned release zip, when this PC has it: OFFICIAL is its file.
ZIP = Path.home() / '.cache/sbo-ue4ss/official-v4.0.0/UE4SS_v4.0.0.zip'
if ZIP.is_file():
    blob = ZIP.read_bytes()
    assert hashlib.sha256(blob).hexdigest() == '251ad0d1381a241750e036f5918cbf2b5d7ec58ebc608cb2dd09d459d0c81e45', ZIP
    shipped = settings(zipfile.ZipFile(io.BytesIO(blob)).read('ue4ss/UE4SS-settings.ini').decode('utf-8'))
    assert {s: {k: v for k, (v, _) in keys.items()} for s, keys in shipped.items()} == \
        {s: {k: v for k, v in keys.items() if v is not None} for s, keys in OFFICIAL.items()}, shipped
    zipped = 'settings checked against the v4.0.0 zip'
else:
    zipped = f'v4.0.0 zip skipped: no {ZIP}'

# NOTICE credits where the files come from and keeps the MIT notice.
notice = (ROOT / 'NOTICE').read_text(encoding='utf-8')
for word in ('https://github.com/Rev-OG-UwU/SB-UE4SS', 'a63c3f8ecfc51c679082c30805d8af5c3514ba9a',
             'https://github.com/Chrisr0/RE-UE4SS', 'e6e59de93656ed3caf242233a0b6f63e073ba3df',
             'https://github.com/UE4SS-RE/RE-UE4SS', 'ue4ss/UE4SS-settings.ini',
             'Copyright (c) 2022 Narknon', 'Permission is hereby granted, free of charge', 'backup_saves()',
             'FText_Constructor.lua'):
    assert word in notice, f'NOTICE lacks {word}'

print(f'ue4ss_test: ok ({len(builds)} build set; {real}; {zipped})')
