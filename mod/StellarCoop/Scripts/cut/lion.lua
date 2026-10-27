-- coop lion: the cut Naytiba 02, the Lion (/Game/Art/Character/Monster/CH_M_NA_02/: blueprint, mesh, clips, collision
-- data and 41 Shows, but no table row), spawned as a real enemy to fight, on the game thread (plan A of the Lion study,
-- made native). Its 222 rows, each authored for it (cut/lion_rows.lua lists them), go into SB's tables through the
-- native part (lion/rows.h, glue/tick/lion_game.inc: SB's own AddRow on the game thread with no logic task in flight),
-- after the 4 rows of the cut items the Night Operation shop sells (2 ItemTable rows, an ItemConsumableTable row and
-- the SkillTable row they play) and the 11 of EVE's cut Tachy ChainSpin (its skill, 9 steps and the effect that starts
-- it), 237 rows: the lion rows batch. The shop and coop chainspin ask for them through Lion.rows (nightop/shop.lua,
-- cut/chainspin.lua). The 4 rows of the Shock Bolt ammo the shop sells too (its item, skill, projectile and hit result)
-- are a batch of their own, the bolt rows batch, which only the shop asks for through Lion.rows, so they never
-- stand in front of the Lion's; once they are in, the native part also grows EVE's gun stances and the ammo list for
-- the Shock Bolt (lion/shock.h, the status's shock line). The Night Operation shop's 6 rows (the Beta Seed's item,
-- three shop items and two shops) are a sixth batch, the shop rows batch, which coop nightop shop asks for before it
-- opens SB's shop screen, with the other two.
-- The flow is cut/enemy.lua's, which coop gardener fight shares: the tables, the lion rows request, the wait on the
-- lion line, the read-back, the one spawn call (10 m ahead of EVE and 1 m up, facing her) and the lines that follow
-- the body. This file holds the Lion's spec and its own parts. The IDs: 50020 (M_LionC, the Skulling test tree), 50021
-- after coop lion brain lurker (M_LionC_Lurker, the Lesser Lurker tree), or for coop lion control 50110 (M_Antlion, a
-- shipped Naytiba, which tells a broken call from broken rows), its body the nearest new SB character. While a Lion
-- lives, cut/enemy.lua sets the boss bar's name, which the game shows as <M_LionC> (no Lion text in
-- CharacterStringTable), to Lion. coop lion unfreeze puts the mesh's engine switches back to their running values
-- on each living Lion (the test of a body whose pose stays on frame 1); a body whose mesh has no anim instance runs the
-- Lion's AnimBP on a hidden Behemoth mesh that the Lion's mesh copies (LEADER_MESH says why), or a single-node stand-in
-- when that fails.
-- The entrance: the Lion's AnimBP (CH_M_NA_02_AnimBP) has no montage slot, so a montage would not show, and a
-- single-node clip on its mesh would replace the anim instance SB plays its skills on while its AI runs. So coop lion
-- spawns at once, and coop lion intro first plays Mon_LionC_Scene01_Appearance (the cut boss intro's clip) on a display
-- copy with the Large mesh, then spawns the Lion where the copy's root ended.
local U=require('core.unreal')
local Doro=require('race.doro')
local Enemy=require('cut.enemy')
local valid,value_of,why=U.valid,U.value_of,Enemy.why
local Lion={}
Lion.TABLES=Enemy.TABLES -- The 19 tables, in the native part's order (link/protocol.h's kLionTables).
-- The only IDs the spawn call takes, with what each is; the brains are the Lion's two CharacterTable rows.
Lion.IDS={[50020]='M_LionC',[50021]='M_LionC_Lurker',[50110]='M_Antlion'}
local BRAINS={skulling=50020,lurker=50021}
local CONTROL=50110
local DIR='/Game/Art/Character/Monster/CH_M_NA_02/'
local USE='Use: coop lion [intro] | rows | control | brain skulling|lurker | unfreeze [init]'
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
-- The boss bar's name: the text the game shows for the Lion (its row name, as CharacterStringTable has no Lion text),
-- and ours (cut/enemy.lua writes it).
local BOSS_SHOWN,BOSS_NAME='^<M_LionC[%w_]*>$','Lion'

-- The rows as the native part writes them: cut/lion_rows.lua's R.ROWS, which the generator of lion/rows.h writes from
-- the same recipe (tests/lua/cut/lion_test.lua checks the two agree), in Enemy.rows' form.
Lion.ROWS=Enemy.rows(require('cut.lion_rows').ROWS)
-- The lion line's counts once every row is in: added=, and SB's lookups by ID (char=, skills=, stance=).
Lion.IN=Enemy.counts(Lion.ROWS)
-- The lion line (glue's rows_status) as fields (Enemy.parse).
function Lion.parse(status) return Enemy.parse(status,'lion') end
-- The Shock Bolt's 4 rows, the bolt rows batch: cut/lion_rows.lua's R.BOLT (lion_test checks it against rows.h's
-- kBoltRecipe), in Enemy.rows' form.
Lion.BOLT=Enemy.rows(require('cut.lion_rows').BOLT)
-- The Night Operation shop's 6 rows, the shop rows batch: cut/lion_rows.lua's R.SHOP (the Beta Seed's ItemTable row,
-- three ShopItemTable rows and two ShopTable rows), which nightop/shop.lua asks for before it opens SB's shop screen.
Lion.SHOP=Enemy.rows(require('cut.lion_rows').SHOP)

-- o: log (the [LI] lines), ask(line) the native request (ok, message), status() the native status text.
function Lion.new(o)
    local log=o.log
    local self={}
    local brain=BRAINS.skulling
    local e -- cut/enemy.lua's, made below with the hooks that use it.
    -- A mesh with no anim instance gets one: with its own anim class, then each of ANIM_CLASSES (found by path, its
    -- package loaded first when it is not yet), the class written into AnimClass, then SetAnimationMode 1 and 0, until
    -- the mesh has an instance. Returns what each try gave, as words (an error's first line only).
    local function give_anim(m,own_only)
        local said={}
        local function has() return valid(m:GetAnimInstance())~=nil end
        local function try(name,c)
            local fine,err=pcall(function()
                if c then m.AnimClass=c end
                m:SetAnimationMode(1) -- EAnimationMode::AnimationSingleNode, then AnimationBlueprint: a rebuild.
                m:SetAnimationMode(0)
            end)
            said[#said+1]=name..' '..(not fine and 'failed ('..why(err):match('^[^\n]*')..')' or has() and 'built one'
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
        local x=valid(StaticFindObject(path))
        if not x then
            pcall(LoadAsset,path)
            x=valid(StaticFindObject(path))
        end
        return assert(x,name..' does not load')
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
        local made,err=pcall(function()
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
            error(err,0)
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
    -- Once a second before a body's follow line (its mesh line said): the control Antlion, once, the rebuild with its
    -- own class, which tells whether the rebuild works on a shipped Naytiba's body (its instance is built again; it is
    -- never given the Lion's classes); a Lion with no anim instance, once, the instance it lacks (give_anim), then the
    -- leader, then the stand-in, and its mesh line again.
    local function follow(f,c,state)
        local name=string.format('lion %d (%d)',f.n,f.id)
        if f.id==CONTROL and not f.given then
            f.given=true
            local fine,err=pcall(give_anim,valid(c.Mesh),true)
            f.mesh=e.mesh_state(c)
            log(string.format('%s rebuild test: %s; mesh: %s',name,fine and err or 'failed ('..why(err)..')',f.mesh))
        end
        if not f.given and f.id~=CONTROL and state:find('^anim instance none,') then
            f.given=true
            local fine,said=pcall(give_anim,valid(c.Mesh))
            said=fine and said or 'not given ('..why(said)..')'
            if not valid(valid(c.Mesh):GetAnimInstance()) then
                local led,l=pcall(lead,c)
                f.lead=led or nil
                said=said..'; leader: '..(led and 'the Lion AnimBP runs on a hidden '..LEADER_MESH.name..', the Lion '
                    ..'mesh copies its pose' or 'failed ('..why(l)..')')
            end
            if not valid(valid(c.Mesh):GetAnimInstance()) then
                local ran,driven=pcall(drive_start,valid(c.Mesh))
                f.drive=ran and driven and c or nil
                said=said..'; stand-in: '..(not ran and 'failed ('..why(driven)..')' or driven
                    and 'the single-node instance plays IdleRun_BS_ by speed' or 'no single-node instance either')
            end
            f.mesh=e.mesh_state(c)
            log(string.format('%s had no anim instance: %s; mesh: %s',name,said,f.mesh))
        end
    end
    -- Each frame: the leaders, dead ones included (their death plays on it), AlwaysTickPoseAndRefreshBones, in case
    -- the engine stops counting a mesh drawn in no pass as rendered, only while the body is still the one met; the
    -- stand-ins, their blend space input from the anim graph speed.
    local function frame(f)
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
    e=Enemy.new(o,{word='lion',name='Lion',command='coop lion',tag='[LI]',rows=Lion.ROWS,ids=Lion.IDS,
        class='CH_M_NA_02_BluePrint_Large_C', -- The Large blueprint, the Lion's appearance row.
        -- cm: the spot ahead of EVE and above her middle, so the body lands (the probe's 1 m).
        ahead=function() return 1000 end,up=100,
        -- The Large blueprint's mesh at its scale (1.5); the cut boss intro's clip. yaw: degrees the display copy turns
        -- from the Lion's facing: the Large blueprint sets no mesh rotation (a starting value, tuned in game).
        entrance={mesh=DIR..'CH_M_NA_02_Large.CH_M_NA_02_Large',
            clip=DIR..'Animation/Mon_LionC_Scene01_Appearance.Mon_LionC_Scene01_Appearance',scale=1.5,yaw=0,seconds=13},
        skipped='off by default: the Lion AnimBP has no montage slot, and a clip on its mesh would replace the anim '
            ..'instance SB plays its skills on; coop lion intro plays it on a display copy before the spawn',
        boss={shown=BOSS_SHOWN,name=BOSS_NAME},follow=follow,frame=frame})
    -- The bolt rows batch through the same flow, rows only, on a job of its own; its [LI] lines start with bolt.
    local bolt=Enemy.new({log=function(m) log('bolt '..m) end,ask=o.ask,status=o.status},
        {word='bolt',name='Shock Bolt',command='coop nightop buy',tag='[LI]',rows=Lion.BOLT,ids={}})
    -- The shop rows batch likewise; its [LI] lines start with shop.
    local shop=Enemy.new({log=function(m) log('shop '..m) end,ask=o.ask,status=o.status},
        {word='shop',name='Night Operation shop',command='coop nightop shop',tag='[LI]',rows=Lion.SHOP,ids={}})
    -- coop lion unfreeze [init]: on each living Lion, every engine switch that can hold a mesh's pose put back to its
    -- running value (component tick, anim pause, the rate scale, skeleton updates, the visibility-based and
    -- rate-optimized ticking, the actor's time dilation), then its mesh line again; init also builds its anim instance
    -- again (give_anim), which SB's skills may not survive: last. The follow line's hand moved says whether the pose
    -- moves after it.
    local function unfreeze(init)
        local n=0
        for _,f in ipairs(e.followed()) do
            local ok,c=pcall(Doro.same,f.obj,f.path)
            local m=ok and c and not f.dead and valid(c.Mesh)
            if m then
                local done={}
                local function try(word,set)
                    local fine,err=pcall(set)
                    done[#done+1]=fine and word or word..' failed ('..why(err)..')'
                end
                try('tick',function() m:SetComponentTickEnabled(true) end)
                try('pause',function() m.bPauseAnims=false end)
                try('rate',function() m.GlobalAnimRateScale=1.0 end)
                try('skeleton',function() m.bNoSkeletonUpdate=false end)
                try('visibility',function() m.VisibilityBasedAnimTickOption=0 end) -- AlwaysTickPoseAndRefreshBones.
                try('optimizations',function() m.bEnableUpdateRateOptimizations=false end)
                try('dilation',function() c.CustomTimeDilation=1.0 end)
                if init then
                    local fine,err=pcall(give_anim,m)
                    done[#done+1]='init: '..(fine and err or 'failed ('..why(err)..')')
                end
                f.mesh=e.mesh_state(c)
                log(string.format('lion %d (%d) unfreeze: %s; mesh: %s',f.n,f.id,table.concat(done,', '),f.mesh))
                n=n+1
            end
        end
        if n==0 then return false,'No living Lion followed: coop lion spawns one.' end
        return true,string.format('unfreeze on %d Lion%s: see its mesh and hand moved lines ([LI] lines).',n,
            n>1 and 's' or '')
    end
    -- Lion.rows, for the Night Operation shop's cut items (nightop/shop.lua) and coop chainspin: cut/enemy.lua's rows
    -- with the lion rows batch, with word bolt the bolt rows batch (the shop's Shock Bolt: a buy of it, and the shop's
    -- screen), with word shop the shop rows batch (the shop's screen only).
    function self.rows(done,word) return (word=='bolt' and bolt or word=='shop' and shop or e).rows(done,brain) end
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
        local busy=e.busy()
        if busy then return false,busy end
        if sub=='rows' then return e.start(brain,false,true) end
        if sub=='control' then
            local ok,said=e.control(CONTROL)
            return ok,ok and 'Antlion 50110 asked: [LI] lines follow.' or said
        end
        return e.start(brain,sub=='intro',false)
    end
    -- Each frame, the three flows: what ended, every message when several ended in the same frame.
    function self.tick()
        local ok,message=e.tick()
        for _,f in ipairs({bolt,shop}) do
            local f_ok,f_message=f.tick()
            if f_message then
                if message then ok,message=ok and f_ok,message..' '..f_message else ok,message=f_ok,f_message end
            end
        end
        return ok,message
    end
    function self.stop()
        e.stop()
        bolt.stop()
        shop.stop()
    end
    return self
end
return Lion
