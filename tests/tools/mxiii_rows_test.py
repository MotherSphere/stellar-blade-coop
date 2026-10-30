"""tools/mxiii_rows.py: the two generated files match data/mxiii-world.json (--check passes on the tree), every row's
fields are known with their offsets inside the row struct, and the checks refuse data the native part would refuse or
misread: an unknown field, two patches on the same bytes, a batch of 256 rows, a name given twice, a list item with
the separator in it. The data file holds the rows the cooked map's manifest expects: the camps, the three bosses, the
72 warp switches, each switch's event and warp row."""
import copy
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
spec = importlib.util.spec_from_file_location('mxiii_rows', ROOT / 'tools/mxiii_rows.py')
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)

# 1. The tree's generated files are what the data gives.
done = subprocess.run([sys.executable, ROOT / 'tools/mxiii_rows.py', '--check'], capture_output=True, text=True)
assert done.returncode == 0, done.stderr

data = json.loads((ROOT / 'data/mxiii-world.json').read_text())
gen.check(data)
words = [b['word'] for b in data['batches']]
assert words == ['mxiii', 'mxspawn', 'mxenv', 'mxwarp'], words
rows = {(r['table'], r['name']): r for b in data['batches'] for r in b['rows']}


def refused(change):
    bad = copy.deepcopy(data)
    change(bad)
    try:
        gen.check(bad)
    except (AssertionError, KeyError):
        return True
    return False


# 2. What the checks refuse.
assert refused(lambda d: d['batches'][0]['rows'][0]['set'].append(['NoSuchField', 'x', True]))
assert refused(lambda d: d['batches'][0]['rows'][0]['set'].append(['CampType', 2, True]))  # The same bytes again.
assert refused(lambda d: d['batches'][3]['rows'].extend(d['batches'][3]['rows'][:40]))  # 256 rows, names twice.
assert refused(lambda d: d['batches'][1]['rows'].append(d['batches'][0]['rows'][0]))  # A name in two batches.
assert data['batches'][0]['rows'][7]['set'][3][0] == 'LinkEnvSpawnList'
assert refused(lambda d: d['batches'][0]['rows'][7]['set'][3].__setitem__(1, ['A|B']))  # A separator in an item.
assert refused(lambda d: d['batches'][0]['rows'][0]['set'][0].__setitem__(1, 300))  # A byte past 255.
assert refused(lambda d: d['batches'][0]['rows'][0].__setitem__('id', 2 ** 32))

# 3. The rows the cooked map relies on (the manifest's spawn point names and row keys).
for camp in ('DLC02_00_Camp_00', 'DLC02_10_Camp_01', 'DLC02_10_Camp_02', 'DLC02_20_Camp_01', 'DLC02_20_Camp_02',
             'DLC02_20_Camp_03', 'DLC02_20_Camp_04', 'DLC02_30_Camp_01', 'DLC02_30_Camp_02', 'DLC02_30_Camp_03',
             'DLC02_40_Camp_01'):
    assert ('ZoneCampTable', camp) in rows, camp
for boss, char in (('DLC02_20_E_CharS_904', 'M_Gardener'), ('DLC02_30_E_CharS_029', 'MX13_M_Sawshark'),
                   ('DLC02_40_E_CharS_051', 'M_LionC')):
    s = dict((f, v) for f, v, _ in rows[('EventSpawnTable', boss)]['set'])
    assert s['SpawnPointName'] == boss and s['CharacterAlias'] == [char] and s['SaveType'] == 1, boss
switches = [r for (t, n), r in rows.items() if t == 'ZoneEnvSpawnTable' and r['donor'] == 'DLC02_10_EnvS_432']
assert len(switches) == 72
for r in switches:
    s = dict((f, v) for f, v, _ in r['set'])
    event = s['TagEventList2'][0]
    assert s['SpawnPointName'] == r['name'] and event.endswith(r['name'][-3:]), r['name']
    assert ('ZoneEventTable', event) in rows and ('EventZoneWarpTable', event) in rows, event
# Every spawn row the batches add or patch is bound by its own name.
for (t, n), r in rows.items():
    if t == 'EventSpawnTable' and r['donor'] != n:
        assert dict((f, v) for f, v, _ in r['set'])['SpawnPointName'] == n, n
# 4. The generated Lua names every batch and the move and boss lists.
lua = (ROOT / 'mod/StellarCoop/Scripts/cut/mxiii_rows.lua').read_text()
for name in ('R.MXIII={', 'R.MXSPAWN={', 'R.MXENV={', 'R.MXWARP={', 'R.MOVE={', 'R.BOSS={'):
    assert name in lua, name
print('mxiii_rows_test: ok')
