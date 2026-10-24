-- cut/lion.lua with fake UE4SS objects. Its row list (cut/lion_rows.lua, generated with rows.h) matches
-- native/src/lion/rows.h's generated recipe row for row (names, IDs, each patched field's kind and value, no field
-- more), and its tables are kLionTables in order. The rows are the Lion's own: no value names a Behemoth row or asset
-- but the sound set, every reference lands on a Lion row or a shipped generic one, the steps' moves are Lion moves, the
-- phase-2 stance turns at HP under 60% and starts the roar's effect, which uses the phase-2 roar skill. The lion line
-- parses in each of its forms. coop lion finds the 12 tables (a missing one, no EVE or no lion line asks nothing), asks
-- the rows once with every address in the native order, waits for the answer (a waiting line, or a refusal from before
-- the ask, is no answer; a map change, a refusal, a fault, 30 s or SB's lookups finding fewer rows stop it), reads
-- every row back through FindRow (the first value that differs stops before any spawn), then makes the one spawn call:
-- 50020 (50021 after brain lurker, 50110 for control, no rows needed) 10 m ahead and 1 m up, facing EVE, cheat on, key
-- 0. Rows already in are read back without an ask. The body is the new one nearest the spot (or one SB sent far away
-- and moved back, whose old follow ends as recycled), given its default controller when it still has none 1.5 s after
-- the call, then followed: a line a second (its place, anim speed, skill and custom anim alphas, a failed read as ?),
-- its death and its body's despawn with the spawn counts; none after 5 s stops. While a Lion lives, the loaded line
-- (two of the 40 Show and clip paths a second, each until seen; said once all were looked for, then at each change) and
-- the boss name (only the live TextBlock_BossName reading <M_LionC> set to Lion, again after the game writes it back;
-- FindAllOf at most every 10 s while none is held). coop lion intro plays the entrance on a display copy first and
-- spawns where its root ended (at the spot when that is too far), removing the copy as soon as the body shows; a map
-- change during it spawns nothing; a copy that cannot be made spawns at once. A second command waits while one runs
-- (brain does not); coop off ends the job and the copy. Never AddRow, RemoveRow or a call from a coroutine, and the
-- source names no save, quest, item, reward, achievement, possession, console, destroy or row call, and no spawn but
-- its one CreateActor and its one SpawnDefaultController.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
local socket_cost=nil -- s the next hand read takes on the clock: what the follow line's longest tick and parts time.
local function fname(t) return {type=function() return 'FName' end,ToString=function() return t end} end
FName=fname
-- UE4SS refuses a call from a lua_State it did not create, and a coroutine is one: every fake engine call checks it.
local function engine() assert(select(2,coroutine.running()),'an engine call from a coroutine') end
local next_address=0x20000
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
local function is(...) -- IsA for these class paths.
    local set={...}
    return function(_,c)
        for _,p in ipairs(set) do if c.path==p then return true end end
        return false
    end
end
local classes={}
local function class(path)
    classes[path]=classes[path] or object({path=path,MakeTransform=function() return 'identity' end})
    return classes[path]
end
local player,pc -- EVE (nil: none) and her player controller, set below.
package.loaded.UEHelpers={GetPlayer=function() return player end,GetPlayerController=function() return pc end}
local L=require('cut.lion')

-- Lion.ROWS against native/src/lion/rows.h: its kPatches entries (a field's name is the comment after the entry, or
-- the comment line just before it; a comment line naming an M_LionC row only heads a group) and kRecipe.
do
    local f=assert(io.open('native/src/lion/rows.h'))
    local src=f:read('a')
    f:close()
    local enum={}
    for w in assert(src:match('enum class Table : uint8_t {([^}]+)}')):gmatch('%a+') do enum[#enum+1]=w end
    local names={}
    for n in assert(src:match('constexpr TableInfo kTables%[kTableCount%] = {(.-)\n};')):gmatch('{"(%a+)", 0x') do
        names[#names+1]=n
    end
    assert(#enum==12 and #names==12,'12 tables')
    for i,n in ipairs(names) do assert(L.TABLES[i]==n,'kLionTables order: '..n) end
    local block=assert(src:match('constexpr Patch kPatches%[%] = {\n(.-)\n};'))
    local patches,pending,line,closed_at={},nil,1,nil
    local i=1
    while i<=#block do
        local ch=block:sub(i,i)
        if ch=='\n' then line=line+1; i=i+1
        elseif block:sub(i,i+1)=='//' then
            local e=block:find('\n',i) or #block+1
            local c=block:sub(i+2,e-1):match('^%s*(.-)%s*$')
            if closed_at==line then patches[#patches].field=c
            elseif not c:find('^M_LionC') then pending=c end
            i=e
        elseif ch=='{' then
            local text,bare,depth,j,s='', '',0,i,nil
            repeat
                local cj=block:sub(j,j)
                if s then
                    if cj=='\\' then text=text..block:sub(j+1,j+1); j=j+1
                    elseif cj=='"' then s=nil
                    else text=text..cj end
                elseif cj=='"' then s=true
                else
                    if cj=='{' then depth=depth+1 elseif cj=='}' then depth=depth-1 end
                    if cj=='\n' then line=line+1 end
                    bare=bare..cj
                end
                j=j+1
            until depth==0 and not s
            local w={}
            for x in bare:sub(2,-2):gmatch('[^,]+') do w[#w+1]=x:match('^%s*(.-)%s*$') end
            patches[#patches+1]={kind=w[2]:match('Kind::(%w+)'),f=tonumber((w[3]:gsub('f$',''))),text=text,
                field=pending}
            pending,closed_at,i=nil,line,j
        else i=i+1 end
    end
    local KINDS={f32='f',i32='i',name='n',string='s',names='N',strings='S'}
    local n=0
    for t,name,_,id,first,count in src:gmatch('{Table::(%a+), "([%w_]+)", "([%w_]+)", (%d+), (%d+), (%d+)}') do
        n=n+1
        local r=assert(L.ROWS[n],'Lion.ROWS lacks '..name)
        local tn
        for k,e in ipairs(enum) do if e==t then tn=names[k] end end
        assert(r.table==tn and r.name==name,
            string.format('row %d: %s %s, not %s %s',n,tostring(r.table),r.name,tn,name))
        assert((r.id or 0)==tonumber(id),name..' ID')
        assert(#r.checks==tonumber(count),name..': '..#r.checks..' checks, '..count..' patches')
        for p=tonumber(first)+1,tonumber(first)+tonumber(count) do
            local pt,found=patches[p],nil
            for _,c in ipairs(r.checks) do if c[1]==pt.field then found=c end end
            assert(found,name..' lacks '..tostring(pt.field))
            -- A byte is a bool (b, 0 or 1) or an enum's number (e).
            assert(found[2]==KINDS[pt.kind] or pt.kind=='u8' and (found[2]=='e' or found[2]=='b' and pt.f<=1),
                name..' '..pt.field..' kind')
            if pt.kind=='f32' then assert(math.abs(found[3]-pt.f)<1e-6,name..' '..pt.field)
            elseif pt.kind=='i32' or pt.kind=='u8' then assert(found[3]==pt.f,name..' '..pt.field)
            else assert(found[3]==pt.text,name..' '..pt.field..': '..found[3]..' vs '..pt.text) end
        end
    end
    assert(n==220 and #L.ROWS==220 and #patches==2976,n..' rows, '..#patches..' patches')
    assert(L.IN.added=='220/220' and L.IN.char=='2/2' and L.IN.skills=='21/21' and L.IN.stance=='2/2')
end
-- The Lion's own rows: no value names a Behemoth row or asset but its sound set (the Lion has none of its own); each
-- step's moves, a skill's first step and target filter, a command's skill, a stance's commands and a hit's results are
-- Lion rows, or the shipped generic ones named here; the link flag is Common; the phase-2 stance turns at HP under 60%
-- and its start runs M_LionC_PhaseRoar, an EffectAction_UseSkill (69) of M_LionC_RoarPhaseChange, which only that
-- stance lists and both trees never pick (AISkillFlag PhaseChange); phase 1 holds no MinimumHP_60p.
do
    local by={}
    for _,r in ipairs(L.ROWS) do
        by[r.table..'.'..r.name]=r
        r.field={}
        for _,c in ipairs(r.checks) do r.field[c[1]]=c[3] end
    end
    local function row(t,name) return assert(by[t..'.'..name],t..' '..name) end
    local function lion(t,name) return by[t..'.'..name] and name:find('^M_LionC_') end
    local SHIPPED={M_Common_Result_ParryJust_Center=true,M_Common_ParryJustFX=true,M_Common_ParryJustEffect=true,
        ['None']=true}
    local changed=0
    for _,r in ipairs(L.ROWS) do
        for _,c in ipairs(r.checks) do
            changed=changed+(c[4] and 1 or 0)
            if type(c[3])=='string' and (c[3]:lower():find('behemoth') or c[3]:find('CH_M_NA_46')) then
                assert(r.table=='CharacterTable' and c[1]=='OverrideCharacterSoundSet',r.name..' '..c[1]..' '..c[3])
            end
        end
        local f=r.field
        if r.table=='SkillActiveStepTable' then
            for m in (f.SelfMoveAliasArray or ''):gmatch('[^|]+') do
                assert(lion('CharacterMoveTable',m),r.name..' '..m)
            end
            for _,k in ipairs({'NextStepAlias','NextStepAliasWhenJustParry'}) do
                assert(not f[k] or SHIPPED[f[k]] or lion('SkillActiveStepTable',f[k]),r.name..' '..k)
            end
            for _,k in ipairs({'SkillResultAlias','SkillResultAliasWhenParry','SkillResultAliasWhenGuard',
                'SkillResultAliasWhenJustParry'}) do
                assert(not f[k] or SHIPPED[f[k]] or lion('SkillResultTable',f[k]),r.name..' '..k)
            end
            assert(not f.OverrideTargetFilterAlias or lion('TargetFilterTable',f.OverrideTargetFilterAlias),r.name)
        elseif r.table=='SkillTable' then
            assert(lion('SkillActiveStepTable',f.FirstSkillActiveAlias) and
                lion('TargetFilterTable',f.TargetFilterAlias))
        elseif r.table=='SkillCommandTable' then
            assert(f.SkillAlias==r.name and lion('SkillTable',f.SkillAlias))
        elseif r.table=='CharacterStanceTable' then
            for c in f.CommandArray:gmatch('[^|]+') do assert(lion('SkillCommandTable',c),r.name..' '..c) end
            assert(not f.StartEffect:find('MinimumHP_60p'),r.name)
        end
    end
    assert(changed==2085,'Fields that differ from the template: '..changed) -- The other 891 restate its value.
    for _,name in ipairs({'M_LionC','M_LionC_Lurker'}) do
        local c=row('CharacterTable',name).field
        assert(c.LinkSkillRandomActiveStepFlagArray=='Common' and c.StanceAliasArray=='M_LionC_Phase2' and
            c.DefaultStanceAlias=='M_LionC_Default' and c.MaxHP==160000 and
            c.DefaultDetectAIAlias=='M_DetectCommon20m360')
    end
    local p2=row('CharacterStanceTable','M_LionC_Phase2').field
    assert(p2.Priority==10 and p2.Condition_ActorStat==1 and p2.Condition_ActorStatCheck==2 and
        p2.Condition_ActorStatCheckValue==60 and p2.StartEffect:find('"M_LionC_PhaseRoar"',1,true))
    assert(p2.CommandArray:find('M_LionC_RoarPhaseChange',1,true))
    assert(not row('CharacterStanceTable','M_LionC_Default').field.CommandArray:find('M_LionC_RoarPhaseChange',1,true))
    local roar=row('EffectTable','M_LionC_PhaseRoar').field
    assert(roar.Action1==69 and roar.ActionValue1=='M_LionC_RoarPhaseChange')
    assert(row('SkillTable','M_LionC_RoarPhaseChange').field.AISkillFlag=='PhaseChange')
    -- A Hit step lasts its Show's step, strikes through the claw's group and turns into the Lion's results; the low
    -- jump leaps the Lion's own clip travel toward EVE (LocalAxis 6, InsideTargetOrSelf 3 along SelfToTarget 2) and
    -- stops 150 cm short of her, where its paws land at their peak. The run attacks find EVE off their front and keep
    -- their heading (no RotationType Target, 1).
    local hit=row('SkillActiveStepTable','M_LionC_ClawAttackLeft_Hit1').field
    assert(hit.Duration==0.2 and hit.Type==1 and hit.HitDetectionType==2 and
        hit.SkillResultAlias=='M_LionC_Result_Light' and
        hit.AttackCollisionGroupArray:find('Mon_Lion_Attack_L_Arm_Collision',1,true))
    local leap=row('CharacterMoveTable','M_LionC_JumpAttackLow_Move1').field
    assert(leap.ForwardValue==615.5 and leap.MoveType==6 and leap.PositionType==3 and leap.PositionDirectionAxis==2 and
        leap.LimitApproachDistance==150.0 and leap.RightValue==0.0)
    assert(row('TargetFilterTable','M_LionC_RunAttackLeft_Target').field.TargetCheckValue2==-80.0)
    for _,m in ipairs({'Move1','Move2','Move3'}) do
        assert((row('CharacterMoveTable','M_LionC_RunAttackLeft_'..m).field.RotationType or 0)==0,m)
    end
    assert(#L.SHOWS==20 and #L.LOADS==40 and
        L.LOADS[1]=='/Game/Art/Show/CH_M_NA_02_Lion/Skill/M_LionC_ClawAttackLeft_1.M_LionC_ClawAttackLeft_1' and
        L.LOADS[26]=='/Game/Art/Character/Monster/CH_M_NA_02/Animation/'
        ..'Mon_Lion_Attack_Roar_01.Mon_Lion_Attack_Roar_01','Each Show, then its clip')
end

-- The lion line in each of its forms (lion/rows.h's status_line).
assert(L.parse('mod=v\nfight=off\n')==nil and L.parse(nil)==nil,'No line: nil')
local s=L.parse('mod=v\nlion=off\nlast=x\n')
assert(s.state=='off' and s.asks==0 and s.spawns==nil and s.line=='lion=off')
s=L.parse('x\nlion=waiting added=12/78 asks=2 spawns=? why=busy ticks=40\r\n')
assert(s.state=='waiting' and s.added=='12/78' and s.asks==2 and s.spawns==nil and s.why=='busy' and s.ticks=='40')
s=L.parse('lion=rows added=78/78 asks=3 spawns=7 char=2/2 skills=15/15 stance=1/1')
assert(s.state=='rows' and s.asks==3 and s.spawns==7 and s.char=='2/2' and s.skills=='15/15' and s.stance=='1/1')
s=L.parse('lion=refused added=0/78 asks=1 spawns=-1 why=size table=SkillTable row=M_LionC_Roar detail=0x300\n')
assert(s.why=='size' and s.table=='SkillTable' and s.row=='M_LionC_Roar' and s.detail=='0x300' and s.spawns==-1)
s=L.parse('lion=fault added=5/78 asks=1 spawns=? where=SB.exe+0x1234 (a read)\nlast=y')
assert(s.state=='fault' and s.where=='SB.exe+0x1234 (a read)')
assert(L.parse('peer=1 name=lion=rows added=78/78\n')==nil,'From the start of its own line only')

-- The world: EVE at the origin facing +X, her player controller, the 8 tables with our rows, the Lion's mesh and clip.
local DIR='/Game/Art/Character/Monster/CH_M_NA_02/'
local MESH,CLIP=DIR..'CH_M_NA_02_Large.CH_M_NA_02_Large',
    DIR..'Animation/Mon_LionC_Scene01_Appearance.Mon_LionC_Scene01_Appearance'
local LION_CLASS='CH_M_NA_02_BluePrint_Large_C'
local world=object({GetFullName=function() return 'World /Game/Maps/E04.E04' end})
local chars,finds={},0 -- Every SBCharacter, EVE first; FindAllOf calls.
local eve=object({at={X=0,Y=0,Z=100},IsA=is('/Script/SB.SBCharacter'),class='EVE_C'})
eve.K2_GetActorLocation=function(self) return {X=self.at.X,Y=self.at.Y,Z=self.at.Z} end
eve.K2_GetActorRotation=function() return {Pitch=0,Yaw=0,Roll=0} end
eve.Mesh=object({K2_GetComponentLocation=function() return {X=eve.at.X,Y=eve.at.Y,Z=eve.at.Z-90} end})
eve.GetWorld=function() return world end
eve.GetFullName=function() return 'EVE_C /Game/Maps/E04.E04:PersistentLevel.EVE' end
chars[1]=eve
player=eve
local calls={} -- ServerRequest_CreateActor's arguments, each call.
local on_create -- f(id, at): what the call makes appear.
pc=object({IsA=is('/Script/SB.SBNetworkPlayerController','/Script/Engine.PlayerController')})
function pc:ServerRequest_CreateActor(...)
    engine()
    local a={...}
    assert(#a==10 and L.IDS[a[1]] and a[4]==false and a[5]==true and a[6]==0 and a[7]==0 and a[8]==0
        and a[9]:ToString()=='None' and a[10]==false,'The one spawn call: a Lion ID, cheat on, key 0')
    calls[#calls+1]=a
    if on_create then on_create(a[1],a[2]) end
end
local made=0
-- The Lion AnimBP's class, as the mesh names it and as StaticFindObject finds it once loaded.
local skeleton=object({GetFName=function() return fname('CH_M_NA_46_Skeleton') end})
local anim_bp=object({GetFName=function() return fname('CH_M_NA_02_AnimBP_C') end,TargetSkeleton=skeleton})
local behemoth_bp=object({GetFName=function() return fname('CH_M_NA_46_AnimBP_C') end,TargetSkeleton=skeleton})
local drive_bs=object({GetFName=function() return fname('IdleRun_BS_') end})
local function body(cls,at)
    made=made+1
    local b=object({class=cls,at={X=at.X,Y=at.Y,Z=at.Z},InteractionState=0,BroadcastSpawnInfo={EventSpawnId=0}})
    local n=made
    b.K2_GetActorLocation=function(self) return {X=self.at.X,Y=self.at.Y,Z=self.at.Z} end
    b.GetFullName=function() return cls..' /Game/Maps/E04.E04:PersistentLevel.'..cls..'_'..n end
    b.IsBattle=function(self) engine(); return self.battle==true end
    b.speed,b.skill,b.alpha=0,false,{0,0}
    b.GetSBSpeedForAnimGraph=function(self) engine(); return self.speed end
    b.IsRunningSkill=function(self) engine(); return self.skill end
    b.GetCurrentCustomAnimAlpha=function(self,i) engine(); return assert(self.alpha[i+1]) end
    -- Its mesh: the engine switches the mesh line reads (and unfreeze sets), and BONE's socket, b.hand in the body's
    -- frame (yaw b.yaw).
    b.yaw,b.hand,b.CustomTimeDilation,b.bInitAnimSetSyncData=0,{X=120,Y=40,Z=-80},1,true
    b.K2_GetActorRotation=function(self) return {Pitch=0,Yaw=self.yaw,Roll=0} end
    local m=object({bPauseAnims=false,GlobalAnimRateScale=1,bNoSkeletonUpdate=false,VisibilityBasedAnimTickOption=0,
        bEnableUpdateRateOptimizations=true,ticking=true,AnimClass=anim_bp,inits=0,mode=0,
        SkeletalMesh=object({GetFName=function() return fname('CH_M_NA_02_Large') end,Skeleton=skeleton})})
    m.GetAnimInstance=function(self) -- The single-node instance in mode 1, else the AnimBP's; its blend space input.
        if self.no_instance then return nil end
        local kind=self.mode==1 and 'AnimSingleNodeInstance' or 'CH_M_NA_02_AnimBP_C'
        return object({GetFullName=function() return kind..' /Game/Maps/E04.E04:AnimInstance_'..n end,
            SetBlendSpaceInput=function(_,v) engine(); m.input=v.X end})
    end
    m.SetSkeletalMesh=function(self,mesh,reinit) -- A mesh marked works takes an AnimBP (the base Lion mesh's case).
        engine()
        assert(reinit==true)
        self.SkeletalMesh=mesh
        if mesh.works then self.refuse_all=false
        elseif self.mode==0 then self.refuse_all,self.no_instance=true,true end -- A Lion mesh drops the AnimBP's.
    end
    m.PlayAnimation=function(self,asset,loop)
        engine()
        assert(asset==drive_bs and loop==true,'The stand-in loops the battle idle-run blend space')
        self.mode,self.no_instance=1,false
    end
    m.GetAnimationMode=function(self) engine(); return self.mode end
    -- The single-node mode builds its instance; the AnimBP mode one of AnimClass, unless it is the class in refuse or
    -- refuse_all is set (the in-game Lion's case: no AnimBP at all).
    m.SetAnimationMode=function(self,mode)
        engine()
        self.mode=mode
        if mode==1 then self.no_instance=false
        elseif self.AnimClass and not self.refuse_all and self.AnimClass~=self.refuse then
            self.no_instance,self.inits=false,self.inits+1
        else self.no_instance=true end
    end
    m.IsComponentTickEnabled=function(self) engine(); return self.ticking end
    m.SetComponentTickEnabled=function(self,on) engine(); self.ticking=on end
    m.SetAnimInstanceClass=function() error('Tried calling a member function but the UObject instance is nullptr') end
    m.GetSocketLocation=function(_,bone)
        engine()
        if socket_cost then clock,socket_cost=clock+socket_cost,nil end
        assert(bone:ToString()=='Bip001-L-Hand',bone:ToString())
        local y=math.rad(b.yaw)
        return {X=b.at.X+b.hand.X*math.cos(y)-b.hand.Y*math.sin(y),Y=b.at.Y+b.hand.X*math.sin(y)+b.hand.Y*math.cos(y),
            Z=b.at.Z+b.hand.Z}
    end
    b.Mesh=m
    b.SpawnDefaultController=function(self)
        engine()
        self.Controller=object({GetFullName=function() return 'SBAIController /Game/Maps/E04.E04:Ctl_'..n end})
    end
    chars[#chars+1]=b
    return b
end
local widgets,text_finds={},0 -- The TextBlocks FindAllOf('TextBlock') gives, and how many times it was asked.
FindAllOf=function(cls)
    engine()
    if cls=='TextBlock' then
        text_finds=text_finds+1
        return widgets
    end
    finds=finds+1
    local out={}
    for _,c in ipairs(chars) do if not c.destroyed and (cls=='SBCharacter' or c.class==cls) then out[#out+1]=c end end
    return out
end
-- The tables: our rows as a game with every row in reads them back (FName fields as FNames, lists as Lua lists, bools
-- as Lua booleans, enums as their numbers).
local tables,present={},{}
local function fresh_rows(t)
    local rows={}
    for _,r in ipairs(L.ROWS) do
        if r.table==t then
            local row={ID=r.id}
            for _,c in ipairs(r.checks) do
                local v=c[3]
                if c[2]=='n' then v=fname(v)
                elseif c[2]=='b' then v=v==1
                elseif c[2]=='N' or c[2]=='S' then
                    local list={}
                    for x in (v..'|'):gmatch('([^|]*)|') do list[#list+1]=c[2]=='N' and fname(x) or x end
                    v=list
                end
                row[c[1]]=v
            end
            rows[r.name]=row
        end
    end
    return rows
end
for _,t in ipairs(L.TABLES) do
    tables[t]=object({rows=fresh_rows(t),IsA=is('/Script/Engine.DataTable'),
        FindRow=function(self,name) engine(); return self.rows[name] end,
        AddRow=function() error('never AddRow on an SB table') end,
        RemoveRow=function() error('never RemoveRow on an SB table') end})
    present[t]=true
end
local mesh_asset=object({IsA=is('/Script/Engine.SkeletalMesh'),key='mesh',
    GetFullName=function() return 'SkeletalMesh '..MESH end})
local clip_asset=object({IsA=is('/Script/Engine.AnimSequence','/Script/Engine.AnimationAsset'),SequenceLength=13.0,
    key='clip',GetFullName=function() return 'AnimSequence '..CLIP end})
local assets={[MESH]=mesh_asset,[CLIP]=clip_asset}
local load_finds=0 -- StaticFindObject calls on the loaded line's paths.
local loads={}
for _,p in ipairs(L.LOADS) do loads[p]=true end
-- The world delta the frame part of the follow line reads each frame (nil: not read).
local frame_dt
local gameplay=object({GetWorldDeltaSeconds=function(_,ctx) engine(); assert(ctx); return frame_dt end})
StaticFindObject=function(path)
    engine()
    if loads[path] then load_finds=load_finds+1 end
    if path=='/Script/Engine.Default__GameplayStatics' then return gameplay end
    if path:find('^/Script/') then return class(path) end
    local t=path:match('^/Game/Local/Data/(%a+)%.%a+$')
    if t then return present[t] and tables[t] or invalid end
    return assets[path] or invalid
end
LoadAsset=function() return invalid end
-- The display copy: plain actors spawned, their components' calls as words; root: where its bone 0 ends.
local actors,root={},nil
function world:SpawnActor(cls,at,rot)
    engine()
    assert(cls.path=='/Script/Engine.Actor','A display copy is a plain actor')
    local a=object({at=at,rot=rot,components={}})
    function a:SetActorEnableCollision(on) assert(on==false) end
    function a:AddComponentByClass(c)
        local m=object({calls={},kind=c.path})
        local function said(...) m.calls[#m.calls+1]=table.concat({...},' ') end
        function m:SetSkeletalMesh(x) said('mesh',x.key) end
        function m:SetRelativeScale3D(v) said('scale',v.X) end
        function m:SetCollisionEnabled(n) said('collision',n) end
        -- The single-node mode builds its instance, the AnimBP mode one of AnimClass when it holds one.
        function m:SetAnimationMode(n) said('mode',n); self.instance=n==1 or self.AnimClass~=nil end
        function m:GetAnimInstance() return self.instance and object({}) or nil end
        function m:K2_SetWorldLocationAndRotation(p,r) self.at,self.rot=p,r end
        function m:PlayAnimation(x,loop) said('play',x.key,tostring(loop)) end
        function m:SetPlayRate(r) said('rate',r) end
        function m:SetPosition(p,notify) assert(notify==false); said('at',p) end
        function m:GetBoneName(i) assert(i==0); return fname('Root') end
        function m:GetSocketLocation(n) assert(n:ToString()=='Root'); return assert(root,'no root') end
        function m:K2_DestroyComponent() self.destroyed=true end
        self.components[#self.components+1]=m
        return m
    end
    function a:K2_DestroyActor() self.destroyed=true end
    function a:K2_GetRootComponent() return self.components[1] end
    a.GetFullName=function() return 'Actor /Game/Maps/E04.E04:PersistentLevel.Actor_'..#actors end
    actors[#actors+1]=a
    return a
end

local lines,asked,status_text={},{},'mod=v\nlion=off\n'
local refuse_ask=nil
local function last() return lines[#lines] end
local function logged(pattern) for _,l in ipairs(lines) do if l:find(pattern) then return l end end end
local function lion_status(t) status_text='mod=v\nslot=coop\nlion='..t..'\nlast=x\n' end
local function new()
    return L.new({log=function(m) lines[#lines+1]=m end,
        ask=function(line) if refuse_ask then return false,refuse_ask end asked[#asked+1]=line; return true end,
        status=function() return status_text end})
end
local function at(t) clock=t end
local REQUEST='lion rows CharacterTable=0x%x CharacterAppearanceTable=0x%x CharacterDeadTable=0x%x '
    ..'CharacterStanceTable=0x%x CharacterAnimSetTable=0x%x SkillCommandTable=0x%x SkillTable=0x%x '
    ..'SkillActiveStepTable=0x%x CharacterMoveTable=0x%x TargetFilterTable=0x%x SkillResultTable=0x%x '
    ..'EffectTable=0x%x'
local addresses={}
for k,t in ipairs(L.TABLES) do addresses[k]=tables[t]:GetAddress() end
REQUEST=REQUEST:format(table.unpack(addresses))
local ROWS_IN='rows added=220/220 asks=%d spawns=%s char=2/2 skills=21/21 stance=2/2'
local SPOT={X=1000,Y=0,Z=200}
-- The call's body: the Lion with no controller, the Antlion with the game's own.
local function spawns_lion(id,p)
    local b=body(id==50110 and 'CH_M_NA_15_Antlion_C' or LION_CLASS,p)
    if id==50110 then b:SpawnDefaultController() end
end

local lion=new()
-- Usage and nothing reached without EVE, a table or a lion line.
for _,w in ipairs({{'x'},{'rows','x'},{'brain'},{'brain','cat'},{'intro','now'},{'unfreeze','all'},{nil,nil,'x'}}) do
    local ok,why=lion.command(w[1],w[2],w[3])
    assert(ok==false and why=='Use: coop lion [intro] | rows | control | brain skulling|lurker | unfreeze [init]',
        tostring(why))
end
assert(select(2,lion.command('unfreeze'))=='No living Lion followed: coop lion spawns one.','unfreeze with no Lion')
player=nil
local ok,why=lion.command()
assert(ok==false and why:find('^no EVE in the world') and #asked==0 and #calls==0,why)
player=eve
present.SkillTable=false
ok,why=lion.command('rows')
assert(ok==false and why=='The game has no SkillTable loaded: nothing was asked.' and #asked==0,why)
assert(last()=='tables: 11/12 found, missing SkillTable: nothing asked',last())
present.SkillTable=true
status_text='mod=v\n'
ok,why=lion.command()
assert(ok==false and why:find('^coop%-status%.txt has no lion line') and #asked==0,why)
assert(last():find('^tables: 12/12 found: CharacterTable=0x'),last())
refuse_ask='the Steam link needs the native part'
lion_status('off')
ok,why=lion.command('rows')
assert(ok==false and why=='Lion rows not asked: the Steam link needs the native part' and #asked==0,why)
refuse_ask=nil

-- coop lion rows: one ask with the 12 addresses in kLionTables' order, then the wait.
at(100)
ok,why=lion.command('rows')
assert(ok and asked[1]==REQUEST and #asked==1,asked[1])
assert(last()=='rows asked of the native part (lion=off): its answer is the next asks= past 0',last())
assert(logged('^tables: 12/12 found: '..REQUEST:sub(11):gsub('%-','%%-')..'$'),'R1 with every address')
ok,why=lion.command()
assert(ok==false and why=='coop lion is busy (the wait for the Lion rows): try again in a few seconds',why)
ok,why=lion.command('brain','lurker')
assert(ok and why=='coop lion spawns 50021 (M_LionC_Lurker, the Lesser Lurker tree) until the mod reloads.',why)
ok,why=lion.command('brain','skulling'); assert(ok and why:find('^coop lion spawns 50020 %(M_LionC, the Skulling'))
lion_status('waiting added=10/220 asks=0 spawns=? why=busy ticks=3')
at(100.1); assert(lion.tick()==nil and not logged('^rows wait'),'Not due before 0.25 s')
at(100.25); assert(lion.tick()==nil and last()=='rows wait for the game thread: lion=waiting added=10/220 asks=0 '
    ..'spawns=? why=busy ticks=3',last())
local n=#lines
at(100.5); lion.tick(); assert(#lines==n,'Said once')
lion_status(ROWS_IN:format(1,'6'))
at(100.75)
ok,why=lion.tick()
assert(ok and why=='Lion rows in: 220/220 added, SB finds them by ID (char 2/2, skills 21/21, stance 2/2) and they '
    ..'read back as written; coop lion spawns one.',tostring(why))
assert(lines[#lines-1]=='rows answer: lion='..ROWS_IN:format(1,'6') and last()=='rows read back through FindRow: '
    ..'220/220 authored rows, 2976 fields as written (2085 differ from the template row)',last())
assert(#calls==0 and #asked==1,'Rows only: no spawn')

-- coop lion with the rows in: no ask, the read-back, the spawn call, then the body after 0.3 s.
on_create=spawns_lion
at(200)
ok,why=lion.command()
assert(ok and why=='M_LionC 50020 asked: [LI] lines follow.' and #asked==1,why)
assert(logged("^rows already in %(220/220; SB's lookups by ID: char 2/2, skills 21/21, stance 2/2%): not added again$"))
local c=calls[1]
assert(c[1]==50020 and c[2].X==1000 and c[2].Y==0 and c[2].Z==200 and c[3].Yaw==180 and c[3].Pitch==0,
    'Ahead 10 m, 1 m up, facing EVE')
assert(last()=='spawn 50020 (M_LionC) at 1000,0,200, 10.0 m from EVE, yaw 180.0; spawn count 6',last())
lion_status(ROWS_IN:format(1,'7'))
at(200.29); assert(lion.tick()==nil)
local lion1=chars[#chars]
-- Spawned as in the 2026-10-24 test: no anim instance, no anim class, the single-node mode; the AnimBP class is found
-- only once its package is loaded.
lion1.Mesh.no_instance,lion1.Mesh.AnimClass,lion1.Mesh.mode=true,nil,2
local ANIM_CLASS=DIR..'BluePrints/CH_M_NA_02_AnimBP.CH_M_NA_02_AnimBP_C'
local load_asset=LoadAsset
LoadAsset=function(p)
    if p==DIR..'BluePrints/CH_M_NA_02_AnimBP.CH_M_NA_02_AnimBP' then assets[ANIM_CLASS]=anim_bp end
    return invalid
end
at(200.3); assert(lion.tick()==nil and lion1.Controller==nil,'Seen with no controller: the game may still give one')
at(201.49); assert(lion.tick()==nil)
at(201.5)
ok,why=lion.tick()
assert(ok and why=='M_LionC 50020 is here, 10.0 m from EVE: lion 1 in the [LI] lines.',tostring(why))
assert(lion1.Controller,'Its default controller: it had none 1.5 s after the call')
assert(lines[#lines-1]=='spawn 50020: CreateActor returned; body '..LION_CLASS..' 10.0 m from EVE, 0.0 m from the '
    ..'spot, after 0.3 s; controller SBAIController (SpawnDefaultController gave it); EventSpawnId 0',lines[#lines-1])
assert(last():find('^entrance: skipped %(off by default: the Lion AnimBP has no montage slot'),last())
-- Followed: a line a second while it lives, the first a second after it was found.
at(202.49); n=#lines; lion.tick(); assert(#lines==n,'Not yet')
at(202.5)
assert(lion.tick()==nil and last()=='lion 1 (50020): 10.0 m, xyz 1000,0,200, speed 0, skill no, anim alpha 0.00/0.00, '
    ..'hand moved ?, battle 0, state 0, controller yes, spawn count 7, frame ? ms, lion Lua 0.0 ms/s, longest tick '
    ..'0.0 ms (last pass: none yet)',last())
-- Its mesh line once before it (then at each change), each field as read; a field that does not read is a ?. With no
-- anim instance (the 2026-10-24 test) it gets one once: the AnimBP mode, then SetAnimInstanceClass with the Lion
-- AnimBP's class, here found once LoadAsset loaded its package (the mesh's own anim class read none).
local REST='mesh CH_M_NA_02_Large, tick true, pause false, rate 1, no skeleton update false, visibility tick 0, '
    ..'rate optimizations true, actor dilation 1, sequencer anim mode ?'
local MESH_LINE='lion 1 (50020) mesh: anim instance CH_M_NA_02_AnimBP_C, anim class CH_M_NA_02_AnimBP_C, its skeleton '
    ..'CH_M_NA_46_Skeleton, mesh skeleton CH_M_NA_46_Skeleton, mode 0, leader none, anim set sync true, '..REST
assert(lines[#lines-2]=='lion 1 (50020) mesh: anim instance none, anim class none, its skeleton ?, mesh skeleton '
    ..'CH_M_NA_46_Skeleton, mode 2, leader none, anim set sync true, '..REST,lines[#lines-2])
assert(lines[#lines-1]=='lion 1 (50020) had no anim instance: its own class built none, CH_M_NA_02_AnimBP_C built '
    ..'one; '..MESH_LINE:gsub('^lion 1 %(50020%) ',''),lines[#lines-1])
assert(lion1.Mesh.inits==1 and lion1.Mesh.mode==0,'Given once, in the AnimBP mode')
lion1.Mesh.inits,LoadAsset=0,load_asset
assert(load_finds==2,'Two loaded-line lookups a second')
lion1.battle,lion1.speed,lion1.skill,lion1.alpha=true,212.6,true,{0.5,1}
at(203); n=#lines; lion.tick(); assert(#lines==n,'One a second')
at(203.5); lion.tick()
assert(last()=='lion 1 (50020): 10.0 m, xyz 1000,0,200, speed 213, skill yes, anim alpha 0.50/1.00, hand moved 0 cm, '
    ..'battle 1, state 0, controller yes, spawn count 7, frame ? ms, lion Lua 0.0 ms/s, longest tick 0.0 ms (last '
    ..'pass: follow 0.0 ms, loaded 0.0 ms, boss name 0.0 ms)',last())
assert(lines[#lines-1]~=MESH_LINE and not lines[#lines-1]:find('mesh:',1,true),'The mesh line only when it changes')
-- The hand in the body's own frame: a turn of the whole body moves nothing, a pose that plays does.
-- A read that fails is a ?, the line still said.
lion1.yaw=90
local speed_of=lion1.GetSBSpeedForAnimGraph
lion1.GetSBSpeedForAnimGraph=function() error('no such function') end
frame_dt=0.02 -- 20 ms frames from now on: each frame read, the second's mean and worst on the next line.
at(204); lion.tick(); frame_dt=0.05; at(204.2); lion.tick(); frame_dt=0.02
at(204.5); socket_cost=0.012; lion.tick() -- Its hand read takes 12 ms: the next line's Lua part says so.
assert(last():find(', speed %?, skill yes, anim alpha 0.50/1.00, hand moved 0 cm,'),last())
assert(last():find(', frame 30%.0 ms %(worst 50%.0%), lion Lua 0%.0 ms/s, longest tick 0%.0 ms %(last pass: follow '
    ..'0%.0 ms, loaded 0%.0 ms, boss name 0%.0 ms%)$'),last())
lion1.GetSBSpeedForAnimGraph,lion1.speed=speed_of,0
lion1.hand={X=150,Y=0,Z=-80}
at(205.5); lion.tick()
assert(last():find(', hand moved 50 cm,'),last())
assert(last():find(', frame 20%.0 ms %(worst 20%.0%), lion Lua 12%.0 ms/s, longest tick 12%.0 ms %(last pass: follow '
    ..'12%.0 ms, loaded 0%.0 ms, boss name 0%.0 ms%)$'),last())
-- unfreeze: every switch back to its running value on each living Lion, its mesh line logged there (not again by the
-- follow); init also builds the anim instance again. Usage for another word, and none without a Lion.
lion1.Mesh.ticking,lion1.Mesh.bPauseAnims,lion1.Mesh.GlobalAnimRateScale,lion1.CustomTimeDilation=false,true,0,0
ok,why=lion.command('unfreeze')
assert(ok and why=='unfreeze on 1 Lion: see its mesh and hand moved lines ([LI] lines).',tostring(why))
assert(last()=='lion 1 (50020) unfreeze: tick, pause, rate, skeleton, visibility, optimizations, dilation; mesh: '
    ..'anim instance CH_M_NA_02_AnimBP_C, anim class CH_M_NA_02_AnimBP_C, its skeleton CH_M_NA_46_Skeleton, mesh '
    ..'skeleton CH_M_NA_46_Skeleton, mode 0, leader none, anim set sync true, mesh CH_M_NA_02_Large, tick true, '
    ..'pause false, rate 1.0, no skeleton '
    ..'update false, visibility tick 0, rate optimizations false, actor dilation 1.0, sequencer anim mode ?',last())
assert(lion1.Mesh.inits==0,'No new anim instance without init')
at(206.5); n=#lines; lion.tick(); assert(#lines==n+1 and last():find('^lion 1 %(50020%): '),'No second mesh line')
-- init with the Lion AnimBP building nothing (as in game): the Behemoth's is tried next.
lion1.Mesh.SetComponentTickEnabled=function() error('no tick') end
lion1.Mesh.no_instance,lion1.Mesh.refuse=true,anim_bp
assets['/Game/Art/Character/Monster/CH_M_NA_46/BluePrints/CH_M_NA_46_AnimBP.CH_M_NA_46_AnimBP_C']=behemoth_bp
ok,why=lion.command('unfreeze','init')
assert(ok and lion1.Mesh.inits==1 and last():find('unfreeze: tick failed %(no tick%), pause, .*dilation, init: '
    ..'its own class built none, CH_M_NA_02_AnimBP_C built none, CH_M_NA_46_AnimBP_C built one; mesh: anim instance '
    ..'CH_M_NA_02_AnimBP_C, anim class CH_M_NA_46_AnimBP_C,'),last())
lion1.Mesh.SetComponentTickEnabled=function(self,on) self.ticking=on end
-- The loaded line: two of the 40 paths a second, each until first seen; once all were looked for, 0/20 says none
-- loaded; then each change. A Show seen without its clip is named.
for t=205.5,221.5 do at(t); lion.tick() end
assert(load_finds==40 and last()=='loaded: shows 0/20, clips 0/20',last())
assets[L.LOADS[1]]=object({key='show'})
at(222.5); lion.tick()
assert(load_finds==42 and last()=='loaded: shows 1/20, clips 0/20 (Show seen, its clip not yet: ClawAttackLeft)',
    last())
assets[L.LOADS[2]]=object({key='clip'})
local said_at=nil
for t=223.5,250.5 do
    at(t); lion.tick()
    if not said_at and last()=='loaded: shows 1/20, clips 1/20' then said_at=t end
end
assert(said_at,'The clip found on the next pass')
assert(not logged('loaded: shows 2/'),'A seen path is not looked for again, nor counted twice')
assets[L.LOADS[1]],assets[L.LOADS[2]]=nil,nil
-- The boss name: the live TextBlock_BossName (under /Engine/Transient) reading <M_LionC> reads Lion; a widget class's
-- template of it and another TextBlock stay as they are. FindAllOf('TextBlock') again only once no block is held, at
-- most every 10 s: with none found, it ran at 202.5, 212.5, 222.5, 232.5 and 242.5.
local function block(name,path,shown)
    return object({name=name,shown=shown,GetFName=function(self) return fname(self.name) end,
        GetFullName=function(self) return 'TextBlock '..path..'.'..self.name end,
        GetText=function(self) engine(); return fname(self.shown) end,
        SetText=function(self,t) engine(); self.shown=t.text end})
end
FText=function(t) return {text=t} end
local live=block('TextBlock_BossName','/Engine/Transient.GameEngine_0:WB_MainHUD_Master_C_0.WidgetTree','<M_LionC>')
local template=block('TextBlock_BossName','/Game/UI/WB_BossHP.WB_BossHP_C:WidgetTree','<M_LionC>')
local other=block('TextBlock_Title','/Engine/Transient.GameEngine_0:WB_MainHUD_Master_C_0.WidgetTree','<M_LionC>')
widgets={template,other,live}
local tf=text_finds
assert(tf==5,'Every 10 s while none is held: '..tf)
at(251.5); lion.tick(); assert(text_finds==tf and live.shown=='<M_LionC>','Not before 252.5')
at(252.5); lion.tick()
assert(text_finds==tf+1 and live.shown=='Lion' and template.shown=='<M_LionC>' and other.shown=='<M_LionC>')
assert(last()=='boss name: <M_LionC> -> Lion',last())
n=#lines
at(253.5); lion.tick()
assert(text_finds==tf+1 and #lines==n+1,'Held: no new walk, nothing to set, only the follow line')
live.shown='<M_LionC>' -- The game's next boss bind writes it again.
at(254.5); lion.tick()
assert(live.shown=='Lion' and last()=='boss name: <M_LionC> -> Lion',last())
live.destroyed=true -- The HUD made again: the held block gone.
widgets={}
at(261.5); lion.tick(); assert(text_finds==tf+1,'At most every 10 s')
at(262.5); lion.tick(); assert(text_finds==tf+2,'Looked for again once none is held')
-- The loaded line's lookups stop once each path was looked for 3 times (a clip never played no longer costs a lookup
-- a second for the whole fight).
for t=263.5,343.5 do at(t); lion.tick() end
assert(load_finds<=3*#L.LOADS,'Each path looked for 3 times at most: '..load_finds)
-- Its death, then its body's despawn: D1 and D2.
lion1.InteractionState,lion1.Controller=3,nil
at(344.5); n=#lines; lion.tick(); assert(#lines==n,'Dead: no line until its body goes')
lion1.destroyed=true
lion_status(ROWS_IN:format(1,'6'))
at(366.9); lion.tick()
assert(lines[#lines-1]=='lion 1 (50020) dead after 143 s (InteractionState 3, no controller); body gone after 22.4 s',
    lines[#lines-1])
assert(last()=='lion 1 spawn count: before 6, alive 7, after death 6',last())
at(367.9); n=#lines; lion.tick(); assert(#lines==n,'No longer followed')

-- A row that reads back wrong stops before the spawn.
local hit=tables.SkillActiveStepTable.rows.M_LionC_ClawAttackLeft_Hit1
local good=hit.AttackCollisionGroupArray
hit.AttackCollisionGroupArray='[{"CollisionGroupName":"Collision_ArmLeft", "DelayTime":0}]'
at(400)
ok,why=lion.command()
assert(ok==false and #calls==1,'No spawn')
assert(why=='A Lion row reads back wrong (M_LionC_ClawAttackLeft_Hit1 AttackCollisionGroupArray reads "[{"'
    ..'CollisionGroupName":"Collision_ArmLeft", "DelayTime":0}]", not "[{"CollisionGroupName":"Mon_Lion_Attack_L_Arm_'
    ..'Collision", "DelayTime":0}]"): no spawn.',why)
local before=0 -- The rows ahead of the Hit step in the recipe: the effect, results, filters, moves and the Cast step.
while L.ROWS[before+1].name~='M_LionC_ClawAttackLeft_Hit1' do before=before+1 end
assert(last():find('^rows read back through FindRow: M_LionC_ClawAttackLeft_Hit1 .* %('..before..'/220 match before '
    ..'it%): no spawn$'),last())
hit.AttackCollisionGroupArray=good
-- An FName reads in any case (the game's first casing wins); a missing row, a float off or an ID off stops.
local app=tables.CharacterAppearanceTable.rows.M_LionC
app.CharacterAssetPath=fname('/Game/Art/Character/Monster/CH_M_NA_02/Blueprints/CH_M_NA_02_BluePrint_Large')
tables.SkillTable.rows.M_LionC_Roar.ID=5046012
ok,why=lion.command()
assert(ok==false and why:find('M_LionC_Roar ID reads "5046012", not "5002012"',1,true) and #calls==1,why)
tables.SkillTable.rows.M_LionC_Roar.ID=5002012
local step=tables.SkillActiveStepTable.rows.M_LionC_Roar_Cast1
step.Duration=1.5
ok,why=lion.command(); assert(ok==false and why:find('M_LionC_Roar_Cast1 Duration reads "1.5"',1,true),why)
step.Duration=1.3320000171661
local cast=tables.SkillActiveStepTable.rows.M_LionC_Roar_Cast1
cast.StopSelfMove=false -- A bool, read as a Lua boolean.
ok,why=lion.command(); assert(ok==false and why:find('M_LionC_Roar_Cast1 StopSelfMove reads "0", not "1"',1,true),why)
cast.StopSelfMove=true
local dead=tables.CharacterDeadTable.rows.M_LionC
tables.CharacterDeadTable.rows.M_LionC=nil
ok,why=lion.command()
assert(ok==false and why=='A Lion row reads back wrong (M_LionC is not in CharacterDeadTable): no spawn.',why)
tables.CharacterDeadTable.rows.M_LionC=dead
-- SB's lookups finding fewer rows: no spawn.
lion_status('rows added=220/220 asks=1 spawns=6 char=1/2 skills=21/21 stance=2/2')
ok,why=lion.command()
assert(ok==false and why=='The Lion rows are not all usable: lion=rows added=220/220 asks=1 spawns=6 char=1/2 '
    ..'skills=21/21 stance=2/2 (char=1/2, 2/2 expected): no spawn.' and #calls==1,why)

-- brain lurker: 50021 through the same call; no body after 5 s stops (FindAllOf at 0.3, 1, 2, 3.5 and 5 s only).
lion.command('brain','lurker')
lion_status(ROWS_IN:format(1,'6'))
on_create=nil
at(500)
ok,why=lion.command()
assert(ok and calls[2][1]==50021,'The lurker brain')
local f0=finds
for _,t in ipairs({500.3,501,502,503.5}) do at(t); assert(lion.tick()==nil) end
at(505)
ok,why=lion.tick()
assert(ok==false and why=='M_LionC_Lurker 50021: the spawn call returned but no body showed in 5 s ([LI] lines in '
    ..'UE4SS.log).',tostring(why))
assert(finds==f0+5 and last()=='spawn 50021: CreateActor returned; no body after 5 s',last())
lion.command('brain','skulling')

-- coop lion control: 50110 through the same call, no rows needed; the body the nearest new character.
lion_status('off')
on_create=spawns_lion
body('CH_M_NA_15_Antlion_C',{X=1200,Y=0,Z=200}) -- One standing there before the call: never taken for the new one.
at(600)
ok,why=lion.command('control')
assert(ok and why=='Antlion 50110 asked: [LI] lines follow.' and calls[3][1]==50110 and #asked==1,why)
at(600.3)
ok,why=lion.tick()
assert(ok and why=='M_Antlion 50110 is here, 10.0 m from EVE: lion 2 in the [LI] lines.',tostring(why))
assert(last()=='spawn 50110: CreateActor returned; body CH_M_NA_15_Antlion_C 10.0 m from EVE, 0.0 m from the spot, '
    ..'after 0.3 s; controller SBAIController; EventSpawnId 0','Its own controller, at once, no entrance line')
local antlion=chars[#chars]
-- Its first follow: the rebuild with its own class only (the test of the rebuild on a shipped Naytiba).
at(601.3); lion.tick()
assert(logged('^lion 2 %(50110%) rebuild test: its own class built one; mesh: anim instance CH_M_NA_02_AnimBP_C,'),
    'The control rebuild line')
antlion.destroyed=true -- Gone with the map while alive.
at(602.3); lion.tick()
assert(lines[#lines-1]=='lion 2 (50110) gone while alive after 2 s (a map change, or the game removed it)',
    lines[#lines-1])
assert(last()=='lion 2 spawn count: before ?, alive ?, after ?',last())

-- A fresh Lua load with the rows not in: a refusal from before the ask is no answer, nor a waiting line with asks
-- grown (an earlier ask finished, then ours was taken); then a refusal after it stops, and asking again goes on.
lion=new()
lion_status('refused added=3/220 asks=1 spawns=6 why=busy table=- row=-')
at(700)
assert(lion.command() and asked[2]==REQUEST,'Asked again after a refusal')
at(700.25); assert(lion.tick()==nil,'The old refusal is no answer')
lion_status('waiting added=3/220 asks=2 spawns=6 why=net ticks=1')
at(700.5); assert(lion.tick()==nil,'A waiting line is no answer')
lion_status('refused added=3/220 asks=3 spawns=6 why=net table=- row=- detail=1')
at(700.75)
ok,why=lion.tick()
assert(ok==false and why=='The native part refused the Lion rows (why=net, table=-, row=-): coop-link.log says why; '
    ..'asking again skips the rows already in.' and #calls==3,tostring(why))
-- A fault, the 30 s limit and a map change each stop the wait.
lion_status('off')
at(800); assert(lion.command())
lion_status('fault added=3/220 asks=1 spawns=6 where=SB.exe+0x10')
at(800.25); ok,why=lion.tick(); assert(ok==false and why=='The Lion rows stopped on a fault (SB.exe+0x10).',why)
ok,why=lion.command()
assert(ok==false and why=='The Lion rows stopped on a fault this game run (SB.exe+0x10).' and #asked==3,why)
lion_status('off')
at(900); assert(lion.command())
at(929.9); assert(lion.tick()==nil)
at(930.15); ok,why=lion.tick()
assert(ok==false and why=='No answer on the Lion rows in 30 s (lion=off): coop-link.log says why.',tostring(why))
at(1000); assert(lion.command())
local map=world.GetFullName
world.GetFullName=function() return 'World /Game/Maps/B07.B07' end
at(1000.25); ok,why=lion.tick()
assert(ok==false and why=='The map changed while the Lion rows were asked: no spawn.',tostring(why))
world.GetFullName=map

-- coop lion intro: the entrance on a display copy at the spot (on EVE's feet, facing her), then the Lion where its
-- root ended, the copy removed as soon as the body shows (before its controller), so the two never stand together.
lion_status(ROWS_IN:format(1,'6'))
root={X=1300,Y=0,Z=-500}
at(1100)
ok,why=lion.command('intro')
assert(ok and #calls==3,'No spawn before the entrance ends')
local copy=actors[#actors]
local m=copy.components[1]
assert(table.concat(m.calls,'|')=='mesh mesh|scale 1|collision 0|mode 1|scale 1.5|play clip false|rate 1|at 0',
    table.concat(m.calls,'|'))
assert(m.at.X==1000 and m.at.Y==0 and m.at.Z==10 and m.rot.Yaw==180,'On the spot, on her feet, facing her')
assert(last()=='entrance: playing Mon_LionC_Scene01_Appearance (13.0 s) on a display copy at 1000,0,10',last())
ok,why=lion.command(); assert(ok==false and why:find('busy %(the entrance%)'),why)
at(1112.9); assert(lion.tick()==nil and #calls==3)
at(1113)
assert(lion.tick()==nil and calls[4][1]==50020 and calls[4][2].X==1300 and calls[4][2].Z==200,'Where its root ended')
assert(lines[#lines-1]=='entrance: played on a display copy for 13.0 s; its root ended 3.0 m from the spot: the Lion '
    ..'spawns there',lines[#lines-1])
assert(not copy.destroyed,'The copy holds its last frame until the body shows')
at(1113.3); assert(lion.tick()==nil and copy.destroyed and not chars[#chars].Controller,'Gone once the body shows')
at(1114.5)
ok,why=lion.tick()
assert(ok and copy.destroyed and not last():find('^entrance: skipped'),last())
-- A root ending too far spawns at the spot; a copy that cannot be made skips the entrance and spawns at once.
root={X=4000,Y=0,Z=0}
at(1200); assert(lion.command('intro'))
at(1213); lion.tick()
assert(calls[5][2].X==1000 and logged('its root ended 30%.0 m from the spot, too far: the Lion spawns at the spot$'))
at(1214.5); assert(lion.tick())
-- A map change during the entrance: no spawn at the old map's spot, the copy removed.
at(1250); assert(lion.command('intro'))
copy=actors[#actors]
world.GetFullName=function() return 'World /Game/Maps/B07.B07' end
at(1263); ok,why=lion.tick()
assert(ok==false and why=='The map changed during the Lion\'s entrance: no spawn.' and #calls==5,tostring(why))
assert(copy.destroyed and logged('^entrance: the map changed during it: no spawn$'),'Said why')
world.GetFullName=map
assets[MESH],mesh_asset.destroyed=nil,true -- Collected, and not found again.
at(1300)
assert(lion.command('intro') and calls[6][1]==50020,'At once')
assert(logged('^entrance: skipped %(.*CH_M_NA_02_Large is missing on this PC%)$'),'Why, in its line')
at(1301.5); assert(lion.tick())
assets[MESH],mesh_asset.destroyed=mesh_asset,nil
-- coop off during the entrance: the copy removed, the job and the followed bodies dropped.
at(1400); assert(lion.command('intro'))
copy=actors[#actors]
lion.stop()
assert(copy.destroyed and last()=='coop off: the entrance ended; 3 Lion bodies no longer followed (they stay)',last())
at(1413); assert(lion.tick()==nil and #calls==6,'Nothing after coop off')
assert(lion.command('rows'),'A new command after coop off would run (main.lua refuses it)')

-- A body SB sent far away and moved back for the next spawn (a Lion at 466 m came back on 2026-10-23) is that spawn's,
-- and its old follow ends as recycled; a body near the spot before the call is still never taken (the Antlion above).
lion=new()
lion_status(ROWS_IN:format(1,'6'))
on_create=spawns_lion
at(1500); assert(lion.command())
at(1500.3); lion.tick()
at(1501.5); assert(lion.tick())
local first=chars[#chars]
first.at={X=46600,Y=0,Z=200} -- Sent away.
on_create=function(_,p) first.at={X=p.X,Y=p.Y,Z=p.Z} end -- Moved back for the call, no new body.
local mark=#lines
at(1510); assert(lion.command())
at(1510.3)
ok,why=lion.tick()
assert(ok and why=='M_LionC 50020 is here, 10.0 m from EVE: lion 2 in the [LI] lines.',tostring(why))
assert(logged('^lion 1 %(50020%) recycled: SB moved its body back for this spawn$'),'The old follow ended')
assert(lines[#lines-1]=='spawn 50020: CreateActor returned; body '..LION_CLASS..' 10.0 m from EVE, 0.0 m from the '
    ..'spot, after 0.3 s; controller SBAIController; EventSpawnId 0; a body SB reused (456 m from the spot at the '
    ..'call)',lines[#lines-1])
at(1511.3); lion.tick()
assert(last():find('^lion 2 %(50020%): 10%.0 m, '),last())
for i=mark+1,#lines do assert(not lines[i]:find('^lion 1 %(50020%): '),'Followed once, as lion 2') end

-- No AnimBP builds an instance (the 2026-10-24 test, the Behemoth's included): the single-node stand-in loops the
-- Lion's battle idle-run blend space, its input set each frame from the speed (600 at most), until the mesh leaves the
-- single-node mode.
lion=new()
lion_status(ROWS_IN:format(1,'6'))
on_create=spawns_lion
assets[DIR..'Animation/BlendSpace/IdleRun_BS_.IdleRun_BS_']=drive_bs
-- Here the Behemoth's mesh takes no AnimBP either: the body gets its Lion mesh back before the stand-in.
assets['/Game/Art/Character/Monster/CH_M_NA_46/CH_M_NA_46.CH_M_NA_46']=object({works=false,
    GetFName=function() return fname('CH_M_NA_46') end})
at(1600); assert(lion.command())
local lone=chars[#chars]
lone.Mesh.no_instance,lone.Mesh.refuse_all=true,true
at(1600.3); lion.tick()
at(1601.5); assert(lion.tick())
at(1602.5); lion.tick()
assert(logged('^lion 1 %(50020%) had no anim instance: its own class built none, CH_M_NA_02_AnimBP_C built none, '
    ..'CH_M_NA_46_AnimBP_C built none; leader: failed %(the Lion AnimBP builds no instance on CH_M_NA_46 either%); '
    ..'stand%-in: the single%-node instance plays IdleRun_BS_ by speed; mesh: anim instance AnimSingleNodeInstance, '
    ..'anim class CH_M_NA_02_AnimBP_C, .*, mode 1,'),'The stand-in line')
assert(lone.Mesh.SkeletalMesh:GetFName():ToString()=='CH_M_NA_02_Large','Its own mesh back')
lone.speed=900; at(1602.6); lion.tick(); assert(lone.Mesh.input==600,tostring(lone.Mesh.input))
lone.speed=212; at(1602.7); lion.tick(); assert(lone.Mesh.input==212,tostring(lone.Mesh.input))
lone.Mesh.mode=0; at(1602.8); lion.tick()
lone.speed=100; at(1602.9); lion.tick(); assert(lone.Mesh.input==212,'No input once out of single-node mode')
-- The leader: the Behemoth's mesh (its hierarchy matches the skeleton) takes the Lion's AnimBP on the body's mesh
-- component, hidden and ticking; a new component attached to it with no offset draws the Lion's mesh and copies its
-- pose. No stand-in. SB's tick option comes back to 3 and is set to 0 again the next frame.
lion=new()
lion_status(ROWS_IN:format(1,'6'))
assets['/Game/Art/Character/Monster/CH_M_NA_46/CH_M_NA_46.CH_M_NA_46']=object({works=true,
    GetFName=function() return fname('CH_M_NA_46') end})
at(1700); assert(lion.command())
local led=chars[#chars]
led.Mesh.no_instance,led.Mesh.refuse_all=true,true
local follower
led.AddComponentByClass=function(_,cls,manual,t,deferred)
    engine()
    assert(cls.path=='/Script/Engine.SkeletalMeshComponent' and manual==true and t~=nil and deferred==false)
    follower=object({calls={}})
    function follower:SetCollisionEnabled(n) self.calls[#self.calls+1]='collision '..n end
    function follower:K2_AttachToComponent(p,socket,a,b,c,weld)
        assert(p==led.Mesh and socket:ToString()=='None' and a==0 and b==0 and c==0 and weld==false)
        self.calls[#self.calls+1]='attach'
    end
    function follower:SetMasterPoseComponent(p,force)
        assert(p==led.Mesh and force==true)
        self.calls[#self.calls+1]='lead'
    end
    function follower:SetSkeletalMesh(x,reinit)
        assert(reinit==true)
        if follower_fails then error('no mesh for it') end
        self.calls[#self.calls+1]='mesh '..x:GetFName():ToString()
    end
    function follower:SetLightingChannels(a,b,c) self.calls[#self.calls+1]=('light %s %s %s'):format(a,b,c) end
    function follower:K2_DestroyComponent(owner) assert(owner==led); self.destroyed=true end
    return follower
end
led.Mesh.SetRenderInMainPass=function(self,on) engine(); self.main=on end
led.Mesh.SetCastShadow=function(self,on) engine(); self.shadow=on end
at(1700.3); lion.tick()
at(1701.5); assert(lion.tick())
at(1702.5); lion.tick()
assert(logged('^lion 1 %(50020%) had no anim instance: its own class built none, CH_M_NA_02_AnimBP_C built none, '
    ..'CH_M_NA_46_AnimBP_C built none; leader: the Lion AnimBP runs on a hidden CH_M_NA_46, the Lion mesh copies its '
    ..'pose; mesh: anim instance CH_M_NA_02_AnimBP_C, anim class CH_M_NA_02_AnimBP_C, .*, mode 0, leader none, '
    ..'anim set sync true, mesh CH_M_NA_46,'),'The leader line')
assert(table.concat(follower.calls,'|')=='collision 0|attach|lead|mesh CH_M_NA_02_Large|light true true false',
    table.concat(follower.calls,'|'))
assert(led.Mesh.main==false and led.Mesh.bRenderInDepthPass==false and led.Mesh.shadow==false
    and led.Mesh.bDisableClothSimulation==true and led.Mesh.input==nil,'Drawn in no pass, no cloth, no stand-in')
led.Mesh.VisibilityBasedAnimTickOption=3
at(1702.6); lion.tick(); assert(led.Mesh.VisibilityBasedAnimTickOption==0,'Ticking again the next frame')
-- A failure after the AnimBP built (here the Lion mesh on the new component): the component goes, the body's mesh
-- is drawn again with the Lion's mesh, and the stand-in plays.
lion=new()
lion_status(ROWS_IN:format(1,'6'))
at(1800); assert(lion.command())
led=chars[#chars]
led.Mesh.no_instance,led.Mesh.refuse_all=true,true
led.AddComponentByClass=chars[#chars-1].AddComponentByClass
led.Mesh.SetRenderInMainPass,led.Mesh.SetCastShadow=chars[#chars-1].Mesh.SetRenderInMainPass,
    chars[#chars-1].Mesh.SetCastShadow
follower_fails=true
at(1800.3); lion.tick()
at(1801.5); assert(lion.tick())
at(1802.5); lion.tick()
assert(logged('^lion 1 %(50020%) had no anim instance: .*; leader: failed %(no mesh for it%); stand%-in: the '
    ..'single%-node instance plays IdleRun_BS_ by speed;'),'The rollback line')
assert(follower.destroyed and led.Mesh.main==true and led.Mesh.shadow==true and led.Mesh.bRenderInDepthPass==true
    and led.Mesh.SkeletalMesh:GetFName():ToString()=='CH_M_NA_02_Large','The Lion drawn again, the component gone')
follower_fails=nil

-- The source names no achievement, reward, item, quest, save, possession, console command, destroy or row call of its
-- own, and its only spawn words are its one CreateActor and its one SpawnDefaultController (race/doro.lua's spawn
-- and remove make and drop the display copy); its one destroy call drops the component it added itself, when the
-- leader fails.
do
    local f=assert(io.open('mod/StellarCoop/Scripts/cut/lion.lua','rb'))
    local src=f:read('a')
    f:close()
    local allowed,seen={ServerRequest_CreateActor=true,SpawnDefaultController=true,K2_DestroyComponent=true},{}
    for call in src:gmatch('[:.]([%a_][%w_]*)%s*%(') do
        if allowed[call] then seen[call]=(seen[call] or 0)+1
        else
            for _,word in ipairs({'Achiev','Reward','Item','Quest','Save','ExecuteConsoleCommand','Possess','Spawn',
                'CreateActor','Destroy','AddRow','RemoveRow','EmptyTable'}) do
                assert(not call:find(word),'cut/lion: '..call)
            end
        end
    end
    assert(seen.ServerRequest_CreateActor==1 and seen.SpawnDefaultController==1 and seen.K2_DestroyComponent==1,
        'One spawn call, one controller, one destroy of its own component')
end
print('lion_test: ok')
