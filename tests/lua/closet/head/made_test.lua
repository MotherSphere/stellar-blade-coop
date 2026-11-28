-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The closet's made head components (closet/head/made.lua) on a fake EVE: the component made, attached to her body at
-- the head socket with SBAccSlot1's rotation, or master-posed to it for a piece on the body's skeleton; destroyed;
-- an earlier Lua load's leftovers swept by the closet's component tag and mesh.
local run = dofile('tests/lua/closet/run.lua')

local calls = {}
local function said(...) calls[#calls + 1] = table.concat({...}, ' ') end
local function object(fields)
    local o = fields or {}
    o.type = function() return 'UObject' end
    o.IsValid = function(self) return not rawget(self, 'destroyed') end
    return o
end
local classes = {}
StaticFindObject = function(path)
    classes[path] = classes[path] or object({path = path})
    return classes[path]
end
FName = function(s) return s end
local Made = require('closet.head.made')

local function mesh(name) return object({name = name, GetFullName = function() return 'SkeletalMesh ' .. name end}) end
local glasses, other = mesh('/Game/G.G'), mesh('/Game/O.O')
-- A component: a name, a mesh, its calls as words.
local function component(name, m)
    local c = object({SkeletalMesh = m, ComponentTags = {}})
    -- UE4SS's TArray of FName: a write at 1 lands on an empty array (vehicles/bike/ride.lua's note).
    function c:ComponentHasTag(t)
        for _, x in ipairs(rawget(self, 'ComponentTags')) do if x == t then return true end end
        return false
    end
    function c:GetFName() return {type = function() return 'FName' end, ToString = function() return name end} end
    function c:SetCollisionEnabled(v) said(name, 'collision', v) end
    function c:K2_AttachToComponent(parent, socket, a, b, s, weld)
        said(name, 'attach', parent.label, socket, a, b, s, tostring(weld))
    end
    function c:SetSkeletalMesh(x, reinit)
        if rawget(self, 'mesh_raises') then error('no mesh', 0) end
        rawset(self, 'SkeletalMesh', x); said(name, 'mesh', x.name, tostring(reinit))
    end
    function c:SetMasterPoseComponent(x, force) said(name, 'master', x.label, tostring(force)) end
    function c:K2_SetRelativeRotation(r, sweep, _, teleport)
        assert(sweep == false and teleport == false)
        said(name, 'rotation', r.Pitch, r.Yaw, r.Roll)
    end
    function c:K2_DestroyComponent(x) assert(x == self); rawset(self, 'destroyed', true); said(name, 'destroy') end
    return c
end
local function eve_of()
    local e = object()
    local body = component('CharacterMesh0', mesh('/Game/Body.Body'))
    body.label = 'body'
    e.Mesh, e.parts, e.made = body, {body}, 0
    function e:AddComponentByClass(cls, manual, t, deferred)
        said('add', cls.path, tostring(manual), t.Translation.X, t.Rotation.W, t.Scale3D.X, tostring(deferred))
        e.made = e.made + 1
        local c = component('SBSkeletalMeshComponent_' .. (e.made - 1), nil)
        c.mesh_raises = e.mesh_raises
        e.parts[#e.parts + 1] = c
        return c
    end
    function e:K2_GetComponentsByClass(k)
        assert(k.path == '/Script/Engine.SkeletalMeshComponent')
        return e.parts
    end
    return e
end

local tests = {
    a_head_piece_goes_on_the_head_socket = function()
        calls = {}
        local e = eve_of()
        local c = Made.put(e, glasses, false)
        eq(table.concat(calls, '|'), 'add /Script/SB.SBSkeletalMeshComponent true 0 1 1 false|'
            .. 'SBSkeletalMeshComponent_0 collision 0|SBSkeletalMeshComponent_0 attach body Bip001-Head 2 2 2 true|'
            .. 'SBSkeletalMeshComponent_0 rotation -90 180 90|SBSkeletalMeshComponent_0 mesh /Game/G.G true')
        eq(c.SkeletalMesh, glasses)
        eq(c:ComponentHasTag(Made.TAG), true, 'tagged as the closet\'s')
    end,

    a_body_skeleton_piece_follows_her_pose = function()
        calls = {}
        local e = eve_of()
        Made.put(e, glasses, true)
        eq(table.concat(calls, '|'), 'add /Script/SB.SBSkeletalMeshComponent true 0 1 1 false|'
            .. 'SBSkeletalMeshComponent_0 collision 0|SBSkeletalMeshComponent_0 attach body None 2 2 2 true|'
            .. 'SBSkeletalMeshComponent_0 mesh /Game/G.G true|SBSkeletalMeshComponent_0 master body true')
    end,

    no_component_raises = function()
        local e = eve_of()
        function e:AddComponentByClass() return nil end
        local good, why = pcall(Made.put, e, glasses, false)
        eq(good, false) ok(tostring(why):find('could not make', 1, true), tostring(why))
    end,

    -- A step that fails after the make destroys the component, then raises: nothing is left on EVE untracked.
    -- A body-skeleton piece never shows unposed.
    a_failed_step_destroys_the_component = function()
        for _, on_body in ipairs({true, false}) do
            calls = {}
            local e = eve_of()
            e.mesh_raises = true
            local good, why = pcall(Made.put, e, glasses, on_body)
            eq(good, false) eq(why, 'no mesh')
            eq(e.parts[2]:IsValid(), false, 'destroyed')
            ok(not table.concat(calls, '|'):find('master', 1, true), table.concat(calls, '|'))
        end
    end,

    -- A tag that does not hold keeps the component (it shows) and says why: a Lua reload cannot sweep it.
    an_untagged_component_is_said = function()
        local e = eve_of()
        local add = e.AddComponentByClass
        function e:AddComponentByClass(...)
            local c = add(self, ...)
            c.ComponentHasTag = function() return false end
            return c
        end
        local c, why = Made.put(e, glasses, false)
        eq(c:IsValid(), true) ok(why and why:find('did not hold', 1, true), tostring(why))
    end,

    destroy_and_sweep = function()
        calls = {}
        local e = eve_of()
        local c = Made.put(e, glasses, false)
        Made.destroy(c)
        eq(c:IsValid(), false)
        Made.destroy(c) -- Gone already: no call.
        Made.destroy(nil)
        eq(#calls, 6, table.concat(calls, '|'))
        -- An earlier Lua load's: only a component with the closet's tag wearing the line's mesh goes. The game's own
        -- (a blueprint one, or an unnamed slot component FUN_14213a400 makes) on that mesh stays.
        local e2 = eve_of()
        local a, b = Made.put(e2, glasses, false), Made.put(e2, other, false)
        local own, slot = component('SBAccSlot1', glasses), component('SBSkeletalMeshComponent_7', glasses)
        e2.parts[#e2.parts + 1], e2.parts[#e2.parts + 2] = own, slot
        eq(Made.sweep(e2, {[glasses.name] = true}), 1)
        eq(a:IsValid(), false) eq(b:IsValid(), true) eq(own:IsValid(), true) eq(slot:IsValid(), true)
        eq(e2.Mesh:IsValid(), true)
    end,

    -- One component whose tag check raises is not ours: the sweep goes on to the others.
    a_raising_tag_check_does_not_abort_the_sweep = function()
        local e = eve_of()
        local bad = component('SBSkeletalMeshComponent_8', glasses)
        bad.ComponentHasTag = function() error('boom') end
        e.parts[#e.parts + 1] = bad
        local a = Made.put(e, glasses, false)
        eq(Made.sweep(e, {[glasses.name] = true}), 1)
        eq(a:IsValid(), false) eq(bad:IsValid(), true)
    end,
}

run('head_made_test', tests)
