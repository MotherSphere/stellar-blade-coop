#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""Writes the generated block of native/src/game/boss_rows.h from a game build's tables: the HP triggers of the bosses
and elites with the scene each one starts and which of those scenes hold a QTE. Also the LV_Dead effect rows.

  python3 -I tools/boss_rows.py JSON_DIR   JSON_DIR holds the <Table>.uasset.json exports of the pinned build

Triggers: SB builds an actor's condition triggers from its EventSpawnTable row (FUN_141a6a440 on 26123051): condition i
of ConditionsTrigger runs event i of ConditionTriggerEvent. A None condition, or one with no event at its index, builds
no trigger. One entry per (row, condition) in table order, for each ActorHP condition of a kept row. A row is kept when
the Rank of its first CharacterAlias is Boss or Elite. Left out: rows whose name starts with Test_, LV_Test, MEDemo,
Nikke_, NKGame_ or EVE_GunNikke (test, demo and NIKKE rows) and every row holding _Boss_ (Boss Challenge, played
solo). A kept ActorHP condition whose equation is not LEQ stops the tool: the header's crosses() reads LEQ only.

Scene: the first theater the event plays. The walk takes the event's ZoneEventTable row, then its AddEvents in order, to
depth 4. A Theater row whose EventTheaterTable row (its EventAlias) plays (ControlType Play) gives its TheaterAssetPath,
else its LevelSeqAssetPath. A chain that plays no theater gives "".

QTE: an HP <= 1 Absolute trigger whose scene's alias (the path's last '.' part) is one of QTE_THEATERS, the theaters
read to hold a QTE. Exact alias, never a substring: MV_DED01_Parkinglot_AfterBattle_TrialVersion holds none.

LV_Dead: the ID of every EffectTable row whose name starts with LV_Dead, in table order.
"""
import json
import re
import sys
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEADER = ROOT / 'native/src/game/boss_rows.h'
BUILD = '26123051'  # The build whose tables the block is written from; change it with the tables.
BEGIN = '// ---- boss rows: generated, begin ----'
END = '// ---- boss rows: generated, end ----'
TABLES = ('EventSpawnTable', 'ConditionTable', 'ZoneEventTable', 'EventTheaterTable', 'CharacterTable', 'EffectTable')
LEFT_OUT = ('Test_', 'LV_Test', 'MEDemo', 'Nikke_', 'NKGame_', 'EVE_GunNikke')
RANKS = ('Boss', 'Elite')
DEPTH = 4
QTE_THEATERS = ('MV_DED01_Parkinglot_AfterBattle', 'MV_WLA_Nest_RavenBattle_QTE_Master', 'MV_Xion06_RavenFinish_QTE',
                'MV_SE08_01_EliteNative_QTE_Master', 'MV_Nest_FinalBattle_Adam_QTE',
                'MV_Nest_FinalBattle_Lily_QTE_Save', 'MV_Nest_FinalBattle_Lily_QTE_Die',
                'MV_SE10_AlphaNative_Ending_Master',
                'MV_SE06_LobbyEliteFinish_Theater', 'MV_DED02_Elite_GrubShooterFinish')
NAME = re.compile(r'[A-Za-z0-9_\-]+')  # A row name: goes into a C++ string literal.
PATH = re.compile(r'[A-Za-z0-9_\-/.]*')  # An asset path, "" for none.


def enum(value):
    """An enum value without its type: 'ESBEquation::ESBEQ_LEQ' gives 'ESBEQ_LEQ'."""
    return value.split('::')[-1]


def load(folder):
    """Each table of TABLES: its rows by name, from <folder>/<Table>.uasset.json."""
    out = {}
    for name in TABLES:
        data = json.loads((Path(folder) / f'{name}.uasset.json').read_text())
        out[name] = next(e['Rows'] for e in data if 'Rows' in e)
    return out


def scene(t, name, depth=0, seen=None):
    """The path of the first theater zone event row name plays, through its AddEvents to depth DEPTH, or ''."""
    seen = set() if seen is None else seen
    row = t['ZoneEventTable'].get(name)
    if row is None or name in seen or depth > DEPTH:
        return ''
    seen.add(name)
    if enum(row['Type']) == 'ZoneEvent_Theater':
        theater = t['EventTheaterTable'].get(row['EventAlias'])
        if theater and enum(theater['ControlType']) == 'ZoneEvent_Theater_Play':
            path = theater['TheaterAssetPath'] or theater['LevelSeqAssetPath']
            if path:
                return path
    for add in row['AddEvents']:
        path = scene(t, add, depth + 1, seen)
        if path:
            return path
    return ''


def triggers(t):
    """The trigger entries in table order, as dicts: spawn, row, value, percent, event, scene, qte."""
    out = []
    for name, row in t['EventSpawnTable'].items():
        if name.startswith(LEFT_OUT) or '_Boss_' in name or not row['CharacterAlias']:
            continue
        if t['CharacterTable'].get(row['CharacterAlias'][0], {}).get('Rank') not in RANKS:
            continue
        events = row['ConditionTriggerEvent']
        for i, key in enumerate(row['ConditionsTrigger']):
            c = t['ConditionTable'].get(key)
            if c is None or i >= len(events) or enum(c['ConditionType']) != 'ESBConditionType_ActorHP':
                continue
            if enum(c['ConditionEq']) != 'ESBEQ_LEQ':
                raise ValueError(f'{name} {key}: {c["ConditionEq"]}, not LEQ')
            percent = enum(c['CheckStatCalcType']).endswith('_Percent')
            path = scene(t, events[i])
            qte = c['CheckValue'] == 1 and not percent and path.split('.')[-1] in QTE_THEATERS
            out.append({'spawn': row['ID'], 'row': name, 'value': c['CheckValue'], 'percent': percent,
                        'event': events[i], 'scene': path, 'qte': qte})
    return out


def lv_dead(t):
    """The IDs of the EffectTable rows whose name starts with LV_Dead, in table order."""
    return [row['ID'] for name, row in t['EffectTable'].items() if name.startswith('LV_Dead')]


def literal(text, indent, width):
    """text as C++ string literals, adjacent ones split after a '/' or '.' so that each line stays within width
    columns."""
    pieces, line = [], ''
    for part in re.split(r'(?<=[/.])', text):
        if line and indent + len(line) + len(part) + 2 > width:
            pieces.append(line)
            line = ''
        line += part
    pieces.append(line)
    return ('\n' + ' ' * indent).join(f'"{p}"' for p in pieces)


def render(rows, lv, counts):
    """The generated block, its begin and end lines included; counts: the note's lines of counts."""
    bad = sorted(r['event'] for r in rows if not NAME.fullmatch(r['event']))
    bad += sorted(r['scene'] for r in rows if not PATH.fullmatch(r['scene']))
    if bad:
        raise ValueError(f'names that would not go into a C++ string literal as they are: {bad}')
    if not (rows and lv):
        raise ValueError('an empty list would make a zero-size C++ array')
    note = (f"Written by tools/boss_rows.py from build {BUILD}'s {', '.join(TABLES[:-1])} and {TABLES[-1]}. "
            "Another build needs it written again from that build's tables.")
    b = lambda v: 'true' if v else 'false'
    out = [BEGIN, *(f'// {line}' for c in [note, *counts] for line in textwrap.wrap(c, 117)),
           'constexpr Trigger kTriggers[] = {']
    for r in rows:
        head, tail = f'    {{{r["spawn"]}, {r["value"]}, {b(r["percent"])}, "{r["event"]}",', f', {b(r["qte"])}}},'
        if len(f'{head} "{r["scene"]}"{tail}') <= 116:
            out.append(f'{head} "{r["scene"]}"{tail}')
        else:  # The scene on lines of its own, the flag after its last piece.
            out += [head, f'     {literal(r["scene"], 5, 116 - len(tail))}{tail}']
    out += ['};', 'constexpr int32_t kLvDead[] = {',
            *(f'    {line}' for line in textwrap.wrap(', '.join(map(str, lv)) + ',', 112)), '};', END]
    return '\n'.join(out)


def write(header, block):
    """Puts block in place of the generated block of header."""
    text = header.read_text()
    begin, end = text.index(BEGIN), text.index(END) + len(END)
    header.write_text(text[:begin] + block + text[end:])


def main(argv):
    if len(argv) != 1:
        sys.exit('Use: python3 -I tools/boss_rows.py JSON_DIR')
    t = load(argv[0])
    rows, lv = triggers(t), lv_dead(t)
    line = (f'boss rows: {len(rows)} triggers on {len({r["spawn"] for r in rows})} spawn rows, '
            f'{sum(r["qte"] for r in rows)} QTE, {len(lv)} LV_Dead rows')
    write(HEADER, render(rows, lv, [f'{line[:1].upper()}{line[1:]}.']))
    print(line)


if __name__ == '__main__':
    main(sys.argv[1:])
