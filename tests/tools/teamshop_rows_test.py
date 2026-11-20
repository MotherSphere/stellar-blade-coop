# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""tools/teamshop_rows.py: the two generated files match data/teamshop/ (--check passes on the tree). The batch holds
every ItemTable row, then every ShopItemTable row, then the one ShopTable row SBOTeam_Shop. The checks refuse a
contributor's mistakes: an alias without the SBOTeam_ prefix, an ID range at or under the shipped maximum, two owners
with the same alias or overlapping ranges, a field off the allow-list, non-ASCII text, a NanoSuit the shop screen would
sell twice (MaxAmount above 1, an InventoryAlias or a MaxAmountOverrideActorStat), an unread donor, a price other than
one in gold, a batch of 256 rows, a range too small for its items. lua5.4 loads the Lua file as the game does."""
import copy
import importlib.util
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
spec = importlib.util.spec_from_file_location('teamshop_rows', ROOT / 'tools/teamshop_rows.py')
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)

# 1. The tree's generated files are what the data gives.
done = subprocess.run([sys.executable, ROOT / 'tools/teamshop_rows.py', '--check'], capture_output=True, text=True)
assert done.returncode == 0, done.stderr

owners = gen.load(ROOT / 'data/teamshop')
gen.check(owners)
rows = gen.rows(owners)
assert [r['table'] for r in rows][-1] == 'ShopTable' and rows[-1]['name'] == gen.SHOP
assert {r['table'] for r in rows} == {'ItemTable', 'ShopItemTable', 'ShopTable'} and len(rows) < 256
tables = [r['table'] for r in rows]
assert tables == sorted(tables, key=['ItemTable', 'ShopItemTable', 'ShopTable'].index), tables


def refused(change):
    bad = copy.deepcopy(owners)
    change(bad)
    try:
        gen.check(bad)
    except (AssertionError, KeyError):
        return True
    return False


# 2. What the checks refuse, each next to the nearest data they let through. The cases take their counts and ranges
# from the data, so a new item or owner needs no edit here.
assert refused(lambda o: o[0]['items'][0].update(alias='GothicRose'))                     # no prefix
assert refused(lambda o: o[0]['items'][0].update(alias='SBOTeam_Gothic Rose'))            # a space
assert refused(lambda o: o[0]['ids'].update(ItemTable=[1, 999]))                           # under the shipped max
# The owner with the lowest ItemTable range: moved down to start next to the shipped max, it overlaps nobody.
low = min(range(len(owners)), key=lambda k: owners[k]['ids']['ItemTable'][0])
held = len(owners[low]['items'])
assert refused(lambda o: o[low]['ids'].update(ItemTable=[2000151, 2000150 + held]))       # the shipped max itself
assert not refused(lambda o: o[low]['ids'].update(ItemTable=[2000152, 2000151 + held]))
assert refused(lambda o: o[0]['ids'].update(ShopItemTable=[9007, 9100]))
assert refused(lambda o: o[0]['ids'].update(ItemTable=[2001999, 2001000]))                 # last before first
assert refused(lambda o: o[0]['ids'].update(ItemTable=[2 ** 32 - 1, 2 ** 32]))             # past a uint32
assert refused(lambda o: o.append(dict(copy.deepcopy(o[0]), owner='other')))              # same alias, same ranges
# A new owner above every owner's ranges, with one item.
top = {t: max(o['ids'][t][1] for o in owners) for t in ('ItemTable', 'ShopItemTable')}
other = {'owner': 'other', 'ids': {t: [top[t] + 1, top[t] + 1000] for t in top},
         'items': [dict(copy.deepcopy(owners[0]['items'][0]), alias='SBOTeam_Other')]}
assert not refused(lambda o: o.append(copy.deepcopy(other)))
assert refused(lambda o: o.append(dict(copy.deepcopy(other), owner=o[0]['owner'])))       # the same owner twice
assert refused(lambda o: o.append(dict(copy.deepcopy(other), items=copy.deepcopy(o[0]['items']))))  # same alias
assert refused(lambda o: o.append(dict(copy.deepcopy(other),                               # overlapping ranges
                                       ids={'ItemTable': [o[0]['ids']['ItemTable'][1], other['ids']['ItemTable'][1]],
                                            'ShopItemTable': other['ids']['ShopItemTable']})))
assert refused(lambda o: o.append(dict(copy.deepcopy(other),
                                       ids={'ItemTable': other['ids']['ItemTable'],
                                            'ShopItemTable': [o[0]['ids']['ShopItemTable'][0]] * 2})))
assert refused(lambda o: o[0]['items'][0]['set'].update(CheckCondition='X'))              # off the allow-list
assert refused(lambda o: o[0]['items'][0]['set'].update(Name='Gothic Rosé'))              # not ASCII
assert refused(lambda o: o[0]['items'][0]['set'].update(MaxAmount=2))                     # category 4 above 1
assert not refused(lambda o: o[0]['items'][0]['set'].update(Category=20, MaxAmount=2))
assert refused(lambda o: o[0]['items'][0]['set'].update(InventoryAlias='BS_Default'))     # held under another key
assert refused(lambda o: o[0]['items'][0]['set'].update(MaxAmountOverrideActorStat=3))    # MaxAmount from a stat
assert refused(lambda o: o[0]['items'][0].update(donor='BS_Default'))                     # a donor never read
assert refused(lambda o: o[0]['items'][0]['set'].update(Category=300))                    # past a byte
assert refused(lambda o: o[0]['items'][0]['set'].update(EquipmentAlias='BS"1000'))        # ends a C++ literal
assert refused(lambda o: o[0]['items'][0].update(price={'Money_NightOperation': 5}))      # not gold
assert refused(lambda o: o[0]['items'][0]['price'].update(Gold2=1))                       # two prices
assert refused(lambda o: o[0]['items'][0].update(price={'BetaCrystal': 0}))
assert refused(lambda o: o[0]['items'][0].update(price={'BetaCrystal': 1000000}))
assert refused(lambda o: o[0]['items'][0].update(price={'BetaCrystal': 5.5}))
assert refused(lambda o: o[0]['items'][0].update(price={'BetaCrystal': '5000'}))
assert not refused(lambda o: o[0]['items'][0].update(price={'BetaCrystal': 999999}))
total = sum(len(o['items']) for o in owners)                                                # rows: 2 per item + 1
assert refused(lambda o: o[0]['items'].extend(                                             # 257 rows
    dict(o[0]['items'][0], alias=f'SBOTeam_X{i}') for i in range(128 - total)))
assert not refused(lambda o: o[0]['items'].extend(                                         # 255 rows
    dict(o[0]['items'][0], alias=f'SBOTeam_X{i}') for i in range(127 - total)))
first = owners[0]['ids']['ItemTable'][0]                                                    # the range's start
just = [first, first + len(owners[0]['items']) - 1]                                        # one ID per item
assert refused(lambda o: (o[0]['ids'].update(ItemTable=just),                              # range too small
                          o[0]['items'].append(dict(o[0]['items'][0], alias='SBOTeam_B'))))
assert not refused(lambda o: o[0]['ids'].update(ItemTable=just))

# 3. The rows: each _Buy row sells an ItemTable row of the batch for gold with no gate. The shop lists each _Buy row
# once with no tag. Each ID sits in its owner's range. Every NanoSuit keeps the screen's refusal of a second buy.
items = {r['name']: r for r in rows if r['table'] == 'ItemTable'}
buys = [r for r in rows if r['table'] == 'ShopItemTable']
shop = dict(rows[-1]['set'])
gates = {'CheckAchievement', 'CheckCondition', 'CheckConditionGroup', 'NanosuitAliasForRecipe', 'LinkedShopItemAlias',
         'LimitedCount'}
for b in buys:
    s = dict(b['set'])
    assert b['name'] == s['ItemAlias'] + '_Buy' and s['ItemAlias'] in items, b['name']
    assert s['MoneyItemAlias1'] == gen.MONEY and b['donor'] == gen.SHOPITEM_DONOR and not gates & set(s), b['name']
assert shop['ShopItems'] == [b['name'] for b in buys] and len(set(shop['ShopItems'])) == len(buys)
assert shop['Tags'] == [] and shop['CurrencyItemAlias'] == gen.MONEY and rows[-1]['id'] == gen.SHOP_ID
assert rows[-1]['donor'] == gen.SHOP_DONOR
for o in owners:
    for t in ('ItemTable', 'ShopItemTable'):
        lo, hi = o['ids'][t]
        names = {i['alias'] + ('_Buy' if t == 'ShopItemTable' else '') for i in o['items']}
        assert all(lo <= r['id'] <= hi for r in rows if r['name'] in names), (o['owner'], t)
for r in items.values():
    got = {**gen.ITEM_DONORS[r['donor']], **dict(r['set'])}
    assert got['Category'] != 4 or (got['MaxAmount'], got['InventoryAlias'], got['MaxAmountOverrideActorStat']) == (
        1, 'None', 0), r['name']
assert items['SBOTeam_GothicRose']['donor'] == 'BS_Yellow_Suit_Jacket'
assert dict(items['SBOTeam_GothicRose']['set'])['EquipmentAlias'] == 'BS_1000'

# 4. The generated files: the header's batch and shop name, the Lua file loaded as the game loads it.
header = (ROOT / 'native/src/world/teamshop/teamshop_rows.h').read_text()
assert 'constexpr Batch kTeamshop{"teamshop", kTeamshopRecipe, kTeamshopRows, kTeamshopPatches};' in header
assert f'constexpr char kTeamshopShop[] = "{gen.SHOP}";' in header
assert header.count('{Table::') == len(rows)
LUA = f"""
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local R=require('world.teamshop.rows')
assert(#R.ROWS=={len(rows)} and R.SHOP=='{gen.SHOP}' and #R.ITEMS=={len(items)})
assert(R.ROWS[#R.ROWS][1]=='ShopTable' and R.ROWS[#R.ROWS][2]==R.SHOP)
local gr
for _,i in ipairs(R.ITEMS) do if i.alias=='SBOTeam_GothicRose' then gr=i end end
assert(gr and gr.category==4 and gr.price==5000)
for _,r in ipairs(R.ROWS) do
    for _,c in ipairs(r[4]) do assert(#c==4 and type(c[4])=='boolean',r[2]..' '..c[1]) end
end
"""
done = subprocess.run(['lua5.4', '-'], input=LUA, cwd=ROOT, capture_output=True, text=True)
assert done.returncode == 0, done.stderr
print('teamshop_rows_test: ok')
