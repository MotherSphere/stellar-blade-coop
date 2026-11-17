-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The parked bike's rules, no engine call: whether her feet reach it for a mount, where it is from her camera when they
-- do not, where a mount puts her so the part lands on it, which spot a dismount parks at, how far her capsule is from
-- the bike's and when the bike turns solid. tests/lua/bike/park_test.lua covers it with lua5.4 alone.
-- A place is {map=<package path>, at={X,Y,Z}, rot={Pitch,Yaw,Roll}}: the bike's root (her feet while she rides) and
-- its heading, in centimetres and degrees, as the game's. UE's yaw grows from +X toward +Y.
local P={}
-- A mount reaches the bike from any side: at most 200 cm across from her feet to its root, 100 cm up or down.
P.REACH,P.RISE=200,100
-- The bike's body: the capsule of its physics asset (on Bn_AdamV_Sub, radius 82.9, 576 cm end to end) as a radius
-- around a segment on the bike's X axis. Its height: past 200 cm up or down her capsule never meets it. Once open,
-- the bike turns solid again only when she is 20 cm clear of it.
P.BODY,P.AXIS,P.TALL,P.LEAVE=83,{-97,314},200,20
-- An angle within (-180, 180].
local function norm(a) return 180-(180-a)%360 end
function P.reach(feet,place)
    local dx,dy,dz=place.at.X-feet.X,place.at.Y-feet.Y,place.at.Z-feet.Z
    return dx*dx+dy*dy<=P.REACH*P.REACH and math.abs(dz)<=P.RISE
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
-- A map's name for the screen: its travel world's alias (session/travel.lua's WORLDS), else the path's last part.
function P.map_name(map,worlds)
    for alias,path in pairs(worlds or {}) do if path==map then return alias end end
    return map:match('[^/]+$') or map
end
return P
