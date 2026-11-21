-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop photohunt (online/modes/photohunt/commands.lua): alone and with status it answers the round's state line; start
-- starts one on the host or says why not in words (each refusal of the design's section 1); stop cancels it on the
-- host only; another word is refused with the use line; without the link it says so.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local session,members,match={id='1001'},{{id='2002',linked=true,lost=false,name='P2'}},nil
local sent={}
local link={saves=function() return {steamid='1001'} end,host=function() return session end,
    match=function() return match end,members=function() return members end,member=function() end,
    me=function() return 'P1' end,chatting=function() return true end,status=function() return '' end,
    take_mode=function() return {} end,mode_line=function(_,text) sent[#sent+1]=text; return true end}
local refused,offered=nil,{'Cat1','Cat2','MemoryOfXion'}
local round=require('online.modes.photohunt.round').new({link=link,clock=function() return 100 end,
    check=function() if refused then return nil,refused end return true end,
    targets=function() if not offered then return nil,'read' end return offered,'Xion' end})
local Cmd=require('online.modes.photohunt.commands').new({round=round})
local USE='Use: coop photohunt [status | start [<minutes>] | stop]'
local ok,line=Cmd.photohunt()
assert(ok and line=='photohunt: no photo hunt yet',line)
ok,line=Cmd.photohunt('status')
assert(ok and line=='photohunt: no photo hunt yet',line)
for _,words in ipairs({{'nope'},{'status','x'},{'stop','1'},{'start','1','2'},{'start','0'},{'start','61'},
        {'start','x'}}) do
    ok,line=Cmd.photohunt(table.unpack(words))
    assert(not ok and line==USE,table.concat(words,' '))
end
ok,line=Cmd.photohunt('stop')
assert(not ok and line=='No photo hunt is on.',line)
for why,words in pairs({off='Photo hunt is off in Options.',slot='Load a co-op save to play the photo hunt.',
        checks='Photo checks are off in this game.'}) do
    refused=why
    ok,line=Cmd.photohunt('start')
    assert(not ok and line==words,line)
end
refused,offered=nil,nil
ok,line=Cmd.photohunt('start')
assert(not ok and line=='Could not read the photo targets.',line)
offered={'Cat1','Cat2'}
ok,line=Cmd.photohunt('start')
assert(not ok and line=='This map has fewer than 3 photo targets. Try Xion, the Wasteland or the Great Desert.',line)
offered={'Cat1','Cat2','MemoryOfXion'}
members[1].linked=false
ok,line=Cmd.photohunt('start')
assert(not ok and line=='Nobody else is in the online session yet.',line)
members[1].linked=true
session={id='2002'}
ok,line=Cmd.photohunt('start')
assert(not ok and line=='Only the host starts a photo hunt.',line)
session=nil
ok,line=Cmd.photohunt('start')
assert(not ok and line=='A photo hunt runs in an online session.',line)
session,match={id='1001'},{state='open'}
ok,line=Cmd.photohunt('start')
assert(not ok and line=='A photo hunt runs in an online session.',line)
match=nil
assert(#sent==0)
ok,line=Cmd.photohunt('start','2')
assert(ok and line:find('^photohunt: round %d+, 2 minutes in Xion, play, starts in 5; board: ')
    and sent[1]:find('^go %d+ 2 Xion [%w_,]+ 1001,2002$'),line)
ok,line=Cmd.photohunt('start')
assert(not ok and line=='A photo hunt is already on.',line)
ok,line=Cmd.photohunt('stop')
assert(ok and line=='photohunt: the photo hunt was cancelled' and sent[2]:find('^void %d+$'),line)
-- 15 minutes without a number.
ok,line=Cmd.photohunt('start')
assert(ok and sent[3]:find('^go %d+ 15 Xion '),sent[3])
-- A guest's stop: refused, nothing sent after her ready.
session={id='2002'}
local guest=require('online.modes.photohunt.round').new({link=link,clock=function() return 100 end,
    check=function() return true end})
link.take_mode=function() return {{from='2002',text='go 5 10 Xion Cat1,Cat2,MemoryOfXion 2002,1001'}} end
guest.tick()
link.take_mode=function() return {} end
ok,line=require('online.modes.photohunt.commands').new({round=guest}).photohunt('stop')
assert(not ok and line=='Only the host stops a photo hunt.' and #sent==4 and sent[4]=='ready 5',line)
ok,line=require('online.modes.photohunt.commands').new({}).photohunt()
assert(not ok and line=='A photo hunt needs the Steam link.',line)
print('photohunt_test ok')
