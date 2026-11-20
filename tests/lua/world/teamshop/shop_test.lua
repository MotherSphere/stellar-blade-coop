-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The team shop (world/teamshop/shop.lua) and coop teamshop (world/teamshop/commands.lua) over fakes: the status text
-- (its slot=, teamshop= and teamshopui= lines as the native part writes them), ItemTable, ShopTable and ShopItemTable
-- with the rows as the native part writes them, the clock, the pause and a request log. Covered:
-- world/teamshop/rows.lua (every row in one of the three tables, the ShopTable row last); on your own save, open()
-- refuses and asks nothing;
-- the title on your own saves asks nothing; on the co-op save files one request with the three tables in the native
-- part's order, then the read-back; open() before the read-back refuses; a refusal, a fault or rows that read back
-- other than written keep the shop shut with the reason (said once), also after a Lua reload; a shut gate's refusal
-- decides nothing; no teamshopui line, its fault, the pause and an open under way refuse; the open's answer is logged
-- (opened, refused, no answer in Shop.WAIT s); coop off drops the waits; the command's argument and link checks.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=100
os.clock=function() return clock end
local next_address=0x90000
local function object(t)
    next_address=next_address+0x100
    local at=next_address
    t.type=t.type or function() return 'UObject' end
    t.IsValid=t.IsValid or function() return true end
    t.GetAddress=t.GetAddress or function() return at end
    return t
end
package.loaded.UEHelpers={}
package.loaded['core.player']={her=function() return nil end} -- At the title: no EVE.
local Shop=require('world.teamshop.shop')
local Commands=require('world.teamshop.commands')
local R=require('world.teamshop.rows')

-- R.ROWS: every table one of the three; the last row is R.SHOP in ShopTable.
local THREE={ItemTable=true,ShopTable=true,ShopItemTable=true}
for _,r in ipairs(R.ROWS) do assert(THREE[r[1]],r[2]..' in '..r[1]) end
assert(R.ROWS[#R.ROWS][1]=='ShopTable' and R.ROWS[#R.ROWS][2]==R.SHOP and R.SHOP=='SBOTeam_Shop')

-- The three tables, each row as the native part writes it.
local function fresh(t)
    local rows={}
    for _,r in ipairs(R.ROWS) do
        if r[1]==t then
            local x={ID=r[3]}
            for _,c in ipairs(r[4]) do
                local v=c[3]
                if c[2]=='N' then
                    v={}
                    for item in c[3]:gmatch('[^|]+') do v[#v+1]=item end
                end
                x[c[1]]=v
            end
            rows[r[2]]=x
        end
    end
    return rows
end
local tables={}
for t in pairs(THREE) do
    tables[t]=object({rows=fresh(t),IsA=function(_,c) return c.path=='/Script/Engine.DataTable' end,
        FindRow=function(self,name) return self.rows[name] end})
end
local classes={}
StaticFindObject=function(path)
    local t=path:match('^/Game/Local/Data/(%a+)%.%a+$')
    if t then return tables[t] end
    if path:find('^/Script/') then
        classes[path]=classes[path] or object({path=path})
        return classes[path]
    end
end
local REQUEST=string.format('teamshop rows ItemTable=0x%x ShopTable=0x%x ShopItemTable=0x%x',
    tables.ItemTable:GetAddress(),tables.ShopTable:GetAddress(),tables.ShopItemTable:GetAddress())
local ROWS_IN='teamshop=rows added=3/3 asks=%d spawns=? char=0/0 skills=0/0 stance=0/0'
local COOP='slot=coop index=1 marker=1 saves=coop'

local logs,asked={},{}
local slot,line,ui,paused=COOP,'teamshop=off','teamshopui=off',false
local function status() return 'mod=v\n'..slot..'\n'..line..'\n'..ui..'\nlast=x\n' end
local function new()
    logs,asked={},{}
    return Shop.new({log=function(m) logs[#logs+1]=m end,status=status,
        ask=function(l) asked[#asked+1]=l; return true,'asked the native part: '..l end,
        paused=function() return paused end})
end
local function logged(text) for _,l in ipairs(logs) do if l:find(text,1,true) then return l end end end
local function count(text) local n=0; for _,l in ipairs(logs) do if l:find(text,1,true) then n=n+1 end end; return n end
local function opens() local n=0; for _,l in ipairs(asked) do if l=='teamshop open' then n=n+1 end end; return n end

-- Own save: no slot=coop line, so open() refuses and asks nothing.
slot='slot=main index=2 marker=none saves=main'
local s=new()
local ok,msg=s.open()
assert(not ok and msg:find('co%-op save only') and #asked==0,msg)
slot='slot=none index=? marker=? saves=?'
ok,msg=s.open()
assert(not ok and msg:find('co%-op save only') and #asked==0,msg)
-- Title on own saves: nothing asked.
for _=1,4 do s.title(true,false) end
assert(#asked==0 and #logs==0,'Not on your own saves')

-- Title on the co-op save files: one request, its three tables only, in the native part's order (kLionTables).
slot=COOP
s=new()
s.title(true,true)
assert(#asked==1 and asked[1]==REQUEST,asked[1])
assert(asked[1]:match('^teamshop rows ItemTable=0x%x+ ShopTable=0x%x+ ShopItemTable=0x%x+$'))
assert(logged('title: the co-op save files: the rows asked before any save loads (try 1 of 4)'),logs[#logs])
s.title(true,true)
assert(#asked==1,'Asked once')
-- The rows in, not read back yet: the shop stays shut.
line=ROWS_IN:format(1)
ok,msg=s.open()
assert(not ok and msg:find('not in',1,true) and opens()==0,msg)
clock=clock+0.5
s.tick()
assert(logged('rows read back through FindRow: 3/3 authored rows'),logs[#logs])
assert(logged('title: the rows are in, before any save loads'),logs[#logs])
clock=clock+20
s.title(true,true)
assert(#asked==1,'Once a game run')

-- Opened: one ask, its answer logged once.
ok,msg=s.open()
assert(ok and asked[2]=='teamshop open',msg)
ok,msg=s.open()
assert(not ok and msg:find('already opening') and opens()==1,msg)
s.tick()
assert(not logged('opened'),'No answer yet')
ui='teamshopui=opened asks=1'
s.tick()
assert(logged("opened: SB's shop screen on SBOTeam_Shop"),logs[#logs])
s.tick()
assert(count('opened:')==1)
-- Refused by the native part (a screen already open): logged with its word.
ok=s.open()
assert(ok and opens()==2)
ui='teamshopui=refused asks=2 why=open'
s.tick()
assert(logged('open refused (open)'),logs[#logs])
-- No answer in Shop.WAIT s.
ok=s.open()
assert(ok and opens()==3)
clock=clock+Shop.WAIT-1
s.tick()
assert(not logged('no answer'))
clock=clock+2
s.tick()
assert(logged('no answer from the native part in 5 s (teamshopui=refused asks=2 why=open)'),logs[#logs])
assert(s.open(),'Free again')
s.stop()

-- A Lua reload with the rows in: open() from the teamshop line, nothing asked of the rows.
s=new()
ok=s.open()
assert(ok and #asked==1 and asked[1]=='teamshop open')
-- coop off: the open's wait dropped, nothing said after.
s.stop()
clock=clock+10
s.tick()
assert(not logged('no answer'))
-- Paused, no teamshopui line, its fault: refused, nothing asked.
s=new()
paused=true
ok,msg=s.open()
assert(not ok and msg:find('paused') and #asked==0,msg)
paused=false
ui=''
ok,msg=s.open()
assert(not ok and msg:find('no teamshopui line',1,true) and #asked==0,msg)
ui='teamshopui=fault asks=2 where=x'
ok,msg=s.open()
assert(not ok and msg:find('(x)',1,true) and #asked==0,msg)
ui='teamshopui=off'

-- Refused rows: the line in the message, said once, also after a reload; no open asked.
line='teamshop=refused added=0/3 asks=1 spawns=? why=id table=ItemTable row=SBOTeam_GothicRose'
s=new()
ok,msg=s.open()
assert(not ok and msg:find(line,1,true) and opens()==0,msg)
ok,msg=s.open()
assert(not ok and count('the team shop stays shut')==1,msg)
-- The title asks again and gets the same refusal: still said once.
s.title(true,true)
assert(asked[1]==REQUEST)
line='teamshop=refused added=0/3 asks=2 spawns=? why=id table=ItemTable row=SBOTeam_GothicRose'
clock=clock+0.5
s.tick()
assert(not s.open() and count('the team shop stays shut')==1,logs[#logs])
-- Rows fault: the message names where.
line='teamshop=fault added=1/3 asks=1 spawns=? where=y'
s=new()
ok,msg=s.open()
assert(not ok and msg:find('where=y',1,true) and opens()==0,msg)
-- A shut gate's refusal: nothing decided, asked again at the title.
line='teamshop=refused added=0/3 asks=1 spawns=? why=busy table=- row=-'
s=new()
ok,msg=s.open()
assert(not ok and msg:find('not in',1,true) and not logged('stays shut'),msg)
-- Read back: the title's batch ends not fine while teamshop=rows.
line='teamshop=off'
s=new()
s.title(true,true)
assert(#asked==1 and asked[1]==REQUEST)
tables.ShopItemTable.rows.SBOTeam_GothicRose_Buy.MoneyItemCount1=50
line=ROWS_IN:format(2)
clock=clock+0.5
s.tick()
ok,msg=s.open()
assert(not ok and msg:find('read back other than written',1,true) and opens()==0,msg)
assert(count('the team shop stays shut')==1,logs[#logs])
tables.ShopItemTable.rows=fresh('ShopItemTable')
-- coop off during the title's wait: nothing asked after.
line='teamshop=off'
s=new()
s.title(true,true)
s.stop()
clock=clock+0.5
s.tick()
assert(#asked==1)

-- coop teamshop: no argument; without the Steam link, a refusal.
ok,msg=Commands.new({}).teamshop()
assert(not ok and msg=='the team shop needs the Steam link and the native part',msg)
ok,msg=Commands.new({shop={open=function() return true,'x' end}}).teamshop('now')
assert(not ok and msg=='Use: coop teamshop',msg)
ok,msg=Commands.new({shop={open=function() return true,'x' end}}).teamshop()
assert(ok and msg=='x')
print('world/teamshop/shop_test: ok')
