-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- bike/ride.lua over a fake EVE with her components, the native part's asks and status line, race/drive.lua: the
-- status words; the preload asked once and released at bike=off; the part made once bike=ready and EVE stood 2 s (on
-- her main mesh, at the seat, hidden), found again by a new Lua load; every mount refusal with its reason, nothing
-- asked or written; the mount in its order (coop-bike.txt first, the drive, the gate, the riding clip, the part shown)
-- and the dismount backward; the lean through ComposeRotators with teleport off, written only on a change; the clip
-- played again after an end or held in photo mode; three ends within 1 s, no weight, a refusal or no answer ending
-- the ride; the 250 ms checks (combat stays, swimming and the gate not on end it); a new EVE, an error and bike=off; a
-- mesh write that fails keeps the file; the next Lua load's restore; coop bike status and tune; the Doro look refused
-- while she rides.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
FName=function(t) return {type=function() return 'FName' end,ToString=function() return t end} end
local function uobj(o)
    o.type=function() return 'UObject' end
    o.IsValid=o.IsValid or function(self) return not self.gone end
    return o
end
local events={}
local function event(e) events[#events+1]=e end
local classes={}
local function class(path)
    classes[path]=classes[path] or uobj({path=path})
    return classes[path]
end
local composed={}
local mathlib=uobj({MakeTransform=function() return {} end,
    ComposeRotators=function(_,a,b)
        composed[#composed+1]={a=a,b=b}
        return {Pitch=a.Pitch+b.Pitch,Yaw=a.Yaw+b.Yaw,Roll=a.Roll+b.Roll}
    end})
local MESH='/Game/Art/Character/ETC/Adam_vehicle_02/Adam_Vehicle_02.Adam_Vehicle_02'
local function mesh_asset(path)
    return uobj({GetFullName=function() return 'SkeletalMesh '..path end,
        IsA=function(_,c) return c.path=='/Script/Engine.SkeletalMesh' end})
end
local bike_mesh,eve_mesh=mesh_asset(MESH),mesh_asset('/Game/Art/Character/PC/CH_P_EVE_01/Mesh/EVE.EVE')
local by_path={}
StaticFindObject=function(path)
    if path=='/Script/Engine.Default__KismetMathLibrary' then return mathlib end
    if path:find('^/Script/') then return class(path) end
    if path==MESH then return bike_mesh end
    return by_path[path]
end
LoadAsset=function(path) error('nothing loads in a ride: '..path,0) end
-- A component of EVE's: its mesh, parent, place, visibility; each write as an event.
local components=0
local function component(owner,mesh)
    components=components+1
    local n=components
    local c=uobj({SkeletalMesh=mesh,visible=true})
    function c:GetFullName() return 'SkeletalMeshComponent /Game/Map.Map:PersistentLevel.'..owner.name..'.Part_'..n end
    function c:K2_AttachToComponent(parent,socket,a,b,d,weld)
        assert(socket:ToString()=='None' and a==0 and b==0 and d==0 and weld==false,'KeepRelative, no socket')
        self.parent=parent
    end
    function c:SetSkeletalMesh(m,reinit) assert(reinit==true); self.SkeletalMesh=m end
    function c:SetRelativeScale3D(s) self.scale=s end
    function c:SetCollisionEnabled(v) self.collision=v end
    function c:SetAnimationMode(v) self.mode=v end
    function c:K2_SetRelativeLocationAndRotation(at,rot,sweep,hit,teleport)
        assert(sweep==false and teleport==false)
        self.at,self.rot=at,rot
    end
    function c:SetVisibility(v,children)
        assert(children==false)
        self.visible=v
        event(v and 'show' or 'hide')
    end
    function c:K2_DestroyComponent() self.gone=true end
    return c
end
-- EVE: her address and path, her main mesh (its relative rotation and location), her components, her movement and
-- SB's reads the checks make.
local addresses=0
local function make_eve(name)
    addresses=addresses+1
    local address=addresses
    local e=uobj({name=name,list={},added=0,skill=false,battle=false,root=false,sequence=false,interaction=false,
        block=false,fishing=0,tps=false,bEnableInteractionBlock=false,bFreeCamMode=false})
    local m=component(e,eve_mesh)
    m.RelativeRotation,m.RelativeLocation={Pitch=0,Yaw=-90,Roll=0},{X=0,Y=0,Z=-90}
    function m:K2_SetRelativeRotation(rot,sweep,hit,teleport)
        assert(sweep==false and teleport==false,'Teleport off: cloth keeps its inertia')
        self.RelativeRotation=rot
        event('mesh rotation')
    end
    function m:K2_SetRelativeLocationAndRotation(at,rot,sweep,hit,teleport)
        assert(sweep==false and teleport==false)
        if self.locked then error('read only',0) end
        self.RelativeLocation,self.RelativeRotation=at,rot
        event('mesh back')
    end
    e.Mesh,e.list[1]=m,m
    e.CharacterMovement=uobj({MovementMode=1})
    function e:GetFullName() return 'CH_P_EVE_01_Blueprint_C /Game/Map.Map:PersistentLevel.'..name end
    function e:GetAddress() return address end
    function e:IsA(c) return c.path=='/Script/SB.SBCharacter' end
    function e:K2_GetComponentsByClass(c)
        assert(c.path=='/Script/Engine.SkeletalMeshComponent')
        return self.list
    end
    function e:AddComponentByClass(c,manual,t,deferred)
        assert(c.path=='/Script/Engine.SkeletalMeshComponent' and manual==false and deferred==false)
        self.added=self.added+1
        local p=component(self,nil)
        self.list[#self.list+1]=p
        return p
    end
    function e:IsAttachedToLevelSequenceWithoutPlayable() return self.sequence end
    function e:IsRunningInteraction() return self.interaction end
    function e:IsMoveInputBlock() return self.block end
    function e:IsRunningSkill() return self.skill end
    function e:IsBattle() return self.battle end
    function e:GetFishingModeType() return self.fishing end
    function e:IsTPSMode() return self.tps end
    function e:IsPlayingRootMotion() return self.root end
    by_path['/Game/Map.Map:PersistentLevel.'..name]=e
    return e
end
local eve=make_eve('EVE_1')
-- UE4SS gives a new wrapper at each call: EVE is told by address.
local function wrapper(o) return o and setmetatable({},{__index=o,__newindex=o}) end
package.loaded.UEHelpers={GetPlayer=function() return wrapper(eve) end}
-- The native part: the asks (each an event) and the status line's words.
local st={warp='idle',anim='idle',id=0,load='off',gate='off'}
local native=true
local function status()
    if not native then return 'slot=coop x\n' end
    return ('slot=coop x\nengine=on warp=%s me=1 travel=idle travel_calls=0 anim=%s anim_id=%d bike=%s bike_gate=%s\n')
        :format(st.warp,st.anim,st.id,st.load,st.gate)
end
local asked,refuse={},{}
local function ask(line)
    if refuse[line:match('^%S+ %S+')] then return false,'the native part is off' end
    asked[#asked+1]=line
    event(line)
    return true,'asked the native part: '..line
end
-- race/drive.lua: on and off with why, its frames (the look it gives), its 250 ms checks.
local B=require('bike.model')
local dv={on=false,ticks=0,slows=0,look={top=2306,stumble=false,lean=0,pitch=0}}
local drive={
    on=function(P,why,model)
        assert(model==B and P.top==2306,'The bike model and its values')
        event('drive on '..why)
        if dv.refuse then return false,dv.refuse end
        dv.on=why
        return true
    end,
    off=function(why)
        event('drive off')
        dv.on=false
        return 'drive off ('..why..')'
    end,
    active=function() return dv.on~=false end,why=function() return dv.on or nil end,
    tick=function()
        dv.ticks=dv.ticks+1
        if dv.error then error(dv.error,0) end
        if dv.gone then dv.on=false return nil end
        return dv.look
    end,
    slow=function() dv.slows=dv.slows+1 end}
local stored
local store={save=function(line)
        event('save')
        stored=line
        return true
    end,load=function() return stored end,clear=function() stored=nil end}
local logs={}
local function log(m) logs[#logs+1]=m end
local function last() return logs[#logs] end
local function find(pattern) for _,l in ipairs(logs) do if l:find(pattern) then return l end end end
local settings={}
local world={paused=false,photo='0',frozen=false,life=nil,busy=nil}
local Ride=require('bike.ride')
local function new()
    return Ride.new({log=log,ask=ask,status=status,store=store,drive=drive,settings=settings,
        paused=function() return world.paused end,photo=function() return world.photo end,
        frozen=function() return world.frozen end,life=function() return world.life end,
        busy=function() return world.busy end})
end
local R=new()
local CLIP='/Game/Art/Character/PC/CH_P_EVE_01/Animation/event/G03/MV_SD20_AfterBruteBattle_Main/eve/'
    ..'eve_bikeSleepPose.eve_bikeSleepPose'
local ok,why

-- 1. The status words; the preload's word as a refusal.
local w=Ride.native('engine=on warp=busy me=3 anim=ended anim_id=12 bike=failed:missing_clip '
    ..'bike_gate=refused:controller')
assert(w.warp=='busy' and w.anim=='ended' and w.id==12 and w.load=='failed:missing_clip'
    and w.gate=='refused:controller')
assert(Ride.native('slot=none\n')==nil and Ride.native(nil)==nil,'No engine line: no native part')
assert(Ride.CLIP==CLIP and Ride.MESH==MESH)
assert(Ride.loaded('ready')==nil and Ride.loaded('loading')=='the bike is still loading')
assert(Ride.loaded('failed:name')=='the bike did not load (name)' and Ride.loaded('fault'):find('a fault%)$'))
assert(Ride.loaded('off')=='the bike is not loaded (bike=off, or not asked yet)')
assert(Ride.loaded(nil)==Ride.loaded('off'))

-- 2. The preload: asked at the first 250 ms, once a Lua load; nothing made while it loads.
R.slow()
assert(asked[1]=='bike load '..CLIP and #asked==1 and last()=='bike=on: asked the native part: bike load '..CLIP)
st.load='loading'
R.slow()
assert(#asked==1 and eve.added==0,'Asked once')

-- 3. The part: once bike=ready and EVE stood 2 s, made on her main mesh at the seat, hidden; then never again.
st.load='ready'
R.slow() -- She is seen now.
clock=1.9
R.slow()
assert(eve.added==0,'Not before 2 s')
clock=2
R.slow()
local part=eve.list[2]
assert(eve.added==1 and part.SkeletalMesh==bike_mesh and part.parent==eve.Mesh and part.collision==0 and part.mode==1)
assert(part.at.X==1.53 and part.at.Y==0.52 and part.at.Z==2.95 and part.rot.Pitch==0.69 and part.rot.Yaw==0)
assert(part.scale.X==1 and part.visible==false and last():find('^bike part ready on EVE %(made in [%d.]+ ms%)$'),last())
clock=3
R.slow()
assert(eve.added==1 and #asked==1,'Made once')

-- 4. The refusals, each with its reason, logged; nothing asked, saved or driven.
local function refused(reason,set,unset)
    set()
    local n,e_n=#asked,#events
    ok,why=R.toggle()
    unset()
    assert(not ok and why==reason,tostring(why)..' for '..reason)
    assert(#asked==n and #events==e_n and not R.riding() and stored==nil,reason)
    assert(last()=='bike refused: '..reason,last())
end
local real=eve
refused('no EVE in the world',function() eve=nil end,function() eve=real end)
refused('the bike needs the native part',function() native=false end,function() native=true end)
refused('a load or a warp is under way',function() st.warp='busy' end,function() st.warp='idle' end)
refused('the selfie mode is open',function() world.photo='s' end,function() world.photo='0' end)
refused('the game is paused or shows one of its screens',function() world.paused=true end,
    function() world.paused=false end)
refused('the photo mode is open',function() world.photo='1' end,function() world.photo='0' end)
refused("your friend's photo mode holds the game",function() world.frozen=true end,function() world.frozen=false end)
refused('a cutscene holds EVE',function() eve.sequence=true end,function() eve.sequence=false end)
refused('EVE is in an interaction',function() eve.interaction=true end,function() eve.interaction=false end)
refused('EVE is in an interaction',function() eve.bEnableInteractionBlock=true end,
    function() eve.bEnableInteractionBlock=false end)
refused('the game holds her movement',function() eve.block=true end,function() eve.block=false end)
local move=eve.CharacterMovement
refused('EVE is swimming',function() move.MovementMode=4 end,function() move.MovementMode=1 end)
refused("EVE is in one of SB's moves (a ladder, a rope, a beam, a wire or an event)",
    function() move.MovementMode=6 end,function() move.MovementMode=1 end)
refused('EVE is in the air',function() move.MovementMode=3 end,function() move.MovementMode=1 end)
refused('EVE cannot move now (movement mode 5)',function() move.MovementMode=5 end,function() move.MovementMode=1 end)
refused('a skill runs (an attack or a dodge)',function() eve.skill=true end,function() eve.skill=false end)
refused('EVE is in combat',function() eve.battle=true end,function() eve.battle=false end)
refused('EVE is fishing',function() eve.fishing=2 end,function() eve.fishing=0 end)
refused('EVE aims',function() eve.tps=true end,function() eve.tps=false end)
refused('the free camera is on',function() eve.bFreeCamMode=true end,function() eve.bFreeCamMode=false end)
refused("EVE is on one of the game's lifts or trains",function() eve.VehicleActor=uobj({}) end,
    function() eve.VehicleActor=nil end)
refused('EVE is down',function() world.life={state=4,hp=0} end,function() world.life=nil end)
refused('a race or the drive probe drives EVE',function() dv.on='probe' end,function() dv.on=false end)
refused('coop emote plays',function() world.busy='coop emote plays' end,function() world.busy=nil end)
refused('the bike is still loading',function() st.load='loading' end,function() st.load='ready' end)
refused('the bike did not load (missing_mesh)',function() st.load='failed:missing_mesh' end,
    function() st.load='ready' end)
-- A new EVE (a map change): no part for her until she stood 2 s.
local other=make_eve('EVE_2')
refused('the bike is still loading',function() eve=other; R.slow() end,function() eve=real; R.slow() end)
-- A part that could not be made: why, once.
do
    local lone=make_eve('EVE_3')
    lone.AddComponentByClass=function() return nil end
    eve=lone
    R.slow()
    clock=clock+2
    R.slow()
    assert(last()=='bike part not made: Adam_Vehicle_02 could not be added',last())
    local said=#logs
    R.slow()
    assert(#logs==said,'Said once')
    refused('the bike part could not be made (Adam_Vehicle_02 could not be added)',function() end,function() end)
    eve=real
    R.slow()
    clock=clock+2
    R.slow()
    assert(last():find('^bike part ready on EVE %(found in'),last())
end
-- coop-bike.txt that cannot be written: refused, nothing else done.
events={}
store.save=function() return false,'cannot write coop-bike.txt' end
ok,why=R.toggle()
assert(not ok and why=='coop-bike.txt could not be written: cannot write coop-bike.txt' and #events==0 and not dv.on)
store.save=function(line) event('save'); stored=line; return true end

-- 5. The mount, in its order: the file (her mesh as it was), the drive with the bike model, the gate, the riding clip
-- looped with her foot IK off, the part shown. One line with her mesh's relative rotation.
assert(eve==real and eve.added==1 and #eve.list==2)
events={}
ok,why=R.toggle()
assert(ok and why=='On the bike: coop bike gets her off.' and R.riding(),why)
local id=tonumber(asked[#asked]:match('^anim play (%d+) '))
assert(id and id>2000000000,'Apart from coop emote\'s ids')
local order={'save','drive on bike','bike gate on','anim play '..id..' '..CLIP..' ride','show'}
for k,e in ipairs(order) do assert(events[k]==e,k..': '..tostring(events[k])) end
assert(#events==#order and part.visible)
assert(stored=='/Game/Map.Map:PersistentLevel.EVE_1\t0\t-90\t0\t0\t0\t-90',stored)
assert(find('^bike on in [%d.]+ ms: her mesh relative rotation P=0%.00 Y=%-90%.00 R=0%.00, location 0%.00 0%.00 '
    ..'%-90%.00$'))
ok,why=R.toggle()
assert(ok and why=='Off the bike.' and not R.riding())
-- 6. The dismount, backward: the part hidden, the clip stopped, the gate off, the drive off, her mesh back, the file
-- cleared.
order={'hide','anim stop','bike gate off','drive off','mesh back'}
for k,e in ipairs(order) do assert(events[5+k]==e,k..': '..tostring(events[5+k])) end
assert(not part.visible and stored==nil and eve.Mesh.RelativeRotation.Yaw==-90 and eve.Mesh.RelativeLocation.Z==-90)
assert(last():find('^bike off %(coop bike%) after [%d.]+ s: her mesh back$'),last())
assert(find('^drive off %(bike coop bike%)$'))

-- The mount fails halfway: the drive refused (nothing else asked); the gate's ask refused (the drive off again).
dv.refuse='EVE has no movement component'
events={}
ok,why=R.toggle()
assert(not ok and why=='no driving: EVE has no movement component' and not R.riding() and stored==nil,why)
assert(events[1]=='save' and events[2]=='drive on bike' and events[3]=='mesh back' and #events==3)
dv.refuse=nil
refuse['bike gate']=true
events={}
ok,why=R.toggle()
assert(not ok and why=="SB's actions could not be turned off: the native part is off" and not dv.on,why)
assert(events[3]=='drive off' and events[4]=='mesh back' and #events==4 and stored==nil)
refuse['bike gate']=nil

-- 7. Each frame: the drive's frame, then her lean and pitch composed after her mesh's base rotation (about her actor's
-- axes), teleport off; a change under 0.05 degrees is not written.
local function mount()
    events={}
    assert(R.toggle())
    st.gate='on'
    return tonumber(asked[#asked]:match('^anim play (%d+) '))
end
-- A new EVE seen, then 2 s: her part.
local function settle()
    R.slow()
    clock=clock+2
    R.slow()
end
id=mount()
dv.look=nil -- The drive's first frame gives no look yet: she rides on, nothing written.
assert(R.steer()==nil and R.riding() and dv.ticks==1 and #composed==0)
dv.look={top=2306,lean=10,pitch=2}
R.steer()
assert(dv.ticks==2 and #composed==1 and composed[1].a.Yaw==-90 and composed[1].b.Roll==10 and composed[1].b.Pitch==2)
assert(composed[1].b.Yaw==0 and eve.Mesh.RelativeRotation.Roll==10 and eve.Mesh.RelativeRotation.Yaw==-90)
dv.look={top=2306,lean=10.04,pitch=2}
R.steer()
assert(#composed==1 and dv.ticks==3,'Under 0.05 degrees: not written')
dv.look={top=2306,lean=0,pitch=0}
R.steer()
assert(#composed==2 and eve.Mesh.RelativeRotation.Roll==0)

-- 8. The riding clip: its answer read every 0.1 s; playing logged once; an end plays it again with a new id, unless
-- the photo mode, a skill or root motion holds her.
st.id,st.anim=id,'playing'
clock=clock+0.15
R.steer()
assert(last()==('bike ride clip plays (anim %d)'):format(id),last())
local n=#asked
st.anim='ended'
clock=clock+0.05
R.steer()
assert(#asked==n,'Read every 0.1 s only')
world.photo='1'
clock=clock+0.15
R.steer()
assert(#asked==n and R.riding() and last()==('bike ride clip ended (anim %d, 1 end(s) within 1 s)'):format(id),last())
world.photo='0'
eve.skill=true
clock=clock+0.15
R.steer()
assert(#asked==n,'A skill holds her')
eve.skill=false
eve.root=true
clock=clock+0.15
R.steer()
assert(#asked==n,'Root motion holds her')
eve.root=false
clock=clock+0.15
R.steer()
local id2=tonumber(asked[#asked]:match('^anim play (%d+) '..CLIP:gsub('%p','%%%0')..' ride$'))
assert(#asked==n+1 and id2==id+1,asked[#asked])
-- No answer for the new id in 5 s: off.
clock=clock+4.9
R.steer()
assert(R.riding())
clock=clock+0.2
ok,why=R.steer()
assert(not ok and why=='Off the bike: no answer from the native part for the riding clip' and not R.riding(),why)
assert(asked[#asked-1]=='anim stop' and asked[#asked]=='bike gate off' and stored==nil)
-- Three ends within 1 s: SB uses the slot.
id=mount()
for k=1,3 do
    st.id,st.anim=id+k-1,'ended'
    clock=clock+0.2
    ok,why=R.steer()
end
assert(not ok and why=='Off the bike: SB ended the riding clip 3 times within 1 s' and not R.riding(),why)
-- Ends further apart only play it again.
id=mount()
for k=1,4 do
    st.id,st.anim=id+k-1,'ended'
    clock=clock+0.6
    ok,why=R.steer()
    assert(ok==nil and R.riding(),tostring(why))
end
R.toggle()
-- No weight, a refusal, a stop or the latch: off with the reason.
for word,reason in pairs({['ended:weight']='her animation blueprint showed none of the riding clip',
    ['refused:slots']='the game refused the riding clip (slots)',
    stopped='the native part stopped the riding clip (stopped)',
    fault='the native part stopped the riding clip (fault)'}) do
    id=mount()
    st.id,st.anim=id,word
    clock=clock+0.15
    ok,why=R.steer()
    assert(not ok and why=='Off the bike: '..reason and not R.riding(),why)
end
-- A frame that raises; the drive gone with her EVE (a map change): off.
id=mount()
dv.error='no velocity'
ok,why=R.steer()
assert(not ok and why=='Off the bike: an error: no velocity' and not R.riding() and stored==nil,why)
dv.error=nil
id=mount()
dv.gone=true
ok,why=R.steer()
assert(not ok and why=='Off the bike: her EVE changed' and not R.riding(),why)
dv.gone=nil

-- 9. Every 250 ms while she rides: the drive's check; combat stays (her actions are off); swimming ends it; so does
-- the gate not on 1 s after the mount; so does another EVE (nothing written on her, nor on the old one once gone).
id=mount()
local slows=dv.slows
eve.battle,eve.skill,move.MovementMode=true,true,3
R.slow()
assert(R.riding() and dv.slows==slows+1,'Combat, a skill and the air do not end a ride')
eve.battle,eve.skill=false,false
move.MovementMode=4
ok,why=R.slow()
assert(not ok and why=='Off the bike: EVE is swimming' and not R.riding(),why)
move.MovementMode=1
for _,case in ipairs({{function() world.photo='s' end,'the selfie mode is open'},
    {function() st.warp='busy' end,'a load or a warp is under way'},
    {function() eve.VehicleActor=uobj({}) end,"EVE is on one of the game's lifts or trains"},
    {function() world.life={state=3,hp=0} end,'EVE is down'},{function() eve.fishing=1 end,'EVE is fishing'}}) do
    id=mount()
    case[1]()
    ok,why=R.slow()
    world.photo,st.warp,eve.VehicleActor,world.life,eve.fishing='0','idle',nil,nil,0
    assert(not ok and why=='Off the bike: '..case[2],why)
end
id=mount()
st.gate='off'
clock=clock+0.5
assert(R.slow()==nil and R.riding(),'The gate is given 1 s')
clock=clock+0.6
ok,why=R.slow()
assert(not ok and why=="Off the bike: SB's actions are not off (bike_gate=off)",why)
id=mount()
eve=other
ok,why=R.slow()
assert(not ok and why=='Off the bike: her EVE changed' and other.Mesh.RelativeRotation.Yaw==-90,why)
eve=real
settle()
-- Her EVE gone with the map: nothing written, the file cleared.
id=mount()
real.gone=true
eve=other
ok,why=R.slow()
assert(not ok and stored==nil and last():find('her EVE is gone, nothing to write$'),last())
real.gone=nil
eve=real

-- 10. A mesh write that fails at the dismount: the file stays for the next Lua load.
settle()
id=mount()
assert(R.riding(),'Her part again after the map change')
eve.Mesh.locked=true
R.stop('coop off')
eve.Mesh.locked=nil
assert(not R.riding() and stored=='/Game/Map.Map:PersistentLevel.EVE_1\t0\t-90\t0\t0\t0\t-90')
assert(last():find('^bike off %(coop off%) after [%d.]+ s: her mesh not written back %(read only%), '
    ..'coop%-bike%.txt kept$'),last())
assert(R.stop('coop off')==nil,'Off already')

-- 11. The next Lua load: coop-bike.txt puts her mesh back and hides the part, once, the file cleared; the part is found
-- again, not made. A path that is no EVE only clears the file.
eve.Mesh.RelativeRotation,eve.Mesh.RelativeLocation={Pitch=5,Yaw=-80,Roll=20},{X=1,Y=1,Z=1}
part.visible=true
local R2=new()
R2.restore()
assert(stored==nil and eve.Mesh.RelativeRotation.Yaw==-90 and eve.Mesh.RelativeRotation.Roll==0)
assert(eve.Mesh.RelativeLocation.Z==-90 and not part.visible)
assert(last()=='bike restored from coop-bike.txt: her mesh back, the bike hidden',last())
stored='/Game/Gone\t0\t0\t0\t0\t0\t0'
R2.restore()
assert(stored~=nil,'Once a Lua load')
new().restore()
assert(stored==nil and last()=='bike restored from coop-bike.txt: her EVE is gone',last())
local added=eve.added
R2.slow()
clock=clock+2
R2.slow()
assert(eve.added==added and last():find('^bike part ready on EVE %(found in'),'Found, not made: '..last())

-- 12. bike=off: off the bike, the part removed, the preload released, once; on again asks the load again.
id=mount()
settings.bike='off'
R.slow()
assert(not R.riding() and find('^bike off %(bike=off%)') and part.gone and asked[#asked]=='bike free')
assert(last()=='bike=off: asked the native part: bike free',last())
n=#asked
R.slow()
ok,why=R.toggle()
assert(#asked==n and not ok and why=='the bike is off (bike=off)' and last()=='bike refused: '..why,tostring(why))
settings.bike=nil
R.slow()
assert(asked[#asked]=='bike load '..CLIP)

-- 13. coop bike status and tune.
local said=R.status()
assert(said=='bike: preload ready, part not made yet, not riding; top=2306 accel=1150 brake_hardness=48 '
    ..'turn_angle=36',said)
settle()
id=mount()
said=R.status()
assert(said:find('^bike: preload ready, part on EVE, riding for 0 s; '),said)
R.toggle()
ok,said=R.tune('top','3000')
assert(ok and said=='Bike top=3000 from your next ride (this Lua load).')
ok,said=R.tune()
assert(ok and said=='bike: top=3000 accel=1150 brake_hardness=48 turn_angle=36',said)
assert(not R.tune('speed','1') and not R.tune('top','fast'))

-- 14. The Doro look does not start while she rides (commands/race.lua).
local looks=0
local rides=true
local Cmd=require('commands.race').new({puppet={doro=function() return true end},
    doro={on=function() looks=looks+1; return true,'look on' end,off=function() return true,'look off' end},
    coop_slot=function() return true end,race={command=function() return true end},riding=function() return rides end})
ok,why=Cmd.race('look','on')
assert(not ok and why=='EVE rides the bike: coop bike gets her off first' and looks==0,why)
rides=false
assert(Cmd.race('look','on') and looks==1)
print('ride_test ok')
