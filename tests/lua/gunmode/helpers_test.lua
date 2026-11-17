-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's pure parts with lua5.4 alone: its settings lines, the rows it fires, the polled keys' edges and taps, the
-- crosshair point in EVE's frame, the laser's nearest hit, the pose's quaternion helpers and elbow turn, the montage
-- filter and the pak search.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Config=require('gunmode.config')
local Rows=require('gunmode.rows')
local Input=require('gunmode.input')
local Aim=require('gunmode.aim')
local Laser=require('gunmode.laser')
local Pose=require('gunmode.pose')
local close=function(a,b,eps) return math.abs(a-b)<=(eps or 1e-6) end

-- 1. Settings: defaults with no file; the last line wins, names in any case, a BOM and CRLF; bad values refused.
do
    local s,bad=Config.parse(nil)
    assert(s.on and s.key=='G' and not s.real_ammo and #bad==0)
    s,bad=Config.parse('\239\187\191name=x\r\nGUN_KEY = f4\r\ngun_mode=off\r\ngun_mode=on\r\ngun_real_ammo=On\r\n')
    assert(s.on and s.key=='F4' and s.real_ammo and #bad==0)
    s,bad=Config.parse('gun_key=F10\ngun_mode=maybe\ngun_key=ab\ngun_real_ammo=1\n')
    assert(s.key=='G' and s.on and not s.real_ammo and #bad==3) -- gun_key: only its last line counts.
    assert(Config.key('g')=='G' and Config.key('F12')=='F12' and not Config.key('F13') and not Config.key('F0'))
    assert(Config.get('a=1\nb=2\na=3','a')=='3' and Config.get('a=1','b')==nil)
end

-- 2. Rows: the free magazine without real ammo; RealAmmo and no free rounds with it; Peace last; the drone given back.
do
    local names=function(rows) local t={} for _,r in ipairs(rows) do t[#t+1]=r[2] end return table.concat(t,' ') end
    assert(names(Rows.on({real_ammo=false}))==
        'NGM_ItemA_Ammo NGM_AE_Reload NGM_AE_GunOn NGM_AE_Beta NGM_AE_Ammo NGM_AE_Peace')
    assert(names(Rows.on({real_ammo=true}))=='NGM_AE_Reload NGM_AE_GunOn NGM_AE_Beta NGM_AE_RealAmmo NGM_AE_Peace')
    assert(Rows.on({})[1][1]==13 and Rows.OFF[#Rows.OFF][2]=='CGH_data_E_ActorEff_003')
end

-- 3. Input: an edge once per press; a tap only on a short press's release; D-pad Right with R1 held is no tap.
do
    local s={}
    assert(Input.edge(s,true) and not Input.edge(s,true) and not Input.edge(s,false) and Input.edge(s,true))
    local t={}
    assert(not Input.tap(t,true,0,0.4) and not Input.tap(t,true,0.2,0.4) and Input.tap(t,false,0.3,0.4))
    assert(not Input.tap(t,true,1,0.4) and not Input.tap(t,false,1.5,0.4)) -- Held 0.5 s: the bike's.
    local st,down=Input.state(),{}
    local cfg=Config.DEFAULTS
    local function read(now) return Input.read(st,function(n) return down[n]==true end,now,cfg) end
    down.Gamepad_DPad_Right=true; read(0); down.Gamepad_DPad_Right=nil
    assert(read(0.1).toggle)
    down.Gamepad_RightShoulder,down.Gamepad_DPad_Right=true,true; read(1); down.Gamepad_DPad_Right=nil
    assert(not read(1.1).toggle)
    down={Y=true}; assert(read(2).crouch and not read(2.05).crouch)
    down={LeftMouseButton=true}; local r=read(3); assert(r.fire and r.fire_held and not r.fire_ctrl)
    down={LeftMouseButton=true,LeftControl=true}; r=read(3.1); assert(r.fire_ctrl and not r.fire and r.aim)
    down={}; read(3.5)
    down={Gamepad_RightTrigger=true,Gamepad_LeftTrigger=true}; r=read(4); assert(r.fire_ctrl and r.aim_start)
end

-- 4. The crosshair point in EVE's frame (yaw only): ahead, to her right, above.
do
    local x,y,z=Aim.local_offset({X=100,Y=0,Z=50},{X=0,Y=0,Z=0},0)
    assert(close(x,100) and close(y,0) and close(z,50))
    x,y,z=Aim.local_offset({X=0,Y=100,Z=0},{X=0,Y=0,Z=0},90) -- Facing +Y: the point is straight ahead.
    assert(close(x,100) and close(y,0,1e-9))
    x,y=Aim.local_offset({X=10,Y=-5,Z=0},{X=10,Y=0,Z=0},90) -- Facing +Y, a point at -Y: behind her.
    assert(close(x,-5) and close(y,0,1e-9))
    x,y=Aim.local_offset({X=1,Y=1,Z=0},{X=0,Y=0,Z=0},0)
    assert(close(y,1)) -- +Y is her right, as UE's frame has it.
end

-- 5. The laser's end: the nearest hit ahead of the muzzle within range; behind or past range ignored.
do
    local o,a={X=0,Y=0,Z=0},{X=1,Y=0,Z=0}
    local p=Laser.nearest(o,a,{{X=500,Y=10,Z=0},{X=200,Y=-3,Z=1},{X=-50,Y=0,Z=0},{X=9000,Y=0,Z=0}},8000)
    assert(p.X==200 and p.Y==-3)
    assert(Laser.nearest(o,a,{{X=-1,Y=0,Z=0}},8000)==nil and Laser.nearest(o,a,{},8000)==nil)
end

-- 6. The pose's helpers: forward of the identity and of a 90-degree yaw; p*q composes; the elbow turned keeps its
-- distance to the shoulder.
do
    local x,y,z=Pose.forward({X=0,Y=0,Z=0,W=1}); assert(close(x,1) and close(y,0) and close(z,0))
    local h=math.sqrt(0.5)
    x,y,z=Pose.forward({X=0,Y=0,Z=h,W=h}); assert(close(x,0,1e-9) and close(y,1) and close(z,0))
    local q=Pose.mul({X=0,Y=0,Z=h,W=h},{X=0,Y=0,Z=h,W=h})
    x,y=Pose.forward(q); assert(close(x,-1) and close(y,0,1e-9)) -- 180 degrees.
    local sh={Translation={X=0,Y=0,Z=0},Rotation={X=0,Y=0,Z=0,W=1}}
    local el={Translation={X=10,Y=0,Z=-10},Rotation={X=0,Y=0,Z=0,W=1}}
    local wr={Translation={X=20,Y=0,Z=0},Rotation={X=0,Y=0,Z=0,W=1}}
    local d0=math.sqrt(10^2+10^2)
    Pose.elbow_out(sh,el,wr,{X=0,Y=1,Z=0},12)
    local e=el.Translation
    assert(close(math.sqrt(e.X^2+e.Y^2+e.Z^2),d0,1e-6) and math.abs(e.Y)>0.5)
    local r=sh.Rotation; assert(close(r.X^2+r.Y^2+r.Z^2+r.W^2,1,1e-9))
end

-- 7. The battle guard's montage filter, and the pak search: the .utoc first in ~mods, then LogicMods, with its
-- .ucas and .pak beside it.
do
    package.loaded['gunmode.mode']=nil
    local M=require('gunmode.mode')
    assert(M.gun_montage('P_Eve_GunNikke_Shoot') and M.gun_montage('TPS_Aim') and not M.gun_montage('P_Eve_Sword_Draw'))
    local files={['P\\LogicMods\\Z.utoc']=1,['P\\LogicMods\\Z.ucas']=1,['P\\LogicMods\\Z.pak']=1,['P\\~mods\\Y.utoc']=1}
    local read=function(p) return files[p] and 'x' or nil end
    assert(M.find_pak('P',read,'Z')==true)
    local ok,why=M.find_pak('P',read,'Y'); assert(not ok and why:find('Y.ucas',1,true))
    ok,why=M.find_pak('P',read,'X'); assert(not ok and why:find('no X',1,true))
    assert(not M.find_pak(nil,read,'Z'))
end
print('gunmode helpers: ok')
