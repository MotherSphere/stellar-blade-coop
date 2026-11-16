# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""tools/world_rows.py on small made-up tables, without the game's: each rule that keeps a ZoneEnvSpawnTable row out
(EnvAlias family, EnvType Camp, Can and Nikke, EnvCrate, TargetCamp, camp object types and aliases, reward groups on
the spawn row or the env row, a box trophy, a boss core, no env row, story envs reached from quest, task group and
task events through chains and the states they set), each that keeps a state out (every player event type, reached
directly, through AddEvents and FinishEvents, through the StateZoneEventList, through another env's state that an env
control row sets, and through a progress control's change tags; the crane's camera tags; a ChangeState achievement on
the state, on any state of its env, or on a state its events set), the SetEnvActive list (all states kept), each
ZoneEvent rule (chain, missing control row, camp, target pair, target row, progress tags, Disable), unknown names and
loops in chains, the envs whose progress count leads off the list, Matrix XIII's rows (copies, in-place changes,
numbered enums), and the written block: sorted, between its markers, the rest of the header untouched, a name that
cannot go into a C++ literal refused, and load and main over a folder of table exports.
Run: python3 tests/tools/world_rows_test.py"""
import contextlib
import importlib.util
import io
import json
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
spec = importlib.util.spec_from_file_location('world_rows', ROOT / 'tools/world_rows.py')
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)


def spawn(env='Env_EnvState_2Phase', camp='None', events=None, rewards=None):
    """A ZoneEnvSpawnTable row: events gives TagEventListN by state tag, rewards State_RewardGroupN by N."""
    row = {'EnvAlias': env, 'TargetCamp': camp}
    for n, (tag, names) in enumerate(list((events or {}).items()) + [('None', [])] * 10, 1):
        if n <= 10:
            row[f'EventTagName{n}'], row[f'TagEventList{n}'] = tag, list(names)
    for n in range(1, 11):
        row[f'State_RewardGroup{n}'] = (rewards or {}).get(n, 'None')
    return row


def env(states=('Off', 'On'), kind='ESBENV_Switch', scan='ESBScanDisplayType_None', rewards=None, camp='None',
        effects=None, zone=None, progress=None, counts=None):
    """A ZoneEnvTable row; effects, zone, progress and counts give a state's StateEffectList, StateZoneEventList,
    StateProgressChangeTagNameList and StateProgressCountList entries by tag."""
    return {'EnvType': f'ESBEnvironmentType::{kind}', 'StateTagNameList': list(states),
            'StateEffectList': [{'EffectList': (effects or {}).get(s, [])} for s in states],
            'StateZoneEventList': [{'ZoneEventList': (zone or {}).get(s, [])} for s in states],
            'StateRewardGroupList': [(rewards or {}).get(s, 'None') for s in states],
            'StateProgressChangeTagNameList': [(progress or {}).get(s, 'None') for s in states],
            'StateProgressCountList': [(counts or {}).get(s, 0) for s in states],
            'ScanDisplayType': f'ESBScanDisplayType::{scan}',
            'CampObjectType': f'ESBZoneCampObjectType::ESBZoneCampObjectType_{camp}'}


def event(kind, alias='None', add=(), finish=()):
    return {'Type': f'ESBZoneEventType::ZoneEvent_{kind}', 'EventAlias': alias, 'AddEvents': list(add),
            'FinishEvents': list(finish)}


def control(alias, tag='None', kind='BaseState', activate='Enable', camp='None'):
    return {'EnvSpawnAlias': alias, 'TagName': tag, 'TargetCamp': camp,
            'EnvControlType': f'ESBZoneEnvControlType::ESBZoneEnvCtrlType_{kind}',
            'Activate': f'ESBObjectState::ESBObject_{activate}'}


def achievement(alias, progress='None', field='ProgressAchievementOnCompleted', state='Open'):
    """A ChangeState achievement on alias in state (None: no state named)."""
    row = {'EventType': 'ESBAchievementEventType::ESBAchievementEventType_ChangeState',
           'ProgressAchievementOnCompleted': 'None', 'ProgressAchievementOnCompleted2': 'None',
           'ProgressAchievementArrayOnCompleted': []}
    for n in range(1, 5):
        row[f'ParamType{n}'], row[f'ParamValue{n}'] = 'ESBAchievementParamType::ESBAchievementParamType_None', ''
    row['ParamType1'], row['ParamValue1'] = 'ESBAchievementParamType::ESBAchievementParamType_ZoneEnvSpawnAlias', alias
    if state:
        row['ParamType2'], row['ParamValue2'] = 'ESBAchievementParamType::ESBAchievementParamType_EnvState', state
    row[field] = [progress] if field == 'ProgressAchievementArrayOnCompleted' else progress
    return row


def world(spawns, envs=None, events=None, controls=None, quests=None, groups=None, tasks=None, achievements=None):
    """The tables build() reads. An env row named after each spawn row's EnvAlias defaults to env()."""
    envs = dict(envs or {})
    for s in spawns.values():
        envs.setdefault(s['EnvAlias'], env())
    return {'ZoneEnvSpawnTable': spawns, 'ZoneEnvTable': envs, 'ZoneEventTable': events or {},
            'EventEnvControlTable': controls or {},
            'QuestTable': {k: {'AcquireEventArray': v, 'CompleteEventArray': []} for k, v in (quests or {}).items()},
            'QuestTaskGroupTable': {k: {'ActivateEvent': [], 'ProgressEvent': [], 'CompleteEvent': v}
                                    for k, v in (groups or {}).items()},
            'QuestTaskTable': {k: {'TaskStartEventSpawnAliasList': v, 'TaskCompleteEventSpawnAliasList': [],
                                   'TaskProgressEventSpawnAliasList': []} for k, v in (tasks or {}).items()},
            'AchievementTable': achievements or {}}


def reasons(t, alias):
    return gen.row_reasons(t, alias, gen.story_aliases(t), gen.trophy_aliases(t))


def test_row_rules():
    t = world({'lever': spawn(), 'box': spawn('Env_SupplyBox_Normal01'), 'remains': spawn('Env_AngelRemains_BodyCore'),
               'core': spawn('Env_Alphacore'),
               'can': spawn('Env_Thing_Can'), 'camp': spawn('Env_Thing_Camp'), 'nikke': spawn('Env_Thing_Nikke'),
               'crate': spawn('Env_Thing_Crate'), 'target camp': spawn(camp='Camp_01'),
               'chair': spawn('Env_Camp_Chair'), 'save': spawn('Env_SaveCamp'), 'disc': spawn('Env_Thing_Turntable'),
               'gift': spawn(rewards={2: 'Gift'}), 'chest': spawn('Env_Thing_Chest'), 'trophy': spawn(),
               'other trophy': spawn(), 'array trophy': spawn(), 'orphan': spawn('Env_Missing')},
              envs={'Env_Thing_Can': env(kind='ESBENV_Can'), 'Env_Thing_Camp': env(kind='ESBENV_Camp'),
                    'Env_Thing_Nikke': env(kind='ESBENV_NikkeLostGoods_Normal'),
                    'Env_Thing_Crate': env(scan='ESBScanDisplayType_EnvCrate'),
                    'Env_Thing_Turntable': env(camp='Turntable'), 'Env_Thing_Chest': env(rewards={'On': 'Loot'})},
              achievements={'a': achievement('trophy', 'Trophy_Open_AllBox'),
                            'b': achievement('other trophy', 'Trophy_Platinum'),
                            'c': achievement('array trophy', 'Trophy_Acquire_AllRecords',
                                             'ProgressAchievementArrayOnCompleted')})
    del t['ZoneEnvTable']['Env_Missing']
    want = {'lever': [], 'box': ['family'], 'remains': ['family'], 'core': ['family'], 'can': ['type'],
            'camp': ['type'], 'nikke': ['type'], 'crate': ['crate'], 'target camp': ['camp'], 'chair': ['camp'],
            'save': ['camp'], 'disc': ['camp'], 'gift': ['reward'], 'chest': ['reward'], 'trophy': ['trophy'],
            'other trophy': [], 'array trophy': ['trophy'], 'orphan': ['no env row']}
    assert {a: reasons(t, a) for a in want} == want
    pairs, active, events, counts = gen.build(t)
    assert pairs == [(a, s) for a in ('lever', 'other trophy') for s in ('Off', 'On')]
    assert active == ['lever', 'other trophy']
    assert counts['rows']['kept'] == 2 and counts['rows']['camp'] == 4 and counts['rows']['type'] == 3


def test_story():
    t = world({'quest door': spawn(), 'lever': spawn(events={'On': ['set door']}), 'door': spawn(),
               'group door': spawn(), 'task door': spawn(), 'free': spawn()},
              events={'acquire': event('Theater', add=['set quest door', 'Quest_Name']),
                      'set quest door': event('ZoneEnvControl', 'c quest door'),
                      'set lever': event('ZoneEnvControl', 'c lever'), 'set door': event('ZoneEnvControl', 'c door'),
                      'group end': event('PlayLevelSeq', finish=['set group door']),
                      'set group door': event('ZoneEnvControl', 'c group door'),
                      'task spawn': event('Spawn', add=['set task door']),
                      'set task door': event('ZoneEnvControl', 'c task door'),
                      'free switch': event('ZoneEnvControl', 'c free')},
              controls={'c quest door': control('quest door', 'On'), 'c lever': control('lever', 'On'),
                        'c door': control('door', 'On'), 'c group door': control('group door', 'On'),
                        'c task door': control('task door', 'On'), 'c free': control('free', 'On')},
              quests={'Quest_Name': ['acquire', 'set lever']}, groups={'g': ['group end']},
              tasks={'t': ['task spawn', 'Some_E_CharS_001']})
    # The lever's On runs set door: the door moves with the quest too.
    assert gen.story_aliases(t) == {'quest door', 'lever', 'door', 'group door', 'task door'}
    assert reasons(t, 'door') == ['story'] and reasons(t, 'free') == []
    pairs, _, events, _ = gen.build(t)
    assert {a for a, _ in pairs} == {'free'} and events == ['free switch']


def test_player_events():
    assert gen.PLAYER_EVENTS == {'Theater', 'UIAction', 'GuideAction', 'CompleteHint', 'ActivateHint', 'Item',
                                 'AcquireQuest', 'InteractCamp', 'FinishBossChallenge', 'PlayerWarp', 'ChangeZone',
                                 'ItemAction', 'StartMatchMaking', 'StopMatchMaking', 'ReturnToSinglePlay'}
    for kind in sorted(gen.PLAYER_EVENTS):
        t = world({'lever': spawn(events={'On': ['shown']})}, events={'shown': event(kind)})
        assert gen.state_reasons(t, 'lever', 'On') == [kind] and gen.state_reasons(t, 'lever', 'Off') == []
    for kind in ('Spawn', 'Despawn', 'PlayLevelSeq', 'LaserControl', 'ZoneObjControl'):
        t = world({'lever': spawn(events={'On': ['shown']})}, events={'shown': event(kind)})
        assert gen.state_reasons(t, 'lever', 'On') == []
    t = world({'lever': spawn(events={'On': ['set door'], 'Off': ['seq']}), 'door': spawn(events={'On': ['warp']}),
               'counter': spawn('Env_Count'), 'add': spawn(events={'On': ['add one']}), 'zone': spawn('Env_Zone'),
               'effect': spawn('Env_Effect'), 'crane': spawn('Env_Crane'), 'gate': spawn(events={'On': ['loop a']})},
              envs={'Env_Count': env(('Off', 'Full'), progress={'Off': 'Full'}, effects={'Full': ['hint']}),
                    'Env_Zone': env(zone={'On': ['hint']}), 'Env_Effect': env(effects={'On': ['ui']}),
                    'Env_Crane': env(('Off', 'On', 'ResetCam', 'ChangeCam'))},
              events={'set door': event('ZoneEnvControl', 'c door', finish=['done']), 'done': event('PlayLevelSeq'),
                      'warp': event('PlayerWarp'), 'seq': event('PlayLevelSeq', add=['later']),
                      'later': event('UIAction'), 'add one': event('ZoneEnvControl', 'c add'),
                      'hint': event('CompleteHint'), 'ui': event('UIAction'), 'loop a': event('Spawn', add=['loop b']),
                      'loop b': event('Spawn', add=['loop a', 'Not_A_Row'])},
              controls={'c door': control('door', 'On'), 'c add': control('counter', kind='StateProgress')})
    assert gen.state_reasons(t, 'door', 'On') == ['PlayerWarp']
    assert gen.state_reasons(t, 'lever', 'On') == ['PlayerWarp']  # Through the door it opens.
    assert gen.state_reasons(t, 'lever', 'Off') == ['UIAction']  # Through AddEvents.
    assert gen.state_reasons(t, 'add', 'On') == ['CompleteHint']  # The counter's Full, at its count.
    assert gen.state_reasons(t, 'zone', 'On') == ['CompleteHint']  # StateZoneEventList.
    assert gen.state_reasons(t, 'effect', 'On') == ['UIAction']  # StateEffectList, with no TagEventList for On.
    assert gen.state_reasons(t, 'crane', 'ResetCam') == ['camera'] == gen.state_reasons(t, 'crane', 'ChangeCam')
    assert gen.state_reasons(t, 'gate', 'On') == []  # A loop and a name with no row end the walk.
    pairs, active, _, counts = gen.build(t)
    assert ('crane', 'On') in pairs and ('crane', 'ResetCam') not in pairs and 'crane' not in active
    assert ('lever', 'Off') not in pairs and 'lever' not in active and 'gate' in active
    assert counts['states']['camera'] == 2 and counts['states']['PlayerWarp'] == 2


def test_achievements():
    # The hyperdrive's A credits a story flag, the door's Open a map entry, and the console has one on every state;
    # the lever opens the door, and the counter's progress moves it to its credited Full.
    t = world({'drive': spawn('Env_Drive'), 'door': spawn('Env_Door'), 'console': spawn(),
               'lever': spawn(events={'On': ['open door']}), 'add': spawn(events={'On': ['add one']}),
               'counter': spawn('Env_Count'), 'free': spawn()},
              envs={'Env_Drive': env(('A', 'B', 'C', 'Off')), 'Env_Door': env(('Closed', 'Open')),
                    'Env_Count': env(('Off', 'Full'), progress={'Off': 'Full'})},
              events={'open door': event('ZoneEnvControl', 'c open', finish=['done']), 'done': event('PlayLevelSeq'),
                      'add one': event('ZoneEnvControl', 'c add'), 'set A': event('ZoneEnvControl', 'c drive'),
                      'set C': event('ZoneEnvControl', 'c drive C')},
              controls={'c open': control('door', 'Open'), 'c add': control('counter', kind='StateProgress'),
                        'c drive': control('drive', 'A'), 'c drive C': control('drive', 'C')},
              achievements={'Phase_2': achievement('drive', state='A'), 'Map_Door': achievement('door'),
                            'Any': achievement('console', state=None), 'Full': achievement('counter', state='Full'),
                            'Not_An_Env': achievement('Area_E_EnvC_001', state='On')})
    assert gen.change_state_achievements(t) == {('drive', 'A'), ('door', 'Open'), ('console', None),
                                                ('counter', 'Full'), ('Area_E_EnvC_001', 'On')}
    assert gen.state_reasons(t, 'drive', 'A') == ['achievement'] and gen.state_reasons(t, 'drive', 'C') == []
    assert gen.state_reasons(t, 'lever', 'On') == ['achievement']  # Through the door it opens.
    assert gen.state_reasons(t, 'add', 'On') == ['achievement']  # The counter's Full, at its count.
    assert gen.state_reasons(t, 'console', 'Off') == ['achievement'] == gen.state_reasons(t, 'console', 'On')
    pairs, active, events, counts = gen.build(t)
    assert [tag for a, tag in pairs if a == 'drive'] == ['B', 'C', 'Off'] and 'drive' not in active
    assert ('door', 'Closed') in pairs and ('door', 'Open') not in pairs and ('lever', 'Off') in pairs
    assert ('free', 'On') in pairs and 'free' in active and 'console' not in {a for a, _ in pairs}
    assert events == ['set C'] and counts['states']['achievement'] == 7


def test_zone_events():
    t = world({'door': spawn(), 'lever': spawn(events={'On': ['shown']}), 'box': spawn('Env_SupplyBox_Normal01'),
               'counter': spawn('Env_Count'), 'bad counter': spawn('Env_Bad_Count')},
              envs={'Env_Count': env(('Off', 'Full'), progress={'Off': 'Full'}),
                    'Env_Bad_Count': env(('Off', 'Full'), progress={'Off': 'Full'}, effects={'Full': ['shown']})},
              events={'open': event('ZoneEnvControl', 'c open', add=['close'], finish=['Quest_Name']),
                      'close': event('ZoneEnvControl', 'c close'), 'shown': event('Theater'),
                      'open then scene': event('ZoneEnvControl', 'c open', finish=['shown']),
                      'lever on': event('ZoneEnvControl', 'c lever on'),
                      'lever off': event('ZoneEnvControl', 'c lever off'),
                      'lever disable': event('ZoneEnvControl', 'c lever disable'),
                      'door disable': event('ZoneEnvControl', 'c door disable'),
                      'box enable': event('ZoneEnvControl', 'c box'), 'lost': event('ZoneEnvControl', 'nothing'),
                      'camp': event('ZoneEnvControl', 'c camp'), 'camp target': event('ZoneEnvControl', 'c camp 2'),
                      'count': event('ZoneEnvControl', 'c count'), 'bad count': event('ZoneEnvControl', 'c bad'),
                      'scene': event('Theater', add=['open'])},
              controls={'c open': control('door', 'On'), 'c close': control('door', 'Off'),
                        'c lever on': control('lever', 'On'), 'c lever off': control('lever', 'Off', activate='None'),
                        'c lever disable': control('lever', activate='Disable'),
                        'c door disable': control('door', activate='Disable'), 'c box': control('box'),
                        'c camp': control('door', kind='CampProperty'), 'c camp 2': control('door', camp='Camp_01'),
                        'c count': control('counter', kind='StateProgress'),
                        'c bad': control('bad counter', kind='ProgressSpeed')})
    pairs, active, _, _ = gen.build(t)
    pair_set, kept = set(pairs), {a for a, _ in pairs}
    want = {'open': None, 'close': None, 'open then scene': 'chain', 'lever on': 'target', 'lever off': None,
            'lever disable': 'disable', 'door disable': None, 'box enable': 'target', 'lost': 'no control row',
            'camp': 'camp', 'camp target': 'camp', 'count': None, 'bad count': 'target'}
    assert {e: gen.event_reason(t, e, pair_set, kept, set(active)) for e in want} == want
    _, _, events, counts = gen.build(t)
    assert events == sorted(e for e, why in want.items() if why is None)  # 'scene' is not an env control row.
    assert sum(counts['events'].values()) == len(want)


def test_no_progress():
    # A counter whose Full shows a scene, one whose Full is kept, one that counts to nothing, and one whose change tag
    # is out but with no count.
    t = world({'scene counter': spawn('Env_Scene_Count'), 'counter': spawn('Env_Count'), 'none': spawn('Env_None'),
               'idle': spawn('Env_Idle'), 'lever': spawn()},
              envs={'Env_Scene_Count': env(('Off', 'Full'), progress={'Off': 'Full'}, counts={'Off': 3},
                                           effects={'Full': ['scene']}),
                    'Env_Count': env(('Off', 'Full'), progress={'Off': 'Full'}, counts={'Off': 3}),
                    'Env_None': env(('Off', 'On'), counts={'Off': 2}),
                    'Env_Idle': env(('Off', 'Full'), progress={'Off': 'Full'}, effects={'Full': ['scene']})},
              events={'scene': event('Theater')})
    pairs, _, _, _ = gen.build(t)
    assert gen.no_progress(t, pairs) == ['scene counter']
    assert gen.no_progress(t, [('lever', 'Off')]) == []


def test_mxiii():
    # A copy of the lever whose On plays a scene, the door changed in place into a supply box, and env control rows
    # whose enums the file gives as numbers.
    t = world({'lever': spawn(), 'door': spawn()},
              events={'open': event('ZoneEnvControl', 'c open'), 'scene': event('Theater')},
              controls={'c open': control('door', 'On')})
    data = {'batches': [
        {'rows': [{'table': 'ZoneCampTable', 'name': 'Camp_9', 'donor': 'Camp_1', 'set': []},
                  {'table': 'ZoneEnvSpawnTable', 'name': 'mx lever', 'donor': 'lever',
                   'set': [['EventTagName1', 'On', True], ['TagEventList1', ['scene'], True]]},
                  {'table': 'ZoneEnvSpawnTable', 'name': 'door', 'donor': 'door',
                   'set': [['EnvAlias', 'Env_SupplyBox_Normal01', True]]}]},
        {'rows': [{'table': 'EventEnvControlTable', 'name': 'c mx', 'donor': 'c open',
                   'set': [['EnvSpawnAlias', 'mx lever', True], ['EnvControlType', 1, False], ['Activate', 2, True],
                           ['TagName', 'Off', True]]},
                  {'table': 'ZoneEventTable', 'name': 'mx off', 'donor': 'open',
                   'set': [['EventAlias', 'c mx', True], ['Type', 10, False]]}]}]}
    gen.mxiii(t, data)
    assert t['ZoneEnvSpawnTable']['mx lever']['TagEventList1'] == ['scene']
    assert t['ZoneEnvSpawnTable']['lever']['TagEventList1'] == []  # The donor stays as it was.
    assert t['EventEnvControlTable']['c mx']['Activate'] == 'ESBObjectState::ESBObject_Disable'
    assert t['ZoneEventTable']['mx off']['Type'] == 'ESBZoneEventType::ZoneEvent_ZoneEnvControl'
    assert 'ZoneCampTable' not in t
    pairs, active, events, _ = gen.build(t)
    assert pairs == [('lever', 'Off'), ('lever', 'On'), ('mx lever', 'Off')] and active == ['lever']
    assert events == []  # mx off disables a lever whose On stays local; open's door is a supply box now.
    for table, field in (('ZoneEventTable', 'Type'), ('EventEnvControlTable', 'Activate')):
        bad = {'batches': [{'rows': [{'table': table, 'name': 'x', 'donor': 'open' if table == 'ZoneEventTable'
                                      else 'c open', 'set': [[field, 99, True]]}]}]}
        try:
            gen.mxiii(t, bad)
            raise AssertionError(f'{field} 99 went in')
        except ValueError as e:
            assert field in str(e)


def test_render_and_write():
    t = world({'b': spawn(), 'a': spawn()}, events={'z': event('ZoneEnvControl', 'cz'),
                                                     'y': event('ZoneEnvControl', 'cy')},
              controls={'cz': control('a', 'On'), 'cy': control('b', 'Off')})
    pairs, active, events, counts = gen.build(t)
    assert pairs == [('a', 'Off'), ('a', 'On'), ('b', 'Off'), ('b', 'On')] and active == ['a', 'b']
    assert events == ['y', 'z']
    block = gen.render(pairs, active, events, ['b'], counts)
    assert block.startswith(gen.BEGIN) and block.endswith(gen.END)
    assert '    {"a", "Off"},\n    {"a", "On"},\n    {"b", "Off"},' in block
    assert 'constexpr const char *kObjectState[] = {\n    "a",\n    "b",\n};' in block
    assert 'constexpr const char *kEvents[] = {\n    "y",\n    "z",\n};' in block
    assert 'constexpr const char *kNoProgress[] = {\n    "b",\n};' in block
    assert 'constexpr const char *kNoProgress[] = {\n    "",\n};' in gen.render(pairs, active, events, [], counts)
    assert all(len(line) <= 120 for line in block.splitlines())
    for bad in ('a"b', 'a\\b', 'a b', 'é'):
        try:
            gen.render([(bad, 'On')], active, events, [], counts)
        except ValueError as e:
            assert repr(bad) in str(e), e
            continue
        raise AssertionError(f'{bad!r} went into the block')
    try:
        gen.render(pairs, active, [], [], counts)
        raise AssertionError('an empty list went into the block')
    except ValueError:
        pass
    with tempfile.TemporaryDirectory() as tmp:
        header = Path(tmp) / 'rows.h'
        header.write_text(f'// top\n{gen.BEGIN}\nold\n{gen.END}\n// bottom\n')
        gen.write(header, block)
        assert header.read_text() == f'// top\n{block}\n// bottom\n'
        gen.write(header, block)
        assert header.read_text() == f'// top\n{block}\n// bottom\n'


def test_load_and_main():
    t = world({'a': spawn()}, events={'z': event('ZoneEnvControl', 'cz')}, controls={'cz': control('a', 'On')})
    with tempfile.TemporaryDirectory() as tmp:
        for name in gen.TABLES:
            other = {'Type': 'Package'}  # An export without rows, before the table's.
            (Path(tmp) / f'{name}.uasset.json').write_text(json.dumps([other, {'Name': name, 'Rows': t[name]}]))
        assert gen.load(tmp) == t
        header, mx = Path(tmp) / 'rows.h', Path(tmp) / 'mxiii.json'
        header.write_text(f'{gen.BEGIN}\n{gen.END}\n')
        mx.write_text(json.dumps({'batches': [{'rows': [{'table': 'ZoneEnvSpawnTable', 'name': 'b', 'donor': 'a',
                                                         'set': []}]}]}))
        saved = gen.HEADER, gen.MXIII
        gen.HEADER, gen.MXIII = header, mx
        try:
            with contextlib.redirect_stdout(io.StringIO()) as out:
                gen.main([tmp])
        finally:
            gen.HEADER, gen.MXIII = saved
        assert out.getvalue().startswith('4 pairs over 2 rows, 2 SetEnvActive rows, 1 ZoneEvent rows, '
                                         '0 rows without progress\n')
        text = header.read_text()
        assert '{"a", "Off"},' in text and '"z",' in text and text.count(gen.BEGIN) == 1


for name, test in list(globals().items()):
    if name.startswith('test_'):
        test()
print('world_rows_test: ok')
