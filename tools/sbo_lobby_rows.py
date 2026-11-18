#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""Writes two files from data/sbo-lobby.json: mod/StellarCoop/Scripts/online/lobby/sbo_maps.lua, the five hall lobby
maps online/lobby/sbo.lua sends SBO match players to, with their world and zone rows' names and IDs, the 8 arrival
spots, the seats with their ZoneEnvSpawnTable rows' names and IDs, the terminal, the menu camera and the fence; and
native/src/online/lobby/halls_rows.h,
the native part's halls batch (rows/rows.h): the five world rows, the five zone rows, then
one ZoneEnvSpawnTable row per kept seat (online/lobby/halls_rows.lua reads them back).

  python3 -I tools/sbo_lobby_rows.py          write both files
  python3 -I tools/sbo_lobby_rows.py --check  exit 1 when either file differs from what the data gives

The world row, zone row and spawn point names come from each map's name: SBO_<Name>, Zone_SBO_<Name>, SBO_<Name>,
and the cooked persistent level from it too: /Game/SBO_Lobby/Lobby_<Name>. A seat's row is SBO_<Name>_Seat<nnn>
(never ending in _<digits>, so its FName number is 0 however it is made), ID 39m0032nnn (m the map's place, 1 to 5).
"""
import itertools
import json
import math
import re
import sys
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'data/sbo-lobby.json'
LUA = ROOT / 'mod/StellarCoop/Scripts/online/lobby/sbo_maps.lua'
HEADER = ROOT / 'native/src/online/lobby/halls_rows.h'

# The license header both written files start with, after the comment mark.
LICENSE_HEADER = ('Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors',
                  'SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later',
                  'SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a '
                  'permission.')

ORDER = ['hotel', 'station', 'cloister', 'terrace', 'foyer']  # World IDs 7121-7125, zone IDs 1000121-1000125.
KINDS = ['outdoor', 'table', 'bar', 'camp']  # SB's four sit loops.
SPOT_GAP = 150  # cm between two spots, so two arriving players never land on each other.
FENCE_MARGIN = 40  # cm between a standing point and the fence circle.
STAND = 100  # cm over the ground: a spot's and an approach point's Z, so EVE drops onto the floor.
HEADROOM = 200  # cm between a standing point's ground and the fence's zmax: STAND, and 100 to spare.
# The ZoneEnvSpawnTable row a seat's row copies, by sit loop: Xion's chairs, whose InteractionGraph (LD_Env_Chair_05,
# _03, _04) and alias Env_Camp_Chair come with the copy. Camp seats get no row: their seat top is 35.5 cm over the
# floor, the outdoor sit loop's 50.8.
DONORS = {'outdoor': 'Xion_10_EnvS_035', 'bar': 'Xion_10_EnvS_021', 'table': 'Xion_10_EnvS_025'}


def names(m):
    n = m['name']
    return {'world': f'SBO_{n}', 'zone': f'Zone_SBO_{n}', 'point': f'SBO_{n}', 'umap': f'/Game/SBO_Lobby/Lobby_{n}'}


def ground(spot):
    """The marker or the Pawn floor the editor measured under it, the higher one."""
    return max(spot['Z'], spot['floor'])


def seat_rows(data):
    """The kept seats with a ZoneEnvSpawnTable row, maps in order: (map, seat, row name, row ID)."""
    return [(m, s, f'SBO_{m["name"]}_Seat{s["n"]:03d}', 3900032000 + 10000000 * (i + 1) + s['n'])
            for i, m in enumerate(data['maps']) for s in m['seats'] if not s.get('skip') and s['kind'] in DONORS]


def seat_floor(data, seat):
    """The seat top minus the seat height of its sit loop."""
    return seat['Z'] - data['seat_cm'][seat['kind']]


def check(data):
    """The errors in the data, empty when the module can be written."""
    errors = []
    if sorted(data['seat_cm']) != sorted(KINDS):
        errors.append(f'seat_cm: {sorted(data["seat_cm"])}, want the sit loops {KINDS}')
    keys = [m['key'] for m in data['maps']]
    if keys != ORDER:
        errors.append(f'maps: {keys}, want {ORDER}')
    for i, m in enumerate(data['maps']):
        k = m['key']
        if not re.fullmatch(r'[A-Z][a-z]+', m['name']) or m['name'].lower() != k:
            errors.append(f'{k}: name {m["name"]!r} must be letters only, the key capitalised')
        for field, name in names(m).items():
            # The warp sends FName number 0: a name ending in _<digits> would be read as another name.
            if re.search(r'_\d+$', name):
                errors.append(f'{k}: {field} {name} ends in _<digits>, the warp would not find it')
        if (m['world_id'], m['zone_id']) != (7121 + i, 1000121 + i):
            errors.append(f'{k}: IDs {m["world_id"]}, {m["zone_id"]}, want {7121 + i}, {1000121 + i}')
        spots = m['spots']
        if [s['n'] for s in spots] != list(range(1, 9)):
            errors.append(f'{k}: spots {[s["n"] for s in spots]}, want 8 spots numbered 1 to 8')
        for a, b in itertools.combinations(spots, 2):
            gap = math.hypot(a['X'] - b['X'], a['Y'] - b['Y'])
            if gap < SPOT_GAP:
                errors.append(f'{k}: spots {a["n"]} and {b["n"]} {gap:.0f} cm apart, closer than {SPOT_GAP}')
        if [s['n'] for s in m['seats']] != list(range(1, len(m['seats']) + 1)):
            errors.append(f'{k}: seats not numbered 1 to {len(m["seats"])}')
        seats = [s for s in m['seats'] if not s.get('skip')]
        for s in seats:
            if s['kind'] not in KINDS:
                errors.append(f'{k}: seat {s["n"]} of kind {s["kind"]!r}: no sit loop, give it a skip reason')
            if 'approach' not in s:
                errors.append(f'{k}: seat {s["n"]} has no approach point to stand up at, give it a skip reason')
        # Every point EVE stands at must lie inside the fence, or the fence would send her back to a spot.
        f = m['fence']
        points = [(f'spot {s["n"]}', s['X'], s['Y'], ground(s)) for s in spots]
        points += [(f'seat {s["n"]}', s['X'], s['Y'], seat_floor(data, s)) for s in seats
                   if s['kind'] in data['seat_cm']]
        points += [(f'seat {s["n"]} approach', s['approach']['X'], s['approach']['Y'], s['approach']['floor'])
                   for s in seats if 'approach' in s]
        points.append(('terminal', m['terminal']['X'], m['terminal']['Y'], m['terminal']['Z']))
        for what, x, y, z in points:
            far = math.hypot(x - f['X'], y - f['Y'])
            if far + FENCE_MARGIN > f['R']:
                errors.append(f'{k}: {what} {far:.0f} cm from the fence centre, the fence R {f["R"]} needs '
                              f'{FENCE_MARGIN} more')
            if not (f['zmin'] < z and z + HEADROOM < f['zmax']):
                errors.append(f'{k}: {what} at Z {z:.2f}, outside the fence zmin {f["zmin"]}, zmax {f["zmax"]} '
                              f'(zmax must be more than {HEADROOM} over it)')
    rows = 2 * len(data['maps']) + len(seat_rows(data))
    if rows > 255:
        errors.append(f'halls batch: {rows} rows, more than 255 (rows/rows.h: a row index fits a byte)')
    return errors


def num(v):
    v = round(float(v), 2) + 0.0  # + 0.0 turns -0.0 into 0.0
    return str(int(v)) if v.is_integer() else repr(v)


def table(d):
    return '{' + ','.join(f'{k}={num(v)}' for k, v in d.items()) + '}'


def render_lua(data):
    out = [*(f'-- {line}' for line in LICENSE_HEADER),
           '-- Generated by tools/sbo_lobby_rows.py from data/sbo-lobby.json: do not edit by hand.',
           '-- The five hall lobby maps for online/lobby/sbo.lua, in the order of their IDs. Each map: its world row,',
           '-- zone row and spawn point names and IDs, the cooked persistent level (umap), the 8 arrival spots (Z: the',
           f'-- ground plus {STAND} cm), the seats (Z: the floor under the seat, the seat top minus its sit loop\'s',
           '-- seat height; approach: where EVE stands up, a point the editor traces found clear for her standing',
           f'-- capsule, its Z the Pawn floor under the seat marker plus {STAND} cm; row, id: its',
           '-- ZoneEnvSpawnTable row in online/lobby/halls_rows.h, none for a camp seat), the terminal, the menu '
           'camera and',
           '-- the fence (centre X, Y, radius R, Z range). Units: cm and degrees.',
           f"local M={{order={{{','.join(repr(k) for k in ORDER)}}},maps={{}}}}"]
    rows = seat_rows(data)
    for m in data['maps']:
        n = names(m)
        out.append(f"M.maps.{m['key']}={{name='{m['name']}',world='{n['world']}',zone='{n['zone']}',"
                   f"point='{n['point']}',world_id={m['world_id']},zone_id={m['zone_id']},")
        out.append(f"    umap='{n['umap']}',")
        out.append(f"    fence={table(m['fence'])},")
        out.append(f"    camera={table({k: m['camera'][k] for k in ('X', 'Y', 'Z', 'Pitch', 'Yaw', 'FOV')})},")
        out.append(f"    terminal={table({k: m['terminal'][k] for k in ('X', 'Y', 'Z', 'Yaw')})},")
        out.append('    spots={')
        for s in m['spots']:
            out.append(f"        {table({'X': s['X'], 'Y': s['Y'], 'Z': ground(s) + STAND, 'Yaw': s['Yaw']})},")
        out.append('    },')
        skipped = {}
        for s in m['seats']:
            if s.get('skip'):
                skipped.setdefault(s['skip'], []).append(str(s['n']))
        for why, ns in skipped.items():
            out.append(f"    -- Left out, seats {' '.join(ns)}: {why}.")
        out.append('    seats={')
        for s in m['seats']:
            if s.get('skip'):
                continue
            z = seat_floor(data, s)
            a = s['approach']
            at = {'X': a['X'], 'Y': a['Y'], 'Z': a['floor'] + STAND}
            row = ''.join(f",row='{name}',id={i}" for m2, s2, name, i in rows if m2 is m and s2 is s)
            out.append(f"        {{n={s['n']},kind='{s['kind']}',X={num(s['X'])},Y={num(s['Y'])},Z={num(z)},"
                       f"Yaw={num(s['Yaw'])}{row},approach={table(at)}}},")
        out.append('    }}')
    out.append('return M')
    return '\n'.join(out) + '\n'


# The header's head after the generated line, a paragraph a string ('' a blank comment line): what the rows hold.
HEAD = [
    ("The hall lobbies' batch (kHallsRecipe, which tools/sbo_lobby_rows.py writes; "
     'online/lobby/halls_rows.lua) holds one WorldTable row and one type-5 ZoneTable row for each SBO hall'
     " lobby map, so SB's warp reaches the cooked maps of the local lobby pak, then one ZoneEnvSpawnTable "
     "row for each kept seat of those maps, for the chair of SB's spawned there."),
    '',
    ('One world row and one zone row for each SBO hall lobby map of online/lobby/sbo_maps.lua (Hotel, '
     "Station, Cloister, Terrace, Foyer, in that order), so online/lobby/sbo.lua's warp (game/sbo.h: the "
     "zone row by name, its WorldAlias +0x14, that world row's UMapPath +0x18, type 5 at +0x25) reaches "
     'the maps of the local lobby pak zSBO_Lobby. The five worlds come first, so no zone names a world row'
     ' not in yet. Each world is a copy of CombatTestMapMk2 (1003: only UMapPath and FileSuffix exist, and'
     " FileSuffix is None in every shipped row) with the cooked persistent level's path; each zone a copy "
     'of Zone_Xion_Boss_Mann (1692, the zone the SBO lobby uses in Xion: type 5 BossChallenge, PS5_Default'
     ' graphics, no events) with WorldAlias naming its world row, ZoneType 5 kept as a guard, '
     "StartPointAlias the map's spawn point (named after its world row, as the cooked SBSpawnPoint is) and"
     " AdditiveDesignLevel emptied (the donor's E04_LD_Mann is Xion's). IDs World 7121-7125 and Zone "
     '1000121-1000125, above every shipped ID on build 26123051 (World max 7000, Zone max 999992). Then '
     'one ZoneEnvSpawnTable row for each kept seat but the camp ones (171), maps in the same order: '
     "SBO_<Map>_Seat<nnn>, the row the chair of SB's spawned at that seat binds to by its EnvActorName. "
     "Each is a copy of Xion's chair row of the seat's sit loop (Xion_10_EnvS_035 outdoor, _021 bar, _025 "
     'table: the InteractionGraph and the alias Env_Camp_Chair come with it, EnvBPPath stays empty, Zone '
     "None and the range fields 0) with ZoneList its hall's zone (+0x20), EnvActorName its own name "
     "(+0x30), InitStateTag FirstInteraction (+0x64: SB's graph runs the sit from there without the first "
     "use's camp-rest effect) and SaveType None (+0x6c: nothing goes into the save)."),
    ("IDs 39m0032nnn (m the map's place, nnn the seat), above ZoneEnvSpawnTable's highest on build "
     '26123051 (3305032001, 4430 rows). No name ends in _<digits>: the warp sends FName number 0, and Lua '
     "names the chair's row by its text. An update that takes an ID refuses the batch (Why::id) and the "
     'lobby stays in Xion. Struct sizes and offsets from the SDK (stellar-sdk-647527f): '
     'SBWorldTableProperty 0x30, SBZoneTableProperty 0x150, neither with a Transient field, '
     'SBZoneEnvSpawnTableProperty 0x508.'),
]


def render_header(data):
    out = [*(f'// {line}' for line in LICENSE_HEADER),
           '// Generated by tools/sbo_lobby_rows.py from data/sbo-lobby.json: do not edit by hand.',
           *('// ' + line if line else '//'
             for p in HEAD for line in textwrap.wrap(p, 117, break_on_hyphens=False) or ['']),
           '#pragma once', '', '#include "rows/rows.h"', '', 'namespace coop::lion {', '',
           'constexpr Patch kHallsPatches[] = {']
    for m in data['maps']:
        n = names(m)
        out.append(f'    {{0x18, Kind::string, 0, "{n["umap"]}.Lobby_{m["name"]}"}}, // UMapPath ({n["world"]})')
    for m in data['maps']:
        n = names(m)
        out += [f'    // {n["zone"]}',
                f'    {{0x14, Kind::name, 0, "{n["world"]}"}}, // WorldAlias',
                '    {0x25, Kind::u8, 5, nullptr}, // ZoneType Zone_BossChallenge, the donor\'s',
                f'    {{0x30, Kind::string, 0, "{n["point"]}"}}, // StartPointAlias',
                '    {0x138, Kind::names, 0, ""}, // AdditiveDesignLevel']
    rows = seat_rows(data)
    for m, s, name, _ in rows:
        out += [f'    // {name} ({s["kind"]} seat {s["n"]})',
                f'    {{0x20, Kind::names, 0, "{names(m)["zone"]}"}}, // ZoneList',
                f'    {{0x30, Kind::name, 0, "{name}"}}, // EnvActorName',
                '    {0x64, Kind::name, 0, "FirstInteraction"}, // InitStateTag',
                '    {0x6c, Kind::u8, 0, nullptr}, // SaveType None']
    out += ['};', 'constexpr Row kHallsRecipe[] = {']
    k = len(data['maps'])
    for i, m in enumerate(data['maps']):
        out.append(f'    {{Table::world, "{names(m)["world"]}", "CombatTestMapMk2", {m["world_id"]}u, {i}, 1}},')
    for i, m in enumerate(data['maps']):
        zone = names(m)['zone']
        out.append(f'    {{Table::zone, "{zone}", "Zone_Xion_Boss_Mann", {m["zone_id"]}u, {k + 4 * i}, 4}},')
    for j, (_, s, name, i) in enumerate(rows):
        out.append(f'    {{Table::env, "{name}", "{DONORS[s["kind"]]}", {i}u, {5 * k + 4 * j}, 4}},')
    out += ['};', 'constexpr size_t kHallsRows = sizeof kHallsRecipe / sizeof kHallsRecipe[0];',
            'static_assert(kHallsRows < 256, "a row index fits a byte");',
            'constexpr Batch kHalls{"halls", kHallsRecipe, kHallsRows, kHallsPatches};', '',
            '} // namespace coop::lion']
    return '\n'.join(out) + '\n'


def main(argv):
    data = json.loads(DATA.read_text())
    errors = check(data)
    if errors:
        sys.exit('data/sbo-lobby.json:\n' + '\n'.join(errors))
    want = {LUA: render_lua(data), HEADER: render_header(data)}
    if '--check' in argv:
        stale = [p.relative_to(ROOT).as_posix() for p, text in want.items() if not p.exists() or p.read_text() != text]
        if stale:
            sys.exit('Out of date, run python3 -I tools/sbo_lobby_rows.py: ' + ', '.join(stale))
        return
    for p, text in want.items():
        p.write_text(text)


if __name__ == '__main__':
    main(sys.argv[1:])
