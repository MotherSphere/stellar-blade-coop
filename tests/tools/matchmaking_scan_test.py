#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""No script or native source of the mod can reach Stellar Blade's matchmaking. The cut recruiter's Join fires zone
event MultiplayTest_ZoneE_059 (type 15) -> RunEvent_StartMatchMaking -> RequestMatchRequest, an HTTP client to Shift
Up's stage servers; types 16 and 19 sit on the same path. Native code calls RunZoneEvent at two sites, with its address
held once in game/sbo.h: sbo_game.inc, for coop sbo seq's four PlayLevelSeq rows, with the native part's own FNames, and
world_game_shared.inc. That one serves the shared world's env control rows, which game/objects/engine.h checks against
game/objects/rows.h's list (kind 10 rows whose chains are kind 10) right before the call. It also serves story
together's scene starts and trips (game/story/engine.h), whose rows are on game/story/rows.h's lists (scene_row(),
trip_sent()). A text scan: scan(root) lists the violations. It first runs on planted trees, one violation each, so no
rule passes vacuously, then on this repository, which must be clean.
Run: python3 tests/tools/matchmaking_scan_test.py"""
import re
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = 'mod/StellarCoop/Scripts'
NATIVE = ('native/src', 'tests/wine')
# The one guarded CreateSBZoneEvent per file that has one, and what each file may hold of the rationed calls and names.
SITES = {'story/scenes/scene.lua', 'world/maps/matrix13/level/boss.lua', 'online/modes/nightop/probe.lua',
         'online/modes/nightop/recruiter.lua', 'fight/gunmode/mode.lua', 'online/modes/scoreattack/run.lua'}
ADD_ROWS = {'online/modes/nightop/probe.lua': 1}
# Raw counts, comments and strings included, so a call no pattern below sees (obj['AddRow'](obj,...)) still shows. A
# new mention, even in a log line, is a deliberate edit here. ServerRequest_*: coop no's ChangeRule and CreateActor,
# coop nightop's one CreateActor (its spawn choke point), the shop's one ItemBucketItemAdd (its grant choke point, in
# core/items.lua) and the Beta Seeds' ItemBucketItemAdd and ItemBucketItemRemove (the shop screen's one seed choke
# point), and the friend's revive's ActorRespawn and ActorRevival on our own EVE (one call each, their log lines, the
# probe's answer and the header). coop lion, coop gardener fight and coop tendril fight: fight/bosses/enemy.lua's one
# CreateActor (their spawn choke point) and its header, which also names SB's AddRow (the native part calls it) and
# UE4SS's (never called); core/enemy.lua, which the row batches keep, holds the same lines.
# fight/bosses/lion.lua's header names SB's AddRow. coop scene: its guarded call (kind 6, its two
# theater rows only), its header, its three log lines and one refusal. coop mxiii boss: its guarded call (kind 10, the
# Lion's three lever rows only, on the fallback Lion's death) and its header. coop chainspin: its header. The one Cheat
# request (SBApplyEffectMe on our EVE, its choke point, in core/effect.lua) applies the ChainSpin's effect or one of
# coop devmenu's fixed list of 23 in cutmenus/devmenu.lua, which only reaches it through ChainSpin.apply. coop gift:
# its one ItemBucketItemRemove (a send's choke point; its grants go through core/items.lua's) and its header. The
# bike's paid fetch: its one ItemBucketItemRemove (BetaCrystal, its price only). Gun mode's rounds
# (fight/gunmode/nikke.lua): its one ItemBucketItemRemove of Bullet_Nikke, once a reload and at most a magazine, only
# while its rows are in and the slot line reads slot=coop, and its header. On 26123051 that remove (0x1423bfa00 ->
# 0x141afa620) queues its packet on SB's local logic queue and sends it (0x1423b8700) only in the UE client net mode
# (3), never to a Shift Up endpoint.
# The Join row: coop recruiter's constant only, which it reads and neutralizes, never fires. Gun mode: its guarded call
# (each shot's kind 2, ZoneEvent_AttachActorEffect, on its EventActorEffectTable row only). On 26123051 RunEvent
# (0x141ca5a10) hands kind 2 to 0x141c9e690, from which no chain of direct calls reaches RunEvent, RunZoneEvent or
# StartMatchMaking. gun_probe's bullet test (a dev setting, off unless set): ServerRequest_ChangeBulletItem once in its
# list of names, then twice as a call with its log label. That request is SB's server RPC (exec 0x14275f350): on a
# standalone game its implementation (0x1423c0180 -> 0x141b02890) queues SB's local server job, which reaches no
# host (only a client net mode sends it, 0x1423b8700). The job (0x141b15b90 -> 0x141a8da30) sets the drone's current
# round in EVE's character data and on her pawn. SB's own round switch (0x141a8d9c0) sends the same request. Whether a
# save keeps that round was not traced, so the probe stays behind its setting.
# Score attack (online/modes/scoreattack/run.lua, a copy of Night Operation's run with its heal and group play's
# respawn): its guarded call (kind 2, the heal row SE_10_E_ActorEff_011 only) and its header; its one CreateActor
# (its spawn choke point), its one ActorRespawn on our own EVE after a death, that call's log line and the header's two
# mentions. On 26123051 CreateActor (0x1423bdd20) queues its job on SB's local logic queue (0x141af4b70) and sends it
# only in the UE client net mode 3; RunEvent hands kind 2 to 0x141c9e690 (its call at 0x141ca627d); the respawn's job
# (0x141b10b30) finds EVE by her GUID and refills her recovery items, reading no zone type.
RATIONED = {'MultiplayTest_ZoneE_059': {'online/modes/nightop/recruiter.lua': 1},
            'CreateSBZoneEvent': {'online/modes/nightop/probe.lua': 3, 'online/modes/nightop/recruiter.lua': 4,
                                  'story/scenes/scene.lua': 6,
                                  'world/maps/matrix13/level/boss.lua': 2, 'fight/gunmode/mode.lua': 1,
                                  'online/modes/scoreattack/run.lua': 2},
            'AddRow': {'online/modes/nightop/probe.lua': 3, 'core/enemy.lua': 2, 'fight/bosses/enemy.lua': 2,
                       'fight/bosses/lion.lua': 1},
            'ServerRequest_': {'online/modes/nightop/probe.lua': 10, 'online/modes/nightop/run.lua': 1,
                               'online/modes/nightop/shop.lua': 2,
                               'core/items.lua': 1, 'online/group/group.lua': 7, 'core/enemy.lua': 2,
                               'fight/bosses/enemy.lua': 2, 'eve/chainspin.lua': 1, 'core/effect.lua': 1,
                               'cutmenus/mailbox.lua': 2, 'vehicles/bike/fetch.lua': 1,
                               'fight/gunmode/probe.lua': 5, 'fight/gunmode/nikke.lua': 2,
                               'online/modes/scoreattack/run.lua': 5}}

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
# The one console call: online/photo/wiring.lua's photo pause sets SB.PhotoMode.PauseMethod (a constant assigned once)
# to 0 or 1.
PAUSE = "local PAUSE_METHOD='SB.PhotoMode.PauseMethod'"
CONSOLE = "library:ExecuteConsoleCommand(pc,PAUSE_METHOD..' '..want,pc)"  # The whole line.
NAMES = ('Develop_NetworkPlay', 'DED10_ZoneE_13')  # The network-play option and the vanilla matchmaking rows.
ADD_ROW = re.compile(r"[:.]\s*AddRow\s*[('{]")
# StartMatchMaking, RequestMatchRequest, RunEvent, RunZoneEvent and the CreateSBZoneEvent job, as image offsets.
ADDRESSES = re.compile('1ca3ea0|230b090|1ca5a10|1ca5790|1abdd80', re.I)
NATIVE_NAMES = re.compile('MatchMaking|RequestMatch')  # Case-sensitive: Steam's Matchmaking lobby API stays allowed.
# RunZoneEvent's two sites, coop sbo seq's (L15-R3) and world_game_shared.inc's (the shared world's env rows, story
# together's scene and trip rows), raw counts with comments: its address only in game/sbo.h (N1 anywhere else), its
# constant there and at each call. The address is counted case-insensitively.
RUN_ZONE_EVENT = '1ca5790'
NATIVE_RATIONED = {RUN_ZONE_EVENT: {'native/src/game/sbo.h': 1},
                   'kRunZoneEvent': {'native/src/game/sbo.h': 1, 'native/src/online/lobby/sbo_game.inc': 1,
                                     'native/src/glue/tick/world_game_shared.inc': 1}}


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
        allow = (name == 'online/photo/wiring.lua' and [line.strip() for line in lines].count(PAUSE) == 1
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
    native = {word: {} for word in NATIVE_RATIONED}
    for folder in NATIVE:
        files = sorted(p for p in (root / folder).rglob('*') if p.is_file())
        if not files: out.append(f'N0 {folder}: no file to scan')
        for path in files:
            text, rel = path.read_bytes().decode('utf-8', 'replace'), path.relative_to(root).as_posix()
            held = rel in NATIVE_RATIONED[RUN_ZONE_EVENT]  # There N3 counts the address; N1 everywhere else.
            out += [f'N1 {rel}: {m.group(0)}' for m in ADDRESSES.finditer(text)
                    if not (held and m.group(0).lower() == RUN_ZONE_EVENT)]
            out += [f'N2 {rel}: {m.group(0)}' for m in NATIVE_NAMES.finditer(text)]
            if held: native[RUN_ZONE_EVENT][rel] = text.lower().count(RUN_ZONE_EVENT)
            native['kRunZoneEvent'][rel] = text.count('kRunZoneEvent')
    for word, expected in NATIVE_RATIONED.items():
        got = native[word]
        for name in sorted(set(got) | set(expected)):
            if got.get(name, 0) != expected.get(name, 0):
                out.append(f'N3 {name}: {got.get(name, 0)} {word}, expected {expected.get(name, 0)}')
    return out


def scan_of(files):
    with tempfile.TemporaryDirectory() as tmp:
        for rel, text in files.items():
            if text is None: continue
            path = Path(tmp, rel)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        return scan(Path(tmp))


N, M, H, W = (f'{SCRIPTS}/online/modes/nightop/probe.lua', f'{SCRIPTS}/main.lua', 'native/src/link/core.h',
              'tests/wine/smoke.cpp')
P = f'{SCRIPTS}/online/photo/wiring.lua'
R, NR, GR = (f'{SCRIPTS}/online/modes/nightop/recruiter.lua', f'{SCRIPTS}/online/modes/nightop/run.lua',
             f'{SCRIPTS}/online/group/group.lua')
NS, LI, SC = (f'{SCRIPTS}/online/modes/nightop/shop.lua', f'{SCRIPTS}/fight/bosses/lion.lua',
              f'{SCRIPTS}/story/scenes/scene.lua')
BO = f'{SCRIPTS}/world/maps/matrix13/level/boss.lua'
GM, GP = f'{SCRIPTS}/fight/gunmode/mode.lua', f'{SCRIPTS}/fight/gunmode/probe.lua'
SA = f'{SCRIPTS}/online/modes/scoreattack/run.lua'
SH, SG, WG = ('native/src/game/sbo.h', 'native/src/online/lobby/sbo_game.inc',
              'native/src/glue/tick/world_game_shared.inc')
SEQ_CONST, SEQ_CALL = ('constexpr uint64_t kRunZoneEvent = 0x141ca5790;\n',
                       'game_function<RunZoneEvent>(sbo::kRunZoneEvent)(world, id, &sbo_seq_names[k], 0);\n')
WORLD_CALL = 'game_function<RunZoneEvent>(sbo::kRunZoneEvent)(world, caster, &row, 0);\n'

CS, EN, MB = f'{SCRIPTS}/eve/chainspin.lua', f'{SCRIPTS}/core/enemy.lua', f'{SCRIPTS}/cutmenus/mailbox.lua'
BF = f'{SCRIPTS}/vehicles/bike/fetch.lua'
NK = f'{SCRIPTS}/fight/gunmode/nikke.lua'
IT, EF = f'{SCRIPTS}/core/items.lua', f'{SCRIPTS}/core/effect.lua'
GUARDED = ("local function zone_event(kind,name)\n\n    assert(NightOp.allowed(kind,name),'zone event refused')\n    "
           + FIRE + '\nend\n')


def padded(name, text):  # The rest of a file's rationed counts, as comments.
    return text + ''.join(f'-- {w}\n' * (n.get(name, 0) - text.count(w)) for w, n in RATIONED.items())


NIGHTOP = padded('online/modes/nightop/probe.lua',
                 GUARDED + "dt:AddRow(RULE,row)\npc:ServerRequest_MultiPlayChangeRule(name)\n"
                 "log('heal: CreateSBZoneEvent(2, x) called; no RemoveRow, EnterZone or AddRow here')\n")
RECRUITER = padded('online/modes/nightop/recruiter.lua',
                   GUARDED.replace('NightOp', 'Recruiter') + "local JOIN='MultiplayTest_ZoneE_059'\n")
RUN = padded('online/modes/nightop/run.lua',
             "pc:ServerRequest_CreateActor(id,at,rot,false,true,0,key,key&0xFF,n,false)\n")
GROUP = padded('online/group/group.lua',
               'pc:ServerRequest_ActorRespawn(me,false)\npc:ServerRequest_ActorRevival(me,false)\n')
SHOP = padded('online/modes/nightop/shop.lua',
              "pc:ServerRequest_ItemBucketItemAdd(1,guid,FName(alias),count,0,true,false,false,{})\n")
ENEMY = padded('core/enemy.lua', "pc:ServerRequest_CreateActor(id,at,rot,false,true,0,0,0,n,false)\n")
LION = padded('fight/bosses/lion.lua', '')
SCENE = padded('story/scenes/scene.lua', GUARDED.replace('NightOp', 'Scene'))
BOSS = padded('world/maps/matrix13/level/boss.lua', GUARDED.replace('NightOp', 'Boss'))
GUN = padded('fight/gunmode/mode.lua', GUARDED.replace('NightOp', 'GunMode'))
SCORE = padded('online/modes/scoreattack/run.lua', GUARDED.replace('NightOp', 'Run')
               + "pc:ServerRequest_CreateActor(id,at,rot,false,true,0,key,key&0xFF,n,false)\n"
               + 'pc:ServerRequest_ActorRespawn(me,false)\n')
GUN_PROBE = padded('fight/gunmode/probe.lua', "pc:ServerRequest_ChangeBulletItem(pawn,FName('Bullet_Nikke'))\n")
CHAINSPIN = padded('eve/chainspin.lua', "pc:ServerRequest_Cheat(guid,0,'SBApplyEffectMe',tostring(ChainSpin.ID))\n")
MAILBOX = padded('cutmenus/mailbox.lua', "pc:ServerRequest_ItemBucketItemRemove(1,guid,FName(alias),count,-1)\n")
FETCH = padded('vehicles/bike/fetch.lua',
               "pc:ServerRequest_ItemBucketItemRemove(1,guid,FName(Fetch.ALIAS),Fetch.PRICE,-1)\n")
NIKKE = padded('fight/gunmode/nikke.lua',
               "pc:ServerRequest_ItemBucketItemRemove(1,guid,FName(R.ROUND),n,-1)\n")
CLEAN = {N: NIGHTOP, R: RECRUITER, NR: RUN, GR: GROUP, NS: SHOP, LI: LION, EN: ENEMY, SC: SCENE, BO: BOSS, CS: CHAINSPIN,
         MB: MAILBOX, BF: FETCH, NK: NIKKE, M: 'local coop=1 -- Steam lobby, friends matchmaking later\n',
         H: 'get(api.create_lobby, "SteamAPI_ISteamMatchmaking_CreateLobby");\n', W: 'int main() { return 0; }\n',
         SH: SEQ_CONST, SG: SEQ_CALL, WG: WORLD_CALL,
         IT: padded('core/items.lua', ''), EF: padded('core/effect.lua', ''), GM: GUN, GP: GUN_PROBE, SA: SCORE}
CE = f'{SCRIPTS}/fight/bosses/enemy.lua'
CLEAN[CE] = padded('fight/bosses/enemy.lua', '')  # fight.bosses' copy of core/enemy.lua (November 2026).
assert scan_of(CLEAN) == [], scan_of(CLEAN)  # A blank line in zone_event and Steam's Matchmaking are fine.
PHOTO = f'{PAUSE}\n    {CONSOLE}\n'
assert scan_of({**CLEAN, P: PHOTO}) == [], scan_of({**CLEAN, P: PHOTO})

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
          ({'L1', 'L5'}, {SC: None}),
          ({'L1'}, {SC: SCENE.replace('Scene.allowed(kind,name)', 'Scene.allowed(6,name)')}),
          ({'L1'}, {BO: BOSS.replace('Boss.allowed(kind,name)', 'Boss.allowed(15,name)')}),
          ({'L1', 'L5'}, {BO: None}),
          ({'L1'}, {GM: GUN.replace('GunMode.allowed(kind,name)', 'GunMode.allowed(15,name)')}),
          ({'L1', 'L5'}, {GM: None}),
          ({'L1'}, {SA: SCORE.replace('Run.allowed(kind,name)', 'Run.allowed(15,name)')}),
          ({'L1', 'L5'}, {SA: None}),
          ({'L5'}, {SA: SCORE + 'pc:ServerRequest_ActorRevival(me,false)\n'}),
          ({'L1'}, {R: RECRUITER.replace('Recruiter.allowed(kind,name)', 'Recruiter.allowed(15,name)')}),
          ({'L1', 'L5'}, {M: 'bpl.CreateSBZoneEvent(bpl,15,n)\n'}),
          ({'L1', 'L5'}, {M: 'bpl: CreateSBZoneEvent(15,n)\n'}),
          *[({'L2'}, {M: f'{call}\n'}) for call in calls],
          ({'L2', 'L5'}, {N: NIGHTOP + 'pc:ServerRequest_EnterZone(1)\n'}),
          ({'L2', 'L5'}, {M: 'pc:ServerRequest_EnterZone(1)\n'}),
          ({'L2'}, {P: PHOTO + CONSOLE + '\n'}),
          ({'L2'}, {P: PHOTO.replace('PauseMethod', 'Pause')}),
          ({'L2'}, {P: PHOTO + "PAUSE_METHOD='open x'\n"}),
          ({'L2'}, {P: PAUSE + '\n' + CONSOLE.replace("' '", "' 1;'") + '\n'}),
          ({'L2'}, {M: 'local x=1\n', N: NIGHTOP + PHOTO}),
          ({'L2'}, {M: PHOTO}),
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
          ({'L5'}, {NK: NIKKE + "pc:ServerRequest_ItemBucketItemAdd(1,guid,FName(R.ROUND),n,0,true,false,false,{})\n"}),
          ({'L5'}, {GR: GROUP + 'pc:ServerRequest_ActorRevival(me,true)\n'}),
          ({'L5'}, {GR: None}),
          ({'L5'}, {NS: SHOP + "log('no ServerRequest_ItemBucketItemRemove here')\n"}),
          ({'L5'}, {NS: None}),
          ({'L5'}, {GP: GUN_PROBE + "pc:ServerRequest_ChangeBulletItem(pawn,FName('Bullet_Normal'))\n"}),
          ({'L5'}, {GP: None}),
          ({'L5'}, {EN: ENEMY + 'pc:ServerRequest_CreateActor(id,at,rot,false,true,0,0,0,n,false)\n'}),
          *[({'N1'}, {H: f'// {a}\n'}) for a in ('0x141ca3ea0', '0x14230B090', 'FUN_141CA5A10', '1ca5790', '1aBdd80')],
          ({'N1'}, {W: 'auto job = 0x141abdd80;\n'}),
          ({'N1'}, {SG: SEQ_CALL + '// 0x141ca5790\n'}),
          ({'N1'}, {SH: SEQ_CONST + '// RunEvent 0x141ca5a10\n'}),
          ({'N3'}, {SH: SEQ_CONST + '// FUN_141CA5790\n'}),
          ({'N3'}, {SH: '#pragma once\n'}),
          ({'N3'}, {SH: SEQ_CONST.replace('kRunZoneEvent', 'kPlaySequence')}),
          ({'N3'}, {SH: '// kRunZoneEvent\n' + SEQ_CONST}),
          ({'N3'}, {H: '// kRunZoneEvent\n'}),
          ({'N3'}, {SG: SEQ_CALL * 2}),
          ({'N3'}, {SG: 'void sbo_step_tick();\n'}),
          ({'N3'}, {WG: WORLD_CALL * 2}),
          ({'N3'}, {WG: 'void world_tick();\n'}),
          ({'N1'}, {WG: WORLD_CALL + '// FUN_141ca5790\n'}),
          ({'N3'}, {'native/src/game/objects/engine.h': '// kRunZoneEvent\n'}),
          ({'N2'}, {H: 'void StartMatchMaking();\n'}),
          ({'N2'}, {W: '// RequestMatchRequest\n'}),
          ({'N0', 'N3'}, {H: None, SH: None, SG: None, WG: None}),
          ({'N0'}, {W: None})]
for tags, change in PLANTS:
    got = scan_of({**CLEAN, **change})
    assert {v.split()[0] for v in got} == tags, (tags, change, got)

assert scan(ROOT) == [], scan(ROOT)
print('matchmaking_scan_test: ok')
