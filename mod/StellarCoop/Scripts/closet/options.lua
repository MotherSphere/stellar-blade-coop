-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Copies closet/colour.lua's dynamic instance code (instance, put, mine and the paint loop over dress.parts(); the tick
-- that paints again when dress.applied() or the values change), without its values from before: this layer always
-- writes the pack value or the kept one.
-- Stellar Closet's options layer (the Full outfit tab's options page, coop closet option): per pack outfit (its
-- UniqueFitID) the variant worn and, per variant, its values. A toggle (key 'toggle:<material slot>') starts
-- from the pack's value (closet/fits.lua's Toggles: of two toggles on one slot an off one wins). The material values
-- are keyed by the control's place in its UserConfigs list: 'colour:<n>' (VectorControls, {R, G, B, A}, custom=true
-- when picked as Custom), 'finish:<n>' (TextureOptions, the option's index from 0), 'number:<n>' (ScalarControls) and
-- 'shape:<n>' (ShapeKeys). Each starts from the pack's Value; only a value that differs from it is kept. A follower
-- (ControlledBy, Fits.leader) has no value of its own: it takes its leader's.
-- toggles() hands closet/dress.lua's plans {[fit]={[slot]=shown}} for the outfits with a kept value or a follower, in
-- the variant each wears. The variant goes to closet/fits.lua (Fits.choose): the outfit's fit is made from it, so
-- every wear plans it.
-- Ranges: a colour channel from its Min to its Max (0..1 when left out) in steps of 1/20 of that range; a number or a
-- shape key from Min to Max (0..1) in its pack Step, else 1/20 of the range. A pack value outside its range (an HDR
-- default above Max) stays until it is moved: a step puts it in the range. A colour's choice is Pack colour, one of
-- closet/colour.lua's SWATCHES (its RGB, the pack's alpha) or Custom (its channels). A finish whose texture does not
-- load is left out (finishes), said once.
-- tick (each frame, on the game thread, before the colour layer's): a variant change of a worn outfit puts the look on
-- again (dress.again), a toggle change of one shows its sections (dress.reshow, applied() kept); a change that cannot
-- show now (a game look on, no EVE, a failed apply) is asked again at the next tick. Then, when dress.applied() or a
-- value changed, every material value and shape key of each worn pack outfit is written on its component (the pack
-- value or the kept one, so no value another mod set stays): each colour, number and finish on its slot's dynamic
-- instance, each shape key (ShapeKeyName, else DisplayName) with SetMorphTarget. A value already written is not sent
-- again. Once a second (CHECK) the shape keys written are read back (GetMorphTarget, as closet/shape.lua does): a worn
-- mesh put on again (gun mode's rebuild of her body) empties the curves while applied() stays, so a gone one writes
-- every shape key again. A shape key counts as gone only when it reads 0 for a value written away from 0: another value
-- is another writer's (the Body tab's shape on the same name, another mod) and is left alone.
-- holds(component, slot) says whether a worn pack outfit has a colour control on that slot; owns, whether that
-- control is set away from the pack's colour: closet/colour.lua's palette leaves an owned slot alone and paints a held
-- one on the same instance. After each pack scan it says once each kept value
-- whose outfit, variant or control is gone: that value is ignored and stays in the file (the pack may come back). A
-- variant whose mesh does not load (dress.loads) is never worn: set_variant refuses it, a kept one is replaced by the
-- first after the scan (said once, kept in the file).
-- The values are kept in coop-closet-options.txt (link.store) as words split by tabs, '<fit> variant=<n>' and
-- '<fit> <variant> <key>=<value>' (on|off, r,g,b,a with custom: before it for a Custom colour, a number), sorted, each
-- fit id as Fits.word gives it. They are read once at new. reset(fit) gives one outfit its pack values back, off() (Reset Stellar Closet) every outfit and
-- clears the file. stop() (coop off) drops the changes not shown yet and removes the shape keys it set: the dress gave
-- EVE her own look back.
-- o: {dress=closet/dress.lua's (plan, again, reshow, loads, applied, parts), store=link.store(Options.FILE), log=,
-- clock= (os.clock)}.
--
-- The game's parts, read in Ghidra (SB-Win64-Shipping.exe, build 26123051) on 26 Nov 2026:
--   UPrimitiveComponent.GetMaterial, CreateDynamicMaterialInstance and
--     UMaterialInstanceDynamic.SetVectorParameterValue: as closet/colour.lua's comment says (native entries
--     0x14662af60, 0x14662ae80, 0x1465e0ff0, read again).
--   UMaterialInstanceDynamic.SetScalarParameterValue(ParameterName FName, Value float): native entry 0x1465e0fb0 (name
--     0x146577870), exec 0x144884430 reads the name and the float and calls FUN_14430d4a0 with {Name, Association 2,
--     Index -1}, as the vector one does.
--   UMaterialInstanceDynamic.SetTextureParameterValue(ParameterName FName, Value Texture): native entry 0x1465e0fd0
--     (name 0x1465dd3a8), exec 0x144883de0 reads the name and an object and calls FUN_14430e910(this, name, it).
--   USkeletalMeshComponent.SetMorphTarget(MorphTargetName FName, Value float, bRemoveZeroWeight bool): native entry
--     0x146659b90 (name 0x1464d8d18), exec 0x14491f120, as closet/shape.lua's comment says: with bRemoveZeroWeight a
--     value of 0 removes the curve. GetMorphTarget(MorphTargetName FName) -> float: native entry 0x146659830 (name
--     0x1466546c0), exec 0x14491efb0 answers the name's value in the curves at +0xec8, else 0.
--   A finish's texture: found in memory (StaticFindObject), else after UE4SS's LoadAsset, used only when it is a
--     UTexture2D (closet/ui/view.lua's find and class; its tiles load a texture path through LoadAsset_Blocking,
--     native entry 0x1465b5cb0, name 0x1465a59e8, exec 0x14482cf00, read again).
local U=require('core.unreal')
local Fits=require('closet.fits')
local Colour=require('closet.colour')
local Options={}
Options.FILE='coop-closet-options.txt'
Options.CHECK=1 -- s: how often the shape keys written are read back.
Options.ZERO=1e-5 -- FUN_14411b400 removes a curve at |Value| <= 1e-05; exec 0x14491efb0 then answers 0.
Options.USE='Use: coop closet option <fit> variant <n> | coop closet option <fit> toggle <slot> on|off'
-- A key's kind -> the UserConfigs list of its controls.
local LISTS={colour='VectorControls',finish='TextureOptions',number='ScalarControls',shape='ShapeKeys'}
local CHANNEL={r=1,g=2,b=3,a=4}
local RGBA={'R','G','B','A'}
local SETTER={colour='SetVectorParameterValue',number='SetScalarParameterValue',finish='SetTextureParameterValue'}
local TEXTURE='/Script/Engine.Texture2D'

local function split(key)
    local kind,n=tostring(key):match('^(%a+):(%d+)$')
    return kind,tonumber(n)
end
local function index_of(t)
    local i=type(t)=='table' and type(t.MaterialIndex)=='number' and math.tointeger(t.MaterialIndex)
    return i and i>=0 and i or nil
end
local function num(x,d) return type(x)=='number' and x or d end
local function copy(x)
    if type(x)~='table' then return x end
    local t={}
    for k,v in pairs(x) do t[k]=v end
    return t
end
-- Two values alike: colours channel by channel (and both Custom or not), numbers within 1e-6, else the same.
local function alike(a,b)
    if type(a)=='table' and type(b)=='table' and type(a.R)=='number' and type(b.R)=='number' then
        for _,k in ipairs(RGBA) do if math.abs(a[k]-b[k])>1e-6 then return false end end
        return not a.custom==not b.custom
    end
    return a==b or type(a)=='number' and type(b)=='number' and math.abs(a-b)<=1e-6
end
local function n6(x) return ('%.6g'):format(x) end
-- A value as its file word, and back (nil when it does not read).
local function word(v)
    if type(v)=='boolean' then return v and 'on' or 'off' end
    if type(v)=='table' then
        return (v.custom and 'custom:' or '')..table.concat({n6(v.R),n6(v.G),n6(v.B),n6(v.A)},',')
    end
    return n6(v)
end
local function parse(kind,text)
    if kind=='toggle' then
        if text=='on' then return true elseif text=='off' then return false end
        return nil
    elseif kind=='colour' then
        local custom,rest=text:match('^(custom:)(.*)$')
        local c={}
        for x in (rest or text):gmatch('[^,]+') do c[#c+1]=tonumber(x) end
        if #c~=4 or not (c[1] and c[2] and c[3] and c[4]) then return nil end
        return {R=c[1],G=c[2],B=c[3],A=c[4],custom=custom and true or nil}
    elseif kind=='finish' then
        local i=math.tointeger(tonumber(text))
        return i and i>=0 and i or nil
    end
    return LISTS[kind] and tonumber(text) or nil
end
-- A control of an outfit by key, its kind and place; nil when the outfit has none there.
local function control(fit,key)
    local f,kind,n=Fits.get(fit),split(key)
    local list=LISTS[kind] and f and f.Controls and f.Controls[LISTS[kind]]
    local c=type(list)=='table' and list[n]
    return type(c)=='table' and c or nil,kind,n
end

function Options.new(o)
    local dress,log=o.dress,o.log or function() end
    local store=o.store or {save=function() end,load=function() end,clear=function() end}
    local self={}
    local values={} -- '<fit> <variant>' -> {[key]=value}, the values that differ from the pack's.
    local variants={} -- fit -> the variant chosen, 2 or more.
    local redress,reshow={},{} -- Fits whose variant or toggles changed since the last tick.
    local said,checked={},nil -- Gone values said; Fits.PACKS as of the last check.
    -- 'part:slot' (dress.parts()'s order) -> {c, index, mid, set={['kind|name']=value written}}; 'part:name' -> {c,
    -- name, v} of each shape key written; 'address:slot' of each slot with a pack colour control.
    local slots,morphs,owned,held={},{},{},{}
    -- changed: grows with each value change; seen, drawn, painted: applied(), changed and Fits.PACKS as last written.
    local changed,seen,drawn,painted=0,nil,nil,nil
    local clock,due=o.clock or os.clock,0 -- The next read back of the shape keys written.
    local names,textures={},{} -- FNames by text; finish textures by path (false: does not load).
    local function fname(text)
        names[text]=names[text] or FName(text)
        return names[text]
    end
    local function say(line)
        if said[line] then return end
        said[line]=true
        log(line)
    end
    for item in (store.load() or ''):gmatch('[^\t]+') do
        local fit,v=item:match('^(%S+) variant=(%d+)$')
        if fit then
            fit=Fits.unword(fit)
            variants[fit]=tonumber(v)
            Fits.choose(fit,variants[fit])
        else
            local key,text
            fit,v,key,text=item:match('^(%S+) (%d+) (%S+)=(%S+)$')
            fit=fit and Fits.unword(fit)
            local kind=fit and split(key)
            local value=kind and parse(kind,text)
            if value~=nil then
                values[fit..' '..v]=values[fit..' '..v] or {}
                values[fit..' '..v][key]=value
            end
        end
    end
    local function keep()
        changed=changed+1
        local out={}
        for fit,v in pairs(variants) do out[#out+1]=Fits.word(fit)..' variant='..v end
        for at,set in pairs(values) do
            local fit,v=at:match('^(.+) (%d+)$')
            for key,value in pairs(set) do out[#out+1]=Fits.word(fit)..' '..v..' '..key..'='..word(value) end
        end
        table.sort(out)
        if #out==0 then return store.clear() end
        local saved,why=store.save(table.concat(out,'\t'))
        if saved==false then log('options: '..Options.FILE..' not written: '..tostring(why)) end
    end
    -- The pack's value of a key, nil when the outfit has no such toggle or control.
    local function default(fit,key)
        local kind,i=split(key)
        if kind=='toggle' then
            local f=Fits.get(fit)
            return f and i and f.Toggles and f.Toggles[i]
        end
        local c=control(fit,key)
        if not c then return nil end
        if kind=='colour' then
            local v=type(c.Value)=='table' and c.Value or {}
            return {R=num(v[1],1),G=num(v[2],1),B=num(v[3],1),A=num(v[4],1)}
        elseif kind=='finish' then
            local at=math.tointeger(num(c.Value,0))
            return at and at>=0 and at or 0
        end
        return num(c.Value,num(c.Min,0))
    end
    local function what(key)
        local kind,i=split(key)
        return kind=='toggle' and 'toggle on slot '..tostring(i) or tostring(kind)..' '..tostring(i)
    end
    -- After a pack scan: each kept value whose outfit, variant or control is gone, said once.
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
            local fit,v=at:match('^(.+) (%d+)$')
            local f=Fits.PACKS[fit]
            if not f then say('options: '..fit..' is not installed: its saved options are ignored')
            elseif not (f.Variants or {})[tonumber(v)] then
                say('options: '..fit..' has no variant '..v..': its saved options are ignored')
            else
                for key in pairs(set) do
                    if default(fit,key)==nil then say('options: '..fit..' has no '..what(key)..': ignored') end
                end
            end
        end
    end
    -- A finish's texture, nil when it does not load (said once; a texture the engine freed is found again).
    local function texture(path)
        local t=textures[path]
        if t==false then return nil end
        if t and U.valid(t) then return t end
        local ok,got=pcall(function()
            local x=U.valid(StaticFindObject(path))
            if not x then
                pcall(LoadAsset,path)
                x=U.valid(StaticFindObject(path))
            end
            return x and x:IsA(U.find(TEXTURE)) and x or nil
        end)
        textures[path]=ok and got or false
        if not textures[path] then
            log('options: '..tostring(path)..' does not load ('..(ok and 'not a Texture2D or not found' or
                tostring(got))..'): that finish is left out')
        end
        return textures[path] or nil
    end

    -- A key's value for an outfit in variant v: the kept one, else the pack's (nil: no such toggle or control).
    function self.get(fit,v,key)
        local mine=values[fit..' '..v] and values[fit..' '..v][key]
        if mine~=nil then return copy(mine) end
        return default(fit,key)
    end
    -- The pack's value of a key (nil: none).
    function self.default(fit,key) return default(fit,key) end
    -- One key's value, kept only when it differs from the pack's; true and a line, or false and why.
    function self.set(fit,v,key,value)
        local pack=default(fit,key)
        if pack==nil or type(pack)~=type(value) then return false,'closet: '..tostring(fit)..' has no '..what(key) end
        local at=fit..' '..v
        values[at]=values[at] or {}
        if alike(value,pack) then values[at][key]=nil else values[at][key]=copy(value) end
        if next(values[at])==nil then values[at]=nil end
        keep()
        if split(key)=='toggle' then reshow[fit]=true end
        local line=('closet: %s variant %d %s %s'):format(fit,v,key,word(value))
        log('options: '..line)
        return true,line
    end
    -- A key's range and step (a colour's for channel ch: r, g, b or a); nil for a key with no range.
    function self.range(fit,key,ch)
        local c,kind=control(fit,key)
        if not c or kind=='finish' then return nil end
        local lo,hi,step
        if kind=='colour' then
            local i=CHANNEL[ch]
            if not i then return nil end
            lo=num((type(c.Min)=='table' and c.Min or {})[i],0)
            hi=num((type(c.Max)=='table' and c.Max or {})[i],1)
            step=(hi-lo)/20
        else
            lo,hi=num(c.Min,0),num(c.Max,1)
            step=num(c.Step,0)>0 and c.Step or (hi-lo)/20
        end
        return lo,hi,step
    end
    -- A step up (dir 1) or down (dir -1) of a number, a shape key or a colour's channel ch (the colour becomes
    -- Custom), clamped to its range.
    function self.step(fit,v,key,dir,ch)
        local lo,hi,step=self.range(fit,key,ch)
        if not lo then return false,'closet: '..tostring(fit)..' has no '..what(key) end
        local function move(x) return math.floor(math.max(lo,math.min(hi,x+dir*step))*1e6+0.5)/1e6 end
        local value=self.get(fit,v,key)
        if type(value)=='table' then
            value.custom=true
            value[RGBA[CHANNEL[ch]]]=move(value[RGBA[CHANNEL[ch]]])
        else
            value=move(value)
        end
        return self.set(fit,v,key,value)
    end
    -- A colour's choice: 'pack', a swatch id or 'custom'; nil when the outfit has no colour i.
    function self.choice(fit,v,i)
        local value,pack=self.get(fit,v,'colour:'..i),default(fit,'colour:'..i)
        if not value then return nil end
        if value.custom then return 'custom' end
        if alike(value,pack) then return 'pack' end
        for _,s in ipairs(Colour.SWATCHES) do
            if math.abs(value.R-s[2])<=1e-6 and math.abs(value.G-s[3])<=1e-6 and math.abs(value.B-s[4])<=1e-6 then
                return s[1]
            end
        end
        return 'custom'
    end
    -- The choice after (dir 1) or before (dir -1) colour i's in the cycle Pack colour, SWATCHES, Custom.
    function self.cycle(fit,v,i,dir)
        local key='colour:'..i
        local now,pack=self.choice(fit,v,i),default(fit,key)
        if not now then return false,'closet: '..tostring(fit)..' has no '..what(key) end
        local order={'pack'}
        for _,s in ipairs(Colour.SWATCHES) do order[#order+1]=s[1] end
        order[#order+1]='custom'
        local at=1
        for k,id in ipairs(order) do if id==now then at=k end end
        local to=order[(at-1+dir)%#order+1]
        local value=pack
        if to=='custom' then
            value=self.get(fit,v,key)
            value.custom=true
        elseif to~='pack' then
            local r,g,b=Colour.swatch(to)
            value={R=r,G=g,B=b,A=pack.A}
        end
        return self.set(fit,v,key,value)
    end
    -- The options of finish i whose texture loads, as indexes from 0.
    function self.finishes(fit,i)
        local c=control(fit,'finish:'..i)
        local out={}
        for j,path in ipairs(c and type(c.Textures)=='table' and c.Textures or {}) do
            if type(path)=='string' and texture(path) then out[#out+1]=j-1 end
        end
        return out
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
    -- {[fit]={[slot]=shown}}: every toggle's value, a follower's its leader's, for the outfits with a kept toggle in
    -- the variant they wear or a follower.
    function self.toggles()
        local out={}
        for id,fit in pairs(Fits.PACKS) do
            local list=fit.Controls and fit.Controls.MaterialToggles or {}
            local set=values[id..' '..tostring(fit.Variant)]
            local any=false
            for key in pairs(set or {}) do any=any or split(key)=='toggle' end
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
    -- The kept values of an outfit in variant v as file words ('<key>=<value>', sorted): closet/presets.lua keeps them.
    function self.words(fit,v)
        local out={}
        for key,value in pairs(values[fit..' '..v] or {}) do out[#out+1]=key..'='..word(value) end
        table.sort(out)
        return out
    end
    -- Those words back as an outfit's kept values in variant v; every other value of it there is the pack's again. A
    -- word that does not read is left out.
    function self.take(fit,v,list)
        local set={}
        for _,item in ipairs(list) do
            local key,text=tostring(item):match('^(%S+)=(%S+)$')
            local kind=key and split(key)
            local value=kind and parse(kind,text)
            if value~=nil then set[key]=value end
        end
        values[fit..' '..v]=next(set) and set or nil
        keep()
        reshow[fit]=true
        log('options: '..fit..' variant '..v..' takes '..#list..' kept value(s)')
        return true
    end
    -- One outfit's pack values back: every variant's values and the first variant.
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
        for at in pairs(values) do reshow[at:match('^(.+) %d+$')]=true end
        values,variants={},{}
        keep()
        log('options: every outfit back to its pack values')
        return true,'closet: options off'
    end
    -- Whether a worn pack outfit has a colour control on slot index of component c (as last written): holds; owns when
    -- that control is set away from the pack's colour (closet/colour.lua's palette leaves only those slots alone).
    local function at_slot(map,c,index)
        local ok,at=pcall(U.address,c)
        return ok and map[tostring(at)..':'..tostring(index)]==true
    end
    function self.holds(c,index) return at_slot(held,c,index) end
    function self.owns(c,index) return at_slot(owned,c,index) end
    -- Grows with each paint (a value change, a new look, a pack rescan): closet/colour.lua paints after each.
    local paints=0
    function self.revision() return paints end
    -- The value (0 to 1) of the shape key name last written on component c, or nil: closet/shape.lua puts it back.
    -- By address, as mine() compares: each read of her body (dress.parts) is a new UE4SS wrapper.
    function self.shaped(c,name)
        local ok,at=pcall(U.address,c)
        if not ok then return nil end
        for _,m in pairs(morphs) do
            if m.name==name then
                local same,mat=pcall(U.address,m.c)
                if same and mat==at then return m.v end
            end
        end
    end

    -- A slot's dynamic instance (an instance already there is reused); nil when the slot has no material or the
    -- engine refuses (said in the log).
    local function instance(c,index)
        local made,got=pcall(function()
            local material=U.valid(c:GetMaterial(index))
            if not material then return nil end
            local mid=U.valid(c:CreateDynamicMaterialInstance(index,material,fname('None')))
            return mid and {c=c,index=index,mid=mid,set={}} or nil
        end)
        if not made then log('options: slot '..index..' not set: '..tostring(got)) end
        return made and got or nil
    end
    -- One parameter of a slot; a value already on is not sent again.
    local function put(s,kind,name,value)
        local at=kind..'|'..name
        local on=s.set[at]
        if on~=nil and (on==value or alike(on,value)) then return end
        s.set[at]=value
        local done,why=pcall(function() s.mid[SETTER[kind]](s.mid,fname(name),value) end)
        if not done then log('options: '..name..' not set on slot '..s.index..': '..tostring(why)) end
    end
    -- A record still on the worn component (closet/colour.lua's mine).
    local function mine(s,c)
        local ok,same=pcall(function()
            return U.valid(s.c) and U.valid(s.mid) and U.valid(c) and U.address(s.c)==U.address(c)
        end)
        return s and ok and same and s or nil
    end
    -- One shape key on a component (0 removes the curve).
    local function morph(c,name,v)
        local done,why=pcall(function()
            if U.valid(c) then c:SetMorphTarget(fname(name),v,true) end
        end)
        if not done then log('options: shape key '..name..' not set: '..tostring(why)) end
    end
    -- A control's value in variant v: its leader's when it follows one (ControlledBy).
    local function value_of(fit,v,kind,list,c)
        local lead=Fits.leader(list,c)
        for n,x in ipairs(list) do
            if x==lead then return self.get(fit,v,kind..':'..n) end
        end
    end
    -- Every material value and shape key of each worn pack outfit on its component.
    local function paint(parts)
        local kept,mine_now,held_now,shaped={},{},{},{}
        local wrote=0
        for i,part in ipairs(parts) do
            local f=part.c and Fits.PACKS[part.fit]
            local cfg=f and f.Controls
            local ok,address=pcall(U.address,part.c)
            if cfg and ok then
                for _,kind in ipairs({'colour','number','finish'}) do
                    local list=type(cfg[LISTS[kind]])=='table' and cfg[LISTS[kind]] or {}
                    for n,c in ipairs(list) do
                        local index=index_of(c)
                        local name=index and type(c.ParamName)=='string' and c.ParamName
                        if name then
                            local value=value_of(part.fit,f.Variant,kind,list,c)
                            if kind=='colour' then
                                held_now[tostring(address)..':'..index]=true
                                if not alike(value,default(part.fit,'colour:'..n)) then
                                    mine_now[tostring(address)..':'..index]=true
                                end
                            end
                            if kind=='colour' then value={R=value.R,G=value.G,B=value.B,A=value.A}
                            elseif kind=='finish' then
                                local path=type(c.Textures)=='table' and c.Textures[value+1]
                                value=type(path)=='string' and texture(path) or nil
                            end
                            local key=i..':'..index
                            local s=kept[key] or mine(slots[key],part.c) or instance(part.c,index)
                            if s then
                                kept[key]=s
                                if value~=nil then put(s,kind,name,value); wrote=wrote+1 end
                            end
                        end
                    end
                end
                local list=type(cfg.ShapeKeys)=='table' and cfg.ShapeKeys or {}
                for _,c in ipairs(list) do
                    local name=type(c)=='table' and (type(c.ShapeKeyName)=='string' and c.ShapeKeyName~='' and
                        c.ShapeKeyName or type(c.DisplayName)=='string' and c.DisplayName~='' and c.DisplayName)
                    if name then
                        local value=value_of(part.fit,f.Variant,'shape',list,c)
                        local key=i..':'..name
                        local was=morphs[key]
                        shaped[key]={c=part.c,name=name,v=value}
                        if not (was and was.v==value) then morph(part.c,name,value); wrote=wrote+1 end
                    end
                end
            end
        end
        slots,morphs,owned,held=kept,shaped,mine_now,held_now
        return wrote
    end
    -- A variant or toggle change of a worn outfit shown; one that cannot show now is asked again at the next tick.
    local function show()
        if next(redress)==nil and next(reshow)==nil then return end
        local plan=dress.plan()
        local worn={}
        if plan then
            worn[plan.body.fit]=true
            for _,a in ipairs(plan.added) do worn[a.fit]=true end
        end
        local again,shown=false,false
        for fit in pairs(redress) do again=again or worn[fit]==true end
        for fit in pairs(reshow) do shown=shown or worn[fit]==true end
        local done,why=true,nil
        if again then done,why=dress.again() elseif shown then done,why=dress.reshow() end
        if not done then return say('options: the change waits: '..tostring(why)) end
        redress,reshow={},{}
    end
    -- Whether a shape key written is gone, read back once a second.
    local function lost()
        local now=clock()
        if now<due then return false end
        due=now+Options.CHECK
        for _,m in pairs(morphs) do
            local ok,v=pcall(function() return U.valid(m.c) and m.c:GetMorphTarget(fname(m.name)) end)
            if ok and type(v)=='number' and math.abs(v)<=Options.ZERO and math.abs(m.v)>Options.ZERO then
                return true
            end
        end
        return false
    end
    function self.tick()
        check()
        show()
        local gen=dress.applied and dress.applied()
        if gen==nil then return end
        local same=gen==seen and changed==drawn and Fits.PACKS==painted
        local gone=same and lost()
        if same and not gone then return end
        local parts=dress.parts()
        if not parts then return end -- Paused or stopped: the body wears another look.
        if gen~=seen then slots,morphs={},{} end -- A new look: its components and instances are new.
        if gone then -- The curves went with a worn mesh put on again: every shape key is written again.
            morphs={}
            log('options: a shape key written is gone (a worn mesh was put on again): written again')
        end
        local wrote=paint(parts)
        paints=paints+1
        seen,drawn,painted=gen,changed,Fits.PACKS
        if wrote>0 then log(('options: %d value(s) written'):format(wrote)) end
    end
    -- coop off: the changes not shown yet dropped, the shape keys set removed; the values stay for the next look.
    function self.stop()
        redress,reshow={},{}
        for _,m in pairs(morphs) do morph(m.c,m.name,0) end
        slots,morphs,owned,held,seen={},{},{},{},nil
    end
    return self
end

return Options
