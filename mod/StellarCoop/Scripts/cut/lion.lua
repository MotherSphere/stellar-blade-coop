-- coop lion: the cut Naytiba 02, the Lion (/Game/Art/Character/Monster/CH_M_NA_02/: blueprint, mesh, clips, collision
-- data and 41 Shows, but no table row), spawned as a real enemy to fight, on the game thread (plan A of the Lion
-- study). Its 78 rows go into SB's 8 tables through the native part (lion/rows.h, glue/tick/lion_game.inc: SB's own
-- AddRow on the game thread with no logic task in flight). This file finds the tables by their fixed paths and sends
-- their addresses (the lion rows request: no console word reaches an address), waits for the answer in
-- coop-status.txt's lion line, then reads every row back through FindRow by field name, independent of the SDK's
-- offsets, and stops at the first value that differs. Then one spawn call, nightop/run.lua's ServerRequest_CreateActor
-- with cheat on and key 0 (no EventSpawn row: no zone storage, no quest event, no respawn, nothing saved), 10 m ahead
-- of EVE and 1 m up, facing her, for a fixed CharacterTable ID only: 50020 (M_LionC, the Skulling test tree), 50021
-- after coop lion brain lurker (M_LionC_Lurker, the Lesser Lurker tree), or for coop lion control 50110 (M_Antlion, a
-- shipped Naytiba, which tells a broken call from broken rows). Its body is the new character nearest the spot (of the
-- Large blueprint's class for the Lion), given its default controller when it has none, then followed: a line a second
-- while it lives, its death (InteractionState and Controller, as run.lua reads them) and its body's despawn, with the
-- spawn manager's counter (the lion line's spawns=) before, while it lives and after. Never called here: UE4SS's AddRow
-- or RemoveRow (a raw RowMap insert or free that SB's ID maps miss), a despawn, a save, quest or inventory call. The
-- Lion goes when it dies or with the map; the rows stay for the game run, and a later coop lion only reads them back.
-- coop off ends what this file does (a wait, a search, the lines) and leaves a living Lion to the game.
-- The entrance: the Lion's AnimBP (CH_M_NA_02_AnimBP) has no montage slot, so a montage would not show, and a
-- single-node clip on its mesh would replace the anim instance SB plays its skills on while its AI runs. So coop lion
-- spawns at once, and coop lion intro first plays Mon_LionC_Scene01_Appearance (the cut boss intro's clip) on a display
-- copy (race/doro.lua's plain actor with the Large mesh, as cut/leviathan.lua shows its meshes), then spawns the Lion
-- where the copy's root ended and removes the copy once the body is found.
local U=require('core.unreal')
local N=require('nightop.probe')
local Doro=require('race.doro')
local valid,value_of,text=U.valid,U.value_of,U.text
local Lion={}
-- The 8 tables, in the native part's order (link/protocol.h's kLionTables), each at /Game/Local/Data/<T>.<T>.
Lion.TABLES={'CharacterTable','CharacterAppearanceTable','CharacterDeadTable','CharacterStanceTable',
    'CharacterAnimSetTable','SkillCommandTable','SkillTable','SkillActiveStepTable'}
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
local MASK=0xFFFFFFFF
local USE='Use: coop lion [intro] | rows | control | brain skulling|lurker'
local GROUP='[{"CollisionGroupName":"Mon_Lion_Attack_%s_Collision", "DelayTime":0}]'
local DEAD='CH_M_NA_02_Lion/Basic/M_Lion_Dead'

-- The rows as the native part writes them (lion/rows.h's generated recipe; tests/lua/cut/lion_test.lua checks this
-- list against it): {table=, name=, id=<nil in the dead table>, checks={{field, kind, value}}}. kind: f a float, n an
-- FName (compared in any case: its text is whichever casing the game registered first), N a list of FNames, s an
-- FString, S a list of FStrings (lists joined by |).
Lion.ROWS={}
local function row(t,name,id,checks) Lion.ROWS[#Lion.ROWS+1]={table=t,name=name,id=id,checks=checks} end
-- The v1 kit in its rows' order: the skill, its steps' durations (s), its Hit step's collision group (none: no Hit
-- collision) and, for a Cast step shorter than its donor's, its action assist check (s, as far before its end as the
-- donor's). IDs 5002000 on; a step's ID is its skill's times 100 plus 2, 3, 4.
local KIT={{'ClawAttackLeft',{0.8,0.2,2.067},'L_Arm'},{'ClawAttackRight',{0.8,0.2,2.067},'R_Arm'},
    {'ClawAttackChaseLeft',{0.7,0.3,2.067},'L_Arm'},{'ClawAttackChaseRight',{0.7,0.3,2.067},'R_Arm'},
    {'TurnAttackLeft',{0.58,0.32,1.6},'L_Arm'},{'TurnAttackRight',{0.58,0.32,1.6},'R_Arm'},
    {'RunAttackLeft',{0.83,0.42,1.68},'R_Arm'},{'RunAttackRight',{0.83,0.42,1.68},'L_Arm'},
    {'JumpAttackLow',{1.13,0.1,0.97},'RL_Arm'},{'JumpAttackHigh',{1.96,0.64,2.4},'RL_Arm'},
    {'BackJumpToAttack',{1.2,0.1,0.9},'RL_Arm'},{'AttackToBackJump',{1.15,0.2,2.25},'RL_Arm'},
    {'Roar',{1.332,1.268,1.533},nil,1.266},{'SideStepLeft',{2.0}},{'SideStepRight',{2.0}}}
local STEPS={'_Cast1','_Hit1','_Finish1'}
local commands={}
for i,k in ipairs(KIT) do
    local skill,id,d='M_LionC_'..k[1],5002000+i-1,k[2]
    commands[i]=skill
    for s=1,#d do
        local c={{'Duration','f',d[s]}}
        if s<#d then c[#c+1]={'NextStepAlias','n',skill..STEPS[s+1]} end
        if s==1 then c[#c+1]={'ShowPath','n','CH_M_NA_02_Lion/Skill/'..skill..'_1'} end
        if s==1 and k[4] then c[#c+1]={'ActionAssistCheckDelay','f',k[4]} end
        if s==2 and k[3] then c[#c+1]={'AttackCollisionGroupArray','s',GROUP:format(k[3])} end
        row('SkillActiveStepTable',skill..STEPS[s],id*100+s+1,c)
    end
    row('SkillTable',skill,id,{{'FirstSkillActiveAlias','n',skill..'_Cast1'}})
end
for i,skill in ipairs(commands) do row('SkillCommandTable',skill,5002000+i-1,{{'SkillAlias','n',skill}}) end
for k,set in ipairs({'Peaceful','Battle'}) do
    local c={}
    if set=='Battle' then
        c={{'RunBlendSpace','s','Animation/BlendSpace/IdleRun_BS_'},
            {'RunTiltBlendSpace','s','Animation/BlendSpace/IdleRun_BS_'}}
    end
    local function to(clip,fields) for f in fields:gmatch('%S+') do c[#c+1]={f,'s',clip} end end
    to('Animation/Mon_Lion_B_Run_Start','RunStart RunStartAfterEvade')
    to('Animation/Mon_Lion_B_Run_End','RunToIdle RunToIdle_L RunToIdle_R ShortMoveToIdle ShortMoveToIdle_L '
        ..'ShortMoveToIdle_R')
    to('Animation/Mon_B_Lion_Run_L_Turn','RunTurn_L WalkTurn_L')
    to('Animation/Mon_B_Lion_Run_R_Turn','RunTurn_R WalkTurn_R')
    to('','Custom_Anim3') -- The Behemoth's shield-break clip: none for the Lion.
    -- The second just parry's (a perfect parry on the Hits of ScratchLeft and TurnAttackLeft): the Lion's one clip.
    to('Animation/Result_Hit_JustParry','Custom_Anim4')
    row('CharacterAnimSetTable','M_LionC_'..set,500199+k,c)
end
row('CharacterStanceTable','M_LionC_Default',500200,{{'CommandArray','N',table.concat(commands,'|')},
    {'StartEffect','s','[{"Alias":"M_Common_HitProjectileCheckCount"}]'},
    {'AnimSet_Peaceful_UpperBody','n','M_LionC_Peaceful'},{'AnimSet_Peaceful_LowerBody','n','M_LionC_Peaceful'},
    {'AnimSet_Battle_UpperBody','n','M_LionC_Battle'},{'AnimSet_Battle_LowerBody','n','M_LionC_Battle'}})
do
    local c={{'DefaultDeadShowArray','S',DEAD}}
    for f in ('Step0 Step1 Step2 Step3 Explosion1 Explosion2 Custom1 Custom4 Custom6 Custom8'):gmatch('%S+') do
        c[#c+1]={f..'DeadShow','s',DEAD}
    end
    row('CharacterDeadTable','M_LionC',nil,c)
end
row('CharacterAppearanceTable','M_LionC',50020,
    {{'CharacterAssetPath','n','/Game/Art/Character/Monster/CH_M_NA_02/BluePrints/CH_M_NA_02_BluePrint_Large'}})
for _,c in ipairs({{'M_LionC_Lurker',50021,'M_LesserLurker_AI'},{'M_LionC',50020,'M_Skulling_AI_Test'}}) do
    row('CharacterTable',c[1],c[2],{{'Type','s','M_LionC'},{'Flag','n','Lion'},{'DefaultEffectArray','N','Rank_Elite'},
        {'DeadAlias','n','M_LionC'},{'DespawnShow','s','Despawn/M_LionA_Despawn'},
        {'DefaultStanceAlias','n','M_LionC_Default'},
        {'BehaviorTreeRes','s','/Game/GameDesign/Combat/BehaviorTree/Monster/'..c[3]},{'RefAppearance','n','M_LionC'},
        {'Name','s',''},{'MeshScale','f',1.0},{'OverrideCharacterSoundSet','s',
            "SBCharacterSoundSet'/Game/Sound/SoundAsset/CharacterSoundset/CSS_MON_46_BEHEMOTH.CSS_MON_46_BEHEMOTH'"}})
end
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
-- A field of a row as compared: a number, or text (an FName lower-cased), a list joined by |. Raises when unread.
local function get(r,field,kind)
    local x=value_of(r[field])
    if kind=='f' or kind=='i' then return assert(tonumber(x),'not a number') end
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
-- order. Returns the count that match and, at the first that does not, what it reads.
local function read_back(tables)
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
    end
    return #Lion.ROWS
end

-- o: log (the [LI] lines), ask(line) the native request (ok, message), status() the native status text.
function Lion.new(o)
    local log,ask,status=o.log,o.ask,o.status
    local self={}
    local brain=BRAINS.skulling
    local job=nil -- The command under way: {what=<for a busy refusal>, step=f(job, now), at=<os.clock when due>, ...}.
    local followed={} -- The bodies spawned this Lua load and not let go: {n=, id=, obj=, path=, since=, before=, ...}.
    local spawned,next_follow=0,0
    local function lion_line() return Lion.parse(status and status()) end
    local her=N.her
    -- The 8 tables by name, and those missing.
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
        log(string.format('%s: %s m, battle %s, state %s, controller %s, spawn count %s',name,
            eve and string.format('%.1f',metres(location(c),location(eve))) or '?',read and (battle and 1 or 0) or '?',
            tostring(c.InteractionState),valid(c.Controller) and 'yes' or 'no',counted(spawn_count())))
    end
    -- A spawn's search (job.id, job.spot, job.before, job.class, job.display): at each of FINDS, the new body nearest
    -- the spot. Found with no controller before ADOPT: looked at again then. Found: its default controller when it has
    -- none, S1 (with when it was first seen), the entrance line, followed from then on.
    local function search(j,now)
        local best,best_m=nil,nil
        for a,c in pairs(bodies(j.class)) do
            if not j.taken[a] then
                local ok,d=pcall(function() return metres(location(c),j.spot) end)
                if ok and d<=NEAR and (not best_m or d<best_m) then best,best_m=c,d end
            end
        end
        local after=now-j.called
        j.seen=best and (j.seen or after)
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
        log(string.format('spawn %d: CreateActor returned; body %s %s m from EVE, %.1f m from the spot, after %.1f s; '
            ..'controller %s%s; EventSpawnId %s',j.id,class_of(best),from and string.format('%.1f',from) or '?',best_m,
            j.seen,ctl and class_of(ctl) or 'none',adopted,read and tostring(key) or '?'))
        if j.display then
            pcall(Doro.remove,j.display)
        elseif j.id~=CONTROL then
            log('entrance: skipped (off by default: the Lion AnimBP has no montage slot, and a clip on its mesh would '
                ..'replace the anim instance SB plays its skills on; coop lion intro plays it on a display copy before '
                ..'the spawn)')
        end
        spawned=spawned+1
        followed[#followed+1]={n=spawned,id=j.id,obj=best,path=path_of(best),since=now,before=j.before,
            alive=spawn_count()}
        if not followed[2] then next_follow=now+FOLLOW end -- Its first line a second from now.
        return true,string.format('%s %d is here, %s m from EVE: lion %d in the [LI] lines.',Lion.IDS[j.id],j.id,
            from and string.format('%.1f',from) or '?',spawned)
    end
    -- The spawn call at at, facing EVE, then the search; raises with nothing called when there is no EVE or controller.
    local function spawn(j,at,now)
        local eve=assert(her(),'no EVE in the world')
        j.spot,j.class=at,j.id==CONTROL and 'SBCharacter' or CLASS
        j.taken=bodies(j.class)
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
    -- the spot when that is unread or more than ROOT_FAR away; the copy stays on its last frame until the search ends.
    local function intro_done(j,now)
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
        local n,wrong=read_back(j.tables)
        if wrong then
            log(string.format('rows read back through FindRow: %s (%d/%d match before it): no spawn',wrong,n,
                #Lion.ROWS))
            return false,'A Lion row reads back wrong ('..wrong..'): no spawn.'
        end
        log(string.format('rows read back through FindRow: %d/%d match',n,#Lion.ROWS))
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
    -- brain sets the ID of the next spawns, even while a command runs; the others wait for it.
    function self.command(sub,a,extra)
        if extra~=nil then return false,USE end
        if sub=='brain' and BRAINS[a] then
            brain=BRAINS[a]
            log('brain: '..a..', CharacterTable '..brain..' ('..Lion.IDS[brain]..')')
            return true,string.format('coop lion spawns %d (%s, the %s tree) until the mod reloads.',brain,
                Lion.IDS[brain],a=='lurker' and 'Lesser Lurker' or 'Skulling test')
        end
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
        if job and now>=job.at then
            local j=job
            local ran,done,said=pcall(j.step,j,now)
            if not ran then
                if j.display then pcall(Doro.remove,j.display) end
                ok,message=false,'coop lion stopped on an error: '..why(done)
            elseif done~=nil then ok,message=done,said end
            if ok~=nil and job==j then job=nil end
        end
        if followed[1] and now>=next_follow then
            next_follow=now+FOLLOW
            for _,f in ipairs({table.unpack(followed)}) do
                local fine,e=pcall(follow_one,f,now)
                if not fine then let_go(f,string.format('lion %d no longer followed: %s',f.n,why(e))) end
            end
        end
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
