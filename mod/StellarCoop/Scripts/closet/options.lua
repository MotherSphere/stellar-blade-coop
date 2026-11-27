-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet's options layer (the Full outfit tab's options page, coop closet option): per pack outfit (its
-- UniqueFitID) the variant worn and, per variant, its piece toggles. A toggle (key 'toggle:<material slot>') starts
-- from the pack's value (closet/fits.lua's Toggles: of two toggles on one slot an off one wins); only a value that
-- differs from it is kept. A follower (ControlledBy, Fits.leader) has no value of its own: it takes its leader's.
-- toggles() hands closet/dress.lua's plans {[fit]={[slot]=shown}} for the outfits with a kept value or a follower, in
-- the variant each wears. The variant goes to closet/fits.lua (Fits.choose): the outfit's fit is made from it, so
-- every wear plans it.
-- tick (each frame, on the game thread, before the colour layer's): a variant change of a worn outfit puts the look on
-- again (dress.again), a toggle change of one shows its sections (dress.reshow, applied() kept); a change that cannot
-- show now (a game look on, no EVE, a failed apply) is asked again at the next tick. After each pack scan it says once
-- each kept value whose outfit, variant or slot is gone: that value is ignored and stays in the file (the pack may
-- come back). A variant whose mesh does not load (dress.loads) is never worn: set_variant refuses it, a kept one is
-- replaced by the first after the scan (said once, kept in the file).
-- The values are kept in coop-closet-options.txt (link.store) as words split by tabs, '<fit> variant=<n>' and
-- '<fit> <variant> toggle:<slot>=on|off', sorted. They are read once at new. reset(fit) gives one outfit its pack
-- values back, off() (Reset Stellar Closet) every outfit and clears the file. stop() (coop off) drops the changes not
-- shown yet: the dress gave EVE her own look back.
-- o: {dress=closet/dress.lua's (plan, again, reshow, loads), store=link.store(Options.FILE), log=}.
local Fits=require('closet.fits')
local Options={}
Options.FILE='coop-closet-options.txt'
Options.USE='Use: coop closet option <fit> variant <n> | coop closet option <fit> toggle <slot> on|off'

local function slot_of(key)
    local i=tostring(key):match('^toggle:(%d+)$')
    return i and tonumber(i)
end
local function index_of(t)
    local i=type(t)=='table' and type(t.MaterialIndex)=='number' and math.tointeger(t.MaterialIndex)
    return i and i>=0 and i or nil
end

function Options.new(o)
    local dress,log=o.dress,o.log or function() end
    local store=o.store or {save=function() end,load=function() end,clear=function() end}
    local self={}
    local values={} -- '<fit> <variant>' -> {[key]=value}, the values that differ from the pack's.
    local variants={} -- fit -> the variant chosen, 2 or more.
    local redress,reshow={},{} -- Fits whose variant or toggles changed since the last tick.
    local said,checked={},nil -- Gone values said; Fits.PACKS as of the last check.
    for item in (store.load() or ''):gmatch('[^\t]+') do
        local fit,v=item:match('^(%S+) variant=(%d+)$')
        if fit then
            variants[fit]=tonumber(v)
            Fits.choose(fit,variants[fit])
        else
            local key,value
            fit,v,key,value=item:match('^(%S+) (%d+) (%S+)=(%S+)$')
            if fit and slot_of(key) and (value=='on' or value=='off') then
                values[fit..' '..v]=values[fit..' '..v] or {}
                values[fit..' '..v][key]=value=='on'
            end
        end
    end
    local function keep()
        local out={}
        for fit,v in pairs(variants) do out[#out+1]=fit..' variant='..v end
        for at,set in pairs(values) do
            for key,on in pairs(set) do out[#out+1]=at..' '..key..'='..(on and 'on' or 'off') end
        end
        table.sort(out)
        if #out==0 then return store.clear() end
        local saved,why=store.save(table.concat(out,'\t'))
        if saved==false then log('options: '..Options.FILE..' not written: '..tostring(why)) end
    end
    -- The pack's value of a key, nil when the outfit has no such toggle.
    local function default(fit,key)
        local f,i=Fits.get(fit),slot_of(key)
        return f and i and f.Toggles and f.Toggles[i]
    end
    local function say(line)
        if said[line] then return end
        said[line]=true
        log(line)
    end
    -- After a pack scan: each kept value whose outfit, variant or slot is gone, said once.
    local function check()
        if checked==Fits.PACKS or next(Fits.PACKS)==nil then return end
        checked=Fits.PACKS
        for fit,v in pairs(variants) do
            local f=Fits.PACKS[fit]
            if f and f.Variant~=v then say('options: '..fit..' has no variant '..v..': the first is worn')
            elseif f and not dress.loads(f.Mesh) then
                -- Fits.CHOSEN keeps v: the next pack scan tries it again (the pack may be fixed).
                Fits.PACKS[fit]=Fits.pack(Fits.ITEMS[fit],1)
                redress[fit]=true
                say('options: '..fit..' variant '..v..': its mesh does not load: the first is worn')
            end
        end
        for at,set in pairs(values) do
            local fit,v=at:match('^(%S+) (%d+)$')
            local f=Fits.PACKS[fit]
            if not f then say('options: '..fit..' is not installed: its saved options are ignored')
            elseif not (f.Variants or {})[tonumber(v)] then
                say('options: '..fit..' has no variant '..v..': its saved options are ignored')
            else
                for key in pairs(set) do
                    if default(fit,key)==nil then
                        say('options: '..fit..' has no toggle on slot '..tostring(slot_of(key))..': ignored')
                    end
                end
            end
        end
    end

    -- A key's value for an outfit in variant v: the kept one, else the pack's (nil: no such toggle).
    function self.get(fit,v,key)
        local mine=values[fit..' '..v] and values[fit..' '..v][key]
        if mine~=nil then return mine end
        return default(fit,key)
    end
    -- One key's value, kept only when it differs from the pack's; true and a line, or false and why.
    function self.set(fit,v,key,value)
        local pack=default(fit,key)
        if pack==nil then return false,'closet: '..tostring(fit)..' has no toggle on slot '..tostring(slot_of(key)) end
        local at=fit..' '..v
        values[at]=values[at] or {}
        if value==pack then values[at][key]=nil else values[at][key]=value end
        if next(values[at])==nil then values[at]=nil end
        keep()
        reshow[fit]=true
        local line=('closet: %s variant %d %s %s'):format(fit,v,key,value and 'on' or 'off')
        log('options: '..line)
        return true,line
    end
    -- The variant an outfit wears: its pack fit's, else the one kept, else the first.
    function self.variant(fit)
        local f=Fits.PACKS[fit]
        return f and f.Variant or variants[fit] or 1
    end
    function self.set_variant(fit,v)
        local was=self.variant(fit)
        if not Fits.choose(fit,v) then return false,'closet: '..tostring(fit)..' has no variant '..tostring(v) end
        local f=Fits.PACKS[fit]
        if f and not dress.loads(f.Mesh) then
            Fits.choose(fit,was)
            return false,'closet: '..fit..' variant '..v..': its mesh does not load'
        end
        variants[fit]=v~=1 and v or nil
        keep()
        redress[fit]=true
        log('options: '..fit..' variant '..v)
        return true,'closet: '..fit..' variant '..v
    end
    -- {[fit]={[slot]=shown}}: every toggle's value, a follower's its leader's, for the outfits with a kept value in the
    -- variant they wear or a follower.
    function self.toggles()
        local out={}
        for id,fit in pairs(Fits.PACKS) do
            local list=fit.Controls and fit.Controls.MaterialToggles or {}
            local set=values[id..' '..tostring(fit.Variant)]
            local any=set~=nil
            for _,t in ipairs(list) do any=any or index_of(t)~=nil and Fits.leader(list,t)~=t end
            if any then
                local map={}
                for _,t in ipairs(list) do
                    local i=index_of(t)
                    if i then
                        local lead=Fits.leader(list,t)
                        local on=set and index_of(lead) and set['toggle:'..index_of(lead)]
                        if on==nil then on=lead.Value~=false end
                        map[i]=map[i]~=false and on
                    end
                end
                out[id]=map
            end
        end
        return out
    end
    -- One outfit's pack values back: every variant's toggles and the first variant.
    function self.reset(fit)
        for at in pairs(values) do
            if at:sub(1,#fit+1)==fit..' ' then values[at]=nil end
        end
        variants[fit]=nil
        Fits.choose(fit,1)
        keep()
        redress[fit]=true
        log('options: '..fit..' back to its pack values')
        return true,'closet: '..fit..' options reset'
    end
    -- Every outfit's pack values back and the file cleared (Reset Stellar Closet).
    function self.off()
        for fit in pairs(variants) do
            Fits.choose(fit,1)
            redress[fit]=true
        end
        for at in pairs(values) do reshow[at:match('^(%S+) ')]=true end
        values,variants={},{}
        keep()
        log('options: every outfit back to its pack values')
        return true,'closet: options off'
    end
    function self.tick()
        check()
        if next(redress)==nil and next(reshow)==nil then return end
        local plan=dress.plan()
        local worn={}
        if plan then
            worn[plan.body.fit]=true
            for _,a in ipairs(plan.added) do worn[a.fit]=true end
        end
        local again,show=false,false
        for fit in pairs(redress) do again=again or worn[fit]==true end
        for fit in pairs(reshow) do show=show or worn[fit]==true end
        local done,why=true,nil
        if again then done,why=dress.again() elseif show then done,why=dress.reshow() end
        if not done then return say('options: the change waits: '..tostring(why)) end
        redress,reshow={},{}
    end
    -- coop off: the changes not shown yet dropped; the values stay for the next look.
    function self.stop() redress,reshow={},{} end
    return self
end

return Options
