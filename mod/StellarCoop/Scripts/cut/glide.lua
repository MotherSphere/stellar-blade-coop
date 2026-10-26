-- coop glide on|off: EVE's cut glide (cut survey entry 9), a test tool left out of the usage line. What is left of it
-- in the pinned build (Ghidra, 2026-10-26): ASBCharacter's bGlide (+0x1100) is read by the character movement's
-- GetGravityZ (FUN_14214d380, before flight and wall run: gravity times GlideGravityScale, 0.1), by its air control
-- (FUN_142154f80: GlideAirControlScale, 1.0, the same as without), by IsGlide (0x142686080, a plain read of it, which
-- the animation graph may use for Proto_Glide) and by the movement debug print ("Glide %s"). Nothing writes it, and
-- nothing reads GlideHoldKeyDurationOnJump (+0x1360, 0.2 in DefaultGame.ini) or RemainGlideKeyHoldDuration (+0x1364):
-- the code that started and ended a glide was cut, so no setting or cheat can turn it on. This module plays that part:
-- while coop glide is on, on a co-op save, it sets bGlide (a reflected property) while EVE falls, is past the top of
-- her jump (velocity Z at or below 0, so a held jump never carries her ten times higher) and the Jump key has been
-- held for 0.2 s, and clears it at once when any of that ends. Not during the developer flight (coop fly), whose
-- gravity bGlide would replace. The keys are the game's default Jump keys (Space, the pad's bottom face button), read
-- through the player controller's IsInputKeyDown; the time is EVE's world time, which stops in the pause menu. Its
-- only write is bGlide on the player's own EVE, never saved (a transient property): coop glide off, coop off, a save
-- that is not a co-op one (checked once a second) and the next Lua load (restore, at its first tick) put false back.
local UE=require('UEHelpers')
local U=require('core.unreal')
local valid,value_of,find=U.valid,U.value_of,U.find
local Glide={}
Glide.HOLD=0.2 -- s: the game's GlideHoldKeyDurationOnJump, which nothing reads any more.
-- ponytail: the default Jump keys only (DefaultInput.ini); a rebound Jump key is not followed. Read the player's
-- mappings if that matters.
Glide.KEYS={'SpaceBar','Gamepad_FaceButton_Bottom'}
local MAX_DT=0.1 -- s: a longer frame (a hitch) counts as this much.
local SLOT_EVERY=1 -- s between two co-op save checks while on.

-- The rule, pure: s.held, how long Jump has been held (s), grows by dt while held and drops to 0 at a release. Glide
-- while she falls past the top of her jump, not in the developer flight, with Jump held HOLD s.
function Glide.want(s,dt,held,falling,descending,flying)
    s.held=held and s.held+math.min(math.max(dt,0),MAX_DT) or 0
    return falling and descending and not flying and s.held>=Glide.HOLD
end

local function her(pawn) return pawn and pawn:IsA(find('/Script/SB.SBCharacter')) and pawn or nil end
local function why_of(e) return (tostring(e):gsub('^.-:%d+: ','')) end -- Without the file and line.

-- o: log (the [GL] lines) and slot() (true on a co-op save, else false and why; main.lua's coop_slot).
function Glide.new(o)
    local log,slot=o.log,o.slot
    local self={}
    local on=false
    local s={held=0}
    -- EVEs are told apart by address: UE4SS gives a new wrapper at each read, and nothing here shows two wrappers of
    -- one object comparing equal (partner/capture.lua compares addresses too).
    local set,set_at=nil,nil -- The EVE whose bGlide is ours (true), until put back, and her address.
    local since=0 -- Her world time when the glide began.
    local t=nil -- Her world time at the last frame, nil after a frame without her.
    local seen=nil -- The address of the last frame's EVE.
    local slot_at,slot_ok=-math.huge,false
    local restored=false
    local fkeys={}
    -- bGlide false again on the EVE we set it on, while she is still an object. Logs why, with the glide's length.
    local function back(why,now)
        local e=set
        if not e then return end
        set,set_at=nil,nil
        local ok,err=pcall(function() if valid(e) then e.bGlide=false end end)
        log(('glide ended (%s) after %.1f s%s'):format(why,math.max((now or since)-since,0),
            ok and '' or ': bGlide not put back ('..why_of(err)..')'))
    end
    local function held(pc)
        for _,name in ipairs(Glide.KEYS) do
            fkeys[name]=fkeys[name] or {KeyName=FName(name)}
            if pc:IsInputKeyDown(fkeys[name])==true then return true end
        end
        return false
    end
    -- One frame: whether she glides now, and bGlide set or put back to match.
    local function step()
        if os.clock()>=slot_at then slot_at,slot_ok=os.clock()+SLOT_EVERY,slot()==true end
        local e=her(valid(UE.GetPlayer()))
        local at=e and U.address(e)
        if set and set_at~=at then back('her EVE changed',t) end
        if at~=seen then seen,t,s.held=at,nil,0 end -- Another EVE (a map change): her own time, a new hold.
        if not e or not slot_ok then
            back('not a co-op save',t) -- Without her, ours went back just above.
            t,s.held=nil,0
            return
        end
        local now=tonumber(value_of(e:GetGameTimeSinceCreation())) or 0
        local dt=t and now-t or 0
        t=now
        local move=valid(e.CharacterMovement)
        local falling=move~=nil and move:IsFalling()==true
        local glide,vz=false,0
        if falling then -- The rest only in the air: on the ground, her movement mode alone.
            local pc=U.controller()
            vz=value_of(e:GetVelocity()).Z
            glide=Glide.want(s,dt,pc~=nil and held(pc),true,vz<=0,e.bFlyingAction==true)
        else
            Glide.want(s,dt,false,false,false,false)
        end
        if glide and not set then -- A set one is this EVE: another went back above.
            e.bGlide=true
            set,set_at,since=e,at,now
            log(('glide on EVE (velocity Z %.0f cm/s)'):format(vz))
        elseif not glide and set then
            back(not falling and 'landed' or s.held==0 and 'Jump released' or 'flight or rising',now)
        end
    end
    -- Off: ours put back, nothing more read. Returns the answer.
    function self.off(why)
        local was=on
        back(why,t)
        on,t,s.held=false,nil,0
        return was and 'glide off' or 'glide off already'
    end
    function self.active() return on end
    -- coop glide on|off (main.lua's commands/cut.lua checks the co-op save before on).
    function self.command(sub,extra)
        if extra~=nil or (sub~='on' and sub~='off') then return false,'Use: coop glide on|off' end
        if sub=='off' then return true,self.off('coop glide off') end
        on,slot_at=true,-math.huge
        log('glide on')
        return true,'glide on: hold Jump (Space, or A/Cross) in the air, from the top of the jump'
    end
    -- Each frame while on. A failure puts bGlide back and turns it off; returns false and why for the screen.
    function self.tick()
        if not on then return end
        local ok,err=pcall(step)
        if ok then return end
        local message='coop glide stopped: '..why_of(err)
        local put=pcall(self.off,'error')
        log(message..(put and '' or ' (bGlide not put back)'))
        return false,message
    end
    -- coop off.
    function self.stop() self.off('coop off') end
    -- At the first tick of a Lua load: an earlier load may have left bGlide set on her (it is never the game's: no
    -- code of the game writes it), so false goes back on the player's EVE if it reads true. Once.
    function self.restore()
        if restored then return end
        restored=true
        local ok,err=pcall(function()
            local e=her(valid(UE.GetPlayer()))
            if e and e.bGlide==true then
                e.bGlide=false
                log('glide restore: bGlide was left on, put back')
            end
        end)
        if not ok then log('glide restore failed: '..why_of(err)) end
    end
    return self
end
return Glide
