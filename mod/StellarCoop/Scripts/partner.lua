-- The partner marker's maths (UI-DESIGN 4.3), no engine call: where her marker goes on screen, or the arrow on the
-- screen's edge that points at her when she is off screen or behind you, the distance it shows, whether she is on
-- your map, and her gauges by the player cluster's own rules (sb-layout.md 0). Screen positions are in the caller's
-- units (the layout's, 3840 wide at 16:9), y down. Locations and rotations are UE4SS's ({X,Y,Z} in cm, {Pitch,Yaw} in
-- degrees; camera roll taken as 0).
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
-- 'same' or 'elsewhere' and her map's short name ('e04'), from both maps' package paths; nil when hers is unknown, and
-- nil with her map's name while yours is (a load).
function P.where(mine,hers)
    if not hers then return nil end
    return mine and (mine==hers and 'same' or 'elsewhere') or nil,hers:match('([^/]+)$')
end
-- Her HP gauge: the lit columns of cols, by HP / MaxHP, rounded up so a sliver still shows one; 0 at 0 HP or with no
-- max.
function P.hp_columns(hp,max,cols)
    if not (max>0 and hp>0) then return 0 end
    return math.min(cols,math.ceil(hp/max*cols))
end
-- Shield block i: its lit columns of cols, or nil when it is not shown. Blocks shown: min(ShieldBlock, 5); points a
-- block: floor(MaxShield / ShieldBlock); every lit block full but the last, which fills by what is left; later ones dim.
function P.shield_block(i,shield,max,blocks,cols)
    if i>math.min(blocks,5) then return nil end
    local per=math.floor(max/blocks)
    local left=shield-(i-1)*per
    if per<=0 or left<=0 then return 0 end
    return math.min(cols,math.ceil(math.min(left,per)/per*cols))
end
-- Cube i of a Beta or Burst row: its lit quarters (0 to 4), or nil when it is not shown. One cube a 200 points of the
-- max, at most limit shown; full cubes: floor(value / 200); the next lights floor((value mod 200) / 50) quarters.
function P.cube(i,value,max,limit)
    if i>math.min(math.floor(max/200),limit) then return nil end
    local full=math.floor(value/200)
    if i<=full then return 4 end
    return i==full+1 and math.floor(value%200/50) or 0
end
return P
