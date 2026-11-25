-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's rounds (fight/gunmode/nikke.lua) over fakes: the status text (its nikke= and engine= lines as the native
-- part writes them), the link's request, the pause, the FName lookup, EVE's controller and pawn and the clock. Covered:
-- fight/gunmode/rows.lua says what native/src/fight/gunmode/nikke_rows.h writes (every row's table, name and ID, every
-- patch's field, kind and value, the round and its price); Nikke.answer reads its own ask's count or refusal and no
-- other ask's; the rows verdict from the nikke= line (a shut gate decides nothing, a refusal is said once); ready()
-- only once a tick read the rows and a slot=coop line, false again after a tick on your own save (slot=main, its count
-- then nil); an unread status, slot=none and slot=unknown keep the verdict, the count and the takes; another co-op
-- save's slot index reads the count again; the count's read only while watched, its ask number in 20000..32767
-- (wrapped from 32767 to 20000) and never the one the engine line shows; take() asks SB's remove with EVE's GUID,
-- lowers the count until a read shows the take or SETTLE s of play pass (paused time not counted), the second logged
-- once. It refuses while paused, before the rows are in and for a count that is no whole number above 0. An unread
-- inventory is logged once.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=100
os.clock=function() return clock end
package.loaded.UEHelpers={}
package.loaded['core.player']={her=function() return nil end}
FName=function(text) return {ToString=function() return text end} end
local Enemy=require('core.enemy')
local R=require('fight.gunmode.rows')
local Nikke=require('fight.gunmode.nikke')

-- The header as text, its line ends cut.
local function read(path)
    local f=assert(io.open(path,'rb'))
    local s=f:read('a'):gsub('\r','')
    f:close()
    return s
end
local H=read('native/src/fight/gunmode/nikke_rows.h')
local round=assert(H:match('constexpr char kNikkeRound%[%] = "([^"]+)";'))
local price=assert(math.tointeger(tonumber(H:match('constexpr int kNikkePrice = (%d+);'))))
assert(R.ROUND==round and R.ROUND=='Bullet_Nikke',R.ROUND)
assert(R.PRICE==price,'R.PRICE '..tostring(R.PRICE)..' against kNikkePrice '..price)
assert(Nikke.ROUND==R.ROUND)

-- The fields by offset, from the header's comment of offsets read in Ghidra ("its ItemAlias 0x145e0f998 (+0x28)").
local FIELD={}
for name,off in H:gmatch('([%a_][%w_]*) 0x%x+ %(%+(0x%x+)%)') do
    assert(not FIELD[off] or FIELD[off]==name,'offset '..off..' named twice')
    FIELD[off]=name
end
-- The Table enum of rows/rows.h, in the order of core/enemy.lua's Enemy.TABLES (both kLionTables' order).
local RH=read('native/src/rows/rows.h')
local TABLE,n={},0
for word in assert(RH:match('enum class Table : uint8_t {(.-)};')):gmatch('(%a+)') do
    n=n+1
    TABLE[word]=assert(Enemy.TABLES[n],'Table::'..word..' has no Enemy.TABLES entry')
end
assert(n==#Enemy.TABLES,'Table has '..n..' tables, Enemy.TABLES '..#Enemy.TABLES)
assert(TABLE.reward=='RewardGroupTable' and TABLE.shopitem=='ShopItemTable' and TABLE.shop=='ShopTable')

-- kNikkePatches: {offset, kind, value, comment}, a value resolved from the header's constants.
local KIND={name='n',i32='i',f32='f',names='N'}
local function value(kind,num,text)
    if kind=='name' or kind=='names' then
        if text=='kNikkeRound' then return round end
        return assert(text:match('^"(.*)"$'),'not a name: '..text)
    end
    if num=='kNikkePrice' or num=='float(kNikkePrice)' then return price end
    return assert(tonumber(num),'not a number: '..num)
end
local patches,open={},nil
for line in assert(H:match('kNikkePatches%[%] = {\n(.-)\n};')):gmatch('[^\n]+') do
    local off,kind,num,rest,comment=line:match('^%s*{(0x%x+), Kind::(%a+%d*), ([^,]+), (.-)},%s*//%s*(.-)%s*$')
    if off then
        patches[#patches+1]={off=off,kind=kind,value=value(kind,num,rest),comment=comment}
    elseif line:match('^%s*{0x') then
        off,kind,num=line:match('^%s*{(0x%x+), Kind::(%a+%d*), ([^,]+),%s*$')
        open=assert(off and {off=off,kind=kind,num=num,text=''},'unread patch: '..line)
    elseif open then
        open.text=open.text..assert(line:match('^%s*"([^"]*)"'),'unread patch line: '..line)
        if line:match('}') then
            patches[#patches+1]={off=open.off,kind=open.kind,value=value(open.kind,open.num,'"'..open.text..'"')}
            open=nil
        end
    else assert(line:match('^%s*//'),'unread line: '..line) end
end
assert(#patches==39,#patches..' patches')
-- A trailing comment names the field at that offset.
for i,p in ipairs(patches) do
    assert(FIELD[p.off],'patch '..i..': no field at '..p.off)
    if p.comment then assert(p.comment:match('^'..FIELD[p.off]),'patch '..i..': '..p.comment..' at '..p.off) end
end

-- kNikkeRecipe against R.ROWS, row by row and value by value.
local recipe={}
for t,name,id,first,count in assert(H:match('kNikkeRecipe%[%] = {\n(.-)\n};'))
        :gmatch('{Table::(%a+), "([^"]+)", "[^"]+", (%d+)u, (%d+), (%d+)}') do
    recipe[#recipe+1]={table=assert(TABLE[t],t),name=name,id=tonumber(id),first=tonumber(first),count=tonumber(count)}
end
assert(#recipe==12,#recipe..' recipe rows')
assert(#R.ROWS==#recipe,'R.ROWS has '..#R.ROWS..' rows, kNikkeRecipe '..#recipe)
local used=0
for i,w in ipairs(recipe) do
    local r=R.ROWS[i]
    local at='row '..i..' ('..w.name..')'
    assert(r[1]==w.table and r[2]==w.name and r[3]==w.id,
        at..': '..tostring(r[1])..' '..tostring(r[2])..' '..tostring(r[3]))
    assert(#r[4]==w.count,at..': '..#r[4]..' checks against '..w.count..' patches')
    assert(w.first==used,at..': patches from '..w.first..', not '..used)
    for j,c in ipairs(r[4]) do
        local p=patches[w.first+j]
        local where=at..' check '..j..' ('..tostring(c[1])..')'
        assert(c[1]==FIELD[p.off],where..': the header writes '..FIELD[p.off])
        assert(c[2]==KIND[p.kind],where..': kind '..tostring(c[2])..' against Kind::'..p.kind)
        assert(c[3]==p.value,where..': '..tostring(c[3])..' against '..tostring(p.value))
        assert(c[4]==true,where..': not marked changed')
    end
    used=used+w.count
end
assert(used==#patches,'the recipe uses '..used..' of '..#patches..' patches')
assert(#Nikke.ROWS==#R.ROWS and Nikke.ROWS[1].table=='RewardGroupTable')

-- Nikke.answer: its own ask's count or refusal word, nothing for another ask or without an engine line.
local function line(engine) return 'mod=v\nslot=coop index=1\nengine='..engine..'\nlast=x\n' end
assert(Nikke.answer(line('fps=60 items=50007 12 me=0'),50007)==12)
assert(math.type(Nikke.answer(line('fps=60 items=50007 12 me=0'),50007))=='integer')
local got,why=Nikke.answer(line('fps=60 items=50007 none unread me=0'),50007)
assert(got==nil and why=='unread',tostring(why))
got,why=Nikke.answer(line('fps=60 items=3 12 me=0'),50007)
assert(got==nil and why==nil,'another ask')
got,why=Nikke.answer(line('fps=60 items=500071 12 me=0'),50007)
assert(got==nil and why==nil,'a longer number is another ask')
got,why=Nikke.answer('mod=v\n',50007)
assert(got==nil and why==nil,'no engine line')
assert(Nikke.answer(nil,50007)==nil)

-- The fakes: the status text, the requests, the pause, the FName lookup, EVE.
local logs,asked,requests,removes={},{},{},{}
local nikke,engine,paused='nikke=off asks=0','fps=60 items=20001 3 me=0',false
local COOP='slot=coop index=1 marker=1 saves=coop'
local slot=nil -- The native part's slot line, or nil while it writes none.
local unread=false -- The status file not read this pass (link.status() gives nil).
local function status()
    if unread then return nil end
    return 'mod=v\n'..(slot and slot..'\n' or '')..nikke..'\nengine='..engine..'\nlast=x\n'
end
local pc={ServerRequest_ItemBucketItemRemove=function(_,...) removes[#removes+1]={...} end}
local pawn={BroadcastSpawnInfo={ActorGuid=0x51}}
local function new()
    logs,asked,requests,removes={},{},{},{}
    return Nikke.new({log=function(m) logs[#logs+1]=m end,status=status,
        ask=function(l) asked[#asked+1]=l; return true,'asked' end,
        request=function(l) requests[#requests+1]=l; return true end,
        paused=function() return paused end,
        name=function(alias) return alias=='Bullet_Nikke' and {index=5,number=0} or nil end,
        pc=function() return pc end,pawn=function() return pawn end,clock=function() return clock end})
end
local function count(text) local k=0; for _,l in ipairs(logs) do if l:find(text,1,true) then k=k+1 end end; return k end
local function step(dt) clock=clock+(dt or 0.25) end
-- The last request's ask number, checked against the format and the range.
local function last_ask()
    local l=requests[#requests]
    local a=math.tointeger(tonumber(l:match('^items (%d+) Bullet_Nikke 5 0$')))
    assert(a and a>=20000 and a<=32767,l)
    return a
end
local ROWS='nikke=rows added=12/12 asks=1 spawns=? char=0/0 skills=0/0 stance=0/0'

-- Before the rows: not ready, no read, no take.
local s=new()
s.watch(true)
s.tick()
assert(not s.ready() and #requests==0,'No read before the rows')
local ok,msg=s.take(3)
assert(not ok and msg=='the rows are not in' and #removes==0,msg)
-- A shut gate's refusal decides nothing.
nikke='nikke=refused asks=1 why=busy'
s.tick()
assert(not s.ready() and #requests==0 and count('refused')==0)
-- The rows in without a slot=coop line: not ready, no read.
nikke=ROWS
step(); s.tick()
assert(not s.ready() and #requests==0,'Not ready without a co-op save')
-- The co-op save loaded: ready once a tick read the slot line (ready() reads no file).
slot=COOP
assert(not s.ready(),'ready() reads no file')
step(); s.tick()
assert(s.ready(),'Ready after a tick on the co-op save')
-- The read starts, its ask skips the number the engine line shows (20001, another ask's answer).
assert(#requests==1,'One read')
local a=last_ask()
assert(a~=20001 and a==20002,'ask '..a..': not the one the engine line shows')
assert(s.count()==nil,'No count before an answer')
step(); s.tick()
assert(#requests==1,'One read under way at a time')
-- Another ask's answer is no count.
engine='fps=60 items=3 9 me=0'
step(); s.tick()
assert(s.count()==nil)
engine='fps=60 items='..a..' 12 me=0'
step(); s.tick()
assert(s.count()==12,tostring(s.count()))
-- Unwatched: no more reads.
s.watch(false)
step(5); s.tick()
assert(#requests==1,'No read while unwatched')
s.watch(true)
s.tick()
assert(#requests==2 and last_ask()~=a,'Read again at once once watched')
a=last_ask()
engine='fps=60 items='..a..' 12 me=0'
step(); s.tick()
assert(s.count()==12)

-- take(n): SB's own remove, bucket 1, EVE's GUID, the round, n, no pocket; the count lower at once.
ok,msg=s.take(4)
assert(ok,msg)
assert(#removes==1)
local rm=removes[1]
assert(rm[1]==1 and rm[2]==0x51 and rm[3]:ToString()=='Bullet_Nikke' and rm[4]==4 and rm[5]==-1,'remove arguments')
assert(s.count()==8,tostring(s.count()))
-- A read that does not show the take yet keeps it out.
step(0.3); s.tick()
a=last_ask()
assert(#requests==3,'The take is read again within 0.3 s')
engine='fps=60 items='..a..' 12 me=0'
step(); s.tick()
assert(s.count()==8,'The take stays out until a read shows it: '..tostring(s.count()))
-- A read that shows it: the take is no longer counted twice.
step(1); s.tick()
a=last_ask()
engine='fps=60 items='..a..' 8 me=0'
step(); s.tick()
assert(s.count()==8,tostring(s.count()))
step(1); s.tick()
a=last_ask()
engine='fps=60 items='..a..' 8 me=0'
step(); s.tick()
assert(s.count()==8,'Counted once: '..tostring(s.count()))

-- Refusals: paused, not a count, all without a remove.
paused=true
ok,msg=s.take(2)
assert(not ok and msg=='the game is paused' and #removes==1,msg)
paused=false
for _,bad in ipairs({1.5,0,-2,'3'}) do
    ok,msg=s.take(bad)
    assert(not ok and msg=='not a count' and #removes==1,tostring(bad)..': '..tostring(msg))
end

-- An unread inventory: logged once while it stays.
for _=1,3 do
    step(1); s.tick()
    a=last_ask()
    engine='fps=60 items='..a..' none unread me=0'
    step(); s.tick()
end
assert(count('rounds: inventory not read (unread)')==1,count('inventory not read')..' logs')
assert(s.count()==8,'The last count kept')

-- A pending take while paused: its SETTLE age does not grow. One poll: a read answered with n, 1.25 s.
local function answer(n)
    step(1); s.tick()
    local k=last_ask()
    engine='fps=60 items='..k..' '..n..' me=0'
    step(); s.tick()
end
ok,msg=s.take(2)
assert(ok,msg)
assert(s.count()==6)
paused=true
for _=1,12 do answer(8) end -- 15 s paused, the reads not showing the take.
assert(s.count()==6,'A paused take does not expire: '..tostring(s.count()))
paused=false
for _=1,4 do answer(8) end -- 5 s of play.
assert(s.count()==6,'Still out before SETTLE s of play: '..tostring(s.count()))
for _=1,5 do answer(8) end -- 11.25 s of play.
assert(s.count()==8,'Expired after SETTLE s of play: '..tostring(s.count()))
assert(count('rounds: 2 taken but the count did not fall in 10 s')==1,count('did not fall')..' logs')
-- A take a read shows: no such line.
ok,msg=s.take(1)
assert(ok,msg)
answer(7)
assert(s.count()==7 and count('did not fall')==1,tostring(s.count()))
answer(7)

-- An unread status, a load or the title (slot=none, unknown): the verdict, the count and the takes hold.
ok,msg=s.take(1)
assert(ok,msg)
assert(s.count()==6)
for _,state in ipairs({'unread','slot=none index=? marker=? saves=coop','slot=unknown index=? marker=? saves=?'}) do
    if state=='unread' then unread=true else slot=state end
    step(); s.tick()
    assert(s.ready() and s.count()==6,state..': '..tostring(s.ready())..' '..tostring(s.count()))
    unread,slot=false,COOP
end
step(); s.tick()
assert(s.ready() and s.count()==6)
-- Another co-op save (another slot index): its count is read again.
slot='slot=coop index=3 marker=1 saves=coop'
step(); s.tick()
assert(s.ready() and s.count()==nil,'Another co-op save: '..tostring(s.count()))
slot=COOP
answer(7)
answer(7)
-- The same slot index from the other files (the manual co-op slot, then the co-op save files): read again each time.
slot='slot=coop index=1 marker=1 saves=main'
step(); s.tick()
assert(s.ready() and s.count()==nil,'The manual co-op slot: '..tostring(s.count()))
slot=COOP
answer(7)
assert(s.count()==7)
slot='slot=coop index=1 marker=1 saves=main'
step(); s.tick()
slot=COOP
step(); s.tick()
assert(s.count()==nil,'Back on the co-op save files: '..tostring(s.count()))
answer(7)

-- Another save loaded: not ready, no count, no take, until a tick reads the co-op save again.
slot='slot=main index=2 marker=1 saves=main'
step(); s.tick()
assert(not s.ready() and s.count()==nil,'Not ready on your own save: '..tostring(s.count()))
ok,msg=s.take(1)
assert(not ok and msg=='the rows are not in',msg)
local before=#requests
step(2); s.tick()
assert(#requests==before,'No read on your own save')
slot=COOP
step(); s.tick()
assert(s.ready() and s.count()==nil,'Ready again, the count read again')

-- coop off: no more reads.
s.stop()
step(5); s.tick()
before=#requests
step(5); s.tick()
assert(#requests==before,'No read after coop off')

-- A refusal that is no shut gate: said once, never ready.
nikke='nikke=refused asks=1 why=dup'
s=new()
s.watch(true)
s.tick(); step(); s.tick()
assert(not s.ready() and #requests==0)
assert(count('rounds: rows refused (nikke=refused asks=1 why=dup)')==1,logs[1])

-- Ask numbers: 20000..32767, wrapped from 32767 to 20000, never the one the engine line shows. Each tick drops the
-- unanswered read (2 s) and asks again.
nikke,slot,engine=ROWS,COOP,'fps=60 items=3 9 me=0'
s=new()
s.watch(true)
step(); s.tick()
assert(s.ready())
local prev=last_ask()
assert(prev==Nikke.ASKS+1,tostring(prev))
local wraps=0
for _=1,2*(Nikke.LAST_ASK-Nikke.ASKS+1)+2 do
    -- At the second wrap the engine line shows 20000: the ask skips it.
    if prev==Nikke.LAST_ASK and wraps==1 then engine='fps=60 items=20000 9 me=0' end
    step(2.5); s.tick()
    a=last_ask()
    if prev==Nikke.LAST_ASK then
        wraps=wraps+1
        assert(a==(wraps==1 and 20000 or 20001),'wrap '..wraps..': '..prev..' then '..a)
        if wraps==2 then break end
    else assert(a==prev+1,prev..' then '..a) end
    prev=a
end
assert(wraps==2,wraps..' wraps')

-- The rows asked only once a co-op save has loaded from the co-op save files (slot=coop with saves=coop), after which
-- the native part refuses `coop saves main` for the game run: never at the title, never on the manual co-op slot
-- (slot=coop with saves=main, one of your own files), never on your own save.
local finds=0
StaticFindObject=function()
    finds=finds+1
    return {type=function() return 'UObject' end,IsValid=function() return true end,IsA=function() return true end,
        GetAddress=function() return 0x1000*finds end}
end
nikke='nikke=off asks=0'
s=new()
for _,l in ipairs({'slot=none index=? marker=? saves=coop','slot=coop index=1 marker=1 saves=main',
        'slot=main index=1 marker=? saves=main','slot=unknown index=? marker=? saves=?'}) do
    slot=l
    step(); s.tick()
    step(); s.tick()
    assert(#asked==0 and finds==0,l..': '..tostring(asked[1]))
end
slot=COOP
step(); s.tick()
assert(#asked==1 and asked[1]:find('^nikke rows ShopTable=0x%x+ ShopItemTable=0x%x+ RewardGroupTable=0x%x+$'),
    tostring(asked[1]))
assert(count('rounds: a co-op save loaded: the rows asked (try 1 of 4)')==1)
-- A shut gate decides nothing: asked again Nikke.RETRY s later, at most Nikke.TRIES times a load.
nikke='nikke=refused asks=1 why=busy'
step(); s.tick()
assert(not s.ready() and #asked==1)
step(Nikke.RETRY-1); s.tick()
assert(#asked==1,'Not before Nikke.RETRY s')
step(1); s.tick()
assert(#asked==2,#asked..' asks')
for k=3,Nikke.TRIES do
    nikke='nikke=refused asks='..(k-1)..' why=busy'
    step(); s.tick()
    step(Nikke.RETRY); s.tick()
    assert(#asked==k,#asked..' asks, '..k..' wanted')
end
nikke='nikke=refused asks='..Nikke.TRIES..' why=busy'
step(); s.tick()
step(Nikke.RETRY*3); s.tick()
assert(#asked==Nikke.TRIES,'At most Nikke.TRIES asks a load: '..#asked)
-- The next load of a co-op save asks again; a refusal that is no shut gate ends it for the run.
slot='slot=none index=? marker=? saves=coop'
step(); s.tick()
slot=COOP
step(); s.tick()
assert(#asked==Nikke.TRIES+1,#asked..' asks')
nikke='nikke=refused asks='..(Nikke.TRIES+1)..' why=id'
step(); s.tick()
assert(not s.ready() and count('rounds: rows refused (nikke=refused asks=5 why=id)')==1)
slot='slot=none index=? marker=? saves=coop'
step(); s.tick()
slot=COOP
step(Nikke.RETRY); s.tick()
assert(#asked==Nikke.TRIES+1,'No ask after a refusal: '..#asked)
StaticFindObject=nil

print('fight/gunmode/nikke_test: ok')
