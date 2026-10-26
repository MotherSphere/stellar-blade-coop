-- coop emote [list] | <name> | off: one of EVE's animation clips on the player's own EVE, on any save (nothing of it is
-- saved). The poses are the 31 clips of /Game/Art/Character/PC/CH_P_EVE_01/Animation/PhotoMode/ outside Bear/ and the
-- _Selfie files, each a still (7 frames over 0.2 s, or 2 frames over 0.033 s) played in a loop so EVE keeps it. They
-- are grouped under the six categories of the cut Social Action menu (StringTable_UI's UI_Gesture_Category_*, cut
-- survey entry 27), whose own gestures shipped as text only. Greetings also holds the selfie mode's two waves,
-- Hello_Selfie_L and _R (3 s each), played once outside their blend space, which follows the selfie camera's
-- direction. A seventh category, Cut, holds six clips of EVE's made for two enemies with no character folder, mesh,
-- CharacterTable row or text string in the game files, also played once: the Chariot's struggle (Hit_Chariot_Confront,
-- 14.8 s, then Hit_Chariot_ConfrontAttack or _ConfrontFail) and EVE's takedown on it
-- (P_Eve_Sword_Normal_LinkAttack1_Chariot), an enemy that was cut (cut survey entry 21); her takedown on Kali and Kali's
-- grab (P_Eve_Sword_Normal_LinkAttack1_Kali, M_Kali_Beta_Grab), an enemy the survey leaves unsure, possibly an early
-- name of a shipped one (entry 39). All are in CH_P_EVE_01/Animation/.
-- The native part plays the clip (game/anim.h): "anim play <id> <path> once|loop" asks SB's own custom animation call
-- on her, the way the game plays her clips, and "anim stop" blends ours out; the native status line's anim=<state>
-- anim_id=<id> says what became of our id (playing, ended, ended:weight when her blueprint took none of it, stopped,
-- refused:<why>, fault). Without that line (no native part, another game build) or after its fault, the clip goes in
-- as a dynamic montage in DefaultSlot of her animation instance instead (PlaySlotAnimationAsDynamicMontage),
-- looped for a pose, which most likely shows nothing: CH_P_EVE_01_AnimBP_New has no slot node in the 2026-10-06
-- extract. Either way her animation blueprint keeps running, the clip blends in and out over 0.25 s, and a friend sees
-- what the pose stream carries (the ghost copies her bones): nothing new travels.
-- It ends with a 0.25 s blend at movement input (GetLastMovementInputVector), in the air (a jump), at a skill (an
-- attack, a dodge: IsRunningSkill), when the clip ends or the game stops it, on another EVE (a map change), at coop
-- emote off, at another emote and at coop off; it does not start in the air or during a skill. Each clip is looked up
-- on its command (in memory, else LoadAsset: Doro.resolve), never in the frame: a path not in memory costs 25 to 35 ms.
-- Called here: the anim request or PlaySlotAnimationAsDynamicMontage at a command, anim stop or Montage_Stop at its
-- end, and each frame while one plays GetLastMovementInputVector, IsFalling, IsRunningSkill and the status line's
-- anim field or Montage_IsPlaying. The native part stops a clip an earlier Lua load left playing; the next Lua load
-- stops a montage an earlier one left (restore, at its first tick).
local UE=require('UEHelpers')
local U=require('core.unreal')
local Doro=require('race.doro')
local valid,value_of,find,address,text=U.valid,U.value_of,U.find,U.address,U.text
local Emote={}
local ANIM='/Game/Art/Character/PC/CH_P_EVE_01/Animation/'
local SEQUENCE='/Script/Engine.AnimSequence'
local SLOT='DefaultSlot'
local BLEND=0.25 -- s, in and out.
local LOOPS=1048576 -- A still looped this often holds for hours (a loop count of 0 would end it at once).
local STICK=0.1 -- Movement input longer than this ends an emote.
local ANSWER=5 -- s: a native play still unanswered after this ends the emote.
Emote.USE='Use: coop emote [list|<name>|off]'
-- The categories in the menu's order, each with its folder under ANIM and its emotes: the command's name, the clip's,
-- and true for a clip played once (the poses loop).
Emote.CATEGORIES={
    {'Greetings',{{'salute','Salute'},{'kungfu','KungFuSalute'},{'toast','Toast'},{'wave','Hello_Selfie_L',true},
        {'wave2','Hello_Selfie_R',true}},dir='PhotoMode/'},
    {'Expression',{{'clap','Clap'},{'heart','HandHeart'},{'thumbsup','ThumbUp'},{'victory','Victory'},
        {'kiss','Kiss'}},dir='PhotoMode/'},
    {'Orders',{{'bringiton','BringItOn'},{'giveme','GiveMe'},{'hush','Hush'},{'reach','Reach'}},dir='PhotoMode/'},
    {'Emotion',{{'omg','OMG'},{'what','What'},{'worry','Worry'},{'wish','Wish'},{'wedidit','WeDidIt'}},
        dir='PhotoMode/'},
    {'Pose',{{'charm','Charm'},{'confident','Confident'},{'cutie','Cutie'},{'sweetie','Sweetie'},
        {'squat','SlavSquart'},{'stretch','Stretch'},{'warmup','WarmUp'},{'walk','Walk'},{'shutter1','ShutterChance1'},
        {'shutter2','ShutterChance2'},{'shutter3','ShutterChance3'}},dir='PhotoMode/'},
    {'Dance',{{'flow','Flow'},{'nataraja','Natarajasana'},{'somersault','Somersault'}},dir='PhotoMode/'},
    {'Cut',{{'chariotstruggle','Hit_Chariot_Confront',true},{'chariotcounter','Hit_Chariot_ConfrontAttack',true},
        {'chariotfail','Hit_Chariot_ConfrontFail',true},
        {'chariottakedown','P_Eve_Sword_Normal_LinkAttack1_Chariot',true},
        {'kalitakedown','P_Eve_Sword_Normal_LinkAttack1_Kali',true},{'kaligrab','M_Kali_Beta_Grab',true}},dir=''},
}
-- name -> {clip=<its file name>, path=<its object path>, once=<played once>}.
Emote.POSES={}
for _,category in ipairs(Emote.CATEGORIES) do
    for _,pose in ipairs(category[2]) do
        assert(not Emote.POSES[pose[1]],pose[1]..' twice')
        Emote.POSES[pose[1]]={clip=pose[2],path=ANIM..category.dir..pose[2]..'.'..pose[2],once=pose[3]==true}
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
-- The native part's anim field: the state and id of its last play, or nil without it (no native part, another build,
-- coop off).
function Emote.native(status)
    local state,id=('\n'..(status or '')):match('\nengine=[^\r\n]* anim=(%S+) anim_id=(%d+)')
    return state,tonumber(id)
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

-- o: log (the [EM] lines), ask(line) (a native request: ok and its line) and status() (the native status text), both
-- nil without the native part.
function Emote.new(o)
    local log,ask,status=o.log,o.ask,o.status
    local self={}
    -- The emote that plays: {name, clip, at (her address), since}, then id (the native play's) or montage and anim
    -- (her animation instance).
    local cur=nil
    local restored=false
    local serial=os.time()%1000000 -- The last native id: a new Lua load starts elsewhere, so no old answer is ours.
    local function native()
        if not ask then return nil end
        local state,id=Emote.native(status and status())
        if state=='fault' then return nil end
        return state,id
    end
    -- The emote ended, logged with why; false when none plays. quiet: the clip went already, nothing to stop.
    local function stop(why,quiet)
        local c=cur
        if not c then return false end
        cur=nil
        local ok,err=true,nil
        if c.id and not quiet then
            ok,err=ask('anim stop')
        elseif not c.id then
            ok,err=pcall(function()
                local a,m=valid(c.anim),valid(c.montage)
                if a and m then a:Montage_Stop(BLEND,m) end
            end)
        end
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
        local how=pose.once and 'once' or 'loop'
        if native() then
            serial=serial%4294967295+1
            local ok,why=ask(('anim play %d %s %s'):format(serial,pose.path,how))
            if not ok then return false,'the native part did not take it: '..tostring(why) end
            cur={name=name,clip=pose.clip,id=serial,at=address(e),since=os.clock()}
            log(('emote %s: %s asked of the native part (anim %d, %s)'):format(name,pose.clip,serial,how))
            return true,'emote '..name..': move, jump, dodge or attack to stop it'
        end
        local m=valid(a:PlaySlotAnimationAsDynamicMontage(clip,FName(SLOT),BLEND,BLEND,1.0,pose.once and 1 or LOOPS,
            -1.0,0.0))
        if not m then
            log(('emote %s: no montage made for %s'):format(name,pose.clip))
            return false,'the game made no montage for '..pose.clip
        end
        cur={name=name,clip=pose.clip,montage=m,anim=a,at=address(e),since=os.clock()}
        log(('emote %s: %s in %s, montage %s, playing %s'):format(name,pose.clip,SLOT,text(m:GetFullName()),
            a:Montage_IsPlaying(m)==true and 'yes' or 'no'))
        return true,'emote '..name..': move, jump, dodge or attack to stop it'
    end
    -- The native part's answer for the native emote: nil while it plays or waits, else why it ended and whether
    -- something is left to stop, and a line for the screen when the clip never showed.
    local function answer(c)
        local state,id=native()
        if not state then return 'the native clips stopped',true,'coop emote stopped: the native clips stopped' end
        if id~=c.id then
            if os.clock()-c.since<ANSWER then return nil end
            return 'no answer from the native part',false,'coop emote stopped: no answer from the native part'
        end
        if state=='playing' then
            if not c.playing then
                c.playing=true
                log(('emote %s: %s plays (anim %d)'):format(c.name,c.clip,c.id))
            end
            return nil
        end
        if state=='ended' then return 'the clip ended',true end
        if state=='ended:weight' then
            return 'her animation blueprint showed nothing',true,'coop emote: EVE did not show '..c.clip
        end
        local refused=state:match('^refused:(.+)$')
        if refused then
            return 'the game refused it: '..refused,true,'coop emote: the game refused '..c.clip..' ('..refused..')'
        end
        return nil -- stopped or idle: an older word, or ours not taken yet.
    end
    -- One frame while an emote plays: whether it ends now, and a line for the screen.
    local function step()
        local e=her()
        if not e or address(e)~=cur.at then return stop('her EVE changed') end
        if cur.id then
            local why,quiet,said=answer(cur)
            if why then
                stop(why,quiet)
                return said
            end
        else
            local a,m=valid(cur.anim),valid(cur.montage)
            if not (a and m and a:Montage_IsPlaying(m)==true) then return stop('the montage no longer plays') end
        end
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
    -- Each frame, only while one plays. A failure stops it; returns false and why for the screen, as for a clip the
    -- game refused or did not show.
    function self.tick()
        if not cur then return end
        local ok,err=pcall(step)
        if ok then
            if type(err)=='string' then
                log(err)
                return false,err
            end
            return
        end
        local message='coop emote stopped: '..why_of(err)
        local stopped=pcall(stop,'error')
        log(message..(stopped and '' or ' (montage not stopped)'))
        return false,message
    end
    -- coop off.
    function self.stop() stop('coop off') end
    -- At the first tick of a Lua load: a montage an earlier load left (a dynamic one, under /Engine/Transient: the
    -- game's own come from its packages) is stopped on the player's EVE. Once. The native part stops a native clip
    -- itself at a new Lua load.
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
