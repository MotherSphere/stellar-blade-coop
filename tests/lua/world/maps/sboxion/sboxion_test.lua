-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop xion (world/maps/sboxion/commands.lua): alone and with city it asks the warp to the city point, with gate to
-- the gate point; leave and status go to their own calls; recover goes to its call alone or with on, death or off;
-- rooms goes to its call alone or with on or off; tetrapod goes to its call alone or with in or out; walls, the word of the walls taken out on 24 November 2026, another
-- word or one too many is refused with the use line; without the Steam link every word says so. The wiring
-- (world/maps/sboxion/wiring.lua) builds SBO Xion with three of the Steam link's stores. coop-xion-rooms.txt is the
-- file the rooms keep their hidden rows in. coop-xion-doors.txt is the file of the threshold doors a player opened.
-- coop-xion-npcs.txt is the file of the NPC bodies' actor paths. It asks for no store without the link. An NPC's
-- line is said in the menu's words.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Commands=require('world.maps.sboxion.commands')
local calls={}
local Cmd=Commands.new({xion={enter=function(name) calls[#calls+1]='enter '..name; return true,'in' end,
    leave=function() calls[#calls+1]='leave'; return true,'out' end,
    status=function() calls[#calls+1]='status'; return true,'line' end,
    recover=function(word) calls[#calls+1]='recover '..tostring(word); return true,'mode' end,
    rooms=function(word) calls[#calls+1]='rooms '..tostring(word); return true,'doors' end,
    tetrapod=function(word) calls[#calls+1]='tetrapod '..tostring(word); return true,'ship' end,
    npc=function(what,value) calls[#calls+1]='npc '..tostring(what)..' '..tostring(value); return true,'body' end}})
local USE='Use: coop xion [city|gate|leave|status|recover [on|death|off]|rooms [on|off]|tetrapod [in|out]'
    ..'|npc [<n>|turn <degrees>]]'
local ok,line=Cmd.xion()
assert(ok and line=='in' and calls[1]=='enter city',line)
ok,line=Cmd.xion('city')
assert(ok and calls[2]=='enter city')
ok,line=Cmd.xion('gate')
assert(ok and calls[3]=='enter gate')
ok,line=Cmd.xion('leave')
assert(ok and line=='out' and calls[4]=='leave')
ok,line=Cmd.xion('status')
assert(ok and line=='line' and calls[5]=='status')
ok,line=Cmd.xion('nope')
assert(not ok and line==USE and #calls==5,line)
ok,line=Cmd.xion('gate','now')
assert(not ok and line==USE and #calls==5,line)
ok,line=Cmd.xion('recover')
assert(ok and line=='mode' and calls[6]=='recover nil',calls[6])
for i,word in ipairs({'on','death','off'}) do
    ok,line=Cmd.xion('recover',word)
    assert(ok and line=='mode' and calls[6+i]=='recover '..word,calls[6+i])
end
ok,line=Cmd.xion('recover','up')
assert(not ok and line==USE and #calls==9,line)
ok,line=Cmd.xion('recover','on','now')
assert(not ok and line==USE and #calls==9,line)
-- The walls are gone: their word, alone or with on or off, is refused like any other word.
for _,words in ipairs({{'walls'},{'walls','on'},{'walls','off'},{'recover','off','now'}}) do
    ok,line=Cmd.xion(table.unpack(words))
    assert(not ok and line==USE and #calls==9,line)
end
ok,line=Cmd.xion('rooms')
assert(ok and line=='doors' and calls[10]=='rooms nil',calls[10])
for i,word in ipairs({'on','off'}) do
    ok,line=Cmd.xion('rooms',word)
    assert(ok and line=='doors' and calls[10+i]=='rooms '..word,calls[10+i])
end
for _,words in ipairs({{'rooms','death'},{'rooms','off','now'},{'rooms','D011'}}) do
    ok,line=Cmd.xion(table.unpack(words))
    assert(not ok and line==USE and #calls==12,line)
end
ok,line=Cmd.xion('tetrapod')
assert(ok and line=='ship' and calls[13]=='tetrapod nil',calls[13])
for i,word in ipairs({'in','out'}) do
    ok,line=Cmd.xion('tetrapod',word)
    assert(ok and line=='ship' and calls[13+i]=='tetrapod '..word,calls[13+i])
end
for _,words in ipairs({{'tetrapod','on'},{'tetrapod','in','now'},{'in'}}) do
    ok,line=Cmd.xion(table.unpack(words))
    assert(not ok and line==USE and #calls==15,line)
end
-- coop xion npc hands its two words to the module, which checks them.
for i,words in ipairs({{},{'3'},{'turn','90'},{'turn'}}) do
    ok,line=Cmd.xion('npc',words[1],words[2])
    assert(ok and line=='body' and calls[15+i]=='npc '..tostring(words[1])..' '..tostring(words[2]),calls[15+i])
end
ok,line=Commands.new({}).xion('status')
assert(not ok and line=='coop xion needs the Steam link and the native part',line)
ok,line=Commands.new({}).xion('npc')
assert(not ok and line=='coop xion needs the Steam link and the native part',line)
-- wiring: SBO Xion is built with the rooms' store and the doors' store alone and the commands reach it.
package.loaded.UEHelpers={}
local built,names,stores=nil,{},{}
package.loaded['world.maps.sboxion.sboxion']={new=function(o)
    built=o
    return {status=function() return true,'wired' end}
end}
package.loaded['world.maps.sboxion.engine']={}
local told={}
local M={print=function() end,folder='C:/SB/Mods/StellarCoop',coop_slot=function() return true end,
    photo_state=function() end,ask=function() return function() return true end end,
    tell=function(build) told[#told+1]=build(require('ui.text').fr) end,
    link={status=function() return '' end,mode=function() return 'none' end,
        store=function(name) names[#names+1]=name; stores[name]={}; return stores[name] end}}
local Wiring=require('world.maps.sboxion.wiring')
local wired=Wiring.new(M)
assert(#names==3 and built.rooms_store==stores['coop-xion-rooms.txt'] and built.rooms_store
    and built.doors_store==stores['coop-xion-doors.txt'] and built.doors_store
    and built.npcs_store==stores['coop-xion-npcs.txt'] and built.npcs_store and built.store==nil,
    'The rooms\' store, the doors\' store and the NPCs\' store: '..table.concat(names,' '))
-- An NPC's line is built from the menu's words: its name, then what it says.
built.say('repairer')
assert(#told==1 and told[1]:find('^Réparateur : Si ça bourdonne') ,told[1])
ok,line=wired.xion('status')
assert(ok and line=='wired' and M.sboxion,'The commands reach the module the wiring built')
M.link=nil
wired=Wiring.new(M)
assert(not M.sboxion and #names==3,'No store is asked without the Steam link')
ok,line=wired.xion('status')
assert(not ok and line=='coop xion needs the Steam link and the native part',line)
print('sboxion_test ok')
