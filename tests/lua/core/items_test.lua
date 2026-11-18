-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- core/items.lua: the grant call with its checks; EVE's GUID from her spawn info (0x51 as bike/fetch_test.lua and
-- cut/menus/mailbox_test.lua give it), 10 items a buy at most.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
FName=function(text) return {ToString=function() return text end} end
local Shop=require('core.items')
assert(Shop.MOST==10)
assert(Shop.guid({BroadcastSpawnInfo={ActorGuid=0x51}},nil,nil)==0x51)
local calls={}
local pc={ServerRequest_ItemBucketItemAdd=function(_,...) calls[#calls+1]={...} end}
Shop.add(pc,0x51,'PulseGrenade',2)
assert(#calls==1 and calls[1][1]==1 and calls[1][2]==0x51 and calls[1][3]:ToString()=='PulseGrenade' and calls[1][4]==2)
assert(not pcall(Shop.add,pc,0x51,'PulseGrenade',11) and not pcall(Shop.add,pc,0,'PulseGrenade',1) and #calls==1)
print('core/items_test: ok')
