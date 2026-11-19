-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The bike's paint for the outfit EVE wears. Paint.BY_MESH, written by hand, maps EVE's body mesh (the SkeletalMesh of
-- her main mesh, which eve/wear.lua sets for coop wear) to vector parameter values per material slot of SB's bike mesh
-- Adam_Vehicle_02. Its four slots and their material instances, read in the game's paks on build 26123051:
-- 0 MI_Adam_vehicle_02_03, 1 MI_Adam_vehicle_02_01, 2 MI_Adam_vehicle_02_04, 3 MI_Adam_vehicle_02_02. All four are
-- children of the material MA_AdamVehicle, whose vector parameters are EmissiveColor, Eye Core HDR Tint,
-- ClearCoatColor, Flakecolor, ScratchColor, AO Tint, Emissive Channel, GrimeColor, Eye Edge Glow Color and Base Color
-- Tint. A name with a space cannot be listed (Paint.check). Once a second (vehicles/bike/ride.lua's 250 ms pass) each
-- bike component whose outfit changed gets its mesh's own materials back, then a dynamic material instance made from
-- the mesh's own material on each listed slot, with the values set on it. Those components are the part EVE rides and
-- her parked bike. The ridden part reaches ghosts through the capture's dyes (coop look dyes). The parked bike's paint
-- stays on this screen: the bike line carries its map and pose only. tests/lua/vehicles/bike/paint_test.lua covers it;
-- docs/dev/modding/bike-paint.md says how to add an entry.
local U=require('core.unreal')
local valid,each,address,why_of=U.valid,U.each,U.address,U.why
local Paint={}
Paint.SLOTS=4 -- Adam_Vehicle_02's material slots.
Paint.MAX=1e5 -- online/partner/capture.lua's bound on a value it sends to ghosts.
Paint.EVERY=1 -- s between two steps, as coop wear checks its look.
-- [<EVE's body mesh object path>]={[<slot 0 to 3>]={[<vector parameter>]={r,g,b,a}}}
Paint.BY_MESH={
    -- Gothic Rose (coop wear gothic): a dark red flake on slot 1 (MI_Adam_vehicle_02_01, which sets Flakecolor).
    ['/Game/Art/Character/PC/CH_P_EVE_IberisCostume/CH_P_EVE_IberisCos.CH_P_EVE_IberisCos']={
        [1]={Flakecolor={0.55,0.05,0.10,1}}},
}

local function colour(v)
    if type(v)~='table' or #v~=4 then return false end
    for k=1,4 do
        local x=v[k]
        if type(x)~='number' or x~=x or x<0 or x>Paint.MAX then return false end
    end
    return true
end
-- true, or false and the first fault: a key that is no object path /Game/<folder>/<name>.<name>, a slot out of 0 to
-- Paint.SLOTS-1, a name that is not 1 to 64 bytes of '!' to '}' (online/partner/capture.lua sends no longer name), a
-- value that is not four numbers from 0 to Paint.MAX.
function Paint.check(by_mesh)
    if type(by_mesh)~='table' then return false,'the table is no Lua table' end
    for mesh,slots in pairs(by_mesh) do
        local file,object
        if type(mesh)=='string' then file,object=mesh:match('^/Game/.+/([^/.]+)%.([^/.]+)$') end
        if not file or file~=object then
            return false,tostring(mesh)..': not an object path /Game/<folder>/<name>.<name>'
        end
        if type(slots)~='table' then return false,mesh..': no slot table' end
        for slot,values in pairs(slots) do
            if math.type(slot)~='integer' or slot<0 or slot>=Paint.SLOTS then
                return false,('%s: slot %s is not 0 to %d'):format(mesh,tostring(slot),Paint.SLOTS-1)
            end
            if type(values)~='table' then return false,('%s slot %d: no parameter table'):format(mesh,slot) end
            for name,v in pairs(values) do
                if type(name)~='string' or #name>64 or not name:find('^[!-}]+$') then
                    return false,('%s slot %d: parameter "%s" is not 1 to 64 bytes of ! to }'):format(mesh,slot,
                        tostring(name))
                end
                if not colour(v) then
                    return false,('%s slot %d %s: not four numbers from 0 to %d'):format(mesh,slot,name,Paint.MAX)
                end
            end
        end
    end
    return true
end
-- The bike mesh's own material in each slot, by slot from 0 (its Materials, as eve/wear.lua reads a suit's). Never
-- GetMaterial: that would give an instance an earlier Lua load left on the component.
local function bases(c)
    local list={}
    each(assert(valid(c.SkeletalMesh),'the component has no mesh').Materials,function(index,s)
        list[index-1]=valid(s.MaterialInterface)
    end)
    return list
end
-- Each slot of entry on component c: an instance made from the mesh's own material, its values set. Raises on a
-- failed call.
function Paint.apply(c,entry)
    local base=bases(c)
    for slot,values in pairs(entry) do
        local own=assert(base[slot],'no material in slot '..slot)
        local mid=assert(valid(c:CreateDynamicMaterialInstance(slot,own,FName('None'))),'no instance on slot '..slot)
        for name,v in pairs(values) do mid:SetVectorParameterValue(FName(name),{R=v[1],G=v[2],B=v[3],A=v[4]}) end
    end
end
-- Every slot of component c back to the mesh's own material. Raises on a failed call.
function Paint.clear(c)
    local base=bases(c)
    for slot=0,Paint.SLOTS-1 do c:SetMaterial(slot,assert(base[slot],'no material in slot '..slot)) end
end

local function path_of(o) return U.text(o:GetFullName()):match('^%S+ (.+)$') end
-- o.log: one line per fault. The table is checked once here: a table that fails paints nothing.
function Paint.new(o)
    local log=o.log
    local ok,why=Paint.check(Paint.BY_MESH)
    if not ok then log('bike paint table refused: '..why) end
    local by_mesh=ok and Paint.BY_MESH or {}
    local self={}
    local last=nil -- The time of the last step that ran.
    -- By component ('<address> <object path>', so a new component at a freed address is a new one): its path, the mesh
    -- it was last set for (false: none read) and the meshes whose fault on it was logged (said).
    local seen={}
    local function key_of(c)
        c=assert(valid(c),'the component is gone')
        local path=path_of(c)
        return address(c)..' '..path,path
    end
    -- Whether mesh (an object path or nil) has a paint.
    function self.on(mesh) return mesh~=nil and by_mesh[mesh]~=nil end
    -- now: os.clock(). mesh: EVE's body mesh path, nil when unread. parts: the live bike components (nil ones skipped).
    -- A component already set for this mesh is left alone. Else it is cleared, then painted when the mesh has an entry.
    -- A failed call leaves it with the mesh's own materials. Never raises.
    function self.step(now,mesh,parts)
        if last and now-last<Paint.EVERY then return end
        last=now
        local kept,m={},mesh or false
        for _,c in pairs(parts) do
            local read,key,path=pcall(key_of,c)
            if read then
                local s=seen[key] or {said={}}
                kept[key]=s
                if s.mesh~=m then
                    s.mesh=m
                    local done,err=pcall(function()
                        Paint.clear(c)
                        if m and by_mesh[m] then Paint.apply(c,by_mesh[m]) end
                    end)
                    if not done then
                        pcall(Paint.clear,c)
                        if not s.said[m] then
                            s.said[m]=true
                            log(('bike paint not set on %s for %s: %s'):format(path,mesh or 'no mesh',why_of(err)))
                        end
                    end
                end
            end
        end
        seen=kept
    end
    -- coop off and bike=off: parts back to the mesh's own materials, forgotten so the next step paints them again.
    -- Never raises.
    function self.clear(parts)
        for _,c in pairs(parts) do
            local read,key=pcall(key_of,c)
            if read then seen[key]=nil end
            pcall(Paint.clear,c)
        end
    end
    return self
end
return Paint
