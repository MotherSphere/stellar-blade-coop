-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The hairpin band (closet/pin.lua) over fake UE4SS objects: a worn body with no SC_HairACC socket takes EVE's
-- ACC_HairPin on the socket's bone with her own body's socket transform after the pin's own place; a body with the
-- socket leaves it; give_back puts it on SC_HairACC with its own place again; a socket that does not read leaves it,
-- said once.
local run = dofile('tests/lua/closet/run.lua')
FName = function(s) return s end
StaticFindObject = function(path) return {path = path, IsValid = function() return true end} end

local function obj(name, fields)
    local o = fields or {}
    o.name = name
    o.type = function() return 'UObject' end
    function o:IsValid() return true end
    function o:GetFName() return self.name end
    return o
end
-- A fake KismetMathLibrary: MakeTransform and ComposeTransforms give tables that name their inputs.
local LIB = {}
function LIB:MakeTransform(l, r, s) return {make = {l, r, s}} end
function LIB:ComposeTransforms(a, b) return {compose = {a, b}} end

local OWN_PLACE = {loc = {X = 1, Y = 2, Z = 3}, rot = {Pitch = 4, Yaw = 5, Roll = 6}, scale = {X = 1, Y = 1, Z = 1}}
local SOCKET = {BoneName = 'Bip001-Ponytail1', RelativeLocation = {X = 7, Y = 8, Z = 9},
    RelativeRotation = {Pitch = 10, Yaw = 11, Roll = 12}, RelativeScale = {X = 2, Y = 2, Z = 2}}

local function rig(opts)
    opts = opts or {}
    local r = {log = {}}
    local pin = obj('ACC_HairPin', {RelativeLocation = OWN_PLACE.loc, RelativeRotation = OWN_PLACE.rot,
        RelativeScale3D = OWN_PLACE.scale, attaches = {}, transforms = {}})
    function pin:K2_AttachToComponent(parent, socket, a, b, c, weld)
        self.attaches[#self.attaches + 1] = {parent = parent.name, socket = socket, rules = {a, b, c}, weld = weld}
        -- SnapToTarget zeroes the relative place, as the engine does.
        self.RelativeLocation, self.RelativeRotation = {X = 0, Y = 0, Z = 0}, {Pitch = 0, Yaw = 0, Roll = 0}
    end
    function pin:K2_SetRelativeTransform(t) self.transforms[#self.transforms + 1] = t end
    r.pin = pin
    r.eve = obj('EVE', {K2_GetComponentsByClass = function() return {obj('SBHair'), pin} end})
    r.body = obj('CharacterMesh0', {sockets = {}})
    function r.body:DoesSocketExist(name) return self.sockets[name] == true end
    r.own = obj('CH_P_EVE_29', {FindSocket = function(_, name)
        if opts.raises then error('read failed') end
        return name == 'SC_HairACC' and not opts.no_socket and obj('SC_HairACC', SOCKET) or nil
    end})
    package.loaded['closet.pin'] = nil
    r.Pin = require('closet.pin')
    r.p = r.Pin.new({log = function(m) r.log[#r.log + 1] = m end, math = function() return LIB end})
    return r
end
local function count(lines, needle)
    local n = 0
    for _, l in ipairs(lines) do if l:find(needle, 1, true) then n = n + 1 end end
    return n
end
local SOCKET_T = {make = {SOCKET.RelativeLocation, SOCKET.RelativeRotation, SOCKET.RelativeScale}}
local OWN_T = {make = {OWN_PLACE.loc, OWN_PLACE.rot, OWN_PLACE.scale}}

local tests = {
    a_body_with_no_socket_takes_the_pin_on_the_bone = function()
        local r = rig()
        ok(r.p.fit(r.eve, r.body, r.own))
        same(r.pin.attaches, {{parent = 'CharacterMesh0', socket = 'Bip001-Ponytail1', rules = {2, 2, 2},
            weld = false}}, 'on the socket bone, snapped')
        same(r.pin.transforms, {{compose = {OWN_T, SOCKET_T}}}, 'its own place, then the socket transform')
        -- The watchdog mixes again: the pin's own place is the first one read, not the bone's zeroed one.
        ok(r.p.fit(r.eve, r.body, r.own))
        same(r.pin.transforms[2], {compose = {OWN_T, SOCKET_T}}, 'the first own place kept')
    end,
    a_body_with_the_socket_changes_nothing = function()
        local r = rig()
        r.body.sockets.SC_HairACC = true
        r.p.fit(r.eve, r.body, r.own)
        same(r.pin.attaches, {}, 'never attached') same(r.pin.transforms, {}, 'never moved')
    end,
    give_back_puts_it_on_its_socket_again = function()
        local r = rig()
        ok(r.p.fit(r.eve, r.body, r.own))
        ok(r.p.give_back(r.body))
        same(r.pin.attaches[2], {parent = 'CharacterMesh0', socket = 'SC_HairACC', rules = {2, 2, 2}, weld = false})
        same(r.pin.transforms[2], OWN_T, 'its own place on the socket')
        eq(r.p.give_back(r.body), false, 'given back once')
        eq(#r.pin.attaches, 2)
    end,
    a_body_with_the_socket_after_a_move_gives_it_back = function()
        local r = rig()
        ok(r.p.fit(r.eve, r.body, r.own))
        r.body.sockets.SC_HairACC = true
        r.p.fit(r.eve, r.body, r.own)
        eq(r.pin.attaches[2].socket, 'SC_HairACC')
    end,
    give_back_with_nothing_moved_does_nothing = function()
        local r = rig()
        eq(r.p.give_back(r.body), false)
        same(r.pin.attaches, {})
    end,
    an_unreadable_socket_leaves_the_pin_and_says_it_once = function()
        for _, opts in ipairs({{no_socket = true}, {raises = true}}) do
            local r = rig(opts)
            r.p.fit(r.eve, r.body, r.own)
            r.p.fit(r.eve, r.body, r.own)
            r.p.fit(r.eve, r.body, nil)
            same(r.pin.attaches, {}, 'never attached') same(r.pin.transforms, {}, 'never moved')
            eq(count(r.log, 'left as it is'), 1, 'said once: ' .. show(r.log))
        end
    end,
    socket_reads_the_bone_and_transform = function()
        local r = rig()
        local s = r.Pin.socket(r.own)
        same(s, {bone = 'Bip001-Ponytail1', loc = SOCKET.RelativeLocation, rot = SOCKET.RelativeRotation,
            scale = SOCKET.RelativeScale})
        local none, why = r.Pin.socket(nil)
        eq(none, nil) ok(why)
        eq(r.Pin.find(r.eve, 'class'), r.pin, 'the pin by its name')
    end,
}
run('pin_test', tests)
