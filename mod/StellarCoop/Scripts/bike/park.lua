-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The parked bike's rules, no engine call: whether her feet reach it for a mount, where it is from her camera when they
-- do not, where a mount puts her so the part lands on it, which spot a dismount parks at, how far her capsule is from
-- the bike's, when the bike turns solid, its record per account and save (coop-bike-<steamid>-<saves><index>.txt) and
-- its line on the link (park or none).
-- tests/lua/bike/park_test.lua covers it with lua5.4 alone.
-- A place is {map=<package path>, at={X,Y,Z}, rot={Pitch,Yaw,Roll}}: the bike's root (her feet while she rides) and
-- its heading, in centimetres and degrees, as the game's. UE's yaw grows from +X toward +Y.
local P={}
-- A mount reaches the bike from any side: her capsule at most 50 cm from its body (P.clear), her feet 100 cm up or
-- down from its root. Its body is solid, so a reach from the root would leave her out of reach at its nose and tail.
P.REACH,P.RISE=50,100
-- The bike's body: the capsule of its physics asset (on Bn_AdamV_Sub, radius 82.9, 576 cm end to end) as a radius
-- around a segment on the bike's X axis. Its height: past 200 cm up or down her capsule never meets it. Once open,
-- the bike turns solid again only when she is 20 cm clear of it.
P.BODY,P.AXIS,P.TALL,P.LEAVE=83,{-97,314},200,20
-- An angle within (-180, 180].
local function norm(a) return 180-(180-a)%360 end
function P.reach(feet,place,radius)
    return math.abs(place.at.Z-feet.Z)<=P.RISE and P.clear(place,feet,radius)<=P.REACH
end
-- Whole metres of the 3D distance, rounded (out of reach is over 100 cm, so a refusal says 1 m or more), then the
-- quarter it lies in from her camera's yaw. Straight above or below it lies ahead.
function P.where(feet,yaw,place)
    local dx,dy,dz=place.at.X-feet.X,place.at.Y-feet.Y,place.at.Z-feet.Z
    local metres=math.floor(math.sqrt(dx*dx+dy*dy+dz*dz)/100+0.5)
    local a=(dx==0 and dy==0) and 0 or norm(math.deg(math.atan(dy,dx))-yaw)
    local word=math.abs(a)<=45 and 'ahead' or math.abs(a)>=135 and 'behind' or a>0 and 'right' or 'left'
    return metres,word
end
-- Where her actor goes for a mount: her offset to the part, turned by the change of yaw (X and Y only), taken from the
-- parked root, so the part lands on it with the parked heading.
function P.seat(actor_at,actor_yaw,part_at,part_yaw,place)
    local turn=norm(place.rot.Yaw-part_yaw)
    local c,s=math.cos(math.rad(turn)),math.sin(math.rad(turn))
    local ox,oy,oz=part_at.X-actor_at.X,part_at.Y-actor_at.Y,part_at.Z-actor_at.Z
    return {X=place.at.X-(ox*c-oy*s),Y=place.at.Y-(ox*s+oy*c),Z=place.at.Z-oz},norm(actor_yaw+turn)
end
-- A dismount parks where she is when that is a place, else at the last ground pose of the ride, else where the bike
-- stood before the mount.
function P.spot(live,ground,before)
    if live then return live,'here' end
    if ground then return ground,'last ground' end
    if before then return before,'before the mount' end
end
-- Centimetres between her capsule and the bike's (below 0: she is inside it). Her feet go into the bike's frame by its
-- yaw alone.
function P.clear(place,feet,radius)
    local dx,dy,dz=feet.X-place.at.X,feet.Y-place.at.Y,feet.Z-place.at.Z
    if math.abs(dz)>P.TALL then return math.huge end
    local c,s=math.cos(math.rad(place.rot.Yaw)),math.sin(math.rad(place.rot.Yaw))
    local x,y=dx*c+dy*s,dy*c-dx*s
    local ax=math.max(P.AXIS[1],math.min(P.AXIS[2],x))
    return math.sqrt((x-ax)^2+y*y)-P.BODY-radius
end
-- Open while she is inside it (a blocking overlap would shove her out sideways), solid again once she is LEAVE clear.
-- A bike that appears beside her, never inside, is solid at once. k is the caller's table for one actor.
function P.solid(k,clear)
    if clear<0 then k.open=true elseif clear>P.LEAVE then k.open=nil end
    return not k.open
end
-- A map's name for the screen: its travel world's alias (core/worlds.lua), else the path's last part.
function P.map_name(map,worlds)
    for alias,path in pairs(worlds or {}) do if path==map then return alias end end
    return map:match('[^/]+$') or map
end
-- A number as text with a dot whatever the locale (coop-bike.txt's and the record's).
function P.number(v) return (string.format('%.9g',v):gsub(',','.')) end
-- The record's file for this account and save, from the status text: the mod= line's SteamID, the slot= line's index
-- while its verdict is coop or main, its saves= word. nil while any of them does not read (the title, a load, an
-- unpinned build, saves=off, the Steam link not ready).
function P.key(status)
    local raw='\n'..(status or '')
    local slot,index,saves=raw:match('\nslot=(%a+) index=(%d) marker=%S+ saves=(%a+)')
    local id=raw:match('\nmod=[^\r\n]* steamid=([1-9]%d*)')
    if not (id and (slot=='coop' or slot=='main') and (saves=='coop' or saves=='main')) then return nil end
    return ('coop-bike-%s-%s%s.txt'):format(id,saves,index)
end
-- The record's line (version 1, no newline): the map, then X Y Z, Pitch Yaw Roll, tab-separated.
function P.line(place)
    local at,rot=place.at,place.rot
    return table.concat({'1',place.map,P.number(at.X),P.number(at.Y),P.number(at.Z),P.number(rot.Pitch),
        P.number(rot.Yaw),P.number(rot.Roll)},'\t')
end
-- A place from the record's text, else nil and why: none (no file) or unreadable (not version 1, a map the wire would
-- refuse, a field missing or not a number, a position past 10,000,000 cm or an angle past 360 degrees).
function P.read(text)
    if text==nil then return nil,'none' end
    local f={}
    for field in (text:match('^[^\r\n]*')..'\t'):gmatch('([^\t]*)\t') do f[#f+1]=field end
    local map=f[2] or ''
    if #f~=8 or f[1]~='1' or #map>128 or not map:find('^/[a-z0-9_/%-]*$') then return nil,'unreadable' end
    local n={}
    for k=3,8 do
        n[k]=tonumber(f[k])
        -- NaN fails the comparison too.
        if not (n[k] and math.abs(n[k])<=(k<=5 and 1e7 or 360)) then return nil,'unreadable' end
    end
    return {map=map,at={X=n[3],Y=n[4],Z=n[5]},rot={Pitch=n[6],Yaw=n[7],Roll=n[8]}}
end
-- The link's bike line from a place (native/src/link/protocol.h's bike_ok): "park <map> <x> <y> <z> <pitch> <yaw>
-- <roll>" in whole centimetres and hundredths of a degree within (-180, 180]; "none" without a place or for one the
-- line cannot carry.
function P.wire(place)
    if not place then return 'none' end
    local at,rot=place.at,place.rot
    -- math.floor gives an integer when it fits; NaN or a huge value stays a float the check below refuses.
    local function whole(v) return tostring(math.floor(v+0.5)) end
    local function cents(a) return whole(norm(a)*100) end
    local line=table.concat({'park',place.map,whole(at.X),whole(at.Y),whole(at.Z),cents(rot.Pitch),cents(rot.Yaw),
        cents(rot.Roll)},' ')
    return P.from_wire(line) and line or 'none'
end
-- A place from a member's bike line, as bike_ok() takes it; nil for none or a line it refuses.
function P.from_wire(payload)
    local f={}
    for field in ((payload or '')..' '):gmatch('([^ ]*) ') do f[#f+1]=field end
    if #f~=8 or f[1]~='park' or #f[2]>128 or not f[2]:find('^/[a-z0-9_/%-]*$') then return nil end
    local n={}
    for k=3,8 do
        n[k]=f[k]:find('^%-?%d+$') and tonumber(f[k])
        if not (n[k] and math.abs(n[k])<=(k<=5 and 1e7 or 36000)) then return nil end
    end
    return {map=f[2],at={X=n[3],Y=n[4],Z=n[5]},rot={Pitch=n[6]/100,Yaw=n[7]/100,Roll=n[8]/100}}
end
return P
