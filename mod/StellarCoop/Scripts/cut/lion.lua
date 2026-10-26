-- coop lion: the cut Naytiba 02, the Lion (/Game/Art/Character/Monster/CH_M_NA_02/: blueprint, mesh, clips, collision
-- data and 41 Shows, but no table row), spawned as a real enemy to fight, on the game thread (plan A of the Lion study,
-- made native). Its 222 rows, each authored for it (cut/lion_rows.lua lists them), go into SB's tables through the
-- native part (lion/rows.h, glue/tick/lion_game.inc: SB's own AddRow on the game thread with no logic task in flight),
-- after the 4 rows of the cut items the Night Operation shop sells (2 ItemTable rows, an ItemConsumableTable row and
-- the SkillTable row they play) and the 11 of EVE's cut Tachy ChainSpin (its skill, 9 steps and the effect that starts
-- it), 237 rows in 14 tables. The shop asks for them through Lion.rows (nightop/shop.lua).
-- This file finds the tables by their fixed paths and sends their addresses (the lion rows request: no console word
-- reaches an address), waits for the answer in coop-status.txt's lion line, then reads every row back through FindRow
-- by field name, independent of the SDK's offsets, and stops at the first value that differs. Then one spawn call,
-- nightop/run.lua's ServerRequest_CreateActor with cheat on and key 0 (no EventSpawn row: no zone storage, no quest
-- event, no respawn, nothing saved), 10 m ahead of EVE and 1 m up, facing her, for a fixed CharacterTable ID only:
-- 50020 (M_LionC, the Skulling test tree), 50021 after coop lion brain lurker (M_LionC_Lurker, the Lesser Lurker tree),
-- or for coop lion control 50110 (M_Antlion, a shipped Naytiba, which tells a broken call from broken rows). Its body
-- is the new character nearest the spot (of the Large blueprint's class for the Lion), or a body SB sent far away and
-- moved back there (it reuses one: a Lion at 466 m came back for the next spawn on 2026-10-23), given its default
-- controller when it has none, then followed: a line a second while it lives (distance, place, the anim graph's speed,
-- a skill running, the custom anim alphas the AnimBP blends a Show's clip by, how far a paw moved in the body's own
-- frame, with its mesh's engine switches before the first line and at each change), its death (InteractionState and
-- Controller, as run.lua reads them) and its body's despawn, with the spawn manager's counter (the lion line's spawns=)
-- before, while it lives and after. While a Lion lives, one more: the boss bar's name, which the game shows as
-- <M_LionC> (no Lion text in CharacterStringTable), set to Lion. Nothing looks its Shows or clips up: a StaticFindObject
-- of one took about 30 ms here, a 50 ms frame each second (the frame rate check of 2026-10-24). coop lion unfreeze puts those switches back to their
-- running values on each living Lion (the test of a body whose pose stays on frame 1); a body whose mesh has no anim
-- instance runs the Lion's AnimBP on a hidden Behemoth mesh that the Lion's mesh copies (LEADER_MESH says why), or a
-- single-node stand-in when that fails. Never called here: UE4SS's
-- AddRow or RemoveRow (a raw RowMap insert or free that SB's ID maps miss), a despawn, a save, quest or inventory call.
-- The Lion goes when it dies or with the map; the rows stay for the game run, and a later coop lion only reads them
-- back. coop off ends what this file does (a wait, a search, the lines) and leaves a living Lion to the game.
-- The entrance: the Lion's AnimBP (CH_M_NA_02_AnimBP) has no montage slot, so a montage would not show, and a
-- single-node clip on its mesh would replace the anim instance SB plays its skills on while its AI runs. So coop lion
-- spawns at once, and coop lion intro first plays Mon_LionC_Scene01_Appearance (the cut boss intro's clip) on a display
-- copy (race/doro.lua's plain actor with the Large mesh, as cut/leviathan.lua shows its meshes), then spawns the Lion
-- where the copy's root ended and removes the copy as soon as the body shows. A map change during the entrance spawns
-- nothing.
local U=require('core.unreal')
local N=require('nightop.probe')
local Doro=require('race.doro')
local valid,value_of,text=U.valid,U.value_of,U.text
local Lion={}
-- The 14 tables, in the native part's order (link/protocol.h's kLionTables), each at /Game/Local/Data/<T>.<T>.
Lion.TABLES={'CharacterTable','CharacterAppearanceTable','CharacterDeadTable','CharacterStanceTable',
    'CharacterAnimSetTable','SkillCommandTable','SkillTable','SkillActiveStepTable','CharacterMoveTable',
    'TargetFilterTable','SkillResultTable','EffectTable','ItemTable','ItemConsumableTable'}
local DATA='/Game/Local/Data/'
-- The only IDs the spawn call takes, with what each is; the brains are the Lion's two CharacterTable rows.
Lion.IDS={[50020]='M_LionC',[50021]='M_LionC_Lurker',[50110]='M_Antlion'}
local BRAINS={skulling=50020,lurker=50021}
local CONTROL=50110
local CLASS='CH_M_NA_02_BluePrint_Large_C' -- The Large blueprint, the Lion's appearance row.
local DIR='/Game/Art/Character/Monster/CH_M_NA_02/'
local MESH=DIR..'CH_M_NA_02_Large.CH_M_NA_02_Large' -- The Large blueprint's mesh, at its scale (1.5).
local CLIP=DIR..'Animation/Mon_LionC_Scene01_Appearance.Mon_LionC_Scene01_Appearance'
local MESH_SCALE=1.5
-- Degrees the display copy turns from the Lion's facing: the Large blueprint sets no mesh rotation. A starting value,
-- tuned in game.
local MESH_YAW=0
local AHEAD,UP=1000,100 -- cm: the spot ahead of EVE and above her middle, so the body lands (the probe's 1 m).
local ROOT_FAR=2000 -- cm: the copy's root ending farther from the spot than this spawns the Lion at the spot.
local POLL,WAIT=0.25,30 -- s: the lion line read while the rows are asked, and how long before giving up.
local FINDS={0.3,1,2,3.5,5} -- s after the call: the body looked for (FindAllOf walks every object: a few tries only).
local NEAR=30 -- m: a new body farther than this from the spot is not the one spawned.
-- s after the call: a body still without a controller gets its default one (run.lua's adopt comes 0.5 s after a find
-- at 1 s at the earliest), so the game's own controller has time to come first.
local ADOPT=1.5
local FOLLOW,GONE=1,60 -- s: a line a second while it lives; a body still there this long after its death is let go.
-- m: a body that stood farther than this from the spot at the call and stands within NEAR of it after is one SB moved
-- back for this spawn (no enemy runs the difference in 5 s).
local FAR=100
local MASK=0xFFFFFFFF
local USE='Use: coop lion [intro] | rows | control | brain skulling|lurker | unfreeze [init]'
-- The bone whose place in the body's own frame the follow line compares from one second to the next: a frozen pose
-- keeps it still while the body runs and attacks (the in-game test of 2026-10-24: frame 1 of its idle, alphas 0).
local BONE='Bip001-L-Hand'
-- The Lion's AnimBP, which all three of its blueprints name: the test of 2026-10-24 found the body's mesh with no anim
-- instance at all (anim instance none), so nothing it plays shows. Its class, and the package that loads it.
-- On 2026-10-24 SetAnimationMode(0), which builds the instance in AnimBP mode, left it none, and UE4SS raised a null
-- UObject on SetAnimInstanceClass with any class (by the mesh's AnimClass or by path: its class parameter does not
-- pass), while the control Antlion has its own instance. So each class goes into AnimClass by a property write, and a
-- mode change (single node, then AnimBP) makes the engine clear the instance and build it again: the mesh's own class
-- first, then the Lion's found by its path, then the Behemoth's (same skeleton, CH_M_NA_46_Skeleton, shipped).
-- When no AnimBP builds an instance: the engine's single-node instance playing the Lion's battle idle-run blend space
-- (speed 0 to 600 cm/s), its input set each frame from the anim graph speed. A stand-in until an AnimBP plays: no skill
-- clip shows with it.
local DRIVE_BS=DIR..'Animation/BlendSpace/IdleRun_BS_.IdleRun_BS_'
local DRIVE_MAX=600
-- Why no AnimBP builds an instance on the Lion (2026-10-24, the eighth test): its three meshes hang Bip001 under Root,
-- but CH_M_NA_46_Skeleton, which the Behemoth's update gave a Base bone, hangs it under Base. UE 4.26 builds an AnimBP
-- instance only for a mesh whose bone hierarchy matches its skeleton's (USkeleton::IsCompatibleMesh); the single-node
-- instance has no such check, so the entrance and the stand-in play. The leader: the body's own mesh component gets
-- the Behemoth's mesh (CH_M_NA_46, same skeleton, Base included), hidden, with the Lion's AnimBP, which SB's skills and
-- moves play on as on any monster; a new component on the body draws the Lion's mesh and copies that pose by bone name
-- (SetMasterPoseComponent).
local LEADER_MESH={name='CH_M_NA_46',path='/Game/Art/Character/Monster/CH_M_NA_46/CH_M_NA_46.CH_M_NA_46'}
local BEHEMOTH='/Game/Art/Character/Monster/CH_M_NA_46/BluePrints/'
local ANIM_CLASSES={
    {name='CH_M_NA_02_AnimBP_C',class=DIR..'BluePrints/CH_M_NA_02_AnimBP.CH_M_NA_02_AnimBP_C',
        package=DIR..'BluePrints/CH_M_NA_02_AnimBP.CH_M_NA_02_AnimBP'},
    {name='CH_M_NA_46_AnimBP_C',class=BEHEMOTH..'CH_M_NA_46_AnimBP.CH_M_NA_46_AnimBP_C',
        package=BEHEMOTH..'CH_M_NA_46_AnimBP.CH_M_NA_46_AnimBP'}}
-- The boss bar's name: the TextBlock SB writes once a boss bind (FUN_141e4c3f0, through FText::FromStringTable on the
-- row's Name), the text it shows for the Lion, and ours. FindAllOf('TextBlock') walks every object: the live blocks
-- found (under /Engine/Transient, not a widget class's template) are kept, and looked for again at most every BOSS_LOOK
-- s while none is held.
local BOSS_TEXT,BOSS_SHOWN,BOSS_NAME,BOSS_LOOK='TextBlock_BossName','^<M_LionC[%w_]*>$','Lion',10
local LIVE='/Engine/Transient'

-- The rows as the native part writes them: cut/lion_rows.lua, which the generator of lion/rows.h writes from the same
-- recipe (tests/lua/cut/lion_test.lua checks the two agree): {table=, name=, id=<nil in the dead table>,
-- checks={{field, kind, value, changed}}}. kind: f a float, i an int32, b a bool (0 or 1), e an enum's number, n an
-- FName (compared in any case: its text is whichever casing the game registered first), N a list of FNames, s an
-- FString, S a list of FStrings (lists joined by |). changed: the value differs from the row's template (the shipped
-- row the native part copies before its patches), so reading it back proves the patch landed; the other checks restate
-- a value the template holds, and a read-back cannot tell them from the copy.
local DATA_ROWS=require('cut.lion_rows')
Lion.ROWS={}
for _,r in ipairs(DATA_ROWS.ROWS) do Lion.ROWS[#Lion.ROWS+1]={table=r[1],name=r[2],id=r[3],checks=r[4]} end
-- The lion line's counts once every row is in: added=, and SB's lookups by ID (char=, skills=, stance=).
local function count(t)
    local n=0
    for _,r in ipairs(Lion.ROWS) do if r.table==t or not t then n=n+1 end end
    return n..'/'..n
end
Lion.IN={added=count(),char=count('CharacterTable'),skills=count('SkillTable'),stance=count('CharacterStanceTable')}

local function why(e) return (tostring(e):gsub('^.-:%d+: ','')) end -- Without the file and line.
local function xyz(v) return string.format('%.0f,%.0f,%.0f',v.X,v.Y,v.Z) end
local function metres(a,b) return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)/100 end
local function location(actor) local v=value_of(actor:K2_GetActorLocation()); return {X=v.X,Y=v.Y,Z=v.Z} end
local function class_of(o) return text(o:GetFullName()):match('^%S+') end
local function path_of(o) return text(o:GetFullName()):match('^%S+ (.+)$') end
local function key_of(c) -- BroadcastSpawnInfo.EventSpawnId, which the spawn sets from the call's key; unsigned.
    local k=math.tointeger(c.BroadcastSpawnInfo.EventSpawnId)
    return k and k&MASK
end
-- run.lua's signals: InteractionState turns non-zero at death, but 1 alone means "can be executed"; a dying body loses
-- its controller at once. Killed: non-zero with no controller.
local function killed(c) return c.InteractionState~=0 and valid(c.Controller)==nil end
-- The lion line (glue's lion_status) as fields: state (off, waiting, rows, refused, fault), asks (a number), spawns (a
-- number, nil while '?'), and the others as written (added, char, skills, stance, why, table, row, detail; where, the
-- rest of the line). nil without one: no native part, or one older than the Lion's rows.
function Lion.parse(status)
    local line=('\n'..(status or '')):match('\nlion=([^\r\n]*)')
    if not line then return nil end
    local s={state=line:match('^(%a+)'),line='lion='..line}
    for k,v in line:gmatch(' (%a+)=(%S+)') do s[k]=v end
    s.where=line:match(' where=(.*)$')
    s.asks,s.spawns=tonumber(s.asks) or 0,tonumber(s.spawns)
    return s
end
-- A field of a row as compared: a number (a bool as 0 or 1), or text (an FName lower-cased), a list joined by |. Raises
-- when unread.
local function get(r,field,kind)
    local x=value_of(r[field])
    if kind=='b' and type(x)=='boolean' then return x and 1 or 0 end
    if kind=='f' or kind=='i' or kind=='e' or kind=='b' then return assert(tonumber(x),'not a number') end
    if kind=='n' then return text(x):lower() end
    if kind=='s' then return text(x) end
    local items={}
    U.each(assert(x,'no field'),function(_,v) items[#items+1]=text(v) end)
    local joined=table.concat(items,'|')
    return kind=='N' and joined:lower() or joined
end
local function same_value(kind,got,want)
    if kind=='f' then return math.abs(got-want)<1e-4 end
    return got==((kind=='n' or kind=='N') and want:lower() or want)
end
-- R4: every row of ROWS read back through its table's FindRow (tables: by name, as found), its ID then its checks, in
-- order. Returns the count that match and, at the first that does not, what it reads; with every row matching, also
-- the fields read and how many of them differ from the template. ponytail: about 3000 field reads in one frame, once a
-- coop lion; a read-back spread over frames if that hitch shows in game.
local function read_back(tables)
    local fields,changed=0,0
    for n,r in ipairs(Lion.ROWS) do
        local found=tables[r.table]:FindRow(r.name)
        if found==nil then return n-1,r.name..' is not in '..r.table end
        local checks={table.unpack(r.checks)}
        if r.id then table.insert(checks,1,{'ID','i',r.id}) end
        for _,c in ipairs(checks) do
            local ok,got=pcall(get,found,c[1],c[2])
            if not ok then return n-1,string.format('%s %s unread (%s)',r.name,c[1],why(got)) end
            if not same_value(c[2],got,c[3]) then
                return n-1,string.format('%s %s reads "%s", not "%s"',r.name,c[1],tostring(got),tostring(c[3]))
            end
        end
        fields=fields+#r.checks
        for _,c in ipairs(r.checks) do changed=changed+(c[4] and 1 or 0) end
    end
    return #Lion.ROWS,nil,fields,changed
end

-- o: log (the [LI] lines), ask(line) the native request (ok, message), status() the native status text.
function Lion.new(o)
    local log,ask,status=o.log,o.ask,o.status
    local self={}
    local brain=BRAINS.skulling
    local job=nil -- The command under way: {what=<for a busy refusal>, step=f(job, now), at=<os.clock when due>, ...}.
    local followed={} -- The bodies spawned this Lua load and not let go: {n=, id=, obj=, path=, since=, before=, ...}.
    local spawned,next_follow=0,0
    -- The frame time while a command runs or a Lion lives (UGameplayStatics' world delta, read each frame), and what
    -- this file's tick costs (os.clock is wall time in the game's CRT), its longest tick, and what the last once-a-second
    -- pass took by part (parts): the follow line's frame part, and the spawn's before line to compare with. gs: the
    -- GameplayStatics default object; ctx: its world context (EVE).
    local perf,gs,ctx={frames=0,sum=0,worst=0,lua=0,tick=0},nil,nil
    local parts='none yet'
    local function perf_take() -- The frame part since the last take, then the counters back to 0.
        local said=(perf.frames>0 and string.format('frame %.1f ms (worst %.1f), ',perf.sum/perf.frames*1000,
            perf.worst*1000) or 'frame ? ms, ')..string.format('lion Lua %.1f ms/s, longest tick %.1f ms (last pass: %s)',
            perf.lua,perf.tick,parts)
        perf.frames,perf.sum,perf.worst,perf.lua,perf.tick=0,0,0,0,0
        return said
    end
    local frame_said='frame ? ms, lion Lua 0.0 ms/s' -- The last second's, for each follow line of that second.
    local boss,next_boss={},0 -- The boss name TextBlocks held, and when to look for them again.
    local failed={} -- The boss name's last error, said once.
    local function lion_line() return Lion.parse(status and status()) end
    local her=N.her
    -- The 14 tables by name, and those missing.
    local function tables()
        local found,missing,words={},{},{}
        for _,t in ipairs(Lion.TABLES) do
            local dt=valid(StaticFindObject(DATA..t..'.'..t))
            if dt and dt:IsA(U.find('/Script/Engine.DataTable')) then
                found[t]=dt
                words[#words+1]=string.format('%s=0x%x',t,U.address(dt))
            else missing[#missing+1]=t end
        end
        return found,missing,words
    end
    -- The one spawn call: an ID of IDS only; cheat on (any CharacterTable ID at any transform), not a player, player 0,
    -- key 0 and spawn index 0 (EventSpawnId 0, as SB's own summons), no spawn point, no possess.
    local function create(id,at,yaw)
        assert(Lion.IDS[id],'not a Lion ID')
        local pc=assert(N.controller(),'no SB player controller')
        pc:ServerRequest_CreateActor(id,at,{Pitch=0,Yaw=yaw,Roll=0},false,true,0,0,0,FName('None'),false)
    end
    -- The objects of class (a Blueprint class's short name, or SBCharacter) but EVE, by address.
    local function bodies(class)
        local eve=her()
        local list,me={},eve and U.address(eve)
        U.each(FindAllOf(class) or {},function(_,c)
            c=valid(c)
            local ok,a=pcall(U.address,c)
            if ok and a and a~=me then list[a]=c end
        end)
        return list
    end
    local function spawn_count() local s=lion_line(); return s and s.spawns end
    local function counted(n) return n and tostring(n) or '?' end
    -- A followed body's end: D1 (its death, then its despawn or why it was let go) and D2 (the spawn manager's counter
    -- before the spawn, when the body was found and now).
    local function let_go(f,said)
        for k,g in ipairs(followed) do
            if g==f then
                table.remove(followed,k)
                break
            end
        end
        log(said)
        log(string.format('lion %d spawn count: before %s, alive %s, %s %s',f.n,counted(f.before),counted(f.alive),
            f.dead and 'after death' or 'after',counted(spawn_count())))
    end
    -- The body's mesh, as the engine ticks it: what could keep its pose still while its logic runs. A field that
    -- cannot be read is a ?.
    local function named(o) local a=valid(o); return a and text(a:GetFName()) or 'none' end
    local function mesh_state(c)
        local m=valid(c.Mesh)
        if not m then return 'no mesh' end
        local function read(get)
            local fine,v=pcall(get)
            if not fine then return '?' end
            v=value_of(v)
            return v==nil and '?' or tostring(v)
        end
        return string.format('anim instance %s, anim class %s, its skeleton %s, mesh skeleton %s, mode %s, '
            ..'leader %s, anim set sync %s, mesh %s, tick %s, pause %s, rate %s, '
            ..'no skeleton update %s, visibility tick %s, rate optimizations %s, actor dilation %s, '
            ..'sequencer anim mode %s',
            read(function() local a=valid(m:GetAnimInstance()); return a and class_of(a) or 'none' end),
            read(function() local a=valid(m.AnimClass); return a and text(a:GetFName()) or 'none' end),
            read(function() return named(valid(m.AnimClass).TargetSkeleton) end),
            read(function() return named(valid(m.SkeletalMesh).Skeleton) end),
            read(function() return m:GetAnimationMode() end),
            read(function() local l=valid(U.weak(m.MasterPoseComponent)); return l and path_of(l) or 'none' end),
            read(function() return c.bInitAnimSetSyncData end),
            read(function() local a=valid(m.SkeletalMesh); return a and text(a:GetFName()) or 'none' end),
            read(function() return m:IsComponentTickEnabled() end),read(function() return m.bPauseAnims end),
            read(function() return m.GlobalAnimRateScale end),read(function() return m.bNoSkeletonUpdate end),
            read(function() return m.VisibilityBasedAnimTickOption end),
            read(function() return m.bEnableUpdateRateOptimizations end),
            read(function() return c.CustomTimeDilation end),read(function() return c.bSequencerAnimMode end))
    end
    -- A mesh with no anim instance gets one: with its own anim class, then each of ANIM_CLASSES (found by path, its
    -- package loaded first when it is not yet), the class written into AnimClass, then SetAnimationMode 1 and 0, until
    -- the mesh has an instance. Returns what each try gave, as words (an error's first line only).
    local function give_anim(m,own_only)
        local said={}
        local function has() return valid(m:GetAnimInstance())~=nil end
        local function try(name,c)
            local fine,e=pcall(function()
                if c then m.AnimClass=c end
                m:SetAnimationMode(1) -- EAnimationMode::AnimationSingleNode, then AnimationBlueprint: a rebuild.
                m:SetAnimationMode(0)
            end)
            said[#said+1]=name..' '..(not fine and 'failed ('..why(e):match('^[^\n]*')..')' or has() and 'built one'
                or 'built none')
        end
        try('its own class',nil)
        for _,a in ipairs(own_only and {} or ANIM_CLASSES) do
            if has() then break end
            local c=valid(StaticFindObject(a.class))
            if not c then
                pcall(LoadAsset,a.package)
                c=valid(StaticFindObject(a.class))
            end
            if c then try(a.name,c) else said[#said+1]=a.name..' does not load' end
        end
        return table.concat(said,', ')
    end
    -- An object by path, its package loaded first when it is not yet; raises when it does not load.
    local function load(path,name)
        local o=valid(StaticFindObject(path))
        if not o then
            pcall(LoadAsset,path)
            o=valid(StaticFindObject(path))
        end
        return assert(o,name..' does not load')
    end
    -- The leader (see LEADER_MESH): the body's mesh component takes the Behemoth's mesh and the Lion's AnimBP, then is
    -- drawn in no pass (main, depth, shadow) but stays in the scene, so the engine still counts it as rendered and SB's
    -- OnlyTickPoseWhenRendered keeps ticking it (the 2026-10-24 test, with it hidden, found transitions stiff); its
    -- cloth is not simulated. A new component on the body, attached to it with no offset (so with its place and 1.5
    -- scale), draws the Lion's mesh in SB's character light channel and copies its pose. Returns the new component;
    -- raises, the Lion's mesh back and no new component left, when anything fails.
    local function lead(c)
        local m=valid(c.Mesh)
        local lion_mesh=assert(valid(m.SkeletalMesh),'no Lion mesh on the body')
        local leader_mesh=load(LEADER_MESH.path,LEADER_MESH.name)
        local class=load(ANIM_CLASSES[1].class,ANIM_CLASSES[1].name)
        m:SetSkeletalMesh(leader_mesh,true)
        m.AnimClass=class
        m:SetAnimationMode(1)
        m:SetAnimationMode(0)
        if not valid(m:GetAnimInstance()) then
            m:SetSkeletalMesh(lion_mesh,true) -- Never a Behemoth drawn as the Lion: its own mesh back.
            error('the Lion AnimBP builds no instance on '..LEADER_MESH.name..' either',0)
        end
        local f
        local made,e=pcall(function()
            local identity=load('/Script/Engine.Default__KismetMathLibrary','KismetMathLibrary'):MakeTransform(
                {X=0,Y=0,Z=0},{Pitch=0,Yaw=0,Roll=0},{X=1,Y=1,Z=1})
            local skinned=load('/Script/Engine.SkeletalMeshComponent','SkeletalMeshComponent')
            f=assert(valid(c:AddComponentByClass(skinned,true,identity,false)),'no component for the Lion mesh')
            f:SetCollisionEnabled(0)
            f:K2_AttachToComponent(m,FName('None'),0,0,0,false) -- EAttachmentRule::KeepRelative, all three.
            f:SetMasterPoseComponent(m,true)
            f:SetSkeletalMesh(lion_mesh,true)
            f:SetLightingChannels(true,true,false) -- As the body's mesh: SB lights its characters in channel 1.
            m:SetRenderInMainPass(false)
            m.bRenderInDepthPass=false
            m:SetCastShadow(false)
            m.bDisableClothSimulation=true
        end)
        if not made then
            if f then pcall(function() f:K2_DestroyComponent(c) end) end
            pcall(function()
                m:SetRenderInMainPass(true)
                m.bRenderInDepthPass=true
                m:SetCastShadow(true)
                m:SetSkeletalMesh(lion_mesh,true)
            end)
            error(e,0)
        end
        return f
    end
    -- The stand-in when give_anim built nothing: the single-node instance playing DRIVE_BS. True once it has one.
    local function drive_start(m)
        local bs=valid(StaticFindObject(DRIVE_BS))
        if not bs then
            pcall(LoadAsset,DRIVE_BS)
            bs=assert(valid(StaticFindObject(DRIVE_BS)),'IdleRun_BS_ does not load')
        end
        m:PlayAnimation(bs,true)
        return valid(m:GetAnimInstance())~=nil
    end
    -- BONE in the body's own frame (cm, yaw only): it moves when the mesh plays anything, and not when its actor moves.
    local function hand(c)
        local p=value_of(valid(c.Mesh):GetSocketLocation(FName(BONE)))
        local at,yaw=location(c),math.rad(value_of(c:K2_GetActorRotation()).Yaw)
        local x,y=p.X-at.X,p.Y-at.Y
        return {X=x*math.cos(yaw)+y*math.sin(yaw),Y=y*math.cos(yaw)-x*math.sin(yaw),Z=p.Z-at.Z}
    end
    local function follow_one(f,now)
        local ok,c=pcall(Doro.same,f.obj,f.path)
        local name=string.format('lion %d (%d)',f.n,f.id)
        if not (ok and c) then
            if f.dead then
                return let_go(f,string.format('%s dead after %.0f s (InteractionState %s, no controller); body gone '
                    ..'after %.1f s',name,f.dead-f.since,tostring(f.state),now-f.dead))
            end
            return let_go(f,string.format('%s gone while alive after %.0f s (a map change, or the game removed it)',
                name,now-f.since))
        end
        if not f.dead and killed(c) then f.dead,f.state=now,c.InteractionState end
        if f.dead then
            if now-f.dead<GONE then return end
            return let_go(f,string.format('%s dead after %.0f s (InteractionState %s, no controller); body still there '
                ..'after %d s, no longer followed',name,f.dead-f.since,tostring(f.state),GONE))
        end
        local eve=her()
        local read,battle=pcall(function() return c:IsBattle()==true end)
        local function num(fmt,read_it) -- A number read off the body, or ? when the call fails.
            local fine,v=pcall(read_it)
            v=fine and tonumber(value_of(v))
            return v and string.format(fmt,v) or '?'
        end
        local skill_read,skill=pcall(function() return c:IsRunningSkill()==true end)
        local at_read,at=pcall(function() return xyz(location(c)) end)
        local state=mesh_state(c)
        if state~=f.mesh then log(string.format('%s mesh: %s',name,state)) end
        f.mesh=state
        -- Once a body, the anim instance it lacks: SetAnimInstanceClass, then its mesh line again.
        -- The control Antlion, once: the same rebuild with its own class, which tells whether the rebuild works on a
        -- shipped Naytiba's body (its instance is built again; it is never given the Lion's classes).
        if f.id==CONTROL and not f.given then
            f.given=true
            local fine,e=pcall(give_anim,valid(c.Mesh),true)
            f.mesh=mesh_state(c)
            log(string.format('%s rebuild test: %s; mesh: %s',name,fine and e or 'failed ('..why(e)..')',f.mesh))
        end
        if not f.given and f.id~=CONTROL and state:find('^anim instance none,') then
            f.given=true
            local fine,e=pcall(give_anim,valid(c.Mesh))
            e=fine and e or 'not given ('..why(e)..')'
            if not valid(valid(c.Mesh):GetAnimInstance()) then
                local led,l=pcall(lead,c)
                f.lead=led or nil
                e=e..'; leader: '..(led and 'the Lion AnimBP runs on a hidden '..LEADER_MESH.name..', the Lion mesh '
                    ..'copies its pose' or 'failed ('..why(l)..')')
            end
            if not valid(valid(c.Mesh):GetAnimInstance()) then
                local ran,driven=pcall(drive_start,valid(c.Mesh))
                f.drive=ran and driven and c or nil
                e=e..'; stand-in: '..(not ran and 'failed ('..why(driven)..')' or driven
                    and 'the single-node instance plays IdleRun_BS_ by speed' or 'no single-node instance either')
            end
            f.mesh=mesh_state(c)
            log(string.format('%s had no anim instance: %s; mesh: %s',name,e,f.mesh))
        end
        local hand_read,p=pcall(hand,c)
        local moved=hand_read and f.hand and string.format('%.0f cm',metres(p,f.hand)*100) or '?'
        f.hand=hand_read and p or nil
        log(string.format('%s: %s m, xyz %s, speed %s, skill %s, anim alpha %s/%s, hand moved %s, battle %s, state %s, '
            ..'controller %s, spawn count %s, %s',name,
            eve and string.format('%.1f',metres(location(c),location(eve))) or '?',
            at_read and at or '?',num('%.0f',function() return c:GetSBSpeedForAnimGraph() end),
            skill_read and (skill and 'yes' or 'no') or '?',
            num('%.2f',function() return c:GetCurrentCustomAnimAlpha(0) end),
            num('%.2f',function() return c:GetCurrentCustomAnimAlpha(1) end),moved,read and (battle and 1 or 0) or '?',
            tostring(c.InteractionState),valid(c.Controller) and 'yes' or 'no',counted(spawn_count()),frame_said))
    end
    -- While a Lion lives, once a second: the boss bar's name as BOSS_NAME where it reads <M_LionC> (SB writes it again
    -- at its next boss bind, and this puts it back).
    local function boss_name(now)
        local held=false
        for _,t in ipairs(boss) do held=held or valid(t)~=nil end
        if not held and now>=next_boss then
            next_boss,boss=now+BOSS_LOOK,{}
            U.each(FindAllOf('TextBlock') or {},function(_,t)
                t=valid(t)
                if t and text(t:GetFName())==BOSS_TEXT and text(t:GetFullName()):find(LIVE,1,true) then
                    boss[#boss+1]=t
                end
            end)
        end
        for _,t in ipairs(boss) do
            local shown=valid(t) and text(t:GetText())
            if shown and shown:find(BOSS_SHOWN) then
                t:SetText(FText(BOSS_NAME))
                log(string.format('boss name: %s -> %s',shown,BOSS_NAME))
            end
        end
    end
    -- A spawn's search (job.id, job.spot, job.before, job.class, job.display): at each of FINDS, the new body nearest
    -- the spot. Seen: the entrance copy removed at once, so the two never stand together. Found with no controller
    -- before ADOPT: looked at again then. Found: its default controller when it has none, S1 (with when it was first
    -- seen), the entrance line, followed from then on.
    local function search(j,now)
        local best,best_m,best_a=nil,nil,nil
        for a,c in pairs(bodies(j.class)) do
            if not j.taken[a] or j.taken[a]>FAR then
                local ok,d=pcall(function() return metres(location(c),j.spot) end)
                if ok and d<=NEAR and (not best_m or d<best_m) then best,best_m,best_a=c,d,a end
            end
        end
        local after=now-j.called
        j.seen=best and (j.seen or after)
        if best and j.display then
            pcall(Doro.remove,j.display)
            j.display=nil
        end
        if best and best.InteractionState==0 and not valid(best.Controller) and after<ADOPT then
            j.at=j.called+ADOPT
            return
        end
        if not best then
            j.tries=j.tries+1
            if j.tries<#FINDS then
                j.at=j.called+FINDS[j.tries+1]
                return
            end
            if j.display then pcall(Doro.remove,j.display) end
            log(string.format('spawn %d: CreateActor returned; no body after %g s',j.id,FINDS[#FINDS]))
            return false,string.format('%s %d: the spawn call returned but no body showed in %g s ([LI] lines in '
                ..'UE4SS.log).',Lion.IDS[j.id],j.id,FINDS[#FINDS])
        end
        local adopted=''
        if best.InteractionState==0 and not valid(best.Controller) then
            local ok=pcall(function() best:SpawnDefaultController() end)
            adopted=ok and valid(best.Controller) and ' (SpawnDefaultController gave it)'
                or ' (SpawnDefaultController failed)'
        end
        local ctl=valid(best.Controller)
        local read,key=pcall(key_of,best)
        local eve=her()
        local from=eve and metres(location(best),location(eve))
        local reused=j.taken[best_a] and string.format('; a body SB reused (%.0f m from the spot at the call)',
            j.taken[best_a]) or ''
        for _,f in ipairs(j.taken[best_a] and {table.unpack(followed)} or {}) do
            if f.address==best_a then
                let_go(f,string.format('lion %d (%d) recycled: SB moved its body back for this spawn',f.n,f.id))
            end
        end
        log('before the spawn: '..perf_take()) -- While the command ran, the Lion not there yet: to compare with.
        log(string.format('spawn %d: CreateActor returned; body %s %s m from EVE, %.1f m from the spot, after %.1f s; '
            ..'controller %s%s; EventSpawnId %s%s',j.id,class_of(best),from and string.format('%.1f',from) or '?',
            best_m,j.seen,ctl and class_of(ctl) or 'none',adopted,read and tostring(key) or '?',reused))
        if not j.intro and j.id~=CONTROL then
            log('entrance: skipped (off by default: the Lion AnimBP has no montage slot, and a clip on its mesh would '
                ..'replace the anim instance SB plays its skills on; coop lion intro plays it on a display copy before '
                ..'the spawn)')
        end
        spawned=spawned+1
        followed[#followed+1]={n=spawned,id=j.id,obj=best,path=path_of(best),address=best_a,since=now,
            before=j.before,alive=spawn_count()}
        if not followed[2] then next_follow=now+FOLLOW end -- Its first line a second from now.
        return true,string.format('%s %d is here, %s m from EVE: lion %d in the [LI] lines.',Lion.IDS[j.id],j.id,
            from and string.format('%.1f',from) or '?',spawned)
    end
    -- The spawn call at at, facing EVE, then the search; raises with nothing called when there is no EVE or controller.
    local function spawn(j,at,now)
        local eve=assert(her(),'no EVE in the world')
        j.spot,j.class=at,j.id==CONTROL and 'SBCharacter' or CLASS
        j.taken={} -- The bodies there before the call, each with its distance to the spot (m; 0 when unread).
        for a,c in pairs(bodies(j.class)) do
            local ok,d=pcall(function() return metres(location(c),at) end)
            j.taken[a]=ok and d or 0
        end
        j.before=spawn_count()
        local yaw=U.yaw_to(at,location(eve))
        create(j.id,at,yaw)
        j.called,j.tries,j.at,j.step=now,0,now+FINDS[1],search
        j.what='the search for its body'
        log(string.format('spawn %d (%s) at %s, %.1f m from EVE, yaw %.1f; spawn count %s',j.id,Lion.IDS[j.id],xyz(at),
            metres(at,location(eve)),yaw,counted(j.before)))
    end
    -- The spot AHEAD of EVE along her facing, UP above her middle; and where her feet are (her mesh's root).
    local function spot()
        local eve=assert(her(),'no EVE in the world')
        local at,yaw=location(eve),math.rad(value_of(eve:K2_GetActorRotation()).Yaw)
        local feet=value_of(valid(eve.Mesh):K2_GetComponentLocation())
        return {X=at.X+AHEAD*math.cos(yaw),Y=at.Y+AHEAD*math.sin(yaw),Z=at.Z+UP},feet.Z
    end
    -- coop lion intro's end: the Lion spawned where the copy's root is now (its bone 0, on the spot's height), or at
    -- the spot when that is unread or more than ROOT_FAR away; the copy stays on its last frame until the body shows.
    -- A map change meanwhile: no spawn (the spot is the old map's).
    local function intro_done(j,now)
        local eve=her()
        if not eve or U.map_of(eve)~=j.map then
            pcall(Doro.remove,j.display)
            log('entrance: the map changed during it: no spawn')
            return false,'The map changed during the Lion\'s entrance: no spawn.'
        end
        local ok,p=pcall(function()
            return value_of(j.display.mesh:GetSocketLocation(j.display.mesh:GetBoneName(0)))
        end)
        local at,said=j.spot,'its root unread ('..why(p)..')'
        if ok and type(p)=='table' and tonumber(p.X) and tonumber(p.Y) then
            local d=math.sqrt((p.X-j.spot.X)^2+(p.Y-j.spot.Y)^2)/100
            said=string.format('its root ended %.1f m from the spot',d)
            if d*100<=ROOT_FAR then at={X=p.X,Y=p.Y,Z=j.spot.Z} else said=said..', too far' end
        end
        log(string.format('entrance: played on a display copy for %.1f s; %s: the Lion spawns %s',now-j.played,said,
            at==j.spot and 'at the spot' or 'there'))

        spawn(j,at,now)
    end
    -- The display copy at the spot, on EVE's feet, facing her, playing the clip once; then intro_done when it ends.
    -- Any failure: the copy gone, the entrance skipped, the Lion spawned at once.
    local function intro(j,now,feet)
        local made,d=pcall(function()
            local eve=her()
            local at={X=j.spot.X,Y=j.spot.Y,Z=feet}
            local d=Doro.spawn(eve:GetWorld(),at,{Pitch=0,Yaw=U.yaw_to(at,location(eve))+MESH_YAW,Roll=0},{path=MESH})
            local ok,e=pcall(function()
                d.mesh:SetRelativeScale3D({X=MESH_SCALE,Y=MESH_SCALE,Z=MESH_SCALE})
                Doro.apply(d,{asset=CLIP,loop=false,rate=1,at=0})
            end)
            if not ok then
                pcall(Doro.remove,d)
                error(e,0)
            end
            return d
        end)
        if not made then
            log('entrance: skipped ('..why(d)..')')
            return spawn(j,j.spot,now)
        end
        local length=tonumber(select(2,pcall(function() return value_of(Doro.resolve(CLIP).SequenceLength) end)))
        length=length and length>0 and length or 13
        -- ponytail: the copy is in no file, so a Lua reload during its 13 s leaves it until the map changes; a
        -- coop-lion.txt swept at the next load (as coop-leviathan.txt) if that shows up.
        j.display,j.played,j.at,j.step,j.what=d,now,now+length,intro_done,'the entrance'
        log(string.format('entrance: playing Mon_LionC_Scene01_Appearance (%.1f s) on a display copy at %s',length,
            xyz({X=j.spot.X,Y=j.spot.Y,Z=feet})))
    end
    -- Once the rows are in (s: the lion line): the read-back (R4), then the spawn (or the entrance first); a rows-only
    -- job ends there. Returns ok, message when the job ends; nil once the spawn is under way.
    local function rows_in(j,s,now)
        for _,k in ipairs({'added','char','skills','stance'}) do
            if s[k]~=Lion.IN[k] then
                return false,string.format('The Lion rows are not all usable: %s (%s=%s, %s expected): no spawn.',
                    s.line,k,tostring(s[k]),Lion.IN[k])
            end
        end
        local n,wrong,fields,changed=read_back(j.tables)
        if wrong then
            log(string.format('rows read back through FindRow: %s (%d/%d match before it): no spawn',wrong,n,
                #Lion.ROWS))
            return false,'A Lion row reads back wrong ('..wrong..'): no spawn.'
        end
        log(string.format('rows read back through FindRow: %d/%d authored rows, %d fields as written (%d differ from '
            ..'the template row)',n,#Lion.ROWS,fields,changed))
        if j.rows_only then
            return true,string.format('Lion rows in: %s added, SB finds them by ID (char %s, skills %s, stance %s) and '
                ..'they read back as written; coop lion spawns one.',s.added,s.char,s.skills,s.stance)
        end
        local ok,e=pcall(function()
            local at,feet=spot()
            j.spot=at
            if j.intro then intro(j,now,feet) else spawn(j,at,now) end
        end)
        if not ok then return false,'No spawn: '..why(e) end
    end
    -- The wait for the native part's answer: the rows in, or a refusal or a fault finished after the ask (asks grown).
    -- A waiting line goes on waiting even with asks grown: an earlier ask finished, then the game thread took ours.
    local function wait(j,now)
        local eve=her()
        if not eve or U.map_of(eve)~=j.map then
            return false,'The map changed while the Lion rows were asked: no spawn.'
        end
        local s=lion_line()
        if s and (s.state=='rows' or s.asks>j.asks and (s.state=='refused' or s.state=='fault')) then
            log('rows answer: '..s.line)
            if s.state=='rows' then return rows_in(j,s,now) end
            if s.state=='fault' then return false,'The Lion rows stopped on a fault ('..tostring(s.where)..').' end
            return false,string.format('The native part refused the Lion rows (why=%s, table=%s, row=%s): '
                ..'coop-link.log says why; asking again skips the rows already in.',tostring(s.why),tostring(s.table),
                tostring(s.row))
        end
        if now-j.asked>=WAIT then
            return false,string.format('No answer on the Lion rows in %d s (%s): coop-link.log says why.',WAIT,
                s and s.line or 'no lion line')
        end
        if s and s.state=='waiting' and not j.said then
            j.said=true
            log('rows wait for the game thread: '..s.line)
        end
        j.at=now+POLL
    end
    -- coop lion, coop lion intro and coop lion rows: the tables (R1), then the rows already in (R5) or asked. Returns
    -- ok, message; the job goes on in tick() when it waits.
    local function start(intro_wanted,rows_only)
        local eve=her()
        if not eve then return false,'no EVE in the world (load a save first): nothing was asked' end
        local found,missing,words=tables()
        if #missing>0 then
            log(string.format('tables: %d/%d found, missing %s: nothing asked',#words,#Lion.TABLES,
                table.concat(missing,', ')))
            return false,'The game has no '..table.concat(missing,', ')..' loaded: nothing was asked.'
        end
        log(string.format('tables: %d/%d found: %s',#words,#Lion.TABLES,table.concat(words,' ')))
        local s=lion_line()
        if not s then
            return false,'coop-status.txt has no lion line: the native part is off, or older than coop lion '
                ..'(coop-link.log): nothing was asked'
        end
        if s.state=='fault' then
            return false,'The Lion rows stopped on a fault this game run ('..tostring(s.where)..').'
        end
        local now=os.clock()
        local j={id=brain,intro=intro_wanted,rows_only=rows_only,tables=found,map=U.map_of(eve)}
        if s.state=='rows' then
            log(string.format('rows already in (%s; SB\'s lookups by ID: char %s, skills %s, stance %s): not added '
                ..'again',tostring(s.added),tostring(s.char),tostring(s.skills),tostring(s.stance)))
            local ok,message=rows_in(j,s,now)
            if ok~=nil then return ok,message end
            job=j
            return true,string.format('%s %d asked: [LI] lines follow.',Lion.IDS[j.id],j.id)
        end
        local asked,said=ask('lion rows '..table.concat(words,' '))
        if not asked then return false,'Lion rows not asked: '..tostring(said) end
        j.asks,j.asked,j.at,j.step,j.what=s.asks,now,now+POLL,wait,'the wait for the Lion rows'
        job=j
        log(string.format('rows asked of the native part (%s): its answer is the next asks= past %d',s.line,s.asks))
        return true,'Lion rows asked of the native part: the '..(rows_only and 'read-back' or 'spawn')
            ..' follows once they are in ([LI] lines).'
    end
    -- coop lion control: 50110 through the same call and search, no rows needed.
    local function control()
        local ok,e=pcall(function()
            local j={id=CONTROL}
            spawn(j,(spot()),os.clock())
            job=j
        end)
        if not ok then return false,'No spawn: '..why(e) end
        return true,'Antlion 50110 asked: [LI] lines follow.'
    end
    -- coop lion unfreeze [init]: on each living Lion, every engine switch that can hold a mesh's pose put back to its
    -- running value (component tick, anim pause, the rate scale, skeleton updates, the visibility-based and
    -- rate-optimized ticking, the actor's time dilation), then its mesh line again; init also builds its anim instance
    -- again (give_anim), which SB's skills may not survive: last. The follow line's hand moved says whether the pose
    -- moves after it.
    local function unfreeze(init)
        local n=0
        for _,f in ipairs(followed) do
            local ok,c=pcall(Doro.same,f.obj,f.path)
            local m=ok and c and not f.dead and valid(c.Mesh)
            if m then
                local done={}
                local function try(word,set)
                    local fine,e=pcall(set)
                    done[#done+1]=fine and word or word..' failed ('..why(e)..')'
                end
                try('tick',function() m:SetComponentTickEnabled(true) end)
                try('pause',function() m.bPauseAnims=false end)
                try('rate',function() m.GlobalAnimRateScale=1.0 end)
                try('skeleton',function() m.bNoSkeletonUpdate=false end)
                try('visibility',function() m.VisibilityBasedAnimTickOption=0 end) -- AlwaysTickPoseAndRefreshBones.
                try('optimizations',function() m.bEnableUpdateRateOptimizations=false end)
                try('dilation',function() c.CustomTimeDilation=1.0 end)
                if init then
                    local fine,e=pcall(give_anim,m)
                    done[#done+1]='init: '..(fine and e or 'failed ('..why(e)..')')
                end
                f.mesh=mesh_state(c)
                log(string.format('lion %d (%d) unfreeze: %s; mesh: %s',f.n,f.id,table.concat(done,', '),f.mesh))
                n=n+1
            end
        end
        if n==0 then return false,'No living Lion followed: coop lion spawns one.' end
        return true,string.format('unfreeze on %d Lion%s: see its mesh and hand moved lines ([LI] lines).',n,
            n>1 and 's' or '')
    end
    -- Lion.rows, for the Night Operation shop's cut items (nightop/shop.lua): coop lion rows' steps (the tables, the
    -- rows already in or the ask, the wait, the read-back), then done(ok, message) with how they ended; what done
    -- returns is the end said. Returns done's ok, message when it ends at once, or ok, message, true while it waits:
    -- done then follows from tick() (not after coop off, which drops the wait).
    function self.rows(done)
        if job then return done(false,'coop lion is busy ('..job.what..'): try again in a few seconds') end
        local ok,message=start(false,true)
        if job and ok then
            job.done=done
            return ok,message,true
        end
        return done(ok,message)
    end
    -- brain sets the ID of the next spawns, even while a command runs; the others wait for it.
    function self.command(sub,a,extra)
        if extra~=nil then return false,USE end
        if sub=='brain' and BRAINS[a] then
            brain=BRAINS[a]
            log('brain: '..a..', CharacterTable '..brain..' ('..Lion.IDS[brain]..')')
            return true,string.format('coop lion spawns %d (%s, the %s tree) until the mod reloads.',brain,
                Lion.IDS[brain],a=='lurker' and 'Lesser Lurker' or 'Skulling test')
        end
        if sub=='unfreeze' and (a==nil or a=='init') then return unfreeze(a=='init') end
        if a~=nil or not (sub==nil or sub=='intro' or sub=='rows' or sub=='control') then return false,USE end
        if job then return false,'coop lion is busy ('..job.what..'): try again in a few seconds' end
        if sub=='rows' then return start(false,true) end
        if sub=='control' then return control() end
        return start(sub=='intro',false)
    end
    -- Each frame, on the game thread: the job's step when due (ok, message when it ends, also on its first error), and
    -- each followed body once a second.
    function self.tick()
        local now=os.clock()
        local ok,message
        if job or followed[1] then
            local fine,dt=pcall(function()
                if not valid(ctx) then ctx=her() end
                gs=gs or valid(StaticFindObject('/Script/Engine.Default__GameplayStatics'))
                return tonumber(value_of(gs:GetWorldDeltaSeconds(ctx)))
            end)
            if fine and dt then perf.frames,perf.sum,perf.worst=perf.frames+1,perf.sum+dt,math.max(perf.worst,dt) end
        end
        if job and now>=job.at then
            local j=job
            local ran,done,said=pcall(j.step,j,now)
            if not ran then
                if j.display then pcall(Doro.remove,j.display) end
                ok,message=false,'coop lion stopped on an error: '..why(done)
            elseif done~=nil then ok,message=done,said end
            if ok~=nil and job==j then job=nil end
            if ok~=nil and j.done then -- Lion.rows' caller says the end.
                local fine,a,b=pcall(j.done,ok,message)
                if fine then ok,message=a,b else ok,message=false,'after the Lion rows: '..why(a) end
            end
        end
        -- The leaders, dead ones included (their death plays on it): AlwaysTickPoseAndRefreshBones each frame, in case
        -- the engine stops counting a mesh drawn in no pass as rendered. Only while the body is still the one met.
        -- The stand-ins: each frame, their blend space input from the anim graph speed.
        for _,f in ipairs(followed) do
            if f.lead then
                pcall(function()
                    local c=Doro.same(f.obj,f.path)
                    if not c then return end
                    local m=c.Mesh
                    if m.VisibilityBasedAnimTickOption~=0 then m.VisibilityBasedAnimTickOption=0 end
                end)
            end
            if f.drive and not f.dead then
                pcall(function()
                    if not Doro.same(f.drive,f.path) then return end
                    local m=f.drive.Mesh
                    if m:GetAnimationMode()~=1 then -- Out of single-node mode (unfreeze init built an AnimBP): done.
                        f.drive=nil
                        return
                    end
                    local speed=tonumber(value_of(f.drive:GetSBSpeedForAnimGraph())) or 0
                    m:GetAnimInstance():SetBlendSpaceInput({X=math.min(DRIVE_MAX,math.max(0,speed)),Y=0,Z=0})
                end)
            end
        end
        if followed[1] and now>=next_follow then
            next_follow=now+FOLLOW
            frame_said=perf_take()
            local took={}
            local t=os.clock()
            for _,f in ipairs({table.unpack(followed)}) do
                local fine,e=pcall(follow_one,f,now)
                if not fine then let_go(f,string.format('lion %d no longer followed: %s',f.n,why(e))) end
            end
            took[1]=string.format('follow %.1f ms',(os.clock()-t)*1000)
            local lives=false
            for _,f in ipairs(followed) do lives=lives or (f.id~=CONTROL and not f.dead) end
            if lives then
                t=os.clock()
                local fine,e=pcall(boss_name,now)
                took[2]=string.format('boss name %.1f ms',(os.clock()-t)*1000)
                e=not fine and string.format('boss name: unread (%s)',why(e))
                if e and e~=failed.boss then log(e) end
                failed.boss=e
            end
            parts=table.concat(took,', ')
        end
        local spent=(os.clock()-now)*1000
        perf.lua,perf.tick=perf.lua+spent,math.max(perf.tick,spent)
        return ok,message
    end
    -- coop off: the job ended (an entrance copy removed), the bodies no longer followed. A living Lion stays: it is the
    -- game's enemy now, and nothing here despawns one.
    function self.stop()
        if job and job.display then pcall(Doro.remove,job.display) end
        local said=job and 'coop off: '..job.what..' ended' or nil
        job=nil
        if followed[1] then
            said=(said and said..'; ' or 'coop off: ')..#followed..' Lion bodies no longer followed (they stay)'
        end
        followed={}
        if said then log(said) end
    end
    return self
end
return Lion
