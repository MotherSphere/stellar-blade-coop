-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The score attack's two runtime lines through main.lua: the 250 ms loop reads its score lines once a pass and plays
-- its round (a guest who is not in the lobby room sits out the host's go with one [SA] line); coop off ends the round
-- for it. No pass reads its lines after that.
dofile('tests/lua/main/fixture.lua')
local Round=require('online.modes.scoreattack.round')
local new,round=Round.new,nil
Round.new=function(o) round=new(o); return round end -- The round main.lua's loader makes.
load_main(true)
local takes,waiting=0,{}
fake_link.take_score=function()
    takes=takes+1
    local out=waiting
    waiting={}
    return out
end
link_mode,saves_info,link_owner='guest',{steamid='2002'},'1001'
loops[2].f()
assert(takes==1,'Once a pass')
link_round={n=1,kind='start',mode='scoreattack',map='lobby',seed=5,ids={'1001','2002'}}
waiting={{from='1001',text='go 5 targets'}}
loops[2].f()
assert(takes==2)
local found=false
for _,l in ipairs(printed) do found=found or l=='[StellarCoop][SA] sit out: EVE is not in the lobby room\n' end
assert(found,'The go line reached the game side')
assert(round.status()=='pick random; round 1 (targets): play',round.status())
coop('off')
assert(round.status()=='pick random; round 1 (targets): coop off',round.status())
loops[2].f()
assert(takes==2,'No pass after coop off')
io.stdout:write('main scoreattack_test ok\n')
