-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's post-process layer. Her body mesh's post-process anim blueprint is swapped for ABP_NGM_Spike
-- (Overlay.CLASS, in zNGMSpike_P), which takes her finished vanilla pose, plays a rifle clip through its own
-- DefaultSlot on the arms only (both clavicles down, mesh-space rotation), then runs the outfit's original
-- post-process graph (BtoB on the vanilla bodies) as a linked graph tagged Orig. The main anim instance, its springs
-- and the outfit physics are never touched.
-- Rules learned in play:
--   * every UObject is fetched fresh in the call that uses it; nothing is kept across ticks except paths (strings)
--   * mod-pak classes load through AssetRegistryHelpers:GetAsset (UE4SS LoadAsset can't see mod-pak packages)
--   * the instance is rebuilt by SetSkeletalMesh(base body) then SetSkeletalMesh(her mesh), in one call
local Overlay={}

Overlay.CLASS='/Game/Mods/NGM/ABP_NGM_Spike.ABP_NGM_Spike_C'
-- the body briefly swapped in to make the engine rebuild the post-process instance (any body but hers will do)
Overlay.BASES={'/Game/Art/Character/PC/CH_P_EVE_29/CH_P_EVE_29.CH_P_EVE_29','/Game/Art/Character/PC/CH_P_EVE_01/CH_P_EVE_01.CH_P_EVE_01'}
-- the two-handed rifle clips made on her skeleton for this rifle (Blender Rifle10: both hands on the rifle by IK, the
-- sight at her right eye); only the arms are used, from the clavicles down
local NGM='/Game/Art/Character/PC/CH_P_EVE_01/Animation/NGM/'
-- The solver places the arms; the clip on the slot only gives the hands their grip (the layer's Layered Blend
-- Per Bone takes Bip001-L-Hand / Bip001-R-Hand and their fingers from it): NIKKE's own rifle idle, a vanilla DLC asset
local SHOOT_IDLE='/Game/DLC_2/Art/Character/PC/CH_P_EVE_01/Animation/P_Eve_GunNikke_Shoot_Idle.P_Eve_GunNikke_Shoot_Idle'
local RELOAD='/Game/DLC_2/Art/Character/PC/CH_P_EVE_01/Animation/P_Eve_GunNikke_Reload.P_Eve_GunNikke_Reload'
-- v3c: the clip leads her upper body (the layer's blend takes everything from Bip001-Neck down)
-- the authored v4 poses (NikkeGunBuild\poses, packed in zNGMSpike_P under Mods/NGM/Poses); grips in fight/gunmode/rifle.lua GRIPS
local POSE='/Game/Mods/NGM/Poses/NGM_Pose_%s.NGM_Pose_%s'
-- reload: the carry pose; the rifle's tilt and the left hand's trip to the magazine are fight/gunmode/ik.lua's (pin_reload)
Overlay.CLIPS={ carry=POSE:format('CarryLowReady','CarryLowReady'), aim=POSE:format('AimLevel','AimLevel'),
    aimup=POSE:format('AimUp45','AimUp45'), aimdown=POSE:format('AimDown45','AimDown45'),
    reload=POSE:format('CarryLowReady','CarryLowReady'), nikke=SHOOT_IDLE, nikke_reload=RELOAD }

-- the layer's class is loadable (zNGMSpike_P is installed)
function Overlay.available()
    local ok,r=pcall(function()
        local o=StaticFindObject(Overlay.CLASS)
        if o and o:IsValid() then return true end
        o=StaticFindObject('/Script/AssetRegistry.Default__AssetRegistryHelpers'):GetAsset({ObjectPath=FName(Overlay.CLASS)})
        return o~=nil and o:IsValid()
    end)
    return ok and r==true
end

function Overlay.new(g)
    local self={}
    -- strings and numbers only. meshes: each body mesh the layer went on (its path) -> its own post-process class's
    -- path ('' for none), until it is put back; coop-gun.txt keeps them (records, adopt).
    local st={meshes={}}
    local function valid(o) return o~=nil and g.try(function() return o:IsValid() end)==true end
    local function name(o) return g.try(function() return o:GetFullName() end) or tostring(o) end
    local function path_of(o) local f=g.try(function() return o:GetFullName() end); return f and f:match('^%S+ (.+)$') end
    local slot -- FName('DefaultSlot'), made once
    local found={} -- path -> object (the clips stay loaded while the layer is on); checked before each use
    local function find(path)
        local c=found[path]; if c and valid(c) then return c end
        local o=StaticFindObject(path)
        if valid(o) then found[path]=o; return o end
        local ok,r=pcall(function()
            return StaticFindObject('/Script/AssetRegistry.Default__AssetRegistryHelpers'):GetAsset({ObjectPath=FName(path)})
        end)
        if ok and valid(r) then found[path]=r; return r end
        pcall(LoadAsset,path)   -- base-game assets
        o=StaticFindObject(path)
        if valid(o) then found[path]=o; return o end
        return nil
    end
    local function pp_of(mesh) local pp=g.try(function() return mesh:GetPostProcessInstance() end); return valid(pp) and pp or nil end
    local function rebuild(mesh,sk,cls)
        local mine=path_of(sk); local base
        for _,b in ipairs(Overlay.BASES) do if b~=mine then base=find(b); if base then break end end end
        if not valid(base) then return false,'no other body to rebuild with' end
        sk.PostProcessAnimBlueprint=cls
        mesh:SetSkeletalMesh(base,false); mesh:SetSkeletalMesh(sk,false)
        return true
    end

    -- true when our layer is the running post-process instance on this pawn's body
    function self.active(p)
        local mesh=g.try(function() return p.Mesh end); if not valid(mesh) then return false end
        local pp=pp_of(mesh)
        return pp~=nil and (path_of(g.try(function() return pp:GetClass() end)) or '')==Overlay.CLASS
    end

    function self.install(p)
        local mesh=p.Mesh; local sk=mesh.SkeletalMesh
        if not valid(sk) then return false,'no body mesh' end
        if self.active(p) then return true end
        local cls=find(Overlay.CLASS)
        if not cls then return false,'layer class not found (pak missing?)' end
        local cur=g.try(function() return sk.PostProcessAnimBlueprint end)
        local cur_path=valid(cur) and path_of(cur) or nil
        local mine=path_of(sk)
        if cur_path~=Overlay.CLASS then st.meshes[mine]=cur_path or '' end
        local orig=st.meshes[mine]
        local ok,e=rebuild(mesh,sk,cls); if not ok then return false,e end
        local pp=pp_of(mesh)
        if not pp then return false,'no post-process instance after rebuild' end
        -- the graph's default linked class is the vanilla BtoB; relink when her outfit had another one (or none)
        local link=orig and orig~='' and find(orig) or nil
        local okl,el=pcall(function() pp:LinkAnimGraphByTag(FName('Orig'),link) end)
        g.log('overlay installed: '..name(pp)..', Orig -> '..tostring(orig)..(okl and '' or (' (link error '..tostring(el)..')')))
        return true
    end

    -- Every body mesh the layer went on gets its own post-process class back. The one this pawn wears is rebuilt with
    -- it, the layer's arms let go first (ArmsAlpha 0, in case the rebuild fails); the others get it on the asset, if
    -- still loaded. p may be nil (no pawn yet: the assets only). A mesh that fails stays listed. true, or false and
    -- why.
    function self.uninstall(p)
        local mesh=p and g.try(function() return p.Mesh end)
        mesh=valid(mesh) and mesh or nil
        local worn=mesh and g.try(function() return mesh.SkeletalMesh end)
        local worn_path=valid(worn) and path_of(worn) or nil
        local ok,why=true,nil
        for path,orig in pairs(st.meshes) do
            local done,e=pcall(function()
                local cls=orig~='' and find(orig) or nil
                assert(orig=='' or cls,'its class '..orig..' was not found')
                if path==worn_path and self.active(p) then
                    local pp=pp_of(mesh)
                    pcall(function() pp.ArmsAlpha=0 end)
                    local r,re=rebuild(mesh,worn,cls)
                    assert(r,re)
                    local now=g.try(function() return pp_of(mesh):GetClass() end)
                    g.log('overlay removed: post-process now '..name(now))
                    return
                end
                local sk=path==worn_path and worn or StaticFindObject(path)
                if valid(sk) and path_of(g.try(function() return sk.PostProcessAnimBlueprint end))==Overlay.CLASS then
                    sk.PostProcessAnimBlueprint=cls
                    g.log('overlay: '..path..' has '..(orig~='' and orig or 'no post-process class')..' again')
                end
            end)
            if done then st.meshes[path]=nil else ok,why=false,path..': '..tostring(e) end
        end
        return ok,why
    end
    -- coop-gun.txt's records for the meshes still listed (fight/gunmode/journal.lua).
    function self.records()
        local out={}
        for path,orig in pairs(st.meshes) do out[#out+1]={'pp',path,orig} end
        return out
    end
    -- An earlier Lua load's record: that mesh listed with its own class, unless this load listed it already.
    function self.adopt(path,orig) if st.meshes[path]==nil then st.meshes[path]=orig end end

    -- play one of Overlay.CLIPS (or a full object path) on the layer's DefaultSlot; loops<=0 holds it indefinitely
    function self.play(p,clip,rate,loops,blend_in,blend_out)
        local pp=pp_of(p.Mesh); if not pp then return nil,'layer not installed' end
        local seq=find(Overlay.CLIPS[clip] or clip); if not seq then return nil,'clip not found '..tostring(clip) end
        local ok,m=pcall(function()
            return pp:PlaySlotAnimationAsDynamicMontage(seq,FName('DefaultSlot'),blend_in or 0.15,blend_out or 0.15,
                rate or 1.0,(loops and loops>0) and loops or 100000,-1.0,0.0)
        end)
        if not ok then return nil,tostring(m) end
        return m
    end

    function self.stop(p,blend_out)
        local pp=pp_of(p.Mesh); if not pp then return end
        pcall(function() pp:StopSlotAnimation(blend_out or 0.15,FName('DefaultSlot')) end)
    end

    -- the layer's upper-body turn (AimRot, added to Bip001-Spine1 in component space): a property write only
    function self.set_turn(p,r)
        local pp=pp_of(p.Mesh); if not pp then return false,'no layer instance' end
        return pcall(function() pp.AimRot={Pitch=r.Pitch,Yaw=r.Yaw,Roll=r.Roll} end)
    end
    -- a clip's length in seconds, or nil (the reload clip is fitted to the reload time with it)
    function self.length(clip)
        local seq=find(Overlay.CLIPS[clip] or clip)
        return seq and g.try(function() return seq:GetPlayLength() end)
    end
    -- whether one of Overlay.CLIPS is still playing on the layer's DefaultSlot (the asset is a loaded clip, never a
    -- montage object that the game may already have freed)
    function self.playing(p,clip)
        local pp=pp_of(p.Mesh); if not pp then return false end
        local seq=find(Overlay.CLIPS[clip] or clip); if not seq then return false end
        slot=slot or FName('DefaultSlot')
        return g.try(function() return pp:IsPlayingSlotAnimation(seq,slot) end)==true
    end
    return self
end

return Overlay
