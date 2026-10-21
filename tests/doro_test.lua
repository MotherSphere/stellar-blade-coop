-- doro.lua with fake UE4SS objects: Doro.pick's mapping (blend space input and play rate from the speed, all fours
-- while sprinting with its hold, the ghost's speed threshold with its hysteresis, take-off, a held fall and landing,
-- emotes only while standing, the smoothing), Doro.apply's calls and a Doro hung on a parent or not.
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
    function c:SetSkeletalMesh(m) self.mesh=m; said('mesh',m.key) end
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
    function a:GetFullName() return 'Actor /Game/Map.Map:PersistentLevel.Actor_'..#spawned end
    a.spawned_at,a.spawned_rot=at,rot
    spawned[#spawned+1]=a
    return a
end,GetFullName=function() return 'World /Game/Art/BG/WorldMap/Level_P/E04.E04' end})
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
print('doro_test ok')
