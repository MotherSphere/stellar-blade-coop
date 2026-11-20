-- Fusion Rider on SBO's bike (dev build, for SBO devs to test; its pak EveBike_FusionRider_P is a recolour of the
-- Night Rider mod, Nexus 2479, so a public release needs that author's permission). Ported from Eve Hoverbike's
-- ride_body.lua and suit_fx.lua. At a mount the riding suit goes on her main mesh with the Fusion suit's wings beside it, through the game's Tachy Mode start show (Suit.ON). At the
-- dismount the prologue's drop-pod wipe (MA_BodySuit_Masking's HeightMask, Suit.OFF) brings her own outfit back, then
-- the wings go. Her riding clip plays on her own animation (vehicles/bike/ride.lua's anim play), so
-- a swap never restarts it: SetSkeletalMesh with bReinitPose false, and the wipe's end puts materials back only.
-- A hidden keeper actor holds her own mesh and materials while the suit is on (the collector would free them).
local U=require('core.unreal')
local Doro=require('core.actors')
local Look=require('vehicles.bike.fusion.look') -- Look.load: a mod pak's assets too
local valid,find=U.valid,U.find
local Suit={}

local DIR='/Game/Mods/EveBikes/Quantum/FusionRider/'
Suit.MESH=DIR..'FusionRider.FusionRider'
Suit.MATS={DIR..'missberave_skin/misberave_skin.misberave_skin',DIR..'PartB.PartB',
    DIR..'missberave_skin/NellSkin.NellSkin',DIR..'PartA.PartA'} -- Its slot order.
Suit.WINGS=DIR..'FusionWings.FusionWings'
-- Saroj 2026-11-19: get on with the Fusion (Tachy Mode start) show, get off with the drop-pod (prologue) wipe.
-- Each 'tachy', 'prologue' or 'off'.
Suit.ON,Suit.OFF='tachy','prologue'
Suit.TIME=1.6 -- s: the wipe (the prologue scene took 1.5 s).
Suit.H0,Suit.H1=2.0,-0.2 -- HeightMask from and to (the scene ran 2.0 -> 0.9 on a kneeling EVE).
Suit.SWAP=0.12 -- s into the Tachy show before the swap.
local PRO='/Game/Art/FX/Enviroment/Beach/Cinematic/Prologue_DropPodOpen/'
local MASK='/Game/Art/Character/Generic/MF/BodySuit/MA_BodySuit_Masking.MA_BodySuit_Masking'
local SHOW='/Game/Art/FX/Show/Common/FX_TachyModeStartFX.FX_TachyModeStartFX'
local MESH,MAT,OBJ='/Script/Engine.SkeletalMesh','/Script/Engine.MaterialInterface','/Script/CoreUObject.Object'
local function asset(dir,n) return dir..n..'.'..n end

local function spawn_hidden(e)
    local p=e:K2_GetActorLocation()
    local a=valid(e:GetWorld():SpawnActor(find('/Script/Engine.SkeletalMeshActor'),{X=p.X,Y=p.Y,Z=p.Z},
        {Pitch=0,Yaw=0,Roll=0}))
    assert(a,'no actor spawned')
    a:SetActorHiddenInGame(true)
    a:SetActorEnableCollision(false,false)
    a.SkeletalMeshComponent:SetComponentTickEnabled(false)
    return a
end
-- A visible actor on her main mesh, copying her pose, showing mesh.
local function follower(e,mesh)
    local a=spawn_hidden(e)
    local c=a.SkeletalMeshComponent
    c:SetSkeletalMesh(mesh,true)
    a:K2_AttachToComponent(e.Mesh,FName('None'),2,2,2,false)
    c:SetComponentTickEnabled(true)
    c:SetMasterPoseComponent(e.Mesh,true)
    -- Her bounds, not its own: its own (from its reference pose) can lie off screen and get it culled (2026-11-19:
    -- the wings never showed in SBO).
    pcall(function() c.bUseBoundsFromMasterPoseComponent=true end)
    a:SetActorHiddenInGame(false)
    return a
end
-- After a mesh swap on her body: the wings copy her new mesh's pose again; a line on their state for the log.
local function relink(s,e)
    if not (s.wings and valid(s.wings)) then return end
    local c=s.wings.SkeletalMeshComponent
    pcall(function() c:SetMasterPoseComponent(e.Mesh,true) end)
    s.report=Suit.wings_state(s,e)
end
-- The wings' state for the log: shown or not, where against her body, their mesh, master and materials.
function Suit.wings_state(s,e)
    if not (s and s.wings and valid(s.wings)) then return 'wings: none (actor gone)' end
    local c=s.wings.SkeletalMeshComponent
    local function n(v) return tonumber(U.value_of(v)) or 0 end
    local parts={}
    local function add(label,f)
        local ok,v=pcall(f)
        parts[#parts+1]=label..' '..(ok and tostring(v) or 'unread')
    end
    add('visible',function() return c:IsVisible() end)
    add('hidden',function() return s.wings:IsHidden() end)
    add('mesh',function() return valid(c.SkeletalMesh) and c.SkeletalMesh:GetFName():ToString() or 'none' end)
    add('master',function() return valid(c.MasterPoseComponent) and (U.address(c.MasterPoseComponent)==U.address(e.Mesh)
        and 'her body' or 'another') or 'none' end)
    add('bones',function() return c:GetNumBones() end)
    add('materials',function()
        local ok,bad=0,0
        for i=0,c:GetNumMaterials()-1 do if valid(c:GetMaterial(i)) then ok=ok+1 else bad=bad+1 end end
        return ok..' ok '..bad..' missing'
    end)
    add('from her (cm)',function()
        local a,b=U.value_of(c:K2_GetComponentLocation()),U.value_of(e.Mesh:K2_GetComponentLocation())
        return ('%d,%d,%d'):format(n(a.X)-n(b.X),n(a.Y)-n(b.Y),n(a.Z)-n(b.Z))
    end)
    add('bounds radius',function() return math.floor(n(U.value_of(c.Bounds).SphereRadius)) end)
    return 'wings: '..table.concat(parts,', ')
end
local function wear(c,s,mesh_too)
    if mesh_too then c:SetSkeletalMesh(s.mesh,false) end -- false: her riding clip keeps playing.
    for i,m in ipairs(s.mats) do c:SetMaterial(i-1,m) end
end

-- Masking master's textures for a material: its own first, then its parents'.
local function target(name)
    local n=name:lower():gsub('[%s_]','')
    if n:find('pattern',1,true) or n:find('detail',1,true) then return nil end
    if n:find('basecolor',1,true) or n:find('diffuse',1,true) or n:find('albedo',1,true) then return 'BaseColor' end
    if n:find('normal',1,true) then return 'BaseNormal' end
    if n:find('orm',1,true) then return 'BaseORM' end
    if n:find('emiss',1,true) then return 'EmissiveMask' end
end
local function textures(mi)
    local out={}
    for _=1,8 do
        if not valid(mi) then break end
        local ok,arr=pcall(function() return mi.TextureParameterValues end)
        if not ok or not arr then break end
        pcall(function() arr:ForEach(function(_,el)
            local v=el:get()
            local k=target(v.ParameterInfo.Name:ToString())
            if k and out[k]==nil and valid(v.ParameterValue) then out[k]=v.ParameterValue end
        end) end)
        local okP,p=pcall(function() return mi.Parent end)
        mi=okP and p or nil
    end
    return out
end
local function mask(c,mats,master,dir,list)
    for i,src in ipairs(mats) do
        local mid=valid(c:CreateDynamicMaterialInstance(i-1,master,FName('None')))
        if mid then
            for k,t in pairs(textures(src)) do mid:SetTextureParameterValue(FName(k),t) end
            mid:SetScalarParameterValue(FName('MaskDirection'),dir)
            mid:SetScalarParameterValue(FName('HeightMask'),Suit.H0)
            list[#list+1]=mid
        end
    end
end
local function niagara(f,path,parent,sock)
    local sys=Look.load(path,OBJ)
    if not sys then return nil end
    local ok,c=pcall(function()
        return find('/Script/Niagara.Default__NiagaraFunctionLibrary'):SpawnSystemAttached(sys,parent,
            FName(sock or 'None'),{X=0,Y=0,Z=0},{Pitch=0,Yaw=0,Roll=0},0,false,true,0,false)
    end)
    if ok and valid(c) then f.ns[#f.ns+1]=c return c end
end

-- f.to: the outfit the change ends in ({mesh, mats}): the suit at a mount, her own at the dismount.
local function prologue(e,f)
    local master=assert(Look.load(MASK,MAT),'no MA_BodySuit_Masking')
    local c,old=e.Mesh,{}
    for i=0,c:GetNumMaterials()-1 do old[i+1]=c:GetMaterial(i) end
    f.copy=follower(e,c.SkeletalMesh) -- the outfit she leaves on a copy that copies her pose
    local cc=f.copy.SkeletalMeshComponent
    mask(cc,old,master,0,f.mids)
    wear(c,f.to,true)
    mask(c,f.to.mats,master,1,f.mids)
    local dm=Look.load(asset(PRO,'MI_ChangeDecal_1'),MAT)
    if dm then
        local ok,dc=pcall(function()
            return find('/Script/Engine.Default__GameplayStatics'):SpawnDecalAttached(dm,{X=70,Y=100,Z=100},e.Mesh,
                FName('None'),{X=0,Y=0,Z=95},{Pitch=0,Yaw=90,Roll=-90},0,Suit.TIME+1)
        end)
        if ok and valid(dc) then f.decal,f.decal_mid=dc,dc:CreateDynamicMaterialInstance() end
    end
    f.ring=niagara(f,asset(PRO,'NS_A_TransformRing'),e.Mesh)
    niagara(f,asset(PRO,'NS_A_BodyChangeFlash_1'),e.Mesh)
    niagara(f,asset(PRO,'NS_A_BodyParticleTest'),e.Mesh)
    return ('prologue wipe, %d masking copies, decal %s'):format(#f.mids,f.decal and 'on' or 'missing')
end
local function tachy(e,f)
    f.swap_at=Suit.SWAP
    local show=Look.load(SHOW,OBJ)
    assert(show,'no FX_TachyModeStartFX')
    find('/Script/SB.Default__SBBlueprintLibrary'):PlaySBShowToPlayerCharacter(show)
    f.show=show -- held while it plays
    return 'Tachy Mode start show'
end
local function finish(s,f)
    if f.copy then pcall(function() f.copy:K2_DestroyActor() end) end
    for _,c in ipairs(f.ns) do pcall(function() c:Deactivate() c:K2_DestroyComponent(c) end) end
    if f.decal then pcall(function() f.decal:K2_DestroyComponent(f.decal) end) end
    if s.fx==f then s.fx=nil end
end
-- After the dismount's change: the keeper and the wings gone, the state done.
local function release(s)
    for _,a in ipairs({s.keeper,s.wings}) do
        if valid(a) then pcall(function() a:K2_DestroyActor() end) end
    end
    s.done=true
end
-- The change to f.to in style ('prologue' falls back to 'tachy'): the line for the log, s.fx set when it runs.
local function change(e,s,style,to)
    local f={t0=os.clock(),style=style,mids={},ns={},to=to}
    local ok,line=pcall(style=='prologue' and prologue or tachy,e,f)
    if not ok and style=='prologue' then
        finish(s,f)
        f={t0=os.clock(),style='tachy',mids={},ns={},to=to}
        ok,line=pcall(tachy,e,f)
        line=ok and line..' (the wipe failed)' or line
    end
    if not ok then
        finish(s,f)
        return 'suit-up failed ('..U.why(line)..')'
    end
    s.fx=f
    return line
end
-- Her own outfit as the keeper holds it.
local function own(s)
    local kc=s.keeper.SkeletalMeshComponent
    local mats={}
    for i=0,s.n-1 do mats[i+1]=kc:GetMaterial(i) end
    return {mesh=kc.SkeletalMesh,mats=mats}
end

-- At the mount, on her EVE e: the suit on through the suit-up. Returns the state (nil, why when the pak is missing).
function Suit.on(e)
    local mesh=Look.load(Suit.MESH,MESH)
    local mats={}
    for i,p in ipairs(Suit.MATS) do mats[i]=Look.load(p,MAT) end
    if not mesh or #mats~=#Suit.MATS then return nil,'Fusion Rider is not in ~mods (EveBike_FusionRider_P)' end
    local c=e.Mesh
    local keeper=spawn_hidden(e)
    local kc=keeper.SkeletalMeshComponent
    kc:SetSkeletalMesh(c.SkeletalMesh,false)
    local n=c:GetNumMaterials()
    for i=0,n-1 do kc:SetMaterial(i,c:GetMaterial(i)) end
    local s={eve=U.address(e),keeper=keeper,n=n,mesh=mesh,mats=mats}
    s.style=Suit.OFF -- the dismount's change
    local said=Suit.ON~='off' and change(e,s,Suit.ON,s) or 'no suit-up'
    if not s.fx then wear(c,s,true) end
    local wings=Look.load(Suit.WINGS,MESH)
    if wings then
        local ok,a=pcall(follower,e,wings)
        if ok then s.wings=a relink(s,e) end
    end
    local line=said..(s.wings and ', wings on' or ', no wings')..(s.report and '; '..s.report or '')
    s.report=nil
    return s,line
end

-- Each frame while a change runs (riding, or after the dismount): its next step. A dismount's change that ends, or
-- whose EVE is gone, releases the keeper and the wings.
function Suit.tick(s,e)
    local f=s and s.fx
    if not f then return end
    if not (e and valid(e) and U.address(e)==s.eve) then
        finish(s,f)
        if s.leaving then release(s) end
        return
    end
    local el=os.clock()-f.t0
    if f.style=='tachy' then
        if el<f.swap_at then return end
        wear(e.Mesh,f.to,true)
        relink(s,e)
        finish(s,f)
        if s.leaving then release(s) end
        return
    end
    local k=math.min(1,el/Suit.TIME)
    local h=Suit.H0+(Suit.H1-Suit.H0)*k
    local g=k>0.7 and math.sin((k-0.7)/0.3*math.pi)*4 or 0 -- the scene's cyan glow as the suit settles
    for _,m in ipairs(f.mids) do
        if valid(m) then
            m:SetScalarParameterValue(FName('HeightMask'),h)
            if g>0 then m:SetVectorParameterValue(FName('EmissiveColor'),{R=0.025*g,G=g,B=0.625*g,A=1}) end
        end
    end
    if f.decal_mid and valid(f.decal_mid) then f.decal_mid:SetScalarParameterValue(FName('OffsetY (S)'),-1.375*k) end
    if f.ring and valid(f.ring) then pcall(function() f.ring:SetNiagaraVariableFloat('Scale',2*(1-k)) end) end
    if k<1 then return end
    wear(e.Mesh,f.to,false) -- the mesh changed at the start: the real materials only
    finish(s,f)
    if s.leaving then release(s) end
end

-- At once: any change dropped, her own body and materials back (on the EVE she rode), the keepers gone. For a new
-- mount while the dismount's change still runs, and wherever no change can play.
function Suit.drop(s,e)
    if not s or s.done then return 'no suit' end
    if s.fx then finish(s,s.fx) end
    local said='her EVE is gone'
    if e and valid(e) and U.address(e)==s.eve and valid(s.keeper) then
        wear(e.Mesh,own(s),true) -- false: her animation keeps going
        said='her own body back'
    end
    release(s)
    return said
end

-- At the dismount: the mount's change played backward to her own outfit (s.done once over; Suit.tick runs it).
function Suit.off(s,e)
    if not s or s.done then return 'no suit' end
    if s.fx then finish(s,s.fx) end
    if s.style=='off' or not (e and valid(e) and U.address(e)==s.eve and valid(s.keeper)) then return Suit.drop(s,e) end
    s.leaving=true
    local said=change(e,s,s.style,own(s))
    if not s.fx then return Suit.drop(s,e)..' ('..said..')' end
    return said..' back to her own outfit'
end

return Suit
