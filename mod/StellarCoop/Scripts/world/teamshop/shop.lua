-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The team shop: SB's own shop screen on the ShopTable row SBOTeam_Shop, which sells the team's items for gold
-- (BetaCrystal). Its rows are world/teamshop/rows.lua, the native part's teamshop batch
-- (world/teamshop/teamshop_rows.h: one ItemTable row per item, its ShopItemTable row <alias>_Buy, then the ShopTable
-- row). They are asked at the title on the co-op save files only (core/enemy.lua's title_batch, from main/pass.lua's
-- 250 ms loop), once a game run. The native part adds them on the game thread. Every patched field is then read back
-- through FindRow. coop teamshop (open) asks the native part's teamshop open (world/teamshop/shop_ui.h), which opens
-- the screen at the game thread's next frame; tick() waits for the teamshopui answer and logs it. SB does the rest: its
-- BuyItem takes the gold and adds the item to EVE's inventory, then the player equips the suit in SB's own menu. A suit
-- EVE holds is not sold again: SB's screen checks its count against MaxAmount 1 before BuyItem runs. Never called here:
-- an item grant, a bucket call, a save. open() refuses on your own saves, while the rows are not in, after they were
-- refused, faulted or read back other than written (said once a Lua load), with a native part older than the shop or
-- after its fault, while the game is paused and while an open waits for its answer.
local Enemy=require('core.enemy')
local R=require('world.teamshop.rows')
local Shop={}
Shop.WAIT=5 -- s: how long an open waits for the native part's answer.
Shop.ROWS=Enemy.rows(R.ROWS)
-- rows/rows.h's refusals of a gate that stayed shut (busy, net, unread): the title asks again, so nothing is decided.
local SHUT={busy=true,net=true,unread=true}
-- coop-status.txt's teamshopui line (world/teamshop/shop_ui.h's status_line) as fields: state (off, opened, refused,
-- fault), asks (a number), why (a refusal's word), where (a fault's), line; nil without one.
function Shop.line(status)
    local line=('\n'..(status or '')):match('\nteamshopui=([^\r\n]*)')
    if not line then return nil end
    return {state=line:match('^(%a+)'),asks=tonumber(line:match(' asks=(%d+)')) or 0,why=line:match(' why=(%S+)'),
        where=line:match(' where=(.*)$'),line='teamshopui='..line}
end

-- o: log, status() the native status text, ask(line) its request (ok, message), paused() whether the game is paused
-- or shows one of its screens (photo modes included).
function Shop.new(o)
    local log,status,ask,paused=o.log,o.status,o.ask,o.paused
    local e=Enemy.new({log=log,ask=ask,status=status},
        {word='teamshop',name='team shop',command='coop teamshop',tag='[TS]',rows=Shop.ROWS,ids={}})
    local asking=false -- The title's ask under way: the teamshop line may read rows before the read-back.
    local verdict,refusal=nil,nil -- true: the rows in; false: refused, refusal says why (said once); nil: undecided.
    local opening=nil -- The open under way: the teamshopui line's asks before it and when it was asked.
    local function refused(why)
        if verdict~=false then log('rows refused ('..why..'): the team shop stays shut') end
        verdict,refusal=false,why
    end
    -- The teamshop line's word: the rows in (this Lua load's read-back, or an earlier load's), or a refusal that stays.
    local function from_line()
        local s=Enemy.parse(status(),'teamshop')
        if not s then return end
        if s.state=='rows' then verdict=true
        elseif s.state=='fault' or s.state=='refused' and not SHUT[s.why] then refused(s.line) end
    end
    local title,title_stop=e.title_batch(function()
        asking=true
        return 'the co-op save files'
    end,'the next visit of the title',function(fine)
        asking=false
        if fine then verdict=true return end
        local s=Enemy.parse(status(),'teamshop')
        if s and s.state=='rows' then refused('they read back other than written') else from_line() end
    end)
    local self={}
    -- title(at_title, coop): at each 250 ms pass while the title shows (main/pass.lua).
    self.title=title
    -- Each 250 ms pass: the title's wait and read-back, then the open's answer.
    function self.tick()
        e.tick()
        if not opening then return end
        local s=Shop.line(status())
        if s and s.asks>opening.asks then
            opening=nil
            if s.state=='opened' then return log("opened: SB's shop screen on "..R.SHOP) end
            return log('open refused ('..(s.why or s.line)..')')
        end
        if os.clock()-opening.at>Shop.WAIT then
            opening=nil
            log(string.format('no answer from the native part in %d s (%s)',Shop.WAIT,
                s and s.line or 'no teamshopui line'))
        end
    end
    -- coop teamshop: ok, message.
    function self.open()
        if not ('\n'..(status() or '')):find('\nslot=coop index=') then
            return false,'the team shop opens on a co-op save only (INSTALL.md: Co-op saves)'
        end
        if verdict==nil and not asking then from_line() end
        if verdict==false then return false,'the team shop rows were refused this game run ('..refusal..')' end
        if verdict~=true then
            return false,"the team shop's rows are not in: they go in at the title before a co-op save loads"
        end
        local s=Shop.line(status())
        if not s then
            return false,'coop-status.txt has no teamshopui line: the native part is older than the team shop'
        end
        if s.state=='fault' then
            return false,'the team shop screen stopped on a fault this game run ('..tostring(s.where)..')'
        end
        if paused() then return false,'the game is paused or shows one of its screens: open the shop once it plays' end
        if opening then return false,'the team shop screen is already opening' end
        local asked,said=ask('teamshop open')
        if not asked then return false,'teamshop open not asked: '..tostring(said) end
        opening={asks=s.asks,at=os.clock()}
        log('open asked ('..s.line..'): its answer is the next asks= past '..s.asks)
        return true,"team shop: SB's shop screen opens at the game thread's next frame ([TS] lines)"
    end
    -- coop off: the title's wait and the open's wait ended (rows already in stay for the game run).
    function self.stop()
        title_stop()
        e.stop()
        asking,opening=false,nil
    end
    return self
end
return Shop
