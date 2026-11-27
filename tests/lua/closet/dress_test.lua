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
    -- As FUN_14411a4f0 (Ghidra, build 26123051): the mesh it wears again returns at once; a new mesh leaves the
    -- overrides (OverrideMaterials, self.mats) as they are.
    function c:SetSkeletalMesh(m)
        if m == self.SkeletalMesh then return end
        self.SkeletalMesh = m; self.hidden = {}
    end
    -- As FUN_1440df060: the array grows to the index; a nil material is stored as a null entry.
    c.overrides = 0
    function c:SetMaterial(i, m)
        self.mats[i] = m
        self.overrides = math.max(self.overrides, i + 1)
    end
    c.OverrideMaterials = {ForEach = function(_, f)
        for i = 0, c.overrides - 1 do f(i + 1, {get = function() return c.mats[i] end}) end
    end}
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

-- Pack suits (closet/fits.lua's Fits.use over a catalogue): P has two variants, the first hiding slot 1 and its
-- toggle on slot 3 off by default; GONE's mesh is not there.
local PV1, PV2 = '/Game/P/V1.V1', '/Game/P/V2.V2'
local function pack_item(id, mesh_path)
    return {UniqueFitID = id, DisplayName = id, Slot = 'FullOutfit', File = '~mods\\P\\p.dekcns.json',
        Variants = {{Mesh = mesh_path or PV1, HiddenMats = {1}}, {Mesh = PV2, HiddenMats = {}}},
        UserConfigs = {MaterialToggles = {{MaterialIndex = 3, Value = false}, {MaterialIndex = 4, Value = true}}}}
end
-- f(w) on a world with the pack suits in the catalogue, which goes again after.
local function with_packs(f)
    local Fits = require('closet.fits')
    local w = world()
    w.assets[PV1], w.assets[PV2] = mesh(PV1, 6), mesh(PV2, 6)
    Fits.use({['p.suit'] = pack_item('p.suit'), ['gone.suit'] = pack_item('gone.suit', '/Game/Gone/G.G')})
    local good, why = pcall(f, w)
    Fits.use(nil)
    ok(good, why)
end

-- A dress on w whose plans take the toggles in t (closet/options.lua's toggles()).
local function toggled(w, t)
    return w.Dress.new({log = function(m) w.log[#w.log + 1] = m end, store = w.store,
        clock = function() return w.now end, toggles = function() return t end})
end
-- Hidden material slots of c at LOD 0, sorted.
local function hidden_at(c)
    local out = {}
    for k in pairs(c.hidden) do
        local i = k:match('^0:(%d+)$')
        if i then out[#out + 1] = tonumber(i) end
    end
    table.sort(out)
    return out
end

-- The slots of c whose override holds a material (OverrideMaterials, as the ghost's capture reads it), rising.
local function held(c)
    local out = {}
    for i = 0, c.overrides - 1 do if c.mats[i] then out[#out + 1] = i end end
    return out
end

local tests = {
    -- Only the slots the look needs carry an override: the ghost's capture (online/partner/capture.lua) sends the first
    -- 16 that hold a material, so no-op copies of a mesh's own materials would crowd out the colour layer's instances.
    only_the_slots_a_look_needs_are_overridden = function()
        local w = world()
        local body = w.eve.Mesh
        local X = '/Game/Mods/CNS/M_X.M_X'
        w.assets[X] = obj(X)
        body:SetMaterial(2, w.assets[X]) -- Her suit with an override from outside (CNS).
        assert(w.d.wear(B))
        same(held(body), {}, 'Kunoichi on her body: no override, hers taken off')
        eq(fields(w.file)[3], '2=' .. X, 'her one override kept')
        for i = 15, 47 do body:SetMaterial(i, obj('MID ' .. i)) end -- The colour layer's instances.
        assert(w.d.wear(B)) -- Worn again on the same mesh: SetSkeletalMesh returns at once.
        same(held(body), {}, 'the instances of the look before taken off')
        for i = 15, 47 do body:SetMaterial(i, obj('MID ' .. i)) end -- The colour layer's instances on this look.
        assert(w.d.off())
        eq(body.SkeletalMesh.path, OWN) same(held(body), {2}, 'off: her own override only')
        eq(body:GetMaterial(2).path, X)
    end,
    -- Her dynamic instances (CNS colours, the game's) come back as new instances of their parents with her values,
    -- after off and after a preview turned down. A parent on her mesh's own material is given back too.
    her_dynamic_instances_come_back_with_their_values = function()
        for _, how in ipairs({'off', 'revert'}) do
            local w = world()
            local body = w.eve.Mesh
            local MIDC = '/Script/Engine.MaterialInstanceDynamic'
            local TEX = '/Game/Mods/CNS/T_Lace.T_Lace'
            w.assets[TEX] = obj(TEX)
            local function mid(parent, values)
                local m = obj('MID of ' .. parent.path, values)
                m.Parent, m.sets = parent, {}
                function m:IsA(class) return class.path == MIDC end
                for _, kind in ipairs({'Vector', 'Scalar', 'Texture'}) do
                    m['Set' .. kind .. 'ParameterValue'] = function(self, n, v)
                        self.sets[#self.sets + 1] = {kind, n, kind == 'Texture' and v.path or v}
                    end
                end
                return m
            end
            function body:CreateDynamicMaterialInstance(i, source)
                local m = mid(source, {})
                self:SetMaterial(i, m)
                return m
            end
            local own3 = w.assets[OWN].Materials[4].MaterialInterface
            w.assets[own3.path] = own3
            -- An instance over an instance of her slot 3's own material: the nearest value of a name wins.
            local inner = mid(own3, {VectorParameterValues = {{ParameterInfo = {Name = 'Tint'},
                ParameterValue = {R = 0, G = 0, B = 1, A = 1}}}})
            body:SetMaterial(3, mid(inner, {
                VectorParameterValues = {{ParameterInfo = {Name = 'Tint'}, ParameterValue = {R = 1, G = 0, B = 0, A = 1}}},
                ScalarParameterValues = {{ParameterInfo = {Name = 'Rough'}, ParameterValue = 0.25}},
                TextureParameterValues = {{ParameterInfo = {Name = 'Lace'}, ParameterValue = w.assets[TEX]}}}))
            if how == 'off' then assert(w.d.wear(B)) else assert(w.d.preview(B)) end
            eq(body:GetMaterial(3).path, KS .. ':M3', how .. ': the look\'s own material on slot 3')
            eq(fields(w.file)[3], '3=' .. own3.path, how .. ': the slot kept by its parent')
            assert(w.d[how]())
            local back = body:GetMaterial(3)
            eq(back.Parent, own3, how .. ': a new instance of her parent')
            same(back.sets, {{'Vector', 'Tint', {R = 1, G = 0, B = 0, A = 1}}, {'Scalar', 'Rough', 0.25},
                {'Texture', 'Lace', TEX}}, how .. ': with her values')
            same(held(body), {3}, how .. ': her one override')
        end
    end,
    -- An older coop-closet.txt line lists every slot of her suit: the slots on her mesh's own material get no override.
    an_older_line_with_every_slot_overrides_only_hers = function()
        local w = world()
        local X = '/Game/Mods/CNS/M_X.M_X'
        w.assets[X] = obj(X)
        w.eve.Mesh:SetSkeletalMesh(w.assets[KS]) -- Kunoichi from the Lua load before.
        local slots = {}
        for i = 0, 5 do
            w.assets[OWN .. ':M' .. i] = w.assets[OWN].Materials[i + 1].MaterialInterface -- Found by its path.
            slots[#slots + 1] = i .. '=' .. (i == 2 and X or OWN .. ':M' .. i)
        end
        w.file = table.concat({w.eve.path, OWN, table.concat(slots, ','), '', ''}, '\t')
        w.new().tick()
        eq(w.eve.Mesh.SkeletalMesh.path, OWN, 'her own look back') same(held(w.eve.Mesh), {2}, 'her one override')
    end,
    toggles_enter_the_plan_and_survive_a_rewear = function()
        with_packs(function(w)
            local plan = assert(w.Dress.plan({{fit = 'p.suit'}}, nil, nil, {['p.suit'] = {[3] = true, [4] = false}}))
            eq(plan.body.whole.Toggles[3], true) eq(plan.body.whole.Toggles[4], false)
            eq(require('closet.fits').get('p.suit').Toggles[3], false, 'the fit itself is not changed')
            local t = {['p.suit'] = {[3] = true, [4] = false}}
            local d = toggled(w, t)
            assert(d.wear({{fit = 'p.suit'}}))
            same(hidden_at(w.eve.Mesh), {1, 4}, 'slot 3 shown, slot 4 hidden')
            assert(d.wear({{fit = 'p.suit'}}))
            same(hidden_at(w.eve.Mesh), {1, 4}, 'worn again: kept')
            w.eve.Mesh:SetSkeletalMesh(w.assets[OWN]) -- A map load: the watchdog mixes again.
            w.now = w.now + 1.01; d.tick(); w.now = w.now + 1.01; d.tick()
            eq(w.eve.Mesh.SkeletalMesh.path, PV1, 'mixed again')
            same(hidden_at(w.eve.Mesh), {1, 4}, 'the watchdog keeps the toggles')
        end)
    end,
    -- A pack suit worn whole with no hand map: each shown section is listed (the colour layer paints it), with its
    -- PieceHints slot (closet/cns_import.lua's guess from the toggle's name), else FullOutfit (the Primary role).
    -- Hidden sections are not listed.
    a_whole_pack_suit_lists_every_shown_section = function()
        with_packs(function(w)
            local item = pack_item('p.suit')
            item.PieceHints = {{MaterialIndex = 4, Name = 'Heels', Slot = 'Shoes'},
                {MaterialIndex = 5, Name = 'Body skin', Slot = 'BaseBody'}}
            require('closet.fits').use({['p.suit'] = item})
            local d = toggled(w, {})
            assert(d.wear({{fit = 'p.suit'}}))
            same(hidden_at(w.eve.Mesh), {1, 3})
            same(d.parts()[1].slots, {[0] = 'FullOutfit', [2] = 'FullOutfit', [4] = 'Shoes', [5] = 'BaseBody'},
                'every shown section: its hint, else FullOutfit')
        end)
    end,
    a_live_toggle_reshows_without_bumping_applied = function()
        with_packs(function(w)
            local t = {}
            local d = toggled(w, t)
            assert(d.wear({{fit = 'p.suit'}}))
            same(hidden_at(w.eve.Mesh), {1, 3})
            eq(d.parts()[1].fit, 'p.suit', 'parts name their outfit')
            local applied, shown = d.applied(), d.shown()
            t['p.suit'] = {[3] = true, [5] = false}
            ok(d.reshow())
            same(hidden_at(w.eve.Mesh), {1, 5}, 'shown at once')
            eq(d.applied(), applied, 'applied() never grows: the layers keep their instances')
            eq(d.shown(), shown + 1, 'shown() grows')
            eq(w.eve.Mesh.SkeletalMesh.path, PV1, 'the same mesh')
            w.now = w.now + 1.01; d.tick(); w.now = w.now + 1.01; d.tick()
            ok(not logged(w, 'hidden again') and not logged(w, 'mix again'), 'the watchdog takes the new show set')
            same(hidden_at(w.eve.Mesh), {1, 5})
        end)
    end,
    the_variant_row_steps_and_wears_its_mesh_with_materials_parameters_and_hiddenmats = function()
        with_packs(function(w)
            local Fits = require('closet.fits')
            local MAT, TEX = '/Game/P/M_Gold.M_Gold', '/Game/P/T_Gold.T_Gold'
            w.assets[MAT] = obj(MAT)
            w.assets[TEX] = obj(TEX, {texture = true})
            w.assets[TEX].IsA = function(_, class) return class.path == '/Script/Engine.Texture2D' end
            local item = pack_item('p.suit')
            item.Variants[2].Materials = {'', MAT, '/Game/P/M_Gone.M_Gone'}
            item.Variants[2].HiddenMats = {0}
            item.Variants[2].Parameters = {
                {MaterialIndex = 1, ParamType = 'Scalar', ParamName = 'Roughness', Value = 0.25},
                {MaterialIndex = 1, ParamType = 'Vector', ParamName = 'Tint', Value = {1, 0.5, 0, 1}},
                {MaterialIndex = 2, ParamType = 'Texture', ParamName = 'Basecolor', Value = TEX},
                {MaterialIndex = 2, ParamType = 'Texture', ParamName = 'Mask', Value = '/Game/P/T_Gone.T_Gone'}}
            Fits.use({['p.suit'] = item})
            local mids = {}
            local body = w.eve.Mesh
            body.CreateDynamicMaterialInstance = function(c, i, source)
                if not mids[i] then
                    mids[i] = {sets = {}, IsValid = function() return true end, type = function() return 'UObject' end}
                    for _, kind in ipairs({'Scalar', 'Vector', 'Texture'}) do
                        mids[i]['Set' .. kind .. 'ParameterValue'] = function(m, name, v)
                            m.sets[#m.sets + 1] = {kind, name, kind == 'Texture' and v.path or v}
                        end
                    end
                end
                c:SetMaterial(i, mids[i])
                return mids[i]
            end
            local options
            local d = w.Dress.new({log = function(m) w.log[#w.log + 1] = m end, store = w.store,
                clock = function() return w.now end, toggles = function() return options.toggles() end})
            options = require('closet.options').new({dress = d, log = function(m) w.log[#w.log + 1] = m end})
            assert(d.wear({{fit = 'p.suit'}}))
            local applied = d.applied()
            ok(options.set_variant('p.suit', 2))
            options.tick()
            eq(body.SkeletalMesh.path, PV2, 'variant 2\'s mesh') eq(d.applied(), applied + 1, 'dressed again')
            eq(body.mats[0], nil, 'an empty path: no override on slot 0')
            eq(body:GetMaterial(0).path, PV2 .. ':M0', 'an empty path keeps the mesh\'s own')
            same(mids[1].sets, {{'Scalar', 'Roughness', 0.25}, {'Vector', 'Tint', {R = 1, G = 0.5, B = 0, A = 1}}},
                'the parameters on slot 1\'s instance')
            same(mids[2].sets, {{'Texture', 'Basecolor', TEX}}, 'a texture that loads')
            same(hidden_at(body), {0, 3}, 'its HiddenMats and the toggle off by default')
            ok(logged(w, '/Game/P/M_Gone.M_Gone does not load'), 'a missing material said')
            ok(logged(w, '/Game/P/T_Gone.T_Gone does not load'), 'a missing texture said')
            options.set_variant('p.suit', 1) options.tick() options.set_variant('p.suit', 2) options.tick()
            local said = 0
            for _, line in ipairs(w.log) do
                if line:find('M_Gone.M_Gone does not load', 1, true) then said = said + 1 end
            end
            eq(said, 1, 'said once')
            Fits.CHOSEN = {}
        end)
    end,
    -- A pack's Materials index is the material slot: an empty or null entry keeps its place (closet/cns_import.lua's
    -- parse, then Fits.pack, then the wear).
    a_parsed_variant_keeps_each_material_on_its_own_slot = function()
        with_packs(function(w)
            local Fits = require('closet.fits')
            local M1, M3 = '/Game/P/M1.M1', '/Game/P/M3.M3'
            w.assets[M1], w.assets[M3] = obj(M1), obj(M3)
            local out = require('closet.cns_import').parse(('[{"UniqueFitID":"q.suit","OutfitDatas":[{"Mesh":"%s",' ..
                '"Materials":["","%s",null,"%s"]}]}]'):format(PV1, M1, M3), 'q.dekcns.json')
            same(out.items[1].Variants[1].Materials, {'', M1, '', M3}, 'positions kept')
            Fits.use({['q.suit'] = out.items[1]})
            local good, why = w.d.wear({{fit = 'q.suit'}})
            ok(good, why)
            local body = w.eve.Mesh
            eq(body:GetMaterial(0).path, PV1 .. ':M0', 'slot 0 keeps the mesh\'s own')
            eq(body:GetMaterial(1).path, M1, 'slot 1')
            eq(body:GetMaterial(2).path, PV1 .. ':M2', 'slot 2 keeps the mesh\'s own')
            eq(body:GetMaterial(3).path, M3, 'slot 3')
        end)
    end,
    a_whole_pack_fit_shows_all_but_hidden_and_off_toggles = function()
        with_packs(function(w)
            local good, line = w.d.wear({{fit = 'p.suit'}})
            ok(good, line)
            eq(w.eve.Mesh.SkeletalMesh.path, PV1, 'on her body')
            eq(#w.eve.comps, 1, 'no added mesh')
            for lod = 0, 1 do
                for i = 0, 5 do
                    eq(w.eve.Mesh.hidden[lod .. ':' .. i] == true, i == 1 or i == 3, 'lod ' .. lod .. ' slot ' .. i)
                end
            end
            second(w) second(w)
            ok(not logged(w, 'hidden again'), 'the watchdog keeps the whole look')
            eq(w.eve.Mesh.SkeletalMesh.path, PV1, 'not mixed again')
        end)
    end,
    variant_one_is_worn_by_default = function()
        with_packs(function(w)
            assert(w.d.preview({{fit = 'p.suit'}}))
            eq(w.eve.Mesh.SkeletalMesh.path, PV1, 'the first variant\'s mesh')
        end)
    end,
    -- SBO's own state that holds EVE's body (closet/wiring.lua's busy: the bike, the Doro look, the rifle, an emote, a
    -- coop wear suit): wear and preview refuse with its words, nothing on EVE and no file; once it ends they wear.
    -- worn() (eve/wear.lua refuses on it) also says yes for a kept look the next Lua load has not worn again yet.
    wear_and_preview_refuse_while_sbo_holds_her_body = function()
        local w = world()
        local key
        local d = w.Dress.new({log = function(m) w.log[#w.log + 1] = m end, store = w.store,
            clock = function() return w.now end, busy = function() return key, key and 'the rifle is out' end})
        key = 'rifle'
        local good, line = d.wear(B)
        eq(good, false, 'wear refused') eq(line, 'closet: not while the rifle is out', 'its line')
        good, line = d.preview(B)
        eq(good, false, 'preview refused') eq(line, 'closet: not while the rifle is out', 'its line')
        eq(w.eve.Mesh.SkeletalMesh.path, OWN, 'her own look') eq(w.file, nil, 'no file')
        ok(not d.worn(), 'nothing worn')
        key = nil
        assert(d.wear(B))
        ok(d.worn(), 'worn')
        w.paused = true
        local again = w.new()
        ok(again.worn(), 'a kept look waiting for its restore counts as worn')
        w.paused = false
        assert(again.off())
        ok(not again.worn(), 'off: nothing worn')
    end,
    -- The next Lua load has no catalogue until the packs are read: restore reads them (o.packs) before the kept words.
    a_kept_pack_suit_is_worn_again_after_the_packs_are_read = function()
        with_packs(function(w)
            assert(w.d.wear({{fit = 'p.suit'}}))
            local Fits = require('closet.fits')
            local catalogue = Fits.PACKS
            Fits.use(nil)
            local reads = 0
            local d = w.Dress.new({log = function(m) w.log[#w.log + 1] = m end, store = w.store,
                clock = function() return w.now end, packs = function() reads = reads + 1; Fits.PACKS = catalogue end})
            d.tick()
            ok(reads >= 1, 'the packs read') ok(d.worn(), 'worn again')
            eq(d.choices()[1].fit, 'p.suit') eq(w.eve.Mesh.SkeletalMesh.path, PV1)
            assert(d.off())
            eq(w.eve.Mesh.SkeletalMesh.path, OWN, 'off gives her own look back, not the pack suit')
        end)
    end,
    -- coop closet off before the kept look is worn again: the packs are read so the pack mesh counts as a closet mesh.
    off_after_a_reload_takes_a_kept_pack_suit_off = function()
        with_packs(function(w)
            assert(w.d.wear({{fit = 'p.suit'}}))
            local Fits = require('closet.fits')
            local catalogue = Fits.PACKS
            Fits.use(nil)
            local d = w.Dress.new({log = function(m) w.log[#w.log + 1] = m end, store = w.store,
                clock = function() return w.now end, packs = function() Fits.PACKS = catalogue end})
            assert(d.off())
            eq(w.eve.Mesh.SkeletalMesh.path, OWN, 'her own look back') eq(w.file, nil)
        end)
    end,
    a_missing_mesh_says_so_once = function()
        with_packs(function(w)
            eq(w.d.installed('gone.suit'), false) eq(w.d.installed('gone.suit'), false)
            eq(w.d.installed('p.suit'), true)
            local n = 0
            for _, line in ipairs(w.log) do if line:find('gone.suit', 1, true) then n = n + 1 end end
            eq(n, 1, 'one line')
            ok(logged(w, '/Game/Gone/G.G'), 'it names the mesh')
        end)
    end,
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
    -- A failed write of coop-closet.txt changes nothing on EVE: the preview and its added mesh stay. off() still works.
    a_failed_save_keeps_the_preview_on_eve = function()
        local w = world()
        assert(w.d.preview(A))
        eq(#w.eve.comps, 2, 'one added mesh')
        local added = w.eve.comps[2]
        local save = w.store.save
        w.store.save = function() return false, 'disk full' end
        local ok_, line = w.d.preview(B)
        eq(ok_, false, 'the preview failed') ok(line:find('disk full', 1, true), line)
        ok(w.d.previewing(), 'still previewing')
        eq(#w.eve.comps, 2, 'the added mesh stays') ok(w.eve.comps[2] == added, 'the same added mesh')
        w.store.save = save
        assert(w.d.off())
        eq(w.eve.Mesh.SkeletalMesh.path, OWN, 'her own body mesh') eq(#w.eve.comps, 1, 'no added mesh')
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
    -- A pack's UniqueFitID is any text: each byte outside [A-Za-z0-9_.-] goes into the file as %XX (Fits.word), so the
    -- next Lua load wears the same outfit again.
    any_pack_id_survives_the_file = function()
        local Dress = require('closet.dress')
        local odd = 'Ocean Maid:v2,(Shadow)+\195\136ve%01\t'
        local choices = {{fit = odd, slots = {'Chest'}}, {fit = 'Kunoichi(Shadow)'}, {fit = 'AiK_CH46_xSH_14462'}}
        local line = Dress.words(choices)
        eq(line, 'Ocean%20Maid%3Av2%2C%28Shadow%29%2B%C3%88ve%2501%09:Chest Kunoichi%28Shadow%29 AiK_CH46_xSH_14462')
        local words = {}
        for x in line:gmatch('%S+') do words[#words + 1] = x end
        same(Dress.parse(words), choices, 'read back')
        with_packs(function(w)
            local Fits = require('closet.fits')
            Fits.use({[odd] = pack_item(odd)})
            assert(w.d.wear({{fit = odd}}))
            local d = w.new()
            d.tick()
            ok(d.worn(), 'worn again') eq(d.choices()[1].fit, odd) eq(w.eve.Mesh.SkeletalMesh.path, PV1)
            ok(logged(w, 'worn again'), 'restored')
        end)
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
    -- A mix again with the closet mesh still on her body writes her own look in its first save: a later save that
    -- fails never leaves the closet mesh in coop-closet.txt as her own look.
    a_mix_again_saves_her_own_look_first = function()
        local w = world()
        assert(w.d.wear({{fit = 'AiK_CH27_14595', slots = {'Chest'}}, {fit = 'AiK_CH46_xSH_14462',
            slots = {'Shoes'}}}))
        w.eve.comps[2]:K2_DestroyComponent()
        local lines = {}
        w.store.save = function(line)
            lines[#lines + 1] = line
            if #lines > 1 then return false, 'disk full' end
            w.file = line
            return true
        end
        second(w) second(w)
        ok(logged(w, 'mix again'))
        eq(fields(lines[1])[2], OWN, 'the first save keeps her own look')
        eq(fields(w.file)[2], OWN, 'the file keeps her own look')
        w.d.off()
        eq(w.eve.Mesh.SkeletalMesh.path, OWN, 'off gives her own look')
    end,
    -- While her body mesh is not valid the mix waits: no mix again, no count toward Dress.FIGHT. Back after longer
    -- than the fight limit, the body gets the mix again.
    a_missing_body_waits_past_the_fight_limit = function()
        local w = world()
        assert(w.d.wear(A))
        local body = w.eve.Mesh
        body.alive = false
        for _ = 1, 2 * w.Dress.FIGHT.mixes + 2 do second(w) end
        ok(logged(w, 'no valid body mesh'), 'the wait logged')
        ok(not logged(w, 'stops mixing'), 'the missing body is no outside fight')
        body.alive = true
        body:SetSkeletalMesh(w.assets[OWN])
        local n = #w.log
        second(w) second(w) -- The watchdog's two looks at a changed body.
        local again
        for i = n + 1, #w.log do again = again or (w.log[i]:find('mix again', 1, true) ~= nil) end
        ok(again, 'mixed again')
        eq(body.SkeletalMesh.path, KS, 'the plan\'s body mesh back') ok(w.d.worn(), 'still worn')
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
    -- A wear or preview while restore waits (a Lua reload while the game is paused): the kept look's leftovers go and
    -- her own look comes back first, so the new look records her own suit and the kept look never comes back over it.
    a_wear_while_restore_waits_records_her_own_look = function()
        for _, put in ipairs({'wear', 'preview'}) do
            local w = world()
            assert(w.d.wear(B)) -- Kunoichi kept: her body wears its mesh, the file holds her own suit.
            w.paused = true
            local d = w.new()
            d.tick()
            eq(w.eve.Mesh.SkeletalMesh.path, KS, put .. ': restore waits while paused')
            assert(d[put]({{fit = MAID}}))
            eq(w.eve.Mesh.SkeletalMesh.path, OM, put .. ': the new look')
            eq(fields(w.file)[2], OWN, put .. ': her own suit kept, not the kept look\'s mesh')
            w.paused = false
            for _ = 1, 2 do w.now = w.now + 1.01; d.tick() end
            eq(w.eve.Mesh.SkeletalMesh.path, OM, put .. ': the kept look never comes back over it')
            ok(not logged(w, 'worn again: ' .. NINJA), put .. ': no restore of the kept look')
            assert(d.off())
            eq(w.eve.Mesh.SkeletalMesh.path, OWN, put .. ': off gives her own suit back') eq(w.file, nil)
        end
    end,
    -- A save that fails (a virus scanner holding coop-closet.txt.tmp): the look on EVE and the state stay as they were,
    -- the old line is written again. off still gives her own look back.
    a_failed_save_keeps_the_look_on_eve = function()
        local w = world()
        assert(w.d.wear(A)) -- Kunoichi's boots on her body, Ocean Maid's top on an added mesh.
        local before, top = w.file, w.eve.comps[2]
        local save, fails = w.store.save, 1
        w.store.save = function(line)
            if fails > 0 then fails = fails - 1; w.file = nil; return false, 'cannot write coop-closet.txt' end
            return save(line)
        end
        local good, why = w.d.wear({{fit = MAID}})
        eq(good, false) eq(why, 'coop-closet.txt not written: cannot write coop-closet.txt')
        ok(w.d.worn(), 'still worn') same(w.d.choices(), A, 'the look before')
        eq(w.eve.Mesh.SkeletalMesh.path, KS, 'her body unchanged') ok(top.alive, 'its added mesh still on EVE')
        eq(w.file, before, 'the old line written again')
        assert(w.d.off())
        eq(w.eve.Mesh.SkeletalMesh.path, OWN, 'off gives her own look back') ok(not top.alive, 'the added mesh gone')
    end,
    -- The watchdog's mix again that fails keeps the look: the next second tries again.
    a_failed_mix_again_is_tried_again = function()
        local w = world()
        assert(w.d.wear(A))
        local save, fails = w.store.save, 1
        w.store.save = function(line)
            if fails > 0 then fails = fails - 1; return false, 'cannot write coop-closet.txt' end
            return save(line)
        end
        w.eve.Mesh:SetSkeletalMesh(w.assets[OWN]) -- A map load.
        second(w) second(w)
        ok(logged(w, 'mix again failed: coop-closet.txt not written'), 'said') ok(w.d.worn(), 'still worn')
        second(w)
        eq(w.eve.Mesh.SkeletalMesh.path, KS, 'mixed again the next second')
        eq(#w.eve.comps, 2, 'one added mesh')
        eq(fields(w.file)[2], OWN, 'her own look kept')
        assert(w.d.off())
        eq(w.eve.Mesh.SkeletalMesh.path, OWN)
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
    -- The copy of online/partner/puppet.lua's guard: SetSkeletalMesh reads the mesh's Skeleton unchecked, so a mesh with
    -- none is refused before any engine call, as the body and as an added mesh (puppet_test's No_Skeleton case).
    a_mesh_with_no_skeleton_is_refused = function()
        local w = world()
        w.assets[KS].Skeleton = nil
        local mesh_, why = w.Dress.usable(KS)
        eq(mesh_, nil) eq(why, KS .. ' has no skeleton')
        local set = 0
        local body = w.eve.Mesh
        local set_mesh = body.SetSkeletalMesh
        body.SetSkeletalMesh = function(c, m) set = set + 1; return set_mesh(c, m) end
        for _, look in ipairs({B, A}) do -- Kunoichi on her body, then Kunoichi's shoes with Ocean Maid's top.
            local good, said = w.d.wear(look)
            eq(good, false) eq(said, KS .. ' has no skeleton')
        end
        eq(set, 0, 'no SetSkeletalMesh call') eq(#w.eve.comps, 1, 'no added mesh')
        eq(body.SkeletalMesh.path, OWN, 'her own look') eq(w.file, nil, 'nothing kept')
        w.assets[OM].Skeleton = nil
        local good, said = w.d.wear({{fit = MAID, slots = {'Chest'}}, {fit = NINJA, slots = {'BaseBody'}}})
        eq(good, false) eq(said, KS .. ' has no skeleton', 'the body is checked first')
        w.assets[KS].Skeleton = obj('/Game/Art/EVE/Skeleton.Skeleton')
        good, said = w.d.wear({{fit = MAID, slots = {'Chest'}}, {fit = NINJA, slots = {'BaseBody'}}})
        eq(good, false) eq(said, OM .. ' has no skeleton', 'an added mesh is checked too')
        eq(set, 0, 'still no SetSkeletalMesh call') eq(#w.eve.comps, 1, 'still no added mesh')
    end,
    -- The copy of online/partner/puppet.lua's resolve: a mod pack's mesh that is neither in memory nor found by LoadAsset
    -- (the cooked registry does not list it) is loaded by AssetRegistryHelpers:GetAsset with its path.
    a_mesh_loadasset_misses_is_found_by_getasset = function()
        local w = world()
        local registry, asked, loads = {[KS] = w.assets[KS]}, {}, {}
        w.assets[KS] = nil
        local find = StaticFindObject
        StaticFindObject = function(path)
            if path ~= '/Script/AssetRegistry.Default__AssetRegistryHelpers' then return find(path) end
            local helpers = obj(path)
            function helpers:GetAsset(data) asked[#asked + 1] = data.ObjectPath; return registry[data.ObjectPath] end
            return helpers
        end
        LoadAsset = function(path) loads[#loads + 1] = path end
        assert(w.d.wear(B))
        eq(w.eve.Mesh.SkeletalMesh.path, KS, 'worn from GetAsset')
        same(loads, {KS}, 'LoadAsset tried first') same(asked, {KS}, 'then GetAsset with its path')
        registry[KS] = nil
        local good, why = w.d.wear(B)
        eq(good, false) eq(why, KS .. ' not found', 'nothing found: refused')
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
    -- The restore line names the body switch as wear and preview do. The menu notice reads the plan on EVE.
    restore_with_a_switched_body_says_so = function()
        local w = world()
        assert(w.d.wear(GLOVES))
        w.log = {}
        w.d = w.new()
        w.d.tick()
        ok(logged(w, 'worn again: ' .. w.Dress.words(GLOVES) .. ' (switched by the auto body rule)'), w.log[1])
        eq(w.d.plan().switched, NINJA, 'the plan on EVE names the switch (the menu notice shows it)')
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
        eq(parts[1].mesh, KS, 'her body\'s mesh path') eq(parts[2].mesh, OM, 'the added mesh\'s path')
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
