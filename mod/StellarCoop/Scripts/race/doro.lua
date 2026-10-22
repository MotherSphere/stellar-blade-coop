-- Doro (Dororong, the game's NPC) as a display only: a plain actor with one SkeletalMeshComponent, or one such
-- component hung on a given parent (the ghost's main mesh), with collision off. No SB character, no table row, no AI,
-- nothing that can die, so nothing of it reaches a quest, an achievement or a save. Doro's own anim Blueprint is never
-- used: the engine's single-node instance plays its blend spaces and clips (SetAnimationMode 1), driven by Doro.pick.
-- The look (Doro.new): your EVE drawn as a Doro. It is the one place the mod writes to the player actor: while it is
-- on, EVE's mesh components carry bHiddenInGame (only those that did not already) and her main mesh's
-- VisibilityBasedAnimTickOption is 0, so her pose, notifies and root-motion moves still run while she is not drawn.
-- Both are restored when it goes off (coop race look off, coop off, a map change, its first error), and by the next
-- Lua load from coop-look.txt when this one could not (Ctrl+R, a dead Lua state). Never a pawn spawned or possessed.
-- The probe (coop race probe doro): a Doro 3 m ahead of EVE plays each clip in turn, with a log line a step.
-- resolve, attach, spawn, sweep, remove, apply and same also show another mesh (cut/leviathan.lua's coop leviathan).
local UE=require('UEHelpers')
local U=require('core.unreal')
local valid,value_of,each,text,find,address=U.valid,U.value_of,U.each,U.text,U.find,U.address
local Doro={}
local DIR='/Game/DLC_2/Art/Character/NPC/CH_NPC_Dororong/'
local function asset(path) return DIR..path..'.'..path:match('[^/]+$') end
-- What pick() names, by key.
Doro.ASSETS={mesh=asset('CH_NPC_Dororong'),
    two=asset('BlendSpace/IdleRun_BS_Peaceful_2'), -- Idle at 0, Move_Bipedal at 500.
    four=asset('BlendSpace/IdleRun_BS_Peaceful_1'), -- Idle at 0, Move_Quadrupedal at 500.
    evade=asset('Animation/N_Dororong_Evade'),exhaust=asset('Animation/N_Dororong_Exhaust'),
    stumble=asset('Animation/N_Dororong_Exhaust_Evade'), -- A tired hop, 1.2 s: a wall hit in a race.
    idle=asset('Animation/N_Dororong_Idle'),turn=asset('Animation/N_Dororong_Turn_90L'),
    meet1=asset('Animation/event/MV_Nikke_Dororong_1stMeet/MV_Nikke_Dororong_1stMeet_dororong_01'),
    meet3=asset('Animation/event/MV_Nikke_Dororong_1stMeet/MV_Nikke_Dororong_1stMeet_dororong_03')}
local MESH,ANIM,STATIC='/Script/Engine.SkeletalMesh','/Script/Engine.AnimationAsset','/Script/Engine.StaticMesh'
local SKINNED,SOLID='/Script/Engine.SkeletalMeshComponent','/Script/Engine.StaticMeshComponent'
local SCALE=1.5 -- The game's own: CharacterTable N_Dororong, MeshScale. About 59 cm tall.
local KEEP_RELATIVE=0 -- EAttachmentRule::KeepRelative
local RUN,MAX_RATE=500,1.8 -- cm/s: the blend spaces' full-run sample, which is EVE's run; the fastest play rate.
local SMOOTH=0.1 -- s: the speed's time constant.
local SPRINT_HOLD=0.3 -- s on all fours after her sprint ends.
-- cm/s with no sprint flag (the ghost): all fours above the first, two legs again below the second.
local GHOST_FOUR,GHOST_BACK=560,520
local AIR=400 -- cm/s with no falling flag: in the air from a vertical speed past this (a starting value).
-- With no falling flag, landed once she stops going down (a vertical speed above -100 cm/s after one below it), or 1 s
-- after take-off when she never went down (onto a ledge): a jump's top, where the speed passes 0, is no landing.
local LANDED,LEDGE=100,1
local TAKE_OFF,EVADE_END=0.5,1.07 -- s into N_Dororong_Evade: the game's own split (held during a fall), its end.
local STAND=50 -- cm/s: an emote plays below this only.
-- While a race drives (s.drive): all fours from 60% of the top speed, two legs again under 55%; the play rate up to 3;
-- the stumble's 1.2 s played in the model's 0.6 s. The lean into a bend: 25 degrees at 1 g of the speed times the
-- turn rate, at most 25, smoothed over 0.15 s. A landing pitches the nose by the landing speed (a degree each 50 cm/s,
-- at most 15) on a 6 Hz spring damped at 0.35. Starting values, tuned in game.
local FOUR_AT,FOUR_BACK,DRIVE_RATE,STUMBLE_RATE=0.6,0.55,3,2
local LEAN,LEAN_MAX,LEAN_SMOOTH,G=25,25,0.15,981
local KICK_PER,KICK_MAX,LAND_HZ,LAND_DAMP=50,15,6,0.35
-- A Doro's mesh faces its +Y: a lean (about its forward axis) is its rotator's Pitch, the nose's pitch (about its side
-- axis) its Roll. The signs are a guess until the drive probe shows them: a right turn (the yaw growing) leans right,
-- a landing dips the nose.
local LEAN_SIGN,NOSE_SIGN=1,1

-- The animation for one frame, from s: speed (horizontal, cm/s), vz (vertical, cm/s), falling (nil: read from vz),
-- sprint (nil for the ghost, which has none: read from speed), emote ('win', 'lose' or nil), now (s), and drive while
-- a race drives ({top (cm/s), yaw (the Doro's, degrees), stumble}). state is the caller's table, kept between frames.
-- Returns {asset=<key of ASSETS>, loop=, input=<blend space input or nil>, rate=, at=<position to set or nil>, and
-- while driving tilt={lean, pitch} in degrees}. Take-off plays Evade's hop from 0 to 0.5 s, a longer fall holds 0.5 s
-- (no sound notify is active there), landing plays the rest; on the ground the blend space, past 500 cm/s played
-- faster.
local function pick(state,s)
    local now=s.now
    if not state.now then state.v=s.speed
    elseif now>state.now then state.v=state.v+(s.speed-state.v)*(1-math.exp((state.now-now)/SMOOTH)) end
    state.now=now
    local falling=s.falling
    if falling==nil then
        if not state.air then falling=math.abs(s.vz)>AIR
        else
            state.down=state.down or s.vz<-LANDED
            falling=s.vz<=-LANDED or not (state.down or now-state.air_at>=LEDGE)
        end
    end
    if falling then
        state.low=math.min(state.low or 0,s.vz)
        if not state.air then
            state.air,state.air_at=s.vz>0 and 'up' or 'fall',now
            if state.air=='up' then return {asset='evade',loop=false,rate=1,at=0} end
        end
        if state.air=='up' and now-state.air_at<TAKE_OFF then return {asset='evade',loop=false,rate=1} end
        state.air='fall'
        return {asset='evade',loop=false,rate=0,at=TAKE_OFF}
    end
    if state.air then
        state.air,state.down,state.land_at=nil,nil,now
        state.kick,state.low=math.min(KICK_MAX,-(state.low or 0)/KICK_PER),nil
        return {asset='evade',loop=false,rate=1,at=TAKE_OFF}
    end
    if state.land_at and now-state.land_at<EVADE_END-TAKE_OFF then return {asset='evade',loop=false,rate=1} end
    state.land_at=nil
    if s.drive and s.drive.stumble then
        local first=not state.stumble
        state.stumble=true
        return {asset='stumble',loop=false,rate=STUMBLE_RATE,at=first and 0 or nil}
    end
    state.stumble=nil
    local v=state.v
    if s.emote and v<STAND then return {asset=s.emote=='win' and 'evade' or 'exhaust',loop=true,rate=1} end
    local four
    if s.drive then
        four=v>s.drive.top*(state.four and FOUR_BACK or FOUR_AT)
    elseif s.sprint==nil then
        four=v>(state.four and GHOST_BACK or GHOST_FOUR)
    else
        if s.sprint then state.sprint_at=now end
        four=state.sprint_at~=nil and now-state.sprint_at<SPRINT_HOLD
    end
    state.four=four
    return {asset=four and 'four' or 'two',loop=true,input=math.min(v,RUN),
        rate=v>RUN and math.min(v/RUN,s.drive and DRIVE_RATE or MAX_RATE) or 1}
end
-- The lean from the speed and the yaw's turn rate since the last frame; the landing's pitch from its kick.
local function tilt(state,s)
    local now,yaw=s.now,s.drive.yaw
    if state.yaw and now>state.yaw_at then
        local dt=now-state.yaw_at
        local rate=math.rad((yaw-state.yaw+180)%360-180)/dt
        local want=math.max(-LEAN_MAX,math.min(LEAN_MAX,LEAN*state.v*rate/G))
        state.lean=state.lean+(want-state.lean)*(1-math.exp(-dt/LEAN_SMOOTH))
    end
    if not state.yaw or now>state.yaw_at then state.yaw,state.yaw_at,state.lean=yaw,now,state.lean or 0 end
    local pitch=0
    if state.land_at and state.kick then
        local t,w=now-state.land_at,2*math.pi*LAND_HZ
        pitch=state.kick*math.exp(-LAND_DAMP*w*t)*math.cos(w*math.sqrt(1-LAND_DAMP^2)*t)
    end
    return {lean=state.lean,pitch=pitch}
end
function Doro.pick(state,s)
    local c=pick(state,s)
    if s.drive then c.tilt=tilt(state,s) else state.yaw,state.lean=nil,nil end
    return c
end
-- A rotator r with a pick()'s tilt added (none: r as it is).
function Doro.tilted(r,t)
    if not t then return r end
    return {Pitch=r.Pitch+LEAN_SIGN*t.lean,Yaw=r.Yaw,Roll=r.Roll+NOSE_SIGN*t.pitch}
end

local function path_of(o) return o:GetFullName():match('^%S+ (.+)$') end
-- o while it is still the object met at path: after travel a new object can sit at a freed one's address, and valid()
-- alone passes it.
local function same(o,path)
    o=valid(o)
    return o and path_of(o)==path and o or nil
end
Doro.same=same
-- Assets found or loaded again after the engine collected them (a clip nothing played for a while): their count and
-- ms, for the look's minute line.
Doro.reloads={n=0,ms=0}
local cache={}
-- An asset by its object path: in memory already, else loaded (LoadAsset, synchronous); nil when neither gives one of
-- that class. A cached one is used again only while it is still that object (partner/puppet.lua's rule).
function Doro.resolve(path,class)
    if same(cache[path],path) then return cache[path] end
    local started,again=os.clock(),cache[path]~=nil
    local a=valid(StaticFindObject(path))
    if not a then
        local ok,loaded=pcall(LoadAsset,path)
        a=ok and valid(loaded) or nil
    end
    if a and not a:IsA(find(class or ANIM)) then a=nil end
    if again then Doro.reloads.n,Doro.reloads.ms=Doro.reloads.n+1,Doro.reloads.ms+(os.clock()-started)*1000 end
    cache[path]=a
    return a
end
-- A Doro component on actor, hung on parent when given (KeepRelative: where the parent is), else the actor's root.
-- look: another mesh, {path=<its object path>, static=true for a StaticMesh}, at scale 1, a static one with no
-- animation mode. Returns the display {mesh=<component>}; raises, with no component left, when it cannot be made.
function Doro.attach(actor,parent,look)
    local static,name=look and look.static,look and look.path:match('[^.]+$') or 'the Doro'
    local mesh=assert(Doro.resolve(look and look.path or Doro.ASSETS.mesh,static and STATIC or MESH),
        (look and name or 'the Doro mesh')..' is missing on this PC')
    local identity=find('/Script/Engine.Default__KismetMathLibrary'):MakeTransform({X=0,Y=0,Z=0},
        {Pitch=0,Yaw=0,Roll=0},{X=1,Y=1,Z=1})
    local c=valid(actor:AddComponentByClass(find(static and SOLID or SKINNED),false,identity,false))
    assert(c,name..' could not be added')
    local ok,why=pcall(function()
        if parent then
            c:K2_AttachToComponent(parent,FName('None'),KEEP_RELATIVE,KEEP_RELATIVE,KEEP_RELATIVE,false)
        end
        if static then c:SetStaticMesh(mesh) else c:SetSkeletalMesh(mesh,true) end
        local scale=look and 1 or SCALE
        c:SetRelativeScale3D({X=scale,Y=scale,Z=scale})
        c:SetCollisionEnabled(0)
        if not static then c:SetAnimationMode(1) end -- AnimationSingleNode
    end)
    if not ok then
        pcall(function() c:K2_DestroyComponent(actor) end)
        error(why,0)
    end
    return {mesh=c}
end
-- A Doro of its own in world, at and turned as given (look: attach's): {actor=, path=<the actor's>, mesh=}. Raises,
-- with nothing left, when it fails.
function Doro.spawn(world,at,rotation,look)
    local actor=valid(world:SpawnActor(find('/Script/Engine.Actor'),at,rotation))
    assert(actor,(look and look.path:match('[^.]+$') or 'the Doro')..' could not be spawned')
    local ok,d=pcall(function()
        actor:SetActorEnableCollision(false,false)
        local d=Doro.attach(actor,nil,look)
        d.mesh:K2_SetWorldLocationAndRotation(at,rotation,false,{},true) -- The root was added at the origin.
        d.path=path_of(actor)
        return d
    end)
    if not ok then
        actor:K2_DestroyActor()
        error(d,0)
    end
    d.actor=actor
    return d
end
-- A Doro an earlier Lua load spawned (Ctrl+R), by its actor's path: gone, and true, only while that actor's root still
-- shows Doro's mesh (mesh: that other mesh's object path), so never another object found at that path.
function Doro.sweep(p,mesh)
    local doro=p and valid(StaticFindObject(p))
    local root=doro and valid(doro:K2_GetRootComponent())
    local shows=root and (root:IsA(find(SKINNED)) and valid(root.SkeletalMesh)
        or root:IsA(find(SOLID)) and valid(root.StaticMesh))
    if shows and path_of(shows)==(mesh or Doro.ASSETS.mesh) then
        doro:K2_DestroyActor()
        return true
    end
end
-- A Doro of spawn()'s gone, if its actor is still the one spawn() made: never a call on another object.
function Doro.remove(d)
    local a=same(d.actor,d.path)
    if a then a:K2_DestroyActor() end
end
-- One choice of pick() on a display: PlayAnimation only when the clip or its looping changes, then the blend space
-- input, the play rate and the position (without notifies) as given. c.asset: a key of ASSETS, or an object path.
function Doro.apply(d,c)
    local m=d.mesh
    if c.asset~=d.asset or c.loop~=d.loop then
        m:PlayAnimation(assert(Doro.resolve(Doro.ASSETS[c.asset] or c.asset),c.asset..' is missing on this PC'),c.loop)
        d.asset,d.loop=c.asset,c.loop
    end
    if c.input then m:GetAnimInstance():SetBlendSpaceInput({X=c.input,Y=0,Z=0}) end
    m:SetPlayRate(c.rate)
    if c.at then m:SetPosition(c.at,false) end
end

local function her(pawn) return pawn and pawn:IsA(find('/Script/SB.SBCharacter')) and pawn or nil end
local function flags(c)
    return string.format('visible=%d hidden=%d',c.bVisible==true and 1 or 0,c.bHiddenInGame==true and 1 or 0)
end
-- The probe's steps: 3 s each unless said. Clips with no notify first, then sound states, footsteps, held frames.
local PROBE={{name='turn_90l',asset='turn',loop=true,rate=1},{name='meet_01',asset='meet1',loop=true,rate=1},
    {name='idle',asset='idle',loop=true,rate=1},{name='two_legs_0',asset='two',loop=true,input=0,rate=1},
    {name='two_legs_250',asset='two',loop=true,input=250,rate=1},
    {name='two_legs_500',asset='two',loop=true,input=500,rate=1},
    {name='all_fours_500',asset='four',loop=true,input=500,rate=1},{name='evade',asset='evade',loop=false,rate=1},
    {name='hold_0.25',asset='evade',loop=false,rate=0,at=0.25},{name='hold_0.5',asset='evade',loop=false,rate=0,at=0.5},
    {name='hold_0.75',asset='evade',loop=false,rate=0,at=0.75},{name='exhaust',asset='exhaust',loop=true,rate=1},
    {name='meet_03',asset='meet3',loop=false,rate=1,seconds=9.4}}

-- o: log (the [DR] lines), store (coop-look.txt through link.store; nil without the native part: no restore).
function Doro.new(o)
    local log=o.log
    local store=o.store or {save=function() end,load=function() end,clear=function() end}
    local self={log=log}
    local look -- While on: what it changed and what it drives.
    local failed -- Why the look stopped on an error: off for this Lua load.
    local restored,yaw_said=false,false
    local probe -- While the probe runs.
    -- The file an earlier Lua load left (its look was on): its Doro destroyed, EVE's listed parts shown and her tick
    -- option back, then the file cleared. On the game thread (the first tick, or look on), never while the Lua state
    -- loads. One line: EVE's path, the old tick option, the Doro's path, the parts' names, tab-separated.
    function self.restore()
        if restored then return end
        restored=true
        local line=store.load()
        if not line then return end
        local f={}
        for field in (line..'\t'):gmatch('([^\t]*)\t') do f[#f+1]=field end
        local shown=0
        local ok,why=pcall(function()
            Doro.sweep(f[3]) -- Only one showing Doro.
            local eve=her(valid(StaticFindObject(f[1])))
            if not eve then return end
            local listed={}
            for k=4,#f do listed[f[k]]=true end
            each(eve:K2_GetComponentsByClass(find('/Script/Engine.MeshComponent')),function(_,c)
                c=valid(c)
                if c and listed[text(c:GetFName())] and c.bHiddenInGame==true then
                    c:SetHiddenInGame(false,false)
                    shown=shown+1
                end
            end)
            if tonumber(f[2]) then valid(eve.Mesh).VisibilityBasedAnimTickOption=tonumber(f[2]) end
        end)
        store.clear()
        log(string.format('look restored %d parts from coop-look.txt%s',shown,ok and '' or ' ('..tostring(why)..')'))
    end
    function self.active() return look~=nil end
    -- The race's results: 'win' or 'lose' while she stands (Doro.pick), nil for none; the look forgets it when it goes.
    function self.emote(e) if look then look.emote=e end end
    -- While a race drives (race/drive.lua's tick): {top, stumble}; nil after.
    function self.drive(d) if look then look.drive=d end end
    -- Each step its own pcall: one failing leaves the others done, and is said, and keeps the file for the next Lua
    -- load. Only the parts the look hid (p.flags set) are shown again, and only what is still the object it met (after
    -- a map change, nothing is).
    function self.off(why)
        local l=look
        if not l then return true,'The Doro look is off already.' end
        look=nil
        local shown,errors=0,{}
        local function try(f)
            local ok,e=pcall(f)
            if not ok then errors[#errors+1]=tostring(e) end
        end
        try(function() local a=same(l.doro.actor,l.doro.path); if a then a:K2_DestroyActor() end end)
        for _,p in ipairs(l.parts) do
            try(function()
                local c=p.flags and same(p.c,p.path)
                if c then c:SetHiddenInGame(false,false); shown=shown+1 end
            end)
        end
        try(function()
            local body=l.tick and same(l.body,l.body_path)
            if body then body.VisibilityBasedAnimTickOption=l.tick end
        end)
        if #errors==0 then store.clear() end
        return #errors==0,string.format('Doro look off (%s): %d parts shown again, tick option %s back%s.',why,shown,
            l.tick,#errors>0 and '; '..table.concat(errors,'; ') or '')
    end
    function self.on()
        self.restore()
        if failed then
            return false,'the Doro look stopped on an error ('..failed..'); it stays off until the mod reloads'
        end
        if look then return true,'The Doro look is on already.' end
        local eve=her(valid(UE.GetPlayer()))
        if not eve then return false,'no EVE in the world' end
        local body=valid(eve.Mesh)
        local at,rot=value_of(body:K2_GetComponentLocation()),value_of(body:K2_GetComponentRotation())
        -- The Doro first: if it cannot be made, nothing of EVE was touched.
        local d=Doro.spawn(eve:GetWorld(),{X=at.X,Y=at.Y,Z=at.Z},{Pitch=rot.Pitch,Yaw=rot.Yaw,Roll=rot.Roll})
        local now=os.clock()
        look={eve=eve,body=body,doro=d,state={},parts={},rehid=0,retick=0,check_at=now+0.25,speed_at=now,
            minute_at=now+60}
        local l=look
        local ok,why=pcall(function()
            l.at,l.path,l.body_path=address(eve),path_of(eve),path_of(body)
            l.map,l.move=U.map_of(eve),valid(eve.CharacterMovement)
            l.tick=assert(tonumber(value_of(body.VisibilityBasedAnimTickOption)),'her tick option is unreadable')
            local names={}
            each(eve:K2_GetComponentsByClass(find('/Script/Engine.MeshComponent')),function(_,c)
                c=valid(c)
                if c and c.bHiddenInGame~=true then
                    l.parts[#l.parts+1]={c=c,name=text(c:GetFName()),path=path_of(c)}
                    names[#names+1]=l.parts[#l.parts].name
                end
            end)
            -- The file before EVE changes: whatever happens next, the next Lua load can undo it.
            local saved,save_why=store.save(table.concat({l.path,tostring(l.tick),d.path,table.concat(names,'\t')},
                '\t'))
            if saved==false then error(save_why,0) end
            for _,p in ipairs(l.parts) do
                p.c:SetHiddenInGame(true,false)
                p.flags=flags(p.c)
            end
            body.VisibilityBasedAnimTickOption=0
        end)
        if not ok then
            failed=tostring(why)
            local _,message=self.off('error')
            return false,'Doro look not turned on: '..failed..'. '..message
        end
        log(string.format('look hid=%d tick=%d->0 rehid=0/min',#l.parts,l.tick))
        if not yaw_said then -- Her actor's yaw minus her main mesh's, as the capture measures it. A log line only.
            yaw_said=true
            pcall(function()
                log(string.format('look yaw_delta=%.1f',value_of(eve:K2_GetActorRotation()).Yaw-rot.Yaw))
            end)
        end
        return true,string.format('Doro look on: %d parts of EVE hidden; coop race look off shows her again.',#l.parts)
    end
    -- Every 250 ms: the same EVE on the same map (else the look goes off), each listed part the game showed hidden
    -- again, the tick option set back; each flag change the game made logged, and both counts once a minute.
    local function check(l,now)
        l.check_at=now+0.25
        local pawn=valid(UE.GetPlayer())
        if not pawn or address(pawn)~=l.at or U.map_of(pawn)~=l.map then return 'map change' end
        for _,p in ipairs(l.parts) do
            local c=same(p.c,p.path)
            if c then
                local seen=flags(c)
                if seen~=p.flags then log('flag '..p.name..' '..seen) end
                if c.bHiddenInGame~=true then
                    c:SetHiddenInGame(true,false)
                    l.rehid=l.rehid+1
                    seen=seen:gsub('hidden=0','hidden=1')
                end
                p.flags=seen
            end
        end
        if value_of(l.body.VisibilityBasedAnimTickOption)~=0 then
            l.body.VisibilityBasedAnimTickOption=0
            l.retick=l.retick+1
        end
        if now>=l.minute_at then
            local r=Doro.reloads
            log(string.format('look hid=%d tick=%d->0 rehid=%d/min retick=%d/min reload=%d/min reload_ms=%.0f',
                #l.parts,l.tick,l.rehid,l.retick,r.n,r.ms))
            l.minute_at,l.rehid,l.retick,r.n,r.ms=now+60,0,0,0,0
        end
    end
    -- Each frame: the Doro where her main mesh is (her feet), animated from her speed, fall and sprint, and while a
    -- race drives leaned and pitched as pick() says. Her main mesh and movement live as long as she does.
    local function frame(l,now)
        if not same(l.eve,l.path) then return 'map change' end
        if not same(l.doro.actor,l.doro.path) then return 'its Doro is gone' end -- Never a call on a destroyed actor.
        local at,rot=value_of(l.body:K2_GetComponentLocation()),value_of(l.body:K2_GetComponentRotation())
        local v=value_of(l.eve:GetVelocity())
        local speed,sprint=math.sqrt(v.X*v.X+v.Y*v.Y),l.eve:IsSprint()==true
        local d=l.drive
        local c=Doro.pick(l.state,{speed=speed,vz=v.Z,falling=l.move:IsFalling()==true,sprint=sprint,emote=l.emote,
            now=now,drive=d and {top=d.top,yaw=rot.Yaw,stumble=d.stumble}})
        l.doro.mesh:K2_SetWorldLocationAndRotation({X=at.X,Y=at.Y,Z=at.Z},
            Doro.tilted({Pitch=rot.Pitch,Yaw=rot.Yaw,Roll=rot.Roll},c.tilt),false,{},false)
        Doro.apply(l.doro,c)
        if now>=l.speed_at then
            l.speed_at=now+1
            local read,sb=pcall(function() return string.format('%.0f',l.eve:GetSBSpeedForAnimGraph()) end)
            log(string.format('speed v=%.0f sb=%s sprint=%d',speed,read and sb or '?',sprint and 1 or 0))
        end
        if now>=l.check_at then return check(l,now) end
    end
    -- The probe, a step at a time: each step's start logged (a crash names its step), a step that fails logged and
    -- skipped; at the end one line with what was read and the time it took on both clocks. Its Doro gone (a map change)
    -- ends it, with no call on it.
    local function probe_step(now)
        local p=probe
        if now<p.next then return end
        if not same(p.d.actor,p.d.path) then
            probe=nil
            return log('probe ended at phase='..p.phase..': its Doro is gone')
        end
        local ending=PROBE[p.k]
        if ending and ending.at then
            local read,at=pcall(function() return string.format('%.2f',p.d.mesh:GetPosition()) end)
            p.holds[#p.holds+1]=read and at or '?'
        end
        p.k=p.k+1
        local step=PROBE[p.k]
        if not step then
            probe=nil
            pcall(function() p.d.actor:K2_DestroyActor() end)
            return log(string.format('probe anim=%s bs=%s rate=%s hold=%s height=%s phase=%s clock=%.1f time=%d',p.anim,
                p.bs,p.rate,table.concat(p.holds,'/'),p.height,p.phase,now-p.clock,os.time()-p.time))
        end
        p.next,p.phase=now+(step.seconds or 3),step.name
        log('probe phase='..step.name)
        local ok,why=pcall(Doro.apply,p.d,step)
        if not ok then
            log('probe phase='..step.name..' failed: '..tostring(why))
            if step.input then p.bs='failed' end
            if step.at then p.rate='failed' end
        elseif p.anim=='?' then
            pcall(function() p.anim=text(p.d.mesh:GetAnimInstance():GetClass():GetFName()) end)
        end
    end
    function self.probe()
        if probe then return false,'the Doro probe runs already' end
        local eve=her(valid(UE.GetPlayer()))
        if not eve then return false,'no EVE in the world' end
        local body=valid(eve.Mesh)
        local at,yaw=value_of(body:K2_GetComponentLocation()),math.rad(value_of(eve:K2_GetActorRotation()).Yaw)
        local spot={X=at.X+math.cos(yaw)*300,Y=at.Y+math.sin(yaw)*300,Z=at.Z}
        local d=Doro.spawn(eve:GetWorld(),spot,{Pitch=0,Yaw=value_of(body:K2_GetComponentRotation()).Yaw+180,Roll=0})
        local read,height=pcall(function()
            return string.format('%.1f',Doro.resolve(Doro.ASSETS.mesh,MESH):GetBounds().BoxExtent.Z*2
                *value_of(d.mesh:K2_GetComponentScale()).Z)
        end)
        probe={d=d,k=0,next=0,clock=os.clock(),time=os.time(),holds={},bs='ok',rate='ok',anim='?',phase='none',
            height=read and height or '?'}
        return true,'Doro probe: a Doro 3 m ahead plays each clip in turn for about 45 s; [DR] lines in this log.'
    end
    -- Each frame, on the game thread. Returns ok, message when the look went off by itself.
    function self.tick()
        local now=os.clock()
        if probe then probe_step(now) end
        local l=look
        if not l then return end
        local ok,why=pcall(frame,l,now)
        if ok and not why then return end
        if ok then return self.off(why) end
        failed=tostring(why)
        local _,message=self.off('error')
        return false,'Doro look stopped until the mod reloads: '..failed..'. '..message
    end
    -- coop off: the look off and the probe's Doro gone.
    function self.stop()
        if probe then
            local p=probe
            probe=nil
            pcall(function() local a=same(p.d.actor,p.d.path); if a then a:K2_DestroyActor() end end)
        end
        if look then log(select(2,self.off('coop off'))) end
    end
    return self
end
return Doro
