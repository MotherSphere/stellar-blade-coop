# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""tools/boss_rows.py on small made-up tables, without the game's: each filter (rank, test, demo, NIKKE and Boss
Challenge rows, conditions that are no ActorHP, a condition with no event at its index, an equation other than LEQ),
the scene a trigger's event plays (through AddEvents, a level sequence alone, a Stop row, an effect-only chain), the QTE
flag on the exact theater alias, the LV_Dead rows. Then the written block: parsed back to the same values, lines
within 116 columns, between its markers, the rest of the header untouched, a name that cannot go into a C++ literal
refused. Last, load and main over a folder of table exports.
Run: python3 tests/tools/boss_rows_test.py"""
import ast
import contextlib
import importlib.util
import io
import json
import re
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
spec = importlib.util.spec_from_file_location('boss_rows', ROOT / 'tools/boss_rows.py')
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)


def spawn(id_, chars, conds, events):
    return {'ID': id_, 'CharacterAlias': list(chars), 'ConditionsTrigger': list(conds),
            'ConditionTriggerEvent': list(events)}


def cond(value, percent=False, eq='LEQ', kind='ActorHP'):
    calc = 'Percent' if percent else 'Absolute'
    return {'ConditionType': f'ESBConditionType::ESBConditionType_{kind}', 'ConditionEq': f'ESBEquation::ESBEQ_{eq}',
            'CheckValue': value, 'CheckStatCalcType': f'ESBConditionCalcuationType::ESBConditionCalcuationType_{calc}'}


def event(kind, alias='None', add=()):
    return {'Type': f'ESBZoneEventType::ZoneEvent_{kind}', 'EventAlias': alias, 'AddEvents': list(add)}


def theater(path='', seq='', stop=False):
    return {'TheaterAssetPath': path, 'LevelSeqAssetPath': seq,
            'ControlType': f'ESBZoneEventTheaterType::ZoneEvent_Theater_{"Stop" if stop else "Play"}'}


def asset(alias):
    return f'/Game/T/{alias}.{alias}'


def tables(spawns, conds, events=None, theaters=None, effects=None):
    chars = {'M_Boss': {'Rank': 'Boss'}, 'M_Elite': {'Rank': 'Elite'}, 'M_Normal': {'Rank': 'Normal2'}}
    return {'EventSpawnTable': spawns, 'ConditionTable': conds, 'ZoneEventTable': events or {},
            'EventTheaterTable': theaters or {}, 'CharacterTable': chars,
            'EffectTable': {k: {'ID': v} for k, v in (effects or {}).items()}}


def test_filters():
    conds = {'C_1': cond(1), 'C_Quest': cond(1, kind='QuestState')}
    events = {'E_1': event('AttachActorEffect')}
    spawns = {'A_10_E_CharS_001': spawn(1, ['M_Boss'], ['C_1', 'C_Quest', 'None', 'C_1'], ['E_1', 'E_1', 'E_1']),
              'A_10_E_CharS_002': spawn(2, ['M_Normal'], ['C_1'], ['E_1']),
              'A_10_E_CharS_003': spawn(3, ['M_Normal', 'M_Boss'], ['C_1'], ['E_1']),
              'Test_A_E_CharS_001': spawn(4, ['M_Boss'], ['C_1'], ['E_1']),
              'NKGame_01_E_CharS_001': spawn(5, ['M_Boss'], ['C_1'], ['E_1']),
              'A_Boss_X_E_CharS_001': spawn(6, ['M_Boss'], ['C_1'], ['E_1']),
              'A_10_E_CharS_004': spawn(7, ['M_Elite'], ['C_1'], ['E_1'])}
    out = gen.triggers(tables(spawns, conds, events))
    # Row 1's quest condition is no ActorHP, its None builds nothing, its fourth condition has no event at its index.
    assert [(r['spawn'], r['row'], r['event']) for r in out] == [(1, 'A_10_E_CharS_001', 'E_1'),
                                                                  (7, 'A_10_E_CharS_004', 'E_1')]
    for name in ('LV_Test_A_E_CharS_001', 'MEDemo_01_E_CharS_001', 'Nikke_01_E_CharS_001', 'EVE_GunNikke_E_CharS_001'):
        assert gen.triggers(tables({name: spawn(8, ['M_Boss'], ['C_1'], ['E_1'])}, conds, events)) == [], name
    try:
        gen.triggers(tables({'A_10_E_CharS_001': spawn(1, ['M_Boss'], ['C_2'], ['E_1'])}, {'C_2': cond(1, eq='GEQ')},
                            events))
        assert False
    except ValueError as e:
        assert 'LEQ' in str(e)


def test_scene_path():
    conds = {'C_1': cond(1), 'C_2': cond(300, percent=True)}
    events = {'E_Eff': event('AttachActorEffect', add=['E_Other', 'E_Th']), 'E_Other': event('AttachActorEffect'),
              'E_Th': event('Theater', 'Th_1'), 'E_Seq': event('Theater', 'Th_Seq'),
              'E_Stop': event('Theater', 'Th_Stop', add=['E_Seq']),
              'E_Only': event('AttachActorEffect', add=['E_Other']),
              'E_Deep': event('AttachActorEffect', add=['E_D1']), 'E_D1': event('AttachActorEffect', add=['E_D2']),
              'E_D2': event('AttachActorEffect', add=['E_D3']), 'E_D3': event('AttachActorEffect', add=['E_D4']),
              'E_D4': event('AttachActorEffect', add=['E_D5']), 'E_D5': event('Theater', 'Th_1')}
    theaters = {'Th_1': theater(asset('MV_A')), 'Th_Seq': theater(seq=asset('Sub_A')),
                'Th_Stop': theater(asset('MV_B'), stop=True)}
    t = tables({}, conds, events, theaters)
    assert gen.scene(t, 'E_Eff') == asset('MV_A')  # Through AddEvents, past a row that plays nothing.
    assert gen.scene(t, 'E_Seq') == asset('Sub_A')  # A level sequence alone.
    assert gen.scene(t, 'E_Stop') == asset('Sub_A')  # A Stop row plays nothing; its AddEvents still run.
    assert gen.scene(t, 'E_Only') == '' and gen.scene(t, 'E_Missing') == ''
    assert gen.scene(t, 'E_Deep') == ''  # Five AddEvents down: past depth 4.
    spawns = {'A_10_E_CharS_001': spawn(1, ['M_Boss'], ['C_2', 'C_1'], ['E_Seq', 'E_Eff'])}
    assert [(r['value'], r['percent'], r['scene']) for r in gen.triggers(t | {'EventSpawnTable': spawns})] == [
        (300, True, asset('Sub_A')), (1, False, asset('MV_A'))]


def test_qte_flag():
    conds = {'C_1': cond(1), 'C_600': cond(600, percent=True), 'C_2': cond(2)}
    aliases = ['MV_WLA_Nest_RavenBattle_QTE_Master', 'MV_WLA30_RoyalGuard_AfterBattle',
               'MV_DED01_Parkinglot_AfterBattle', 'MV_DED01_Parkinglot_AfterBattle_TrialVersion']
    events = {f'E_{i}': event('Theater', f'Th_{i}') for i in range(len(aliases))}
    theaters = {f'Th_{i}': theater(asset(a)) for i, a in enumerate(aliases)}
    spawns = {'A_10_E_CharS_001': spawn(1, ['M_Boss'], ['C_1', 'C_600', 'C_2', 'C_1', 'C_1', 'C_1'],
                                        ['E_0', 'E_0', 'E_0', 'E_1', 'E_2', 'E_3'])}
    out = gen.triggers(tables(spawns, conds, events, theaters))
    assert [r['qte'] for r in out] == [True, False, False, False, True, False]
    assert len(gen.QTE_THEATERS) == 10 and 'MV_Nest_FinalBattle_Lily_QTE_Die' in gen.QTE_THEATERS


def test_lv_dead():
    t = tables({}, {}, effects={'Passive_DeathReady': 2001101, 'LV_Dead': 7000007, 'LV_DeadZone': 7000001,
                                'LV_Dead_Falling': 7000028})
    assert gen.lv_dead(t) == [7000007, 7000001, 7000028]  # Every name that starts with LV_Dead, in table order.


def unrender(block, name):
    """The entries of a generated C++ list, parsed back into tuples (or numbers)."""
    body = block[block.index(f'{name}[] = {{') + len(name) + 6:]
    body = body[:body.index('};')]
    body = re.sub(r'"\s*\n\s*"', '', body)  # Adjacent literals.
    body = body.replace('{', '(').replace('}', ')').replace('true', 'True').replace('false', 'False')
    return ast.literal_eval(f'[{body}]')


def test_render():
    rows = [{'spawn': 1410024156, 'row': 'A', 'value': 600, 'percent': True, 'event': 'WLA_10_E_Theater_006',
             'scene': '/Game/' + 'Folder/' * 20 + 'MV_A.MV_A', 'qte': False},
            {'spawn': 1710024026, 'row': 'B', 'value': 1, 'percent': False, 'event': 'SD_10_E_ActorEff_098',
             'scene': '', 'qte': True}]
    lv = [7000000 + i for i in range(20)]
    block = gen.render(rows, lv, ['Count line.'])
    assert block.startswith(gen.BEGIN + '\n') and block.endswith('\n' + gen.END) and '// Count line.' in block
    assert all(len(line) <= 120 for line in block.split('\n'))
    assert all(len(line) <= 116 for line in block.split('\n') if not line.startswith('//'))
    keys = ('spawn', 'value', 'percent', 'event', 'scene', 'qte')
    assert unrender(block, 'kTriggers') == [tuple(r[k] for k in keys) for r in rows]
    assert unrender(block, 'kLvDead') == lv
    for bad in ({'event': 'A"b'}, {'event': 'A b'}, {'scene': '/Game/A".A'}, {'scene': '/Game/A B.A'}):
        try:
            gen.render([dict(rows[0], **bad)], lv, [])
            assert False, bad
        except ValueError as e:
            assert 'C++ string literal' in str(e)
    for empty in (([], lv), (rows, [])):
        try:
            gen.render(*empty, [])
            assert False
        except ValueError as e:
            assert 'zero-size' in str(e)
    with tempfile.TemporaryDirectory() as tmp:
        header = Path(tmp) / 'boss_rows.h'
        header.write_text(f'// top\n{gen.BEGIN}\nold\n{gen.END}\n// bottom\n')
        gen.write(header, block)
        assert header.read_text() == f'// top\n{block}\n// bottom\n'


def test_main_counts():
    conds = {'C_1': cond(1), 'C_600': cond(600, percent=True)}
    events = {'E_Q': event('Theater', 'Th_Q'), 'E_Eff': event('AttachActorEffect')}
    theaters = {'Th_Q': theater(asset('MV_Xion06_RavenFinish_QTE'))}
    spawns = {'A_10_E_CharS_001': spawn(1, ['M_Boss'], ['C_600', 'C_1'], ['E_Eff', 'E_Q']),
              'A_10_E_CharS_002': spawn(2, ['M_Elite'], ['C_1'], ['E_Eff']),
              'A_10_E_CharS_003': spawn(3, ['M_Normal'], ['C_1'], ['E_Q'])}
    t = tables(spawns, conds, events, theaters, {'LV_Dead': 7000007, 'LV_Dead_Falling': 7000028, 'Other': 1})
    with tempfile.TemporaryDirectory() as tmp:
        for name in gen.TABLES:
            other = {'Type': 'Package'}  # An export without rows, before the table's.
            (Path(tmp) / f'{name}.uasset.json').write_text(json.dumps([other, {'Name': name, 'Rows': t[name]}]))
        assert gen.load(tmp) == t
        header = Path(tmp) / 'boss_rows.h'
        header.write_text(f'{gen.BEGIN}\n{gen.END}\n')
        saved, gen.HEADER = gen.HEADER, header
        try:
            with contextlib.redirect_stdout(io.StringIO()) as out:
                gen.main([tmp])
        finally:
            gen.HEADER = saved
        assert out.getvalue() == 'boss rows: 3 triggers on 2 spawn rows, 1 QTE, 2 LV_Dead rows\n'
        text = header.read_text()
        assert '{1, 1, false, "E_Q", "/Game/T/MV_Xion06_RavenFinish_QTE.MV_Xion06_RavenFinish_QTE", true},' in text
        assert text.count(gen.BEGIN) == 1


for name, test in list(globals().items()):
    if name.startswith('test_'):
        test()
print('boss_rows_test: ok')
