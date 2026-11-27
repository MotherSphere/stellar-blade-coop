-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Copies online/partner/capture.lua's morphs_of (a mesh's MorphTargets, each named by its GetFName, read once in a
-- pcall; a list that does not read counts as none).
-- Stellar Closet's shape layer (coop closet shape, the menu's Body tab): the body shape by the morph targets of the
-- worn meshes. Each worn mesh's morph names are read once per mesh path. A name is a row when her body's mesh has it
-- or two worn meshes share it; each row holds a value from 0 to 100% in steps of STEP. A value goes on her body with
-- SetMorphTarget when her body has the name: every added piece whose mesh has it follows (the engine's follower
-- merge, below). A name her body lacks goes on each added component that has it. A name no row lists is never set.
-- tick (each frame, on the game thread, menu open or not) puts the shape on when dress.applied() changes (a new body
-- mesh clears her body's curves, the added components are new) and when a value changes. Once a second (CHECK) it reads
-- the curves it set back (GetMorphTarget): another mesh put on a worn component and its own back in one frame (gun
-- mode's rebuild of her body, fight/gunmode/overlay.lua) empties them while applied() stays, so a gone curve puts the
-- whole shape on again. A curve counts as gone when it reads 0 (its name no longer in the curves) or when it reads the
-- options layer's value for that name on that component (options.shaped), which the options layer writes back first
-- after such a rebuild. Any other value is another writer's (another mod) and is left alone, so two writers of one name
-- never take turns. A name set before that is
-- no longer wanted is removed (SetMorphTarget with 0 and bRemoveZeroWeight): her own look (own_look, off) loses the
-- closet's names, a curve set from outside stays. A name the options layer wrote on that component (a pack ShapeKey,
-- options.shaped) gets the pack's value back instead. Nothing while the dress is paused (Tachy Mode) or stopped.
-- The values are kept in coop-closet-shape.txt (link.store) as name=value words split by tabs, in name order, apart
-- from the look. They are read once at new: they survive a restart. off() (Reset Stellar Closet, coop closet shape off)
-- sets every value to 0 and clears the file. stop() (coop off) removes the closet's names from what it set: her body
-- may wear the same mesh again, which keeps its curves.
-- o: {dress=closet/dress.lua's (applied, parts), store=link.store(Shape.FILE), options=closet/options.lua's (shaped),
-- log=, clock= (os.clock)}.
--
-- The game's parts, read in Ghidra (SB-Win64-Shipping.exe, build 26123051) on 26 Nov 2026:
--   USkinnedMeshComponent.SkeletalMesh: object property at 0x568, params 0x14665d7e0 (name 0x145a76dc0).
--   USkeletalMesh.MorphTargets: TArray of MorphTarget objects at 0x198, params 0x14664fc68 (name 0x14649e748); its
--     inner object property 0x14664fb78 takes class func 0x14488c890 -> 0x14488c960 (/Script/Engine MorphTarget). A
--     morph target's name is its object name (GetFName).
--   USkeletalMeshComponent.SetMorphTarget(MorphTargetName FName, Value float, bRemoveZeroWeight bool): native entry
--     0x146659b90 (name 0x1464d8d18), exec 0x14491f120 reads the three (params 0x1466561e8 MorphTargetName, 0x146656250
--     bRemoveZeroWeight) and calls FUN_14411b400: the name's curve in the TMap at component +0xec8 is added or changed;
--     with bRemoveZeroWeight and |Value| <= 1e-05 it is removed.
--   The follower merge, USkeletalMeshComponent::UpdateSlaveComponent FUN_144116570: on a component with a master pose
--     (+0x570), the master's curves (+0xec8) are appended to the follower's mesh (+0x568) by name, then the follower's
--     own; FUN_143f8d220 finds each name on that mesh (FUN_144531b00) and skips a name the mesh lacks.
--   USkeletalMeshComponent::SetSkeletalMesh FUN_14411a4f0: returns at once for the mesh it wears (+0x568), its
--     curves kept; a new mesh empties the curves at +0xec8 (FUN_140e6c6a0, FUN_140e6c3f0).
--   USkeletalMeshComponent.GetMorphTarget(MorphTargetName FName) -> float: native entry 0x146659830 (name 0x1466546c0),
--     exec 0x14491efb0 finds the name in the TMap at +0xec8 (FUN_140e6c8e0) and answers its value, else 0.
local U=require('core.unreal')
local Shape={}
Shape.FILE='coop-closet-shape.txt'
Shape.STEP=10 -- %: a row's step.
Shape.CHECK=1 -- s: how often the curves set are read back.
Shape.ZERO=1e-5 -- FUN_14411b400 removes a curve at |Value| <= 1e-05; exec 0x14491efb0 then answers 0.
Shape.USE='Use: coop closet shape <morph> <0-100> | coop closet shape off'
-- A value in steps of STEP from 0 to 100.
local function clamp(v) return math.max(0,math.min(100,math.floor(v/Shape.STEP+0.5)*Shape.STEP)) end

function Shape.new(o)
    local dress,options,log=o.dress,o.options,o.log or function() end
    local store=o.store or {save=function() end,load=function() end,clear=function() end}
    local self={}
    local values={} -- Name -> % (STEP to 100); a name left out is 0.
    local names_of={} -- Mesh path -> its morph names, read once.
    local names={} -- FNames by text, made at their first use.
    local set={} -- 'part:name' (dress.parts()'s order) -> {c, name, v} as last set.
    local listed={} -- The rows' names as of the last paint.
    local wanted,seen,drawn='',nil,nil -- The values' words; applied() and the words as last put on.
    local clock,due=o.clock or os.clock,0 -- The next read back of the curves set.
    local function words()
        local list={}
        for name,v in pairs(values) do list[#list+1]=name..'='..v end
        table.sort(list)
        return table.concat(list,'\t')
    end
    for item in (store.load() or ''):gmatch('[^\t]+') do
        local name,v=item:match('^(.+)=(%d+)$')
        if name and clamp(tonumber(v))>0 then values[name]=clamp(tonumber(v)) end
    end
    wanted=words()
    local function keep()
        wanted=words()
        if wanted=='' then return store.clear() end
        local saved,why=store.save(wanted)
        if saved==false then log('shape: '..Shape.FILE..' not written: '..tostring(why)) end
    end
    local function fname(text)
        names[text]=names[text] or FName(text)
        return names[text]
    end

    -- A worn part's morph names (none while its component is gone, read again once it is there).
    local function morphs(part)
        if not part.c then return {} end
        local path=part.mesh or ''
        if names_of[path]==nil then
            local read,list=pcall(function()
                local out={}
                U.each(part.c.SkeletalMesh.MorphTargets,function(_,m)
                    m=U.valid(m)
                    if m then out[#out+1]=U.text(m:GetFName()) end
                end)
                return out
            end)
            if not read then log('shape: the morph names of '..path..' not read: '..tostring(list)) end
            names_of[path]=read and list or {}
        end
        return names_of[path]
    end
    -- One morph on a component: value % (0 removes the name).
    local function morph(c,name,v)
        local done,why=pcall(function()
            if U.valid(c) then c:SetMorphTarget(fname(name),v/100,true) end
        end)
        if not done then log('shape: '..name..' not set: '..tostring(why)) end
    end
    -- The shape on the worn parts (her body first); the names no longer wanted removed. again: set every one.
    local function paint(parts,again)
        local has,count,order,body={},{},{},{}
        for i,part in ipairs(parts) do
            has[i]={}
            for _,name in ipairs(morphs(part)) do
                if not has[i][name] then
                    has[i][name]=true
                    if not count[name] then order[#order+1]=name end
                    count[name]=(count[name] or 0)+1
                    body[name]=body[name] or i==1
                end
            end
        end
        local rows,want={},{}
        for _,name in ipairs(order) do
            if body[name] or count[name]>=2 then
                rows[#rows+1]=name
                for i,part in ipairs(parts) do
                    if values[name] and has[i][name] and (i==1 or not body[name]) then
                        want[i..':'..name]={c=part.c,name=name,v=values[name]}
                    end
                end
            end
        end
        local on,off=0,0
        for key,s in pairs(set) do
            if not want[key] then
                local keep=options and options.shaped(s.c,s.name) -- 0 to 1: the pack's ShapeKey on this component.
                morph(s.c,s.name,keep and keep*100 or 0); off=off+1
            end
        end
        for key,s in pairs(want) do
            if again or not set[key] or set[key].v~=s.v then morph(s.c,s.name,s.v); on=on+1 end
        end
        set,listed=want,rows
        if on+off>0 then
            log(('shape: %d morph(s) set, %d removed (%s)'):format(on,off,wanted~='' and wanted:gsub('\t',' ') or
                'every value 0'))
        end
    end

    -- Whether a curve set is gone, read back once a second. A curve that reads the options layer's value on that
    -- component, not ours, is gone too: after her body is rebuilt the options layer (it ticks first) wrote its value
    -- back over the name.
    local function lost()
        local now=clock()
        if now<due then return false end
        due=now+Shape.CHECK
        for _,s in pairs(set) do
            local ok,v=pcall(function() return U.valid(s.c) and s.c:GetMorphTarget(fname(s.name)) end)
            if ok and type(v)=='number' and s.v/100>Shape.ZERO then
                if math.abs(v)<=Shape.ZERO then return true end
                local theirs=options and options.shaped(s.c,s.name)
                if theirs and math.abs(v-theirs)<=Shape.ZERO and math.abs(v-s.v/100)>Shape.ZERO then return true end
            end
        end
        return false
    end
    -- Each frame: the shape put on again once the dress applied a look, a value changed or a curve set is gone.
    function self.tick()
        local gen=dress.applied()
        local same=gen==seen and wanted==drawn
        local gone=same and lost()
        if same and not gone then return end
        local parts=dress.parts()
        if not parts then return end -- Paused or stopped: the body wears another look.
        if gone then
            log('shape: a curve set is gone (a worn mesh was put on again, or the options layer wrote its value): the'
                ..' shape goes on again')
        end
        paint(parts,gen~=seen or gone)
        seen,drawn=gen,wanted
    end
    -- The Body tab's rows: the morph names the rule allows on the look as last put on.
    function self.rows() return listed end
    function self.get(name) return values[name] or 0 end
    -- coop closet shape <morph> <0-100> and the Body tab: one name's value (in steps, from 0 to 100), kept at once.
    function self.set(name,v)
        v=clamp(v)
        values[name]=v>0 and v or nil
        keep()
        log('shape: '..name..' '..v..'%')
        return true,'closet: shape '..name..' '..v..'%'
    end
    -- A step up (dir 1) or down (dir -1): left and right on its row.
    function self.step(name,dir) return self.set(name,self.get(name)+dir*Shape.STEP) end
    -- Every value 0 and the file cleared (Reset Stellar Closet, coop closet shape off).
    function self.off()
        values={}
        keep()
        log('shape: every value 0')
        return true,'closet: shape off'
    end
    -- coop off: the closet's names removed from what it set; the values stay for the next look.
    function self.stop()
        for _,s in pairs(set) do morph(s.c,s.name,0) end
        set,seen,drawn={},nil,nil
    end
    return self
end

return Shape
