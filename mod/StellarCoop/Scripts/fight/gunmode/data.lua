-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's shot, without a pak of tables: fields of SB's own rows (live data, as FindRow gives them), changed while
-- gun mode is out and put back at put_back() (a new world), so the NIKKE missions find them as shipped. No row is
-- added to a table: only fields of rows SB ships change.
-- * EventActorEffectTable: Nikke_01_E_ActorEff_015 (a NIKKE mission's cover row) applies M_Scarlet_CounterLinkStart;
--   fight/gunmode/mode.lua fires it as a zone event for each shot.
-- * EffectTable: M_Scarlet_CounterLinkStart (0.1 s on self, one UseSkill action) starts P_Eve_GunNikke_ShootSlug1_1,
--   the NIKKE shot. Its ActionValue1 is an FString: an FName written there crashed the game (11-17).
-- * SkillCommandTable: the NIKKE fire commands ShootSlug1_1 and _2 take the burst shot's command type
--   (RangedFireSkill: no check of the equipped bullet), as an older gun mode pak did.
-- * SkillActiveStepTable: the shot's Hit1 step takes its Cast1 step's type (fires its projectile, spends no round).
-- * Native fire (fight/gunmode/mode.lua's firing mode on the game's own aim): the drone's normal fire commands
--   (P_Eve_Gun_Shoot*, every round's) start the NIKKE shot skill instead of the drone's, with the burst's command type
--   (no round spent) and no "not while jumping" check (bJumping takes bWallRun's None).
-- Neither Survival Protocol's pak nor any gun mode pak is needed.
local Data={}

local BASE='/Game/Local/Data/'
Data.OWN={} -- Rows used as SB ships them: logical name -> {row, its effect} (checked before use).
-- Rows borrowed while gun mode is out: logical name -> {row, the effect it is pointed at}.
Data.FIRE_EFFECT='M_Scarlet_CounterLinkStart'
Data.BORROWED={Fire={'Nikke_01_E_ActorEff_015',Data.FIRE_EFFECT}}
Data.BORROW_ORDER={'Fire'}
Data.FIRE_SKILL='P_Eve_GunNikke_ShootSlug1_1'
Data.FIRE_COMMANDS={'P_Eve_GunNikke_ShootSlug1_1','P_Eve_GunNikke_ShootSlug1_2'}
Data.BURST_COMMAND='P_Eve_GunNikke_ShootSlug2_1'
-- Every drone fire command, of every round (the game loads the round the player picked each time she aims), the empty
-- ones (Fail) included: each starts the NIKKE shot while the rifle is out.
Data.AIM_STANCE='P_Eve_Gun'
Data.SPEED_FIELDS={'WalkSpeed','RunSpeed','JoggingRunSpeed','LockOnWalkSpeed','LockOnRunSpeed'}
Data.NIKKE_PROJECTILE,Data.DRONE_PROJECTILE='P_Eve_GunNikke_ShootSlug1_Projectile1','P_Eve_Gun_ShootSlug1_Projectile1'
Data.DRONE_COMMANDS={}
for _,kind in ipairs({'Slug1','Missile1','Railgun1','Railgun2','Railgun3','Railgun4','ScatterSlug1','ShockSlug1',
        'ExplosiveSlug1','SlugFail1','ScatterSlugFail1','ShockSlugFail1','ExplosiveSlugFail1'}) do
    for _,n in ipairs({'_1','_2'}) do Data.DRONE_COMMANDS[#Data.DRONE_COMMANDS+1]='P_Eve_Gun_Shoot'..kind..n end
end
Data.HIT_STEP,Data.CAST_STEP='P_Eve_GunNikke_ShootSlug1_1_Hit1','P_Eve_GunNikke_ShootSlug1_1_Cast1'

-- The row name for logical name k ('GunOn', 'Fire', ...), or nil.
function Data.row(k)
    local e=Data.OWN[k] or Data.BORROWED[k]
    return e and e[1]
end

-- g: gun mode's shared state (log, try, valid). Returns an object: take() points the rows at gun mode's data (true,
-- or false and why), put_back() restores what take() changed.
-- opts (native fire only): speed (the aim stance's speed factor), upper (an animation set for its upper body, or nil).
function Data.new(g,native,opts)
    local self={saved=nil,fire=true,native=native==true,opts=opts or {speed=1}}
    local function tbl(name)
        local t=g.try(function() return StaticFindObject(BASE..name..'.'..name) end)
        assert(g.valid(t),'no '..name)
        return t
    end
    local function text(v) return g.try(function() return v:ToString() end) or tostring(v) end
    local function row(t,name)
        local r=g.try(function() return t:FindRow(name) end)
        assert(r,'no row '..name)
        return r
    end

    function self.take()
        if self.saved then return true end
        local saved={}
        local ok,err=pcall(function()
            local eae=tbl('EventActorEffectTable')
            for k,e in pairs(Data.OWN) do
                local got=text(row(eae,e[1]).ActorEffectAlias)
                assert(got==e[2],e[1]..' applies '..got..', not '..e[2])
            end
            local spare=nil -- NIKKE mission rows to borrow in place of one this game version lacks.
            local function take_spare(used)
                if not spare then
                    spare={}
                    g.try(function() eae:ForEachRow(function(name)
                        local n=text(name)
                        if n:match('^Nikke_') then spare[#spare+1]=n end
                    end) end)
                    table.sort(spare)
                end
                for _,n in ipairs(spare) do if not used[n] then used[n]=true; return n end end
            end
            local used={}
            for _,e in pairs(Data.OWN) do used[e[1]]=true end
            for _,e in pairs(Data.BORROWED) do used[e[1]]=true end
            for _,k in ipairs(Data.BORROW_ORDER) do
                local e=(k~='Fire' or self.fire) and Data.BORROWED[k]
                if e and not g.try(function() return eae:FindRow(e[1]) end) then
                    local n=take_spare(used)
                    assert(n,'no spare row for '..k)
                    g.log('data: '..e[1]..' missing, borrowing '..n..' for '..k)
                    e[1]=n
                end
                if e then
                    local r=row(eae,e[1])
                    saved[#saved+1]={r,'ActorEffectAlias',FName(text(r.ActorEffectAlias))}
                    r.ActorEffectAlias=FName(e[2])
                end
            end
            if self.fire then
                local fire=row(tbl('EffectTable'),Data.FIRE_EFFECT)
                local was=text(fire.ActionValue1)
                saved[#saved+1]={fire,'ActionValue1',was}
                fire.ActionValue1=Data.FIRE_SKILL
            end
            -- The NIKKE shot's cool time: the rifle's rate of fire (opts.cool s between rounds).
            if self.opts.cool then
                local sk=row(tbl('SkillTable'),Data.FIRE_SKILL)
                saved[#saved+1]={sk,'CoolTime',sk.CoolTime}
                sk.CoolTime=self.opts.cool
                self.cool_row=sk
            end
            local cmd=tbl('SkillCommandTable')
            local kind=row(cmd,Data.BURST_COMMAND).CommandActionType
            for _,name in ipairs(Data.FIRE_COMMANDS) do
                local r=row(cmd,name)
                saved[#saved+1]={r,'CommandActionType',r.CommandActionType}
                r.CommandActionType=kind
            end
            if self.native then
                for _,name in ipairs(Data.DRONE_COMMANDS) do
                    local r=g.try(function() return cmd:FindRow(name) end)
                    if r then
                    saved[#saved+1]={r,'SkillAlias',FName(text(r.SkillAlias))}
                    saved[#saved+1]={r,'CommandActionType',r.CommandActionType}
                    saved[#saved+1]={r,'bJumping',r.bJumping}
                    r.SkillAlias=FName(Data.FIRE_SKILL) -- An FName (NamePropertyData), as the JSON of the table shows.
                    r.CommandActionType=kind
                    r.bJumping=r.bWallRun
                    end
                end
                -- The game's aim stance: faster (its own speed fields, so its walk and run play for the new speed),
                -- and with opts.upper its upper body from that animation set (the NIKKE rifle's).
                local st=row(tbl('CharacterStanceTable'),Data.AIM_STANCE)
                local pak=self.opts.pak
                for _,f in ipairs(Data.SPEED_FIELDS) do
                    local v=g.try(function() return st[f] end)
                    if type(v)=='number' then
                        saved[#saved+1]={st,f,v}
                        st[f]=(pak and pak.speeds and pak.speeds[f]) or v*self.opts.speed
                    end
                end
                -- With the pak: no drone summon/dismiss show when the aim starts and ends (it played the drone's
                -- raise pose for a moment before her rifle aim); her default stance has none either.
                if pak then
                    for _,f in ipairs({'StartShowPathWhenPeaceful','StartShowPathWhenBattle','EndShowPathWhenPeaceful','EndShowPathWhenBattle'}) do
                        local v=g.try(function() return text(st[f]) end)
                        if v and v~='' and v~='None' then
                            saved[#saved+1]={st,f,v}
                            local ok=pcall(function() st[f]='' end)
                            g.log('data: aim stance '..f..(ok and ' cleared (was '..v..')' or ' could not be cleared'))
                        end
                    end
                end
                -- Jumping in the aim (fight/gunmode/mode.lua launches her): a jump no longer ends the aim stance
                -- (Condition_Jumping as EVE's default stance has it).
                local def=g.try(function() return tbl('CharacterStanceTable'):FindRow('P_Eve_Default') end)
                local none=def and g.try(function() return def.Condition_Jumping end)
                if none~=nil then
                    saved[#saved+1]={st,'Condition_Jumping',st.Condition_Jumping}
                    st.Condition_Jumping=none
                end
                -- (test, opts.bs) the aim stance's animation set's blend spaces pointed elsewhere while the rifle is
                -- out: whether the game reads them again each time she aims.
                if self.opts.bs then
                    local ar=g.try(function() return tbl('CharacterAnimSetTable'):FindRow('P_Eve_Gun_Battle') end)
                    if ar then
                        for _,f in ipairs({'RunBlendSpace','RunTiltBlendSpace','LockOnRunBlendSpace'}) do
                            local was=text(ar[f])
                            saved[#saved+1]={ar,f,was}
                            ar[f]=self.opts.bs
                        end
                        g.log('data: P_Eve_Gun_Battle blend spaces -> '..self.opts.bs)
                        if pak and pak.aim_offset then
                            saved[#saved+1]={ar,'AimOffsetBlendSpace',text(ar.AimOffsetBlendSpace)}
                            ar.AimOffsetBlendSpace=pak.aim_offset
                            g.log('data: P_Eve_Gun_Battle aim offset -> '..pak.aim_offset)
                        end
                    else g.log('data: no CharacterAnimSetTable row P_Eve_Gun_Battle') end
                end
                -- The rifle carried, by a custom moving stance (fight/gunmode/mode.lua): its OverrideStanceAnim names an
                -- animation set row she has never loaded (the game keeps a set once loaded, so her own rows can't be
                -- changed in play). A spare NPC row is filled with P_Eve_Peaceful's fields and the rifle swaps.
                if pak and pak.carry and self.opts.carry_ovr=='auto' then
                    local at=tbl('CharacterAnimSetTable')
                    local src=row(at,'P_Eve_Peaceful')
                    -- Spare rows: NPC death sets (never loaded by EVE). opts.carry_spare picks the nth (testing: a row
                    -- once loaded keeps its first contents for the rest of the session).
                    local cands={}
                    g.try(function() at:ForEachRow(function(rn)
                        local n=text(rn)
                        if n:match('^N_.+_Dead$') then cands[#cands+1]=n end
                    end) end)
                    table.sort(cands)
                    local name=cands[(self.opts.carry_spare or 0)+1]
                    g.log('data: '..#cands..' spare animation set rows, carry uses '..tostring(name))
                    assert(name,'no spare animation set row for the carry')
                    local dst=row(at,name)
                    local n,bad=0,0
                    local fields={}
                    g.try(function() at.RowStruct:ForEachProperty(function(pr) fields[#fields+1]=pr:GetFName():ToString() end) end)
                    for _,f in ipairs(fields) do
                        local ok=pcall(function()
                            local v=src[f]
                            local was=dst[f]
                            if type(v)=='userdata' then
                                local t=g.try(function() return v:ToString() end)
                                if t==nil then error('skip') end
                                local isname=g.try(function() return v:GetComparisonIndex() end)~=nil
                                saved[#saved+1]={dst,f,isname and FName(text(was)) or text(was)}
                                dst[f]=isname and FName(t) or t
                            else
                                saved[#saved+1]={dst,f,was}
                                dst[f]=v
                            end
                        end)
                        if ok then n=n+1 else bad=bad+1 end
                    end
                    dst.RunBlendSpace=pak.carry
                    saved[#saved+1]={dst,'RunTiltBlendSpace',text(dst.RunTiltBlendSpace)}
                    dst.RunTiltBlendSpace=pak.carry
                    dst.IdleAnimType=self.opts.carry_idle_type or 1 -- battle type: her idle is the blend space's centre (the rifle idle)
                    local c=0
                    for _,f in ipairs(pak.carry_fields or {}) do
                        local v=g.try(function() return text(dst[f]) end)
                        local x=v and v:match('^Animation/Proto_(.+)$')
                        if x then dst[f]='Animation/NGM/NGM_R_C_'..x; c=c+1 end
                    end
                    self.carry_ovr_row=name
                    g.log('data: carry row '..name..': '..n..' fields from P_Eve_Peaceful ('..bad..' skipped), '..c..' clips -> rifle, run -> '..pak.carry..', rows '..#fields)
                end
                if self.opts.upper then
                    for _,f in ipairs({'AnimSet_Battle_UpperBody','AnimSet_Peaceful_UpperBody'}) do
                        saved[#saved+1]={st,f,FName(text(st[f]))}
                        st[f]=FName(self.opts.upper)
                    end
                end
            end
            -- The NIKKE bullet starts from a point fight/gunmode/mode.lua keeps on the rifle's muzzle: its start the
            -- same kind of point as its destination (EVE's base and an offset in her yaw frame), not the
            -- SC_GunShoot socket of the NIKKE rifle the game attaches only in the NIKKE stance (outside it the
            -- shot left from the drone).
            local pt=tbl('ProjectileTable')
            local nr=row(pt,Data.NIKKE_PROJECTILE)
            local dr=row(pt,Data.DRONE_PROJECTILE)
            for _,f in ipairs({'StartTargetTransformType','StartTargetRelativeAxisType','DestTargetTransformType',
                    'DestTargetRelativeAxisType','DestTarget'}) do -- The Dest pair: fight/gunmode/aim.lua sets it next.
                saved[#saved+1]={nr,f,nr[f]}
            end
            local dl=nr.DestTargetRelativeLocation
            saved[#saved+1]={nr,'DestTargetRelativeLocation',{X=dl.X,Y=dl.Y,Z=dl.Z}}
            -- The NIKKE bullet's spread: its destination is shipped with a random range of 300 cm on each axis
            -- (the drone's has none); zero while the rifle is out, so every round lands on the reticle.
            local rr=nr.DestTargetRandomRange
            saved[#saved+1]={nr,'DestTargetRandomRange',{X=rr.X,Y=rr.Y,Z=rr.Z}}
            nr.DestTargetRandomRange={X=0,Y=0,Z=0}
            -- The destination is placed from EVE's root: DestTarget (a byte at 0x1dd, property params 0x145e00000;
            -- ESBProjectileTarget, enum params 0x146d34f70 on 26123051: MainActor 0, OtherActor 1, SetLocation 2,
            -- StartToDestDirection 3, SkillTargetLocation 4, InputTransform 5). The row ships StartToDestDirection.
            -- With it the shot (0x141c4be30) puts the destination StartToDestDirectionDistance (a float at 0x238,
            -- params 0x145dffce8) out on the line from the muzzle to the skill's own target location (on that location
            -- for 0). It adds the offset there in world axes (turned by the zero rotator 0x147112ca8). Rounds went to
            -- the side of the reticle point. MainActor builds the target on her (0x14228c020): the target's update
            -- (0x142431530) puts it on her RootComponent's world location (component+0x200) for Base and turns the
            -- offset by that component's rotation (component+0x1f0) for RootAxis. aim.write writes in that frame with her
            -- yaw alone: her root's pitch and roll are taken as 0.
            local dt=nr.DestTarget
            nr.DestTarget=0
            g.log(('data: NIKKE round: dest target %s -> 0, start target %s, start-to-dest distance %s'):format(
                tostring(dt),tostring(nr.StartTarget),tostring(nr.StartToDestDirectionDistance)))
            local sl=nr.StartTargetRelativeLocation
            saved[#saved+1]={nr,'StartTargetRelativeLocation',{X=sl.X,Y=sl.Y,Z=sl.Z}}
            nr.StartTargetTransformType=dr.DestTargetTransformType
            nr.StartTargetRelativeAxisType=dr.DestTargetRelativeAxisType
            local step=g.try(function() return tbl('SkillActiveStepTable') end)
            local hit=step and g.try(function() return step:FindRow(Data.HIT_STEP) end)
            local cast=step and g.try(function() return step:FindRow(Data.CAST_STEP) end)
            if hit and cast then
                saved[#saved+1]={hit,'StepType',hit.StepType}
                hit.StepType=cast.StepType
            end
        end)
        if not ok then
            for i=#saved,1,-1 do local e=saved[i]; pcall(function() e[1][e[2]]=e[3] end) end
            g.log('data: not taken ('..tostring(err)..')')
            return false,err
        end
        self.saved=saved
        g.log('data: '..#saved..' fields of SB\'s rows taken for gun mode')
        return true
    end

    -- The shot's cool time now (the rate of fire, or a reload's wait); put back with the rest at put_back().
    function self.cool(v)
        if self.saved and self.cool_row then self.cool_row.CoolTime=v end
    end

    function self.put_back()
        self.cool_row=nil
        local saved=self.saved
        self.saved=nil
        if not saved then return end
        for i=#saved,1,-1 do local e=saved[i]; pcall(function() e[1][e[2]]=e[3] end) end
        g.log('data: SB\'s rows put back')
    end

    return self
end

return Data
