"""tools/mxiii_rows.py: the two generated files match data/mxiii-world.json (--check passes on the tree), every row's
fields are known with their offsets inside the row struct, and the checks refuse data the native part would refuse or
misread: an unknown field, two patches on the same bytes, a batch of 256 rows, a name given twice, a list item with
the separator in it, a string list of one empty item, a row whose strings overflow the native pool. The data file holds
the rows the cooked map's manifest expects: the camps, the three bosses, no warp switch left (only coop mxiii warp's 72
arrival points), the doors that stand open with no opener and the others closed at the start, and the mechanism
rows' names chained: every event a row fires that
the data adds is a ZoneEvent row of the data, every EnvC row the data adds has its ZoneEvent row and targets an env
row."""
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
assert words == ['mxiii', 'mxspawn', 'mxenv', 'mxupper', 'mxmiddle', 'mxlower', 'mxlily', 'mxnames', 'mxrecords'], words
rows = {(r['table'], r['name']): r for b in data['batches'] if b['word'] != 'mxnames' for r in b['rows']}


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
assert refused(lambda d: d['batches'][3]['rows'].extend(d['batches'][3]['rows'][:40]))  # Names twice, in one batch.
assert refused(lambda d: d['batches'][1]['rows'].append(d['batches'][0]['rows'][0]))  # A name in two batches.
assert data['batches'][0]['rows'][7]['set'][3][0] == 'LinkEnvSpawnList'
assert refused(lambda d: d['batches'][0]['rows'][7]['set'][3].__setitem__(1, ['A|B']))  # A separator in an item.
assert refused(lambda d: d['batches'][0]['rows'][0]['set'][0].__setitem__(1, 300))  # A byte past 255.
assert refused(lambda d: d['batches'][0]['rows'][0].__setitem__('id', 2 ** 32))
door = data['batches'][3]['rows'][0]
assert door['set'][10][0] == 'OutTransitSequenceList', door['set'][10]
assert refused(lambda d: d['batches'][3]['rows'][0]['set'][10].__setitem__(1, ['']))  # Would read as no item.
assert refused(lambda d: d['batches'][3]['rows'][0]['set'][10].__setitem__(1, ['/Game/' + 'x' * 2100]))  # The pool.
assert refused(lambda d: d['batches'][3]['rows'][0]['set'][7].__setitem__(1, 'x'))  # A float that is no number.

# 2b. The camp names: the last batch, the 11 camps patched in place on their own IDs, with no other field; each key has
# its entry in game/camp_text.h, and no other batch writes the two fields.
names = next(b['rows'] for b in data['batches'] if b['word'] == 'mxnames')
camps = sorted(n for t, n in rows if t == 'ZoneCampTable')
assert [r['name'] for r in names] == camps and len(camps) == 11
text = (ROOT / 'native/src/game/camp_text.h').read_text()
for r in names:
    assert r['table'] == 'ZoneCampTable' and r['donor'] == r['name'], r['name']
    assert r['id'] == rows[('ZoneCampTable', r['name'])]['id'], r['name']
    assert [s[:2] for s in r['set']] == [['CampName', 'MX13_Camp_' + r['name']],
                                         ['RegionName', 'MX13_Region']], r['name']
    assert f'{{u"MX13_Camp_{r["name"]}", ' in text, r['name']
assert '{u"MX13_Region", ' in text and text.count('{u"MX13_') == 12
assert not [f for r in rows.values() for f, _, _ in r['set'] if f in ('CampName', 'RegionName')]

# 2c. Lily's menu: the three IsInWorld rows name the dungeon's world, each group of the Great Desert branch turns to OR
# (one of its two conditions is that world's, the other the Great Desert actor), shipped rows on their own IDs.
lily = {r['name']: r for b in data['batches'] if b['word'] == 'mxlily' for r in b['rows']}
P = 'Xion01_NPC_Lily_01_'
for name, table, id_, s in ((P + 'IACC__075', 'ConditionTable', 1202, ['CustomStr01', 'DLCMatrix13', True]),
                            (P + 'IACC__073', 'ConditionTable', 1194, ['CustomStr01', 'DLCMatrix13', True]),
                            (P + 'IACC__077', 'ConditionTable', 1204, ['CustomStr01', 'DLCMatrix13', True]),
                            (P + 'ConditionGroup_019', 'ConditionGroupTable', 244, ['ConditionEq', 3, True]),
                            (P + 'ConditionGroup_017', 'ConditionGroupTable', 243, ['ConditionEq', 3, True]),
                            (P + 'ConditionGroup_018', 'ConditionGroupTable', 245, ['ConditionEq', 3, True])):
    r = lily[name]
    assert (r['table'], r['donor'], r['id'], r['set']) == (table, name, id_, [s]), name
assert len(lily) == 6

# 3. The rows the cooked map relies on (the manifest's spawn point names and row keys).
for camp in ('DLC02_00_Camp_00', 'DLC02_10_Camp_01', 'DLC02_10_Camp_02', 'DLC02_20_Camp_01', 'DLC02_20_Camp_02',
             'DLC02_20_Camp_03', 'DLC02_20_Camp_04', 'DLC02_30_Camp_01', 'DLC02_30_Camp_02', 'DLC02_30_Camp_03',
             'DLC02_40_Camp_01'):
    assert ('ZoneCampTable', camp) in rows, camp
    # Its own camp list; the Tetrapod stays in Matrix 11's bucket, so a bucket of its own does not put it past the game's 7 tabs.
    region = dict((f, v) for f, v, _ in rows[('ZoneCampTable', camp)]['set']).get('Region')
    assert region == (None if camp == 'DLC02_00_Camp_00' else 'Matrix13'), camp
# EVE arrives at the Tetrapod with no camp active: its machine is the only camp row that starts Enable with no coin.
# Every other camp names a coin of its own, spawned at the point of its name, and its kit stays off until that coin
# is spent at the vending machine: no kit row changes its donor's start state (Enable, Off on the vending machine,
# Disable, Off on the others).
coins = {}
for (t, n), r in rows.items():
    if t != 'ZoneCampTable':
        continue
    s = dict((f, v) for f, v, _ in r['set'])
    if n == 'DLC02_00_Camp_00':
        assert s.get('CampType') == 4 and 'CoinSpawnPointName' not in s
    else:
        assert s.get('CampType') in (2, 3) and s['CoinSpawnPointName'].startswith(n[:8] + '_E_ItemS_'), n
        coins[n] = s['CoinSpawnPointName']
assert len(coins) == 10 and len(set(coins.values())) == 10
for coin in ('DLC02_10_E_ItemS_014', 'DLC02_20_E_ItemS_022', 'DLC02_30_E_ItemS_029'):  # The rest are the game's rows.
    assert coin in coins.values(), coin
    s = dict((f, v) for f, v, _ in rows[('EventItemTable', coin)]['set'])
    assert s['SpawnPointName'] == coin and s.get('Zone', 'Zone_DLC02_10') == 'Zone_' + coin[:8], coin  # Donor: zone 10.
for (t, n), r in rows.items():
    s = dict((f, v) for f, v, _ in r['set'])
    if t == 'ZoneEnvSpawnTable' and s.get('TargetCamp') in coins:
        assert 'InitActivate' not in s and 'InitStateTag' not in s, n
for boss, char in (('DLC02_20_E_CharS_904', 'M_Gardener'), ('DLC02_30_E_CharS_029', 'MX13_M_Sawshark'),
                   ('DLC02_40_E_CharS_051', 'M_LionC')):
    s = dict((f, v) for f, v, _ in rows[('EventSpawnTable', boss)]['set'])
    assert s['SpawnPointName'] == boss and s['CharacterAlias'] == [char] and s['SaveType'] == 1, boss
# No warp switch, event or warp row is left; coop mxiii warp keeps the 72 arrival points.
assert not [n for (t, n) in rows if t == 'EventZoneWarpTable' or '_E_ZoneWarp_' in n]
assert not [n for (t, n) in rows if t == 'ZoneEnvSpawnTable' and n[-3:].isdigit() and 970 <= int(n[-3:]) <= 993]
assert len(data['warp']) == 72 and [w['n'] for w in data['warp']] == list(range(1, 73))
assert all(w['name'].startswith('DLC02_') and '_WarpPoint_' in w['name'] for w in data['warp'])
# Each camp holds the kit of its shipped type. A full camp (ME03_Camp_01): the base at the point of its row's name, skill
# machine, chair, storage, turntable, phone and vending machine. A simple camp (ME01_Camp_02): skill machine, chair,
# turntable and the small vending machine, no base, storage or phone. Every object row spawns its blueprint at the point
# of its own name, the vending machine links all the others in the shipped order, and it is its own shop. No value names
# SE_02_EnvS_010, the trophy row the DLC02 kits inherit their shop from.
ZE = '/Game/GameDesign/Level/ZoneEnv/'
KIT = {'Env_Camp_SkillMachine', 'Env_Camp_Chair', 'Env_Camp_Turntable'}
FULL = {'DLC02_10_Camp_01': ('906', '900', '901 902 900 903 904 905'),
        'DLC02_20_Camp_01': ('049', '048', '043 044 048 045 046 047'),
        'DLC02_20_Camp_04': ('111', '110', '105 106 110 107 108 109'),
        'DLC02_30_Camp_03': ('030', '033', '031 032 033 034 035 036'),
        'DLC02_40_Camp_01': ('009', '015', '010 011 015 012 013 014')}
SIMPLE = {'DLC02_10_Camp_02': ('426', '420 421 423'), 'DLC02_20_Camp_02': ('062', '056 057 059'),
          'DLC02_20_Camp_03': ('074', '068 069 071'), 'DLC02_30_Camp_01': ('004', '005 006 007'),
          'DLC02_30_Camp_02': ('008', '009 010 011')}
assert set(FULL) | set(SIMPLE) == set(coins)
for camp, parts in {**FULL, **{c: (v, None, l) for c, (v, l) in SIMPLE.items()}}.items():
    vend, base, links = parts
    env = camp[:8] + '_EnvS_'
    want = [env + n for n in links.split()]
    machine = dict((f, v) for f, v, _ in rows[('ZoneEnvSpawnTable', env + vend)]['set'])
    assert machine['LinkEnvSpawnList'] == want and machine['ShopDataList'] == [env + vend], camp
    assert machine['EnvBPPath'] == ZE + ('Env_VendingMachine.Env_VendingMachine_C' if base
                                         else 'Env_VendingMachine_Simple.Env_VendingMachine_Simple_C'), camp
    assert len(want) == (6 if base else 3), camp
    classes = set()
    for n in want + [env + vend]:
        s = dict((f, v) for f, v, _ in rows[('ZoneEnvSpawnTable', n)]['set'])
        assert s['TargetCamp'] == camp and s['SpawnPointName'] == n and s['EnvBPPath'].startswith(ZE), n
        classes.add(s['EnvBPPath'][len(ZE):].split('.')[0])
    assert classes - {'Env_VendingMachine', 'Env_VendingMachine_Simple'} == (
        KIT | {'Env_Camp_Base', 'Env_Camp_Storage', 'Env_Camp_TeleportMachine'} if base else KIT), camp
assert not [n for (t, n), r in rows.items() if t == 'ZoneEnvSpawnTable' and 'SE_02_EnvS_010' in str(r['set'])]
# Every door the data adds has its four sequences at the spawn point of its own name. Eleven start closed: the R12 and
# zone 4 shortcut doors, opened from one side, the control room door, opened once E10 is dead, and the car 9 airlock's
# inner door. The others start open: the 34 doors with no opener row (the 14 arena doors among them close by their
# arena lock and are ResetZone rows, so a death puts them back to Open), the airlock's outer door (its panel shuts it
# before the inner one opens) and the zone 3 pressure door (trigger 601 shuts it behind EVE).
CLOSED = {'DLC02_10_EnvS_610', 'DLC02_20_EnvS_609', 'DLC02_40_EnvS_601', 'DLC02_40_EnvS_602', 'DLC02_40_EnvS_603',
          'DLC02_40_EnvS_604', 'DLC02_40_EnvS_605', 'DLC02_40_EnvS_608', 'DLC02_40_EnvS_609', 'DLC02_40_EnvS_610',
          'DLC02_40_EnvS_611'}
ARENA = {'DLC02_30_EnvS_6%02d' % n for n in (2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 16)} | {'DLC02_40_EnvS_607'}
added = {n: r for (t, n), r in rows.items() if r['donor'] != n}
doors = [r for r in added.values() if dict((f, v) for f, v, _ in r['set']).get('EnvAlias') == 'Env_Countdown_Gate']
assert len(doors) == 47
for r in doors:
    s = dict((f, v) for f, v, _ in r['set'])
    start = 'Close' if r['name'] in CLOSED else 'Open'
    assert s['InitStateTag'] == start and s['SpawnPointName'] == r['name'], r['name']
    assert (s['SaveType'] == 2) == (r['name'] in ARENA), r['name']
    assert len(s['OutTransitSequenceList']) == 2 and all(p.startswith('/Game/MXIII_Editor/Seq/MX13_' + r['name'])
                                                         for p in s['ActiveSequenceList']), r['name']
# The names chained: what a data row fires, the EnvC rows and the env rows they drive.
fired = set()
for (t, n), r in rows.items():
    for f, v, _ in r['set']:
        if f.startswith('TagEventList') or f in ('TouchEvents', 'EventOnDead', 'EventOnBattle',
                                                   'EventFirstTimeOnBattle'):
            fired.update(v)
envc = {n for (t, n) in rows if t == 'EventEnvControlTable'}
zevents = {n for (t, n) in rows if t == 'ZoneEventTable'}
assert envc and envc <= zevents, sorted(envc - zevents)[:5]
assert {e for e in fired if '_E_EnvC_6' in e or '_E_EnvC_7' in e} <= zevents
for n in envc:
    target = dict((f, v) for f, v, _ in rows[('EventEnvControlTable', n)]['set'])['EnvSpawnAlias']
    assert ('ZoneEnvSpawnTable', target) in rows or target.startswith('DLC02_'), (n, target)
# The arena locks: the Lion's spawn row shuts its doors on battle and opens them on its death.
lion = dict((f, v) for f, v, _ in rows[('EventSpawnTable', 'DLC02_40_E_CharS_051')]['set'])
assert lion['EventOnBattle'] and lion['EventOnDead'] and set(lion['EventOnBattle']) <= zevents
# Every spawn row the batches add or patch is bound by its own name.
for (t, n), r in rows.items():
    if t == 'EventSpawnTable' and r['donor'] != n:
        assert dict((f, v) for f, v, _ in r['set'])['SpawnPointName'] == n, n
# 4. The generated Lua names every batch and the move, boss, warp and break lists.
lua = (ROOT / 'mod/StellarCoop/Scripts/matrix13/world/rows.lua').read_text()
for name in ('R.MXIII={', 'R.MXSPAWN={', 'R.MXENV={', 'R.MXUPPER={', 'R.MXMIDDLE={', 'R.MXLOWER={', 'R.MOVE={',
             'R.BOSS={', 'R.WARP={', 'R.BREAK={'):
    assert name in lua, name
print('mxiii_rows_test: ok')

# The records: 25 of each kind chained: an env row at the map's spawn point of its name, its text in the puzzle row it
# names, the unlock that fires on its CallPuzzle state and progresses no trophy, the Data Bank row on that unlock with no
# popup (reading it shows the text), and the words game/camp_text.h adds.
records = next(b['rows'] for b in data['batches'] if b['word'] == 'mxrecords')
by = {}
for r in records:
    by.setdefault(r['table'], {})[r['name']] = r
assert all(len(by[t]) == 25 for t in ('AlbumTable', 'AchievementTable', 'PuzzleStringArrayTable', 'ZoneEnvSpawnTable'))
assert [r['table'] for r in records[:50:25]] == ['PuzzleStringArrayTable', 'AchievementTable'], 'no row names a later one'
text = (ROOT / 'native/src/game/record_text.h').read_text()
field = lambda r: {f: v for f, v, _ in r['set']}
ids = [r['id'] for r in by['ZoneEnvSpawnTable'].values()]
assert len(set(ids)) == 25
groups = {}
for name, album in by['AlbumTable'].items():
    a = field(album)
    assert name.startswith('Records_MX13_') and a['Name'] == name + '_Title' and a['Desc'] == name + '_Desc'
    assert a['PopupWhenUnlock'] == 0 and a['PauseWhenPopup'] == 0 and a['AchievementPopup'] == 'None'
    groups[a['GroupName']] = groups.get(a['GroupName'], 0) + 1
    assert 10700 <= album['id'] <= 10724
    unlock = field(by['AchievementTable'][a['AchievementUnlocked']])
    assert 280900 <= by['AchievementTable'][a['AchievementUnlocked']]['id'] <= 280924
    assert unlock['ProgressAchievementOnCompleted'] == 'None' and unlock['ProgressAchievementValueOnCompleted'] == 0
    assert unlock['ProgressAchievementOnCompleted2'] == 'None' and unlock['ProgressAchievementArrayOnCompleted'] == []
    assert by['AchievementTable'][a['AchievementUnlocked']]['donor'] == 'Ach_Album_Unlock_Item_Records_ME01_Memory_01'
    env = by['ZoneEnvSpawnTable'][unlock['ParamValue1']]
    e = field(env)
    assert e['PuzzleInputText1'] == name and e['SpawnPointName'] == env['name'] and e['EnvActorName'] == env['name']
    if env['donor'] == 'DED10_EnvS_168':  # The donor's Legion_Drown reward on its On state stays behind.
        assert e['RewardTagName1'] == 'None' and e['State_RewardGroup1'] == 'None', env['name']
    assert field(by['PuzzleStringArrayTable'][name])['StringArray'] == [name + '_Title', name + '_Desc']
    assert f'u"{name}_Title"' in text and f'u"{name}_Desc"' in text
assert groups == {'MX13_Region': 7, 'UI_Album_Document_Category_Message': 5, 'UI_Album_Document_Category_Guide': 5,
                  'UI_Album_Document_Category_Log': 8}, groups
