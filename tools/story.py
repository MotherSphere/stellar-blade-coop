"""Stellar Blade's story and world state as the save holds it: the part two players have to agree on, as one sorted
"key = value" line each, and a diff of two of those. Read only: it never writes a save (it reads it through gvas.py).

  python -I tools/story.py snapshot SAVE [PREFIX]  every story line, sorted (only keys starting with PREFIX)
  python -I tools/story.py diff OLD NEW            the lines that differ, were added or were removed
  python -I tools/story.py digest SAVE             one SHA-256 over the sorted lines, to compare two players' worlds
  python -I tools/story.py digest-lines FILE       the same over a file of lines (a game-side dump; # comments skipped)
  python -I tools/story.py compare SAVE FILE       a save's lines against a dump's: both digests and what differs
  python -I tools/story.py selftest                a built save read back

What is in it (mapped from the New Game save at the first beach, 2026-10-23; docs/story.md has the evidence): quests,
their task groups and tasks with their counters, the complete and failed lists, the tracking quest; the mission
tables' per-entry success flags; and each zone's object state and its env objects (doors, lifts, consoles: activated,
active state, interacted, trigger count), NPCs, triggers, picked-up event items, event actors and world objects.

Left out on purpose: positions and rotations (the player's and every stored actor's), timestamps, playtime, the camera,
the inventory (each player keeps her own), bZoneReset (it flips for every zone that is not the loaded one; its meaning
is unknown) and the theater's level-sequence set (it grows as subtitles play). Keys are the aliases the game stores, so
a line means the same thing in any save; a repeated alias gets #2, #3 in the order the game lists them; an entry with
no alias of its own is keyed by its map key or index. docs/story.md lists what this does not cover yet.
"""
import copy
import hashlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gvas  # noqa: E402

# Never story state: where something was, and when it changed.
VOLATILE = {'ActorLocation', 'ActorRotation', 'QuestMarkerLocation', 'LastUpdateTimestamp'}
# Aliases an element may name itself by, the game's own field names.
ALIASES = ('ZoneAlias', 'EnvAlias', 'TriggerAlias', 'QuestAlias', 'TaskGroupAlias', 'TaskAlias',
           'CharacterDataAlias', 'UniqueKey', 'WorldAlias', 'ObjectName', 'RecordGroupName', 'DataAlias', 'Alias')


def at(node, key, default=None):
    """A struct's field, or a map's value for a key (gvas keeps a map as [key, value] pairs)."""
    if isinstance(node, dict):
        return node.get(key, default)
    if isinstance(node, list):
        for pair in node:
            if isinstance(pair, list) and len(pair) == 2 and pair[0] == key:
                return pair[1]
    return default


def entries(node):
    """A list's (index, element) pairs, or a map's (key, value) pairs."""
    if not isinstance(node, list):
        return []
    if node and all(isinstance(pair, list) and len(pair) == 2 for pair in node):
        return [(pair[0], pair[1]) for pair in node]
    return list(enumerate(node))


def alias_of(element):
    if isinstance(element, str):
        return element
    for key in ALIASES:
        value = at(element, key)
        if isinstance(value, str) and value != 'None':
            return value
    return None


def name(value, seen):
    """The alias, or its occurrence number when the same alias is already in use."""
    seen[value] = seen.get(value, 0) + 1
    return value if seen[value] == 1 else f'{value}#{seen[value]}'


def key_of(index, key, element, seen):
    """The stable name of a list element (key is its index) or a map entry (key is the map's key)."""
    value = alias_of(element)
    if not isinstance(value, str):
        value = key if isinstance(key, (str, int)) else '#' + str(index)
    return name(str(value), seen)


def fields(out, prefix, element, wanted):
    """(field in the save, name in the line) pairs that are plain values; 'None' names are skipped."""
    for key, label in wanted:
        value = at(element, key)
        if isinstance(value, (str, int, float, bool)) and value != 'None':
            out[f'{prefix} {label}'] = value


def leaf_lines(out, prefix, element):
    """Every plain leaf under element, for lists whose shape is not mapped field by field yet."""
    if not isinstance(element, (dict, list)) or not element:
        return
    for path, value in gvas.leaves(element):
        if not path or isinstance(value, (dict, list)) or path.rsplit('.', 1)[-1].split('[', 1)[0] in VOLATILE:
            continue
        out[f'{prefix} {path}'] = value


# (field in the save, name in the line), per kind of element.
QUEST = (('QuestState', 'state'),)
TASK_GROUP = (('TaskGroupState', 'state'),)
TASK = (('TaskState', 'state'), ('CurrentValue', 'value'), ('CompleteOrder', 'order'))
PROGRESS = (('bSuccessTask', 'done'),)
ZONE = (('ZoneObjectState', 'state'),)
ENV = (('EnvActivate', 'activate'), ('EnvActiveState', 'active'), ('EnvStateSlotTag', 'slot'),
       ('CurrentTriggerCount', 'count'))
NPC = (('ObjectState', 'state'), ('LifeState', 'life'), ('bActiveActor', 'active'), ('bHiddenGame', 'hidden'),
       ('SpawnIndex', 'spawn'))
TRIGGER = (('TriggerActivate', 'activate'), ('DoingCount', 'count'))
OBJECT = (('Activate', 'activate'), ('EffectVolumeDeadCount', 'deaths'))


def quests(out, props):
    quest = at(at(props, 'DataMap_SBQuest'), 'Quest')
    if quest is None:
        return
    tracked = {t for t in at(quest, 'TrackingQuestAliases') or [] if isinstance(t, str)}
    seen = {}
    for index, q in entries(at(quest, 'ProgressQuestList')):
        alias = key_of(index, index, q, seen)
        prefix = f'quest {alias}'
        fields(out, prefix, q, QUEST)
        out[f'{prefix} tracked'] = alias.split('#')[0] in tracked
        groups, tasks = {}, {}
        for group_index, group in entries(at(q, 'QuestTaskGroupList')):
            group_alias = key_of(group_index, group_index, group, groups)
            gprefix = f'{prefix} group {group_alias}'
            fields(out, gprefix, group, TASK_GROUP)
            # The group's TaskList (what its panel shows) and AllChildTaskList hold the same tasks; the second is the
            # complete one, so the lines come from it alone.
            for task_index, task in entries(at(group, 'AllChildTaskList')):
                fields(out, f'{gprefix} task {key_of(task_index, task_index, task, tasks)}', task, TASK)
    # The save holds a finished quest's alias as a name in older saves, and as the whole quest struct (QuestAlias,
    # QuestState 3, its task groups) in the saves this game now writes; both name the same line.
    for done, label in (('CompleteQuestList', 'complete'), ('FailedQuestList', 'failed')):
        for _, entry in entries(at(quest, done)):
            alias = entry if isinstance(entry, str) else None
            if alias is None and isinstance(entry, dict):
                alias = at(entry, 'QuestAlias')
            if isinstance(alias, str) and alias:
                out[f'quest {alias} {label}'] = True


def progress(out, props):
    records = at(at(props, 'GamePlayProgressRecordData'), 'ProgressRecordGroup')
    for group_index, group in entries(records):
        group_alias = key_of(group_index, group_index, group, {})
        seen_groups = {}
        for record_key, task_group in entries(at(group, 'RecordTaskGroupMap')):
            record_alias = key_of(record_key, record_key, task_group, seen_groups)
            seen = {}
            for data_index, data in entries(at(task_group, 'TaskDataList')):
                alias = key_of(data_index, data_index, data, seen)
                fields(out, f'progress {group_alias} {record_alias} {alias}', data, PROGRESS)


def zone(out, element):
    alias = alias_of(element)
    if not isinstance(alias, str):
        return
    prefix = f'zone {alias}'
    fields(out, prefix, element, ZONE)
    for list_name, kind, wanted in (('ZoneEnvStorageList', 'env', ENV),
                                    ('ZoneNpcStorageList', 'npc', NPC),
                                    ('ZoneTriggerStorageList', 'trigger', TRIGGER)):
        seen = {}
        for index, item in entries(at(element, list_name)):
            item_prefix = f'{prefix} {kind} {key_of(index, index, item, seen)}'
            fields(out, item_prefix, item, wanted)
            fields(out, item_prefix, at(item, 'InteractData'), (('bInteracted', 'interacted'),))
            if kind == 'env':  # A door's or a console's own progress lists, when it has any.
                for list_name in ('StateInfoList', 'EnvProgressInfo'):
                    leaf_lines(out, item_prefix, at(item, list_name))
    seen = {}
    for key, item in entries(at(element, 'WorldObjectStorageMap')):
        fields(out, f'{prefix} object {key_of(key, key, item, seen)}', item, OBJECT)
    for list_name, kind in (('ZoneEventItemStorageList', 'item'), ('ZoneEventActorStorageList', 'actor')):
        seen = {}
        for index, item in entries(at(element, list_name)):
            leaf_lines(out, f'{prefix} {kind} {key_of(index, index, item, seen)}', item)


def worlds(out, props):
    for index, world in entries(at(at(at(props, 'DataMap_SBEnv'), 'Env'), 'WorldContainerList')):
        alias = alias_of(world)
        if not isinstance(alias, str):
            continue
        seen = {}
        for item_index, item in entries(at(world, 'ZoneEventActorStorageList')):
            leaf_lines(out, f'world {alias} actor {key_of(item_index, item_index, item, seen)}', item)


def story(props):
    """The story and world lines of a parsed save: {line key: value}."""
    out = {}
    quests(out, props)
    progress(out, props)
    env = at(at(props, 'DataMap_SBEnv'), 'Env')
    for _, element in entries(at(env, 'ZoneContainerList')):
        zone(out, element)
    worlds(out, props)
    return out


def lines(state):
    return [f'{key} = {state[key]}' for key in sorted(state)]


def snapshot(properties, prefix=None):
    """The sorted story lines, optionally only those whose key starts with prefix."""
    return [line for line in lines(story(properties))
            if prefix is None or line.split(' = ', 1)[0].startswith(prefix)]


def digest(properties):
    """A SHA-256 over the sorted story lines: the same for two saves whose story state agrees."""
    return hashlib.sha256('\n'.join(lines(story(properties))).encode('utf-8')).hexdigest()


def diff(old, new):
    """The story lines that differ: '~ key: old -> new', '+ key = value' or '- key = value'."""
    a, b = story(old), story(new)
    out = []
    for key in sorted(a.keys() | b.keys()):
        if key not in a:
            out.append(f'+ {key} = {b[key]}')
        elif key not in b:
            out.append(f'- {key} = {a[key]}')
        elif a[key] != b[key]:
            out.append(f'~ {key}: {a[key]} -> {b[key]}')
    return out


def dump_lines(path):
    """A file of story lines as the game's side writes them: sorted, comments (#) and blank lines skipped."""
    with open(path, 'rb') as file:
        data = file.read()
    if b'\0' in data:
        raise ValueError(f'{path} is not a text dump (it holds NUL bytes): a save is read with snapshot or diff')
    text = data.decode('utf-8', 'replace').splitlines()
    return sorted(line.rstrip() for line in text if line.strip() and not line.startswith('#'))


def lines_digest(rows):
    return hashlib.sha256('\n'.join(rows).encode('utf-8')).hexdigest()


def compare(properties, rows):
    """(save lines, the lines only in the dump, the lines only in the save, both digests) for a save and a dump."""
    mine = lines(story(properties))
    added = [line for line in rows if line not in set(mine)]
    removed = [line for line in mine if line not in set(rows)]
    return mine, added, removed, lines_digest(mine), lines_digest(rows)


def read(path):
    return gvas.read(path)[1]


def sample():
    """A parsed save with the shapes this game's save has, for the selftest and the tests."""
    return {
        'DataMap_SBQuest': [['Quest', {
            'ProgressQuestList': [
                {'QuestAlias': 'Quest_Epic_01', 'QuestState': 1, 'QuestTaskGroupList': [
                    {'TaskGroupAlias': 'Quest_Epic_01_M01', 'TaskGroupState': 'TaskGroup_Progress',
                     'AllChildTaskList': [[
                         'Quest_Epic_01_M01_T01', {'TaskAlias': 'Quest_Epic_01_M01_T01',
                                                   'TaskState': 'ESBQuestTaskState_Progress',
                                                   'CurrentValue': 0, 'CompleteOrder': -1}]],
                     'TaskList': [{'TaskAlias': 'Quest_Epic_01_M01_T01', 'TaskState': 'ESBQuestTaskState_Progress',
                                   'CurrentValue': 0, 'CompleteOrder': -1}]}]},
                {'QuestAlias': 'CQ_SD10_RR', 'QuestState': 1}],
            'TrackingQuestAliases': ['Quest_Epic_01'],
            'CompleteQuestList': ['Quest_Epic_00'],
            'FailedQuestList': []}]],
        'GamePlayProgressRecordData': {'ProgressRecordGroup': [[
            'Quest_Epic_01_M01', {'RecordGroupName': 'Quest_Epic_01_M01', 'RecordTaskGroupMap': [[
                'ESBMission_EnvState', {'TaskDataList': [
                    {'DataAlias': 'SD_10_EnvS_010', 'bSuccessTask': False},
                    {'DataAlias': 'SD_10_EnvS_010', 'bSuccessTask': True}]}]]}]]},
        'DataMap_SBEnv': [['Env', {
            'WorldContainerList': [{'WorldAlias': 'NKGameWaste', 'ZoneEventActorStorageList': []},
                                   {'WorldAlias': 'SDS', 'ZoneEventActorStorageList': [
                                       {'ObjectName': 'SDS_EActor_001', 'ObjectState': 'ESBObject_Disable',
                                        'ActorLocation': [1.0, 2.0, 3.0]}]}],
            'ZoneContainerList': [
                {'ZoneAlias': 'Zone_SD_10', 'ZoneObjectState': 'ESBObject_Enable', 'bZoneReset': True,
                 'ZoneEnvStorageList': [
                     {'EnvAlias': 'SD_10_EnvS_067', 'EnvActivate': 'ESBObject_Disable',
                      'EnvActiveState': 'ESBENV_State_None', 'CurrentTriggerCount': 0,
                      'InteractData': {'bInteracted': False}, 'ActorLocation': [1.0, 2.0, 3.0],
                      'LastUpdateTimestamp': 5},
                     {'EnvAlias': 'SD_10_EnvS_066', 'EnvActivate': 'ESBObject_Enable', 'CurrentTriggerCount': 2,
                      'InteractData': {'bInteracted': True}}],
                 'ZoneNpcStorageList': [{'CharacterDataAlias': 'Npc_Shop_01', 'ObjectState': 'ESBObject_Enable',
                                         'LifeState': 1, 'bActiveActor': True, 'InteractData': {'bInteracted': False}}],
                 'ZoneTriggerStorageList': [{'TriggerAlias': 'SD_10_ZTrigger_001',
                                             'TriggerActivate': 'ESBObject_Enable', 'DoingCount': 0}],
                 'ZoneEventItemStorageList': [],
                 'WorldObjectStorageMap': [[0, {'UniqueKey': 'SD_10_EffVol_007', 'Activate': 'ESBObject_Enable'}],
                                           [1, {'UniqueKey': 'SD_10_EffVol_006', 'Activate': 'ESBObject_Disable'}]]},
                {'ZoneAlias': 'Zone_Xion_10', 'ZoneObjectState': 'ESBObject_Enable',
                 'ZoneEnvStorageList': [], 'ZoneNpcStorageList': [], 'ZoneTriggerStorageList': [],
                 'ZoneEventItemStorageList': [], 'WorldObjectStorageMap': []}]}]]}


def selftest():
    props = sample()
    state = story(props)
    assert state['quest Quest_Epic_01 state'] == 1 and state['quest Quest_Epic_01 tracked'] is True, state
    assert state['quest CQ_SD10_RR tracked'] is False and state['quest Quest_Epic_00 complete'] is True, state
    assert state['quest Quest_Epic_01 group Quest_Epic_01_M01 task Quest_Epic_01_M01_T01 value'] == 0, state
    assert state['progress Quest_Epic_01_M01 ESBMission_EnvState SD_10_EnvS_010 done'] is False, state
    assert state['progress Quest_Epic_01_M01 ESBMission_EnvState SD_10_EnvS_010#2 done'] is True, state
    assert state['zone Zone_SD_10 env SD_10_EnvS_067 activate'] == 'ESBObject_Disable', state
    assert state['zone Zone_SD_10 env SD_10_EnvS_066 interacted'] is True, state
    assert state['zone Zone_SD_10 npc Npc_Shop_01 life'] == 1, state
    assert state['zone Zone_SD_10 object SD_10_EffVol_007 activate'] == 'ESBObject_Enable', state
    assert state['world SDS actor SDS_EActor_001 ObjectState'] == 'ESBObject_Disable', state
    assert not [k for k in state if 'Location' in k or 'Timestamp' in k or k.endswith('bZoneReset')], state
    assert lines(state) == sorted(lines(state)) and snapshot(props, 'zone ') != snapshot(props, 'world ')

    def zone_of(properties, alias):
        return next(z for z in properties['DataMap_SBEnv'][0][1]['ZoneContainerList'] if z['ZoneAlias'] == alias)

    other = copy.deepcopy(props)
    # Volatile and per-player changes keep the digest; a story change moves it and shows in the diff.
    zone_of(other, 'Zone_SD_10')['ZoneEnvStorageList'][0]['ActorLocation'] = [9.0, 9.0, 9.0]
    zone_of(other, 'Zone_SD_10')['bZoneReset'] = False
    other['DataMap_SBEnv'][0][1]['ZoneContainerList'].reverse()  # Order is not state.
    assert digest(props) == digest(other) and diff(props, other) == [], diff(props, other)
    other['DataMap_SBQuest'][0][1]['ProgressQuestList'][0]['QuestState'] = 3
    zone_of(other, 'Zone_SD_10')['ZoneEnvStorageList'][0]['EnvActivate'] = 'ESBObject_Enable'
    assert digest(props) != digest(other)
    assert diff(props, other) == [
        '~ quest Quest_Epic_01 state: 1 -> 3',
        '~ zone Zone_SD_10 env SD_10_EnvS_067 activate: ESBObject_Disable -> ESBObject_Enable'], diff(props, other)
    other['DataMap_SBQuest'][0][1]['CompleteQuestList'] = ['Quest_Epic_02']
    assert '- quest Quest_Epic_00 complete = True' in diff(props, other), diff(props, other)
    assert '+ quest Quest_Epic_02 complete = True' in diff(props, other), diff(props, other)
    print('story selftest: ok')


def main(argv):
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(errors='replace')  # A name with an odd byte prints, never crashes on a console's code page.
    if argv[:1] == ['selftest']:
        return selftest()
    if len(argv) in (2, 3) and argv[0] == 'snapshot':
        for line in snapshot(read(argv[1]), argv[2] if len(argv) == 3 else None):
            print(line)
        return 0
    if len(argv) == 3 and argv[0] == 'diff':
        for line in diff(read(argv[1]), read(argv[2])):
            print(line)
        return 0
    if len(argv) == 2 and argv[0] == 'digest':
        print(digest(read(argv[1])))
        return 0
    if len(argv) == 2 and argv[0] == 'digest-lines':
        try:
            print(lines_digest(dump_lines(argv[1])))
        except ValueError as error:
            print(f'story: {error}')
            return 2
        return 0
    if len(argv) == 3 and argv[0] == 'compare':
        try:
            mine, added, removed, theirs, ours = compare(read(argv[1]), dump_lines(argv[2]))
        except ValueError as error:
            print(f'story: {error}')
            return 2
        print(f'save {theirs}  {len(mine)} lines')
        print(f'dump {ours}  {len(mine) + len(added) - len(removed)} lines')
        if not added and not removed:
            print('the same')
            return 0
        for line in added:
            print(f'+ {line}')
        for line in removed:
            print(f'- {line}')
        print(f'{len(added)} only in the dump, {len(removed)} only in the save')
        return 1
    print(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
