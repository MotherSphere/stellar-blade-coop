-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The rifle's own round: NIKKE rapid rounds in a magazine of cfg.mag_size with cfg.spare_mags spare magazines, fired
-- at the NIKKE shot's cool time. A reload (cfg.reload_time, the NIKKE squad's reload animation) comes when the
-- magazine runs dry or at the player's reload key (manual), never because the rifle is lowered. The reticle's round
-- slot (WB_Tps_Bullet3, under the drone's reticle) shows the round's name and the rounds in the magazine while
-- firing mode is held. Its own text goes back when the rifle goes away. The drone's round count at the bottom left (WB_MainHUD_Lower1Item, beside
-- D-pad Right) keeps the game's own text: find() only logs it. dpad: a D-pad slot that shows the rounds, or nil (gun
-- mode passes none: its HUD entry, fight/gunmode/ui/dpad.lua, shows them from fight/gunmode/mode.lua's tick).
-- Where the rounds come from: with stock (fight/gunmode/nikke.lua) once its rows are in, EVE's inventory of SB's own
-- round Bullet_Nikke, while a co-op save is loaded. The magazine then starts empty. Each reload takes the rounds it
-- loads out of the inventory (stock.take), at most what she carries. The spares are what she carries (stock.count).
-- Rounds already in the magazine stay there across worlds. A refused take loads nothing and the next reload waits
-- RETRY s. Without stock, or while it is not ready (your own saves, no native part, rows refused), cfg.spare_mags
-- free magazines that a new world (a map, a death, a camp's travel) fills again.
-- Rounds are counted at the rate the game fires them: one at the press, then one per cool time (rounded up to whole
-- frames, as the game checks the cool time once a frame). While reloading the shot's cool time is the reload's, so
-- the trigger fires nothing until the magazine is full again.
local Ammo={}
Ammo.RETRY=5 -- s: after a refused take, before a stocked magazine reloads again.

Ammo.SLOT='WB_Tps_Bullet3'
Ammo.NAME_TEXT,Ammo.COUNT_TEXT='TextBlock_bullet_name','TextBlock_ItemCount'
Ammo.LOWER,Ammo.LOWER_TEXT='WB_MainHUD_Lower1Item','TextBlock_Item_Count'

-- The bottom-left text: rounds in the magazine | magazines left (a part-spent one counted).
function Ammo.lower_text(left,reserve,mag)
    return ('%d | %d'):format(math.floor(left),math.ceil(reserve/mag))
end

-- The time between rounds the game manages at a frame time dt for a cool time c: whole frames, at least one.
function Ammo.step(c,dt)
    if not dt or dt<=0 then return c end
    return math.max(1,math.ceil(c/dt-1e-6))*dt
end

-- g: gun mode's shared state (log, try, valid; words: ui/text.lua's gun in the player's language, whose round, reload
-- and empty go on the slot). cfg: mag_size, reload_time, fire_interval, round_color, reload_color. cool(v): sets the
-- shot's cool time (fight/gunmode/data.lua).
-- on_reload(on, duration): the reload's animation and sound (fight/gunmode/mode.lua).
-- dpad: the D-pad slot, show(text, color, rounds in the magazine) each frame and hide(); nil for none.
-- stock: fight/gunmode/nikke.lua's object (ready, count, take, watch), or nil.
function Ammo.new(g,cfg,cool,on_reload,dpad,stock)
    local self={left=cfg.mag_size,reserve=cfg.mag_size*cfg.spare_mags,reload_until=nil,acc=0,dt=1/60,held=false}
    on_reload=on_reload or function() end
    local ui={} -- name, count: the slot's text blocks; saved: their own text and colour.

    local function find()
        if g.valid(ui.name) and g.valid(ui.count) then return true end
        ui.name,ui.count,ui.lower=nil,nil,nil
        -- FindAllOf walks every object: only after an event (ui.look: the rifle out, firing mode entered), once a
        -- second at most (L1).
        if not ui.look or (ui.retry or 0)>os.clock() then return false end
        ui.look,ui.retry=false,os.clock()+1.0
        pcall(function()
            for _,t in ipairs(FindAllOf('TextBlock') or {}) do
                local full=t:GetFullName()
                if full:find(Ammo.SLOT,1,true) and full:find('MainHUD',1,true) then
                    local leaf=full:match('([%w_]+)$')
                    if leaf==Ammo.NAME_TEXT then ui.name=t elseif leaf==Ammo.COUNT_TEXT then ui.count=t end
                elseif full:find(Ammo.LOWER,1,true) and full:find('MainHUD_Master',1,true) then
                    local leaf=full:match('([%w_]+)$')
                    local txt=g.try(function() return t:GetText():ToString() end)
                    ui.lower_all=ui.lower_all or {}
                    ui.lower_all[#ui.lower_all+1]=full:match('Lower1Item%.(.*)$')..'="'..tostring(txt)..'"'
                end
            end
        end)
        if not ui.logged then
            ui.logged=true
            g.log('ammo: bottom-left texts: '..table.concat(ui.lower_all or {},' | '))
            g.log('ammo: reticle round slot '..((ui.name and ui.count) and 'found' or 'not found')..', bottom-left count '..
                (ui.lower and 'found' or 'not found'))
        end
        return ui.name~=nil and ui.count~=nil
    end

    local function colour(c) return {SpecifiedColor={R=c[1],G=c[2],B=c[3],A=1},ColorUseRule=0} end
    local function set_text(t,text)
        local ok=pcall(function() t:SetText(FText(text)) end)
        return ok
    end

    -- The slot showing the rifle's round (firing mode held).
    local function show()
        if dpad then
            local empty=self.left<=0 and self.reserve<=0
            pcall(dpad.show,Ammo.lower_text(math.max(0,self.left),self.reserve,cfg.mag_size),
                (empty or self.reload_until) and cfg.reload_color or cfg.round_color,math.max(0,math.floor(self.left)))
        end
        if not find() then return end
        if not ui.saved then
            ui.saved={}
            for _,k in ipairs({'name','count','lower'}) do
                local t=ui[k]
                if t then
                local text=g.try(function() return t:GetText():ToString() end)
                local c=g.try(function() local v=t.ColorAndOpacity.SpecifiedColor; return {v.R,v.G,v.B,v.A} end)
                ui.saved[k]={text=text,col=c}
                end
            end
        end
        local empty=self.left<=0 and self.reserve<=0
        -- The words once a second: main/base.lua's words asks the engine for the game's language.
        if (ui.words_at or 0)<os.clock() then ui.words,ui.words_at=g.words(),os.clock()+1.0 end
        local w=ui.words
        local name=self.reload_until and w.reload or empty and w.empty or w.round
        local count=tostring(math.max(0,math.floor(self.left)))
        if ui.shown_name~=name or (ui.check or 0)<os.clock() then
            if set_text(ui.name,name) then ui.shown_name=name end
            pcall(function() ui.name:SetColorAndOpacity(colour((self.reload_until or empty) and cfg.reload_color or cfg.round_color)) end)
            pcall(function() ui.count:SetColorAndOpacity(colour(cfg.round_color)) end)
            ui.check=os.clock()+0.25 -- The game writes its own round again now and then: written back within 0.25 s.
            ui.shown_count=nil
        end
        if ui.shown_count~=count then
            if set_text(ui.count,count) then ui.shown_count=count end
        end
        -- The bottom-left slot shown while the rifle is out (the game shows it only in its aim and in fights): the
        -- count's text block and every panel and widget above it up to the HUD made visible, each put back after.
        if g.valid(ui.lower) and not ui.chain then
            ui.chain={}
            local w=ui.lower
            for _=1,12 do
                local parent=g.try(function() return w:GetParent() end)
                if not g.valid(parent) then
                    -- The top of a widget tree: its user widget (the tree's outer's outer).
                    parent=g.try(function() return w:GetOuter():GetOuter() end)
                    if not (g.valid(parent) and g.try(function() return parent:IsA(StaticFindObject('/Script/UMG.UserWidget')) end)) then break end
                end
                local name=g.try(function() return parent:GetFName():ToString() end) or '?'
                if name:find('MainHUD_Master') then break end
                ui.chain[#ui.chain+1]={w=parent,vis=g.try(function() return parent:GetVisibility() end),
                    op=g.try(function() return parent:GetRenderOpacity() end),name=name}
                w=parent
            end
            local names={}
            for _,e in ipairs(ui.chain) do names[#names+1]=e.name..'('..tostring(e.vis)..','..tostring(e.op)..')' end
            g.log('ammo: bottom-left slot chain: '..table.concat(names,' < '))
        end
        if ui.chain and (ui.vis_at or 0)<os.clock() then
            ui.vis_at=os.clock()+0.1
            for _,e in ipairs(ui.chain) do
                if g.valid(e.w) then
                    pcall(function() if e.w:GetVisibility()==1 or e.w:GetVisibility()==2 then e.w:SetVisibility(4) end end)
                    pcall(function() if e.w:GetRenderOpacity()<1 then e.w:SetRenderOpacity(1.0) end end)
                end
            end
        end
        if g.valid(ui.lower) then
            local low=Ammo.lower_text(math.max(0,self.left),self.reserve,cfg.mag_size)
            if ui.shown_lower~=low or (ui.check_low or 0)<os.clock() then -- every 0.1 s: the game writes its count
                if set_text(ui.lower,low) then ui.shown_lower=low end
                pcall(function() ui.lower:SetColorAndOpacity(colour(empty and cfg.reload_color or cfg.round_color)) end)
                ui.check_low=os.clock()+0.1
            end
        end
    end

    -- The game's own text and colour back in the slot.
    function self.restore()
        if dpad then pcall(dpad.hide) end
        if ui.saved then
            for _,k in ipairs({'name','count','lower'}) do
                local t,sv=ui[k],ui.saved[k]
                if g.valid(t) and sv then
                    if sv.text then set_text(t,sv.text) end
                    if sv.col then pcall(function() t:SetColorAndOpacity(colour(sv.col)) end) end
                end
            end
        end
        for _,e in ipairs(ui.chain or {}) do
            if g.valid(e.w) then
                if e.vis then pcall(function() e.w:SetVisibility(e.vis) end) end
                if e.op then pcall(function() e.w:SetRenderOpacity(e.op) end) end
            end
        end
        ui.chain=nil
        ui.saved,ui.shown_name,ui.shown_count,ui.shown_lower=nil,nil,nil,nil
    end

    local function start_reload(now,why)
        if self.reload_until or self.reserve<=0 or self.left>=cfg.mag_size then return end
        self.reload_until=now+cfg.reload_time
        self.reload_from=self.left
        self.reload_to=math.min(cfg.mag_size,self.left+self.reserve)
        pcall(cool,cfg.reload_time+0.2) -- No round until the magazine is in.
        local ok,err=pcall(on_reload,true,cfg.reload_time)
        if not ok then g.log('ammo: reload animation: '..tostring(err)) end
        g.log(('ammo: reload (%s), %d in the magazine, %d spare'):format(why,math.floor(self.left),self.reserve))
    end

    -- The magazine goes in: with stock, its rounds taken out of EVE's inventory first, at most what she carries now (a
    -- refused take loads nothing).
    local function load(now)
        local n=self.reload_to-self.reload_from
        if self.stocked then
            n=math.min(n,stock.count() or 0)
            local ok,why=true,nil
            if n>0 then ok,why=stock.take(n) end
            if not ok then
                self.retry_at=(now or 0)+Ammo.RETRY
                return g.log('ammo: '..n..' rounds not taken ('..tostring(why)..'): nothing loaded')
            end
        else self.reserve=self.reserve-n end
        self.left=self.reload_from+n
    end

    -- Every frame while the rifle is out. aiming: firing mode; firing: the trigger held.
    local was_aiming=false
    function self.tick(aiming,firing,now)
        if stock then
            local ready=stock.ready()
            if self.stocked and not ready then
                -- Your own save loaded (or the rows gone): free magazines again.
                self.stocked,self.retry_at=false,nil
                self.left,self.reserve=cfg.mag_size,cfg.mag_size*cfg.spare_mags
                if self.reload_until then self.reload_until,self.loaded=nil,false; pcall(on_reload,false) end
                pcall(stock.watch,false)
                pcall(cool,cfg.fire_interval)
                g.log('ammo: free magazines (no co-op save, or the rounds\' rows are not in)')
            elseif not self.stocked and ready then
                -- The rows are in: from now on the magazine loads from her inventory, and holds no free round.
                self.stocked,self.left=true,0
                if self.reload_until then self.reload_until,self.loaded=nil,false; pcall(on_reload,false) end
                g.log('ammo: the magazine loads from EVE\'s inventory ('..tostring(stock.round)..')')
            end
            if self.stocked then
                pcall(stock.watch,true)
                self.reserve=stock.count() or 0
            end
        end
        if aiming and not was_aiming then ui.look=true end -- Firing mode entered: the reticle's slot looked for.
        was_aiming=aiming
        local dt=now-(self.last or now)
        self.last=now
        if dt>0 and dt<0.2 then self.dt=self.dt+(dt-self.dt)*0.1 end
        if self.reload_until then
            local k=1-(self.reload_until-now)/cfg.reload_time
            -- The count jumps when the magazine goes in (two thirds of the way), as the NIKKE squad's does.
            if k>=0.66 and not self.loaded then
                self.loaded=true
                load(now)
            end
            if now>=self.reload_until then
                self.reload_until,self.loaded=nil,false
                pcall(on_reload,false)
                pcall(cool,self.left>0 and cfg.fire_interval or 999) -- Nothing loaded: no round.
            end
        elseif aiming and firing and self.left>0 then
            if not self.held then -- The press: one round at once.
                self.held=true
                self.acc=0
                self.left=self.left-1
            else
                self.acc=self.acc+dt
                local step=Ammo.step(cfg.fire_interval,self.dt)
                while self.acc>=step and self.left>0 do
                    self.acc=self.acc-step
                    self.left=self.left-1
                end
            end
            if self.left<=0 then
                self.left=0
                if self.reserve>0 then start_reload(now,'empty')
                else pcall(cool,999); self.dry=true; g.log('ammo: out of rounds') end
            end
        else
            if not firing then self.held=false end
            -- (no reload when the rifle is lowered: only an empty magazine or the player's reload key, 11-20)
        end
        -- With stock, an empty magazine reloads as soon as she carries rounds (a purchase, a drop), and holds no round
        -- while she carries none.
        if self.stocked and self.left<=0 and not self.reload_until and now>=(self.retry_at or 0) then
            if self.reserve>0 then start_reload(now,'empty')
            elseif not self.dry then self.dry=true; pcall(cool,999); g.log('ammo: out of rounds') end
        end
        if self.left>0 or self.reserve>0 then self.dry=nil end
        show()
    end

    -- The player's reload (fight/gunmode/mode.lua: B / Triangle): the rest of the magazine is thrown away and a full one
    -- goes in from the spares (with stock: taken out of EVE's inventory by load, as any reload). Nothing while
    -- reloading, with a full magazine, with no spares or while a refused take waits (retry_at).
    function self.manual(now)
        if self.reload_until or self.reserve<=0 or self.left>=cfg.mag_size then return false end
        if self.stocked and now<(self.retry_at or 0) then return false end
        self.left=0
        start_reload(now,'manual')
        return self.reload_until~=nil
    end

    -- One round that gun mode fired itself (hip fire, the air shot): counted per shot, not on the timer, so the count
    -- matches the rounds that left the rifle.
    function self.spend(now)
        if self.reload_until or self.left<=0 then return false end
        self.left=self.left-1
        if self.left<=0 then
            self.left=0
            if self.reserve>0 and now>=(self.retry_at or 0) then start_reload(now,'empty')
            elseif self.reserve<=0 then pcall(cool,999); self.dry=true; g.log('ammo: out of rounds') end
        end
        show()
        return true
    end

    -- After the rows are taken again (the rifle out): no round if both magazine and spares are spent. The reticle's
    -- slot looked for at the next tick.
    function self.sync()
        ui.look=true
        if self.left<=0 and (self.stocked or self.reserve<=0) then pcall(cool,999) end
    end

    -- A new world: full free magazines again. With stock, the magazine as it was (its rounds came out of the
    -- inventory). A stocked magazine fires only what it holds: an empty one waits for its reload.
    function self.refill()
        if not self.stocked then self.left,self.reserve=cfg.mag_size,cfg.mag_size*cfg.spare_mags end
        if self.reload_until then self.reload_until,self.loaded=nil,false; pcall(on_reload,false) end
        pcall(cool,(self.left>0 or (not self.stocked and self.reserve>0)) and cfg.fire_interval or 999)
    end

    -- The rifle put away: the game's slot back, the cool time back to the rate of fire. The rounds stay as they are.
    function self.stop()
        self.restore()
        if self.reload_until then
            -- Put away mid-reload: the magazine goes in.
            if not self.loaded then load(os.clock()) end
            self.reload_until,self.loaded=nil,false
            pcall(on_reload,false)
        end
        if self.left>0 or (not self.stocked and self.reserve>0) then pcall(cool,cfg.fire_interval) end
        self.held=false
        if stock then pcall(stock.watch,false) end
    end

    return self
end

return Ammo
