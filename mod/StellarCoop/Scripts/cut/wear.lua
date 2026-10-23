-- coop wear: hairs and suits that are complete in the game's files but that no item gives, put on your EVE by setting
-- her own components' meshes (display only). Her equipment, inventory, saves and quests are never read or written: the
-- game still thinks she wears what it put on, and its next save holds that. Her parts (partner/capture.lua reads them):
-- the body is her main mesh (CharacterMesh0, eve.Mesh), the leader that her face and ponytails follow; the hair is
-- SBHair, a leader of its own (its own skeleton, an AnimBP of KawaiiPhysics nodes) hung on the body's Bip001-Head
-- socket. A suit sets the body's mesh only (SetSkeletalMesh with a new pose, as SB's SetMeshInfo does): its skeleton
-- is the body's own (CH_P_EVE_01_Skeleton), so her AnimBP, her followers' links and the physics asset her hits use stay
-- as the game set them; a suit mesh's post-process AnimBP comes with it. A hair also sets SBHair's AnimBP class (the
-- AnimAssetPath of a hair's EquipmentTable row) and its physics asset as the component's override: the cut hair meshes
-- have none of their own, the game's do, and the table has no physics column. Each material slot the game overrides on
-- that component (her hair colour) is set to the new mesh's own material, so the cut asset shows as made. Never
-- NotifyBP_SetMesh, ApplyMeshInfo or SetOverrideClothPhysicsAsset: the ponytail keeps the collision of the suit the
-- game put on, and the hair the ponytail and colour the game gave it.
-- Before the first change on a part, the game's own look of it (mesh, the hair's AnimBP class and physics asset
-- override, the overridden materials) goes into coop-wear.txt (link.store), so coop wear off, coop off and the next Lua
-- load (Ctrl+R, at the first tick) give it back. The game puts its own meshes on again at times (its wardrobe, a map
-- load, a cutscene, photo mode): once a second, unless the game is paused or shows one of its screens (its wardrobe
-- among them), a part whose mesh is no longer the one worn takes the game's new look as the one to give back, then the
-- worn one again, logged. A new EVE (a map load) is the same: her parts get the worn look once she is in the world.
-- Allowed on any save: nothing of it is saved. The friend's ghost follows (the capture reads each part's mesh path
-- every second, and these paths are in /Game/Art/Character, which the link takes).
local UE=require('UEHelpers')
local U=require('core.unreal')
local Doro=require('race.doro')
local valid,value_of,each,text,find=U.valid,U.value_of,U.each,U.text,U.find
local Wear={}
local MESH,CLASS='/Script/Engine.SkeletalMesh','/Script/Engine.AnimBlueprintGeneratedClass'
local PHYSICS,MATERIAL='/Script/Engine.PhysicsAsset','/Script/Engine.MaterialInterface'
local MID,SKINNED='/Script/Engine.MaterialInstanceDynamic','/Script/Engine.SkeletalMeshComponent'
local HAIR='SBHair' -- Her hair's component (ESBMesh_Hair1 in her Blueprint).
local PARTS={'hair','suit'}
local function asset(p) return '/Game/Art/Character/PC/'..p..'.'..p:match('[^/]+$') end
-- The names coop wear takes, in the order coop wear lists them: {part=, mesh=, anim=<hair: its AnimBP class>,
-- physics=<hair: its physics asset>}. The hairs' items (Item_Hair_024 Nyaaa, 025 Mecha Rabbit) have names in
-- ItemStringTable and no ItemTable row; the suits' rows in EquipmentTable (BS_1000 Gothic Rose, BS_Leather_Jean2 Daily
-- Rider, BS_Blue_Suit_Var2 Planet Diving Suit (5th) V2, BS_102_1 Golden Skin Suit, whose materials are the asset's
-- temporary ones) have no ItemTable row either. Every suit mesh is on CH_P_EVE_01_Skeleton; CH_P_EVE_IberisCos has 385
-- bones, the others 159 to 203.
Wear.NAMES={'nyaaa','rabbit','gothic','rider','diving2','golden'}
local function hair(n)
    local dir='00_HR/EVE_HR_'..n..'/EVE_HR_'..n
    return {part='hair',mesh=asset(dir),anim=asset(dir..'_AnimBP')..'_C',physics=asset(dir..'_Physics')}
end
Wear.LOOKS={nyaaa=hair(14),rabbit=hair(15),
    gothic={part='suit',mesh=asset('CH_P_EVE_IberisCostume/CH_P_EVE_IberisCos')},
    rider={part='suit',mesh=asset('CH_P_EVE_03/CH_P_EVE_03_Body')},
    diving2={part='suit',mesh=asset('CH_P_EVE_01/CH_P_EVE_01_TypeB')},
    golden={part='suit',mesh=asset('CH_P_EVE_InnerSuit/CH_P_EVE_InnerSuit1')}}
Wear.USE='Use: coop wear [nyaaa|rabbit|gothic|rider|diving2|golden|off [hair|suit]]'

local function name_of(path) return path:match('[^.]+$') end
local function path_of(o) return text(o:GetFullName()):match('^%S+ (.+)$') end
local function her(pawn) return pawn and pawn:IsA(find('/Script/SB.SBCharacter')) and pawn or nil end
local function mesh_of(c) local m=valid(c.SkeletalMesh); return m and path_of(m) or nil end
-- A part's component on EVE: her main mesh for a suit, SBHair for a hair; nil when she has none.
local function component(eve,part)
    if part=='suit' then return valid(eve.Mesh) end
    local found
    each(eve:K2_GetComponentsByClass(find(SKINNED)),function(_,c)
        c=not found and valid(c)
        if c and text(c:GetFName())==HAIR then found=c end
    end)
    return found
end
-- An AnimBP class by its path: in memory, else its Blueprint's package loaded, whose class then shows
-- (cut/leviathan.lua's lookup).
local function class_of(path)
    local c=Doro.resolve(path,CLASS)
    if c then return c end
    pcall(LoadAsset,path:sub(1,-3))
    return Doro.resolve(path,CLASS)
end
-- A look's assets ({mesh=, anim=, physics=}), loaded before anything changes; nil and why when one is missing.
local function assets_of(look)
    local a={mesh=Doro.resolve(look.mesh,MESH)}
    if not a.mesh then return nil,name_of(look.mesh)..' is missing on this PC' end
    if look.anim then
        a.anim=class_of(look.anim)
        if not a.anim then return nil,name_of(look.anim)..' is missing on this PC' end
        a.physics=Doro.resolve(look.physics,PHYSICS)
        if not a.physics then return nil,name_of(look.physics)..' is missing on this PC' end
    end
    return a
end
-- A material the game made at run time (a dynamic instance: her hair colour) as the asset it was made from, up to 4
-- levels (partner/capture.lua's rule): what a later Lua load can find again by its path.
local function base_of(m)
    for _=1,4 do
        local parent=m:IsA(find(MID)) and valid(m.Parent)
        if not parent then return m end
        m=parent
    end
    return m
end
-- The game's own look of a component: {mesh=<path>, anim=, physics= (a hair's: its AnimBP class and physics asset
-- override, '' for none), materials={{slot=, object=, path=, base=<base_of's path>}} (its overridden slots)}. was: the
-- part as worn before, when the game set a mesh on it: what still holds what apply() put there (the look's AnimBP class
-- or physics asset, a material of was.put, by path) keeps the game's one read before it.
local function read(c,is_hair,was)
    local own={mesh=mesh_of(c),anim='',physics='',materials={}}
    if is_hair then
        local anim,physics=valid(c.AnimClass),valid(c.PhysicsAssetOverride)
        own.anim,own.physics=anim and path_of(anim) or '',physics and path_of(physics) or ''
        if was and own.anim==was.look.anim then own.anim=was.own.anim end
        if was and own.physics==was.look.physics then own.physics=was.own.physics end
    end
    each(c.OverrideMaterials,function(index,m)
        m=valid(m)
        local path=m and path_of(m)
        if m and not (was and was.put and was.put[path]) then
            own.materials[#own.materials+1]={slot=index-1,object=m,path=path,base=path_of(base_of(m))}
        elseif m then
            for _,before in ipairs(was.own.materials) do
                if before.slot==index-1 then own.materials[#own.materials+1]=before end
            end
        end
    end)
    return own
end
-- A look on c (assets a): its mesh, a hair's AnimBP class and physics asset, then each slot the game overrode set to
-- the new mesh's own material (a slot past the new mesh's is left). Returns how many slots were set and the paths of
-- the materials put; raises on a failing call.
local function apply(c,a,own)
    c:SetSkeletalMesh(a.mesh,true)
    if a.anim then c:SetAnimClass(a.anim) end
    if a.physics then c:SetPhysicsAsset(a.physics,false) end
    local slots,n,put={},0,{}
    if own.materials[1] then
        each(a.mesh.Materials,function(index,s) slots[index-1]=valid(value_of(s).MaterialInterface) end)
    end
    for _,m in ipairs(own.materials) do
        local material=slots[m.slot]
        if material then
            c:SetMaterial(m.slot,material)
            n,put[path_of(material)]=n+1,true
        end
    end
    return n,put
end
-- The game's own look back on c: its mesh, a hair's AnimBP class and physics asset override (none when it had none:
-- SetPhysicsAsset(nil) clears it, as UE4SS passes nil as a null object, so this mesh and any hair the game puts on
-- later use their own physics asset), each overridden material (the object itself while it still is the one read, else
-- its base asset). Returns what could not be put back, as words; raises when the mesh cannot be loaded or a call fails.
-- ponytail: a dynamic material the engine collected since (its next GC, about a minute) comes back as the asset it was
-- made from, so a colour SB drives at run time stays still until SB sets that slot again.
local function give_back(c,own,is_hair)
    local mesh=assert(Doro.resolve(own.mesh,MESH),name_of(own.mesh)..' cannot be loaded')
    local missed={}
    c:SetSkeletalMesh(mesh,true)
    if is_hair then
        local anim=own.anim~='' and class_of(own.anim)
        if anim then c:SetAnimClass(anim) elseif own.anim~='' then missed[#missed+1]=name_of(own.anim) end
        local physics=own.physics~='' and Doro.resolve(own.physics,PHYSICS) or nil
        if own.physics~='' and not physics then missed[#missed+1]=name_of(own.physics) end
        c:SetPhysicsAsset(physics,false)
    end
    for _,m in ipairs(own.materials) do
        local material=m.object and Doro.same(m.object,m.path) or Doro.resolve(m.base,MATERIAL)
        if material then c:SetMaterial(m.slot,material) else missed[#missed+1]='slot '..m.slot..' '..m.base end
    end
    return missed
end

-- o: log (the [WR] lines), store (coop-wear.txt through link.store; nil without the native part: no restore at the
-- next Lua load), paused (true while the game is paused or shows one of its screens: no look is put on again then).
-- coop-wear.txt: EVE's path, then for the hair and for the suit five fields: the worn mesh's path and the game's own
-- look (its mesh's path, a hair's AnimBP class and physics asset, its overridden materials as <slot>=<base path>
-- separated by commas), tab-separated, '' for none. It goes once nothing is worn.
function Wear.new(o)
    local log=o.log
    local store=o.store or {save=function() end,load=function() end,clear=function() end}
    local paused=o.paused or function() return false end
    local self={}
    local worn={} -- By part: {name=, look=, c=<component>, c_path=, own=<read()'s>, put=<apply()'s>}.
    local eve_path -- The EVE the worn parts are on.
    local restored,due=false,0
    local function line()
        local f={eve_path or ''}
        for _,part in ipairs(PARTS) do
            local p=worn[part]
            local own=p and p.own or {materials={}}
            local materials={}
            for _,m in ipairs(own.materials) do materials[#materials+1]=m.slot..'='..m.base end
            for _,v in ipairs({p and p.look.mesh or '',own.mesh or '',own.anim or '',own.physics or '',
                table.concat(materials,',')}) do f[#f+1]=v end
        end
        return table.concat(f,'\t')
    end
    -- The file as worn says; gone when nothing is. Returns the store's answer: false and why when it was not written.
    local function keep()
        if next(worn)==nil then return store.clear() end
        return store.save(line())
    end
    -- What an earlier Lua load left worn: each part whose component still shows the mesh it put on gets the game's own
    -- look back, then the file goes. Once, on the game thread (the first tick, or a command).
    function self.restore()
        if restored then return end
        restored=true
        local f={}
        for x in ((store.load() or '')..'\t'):gmatch('([^\t]*)\t') do f[#f+1]=x end
        if (f[1] or '')=='' then return end
        local said={}
        local ok,why=pcall(function()
            local eve=her(valid(StaticFindObject(f[1])))
            for k,part in ipairs(PARTS) do
                local at=1+(k-1)*5
                local worn_path=f[at+1] or ''
                if worn_path~='' then
                    local c=eve and component(eve,part)
                    if c and mesh_of(c)==worn_path then
                        local own={mesh=f[at+2],anim=f[at+3] or '',physics=f[at+4] or '',materials={}}
                        for slot,base in (f[at+5] or ''):gmatch('(%d+)=([^,]+)') do
                            own.materials[#own.materials+1]={slot=tonumber(slot),base=base}
                        end
                        local done,missed=pcall(give_back,c,own,part=='hair')
                        said[#said+1]=done and string.format('%s %s back%s',part,name_of(own.mesh),
                            #missed>0 and ' ('..table.concat(missed,', ')..' not found)' or '')
                            or part..' not given back: '..tostring(missed)
                    else
                        said[#said+1]=part..': nothing to give back'
                    end
                end
            end
        end)
        store.clear()
        log('restore from coop-wear.txt: '..(ok and table.concat(said,'; ') or tostring(why)))
    end
    -- name on EVE: the game's own look read first (kept when that part already wears a look and still shows it), the
    -- file written before anything changes, then the look; a failing call puts the game's look back.
    local function wear(name)
        self.restore()
        local look=Wear.LOOKS[name]
        local eve=her(valid(UE.GetPlayer()))
        if not eve then return false,'no EVE in the world' end
        local a,missing=assets_of(look)
        if not a then return false,missing end
        local c=component(eve,look.part)
        if not c then return false,'EVE has no '..(look.part=='hair' and HAIR or 'main mesh') end
        local was=worn[look.part]
        local is_hair=look.part=='hair'
        local own=was and Doro.same(was.c,was.c_path) and mesh_of(c)==was.look.mesh and was.own
            or read(c,is_hair,was)
        if not own.mesh then return false,text(c:GetFName())..' has no mesh' end
        worn[look.part],eve_path={name=name,look=look,c=c,c_path=path_of(c),own=own},path_of(eve)
        local saved,save_why=keep()
        if saved==false then
            worn[look.part]=was
            return false,'coop-wear.txt not written ('..tostring(save_why)..')'
        end
        local ok,n,put=pcall(apply,c,a,own)
        if not ok then
            worn[look.part]=nil
            local back,missed=pcall(give_back,c,own,is_hair)
            if back then keep() end -- Else the next Lua load tries again.
            log(string.format('wear %s failed: %s; %s',name,tostring(n),back and name_of(own.mesh)..' back'
                or 'the game\'s look not given back: '..tostring(missed)))
            return false,'EVE could not wear '..name..': '..tostring(n)
        end
        worn[look.part].put=put
        log(string.format('wear %s: %s %s (was %s)%s, %d overridden material slots set to its own',name,
            text(c:GetFName()),name_of(look.mesh),name_of(own.mesh),is_hair and ', AnimBP '..name_of(look.anim)
            ..', physics '..name_of(look.physics) or '',n))
        return true,string.format('EVE wears %s as her %s (display only); coop wear off %s gives the game\'s back.',
            name,look.part,look.part)
    end
    -- The game's own look back on each part asked (nil: both) that still shows the worn mesh; a part the game set
    -- again meanwhile, or whose EVE is gone, has it already. Returns the words for each part.
    local function take_off(which,why)
        local said,failed={},false
        for _,part in ipairs(PARTS) do
            local p=(which==nil or which==part) and worn[part]
            if p then
                worn[part]=nil
                local c=Doro.same(p.c,p.c_path)
                local result
                if c and mesh_of(c)==p.look.mesh then
                    local ok,missed=pcall(give_back,c,p.own,part=='hair')
                    failed=failed or not ok
                    result=ok and name_of(p.own.mesh)..' back'..(#missed>0 and ' ('..table.concat(missed,', ')
                        ..' not found)' or '') or 'not given back: '..tostring(missed)
                else
                    result='nothing to give back (the game set its own meanwhile, or EVE is gone)'
                end
                log(string.format('off %s %s (%s): %s',part,p.name,why,result))
                said[#said+1]=part..' '..result
            end
        end
        if said[1] and not failed then keep() end -- Else the next Lua load tries again.
        return said
    end
    -- Once a second while a look is worn and the game is not paused: each part on EVE (a new EVE's own component after
    -- a map load) whose mesh is not the worn one takes the game's mesh as its own look, then the worn one again.
    local function check()
        local eve=her(valid(UE.GetPlayer()))
        if not eve then return end -- A load or the title: the look waits for her.
        local same_eve=path_of(eve)==eve_path
        for _,part in ipairs(PARTS) do
            local p=worn[part]
            local c=p and (same_eve and Doro.same(p.c,p.c_path) or component(eve,part))
            local now=c and mesh_of(c)
            if now and now~=p.look.mesh then
                local a,missing=assets_of(p.look)
                local own=read(c,part=='hair',p)
                worn[part],eve_path={name=p.name,look=p.look,c=c,c_path=path_of(c),own=own},path_of(eve)
                local saved,save_why
                if a then saved,save_why=keep() end
                local ok,n,put=false,missing or 'coop-wear.txt not written ('..tostring(save_why)..')',nil
                if a and saved~=false then ok,n,put=pcall(apply,c,a,own) end
                if ok then
                    worn[part].put=put
                    log(string.format('re-applied %s on %s: the game had set %s',p.name,text(c:GetFName()),
                        name_of(now)))
                else
                    worn[part]=nil
                    local back,missed=true,nil
                    if a and saved~=false then back,missed=pcall(give_back,c,own,part=='hair') end
                    if back then keep() end -- Else the next Lua load tries again.
                    log(string.format('%s not re-applied (the game had set %s): %s; worn no more%s',p.name,
                        name_of(now),tostring(n),back and '' or '; the game\'s look not given back: '
                        ..tostring(missed)))
                end
            end
        end
    end
    -- Each frame, on the game thread; a look is checked once a second. Its first error takes every look off. Returns
    -- ok, message then.
    function self.tick()
        if next(worn)==nil then return end
        local now=os.clock()
        if now<due then return end
        due=now+1
        if paused() then return end
        local ok,why=pcall(check)
        if ok then return end
        local said=take_off(nil,'error')
        return false,'coop wear stopped on an error: '..tostring(why)
            ..(said[1] and '; '..table.concat(said,'; ') or '')
    end
    function self.command(a,b,c)
        if c==nil then
            if a==nil then
                local w,hairs,suits={},{},{}
                for _,part in ipairs(PARTS) do w[#w+1]=part..' '..(worn[part] and worn[part].name or 'none') end
                for _,n in ipairs(Wear.NAMES) do
                    local list=Wear.LOOKS[n].part=='hair' and hairs or suits
                    list[#list+1]=n
                end
                return true,string.format('Worn: %s. Hairs: %s. Suits: %s. coop wear <name> puts one on (display '
                    ..'only), coop wear off [hair|suit] gives the game\'s back.',table.concat(w,', '),
                    table.concat(hairs,', '),table.concat(suits,', '))
            end
            if Wear.LOOKS[a] and b==nil then return wear(a) end
            if a=='off' and (b==nil or b=='hair' or b=='suit') then
                self.restore()
                local said=take_off(b,'coop wear off')
                if #said==0 then return true,b and 'No '..b..' is worn.' or 'Nothing is worn.' end
                return true,'Worn no more: '..table.concat(said,'; ')..'.'
            end
        end
        return false,Wear.USE
    end
    -- coop off.
    function self.stop() take_off(nil,'coop off') end
    return self
end
return Wear
