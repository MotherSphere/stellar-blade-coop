"""tools/mxiii_climb.py: every ladder of data/mxiii-world.json's move list with editor proxies is what the proxies give
(--check passes on the tree), and rebuilt the way BP_EM_Ladder_C's construction script builds it (pieces stacked up
from the actor's origin, TotalHeight starting at 0) it lays within 2 cm on the editor's ladder, the R16 ledges on the
static ledges and the shimmy markers, the ropes on their markers. The check refuses what the move list held before
2026-10-31: ladders lifted by their own height (TotalHeight written before the finish), feet sunk under the editor's
(the top-aligned recipe), stacks other than the editor's, and the landing on the wrong side. Every ladder also lands:
TopLeave's trace (S + 25 down to S - 25 at x -60) meets the floor within 20 cm of its stack top S, and its foot stands
on (or up to 20 cm in) the floor at BottomLeave; the 20 ladders whose editor stack does not land get another stack and
foot, and the check refuses the editor's there."""
import copy
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
spec = importlib.util.spec_from_file_location('mxiii_climb', ROOT / 'tools/mxiii_climb.py')
climb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(climb)

done = subprocess.run([sys.executable, ROOT / 'tools/mxiii_climb.py', '--check'], capture_output=True, text=True)
assert done.returncode == 0, done.stderr

geo = json.loads((ROOT / 'data/mxiii-climb.json').read_text())
move = json.loads((ROOT / 'data/mxiii-world.json').read_text())['move']
assert climb.overlay(geo, move) == []
ladders = [m for m in move if m['cls'] == 'ladder' and m['key'] in geo['ladders']]
assert len(ladders) == 37 and len([m for m in move if m['key'] in geo['ledges'] or m['key'] in geo['ropes']]) == 6


def misses(change):
    bad = copy.deepcopy(move)
    for m in bad:
        if m['cls'] == 'ladder' and m['key'] in geo['ladders']:
            change(m)
    return {line.split(':')[0] for line in climb.overlay(geo, bad)}


every = {m['key'] for m in ladders}
# The pieces started at the TotalHeight the mod wrote: every ladder a whole height up.
assert misses(lambda m: m['at'].__setitem__(2, m['at'][2] + m['height'])) == every
# Sunk 25 cm: every ladder; 3 cm off the rail line: every ladder but the four whose scaled proxies no stack matches.
assert misses(lambda m: m['at'].__setitem__(2, m['at'][2] - 25)) == every
assert misses(lambda m: m['at'].__setitem__(0, m['at'][0] + 3)) == every - set(climb.SCALED)
# The landing on the +X side, where the markers show it.
assert 'M6_ladder_R28_walkout' in misses(lambda m: m.__setitem__('yaw', m['yaw'] + 180))
# The recipe's 200+200 for Z2P02_S, whose editor ladder is 240+240.
assert 'M6_ladder_Z2P02_S' in misses(lambda m: m['key'] == 'M6_ladder_Z2P02_S' and m.__setitem__('meshes', [1, 1]))
# A ledge turned, a rope 10 cm short.
bad = copy.deepcopy(move)
next(m for m in bad if m['key'] == 'R16_S_Ledge_0')['yaw'] += 2
next(m for m in bad if m['key'] == 'Rope_R28')['drop'] -= 10
assert {line.split(':')[0] for line in climb.overlay(geo, bad)} == {'R16_S_Ledge_0', 'Rope_R28'}
# The editor's stack on the editor's foot, as the move list held it before the landing fix: these 20 do not land (18
# tops 23 to 100 cm over the landing, R11_R08 and Z3P08 under it, Z4_L1's foot 24 cm over its floor).
RESOLVED = {'M6_ladder_' + k for k in (
    'R08_0', 'R08_1', 'R11_R08', 'R10_84', 'R10_TopStop', 'R26_0', 'R26_1', 'Z2R29_car14', 'Z2R29_P1W', 'Z2R24',
    'Z2P02_S', 'Z2P02_N', 'Z2P03', 'Z2P05', 'Z2P06_wall', 'Z2P06_cabin', 'Z3P08', 'Z4R14', 'Z4R16', 'Z4_L1')}
M = geo['meshes']
assert {k for k, lad in geo['ladders'].items()
        if climb.landing(M, lad, *climb.editor_stack(M, lad))[0] is None} == RESOLVED


def editors(m):
    m['meshes'], m['at'][2] = climb.editor_stack(M, geo['ladders'][m['key']])


bad = copy.deepcopy(move)
for m in bad:
    if m['key'] in geo['ladders']:
        editors(m)
lands = {line.split(':')[0] for line in climb.overlay(geo, bad) if 'landing' in line or 'its top' in line
         or 'in the air' in line or 'over its floor' in line}
assert lands == RESOLVED, lands ^ RESOLVED
# Every move ladder: the landing within 20 cm of S; 21 cm higher, R28's walk-out ladder misses it.
for m in ladders:
    land, why = climb.landing(M, geo['ladders'][m['key']], m['meshes'], m['at'][2])
    assert not why and abs(land) <= climb.WINDOW, (m['key'], why)
assert any(line.startswith('M6_ladder_R28_walkout: top +21.0') for line in climb.overlay(geo, [
    dict(m, at=m['at'][:2] + [m['at'][2] + 21]) for m in move if m['key'] == 'M6_ladder_R28_walkout']))
print('mxiii_climb_test: ok')
