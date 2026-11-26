-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's pure parts with lua5.4 alone: its settings lines, the polled keys' edges and taps, the crosshair point in
-- EVE's frame, the rounds' spread with its setting and the rifle's magazine (rounds, reloads, the HUD count, running
-- dry, a refill). Also the one zone event gun mode may fire and the NIKKE round's DestTarget over fake tables.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Config=require('fight.gunmode.config')
local Input=require('fight.gunmode.input')
local Aim=require('fight.gunmode.aim')
local Ammo=require('fight.gunmode.ammo')
local close=function(a,b,eps) return math.abs(a-b)<=(eps or 1e-6) end

-- 1. Settings: defaults with no file; the last line wins, names in any case, a BOM and CRLF; bad values refused.
do
    local s,bad=Config.parse(nil)
    assert(s.on and s.key=='G' and s.native and s.aim_key=='RightMouseButton' and not s.probe and #bad==0)
    s,bad=Config.parse('\239\187\191name=x\r\nGUN_KEY = f4\r\ngun_mode=off\r\ngun_mode=on\r\ngun_aim_key=LeftMouseButton\r\n')
    assert(s.on and s.key=='F4' and s.aim_key=='LeftMouseButton' and #bad==0)
    s,bad=Config.parse('gun_key=F10\ngun_mode=maybe\ngun_zoom=sideways\n')
    assert(s.key=='G' and #bad==3)
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

-- 3b. The spread: a round lands within gun_spread degrees of the reticle point seen from the camera, every way
--     round, the edge at exactly that angle; 0 degrees or no camera gives the point itself; a point straight above
--     the camera works too. The setting takes 0 to 10 degrees, 0.5 unless set. Each write of a round's destination in
--     mode.lua goes through it.
do
    local function apart(a,b,from)
        local ax,ay,az=a.X-from.X,a.Y-from.Y,a.Z-from.Z
        local bx,by,bz=b.X-from.X,b.Y-from.Y,b.Z-from.Z
        local l=math.sqrt((ax*ax+ay*ay+az*az)*(bx*bx+by*by+bz*bz))
        return math.deg(math.acos(math.max(-1,math.min(1,(ax*bx+ay*by+az*bz)/l))))
    end
    local cam,t={X=0,Y=0,Z=100},{X=1000,Y=200,Z=-50}
    assert(Aim.spread(t,cam,0,0.5,0.5)==t and Aim.spread(t,nil,0.5,0.5,0.5)==t,'No spread: the point itself')
    for j=0,7 do
        assert(close(apart(Aim.spread(t,cam,0.5,1,j/8),t,cam),0.5,1e-6),'The edge is at the angle, way '..j)
        local inside=apart(Aim.spread(t,cam,0.5,0.25,j/8),t,cam)
        assert(inside>0.2 and inside<0.3,'A quarter of the disc is at half the angle: '..inside)
    end
    assert(apart(Aim.spread(t,cam,0.5,0,0.3),t,cam)<1e-6,'u 0 is the point')
    local up=Aim.spread({X=0,Y=0,Z=1100},cam,1,1,0.25)
    assert(up.X==up.X and close(apart(up,{X=0,Y=0,Z=1100},cam),1,1e-6),'Straight up')
    assert(Config.DEFAULTS.spread==0.5)
    for v,want in pairs({['0']=0,['10']=10,['2.5']=2.5}) do
        local s,bad=Config.parse('gun_spread='..v..'\n')
        assert(s.spread==want and #bad==0,'gun_spread='..v)
    end
    for _,v in ipairs({'abc','-1','11'}) do
        local s,bad=Config.parse('gun_spread='..v..'\n')
        assert(s.spread==nil and #bad==1 and bad[1]=='gun_spread: degrees from 0 to 10','gun_spread='..v)
    end
    local f=assert(io.open('mod/StellarCoop/Scripts/fight/gunmode/mode.lua'))
    local src=f:read('a'); f:close()
    local writes,spread=0,0
    for line in src:gmatch('[^\n]+') do
        if line:find('aim.write(p,',1,true) then writes=writes+1 end
        if line:find('Aim.spread(',1,true) then spread=spread+1 end
    end
    assert(writes==2 and spread==2,("mode.lua writes a round's destination %d times and spreads it %d times"):format(writes,spread))
end

-- 4. The magazine: a press fires at once, then one round per cool time in whole frames; empty -> a reload (no round
--    until it is done), the count jumping when the magazine goes in; lowered part-spent -> reloaded after a moment;
--    spares spent -> no rounds (cool time 999) until a refill. A reload's end and a refill write cool time 0, the rate
--    of fire once a cool time and Ammo.OPEN_FRAMES frames went by after the first round (4f755c24, 7f3932fe).
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
    assert(a.left==10 and a.reserve==10 and not a.reload_until and reloads[2]==false and cools[2]==0,
        'the reload ends on cool time 0: '..tostring(cools[2]))
    run(31,true,true)
    assert(cools[3]==0.05,'the rate of fire after the first round: '..tostring(cools[3]))
    run(62,true,false)
    assert(a.left==10 and a.reserve==0)
    run(31,true,true)
    assert(a.left==0 and a.reserve==0 and cools[#cools]==999)
    a.refill()
    assert(a.left==10 and a.reserve==20 and cools[#cools]==0,'the refill writes 0: '..tostring(cools[#cools]))
    run(1,true,false); run(1,true,true)
    run(120,false,false)
    assert(a.left==9 and a.reserve==20,'no reload when lowered (11-20): '..a.left..' '..a.reserve)
    assert(cools[#cools]==0.05,'the rate of fire after the refill\'s first round: '..tostring(cools[#cools]))
end

-- 4c. The reticle's round slot on the first frame of each aim: the game writes its own round's name when its aim
--     starts, here also on the aim's second frame. An aim with the slot not found yet looks for it at its end, not in
--     the aim: a 60-90 ms walk there landed where she watches her body turn to the front. The slot found is kept. A
--     block whose address another object took (a freed HUD) gets no write. Only the reticle's slot is written: the
--     bottom-left count keeps the game's text (f60b4d27).
do
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
    local lower=block(hud..'WB_MainHUD_Lower1Item.WidgetTree.WB_MainHUD_ItemSlotGeneral.WidgetTree.'
        ..'TextBlock_Item_Count')
    local walks=0
    FindAllOf=function(class) if class=='TextBlock' then walks=walks+1; return {lower,name,count} end return {} end
    FText=function(t) return t end
    local clock=10
    local real_clock=os.clock
    os.clock=function() return clock end
    local g={log=function() end,valid=function(o) return o~=nil and o:IsValid() end,
        try=function(f) local ok,r=pcall(f); if ok then return r end end}
    function g.path(o) local f=g.valid(o) and o:GetFullName(); return f and f:match('^%S+ (.+)$') or nil end
    local cfg={mag_size=30,spare_mags=2,reload_time=1,fire_interval=0.05,round_name='NIKKE RAPID',reload_text='R',
        empty_text='E',round_color={1,1,1},reload_color={1,0,0}}
    local a=Ammo.new(g,cfg,function() end,function() end)
    local function run(n,aim) for _=1,n do clock=clock+1/60; a.tick(aim,false,clock) end end
    run(30,true)
    assert(walks==0 and name.text=='game','no walk in the first aim: '..walks..' walks')
    run(1,false)
    assert(walks==1,'the slot looked for at the aim\'s end: '..walks..' walks')
    run(30,false)
    name.text='DRONE ROUND' -- The game's aim starts: its own round's name.
    run(1,true)
    assert(name.text=='NIKKE RAPID','the first frame of the next aim: '..tostring(name.text))
    name.text='DRONE ROUND' -- Written again by the game on the aim's second frame.
    run(1,true)
    assert(name.text=='NIKKE RAPID','the second frame of the aim: '..tostring(name.text))
    assert(walks==1,'the slot found is kept: '..walks..' walks')
    assert(lower.text=='game' and lower.writes==0,'the bottom-left count keeps the game\'s text')
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

-- The one zone event gun mode may fire: kind 2 on the shot's row. Never matchmaking's kinds 15, 16 or 19, another
-- kind or another row. mode.lua calls CreateSBZoneEvent once, inside the guarded zone_event, and the shot (fire_row)
-- reaches it only through that guard.
do
    local GunMode=require('fight.gunmode.mode')
    local Data=require('fight.gunmode.data')
    local fire=Data.row('Fire')
    assert(GunMode.allowed(2,fire))
    for _,kind in ipairs({0,1,3,5,6,10,15,16,19}) do assert(not GunMode.allowed(kind,fire),kind) end
    assert(not GunMode.allowed(2,'MultiplayTest_ZoneE_059') and not GunMode.allowed(2,nil))
    local f=assert(io.open('mod/StellarCoop/Scripts/fight/gunmode/mode.lua','rb')); local src=f:read('a'); f:close()
    local _,calls=src:gsub('CreateSBZoneEvent%(','')
    assert(calls==1,calls..' CreateSBZoneEvent calls in mode.lua')
    local guard=src:match('local function zone_event%(kind,name%)(.-)\r?\nend')
    assert(guard and guard:find("assert(GunMode.allowed(kind,name)",1,true) and guard:find('CreateSBZoneEvent(kind',1,true),
        'the call sits in the guarded zone_event')
    local shot=src:match('local function fire_row%(row%)(.-)\r?\n    end')
    assert(shot and shot:find('pcall(zone_event,ATTACH_ACTOR_EFFECT,row)',1,true) and not shot:find('CreateSBZoneEvent',1,true),
        'the shot goes through the guard')
end

-- 6. The NIKKE round's destination: on EVE (DestTarget MainActor, 0) while the rifle is out, so the offset aim.write
--    puts in her root's frame is where SB sends it. The row ships StartToDestDirection (3), which put the destination on
--    the line to SB's own target location (the 11-25 rounds to the side). put_back() gives 3 back.
do
    local Data=require('fight.gunmode.data')
    local nikke={StartTarget=0,DestTarget=3,StartToDestDirectionDistance=50000.0,StartTargetTransformType=1,
        StartTargetRelativeAxisType=0,DestTargetTransformType=1,DestTargetRelativeAxisType=0,
        DestTargetRelativeLocation={X=0,Y=0,Z=0},DestTargetRandomRange={X=300,Y=300,Z=300},
        StartTargetRelativeLocation={X=0,Y=0,Z=0}}
    local tables={
        EventActorEffectTable={Nikke_01_E_ActorEff_015={ActorEffectAlias='Nikke_Cover'}},
        EffectTable={M_Scarlet_CounterLinkStart={ActionValue1='None'}},
        SkillCommandTable={P_Eve_GunNikke_ShootSlug2_1={CommandActionType=5},
            P_Eve_GunNikke_ShootSlug1_1={CommandActionType=1},P_Eve_GunNikke_ShootSlug1_2={CommandActionType=1}},
        ProjectileTable={P_Eve_GunNikke_ShootSlug1_Projectile1=nikke,
            P_Eve_Gun_ShootSlug1_Projectile1={DestTargetTransformType=0,DestTargetRelativeAxisType=2}}}
    FName=function(s) return s end
    StaticFindObject=function(path)
        local t=tables[path:match('([%w_]+)$')]
        return t and {FindRow=function(_,name) return t[name] end}
    end
    local lines={}
    local g={log=function(s) lines[#lines+1]=s end,valid=function(o) return o~=nil end,
        try=function(f) local ok,r=pcall(f); if ok then return r end end}
    local d=Data.new(g,false)
    assert(d.take()==true,table.concat(lines,'\n'))
    assert(nikke.DestTarget==0,'DestTarget '..tostring(nikke.DestTarget)..' while the rifle is out, not MainActor (0)')
    local said=table.concat(lines,'\n')
    assert(said:find('data: NIKKE round: dest target 3 -> 0, start target 0, start-to-dest distance 50000.0',1,true),said)
    d.put_back()
    assert(nikke.DestTarget==3,'DestTarget '..tostring(nikke.DestTarget)..' after put_back, not as shipped (3)')
end

print('gunmode helpers: ok')
