#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""Writes the generated block of native/src/world/rows.h from a game build's tables: what shared world sync may send
and apply. It reads the tables only.

  python3 -I tools/world_rows.py JSON_DIR   JSON_DIR holds the <Table>.uasset.json exports of the pinned build

The block holds three sorted lists: the (EnvSpawnAlias, state tag) pairs a ChangeEnvState root may carry, the
EnvSpawnAliases a SetEnvActive root may carry, and the ZoneEventTable rows a ZoneEvent root may run.

A ZoneEnvSpawnTable row is out, all its states with it, when it is per player (its EnvAlias family, the boss cores
whose graph gives the item included, an EnvType Camp, Can or Nikke, an EnvCrate scan type, a box or record trophy on
it), belongs to a camp (a TargetCamp, a camp object
type, an Env_Camp_ or Env_SaveCamp alias), has a reward group on any state (State_RewardGroupN, or its ZoneEnvTable
row's StateRewardGroupList), has no ZoneEnvTable row (no states to name), or is story driven: the target of an
EventEnvControlTable row that a quest's acquire or complete events, its task groups' events or its tasks' event
aliases reach, through chained rows and the states those rows set.

A state of a kept row is out when it is ResetCam or ChangeCam (the crane's camera states), or when the zone events
ChangeState runs for it, followed through AddEvents, FinishEvents and the events of every state an env control row
among them sets, reach a type that acts on the player, her items or her story (PLAYER_EVENTS), or when that state, or
one an env control row among them sets, has a ChangeState achievement: ChangeState credits it to the caster, and the
receiver applies with her own player as caster. A row goes on the
SetEnvActive list only when every one of its states is kept, so a forwarded Disable never locks a lever whose state
change stayed local. A ZoneEvent row is kept when it and every row it chains to are env control rows, none names a
camp, each names a kept row, every tag it can set (its TagName, and for a progress control its env's progress change
tags) is a kept pair, and each Disable is on an env of the SetEnvActive list.
"""
import json
import re
import sys
import textwrap
from collections import Counter, deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEADER = ROOT / 'native/src/world/rows.h'
BUILD = '26123051'  # The build whose tables the block is written from; change it with the tables.
BEGIN = '// ---- world rows: generated, begin ----'
END = '// ---- world rows: generated, end ----'
TABLES = ('ZoneEnvSpawnTable', 'ZoneEnvTable', 'ZoneEventTable', 'EventEnvControlTable', 'QuestTable',
          'QuestTaskGroupTable', 'QuestTaskTable', 'AchievementTable')

# Loot, records and collectibles, by EnvAlias family; the reward test misses cabinets, chargers, angel remains and the
# boss cores (Env_Alphacore: the Beta core and the Burst core, which their interaction graphs give).
FAMILY = re.compile(r'Env_(SupplyBox|Cabinet|RecordsObject|MemoryStick|RobotObject|Corpse_|AngelRemains_|BulletCharger'
                    r'|Can|Car_Interaction|Car_FusionCell|Passcode_Hint|VendingMachine_NewsPaper'
                    r'|VendingMachine_Fake_Can|LostItem_|Alphacore)')
TYPES = {'ESBENV_Camp', 'ESBENV_Can', 'ESBENV_NikkeDefenseArea', 'ESBENV_NikkeLostGoods_Normal',
         'ESBENV_NikkeLostGoods_Request'}
TROPHIES = {'Trophy_Open_AllBox', 'Trophy_Acquire_AllRecords'}
CAMP = re.compile(r'Env_(Camp_|SaveCamp)')
# Zone event types that move the player (PlayerWarp, ChangeZone), play a scene, the UI or a hint on her screen, change
# her items, her quests, her camps or her boss challenge, or her session.
PLAYER_EVENTS = {'Theater', 'UIAction', 'GuideAction', 'CompleteHint', 'ActivateHint', 'Item', 'AcquireQuest',
                 'InteractCamp', 'FinishBossChallenge', 'PlayerWarp', 'ChangeZone', 'ItemAction', 'StartMatchMaking',
                 'StopMatchMaking', 'ReturnToSinglePlay'}
CAMERA = {'ResetCam', 'ChangeCam'}
ENV_CONTROL = 'ZoneEnvControl'
STATE_CONTROL = {'ESBZoneEnvCtrlType_BaseState'}  # Every other control type but a camp's may move progress.
CAMP_CONTROL = 'ESBZoneEnvCtrlType_CampProperty'
QUEST_EVENTS = (('QuestTable', ('AcquireEventArray', 'CompleteEventArray')),
                ('QuestTaskGroupTable', ('ActivateEvent', 'ProgressEvent', 'CompleteEvent')),
                ('QuestTaskTable', ('TaskStartEventSpawnAliasList', 'TaskCompleteEventSpawnAliasList',
                                    'TaskProgressEventSpawnAliasList')))
NAME = re.compile(r'[A-Za-z0-9_\-]+')  # What a name may hold to go into a C++ string literal and sort as in C++.


def enum(value):
    """An enum value without its type: 'ESBEnvironmentType::ESBENV_Can' gives 'ESBENV_Can'."""
    return value.split('::')[-1]


def kind(row):
    """A ZoneEventTable row's type: 'ESBZoneEventType::ZoneEvent_Theater' gives 'Theater'."""
    return enum(row['Type']).removeprefix('ZoneEvent_')


def load(folder):
    """Each table of TABLES: its rows by name, from <folder>/<Table>.uasset.json."""
    out = {}
    for name in TABLES:
        data = json.loads((Path(folder) / f'{name}.uasset.json').read_text())
        out[name] = next(e['Rows'] for e in data if 'Rows' in e)
    return out


def env_row(t, alias):
    """The ZoneEnvTable row of a ZoneEnvSpawnTable row, or None."""
    return t['ZoneEnvTable'].get(t['ZoneEnvSpawnTable'][alias]['EnvAlias'])


def states(t, alias):
    """The state tags of an env, as the game builds them from its ZoneEnvTable row."""
    env = env_row(t, alias)
    return list(dict.fromkeys(x for x in env['StateTagNameList'] if x != 'None')) if env else []


def state_events(t, alias, tag):
    """The zone event rows ChangeState runs for a state: the spawn row's TagEventListN of that tag, else the env row's
    StateEffectList entry, and the env row's StateZoneEventList entry (run when there is a caster, as on apply)."""
    spawn = t['ZoneEnvSpawnTable'].get(alias)
    env = env_row(t, alias) if spawn else None
    if not env or tag not in env['StateTagNameList']:
        return []
    i = env['StateTagNameList'].index(tag)
    tagged = [e for n in range(1, 11) if spawn[f'EventTagName{n}'] == tag for e in spawn[f'TagEventList{n}']]
    effects = env['StateEffectList'][i]['EffectList'] if i < len(env['StateEffectList']) else []
    zone = env['StateZoneEventList'][i]['ZoneEventList'] if i < len(env['StateZoneEventList']) else []
    return (tagged or effects) + zone


def control_tags(t, control):
    """The tags an EventEnvControlTable row can put its env in: its TagName, and for a progress control the tags its
    env's states move to at their progress count."""
    tags = [control['TagName']] if control['TagName'] != 'None' else []
    if enum(control['EnvControlType']) not in STATE_CONTROL and control['EnvSpawnAlias'] in t['ZoneEnvSpawnTable']:
        env = env_row(t, control['EnvSpawnAlias'])
        tags += [x for x in env['StateProgressChangeTagNameList'] if x != 'None'] if env else []
    return tags


def walk(t, start, cascade=True):
    """The zone event rows running start reaches, each once, as (name, row): their AddEvents and FinishEvents and, with
    cascade, the events of each state an env control row among them sets, which ChangeState runs in the same world.
    Names with no row are skipped, as the game's row lookup skips them."""
    rows, controls = t['ZoneEventTable'], t['EventEnvControlTable']
    seen, todo = set(), deque(start)
    while todo:
        name = todo.popleft()
        if name in seen or name not in rows:
            continue
        seen.add(name)
        row = rows[name]
        yield name, row
        todo.extend(row['AddEvents'])
        todo.extend(row['FinishEvents'])
        control = controls.get(row['EventAlias']) if kind(row) == ENV_CONTROL else None
        if cascade and control:
            for tag in control_tags(t, control):
                todo.extend(state_events(t, control['EnvSpawnAlias'], tag))


def story_aliases(t):
    """The envs a quest's events move: targets of the env control rows its events reach."""
    start = [e for table, fields in QUEST_EVENTS for r in t[table].values() for f in fields for e in r[f]]
    controls = t['EventEnvControlTable']
    return {controls[row['EventAlias']]['EnvSpawnAlias'] for _, row in walk(t, start)
            if kind(row) == ENV_CONTROL and row['EventAlias'] in controls} - {'None'}


def change_state_achievements(t):
    """The ChangeState achievements by (EnvSpawnAlias, tag): the tag None when the row names no state."""
    out = set()
    for r in t['AchievementTable'].values():
        if enum(r['EventType']) != 'ESBAchievementEventType_ChangeState':
            continue
        params = [(enum(r[f'ParamType{n}']), r[f'ParamValue{n}']) for n in range(1, 5)]
        tags = [v for k, v in params if k == 'ESBAchievementParamType_EnvState'] or [None]
        out |= {(v, tag) for k, v in params if k == 'ESBAchievementParamType_ZoneEnvSpawnAlias' for tag in tags}
    return out


def trophy_aliases(t):
    """The envs a ChangeState achievement counts for the box or record trophy."""
    out = set()
    for r in t['AchievementTable'].values():
        progress = {r['ProgressAchievementOnCompleted'], r['ProgressAchievementOnCompleted2'],
                    *r['ProgressAchievementArrayOnCompleted']}
        if enum(r['EventType']) == 'ESBAchievementEventType_ChangeState' and progress & TROPHIES:
            out |= {r[f'ParamValue{n}'] for n in range(1, 5)
                    if enum(r[f'ParamType{n}']) == 'ESBAchievementParamType_ZoneEnvSpawnAlias'}
    return out


def row_reasons(t, alias, story, trophy):
    """Why a ZoneEnvSpawnTable row is out, all its states with it; empty when it is kept."""
    spawn, env = t['ZoneEnvSpawnTable'][alias], env_row(t, alias)
    rewards = [spawn[f'State_RewardGroup{n}'] for n in range(1, 11)] + (env['StateRewardGroupList'] if env else [])
    why = {'family': bool(FAMILY.match(spawn['EnvAlias'])),
           'no env row': env is None,
           'type': bool(env) and enum(env['EnvType']) in TYPES,
           'crate': bool(env) and enum(env['ScanDisplayType']) == 'ESBScanDisplayType_EnvCrate',
           'camp': spawn['TargetCamp'] != 'None' or bool(CAMP.match(spawn['EnvAlias']))
                   or bool(env) and enum(env['CampObjectType']) != 'ESBZoneCampObjectType_None',
           'reward': any(x != 'None' for x in rewards),
           'trophy': alias in trophy,
           'story': alias in story}
    return [k for k, v in why.items() if v]


def state_reasons(t, alias, tag, credits=None):
    """Why a state of a kept row is out: 'camera', the player event types its events reach, or 'achievement'; empty
    when kept. credits: change_state_achievements(t), made when not given."""
    if tag in CAMERA:
        return ['camera']
    credits = change_state_achievements(t) if credits is None else credits
    controls = t['EventEnvControlTable']
    rows = [row for _, row in walk(t, state_events(t, alias, tag))]
    why = {kind(row) for row in rows} & PLAYER_EVENTS
    sets = [(alias, tag)] + [(c['EnvSpawnAlias'], x) for row in rows if kind(row) == ENV_CONTROL
                             for c in [controls.get(row['EventAlias'])] if c for x in control_tags(t, c)]
    if any(p in credits or (p[0], None) in credits for p in sets):
        why.add('achievement')
    return sorted(why)


def event_reason(t, name, pairs, kept, active):
    """Why a ZoneEvent root row is out, or None when it is kept: pairs, kept and active are build()'s sets."""
    controls = t['EventEnvControlTable']
    for _, row in walk(t, [name], cascade=False):
        if kind(row) != ENV_CONTROL:
            return 'chain'
        control = controls.get(row['EventAlias'])
        if control is None:
            return 'no control row'
        if enum(control['EnvControlType']) == CAMP_CONTROL or control['TargetCamp'] != 'None':
            return 'camp'
        alias = control['EnvSpawnAlias']
        if alias not in kept or any((alias, tag) not in pairs for tag in control_tags(t, control)):
            return 'target'
        # An Enable runs the same row in both worlds and cannot lock anything; a Disable is held to the list.
        if enum(control['Activate']) == 'ESBObject_Disable' and alias not in active:
            return 'disable'
    return None


def build(t):
    """(pairs, SetEnvActive aliases, ZoneEvent rows, counts): the lists sorted, counts a Counter per list of reasons;
    a row or state counts under each reason it meets."""
    story, trophy, credits = story_aliases(t), trophy_aliases(t), change_state_achievements(t)
    counts = {'rows': Counter(), 'states': Counter(), 'events': Counter()}
    pairs, active = [], []
    for alias in t['ZoneEnvSpawnTable']:
        why = row_reasons(t, alias, story, trophy)
        counts['rows'].update(why or ['kept'])
        if why:
            continue
        tags = states(t, alias)
        ok = []
        for tag in tags:
            why = state_reasons(t, alias, tag, credits)
            counts['states'].update(why or ['kept'])
            if not why:
                ok.append(tag)
        pairs += [(alias, tag) for tag in ok]
        if ok and len(ok) == len(tags):
            active.append(alias)
    events = []
    pair_set, kept, active_set = set(pairs), {a for a, _ in pairs}, set(active)
    for name, row in t['ZoneEventTable'].items():
        if kind(row) == ENV_CONTROL:
            why = event_reason(t, name, pair_set, kept, active_set)
            counts['events'][why or 'kept'] += 1
            if why is None:
                events.append(name)
    return sorted(pairs), sorted(active), sorted(events), counts


def tally(c):
    return ', '.join(f'{k} {n}' for k, n in sorted(c.items(), key=lambda kv: (kv[0] == 'kept', -kv[1], kv[0])))


def render(pairs, active, events, counts):
    """The generated block, its begin and end lines included."""
    bad = sorted(x for x in {x for p in pairs for x in p} | set(active) | set(events) if not NAME.fullmatch(x))
    if bad:
        raise ValueError(f'names that would not go into a C++ string literal as they are: {bad}')
    if not (pairs and active and events):
        raise ValueError('an empty list would make a zero-size C++ array')
    note = (f"Written by tools/world_rows.py from build {BUILD}'s {', '.join(TABLES[:-1])} and {TABLES[-1]}. "
            "Another build needs it written again from that build's tables. A row or state counts under each reason "
            'it meets.')
    out = [BEGIN,
           *(f'// {line}' for line in textwrap.wrap(note, 117)),
           *(f'// {line}' for line in textwrap.wrap(f'ZoneEnvSpawnTable rows: {tally(counts["rows"])}.', 117)),
           *(f'// {line}' for line in textwrap.wrap(f'States of kept rows: {tally(counts["states"])}.', 117)),
           *(f'// {line}' for line in textwrap.wrap(f'Env control ZoneEvent rows: {tally(counts["events"])}.', 117)),
           'constexpr Pair kPairs[] = {',
           *(f'    {{"{a}", "{s}"}},' for a, s in pairs),
           '};',
           'constexpr const char *kObjectState[] = {',
           *(f'    "{a}",' for a in active),
           '};',
           'constexpr const char *kEvents[] = {',
           *(f'    "{e}",' for e in events),
           '};',
           END]
    return '\n'.join(out)


def write(header, block):
    """Puts block in place of the generated block of header."""
    text = header.read_text()
    begin, end = text.index(BEGIN), text.index(END) + len(END)
    header.write_text(text[:begin] + block + text[end:])


def main(argv):
    if len(argv) != 1:
        sys.exit('Use: python3 -I tools/world_rows.py JSON_DIR')
    t = load(argv[0])
    pairs, active, events, counts = build(t)
    write(HEADER, render(pairs, active, events, counts))
    kept = {a for a, _ in pairs}
    families = Counter(t['ZoneEnvSpawnTable'][a]['EnvAlias'] for a in kept)
    total = Counter(r['EnvAlias'] for r in t['ZoneEnvSpawnTable'].values())
    print(f'{len(pairs)} pairs over {len(kept)} rows, {len(active)} SetEnvActive rows, {len(events)} ZoneEvent rows')
    for what, c in counts.items():
        print(f'{what}: {tally(c)}')
    print('kept rows per EnvAlias (kept/all): ' +
          ', '.join(f'{f} {families[f]}/{total[f]}' for f in sorted(total, key=lambda f: -total[f]) if families[f]))


if __name__ == '__main__':
    main(sys.argv[1:])
