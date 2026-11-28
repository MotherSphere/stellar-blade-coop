-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Stellar Closet's presets and favourites (the Full outfit tab's Presets rows and F on an outfit's row, coop closet
-- preset and coop closet favourite). A preset is a number from 1, a name or none (the menu then shows "Preset n"), the
-- whole outfit worn when it was saved, its variant and its kept option values (closet/options.lua's words). save takes
-- the first free number. wear(n, put) gives the outfit that variant and those values (closet/options.lua's
-- set_variant and take), then wears it whole with put (closet/ui/menu.lua's preview), else with dress.wear. A preset
-- whose outfit is not installed (its pack removed) stays in the file: list says gone and wear refuses it.
-- A preset keeps its head pieces as extra items; one with none (an old file) leaves the worn head pieces alone.
-- A favourite is an outfit's UniqueFitID; fav turns it on or off.
-- Both are kept in coop-closet-presets.txt (link.store, one line) as items split by tabs: 'fav <fit>',
-- '<n> <fit> <variant>', '<n> name=<name>', '<n> <key>=<value>', and for each head piece (hair, ponytail)
-- '<n> head <fit> <slot> <variant>' and '<n> h:<fit> <key>=<value>', sorted, each fit id as Fits.word gives it. They
-- are read once at new.
-- o: {store=link.store(Presets.FILE), options=closet/options.lua's, dress=closet/dress.lua's (choices, installed,
-- wear), log=}.
local Fits=require('closet.fits')
local Slots=require('closet.slots')
local Presets={}
Presets.FILE='coop-closet-presets.txt'
Presets.USE='Use: coop closet preset save [name] | coop closet preset wear|delete <n> | '..
    'coop closet preset rename <n> [name] | coop closet favourite <fit>'

function Presets.new(o)
    local options,dress,log=o.options,o.dress,o.log or function() end
    local store=o.store or {save=function() end,load=function() end,clear=function() end}
    local self={}
    -- n -> {fit, variant, name, values={'<key>=<value>'}, heads={{fit, slot, variant, values}}}; fit -> true.
    local presets,favs={},{}
    for item in (store.load() or ''):gmatch('[^\t]+') do
        local fit=item:match('^fav (%S+)$')
        local n,name=item:match('^(%d+) name=(.+)$')
        local n2,fit2,v=item:match('^(%d+) (%S+) (%d+)$')
        local n3,value=item:match('^(%d+) (%S+=%S+)$')
        local n4,hfit,hslot,hv=item:match('^(%d+) head (%S+) (%S+) (%d+)$')
        local n5,hof,hvalue=item:match('^(%d+) h:(%S+) (%S+=%S+)$')
        n=tonumber(n or n2 or n3 or n4 or n5)
        if fit then favs[Fits.unword(fit)]=true
        elseif n then
            presets[n]=presets[n] or {values={},heads={}}
            if name then presets[n].name=name
            elseif hfit then
                table.insert(presets[n].heads,{fit=Fits.unword(hfit),slot=hslot,variant=tonumber(hv),values={}})
            elseif hof then hof=Fits.unword(hof)
                presets[n].hvalues=presets[n].hvalues or {}
                presets[n].hvalues[hof]=presets[n].hvalues[hof] or {}
                table.insert(presets[n].hvalues[hof],hvalue)
            elseif fit2 then presets[n].fit,presets[n].variant=Fits.unword(fit2),tonumber(v)
            else table.insert(presets[n].values,value) end
        end
    end
    for n,p in pairs(presets) do
        if not p.fit then presets[n]=nil end -- An item with no outfit line.
        for _,h in ipairs(p.heads) do h.values=(p.hvalues or {})[h.fit] or {} end
    end
    local function keep()
        local out={}
        for fit in pairs(favs) do out[#out+1]='fav '..Fits.word(fit) end
        for n,p in pairs(presets) do
            out[#out+1]=n..' '..Fits.word(p.fit)..' '..p.variant
            if p.name then out[#out+1]=n..' name='..p.name end
            for _,value in ipairs(p.values) do out[#out+1]=n..' '..value end
            for _,h in ipairs(p.heads) do
                out[#out+1]=n..' head '..Fits.word(h.fit)..' '..h.slot..' '..h.variant
                for _,value in ipairs(h.values) do out[#out+1]=n..' h:'..Fits.word(h.fit)..' '..value end
            end
        end
        table.sort(out)
        if #out==0 then return store.clear() end
        local saved,why=store.save(table.concat(out,'\t'))
        if saved==false then log('presets: '..Presets.FILE..' not written: '..tostring(why)) end
    end
    local function label(n) return presets[n].name or 'Preset '..n end
    -- A name with its tabs and line ends as spaces, nil when empty.
    local function clean(name)
        name=name and tostring(name):gsub('[\t\r\n]',' '):match('^%s*(.-)%s*$')
        return name~='' and name or nil
    end

    -- A choice of a head piece (its slots, or its fit's own, of group head).
    local function head_slots(c)
        local fit=Fits.get(c.fit)
        local list=c.slots or {fit and fit.Slot}
        for _,slot in ipairs(list) do if Slots.group(slot)~='head' then return nil end end
        return #list>0 and list or nil
    end
    -- The worn choices split: the head pieces {{fit, slot}} and the others.
    local function split(c)
        local heads,rest={},{}
        for _,choice in ipairs(c) do
            local slots=head_slots(choice)
            if slots then for _,slot in ipairs(slots) do heads[#heads+1]={fit=choice.fit,slot=slot} end
            else rest[#rest+1]=choice end
        end
        return heads,rest
    end
    -- The worn whole outfit as preset n (the first free number), named or not, with the head pieces worn; nil and why
    -- when no one whole outfit is worn (head choices do not count).
    function self.save(name)
        local worn,c=split(dress.choices() or {})
        if #c~=1 or c[1].slots then return nil,'closet: a preset needs one whole outfit worn' end
        local fit=c[1].fit
        local v=options.variant(fit)
        local n=1
        while presets[n] do n=n+1 end
        presets[n]={fit=fit,variant=v,name=clean(name),values=options.words(fit,v),heads={}}
        for _,h in ipairs(worn) do
            local hv=options.variant(h.fit)
            table.insert(presets[n].heads,{fit=h.fit,slot=h.slot,variant=hv,values=options.words(h.fit,hv)})
        end
        keep()
        log('presets: '..label(n)..' saved: '..fit..' variant '..v)
        return n,'closet: '..label(n)..' saved'
    end
    -- Preset n on EVE: its variant and values, then its outfit worn whole by put (default dress.wear). put also gets
    -- back, which gives the outfit its variant and values from before (the menu's preview turned down).
    function self.wear(n,put)
        local p=presets[tonumber(n)]
        if not p then return false,'closet: no preset '..tostring(n) end
        if not (Fits.get(p.fit) and dress.installed(p.fit)) then
            return false,'closet: '..label(tonumber(n))..': '..p.fit..' is not installed'
        end
        -- The outfit and each head piece that is installed (a removed hair pack leaves the rest of the preset): its
        -- variant and values from before, kept for back.
        local pieces={{fit=p.fit,variant=p.variant,values=p.values}}
        local choices={{fit=p.fit}}
        for _,h in ipairs(p.heads) do
            if Fits.get(h.fit) and dress.installed(h.fit) then
                pieces[#pieces+1]=h
                choices[#choices+1]={fit=h.fit,slots={h.slot}}
            else log('presets: '..label(tonumber(n))..': '..h.fit..' is not installed, left out') end
        end
        if #p.heads==0 then -- An old preset: the worn head pieces stay.
            for _,c in ipairs(dress.choices() or {}) do if head_slots(c) then choices[#choices+1]=c end end
        end
        for _,piece in ipairs(pieces) do
            piece.was,piece.words=options.variant(piece.fit),options.words(piece.fit,piece.variant)
        end
        local function back()
            for _,piece in ipairs(pieces) do
                options.take(piece.fit,piece.variant,piece.words)
                if options.variant(piece.fit)~=piece.was then options.set_variant(piece.fit,piece.was) end
                log('presets: '..piece.fit..' back to variant '..piece.was)
            end
        end
        for _,piece in ipairs(pieces) do
            if options.variant(piece.fit)~=piece.variant then
                local good,why=options.set_variant(piece.fit,piece.variant)
                if not good then back() return false,why end
            end
            options.take(piece.fit,piece.variant,piece.values)
        end
        log('presets: '..label(tonumber(n))..' worn')
        local good,why=(put or dress.wear)(choices,back)
        if not good then back() end -- A wear that failed (no EVE during a map change): the options as before.
        return good,why
    end
    function self.delete(n)
        n=tonumber(n)
        if not presets[n] then return false,'closet: no preset '..tostring(n) end
        local was=label(n)
        presets[n]=nil
        keep()
        log('presets: '..was..' deleted')
        return true,'closet: '..was..' deleted'
    end
    -- A preset's name (nil or empty: none, so "Preset n").
    function self.rename(n,name)
        n=tonumber(n)
        if not presets[n] then return false,'closet: no preset '..tostring(n) end
        presets[n].name=clean(name)
        keep()
        log('presets: preset '..n..' is '..label(n))
        return true,'closet: preset '..n..' is '..label(n)
    end
    -- The presets by number: {n, name (nil: none), fit, variant, gone=its outfit is not installed}.
    function self.list()
        local out={}
        for n,p in pairs(presets) do
            out[#out+1]={n=n,name=p.name,fit=p.fit,variant=p.variant,
                gone=not (Fits.get(p.fit) and dress.installed(p.fit))}
        end
        table.sort(out,function(a,b) return a.n<b.n end)
        return out
    end
    function self.fav(fit)
        if type(fit)~='string' or fit=='' then return false,Presets.USE end
        favs[fit]=not favs[fit] or nil
        keep()
        local line='closet: '..fit..(favs[fit] and ' is a favourite' or ' is not a favourite')
        log('presets: '..line)
        return true,line
    end
    function self.is_fav(fit) return favs[fit]==true end
    return self
end

return Presets
