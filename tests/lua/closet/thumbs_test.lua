-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop closet thumbs (closet/thumbs.lua) on a fake game: the cache folder and file names, the capture queue (every
-- installed fit's pieces and full, cached ones skipped unless redo, a changed stamp captured again), one capture a
-- frame after the textures' wait, the sections shown per picture, the rig's settings, the rig removed on each end path
-- (done, coop off, a map change, a Lua reload), the refusals and the waits, a run from the menu's row that waits for
-- its close, a missing mesh, a folder the export did not make, the framing, the AActor link entries the header cites.
local run = dofile('tests/lua/closet/run.lua')
package.loaded.UEHelpers = {GetPlayer = function() return nil end}
FName = function(s) return s end
local Player = require('core.player')
local Fits = require('closet.fits')
local Thumbs = require('closet.thumbs')

local MAID, KUNOICHI = 'AiK_CH27_14595', 'AiK_CH46_xSH_14462'
local CAPTURE, SKINNED = '/Script/Engine.SceneCapture2D', '/Script/Engine.SkeletalMeshComponent'
local RENDER = '/Script/Engine.Default__KismetRenderingLibrary'
local RIG = '/Game/Maps/A.A:PersistentLevel.SceneCapture2D_7'

local function obj(t)
    t.IsValid = t.IsValid or function(self) return self.valid ~= false end
    t.type = function() return 'UObject' end
    return t
end
-- A fake game: EVE, her world, the capture actor, its rig mesh, the rendering library, the files and the link file.
-- r.calls lists the engine calls in order ({name, ...}); r.files the files there; r.stamps what was written.
local function game(opt)
    opt = opt or {}
    local r = {calls = {}, log = {}, files = {}, stamps = {}, dirs = {}, t = 0, world = true, installed = {}}
    local function call(...) r.calls[#r.calls + 1] = {...} end
    r.meshes = {[Fits.get(MAID).Mesh] = {path = Fits.get(MAID).Mesh, count = 48},
        [Fits.get(KUNOICHI).Mesh] = {path = Fits.get(KUNOICHI).Mesh, count = 44}}
    -- Bones of the rig mesh in its reference pose (cm, world): hands 160 cm apart, the head 150 cm up.
    r.bones = {['Bip001-Head'] = {X = 0, Y = 0, Z = 5150}, ['Bip001-Neck'] = {X = 0, Y = 0, Z = 5140},
        ['Bip001-Pelvis'] = {X = 0, Y = 0, Z = 5095}, ['Bip001-L-Hand'] = {X = 0, Y = -80, Z = 5130},
        ['Bip001-R-Hand'] = {X = 0, Y = 80, Z = 5130}, ['Bip001-L-Thigh'] = {X = 0, Y = -10, Z = 5090},
        ['Bip001-R-Thigh'] = {X = 0, Y = 10, Z = 5090}, ['Bip001-L-Foot'] = {X = 0, Y = -12, Z = 5008},
        ['Bip001-R-Foot'] = {X = 0, Y = 12, Z = 5008}}
    local mesh = obj({sections = {}})
    function mesh:SetCollisionEnabled(n) call('collision', n) end
    function mesh:SetSkeletalMesh(m, re) call('mesh', m.path, re); r.count = m.count end
    function mesh:SetForcedLOD(n) call('lod', n) end
    function mesh:PrestreamTextures(s, p, c) call('prestream', s, p, c) end
    function mesh:GetNumMaterials() return r.count end
    function mesh:GetNumLODs() return 2 end
    function mesh:ShowAllMaterialSections(lod) mesh.sections[lod] = {} end
    function mesh:ShowMaterialSection(i, s, show, lod)
        assert(s == -1, 'no LODMaterialMap remap')
        if not show then mesh.sections[lod][i] = true end
    end
    function mesh:GetSocketLocation(name) return assert(r.bones[name], name) end
    function mesh:K2_SetWorldLocationAndRotation(at, rot) call('place mesh', at, rot) end
    local capture = obj({})
    function capture:ShowOnlyComponent(c) call('show only', c) end
    function capture:CaptureScene() call('capture') end
    local actor = obj({CaptureComponent2D = capture})
    function actor:AddComponentByClass(cls, manual, _, deferred)
        call('add', cls.path, manual, deferred)
        return mesh
    end
    function actor:K2_SetActorLocationAndRotation(at, rot, sweep, _, teleport)
        call('place', at, rot, sweep, teleport)
    end
    function actor:K2_DestroyActor() call('destroy'); actor.valid = false end
    function actor:GetFullName() return 'SceneCapture2D ' .. RIG end
    function actor:IsA(cls) return cls.path == CAPTURE end
    local world = obj({})
    function world:SpawnActor(cls, at, rot) call('spawn', cls.path, at, rot); return actor end
    local render = obj({path = RENDER})
    function render:CreateRenderTarget2D(w, x, y, f, clear, mips)
        assert(w == world, 'the world as context')
        call('rt', x, y, f, clear, mips)
        r.rt = obj({})
        return r.rt
    end
    -- Writes the PNG unless opt.no_dirs and its folder was not made.
    function render:ExportRenderTarget(w, rt, dir, name)
        assert(w == world and rt == r.rt, 'the world and the rig\'s render target')
        call('export', dir, name)
        if not opt.no_dirs or r.dirs[dir] then r.files[dir .. '\\' .. name] = true end
    end
    function render:ReleaseRenderTarget2D(rt) call('release', rt) end
    local classes = {[CAPTURE] = obj({path = CAPTURE}), [SKINNED] = obj({path = SKINNED}), [RENDER] = render}
    local body = obj({})
    function body:K2_GetComponentLocation() return {X = 100, Y = 200, Z = 0} end
    function body:K2_GetComponentRotation() return {Pitch = 0, Yaw = -90, Roll = 0} end
    r.eve = obj({Mesh = body})
    function r.eve:GetWorld() return world end
    function r.eve:K2_GetActorRotation() return {Pitch = 0, Yaw = 0, Roll = 0} end
    function r.eve:IsBattle() return r.battle == true end
    function r.eve:IsAttachedToLevelSequenceWithoutPlayable() return r.cutscene == true end
    Player.engaged = function() return r.near == true end
    r.objects = {}
    StaticFindObject = function(p) return r.objects[p] end
    r.mesh, r.capture, r.actor, r.world = mesh, capture, actor, world
    r.thumbs = Thumbs.new({log = function(m) r.log[#r.log + 1] = m end, folder = 'M', fits = Fits,
        installed = function(id) return r.installed[id] ~= false end,
        store = {save = function(p) r.saved = p end, load = function() return r.saved end,
            clear = function() r.saved = nil end},
        fs = {exists = function(p) return r.files[p] == true end, read = function(p) return r.stamps[p] end,
            write = function(p, s) r.stamps[p] = s; return true end,
            mkdir = function(d) r.dirs[d] = true; call('mkdir', d) end,
            rmdir = function(d) r.removed_dirs = r.removed_dirs or {}; r.removed_dirs[#r.removed_dirs + 1] = d end},
        her = function() return r.eve end, find = function(p) return classes[p] end,
        usable = function(p)
            local m = r.meshes[p]
            if not m then return nil, p .. ' not found' end
            return m
        end,
        clock = function() return r.t end, world = function() return r.world end,
        paused = function() return r.paused == true end, menu_open = function() return r.menu == true end,
        status = function() return r.status end})
    return r
end
-- The calls named name since index from (1 when nil).
local function named(r, name, from)
    local out = {}
    for i = from or 1, #r.calls do if r.calls[i][1] == name then out[#out + 1] = r.calls[i] end end
    return out
end
-- Ticks until the run ends (at most n), 0.1 s apart; the exports of each tick.
local function drain(r, n)
    local per = {}
    for _ = 1, n or 400 do
        if not r.thumbs.running() then break end
        local before = #named(r, 'export')
        r.t = r.t + 0.1
        r.thumbs.tick()
        per[#per + 1] = #named(r, 'export') - before
    end
    return per
end
local function logged(r, needle)
    for _, line in ipairs(r.log) do if line:find(needle, 1, true) then return true end end
    return false
end
-- Every file of a fit there, with its stamp.
local function cache(r, id)
    for _, p in ipairs(Thumbs.pictures(Fits.get(id))) do r.files[Thumbs.file('M', id, p.slot)] = true end
    r.stamps[Thumbs.folder('M', id) .. '\\stamp.txt'] = Thumbs.stamp(Fits.get(id))
end

local tests = {
    -- A pack suit of the catalogue (closet/fits.lua's Fits.use) gets its full picture, worn whole: every section but
    -- its HiddenMats and its toggles off by default, counted by GetNumMaterials on the rig mesh.
    pack_suits_are_captured_whole = function()
        local PM = '/Game/P/V1.V1'
        Fits.use({['p.suit'] = {UniqueFitID = 'p.suit', DisplayName = 'P', Slot = 'FullOutfit',
            File = '~mods\\P\\p.dekcns.json', Variants = {{Mesh = PM, HiddenMats = {1}}},
            UserConfigs = {MaterialToggles = {{MaterialIndex = 3, Value = false}}}}})
        local good, why = pcall(function()
            local r = game()
            r.meshes[PM] = {path = PM, count = 5}
            local seen = {}
            local capture = r.capture.CaptureScene
            r.capture.CaptureScene = function(self)
                if r.count == 5 then
                    local hidden = {}
                    for i in pairs(r.mesh.sections[0]) do hidden[#hidden + 1] = i end
                    table.sort(hidden)
                    seen[#seen + 1] = hidden
                end
                return capture(self)
            end
            ok(r.thumbs.run(false))
            drain(r, 1000)
            same(seen, {{1, 3}}, 'one picture, slots 1 and 3 hidden')
            ok(r.files[Thumbs.file('M', 'p.suit', Thumbs.FULL)], 'its full.png')
            eq(r.stamps[Thumbs.folder('M', 'p.suit') .. '\\stamp.txt'], Thumbs.stamp(Fits.get('p.suit')), 'stamp')
            ok(Thumbs.stamp(Fits.get('p.suit')):find('|1,3', 1, true), 'the stamp holds what it hides')
            ok(logged(r, 'p.suit 1/1'), 'logged')
        end)
        Fits.use(nil)
        ok(good, why)
    end,

    folder_and_file_names = function()
        eq(Thumbs.key(MAID), MAID, 'a plain id is its own folder')
        eq(Thumbs.folder('M', MAID), 'M\\closet-thumbs\\' .. MAID, 'the folder')
        eq(Thumbs.file('M', MAID, 'Gloves'), 'M\\closet-thumbs\\' .. MAID .. '\\Gloves.png', 'a piece')
        eq(Thumbs.file('M', MAID, Thumbs.FULL), 'M\\closet-thumbs\\' .. MAID .. '\\full.png', 'the whole outfit')
        -- An id with characters a folder name may not hold: those turned into _, then 8 hex digits of its hash, so
        -- two ids that turn alike keep two folders.
        local a, b = Thumbs.key("Racer's High Edit"), Thumbs.key('Racer_s High Edit')
        ok(a:match("^Racer_s_High_Edit%-%x%x%x%x%x%x%x%x$"), a)
        ok(b:match('^Racer_s_High_Edit%-%x%x%x%x%x%x%x%x$'), b)
        ok(a ~= b, 'two folders')
        eq(Thumbs.key("Racer's High Edit"), a, 'the same id, the same folder')
    end,

    pictures_of_a_fit = function()
        -- One picture a piece, then full: the outfit as its pack shows it (the pieces not off and the skin).
        local fit = Fits.get(MAID)
        local list = Thumbs.pictures(fit)
        eq(#list, #fit.Pieces + 1, 'a picture a piece and full')
        eq(list[#list].slot, Thumbs.FULL, 'full last')
        local gloves
        for _, p in ipairs(list) do if p.slot == 'Gloves' then gloves = p end end
        same(gloves.show, {[17] = true, [24] = true, [25] = true}, 'a piece shows its own materials only')
        eq(gloves.region, 'hands', 'gloves are framed on the hands')
        local full = list[#list].show
        ok(full[14], 'full shows the skin')
        ok(full[15] and full[46], 'full shows the pieces not off')
        ok(not full[42] and not full[10], 'full leaves the pieces off by default hidden')
        ok(not full[1], 'full leaves the unknown slots hidden')
        eq(list[#list].region, 'full', 'full is framed whole')
    end,

    the_stamp_follows_the_mesh_and_the_pieces = function()
        local fit = Fits.get(MAID)
        local stamp = Thumbs.stamp(fit)
        ok(stamp:find(fit.Mesh, 1, true), 'the mesh path in the stamp')
        local moved = {Mesh = '/Game/Other.Other', Skin = fit.Skin, Pieces = fit.Pieces}
        ok(Thumbs.stamp(moved) ~= stamp, 'another mesh, another stamp')
        local fewer = {Mesh = fit.Mesh, Skin = fit.Skin, Pieces = {table.unpack(fit.Pieces, 2)}}
        ok(Thumbs.stamp(fewer) ~= stamp, 'other pieces, another stamp')
    end,

    the_queue_takes_every_installed_fit_and_skips_cached_ones = function()
        local r = game()
        local good, line = r.thumbs.run(false)
        ok(good, line)
        ok(line:find('24 picture', 1, true), line)
        r.thumbs.stop()
        -- A fit not installed: none of its pictures.
        r = game()
        r.installed[KUNOICHI] = false
        good, line = r.thumbs.run(false)
        ok(line:find('12 picture', 1, true), line)
        r.thumbs.stop()
        -- Ocean Maid cached under its stamp: Kunoichi Shadow's only; redo takes both again.
        r = game()
        cache(r, MAID)
        good, line = r.thumbs.run(false)
        ok(line:find('12 picture', 1, true), line)
        r.thumbs.stop()
        good, line = r.thumbs.run(true)
        ok(line:find('24 picture', 1, true), 'redo: ' .. line)
        r.thumbs.stop()
        -- One file gone: that one alone; a changed stamp (the pack's mesh changed): the whole fit again.
        r.files[Thumbs.file('M', MAID, 'Gloves')] = nil
        good, line = r.thumbs.run(false, MAID)
        ok(line:find('1 picture', 1, true), line)
        r.thumbs.stop()
        r.files[Thumbs.file('M', MAID, 'Gloves')] = true
        r.stamps[Thumbs.folder('M', MAID) .. '\\stamp.txt'] = 'v1|/Game/Old.Old|'
        good, line = r.thumbs.run(false, MAID)
        ok(line:find('12 picture', 1, true), line)
        r.thumbs.stop()
        -- Everything cached: nothing to run.
        cache(r, MAID)
        cache(r, KUNOICHI)
        good, line = r.thumbs.run(false)
        ok(good and not r.thumbs.running(), line)
        ok(line:find('redo', 1, true), 'it names redo: ' .. line)
        -- An unknown fit: refused.
        good, line = r.thumbs.run(false, 'nope')
        ok(not good and line:find('nope', 1, true), tostring(line))
    end,

    the_rig_and_one_capture_a_frame = function()
        local r = game()
        ok(r.thumbs.run(false, MAID))
        eq(#r.calls, 0, 'nothing before the first tick')
        r.thumbs.tick()
        -- The rig: a SceneCapture2D 50 m above EVE, a 256x256 RTF_RGBA8 target, LDR colour, the show-only list.
        local spawn = named(r, 'spawn')[1]
        eq(spawn[2], CAPTURE, 'a SceneCapture2D')
        same(spawn[3], {X = 100, Y = 200, Z = 5000}, '50 m above EVE')
        same(named(r, 'rt')[1], {'rt', 256, 256, 2, {R = 0, G = 0, B = 0, A = 1}, false}, 'the render target')
        local c = r.capture
        ok(c.TextureTarget == r.rt, 'the target')
        eq(c.bCaptureEveryFrame, false, 'no capture every frame')
        eq(c.bCaptureOnMovement, false, 'no capture on movement')
        eq(c.CaptureSource, 2, 'SCS_FinalColorLDR')
        eq(c.PrimitiveRenderMode, 2, 'PRM_UseShowOnlyList')
        eq(c.FOVAngle, Thumbs.FOV, 'the FOV')
        same(named(r, 'add')[1], {'add', SKINNED, true, false}, 'a skeletal mesh, manual attachment')
        same(named(r, 'collision')[1], {'collision', 0}, 'no collision')
        eq(r.mesh.bForceMipStreaming, true, 'full mips')
        same(named(r, 'place mesh')[1], {'place mesh', {X = 100, Y = 200, Z = 5000}, {Pitch = 0, Yaw = -90, Roll = 0}},
            'the mesh where her body is, 50 m up, turned as hers')
        ok(named(r, 'show only')[1][2] == r.mesh, 'the capture shows the mesh only')
        eq(r.saved, RIG, 'the rig\'s path in the link file')
        -- The outfit's mesh: LOD 0 forced, its textures streamed; no capture before WAIT s.
        r.t = 0.1
        r.thumbs.tick()
        same(named(r, 'mesh')[1], {'mesh', Fits.get(MAID).Mesh, true}, 'Ocean Maid\'s mesh')
        same(named(r, 'lod')[1], {'lod', 1}, 'LOD 0 forced')
        same(named(r, 'prestream')[1], {'prestream', 2, true, 0}, 'textures streamed')
        for _ = 1, 5 do r.t = r.t + 0.1; r.thumbs.tick() end
        eq(#named(r, 'capture'), 0, 'no capture before the wait')
        -- Then one export a tick at most, every picture once, into the fit's folder.
        local per = drain(r)
        for i, n in ipairs(per) do ok(n <= 1, 'tick ' .. i .. ': ' .. n .. ' exports') end
        local exports = named(r, 'export')
        eq(#exports, 12, 'every picture of Ocean Maid')
        eq(exports[1][2], 'M\\closet-thumbs\\' .. MAID, 'the folder')
        eq(exports[1][3], Fits.get(MAID).Pieces[1].Slot .. '.png', 'the first piece')
        eq(exports[12][3], 'full.png', 'full last')
        eq(#named(r, 'capture'), 12, 'one capture a picture')
        -- Each capture after its place: in front of EVE, right of her, a little above, looking back.
        local place = named(r, 'place')[1]
        ok(place[2].X > 0 and place[2].Y > 0, 'in front, on her right')
        eq(place[3].Pitch, -Thumbs.VIEW[2], 'looking a little down')
        eq(place[4], false, 'no sweep')
        -- The stamp once every file is there; the rig removed, its target released, the link file cleared.
        eq(r.stamps[Thumbs.folder('M', MAID) .. '\\stamp.txt'], Thumbs.stamp(Fits.get(MAID)), 'the stamp')
        eq(#named(r, 'destroy'), 1, 'the rig removed')
        same(named(r, 'release')[1], {'release', r.rt}, 'the target released')
        eq(r.saved, nil, 'the link file cleared')
        ok(logged(r, MAID .. ' 12/12'), 'the fit\'s count in the log')
        ok(logged(r, '12 made, 0 failed'), 'the summary')
    end,

    each_picture_shows_its_sections_only = function()
        local r = game()
        ok(r.thumbs.run(false, MAID))
        -- Before each capture: the sections of that picture shown on every LOD, all others hidden.
        local seen = {}
        local capture = r.capture.CaptureScene
        r.capture.CaptureScene = function(self)
            local hidden = {}
            for lod = 0, 1 do
                hidden[lod] = {}
                for i in pairs(r.mesh.sections[lod]) do hidden[lod][i] = true end
            end
            seen[#seen + 1] = hidden
            return capture(self)
        end
        drain(r)
        local list = Thumbs.pictures(Fits.get(MAID))
        eq(#seen, #list, 'a capture a picture')
        for k, p in ipairs(list) do
            for lod = 0, 1 do
                for i = 0, 47 do
                    eq(seen[k][lod][i] == true, not p.show[i], p.slot .. ' LOD ' .. lod .. ' slot ' .. i)
                end
            end
        end
    end,

    a_failed_picture_keeps_the_stamp_off = function()
        local r = game()
        ok(r.thumbs.run(false, MAID))
        local real = r.files
        r.files = setmetatable({}, {__newindex = function(t, k, v)
            if not k:find('Gloves', 1, true) then rawset(t, k, v) end
        end})
        drain(r)
        eq(r.stamps[Thumbs.folder('M', MAID) .. '\\stamp.txt'], nil, 'no stamp: the next run captures it again')
        ok(logged(r, MAID .. ' 11/12'), 'the count says one is missing')
        ok(logged(r, '11 made, 1 failed'), 'the summary')
        r.files = real
    end,

    a_missing_mesh_is_skipped = function()
        local r = game()
        r.meshes[Fits.get(KUNOICHI).Mesh] = nil
        r.installed[KUNOICHI] = true
        ok(r.thumbs.run(false))
        drain(r)
        eq(#named(r, 'export'), 12, 'Ocean Maid\'s pictures only')
        ok(logged(r, KUNOICHI .. ' skipped'), 'said')
        ok(logged(r, '12 made, 12 failed'), 'the summary')
    end,

    a_folder_the_export_did_not_make_is_made = function()
        local r = game({no_dirs = true})
        ok(r.thumbs.run(false, MAID))
        drain(r)
        local dir = 'M\\closet-thumbs\\' .. MAID
        same(named(r, 'mkdir'), {{'mkdir', dir}}, 'the folder made once')
        eq(#named(r, 'export'), 13, 'the first picture exported again')
        ok(logged(r, '12 made, 0 failed'), 'every picture made')
    end,

    the_rig_goes_on_each_end_path = function()
        -- coop off (stop).
        local r = game()
        ok(r.thumbs.run(false))
        r.thumbs.tick()
        r.thumbs.stop()
        eq(#named(r, 'destroy'), 1, 'stop: removed')
        eq(#named(r, 'release'), 1, 'stop: released')
        eq(r.saved, nil, 'stop: the link file cleared')
        eq(r.thumbs.running(), false, 'stop: not running')
        r.thumbs.stop()
        eq(#named(r, 'destroy'), 1, 'a second stop: nothing')
        -- A map change: the rig gone with its world.
        r = game()
        ok(r.thumbs.run(false))
        r.thumbs.tick()
        r.actor.valid = false
        r.t = 0.1
        r.thumbs.tick()
        eq(r.thumbs.running(), false, 'map: stopped')
        eq(#named(r, 'destroy'), 0, 'map: nothing to destroy')
        eq(r.saved, nil, 'map: the link file cleared')
        ok(logged(r, 'map'), 'map: said')
        -- A Lua reload: the next load's first tick removes the rig the link file names, a SceneCapture2D only.
        r = game()
        local left = obj({})
        function left:IsA(cls) return cls.path == CAPTURE end
        function left:K2_DestroyActor() left.gone = true end
        r.objects['/Game/Old.Old:PersistentLevel.SceneCapture2D_3'] = left
        r.saved = '/Game/Old.Old:PersistentLevel.SceneCapture2D_3'
        r.thumbs.tick()
        eq(left.gone, true, 'reload: the earlier rig removed')
        eq(r.saved, nil, 'reload: the link file cleared')
        local other = obj({})
        function other:IsA() return false end
        function other:K2_DestroyActor() other.gone = true end
        r = game()
        r.objects['/Game/Old.Old:PersistentLevel.Thing_3'] = other
        r.saved = '/Game/Old.Old:PersistentLevel.Thing_3'
        r.thumbs.tick()
        eq(other.gone, nil, 'reload: never another object')
        -- An engine call that raises during a run: the run ends with its rig removed, said once.
        r = game()
        ok(r.thumbs.run(false))
        r.thumbs.tick()
        r.eve.IsBattle = function() error('gone', 0) end
        r.t = 1.5
        r.thumbs.tick()
        eq(r.thumbs.running(), false, 'raise: stopped')
        eq(#named(r, 'destroy'), 1, 'raise: removed')
        ok(logged(r, 'stopped: gone'), 'raise: said')
        -- A sweep that raises: said. The run's first step still comes.
        r = game()
        r.saved = '/Game/Old.Old:PersistentLevel.SceneCapture2D_3'
        StaticFindObject = function() error('no objects yet', 0) end
        ok(r.thumbs.run(false))
        r.thumbs.tick()
        ok(logged(r, 'the sweep failed: no objects yet'), 'sweep raise: said')
        eq(#named(r, 'spawn'), 1, 'sweep raise: the rig spawned in the same tick')
    end,

    refusals_and_waits = function()
        local r = game()
        r.battle = true
        local good, line = r.thumbs.run(false)
        ok(not good and line:find('combat', 1, true), tostring(line))
        r.battle, r.near = false, true
        good, line = r.thumbs.run(false)
        ok(not good and line:find('combat', 1, true), 'an enemy near: ' .. tostring(line))
        r.near, r.menu = false, true
        good, line = r.thumbs.run(false)
        ok(not good and line:find('menu', 1, true), tostring(line))
        r.menu, r.cutscene = false, true
        good, line = r.thumbs.run(false)
        ok(not good and line:find('cutscene', 1, true), tostring(line))
        r.cutscene, r.paused = false, true
        good, line = r.thumbs.run(false)
        ok(not good, tostring(line))
        r.paused = false
        good, line = r.thumbs.run(false)
        ok(good, line)
        good, line = r.thumbs.run(false)
        ok(not good and line:find('already', 1, true), tostring(line))
        eq(#named(r, 'spawn'), 0, 'no rig from a refusal')
        -- During a run, combat or the menu makes it wait (looked at once a second), then it goes on.
        r.thumbs.tick()
        r.battle = true
        for _ = 1, 40 do r.t = r.t + 0.1; r.thumbs.tick() end
        local calls = #r.calls
        for _ = 1, 20 do r.t = r.t + 0.1; r.thumbs.tick() end
        eq(#r.calls, calls, 'nothing while in combat')
        eq(r.thumbs.running(), true, 'still running')
        r.battle = false
        drain(r)
        eq(#named(r, 'export'), 24, 'every picture after the fight')
    end,

    a_run_from_the_menu_waits_for_its_close = function()
        -- The closet menu's row (closet/ui/menu.lua) starts a run while the menu is open: it waits for the close.
        -- The console's run is still refused while the menu is open; every other refusal still holds for the row.
        local r = game()
        r.menu = true
        local good, line = r.thumbs.run(false)
        ok(not good and line:find('menu', 1, true), 'the console: ' .. tostring(line))
        r.battle = true
        good, line = r.thumbs.run(false, nil, true)
        ok(not good and line:find('combat', 1, true), 'the row in combat: ' .. tostring(line))
        r.battle = false
        good, line = r.thumbs.run(false, nil, true)
        ok(good and r.thumbs.running(), tostring(line))
        for _ = 1, 30 do r.t = r.t + 0.1; r.thumbs.tick() end
        eq(#r.calls, 0, 'nothing while the menu is open')
        r.menu = false
        drain(r)
        eq(#named(r, 'export'), 24, 'every picture after the close')
    end,

    -- snap(fit, shot) takes the outfit's picture as the closet camera shows it: a SceneCapture2D at the camera's place
    -- looking at its look point, the whole scene (no show-only list), a SNAP_W x SNAP_H target (EVE's part of the
    -- screen), its FOV from the screen's vertical half-angle; exported as full.png, then the capture and the target go.
    snap_takes_the_camera_view_as_full_png = function()
        local function near(got, want, tol, what)
            ok(math.abs(got - want) <= tol, what .. ': ' .. got .. ' vs ' .. want)
        end
        local r = game()
        local shot = {at = {X = 300, Y = 0, Z = 100}, look = {X = 0, Y = 0, Z = 100}, tanv = 0.4}
        local good, line = r.thumbs.snap(MAID, shot)
        ok(good, tostring(line))
        local spawn = named(r, 'spawn')[1]
        eq(spawn[2], CAPTURE, 'a SceneCapture2D') same(spawn[3], shot.at, 'at the camera')
        near(spawn[4].Yaw, 180, 1e-6, 'facing the look point') near(spawn[4].Pitch, 0, 1e-6, 'level')
        same(named(r, 'rt')[1], {'rt', Thumbs.SNAP_W, Thumbs.SNAP_H, 2, {R = 0, G = 0, B = 0, A = 1}, false},
            'EVE\'s part of the screen')
        local c = r.capture
        eq(c.CaptureSource, 2, 'SCS_FinalColorLDR') eq(c.PrimitiveRenderMode, nil, 'the whole scene')
        near(c.FOVAngle, 2 * math.deg(math.atan(0.4 * Thumbs.SNAP_W / Thumbs.SNAP_H)), 1e-6, 'the screen\'s height')
        eq(#named(r, 'capture'), 1, 'one capture')
        same(named(r, 'export')[1], {'export', 'M\\closet-thumbs\\' .. MAID, 'full.png'}, 'full.png in its folder')
        eq(#named(r, 'release'), 1, 'the target released') eq(#named(r, 'destroy'), 1, 'the capture gone')
        good, line = r.thumbs.snap('no.such.fit', shot)
        ok(not good and line:find('no.such.fit', 1, true), tostring(line))
        good, line = r.thumbs.snap(MAID, nil)
        ok(not good and line:find('camera', 1, true), 'no camera: ' .. tostring(line))
    end,

    -- clear() deletes the pictures' folder (<mod folder>\closet-thumbs) with everything in it; refused while a run
    -- goes (its files would come back half made) or with no mod folder.
    clear_deletes_the_pictures_folder = function()
        local r = game()
        local good, line = r.thumbs.clear()
        ok(good, tostring(line))
        same(r.removed_dirs, {'M\\' .. Thumbs.DIR}, 'the pictures folder deleted')
        r.menu = false
        ok(r.thumbs.run(false), 'a run')
        good, line = r.thumbs.clear()
        ok(not good and line:find('running', 1, true), 'refused while running: ' .. tostring(line))
        eq(#r.removed_dirs, 1, 'nothing deleted then')
        good, line = Thumbs.new({log = function() end, fs = {rmdir = function() error('called') end}}).clear()
        ok(not good and line:find('folder', 1, true), 'no mod folder: refused, ' .. tostring(line))
    end,

    -- The header cites each AActor function by its FClassFunctionLinkInfo entry {CreateFuncPtr, Name}, 16 bytes, and
    -- that entry's constructor and FFunctionParams: never an entry's Name field or the next function's constructor.
    the_actor_functions_are_cited_by_their_link_entries = function()
        local f = assert(io.open('mod/StellarCoop/Scripts/closet/thumbs.lua', 'rb'))
        local src = f:read('a')
        f:close()
        for _, want in ipairs({'AddComponentByClass: link entry 0x1464cb810, constructor 0x1446be8d0',
            'K2_SetActorLocationAndRotation: link entry 0x1464cbcf0, constructor 0x1446bf770',
            'K2_DestroyActor: link entry 0x1464cbc40, constructor 0x1446bf560'}) do
            ok(src:find(want, 1, true), 'cited: ' .. want)
        end
        for _, wrong in ipairs({'0x1464cb818', '0x1464cbcf8', '0x1464cbc48', '0x1446be900', '0x1446bf7a0',
            '0x1446bf590'}) do
            ok(not src:find(wrong, 1, true), 'not cited: ' .. wrong)
        end
    end,

    the_framing = function()
        -- Two bones 100 cm apart: the span with its margin fills the FOV; the eye looks back at their middle from
        -- VIEW degrees right of her front and above.
        local eye, rot, d = Thumbs.frame({X = 0, Y = -50, Z = 100}, {X = 0, Y = 50, Z = 100}, {min = 0}, 0)
        local want = 100 * Thumbs.MARGIN / 2 / math.tan(math.rad(Thumbs.FOV / 2))
        ok(math.abs(d - want) < 1e-6, 'distance ' .. d .. ', want ' .. want)
        local back = math.sqrt(eye.X ^ 2 + eye.Y ^ 2 + (eye.Z - 100) ^ 2)
        ok(math.abs(back - want) < 1e-6, 'the eye at that distance from the middle')
        ok(math.abs(math.deg(math.atan(eye.Y, eye.X)) - Thumbs.VIEW[1]) < 1e-6, 'right of her front')
        ok(math.abs(rot.Yaw - (Thumbs.VIEW[1] + 180)) < 1e-6, 'looking back')
        eq(rot.Pitch, -Thumbs.VIEW[2], 'looking down')
        -- A short span takes the region's least one; lift raises the middle.
        local _, _, short = Thumbs.frame({X = 0, Y = 0, Z = 0}, {X = 0, Y = 0, Z = 10}, {min = 40}, 0)
        ok(math.abs(short - 40 * Thumbs.MARGIN / 2 / math.tan(math.rad(Thumbs.FOV / 2))) < 1e-6, 'the least span')
        local high = Thumbs.frame({X = 0, Y = 0, Z = 0}, {X = 0, Y = 0, Z = 0}, {min = 40, lift = 10}, 0)
        local low = Thumbs.frame({X = 0, Y = 0, Z = 0}, {X = 0, Y = 0, Z = 0}, {min = 40}, 0)
        ok(math.abs(high.Z - low.Z - 10) < 1e-6, 'lift')
        -- Every region names two bones.
        for _, region in ipairs({'head', 'torso', 'arms', 'hands', 'hips', 'legs', 'feet', 'full'}) do
            local b = Thumbs.REGIONS[region]
            ok(b and b[1] and b[2], region)
        end
    end,
}

run('thumbs_test', tests)
