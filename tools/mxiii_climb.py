#!/usr/bin/env python3
"""Places Matrix XIII's spawned ladders on the editor's ladders: writes each ladder of data/mxiii-world.json's move list
that data/mxiii-climb.json has proxies for (at, yaw, Meshes, the TotalHeight they give), and checks that every
ladder, ledge and rope of the move list overlays the editor geometry within 2 cm, its parts rebuilt the way the
game's construction scripts build them.

  python3 tools/mxiii_climb.py          rewrite those ladders in data/mxiii-world.json
  python3 tools/mxiii_climb.py --check  exit 1 when the move list is not what the editor geometry gives or does not
                                        overlay it

BP_EM_Ladder_C's UserConstructionScript (bytecode read with CUE4Parse): one StaticMeshComponent per Meshes entry, then
the 80_A_SM head, each at (0, -HeadWidthHalf, TotalHeight) with yaw -90 in the actor, TotalHeight growing by each
mesh's 2 * BoxExtent.Z after it is placed. TotalHeight is never reset first, so the stack starts at whatever it holds
when the script runs: the class default 0 unless something writes it before. The root is the ladder's foot and the
pieces stack upward from it; HeadWidthHalf is the head mesh's BoxExtent.Y. StartUnit only raises BottomBegin (40 cm a
unit) and the lower clamp of CollisionBottomZAdd, which lowers the bottom of the climb box; neither moves a piece.
BP_EM_Ledge_C puts its first mesh at the actor's origin. Env_EM_VerticalRope_C hangs from its origin, BottomLeavePoint
RopeDistanceB below it.
"""
import itertools
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLIMB = ROOT / 'data/mxiii-climb.json'
WORLD = ROOT / 'data/mxiii-world.json'
ENUM = {'160_A_SM': 0, '200_A_SM': 1, '240_A_SM': 2, '600_A_SM': 3, '40_A_SM': 11}  # BP_EM_Ladder_C's MeshMap.
NAME = {v: k for k, v in ENUM.items()}
HEAD = '80_A_SM'
TOL = 2.0  # cm
REACH = 20.0  # cm a ladder's foot may stand over the floor and still be caught (its climb box reaches 55 cm under).
# Ladders whose editor proxies are scaled in z to a span no Meshes stack gives within TOL: the stack reaches the top
# and overshoots it by at most this much (cm); the top landing is traced within 25 cm, so EVE still steps onto it.
SCALED = {'M6_ladder_Z4P02': 15.0, 'M6_ladder_Z4P03_up': 17.0, 'M6_ladder_Z4P03_down': 17.0, 'M6_ladder_Z4R21': 6.0}
# Editor pieces off their own ladder's rail line, which the script never does (cm): Z4R06_pit's top 160_A_SM stands
# 97 cm behind it (that mesh's rails are at its depth 0, with 86 stray vertices 100 cm behind).
SLIP = {('M6_ladder_Z4R06_pit', 3): 98.0}


def turn(yaw, x, y):
    a = math.radians(yaw)
    return x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a)


def height(meshes, name):
    return meshes[name]['max'][2] - meshes[name]['min'][2]


def rails(meshes, name, pivot, yaw, sz=1.0):
    """A ladder piece's rail plane: its lateral bounds at its bottom and top, at the mesh's depth 0 (world points)."""
    lo, hi = meshes[name]['min'], meshes[name]['max']
    out = []
    for lx in (lo[0], hi[0]):
        dx, dy = turn(yaw, lx, 0.0)
        out += [(pivot[0] + dx, pivot[1] + dy, pivot[2] + lz * sz) for lz in (lo[2], hi[2])]
    return out


def apart(a, b):
    """The largest distance from a point of one set to the nearest point of the other (cm)."""
    near = lambda p, q: max(min(math.dist(x, y) for y in q) for x in p)
    return max(near(a, b), near(b, a))


def ladder_pieces(meshes, m):
    """[(mesh, rail plane)] of a move ladder as the construction script builds it, from TotalHeight 0."""
    hwh = (meshes[HEAD]['max'][1] - meshes[HEAD]['min'][1]) / 2
    px, py = turn(m['yaw'], 0.0, -hwh)
    z, out = 0.0, []
    for name in [NAME[k] for k in m['meshes']] + [HEAD]:
        out.append((name, rails(meshes, name, (m['at'][0] + px, m['at'][1] + py, m['at'][2] + z), m['yaw'] - 90)))
        z += height(meshes, name)
    return out


def proxy_pieces(meshes, ladder):
    return [(p['mesh'], rails(meshes, p['mesh'], p['at'], p['yaw'], p.get('scale', [1, 1, 1])[2]))
            for p in ladder['proxies']]


def stack_for(meshes, span, below=False):
    """The Meshes stack for a span: the fewest pieces within TOL, else the shortest overshoot (below: the fewest pieces
    that stay under the span by at most REACH, for the pieces added under a proxy that floats over its floor)."""
    best = None
    for n in range(1, 6):
        for combo in itertools.combinations_with_replacement(sorted(ENUM, key=lambda k: -height(meshes, k)), n):
            s = sum(height(meshes, k) for k in combo)
            if below:
                key = (s > span, span - s > REACH, n, span - s)
            else:
                key = (abs(s - span) > TOL, s < span - TOL, abs(s - span), n)
            if best is None or key < best[0]:
                best = (key, [ENUM[k] for k in combo])
    return best[1]


def landing_yaw(ladder, py, old):
    """The actor yaw whose -X points from the Foot marker to the Head marker (the upper landing), the rungs facing as
    the proxy's (proxy yaw + 90 or - 90); markers with no clear direction keep the old yaw if it is one of the two."""
    two = [((py + d + 180) % 360) - 180 for d in (90, -90)]
    fx, fy = ladder['head'][0] - ladder['foot'][0], ladder['head'][1] - ladder['foot'][1]
    reach = math.hypot(fx, fy)
    dots = [-(math.cos(math.radians(y)) * fx + math.sin(math.radians(y)) * fy) for y in two]
    if reach > 5 and max(dots) > 0.5 * reach:
        return two[0] if dots[0] > dots[1] else two[1]
    return next((y for y in two if abs(((y - old + 180) % 360) - 180) < 1), two[0])


def place(meshes, ladder, old):
    """The move fields that lay the spawned ladder on the editor's: Meshes from the proxy stack (or the stack nearest
    a z-scaled one), the foot on the lowest proxy, pieces added under a proxy that floats over the Foot marker."""
    body = [p for p in ladder['proxies'] if p['mesh'] != HEAD]
    low, py = body[0], body[0]['yaw']
    # The editor's pieces; a run of z-scaled ones becomes the stack nearest its span.
    stack, run = [], 0.0
    for p in body + [None]:
        if p and 'scale' in p:
            run += height(meshes, p['mesh']) * p['scale'][2]
            continue
        if run:
            stack += stack_for(meshes, run)
            run = 0.0
        if p:
            stack.append(ENUM[p['mesh']])
    gap = low['at'][2] - ladder['foot'][2]
    under = stack_for(meshes, gap, below=True) if gap > REACH else []
    yaw = landing_yaw(ladder, py, old['yaw'])
    pivot = low['at'][:2]
    if abs(((yaw - py - 90 + 180) % 360) - 180) > 1:  # Turned half round: the pivot rail is the proxy's far rail.
        lo, hi = meshes[low['mesh']]['min'][0], meshes[low['mesh']]['max'][0]
        dx, dy = turn(py, lo + hi, 0.0)
        pivot = [pivot[0] + dx, pivot[1] + dy]
    hwh = (meshes[HEAD]['max'][1] - meshes[HEAD]['min'][1]) / 2
    ox, oy = turn(yaw, 0.0, -hwh)
    meshes_all = under + stack
    total = sum(height(meshes, NAME[k]) for k in meshes_all) + height(meshes, HEAD)
    z = low['at'][2] - sum(height(meshes, NAME[k]) for k in under)
    return {'at': [round(pivot[0] - ox, 2), round(pivot[1] - oy, 2), round(z, 2)], 'yaw': round(yaw, 1),
            'height': round(total, 3), 'meshes': meshes_all, 'start': 1, 'bottom': 55.0}


def overlay(climb, move):
    """Every way the move list's ladders, ledges and ropes miss the editor geometry: a list of lines, empty if none."""
    meshes, bad = climb['meshes'], []
    for m in move:
        key = m['key']
        if m['cls'] == 'ladder' and key in climb['ladders']:
            lad = climb['ladders'][key]
            got = ladder_pieces(meshes, m)
            want = proxy_pieces(meshes, lad)
            body, head = got[:-1], got[-1]
            pbody = [p for p in want if p[0] != HEAD]
            phead = [p for p in want if p[0] == HEAD]
            if all('scale' not in p for p in lad['proxies']):
                if [n for n, _ in body[-len(pbody):]] != [n for n, _ in pbody]:
                    bad.append(f'{key}: stack {[n for n, _ in body]}, editor {[n for n, _ in pbody]}')
                else:
                    for i, ((_, a), (_, b)) in enumerate(zip(body[-len(pbody):], pbody)):
                        if apart(a, b) > SLIP.get((key, i), TOL):
                            bad.append(f'{key}: piece {i} {apart(a, b):.1f} cm off the editor\'s')
            else:
                # The stack's rail plane, lowest bottom to highest top, against the scaled proxies'.
                span = lambda pieces: [pieces[0][1][0], pieces[0][1][2], pieces[-1][1][1], pieces[-1][1][3]]
                d = apart(span(body), span(pbody))
                if d > SCALED.get(key, TOL):
                    bad.append(f'{key}: rails {d:.1f} cm off the editor\'s scaled ones')
            # The head by its height only: the script hangs its handrail over the landing (-X), where several editor
            # heads stand 21 or 53 cm off the rail line or hook away from the landing.
            if phead and abs(head[1][0][2] - phead[0][1][0][2]) > SCALED.get(key, TOL):
                bad.append(f'{key}: head {head[1][0][2] - phead[0][1][0][2]:.1f} cm off the editor\'s')
            foot = body[0][1][0][2]
            if foot > lad['foot'][2] + REACH:
                bad.append(f'{key}: foot {foot - lad["foot"][2]:.0f} cm over the Foot marker')
            total = sum(height(meshes, n) for n, _ in got)
            if abs(total - m['height']) > 0.01:
                bad.append(f'{key}: height {m["height"]}, its pieces give {total:.3f}')
            fx, fy = lad['head'][0] - lad['foot'][0], lad['head'][1] - lad['foot'][1]
            back = -(math.cos(math.radians(m['yaw'])) * fx + math.sin(math.radians(m['yaw'])) * fy)
            if math.hypot(fx, fy) > 5 and back < -0.5 * math.hypot(fx, fy):
                bad.append(f'{key}: the landing is on its +X side (yaw {m["yaw"]})')
        elif m['cls'] == 'ledge' and key in climb['ledges']:
            ref = climb['ledges'][key]
            lo, hi = meshes['006_B_SM']['min'], meshes['006_B_SM']['max']
            if m['mesh'].split('/')[-1].split('.')[0] != '006_B_SM':
                bad.append(f'{key}: mesh {m["mesh"]}')
            box = lambda at, yaw: [(at[0] + turn(yaw, x, y)[0], at[1] + turn(yaw, x, y)[1], at[2] + z)
                                   for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]
            if 'mesh' in ref:
                d = apart(box(m['at'], m['yaw']), box(ref['at'], ref['yaw']))
            else:  # The shimmy: from its End marker to its Start marker, the mesh's length.
                ex, ey = turn(m['yaw'], hi[0], 0.0)
                end = (m['at'][0] + ex, m['at'][1] + ey, m['at'][2])
                d = max(math.dist(m['at'], ref['from']), math.dist(end, ref['to']))
            if d > TOL:
                bad.append(f'{key}: {d:.1f} cm off the editor\'s ledge')
        elif m['cls'] == 'rope' and key in climb['ropes']:
            ref = climb['ropes'][key]
            d = max(math.dist(m['at'], ref['top']), abs(m['at'][2] - m['drop'] - ref['foot'][2]))
            if d > TOL:
                bad.append(f'{key}: {d:.1f} cm off its markers')
    return bad


def main(argv):
    climb = json.loads(CLIMB.read_text())
    text = WORLD.read_text()
    data = json.loads(text)
    check = '--check' in argv
    bad = overlay(climb, data['move']) if check else []  # The file as it is.
    for m in data['move']:
        if m['cls'] == 'ladder' and m['key'] in climb['ladders']:
            m.update(place(climb['meshes'], climb['ladders'][m['key']], m))
    want = json.dumps(data, indent=1, ensure_ascii=False) + '\n'
    if check:
        if want != text:
            bad.insert(0, 'data/mxiii-world.json is out of date, run python3 tools/mxiii_climb.py')
    else:
        WORLD.write_text(want)
        bad = overlay(climb, data['move'])
    if bad:
        sys.exit('\n'.join(bad))


if __name__ == '__main__':
    main(sys.argv[1:])
