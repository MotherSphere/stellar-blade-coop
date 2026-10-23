#!/usr/bin/env python3
"""tools/story.py on saves built here: a save written as the game writes them (EVAS-wrapped GVAS, CRC-32), read
back, snapshotted, digested and diffed. The same story in two saves gives one digest however the zones are ordered and
whatever moved or was reset; a quest state, an env object and a mission flag each show in the diff, and one that only
moved is absent. The command line is run too.
Run: python3 tests/story_test.py"""
import contextlib
import io
import struct
import sys
import tempfile
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'tools'))
import story  # noqa: E402


def fs(text):
    """An FString: a length with its NUL, or the UTF-16 form for a negative one (not needed here)."""
    return struct.pack('<i', len(text) + 1) + text.encode('latin-1') + b'\0'


def name_prop(name, value):
    payload = fs(value)
    return fs(name) + fs('NameProperty') + struct.pack('<ii', len(payload), 0) + b'\0' + payload


def int_prop(name, value):
    payload = struct.pack('<i', value)
    return fs(name) + fs('IntProperty') + struct.pack('<ii', len(payload), 0) + b'\0' + payload


def bool_prop(name, value):
    return fs(name) + fs('BoolProperty') + struct.pack('<ii', 0, 0) + bytes([1 if value else 0]) + b'\0'


def struct_prop(name, struct_name, payload):
    return fs(name) + fs('StructProperty') + struct.pack('<ii', len(payload), 0) + fs(struct_name) + b'\0' * 16 + \
        b'\0' + payload


def vector_prop(name, x, y, z):
    return struct_prop(name, 'Vector', struct.pack('<3f', x, y, z))


def array_prop(name, inner, values, struct_name=''):
    """An array of structs (each element its own tagged properties, ending in a 'None' name) or of names."""
    if inner == 'StructProperty':
        body = b''.join(value + fs('None') for value in values)
        payload = struct.pack('<i', len(values)) + fs('Items') + fs('StructProperty') + \
            struct.pack('<ii', len(body), 0) + fs(struct_name) + b'\0' * 16 + b'\0' + body
    else:
        payload = struct.pack('<i', len(values)) + b''.join(fs(v) for v in values)
    return fs(name) + fs('ArrayProperty') + struct.pack('<ii', len(payload), 0) + fs(inner) + b'\0' + payload


def map_prop(name, key_kind, value_kind, entries):
    """(key bytes, value bytes) pairs. A struct value is tagged properties, so it ends with a 'None' name."""
    body = b''.join(k + v + (fs('None') if value_kind == 'StructProperty' else b'') for k, v in entries)
    payload = struct.pack('<ii', 0, len(entries)) + body
    return fs(name) + fs('MapProperty') + struct.pack('<ii', len(payload), 0) + fs(key_kind) + fs(value_kind) + \
        b'\0' + payload


def name_entry(value):
    return fs(value)


def int_entry(value):
    return struct.pack('<i', value)


def task_group(alias, state, task_alias, task_state, value, order):
    task = name_prop('TaskAlias', task_alias) + name_prop('TaskState', task_state) + \
        int_prop('CurrentValue', value) + int_prop('CompleteOrder', order)
    group = name_prop('TaskGroupAlias', alias) + name_prop('TaskGroupState', state) + \
        array_prop('AllChildTaskList', 'NameProperty', []) + array_prop('TaskList', 'StructProperty', [task],
                                                                       'SBSaveQuestTask') + \
        map_prop('AllChildTaskList', 'NameProperty', 'StructProperty', [(name_entry(task_alias), task)])
    return group


def quest(alias, state, groups):
    return name_prop('QuestAlias', alias) + int_prop('QuestState', state) + \
        array_prop('QuestTaskGroupList', 'StructProperty', groups, 'SBSaveQuestTaskGroup')


def env_object(alias, activate, interacted, at):
    interact = struct_prop('InteractData', 'SBSaveInteractData', bool_prop('bInteracted', interacted))
    return name_prop('EnvAlias', alias) + name_prop('EnvActivate', activate) + \
        name_prop('EnvActiveState', 'ESBENV_State_None') + interact + vector_prop('ActorLocation', *at)


def zone(alias, activate, reset, env_objects, objects, at=(1.0, 2.0, 3.0)):
    return name_prop('ZoneAlias', alias) + name_prop('ZoneObjectState', activate) + \
        bool_prop('bZoneReset', reset) + \
        array_prop('ZoneEnvStorageList', 'StructProperty', env_objects, 'SBSaveZoneEnv') + \
        array_prop('ZoneNpcStorageList', 'StructProperty', [], 'SBSaveZoneNpc') + \
        array_prop('ZoneTriggerStorageList', 'StructProperty', [], 'SBSaveZoneTrigger') + \
        vector_prop('ActorLocation', *at) + \
        map_prop('WorldObjectStorageMap', 'IntProperty', 'StructProperty',
                 [(int_entry(index), name_prop('UniqueKey', key) + name_prop('Activate', activate))
                  for index, (key, activate) in enumerate(objects)])


def record(group, entries):
    data = b''.join(name_prop('DataAlias', alias) + bool_prop('bSuccessTask', done) for alias, done in entries)
    return name_prop('RecordGroupName', group) + \
        map_prop('RecordTaskGroupMap', 'NameProperty', 'StructProperty',
                 [(name_entry('ESBMission_Achievement'),
                   array_prop('TaskDataList', 'StructProperty', [name_prop('DataAlias', a) + bool_prop('bSuccessTask', d)
                                                                 for a, d in entries],
                              'SBSaveProgressData'))])


def save(path, *, quest_state=1, quest_value=0, achievement=False, env_activate='ESBObject_Disable',
         interacted=False, impact=None, reset=True, zones_reversed=False, moved=(1.0, 2.0, 3.0)):
    """A save of the shape the game writes, with the story bits given; impact is the world object's activate name."""
    groups = [task_group('Quest_Epic_01_M01', 'TaskGroup_Progress', 'Quest_Epic_01_M01_T01',
                         'ESBQuestTaskState_Progress', quest_value, -1)]
    quests = [quest('Quest_Epic_01', quest_state, groups), quest('CQ_SD10_RR', 1, [])]
    env = [env_object('SD_10_EnvS_067', env_activate, interacted, moved),
           env_object('SD_10_EnvS_066', 'ESBObject_Enable', True, (0.0, 0.0, 0.0))]
    objects = [('SD_10_EffVol_007', impact or 'ESBObject_Disable')]
    places = [zone('Zone_SD_10', 'ESBObject_Enable', reset, env, objects, moved),
              zone('Zone_Xion_10', 'ESBObject_Enable', reset, [], [])]
    if zones_reversed:
        places.reverse()
    properties = (
        map_prop('DataMap_SBQuest', 'NameProperty', 'StructProperty', [(name_entry('Quest'), b''.join([
            array_prop('ProgressQuestList', 'StructProperty', quests, 'SBSaveQuest'),
            array_prop('TrackingQuestAliases', 'NameProperty', ['Quest_Epic_01']),
            array_prop('CompleteQuestList', 'NameProperty', ['Quest_Epic_00']),
            array_prop('FailedQuestList', 'NameProperty', []),
        ]))]) +
        struct_prop('GamePlayProgressRecordData', 'SBSaveProgress',
                    array_prop('ProgressRecordGroup', 'StructProperty',
                               [record('Quest_Epic_01_M01', [('Xion_Phase_1', achievement),
                                                             ('Ach_LV_SD10_SaveProgress_01', False)])],
                               'SBSaveProgressGroup')) +
        map_prop('DataMap_SBEnv', 'NameProperty', 'StructProperty', [(name_entry('Env'), b''.join([
            array_prop('WorldContainerList', 'StructProperty', [], 'SBSaveWorld'),
            array_prop('ZoneContainerList', 'StructProperty', places, 'SBSaveZone'),
        ]))]))
    body = (b'GVAS' + struct.pack('<ii', 2, 522) + struct.pack('<3HI', 4, 26, 2, 1) + fs('++UE4') +
            struct.pack('<ii', 0, 0) + fs('/Script/SB.SBSaveGame') + properties + fs('None') + b'\0' * 4)
    Path(path).write_bytes(b'EVAS' + b'\0' * 4 + body + struct.pack('<I', zlib.crc32(body) & 0xffffffff))
    return path


def run(*argv):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = story.main([str(a) for a in argv])
    return code, out.getvalue().splitlines()


story.selftest()

# 0. The fixture tests/story_dump_test.lua mirrors: this tool's sample and the file's lines agree, so the Lua dump's
#    test pins the two implementations to the same text.
sample_file = Path(__file__).resolve().parent / 'story_sample.txt'
assert story.lines(story.story(story.sample())) == sample_file.read_text(encoding='utf-8').splitlines(), \
    'tests/story_sample.txt does not match tools/story.py sample()'

with tempfile.TemporaryDirectory() as folder:
    folder = Path(folder)
    first = save(folder / 'first.sav')
    props = story.read(first)
    assert props['DataMap_SBQuest'][0][0] == 'Quest', props
    state = story.story(props)
    assert state['quest Quest_Epic_01 state'] == 1, state
    assert state['quest Quest_Epic_01 group Quest_Epic_01_M01 task Quest_Epic_01_M01_T01 value'] == 0, state
    assert state['quest Quest_Epic_00 complete'] is True, state
    assert state['progress Quest_Epic_01_M01 ESBMission_Achievement Xion_Phase_1 done'] is False, state
    assert state['zone Zone_SD_10 env SD_10_EnvS_067 activate'] == 'ESBObject_Disable', state
    assert state['zone Zone_SD_10 env SD_10_EnvS_067 interacted'] is False, state
    assert state['zone Zone_SD_10 object SD_10_EffVol_007 activate'] == 'ESBObject_Disable', state
    assert not [key for key in state if 'ActorLocation' in key or key.endswith('bZoneReset')], state

    # 0b. A finished quest held as its whole struct, as this game's newer saves write it: the alias still names the
    #     line, next to the older saves' plain name.
    struct_done = {'DataMap_SBQuest': [['Quest', {'CompleteQuestList': [
        {'QuestAlias': 'Quest_Epic_00', 'QuestState': 3}]}]]}
    assert story.story(struct_done)['quest Quest_Epic_00 complete'] is True, story.story(struct_done)

    # 1. What did not change the story at all: moved, reset, and the zones listed the other way round.
    again = save(folder / 'again.sav', quest_state=1, quest_value=0, achievement=False,
                 env_activate='ESBObject_Disable', interacted=False, reset=False,
                 zones_reversed=True, moved=(9.0, 8.0, 7.0))
    assert story.digest(story.read(first)) == story.digest(story.read(again)), 'a volatile field reached the digest'
    assert story.diff(story.read(first), story.read(again)) == [], story.diff(story.read(first), story.read(again))
    assert len(story.snapshot(story.read(first))) == len(story.snapshot(story.read(again))), 'order changed the lines'

    # 2. A story change: the quest advanced, a door opened, an achievement done, a counter moved.
    later = save(folder / 'later.sav', quest_state=3, quest_value=2, achievement=True,
                 env_activate='ESBObject_Enable', interacted=True, impact='ESBObject_Enable')
    changes = story.diff(story.read(first), story.read(later))
    assert changes == [
        '~ progress Quest_Epic_01_M01 ESBMission_Achievement Xion_Phase_1 done: False -> True',
        '~ quest Quest_Epic_01 group Quest_Epic_01_M01 task Quest_Epic_01_M01_T01 value: 0 -> 2',
        '~ quest Quest_Epic_01 state: 1 -> 3',
        '~ zone Zone_SD_10 env SD_10_EnvS_067 activate: ESBObject_Disable -> ESBObject_Enable',
        '~ zone Zone_SD_10 env SD_10_EnvS_067 interacted: False -> True',
        '~ zone Zone_SD_10 object SD_10_EffVol_007 activate: ESBObject_Disable -> ESBObject_Enable'], changes
    assert story.digest(story.read(first)) != story.digest(story.read(later))

    # 3. A dump as the game's side writes it: comments skipped, the same lines give the same digest, and a changed
    #    line and a missing one each show in compare (exit 1).
    rows = story.lines(story.story(story.read(first)))
    dump = folder / 'dump.txt'
    dump.write_text('# a game-side dump\n' + '\n'.join(rows) + '\n\n', encoding='utf-8')
    code, out = run('digest-lines', dump)
    assert code == 0 and out == [story.digest(story.read(first))], out
    code, out = run('compare', first, dump)
    assert code == 0 and out[0].startswith('save ') and out[-1] == 'the same', out
    dump.write_text('\n'.join(rows[1:] + ['zone Zone_SD_10 state = ESBObject_Disable']) + '\n', encoding='utf-8')
    code, out = run('compare', first, dump)
    assert code == 1 and '+ zone Zone_SD_10 state = ESBObject_Disable' in out, out
    assert [line for line in out if line.startswith('- ')], out

    # 4. The command line: a snapshot narrowed by a prefix, a digest, a diff, and the usage.
    code, lines = run('snapshot', first, 'quest ')
    assert code == 0 and lines and all(line.startswith('quest ') for line in lines), lines
    code, lines = run('digest', first)
    assert code == 0 and lines == [story.digest(story.read(first))], lines
    code, lines = run('diff', first, later)
    assert code == 0 and len(lines) == 6 and lines[2].startswith('~ quest Quest_Epic_01 state'), lines
    code, lines = run()
    assert code == 2 and lines and lines[0].startswith("Stellar Blade's story"), lines

print('story_test: ok')
