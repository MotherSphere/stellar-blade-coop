-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The closet's copy of eve/wear.lua's SBHair swap (November 2026), cut to the closet's hair and ponytail: its own from then on.
-- Stellar Closet's head part (closet/dress.lua's o.head): the Head tab's Hair and Ponytail fits (closet/fits.lua) worn
-- on EVE's own head components, display only. Her equipment, saves and the Hair Salon are never read or written.
--   SBHair: a hair fit's mesh, its AnimBP class (a stock row's AnimAssetPath, a pack's AnimationBP), its physics asset
--     (a cut hair's PhysicsAsset; else the mesh's own, as the game sets it), its variant's materials (each slot the
--     game overrode gets the new mesh's own when the variant names none) and a stock row's rotation. A pack hair's
--     transform stays as the component has it.
--   SBPonytail: one ponytail at a time. A stock hair brings its own (SB.Ponytail_Short when the game's ponytail is the
--     short mesh, else SB.Ponytail_Long) in the hair's variant (salon colour) when the hair has colour controls
--     (Fits.follows; under a cut hair its own variant); a picked ponytail wins; a pack hair, a
--     stock hair with HidePonytail and SB.Ponytail_None hide it. Its cloth collision is the hair's (or ponytail's)
--     PonyPhysics, else the body's, set when it resolves.
--   SBPonytailShort: hidden while the closet holds the ponytail (no stock row puts a mesh there).
-- Before the first change the game's own pieces are read (line(), which the dress writes as field 6 of
-- coop-closet.txt before each wear), so give_back, coop off and the next Lua load (restore) put them back.
-- Once a second (tick), unless the game is paused or shows one of its screens: a worn component the game changed (the
-- salon, photo mode, a map load: a new EVE's components) for 2 s takes the game's new look as the one to give back and
-- gets the closet's piece again. FIGHT: something outside that undoes every re-wear makes the closet leave it until the
-- next wear. A closet change never counts.
--
-- The game's parts (SB-Win64-Shipping.exe, build 26123051, read 27 Nov 2026):
--   USkinnedMeshComponent.SetSkeletalMesh(NewMesh, bReinitPose): native entry 0x14665f1e0 (name 0x14665be90), exec
--     0x14492a420 calls vtable +0x910 (mesh, bReinitPose). The equip step FUN_1424c12e0 calls +0x910 with (mesh, 1).
--   USkinnedMeshComponent.SetPhysicsAsset(NewPhysicsAsset, bForceReInit): entry 0x14665f1a0 (name 0x14665bee0), exec
--     0x14492aea0 calls vtable +0x908. FUN_1424c12e0 sets it to the new mesh's own physics asset (mesh +0x178), else
--     "{0}/{1}_PhysicsAsset.{2}_PhysicsAsset'" (0x145c6eda0; {0} the mesh path before its last '/', FUN_142903b70;
--     {1} {2} its name, FUN_142910780) when it loads (FUN_14213a310), else none. The closet does the same.
--   USkeletalMeshComponent.SetAnimClass(NewClass): entry 0x146659ae0 (name 0x1466542d8), exec 0x144920a70 calls
--     vtable +0xa08. FUN_1424c12e0 sets a row's AnimAssetPath class through FUN_14411af10.
--   USceneComponent.K2_SetRelativeRotation(NewRotation, bSweep, SweepHitResult, bTeleport): entry 0x14664bb90 (name
--     0x1466487c0), exec 0x14490f950.
--   USceneComponent.SetVisibility(bNewVisibility, bPropagateToChildren): entry 0x14664bca0 (name 0x1461b8380), exec
--     0x14490b360 -> FUN_14410dfb0. How the game hides the ponytail: FUN_14203bb10 stores bHidePonyTail (character
--     +0x2f88, property params 0x145d7a840; IsHidePonyTail exec 0x1426853f0 reads it) and calls FUN_14410dfb0(slot 3's
--     component, visible, 1): SetVisibility(visible, false) on SBPonytail. The equip step FUN_141caddf0 then skips the
--     ponytail row while that flag is set. The closet calls SetVisibility itself and leaves the flag alone.
--   The ponytail length: FUN_141caddf0 reads game option 0x58 ('X') for a row of type 6 (Ponytail) and loads the row
--     "%s_Short" when it is 1; that row is type 6 too, so both lengths go on slot 3 (SBPonytail). FUN_1424c12e0 marks
--     the short one by the mesh name "CH_P_EVE_Hair_PonyTail_Short" (0x145c6ebe8, manager +0x5f4). Type 7
--     (PonytailShort, slot 4 by FUN_141a2d790) is in no row of SB/Content/Local/Data/EquipmentTable.uasset: nothing
--     drives SBPonytailShort. The closet tells the length by that mesh name on the game's own SBPonytail.
--   The ponytail collision: after a mesh change on slot 0, 2 or 3 FUN_1424c12e0 builds
--     "{0}/{1}_PonytailPhysicsAsset.{2}_PonytailPhysicsAsset" (0x145c6edf0; {0} the body mesh's path before its last
--     '/', FUN_1429039f0; {1} {2} its name, FUN_142910570) and gives it to FUN_14411e0f0(SBPonytail, asset), which
--     writes USkeletalMeshComponent.OverrideClothPhysicsAsset (+0xdd8, property params 0x1466556b8) and recreates the
--     cloth when it has one (else marks +0xde0 for later). The closet writes that property, before SetSkeletalMesh,
--     as online/partner/puppet.lua does (the cloth made by a new mesh takes it).
local UE=require('UEHelpers')
local U=require('core.unreal')
local Doro=require('core.actors')
local Dress=require('closet.dress')
local Fits=require('closet.fits')
local valid,value_of,each,text,find=U.valid,U.value_of,U.each,U.text,U.find
local Head={}
-- An outside fight, copy of closet/dress.lua's Dress.FIGHT: this many re-wears within this many seconds.
Head.FIGHT={mixes=5,within=15}
local CLASS,PHYSICS='/Script/Engine.AnimBlueprintGeneratedClass','/Script/Engine.PhysicsAsset'
local MATERIAL,MID='/Script/Engine.MaterialInterface','/Script/Engine.MaterialInstanceDynamic'
local SKINNED='/Script/Engine.SkeletalMeshComponent'
local HAIR,PONY,SHORT='SBHair','SBPonytail','SBPonytailShort' -- Mesh slots Hair1, Ponytail, PonytailShort.
local NAMES={HAIR,PONY,SHORT}
local LONG_ID,SHORT_ID='SB.Ponytail_Long','SB.Ponytail_Short'
local SHORT_MESH='CH_P_EVE_Hair_PonyTail_Short'

local function name_of(path) return (path or ''):match('[^./]+$') or '' end
local function path_of(o)
    local ok,p=pcall(function() return text(o:GetFullName()):match('^%S+ (.+)$') end)
    return ok and p or nil
end
local function mesh_of(c) local m=valid(c.SkeletalMesh); return m and path_of(m) or nil end
local function visible(c) return c:IsVisible()==true end
local function her() return U.her(valid(UE.GetPlayer())) end
local function rotation_of(c)
    local r=value_of(c.RelativeRotation)
    return r and {Pitch=r.Pitch,Yaw=r.Yaw,Roll=r.Roll} or nil
end
local function same_rotation(a,b)
    return a and b and a.Pitch==b.Pitch and a.Yaw==b.Yaw and a.Roll==b.Roll or a==b
end
-- EVE's head components by name (eve/wear.lua's component, for three names).
local function components(eve)
    local out={}
    each(eve:K2_GetComponentsByClass(find(SKINNED)),function(_,c)
        c=valid(c)
        local n=c and text(c:GetFName())
        if n and (n==HAIR or n==PONY or n==SHORT) and not out[n] then out[n]=c end
    end)
    return out
end
-- An asset of a class by path (closet/dress.lua's resolve: a mod pack's asset too), or nil.
local function resolve(path,class)
    local o=path and path~='' and Dress.resolve(path)
    return o and o:IsA(find(class)) and o or nil
end
-- An AnimBP class: in memory, else its Blueprint's package loaded (eve/wear.lua's class_of), else through the asset
-- registry (closet/dress.lua's resolve: a mod pack's package). path: the class (..._C, the stock rows' AnimAssetPath)
-- or the Blueprint's asset path, as packs name their AnimationBP (the BG3 hair packs: "<pack>_AnimBP.<pack>_AnimBP";
-- cutting two characters off that, as this did, named nothing: "is missing on this PC" in game, 27 Nov 2026).
local function class_of(path)
    local cls=path:match('_C$') and path or path..'_C'
    local bp=cls:sub(1,-3)
    local c=resolve(cls,CLASS)
    if c then return c end
    pcall(LoadAsset,bp)
    c=resolve(cls,CLASS)
    if c then return c end
    pcall(Dress.resolve,bp)
    return resolve(cls,CLASS)
end
-- A run-time material (a dynamic instance) as the asset it was made from, up to 4 levels (eve/wear.lua's base_of).
local function base_of(m)
    for _=1,4 do
        local parent=m:IsA(find(MID)) and valid(m.Parent)
        if not parent then return m end
        m=parent
    end
    return m
end
-- A hair mesh's physics asset by the game's name when the mesh has none (FUN_1424c12e0's format, see the header).
local function named_physics(path)
    local dir,name=(path or ''):match('^(.*)/([^/]+)%.[^/]*$')
    return dir and dir..'/'..name..'_PhysicsAsset.'..name..'_PhysicsAsset' or nil
end
-- The ponytail collision the game names from the body mesh (see the header), or nil.
local function body_collision(eve)
    local body=valid(eve.Mesh)
    local package=(body and mesh_of(body) or ''):match('^(.-)%.') or ''
    local dir,name=package:match('^(.*)/([^/]+)$')
    return dir and dir..'/'..name..'_PonytailPhysicsAsset.'..name..'_PonytailPhysicsAsset' or nil
end

-- The game's own look of component n: {mesh=, anim=, physics=, rotation= (SBHair), visible=, cloth= (the ponytails),
-- materials={{slot=, object=, path=, base=}}}. was: the piece the closet wore there, when the game set something
-- since: what still holds the closet's put keeps the game's one read before (eve/wear.lua's rule).
local function read(c,n,was)
    local before=was and was.own
    local own={materials={},mesh=n~=SHORT and mesh_of(c) or nil}
    if n~=HAIR then
        own.visible=visible(c)
        if before and was.visible==own.visible then own.visible=before.visible end
    end
    if n==SHORT then return own end
    if n==HAIR then
        local anim,physics=valid(c.AnimClass),valid(c.PhysicsAssetOverride)
        own.anim,own.physics=anim and path_of(anim) or '',physics and path_of(physics) or ''
        own.rotation=rotation_of(c)
        if before and own.anim==was.anim then own.anim=before.anim end
        if before and own.physics==was.physics then own.physics=before.physics end
        if before and was.rotation and same_rotation(own.rotation,was.rotation) then own.rotation=before.rotation end
    else
        local cloth=valid(c.OverrideClothPhysicsAsset)
        own.cloth=cloth and path_of(cloth) or ''
        if before and was.cloth and own.cloth==was.cloth then own.cloth=before.cloth end
    end
    each(c.OverrideMaterials,function(index,m)
        m=valid(m)
        local path=m and path_of(m)
        if m and not (before and was.put[path]) then
            own.materials[#own.materials+1]={slot=index-1,object=m,path=path,base=path_of(base_of(m))}
        elseif m then
            for _,b in ipairs(before.materials) do if b.slot==index-1 then own.materials[#own.materials+1]=b end end
        end
    end)
    return own
end

-- The game's own look back on component n. Returns what could not be put back, as words; raises when its mesh does
-- not load or a call fails. SetPhysicsAsset(nil) clears the override (UE4SS passes nil as a null object).
local function give_back(c,n,own)
    local missed={}
    if n==SHORT then c:SetVisibility(own.visible==true,false); return missed end
    if n==PONY then
        local cloth=own.cloth~='' and resolve(own.cloth,PHYSICS) or nil
        local now=valid(c.OverrideClothPhysicsAsset)
        if (now and path_of(now) or '')~=own.cloth then c.OverrideClothPhysicsAsset=cloth end
    end
    local mesh=own.mesh and assert(Dress.usable(own.mesh),name_of(own.mesh)..' cannot be loaded')
    if mesh then c:SetSkeletalMesh(mesh,true) end
    if n==HAIR then
        local anim=own.anim~='' and class_of(own.anim)
        if anim then c:SetAnimClass(anim) elseif own.anim~='' then missed[#missed+1]=name_of(own.anim) end
        local physics=own.physics~='' and resolve(own.physics,PHYSICS) or nil
        if own.physics~='' and not physics then missed[#missed+1]=name_of(own.physics) end
        c:SetPhysicsAsset(physics,false)
    end
    -- A slot the closet painted that the game had not overridden: the mesh's own material again.
    local had,mine={},{}
    for _,m in ipairs(own.materials) do had[m.slot]=true end
    if mesh then each(mesh.Materials,function(index,s) mine[index-1]=valid(value_of(s).MaterialInterface) end) end
    local painted={}
    each(c.OverrideMaterials,function(index,m)
        if valid(m) and not had[index-1] then painted[#painted+1]=index-1 end
    end)
    for _,slot in ipairs(painted) do if mine[slot] then c:SetMaterial(slot,mine[slot]) end end
    for _,m in ipairs(own.materials) do
        local material=m.object and Doro.same(m.object,m.path) or resolve(m.base,MATERIAL)
        if material then c:SetMaterial(m.slot,material) else missed[#missed+1]='slot '..m.slot..' '..m.base end
    end
    if n==HAIR and own.rotation and not same_rotation(rotation_of(c),own.rotation) then
        c:K2_SetRelativeRotation(own.rotation,false,{},false)
    end
    if n==PONY then c:SetVisibility(own.visible==true,false) end
    return missed
end

-- field 6 of coop-closet.txt (line): EVE's path, then per component '|<name>;<mark>;<mesh>;<anim>;<physics>;
-- <slot>=<base>,...;<visible 1|0>;<cloth>;<pitch>,<yaw>,<roll>', '' for none: the game's own pieces with a mark, '+'
-- when the closet wears a piece there, '-' when it hides it, '' when it leaves it. The dress writes it before each
-- wear and again after a head wear that went on, so the marks are the worn ones.
-- shortcut: a crash between the first write and the second leaves that wear's components unmarked (left at the next
-- load); write the marks before the calls if that shows in game.
local function encode(n,state,own)
    local mats={}
    for _,m in ipairs(own.materials) do mats[#mats+1]=m.slot..'='..m.base end
    local r=own.rotation
    return table.concat({n,state,own.mesh or '',own.anim or '',own.physics or '',table.concat(mats,','),
        own.visible==nil and '' or own.visible and '1' or '0',own.cloth or '',
        r and r.Pitch..','..r.Yaw..','..r.Roll or ''},';')
end
local function decode(entry)
    local f={}
    for x in (entry..';'):gmatch('([^;]*);') do f[#f+1]=x end
    local own={mesh=f[3]~='' and f[3] or nil,anim=f[4] or '',physics=f[5] or '',materials={},cloth=f[8] or ''}
    for slot,base in (f[6] or ''):gmatch('(%d+)=([^,]+)') do
        own.materials[#own.materials+1]={slot=tonumber(slot),base=base}
    end
    if f[7]~='' then own.visible=f[7]=='1' end
    local p,y,r=(f[9] or ''):match('^([^,]+),([^,]+),([^,]+)$')
    if p then own.rotation={Pitch=tonumber(p),Yaw=tonumber(y),Roll=tonumber(r)} end
    return f[1],f[2] or '',own
end

-- o: log (the [CL] lines), fits (closet/fits.lua: get), paused (no re-wear while true), clock (seconds).
function Head.new(o)
    local log=o.log
    local fits=o.fits or require('closet.fits')
    local paused=o.paused or function() return false end
    local clock=o.clock or os.clock
    local self={}
    -- By component name: {c=, c_path=, own=<read()'s>, worn=<the piece on it: {fit=, slot=, mesh=, hidden=, anim=,
    -- physics=, cloth=, rotation=, visible=, put=, count=, key=}>}. eve_path: the EVE they are on.
    local parts,eve_path={},nil
    local list={} -- The choices worn.
    local due,wrong,fights,stopped,applied=0,0,{},false,0
    local said={} -- Variant materials that did not load, said once.

    -- The game's own look of each head component not read yet (all again on a new EVE).
    local function capture(eve)
        local path=path_of(eve)
        if path~=eve_path then parts,eve_path={},path end
        for n,c in pairs(components(eve)) do
            if not parts[n] then parts[n]={c=c,c_path=path_of(c),own=read(c,n)} end
        end
    end

    -- What each component should wear for list: {[name]={fit=, slot=, mesh=, anim=, physics=, rotation=, materials=,
    -- cloth=, hide=}}, or nil and why.
    local function plan(eve)
        local hair,pony
        for _,choice in ipairs(list) do
            local fit=fits.get(choice.fit)
            if not fit then return nil,choice.fit..' is not installed' end
            if choice.slot=='Hair' then hair=hair or {id=choice.fit,f=fit}
            elseif choice.slot=='Ponytail' then pony=pony or {id=choice.fit,f=fit} end
        end
        local out={}
        local stock_hair=hair and hair.f.Origin=='original'
        if hair then
            out[HAIR]={fit=hair.id,slot='Hair',mesh=hair.f.Mesh,anim=hair.f.AnimationBP,physics=hair.f.PhysicsAsset,
                rotation=hair.f.Rotation,materials=hair.f.Materials or {}}
        end
        if not pony and stock_hair and not hair.f.HidePonytail and hair.f.Ponytail then
            local game=parts[PONY] and parts[PONY].own.mesh or ''
            local id=game:find(SHORT_MESH,1,true) and SHORT_ID or LONG_ID
            local f=fits.get(id)
            if f then pony={id=id,f=f} end
        end
        local collision=(pony and pony.f.PonyPhysics) or (hair and hair.f.PonyPhysics)
        if pony and pony.f.Mesh~='' then
            local materials=pony.f.Materials or {}
            if hair and Fits.follows(hair.f,pony.f) then -- The hair's salon colour.
                local v=pony.f.Variants and pony.f.Variants[hair.f.Variant or 1]
                materials=v and v.Materials or materials
            end
            out[PONY]={fit=pony.id,slot='Ponytail',mesh=pony.f.Mesh,materials=materials,
                cloth=collision or body_collision(eve)}
        elseif pony or hair then
            if pony or hair.f.HidePonytail or not stock_hair then out[PONY]={hide=true,cloth=collision} end
        end
        if out[PONY] then out[SHORT]={hide=true} end
        return out
    end

    -- A target's assets, loaded before anything changes: {mesh=, anim=, physics=, cloth=, materials={[slot]=obj}},
    -- or nil and why. The cloth and a variant's material that do not load are left out.
    local function assets_of(t)
        local a={materials={}}
        if t.mesh and t.mesh~='' then
            local why
            a.mesh,why=Dress.usable(t.mesh)
            if not a.mesh then return nil,why end
        end
        if t.anim then
            a.anim=class_of(t.anim)
            if not a.anim then return nil,name_of(t.anim)..' is missing on this PC' end
        end
        if t.physics then
            a.physics=resolve(t.physics,PHYSICS)
            if not a.physics then return nil,name_of(t.physics)..' is missing on this PC' end
        elseif t.slot=='Hair' and a.mesh and not valid(a.mesh.PhysicsAsset) then
            a.physics=resolve(named_physics(t.mesh),PHYSICS) -- The game's second try; none when it does not load.
        end
        a.cloth=t.cloth and resolve(t.cloth,PHYSICS)
        for i,p in ipairs(t.materials or {}) do
            local m=p~='' and resolve(p,MATERIAL)
            if m then a.materials[i-1]=m
            elseif p~='' and not said[p] then said[p]=true; log('head: '..p..' does not load: left out') end
        end
        return a
    end

    -- Each slot of the new mesh, each the game overrode and each the variant names: the variant's material, else the
    -- new mesh's own. Every mesh slot, as a slot an earlier hair or its colour painted kept that material on the next
    -- mesh (Klukai's tech band on the BG3 hairs, Schizo's video of 27 Nov 2026).
    local function paint(c,a,own,mesh)
        local mine,slots,order={},{},{}
        each(mesh.Materials,function(index,s)
            mine[index-1]=valid(value_of(s).MaterialInterface)
            slots[index-1]=true
        end)
        for _,m in ipairs(own.materials) do slots[m.slot]=true end
        for slot in pairs(a.materials) do slots[slot]=true end
        for slot in pairs(slots) do order[#order+1]=slot end
        table.sort(order)
        local put={}
        for _,slot in ipairs(order) do
            local m=a.materials[slot] or mine[slot]
            if m then c:SetMaterial(slot,m); put[path_of(m)]=true end
        end
        return put
    end

    -- Target t on component n (its part p), assets a; only its materials when the piece already shows. Raises on a
    -- failing call.
    local function put_on(n,p,t,a,only_paint)
        local c,w,was=p.c,{fit=t.fit,slot=t.slot,mesh=t.mesh,hidden=t.hide or nil,put={}},p.worn
        p.worn=w -- Set first: a call that fails gives back what went on.
        if t.hide then
            if a.cloth then c.OverrideClothPhysicsAsset=a.cloth; w.cloth=path_of(a.cloth) end
            c:SetVisibility(false,false)
            w.visible=false
            return
        end
        local mesh=a.mesh or valid(c.SkeletalMesh)
        if not only_paint then
            if n==PONY and a.cloth then c.OverrideClothPhysicsAsset=a.cloth; w.cloth=path_of(a.cloth) end
            c:SetSkeletalMesh(a.mesh,true)
            if a.anim then c:SetAnimClass(a.anim); w.anim=path_of(a.anim) end
            if n==HAIR then
                -- The game's rule (FUN_1424c12e0): a cut hair's own asset, else the mesh's own, else its named one.
                local want=t.physics and a.physics or valid(a.mesh.PhysicsAsset) or a.physics
                local now=valid(c.PhysicsAssetOverride)
                if (now and path_of(now))~=(want and path_of(want)) then c:SetPhysicsAsset(want,false) end
                w.physics=want and path_of(want) or ''
            end
        else
            w.anim,w.physics,w.cloth,w.rotation=was.anim,was.physics,was.cloth,was.rotation
        end
        w.put=paint(c,a,p.own,mesh)
        if not only_paint and n==HAIR and t.rotation then
            c:K2_SetRelativeRotation(t.rotation,false,{},false)
            w.rotation=t.rotation
        elseif not only_paint and n==HAIR and was and was.rotation and p.own.rotation then
            c:K2_SetRelativeRotation(p.own.rotation,false,{},false) -- A stock row's rotation off a hair with none.
        end
        if n==PONY then c:SetVisibility(true,false); w.visible=true end
        local count=0
        each(mesh.Materials,function(index) count=math.max(count,index) end)
        w.count=count
    end

    -- Whether component n still shows what the closet put there.
    local function holds(n,p)
        local c=Doro.same(p.c,p.c_path)
        if not (c and p.worn) then return false end
        if p.worn.hidden then return not visible(c) end
        return mesh_of(c)==p.worn.mesh and (n~=PONY or visible(c))
    end
    local function key(t)
        local m={}
        for i,x in ipairs(t.materials or {}) do m[i]=x end
        return table.concat({t.fit or '',tostring(t.hide),t.mesh or '',table.concat(m,',')},'\n')
    end

    -- The game's own look back on component n when it still shows the closet's piece. Returns the words.
    local function take_off(n,p)
        if not p.worn then return nil end
        if not holds(n,p) then return n..': nothing to give back (the game set its own meanwhile, or EVE is gone)' end
        local missed=give_back(p.c,n,p.own)
        p.worn=nil
        return n..' '..(p.own.mesh and name_of(p.own.mesh) or 'shown')..' back'
            ..(#missed>0 and ' ('..table.concat(missed,', ')..' not found)' or '')
    end

    -- list on EVE: force names the components put on again even when they hold the same piece (rewear, the
    -- watchdog). Returns true and whether anything changed, or nil and why (nothing changed then).
    local function dress_up(eve,force)
        capture(eve)
        local targets,why=plan(eve)
        if not targets then return nil,why end
        local assets={}
        for n,t in pairs(targets) do
            if not parts[n] then
                if n~=SHORT then return nil,'EVE has no '..n end
                targets[n]=nil
            else
                assets[n],why=assets_of(t)
                if not assets[n] then return nil,why end
            end
        end
        local changed,lines=false,{}
        local ok,e=pcall(function()
            for _,n in ipairs(NAMES) do
                local p,t=parts[n],targets[n]
                if t then
                    t.key=key(t)
                    local same_piece=p.worn and p.worn.fit==t.fit and p.worn.hidden==(t.hide or nil) and holds(n,p)
                    if not same_piece or p.worn.key~=t.key or (force and force[n] and not t.hide) then
                        local only_paint=same_piece and not t.hide and p.worn.mesh==t.mesh
                        put_on(n,p,t,assets[n],only_paint)
                        p.worn.key=t.key
                        changed=true
                        lines[#lines+1]=n..' '..(t.hide and 'hidden' or t.fit..(only_paint and ' (materials)' or ''))
                    end
                elseif p and p.worn then
                    lines[#lines+1]=take_off(n,p)
                    parts[n]=nil -- Read again before the next change.
                    changed=true
                end
            end
        end)
        if not ok then
            local back={}
            for _,n in ipairs(NAMES) do
                local p=parts[n]
                if p and p.worn then
                    local done,w=pcall(take_off,n,p)
                    back[#back+1]=done and w or n..' not given back: '..tostring(w)
                end
            end
            log('head: wear failed: '..tostring(e)..(back[1] and '; '..table.concat(back,'; ') or ''))
            return nil,'EVE could not wear the head pieces: '..tostring(e)
        end
        if changed then log('head: '..table.concat(lines,', ')) end
        return true,changed
    end

    function self.line()
        local eve=her()
        local any=false
        for _,p in pairs(parts) do any=any or p.worn~=nil end
        if not any then parts,eve_path={},nil end -- Nothing worn: her head as it is now.
        if eve then pcall(capture,eve) end
        if not eve_path then return '' end
        local f={eve_path}
        for _,n in ipairs(NAMES) do
            local p=parts[n]
            if p then
                f[#f+1]=encode(n,p.worn and (p.worn.hidden and '-' or '+') or '',p.own)
            end
        end
        return table.concat(f,'|')
    end

    -- list: {{fit=, slot=}}; {} gives her own head back. The same list again changes nothing.
    function self.wear(choices)
        local before=list
        local function words(l)
            local w={}
            for _,c in ipairs(l) do w[#w+1]=c.fit..':'..c.slot end
            return table.concat(w,' ')
        end
        list=choices or {}
        -- A new list starts the fight count again; the dress's mix again with the same list does not.
        if words(list)~=words(before) then stopped,fights,wrong=false,{},0 end
        if #list==0 then return self.give_back() end
        local eve=her()
        if not eve then list=before; return nil,'no EVE in the world' end
        local ok,changed=dress_up(eve)
        if not ok then list=before; return nil,changed end
        if changed then applied=applied+1 end
        return true
    end

    -- The component(s) wearing fit (a stock ponytail following that hair among them) put on again: its materials only
    -- while its mesh shows.
    function self.rewear(fit)
        local eve=her()
        if not eve then return nil,'no EVE in the world' end
        local force={}
        for _,choice in ipairs(list) do
            if choice.fit==fit then
                force[choice.slot=='Hair' and HAIR or PONY]=true
                if choice.slot=='Hair' then force[PONY]=true end
            end
        end
        if not next(force) then return nil,fit..' is not worn' end
        local ok,why=dress_up(eve,force)
        if not ok then return nil,why end
        applied=applied+1
        return true
    end

    function self.give_back()
        local lines,failed={},nil
        for _,n in ipairs(NAMES) do
            local p=parts[n]
            if p and p.worn then
                local ok,w=pcall(take_off,n,p)
                lines[#lines+1]=ok and w or n..' not given back: '..tostring(w)
                if not ok then failed=lines[#lines] end
            end
        end
        parts,eve_path,list=({}),nil,{} -- Read again before the next change; nothing to rewear.
        if not lines[1] then return true end
        applied=applied+1
        log('head: off: '..table.concat(lines,'; '))
        if failed then return nil,failed end
        return true
    end

    -- The meshes and materials of every head fit known now (the dress reads the packs before its restore):
    -- {[path]=true} each, and how many fits.
    local function known_assets()
        local meshes,materials,count={},{},0
        for _,slot in ipairs({'Hair','Ponytail'}) do
            for _,id in ipairs(fits.heads and fits.heads(slot) or {}) do
                local fit=fits.get(id)
                if fit then
                    count=count+1
                    for _,v in ipairs(fit.Variants or {{Mesh=fit.Mesh,Materials=fit.Materials}}) do
                        if v.Mesh and v.Mesh~='' then meshes[v.Mesh]=true end
                        for _,m in ipairs(v.Materials or {}) do if m~='' then materials[m]=true end end
                    end
                end
            end
        end
        return meshes,materials,count
    end
    -- Whether c wears a head fit's material on a slot where the game's own look (own) had another.
    local function painted(c,own,materials)
        local before,found={},false
        for _,m in ipairs(own.materials) do before[m.slot]=m.base end
        each(c.OverrideMaterials,function(index,m)
            m=valid(m)
            local base=m and path_of(base_of(m))
            found=found or (base~=nil and materials[base]==true and before[index-1]~=base)
        end)
        return found
    end

    -- An earlier Lua load's leftovers (field 6 of its file): only a component marked worn ('+') or hidden ('-') is
    -- looked at. A '+' one is the closet's while it wears a head fit's mesh other than its own or a head fit's material
    -- on its own mesh; a '-' one while it is still hidden. That one gets the game's own look back; any other is left.
    function self.restore(field)
        if not field or field=='' then return end
        local f={}
        for x in (field..'|'):gmatch('([^|]*)|') do f[#f+1]=x end
        local meshes,materials,count=known_assets()
        if count==0 then
            log('head: restore from coop-closet.txt: no head fit is known (the catalogue is not read): the head is '
                ..'left as it is')
            return
        end
        local eve=U.her(valid(StaticFindObject(f[1])))
        local cs=eve and components(eve) or {}
        local lines={}
        for i=2,#f do
            local n,state,own=decode(f[i])
            local c=cs[n]
            local ours=false
            if c and state=='-' then ours=visible(c)~=own.visible
            elseif c and state=='+' then
                local now=mesh_of(c)
                ours=(now~=own.mesh and meshes[now]==true) or (now==own.mesh and painted(c,own,materials))
            end
            if ours then
                local ok,missed=pcall(give_back,c,n,own)
                lines[#lines+1]=ok and n..' back'..(#missed>0 and ' ('..table.concat(missed,', ')..' not found)' or '')
                    or n..' not given back: '..tostring(missed)
            elseif state~='' then
                lines[#lines+1]=n..': nothing to give back'
            end
        end
        if lines[1] then log('head: restore from coop-closet.txt: '..table.concat(lines,'; ')) end
    end

    -- {{c=, fit=, mesh=, slots={[index]=<Slot id>}, head=true}} for each shown piece.
    function self.parts()
        local out={}
        for _,n in ipairs(NAMES) do
            local p=parts[n]
            local w=p and p.worn
            if w and not w.hidden then
                local slots={}
                for i=0,(w.count or 0)-1 do slots[i]=w.slot end
                out[#out+1]={c=Doro.same(p.c,p.c_path),fit=w.fit,mesh=w.mesh,slots=slots,head=true}
            end
        end
        return out
    end

    -- Once a second while a piece is worn (see the header).
    local function check(now)
        local eve=her()
        if not eve then return end -- A load: the pieces wait for her.
        local new_eve=path_of(eve)~=eve_path
        local changed={}
        for _,n in ipairs(NAMES) do
            local p=parts[n]
            if p and p.worn and (new_eve or not holds(n,p)) then changed[n]=true end
        end
        if not next(changed) then wrong=0; return end
        wrong=wrong+1
        if wrong<2 then return end
        wrong=0
        fights[#fights+1]=now
        while now-fights[1]>Head.FIGHT.within do table.remove(fights,1) end
        local c=not new_eve and parts[HAIR] and Doro.same(parts[HAIR].c,parts[HAIR].c_path)
        local what=c and mesh_of(c) or 'a new EVE'
        if #fights>=Head.FIGHT.mixes then
            stopped,fights=true,{}
            log('something outside keeps changing her hair ('..tostring(what)..'): the closet leaves it until the '
                ..'next wear')
            return
        end
        if not new_eve then -- A new EVE: capture reads her own components afresh, the old ones are never called.
            for n in pairs(changed) do
                local p=parts[n]
                local cc=Doro.same(p.c,p.c_path)
                if cc then p.worn.own=p.own; p.own=read(cc,n,p.worn); p.worn=nil
                else parts[n]=nil end -- Its component is gone: capture reads the new one afresh.
            end
        end
        local ok,why=dress_up(eve,changed)
        if ok then
            applied=applied+1
            log('the game changed her head ('..tostring(what)..'): the closet\'s pieces again')
        else
            log('head: not worn again: '..tostring(why))
        end
    end
    function self.tick()
        if stopped or #list==0 then return end
        local now=clock()
        if now<due then return end
        due=now+1
        if paused() then return end
        local ok,why=pcall(check,now)
        if not ok then log('head: the watchdog failed: '..tostring(why)) end
    end
    function self.stop()
        self.give_back()
        list,stopped={},false
    end
    function self.applied() return applied end
    function self.worn()
        local out,any={},false
        for _,p in pairs(parts) do any=any or p.worn~=nil end
        if not any then return out end
        for _,choice in ipairs(list) do out[choice.fit]=choice.slot end
        return out
    end
    return self
end

return Head
