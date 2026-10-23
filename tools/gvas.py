"""Stellar Blade's saves as data: reads the game's EVAS-wrapped GVAS (UE 4.26 tagged properties) into plain Python
values, prints them as flat "path = value" lines, and diffs two saves. Read only: it never writes a save.

  python -I tools/gvas.py dump SAVE [PREFIX]   every leaf as "path = value" (only paths starting with PREFIX)
  python -I tools/gvas.py diff OLD NEW         the leaves that differ, were added or were removed
  python -I tools/gvas.py selftest             a built save read back

A struct is a dict of its properties; an array or set a list; a map a list of [key, value] pairs, since keys can be
structs. Native structs are decoded where their layout is plain (Vector, Rotator, Quat, Guid, DateTime, Timespan,
LinearColor, Color, Vector2D, IntPoint); any other struct a map holds without a tag is read as properties up to None.
Paths use the property names, [i] for an element, and a map entry's key when it is a name, string or number.
"""
import struct
import sys
import zlib

NATIVE = {'Vector': '<3f', 'Rotator': '<3f', 'Quat': '<4f', 'Vector2D': '<2f', 'LinearColor': '<4f', 'Color': '<4B',
          'IntPoint': '<2i', 'DateTime': '<q', 'Timespan': '<q'}


class Reader:
    def __init__(self, data, at=0):
        self.b, self.at = data, at

    def take(self, n):
        if self.at + n > len(self.b):
            raise ValueError(f'past the end at {self.at} (+{n})')
        v = self.b[self.at:self.at + n]
        self.at += n
        return v

    def u(self, fmt):
        return struct.unpack(fmt, self.take(struct.calcsize(fmt)))

    def i32(self):
        return self.u('<i')[0]

    def fstr(self):
        n = self.i32()
        if n == 0:
            return ''
        if n < 0:  # UTF-16, -n characters with the NUL.
            return self.take(-2 * n)[:-2].decode('utf-16-le')
        if n > 1 << 20:
            raise ValueError(f'string of {n} bytes at {self.at - 4}')
        return self.take(n)[:-1].decode('latin-1')


def header(r):
    if r.take(4) != b'GVAS':
        raise ValueError('not GVAS')
    h = {'save_version': r.i32(), 'package_version': r.i32()}
    h['engine'] = '%d.%d.%d-%d' % (*r.u('<3H'), r.u('<I')[0])
    h['branch'] = r.fstr()
    h['custom_format'] = r.i32()
    h['custom'] = [(r.take(16).hex(), r.i32()) for _ in range(r.i32())]
    h['class'] = r.fstr()
    return h


def properties(r, end=None):
    """Tagged properties up to None (or to end)."""
    out = {}
    while end is None or r.at < end:
        name = r.fstr()
        if name == 'None':
            break
        kind = r.fstr()
        size, index = r.u('<ii')
        value = tagged(r, kind, size)
        out[name if index == 0 else f'{name}#{index}'] = value
    return out


def tagged(r, kind, size):
    """The rest of a tag after its name, type, size and index, then the value."""
    if kind == 'BoolProperty':
        v = r.take(1)[0] != 0
        guid(r)
        return v
    if kind == 'StructProperty':
        sname = r.fstr()
        r.take(16)
        guid(r)
        start = r.at
        v = struct_value(r, sname, start + size)
        r.at = start + size  # Trust the size: a struct we read short or long never derails the rest.
        return v
    if kind in ('ByteProperty', 'EnumProperty'):
        enum = r.fstr()
        guid(r)
        if kind == 'ByteProperty' and enum == 'None':
            return r.take(1)[0]
        return r.fstr()
    if kind in ('ArrayProperty', 'SetProperty'):
        inner = r.fstr()
        guid(r)
        start = r.at
        v = array(r, inner, start + size, kind == 'SetProperty')
        r.at = start + size
        return v
    if kind == 'MapProperty':
        key, val = r.fstr(), r.fstr()
        guid(r)
        start = r.at
        try:
            v = mapping(r, key, val, start + size)
        except (ValueError, UnicodeDecodeError, struct.error) as e:
            v = f'<map {key}->{val}, {size} bytes: {e}>'
        r.at = start + size
        return v
    guid(r)
    return scalar(r, kind, size)


def guid(r):
    if r.take(1)[0]:
        r.take(16)


def scalar(r, kind, size):
    fmts = {'IntProperty': '<i', 'UInt32Property': '<I', 'Int64Property': '<q', 'UInt64Property': '<Q',
            'FloatProperty': '<f', 'DoubleProperty': '<d', 'Int16Property': '<h', 'UInt16Property': '<H',
            'Int8Property': '<b'}
    if kind in fmts:
        return r.u(fmts[kind])[0]
    if kind in ('NameProperty', 'StrProperty', 'ObjectProperty', 'SoftObjectProperty'):
        start = r.at
        v = r.fstr()
        if kind == 'SoftObjectProperty' and r.at < start + size:
            v += '|' + r.fstr()
        r.at = start + size
        return v
    if kind == 'TextProperty':
        return '<text %s>' % r.take(size).hex()
    return '<%s %s>' % (kind, r.take(size).hex())


def struct_value(r, sname, end):
    if sname in NATIVE:
        v = r.u(NATIVE[sname])
        return list(v) if len(v) > 1 else v[0]
    if sname == 'Guid':
        return r.take(16).hex()
    return properties(r, end)


def element(r, kind, sname, end):
    """One element of an array, set or map, which carries no tag of its own."""
    if kind == 'StructProperty':
        return struct_value(r, sname, end)
    if kind == 'BoolProperty':
        return r.take(1)[0] != 0
    if kind == 'ByteProperty':  # An enum's byte is stored as its name; a plain byte as one byte. The tag does not say.
        n, = struct.unpack_from('<i', r.b, r.at) if r.at + 4 <= len(r.b) else (0,)
        if 1 < n < 256 and r.at + 4 + n <= len(r.b) and r.b[r.at + 3 + n] == 0 and \
                all(32 <= c < 127 for c in r.b[r.at + 4:r.at + 3 + n]):
            return r.fstr()
        return r.take(1)[0]
    if kind in ('EnumProperty', 'NameProperty', 'StrProperty', 'ObjectProperty'):
        return r.fstr()
    return scalar(r, kind, struct.calcsize({'IntProperty': '<i', 'UInt32Property': '<I', 'FloatProperty': '<f',
                                            'Int64Property': '<q', 'UInt64Property': '<Q'}.get(kind, '<i')))


def array(r, inner, end, is_set):
    if is_set:
        r.i32()  # Removed elements: none in a save.
    n = r.i32()
    if inner == 'StructProperty':
        r.fstr(), r.fstr()  # The inner tag: its name and type,
        r.u('<ii')  # size and index,
        sname = r.fstr()  # the struct's name,
        r.take(16)
        guid(r)
        return [struct_value(r, sname, end) for _ in range(n)]
    if inner == 'ByteProperty' and not is_set:
        return r.take(n).hex()
    return [element(r, inner, None, end) for _ in range(n)]


def mapping(r, key, val, end):
    r.i32()  # Removed entries.
    n = r.i32()
    out = []
    for _ in range(n):
        k = element(r, key, None, end)
        v = element(r, val, None, end)
        out.append([k, v])
    if r.at != end:
        raise ValueError(f'ended at {r.at}, size says {end}')
    return out


def read(path):
    b = open(path, 'rb').read()
    if b[:4] != b'EVAS' or b[8:12] != b'GVAS':
        raise ValueError('not an EVAS save')
    stored, = struct.unpack('<I', b[-4:])
    if zlib.crc32(b[8:-4]) & 0xffffffff != stored:
        raise ValueError('CRC-32 does not match')
    r = Reader(b[8:-4])
    h = header(r)
    props = properties(r)
    return h, props, r.at, len(b) - 12


def leaves(v, path=''):
    if isinstance(v, dict):
        for k, x in v.items():
            yield from leaves(x, f'{path}.{k}' if path else k)
    elif isinstance(v, list) and v and all(isinstance(p, list) and len(p) == 2 for p in v) and \
            any(isinstance(p[1], (dict, list)) for p in v):
        for i, (k, x) in enumerate(v):  # A map: entries by key.
            yield from leaves(x, f'{path}[{k}]' if isinstance(k, (str, int)) else f'{path}[{i}]')
    elif isinstance(v, list) and any(isinstance(x, (dict, list)) for x in v):
        for i, x in enumerate(v):  # An element named by its own alias (ZoneAlias, QuestAlias...) when it has one.
            alias = next((a for k, a in x.items() if k.endswith('Alias') and isinstance(a, str) and a != 'None'),
                         None) if isinstance(x, dict) else None
            yield from leaves(x, f'{path}[{alias if alias else i}]')
    else:
        yield path, v


def selftest():
    def fs(s):
        return struct.pack('<i', len(s) + 1) + s.encode() + b'\0'

    def tag(name, kind, payload, extra=b''):
        return fs(name) + fs(kind) + struct.pack('<ii', len(payload), 0) + extra + payload

    inner = tag('Alias', 'NameProperty', fs('Zone_A'), b'\0') + tag('bOn', 'BoolProperty', b'', b'\1\0') + fs('None')
    body = (b'GVAS' + struct.pack('<ii', 2, 522) + struct.pack('<3HI', 4, 26, 2, 1) + fs('++UE4') +
            struct.pack('<ii', 3, 0) + fs('/Script/SB.SBSaveGame') +
            tag('Count', 'IntProperty', struct.pack('<i', 7), b'\0') +
            tag('Zone', 'StructProperty', inner, fs('ZoneData') + b'\0' * 16 + b'\0') +
            tag('Tasks', 'MapProperty', struct.pack('<ii', 0, 1) + fs('T1') + struct.pack('<i', 3),
                fs('NameProperty') + fs('IntProperty') + b'\0') +
            tag('Where', 'StructProperty', struct.pack('<3f', 1, 2, 3), fs('Vector') + b'\0' * 16 + b'\0') +
            fs('None') + b'\0' * 4)
    r = Reader(body)
    h = header(r)
    p = properties(r)
    assert h['engine'] == '4.26.2-1' and h['class'] == '/Script/SB.SBSaveGame', h
    assert p == {'Count': 7, 'Zone': {'Alias': 'Zone_A', 'bOn': True}, 'Tasks': [['T1', 3]], 'Where': [1.0, 2.0, 3.0]}, p
    assert dict(leaves(p))['Zone.bOn'] is True and r.at == len(body) - 4
    print('gvas selftest: ok')


def main(argv):
    if argv[:1] == ['selftest']:
        return selftest()
    if len(argv) >= 2 and argv[0] == 'dump':
        h, p, used, total = read(argv[1])
        print(f'# {h["class"]} engine {h["engine"]}, read {used} of {total} bytes')
        for k, v in leaves(p):
            if len(argv) < 3 or k.startswith(argv[2]):
                print(f'{k} = {v}')
        return 0
    if len(argv) == 3 and argv[0] == 'diff':
        a, b = (dict(leaves(read(x)[1])) for x in argv[1:])
        for k in sorted(a.keys() | b.keys()):
            if k not in a:
                print(f'+ {k} = {b[k]}')
            elif k not in b:
                print(f'- {k} = {a[k]}')
            elif a[k] != b[k]:
                print(f'~ {k}: {a[k]} -> {b[k]}')
        return 0
    print(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
