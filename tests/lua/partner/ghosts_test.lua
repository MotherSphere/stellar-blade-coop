-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- One ghost per remote member of a match lobby, slots 1 to 6: made the first time her slot shows, toggled on once, fed
-- her slot's remote table every 250 ms, ticked and placed each frame, toggled off at coop off. Slot 0 is main.lua's.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local members,remotes,made={},{},{}
local link={members=function() return members end,remote=function(k) return table.unpack(remotes[k] or {}) end,
    slot=function(k) return {k=k} end}
local function make(files,k)
    local g={k=files.k,on=false,calls={}}
    function g.toggle() g.on=not g.on; return true,'toggled' end
    function g.active() return g.on end
    function g.remote(...) g.calls[#g.calls+1]={...} end
    function g.tick() g.ticked=(g.ticked or 0)+1 end
    function g.place() g.placed=(g.placed or 0)+1 end
    made[k]=g; return g
end
local G=require('partner.ghosts').new(link,make)
members={{id='2002',slot=0,linked=true},{id='4003',slot=1,linked=true},{id='4004',slot=3,linked=true}}
remotes={[1]={7,1,'peer'},[3]={9,2,'peer'}}
G.sync()
assert(made[0]==nil and made[1].k==1 and made[3].k==3 and made[1].on and made[3].on,'slots 1 and 3, not slot 0')
assert(made[1].calls[1][1]==7 and made[3].calls[1][2]==2)
G.tick(); G.place()
assert(made[1].ticked==1 and made[3].placed==1)
members={{id='2002',slot=0,linked=true},{id='4003',slot=1,linked=true}}; remotes[3]=nil
G.sync()
assert(#made[3].calls==2 and made[3].calls[2][1]==nil,'a gone member clears her ghost')
G.off(); assert(not made[1].on and not made[3].on)
-- What the ghosts say comes back as {ok, message}, with the slot; a ghost that raises is said once and the others go on.
do
    members,remotes,made={{id='5005',slot=2,linked=true},{id='5006',slot=4,linked=true}},{},{}
    local H=require('partner.ghosts').new(link,make)
    local said=H.sync()
    assert(#said==2 and said[1][1]==true and said[1][2]=='slot 2: toggled' and said[2][2]=='slot 4: toggled',
        tostring(said[1] and said[1][2]))
    made[2].tick=function() error('broken',0) end
    made[4].tick=function() return false,'stopped' end
    said=H.tick()
    assert(#said==2 and said[1][1]==false and said[1][2]:find('^slot 2: error') and said[1][2]:find('broken',1,true)
        and said[2][1]==false and said[2][2]=='slot 4: stopped',tostring(said[1] and said[1][2]))
    said=H.tick()
    assert(#said==1 and said[1][2]=='slot 4: stopped','the error once')
    assert(#H.place()==0,'nothing to say')
end
print('ghosts_test ok')
