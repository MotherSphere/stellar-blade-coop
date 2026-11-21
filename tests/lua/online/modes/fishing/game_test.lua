-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The game side of a fishing tournament (online/modes/fishing/game.lua) on a fake round, status, clock and world: the
-- fish table read from SB's two tables by row name (a missing row, a bad value, a shared ID refused) and fish()'s sit
-- outs (fishing=off, off a co-op save, a table that cannot be read, read once a Lua load); the engine line's book
-- answers; the asks once a second from GO, never with the number the engine line shows, again after a lost answer, one
-- last ask at our end, then none; a catch before GO; the baseline taken again after a map change, a loading screen, a
-- slot change and each none answer but unread, which keeps it, the answer of an ask sent before the event dropped; no
-- ask while the world is not loaded; a fall or a missing fish counting nothing; a jump of 3; a fish not in the table
-- logged once and never sent; coop off, a round replaced and a round that ended.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local G=require('online.modes.fishing.game')
local rows=require('online.modes.fishing.rows')

-- G.rows on two fake DataTables: each row's ID and points by its name.
local function tables(skip,bad,twice)
    local items,fish={},{}
    for k,name in ipairs(rows) do
        if name~=skip then
            items[name]={ID=(twice==name and 9201) or 9200+k}
            fish[name]={RewardItemCount=bad==name and 'x' or k*10}
        end
    end
    local function dt(t) return {FindRow=function(_,name) return t[name] end} end
    local by={['/Game/Local/Data/ItemTable.ItemTable']=dt(items),
        ['/Game/Local/Data/ItemFishTable.ItemFishTable']=dt(fish)}
    return function(path) return assert(by[path],path) end
end
local plain=function(v) return v end
local t=G.rows(tables(),plain)
local n=0
for id,p in pairs(t) do n=n+1; assert(p==(id-9200)*10) end
assert(n==40)
assert(not pcall(G.rows,tables('Fish_Tuna'),plain),'A missing row raises')
assert(not pcall(G.rows,tables(nil,'Fish_Tuna'),plain),'A value that is no number raises')
assert(not pcall(G.rows,tables(nil,nil,'Fish_Tuna'),plain),'Two rows of one ID raise')

-- The engine line's book answers.
local b=G.book('9201:3,9220:1')
assert(b[9201]==3 and b[9220]==1)
assert(next(G.book('-'))==nil)
for _,bad in ipairs({'','9201','9201:','9201:3,','9201:3,9201:4','x:1','9201:-1','9201:3;9220:1'}) do
    assert(G.book(bad)==nil,bad)
end

local POINTS={[9201]=30,[9220]=138,[9228]=0}
local now,cur,caught,logged,asked=0,nil,{},{},{}
local status='engine=v1 me=81 pad=xinput\nslot=coop 2\n'
local on,coop,map,rows_read=true,true,'/game/art/bg/worldmap/level_p/e04',0
local read_rows=function() rows_read=rows_read+1; return POINTS end
local round={round=function() return cur end,catch=function(item,points) caught[#caught+1]=item..' '..points end}
local g=G.new({round=round,status=function() return status end,
    request=function(line) asked[#asked+1]=line; return true end,clock=function() return now end,
    log=function(m) logged[#logged+1]=m end,on=function() return on end,coop=function() return coop end,
    world=function() return map end,rows=function() return read_rows() end})
local function ask() return asked[#asked] and math.tointeger(tonumber(asked[#asked]:match('^fishbook (%d+)$'))) end
-- The worker's answer to our last ask in the engine line, before pad= as the native part writes it.
local function answer(text) status='engine=v1 me=81 fish='..ask()..' '..text..' pad=xinput\nslot=coop 2\n' end
local function said(m) for _,l in ipairs(logged) do if l==m then return true end end end

-- fish(): our table, or why we sit out. The table is read once a Lua load, a failed read tried again at the next go.
on=false
assert(select(2,g.fish())=='off' and rows_read==0)
on,coop=true,false
assert(select(2,g.fish())=='slot' and rows_read==0)
coop=true
read_rows=function() rows_read=rows_read+1; error('ItemTable is unavailable',0) end
local p,why=g.fish()
assert(p==nil and why=='table' and rows_read==1)
assert(said('fish table not read: ItemTable is unavailable'),logged[#logged])
read_rows=function() rows_read=rows_read+1; return POINTS end
assert(g.fish()==POINTS and g.fish()==POINTS and rows_read==2,'Read once, then kept')

-- A tournament of 1 minute, go at 100: GO at 105, our end at 165.
-- Each start ticks once in the countdown, as the 250 ms passes do: the map she fishes on is known at GO.
local function start()
    cur={seed=7,minutes=1,go=100,phase='play'}
    asked,caught,logged={},{},{}
    g.start(cur)
    now=100
    g.tick()
end
start()
assert(#asked==0,'No ask during the countdown: a catch before GO does not count')
now=105
g.tick()
assert(#asked==1 and ask(),'The first ask at GO')
local first=ask()
g.tick()
assert(#asked==1,'Once a second')
answer('9201:2') -- The baseline: two goldfish caught before GO count nothing.
g.tick()
assert(#caught==0 and #asked==1)
now=106
g.tick()
assert(#asked==2 and ask()~=first)
answer('9201:2,9220:1')
g.tick()
assert(#caught==1 and caught[1]=='9220 138','A new fish counts its count')
now=107; g.tick(); answer('9201:3,9220:1'); g.tick()
assert(#caught==2 and caught[2]=='9201 30','A count that rose by 1')
now=108; g.tick(); answer('9201:3,9220:1,9228:2'); g.tick()
assert(#caught==4 and caught[3]=='9228 0' and caught[4]=='9228 0','A trash fish: 0 points, still catches')
-- unread keeps the baseline: the next answer still counts against it.
now=109; g.tick(); answer('none unread'); g.tick()
now=110; g.tick(); answer('9201:4,9220:1,9228:2'); g.tick()
assert(#caught==5 and caught[5]=='9201 30','unread kept the baseline')
-- Each none but unread takes the baseline again: the next answer counts nothing.
for _,none in ipairs({'noeve','nobook','off','unpinned'}) do
    local before=#caught
    now=now+1; g.tick(); answer('none '..none); g.tick()
    now=now+1; g.tick(); answer('9201:9,9220:1,9228:2'); g.tick()
    assert(#caught==before,none..': the answer after it is the baseline')
    now=now+1; g.tick(); answer('9201:10,9220:1,9228:2'); g.tick()
    assert(#caught==before+1,none..': then catches count again')
end
-- A fall counts nothing, logs once and the next answer is the baseline; so does a fish that went missing.
local before=#caught
now=now+1; g.tick(); answer('9201:1,9220:1,9228:2'); g.tick()
assert(#caught==before and said('book fell: baseline again'))
now=now+1; g.tick(); answer('9201:2,9220:2,9228:2'); g.tick()
assert(#caught==before,'The answer after the fall is the baseline')
now=now+1; g.tick(); answer('9201:2,9228:2'); g.tick()
now=now+1; g.tick(); answer('9201:2,9220:3,9228:2'); g.tick()
assert(#caught==before,'A missing fish: nothing, then the baseline')
-- A jump of 3: nothing, one log line, the next answer the baseline.
now=now+1; g.tick(); answer('9201:5,9220:3,9228:2'); g.tick()
assert(#caught==before and said('book jumped by 3: baseline again'))
now=now+1; g.tick(); answer('9201:6,9220:3,9228:2'); g.tick()
assert(#caught==before,'The answer after the jump is the baseline')
-- A fish not in the table: logged once, never sent.
now=now+1; g.tick(); answer('9201:6,9220:3,9228:2,9999:1'); g.tick()
now=now+1; g.tick(); answer('9201:6,9220:3,9228:2,9999:2'); g.tick()
local odd=0
for _,l in ipairs(logged) do if l=='book fish 9999 is not in the fish table: not sent' then odd=odd+1 end end
assert(#caught==before and odd==1,'Logged once')
-- A text that is no book: a torn answer, the baseline kept.
now=now+1; g.tick(); answer('9201:6,9220'); g.tick()
now=now+1; g.tick(); answer('9201:7,9220:3,9228:2,9999:2'); g.tick()
assert(#caught==before+1)

-- The events that may rebuild the book: a map change, a loading screen (no map), the slot verdict leaving coop. Each
-- takes the baseline again; the answer of an ask sent before it is dropped; no ask goes in its pass.
local goldfish=7 -- 9201's count in the baseline the torn answer left.
local function event(what,set,back)
    local base=#caught
    local function book(n) goldfish=goldfish+n; answer('9201:'..goldfish..',9220:3,9228:2,9999:2') end
    now=now+1; g.tick()
    local n_asked=#asked
    set()
    book(1) -- The answer of the ask before the event, one more goldfish than the baseline: dropped.
    now=now+1; g.tick() -- An ask is due by the clock.
    assert(#asked==n_asked,what..': no ask in its pass')
    back()
    g.tick() -- The world back: one more pass for its map to settle when it changed.
    now=now+1; g.tick(); book(1); g.tick()
    assert(#caught==base,what..': the first answer after it is the baseline')
    now=now+1; g.tick(); book(1); g.tick()
    assert(#caught==base+1,what..': then catches count')
end
event('map change',function() map='/game/art/bg/worldmap/level_p/f02' end,function() end)
event('loading screen',function() map=nil end,function() map='/game/art/bg/worldmap/level_p/f02' end)
event('slot change',function() coop=false end,function() coop=true end)
-- A loading screen of several passes: no ask in any of them.
local k_load=#asked
map=nil
for _=1,4 do now=now+1; g.tick() end
assert(#asked==k_load,'No ask while the world is not loaded')
map='/game/art/bg/worldmap/level_p/f02'
assert(now<165)

-- An answer that does not come: asked again after G.LOST seconds, with a new number.
local k=#asked
repeat now=now+1; g.tick() until #asked>k or now>=160 -- The next ask.
local lost,n_asked=ask(),#asked
now=now+G.LOST-1; g.tick()
assert(#asked==n_asked,'Waits for it')
now=now+1; g.tick()
assert(#asked==n_asked+1 and ask()~=lost,'Asked again')
-- The number the engine line shows is never asked again: an earlier Lua load's answer could pass for ours.
local g2=G.new({round=round,status=function() return 'engine=v1 fish=1 9201:9 pad=xinput\n' end,
    request=function(line) asked[#asked+1]=line; return true end,clock=function() return now end,log=function() end,
    on=function() return true end,coop=function() return true end,world=function() return map end,
    rows=function() return POINTS end})
for _=1,70000 do
    local k=#asked
    g2.start(cur)
    g2.tick() -- The map is new to this run: no ask in this pass.
    g2.tick()
    assert(#asked==k+1 and ask()~=1)
end

-- Our end: one last ask after the last answer, then none.
start()
now=164; g.tick(); answer('9201:1'); g.tick()
now=165; g.tick()
local last,n=ask(),#asked
assert(n==2 and last,'The last ask at our end')
answer('9201:2'); g.tick()
assert(#caught==1 and caught[1]=='9201 30','The last answer counts')
now=170; g.tick()
assert(#asked==n,'Nothing after it')
-- An end with no baseline left (a loading screen at the end): no last ask.
start()
now=164; g.tick(); answer('9201:1'); g.tick()
map=nil
now=165; g.tick()
map='/game/art/bg/worldmap/level_p/f02'
now=166; g.tick()
assert(#asked==1,'No last ask: nothing to count it against')

-- coop off (the round's stop), a round replaced, a round that ended: no more asks.
for _,case in ipairs({'stop','replaced','ended'}) do
    start()
    now=106; g.tick(); answer('9201:1'); g.tick() -- The baseline: the next ask is due a second later.
    local k=#asked
    if case=='stop' then g.stop('coop off')
    elseif case=='replaced' then cur={seed=8,minutes=1,go=100,phase='play'}
    else cur.phase='over' end
    now=107; g.tick()
    now=108; g.tick()
    assert(#asked==k,case)
end
print('game_test ok')
