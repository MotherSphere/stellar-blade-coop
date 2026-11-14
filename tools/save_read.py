#!/usr/bin/env python3
"""Reads a Stellar Blade save (an EVAS wrapper around an Unreal 4.26 GVAS body) and prints every value in it as one
`path = value` line, or the paths whose value differs between two saves. Read only: it never writes a file.

  python3 tools/save_read.py dump SAVE [PREFIX]   the values in save order, those whose path starts with PREFIX
  python3 tools/save_read.py diff OLD NEW         + path only in NEW, - path only in OLD, ~ changed, sorted by path
  python3 tools/save_read.py selftest             reads back a body built in memory

The layout and the path rules are in docs/story.md. tools/story_lines.py reads saves through this file.
"""
import struct
import sys
import zlib

USE = 'Use: save_read.py dump SAVE [PREFIX] | diff OLD NEW | selftest'
SAVE_CLASS = '/Script/SB.SBSaveGame'
SCALARS = {'IntProperty': '<i', 'UInt32Property': '<I', 'Int64Property': '<q', 'UInt64Property': '<Q',
           'Int16Property': '<h', 'UInt16Property': '<H', 'Int8Property': '<b', 'FloatProperty': '<f',
           'DoubleProperty': '<d'}
STRINGS = {'NameProperty', 'StrProperty', 'ObjectProperty', 'EnumProperty'}
# Structs the engine writes as raw fields, with no tags. Guid apart: 16 bytes shown as hex.
FIXED = {'Vector': '<3f', 'Rotator': '<3f', 'Quat': '<4f', 'LinearColor': '<4f', 'Vector2D': '<2f', 'Color': '<4B',
         'IntPoint': '<2i', 'DateTime': '<q', 'Timespan': '<q'}


class SaveError(ValueError):
    """The bytes are not a save this reader understands."""


class Map(list):
    """A map value: its (key, value) pairs in file order. A key can be a struct, so it is no dict."""


class Reader:
    def __init__(self, data):
        self.data, self.pos = data, 0

    def take(self, n):
        if n < 0 or self.pos + n > len(self.data):
            raise SaveError(f'a read of {n} bytes at {self.pos} goes past the end of the {len(self.data)} bytes')
        self.pos += n
        return self.data[self.pos - n:self.pos]

    def unpack(self, fmt):
        return struct.unpack(fmt, self.take(struct.calcsize(fmt)))

    def i32(self):
        return self.unpack('<i')[0]

    def fstring(self):
        """An FString: an int32 length that counts the NUL, then Latin-1 bytes (positive) or UTF-16LE units."""
        n = self.i32()
        if n > 1 << 20: raise SaveError(f'an FString of {n} bytes at {self.pos - 4}: a misread')
        if n >= 0: return self.take(n)[:-1].decode('latin-1')
        return self.take(-2 * n)[:-2].decode('utf-16-le', 'replace')

    def short_name_next(self):
        """Whether the next bytes read as an FString of 1 to 255 printable ASCII characters and its NUL."""
        at = self.pos
        if at + 4 > len(self.data): return False
        n = int.from_bytes(self.data[at:at + 4], 'little', signed=True)
        text = self.data[at + 4:at + 4 + n]
        return 2 <= n <= 256 and len(text) == n and text[-1] == 0 and all(0x20 <= b < 0x7f for b in text[:-1])

    def properties(self):
        """A tagged property list up to the name None, as {name: value}; a tag with array index i is name#i."""
        fields = {}
        while (name := self.fstring()) != 'None':
            kind, size, index = self.fstring(), self.i32(), self.i32()
            extra = None
            if kind == 'BoolProperty': extra = self.take(1)[0] != 0
            elif kind == 'StructProperty': extra = self.fstring(); self.take(16)
            elif kind in ('ByteProperty', 'EnumProperty', 'ArrayProperty', 'SetProperty'): extra = self.fstring()
            elif kind == 'MapProperty': extra = (self.fstring(), self.fstring())
            if self.take(1)[0]: self.take(16)  # The property GUID.
            start = self.pos
            fields[name if index == 0 else f'{name}#{index}'] = self.value(kind, size, extra)
            self.pos = start + size  # Whatever the value used, the next tag starts there.
        return fields

    def value(self, kind, size, extra):
        start = self.pos
        if kind == 'BoolProperty': return extra
        if kind in SCALARS: return self.unpack(SCALARS[kind])[0]
        if kind in STRINGS: return self.fstring()
        if kind == 'SoftObjectProperty':
            text = self.fstring()
            return text + '|' + self.fstring() if self.pos < start + size else text
        if kind == 'ByteProperty': return self.take(1)[0] if extra == 'None' else self.fstring()
        if kind == 'StructProperty': return self.struct(extra)
        if kind in ('ArrayProperty', 'SetProperty'): return self.array(extra, kind == 'SetProperty', start + size)
        if kind == 'MapProperty':
            self.i32()  # Removed entries.
            pairs = Map((self.element(extra[0]), self.element(extra[1])) for _ in range(self.i32()))
            if self.pos != start + size: return f"<error: the map's entries take {self.pos - start} of its {size} bytes>"
            return pairs
        if kind == 'TextProperty': return self.take(size).hex()
        return f'<{kind} {self.take(size).hex()}>'

    def struct(self, name):
        if name == 'Guid': return self.take(16).hex()
        if name in FIXED:
            fields = self.unpack(FIXED[name])
            return fields[0] if len(fields) == 1 else list(fields)
        return self.properties()

    def array(self, inner, is_set, end):
        if is_set: self.i32()  # Removed elements.
        count = self.i32()
        if inner == 'ByteProperty' and self.pos + count == end: return self.take(count).hex()  # Plain bytes.
        if inner != 'StructProperty': return [self.element(inner) for _ in range(count)]
        if count == 0: return []
        self.fstring(), self.fstring(), self.i32(), self.i32()  # The inner tag: name, type, size, index,
        name = self.fstring()  # its struct type,
        self.take(16)
        if self.take(1)[0]: self.take(16)  # GUID and GUID flag.
        return [self.struct(name) for _ in range(count)]

    def element(self, kind):
        """A value inside a container: no tag, and a struct there has no type name, so it is a tagged list."""
        if kind == 'StructProperty': return self.properties()
        if kind == 'BoolProperty': return self.take(1)[0] != 0
        if kind in SCALARS: return self.unpack(SCALARS[kind])[0]
        if kind in STRINGS or kind == 'SoftObjectProperty': return self.fstring()
        if kind == 'ByteProperty': return self.fstring() if self.short_name_next() else self.take(1)[0]
        raise SaveError(f'no reading for a {kind} inside a container')


def read_body(body):
    """(header, tree) of a GVAS body. header: save_version, package_version, engine, branch, save_class, read (bytes
    read) and size; tree: the top-level properties."""
    r = Reader(body)
    if r.take(4) != b'GVAS': raise SaveError('not a GVAS body')
    save_version, package_version = r.i32(), r.i32()
    major, minor, patch, changelist = r.unpack('<3HI')
    branch = r.fstring()
    r.i32()  # Custom version format.
    for _ in range(r.i32()): r.take(20)  # GUID and version of each custom version.
    save_class = r.fstring()
    tree = r.properties()
    r.take(4)
    return {'save_version': save_version, 'package_version': package_version,
            'engine': f'{major}.{minor}.{patch}-{changelist}', 'branch': branch, 'save_class': save_class,
            'read': r.pos, 'size': len(body)}, tree


def read_save(data):
    """(header, tree) of a .sav file's bytes, after the EVAS wrapper's checks."""
    if data[:4] != b'EVAS' or data[8:12] != b'GVAS': raise SaveError('not a Stellar Blade save (no EVAS and GVAS)')
    body = data[8:-4]
    if zlib.crc32(body) != int.from_bytes(data[-4:], 'little'): raise SaveError('the CRC-32 does not match the body')
    return read_body(body)


def read_file(path):
    with open(path, 'rb') as f: return read_save(f.read())


def nested(value):
    return isinstance(value, (dict, list))


def alias(element):
    """A list element's first field ending in Alias that holds a string other than None, else None."""
    if isinstance(element, dict):
        for name, value in element.items():
            if name.endswith('Alias') and isinstance(value, str) and value != 'None': return value
    return None


def walk(value, path='', field=''):
    """(path, last field name, value) of each plain value under value, in save order. A list or map gets an entry
    step only when it holds something nested; otherwise it is one value at the end of its path."""
    if isinstance(value, dict):
        for name, inner in value.items(): yield from walk(inner, f'{path}.{name}' if path else name, name)
    elif isinstance(value, Map) and any(nested(v) for _, v in value):
        for at, (key, inner) in enumerate(value):
            step = key if isinstance(key, (str, int)) and not isinstance(key, bool) else at
            yield from walk(inner, f'{path}[{step}]', field)
    elif isinstance(value, list) and not isinstance(value, Map) and any(nested(v) for v in value):
        for at, inner in enumerate(value):
            name = alias(inner)
            yield from walk(inner, f'{path}[{at if name is None else name}]', field)
    else:
        yield path, field, value


def text(value):
    """A value as the lines write it: True/False, decimal integers, Python's repr of a double, strings as stored, and
    a list or map of plain values in Python's list notation."""
    if isinstance(value, float): return repr(value)
    if isinstance(value, list): return repr(list(value))
    return str(value)


def values(tree):
    """{path: text} of a tree; of two values on one path, the last."""
    return {path: text(value) for path, _, value in walk(tree)}


def diff(old, new):
    """The lines that turn {key: text} old into new, sorted by key."""
    out = []
    for key in sorted(old.keys() | new.keys()):
        if key not in old: out.append(f'+ {key} = {new[key]}')
        elif key not in new: out.append(f'- {key} = {old[key]}')
        elif old[key] != new[key]: out.append(f'~ {key}: {old[key]} -> {new[key]}')
    return out


# The writer: a body for the selftest and the tests, with each property's type picked from its value.
def fstring_bytes(s):
    if not s: return struct.pack('<i', 0)
    if s.isascii(): return struct.pack('<i', len(s) + 1) + s.encode() + b'\0'
    data = s.encode('utf-16-le') + b'\0\0'
    return struct.pack('<i', -(len(data) // 2)) + data


def tag_bytes(name, kind, payload, header=b'', index=0):
    """One tag and its value; header is the type-specific part between the index and the GUID flag."""
    return (fstring_bytes(name) + fstring_bytes(kind) + struct.pack('<ii', len(payload), index) + header + b'\0'
            + payload)


def kind_of(value):
    if isinstance(value, bool): return 'BoolProperty'
    if isinstance(value, int): return 'IntProperty' if -2**31 <= value < 2**31 else 'Int64Property'
    if isinstance(value, float):
        return 'FloatProperty' if struct.unpack('<f', struct.pack('<f', value))[0] == value else 'DoubleProperty'
    if isinstance(value, str): return 'StrProperty'
    if isinstance(value, dict): return 'StructProperty'
    if isinstance(value, Map): return 'MapProperty'
    if isinstance(value, (list, bytes)): return 'ArrayProperty'
    raise TypeError(f'no property type for {value!r}')


def element_bytes(kind, value):
    if kind == 'StructProperty': return properties_bytes(value)
    if kind == 'BoolProperty': return bytes([value])
    if kind == 'StrProperty': return fstring_bytes(value)
    return struct.pack(SCALARS[kind], value)


def properties_bytes(fields):
    out = b''
    for name, value in fields.items():
        name, _, index = name.partition('#')
        kind, header, payload = kind_of(value), b'', None
        if kind == 'BoolProperty': header, payload = bytes([value]), b''
        elif kind == 'StructProperty': header = fstring_bytes('SBCase') + bytes(16)
        elif kind == 'ArrayProperty' and isinstance(value, bytes):
            header, payload = fstring_bytes('ByteProperty'), struct.pack('<i', len(value)) + value
        elif kind == 'ArrayProperty':
            inner = kind_of(value[0]) if value else 'IntProperty'
            items = b''.join(element_bytes(inner, v) for v in value)
            header, payload = fstring_bytes(inner), struct.pack('<i', len(value))
            if inner == 'StructProperty' and value:
                payload += tag_bytes(name, inner, items, fstring_bytes('SBCase') + bytes(16))
            else:
                payload += items
        elif kind == 'MapProperty':
            keys, vals = (kind_of(value[0][0]), kind_of(value[0][1])) if value else ('StrProperty', 'IntProperty')
            header = fstring_bytes(keys) + fstring_bytes(vals)
            payload = struct.pack('<ii', 0, len(value)) + b''.join(
                element_bytes(keys, k) + element_bytes(vals, v) for k, v in value)
        if payload is None: payload = element_bytes(kind, value)
        out += tag_bytes(name, kind, payload, header, int(index or 0))
    return out + fstring_bytes('None')


def encode(tree, save_class=SAVE_CLASS):
    """A GVAS body that reads back as tree: ints as IntProperty or Int64Property, floats as FloatProperty when a
    float holds them, else DoubleProperty, strings as StrProperty, dicts as structs, Map as MapProperty."""
    return (b'GVAS' + struct.pack('<ii', 2, 522) + struct.pack('<3HI', 4, 26, 2, 0) + fstring_bytes('++UE4+Release-4.26')
            + struct.pack('<ii', 3, 1) + bytes(16) + struct.pack('<i', 7) + fstring_bytes(save_class)
            + properties_bytes(tree) + bytes(4))


def wrap(body):
    """The EVAS wrapper the game writes around a body: magic, version 1, the body, its CRC-32."""
    return b'EVAS\x01\x00\x00\x00' + body + struct.pack('<I', zlib.crc32(body))


def selftest():
    tree = {'Level': 7, 'Ratio': 0.30000001192092896, 'Quest': {'QuestAlias': 'Q', 'Done': True},
            'Zones': [{'ZoneAlias': 'Z', 'Objects': Map([(41, {'UniqueKey': 'K'})])}], 'Names': ['a', 'b']}
    header, back = read_save(wrap(encode(tree)))
    assert back == tree and header['read'] == header['size'] and header['save_class'] == SAVE_CLASS, back
    assert values(back)['Zones[Z].Objects[41].UniqueKey'] == 'K' and values(back)['Names'] == "['a', 'b']"
    print('save_read selftest: ok')
    return 0


def main(argv=None):
    args = sys.argv[1:] if argv is None else argv
    command, rest = (args[0], args[1:]) if args else ('', [])
    if command == 'dump' and len(rest) in (1, 2):
        header, tree = read_file(rest[0])
        prefix = rest[1] if len(rest) == 2 else ''
        print(f"# {header['save_class']}, engine {header['engine']}, read {header['read']} of {header['size']} bytes")
        for path, _, value in walk(tree):
            if path.startswith(prefix): print(f'{path} = {text(value)}')
        return 0
    if command == 'diff' and len(rest) == 2:
        for line in diff(values(read_file(rest[0])[1]), values(read_file(rest[1])[1])): print(line)
        return 0
    if command == 'selftest' and not rest: return selftest()
    print(USE)
    return 2


if __name__ == '__main__':
    sys.stdout.reconfigure(errors='replace')
    sys.exit(main())
