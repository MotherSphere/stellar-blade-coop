#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""No module depends on another (docs/dev/structure.md). A module is a folder of mod/StellarCoop/Scripts with a
wiring.lua (cut/enemies/ is cut.enemies), with its tests under tests/lua/<its path>/ and its native part in its folder
of native/src. scan(root) lists the violations, each as '<rule> <file>:<line>: <what>':
R1 main.lua's MODULES names exactly the folders with a wiring.lua; each has tests/lua/<path>/off_test.lua.
R2 No manifest has a needs key.
R3 No file of a module (code or test) requires, fakes (package.loaded or package.preload) or patches
   (require('<name>').<field>=) a file of another module, or runs one with dofile; main.lua, main/, core/, ui/kit/,
   ui/text.lua and ui/text/ read no module. Their tests read none either, except tests/lua/main/ and
   tests/lua/ui/text_test.lua, which check the runtime and the text tables against what modules put through them.
R4 Each M.<field> a wiring.lua reads that another module exports, each view(M,'<field>') of one and each
   get(M,'<module>',...) names that module in uses; uses names nothing else (a module's other files get what its new
   hands them).
R5 Exports are unique across modules and the runtime's fields; a wiring assigns only its own exports (partner sets
   the runtime's aside_note, the crash sentinel's note).
R6 Each build(M,'<module>','<step>' in main/ui.lua names a step of that module's manifest; each step is built once.
R7 A wiring that calls RegisterHook or NotifyOnNewObject guards each callback with M.off_modules: the hook outlives an
   off module.
R8 Native: no header, part or test of a module folder reads another module folder's header, by an #include or by a
   name through the header's namespace (world::kNoneName: tick.cpp includes every header once at its top, so a part
   reads headers it never includes); a shared header (game, link, lion, ui) reads none either. Only glue/ (the hub)
   and the tests of tests/native/game/globals_test.cpp and tests/native/link/ may; no module part
   (native/src/<module>/*.inc, in glue/tick.cpp's order) uses a name another module folder's part defines at its top
   level (whole tokens, comments and strings out, a local of the same name not counted).
R9 Each language table of ui/text.lua, loaded by lua5.4, names exactly the modules of MODULES in modules.
It first runs on planted trees, one violation each, so no rule passes vacuously, then on this repository, which must
be clean.
Run: python3 tests/tools/modules_test.py"""
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = 'mod/StellarCoop/Scripts'
SRC = 'native/src'
SHARED_LUA = ('main.lua', 'main/', 'core/', 'ui/kit/', 'ui/text.lua', 'ui/text/')
SHARED_LUA_TESTS = ('tests/lua/main/', 'tests/lua/ui/text_test.lua')
SHARED_NATIVE = {'game', 'link', 'lion', 'ui', 'glue'}
NATIVE_TESTS_READING = ('tests/native/game/globals_test.cpp', 'tests/native/link/')
RUNTIME_SET_BY = {'aside_note': 'partner'}  # A runtime value a module sets (MAP.md section 10).
HOOKS = re.compile(r'\b(RegisterHook|NotifyOnNewObject)\b')
FUNCTION = re.compile(r'\bfunction\s*\(')
GUARD = re.compile(r"function\s*\([^)]*\)\s*if\s+M\.off_modules(?:\.(\w+)|\['([\w.]+)'\])\s+then\s+return\s+end")


def line_of(text, pos): return text.count('\n', 0, pos) + 1


def strip_lua(text, strings):
    """Comments blanked (and string contents when strings), newlines kept."""
    out, i, n = [], 0, len(text)
    while i < n:
        long = re.match(r'(--)?\[(=*)\[', text[i:i + 64])
        if text.startswith('--', i) or long:
            if long:
                end = ']' + long.group(2) + ']'
                j = text.find(end, i + len(long.group(0)))
                j = n if j < 0 else j + len(end)
            else:
                j = text.find('\n', i)
                j = n if j < 0 else j
            if long and not long.group(1) and not strings: out.append(text[i:j])
            else: out.append(re.sub(r'[^\n]', ' ', text[i:j]))
            i = j
        elif text[i] in '\'"':
            j = i + 1
            while j < n and text[j] not in (text[i], '\n'): j += 2 if text[j] == '\\' else 1
            j += 1
            out.append(text[i] + ' ' * (j - i - 2) + text[i] if strings else text[i:j])
            i = j
        else:
            out.append(text[i])
            i += 1
    return ''.join(out)


def strip_c(code):
    """C++ comments and string or char literals blanked (newlines kept)."""
    out, i, n = [], 0, len(code)
    while i < n:
        c = code[i]
        if code.startswith('//', i):
            j = code.find('\n', i)
            j = n if j < 0 else j
            out.append(' ' * (j - i))
            i = j
        elif code.startswith('/*', i):
            j = code.find('*/', i + 2)
            j = n if j < 0 else j + 2
            out.append(re.sub(r'[^\n]', ' ', code[i:j]))
            i = j
        elif c in '"\'' and not (c == "'" and i > 0 and code[i - 1].isalnum()):  # 50'000: a digit separator.
            j = i + 1
            if c == '"' and i > 0 and code[i - 1] == 'R':  # Raw string R"(...)".
                k = code.find('(', j)
                end = ')' + code[j:k] + '"'
                j = code.find(end, k) + len(end)
            else:
                while j < n and code[j] != c: j += 2 if code[j] == '\\' else 1
                j += 1
            out.append(c + ' ' * (j - i - 2) + c if j - i >= 2 else code[i:j])
            i = j
        else:
            out.append(c)
            i += 1
    return ''.join(out)


def lua_modules(root):
    """{dotted module name: its path} for each folder of Scripts with a wiring.lua."""
    base = root / SCRIPTS
    return {str(p.parent.relative_to(base)).replace('/', '.'): str(p.parent.relative_to(base))
            for p in base.rglob('wiring.lua')}


def owner(name, mods):  # The module a dotted file name belongs to (the longest module path), or None.
    best = None
    for m in mods:
        if (name == m or name.startswith(m + '.')) and (best is None or len(m) > len(best)): best = m
    return best


def manifest(text):
    """uses, exports, build steps of a wiring.lua (comments out) with the position of a needs key."""
    code = strip_lua(text, False)
    def names(key):
        m = re.search(r'(?m)^\s*' + key + r'=(\{.*?\})', code, re.S)
        return re.findall(r"'([\w.]+)'", m.group(1)) if m else []
    build = re.search(r'(?m)^build=\{(.*)\n\},?\s*\n\}', code, re.S)
    steps = re.findall(r'(?m)^(\w+)=function\(M,Ui\)', build.group(1)) if build else []
    needs = re.search(r'(?m)(?:^|[{,])\s*needs\s*=', code)
    return {'uses': names('uses'), 'exports': names('exports'), 'build': steps, 'needs': needs and needs.start()}


def runtime_fields(root):
    base, fields = root / SCRIPTS, {'print', 'log', 'VERSION', 'folder', 'commands', 'off_modules', 'off_notes'}
    for p in [base / 'main.lua', *sorted((base / 'main').glob('*.lua'))]:
        fields |= assigned(strip_lua(p.read_text(encoding='utf-8'), True))
    return fields


def assigned(code):
    out = set(re.findall(r'\bfunction\s+M\.(\w+)', code))
    for m in re.finditer(r'(?m)^\s*(M\.\w+(?:\s*,\s*M\.\w+)*)\s*=(?!=)', code):
        out |= set(re.findall(r'M\.(\w+)', m.group(1)))
    return out


def check_lua(root, out):
    mods, base = lua_modules(root), root / SCRIPTS
    main = (base / 'main.lua').read_text(encoding='utf-8')
    m = re.search(r'MODULES=(\{.*?\})', main, re.S)
    listed = re.findall(r"'([\w.]+)'", m.group(1)) if m else []
    at = line_of(main, m.start()) if m else 1
    for name in sorted(set(listed) ^ set(mods)):
        out.append(f'R1 {SCRIPTS}/main.lua:{at}: {name} '
                   + ('has no wiring.lua' if name in listed else 'has a wiring.lua but is not in MODULES'))
    for name, path in sorted(mods.items()):
        if not (root / 'tests/lua' / path / 'off_test.lua').exists():
            out.append(f'R1 tests/lua/{path}/off_test.lua:1: {name} has no load-failure test')
    walls = {name: manifest((base / path / 'wiring.lua').read_text(encoding='utf-8')) for name, path in mods.items()}
    exporter = {}
    runtime = runtime_fields(root)
    for name, w in sorted(walls.items()):
        f = f'{SCRIPTS}/{mods[name]}/wiring.lua'
        if w['needs'] is not None:
            text = (base / mods[name] / 'wiring.lua').read_text(encoding='utf-8')
            out.append(f'R2 {f}:{line_of(text, w["needs"])}: a needs key (no module needs another)')
        for x in w['exports']:
            if x in exporter: out.append(f'R5 {f}:1: {x} is exported by {exporter[x]} too')
            elif x in runtime: out.append(f'R5 {f}:1: {x} is a runtime field')
            else: exporter[x] = name
    # R3: what each Lua file of the tree reads of a module's files.
    files = sorted((root / SCRIPTS).rglob('*.lua')) + sorted((root / 'tests/lua').rglob('*.lua'))
    for p in files:
        rel = str(p.relative_to(root))
        under = rel[len(SCRIPTS) + 1:] if rel.startswith(SCRIPTS) else rel[len('tests/lua/'):]
        mine = owner(under[:-4].replace('/', '.'), mods)
        if mine is None and (rel.startswith(SHARED_LUA_TESTS) or not under.startswith(SHARED_LUA)): continue
        code = strip_lua(p.read_text(encoding='utf-8'), False)
        reads = [(m.start(), m.group(2), 'requires')
                 for m in re.finditer(r'''\brequire\s*\(?\s*(['"])([\w.\-]+)\1''', code)]
        reads += [(m.start(), m.group(3) or m.group(4), 'fakes') for m in re.finditer(
            r'''\bpackage\.(loaded|preload)\s*(?:\[\s*(['"])([\w.\-]+)\2\s*\]|\.(\w+))''', code)]
        reads += [(m.start(), m.group(2).replace('/', '.'), 'runs') for m in re.finditer(
            r'''\b(?:dofile|loadfile)\s*\(\s*(['"])''' + SCRIPTS + r'''/([\w/\-]+)\.lua\1''', code)]
        reads += [(m.start(), m.group(2).replace('/', '.'), 'runs') for m in re.finditer(
            r'''\b(?:dofile|loadfile)\s*\(\s*(['"])tests/lua/([\w/\-]+)\.lua\1''', code)]
        for pos, name, how in reads:
            o = owner(name, mods)
            if o is not None and o != mine:
                patch = re.match(r'''require\s*\(\s*['"][\w.\-]+['"]\s*\)\s*\.\s*\w+\s*=(?!=)''', code[pos:])
                out.append(f'R3 {rel}:{line_of(code, pos)}: {mine or "a shared file"} '
                           f'{"patches" if patch else how} {name} ({o})')
    # R4, R5 (assignments), R7: each wiring's M reads and hooks.
    for name, w in sorted(walls.items()):
        f = f'{SCRIPTS}/{mods[name]}/wiring.lua'
        text = (base / mods[name] / 'wiring.lua').read_text(encoding='utf-8')
        code = strip_lua(text, True)
        raw = strip_lua(text, False)
        read = {}
        for m in re.finditer(r'(?<![\w.])M\.(\w+)', code):
            o = exporter.get(m.group(1))
            if o and o != name: read.setdefault(o, line_of(code, m.start()))
        for m in re.finditer(r"""\bview\s*\(\s*M\s*,\s*'(\w+)'""", raw):
            o = exporter.get(m.group(1))
            if o is None: out.append(f'R4 {f}:{line_of(raw, m.start())}: view of {m.group(1)}, no module exports it')
            elif o != name: read.setdefault(o, line_of(raw, m.start()))
        for m in re.finditer(r"""\bget\s*\(\s*M\s*,\s*'([\w.]+)'\s*,\s*'(\w+)'""", raw):
            if exporter.get(m.group(2)) != m.group(1):
                out.append(f'R4 {f}:{line_of(raw, m.start())}: get of {m.group(2)}, not an export of {m.group(1)}')
            if m.group(1) != name: read.setdefault(m.group(1), line_of(raw, m.start()))
        for o, ln in sorted(read.items()):
            if o not in w['uses']: out.append(f'R4 {f}:{ln}: reads {o} late without {o} in uses')
        for o in w['uses']:
            if o not in read: out.append(f'R4 {f}:1: uses names {o}, which it never reads')
        for x in sorted(assigned(code)):
            if x not in w['exports'] and RUNTIME_SET_BY.get(x) != name:
                out.append(f'R5 {f}:1: assigns M.{x}, not one of its exports')
        for m in HOOKS.finditer(raw):
            fn = FUNCTION.search(raw, m.end())
            g = fn and GUARD.match(raw, fn.start())
            if not g or (g.group(1) or g.group(2)) != name:
                out.append(f'R7 {f}:{line_of(raw, m.start())}: {m.group(1)} callback without '
                           f"if M.off_modules['{name}'] then return end")
    # R6: main/ui.lua's build steps.
    ui = (base / 'main/ui.lua').read_text(encoding='utf-8')
    built = set()
    for m in re.finditer(r"build\(M,'([\w.]+)','(\w+)'", ui):
        key, ln = (m.group(1), m.group(2)), line_of(ui, m.start())
        if key in built: out.append(f'R6 {SCRIPTS}/main/ui.lua:{ln}: {key[0]} {key[1]} built twice')
        elif key[0] not in walls or key[1] not in walls[key[0]]['build']:
            out.append(f'R6 {SCRIPTS}/main/ui.lua:{ln}: {key[0]} has no build step {key[1]}')
        built.add(key)
    for name, w in sorted(walls.items()):
        for step in w['build']:
            if (name, step) not in built:
                out.append(f'R6 {SCRIPTS}/{mods[name]}/wiring.lua:1: build step {step} is never built')
    # R9: each language table's module names.
    lua = ("package.path='" + SCRIPTS + "/?.lua;'..package.path local T=require('ui.text') "
           "for name,t in pairs(T) do if type(t)=='table' and next(t) then local ks={} "
           "for k in pairs(rawget(t,'modules') or {}) do ks[#ks+1]=k end table.sort(ks) "
           "print(name..'='..table.concat(ks,' ')) end end")
    run = subprocess.run(['lua5.4', '-e', lua], cwd=root, capture_output=True, text=True)
    if run.returncode: out.append(f'R9 {SCRIPTS}/ui/text.lua:1: does not load: {run.stderr.strip()}')
    text = (base / 'ui/text.lua').read_text(encoding='utf-8')
    for row in run.stdout.split('\n'):
        if not row: continue
        culture, keys = row.split('=', 1)
        if keys.split() != sorted(mods):
            m = re.search(r"(?m)^T(?:\." + re.escape(culture) + r"|\['" + re.escape(culture) + r"'\])=", text)
            missing, extra = sorted(set(mods) - set(keys.split())), sorted(set(keys.split()) - set(mods))
            out.append(f'R9 {SCRIPTS}/ui/text.lua:{line_of(text, m.start()) if m else 1}: T.{culture}.modules lacks '
                       f'{" ".join(missing) or "nothing"}, has extra {" ".join(extra) or "nothing"}')


INC = re.compile(r'#include "([^"]+)"')
NAMESPACE = re.compile(r'\bnamespace\s+([\w:]+)\s*\{')
QUALIFIED = re.compile(r'(?<![\w:])(?:\w+::)*(\w+)::([A-Za-z_]\w*)')
NOT_TYPES = {'return', 'case', 'else', 'new', 'delete', 'throw', 'sizeof', 'typename', 'goto', 'do', 'not', 'and', 'or'}
NS_OPEN = re.compile(r'^namespace (coop::pose )?\{\s*(//.*)?$')
LOCAL = r'(?:\b(?:auto|int|bool|char|float|double|size_t|uint\d+_t|int\d+_t|uintptr_t|std::[\w:<>]+|[A-Z]\w*)[\s*&]+)'


def declared(code):
    """Names a header declares (types, aliases, functions, variables and constants), by their declaration's form."""
    names = set(re.findall(r'\b(?:struct|class|union|enum(?:\s+class)?)\s+([A-Za-z_]\w*)', code))
    names |= set(re.findall(r'\busing\s+([A-Za-z_]\w*)\s*=', code))
    for m in re.finditer(r'([\w>*&\]])\s+([A-Za-z_]\w*)\s*(?:=(?!=)|\{|\(|\[|;)', code):
        before = re.search(r'(\w+)\s*$', code[max(0, m.start(2) - 200):m.start(2)])
        if before and before.group(1) in NOT_TYPES or code[m.start(1) - 1:m.start(1) + 1] == '&&': continue
        names.add(m.group(2))
    last, stmts = -1, []  # Each run between ; { } that ends in ;
    for m in re.finditer(r'[;{}]', code):
        if m.group() == ';': stmts.append(code[last + 1:m.end()])
        last = m.start()
    for stmt in stmts:  # The later names of a list: constexpr uint64_t kA = 1, kB = 2;
        depth, start, parts = 0, 0, []
        for i, ch in enumerate(stmt):
            if ch in '([<': depth += 1
            elif ch in ')]>': depth -= 1
            elif ch == ',' and depth == 0:
                parts.append(stmt[start:i])
                start = i + 1
        parts.append(stmt[start:])
        for part in parts[1:]:
            m = re.match(r'\s*([A-Za-z_]\w*)\s*(?:=(?!=)|\[)', part)
            if m: names.add(m.group(1))
    return names


def top_names(code):
    """The names one top-level item of a part defines."""
    c = re.sub(r'__declspec\([^)]*\)|alignas\([^)]*\)|\[\[[^\]]*\]\]', ' ', code)
    head = re.sub(r'template\s*<[^{;]*?>\s*(?=[A-Za-z_])', ' ', c).strip()
    if head.startswith('static_assert'): return set()
    m = re.match(r'(?:typedef\s+)?(?:struct|class|union|enum(?:\s+class)?)\s+([A-Za-z_]\w*)', head) or \
        re.match(r'using\s+([A-Za-z_]\w*)\s*=', head)
    if m: return {m.group(1)}
    cut, par = re.search(r'[{=;]', head), head.find('(')
    if par >= 0 and (not cut or par < cut.start()):  # A function (or a function-pointer variable).
        m = re.search(r'([A-Za-z_]\w*)\s*$', head[:par])
        fp = re.match(r'[^(]*\(\s*\*\s*([A-Za-z_]\w*)\s*\)', head)
        return {fp.group(1)} if fp else ({m.group(1)} if m else set())
    out, d, start, parts = set(), 0, 0, []  # Variables: each declarator of the list.
    for i, ch in enumerate(head):
        if ch in '({[<': d += 1
        elif ch in ')}]>': d -= 1
        elif ch == ',' and d == 0:
            parts.append(head[start:i])
            start = i + 1
        elif ch == ';' and d == 0:
            parts.append(head[start:i])
            break
    for p in parts:
        m = re.match(r'\s*(?:[^={\[]*?[\s*&])?([A-Za-z_]\w*)\s*(?:\[[^\]]*\])?\s*(?:=|\{|$)', p.strip() + ' ')
        if m: out.add(m.group(1))
    return out


def part_names(raw):
    """The names a part defines at its top level, inside its namespaces (coop::pose and the anonymous one)."""
    code = strip_c(raw)
    names, depth, item = set(), 0, []
    for line in code.splitlines():
        s = line.strip()
        if depth == 0 and not item and (NS_OPEN.match(s) or s.startswith('}') and not s.strip('}; ') or not s
                                        or s.startswith('#')):
            continue
        item.append(line)
        for ch in line:
            if ch == '{': depth += 1
            elif ch == '}': depth -= 1
        if depth == 0 and (s.endswith(';') or s.endswith('}')):
            names |= top_names('\n'.join(item))
            item = []
    return names


def reads(code, name):
    if not re.search(r'(?<![\w.>:])' + re.escape(name) + r'\b', code): return False
    return not re.search(LOCAL + re.escape(name) + r'\s*(?:[=;,)({\[]|:)', code)  # Its own of that name.


def check_native(root, out):
    files = []
    for p in sorted((root / SRC).rglob('*')):
        if p.suffix in ('.h', '.inc', '.cpp'): files.append((p, str(p.relative_to(root / SRC))))
    for p in sorted((root / 'tests/native').rglob('*.cpp')):
        files.append((p, str(p.relative_to(root / 'tests/native'))))
    folders = {r.split('/')[0] for p, r in files if p.is_relative_to(root / SRC) and '/' in r} - SHARED_NATIVE
    heads, spaces = {}, set()
    for p, rel in files:
        if p.suffix != '.h' or not p.is_relative_to(root / SRC): continue
        code = strip_c(p.read_text(encoding='utf-8'))
        last = set()
        for m in NAMESPACE.finditer(code):
            parts = m.group(1).split('::')
            spaces.update(parts)
            last.add(parts[-1])
        heads[rel] = (last, declared(code))
    for p, rel in files:
        mine, name = rel.split('/')[0], str(p.relative_to(root))
        if mine == 'glue' and p.is_relative_to(root / SRC) or name.startswith(NATIVE_TESTS_READING): continue
        raw = p.read_text(encoding='utf-8')
        code = strip_c(raw)
        for m in INC.finditer(raw):
            d = m.group(1).split('/')[0]
            if d in folders and d != mine and '/' in m.group(1):
                out.append(f'R8 {name}:{line_of(raw, m.start())}: includes {m.group(1)} of module folder {d}')
        for m in QUALIFIED.finditer(code):
            space, what = m.groups()
            if space in ('std', 'coop') or what in spaces: continue
            found = [h for h, (last, names) in heads.items() if space in last and what in names]
            if found and not any(h.split('/')[0] == mine or h.split('/')[0] in SHARED_NATIVE for h in found):
                out.append(f'R8 {name}:{line_of(code, m.start())}: reads {space}::{what} of {found[0]}')
    tick = (root / SRC / 'glue/tick.cpp').read_text(encoding='utf-8')
    order = [p for p in re.findall(r'^#include "([^"]+\.inc)"', tick, re.M) if p.split('/')[0] in folders]
    parts = {p: strip_c((root / SRC / p).read_text(encoding='utf-8')) for p in order}
    defined = {p: part_names((root / SRC / p).read_text(encoding='utf-8')) for p in order}
    tokens = {p: set(re.findall(r'[A-Za-z_]\w*', c)) for p, c in parts.items()}
    for q in order:
        for p in order:
            if p.split('/')[0] == q.split('/')[0]: continue
            for n in sorted(defined[p] & tokens[q] - defined[q]):
                if reads(parts[q], n):
                    pos = re.search(r'(?<![\w.>:])' + re.escape(n) + r'\b', parts[q]).start()
                    out.append(f'R8 {SRC}/{q}:{line_of(parts[q], pos)}: uses {n} of {p}')


def scan(root):
    out = []
    check_lua(Path(root), out)
    check_native(Path(root), out)
    return out


def scan_of(files):
    with tempfile.TemporaryDirectory() as tmp:
        for rel, text in files.items():
            if text is None: continue
            path = Path(tmp, rel)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding='utf-8')
        return scan(Path(tmp))


S = SCRIPTS
def wiring(uses, exports, body='', build=''):
    return (f"return {{\nuses={{{','.join(repr(u) for u in uses)}}},\nexports={{{','.join(repr(x) for x in exports)}}},"
            f"\nnew=function(M)\nlocal print,log=M.print,M.log\n{body}end,\n{build}}}\n")
ALPHA = wiring([], ['alpha', 'alpha_hud'], "M.alpha=require('alpha.core').new()\n",
               "build={\nhud=function(M,Ui)\n    M.alpha_hud={}\nend,\n},\n")
BETA = wiring(['alpha'], ['beta'], "M.beta={f=function() return M.alpha.f() end}\n"
              "local hooked=pcall(RegisterHook,'/Script/X:Y',function()\n"
              "    if M.off_modules.beta then return end\nend)\n")
TEXT = ("local T={}\nT.en={\n    modules={alpha='Alpha',beta='Beta'},\n}\n"
        "T.fr={\n    modules={alpha='A',beta='B'},\n}\nT.de={}\nfunction T.pick() return T.en end\nreturn T\n")
TICK = '#include "alpha/alpha_game.inc"\n#include "beta/beta_game.inc"\n'
CLEAN = {
    f'{S}/main.lua': "local M={}\nlocal MODULES={'alpha','beta'}\nrequire('main.loader').run(M,MODULES)\n",
    f'{S}/main/base.lua': 'return function(M)\nM.riding=function() end\nend\n',
    f'{S}/main/ui.lua': "return function(M)\nrequire('main.loader').build(M,'alpha','hud',Ui)\nend\n",
    f'{S}/core/line.lua': 'return {}\n',
    f'{S}/ui/text.lua': TEXT,
    f'{S}/alpha/wiring.lua': ALPHA, f'{S}/alpha/core.lua': "local U=require('core.line')\nreturn {}\n",
    f'{S}/beta/wiring.lua': BETA, f'{S}/beta/run.lua': 'return {}\n',
    'tests/lua/alpha/off_test.lua': "dofile('tests/lua/main/isolation.lua')('alpha')\n",
    'tests/lua/beta/off_test.lua': "dofile('tests/lua/main/isolation.lua')('beta')\n",
    'tests/lua/beta/run_test.lua': "package.loaded['core.line']={}\nlocal R=require('beta.run')\n",
    'tests/lua/main/fixture.lua': "package.loaded['alpha.core']={}\n",
    f'{SRC}/glue/tick.cpp': TICK,
    f'{SRC}/game/memory.h': '#pragma once\nnamespace coop::game { inline int kShared = 1; }\n',
    f'{SRC}/alpha/alpha.h': '#pragma once\nnamespace coop::alpha { constexpr int kAlphaOnly = 3; }\n',
    f'{SRC}/alpha/alpha_game.inc': 'namespace coop::pose {\nint alpha_count = 0;\n'
                                   'void alpha_tick() { alpha_count++; }\n} // namespace coop::pose\n',
    f'{SRC}/beta/beta_game.inc': 'namespace coop::pose {\nvoid beta_tick() { int alpha_count = game::kShared; }\n'
                                 '} // namespace coop::pose\n',
    'tests/native/beta/beta_test.cpp': '#include "game/memory.h"\nint main() { return 0; }\n',
}
assert scan_of(CLEAN) == [], scan_of(CLEAN)
B = f'{S}/beta/wiring.lua'
PLANTS = [
    ({'R2'}, {B: BETA.replace("uses={'alpha'}", "needs={'alpha'},\nuses={'alpha'}")}),
    ({'R3'}, {f'{S}/beta/run.lua': "local A=require('alpha.core')\nreturn {}\n"}),
    ({'R3'}, {'tests/lua/beta/run_test.lua': "local A=require('alpha.core')\n"}),
    ({'R3'}, {'tests/lua/beta/run_test.lua': "package.loaded['alpha.core']={new=function() end}\n"}),
    ({'R3'}, {'tests/lua/beta/run_test.lua': "require('alpha.core').new=function() end\n"}),
    ({'R3'}, {'tests/lua/beta/run_test.lua': "dofile('mod/StellarCoop/Scripts/alpha/core.lua')\n"}),
    ({'R3'}, {f'{S}/core/line.lua': "local A=require('alpha.core')\nreturn {}\n"}),
    ({'R3'}, {'tests/lua/core/line_test.lua': "package.preload['beta.run']=function() end\n"}),
    ({'R4'}, {B: BETA.replace("uses={'alpha'}", 'uses={}')}),
    ({'R4'}, {B: BETA.replace("uses={'alpha'}", "uses={'alpha','gamma'}")}),
    ({'R4'}, {f'{S}/alpha/wiring.lua': ALPHA.replace('local print', "local b=require('main.loader').view(M,'beta')\n"
                                                      'local print')}),
    ({'R4'}, {f'{S}/alpha/wiring.lua': ALPHA.replace('local print', "local b=require('main.loader').get(M,'beta',"
                                                      "'beta')\nlocal print")}),
    ({'R5'}, {B: BETA.replace("exports={'beta'}", "exports={'beta','alpha_hud'}")}),
    ({'R5'}, {B: BETA.replace("exports={'beta'}", "exports={'beta','riding'}")}),
    ({'R5'}, {B: BETA.replace('M.beta={', 'M.gamma=1\nM.beta={')}),
    ({'R6'}, {f'{S}/main/ui.lua': "return function(M)\nrequire('main.loader').build(M,'alpha','hud',Ui)\n"
                                  "require('main.loader').build(M,'alpha','hud',Ui)\nend\n"}),
    ({'R6'}, {f'{S}/main/ui.lua': "return function(M)\nrequire('main.loader').build(M,'beta','hud',Ui)\nend\n"}),
    ({'R7'}, {B: BETA.replace('    if M.off_modules.beta then return end\n', '')}),
    ({'R7'}, {B: BETA.replace('M.off_modules.beta', 'M.off_modules.alpha')}),
    ({'R1'}, {'tests/lua/beta/off_test.lua': None}),
    ({'R1'}, {f'{S}/main.lua': "local MODULES={'alpha'}\n"}),
    ({'R9'}, {f'{S}/ui/text.lua': TEXT.replace("modules={alpha='A',beta='B'}", "modules={alpha='A'}")}),
    ({'R8'}, {f'{SRC}/beta/beta_game.inc': 'namespace coop::pose {\nvoid beta_tick() { alpha_count = 2; }\n'
                                           '} // namespace coop::pose\n'}),
    ({'R8'}, {f'{SRC}/beta/beta_game.inc': 'namespace coop::pose {\nint beta_v() { return alpha::kAlphaOnly; }\n'
                                           '} // namespace coop::pose\n'}),
    ({'R8'}, {'tests/native/beta/beta_test.cpp': '#include "alpha/alpha.h"\nint main() { return 0; }\n'}),
    ({'R8'}, {f'{SRC}/game/memory.h': '#pragma once\n#include "alpha/alpha.h"\n'}),
]
for tags, change in PLANTS:
    got = scan_of({**CLEAN, **change})
    assert {v.split()[0] for v in got} == tags, (tags, change, got)

found = scan(ROOT)
assert found == [], '\n'.join(found)
print('modules_test: ok')
