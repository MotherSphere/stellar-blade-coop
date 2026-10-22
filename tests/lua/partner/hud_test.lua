-- The partner marker's maths: a point in camera space (UE: X forward, Y right, Z up; camera roll 0), the marker on
-- screen or an arrow on the screen's edge pointing at her (behind and straight above included), with hysteresis
-- between the two (off at 48 units from an edge, back at 72), the distance text, and whether she is on your map.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local P=require('partner.hud')
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
place(view(at(-1000,-500,0)),true,{false,W/2-(H/2-M)/2,H-M,math.deg(math.atan(1000,-500))}) -- Behind-left: bottom left.
-- Straight behind with her marker point above the camera (2.2 m over her feet): the bottom centre whatever the pitch,
-- and with a small side offset; never the top edge that the raw up would give.
for _,pitch in ipairs({0,3,10,-10,-15}) do
    place(view(at(-1000,0,50),{rotation={Pitch=pitch,Yaw=0}}),true,{false,W/2,H-M,90})
end
place(view(at(-1000,30,0)),true,{false,W/2+(H/2-M)*30/1000,H-M,math.deg(math.atan(1000,30))})
place(view(at(-1000,0,5000)),true,{false,W/2,M,-90}) -- Far above, behind: still the top.
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


-- The partner HUD (P.hud) on a fake kit: the marker over her head (name, HP dots, shield line, the distance past
-- 15 m) placed from the kit's projection, the arrow on the edge (turned towards her, the distance, three HP pips) with
-- the hysteresis carried from one update to the next, all three kept inside the screen by the kit, every frame and no
-- projection while there is nothing to place; the top-left card (her name, then her HP, SH and BE rows, all inside its
-- panel) by the player cluster's rules, its gauges moving over 300 ms from where they are drawn to her latest value;
-- her states (DOWN, elsewhere, connection lost, no vitals: greyed), the alert sound on DOWN and on a lost link;
-- each part on its own setting, changed at once; the name tag left to the marker while it is up.
local T=require('ui.text')
local THEME={text='text',grey='grey',teal='teal',error='error',white='white',dim='dim',beta='beta',burst='burst'}
local kit,groups,shown,moved,faded,sounds,projects,ready,language
local function element(kind)
    local e={kind=kind,on=true,calls=0}
    function e.set(...) e.calls=e.calls+1; e.v={...} end
    function e.color(c) e.c=c end
    function e.show(on) e.on=on end
    function e.tint(c) e.c=c end
    function e.turn(a) e.angle=a end
    return e
end
local function builder(g)
    local b={}
    function b.panel(...) g.panel={...} end
    function b.text(x,y,str,style,color,align)
        local e=element('text')
        e.v,e.c,e.x,e.y,e.style,e.align={str},color,x,y,style,align or {X=0,Y=0}
        g[#g+1]=e
        return e
    end
    for _,kind in ipairs({'image','dots','hp','shield','cubes','bar'}) do
        b[kind]=function(x,y,...) local e=element(kind); e.x,e.y,e.args=x,y,{...}; g[#g+1]=e; return e end
    end
    return b
end
local view_of={}
local function new_kit()
    groups,shown,moved,faded,sounds,projects,ready,language={},{},{},{},{},0,true,'en-US'
    kit={}
    function kit.add(name,place,build)
        groups[name]={place=place,build=build}
        view_of[name]=build(builder(groups[name]))
    end
    function kit.view(name) return ready and view_of[name] or nil end
    function kit.ready() return ready end
    function kit.show(name,on) shown[name]=on==true end
    function kit.move(name,x,y) moved[name]={x,y} end
    function kit.fade(name,a) faded[name]=a end
    function kit.sound(name) sounds[#sounds+1]=name end
    function kit.language() return language end
    kit.away,kit.paused_reads=false,0
    function kit.paused() kit.paused_reads=kit.paused_reads+1; return kit.away end
    -- The kit's projection: the field of view's (90 degrees) from the camera, in layout units.
    kit.camera,kit.rotation={X=0,Y=0,Z=0},{Pitch=0,Yaw=0}
    function kit.project(anchor)
        projects=projects+1
        if kit.blind then return nil end
        return {camera=kit.camera,rotation=kit.rotation,fov=90,anchor=anchor,width=W,height=H,screen=kit.screen}
    end
    return kit
end
local E04B,B07B='/game/art/bg/worldmap/level_p/e04','/game/art/bg/worldmap/level_p/b07'
local link,puppet,settings,hud,now
local function vitals(o)
    local v={hp=500,max_hp=1000,shield=150,max_shield=300,blocks=3,beta=450,max_beta=1000,burst=0,max_burst=0,tachy=0,
        max_tachy=0,life=1}
    for k,value in pairs(o or {}) do v[k]=value end
    return v
end
local function setup()
    new_kit()
    link={session=true,name='Kaanta',linked=true,lost=false,vit=vitals(),ping=118}
    function link.chatting() return link.session end
    function link.friend() if link.name then return link.name,link.linked,link.lost end end
    function link.paused() return link.paused_v==true end
    function link.mate() return link.vit end
    function link.ping() return link.ping_ms end
    link.ping_ms=118
    -- The status line in the words given (link.summary), and the fight, same-place and quests lines (nil: none).
    link.summary_k='hosting'
    function link.summary(w)
        local text=w.summary[link.summary_k]
        return text:find('%%s') and text:format(link.name) or text
    end
    function link.fight() return link.fight_line end
    function link.pilot() return link.pilot_line end
    function link.quests() return link.quests_line end
    puppet={at=at(1000,0,220),feet=at(1000,0,0),map=E04B,me_v={at=at(0,0,0),map=E04B}}
    function puppet.anchor() if puppet.at then return puppet.at,puppet.feet end end
    function puppet.her_map() return puppet.map end
    function puppet.me() return puppet.me_v end
    settings={partner_bar=true,partner_arrow=true,partner_card=true,card_details=true,ui_language='game',send_rate=60}
    package.loaded['partner.hud']=nil
    P=require('partner.hud')
    hud=P.hud({kit=kit,link=link,puppet=puppet,settings=settings,theme=THEME})
    now=100
end
local function by(g,kind,n) -- The n-th element of a kind in a group's view.
    local k=0
    for _,e in ipairs(groups[g]) do if e.kind==kind then k=k+1; if k==(n or 1) then return e end end end
end
local function texts(g)
    local out={}
    for _,e in ipairs(groups[g]) do if e.kind=='text' then out[#out+1]=e end end
    return out
end
local function frame(dt) now=now+(dt or 0.034); hud.tick(now) end
setup()
-- Three groups: the card top left (above the feed: 96 to 316, the feed from 330), the marker scaled from its bottom
-- centre (her head), the arrow from its diamond; none shown before the first slow. Both scale from their top left: the
-- open chat's first line (330 + 32 a scale unit) clears the card up to ui_scale=124.
assert(groups.card.place.x==96 and groups.card.place.y==96 and groups.card.place.y+groups.card.place.h<=330)
local function card_clear(s) return 96+groups.card.place.h*s<=330+32*s end
assert(card_clear(1.24),groups.card.place.h)
assert(groups.marker.place.pivot.X==0.5 and groups.marker.place.pivot.Y==1 and groups.arrow.place.pivot.X==0.5)
assert(not groups.card.place.shown and not groups.marker.place.shown and not groups.arrow.place.shown)
assert(not groups.card.place.hit and not groups.marker.place.hit,'Hit tests pass through the HUD')
assert(groups.card.place.inside and groups.marker.place.inside and groups.arrow.place.inside,
    'The kit keeps all three inside the screen')
-- The card: her name in teal, the ping and her map in grey, her gauges by the player cluster's rules at once (the
-- first values are not tweened): HP 40 columns by 3 rows of the big dots, the shield's blocks, Beta cubes (8 at
-- most); no Burst row.
hud.slow()
frame()
assert(shown.card==true and faded.card==1 and moved.card[1]==96 and moved.card[2]==96,'Moved: the kit keeps it inside')
local card=texts('card')
assert(card[1].v[1]=='Kaanta' and card[1].c=='teal' and card[1].style=='name')
local info=card[2]
assert(info.v[1]=='118 ms · e04' and info.c=='grey',info.v[1])
local hp,sh,be=by('card','hp'),by('card','shield'),by('card','cubes',1)
assert(hp.args[1]==40 and hp.args[2]==3 and hp.args[3]=='big' and sh.args[1]=='small' and be.args[1]==8)
assert(by('card','cubes',2)==nil,'No Burst row')
assert(hp.v[1]==500 and hp.v[2]==1000 and sh.v[1]==150 and sh.v[2]==300 and sh.v[3]==3 and be.v[1]==450
    and be.v[2]==1000)
-- Her name, then exactly three rows stacked under it: HP, SH, BE, each label centred on its row in a column of its
-- own; all inside the panel, 24 units from its sides and clear of its dotted rails (22 units from its top and bottom
-- edges). Her state sits at the right end of her name's line. A font's line is 4/3 units a point.
local panel=groups.card.panel
assert(panel[1]==0 and panel[2]==0 and panel[3]==groups.card.place.w and panel[4]==groups.card.place.h)
local labels={}
for _,e in ipairs(card) do if e.style=='label' then labels[#labels+1]=e end end
assert(#labels==3 and labels[1].v[1]=='HP' and labels[2].v[1]=='SH' and labels[3].v[1]=='BE')
assert(card[1].align.Y==0.5 and card[1].y-36*2/3>=22 and info.align.X==1 and info.align.Y==0.5
    and info.x==panel[3]-24 and info.y==card[1].y)
local bottom=card[1].y+36*2/3
for i,row in ipairs({{hp,40*15,3*15},{sh,59*10,2*10},{be,7*41+30,30}}) do
    local e,w,h=row[1],row[2],row[3]
    assert(e.y>=bottom+8 and e.x>=labels[i].x+80 and e.x+w<=panel[3]-24,i)
    assert(labels[i].x>=24 and labels[i].align.Y==0.5 and math.abs(labels[i].y-(e.y+h/2))<1e-9,i)
    bottom=e.y+h
end
assert(bottom<=panel[4]-22-6,'Clear of the bottom rail')
-- The marker: her anchor 10 m ahead and 2.2 m up, 90 degrees of view: 1920 units a unit of up over forward. Its
-- bottom centre on her head, her name in teal, 30 small dots of HP, the shield line, no distance within 15 m.
local m=texts('marker')
assert(shown.marker==true and shown.arrow~=true)
local MH=groups.marker.place.h
assert(math.abs(moved.marker[1]-(1920-160))<1e-6 and math.abs(moved.marker[2]-(1080-0.22*1920-MH))<1e-6,
    moved.marker[1]..' '..moved.marker[2])
assert(m[1].v[1]=='Kaanta' and m[1].c=='teal' and m[2].v[1]=='')
local mhp,line=by('marker','hp'),by('marker','bar')
assert(mhp.args[1]==30 and mhp.args[2]==1 and mhp.args[3]=='small' and mhp.v[1]==500 and mhp.v[2]==1000)
assert(line.v[1]==0.5,'Shield 150 of 300')
-- Its texts centred on their lines, inside its box: the name on top, the distance under the shield line.
assert(m[1].align.Y==0.5 and m[1].y-30*2/3>=0 and m[2].align.Y==0.5 and m[2].y-30*2/3>=line.y+line.args[2]
    and m[2].y+30*2/3<=MH)
-- Every frame: one projection each, so the marker follows the camera at the game's frame rate.
local p=projects
frame(0.008); frame(0.008)
assert(projects==p+2)
-- 20 m away: the distance shows on the marker.
puppet.at,puppet.feet=at(2000,0,220),at(2000,0,0)
frame()
assert(m[2].v[1]=='20 m' and shown.marker)
-- Behind her: the arrow at the bottom centre, turned down (its art points up), the distance and three HP pips; its
-- diamond, 80 units into its group, on the edge's point (the kit keeps the whole arrow on screen).
puppet.at,puppet.feet=at(-1000,0,0),at(-1000,0,0)
frame()
assert(shown.arrow==true and shown.marker==false)
assert(moved.arrow[1]==W/2-80 and moved.arrow[2]==H-48-80,moved.arrow[1]..' '..moved.arrow[2])
local chevron,diamond,pips=by('arrow','image',1),by('arrow','image',2),by('arrow','dots')
assert(chevron.args[3]=='chevron' and diamond.args[3]=='diamond' and chevron.args[5].Y==2,'It turns around the diamond')
assert(math.abs(chevron.angle%360-180)<1e-6 and chevron.c=='teal' and diamond.c=='teal')
assert(pips.args[1]==3 and pips.v[1]==2,'Half her HP: two pips of three')
assert(texts('arrow')[1].v[1]=='10 m','On the arrow, any distance')
-- To her right: right edge, middle, pointing right.
puppet.at=at(1000,5000,0)
frame()
assert(moved.arrow[1]==W-48-80 and moved.arrow[2]==H/2-80 and math.abs(chevron.angle-90)<1e-6)
-- The hysteresis carries over: the marker 60 units from the left edge stays one, then at 40 is the arrow, which turns
-- back into the marker only 72 units in.
local function x_at(x) puppet.at=at(1920,x-1920,0); frame() end
x_at(1920); assert(shown.marker)
x_at(60); assert(shown.marker and not shown.arrow)
x_at(40); assert(shown.arrow and not shown.marker)
x_at(60); assert(shown.arrow,'Not back before 72')
x_at(120); assert(shown.marker)
-- The engine's own projection, when the kit has one, places the marker.
kit.screen={x=700,y=800}
frame()
assert(moved.marker[1]==700-160 and moved.marker[2]==800-MH)
kit.screen=nil
-- No anchor (her ghost hidden: no pose for a second, another map) and her link fine: nothing, no projection.
puppet.at=nil
p=projects
frame()
assert(not shown.marker and not shown.arrow and projects==p)
-- The kit cannot project (a map loads): both hidden.
puppet.at=at(1000,0,220)
kit.blind=true
frame()
assert(not shown.marker and not shown.arrow)
kit.blind=false
frame()
assert(shown.marker)

-- The gauges move over 300 ms on the card and the marker, a bit longer than the 250 ms between two reads of her
-- vitals: halfway at 150 ms, there at 300, set each frame meanwhile.
link.vit=vitals({hp=1000,shield=300})
hud.slow()
local calls=hp.calls
frame(0.15)
assert(math.abs(hp.v[1]-750)<1e-6 and math.abs(mhp.v[1]-750)<1e-6 and math.abs(sh.v[1]-225)<1e-6,hp.v[1])
frame(0.15)
assert(hp.v[1]==1000 and sh.v[1]==300 and line.v[1]==1 and hp.calls==calls+2)
calls=hp.calls
frame(); frame()
assert(hp.calls==calls,'Done: no more sets')
-- A value that comes while one moves: from where the gauge is drawn, so it goes on without a jump or a stop.
link.vit=vitals({hp=600,shield=300})
hud.slow(); frame(0.15)
assert(math.abs(hp.v[1]-800)<1e-6,hp.v[1])
link.vit=vitals({hp=200,shield=300})
hud.slow()
assert(math.abs(hp.v[1]-800)<1e-6,'No jump')
frame(0.15)
assert(math.abs(hp.v[1]-500)<1e-6,hp.v[1])
link.vit=vitals({hp=1000,shield=300})
hud.slow(); frame(0.31)
assert(hp.v[1]==1000,hp.v[1])

-- Her states, on the card's info: DOWN in red (life 3 to 5, or 0 HP), with the alert once; another map, with its
-- name; the link lost (grey, the card faded, the arrow grey at her last place even once her ghost hides, the alert);
-- no vitals (the native part drops them 3 s after her last: faded, a dash, her last values kept).
link.vit=vitals({life=4,hp=10})
hud.slow(); frame()
assert(info.v[1]=='DOWN' and info.c=='error' and faded.card==1 and sounds[#sounds]=='alert' and #sounds==1)
hud.slow(); frame()
assert(#sounds==1,'Once')
link.vit=vitals({hp=0})
hud.slow(); frame()
assert(info.v[1]=='DOWN' and #sounds==1,'0 HP is down too; still down: no new alert')
link.vit=vitals()
puppet.map=B07B
hud.slow(); frame()
assert(info.v[1]=='elsewhere · b07' and info.c=='grey' and faded.card==1)
puppet.map=E04B
link.lost=true
puppet.at=at(-1000,0,0)
hud.slow(); frame()
assert(info.v[1]=='connection lost' and info.c=='grey' and faded.card<1 and #sounds==2 and sounds[2]=='alert')
assert(shown.arrow and chevron.c=='grey' and diamond.c=='grey')
puppet.at=nil -- Her ghost hides with no poses: the arrow stays at her last place.
frame()
assert(shown.arrow and moved.arrow[2]==H-48-80)
link.lost=false
hud.slow(); frame()
assert(not shown.arrow and not shown.marker,'Back: no anchor until her next pose')
assert(info.v[1]=='118 ms · e04' and faded.card==1)
puppet.at=at(1000,0,220)
frame(0.3) -- The tween from 0 HP done.
local kept=hp.v[1]
assert(kept==500)
link.vit=nil
hud.slow(); frame()
assert(info.v[1]=='—' and info.c=='grey' and faded.card<1 and hp.v[1]==kept,'Greyed, her last values kept')
-- Nothing from her, her link not lost yet (the native part drops her vitals at 3 s, her ghost hides a second after her
-- last pose, the link is lost only at 10 s): the arrow stays grey at her last place.
puppet.at=at(-1000,0,0)
frame()
assert(shown.arrow and chevron.c=='grey' and diamond.c=='grey' and m[1].c=='grey')
local kept_at={moved.arrow[1],moved.arrow[2]}
puppet.at=nil
frame(); frame()
assert(shown.arrow and moved.arrow[1]==kept_at[1] and moved.arrow[2]==kept_at[2],'Kept at her last place')
-- Your map changes meanwhile (a camp's teleport): her last place is another map's, forgotten.
puppet.me_v.map=B07B
hud.slow(); frame()
assert(not shown.arrow and not shown.marker,'Her last place was on your old map')
puppet.me_v.map=E04B
hud.slow(); frame()
assert(not shown.arrow,'Forgotten for good')
puppet.at=at(1000,0,220)
link.vit=vitals()
hud.slow(); frame(0.3)
assert(faded.card==1 and info.v[1]=='118 ms · e04')
-- No ping yet: the map alone; card_details off: nothing there in a normal state.
link.ping_ms=nil
hud.slow(); frame()
assert(info.v[1]=='e04')
settings.card_details=false
hud.slow(); frame()
assert(info.v[1]=='')
settings.card_details=true

-- Each part on its own setting, at once: partner_card, partner_bar (the marker; the name tag is then the ghost's),
-- partner_arrow.
assert(hud.marking()==true,'The marker carries her name: the ghost hides its tag')
settings.partner_card=false
hud.slow()
assert(shown.card==false)
settings.partner_card=true
hud.slow()
assert(shown.card==true)
settings.partner_bar=false
frame()
assert(not shown.marker and hud.marking()==false)
puppet.at=at(-1000,0,0)
frame()
assert(shown.arrow)
settings.partner_arrow=false
frame()
assert(not shown.arrow)
p=projects
frame()
assert(projects==p,'Neither wanted: no projection')
settings.partner_bar,settings.partner_arrow=true,true
ready=false
assert(hud.marking()==false,'No root: the name tag is the fallback')
frame()
assert(projects==p,'No view: no projection either')
ready=true
-- The game paused or on one of its screens (UI-DESIGN 7.4): the card, marker and arrow hide; back on resume.
puppet.at=at(1000,0,220)
hud.slow(); frame()
assert(shown.card and shown.marker)
kit.away=true
hud.slow(); frame()
assert(shown.card==false and not shown.marker and not shown.arrow,'Paused: hidden')
puppet.at=at(-1000,0,0)
p=projects
frame()
assert(not shown.arrow and projects==p,'Paused: no arrow, no projection')
kit.away=false
hud.slow(); frame()
assert(shown.card and shown.arrow,'Resumed')
-- Out of a session: everything hidden, the pause not read; the status unread (nil): nothing changes.
link.session=false
local reads=kit.paused_reads
hud.slow(); frame()
assert(shown.card==false and not shown.marker and not shown.arrow and kit.paused_reads==reads)
link.session=nil
hud.slow()
assert(shown.card==false)
link.session,link.vit=true,nil
hud.slow(); frame()
assert(shown.card==true and info.v[1]=='—')
assert(hp.v[1]==0 and hp.v[2]==0 and sh.v[2]==0 and be.v[2]==0 and mhp.v[1]==0 and line.v[1]==0
    and pips.v[1]==0,'A new session: empty, not the last partner\'s gauges')
link.vit=vitals()
hud.slow(); frame(0.3)
assert(hp.v[1]==500 and info.v[1]=='e04')
-- A new root (the look in, or the root out of the viewport) keeps a shown arrow shown: placed and turned in the same
-- slow, before it ever draws at its corner.
puppet.at=at(-1000,0,0)
frame()
assert(shown.arrow)
local before={}
for _,name in ipairs({'card','marker','arrow'}) do before[name],view_of[name]=view_of[name],groups[name].build(builder({})) end
moved={}
p=projects
hud.slow()
assert(projects==p+1 and moved.arrow[1]==W/2-80 and moved.arrow[2]==H-48-80,'Placed at once')
assert(math.abs(view_of.arrow.chevron.angle%360-180)<1e-6,'Turned at once')
for name,v in pairs(before) do view_of[name]=v end
puppet.at=at(1000,0,220)

-- Her name as it shows: cleaned (no controls), at most 20 characters, then an ellipsis; in loopback, 'Partner'.
link.name='A\1B'..string.rep('é',30)
hud.slow(); frame()
assert(card[1].v[1]=='AB'..string.rep('é',18)..'…' and m[1].v[1]==card[1].v[1],card[1].v[1])
link.name=nil
hud.slow(); frame()
assert(card[1].v[1]=='Partner')
-- In French (the game's language), from the next build of the root on (a new view).
language='fr-FR'
local g2={}
view_of.card=groups.card.build(builder(g2))
link.vit=vitals({life=3})
hud.slow()
assert(g2[2].v[1]==T.fr.partner.down and g2[1].v[1]==T.fr.partner.partner,g2[2].v[1])
-- The words come from ui_text, both languages complete.
for k in pairs(T.en.partner) do assert(T.fr.partner[k],k) end
for _,k in ipairs({'partner_bar','partner_arrow','partner_card','card_details'}) do
    assert(T.en.row[k] and T.fr.row[k],k)
end
assert(T.fr.partner.down~=T.en.partner.down)

-- The status strip's rows (status_overlay): nothing when off (or unset), out of a session (the status line says none)
-- or before Steam (waiting); compact: the status line and the ping ('' before the first pong); detailed: a second row
-- of the facts that hold, in this order: shared enemies while the fight runs (the host's enemies=, the guest's pairs=;
-- not while it waits, nor its probe, which pairs none), same-place enemies while they run, shared quests on, and the
-- poses sent a second always. The status line comes in the strip's words (P.short: no 'Co-op: ', no paused or lost
-- end); a lost link and her photo pause come first in words of their own, and a lost link drops the ping (the native
-- part keeps the last one). Each row cut to its columns with an ellipsis, the ellipsis included, never after a Thai
-- leading vowel; the top row takes the ping's columns when there is none.
local E,O=T.en,T.en.overlay
local S=P.short(E).summary
assert(S.hosting=='hosting %s.' and S.rejoin=="rejoining your friend's game (try %s/3)." and S.paused=='' and S.lost==''
    and S.friend==E.summary.friend and P.short(T.ja).summary.none==T.ja.summary.none:gsub('^協力プレイ：',''))
local HOST='fight=on mode=on role=host enemies=3 claims=5 refused=0 kills=1 floored=0 scale=135/115 sim_us=4/9 '
    ..'threads=1/2/3'
local GUEST='fight=on mode=on role=guest pairs=2 claims=1 corrections=0 kills=0 floored=0 desync=0 unpaired=1 maxhp=0'
local function rows(o)
    local s={mode='detailed',summary=S.hosting:format('Kaanta'),ping=118,rate=60}
    for k,v in pairs(o) do s[k]=v end
    return P.status_rows(E,s)
end
local function facts(...) return table.concat({...},' · ') end
assert(rows({mode='off'})==nil and P.status_rows(E,{summary=S.alone,rate=60})==nil,'Off, or unset: nothing')
assert(rows({summary=S.none})==nil and rows({summary=S.waiting})==nil,'No session, no Steam yet')
for _,k in ipairs({'stopped','held','rejoin','alone','connecting','hosting','guest'}) do
    assert(rows({mode='compact',summary=S[k]}),k)
end
assert(rows({mode='compact',summary=S.alone})=='hosting, no friend yet.')
local top,right,second=rows({mode='compact'})
assert(top=='hosting Kaanta.' and right=='118 ms' and second==nil,top)
top,right,second=rows({mode='compact',ping=false})
assert(top=='hosting Kaanta.' and right=='' and second==nil,'No pong yet: no ping')
top,right=rows({mode='compact',lost=true})
assert(top=='connection lost · hosting Kaanta.' and right=='','Lost: said first, and no stale ping')
top,right=rows({mode='compact',paused=true})
assert(top=='paused · hosting Kaanta.' and right=='118 ms',top)
assert(rows({mode='compact',lost=true,paused=true})=='connection lost · paused · hosting Kaanta.')
top,right,second=rows({})
assert(top=='hosting Kaanta.' and right=='118 ms' and second==O.rate:format(60),'Nothing else holds: the rate')
assert(select(3,rows({fight=HOST}))==facts(O.enemies:format(3),O.rate:format(60)),'The host: enemies=')
assert(select(3,rows({fight=GUEST,rate=30}))==facts(O.enemies:format(2),O.rate:format(30)),'The guest: pairs=')
for _,line in ipairs({'fight=waiting mode=on why=friend','fight=off why=asked','fight=stopped why=fault',
        'fight=on mode=probe actors=40 eve=1 turn=2 turns_per_s=60 writes=off'}) do
    assert(select(3,rows({fight=line}))==O.rate:format(60),line)
end
assert(select(3,rows({pilot='pilot=on piloted=4 owned=1 drawn=3'}))==facts(O.place:format(4),O.rate:format(60)))
for _,line in ipairs({'pilot=off why=host','pilot=stopped','pilot=refused why=coop off'}) do
    assert(select(3,rows({pilot=line}))==O.rate:format(60),line)
end
assert(select(3,rows({quests='quests=on mode=on role=guest partner=on'}))==facts(O.quests,O.rate:format(60)))
for _,line in ipairs({'quests=off','quests=waiting mode=on why=save','quests=stopped'}) do
    assert(select(3,rows({quests=line}))==O.rate:format(60),line)
end
top,right,second=rows({fight=HOST,pilot='pilot=on piloted=2 owned=2 drawn=0',quests='quests=on mode=on role=host'})
assert(top=='hosting Kaanta.' and right=='118 ms'
    and second==facts(O.enemies:format(3),O.place:format(2),O.quests,O.rate:format(60)),second)
-- Cut: at the last space within its columns less one, else between two characters; the ellipsis within its columns;
-- never after a Thai leading vowel (it belongs to the syllable after it). A row that fits stays whole.
assert(rows({mode='compact',summary=S.hosting:format(('W'):rep(32))})=='hosting…')
assert(rows({mode='compact',summary=('x'):rep(P.TOP)})==('x'):rep(P.TOP),'Fits: whole')
assert(rows({mode='compact',summary=('x'):rep(80)})==('x'):rep(P.TOP-1)..'…')
assert(rows({mode='compact',summary=('x'):rep(80),ping=false})==('x'):rep(P.ROW-1)..'…','No ping: its columns too')
assert(rows({mode='compact',summary=S.hosting:format(('W'):rep(32)),lost=true})=='connection lost · hosting…')
assert(rows({mode='compact',summary=('ก'):rep(P.TOP-2)..'เปิด'})==('ก'):rep(P.TOP-2)..'…')
-- Only the status line is cut after the words put first, so a line with no space (Japanese) keeps what fits of it.
assert(P.status_rows(T.ja,{mode='compact',summary=P.short(T.ja).summary.held,lost=true,rate=60})
    ==T.ja.partner.lost..' · セーブのロード完了まで招待を保留…')
local long={summary=E.summary,partner=E.partner,
    overlay={enemies=('E'):rep(80)..' %d',place=O.place,quests=O.quests,rate=O.rate,paused=O.paused}}
second=select(3,P.status_rows(long,{mode='detailed',summary='Co-op',fight=HOST,rate=60}))
assert(second==('E'):rep(P.COLS-1)..'…',second)

-- The strip on the kit (P.hud): its group above the card, at the card's x and width, from y 8 to before the card's 96;
-- not kept inside the kit's 48-unit margin (that would push it onto the card); hit tests pass through. Its top band
-- holds the status line (status style) and the ping at the right end (grey); the band under it, detailed only, the
-- facts (head style, grey); both inside the group. The setting is read at each slow: off (unset) hidden, then compact,
-- detailed and off at once. Hidden while paused, out of a session or before Steam; shown while hosting alone (no chat
-- session yet: the pause read then).
setup()
local sp=groups.status.place
assert(sp.x==96 and sp.y==8 and sp.w==groups.card.place.w and sp.y+sp.h<96 and not sp.inside and not sp.hit
    and not sp.shown,sp.y+sp.h)
local st=view_of.status
local band,more=by('status','image',1),by('status','image',2)
assert(band.x==0 and band.y==0 and band.args[1]==sp.w and more.x==0 and more.y==band.args[2] and more.args[1]==sp.w
    and more.y+more.args[2]==sp.h)
assert(st.top.style=='status' and st.top.c=='text' and st.right.style=='status' and st.right.c=='grey'
    and st.right.align.X==1 and st.second.style=='head' and st.second.c=='grey' and st.second.x==st.top.x)
assert(st.top.align.Y==0.5 and st.top.y-30*2/3>=0 and st.top.y+30*2/3<=band.args[2] and st.right.y==st.top.y)
assert(st.second.align.Y==0.5 and st.second.y-28*2/3>=more.y and st.second.y+28*2/3<=sp.h)
-- Its rows' columns (Chat.wrap's) fit between its margins: Mideum 34 is about 18 units a column (the feed's), so Mideum
-- 30 and 28 about 18*30/34 and 18*28/34; the top row keeps 9 columns for the ping ('9999 ms' and a gap). Scaled at most
-- as far as it stays above the card (ui_scale past it would put it on the card).
local wide=st.right.x-st.top.x
assert(st.top.x>0 and st.right.x<sp.w and P.COLS*18*28/34<=wide and P.ROW*18*30/34<=wide and P.TOP==P.ROW-9,wide)
assert(sp.most==1 and sp.y+sp.h*sp.most<96,sp.most)
hud.slow()
assert(shown.status==false,'Off unless set')
settings.status_overlay='compact'
hud.slow()
assert(shown.status==true and st.top.v[1]=='hosting Kaanta.' and st.top.c=='text' and st.right.v[1]=='118 ms'
    and st.second.v[1]=='' and more.on==false)
-- Her link lost: said first in red, the ping gone; her photo pause said first too; both back at once.
link.lost=true
hud.slow()
assert(st.top.v[1]=='connection lost · hosting Kaanta.' and st.top.c=='error' and st.right.v[1]=='',st.top.v[1])
link.lost,link.paused_v=false,true
hud.slow()
assert(st.top.v[1]=='paused · hosting Kaanta.' and st.top.c=='text' and st.right.v[1]=='118 ms',st.top.v[1])
link.paused_v=false
hud.slow()
assert(st.top.v[1]=='hosting Kaanta.')
settings.status_overlay='detailed'
link.fight_line,link.pilot_line,link.quests_line=HOST,'pilot=on piloted=2 owned=2 drawn=0','quests=on mode=on role=host'
hud.slow()
assert(shown.status and more.on==true
    and st.second.v[1]==facts(O.enemies:format(3),O.place:format(2),O.quests,O.rate:format(60)),st.second.v[1])
settings.send_rate=30
hud.slow()
assert(st.second.v[1]:find(O.rate:format(30),1,true),'The rate as set now')
link.ping_ms=nil
hud.slow()
assert(st.right.v[1]=='')
kit.away=true
hud.slow()
assert(shown.status==false,'Paused, or a game screen')
kit.away=false
hud.slow()
assert(shown.status==true)
for _,k in ipairs({'none','waiting'}) do
    link.summary_k=k
    hud.slow()
    assert(shown.status==false,k)
end
link.session,link.summary_k=false,'alone' -- Hosting, nobody yet: no chat session, the card hidden.
local reads=kit.paused_reads
hud.slow()
assert(shown.status==true and shown.card==false and kit.paused_reads==reads+1 and st.top.v[1]==S.alone)
settings.status_overlay='compact'
hud.slow()
assert(shown.status==true and more.on==false and st.second.v[1]=='')
settings.status_overlay='off'
reads=kit.paused_reads
hud.slow()
assert(shown.status==false and kit.paused_reads==reads,'Off at once; out of a session, the pause not read')
-- In the game's language (French), from the next build of the root on: both rows in its words.
link.session,link.summary_k,settings.status_overlay,language=true,'hosting','detailed','fr-FR'
view_of.card=groups.card.build(builder({}))
hud.slow()
assert(st.top.v[1]==P.short(T.fr).summary.hosting:format('Kaanta') and st.top.v[1]=='vous hébergez Kaanta.'
    and st.second.v[1]==facts(T.fr.overlay.enemies:format(3),T.fr.overlay.place:format(2),T.fr.overlay.quests,
        T.fr.overlay.rate:format(30)),st.second.v[1])
link.lost=true
hud.slow()
assert(st.top.v[1]==T.fr.partner.lost..' · vous hébergez Kaanta.',st.top.v[1])

print('partner_test ok')
