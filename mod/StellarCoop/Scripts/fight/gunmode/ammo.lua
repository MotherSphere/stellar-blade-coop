-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The rifle's own round: NIKKE rapid rounds in a magazine of cfg.mag_size with cfg.spare_mags spare magazines, fired
-- at the NIKKE shot's cool time. A reload (cfg.reload_time, the NIKKE squad's reload animation) comes when the
-- magazine runs dry or at the player's reload key (manual), never because the rifle is lowered. The reticle's round
-- slot (WB_Tps_Bullet3, under the drone's reticle) shows the round's name and the rounds in the magazine while
-- firing mode is held, from the aim's first frame. Its own text goes back when the rifle goes away. The drone's
-- round count at the bottom left keeps the game's own text: gun mode's HUD entry beside the D-pad marker shows the
-- rifle's rounds (0fb38c0c, 11-18). dpad: a D-pad slot that shows the rounds, or nil (gun mode passes none: its HUD
-- entry, fight/gunmode/ui/dpad.lua, shows them from fight/gunmode/mode.lua's tick).
-- Where the rounds come from: with stock (fight/gunmode/nikke.lua) once its rows are in, EVE's inventory of SB's own
-- round Bullet_Nikke, while a co-op save is loaded. The magazine then starts empty. Each reload takes the rounds it
-- loads out of the inventory (stock.take), at most what she carries. The spares are what she carries (stock.count).
-- Rounds already in the magazine stay there across worlds. A refused take loads nothing and the next reload waits
-- RETRY s. Without stock, or while it is not ready (your own saves, no native part, rows refused), cfg.spare_mags
-- free magazines that a new world (a map, a death, a camp's travel) fills again.
-- Rounds are counted at the rate the game fires them: one at the press, then one per cool time (rounded up to whole
-- frames, as the game checks the cool time once a frame). While reloading the shot's cool time is the reload's, so
-- the trigger fires nothing until the magazine is full again. Where rounds come back after a longer cool time (a
-- reload's end, a refill, the rifle out) the cool time is 0 until one cool time and Ammo.OPEN_FRAMES frames after the
-- first round (open below).
local Ammo={}
Ammo.RETRY=5 -- s: after a refused take, before a stocked magazine reloads again.
-- frames: the cool time 0 (open below) lasts at least this many frames from the first round. One cool time alone is
-- 1 to 2 frames at 30 fps or after a slow frame. SB's first start can come a frame or two after gun mode sees the
-- press. With the rate of fire already back in the row, a stored 999 refused that start.
Ammo.OPEN_FRAMES=4

Ammo.SLOT='WB_Tps_Bullet3'
Ammo.NAME_TEXT,Ammo.COUNT_TEXT='TextBlock_bullet_name','TextBlock_ItemCount'
-- s from the aim's start during which the slot's text is written each frame: the game writes its own round's name
-- when its aim starts, in the aim's first frames.
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

-- g: gun mode's shared state (log, try, valid; words: ui/text.lua's gun in the player's language, whose round, reload
-- and empty go on the slot). cfg: mag_size, reload_time, fire_interval, round_color, reload_color. cool(v): sets the
-- shot's cool time (fight/gunmode/data.lua).
-- on_reload(on, duration): the reload's animation and sound (fight/gunmode/mode.lua).
-- dpad: the D-pad slot, show(text, color, rounds in the magazine) each frame and hide(); nil for none.
-- stock: fight/gunmode/nikke.lua's object (ready, count, take, watch), or nil.
function Ammo.new(g,cfg,cool,on_reload,dpad,stock)
    -- fired: the rounds the game's aim fired, as tick counts them (gun mode's own shots count themselves).
    local self={left=cfg.mag_size,reserve=cfg.mag_size*cfg.spare_mags,reload_until=nil,acc=0,dt=1/60,held=false,fired=0}
    on_reload=on_reload or function() end
    local ui={} -- name, count: the slot's text blocks; saved: their own text and colour.

    -- The slot's text blocks while they are the ones found: IsValid each frame, their paths every 0.25 s and before
    -- a restore. A map change frees them. Another object can then sit at a freed address and pass IsValid.
    local function ours(now)
        if not (g.valid(ui.name) and g.valid(ui.count)) then return false end
        if not now and (ui.seen_at or 0)>os.clock() then return true end
        ui.seen_at=os.clock()+0.25
        return g.path(ui.name)==ui.name_at and g.path(ui.count)==ui.count_at
    end
    local function find()
        if ours() then return true end
        ui.name,ui.count,ui.seen_at=nil,nil,nil
        -- FindAllOf walks every object: only after an event (ui.look: the rifle out, firing mode entered), once a
        -- second at most (L1).
        if not ui.look or (ui.retry or 0)>os.clock() then return false end
        ui.look,ui.retry=false,os.clock()+10.0 -- a walk costs 60-90 ms: at most one in 10 s while the slot is missing
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
                (empty or self.reload_until) and cfg.reload_color or cfg.round_color,math.max(0,math.floor(self.left)))
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
        -- The words once a second: main/base.lua's words asks the engine for the game's language.
        if (ui.words_at or 0)<os.clock() then ui.words,ui.words_at=g.words(),os.clock()+1.0 end
        local w=ui.words
        local name=self.reload_until and w.reload or empty and w.empty or w.round
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
    -- trigger held) then refused every round of the next magazine for up to 999 s: no round, no shot sound (2026-11-21
    -- test). A row value of 0 lets the next start through, which stores 0. tick puts the rate of fire back one cool time
    -- and Ammo.OPEN_FRAMES frames after the first round (open_at, open_n): the game's aim drops for a frame on each of
    -- its shots, which ends a held press.
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

    -- The magazine goes in: with stock, its rounds taken out of EVE's inventory first, at most what she carries now (a
    -- refused take loads nothing). The take gets gun mode's controller and EVE (g.pc, g.pawn: kept, no walk). Without
    -- them fight/gunmode/nikke.lua finds the controller with FindFirstOf, twice: a walk of the object array each time
    -- (each reload's frame took 64 to 66 ms in the 2026-11-21 test).
    local function load(now)
        local n=self.reload_to-self.reload_from
        if self.stocked then
            n=math.min(n,stock.count() or 0)
            local ok,why=true,nil
            if n>0 then ok,why=stock.take(n,g.pc and g.pc(),g.pawn and g.pawn()) end
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
                open()
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
        -- Firing mode entered: the slot looked for if not found yet. Its text is written each frame for FRESH s.
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
                load(now)
            end
            if now>=self.reload_until then
                self.reload_until,self.loaded=nil,false
                pcall(on_reload,false)
                if self.left>0 then open() else pcall(cool,999) end -- Nothing loaded: no round.
            end
        elseif aiming and firing and self.left>0 then
            if self.open and not self.open_at then self.open_at,self.open_n=now,0 end
            if not self.held then -- The press: one round at once.
                self.held=true
                self.acc=0
                self.left=self.left-1
                self.fired=self.fired+1
            else
                self.acc=self.acc+dt
                local step=Ammo.step(cfg.fire_interval,self.dt)
                while self.acc>=step and self.left>0 do
                    self.acc=self.acc-step
                    self.left=self.left-1
                    self.fired=self.fired+1
                end
            end
            if self.left<=0 then
                self.left=0
                if self.reserve>0 and now>=(self.retry_at or 0) then start_reload(now,'empty')
                elseif self.reserve<=0 then pcall(cool,999); self.dry=true; g.log('ammo: out of rounds')
                else pcall(cool,999) end -- After a refused take: the stocked empty check below reloads after RETRY.
            end
        else
            if not firing then self.held=false end
            -- (no reload when the rifle is lowered: only an empty magazine or the player's reload key, 11-20)
        end
        -- With stock, an empty magazine reloads as soon as she carries rounds (a purchase, a drop), and holds no round
        -- while she carries none. Nothing before the count's first read (count() nil): its reserve of 0 is no count.
        if self.stocked and self.left<=0 and not self.reload_until and now>=(self.retry_at or 0) and stock.count()~=nil then
            if self.reserve>0 then start_reload(now,'empty')
            elseif not self.dry then self.dry=true; pcall(cool,999); g.log('ammo: out of rounds') end
        end
        if self.left>0 or self.reserve>0 then self.dry=nil end
        if self.open_at then
            self.open_n=self.open_n+1
            if self.open_n>Ammo.OPEN_FRAMES and now-self.open_at>=cfg.fire_interval then
                self.open,self.open_at=nil,nil
                if self.left>0 and not self.reload_until then pcall(cool,cfg.fire_interval) end -- (else 999 or the reload's wait)
            end
        end
        show()
    end

    -- The player's reload (fight/gunmode/mode.lua: B / Triangle): the magazine is topped up from the spares (with stock:
    -- taken out of EVE's inventory by load, as any reload). Its rounds stay in it, so a press never leaves fewer rounds
    -- and never loses a round taken from the inventory. Nothing while reloading, with a full magazine, with no spares or
    -- while a refused take waits (retry_at).
    function self.manual(now)
        if self.reload_until or self.reserve<=0 or self.left>=cfg.mag_size then return false end
        if self.stocked and now<(self.retry_at or 0) then return false end
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
            if self.reserve>0 and now>=(self.retry_at or 0) then start_reload(now,'empty')
            elseif self.reserve<=0 then pcall(cool,999); self.dry=true; g.log('ammo: out of rounds') end
        end
        show()
        return true
    end

    -- After the rows are taken again (the rifle out): no round if both magazine and spares are spent. Else the cool
    -- time stays the take's 0 (fight/gunmode/mode.lua) until the first round. The reticle's slot looked for at the next
    -- tick.
    function self.sync()
        ui.look=true
        if self.left<=0 and (self.stocked or self.reserve<=0) then pcall(cool,999) else self.open=true end
    end

    -- A new world: full free magazines again. With stock, the magazine as it was (its rounds came out of the
    -- inventory). A stocked magazine fires only what it holds: an empty one waits for its reload.
    function self.refill()
        if not self.stocked then self.left,self.reserve=cfg.mag_size,cfg.mag_size*cfg.spare_mags end
        if self.reload_until then self.reload_until,self.loaded=nil,false; pcall(on_reload,false) end
        if self.left>0 or (not self.stocked and self.reserve>0) then open() else pcall(cool,999) end
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
        self.held,self.open,self.open_at=false,nil,nil
        if stock then pcall(stock.watch,false) end
    end

    return self
end

return Ammo
