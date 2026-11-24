-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop xion (world/maps/sboxion/commands.lua): alone and with city it asks the warp to the city point, with gate to
-- the gate point; leave and status go to their own calls; recover goes to its call alone or with on, death or off;
-- walls goes to its call alone or with on or off; another word or one too many is refused with the use line; without
-- the Steam link every word says so.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Commands=require('world.maps.sboxion.commands')
local calls={}
local Cmd=Commands.new({xion={enter=function(name) calls[#calls+1]='enter '..name; return true,'in' end,
    leave=function() calls[#calls+1]='leave'; return true,'out' end,
    status=function() calls[#calls+1]='status'; return true,'line' end,
    recover=function(word) calls[#calls+1]='recover '..tostring(word); return true,'mode' end,
    walls=function(word) calls[#calls+1]='walls '..tostring(word); return true,'count' end}})
local USE='Use: coop xion [city|gate|leave|status|recover [on|death|off]|walls [on|off]]'
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
ok,line=Commands.new({}).xion('status')
assert(not ok and line=='coop xion needs the Steam link and the native part',line)
print('sboxion_test ok')
