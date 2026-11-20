#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""A copy of tools/mxiii_rows.py's core (SIZE, text_of, the field checks, the header and Lua writers, main) that writes
the team shop's rows from data/teamshop/*.json: native/src/world/teamshop/teamshop_rows.h (the teamshop batch for
rows/rows.h) and mod/StellarCoop/Scripts/world/teamshop/rows.lua (the same rows for core/enemy.lua's read-back, the
items with their category and price, the shop's row name).

  python3 tools/teamshop_rows.py          write both files
  python3 tools/teamshop_rows.py --check  exit 1 when either file differs from what the data gives

Each data file holds one team member's ID ranges and items. An item becomes an ItemTable row named after its alias (a
copy of its donor with the fields of its "set") and a ShopItemTable row <alias>_Buy that sells it for gold. One
ShopTable row, SBOTeam_Shop, lists every _Buy row. The batch holds every ItemTable row first, then every ShopItemTable
row, then the ShopTable row, owners in file name order.

Each field an item sets must be in FIELDS: its offset in the row struct, read in Ghidra on build 26123051 from its
FPropertyParams (the address in its comment), the patch kind of rows/rows.h and the check kind of core/enemy.lua's
read-back. Donors, IDs and string keys come from the build 26123051 table dumps.
"""
import json
import re
import sys
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'data/teamshop'
HEADER = ROOT / 'native/src/world/teamshop/teamshop_rows.h'
LUA = ROOT / 'mod/StellarCoop/Scripts/world/teamshop/rows.lua'

# The license header both written files start with, after the comment mark.
LICENSE_HEADER = ('Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors',
                  'SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later',
                  'SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a '
                  'permission.')

PREFIX = 'SBOTeam_'  # Every item alias starts with it, so a team item is known by its name alone.
SHOP = 'SBOTeam_Shop'
SHOP_ID = 10000  # The first multiple of 10 above the shipped ShopTable maximum and the shop batch's 1062.
SHOP_DONOR = 'Shop_NightOperation'  # ShopTable 1060 as shipped: UnionLimitedItem true, currency BetaCrystal.
# ShopItemTable 9003: ShopType Buy, priced in betacrystal, every gate field None, discount 0, LimitedCount 1.
SHOPITEM_DONOR = 'StudioTest_BS_Yellow_Suit_Jacket_x1_Buy'
MONEY = 'BetaCrystal'  # Gold, the ItemTable row 9001.
# The highest ID of each table: the shipped rows' and those the lion, bolt and shop batches add
# (fight/bosses/lion_rows.h, eve/bolt_rows.h, online/modes/nightop/shop_rows.h). An owner's range starts above both.
SHIPPED_MAX = {'ItemTable': 2000151, 'ShopItemTable': 9007, 'ShopTable': 9990}
BATCH_MAX = {'ItemTable': 300014, 'ShopItemTable': 3573, 'ShopTable': 1062}
# The ItemTable rows an item may copy, with the donor's values the NanoSuit checks read. A donor not listed has not been
# read in the dumps. BS_Yellow_Suit_Jacket (2000046) names the EquipmentTable Body row of its own name.
ITEM_DONORS = {'BS_Yellow_Suit_Jacket': {'Category': 4, 'MaxAmount': 1, 'InventoryAlias': 'None',
                                         'MaxAmountOverrideActorStat': 0}}
NANOSUIT = 4  # ESBItemCategory_NanoSuit (FEnumParams 0x146d35e70).

# Table asset name: (rows/rows.h Table, {field: (offset, patch kind, read-back kind)}). An item's "set" may hold the
# ItemTable fields only; the generator writes the ShopItemTable and ShopTable fields.
FIELDS = {
    # SBItemTableProperty, params 0x146db2cb0. Not here: ApplyEquipType (Array of Byte, +0x170), since rows/rows.h has
    # no byte list kind; a row keeps its donor's.
    'ItemTable': ('item', {
        'InventoryAlias': (0x14, 'name', 'n'),  # 0x145e0f310
        'Name': (0x30, 'string', 's'),  # 0x145e0f220, an ItemStringTable key
        'DescFunction': (0x50, 'string', 's'),  # 0x145e0f270, an ItemStringTable key
        'DescContent': (0x60, 'string', 's'),  # 0x145e0f1a0, an ItemStringTable key
        'Category': (0x70, 'u8', 'e'),  # 0x145e0f170, ESBItemCategory
        'Rarity': (0x7c, 'u8', 'e'),  # 0x145e0f1c8, ESBItemRarityType
        'MaxAmount': (0x84, 'i32', 'i'),  # 0x145e0f120
        'MaxAmountOverrideActorStat': (0x88, 'u8', 'e'),  # 0x145e0f020, ESBActorStatType (FEnumParams 0x146d33ff0)
        'Asset2D': (0xd0, 'string', 's'),  # 0x145e0edf0, the icon
        'EquipableAlias': (0x144, 'name', 'n'),  # 0x145e0d870
        'SkillEquipableAlias': (0x154, 'name', 'n'),  # 0x145e0d8c0
        'EquipmentAlias': (0x15c, 'name', 'n'),  # 0x145e0d818, the EquipmentTable row the equip looks up
        'EquipmentAlias2': (0x164, 'name', 'n'),  # 0x145e0d7f0
        'ValidConditionGroup': (0x1ac, 'name', 'n'),  # 0x145e0d400
    }),
    # SBShopItemTableProperty, params 0x146db1d10.
    'ShopItemTable': ('shopitem', {
        'ItemAlias': (0x18, 'name', 'n'),  # 0x145e1acb8
        'MoneyItemAlias1': (0x2c, 'name', 'n'),  # 0x145e1ace0
        'MoneyItemCount1': (0x34, 'i32', 'i'),  # 0x145e1ac18
    }),
    # SBShopTableProperty, params 0x146db1d60.
    'ShopTable': ('shop', {
        'UnionLimitedItem': (0x14, 'u8', 'b'),  # 0x145e19810, a native bool (its SetBitFunc 0x141150bc0)
        'CurrencyItemAlias': (0x20, 'name', 'n'),  # 0x145e19870
        'Tags': (0x28, 'names', 'N'),  # 0x145e19760
        'ShopItems': (0x38, 'names', 'N'),  # 0x145e197b8
    }),
}
# The fields the generator writes with the donor's own value (FNames compare in any case), so a later SB update of the
# donor cannot change them: their read-back is no proof the patch landed (core/enemy.lua's changed flag).
SAME = {('ShopItemTable', 'MoneyItemAlias1'), ('ShopTable', 'UnionLimitedItem'), ('ShopTable', 'CurrencyItemAlias')}
SIZE = {'u8': 1, 'f32': 4, 'i32': 4, 'name': 8, 'string': 16, 'names': 16, 'strings': 16}
STRUCT = {'ItemTable': 0x1c0, 'ShopItemTable': 0xa0, 'ShopTable': 0xa8}  # Each row struct's SizeOf, from its params.
POOL = 0x1000  # rows/rows.h's kPoolBytes: a row's strings and lists must fit it.


def text_of(kind, value):
    """The value as rows/rows.h's patch text: names joined by '|'."""
    return '|'.join(value) if kind in ('names', 'strings') else str(value)


def load(folder):
    """Every data file of the folder, by file name."""
    return [json.loads(p.read_text()) for p in sorted(Path(folder).glob('*.json'))]


def rows(owners):
    """The batch: {table, name, donor, id, set: [[field, value]]}, every ItemTable row, then every ShopItemTable row,
    then the ShopTable row."""
    items, buys = [], []
    for o in owners:
        for i, item in enumerate(o['items']):
            items.append({'table': 'ItemTable', 'name': item['alias'], 'donor': item['donor'],
                          'id': o['ids']['ItemTable'][0] + i, 'owner': o['owner'],
                          'set': [[f, v] for f, v in item['set'].items()]})
            buys.append({'table': 'ShopItemTable', 'name': item['alias'] + '_Buy', 'donor': SHOPITEM_DONOR,
                         'id': o['ids']['ShopItemTable'][0] + i, 'owner': o['owner'],
                         'set': [['ItemAlias', item['alias']], ['MoneyItemAlias1', MONEY],
                                 ['MoneyItemCount1', item['price'][MONEY]]]})
    shop = {'table': 'ShopTable', 'name': SHOP, 'donor': SHOP_DONOR, 'id': SHOP_ID, 'owner': 'the team',
            'set': [['UnionLimitedItem', 1], ['CurrencyItemAlias', MONEY], ['Tags', []],
                    ['ShopItems', [b['name'] for b in buys]]]}
    return items + buys + [shop]


def check(owners):
    """Raises on data the native part would refuse or misread, or that takes an ID or a name someone else holds."""
    spans = {'ItemTable': [], 'ShopItemTable': []}
    aliases = set()
    assert len({o['owner'] for o in owners}) == len(owners), 'an owner twice'
    for o in owners:
        assert re.fullmatch(r'[A-Za-z0-9_]+', o['owner']), o['owner']
        for t, taken in spans.items():
            lo, hi = o['ids'][t]
            assert type(lo) is int and type(hi) is int and 0 < lo <= hi < 2 ** 32, (o['owner'], t)
            assert lo > max(SHIPPED_MAX[t], BATCH_MAX[t]), (o['owner'], t, 'an ID the game or a batch holds')
            assert all(hi < a or b < lo for a, b in taken), (o['owner'], t, 'overlaps another owner')
            assert hi - lo + 1 >= len(o['items']), (o['owner'], t, 'too small for the items')
            taken.append((lo, hi))
        for item in o['items']:
            alias = item['alias']
            assert re.fullmatch(PREFIX + r'[A-Za-z0-9_]+', alias) and alias not in aliases, alias
            aliases.add(alias)
            # One price, in gold: BuyItem (FUN_141bbe480) takes each price the row names.
            assert list(item['price']) == [MONEY], (alias, 'one price, in ' + MONEY)
            price = item['price'][MONEY]
            assert type(price) is int and 1 <= price <= 999999, (alias, price)
            # A NanoSuit is sold once: the screen's pre-check (FUN_141f5bdc0) refuses a buy when MaxAmount less the
            # count held under the alias is under 1, before BuyItem takes the gold. InventoryAlias would change that
            # key, MaxAmountOverrideActorStat would put an actor stat in place of MaxAmount.
            got = {**ITEM_DONORS[item['donor']], **item['set']}
            if got['Category'] == NANOSUIT:
                assert got['MaxAmount'] == 1, (alias, 'a NanoSuit holds at most 1')
                assert got['InventoryAlias'] == 'None' and got['MaxAmountOverrideActorStat'] == 0, alias
    batch = rows(owners)
    assert len(batch) < 256, 'a row index fits a byte'
    for r in batch:
        fields = FIELDS[r['table']][1]
        used, pool = [], 0
        for field, value in r['set']:
            at, kind, _ = fields[field]
            assert at >= 0x14 and at + SIZE[kind] <= STRUCT[r['table']], (r['name'], field)
            assert all(at + SIZE[kind] <= a or b2 <= at for a, b2 in used), (r['name'], field, 'overlaps')
            used.append((at, at + SIZE[kind]))
            if kind == 'u8':
                assert type(value) in (int, bool) and 0 <= int(value) <= 255, (r['name'], field)
            elif kind == 'i32':
                # rows/rows.h holds it in a float: an int32 must stay exact there.
                assert type(value) is int and abs(value) < 2 ** 24, (r['name'], field)
            elif kind == 'names':
                assert isinstance(value, list) and all(v and '|' not in v and len(v) < 128 for v in value)
                assert all(v.isascii() and '"' not in v and '\\' not in v for v in value), (r['name'], field)
                pool += -(-8 * len(value) // 8) * 8
            else:
                assert isinstance(value, str) and '"' not in value and '\\' not in value, (r['name'], field)
                assert value.isascii(), (r['name'], field, 'not ASCII')
                pool += -(-2 * (len(value) + 1) // 8) * 8 if value else 0
        assert pool <= POOL, (r['name'], pool, 'its strings overflow the pool')


# The header's head after the generated line: what the batch holds.
HEAD = ("The team shop's batch (kTeamshopRecipe), asked by world/teamshop at the title on the co-op save files. "
        'Per team item an ItemTable row named after its alias (a copy of its donor with its own fields) and a '
        f'ShopItemTable row <alias>_Buy (a copy of {SHOPITEM_DONOR}) that sells it for {MONEY}; then the ShopTable '
        f'row {SHOP} (a copy of {SHOP_DONOR} with no tag), which lists every _Buy row and comes last, once every row '
        'it names is in. Field offsets read in Ghidra on build 26123051 (tools/teamshop_rows.py names each params '
        'address); donors and free IDs from the build 26123051 table dumps.')


def header(batch):
    out = [*(f'// {line}' for line in LICENSE_HEADER),
           '// Generated by tools/teamshop_rows.py from data/teamshop/: do not edit it by hand.',
           *('// ' + line for line in textwrap.wrap(HEAD, 117, break_on_hyphens=False)),
           '#pragma once', '', '#include "rows/rows.h"', '', 'namespace coop::lion {', '',
           'constexpr Patch kTeamshopPatches[] = {']
    for r in batch:
        out.append(f'    // {r["name"]} ({r["table"]}, {r["owner"]})')
        fields = FIELDS[r['table']][1]
        for field, value in r['set']:
            at, kind, _ = fields[field]
            if kind in ('u8', 'i32'):
                out.append(f'    {{0x{at:x}, Kind::{kind}, {int(value)}, nullptr}}, // {field}')
            else:
                out.append(f'    {{0x{at:x}, Kind::{kind}, 0, "{text_of(kind, value)}"}}, // {field}')
    out.append('};')
    out.append('constexpr Row kTeamshopRecipe[] = {')
    first = 0
    for r in batch:
        t = FIELDS[r['table']][0]
        out.append(f'    {{Table::{t}, "{r["name"]}", "{r["donor"]}", {r["id"]}u, {first}, {len(r["set"])}}},')
        first += len(r['set'])
    out += ['};',
            'constexpr size_t kTeamshopRows = sizeof kTeamshopRecipe / sizeof kTeamshopRecipe[0];',
            'static_assert(kTeamshopRows < 256, "a row index fits a byte");',
            'constexpr Batch kTeamshop{"teamshop", kTeamshopRecipe, kTeamshopRows, kTeamshopPatches};',
            '// The ShopTable row world/teamshop opens SB\'s shop screen on.',
            f'constexpr char kTeamshopShop[] = "{SHOP}";',
            '', '} // namespace coop::lion']
    return '\n'.join(out)


def lua_value(kind, value):
    if kind in ('e', 'b', 'i'):
        return str(int(value))
    if kind == 'N':
        value = '|'.join(value)
    return "'" + value + "'"


def lua(owners, batch):
    out = [*(f'-- {line}' for line in LICENSE_HEADER),
           '-- Generated by tools/teamshop_rows.py from data/teamshop/: do not edit it by hand.',
           '-- The team shop\'s rows as native/src/world/teamshop/teamshop_rows.h writes them, for core/enemy.lua\'s',
           '-- read-back: ROWS {table, name, ID, checks}, each check {field, kind, value, changed} (core/enemy.lua\'s',
           '-- kinds). ITEMS: each team item\'s alias, ItemTable category and price in gold. SHOP: the ShopTable row',
           '-- the shop screen opens on.',
           'local R={}',
           'R.ROWS={']
    for r in batch:
        fields = FIELDS[r['table']][1]
        checks = ','.join(
            '{' + f"'{f}','{fields[f][2]}',{lua_value(fields[f][2], v)}," + str((r['table'], f) not in SAME).lower()
            + '}' for f, v in r['set'])
        out.append(f"    {{'{r['table']}','{r['name']}',{r['id']},{{{checks}}}}},")
    out.append('}')
    out.append('R.ITEMS={')
    for o in owners:
        for item in o['items']:
            category = {**ITEM_DONORS[item['donor']], **item['set']}['Category']
            out.append(f"    {{alias='{item['alias']}',category={category},price={item['price'][MONEY]}}},")
    out += ['}', f"R.SHOP='{SHOP}'", 'return R']
    return '\n'.join(out) + '\n'


def main(argv):
    owners = load(DATA)
    check(owners)
    batch = rows(owners)
    want = {HEADER: header(batch) + '\n', LUA: lua(owners, batch)}
    if '--check' in argv:
        stale = [p.relative_to(ROOT).as_posix() for p, t in want.items() if not p.exists() or p.read_text() != t]
        if stale:
            sys.exit('Out of date, run python3 tools/teamshop_rows.py: ' + ', '.join(stale))
        return
    for p, t in want.items():
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(t)


if __name__ == '__main__':
    main(sys.argv[1:])
