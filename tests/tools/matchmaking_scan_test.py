#!/usr/bin/env python3
"""No script or native source of the mod can reach Stellar Blade's matchmaking. The cut recruiter's Join fires zone
event MultiplayTest_ZoneE_059 (type 15) -> RunEvent_StartMatchMaking -> RequestMatchRequest, an HTTP client to Shift
Up's stage servers; types 16 and 19 sit on the same path. A text scan: scan(root) lists the violations. It first runs
on planted trees, one violation each, so no rule passes vacuously, then on this repository, which must be clean.
Run: python3 tests/tools/matchmaking_scan_test.py"""
import re
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = 'mod/StellarCoop/Scripts'
NATIVE = ('native/src', 'tests/wine')
# The one guarded CreateSBZoneEvent per file that has one, and what each file may hold of the rationed calls and names.
SITES = {'nightop/probe.lua', 'nightop/recruiter.lua'}
ADD_ROWS = {'nightop/probe.lua': 1}
# Raw counts, comments and strings included, so a call no pattern below sees (obj['AddRow'](obj,...)) still shows. A
# new mention, even in a log line, is a deliberate edit here. ServerRequest_*: coop no's ChangeRule and CreateActor,
# coop nightop's one CreateActor (its spawn choke point), its shop's one ItemBucketItemAdd (its grant choke point), and
# the friend's revive's ActorRespawn and ActorRevival on our own EVE (one call each, their log lines, the probe's
# answer and the header).
# The Join row: coop recruiter's constant only, which it reads and neutralizes, never fires.
RATIONED = {'MultiplayTest_ZoneE_059': {'nightop/recruiter.lua': 1},
            'CreateSBZoneEvent': {'nightop/probe.lua': 3, 'nightop/recruiter.lua': 4},
            'AddRow': {'nightop/probe.lua': 3},
            'ServerRequest_': {'nightop/probe.lua': 10, 'nightop/run.lua': 1, 'nightop/shop.lua': 1,
                               'session/group.lua': 7}}

# Calls are matched with every string literal turned into '', so log prose such as 'heal: CreateSBZoneEvent(2, ...)' is
# not one. Lua allows space after the ':' and a string or table argument without '(': obj: f(x), obj:f'x', obj:f{}.
STRINGS = re.compile(r"'(?:\\.|[^'\\\n])*'" r'|"(?:\\.|[^"\\\n])*"')
SITE = re.compile(r"[:.]\s*CreateSBZoneEvent\s*[('{]")
HEADER = 'local function zone_event(kind,name)'
GUARD = re.compile(r"assert\(\w+\.allowed\(kind,name\),'zone event refused'\)")
FIRE = "U.find('/Script/SB.Default__SBBlueprintLibrary'):CreateSBZoneEvent(kind,find_name(name))"  # The whole line.
# Zone events run directly (bypassing CreateSBZoneEvent's guard), table wipes, the console, anything matchmaking.
CALL = re.compile(r'[:.]\s*(RunZoneEvent|NotifyClientRunEvent|EnterZone|ServerRequest_EnterZone|RemoveRow|EmptyTable|'
                  r"SetRemainTime|ExecuteConsoleCommand|\w*RunEvent\w*|\w*[Mm]atch[Mm]ak\w*)\s*[('{]")
# The one console call: main.lua's photo pause sets SB.PhotoMode.PauseMethod (a constant assigned once) to 0 or 1.
PAUSE = "local PAUSE_METHOD='SB.PhotoMode.PauseMethod'"
CONSOLE = "library:ExecuteConsoleCommand(pc,PAUSE_METHOD..' '..want,pc)"  # The whole line.
NAMES = ('Develop_NetworkPlay', 'DED10_ZoneE_13')  # The network-play option and the vanilla matchmaking rows.
ADD_ROW = re.compile(r"[:.]\s*AddRow\s*[('{]")
# StartMatchMaking, RequestMatchRequest, RunEvent, RunZoneEvent and the CreateSBZoneEvent job, as image offsets.
ADDRESSES = re.compile('1ca2c50|23058c0|1ca47c0|1ca4540|1abcb40', re.I)
NATIVE_NAMES = re.compile('MatchMaking|RequestMatch')  # Case-sensitive: Steam's Matchmaking lobby API stays allowed.


def scan(root):
    """Every violation under root, as '<rule> <file>[:<line>]: <what>'."""
    out = []
    sites, adds, counts = set(), {}, {word: {} for word in RATIONED}
    for path in sorted((root / SCRIPTS).rglob('*.lua')):
        name, text = path.relative_to(root / SCRIPTS).as_posix(), path.read_text(encoding='utf-8')
        lines, code = text.splitlines(), STRINGS.sub("''", text)  # Same lines: no literal spans a newline.

        def at(m): return '%s:%d' % (name, code.count('\n', 0, m.start()) + 1)

        found = list(SITE.finditer(code))
        if found: sites.add(name)
        if len(found) > 1: out.append(f'L1 {name}: {len(found)} CreateSBZoneEvent calls, at most one per file')
        for m in found:
            row = code.count('\n', 0, m.start())
            before = [line.strip() for line in lines[:row] if line.strip()]
            if (len(before) < 2 or not GUARD.fullmatch(before[-1]) or before[-2] != HEADER
                    or lines[row].strip() != FIRE):
                out.append(f'L1 {at(m)}: CreateSBZoneEvent is not the guarded call of zone_event(kind,name)')
        allow = (name == 'main.lua' and [line.strip() for line in lines].count(PAUSE) == 1
                 and len(re.findall(r'\bPAUSE_METHOD\s*=(?!=)', code)) == 1)
        for m in CALL.finditer(code):
            if allow and lines[code.count('\n', 0, m.start())].strip() == CONSOLE: allow = False  # The first one only.
            else: out.append(f'L2 {at(m)}: {m.group(1)} call')
        out += [f'L3 {name}: {word}' for word in NAMES if word in text]
        adds[name] = len(ADD_ROW.findall(code))
        for word in RATIONED: counts[word][name] = text.count(word)
    if sites != SITES: out.append(f'L1 {SCRIPTS}: CreateSBZoneEvent in {sorted(sites)}, expected {sorted(SITES)}')
    for rule, got, expected, what in [('L4', adds, ADD_ROWS, 'AddRow calls')] + [
            ('L5', counts[word], RATIONED[word], word) for word in RATIONED]:
        for name in sorted(set(got) | set(expected)):
            if got.get(name, 0) != expected.get(name, 0):
                out.append(f'{rule} {name}: {got.get(name, 0)} {what}, expected {expected.get(name, 0)}')
    for folder in NATIVE:
        files = sorted(p for p in (root / folder).rglob('*') if p.is_file())
        if not files: out.append(f'N0 {folder}: no file to scan')
        for path in files:
            text, rel = path.read_bytes().decode('utf-8', 'replace'), path.relative_to(root)
            out += [f'N1 {rel}: {m.group(0)}' for m in ADDRESSES.finditer(text)]
            out += [f'N2 {rel}: {m.group(0)}' for m in NATIVE_NAMES.finditer(text)]
    return out


def scan_of(files):
    with tempfile.TemporaryDirectory() as tmp:
        for rel, text in files.items():
            if text is None: continue
            path = Path(tmp, rel)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        return scan(Path(tmp))


N, M, H, W = f'{SCRIPTS}/nightop/probe.lua', f'{SCRIPTS}/main.lua', 'native/src/link/core.h', 'tests/wine/smoke.cpp'
R, NR, GR = f'{SCRIPTS}/nightop/recruiter.lua', f'{SCRIPTS}/nightop/run.lua', f'{SCRIPTS}/session/group.lua'
NS = f'{SCRIPTS}/nightop/shop.lua'
GUARDED = ("local function zone_event(kind,name)\n\n    assert(NightOp.allowed(kind,name),'zone event refused')\n    "
           + FIRE + '\nend\n')


def padded(name, text):  # The rest of a file's rationed counts, as comments.
    return text + ''.join(f'-- {w}\n' * (n.get(name, 0) - text.count(w)) for w, n in RATIONED.items())


NIGHTOP = padded('nightop/probe.lua', GUARDED + "dt:AddRow(RULE,row)\npc:ServerRequest_MultiPlayChangeRule(name)\n"
                 "log('heal: CreateSBZoneEvent(2, x) called; no RemoveRow, EnterZone or AddRow here')\n")
RECRUITER = padded('nightop/recruiter.lua',
                   GUARDED.replace('NightOp', 'Recruiter') + "local JOIN='MultiplayTest_ZoneE_059'\n")
RUN = padded('nightop/run.lua', "pc:ServerRequest_CreateActor(id,at,rot,false,true,0,key,key&0xFF,n,false)\n")
GROUP = padded('session/group.lua',
               'pc:ServerRequest_ActorRespawn(me,false)\npc:ServerRequest_ActorRevival(me,false)\n')
SHOP = padded('nightop/shop.lua',
              "pc:ServerRequest_ItemBucketItemAdd(1,guid,FName(alias),count,0,true,false,false,{})\n")
CLEAN = {N: NIGHTOP, R: RECRUITER, NR: RUN, GR: GROUP, NS: SHOP,
         M: 'local coop=1 -- Steam lobby, friends matchmaking later\n',
         H: 'get(api.create_lobby, "SteamAPI_ISteamMatchmaking_CreateLobby");\n', W: 'int main() { return 0; }\n'}
assert scan_of(CLEAN) == [], scan_of(CLEAN)  # A blank line in zone_event and Steam's Matchmaking are fine.
PHOTO = f'{PAUSE}\n    {CONSOLE}\n'
assert scan_of({**CLEAN, M: PHOTO}) == [], scan_of({**CLEAN, M: PHOTO})

calls = ['x:RunZoneEvent(1)', 'x.NotifyClientRunEvent(1)', 'x:EnterZone(1)', 'x:RemoveRow(n)', 'x . EmptyTable ()',
         'x:\n  SetRemainTime\n(0)', "x:ExecuteConsoleCommand('a')", 'w:RunEvent_StartMatchMaking()',
         'w:K2_RunEventNow()', 'm:RequestMatchmaking()', 'm:GetMatchMakingManager()', 'm:matchmake()',
         'x:EmptyTable{}', "x:RemoveRow'n'", 'x:RemoveRow"it\'s"', "log('it\\'s') x:EmptyTable('t')"]
PLANTS = [({'L1'}, {N: NIGHTOP.replace("    assert(NightOp.allowed(kind,name),'zone event refused')\n", '')}),
          ({'L1'}, {N: NIGHTOP.replace("    assert(NightOp", "    -- assert(NightOp")}),
          ({'L1'}, {N: NIGHTOP.replace("'zone event refused'", "'zone event blocked'")}),
          ({'L1'}, {N: NIGHTOP.replace('NightOp.allowed(kind,name)', 'NightOp.allowed(15,name)')}),
          ({'L1'}, {N: NIGHTOP.replace(HEADER, 'local function fire(kind,name)')}),
          ({'L1'}, {N: NIGHTOP.replace(HEADER, '-- ' + HEADER)}),
          ({'L1'}, {N: NIGHTOP.replace('    U.find', '    kind=15\n    U.find')}),
          ({'L1'}, {N: NIGHTOP.replace('    U.find', '    kind=15 U.find')}),
          ({'L1'}, {N: NIGHTOP.replace('CreateSBZoneEvent(kind,', 'CreateSBZoneEvent(15,')}),
          ({'L1'}, {N: NIGHTOP.replace('CreateSBZoneEvent(kind,', 'CreateSBZoneEvent(kind+13,')}),
          # A rationed name in a comment turned into a call keeps the raw counts: only the call patterns see it.
          ({'L1'}, {N: NIGHTOP.replace('-- CreateSBZoneEvent\n', 'bpl: CreateSBZoneEvent (15,n)\n')}),
          ({'L1'}, {N: NIGHTOP.replace('-- CreateSBZoneEvent\n', "bpl:CreateSBZoneEvent{15,n}\n")}),
          ({'L1', 'L5'}, {N: NIGHTOP.replace(FIRE, FIRE + ' x:CreateSBZoneEvent(kind,y)')}),
          ({'L1', 'L5'}, {N: NIGHTOP + GUARDED}),
          ({'L1', 'L5'}, {N: NIGHTOP.replace(GUARDED, '')}),
          ({'L1', 'L5'}, {M: GUARDED}),
          ({'L1', 'L5'}, {R: RECRUITER.replace(GUARDED.replace('NightOp', 'Recruiter'), '')}),
          ({'L1', 'L5'}, {R: None}),
          ({'L1'}, {R: RECRUITER.replace('Recruiter.allowed(kind,name)', 'Recruiter.allowed(15,name)')}),
          ({'L1', 'L5'}, {M: 'bpl.CreateSBZoneEvent(bpl,15,n)\n'}),
          ({'L1', 'L5'}, {M: 'bpl: CreateSBZoneEvent(15,n)\n'}),
          *[({'L2'}, {M: f'{call}\n'}) for call in calls],
          ({'L2', 'L5'}, {N: NIGHTOP + 'pc:ServerRequest_EnterZone(1)\n'}),
          ({'L2', 'L5'}, {M: 'pc:ServerRequest_EnterZone(1)\n'}),
          ({'L2'}, {M: PHOTO + CONSOLE + '\n'}),
          ({'L2'}, {M: PHOTO.replace('PauseMethod', 'Pause')}),
          ({'L2'}, {M: PHOTO + "PAUSE_METHOD='open x'\n"}),
          ({'L2'}, {M: PAUSE + '\n' + CONSOLE.replace("' '", "' 1;'") + '\n'}),
          ({'L2'}, {M: 'local x=1\n', N: NIGHTOP + PHOTO}),
          ({'L3'}, {M: '-- Develop_NetworkPlay\n'}),
          *[({'L3'}, {N: NIGHTOP + f"local row='DED10_ZoneE_13{i}'\n"}) for i in (6, 7, 8)],
          ({'L4'}, {N: NIGHTOP.replace('-- AddRow\n', 'dt: AddRow (B,row)\n')}),
          ({'L4'}, {N: NIGHTOP.replace('-- AddRow\n', "dt:AddRow'B'\n")}),
          ({'L4', 'L5'}, {N: NIGHTOP + 'dt:AddRow(B,row)\n'}),
          ({'L4', 'L5'}, {N: NIGHTOP.replace('dt:AddRow(RULE,row)\n', '')}),
          ({'L4', 'L5'}, {M: 't.AddRow(t,n,row)\n'}),
          ({'L5'}, {M: "local JOIN='MultiplayTest_ZoneE_059'\n"}),
          ({'L5'}, {R: RECRUITER + "log('join row: MultiplayTest_ZoneE_059')\n"}),
          ({'L5'}, {R: RECRUITER.replace("local JOIN='MultiplayTest_ZoneE_059'\n", '')}),
          ({'L5'}, {M: "bpl['CreateSBZoneEvent'](bpl,15,n)\n"}),
          ({'L5'}, {M: "dt['AddRow'](dt,n,row)\n"}),
          ({'L5'}, {M: 'pc: ServerRequest_CreateActor (pc,1)\n'}),
          ({'L5'}, {N: NIGHTOP + '-- ServerRequest_\n'}),
          ({'L5'}, {NR: RUN + 'pc:ServerRequest_CreateActor(id,at,rot,false,true,0,0,0,n,false)\n'}),
          ({'L5'}, {NR: None}),
          ({'L5'}, {GR: GROUP + 'pc:ServerRequest_ActorRevival(me,true)\n'}),
          ({'L5'}, {GR: None}),
          ({'L5'}, {NS: SHOP + "log('no ServerRequest_ItemBucketItemRemove here')\n"}),
          ({'L5'}, {NS: None}),
          *[({'N1'}, {H: f'// {a}\n'}) for a in ('0x141ca2c50', '0x1423058C0', 'FUN_141CA47C0', '1ca4540', '1aBcb40')],
          ({'N1'}, {W: 'auto job = 0x141abcb40;\n'}),
          ({'N2'}, {H: 'void StartMatchMaking();\n'}),
          ({'N2'}, {W: '// RequestMatchRequest\n'}),
          ({'N0'}, {H: None}),
          ({'N0'}, {W: None})]
for tags, change in PLANTS:
    got = scan_of({**CLEAN, **change})
    assert {v.split()[0] for v in got} == tags, (tags, change, got)

assert scan(ROOT) == [], scan(ROOT)
print('matchmaking_scan_test: ok')
