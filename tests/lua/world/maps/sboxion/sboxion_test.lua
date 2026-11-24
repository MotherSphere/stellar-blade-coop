-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop xion (world/maps/sboxion/commands.lua): alone and with city it asks the warp to the city point, with gate to
-- the gate point; leave and status go to their own calls; recover goes to its call alone or with on, death or off;
-- walls and rooms each go to their call alone or with on or off; another word or one too many is refused with the use
-- line; without the Steam link every word says so. The wiring (world/maps/sboxion/wiring.lua) builds SBO Xion with
-- two of the Steam link's stores, coop-xion-walls.txt, the file the walls keep their paths in, and
-- coop-xion-rooms.txt, the file the rooms keep their hidden rows in, and asks for no store without the link.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Commands=require('world.maps.sboxion.commands')
local calls={}
local Cmd=Commands.new({xion={enter=function(name) calls[#calls+1]='enter '..name; return true,'in' end,
    leave=function() calls[#calls+1]='leave'; return true,'out' end,
    status=function() calls[#calls+1]='status'; return true,'line' end,
    recover=function(word) calls[#calls+1]='recover '..tostring(word); return true,'mode' end,
    walls=function(word) calls[#calls+1]='walls '..tostring(word); return true,'count' end,
    rooms=function(word) calls[#calls+1]='rooms '..tostring(word); return true,'doors' end}})
local USE='Use: coop xion [city|gate|leave|status|recover [on|death|off]|walls [on|off]|rooms [on|off]]'
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
ok,line=Cmd.xion('walls')
assert(ok and line=='count' and calls[10]=='walls nil',calls[10])
for i,word in ipairs({'on','off'}) do
    ok,line=Cmd.xion('walls',word)
    assert(ok and line=='count' and calls[10+i]=='walls '..word,calls[10+i])
end
for _,words in ipairs({{'walls','death'},{'walls','on','now'},{'recover','off','now'}}) do
    ok,line=Cmd.xion(table.unpack(words))
    assert(not ok and line==USE and #calls==12,line)
end
ok,line=Cmd.xion('rooms')
assert(ok and line=='doors' and calls[13]=='rooms nil',calls[13])
for i,word in ipairs({'on','off'}) do
    ok,line=Cmd.xion('rooms',word)
    assert(ok and line=='doors' and calls[13+i]=='rooms '..word,calls[13+i])
end
for _,words in ipairs({{'rooms','death'},{'rooms','off','now'},{'rooms','D011'}}) do
    ok,line=Cmd.xion(table.unpack(words))
    assert(not ok and line==USE and #calls==15,line)
end
ok,line=Commands.new({}).xion('status')
assert(not ok and line=='coop xion needs the Steam link and the native part',line)
-- wiring: SBO Xion is built with the store of that name and the commands reach it.
package.loaded.UEHelpers={}
local built,names,stores=nil,{},{}
package.loaded['world.maps.sboxion.sboxion']={new=function(o)
    built=o
    return {status=function() return true,'wired' end}
end}
package.loaded['world.maps.sboxion.engine']={}
local M={print=function() end,folder='C:/SB/Mods/StellarCoop',coop_slot=function() return true end,
    photo_state=function() end,ask=function() return function() return true end end,
    link={status=function() return '' end,mode=function() return 'none' end,
        store=function(name) names[#names+1]=name; stores[name]={}; return stores[name] end}}
local Wiring=require('world.maps.sboxion.wiring')
local wired=Wiring.new(M)
assert(#names==2 and built.store==stores['coop-xion-walls.txt'],'The walls\' store: '..table.concat(names,' '))
assert(built.rooms_store==stores['coop-xion-rooms.txt'] and built.rooms_store~=built.store,'The rooms\' own store')
ok,line=wired.xion('status')
assert(ok and line=='wired' and M.sboxion,'The commands reach the module the wiring built')
M.link=nil
wired=Wiring.new(M)
assert(not M.sboxion and #names==2,'No store is asked without the Steam link')
ok,line=wired.xion('status')
assert(not ok and line=='coop xion needs the Steam link and the native part',line)
print('sboxion_test ok')
