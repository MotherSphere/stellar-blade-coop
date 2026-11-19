-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's pure parts with lua5.4 alone: its settings lines, the polled keys' edges and taps, the crosshair point in
-- EVE's frame, the rifle's magazine (rounds, reloads, the HUD count, running dry, a refill) and the one zone event
-- gun mode may fire.
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
--    until it is done), the count jumping when the magazine goes in; lowered part-spent -> reloaded after a moment;
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
    assert(a.left==10 and a.reserve==19,'lowered reload '..a.left..' '..a.reserve)
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

print('gunmode helpers: ok')
