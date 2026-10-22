-- race/doro.lua with fake UE4SS objects: Doro.pick's mapping (blend space input and play rate from the speed, all fours
-- while sprinting with its hold, the ghost's speed threshold with its hysteresis, take-off, a held fall and landing,
-- emotes only while standing, the smoothing; while a race drives, all fours by the top speed, the faster play rate,
-- the stumble, the lean and the landing pitch), Doro.apply's calls, Doro.remove (only the actor spawn made); the look
-- (only parts not already hidden are hidden, listed and written to coop-look.txt before EVE changes; the Doro placed at
-- her main mesh each frame; the 250 ms check hides again and counts, and logs the flags the game changed; off clears
-- only those parts and restores the tick option, and keeps the file when a step fails; a map change turns it off, with
-- no call on an object that took the place of one it met; its first error turns it off until the mod reloads; a restore
-- from an earlier Lua load's file; a stale path only clears the file; the race's emote while she stands) and the
-- probe's steps and lines. Each Doro's keepers (one hidden, non-ticking component a clip, which holds it), Doro.detach,
-- and with a fake collector that drops what no live component holds, no clip loaded again while a Doro stands. The
-- drone that follows EVE: hidden only when shown, recorded in coop-look.txt, shown again on each way out and by the
-- next Lua load, and no other character touched.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
local function fname(t) return {type=function() return 'FName' end,ToString=function() return t end} end
FName=fname
local next_address=0x1000
local function object(fields)
    next_address=next_address+0x100
    local at=next_address
    local o=fields or {}
    o.type=function() return 'UObject' end
    o.IsValid=o.IsValid or function(self) return not self.destroyed end
    o.GetAddress=function() return at end
    return o
end
local invalid=object({destroyed=true})
local function class(path) return object({path=path,MakeTransform=function() return 'identity' end}) end
-- The assets: Doro's mesh and its clips, each found by path (some only through LoadAsset).
local assets,loads={},{}
local player -- What UEHelpers.GetPlayer() gives.
package.loaded.UEHelpers={GetPlayer=function() return player end}
local Doro=require('race.doro')
for key,path in pairs(Doro.ASSETS) do
    local kind=key=='mesh' and 'SkeletalMesh' or key:match('^two$') and 'BlendSpace1D' or 'AnimSequence'
    assets[path]=object({key=key,GetFullName=function() return kind..' '..path end,
        IsA=function(_,c)
            return c.path==(key=='mesh' and '/Script/Engine.SkeletalMesh' or '/Script/Engine.AnimationAsset')
        end,
        GetBounds=function() return {BoxExtent={X=23.3,Y=17.2,Z=19.8}} end})
end
local by_path={} -- Objects StaticFindObject finds by path (EVE, an earlier Doro), beside classes and assets.
local unloaded={[Doro.ASSETS.four]=true} -- Assets not in memory: only LoadAsset brings them.
StaticFindObject=function(path)
    if by_path[path] then return by_path[path] end
    if path:find('^/Script/') then return class(path) end
    if unloaded[path] then return invalid end
    return assets[path] or invalid
end
LoadAsset=function(path) loads[#loads+1]=path; unloaded[path]=nil; return assets[path] or invalid end
local fail_anim=false -- SetAnimation refuses: a keeper cannot be made.
-- A Doro component: its calls in order, as words.
local function component(actor)
    local c=object({calls={},actor=actor})
    local function said(...)
        local words={...}
        for k,w in ipairs(words) do if math.type(w)=='float' then words[k]=string.format('%g',w) end end
        c.calls[#c.calls+1]=table.concat(words,' ')
    end
    function c:K2_AttachToComponent(parent) self.parent=parent; said('attach') end
    function c:SetVisibility(on,children) assert(children==false); self.visible=on; said('visible',tostring(on)) end
    function c:SetComponentTickEnabled(on) self.ticks=on; said('tick',tostring(on)) end
    function c:SetAnimation(a) if fail_anim then error('no animation') end self.anim=a; said('anim',a.key) end
    function c:SetSkeletalMesh(m) self.mesh,self.SkeletalMesh=m,m; said('mesh',m.key) end
    function c:SetRelativeScale3D(v) self.scale=v; said('scale',v.X) end
    function c:SetCollisionEnabled(n) said('collision',n) end
    function c:SetAnimationMode(n) said('mode',n) end
    function c:K2_SetWorldLocationAndRotation(at,r,sweep,_,teleport)
        assert(sweep==false)
        self.at,self.rot,self.teleport=at,r,teleport
    end
    function c:PlayAnimation(a,loop) self.anim=a; said('play',a.key,tostring(loop)) end
    function c:GetAnimInstance()
        return {SetBlendSpaceInput=function(_,v) assert(v.Y==0 and v.Z==0); said('input',v.X) end,
            GetClass=function() return {GetFName=function() return fname('AnimSingleNodeInstance') end} end}
    end
    function c:SetPlayRate(r) said('rate',r) end
    function c:SetPosition(at,notifies) assert(notifies==false,'Never notifies'); self.position=at; said('at',at) end
    function c:GetPosition() return self.position or 0 end
    function c:K2_GetComponentScale() return self.scale end
    function c:K2_DestroyComponent(owner)
        assert(owner==actor,'DestroyComponent takes the owner')
        self.destroyed=true
    end
    function c:IsA(k) return k.path=='/Script/Engine.SkeletalMeshComponent' end
    return c
end
local spawned={}
local world=object({SpawnActor=function(_,c,at,rot)
    assert(c.path=='/Script/Engine.Actor','A plain Actor only')
    local a=object({components={}})
    function a:SetActorEnableCollision(on) self.collision=on end
    function a:AddComponentByClass(k,manual,transform,deferred)
        assert(k.path=='/Script/Engine.SkeletalMeshComponent' and type(manual)=='boolean' and transform=='identity'
            and deferred==false)
        local added=component(self)
        added.manual=manual -- The display on the root, a keeper unattached.
        self.components[#self.components+1]=added
        return added
    end
    function a:K2_GetRootComponent() return self.components[1] end
    function a:K2_DestroyActor() self.destroyed=true end
    local n=#spawned+1
    function a:GetFullName() return 'Actor /Game/Map.Map:PersistentLevel.Actor_'..n end
    a.spawned_at,a.spawned_rot=at,rot
    spawned[n]=a
    return a
end,GetFullName=function() return 'World /Game/Art/BG/WorldMap/Level_P/E04.E04' end})
-- A mesh component of EVE's: hidden (bHiddenInGame) or not, visible (bVisible) or not; its writes counted.
local function part(name,hidden,visible)
    local p=object({name=name,bHiddenInGame=hidden,bVisible=visible~=false,writes=0})
    function p:GetFName() return fname(name) end
    function p:SetHiddenInGame(on,children)
        assert(children==false,'Never its children')
        self.bHiddenInGame,self.writes=on,self.writes+1
    end
    return p
end
-- EVE: her body (the main mesh, tick option 3: OnlyTickPoseWhenRendered), face, hair, a ponytail the game hides
-- itself and a sheathed blade (bVisible off, bHiddenInGame off).
local function eve_of(name)
    local e=object({velocity={X=0,Y=0,Z=0},sprint=false,falling=false})
    e.parts={part('CharacterMesh0',false),part('Mesh_Face',false),part('SBHair',false),part('SBPonytail',true),
        part('Blade',false,false)}
    for _,p in ipairs(e.parts) do
        function p:GetFullName() return 'MeshComponent /Game/Map.Map:PersistentLevel.'..name..'.'..self.name end
    end
    e.Mesh=e.parts[1]
    e.Mesh.VisibilityBasedAnimTickOption=3
    e.Mesh.K2_GetComponentLocation=function() return {X=10,Y=20,Z=-87} end
    e.Mesh.K2_GetComponentRotation=function() return {Pitch=0,Yaw=0,Roll=0} end
    e.CharacterMovement=object({IsFalling=function() return e.falling end})
    function e:IsA(k) return k.path=='/Script/SB.SBCharacter' end
    function e:GetFullName() return 'CH_P_EVE_01_Blueprint_C /Game/Map.Map:PersistentLevel.'..name end
    function e:GetWorld() return world end
    function e:K2_GetActorRotation() return {Pitch=0,Yaw=90,Roll=0} end
    function e:K2_GetActorLocation() return {X=10,Y=20,Z=0} end
    function e:K2_GetComponentsByClass(k)
        assert(k.path=='/Script/Engine.MeshComponent')
        return self.parts
    end
    function e:GetVelocity() if self.broken then error('no velocity') end return self.velocity end
    function e:IsSprint() return self.sprint end
    function e:GetSBSpeedForAnimGraph() return 512.4 end
    return e
end
local eve=eve_of('EVE_1')
player=eve
-- What FindAllOf('SBCharacter') gives: EVE, then the characters a test adds (the drone and others).
local characters={eve}
FindAllOf=function(name) assert(name=='SBCharacter',name); return characters end
local stored -- coop-look.txt's line.
local store={save=function(line) stored=line; return true end,load=function() return stored end,
    clear=function() stored=nil end}
local logs={}
local function log(m) logs[#logs+1]=m end
local function last() return logs[#logs] end
local function close(a,b) return math.abs(a-b)<1e-6 end

-- Doro.pick: the mapping on the ground, each speed from a fresh state (the first frame takes the speed as it is).
local function pick(speed,sprint) return Doro.pick({},{speed=speed,vz=0,falling=false,sprint=sprint,now=0}) end
for _,case in ipairs({{0,0,1},{150,150,1},{300,300,1},{500,500,1},{700,500,1.4},{900,500,1.8},{1000,500,1.8}}) do
    local c=pick(case[1],false)
    assert(c.asset=='two' and c.loop==true and close(c.input,case[2]) and close(c.rate,case[3]) and c.at==nil,
        case[1]..': '..c.asset..' '..c.input..' '..c.rate)
end
-- All fours while she sprints, and 0.3 s after.
local state={}
local function at(s,t,speed,sprint,extra)
    local p={speed=speed,vz=0,falling=false,sprint=sprint,now=t}
    for k,v in pairs(extra or {}) do p[k]=v end
    return Doro.pick(s,p)
end
assert(at(state,0,700,true).asset=='four' and at(state,0.1,700,true).asset=='four')
assert(at(state,0.3,700,false).asset=='four' and at(state,0.39,700,false).asset=='four','0.3 s of hold')
assert(at(state,0.41,700,false).asset=='two','Two legs again after the hold')
assert(at(state,0.5,700,true).asset=='four','Sprinting again')
-- The ghost (no sprint flag): all fours above 560 cm/s, two legs again below 520. 10 s apart: the smoothing settled.
state={}
assert(at(state,0,550).asset=='two' and at(state,10,570).asset=='four','On above 560')
assert(at(state,20,530).asset=='four' and at(state,30,521).asset=='four','Kept down to 520')
assert(at(state,40,515).asset=='two' and at(state,50,550).asset=='two','Off below 520, on again only above 560')
local c=at(state,60,700)
assert(c.asset=='four' and close(c.input,500) and close(c.rate,1.4))
-- The speed is smoothed over about 0.1 s: from standing to 500 cm/s, 0.1 s later 63 % of it.
state={}
at(state,0,0,false)
c=at(state,0.1,500,false)
assert(close(c.input,500*(1-math.exp(-1))),c.input)
assert(close(at(state,0.1,0,false).input,c.input),'No time passed: no change')
-- Take-off (falling with an upward speed): the hop from 0 to 0.5 s; a longer fall holds 0.5 s; landing plays the rest,
-- then the blend space again. Never a notify: SetPosition is told not to fire them (apply below).
state={}
at(state,0,300,false)
local function air(t,falling,vz) return at(state,t,300,false,{falling=falling,vz=vz}) end
c=air(1,true,600)
assert(c.asset=='evade' and c.loop==false and c.rate==1 and c.at==0 and c.input==nil,'Take-off from the start')
c=air(1.3,true,200)
assert(c.asset=='evade' and c.rate==1 and c.at==nil,'The hop plays on')
c=air(1.5,true,-100)
assert(c.asset=='evade' and c.rate==0 and c.at==0.5,'Held at 0.5 s')
c=air(3,true,-900)
assert(c.rate==0 and c.at==0.5,'Still held')
c=air(3.1,false,0)
assert(c.asset=='evade' and c.rate==1 and c.at==0.5,'Landing: from 0.5 s')
c=air(3.6,false,0)
assert(c.asset=='evade' and c.rate==1 and c.at==nil,'The landing plays on')
c=air(3.68,false,0)
assert(c.asset=='two' and c.loop==true,'Back on the blend space after 0.57 s')
-- Walking off a ledge (no upward speed): held at once.
c=air(4,true,-50)
assert(c.rate==0 and c.at==0.5,'A fall with no take-off is held')
-- A landing before the hop ends goes on from 0.5 s.
state={}
c=at(state,0,0,false,{falling=true,vz=500})
c=at(state,0.2,0,false,{falling=false,vz=0})
assert(c.rate==1 and c.at==0.5)
-- The ghost has no falling flag: in the air while her vertical speed is past 400 cm/s.
state={}
local function ghost(t,vz) return Doro.pick(state,{speed=0,vz=vz,now=t}) end
assert(ghost(0,300).asset=='two','A slope: on the ground')
c=ghost(1,500)
assert(c.asset=='evade' and c.at==0,'Up past 400: a take-off')
assert(ghost(2,-800).rate==0,'Falling: held')
assert(ghost(3,0).at==0.5,'Landed')
-- A whole jump as the ghost's feet give it (the mean vertical speed over each 50 ms): the hop, then held through its
-- top, where the speed passes 0, until her feet are down, then one landing. Also a jump whose top comes after the hop's
-- 0.5 s.
for _,v0 in ipairs({800,1200}) do
    state={}
    local function z(t) return math.max(0,v0*t-980*t*t) end
    local down,landed=v0/980,nil -- When her feet are down again; when the Doro landed.
    for k=1,40 do
        local t=k*0.05
        c=Doro.pick(state,{speed=0,vz=(z(t)-z(t-0.05))/0.05,now=t})
        if c.asset=='evade' and c.at==0.5 and c.rate==1 then
            assert(not landed and t>down,v0..': landed in the air at '..t)
            landed=t
        elseif t<down then
            assert(c.asset=='evade' and c.rate==(t-0.05<0.5 and 1 or 0),v0..' at '..t..': '..c.asset..' '..c.rate)
        end
    end
    assert(landed and landed<=down+0.1,v0..': landed at '..tostring(landed))
end
-- Onto a ledge (up, never down): held, then landed 1 s after take-off.
state={}
assert(ghost(0,600).at==0 and ghost(0.6,0).rate==0)
c=ghost(1,0)
assert(c.rate==1 and c.at==0.5,'Landed on the ledge')
-- Emotes: only while standing (under 50 cm/s); a moving racer keeps the speed mapping.
c=pick(0,false); assert(c.asset=='two')
c=Doro.pick({},{speed=20,vz=0,falling=false,sprint=false,emote='win',now=0})
assert(c.asset=='evade' and c.loop==true and c.rate==1 and c.at==nil,'The winner hops, looping')
c=Doro.pick({},{speed=0,vz=0,falling=false,emote='lose',now=0})
assert(c.asset=='exhaust' and c.loop==true,'The others are out of breath')
c=Doro.pick({},{speed=300,vz=0,falling=false,sprint=false,emote='win',now=0})
assert(c.asset=='two' and c.input==300,'Moving: no emote')
c=Doro.pick({},{speed=0,vz=500,falling=true,sprint=false,emote='win',now=0})
assert(c.asset=='evade' and c.loop==false and c.at==0,'In the air: no emote')

-- While a race drives: all fours from 60% of the top speed (1320 of 2200), two legs again under 55% (1210); the play
-- rate up to 3; the stumble's tired hop at twice its speed, from its start; a lean into the bend from the speed and the
-- turn rate, smoothed; a landing's pitch from its speed, settling; none of it without a drive.
local DRIVE={top=2200,yaw=0}
local function driven(t,speed,extra)
    local p={speed=speed,vz=0,falling=false,sprint=false,now=t,drive=DRIVE}
    for k,v in pairs(extra or {}) do p[k]=v end
    return Doro.pick(state,p)
end
state={}
c=driven(0,1300)
assert(c.asset=='two' and close(c.rate,1300/500) and c.input==500 and c.tilt.lean==0 and c.tilt.pitch==0)
assert(driven(10,1400).asset=='four','All fours past 1320')
assert(driven(20,1220).asset=='four' and driven(30,1200).asset=='two','Kept down to 1210')
c=driven(40,2200)
assert(c.asset=='four' and close(c.rate,3),'The play rate stops at 3')
assert(close(Doro.pick({},{speed=2200,vz=0,falling=false,sprint=false,now=0}).rate,1.8),'1.8 outside a race')
assert(Doro.pick({},{speed=2200,vz=0,falling=false,sprint=false,now=0}).tilt==nil,'No tilt outside a race')
-- The stumble.
c=driven(41,500,{drive={top=2200,yaw=0,stumble=true}})
assert(c.asset=='stumble' and c.loop==false and c.rate==2 and c.at==0)
c=driven(41.1,500,{drive={top=2200,yaw=0,stumble=true}})
assert(c.asset=='stumble' and c.at==nil,'Played on')
assert(driven(41.2,500).asset=='two','Over: the blend space again')
-- The lean: 1000 cm/s turning right at 30 deg/s is 0.53 g: 13.3 degrees once settled.
state={}
for k=0,200 do c=driven(k/100,1000,{drive={top=2200,yaw=k*0.3}}) end
local g=1000*math.rad(30)/981
assert(math.abs(c.tilt.lean-25*g)<1e-3,c.tilt.lean)
for k=201,400 do c=driven(k/100,1000,{drive={top=2200,yaw=60-(k-200)*0.3}}) end
assert(math.abs(c.tilt.lean+25*g)<1e-3,'Left: the other way')
for k=401,600 do c=driven(k/100,2200,{drive={top=2200,yaw=(k-400)*3}}) end
assert(math.abs(c.tilt.lean-25)<1e-3,'At most 25 degrees')
-- A landing at 600 cm/s down: the nose 12 degrees at once, then it settles.
state={}
driven(0,1000)
driven(0.1,1000,{falling=true,vz=-600})
c=driven(0.2,1000,{falling=false,vz=0})
assert(c.asset=='evade' and close(c.tilt.pitch,12),c.tilt.pitch)
c=driven(0.5,1000)
assert(math.abs(c.tilt.pitch)<0.2,c.tilt.pitch)
state={}
driven(0,1000)
driven(0.1,1000,{falling=true,vz=-2000})
assert(close(driven(0.2,1000).tilt.pitch,15),'At most 15')
-- Doro.tilted: the lean on Pitch, the nose on Roll; none: the rotator as it is.
local r=Doro.tilted({Pitch=1,Yaw=90,Roll=2},{lean=10,pitch=-3})
assert(r.Pitch==11 and r.Yaw==90 and r.Roll==-1)
r={Pitch=0,Yaw=0,Roll=0}
assert(Doro.tilted(r,nil)==r)

-- Doro.apply: PlayAnimation only when the clip or its looping changes; the input on a blend space only; the position
-- without notifies.
local actor=world:SpawnActor(class('/Script/Engine.Actor'),{},{})
local d=Doro.attach(actor)
local m=d.mesh
assert(table.concat(m.calls,'|')=='mesh mesh|scale 1.5|collision 0|mode 1',table.concat(m.calls,'|'))
assert(m.parent==nil and m.manual==false and actor.components[1]==m,'No parent given: the actor\'s root')
-- Its keepers: one per clip, unattached and never moved, hidden and not ticking before the mesh is set, collision
-- off, the single-node mode holding the clip. A clip not in memory (all fours) is loaded now, once, before anything
-- plays it.
local clips={}
for key in pairs(Doro.ASSETS) do if key~='mesh' then clips[key]=true end end
assert(#d.keepers==9 and #actor.components==10,#d.keepers)
for k,keeper in ipairs(d.keepers) do
    local key=keeper.anim.key
    assert(keeper==actor.components[k+1] and keeper.manual==true and keeper.at==nil,'Unattached, never moved')
    assert(table.concat(keeper.calls,'|')=='visible false|tick false|collision 0|mesh mesh|mode 1|anim '..key,
        table.concat(keeper.calls,'|'))
    assert(keeper.VisibilityBasedAnimTickOption==3 and keeper.mesh==assets[Doro.ASSETS.mesh] and clips[key],key)
    clips[key]=nil
end
assert(next(clips)==nil,'Every clip held')
assert(#loads==1 and loads[1]==Doro.ASSETS.four,'Loaded as the Doro was made')
m.calls={}
Doro.apply(d,{asset='two',loop=true,input=250,rate=1})
Doro.apply(d,{asset='two',loop=true,input=500,rate=1.4})
assert(table.concat(m.calls,'|')=='play two true|input 250|rate 1|input 500|rate 1.4',table.concat(m.calls,'|'))
m.calls={}
Doro.apply(d,{asset='four',loop=true,input=500,rate=1})
Doro.apply(d,{asset='evade',loop=false,rate=1,at=0})
Doro.apply(d,{asset='evade',loop=false,rate=0,at=0.5})
Doro.apply(d,{asset='evade',loop=true,rate=1})
assert(table.concat(m.calls,'|')=='play four true|input 500|rate 1|play evade false|rate 1|at 0|rate 0|at 0.5|'
    ..'play evade true|rate 1',table.concat(m.calls,'|'))
assert(#loads==1,'Played: not loaded again')
Doro.apply(d,{asset='four',loop=true,input=0,rate=1})
assert(#loads==1,'Cached')
-- Hung on a parent: attached there, kept relative. Doro.detach (the ghost's Doro mode off): the display and its
-- keepers gone, the actor kept.
local parent=object({})
local hung=Doro.attach(actor,parent)
assert(hung.mesh.parent==parent and #hung.keepers==9)
Doro.detach(hung,actor)
assert(hung.mesh.destroyed and not actor.destroyed)
for _,k in ipairs(hung.keepers) do assert(k.destroyed) end
-- A keeper that cannot be made: nothing left on the actor.
fail_anim=true
local added=#actor.components
local ok,why=pcall(Doro.attach,actor)
fail_anim=false
assert(not ok and why:find('no animation',1,true) and #actor.components==added+2,why)
assert(actor.components[added+1].destroyed and actor.components[added+2].destroyed,'The display and the keeper gone')
-- A missing mesh (the cached one collected, none to load): nothing added.
local mesh_path=Doro.ASSETS.mesh
local mesh_asset=assets[mesh_path]
assets[mesh_path],mesh_asset.destroyed=nil,true
local before=#actor.components
ok,why=pcall(Doro.attach,actor)
assert(not ok and why:find('the Doro mesh is missing on this PC',1,true) and #actor.components==before,why)
assets[mesh_path],mesh_asset.destroyed=mesh_asset,nil

-- Doro.remove: a Doro of spawn()'s destroyed while it is that actor; once gone, or another object at its place, no call.
do
    local made=Doro.spawn(world,{X=1,Y=2,Z=3},{Pitch=0,Yaw=0,Roll=0})
    Doro.remove(made)
    assert(made.actor.destroyed)
    made.actor.K2_DestroyActor=function() error('a call on a destroyed actor') end
    Doro.remove(made)
    local other=Doro.spawn(world,{X=1,Y=2,Z=3},{Pitch=0,Yaw=0,Roll=0})
    other.path='/Game/Map.Map:PersistentLevel.Actor_0'
    Doro.remove(other)
    assert(not other.actor.destroyed,'Another object: left alone')
    other.actor.destroyed=true
end
-- The look.
local look=Doro.new({log=log,store=store})
assert(look.log==log and not look.active())
assert(look.tick()==nil,'Off: nothing')
clock=100
ok,why=look.on()
assert(ok and why=='Doro look on: 4 parts of EVE hidden; coop race look off shows her again.',why)
local doro=spawned[#spawned]
local root=doro.components[1]
assert(doro.collision==false and root.mesh==mesh_asset and root.scale.X==1.5 and not root.parent,'A Doro of its own')
assert(#doro.components==10 and doro.components[2].manual==true,'With its keepers')
assert(root.at.X==10 and root.at.Y==20 and root.at.Z==-87 and root.rot.Yaw==0,'At her main mesh, her feet')
-- Only parts not hidden already: her ponytail stays the game's.
local body,face,hair,pony,blade=table.unpack(eve.parts)
for _,p in ipairs({body,face,hair,blade}) do assert(p.bHiddenInGame==true and p.writes==1,p.name) end
assert(pony.writes==0,'Hidden by the game: never touched, never listed')
assert(body.VisibilityBasedAnimTickOption==0,'Her pose ticks while she is not drawn')
assert(stored=='/Game/Map.Map:PersistentLevel.EVE_1\t3\t/Game/Map.Map:PersistentLevel.Actor_'..#spawned
    ..'\tCharacterMesh0\tMesh_Face\tSBHair\tBlade',stored)
assert(logs[1]=='look drone none: 0 characters within 30 m, none a shown drone' and
    logs[2]=='look hid=4 tick=3->0 rehid=0/min' and logs[3]=='look yaw_delta=90.0',table.concat(logs,'|'))
assert(look.active() and select(2,look.on())=='The Doro look is on already.')
-- Each frame: placed at her main mesh, animated from her velocity, her sprint and her fall; her speed once a second.
eve.velocity={X=300,Y=400,Z=0}
eve.Mesh.K2_GetComponentLocation=function() return {X=60,Y=20,Z=-87} end
root.calls={}
assert(look.tick()==nil)
assert(root.at.X==60 and root.teleport==false,'Moved, never teleported')
assert(table.concat(root.calls,'|')=='play two true|input 500|rate 1',table.concat(root.calls,'|'))
assert(last()=='speed v=500 sb=512 sprint=0',last())
local lines=#logs
clock=100.1
eve.sprint=true
root.calls={}
look.tick()
assert(root.calls[1]=='play four true' and #logs==lines,'All fours; no speed line before a second')
clock=101
look.tick()
assert(last()=='speed v=500 sb=512 sprint=1',last())
eve.sprint=false
-- Her falling flag with no vertical speed: held at 0.5 s. Evade was collected meanwhile: found again, and counted on
-- the minute line.
local evade=assets[Doro.ASSETS.evade]
evade.destroyed=true
assets[Doro.ASSETS.evade]=object({key='evade',GetFullName=evade.GetFullName,IsA=evade.IsA})
Doro.reloads.n,Doro.reloads.ms=0,0
eve.falling=true
clock=101.05
root.calls={}
look.tick()
assert(table.concat(root.calls,'|')=='play evade false|rate 0|at 0.5',table.concat(root.calls,'|'))
assert(Doro.reloads.n==1)
eve.falling=false
-- The 250 ms check: a part the game showed is hidden again and counted; a flag the game changed is logged once; the
-- tick option the game set back is set to 0 again.
face.bHiddenInGame=false
blade.bVisible=true
body.VisibilityBasedAnimTickOption=3
clock=101.3
look.tick()
assert(face.bHiddenInGame==true and face.writes==2 and body.VisibilityBasedAnimTickOption==0)
assert(logs[#logs-1]=='flag Mesh_Face visible=1 hidden=0' and last()=='flag Blade visible=1 hidden=1',
    table.concat(logs,'|',#logs-1))
lines=#logs
clock=101.6
look.tick()
assert(#logs==lines and face.writes==2,'Nothing changed: nothing said or written')
clock=160.1
look.tick()
assert(last()=='look hid=4 tick=3->0 rehid=1/min retick=1/min reload=1/min reload_ms=0' and Doro.reloads.n==0,last())
-- The race's results: standing, the emote it is given (win: Evade in a loop), until cleared.
eve.velocity={X=0,Y=0,Z=0}
look.emote('win')
clock=161
root.calls={}
look.tick()
assert(root.calls[1]=='play evade true',table.concat(root.calls,'|'))
look.emote(nil)
clock=161.1
root.calls={}
look.tick()
assert(root.calls[1]=='play two true',table.concat(root.calls,'|'))
-- While a race drives: at 2200 cm/s all fours at a play rate of 3; a stumble; her yaw turning leans the Doro; off
-- again with the drive gone.
look.drive({top=2200,stumble=false})
eve.velocity={X=2200,Y=0,Z=0}
local yaw=0
eve.Mesh.K2_GetComponentRotation=function() return {Pitch=0,Yaw=yaw,Roll=0} end
clock=162
root.calls={}
look.tick()
assert(table.concat(root.calls,'|')=='play four true|input 500|rate 3',table.concat(root.calls,'|'))
assert(root.rot.Pitch==0 and root.rot.Roll==0)
yaw,clock=3,162.1
look.tick()
assert(root.rot.Yaw==3 and root.rot.Pitch>0 and root.rot.Roll==0,'Leaned right')
look.drive({top=2200,stumble=true})
clock=162.2
root.calls={}
look.tick()
assert(root.calls[1]=='play stumble false',table.concat(root.calls,'|'))
look.drive(nil)
eve.velocity={X=0,Y=0,Z=0}
clock=162.3
look.tick()
assert(root.rot.Pitch==0 and root.rot.Roll==0,'No tilt once the drive is gone')
eve.Mesh.K2_GetComponentRotation=function() return {Pitch=0,Yaw=0,Roll=0} end
-- Off: only the listed parts are shown again, the tick option is back, the file and the Doro are gone.
ok,why=look.off('coop race look off')
assert(ok and why=='Doro look off (coop race look off): 4 parts shown again, tick option 3 back.',why)
for _,p in ipairs({body,face,hair,blade}) do assert(p.bHiddenInGame==false,p.name) end
assert(pony.bHiddenInGame==true and pony.writes==0,'The game\'s own hidden part stays hidden')
assert(body.VisibilityBasedAnimTickOption==3 and stored==nil and doro.destroyed)
assert(not look.active() and select(2,look.off('again'))=='The Doro look is off already.')
-- A step of off that fails keeps the file: the next Lua load tries again.
assert(look.on())
local set=hair.SetHiddenInGame
hair.SetHiddenInGame=function() error('no write') end
ok,why=look.off('test')
hair.SetHiddenInGame=set
assert(not ok and why:find('3 parts shown again',1,true) and why:find('no write',1,true) and stored~=nil,why)
hair:SetHiddenInGame(false,false)
stored=nil
-- After travel a new object can sit where a freed one was, and valid() passes it; its path differs. The look then
-- goes off with no call on any of them.
local other=eve_of('EVE_3')
player=other
assert(look.on())
local foreign=spawned[#spawned]
for _,o in ipairs({other,foreign,table.unpack(other.parts)}) do
    o.GetFullName=function() return 'Other /Game/Other.Other:PersistentLevel.Other' end
end
ok,why=look.tick()
assert(ok and why:find('^Doro look off %(map change%): 0 parts shown again'),why)
assert(not foreign.destroyed and other.Mesh.VisibilityBasedAnimTickOption==0 and stored==nil)
for _,p in ipairs(other.parts) do assert(p.writes==(p.name=='SBPonytail' and 0 or 1),p.name) end
player=eve
-- A map change (another EVE, or none): off by itself, EVE's flags restored where she still is.
assert(look.on())
player=eve_of('EVE_2')
clock=170
ok,why=look.tick()
assert(ok and why:find('^Doro look off %(map change%)'),why)
assert(body.bHiddenInGame==false and stored==nil)
player=eve
assert(look.on(),'On again by hand')
-- Its Doro destroyed by the game: off, no call on it.
spawned[#spawned].destroyed=true
ok,why=look.tick()
assert(ok and why:find('^Doro look off %(its Doro is gone%)'),why)
assert(look.on())
-- The first error turns the look off for this Lua load: EVE restored, on refused.
eve.broken=true
ok,why=look.tick()
assert(ok==false and why:find('^Doro look stopped until the mod reloads: .*no velocity%. Doro look off %(error%): '
    ..'4 parts shown again'),why)
assert(body.bHiddenInGame==false and body.VisibilityBasedAnimTickOption==3 and stored==nil)
eve.broken=false
ok,why=look.on()
assert(not ok and why:find('stays off until the mod reloads',1,true),why)
-- A file that cannot be written: EVE is never changed.
local look2=Doro.new({log=log,store={save=function() return false,'cannot write coop-look.txt' end,
    load=function() end,clear=function() end}})
local writes=body.writes
ok,why=look2.on()
assert(not ok and why:find('^Doro look not turned on: cannot write coop%-look%.txt%. Doro look off %(error%): 0 '),why)
assert(body.writes==writes and body.bHiddenInGame==false and body.VisibilityBasedAnimTickOption==3,'Never written')
assert(spawned[#spawned].destroyed,'Its Doro gone')
-- Her rotation unreadable for the yaw line, a log line only: the look stays on.
local look3=Doro.new({log=log,store=store})
local rotation=eve.K2_GetActorRotation
eve.K2_GetActorRotation=function() error('no rotation') end
ok,why=look3.on()
eve.K2_GetActorRotation=rotation
assert(ok and look3.active(),why)
look3.off('test')

-- An earlier Lua load left its look on (Ctrl+R): the next load's first tick shows the listed parts, sets the tick
-- option back, destroys that load's Doro and clears the file. Once.
local earlier=Doro.new({log=log,store=store})
assert(earlier.on())
local left=spawned[#spawned]
by_path['/Game/Map.Map:PersistentLevel.EVE_1']=eve
by_path['/Game/Map.Map:PersistentLevel.Actor_'..#spawned]=left
local line=stored
local fresh=Doro.new({log=log,store=store})
fresh.restore()
assert(last()=='look restored 4 parts from coop-look.txt' and stored==nil,last())
assert(body.bHiddenInGame==false and face.bHiddenInGame==false and pony.bHiddenInGame==true
    and body.VisibilityBasedAnimTickOption==3 and left.destroyed)
lines=#logs
stored=line
fresh.restore()
assert(#logs==lines and stored==line,'Once a Lua load')
-- Look on runs it first too.
fresh=Doro.new({log=log,store=store})
eve.parts[2].bHiddenInGame=true
assert(fresh.on() and logs[lines+1]=='look restored 1 parts from coop-look.txt',logs[lines+1])
fresh.off('test')
-- A stale path (EVE gone, the Doro gone): the file is cleared, nothing written.
stored='/Game/Map.Map:PersistentLevel.EVE_9\t3\t/Game/Map.Map:PersistentLevel.Actor_99\tCharacterMesh0'
writes=body.writes
fresh=Doro.new({log=log,store=store})
fresh.restore()
assert(stored==nil and body.writes==writes and last()=='look restored 0 parts from coop-look.txt',last())
-- An actor at the saved path whose root shows another mesh is no Doro of ours: left standing.
local stranger=world:SpawnActor(class('/Script/Engine.Actor'),{},{})
stranger:AddComponentByClass(class('/Script/Engine.SkeletalMeshComponent'),false,'identity',false)
    :SetSkeletalMesh(assets[Doro.ASSETS.idle])
by_path['/Game/Map.Map:PersistentLevel.Actor_77']=stranger
stored='/Game/Map.Map:PersistentLevel.EVE_9\t3\t/Game/Map.Map:PersistentLevel.Actor_77\tCharacterMesh0'
Doro.new({log=log,store=store}).restore()
assert(not stranger.destroyed and stored==nil)
-- Doro.sweep alone (race/run.lua's display Doros after a reload): true only for a Doro it destroyed.
local shown=Doro.spawn(world,{X=0,Y=0,Z=0},{Pitch=0,Yaw=0,Roll=0})
by_path[shown.path]=shown.actor
assert(Doro.sweep(shown.path)==true and shown.actor.destroyed)
assert(not Doro.sweep('/Game/Map.Map:PersistentLevel.Actor_77') and not stranger.destroyed and not Doro.sweep(nil))

-- The probe: a Doro 3 m ahead of her, facing her; each step logged as it starts, the held frames read back, one line
-- at the end with both clocks; its Doro gone after.
local probe=Doro.new({log=log,store=store})
clock=200
ok,why=probe.probe()
assert(ok and why:find('^Doro probe: '),why)
local p=spawned[#spawned]
root=p.components[1]
assert(math.abs(root.at.X-60)<1e-6 and math.abs(root.at.Y-320)<1e-6 and root.at.Z==-87 and root.rot.Yaw==180,
    'Ahead of her actor (yaw 90), turned to her')
assert(select(2,probe.probe())=='the Doro probe runs already')
lines=#logs
local steps={}
for _=1,600 do
    probe.tick()
    clock=clock+0.1
    if logs[#logs]:find('^probe anim=') then break end
end
for k=lines+1,#logs-1 do steps[#steps+1]=logs[k]:match('^probe phase=(.*)$') end
assert(table.concat(steps,' ')=='turn_90l meet_01 idle two_legs_0 two_legs_250 two_legs_500 all_fours_500 evade '
    ..'hold_0.25 hold_0.5 hold_0.75 exhaust meet_03',table.concat(steps,' '))
assert(last():find('^probe anim=AnimSingleNodeInstance bs=ok rate=ok hold=0%.25/0%.50/0%.75 height=59%.4 '
    ..'phase=meet_03 clock=4[56]%.%d time=%d+$'),last())
assert(p.destroyed and probe.tick()==nil)
-- A step that fails is logged and skipped; the rest goes on.
probe=Doro.new({log=log,store=store})
assert(probe.probe())
p=spawned[#spawned]
p.components[1].GetAnimInstance=function() error('no instance') end
lines=#logs
for _=1,600 do
    probe.tick()
    clock=clock+0.1
    if logs[#logs]:find('^probe anim=') then break end
end
local failed=0
for k=lines+1,#logs do if logs[k]:find('^probe phase=two_legs_%d+ failed: .*no instance$') then failed=failed+1 end end
assert(failed==3 and last():find('^probe anim=%? bs=failed rate=ok '),last())
-- Another object where its Doro was (a map change): the probe ends at its next step with no call on it, and coop off
-- destroys nothing.
probe=Doro.new({log=log,store=store})
assert(probe.probe())
probe.tick()
p=spawned[#spawned]
p.GetFullName=function() return 'Other /Game/Other.Other:PersistentLevel.Other' end
p.components[1].calls={}
clock=clock+3
probe.tick()
assert(last()=='probe ended at phase=turn_90l: its Doro is gone' and #p.components[1].calls==0,last())
assert(probe.tick()==nil and not p.destroyed)
probe=Doro.new({log=log,store=store})
assert(probe.probe())
p=spawned[#spawned]
p.GetFullName=function() return 'Other /Game/Other.Other:PersistentLevel.Other' end
probe.stop()
assert(not p.destroyed)

-- coop off: the look off (logged), the probe's Doro gone.
local all=Doro.new({log=log,store=store})
assert(all.on() and all.probe())
p=spawned[#spawned]
all.stop()
assert(p.destroyed and not all.active() and last():find('^Doro look off %(coop off%)'),last())
assert(body.bHiddenInGame==false and stored==nil)

-- The drone that follows EVE (EVE's actor at 10, 20, 0): the nearest shown character but her whose movement is in
-- drone mode, within 30 m, shown or not. Around her: a plain character 2 m off, the drone 3 m off, another drone-mode
-- character 10 m off, one the game hid 20 m off and one 50 m off. Only the drone is ever written, and only while the
-- game shows it.
local function character(name,x,flying,hidden)
    local c=object({bHidden=hidden==true,hides=0,CharacterMovement=object({bCustomFlyMoveDroneMode=flying})})
    function c:IsA(k) return k.path=='/Script/SB.SBCharacter' end
    function c:K2_GetActorLocation() return {X=10+x,Y=20,Z=0} end
    function c:GetFName() return fname(name) end
    function c:GetFullName() return 'BP_'..name..'_C /Game/Map.Map:PersistentLevel.'..name end
    function c:SetActorHiddenInGame(on) self.bHidden,self.hides=on,self.hides+1 end
    return c
end
local npc,docked=character('Npc',200,false),character('Docked',2000,true,true)
local drone,other,away=character('Drone',300,true),character('Other',1000,true),character('Away',5000,true)
characters={eve,npc,docked,drone,other,away}
local function untouched()
    for _,c in ipairs({npc,docked,other,away}) do
        assert(c.hides==0 and c.bHidden==(c==docked),c:GetFName():ToString())
    end
end
-- Look on: the drone hidden, its path in coop-look.txt after the parts'; the game showing it again: hidden again at
-- the next second; look off: shown again.
local flyer=Doro.new({log=log,store=store})
lines=#logs
assert(flyer.on())
assert(drone.bHidden==true and drone.hides==1 and logs[lines+1]=='look drone hid Drone at 3.0 m',logs[lines+1])
assert(stored:find('\tBlade\t/Game/Map.Map:PersistentLevel.Drone$'),stored)
drone.bHidden=false
clock=clock+1
flyer.tick()
assert(drone.bHidden==true and drone.hides==2,'Hidden again')
clock=clock+1
flyer.tick()
assert(drone.hides==2,'Hidden: no write')
ok,why=flyer.off('test')
assert(ok and why=='Doro look off (test): 4 parts and the drone shown again, tick option 3 back.',why)
assert(drone.bHidden==false and drone.hides==3 and stored==nil)
untouched()
-- Hidden by the game at look on: left alone, said once; shown later (it streams in): hidden then, and shown at off.
drone.bHidden=true
assert(flyer.on())
assert(drone.hides==3 and last()=='look hid=4 tick=3->0 rehid=0/min',last())
assert(logs[#logs-1]=='look drone none: 4 characters within 30 m, none a shown drone',logs[#logs-1])
assert(other.hides==0,'Never another drone-mode character in its place')
lines=#logs
for _=1,3 do clock=clock+1; flyer.tick() end
for k=lines+1,#logs do assert(not logs[k]:find('drone',1,true),logs[k]) end
assert(drone.hides==3,'Said once, never written')
drone.bHidden=false
clock=clock+1
flyer.tick()
assert(drone.bHidden==true and drone.hides==4 and last()=='look drone hid Drone at 3.0 m',last())
assert(stored:find('PersistentLevel.Drone$'),'Recorded before it was hidden')
ok,why=flyer.off('test')
assert(drone.bHidden==false and why:find('and the drone shown again',1,true),why)
-- coop off.
assert(flyer.on() and drone.bHidden==true)
flyer.stop()
assert(drone.bHidden==false and last():find('^Doro look off %(coop off%): 4 parts and the drone'),last())
-- A map change: off, the drone shown while it is still the one it hid; once another object is at its place, no call.
assert(flyer.on() and drone.bHidden==true)
player=eve_of('EVE_4')
clock=clock+1
ok,why=flyer.tick()
assert(ok and why:find('^Doro look off %(map change%): 4 parts and the drone') and drone.bHidden==false,why)
player=eve
assert(flyer.on() and drone.bHidden==true)
local full=drone.GetFullName
drone.GetFullName=function() return 'Other /Game/Other.Other:PersistentLevel.Other' end
local writes=drone.hides
flyer.off('map change')
assert(drone.hides==writes,'No call on another object')
drone.GetFullName,drone.bHidden=full,false
-- Its first error.
local broken=Doro.new({log=log,store=store})
assert(broken.on() and drone.bHidden==true)
eve.broken=true
clock=clock+1
ok,why=broken.tick()
eve.broken=false
assert(ok==false and why:find('Doro look off %(error%): 4 parts and the drone') and drone.bHidden==false,why)
-- The next Lua load (Ctrl+R with the look on): the drone shown from coop-look.txt; only an SB character still hidden.
local left_on=Doro.new({log=log,store=store})
assert(left_on.on() and drone.bHidden==true)
by_path['/Game/Map.Map:PersistentLevel.Drone']=drone
Doro.new({log=log,store=store}).restore()
assert(drone.bHidden==false and stored==nil and last()=='look restored 4 parts and the drone from coop-look.txt',
    last())
local plain=object({bHidden=true,IsA=function() return false end,
    SetActorHiddenInGame=function() error('a call on another actor') end})
by_path['/Game/Map.Map:PersistentLevel.Drone']=plain
stored='/Game/Map.Map:PersistentLevel.EVE_1\t3\t/Game/Map.Map:PersistentLevel.Actor_98\tCharacterMesh0'
    ..'\t/Game/Map.Map:PersistentLevel.Drone'
Doro.new({log=log,store=store}).restore()
assert(stored==nil and last()=='look restored 0 parts from coop-look.txt',last())
by_path['/Game/Map.Map:PersistentLevel.Drone']=nil
untouched()
characters={eve}

-- The engine's collector: an asset of Doro's that no live component of a live actor holds (its mesh, the clip it plays,
-- a keeper's clip) is unloaded, and only LoadAsset brings it back, as a new object.
local function collect()
    local held={}
    for _,a in ipairs(spawned) do
        for _,c in ipairs(a.destroyed and {} or a.components) do
            if not c.destroyed then
                if c.mesh then held[c.mesh]=true end
                if c.anim then held[c.anim]=true end
            end
        end
    end
    for path,a in pairs(assets) do
        if not held[a] and not unloaded[path] then
            a.destroyed,unloaded[path]=true,true
            assets[path]=object({key=a.key,GetFullName=a.GetFullName,IsA=a.IsA,GetBounds=a.GetBounds})
        end
    end
end
-- With no Doro standing, every asset goes; the next Doro loads each again, once, as it is made. Then, whatever it
-- plays (two legs, all fours, a jump, a stumble, the tired emote) with the collector between frames, nothing is loaded
-- again, and the minute line says reload=0/min.
for _,a in ipairs(spawned) do a.destroyed=true end
collect()
for _,path in pairs(Doro.ASSETS) do assert(unloaded[path],path) end
local loaded=#loads
Doro.reloads.n,Doro.reloads.ms=0,0
local racer=Doro.new({log=log,store=store})
assert(racer.on())
assert(#loads==loaded+10 and Doro.reloads.n==10,#loads-loaded)
Doro.reloads.n,Doro.reloads.ms,loaded=0,0,#loads
root=spawned[#spawned].components[1]
local played={}
local function run(seconds,set)
    set()
    for _=1,seconds*20 do
        clock=clock+0.05
        root.calls={}
        assert(racer.tick()==nil)
        for _,call in ipairs(root.calls) do played[call:match('^play (%a+)') or '']=true end
        collect()
    end
end
run(1,function() eve.velocity={X=300,Y=0,Z=0} end)
run(1,function() eve.sprint=true end)
run(1,function() eve.sprint,eve.falling,eve.velocity=false,true,{X=300,Y=0,Z=-600} end)
run(1,function() eve.falling,eve.velocity=false,{X=300,Y=0,Z=0} end)
run(1,function() racer.drive({top=2200,stumble=true}) end)
run(1,function() racer.drive(nil); racer.emote('lose'); eve.velocity={X=0,Y=0,Z=0} end)
racer.emote(nil)
for _,key in ipairs({'two','four','evade','stumble','exhaust'}) do assert(played[key],key) end
assert(#loads==loaded and Doro.reloads.n==0,'Nothing loaded again: '..(#loads-loaded))
clock=clock+60
racer.tick()
assert(last():find(' reload=0/min reload_ms=0$'),last())
racer.off('test')
collect()
assert(unloaded[Doro.ASSETS.four],'Its Doro gone: nothing holds the clips')
print('doro_test ok')
