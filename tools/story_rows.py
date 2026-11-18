#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""Writes the generated block of native/src/game/story/rows.h from a game build's tables: the story scenes and trips
that story sync may share. It reads the tables and the quest table of native/src/game/quest/sync.h only.

  python3 -I tools/story_rows.py JSON_DIR   JSON_DIR holds the <Table>.uasset.json exports of the pinned build

Run it after tools/world_rows.py and after the quest table of game/quest/sync.h is written: a scene's quest flag comes
from that table.

Scenes: one entry per ZoneEventTable Theater row whose EventTheaterTable row plays (ControlType Play) a theater asset,
or with none a level sequence alone (a subtitle sequence). Each holds the path the zone-event handler gives the theater
manager (TheaterAssetPath, else LevelSeqAssetPath), the row, the zone its name gives (DED10_E_Theater_001: Zone_DED10),
the priority as the manager keeps it (the EventTheaterTable Priority, 0 when below), its FinishEvents, the quest flag
(a step of a shared quest runs it: game/quest/sync.h's kSteps names it) and, for a row with AddEvents, its
ZoneEventTable condition: RunZoneEvent runs AddEvents even when the condition fails. Entries are sorted by path, then in
table order.

Trips: the ZoneEventTable PlayerWarp and ChangeZone rows of the story, each with its target and what starts it in the
tables (STARTERS). Three kinds stay out: a PlayerWarp with no EventZoneWarpTable row (no target), a test world's row
or one that warps to a test world, the cut multiplayer's warp (a TargetSpawnPoint with MultiPlay in its name).
"""
import json
import re
import sys
import textwrap
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEADER = ROOT / 'native/src/game/story/rows.h'
QUESTS = ROOT / 'native/src/game/quest/sync.h'
BUILD = '26123051'  # The build whose tables the block is written from; change it with the tables.
BEGIN = '// ---- story rows: generated, begin ----'
END = '// ---- story rows: generated, end ----'
TABLES = ('ZoneEventTable', 'EventTheaterTable', 'EventZoneWarpTable', 'ZoneTable', 'ZoneTriggerTable',
          'WorldTransitionTable', 'ZoneEnvSpawnTable', 'ZoneEnvTable', 'QuestTable', 'QuestTaskGroupTable',
          'QuestTaskTable')
QUEST_BEGIN, QUEST_END = '// ---- quest table: generated, begin ----', '// ---- quest table: generated, end ----'
# What starts a trip row in the tables, by letter: a theater's FinishEvents or AddEvents, another zone event's, a zone
# trigger, a world transition, a quest, a task group or a task, a zone's own events, an env state. No letter: "g", an
# interaction graph or an asset runs it.
STARTERS = 'tezwqav'
TEST = re.compile(r'(LV|Level)_Test')
NAME = re.compile(r'[A-Za-z0-9_\-]+')  # A row or zone name: goes into a C++ string literal and a space-separated list.
PATH = re.compile(r'[A-Za-z0-9_\-/.]+')  # An asset path.


def enum(value):
    """An enum value without its type: 'ESBZoneEventType::ZoneEvent_Theater' gives 'ZoneEvent_Theater'."""
    return value.split('::')[-1]


def kind(row):
    """A ZoneEventTable row's type: 'ESBZoneEventType::ZoneEvent_Theater' gives 'Theater'."""
    return enum(row['Type']).removeprefix('ZoneEvent_')


def none(value):
    return '' if value == 'None' else value


def load(folder):
    """Each table of TABLES: its rows by name, from <folder>/<Table>.uasset.json."""
    out = {}
    for name in TABLES:
        data = json.loads((Path(folder) / f'{name}.uasset.json').read_text())
        out[name] = next(e['Rows'] for e in data if 'Rows' in e)
    return out


def quest_events(text):
    """The names kSteps of a game/quest/sync.h text lists as the events of a shared quest's steps."""
    block = text[text.index(QUEST_BEGIN):text.index(QUEST_END)]
    steps = block[block.index('constexpr Step kSteps[]'):]
    steps = steps[:steps.index('};')]
    names = set()
    for literals in re.findall(r"\{'.', (?:true|false), \"[^\"]*\", ((?:\"[^\"]*\"\s*)+)\}", steps):
        names.update(''.join(re.findall(r'"([^"]*)"', literals)).split())
    return names


def zone_of(t, name):
    """The zone a row's name gives (Xion_10_E_Theater_029: Zone_Xion_10, DED10_E_Theater_001: Zone_DED10), or ''."""
    p = name.split('_E_')[0].split('_ZoneE_')[0]
    for zone in (f'Zone_{p}', f'Zone_{p.replace("_", "")}', f'Zone_{p[:-2]}_{p[-2:]}'):
        if zone in t['ZoneTable']:
            return zone
    return ''


def scenes(t, quest):
    """The scene entries, sorted by path then in table order, as dicts; quest: quest_events()."""
    out = []
    for name, row in t['ZoneEventTable'].items():
        theater = t['EventTheaterTable'].get(row['EventAlias']) if kind(row) == 'Theater' else None
        if theater is None or enum(theater['ControlType']) != 'ZoneEvent_Theater_Play':
            continue
        path = theater['TheaterAssetPath'] or theater['LevelSeqAssetPath']
        if not path:
            continue
        test = row['AddEvents'] and (row['EventCondition'] != 'None' or row['EventConditionGroup'] != 'None')
        out.append({'path': path, 'row': name, 'zone': zone_of(t, name), 'finish': ' '.join(row['FinishEvents']),
                    'condition': none(row['EventCondition']) if test else '',
                    'group': none(row['EventConditionGroup']) if test else '',
                    'priority': max(theater['Priority'], 0), 'sequence': not theater['TheaterAssetPath'],
                    'quest': name in quest})
    return sorted(out, key=lambda s: s['path'])  # Stable: table order within a path.


def ambiguity(entries):
    """(paths with two rows or more equal in priority and FinishEvents, paths where such rows also share a zone, the
    classes with two rows or more, keyed by (path, priority, FinishEvents)), over scenes()."""
    classes = {}
    for s in entries:
        classes.setdefault((s['path'], s['priority'], s['finish']), []).append(s)
    equal = {k: v for k, v in classes.items() if len(v) > 1}
    zoned = {k for k, v in equal.items() if len({s['zone'] for s in v}) < len(v)}
    return len({k[0] for k in equal}), len({k[0] for k in zoned}), equal


def starters(t):
    """The STARTERS letters of each zone event name the tables start."""
    out = {}

    def add(names, letter):
        for name in names:
            out.setdefault(name, set()).add(letter)
    for row in t['ZoneEventTable'].values():
        add(row['FinishEvents'] + row['AddEvents'], 't' if kind(row) == 'Theater' else 'e')
    for row in t['ZoneTriggerTable'].values():
        add(row['TouchEvents'] + row['LeaveEvents'], 'z')
    add([r['ZoneEventAlias'] for r in t['WorldTransitionTable'].values()], 'w')
    for row in t['QuestTable'].values():
        add(row['AcquireEventArray'] + row['CompleteEventArray'], 'q')
    for row in t['QuestTaskGroupTable'].values():
        add(row['ActivateEvent'] + row['ProgressEvent'] + row['CompleteEvent'], 'q')
    for row in t['QuestTaskTable'].values():
        add(row['TaskStartEventSpawnAliasList'] + row['TaskCompleteEventSpawnAliasList'] +
            row['TaskProgressEventSpawnAliasList'], 'q')
    for row in t['ZoneTable'].values():
        add([e for f in ('EnterEvents', 'LeaveEvents', 'ActiveEvents', 'DeactiveEvents', 'ZoneSpawnEvents')
             for e in row[f]], 'a')
    for row in t['ZoneEnvSpawnTable'].values():
        add([e for n in range(1, 11) for e in row[f'TagEventList{n}']], 'v')
    for row in t['ZoneEnvTable'].values():
        add([e for x in row['StateEffectList'] for e in x['EffectList']], 'v')
        add([e for x in row['StateZoneEventList'] for e in x['ZoneEventList']], 'v')
    return {k: ''.join(c for c in STARTERS if c in v) for k, v in out.items()}


def trips(t):
    """(the trip entries sorted by row, as dicts, a Counter of the rows left out by reason)."""
    started, out, left = starters(t), [], Counter()
    for name, row in t['ZoneEventTable'].items():
        if kind(row) == 'ChangeZone':
            target = row['EventAlias']
        elif kind(row) == 'PlayerWarp':
            warp = t['EventZoneWarpTable'].get(row['EventAlias'])
            if warp is None:
                left['no target'] += 1
                continue
            if TEST.search(name) or TEST.search(warp['TargetWorld']):
                left['test world'] += 1
                continue
            if 'MultiPlay' in warp['TargetSpawnPoint']:
                left['multiplayer'] += 1
                continue
            point = warp['TargetZoneCamp'] if warp['TargetZoneCamp'] != 'None' else warp['TargetSpawnPoint']
            target = f'{warp["TargetWorld"]} {point}'
        else:
            continue
        out.append({'row': name, 'target': target, 'starters': started.get(name) or 'g'})
    return sorted(out, key=lambda x: x['row']), left


def literal(text, indent):
    """text as C++ string literals, adjacent ones split after a '/', '.' or ' ' so that each line stays within 116
    columns."""
    pieces, line = [], ''
    for part in re.split(r'(?<=[/. ])', text):
        if line and indent + len(line) + len(part) + 4 > 116:
            pieces.append(line)
            line = ''
        line += part
    pieces.append(line)
    return ('\n' + ' ' * indent).join(f'"{p}"' for p in pieces)


def render(entries, trip_list, counts):
    """The generated block, its begin and end lines included; counts: the note's lines of counts."""
    names = {x for s in entries for x in (s['row'], s['zone'], s['condition'], s['group'], *s['finish'].split())}
    names |= {x for r in trip_list for x in (r['row'], *r['target'].split())}
    bad = sorted(x for x in names - {''} if not NAME.fullmatch(x))
    bad += sorted(s['path'] for s in entries if not PATH.fullmatch(s['path']))
    if bad:
        raise ValueError(f'names that would not go into a C++ string literal as they are: {bad}')
    if not (entries and trip_list):
        raise ValueError('an empty list would make a zero-size C++ array')
    note = (f"Written by tools/story_rows.py from build {BUILD}'s {', '.join(TABLES[:-1])} and {TABLES[-1]}, with "
            "game/quest/sync.h's quest table. Another build needs it written again from that build's tables.")
    b = lambda v: 'true' if v else 'false'
    out = [BEGIN, *(f'// {line}' for c in [note, *counts] for line in textwrap.wrap(c, 117)),
           'constexpr Scene kScenes[] = {']
    for s in entries:
        head = f'     "{s["row"]}", "{s["zone"]}",'
        tail = f', "{s["condition"]}", "{s["group"]}", {s["priority"]}, {b(s["sequence"])}, {b(s["quest"])}}},'
        finish = literal(s['finish'], 5)
        out.append(f'    {{{literal(s["path"], 5)},')
        if '\n' not in finish and len(f'{head} {finish}{tail}') <= 116:
            out.append(f'{head} {finish}{tail}')
        else:  # The FinishEvents on lines of their own, the rest after them.
            last = finish.split('\n')[-1]
            out += [head, f'     {finish}' + (tail if len(last) + len(tail) <= 111 else f',\n    {tail[1:]}')]
    out += ['};', 'constexpr Trip kTrips[] = {',
            *(f'    {{"{r["row"]}", "{r["target"]}", "{r["starters"]}"}},' for r in trip_list), '};', END]
    return '\n'.join(out)


def write(header, block):
    """Puts block in place of the generated block of header."""
    text = header.read_text()
    begin, end = text.index(BEGIN), text.index(END) + len(END)
    header.write_text(text[:begin] + block + text[end:])


def main(argv):
    if len(argv) != 1:
        sys.exit('Use: python3 -I tools/story_rows.py JSON_DIR')
    t = load(argv[0])
    entries = scenes(t, quest_events(QUESTS.read_text()))
    trip_list, left = trips(t)
    paths, zoned, equal = ambiguity(entries)
    differ = sum(1 for v in equal.values() for s in v[1:]
                 if (s['quest'], s['condition'], s['group'], t['ZoneEventTable'][s['row']]['AddEvents']) !=
                 (v[0]['quest'], v[0]['condition'], v[0]['group'], t['ZoneEventTable'][v[0]['row']]['AddEvents']))
    test = sum(1 for s in entries if s['condition'] or s['group'])
    graph = sum(1 for r in trip_list if r['starters'] == 'g')
    counts = [f'Scenes: {len(entries)} rows over {len({s["path"] for s in entries})} paths, '
              f'{sum(s["sequence"] for s in entries)} of them a level sequence alone, '
              f'{sum(s["quest"] for s in entries)} run by a shared quest step.',
              f'Still ambiguous after the filters: {paths} paths keep rows equal in priority and FinishEvents, {zoned} '
              f'of them with the same zone; {differ} rows after the first of such a group differ from it in AddEvents, '
              'condition or quest flag.',
              f'Theater rows with both a ZoneEventTable condition and AddEvents: {test}.',
              f'Trips: {len(trip_list)} rows, {graph} started by no table (sent); left out: '
              f'{", ".join(f"{k} {n}" for k, n in sorted(left.items())) or "none"}.']
    write(HEADER, render(entries, trip_list, counts))
    for line in counts:
        print(line)


if __name__ == '__main__':
    main(sys.argv[1:])
