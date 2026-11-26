-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop closet wear (closet/dress.lua) over fake UE4SS objects: the plan (the shoes' outfit on the body with its skin,
-- one added mesh per other outfit, covered skin hidden, the refusals), the mix on EVE, her own look kept and given
-- back by off and by the next Lua load, and the watchdog: Tachy Mode's suit pauses the mix, a changed look for 2 s gets
-- it again, a section the game showed again is hidden again. The words of coop closet (closet/commands.lua).
local run = dofile('tests/lua/closet/run.lua')
package.loaded.UEHelpers = {GetPlayer = function() return nil end} -- world() replaces it

local function obj(path, fields)
    local o = fields or {}
    o.path = path
    o.alive = true
    o.type = function() return 'UObject' end
    function o:IsValid() return self.alive end
    function o:GetFullName() return 'Class ' .. self.path end
    function o:IsA(class) return class == 'SBCharacter' and self.is_eve == true end
    return o
end
local function mesh(path, n)
    local m = obj(path)
    m.Skeleton = obj('/Game/Art/EVE/Skeleton.Skeleton')
    m.Materials = {}
    for i = 1, n do m.Materials[i] = {MaterialInterface = obj(path .. ':M' .. (i - 1))} end
    return m
end
local function component(path, owner)
    local c = obj(path)
    c.hidden, c.mats, c.owner = {}, {}, owner
    function c:SetSkeletalMesh(m) self.SkeletalMesh = m; self.mats = {}; self.hidden = {} end
    function c:SetMaterial(i, m) self.mats[i] = m end
    function c:GetNumMaterials() return self.SkeletalMesh and #self.SkeletalMesh.Materials or 0 end
    function c:GetMaterial(i)
        return self.mats[i] or (self.SkeletalMesh and self.SkeletalMesh.Materials[i + 1].MaterialInterface)
    end
    function c:GetNumLODs() return 2 end
    function c:ShowMaterialSection(i, _, show, lod) self.hidden[lod .. ':' .. i] = not show or nil end
    function c:ShowAllMaterialSections(lod)
        for k in pairs(self.hidden) do if k:match('^' .. lod .. ':') then self.hidden[k] = nil end end
    end
    function c:IsMaterialSectionShown(i, lod) return not self.hidden[lod .. ':' .. i] end
    function c:SetCollisionEnabled(n) self.collision = n end
    function c:K2_AttachToComponent(parent) self.parent = parent end
    function c:SetMasterPoseComponent(leader) self.leader = leader end
    function c:SetHiddenInGame(h) self.hidden_in_game = h end
    function c:K2_DestroyComponent() self.alive = false; self.owner:forget(self) end
    return c
end

local OM, KS = '/Game/OutfitMods/AiK_CH27/CH27_NRS.CH27_NRS', '/Game/OutfitMods/AiK_CH46/CH46_xSH_NRS.CH46_xSH_NRS'
local OWN, TACHY = '/Game/Art/Character/PC/CH_P_EVE_29/CH_P_EVE_29.CH_P_EVE_29',
    '/Game/Art/Character/PC/CH_P_EVE_10/CH_P_EVE_10.CH_P_EVE_10'

local function world()
    local w = {assets = {}, log = {}, file = nil, now = 100}
    w.assets[OM] = mesh(OM, 48)
    w.assets[KS] = mesh(KS, 44)
    w.assets[OWN] = mesh(OWN, 6)
    w.assets[TACHY] = mesh(TACHY, 3)
    local eve = obj('/Game/Maps/World.World:PersistentLevel.EVE', {is_eve = true})
    eve.comps = {}
    function eve:forget(c) for i, x in ipairs(self.comps) do if x == c then table.remove(self.comps, i) end end end
    eve.Mesh = component(eve.path .. '.CharacterMesh0', eve)
    eve.Mesh:SetSkeletalMesh(w.assets[OWN])
    eve.comps[1] = eve.Mesh
    local n = 0
    function eve:AddComponentByClass()
        n = n + 1
        local c = component(self.path .. '.SkeletalMeshComponent_' .. n, self)
        self.comps[#self.comps + 1] = c
        return c
    end
    function eve:K2_GetComponentsByClass() return {table.unpack(self.comps)} end
    w.eve = eve
    package.loaded.UEHelpers = {GetPlayer = function() return w.eve end}
    StaticFindObject = function(path)
        if path == '/Script/SB.SBCharacter' then return obj(path, {is_eve = false, cls = true}) end
        if path:find('^/Game/') then return w.assets[path] end
        return obj(path)
    end
    LoadAsset = function() end
    FName = function(s) return s end
    -- U.her checks IsA against the class U.find returns; the fake class answers to its own path.
    package.loaded['core.unreal'] = nil
    local fresh = require('core.unreal')
    fresh.her = function(pawn) return pawn and pawn.is_eve and pawn or nil end
    package.loaded['closet.dress'] = nil
    local Dress = require('closet.dress')
    w.Dress = Dress
    w.loads = 0
    w.store = {save = function(line) w.file = line; return true end,
        load = function() w.loads = w.loads + 1; return w.file end, clear = function() w.file = nil end}
    w.new = function()
        return Dress.new({log = function(m) w.log[#w.log + 1] = m end, store = w.store,
            clock = function() return w.now end, paused = function() return w.paused == true end})
    end
    w.d = w.new()
    return w
end
local function logged(w, needle)
    for _, line in ipairs(w.log) do if line:find(needle, 1, true) then return true end end
    return false
end
local function second(w) w.now = w.now + 1.01; w.d.tick() end
-- A coop-closet.txt line's tab-separated fields, empty ones kept (as restore reads it).
local function fields(line)
    local f = {}
    for x in (line .. '\t'):gmatch('([^\t]*)\t') do f[#f + 1] = x end
    return f
end

local tests = {
    plan_puts_the_shoes_outfit_on_the_body = function()
        local Dress = require('closet.dress')
        local plan = assert(Dress.plan({{fit = 'AiK_CH27_14595', slots = {'Chest', 'Legs'}},
            {fit = 'AiK_CH46_xSH_14462', slots = {'Shoes'}}}))
        eq(plan.body.fit, 'AiK_CH46_xSH_14462', 'the shoes supply the body')
        eq(plan.parts, 1) eq(plan.pieces, 3)
        ok(plan.body.show[19] and plan.body.show[0] and plan.body.show[1] and plan.body.show[2], 'boots and skin')
        ok(not plan.body.show[3], 'no jacket')
        ok(plan.added[1].show[15] and plan.added[1].show[42] and not plan.added[1].show[14], 'top, stockings, no skin')
    end,
    covered_skin_is_hidden = function()
        local Dress = require('closet.dress')
        local plan = assert(Dress.plan({{fit = 'AiK_CH46_xSH_14462', slots = {'Gloves', 'Shoes'}}}))
        ok(plan.body.show[0] and not plan.body.show[1] and not plan.body.show[2], 'arms and hands skin under gloves')
        plan = assert(Dress.plan({{fit = 'AiK_CH46_xSH_14462', slots = {'Shoes'}}}))
        ok(plan.body.show[1] and plan.body.show[2], 'bare arms show')
    end,
    a_fit_alone_is_the_outfit_as_is = function()
        local Dress = require('closet.dress')
        local plan = assert(Dress.plan({{fit = 'AiK_CH27_14595'}}))
        eq(plan.parts, 0) eq(plan.pieces, 9, 'every piece shown by default')
        ok(not plan.body.show[42], 'stockings are off by default')
    end,
    plan_refusals = function()
        local Dress = require('closet.dress')
        local function why(c) local p, e = Dress.plan(c) eq(p, nil) return e end
        ok(why({}):find('nothing to wear'))
        ok(why({{fit = 'nope'}}):find('no fit map'))
        ok(why({{fit = 'AiK_CH27_14595', slots = {'Mask'}}}):find('has no Mask'))
        ok(why({{fit = 'AiK_CH27_14595', slots = {'Hat'}}}):find('unknown slot'))
        ok(why({{fit = 'AiK_CH27_14595', slots = {'Shoes'}}, {fit = 'AiK_CH46_xSH_14462', slots = {'Shoes'}}})
            :find('Shoes is worn twice'))
        ok(why({{fit = 'AiK_CH27_14595'}, {fit = 'AiK_CH27_14595'}}):find('named twice'))
    end,
    parse_words = function()
        local Dress = require('closet.dress')
        same(Dress.parse({'AiK_CH27_14595:Chest,Legs', 'AiK_CH46_xSH_14462'}),
            {{fit = 'AiK_CH27_14595', slots = {'Chest', 'Legs'}}, {fit = 'AiK_CH46_xSH_14462'}})
        eq(Dress.parse({'a b'}), nil)
    end,
    words_are_the_inverse_of_parse = function()
        local Dress = require('closet.dress')
        local line = 'AiK_CH27_14595:Chest,Legs AiK_CH46_xSH_14462'
        local words = {}
        for x in line:gmatch('%S+') do words[#words + 1] = x end
        eq(Dress.words(assert(Dress.parse(words))), line)
    end,
    the_worn_choices_are_kept = function()
        local w = world()
        assert(w.d.wear({{fit = 'AiK_CH27_14595', slots = {'Chest'}}, {fit = 'AiK_CH46_xSH_14462',
            slots = {'Shoes'}}}))
        eq(fields(w.file)[5], 'AiK_CH27_14595:Chest AiK_CH46_xSH_14462:Shoes')
    end,
    wear_then_off = function()
        local w = world()
        local ok_, line = w.d.wear({{fit = 'AiK_CH27_14595', slots = {'Chest'}}, {fit = 'AiK_CH46_xSH_14462',
            slots = {'Shoes'}}})
        ok(ok_, line)
        local body = w.eve.Mesh
        eq(body.SkeletalMesh.path, KS, 'boots outfit on the body')
        ok(body.hidden['0:3'] and body.hidden['1:3'] and not body.hidden['0:19'], 'jacket hidden on both LODs')
        eq(#w.eve.comps, 2)
        local added = w.eve.comps[2]
        eq(added.SkeletalMesh.path, OM) eq(added.leader, body) eq(added.parent, body) eq(added.collision, 0)
        ok(not added.hidden['0:15'] and added.hidden['0:14'], 'top shows, its skin does not')
        ok(w.file and w.file:find(OWN, 1, true), 'her own mesh kept in coop-closet.txt')
        ok(w.d.status():find('3 pieces') == nil and w.d.status():find('2 pieces'), w.d.status())
        w.d.off()
        eq(body.SkeletalMesh.path, OWN, 'her own look back') eq(#w.eve.comps, 1) eq(w.file, nil)
        ok(next(body.hidden) == nil)
    end,
    tachy_pauses_then_the_mix_comes_back = function()
        local w = world()
        assert(w.d.wear({{fit = 'AiK_CH27_14595', slots = {'Chest'}}, {fit = 'AiK_CH46_xSH_14462',
            slots = {'Shoes'}}}))
        local added = w.eve.comps[2]
        w.eve.Mesh:SetSkeletalMesh(w.assets[TACHY])
        second(w) second(w) second(w)
        eq(w.eve.Mesh.SkeletalMesh.path, TACHY, 'the Tachy suit shows') eq(added.hidden_in_game, true)
        ok(logged(w, 'mix paused'))
        -- Tachy Mode ends: the game puts the mixed mesh back, all sections shown.
        w.eve.Mesh:SetSkeletalMesh(w.assets[KS])
        second(w)
        eq(added.hidden_in_game, false, 'added mesh back')
        eq(w.eve.Mesh.SkeletalMesh.path, KS, 'mix back at once')
        ok(w.eve.Mesh.hidden['0:3'], 'jacket hidden again')
    end,
    a_map_load_gets_the_mix_again = function()
        local w = world()
        assert(w.d.wear({{fit = 'AiK_CH27_14595', slots = {'Chest'}}, {fit = 'AiK_CH46_xSH_14462',
            slots = {'Shoes'}}}))
        w.eve.comps[2]:K2_DestroyComponent()
        w.eve.Mesh:SetSkeletalMesh(w.assets[OWN])
        second(w)
        eq(w.eve.Mesh.SkeletalMesh.path, OWN, 'one second: wait')
        second(w)
        eq(w.eve.Mesh.SkeletalMesh.path, KS, 'two seconds: mixed again') eq(#w.eve.comps, 2)
        ok(logged(w, 'mix again'))
        ok(w.file:find('AiK_CH27_14595:Chest AiK_CH46_xSH_14462:Shoes', 1, true), 'choices kept after mix again')
        w.d.off()
        eq(w.eve.Mesh.SkeletalMesh.path, OWN, 'off still gives her own look')
    end,
    hidden_sections_shown_again_are_hidden = function()
        local w = world()
        assert(w.d.wear({{fit = 'AiK_CH46_xSH_14462', slots = {'Shoes'}}}))
        w.eve.Mesh:ShowAllMaterialSections(0)
        second(w)
        ok(w.eve.Mesh.hidden['0:3'], 'hidden again') ok(logged(w, 'hidden again'))
    end,
    a_lua_reload_wears_the_look_again = function()
        local w = world()
        assert(w.d.wear({{fit = 'AiK_CH27_14595', slots = {'Chest'}}, {fit = 'AiK_CH46_xSH_14462',
            slots = {'Shoes'}}}))
        local d2 = w.new() -- Ctrl+R: a new Lua state, the mix still on EVE
        d2.tick()
        eq(w.eve.Mesh.SkeletalMesh.path, KS, 'worn again') eq(#w.eve.comps, 2, 'one added mesh, no orphan')
        ok(logged(w, 'worn again: AiK_CH27_14595:Chest AiK_CH46_xSH_14462:Shoes'))
        d2.off()
        eq(w.eve.Mesh.SkeletalMesh.path, OWN, 'off still gives her own look') eq(w.file, nil)
    end,
    a_restart_wears_the_look_again = function()
        local w = world()
        assert(w.d.wear({{fit = 'AiK_CH46_xSH_14462'}}))
        local kept = w.file
        local w2 = world() -- a new game: EVE in her own look, no added mesh
        w2.file = kept
        w2.d.tick()
        eq(w2.eve.Mesh.SkeletalMesh.path, KS) ok(w2.file and w2.file:find('AiK_CH46_xSH_14462', 1, true))
    end,
    restore_waits_for_eve = function()
        local w = world()
        assert(w.d.wear({{fit = 'AiK_CH46_xSH_14462'}}))
        local kept, eve = w.file, w.eve
        w.eve = nil -- the title screen
        local d2 = w.new()
        d2.tick()
        eq(w.file, kept, 'file untouched while there is no EVE')
        w.eve = eve
        d2.tick()
        eq(w.eve.Mesh.SkeletalMesh.path, KS) ok(logged(w, 'worn again'))
    end,
    off_before_eve_drops_the_kept_look = function()
        local w = world()
        assert(w.d.wear({{fit = 'AiK_CH46_xSH_14462'}}))
        local w2 = world() -- a new game, still on the title screen
        w2.file = w.file
        local eve = w2.eve
        w2.eve = nil
        w2.d.tick()
        w2.d.off()
        eq(w2.file, nil, 'off clears the kept look')
        w2.eve = eve
        w2.d.tick()
        eq(w2.eve.Mesh.SkeletalMesh.path, OWN, 'nothing worn when EVE appears')
    end,
    a_restart_in_another_look_keeps_that_look_as_her_own = function()
        local w = world()
        assert(w.d.wear({{fit = 'AiK_CH46_xSH_14462'}}))
        local w2 = world()
        w2.file = w.file
        local other = '/Game/Art/Character/PC/CH_P_EVE_31/CH_P_EVE_31.CH_P_EVE_31'
        w2.assets[other] = mesh(other, 6)
        w2.eve.Mesh:SetSkeletalMesh(w2.assets[other]) -- the save she loads in wears another suit
        w2.d.tick()
        eq(w2.eve.Mesh.SkeletalMesh.path, KS, 'worn again')
        w2.d.off()
        eq(w2.eve.Mesh.SkeletalMesh.path, other, 'off gives back the suit she spawned in')
    end,
    a_failed_wear_while_she_spawns_is_tried_again = function()
        local w = world()
        assert(w.d.wear({{fit = 'AiK_CH46_xSH_14462'}}))
        local w2 = world()
        w2.file = w.file
        local body = w2.eve.Mesh
        w2.eve.Mesh = nil -- spawning: no body mesh yet
        w2.d.tick()
        ok(w2.file, 'the kept look waits')
        w2.eve.Mesh = body
        w2.now = w2.now + 1.01
        w2.d.tick()
        eq(w2.eve.Mesh.SkeletalMesh.path, KS, 'worn once she is ready')
    end,
    restore_waits_while_the_game_is_paused = function()
        local w = world()
        assert(w.d.wear({{fit = 'AiK_CH46_xSH_14462'}}))
        local w2 = world()
        w2.file = w.file
        w2.paused = true -- a loading screen or one of the game's screens
        w2.d.tick()
        eq(w2.eve.Mesh.SkeletalMesh.path, OWN) ok(w2.file)
        w2.paused = false
        w2.d.tick()
        eq(w2.eve.Mesh.SkeletalMesh.path, KS)
    end,
    the_kept_line_is_read_once = function()
        local w = world()
        assert(w.d.wear({{fit = 'AiK_CH46_xSH_14462'}}))
        local w2 = world()
        w2.file = w.file
        local eve = w2.eve
        w2.eve = nil
        for _ = 1, 5 do w2.d.tick() end
        w2.eve = eve
        w2.d.tick()
        eq(w2.loads, 1, 'one read while waiting for EVE') eq(w2.eve.Mesh.SkeletalMesh.path, KS)
    end,
    a_kept_look_that_cannot_be_worn_is_dropped = function()
        local w = world()
        w.file = '\t' .. OWN .. '\t\t\tNoSuchFit'
        w.d.tick()
        eq(w.eve.Mesh.SkeletalMesh.path, OWN) eq(w.file, nil) ok(logged(w, 'could not wear NoSuchFit again'))
    end,
    an_old_four_field_line_only_gives_her_look_back = function()
        local w = world()
        assert(w.d.wear({{fit = 'AiK_CH27_14595', slots = {'Chest'}}, {fit = 'AiK_CH46_xSH_14462',
            slots = {'Shoes'}}}))
        w.file = w.file:match('^(.*)\t[^\t]*$') -- drop field 5, as the build before it writes
        local d2 = w.new()
        d2.tick()
        eq(w.eve.Mesh.SkeletalMesh.path, OWN) eq(#w.eve.comps, 1) eq(w.file, nil)
        ok(logged(w, 'restore from coop-closet.txt: 1 added mesh(es) removed'))
    end,
    nothing_changes_when_a_mesh_is_missing = function()
        local w = world()
        w.assets[OM] = nil
        local ok_, why = w.d.wear({{fit = 'AiK_CH27_14595'}})
        eq(ok_, false) ok(why:find('not found'), why)
        eq(w.eve.Mesh.SkeletalMesh.path, OWN) eq(w.file, nil)
    end,
    commands = function()
        local w = world()
        local C = require('closet.commands').new({dress = w.d, fits = require('closet.fits')})
        local ok_, line = C.closet()
        ok(ok_ and line == 'closet: nothing worn', line)
        ok_, line = C.closet('fits')
        ok(ok_ and line:find('AiK_CH27_14595: ') and line:find('AiK_CH46_xSH_14462: '), line)
        ok_, line = C.closet('wear', 'AiK_CH27_14595:Chest', 'AiK_CH46_xSH_14462:Shoes')
        ok(ok_, line)
        ok_, line = C.closet('wear')
        ok(not ok_ and line:find('Use: coop closet wear'), line)
        ok_, line = C.closet('bogus')
        ok(not ok_ and line:find('Use: coop closet'), line)
        ok_, line = C.closet('off')
        ok(ok_ and line == 'closet: off', line)
        -- As main/commands.lua's M.run calls it: six words, nil-padded.
        ok_, line = C.closet('wear', 'AiK_CH46_xSH_14462', nil, nil, nil, nil)
        ok(ok_, line)
        ok_, line = C.closet('status', nil, nil, nil, nil, nil)
        ok(ok_ and line:find('^closet: 8 pieces'), line)
        ok_, line = C.closet('off', nil, nil, nil, nil, nil)
        ok(ok_ and line == 'closet: off', line)
        ok_, line = C.closet('fits', nil, nil, nil, nil, nil)
        ok(ok_, line)
        ok_, line = C.closet('wear', nil, nil, nil, nil, nil)
        ok(not ok_ and line:find('Use: coop closet wear'), line)
        ok_, line = C.closet(nil, nil, nil, nil, nil, nil)
        ok(ok_ and line == 'closet: nothing worn', line)
    end,
    two_body_changes_in_a_row_leave_one_added_mesh = function()
        local w = world()
        assert(w.d.wear({{fit = 'AiK_CH27_14595', slots = {'Chest'}}, {fit = 'AiK_CH46_xSH_14462',
            slots = {'Shoes'}}}))
        -- A map load: the added mesh stays for once, the game sets her body to one mesh, then to her suit.
        w.eve.Mesh:SetSkeletalMesh(w.assets[TACHY .. 'x'] or w.assets[OWN])
        second(w) second(w)
        eq(#w.eve.comps, 2, 'mixed again')
        w.eve.Mesh:SetSkeletalMesh(w.assets[OWN])
        second(w) second(w)
        eq(#w.eve.comps, 2, 'still one added mesh, not two')
        -- Wearing another mix sweeps any added mesh of the old one.
        assert(w.d.wear({{fit = 'AiK_CH46_xSH_14462'}}))
        eq(#w.eve.comps, 1, 'the whole outfit alone: no added mesh left')
        w.d.off()
        eq(w.eve.Mesh.SkeletalMesh.path, OWN) eq(#w.eve.comps, 1)
    end,
}
run('dress_test', tests)
