-- cut/wear.lua with fake UE4SS objects: unknown names and extra words refused with the usage line, with no call; the
-- list of what is worn and of the names; no EVE, a missing asset and coop-wear.txt not written refused before any call;
-- a hair sets SBHair's mesh (with a new pose), AnimBP class (its Blueprint's package loaded when the class is not in
-- memory) and physics asset, and each slot the game overrode (her hair colour, a dynamic material) to the new mesh's
-- own material, after the file holds the game's look; a suit sets the body's mesh only; a hair and a suit together; a
-- second hair replaces the first and keeps the game's look to give back; off gives the game's look back (the dynamic
-- material itself while it lives), one part or both, and the file goes once nothing is worn; a part the game set again
-- meanwhile is left as the game set it; while the game is paused nothing is put on again; then, once a second at most,
-- a part whose mesh the game set takes that look as the one to give back (a slot still holding a material wear put
-- there keeps the game's earlier one) and the worn look again, logged; a new EVE (a map load) gets the worn look; a
-- failing call puts the game's look back; a check's first error takes every look off; the next Lua load gives back what
-- the file names (a material as the asset it was made from), once, and leaves a part the game set again; coop off gives
-- everything back. The face and ponytails (the body's followers) never get a call, and nothing reads or calls anything
-- on EVE but her main mesh, her components, her class and her path: never her equipment.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
local function fname(t) return {type=function() return 'FName' end,ToString=function() return t end} end
local next_address=0x1000
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
local classes={}
local function class(path)
    classes[path]=classes[path] or object({path=path})
    return classes[path]
end
-- Assets by object path: kinds are the classes they are (the first names it), fields their properties.
local assets,loads,packages={},{},{}
local function asset(path,kinds,fields)
    local o=object(fields or {})
    o.at_path=path
    o.GetFullName=function() return kinds[1]:match('[^.]+$')..' '..path end
    o.IsA=function(_,c)
        if c.path=='/Script/CoreUObject.Object' then return true end
        for _,k in ipairs(kinds) do if k==c.path then return true end end
        return false
    end
    assets[path]=o
    return o
end
local by_path={}
StaticFindObject=function(path)
    if by_path[path] then return by_path[path] end
    if path:find('^/Script/') then return class(path) end
    return assets[path] or invalid
end
LoadAsset=function(path) -- A class shows once its Blueprint's package is loaded.
    loads[#loads+1]=path
    local c=packages[path]
    if c then assets[c.at_path]=c end
    return invalid
end
local player
package.loaded.UEHelpers={GetPlayer=function() return player end}
local W=require('cut.wear')
local PC='/Game/Art/Character/PC/'
local function p(rel) return PC..rel..'.'..rel:match('[^/]+$') end
local MAT={'/Script/Engine.MaterialInstanceConstant','/Script/Engine.MaterialInterface'}
local function material(rel) return asset(p(rel),MAT) end
local function mesh(rel,slots,fields)
    local f=fields or {}
    f.Materials={}
    for k,m in ipairs(slots) do f.Materials[k]={MaterialInterface=m,MaterialSlotName=fname('slot'..k)} end
    return asset(p(rel),{'/Script/Engine.SkeletalMesh'},f)
end
local PHYS,ANIM={'/Script/Engine.PhysicsAsset'},{'/Script/Engine.AnimBlueprintGeneratedClass'}
-- The game's own hair (EVE_HR_07, its colour TypeB) and body, and the cut assets.
local hr07_type_b=material('00_HR/EVE_HR_07/Materials/MI_EVE_HR_07_TypeB')
local hr07_phys=asset(p('00_HR/EVE_HR_07/CH_P_EVE_Hair07_PhysicsAsset'),PHYS)
local hr07=mesh('00_HR/EVE_HR_07/CH_P_EVE_Hair07',{material('00_HR/EVE_HR_07/Materials/MI_EVE_HR_07_TypeA')},
    {PhysicsAsset=hr07_phys})
local hr07_anim=asset(p('00_HR/EVE_HR_07/EVE_HR_07_AnimBP')..'_C',ANIM)
local hr14=mesh('00_HR/EVE_HR_14/EVE_HR_14',{material('00_HR/EVE_HR_14/Materials/MI_EVE_HR_14_TypeA'),
    material('00_HR/EVE_HR_14/Materials/MI_EVE_HR_14_Band')})
local hr14_phys=asset(p('00_HR/EVE_HR_14/EVE_HR_14_Physics'),PHYS)
do -- EVE_HR_14's AnimBP class shows once its Blueprint's package is loaded.
    local path=p('00_HR/EVE_HR_14/EVE_HR_14_AnimBP')..'_C'
    packages[path:sub(1,-3)]=asset(path,ANIM)
    assets[path]=nil
end
local hr15=mesh('00_HR/EVE_HR_15/EVE_HR_15',{material('00_HR/EVE_HR_15/Materials/MI_EVE_HR_15')})
local hr15_phys=asset(p('00_HR/EVE_HR_15/EVE_HR_15_Physics'),PHYS)
asset(p('00_HR/EVE_HR_15/EVE_HR_15_AnimBP')..'_C',ANIM)
local eve08=mesh('CH_P_EVE_08/CH_P_EVE_08',{material('CH_P_EVE_08/MI_CH_P_EVE_08_01')})
local eve09=mesh('CH_P_EVE_09/CH_P_EVE_09',{material('CH_P_EVE_09/MI_CH_P_EVE_09_01')})
local iberis=mesh('CH_P_EVE_IberisCostume/CH_P_EVE_IberisCos',{material('CH_P_EVE_IberisCostume/MI_Upper')})
mesh('CH_P_EVE_03/CH_P_EVE_03_Body',{material('CH_P_EVE_03/MI_Base')})
mesh('CH_P_EVE_01/CH_P_EVE_01_TypeB',{material('CH_P_EVE_01/MI_TypeB')})
mesh('CH_P_EVE_InnerSuit/CH_P_EVE_InnerSuit1',{material('CH_P_EVE_InnerSuit/MI_Suit')})
-- Every call on a component, in order with the store's, as words.
local calls={}
local function said(...) calls[#calls+1]=table.concat({...},' ') end
local function short(o) return o.at_path and o.at_path:match('[^.]+$') or o:GetFullName():match('[^.]+$') end
local MID='/Script/Engine.MaterialInstanceDynamic'
-- Her hair colour: a dynamic instance SB made at run time from MI_EVE_HR_07_TypeB.
local function colour(name)
    local path='/Game/Map.Map:PersistentLevel.'..name..'.SBHair.MaterialInstanceDynamic_0'
    local o=object({Parent=hr07_type_b,at_path=path})
    o.GetFullName=function() return 'MaterialInstanceDynamic '..path end
    o.IsA=function(_,c) return c.path==MID or c.path=='/Script/Engine.MaterialInterface' end
    return o
end
-- A component of hers: its mesh, AnimBP class, physics asset override and overridden materials (invalid for a slot
-- with none, as UE4SS gives a None).
local function part(eve_name,name,fields)
    local c=object(fields)
    c.name,c.OverrideMaterials=name,c.OverrideMaterials or {}
    local path='/Game/Map.Map:PersistentLevel.'..eve_name..'.'..name
    function c:GetFName() return fname(name) end
    function c:GetFullName() return 'SBSkeletalMeshComponent '..path end
    function c:SetSkeletalMesh(m,reinit)
        assert(reinit==true,'A new pose, as SB sets a mesh')
        self.SkeletalMesh=m; said(name,'mesh',short(m),tostring(reinit))
    end
    function c:SetAnimClass(k) -- anim_raises: the next call raises it.
        local raise=self.anim_raises
        self.anim_raises=nil
        if raise then error(raise,0) end
        self.AnimClass=k; said(name,'anim',short(k))
    end
    function c:SetPhysicsAsset(a,force) self.PhysicsAssetOverride=a; said(name,'physics',short(a),tostring(force)) end
    function c:SetMaterial(i,m)
        assert(math.type(i)=='integer' and i>=0)
        for k=#self.OverrideMaterials+1,i do self.OverrideMaterials[k]=invalid end
        self.OverrideMaterials[i+1]=m; said(name,'material',i,short(m))
    end
    return c
end
-- EVE: strict, so a read of anything but these fails the test (her equipment, inventory or saves among them).
local ALLOWED={Mesh=true,K2_GetComponentsByClass=true,IsA=true,GetFullName=true,IsValid=true,type=true,GetAddress=true,
    destroyed=true}
local function eve_of(name,body_mesh)
    local e=object()
    local parts={part(name,'CharacterMesh0',{SkeletalMesh=body_mesh or eve08}),
        part(name,'Mesh_Face',{SkeletalMesh=asset(p('CH_P_EVE_Head/CH_P_EVE_Face_Jali3'),{'/Script/Engine.SkeletalMesh'})}),
        part(name,'SBHair',{SkeletalMesh=hr07,AnimClass=hr07_anim,PhysicsAssetOverride=hr07_phys,
            OverrideMaterials={colour(name)}}),
        part(name,'SBPonytail',{SkeletalMesh=asset(p('CH_P_EVE_Hair/CH_P_EVE_Hair_PonyTail_2'),
            {'/Script/Engine.SkeletalMesh'})})}
    e.Mesh=parts[1]
    function e:IsA(k) return k.path=='/Script/SB.SBCharacter' end
    function e:GetFullName() return 'CH_P_EVE_01_Blueprint_C /Game/Map.Map:PersistentLevel.'..name end
    function e:K2_GetComponentsByClass(k)
        assert(k.path=='/Script/Engine.SkeletalMeshComponent')
        return parts
    end
    e.parts,e.hair,e.read=parts,parts[3],{}
    by_path['/Game/Map.Map:PersistentLevel.'..name]=e
    return setmetatable(e,{__index=function(_,k)
        if ALLOWED[k] then return nil end
        e.read[#e.read+1]=k
        error('EVE.'..tostring(k)..' read',0)
    end})
end
local eve=eve_of('EVE_1')
player=eve
local stored -- coop-wear.txt's line.
local refuse -- The store's refusal, when set.
local store={save=function(line)
        if refuse then return false,refuse end
        stored=line; said('save'); return true
    end,load=function() return stored end,clear=function() stored=nil; said('clear') end}
local logs={}
local function log(m) logs[#logs+1]=m end
local function last() return logs[#logs] end
local paused=false
local wr=W.new({log=log,store=store,paused=function() return paused end})
local function fields()
    local f={}
    for x in ((stored or '')..'\t'):gmatch('([^\t]*)\t') do f[#f+1]=x end
    return f
end
local function since(n) return table.concat(calls,'|',n+1) end

-- Refusals: the usage line, with no call and no file.
for _,bad in ipairs({{'cat'},{'NYAAA'},{'off','belt'},{'nyaaa','x'},{'off','hair','x'},{'golden','golden'}}) do
    local ok,why=wr.command(table.unpack(bad))
    assert(not ok and why==W.USE and why=='Use: coop wear [nyaaa|rabbit|gothic|rider|diving2|golden|off [hair|suit]]',
        why)
end
assert(#calls==0 and stored==nil)
-- The list.
local ok,why=wr.command()
assert(ok and why=='Worn: hair none, suit none. Hairs: nyaaa, rabbit. Suits: gothic, rider, diving2, golden. coop wear '
    ..'<name> puts one on (display only), coop wear off [hair|suit] gives the game\'s back.',why)
ok,why=wr.command('off')
assert(ok and why=='Nothing is worn.' and #calls==0,why)
ok,why=wr.command('off','suit')
assert(ok and why=='No suit is worn.',why)
-- No EVE, a missing asset, a pawn that is no SBCharacter: refused before any call.
player=nil
ok,why=wr.command('nyaaa')
assert(not ok and why=='no EVE in the world' and #calls==0,why)
player=object({IsA=function() return false end})
ok,why=wr.command('gothic')
assert(not ok and why=='no EVE in the world' and #calls==0,why)
player=eve
local hr15_path=hr15.at_path
assets[hr15_path]=nil
ok,why=wr.command('rabbit')
assert(not ok and why=='EVE_HR_15 is missing on this PC' and #calls==0 and stored==nil,why)
assets[hr15_path]=hr15
-- The file not written: nothing changes.
refuse='disk full'
ok,why=wr.command('nyaaa')
assert(not ok and why=='coop-wear.txt not written (disk full)' and #calls==0 and eve.hair.SkeletalMesh==hr07,why)
refuse=nil
ok,why=wr.command()
assert(why:find('^Worn: hair none, suit none%.'),why)

-- nyaaa: the file first (the game's hair: its mesh, AnimBP class, physics asset and colour as the asset it was made
-- from), then the mesh, the AnimBP class (its package loaded), the physics asset and the colour's slot.
local hair_colour=eve.hair.OverrideMaterials[1]
ok,why=wr.command('nyaaa')
assert(ok and why=='EVE wears nyaaa as her hair (display only); coop wear off hair gives the game\'s back.',why)
assert(since(0)=='save|SBHair mesh EVE_HR_14 true|SBHair anim EVE_HR_14_AnimBP_C|SBHair physics EVE_HR_14_Physics '
    ..'false|SBHair material 0 MI_EVE_HR_14_TypeA',since(0))
assert(loads[#loads]==p('00_HR/EVE_HR_14/EVE_HR_14_AnimBP'),tostring(loads[#loads]))
local f=fields()
assert(#f==11 and f[1]=='/Game/Map.Map:PersistentLevel.EVE_1' and f[2]==hr14.at_path and f[3]==hr07.at_path
    and f[4]==hr07_anim.at_path and f[5]==hr07_phys.at_path and f[6]=='0='..hr07_type_b.at_path and f[7]==''
    and f[8]=='' and f[11]=='',stored)
assert(last()=='wear nyaaa: SBHair EVE_HR_14 (was CH_P_EVE_Hair07), AnimBP EVE_HR_14_AnimBP_C, physics '
    ..'EVE_HR_14_Physics, 1 overridden material slots set to its own',last())
-- gothic with it: the body's mesh alone (no AnimBP, no physics asset, no slot the game overrode).
local n=#calls
ok,why=wr.command('gothic')
assert(ok and why=='EVE wears gothic as her suit (display only); coop wear off suit gives the game\'s back.',why)
assert(since(n)=='save|CharacterMesh0 mesh CH_P_EVE_IberisCos true',since(n))
f=fields()
assert(f[2]==hr14.at_path and f[7]==iberis.at_path and f[8]==eve08.at_path and f[9]=='' and f[10]=='' and f[11]=='')
assert(last()=='wear gothic: CharacterMesh0 CH_P_EVE_IberisCos (was CH_P_EVE_08), 0 overridden material slots set to '
    ..'its own',last())
ok,why=wr.command()
assert(why:find('^Worn: hair nyaaa, suit gothic%.'),why)
-- rabbit replaces nyaaa: the game's hair is still the one to give back.
n=#calls
ok,why=wr.command('rabbit')
assert(ok and since(n)=='save|SBHair mesh EVE_HR_15 true|SBHair anim EVE_HR_15_AnimBP_C|SBHair physics '
    ..'EVE_HR_15_Physics false|SBHair material 0 MI_EVE_HR_15',since(n))
f=fields()
assert(f[2]==hr15.at_path and f[3]==hr07.at_path and f[6]=='0='..hr07_type_b.at_path and f[7]==iberis.at_path,stored)

-- The game sets its own meshes (its wardrobe): nothing while it is paused, then once a second at most the game's look
-- becomes the one to give back and the worn one goes on again.
eve.Mesh.SkeletalMesh=eve09
paused=true
n=#calls
clock=clock+1; wr.tick(); clock=clock+1; wr.tick()
assert(#calls==n and eve.Mesh.SkeletalMesh==eve09,'Nothing while the game is paused')
paused=false
wr.tick()
assert(#calls==n,'Checked this second already')
clock=clock+1; wr.tick()
assert(since(n)=='save|CharacterMesh0 mesh CH_P_EVE_IberisCos true',since(n))
assert(last()=='re-applied gothic on CharacterMesh0: the game had set CH_P_EVE_09',last())
assert(fields()[8]==eve09.at_path,stored)
eve.Mesh.SkeletalMesh=eve08
n=#calls
clock=clock+0.5; wr.tick()
assert(#calls==n,'Once a second at most')
clock=clock+0.5; wr.tick()
assert(since(n)=='save|CharacterMesh0 mesh CH_P_EVE_IberisCos true' and fields()[8]==eve08.at_path,since(n))
-- The game sets the hair's mesh and its own colour again: that colour is the one to give back.
local hair_colour2=colour('EVE_1b')
eve.hair.SkeletalMesh,eve.hair.AnimClass,eve.hair.OverrideMaterials[1]=hr07,hr07_anim,hair_colour2
n=#calls
clock=clock+1; wr.tick()
assert(since(n)=='save|SBHair mesh EVE_HR_15 true|SBHair anim EVE_HR_15_AnimBP_C|SBHair physics EVE_HR_15_Physics '
    ..'false|SBHair material 0 MI_EVE_HR_15',since(n))
-- The game sets the mesh alone and leaves the slot wear set: the colour read before stays the one to give back.
eve.hair.SkeletalMesh=hr07
clock=clock+1; wr.tick()
assert(last()=='re-applied rabbit on SBHair: the game had set CH_P_EVE_Hair07',last())

-- off hair: the game's hair back with its AnimBP class, physics asset and the colour itself (it still lives); the file
-- keeps the suit only.
n=#calls
ok,why=wr.command('off','hair')
assert(ok and why=='Worn no more: hair CH_P_EVE_Hair07 back.',why)
assert(since(n)=='SBHair mesh CH_P_EVE_Hair07 true|SBHair anim EVE_HR_07_AnimBP_C|SBHair physics '
    ..'CH_P_EVE_Hair07_PhysicsAsset false|SBHair material 0 MaterialInstanceDynamic_0|save',since(n))
assert(eve.hair.OverrideMaterials[1]==hair_colour2 and eve.hair.AnimClass==hr07_anim)
assert(last()=='off hair rabbit (coop wear off): CH_P_EVE_Hair07 back',last())
f=fields()
assert(f[2]=='' and f[3]=='' and f[6]=='' and f[7]==iberis.at_path and f[8]==eve08.at_path,stored)
ok,why=wr.command('off','hair')
assert(ok and why=='No hair is worn.',why)
assert(hair_colour~=hair_colour2)

-- The next Lua load: the suit the file names given back, once, and the file gone.
local wr2=W.new({log=log,store=store,paused=function() return paused end})
n=#calls
wr2.restore(); wr2.restore()
assert(since(n)=='CharacterMesh0 mesh CH_P_EVE_08 true|clear' and stored==nil,since(n))
assert(last()=='restore from coop-wear.txt: suit CH_P_EVE_08 back',last())
-- A hair the file names: its colour as the asset it was made from (a new Lua load has no dynamic one).
wr2.command('nyaaa')
local wr3=W.new({log=log,store=store})
n=#calls
wr3.restore()
assert(since(n)=='SBHair mesh CH_P_EVE_Hair07 true|SBHair anim EVE_HR_07_AnimBP_C|SBHair physics '
    ..'CH_P_EVE_Hair07_PhysicsAsset false|SBHair material 0 MI_EVE_HR_07_TypeB|clear',since(n))
-- A part the game set again before the reload is left as it is.
wr3.command('diving2')
eve.Mesh.SkeletalMesh=eve08
local wr4=W.new({log=log,store=store})
n=#calls
wr4.restore()
assert(since(n)=='clear' and last()=='restore from coop-wear.txt: suit: nothing to give back',since(n))
-- off with the game's own mesh on already: nothing to give back.
wr4.command('rider')
eve.Mesh.SkeletalMesh=eve09
n=#calls
ok,why=wr4.command('off')
assert(ok and since(n)=='clear' and why=='Worn no more: suit nothing to give back (the game set its own meanwhile, or '
    ..'EVE is gone).',why)
eve.Mesh.SkeletalMesh=eve08

-- coop off: everything back.
wr4.command('nyaaa'); wr4.command('golden')
n=#calls
wr4.stop()
assert(since(n)=='SBHair mesh CH_P_EVE_Hair07 true|SBHair anim EVE_HR_07_AnimBP_C|SBHair physics '
    ..'CH_P_EVE_Hair07_PhysicsAsset false|SBHair material 0 MI_EVE_HR_07_TypeB|CharacterMesh0 mesh CH_P_EVE_08 '
    ..'true|clear',since(n))
assert(last()=='off suit golden (coop off): CH_P_EVE_08 back',last())
eve.hair.OverrideMaterials[1]=hair_colour

-- A failing call puts the game's look back and wears nothing.
eve.hair.anim_raises='no class'
n=#calls
ok,why=wr4.command('nyaaa')
assert(not ok and why=='EVE could not wear nyaaa: no class',why)
assert(since(n)=='save|SBHair mesh EVE_HR_14 true|SBHair mesh CH_P_EVE_Hair07 true|SBHair anim EVE_HR_07_AnimBP_C|'
    ..'SBHair physics CH_P_EVE_Hair07_PhysicsAsset false|SBHair material 0 MaterialInstanceDynamic_0|clear',since(n))
assert(last()=='wear nyaaa failed: no class; CH_P_EVE_Hair07 back',last())
ok,why=wr4.command()
assert(why:find('^Worn: hair none, suit none%.'),why)

-- A map load: a new EVE gets the worn look once she is in the world; the old one gets no call.
wr4.command('gothic')
local old=eve
local eve2=eve_of('EVE_2')
player=nil
n=#calls
clock=clock+1; wr4.tick()
assert(#calls==n,'No EVE: the look waits')
player,eve=eve2,eve2
clock=clock+1; wr4.tick()
assert(since(n)=='save|CharacterMesh0 mesh CH_P_EVE_IberisCos true' and eve2.Mesh.SkeletalMesh==iberis,since(n))
assert(fields()[1]=='/Game/Map.Map:PersistentLevel.EVE_2' and fields()[8]==eve08.at_path,stored)
assert(old.Mesh.SkeletalMesh==iberis,'The old EVE is left alone')
-- A check's first error takes every look off.
eve2.Mesh.SkeletalMesh=eve09
local resolve=require('race.doro').resolve
require('race.doro').resolve=function() error('engine fault',0) end
clock=clock+1
local tick_ok,tick_why=wr4.tick()
require('race.doro').resolve=resolve
assert(tick_ok==false and tick_why:find('^coop wear stopped on an error: engine fault; suit nothing to give back'),
    tostring(tick_why))
assert(stored==nil and select(2,wr4.command()):find('^Worn: hair none, suit none%.'))

-- Her followers never got a call, and nothing read anything else on EVE.
for _,e in ipairs({old,eve2}) do
    assert(#e.read==0,table.concat(e.read,' '))
    for _,c in ipairs({e.parts[2],e.parts[4]}) do
        for _,line in ipairs(calls) do assert(not line:find('^'..c.name..' '),line) end
    end
end
print('wear_test ok')
