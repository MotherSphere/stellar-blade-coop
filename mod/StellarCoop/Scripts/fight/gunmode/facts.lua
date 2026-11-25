-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Facts probe (dev builds only: gun_facts=on in coop-settings.txt; release_check.lua refuses it). Read-only
-- except F8, which plays one vanilla clip through a montage slot on a key press. Runs from fight/gunmode/mode.lua's tick
-- (the game thread), never from a key bind. Logs [GM] facts ... lines.
--   F5/F6  once, 5 s after EVE is in the world: her mesh components, anim classes (with parents), the post-process
--          instance and asset, and properties named like invincibility on the pawn and the anim instance.
--   F7     every 0.1 s: the anim instance's active montage (name and slots) whenever it changes.
--   F8     NumPadSeven / NumPadEight / NumPadNine: P_Eve_GunNikke_Shoot_Idle played as a dynamic montage on slot
--          DefaultSlot / UpperBody / FullBody of her anim instance.
local Facts={}

local SHOOT_IDLE='/Game/DLC_2/Art/Character/PC/CH_P_EVE_01/Animation/P_Eve_GunNikke_Shoot_Idle.P_Eve_GunNikke_Shoot_Idle'
local SLOTS={NumPadSeven='DefaultSlot',NumPadEight='UpperBody',NumPadNine='FullBody'}
local WORDS={'invinc','immune','nodamage','untarget','godmode','ignoredamage','superarmor','damageable'}

function Facts.new(g)
    local self={}
    local st={seen_at=nil,done=false,last_m='',poll=0,keys={}}
    local function name(o) return g.try(function() return o:GetFullName() end) or tostring(o) end
    local function valid(o) return o~=nil and g.try(function() return o:IsValid() end)==true end
    local function chain(cls)
        local out,d={},0
        while valid(cls) and d<10 do
            out[#out+1]=g.try(function() return cls:GetFName():ToString() end) or '?'
            cls=g.try(function() return cls:GetSuperStruct() end); d=d+1
        end
        return table.concat(out,' < ')
    end
    local function props_like(obj,label)
        local hits={}
        local cls=g.try(function() return obj:GetClass() end); local d=0
        while valid(cls) and d<10 do
            pcall(function() cls:ForEachProperty(function(pr)
                local n=pr:GetFName():ToString(); local l=n:lower()
                for _,w in ipairs(WORDS) do
                    if l:find(w,1,true) then
                        local v=g.try(function() local x=obj[n]; return type(x)=='userdata' and (g.try(function() return x:ToString() end) or 'obj') or tostring(x) end)
                        hits[#hits+1]=n..'='..tostring(v); break
                    end
                end
            end) end)
            cls=g.try(function() return cls:GetSuperStruct() end); d=d+1
        end
        g.log('facts F5 '..label..' invincibility-like properties: '..(#hits>0 and table.concat(hits,' ') or 'none'))
    end

    local function snapshot(p)
        local mesh=g.try(function() return p.Mesh end)
        g.log('facts F6 pawn '..name(p)..' class '..chain(g.try(function() return p:GetClass() end)))
        local ai=valid(mesh) and g.try(function() return mesh:GetAnimInstance() end)
        g.log('facts F6 Mesh '..name(mesh))
        g.log('facts F6 Mesh.SkeletalMesh '..name(g.try(function() return mesh.SkeletalMesh end)))
        g.log('facts F6 Mesh.AnimClass '..name(g.try(function() return mesh.AnimClass end)))
        g.log('facts F6 anim instance '..name(ai)..' class '..chain(valid(ai) and g.try(function() return ai:GetClass() end)))
        g.log('facts F6 SkeletalMesh.PostProcessAnimBlueprint '..name(g.try(function() return mesh.SkeletalMesh.PostProcessAnimBlueprint end)))
        local pp=g.try(function() return mesh:GetPostProcessInstance() end)
        g.log('facts F6 post-process instance '..(valid(pp) and (name(pp)..' class '..chain(g.try(function() return pp:GetClass() end))) or 'none ('..tostring(pp)..')'))
        g.log('facts F6 Mesh.bDisablePostProcessBlueprint '..tostring(g.try(function() return mesh.bDisablePostProcessBlueprint end)))
        -- every skeletal mesh component on her
        local n=0
        local all=g.try(function() return FindAllOf('SkeletalMeshComponent') end) or {}
        for _,c in ipairs(all) do
            if g.try(function() return c:GetOwner()==p end) or g.try(function() return c:GetOwner():GetFullName()==p:GetFullName() end) then
                n=n+1
                local sm=g.try(function() return c.SkeletalMesh end)
                local master=g.try(function() return c.MasterPoseComponent end)
                g.log(('facts F6 part %d: %s mesh %s anim %s master %s pp %s visible %s'):format(n,
                    g.try(function() return c:GetFName():ToString() end) or '?',
                    name(sm),name(g.try(function() return c:GetAnimInstance() end)),
                    valid(master) and (g.try(function() return master:GetFName():ToString() end) or '?') or '-',
                    name(g.try(function() return sm.PostProcessAnimBlueprint end)),
                    tostring(g.try(function() return c:IsVisible() end))))
            end
        end
        g.log('facts F6 '..n..' skeletal mesh components on her')
        props_like(p,'pawn')
        if valid(ai) then props_like(ai,'anim instance') end
    end

    local function montage(ai)
        local m=g.try(function() return ai:GetCurrentActiveMontage() end)
        local label='none'
        if valid(m) then
            local slots={}
            pcall(function() for i=1,#m.SlotAnimTracks do slots[#slots+1]=m.SlotAnimTracks[i].SlotName:ToString() end end)
            label=name(m)..' slots '..table.concat(slots,',')
        end
        if label~=st.last_m then st.last_m=label; g.log('facts F7 active montage: '..label) end
    end

    local function dprobe(ai,slot)
        local seq=g.try(function() return LoadAsset(SHOOT_IDLE) end) or g.try(function() return StaticFindObject(SHOOT_IDLE) end)
        if not valid(seq) then g.log('facts F8 '..slot..': clip did not load'); return end
        local ok,res=pcall(function() return ai:PlaySlotAnimationAsDynamicMontage(seq,FName(slot),0.2,0.2,1.0,1,-1.0,0.0) end)
        g.log('facts F8 '..slot..': call '..(ok and 'returned '..name(res) or 'failed: '..tostring(res))
            ..', active montage now '..name(g.try(function() return ai:GetCurrentActiveMontage() end)))
    end

    -- F11 (an early test): can Lua swap the mesh asset's PostProcessAnimBlueprint and have the game build that
    -- instance? At +25 s: the field set to another game post-process class (EVE_08's), then SetAnimClass(same class)
    -- to re-init; at +40 s the original put back the same way. Each step logs the instance class it finds.
    local OTHER='/Game/Art/Character/PC/CH_P_EVE_08/Blueprints/CH_P_EVE_08_AnimBP.CH_P_EVE_08_AnimBP_C'
    local function ppname(mesh) local pp=g.try(function() return mesh:GetPostProcessInstance() end); return valid(pp) and name(pp:GetClass()) or 'none' end
    local function swap(p,cls,label)
        local mesh=p.Mesh; local sk=mesh.SkeletalMesh
        g.log('facts F11 '..label..' before: field '..name(sk.PostProcessAnimBlueprint)..', instance '..ppname(mesh))
        local ok1,e1=pcall(function() sk.PostProcessAnimBlueprint=cls end)
        g.log('facts F11 '..label..' field write: '..(ok1 and 'ok, now '..name(sk.PostProcessAnimBlueprint) or tostring(e1)))
        local ok2,e2=pcall(function() mesh:SetAnimClass(mesh.AnimClass) end)
        g.log('facts F11 '..label..' SetAnimClass(same): '..(ok2 and 'ok' or tostring(e2))..', instance now '..ppname(mesh)
            ..', main '..name(g.try(function() return mesh:GetAnimInstance():GetClass() end)))
    end

    -- pc, p: controller and pawn (or nil); down(key name): held; now: os.clock().
    function self.tick(pc,p,down,now)
        if not (p and valid(p)) then st.seen_at=nil; return end
        local pn=name(p)
        if pn~=st.pawn then st.pawn,st.seen_at,st.done,st.d8=pn,now,false,3 end
        if not st.done and now-st.seen_at>=5 then st.done=true; local ok,e=pcall(snapshot,p); if not ok then g.log('facts snapshot: '..tostring(e)) end end
        local ai=g.try(function() return p.Mesh:GetAnimInstance() end)
        -- F14 (M1 layer test, replaces the F13 spike): fight/gunmode/overlay.lua installs the post-process layer at +15 s on a
        -- non-lobby pawn, then plays rifle clips on its arms-only slot on a timer so screenshots can be matched to the
        -- logged times, with the rifle in her right hand (rifle.lua's grip) from +18 s: carry (ShootReady_Start nearly
        -- frozen) +20 s, aim (Shoot_Idle looped) +35 s, reload looped +50 s, stop +65 s, rifle and layer removed +72 s.
        if st.done and not st.pawn:find('/Game/Lobby/',1,true) then
            st.ov=st.ov or require('fight.gunmode.overlay').new(g)
            local steps={
                {15,'install',function() return st.ov.install(p) end},
                {18,'rifle',function()
                    st.rf=require('fight.gunmode.rifle').new(function() return function() end,function() end end)
                    return st.rf.start(pc,function() return false end,function() return nil end) end},
                {20,'carry',function() return st.ov.play(p,'carry',0.02,1) end},
                {35,'aim',function() return st.ov.play(p,'aim',1.0,0) end},
                {50,'reload',function() return st.ov.play(p,'reload',1.0,0) end},
                {65,'stop',function() st.ov.stop(p); return true end},
                {72,'uninstall',function() if st.rf then st.rf.stop(); st.rf=nil end; return st.ov.uninstall(p) end},
            }
            st.f14=st.f14 or 0
            local nx=steps[st.f14+1]
            if st.rf then pcall(st.rf.frame) end
            if nx and now-st.seen_at>=nx[1] then
                st.f14=st.f14+1
                local ok,r,e=pcall(nx[3])
                g.log(('facts F14 %s at %s -> %s %s, layer active %s'):format(nx[2],os.date('%H:%M:%S'),
                    ok and name(r) or 'error',tostring(ok and e or r),tostring(g.try(function() return st.ov.active(p) end))))
            end
        end
        -- F11 retired (2026-11-18): holding a mesh asset and a class across a level load left stale wrappers.
        -- The put-back wrote a level object into the field. Any install test must re-fetch everything by path within
        -- one load. It must never write after a load through an object found before it.
        if not valid(ai) then return end
        if now-st.poll>=0.1 then st.poll=now; pcall(montage,ai) end
        -- F8 on a timer after the snapshot (the test harness can't press numpad keys): DefaultSlot at +5 s, UpperBody
        -- at +10 s, FullBody at +15 s, each logged with its time so screenshots can be matched.
        if st.done then
            local order={'DefaultSlot','UpperBody','FullBody'}
            st.d8=st.d8 or 0
            if st.d8<#order and now-st.seen_at>=10+5*st.d8 then
                st.d8=st.d8+1
                g.log(('facts F8 run %d at %s'):format(st.d8,os.date('%H:%M:%S')))
                pcall(dprobe,ai,order[st.d8])
            end
        end
    end
    return self
end

return Facts
