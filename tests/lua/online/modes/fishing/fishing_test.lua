-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop fish (online/modes/fishing/commands.lua): alone and with status it answers the tournament's state line; start
-- starts one on the host or says why not in words; stop cancels it on the host only; another word is refused with the
-- use line; without the link it says so.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local session,members={id='1001'},{{id='2002',linked=true,lost=false,name='P2'}}
local sent={}
local link={saves=function() return {steamid='1001'} end,host=function() return session end,
    match=function() end,members=function() return members end,member=function() end,me=function() return 'P1' end,
    chatting=function() return true end,status=function() return '' end,
    take_mode=function() return {} end,mode_line=function(_,text) sent[#sent+1]=text; return true end}
local fish=nil
local round=require('online.modes.fishing.round').new({link=link,clock=function() return 100 end,
    fish=function() if fish then return nil,fish end return {[9220]=138} end})
local Cmd=require('online.modes.fishing.commands').new({round=round})
local USE='Use: coop fish [status | start [<minutes>] | stop]'
local ok,line=Cmd.fish()
assert(ok and line=='fishing: no tournament yet',line)
ok,line=Cmd.fish('status')
assert(ok and line=='fishing: no tournament yet',line)
for _,words in ipairs({{'nope'},{'status','x'},{'stop','1'},{'start','1','2'},{'start','0'},{'start','61'}}) do
    ok,line=Cmd.fish(table.unpack(words))
    assert(not ok and line==USE,table.concat(words,' '))
end
ok,line=Cmd.fish('stop')
assert(not ok and line=='No fishing tournament is on.',line)
for why,words in pairs({off='Fishing tournament is off in Options.',slot='Load a co-op save to fish in the tournament.',
        table='Could not read the fish table.'}) do
    fish=why
    ok,line=Cmd.fish('start')
    assert(not ok and line==words,line)
end
fish=nil
members[1].linked=false
ok,line=Cmd.fish('start')
assert(not ok and line=='Nobody else is in the online session yet.',line)
members[1].linked=true
session={id='2002'}
ok,line=Cmd.fish('start')
assert(not ok and line=='Only the host starts a fishing tournament.',line)
session=nil
ok,line=Cmd.fish('start')
assert(not ok and line=='A fishing tournament runs in an online session.',line)
session={id='1001'}
assert(#sent==0)
ok,line=Cmd.fish('start','2')
assert(ok and line:find('^fishing: tournament %d+, 2 minutes, play, starts in 5$')
    and sent[1]:find('^go %d+ 2 1001,2002$'),line)
ok,line=Cmd.fish('start')
assert(not ok and line=='A fishing tournament is already on.',line)
ok,line=Cmd.fish('stop')
assert(ok and line=='fishing: the tournament was cancelled' and sent[2]:find('^void %d+$'),line)
-- A guest's stop: refused, nothing sent after her ready.
session={id='2002'}
local guest=require('online.modes.fishing.round').new({link=link,clock=function() return 100 end,
    fish=function() return {[9220]=138} end})
link.take_mode=function() return {{from='2002',text='go 5 10 2002,1001'}} end
guest.tick()
link.take_mode=function() return {} end
ok,line=require('online.modes.fishing.commands').new({round=guest}).fish('stop')
assert(not ok and line=='Only the host stops a fishing tournament.' and #sent==3 and sent[3]=='ready 5',line)
ok,line=require('online.modes.fishing.commands').new({}).fish()
assert(not ok and line=='A fishing tournament needs the Steam link.',line)
print('fishing_test ok')
