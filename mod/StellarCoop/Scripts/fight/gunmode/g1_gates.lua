-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gate G1 (standing aim at camera pitch -40, 0 and +40): the pass thresholds, fixed before the build
-- so they are not tuned to the result. Values are unchanged since they were written down. Units cm and degrees.
-- The red test runs these on the build before the v3a graph: the wrist, neck and pocket gates must FAIL there.
local Gates={}

-- min / max are inclusive limits; pitches limits a gate to some pitches; logonly gates never decide the result
Gates.LIST={
    {id='butt_pocket',      what='butt centre to pocket point',               max=1.0},
    {id='shoulder_drift',   what='shoulder joints in Spine2 space vs layer off', max=2.0},
    {id='rwrist_neck',      what='right wrist to neck capsule',               min=6.0},
    {id='rforearm_neck',    what='right forearm to neck capsule',             min=3.0},
    {id='grip_fwd',         what='grip forward of the right shoulder joint',  min=15.0},
    {id='stock_clear',      what='stock samples vs neck, collar, chest',      min=0.5},
    {id='breast_clear_0',   what='rifle and forearms vs breast proxies',      min=1.0, pitches={0}},
    {id='breast_clear_40',  what='rifle and forearms vs breast proxies',      min=-1.0, pitches={-40,40}},
    {id='eye_sight',        what='eye to sight line',                         max=5.0, pitches={0}},
    {id='bore_ray',         what='bore to camera ray, two-point, at rest',    max=0.5},
    {id='wrist_flex_L',     what='left wrist flexion/extension',              max=45},
    {id='wrist_flex_R',     what='right wrist flexion/extension',             max=45},
    {id='wrist_dev_L',      what='left wrist deviation',                      max=30},
    {id='wrist_dev_R',      what='right wrist deviation',                     max=30},
    {id='wrist_twist_L',    what='left residual twist',                       max=30},
    {id='wrist_twist_R',    what='right residual twist',                      max=30},
    {id='elbow_L',          what='left elbow interior angle',                 min=60, max=150},
    {id='elbow_R',          what='right elbow interior angle',                min=60, max=150},
    {id='lforearm_vert',    what='left forearm from vertical',                min=30},
    {id='reach_L',          what='left reach',                                max=0.90},
    {id='reach_R',          what='right reach',                               max=0.90},
    {id='lpalm_normal',     what='left palm normal to handguard axis',        max=25},
    {id='lpalm_gap',        what='left palm gap to handguard',                max=1.5},
    {id='lpalm_rear',       what='left palm position, 0 = rear end of the handguard underside, 1 = front', max=0.40},
    {id='fingertip',        what='fingertip to rifle surface (expected to FAIL)', max=1.2, logonly=true},
}

-- Measured once, game closed (NikkeGunBuild\g1\measure.json, Nov 19 2026). Rifle space: bore along -X at Z 9.9.
Gates.RIFLE={length=63.7, butt_x=14.96, butt_centre={X=14.96,Y=0,Z=8.72}, heel_z=12.69, toe_z=2.62,
    hand_bone={X=5.90,Y=-0.04,Z=1.79}, butt_to_hand_bone=9.06, butt_to_magwell=27.06, sight_above_bore=7.87,
    handguard_x={-44,-18}}  -- the handguard underside spans about X -44 to -18
Gates.BODY={arm_upper=24.38, arm_fore=24.39, shoulder_half_width=11.54, head_above_shoulder=11.61,
    bust_front_of_shoulder=14.45, underbust_below_shoulder=13.80} -- vanilla CH_P_EVE_01_Body; the catsuit is unmeasured

local function applies(g,pitch) if not g.pitches or pitch==nil then return true end
    for _,p in ipairs(g.pitches) do if p==pitch then return true end end
    return false
end

-- one gate: true (pass), false (fail), or nil (not this pitch, or no value)
function Gates.check(id,value,pitch)
    for _,g in ipairs(Gates.LIST) do
        if g.id==id then
            if value==nil or not applies(g,pitch) then return nil end
            return (g.min==nil or value>=g.min) and (g.max==nil or value<=g.max)
        end
    end
    error('g1_gates: no gate '..tostring(id))
end

-- a measured set {id=value} at one pitch -> passed, failed lists (logonly gates go to neither)
function Gates.judge(values,pitch)
    local pass,fail={},{}
    for _,g in ipairs(Gates.LIST) do
        local r=Gates.check(g.id,values[g.id],pitch)
        if r~=nil and not g.logonly then if r then pass[#pass+1]=g.id else fail[#fail+1]=g.id end end
    end
    return pass,fail
end

return Gates
