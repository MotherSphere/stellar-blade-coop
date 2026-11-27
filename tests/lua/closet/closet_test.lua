-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop closet (closet/commands.lua): alone and with status it answers the dress's status line; another word is
-- refused with the use line. thumbs [redo] [<fit>] runs closet/thumbs.lua's run. The wear, off and fits words are
-- checked in dress_test, the colour words in colour_test, the shape words in shape_test.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
package.loaded.UEHelpers={GetPlayer=function() return nil end}
local runs={}
local scans=0
local Cmd=require('closet.commands').new({dress={status=function() return 'closet: nothing worn' end},
    fits=require('closet.fits'),thumbs={run=function(redo,fit) runs[#runs+1]={redo,fit}; return true,'ran' end},
    packs={scan=function() scans=scans+1; return {},{packs=2,reused=1,items=3,failed={}} end}})
local USE='Use: coop closet [status|wear <fit>[:<Slot>,...] ...|off|fits|menu|thumbs [redo] [<fit>]|'..
    'probe <1-6|off>|body <auto|shoes|first|<fit>>|skin <fit> <slot> on|off|colour <role> <swatch|off>|colour off|'..
    'shape <morph> <0-100>|shape off|rescan|option <fit> variant <n>|option <fit> toggle <slot> on|off|'..
    'preset save [name]|preset wear|delete <n>|preset rename <n> [name]|favourite <fit>]'
-- rescan reads every installed pack again (closet/packs.lua) and answers its report line.
local ok,line=Cmd.closet('rescan')
assert(ok and line=='closet packs: 2 packs (1 reused), 3 outfits, 0 failed',line)
ok,line=Cmd.closet('rescan','extra')
assert(not ok and line==USE,line)
assert(scans==1,scans)
ok,line=Cmd.closet()
assert(ok and line=='closet: nothing worn',line)
ok,line=Cmd.closet('status')
assert(ok and line=='closet: nothing worn',line)
ok,line=Cmd.closet('nope')
assert(not ok and line==USE,line)
ok,line=Cmd.closet('status','extra')
assert(not ok,line)
-- thumbs, thumbs redo, thumbs <fit>, thumbs redo <fit>; a third word is refused.
for _,words in ipairs({{},{'redo'},{'AiK_CH27_14595'},{'redo','AiK_CH27_14595'}}) do
    ok,line=Cmd.closet('thumbs',table.unpack(words))
    assert(ok and line=='ran',line)
end
assert(#runs==4,#runs)
assert(runs[1][1]==false and runs[1][2]==nil,'thumbs')
assert(runs[2][1]==true and runs[2][2]==nil,'thumbs redo')
assert(runs[3][1]==false and runs[3][2]=='AiK_CH27_14595','thumbs <fit>')
assert(runs[4][1]==true and runs[4][2]=='AiK_CH27_14595','thumbs redo <fit>')
ok,line=Cmd.closet('thumbs','AiK_CH27_14595','extra')
assert(not ok and line==USE,line)
ok,line=Cmd.closet('thumbs','redo','AiK_CH27_14595','extra')
assert(not ok and line==USE,line)
assert(#runs==4,'no run from a refused line')
print('closet_test ok')
