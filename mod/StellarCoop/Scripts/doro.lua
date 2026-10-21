-- Doro (Dororong, the game's NPC) as a display only: a plain actor with one SkeletalMeshComponent, or one such
-- component hung on a given parent (the ghost's main mesh), with collision off. No SB character, no table row, no AI,
-- nothing that can die, so nothing of it reaches a quest, an achievement or a save. Doro's own anim Blueprint is never
-- used: the engine's single-node instance plays its blend spaces and clips (SetAnimationMode 1), driven by Doro.pick.
local U=require('unreal')
local valid,find=U.valid,U.find
local Doro={}
local DIR='/Game/DLC_2/Art/Character/NPC/CH_NPC_Dororong/'
local function asset(path) return DIR..path..'.'..path:match('[^/]+$') end
-- What pick() names, by key.
Doro.ASSETS={mesh=asset('CH_NPC_Dororong'),
    two=asset('BlendSpace/IdleRun_BS_Peaceful_2'), -- Idle at 0, Move_Bipedal at 500.
    four=asset('BlendSpace/IdleRun_BS_Peaceful_1'), -- Idle at 0, Move_Quadrupedal at 500.
    evade=asset('Animation/N_Dororong_Evade'),exhaust=asset('Animation/N_Dororong_Exhaust'),
    idle=asset('Animation/N_Dororong_Idle'),turn=asset('Animation/N_Dororong_Turn_90L'),
    meet1=asset('Animation/event/MV_Nikke_Dororong_1stMeet/MV_Nikke_Dororong_1stMeet_dororong_01'),
    meet3=asset('Animation/event/MV_Nikke_Dororong_1stMeet/MV_Nikke_Dororong_1stMeet_dororong_03')}
local MESH,ANIM='/Script/Engine.SkeletalMesh','/Script/Engine.AnimationAsset'
local SCALE=1.5 -- The game's own: CharacterTable N_Dororong, MeshScale. About 59 cm tall.
local KEEP_RELATIVE=0 -- EAttachmentRule::KeepRelative
local RUN,MAX_RATE=500,1.8 -- cm/s: the blend spaces' full-run sample, which is EVE's run; the fastest play rate.
local SMOOTH=0.1 -- s: the speed's time constant.
local SPRINT_HOLD=0.3 -- s on all fours after her sprint ends.
-- cm/s with no sprint flag (the ghost): all fours above the first, two legs again below the second.
local GHOST_FOUR,GHOST_BACK=560,520
local AIR=400 -- cm/s with no falling flag: in the air while the vertical speed is past this (a starting value).
local TAKE_OFF,EVADE_END=0.5,1.07 -- s into N_Dororong_Evade: the game's own split (held during a fall), its end.
local STAND=50 -- cm/s: an emote plays below this only.

-- The animation for one frame, from s: speed (horizontal, cm/s), vz (vertical, cm/s), falling (nil: read from vz),
-- sprint (nil for the ghost, which has none: read from speed), emote ('win', 'lose' or nil), now (s). state is the
-- caller's table, kept between frames. Returns {asset=<key of ASSETS>, loop=, input=<blend space input or nil>, rate=,
-- at=<position to set or nil>}. Take-off plays Evade's hop from 0 to 0.5 s, a longer fall holds 0.5 s (no sound
-- notify is active there), landing plays the rest; on the ground the blend space, past 500 cm/s played faster.
function Doro.pick(state,s)
    local now=s.now
    if not state.now then state.v=s.speed
    elseif now>state.now then state.v=state.v+(s.speed-state.v)*(1-math.exp((state.now-now)/SMOOTH)) end
    state.now=now
    local falling=s.falling
    if falling==nil then falling=math.abs(s.vz)>AIR end
    if falling then
        if not state.air then
            state.air,state.air_at=s.vz>0 and 'up' or 'fall',now
            if state.air=='up' then return {asset='evade',loop=false,rate=1,at=0} end
        end
        if state.air=='up' and now-state.air_at<TAKE_OFF then return {asset='evade',loop=false,rate=1} end
        state.air='fall'
        return {asset='evade',loop=false,rate=0,at=TAKE_OFF}
    end
    if state.air then
        state.air,state.land_at=nil,now
        return {asset='evade',loop=false,rate=1,at=TAKE_OFF}
    end
    if state.land_at and now-state.land_at<EVADE_END-TAKE_OFF then return {asset='evade',loop=false,rate=1} end
    state.land_at=nil
    local v=state.v
    if s.emote and v<STAND then return {asset=s.emote=='win' and 'evade' or 'exhaust',loop=true,rate=1} end
    local four
    if s.sprint==nil then
        four=v>(state.four and GHOST_BACK or GHOST_FOUR)
    else
        if s.sprint then state.sprint_at=now end
        four=state.sprint_at~=nil and now-state.sprint_at<SPRINT_HOLD
    end
    state.four=four
    return {asset=four and 'four' or 'two',loop=true,input=math.min(v,RUN),rate=v>RUN and math.min(v/RUN,MAX_RATE) or 1}
end

-- An asset by its object path: in memory already, else loaded (LoadAsset, synchronous); nil when neither gives one of
-- that class. A cached one is used again only while it is still that object (puppet.lua's rule).
local cache={}
function Doro.resolve(path,class)
    local a=valid(cache[path])
    if a and a:GetFullName():match('^%S+ (.+)$')==path then return a end
    a=valid(StaticFindObject(path))
    if not a then
        local ok,loaded=pcall(LoadAsset,path)
        a=ok and valid(loaded) or nil
    end
    if a and not a:IsA(find(class or ANIM)) then a=nil end
    cache[path]=a
    return a
end
-- A Doro component on actor, hung on parent when given (KeepRelative: where the parent is), else the actor's root.
-- Returns the display {mesh=<component>}; raises, with no component left, when it cannot be made.
function Doro.attach(actor,parent)
    local mesh=assert(Doro.resolve(Doro.ASSETS.mesh,MESH),'the Doro mesh is missing on this PC')
    local identity=find('/Script/Engine.Default__KismetMathLibrary'):MakeTransform({X=0,Y=0,Z=0},
        {Pitch=0,Yaw=0,Roll=0},{X=1,Y=1,Z=1})
    local c=valid(actor:AddComponentByClass(find('/Script/Engine.SkeletalMeshComponent'),false,identity,false))
    assert(c,'the Doro could not be added')
    local ok,why=pcall(function()
        if parent then
            c:K2_AttachToComponent(parent,FName('None'),KEEP_RELATIVE,KEEP_RELATIVE,KEEP_RELATIVE,false)
        end
        c:SetSkeletalMesh(mesh,true)
        c:SetRelativeScale3D({X=SCALE,Y=SCALE,Z=SCALE})
        c:SetCollisionEnabled(0)
        c:SetAnimationMode(1) -- AnimationSingleNode
    end)
    if not ok then
        pcall(function() c:K2_DestroyComponent(actor) end)
        error(why,0)
    end
    return {mesh=c}
end
-- A Doro of its own in world, at and turned as given: {actor=, mesh=}. Raises, with nothing left, when it fails.
function Doro.spawn(world,at,rotation)
    local actor=valid(world:SpawnActor(find('/Script/Engine.Actor'),at,rotation))
    assert(actor,'the Doro could not be spawned')
    local ok,d=pcall(function()
        actor:SetActorEnableCollision(false,false)
        local d=Doro.attach(actor)
        d.mesh:K2_SetWorldLocationAndRotation(at,rotation,false,{},true) -- The root was added at the origin.
        return d
    end)
    if not ok then
        actor:K2_DestroyActor()
        error(d,0)
    end
    d.actor=actor
    return d
end
-- One choice of pick() on a display: PlayAnimation only when the clip or its looping changes, then the blend space
-- input, the play rate and the position (without notifies) as given.
function Doro.apply(d,c)
    local m=d.mesh
    if c.asset~=d.asset or c.loop~=d.loop then
        m:PlayAnimation(assert(Doro.resolve(Doro.ASSETS[c.asset]),c.asset..' is missing on this PC'),c.loop)
        d.asset,d.loop=c.asset,c.loop
    end
    if c.input then m:GetAnimInstance():SetBlendSpaceInput({X=c.input,Y=0,Z=0}) end
    m:SetPlayRate(c.rate)
    if c.at then m:SetPosition(c.at,false) end
end
return Doro
