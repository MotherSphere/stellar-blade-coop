-- doro.lua with fake UE4SS objects: Doro.pick's mapping (blend space input and play rate from the speed, all fours
-- while sprinting with its hold, the ghost's speed threshold with its hysteresis, take-off, a held fall and landing,
-- emotes only while standing, the smoothing), Doro.apply's calls, Doro.remove (only the actor spawn made); the look
-- (only parts not already hidden are hidden, listed and written to coop-look.txt before EVE changes; the Doro placed at
-- her main mesh each frame; the 250 ms check hides again and counts, and logs the flags the game changed; off clears
-- only those parts and restores the tick option, and keeps the file when a step fails; a map change turns it off, with
-- no call on an object that took the place of one it met; its first error turns it off until the mod reloads; a restore
-- from an earlier Lua load's file; a stale path only clears the file; the race's emote while she stands) and the
-- probe's steps and lines.
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
local Doro=require('doro')
for key,path in pairs(Doro.ASSETS) do
    local kind=key=='mesh' and 'SkeletalMesh' or key:match('^two$') and 'BlendSpace1D' or 'AnimSequence'
    assets[path]=object({key=key,GetFullName=function() return kind..' '..path end,
        IsA=function(_,c)
            return c.path==(key=='mesh' and '/Script/Engine.SkeletalMesh' or '/Script/Engine.AnimationAsset')
        end,
        GetBounds=function() return {BoxExtent={X=23.3,Y=17.2,Z=19.8}} end})
end
local by_path={} -- Objects StaticFindObject finds by path (EVE, an earlier Doro), beside classes and assets.
StaticFindObject=function(path)
    if by_path[path] then return by_path[path] end
    if path:find('^/Script/') then return class(path) end
    if path:find('Peaceful_1',1,true) then return invalid end -- Not in memory: LoadAsset brings it.
    return assets[path] or invalid
end
LoadAsset=function(path) loads[#loads+1]=path; return assets[path] or invalid end
-- A Doro component: its calls in order, as words.
local function component(actor)
    local c=object({calls={},actor=actor})
    local function said(...)
        local words={...}
        for k,w in ipairs(words) do if math.type(w)=='float' then words[k]=string.format('%g',w) end end
        c.calls[#c.calls+1]=table.concat(words,' ')
    end
    function c:K2_AttachToComponent(parent) self.parent=parent; said('attach') end
    function c:SetSkeletalMesh(m) self.mesh,self.SkeletalMesh=m,m; said('mesh',m.key) end
    function c:SetRelativeScale3D(v) self.scale=v; said('scale',v.X) end
    function c:SetCollisionEnabled(n) said('collision',n) end
    function c:SetAnimationMode(n) said('mode',n) end
    function c:K2_SetWorldLocationAndRotation(at,r,sweep,_,teleport)
        assert(sweep==false)
        self.at,self.rot,self.teleport=at,r,teleport
    end
    function c:PlayAnimation(a,loop) said('play',a.key,tostring(loop)) end
    function c:GetAnimInstance()
        return {SetBlendSpaceInput=function(_,v) assert(v.Y==0 and v.Z==0); said('input',v.X) end,
            GetClass=function() return {GetFName=function() return fname('AnimSingleNodeInstance') end} end}
    end
    function c:SetPlayRate(r) said('rate',r) end
    function c:SetPosition(at,notifies) assert(notifies==false,'Never notifies'); self.position=at; said('at',at) end
    function c:GetPosition() return self.position or 0 end
    function c:K2_GetComponentScale() return self.scale end
    function c:K2_DestroyComponent() self.destroyed=true end
    function c:IsA(k) return k.path=='/Script/Engine.SkeletalMeshComponent' end
    return c
end
local spawned={}
local world=object({SpawnActor=function(_,c,at,rot)
    assert(c.path=='/Script/Engine.Actor','A plain Actor only')
    local a=object({components={}})
    function a:SetActorEnableCollision(on) self.collision=on end
    function a:AddComponentByClass(k,manual,transform,deferred)
        assert(k.path=='/Script/Engine.SkeletalMeshComponent' and manual==false and transform=='identity'
            and deferred==false)
        local added=component(self)
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

-- Doro.apply: PlayAnimation only when the clip or its looping changes; the input on a blend space only; the position
-- without notifies.
local actor=world:SpawnActor(class('/Script/Engine.Actor'),{},{})
local d=Doro.attach(actor)
local m=d.mesh
assert(table.concat(m.calls,'|')=='mesh mesh|scale 1.5|collision 0|mode 1',table.concat(m.calls,'|'))
assert(m.parent==nil,'No parent given: the actor\'s root')
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
assert(#loads==1 and loads[1]==Doro.ASSETS.four,'Not in memory: loaded, once')
Doro.apply(d,{asset='four',loop=true,input=0,rate=1})
assert(#loads==1,'Cached')
-- Hung on a parent: attached there, kept relative.
local parent=object({})
assert(Doro.attach(actor,parent).mesh.parent==parent)
-- A missing mesh (the cached one collected, none to load): nothing added.
local mesh_path=Doro.ASSETS.mesh
local mesh_asset=assets[mesh_path]
assets[mesh_path],mesh_asset.destroyed=nil,true
local before=#actor.components
local ok,why=pcall(Doro.attach,actor)
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
assert(root.at.X==10 and root.at.Y==20 and root.at.Z==-87 and root.rot.Yaw==0,'At her main mesh, her feet')
-- Only parts not hidden already: her ponytail stays the game's.
local body,face,hair,pony,blade=table.unpack(eve.parts)
for _,p in ipairs({body,face,hair,blade}) do assert(p.bHiddenInGame==true and p.writes==1,p.name) end
assert(pony.writes==0,'Hidden by the game: never touched, never listed')
assert(body.VisibilityBasedAnimTickOption==0,'Her pose ticks while she is not drawn')
assert(stored=='/Game/Map.Map:PersistentLevel.EVE_1\t3\t/Game/Map.Map:PersistentLevel.Actor_'..#spawned
    ..'\tCharacterMesh0\tMesh_Face\tSBHair\tBlade',stored)
assert(logs[1]=='look hid=4 tick=3->0 rehid=0/min' and logs[2]=='look yaw_delta=90.0',table.concat(logs,'|'))
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
-- Doro.sweep alone (race.lua's display Doros after a reload): true only for a Doro it destroyed.
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
print('doro_test ok')
