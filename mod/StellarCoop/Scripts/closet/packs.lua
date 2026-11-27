-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet's pack catalogue: every installed *.dekcns.json pack read into one table of outfits by UniqueFitID.
-- The DLL lists the packs at game start in coop-cns-packs.txt (native closet/packs.h pack_list): a "<size> <time>
-- <path from Content\Paks>" line each. Each pack is read in place with closet/cns_import.lua and never changed.
-- Packs.new{paks = SB\Content\Paks (core/pak_gate.lua paks_of) or nil, list = full path of coop-cns-packs.txt,
--     read = function(path, limit) -> text | nil, message (core/link.lua Link.files.read), log = function(line)}
--   loader.scan()      -> catalogue, report {packs = listed packs, reused = of them taken from the cache,
--                         items = outfits in the catalogue, failed = {[path] = why: no outfit came from it},
--                         why = nil | 'no pack folder' | 'no pack list'}
--   loader.catalogue() -> the last scan's {[UniqueFitID] = item with File = its path} ({} before the first scan)
--   loader.items(slot) -> that slot's items, sorted by DisplayName in any case, then by UniqueFitID
-- A pack whose size and time match the last scan's keeps its parsed items without a read. Each log line is said once
-- per pack path and stamp. Of two packs with one UniqueFitID the first by sorted path wins.
-- shortcut: the DLL lists packs only at game start, so rescan sees new files after a restart; add a native re-list
-- when packs change in play.
-- shortcut: Lua's io.open takes the ANSI code page while the list is UTF-8, so a pack path with non-ASCII bytes fails
-- to open (logged once); let the DLL hand the text over if a real pack hits it.
local CnsImport = require('closet.cns_import')

local Packs = {}

Packs.MAX_BYTES = 1 << 20 -- the DLL's kMaxCnsBytes (link/pak_list.h): a longer pack is skipped, not parsed cut

-- The list's lines CnsImport.should_read accepts, as {path=, size=, time=}, sorted by path. Other lines are dropped.
function Packs.entries(text)
    local out = {}
    for line in (text or ''):gmatch('[^\r\n]+') do
        local size, time, path = line:match('^(%d+) (%d+) (.+)$')
        if path and CnsImport.should_read(path) then
            out[#out + 1] = {path = path, size = tonumber(size), time = tonumber(time)}
        end
    end
    table.sort(out, function(a, b) return a.path < b.path end)
    return out
end

-- A scan's report as one line (the log, coop closet rescan).
function Packs.line(report)
    if report.why == 'no pack list' then
        return 'closet packs: no pack list (coop-cns-packs.txt: an older DLL or no start yet)'
    elseif report.why then
        return 'closet packs: ' .. report.why
    end
    local failed = 0
    for _ in pairs(report.failed) do failed = failed + 1 end
    return ('closet packs: %d packs (%d reused), %d outfits, %d failed'):format(report.packs, report.reused,
        report.items, failed)
end

function Packs.new(env)
    local self = {}
    local cache = {} -- [path] = {stamp=, items=, why=}
    local said = {}
    local current = {}
    local function say(key, line)
        if said[key] then return end
        said[key] = true
        env.log(line)
    end

    local function load(entry, stamp)
        local text, message = env.read(env.paks .. '\\' .. entry.path, Packs.MAX_BYTES + 1)
        local why = not text and 'cannot open: ' .. tostring(message)
            or #text > Packs.MAX_BYTES and ('larger than %d bytes'):format(Packs.MAX_BYTES)
        if why then
            say(stamp .. ' ' .. entry.path, entry.path .. ': ' .. why)
            return {stamp = stamp, items = {}, why = why}
        end
        local out = CnsImport.parse(text, entry.path)
        for _, line in ipairs(out.errors) do say(stamp .. ' ' .. line, line) end
        return {stamp = stamp, items = out.items, why = #out.items == 0 and out.errors[1] or nil}
    end

    function self.scan()
        local report = {packs = 0, reused = 0, items = 0, failed = {}}
        local text
        if not env.paks then
            report.why = 'no pack folder'
        else
            text = env.list and env.read(env.list)
            if not text then report.why = 'no pack list' end
        end
        local catalogue, seen = {}, {}
        for _, entry in ipairs(Packs.entries(text)) do
            local stamp = entry.size .. ':' .. entry.time
            local known = cache[entry.path]
            if known and known.stamp == stamp then
                report.reused = report.reused + 1
            else
                known = load(entry, stamp)
                cache[entry.path] = known
            end
            seen[entry.path] = true
            report.packs = report.packs + 1
            report.failed[entry.path] = known.why
            for _, line in ipairs(CnsImport.merge(catalogue, known.items, entry.path)) do say(line, line) end
        end
        for path in pairs(cache) do
            if not seen[path] then cache[path] = nil end
        end
        for _ in pairs(catalogue) do report.items = report.items + 1 end
        current = catalogue
        local line = Packs.line(report)
        if report.why then say(line, line) else env.log(line) end
        return catalogue, report
    end

    function self.catalogue() return current end

    function self.items(slot)
        local out = {}
        for _, item in pairs(current) do
            if item.Slot == slot then out[#out + 1] = item end
        end
        table.sort(out, function(a, b)
            local x, y = a.DisplayName:lower(), b.DisplayName:lower()
            if x ~= y then return x < y end
            return a.UniqueFitID < b.UniqueFitID
        end)
        return out
    end

    return self
end

return Packs
