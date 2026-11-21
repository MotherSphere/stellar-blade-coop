-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- online/partner/commands.lua's coop look over a fake ghost: each of the six looks (cloth, dyes, effects, drone, sounds,
-- faces) changes in the table the ghost holds and builds the ghost again; any other word gets the usage with nothing
-- changed; no argument prints the looks with the help that names the six.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Partner=require('online.partner.commands')
local look={cloth=true,dyes=true,effects=true,drone=true,sounds=true,faces=true}
local rebuilds={}
local puppet={toggle=function() end,basesuit=function() end,where=function() end,near=function() end,
    cns=function() end,active=function() return true end,rebuild=function(why) rebuilds[#rebuilds+1]=why end}
local p=Partner.new({puppet=puppet,look=look,looks=function() return 'look: ...' end,
    ask=function() return function() return true end end})
local function run(args)
    local feature,state=(args or ''):match('^(%S*)%s*(%S*)$')
    if feature=='' then feature=nil end
    if state=='' then state=nil end
    return p.look(feature,state)
end

assert(select(2,run('drone off')):find('^Drone off until the mod reloads'))
assert(look.drone==false and #rebuilds==1 and rebuilds[1]=='look')
assert(select(2,run('sounds off')):find('^Sounds off until the mod reloads') and look.sounds==false)
assert(select(2,run('faces on')):find('^Faces on until the mod reloads') and look.faces==true and #rebuilds==3)
local ok,usage=run('wings off')
assert(ok==false and usage=='Use: coop look [cloth|dyes|effects|drone|sounds|faces on|off]' and look.wings==nil
    and #rebuilds==3)
ok,usage=run('drone maybe')
assert(ok==false and usage:find('^Use: coop look') and look.drone==false and #rebuilds==3)
assert(select(2,run()):find('coop look <cloth|dyes|effects|drone|sounds|faces> <on|off>',1,true),'the help names them')
-- The three older looks change the same way.
for _,name in ipairs({'cloth','dyes','effects'}) do
    local word=name:sub(1,1):upper()..name:sub(2)
    assert(select(2,run(name..' off')):find('^'..word..' off until the mod reloads') and look[name]==false,name)
end
assert(#rebuilds==6 and rebuilds[6]=='look')
print('online.partner_commands_test ok')
