-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Copies online/partner/puppet.lua's dynamic instance code (tint: CreateDynamicMaterialInstance with the slot's own
-- material and FName('None'), then SetVectorParameterValue with {R,G,B,A}, in a pcall; plain: SetMaterial with the
-- material from before; value_name's FNames made once).
-- Stellar Closet's colour layer (coop closet colour, the menu's Colour tab): one palette over every piece worn. Four
-- roles: Primary (main garments), Secondary (gloves, shoes, bands, straps, belts), Accent (jewellery, piercings,
-- rings, metal trims) and Glow (emissive). Each is off (the pack's own colours) or on with its own colour: linear R, G
-- and B in 0..1, which the Colour tab's Red, Green and Blue sliders set in STEPs (a role turned on for the first time
-- starts at DEFAULT; a role turned off keeps its colour for the next on). A material slot's
-- role is the role of the closet slot its piece sits in (Colour.SLOTS lists every closet/slots.lua slot; head slots
-- never take a role; a pack suit
-- worn whole: its PieceHints' slot, else FullOutfit, closet/dress.lua's parts), so mixed
-- outfits from different packs share one palette. Primary, Secondary and Accent set 'Base Color Tint' to the colour
-- (the slot's alpha kept). Glow sets 'EmissiveColor' on the slots of its own role (Dermal: body glows) whose glow is on
-- (not black): the colour times the glow's brightness (its largest channel), alpha kept. A slot whose glow is off keeps
-- it off. The glow of a piece in another role's slot (a jacket's, a watch's) keeps the pack's colour.
-- tick (each frame, on the game thread, menu open or not) puts the palette on when dress.applied() changes (the dress
-- made its materials and components again: the closet's instances went with them) and when the palette changes. On
-- each shown material slot of each worn component (dress.parts()) that a set role reaches:
-- CreateDynamicMaterialInstance with the slot's material (an instance already there is reused), its values read, then
-- the role's values set. A slot no set role reaches any more gets its values and its material from before back.
-- Nothing while the dress is paused (Tachy Mode) or stopped (an outside fight): the body wears another look.
-- The palette is kept in coop-closet-colour.txt (link.store) as words, one a role with a colour
-- (primary=on:0.515,0.007,0.021 glow=off:0.888,0.888,0.888), apart from the look. It is read once at new: it survives a
-- restart. A word of the swatch file before (primary=crimson) reads as that swatch's colour, on. off() (Reset Stellar
-- Closet, coop closet colour off) turns every role off, forgets the colours and clears the file. stop() (coop off)
-- forgets the instances: the dress's off gave the body its own materials back and removed the added components.
-- A slot whose pack colour control is set away from the pack's colour (o.options.owns, closet/options.lua) belongs to
-- the options layer: the palette never paints it; a record of the palette's there is forgotten, its material and
-- instance left as they are. A slot whose control is on the pack's colour (o.options.holds) gets the palette on the
-- instance both layers write: a role turned off gives back its values only, never the material (the options layer's
-- values are on that instance). tick also paints again after each options paint (o.options.revision): a slot set
-- back to the pack's colour gets the palette at once.
-- o: {dress=closet/dress.lua's (applied, parts), store=link.store(Colour.FILE), log=, options=closet/options.lua's
-- or nil}.
--
-- The game's parts, read in Ghidra (SB-Win64-Shipping.exe, build 26123051) on 26 Nov 2026:
--   UPrimitiveComponent.CreateDynamicMaterialInstance(ElementIndex int32, SourceMaterial, OptionalName FName) ->
--     MaterialInstanceDynamic: native entry 0x14662ae80 (name 0x146527a58), exec 0x1448f4660 (reads the three, calls
--     vtable +0x5b0), body FUN_1440e9330: a SourceMaterial is set on the slot first (vtable +0x590, SetMaterial's);
--     then the slot's material (vtable +0x588, GetMaterial's) is given back when it is a MaterialInstanceDynamic
--     (FUN_140f8cdf0's class) already, else a new instance of it is made (FUN_14430e740, outer the component) and set
--     on the slot. No material: null.
--   UPrimitiveComponent.SetMaterial(ElementIndex int32, Material): native entry 0x14662b380 (name 0x1466244c8), exec
--     0x1448f4c20 -> vtable +0x590. GetMaterial(ElementIndex int32) -> MaterialInterface: native entry 0x14662af60
--     (name 0x146623118), exec 0x1448f4d90 -> vtable +0x588.
--   UMaterialInstanceDynamic.SetVectorParameterValue(ParameterName FName, Value FLinearColor): native entry 0x1465e0ff0
--     (name 0x146578140), exec 0x144883770 -> FUN_14430d370 with {Name, Association 2, Index -1}: it adds or changes
--     the instance's own value (array +0xf0, 0x30 a value) and returns early when the value is the same. It never asks
--     whether the material has the parameter: a piece without it keeps its look, with no error.
--   UMaterialInstanceDynamic.K2_GetVectorParameterValue(ParameterName FName) -> FLinearColor: native entry 0x1465e0f80
--     (name 0x1465dd478), exec 0x144883460: the instance's own value, else its Parent's (+0xd0, virtual +0x3c8), else
--     (0,0,0,1). A parameter the material lacks answers (0,0,0,1): its glow reads as off.
-- The parameter names are pack data (the installed packs' *.dekcns.json VectorControls, read 26 Nov 2026): 'Base Color
-- Tint' is the cloth tint of 446 controls in 37 packs, 'EmissiveColor' the glow of 117 controls in 15 packs.
local U=require('core.unreal')
local Slots=require('closet.slots')
local Colour={}
Colour.FILE='coop-closet-colour.txt'
Colour.ROLES={'primary','secondary','accent','glow'} -- The Colour tab's rows, in order.
Colour.USE='Use: coop closet colour <primary|secondary|accent|glow> <on|off|swatch|<r> <g> <b>> | '..
    'coop closet colour off (r, g, b: 0-255)'
Colour.CHANNELS={'r','g','b'} -- The sliders under a role that is on, in order.
Colour.STEP=1/20 -- A slider's step in 0..1, as closet/options.lua's colour channels.
Colour.DEFAULT={R=0.888,G=0.888,B=0.888} -- A role's colour at its first on: the white swatch, which keeps the look.
-- Named colours (coop closet colour <role> <swatch>, the options layer's swatch cycle, the swatch file before): linear
-- RGB (the sRGB colour after each, decoded), picked to read well as a tint on cloth. White and black stay off the ends
-- of the scale, so a texture keeps its detail.
Colour.SWATCHES={
    {'white',0.888,0.888,0.888}, -- sRGB 242,242,242
    {'black',0.010,0.010,0.010}, -- sRGB 26,26,26
    {'charcoal',0.042,0.042,0.045}, -- sRGB 58,58,60
    {'silver',0.527,0.527,0.578}, -- sRGB 192,192,200
    {'gold',0.745,0.456,0.080}, -- sRGB 224,180,80
    {'crimson',0.515,0.007,0.021}, -- sRGB 190,20,40
    {'wine',0.156,0.007,0.021}, -- sRGB 110,20,40
    {'rose',0.791,0.262,0.352}, -- sRGB 230,140,160
    {'violet',0.188,0.045,0.456}, -- sRGB 120,60,180
    {'navy',0.007,0.013,0.080}, -- sRGB 20,30,80
    {'azure',0.021,0.223,0.791}, -- sRGB 40,130,230
    {'teal',0.007,0.223,0.223}, -- sRGB 20,130,130
    {'emerald',0.007,0.262,0.061}, -- sRGB 20,140,70
    {'sand',0.644,0.485,0.262}, -- sRGB 210,185,140
}
-- Every closet/slots.lua slot, once: the role whose colour it takes. none: her skin, what is painted on it, her own
-- head parts, nails and the weapon keep their colours.
Colour.SLOTS={
    primary={'SkinSuit','UndergarmentTop','UndergarmentBottom','Chest','Pants','Outerwear','Cape','Headwear',
        'FullOutfit'},
    secondary={'Legs','Shoes','Gloves','Sleeves','Belt','Garter','ThighStraps','ChestHardware','Armbands','Mask'},
    accent={'Collar','Necklace','NippleL','NippleR','Navel','BraceletL','BraceletR','Rings','ClitPiercing',
        'LabiaPiercing','AnalPlug','AnkletL','AnkletR','HairAccessory','Glasses','EarringL','EarringR','BrowPiercing',
        'NosePiercing','SeptumPiercing','LipPiercing','TonguePiercing'},
    glow={'Dermal'},
    none={'BaseBody','SkinTone','TanLines','SkinShine','TattooFull','TattooChest','TattooStomach','TattooBack',
        'TattooShoulders','TattooUpperArm','TattooForearm','TattooHand','Fingernails','TattooHips','TattooLowerBack',
        'TattooButt','PubicHair','Anus','TattooPubic','TattooThigh','TattooCalf','TattooFoot','Toenails','Face','Hair',
        'Ponytail','Ears','Eyes','Makeup','FaceTattoo','Weapon'},
}
local ROLE,IS_ROLE={},{}
for role,list in pairs(Colour.SLOTS) do
    -- The four roles stay body roles: a head slot (Slots.group) never takes one, whatever list it is in.
    for _,id in ipairs(list) do ROLE[id]=role~='none' and Slots.group(id)~='head' and role or nil end
end
for _,role in ipairs(Colour.ROLES) do IS_ROLE[role]=true end
local TINT,GLOW='Base Color Tint','EmissiveColor'
local names={} -- FNames by text, made at their first use (puppet.lua's value_name; three names only).
local function fname(text)
    names[text]=names[text] or FName(text)
    return names[text]
end

-- A slot's role, nil for none.
function Colour.role(slot) return ROLE[slot] end
-- A swatch's linear R, G, B; nothing for off or an unknown id.
function Colour.swatch(id)
    for _,s in ipairs(Colour.SWATCHES) do if s[1]==id then return s[2],s[3],s[4] end end
end
local function clamp(x) return math.max(0,math.min(1,x)) end
-- A channel value on the 1e-6 grid (as closet/options.lua's step), so steps add up without drift.
local function tidy(x) return math.floor(clamp(x)*1e6+0.5)/1e6 end
-- A channel as the file writes it: six decimals at most, trailing zeros cut, never an exponent (the reader takes
-- digits and a point only).
local function word(x) return (('%.6f'):format(x):gsub('0+$',''):gsub('%.$','')) end

function Colour.new(o)
    local dress,log=o.dress,o.log or function() end
    local store=o.store or {save=function() end,load=function() end,clear=function() end}
    local self={}
    local palette={} -- Role -> {on=bool, R, G, B}; a role left out is off with no colour yet.
    -- 'part:index' (dress.parts()'s order, the same until applied() changes) -> {c, index, original, mid,
    -- was={[name]=the value before}, set={[name]=the closet's value while it is on}}.
    local slots={}
    -- The palette's words; applied(), the words, shown() and options.revision() as last put on.
    local wanted,seen,drawn,viewed,revised='',nil,nil,nil,nil
    local function words()
        local out={}
        for _,role in ipairs(Colour.ROLES) do
            local p=palette[role]
            if p then
                out[#out+1]=('%s=%s:%s,%s,%s'):format(role,p.on and 'on' or 'off',word(p.R),word(p.G),word(p.B))
            end
        end
        return table.concat(out,' ')
    end
    for role,value in (store.load() or ''):gmatch('(%w+)=(%S+)') do
        local state,r,g,b=value:match('^(%a+):([%d.]+),([%d.]+),([%d.]+)$')
        r,g,b=tonumber(r),tonumber(g),tonumber(b)
        if not r then state,r,g,b='on',Colour.swatch(value) end -- The swatch file before.
        if IS_ROLE[role] and r and (state=='on' or state=='off') then
            palette[role]={on=state=='on',R=tidy(r),G=tidy(g),B=tidy(b)}
        end
    end
    wanted=words()
    local function keep()
        wanted=words()
        if wanted=='' then return store.clear() end
        local saved,why=store.save(wanted)
        if saved==false then log('colour: '..Colour.FILE..' not written: '..tostring(why)) end
    end

    -- A slot's dynamic instance (an instance already there is reused), its material before and the values it had;
    -- nil when the slot has no material or the engine refuses (said in the log).
    local function instance(c,index)
        local made,got=pcall(function()
            local original=U.valid(c:GetMaterial(index))
            if not original then return nil end
            local mid=U.valid(c:CreateDynamicMaterialInstance(index,original,fname('None')))
            if not mid then return nil end
            local was={}
            for _,name in ipairs({TINT,GLOW}) do
                local v=mid:K2_GetVectorParameterValue(fname(name))
                was[name]={R=v.R,G=v.G,B=v.B,A=v.A}
            end
            return {c=c,index=index,original=original,mid=mid,was=was,set={}}
        end)
        if not made then log('colour: slot '..index..' not coloured: '..tostring(got)) end
        return made and got or nil
    end
    -- One parameter of a slot: value set, or (nil) its value from before put back when the closet set it. A value
    -- already on is not sent again (puppet.lua's s.done).
    local function put(s,name,value)
        local on=s.set[name]
        if not (value or on) then return end
        if value and on and not s.force and on.R==value.R and on.G==value.G and on.B==value.B and on.A==value.A then
            return
        end
        s.set[name]=value
        local done,why=pcall(function() s.mid:SetVectorParameterValue(fname(name),value or s.was[name]) end)
        if not done then log('colour: '..name..' not set on slot '..s.index..': '..tostring(why)) end
    end
    -- A slot no set role reaches: its values from before, then its material from before (not on a slot the options
    -- layer also writes: its instance stays).
    local function give_back(s)
        -- Gone with the old world (a map change): nothing to give back.
        if not (U.valid(s.c) and U.valid(s.mid)) then return end
        for name in pairs(s.set) do put(s,name,nil) end
        if o.options and o.options.holds and o.options.holds(s.c,s.index) then return end
        local done,why=pcall(function() s.c:SetMaterial(s.index,s.original) end)
        if not done then log('colour: slot '..s.index..' not given back: '..tostring(why)) end
    end
    -- A record still on the worn component: after a map change dress.parts() gives the new EVE's Mesh before applied()
    -- grows, while the record's component and instance went with the old world.
    local function mine(s,c)
        local ok,same=pcall(function()
            return U.valid(s.c) and U.valid(s.mid) and U.valid(c) and U.address(s.c)==U.address(c)
        end)
        return s and ok and same and s or nil
    end
    local function owned(c,index) return o.options~=nil and o.options.owns(c,index) end
    -- The palette on the worn parts; the slots it no longer reaches given back.
    local function paint(parts)
        local kept,coloured,back={},0,0
        for i,part in ipairs(parts) do
            for index,slot in pairs(part.slots) do
                local role=Colour.role(slot)
                local p=role and palette[role]
                p=p and p.on and p or nil
                local tint=role~='glow' and p
                local glow=role=='glow' and p
                local key=i..':'..index
                local s=(tint or glow) and not owned(part.c,index)
                    and (mine(slots[key],part.c) or part.c and instance(part.c,index))
                if s then
                    kept[key],coloured=s,coloured+1
                    put(s,TINT,tint and {R=tint.R,G=tint.G,B=tint.B,A=s.was[TINT].A} or nil)
                    local was=s.was[GLOW]
                    local bright=math.max(was.R,was.G,was.B)
                    put(s,GLOW,glow and bright>0 and {R=glow.R*bright,G=glow.G*bright,B=glow.B*bright,A=was.A} or nil)
                end
            end
        end
        for key,s in pairs(slots) do
            if not kept[key] and not owned(s.c,s.index) then give_back(s); back=back+1 end
        end
        slots=kept
        if coloured+back>0 then
            log(('colour: %d slot(s) coloured, %d given back (%s)'):format(coloured,back,
                wanted~='' and wanted or 'every role off'))
        end
    end

    -- Each frame: the palette put on again once the dress applied a look, showed other sections of it (dress.shown,
    -- closet/options.lua's toggles: the instances kept), the palette changed or the options layer painted
    -- (options.revision: a slot set to or away from the pack's colour).
    function self.tick()
        local gen,view=dress.applied(),dress.shown and dress.shown()
        local rev=o.options and o.options.revision and o.options.revision()
        if gen==seen and wanted==drawn and view==viewed and rev==revised then return end
        local parts=dress.parts()
        if not parts then return end -- Paused or stopped: the body wears another look.
        if gen~=seen then slots={} end -- The dress made its materials and components again: ours went with them.
        -- An options paint may have written over a slot both layers write (held): its values are sent again
        -- (force), its record kept, so a role turned off still gives its value from before back.
        if rev~=revised and o.options and o.options.holds then
            for _,s in pairs(slots) do if o.options.holds(s.c,s.index) then s.force=true end end
        end
        paint(parts)
        for _,s in pairs(slots) do s.force=nil end
        seen,drawn,viewed,revised=gen,wanted,view,rev
    end
    -- A role's record, made at DEFAULT (off) when it has none.
    local function record(role)
        palette[role]=palette[role] or {on=false,R=Colour.DEFAULT.R,G=Colour.DEFAULT.G,B=Colour.DEFAULT.B}
        return palette[role]
    end
    local function changed(role)
        keep()
        local p=palette[role]
        local line=('colour %s %s %d %d %d'):format(role,p.on and 'on' or 'off',math.floor(p.R*255+0.5),
            math.floor(p.G*255+0.5),math.floor(p.B*255+0.5))
        log('colour: '..line)
        return true,'closet: '..line
    end
    -- Whether a role is on, and its colour (a copy: R, G, B in 0..1; DEFAULT for a role with none yet).
    function self.get(role)
        local p=palette[role] or Colour.DEFAULT
        return p.on==true,{R=p.R,G=p.G,B=p.B}
    end
    -- A role on or off (its colour kept), kept in the file at once.
    function self.turn(role,on)
        if not IS_ROLE[role] then return false,Colour.USE end
        record(role).on=on==true
        return changed(role)
    end
    -- One channel (r, g or b) of a role's colour set to x in 0..1 (clamped), the role turned on.
    function self.channel(role,ch,x)
        local key=({r='R',g='G',b='B'})[ch]
        if not (IS_ROLE[role] and key and type(x)=='number') then return false,Colour.USE end
        local p=record(role)
        p.on,p[key]=true,tidy(x)
        return changed(role)
    end
    -- A channel's step up (dir 1) or down (dir -1), clamped (left and right on its slider row).
    function self.step(role,ch,dir)
        local _,c=self.get(role)
        local key=({r='R',g='G',b='B'})[ch]
        if not key then return false,Colour.USE end
        return self.channel(role,ch,c[key]+dir*Colour.STEP)
    end
    -- coop closet colour <role> <on|off|swatch> or <role> <r> <g> <b> (each 0-255): the role on with that colour.
    function self.set(role,a,g,b)
        if not IS_ROLE[role] then return false,Colour.USE end
        local r=tonumber(a)
        -- Three words are R G B, all numbers; one word is on, off or a swatch.
        if g~=nil or b~=nil then
            g,b=tonumber(g),tonumber(b)
            if not (r and g and b) then return false,Colour.USE end
        elseif a=='on' or a=='off' then return self.turn(role,a=='on') end
        if r and g and b then
            r,g,b=r/255,g/255,b/255
        else
            r,g,b=Colour.swatch(a)
            if not r then
                local ids={}
                for _,s in ipairs(Colour.SWATCHES) do ids[#ids+1]=s[1] end
                return false,'closet: '..tostring(a)..' is not a colour ('..table.concat(ids,', ')..
                    ', on, off or R G B)'
            end
        end
        palette[role]={on=true,R=tidy(r),G=tidy(g),B=tidy(b)}
        return changed(role)
    end
    -- Every role off and the file cleared (Reset Stellar Closet, coop closet colour off).
    function self.off()
        palette={}
        keep()
        log('colour: every role off')
        return true,'closet: colours off'
    end
    -- coop off: the instances forgotten (the dress gave back what wore them); the palette stays for the next look.
    function self.stop() slots,seen,drawn,viewed,revised={},nil,nil,nil,nil end
    return self
end

return Colour
