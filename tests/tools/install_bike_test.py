#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""tools/install.py's --bike on a fake game folder: a bike folder missing a file is refused; no CPS, refused; the dry
run changes nothing; the install puts mod/EveHoverbike, the four paks (each in its own ~mods folder) and the CPS
plugin in place, writes the starting tuning.txt and CPS settings only where none is, sets bike=off and bike_key=none in
coop-settings.txt (a new file holds just them) and UE4SS's queue on ProcessEvent, backing up every file it replaces;
a second install keeps the player's tuning.txt and settings.json."""
import importlib.util
import tempfile
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
spec = importlib.util.spec_from_file_location('install', ROOT / 'tools/install.py')
I = importlib.util.module_from_spec(spec)
spec.loader.exec_module(I)
I.running_game = lambda: False


def run(f, *args):
    out = StringIO()
    try:
        with redirect_stdout(out): f(*args)
    except SystemExit as e:
        return out.getvalue(), str(e)
    return out.getvalue(), None


with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    I.BACKUPS = tmp / 'backups'
    kit, game = tmp / 'kit', tmp / 'game'
    for n in I.BIKE_PAKS:
        for ext in ('pak', 'ucas', 'utoc'):
            (kit / n).mkdir(parents=True, exist_ok=True)
            (kit / n / f'{n}.{ext}').write_bytes(f'{n}.{ext}'.encode())
    _, why = run(I.bike_sources, kit)
    assert why and I.BIKE_CPS in why, why
    (kit / I.BIKE_CPS).write_bytes(b'cps')
    sources = I.bike_sources(kit)
    assert len(sources) == 3 * len(I.BIKE_PAKS) + 1
    win = game / 'SB/Binaries/Win64'
    (win / 'ue4ss/Mods/StellarCoop').mkdir(parents=True)
    _, why = run(I.install_bike, kit, sources, game, False)
    assert why and 'No CPS' in why, why
    (win / 'CPS').mkdir(parents=True)
    (win / 'CPS/CPS.dll').write_bytes(b'dll')
    ini = win / 'ue4ss/UE4SS-settings.ini'
    ini.write_bytes(b'[General]\r\nDefaultExecuteInGameThreadMethod = EngineTick\r\nHookBeginPlay = 0\r\n')
    # The dry run: nothing written.
    out, why = run(I.install_bike, kit, sources, game, True)
    assert why is None and 'Dry run' in out and not (win / 'ue4ss/Mods/EveHoverbike').exists(), out
    assert b'EngineTick' in ini.read_bytes() and not (win / 'ue4ss/Mods/StellarCoop/coop-settings.txt').exists()
    # The install.
    out, why = run(I.install_bike, kit, sources, game, False)
    assert why is None, why
    ehb = win / 'ue4ss/Mods/EveHoverbike'
    for rel in ('enabled.txt', 'Scripts/main.lua', 'Scripts/logic.lua', 'Scripts/tuning.txt'):
        assert (ehb / rel).read_bytes() == (ROOT / 'mod/EveHoverbike' / rel).read_bytes(), rel
    assert not (ehb / 'cps-settings.json').exists(), 'the CPS settings go to CPS, not to the mod'
    for n in I.BIKE_PAKS:
        assert (game / f'SB/Content/Paks/~mods/{n}/{n}.ucas').read_bytes() == f'{n}.ucas'.encode()
    assert (win / 'CPS/Plugins/eve_hoverbike.cps').read_bytes() == b'cps'
    config = win / 'CPS/Configs/EveHoverbike/settings.json'
    assert config.read_bytes() == (ROOT / 'mod/EveHoverbike/cps-settings.json').read_bytes()
    assert (win / 'ue4ss/Mods/StellarCoop/coop-settings.txt').read_bytes() == b'bike=off\nbike_key=none\n'
    assert ini.read_bytes() == b'[General]\r\nDefaultExecuteInGameThreadMethod = ProcessEvent\r\nHookBeginPlay = 0\r\n'
    assert list(I.BACKUPS.rglob('UE4SS-settings.ini')), 'the ini backed up first'
    # A second install: the player's own tuning and CPS settings kept, other files replaced with a backup.
    (ehb / 'Scripts/tuning.txt').write_text('Pose=3\n')
    config.write_text('{"mine": true}')
    coop = win / 'ue4ss/Mods/StellarCoop/coop-settings.txt'
    coop.write_bytes(b'# mine\nbike=on\nbike_key=F3\nmenu_key=F5\n')
    (ehb / 'Scripts/main.lua').write_text('old')
    out, why = run(I.install_bike, kit, sources, game, False)
    assert why is None, why
    assert (ehb / 'Scripts/tuning.txt').read_text() == 'Pose=3\n' and config.read_text() == '{"mine": true}'
    assert (ehb / 'Scripts/main.lua').read_bytes() == (ROOT / 'mod/EveHoverbike/Scripts/main.lua').read_bytes()
    assert any(p.read_text() == 'old' for p in I.BACKUPS.rglob('main.lua')), 'the replaced main.lua backed up'
    assert coop.read_bytes() == b'# mine\nbike=off\nbike_key=none\nmenu_key=F5\n', coop.read_bytes()
    assert 'already holds' in out, out
    # An ini without the key: told, never guessed into a section.
    ini.write_bytes(b'[General]\nHookBeginPlay = 0\n')
    out, _ = run(I.write_keys, ini, [I.BIKE_UE4SS], ' = ', False, False)
    assert 'by hand' in out and ini.read_bytes() == b'[General]\nHookBeginPlay = 0\n', out
print('install_bike_test ok')
