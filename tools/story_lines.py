#!/usr/bin/env python3
"""Turns a Stellar Blade save into its story lines (docs/story.md): one sorted `key = value` line per quest, task,
mission record, zone, zone object and event actor value, in the format the mod's `coop story` writes to
StellarCoopStory.txt, so two saves, or a save and an in-game dump, can be compared line by line. Read only.

  python3 tools/story_lines.py snapshot SAVE [PREFIX]  the lines, those whose key starts with PREFIX
  python3 tools/story_lines.py diff OLD NEW            ~ changed, + only in NEW, - only in OLD, sorted by key
  python3 tools/story_lines.py digest SAVE             the SHA-256 of the lines
  python3 tools/story_lines.py digest-lines FILE       the same over a file of lines, such as StellarCoopStory.txt
  python3 tools/story_lines.py compare SAVE FILE       each digest, the unmatched lines; exit 0 if all match, else 1
  python3 tools/story_lines.py selftest

mod/StellarCoop/Scripts/story/snapshot.lua builds the same lines from the game's memory; both are held to
tests/tools/story_case.txt.
"""
import hashlib
import sys

from save_read import Map, diff, read_file, text, walk

USE = ('Use: story_lines.py snapshot SAVE [PREFIX] | diff OLD NEW | digest SAVE | digest-lines FILE | compare SAVE FILE '
       '| selftest')
# The fields that name an entry, first found first.
NAMING = ('ZoneAlias', 'EnvAlias', 'TriggerAlias', 'QuestAlias', 'TaskGroupAlias', 'TaskAlias', 'CharacterDataAlias',
          'UniqueKey', 'WorldAlias', 'ObjectName', 'RecordGroupName', 'DataAlias', 'Alias')
DROPPED = {'ActorLocation', 'ActorRotation', 'QuestMarkerLocation', 'LastUpdateTimestamp'}  # In path lines.
# The labelled fields of each kind of entry: a dotted path below the entry, and its label.
RECORD = {'bSuccessTask': 'done'}
QUEST = {'QuestState': 'state'}
GROUP = {'TaskGroupState': 'state'}
TASK = {'CompleteOrder': 'order', 'CurrentValue': 'value', 'TaskState': 'state'}
ZONE = {'ZoneObjectState': 'state'}
ENV = {'CurrentTriggerCount': 'count', 'EnvActivate': 'activate', 'EnvActiveState': 'active', 'EnvStateSlotTag': 'slot',
       'InteractData.bInteracted': 'interacted'}
NPC = {'bActiveActor': 'active', 'bHiddenGame': 'hidden', 'InteractData.bInteracted': 'interacted',
       'LifeState': 'life', 'ObjectState': 'state', 'SpawnIndex': 'spawn'}
OBJECT = {'Activate': 'activate', 'EffectVolumeDeadCount': 'deaths'}
TRIGGER = {'DoingCount': 'count', 'InteractData.bInteracted': 'interacted', 'TriggerActivate': 'activate'}
# A zone's containers: the key word, the save field, and either the labels of an entry and the fields under it that
# give path lines, or None: every plain value of the entry is a path line.
PARTS = (('actor', 'ZoneEventActorStorageList', None, ()),
         ('env', 'ZoneEnvStorageList', ENV, ('StateInfoList', 'EnvProgressInfo')),
         ('item', 'ZoneEventItemStorageList', None, ()),
         ('npc', 'ZoneNpcStorageList', NPC, ()),
         ('object', 'WorldObjectStorageMap', OBJECT, ()),
         ('trigger', 'ZoneTriggerStorageList', TRIGGER, ()))


def plain(value):
    return isinstance(value, (bool, int, float, str))


def get(entry, path):
    """The value at a dotted path of struct fields below entry, or None."""
    for name in path.split('.'): entry = entry.get(name) if isinstance(entry, dict) else None
    return entry


def keyed(container, key):
    """The value under key in a map: its first entry with that key."""
    if isinstance(container, Map): return next((v for k, v in container if k == key), None)
    return get(container, key)


def name_field(entry):
    if isinstance(entry, str): return entry
    found = (get(entry, field) for field in NAMING)
    return next((v for v in found if isinstance(v, str) and v != 'None'), None)


def entries(container, counts=None):
    """(name, name before numbering, entry) of each entry of a list or map, in save order. An entry is named by its
    naming field, else by its string or integer map key, else by its position. counts is the numbering scope, shared
    by the calls it covers: in it, the n-th entry of one name (n >= 2) gets #n. None: no numbering."""
    if isinstance(container, Map): items = [(True, k, v) for k, v in container]
    elif isinstance(container, list): items = [(False, None, v) for v in container]
    else: return
    for at, (in_map, key, entry) in enumerate(items):
        name = name_field(entry)
        if name is None and in_map:
            name = str(key) if isinstance(key, (str, int)) and not isinstance(key, bool) else f'#{key}'
        if name is None: name = str(at)
        numbered = name
        if counts is not None:
            counts[name] = counts.get(name, 0) + 1
            if counts[name] > 1: numbered = f'{name}#{counts[name]}'
        yield numbered, name, entry


def label_lines(out, prefix, entry, fields):
    for path, label in fields.items():
        value = get(entry, path)
        if plain(value) and value != 'None': out[f'{prefix} {label}'] = text(value)


def path_lines(out, prefix, value):
    """One line per plain value under value, keyed by its path below it; dropped names, lists and maps give none."""
    for path, field, inner in walk(value):
        if path and field not in DROPPED and not isinstance(inner, list): out[f'{prefix} {path}'] = text(inner)


def finished(out, done, word):
    """quest <alias> <word> = True for each entry of a finished or failed list: a name, or a record's QuestAlias."""
    if isinstance(done, Map) or not isinstance(done, list): return
    for entry in done:
        alias = get(entry, 'QuestAlias') if isinstance(entry, dict) else entry
        if isinstance(alias, str) and alias: out[f'quest {alias} {word}'] = 'True'


def quests(out, data):
    quest = keyed(data, 'Quest')
    finished(out, get(quest, 'CompleteQuestList'), 'complete')
    finished(out, get(quest, 'FailedQuestList'), 'failed')
    tracking = get(quest, 'TrackingQuestAliases')
    for name, base, entry in entries(get(quest, 'ProgressQuestList'), {}):
        prefix = f'quest {name}'
        label_lines(out, prefix, entry, QUEST)
        out[f'{prefix} tracked'] = str(isinstance(tracking, list) and base in tracking)
        tasks = {}  # Tasks are numbered across all the quest's groups.
        for group, _, g in entries(get(entry, 'QuestTaskGroupList'), {}):
            label_lines(out, f'{prefix} group {group}', g, GROUP)
            for task, _, t in entries(get(g, 'AllChildTaskList'), tasks):
                label_lines(out, f'{prefix} group {group} task {task}', t, TASK)


def records(out, data):
    for group, _, g in entries(get(data, 'ProgressRecordGroup')):
        for mission, _, m in entries(get(g, 'RecordTaskGroupMap'), {}):
            for record, _, r in entries(get(m, 'TaskDataList'), {}):
                label_lines(out, f'progress {group} {mission} {record}', r, RECORD)


def has_alias(entry, field):
    alias = get(entry, field)
    return isinstance(alias, str) and alias != 'None'


def zone(out, entry):
    """The lines of one zone, if it has a ZoneAlias."""
    if not has_alias(entry, 'ZoneAlias'): return
    prefix = f'zone {name_field(entry)}'
    label_lines(out, prefix, entry, ZONE)
    for word, field, fields, below in PARTS:
        for name, _, e in entries(get(entry, field), {}):
            key = f'{prefix} {word} {name}'
            if fields is None: path_lines(out, key, e)
            else: label_lines(out, key, e, fields)
            for inner in below: path_lines(out, key, get(e, inner))


def worlds(out, data):
    for world, _, w in entries(data):
        if not has_alias(w, 'WorldAlias'): continue
        for name, _, a in entries(get(w, 'ZoneEventActorStorageList'), {}):
            path_lines(out, f'world {world} actor {name}', a)


def story(tree):
    """{key: text} of a parsed save's story; of two lines with one key, the last."""
    out = {}
    quests(out, tree.get('DataMap_SBQuest'))
    records(out, tree.get('GamePlayProgressRecordData'))
    env = keyed(tree.get('DataMap_SBEnv'), 'Env')
    for _, _, z in entries(get(env, 'ZoneContainerList')): zone(out, z)
    worlds(out, get(env, 'WorldContainerList'))
    return out


def lines(tree):
    return sorted(f'{k} = {v}' for k, v in story(tree).items())


def digest(sorted_lines):
    return hashlib.sha256('\n'.join(sorted_lines).encode()).hexdigest()


def file_lines(path):
    """A dump file's lines, sorted: UTF-8 (bad bytes replaced), trailing white space cut, blank and # lines left out."""
    with open(path, 'rb') as f: data = f.read()
    if b'\0' in data: raise ValueError(f'{path} holds a NUL byte: not a file of lines')
    kept = []
    for raw in data.decode('utf-8', 'replace').split('\n'):
        line = raw.rstrip()
        if line and line[0] != '#': kept.append(line)
    kept.sort()
    return kept


def fail(message):
    print(f'story_lines: {message}', file=sys.stderr)
    return 2


def compare(save, dump):
    try:
        ours = lines(read_file(save)[1])
    except (OSError, ValueError) as e:
        return fail(f'{save}: {e}')
    try:
        theirs = file_lines(dump)
    except (OSError, ValueError) as e:
        return fail(str(e))
    print(f'save {digest(ours)} {len(ours)} lines')
    print(f'dump {digest(theirs)} {len(theirs)} lines')
    if ours == theirs:
        print('same story: every line matches')
        return 0
    in_save, in_dump = set(ours), set(theirs)
    extra, missing = [x for x in theirs if x not in in_save], [x for x in ours if x not in in_dump]
    for line in extra: print(f'+ {line}')
    for line in missing: print(f'- {line}')
    print(f'{len(extra)} dump lines not in the save, {len(missing)} save lines not in the dump')
    return 1


def selftest():
    tree = {'DataMap_SBQuest': Map([('Quest', {'ProgressQuestList': [{'QuestAlias': 'Q', 'QuestState': 1}] * 2,
                                               'TrackingQuestAliases': ['Q'], 'CompleteQuestList': ['P']})]),
            'DataMap_SBEnv': Map([('Env', {'ZoneContainerList': [{'ZoneAlias': 'Z', 'ZoneObjectState': 'On',
                                                                  'WorldObjectStorageMap': Map([(5, {'Activate': 'X'})])}]})])}
    assert lines(tree) == ['quest P complete = True', 'quest Q state = 1', 'quest Q tracked = True', 'quest Q#2 state = 1',
                           'quest Q#2 tracked = True', 'zone Z object 5 activate = X', 'zone Z state = On'], lines(tree)
    print('story_lines selftest: ok')
    return 0


def main(argv=None):
    args = sys.argv[1:] if argv is None else argv
    command, rest = (args[0], args[1:]) if args else ('', [])
    if command == 'snapshot' and len(rest) in (1, 2):
        prefix = rest[1] if len(rest) == 2 else ''
        for line in lines(read_file(rest[0])[1]):
            if line.split(' = ', 1)[0].startswith(prefix): print(line)
        return 0
    if command == 'diff' and len(rest) == 2:
        for line in diff(story(read_file(rest[0])[1]), story(read_file(rest[1])[1])): print(line)
        return 0
    if command == 'digest' and len(rest) == 1:
        print(digest(lines(read_file(rest[0])[1])))
        return 0
    if command == 'digest-lines' and len(rest) == 1:
        try:
            print(digest(file_lines(rest[0])))
        except (OSError, ValueError) as e:
            return fail(str(e))
        return 0
    if command == 'compare' and len(rest) == 2: return compare(*rest)
    if command == 'selftest' and not rest: return selftest()
    print(USE)
    return 2


if __name__ == '__main__':
    sys.stdout.reconfigure(errors='replace')
    sys.exit(main())
