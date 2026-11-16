# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""tools/story_rows.py on small made-up tables, without the game's: the quest events read from a quest table block
(wrapped literals included), the zone a row's name gives, each scene rule (a theater path, a level sequence alone, Stop
rows, rows with no theater row or no path, the priority as the manager keeps it, the condition kept only beside
AddEvents, the quest flag, the order), the ambiguity counts, each trip rule (camp and spawn point targets, a ChangeZone,
no target, a test world by name and by target, the cut multiplayer warp) with every starter letter. Then the written
block: parsed back to the same values, lines within 116 columns, between its markers, the rest of the header
untouched, a name that cannot go into a C++ literal refused. Last, load and main over a folder of table exports.
Run: python3 tests/tools/story_rows_test.py"""
import ast
import contextlib
import importlib.util
import io
import json
import re
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
spec = importlib.util.spec_from_file_location('story_rows', ROOT / 'tools/story_rows.py')
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)

QUEST_BLOCK = '''// ---- quest table: generated, begin ----
constexpr Row kRows[] = {
    {1, "Quest_A", 'S', false, 1, "1", 0},
};
constexpr Step kSteps[] = {
    // Quest_A
    {'-', false, "", ""},
    {'t', false, "Zone_A_10 Zone_A_20", "A_10_E_Theater_001 "
        "A_10_E_Theater_002"},
    {'h', true, "", "Quest_A_E_Theater__017_001"},
};
constexpr Kill kKills[] = {
    {1, 0, 0, 0}, // "Not_A_Step"
};
// ---- quest table: generated, end ----
'''


def event(kind, alias='None', add=(), finish=(), condition='None', group='None'):
    return {'Type': f'ESBZoneEventType::ZoneEvent_{kind}', 'EventAlias': alias, 'AddEvents': list(add),
            'FinishEvents': list(finish), 'EventCondition': condition, 'EventConditionGroup': group}


def theater(path='', seq='', priority=-1, stop=False):
    return {'TheaterAssetPath': path, 'LevelSeqAssetPath': seq, 'Priority': priority,
            'ControlType': f'ESBZoneEventTheaterType::ZoneEvent_Theater_{"Stop" if stop else "Play"}'}


def warp(world='Xion', camp='None', point='None'):
    return {'TargetWorld': world, 'TargetZoneCamp': camp, 'TargetSpawnPoint': point}


def tables(events, theaters=None, warps=None, zones=('Zone_A_10', 'Zone_DED10'), triggers=None, transitions=(),
           quests=None, groups=None, tasks=None, spawns=None, envs=None):
    return {'ZoneEventTable': events, 'EventTheaterTable': theaters or {}, 'EventZoneWarpTable': warps or {},
            'ZoneTable': {z: {f: [] for f in ('EnterEvents', 'LeaveEvents', 'ActiveEvents', 'DeactiveEvents',
                                              'ZoneSpawnEvents')} for z in zones},
            'ZoneTriggerTable': {k: {'TouchEvents': v, 'LeaveEvents': []} for k, v in (triggers or {}).items()},
            'WorldTransitionTable': {f'WT_{i}': {'ZoneEventAlias': a} for i, a in enumerate(transitions)},
            'QuestTable': {k: {'AcquireEventArray': v, 'CompleteEventArray': []} for k, v in (quests or {}).items()},
            'QuestTaskGroupTable': {k: {'ActivateEvent': [], 'ProgressEvent': [], 'CompleteEvent': v}
                                    for k, v in (groups or {}).items()},
            'QuestTaskTable': {k: {'TaskStartEventSpawnAliasList': v, 'TaskCompleteEventSpawnAliasList': [],
                                   'TaskProgressEventSpawnAliasList': []} for k, v in (tasks or {}).items()},
            'ZoneEnvSpawnTable': {k: {f'TagEventList{n}': v if n == 1 else [] for n in range(1, 11)}
                                  for k, v in (spawns or {}).items()},
            'ZoneEnvTable': {k: {'StateEffectList': [{'EffectList': v}], 'StateZoneEventList': [{'ZoneEventList': []}]}
                             for k, v in (envs or {}).items()}}


def test_quest_events():
    assert gen.quest_events(f'// top\n{QUEST_BLOCK}// bottom\n') == {'A_10_E_Theater_001', 'A_10_E_Theater_002',
                                                                     'Quest_A_E_Theater__017_001'}


def test_zone_of():
    t = tables({}, zones=('Zone_Xion_10', 'Zone_DED10', 'Zone_SE_01'))
    assert gen.zone_of(t, 'Xion_10_E_Theater_029') == 'Zone_Xion_10'
    assert gen.zone_of(t, 'DED10_E_Theater_001') == 'Zone_DED10' and gen.zone_of(t, 'SE01_ZoneE_004') == 'Zone_SE_01'
    assert gen.zone_of(t, 'Quest_Sub_030_E_Theater__017_001') == '' and gen.zone_of(t, 'Xion_11_E_Theater_001') == ''


def scene_tables():
    return tables({'A_10_E_Theater_002': event('Theater', 'th b', finish=['A_10_E_Warp_001', 'A_10_E_Ui_001'],
                                               add=['A_10_E_Env_001'], condition='Cond_1'),
                   'A_10_E_Theater_001': event('Theater', 'th a', add=['A_10_E_Env_002']),
                   'DED10_E_Theater_001': event('Theater', 'th a'),
                   'Quest_A_E_Theater__017_001': event('Theater', 'th seq', condition='Cond_2'),
                   'A_10_E_Theater_003': event('Theater', 'th stop'), 'A_10_E_Theater_004': event('Theater', 'gone'),
                   'A_10_E_Theater_005': event('Theater', 'th empty'), 'A_10_E_Warp_001': event('PlayerWarp', 'w'),
                   'A_10_E_Theater_006': event('Theater', 'th high', group='Group_1', add=['A_10_E_Env_003'])},
                  {'th a': theater('/Game/T/B.B', '/Game/S/Ignored.Ignored'),
                   'th b': theater('/Game/T/A.A', priority=-1), 'th seq': theater(seq='/Game/S/Q.Q', priority=0),
                   'th stop': theater('/Game/T/A.A', stop=True), 'th empty': theater(),
                   'th high': theater('/Game/T/B.B', priority=10)})


def test_scenes():
    out = gen.scenes(scene_tables(), {'Quest_A_E_Theater__017_001'})
    assert [s['row'] for s in out] == ['Quest_A_E_Theater__017_001', 'A_10_E_Theater_002', 'A_10_E_Theater_001',
                                       'DED10_E_Theater_001', 'A_10_E_Theater_006']
    seq, first, a, ded, high = out
    assert first == {'path': '/Game/T/A.A', 'row': 'A_10_E_Theater_002', 'zone': 'Zone_A_10',
                     'finish': 'A_10_E_Warp_001 A_10_E_Ui_001', 'condition': 'Cond_1', 'group': '', 'priority': 0,
                     'sequence': False, 'quest': False}
    assert a['path'] == ded['path'] == '/Game/T/B.B' and a['condition'] == a['group'] == ''
    assert ded['zone'] == 'Zone_DED10'
    assert high['priority'] == 10 and high['condition'] == '' and high['group'] == 'Group_1'
    # A level sequence alone; its condition has no AddEvents beside it, so it is not kept.
    assert seq['sequence'] and seq['quest'] and seq['path'] == '/Game/S/Q.Q' and seq['zone'] == seq['condition'] == ''


def test_ambiguity():
    t = tables({f'{z}_E_Theater_00{i}': event('Theater', 'same', finish=['End'] if i == 3 else [])
                for z in ('A_10', 'DED10') for i in (1, 2, 3)} | {'A_10_E_Theater_009': event('Theater', 'alone')},
               {'same': theater('/Game/T/Same.Same'), 'alone': theater('/Game/T/Alone.Alone')})
    paths, zoned, equal = gen.ambiguity(gen.scenes(t, {'DED10_E_Theater_002'}))
    assert paths == 1 and zoned == 1 and [len(v) for v in equal.values()] == [4, 2]


def test_trips():
    t = tables({'A_10_E_ZoneWarp_001': event('PlayerWarp', 'A_10_E_ZoneWarp_001'),
                'A_10_E_ZoneWarp_002': event('PlayerWarp', 'A_10_E_ZoneWarp_002'),
                'A_10_ZoneE_003': event('ChangeZone', 'Zone_A_20'),
                'A_10_E_ZoneWarp_004': event('PlayerWarp', 'No_Warp_Row'),
                'LV_Test_A_E_ZoneWarp_001': event('PlayerWarp', 'LV_Test_A_E_ZoneWarp_001'),
                'A_10_E_ZoneWarp_005': event('PlayerWarp', 'A_10_E_ZoneWarp_005'),
                'A_10_E_ZoneWarp_006': event('PlayerWarp', 'A_10_E_ZoneWarp_006'),
                'A_10_E_Theater_001': event('Theater', 'th', finish=['A_10_E_ZoneWarp_002'], add=['A_10_ZoneE_003']),
                'A_10_E_ObjectC_001': event('ZoneObjControl', add=['A_10_E_ZoneWarp_006'])},
               warps={'A_10_E_ZoneWarp_001': warp('WasteLandA', camp='WLA10_Camp_04_SV', point='Ignored'),
                      'A_10_E_ZoneWarp_002': warp('None', point='TeleportPoint_Lift'),
                      'LV_Test_A_E_ZoneWarp_001': warp(), 'A_10_E_ZoneWarp_005': warp('LV_Test_Tetrapod'),
                      'A_10_E_ZoneWarp_006': warp(point='TeleportPoint_Xion_MultiPlay')},
               triggers={'Trigger': ['A_10_ZoneE_003']}, transitions=['A_10_ZoneE_003'])
    out, left = gen.trips(t)
    assert out == [{'row': 'A_10_E_ZoneWarp_001', 'target': 'WasteLandA WLA10_Camp_04_SV', 'starters': 'g'},
                   {'row': 'A_10_E_ZoneWarp_002', 'target': 'None TeleportPoint_Lift', 'starters': 't'},
                   {'row': 'A_10_ZoneE_003', 'target': 'Zone_A_20', 'starters': 'tzw'}]
    assert left == {'no target': 1, 'test world': 2, 'multiplayer': 1}
    # Every source, one letter each, in STARTERS order whatever the order found.
    t = tables({'X': event('UIAction', add=['R']), 'Y': event('Theater', finish=['R'])},
               triggers={'Tr': ['R']}, transitions=['R'], quests={'Q': ['R']}, groups={'G': ['R']}, tasks={'T': ['R']},
               spawns={'S': ['R']}, envs={'E': ['R']})
    t['ZoneTable']['Zone_A_10']['LeaveEvents'] = ['R']
    assert gen.starters(t)['R'] == gen.STARTERS


def unrender(block, name):
    """The entries of a generated C++ list, parsed back into tuples."""
    body = block[block.index(f'{name}[] = {{') + len(name) + 6:]
    body = body[:body.index('\n};')]
    body = re.sub(r'"\s*\n\s*"', '', body)  # Adjacent literals.
    body = body.replace('{', '(').replace('}', ')').replace('true', 'True').replace('false', 'False')
    return ast.literal_eval(f'[{body}]')


def test_render_and_write():
    entries = gen.scenes(scene_tables(), set())
    long = dict(entries[0], path='/Game/' + 'Folder/' * 30 + 'Asset.Asset',
                finish=' '.join(f'A_10_E_Event_{i:03}' for i in range(12)))
    entries.append(long)
    trips = [{'row': 'A_10_E_ZoneWarp_001', 'target': 'WasteLandA WLA10_Camp_04_SV', 'starters': 'g'}]
    block = gen.render(entries, trips, ['Count line.'])
    assert block.startswith(gen.BEGIN + '\n') and block.endswith('\n' + gen.END) and '// Count line.' in block
    assert all(len(line) <= 120 for line in block.split('\n'))
    assert all(len(line) <= 116 for line in block.split('\n') if not line.startswith('//'))
    keys = ('path', 'row', 'zone', 'finish', 'condition', 'group', 'priority', 'sequence', 'quest')
    assert unrender(block, 'kScenes') == [tuple(s[k] for k in keys) for s in entries]
    assert unrender(block, 'kTrips') == [('A_10_E_ZoneWarp_001', 'WasteLandA WLA10_Camp_04_SV', 'g')]
    for bad in ({'row': 'A b'}, {'zone': 'A"b'}, {'finish': 'A;b'}, {'path': '/Game/A B.A'}):
        try:
            gen.render([dict(entries[0], **bad)], trips, [])
            assert False, bad
        except ValueError as e:
            assert 'C++ string literal' in str(e)
    for empty in (([], trips), (entries, [])):
        try:
            gen.render(*empty, [])
            assert False
        except ValueError as e:
            assert 'zero-size' in str(e)
    with tempfile.TemporaryDirectory() as tmp:
        header = Path(tmp) / 'rows.h'
        header.write_text(f'// top\n{gen.BEGIN}\nold\n{gen.END}\n// bottom\n')
        gen.write(header, block)
        assert header.read_text() == f'// top\n{block}\n// bottom\n'


def test_load_and_main():
    t = scene_tables()
    t['EventZoneWarpTable'] = {'w': warp(point='Spot')}
    with tempfile.TemporaryDirectory() as tmp:
        for name in gen.TABLES:
            other = {'Type': 'Package'}  # An export without rows, before the table's.
            (Path(tmp) / f'{name}.uasset.json').write_text(json.dumps([other, {'Name': name, 'Rows': t[name]}]))
        assert gen.load(tmp) == t
        header, quests = Path(tmp) / 'rows.h', Path(tmp) / 'sync.h'
        header.write_text(f'{gen.BEGIN}\n{gen.END}\n')
        quests.write_text(QUEST_BLOCK)
        saved = gen.HEADER, gen.QUESTS
        gen.HEADER, gen.QUESTS = header, quests
        try:
            with contextlib.redirect_stdout(io.StringIO()) as out:
                gen.main([tmp])
        finally:
            gen.HEADER, gen.QUESTS = saved
        lines = out.getvalue().split('\n')
        assert lines[0] == ('Scenes: 5 rows over 3 paths, 1 of them a level sequence alone, 3 run by a shared quest '
                            'step.')
        assert lines[1] == ('Still ambiguous after the filters: 1 paths keep rows equal in priority and FinishEvents, '
                            '0 of them with the same zone; 1 rows after the first of such a group differ from it in '
                            'AddEvents, condition or quest flag.')
        assert lines[2] == 'Theater rows with both a ZoneEventTable condition and AddEvents: 2.'
        assert lines[3] == 'Trips: 1 rows, 0 started by no table (sent); left out: none.'
        text = header.read_text()
        assert '"A_10_E_Warp_001", "Xion Spot", "t"' in text and text.count(gen.BEGIN) == 1


for name, test in list(globals().items()):
    if name.startswith('test_'):
        test()
print('story_rows_test: ok')
