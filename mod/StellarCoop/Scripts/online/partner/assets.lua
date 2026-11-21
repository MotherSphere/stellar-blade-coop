-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The assets her ghost's events name (the ghost's fidelity, phase 5 Task 10), one loader for every ghost slot. The
-- native part appends each name a member's game sent to the slot's coop-names file ('name <k> <kind> <asset> <a> <b>
-- [<params>]'); this loader reads the new lines of each watched slot at most each 0.25 s, loads one path each 0.25 s
-- for all the slots together (LoadAsset, a path two slots name once) and appends 'loaded <k> 0x<object> 0x<class>
-- 0x<a|0> 0x<b|0>' to the slot's coop-loaded file once every path of that key is in, for the native part to play.
-- Each object must be of its kind's class (a sound's SoundBase, its SoundClass and SoundAttenuation), else it is
-- refused. A path outside the game's own Sound and Art folders is a mod's: loaded only when allowed(path) says both
-- players have it, under the crash sentinel. The game may collect an object nothing else holds: one cached object a
-- tick is checked. A collected one is loaded again at the same pace; each key naming it then gets a new line.
local U=require('core.unreal')
local valid,hex,find=U.valid,U.hex,U.find
local Assets={}
local EVERY=0.25
-- The class each path of a kind must be, in the order of its words: the asset, then a and b (a sound's class and
-- attenuation). Other kinds carry no path in a and b.
local CLASSES={sound={'/Script/Engine.SoundBase','/Script/Engine.SoundClass','/Script/Engine.SoundAttenuation'},
    niagara={'/Script/Niagara.NiagaraSystem'},cascade={'/Script/Engine.ParticleSystem'}}
-- The game's own: /Game/[DLC_<n>/](Sound|Art)/..., as the native part's event_path_ok checks every path it hands over.
local function own(path)
    local top=path:match('^/Game/DLC_%d%d?/(%w+)/') or path:match('^/Game/(%w+)/')
    return top=='Sound' or top=='Art'
end
-- sentinel: online/partner/sentinel.lua's. allowed(path): true for a mod's asset both players have.
function Assets.new(sentinel,allowed)
    local self={}
    -- By ghost slot: files, from (bytes read), read_at, keys ({k, kind, paths}) in order, sent (k: line), kinds, on
    -- (watched now). A slot unwatched keeps its place, so watching it again appends no line it already has.
    local slots={}
    -- By class and path: {object=, hex=, class=}, or false after a failed load (never tried again). Its address and
    -- class are read at the load: lines() may run after the game collected it, before the check finds it.
    local cache={}
    local order,check={},0 -- The cache keys holding an object, in their load's order; the last one checked.
    local load_at,dirty=-math.huge,false
    local function wants(s,kind) return s.on and (not s.kinds or s.kinds[kind]) end
    -- A slot's new names from its files, or all of them again after a reset.
    local function read(s)
        local text,to=s.files.names(s.from)
        if text==false then -- Shorter than read: the native part started the slot again.
            s.from,s.keys,s.sent=0,{},{}
            text,to=s.files.names(0)
        end
        if not text then return end
        s.from=to
        for line in text:gmatch('[^\n]+') do
            local k,kind,asset,a,b=line:match('^name (%d+) (%a+) (%S+) (%S+) (%S+)')
            local classes=CLASSES[kind]
            if k and classes then
                local paths={classes[1]..' '..asset}
                if kind=='sound' then
                    paths[2]=a~='-' and classes[2]..' '..a or nil
                    paths[3]=b~='-' and classes[3]..' '..b or nil
                end
                s.keys[#s.keys+1]={k=tonumber(k),kind=kind,paths=paths}
                dirty=true
            end
        end
    end
    -- The first cache key ('<class> <path>') a watched key needs that is neither cached nor failed and may be loaded.
    local function wanted()
        for _,s in pairs(slots) do
            for _,key in ipairs(s.keys) do
                for i=1,3 do
                    local c=key.paths[i]
                    local path=c and c:match(' (.+)$')
                    if path and wants(s,key.kind) and cache[c]==nil and not sentinel.aside(path) and
                        (own(path) or allowed(path)) then
                        return c
                    end
                end
            end
        end
    end
    -- One load of a cache key; the message when it failed or gave another class.
    local function load(c)
        local class_path,path=c:match('^(%S+) (.+)$')
        local object
        local function get()
            local ok,loaded=pcall(LoadAsset,path)
            object=ok and valid(loaded) or nil
            local checked,is=pcall(function() return object and object:IsA(find(class_path)) end)
            if object and not (checked and is) then object=false end
        end
        if own(path) then get() else sentinel.call(path,get) end
        cache[c]=object and {object=object,hex=hex(object),class=hex(object:GetClass())} or false
        if not object then
            return 'Ghost asset not loaded: '..path..(object==false and ' (not a '..class_path..')' or '')
        end
        order[#order+1]=c
        dirty=true
    end
    -- Each watched key whose paths are all in gets a loaded line, again when one of its objects changed.
    local function lines()
        for _,s in pairs(slots) do
            for _,key in ipairs(s.keys) do
                local got={}
                for i=1,3 do
                    local c=key.paths[i]
                    if c and not cache[c] then got=nil; break end
                    got[i]=c and cache[c].hex or '0x0'
                end
                if got and wants(s,key.kind) then
                    local class=cache[key.paths[1]].class
                    local line=string.format('loaded %d %s %s %s %s',key.k,got[1],class,got[2],got[3])
                    if s.sent[key.k]~=line and s.files.loaded(line) then s.sent[key.k]=line end
                end
            end
        end
    end
    -- k's files (core/link.lua's link or link.slot(k)) watched; kinds: the kinds loaded, {sound=true, niagara=true,
    -- cascade=true} or some of them (nil: every kind).
    function self.watch(k,files,kinds)
        local s=slots[k]
        if not (s and s.files==files) then
            s={files=files,from=0,read_at=-math.huge,keys={},sent={}}
            slots[k]=s
        end
        s.kinds,s.on,dirty=kinds,true,true
    end
    -- k no longer watched (its ghost went): nothing more read or loaded for it until it is watched again. Its loaded
    -- file stays, so the native part keeps what it has: removing it could race the worker's read offset.
    function self.unwatch(k)
        if slots[k] then slots[k].on=false end
    end
    -- At coop off: every slot's loaded file removed, every slot forgotten.
    function self.off()
        for _,s in pairs(slots) do s.files.loaded(nil) end
        slots={}
    end
    -- Each frame (every ghost's tick calls it; the clock paces it): new names, one cached object checked, one load,
    -- the lines due. Returns a line for the log when a load failed.
    function self.tick()
        local now=os.clock()
        for _,s in pairs(slots) do
            if s.on and now-s.read_at>=EVERY then s.read_at=now; read(s) end
        end
        if #order>0 then
            check=check%#order+1
            local c=cache[order[check]]
            if c and not valid(c.object) then cache[order[check]]=nil; table.remove(order,check); check=check-1 end
        end
        local said
        if now-load_at>=EVERY then
            local c=wanted()
            if c then load_at=now; said=load(c) end
        end
        if dirty then dirty=false; lines() end
        return said
    end
    return self
end
return Assets
