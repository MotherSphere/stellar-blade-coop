-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's post-process layer (M1). Her body mesh's post-process anim blueprint is swapped for ABP_NGM_Spike
-- (gunmode's pak, zNGMSpike_P), which takes her finished vanilla pose, plays a rifle clip through its own DefaultSlot on the arms
-- only (both clavicles down, mesh-space rotation), then runs the outfit's original post-process graph (BtoB on the
-- vanilla bodies) as a linked graph tagged Orig. The main anim instance, its springs and the outfit physics are
-- never touched.
-- Rules (learned the hard way in game):
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
-- the solver places the arms; the clip on the slot only gives the hands their grip (the layer's Layered Blend
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

-- the layer's class is loadable (gunmode's pak is installed). loaded: the class while it is in memory, with no walk
-- (fight/gunmode/mode.lua's g.loaded, 17a166fa); StaticFindObject without it.
function Overlay.available(loaded)
    local ok,r=pcall(function()
        local o=(loaded or StaticFindObject)(Overlay.CLASS)
        if o and o:IsValid() then return true end
        o=StaticFindObject('/Script/AssetRegistry.Default__AssetRegistryHelpers'):GetAsset({ObjectPath=FName(Overlay.CLASS)})
        return o~=nil and o:IsValid()
    end)
    return ok and r==true
end

function Overlay.new(g)
    local self={}
    local st={patched={}}   -- strings and numbers only (patched: each body mesh path given our class -> its own class path, or false)
    local function valid(o) return o~=nil and g.try(function() return o:IsValid() end)==true end
    local function name(o) return g.try(function() return o:GetFullName() end) or tostring(o) end
    local function path_of(o) local f=g.try(function() return o:GetFullName() end); return f and f:match('^%S+ (.+)$') end
    local slot -- FName('DefaultSlot'), made once
    -- path -> object, checked by its path before each use (b71e6f6f). Nothing of gun mode holds the clips across a
    -- map change. Another object can then sit at a freed address and pass IsValid.
    local found={}
    -- An asset in memory, with no walk of the object array (fight/gunmode/mode.lua's g.loaded: the keep, else the
    -- engine's name hash, 17a166fa), else nil.
    local function loaded(path)
        if g.loaded then return g.loaded(path) end
        local o=StaticFindObject(path)
        if valid(o) then return o end
    end
    local function find(path)
        local c=found[path]; if c and valid(c) and path_of(c)==path then return c end
        local o=loaded(path)
        if valid(o) then found[path]=o; return o end
        local ok,r=pcall(function()
            return StaticFindObject('/Script/AssetRegistry.Default__AssetRegistryHelpers'):GetAsset({ObjectPath=FName(path)})
        end)
        if ok and valid(r) then found[path]=r; return r end
        pcall(LoadAsset,path)   -- base-game assets
        o=loaded(path)
        if valid(o) then found[path]=o; return o end
        return nil
    end
    -- One of Overlay.CLIPS (or a full object path), or a rebuild body. A path missed once is not in the installed paks
    -- (an older zNGMSpike_P without the v4 poses, or a body of another build): it is not looked up again this Lua load
    -- (6057c7a5). Each miss walks the object array twice and tries a load (50 to 70 ms), while the tick asks for the
    -- clip each frame and each rifle out asks for the body.
    local missing={}
    local function have(path)
        if missing[path] then return nil end
        local o=find(path)
        if not o then missing[path]=true end
        return o
    end
    local function clip_of(clip) return have(Overlay.CLIPS[clip] or clip) end
    local function pp_of(mesh) local pp=g.try(function() return mesh:GetPostProcessInstance() end); return valid(pp) and pp or nil end
    local function rebuild(mesh,sk,cls)
        local mine=path_of(sk); local base
        -- a body already in memory first: no body loaded on the frame of the press (17a166fa)
        for _,b in ipairs(Overlay.BASES) do if b~=mine and not base and not missing[b] then base=loaded(b) end end
        for _,b in ipairs(Overlay.BASES) do if b~=mine and not base then base=have(b) end end
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
        if cur_path~=Overlay.CLASS then
            st.orig_cls,st.orig_mesh=cur_path,path_of(sk)
            if st.orig_mesh then st.patched[st.orig_mesh]=cur_path or false end
        end
        local ok,e=rebuild(mesh,sk,cls); if not ok then return false,e end
        local pp=pp_of(mesh)
        if not pp then return false,'no post-process instance after rebuild' end
        -- the graph's default linked class is the vanilla BtoB; relink when her outfit had another one (or none)
        local link=st.orig_cls and find(st.orig_cls) or nil
        local okl,el=pcall(function() pp:LinkAnimGraphByTag(FName('Orig'),link) end)
        g.log('overlay installed: '..name(pp)..', Orig -> '..tostring(st.orig_cls)..(okl and '' or (' (link error '..tostring(el)..')')))
        return true
    end

    function self.uninstall(p)
        local mesh=p.Mesh; local sk=mesh.SkeletalMesh
        local mine=path_of(sk)
        -- bodies worn earlier while the layer was on (an outfit change) still name it on their asset: theirs put back
        -- (loaded assets only: one unloaded since has lost the change anyway)
        for path,orig in pairs(st.patched) do
            if path~=mine then
                local o=StaticFindObject(path)
                local c=orig and find(orig) or nil
                if valid(o) and (orig==false or c) then pcall(function() o.PostProcessAnimBlueprint=c end) end
                st.patched[path]=nil
            end
        end
        if not self.active(p) then return true end
        if mine~=st.orig_mesh then g.log('overlay: outfit changed since install, each body gets its own class back') end
        local orig=mine and st.patched[mine]; if orig==nil then orig=st.orig_cls end
        if mine then st.patched[mine]=nil end
        local cls=orig and find(orig) or nil
        local ok,e=rebuild(mesh,sk,cls)
        g.log('overlay removed: post-process now '..name(g.try(function() return pp_of(mesh):GetClass() end))..(ok and '' or (' error '..tostring(e))))
        return ok,e
    end

    -- play one of Overlay.CLIPS (or a full object path) on the layer's DefaultSlot; loops<=0 holds it indefinitely
    function self.play(p,clip,rate,loops,blend_in,blend_out)
        local pp=pp_of(p.Mesh); if not pp then return nil,'layer not installed' end
        local seq=clip_of(clip); if not seq then return nil,'clip not found '..tostring(clip) end
        local ok,m=pcall(function()
            slot=slot or FName('DefaultSlot') -- (made once: b812f708)
            return pp:PlaySlotAnimationAsDynamicMontage(seq,slot,blend_in or 0.15,blend_out or 0.15,
                rate or 1.0,(loops and loops>0) and loops or 100000,-1.0,0.0)
        end)
        if not ok then return nil,tostring(m) end
        return m
    end

    function self.stop(p,blend_out)
        local pp=pp_of(p.Mesh); if not pp then return end
        slot=slot or FName('DefaultSlot')
        pcall(function() pp:StopSlotAnimation(blend_out or 0.15,slot) end)
    end

    -- the layer's upper-body turn (AimRot, added to Bip001-Spine1 in component space): a property write only
    function self.set_turn(p,r)
        local pp=pp_of(p.Mesh); if not pp then return false,'no layer instance' end
        return pcall(function() pp.AimRot={Pitch=r.Pitch,Yaw=r.Yaw,Roll=r.Roll} end)
    end
    -- a clip's length in seconds, or nil (the reload clip is fitted to the reload time with it)
    function self.length(clip)
        local seq=clip_of(clip)
        return seq and g.try(function() return seq:GetPlayLength() end)
    end
    -- whether one of Overlay.CLIPS is still playing on the layer's DefaultSlot (the asset is a loaded clip, never a
    -- montage object that the game may already have freed)
    function self.playing(p,clip)
        local pp=pp_of(p.Mesh); if not pp then return false end
        local seq=clip_of(clip); if not seq then return false end
        slot=slot or FName('DefaultSlot')
        return g.try(function() return pp:IsPlayingSlotAnimation(seq,slot) end)==true
    end
    return self
end

return Overlay
