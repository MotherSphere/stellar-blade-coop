-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The shop's item grant and EVE's GUID, moved out of online/modes/nightop/shop.lua for every module to read.
local U=require('core.unreal')
local Shop={}
local MASK=0xFFFFFFFF
Shop.MOST=10 -- Items in one buy.
-- The one grant call: an item alias, EVE's GUID and 1 to MOST items, into the inventory, with the game's pickup
-- message; no stat level, no enhance message, not an event load, no saved instance. Shop.grant and coop gift
-- (tools/mailbox.lua) call it, each after checking the alias against its own list.
function Shop.add(pc,guid,alias,count)
    assert(type(alias)=='string' and alias:match('^[%w_]+$'),'not an alias')
    assert(math.type(count)=='integer' and count>=1 and count<=Shop.MOST,'not a count')
    assert(math.type(guid)=='integer' and guid>0 and guid<=MASK,'not a GUID')
    pc:ServerRequest_ItemBucketItemAdd(1,guid,FName(alias),count,0,true,false,false,{})
end
-- EVE's GUID for the item requests, or nil when every read gives 0: her spawn info's; the player state's when that
-- holds none (read 0 in game, 2026-10-26); the native part's, its engine line's me=, when that reads 0 too (read 0 in
-- game as well). status: the native part's status text.
function Shop.guid(eve,pc,status)
    local guid=math.tointeger(eve.BroadcastSpawnInfo.ActorGuid)
    guid=guid and guid&MASK
    if not guid or guid==0 then
        local ok,g=pcall(function() return math.tointeger(U.valid(pc.PlayerState).ActorNetGuid) end)
        guid=ok and g and g&MASK or guid
    end
    if not guid or guid==0 then
        local me=('\n'..tostring(status or '')):match('\nengine=[^\r\n]* me=(%d+)')
        guid=me and math.tointeger(tonumber(me)) or guid
    end
    if guid and guid~=0 then return guid end
end
return Shop
