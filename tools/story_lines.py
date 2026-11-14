#!/usr/bin/env python3
"""Turns a Stellar Blade save into its story lines (docs/story.md): one sorted `key = value` line per quest, task,
mission record, zone, zone object and event actor value, in the format the mod's `coop story` writes to
StellarCoopStory.txt, so two saves, or a save and an in-game dump, can be compared line by line. Read only.

  python3 tools/story_lines.py snapshot SAVE [PREFIX]  the lines, those whose key starts with PREFIX
  python3 tools/story_lines.py diff OLD NEW            ~ changed, + only in NEW, - only in OLD, sorted by key
  python3 tools/story_lines.py digest SAVE             the SHA-256 of the lines
  python3 tools/story_lines.py digest-lines FILE       the same over a file of lines, such as StellarCoopStory.txt
  python3 tools/story_lines.py compare SAVE FILE       a save's lines against a dump's: exit 0 same, 1 different
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
INTERACTED = (('InteractData', 'bInteracted'), 'interacted')
RECORD = [(('bSuccessTask',), 'done')]
QUEST = [(('QuestState',), 'state')]
GROUP = [(('TaskGroupState',), 'state')]
TASK = [(('CompleteOrder',), 'order'), (('TaskState',), 'state'), (('CurrentValue',), 'value')]
ZONE = [(('ZoneObjectState',), 'state')]
ENV = [(('EnvActivate',), 'activate'), (('EnvActiveState',), 'active'), (('CurrentTriggerCount',), 'count'),
       (('EnvStateSlotTag',), 'slot'), INTERACTED]
NPC = [(('bActiveActor',), 'active'), (('bHiddenGame',), 'hidden'), (('LifeState',), 'life'), (('SpawnIndex',), 'spawn'),
       (('ObjectState',), 'state'), INTERACTED]
OBJECT = [(('Activate',), 'activate'), (('EffectVolumeDeadCount',), 'deaths')]
TRIGGER = [(('TriggerActivate',), 'activate'), (('DoingCount',), 'count'), INTERACTED]


def plain(value):
    return isinstance(value, (bool, int, float, str))


def get(entry, *names):
    for name in names: entry = entry.get(name) if isinstance(entry, dict) else None
    return entry


def keyed(container, key):
    """The value under key in a map: its first entry with that key."""
    if isinstance(container, Map): return next((v for k, v in container if k == key), None)
    return get(container, key)


def name_field(entry):
    if isinstance(entry, str): return entry
    for field in NAMING:
        value = get(entry, field)
        if isinstance(value, str) and value != 'None': return value
    return None


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


def labels(out, prefix, entry, table):
    for field, label in table:
        value = get(entry, *field)
        if plain(value) and value != 'None': out[f'{prefix} {label}'] = text(value)


def path_lines(out, prefix, value):
    """One line per plain value under value, keyed by its path below it; dropped names, lists and maps give none."""
    for path, field, inner in walk(value):
        if path and field not in DROPPED and not isinstance(inner, list): out[f'{prefix} {path}'] = text(inner)


def quests(out, data):
    quest = keyed(data, 'Quest')
    tracked = {a for a in get(quest, 'TrackingQuestAliases') or [] if isinstance(a, str)}
    for name, base, entry in entries(get(quest, 'ProgressQuestList'), {}):
        prefix = f'quest {name}'
        labels(out, prefix, entry, QUEST)
        out[f'{prefix} tracked'] = str(base in tracked)
        tasks = {}  # Tasks are numbered across all the quest's groups.
        for group, _, g in entries(get(entry, 'QuestTaskGroupList'), {}):
            labels(out, f'{prefix} group {group}', g, GROUP)
            for task, _, t in entries(get(g, 'AllChildTaskList'), tasks):
                labels(out, f'{prefix} group {group} task {task}', t, TASK)
    for field, word in (('CompleteQuestList', 'complete'), ('FailedQuestList', 'failed')):
        done = get(quest, field)
        for entry in done if isinstance(done, list) and not isinstance(done, Map) else []:
            alias = entry if isinstance(entry, str) else get(entry, 'QuestAlias')
            if isinstance(alias, str) and alias: out[f'quest {alias} {word}'] = 'True'


def records(out, data):
    for group, _, g in entries(get(data, 'ProgressRecordGroup')):
        for mission, _, m in entries(get(g, 'RecordTaskGroupMap'), {}):
            for record, _, r in entries(get(m, 'TaskDataList'), {}):
                labels(out, f'progress {group} {mission} {record}', r, RECORD)


def zone(out, entry):
    """The lines of one zone, if it has a ZoneAlias."""
    alias = get(entry, 'ZoneAlias')
    if not isinstance(alias, str) or alias == 'None': return
    prefix = f'zone {name_field(entry)}'
    labels(out, prefix, entry, ZONE)
    for word, field, table in (('env', 'ZoneEnvStorageList', ENV), ('npc', 'ZoneNpcStorageList', NPC),
                               ('trigger', 'ZoneTriggerStorageList', TRIGGER)):
        for name, _, e in entries(get(entry, field), {}):
            labels(out, f'{prefix} {word} {name}', e, table)
            if word == 'env':
                path_lines(out, f'{prefix} env {name}', get(e, 'StateInfoList'))
                path_lines(out, f'{prefix} env {name}', get(e, 'EnvProgressInfo'))
    for name, _, e in entries(get(entry, 'WorldObjectStorageMap'), {}):
        labels(out, f'{prefix} object {name}', e, OBJECT)
    for word, field in (('item', 'ZoneEventItemStorageList'), ('actor', 'ZoneEventActorStorageList')):
        for name, _, e in entries(get(entry, field), {}):
            path_lines(out, f'{prefix} {word} {name}', e)


def worlds(out, data):
    for world, _, w in entries(data):
        alias = get(w, 'WorldAlias')
        if not isinstance(alias, str) or alias == 'None': continue
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
    stripped = (line.rstrip() for line in data.decode('utf-8', 'replace').split('\n'))
    return sorted(line for line in stripped if line and not line.startswith('#'))


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
