-- cut/tendril.lua (and the parts of cut/enemy.lua the other specs never reach) with fake UE4SS objects. Its 107 rows
-- are R.TENDRIL (tests/lua/cut/lion_test.lua checks them against rows.h's kTendrilRecipe): 11 MeleeAttack skills, each
-- whose first step plays the run-time Show of its name and turns it toward EVE, whose steps last as long as that
-- Show's clip and whose Hit steps hit through areas of its own; its stance lists the 11 commands; its dead row plays
-- the run-time death Show; its CharacterTable row names its stance, dead, appearance and the Skulling test tree, with
-- no link flag and no name. R.TENDRIL_SHOWS lists exactly the Shows the rows name. The tendril line parses apart from
-- the others. coop tendril fight asks "tendril rows" with the 14 addresses, reads the 107 rows back, builds the 12
-- Shows (each a copy of the template Show in its package, rooted, with its own anim key set to its clip and length,
-- found by its steps' path; a Lua reload finds them built; a copy whose key is the template's stops the spawn), then
-- makes the one spawn call for 50060 8 m ahead of EVE and 1 m above her middle, facing her, cheat on, key 0. The body's
-- mesh turns to yaw 0 and takes the Hydra's tentacle material once found; the boss bar's <M_TendrilC> reads Tendril; a
-- Show the game collected is built again; the body is followed until its death and despawn. Usage, busy and coop off
-- as coop lion's; the source names no spawn, destroy, save or row call of its own, and no engine call comes from a
-- coroutine.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
local names={} -- Every FName made, with whether it was asked to be added.
local function fname(t,add)
    names[#names+1]={t,add}
    return {type=function() return 'FName' end,ToString=function() return t end}
end
FName=fname
FText=function(t) return {text=t} end
local function engine() assert(select(2,coroutine.running()),'an engine call from a coroutine') end
local next_address=0x60000
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
local function is(...)
    local set={...}
    return function(_,c)
        for _,p in ipairs(set) do if c.path==p then return true end end
        return false
    end
end
local classes={}
local function class(path)
    classes[path]=classes[path] or object({path=path})
    return classes[path]
end
local player,pc
package.loaded.UEHelpers={GetPlayer=function() return player end,GetPlayerController=function() return pc end}
local T=require('cut.tendril')
local Enemy=require('cut.enemy')

-- The rows: 107, the counts the tendril line gives once they are in, and what they hold.
assert(#T.ROWS==107 and T.IN.added=='107/107' and T.IN.char=='1/1' and T.IN.skills=='11/11' and T.IN.stance=='1/1')
local by={}
for _,r in ipairs(T.ROWS) do
    r.field={}
    for _,c in ipairs(r.checks) do r.field[c[1]]=c[3] end
    by[r.table..'.'..r.name]=r
end
local function row(t,name) return assert(by[t..'.'..name],t..' '..name).field end
local S=T.SHOWS
assert(S.template=='CH_M_NA_01_Gardener/Skill/M_Gardener_ToxicBeam' and S.key=='SBShowAnimKey_0'
    and S.folder=='/Game/Art/Character/Monster/CH_M_NA_06/Animation/' and #S==12)
local shown,commands={},{}
for _,r in ipairs(T.ROWS) do
    if r.table=='SkillTable' then
        local s=r.field
        assert(s.AISkillFlag=='MeleeAttack' and row('SkillCommandTable',r.name).SkillAlias==r.name,r.name)
        local step=row('SkillActiveStepTable',s.FirstSkillActiveAlias)
        assert(step.ShowPath==S.template..'.'..r.name and step.SelfMoveAliasArray=='M_TendrilC_Turn',r.name)
        local seconds,hits=0,0
        local name=s.FirstSkillActiveAlias
        while name and name~='None' do
            local f=row('SkillActiveStepTable',name)
            seconds=seconds+f.Duration
            if f.Type==1 then
                hits=hits+1
                assert(f.HitDetectionType==1 and f.OverrideTargetFilterAlias:find('^'..r.name..'_HitArea%d$')
                    and by['TargetFilterTable.'..f.OverrideTargetFilterAlias],name)
            end
            name=f.NextStepAlias
        end
        shown[r.name]={seconds=seconds,hits=hits}
        commands[#commands+1]=r.name
    end
end
assert(#commands==11 and row('CharacterStanceTable','M_TendrilC_Default').CommandArray==table.concat(commands,'|'))
assert(shown.M_TendrilC_Rush.hits==4 and shown.M_TendrilC_Whip.hits==3 and shown.M_TendrilC_Chop.hits==1)
for _,s in ipairs(S) do -- Exactly the Shows the rows name, each as long as the steps that play it.
    if s.name=='M_TendrilC_Dead' then
        assert(s.clip=='Dead' and s.seconds==6.0)
    else
        assert(shown[s.name] and math.abs(shown[s.name].seconds-s.seconds)<1e-3,s.name)
        shown[s.name]=nil
    end
end
assert(next(shown)==nil,'A skill whose Show is not listed')
assert(row('CharacterDeadTable','M_TendrilC').DefaultDeadShowArray==S.template..'.M_TendrilC_Dead')
local c=row('CharacterTable','M_TendrilC')
assert(c.BehaviorTreeRes:find('M_Skulling_AI_Test',1,true) and c.DeadAlias=='M_TendrilC'
    and c.RefAppearance=='M_TendrilC' and c.DefaultStanceAlias=='M_TendrilC_Default' and c.Name==''
    and c.ActorType==4 and c.LinkSkillRandomActiveStepFlagArray=='' and c.MaxHP==64960
    and c.DefaultEffectArray:find('M_Common_ImmuneAbnormal',1,true))
assert(row('CharacterAppearanceTable','M_TendrilC').CharacterAssetPath
    =='/Game/Art/Character/Monster/CH_M_NA_06/Blueprints/CH_M_NA_06_Blueprint')
assert(T.IDS[50060]=='M_TendrilC')

-- The tendril line, apart from the others.
local all='lion=rows added=237/237 asks=2 spawns=7 char=2/2 skills=23/23 stance=2/2\n'
    ..'gardener=off\ntendril=refused added=5/107 asks=1 spawns=7 why=donor table=TargetFilterTable '
    ..'row=M_TendrilC_SwingLeft_HitArea1\n'
local s=T.parse(all)
assert(s.state=='refused' and s.added=='5/107' and s.asks==1 and s.row=='M_TendrilC_SwingLeft_HitArea1')
assert(Enemy.parse(all,'gardener').state=='off' and T.parse('lion=off\n')==nil and T.parse(nil)==nil)

-- The world: EVE at the origin facing +X, her player controller, the 14 tables with the Tendril's rows, the template
-- Show in its package (its one anim key on the Gardener's clip), the Hydra's material and the boss bar's TextBlocks.
local CLASS='CH_M_NA_06_Blueprint_C'
local SHOW_CLASS,KEY_CLASS=class('/Script/SB.SBShowData'),class('/Script/SB.SBShowAnimKey')
local TEMPLATE_PATH='/Game/Art/Show/'..S.template..'.M_Gardener_ToxicBeam'
local HYDRA='/Game/Art/Character/Monster/CH_M_NA_09/Materials/MI_M_NA_09_V03_Tentacle.MI_M_NA_09_V03_Tentacle'
local package_object=object({GetFullName=function() return 'Package /Game/Art/Show/'..S.template end})
local inners={} -- Objects by outer address and name, as UE's StaticFindObject in an outer finds them.
local paths={} -- Objects by full path.
local function place(o,outer,name,path)
    inners[outer:GetAddress()..'/'..name],paths[path]=o,o
    o.GetOuter=function() return outer end
end
local template=object({IsA=is('/Script/SB.SBShowData'),EndTime=5.4,bUseStep=false,
    GetFullName=function() return 'SBShowData '..TEMPLATE_PATH end})
template.GetClass=function() return SHOW_CLASS end
place(template,package_object,'M_Gardener_ToxicBeam',TEMPLATE_PATH)
local template_key=object({
    AnimResourcePath='/Game/Art/Character/Monster/CH_M_NA_01/Animation/Mon_Gardener_S_03_Toxic_Beam',PlayEndTime=5.3333,
    Duration=5.3333,bAbsoluteResourcePath=true,bUseCharacterCustomAnim=false})
place(template_key,template,S.key,TEMPLATE_PATH..':'..S.key)
local material=object({IsA=is('/Script/Engine.MaterialInterface'),
    GetFullName=function() return 'MaterialInstanceConstant '..HYDRA end})
paths[HYDRA]=material
local constructed,share_key={},false
StaticConstructObject=function(cls,outer,name,flags,internal,copy,assume,from)
    engine()
    assert(cls==SHOW_CLASS and outer==package_object and from==template and flags==0x1 and internal==0x40000000
        and copy==false and assume==false,'A rooted copy of the template in its package')
    local n=name:ToString()
    local show=object({IsA=is('/Script/SB.SBShowData'),EndTime=from.EndTime,bUseStep=from.bUseStep})
    show.GetClass=function() return SHOW_CLASS end
    local path='/Game/Art/Show/'..S.template..'.'..n
    place(show,outer,n,path)
    if not share_key then -- UE instances the template's anim key under the copy, with the same name.
        local key=object({AnimResourcePath=template_key.AnimResourcePath,PlayEndTime=5.3333,Duration=5.3333,
            bAbsoluteResourcePath=true,bUseCharacterCustomAnim=false})
        place(key,show,S.key,path..':'..S.key)
    end
    constructed[#constructed+1]=show
    return show
end
local world=object({GetFullName=function() return 'World /Game/Maps/F01.F01' end})
local chars={}
local eve=object({at={X=0,Y=0,Z=100},IsA=is('/Script/SB.SBCharacter')})
eve.K2_GetActorLocation=function(self) return {X=self.at.X,Y=self.at.Y,Z=self.at.Z} end
eve.K2_GetActorRotation=function() return {Pitch=0,Yaw=0,Roll=0} end
eve.Mesh=object({K2_GetComponentLocation=function() return {X=eve.at.X,Y=eve.at.Y,Z=eve.at.Z-90} end})
eve.GetWorld=function() return world end
eve.GetFullName=function() return 'EVE_C /Game/Maps/F01.F01:PersistentLevel.EVE' end
chars[1]=eve
player=eve
local calls,on_create={},nil
pc=object({IsA=is('/Script/SB.SBNetworkPlayerController','/Script/Engine.PlayerController')})
function pc:ServerRequest_CreateActor(...)
    engine()
    local a={...}
    assert(#a==10 and T.IDS[a[1]] and a[4]==false and a[5]==true and a[6]==0 and a[7]==0 and a[8]==0
        and a[9]:ToString()=='None' and a[10]==false,'The one spawn call: the Tendril ID, cheat on, key 0')
    calls[#calls+1]=a
    if on_create then on_create(a[1],a[2]) end
end
local made=0
local function body(at)
    made=made+1
    local n=made
    local b=object({at={X=at.X,Y=at.Y,Z=at.Z},InteractionState=0,BroadcastSpawnInfo={EventSpawnId=0},yaw=180})
    b.K2_GetActorLocation=function(self) return {X=self.at.X,Y=self.at.Y,Z=self.at.Z} end
    b.K2_GetActorRotation=function(self) return {Pitch=0,Yaw=self.yaw,Roll=0} end
    b.GetFullName=function() return CLASS..' /Game/Maps/F01.F01:PersistentLevel.'..CLASS..'_'..n end
    b.IsBattle=function() engine(); return true end
    b.GetSBSpeedForAnimGraph=function() engine(); return 0 end
    b.IsRunningSkill=function() engine(); return false end
    b.GetCurrentCustomAnimAlpha=function() engine(); return 0 end
    -- Its mesh as the blueprint sets it: turned -90 degrees, its one material slot empty.
    local m=object({RelativeRotation={Pitch=0,Yaw=-90,Roll=0},turns={},materials={}})
    m.GetAnimInstance=function() return object({GetFullName=function() return 'CH_M_NA_06_AnimBP_C /x' end}) end
    m.K2_SetRelativeRotation=function(self,r,sweep,hit_result,teleport)
        engine()
        assert(sweep==false and type(hit_result)=='table' and teleport==false)
        self.RelativeRotation={Pitch=r.Pitch,Yaw=r.Yaw,Roll=r.Roll}
        self.turns[#self.turns+1]=r.Yaw
    end
    m.GetNumMaterials=function() engine(); return 1 end
    m.SetMaterial=function(self,i,x) engine(); self.materials[i]=x end
    m.GetSocketLocation=function(_,bone)
        engine()
        assert(bone:ToString()=='Bip001-L-Hand')
        return {X=b.at.X,Y=b.at.Y,Z=b.at.Z+40}
    end
    b.Mesh=m
    b.SpawnDefaultController=function(self)
        engine()
        self.Controller=object({GetFullName=function() return 'SBAIController /Game/Maps/F01.F01:Ctl_'..n end})
    end
    chars[#chars+1]=b
    return b
end
local blocks,text_finds={},0
local function block(name,path,text)
    local t=object({shown=text})
    t.GetFName=function(self) return fname(self.name) end
    t.name=name
    t.GetFullName=function(self) return 'TextBlock '..path..'.'..self.name end
    t.GetText=function(self) return {ToString=function() return self.shown end} end
    t.SetText=function(self,x) engine(); self.shown=x.text end
    blocks[#blocks+1]=t
    return t
end
FindAllOf=function(cls)
    engine()
    local out={}
    if cls=='TextBlock' then
        text_finds=text_finds+1
        for _,t in ipairs(blocks) do out[#out+1]=t end
        return out
    end
    for _,ch in ipairs(chars) do if not ch.destroyed and ch~=eve and cls==CLASS then out[#out+1]=ch end end
    return out
end
local tables,present={},{}
local function fresh_rows(t)
    local rows={}
    for _,r in ipairs(T.ROWS) do
        if r.table==t then
            local x={ID=r.id}
            for _,ch in ipairs(r.checks) do
                local v=ch[3]
                if ch[2]=='n' then v=fname(v)
                elseif ch[2]=='b' then v=v==1
                elseif ch[2]=='N' or ch[2]=='S' then
                    local list={}
                    for item in (v..'|'):gmatch('([^|]*)|') do list[#list+1]=ch[2]=='N' and fname(item) or item end
                    if v=='' then list={} end
                    v=list
                end
                x[ch[1]]=v
            end
            rows[r.name]=x
        end
    end
    return rows
end
for _,t in ipairs(Enemy.TABLES) do
    tables[t]=object({rows=fresh_rows(t),IsA=is('/Script/Engine.DataTable'),
        FindRow=function(self,name) engine(); return self.rows[name] end,
        AddRow=function() error('never AddRow on an SB table') end,
        RemoveRow=function() error('never RemoveRow on an SB table') end})
    present[t]=true
end
local gameplay=object({GetWorldDeltaSeconds=function() engine(); return 0.02 end})
local full_finds=0 -- StaticFindObject by a path that is not in memory: what costs 25 to 35 ms in game.
StaticFindObject=function(a,outer,name,exact)
    engine()
    if type(a)~='string' then -- UE's StaticFindObject in an outer.
        assert(type(name)=='string' and exact==false and (a==SHOW_CLASS or a==KEY_CLASS),'In an outer, by class')
        return inners[outer:GetAddress()..'/'..name] or invalid
    end
    if a=='/Script/Engine.Default__GameplayStatics' then return gameplay end
    if a:find('^/Script/') then return class(a) end
    local t=a:match('^/Game/Local/Data/(%a+)%.%a+$')
    if t then return present[t] and tables[t] or invalid end
    if not paths[a] or paths[a].destroyed then full_finds=full_finds+1 end
    return paths[a] or invalid
end
LoadAsset=function() return invalid end

local lines,asked,status_text={},{},'mod=v\ntendril=off\n'
local function last() return lines[#lines] end
local function logged(pattern) for _,l in ipairs(lines) do if l:find(pattern) then return l end end end
local function tendril_status(t) status_text='mod=v\nslot=coop\nlion=off\ngardener=off\ntendril='..t..'\nlast=x\n' end
local function new()
    return T.new({log=function(m) lines[#lines+1]=m end,ask=function(line) asked[#asked+1]=line; return true end,
        status=function() return status_text end})
end
local function at(t) clock=t end
local REQUEST={}
for _,t in ipairs(Enemy.TABLES) do REQUEST[#REQUEST+1]=string.format('%s=0x%x',t,tables[t]:GetAddress()) end
REQUEST='tendril rows '..table.concat(REQUEST,' ')
local ROWS_IN='rows added=107/107 asks=%d spawns=%s char=1/1 skills=11/11 stance=1/1'

local td=new()
-- Usage, and nothing asked without a tendril line.
for _,w in ipairs({{'x'},{'rows','x'},{'intro'},{'half'},{'skulling'}}) do
    local ok,why=td.command(w[1],w[2])
    assert(ok==false and why=='Use: coop tendril fight [rows]',tostring(why))
end
status_text='mod=v\nlion=off\n'
local ok,why=td.command()
assert(ok==false and why=='coop-status.txt has no tendril line: the native part is off, or older than coop tendril '
    ..'fight (coop-link.log): nothing was asked' and #asked==0,why)

-- coop tendril fight rows: one tendril rows request with the 14 addresses, then the wait, the read-back and the Shows,
-- each a rooted copy of the template with its own anim key on its clip and length, found by its steps' path.
tendril_status('off')
local from=#names+1 -- The FNames the command makes.
at(100)
ok,why=td.command('rows')
assert(ok and asked[1]==REQUEST and why=='Tendril rows asked of the native part: the read-back follows once they are '
    ..'in ([TD] lines).',why)
tendril_status(ROWS_IN:format(1,'6'))
at(100.25)
ok,why=td.tick()
assert(ok and why=='Tendril rows in: 107/107 added, SB finds them by ID (char 1/1, skills 11/11, stance 1/1) and they '
    ..'read back as written; coop tendril fight spawns one.',tostring(why))
assert(lines[#lines-1]:find('^rows read back through FindRow: 107/107 authored rows, 1281 fields as written'),
    lines[#lines-1])
assert(last()=='shows: 12/12 ready (12 made, 0 found built), each with its own anim key on its clip and found by the '
    ..'path its steps name',last())
assert(#constructed==12 and #calls==0)
for k,show in ipairs(constructed) do
    local want=S[k]
    local key=inners[show:GetAddress()..'/'..S.key]
    assert(key.AnimResourcePath==S.folder..want.clip and key.bAbsoluteResourcePath==true
        and key.bUseCharacterCustomAnim==false and key.PlayStartTime==0 and key.PlayEndTime==want.seconds
        and key.Duration==want.seconds and show.EndTime==want.seconds and show.bUseStep==false,want.name)
end
assert(template_key.AnimResourcePath:find('Mon_Gardener_S_03_Toxic_Beam',1,true) and template.EndTime==5.4,
    'The template left as it is')
local show_names={}
for _,x in ipairs(S) do show_names[x.name]=true end
for i=from,#names do
    if show_names[names[i][1]] then assert(names[i][2]==1,'A Show\'s name added, not only found: '..names[i][1]) end
end
assert(full_finds==0,'No path that is not in memory looked up')
-- A Lua reload: the Shows are found where they were built, none made again.
local td2=new()
tendril_status(ROWS_IN:format(1,'6'))
at(110)
ok,why=td2.command('rows')
assert(ok and why:find('^Tendril rows in: 107/107') and #constructed==12,tostring(why))
assert(last()=='shows: 12/12 ready (0 made, 12 found built), each with its own anim key on its clip and found by the '
    ..'path its steps name',last())

-- coop tendril fight with the rows in: 50060, 8 m ahead, 1 m above her middle, facing her; the body after 0.3 s, its
-- default controller at 1.5 s, its mesh turned to 0 and painted with the Hydra's tentacle material.
on_create=function(_,p) body(p) end
at(200)
ok,why=td.command()
assert(ok and why=='M_TendrilC 50060 asked: [TD] lines follow.' and #asked==1,why)
assert(logged("^rows already in %(107/107; SB's lookups by ID: char 1/1, skills 11/11, stance 1/1%): not added again$"))
local call=calls[1]
assert(call[1]==50060 and call[2].X==800 and call[2].Y==0 and call[2].Z==200 and call[3].Yaw==180,
    '8 m ahead, 1 m above her middle')
assert(last()=='spawn 50060 (M_TendrilC) at 800,0,200, 8.1 m from EVE, yaw 180.0; spawn count 6',last())
tendril_status(ROWS_IN:format(1,'7'))
at(200.3); assert(td.tick()==nil)
local tendril=chars[#chars]
at(201.5)
ok,why=td.tick()
assert(ok and why=='M_TendrilC 50060 is here, 8.1 m from EVE: tendril 1 in the [TD] lines.',tostring(why))
assert(lines[#lines-2]=='tendril 1: mesh yaw set to 0 (was -90)' and tendril.Mesh.RelativeRotation.Yaw==0,
    lines[#lines-2])
assert(lines[#lines-1]=='tendril 1: material MI_M_NA_09_V03_Tentacle on its 1 slots'
    and tendril.Mesh.materials[0]==material,lines[#lines-1])
assert(last()=='entrance: skipped (none of its clips is an entrance)',last())
-- A second later: the follow line, the boss bar's name, the Shows all there.
local live=block('TextBlock_BossName','/Engine/Transient.GameEngine_0:WB_MainHUD_Master_C_0.WidgetTree',
    '<M_TendrilC>')
local other=block('TextBlock_BossName','/Game/UI/WB_BossHP.WB_BossHP_C:WidgetTree','<M_TendrilC>')
at(202.5); td.tick()
assert(live.shown=='Tendril' and other.shown=='<M_TendrilC>' and last()=='boss name: <M_TendrilC> -> Tendril',last())
assert(logged('^tendril 1 %(50060%): 8%.1 m, xyz 800,0,200,'))
assert(text_finds==1)
-- A Show the game collected: built again at the next second.
constructed[7].destroyed=true
at(203.5); td.tick()
assert(last()=='shows: M_TendrilC_Chop gone: built again' and #constructed==13,last())
local again=constructed[13]
assert(inners[again:GetAddress()..'/'..S.key].AnimResourcePath==S.folder..'M_Tendril_ChopAttack')
-- Its death, then its despawn: D1 and D2.
tendril.InteractionState,tendril.Controller=3,nil
at(240.5); td.tick()
tendril.destroyed=true
tendril_status(ROWS_IN:format(1,'6'))
at(250.5); td.tick()
assert(lines[#lines-1]=='tendril 1 (50060) dead after 39 s (InteractionState 3, no controller); body gone after '
    ..'10.0 s',lines[#lines-1])
assert(last()=='tendril 1 spawn count: before 6, alive 7, after death 6',last())

-- A copy whose anim key is the template's stops the spawn, and the template's key is left alone.
for k in pairs(inners) do if not k:find('^'..package_object:GetAddress()..'/M_Gardener') and k:find('/M_TendrilC_')
    then inners[k]=nil end end
share_key=true
local td3=new()
at(300)
ok,why=td3.command()
assert(ok==false and why=='The Tendril rows are in, but M_TendrilC_SwingLeft: no anim key of its own: no spawn.'
    and #calls==1,why)
assert(template_key.AnimResourcePath:find('Mon_Gardener',1,true))
share_key=false

-- coop off: the job ended, the bodies no longer followed.
for k in pairs(inners) do if k:find('/M_TendrilC_') then inners[k]=nil end end
at(400); assert(td3.command())
td3.stop()
assert(last()=='coop off: the search for its body ended',last())
at(406); assert(td3.tick()==nil and #calls==2,'Nothing after coop off')

-- The source names no spawn, destroy, save, quest, item, reward, achievement, possession, console, object walk or row
-- call of its own: its one spawn call and controller are cut/enemy.lua's (lion_test counts those), and its object calls
-- are the Shows' own (StaticConstructObject, StaticFindObject).
do
    local f=assert(io.open('mod/StellarCoop/Scripts/cut/tendril.lua','rb'))
    local src=f:read('a')
    f:close()
    for call in src:gmatch('[:.]([%a_][%w_]*)%s*%(') do
        for _,word in ipairs({'Achiev','Reward','Item','Quest','Save','ExecuteConsoleCommand','Possess','Spawn',
            'CreateActor','Destroy','AddRow','RemoveRow','EmptyTable','FindAllOf'}) do
            assert(not call:find(word),'cut/tendril: '..call)
        end
    end
    assert(not src:find('FindAllOf',1,true) and select(2,src:gsub('StaticConstructObject%(',''))==1,
        'One construction, no object walk')
end
print('tendril_test: ok')
