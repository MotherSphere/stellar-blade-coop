-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Development probe (gun_probe=on in coop-settings.txt): while the game's aim is held it runs timed camera tests and
-- logs what the HUD and the shots are made of. Nothing here runs unless the setting is on.
local Probe={}

function Probe.new(g)
    local self={}
    local s={aim_at=nil,phase=-1,arm=nil,sock=nil,actors={},counting=false,hud_done=false,seen=0}
    local function v3(a) return a and ('(%.0f,%.0f,%.0f)'):format(a.X,a.Y,a.Z) or '?' end

    -- Every new actor while firing: its class, once each (what a shot spawns).
    function self.hook_actors()
        pcall(function()
            NotifyOnNewObject('/Script/Engine.Actor',function(a)
                if not s.counting then return end
                s.seen=s.seen+1
                local ok,n=pcall(function() return a:GetClass():GetFName():ToString() end)
                n=ok and n or '?'
                s.actors[n]=(s.actors[n] or 0)+1
            end)
        end)
    end

    local WORDS={'TPS','Aim','Bullet','Drone','Reticle','Cross','Ammo','Gun','Nikke'}
    local function hit(n) for _,w in ipairs(WORDS) do if n:find(w) then return true end end end
    local function hud(pc)
        local classes={}
        pcall(function()
            for _,w in ipairs(FindAllOf('UserWidget') or {}) do
                local n=w:GetClass():GetFName():ToString()
                if hit(n) then classes[n]=(classes[n] or 0)+1 end
            end
        end)
        local cl={}
        for n,c in pairs(classes) do cl[#cl+1]=n..'x'..c end
        g.log('probe: widget classes: '..table.concat(cl,' '))
        for _,kind in ipairs({'TextBlock','Image','RichTextBlock'}) do
            local n=0
            pcall(function()
                for _,t in ipairs(FindAllOf(kind) or {}) do
                    local full=t:GetFullName()
                    if full:find('MainHUD') and hit(full) and n<60 then
                        n=n+1
                        local txt=''
                        if kind~='Image' then txt=g.try(function() return t:GetText():ToString() end) or '?' end
                        local vis=g.try(function() return t:GetVisibility() end)
                        local op=g.try(function() return t:GetRenderOpacity() end)
                        g.log(('probe: %s %s vis %s op %s "%s"'):format(kind,full:gsub('^.-WB_MainHUD_Master_C_%d+%.',''),
                            tostring(vis),tostring(op),txt))
                    end
                end
            end)
        end
        -- The character's functions about skills, effects and rounds (what a shot can be counted with).
        local fns={}
        pcall(function()
            local c=g.pawn():GetClass()
            local guard=0
            while c and c:IsValid() and guard<8 do
                guard=guard+1
                c:ForEachFunction(function(f)
                    local n=f:GetFName():ToString()
                    if n:find('Skill') or n:find('Effect') or n:find('Bullet') or n:find('TPS') then fns[#fns+1]=n end
                end)
                c=c:GetSuperStruct()
            end
        end)
        for i=1,#fns,25 do g.log('probe: fn '..table.concat(fns,' ',i,math.min(i+24,#fns))) end
    end

    -- Called every frame from the gun mode tick in the game's aim (aim: bTPSMode): logs only.
    function self.tick(pc,p,aim,firing,now)
        local cm=g.try(function() return pc.PlayerCameraManager end)
        if not cm then return end
        s.counting=aim and firing
        if not aim then
            if s.aim_at then
                local list={}
                for n,c in pairs(s.actors) do list[#list+1]=n..'x'..c end
                g.log('probe: actors spawned while firing ('..s.seen..'): '..table.concat(list,' '))
            end
            s.aim_at=nil
            return
        end
        if not s.aim_at then s.aim_at=now end
        local t=now-s.aim_at
        if t>2 and not s.hud_done then s.hud_done=true; hud(pc) end
        local run=g.try(function() return p:IsRunningSkill() end)
        if run and not s.run then s.edges=(s.edges or 0)+1 end
        s.run=run
        s.frames=(s.frames or 0)+1
        if now-(s.log_at or 0)>=1.0 then
            s.log_at=now
            pcall(function()
                local cl,el=cm:GetCameraLocation(),p:K2_GetActorLocation()
                local d=math.sqrt((cl.X-el.X)^2+(cl.Y-el.Y)^2+(cl.Z-el.Z)^2)
                g.log(('probe: t %.1f dist %.0f fov %.1f firing %s skill edges %d frames %d'):format(t,d,
                    cm:GetFOVAngle(),tostring(firing),s.edges or 0,s.frames))
            end)
            s.edges,s.frames=0,0
        end
    end
    return self
end

return Probe
