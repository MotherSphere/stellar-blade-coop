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


-- The partner HUD (P.hud) on a fake kit: the marker over her head (name, HP dots, shield line, the distance past
-- 15 m) placed from the kit's projection, the arrow on the edge (turned towards her, the distance, three HP pips,
-- whole on screen) with the hysteresis carried from one update to the next, at most 30 updates a second and no
-- projection while there is nothing to place; the top-left card by the player cluster's rules, its gauges tweened over
-- 150 ms; her states (DOWN, elsewhere, connection lost, no vitals: greyed), the alert sound on DOWN and on a lost link;
-- each part on its own setting, changed at once; the name tag left to the marker while it is up.
local T=require('ui_text')
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
    function b.panel() end
    function b.text(x,y,str,style,color)
        local e=element('text')
        e.v,e.c,e.x,e.y,e.style={str},color,x,y,style
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
    function link.mate() return link.vit end
    function link.ping() return link.ping_ms end
    link.ping_ms=118
    puppet={at=at(1000,0,220),feet=at(1000,0,0),map=E04B,me_v={at=at(0,0,0),map=E04B}}
    function puppet.anchor() if puppet.at then return puppet.at,puppet.feet end end
    function puppet.her_map() return puppet.map end
    function puppet.me() return puppet.me_v end
    settings={partner_bar=true,partner_arrow=true,partner_card=true,card_details=true,ui_language='game'}
    package.loaded.partner=nil
    P=require('partner')
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
-- Three groups: the card top left (under the feed: 96 to 296), the marker scaled from its bottom centre (her head),
-- the arrow from its diamond; none shown before the first slow.
assert(groups.card.place.x==96 and groups.card.place.y==96 and groups.card.place.y+groups.card.place.h<=330)
assert(groups.marker.place.pivot.X==0.5 and groups.marker.place.pivot.Y==1 and groups.arrow.place.pivot.X==0.5)
assert(not groups.card.place.shown and not groups.marker.place.shown and not groups.arrow.place.shown)
assert(not groups.card.place.hit and not groups.marker.place.hit,'Hit tests pass through the HUD')
-- The card: her name in teal, the ping and her map in grey, her gauges by the player cluster's rules at once (the
-- first values are not tweened): HP 40 columns by 3 rows of the big dots, the shield's blocks, Beta and Burst cubes
-- (8 at most each).
hud.slow()
frame()
assert(shown.card==true and faded.card==1)
local card=texts('card')
assert(card[1].v[1]=='Kaanta' and card[1].c=='teal' and card[1].style=='name')
local info=card[2]
assert(info.v[1]=='118 ms · e04' and info.c=='grey',info.v[1])
local hp,sh,be,bu=by('card','hp'),by('card','shield'),by('card','cubes',1),by('card','cubes',2)
assert(hp.args[1]==40 and hp.args[2]==3 and hp.args[3]=='big' and sh.args[1]=='small' and be.args[1]==8
    and bu.args[1]==8)
assert(hp.v[1]==500 and hp.v[2]==1000 and sh.v[1]==150 and sh.v[2]==300 and sh.v[3]==3 and be.v[1]==450
    and be.v[2]==1000 and bu.v[1]==0 and bu.v[2]==0)
for _,label in ipairs({'HP','SH','BE','BU'}) do
    local found=false
    for _,e in ipairs(card) do found=found or e.v[1]==label end
    assert(found,label)
end
-- The marker: her anchor 10 m ahead and 2.2 m up, 90 degrees of view: 1920 units a unit of up over forward. Its
-- bottom centre on her head, her name in teal, 30 small dots of HP, the shield line, no distance within 15 m.
local m=texts('marker')
assert(shown.marker==true and shown.arrow~=true)
assert(math.abs(moved.marker[1]-(1920-160))<1e-6 and math.abs(moved.marker[2]-(1080-0.22*1920-110))<1e-6,
    moved.marker[1]..' '..moved.marker[2])
assert(m[1].v[1]=='Kaanta' and m[1].c=='teal' and m[2].v[1]=='')
local mhp,line=by('marker','hp'),by('marker','bar')
assert(mhp.args[1]==30 and mhp.args[2]==1 and mhp.args[3]=='small' and mhp.v[1]==500 and mhp.v[2]==1000)
assert(line.v[1]==0.5,'Shield 150 of 300')
-- At most 30 updates a second: one projection a 1/30 s, none in between.
local p=projects
frame(0.01); frame(0.01)
assert(projects==p,'Not yet')
frame(0.02)
assert(projects==p+1)
-- 20 m away: the distance shows on the marker.
puppet.at,puppet.feet=at(2000,0,220),at(2000,0,0)
frame()
assert(m[2].v[1]=='20 m' and shown.marker)
-- Behind her: the arrow at the bottom centre, turned down (its art points up), the distance and three HP pips; the
-- whole arrow on screen, its diamond 80 units into its group.
puppet.at,puppet.feet=at(-1000,0,0),at(-1000,0,0)
frame()
assert(shown.arrow==true and shown.marker==false)
assert(moved.arrow[1]==W/2-80 and moved.arrow[2]==H-180,moved.arrow[1]..' '..moved.arrow[2])
local chevron,diamond,pips=by('arrow','image',1),by('arrow','image',2),by('arrow','dots')
assert(chevron.args[3]=='chevron' and diamond.args[3]=='diamond' and chevron.args[5].Y==2,'It turns around the diamond')
assert(math.abs(chevron.angle%360-180)<1e-6 and chevron.c=='teal' and diamond.c=='teal')
assert(pips.args[1]==3 and pips.v[1]==2,'Half her HP: two pips of three')
assert(texts('arrow')[1].v[1]=='10 m','On the arrow, any distance')
-- To her right: right edge, middle, pointing right.
puppet.at=at(1000,5000,0)
frame()
assert(moved.arrow[1]==W-160 and moved.arrow[2]==H/2-80 and math.abs(chevron.angle-90)<1e-6)
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
assert(moved.marker[1]==700-160 and moved.marker[2]==800-110)
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

-- The gauges tween over 150 ms on the card and the marker: halfway at 75 ms, there at 150.
link.vit=vitals({hp=1000,shield=300})
hud.slow()
frame(0.075)
assert(math.abs(hp.v[1]-750)<1e-6 and math.abs(mhp.v[1]-750)<1e-6 and math.abs(sh.v[1]-225)<1e-6,hp.v[1])
frame(0.075)
assert(hp.v[1]==1000 and sh.v[1]==300 and line.v[1]==1)
local calls=hp.calls
frame(); frame()
assert(hp.calls==calls,'Done: no more sets')

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
assert(shown.arrow and moved.arrow[2]==H-180)
link.lost=false
hud.slow(); frame()
assert(not shown.arrow and not shown.marker,'Back: no anchor until her next pose')
assert(info.v[1]=='118 ms · e04' and faded.card==1)
puppet.at=at(1000,0,220)
frame(0.2) -- The tween from 0 HP done.
local kept=hp.v[1]
assert(kept==500)
link.vit=nil
hud.slow(); frame()
assert(info.v[1]=='—' and info.c=='grey' and faded.card<1 and hp.v[1]==kept,'Greyed, her last values kept')
link.vit=vitals()
hud.slow(); frame(0.2)
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
-- Out of a session: everything hidden; the status unread (nil): nothing changes.
link.session=false
hud.slow(); frame()
assert(shown.card==false and not shown.marker and not shown.arrow)
link.session=nil
hud.slow()
assert(shown.card==false)
link.session=true
hud.slow(); frame()
assert(shown.card==true)

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

print('partner_test ok')
