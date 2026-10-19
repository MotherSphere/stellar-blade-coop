-- The partner marker's maths (UI-DESIGN 4.3), no engine call: where her marker goes on screen, or the arrow on the
-- screen's edge that points at her when she is off screen or behind you, the distance it shows, and whether she is on
-- your map. Screen positions are in the caller's units (the layout's, 3840 wide at 16:9), y down. Locations and
-- rotations are UE4SS's ({X,Y,Z} in cm, {Pitch,Yaw} in degrees; camera roll taken as 0).
local P={}
P.OFF,P.ON=48,72 -- Units from an edge: the marker turns into the arrow inside OFF, and back only ON inside.
-- at as seen from a camera at c turned r: forward, right, up (UE: X forward, Y right, Z up).
function P.camera_space(c,r,at)
    local p,y=math.rad(r.Pitch),math.rad(r.Yaw)
    local cp,sp,cy,sy=math.cos(p),math.sin(p),math.cos(y),math.sin(y)
    local dx,dy,dz=at.X-c.X,at.Y-c.Y,at.Z-c.Z
    return dx*cp*cy+dy*cp*sy+dz*sp,-dx*sy+dy*cy,-dx*sp*cy-dy*sp*sy+dz*cp
end
-- The arrow on a W by H screen, m in from the edge, towards (right, up): x, y and its angle in degrees (the art
-- points right at 0; screen y down). Straight behind or under: bottom centre.
function P.edge(right,up,W,H,m)
    local a=(right==0 and up==0) and math.pi/2 or math.atan(-up,right)
    local ca,sa=math.cos(a),math.sin(a)
    local t=math.min((W/2-m)/math.max(math.abs(ca),1e-6),(H/2-m)/math.max(math.abs(sa),1e-6))
    return W/2+ca*t,H/2+sa*t,math.deg(a)
end
-- v: {camera, rotation, fov (horizontal, degrees), anchor (above her head), width, height, screen={x,y} or nil (the
-- engine's projection of the anchor, when it gave one)}. was_on: whether the marker showed last time. Returns true, x,
-- y for the marker, or false, x, y, angle for the arrow.
function P.place(v,was_on)
    local f,r,u=P.camera_space(v.camera,v.rotation,v.anchor)
    local W,H=v.width,v.height
    if f>1 then -- In front, past the camera's nose.
        local x,y
        if v.screen then x,y=v.screen.x,v.screen.y else
            local k=W/2/math.tan(math.rad(v.fov)/2)
            x,y=W/2+r/f*k,H/2-u/f*k
        end
        local m=was_on and P.OFF or P.ON
        if x>=m and x<=W-m and y>=m and y<=H-m then return true,x,y end
    end
    local x,y,a=P.edge(r,u,W,H,P.OFF)
    return false,x,y,a
end
-- The distance from you to her in whole metres ('42 m'), or nil on the marker at 15 m or less.
function P.distance(you,her,on)
    local m=math.floor(math.sqrt((her.X-you.X)^2+(her.Y-you.Y)^2+(her.Z-you.Z)^2)/100+0.5)
    if on and m<=15 then return nil end
    return string.format('%d m',m)
end
-- 'same' or 'elsewhere' and her map's short name ('e04'), from both maps' package paths; nil when hers is unknown.
function P.where(mine,hers)
    if not hers then return nil end
    return mine==hers and 'same' or 'elsewhere',hers:match('([^/]+)$')
end
return P
