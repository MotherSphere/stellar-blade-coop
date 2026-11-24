-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The emote wheel: coop emote's clips (eve/emote.lua's CATEGORIES) on the kit's wheel (ui/kit/wheel.lua, the runtime's
-- M.wheel), a page a category and Pose's 11 on two, each named in the game's own words where it has them
-- (StringTable_UI's UI_PhotoMode_Pose_<clip>; the waves' UI_PhotoMode_Pose_Hello_Selfie with their side; the pages'
-- UI_Gesture_Category_*; the centre's UI_HUD_Gesture), else in SBO's (ui/text's emote and wheel: the Cut clips, and
-- every name under ui_language=english). emote_key held (main/keys.lua) or D-pad Left held 0.3 s (main/input.lua, with
-- emote_pad=dpad_left) opens it on the page last used in this Lua load; the release plays the slot pointed at through
-- coop emote's own path (run). It does not open, and it closes with nothing played, while EVE is busy (eve/emote.lua's
-- busy: the bike, the air, a skill, a fight, a cutscene); its refusals go on screen. Logs [EM] wheel: lines.
local Emote=require('eve.emote')
local Kit=require('ui.kit.wheel')
local T=require('ui.text')
local EW={}
-- Each category's fallback word (ui/text's emote.cats) and its game key's end (UI_Gesture_Category_<end>; Cut has
-- none).
local CATS={Greetings={'greetings','Greetings'},Expression={'expression','Expression'},Orders={'orders','Instruction'},
    Emotion={'emotion','Emotion'},Pose={'pose','Pose'},Dance={'dance','Dance'},Cut={'cut'}}
EW.CATS=CATS
-- An emote's game key (nil for the Cut clips), its fallback name's key and, for the two waves, its side.
function EW.keys(category,pose)
    local side=pose[2]:match('^Hello_Selfie_([LR])$')
    if side then return 'UI_PhotoMode_Pose_Hello_Selfie','hello',side=='L' and 'left' or 'right' end
    return category.dir=='PhotoMode/' and 'UI_PhotoMode_Pose_'..pose[2] or nil,pose[1]
end
-- The wheel's pages in w's words, game(key) first (SB's word or nil).
function EW.pages(w,game)
    local groups={}
    for _,c in ipairs(Emote.CATEGORIES) do
        local cat=CATS[c[1]]
        local slots={}
        for _,pose in ipairs(c[2]) do
            local key,name,side=EW.keys(c,pose)
            local label=key and game(key) or w.emote.names[name]
            slots[#slots+1]={id=pose[1],label=side and w.emote[side]:format(label) or label}
        end
        groups[#groups+1]={title=cat[2] and game('UI_Gesture_Category_'..cat[2]) or w.emote.cats[cat[1]],slots=slots}
    end
    return Kit.pages(groups)
end
local function none() end
-- o: {wheel=function() -> the kit's wheel or nil (no Steam link), words=function() -> the player's words, game=SB's
-- word for a StringTable_UI key or nil (main/base.lua's game_words), busy=eve/emote.lua's busy, run=main/commands.lua's
-- run (coop emote <id>, logged and refused at coop off as the console's), log=, say=function(text, en)}.
function EW.new(o)
    local self={}
    local last,cache=1,{}
    local function busy()
        local ok,why=pcall(o.busy)
        if not ok then return 'EVE unreadable: '..tostring(why) end
        return why
    end
    local function closed(why,id,page)
        last=page
        if not id then return o.log('wheel: closed ('..why..')') end
        o.log('wheel: emote '..id..' ('..why..')')
        local ok,message=o.run('emote',id)
        if not ok then o.say(tostring(message)) end
    end
    -- emote_key (device 'key', key: its F-key's number) or D-pad Left held (device 'pad'): the wheel opened, or its
    -- refusal said.
    function self.press(device,key)
        local wheel=o.wheel()
        if not wheel or wheel.is_open() then return end
        local w=o.words()
        local why=busy()
        if why then
            o.log('wheel: not opened: '..why)
            return o.say(w.wheel.busy,T.en.wheel.busy)
        end
        if cache.w~=w then cache={w=w,pages=EW.pages(w,o.game),title=o.game('UI_HUD_Gesture') or w.wheel.title} end
        local ok,word,en=wheel.open({pages=cache.pages,page=last,title=cache.title,device=device,key=key,guard=busy,
            closed=closed})
        if not ok then
            o.log('wheel: not opened: '..en)
            return o.say(w.wheel[word],T.en.wheel[word])
        end
        o.log(('wheel: open on %s (%s)'):format(EW.pages(T.en,none)[last].title,device=='pad' and 'pad' or 'F'..key))
    end
    return self
end
return EW
