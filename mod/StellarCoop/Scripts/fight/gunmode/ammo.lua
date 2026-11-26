-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The rifle's own round: NIKKE rapid rounds, a magazine of cfg.mag_size and cfg.spare_mags spare magazines, fired
-- at the NIKKE shot's cool time. A reload (cfg.reload_time, the NIKKE squad's reload animation) comes when the
-- magazine runs dry or while the rifle is lowered with a part-spent one. The reticle's round slot (WB_Tps_Bullet3,
-- under the drone's reticle) shows the round's name and the rounds in the magazine while firing mode is held, from the
-- aim's first frame (f60b4d27). The drone's round count at the bottom left keeps the game's own text: gun mode's HUD
-- entry beside the D-pad marker shows the rifle's rounds (a5556d87). The game's own text goes back when the rifle
-- goes away. A new world (a map, a death, a camp's travel) gives full magazines again.
-- Rounds are counted at the rate the game fires them: one at the press, then one per cool time (rounded up to whole
-- frames, as the game checks the cool time once a frame). While reloading the shot's cool time is the reload's, so
-- the trigger fires nothing until the magazine is full again. Where rounds come back after a longer cool time (a
-- reload's end, a refill, the rifle out) the cool time is 0 until one cool time and Ammo.OPEN_FRAMES frames after the
-- first round (open below).
local Ammo={}
-- frames: the cool time 0 (open below) lasts at least this many frames from the first round. One cool time alone is
-- 1 to 2 frames at 30 fps or after a slow frame. SB's first start can come a frame or two after gun mode sees the
-- press. With the rate of fire already back in the row, a stored 999 refused that start (7f3932fe).
Ammo.OPEN_FRAMES=4

Ammo.SLOT='WB_Tps_Bullet3'
Ammo.NAME_TEXT,Ammo.COUNT_TEXT='TextBlock_bullet_name','TextBlock_ItemCount'
-- s from the aim's start during which the slot's text is written each frame: the game writes its own round's name
-- when its aim starts, in the aim's first frames (f60b4d27).
Ammo.FRESH=0.25

-- The HUD entry's text: rounds in the magazine | magazines left (a part-spent one counted).
function Ammo.lower_text(left,reserve,mag)
    return ('%d | %d'):format(math.floor(left),math.ceil(reserve/mag))
end

-- The time between rounds the game manages at a frame time dt for a cool time c: whole frames, at least one.
function Ammo.step(c,dt)
    if not dt or dt<=0 then return c end
    return math.max(1,math.ceil(c/dt-1e-6))*dt
end

-- g: gun mode's shared state (log, try, valid). cfg: mag_size, reload_time, fire_interval, round_name, round_color,
-- reload_text. cool(v): sets the shot's cool time (fight/gunmode/data.lua).
-- on_reload(on, duration): the reload's animation and sound (fight/gunmode/mode.lua).
function Ammo.new(g,cfg,cool,on_reload,dpad)
    local self={left=cfg.mag_size,reserve=cfg.mag_size*cfg.spare_mags,reload_until=nil,acc=0,dt=1/60,held=false}
    on_reload=on_reload or function() end
    local ui={} -- name, count: the slot's text blocks; saved: their own text and colour.
    local was_aiming=false

    -- The slot's text blocks while they are the ones found: IsValid each frame, their paths every 0.25 s and before
    -- a restore. A map change frees them. Another object can then sit at a freed address and pass IsValid (f60b4d27).
    local function ours(now)
        if not (g.valid(ui.name) and g.valid(ui.count)) then return false end
        if not now and (ui.seen_at or 0)>os.clock() then return true end
        ui.seen_at=os.clock()+0.25
        return g.path(ui.name)==ui.name_at and g.path(ui.count)==ui.count_at
    end
    local function find()
        if ours() then return true end
        ui.name,ui.count,ui.seen_at=nil,nil,nil
        -- FindAllOf walks every object: only after an event (ui.look: the rifle out, firing mode entered), at most
        -- once in 10 s while the slot is missing (468f7ab6, b812f708: a walk costs 60-90 ms). Never in firing mode:
        -- a walk at its start lands where she watches her body turn to the front. The look an aim asks waits for its
        -- end.
        if not ui.look or was_aiming or (ui.retry or 0)>os.clock() then return false end
        ui.look,ui.retry=false,os.clock()+10.0
        pcall(function()
            for _,t in ipairs(FindAllOf('TextBlock') or {}) do
                local full=t:GetFullName()
                if full:find(Ammo.SLOT,1,true) and full:find('MainHUD',1,true) then
                    local leaf=full:match('([%w_]+)$')
                    if leaf==Ammo.NAME_TEXT then ui.name=t elseif leaf==Ammo.COUNT_TEXT then ui.count=t end
                end
            end
        end)
        ui.name_at,ui.count_at=ui.name and g.path(ui.name),ui.count and g.path(ui.count)
        if not ui.logged then
            ui.logged=true
            g.log('ammo: reticle round slot '..((ui.name and ui.count) and 'found' or 'not found'))
        end
        return ui.name~=nil and ui.count~=nil and ui.name_at~=nil and ui.count_at~=nil
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
                (empty or self.reload_until) and cfg.reload_color or cfg.round_color)
        end
        if not find() then return end
        if not ui.saved then
            ui.saved={}
            for _,k in ipairs({'name','count'}) do
                local t=ui[k]
                local text=g.try(function() return t:GetText():ToString() end)
                local c=g.try(function() local v=t.ColorAndOpacity.SpecifiedColor; return {v.R,v.G,v.B,v.A} end)
                ui.saved[k]={text=text,col=c}
            end
        end
        local empty=self.left<=0 and self.reserve<=0
        local name=self.reload_until and cfg.reload_text or empty and cfg.empty_text or cfg.round_name
        local count=tostring(math.max(0,math.floor(self.left)))
        -- (the aim's first frames: each frame, as the game writes its own round's name when its aim starts)
        if ui.shown_name~=name or (ui.check or 0)<os.clock() or os.clock()<(ui.fresh_until or 0) then
            if set_text(ui.name,name) then ui.shown_name=name end
            pcall(function() ui.name:SetColorAndOpacity(colour((self.reload_until or empty) and cfg.reload_color or cfg.round_color)) end)
            pcall(function() ui.count:SetColorAndOpacity(colour(cfg.round_color)) end)
            ui.check=os.clock()+0.25 -- The game writes its own round again now and then: written back within 0.25 s.
            ui.shown_count=nil
        end
        if ui.shown_count~=count then
            if set_text(ui.count,count) then ui.shown_count=count end
        end
    end

    -- The game's own text and colour back in the slot.
    function self.restore()
        if dpad then pcall(dpad.hide) end
        if ui.saved and ours(true) then
            for _,k in ipairs({'name','count'}) do
                local t,sv=ui[k],ui.saved[k]
                if sv.text then set_text(t,sv.text) end
                if sv.col then pcall(function() t:SetColorAndOpacity(colour(sv.col)) end) end
            end
        end
        ui.saved,ui.shown_name,ui.shown_count=nil,nil,nil
    end

    -- SB keeps its own copy of the shot's cool time (build 26123051): FSBSkillStart::Execute (0x141b17900) calls
    -- 0x141d2f750, which copies the SkillTable row's CoolTime (SBSkillTableProperty+0x124, property params at
    -- 0x145df2820) into the skill component's map at +0x80 at each start (0x141d2fe7b). 0x141d2e4c0 counts that copy
    -- down by the frame time (0x141d2e623) and never reads the row. 0x141d2cce0 refuses a start while the row's
    -- CoolTime and the copy are both above 0 (0x141d2d5ed). A 999 taken while SB could start (fired dry with the
    -- trigger held) then refused every round of the next magazine for up to 999 s: no round, no shot sound
    -- (2026-11-21 test). A row value of 0 lets the next start through, which stores 0. tick puts the rate of fire back
    -- one cool time and Ammo.OPEN_FRAMES frames after the first round (open_at, open_n): the game's aim drops for a
    -- frame on each of its shots, which ends a held press (4f755c24, 7f3932fe).
    local function open() self.open,self.open_at=true,nil; pcall(cool,0) end

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

    -- Every frame while the rifle is out. aiming: firing mode; firing: the trigger held.
    function self.tick(aiming,firing,now)
        -- Firing mode entered: the slot looked for once it ends, if not found yet. Its text is written each frame for
        -- FRESH s.
        if aiming and not was_aiming then ui.look,ui.fresh_until=true,os.clock()+Ammo.FRESH end
        was_aiming=aiming
        local dt=now-(self.last or now)
        self.last=now
        if dt>0 and dt<0.2 then self.dt=self.dt+(dt-self.dt)*0.1 end
        if self.reload_until then
            local k=1-(self.reload_until-now)/cfg.reload_time
            -- The count jumps when the magazine goes in (two thirds of the way), as the NIKKE squad's does.
            if k>=0.66 and not self.loaded then
                self.loaded=true
                self.reserve=self.reserve-(self.reload_to-self.reload_from)
                self.left=self.reload_to
            end
            if now>=self.reload_until then
                self.reload_until,self.loaded=nil,false
                pcall(on_reload,false)
                open() -- (a reload always loads a round: start_reload needs spares)
            end
        elseif aiming and firing and self.left>0 then
            if self.open and not self.open_at then self.open_at,self.open_n=now,0 end
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
                else pcall(cool,999); g.log('ammo: out of rounds') end
            end
        else
            if not firing then self.held=false end
            -- (no reload when the rifle is lowered: only an empty magazine or the player's reload key, 11-20)
        end
        if self.open_at then
            self.open_n=self.open_n+1
            if self.open_n>Ammo.OPEN_FRAMES and now-self.open_at>=cfg.fire_interval then
                self.open,self.open_at=nil,nil
                -- (else 999 or the reload's wait)
                if self.left>0 and not self.reload_until then pcall(cool,cfg.fire_interval) end
            end
        end
        show()
    end

    -- The player's reload (fight/gunmode/mode.lua: R / Triangle): the rest of the magazine is thrown away and a full one
    -- goes in from the spares. Nothing while reloading, with a full magazine or with no spares.
    function self.manual(now)
        if self.reload_until or self.reserve<=0 or self.left>=cfg.mag_size then return false end
        self.left=0
        start_reload(now,'manual')
        return self.reload_until~=nil
    end

    -- One round that gun mode fired itself (hip fire, the air shot): counted per shot, not on the timer, so the count
    -- matches the rounds that left the rifle.
    function self.spend(now)
        if self.reload_until or self.left<=0 then return false end
        if self.open and not self.open_at then self.open_at,self.open_n=now,0 end
        self.left=self.left-1
        if self.left<=0 then
            self.left=0
            if self.reserve>0 then start_reload(now,'empty') else pcall(cool,999); g.log('ammo: out of rounds') end
        end
        show()
        return true
    end

    -- After the rows are taken again (the rifle out): no round if both magazine and spares are spent. Else the cool
    -- time stays the take's 0 (fight/gunmode/mode.lua) until the first round. The reticle's slot looked for at the next
    -- tick.
    function self.sync()
        ui.look=true
        if self.left<=0 and self.reserve<=0 then pcall(cool,999) else self.open=true end
    end

    -- Full magazines again (a new world).
    function self.refill()
        self.left,self.reserve=cfg.mag_size,cfg.mag_size*cfg.spare_mags
        if self.reload_until then self.reload_until,self.loaded=nil,false; pcall(on_reload,false) end
        open()
    end

    -- The rifle put away: the game's slot back, the cool time back to the rate of fire. The rounds stay as they are.
    function self.stop()
        self.restore()
        if self.reload_until then
            -- Put away mid-reload: the magazine goes in.
            if not self.loaded then self.reserve=self.reserve-(self.reload_to-self.reload_from); self.left=self.reload_to end
            self.reload_until,self.loaded=nil,false
            pcall(on_reload,false)
        end
        if self.left>0 or self.reserve>0 then pcall(cool,cfg.fire_interval) end
        self.held,self.lowered,self.open,self.open_at=false,nil,nil,nil
    end

    return self
end

return Ammo
