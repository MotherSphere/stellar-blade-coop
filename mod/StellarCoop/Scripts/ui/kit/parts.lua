-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Blade's own widget parts for the SBO screens made of them (online/lobby/ui/lobby.lua,
-- online/session/ui/sessions.lua, online/session/ui/create.lua and online/session/join.lua's popups): each part's
-- object path and class; for one screen (new), the helpers that make, remake and drive them. A part is made in a
-- ui/kit/kit.lua group (kit.part) from a spec. It is made again when its slot's content or place changes or its root
-- went (a map change); a call on one runs in pcall and a refusal is logged once a kind; a kind that cannot be made is
-- logged once and left out until the mod reloads, so the screen draws its kit fallback in its place.
local Parts={}
-- Each kind's path under /Game/Art/UI/Widget/, in the parts check's order (online/lobby/ui/lobby.lua). slider (the
-- settings menu's slider slot: closet/ui/view.lua's number rows) is not in that check: a screen without it shows the
-- kit row instead.
Parts.ORDER={'row','option','header','hint','popup','count'}
local PATH={row='Lobby/WB_Lobby_Menu_Slot',option='GameMenu/Setting/Slot/WB_Setting_Button_Slot',
    header='GameMenu/Setting/Slot/WB_Setting_Category',hint='GameMenu/Common/Indicator/WB_Common_IndicatorBtnDefault',
    popup='GameMenu/Common/WB_Common_Popup',count='HUD/WB_MainHUD_CountDown',
    slider='GameMenu/Setting/Slot/WB_Setting_Slider_Slot'}
-- Each kind's object path (kit.warm_part) and class (kit.part).
Parts.ASSET,Parts.CLASS={},{}
for kind,p in pairs(PATH) do
    Parts.ASSET[kind]='/Game/Art/UI/Widget/'..p..'.'..p:match('[^/]+$')
    Parts.CLASS[kind]=Parts.ASSET[kind]..'_C'
end
-- A key hint's spec at x, y: its label and icons (SB's resource actions, the second one optional); a hint never takes
-- a click.
function Parts.hint(x,y,label,icon,icon2)
    return {kind='hint',x=x,y=y,sig=label..icon..(icon2 or ''),fill=function(w)
        w:SetText(FText(label))
        w:SetResourceAction(FName(icon))
        w:SetResourceAction2(FName(icon2 or 'None'))
        w:SetButtonClickable(false)
    end}
end
-- A header's spec (WB_Setting_Category) at x, y.
function Parts.header(x,y,label)
    return {kind='header',x=x,y=y,sig=label,fill=function(w) w.Category_Name=FText(label) end}
end
-- One screen's helpers over kit (ui/kit/kit.lua's) and log, whose lines start with who ('lobby: ...'). broken: the
-- kinds left out until the mod reloads.
function Parts.new(kit,log,who)
    local self,said={broken={}},{}
    local broken=self.broken
    -- A call on a part while it is ours; a refusal logged once a kind (what).
    function self.call(rec,what,f)
        local w=rec and kit.alive(rec)
        if not w then return end
        local ok,why=pcall(f,w)
        if not ok and not said[what] then
            said[what]=true
            log(who..': '..what..' refused: '..tostring(why))
        end
    end
    -- A part of kind made in group, or nil: a failure (but the UI not up yet) is logged once and the kind left out.
    function self.make(group,kind,x,y,w,h,fill,hit)
        if broken[kind] then return nil end
        local rec,why=kit.part(group,Parts.CLASS[kind],x,y,w,h,fill,hit)
        if rec then rec.kind,rec.look=kind,'normal'; return rec end -- Construct played Normal (or Disable).
        if not why:find('not up',1,true) then
            broken[kind]=true
            log(who..': '..why..'; left out until the mod reloads')
        end
    end
    -- The parts of one set by slot, 1 to n, as specs say ({kind, x, y, w, h, sig, fill, after} or false: none): a
    -- slot whose part is gone (a root build), moved or whose sig changed is made again; after: its EventNotification
    -- once in the canvas.
    function self.sync(set,group,specs,n)
        for i=1,n do
            local s,have=specs[i],set[i]
            local sig=s and s.sig..'@'..s.x..','..s.y
            if have and not (sig==have.sig and kit.alive(have)) then kit.drop(have); set[i],have=nil,nil end
            if s and not have then
                local rec=self.make(group,s.kind,s.x,s.y,s.w,s.h,s.fill)
                if rec then
                    rec.sig,set[i]=sig,rec
                    if s.after then self.call(rec,s.kind..' '..s.after,function(w) w:EventNotification(s.after) end) end
                end
            end
        end
    end
    -- A row's look, on change only: lobby rows 'select' or 'normal' (SelectAnimation, NormalAnimation), option rows
    -- 'focus' or 'normal' (StateFocus, StateNormal), slider rows 'focus' or 'normal' (their Focus and Normal).
    function self.look(rec,want)
        if not rec or rec.look==want then return end
        rec.look=want
        self.call(rec,rec.kind..' look',function(w)
            if rec.kind=='slider' then if want=='focus' then w:Focus() else w:Normal() end
            elseif rec.kind~='row' then w:EventNotification(want=='focus' and 'StateFocus' or 'StateNormal')
            elseif want=='select' then w:SelectAnimation() else w:NormalAnimation() end
        end)
    end
    return self
end
return Parts
