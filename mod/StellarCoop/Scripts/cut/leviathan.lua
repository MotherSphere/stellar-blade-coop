-- coop leviathan: the cut Naytiba 10, the Leviathan (/Game/Art/Character/Monster/CH_M_NA_10/, found in pakchunk0's
-- index, not seen in game), shown with race/doro.lua's display parts: a plain actor with one mesh component, collision
-- off, the engine's single-node instance playing its clips. No SB character, no table row, no AI, nothing that can
-- die, so nothing of it reaches a quest, an achievement or a save; its Blueprint classes are looked up, never spawned.
-- list only reads: which assets resolve, each mesh's and clip's skeleton, each class's super class, and the
-- CharacterTable rows that name it. show puts one mesh 6 m ahead of EVE, facing her, and plays each clip of its
-- skeleton twice in turn; play holds one. off removes it, and so do coop off, a map change, its first error and the
-- next Lua load (coop-leviathan.txt, read at the first tick).
local UE=require('UEHelpers')
local U=require('core.unreal')
local Doro=require('race.doro')
local valid,value_of,text,find=U.valid,U.value_of,U.text,U.find
local Leviathan={}
local DIR='/Game/Art/Character/Monster/CH_M_NA_10/'
local OBJECT,ANIM='/Script/CoreUObject.Object','/Script/Engine.AnimationAsset'
local TABLE='/Game/Local/Data/CharacterTable.CharacterTable'
-- SBCharacterTableProperty's fields that hold names (its export: M_Hydra's Type M_Hydra, DespawnShow
-- Despawn/M_Hydra_Despawn, RefAppearance M_Hydra), read beside the row's own name.
local FIELDS={'Type','Flag','DeadAlias','DespawnShow','DefaultStanceAlias','BehaviorTreeRes','DefaultDetectAIAlias',
    'NarrowDetectAIAlias','RefAppearance'}
local AHEAD=600 -- cm in front of EVE.
local USE='Use: coop leviathan [list] | show [body|a|b|tentacle|statue] | play [<clip>] | off'
-- What list reads, in order: {kind, object path}. A class's path is its Blueprint's with _C.
Leviathan.LIST={}
local function add(kind,dir,names)
    for name in names:gmatch('%S+') do
        Leviathan.LIST[#Leviathan.LIST+1]={kind=kind,path=dir..name..'.'..name..(kind=='class' and '_C' or '')}
    end
end
add('mesh',DIR,'CH_M_NA_10 Leviathan_A Leviathan_B M_LeviathanTentacleA')
add('mesh','/Game/Art/BG/Actor/SecretRoom/','C_Reviathan') -- The secret room's statue, a StaticMesh.
add('skeleton',DIR,'CH_M_NA_10_Skeleton Leviathan_A_Skeleton Leviathan_B_Skeleton M_LeviathanTentacleA_Skeleton')
add('clip',DIR..'Animation/','M_Leviathan_BashLeft1_1 M_Leviathan_BashRight1_1 M_Leviathan_BattleIdle01 '
    ..'M_Leviathan_BattleIdle02 M_Leviathan_Catch_1 M_Leviathan_LightningBall1_1 M_Leviathan_SmashLeft1_1 '
    ..'M_Leviathan_SmashRight1_1 M_LeviathanTentacleA_BashLeft M_LeviathanTentacleA_BashLeft_1 '
    ..'M_LeviathanTentacleA_BashRight M_LeviathanTentacleA_BashRight_1 M_LeviathanTentacleA_Battleidle01 '
    ..'M_LeviathanTentacleA_Smash M_LeviathanTentacleA_Smash_1 M_LeviathanTentacleA_SwingLeft_1 '
    ..'M_LeviathanTentacleA_SwingRight_1 M_LeviathanTentacleB_Catch M_LeviathanTentacleB_CatchHit '
    ..'M_LeviathanTentacleB_Swing')
add('clip',DIR..'Animation/BlendSpace/','IdleRun_BS_Battle TentacleA_IdleRun_BS_Peaceful')
add('clip',DIR,'CH_M_NA_10_Anim')
add('clip','/Game/Art/Character/PC/CH_P_EVE_01/Animation/','Hit_Leviathan_GrabSuccess') -- EVE's own.
add('class',DIR..'Blueprints/','CH_M_NA_10_Blueprint CH_M_NA_10_AnimBP CH_M_NA_10_TentacleA_Blueprint '
    ..'CH_M_NA_10_TentacleA_AnimBP CH_M_NA_10_TentacleB_Blueprint CH_M_NA_10_TentacleB_AnimBP '
    ..'CH_M_NA_10_Tentacle_AnimBP')
add('class','/Game/GameDesign/Level/BluePrintActor/Matrix_XI/','ME_Area04_SecretRoom_Leviathan')
add('asset','/Game/Art/Show/Despawn/','M_Leviathan_Despawn')
add('asset',DIR,'Default')
-- show's meshes: LIST's first five.
Leviathan.MESHES={body=1,a=2,b=3,tentacle=4,statue=5}

local function name_of(path) return path:match('[^.]+$') end
local function her(pawn) return pawn and pawn:IsA(find('/Script/SB.SBCharacter')) and pawn or nil end
-- An entry's object (Doro.resolve: in memory, else LoadAsset); a class not found by itself is looked up again once its
-- Blueprint's package is loaded.
local function resolve(e)
    local o=Doro.resolve(e.path,OBJECT)
    if o or e.kind~='class' then return o end
    pcall(LoadAsset,e.path:sub(1,-3))
    return Doro.resolve(e.path,OBJECT)
end
-- The full name of o's skeleton (a skeletal mesh's or a clip's); nil when it has none.
local function skeleton_of(o)
    local ok,s=pcall(function() return text(valid(o.Skeleton):GetFullName()) end)
    return ok and s or nil
end
-- A clip's length in s, 3 when it has none (a blend space).
local function length_of(a)
    local ok,t=pcall(function() return tonumber(value_of(a.SequenceLength)) end)
    return ok and t and t>0 and t or 3
end
-- The clips of LIST on the skeleton of mesh (an entry of LIST), in order: {path, name, seconds}; and that skeleton.
local function clips_of(mesh)
    local skeleton,out=skeleton_of(resolve(mesh)),{}
    if not skeleton then return out end
    for _,e in ipairs(Leviathan.LIST) do
        local a=e.kind=='clip' and resolve(e)
        if a and a:IsA(find(ANIM)) and skeleton_of(a)==skeleton then
            out[#out+1]={path=e.path,name=name_of(e.path),seconds=length_of(a)}
        end
    end
    return out,skeleton
end

-- o: log (the [LV] lines), store (coop-leviathan.txt through link.store; nil without the native part: no sweep at the
-- next Lua load).
function Leviathan.new(o)
    local log=o.log
    local store=o.store or {save=function() end,load=function() end,clear=function() end}
    local self={}
    local shown -- {d=<Doro.spawn's>, name=, map=, clips=, k=<cycle step>, next=<os.clock of the next>, held=<clip>}
    local restored=false
    -- The display the file names (its actor's path and mesh, tab-separated) destroyed while it still is one: pcall's
    -- ok, and true when it was.
    local function sweep(line) return pcall(Doro.sweep,line:match('^([^\t]*)\t(.*)$')) end
    -- The display an earlier Lua load left, then the file cleared. Once, on the game thread (the first tick, or show).
    function self.restore()
        if restored then return end
        restored=true
        local line=store.load()
        if not line then return end
        local ok,gone=sweep(line)
        store.clear()
        log('restore: '..(not ok and tostring(gone) or gone and 'the display of an earlier Lua load destroyed'
            or 'nothing left'))
    end
    local function remove(why)
        local s=shown
        shown=nil
        local ok,e=pcall(Doro.remove,s.d)
        if ok then store.clear() end -- Else the next Lua load tries again.
        log('removed ('..why..')'..(ok and '' or ': '..tostring(e)))
    end
    -- One line per entry of LIST, then the CharacterTable rows whose name or name fields hold NA_10 or eviathan
    -- (Leviathan, and the statue's Reviathan), with their ID and MeshScale, and a count.
    local function list()
        local found=0
        for _,e in ipairs(Leviathan.LIST) do
            local x=resolve(e)
            local line='list '..e.kind..' '..name_of(e.path)..': '
            if not x then line=line..'missing'
            else
                found=found+1
                line=line..text(x:GetFullName()):match('^%S+')
                if e.kind=='class' then
                    local ok,super=pcall(function() return text(valid(x:GetSuperStruct()):GetFName()) end)
                    line=line..' super='..(ok and super or '-')
                elseif e.kind=='mesh' or e.kind=='clip' then
                    line=line..' skeleton='..name_of(skeleton_of(x) or '-')
                end
            end
            log(line)
        end
        local rows,named=0,0
        local function read(row,field)
            local ok,v=pcall(function() local x=value_of(row[field]); return type(x)=='number' and x or text(x) end)
            return ok and tostring(v) or '?'
        end
        local ok,why=pcall(function()
            local dt=Doro.resolve(TABLE,'/Script/Engine.DataTable')
            if not dt then error('not found',0) end
            dt:ForEachRow(function(key,row)
                rows,row=rows+1,value_of(row)
                local words={'list row '..text(key)}
                for _,f in ipairs(FIELDS) do words[#words+1]=f..'='..read(row,f) end
                local line=table.concat(words,' ')
                if line:lower():find('na_10',1,true) or line:lower():find('eviathan',1,true) then
                    named=named+1
                    log(line..' ID='..read(row,'ID')..' MeshScale='..read(row,'MeshScale'))
                end
            end)
        end)
        log(ok and string.format('list CharacterTable rows=%d named=%d',rows,named)
            or 'list CharacterTable not read: '..tostring(why))
        return true,string.format('Leviathan list: %d of %d assets found, %s; [LV] lines in this log.',found,
            #Leviathan.LIST,ok and named..' CharacterTable rows name it' or 'CharacterTable not read')
    end
    -- A second show replaces the first.
    local function show(which)
        self.restore()
        local eve=her(valid(UE.GetPlayer()))
        if not eve then return false,'no EVE in the world' end
        if shown then remove('replaced') end
        -- A display whose removal failed is still in the file: it goes first, else no new one, so the file never loses
        -- it and the next Lua load can still sweep it.
        local line=store.load()
        if line then
            local ok,why=sweep(line)
            if not ok then return false,'the Leviathan shown before could not be removed: '..tostring(why) end
            store.clear()
        end
        local e=Leviathan.LIST[Leviathan.MESHES[which]]
        local body=valid(eve.Mesh)
        local at,yaw=value_of(body:K2_GetComponentLocation()),math.rad(value_of(eve:K2_GetActorRotation()).Yaw)
        local map=U.map_of(eve)
        local d=Doro.spawn(eve:GetWorld(),{X=at.X+math.cos(yaw)*AHEAD,Y=at.Y+math.sin(yaw)*AHEAD,Z=at.Z},
            {Pitch=0,Yaw=value_of(body:K2_GetComponentRotation()).Yaw+180,Roll=0},
            {path=e.path,static=which=='statue'})
        shown={d=d,name=which,map=map,clips={},k=0,next=0}
        store.save(d.path..'\t'..e.path)
        local clips,skeleton=clips_of(e)
        shown.clips=clips
        log(string.format('show %s: %s, %d clips on skeleton %s',which,name_of(e.path),#clips,
            name_of(skeleton or '-')))
        return true,string.format('Leviathan %s shown 6 m ahead, %d clips in turn; [LV] lines in this log.',which,
            #clips)
    end
    -- The clip whose name ends with want, else holds it (any case), held looping; none: the cycle again.
    local function play(want)
        local s=shown
        if not s then return false,'no Leviathan is shown: coop leviathan show first' end
        if not want then
            s.held,s.next=nil,0
            return true,'Leviathan '..s.name..' back to its cycle.'
        end
        want=want:lower()
        local pick=nil
        for _,c in ipairs(s.clips) do if not pick and c.name:lower():sub(-#want)==want then pick=c end end
        for _,c in ipairs(s.clips) do if not pick and c.name:lower():find(want,1,true) then pick=c end end
        if not pick then return false,'no clip of the shown '..s.name..' ends with or holds '..want end
        s.held,s.next=pick,0
        return true,'Leviathan '..s.name..' holds '..pick.name..' looping; coop leviathan play goes back to the cycle.'
    end
    function self.command(sub,a,extra)
        if extra==nil then
            if (sub==nil or sub=='list') and a==nil then return list() end
            if sub=='show' and (a==nil or Leviathan.MESHES[a]) then return show(a or 'body') end
            if sub=='play' then return play(a) end
            if sub=='off' and a==nil then
                if not shown then return true,'No Leviathan is shown.' end
                remove('coop leviathan off')
                return true,'Leviathan removed.'
            end
        end
        return false,USE
    end
    -- EVE on another map (or none) removes it, and so does its actor no longer being the one spawned, with no call on
    -- it. Then a held clip, played once; else, once the last clip played twice, the next of the cycle, logged.
    local function step(now)
        local s=shown
        local pawn=valid(UE.GetPlayer())
        if not pawn or U.map_of(pawn)~=s.map then return 'map change' end
        if not Doro.same(s.d.actor,s.d.path) then return 'its actor is gone' end
        if now<s.next then return end
        local c=s.held
        if c then
            s.next=math.huge
            log('play '..c.name..' looping')
        elseif #s.clips==0 then
            s.next=math.huge
            return
        else
            s.k=s.k%#s.clips+1
            c=s.clips[s.k]
            s.next=now+2*c.seconds
            log(string.format('show %s step %d/%d %s %.2f s twice',s.name,s.k,#s.clips,c.name,c.seconds))
        end
        Doro.apply(s.d,{asset=c.path,loop=true,rate=1,at=0})
    end
    -- Each frame, on the game thread. Returns ok, message when it removed the display by itself.
    function self.tick()
        if not shown then return end
        local ok,why=pcall(step,os.clock())
        if ok and not why then return end
        local name=shown.name
        remove(ok and why or 'error: '..tostring(why))
        if ok then return true,'Leviathan '..name..' removed: '..why..'.' end
        return false,'Leviathan '..name..' removed on an error: '..tostring(why)
    end
    -- coop off.
    function self.stop() if shown then remove('coop off') end end
    return self
end
return Leviathan
