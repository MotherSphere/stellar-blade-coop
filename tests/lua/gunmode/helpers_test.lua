-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's pure parts with lua5.4 alone: its settings lines, the polled keys' edges and taps, the crosshair point in
-- EVE's frame, and the rifle's magazine (rounds, reloads, the HUD count, running dry, a refill).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Config=require('gunmode.config')
local Input=require('gunmode.input')
local Aim=require('gunmode.aim')
local Ammo=require('gunmode.ammo')
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

print('gunmode helpers: ok')
