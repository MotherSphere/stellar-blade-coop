-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- online/lobby/commands.lua over a fake link, with no session handler: coop match join <row> joins that row's lobby and
-- a row the list lacks is refused with nothing asked; a lobby id and a join code join as coop join does. coop match
-- leave asks leave. coop match join alone is refused.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Lobby=require('online.lobby.commands')
local Link=require('core.link')
local asked={}
local rows={{lobby='900'},{lobby='901'}} -- What link.list() says.
local link={request=function(line) asked[#asked+1]=line; return true,'asked the native part: '..line end,
    list=function() return {tab='public',state='done'},rows end,valid_lobby=Link.new('C:\\Mod',{}).valid_lobby,
    join_code=Link.join_code}
local l=Lobby.new({link=link,settings=Link.parse_settings(''),
    ask=function(line) return function() return link.request(line) end end})

assert(l.match('join','2') and asked[#asked]=='join 901' and l.match('join','01') and asked[#asked]=='join 900')
for _,bad in ipairs({'3','0','99'}) do
    local ok,why=l.match('join',bad)
    assert(not ok and why=='the session list has no row '..bad..': coop list shows it' and #asked==2,bad)
end
assert(l.match('join','109775241234567890') and asked[#asked]=='join 109775241234567890')
assert(l.match('join','0cs-cbmh') and asked[#asked]=='join 0CS-CBMH')
assert(l.match('leave') and asked[#asked]=='leave' and #asked==5)
local ok,why=l.match('join')
assert(not ok and why=='Use: coop match search|create <mode> | cancel | end | join <code> | leave' and #asked==5,why)
print('lobby_commands_test ok')
