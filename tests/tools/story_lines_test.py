#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""tools/story_lines.py: the story lines of docs/dev/story.md from parsed saves held in memory and from saves written
into a temporary folder, their digest, and the snapshot, diff, digest, digest-lines and compare commands. The expected
lines of story_case.json are in story_case.txt, which tests/lua/story/snapshot_test.lua holds the in-game dump to as
well; float_repr.txt holds Python's repr of many doubles for the same test.
Run: python3 tests/tools/story_lines_test.py (--write rewrites float_repr.txt)"""
import contextlib
import copy
import io
import json
import math
import random
import struct
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / 'tools'))
import save_read  # noqa: E402
import story_lines as L  # noqa: E402
from save_read import Map  # noqa: E402


def run(*argv):
    """(exit code, stdout, stderr) of story_lines with these arguments."""
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        try:
            code = L.main([str(a) for a in argv])
        except SystemExit as stop:
            code = stop.code
    return code, out.getvalue(), err.getvalue()


def from_json(value):
    """story_case.json's form of a parsed save: {"$map": [[key, value], ...]} is a Map."""
    if isinstance(value, dict) and list(value) == ['$map']:
        return Map((from_json(k), from_json(v)) for k, v in value['$map'])
    if isinstance(value, dict): return {k: from_json(v) for k, v in value.items()}
    if isinstance(value, list): return [from_json(v) for v in value]
    return value


def quest(**fields):
    return {'DataMap_SBQuest': Map([('Quest', fields)])}


def env(zones=(), worlds=()):
    return {'DataMap_SBEnv': Map([('Env', {'ZoneContainerList': list(zones), 'WorldContainerList': list(worlds)})])}


# 1. The example of docs/dev/story.md, built from its description: the same 29 lines and digest as the old tool printed.
example = {
    **quest(ProgressQuestList=[
        {'QuestAlias': 'Quest_Example_07', 'QuestState': 1, 'QuestTaskGroupList': [
            {'TaskGroupAlias': 'Quest_Example_07_M03', 'TaskGroupState': 'TaskGroup_None',
             'AllChildTaskList': Map([('Quest_Example_07_M03_T02', {
                 'TaskAlias': 'Quest_Example_07_M03_T02', 'TaskState': 'ESBQuestTaskState_Progress',
                 'CurrentValue': 12, 'CompleteOrder': 2})])}]},
        {'QuestAlias': 'Quest_Example_07', 'QuestState': 1, 'QuestTaskGroupList': []},
        {'QuestAlias': 'Quest_Example_11', 'QuestState': 1}],
        TrackingQuestAliases=['Quest_Example_07'], CompleteQuestList=[{'QuestAlias': 'Quest_Example_03'}],
        FailedQuestList=['Quest_Example_02']),
    'GamePlayProgressRecordData': {'ProgressRecordGroup': [{'RecordGroupName': 'Quest_Example_07_M03',
        'RecordTaskGroupMap': Map([('ESBMission_EnterTrigger', {'TaskDataList': [
            {'DataAlias': 'Example_ZTrigger_014', 'bSuccessTask': True}, {'bSuccessTask': False}]})])}]},
    **env(zones=[
        {'ZoneAlias': 'Zone_Example_N', 'ZoneObjectState': 'ESBObject_Disable', 'ZoneEnvStorageList': [
            {'EnvAlias': 'Example_EnvS_031', 'EnvActivate': 'ESBObject_Enable', 'CurrentTriggerCount': 4,
             'EnvStateSlotTag': 'Example_Slot_B', 'InteractData': {'bInteracted': False}},
            {'EnvAlias': 'Example_EnvS_031', 'EnvActivate': 'ESBObject_Disable',
             'StateInfoList': [{'ExampleRatio': 2.5e-05}]}],
         'ZoneEventItemStorageList': [{'ObjectName': 'Example_Pickup_12', 'ExampleTaken': True}],
         'ZoneNpcStorageList': [{'CharacterDataAlias': 'Npc_Example_04', 'bHiddenGame': True, 'SpawnIndex': 2}],
         'WorldObjectStorageMap': Map([(41, {'UniqueKey': 'Example_EffVol_020', 'EffectVolumeDeadCount': 3})]),
         'ZoneTriggerStorageList': [{'TriggerAlias': 'Example_ZTrigger_014', 'TriggerActivate': 'ESBObject_Disable'}]},
        {'ZoneObjectState': 'ESBObject_Enable'}],
        worlds=[{'WorldAlias': 'Example_World_2', 'ZoneEventActorStorageList': [
            {'ExampleCount': 0},
            {'ElementInfoMap': Map([('Element_Fire', {'ElementAmount': struct.unpack('<f', struct.pack('<f', 0.3))[0]})]),
             'ActorRotation': [0.0, 90.0, 0.0]}]}])}
lines = L.lines(example)
assert len(lines) == 29 and lines[0] == 'progress Quest_Example_07_M03 ESBMission_EnterTrigger 1 done = False', lines
assert 'quest Quest_Example_07#2 tracked = True' in lines and 'zone Zone_Example_N object Example_EffVol_020 deaths = 3' \
    in lines and 'world Example_World_2 actor 1 ElementInfoMap[Element_Fire].ElementAmount = 0.30000001192092896' in lines
assert L.digest(lines) == '045f870eadaac816520e6ad0d5cf27bde23e5688f94bc954d67c657e114a2cec', L.digest(lines)

# 2. story_case.json: its lines are story_case.txt, also after a trip through a .sav file in the game's layout.
case = from_json(json.loads((HERE / 'story_case.json').read_text()))
expected = (HERE / 'story_case.txt').read_text().splitlines()
assert L.lines(case) == expected, '\n'.join(sorted(set(L.lines(case)) ^ set(expected)))
assert save_read.read_save(save_read.wrap(save_read.encode(case)))[1] == case
# A few of its lines by hand: each scope's numbering, tracked on a numbered quest, a name by position and by map key,
# a negative integer, a float read from a FloatProperty, a None value in a path line, a map below an entry.
for line in ('quest Quest_Case_01 group Quest_Case_01_G1#2 task Quest_Case_01_T1#2 state = ESBQuestTaskState_None',
             'quest Quest_Case_01#2 tracked = True', 'quest 2 group 0 task Key_Only value = 1',
             'quest 2 tracked = False', 'quest None complete = True', 'quest Quest_Case_09 failed = True',
             'progress 1 ESBMission_Achievement Case_Ach_1 done = True',
             'progress Quest_Case_01_G1 ESBMission_EnterTrigger Case_Trigger_01#2 done = False',
             'progress Quest_Case_01_G1 ESBMission_EnvState Case_Env_07 done = False',
             'quest Quest_Case_01 group Quest_Case_01_G1 task Quest_Case_01_T2 value = -2',
             'zone Zone_Case_A env Case_Door_01#2 count = 0', 'zone Zone_Case_A env 2 active = ESBENV_State_Close',
             'zone Zone_Case_A env Case_Door_01 [1].Ratio = 1e+16', 'zone Zone_Case_A env Case_Door_01 Phase = None',
             'zone Zone_Case_A object 7 activate = ESBObject_Disable', 'zone Zone_Case_A object Case_EffVol_020#2 deaths = 1',
             'zone Zone_Case_A trigger Case_Trigger_01#2 interacted = False', 'zone Zone_Case_A npc Npc_Case_Kaya life = 0',
             'zone Zone_Case_A item Case_Pickup_03 Share = 0.10000000149011612',
             'world World_Case_A actor 1 Parts[Part_Case_X].Hp = 10', 'world World_Case_A actor 1 Slots[-1].On = False',
             'world World_Case_A actor 1 EventName = None'):
    assert line in expected, line
assert not [x for x in expected if 'Location' in x or 'Rotation' in x or 'Timestamp' in x or 'Tags' in x
            or 'Zone_Case_B env' in x or 'Case_Lost' in x or 'EnvPosition' in x or 'bZoneReset' in x or 'TaskList' in x]
assert 'quest  complete = True' not in expected and 'quest Quest_Elsewhere tracked = False' not in expected

# 3. What docs/dev/story.md leaves out keeps the digest and gives an empty diff: positions, bZoneReset, the timestamps,
# TaskList and the order of zones and worlds. Each story change gives its own ~ line and another digest.
moved = copy.deepcopy(case)
e = moved['DataMap_SBEnv'][0][1]
e['ZoneContainerList'].reverse()
e['WorldContainerList'] = e['WorldContainerList'][1:] + e['WorldContainerList'][:1]
for z in e['ZoneContainerList']: z['bZoneReset'] = not z.get('bZoneReset')
zone_a = e['ZoneContainerList'][1]
zone_a['ZoneEventActorStorageList'][0]['ActorLocation'] = [99.0, 98.0, 97.0]
e['WorldContainerList'][2]['ZoneEventActorStorageList'][0]['ActorRotation'] = [1.0, 2.0, 3.0]
q = moved['DataMap_SBQuest'][0][1]
q['ProgressQuestList'][0]['LastUpdateTimestamp'] += 1
q['ProgressQuestList'][0]['QuestTaskGroupList'][0]['TaskList'][0]['CurrentValue'] = 1
q['QuestMarkerLocation'] = [0.0, 0.0, 0.0]
assert L.digest(L.lines(moved)) == L.digest(expected) and save_read.diff(L.story(case), L.story(moved)) == []
changed = copy.deepcopy(moved)
cq = changed['DataMap_SBQuest'][0][1]
cq['ProgressQuestList'][0]['QuestTaskGroupList'][0]['AllChildTaskList'][1][1]['CurrentValue'] = 5
changed['DataMap_SBEnv'][0][1]['ZoneContainerList'][1]['ZoneEnvStorageList'][0]['InteractData']['bInteracted'] = False
cq['CompleteQuestList'].append('Quest_Case_01')
assert save_read.diff(L.story(case), L.story(changed)) == [
    '+ quest Quest_Case_01 complete = True',
    '~ quest Quest_Case_01 group Quest_Case_01_G1 task Quest_Case_01_T2 value: -2 -> 5',
    '~ zone Zone_Case_A env Case_Door_01 interacted: True -> False']
assert L.digest(L.lines(changed)) != L.digest(expected)

# 4. Finished and failed quests as plain names or as full records; an empty name and a record with none give no line.
for done in (['Q_A', ''], [{'QuestAlias': 'Q_A', 'QuestState': 3}, {'QuestState': 3}]):
    assert L.lines(quest(CompleteQuestList=done, FailedQuestList=done)) == ['quest Q_A complete = True',
                                                                            'quest Q_A failed = True']
# An empty string value ends in '= '; True, False and floats in Python's spelling; an integer-valued float keeps '.0'.
got = L.lines(env(zones=[{'ZoneAlias': 'Z', 'ZoneEventItemStorageList': [
    {'ObjectName': 'I', 'Note': '', 'A': True, 'B': 7.0, 'C': -0.0, 'D': 3e+20}]}]))
assert got == ['zone Z item I A = True', 'zone Z item I B = 7.0', 'zone Z item I C = -0.0', 'zone Z item I D = 3e+20',
               'zone Z item I Note = ', 'zone Z item I ObjectName = I'], got
# A map entry with no naming field and a struct key is named '#' and the key's text.
assert L.lines(env(zones=[{'ZoneAlias': 'Z', 'WorldObjectStorageMap': Map([({'K': 1}, {'Activate': 'X'})])}])) == [
    "zone Z object #{'K': 1} activate = X"]


# 5. float_repr.txt: doubles as 16 big-endian hex digits, then Python's repr. Both sides of each notation switch,
# negative zero, subnormals, the largest values, each power of two of a range and its neighbours, float-widened
# values, and random bit patterns.
def floats():
    xs = [0.0, -0.0, math.inf, -math.inf, 5e-324, 1e-323, 2.225073858507201e-308, 2.2250738585072014e-308,
          1.7976931348623157e308, 1e308, 1e300, 1e22, 1e23, 0.1, 0.3, 1 / 3, 2 / 3, 123456789.0, 2.5e-05, 7.0, 0.5]
    for edge in (1e-5, 1e-4, 1e15, 1e16, 1e17, 1.0, 10.0):
        y = z = edge
        for _ in range(3):
            y, z = math.nextafter(y, 0), math.nextafter(z, math.inf)
            xs += [y, z]
        xs.append(edge)
    for e in range(-1074, 1024, 5):
        p = math.ldexp(1.0, e)
        xs += [p, math.nextafter(p, 0), math.nextafter(p, math.inf)]
    rng = random.Random(20261115)
    for _ in range(300):
        xs.append(struct.unpack('<f', struct.pack('<I', rng.getrandbits(32) & 0xff7fffff))[0])
    for _ in range(600):
        bits = rng.getrandbits(64)
        if (bits >> 52) & 0x7ff != 0x7ff: xs.append(struct.unpack('>d', bits.to_bytes(8, 'big'))[0])
    for _ in range(60):
        xs.append(struct.unpack('>d', rng.getrandbits(52).to_bytes(8, 'big'))[0])  # Subnormals.
    xs += [-x for x in xs[:40]]
    return [f"{struct.pack('>d', x).hex()} {x!r}" for x in xs] + ['7ff8000000000000 nan']


fixture = HERE / 'float_repr.txt'
if '--write' in sys.argv: fixture.write_text('\n'.join(floats()) + '\n')
assert fixture.read_text().splitlines() == floats(), 'float_repr.txt is stale: run with --write'

# 6. The commands, on saves and dump files written into a temporary folder.
with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    a, b, c, bad = tmp / 'a.sav', tmp / 'b.sav', tmp / 'c.sav', tmp / 'bad.sav'
    a.write_bytes(save_read.wrap(save_read.encode(case)))
    b.write_bytes(save_read.wrap(save_read.encode(moved)))
    c.write_bytes(save_read.wrap(save_read.encode(changed)))
    bad.write_bytes(b'EVAS\x01\x00\x00\x00GVAS' + bytes(12))
    digest = L.digest(expected)
    assert run('snapshot', a) == (0, '\n'.join(expected) + '\n', '')
    code, out, _ = run('snapshot', a, 'zone Zone_Case_B ')
    assert code == 0 and out == 'zone Zone_Case_B state = ESBObject_Enable\n', out
    assert run('snapshot', a, 'quest 2 ')[1] == ''.join(f'{x}\n' for x in expected if x.startswith('quest 2 '))
    assert run('diff', a, b) == (0, '', '')
    assert run('diff', a, c)[:2] == (0, '\n'.join(save_read.diff(L.story(case), L.story(changed))) + '\n')
    assert run('digest', a) == (0, digest + '\n', '') and run('digest', b) == (0, digest + '\n', '')
    # A dump as the game writes it: comment lines, blank lines, CRLF ends, the lines in another order.
    dump = tmp / 'StellarCoopStory.txt'
    dump.write_bytes(('# coop story dump\r\n\r\n' + '\r\n'.join(reversed(expected)) + '\r\n  \r\n').encode())
    assert run('digest-lines', dump) == (0, digest + '\n', '')
    assert run('compare', a, dump) == (0, f'save {digest} {len(expected)} lines\ndump {digest} {len(expected)} lines\n'
                                          'same story: every line matches\n', '')
    # Lines missing on each side: the dump's extra lines (+) in its sorted order, then the save's (-), then counts.
    edited = [x for x in expected if not x.startswith('zone Zone_Case_B ')] + ['quest Quest_Extra state = 1',
                                                                               'quest Quest_Case_01 state = 2']
    edited.remove('quest Quest_Case_01 state = 1')
    dump.write_text('# edited\n' + '\n'.join(edited) + '\n')
    code, out, _ = run('compare', a, dump)
    head = [f'save {digest} {len(expected)} lines', f'dump {L.digest(sorted(edited))} {len(edited)} lines']
    assert code == 1 and out.splitlines() == head + [
        '+ quest Quest_Case_01 state = 2', '+ quest Quest_Extra state = 1', '- quest Quest_Case_01 state = 1',
        '- zone Zone_Case_B state = ESBObject_Enable', '2 dump lines not in the save, 2 save lines not in the dump'], out
    # A repeated line is counted, and the stories then differ.
    dump.write_text('\n'.join(expected + expected[:1]) + '\n')
    code, out, _ = run('compare', a, dump)
    assert code == 1 and f'dump {L.digest(sorted(expected + expected[:1]))} {len(expected) + 1} lines' in out, out
    # A file with a NUL byte, a missing file and a save that cannot be read: the tool's message and exit 2.
    (tmp / 'utf16.txt').write_bytes('quest A state = 1\n'.encode('utf-16-le'))
    for argv in (('digest-lines', tmp / 'utf16.txt'), ('digest-lines', tmp / 'none.txt'), ('compare', a, tmp / 'utf16.txt'),
                 ('compare', bad, dump), ('compare', tmp / 'none.sav', dump)):
        code, out, err = run(*argv)
        assert code == 2 and out == '' and err.startswith('story_lines: '), (argv, code, out, err)
    assert 'NUL' in run('digest-lines', tmp / 'utf16.txt')[2]
    assert run('selftest') == (0, 'story_lines selftest: ok\n', '')
    for argv in ((), ('snapshot',), ('digest', a, b), ('compare', a), ('nope',), ('selftest', 'x')):
        code, out, _ = run(*argv)
        assert code == 2 and out.startswith('Use: '), (argv, code, out)
    try:
        run('digest', bad)
        raise AssertionError('bad save read')
    except save_read.SaveError:
        pass

print('story_lines_test: ok')
