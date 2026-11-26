-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop closet wear (closet/dress.lua) over fake UE4SS objects: the plan (the shoes' outfit on the body with its skin,
-- one added mesh per other outfit, covered skin hidden, the refusals), the mix on EVE, her own look kept and given
-- back by off and by the next Lua load, and the watchdog: Tachy Mode's suit pauses the mix, a changed look for 2 s gets
-- it again (an outside one becomes her own look, a closet mesh never does; after off nothing is watched), a section
-- the game showed again is hidden again. The body rule: a single-skin body switched under foreign
-- gloves (never under its own covering pieces), a picked BaseBody never switched, the modes, nails under foreign
-- gloves, sections hidden by material slot.
-- The words of coop closet (closet/commands.lua).
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
local addresses = 0
local function component(path, owner)
    local c = obj(path)
    c.hidden, c.mats, c.owner = {}, {}, owner
    addresses = addresses + 1
    c.addr = addresses
    function c:GetAddress() return self.addr end
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

-- A new table at each read of what UE4SS hands as a new wrapper: the same object, another identity.
local function wrapper(real)
    return setmetatable({}, {__index = function(_, k)
        local v = real[k]
        if type(v) == 'function' then return function(_, ...) return v(real, ...) end end
        return v
    end, __newindex = function(_, k, v) real[k] = v end})
end
-- wrapped: eve.Mesh is a new wrapper at each read, as in UE4SS.
local function world(wrapped)
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
    if wrapped then
        local body = eve.Mesh
        eve.Mesh = nil
        setmetatable(eve, {__index = function(_, k) if k == 'Mesh' then return wrapper(body) end end})
    end
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

local A = {{fit = 'AiK_CH27_14595', slots = {'Chest'}}, {fit = 'AiK_CH46_xSH_14462', slots = {'Shoes'}}}
local B = {{fit = 'AiK_CH46_xSH_14462'}}
local MAID, NINJA = 'AiK_CH27_14595', 'AiK_CH46_xSH_14462' -- Ocean Maid (one skin slot), Kunoichi Shadow (three).
-- Ocean Maid's nails (and shoes) with Kunoichi's gloves: Ocean Maid's single skin slot cannot hide the arms.
local GLOVES = {{fit = MAID, slots = {'Fingernails'}}, {fit = NINJA, slots = {'Gloves'}}}

local tests = {
    preview_keeps_the_confirmed_words = function()
        local w = world()
        assert(w.d.wear(A))
        local ok_, line, plan = w.d.preview(B)
        ok(ok_, line)
        eq(plan and plan.body.fit, 'AiK_CH46_xSH_14462', 'the plan for the menu (its body switch notice)')
        ok(w.d.previewing())
        eq(fields(w.file)[5], 'AiK_CH27_14595:Chest AiK_CH46_xSH_14462:Shoes', 'the file holds the confirmed words')
        eq(w.eve.Mesh.SkeletalMesh.path, KS, 'EVE wears B')
        eq(#w.eve.comps, 1, 'B has no added mesh')
        ok(logged(w, 'preview:'))
        ok(w.d.preview(B)) -- A second preview keeps the first confirmed look.
        eq(fields(w.file)[5], 'AiK_CH27_14595:Chest AiK_CH46_xSH_14462:Shoes')
    end,
    revert_wears_the_confirmed_look_again = function()
        local w = world()
        assert(w.d.wear(A))
        assert(w.d.preview(B))
        local ok_, line = w.d.revert()
        ok(ok_, line)
        ok(not w.d.previewing())
        eq(#w.eve.comps, 2, 'A again, one added mesh')
        eq(w.d.choices()[1].fit, 'AiK_CH27_14595')
        eq(fields(w.file)[5], 'AiK_CH27_14595:Chest AiK_CH46_xSH_14462:Shoes')
    end,
    a_revert_without_eve_keeps_the_confirmed_words = function()
        local w = world()
        assert(w.d.wear(A))
        assert(w.d.preview(B))
        local eve = w.eve
        w.eve = nil -- A map change: no EVE.
        local ok_, line = w.d.revert()
        eq(ok_, false, 'the revert failed')
        ok(line:find('no EVE', 1, true), line)
        eq(fields(w.file)[5], 'AiK_CH27_14595:Chest AiK_CH46_xSH_14462:Shoes', 'the file keeps the confirmed words')
        ok(w.d.previewing(), 'still previewing')
        eq(w.d.choices()[1].fit, 'AiK_CH46_xSH_14462', 'the preview stays')
        ok(logged(w, 'revert:'), 'logged')
        w.eve = eve
        assert(w.d.revert())
        ok(not w.d.previewing())
        eq(#w.eve.comps, 2, 'A again')
    end,
    a_revert_to_a_look_that_no_longer_plans_gives_her_own_look = function()
        local w = world()
        assert(w.d.wear(A))
        assert(w.d.preview(B))
        local Fits = require('closet.fits')
        local get = Fits.get
        Fits.get = function(id) if id ~= 'AiK_CH27_14595' then return get(id) end end
        local done, why = pcall(w.d.revert)
        Fits.get = get
        ok(done, why)
        eq(w.eve.Mesh.SkeletalMesh.path, OWN) eq(#w.eve.comps, 1) eq(w.file, nil)
        ok(not w.d.previewing() and not w.d.worn())
    end,
    an_empty_preview_shows_her_own_look = function()
        local w = world()
        assert(w.d.wear(A))
        local ok_, line = w.d.preview({})
        ok(ok_, line)
        eq(w.eve.Mesh.SkeletalMesh.path, OWN, 'her own body mesh') eq(#w.eve.comps, 1, 'no added mesh')
        ok(w.d.previewing(), 'previewing')
        same(w.d.choices(), {}, 'nothing chosen')
        eq(fields(w.file)[5], 'AiK_CH27_14595:Chest AiK_CH46_xSH_14462:Shoes', 'the file keeps the confirmed words')
        eq(fields(w.file)[4], '', 'no added mesh to sweep')
        local ticked, why = pcall(function() second(w) second(w) second(w) end)
        ok(ticked, 'the watchdog runs: ' .. tostring(why))
        ok(w.d.status():find('own look', 1, true), w.d.status())
        ok(w.d.previewing(), 'still previewing after the ticks')
        -- A preview after it, then the revert: the confirmed look again.
        assert(w.d.preview(B))
        assert(w.d.preview({}))
        assert(w.d.revert())
        ok(not w.d.previewing())
        eq(#w.eve.comps, 2, 'A again') eq(w.d.choices()[1].fit, 'AiK_CH27_14595')
    end,
    confirming_an_empty_preview_clears_the_file = function()
        local w = world()
        assert(w.d.wear(A))
        assert(w.d.preview({}))
        local ok_, line = w.d.confirm()
        ok(ok_, line)
        eq(w.file, nil, 'the file cleared')
        ok(not w.d.previewing() and not w.d.worn(), 'nothing worn')
        eq(w.eve.Mesh.SkeletalMesh.path, OWN) eq(#w.eve.comps, 1)
    end,
    a_reload_mid_empty_preview_gives_the_confirmed_look = function()
        local w = world()
        assert(w.d.wear(A))
        assert(w.d.preview({}))
        w.d = w.new()
        second(w)
        eq(w.eve.Mesh.SkeletalMesh.path, KS, 'A: the shoes outfit on the body')
        eq(#w.eve.comps, 2, 'one added mesh')
        ok(not w.d.previewing())
    end,
    revert_with_nothing_confirmed_gives_her_own_look_and_clears_the_file = function()
        local w = world()
        assert(w.d.preview(A))
        ok(w.d.previewing())
        eq(fields(w.file)[5], '', 'nothing confirmed')
        assert(w.d.revert())
        eq(w.eve.Mesh.SkeletalMesh.path, OWN) eq(#w.eve.comps, 1) eq(w.file, nil)
        ok(not w.d.previewing() and not w.d.worn())
    end,
    confirm_saves_the_previewed_words = function()
        local w = world()
        assert(w.d.wear(A))
        assert(w.d.preview(B))
        local ok_, line = w.d.confirm()
        ok(ok_, line)
        ok(not w.d.previewing())
        eq(fields(w.file)[5], 'AiK_CH46_xSH_14462')
        ok(w.d.revert()) -- Nothing to revert now.
        eq(w.eve.Mesh.SkeletalMesh.path, KS)
        local ok2, line2 = w.d.confirm()
        ok(ok2 and line2 == 'closet: nothing to confirm', line2)
    end,
    a_reload_mid_preview_gives_the_confirmed_look = function()
        local w = world()
        assert(w.d.wear(A))
        assert(w.d.preview({{fit = 'AiK_CH27_14595'}}))
        w.d = w.new() -- A new Lua state reads the file.
        second(w)
        eq(w.eve.Mesh.SkeletalMesh.path, KS, 'A: the shoes outfit on the body')
        eq(#w.eve.comps, 2, 'one added mesh')
        ok(not w.d.previewing())
    end,
    a_map_change_mid_preview_keeps_the_preview_going = function()
        local w = world()
        assert(w.d.wear(A))
        assert(w.d.preview(B))
        w.eve.Mesh:SetSkeletalMesh(w.assets[OWN])
        second(w) second(w)
        ok(w.d.previewing(), 'still previewing after the re-mix')
        eq(w.eve.Mesh.SkeletalMesh.path, KS)
        assert(w.d.revert())
        eq(#w.eve.comps, 2) eq(w.d.choices()[1].fit, 'AiK_CH27_14595')
    end,
    wear_and_off_end_the_preview = function()
        local w = world()
        assert(w.d.wear(A))
        assert(w.d.preview(B))
        assert(w.d.wear(A))
        ok(not w.d.previewing())
        assert(w.d.preview(B))
        w.d.off()
        ok(not w.d.previewing())
        local ok_, line = w.d.revert()
        ok(ok_ and line:find('nothing'), line)
        eq(w.eve.Mesh.SkeletalMesh.path, OWN)
    end,
    game_look_names_the_tachy_suit = function()
        local w = world()
        eq(w.d.game_look(), nil)
        w.eve.Mesh:SetSkeletalMesh(w.assets[TACHY])
        eq(w.d.game_look(), TACHY)
    end,
    installed_is_cached_per_fit = function()
        local w = world()
        local finds, real = 0, StaticFindObject
        StaticFindObject = function(path) finds = finds + 1; return real(path) end
        ok(w.d.installed('AiK_CH27_14595'))
        ok(w.d.installed('AiK_CH27_14595'))
        eq(finds, 1, 'found once')
        ok(not w.d.installed('nope'), 'unknown fit')
        w.assets[KS] = nil
        ok(not w.d.installed('AiK_CH46_xSH_14462'), 'a missing mesh')
        w.assets[KS] = mesh(KS, 44)
        ok(not w.d.installed('AiK_CH46_xSH_14462'), 'cached')
    end,
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
    -- Stellar Closet keeps control over CNS (design 9): a look changed from outside while one is kept is worn again.
    -- A change the closet made itself (a preview, its own mesh still on her body) is never taken as her own look.
    an_outside_body_change_remixes_a_kept_look = function()
        local w = world()
        local function mixes()
            local n = 0
            for _, line in ipairs(w.log) do if line:find('mix again', 1, true) then n = n + 1 end end
            return n
        end
        assert(w.d.wear(A))
        local other = '/Game/Art/Character/PC/CH_P_EVE_31/CH_P_EVE_31.CH_P_EVE_31'
        w.assets[other] = mesh(other, 6)
        w.eve.Mesh:SetSkeletalMesh(w.assets[other]) -- CNS puts its outfit on her body.
        second(w)
        eq(w.eve.Mesh.SkeletalMesh.path, other, 'one second: wait')
        second(w)
        eq(w.eve.Mesh.SkeletalMesh.path, KS, 'the kept look again') eq(#w.eve.comps, 2, 'one added mesh')
        eq(mixes(), 1, 'mixed again once')
        -- The closet's own preview is not an outside change.
        assert(w.d.preview({{fit = MAID}}))
        second(w) second(w) second(w)
        eq(mixes(), 1, 'the preview is left alone') eq(w.eve.Mesh.SkeletalMesh.path, OM)
        assert(w.d.revert())
        -- Its added mesh gone while her body still wears the closet's mesh: mixed again, the closet's mesh is not hers.
        w.eve.comps[2]:K2_DestroyComponent()
        second(w) second(w)
        eq(mixes(), 2, 'mixed again') eq(#w.eve.comps, 2, 'the added mesh back')
        eq(fields(w.file)[2], other, 'her own look kept, not the closet mesh')
        w.d.off()
        eq(w.eve.Mesh.SkeletalMesh.path, other, 'off gives back the outside look, never a closet mesh')
    end,
    -- UE4SS hands a new wrapper at each read of eve.Mesh: the sweep of added meshes tells her body by its address, so it
    -- never removes her body, even when something outside put an added outfit's mesh on it (seen 26 Nov 2026).
    the_sweep_never_removes_her_body = function()
        local w = world(true)
        assert(w.d.wear(GLOVES)) -- Kunoichi's body (switched), Ocean Maid's nails as the added mesh.
        eq(w.eve.Mesh.SkeletalMesh.path, KS)
        w.eve.Mesh:SetSkeletalMesh(w.assets[OM])
        second(w) second(w)
        ok(w.eve.Mesh:IsValid(), 'her body is never removed')
        eq(w.eve.Mesh.SkeletalMesh.path, KS, 'the look again') eq(#w.eve.comps, 2, 'her body and one added mesh')
    end,
    -- Something outside that undoes every mix (CNS put Ocean Maid back on her body each second, 26 Nov 2026): after
    -- FIGHT.mixes mixes in FIGHT.within s the closet stops fighting. A body the look holds is worn as the body.
    an_outside_fight_over_the_body_ends = function()
        local w = world()
        local function mixes()
            local n = 0
            for _, line in ipairs(w.log) do if line:find('mix again', 1, true) then n = n + 1 end end
            return n
        end
        assert(w.d.wear(GLOVES))
        for _ = 1, 30 do
            if w.eve.Mesh.SkeletalMesh.path ~= OM then w.eve.Mesh:SetSkeletalMesh(w.assets[OM]) end
            second(w)
        end
        eq(mixes(), w.Dress.FIGHT.mixes, 'the mixes stop')
        ok(logged(w, 'keeps putting AiK_CH27_14595 on her body'), 'the log says why')
        eq(w.eve.Mesh.SkeletalMesh.path, OM, 'Ocean Maid is the body') eq(#w.eve.comps, 2, 'Kunoichi gloves added')
        eq(w.d.plan().body.fit, MAID, 'no switch') ok(w.d.plan().clips, 'the menu warns of the clipping arms')
        ok(w.file:find('AiK_CH27_14595:Fingernails AiK_CH46_xSH_14462:Gloves', 1, true), 'the words stay the picks')
        assert(w.d.wear(GLOVES)) -- A new wear starts over with the body rule.
        eq(w.eve.Mesh.SkeletalMesh.path, KS)
    end,
    an_outside_fight_with_another_body_stops_the_mix = function()
        local w = world()
        local other = '/Game/Art/Character/PC/CH_P_EVE_31/CH_P_EVE_31.CH_P_EVE_31'
        w.assets[other] = mesh(other, 6)
        assert(w.d.wear(A))
        for _ = 1, 30 do
            if w.eve.Mesh.SkeletalMesh.path ~= other then w.eve.Mesh:SetSkeletalMesh(w.assets[other]) end
            second(w)
        end
        local n = 0
        for _, line in ipairs(w.log) do if line:find('mix again', 1, true) then n = n + 1 end end
        eq(n, w.Dress.FIGHT.mixes, 'the mixes stop')
        ok(logged(w, 'the closet stops mixing'), 'the log says why')
        eq(w.eve.Mesh.SkeletalMesh.path, other, 'the outside body stays')
        ok(w.file:find('AiK_CH27_14595:Chest AiK_CH46_xSH_14462:Shoes', 1, true), 'the look stays kept')
    end,
    -- A picked body (the Body row) is never switched, so a fight over it cannot be ended by wearing the outside body:
    -- the mix stops, the added meshes hidden so she never wears two outfits at once.
    an_outside_fight_over_a_picked_body_stops_the_mix = function()
        local w = world()
        local picked = {{fit = NINJA, slots = {'BaseBody', 'Gloves'}}, {fit = MAID, slots = {'Fingernails'}}}
        assert(w.d.wear(picked))
        for _ = 1, 30 do
            if w.eve.Mesh.SkeletalMesh.path ~= OM then w.eve.Mesh:SetSkeletalMesh(w.assets[OM]) end
            second(w)
        end
        local n = 0
        for _, line in ipairs(w.log) do if line:find('mix again', 1, true) then n = n + 1 end end
        eq(n, w.Dress.FIGHT.mixes, 'the mixes stop') ok(not logged(w, 'keeps putting'), 'no false line')
        ok(logged(w, 'the closet stops mixing until the next wear or preview'))
        eq(w.eve.comps[2].hidden_in_game, true, 'the added mesh hidden')
        ok(w.d.status():find('stopped', 1, true), 'status says so')
    end,
    -- Outside changes far apart (a map load now, Tachy Mode later) are no fight, however many.
    outside_changes_far_apart_are_no_fight = function()
        local w = world()
        local other = '/Game/Art/Character/PC/CH_P_EVE_31/CH_P_EVE_31.CH_P_EVE_31'
        w.assets[other] = mesh(other, 6)
        assert(w.d.wear(GLOVES))
        for _ = 1, 8 do
            w.eve.Mesh:SetSkeletalMesh(w.assets[other])
            second(w) second(w)
            w.now = w.now + w.Dress.FIGHT.within
        end
        eq(w.eve.Mesh.SkeletalMesh.path, KS, 'the look again') ok(not logged(w, 'stops mixing'))
    end,
    -- A wear or a preview starts the count over.
    a_wear_starts_the_fight_count_over = function()
        local w = world()
        local other = '/Game/Art/Character/PC/CH_P_EVE_31/CH_P_EVE_31.CH_P_EVE_31'
        w.assets[other] = mesh(other, 6)
        assert(w.d.wear(GLOVES))
        local function change() w.eve.Mesh:SetSkeletalMesh(w.assets[other]); second(w) second(w) end
        for _ = 1, w.Dress.FIGHT.mixes - 1 do change() end
        assert(w.d.wear(GLOVES))
        change() change()
        ok(not logged(w, 'stops mixing'), 'counted from the wear') eq(w.eve.Mesh.SkeletalMesh.path, KS)
        assert(w.d.preview(GLOVES))
        for _ = 1, w.Dress.FIGHT.mixes - 1 do change() end
        ok(not logged(w, 'stops mixing'), 'counted from the preview')
    end,
    -- off on an EVE whose body component is gone still removes the closet's added meshes.
    off_without_her_body_removes_the_added_meshes = function()
        local w = world()
        assert(w.d.wear(GLOVES))
        w.eve.comps[1].alive = false
        w.d.off()
        eq(#w.eve.comps, 1, 'only the dead body stays') eq(w.file, nil)
    end,
    -- A map load sets her body twice: two mixes close together are no fight.
    two_quick_outside_changes_are_no_fight = function()
        local w = world()
        assert(w.d.wear(GLOVES))
        local other = '/Game/Art/Character/PC/CH_P_EVE_31/CH_P_EVE_31.CH_P_EVE_31'
        w.assets[other] = mesh(other, 6)
        for _ = 1, 2 do w.eve.Mesh:SetSkeletalMesh(w.assets[other]); second(w) second(w) end
        eq(w.eve.Mesh.SkeletalMesh.path, KS, 'the look again') ok(not logged(w, 'stops mixing'))
        ok(not logged(w, 'keeps putting'))
    end,
    after_off_an_outside_change_is_left_alone = function()
        local w = world()
        assert(w.d.wear(A))
        assert(w.d.preview(B)) -- Reset Stellar Closet from the menu: coop closet off mid-preview.
        w.d.off()
        local other = '/Game/Art/Character/PC/CH_P_EVE_31/CH_P_EVE_31.CH_P_EVE_31'
        w.assets[other] = mesh(other, 6)
        w.eve.Mesh:SetSkeletalMesh(w.assets[other])
        second(w) second(w) second(w)
        eq(w.eve.Mesh.SkeletalMesh.path, other, 'the outside look stays') eq(#w.eve.comps, 1, 'nothing added')
        eq(w.file, nil, 'nothing kept') ok(not logged(w, 'mix again'), 'no mix')
        w.d = w.new() -- The next Lua load wears nothing either.
        second(w) second(w)
        eq(w.eve.Mesh.SkeletalMesh.path, other, 'still the outside look after a reload')
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
    foreign_gloves_switch_a_single_skin_body = function()
        local Dress = require('closet.dress')
        local plan = assert(Dress.plan(GLOVES))
        eq(plan.body.fit, NINJA, 'the body whose skin hides arms and hands') eq(plan.switched, NINJA)
        eq(plan.clips, nil, 'nothing clips')
        ok(plan.body.show[0] and plan.body.show[16] and plan.body.show[17], 'body skin and gloves')
        ok(not plan.body.show[1] and not plan.body.show[2], 'no arms or hands skin under the gloves')
        eq(plan.parts, 1) eq(plan.added[1].fit, MAID)
        ok(not plan.added[1].show[0], 'Ocean Maid nails hidden under the gloves')
        ok(not plan.added[1].show[14], 'no Ocean Maid skin')
        -- Her own gloves over her own nails: the nails stay (Kunoichi's nails are off by default, so picked).
        plan = assert(Dress.plan({{fit = NINJA, slots = {'Gloves', 'Fingernails'}}}))
        ok(plan.body.show[25], 'own nails under own gloves stay') eq(plan.switched, nil)
    end,
    own_covering_pieces_never_switch_or_clip = function()
        local Dress, Fits = require('closet.dress'), require('closet.fits')
        -- A stub fit map: Ocean Maid's own Gloves cover the arms and hands, as the next fit maps may say.
        local maid = {}
        for k, v in pairs(Fits.get(MAID)) do maid[k] = v end
        maid.Pieces = {}
        for i, p in ipairs(Fits.get(MAID).Pieces) do
            maid.Pieces[i] = p.Slot ~= 'Gloves' and p or
                {Slot = 'Gloves', Name = p.Name, Materials = p.Materials, Covers = {'ArmUpper', 'Forearm', 'Hand'}}
        end
        local by_id = {[MAID] = maid, [NINJA] = Fits.get(NINJA)}
        local fits = {get = function(id) return by_id[id] end}
        function fits.piece(id, slot)
            for _, p in ipairs(by_id[id] and by_id[id].Pieces or {}) do if p.Slot == slot then return p end end
        end
        local plan = assert(Dress.plan({{fit = MAID}}, fits))
        eq(plan.body.fit, MAID) eq(plan.switched, nil) eq(plan.clips, nil, 'the outfit worn as is: no clip warning')
        plan = assert(Dress.plan({{fit = MAID}, {fit = NINJA, slots = {'BraceletL'}}}, fits))
        eq(plan.body.fit, MAID, 'no gloves or shoes of another outfit: no switch') eq(plan.switched, nil)
        eq(plan.clips, nil)
        -- Gloves of another outfit still switch the body.
        plan = assert(Dress.plan({{fit = MAID, slots = {'Chest', 'Shoes'}}, {fit = NINJA, slots = {'Gloves'}}}, fits))
        eq(plan.body.fit, NINJA) eq(plan.switched, NINJA) eq(plan.clips, nil)
    end,
    a_picked_body_is_never_switched = function()
        local Dress = require('closet.dress')
        local picked = {{fit = MAID, slots = {'BaseBody'}}, {fit = NINJA, slots = {'Gloves'}}}
        local plan = assert(Dress.plan(picked))
        eq(plan.body.fit, MAID, 'the picked body') eq(plan.switched, nil)
        same(plan.clips, {'ArmUpper', 'Forearm', 'Hand'}, 'the regions that clip')
        ok(plan.body.show[14], 'its one skin slot shows') eq(plan.pieces, 1) eq(plan.parts, 1)
        eq(assert(Dress.plan(picked, nil, NINJA)).body.fit, MAID, 'a forced body does not beat a picked one')
        plan = assert(Dress.plan({{fit = MAID, slots = {'BaseBody'}}, {fit = NINJA, slots = {'Gloves', 'Shoes'}}}))
        eq(plan.body.fit, MAID, 'the picked body beats the shoes')
    end,
    a_switched_body_is_not_saved = function()
        local w = world()
        eq(w.d.plan(), nil, 'nothing worn: no plan')
        assert(w.d.wear(GLOVES))
        eq(w.eve.Mesh.SkeletalMesh.path, KS, 'the body switched to Kunoichi')
        eq(w.d.plan().switched, NINJA, 'the plan on EVE names the switch (the menu shows it)')
        eq(fields(w.file)[5], w.Dress.words(GLOVES), 'the file holds the picks only')
        w.d = w.new() -- A reload computes the switch again.
        second(w)
        eq(w.eve.Mesh.SkeletalMesh.path, KS) eq(fields(w.file)[5], w.Dress.words(GLOVES))
    end,
    basebody_needs_skin = function()
        local Dress = require('closet.dress')
        local fits = {get = function(id) return id == 'Bare' and {Mesh = '/Game/Bare.Bare', Pieces = {}} or nil end,
            piece = function() return nil end}
        local plan, why = Dress.plan({{fit = 'Bare', slots = {'BaseBody'}}}, fits)
        eq(plan, nil) ok(why and why:find('Bare has no skin', 1, true), why)
        plan, why = Dress.plan({{fit = MAID, slots = {'BaseBody'}}, {fit = NINJA, slots = {'BaseBody'}}})
        eq(plan, nil) ok(why and why:find('BaseBody is worn twice', 1, true), why)
        plan = assert(Dress.plan({{fit = NINJA, slots = {'BaseBody'}}}))
        eq(plan.pieces, 0) ok(plan.body.show[0] and plan.body.show[1] and not plan.body.show[19], 'its skin only')
    end,
    sections_hide_by_slot = function()
        local w = world()
        local calls, real = {}, w.eve.Mesh.ShowMaterialSection
        w.eve.Mesh.ShowMaterialSection = function(c, i, section, show, lod)
            calls[#calls + 1] = {i, section, show, lod}
            return real(c, i, section, show, lod)
        end
        assert(w.d.wear({{fit = NINJA, slots = {'Shoes'}}}))
        ok(#calls > 0, 'sections hidden')
        local seen = {}
        for _, c in ipairs(calls) do
            eq(c[2], -1, 'the slot itself, no section index to remap') eq(c[3], false)
            seen[c[4] .. ':' .. c[1]] = true
        end
        ok(seen['0:3'] and seen['1:3'], 'the jacket slot on every LOD')
    end,
    body_modes_change_the_rule = function()
        local Dress = require('closet.dress')
        same(Dress.BODY_MODES, {'auto', 'shoes', 'first'})
        local look = {{fit = NINJA, slots = {'Gloves'}}, {fit = MAID, slots = {'Shoes', 'Fingernails'}}}
        eq(assert(Dress.plan(look)).body.fit, NINJA, 'auto by default')
        eq(assert(Dress.plan(look, nil, 'auto')).switched, NINJA)
        local plan = assert(Dress.plan(look, nil, 'shoes'))
        eq(plan.body.fit, MAID, "today's rule: the shoes' outfit") eq(plan.switched, nil)
        same(plan.clips, {'ArmUpper', 'Forearm', 'Hand'})
        plan = assert(Dress.plan({{fit = MAID, slots = {'Chest'}}, {fit = NINJA, slots = {'Shoes'}}}, nil, 'first'))
        eq(plan.body.fit, MAID, 'the first choice')
        plan = assert(Dress.plan({{fit = MAID}}, nil, NINJA))
        eq(plan.body.fit, NINJA, 'a forced body, even one not in the look') eq(plan.switched, nil)
        eq(plan.parts, 1) eq(plan.added[1].fit, MAID)
        ok(plan.body.show[0] and not plan.body.show[19], 'its skin only')
        local w = world()
        local good, why = w.d.body_mode('nope')
        eq(good, false) ok(why:find('no fit map for nope', 1, true), why)
        ok(w.d.body_mode('shoes'))
        assert(w.d.wear(look))
        eq(w.eve.Mesh.SkeletalMesh.path, OM, 'the shoes rule for this Lua load')
        ok(w.d.body_mode(NINJA))
        assert(w.d.wear({{fit = MAID, slots = {'Chest', 'Shoes'}}}))
        eq(w.eve.Mesh.SkeletalMesh.path, KS, 'the forced body') eq(#w.eve.comps, 2)
        ok(w.d.body_mode('auto'))
    end,
    body_and_skin_words = function()
        local w = world()
        local Commands = require('closet.commands')
        local C = Commands.new({dress = w.d, fits = require('closet.fits')})
        local USE = Commands.USE
        ok(USE:find('body <auto|shoes|first|<fit>>', 1, true) and USE:find('skin <fit> <slot> on|off', 1, true), USE)
        local good, line = C.closet('body', 'first', nil, nil, nil, nil)
        ok(good, line)
        good, line = C.closet('body', 'nope', nil, nil, nil, nil)
        eq(good, false) ok(line:find('no fit map', 1, true), line)
        good, line = C.closet('skin', NINJA, '3', 'off', nil, nil)
        eq(good, false) ok(line:find('nothing worn', 1, true), line)
        assert(w.d.wear(A))
        eq(w.eve.Mesh.SkeletalMesh.path, OM, 'body first: Ocean Maid')
        ok(C.closet('body', 'auto', nil, nil, nil, nil))
        assert(w.d.wear(A)) -- Kunoichi's shoes on the body, Ocean Maid's top on an added mesh.
        ok(w.eve.Mesh.hidden['0:3'] and not w.eve.Mesh.hidden['0:1'], 'the plan: no jacket, bare arms')
        good, line = C.closet('skin', NINJA, '3', 'on', nil, nil)
        ok(good, line) ok(not w.eve.Mesh.hidden['0:3'] and not w.eve.Mesh.hidden['1:3'], 'slot 3 shown on every LOD')
        good, line = C.closet('skin', NINJA, '1', 'off', nil, nil)
        ok(good, line) ok(w.eve.Mesh.hidden['0:1'] and w.eve.Mesh.hidden['1:1'], 'slot 1 hidden on every LOD')
        second(w)
        ok(not w.eve.Mesh.hidden['0:3'] and not logged(w, 'hidden again'), 'the watchdog keeps the shown slot')
        local added = w.eve.comps[2]
        good, line = C.closet('skin', MAID, '15', 'off', nil, nil)
        ok(good, line) ok(added.hidden['0:15'] and added.hidden['1:15'], "Ocean Maid's added mesh")
        good, line = C.closet('skin', NINJA, '44', 'off', nil, nil)
        eq(good, false) ok(line:find('no material slot 44', 1, true), line)
        good, line = C.closet('skin', 'AiK_Other', '3', 'off', nil, nil)
        eq(good, false) ok(line:find('not worn', 1, true), line)
        w.eve.Mesh:SetSkeletalMesh(w.assets[TACHY]) -- Tachy Mode pauses the mix: her body wears the game's suit.
        second(w)
        good, line = C.closet('skin', NINJA, '0', 'off', nil, nil)
        eq(good, false) ok(line:find('paused', 1, true), line) eq(w.eve.Mesh.hidden['0:0'], nil, "the suit's slot 0")
        for _, bad in ipairs({{'body'}, {'body', 'first', 'x'}, {'skin'}, {'skin', NINJA, '3'},
            {'skin', NINJA, 'x', 'off'}, {'skin', NINJA, '3', 'maybe'}, {'skin', NINJA, '3', 'off', 'more'}}) do
            eq(select(2, C.closet(table.unpack(bad))), USE, table.concat(bad, ' '))
        end
        assert(w.d.wear(A)) -- The next wear clears the tries.
        ok(w.eve.Mesh.hidden['0:1'] == nil and w.eve.Mesh.hidden['0:3'], 'the plan again')
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
    -- closet/colour.lua puts its palette on again when applied() changes: at every apply (wear, preview, revert, the
    -- watchdog's mix again), her own look previewed and off.
    applied_grows_with_every_change_of_her_look = function()
        local w = world()
        eq(w.d.applied(), 0, 'nothing yet')
        assert(w.d.wear(A))
        eq(w.d.applied(), 1, 'a wear')
        ok(not w.d.wear({{fit = 'nope'}}))
        eq(w.d.applied(), 1, 'a wear that fails changes nothing')
        assert(w.d.preview(B))
        eq(w.d.applied(), 2, 'a preview')
        assert(w.d.preview({}))
        eq(w.d.applied(), 3, 'her own look previewed')
        assert(w.d.revert())
        eq(w.d.applied(), 4, 'the confirmed look worn again')
        w.eve.Mesh:SetSkeletalMesh(w.assets[OWN])
        second(w) second(w)
        eq(w.eve.Mesh.SkeletalMesh.path, KS, 'mixed again')
        eq(w.d.applied(), 5, 'the watchdog\'s mix again')
        w.d.off()
        eq(w.d.applied(), 6, 'off')
    end,
    -- The worn components with their shown material slots and the closet slot each belongs to (closet/colour.lua's
    -- read): her body first, its skin slots as BaseBody; nil while the mix is paused.
    parts_list_the_shown_slots_and_their_closet_slot = function()
        local w = world()
        same(w.d.parts(), {}, 'nothing worn: no part')
        assert(w.d.wear(A)) -- Kunoichi's boots on her body with its skin, Ocean Maid's top on an added mesh.
        local parts = w.d.parts()
        eq(#parts, 2, 'her body, then the added mesh')
        ok(parts[1].c == w.eve.Mesh, 'her body first') ok(parts[2].c == w.eve.comps[2], 'the added mesh')
        same(parts[1].slots, {[0] = 'BaseBody', [1] = 'BaseBody', [2] = 'BaseBody', [19] = 'Shoes', [20] = 'Shoes',
            [33] = 'Shoes', [35] = 'Shoes'}, 'the boots and the skin')
        local top = {}
        for _, i in ipairs({15, 44, 19, 47, 18, 16, 29, 30, 20, 22, 21, 31}) do top[i] = 'Chest' end
        same(parts[2].slots, top, 'the top')
        assert(w.d.skin(NINJA, 1, false))
        eq(w.d.parts()[1].slots[1], nil, 'a slot coop closet skin hides is not listed')
        -- Ocean Maid's nails under Kunoichi's gloves are hidden: not listed.
        assert(w.d.wear(GLOVES))
        parts = w.d.parts()
        same(parts[1].slots, {[0] = 'BaseBody', [16] = 'Gloves', [17] = 'Gloves'}, 'gloves, no arms or hands skin')
        same(parts[2].slots, {}, 'the nails hidden')
        w.eve.Mesh:SetSkeletalMesh(w.assets[TACHY])
        second(w)
        eq(w.d.parts(), nil, 'paused by Tachy Mode: nil')
        w.d.off()
        same(w.d.parts(), {}, 'off: nothing')
    end,
}
run('dress_test', tests)
