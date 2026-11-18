# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""tools/sbo_lobby_rows.py: online/lobby/sbo_maps.lua and online/lobby/halls_rows.h are what data/sbo-lobby.json gives
(--check passes on the tree, and fails once either file is edited by hand), the render is the same twice and loads in
Lua with the shape sbo.lua reads, the halls batch holds the five worlds, the five zones, then one ZoneEnvSpawnTable row
per kept seat but the camp ones (171: unique zero-padded names that never end in _<digits>, unique IDs over build
26123051's highest, the donor of the seat's sit loop, its zone, FirstInteraction and SaveType None), glue/tick.cpp
includes the header, and the checks refuse a map with 7 spots, two spots closer than 150 cm, a seat type with no sit
loop, a kept seat with no approach point, a map name whose world, zone or spawn point name the warp would misread
(ending in _<digits>), a fence that does not reach 40 cm past every spot, kept seat and approach point, world or zone
IDs off 7121+i and 1000121+i, maps out of order, seats not numbered 1 to n, seat heights for other loops than the four,
and more rows than a batch's byte-sized row index holds.
Run: python3 tests/tools/sbo_lobby_rows_test.py"""
import copy
import importlib.util
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
TOOL = ROOT / 'tools/sbo_lobby_rows.py'
LUA = 'mod/StellarCoop/Scripts/online/lobby/sbo_maps.lua'
HEADER = 'native/src/online/lobby/halls_rows.h'
spec = importlib.util.spec_from_file_location('sbo_lobby_rows', TOOL)
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)
DATA = json.loads((ROOT / 'data/sbo-lobby.json').read_text())


def errors_after(change):
    bad = copy.deepcopy(DATA)
    change(bad)
    return gen.check(bad)


def refused(change, word):
    return any(word in e for e in errors_after(change))


def test_check_passes():
    assert gen.check(DATA) == []
    done = subprocess.run([sys.executable, '-I', TOOL, '--check'], capture_output=True, text=True)
    assert done.returncode == 0, done.stderr
    maps = DATA['maps']
    assert [m['key'] for m in maps] == ['hotel', 'station', 'cloister', 'terrace', 'foyer']
    assert [m['world_id'] for m in maps] == [7121, 7122, 7123, 7124, 7125]
    assert [m['zone_id'] for m in maps] == [1000121, 1000122, 1000123, 1000124, 1000125]
    assert [len(m['spots']) for m in maps] == [8] * 5
    assert [len(m['seats']) for m in maps] == [33, 54, 42, 58, 60]
    # The 66 low benches and Cloister's 8 folding seats.
    assert [sum('skip' in s for s in m['seats']) for m in maps] == [8, 14, 16, 20, 16]
    assert {s['kind'] for m in maps for s in m['seats'] if 'skip' in s and 'folding' in s['skip']} == {'folding'}
    rules = {(m['key'], s['n']): s['approach']['rule'] for m in maps for s in m['seats'] if 'approach' in s}
    assert set(rules.values()) == {'60 cm along the yaw', 'nearest clear point on the yaw line', 'nearest walkable cell'}
    # The 7 seats with no clear point on the yaw line stand up on the nearest flood fill cell of their floor.
    cell = {k for k, rule in rules.items() if rule == 'nearest walkable cell'}
    assert cell == {('hotel', 30), ('hotel', 31), ('hotel', 32), ('hotel', 33), ('terrace', 1), ('terrace', 8),
                    ('terrace', 13)}, cell
    assert [m['fence']['R'] for m in maps] == [3573, 3971, 3851, 3939, 3625]


def test_refuses_seven_spots():
    assert refused(lambda d: d['maps'][0]['spots'].pop(), '8 spots')


def test_refuses_spots_closer_than_150():
    def close(d):
        a, b = d['maps'][4]['spots'][:2]  # Foyer 1 and 2, 280 cm apart in Y.
        b['X'], b['Y'] = a['X'], a['Y'] + 149
    assert refused(close, 'closer than 150')

    def at_150(d):
        a, b = d['maps'][4]['spots'][:2]
        b['X'], b['Y'] = a['X'], a['Y'] + 150
    assert errors_after(at_150) == []


def test_refuses_unknown_kind():
    assert refused(lambda d: d['maps'][0]['seats'][0].update(kind='sofa'), 'no sit loop')
    # A folding seat no longer skipped: SB's FoldingChair loop is not one of the four.
    assert refused(lambda d: d['maps'][2]['seats'][24].pop('skip'), 'no sit loop')
    assert errors_after(lambda d: d['maps'][2]['seats'][24].update(kind='sofa')) == []  # Skipped anyway.


def test_refuses_seat_without_approach():
    assert refused(lambda d: d['maps'][0]['seats'][0].pop('approach'), 'no approach point')


def test_refuses_wrong_ids():
    assert refused(lambda d: d['maps'][1].update(world_id=7121), 'IDs 7121, 1000122, want 7122, 1000122')
    assert refused(lambda d: d['maps'][4].update(zone_id=1000126), 'IDs 7125, 1000126, want 7125, 1000125')


def test_refuses_maps_out_of_order():
    def swap(d):
        d['maps'][0], d['maps'][1] = d['maps'][1], d['maps'][0]
    assert refused(swap, "maps: ['station', 'hotel', 'cloister', 'terrace', 'foyer']")
    assert refused(lambda d: d['maps'].pop(), "maps: ['hotel', 'station', 'cloister', 'terrace']")


def test_refuses_seats_not_numbered_1_to_n():
    assert refused(lambda d: d['maps'][3]['seats'][1].update(n=3), 'seats not numbered 1 to 58')
    assert refused(lambda d: d['maps'][3]['seats'].pop(0), 'seats not numbered 1 to 57')


def test_refuses_seat_heights_of_other_loops():
    assert refused(lambda d: d['seat_cm'].pop('camp'), 'seat_cm')
    assert refused(lambda d: d['seat_cm'].update(folding=46.4), 'seat_cm')


def test_refuses_name_ending_in_digits():
    errors = errors_after(lambda d: d['maps'][0].update(name='Hotel_2'))
    for name in ('world SBO_Hotel_2', 'zone Zone_SBO_Hotel_2', 'point SBO_Hotel_2'):
        assert any(name in e and '_<digits>' in e for e in errors), (name, errors)
    assert any('letters only' in e for e in errors), errors
    # Digits with no underscore are no FName number, but the name stays letters only.
    assert refused(lambda d: d['maps'][0].update(name='Hotel2'), 'letters only')
    assert not refused(lambda d: d['maps'][0].update(name='Hotel2'), '_<digits>')


def test_refuses_fence_shorter_than_farthest_spot_plus_40():
    f = DATA['maps'][1]['fence']  # Station.

    def spot_at(far):
        return lambda d: d['maps'][1]['spots'][0].update(X=f['X'] + far, Y=f['Y'])
    assert refused(spot_at(f['R'] - 39), 'fence')
    assert errors_after(spot_at(f['R'] - 40)) == []
    # Z: every ground over zmin, and zmax 200 cm over the highest (Station's: spot 3, 11.27).
    top = max(max(s['Z'], s['floor']) for s in DATA['maps'][1]['spots'])
    assert refused(lambda d: d['maps'][1]['fence'].update(zmax=top + 200), 'fence')
    assert errors_after(lambda d: d['maps'][1]['fence'].update(zmax=top + 201)) == []
    assert refused(lambda d: d['maps'][1]['fence'].update(zmin=0), 'fence')  # The terminal stands at 0.


def test_refuses_seat_or_approach_outside_fence():
    f = DATA['maps'][1]['fence']  # Station, seat 1 kept.

    def approach_at(far):
        return lambda d: d['maps'][1]['seats'][0]['approach'].update(X=f['X'] + far, Y=f['Y'])
    errors = errors_after(approach_at(f['R'] - 39))
    assert len(errors) == 1 and errors[0].startswith(f"station: seat 1 approach {f['R'] - 39} cm"), errors
    assert errors_after(approach_at(f['R'] - 40)) == []
    errors = errors_after(lambda d: d['maps'][1]['seats'][0].update(X=f['X'] + f['R'] - 39, Y=f['Y']))
    assert len(errors) == 1 and errors[0].startswith(f"station: seat 1 {f['R'] - 39} cm"), errors


def test_render_is_stable():
    text = gen.render_lua(DATA)
    assert text == gen.render_lua(copy.deepcopy(DATA))
    assert text.startswith(''.join(f'-- {line}\n' for line in gen.LICENSE_HEADER)
                           + '-- Generated by tools/sbo_lobby_rows.py from data/sbo-lobby.json: do not edit by hand.\n')
    # The module loads in Lua with the interface sbo.lua reads. Hotel seat 1: a sofa, top at 137, outdoor loop
    # (50.8): the floor 86.2, facing -Y; the traces found its standing capsule clear 60 cm towards -Y over the Pawn
    # floor 86.12. Hotel seat 8: blocked at 60 cm by the booth table, clear at 25. Hotel seat 30: no clear point on
    # its yaw line, it stands up on the nearest flood fill cell (650, 1750). Station seat 1 stands up at the Pawn floor
    # 10.77, not at its seat floor (-1.3). Station seat 33: clear 15 cm behind the seat (yaw -150). Terrace seat 1:
    # its cell's floor is 7.83, its Z the Pawn floor under the marker (4.31) plus 100.
    check = r"""
local M=dofile(arg[1])
assert(table.concat(M.order,',')=='hotel,station,cloister,terrace,foyer')
local h=M.maps.hotel
assert(h.name=='Hotel' and h.world=='SBO_Hotel' and h.zone=='Zone_SBO_Hotel' and h.point=='SBO_Hotel')
assert(h.world_id==7121 and h.zone_id==1000121 and h.umap=='/Game/SBO_Lobby/Lobby_Hotel')
assert(M.maps.foyer.world_id==7125 and M.maps.foyer.zone=='Zone_SBO_Foyer')
assert(#h.spots==8 and h.spots[1].X==267.9 and h.spots[1].Z==105 and h.spots[1].Yaw==96.53)
assert(M.maps.station.spots[3].Z==111.27 and M.maps.cloister.spots[1].Z==100)
local s=h.seats[1]
assert(#h.seats==25 and s.n==1 and s.kind=='outdoor' and s.X==-910 and s.Y==2319 and s.Yaw==-90)
assert(math.abs(s.Z-86.2)<1e-9 and s.approach.X==-910 and s.approach.Y==2259 and s.approach.Z==186.12)
local by={}
for _,seat in ipairs(h.seats) do assert(seat.n<22 or seat.n>29); by[seat.n]=seat end
assert(by[8].approach.X==0 and by[8].approach.Y==2368 and by[8].approach.Z==186.12)
assert(by[30].approach.X==650 and by[30].approach.Y==1750 and by[30].approach.Z==186.12)
local st={}
for _,seat in ipairs(M.maps.station.seats) do st[seat.n]=seat end
assert(math.abs(st[1].Z+1.3)<1e-9 and st[1].approach.Y==-1533 and st[1].approach.Z==110.77)
assert(st[33].approach.X==-354.61 and st[33].approach.Y==-1245 and st[33].approach.Z==111.27)
assert(#M.maps.cloister.seats==26 and #M.maps.terrace.seats==38)
-- Each seat's ZoneEnvSpawnTable row, but the camp seats'.
assert(s.row=='SBO_Hotel_Seat001' and s.id==3910032001 and st[33].row=='SBO_Station_Seat033')
for _,seat in ipairs(M.maps.cloister.seats) do
    assert((seat.row==nil)==(seat.kind=='camp') and (seat.id==nil)==(seat.kind=='camp'))
end
local te=M.maps.terrace.seats[1]
assert(te.n==1 and te.approach.X==-3050 and te.approach.Y==-550 and math.abs(te.approach.Z-104.31)<1e-9)
assert(h.terminal.X==1380 and h.terminal.Yaw==0 and h.camera.FOV==60 and h.camera.Pitch==3.72)
assert(h.fence.X==12.5 and h.fence.Y==-537.5 and h.fence.R==3573 and h.fence.zmin==-200 and h.fence.zmax==900)
"""
    with tempfile.TemporaryDirectory() as tmp:
        (Path(tmp) / 'sbo_maps.lua').write_text(text)
        (Path(tmp) / 'check.lua').write_text(check)
        done = subprocess.run(['lua5.4', 'check.lua', 'sbo_maps.lua'], cwd=tmp, capture_output=True, text=True)
        assert done.returncode == 0, done.stderr


def test_seat_rows():
    rows = gen.seat_rows(DATA)
    # Every kept seat but Cloister's two camp seats, 37 and 38.
    assert [sum(m['key'] == k for m, _, _, _ in rows) for k in gen.ORDER] == [25, 40, 24, 38, 44]
    assert len(rows) == 171 and not any(s['kind'] == 'camp' for _, s, _, _ in rows)
    assert {(m['key'], s['n']) for m in DATA['maps'] for s in m['seats']
            if not s.get('skip') and s['kind'] == 'camp'} == {('cloister', 37), ('cloister', 38)}
    names, ids = [name for _, _, name, _ in rows], [i for _, _, _, i in rows]
    assert len(set(names)) == 171 and len(set(ids)) == 171
    for i, (m, s, name, rid) in enumerate(rows):
        assert name == f"SBO_{m['name']}_Seat{s['n']:03d}" and not re.search(r'_\d+$', name), name
        assert rid == 3900032000 + 10000000 * (gen.ORDER.index(m['key']) + 1) + s['n'], name
        # Above every ZoneEnvSpawnTable ID of build 26123051 (4430 rows, highest NKGame_05_EnvS_001), under 2^32.
        assert 3305032001 < rid < 2 ** 32, name
    assert (rows[0][2], rows[0][3], rows[-1][2], rows[-1][3]) == ('SBO_Hotel_Seat001', 3910032001,
                                                                  'SBO_Foyer_Seat060', 3950032060)
    assert gen.DONORS == {'outdoor': 'Xion_10_EnvS_035', 'bar': 'Xion_10_EnvS_021', 'table': 'Xion_10_EnvS_025'}


def test_header():
    text = gen.render_header(DATA)
    assert text == gen.render_header(copy.deepcopy(DATA))
    assert text.startswith(''.join(f'// {line}\n' for line in gen.LICENSE_HEADER)
                           + '// Generated by tools/sbo_lobby_rows.py from data/sbo-lobby.json: do not edit by hand.\n')
    assert (ROOT / HEADER).read_text() == text
    assert '\n#include "online/lobby/halls_rows.h"\n' in (ROOT / 'native/src/glue/tick.cpp').read_text()
    body = re.search(r'constexpr Patch kHallsPatches\[\] = \{\n(.*?)\n\};', text, re.S).group(1)
    patches = re.findall(r'\{(0x[0-9a-f]+), Kind::(\w+), (\d+), (?:"([^"]*)"|nullptr)\}, // (\w+)', body)
    recipe = re.findall(r'\{Table::(\w+), "(\w+)", "(\w+)", (\d+)u, (\d+), (\d+)\}',
                        re.search(r'constexpr Row kHallsRecipe\[\] = \{\n(.*?)\n\};', text, re.S).group(1))
    assert len(recipe) == 181 and len(patches) == 5 + 5 * 4 + 171 * 4
    first = 0
    for t, name, donor, rid, at, count in recipe:  # Each row's patches follow the last row's.
        assert int(at) == first, name
        first += int(count)
    assert first == len(patches)
    for i, key in enumerate(gen.ORDER):
        m = DATA['maps'][i]
        n = gen.names(m)
        assert recipe[i] == ('world', n['world'], 'CombatTestMapMk2', str(7121 + i), str(i), '1')
        assert patches[i] == ('0x18', 'string', '0', f"{n['umap']}.Lobby_{m['name']}", 'UMapPath')
        assert recipe[5 + i] == ('zone', n['zone'], 'Zone_Xion_Boss_Mann', str(1000121 + i), str(5 + 4 * i), '4')
        assert patches[5 + 4 * i:9 + 4 * i] == [('0x14', 'name', '0', n['world'], 'WorldAlias'),
                                                ('0x25', 'u8', '5', '', 'ZoneType'),
                                                ('0x30', 'string', '0', n['point'], 'StartPointAlias'),
                                                ('0x138', 'names', '0', '', 'AdditiveDesignLevel')]
    for k, ((t, name, donor, rid, at, count), (m, s, want, want_id)) in enumerate(zip(recipe[10:],
                                                                                         gen.seat_rows(DATA))):
        assert (t, name, donor, int(rid), count) == ('env', want, gen.DONORS[s['kind']], want_id, '4')
        assert patches[int(at):int(at) + 4] == [('0x20', 'names', '0', gen.names(m)['zone'], 'ZoneList'),
                                                ('0x30', 'name', '0', want, 'EnvActorName'),
                                                ('0x64', 'name', '0', 'FirstInteraction', 'InitStateTag'),
                                                ('0x6c', 'u8', '0', '', 'SaveType')], name


def test_refuses_more_rows_than_a_batch_holds():
    def grow(by):  # Foyer's kept seats copied as seats 61 on.
        def change(d):
            seats = d['maps'][4]['seats']
            kept = [s for s in seats if not s.get('skip')]
            seats += [dict(copy.deepcopy(kept[k % len(kept)]), n=len(seats) + 1 + k) for k in range(by)]
        return change
    # 10 + 171 rows now; 74 more make 255, the most a byte-sized row index counts.
    assert errors_after(grow(74)) == []
    assert refused(grow(75), 'halls batch: 256 rows')


def test_check_mode_detects_stale_module():
    with tempfile.TemporaryDirectory() as tmp:
        for rel in ('tools/sbo_lobby_rows.py', 'data/sbo-lobby.json', LUA, HEADER):
            (Path(tmp) / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(ROOT / rel, Path(tmp) / rel)
        args = [sys.executable, '-I', Path(tmp) / 'tools/sbo_lobby_rows.py', '--check']
        assert subprocess.run(args, capture_output=True).returncode == 0
        lua = Path(tmp) / LUA
        lua.write_text(lua.read_text().replace('world_id=7121', 'world_id=7120'))
        done = subprocess.run(args, capture_output=True, text=True)
        assert done.returncode == 1 and 'Out of date' in done.stderr and LUA in done.stderr, done.stderr
        assert HEADER not in done.stderr, done.stderr
        shutil.copy(ROOT / LUA, lua)
        header = Path(tmp) / HEADER
        header.write_text(header.read_text().replace('3910032001u', '3910032002u'))
        done = subprocess.run(args, capture_output=True, text=True)
        assert done.returncode == 1 and HEADER in done.stderr and LUA not in done.stderr, done.stderr


for name, test in list(globals().items()):
    if name.startswith('test_'):
        test()
print('sbo_lobby_rows_test: ok')
