-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop scoreattack (online/modes/scoreattack/commands.lua): alone and with status it answers the round's state line;
-- pick sets the host's pick by word; another word is refused with the use line; without the link it says so.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local link={saves=function() return {} end,round=function() end,mode=function() end,take_score=function() return {} end}
local round=require('online.modes.scoreattack.round').new({link=link,clock=function() return 0 end})
local Cmd=require('online.modes.scoreattack.commands').new({round=round})
local USE='Use: coop scoreattack [status | pick random|swarm|skulls|gauntlet|targets|range|1-5]'
local ok,line=Cmd.scoreattack()
assert(ok and line=='score attack: pick random; no round yet',line)
ok,line=Cmd.scoreattack('status')
assert(ok and line=='score attack: pick random; no round yet',line)
ok,line=Cmd.scoreattack('pick','2')
assert(ok and line=='score attack: next challenge skulls',line)
ok,line=Cmd.scoreattack('pick','range')
assert(ok and line=='score attack: next challenge range' and round.pick()=='range',line)
ok,line=Cmd.scoreattack('pick','random')
assert(ok and line=='score attack: next challenge random',line)
for _,words in ipairs({{'nope'},{'pick'},{'pick','6'},{'pick','race'},{'status','x'},{'pick','1','2'}}) do
    ok,line=Cmd.scoreattack(table.unpack(words))
    assert(not ok and line==USE,table.concat(words,' '))
end
assert(round.pick()=='random','A refused pick changes nothing')
ok,line=require('online.modes.scoreattack.commands').new({}).scoreattack()
assert(not ok and line=='Score attack needs the Steam link.',line)
print('scoreattack_test ok')
