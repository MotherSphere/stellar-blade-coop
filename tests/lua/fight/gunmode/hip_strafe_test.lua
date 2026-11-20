-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Hip fire's strafe legs: the custom moving stance row by state (GunMode.stance_row), the switch between rows on a fake
-- pawn (GunMode.stance_set), the release gun mode's disable makes, and the coop-settings line.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
function FName(x) return x end
local GunMode=require('fight.gunmode.mode')
local Config=require('fight.gunmode.config')
local Check=require('fight.gunmode.release_check')

-- 1. The row: hip fire's set while hip firing, the carry set while not zoomed, none in the game's aim; switched off,
-- hip fire keeps the carry set as before.
do
    local R=GunMode.stance_row
    assert(R(true,false,'H','C',true)=='H')
    assert(R(false,false,'H','C',true)=='C')
    assert(R(false,true,'H','C',true)==nil)
    assert(R(true,false,'H','C',false)=='C')
    assert(R(false,false,'H',nil,true)==nil)             -- no pak: no carry set
    assert(R(true,false,'H',nil,true)=='H')              -- the strafe set needs no pak
end

-- 2. A fake pawn with one custom moving stance slot: a switch lets the old row go first; the same row is set once;
-- nil leaves none active (gun mode's disable calls it so); a failed set keeps none.
do
    local calls={}
    local p={active=nil}
    function p:ActiveCustomMovingStanceData(d)
        assert(not self.active,'a row set over an active one')
        calls[#calls+1]='on '..d.OverrideStanceAnim..' '..d.NormalAnimRangeDegree
        self.active=d.OverrideStanceAnim
    end
    function p:DeactiveCustomMovingStanceData() calls[#calls+1]='off'; self.active=nil end
    function p:IsActiveCustomMovingStanceData() return self.active~=nil end
    local lines={}
    local s={ovr_log={}}
    local log=function(l) lines[#lines+1]=l end
    GunMode.stance_set(s,p,'C',180.0,log)
    GunMode.stance_set(s,p,'C',180.0,log)
    assert(#calls==1 and s.ovr_active=='C')
    GunMode.stance_set(s,p,'P_Eve_Gun_Battle',45.0,log)
    assert(calls[2]=='off' and calls[3]=='on P_Eve_Gun_Battle 45.0' and p.active=='P_Eve_Gun_Battle')
    GunMode.stance_set(s,p,'C',180.0,log)
    GunMode.stance_set(s,p,'P_Eve_Gun_Battle',45.0,log)
    GunMode.stance_set(s,p,nil,180.0,log)                -- the rifle goes away
    assert(p.active==nil and s.ovr_active==nil,'disable leaves no override active')
    -- the trace: one line per row and one for the release, each with the slot's state
    assert(#lines==3,#lines..' log lines')
    assert(lines[1]:find('override C',1,true) and lines[1]:find('active=true',1,true))
    assert(lines[2]:find('override off',1,true) and lines[2]:find('active=false',1,true))
    assert(lines[3]:find('P_Eve_Gun_Battle',1,true))
    -- a set the pawn refuses keeps none (tried again next frame)
    local bad={}
    function bad:ActiveCustomMovingStanceData() error('no') end
    local s2={}
    GunMode.stance_set(s2,bad,'C',180.0)
    assert(s2.ovr_active==nil)
end

-- 3. The coop-settings line: a row name taken, anything else refused; a release build must not carry it.
do
    assert(Config.parse('gun_hip_strafe_row=P_Eve_Gun_Battle\n').hip_strafe_row=='P_Eve_Gun_Battle')
    assert(Config.parse('gun_hip_strafe_row=bad row!\n').hip_strafe_row==nil)
    local ok=Check.run('gun_hip_strafe_row=X\n',nil)
    assert(ok==false,'gun_hip_strafe_row is test only')
    local D=Config.DEFAULTS
    assert(D.hip_strafe==false and D.hip_strafe_row=='P_Eve_Gun_Battle' and D.hip_strafe_deg==180)
end
print('gunmode hip_strafe_test ok')
