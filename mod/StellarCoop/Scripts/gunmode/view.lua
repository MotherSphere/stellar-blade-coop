-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- What gun mode keeps on screen: the main HUD the NIKKE mode hides, and the reticle.
-- * HUD: the widgets showing before gun mode (walked inside every visible root, WB_MainHUD_Master's children included)
--   are remembered; any of them the NIKKE mode hides or fades is shown again (entry +1 s, +2.5 s, then every 1.5 s).
--   Its own TPS, NIKKE and aim widgets are left alone.
-- * Reticle: WB_NikkeHUD_Aim_C and WB_Tps_Aim_C scaled up, the live (transient) ones made visible standing; the
--   player cameras' AspectRatio set to the screen's with bConstrainAspectRatio, so the pin's X is clamped to the whole
--   screen and not to a 16:9 part of it.
-- All of it runs from one-off calls of gun mode's delay queue, never every frame.
local View={}

local AIMS={'WB_NikkeHUD_Aim_C','WB_Tps_Aim_C'}
local VISIBLE={[0]=true,[3]=true,[4]=true} -- ESlateVisibility: Visible, HitTestInvisible, SelfHitTestInvisible.

-- Whether gun mode leaves a widget at path (its own reticle and TPS widgets) alone.
function View.own(path)
    return path:find('Tps',1,true) or path:find('Nikke',1,true) or path:find('Aim',1,true)
end

-- g: gun mode's shared state (gunmode/mode.lua).
function View.new(g)
    local self={hud={},aspect={}}

    local function walk(w,depth,out,path)
        if #out>1500 or depth>12 then return end
        local name=g.try(function() return w:GetFName():ToString() end) or '?'
        local vis=g.try(function() return w:GetVisibility() end)
        local op=g.try(function() return w:GetRenderOpacity() end) or 1.0
        path=path..'/'..name
        if vis~=nil then out[#out+1]={w=w,vis=vis,op=op,path=path} end
        local n=g.try(function() return w:GetChildrenCount() end) or 0
        for i=0,n-1 do
            local c=g.try(function() return w:GetChildAt(i) end)
            if g.valid(c) then walk(c,depth+1,out,path) end
        end
        local root=g.try(function() local t=w.WidgetTree; if g.valid(t) then return t.RootWidget end end)
        if g.valid(root) then walk(root,depth+1,out,path) end
    end
    function self.hud_snapshot()
        self.hud={}
        for _,w in ipairs(g.try(function() return FindAllOf('UserWidget') end) or {}) do
            pcall(function()
                if not (w:IsInViewport() and w:IsVisible()) then return end
                local out={}
                walk(w,0,out,'')
                for _,e in ipairs(out) do
                    if VISIBLE[e.vis] and e.op>0.05 and not View.own(e.path) then self.hud[#self.hud+1]=e end
                end
            end)
        end
    end
    function self.hud_restore()
        local n=0
        for _,e in ipairs(self.hud) do
            pcall(function()
                if not g.valid(e.w) then return end
                local vis,op=e.w:GetVisibility(),e.w:GetRenderOpacity()
                if vis==1 or vis==2 or op<e.op*0.5 then
                    e.w:SetVisibility(e.vis)
                    if op<e.op then e.w:SetRenderOpacity(e.op) end
                    n=n+1
                end
            end)
        end
        return n
    end

    function self.reticle_scale(scale)
        for _,cls in ipairs(AIMS) do
            for _,w in ipairs(g.try(function() return FindAllOf(cls) end) or {}) do
                if g.valid(w) then pcall(function() w:SetRenderScale({X=scale,Y=scale}) end) end
            end
        end
    end
    -- Standing: the live reticle widgets visible (WB_MainHUD_TpsMaster hides them outside the drone aim).
    function self.reticle_show()
        for _,cls in ipairs({'WB_MainHUD_TpsMaster_C','WB_Tps_Aim_C','WB_NikkeHUD_Aim_C'}) do
            for _,w in ipairs(g.try(function() return FindAllOf(cls) end) or {}) do
                local live=g.valid(w) and (g.try(function() return w:GetFullName() end) or ''):find('Transient',1,true)
                if live then
                    local vis=g.try(function() return w:GetVisibility() end)
                    if not VISIBLE[vis] then pcall(function() w:SetVisibility(3) end) end
                    local op=g.try(function() return w:GetRenderOpacity() end)
                    if op and op<0.99 then pcall(function() w:SetRenderOpacity(1.0) end) end
                end
            end
        end
    end

    local function screen_aspect()
        return g.try(function()
            local pt=FindFirstOf('GameUserSettings'):GetScreenResolution()
            if pt.Y>0 then return pt.X/pt.Y end
        end)
    end
    function self.wide(on)
        if not on then
            for k,v in pairs(self.aspect) do
                pcall(function() if g.valid(v.c) then v.c.AspectRatio=v.ar; v.c.bConstrainAspectRatio=v.cn end end)
                self.aspect[k]=nil
            end
            return
        end
        local asp,p=screen_aspect(),g.pawn()
        if not (asp and p) then return end
        local mine={[p:GetFullName()]=true}
        local pcm=g.try(function() return g.pc().PlayerCameraManager end)
        if g.valid(pcm) then mine[pcm:GetFullName()]=true end
        for _,cls in ipairs({'SBCameraComponent','CameraComponent'}) do
            for _,c in ipairs(g.try(function() return FindAllOf(cls) end) or {}) do
                pcall(function()
                    local key=c:GetFullName()
                    local o=c:GetOwner()
                    if self.aspect[key] or not (g.valid(o) and mine[o:GetFullName()]) then return end
                    self.aspect[key]={c=c,ar=c.AspectRatio,cn=c.bConstrainAspectRatio}
                    c.AspectRatio=asp
                    c.bConstrainAspectRatio=true
                end)
            end
        end
    end

    return self
end

return View
