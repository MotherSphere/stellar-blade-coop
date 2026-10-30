#!/usr/bin/env python3
"""Writes Matrix XIII's rows from data/mxiii-world.json: native/src/lion/mxiii_rows.h (the batches' recipes and
patches for lion/rows.h) and mod/StellarCoop/Scripts/cut/mxiii_rows.lua (the same rows for cut/mxiii.lua's read-back,
the ladders and ledges cut/mxmove.lua spawns, the boss points cut/mxboss.lua watches).

  python3 tools/mxiii_rows.py          write both files
  python3 tools/mxiii_rows.py --check  exit 1 when either file differs from what the data gives

Each field a row sets must be in FIELDS: its offset in the row struct (SDK stellar-sdk-647527f), the patch kind of
lion/rows.h and the check kind of cut/enemy.lua's read-back.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'data/mxiii-world.json'
HEADER = ROOT / 'native/src/lion/mxiii_rows.h'
LUA = ROOT / 'mod/StellarCoop/Scripts/cut/mxiii_rows.lua'

# Table asset name: (lion/rows.h Table, {field: (offset, patch kind, read-back kind)}).
FIELDS = {
    'CharacterTable': ('character', {'DefaultEffectArray': (0x220, 'names', 'N')}),
    'ZoneCampTable': ('camp', {'CampType': (0x28, 'u8', 'e'), 'CoinSpawnPointName': (0x60, 'name', 'n'),
                               'CampDisplayType': (0x6c, 'u8', 'e')}),
    'ZoneEnvSpawnTable': ('env', {
        'ZoneList': (0x20, 'names', 'N'), 'EnvActorName': (0x30, 'name', 'n'), 'EnvBPPath': (0x38, 'string', 's'),
        'SpawnPointName': (0x48, 'name', 'n'), 'EnvAlias': (0x58, 'name', 'n'), 'InitActivate': (0x60, 'u8', 'e'),
        'InitStateTag': (0x64, 'name', 'n'), 'SaveType': (0x6c, 'u8', 'e'),
        **{f'TagEventList{i}': (0x78 + 0x18 * (i - 1), 'names', 'N') for i in range(1, 11)},
        'LinkEnvSpawnList': (0x260, 'names', 'N'), 'TargetCamp': (0x270, 'name', 'n')}),
    'ZoneTriggerTable': ('trigger', {'InitActivate': (0x1c, 'u8', 'e'), 'TouchEvents': (0x20, 'names', 'N')}),
    'EventSpawnTable': ('spawn', {
        'SpawnPointName': (0x14, 'name', 'n'), 'CharacterAlias': (0x20, 'names', 'N'), 'SpawnType': (0x30, 'u8', 'e'),
        'Zone': (0x34, 'name', 'n'), 'SaveType': (0x44, 'u8', 'e'), 'GoPathAfterSpawn': (0xb1, 'u8', 'b'),
        'PathWay': (0xb8, 'string', 's'), 'RewardGroup': (0xc8, 'name', 'n'), 'AIGroupAlias': (0xe0, 'name', 'n'),
        'AIGroupName': (0xe8, 'name', 'n')}),
    'EventItemTable': ('eitem', {'Zone': (0x20, 'name', 'n'), 'SpawnPointName': (0x2c, 'name', 'n')}),
    'ZoneEventTable': ('zevent', {'Type': (0x14, 'u8', 'e'), 'EventAlias': (0x18, 'name', 'n')}),
    'WorldTransitionTable': ('transition', {
        'EnvSpawnAlias': (0x30, 'name', 'n'), 'EventSpawnAliasArray': (0x38, 'names', 'N'),
        'FromWorldAlias': (0x48, 'name', 'n'), 'FromIsolatedAreaAlias': (0x50, 'name', 'n')}),
    'EventZoneWarpTable': ('warp', {'TargetWorld': (0x24, 'name', 'n'), 'TargetZoneCamp': (0x2c, 'name', 'n'),
                                    'TargetSpawnPoint': (0x34, 'name', 'n')}),
    'EffectVolumeTable': ('effvol', {'ActiveZoneAlias': (0x18, 'name', 'n'), 'EnterEffectAlias': (0x20, 'name', 'n')}),
}
SIZE = {'u8': 1, 'name': 8, 'string': 16, 'names': 16}
STRUCT = {'CharacterTable': 0x548, 'ZoneCampTable': 0xa8, 'ZoneEnvSpawnTable': 0x508, 'ZoneTriggerTable': 0xa8,
          'EventSpawnTable': 0x290, 'EventItemTable': 0x80, 'ZoneEventTable': 0x70, 'WorldTransitionTable': 0x88,
          'EventZoneWarpTable': 0x70, 'EffectVolumeTable': 0xc0}


def cname(word):
    return 'k' + word[0].upper() + word[1:]


def text_of(kind, value):
    """The value as lion/rows.h's patch text: names joined by '|'."""
    return '|'.join(value) if kind == 'names' else str(value)


def check(data):
    """Raises on data the native part would refuse or misread."""
    seen = set()
    for b in data['batches']:
        assert b['word'].isalpha() and b['word'].islower(), b['word']
        assert 0 < len(b['rows']) < 256, (b['word'], 'a row index fits a byte')
        for r in b['rows']:
            assert r['table'] in FIELDS, r['table']
            assert (r['table'], r['name']) not in seen, r['name']
            seen.add((r['table'], r['name']))
            assert 0 < r['id'] < 2 ** 32, r['name']
            fields = FIELDS[r['table']][1]
            spans = []
            for field, value, changed in r['set']:
                at, kind, _ = fields[field]
                assert at >= 0x14 and at + SIZE[kind] <= STRUCT[r['table']], (r['name'], field)
                assert all(at + SIZE[kind] <= a or b2 <= at for a, b2 in spans), (r['name'], field, 'overlaps')
                spans.append((at, at + SIZE[kind]))
                if kind == 'u8':
                    assert isinstance(value, (int, bool)) and 0 <= int(value) <= 255, (r['name'], field)
                elif kind == 'names':
                    assert isinstance(value, list) and all(v and '|' not in v and len(v) < 128 for v in value)
                else:
                    assert isinstance(value, str) and '"' not in value and '\\' not in value, (r['name'], field)
                assert isinstance(changed, bool)


def header(data):
    out = ['// Generated by tools/mxiii_rows.py from data/mxiii-world.json: do not edit by hand.',
           '// Matrix XIII\'s batches (coop mxiii, cut/mxiii.lua), included by lion/rows.h after its Table, Patch and',
           '// Row: each row a copy of its donor (a shipped row; donor equal to name: that row patched in place) with',
           '// the fields below. docs/how-it-works.md, "Matrix XIII\'s world rows", says what each batch holds.',
           '#pragma once', '']
    for b in data['batches']:
        word = cname(b['word'])
        out.append(f'constexpr Patch {word}Patches[] = {{')
        for r in b['rows']:
            out.append(f'    // {r["name"]} ({r["table"]}{", " + r["note"] if r.get("note") else ""})')
            fields = FIELDS[r['table']][1]
            for field, value, _ in r['set']:
                at, kind, _ = fields[field]
                if kind == 'u8':
                    out.append(f'    {{0x{at:x}, Kind::u8, {int(value)}, nullptr}}, // {field}')
                else:
                    out.append(f'    {{0x{at:x}, Kind::{kind}, 0, "{text_of(kind, value)}"}}, // {field}')
        out.append('};')
        out.append(f'constexpr Row {word}Recipe[] = {{')
        first = 0
        for r in b['rows']:
            t = FIELDS[r['table']][0]
            out.append(f'    {{Table::{t}, "{r["name"]}", "{r["donor"]}", {r["id"]}u, {first}, {len(r["set"])}}},')
            first += len(r['set'])
        out.append('};')
        out.append('')
    return '\n'.join(out)


def lua_value(kind, value):
    if kind in ('e', 'b'):
        return str(int(value))
    if kind == 'N':
        value = '|'.join(value)
    return "'" + value + "'"


def lua(data):
    out = ['-- Generated by tools/mxiii_rows.py from data/mxiii-world.json: do not edit by hand.',
           '-- Matrix XIII\'s rows as native/src/lion/mxiii_rows.h writes them, batch by batch, for cut/mxiii.lua\'s',
           '-- read-back: {table, name, ID, checks}, each check {field, kind, value, changed} (cut/enemy.lua\'s',
           '-- kinds). MOVE: the ladders and ledges cut/mxmove.lua spawns (at: the foot or the ledge marker, world cm;',
           '-- yaw in degrees; height: a ladder\'s TotalHeight in cm). BOSS: the boss spawn points cut/mxboss.lua',
           '-- watches.',
           'local R={}']
    for b in data['batches']:
        out.append(f'R.{b["word"].upper()}={{')
        for r in b['rows']:
            fields = FIELDS[r['table']][1]
            checks = ','.join(
                '{' + f"'{f}','{fields[f][2]}',{lua_value(fields[f][2], v)}" + (',true' if c else '') + '}'
                for f, v, c in r['set'])
            out.append(f"    {{'{r['table']}','{r['name']}',{r['id']},{{{checks}}}}},")
        out.append('}')
    out.append('R.MOVE={')
    for m in data['move']:
        extra = f",height={m['height']}" if 'height' in m else ''
        out.append(f"    {{key='{m['key']}',cls='{m['cls']}',at={{{m['at'][0]},{m['at'][1]},{m['at'][2]}}},"
                   f"yaw={m['yaw']}{extra},role='{m['role']}'}},")
    out.append('}')
    out.append('R.BOSS={')
    for k, v in sorted(data['boss'].items()):
        out.append(f"    {k}={{at={{{v['at'][0]},{v['at'][1]},{v['at'][2]}}},yaw={v['yaw']}}},")
    out.append('}')
    out.append('return R')
    return '\n'.join(out) + '\n'


def main(argv):
    data = json.loads(DATA.read_text())
    check(data)
    want = {HEADER: header(data) + '\n', LUA: lua(data)}
    if '--check' in argv:
        stale = [p.relative_to(ROOT).as_posix() for p, t in want.items() if not p.exists() or p.read_text() != t]
        if stale:
            sys.exit('Out of date, run python3 tools/mxiii_rows.py: ' + ', '.join(stale))
        return
    for p, t in want.items():
        p.write_text(t)


if __name__ == '__main__':
    main(sys.argv[1:])
