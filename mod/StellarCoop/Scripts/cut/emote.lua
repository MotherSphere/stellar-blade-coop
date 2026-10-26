-- coop emote [list] | <name> | off: one of EVE's photo-mode poses on the player's own EVE, on any save (nothing of it
-- is saved). The poses are the 31 clips of /Game/Art/Character/PC/CH_P_EVE_01/Animation/PhotoMode/ outside Bear/ and
-- the _Selfie files (those sit in blend spaces that follow the selfie camera's direction; the wave exists only there,
-- so there is no hello). Each one is a still: 7 frames over 0.2 s, or 2 frames over 0.033 s. They are grouped
-- under the six categories of the cut Social Action menu (StringTable_UI's UI_Gesture_Category_*, cut survey entry 27),
-- whose own gestures shipped as text only.
-- Played as a dynamic montage in DefaultSlot of her animation instance (PlaySlotAnimationAsDynamicMontage), so her
-- animation blueprint keeps running, looped so the still holds, blended in and out over 0.25 s. Not tested in game:
-- CH_P_EVE_01_AnimBP_New has no slot node in the 2026-10-06 extract, so the montage may play with nothing shown, and
-- the start line logs the montage and whether it plays so one try tells. A friend sees what the pose stream carries
-- (the ghost copies her bones): nothing new travels.
-- It ends with a 0.25 s blend at movement input (GetLastMovementInputVector), in the air (a jump), at a skill (an
-- attack, a dodge: IsRunningSkill), when the montage no longer plays, on another EVE (a map change), at coop emote off,
-- at another emote and at coop off; it does not start in the air or during a skill. Each clip is looked up on its
-- command (in memory, else LoadAsset: Doro.resolve), never in the frame: a path not in memory costs 25 to 35 ms.
-- Called here: PlaySlotAnimationAsDynamicMontage at a command, Montage_Stop at its end, and each frame while one plays
-- Montage_IsPlaying, GetLastMovementInputVector, IsFalling and IsRunningSkill. The next Lua load stops a montage an
-- earlier one left (restore, at its first tick).
local UE=require('UEHelpers')
local U=require('core.unreal')
local Doro=require('race.doro')
local valid,value_of,find,address,text=U.valid,U.value_of,U.find,U.address,U.text
local Emote={}
local DIR='/Game/Art/Character/PC/CH_P_EVE_01/Animation/PhotoMode/'
local SEQUENCE='/Script/Engine.AnimSequence'
local SLOT='DefaultSlot'
local BLEND=0.25 -- s, in and out.
local LOOPS=1048576 -- A still looped this often holds for hours (a loop count of 0 would end it at once).
local STICK=0.1 -- Movement input longer than this ends an emote.
Emote.USE='Use: coop emote [list|<name>|off]'
-- The menu's categories in its order, each with its poses: the command's name, then the clip's.
Emote.CATEGORIES={
    {'Greetings',{{'salute','Salute'},{'kungfu','KungFuSalute'},{'toast','Toast'}}},
    {'Expression',{{'clap','Clap'},{'heart','HandHeart'},{'thumbsup','ThumbUp'},{'victory','Victory'},
        {'kiss','Kiss'}}},
    {'Orders',{{'bringiton','BringItOn'},{'giveme','GiveMe'},{'hush','Hush'},{'reach','Reach'}}},
    {'Emotion',{{'omg','OMG'},{'what','What'},{'worry','Worry'},{'wish','Wish'},{'wedidit','WeDidIt'}}},
    {'Pose',{{'charm','Charm'},{'confident','Confident'},{'cutie','Cutie'},{'sweetie','Sweetie'},
        {'squat','SlavSquart'},{'stretch','Stretch'},{'warmup','WarmUp'},{'walk','Walk'},{'shutter1','ShutterChance1'},
        {'shutter2','ShutterChance2'},{'shutter3','ShutterChance3'}}},
    {'Dance',{{'flow','Flow'},{'nataraja','Natarajasana'},{'somersault','Somersault'}}},
}
-- name -> {clip=<its file name>, path=<its object path>}.
Emote.POSES={}
for _,category in ipairs(Emote.CATEGORIES) do
    for _,pose in ipairs(category[2]) do
        assert(not Emote.POSES[pose[1]],pose[1]..' twice')
        Emote.POSES[pose[1]]={clip=pose[2],path=DIR..pose[2]..'.'..pose[2]}
    end
end
-- The names by category, for coop emote and coop emote list.
function Emote.list()
    local parts={}
    for _,category in ipairs(Emote.CATEGORIES) do
        local names={}
        for _,pose in ipairs(category[2]) do names[#names+1]=pose[1] end
        parts[#parts+1]=category[1]..': '..table.concat(names,', ')..'.'
    end
    return table.concat(parts,' ')..' coop emote <name> plays one; move, jump, dodge or attack to stop it.'
end
-- The rule, pure: why an emote ends this frame, or nil. stick: the length of her movement input; falling: in the air;
-- skill: a skill of hers runs.
function Emote.ends(stick,falling,skill)
    if stick>STICK then return 'movement input' end
    if falling then return 'in the air' end
    if skill then return 'a skill runs' end
    return nil
end

local function why_of(e) return (tostring(e):gsub('^.-:%d+: ','')) end -- Without the file and line.
local function her()
    local e=valid(UE.GetPlayer())
    return e and e:IsA(find('/Script/SB.SBCharacter')) and e or nil
end
local function anim_of(e)
    local mesh=valid(e.Mesh)
    return mesh and valid(mesh:GetAnimInstance()) or nil
end
local function falling(e)
    local move=valid(e.CharacterMovement)
    return move~=nil and move:IsFalling()==true
end

-- o: log (the [EM] lines).
function Emote.new(o)
    local log=o.log
    local self={}
    local cur=nil -- The emote that plays: {name, montage, anim (her animation instance), at (her address), since}.
    local restored=false
    -- The emote's montage stopped, logged with why; false when none plays.
    local function stop(why)
        local c=cur
        if not c then return false end
        cur=nil
        local ok,err=pcall(function()
            local a,m=valid(c.anim),valid(c.montage)
            if a and m then a:Montage_Stop(BLEND,m) end
        end)
        log(('emote %s ended (%s) after %.1f s%s'):format(c.name,why,os.clock()-c.since,
            ok and '' or ': not stopped ('..why_of(err)..')'))
        return true
    end
    local function play(name,pose)
        local e=her()
        if not e then return false,'no EVE in the world' end
        if falling(e) then return false,'EVE is in the air: try again on the ground' end
        if e:IsRunningSkill()==true then return false,'EVE is busy (a skill runs): try again once she stands' end
        local a=anim_of(e)
        if not a then return false,'EVE has no animation instance' end
        local clip=Doro.resolve(pose.path,SEQUENCE)
        if not clip then return false,pose.clip..' is missing on this PC' end
        stop('another emote')
        local m=valid(a:PlaySlotAnimationAsDynamicMontage(clip,FName(SLOT),BLEND,BLEND,1.0,LOOPS,-1.0,0.0))
        if not m then
            log(('emote %s: no montage made for %s'):format(name,pose.clip))
            return false,'the game made no montage for '..pose.clip
        end
        cur={name=name,montage=m,anim=a,at=address(e),since=os.clock()}
        log(('emote %s: %s in %s, montage %s, playing %s'):format(name,pose.clip,SLOT,text(m:GetFullName()),
            a:Montage_IsPlaying(m)==true and 'yes' or 'no'))
        return true,'emote '..name..': move, jump, dodge or attack to stop it'
    end
    -- One frame while an emote plays: whether it ends now.
    local function step()
        local e=her()
        if not e or address(e)~=cur.at then return stop('her EVE changed') end
        local a,m=valid(cur.anim),valid(cur.montage)
        if not (a and m and a:Montage_IsPlaying(m)==true) then return stop('the montage no longer plays') end
        local v=value_of(e:GetLastMovementInputVector())
        local why=Emote.ends(math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z),falling(e),e:IsRunningSkill()==true)
        if why then stop(why) end
    end
    function self.active() return cur~=nil end
    -- coop emote [list|<name>|off].
    function self.command(sub,extra)
        if extra~=nil then return false,Emote.USE end
        if sub==nil or sub=='list' then return true,Emote.list() end
        if sub=='off' then return true,stop('coop emote off') and 'emote off' or 'no emote plays' end
        local pose=Emote.POSES[sub]
        if not pose then return false,"no emote '"..sub.."': coop emote list names them" end
        return play(sub,pose)
    end
    -- Each frame, only while one plays. A failure stops it; returns false and why for the screen.
    function self.tick()
        if not cur then return end
        local ok,err=pcall(step)
        if ok then return end
        local message='coop emote stopped: '..why_of(err)
        local stopped=pcall(stop,'error')
        log(message..(stopped and '' or ' (montage not stopped)'))
        return false,message
    end
    -- coop off.
    function self.stop() stop('coop off') end
    -- At the first tick of a Lua load: a montage an earlier load left (a dynamic one, under /Engine/Transient: the
    -- game's own come from its packages) is stopped on the player's EVE. Once.
    function self.restore()
        if restored then return end
        restored=true
        local ok,err=pcall(function()
            local e=her()
            local a=e and anim_of(e)
            local m=a and valid(a:GetCurrentActiveMontage())
            if m and text(m:GetFullName()):find('/Engine/Transient.',1,true) then
                a:Montage_Stop(BLEND,m)
                log('emote restore: an earlier load\'s montage stopped')
            end
        end)
        if not ok then log('emote restore failed: '..why_of(err)) end
    end
    return self
end
return Emote
