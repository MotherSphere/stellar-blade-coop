-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The bike's copy of tests/lua/race/drive_test.lua (November 2026): its own from then on.
-- bike/drive.lua over a fake EVE, movement component and player controller: on keeps the four values (the file first)
-- and zeroes them; each frame the model's velocity as an impulse (Z at 0, the unused one cleared first) or a Velocity
-- write, the yaw, a launch over a crest (her climb from her height: her movement keeps Velocity.Z at 0 on the ground);
-- nothing while the world's time stands still, nor under root motion; the drift keys (a change logged, a read that
-- fails said once, no controller this frame skips this frame only); a stance push undone at the next 250 ms; off writes the values back on that EVE only, and
-- clears the file; a failing write keeps it; the next Lua load's restore; the probe's two feeds and its free drive;
-- coop race drive's words; and the bike's drive with its own model, lean and pitch, the probe and its off refused.
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
local pc_reads=0
package.loaded.UEHelpers={GetPlayer=function() return eve end,
    GetPlayerController=function() pc_reads=pc_reads+1 return pc end}
local Drive=require('bike.drive')
local M=require('bike.drive_model')
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
-- 0); her yaw is written only where it is off the heading by 0.01 degree or more (straight ahead here: not written).
-- The look gets the top speed and the stumble.
eve.stick={X=1,Y=0,Z=0}
local look=d.tick()
assert(#eve.impulses==0 and #eve.yaws==0,'First frame: her time only')
eve.time=eve.time+0.1
eve.velocity={X=500,Y=0,Z=-3} -- Her Velocity.Z is not her climb: she stands at the same height.
look=d.tick()
local step=M.step({heading=0},{stick={x=1,y=0},v={x=500,y=0,z=0},yaw=0},M.values(M.DEFAULTS),0.1)
local i=eve.impulses[1]
assert(#eve.impulses==1 and close(i.X,step.vx-500) and close(i.Y,0) and i.Z==0,i.X)
assert(#eve.yaws==0 and look.top==2200 and look.stumble==false)
assert(find('^drive v=500 vz=0 asked=%d+ yaw=0%.0 heading=0%.0 air=0 root=0 drift=0 stumble=0$'),logs[#logs])
-- Paused (her time not moved): nothing written, the same look.
assert(d.tick()==look and #eve.impulses==1 and #eve.yaws==0)
-- Under root motion (a dodge): nothing written, not even the yaw.
eve.time,eve.root=eve.time+0.1,true
d.tick()
assert(#eve.impulses==1 and #eve.yaws==0)
eve.root=false
-- In the air: the yaw only (the stick to her right turns the heading).
eve.time,move.falling,eve.velocity,eve.stick=eve.time+0.1,true,{X=1500,Y=0,Z=400},{X=0,Y=1,Z=0}
d.tick()
assert(#eve.impulses==1 and #eve.yaws==1)
move.falling,eve.stick=false,{X=1,Y=0,Z=0}
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

-- 3. The drift keys: held, the model drifts; each change logged; a failing read said once, then no key. The player
-- controller is read at drive on and checked every 250 ms: once it is gone, no player controller or another object
-- where UEHelpers kept it gives no key until a 250 ms check finds one again.
down.B=true
eve.time,eve.velocity,eve.stick=eve.time+1/60,{X=1500,Y=0,Z=0},{X=1,Y=0,Z=0}
local real_pc=pc
real_pc.gone=true
for _,other in ipairs({false,uobj({IsA=function() return false end,IsInputKeyDown=function() error('no such call') end})})
do
    pc=other or nil
    d.slow()
    eve.time=eve.time+1/60
    d.tick()
    assert(not find('^drive key B down$') and not find('cannot be read'),logs[#logs])
end
real_pc.gone=nil
pc=real_pc
eve.time=eve.time+1/60
d.tick()
assert(not find('^drive key B down$'),'No key before the next 250 ms check')
d.slow()
eve.time=eve.time+1/60
d.tick()
assert(find('^drive key B down$'))
eve.time=eve.time+10
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

-- 9. The bike (bike/ride.lua): its own model per drive, why 'bike'. The log lists the bike's four values; each frame
-- bike/model.lua's step drives her and the look carries its lean and pitch; every 10 s the line adds them with the
-- stick and SB's raw axes. coop race drive probe and off wait while she rides; the race's model is untouched.
local B=require('bike.model')
eve.LastMoveFowardInput,eve.LastMoveRightInput=0.75,-0.25
eve.yaw,eve.velocity,eve.stick=0,{X=0,Y=0,Z=0},{X=1,Y=0,Z=0}
assert(d.why()==nil)
assert(d.on(B.DEFAULTS,'bike',B) and d.active() and not d.racing() and d.why()=='bike')
assert(logs[#logs]:find('kept; top=2306 accel=1150 brake_hardness=48 turn_angle=36$'),logs[#logs])
d.tick()
eve.time,eve.velocity=eve.time+1,{X=500,Y=0,Z=0}
local fed=#eve.impulses
look=d.tick()
assert(look.top==2306 and look.lean==0 and look.pitch==0,'Straight ahead: no lean')
assert(#eve.impulses==fed+1 and eve.impulses[fed+1].X>0,'The bike model\'s speed fed as an impulse')
assert(logs[#logs]:find(' lean=0%.0 pitch=0%.0 stick=1%.00,0%.00 raw=0%.75,%-0%.25$'),logs[#logs])
eve.time,eve.stick=eve.time+0.1,{X=0.5,Y=0.86,Z=0}
for _=1,10 do
    eve.time=eve.time+1/60
    look=d.tick()
end
assert(look.lean>0,'A right turn (the yaw growing) leans right: '..tostring(look.lean))
for _,word in ipairs({'probe','off'}) do
    ok,message=d.command(word)
    assert(not ok and message=='EVE rides the bike: coop bike gets her off first' and d.why()=='bike')
end
assert(d.values().top==2600,'The race values stay the races\'')
assert(d.off('bike coop bike'):find('^drive off %(bike coop bike%)') and d.why()==nil)

-- 10. One speed line every 10 s, not every second (players post UE4SS.log in public): 12 s at 60 fps give two.
assert(d.on(M.DEFAULTS,'race'))
d.tick()
local said,t0=#logs,eve.time
for k=1,720 do
    eve.time=t0+k/60
    d.tick()
end
local lines=0
for k=said+1,#logs do if logs[k]:find('^drive v=') then lines=lines+1 end end
assert(lines==2,lines)
d.off('done')

-- 11. Fewer engine calls a frame. The controller is read at drive on and checked every 250 ms, never per frame.
eve.yaw,eve.velocity,eve.stick=0,{X=0,Y=0,Z=0},{X=0,Y=0,Z=0}
local reads=pc_reads
assert(d.on(M.DEFAULTS,'race') and pc_reads==reads+1,'Read at drive on')
for _=1,60 do
    eve.time=eve.time+1/60
    d.tick()
end
d.slow()
assert(pc_reads==reads+1,'Never per frame, kept by the 250 ms check while it is valid')
-- Parked: no rotation write and no impulse pair once the last frame gave none.
local yaws,impulses=#eve.yaws,#eve.impulses
for _=1,2 do
    eve.time=eve.time+1/60
    d.tick()
end
assert(#eve.yaws==yaws and #eve.impulses==impulses,'Parked: nothing written')
-- A turn the game made is still corrected the same frame.
eve.yaw=5
eve.time=eve.time+1/60
d.tick()
assert(#eve.yaws==yaws+1 and eve.yaw==0,'Turned back to the heading')
-- The stick again: an impulse at once.
eve.stick={X=1,Y=0,Z=0}
eve.time=eve.time+1/60
d.tick()
assert(#eve.impulses==impulses+1)
-- Coasting to a stop, her movement taking each impulse: after the last real one, one pair under 1 cm/s (it clears what
-- the last frame may have left unused), then none.
eve.stick,eve.velocity={X=0,Y=0,Z=0},{X=eve.impulses[#eve.impulses].X,Y=0,Z=0}
local given={}
for k=1,120 do
    eve.time=eve.time+1/60
    local n=#eve.impulses
    d.tick()
    if #eve.impulses>n then
        local i=eve.impulses[#eve.impulses]
        eve.velocity={X=eve.velocity.X+i.X,Y=eve.velocity.Y+i.Y,Z=0}
        given[#given+1]={k=k,size=math.sqrt(i.X^2+i.Y^2)}
    end
end
local tail,before=given[#given],given[#given-1]
assert(tail.size<1 and before.size>=1 and tail.k==before.k+1 and tail.k<60,'One pair once she stops, then none')
d.off('done')
print('drive_test ok')
