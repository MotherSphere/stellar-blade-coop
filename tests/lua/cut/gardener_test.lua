-- cut/gardener.lua (and the parts of cut/enemy.lua the Lion's spec never reaches) with fake UE4SS objects. Its 13 rows
-- are R.GARDENER (tests/lua/cut/lion_test.lua checks them against rows.h's kGardenerRecipe): ToxicBeam's steps last its
-- Show's 5.4 s, its three skills are MeleeAttack, its stance never moves, its CharacterTable rows name its own dead,
-- appearance and detect rows, its trees and scales. The gardener line parses apart from the lion line. coop gardener
-- fight asks "gardener rows" with the 14 addresses, reads the 13 rows back (the first value that differs stops before
-- the spawn), then makes the one spawn call for 50010 (50012 with half, 50011 with skulling) 25 m ahead of EVE (12.5 m
-- for half) and 7.5 m above her feet, facing her, cheat on, key 0. The body's mesh turns -90 degrees once found (S3),
-- and again when the game turns it back; it is followed until its death and despawn. intro plays Mon_Gardener_C_Appear
-- on a display copy of its mesh turned the same way. Usage, busy and coop off as coop lion's; the source names no
-- spawn, destroy, save or row call of its own, and no engine call comes from a coroutine.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
local function fname(t) return {type=function() return 'FName' end,ToString=function() return t end} end
FName=fname
local function engine() assert(select(2,coroutine.running()),'an engine call from a coroutine') end
local next_address=0x40000
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
    classes[path]=classes[path] or object({path=path,MakeTransform=function() return 'identity' end})
    return classes[path]
end
local player,pc
package.loaded.UEHelpers={GetPlayer=function() return player end,GetPlayerController=function() return pc end}
local G=require('cut.gardener')
local Enemy=require('cut.enemy')

-- The rows: 13, the counts the gardener line gives once they are in, and what they hold.
assert(#G.ROWS==13 and G.IN.added=='13/13' and G.IN.char=='3/3' and G.IN.skills=='3/3' and G.IN.stance=='1/1')
local by={}
for _,r in ipairs(G.ROWS) do
    r.field={}
    for _,c in ipairs(r.checks) do r.field[c[1]]=c[3] end
    by[r.table..'.'..r.name]=r
end
local function row(t,name) return assert(by[t..'.'..name],t..' '..name).field end
local cast,hit,finish=row('SkillActiveStepTable','M_GardenerC_ToxicBeam_Cast1'),
    row('SkillActiveStepTable','M_GardenerC_ToxicBeam_Hit1'),row('SkillActiveStepTable','M_GardenerC_ToxicBeam_Finish1')
assert(cast.ShowPath=='CH_M_NA_01_Gardener/Skill/M_Gardener_ToxicBeam'
    and cast.NextStepAlias=='M_GardenerC_ToxicBeam_Hit1' and hit.NextStepAlias=='M_GardenerC_ToxicBeam_Finish1')
assert(math.abs(cast.Duration+hit.Duration+finish.Duration-5.4)<1e-6,'The Show lasts 5.4 s')
assert(hit.UsableTargetProjectileAliasArray==hit.UsableNonTargetProjectileAliasArray
    and select(2,hit.UsableTargetProjectileAliasArray:gsub('|',''))==7,'8 shells')
for name,first in pairs({M_GardenerC_SingleShot='M_Gardener_SingleShot_4_Cast1',
    M_GardenerC_MultipleShot='M_Gardener_MultipleShot_1_Cast1',M_GardenerC_ToxicBeam='M_GardenerC_ToxicBeam_Cast1'}) do
    local s=row('SkillTable',name)
    assert(s.AISkillFlag=='MeleeAttack' and s.FirstSkillActiveAlias==first,name)
    assert(row('SkillCommandTable',name).SkillAlias==name)
end
local stance=row('CharacterStanceTable','M_GardenerC_Default')
assert(stance.CommandArray=='M_GardenerC_SingleShot|M_GardenerC_MultipleShot|M_GardenerC_ToxicBeam')
assert(stance.WalkSpeed==0 and stance.RunSpeed==0 and stance.LockOnRunSpeed==0 and stance.LockOnWalkSpeed==0)
for name,want in pairs({M_Gardener={'M_Tentacle_AI',1.0},M_Gardener_Half={'M_Tentacle_AI',0.5},
    M_Gardener_Skulling={'M_Skulling_AI_Test',1.0}}) do
    local c=row('CharacterTable',name)
    assert(c.BehaviorTreeRes:find(want[1],1,true) and c.MeshScale==want[2] and c.DeadAlias=='M_Gardener'
        and c.RefAppearance=='M_Gardener' and c.DefaultDetectAIAlias=='M_Gardener' and c.MaxHP==37840
        and c.Name=='Char_M_Gardener_AlbumName' and c.DefaultStanceAlias=='M_GardenerC_Default'
        and c.ActorType==4 and c.LinkSkillRandomActiveStepFlagArray=='',name)
    assert(c.DefaultEffectArray:find('M_Common_FixedLocation',1,true) and not c.DefaultEffectArray:find('Maelstrom'),
        name)
end
assert(G.IDS[50010]=='M_Gardener' and G.IDS[50011]=='M_Gardener_Skulling' and G.IDS[50012]=='M_Gardener_Half')

-- The gardener line, apart from the lion line.
local both='lion=rows added=237/237 asks=2 spawns=7 char=2/2 skills=23/23 stance=2/2\n'
    ..'gardener=refused added=3/13 asks=1 spawns=7 why=donor table=SkillTable row=M_GardenerC_SingleShot\n'
local s=G.parse(both)
assert(s.state=='refused' and s.added=='3/13' and s.asks==1 and s.why=='donor' and s.row=='M_GardenerC_SingleShot')
assert(Enemy.parse(both,'lion').added=='237/237' and G.parse('lion=off\n')==nil and G.parse(nil)==nil)

-- The world: EVE at the origin facing +X (her feet 90 cm below her middle), her player controller, the 14 tables with
-- the Gardener's rows, its mesh and appear clip.
local DIR='/Game/Art/Character/Monster/CH_M_NA_01/'
local MESH,CLIP=DIR..'CH_M_NA_01.CH_M_NA_01',DIR..'Animation/Mon_Gardener_C_Appear.Mon_Gardener_C_Appear'
local CLASS='CH_M_NA_01_BluePrint_C'
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
    assert(#a==10 and G.IDS[a[1]] and a[4]==false and a[5]==true and a[6]==0 and a[7]==0 and a[8]==0
        and a[9]:ToString()=='None' and a[10]==false,'The one spawn call: a Gardener ID, cheat on, key 0')
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
    -- Its mesh: an anim instance of its own AnimBP, and its relative rotation, which K2_SetRelativeRotation sets.
    local m=object({RelativeRotation={Pitch=0,Yaw=0,Roll=0},turns={}})
    m.GetAnimInstance=function() return object({GetFullName=function() return 'CH_M_NA_01_AnimBP_C /x' end}) end
    m.K2_SetRelativeRotation=function(self,r,sweep,hit_result,teleport)
        engine()
        assert(sweep==false and type(hit_result)=='table' and teleport==false)
        self.RelativeRotation={Pitch=r.Pitch,Yaw=r.Yaw,Roll=r.Roll}
        self.turns[#self.turns+1]=r.Yaw
    end
    m.GetSocketLocation=function(_,bone)
        engine()
        assert(bone:ToString()=='Bip001-L-Hand')
        return {X=b.at.X,Y=b.at.Y,Z=b.at.Z+400}
    end
    b.Mesh=m
    b.SpawnDefaultController=function(self)
        engine()
        self.Controller=object({GetFullName=function() return 'SBAIController /Game/Maps/F01.F01:Ctl_'..n end})
    end
    chars[#chars+1]=b
    return b
end
FindAllOf=function(cls)
    engine()
    local out={}
    for _,c in ipairs(chars) do if not c.destroyed and c~=eve and cls==CLASS then out[#out+1]=c end end
    return out
end
local tables,present={},{}
local function fresh_rows(t)
    local rows={}
    for _,r in ipairs(G.ROWS) do
        if r.table==t then
            local x={ID=r.id}
            for _,c in ipairs(r.checks) do
                local v=c[3]
                if c[2]=='n' then v=fname(v)
                elseif c[2]=='b' then v=v==1
                elseif c[2]=='N' or c[2]=='S' then
                    local list={}
                    for item in (v..'|'):gmatch('([^|]*)|') do list[#list+1]=c[2]=='N' and fname(item) or item end
                    if v=='' then list={} end
                    v=list
                end
                x[c[1]]=v
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
local mesh_asset=object({IsA=is('/Script/Engine.SkeletalMesh'),key='mesh',
    GetFullName=function() return 'SkeletalMesh '..MESH end})
local clip_asset=object({IsA=is('/Script/Engine.AnimSequence','/Script/Engine.AnimationAsset'),SequenceLength=15.5,
    key='clip',GetFullName=function() return 'AnimSequence '..CLIP end})
local assets={[MESH]=mesh_asset,[CLIP]=clip_asset}
local gameplay=object({GetWorldDeltaSeconds=function() engine(); return 0.02 end})
StaticFindObject=function(path)
    engine()
    if path=='/Script/Engine.Default__GameplayStatics' then return gameplay end
    if path:find('^/Script/') then return class(path) end
    local t=path:match('^/Game/Local/Data/(%a+)%.%a+$')
    if t then return present[t] and tables[t] or invalid end
    return assets[path] or invalid
end
LoadAsset=function() return invalid end
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
        function m:SetAnimationMode(n) said('mode',n); self.instance=n==1 end
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
    a.GetFullName=function() return 'Actor /Game/Maps/F01.F01:PersistentLevel.Actor_'..#actors end
    actors[#actors+1]=a
    return a
end

local lines,asked,status_text={},{},'mod=v\ngardener=off\n'
local function last() return lines[#lines] end
local function logged(pattern) for _,l in ipairs(lines) do if l:find(pattern) then return l end end end
local function gardener_status(t) status_text='mod=v\nslot=coop\nlion=off\ngardener='..t..'\nlast=x\n' end
local function new()
    return G.new({log=function(m) lines[#lines+1]=m end,ask=function(line) asked[#asked+1]=line; return true end,
        status=function() return status_text end})
end
local function at(t) clock=t end
local REQUEST={}
for _,t in ipairs(Enemy.TABLES) do REQUEST[#REQUEST+1]=string.format('%s=0x%x',t,tables[t]:GetAddress()) end
REQUEST='gardener rows '..table.concat(REQUEST,' ')
local ROWS_IN='rows added=13/13 asks=%d spawns=%s char=3/3 skills=3/3 stance=1/1'
local function spawns_body(_,p) body(p) end

local gd=new()
-- Usage and nothing reached without EVE, a table or a gardener line.
for _,w in ipairs({{'x'},{'rows','x'},{'half','now'},{'control'},{'brain','lurker'}}) do
    local ok,why=gd.command(w[1],w[2])
    assert(ok==false and why=='Use: coop gardener fight [intro|half|skulling|rows]',tostring(why))
end
player=nil
local ok,why=gd.command()
assert(ok==false and why:find('^no EVE in the world') and #asked==0,why)
player=eve
present.SkillActiveStepTable=false
ok,why=gd.command('rows')
assert(ok==false and why=='The game has no SkillActiveStepTable loaded: nothing was asked.',why)
present.SkillActiveStepTable=true
status_text='mod=v\nlion=off\n'
ok,why=gd.command()
assert(ok==false and why=='coop-status.txt has no gardener line: the native part is off, or older than coop gardener '
    ..'fight (coop-link.log): nothing was asked' and #asked==0,why)

-- coop gardener fight rows: one gardener rows request with the 14 addresses, then the wait and the read-back.
gardener_status('off')
at(100)
ok,why=gd.command('rows')
assert(ok and asked[1]==REQUEST and why=='Gardener rows asked of the native part: the read-back follows once they are '
    ..'in ([GD] lines).',why)
ok,why=gd.command('half')
assert(ok==false and why=='coop gardener fight is busy (the wait for the Gardener rows): try again in a few seconds',
    why)
gardener_status('waiting added=0/13 asks=0 spawns=? why=busy ticks=3')
at(100.25); assert(gd.tick()==nil and last()=='rows wait for the game thread: gardener=waiting added=0/13 asks=0 '
    ..'spawns=? why=busy ticks=3',last())
gardener_status(ROWS_IN:format(1,'6'))
at(100.5)
ok,why=gd.tick()
assert(ok and why=='Gardener rows in: 13/13 added, SB finds them by ID (char 3/3, skills 3/3, stance 1/1) and they '
    ..'read back as written; coop gardener fight spawns one.',tostring(why))
assert(last()=='rows read back through FindRow: 13/13 authored rows, 279 fields as written (102 differ from the '
    ..'template row)',last())
assert(#calls==0)

-- coop gardener fight with the rows in: 50010, 25 m ahead, 7.5 m above her feet, facing her; the body after 0.3 s, its
-- default controller at 1.5 s, its mesh turned -90 degrees (S3).
on_create=spawns_body
at(200)
ok,why=gd.command()
assert(ok and why=='M_Gardener 50010 asked: [GD] lines follow.' and #asked==1,why)
assert(logged("^rows already in %(13/13; SB's lookups by ID: char 3/3, skills 3/3, stance 1/1%): not added again$"))
local c=calls[1]
assert(c[1]==50010 and c[2].X==2500 and c[2].Y==0 and c[2].Z==760 and c[3].Yaw==180,'25 m ahead, 7.5 m over her feet')
assert(last()=='spawn 50010 (M_Gardener) at 2500,0,760, 25.9 m from EVE, yaw 180.0; spawn count 6',last())
gardener_status(ROWS_IN:format(1,'7'))
at(200.3); assert(gd.tick()==nil)
local tower=chars[#chars]
at(201.5)
ok,why=gd.tick()
assert(ok and why=='M_Gardener 50010 is here, 25.9 m from EVE: gardener 1 in the [GD] lines.',tostring(why))
assert(lines[#lines-2]=='spawn 50010: CreateActor returned; body '..CLASS..' 25.9 m from EVE, 0.0 m from the spot, '
    ..'after 0.3 s; controller SBAIController (SpawnDefaultController gave it); EventSpawnId 0',lines[#lines-2])
assert(lines[#lines-1]=='gardener 1: mesh yaw set to -90 (was 0)' and tower.Mesh.RelativeRotation.Yaw==-90,
    lines[#lines-1])
assert(last()=='entrance: skipped (off by default: a clip on its mesh would replace the anim instance SB plays its '
    ..'skills on; coop gardener fight intro plays Mon_Gardener_C_Appear on a display copy before the spawn)',last())
-- Followed a second later; the game turning its mesh back gets it turned again, said.
at(202.5); gd.tick()
assert(last():find('^gardener 1 %(50010%): 25%.9 m, xyz 2500,0,760, speed 0, skill no, anim alpha 0%.00/0%.00, hand '
    ..'moved %?, battle 1, state 0, controller yes, spawn count 7, frame 20%.0 ms'),last())
assert(lines[#lines-1]:find('^gardener 1 %(50010%) mesh: anim instance CH_M_NA_01_AnimBP_C,'),lines[#lines-1])
assert(#tower.Mesh.turns==1,'Turned once')
tower.Mesh.RelativeRotation={Pitch=0,Yaw=0,Roll=0}
at(203.5); gd.tick()
assert(lines[#lines-1]=='gardener 1 (50010): mesh yaw 0, not -90 (the game turned it back): set again',
    lines[#lines-1])
assert(#tower.Mesh.turns==2 and tower.Mesh.RelativeRotation.Yaw==-90)
at(204.5); gd.tick(); assert(#tower.Mesh.turns==2,'Left alone while it stays turned')
tower.Mesh.RelativeRotation={Pitch=0,Yaw=270,Roll=0}
at(205.5); gd.tick(); assert(#tower.Mesh.turns==2,'270 is -90 once round')
-- Its death, then its despawn: D1 and D2.
tower.InteractionState,tower.Controller=3,nil
at(250.5); gd.tick()
tower.destroyed=true
gardener_status(ROWS_IN:format(1,'6'))
at(266.5); gd.tick()
assert(lines[#lines-1]=='gardener 1 (50010) dead after 49 s (InteractionState 3, no controller); body gone after '
    ..'16.0 s',lines[#lines-1])
assert(last()=='gardener 1 spawn count: before 6, alive 7, after death 6',last())

-- half: 50012 at 12.5 m; skulling: 50011 at 25 m.
at(300); assert(gd.command('half'))
assert(calls[2][1]==50012 and calls[2][2].X==1250 and calls[2][2].Z==760,'The half-scale row nearer')
at(300.3); gd.tick(); at(301.5); assert(gd.tick())
at(310); assert(gd.command('skulling'))
assert(calls[3][1]==50011 and calls[3][2].X==2500,'The Skulling tree')
at(310.3); gd.tick(); at(311.5); assert(gd.tick())

-- A row that reads back wrong stops before the spawn.
local half=tables.CharacterTable.rows.M_Gardener_Half
half.MeshScale=1.0
at(400)
ok,why=gd.command()
assert(ok==false and why=='A Gardener row reads back wrong (M_Gardener_Half MeshScale reads "1.0", not "0.5"): no '
    ..'spawn.' and #calls==3,why)
half.MeshScale=0.5

-- intro: Mon_Gardener_C_Appear on a display copy of its mesh at the spot, on EVE's feet, turned -90 degrees from facing
-- her as the body's mesh is; then the Gardener where its root ended, the copy gone once the body shows.
root={X=2600,Y=0,Z=0}
at(500)
ok,why=gd.command('intro')
assert(ok and #calls==3,'No spawn before the entrance ends')
local copy=actors[#actors]
local m=copy.components[1]
assert(table.concat(m.calls,'|')=='mesh mesh|scale 1|collision 0|mode 1|scale 1|play clip false|rate 1|at 0',
    table.concat(m.calls,'|'))
assert(m.at.X==2500 and m.at.Z==10 and m.rot.Yaw==90,'On the spot, on her feet, its front toward her')
assert(last()=='entrance: playing Mon_Gardener_C_Appear (15.5 s) on a display copy at 2500,0,10',last())
at(515.4); assert(gd.tick()==nil and #calls==3)
at(515.5); assert(gd.tick()==nil and calls[4][1]==50010 and calls[4][2].X==2600 and calls[4][2].Z==760)
assert(lines[#lines-1]=='entrance: played on a display copy for 15.5 s; its root ended 1.0 m from the spot: the '
    ..'Gardener spawns there',lines[#lines-1])
at(515.8); gd.tick(); assert(copy.destroyed,'Gone once the body shows')
at(517); assert(gd.tick())
local skipped=0
for _,l in ipairs(lines) do skipped=skipped+(l:find('^entrance: skipped') and 1 or 0) end
assert(skipped==3,'Said for the three spawns without intro only')
-- coop off: the job ended, the bodies no longer followed (they stay).
at(600); assert(gd.command('intro'))
copy=actors[#actors]
gd.stop()
assert(copy.destroyed and last()=='coop off: the entrance ended; 3 Gardener bodies no longer followed (they stay)',
    last())
at(616); assert(gd.tick()==nil and #calls==4,'Nothing after coop off')

-- The source names no spawn, destroy, save, quest, item, reward, achievement, possession, console or row call of its
-- own: its one spawn call and controller are cut/enemy.lua's (lion_test counts those).
do
    local f=assert(io.open('mod/StellarCoop/Scripts/cut/gardener.lua','rb'))
    local src=f:read('a')
    f:close()
    for call in src:gmatch('[:.]([%a_][%w_]*)%s*%(') do
        for _,word in ipairs({'Achiev','Reward','Item','Quest','Save','ExecuteConsoleCommand','Possess','Spawn',
            'CreateActor','Destroy','AddRow','RemoveRow','EmptyTable','StaticFindObject','FindAllOf'}) do
            assert(not call:find(word),'cut/gardener: '..call)
        end
    end
end
print('gardener_test: ok')
