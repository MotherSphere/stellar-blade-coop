-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop-gun.txt's one line (fight/gunmode/mode.lua's keep and restore): what gun mode has changed in the game, so the
-- next Lua load can put it back after a Ctrl+R. Records are split by tabs, a record's fields by '|'; '%', '|', tabs and
-- line ends in a field are written as %XX. The records:
--   row|<table>|<row>|<field>|<kind>|<value>  a field of SB's rows and its value before gun mode (data.lua)
--   key|<action>|<key>|<masked key>|<index>   an action mapping masked while the rifle is out
--   pp|<body mesh>|<its own post-process class, or nothing>   a body mesh under the rifle layer (overlay.lua)
--   see|<component>|<bOwnerNoSee before>[|<tick option before>]   one of her meshes hidden from her own camera
--   follow|<component>|<her body mesh>       a mesh made to follow the posed copy (it follows her body again)
--   drone|<component>                         a part of the drone hidden while the rifle is out
--   carry|<EVE>                               the carry stance may be on (fight/gunmode/mode.lua's carry)
--   part|<component>                          a part of the posed stance (stance.lua), destroyed
--   holder|<actor>                            the actor the posed stance's donor stands on, destroyed
--   hud|<widget>                              the HUD entry or the crosshair in SB's HUD (ui/dpad.lua), taken off it
--   out                                       the rifle is out (its tagged rifle, the FOV lock)
-- Components and actors are named by their paths (their full names without the class), which StaticFindObject finds.
local Journal={}

local function escape(s) return (s:gsub('[%%|\t\r\n]',function(c) return ('%%%02X'):format(c:byte()) end)) end
local function unescape(s) return (s:gsub('%%(%x%x)',function(h) return string.char(tonumber(h,16)) end)) end

-- records: a list of lists of strings.
function Journal.line(records)
    local out={}
    for _,r in ipairs(records) do
        local f={}
        for i,v in ipairs(r) do f[i]=escape(v) end
        out[#out+1]=table.concat(f,'|')
    end
    return table.concat(out,'\t')
end

function Journal.records(line)
    local out={}
    for record in ((line or '')..'\t'):gmatch('([^\t]*)\t') do
        if record~='' then
            local f={}
            for v in (record..'|'):gmatch('([^|]*)|') do f[#f+1]=unescape(v) end
            out[#out+1]=f
        end
    end
    return out
end

-- A field's value before gun mode, as a kind and a text: d a number (exact; a whole float reads back as an integer,
-- which a float field takes as it is), b a boolean, s a string,
-- v a vector, n an FName (data.lua keeps those as FName(text)). The fields data.lua changes read in Lua as one of these
-- on 26123051: byte enums such as CommandActionType (its property at 0x145dfa6a8), SkillCommandTable's bJumping (a
-- byte too, 0x145dfa3b0) and Condition_Jumping (0x145e004b8), floats such as CoolTime (0x145df2820), FNames such as
-- ActorEffectAlias (0x145e02b10) and vector structs such as DestTargetRelativeLocation (0x145dffe40). FStrings such as
-- ActionValue1 (0x145df9548) are kept as text. None of them is a boolean. Anything else raises.
function Journal.value(v)
    local t=type(v)
    if t=='number' then return 'd',math.type(v)=='integer' and tostring(v) or ('%.17g'):format(v) end
    if t=='boolean' or t=='string' then return t:sub(1,1),tostring(v) end
    if t=='table' and type(v.X)=='number' then return 'v',('%.17g,%.17g,%.17g'):format(v.X,v.Y,v.Z) end
    if t=='userdata' or t=='table' then
        local ok,text=pcall(function() assert(v:GetComparisonIndex()~=nil); return v:ToString() end)
        if ok and type(text)=='string' then return 'n',text end
    end
    error('a '..t..' value cannot be kept in coop-gun.txt',0)
end

function Journal.parse(kind,text)
    if kind=='d' then return assert(tonumber(text),'not a number: '..text) end
    if kind=='b' then return text=='true' end
    if kind=='s' then return text end
    if kind=='n' then return FName(text) end
    if kind=='v' then
        local x,y,z=text:match('^([^,]+),([^,]+),([^,]+)$')
        return {X=assert(tonumber(x)),Y=assert(tonumber(y)),Z=assert(tonumber(z))}
    end
    error('unknown kind '..tostring(kind),0)
end

return Journal
