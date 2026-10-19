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
-- The partner HUD (UI-DESIGN 3.2, 4.3, D-UI5) on the Uplink kit (ui.lua), during a session (a friend linked or
-- rejoining, or coop loopback). Her card at the top left: her name in teal, then her HP, shield, Beta and Burst rows by
-- the player cluster's rules above, and one line for her state: DOWN in red (life 3 to 5, or no HP), elsewhere and her
-- map, connection lost, or a dash when the native part has had no vitals from her for 3 s (it drops them then); the
-- last two grey the card out, her last values kept. Otherwise that line holds the ping and her map (card_details). Over
-- her ghost's head, her marker: name, a row of HP dots, a shield line, and the distance past 15 m; when she is out of
-- view or behind, an arrow on the screen's edge instead, turned towards her, with the distance and three HP pips; grey
-- and kept at her last place while her link is lost. The gauges tween over 150 ms; DOWN and a lost link sound the
-- alert once. Each part has its setting (partner_bar, partner_arrow, partner_card, card_details), read at each update,
-- so the menu's change applies at once; while the marker carries her name, her ghost's name tag hides (marking()).
-- Each 250 ms (slow): the session, her state, name and vitals from the link's last read (an unread status changes
-- nothing). Each frame (tick): at most 30 updates a second, and then only the gauges while they tween and the marker or
-- arrow while she has an anchor: one projection through the kit, its views' setters touching the engine on change only.
-- No engine call here: the kit makes them.
local T=require('ui_text')
local clean=require('chat').clean
local RATE,TWEEN,GREY,NAME=1/30,0.15,0.45,20 -- s between updates; s a tween; a greyed card's opacity; characters shown.
local MW,MH,AW,AH,AC=320,110,160,180,80 -- Marker and arrow sizes in layout units; the arrow's diamond centre in it.
local TWEENED={'hp','shield','beta','burst'}
-- o: {kit=ui.kit's, link= (chatting, friend, mate, ping), puppet= (anchor, her_map, me), settings= (main.lua's: the
-- menu changes them in place), theme=ui.THEME}.
function P.hud(o)
    local kit,link,puppet,settings,theme=o.kit,o.link,o.puppet,o.settings,o.theme
    local self,words,picked,lang={},T.en.partner,nil,nil
    local session,lost,alert,vit,from,since=false,false,nil,nil,nil,nil
    local now,due,was_on,last_at,last_feet=0,0,false,nil,nil
    kit.add('card',{x=96,y=96,w=860,h=200},function(b)
        b.panel(0,0,860,200)
        local v={name=b.text(24,16,'','name',theme.teal),info=b.text(540,22,'','status',theme.grey)}
        for _,l in ipairs({{'HP',24,72},{'SH',24,118},{'BE',24,154},{'BU',440,154}}) do
            b.text(l[2],l[3],l[1],'label',theme.text)
        end
        v.hp,v.sh=b.hp(96,68,40,3,'big'),b.shield(96,124,'small')
        v.be,v.bu=b.cubes(96,156,8,theme.beta),b.cubes(500,156,8,theme.burst)
        return v
    end)
    -- Scaled from its bottom centre, on her head.
    kit.add('marker',{x=0,y=0,w=MW,h=MH,pivot={X=0.5,Y=1}},function(b)
        return {name=b.text(10,0,'','hint',theme.teal),hp=b.hp(10,46,30,1,'small'),shield=b.bar(10,62,300,6,theme.teal),
            far=b.text(10,72,'','num')}
    end)
    -- The chevron turns around the diamond, at the group's (80, 80): the point on the edge.
    kit.add('arrow',{x=0,y=0,w=AW,h=AH,pivot={X=0.5,Y=AC/AH}},function(b)
        return {chevron=b.image(64,16,32,32,'chevron',theme.teal,{X=0.5,Y=2}),
            diamond=b.image(64,64,32,32,'diamond',theme.teal),far=b.text(52,116,'','num'),
            pips=b.dots(65,160,3,1,'small')}
    end)
    -- A tweened value as drawn now.
    local function at_now(k)
        if not since then return vit[k] end
        return from[k]+(vit[k]-from[k])*math.min(1,(now-since)/TWEEN)
    end
    local function gauges()
        if not vit then return end
        local hp,sh=at_now('hp'),at_now('shield')
        local c,m,a=kit.view('card'),kit.view('marker'),kit.view('arrow')
        if c then
            c.hp.set(hp,vit.max_hp)
            c.sh.set(sh,vit.max_shield,vit.blocks)
            c.be.set(at_now('beta'),vit.max_beta)
            c.bu.set(at_now('burst'),vit.max_burst)
        end
        if m then
            m.hp.set(hp,vit.max_hp)
            m.shield.set(vit.max_shield>0 and sh/vit.max_shield or 0)
        end
        if a then a.pips.set(P.hp_columns(hp,vit.max_hp,3)) end
    end
    -- Her name as shown: cleaned like a chat line (a Steam name may hold anything), at most 20 characters.
    local function shown_name(name)
        name=clean(name or '')
        if name=='' then return words.partner end
        if utf8.len(name)>NAME then name=name:sub(1,utf8.offset(name,NAME+1)-1)..'…' end
        return name
    end
    function self.slow()
        local on=link.chatting()
        if on==nil then return end
        session=on
        local c=kit.view('card')
        if c and (c~=picked or settings.ui_language~=lang) then -- At each build of the root: the language may change.
            picked,lang=c,settings.ui_language
            words=T.pick(kit.language(),lang).partner
        end
        local friend,_,is_lost=link.friend()
        local new=session and link.mate() or nil
        lost=session and is_lost==true
        if not session then vit,since,last_at,last_feet=nil,nil,nil,nil end
        if new and vit then
            for _,k in ipairs(TWEENED) do
                if new[k]~=vit[k] then
                    local f={}
                    for _,key in ipairs(TWEENED) do f[key]=at_now(key) end
                    from,since=f,now
                    break
                end
            end
        end
        vit=new or vit
        local mine=puppet.me()
        local where,map=P.where(mine and mine.map,puppet.her_map())
        local info,color,grey,state='',theme.grey,false,nil
        if lost then info,grey,state=words.lost,true,'lost'
        elseif not new then info,grey='—',true
        elseif new.life>=3 and new.life<=5 or new.hp==0 and new.max_hp>0 then
            info,color,state=words.down,theme.error,'down'
        elseif where=='elsewhere' then info=words.elsewhere:format(map)
        elseif settings.card_details~=false then
            local ping,parts=link.ping(),{}
            if ping then parts[1]=string.format('%d ms',ping) end
            parts[#parts+1]=map
            info=table.concat(parts,' · ')
        end
        if session and state and state~=alert then kit.sound('alert') end
        alert=session and state or nil
        local name=shown_name(friend)
        kit.show('card',session and settings.partner_card~=false)
        kit.fade('card',grey and GREY or 1)
        if c then
            c.name.set(name)
            c.info.set(info)
            c.info.color(color)
        end
        local m,a=kit.view('marker'),kit.view('arrow')
        if m then
            m.name.set(name)
            m.name.color(lost and theme.grey or theme.teal)
        end
        if a then
            a.chevron.tint(lost and theme.grey or theme.teal)
            a.diamond.tint(lost and theme.grey or theme.teal)
        end
        gauges()
    end
    local function hide() kit.show('marker',false); kit.show('arrow',false) end
    -- The marker on her head or the arrow on the edge, from her anchor (her last, while her link is lost).
    local function place()
        local bar,arrow=session and settings.partner_bar~=false,session and settings.partner_arrow~=false
        local at,feet=puppet.anchor()
        if at then last_at,last_feet=at,feet elseif not lost then last_at,last_feet=nil,nil end
        at,feet=at or last_at,feet or last_feet
        local m,a=kit.view('marker'),kit.view('arrow')
        local v=(bar or arrow) and at and m and a and kit.project(at,now)
        if not v then return hide() end
        local on,x,y,angle=P.place(v,was_on)
        was_on=on
        local me=puppet.me()
        local far=me and P.distance(me.at,feet,on) or ''
        if on and bar then
            kit.show('arrow',false)
            kit.move('marker',x-MW/2,y-MH)
            m.far.set(far)
            kit.show('marker',true)
        elseif not on and arrow then
            kit.show('marker',false)
            kit.move('arrow',math.max(0,math.min(v.width-AW,x-AC)),math.max(0,math.min(v.height-AH,y-AC)))
            a.chevron.turn(angle+90) -- Its art points up.
            a.far.set(far)
            kit.show('arrow',true)
        else hide() end
    end
    -- Each frame with the 1 ms loop's clock (os.clock, as the kit's tweens).
    function self.tick(t)
        now=t
        if t<due then return end
        due=t+RATE
        if since then
            gauges()
            if t-since>=TWEEN then since=nil end
        end
        place()
    end
    -- Whether the marker carries her name now: the ghost's name tag hides then.
    function self.marking() return session and settings.partner_bar~=false and kit.ready() end
    return self
end
return P
