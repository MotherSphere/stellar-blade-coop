-- cut/lion.lua with fake UE4SS objects. Its row list matches native/src/lion/rows.h's generated recipe row for row
-- (names, IDs, each patched field's kind and value, no field more), and its tables are kLionTables in order. The lion
-- line parses in each of its forms. coop lion finds the 8 tables (a missing one, no EVE or no lion line asks nothing),
-- asks the rows once with every address in the native order, waits for the answer (a waiting line, or a refusal from
-- before the ask, is no answer; a map change, a refusal, a fault, 30 s or SB's lookups finding fewer rows stop it),
-- reads every row back through FindRow (the first value that differs stops before any spawn), then makes the one spawn
-- call: 50020 (50021 after brain lurker, 50110 for control, no rows needed) 10 m ahead and 1 m up, facing EVE, cheat
-- on, key 0. Rows already in are read back without an ask. The body is the new one nearest the spot, given its default
-- controller when it still has none 1.5 s after the call, then followed: a line a second, its death and its body's
-- despawn with the spawn counts; none after 5 s stops. coop lion intro plays the entrance on a display copy first and
-- spawns where its root ended (at the spot when that is too far), removing the copy as soon as the body shows; a map
-- change during it spawns nothing; a copy that cannot be made spawns at once. A second command waits while one runs
-- (brain does not); coop off ends the job and the copy. Never AddRow, RemoveRow or a call from a coroutine, and the
-- source names no save, quest, item, reward, achievement, possession, console, destroy or row call, and no spawn but
-- its one CreateActor and its one SpawnDefaultController.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
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
    for w in assert(src:match('enum class Table : uint8_t { ([^}]+) }')):gmatch('%a+') do enum[#enum+1]=w end
    local names={}
    for n in assert(src:match('constexpr TableInfo kTables%[kTableCount%] = {(.-)\n};')):gmatch('{"(%a+)", 0x') do
        names[#names+1]=n
    end
    assert(#enum==8 and #names==8,'8 tables')
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
    local KINDS={f32='f',name='n',string='s',names='N',strings='S'}
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
            assert(found[2]==KINDS[pt.kind],name..' '..pt.field..' kind')
            if pt.kind=='f32' then assert(math.abs(found[3]-pt.f)<1e-6,name..' '..pt.field)
            else assert(found[3]==pt.text,name..' '..pt.field..': '..found[3]..' vs '..pt.text) end
        end
    end
    assert(n==78 and #L.ROWS==78 and #patches==204,n..' rows, '..#patches..' patches')
    assert(L.IN.added=='78/78' and L.IN.char=='2/2' and L.IN.skills=='15/15' and L.IN.stance=='1/1')
end
-- The read-back covers the link flag (Common, not the Behemoth's) and the moves the generator cut: the side step's 11 m
-- slide gone, the turn's Behemoth root motion gone and its turn kept, the claws' short moves left as the donor's.
do
    local function check(name,field)
        for _,r in ipairs(L.ROWS) do
            if r.name==name and (r.table=='CharacterTable' or r.table=='SkillActiveStepTable') then
                for _,c in ipairs(r.checks) do if c[1]==field then return c[3] end end
                return nil
            end
        end
    end
    assert(check('M_LionC','LinkSkillRandomActiveStepFlagArray')=='Common')
    assert(check('M_LionC_Lurker','LinkSkillRandomActiveStepFlagArray')=='Common')
    assert(check('M_LionC_SideStepLeft_Cast1','SelfMoveAliasArray')=='')
    assert(check('M_LionC_TurnAttackLeft_Cast1','SelfMoveAliasArray')=='M_Behemoth_TurnAttackLeft_Move1')
    assert(check('M_LionC_ClawAttackLeft_Cast1','SelfMoveAliasArray')==nil)
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
local function body(cls,at)
    made=made+1
    local b=object({class=cls,at={X=at.X,Y=at.Y,Z=at.Z},InteractionState=0,BroadcastSpawnInfo={EventSpawnId=0}})
    local n=made
    b.K2_GetActorLocation=function(self) return {X=self.at.X,Y=self.at.Y,Z=self.at.Z} end
    b.GetFullName=function() return cls..' /Game/Maps/E04.E04:PersistentLevel.'..cls..'_'..n end
    b.IsBattle=function(self) engine(); return self.battle==true end
    b.SpawnDefaultController=function(self)
        engine()
        self.Controller=object({GetFullName=function() return 'SBAIController /Game/Maps/E04.E04:Ctl_'..n end})
    end
    chars[#chars+1]=b
    return b
end
FindAllOf=function(cls)
    engine()
    finds=finds+1
    local out={}
    for _,c in ipairs(chars) do if not c.destroyed and (cls=='SBCharacter' or c.class==cls) then out[#out+1]=c end end
    return out
end
-- The tables: our rows as a game with every row in reads them back (FName fields as FNames, lists as Lua lists).
local tables,present={},{}
local function fresh_rows(t)
    local rows={}
    for _,r in ipairs(L.ROWS) do
        if r.table==t then
            local row={ID=r.id}
            for _,c in ipairs(r.checks) do
                local v=c[3]
                if c[2]=='n' then v=fname(v)
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
StaticFindObject=function(path)
    engine()
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
        function m:SetAnimationMode(n) said('mode',n) end
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
    ..'SkillActiveStepTable=0x%x'
local addresses={}
for k,t in ipairs(L.TABLES) do addresses[k]=tables[t]:GetAddress() end
REQUEST=REQUEST:format(table.unpack(addresses))
local ROWS_IN='rows added=78/78 asks=%d spawns=%s char=2/2 skills=15/15 stance=1/1'
local SPOT={X=1000,Y=0,Z=200}
-- The call's body: the Lion with no controller, the Antlion with the game's own.
local function spawns_lion(id,p)
    local b=body(id==50110 and 'CH_M_NA_15_Antlion_C' or LION_CLASS,p)
    if id==50110 then b:SpawnDefaultController() end
end

local lion=new()
-- Usage and nothing reached without EVE, a table or a lion line.
for _,w in ipairs({{'x'},{'rows','x'},{'brain'},{'brain','cat'},{'intro','now'},{nil,nil,'x'}}) do
    local ok,why=lion.command(w[1],w[2],w[3])
    assert(ok==false and why=='Use: coop lion [intro] | rows | control | brain skulling|lurker',tostring(why))
end
player=nil
local ok,why=lion.command()
assert(ok==false and why:find('^no EVE in the world') and #asked==0 and #calls==0,why)
player=eve
present.SkillTable=false
ok,why=lion.command('rows')
assert(ok==false and why=='The game has no SkillTable loaded: nothing was asked.' and #asked==0,why)
assert(last()=='tables: 7/8 found, missing SkillTable: nothing asked',last())
present.SkillTable=true
status_text='mod=v\n'
ok,why=lion.command()
assert(ok==false and why:find('^coop%-status%.txt has no lion line') and #asked==0,why)
assert(last():find('^tables: 8/8 found: CharacterTable=0x'),last())
refuse_ask='the Steam link needs the native part'
lion_status('off')
ok,why=lion.command('rows')
assert(ok==false and why=='Lion rows not asked: the Steam link needs the native part' and #asked==0,why)
refuse_ask=nil

-- coop lion rows: one ask with the 8 addresses in kLionTables' order, then the wait.
at(100)
ok,why=lion.command('rows')
assert(ok and asked[1]==REQUEST and #asked==1,asked[1])
assert(last()=='rows asked of the native part (lion=off): its answer is the next asks= past 0',last())
assert(logged('^tables: 8/8 found: '..REQUEST:sub(11):gsub('%-','%%-')..'$'),'R1 with every address')
ok,why=lion.command()
assert(ok==false and why=='coop lion is busy (the wait for the Lion rows): try again in a few seconds',why)
ok,why=lion.command('brain','lurker')
assert(ok and why=='coop lion spawns 50021 (M_LionC_Lurker, the Lesser Lurker tree) until the mod reloads.',why)
ok,why=lion.command('brain','skulling'); assert(ok and why:find('^coop lion spawns 50020 %(M_LionC, the Skulling'))
lion_status('waiting added=10/78 asks=0 spawns=? why=busy ticks=3')
at(100.1); assert(lion.tick()==nil and not logged('^rows wait'),'Not due before 0.25 s')
at(100.25); assert(lion.tick()==nil and last()=='rows wait for the game thread: lion=waiting added=10/78 asks=0 '
    ..'spawns=? why=busy ticks=3',last())
local n=#lines
at(100.5); lion.tick(); assert(#lines==n,'Said once')
lion_status(ROWS_IN:format(1,'6'))
at(100.75)
ok,why=lion.tick()
assert(ok and why=='Lion rows in: 78/78 added, SB finds them by ID (char 2/2, skills 15/15, stance 1/1) and they read '
    ..'back as written; coop lion spawns one.',tostring(why))
assert(lines[#lines-1]=='rows answer: lion='..ROWS_IN:format(1,'6') and last()=='rows read back through FindRow: '
    ..'78/78 match',last())
assert(#calls==0 and #asked==1,'Rows only: no spawn')

-- coop lion with the rows in: no ask, the read-back, the spawn call, then the body after 0.3 s.
on_create=spawns_lion
at(200)
ok,why=lion.command()
assert(ok and why=='M_LionC 50020 asked: [LI] lines follow.' and #asked==1,why)
assert(logged("^rows already in %(78/78; SB's lookups by ID: char 2/2, skills 15/15, stance 1/1%): not added again$"))
local c=calls[1]
assert(c[1]==50020 and c[2].X==1000 and c[2].Y==0 and c[2].Z==200 and c[3].Yaw==180 and c[3].Pitch==0,
    'Ahead 10 m, 1 m up, facing EVE')
assert(last()=='spawn 50020 (M_LionC) at 1000,0,200, 10.0 m from EVE, yaw 180.0; spawn count 6',last())
lion_status(ROWS_IN:format(1,'7'))
at(200.29); assert(lion.tick()==nil)
local lion1=chars[#chars]
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
assert(lion.tick()==nil and last()=='lion 1 (50020): 10.0 m, battle 0, state 0, controller yes, spawn count 7',last())
lion1.battle=true
at(203); n=#lines; lion.tick(); assert(#lines==n,'One a second')
at(203.5); lion.tick()
assert(last()=='lion 1 (50020): 10.0 m, battle 1, state 0, controller yes, spawn count 7',last())
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
assert(last():find('^rows read back through FindRow: M_LionC_ClawAttackLeft_Hit1 .* %(1/78 match before it%): '
    ..'no spawn$'),last())
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
local dead=tables.CharacterDeadTable.rows.M_LionC
tables.CharacterDeadTable.rows.M_LionC=nil
ok,why=lion.command()
assert(ok==false and why=='A Lion row reads back wrong (M_LionC is not in CharacterDeadTable): no spawn.',why)
tables.CharacterDeadTable.rows.M_LionC=dead
-- SB's lookups finding fewer rows: no spawn.
lion_status('rows added=78/78 asks=1 spawns=6 char=1/2 skills=15/15 stance=1/1')
ok,why=lion.command()
assert(ok==false and why=='The Lion rows are not all usable: lion=rows added=78/78 asks=1 spawns=6 char=1/2 '
    ..'skills=15/15 stance=1/1 (char=1/2, 2/2 expected): no spawn.' and #calls==1,why)

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
antlion.destroyed=true -- Gone with the map while alive.
at(601.3); lion.tick()
assert(lines[#lines-1]=='lion 2 (50110) gone while alive after 1 s (a map change, or the game removed it)',
    lines[#lines-1])
assert(last()=='lion 2 spawn count: before ?, alive ?, after ?',last())

-- A fresh Lua load with the rows not in: a refusal from before the ask is no answer, nor a waiting line with asks
-- grown (an earlier ask finished, then ours was taken); then a refusal after it stops, and asking again goes on.
lion=new()
lion_status('refused added=3/78 asks=1 spawns=6 why=busy table=- row=-')
at(700)
assert(lion.command() and asked[2]==REQUEST,'Asked again after a refusal')
at(700.25); assert(lion.tick()==nil,'The old refusal is no answer')
lion_status('waiting added=3/78 asks=2 spawns=6 why=net ticks=1')
at(700.5); assert(lion.tick()==nil,'A waiting line is no answer')
lion_status('refused added=3/78 asks=3 spawns=6 why=net table=- row=- detail=1')
at(700.75)
ok,why=lion.tick()
assert(ok==false and why=='The native part refused the Lion rows (why=net, table=-, row=-): coop-link.log says why; '
    ..'asking again skips the rows already in.' and #calls==3,tostring(why))
-- A fault, the 30 s limit and a map change each stop the wait.
lion_status('off')
at(800); assert(lion.command())
lion_status('fault added=3/78 asks=1 spawns=6 where=SB.exe+0x10')
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

-- The source names no achievement, reward, item, quest, save, possession, console command, destroy or row call of its
-- own, and its only spawn words are its one CreateActor and its one SpawnDefaultController (race/doro.lua's spawn
-- and remove make and drop the display copy).
do
    local f=assert(io.open('mod/StellarCoop/Scripts/cut/lion.lua','rb'))
    local src=f:read('a')
    f:close()
    local allowed,seen={ServerRequest_CreateActor=true,SpawnDefaultController=true},{}
    for call in src:gmatch('[:.]([%a_][%w_]*)%s*%(') do
        if allowed[call] then seen[call]=(seen[call] or 0)+1
        else
            for _,word in ipairs({'Achiev','Reward','Item','Quest','Save','ExecuteConsoleCommand','Possess','Spawn',
                'CreateActor','Destroy','AddRow','RemoveRow','EmptyTable'}) do
                assert(not call:find(word),'cut/lion: '..call)
            end
        end
    end
    assert(seen.ServerRequest_CreateActor==1 and seen.SpawnDefaultController==1,'One spawn call, one controller')
end
print('lion_test: ok')
