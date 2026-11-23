-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion (a test tool, experimental, left out of the usage line): a world of SBO's own whose persistent level
-- /Game/SBO_World/Xion_P streams the look-only sublevels of SB's Xion from the player's own game files. The level is
-- in the zSBO_Xion test pak, built outside the mod and never shipped with it. SB's world row Xion, its zones and its
-- level-design sublevels are not touched: story mode and online sessions keep SB's Xion.
-- The pak gate (core/pak_gate.lua), once a Lua load: the container's .utoc must name SBO_World and Xion_P.umap, with
-- its .pak and .ucas beside it. With no pak nothing is asked and nothing is said: most players have none.
-- The rows (native/src/world/maps/sboxion/sboxion_rows.h's sboxion batch, world/maps/sboxion/data.lua): one world row
-- and one type-5 zone row, asked at the title while the game uses the co-op save files (core/enemy.lua's title_batch,
-- from main/pass.lua), then read back. A refusal is logged once a Lua load.
local Enemy=require('core.enemy')
local PakGate=require('core.pak_gate')
local D=require('world.maps.sboxion.data')
local Xion={}
Xion.ROWS=Enemy.rows(D.ROWS)
-- rows/rows.h's refusals of a gate that stayed shut (busy, net, unread): the title asks again, so nothing is decided.
local SHUT={busy=true,net=true,unread=true}

-- o: log(m), status() the native status text, ask(line) its request (ok, why), paks (SB/Content/Paks, or nil) and
-- read (core/link.lua's files.read) for the pak gate.
function Xion.new(o)
    local log=o.log
    local e=Enemy.new({log=function(m) log('sboxion '..m) end,ask=o.ask,status=o.status},
        {word='sboxion',name='SBO Xion',command='coop xion',tag='[SX]',rows=Xion.ROWS,ids={}})
    local pak,pak_why=nil,nil -- The test pak's version (false: none, with why), looked for once a Lua load.
    local verdict=nil -- true: the rows in and read back; false: refused (said); nil: nothing decided yet.
    local self={}
    -- The test pak's version, or nil and why there is none.
    function self.gate()
        if pak==nil then
            pak,pak_why=PakGate.find(o.paks,o.read,D.PAK,{D.UMAP})
            pak=pak or false
        end
        return pak or nil,pak_why
    end
    local function refused(why)
        if verdict~=false then log('sboxion rows: refused ('..why..'): coop xion stays off') end
        verdict=false
    end
    -- How an ask of the batch ended: the rows in and read back, or a refusal that stays (a shut gate decides nothing).
    local function decided(fine)
        if fine then
            if verdict~=true then log('sboxion rows: '..#Xion.ROWS..'/'..#Xion.ROWS..' in') end
            verdict=true
            return
        end
        local s=Enemy.parse(o.status(),'sboxion')
        if s and s.state=='rows' then refused('they read back other than written')
        elseif s and (s.state=='fault' or s.state=='refused' and not SHUT[s.why]) then refused(s.line) end
    end
    local title,title_stop=e.title_batch(function()
        return self.gate() and 'the co-op save files and test pak '..pak or nil
    end,'coop xion',decided)
    -- title(at_title, coop): at each 250 ms pass while the title shows (main/pass.lua).
    self.title=title
    -- true once the rows are in and read back, false when refused, nil while nothing is decided.
    function self.ok() return verdict end
    -- Each 250 ms pass: the wait for the rows and their read-back.
    function self.tick() return e.tick() end
    -- coop off: the title's wait ended. Rows already in stay for the game run.
    function self.stop()
        title_stop()
        e.stop()
    end
    return self
end
return Xion
