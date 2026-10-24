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
    -- Behind: her depth pulls the arrow down, so straight behind stays at the bottom whatever the pitch or a small side
    -- or height offset; far above or to the side still wins.
    local x,y,a=P.edge(r,u+math.min(f,0),W,H,P.OFF)
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
local Chat=require('session.chat')
local T=require('ui.text')
-- The status strip's column budgets (Chat.wrap's columns) over the 712 units between its 16-unit margins: Mideum 28
-- (its second row) about 18*28/34 units a column, as the feed's Mideum 34 is 18; Mideum 30 (its top row) about
-- 18*30/34, less 9 columns kept for the ping at the right end ('9999 ms' and a gap) when it shows.
P.ROW,P.COLS=44,48
P.TOP=P.ROW-9
-- Text within cols columns: whole when it fits, else cut at Chat.wrap's first break one column earlier, with an
-- ellipsis; never after a Thai leading vowel (U+0E40 to U+0E44), which belongs to the syllable after it.
local function cut(text,cols)
    if Chat.wrap(text,cols)[1]==text then return text end
    return Chat.wrap(text,cols-1)[1]:gsub('\xE0\xB9[\x80-\x84]$','')..'…'
end
-- The status line's words for the strip, for link.summary: each without summary.none's prefix (up to its colon and
-- the spaces after it: 'Co-op: ', '協力プレイ：'), and no paused or lost end, which the strip puts first in words of
-- its own.
function P.short(words)
    local w,s=words.summary,{}
    local prefix=w.none:match('^(.-：)') or w.none:match('^(.-:%s*)') or ''
    for k in pairs(T.en.summary) do s[k]=w[k]:sub(1,#prefix)==prefix and w[k]:sub(#prefix+1) or w[k] end
    s.paused,s.lost='',''
    return {summary=s}
end
-- The status strip's rows (status_overlay, s.mode: 'off', 'compact' or 'detailed') from s={summary=the status line
-- in P.short(words) (link.summary), lost=true while her link is lost, paused=true while her photo mode pauses our
-- game, ping=ms or nil, fight=, pilot=, quests= (link's lines, or nil), rate=send_rate}: the top row (connection lost,
-- paused, then the summary, joined by ' · '; only the summary cut), the ping ('118 ms'; '' before the first pong and
-- while lost, as the native part keeps the last one then), and in detailed the facts that hold, joined by ' · ': the
-- shared enemies while the fight runs (the host's enemies=, the guest's pairs=), the same-place enemies while they
-- run, shared quests on, and the poses sent a second always. The top row takes the ping's 9 columns when there is
-- none. nil when off, out of a session (summary.none) or before Steam (waiting).
function P.status_rows(words,s)
    local w=P.short(words).summary
    if s.mode~='compact' and s.mode~='detailed' or s.summary==w.none or s.summary==w.waiting then return nil end
    local second
    if s.mode=='detailed' then
        local o,facts,fight,quests=words.overlay,{},s.fight or '',s.quests or ''
        local n=fight:find('^fight=on ') and (fight:match(' enemies=(%d+)') or fight:match(' pairs=(%d+)'))
        if n then facts[#facts+1]=o.enemies:format(tonumber(n)) end
        n=(s.pilot or ''):match('^pilot=on piloted=(%d+)')
        if n then facts[#facts+1]=o.place:format(tonumber(n)) end
        if quests:find('^quests=on ') then facts[#facts+1]=o.quests end
        facts[#facts+1]=o.rate:format(s.rate)
        second=cut(table.concat(facts,' · '),P.COLS)
    end
    local lead={}
    if s.lost then lead[1]=words.partner.lost end
    if s.paused then lead[#lead+1]=words.overlay.paused end
    local right=not s.lost and s.ping and string.format('%d ms',s.ping) or ''
    local room=right=='' and P.ROW or P.TOP
    if not lead[1] then return cut(s.summary,room),right,second end
    local first=table.concat(lead,' · ')..' · ' -- Whole: only the status line after it is cut (3 columns at least).
    return first..cut(s.summary,math.max(3,room-Chat.columns(first))),right,second
end
-- The partner HUD (UI-DESIGN 3.2, 4.3, D-UI5) on the Uplink kit (ui/kit.lua), during a session (a friend linked or
-- rejoining, or coop loopback). Her card at the top left: her name in teal, then her HP, shield and Beta rows stacked
-- under it by the player cluster's rules above, and at the right end of her name's line her state: DOWN in red (life 3
-- to 5, or no HP), elsewhere and her map, connection lost, or a dash when the native part has had no vitals from her
-- for 3 s (it drops them then); the last two grey the card out, her last values kept. Otherwise that line holds the
-- ping and her map (card_details). Over her ghost's head, her marker: name, a row of HP dots, a shield line, and the
-- distance past 15 m; when she is out of view or behind, an arrow on the screen's edge instead, turned towards her,
-- with the distance and three HP pips; grey and kept at her last place on your map while nothing comes from her (her
-- link lost, or no vitals: her ghost hides a second after her last pose, her link is lost only after 10 s). The kit
-- keeps all three on screen at any resolution and ui_scale. Each gauge moves over 300 ms from where it is drawn to her
-- latest value, a bit longer than the 250 ms between two reads of her vitals, so it neither jumps nor stops between
-- them; empty until her first vitals; DOWN and a lost link sound the alert once. All three hide while the game is
-- paused or on one of its screens (UI-DESIGN 7.4). Each part has its setting (partner_bar, partner_arrow, partner_card,
-- card_details), read at each update, so the menu's change applies at once; while the marker carries her name, her
-- ghost's name tag hides (marking()). Each 250 ms (slow): the session, her state, name and vitals from the link's last
-- read (an unread status changes nothing), and the marker or arrow placed at once on a new root (never drawn at its
-- corner). Each frame (tick): the gauges while they move and the marker or arrow while she has an anchor, so it follows
-- the camera at the game's frame rate: one projection through the kit, its views' setters touching the engine on change
-- only. No engine call here: the kit makes them.
local clean=Chat.clean
local TWEEN,GREY,NAME=0.3,0.45,20 -- s a gauge moves; a greyed card's opacity; characters shown.
local MW,MH,AW,AH,AC=320,120,160,180,80 -- Marker and arrow sizes in layout units; the arrow's diamond centre in it.
-- The card in layout units: its place (under it from y 330, the feed), its size, where its rows start (after their
-- labels' column), its name's line, and each row's label, top and height (HP: 3 rows of 15-unit dots; SH: 2 of 10;
-- BE: 30-unit cubes). Rows 9 units apart and 6 from the rails keep it short: the open chat's first line (330 + 32 per
-- scale) stays clear of it up to ui_scale=124.
local CX,CY,CW,CH,ROW_X,NAME_Y=96,96,744,220,120,46
-- The status strip: from the screen's top to 4 units above the card, its top band (the status line, the ping) and the
-- band under it (detailed only); never scaled past what keeps it there (100 %): past it, it would cover the card.
local SY,SH,BAND,PAD=8,84,46,16
local MOST=(CY-4-SY)/SH
local HP_ROW,SH_ROW,BE_ROW={'HP',79,45},{'SH',133,20},{'BE',162,30}
local MID,RIGHT={X=0,Y=0.5},{X=1,Y=0.5} -- A text centred on its line, from its left or its right end.
local TWEENED={'hp','shield','beta'}
-- o: {kit=ui.kit's, link= (chatting, friend, mate, ping, summary, paused, fight, pilot, quests), puppet= (anchor,
-- her_map, me), settings= (main.lua's: the menu changes them in place), theme=ui.THEME}.
function P.hud(o)
    local kit,link,puppet,settings,theme=o.kit,o.link,o.puppet,o.settings,o.theme
    local self,all,words,picked,lang={},T.en,T.en.partner,nil,nil
    local session,quiet,away,where,alert,vit,from,since=false,false,false,nil,nil,nil,nil,nil
    local now,was_on,last_at,last_feet=0,false,nil,nil
    kit.add('card',{x=CX,y=CY,w=CW,h=CH,inside=true},function(b)
        b.panel(0,0,CW,CH)
        local v={name=b.text(24,NAME_Y,'','name',theme.teal,MID),info=b.text(CW-24,NAME_Y,'','status',theme.grey,RIGHT)}
        for _,row in ipairs({HP_ROW,SH_ROW,BE_ROW}) do b.text(24,row[2]+row[3]/2,row[1],'label',theme.text,MID) end
        v.hp,v.sh=b.hp(ROW_X,HP_ROW[2],40,3,'big'),b.shield(ROW_X,SH_ROW[2],'small')
        v.be=b.cubes(ROW_X,BE_ROW[2],8,theme.beta)
        return v
    end)
    -- With status_overlay on, the status strip above her card (status_rows), while the status line shows one (hosting
    -- alone included), hidden as the card is; its setting read at each slow too. Flat glass (no rails: two rows fill
    -- it). Not inside: the kit's 48-unit margin would push it onto the card. Added before the marker and the arrow,
    -- which draw over it. Its top row red while her link is lost.
    kit.add('status',{x=CX,y=SY,w=CW,h=SH,most=MOST},function(b)
        b.image(0,0,CW,BAND,nil,theme.panel)
        return {more=b.image(0,BAND,CW,SH-BAND,nil,theme.panel),top=b.text(PAD,BAND/2,'','status',theme.text,MID),
            right=b.text(CW-PAD,BAND/2,'','status',theme.grey,RIGHT),
            second=b.text(PAD,(BAND+SH)/2,'','head',theme.grey,MID)}
    end)
    -- Scaled from its bottom centre, on her head.
    kit.add('marker',{x=0,y=0,w=MW,h=MH,pivot={X=0.5,Y=1},inside=true},function(b)
        return {name=b.text(10,22,'','hint',theme.teal,MID),hp=b.hp(10,50,30,1,'small'),
            shield=b.bar(10,66,300,6,theme.teal),far=b.text(10,96,'','num',nil,MID)}
    end)
    -- The chevron turns around the diamond, at the group's (80, 80): the point on the edge.
    kit.add('arrow',{x=0,y=0,w=AW,h=AH,pivot={X=0.5,Y=AC/AH},inside=true},function(b)
        return {chevron=b.image(64,16,32,32,'chevron',theme.teal,{X=0.5,Y=2}),
            diamond=b.image(64,64,32,32,'diamond',theme.teal),far=b.text(52,116,'','num'),
            pips=b.dots(65,160,3,1,'small')}
    end)
    -- Before her first vitals (a new session): every gauge empty, never the last partner's.
    local NONE={hp=0,max_hp=0,shield=0,max_shield=0,blocks=0,beta=0,max_beta=0}
    -- A gauge's value as drawn now.
    local function at_now(k)
        if not since then return (vit or NONE)[k] end
        return from[k]+(vit[k]-from[k])*math.min(1,(now-since)/TWEEN)
    end
    local function gauges()
        local v=vit or NONE
        local hp,sh=at_now('hp'),at_now('shield')
        local c,m,a=kit.view('card'),kit.view('marker'),kit.view('arrow')
        if c then
            c.hp.set(hp,v.max_hp)
            c.sh.set(sh,v.max_shield,v.blocks)
            c.be.set(at_now('beta'),v.max_beta)
        end
        if m then
            m.hp.set(hp,v.max_hp)
            m.shield.set(v.max_shield>0 and sh/v.max_shield or 0)
        end
        if a then a.pips.set(P.hp_columns(hp,v.max_hp,3)) end
    end
    -- Her name as shown: cleaned like a chat line (a Steam name may hold anything), at most 20 characters.
    local function shown_name(name)
        name=clean(name or '')
        if name=='' then return words.partner end
        if utf8.len(name)>NAME then name=name:sub(1,utf8.offset(name,NAME+1)-1)..'…' end
        return name
    end
    local function hide() kit.show('marker',false); kit.show('arrow',false) end
    -- The marker on her head or the arrow on the edge, from her anchor; while nothing comes from her, from her last
    -- place, forgotten once she is back or on another map than yours (yours changed: those numbers are another map's).
    local function place()
        local bar=session and not away and settings.partner_bar~=false
        local arrow=session and not away and settings.partner_arrow~=false
        local at,feet=puppet.anchor()
        if at then last_at,last_feet=at,feet elseif not quiet or where=='elsewhere' then last_at,last_feet=nil,nil end
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
            kit.move('arrow',x-AC,y-AC)
            a.chevron.turn(angle+90) -- Its art points up.
            a.far.set(far)
            kit.show('arrow',true)
        else hide() end
    end
    function self.slow()
        local on=link.chatting()
        if on==nil then return end
        session=on
        local c=kit.view('card')
        local rebuilt=c and c~=picked
        if c and (rebuilt or settings.ui_language~=lang) then -- At each build of the root: the language may change.
            picked,lang=c,settings.ui_language
            all=T.pick(kit.language(),lang)
            words=all.partner
        end
        local friend,_,is_lost=link.friend()
        local top,right,second=P.status_rows(all,{mode=settings.status_overlay,summary=link.summary(P.short(all)),
            lost=is_lost==true,paused=link.paused(),ping=link.ping(),fight=link.fight(),pilot=link.pilot(),
            quests=link.quests(),rate=settings.send_rate})
        local new=session and link.mate() or nil
        local lost=session and is_lost==true
        quiet=session and (lost or not new) -- Her link lost, or no vitals from her for 3 s (none yet included).
        away=(session or top~=nil) and kit.paused()
        local st=kit.view('status')
        if st and top then
            st.top.set(top)
            st.top.color(is_lost==true and theme.error or theme.text)
            st.right.set(right)
            st.second.set(second or '')
            st.more.show(second~=nil)
        end
        kit.show('status',top~=nil and not away)
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
        local map
        where,map=P.where(mine and mine.map,puppet.her_map())
        local info,color,grey,state='',theme.grey,false,nil
        -- Her death and revive state (glue/tick/revive.inc): down or spectating shows as DOWN even while her vitals
        -- still read (her game keeps her at 1 HP), which is the state a revive ends.
        local rev=link.revive and link.revive()
        local her_down=session and rev and (rev.partner=='down' or rev.partner=='spectating')
        if lost then info,grey,state=words.lost,true,'lost'
        elseif not new then info,grey='—',true
        elseif her_down or new.life>=3 and new.life<=5 or new.hp==0 and new.max_hp>0 then
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
        kit.show('card',session and not away and settings.partner_card~=false)
        kit.move('card',CX,CY) -- The kit keeps it on screen for this viewport and ui_scale.
        kit.fade('card',grey and GREY or 1)
        if c then
            c.name.set(name)
            c.info.set(info)
            c.info.color(color)
        end
        local m,a=kit.view('marker'),kit.view('arrow')
        local tint=quiet and theme.grey or theme.teal
        if m then
            m.name.set(name)
            m.name.color(tint)
        end
        if a then
            a.chevron.tint(tint)
            a.diamond.tint(tint)
        end
        gauges()
        if rebuilt then place() end -- A new root shows a shown marker or arrow at its corner: placed before it draws.
    end
    -- Each frame with the 1 ms loop's clock (os.clock, as the kit's tweens).
    function self.tick(t)
        now=t
        if since then
            if t-since>=TWEEN then since=nil end -- Done: drawn at her values themselves.
            gauges()
        end
        place()
    end
    -- Whether the marker carries her name now: the ghost's name tag hides then.
    function self.marking() return session and settings.partner_bar~=false and kit.ready() end
    return self
end
return P
