-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Development probe (gun_probe=on in coop-settings.txt): while the game's aim is held it runs timed camera tests and
-- logs what the HUD and the shots are made of. Nothing here runs unless the setting is on.
local Probe={}

function Probe.new(g)
    local self={}
    local s={aim_at=nil,phase=-1,arm=nil,sock=nil,hud_done=false}
    local function v3(a) return a and ('(%.0f,%.0f,%.0f)'):format(a.X,a.Y,a.Z) or '?' end

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

    -- The HUD's item column (potion, D-pad marker, drone slot): every widget under Overlay_ItemSlot with its class,
    -- visibility, opacity, slot and, for an image, its texture.
    function self.item_tree()
        local root
        pcall(function()
            for _,w in ipairs(FindAllOf('Overlay') or {}) do
                local full=w:GetFullName()
                if full:match('%.Overlay_ItemSlot$') and full:find('WB_MainHUD_Master',1,true) then root=w; break end
            end
        end)
        if not root then g.log('probe: no Overlay_ItemSlot'); return end
        local n=0
        local function walk(w,depth)
            n=n+1
            if n>160 or depth>14 then return end
            local cls=g.try(function() return w:GetClass():GetFName():ToString() end) or '?'
            local name=g.try(function() return w:GetFName():ToString() end) or '?'
            local vis=g.try(function() return w:GetVisibility() end)
            local op=g.try(function() return w:GetRenderOpacity() end)
            local slot=g.try(function() return w.Slot:GetClass():GetFName():ToString() end) or '-'
            local extra=''
            if cls=='Image' then
                extra=' tex '..(g.try(function() return w.Brush.ResourceObject:GetFName():ToString() end) or '?')..
                    (' size %s'):format(g.try(function() local s=w.Brush.ImageSize; return ('%.0fx%.0f'):format(s.X,s.Y) end) or '?')
            elseif cls=='TextBlock' then
                extra=' "'..(g.try(function() return w:GetText():ToString() end) or '?')..'"'
            end
            g.log(('probe: tree %s%s %s vis %s op %s slot %s%s'):format(string.rep('. ',depth),cls,name,tostring(vis),
                tostring(op),slot,extra))
            local count=g.try(function() return w:GetChildrenCount() end)
            if count then for i=0,count-1 do local c=g.try(function() return w:GetChildAt(i) end); if c then walk(c,depth+1) end end end
            local tree=g.try(function() return w.WidgetTree end)
            local rw=tree and g.try(function() return tree.RootWidget end)
            if rw and g.valid(rw) then walk(rw,depth+1) end
        end
        walk(root,0)
    end

    -- Functions about items, buckets and counts on the pawn, the controller, their states and every component of
    -- theirs (to read and spend the NIKKE rounds she carries).
    local function scan(label,c,words)
        local fns={}
        pcall(function()
            local guard=0
            while c and c:IsValid() and guard<8 do
                guard=guard+1
                c:ForEachFunction(function(f)
                    local n=f:GetFName():ToString()
                    for _,w in ipairs(words) do if n:find(w) then fns[#fns+1]=n; break end end
                end)
                c=c:GetSuperStruct()
            end
        end)
        for i=1,#fns,16 do g.log('probe: '..label..' fn '..table.concat(fns,' ',i,math.min(i+15,#fns))) end
    end
    -- The rifle's rounds as the game's own item: the bullet-change function's parameters, a change to Bullet_Nikke,
    -- and what the drone slot's count reads after it.
    function self.bullet_test()
        local pc,pawn=g.pc(),g.pawn()
        for _,fname in ipairs({'ServerRequest_ChangeBulletItem','ClientBroadcast_ActorSetBulletItem'}) do
            local f
            for _,cls in ipairs({'SBPlayerController','SBPlayerControllerBase','SBBasePlayerController'}) do
                f=f or StaticFindObject('/Script/SB.'..cls..':'..fname)
            end
            if f and f:IsValid() then
                local ps={}
                pcall(function() f:ForEachProperty(function(pr) ps[#ps+1]=pr:GetFName():ToString()..':'..pr:GetClass():GetFName():ToString() end) end)
                g.log('probe: '..f:GetFullName()..'('..table.concat(ps,', ')..')')
            else g.log('probe: no function object for '..fname) end
        end
        local before=g.try(function() return pawn:GetCurrentBulletItemAlias():ToString() end)
        g.log('probe: current bullet '..tostring(before))
        -- Each way in turn, read back after 0.3 s: the client-side set, then the server request with a drone round
        -- (to see whether the request works at all), then with NIKKE rounds.
        s.bullet_steps={
            {'ClientBroadcast_ActorSetBulletItem(pawn, Bullet_Nikke)',function() pc:ClientBroadcast_ActorSetBulletItem(pawn,FName('Bullet_Nikke')) end},
            {'ServerRequest_ChangeBulletItem(pawn, Bullet_Normal)',function() pc:ServerRequest_ChangeBulletItem(pawn,FName('Bullet_Normal')) end},
            {'ServerRequest_ChangeBulletItem(pawn, Bullet_Nikke)',function() pc:ServerRequest_ChangeBulletItem(pawn,FName('Bullet_Nikke')) end},
        }
        s.bullet_check=os.clock()+0.2
        s.bullet_before=before
    end
    function self.bullet_after()
        if not s.bullet_check or os.clock()<s.bullet_check then return end
        local function read()
            local now=g.try(function() return g.pawn():GetCurrentBulletItemAlias():ToString() end)
            local txt
            pcall(function()
                for _,t in ipairs(FindAllOf('TextBlock') or {}) do
                    local full=t:GetFullName()
                    if full:find('WB_MainHUD_Lower1Item.WidgetTree.WB_MainHUD_ItemSlotGeneral.WidgetTree.TextBlock_Item_Count',1,true) then
                        txt=t:GetText():ToString()
                    end
                end
            end)
            return tostring(now)..', drone slot count "'..tostring(txt)..'"'
        end
        if s.bullet_pending then g.log('probe:   -> current bullet '..read()); s.bullet_pending=nil end
        local step=s.bullet_steps and table.remove(s.bullet_steps,1)
        if not step then s.bullet_check=nil; return end
        local ok,err=pcall(step[2])
        g.log('probe: '..step[1]..': '..(ok and 'called' or tostring(err)))
        s.bullet_pending=true
        s.bullet_check=os.clock()+0.4
    end

    function self.item_fns()
        local words={'Item','Bullet','Count','Inven','Bucket'}
        pcall(function() scan('pawn',g.pawn():GetClass(),words) end)
        pcall(function() scan('pc',g.pc():GetClass(),words) end)
        pcall(function() scan('lib',StaticFindObject('/Script/SB.SBBlueprintLibrary'),words) end)
    end

    -- The heal item slot's and the D-pad's images and texts (names, textures, sizes) for the rifle's slot.
    function self.slot_parts()
        for _,kind in ipairs({'Image','TextBlock'}) do
            pcall(function()
                for _,w in ipairs(FindAllOf(kind) or {}) do
                    local full=w:GetFullName()
                    if full:find('WB_MainHUD_Master',1,true) and (full:find('WB_MainHUD_HealItem',1,true) or full:find('WB_MainHUD_Dpad',1,true)) then
                        local extra=''
                        if kind=='Image' then
                            extra=' tex '..(g.try(function() return w.Brush.ResourceObject:GetFName():ToString() end) or '?')..
                                (' size %s'):format(g.try(function() local s=w.Brush.ImageSize; return ('%.0fx%.0f'):format(s.X,s.Y) end) or '?')
                        else extra=' "'..(g.try(function() return w:GetText():ToString() end) or '?')..'"' end
                        g.log(('probe: part %s vis %s%s'):format(full:match('MainHUD_Master_C_%d+%.(.*)$') or full,
                            tostring(g.try(function() return w:GetVisibility() end)),extra))
                    end
                end
            end)
        end
    end

    -- Called every frame from the gun mode tick in the game's aim (aim: bTPSMode): logs only.
    function self.tick(pc,p,aim,firing,now)
        local cm=g.try(function() return pc.PlayerCameraManager end)
        if not cm then return end
        if not aim then
            s.aim_at=nil
            return
        end
        pcall(self.bullet_after)
        if not s.aim_at then s.aim_at=now end
        local t=now-s.aim_at
        if t>2 and not s.hud_done then s.hud_done=true; pcall(self.item_fns); pcall(self.bullet_test) end
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
