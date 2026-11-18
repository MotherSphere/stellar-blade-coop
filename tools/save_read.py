#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""Reads a Stellar Blade save (an EVAS wrapper around an Unreal 4.26 GVAS body) and prints every value in it as one
`path = value` line, or the paths whose value differs between two saves. Read only: it never writes a file.

  python3 tools/save_read.py dump SAVE [PREFIX]   the values in save order, those whose path starts with PREFIX
  python3 tools/save_read.py diff OLD NEW         + path only in NEW, - path only in OLD, ~ changed, sorted by path
  python3 tools/save_read.py selftest             reads back a body built in memory

The layout and the path rules are in docs/dev/story-dump.md. tools/story_lines.py reads saves through this file.
"""
import struct
import sys
import zlib

USE = 'Use: save_read.py dump SAVE [PREFIX] | diff OLD NEW | selftest'
SAVE_CLASS = '/Script/SB.SBSaveGame'
SCALARS = {kind: struct.Struct(fmt) for kind, fmt in (
    ('IntProperty', '<i'), ('UInt32Property', '<I'), ('Int64Property', '<q'), ('UInt64Property', '<Q'),
    ('Int16Property', '<h'), ('UInt16Property', '<H'), ('Int8Property', '<b'), ('FloatProperty', '<f'),
    ('DoubleProperty', '<d'))}
STRINGS = {'NameProperty', 'StrProperty', 'ObjectProperty', 'EnumProperty'}
# Structs the engine writes as raw fields, with no tags: read as a list of numbers, or as one number. A Guid is 16
# bytes shown as hex.
NUMBER_LISTS = {name: struct.Struct(fmt) for name, fmt in (
    ('Vector', '<3f'), ('Rotator', '<3f'), ('Quat', '<4f'), ('LinearColor', '<4f'), ('Vector2D', '<2f'),
    ('Color', '<4B'), ('IntPoint', '<2i'))}
ONE_NUMBER = {'DateTime': struct.Struct('<q'), 'Timespan': struct.Struct('<q')}
INT32, ENGINE = struct.Struct('<i'), struct.Struct('<3HI')
FSTRING_LIMIT = 1024 * 1024  # A longer FString means the reader is out of step.


class SaveError(ValueError):
    """The bytes are not a save this reader understands."""


class Map(list):
    """A map value: its (key, value) pairs in file order. A key can be a struct, so it is no dict."""


class Reader:
    """A cursor over a GVAS body. From the top down: a tagged property list, one tag, the values, then the FStrings,
    numbers and bytes they are made of."""

    def __init__(self, data):
        self.data, self.pos = data, 0

    def properties(self):
        """A tagged property list up to the name None, as {name: value}; a tag with array index i is name#i."""
        found = {}
        while (tag := self.tag()) is not None:
            name, kind, size, index, extra = tag
            start = self.pos
            found[f'{name}#{index}' if index else name] = self.value(kind, size, extra)
            self.pos = start + size  # Whatever the value used, the next tag starts there.
        return found

    def tag(self):
        """(name, type, value size, array index, type header) of the next tag, or None at the name None. The type
        header holds the bool's value, the struct type, the enum or element type, or the map's key and value types."""
        name = self.fstring()
        if name == 'None': return None
        kind, size, index = self.fstring(), self.int32(), self.int32()
        extra = None
        if kind == 'BoolProperty': extra = self.take(1)[0] != 0
        elif kind == 'StructProperty': extra = self.fstring(); self.take(16)  # The struct GUID.
        elif kind in ('ByteProperty', 'EnumProperty', 'ArrayProperty', 'SetProperty'): extra = self.fstring()
        elif kind == 'MapProperty': extra = (self.fstring(), self.fstring())
        if self.take(1)[0]: self.take(16)  # The property GUID, after its flag.
        return name, kind, size, index, extra

    def value(self, kind, size, extra):
        start, end = self.pos, self.pos + size
        if kind == 'BoolProperty': return extra
        if kind in SCALARS or kind in STRINGS: return self.element(kind)
        if kind == 'SoftObjectProperty':
            path = self.fstring()
            return f'{path}|{self.fstring()}' if self.pos < end else path
        if kind == 'ByteProperty': return self.fstring() if extra != 'None' else self.take(1)[0]
        if kind == 'StructProperty': return self.struct(extra)
        if kind == 'SetProperty': self.int32()  # 0 in saves: the count of elements taken out.
        if kind in ('ArrayProperty', 'SetProperty'): return self.array(extra, end)
        if kind == 'MapProperty': return self.map(extra, start, size)
        if kind == 'TextProperty': return self.take(size).hex()
        return f'<{kind} {self.take(size).hex()}>'

    def struct(self, name):
        if name in ONE_NUMBER: return self.read(ONE_NUMBER[name])[0]
        if name in NUMBER_LISTS: return list(self.read(NUMBER_LISTS[name]))
        if name == 'Guid': return self.take(16).hex()
        return self.properties()

    def array(self, inner, end):
        count = self.int32()
        if inner == 'ByteProperty' and self.pos + count == end: return self.take(count).hex()  # Plain bytes.
        if inner != 'StructProperty': return [self.element(inner) for _ in range(count)]
        if count == 0: return []
        inner_tag = self.tag()  # It names the struct type.
        if inner_tag is None: raise SaveError(f'a struct array with no inner tag, before byte {self.pos}')
        return [self.struct(inner_tag[4]) for _ in range(count)]

    def map(self, types, start, size):
        self.int32()  # 0 in saves: the count of entries taken out.
        count = self.int32()
        pairs = Map()
        for _ in range(count): pairs.append((self.element(types[0]), self.element(types[1])))
        used = self.pos - start
        return pairs if used == size else f"<error: the map's entries take {used} of its {size} bytes>"

    def element(self, kind):
        """A value inside a container: no tag, and a struct there has no type name, so it is a tagged list."""
        if kind in SCALARS: return self.read(SCALARS[kind])[0]
        if kind in STRINGS or kind == 'SoftObjectProperty': return self.fstring()
        if kind == 'BoolProperty': return self.take(1)[0] != 0
        if kind == 'ByteProperty': return self.fstring() if self.name_ahead() else self.take(1)[0]
        if kind == 'StructProperty': return self.properties()
        raise SaveError(f'no reading for a {kind} inside a container')

    def fstring(self):
        """An FString: an int32 length that counts the NUL, then Latin-1 bytes (positive) or UTF-16LE units."""
        at = self.pos
        length = self.int32()
        if length > FSTRING_LIMIT:
            raise SaveError(f'byte {at}: an FString length of {length}, so the reader is out of step')
        if length < 0:
            units = -length
            return self.take(units * 2).decode('utf-16-le', 'replace').removesuffix('\0')
        return self.take(length).decode('latin-1').removesuffix('\0')

    def name_ahead(self):
        """Whether the next bytes read as an FString of 1 to 255 printable ASCII characters and its NUL."""
        at = self.pos
        if at + 4 > len(self.data): return False
        n = int.from_bytes(self.data[at:at + 4], 'little', signed=True)
        text = self.data[at + 4:at + 4 + n]
        return 2 <= n <= 256 and len(text) == n and text[-1] == 0 and all(0x20 <= b < 0x7f for b in text[:-1])

    def int32(self):
        return self.read(INT32)[0]

    def read(self, layout):
        """The values of a struct.Struct layout at the cursor."""
        return layout.unpack(self.take(layout.size))

    def take(self, n):
        end = self.pos + n
        if n < 0 or end > len(self.data):
            raise SaveError(f'a read of {n} bytes at {self.pos} goes past the end of the {len(self.data)} bytes')
        chunk, self.pos = self.data[self.pos:end], end
        return chunk


def read_body(body):
    """(header, tree) of a GVAS body. header: save_version, package_version, engine, branch, save_class, read (bytes
    read) and size; tree: the top-level properties."""
    r = Reader(body)
    if r.take(4) != b'GVAS': raise SaveError('not a GVAS body')
    save_version, package_version = r.int32(), r.int32()
    major, minor, patch, changelist = r.read(ENGINE)
    branch = r.fstring()
    r.int32()  # Custom version format.
    for _ in range(r.int32()): r.take(20)  # GUID and version of each custom version.
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
    change = {key: f'+ {key} = {value}' for key, value in new.items() if key not in old}
    for key, value in old.items():
        if key not in new: change[key] = f'- {key} = {value}'
        elif new[key] != value: change[key] = f'~ {key}: {value} -> {new[key]}'
    return [change[key] for key in sorted(change)]


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
    return SCALARS[kind].pack(value)


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
        print(f"# {header['save_class']} (UE {header['engine']}): {header['read']} of {header['size']} body bytes read")
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
