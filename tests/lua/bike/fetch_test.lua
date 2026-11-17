-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- bike/fetch.lua over fakes (EVE, the player controller with its remove request and nightop.probe as
-- cut/mailbox_test.lua fakes them; the real nightop.shop reads her GUID): the price and its timings; a start asks the
-- native part for her betacrystal count; one payment at a time; too little money refuses with her count and removes
-- nothing; an answer to an earlier ask never counts; the remove's five arguments; paid once the count fell by the
-- price; paused time not counted toward SETTLE; failed when it does not fall or when no answer comes.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
FName=function(text) return {ToString=function() return text end} end
local removes={}
local pc={ServerRequest_ItemBucketItemRemove=function(_,...) removes[#removes+1]=table.pack(...) end}
local eve={BroadcastSpawnInfo={ActorGuid=0x51}}
package.loaded['nightop.probe']={her=function() return eve end,controller=function() return pc end}
local Fetch=require('bike.fetch')
local asked,engine,paused={},'engine=on reason=pinned me=81',false
-- items=<the last ask's id> <n> on the engine line.
local function answer(n)
    engine='engine=on reason=pinned me=81 items='..asked[#asked]:match('^items (%d+) ')..' '..n..' x=1'
end
local logs={}
local F=Fetch.new({log=function(m) logs[#logs+1]=m end,
    ask=function(line) asked[#asked+1]=line; return true,'asked the native part: '..line end,
    status=function() return 'mod=v\n'..engine..'\n' end,name=function() return {index=77,number=0} end,
    paused=function() return paused end})

assert(Fetch.PRICE==500 and Fetch.ALIAS=='BetaCrystal' and Fetch.SETTLE==10 and Fetch.WINDOW==5)
assert(Fetch.READ==5 and Fetch.POLL==0.5)
assert(F.start(0) and asked[1]:match('^items %d+ BetaCrystal 77 0$') and F.busy())
assert(select(1,F.start(0.1))==false,'One payment at a time')
answer(499); local r,have=F.step(0.5); assert(r=='poor' and have==499 and #removes==0 and not F.busy())
assert(F.step(0.6)==nil,'Nothing runs')
answer(500); assert(F.start(1) and F.step(1.5)==nil,'An old answer never counts for a new ask')
answer(500); assert(F.step(1.6)==nil)
assert(#removes==1 and removes[1][1]==1 and removes[1][2]==0x51 and removes[1][3]:ToString()=='BetaCrystal'
    and removes[1][4]==500 and removes[1][5]==-1)
assert(logs[#logs]=='remove asked: BetaCrystal x500 of 500 (guid 81)',logs[#logs])
answer(0); assert(F.step(2.2)=='paid' and not F.busy())
assert(F.start(3)); answer(800); F.step(3.5)
answer(800); paused=true; F.step(20); assert(F.busy(),'Paused time does not count')
paused=false; answer(800); F.step(20.1); answer(800); local r2,why=F.step(30.2)
assert(r2=='failed' and why:find('did not fall by 500 in 10 s of play'),tostring(why))
assert(F.start(40) and F.step(40+Fetch.READ+0.1)=='failed','No answer from the native part')
-- A count the native part cannot read; no name for BetaCrystal; an ask the native part does not take.
assert(F.start(50)); engine='engine=on items='..asked[#asked]:match('^items (%d+) ')..' none nobucket x=1'
local r3,why3=F.step(50.5); assert(r3=='failed' and why3:find('nobucket',1,true) and #removes==2)
local G=Fetch.new({log=function() end,ask=function() return false,'the native part is off' end,
    status=function() return '' end,name=function() return nil end,paused=function() return false end})
local ok,e=G.start(0); assert(not ok and e=='BetaCrystal has no FName' and not G.busy())
G=Fetch.new({log=function() end,ask=function() return false,'the native part is off' end,
    status=function() return '' end,name=function() return {index=1,number=0} end,paused=function() return false end})
ok,e=G.start(0); assert(not ok and e:find('the native part is off',1,true) and not G.busy())
print('fetch_test ok')
