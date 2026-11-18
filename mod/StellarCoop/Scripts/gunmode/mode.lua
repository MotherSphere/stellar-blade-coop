-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode: the NIKKE DLC's rifle outside its missions, as a standing third-person shooter, on any save. G (gun_key)
-- or a tap of D-pad Right turns it on or off; standing, LMB / R2 fires full auto at the screen-centre crosshair with a
-- laser sight; Caps Lock / Y / R3 crouches into the NIKKE cover kneel (Ctrl+LMB / L2+R2 fires there); Shift / Circle
-- rolls (the gun is lifted for the game's own evade, then put back). Logged as [StellarCoop][GM].
-- How: the NIKKE stage's effects put on EVE through zone-event rows (gunmode/rows.lua) that the gun mode build adds
-- to Survival Protocol's pak RoguelikeMode_P (its EventActorEffectTable, EventItemActionTable and EffectTable), the
-- shot made to fire without a bullet check by zNikkeGunMode_P (SkillCommandTable, SkillActiveStepTable), and the
-- standing animations (Eve's own legs, a rifle upper body, the aim offset) from zNikkeGunStand_P. All three are built
-- from the game's files on the player's PC (tools/gunmode/), never shipped here. Without RoguelikeMode_P or
-- zNikkeGunMode_P the module stays off and says why; without zNikkeGunStand_P it runs with the NIKKE kneel only. The
-- rows themselves cannot be seen from Lua before use: a RoguelikeMode_P built without them leaves gun mode doing
-- nothing.
-- Standing, luke77's posed arms carry the rifle along the camera with a laser sight from its muzzle (gunmode/pose.lua,
-- gunmode/laser.lua), and every round goes to the crosshair point (gunmode/aim.lua).
-- Gun mode is a module of its own: it reads its own coop-settings.txt lines and finds its own paks, and uses nothing
-- of the rest of the mod; main.lua only builds and starts it, inside a pcall. All of it runs on the game thread, from
-- one LoopInGameThreadWithDelay loop (every frame), as main.lua's own loop does: the keys polled there, its delays a
-- queue that loop works through, the pose a step of it. No LoopAsync, ExecuteWithDelay or key bind: their callbacks run
-- Lua on another thread, and two threads in one Lua state corrupted it ("FindFirstOf cannot be called with 0
-- parameters") and crashed UE4SS (11-17, the pose's 16 ms LoopAsync against the tick). Every step is wrapped, so an
-- error in gun mode never reaches the rest of the mod.
local Config=require('gunmode.config')
local Rows=require('gunmode.rows')
local Aim=require('gunmode.aim')
local View=require('gunmode.view')
local Input=require('gunmode.input')
local Pose=require('gunmode.pose')
local Laser=require('gunmode.laser')
local Data=require('gunmode.data')

local GunMode={}

GunMode.STAND_PAK='zNikkeGunStand_P'
local EVE='/Game/Art/Character/PC/CH_P_EVE_01/Blueprints/CH_P_EVE_01_Blueprint.CH_P_EVE_01_Blueprint_C'
local LIB='/Script/SB.Default__SBBlueprintLibrary'
local NIKKE='Bullet_Nikke'

-- Whether a montage is the gun's own (the battle guard stops every other one for a moment after a battle change).
function GunMode.gun_montage(name)
    local n=name:lower()
    return n:find('gun',1,true) or n:find('nikke',1,true) or n:find('tps',1,true) or n:find('shoot',1,true)
end

-- Whether container name (a .utoc, .ucas and .pak) is in ~mods or LogicMods under paks (SB/Content/Paks): true, or
-- false and why. read(path): the file's first bytes, or nil.
function GunMode.find_pak(paks,read,name)
    if not paks then return false,'the game folder is unknown' end
    for _,dir in ipairs({'~mods','LogicMods'}) do
        local base=paks..'\\'..dir..'\\'..name
        if read(base..'.utoc') then
            for _,ext in ipairs({'.ucas','.pak'}) do
                if not read(base..ext) then return false,'no '..base..ext end
            end
            return true
        end
    end
    return false,'no '..name..' in ~mods or LogicMods'
end
local function read_start(path)
    local f=io.open(path,'rb')
    if not f then return nil end
    local text=f:read(4096) or ''
    f:close()
    return text
end
local function read_all(path)
    local f=io.open(path,'rb')
    if not f then return nil end
    local text=f:read('a')
    f:close()
    return text
end

-- env: {log, folder (the mod folder: coop-settings.txt, the starter-ammo flag, SB/Content/Paks above it), say (a
-- line on screen, optional), read and read_all (a file's first bytes, and all of it; io.open's unless given)}.
function GunMode.new(env)
    local cfg=Config.DEFAULTS
    local read,whole=env.read or read_start,env.read_all or read_all
    local set,bad=Config.parse(env.folder and whole(env.folder..'\\coop-settings.txt'))
    local sb=env.folder and env.folder:match('^(.*)[\\/][Bb]inaries[\\/][Ww]in64[\\/]')
    local paks=sb and sb..'\\Content\\Paks'
    env.stand,env.stand_why=GunMode.find_pak(paks,read,GunMode.STAND_PAK)
    env.say=env.say or function(text) env.log(text) end
    local g={}
    function g.log(m) env.log(m) end
    function g.valid(o)
        if o==nil then return false end
        local ok,r=pcall(function() return o:IsValid() end)
        return ok and r==true
    end
    function g.try(fn) local ok,r=pcall(fn); if ok then return r end end
    local cached -- The controller: FindFirstOf walks the whole object array.
    function g.pc()
        if g.valid(cached) then return cached end
        local pc=FindFirstOf('SBPlayerController')
        if g.valid(pc) then cached=pc; return pc end
    end
    function g.pawn()
        local pc=g.pc(); if not pc then return nil end
        local p=g.try(function() return pc.Pawn end)
        if g.valid(p) then return p end
    end
    function g.stance(p) return g.try(function() return p:GetCurrentStanceName():ToString() end) end
    local aim,view=Aim.new(g),View.new(g)
    local laser=Laser.new(g)
    local data=Data.new(g,set.fire_effect or nil)
    local pose=Pose.new(g,cfg.laser and laser or nil)
    local keys=Input.state()
    local self={}
    local s={on=false,crouched=false,since=0,pause=0,prev=nil,set_up=false,
        firing=false,next_shot=0,shots=0,aim_since=0,wait=nil,fire_n=0,last_fire=-1,
        guard_at=0,guard_last=0,guard_fails=0,guard_n=0,battle_until=0,
        roll_back=nil,roll_ready=0,ammo=nil,bag_empty=false,empty_hits=0,tps_hits=0,
        hud_at=0,off_serial=0,toggle_at=-1,blocked_at=0,hooked=false,battle_hooked=false,ammo_hooked=false}
    local t={pad=0,hold=0,battle=0,cam=0,mode=0,empty=0,tps=0}

    -- fn, on the game thread, ms from now (worked through by the loop; a delay of 0 is the next frame).
    s.timers={}
    local function later(ms,fn) s.timers[#s.timers+1]={at=os.clock()+ms/1000,fn=fn} end
    local function run_timers(now)
        if #s.timers==0 then return end
        local due,keep={},{}
        for _,e in ipairs(s.timers) do if e.at<=now then due[#due+1]=e else keep[#keep+1]=e end end
        s.timers=keep
        table.sort(due,function(a,b) return a.at<b.at end)
        for _,e in ipairs(due) do pcall(e.fn) end
    end
    local function fire_row(e)
        local lib=StaticFindObject(LIB)
        if not g.valid(lib) then return false end
        local ok,err=pcall(function() lib:CreateSBZoneEvent(e[1],FName(e[2])) end)
        if not ok then g.log('row '..e[2]..' failed: '..tostring(err)) end
        return ok
    end
    local function fire_rows(rows) for _,r in ipairs(rows) do fire_row(r) end end
    local function mode_type(p) return tonumber(g.try(function() return p:GetTPSModeType() end)) end
    local function tps(p) return g.try(function() return p:IsTPSMode() end) end

    -- Crouched: the NIKKE centre cover and its kneel animset; standing: neither (zNikkeGunStand_P makes the cover
    -- stance P_Eve_GunNikkeHide the standing one, gun out, with the stand animations).
    local function posture(tag)
        local p=g.pawn(); if not p then return end
        if s.crouched then
            fire_row(Rows.one(s.ns,'Pos2'))
            pcall(function() p:ActiveCustomMovingStanceData({ForceType=0,OverrideStanceAnim=FName(cfg.crouch_anim),
                NormalAnimRangeDegree=180.0}) end)
        else
            fire_row(Rows.one(s.ns,'PosOff'))
            pcall(function() p:DeactiveCustomMovingStanceData() end)
        end
        g.log('posture: '..(s.crouched and 'crouched' or 'standing')..' ('..tag..')')
    end

    -- The gun stance put back when the game drops it (combat draws the sword), at most once a cooldown, and not past 5
    -- tries in a row (EVE down: nothing brings it back until she is up).
    local function stance_guard(p,now)
        if now-s.guard_at<cfg.stance_check or now-s.since<1.5 then return end
        s.guard_at=now
        local stance=g.stance(p) or '?'
        local m=mode_type(p)
        -- Mode 0 is ours while standing; crouched, aim.crouch_tick puts 2 back within 0.25 s.
        if stance:find('GunNikke',1,true) and tps(p) and (m==2 or (m==0 and not aim.dead)) then
            s.guard_fails=0; return
        end
        if now-s.guard_last<cfg.stance_cooldown or s.guard_fails>=5 then return end
        s.guard_fails,s.guard_last,s.guard_n=s.guard_fails+1,now,s.guard_n+1
        if set.real_ammo then fire_row({2,'NGM_AE_GunOnAmmo'}); fire_row({2,'NGM_AE_ZeroOff'})
        else fire_row(Rows.one(s.ns,'GunOn')) end
        if s.crouched then fire_row(Rows.one(s.ns,'Pos2')) end
        if s.guard_n<=10 or s.guard_n%10==0 then
            g.log(('stance guard #%d: %s, TPS %s mode %s: gun stance put back'):format(s.guard_n,stance,
                tostring(tps(p)),
                tostring(m)))
        end
    end
    -- Every hold_ms: the NIKKE bullet and the look-at kept (plain property writes, as a real stage has them).
    local function hold(p,now)
        pcall(function()
            if p.CurrentBulletItemAlias:ToString()~=NIKKE then p.CurrentBulletItemAlias=FName(NIKKE) end
        end)
        pcall(function() if not p.CustomLookAtActive then p.CustomLookAtActive=true end end)
        stance_guard(p,now)
    end
    local function battle(p)
        local ai=g.try(function() return p.Mesh:GetAnimInstance() end)
        local m=g.valid(ai) and g.try(function() return ai:GetCurrentActiveMontage() end)
        if not g.valid(m) then return end
        local name=m:GetFName():ToString()
        if not GunMode.gun_montage(name) then pcall(function() ai:Montage_Stop(0.15,m) end) end
    end

    local function hook_battle()
        if s.battle_hooked then return end
        s.battle_hooked=pcall(function()
            RegisterHook(EVE..':Event_ChangeBattleState',function()
                if s.on then s.battle_until=os.clock()+cfg.battle_window end
            end)
        end)
    end
    -- With real ammo: the NIKKE round count from the item broadcasts (add and update carry the item with its total).
    local function hook_ammo()
        if s.ammo_hooked or not set.real_ammo then return end
        s.ammo_hooked=true
        for _,fn in ipairs({'ClientBroadcast_ItemBucketItemAdd','ClientBroadcast_ItemBucketItemUpdate'}) do
            pcall(function()
                RegisterHook('/Script/SB.SBNetworkPlayerController:'..fn,function(_,_,_,inst)
                    pcall(function()
                        local i=inst:get()
                        if i.ItemAlias:ToString()==NIKKE then
                            s.ammo=tonumber(i.ItemCount)
                            if s.ammo and s.ammo>0 then s.bag_empty=false end
                        end
                    end)
                end)
            end)
        end
    end

    -- The rows gun mode fires: SB's own, taken by gunmode/data.lua (GM), else a Survival Protocol pak's (NGM) when
    -- that has them; false: neither, gun mode cannot start. SB's rows go back at a new controller (tick).
    local function rows_ready()
        if s.ns then return true end
        if data.take() then s.ns='GM'
        elseif g.try(function()
                local t=StaticFindObject('/Game/Local/Data/EventActorEffectTable.EventActorEffectTable')
                return t:FindRow('NGM_AE_GunOn')
            end) then
            s.ns='NGM'; g.log('rows: Survival Protocol\'s NGM rows')
        else
            g.log('off: no rows (SB\'s could not be taken, and no Survival Protocol pak carries gun mode\'s)')
            return false
        end
        if set.real_ammo and s.ns~='NGM' then
            set.real_ammo=false
            g.log('real ammo off: its rows come only with a Survival Protocol pak built with gun mode\'s patches')
        end
        return true
    end

    local function enable()
        if not g.pawn() then return end
        if not rows_ready() then return end
        if set.real_ammo and s.bag_empty then
            env.say('Out of NIKKE rounds: buy more at a camp shop.'); return
        end
        if cfg.keep_hud then pcall(view.hud_snapshot) end
        fire_rows(Rows.on(set,s.ns))
        local p=g.pawn()
        local b=p and g.try(function() return p.CurrentBulletItemAlias:ToString() end)
        if b and b~=NIKKE then s.prev=b end
        local now=os.clock()
        s.on,s.crouched,s.since,s.set_up=true,false,now,false
        s.guard_n,s.guard_fails,s.empty_hits,s.tps_hits=0,0,0,0
        self.hook()
        later(700,function() if s.on then posture('entry') end end)
        for _,ms in ipairs({1000,2500}) do
            later(ms,function() if s.on and cfg.keep_hud then view.hud_restore() end end)
        end
        s.hud_at=now+4.0
        later(800,function() if s.on then view.reticle_scale(cfg.reticle_scale) end end)
        if cfg.wide_reticle then later(900,function() if s.on then view.wide(true) end end) end
        hook_battle()
        hook_ammo()
        if set.real_ammo then
            local flag=env.folder and env.folder..'\\coop-gunmode-starter.txt'
            local f=flag and io.open(flag,'r')
            if f then f:close()
            elseif fire_row({13,'NGM_ItemA_Ammo'}) and flag then
                local w=io.open(flag,'w'); if w then w:write(os.date()); w:close() end
                g.log('ammo: starter rounds given')
            end
            for _,ms in ipairs({600,1600}) do
                later(ms,function() if s.on then fire_row({2,'NGM_AE_ZeroOff'}) end end)
            end
            later(2200,function() if s.on then fire_row({2,'NGM_AE_EmptyExit'}) end end)
        end
        g.log('on')
        later(700,function()
            local p2=g.pawn()
            if p2 then g.log(('engaged: TPS %s mode %s'):format(tostring(tps(p2)),tostring(mode_type(p2)))) end
        end)
    end

    local function disable()
        if set.real_ammo then -- A NIKKE reload still pending would refill the bag the moment RealAmmo comes off.
            fire_row({2,'NGM_AE_ReloadCancel'})
            later(1500,function() if not s.on then fire_row({2,'NGM_AE_ReloadCancel'}) end end)
            later(4000,function()
                if not s.on then fire_row({2,'NGM_AE_ReloadCancel'}); fire_row({2,'NGM_AE_RealAmmoOff'}) end
            end)
        end
        local p=g.pawn()
        if p then pcall(function() p:DeactiveCustomMovingStanceData() end) end
        aim.set_mode(2,'exit')
        aim.camera_off()
        fire_rows(Rows.off(s.ns))
        -- An off soon after an on can land before the on rows: send the off rows again unless gun mode came back on.
        s.off_serial=s.off_serial+1
        local mine=s.off_serial
        for _,ms in ipairs({1200,3000}) do
            later(ms,function() if not s.on and mine==s.off_serial then fire_rows(Rows.off(s.ns)) end end)
        end
        s.on,s.firing,s.roll_back=false,false,nil
        view.reticle_scale(1.0)
        view.wide(false)
        if p then
            if s.prev and s.prev~='None' then pcall(function() p.CurrentBulletItemAlias=FName(s.prev) end) end
            pcall(function() p.CustomLookAtActive=false end)
        end
        g.log('off')
    end

    local function in_menu()
        local pc=g.pc()
        if not pc then return true end
        if g.try(function() return pc.bShowMouseCursor end) then return true end
        local stats=StaticFindObject('/Script/Engine.Default__GameplayStatics')
        return g.try(function() return stats:IsGamePaused(pc) end)==true
    end
    local function stuck()
        local p=g.pawn()
        local m=p and mode_type(p)
        return p~=nil and tps(p)==true and (m==2 or m==0)
    end
    function self.toggle(src)
        local now=os.clock()
        if now-s.toggle_at<0.4 then return end -- One press can reach both the key and Ctrl+key binds.
        if not s.on and stuck() then -- Off, yet still in the NIKKE stance: the key always sends the off rows again.
            s.toggle_at=now
            fire_rows(Rows.off(s.ns))
            g.log('toggle ('..src..'): the NIKKE stance was still on: off rows sent again')
            return
        end
        if in_menu() then
            if now-s.blocked_at>2 then s.blocked_at=now; g.log('toggle ('..src..') ignored: a menu or pause is up') end
            return
        end
        s.toggle_at=now
        local ok,err=pcall(s.on and disable or enable)
        if not ok then g.log('toggle error: '..tostring(err)) end
    end

    -- Firing. Only in the aim stance, or standing in the cover stance (its gun is out with zNikkeGunStand_P): the shot
    -- starts at the muzzle socket, and with the gun folded away the game read a null pointer and crashed.
    local function fire_once(p)
        local now=os.clock()
        if now-s.last_fire<cfg.fire_interval then return end
        s.last_fire=now
        if set.real_ammo and s.ammo and s.ammo<=0 then
            g.log('ammo: out of NIKKE rounds')
            later(200,function() if s.on then self.toggle('empty') end end)
            return
        end
        s.fire_n=s.fire_n+1
        if set.real_ammo then
            fire_row({13,'NGM_ItemA_Spend'})
            fire_row({2,'NGM_AE_EmptyExit'}) -- Applies only once the bag is empty.
            if s.ammo then s.ammo=s.ammo-1 end
        end
        local target=g.try(function() return p:GetTPSLookAtWorldLocation(true) end)
        if target then aim.write(p,target) end
        if s.ns=='GM' and not data.fire then -- The stance's own command fires (aimed); the row aimed it.
            if s.fire_n<=3 or s.fire_n%50==0 then g.log('aim #'..s.fire_n..' (the stance fires)') end
            return
        end
        local ok=fire_row(Rows.one(s.ns,'Fire'))
        if s.fire_n<=3 or s.fire_n%50==0 then g.log('shot #'..s.fire_n..(ok and '' or ' failed')) end
    end
    local function fire_step(now,inp)
        if not s.firing then return end
        if now<s.next_shot then return end
        local held=(not s.crouched and inp.fire_held) or inp.fire_ctrl
        if s.shots>0 and not held then s.firing=false; return end
        local p=g.pawn()
        local stance=p and g.stance(p)
        if not (stance=='P_Eve_GunNikke' or (stance=='P_Eve_GunNikkeHide' and not s.crouched)) then
            s.wait=s.wait or now
            if now-s.wait>1.0 then s.firing,s.wait=false,nil end
            return
        end
        s.wait=nil
        s.shots=s.shots+1
        pcall(fire_once,p)
        s.next_shot=now+cfg.fire_interval
    end
    local function start_firing(now)
        if not s.on or s.firing then return end
        s.firing,s.shots=true,0
        s.next_shot=math.max(now+cfg.first_shot_delay,s.aim_since+cfg.aim_ready)
    end

    local last={}
    local function poll(now)
        local pc=g.pc(); if not pc then return end
        local function down(name)
            local ok,d=pcall(function() return pc:IsInputKeyDown({KeyName=FName(name)}) end)
            return ok and d==true
        end
        local inp=Input.read(keys,down,now,cfg,set.key)
        last=inp
        if inp.toggle then self.toggle('D-pad Right') end
        if inp.key then self.toggle(set.key) end
        if inp.aim_start then s.aim_since=now end
        if not s.on then return end
        if inp.crouch then
            s.crouched=not s.crouched
            later(10,function() if s.on then posture('key') end end)
        end
        if inp.roll and not s.roll_back and now>=s.roll_ready then
            s.roll_back,s.since=now+cfg.roll_time,now -- The guards stay quiet during the roll.
            later(1,function() if s.on then fire_row(Rows.one(s.ns,'GunOff')); fire_row(Rows.one(s.ns,'PosOff')) end end)
        end
        local standing=not s.crouched
        if (standing and inp.fire) or (inp.fire_ctrl and not s.firing) then
            if standing then s.aim_since=math.min(s.aim_since,now-cfg.aim_ready) end -- Standing always aims.
            start_firing(now)
        end
    end

    -- The roll is over: the full on rows again (the gun alone left IsTPSMode false), the posture's row after them.
    local function roll_back(now)
        s.roll_back,s.since,s.roll_ready=nil,now,now+cfg.roll_cooldown
        later(1,function()
            if not s.on then return end
            fire_rows(Rows.on(set,s.ns))
            if set.real_ammo then fire_row({2,'NGM_AE_ZeroOff'}) end
            if s.crouched then fire_row(Rows.one(s.ns,'Pos2')) end
        end)
    end

    -- With real ammo: the gun stance gone (NGM_AE_EmptyExit applies once the bag is empty) ends gun mode.
    local function empty_check(p,now)
        if not set.real_ammo or now-s.since<=1.5 or now-t.tps<0.2 then return end
        t.tps=now
        local m=mode_type(p)
        if tps(p)==false or (m and m~=2 and not (m==0 and not aim.dead)) then
            s.tps_hits=s.tps_hits+1
            if s.tps_hits>=3 then
                s.tps_hits,s.bag_empty=0,true
                env.say('Out of NIKKE rounds.')
                later(100,function() if s.on then self.toggle('empty') end end)
            end
        else
            s.tps_hits=0
        end
    end

    local function tick()
        local now=os.clock()
        if now<s.pause then return end
        if s.give_back then s.give_back=false; s.ns=nil; pcall(data.put_back) end
        run_timers(now)
        if not g.valid(cached) or not g.valid(g.try(function() return cached.Pawn end)) then
            cached=nil
            if not g.pawn() then s.pause=now+2.0; return end -- Player objects going away: stay out a moment.
        end
        pcall(poll,now) -- Every frame: a quick tap lasts less than 50 ms.
        if not s.on then return end
        local p=g.pawn(); if not p then return end
        fire_step(now,last)
        if now-t.hold>=cfg.hold_ms/1000 then t.hold=now; pcall(hold,p,now) end
        if now<s.battle_until and now-t.battle>=0.05 then t.battle=now; pcall(battle,p) end
        if not s.set_up and now-s.since>1.0 then
            s.set_up=true
            pcall(aim.setup)
            pcall(view.reticle_show)
        end
        local standing=not s.crouched and not s.roll_back
        if standing and aim.mode0 and now-t.cam>=2.0 then t.cam=now; pcall(aim.camera_on,cfg.cam_offset) end
        if s.crouched and now-t.mode>=0.25 then t.mode=now; pcall(aim.crouch_tick)
        elseif standing and now-s.since>1.5 and now-t.mode>=1.0 then t.mode=now; pcall(aim.stand_tick,function() fire_row(Rows.one(s.ns,'GunOn')) end) end
        pcall(empty_check,p,now)
        if cfg.keep_hud and now>=s.hud_at then
            s.hud_at=now+1.5
            later(10,function() if s.on then view.hud_restore() end end)
        end
        if s.roll_back and now>=s.roll_back then roll_back(now) end
    end
    -- The pose: on and aimed while standing, set up and not rolling; a step of every frame.
    local function pose_step()
        if not set.pose then return end
        local want=s.on and s.set_up and not s.crouched and not s.roll_back
        pose.step(want,want)
    end

    -- The loop, once a Lua load: gun mode's tick, then the pose, every frame on the game thread.
    function self.hook()
        if s.hooked then return true end
        s.errors=0
        local function guarded(f)
            local ok,e=pcall(f)
            if not ok and s.errors<5 then s.errors=s.errors+1; g.log('error: '..tostring(e)) end
        end
        s.hooked=pcall(function() LoopInGameThreadWithDelay(1,function() guarded(tick); guarded(pose_step) end) end)
        return s.hooked
    end

    -- The new-controller reset and the loop. Nothing at all with gun_mode=off.
    function self.start()
        for _,why in ipairs(bad) do g.log('coop-settings.txt: '..why) end
        if not set.on then g.log('off (gun_mode=off in coop-settings.txt)'); return end
        if env.stand~=true then
            g.log('no standing animations ('..tostring(env.stand_why)..'): the NIKKE kneel only')
        end
        -- A new controller (map load, death, camp warp) starts with gun mode off. Its controller is cached at once:
        -- FindFirstOf could hand back the previous world's for ~2 s, and per-frame key reads then touched freed memory.
        -- Nothing here calls into the game: the controller is still being built (reading its pawn from this callback
        -- crashed UE4SS on the title screen). The new pawn's camera boom is a fresh one, so the saved offset just goes.
        NotifyOnNewObject('/Script/SB.SBPlayerController',function(pc)
            cached=pc
            s.pause=os.clock()+4.0
            s.give_back=true
            s.on,s.firing,s.roll_back,s.bag_empty,s.prev=false,false,nil,false,nil
            aim.cam_saved=nil
        end)
        if not self.hook() then g.log('off: this UE4SS has no LoopInGameThreadWithDelay'); return end
        g.log('ready: '..set.key..' or a tap of D-pad Right')
    end

    function self.status()
        return ('gun mode %s%s, key %s, real ammo %s, pose %s%s, rows %s, standing animations %s'):format(
            s.on and 'on' or 'off',s.on and (s.crouched and ' (crouched)' or ' (standing)') or '',set.key,
            set.real_ammo and 'on' or 'off',pose.on and 'on' or 'off',
            pose.failed and (' ('..pose.failed..' errors)') or '',
            s.ns=='GM' and 'its own' or s.ns=='NGM' and 'Survival Protocol\'s' or 'not made yet',
            env.stand and 'found' or 'missing')
    end
    self.toggle_now=function() self.toggle('command') end
    self.state=s
    return self
end

return GunMode
