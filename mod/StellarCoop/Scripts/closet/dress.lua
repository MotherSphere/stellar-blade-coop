-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop closet wear: pieces of several CNS-format outfits worn at once on EVE, by fit map (closet/fits.lua). Display
-- only: her equipment, inventory and saves are never read or written. Built on the Phase 0 spike's tested way
-- (Stellar-Closet repository, spike/, 25 Nov 2026):
--   - The outfit that supplies the shoes goes on her body mesh (eve.Mesh, the animation leader), with its own skin:
--     its feet are the ones its shoes were shaped around. It shows its skin and its chosen pieces only.
--   - Each other outfit goes on one added SkeletalMeshComponent, attached to the body and following its pose
--     (SetMasterPoseComponent), with no collision. It shows its chosen pieces only. So the friend's ghost pays one
--     part per extra outfit, however many of its pieces are worn.
--   - A skin slot whose every region a worn piece covers (a piece's Covers) is hidden too.
--   - Sections are hidden on every LOD; the ghost's capture reads LOD 0.
-- Before the first change, her own body mesh and overridden materials go into coop-closet.txt (link.store), with the
-- worn choices as console words, so coop closet off, coop off and the next Lua load (at its first tick) give her look
-- back and remove the added meshes.
-- Once a second (tick), unless the game is paused or shows one of its screens: a body mesh in GAME_LOOKS (Tachy Mode's
-- suit) pauses the mix (the added meshes hidden) until it goes; any other changed look for 2 s (a map load, a game
-- reset) gets the mix again; a hidden section the game showed again (Tachy Mode's end) is hidden again.
-- The resolve (find, LoadAsset, AssetRegistryHelpers:GetAsset for a mod pack's asset) and the skeleton guard are copies
-- of online/partner/puppet.lua's (resolve and its SetSkeletalMesh guard).
local UE=require('UEHelpers')
local U=require('core.unreal')
local Fits=require('closet.fits')
local Slots=require('closet.slots')
local valid,each,text=U.valid,U.each,U.text
local Dress={}
local SKINNED,MID='/Script/Engine.SkeletalMeshComponent','/Script/Engine.MaterialInstanceDynamic'
-- Body meshes the game puts on EVE that pause the mix while they are on: Tachy Mode's suit (seen in the spike's
-- UE4SS.log at 11:33 and 11:39 on 25 Nov 2026, the mix paused and back as it ended).
Dress.GAME_LOOKS={['/Game/Art/Character/PC/CH_P_EVE_10/CH_P_EVE_10.CH_P_EVE_10']=true}
Dress.USE='Use: coop closet wear <fit>[:<Slot>,<Slot>...] [<fit>[:...]] | coop closet off | coop closet fits'
-- Tries of restore's wear of the kept look while EVE spawns, a second apart, before it is dropped.
Dress.RETRIES=5

local function path_of(o)
    local ok,full=pcall(function() return text(o:GetFullName()) end)
    return ok and full and full:match('^%S+ (.+)$') or nil
end
local function her() return U.her(valid(UE.GetPlayer())) end
-- An asset by object path: in memory, else LoadAsset (the cooked registry), else the asset registry helpers' GetAsset
-- (a mod pack's asset that the cooked registry does not list). Copy of online/partner/puppet.lua's resolve.
local function resolve(path)
    local o=valid(StaticFindObject(path))
    if o then return o end
    if type(LoadAsset)=='function' then
        pcall(LoadAsset,path)
        o=valid(StaticFindObject(path))
        if o then return o end
    end
    local ok,got=pcall(function()
        local helpers=StaticFindObject('/Script/AssetRegistry.Default__AssetRegistryHelpers')
        return helpers:GetAsset({ObjectPath=FName(path)})
    end)
    return ok and valid(got) or nil
end
-- A mesh safe for SetSkeletalMesh, which reads its Skeleton unchecked: a null one is an access violation no pcall
-- catches. Copy of online/partner/puppet.lua's guard.
local function usable(path)
    local mesh=resolve(path)
    if not mesh then return nil,path..' not found' end
    local ok,skeleton=pcall(function() return mesh.Skeleton end)
    if not (ok and valid(skeleton)) then return nil,path..' has no skeleton' end
    return mesh
end
local function lods(c)
    local ok,n=pcall(function() return c:GetNumLODs() end)
    return ok and n and n>0 and n or 1
end
local function show_only(c,count,show)
    for lod=0,lods(c)-1 do
        pcall(function() c:ShowAllMaterialSections(lod) end)
        for i=0,count-1 do
            if not show[i] then pcall(function() c:ShowMaterialSection(i,0,false,lod) end) end
        end
    end
end
-- The sections of c the mix hid that it shows at LOD 0 again.
local function shown_again(c,count,show)
    local out={}
    for i=0,count-1 do
        if not show[i] then
            local ok,shown=pcall(function() return c:IsMaterialSectionShown(i,0) end)
            if ok and shown==true then out[#out+1]=i end
        end
    end
    return out
end
-- The mesh's own material per slot, 0-based, and the slot count.
local function own_materials(mesh)
    local out,n={},0
    each(mesh.Materials,function(index,slot)
        out[index-1]=valid(slot.MaterialInterface)
        n=math.max(n,index)
    end)
    return out,n
end
-- The material on each slot of a component now, as an asset path (a dynamic one as its parent).
local function current_materials(c)
    local out={}
    local ok,n=pcall(function() return c:GetNumMaterials() end)
    for i=0,(ok and n or 0)-1 do
        local m=valid(c:GetMaterial(i))
        for _=1,4 do
            if not (m and m:IsA(StaticFindObject(MID))) then break end
            m=valid(m.Parent)
        end
        out[#out+1]=i..'='..(m and path_of(m) or '')
    end
    return table.concat(out,',')
end

-- The plan for a list of choices {{fit=<UniqueFitID>, slots=<list of Slot ids, or nil for every piece it shows by
-- default>}}: {body={fit,mesh,show,count?}, added={{fit,mesh,show}}, pieces=n, parts=<added meshes>} or nil and why.
-- Pure: no engine call. The fit that supplies Shoes goes on the body, else the first.
function Dress.plan(choices,fits)
    fits=fits or Fits
    if #choices==0 then return nil,'nothing to wear' end
    local taken,by_fit,order={},{},{}
    for _,choice in ipairs(choices) do
        local fit=fits.get(choice.fit)
        if not fit then return nil,'no fit map for '..tostring(choice.fit) end
        if by_fit[choice.fit] then return nil,choice.fit..' named twice' end
        local pieces={}
        if choice.slots then
            for _,slot in ipairs(choice.slots) do
                if not Slots.known(slot) then return nil,'unknown slot '..tostring(slot) end
                local piece=fits.piece(choice.fit,slot)
                if not piece then return nil,choice.fit..' has no '..slot end
                pieces[#pieces+1]=piece
            end
        else
            for _,piece in ipairs(fit.Pieces) do if not piece.Off then pieces[#pieces+1]=piece end end
        end
        for _,piece in ipairs(pieces) do
            for _,slot in ipairs({piece.Slot,table.unpack(piece.Occupies or {})}) do
                if taken[slot] then return nil,slot..' is worn twice ('..taken[slot]..' and '..choice.fit..')' end
                taken[slot]=choice.fit
            end
        end
        by_fit[choice.fit]={fit=choice.fit,map=fit,pieces=pieces}
        order[#order+1]=by_fit[choice.fit]
    end
    local body=order[1]
    if taken.Shoes then body=by_fit[taken.Shoes] end
    -- Regions the worn pieces cover: a body skin slot all of whose regions are covered is hidden.
    local covered={}
    for _,o in ipairs(order) do
        for _,piece in ipairs(o.pieces) do
            for _,region in ipairs(piece.Covers or {}) do covered[region]=true end
        end
    end
    local plan={added={},pieces=0}
    for _,o in ipairs(order) do
        local show={}
        for _,piece in ipairs(o.pieces) do
            for _,index in ipairs(piece.Materials) do show[index]=true end
            plan.pieces=plan.pieces+1
        end
        if o==body then
            for index,regions in pairs(o.map.Skin) do
                local all=#regions>0
                for _,region in ipairs(regions) do all=all and covered[region]==true end
                if not all then show[index]=true end
            end
            plan.body={fit=o.fit,mesh=o.map.Mesh,show=show}
        else
            plan.added[#plan.added+1]={fit=o.fit,mesh=o.map.Mesh,show=show}
        end
    end
    plan.parts=#plan.added
    return plan
end

-- "fit:Slot,Slot fit2" -> choices, or nil and why.
function Dress.parse(words)
    local choices={}
    for _,word in ipairs(words) do
        local fit,slots=word:match('^([%w_%.%-]+):([%w,]+)$')
        if fit then
            local list={}
            for slot in slots:gmatch('[^,]+') do list[#list+1]=slot end
            choices[#choices+1]={fit=fit,slots=list}
        elseif word:match('^[%w_%.%-]+$') then
            choices[#choices+1]={fit=word}
        else
            return nil,Dress.USE
        end
    end
    return choices
end
-- choices -> "fit:Slot,Slot fit2", the words parse reads back (split on spaces).
function Dress.words(choices)
    local out={}
    for _,c in ipairs(choices) do
        out[#out+1]=c.slots and c.fit..':'..table.concat(c.slots,',') or c.fit
    end
    return table.concat(out,' ')
end

function Dress.new(o)
    local log=o.log
    local store=o.store or {save=function() end,load=function() end,clear=function() end}
    local paused=o.paused or function() return false end
    local fits=o.fits or Fits
    local clock=o.clock or os.clock
    local self={}
    local state -- While a mix is on: {plan=, eve_path=, own=<mesh path>, materials=<line>, added={c,count,show},
                -- count=, paused=, wrong=}
    local restored,due=false,0
    local pending,tries,retry_at=nil,0,0 -- The kept line's fields once read; restore's failed wears; its next try.
    local kept_fields,undo_kept -- Set with restore below; off uses them too.

    local function keep()
        if not state then return store.clear() end
        local added={}
        for _,a in ipairs(state.added) do added[#added+1]=a.mesh end
        return store.save(table.concat({state.eve_path or '',state.own or '',state.materials or '',
            table.concat(added,';'),Dress.words(state.choices or {})},'\t'))
    end
    -- Removes every component on EVE but her body that wears one of the given mesh paths: ours, also one an earlier
    -- mix or Lua load left (a map load can make the game set her body twice, and each change got the mix again).
    local function sweep(eve,paths)
        local body=valid(eve.Mesh)
        local removed=0
        local wanted={}
        for _,p in ipairs(paths) do wanted[p]=true end
        each(eve:K2_GetComponentsByClass(StaticFindObject(SKINNED)),function(_,c)
            c=valid(c)
            local mesh=c and valid(c.SkeletalMesh)
            if c and mesh and c~=body and wanted[path_of(mesh)] then
                pcall(function() c:K2_DestroyComponent(c) end)
                removed=removed+1
            end
        end)
        return removed
    end
    -- Removes the added components wearing the given mesh paths and gives the body its own mesh and materials back.
    local function give_back(eve,own,materials,added_paths)
        local body=valid(eve.Mesh)
        local removed=sweep(eve,added_paths)
        if body and own and own~='' then
            local mesh=usable(own)
            if mesh then
                body:SetSkeletalMesh(mesh,true)
                for slot,p in (materials or ''):gmatch('(%d+)=([^,]*)') do
                    local m=p~='' and resolve(p)
                    if m then pcall(function() body:SetMaterial(tonumber(slot),m) end) end
                end
                for lod=0,lods(body)-1 do pcall(function() body:ShowAllMaterialSections(lod) end) end
            end
        end
        return removed
    end

    local function apply(plan,choices)
        local eve=her()
        if not eve then return nil,'no EVE in the world' end
        local body=valid(eve.Mesh)
        if not body then return nil,'EVE has no body mesh' end
        local body_mesh,why=usable(plan.body.mesh)
        if not body_mesh then return nil,why end
        local added_meshes={}
        for i,a in ipairs(plan.added) do
            added_meshes[i],why=usable(a.mesh)
            if not added_meshes[i] then return nil,why end
        end
        -- Her own look first, kept across a mix that changes (the first mix's).
        local own,materials=state and state.own,state and state.materials
        -- No added mesh of an earlier mix stays: the old one's and this plan's outfits are swept off EVE first.
        local paths={}
        for _,a in ipairs(state and state.added or {}) do paths[#paths+1]=a.mesh end
        for _,a in ipairs(plan.added) do paths[#paths+1]=a.mesh end
        sweep(eve,paths)
        if not state then
            local mesh=valid(body.SkeletalMesh)
            own,materials=mesh and path_of(mesh) or '',current_materials(body)
        end
        state={plan=plan,choices=choices,eve_path=path_of(eve),own=own,materials=materials,added={},paused=false,
            wrong=0}
        for _,a in ipairs(plan.added) do state.added[#state.added+1]={mesh=a.mesh} end
        local saved,e=keep()
        if saved==false then state=nil; return nil,'coop-closet.txt not written: '..tostring(e) end
        local mats,count=own_materials(body_mesh)
        body:SetSkeletalMesh(body_mesh,true)
        for i=0,count-1 do
            if mats[i] then pcall(function() body:SetMaterial(i,mats[i]) end) end
        end
        show_only(body,count,plan.body.show)
        state.count=count
        for i,a in ipairs(plan.added) do
            local c=valid(eve:AddComponentByClass(StaticFindObject(SKINNED),true,
                {Translation={X=0,Y=0,Z=0},Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}},false))
            if not c then
                self.off()
                return nil,'could not add a mesh to EVE: her own look is back'
            end
            pcall(function() c:SetCollisionEnabled(0) end) -- Never blocks her capsule, the camera or the floor.
            c:K2_AttachToComponent(body,FName('None'),2,2,2,true)
            c:SetSkeletalMesh(added_meshes[i],true)
            c:SetMasterPoseComponent(body,true)
            pcall(function() c.bUseBoundsFromMasterPoseComponent=true end) -- No culling pop.
            local _,n=own_materials(added_meshes[i])
            show_only(c,n,a.show)
            state.added[i]={mesh=a.mesh,c=c,count=n,show=a.show}
        end
        return true
    end

    -- coop closet wear: the plan for choices, put on now.
    function self.wear(choices)
        self.restore()
        local plan,why=Dress.plan(choices,fits)
        if not plan then return false,why end
        local ok,e=apply(plan,choices)
        if not ok then return false,e end
        local names={}
        for _,c in ipairs(choices) do names[#names+1]=c.fit end
        local line=string.format('closet: %d pieces of %s; body %s, %d added mesh%s', plan.pieces,
            table.concat(names,' + '),plan.body.fit,plan.parts,plan.parts==1 and '' or 'es')
        log(line)
        return true,line
    end
    -- coop closet off and coop off: her own look back, the added meshes gone, the file cleared.
    function self.off()
        if not state and not restored then -- A kept look not worn again yet: dropped, its leftovers off EVE.
            local f=kept_fields()
            local found,eve=pcall(her)
            if #f>0 and found and eve then pcall(undo_kept,eve,f) end
            restored,pending=true,{}
            if #f>0 then
                store.clear()
                log('off: the kept look is dropped')
                return true,'closet: off'
            end
        end
        if not state then return true,'closet: nothing worn' end
        local eve=her()
        local paths={}
        for _,a in ipairs(state.added) do paths[#paths+1]=a.mesh end
        local removed=eve and give_back(eve,state.own,state.materials,paths) or 0
        state=nil
        keep()
        log('off: her own look back, '..removed..' added mesh(es) removed')
        return true,'closet: off'
    end
    self.stop=self.off
    -- The kept line's fields, read once (the title screen calls restore each frame while it waits for EVE).
    function kept_fields()
        if pending==nil then
            pending={}
            local line=store.load() or ''
            if line~='' then for x in (line..'\t'):gmatch('([^\t]*)\t') do pending[#pending+1]=x end end
        end
        return pending
    end
    -- Whether a mesh path is one a fit map puts on her body: her body still wears an earlier mix.
    local function closet_mesh(path)
        for _,fit in pairs(fits.BY_ID or {}) do if fit.Mesh==path then return true end end
        return false
    end
    -- An earlier mix's leftovers off EVE: its added meshes, and her own look from the file when her body still wears
    -- a closet mesh (a Lua reload). On a new game she wears the game's look, which stays hers.
    function undo_kept(eve,f)
        local paths={}
        for p in (f[4] or ''):gmatch('[^;]+') do paths[#paths+1]=p end
        local body=valid(eve.Mesh)
        local mesh=body and valid(body.SkeletalMesh)
        if mesh and closet_mesh(path_of(mesh)) then return give_back(eve,f[2],f[3],paths) end
        return sweep(eve,paths)
    end
    local function done(clear,line)
        restored,pending=true,{}
        if clear then store.clear() end
        log('restore from coop-closet.txt: '..line)
    end
    -- What an earlier Lua load or game left: its leftovers off EVE (undo_kept), then the kept choices worn again (the
    -- file rewritten), or the file goes when there are none or they cannot be worn. It waits, the file untouched,
    -- while there is no EVE (the title screen) or the game is paused or shows one of its screens (a loading screen).
    -- A wear that fails while she spawns is tried again once a second, RETRIES times. On the game thread (a tick, or
    -- a command).
    function self.restore()
        if restored then return end
        local f=kept_fields()
        if #f==0 then restored=true; return end
        if paused() then return end
        local found,eve=pcall(her)
        if not (found and eve) then return end
        local now=clock()
        if now<retry_at then return end
        local ok,removed=pcall(undo_kept,eve,f)
        local kept=f[5] or ''
        if kept=='' then
            return done(true,ok and (removed..' added mesh(es) removed, her own look back') or tostring(removed))
        end
        local words={}
        for x in kept:gmatch('%S+') do words[#words+1]=x end
        local choices,why=Dress.parse(words)
        local plan
        if choices then plan,why=Dress.plan(choices,fits) end
        if not plan then return done(true,'could not wear '..kept..' again: '..tostring(why)) end
        local ran,worn,e=pcall(apply,plan,choices)
        if ran and worn then return done(false,'worn again: '..kept) end
        tries=tries+1
        if tries<Dress.RETRIES then retry_at=now+1; return end
        done(not state,'could not wear '..kept..' again after '..tries..' tries: '..tostring(ran and e or worn))
    end
    -- Once a second at most, on the game thread: the watchdog.
    function self.tick()
        if not restored then self.restore() end
        if not state or paused() then return end
        local now=clock()
        if now<due then return end
        due=now+1
        local eve=her()
        if not eve then return end -- Loading: no EVE yet.
        local body=valid(eve.Mesh)
        local mesh=body and valid(body.SkeletalMesh)
        local path=mesh and path_of(mesh)
        if path and Dress.GAME_LOOKS[path] then
            state.wrong=0
            if not state.paused then
                state.paused=true
                for _,a in ipairs(state.added) do
                    if valid(a.c) then pcall(function() a.c:SetHiddenInGame(true,false) end) end
                end
                log('the game put '..path..' on EVE: mix paused')
            end
            return
        end
        local was_paused=state.paused
        if was_paused then
            state.paused=false
            for _,a in ipairs(state.added) do
                if valid(a.c) then pcall(function() a.c:SetHiddenInGame(false,false) end) end
            end
        end
        local intact=path==state.plan.body.mesh
        for _,a in ipairs(state.added) do intact=intact and valid(a.c)~=nil end
        if not intact then
            state.wrong=state.wrong+1
            if state.wrong<2 and not was_paused then return end
            log(string.format('the game changed EVE (body %s): mix again',tostring(path)))
            local plan,choices=state.plan,state.choices
            state.own,state.materials=path or state.own,body and current_materials(body) or state.materials
            local own,materials=state.own,state.materials
            state=nil
            local ok,why=apply(plan,choices)
            if ok then state.own,state.materials=own,materials; keep()
            else log('mix again failed: '..tostring(why)) end
            return
        end
        state.wrong=0
        local back=shown_again(body,state.count,state.plan.body.show)
        for _,a in ipairs(state.added) do
            local more=shown_again(a.c,a.count,a.show)
            if #more>0 then show_only(a.c,a.count,a.show); back[#back+1]=a.mesh..':'..table.concat(more,',') end
        end
        if #back>0 then
            show_only(body,state.count,state.plan.body.show)
            log('the game showed hidden sections again: hidden again ('..table.concat(back,' ')..')')
        end
    end
    function self.status()
        if not state then return 'closet: nothing worn' end
        local p=state.plan
        return string.format('closet: %d pieces, body %s, %d added mesh%s%s',p.pieces,p.body.fit,p.parts,
            p.parts==1 and '' or 'es',state.paused and ', paused (a game look is on)' or '')
    end
    function self.worn() return state~=nil end
    return self
end

return Dress
