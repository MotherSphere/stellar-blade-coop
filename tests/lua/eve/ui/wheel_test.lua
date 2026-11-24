-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- eve/ui/wheel.lua on a fake kit wheel: 8 pages of 5, 5, 4, 5, 6, 5, 3 and 6 slots holding coop emote's 39 ids once
-- each; the game's word for a slot, a page and the centre where it has one, SBO's else (the Cut clips always); the
-- two waves with their side; a refusal for a busy EVE and each of the kit's, in the player's words with English for
-- the line above EVE; a pick through coop emote's own path, its refusal on screen; the last page used comes back; the
-- guard is EVE's busy.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
package.loaded.UEHelpers={GetPlayer=function() end}
local Emote=require('eve.emote')
local EW=require('eve.ui.wheel')
local T=require('ui.text')

-- The game's words: a few keys answered, in German.
local GAME={UI_PhotoMode_Pose_Salute='Salutieren',UI_PhotoMode_Pose_Hello_Selfie='Hallo',
    UI_Gesture_Category_Greetings='Grüßen',UI_Gesture_Category_Pose='Pose',UI_HUD_Gesture='Aktion (sozial)'}
local asked={}
local function game(key) asked[#asked+1]=key; return GAME[key] end
local pages=EW.pages(T.de,game)
local sizes,ids={},{}
for i,p in ipairs(pages) do
    sizes[i]=#p.slots
    for _,s in ipairs(p.slots) do assert(not ids[s.id],s.id..' twice'); ids[s.id]=s.label end
end
assert(table.concat(sizes,' ')=='5 5 4 5 6 5 3 6',table.concat(sizes,' '))
local n=0
for id in pairs(Emote.POSES) do n=n+1; assert(ids[id],id..': not on the wheel') end
assert(n==39)
assert(pages[1].title=='Grüßen' and pages[5].title=='Pose 1' and pages[6].title=='Pose 2','The game\'s page words')
assert(pages[2].title==T.de.emote.cats.expression and pages[8].title==T.de.emote.cats.cut,'SBO\'s where it has none')
assert(ids.salute=='Salutieren' and ids.wave=='Hallo (links)' and ids.wave2=='Hallo (rechts)')
assert(ids.clap==T.de.emote.names.clap and ids.kaligrab==T.de.emote.names.kaligrab)
for _,key in ipairs(asked) do assert(not key:find('Kali',1,true) and not key:find('Chariot',1,true),key) end
-- Every key asked of the game is one StringTable_UI holds (read in its export): the 31 poses' and the categories'.
local KEYS={}
for k in ('Salute KungFuSalute Toast Hello_Selfie Clap HandHeart ThumbUp Victory Kiss BringItOn GiveMe Hush Reach OMG '
    ..'What Worry Wish WeDidIt Charm Confident Cutie Sweetie SlavSquart Stretch WarmUp Walk ShutterChance1 '
    ..'ShutterChance2 ShutterChance3 Flow Natarajasana Somersault'):gmatch('%S+') do
    KEYS['UI_PhotoMode_Pose_'..k]=true
end
for k in ('Greetings Expression Instruction Emotion Pose Dance'):gmatch('%S+') do KEYS['UI_Gesture_Category_'..k]=true end
for _,key in ipairs(asked) do assert(KEYS[key],key..': not a key of StringTable_UI') end
-- No game word (ui_language=english): SBO's English throughout.
local en=EW.pages(T.en,function() end)
assert(en[1].title=='Greeting' and en[1].slots[4].label=='Wave (left)' and en[8].slots[1].label=='Chariot struggle')

-- The press: on a fake kit wheel.
local opened,said,logs,ran={},{},{},{}
local busy,refuse=nil,nil
local wheel={is_open=function() return opened.spec~=nil end,open=function(spec)
    if refuse then return false,refuse[1],refuse[2] end
    opened.spec=spec
    return true
end}
local ew=EW.new({wheel=function() return wheel end,words=function() return T.fr end,game=function() end,
    busy=function() return busy end,run=function(name,id) ran[#ran+1]=name..' '..id; return id~='kaligrab','refused' end,
    log=function(m) logs[#logs+1]=m end,say=function(text,english) said[#said+1]={text,english} end})
ew.press('key',2)
local spec=opened.spec
assert(spec.device=='key' and spec.key==2 and spec.page==1 and #spec.pages==8 and spec.title==T.fr.wheel.title)
assert(spec.pages[1].title==T.fr.emote.cats.greetings and logs[#logs]=='wheel: open on Greeting (F2)')
assert(spec.guard()==nil)
busy='EVE is in combat'
assert(spec.guard()=='EVE is in combat','The guard is EVE\'s busy')
-- Closed with a pick on page 6: coop emote's own path; the next open on that page.
busy=nil
opened.spec=nil
spec.closed('release','shutter2',6)
assert(ran[1]=='emote shutter2' and logs[#logs]=='wheel: emote shutter2 (release)' and #said==0)
ew.press('pad')
assert(opened.spec.page==6 and opened.spec.device=='pad' and logs[#logs]=='wheel: open on Pose 2 (pad)')
-- A refused pick goes on screen as the console gives it.
opened.spec.closed('select','kaligrab',8)
assert(said[#said][1]=='refused')
-- Closed with nothing: logged only.
opened.spec.closed('cancelled',nil,8)
assert(logs[#logs]=='wheel: closed (cancelled)' and #ran==2)
-- Open already: nothing.
local n_logs=#logs
ew.press('key',2)
assert(#logs==n_logs)
-- EVE busy: not opened, said in the player's words with English for the line above EVE.
opened.spec=nil
busy='EVE is in the air'
ew.press('key',2)
assert(opened.spec==nil and logs[#logs]=='wheel: not opened: EVE is in the air'
    and said[#said][1]==T.fr.wheel.busy and said[#said][2]==T.en.wheel.busy)
-- A guard that raises reads as busy.
local boom=EW.new({wheel=function() return wheel end,words=function() return T.en end,game=function() end,
    busy=function() error('no EVE object',0) end,run=function() end,log=function(m) logs[#logs+1]=m end,
    say=function(text,english) said[#said+1]={text,english} end})
boom.press('key',2)
assert(opened.spec==nil and logs[#logs]=='wheel: not opened: EVE unreadable: no EVE object')
-- The kit's refusals: its word.
busy=nil
for _,r in ipairs({{'world','one of our screens holds the input'},{'native','no coop_stick'},{'off','the UI stopped'}}) do
    refuse=r
    ew.press('key',2)
    assert(logs[#logs]=='wheel: not opened: '..r[2] and said[#said][1]==T.fr.wheel[r[1]]
        and said[#said][2]==T.en.wheel[r[1]],r[1])
end
-- No kit wheel (no Steam link): nothing.
n_logs=#logs
EW.new({wheel=function() end,words=function() return T.en end,game=function() end,busy=function() end,
    run=function() end,log=function(m) logs[#logs+1]=m end,say=function() end}).press('key',2)
assert(#logs==n_logs)
print('eve_wheel_test ok')
