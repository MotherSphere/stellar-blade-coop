-- drive.lua over a fake EVE, movement component and player controller: on keeps the four values (the file first) and
-- zeroes them; each frame the model's velocity as an impulse (Z at 0, the unused one cleared first) or a Velocity
-- write, the yaw, a launch over a crest (her climb from her height: her movement keeps Velocity.Z at 0 on the ground);
-- nothing while the world's time stands still, nor under root motion; the drift keys (a change logged, a read that
-- fails said once, no controller this frame skips this frame only); a stance push undone at the next 250 ms; off writes the values back on that EVE only, and
-- clears the file; a failing write keeps it; the next Lua load's restore; the probe's two feeds and its free drive;
-- and coop race drive's words.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local function fname(t) return {type=function() return 'FName' end,ToString=function() return t end} end
FName=fname
local SBC={type=function() return 'UObject' end,IsValid=function() return true end,path='/Script/SB.SBCharacter'}
local PCC={type=function() return 'UObject' end,IsValid=function() return true end}
local by_path={}
StaticFindObject=function(path)
    if path=='/Script/SB.SBCharacter' then return SBC end
    if path=='/Script/Engine.PlayerController' then return PCC end
    return by_path[path]
end
local function uobj(o)
    o.type=function() return 'UObject' end
    o.IsValid=o.IsValid or function(self) return not self.gone end
    return o
end
-- EVE and her movement: the four values (the engine's and SB's), what each call did.
local function make_eve(name)
    local e=uobj({velocity={X=0,Y=0,Z=0},at={X=0,Y=0,Z=0},stick={X=0,Y=0,Z=0},yaw=0,time=10,root=false,impulses={},
        yaws={},launches={},clears=0})
    -- Its properties behind a metatable: with locked set, a write raises.
    local props={MaxAcceleration=2048,GroundFriction=8,BrakingDecelerationWalking=0,BrakingFrictionFactor=2}
    local m=setmetatable(uobj({falling=false}),{__index=props,__newindex=function(t,k,v)
        if rawget(t,'locked') then error('read only',0) end
        props[k]=v
    end})
    function m:IsFalling() return self.falling end
    function m:ClearAccumulatedForces() e.clears=e.clears+1 end
    function m:AddImpulse(v,change)
        assert(change==true,'A velocity change')
        e.impulses[#e.impulses+1]=v
        assert(e.clears==#e.impulses,'The unused impulse cleared just before')
    end
    function m:GetFullName() return 'SBCharacterMovementComponent /Game/Map.Map:PersistentLevel.'..name..'.Move' end
    e.CharacterMovement=m
    function e:GetFullName() return 'CH_P_EVE_01_Blueprint_C /Game/Map.Map:PersistentLevel.'..name end
    function e:IsA(c) return c==SBC end
    function e:GetGameTimeSinceCreation() return self.time end
    function e:GetVelocity() return self.velocity end
    function e:K2_GetActorLocation() return self.at end
    function e:GetLastMovementInputVector() return self.stick end
    function e:IsPlayingRootMotion() return self.root end
    function e:K2_GetActorRotation() return {Pitch=0,Yaw=self.yaw,Roll=0} end
    function e:K2_SetActorRotation(r,teleport)
        assert(r.Pitch==0 and r.Roll==0 and teleport==false)
        self.yaws[#self.yaws+1]=r.Yaw
        self.yaw=r.Yaw
    end
    function e:LaunchCharacter(v,xy,z)
        assert(xy==true and z==true)
        self.launches[#self.launches+1]=v
    end
    by_path['/Game/Map.Map:PersistentLevel.'..name]=e
    return e
end
local eve=make_eve('EVE_1')
local down={}
local pc=uobj({IsInputKeyDown=function(_,key) return down[key.KeyName:ToString()]==true end,
    IsA=function(_,c) return c==PCC end})
package.loaded.UEHelpers={GetPlayer=function() return eve end,GetPlayerController=function() return pc end}
local Drive=require('drive')
local M=require('drive_model')
local logs={}
local function log(m) logs[#logs+1]=m end
local function find(pattern) for _,l in ipairs(logs) do if l:find(pattern) then return l end end end
local stored
local store={save=function(line) stored=line; return true end,load=function() return stored end,
    clear=function() stored=nil end}
local settings={drift_keys={'Gamepad_RightTrigger','B'}}
local d=Drive.new({log=log,store=store,settings=settings})
local move=eve.CharacterMovement
local function close(a,b) return math.abs(a-b)<1e-6 end

-- 1. On: the file first (the values still there when it is written), then the four at 0.
assert(not d.active() and d.tick()==nil,'Off: nothing')
local saved_with
store.save=function(line) saved_with=move.MaxAcceleration; stored=line; return true end
local ok,why=d.on(M.DEFAULTS,'race')
assert(ok and d.active() and d.racing(),why)
assert(saved_with==2048 and stored=='/Game/Map.Map:PersistentLevel.EVE_1\t2048\t8\t0\t2',stored)
assert(move.MaxAcceleration==0 and move.GroundFriction==0 and move.BrakingDecelerationWalking==0
    and move.BrakingFrictionFactor==0)
assert(logs[#logs]=='drive on (race): MaxAcceleration=2048 GroundFriction=8 BrakingDecelerationWalking=0 '
    ..'BrakingFrictionFactor=2 kept; top=2200 accel=950 brake=2400 coast=250 grip=80 drift_grip=15 turn_slow=220 '
    ..'turn_fast=75 drift_angle=45',logs[#logs])

-- 2. The first frame only reads her time; the next one feeds the model's velocity as an impulse (the difference, Z at
-- 0) and writes her yaw. The look gets the top speed and the stumble.
eve.stick={X=1,Y=0,Z=0}
local look=d.tick()
assert(#eve.impulses==0 and #eve.yaws==0,'First frame: her time only')
eve.time=eve.time+0.1
eve.velocity={X=500,Y=0,Z=-3} -- Her Velocity.Z is not her climb: she stands at the same height.
look=d.tick()
local step=M.step({heading=0},{stick={x=1,y=0},v={x=500,y=0,z=0},yaw=0},M.values(M.DEFAULTS),0.1)
local i=eve.impulses[1]
assert(#eve.impulses==1 and close(i.X,step.vx-500) and close(i.Y,0) and i.Z==0,i.X)
assert(eve.yaws[1]==0 and look.top==2200 and look.stumble==false)
assert(find('^drive v=500 vz=0 asked=%d+ yaw=0%.0 heading=0%.0 air=0 root=0 drift=0 stumble=0$'),logs[#logs])
-- Paused (her time not moved): nothing written, the same look.
assert(d.tick()==look and #eve.impulses==1 and #eve.yaws==1)
-- Under root motion (a dodge): nothing written, not even the yaw.
eve.time,eve.root=eve.time+0.1,true
d.tick()
assert(#eve.impulses==1 and #eve.yaws==1)
eve.root=false
-- In the air: the yaw only.
eve.time,move.falling,eve.velocity=eve.time+0.1,true,{X=1500,Y=0,Z=400}
d.tick()
assert(#eve.impulses==1 and #eve.yaws==2)
move.falling=false
-- A crest: on the ground her Velocity.Z stays 0, as the game's; her height climbs 500 then 520 cm/s and then 100: a
-- launch in place of the impulse. The same climb in her Velocity.Z alone, at her height, launches nothing.
for _,vz in ipairs({0,500,520,100}) do
    eve.time,eve.velocity,eve.at=eve.time+1/60,{X=1500,Y=0,Z=0},{X=0,Y=0,Z=eve.at.Z+vz/60}
    d.tick()
end
assert(#eve.launches==1 and close(eve.launches[1].Z,500) and find('^drive crest: launched at 500 cm/s up$'))
for _,vz in ipairs({0,500,520,100}) do
    eve.time,eve.velocity=eve.time+1/60,{X=1500,Y=0,Z=vz}
    d.tick()
end
assert(#eve.launches==1,'Her height only')
-- The Velocity write in place of impulses: her own vertical speed kept.
local impulses=#eve.impulses
assert(d.command('feed','struct'))
eve.time,eve.velocity=eve.time+1/60,{X=1500,Y=0,Z=-7}
d.tick()
assert(#eve.impulses==impulses and move.Velocity and move.Velocity.Z==-7 and move.Velocity.X>1400,'Velocity written')
assert(d.command('feed','impulse'))

-- 3. The drift keys: held, the model drifts; each change logged; a failing read said once, then no key. No player
-- controller, or another object where UEHelpers kept it: no key this frame, and the keys are read again the next.
down.B=true
eve.time,eve.velocity,eve.stick=eve.time+1/60,{X=1500,Y=0,Z=0},{X=1,Y=0,Z=0}
local real_pc=pc
for _,other in ipairs({false,uobj({IsA=function() return false end,IsInputKeyDown=function() error('no such call') end})})
do
    pc=other or nil
    eve.time=eve.time+1/60
    d.tick()
    assert(not find('^drive key B down$') and not find('cannot be read'),logs[#logs])
end
pc=real_pc
eve.time=eve.time+1/60
d.tick()
assert(find('^drive key B down$'))
eve.time=eve.time+1
d.tick()
assert(logs[#logs]:find(' drift=1 '),logs[#logs])
down.B=false
eve.time=eve.time+1/60
d.tick()
assert(find('^drive key B up$'))
pc.IsInputKeyDown=function() error('no FKey') end
eve.time=eve.time+1/60
d.tick()
eve.time=eve.time+1/60
d.tick()
local n=0
for _,l in ipairs(logs) do if l:find('^drive: the drift keys cannot be read') then n=n+1 end end
assert(n==1 and find('cannot be read %(.*no FKey%); drifts come from steering alone$'))

-- 4. A stance push writes one of the four: the next 250 ms puts 0 back, and says so.
move.MaxAcceleration=2048
d.slow()
assert(move.MaxAcceleration==0 and find('^drive field MaxAcceleration=2048 written by the game: 0 again$'))

-- 5. Off: the values back on her, the file cleared; again: nothing.
assert(d.off('race fin')=='drive off (race fin): MaxAcceleration=2048 GroundFriction=8 BrakingDecelerationWalking=0 '
    ..'BrakingFrictionFactor=2 back')
assert(move.GroundFriction==8 and move.BrakingFrictionFactor==2 and stored==nil and not d.active())
assert(d.off('again')=='drive off already')
-- A map change: her EVE is another object; nothing written, the file cleared, said.
assert(d.on(M.DEFAULTS,'race'))
eve.gone=true
assert(d.tick()==nil and not d.active() and stored==nil)
assert(logs[#logs]=='drive off (map change): her EVE is gone, nothing to write',logs[#logs])
eve.gone=nil
move.MaxAcceleration,move.GroundFriction,move.BrakingFrictionFactor=2048,8,2
-- A write that fails: the file stays for the next Lua load.
assert(d.on(M.DEFAULTS,'race'))
local saved=stored
rawset(move,'locked',true)
local message=d.off('error')
assert(message=='drive off (error): failed, coop-drive.txt kept for the next Lua load: read only',message)
assert(stored==saved and not d.active())
rawset(move,'locked',nil)

-- A write that fails while on() sets the values: off at once, and on says why. Its file keeps her values from the
-- file the failed off left, never the zeros she has now.
rawset(move,'locked',true)
ok,why=d.on(M.DEFAULTS,'race')
rawset(move,'locked',nil)
assert(not ok and why=='its movement values could not be set (read only); drive off (error): failed, coop-drive.txt '
    ..'kept for the next Lua load: read only' and not d.active() and stored==saved,why)

-- 6. The next Lua load: the file's values back on that EVE, once, the file cleared; a path that is no EVE only
-- clears it.
local d2=Drive.new({log=log,store=store,settings=settings})
d2.restore()
assert(move.MaxAcceleration==2048 and move.GroundFriction==8 and move.BrakingFrictionFactor==2 and stored==nil)
assert(logs[#logs]=='drive restored from coop-drive.txt: MaxAcceleration=2048 GroundFriction=8 '
    ..'BrakingDecelerationWalking=0 BrakingFrictionFactor=2',logs[#logs])
stored='/Game/Gone\t1\t1\t1\t1'
d2.restore()
assert(stored=='/Game/Gone\t1\t1\t1\t1','Once a Lua load')
local d3=Drive.new({log=log,store=store,settings=settings})
d3.restore()
assert(stored==nil and logs[#logs]=='drive restored from coop-drive.txt: her EVE is gone')
-- Nothing to save to: no drive, nothing changed.
local d4=Drive.new({log=log,store={save=function() return false,'cannot write coop-drive.txt' end,load=function() end,
    clear=function() end},settings=settings})
ok,why=d4.on(M.DEFAULTS,'race')
assert(not ok and why=='cannot write coop-drive.txt' and move.MaxAcceleration==2048 and not d4.active())

-- 7. coop race drive: the values, one changed (clamped), the feed, refusals.
ok,message=d.command()
assert(ok and message=='drive: top=2200 accel=950 brake=2400 coast=250 grip=80 drift_grip=15 turn_slow=220 '
    ..'turn_fast=75 drift_angle=45 feed=impulse',message)
ok,message=d.command('top','2600')
assert(ok and message=='Drive top=2600 for your next races (this Lua load).' and d.values().top==2600)
ok,message=d.command('grip','99999')
assert(ok and d.values().grip==300)
assert(not d.command('nope','1') and not d.command('top','fast') and not d.command('top'))
ok,message=d.command('off')
assert(not ok and message=='no drive probe runs')

-- 8. The probe: 3 s of impulses toward 1500 cm/s along her yaw, 3 s of Velocity writes, then the model with her
-- stick until coop race drive off. A race's GO replaces it.
pc.IsInputKeyDown=function(_,key) return down[key.KeyName:ToString()]==true end
eve.yaw,eve.velocity,eve.stick=90,{X=0,Y=0,Z=0},{X=0,Y=0,Z=0}
local before=#eve.impulses
ok,message=d.command('probe')
assert(ok and message:find('^Drive probe: 3 s straight ahead') and d.active() and not d.racing())
d.tick()
for _=1,62 do
    eve.time=eve.time+0.1
    d.tick()
end
local first=eve.impulses[before+1]
assert(first and close(first.X,0) and close(first.Y,1500) and first.Z==0,'Toward her yaw at 1500 cm/s')
assert(find('^drive probe impulse target=1500 read=0,0,0 gave=0,1500$') and find('^drive probe phase=struct$'))
assert(move.Velocity.Y==1500 and find('^drive probe struct target=1500 '))
assert(find('^drive probe phase=free$'))
ok,message=d.command('off')
assert(ok and message:find('^drive off %(coop race drive off%)') and move.MaxAcceleration==2048)
assert(d.command('probe'))
assert(d.on(M.DEFAULTS,'race') and d.racing() and find('^drive off %(replaced by a race%)'))
ok,message=d.command('off')
assert(not ok and message=='a race drives: coop race quit leaves it')
d.off('done')
print('drive_test ok')
