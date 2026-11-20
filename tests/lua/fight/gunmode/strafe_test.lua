-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Hip fire's strafe (fight/gunmode/strafe.lua): the sector with hysteresis, the walk/run switch, the rate clamp, the pick
-- in her actor frame, and on a fake engine one montage per clip change, stopped on end, disable and the turn step.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
function FName(x) return x end
local Strafe=require('fight.gunmode.strafe')
local cfg=require('fight.gunmode.config').DEFAULTS

-- 1. Sectors: 0 forward, 90 right, 180 and -180 back, -90 left; borders at 22.5 deg; hysteresis holds a sector
-- hyst deg past its border (both sides, across the 180 wrap).
do
    local S=Strafe.sector
    assert(S(nil,0,10)==1 and S(nil,90,10)==3 and S(nil,-90,10)==7)
    assert(S(nil,180,10)==5 and S(nil,-180,10)==5 and S(nil,179,10)==5 and S(nil,-179,10)==5)
    assert(S(nil,22,0)==1 and S(nil,23,0)==2 and S(nil,-23,0)==8)
    assert(S(1,30,10)==1 and S(1,33,10)==2)          -- forward held to 32.5, then forward-right
    assert(S(2,15,10)==2 and S(2,12,10)==1)          -- forward-right held down to 12.5
    assert(S(5,-150,10)==5 and S(5,-147,10)==6)      -- back held across the wrap down to -147.5 (157.5 - 10 off 180)
    assert(S(5,150,10)==5 and S(5,147,10)==4)
    assert(S(4,165,10)==4 and S(4,-178,10)==5)       -- back-right held to 167.5, then back
    assert(Strafe.DIRS[S(nil,90,10)]=='R' and Strafe.DIRS[S(nil,-90,10)]=='L')
end

-- 2. Walk/run with hysteresis around strafe_run_at.
do
    local R=Strafe.run
    assert(R(nil,280,260,30)==false and R(nil,290,260,30)==true)
    assert(R(true,240,260,30)==true and R(true,229,260,30)==false)
    assert(R(false,289,260,30)==false)
end

-- 3. The rate: speed over the authored speed, clamped.
do
    local K=Strafe.rate
    assert(K(150,150,0.6,1.6)==1.0 and K(30,150,0.6,1.6)==0.6 and K(500,150,0.6,1.6)==1.6)
    assert(math.abs(K(180,150,0.6,1.6)-1.2)<1e-9)
end

-- 4. The pick in her actor frame: yaw 90 faces world +Y; a move along world +X is then to her left; along world -X to
-- her right. Below strafe_min no clip; fast is a run clip at the run rate.
do
    local st={}
    local path,k=Strafe.pick(st,150,0,90,cfg)
    assert(path==Strafe.WALK[7] and path:find('NGM_R_AimL%.NGM_R_AimL$') and math.abs(k-1)<1e-9)
    path=Strafe.pick(st,-150,0,90,cfg); assert(path==Strafe.WALK[3] and path:find('/NGM/NGM_R_AimR%.'))
    path=Strafe.pick(st,0,150,90,cfg); assert(path==Strafe.WALK[1])
    path,k=Strafe.pick(st,0,330,90,cfg); assert(path==Strafe.RUN[1] and path:find('NGM_R_AimRunF%.') and math.abs(k-1.1)<1e-9)
    assert(Strafe.pick(st,10,10,0,cfg)==nil and st.sec==nil and st.run==nil)
end

-- 5. A fake engine: one montage per clip change, its rate set on a speed change, stopped (with the blend) when the
-- strafe ends, on stop() (disable, new controller) and while the turn step plays; never two looping at once.
do
    local log={}
    local live={} -- montages playing
    local function montage(name) return {name=name} end
    local ai={}
    function ai:PlaySlotAnimationAsDynamicMontage(seq,slot,bi,bo,rate,loops,trig,at)
        assert(slot=='DefaultSlot' and bi==cfg.strafe_blend and bo==cfg.strafe_blend and loops==Strafe.LOOPS)
        local m=montage(seq); live[m]=true; log[#log+1]='play '..seq:match('([%w_]+)$')..(' %.2f'):format(rate); return m
    end
    function ai:Montage_Stop(blend,m) assert(blend==cfg.strafe_blend); live[m]=nil; log[#log+1]='stop '..m.name:match('([%w_]+)$') end
    function ai:Montage_IsPlaying(m) return live[m]==true end
    function ai:Montage_SetPlayRate(m,k) log[#log+1]=('rate %.2f'):format(k) end
    function ai:IsValid() return true end
    local p={vel={X=0,Y=0},Mesh={}}
    function p.Mesh:GetAnimInstance() return ai end
    function p:GetVelocity() return self.vel end
    function p:K2_GetActorRotation() return {Yaw=0} end
    local g={valid=function(o) return o~=nil end,log=function() end,asset=function(path) return path end}
    local sf=Strafe.new(g,cfg)
    local function n_live() local n=0; for _ in pairs(live) do n=n+1 end; return n end
    local t=0
    local function frame(vx,vy,active) t=t+0.02; p.vel.X,p.vel.Y=vx,vy; sf.tick(p,active~=false,t) end

    frame(0,150) for _=1,10 do frame(0,150) end         -- D held: right walk, played once
    assert(#log==1 and log[1]=='play NGM_R_AimR 1.00' and n_live()==1)
    frame(0,180); assert(log[2]=='rate 1.20')           -- faster: the rate follows, no new montage
    frame(0,-150); assert(log[3]=='stop NGM_R_AimR' and log[4]=='play NGM_R_AimL 1.00' and n_live()==1)
    frame(0,0); assert(log[5]=='stop NGM_R_AimL' and n_live()==0 and sf.playing()==nil) -- stopped moving
    frame(150,0); assert(log[6]=='play NGM_R_AimF 1.00')
    frame(150,0,false); assert(log[7]=='stop NGM_R_AimF' and n_live()==0) -- hip fire let go
    frame(150,0); assert(n_live()==1)
    sf.stop(); assert(n_live()==0 and sf.playing()==nil) -- disable / new controller
    sf.stop(); assert(n_live()==0)                       -- twice is harmless

    -- the turn step: the strafe gives way while the turn clip plays, then comes back
    frame(150,0); assert(n_live()==1)
    local turn=montage('turn'); live[turn]=true
    sf.hold(ai,turn)
    frame(150,0); assert(live[turn] and n_live()==1 and sf.playing()==nil)
    frame(150,0); assert(n_live()==1)
    live[turn]=nil
    frame(150,0); assert(n_live()==1 and sf.playing()==Strafe.WALK[1])

    -- the game stopped the montage: played again at the next check
    for m in pairs(live) do live[m]=nil end
    t=t+0.3; frame(150,0); assert(n_live()==1)
    sf.stop(); assert(n_live()==0)
end

-- 6. The settings: strafe on, the old stance-override strafe off.
do
    assert(cfg.strafe==false and cfg.hip_strafe==false)
    assert(cfg.strafe_min==40 and cfg.strafe_hyst==10 and cfg.strafe_run_at==260 and cfg.strafe_blend==0.2)
    assert(cfg.strafe_walk_speed==150 and cfg.strafe_run_speed==300 and cfg.strafe_rate_min==0.6 and cfg.strafe_rate_max==1.6)
end
-- another montage (a dodge, a hit, the game's shot) playing on her: the strafe plays nothing over it, then comes back;
-- below strafe_min it holds down to strafe_min - strafe_min_hyst once going
do
    local live,plays={},0
    local foreign={name='dodge'}
    local ai={}
    function ai:PlaySlotAnimationAsDynamicMontage(seq) plays=plays+1; local m={name=seq}; live[m]=true; return m end
    function ai:Montage_Stop(_,m) live[m]=nil end
    function ai:Montage_IsPlaying(m) return live[m]==true end
    function ai:Montage_SetPlayRate() end
    function ai:GetCurrentActiveMontage() if live[foreign] then return foreign end end
    local p={vel={X=0,Y=0},Mesh={}}
    function p.Mesh:GetAnimInstance() return ai end
    function p:GetVelocity() return self.vel end
    function p:K2_GetActorRotation() return {Yaw=0} end
    local g={valid=function(o) return o~=nil end,log=function() end,asset=function(path) return path end}
    local sf=Strafe.new(g,cfg)
    local t=0
    local function frame(vx,vy) t=t+0.02; p.vel.X,p.vel.Y=vx,vy; sf.tick(p,true,t) end
    live[foreign]=true
    frame(150,0); frame(0,150)
    assert(plays==0 and sf.playing()==nil,'nothing played over a dodge')
    live[foreign]=nil
    frame(0,150); assert(plays==1,'played once the dodge ended')
    frame(0,cfg.strafe_min-cfg.strafe_min_hyst+2); assert(sf.playing()~=nil,'held just under strafe_min')
    frame(0,cfg.strafe_min-cfg.strafe_min_hyst-2); assert(sf.playing()==nil,'stopped under the hysteresis')
    frame(0,cfg.strafe_min-5); assert(sf.playing()==nil,'not started again under strafe_min')
end
-- a clip of the mod pak (LoadAsset cannot see it): loaded through the asset registry once, kept while it has its path,
-- loaded again when its address holds another object, a miss waits 5 s
do
    local gets,objs=0,{}
    local function obj(path) return {ok=true,path=path,GetFullName=function(o) return 'AnimSequence '..o.path end} end
    StaticFindObject=function() return {GetAsset=function(_,a) gets=gets+1; if a.ObjectPath=='missing' then return nil end; objs[a.ObjectPath]=objs[a.ObjectPath] or obj(a.ObjectPath); return objs[a.ObjectPath] end} end
    FName=function(s) return s end
    local g={valid=function(o) return o~=nil and o.ok==true end}
    local kept={}
    local a=Strafe.registry_find(g,kept,'/X/C.C',0); local b2=Strafe.registry_find(g,kept,'/X/C.C',1)
    assert(a and a==b2 and gets==1,'one registry load, kept')
    objs['/X/C.C'].path='/Other/O.O'; objs['/X/C.C']=nil
    assert(Strafe.registry_find(g,kept,'/X/C.C',2) and gets==2,'loaded again when the address holds another object')
    assert(Strafe.registry_find(g,kept,'missing',3)==nil and Strafe.registry_find(g,kept,'missing',4)==nil and gets==3,'a miss waits')
    assert(Strafe.registry_find(g,kept,'missing',9)==nil and gets==4,'tried again after 5 s')
end
print('gunmode strafe_test ok')
