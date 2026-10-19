-- The partner marker's maths: a point in camera space (UE: X forward, Y right, Z up; camera roll 0), the marker on
-- screen or an arrow on the screen's edge pointing at her (behind and straight above included), with hysteresis
-- between the two (off at 48 units from an edge, back at 72), the distance text, and whether she is on your map.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local P=require('partner')
local function near(a,b) return math.abs(a-b)<1e-6 end
local function at(x,y,z) return {X=x,Y=y,Z=z} end
local ORIGIN,AHEAD=at(0,0,0),{Pitch=0,Yaw=0}

-- Camera space.
local function space(c,r,p,want)
    local f,ri,u=P.camera_space(c,r,p)
    assert(near(f,want[1]) and near(ri,want[2]) and near(u,want[3]),string.format('%g %g %g',f,ri,u))
end
space(ORIGIN,AHEAD,at(100,0,0),{100,0,0})
space(ORIGIN,AHEAD,at(0,100,0),{0,100,0}) -- +Y is on the right.
space(ORIGIN,AHEAD,at(0,0,100),{0,0,100})
space(ORIGIN,{Pitch=0,Yaw=90},at(0,100,0),{100,0,0}) -- Facing +Y.
space(ORIGIN,{Pitch=0,Yaw=90},at(-100,0,0),{0,100,0}) -- Then -X is on the right.
space(ORIGIN,{Pitch=90,Yaw=0},at(0,0,100),{100,0,0}) -- Looking straight up.
space(ORIGIN,{Pitch=90,Yaw=0},at(100,0,0),{0,0,-100}) -- Then what was ahead is below.
space(at(10,20,30),{Pitch=0,Yaw=180},at(-90,20,30),{100,0,0}) -- From where the camera stands.

-- The edge: 48 units in, the art pointing right at 0 degrees, screen y down. 16:9 in layout units.
local W,H,M=3840,2160,48
local function edge(r,u,want)
    local x,y,a=P.edge(r,u,W,H,M)
    assert(near(x,want[1]) and near(y,want[2]) and near(a%360,want[3]%360),string.format('%g %g %g',x,y,a))
end
edge(1,0,{W-M,H/2,0})
edge(-1,0,{M,H/2,180})
edge(0,1,{W/2,M,-90}) -- Straight above: top centre, pointing up.
edge(0,-1,{W/2,H-M,90})
edge(0,0,{W/2,H-M,90}) -- Straight behind or under: bottom centre.
edge(1,1,{W/2+H/2-M,M,-45}) -- The top edge comes first on a wide screen.
edge(1,-1,{W/2+H/2-M,H-M,45})
edge(-3,1,{M,H/2-(W/2-M)/3,math.deg(math.atan(1,3))-180}) -- Left and up.

-- place(): the marker on screen, or the arrow. 90 degrees of horizontal view: 1920 units of screen per unit of
-- right/forward from the centre.
local function view(p,extra)
    local v={camera=ORIGIN,rotation=AHEAD,fov=90,anchor=p,width=W,height=H}
    for k,value in pairs(extra or {}) do v[k]=value end
    return v
end
local function place(v,was_on,want)
    local on,x,y,a=P.place(v,was_on)
    assert(on==want[1] and near(x,want[2]) and near(y,want[3]) and (want[4]==nil and a==nil or near(a%360,want[4]%360)),
        string.format('%s %g %g %s',on,x,y,a))
end
place(view(at(1000,0,0)),false,{true,W/2,H/2})
place(view(at(1000,500,-250)),false,{true,W/2+960,H/2+480})
place(view(at(1000,990,0)),true,{false,W-M,H/2,0}) -- Past the right edge: the arrow, pointing right.
-- Hysteresis: 60 units from the left edge stays a marker, and becomes one again only 72 units in.
place(view(at(1920,-1860,0)),true,{true,60,H/2})
place(view(at(1920,-1860,0)),false,{false,M,H/2,180})
place(view(at(1920,-1800,0)),false,{true,120,H/2})
place(view(at(1920,-1880,0)),true,{false,M,H/2,180}) -- 40 units in: gone either way.
-- Behind: always the arrow, towards the side she is on; straight behind, bottom centre.
place(view(at(-1000,0,0)),true,{false,W/2,H-M,90})
place(view(at(-1000,-500,0)),true,{false,M,H/2,180})
place(view(at(100,0,5000)),true,{false,W/2,M,-90}) -- High above: top centre.
place(view(at(0.5,0,0)),true,{false,W/2,H-M,90}) -- At the camera: no division by almost nothing.
-- The engine's projection, when given, places the marker instead of the field of view; never for a point behind.
place(view(at(1000,0,0),{screen={x=500,y=400}}),false,{true,500,400})
place(view(at(-1000,0,0),{screen={x=500,y=400}}),false,{false,W/2,H-M,90})
place(view(at(1000,-990,0),{screen={x=10,y=H/2}}),true,{false,M,H/2,180})

-- The distance: whole metres; on screen only past 15 m, on the arrow always.
assert(P.distance(ORIGIN,at(1549,0,0),true)==nil and P.distance(ORIGIN,at(1550,0,0),true)=='16 m')
assert(P.distance(ORIGIN,at(200,0,0),false)=='2 m' and P.distance(ORIGIN,at(300,0,400),false)=='5 m')
assert(P.distance(at(100,100,100),at(100,100,100),false)=='0 m')

-- Her map: the same as yours, elsewhere (the arrow hides, the card says where), or unknown.
local E04,B07='/game/art/bg/worldmap/level_p/e04','/game/art/bg/worldmap/level_p/b07'
local state,map=P.where(E04,E04)
assert(state=='same' and map=='e04')
state,map=P.where(E04,B07)
assert(state=='elsewhere' and map=='b07')
state,map=P.where(nil,B07)
assert(state==nil and map=='b07','Your own map unknown (a load): neither same nor elsewhere, her map still known')
assert(P.where(E04,nil)==nil,'Hers unknown: nothing to say')

-- Her gauges by the player cluster's own rules (sb-layout.md 0). HP: lit columns by HP / MaxHP, rounded up so a sliver
-- still shows one; none at 0 HP or without a max.
assert(P.hp_columns(100,100,40)==40 and P.hp_columns(50,100,40)==20 and P.hp_columns(51,100,40)==21)
assert(P.hp_columns(1,1000,40)==1,'A sliver shows')
assert(P.hp_columns(0,100,40)==0 and P.hp_columns(5,0,40)==0 and P.hp_columns(150,100,40)==40)
-- Shield: blocks shown = min(ShieldBlock, 5); points a block = floor(MaxShield / ShieldBlock); every lit block full
-- but the last, which fills by what is left (rounded up); later blocks dim (0); nil past the shown ones.
local function blocks(sh,max,n)
    local out={}
    for i=1,6 do out[i]=tostring(P.shield_block(i,sh,max,n,11)) end
    return table.concat(out,' ')
end
assert(blocks(300,300,3)=='11 11 11 nil nil nil',blocks(300,300,3))
assert(blocks(150,300,3)=='11 6 0 nil nil nil',blocks(150,300,3)) -- 100 a block: 50 of the second, 5.5 columns.
assert(blocks(0,300,3)=='0 0 0 nil nil nil')
assert(blocks(40,100,1)=='5 nil nil nil nil nil')
assert(blocks(700,700,7)=='11 11 11 11 11 nil','ShieldBlock 7: five shown')
assert(blocks(250,700,7)=='11 11 6 0 0 nil',blocks(250,700,7))
assert(blocks(50,100,0)=='nil nil nil nil nil nil','No block, no row')
assert(blocks(5,3,7)=='0 0 0 0 0 nil','Under a point a block: dim')
-- Beta and Burst: one cube a 200 points of the max, at most limit shown; full cubes = floor(value / 200); the next
-- lights floor((value mod 200) / 50) quarters.
local function cubes(value,max,limit)
    local out={}
    for i=1,limit+1 do out[i]=tostring(P.cube(i,value,max,limit)) end
    return table.concat(out,' ')
end
assert(cubes(450,1000,8)=='4 4 1 0 0 nil nil nil nil',cubes(450,1000,8))
assert(cubes(0,600,8)=='0 0 0 nil nil nil nil nil nil')
assert(cubes(199,400,8)=='3 0 nil nil nil nil nil nil nil')
assert(cubes(3200,3200,8)=='4 4 4 4 4 4 4 4 nil','Sixteen cubes of Beta: eight on the card')
assert(cubes(0,0,8)=='nil nil nil nil nil nil nil nil nil','Burst before its unlock: no cube')

print('partner_test ok')
