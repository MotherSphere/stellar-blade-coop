-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Copies online/partner/puppet.lua's resolve (find, LoadAsset, AssetRegistryHelpers:GetAsset for a mod pack's asset)
-- and its SetSkeletalMesh skeleton guard (usable).
-- coop closet wear: pieces of several CNS-format outfits worn at once on EVE, by fit map (closet/fits.lua). Display
-- only: her equipment, inventory and saves are never read or written. It works this way, tried in game on 25 Nov
-- 2026:
--   - One outfit goes on her body mesh (eve.Mesh, the animation leader), with its own skin. It shows its skin and its
--     chosen pieces only. The body is the one picked (<fit>:BaseBody), else the body rule's (Dress.plan): by default
--     the outfit that supplies the shoes (its feet are the ones its shoes were shaped around), else the first, unless
--     its skin cannot hide a region another outfit's piece covers; then the look's outfit whose skin hides the most.
--     The switch is computed at each wear: coop-closet.txt keeps the picks only.
--   - Each other outfit goes on one added SkeletalMeshComponent, attached to the body and following its pose
--     (SetMasterPoseComponent), with no collision. It shows its chosen pieces only. So the friend's ghost pays one
--     part per extra outfit, however many of its pieces are worn.
--   - A skin slot whose every region a worn piece covers (a piece's Covers) is hidden too. Fingernails and Toenails
--     pieces are hidden under a piece of another outfit that covers the hands or feet.
--   - Sections are hidden on every LOD; the ghost's capture reads LOD 0.
--   - An installed pack's suit worn whole (a Whole fit of closet/fits.lua, the Full outfit tab) shows every section
--     of its mesh but its HiddenMats and the toggles off by default (Fits.shows). Its mesh resolves by path as above.
--     The options layer's toggles (closet/options.lua, o.toggles) go over the pack's at each plan; its variant's
--     Materials and Parameters go on the mesh (wear_variant). reshow shows a toggle change on the same meshes, again
--     puts a new variant on.
-- Before the first change, her own body mesh and overridden materials go into coop-closet.txt (link.store), with the
-- worn choices as console words, so coop closet off, coop off and the next Lua load (at its first tick) give her look
-- back and remove the added meshes.
-- Once a second (tick), unless the game is paused or shows one of its screens: a body mesh in GAME_LOOKS (Tachy Mode's
-- suit) pauses the mix (the added meshes hidden) until it goes; any other changed look for 2 s (a map load, a game
-- reset, CNS) gets the mix again; a hidden section the game showed again (Tachy Mode's end) is hidden again. The body
-- mesh put on from outside becomes her own look, which off gives back; a closet mesh never does. The closet's own
-- changes (wear, preview, revert) set the plan the watchdog compares with, so they never count. After off nothing is
-- watched until the next wear. An outside fight (FIGHT: something undoes every mix) ends. When the look holds the
-- outside body's outfit and no body is picked, that outfit is worn as the body. Otherwise the mix stops until the next
-- wear or preview, with its added meshes hidden. Her body is never removed.
-- Preview (the closet menu's live look): preview(choices) puts a look on without saving it. The first call remembers the
-- confirmed choices (state.kept, false when none). During a preview coop-closet.txt holds EVE's leftovers to sweep and
-- the confirmed words, so a reload gives the confirmed look. confirm() saves the previewed look, revert() wears the
-- confirmed one again (her own look when none). wear and off end a preview. preview({}) while a look is on previews
-- her own look; confirm() of it clears the file, as off does.
-- wear and preview refuse while o.busy() names SBO's own state that holds EVE's body (closet/wiring.lua: the bike
-- ride, the Doro look, the rifle out, an emote, a coop wear suit): its key, then the words for the line.
local UE=require('UEHelpers')
local U=require('core.unreal')
local Fits=require('closet.fits')
local Slots=require('closet.slots')
local valid,each,text=U.valid,U.each,U.text
local Dress={}
local SKINNED,MID='/Script/Engine.SkeletalMeshComponent','/Script/Engine.MaterialInstanceDynamic'
-- Body meshes the game puts on EVE that pause the mix while they are on: Tachy Mode's suit (seen in UE4SS.log at
-- 11:33 and 11:39 on 25 Nov 2026, the mix paused and back as it ended).
Dress.GAME_LOOKS={['/Game/Art/Character/PC/CH_P_EVE_10/CH_P_EVE_10.CH_P_EVE_10']=true}
Dress.USE='Use: coop closet wear <fit>[:<Slot>,<Slot>...] [<fit>[:...]] | coop closet off | coop closet fits'
local installed_cache={} -- mesh path -> whether it loads; once per path per Lua load (installed, loads).
-- Tries of restore's wear of the kept look while EVE spawns, a second apart, before it is dropped.
Dress.RETRIES=5
-- An outside fight: this many mixes again within this many seconds (something undoes every mix: CNS put Ocean Maid's
-- mesh back on her body each second on 26 Nov 2026). A map load sets her body twice or three times, never five.
Dress.FIGHT={mixes=5,within=15}

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
-- USkinnedMeshComponent.GetNumLODs (Ghidra, build 26123051: native entry 0x14665f090, exec 0x14492ae50; table
-- 0x14665efd0 of /Script/Engine SkinnedMeshComponent, FUN_14492b9e0).
local function lods(c)
    local ok,n=pcall(function() return c:GetNumLODs() end)
    return ok and n and n>0 and n or 1
end
-- ShowMaterialSection(MaterialID, SectionIndex, bShow, LODIndex): Ghidra, build 26123051, native table entry
-- 0x14665f240 (name 0x14665bad8) -> exec 0x144927700 -> FUN_14412c640. A SectionIndex >= 0 inside the LOD's
-- LODMaterialMap replaces MaterialID with that map entry; -1 skips the remap, so the material slot itself is hidden.
local function show_only(c,count,show)
    for lod=0,lods(c)-1 do
        pcall(function() c:ShowAllMaterialSections(lod) end)
        for i=0,count-1 do
            if not show[i] then pcall(function() c:ShowMaterialSection(i,-1,false,lod) end) end
        end
    end
end
-- The sections of c the mix hid that it shows at LOD 0 again.
-- IsMaterialSectionShown(MaterialID, LODIndex) takes no SectionIndex: Ghidra, build 26123051, native table entry
-- 0x14665f110 (name 0x14665bf58) -> exec 0x144927490 reads LODInfo[LODIndex] (component +0x798, 0x48 a LOD) and
-- answers not HiddenMaterials[MaterialID], with no LODMaterialMap remap. So (i,0) is slot i at LOD 0, as written.
-- closet/thumbs.lua's capture rig loads its meshes and shows its sections the same way.
Dress.usable,Dress.show_only=usable,show_only
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
-- The slots of c whose override holds a material, 0-based: OverrideMaterials, UMeshComponent's TArray at +0x538
-- (Ghidra, build 26123051: property params 0x1465e6df0, name 0x1459c08d8, Num at +0x540).
local function overridden(c)
    local out={}
    pcall(function() each(c.OverrideMaterials,function(index,m) if valid(m) then out[#out+1]=index-1 end end) end)
    return out
end
-- Every override of c taken off: SetMaterial with nil (UE4SS passes nil as a null object) stores a null entry, so the
-- slot shows its mesh's own material and the ghost's capture (online/partner/capture.lua, which sends the first 16
-- overrides that hold a material) skips it.
local function clear(c)
    for _,i in ipairs(overridden(c)) do pcall(function() c:SetMaterial(i,nil) end) end
end
-- The values set on dynamic instances, nearest instance first and each name once per kind: {{kind='Vector'|'Scalar'|
-- 'Texture', name=<text>, value=}}. Ghidra, build 26123051: UMaterialInstance's ScalarParameterValues (+0xe0, property
-- params 0x1465d9fe8), VectorParameterValues (+0xf0, 0x1465da110) and TextureParameterValues (+0x100, 0x1465da0b0);
-- each value is ParameterInfo (+0, MaterialParameterInfo, whose Name is its FName at +0) and ParameterValue (+0x10: a
-- LinearColor, a float or a Texture).
local VALUES={{'Vector','VectorParameterValues'},{'Scalar','ScalarParameterValues'},{'Texture','TextureParameterValues'}}
local function values_of(levels)
    local out,seen={},{}
    for _,mid in ipairs(levels) do
        for _,list in ipairs(VALUES) do
            local kind=list[1]
            pcall(function()
                each(mid[list[2]],function(_,v)
                    local name=text(U.value_of(v.ParameterInfo).Name)
                    local x=U.value_of(v.ParameterValue)
                    if kind=='Vector' then x={R=x.R,G=x.G,B=x.B,A=x.A} elseif kind=='Texture' then x=valid(x) end
                    if x~=nil and not seen[kind..name] then
                        seen[kind..name]=true
                        out[#out+1]={kind=kind,name=name,value=x}
                    end
                end)
            end)
        end
    end
    return out
end
-- Her overridden slots now, as 'slot=path' words split by commas: each override that is not the mesh's own material on
-- that slot, a dynamic one as its parent asset (MaterialInstance.Parent, +0xd0, property params 0x1465da3f0). A slot
-- with no override needs no word: it shows the mesh's own. dynamic (a table, or nil): each dynamic slot's values
-- (values_of), so give_back makes the instance again with them.
local function current_materials(c,dynamic)
    local mesh=valid(c.SkeletalMesh)
    local own=mesh and own_materials(mesh) or {}
    local out={}
    for _,i in ipairs(overridden(c)) do
        local m=valid(c:GetMaterial(i))
        local levels={}
        for _=1,4 do
            if not (m and m:IsA(StaticFindObject(MID))) then break end
            levels[#levels+1]=m
            m=valid(m.Parent)
        end
        local p=m and path_of(m) or ''
        if #levels>0 or p~=(own[i] and path_of(own[i]) or '') then
            out[#out+1]=i..'='..p
            if #levels>0 and dynamic then dynamic[i]=values_of(levels) end
        end
    end
    return table.concat(out,',')
end

-- The body rules of Dress.plan: auto (the switch below), shoes (the Shoes' outfit, else the first), first (the first
-- choice). A fit id with Skin forces that body. On 26 Nov 2026 the rule was not tried in game yet.
Dress.BODY_MODES={'auto','shoes','first'}
local NAILS={Fingernails='Hand',Toenails='Foot'} -- Hidden under a covering piece of another outfit.
-- Whether a skin slot can be hidden: each of its regions is covered.
local function hidden(regions,covered)
    local all=#regions>0
    for _,region in ipairs(regions) do all=all and covered[region]~=nil end
    return all
end
-- Whether a piece of an outfit other than fit covers the region.
local function foreign(covered,region,fit)
    for by in pairs(covered[region] or {}) do if by~=fit then return true end end
    return false
end
-- An outfit worn as the body: the regions another outfit's piece covers that its skin keeps showing (Slots.REGIONS
-- order), and how many covered regions it hides. Its own pieces were made over its own skin: they never clip.
local function skin_of(o,covered)
    local clips,hides={},0
    for _,region in ipairs(Slots.REGIONS) do
        for _,regions in pairs(covered[region] and o.map.Skin or {}) do
            for _,r in ipairs(regions) do
                if r==region and hidden(regions,covered) then hides=hides+1
                elseif r==region and foreign(covered,region,o.fit) then clips[#clips+1]=region end
            end
        end
    end
    return clips,hides
end

-- The plan for a list of choices {{fit=<UniqueFitID>, slots=<list of Slot ids, or nil for every piece it shows by
-- default>}}: {body={fit,mesh,show,slots}, added={{fit,mesh,show,slots}}, pieces=n, parts=<added meshes>,
-- switched=<fit the auto rule put on the body instead of the Shoes'/first one>?, clips=<regions another outfit's piece
-- covers that the body's skin shows>?} or nil and why. Pure: no engine call; choices are never changed. The slot
-- BaseBody of a fit with Skin (no piece) picks its body, which is never switched. Else the body rule mode
-- (Dress.BODY_MODES, default auto, or a fit id): auto keeps the Shoes' outfit, else the first, unless its skin shows on
-- a region another outfit's piece covers; then the look's outfit with Skin that hides the most covered regions (ties:
-- the Shoes' outfit, then choice order). slots: material index -> the closet slot of its piece (BaseBody for the
-- body's skin slots), shown or not. toggles: {[fit]={[material index]=shown}} (closet/options.lua's toggles()), put
-- over the Toggles of a Whole fit worn whole (the fit itself is not changed); a fit worn as pieces keeps its pieces.
function Dress.plan(choices,fits,mode,toggles)
    fits=fits or Fits
    if #choices==0 then return nil,'nothing to wear' end
    local taken,by_fit,order,picked={},{},{},nil
    for _,choice in ipairs(choices) do
        local fit=fits.get(choice.fit)
        if not fit then return nil,'no fit map for '..tostring(choice.fit) end
        if by_fit[choice.fit] then return nil,choice.fit..' named twice' end
        local pieces,body={},false
        if choice.slots then
            for _,slot in ipairs(choice.slots) do
                if not Slots.known(slot) then return nil,'unknown slot '..tostring(slot) end
                if slot=='BaseBody' then
                    if next(fit.Skin or {})==nil then return nil,choice.fit..' has no skin' end
                    body=true
                else
                    local piece=fits.piece(choice.fit,slot)
                    if not piece then return nil,choice.fit..' has no '..slot end
                    pieces[#pieces+1]=piece
                end
            end
        else
            for _,piece in ipairs(fit.Pieces) do if not piece.Off then pieces[#pieces+1]=piece end end
        end
        local claims=body and {'BaseBody'} or {}
        for _,piece in ipairs(pieces) do
            for _,slot in ipairs({piece.Slot,table.unpack(piece.Occupies or {})}) do claims[#claims+1]=slot end
        end
        for _,slot in ipairs(claims) do
            if taken[slot] then return nil,slot..' is worn twice ('..taken[slot]..' and '..choice.fit..')' end
            taken[slot]=choice.fit
        end
        -- A Whole fit (a pack's, closet/fits.lua) worn with no slots named shows all its sections but the hidden ones
        -- (Fits.shows, at apply, which knows the mesh's slot count).
        by_fit[choice.fit]={fit=choice.fit,map=fit,pieces=pieces,whole=not choice.slots and fit.Whole and fit or nil}
        order[#order+1]=by_fit[choice.fit]
        if body then picked=by_fit[choice.fit] end
    end
    -- Regions the worn pieces cover, each with the outfits covering it: a body skin slot all of whose regions are
    -- covered is hidden.
    local covered={}
    for _,o in ipairs(order) do
        for _,piece in ipairs(o.pieces) do
            for _,region in ipairs(piece.Covers or {}) do
                covered[region]=covered[region] or {}
                covered[region][o.fit]=true
            end
        end
    end
    local base=taken.Shoes and by_fit[taken.Shoes] or order[1]
    local body,switched=picked,nil
    if not body and mode=='first' then body=order[1]
    elseif not body and mode=='shoes' then body=base
    elseif not body and mode and mode~='auto' then -- A forced body: worn with its skin only when not in the look.
        body=by_fit[mode]
        if not body and fits.get(mode) then
            body={fit=mode,map=fits.get(mode),pieces={}}
            order[#order+1]=body
        end
        body=body or base
    elseif not body then
        body=base
        local clips,most=skin_of(base,covered)
        if #clips>0 then
            for _,o in ipairs(order) do
                local _,hides=skin_of(o,covered)
                if hides>most then body,most=o,hides end
            end
            if body~=base then switched=body.fit end
        end
    end
    local plan={added={},pieces=0,switched=switched}
    local clips=skin_of(body,covered)
    if #clips>0 then plan.clips=clips end
    for _,o in ipairs(order) do
        local show,slots={},{}
        for _,piece in ipairs(o.pieces) do
            local shown=not foreign(covered,NAILS[piece.Slot] or '',o.fit)
            for _,index in ipairs(piece.Materials) do
                if shown then show[index]=true end
                slots[index]=piece.Slot
            end
            plan.pieces=plan.pieces+1
        end
        -- A pack suit worn whole: its PieceHints' slots (closet/cns_import.lua's guess from each toggle's name) for the
        -- sections no hand piece maps; parts() lists the other shown sections as FullOutfit.
        for _,h in ipairs(o.whole and o.whole.Hints or {}) do
            local i=h.MaterialIndex
            if i and not (o.map.Skin or {})[i] then slots[i]=slots[i] or h.Slot end -- The hand map's skin wins.
        end
        if o==body then
            for index,regions in pairs(o.map.Skin or {}) do
                if not hidden(regions,covered) then show[index]=true end
                slots[index]=slots[index] or 'BaseBody'
            end
            plan.body={fit=o.fit,mesh=o.map.Mesh,show=show,slots=slots,whole=o.whole}
        else
            plan.added[#plan.added+1]={fit=o.fit,mesh=o.map.Mesh,show=show,slots=slots,whole=o.whole}
        end
    end
    for _,a in ipairs({plan.body,table.unpack(plan.added)}) do
        local on=a.whole and toggles and toggles[a.fit]
        if on then
            local copy={}
            for k,v in pairs(a.whole) do copy[k]=v end
            copy.Toggles={}
            for index,v in pairs(a.whole.Toggles or {}) do copy.Toggles[index]=v end
            for index,v in pairs(on) do copy.Toggles[index]=v end
            a.whole=copy
        end
    end
    plan.parts=#plan.added
    return plan
end

-- "fit:Slot,Slot fit2" -> choices, or nil and why. A fit word is Fits.word's: %XX gives the byte back.
function Dress.parse(words)
    local choices={}
    for _,word in ipairs(words) do
        local fit,slots=word:match('^([%w_%.%-%%]+):([%w,]+)$')
        if fit then
            local list={}
            for slot in slots:gmatch('[^,]+') do list[#list+1]=slot end
            choices[#choices+1]={fit=Fits.unword(fit),slots=list}
        elseif word:match('^[%w_%.%-%%]+$') then
            choices[#choices+1]={fit=Fits.unword(word)}
        else
            return nil,Dress.USE
        end
    end
    return choices
end
-- choices -> "fit:Slot,Slot fit2", the words parse reads back (split on spaces), each fit id as Fits.word gives it.
function Dress.words(choices)
    local out={}
    for _,c in ipairs(choices) do
        local fit=Fits.word(c.fit)
        out[#out+1]=c.slots and fit..':'..table.concat(c.slots,',') or fit
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
    local state -- While a mix is on: {plan=, eve_path=, own=<mesh path>, materials=<line>, dynamic=<her dynamic slots'
                -- values>, added={c,count,show}, count=, paused=, wrong=}
    local restored,due=false,0
    local pending,tries,retry_at=nil,0,0 -- The kept line's fields once read; restore's failed wears; its next try.
    local mode='auto' -- Dress.plan's body rule for this Lua load (body_mode).
    local fights={} -- The clock of each mix again since the last wear or preview (an outside fight, Dress.FIGHT).
    local kept_fields,undo_kept -- Set with restore below; off uses them too.
    local applied=0 -- Each apply, her own look previewed and off (self.applied).
    local shown=0 -- Each reshow (self.shown).
    local function toggles() return o.toggles and o.toggles() end
    local said={} -- Asset paths of a variant that did not load, said once.
    local function asset(path)
        local got=path~='' and resolve(path)
        if not got and path~='' and not said[path] then
            said[path]=true
            log('variant: '..path..' does not load: left out')
        end
        return got
    end
    -- A variant's own materials (Materials: index i+1 is material slot i, an empty path keeps the mesh's) and fixed
    -- parameters (Parameters, after the materials) on the component c that wears a Whole fit. An asset that does not
    -- load is left out. Each parameter goes on the slot's dynamic instance (closet/colour.lua's
    -- CreateDynamicMaterialInstance, which hands back an instance already there: the palette reuses this one).
    -- The game's parts, read in Ghidra (SB-Win64-Shipping.exe, build 26123051) on 26 Nov 2026:
    --   UPrimitiveComponent.SetMaterial, GetMaterial, CreateDynamicMaterialInstance and
    --     UMaterialInstanceDynamic.SetVectorParameterValue: as closet/colour.lua's comment says (entries 0x14662b380,
    --     0x14662af60, 0x14662ae80, 0x1465e0ff0).
    --   UMaterialInstanceDynamic.SetScalarParameterValue(ParameterName FName, Value float): native entry 0x1465e0fb0
    --     (name 0x146577870), exec 0x144884430 reads the name and the float and calls FUN_14430d4a0 with {Name,
    --     Association 2, Index -1}, as the vector one does.
    --   UMaterialInstanceDynamic.SetTextureParameterValue(ParameterName FName, Value Texture): native entry 0x1465e0fd0
    --     (name 0x1465dd3a8), exec 0x144883de0 reads the name and an object and calls FUN_14430e910(this, name, it).
    --   A texture is used only when it is a UTexture2D (closet/ui/view.lua's class).
    --   USkeletalMeshComponent::SetSkeletalMesh FUN_14411a4f0 returns at once for the mesh it wears (+0x568), as
    --     closet/shape.lua's comment says. Neither it nor USkinnedMeshComponent's FUN_144128b60 touches
    --     OverrideMaterials (+0x538): an override stays across a mesh change, so apply and give_back take every override
    --     off (clear) before they set the ones the look needs.
    --   SetMaterial, vtable +0x590: FUN_1440df060 in USkeletalMeshComponent's vtable 0x1463ef0b0 (set by FUN_144112010
    --     after FUN_144123900; its SetSkeletalMesh FUN_14411a4f0 at +0x910) and in USkinnedMeshComponent's 0x1463fcac8
    --     (set by FUN_144123900; its SetSkeletalMesh FUN_144128b60 at +0x910). EVE's body can be SB's
    --     SBSkeletalMeshComponent (class FUN_1427ade70; its constructor at 0x1427b0750 jumps to FUN_1421bf180, which
    --     sets the vtable 0x145c7cfa0 after FUN_144112010): the same 0x144124f30, 0x1440df060 and 0x14411a4f0 at
    --     +0x588, +0x590 and +0x910. FUN_1440df060 returns for an index below 0 or when the entry already holds that
    --     material, grows OverrideMaterials (+0x538 data, +0x540 Num) to the index, stores the material (a null one as
    --     null) and marks the render state dirty (FUN_14408e490). It does more than that: over an entry that is not
    --     null it first sets bit 0x2 of the byte at +0x558, unless the new material is a MaterialInstanceDynamic whose
    --     Parent (+0xd0) is that entry. After a material that is not null it calls FUN_142b94cb0(material, component,
    --     1).
    --     GetMaterial, vtable +0x588 (0x144124f30 in both): the override when it is not null, else the mesh's
    --     Materials[i] (+0xe0 data, +0xe8 Num, 0x28 a slot), else null.
    -- shortcut: a Parameters texture of another Texture class (a cube map) is left out; read UTexture in Ghidra if a
    -- pack needs one.
    local function wear_variant(c,whole)
        if not whole then return end
        for i,p in ipairs(whole.Materials or {}) do
            local m=asset(p)
            if m then pcall(function() c:SetMaterial(i-1,m) end) end
        end
        for _,p in ipairs(whole.Parameters or {}) do
            local index=type(p)=='table' and math.tointeger(p.MaterialIndex)
            local value=index and p.Value
            if p.ParamType=='Texture' then
                value=type(value)=='string' and asset(value)
                if value and not value:IsA(StaticFindObject('/Script/Engine.Texture2D')) then value=nil end
            elseif p.ParamType=='Vector' then
                value=type(value)=='table' and {R=value[1] or 0,G=value[2] or 0,B=value[3] or 0,A=value[4] or 1}
            elseif p.ParamType~='Scalar' or type(value)~='number' then value=nil end
            if value and type(p.ParamName)=='string' then
                local done,why=pcall(function()
                    local mid=valid(c:CreateDynamicMaterialInstance(index,c:GetMaterial(index),FName('None')))
                    if mid then mid['Set'..p.ParamType..'ParameterValue'](mid,FName(p.ParamName),value) end
                end)
                if not done then log('variant: '..p.ParamName..' not set on slot '..index..': '..tostring(why)) end
            end
        end
    end

    local function keep()
        if not state then return store.clear() end
        local added={}
        for _,a in ipairs(state.added) do added[#added+1]=a.mesh end
        return store.save(table.concat({state.eve_path or '',state.own or '',state.materials or '',
            table.concat(added,';'),
            Dress.words(state.kept==nil and state.choices or (state.kept or {}))},'\t'))
    end
    -- Removes every component on EVE but her body that wears one of the given mesh paths: ours, also one an earlier
    -- mix or Lua load left (a map load can make the game set her body twice: each change got the mix again).
    -- Her body is told by its address: UE4SS hands a new wrapper at each read, so c~=body is true for her body too. A
    -- body whose address does not read: nothing is removed. No valid body: no component can be it.
    local function sweep(eve,paths)
        local body=valid(eve.Mesh)
        local at=nil
        if body then
            local read
            read,at=pcall(U.address,body)
            if not (read and at) then return 0 end
        end
        local removed=0
        local wanted={}
        for _,p in ipairs(paths) do wanted[p]=true end
        each(eve:K2_GetComponentsByClass(StaticFindObject(SKINNED)),function(_,c)
            c=valid(c)
            local mesh=c and valid(c.SkeletalMesh)
            local ok,addr=pcall(U.address,c)
            if c and mesh and ok and addr~=at and wanted[path_of(mesh)] then
                pcall(function() c:K2_DestroyComponent(c) end)
                removed=removed+1
            end
        end)
        return removed
    end
    -- Removes the added components wearing the given mesh paths and gives the body its own mesh and materials back. A
    -- slot in dynamic (current_materials') gets a new dynamic instance of its parent with her values: the one she wore
    -- went with the first mix. The engine may have freed it since.
    -- shortcut: the values live in memory only, so after a Lua reload her dynamic slots come back as their parents;
    -- write them into coop-closet.txt if a pack or the game is seen to need them.
    local function give_back(eve,own,materials,added_paths,dynamic)
        local body=valid(eve.Mesh)
        local removed=sweep(eve,added_paths)
        if body and own and own~='' then
            local mesh=usable(own)
            if mesh then
                body:SetSkeletalMesh(mesh,true)
                clear(body)
                local mats=own_materials(mesh)
                for slot,p in (materials or ''):gmatch('(%d+)=([^,]*)') do
                    slot=tonumber(slot)
                    -- An older line lists every slot: one on its mesh's own material needs no override.
                    local values=dynamic and dynamic[slot]
                    local m=p~='' and (values or p~=(mats[slot] and path_of(mats[slot]))) and resolve(p)
                    if m and values then
                        local done,why=pcall(function()
                            local mid=valid(body:CreateDynamicMaterialInstance(slot,m,FName('None')))
                            for _,v in ipairs(mid and values or {}) do
                                local x=v.kind=='Texture' and valid(v.value) or v.value
                                if x then mid['Set'..v.kind..'ParameterValue'](mid,FName(v.name),x) end
                            end
                        end)
                        if not done then log('her dynamic material on slot '..slot..' not made again: '..tostring(why)) end
                    elseif m then pcall(function() body:SetMaterial(slot,m) end) end
                end
                for lod=0,lods(body)-1 do pcall(function() body:ShowAllMaterialSections(lod) end) end
            end
        end
        return removed
    end

    -- kept: the confirmed choices of a preview (or false), nil when none is going.
    local function apply(plan,choices,kept)
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
        local own,materials,dynamic=state and state.own,state and state.materials,state and state.dynamic
        if not state then
            local mesh=valid(body.SkeletalMesh)
            dynamic={}
            own,materials=mesh and path_of(mesh) or '',current_materials(body,dynamic)
        end
        -- The new look is written before anything on EVE changes. A save that fails (a virus scanner holding the
        -- temporary file) leaves the look on EVE and the state as they were. The old line is then written again.
        local was=state
        state={plan=plan,choices=choices,kept=kept,eve_path=path_of(eve),own=own,materials=materials,dynamic=dynamic,
            added={},paused=false,wrong=0}
        for _,a in ipairs(plan.added) do state.added[#state.added+1]={mesh=a.mesh} end
        local saved,e=keep()
        if saved==false then
            state=was
            if was then keep() end
            return nil,'coop-closet.txt not written: '..tostring(e)
        end
        -- No added mesh of an earlier mix stays: the old one's and this plan's outfits are swept off EVE first.
        local paths={}
        for _,a in ipairs(was and was.added or {}) do paths[#paths+1]=a.mesh end
        for _,a in ipairs(plan.added) do paths[#paths+1]=a.mesh end
        sweep(eve,paths)
        local _,count=own_materials(body_mesh)
        if plan.body.whole then plan.body.show=Fits.shows(plan.body.whole,count) end
        body:SetSkeletalMesh(body_mesh,true)
        clear(body) -- Hers, an earlier mix's variant and the colour layer's instances: only the look's own go on.
        wear_variant(body,plan.body.whole)
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
            wear_variant(c,a.whole)
            if a.whole then a.show=Fits.shows(a.whole,n) end
            show_only(c,n,a.show)
            state.added[i]={mesh=a.mesh,c=c,count=n,show=a.show}
        end
        applied=applied+1
        return true
    end

    -- Her own look as a preview (the menu's None tile on the last piece worn): the added meshes off, her body's own
    -- mesh and materials back, no plan; kept stays, so the file keeps the confirmed words.
    local function own_look(kept)
        local eve=her()
        if not eve then return false,'no EVE in the world' end
        local paths={}
        for _,a in ipairs(state.added) do paths[#paths+1]=a.mesh end
        local removed=give_back(eve,state.own,state.materials,paths,state.dynamic)
        state={choices={},kept=kept,eve_path=path_of(eve),own=state.own,materials=state.materials,dynamic=state.dynamic,
            added={},paused=false,wrong=0}
        applied=applied+1
        local saved,e=keep()
        if saved==false then return false,'coop-closet.txt not written: '..tostring(e) end
        log('preview: her own look, '..removed..' added mesh(es) removed')
        return true,'closet: previewing her own look'
    end
    -- What the body rule did, for the log lines: the switch and the regions whose skin shows under a piece.
    local function body_notes(plan)
        return (plan.switched and ' (switched by the auto body rule)' or '')..
            (plan.clips and ', skin shows on '..table.concat(plan.clips,',') or '')
    end
    -- A kept look restore has not worn again yet (it waits while the game is paused, shows a loading screen or is in its
    -- retry window): its leftovers off EVE and her own look back now. Then restore is done. So a wear or preview right
    -- after records her own look, never the kept look's mesh. No later restore puts the kept look over it. With no EVE
    -- it waits: the apply fails anyway.
    local function settle()
        if restored then return end
        if state then restored,pending=true,{}; return end
        local found,eve=pcall(her)
        if not (found and eve) then return end
        local f=kept_fields()
        if #f>0 then
            if o.packs then o.packs() end -- A pack suit on her body is a closet mesh once the packs are read.
            pcall(undo_kept,eve,f)
        end
        restored,pending=true,{}
    end
    -- The line that refuses a wear or preview while SBO's own state holds EVE's body, or nil.
    local function held()
        local key,why=nil,nil
        if o.busy then key,why=o.busy() end
        return key and 'closet: not while '..tostring(why or key) or nil
    end
    -- coop closet wear: the plan for choices, put on now.
    function self.wear(choices)
        local busy=held()
        if busy then return false,busy end
        self.restore()
        settle()
        fights={}
        local plan,why=Dress.plan(choices,fits,mode,toggles())
        if not plan then return false,why end
        local ok,e=apply(plan,choices,nil)
        if not ok then return false,e end
        local names={}
        for _,c in ipairs(choices) do names[#names+1]=c.fit end
        local line=string.format('closet: %d pieces of %s; body %s%s, %d added mesh%s', plan.pieces,
            table.concat(names,' + '),plan.body.fit,body_notes(plan),plan.parts,plan.parts==1 and '' or 'es')
        log(line)
        return true,line
    end
    -- A look put on without saving it: the confirmed choices stay in the file until confirm. No choices while a look is
    -- on: her own look (own_look). Gives true, the line and the plan (the menu tells its switched and clips).
    function self.preview(choices)
        local busy=held()
        if busy then return false,busy end
        self.restore()
        settle()
        fights={}
        local kept=state and state.kept
        if kept==nil then kept=state and state.choices or false end
        if #choices==0 and state then return own_look(kept) end
        local plan,why=Dress.plan(choices,fits,mode,toggles())
        if not plan then return false,why end
        local ok,e=apply(plan,choices,kept)
        if not ok then return false,e end
        local line=string.format('closet: previewing %d pieces, body %s%s, %d added mesh%s',plan.pieces,plan.body.fit,
            body_notes(plan),plan.parts,plan.parts==1 and '' or 'es')
        log('preview: '..line)
        return true,line,plan
    end
    function self.previewing() return state~=nil and state.kept~=nil end
    -- Ends the preview and saves the worn choices.
    function self.confirm()
        if not self.previewing() then return true,'closet: nothing to confirm' end
        if not state.plan then -- Her own look kept: as coop closet off.
            self.off()
            log('confirm: her own look is saved, the kept look is cleared')
            return true,'closet: confirmed'
        end
        local was=state.kept
        state.kept=nil
        local saved,e=keep()
        if saved==false then state.kept=was; return false,'coop-closet.txt not written: '..tostring(e) end
        log('confirm: the previewed look is saved')
        return true,'closet: confirmed'
    end
    -- Ends the preview: the confirmed look worn again, her own look when none was confirmed or it no longer plans. A
    -- wear that fails now (no EVE during a map change, a mesh that does not load) keeps the preview going. The file
    -- keeps the confirmed words: the next revert or Lua load wears them.
    function self.revert()
        if not self.previewing() then return true,'closet: nothing to revert' end
        local was=state.kept
        if was and Dress.plan(was,fits,mode,toggles()) then
            local ok,line=self.wear(was)
            if ok then log('revert: the confirmed look is back'); return true,line end
            log('revert: the confirmed look could not be worn now: '..tostring(line))
            return false,line
        end
        local ok,line=self.off()
        log('revert: the confirmed look is gone: her own look')
        return ok,line
    end
    function self.choices()
        if not state then return nil end
        local out={}
        for i,c in ipairs(state.choices) do
            out[i]={fit=c.fit,slots=c.slots and {table.unpack(c.slots)} or nil}
        end
        return out
    end
    -- The body mesh path when the game put one of GAME_LOOKS on EVE (Tachy Mode), else nil.
    function self.game_look()
        local eve=her()
        local body=eve and valid(eve.Mesh)
        local mesh=body and valid(body.SkeletalMesh)
        local path=mesh and path_of(mesh)
        return path and Dress.GAME_LOOKS[path] and path or nil
    end
    -- Whether a mesh loads here, cached per path; one that does not load is logged once (what(why) gives the line).
    local function loads(path,what)
        if installed_cache[path]==nil then
            local mesh,why=usable(path)
            installed_cache[path]=mesh~=nil
            if not mesh then log(what(tostring(why))) end
        end
        return installed_cache[path]
    end
    -- Whether the fit's mesh loads here (its outfit is installed).
    function self.installed(fit_id)
        local fit=fits.get(fit_id)
        if not fit then return false end
        return loads(fit.Mesh,function(why)
            return fit_id..': its mesh does not load ('..why..'): its row is locked'
        end)
    end
    -- Whether a variant's mesh loads here (the options page's Variant row skips one that does not).
    function self.loads(path)
        return loads(path,function(why)
            return 'variant: its mesh does not load ('..why..'): the variant is left out'
        end)
    end
    -- coop closet body: the body rule of the next wears in this Lua load: one of Dress.BODY_MODES, or a fit id with
    -- Skin (that body forced).
    function self.body_mode(word)
        local known=false
        for _,m in ipairs(Dress.BODY_MODES) do known=known or m==word end
        local fit=not known and fits.get(word)
        if not known and not fit then return false,'no fit map for '..tostring(word) end
        if fit and next(fit.Skin or {})==nil then return false,word..' has no skin' end
        mode=word
        log('body rule: '..word)
        return true,'closet: body rule '..word..' from the next wear'
    end
    -- coop closet skin: one material slot of the component that wears fit_id's mesh shown or hidden now, on every LOD,
    -- for trying a setup in game. The watchdog keeps it; the next wear's plan replaces it.
    function self.skin(fit_id,index,on)
        if not (state and state.plan) then return false,'closet: nothing worn' end
        if state.paused then return false,'closet: paused while a game look is on' end -- Her body wears its mesh.
        local c,count,show
        if state.plan.body.fit==fit_id then
            local eve=her()
            c,count,show=eve and eve.Mesh,state.count,state.plan.body.show
        end
        for i,a in ipairs(state.plan.added) do
            if a.fit==fit_id then c,count,show=state.added[i].c,state.added[i].count,state.added[i].show end
        end
        c=valid(c)
        if not c then return false,'closet: '..tostring(fit_id)..' is not worn' end
        if index>=count then return false,'closet: '..fit_id..' has no material slot '..index end
        show[index]=on or nil
        show_only(c,count,show)
        local line=string.format('closet: slot %d of %s %s',index,fit_id,on and 'shown' or 'hidden')
        log(line)
        return true,line
    end
    -- coop closet off and coop off: her own look back, the added meshes gone, the file cleared.
    function self.off()
        if not state and not restored then -- A kept look not worn again yet: dropped, its leftovers off EVE.
            local f=kept_fields()
            local found,eve=pcall(her)
            if #f>0 and found and eve then
                if o.packs then o.packs() end -- A pack suit on her body is a closet mesh once the packs are read.
                pcall(undo_kept,eve,f)
            end
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
        local removed=eve and give_back(eve,state.own,state.materials,paths,state.dynamic) or 0
        state=nil
        applied=applied+1
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
        for _,fit in pairs(fits.all and fits.all() or fits.BY_ID or {}) do if fit.Mesh==path then return true end end
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
        -- The pack catalogue read first: a pack suit on her body is a closet mesh, the kept words may name one.
        if o.packs then o.packs() end
        local ok,removed=pcall(undo_kept,eve,f)
        local kept=f[5] or ''
        if kept=='' then
            return done(true,ok and (removed..' added mesh(es) removed, her own look back') or tostring(removed))
        end
        local words={}
        for x in kept:gmatch('%S+') do words[#words+1]=x end
        local choices,why=Dress.parse(words)
        local plan
        if choices then plan,why=Dress.plan(choices,fits,mode,toggles()) end
        if not plan then return done(true,'could not wear '..kept..' again: '..tostring(why)) end
        local ran,worn,e=pcall(apply,plan,choices)
        if ran and worn then return done(false,'worn again: '..kept..body_notes(plan)) end
        tries=tries+1
        if tries<Dress.RETRIES then retry_at=now+1; return end
        done(not state,'could not wear '..kept..' again after '..tries..' tries: '..tostring(ran and e or worn))
    end
    -- Once a second at most, on the game thread: the watchdog.
    function self.tick()
        if not restored then self.restore() end
        -- No plan: her own look previewed, nothing mixed. Stopped: an outside fight over the body (below).
        if not state or not state.plan or state.stopped or paused() then return end
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
            -- No valid body mesh (a pawn still spawning): the mix waits (counted toward no outside fight) and goes on
            -- at the first second the body is back.
            if not path then
                if not state.waiting then state.waiting=true; log('EVE has no valid body mesh: the mix waits') end
                return
            end
            state.waiting=nil
            state.wrong=state.wrong+1
            if state.wrong<2 and not was_paused then return end
            log(string.format('the game changed EVE (body %s): mix again',tostring(path)))
            local plan,choices,kept=state.plan,state.choices,state.kept
            -- A look put on from outside is hers from now on; a closet mesh still on her body is the closet's own.
            if path and not closet_mesh(path) then
                state.own,state.dynamic=path,{}
                state.materials=current_materials(body,state.dynamic)
            end
            -- Something outside undoes every mix: the look's outfit it keeps putting on her body is worn as the body
            -- unless a body is picked (no switch, the menu warns of the clipping). Otherwise the mix stops until the next
            -- wear or preview.
            fights[#fights+1]=now
            while now-fights[1]>Dress.FIGHT.within do table.remove(fights,1) end
            if #fights>=Dress.FIGHT.mixes then
                fights={}
                local insisted
                for _,c in ipairs(choices) do
                    local fit=fits.get(c.fit)
                    if fit and fit.Mesh==path then insisted=c.fit end
                end
                -- A picked body (BaseBody) wins over the mode, so that plan may keep the body the outside undoes.
                local forced=insisted and insisted~=plan.body.fit and Dress.plan(choices,fits,insisted,toggles())
                if not (forced and forced.body.fit==insisted) then
                    state.stopped=true
                    for _,a in ipairs(state.added) do
                        if valid(a.c) then pcall(function() a.c:SetHiddenInGame(true,false) end) end
                    end
                    log(string.format('something outside keeps changing her body (%s): the closet stops mixing until '
                        ..'the next wear or preview, its added meshes hidden',tostring(path)))
                    return
                end
                plan=forced
                log('something outside keeps putting '..insisted..' on her body: the look is worn on that body until '
                    ..'the next wear or preview')
            end
            -- apply keeps the state's own look and sweeps its added meshes (a forced body's plan adds other outfits). A
            -- mix that fails keeps the state: the next second tries again. coop closet off still gives her look back.
            local ok,why=apply(plan,choices,kept)
            if not ok then log('mix again failed: '..tostring(why)) end
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
        if not state.plan then return 'closet: previewing her own look' end
        local p=state.plan
        return string.format('closet: %d pieces, body %s, %d added mesh%s%s',p.pieces,p.body.fit,p.parts,
            p.parts==1 and '' or 'es',state.stopped and ', stopped (something outside keeps changing her body)'
            or state.paused and ', paused (a game look is on)' or '')
    end
    -- Whether a look of the closet is on EVE, or a kept one waits for restore to wear it again (eve/wear.lua refuses
    -- then: its own look of her would be the closet's mesh).
    function self.worn() return state~=nil or not restored and #kept_fields()>0 end
    -- The plan on EVE now (Dress.plan's, the preview's or the confirmed look's), or nil: the menu shows its body and
    -- its switched and clips.
    function self.plan() return state and state.plan end
    -- How many times her look was put on or given back (each apply, her own look previewed, off): closet/colour.lua
    -- puts its palette on again when it grows, closet/shape.lua its shape.
    function self.applied() return applied end
    -- How many times reshow showed new sections on the same meshes: closet/colour.lua paints the slots shown since,
    -- keeping its instances.
    function self.shown() return shown end
    -- The look on EVE planned again with the toggles of now (closet/options.lua's tick, after a variant change): put
    -- on as a new look (applied grows), the preview and the confirmed words kept. true when nothing is mixed or the
    -- mix is stopped (the next wear plans anew); false and why while paused (asked again) or when it fails.
    function self.again()
        if not (state and state.plan) or state.stopped then return true end
        if state.paused then return false,'paused while a game look is on' end
        local plan,why=Dress.plan(state.choices,fits,mode,toggles())
        if not plan then return false,why end
        return apply(plan,state.choices,state.kept)
    end
    -- The sections of the look on EVE shown again by the toggles of now (closet/options.lua's tick, after a toggle
    -- change), on the meshes she wears: no SetSkeletalMesh, applied() kept (the colour and shape layers keep their
    -- instances and curves), shown() grows. A plan with other meshes is put on as again does. The watchdog compares
    -- with the new plan.
    function self.reshow()
        if not (state and state.plan) or state.stopped then return true end
        if state.paused then return false,'paused while a game look is on' end
        local plan,why=Dress.plan(state.choices,fits,mode,toggles())
        if not plan then return false,why end
        local same=plan.body.mesh==state.plan.body.mesh and #plan.added==#state.added
        for i,a in ipairs(plan.added) do same=same and a.mesh==state.added[i].mesh end
        if not same then return apply(plan,state.choices,state.kept) end
        local eve=her()
        local body=eve and valid(eve.Mesh)
        if not body then return false,'no EVE in the world' end
        if plan.body.whole then plan.body.show=Fits.shows(plan.body.whole,state.count) end
        show_only(body,state.count,plan.body.show)
        for i,a in ipairs(plan.added) do
            local s=state.added[i]
            if a.whole then a.show=Fits.shows(a.whole,s.count) end
            s.show=a.show
            if valid(s.c) then show_only(s.c,s.count,a.show) end
        end
        state.plan=plan
        shown=shown+1
        return true
    end
    -- The worn components with their outfits, mesh paths, shown material slots and the closet slot each belongs to
    -- (closet/colour.lua, closet/shape.lua; a pack suit worn whole: FullOutfit for a section no piece or hint maps):
    -- {{c=<component, nil when gone>, fit=<UniqueFitID>, mesh=<path>,
    -- slots={[index]=<Slot id>}}},
    -- her body first, then the added meshes in the plan's order. {} with no look mixed; nil while the mix is paused or
    -- stopped, or EVE is not there.
    function self.parts()
        if not (state and state.plan) then return {} end
        local eve=not (state.paused or state.stopped) and her()
        if not eve then return nil end
        local out={}
        local function add(c,a)
            c=valid(c)
            local slots={}
            for index,slot in pairs(c and a.slots or {}) do if a.show[index] then slots[index]=slot end end
            -- A pack suit worn whole: a shown section with no slot is the whole outfit's (the colour layer's Primary).
            for index in pairs(c and a.whole and a.show or {}) do slots[index]=slots[index] or Slots.FULL_OUTFIT end
            out[#out+1]={c=c,fit=a.fit,mesh=a.mesh,slots=slots}
        end
        add(eve.Mesh,state.plan.body)
        for i,a in ipairs(state.plan.added) do add(state.added[i] and state.added[i].c,a) end
        return out
    end
    return self
end

return Dress
