-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- vehicles/bike/ride.lua over a fake EVE with her components, the native part's asks and status line,
-- vehicles/bike/drive.lua: the status words; the preload asked once and released at bike=off; the part made once
-- bike=ready and EVE stood 2 s (on her main mesh, at the seat, hidden, its tick off), found again by a new Lua load;
-- every mount refusal with its reason, nothing asked or written; the mount in its order (coop-bike.txt first, the
-- drive, the gate, the riding clip, the part shown) and the dismount backward; the lean through ComposeRotators with
-- teleport off, written only on a change; the clip played again after an end or held in photo mode; three ends within 1
-- s, no weight, a refusal or no answer ending the ride, all read in the 250 ms pass (no frame reads the status); the
-- 250 ms checks (combat stays, swimming and the gate not on end it); a new EVE, an error and bike=off; a
-- mesh write that fails keeps the file; the next Lua load's restore; coop bike status and tune; idle_part (the part
-- the capture leaves out) before the part, off the bike, on it and at bike=off;
-- the part's tag (one that does not hold makes no part), found at a new Lua load's first tick whatever the bike= word,
-- removed by its first pass at bike=off; another mod's component on the same mesh never taken for it. The parked bike
-- (a fake vehicles/bike/stand.lua): made after the part, parked where a dismount by the key leaves her, at the last
-- ground pose after a forced one or where it stood before the mount, hidden while she rides or a cutscene holds her,
-- removed for a new EVE; a mount refused far from it (the distance and the side), on another map or before it is back,
-- else made onto it by a teleport; the prompt once she comes within reach; its place per account and save (o.file),
-- kept out of the record while an SBO lobby is open; its path kept for the next Lua load (o.stand_store), swept at that
-- load's first tick, which parks at her feet after a Ctrl+R while she rode; removed at coop off and bike=off, put back
-- at bike=on; its line for the link (o.send) at each change, sent again after a failed write. The paid fetch at a Xion
-- camp (o.camp, o.fetch): offered after a far or another-map refusal, paid by a press within 5 s, every press refused
-- while it runs, the place it gives, its notices; never within reach, in an SBO lobby or away from a camp. The money's
-- name in them: SB's (o.game_text) on the screen's words, betacrystal in the English copy of another language, for a
-- name over 32 bytes and in an offer it would take past the feed's 200 bytes. The rig way (a fake
-- vehicles/bike/rig.lua): its mount and dismount, bike_pose read at each mount, its 250 ms checks; after Ctrl+R the rig
-- of fields 8 and 9 released before her mesh goes back (a hold ride's file releases nothing); a dismount in photo mode
-- keeps the rig until the first 250 ms pass with photo mode closed.
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
local stand_order={} -- The fake stand's hides, in order with what the tests put beside them.
local classes={}
local function class(path)
    classes[path]=classes[path] or uobj({path=path})
    return classes[path]
end
local composed={}
local math_looks=0 -- Each U.find of the math library checks it with IsValid.
local mathlib=uobj({IsValid=function() math_looks=math_looks+1 return true end,MakeTransform=function() return {} end,
    ComposeRotators=function(_,a,b)
        composed[#composed+1]={a=a,b=b}
        return {Pitch=a.Pitch+b.Pitch,Yaw=a.Yaw+b.Yaw,Roll=a.Roll+b.Roll}
    end,
    MakeRotFromZX=function(_,z,x) return {Pitch=0,Yaw=math.deg(math.atan(x.Y,x.X)),Roll=0} end})
local MESH='/Game/Art/Character/ETC/Adam_vehicle_02/Adam_Vehicle_02.Adam_Vehicle_02'
local function mesh_asset(path)
    return uobj({GetFullName=function() return 'SkeletalMesh '..path end,
        IsA=function(_,c) return c.path=='/Script/Engine.SkeletalMesh' end})
end
local bike_mesh,eve_mesh=mesh_asset(MESH),mesh_asset('/Game/Art/Character/PC/CH_P_EVE_01/Mesh/EVE.EVE')
-- The skeletons the rig's mesh is matched by (the riding clip's and her body mesh's are one), told by address.
local function skeleton(at) return uobj({GetAddress=function() return at end}) end
local eve_skeleton=skeleton(0x9001)
eve_mesh.Skeleton=eve_skeleton
-- The bike mesh's own material in each of its four slots (vehicles/bike/paint.lua makes its instances from them).
local own={}
bike_mesh.Materials={}
for slot=0,3 do own[slot]=uobj({}); bike_mesh.Materials[slot+1]={MaterialInterface=own[slot]} end
local by_path={}
StaticFindObject=function(path)
    if path=='/Script/Engine.Default__KismetMathLibrary' then return mathlib end
    if path:find('^/Script/') then return class(path) end
    if path==MESH then return bike_mesh end
    return by_path[path]
end
LoadAsset=function(path) error('nothing loads in a ride: '..path,0) end
-- A component of EVE's: its address, mesh, parent, place, visibility, tags; each write as an event.
local components=0
local function component(owner,mesh)
    components=components+1
    local n=components
    local c=uobj({SkeletalMesh=mesh,visible=true,ComponentTags={},forward={X=0,Y=1,Z=0}})
    function c:GetAddress() return 0x7000+n end
    function c:GetForwardVector() return self.forward end
    function c:K2_GetComponentLocation() return {X=0,Y=0,Z=3} end
    function c:K2_GetComponentRotation() return {Pitch=0,Yaw=0,Roll=0} end
    function c:ComponentHasTag(tag)
        for _,t in ipairs(self.ComponentTags) do if t:ToString()==tag:ToString() then return true end end
        return false
    end
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
    function c:SetComponentTickEnabled(v) self.tick_enabled=v end
    -- The paint: each instance made (made, by slot, with its base and values) and what each slot shows (current).
    c.made,c.current={},{}
    function c:CreateDynamicMaterialInstance(slot,base,name)
        assert(name:ToString()=='None')
        local mid=uobj({base=base,values={}})
        function mid:SetVectorParameterValue(k,v) self.values[k:ToString()]=v end
        self.made[slot],self.current[slot]=mid,mid
        return mid
    end
    function c:SetMaterial(slot,m) self.current[slot]=m end
    return c
end
-- EVE: her address and path, her main mesh (its relative rotation and location), her components, her movement and
-- SB's reads the checks make.
local addresses=0
local function make_eve(name)
    addresses=addresses+1
    local address=addresses
    local e=uobj({name=name,list={},added=0,skill=false,battle=false,root=false,sequence=false,interaction=false,
        block=false,fishing=0,tps=false,bEnableInteractionBlock=false,bFreeCamMode=false,
        mesh_at={X=0,Y=0,Z=0},base=nil,world_name='World /Game/Map/Map.Map',control_yaw=0,teleport_ok=true})
    local m=component(e,eve_mesh)
    m.RelativeRotation,m.RelativeLocation={Pitch=0,Yaw=-90,Roll=0},{X=0,Y=0,Z=-90}
    function m:K2_GetComponentLocation() return e.mesh_at end
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
    e.CapsuleComponent=uobj({GetUnscaledCapsuleRadius=function() return 35 end})
    -- A walkable flat floor; its read raises while floor_raises (a struct UE4SS would not read).
    local floor={bWalkableFloor=true,HitResult={ImpactNormal={X=0,Y=0,Z=1}}}
    -- Her movement base: her movement component's GetMovementBase, as in the game (her actor class has none).
    e.CharacterMovement=setmetatable(uobj({MovementMode=1,
        GetMovementBase=function() return e.base and uobj(e.base) end}),{__index=function(_,k)
        if k~='CurrentFloor' then return nil end
        if e.floor_raises then error('CurrentFloor unreadable',0) end
        return floor
    end})
    function e:GetWorld() return {GetFullName=function() return e.world_name end} end
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
    function e:K2_GetActorLocation() return {X=0,Y=0,Z=97} end
    function e:K2_GetActorRotation() return {Pitch=0,Yaw=0,Roll=0} end
    function e:GetControlRotation() return {Pitch=0,Yaw=self.control_yaw,Roll=0} end
    function e:K2_TeleportTo(at,rot)
        self.teleported={at=at,rot=rot}
        stand_order[#stand_order+1]='teleport'
        return self.teleport_ok
    end
    by_path['/Game/Map.Map:PersistentLevel.'..name]=e
    return e
end
local eve=make_eve('EVE_1')
-- UE4SS gives a new wrapper at each call: EVE is told by address.
local function wrapper(o) return o and setmetatable({},{__index=o,__newindex=o}) end
package.loaded.UEHelpers={GetPlayer=function() return wrapper(eve) end}
-- The native part: the asks (each an event) and the status line's words.
local st={warp='idle',anim='idle',id=0,load='off',gate='off',life=1}
local native=true
-- The record's key: the mod= and slot= lines use_key puts before the engine line; no_key takes them out.
local key_text=nil
local function use_key(text) key_text=text end
local function no_key() key_text=nil end
local status_reads=0
local function status()
    status_reads=status_reads+1
    if not native then return 'slot=coop x\n' end
    return (key_text or 'slot=coop x\n')
        ..('engine=on warp=%s me=1 travel=idle travel_calls=0 anim=%s anim_id=%d bike=%s bike_gate=%s%s\n')
        :format(st.warp,st.anim,st.id,st.load,st.gate,st.life and ' bike_life='..st.life or '')
end
-- o.file over files: a read counts in file_reads; a write lands in files and written, or fails with write_fails. lobby
-- is what o.lobby answers.
local files,written,file_reads,write_fails,lobby={},{},0,nil,false
local file={read=function(name) file_reads=file_reads+1; return files[name] end,
    write=function(name,text)
        if write_fails then return false,write_fails end
        files[name]=text
        written[#written+1]={name=name,text=text}
        return true
    end}
local asked,refuse={},{}
local function ask(line)
    if refuse[line:match('^%S+ %S+')] then return false,'the native part is off' end
    asked[#asked+1]=line
    event(line)
    return true,'asked the native part: '..line
end
-- vehicles/bike/drive.lua: on and off with why, its frames (the look it gives), its 250 ms checks.
local B=require('vehicles.bike.model')
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
    slow=function() dv.slows=dv.slows+1 end,restore=function()
        dv.restores=(dv.restores or 0)+1
        if dv.raise then error(dv.raise,0) end
    end}
local stored
local store={save=function(line)
        event('save')
        stored=line
        return true
    end,load=function() return stored end,clear=function() stored=nil end}
-- o.stand_store: save(path) sets stand_stored, load() returns it, clear() sets it nil.
local stand_stored
local stand_store={save=function(path) stand_stored=path; return true end,load=function() return stand_stored end,
    clear=function() stand_stored=nil end}
-- o.send: each bike line the ride hands the link, in sent; while send_fails it returns false and keeps nothing.
local sent,send_fails={},false
local function send(payload)
    if send_fails then return false end
    sent[#sent+1]=payload
    return true
end
local logs={}
local function log(m) logs[#logs+1]=m end
local function last() return logs[#logs] end
local function find(pattern) for _,l in ipairs(logs) do if l:find(pattern) then return l end end end
-- bike_pose=hold for today's cases up to section 23 (the hold way: the riding clip in her slot); section 24 has the rig.
local settings={bike_key={name='F3'},bike_pose='hold'}
local world={paused=false,photo='0',frozen=false,life=nil,armed=false,busy=nil}
-- vehicles/bike/stand.lua (vehicles/bike/stand_test tests it): each display made (st_made) with its place, shown,
-- removed, path and component (mesh); a hide also goes to stand_order; sweep records what it was asked (swept,
-- swept_mesh). It writes no event and no log.
local st_made,swept,swept_mesh={},{},{}
local stand_like=nil -- A component whose address and path the next display's component takes (a freed address).
package.loaded['vehicles.bike.stand']={CULL=20000,
    make=function(w,mesh,cull)
        assert(w and mesh==MESH,'In her world, with the bike mesh')
        local d={shown=false,cull=cull,path='/Game/Map.Map:PersistentLevel.Actor_'..(#st_made+1)}
        d.mesh=component({name='Actor_'..(#st_made+1)},bike_mesh) -- Its component, which the paint reaches.
        if stand_like then
            d.mesh.GetAddress,d.mesh.GetFullName,stand_like=stand_like.GetAddress,stand_like.GetFullName,nil
        end
        st_made[#st_made+1]=d
        return d
    end,
    put=function(d,place) d.place=place end,
    show=function(d,on)
        d.shown=on
        if not on then stand_order[#stand_order+1]='stand hide' end
    end,
    step=function() return nil end,
    alive=function(d) return not d.removed and d or nil end,
    remove=function(d) d.removed,d.shown=true,false end,
    sweep=function(path,mesh) swept[#swept+1],swept_mesh[#swept_mesh+1]=path,mesh end}
-- vehicles/bike/rig.lua (rig_test tests it): each rig made in rigs ({actor, path, mesh, skip, eve, mesh_path, clip};
-- worn: the mesh SetSkeletalMesh gave it; plays: PlayAnimation's calls after it; hooks: hook's calls; unhooked: what
-- unhook was given). make, hook, unhook, remove, release and a new mesh are events. rig_state: refuse (make raises
-- it), hook_raise (hook raises it), hooked (what hooked answers; a hook sets it true), failed (unhook's and release's
-- failed calls), released (what release was given), release_raise (release raises it), unswept (release finds no rig).
local rigs,rig_state={},{hooked=true}
package.loaded['vehicles.bike.rig']={
    make=function(e,mesh_path,clip,skip)
        if rig_state.refuse then error(rig_state.refuse,0) end
        local n=#rigs+1
        local d={path='/Game/Map.Map:PersistentLevel.Actor_Rig'..n,skip=skip,eve=e,mesh_path=mesh_path,clip=clip,
            hooks=0,plays=0}
        d.actor=uobj({GetFullName=function() return 'Actor '..d.path end})
        d.mesh=uobj({SetSkeletalMesh=function(_,m,reinit)
                assert(reinit==true)
                d.worn=m
                event('rig mesh')
            end,PlayAnimation=function(_,c,loop)
                assert(c==clip and loop==true,'The riding clip, looped')
                d.plays=d.plays+1
            end})
        rigs[n]=d
        event('rig')
        return d
    end,
    hook=function(e,d)
        if rig_state.hook_raise then error(rig_state.hook_raise,0) end
        d.hooks=d.hooks+1
        rig_state.hooked=true
        event('hook')
        return {'list '..d.hooks,'second part'},2
    end,
    unhook=function(e,d,list)
        d.unhooked={e=e,list=list}
        event('unhook')
        return 2,rig_state.failed or 0
    end,
    hooked=function() return rig_state.hooked end,
    remove=function(d)
        d.actor.gone=true
        event('rig gone')
    end,
    release=function(e,path,mesh_path,skip)
        rig_state.released={e=e,path=path,mesh_path=mesh_path,skip=skip}
        event('release')
        if rig_state.release_raise then error(rig_state.release_raise,0) end
        return 3,rig_state.failed or 0,not rig_state.unswept
    end}
local Ride=require('vehicles.bike.ride')
-- The screen's words (T.en until a test picks another table) and the notices told in them, with their English copies
-- (told_en, main.lua's for the line above EVE). o.game_text answers money and logs each ask (money_asks).
local T=require('ui.text')
local words,told,told_en=T.en,{},{}
local money,money_asks=nil,{}
-- o.camp: counts camp_asks, answers camp. o.fetch (vehicles/bike/fetch.lua): start counts fetch.starts; with
-- fetch.refuse set it returns false and fetch.refuse (busy() stays false), else busy() is true; step returns
-- fetch.result once (then busy() is false).
local camp,camp_asks=nil,0
local fetch={starts=0}
function fetch.start(t)
    assert(t==clock,'Started at os.clock()')
    fetch.starts=fetch.starts+1
    if fetch.refuse then return false,fetch.refuse end
    fetch.running=true
    return true
end
function fetch.busy() return fetch.running==true end
function fetch.step(t)
    assert(t==clock and fetch.running,'Stepped at os.clock(), while it runs')
    local r=fetch.result
    if not r then return nil end
    fetch.result,fetch.running=nil,false
    return table.unpack(r)
end
local function new()
    return Ride.new({log=log,ask=ask,status=status,store=store,stand_store=stand_store,drive=drive,settings=settings,
        paused=function() return world.paused end,photo=function() return world.photo end,
        frozen=function() return world.frozen end,life=function() return world.life end,
        armed=function() return world.armed end,busy=function() return world.busy end,
        drove=function() return world.drove end,
        words=function() return words end,
        tell=function(build) told[#told+1],told_en[#told_en+1]=build(words),build(T.en) end,
        game_text=function(key,path) money_asks[#money_asks+1]=key..' '..path; return money end,
        worlds={Xion='/game/art/bg/worldmap/level_p/e04'},file=file,lobby=function() return lobby end,send=send,
        camp=function(w,m)
            assert(w=='Xion' and m==10,'Xion within 10 m')
            camp_asks=camp_asks+1
            return camp
        end,fetch=fetch})
end
local R=new()
local CLIP='/Game/Art/Character/PC/CH_P_EVE_01/Animation/event/G03/MV_SD20_AfterBruteBattle_Main/eve/'
    ..'eve_bikeSleepPose.eve_bikeSleepPose'
-- The riding clip in memory (the native bike load keeps it), on her body mesh's skeleton.
local clip=uobj({Skeleton=eve_skeleton})
by_path[CLIP]=clip
local ok,why

-- 1. The status words; the preload's word as a refusal.
local w=Ride.native('engine=on warp=busy me=3 anim=ended anim_id=12 bike=failed:missing_clip '
    ..'bike_gate=refused:controller bike_life=4')
assert(w.warp=='busy' and w.anim=='ended' and w.id==12 and w.load=='failed:missing_clip'
    and w.gate=='refused:controller' and w.life==4)
assert(Ride.native('engine=on anim=idle anim_id=0 bike=ready bike_gate=off').life==nil,'Her life state unread')
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
assert(R.idle_part(eve:GetAddress())==nil,'No part to leave out yet')

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
assert(part.scale.X==1 and part.visible==false and find('^bike part ready on EVE %(made in [%d.]+ ms%)$'),last())
assert(#part.ComponentTags==1 and part.ComponentTags[1]:ToString()=='SBO_Bike' and Ride.TAG=='SBO_Bike',
    "Tagged as SBO's")
-- The part never ticks: made with its tick off and OnlyTickPoseWhenRendered (its reference pose needs no tick).
assert(part.tick_enabled==false and part.VisibilityBasedAnimTickOption==3)
clock=3
R.slow()
assert(eve.added==1 and #asked==1,'Made once')
-- The capture's leave_out: the part's address while she does not ride, asked with her EVE's address.
assert(R.idle_part(eve:GetAddress())==part:GetAddress() and R.idle_part(eve:GetAddress()+100)==nil)

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
-- Down: her own life state from the native part, on any save; link.life() (a session's) only when it did not read.
refused('EVE is down',function() st.life=4 end,function() st.life=1 end)
refused('EVE is down',function() st.life,world.life=nil,{state=4,hp=0} end,function() st.life,world.life=1,nil end)
refused('a race or the drive probe drives EVE',function() dv.on='probe' end,function() dv.on=false end)
-- The race's own drive (its copy since November 2026), read through drove().
refused('a race or the drive probe drives EVE',function() world.drove=true end,function() world.drove=false end)
-- A race armed before GO (a guest's whose Doro look failed): its drive would replace the bike's at GO.
refused('a race is armed: coop race quit leaves it',function() world.armed=true end,function() world.armed=false end)
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
    assert(find('^bike part ready on EVE %(found in'),last())
end
-- A tag that does not hold: the part kept for this Lua load, why logged once; only a Ctrl+R cannot find it.
do
    local lone=make_eve('EVE_4')
    local add=lone.AddComponentByClass
    lone.AddComponentByClass=function(self,...)
        local c=add(self,...)
        c.ComponentHasTag=function() return false end
        return c
    end
    eve=lone
    R.slow()
    clock=clock+2
    R.slow()
    assert(not lone.list[2].gone and logs[#logs-1]=='bike part tag SBO_Bike not written (it did not hold): a Ctrl+R '
        ..'will not find this part',logs[#logs-1])
    assert(logs[#logs-2]:find('^bike part ready on EVE %(made in'),logs[#logs-2])
    eve=real
    R.slow()
    clock=clock+2
    R.slow()
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
assert(R.idle_part(eve:GetAddress())==nil,'A part of the ghost while she rides')
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
assert(R.idle_part(eve:GetAddress())==part:GetAddress(),'Left out again once she is off')
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
local looks=math_looks
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
assert(math_looks==looks+1,'The math library looked up once per ride, not at each tilted frame')

-- 8. The riding clip: its answer read in the 250 ms pass, from that pass's status text; no frame reads the status.
-- Playing logged once; an end plays it again with a new id at the next pass, unless the photo mode, a skill or root
-- motion holds her.
local reads=status_reads
for _=1,30 do R.steer() end
assert(status_reads==reads,'No frame reads the status')
st.id,st.anim=id,'playing'
clock=clock+0.25
R.slow()
assert(last()==('bike ride clip plays (anim %d)'):format(id),last())
local n=#asked
st.anim='ended'
R.steer()
assert(#asked==n,'A frame never plays it again')
world.photo='1'
clock=clock+0.25
R.slow()
assert(#asked==n and R.riding() and last()==('bike ride clip ended (anim %d, 1 end(s) within 1 s)'):format(id),last())
world.photo='0'
eve.skill=true
clock=clock+0.25
R.slow()
assert(#asked==n,'A skill holds her')
eve.skill=false
eve.root=true
clock=clock+0.25
R.slow()
assert(#asked==n,'Root motion holds her')
eve.root=false
clock=clock+0.25
R.slow()
assert(asked[#asked]:find('^anim '),'Asked again at the next 250 ms pass')
local id2=tonumber(asked[#asked]:match('^anim play (%d+) '..CLIP:gsub('%p','%%%0')..' ride$'))
assert(#asked==n+1 and id2==id+1,asked[#asked])
-- No answer for the new id in 5 s: off.
clock=clock+4.9
R.slow()
assert(R.riding())
clock=clock+0.2
ok,why=R.slow()
assert(not ok and why=='Off the bike: no answer from the native part for the riding clip' and not R.riding(),why)
assert(R.idle_part(eve:GetAddress())==part:GetAddress(),'Left out again after a ride that ended on a fault')
assert(asked[#asked-1]=='anim stop' and asked[#asked]=='bike gate off' and stored==nil)
-- Three ends within 1 s: SB uses the slot.
id=mount()
for k=1,3 do
    st.id,st.anim=id+k-1,'ended'
    clock=clock+0.25
    ok,why=R.slow()
end
assert(not ok and why=='Off the bike: SB ended the riding clip 3 times within 1 s' and not R.riding(),why)
-- Ends further apart only play it again.
id=mount()
for k=1,4 do
    st.id,st.anim=id+k-1,'ended'
    clock=clock+0.6
    ok,why=R.slow()
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
    clock=clock+0.25
    ok,why=R.slow()
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
-- A race's drive in place of the bike's: off with that reason; the race's drive is left on.
id=mount()
dv.on='race'
ok,why=R.steer()
assert(not ok and why=='Off the bike: a race drive took over her driving' and not R.riding() and dv.on=='race',why)
dv.on=false

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
    {function() st.life=5 end,'EVE is down'},{function() st.life,world.life=nil,{state=3,hp=0} end,'EVE is down'},
    {function() eve.fishing=1 end,'EVE is fishing'}}) do
    id=mount()
    case[1]()
    ok,why=R.slow()
    world.photo,st.warp,eve.VehicleActor,world.life,st.life,eve.fishing='0','idle',nil,nil,1,0
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
-- The next mount of this Lua load keeps that file's base, not the lean her mesh still has; its dismount writes it.
eve.Mesh.RelativeRotation,eve.Mesh.RelativeLocation={Pitch=2,Yaw=-90,Roll=10},{X=0,Y=0,Z=-90}
id=mount()
assert(stored=='/Game/Map.Map:PersistentLevel.EVE_1\t0\t-90\t0\t0\t0\t-90',stored)
assert(find(' R=0%.00, location 0%.00 0%.00 %-90%.00 %(kept in coop%-bike%.txt%)$'))
R.toggle()
assert(stored==nil and eve.Mesh.RelativeRotation.Roll==0 and eve.Mesh.RelativeRotation.Pitch==0)
-- A file for another EVE is no base for her.
stored='/Game/Map.Map:PersistentLevel.EVE_9\t9\t9\t9\t9\t9\t9'
id=mount()
assert(stored=='/Game/Map.Map:PersistentLevel.EVE_1\t0\t-90\t0\t0\t0\t-90',stored)
eve.Mesh.locked=true
R.stop('coop off')
eve.Mesh.locked=nil

-- 11. The next Lua load: its first tick finds the part by its tag, hides it and names it for the capture before any
-- bike= word is read; coop-bike.txt puts her mesh back and hides the part, once, the file cleared; the part is used
-- again, not made. A path that is no EVE only clears the file.
eve.Mesh.RelativeRotation,eve.Mesh.RelativeLocation={Pitch=5,Yaw=-80,Roll=20},{X=1,Y=1,Z=1}
part.visible=true
local R2=new()
local n_logs=#logs
R2.restore()
assert(R2.idle_part(eve:GetAddress())==part:GetAddress(),"The earlier load's part, named from the first tick")
assert(logs[n_logs+1]=="bike part found on EVE (an earlier Lua load's), hidden",tostring(logs[n_logs+1]))
assert(stored==nil and eve.Mesh.RelativeRotation.Yaw==-90 and eve.Mesh.RelativeRotation.Roll==0)
assert(eve.Mesh.RelativeLocation.Z==-90 and not part.visible)
assert(last()=='bike restored from coop-bike.txt: her mesh back, the bike hidden',last())
assert(rig_state.released==nil and not find('^bike rig from'),'Seven fields: no rig to release')
stored='/Game/Gone\t0\t0\t0\t0\t0\t0'
R2.restore()
assert(stored~=nil,'Once a Lua load')
new().restore()
assert(stored==nil and last()=='bike restored from coop-bike.txt: her EVE is gone',last())
-- Its own drive comes back first (vehicles/bike/drive.lua's restore); one that raises is logged and the rest goes on.
local restores=dv.restores or 0
dv.raise,n_logs='coop-drive.txt unreadable',#logs
new().restore()
dv.raise=nil
assert((dv.restores or 0)==restores+1 and logs[n_logs+1]=='bike drive not restored: coop-drive.txt unreadable',
    tostring(logs[n_logs+1]))
assert(logs[n_logs+2]=="bike part found on EVE (an earlier Lua load's), hidden",tostring(logs[n_logs+2]))
local added=eve.added
n_logs=#logs
R2.slow()
clock=clock+2
R2.slow()
assert(eve.added==added and logs[n_logs+1]=='bike=on: asked the native part: bike load '..CLIP,logs[n_logs+1])
for k=n_logs+2,#logs do assert(not logs[k]:find('^bike part'),logs[k]) end
assert(R2.idle_part(eve:GetAddress())==part:GetAddress(),'The part it found, left out')
-- A value the file cannot give clears it. A mesh write that fails keeps it: the next mount takes her base from it.
stored='/Game/Map.Map:PersistentLevel.EVE_1\t0\tx\t0\t0\t0\t-90'
new().restore()
assert(stored==nil and last()=='bike restored from coop-bike.txt: failed (value 2 unreadable in the file)',last())
stored='/Game/Map.Map:PersistentLevel.EVE_1\t0\t-90\t0\t0\t0\t-90'
eve.Mesh.RelativeRotation={Pitch=2,Yaw=-90,Roll=10}
eve.Mesh.locked=true
new().restore()
eve.Mesh.locked=nil
assert(stored=='/Game/Map.Map:PersistentLevel.EVE_1\t0\t-90\t0\t0\t0\t-90' and eve.Mesh.RelativeRotation.Roll==10)
assert(last()=='bike restored from coop-bike.txt: failed (read only), coop-bike.txt kept',last())
id=mount()
assert(stored=='/Game/Map.Map:PersistentLevel.EVE_1\t0\t-90\t0\t0\t0\t-90',stored)
R.toggle()
assert(stored==nil and eve.Mesh.RelativeRotation.Roll==0)

-- 12. bike=off: off the bike, the part removed, the preload released, once; on again asks the load again.
id=mount()
settings.bike=false
R.slow()
assert(not R.riding() and find('^bike off %(bike=off%)') and part.gone and asked[#asked]=='bike free')
assert(R.idle_part(eve:GetAddress())==nil,'bike=off: no part')
assert(last()=='bike=off: asked the native part: bike free',last())
n=#asked
R.slow()
ok,why=R.toggle()
assert(#asked==n and not ok and why=='the bike is off (bike=off)' and last()=='bike refused: '..why,tostring(why))
settings.bike=nil
R.slow()
assert(asked[#asked]=='bike load '..CLIP)
-- That ask lost on the way (bike=off 5 s later): asked again, logged.
st.load='off'
n=#asked
clock=clock+4.9
R.slow()
assert(#asked==n,'Not before 5 s')
clock=clock+0.1
R.slow()
assert(#asked==n+1 and asked[#asked]=='bike load '..CLIP)
assert(last()=='bike=off 5 s after the bike load: asked again: asked the native part: bike load '..CLIP,last())
st.load='loading'
clock=clock+5
R.slow()
assert(#asked==n+1,'Not again while it loads')
st.load='ready'

-- 13. coop bike status and tune.
local said=R.status()
assert(said=='bike: preload ready, part not made yet, not riding; top=2306 accel=1150 brake_hardness=48 '
    ..'turn_angle=36; parked on /game/map/map, 0 m away; paint off for '
    ..'/Game/Art/Character/PC/CH_P_EVE_01/Mesh/EVE.EVE',said)
settle()
id=mount()
said=R.status()
assert(said:find('^bike: preload ready, part on EVE, riding for 0 s %(hold%); '),said)
R.toggle()
ok,said=R.tune('top','3000')
assert(ok and said=='Bike top=3000 from your next ride (this Lua load).')
ok,said=R.tune()
assert(ok and said=='bike: top=3000 accel=1150 brake_hardness=48 turn_angle=36',said)
assert(not R.tune('speed','1') and not R.tune('top','fast'))

-- 14. A Lua load whatever the bike= word: the first tick names the earlier load's part (its tag), so the capture leaves
-- it out with the preload at a fault; at bike=off the first 250 ms pass removes it. Another mod's component on the
-- bike's mesh, first in her component order and with no tag, is never taken for it: not hidden, named or removed. A
-- part is made beside it.
local sbo=eve.list[#eve.list]
assert(sbo.SkeletalMesh==bike_mesh and sbo.ComponentTags[1] and not sbo.gone)
assert(R.idle_part(eve:GetAddress())==sbo:GetAddress())
local theirs=component(eve,bike_mesh)
table.insert(eve.list,2,theirs)
st.load='fault'
local R3=new()
R3.restore()
assert(R3.idle_part(eve:GetAddress())==sbo:GetAddress() and theirs.visible,'Its own part, by its tag')
added=eve.added
for _=1,12 do
    R3.slow()
    clock=clock+0.25
end
assert(R3.idle_part(eve:GetAddress())==sbo:GetAddress() and eve.added==added and not sbo.gone,'Named at a fault')
settings.bike=false
local R4=new()
R4.restore()
assert(R4.idle_part(eve:GetAddress())==sbo:GetAddress())
n_logs=#logs
R4.slow()
assert(sbo.gone and not theirs.gone and theirs.visible and R4.idle_part(eve:GetAddress())==nil)
assert(logs[n_logs+1]=='bike part removed from EVE' and logs[n_logs+2]=='bike=off: asked the native part: bike free')
settings.bike=nil
st.load='ready'
local R5=new()
R5.restore()
assert(R5.idle_part(eve:GetAddress())==nil and theirs.visible,'Nothing of SBO\'s on her')
R5.slow()
clock=clock+2
R5.slow()
local made=eve.list[#eve.list]
assert(made~=theirs and made.ComponentTags[1] and eve.added==added+1,'Made beside it')
assert(find('^bike part ready on EVE %(made in') and R5.idle_part(eve:GetAddress())==made:GetAddress(),last())
assert(theirs.visible and not theirs.gone)

-- 16. The stand: one per EVE, made after her part under the same 2 s gate, hidden; a dismount by the key parks it
-- where she stands, shown; a forced one at the last ground pose; none kept on a Movable base; no pose keeps the place
-- before the mount; hidden while she rides or a cutscene holds her.
R=new(); local before=#st_made; eve=make_eve('EVE_15'); settle()
assert(#st_made==before+1 and st_made[#st_made].shown==false and find('^bike stand made in [%d.]+ ms$'))
local s=st_made[#st_made]
mount()
eve.mesh_at={X=100,Y=200,Z=0}
clock=clock+0.25; R.slow()
R.toggle()
assert(s.shown and s.place.map=='/game/map/map' and s.place.at.X==100 and s.place.rot.Yaw==90)
assert(find('^bike parked on /game/map/map at 100,200,0 %(here%)$'))
mount(); eve.mesh_at={X=500,Y=0,Z=0}; clock=clock+0.25; R.slow()
assert(s.shown==false,'Hidden while she rides')
eve.CharacterMovement.MovementMode=4; clock=clock+0.25
assert(select(1,R.slow())==false and s.place.at.X==500 and find('^bike parked on /game/map/map at 500,0,0 %(last ground%)$'))
eve.CharacterMovement.MovementMode=1
mount(); eve.base={Mobility=2}; eve.mesh_at={X=900,Y=0,Z=0}; clock=clock+0.25; R.slow()
eve.CharacterMovement.MovementMode=4; clock=clock+0.25; R.slow()
assert(s.place.at.X==500 and find('%(before the mount%)$'),'A lift is never a ground pose')
eve.CharacterMovement.MovementMode,eve.base=1,nil
eve.sequence=true; clock=clock+0.25; R.slow(); assert(s.shown==false)
eve.sequence=false; clock=clock+0.25; R.slow(); assert(s.shown==true)
-- CurrentFloor that does not read: walking on a fixed base counts, the yaw alone kept, one log line.
eve.mesh_at={X=500,Y=0,Z=0}; eve.floor_raises=true; mount(); clock=clock+0.25; R.slow(); R.toggle()
assert(s.place.rot.Pitch==0 and s.place.rot.Roll==0 and find('^bike floor: CurrentFloor not read'))
-- A new EVE on the same map (a respawn): the old stand removed before the new one is made.
local n=#st_made; eve=make_eve('EVE_16'); settle()
assert(s.removed and #st_made==n+1)

-- A dismount at at with the part's forward at yaw: she stands on her bike's place first when it shows here, mounts,
-- rides to at, gets off with the key, then walks back to the origin.
local function park_at(at,yaw)
    local shown=st_made[#st_made]
    if shown.shown then eve.mesh_at=shown.place.at end
    mount()
    eve.mesh_at=at
    eve.list[#eve.list].forward={X=math.cos(math.rad(yaw)),Y=math.sin(math.rad(yaw)),Z=0}
    R.toggle()
    eve.mesh_at={X=0,Y=0,Z=0}
end
-- A new Lua load whose EVE parks her bike where she stands on map, then a new EVE on /game/map/map, settled.
local function place_on(map)
    R=new()
    eve=make_eve('EVE_P'..addresses)
    eve.world_name='World '..map..'.Map'
    settle()
    mount()
    R.toggle()
    eve=make_eve('EVE_P'..addresses)
    settle()
end
-- 17. A mount with a place: refused far away (distance and side), on another map or before it is back; within reach
-- the stand hidden, her actor teleported so the part lands on it, then today's mount; a refused teleport mounts where
-- she stands; a failed mount shows the stand again; the prompt once each time she comes within reach.
park_at({X=4200,Y=0,Z=0},0)          -- helper: a dismount there, then she walks back to the origin
eve.mesh_at,eve.control_yaw={X=0,Y=0,Z=0},180
ok,why=R.toggle()
assert(not ok and why=='Your bike is 42 m away, behind you.' and last()=='bike refused: Your bike is 42 m away, behind you.')
-- Review Focus 4: one floor below, 0 cm across: out of reach, the 3D distance.
park_at({X=0,Y=0,Z=-300},0); eve.mesh_at,eve.control_yaw={X=0,Y=0,Z=0},0
ok,why=R.toggle(); assert(not ok and why=='Your bike is 3 m away, ahead of you.',why)
place_on('/game/art/bg/worldmap/level_p/e04')
ok,why=R.toggle()
assert(not ok and why=='Your bike is on another map: Xion.')
place_on('/game/map/map')
eve=make_eve('EVE_2'); R.slow(); clock=clock+1; R.slow()  -- back on the map, seen 1 s ago: under 2 s
ok,why=R.toggle(); assert(not ok and why=='Your bike is not back yet.')
clock=clock+1; R.slow()
park_at({X=100,Y=0,Z=0},90); eve.mesh_at={X=0,Y=0,Z=0}
stand_order={}
ok=R.toggle()
assert(ok and R.riding() and stand_order[1]=='stand hide' and stand_order[2]=='teleport' and find('^bike mount: onto the parked bike$'))
assert(eve.teleported.at.X==100 and eve.teleported.at.Y==0 and eve.teleported.at.Z==94 and eve.teleported.rot.Yaw==90)
R.toggle(); eve.teleport_ok=false; R.toggle()
assert(R.riding() and find('^bike mount: teleport refused, the bike came to her$')); eve.teleport_ok=true
R.toggle(); dv.refuse='no'; ok=R.toggle(); dv.refuse=nil
assert(not ok and st_made[#st_made].shown,'A failed mount shows the stand again')
-- Touching its nose, its tail or the front of a flank reaches it: its solid body stops her there, so the reach counts
-- from the body, not from the root.
for _,at in ipairs({{X=433,Y=0,Z=0},{X=-216,Y=0,Z=0},{X=300,Y=120,Z=0}}) do
    park_at({X=0,Y=0,Z=0},0); eve.mesh_at=at
    ok,why=R.toggle(); assert(ok and R.riding(),why); R.toggle()
end
-- The prompt: once on entering reach.
local n=#told
eve.mesh_at={X=1000,Y=0,Z=0}; clock=clock+0.25; R.slow()
eve.mesh_at={X=150,Y=0,Z=0}; clock=clock+0.25; R.slow(); clock=clock+0.25; R.slow()
assert(#told==n+1 and told[#told]=='F3: get on the bike')
-- Another language on screen, English in the log.
words=T.fr; park_at({X=4200,Y=0,Z=0},0); eve.mesh_at={X=0,Y=0,Z=0}
ok,why=R.toggle(); assert(why==T.fr.bike.far:format(42,T.fr.bike.ahead) and last():find('ahead of you'))

-- 18. The place per save. Read once per key; absent, readable and unreadable logged; a park written once; a failed write
-- kept in memory; put back on her return after 2 s; an SBO lobby starts with no place and writes nothing; status words.
-- A new Lua load first: every park so far had no key, so the first key would keep the last one (Review Focus 1 below).
R=new(); settle()
local ST='mod=v proto=22 steam=ready steamid=76561190000000000\nslot=coop index=2 marker=none saves=coop\n'
use_key(ST)
files['coop-bike-76561190000000000-coop2.txt']='1\t/game/map/map\t100\t0\t0\t0\t0\t0\n'
clock=clock+0.25; R.slow()
assert(find('^bike place: coop%-bike%-76561190000000000%-coop2%.txt: /game/map/map$') and file_reads==1)
clock=clock+0.25; R.slow(); assert(file_reads==1,'Read once per key')
mount(); R.toggle()
assert(written[1].name=='coop-bike-76561190000000000-coop2.txt' and written[1].text:find('^1\t/game/map/map\t'))
write_fails='disk full'; mount(); R.toggle()
assert(find('^bike place: write failed: disk full; kept in memory$') and not R.riding())
write_fails=nil
clock=math.ceil(clock) -- A whole clock, so 1.9 s then 0.1 s more make 2 s exactly in floating point.
eve=make_eve('EVE_3'); R.slow(); clock=clock+1.9; R.slow(); assert(not st_made[#st_made].shown)
clock=clock+0.1; R.slow(); assert(st_made[#st_made].shown and last():find('^bike put back on /game/map/map at '),last())
assert(R.status():find('parked on /game/map/map, 0 m away; paint off for /Game/',1,true))
-- Review Focus 1: another save loads during a ride: her park goes to the old save's file.
eve.mesh_at={X=0,Y=0,Z=0}; mount(); eve.mesh_at={X=300,Y=0,Z=0}; clock=clock+0.25; R.slow()
use_key((ST:gsub('index=2','index=3'))); eve=make_eve('EVE_4'); clock=clock+0.25; R.slow()
assert(written[#written].name=='coop-bike-76561190000000000-coop2.txt' and written[#written].text:find('\t300\t'),
    'The forced park of the save she rode in')
for _,w in ipairs(written) do assert(w.name~='coop-bike-76561190000000000-coop3.txt') end
clock=clock+0.25; R.slow(); assert(find('^bike place: coop%-bike%-76561190000000000%-coop3%.txt: none$'))
-- Review Focus 1 too: a park before any key is written at the first key read, not replaced by the file.
R=new(); no_key(); settle(); park_at({X=7,Y=0,Z=0},0)
files['coop-bike-76561190000000000-coop2.txt']='1\t/game/map/map\t100\t0\t0\t0\t0\t0\n'
use_key(ST); clock=clock+0.25; R.slow()
assert(written[#written].name=='coop-bike-76561190000000000-coop2.txt' and written[#written].text:find('^1\t/game/map/map\t7\t'))
assert(find('kept the park made before the key'))
-- An SBO lobby: no place (first ride under her), nothing written; leaving brings the save's place back.
lobby=true; clock=clock+0.25; R.slow(); assert(R.status():find('no place yet; paint off for /Game/',1,true))
local n=#written; mount(); R.toggle(); assert(#written==n)
lobby=false; clock=clock+0.25; R.slow(); assert(R.status():find('parked on /game/map/map'))
-- Unreadable file: none, logged.
use_key((ST:gsub('index=2','index=4'))); files['coop-bike-76561190000000000-coop4.txt']='junk'
clock=clock+0.25; R.slow(); assert(find(': unreadable, read as none$'))

-- 19. The stand's path kept for the next Lua load, swept at its first tick; Ctrl+R while riding parks at her feet when
-- the floor counts; coop off removes the stand and keeps the place; bike=off removes it, bike=on puts it back.
-- (o.stand_store: save(path) sets stand_stored, load() returns it, clear() sets it nil.)
local kept=stand_stored
assert(kept==st_made[#st_made].path)
local R2=new(); R2.restore()
assert(swept[#swept]==kept and swept_mesh[#swept]==MESH and stand_stored==nil)
eve.mesh_at={X=0,Y=0,Z=0}; mount(); local R3=new(); eve.mesh_at={X=33,Y=0,Z=0}; R3.restore(); R=R3; settle()
assert(find('^bike parked on /game/map/map at 33,0,0 %(here%)$') and written[#written].text:find('\t33\t'))
settings.bike=false; clock=clock+0.25; R.slow()
assert(st_made[#st_made].removed and R.status():find('parked on'))
settings.bike=true; st.load='ready'; clock=clock+0.25; R.slow(); clock=clock+2; R.slow()
assert(st_made[#st_made].shown and not st_made[#st_made].removed,'bike=on: put back at its place')
R.leave(); assert(st_made[#st_made].removed and stand_stored==nil and R.status():find('parked on'))

-- 20. Her bike line for the link (o.send): none first, park at a dismount, none at a mount, none at bike=off, the park
-- again at bike=on; a send that fails goes again at the next pass; nothing when nothing changed.
assert(sent[1]=='none')
-- Section 19's state first: the earlier load's drive off (vehicles/bike/drive.lua's restore does it after a Ctrl+R),
-- the stand R.leave took made again and shown at its place.
dv.on=false; clock=clock+0.25; R.slow()
eve.mesh_at={X=0,Y=0,Z=0}; mount(); R.toggle(); assert(sent[#sent]:find('^park /game/map/map 0 0 0 '))
local n=#sent; clock=clock+0.25; R.slow(); assert(#sent==n)
mount(); assert(sent[#sent]=='none')
R.toggle(); send_fails=true; mount(); send_fails=false; clock=clock+0.25; R.slow(); assert(sent[#sent]=='none')
R.toggle(); settings.bike=false; clock=clock+0.25; R.slow(); assert(sent[#sent]=='none')
settings.bike=true; clock=clock+0.25; R.slow(); assert(sent[#sent]:find('^park /game/map/map '))

-- 21. The paid fetch at a Xion camp (o.camp, o.fetch): a far or other-map refusal there offers it; a press within 5 s
-- pays; presses while it runs refuse; paid moves the place to where she stood at the offer; too little money and a
-- failure are said; never within reach, never in an SBO lobby, never away from a camp.
words,camp_asks=T.en,0
no_key(); eve.mesh_at={X=0,Y=0,Z=0}
camp='Xion_Camp_10'; place_on('/game/other')
ok,why=R.toggle()
assert(not ok and why=='Your bike is on another map: other. Press F3 again within 5 s to pay 500 betacrystal to bring it here.')
assert(camp_asks==1)
clock=clock+4.9; ok,why=R.toggle()
assert(ok and why=='Paying 500 betacrystal for your bike.' and fetch.starts==1)
assert(told[#told]=='Paying 500 betacrystal for your bike.','On screen: F3 and the pad show only refusals')
-- Review Focus 3: presses during the payment: no second start.
ok,why=R.toggle(); assert(not ok and why=='Paying 500 betacrystal for your bike.' and fetch.starts==1)
fetch.result={'paid'}; clock=clock+0.25; R.slow()
assert(st_made[#st_made].shown and told[#told]=='Your bike was brought here for 500 betacrystal.')
assert(find('^bike brought to Xion_Camp_10 for 500 betacrystal$') and sent[#sent]:find('^park /game/map/map 0 0 0 '))
-- Review Focus 2: within reach at the camp: a plain mount, the camp never asked, no charge.
local asks=camp_asks
assert(R.toggle() and R.riding() and camp_asks==asks and fetch.starts==1); R.toggle()
-- The window: a press after 5 s offers again; a press inside it pays; too little money and a failure are said.
place_on('/game/other'); R.toggle(); clock=clock+5.1; ok=R.toggle(); assert(not ok and fetch.starts==1)
assert(R.toggle()==true and fetch.starts==2)
fetch.result={'poor',120}; clock=clock+0.25; R.slow()
assert(told[#told]=='Not enough betacrystal: 500 needed, you carry 120.')
R.toggle(); R.toggle(); fetch.result={'failed','no answer from the native part'}; clock=clock+0.25; R.slow()
assert(fetch.starts==3 and told[#told]=='Your bike was not brought here. UE4SS.log says why.' and find('no answer from the native part'))
-- A start the fetch refuses (no FName, the native part off): unpaid at once, the why logged, no payment running.
R.toggle(); fetch.refuse='BetaCrystal has no FName'; ok,why=R.toggle(); fetch.refuse=nil
assert(not ok and why=='Your bike was not brought here. UE4SS.log says why.' and fetch.starts==4 and not fetch.busy())
assert(find('^bike fetch not started: BetaCrystal has no FName$'))
-- Review Focus 2: an SBO lobby (its own place, far away here): refused with no offer, the camp never asked.
lobby=true; clock=clock+0.25; R.slow(); park_at({X=4200,Y=0,Z=0},0); eve.mesh_at={X=0,Y=0,Z=0}; eve.control_yaw=0
asks=camp_asks; ok,why=R.toggle()
assert(not ok and why=='Your bike is 42 m away, ahead of you.' and camp_asks==asks and fetch.starts==4); lobby=false
-- Not at a Xion camp: the plain refusal.
camp=nil; place_on('/game/other'); ok,why=R.toggle(); assert(why=='Your bike is on another map: other.')
-- Another language on screen, English in the log.
words=T.fr; camp='Xion_Camp_10'; ok,why=R.toggle()
assert(why==T.fr.bike.other_map:format('other')..' '..T.fr.bike.offer:format('F3',500,'betacrystal')
    and last()=='bike refused: Your bike is on another map: other.',last())
-- SB's name for the money on the screen's words, from ItemStringTable's Item_BetaCrystal_Name; the log and the English
-- copy of another language keep betacrystal.
money='Or'; clock=clock+6; ok,why=R.toggle()
assert(why==T.fr.bike.other_map:format('other')..' '..T.fr.bike.offer:format('F3',500,'Or'),why)
assert(money_asks[#money_asks]=='Item_BetaCrystal_Name /Game/Local/Localize/ItemStringTable.ItemStringTable')
ok,why=R.toggle(); assert(ok and why=='Paiement de 500 Or pour votre moto.' and told[#told]==why)
assert(told_en[#told_en]=='Paying 500 betacrystal for your bike.')
assert(last()=='bike fetch asked at Xion_Camp_10 for 500 betacrystal')
ok,why=R.toggle(); assert(not ok and why=='Paiement de 500 Or pour votre moto.')
assert(last()=='bike refused: Paying 500 betacrystal for your bike.')
fetch.result={'poor',120}; clock=clock+0.25; R.slow()
assert(told[#told]=='Or insuffisant : 500 requis, vous en avez 120.')
assert(told_en[#told_en]=='Not enough betacrystal: 500 needed, you carry 120.')
-- A name over 32 bytes: betacrystal.
words,money=T.en,('Ж'):rep(17); clock=clock+6; ok,why=R.toggle()
assert(why=='Your bike is on another map: other. Press F3 again within 5 s to pay 500 betacrystal to bring it here.')
-- A 32-byte name after a 32-byte map name passes Russian's 200 bytes: the offer says betacrystal.
words,money=T.ru,('Ж'):rep(16); place_on('/game/'..('m'):rep(32)); ok,why=R.toggle()
assert(why==T.ru.bike.other_map:format(('m'):rep(32))..' '..T.ru.bike.offer:format('F3',500,'betacrystal'),why)
-- The English screen: SB's English name in both copies.
words,money=T.en,'Gold'; place_on('/game/other'); ok,why=R.toggle()
assert(why=='Your bike is on another map: other. Press F3 again within 5 s to pay 500 Gold to bring it here.',why)
ok,why=R.toggle(); assert(ok and why=='Paying 500 Gold for your bike.' and told_en[#told_en]==why)
fetch.result={'poor',120}; clock=clock+0.25; R.slow()
assert(told[#told]=='Not enough Gold: 500 needed, you carry 120.' and told_en[#told_en]==told[#told])
money=nil
-- On a Movable base (no pose a park takes) the fetch brings it to her feet with her actor's yaw.
clock=clock+6; eve.base={Mobility=2}; eve.mesh_at={X=5,Y=0,Z=0}; R.toggle(); eve.base=nil
assert(R.toggle()==true); fetch.result={'paid'}; clock=clock+0.25; R.slow()
assert(sent[#sent]=='park /game/map/map 5 0 0 0 0 0',sent[#sent])
assert((dv.restores or 0)>=1,'Each ride\'s restore puts its own drive back first')

-- 22. The paint (vehicles/bike/paint.lua; paint_test tests it): with EVE's main mesh showing the example entry's key, a
-- pass one second after the part and the stand are made gives both an instance on its slot, made from the bike mesh's
-- own material; another outfit puts that material back; coop off (self.leave) puts it back on the part; coop bike
-- status ends with paint on for that key, or paint off for the whole path of a mesh with no entry.
local Paint=require('vehicles.bike.paint')
local KEY=next(Paint.BY_MESH)
local SLOT=next(Paint.BY_MESH[KEY])
local NAME,COLOUR=next(Paint.BY_MESH[KEY][SLOT])
local rose=mesh_asset(KEY)
R=new(); eve=make_eve('EVE_9'); eve.Mesh.SkeletalMesh=rose
clock=clock+0.25; settle()
local p9,s9=eve.list[2],st_made[#st_made]
assert(p9 and p9.SkeletalMesh==bike_mesh and s9.mesh,'The part and the stand are made')
clock=clock+1; R.slow()
for _,c in ipairs({p9,s9.mesh}) do
    local mid=c.made[SLOT]
    assert(mid and mid.base==own[SLOT] and c.current[SLOT]==mid,'An instance on the slot, from its own material')
    assert(mid.values[NAME].R==COLOUR[1] and mid.values[NAME].G==COLOUR[2] and mid.values[NAME].A==COLOUR[4])
end
said=R.status()
assert(said:sub(-#('; paint on for '..KEY))=='; paint on for '..KEY,said)
eve.Mesh.SkeletalMesh=eve_mesh; clock=clock+1; R.slow()
assert(p9.current[SLOT]==own[SLOT] and s9.mesh.current[SLOT]==own[SLOT],'Another outfit: the own material back')
said=R.status()
local off_word='; paint off for /Game/Art/Character/PC/CH_P_EVE_01/Mesh/EVE.EVE' -- The whole path a modder copies.
assert(said:sub(-#off_word)==off_word,said)
eve.Mesh.SkeletalMesh=rose; clock=clock+1; R.slow(); assert(p9.current[SLOT]~=own[SLOT])
R.leave(); assert(p9.current[SLOT]==own[SLOT],'coop off: the part back to its own material')
eve.Mesh.SkeletalMesh=nil; assert(R.status():find('; paint off %(no body mesh read%)$'))
-- 23. After coop off, the next parked bike takes the freed address and path of the one coop off removed, which was
-- painted for this outfit: it is painted too, never taken for the old one.
stand_like=s9.mesh
eve.Mesh.SkeletalMesh=rose; clock=clock+1; R.slow()
local s10=st_made[#st_made]
assert(s10~=s9 and s10.mesh:GetAddress()==s9.mesh:GetAddress() and s10.mesh:GetFullName()==s9.mesh:GetFullName())
assert(s10.mesh.made[SLOT] and s10.mesh.current[SLOT]==s10.mesh.made[SLOT],'The new parked bike is painted')

-- 24. The rig way, bike_pose's default. The mount in its order: the file, the drive, the gate, the rig made in her body
-- mesh with the clip and the bike part's address left out, the file again with fields 8 and 9, the hook, the part
-- shown; no clip asked of the native part. The dismount backward: the part hidden, the rig unhooked from the hook's
-- list then removed, the gate off, the drive off, her mesh back, the file cleared.
settings.bike_pose=nil
R=new(); eve=make_eve('EVE_R'); settle()
local rpart=eve.list[2]
local function on_rig()
    events={}
    local n_asked=#asked
    ok,why=R.toggle()
    assert(ok and R.riding(),tostring(why))
    assert(#asked==n_asked+1 and asked[#asked]=='bike gate on','No clip asked of the native part')
    return rigs[#rigs]
end
local rig=on_rig()
order={'save','drive on bike','bike gate on','rig','save','hook','show'}
for k,e in ipairs(order) do assert(events[k]==e,k..': '..tostring(events[k])) end
assert(#events==#order and rpart.visible)
local BODY='/Game/Art/Character/PC/CH_P_EVE_01/Mesh/EVE.EVE'
assert(rig.eve:GetAddress()==eve:GetAddress() and rig.mesh_path==BODY and rig.clip==clip
    and rig.skip==rpart:GetAddress())
local LINE='/Game/Map.Map:PersistentLevel.EVE_R\t0\t-90\t0\t0\t0\t-90'
assert(stored==LINE..'\t'..rig.path..'\t'..BODY,'Fields 8 and 9: the rig and its mesh')
assert(find('^bike rig made in [%d.]+ ms wearing '..BODY:gsub('%p','%%%0')..': her body and 2 of 2 part%(s%) follow it$'))
assert(R.status():find(', riding for 0 s %(rig%); '),R.status())
R.toggle()
order={'hide','unhook','rig gone','bike gate off','drive off','mesh back'}
for k,e in ipairs(order) do assert(events[7+k]==e,k..': '..tostring(events[7+k])) end
assert(#events==7+#order and stored==nil and not R.riding() and rig.actor.gone)
assert(rig.unhooked.e:GetAddress()==eve:GetAddress() and rig.unhooked.list[1]=='list 1','The hook\'s list')
-- The last log line that starts with start.
local function latest(start) for k=#logs,1,-1 do if logs[k]:sub(1,#start)==start then return logs[k] end end end
assert(latest('bike rig unhooked')=='bike rig unhooked: 2 part(s) back to her body'
    and last():find('^bike off %(coop bike%)'))
-- An unhook with calls that failed says how many.
rig_state.failed=1; on_rig(); R.toggle(); rig_state.failed=nil
assert(latest('bike rig unhooked')=='bike rig unhooked: 2 part(s) back to her body, 1 call(s) failed')

-- The setting, read at each mount: hold plays the clip in her slot with no rig; a word that is neither is the rig, said
-- once; a change during a ride counts from the next mount.
settings.bike_pose='hold'
local made=#rigs
events={}
assert(R.toggle() and asked[#asked]:find('^anim play %d+ ') and #rigs==made)
R.toggle()
settings.bike_pose='puppet'
on_rig(); R.toggle()
assert(#rigs==made+1 and find('^bike_pose=puppet is neither rig nor hold: the rig$'))
local function told_pose()
    local n=0
    for _,l in ipairs(logs) do if l:find('^bike_pose=') then n=n+1 end end
    return n
end
local said_n=told_pose()
on_rig(); R.toggle()
assert(said_n==1 and told_pose()==1 and #rigs==made+2,'Said once')
settings.bike_pose=nil
rig=on_rig()
assert(told_pose()==1,'No setting: the rig, nothing said')
settings.bike_pose='hold'
local n_asked=#asked
clock=clock+0.25; R.slow()
assert(R.riding() and #asked==n_asked,'The ride keeps its rig')
R.toggle()
assert(rig.actor.gone and R.toggle() and asked[#asked]:find('^anim play %d+ '),'The next mount holds the clip')
R.toggle()
settings.bike_pose=nil

-- Every 250 ms: the rig gone ends the ride.
rig=on_rig()
rig.actor.gone=true
clock=clock+0.25; ok,why=R.slow()
assert(not ok and why=='Off the bike: the riding rig is gone' and not R.riding(),why)
-- Her main mesh found off the rig: hooked again once; again 1 s or more later: hooked again; again within 1 s: off.
rig=on_rig()
rig_state.hooked=false
clock=clock+0.25; ok=R.slow()
assert(ok==nil and R.riding() and rig.hooks==2,'Hooked again')
assert(last()=='bike rig: her body had left it: hooked again, her body and 2 of 2 part(s) follow it',last())
rig_state.hooked=false
clock=clock+1; ok=R.slow()
assert(ok==nil and R.riding() and rig.hooks==3,'1 s later: hooked again')
rig_state.hooked=false
clock=clock+0.25; ok,why=R.slow()
assert(not ok and why=='Off the bike: her body left the riding rig twice within 1 s' and rig.hooks==3,why)
assert(rig.unhooked and rig.actor.gone)

-- An outfit on the clip's skeleton: the rig wears it, played again, field 9 written, every part hooked again.
local SUIT='/Game/Art/Character/PC/CH_P_EVE_01/Mesh/Suit.Suit'
local suit=mesh_asset(SUIT)
suit.Skeleton=eve_skeleton
rig=on_rig()
eve.Mesh.SkeletalMesh=suit
events={}
clock=clock+0.25; ok=R.slow()
assert(ok==nil and R.riding() and rig.worn==suit and rig.plays==1 and rig.hooks==2)
assert(events[1]=='rig mesh' and events[2]=='save' and events[3]=='hook',tostring(events[1]))
assert(stored==LINE..'\t'..rig.path..'\t'..SUIT,stored)
assert(last()=='bike rig: her outfit changed to '..SUIT..': the rig wears '..SUIT..', her body and 2 of 2 part(s) '
    ..'follow it',last())
clock=clock+0.25; R.slow()
assert(rig.hooks==2,'Once a change')
-- An outfit on another skeleton with no spare body in memory or on this PC: off with why.
local ALIEN='/Game/Art/Character/NPC/Other/Other.Other'
local alien=mesh_asset(ALIEN)
alien.Skeleton=skeleton(0x9002)
eve.Mesh.SkeletalMesh=alien
clock=clock+0.25; ok,why=R.slow()
assert(not ok and why=="Off the bike: her outfit's body and the spare body are on another skeleton than the riding "
    .."clip" and rig.actor.gone,why)
made=#rigs
ok,why=R.toggle()
assert(not ok and why=="her outfit's body and the spare body are on another skeleton than the riding clip"
    and #rigs==made and not R.riding(),why)
-- With the spare body: the rig wears it from the mount; back to her own body when an outfit fits; the spare again for
-- another outfit that does not; one more that does not keeps the spare, hooked again with nothing written.
local spare=mesh_asset(Ride.SPARE)
spare.Skeleton=eve_skeleton
by_path[Ride.SPARE]=spare
rig=on_rig()
assert(Ride.SPARE=='/Game/Art/Character/PC/CH_P_EVE_InnerSuit/CH_P_EVE_InnerSuit.CH_P_EVE_InnerSuit')
assert(rig.mesh_path==Ride.SPARE and stored==LINE..'\t'..rig.path..'\t'..Ride.SPARE,stored)
eve.Mesh.SkeletalMesh=eve_mesh
clock=clock+0.25; R.slow()
assert(R.riding() and rig.worn==eve_mesh and stored:sub(-#BODY)==BODY)
local ALIEN2='/Game/Art/Character/NPC/Other/Other2.Other2'
local alien2=mesh_asset(ALIEN2)
alien2.Skeleton=skeleton(0x9003)
eve.Mesh.SkeletalMesh=alien2
clock=clock+0.25; R.slow()
assert(R.riding() and rig.worn==spare and stored:sub(-#Ride.SPARE)==Ride.SPARE and rig.hooks==3)
eve.Mesh.SkeletalMesh=alien
events={}
clock=clock+0.25; R.slow()
assert(R.riding() and rig.hooks==4 and #events==1 and events[1]=='hook','The spare kept')
R.toggle()
eve.Mesh.SkeletalMesh=eve_mesh

-- A mount that fails on the rig way: a rig that cannot be made (nothing to unhook); her main mesh refusing the hook
-- or the file's second write failing (the rig unhooked and removed); the clip not in memory. Each refused with why.
rig_state.refuse='the rig could not be spawned'
events={}
ok,why=R.toggle()
assert(not ok and why=='the rig could not be spawned' and not R.riding() and stored==nil,why)
order={'save','drive on bike','bike gate on','bike gate off','drive off','mesh back'}
for k,e in ipairs(order) do assert(events[k]==e,k..': '..tostring(events[k])) end
assert(#events==#order)
rig_state.refuse=nil
rig_state.hook_raise='her main mesh refused'
events={}
ok,why=R.toggle()
rig_state.hook_raise=nil
rig=rigs[#rigs]
assert(not ok and why=='her main mesh refused' and events[4]=='rig' and events[6]=='unhook' and rig.actor.gone,why)
local saves,real_save=0,store.save
store.save=function(line)
    saves=saves+1
    if saves==2 then return false,'disk full' end
    return real_save(line)
end
events={}
ok,why=R.toggle()
store.save=real_save
rig=rigs[#rigs]
assert(not ok and why=='coop-bike.txt could not be written: disk full' and rig.actor.gone and rig.hooks==0,why)
assert(events[4]=='rig' and events[5]=='unhook' and stored==nil,tostring(events[5]))
by_path[CLIP]=nil
made=#rigs
ok,why=R.toggle()
by_path[CLIP]=clip
assert(not ok and why=='the riding clip is not in memory' and #rigs==made,why)
-- Her EVE gone with the map: off, the unhook given no EVE (it calls nothing), the rig removed.
rig=on_rig()
local gone_eve=eve
gone_eve.gone=true
eve=make_eve('EVE_R2')
ok,why=R.slow()
assert(not ok and why=='Off the bike: her EVE changed' and rig.unhooked.e==nil and rig.actor.gone,why)
gone_eve.gone=nil

-- 25. The next Lua load after a rig ride (Ctrl+R): fields 8 and 9 name the rig. Her body and parts come off it and it
-- is swept (vehicles/bike/rig.lua's release: her EVE, the rig's path and mesh, the bike part left out), then her mesh
-- goes back as for any ride. A release that raises or finds no rig is logged and the rest goes on. A hold ride's file
-- (seven fields) releases nothing.
settle()
rpart=eve.list[2]
local function reload()
    events={}
    rig_state.released=nil
    local again=new()
    again.restore()
    dv.on=false -- The earlier load's drive off, as vehicles/bike/drive.lua's restore leaves it.
    return again
end
rig=on_rig()
eve.Mesh.RelativeRotation={Pitch=3,Yaw=-90,Roll=7}
local R6=reload()
local rel=rig_state.released
assert(rel.e:GetAddress()==eve:GetAddress() and rel.path==rig.path and rel.mesh_path==BODY
    and rel.skip==rpart:GetAddress(),'Her EVE, the rig and its mesh, the bike part left out')
order={'hide','release','mesh back','hide'}
for k,e in ipairs(order) do assert(events[k]==e,k..': '..tostring(events[k])) end
assert(#events==#order and stored==nil and eve.Mesh.RelativeRotation.Roll==0)
assert(find('^bike rig from coop%-bike%.txt: 3 part%(s%) back to her body, swept$'))
assert(last()=='bike restored from coop-bike.txt: her mesh back, the bike hidden',last())
R=R6; settle()
rig=on_rig()
rig_state.failed,rig_state.unswept=2,true
reload()
rig_state.failed,rig_state.unswept=nil,nil
assert(latest('bike rig from')=='bike rig from coop-bike.txt: 3 part(s) back to her body, 2 call(s) failed, '
    ..'no rig at its path' and stored==nil)
R=new(); R.restore(); settle()
rig=on_rig()
rig_state.release_raise='her actor does not read'
reload()
rig_state.release_raise=nil
assert(latest('bike rig from')=='bike rig from coop-bike.txt not released: her actor does not read')
assert(stored==nil and last()=='bike restored from coop-bike.txt: her mesh back, the bike hidden',last())
R=new(); R.restore(); settle()
settings.bike_pose='hold'
assert(R.toggle() and not stored:find('\t.*\t.*\t.*\t.*\t.*\t.*\t'),'Seven fields')
reload()
settings.bike_pose=nil
assert(rig_state.released==nil and events[2]=='mesh back' and stored==nil,tostring(events[2]))
R=new(); R.restore(); settle()

-- 26. Photo mode: a dismount there unhooks at once and keeps the rig; it goes at the first 250 ms pass with photo mode
-- closed, once. The selfie mode and the friend's photo mode that holds our game count too. At bike=off the pass still
-- removes it after photo mode closes.
rig=on_rig()
world.photo='1'
events={}
R.toggle()
order={'hide','unhook','bike gate off','drive off','mesh back'}
for k,e in ipairs(order) do assert(events[k]==e,k..': '..tostring(events[k])) end
assert(#events==#order and not rig.actor.gone and not R.riding() and stored==nil)
assert(find('^bike rig kept until photo mode closes$'))
clock=clock+0.25; R.slow()
assert(not rig.actor.gone,'Photo mode still open')
world.photo='0'
events={}
clock=clock+0.25; R.slow()
assert(rig.actor.gone and events[1]=='rig gone' and find('^bike rig removed: photo mode closed$'))
local removed=0
for _,l in ipairs(logs) do if l=='bike rig removed: photo mode closed' then removed=removed+1 end end
clock=clock+0.25; R.slow()
local now_removed=0
for _,l in ipairs(logs) do if l=='bike rig removed: photo mode closed' then now_removed=now_removed+1 end end
assert(removed==1 and now_removed==1,'Once')
for _,hold in ipairs({{photo='s'},{frozen=true}}) do
    rig=on_rig()
    world.photo,world.frozen=hold.photo or '0',hold.frozen or false
    if hold.photo then -- The selfie mode ends the ride at the 250 ms check.
        clock=clock+0.25; ok,why=R.slow()
        assert(not ok and why=='Off the bike: the selfie mode is open',why)
    else
        R.toggle()
    end
    assert(not R.riding() and not rig.actor.gone)
    clock=clock+0.25; R.slow()
    assert(not rig.actor.gone)
    world.photo,world.frozen='0',false
    clock=clock+0.25; R.slow()
    assert(rig.actor.gone)
end
rig=on_rig()
world.photo='1'
settings.bike=false
clock=clock+0.25; R.slow()
assert(not R.riding() and not rig.actor.gone and find('^bike off %(bike=off%)'))
world.photo='0'
clock=clock+0.25; R.slow()
settings.bike=nil
assert(rig.actor.gone,'Removed at bike=off once photo mode closed')
print('ride_test ok')
