#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""tools/compat/cns_coop_saves.py on a stand-in for CNS's main.lua written for this test: the local names the blocks
use, the same shape, SBO's own code. No line of CNS is needed. With lua5.4, the stand-in runs with the two blocks
in on temporary saves. On a PC with CNS v2.2 installed, a copy of its main.lua also goes through apply and remove.
Run: python3 tests/tools/cns_coop_saves_test.py"""
import contextlib
import io
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/compat'))
import cns_coop_saves as cns  # noqa: E402

install = cns.install
install.running_game = lambda: False  # The real check would fail this test while Stellar Blade runs.

# Shaped like CNS's main.lua where the blocks go. StandIn (set by DRIVER) gives the folders and records each read.
STAND_IN = b'''\
-- Stand-in for CNS's main.lua, for cns_coop_saves_test.py only.
local logged = {}
local function Log(message) logged[#logged + 1] = message end

local ResolvedSaveFilePath, CachedOutfitsFromSaveFile

local function remember(found)
    ResolvedSaveFilePath = found
    return found
end

local ResolveSaveFilePath = function()
    if ResolvedSaveFilePath ~= nil then return ResolvedSaveFilePath end
    local steamId = StandIn.steamId
    if steamId ~= nil then
        local savedDir = StandIn.savedDir
        if savedDir ~= nil then
            local path = table.concat({ savedDir .. "SaveGames", steamId, "StellarBladeSave00.sav" }, "/")
            local solo = io.open(path, "rb")
            if solo then
                solo:close()
                return remember(path)
            end -- anchor: fallback
        end
    end
    Log("stand-in: no save found")
end

local LoadOutfitKeysFromSaveFile = function()
    if CachedOutfitsFromSaveFile ~= nil then return CachedOutfitsFromSaveFile end
    local where = ResolveSaveFilePath()
    local found = {}
    local handle = where and io.open(where, "rb")
    if handle then
        StandIn.read[#StandIn.read + 1] = where
        for key in handle:read("a"):gmatch("UNLOCK:([%w_]+)") do found[key] = true end
        handle:close()
    else
        Log("stand-in: cannot read " .. tostring(where))
    end
    CachedOutfitsFromSaveFile = found
    return found
end -- anchor: union

local function DekCNS_ClearSaveFileOutfitCache() CachedOutfitsFromSaveFile = nil end

local function DekCNS_CheckOutfitUnlocked(key)
    return LoadOutfitKeysFromSaveFile()[key] == true
end

return {
    unlocked = DekCNS_CheckOutfitUnlocked,
    forget = DekCNS_ClearSaveFileOutfitCache,
    logged = logged,
    where = function() return ResolvedSaveFilePath end,
}
'''

# arg: main.lua, saved folder, Steam ID. The cache reset case adds a save to append BS_Late to between two reports.
DRIVER = '''\
StandIn = { savedDir = arg[2], steamId = arg[3], read = {} }
local cns = dofile(arg[1])
local function report()
    local keys = {}
    for _, key in ipairs({ "BS_Solo", "BS_Coop", "BS_Both", "BS_Late" }) do
        if cns.unlocked(key) then keys[#keys + 1] = key end
    end
    print("keys " .. table.concat(keys, " "))
end
report()
if arg[4] then
    local save = assert(io.open(arg[4], "ab"))
    save:write("UNLOCK:BS_Late\\n")
    save:close()
    report()
    cns.forget()
    report()
end
print("where " .. tostring(cns.where()))
print("read " .. table.concat(StandIn.read, " "))
print("log " .. table.concat(cns.logged, "|"))
'''


def anchors(data):
    """The line numbers of the stand-in's anchor comments: the lines the two blocks go after."""
    lines = data.decode().splitlines()
    return tuple(next(n for n, line in enumerate(lines, 1) if line.endswith(f'-- anchor: {name}'))
                 for name in ('fallback', 'union'))


def run(function, path, known):
    """(exit code, output) of function(path, known)."""
    out = io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
        try:
            function(path, known)
            code = 0
        except SystemExit as stop:
            code = stop.code
            if isinstance(code, str): print(code)
    return code, out.getvalue()


def backups():
    return sorted(install.BACKUPS.glob('*/DekCNS/main.lua')) if install.BACKUPS.exists() else []


POINTS = anchors(STAND_IN)
KNOWN = {cns.digest(STAND_IN): ('stand-in', POINTS)}
assert cns.digest(STAND_IN) not in cns.KNOWN and STAND_IN.count(b'\n') != 1083  # Not CNS's file.

with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    install.BACKUPS = tmp / 'backups'
    main = tmp / 'main.lua'
    main.write_bytes(STAND_IN)

    # 1. Check on the shipped file changes nothing.
    code, out = run(cns.check, main, KNOWN)
    assert code == 0 and 'as shipped' in out and 'not applied' in out, out
    assert main.read_bytes() == STAND_IN and not backups()

    # 2. Apply: both blocks in at their lines, nothing of the file removed, a backup of the shipped file first.
    code, out = run(cns.apply, main, KNOWN)
    assert code == 0 and 'Applied' in out, out
    patched = main.read_bytes()
    lines = patched.splitlines(keepends=True)
    fallback, union = POINTS
    assert b''.join(lines[fallback:fallback + cns.FALLBACK.count(b'\n')]) == cns.FALLBACK, lines[fallback]
    union += cns.FALLBACK.count(b'\n')
    assert b''.join(lines[union:union + cns.UNION.count(b'\n')]) == cns.UNION, lines[union]
    assert cns.strip(patched) == STAND_IN
    assert patched.count(cns.BEGIN) == patched.count(cns.END) == 2
    [copy] = backups()
    assert copy.read_bytes() == STAND_IN, copy
    code, out = run(cns.check, main, KNOWN)
    assert code == 0 and 'with the co-op saves change' in out, out

    # 3. Apply twice: the markers are found, nothing is written, no second backup.
    code, out = run(cns.apply, main, KNOWN)
    assert code == 0 and 'already applied' in out, out
    assert main.read_bytes() == patched and len(backups()) == 1

    # 4. Remove gives the shipped bytes back, after a backup of the changed file.
    code, out = run(cns.remove, main, KNOWN)
    assert code == 0 and 'as shipped again' in out, out
    assert main.read_bytes() == STAND_IN
    assert [b.read_bytes() for b in backups()] == [STAND_IN, patched]
    code, out = run(cns.remove, main, KNOWN)
    assert code == 0 and 'Nothing to remove' in out and main.read_bytes() == STAND_IN, out

    # 5. Blocks of another version of this tool: check says so, apply writes the current ones.
    main.write_bytes(patched.replace(b'twin (Save00 or Coop00)', b'other save'))
    code, out = run(cns.check, main, KNOWN)
    assert code == 0 and 'other co-op saves blocks' in out, out
    assert run(cns.apply, main, KNOWN)[0] == 0 and main.read_bytes() == patched

    # 6. A file of another hash is refused by each command and left alone, without a backup.
    for other in (STAND_IN.replace(b'stand-in: no save', b'stand-in: no file'), STAND_IN[:-1]):
        main.write_bytes(other)
        count = len(backups())
        for function in (cns.check, cns.apply, cns.remove):
            code, out = run(function, main, KNOWN)
            assert code != 0 and 'is not a CNS main.lua this tool knows' in out and 'Nothing was changed' in out, out
            assert cns.digest(other) in out, out
            assert main.read_bytes() == other and len(backups()) == count

    # 7. The game running: apply and remove refuse before any backup or write.
    main.write_bytes(STAND_IN)
    install.running_game = lambda: True
    count = len(backups())
    assert run(cns.apply, main, KNOWN) == (install.CLOSE_GAME, install.CLOSE_GAME + '\n')
    assert main.read_bytes() == STAND_IN and len(backups()) == count
    main.write_bytes(patched)
    assert run(cns.remove, main, KNOWN)[0] == install.CLOSE_GAME
    assert main.read_bytes() == patched and len(backups()) == count
    install.running_game = lambda: False

    # 8. A failed remove: a line of the stand-in changed after the apply, so the file without the blocks is not the
    # shipped one. Remove backs it up, then restores the newest shipped backup. It says so.
    edited = patched.replace(b'stand-in: cannot read', b'stand-in: cannot open')
    main.write_bytes(edited)
    count = len(backups())
    code, out = run(cns.remove, main, KNOWN)
    assert code != 0 and 'restored' in out and str(backups()[0]) in out, out
    assert main.read_bytes() == STAND_IN
    assert len(backups()) == count + 1 and backups()[-1].read_bytes() == edited
    # Without a shipped backup it refuses and changes nothing.
    install.BACKUPS = tmp / 'no-backups'
    main.write_bytes(edited)
    code, out = run(cns.remove, main, KNOWN)
    assert code != 0 and 'has no shipped copy' in out and main.read_bytes() == edited and not backups(), out
    install.BACKUPS = tmp / 'backups'

    # 9. main: the CNS path under --game, a missing file, the real table refusing the stand-in.
    game = tmp / 'game'
    (game / cns.CNS).parent.mkdir(parents=True)
    (game / cns.CNS).write_bytes(STAND_IN)
    for argv, code_out in ((['--game', tmp / 'nothing'], 'No CNS main.lua at'), (['--game', game], 'this tool knows')):
        try:
            cns.main([str(a) for a in argv])
            raise AssertionError(argv)
        except SystemExit as stop:
            assert code_out in str(stop.code), stop.code
    real_known, cns.KNOWN = cns.KNOWN, KNOWN
    with contextlib.redirect_stdout(io.StringIO()) as out:
        cns.main(['--game', str(game)])
        cns.main(['--game', str(game), '--check'])
        cns.main(['--game', str(game), '--remove'])
    assert 'Applied' in out.getvalue() and 'with the co-op saves change' in out.getvalue(), out.getvalue()
    assert (game / cns.CNS).read_bytes() == STAND_IN
    cns.KNOWN = real_known
    told = subprocess.run([sys.executable, '-I', ROOT / 'tools/compat/cns_coop_saves.py', '--help'],
                          capture_output=True, text=True)
    assert told.returncode == 0 and '--remove' in told.stdout, told.stderr

    # 10. The blocks in Lua: the stand-in with both blocks on temporary saves.
    lua = shutil.which('lua5.4')
    assert lua, 'lua5.4 is needed: the game embeds Lua 5.4 (pacman -S lua54)'
    main.write_bytes(patched)
    driver = tmp / 'driver.lua'
    driver.write_text(DRIVER)

    def play(name, solo=None, coop=None, late=None):
        """{'keys', 'where', 'read', 'log'} of the driver on a saved folder with these saves (lists of keys)."""
        saved = tmp / name
        folder = saved / 'SaveGames' / '7656'
        folder.mkdir(parents=True)
        for file, keys in (('StellarBladeSave00.sav', solo), ('StellarBladeCoop00.sav', coop)):
            if keys is not None:
                (folder / file).write_bytes(b''.join(b'\0junk UNLOCK:%s\0' % key.encode() for key in keys))
        args = [lua, driver, main, f'{saved}/', '7656'] + ([folder / late] if late else [])
        done = subprocess.run(args, capture_output=True, text=True, timeout=60)
        assert done.returncode == 0 and not done.stderr, done.stderr
        lines = done.stdout.splitlines()
        result = {line.split(' ', 1)[0]: line.split(' ', 1)[1] if ' ' in line else '' for line in lines[-3:]}
        result['keys'] = [line[5:] for line in lines[:-3]]
        return result, str(folder / 'StellarBladeSave00.sav'), str(folder / 'StellarBladeCoop00.sav')

    # Solo only: CNS's run on the solo save, no run on the missing twin, so no failed read in the log.
    got, solo, coop = play('solo', solo=['BS_Solo', 'BS_Both'])
    assert got == {'keys': ['BS_Solo BS_Both'], 'where': solo, 'read': solo, 'log': ''}, got
    # Co-op only: the fallback resolves the co-op copy.
    got, solo, coop = play('coop', coop=['BS_Coop'])
    assert got == {'keys': ['BS_Coop'], 'where': coop, 'read': coop, 'log': ''}, got
    # Both: one run on each, the union, the first path put back.
    got, solo, coop = play('both', solo=['BS_Solo', 'BS_Both'], coop=['BS_Coop', 'BS_Both'])
    assert got == {'keys': ['BS_Solo BS_Coop BS_Both'], 'where': solo, 'read': f'{solo} {coop}', 'log': ''}, got
    # Neither: CNS's own failure lines, once each.
    got, solo, coop = play('neither')
    assert got == {'keys': [''], 'where': 'nil', 'read': '',
                   'log': 'stand-in: no save found|stand-in: cannot read nil'}, got
    # The cache reset: a key added to the co-op copy shows only after the reset, read again from both saves.
    got, solo, coop = play('reset', solo=['BS_Solo'], coop=['BS_Coop'], late='StellarBladeCoop00.sav')
    assert got == {'keys': ['BS_Solo BS_Coop', 'BS_Solo BS_Coop', 'BS_Solo BS_Coop BS_Late'], 'where': solo,
                   'read': f'{solo} {coop} {solo} {coop}', 'log': ''}, got

    # 11. The installed CNS v2.2 on this PC, if any: a copy through apply, a Lua parse and remove. Read only.
    real = install.GAME / cns.CNS
    data = real.read_bytes() if real.is_file() else b''
    if cns.digest(data) in cns.KNOWN:
        copy = tmp / 'cns/main.lua'
        copy.parent.mkdir()
        copy.write_bytes(data)
        assert run(cns.apply, copy, cns.KNOWN)[0] == 0
        parsed = subprocess.run([lua, '-e', f'assert(loadfile([[{copy}]]))'], capture_output=True, text=True)
        assert parsed.returncode == 0, parsed.stderr
        assert run(cns.remove, copy, cns.KNOWN)[0] == 0 and copy.read_bytes() == data
    else:
        print(f'cns_coop_saves_test: the real CNS file not tested: no CNS v2.2 main.lua at {real}')

print('cns_coop_saves_test: OK')
