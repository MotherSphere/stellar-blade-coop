#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""Makes a new module in a category (docs/dev/structure.md, Adding a module) with the files it needs to load and the
registrations the checks ask for, then runs those checks. docs/dev/modding/new-module.md describes it.

Created: mod/StellarCoop/Scripts/<path>/wiring.lua and commands.lua (coop <name> answers a status line),
tests/lua/<path>/off_test.lua and <name>_test.lua, docs/<category>/<name>.md; with --native also
native/src/<path>/<name>.h and tests/native/<path>/<name>_test.cpp.
Edited: main.lua's MODULES, the modules table of every language file of ui/text/ (the English name in each),
the module count of tests/lua/ui/text_test.lua, the shipped list of tests/tools/install_test.py and the module table of
docs/dev/structure.md.
Every check and every edit is worked out before the first write. A bad name, an unknown category, a module or file that
exists, a console word that exists (main.lua loaded by lua5.4 with the main tests' fixture gives them), with --native
a native namespace of that name, a bad title, a --root that is not a checkout or an edit whose anchor is missing exits
with code 2 and changes nothing. After a real run it runs tests/tools/modules_test.py, tests/lua/ui/text_test.lua
and the module's two Lua tests from the root. It exits with 1 when one of them fails.
Run: python3 -I tools/new_module.py <category>/<name> --title "<English name>" [--native] [--dry-run] [--root <repo>]"""
import argparse
import re
import subprocess
import sys
import textwrap
from pathlib import Path
from string import Template

ROOT = Path(__file__).resolve().parent.parent
S = 'mod/StellarCoop/Scripts'
WIDTH = 120
LICENSE = ('Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors',
           'SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later',
           'SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a '
           'permission.')
NEEDED = (f'{S}/main.lua', f'{S}/ui/text.lua', 'docs/dev/structure.md', 'tests/tools/modules_test.py',
          'tests/tools/install_test.py', 'tests/lua/ui/text_test.lua', 'tests/lua/main/isolation.lua',
          'tests/lua/main/fixture.lua')
# Loads main.lua with the main tests' fixture and prints each word of its command table as "word <word>".
WORDS = ("dofile('tests/lua/main/fixture.lua') local L=require('main.loader') local run,M=L.run "
         "L.run=function(s,l) M=s return run(s,l) end load_main(true) "
         "for w in pairs(M.commands) do io.write('word ',w,'\\n') end")
NAME = re.compile(r'[a-z][a-z0-9_]*')
# 1 to 40 characters: the off notice puts the name in a chat line of at most 200 bytes (core/line.lua).
TITLE = re.compile(r"[A-Za-z0-9](?:[A-Za-z0-9 '!&()+,.:?-]{0,38}[A-Za-z0-9'!&()+,.:?-])?")
LUA_WORDS = set('and break do else elseif end false for function goto if in local nil not or repeat return then true '
                'until while'.split())
CPP_WORDS = set('alignas alignof and_eq asm auto bitand bitor bool case catch char char8_t char16_t char32_t class '
                'compl concept const consteval constexpr constinit const_cast continue co_await co_return co_yield '
                'decltype default delete double dynamic_cast enum explicit export extern float friend inline int long '
                'mutable namespace new noexcept not_eq nullptr operator or_eq private protected public register '
                'reinterpret_cast requires short signed sizeof static static_assert static_cast struct switch '
                'template this thread_local throw try typedef typeid typename union unsigned using virtual void '
                'volatile wchar_t xor xor_eq coop std'.split()) | LUA_WORDS


class Refused(Exception):
    pass


def comment(mark, text):
    """text as comment lines of at most WIDTH columns."""
    return ''.join(f'{mark} {line}\n' for line in textwrap.wrap(text, WIDTH - len(mark) - 1, break_on_hyphens=False,
                                                                       break_long_words=False))


def head(mark, text): return ''.join(f'{mark} {line}\n' for line in LICENSE) + comment(mark, text)


def fill(text): return textwrap.fill(text, WIDTH, break_on_hyphens=False, break_long_words=False)


def closing(text, at, rel):
    """The position of the } that closes the Lua { at, its strings and comments skipped."""
    depth, i = 0, at
    while i < len(text):
        c = text[i]
        if text.startswith('--', i):
            i = text.find('\n', i)
            if i < 0: break
        elif c in '\'"':
            i += 1
            while i < len(text) and text[i] not in (c, '\n'): i += 2 if text[i] == '\\' else 1
        elif c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0: return i
        i += 1
    raise Refused(f'{rel}: the table at line {text.count(chr(10), 0, at) + 1} is not closed, so nothing was changed')


def append(text, at, item, sep):
    """item added last to the list whose closing mark is at: on the closing line when it fits in WIDTH columns, else on
    a new line with that line's indent."""
    lead = '' if text[:at].rstrip().endswith((',', '{', '(')) else sep
    start, stop = text.rfind('\n', 0, at) + 1, text.find('\n', at)
    line = text[start:len(text) if stop < 0 else stop]
    if len(line) + len(lead) + len(item) <= WIDTH: return text[:at] + lead + item + text[at:]
    return text[:at] + lead.rstrip() + '\n' + re.match(r' *', line).group() + item + text[at:]


def find(text, pattern, rel, what):
    m = re.search(pattern, text, re.M | re.S)
    if not m: raise Refused(f'{rel}: {what} was not found, so nothing was changed')
    return m


WIRING = Template("""return {
uses={},
exports={},
new=function(M)
return require('$module.commands').new({})
end,
}
""")
COMMANDS = Template("""local Commands={}
local USE='Use: coop $name [status]'
function Commands.new(o)
    local self={}
    function self.$name(sub,extra)
        if extra~=nil or (sub~=nil and sub~='status') then return false,USE end
        return true,'$module: nothing built yet'
    end
    return self
end
return Commands
""")
OFF_TEST = Template("""dofile('tests/lua/main/isolation.lua')('$module')
print('${module}_off_test ok')
""")
FIRST_TEST = Template("""package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Cmd=require('$module.commands').new({})
local ok,line=Cmd.$name()
assert(ok and line=='$module: nothing built yet',line)
ok,line=Cmd.$name('status')
assert(ok and line=='$module: nothing built yet',line)
ok,line=Cmd.$name('nope')
assert(not ok and line=='Use: coop $name [status]',line)
print('${name}_test ok')
""")
HEADER = Template("""#pragma once

namespace coop::$name {

} // namespace coop::$name
""")
NATIVE_TEST = Template("""#include "$path/$name.h"

int main() { return 0; }
""")


def made(path, title, native):
    """{path: text} of the files a new module gets."""
    category, _, name = path.rpartition('/')
    v = {'path': path, 'module': path.replace('/', '.'), 'name': name}
    native_dir = f' and `native/src/{path}/`' if native else ''
    native_test = f' `tests/native/{path}/{name}_test.cpp` builds its header on the build machine.' if native else ''
    files = {
        f'{S}/{path}/wiring.lua': head('--', f'The wiring of {title} ({path}/): new, it builds nothing yet. To fill '
                                       'in: what new builds and sets in M (each field in exports), the modules it '
                                       'reads later through M (in uses) and its kit groups in build, as '
                                       'docs/dev/structure.md (The manifest) says.') + WIRING.substitute(v),
        f'{S}/{path}/commands.lua': head('--', f'coop {name}: alone or with status, the status line of {title}. '
                                         f'{path}/wiring.lua builds it with new(o) at each Lua load and '
                                         'main/loader.lua merges it into the command table. o: nothing yet. To fill '
                                         'in: the words of the module and what new(o) gets from its wiring.lua.')
        + COMMANDS.substitute(v),
        f'tests/lua/{path}/off_test.lua': head('--', '') + OFF_TEST.substitute(v),
        f'tests/lua/{path}/{name}_test.lua': head('--', f'coop {name} ({path}/commands.lua): alone and with status '
                                                  'it answers the status line; another word is refused with the use '
                                                  'line.') + FIRST_TEST.substitute(v),
        f'docs/{category}/{name}.md': '\n\n'.join((
            f'# {title}',
            fill(f'New module `{v["module"]}`, made by `tools/new_module.py`. It has one console word and no game code '
                 'yet.'),
            '## What players see',
            fill(f'To fill in: what the module does in the game and its console words. `coop {name}` and '
                 f'`coop {name} status` answer its status line for now.'),
            '## How it works',
            fill(f'To fill in: its files in `{S}/{path}/`{native_dir}, what its `wiring.lua` builds, the modules it '
                 'reads later and the fields of `M` it sets.'),
            '## Tests',
            fill(f'`tests/lua/{path}/off_test.lua` checks that a failure of this module at load turns this module off '
                 f'alone. `tests/lua/{path}/{name}_test.lua` checks `coop {name}`.{native_test}'))) + '\n',
    }
    if native:
        files[f'native/src/{path}/{name}.h'] = head('//', f'The native part of {title} ({path}/): nothing yet. To '
                                                    f'fill in: its declarations in coop::{name}, its game thread part '
                                                    '<part>_game.inc and its worker part <part>_worker.inc in this '
                                                    f'folder. tests/native/{path}/{name}_test.cpp checks this file on '
                                                    'the build machine.') + HEADER.substitute(v)
        files[f'tests/native/{path}/{name}_test.cpp'] = head('//', f'The header of {title} ({path}/{name}.h) builds '
                                                             'on its own on the build machine. To fill in: the checks '
                                                             'of its logic.') + NATIVE_TEST.substitute(v)
    return files


def plan(root, spec, title, native):
    """({path: text} to create, {path: (text, what)} to edit, the language files) for this module, or Refused."""
    for rel in NEEDED:
        if not (root / rel).is_file(): raise Refused(f'{root} is not a Stellar Blade Online checkout: {rel} is missing')
    read = {}

    def text(rel):
        if rel not in read: read[rel] = (root / rel).read_text(encoding='utf-8')
        return read[rel]

    path = spec.strip('/')
    category, _, name = path.rpartition('/')
    if not category or not NAME.fullmatch(name) or name in (CPP_WORDS if native else LUA_WORDS):
        raise Refused(f'bad module name {spec}: give <category>/<name>, the name in lower case letters, digits and _, '
                      'starting with a letter, not a Lua' + (' or C++' if native else '') + ' keyword')
    sentence = find(' '.join(text('docs/dev/structure.md').split()), r'category folders \(([^)]*)\)',
                    'docs/dev/structure.md', 'the sentence that lists the category folders').group(1)
    categories = [c.strip('/') for c in re.findall(r'`([^`]+)`', sentence)]
    if category not in categories:
        raise Refused(f'unknown category {category}: docs/dev/structure.md lists {", ".join(categories)}')
    if not TITLE.fullmatch(title):
        raise Refused(f'bad title {title!r}: 1 to 40 characters (letters, digits, spaces and \' ! & ( ) + , . : ? -), '
                      'starting with a letter or a digit, not ending with a space')
    module = path.replace('/', '.')
    docs = f'docs/{category}/{name}.md'
    files = made(path, title, native)
    main_rel = f'{S}/main.lua'
    listed = find(text(main_rel), r'MODULES=\{', main_rel, 'the MODULES list')
    end = closing(text(main_rel), listed.end() - 1, main_rel)
    if f"'{module}'" in text(main_rel)[listed.end():end]: raise Refused(f'{module} already exists in MODULES')
    for folder in (f'{S}/{path}', f'tests/lua/{path}', f'native/src/{path}', f'tests/native/{path}', docs):
        if (root / folder).exists(): raise Refused(f'{module} already exists: {folder} is there')
    # The words as main.lua's load gives them. Some are made in a loop (eve's fly and slowmo): a text scan misses them.
    try:
        done = subprocess.run(['lua5.4', '-e', WORDS], cwd=root, stdin=subprocess.DEVNULL, capture_output=True,
                              text=True)
    except OSError as why:
        raise Refused(f'lua5.4 did not start ({why.strerror}): the tool reads the console words with it')
    if done.returncode:
        raise Refused('main.lua does not load with tests/lua/main/fixture.lua, so the console words are unknown: '
                      + (done.stderr.strip().splitlines() or ['no error line'])[0])
    if name in re.findall(r'(?m)^word (\w+)$', done.stdout):
        raise Refused(f'coop {name} is already a console word: pick another name')
    if native:
        for p in sorted((root / 'native/src').rglob('*')):
            if p.suffix in ('.h', '.inc', '.cpp') and re.search(rf'\bnamespace\s+(?:\w+::)*{name}\b',
                                                                 p.read_text(encoding='utf-8')):
                raise Refused(f'{p.relative_to(root)} has a namespace {name} already, so coop::{name} would join '
                              'it: pick another name')
    edits = {main_rel: (append(text(main_rel), end, f"'{module}'", ','), f"add '{module}' to MODULES")}
    quoted = f'"{title}"' if "'" in title else f"'{title}'"
    langs = re.findall(r"(?m)^T(?:\.\w+|\['[\w-]+'\])=require\('ui\.text\.([\w-]+)'\)", text(f'{S}/ui/text.lua'))
    if not langs: raise Refused(f'{S}/ui/text.lua: no language table was found, so nothing was changed')
    for c in langs:
        rel = f'{S}/ui/text/{c}.lua'
        if not (root / rel).is_file(): raise Refused(f'{rel} is missing, so nothing was changed')
        at = find(text(rel), r'^\s*modules=\{', rel, 'the modules table').end() - 1
        edits[rel] = (append(text(rel), closing(text(rel), at, rel), f"['{module}']={quoted}", ','),
                      f"add ['{module}']={quoted} to modules")
    rel = 'tests/lua/ui/text_test.lua'
    count = find(text(rel), r'assert\(MODULE_KEYS==(\d+),', rel, 'the module count assert(MODULE_KEYS==<n>,')
    words_count = find(text(rel), r"T\.en's (\d+) keys", rel, "the module count in T.en's <n> keys")
    new = int(count.group(1)) + 1
    t = text(rel)
    t = t[:count.start(1)] + str(new) + t[count.end(1):]
    t = t[:words_count.start(1)] + str(new) + t[words_count.end(1):]
    edits[rel] = (t, f'count {new} module names')
    rel = 'tests/tools/install_test.py'
    t = text(rel)
    wiring = find(t, r"^( *)\*\(f'\{module\}/wiring' for module in \(", rel, 'the wiring tuple')
    t = append(t, t.index('))', wiring.end()), f"'{path}'", ', ')
    t = t[:wiring.start()] + f"{wiring.group(1)}'{path}/commands',\n" + t[wiring.start():]
    edits[rel] = (t, f'ship {path}/commands.lua and {path}/wiring.lua')
    rel = 'docs/dev/structure.md'
    t = text(rel)
    table = find(t, r'^\| Module \| Players see it as \|.*?\n(?=[^|])', rel, 'the module table')
    row = (f'| `{module}` | {title} | `{path}/` | ' + (f'`{path}/`' if native else 'none')
           + f' | [{title}](../{category}/{name}.md) | |\n')
    edits[rel] = (t[:table.end()] + row + t[table.end():], f'add the {module} row to the module table')
    return files, edits, langs


def steps(path, name, native, langs):
    """What is left to do by hand."""
    out = ['Left to do by hand:',
           f'- Translate its name in {S}/ui/text/: {", ".join(f"{c}.lua" for c in langs if c != "en")}.',
           '- Add its docs page to docs/README.md.',
           '- A console word for players goes in M.USAGE (main/base.lua) and docs/usage.md.',
           '- Screens or HUDs: build steps in its wiring.lua and their calls in main/ui.lua (Adding a module, step 5).']
    if native:
        out += [f'- Native: put its parts in native/src/{path}/ as <part>_game.inc (game thread) and '
                '<part>_worker.inc (worker).',
                f'- Include {path}/{name}.h at the top of native/src/glue/tick.cpp, then each part where its order '
                'says: a part sees what the parts before it declare.',
                '- A status line of its own goes through native/src/glue/tick/status.inc into coop-status.txt.']
    return '\n'.join(out)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('module', metavar='<category>/<name>', help='for example world/lanterns or online/modes/duel')
    parser.add_argument('--title', required=True, help='its English name, as players see it')
    parser.add_argument('--native', action='store_true', help='also a native header and a native test')
    parser.add_argument('--dry-run', action='store_true', help='print what it would do and change nothing')
    parser.add_argument('--root', type=Path, default=ROOT, help='the repository (default: %(default)s)')
    args = parser.parse_args(argv)
    root = args.root.resolve()
    try:
        files, edits, langs = plan(root, args.module, args.title, args.native)
    except Refused as why:
        print(f'Refused: {why}', file=sys.stderr)
        return 2
    path = args.module.strip('/')
    name = path.rpartition('/')[2]
    verb = ('Would create', 'Would edit') if args.dry_run else ('Created', 'Edited')
    for rel, data in files.items():
        if not args.dry_run:
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            (root / rel).write_text(data, encoding='utf-8')
        print(f'{verb[0]} {rel}')
    for rel, (data, what) in edits.items():
        if not args.dry_run: (root / rel).write_text(data, encoding='utf-8')
        print(f'{verb[1]} {rel}: {what}')
    if args.dry_run:
        print('Dry run: nothing changed.')
        return 0
    print(steps(path, name, args.native, langs))
    failed = 0
    for cmd in ([sys.executable, '-I', 'tests/tools/modules_test.py'], ['lua5.4', 'tests/lua/ui/text_test.lua'],
                ['lua5.4', f'tests/lua/{path}/off_test.lua'], ['lua5.4', f'tests/lua/{path}/{name}_test.lua']):
        done = subprocess.run(cmd, cwd=root, capture_output=True, text=True)
        print(f'{cmd[-1]}: ' + ('passed' if done.returncode == 0 else 'FAILED'))
        print((done.stdout + done.stderr).strip())
        failed += done.returncode != 0
    if args.native: print('python3 tools/install.py --dry-run builds and runs the native test with the others.')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
