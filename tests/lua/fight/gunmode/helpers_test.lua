-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's pure parts with lua5.4 alone: its settings lines, the polled keys' edges and taps, the crosshair point in
-- EVE's frame, the rifle's magazine (rounds, reloads, the HUD count, running dry, a refill), the one zone event gun
-- mode may fire, mode.lua's camera helpers, the rifle layer's clip paths and mesh records (overlay.lua) and the rifle
-- solver's quaternion math (ik.lua).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Config=require('fight.gunmode.config')
local Input=require('fight.gunmode.input')
local Aim=require('fight.gunmode.aim')
local Ammo=require('fight.gunmode.ammo')
local close=function(a,b,eps) return math.abs(a-b)<=(eps or 1e-6) end

-- 1. Settings, as main.lua reads coop-settings.txt (core/link.lua's parse_settings, M.settings): the defaults with
--    none (no native part); gun_mode and gun_key as SBO reads them; the test lines checked here, a bad value refused.
do
    local Link=require('core.link')
    local s,bad=Config.from(nil)
    assert(s.on and s.key.key=='F4' and s.key.name=='F4' and s.native and s.aim_key=='RightMouseButton'
        and not s.probe and not s.zoom_toggle and #bad==0)
    s,bad=Config.from(Link.parse_settings('\239\187\191GUN_KEY = Ctrl+f2\r\ngun_mode=off\r\ngun_mode=on\r\n'
        ..'gun_aim_key=LeftMouseButton\r\ngun_zoom=toggle\r\ngun_fire=own\r\ngun_upper=nikke\r\ngun_trace=on\r\n'))
    assert(s.on and s.key.key=='F2' and s.key.mod=='CONTROL' and s.aim_key=='LeftMouseButton' and s.zoom_toggle
        and not s.native and s.upper and s.trace and #bad==0)
    s,bad=Config.from(Link.parse_settings('gun_mode=off\ngun_key=none\n'))
    assert(not s.on and s.key.key==nil and s.key.name=='none' and #bad==0)
    s,bad=Config.from(Link.parse_settings('gun_zoom=sideways\ngun_upper=yes\ngun_fire=both\ngun_aim_key=Left Mouse\n'))
    assert(not s.zoom_toggle and not s.upper and s.native and s.aim_key=='RightMouseButton' and #bad==4,
        table.concat(bad,'|'))
end

-- 2. Keys: an edge on the press only; a tap is a short press, a hold is not.
do
    local st={}
    assert(Input.edge(st,true)==true and Input.edge(st,true)==false and Input.edge(st,false)==false)
    local t={}
    Input.tap(t,true,0,0.4); assert(Input.tap(t,false,0.2,0.4)==true)
    Input.tap(t,true,1,0.4); assert(Input.tap(t,false,1.9,0.4)==false)
end

-- 3. The crosshair point in EVE's yaw frame: forward, right, up.
do
    local f,r,u=Aim.local_offset({X=0,Y=100,Z=50},{X=0,Y=0,Z=0},90)
    assert(close(f,100) and close(r,0) and close(u,50))
end

-- 4. The magazine: a press fires at once, then one round per cool time in whole frames; empty -> a reload (no round
--    until it is done), the count jumping when the magazine goes in; lowered part-spent -> no reload (11-20);
--    spares spent -> no rounds (cool time 999) until a refill.
do
    assert(close(Ammo.step(0.045,1/60),0.05) and close(Ammo.step(0.01,1/60),1/60))
    assert(Ammo.lower_text(60,300,60)=='60 | 5' and Ammo.lower_text(12,250,60)=='12 | 5' and Ammo.lower_text(0,0,60)=='0 | 0')
    FindAllOf=function() return {} end
    local g={log=function() end,valid=function() return false end,try=function(f) local ok,r=pcall(f); if ok then return r end end}
    local cools,reloads={},{}
    local cfg={mag_size=10,spare_mags=2,reload_time=1,reload_delay=1,fire_interval=0.05,round_name='N',reload_text='R',
        empty_text='E',round_color={1,1,1},reload_color={1,0,0}}
    local a=Ammo.new(g,cfg,function(v) cools[#cools+1]=v end,function(on) reloads[#reloads+1]=on end)
    local t=0
    local function run(n,aim,fire) for _=1,n do a.tick(aim,fire,t); t=t+1/60 end end
    run(31,true,true)
    assert(a.left<1 and a.reload_until and reloads[1]==true and cools[1]==1.2)
    run(62,true,false)
    assert(a.left==10 and a.reserve==10 and not a.reload_until and reloads[2]==false and cools[2]==0.05)
    run(31,true,true); run(62,true,false)
    assert(a.left==10 and a.reserve==0)
    run(31,true,true)
    assert(a.left==0 and a.reserve==0 and cools[#cools]==999)
    a.refill()
    assert(a.left==10 and a.reserve==20 and cools[#cools]==0.05)
    run(1,true,false); run(1,true,true)
    run(120,false,false)
    assert(a.left==9 and a.reserve==20,'no reload when lowered (11-20): '..a.left..' '..a.reserve)
end

-- 4b. L4: the reticle's round slot in the menu's words (g.words: ui/text.lua's gun in the player's language): the
--     round's name, the reload word while it reloads, the empty word with no round left.
do
    local T=require('ui.text')
    local fr=T.fr.gun
    assert(fr.round and fr.reload and fr.empty,'T.fr.gun has round, reload and empty')
    local function block(leaf)
        local b={text='game',full='TextBlock /Engine/Transient.WB_MainHUD_C_0.WidgetTree.WB_Tps_Bullet3.WidgetTree.'..leaf,
            ColorAndOpacity={SpecifiedColor={R=1,G=1,B=1,A=1}}}
        function b.GetFullName(o) return o.full end
        function b.IsValid() return true end
        function b.SetText(o,t) o.text=t end
        function b.GetText(o) return {ToString=function() return o.text end} end
        function b.SetColorAndOpacity() end
        return b
    end
    local name,count=block('TextBlock_bullet_name'),block('TextBlock_ItemCount')
    FindAllOf=function(class) if class=='TextBlock' then return {name,count} end return {} end
    FText=function(t) return t end
    local asked=0 -- g.words calls: main/base.lua's words reads the game's language through the engine.
    local g={log=function() end,valid=function(o) return o~=nil and o:IsValid() end,
        try=function(f) local ok,r=pcall(f); if ok then return r end end,
        words=function() asked=asked+1; return fr end}
    function g.path(o) local f=g.valid(o) and o:GetFullName(); return f and f:match('^%S+ (.+)$') or nil end
    local cfg={mag_size=1,spare_mags=1,reload_time=1,reload_delay=1,fire_interval=0.05,round_color={1,1,1},
        reload_color={1,0,0}}
    local a=Ammo.new(g,cfg,function() end,function() end)
    local t=0
    local function run(n,aim,fire) for _=1,n do a.tick(aim,fire,t); t=t+1/60 end end
    run(1,true,false)
    assert(name.text==fr.round,tostring(name.text))
    run(1,true,true)
    assert(a.reload_until and name.text==fr.reload,tostring(name.text))
    run(70,true,false)
    run(1,true,true)
    assert(a.left==0 and a.reserve==0 and name.text==fr.empty,tostring(name.text))
    -- 73 ticks within a second of os.clock: the words were read once, not on each frame.
    assert(asked==1,'words read '..asked..' times')
    a.stop()
    assert(name.text=='game','the game\'s own text back')
    FindAllOf=function() return {} end
end

-- 4c. The reticle's round slot on the first frame of each aim: the game writes its own round's name when its aim
--     starts (11-21: the drone's round showed 0.2 s before NIKKE RAPID), here also on the aim's second frame. The
--     slot found at the first aim is kept. A block whose address another object took (a freed HUD) gets no write.
--     Only the reticle's slot is looked for: the bottom-left count keeps the game's text and no line says it was
--     not found (11-21).
do
    local T=require('ui.text')
    local en=T.en.gun
    local function block(full)
        local b={text='game',full=full,ColorAndOpacity={SpecifiedColor={R=1,G=1,B=1,A=1}},writes=0}
        function b.GetFullName(o) return o.full end
        function b.IsValid() return true end
        function b.SetText(o,t) o.text=t; o.writes=o.writes+1 end
        function b.GetText(o) return {ToString=function() return o.text end} end
        function b.SetColorAndOpacity() end
        return b
    end
    local hud='TextBlock /Engine/Transient.GameEngine_0:Instance_0.WB_MainHUD_Master_C_1.WidgetTree.'
    local name=block(hud..'WB_Tps_Bullet3.WidgetTree.TextBlock_bullet_name')
    local count=block(hud..'WB_Tps_Bullet3.WidgetTree.TextBlock_ItemCount')
    local lower=block(hud..'WB_MainHUD_Lower1Item.WidgetTree.WB_MainHUD_ItemSlotGeneral.WidgetTree.TextBlock_Item_Count')
    local walks=0
    FindAllOf=function(class) if class=='TextBlock' then walks=walks+1; return {lower,name,count} end return {} end
    FText=function(t) return t end
    local clock=10
    local real_clock=os.clock
    os.clock=function() return clock end
    local lines={}
    local g={log=function(m) lines[#lines+1]=m end,valid=function(o) return o~=nil and o:IsValid() end,
        try=function(f) local ok,r=pcall(f); if ok then return r end end,words=function() return en end}
    function g.path(o) local f=g.valid(o) and o:GetFullName(); return f and f:match('^%S+ (.+)$') or nil end
    local cfg={mag_size=30,spare_mags=2,reload_time=1,fire_interval=0.05,round_color={1,1,1},reload_color={1,0,0}}
    local a=Ammo.new(g,cfg,function() end,function() end)
    local function run(n,aim) for _=1,n do clock=clock+1/60; a.tick(aim,false,clock) end end
    run(5,true)
    assert(name.text==en.round and walks==1,'the first aim: '..tostring(name.text)..', '..walks..' walks')
    run(30,false)
    name.text='DRONE ROUND' -- The game's aim starts: its own round's name.
    run(1,true)
    assert(name.text==en.round,'the first frame of the next aim: '..tostring(name.text))
    name.text='DRONE ROUND' -- Written again by the game on the aim's second frame.
    run(1,true)
    assert(name.text==en.round,'the second frame of the aim: '..tostring(name.text))
    assert(walks==1,'the slot found at the first aim is kept: '..walks..' walks')
    assert(lower.text=='game' and lower.writes==0,'the bottom-left count keeps the game\'s text')
    for _,m in ipairs(lines) do assert(not m:find('bottom-left',1,true),'a bottom-left line: '..m) end
    -- A map change frees the HUD. A text block of another widget takes the name block's address: it passes IsValid.
    run(30,false)
    name.full='TextBlock /Engine/Transient.GameEngine_0:Instance_0.WB_Other_C_7.WidgetTree.TextBlock_Title'
    name.text,name.writes='Title',0
    clock=clock+1
    run(10,true)
    a.stop()
    assert(name.text=='Title' and name.writes==0,'no write to another object at the old address: '..name.writes)
    os.clock=real_clock
    FindAllOf=function() return {} end
end

-- 5. The one zone event gun mode may fire: kind 2 on the shot's row, also once arm() borrowed a spare NIKKE row in its
--    place. Never matchmaking's kinds 15, 16 or 19, another kind or another row.
do
    local GunMode=require('fight.gunmode.mode')
    local Data=require('fight.gunmode.data')
    local fire=Data.row('Fire')
    assert(GunMode.allowed(2,fire))
    for _,kind in ipairs({0,1,3,5,6,10,15,16,19}) do assert(not GunMode.allowed(kind,fire),kind) end
    assert(not GunMode.allowed(2,'MultiplayTest_ZoneE_059') and not GunMode.allowed(2,nil))
    Data.BORROWED.Fire[1]='Nikke_02_E_ActorEff_001'
    assert(GunMode.allowed(2,'Nikke_02_E_ActorEff_001') and not GunMode.allowed(2,fire))
    Data.BORROWED.Fire[1]=fire
end

-- 6. mode.lua's camera helpers: the point d along a camera's forward (the crosshair's trace runs from 0 to its range)
--    and the eased step of the zoom and the field of view.
do
    local GunMode=require('fight.gunmode.mode')
    local function at(p,x,y,z) return close(p.X,x,1e-9) and close(p.Y,y,1e-9) and close(p.Z,z,1e-9) end
    local o={X=10,Y=20,Z=30}
    assert(at(GunMode.ahead(o,{Pitch=0,Yaw=0,Roll=0},100),110,20,30))
    assert(at(GunMode.ahead(o,{Pitch=0,Yaw=90,Roll=0},100),10,120,30))
    assert(at(GunMode.ahead(o,{Pitch=90,Yaw=45,Roll=0},100),10,20,130))
    assert(at(GunMode.ahead(o,{Pitch=30,Yaw=180,Roll=0},0),10,20,30))
    local p=GunMode.ahead({X=0,Y=0,Z=0},{Pitch=-30,Yaw=0,Roll=0},200)
    assert(close(p.X,200*math.cos(math.rad(30))) and close(p.Z,-100))
    assert(GunMode.ease(0,10,0.25)==2.5 and GunMode.ease(4,4,0.5)==4 and GunMode.ease(66,45,1)==45
        and GunMode.ease(45,66,0)==45)
end

-- 7. overlay.lua's parts that need no engine: the rifle clips are object paths (<folder>/<name>.<name>). The meshes the layer
--    went on (records for coop-gun.txt, adopt from an earlier Lua load's records) keep the first class listed.
do
    local Overlay=require('fight.gunmode.overlay')
    for clip,path in pairs(Overlay.CLIPS) do
        local name,obj=path:match('^/Game/[%w_/]+/([%w_]+)%.([%w_]+)$')
        assert(name and obj==name,clip..': '..path)
    end
    assert(Overlay.CLASS:match('^/Game/Mods/NGM/ABP_NGM_Spike%.ABP_NGM_Spike_C$'))
    local g={log=function() end,try=function(f) local ok,r=pcall(f); if ok then return r end end}
    local layer=Overlay.new(g)
    assert(#layer.records()==0)
    layer.adopt('/Game/A/Body','/Game/A/PP_C')
    layer.adopt('/Game/A/Body','/Game/Other/PP_C') -- Listed already: its first class stays.
    layer.adopt('/Game/B/Body','')                 -- A body with no post-process class of its own.
    local got={}
    for _,r in ipairs(layer.records()) do assert(r[1]=='pp'); got[r[2]]=r[3] end
    assert(got['/Game/A/Body']=='/Game/A/PP_C' and got['/Game/B/Body']=='' and #layer.records()==2)
end

-- 7b. A rifle clip found once is kept while it is still that clip. After a map change another object may sit at its
--     freed address and pass IsValid: the clip is then looked up again by its path.
do
    local Overlay=require('fight.gunmode.overlay')
    local path=Overlay.CLIPS.aim
    local function clip(len)
        return {full='AnimSequence '..path,IsValid=function() return true end,
            GetFullName=function(o) return o.full end,GetPlayLength=function() return len end}
    end
    local now=clip(1.0)
    local finds=0
    local find=StaticFindObject
    StaticFindObject=function(p) finds=finds+1; return p==path and now or nil end
    local g={log=function() end,try=function(f) local ok,r=pcall(f); if ok then return r end end}
    local layer=Overlay.new(g)
    assert(layer.length('aim')==1.0 and layer.length('aim')==1.0 and finds==1,'found once: '..finds)
    now.full='Texture2D /Game/Other/T_Other.T_Other' -- another object at the clip's address
    now=clip(2.0)                                    -- the clip loaded again
    assert(layer.length('aim')==2.0,'the clip looked up again')
    StaticFindObject=find
end

-- 7c. A rifle clip the installed pak lacks (an older zNGMSpike_P without the v4 poses) is looked up once a Lua load. A
--     miss walks the object array twice and tries a load (50 to 70 ms): the tick asks for the clip each frame.
do
    local Overlay=require('fight.gunmode.overlay')
    local path=Overlay.CLIPS.aimup
    local lookups=0
    local find,load=StaticFindObject,LoadAsset
    local registry={IsValid=function() return true end,GetAsset=function() return nil end}
    StaticFindObject=function(p)
        if p=='/Script/AssetRegistry.Default__AssetRegistryHelpers' then return registry end
        if p==path then lookups=lookups+1 end
    end
    LoadAsset=function(p) if p==path then lookups=lookups+1 end end
    local g={log=function() end,try=function(f) local ok,r=pcall(f); if ok then return r end end}
    local layer=Overlay.new(g)
    local pp={IsValid=function() return true end}
    local her={Mesh={GetPostProcessInstance=function() return pp end}}
    for _=1,60 do
        local m,e=layer.play(her,'aimup')
        assert(m==nil and tostring(e):find('clip not found',1,true),tostring(e))
    end
    assert(lookups==3,'a missing clip looked up '..lookups..' times in 60 frames')
    StaticFindObject,LoadAsset=find,load
end

-- 8. ik.lua's math (UE's conventions): a rotator to a quaternion and back, a vector turned by a quaternion, the
--    rotation of an orthonormal frame and the frame made orthonormal.
do
    local Q=require('fight.gunmode.ik').math
    local function at(v,x,y,z) return close(v.X,x,1e-9) and close(v.Y,y,1e-9) and close(v.Z,z,1e-9) end
    local X,Y,Z={X=1,Y=0,Z=0},{X=0,Y=1,Z=0},{X=0,Y=0,Z=1}
    -- As FRotator::Quaternion: yaw turns forward (X) to the right (Y), pitch turns it up (Z), roll turns the right (Y)
    -- down (-Z).
    assert(at(Q.qrot(Q.rot2q({Pitch=0,Yaw=90,Roll=0}),X),0,1,0))
    assert(at(Q.qrot(Q.rot2q({Pitch=90,Yaw=0,Roll=0}),X),0,0,1))
    assert(at(Q.qrot(Q.rot2q({Pitch=0,Yaw=0,Roll=90}),Y),0,0,-1))
    for _,r in ipairs({{Pitch=0,Yaw=0,Roll=0},{Pitch=30,Yaw=-120,Roll=15},{Pitch=-80,Yaw=170,Roll=-45},
            {Pitch=10,Yaw=45,Roll=179}}) do
        local b=Q.q2rot(Q.rot2q(r))
        assert(close(b.Pitch,r.Pitch,1e-6) and close(b.Yaw,r.Yaw,1e-6) and close(b.Roll,r.Roll,1e-6),
            ('%g %g %g -> %g %g %g'):format(r.Pitch,r.Yaw,r.Roll,b.Pitch,b.Yaw,b.Roll))
    end
    assert(close(Q.q2rot(Q.rot2q({Pitch=90,Yaw=0,Roll=0})).Pitch,90,1e-6))
    -- qmul(a,b) is a after b; qinv undoes a unit quaternion.
    local a,b=Q.rot2q({Pitch=0,Yaw=90,Roll=0}),Q.rot2q({Pitch=90,Yaw=0,Roll=0})
    assert(at(Q.qrot(Q.qmul(a,b),X),0,0,1) and at(Q.qrot(Q.qmul(b,a),X),0,1,0))
    assert(at(Q.qrot(Q.qmul(Q.qinv(a),a),{X=3,Y=-2,Z=5}),3,-2,5))
    -- frame_q(x,z): the rotation taking X onto x and Z onto z.
    assert(at(Q.qrot(Q.frame_q(X,Z),{X=3,Y=-2,Z=5}),3,-2,5))
    for _,r in ipairs({{Pitch=30,Yaw=-120,Roll=15},{Pitch=-80,Yaw=170,Roll=-45},{Pitch=5,Yaw=0,Roll=-170}}) do
        local q=Q.rot2q(r)
        local x,z=Q.qrot(q,X),Q.qrot(q,Z)
        local f=Q.frame_q(x,z)
        local fx,fz=Q.qrot(f,X),Q.qrot(f,Z)
        assert(at(fx,x.X,x.Y,x.Z) and at(fz,z.X,z.Y,z.Z),('%g %g %g'):format(r.Pitch,r.Yaw,r.Roll))
    end
    -- ortho(x,z): x made unit, z the unit part of z square to x.
    local ox,oz=Q.ortho({X=2,Y=0,Z=0},{X=1,Y=0,Z=3})
    assert(at(ox,1,0,0) and at(oz,0,0,1))
end

print('gunmode helpers: ok')
