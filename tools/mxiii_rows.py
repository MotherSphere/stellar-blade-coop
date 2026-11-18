#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""Writes Matrix XIII's rows from data/mxiii-world.json: native/src/world/maps/matrix13/mxiii_rows.h (the batches'
recipes and patches for rows/rows.h) and mod/StellarCoop/Scripts/world/maps/matrix13/level/rows.lua (the same rows for
world/maps/matrix13/level/travel.lua's read-back, the ladders and ledges world/maps/matrix13/level/move.lua spawns, the
boxes and barrels world/maps/matrix13/level/breakables.lua spawns, the boss points world/maps/matrix13/level/boss.lua
watches).

  python3 tools/mxiii_rows.py          write both files
  python3 tools/mxiii_rows.py --check  exit 1 when either file differs from what the data gives

Each field a row sets must be in FIELDS: its offset in the row struct (SDK stellar-sdk-647527f), the patch kind of
rows/rows.h and the check kind of core/enemy.lua's read-back.
"""
import json
import sys
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'data/mxiii-world.json'
HEADER = ROOT / 'native/src/world/maps/matrix13/mxiii_rows.h'
LUA = ROOT / 'mod/StellarCoop/Scripts/world/maps/matrix13/level/rows.lua'

# The license header both written files start with, after the comment mark.
LICENSE_HEADER = ('Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors',
                  'SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later',
                  'SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a '
                  'permission.')

# Table asset name: (rows/rows.h Table, {field: (offset, patch kind, read-back kind)}).
FIELDS = {
    'CharacterTable': ('character', {'DefaultEffectArray': (0x220, 'names', 'N')}),
    'ZoneCampTable': ('camp', {'CampName': (0x18, 'string', 's'), 'CampType': (0x28, 'u8', 'e'),
                               'Region': (0x2c, 'name', 'n'), 'RegionName': (0x34, 'name', 'n'),
                               'CoinSpawnPointName': (0x60, 'name', 'n'), 'CampDisplayType': (0x6c, 'u8', 'e')}),
    'ZoneEnvSpawnTable': ('env', {
        'ZoneList': (0x20, 'names', 'N'), 'EnvActorName': (0x30, 'name', 'n'), 'EnvBPPath': (0x38, 'string', 's'),
        'SpawnPointName': (0x48, 'name', 'n'), 'EnvAlias': (0x58, 'name', 'n'), 'InitActivate': (0x60, 'u8', 'e'),
        'InitStateTag': (0x64, 'name', 'n'), 'SaveType': (0x6c, 'u8', 'e'),
        **{f'EventTagName{i}': (0x70 + 0x18 * (i - 1), 'name', 'n') for i in range(1, 11)},
        **{f'TagEventList{i}': (0x78 + 0x18 * (i - 1), 'names', 'N') for i in range(1, 11)},
        'InteractionRange': (0x214, 'f32', 'f'), 'InteractionAngle': (0x220, 'f32', 'f'),
        'Interaction': (0x230, 'string', 's'), 'LinkEnvSpawnList': (0x260, 'names', 'N'),
        'TargetCamp': (0x270, 'name', 'n'), 'SequenceTagNameList': (0x350, 'names', 'N'),
        # The per-state lists, one item a state of SequenceTagNameList, in its order.
        'OutTransitSequenceList': (0x370, 'strings', 'S'), 'OutTransitTemplatePath': (0x380, 'strings', 'S'),
        'ActiveSequenceList': (0x3b0, 'strings', 'S'), 'ShopDataList': (0x460, 'names', 'N'),
        'PuzzleInputText1': (0x31c, 'name', 'n'),
        'RewardTagName1': (0x160, 'name', 'n'), 'State_RewardGroup1': (0x168, 'name', 'n')}),
    'ZoneTriggerTable': ('trigger', {'Zone': (0x14, 'name', 'n'), 'InitActivate': (0x1c, 'u8', 'e'),
                                     'TouchEvents': (0x20, 'names', 'N'), 'InitialDoingCount': (0x5c, 'i32', 'i'),
                                     'SaveType': (0x68, 'u8', 'e')}),
    'EventSpawnTable': ('spawn', {
        'SpawnPointName': (0x14, 'name', 'n'), 'CharacterAlias': (0x20, 'names', 'N'), 'SpawnType': (0x30, 'u8', 'e'),
        'Zone': (0x34, 'name', 'n'), 'SaveType': (0x44, 'u8', 'e'), 'EventOnDead': (0x70, 'names', 'N'),
        'EventOnBattle': (0x80, 'names', 'N'), 'EventFirstTimeOnBattle': (0x90, 'names', 'N'),
        'GoPathAfterSpawn': (0xb1, 'u8', 'b'),
        'PathWay': (0xb8, 'string', 's'), 'RewardGroup': (0xc8, 'name', 'n'), 'AIGroupAlias': (0xe0, 'name', 'n'),
        'AIGroupName': (0xe8, 'name', 'n')}),
    # shortcut: SpawnItemCount is an int32 written as its low byte (counts under 256, the donor's upper bytes 0);
    # add an i32 patch kind if a count of 256 or more is ever needed.
    'EventItemTable': ('eitem', {'Zone': (0x20, 'name', 'n'), 'SpawnPointName': (0x2c, 'name', 'n'),
                                 'SpawnItemAlias': (0x34, 'name', 'n'), 'SpawnItemCount': (0x3c, 'u8', 'e')}),
    'ZoneEventTable': ('zevent', {'Type': (0x14, 'u8', 'e'), 'EventAlias': (0x18, 'name', 'n'),
                                  'EventConditionCheckType': (0x30, 'u8', 'e'), 'EventDelayTime': (0x34, 'f32', 'f')}),
    'EventEnvControlTable': ('envc', {'EnvSpawnAlias': (0x14, 'name', 'n'), 'EnvControlType': (0x1c, 'u8', 'e'),
                                      'TagName': (0x28, 'name', 'n'), 'Activate': (0x30, 'u8', 'e'),
                                      'AddProgressValue': (0x34, 'i32', 'i')}),
    'WorldTransitionTable': ('transition', {
        'EnvSpawnAlias': (0x30, 'name', 'n'), 'EventSpawnAliasArray': (0x38, 'names', 'N'),
        'FromWorldAlias': (0x48, 'name', 'n'), 'FromIsolatedAreaAlias': (0x50, 'name', 'n')}),
    'EventZoneWarpTable': ('warp', {'TargetWorld': (0x24, 'name', 'n'), 'TargetZoneCamp': (0x2c, 'name', 'n'),
                                    'TargetSpawnPoint': (0x34, 'name', 'n')}),
    'EffectVolumeTable': ('effvol', {'ActiveZoneAlias': (0x18, 'name', 'n'), 'EnterEffectAlias': (0x20, 'name', 'n')}),
    'ConditionTable': ('condition', {'CustomStr01': (0x18, 'string', 's')}),
    'ConditionGroupTable': ('cgroup', {'ConditionEq': (0x28, 'u8', 'e')}),
    'AlbumTable': ('album', {'PopupWhenUnlock': (0x1d, 'u8', 'b'), 'PauseWhenPopup': (0x1e, 'u8', 'b'),
                             'GroupName': (0x20, 'string', 's'), 'Name': (0x30, 'string', 's'),
                             'Desc': (0x40, 'string', 's'), 'AchievementUnlocked': (0x70, 'name', 'n'),
                             'AchievementPopup': (0x80, 'name', 'n')}),
    'AchievementTable': ('achievement', {'ParamValue1': (0x18, 'string', 's'),
                                         'ProgressAchievementOnCompleted': (0xb4, 'name', 'n'),
                                         'ProgressAchievementValueOnCompleted': (0xbc, 'i32', 'i'),
                                         'ProgressAchievementOnCompleted2': (0xc0, 'name', 'n'),
                                         'ProgressAchievementArrayOnCompleted': (0xd0, 'names', 'N')}),
    'PuzzleStringArrayTable': ('puzzle', {'StringArray': (0x18, 'strings', 'S')}),
}
SIZE = {'u8': 1, 'f32': 4, 'i32': 4, 'name': 8, 'string': 16, 'names': 16, 'strings': 16}
STRUCT = {'CharacterTable': 0x548, 'ZoneCampTable': 0xa8, 'ZoneEnvSpawnTable': 0x508, 'ZoneTriggerTable': 0xa8,
          'EventSpawnTable': 0x290, 'EventItemTable': 0x80, 'ZoneEventTable': 0x70, 'WorldTransitionTable': 0x88,
          'EventEnvControlTable': 0x70, 'EventZoneWarpTable': 0x70, 'EffectVolumeTable': 0xc0, 'ConditionTable': 0x78,
          'ConditionGroupTable': 0x50, 'AlbumTable': 0x90, 'AchievementTable': 0xf0, 'PuzzleStringArrayTable': 0x30}
POOL = 0x1000  # rows/rows.h's kPoolBytes: a row's strings and lists must fit it.


def cname(word):
    return 'k' + word[0].upper() + word[1:]


def text_of(kind, value):
    """The value as rows/rows.h's patch text: names joined by '|'."""
    return '|'.join(value) if kind in ('names', 'strings') else str(value)


def check(data):
    """Raises on data the native part would refuse or misread."""
    seen = {}
    for b in data['batches']:
        assert b['word'].isalpha() and b['word'].islower(), b['word']
        assert 0 < len(b['rows']) < 256, (b['word'], 'a row index fits a byte')
        for r in b['rows']:
            assert r['table'] in FIELDS, r['table']
            # A name once, but for a later batch patching a row in place (mxnames, on the mxiii batch's camps).
            before = seen.get((r['table'], r['name']))
            assert before is None or (before != b['word'] and r['donor'] == r['name']), r['name']
            seen[(r['table'], r['name'])] = b['word']
            assert 0 < r['id'] < 2 ** 32, r['name']
            # The game numbers its own ZoneEvent rows from 1 up, and build 26123051 added 8480 and 8481.
            assert r['table'] != 'ZoneEventTable' or r['id'] >= 2 ** 31, (r['name'], 'an ID the game may take')
            fields = FIELDS[r['table']][1]
            spans, pool = [], 0
            for field, value, changed in r['set']:
                at, kind, _ = fields[field]
                assert at >= 0x14 and at + SIZE[kind] <= STRUCT[r['table']], (r['name'], field)
                assert all(at + SIZE[kind] <= a or b2 <= at for a, b2 in spans), (r['name'], field, 'overlaps')
                spans.append((at, at + SIZE[kind]))
                if kind == 'u8':
                    assert isinstance(value, (int, bool)) and 0 <= int(value) <= 255, (r['name'], field)
                elif kind in ('f32', 'i32'):
                    # rows/rows.h holds both in a float: an int32 must stay exact there.
                    assert isinstance(value, (int, float)) and not isinstance(value, bool), (r['name'], field)
                    assert kind == 'f32' or (int(value) == value and abs(value) < 2 ** 24), (r['name'], field)
                elif kind == 'names':
                    assert isinstance(value, list) and all(v and '|' not in v and len(v) < 128 for v in value)
                    pool += -(-8 * len(value) // 8) * 8
                elif kind == 'strings':
                    # Joined by '|': one empty item alone would read as an empty list.
                    assert isinstance(value, list) and value != [''], (r['name'], field)
                    assert all('|' not in v and '"' not in v and '\\' not in v for v in value), (r['name'], field)
                    pool += 16 * len(value) + sum(-(-2 * (len(v) + 1) // 8) * 8 for v in value if v)
                else:
                    assert isinstance(value, str) and '"' not in value and '\\' not in value, (r['name'], field)
                    pool += -(-2 * (len(value) + 1) // 8) * 8 if value else 0
                assert isinstance(changed, bool)
            assert pool <= POOL, (r['name'], pool, 'its strings overflow the pool')
    # The breakables: Matrix 11's pairings (Box_02 always the _Plus row, a barrel the explosive row with its fuse).
    keys = [m['key'] for m in data['break']]
    assert len(set(keys)) == len(keys), 'a breakable key given twice'
    for m in data['break']:
        want = {'box1': ('ME_01_ZEA_003', 'ME_01_ZEA_007'), 'box2': ('ME_01_ZEA_007',),
                'barrel': ('ME_01_ZEA_001',)}[m['cls']]
        assert m['alias'] in want and ('delay' in m) == (m['cls'] == 'barrel'), m['key']


# The header's head after the generated line, a paragraph a string ('' a blank comment line): what the batches
# hold.
HEAD = [
    ("Matrix XIII's batches (coop mxiii, world/maps/matrix13/level/travel.lua): each row a copy of its "
     'donor (a shipped row; donor equal to name: that row patched in place) with the fields below. '
     'docs/README.md, "Matrix XIII\'s world rows", says what each batch holds.'),
    '',
    ("The mxiii batch (kMxiiiRecipe, with its own patches) holds the 8 rows the cut dungeon's first zone "
     'lacks for a camp of its own (coop mxiii, world/maps/matrix13/level/travel.lua): ZoneCampTable '
     'DLC02_10_Camp_01 (280001, a copy of ME01_Camp_03 that the camp list shows once activated) and 7 '
     'ZoneEnvSpawnTable rows in Zone_DLC02_10 whose TargetCamp names that camp (2800032900 to 2800032906, '
     "copies of the DLC02_10 camp kit's rows 420 to 426): DLC02_10_EnvS_900 leads SB's camp travel there, "
     "and the camp's 7 rows bind by name the kit the test pak places in its MXIII_Camps_A level, in the "
     'two zone tables only it writes. Then 2 rows give zone 30 a camp with no kit (coop mxiii 30): '
     'ZoneCampTable DLC02_30_Camp_01 (281001, a copy of ME03_Camp_03) and DLC02_30_EnvS_900 (2810032900, '
     "DLC02_10_EnvS_900's recipe in Zone_DLC02_30). After them it patches 5 shipped ZoneTriggerTable rows "
     'in place, the table only it reads, so the zone 20 waves and the zone 40 chains of spawns fire '
     "without the dungeon's own props."),
    '',
    ('Nine batches, each its own ask so a refusal in one never stops another: mxrecords (last), mxiii, '
     "mxspawn, mxenv, mxupper, mxmiddle, mxlower, mxlily (Lily's menu in this world: three IsInWorld "
     'conditions and three groups of her Tetrapod graph, shipped rows patched in place) and mxnames (the '
     "camps' display keys, patched last in place on the mxiii batch's own rows, and only once "
     "game/camp_text.h's entries exist). They go in at the title on the co-op save files with the zMXIII_P"
     ' pak there (world/maps/matrix13/level/travel.lua), so a co-op save that names one of their rows '
     'loads with it. Each row copies a shipped row of its table; a row whose donor is itself is that '
     'shipped row patched in place.'),
    ('mxiii: the camps and what they need. Zone_DLC02_10 (ZoneTable 2800, world DLCMatrix13) has no camp, '
     "so SB's camp travel (game/travel.h) cannot reach it without these. DLC02_10_Camp_01 and its first "
     "env row DLC02_10_EnvS_900 (the camp base; FUN_141cdfbd0 reads only a camp's first env row, its Zone "
     "or ZoneList[0], to find the world), then its kit 901 to 906. When the zone's env rows are created, "
     'FUN_141d207c0 reads EnvBPPath: empty (Num below 2), it binds the placed SBZoneEnvActor whose '
     "EnvActorName equals the row's (FUN_142281550); set, it spawns that class at the SBSpawnPoint named "
     'SpawnPointName (FUN_1422925c0). The shipped DLC02 kit rows have none and look for placed actors no '
     "shipped pak holds. The zone 10 camps' 11 rows (900 to 906 and 420, 421, 423, 426) keep their donor's"
     ' empty EnvBPPath and None SpawnPointName and bind by their own name the kit actors the test pak '
     'places in its MXIII_Camps_A level; every other kit row gets a blueprint and the spawn point of its '
     "own name. Each kit row's TargetCamp names its own camp instead of the placeholders WLB10_Camp_05 and"
     " SE02_Camp_02. A vending machine's LinkEnvSpawnList switches its kit objects on once a coin "
     "activates the camp; a full camp's lists its base row too, in the shipped order (not yet run in "
     "game). Then zone 30's rest stop DLC02_30_Camp_01 (a simple camp now; the alias stays) with its "
     "travel row, zone 40's triggers 001 and 002 (enabled from the start), the other 9 camps of the map "
     '(Tetrapod, simple and full), their kits (34 shipped rows patched, 14 new), the three new coins, and '
     "zone 0's Tetrapod: machine DLC02_00_EnvS_960, Lily DLC02_00_E_CharS_960 and WorldTransitionTable "
     'WT_T_MX13.'),
    ('mxspawn: the Naytibas. The killable Stalker MX13_M_Sawshark (CharacterTable 50071, '
     'CHAL_UME_M_Sawshark_01 without Passive_Immortal) first, then the 8 M_DummyC rows patched to shipped '
     'Naytibas, the zone 4 trio 035, 036 and 042 made ZoneEvent spawns, 25 new enemy rows and the three '
     'bosses (Gardener M_Gardener and Lion M_LionC come from the gardener and lion batches, which '
     'world/maps/matrix13/level/travel.lua asks first), the 4 zone events that spawn the Gardener and the '
     'trio, and the two trigger rows that run them. SB binds a spawn row to the placed SBSpawnPoint whose '
     "name equals the row's SpawnPointName field (FUN_1422925c0); every name here is one the cooked map "
     'places.'),
    ('mxenv: loot, kill volumes and the shipped device rows dev already patched: the one-way doors 050, '
     '051 and 037 (an empty arrow at their point, our own sequences moving the cooked leaf), the R29 gate '
     'and its card switch listing zone 1 and 2, the 55 m lift waiting at the top with our sequences, the '
     "74 m lift's call switches (the lift controller, disabled until the first ride up as Shift Up wired "
     'them), two kill volumes under the lift shafts.'),
    ('mxupper, mxmiddle, mxlower: the mechanisms of zones 0 to 2, of zone 3 and of zone 4, the way Matrix '
     '11 builds its own. A door is an Env_Countdown_Gate row with an empty arrow at its point, closed at '
     'the start, whose four LevelSequences (ToOpen, Closed, Opened, ToClose, in /Game/MXIII_Editor/Seq) '
     'move the cooked leaf; one opener row per side (ME_Area01_ShotCutDoor) fires the EventEnvControlTable'
     " row that opens it, and a one-way door's other side has the _Opposite graph. Gates keep their "
     'shipped switch chains with our sequences; lifts are their shipped Env_Lift rows with our sequences '
     "and call switches that send the cab to their landing. Arenas lock and unlock through the spawn rows'"
     ' EventOnBattle, EventFirstTimeOnBattle and EventOnDead: the first fight shuts the doors and disables'
     ' their openers, each death adds 1 to an Env_<N>CountProgress row whose On state opens them again '
     "(SE_08's pattern), and the Lion's own death opens the fan door and D7. The zone 2 wave triggers 601 "
     'to 603 also shut the arena gate behind EVE, and trigger 601 of zone 3 shuts the pressure door behind'
     " her for good. Zone 4's water device keeps its shipped P1, P2 and P3 states with our sequences, "
     'driven by its drain and pipe panels, with two toxic effect volumes.'),
    ('Free names and IDs in the build 26123051 dumps; struct sizes and offsets from the SDK '
     '(stellar-sdk-647527f).'),
]


def header(data):
    out = [*(f'// {line}' for line in LICENSE_HEADER),
           '// Generated by tools/mxiii_rows.py from data/mxiii-world.json: do not edit by hand.',
           *('// ' + line if line else '//'
             for p in HEAD for line in textwrap.wrap(p, 117, break_on_hyphens=False) or ['']),
           '#pragma once', '', '#include "rows/rows.h"', '', 'namespace coop::lion {', '']
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
                elif kind == 'i32':
                    out.append(f'    {{0x{at:x}, Kind::i32, {int(value)}, nullptr}}, // {field}')
                elif kind == 'f32':
                    out.append(f'    {{0x{at:x}, Kind::f32, {float(value)!r}f, nullptr}}, // {field}')
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
    words = [cname(b['word']) for b in data['batches']]
    out += [f'constexpr size_t {w}Rows = sizeof {w}Recipe / sizeof {w}Recipe[0];' for w in words]
    line = 'static_assert('
    for i, w in enumerate(words):
        part = f'{w}Rows < 256' + (' &&' if i < len(words) - 1 else ',')
        if len(line) + len(part) + 1 > 120:
            out.append(line.rstrip())
            line = '              '
        line += part + ' '
    out += [line.rstrip(), '              "a row index fits a byte");']
    batches = [f'{w}{{"{b["word"]}", {w}Recipe, {w}Rows, {w}Patches}}' for w, b in zip(words, data['batches'])]
    out.append('constexpr Batch ' + ',\n    '.join(batches) + ';')
    out += ['', '} // namespace coop::lion']
    return '\n'.join(out)


def lua_value(kind, value):
    if kind in ('e', 'b', 'i'):
        return str(int(value))
    if kind == 'f':
        return repr(float(value))
    if kind in ('N', 'S'):
        value = '|'.join(value)
    return "'" + value + "'"


def lua(data):
    out = [*(f'-- {line}' for line in LICENSE_HEADER),
           '-- Generated by tools/mxiii_rows.py from data/mxiii-world.json: do not edit by hand.',
           '-- Matrix XIII\'s rows as native/src/world/maps/matrix13/mxiii_rows.h writes them, batch by batch, for',
           '-- world/maps/matrix13/level/travel.lua\'s read-back: {table, name, ID, checks}, each check {field, kind, '
           'value,',
           '-- changed} (core/enemy.lua\'s kinds). MOVE: the ladders, ledges and ropes '
           'world/maps/matrix13/level/move.lua spawns',
           '-- (at: the actor origin, world cm; yaw in degrees; a ladder\'s Meshes stack, StartUnit and',
           '-- CollisionBottomZAdd and the TotalHeight they give; a ledge\'s mesh; a rope\'s drop, its RopeDistanceB;',
           '-- env: the EnvActorName binding it to its row). BOSS: the boss spawn points '
           'world/maps/matrix13/level/boss.lua',
           '-- watches. WARP: coop mxiii warp\'s arrival points (at, yaw). BREAK: the boxes and barrels',
           '-- world/maps/matrix13/level/breakables.lua spawns in this order (key: the cooked proxy it replaces; '
           'alias: its',
           '-- ZoneEventActorTable row; delay: a barrel\'s fuse, min and max s; proxy_in_cook=false: no proxy to hide).',
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
        extra = ''.join(f",{lk}={m[k]}" for k, lk in (('height', 'height'), ('start', 'start'), ('bottom', 'bottom'),
                                                      ('drop', 'drop')) if k in m)
        if 'meshes' in m:
            extra += ',meshes={' + ','.join(str(x) for x in m['meshes']) + '}'
        extra += ''.join(f",{k}='{m[k]}'" for k in ('mesh', 'env') if k in m)
        out.append(f"    {{key='{m['key']}',cls='{m['cls']}',at={{{m['at'][0]},{m['at'][1]},{m['at'][2]}}},"
                   f"yaw={m['yaw']}{extra},role='{m['role']}'}},")
    out.append('}')
    out.append('R.BREAK={')
    for m in data['break']:
        extra = ',delay={' + ','.join(str(x) for x in m['delay']) + '}' if 'delay' in m else ''
        if m.get('proxy_in_cook') is False:
            extra += f",proxy_in_cook=false,gates='{m['gates']}'"
        out.append(f"    {{key='{m['key']}',level='{m['level']}',cls='{m['cls']}',at={{{m['at'][0]},{m['at'][1]},"
                   f"{m['at'][2]}}},yaw={m['yaw']},alias='{m['alias']}'{extra}}},")
    out.append('}')
    out.append('R.WARP={')
    for w in data['warp']:
        out.append(f"    {{n={w['n']},name='{w['name']}',mover='{w['mover']}',at={{{w['at'][0]},{w['at'][1]},"
                   f"{w['at'][2]}}},yaw={w['yaw']}}},")
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
