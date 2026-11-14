#!/usr/bin/env python3
"""tools/save_read.py on GVAS bodies built here: the header, scalars, structs, containers, the checks of the EVAS
wrapper, the ByteProperty element guess, value paths, and the dump, diff and selftest commands on saves written into a
temporary folder. Run: python3 tests/tools/save_read_test.py"""
import contextlib
import io
import struct
import sys
import tempfile
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools'))
import save_read as S  # noqa: E402
from save_read import Map  # noqa: E402


def run(*argv):
    """(exit code, stdout + stderr) of save_read with these arguments."""
    out = io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
        try:
            code = S.main([str(a) for a in argv])
        except SystemExit as stop:
            code = stop.code
    return code, out.getvalue()


def refused(data, words):
    try:
        S.read_save(data)
    except S.SaveError as e:
        assert words in str(e), e
        return
    raise AssertionError(f'not refused: {words}')


# 1. A body built by hand, tag by tag: the header, a scalar, a tagged struct, a map of structs, a fixed-layout struct,
# a Guid, a bool, a plain byte, an enum byte, an indexed tag, a text and an unknown type.
fs, tag, i32 = S.fstring_bytes, S.tag_bytes, (lambda n: struct.pack('<i', n))
inner = tag('Count', 'IntProperty', i32(-7)) + fs('None')
key_struct = tag('Name', 'StrProperty', fs('k')) + fs('None')
body = (b'GVAS' + struct.pack('<ii', 2, 522) + struct.pack('<3HI', 4, 26, 2, 1234) + fs('++UE4+Release-4.26')
        + i32(3) + i32(1) + bytes(16) + i32(9) + fs('/Script/SB.SBSaveGame')
        + tag('Level', 'IntProperty', i32(12))
        + tag('Inner', 'StructProperty', inner, fs('SBInner') + bytes(16))
        + tag('Pairs', 'MapProperty', i32(0) + i32(1) + fs('Env') + inner, fs('NameProperty') + fs('StructProperty'))
        + tag('Keyed', 'MapProperty', i32(0) + i32(1) + key_struct + i32(5), fs('StructProperty') + fs('IntProperty'))
        + tag('At', 'StructProperty', struct.pack('<3f', 1.5, -2.0, 0.25), fs('Vector') + bytes(16))
        + tag('When', 'StructProperty', struct.pack('<q', 638000000000000000), fs('DateTime') + bytes(16))
        + tag('Id', 'StructProperty', bytes(range(16)), fs('Guid') + bytes(16))
        + fs('On') + fs('BoolProperty') + i32(0) + i32(0) + b'\x01' + b'\x00'
        + tag('Raw', 'ByteProperty', b'\x05', fs('None'))
        + tag('State', 'ByteProperty', fs('ESBObject_Enable'), fs('ESBObjectState'))
        + tag('Slot', 'IntProperty', i32(3), index=2)
        + tag('Label', 'TextProperty', b'\x01\x02')
        + tag('Odd', 'WeirdProperty', b'\xab')
        + tag('Ratio', 'FloatProperty', struct.pack('<f', 0.3))
        + tag('Name', 'NameProperty', fs('Café'))
        + fs('None') + bytes(4))
header, tree = S.read_body(body)
assert header == {'save_version': 2, 'package_version': 522, 'engine': '4.26.2-1234', 'branch': '++UE4+Release-4.26',
                  'save_class': '/Script/SB.SBSaveGame', 'read': len(body), 'size': len(body)}, header
assert tree == {'Level': 12, 'Inner': {'Count': -7}, 'Pairs': [('Env', {'Count': -7})],
                'Keyed': [({'Name': 'k'}, 5)],
                'At': [1.5, -2.0, 0.25], 'When': 638000000000000000, 'Id': '000102030405060708090a0b0c0d0e0f',
                'On': True, 'Raw': 5, 'State': 'ESBObject_Enable', 'Slot#2': 3, 'Label': '0102',
                'Odd': '<WeirdProperty ab>', 'Ratio': 0.30000001192092896, 'Name': 'Café'}, tree
assert isinstance(tree['Pairs'], Map) and not isinstance(tree['At'], Map)
# The reader goes on at the value's end, whatever the value held: a struct that leaves bytes unread is skipped whole.
padded = tag('Inner', 'StructProperty', inner + b'\xee\xee', fs('SBInner') + bytes(16)) + tag('Next', 'IntProperty', i32(1))
assert S.Reader(padded + fs('None')).properties() == {'Inner': {'Count': -7}, 'Next': 1}
# A map whose entries do not end at the value's size is an error marker, and the next tag still reads.
short = tag('Pairs', 'MapProperty', i32(0) + i32(1) + i32(4) + i32(5) + b'\x00', fs('IntProperty') + fs('IntProperty'))
got = S.Reader(short + tag('Next', 'IntProperty', i32(1)) + fs('None')).properties()
assert got['Next'] == 1 and got['Pairs'] == "<error: the map's entries take 16 of its 17 bytes>", got
# A positive FString length over 1 MiB is a misread.
try:
    S.Reader(i32(2 << 20) + bytes(8)).fstring()
    raise AssertionError('long FString read')
except S.SaveError as e:
    assert 'FString' in str(e)

# 2. The EVAS wrapper: magic words, then the CRC-32 of the body, little endian.
save = S.wrap(body)
assert save[:8] == b'EVAS\x01\x00\x00\x00' and save[8:-4] == body
assert save[-4:] == struct.pack('<I', zlib.crc32(body))
assert S.read_save(save) == (header, tree)
refused(b'SAVE' + save[4:], 'not a Stellar Blade save')
refused(save[:8] + b'XVAS' + save[12:], 'not a Stellar Blade save')
refused(save[:-4] + struct.pack('<I', zlib.crc32(body) ^ 1), 'CRC-32')
refused(S.wrap(body[:-30]), 'past the end')

# 3. A ByteProperty element (here a map's keys) is a name when the next bytes read as a short printable FString with
# its NUL, and one raw byte otherwise; an array of plain bytes is one hex string.
names = tag('Kinds', 'MapProperty', i32(0) + i32(2) + fs('ESBMission_EnvState') + i32(1) + fs('ESBMission_Achievement')
            + i32(2), fs('ByteProperty') + fs('IntProperty'))
raw = tag('Kinds', 'MapProperty', i32(0) + i32(2) + b'\x03' + i32(1) + b'\x09' + i32(2),
          fs('ByteProperty') + fs('IntProperty'))
almost = tag('Kinds', 'MapProperty', i32(0) + i32(1) + b'\x04' + i32(0x41414141), fs('ByteProperty') + fs('IntProperty'))
assert S.Reader(names + fs('None')).properties() == {'Kinds': [('ESBMission_EnvState', 1), ('ESBMission_Achievement', 2)]}
assert S.Reader(raw + fs('None')).properties() == {'Kinds': [(3, 1), (9, 2)]}
assert S.Reader(almost + fs('None')).properties() == {'Kinds': [(4, 0x41414141)]}  # 'AAAA' has no NUL: a raw byte.
blob = tag('Blob', 'ArrayProperty', i32(3) + b'\x00\xff\x10', fs('ByteProperty'))
assert S.Reader(blob + fs('None')).properties() == {'Blob': '00ff10'}

# 4. The writer the selftest and the story tests use reads back to the same tree, a struct list, a set and an empty
# list included.
sample = {'Count': 3, 'Big': 1 << 40, 'Ratio': 0.30000001192092896, 'Exact': 2.5e-05, 'On': False, 'Text': 'Café',
          'Empty': '', 'List': [{'Alias': 'A', 'N': 1}, {'N': 2}], 'Words': ['a', 'b'], 'None_': [],
          'Map': Map([(41, {'UniqueKey': 'K'}), (-1, {})]), 'Flags': Map([('x', True)]), 'Nested': {'Deep': {'X': 1}}}
assert S.read_body(S.encode(sample))[1] == sample
assert S.read_save(S.wrap(S.encode(sample)))[0]['save_class'] == '/Script/SB.SBSaveGame'
a_set = tag('Seen', 'SetProperty', i32(0) + i32(2) + fs('Lv_A') + fs('Lv_B'), fs('NameProperty'))
assert S.Reader(a_set + fs('None')).properties() == {'Seen': ['Lv_A', 'Lv_B']}

# 5. Value paths: field steps joined by dots, entry steps in brackets only on containers that hold something nested,
# a map entry by its string or integer key, a list element by its first *Alias field that is not None.
tree = {'A': 1, 'Vec': [1.0, 2.0, 3.0], 'Names': ['x'], 'Env': Map([('Env', {'Zones': [
    {'ZoneAlias': 'Zone_N', 'Objs': Map([(41, {'K': True}), ((1, 2), {'K': False})]), 'Opt': {}},
    {'OtherAlias': 'None', 'StayZoneAlias': 'Zone_M', 'V': 'None'}]})]), 'Flat': Map([('a', 1)])}
assert list(S.walk(tree)) == [
    ('A', 'A', 1), ('Vec', 'Vec', [1.0, 2.0, 3.0]), ('Names', 'Names', ['x']),
    ('Env[Env].Zones[Zone_N].ZoneAlias', 'ZoneAlias', 'Zone_N'), ('Env[Env].Zones[Zone_N].Objs[41].K', 'K', True),
    ('Env[Env].Zones[Zone_N].Objs[1].K', 'K', False), ('Env[Env].Zones[Zone_M].OtherAlias', 'OtherAlias', 'None'),
    ('Env[Env].Zones[Zone_M].StayZoneAlias', 'StayZoneAlias', 'Zone_M'), ('Env[Env].Zones[Zone_M].V', 'V', 'None'),
    ('Flat', 'Flat', Map([('a', 1)]))], list(S.walk(tree))
assert [p for p, _, _ in S.walk([{'X': 1}, 2])] == ['[0].X', '[1]']
assert S.values(tree)['Vec'] == '[1.0, 2.0, 3.0]' and S.values(tree)['Flat'] == "[('a', 1)]"

# 6. The commands, on saves written into a temporary folder.
with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    old, new, bad = tmp / 'old.sav', tmp / 'new.sav', tmp / 'bad.sav'
    first = {'Level': 3, 'Quest': {'Alias': 'Q1', 'State': 1}, 'Gone': True, 'Ratio': 0.5}
    second = {'Level': 3, 'Quest': {'Alias': 'Q1', 'State': 2}, 'Ratio': 0.5, 'Added': 'x y'}
    old.write_bytes(S.wrap(S.encode(first)))
    new.write_bytes(S.wrap(S.encode(second)))
    bad.write_bytes(b'EVAS' + bytes(20))
    code, out = run('dump', old)
    lines = out.splitlines()
    assert code == 0 and lines[0].startswith('# /Script/SB.SBSaveGame (UE 4.26.2-0): ') and lines[1:] == [
        'Level = 3', 'Quest.Alias = Q1', 'Quest.State = 1', 'Gone = True', 'Ratio = 0.5'], out
    size = len(S.encode(first))
    assert lines[0] == f'# /Script/SB.SBSaveGame (UE 4.26.2-0): {size} of {size} body bytes read', lines[0]
    assert run('dump', old, 'Quest.') == (0, lines[0] + '\nQuest.Alias = Q1\nQuest.State = 1\n')
    assert run('diff', old, new) == (0, '+ Added = x y\n- Gone = True\n~ Quest.State: 1 -> 2\n')
    assert run('diff', old, old) == (0, '')
    code, out = run('selftest')
    assert code == 0 and out == 'save_read selftest: ok\n', out
    for argv in ([], ['dump'], ['diff', old], ['nope', old], ['selftest', 'x']):
        code, out = run(*argv)
        assert code == 2 and out.startswith('Use: '), (argv, code, out)
    try:
        run('dump', bad)
        raise AssertionError('bad save dumped')
    except S.SaveError as e:
        assert 'not a Stellar Blade save' in str(e)
    assert sorted(p.name for p in tmp.iterdir()) == ['bad.sav', 'new.sav', 'old.sav']  # It writes nothing.

print('save_read_test: ok')
