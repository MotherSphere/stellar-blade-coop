-- vehicles/bike/fusion/look.lua with fake UE4SS objects (dev build): the body sits at the inverse of the part's
-- seat (seat then body lands on her mesh's origin); Fusion Strider built on SB's part: SB's mesh never drawn, body and
-- nine parts at their offsets, each slot dressed on SB's vehicle material with its textures, tint and glow, the orb
-- on SB's glass; shown and hidden together; nothing left when the body is missing.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
FName=function(t) return {type=function() return 'FName' end,ToString=function() return t end} end
local next_address=0x1000
local function object(o)
    next_address=next_address+0x100
    local at=next_address
    o=o or {}
    o.type=function() return 'UObject' end
    o.IsValid=o.IsValid or function(self) return not self.destroyed end
    o.GetAddress=function() return at end
    o.IsA=o.IsA or function() return true end
    return o
end
local assets,missing={},{}
local function asset(path)
    if missing[path] then return nil end
    assets[path]=assets[path] or object({path=path,GetFName=function() return FName(path:match('%.(.+)$')) end,
        GetFullName=function() return 'Object '..path end})
    return assets[path]
end
-- A mod pak's assets: LoadAsset never finds them (not in the game's asset registry); the registry helper's GetAsset by
-- object path loads them into memory (2026-11-19 first ride).
local pak_only,registry_asks={},{}
EFindName={FNAME_Add=1}
StaticFindObject=function(path)
    if path=='/Script/AssetRegistry.Default__AssetRegistryHelpers' then
        return object({GetAsset=function(_,data)
            local p=data.ObjectPath:ToString()
            registry_asks[#registry_asks+1]=p
            if pak_only[p] then pak_only[p]=nil; return asset(p) end
        end})
    end
    if path:find('^/Script/') then return object({path=path,MakeTransform=function() return 'identity' end}) end
    return assets[path] or object({destroyed=true})
end
LoadAsset=function(path) if pak_only[path] then return nil end return asset(path) end
local Look=require('vehicles.bike.fusion.look')

-- 0. Look.load: a pak-only asset comes through the registry; one in neither place is nil.
pak_only['/Game/Mods/T.T']=true
assert(Look.load('/Game/Mods/T.T','/Script/Engine.Texture')==assets['/Game/Mods/T.T'] and registry_asks[1]=='/Game/Mods/T.T',
    'pak-only asset loaded by object path')
missing['/Game/Mods/None.None']=true
assert(Look.load('/Game/Mods/None.None','/Script/Engine.Texture')==nil)

local function mid(parent)
    local m=object({parent=parent,s={},t={},v={}})
    function m:SetScalarParameterValue(k,v) self.s[k:ToString()]=v end
    function m:SetTextureParameterValue(k,v) self.t[k:ToString()]=v end
    function m:SetVectorParameterValue(k,v) self.v[k:ToString()]=v end
    return m
end
local actor=object({components={}})
function actor:AddComponentByClass()
    local c=object({visible=true,mats={}})
    function c:K2_AttachToComponent(p) self.parent=p end
    function c:SetStaticMesh(m)
        self.mesh=m
        -- the imported slots the cooked meshes carry
        local slots={[Look.BODY]={'M_Quantum_shell_sto01Fairing','M_Quantum_OrbGlass','M_Quantum_Glow','M_Unknown'}}
        for i,n in ipairs(slots[m.path] or {'M_Quantum_Tyre'}) do
            self.mats[i]=object({GetFName=function() return FName(n) end})
        end
    end
    function c:SetRelativeScale3D() end
    function c:SetCollisionEnabled() end
    function c:K2_SetRelativeLocationAndRotation(at,rot) self.at,self.rot=at,rot end
    function c:SetVisibility(on,kids) assert(kids==false) self.visible=on end
    function c:GetNumMaterials() return #self.mats end
    function c:GetMaterial(i) return self.mats[i+1] end
    function c:CreateDynamicMaterialInstance(i,p) local m=mid(p) self.mats[i+1]=m return m end
    function c:K2_DestroyComponent() self.destroyed=true end
    self.components[#self.components+1]=c
    return c
end
local function near(a,b) return math.abs(a-b)<1e-6 end

-- 1. The inverse seat: the part at seat on her mesh, then the body at under on the part, lands on her mesh's origin.
local seat,pitch={X=1.53,Y=0.52,Z=2.95},0.69
local at,rot=Look.under(seat,pitch)
local p=math.rad(pitch)
-- the body's origin in her mesh space: seat + R(pitch) * at
local x=seat.X+at.X*math.cos(p)-at.Z*math.sin(p)
local z=seat.Z+at.X*math.sin(p)+at.Z*math.cos(p)
assert(near(x,0) and near(seat.Y+at.Y,0) and near(z,0),'seat then under: her mesh origin')
assert(rot.Pitch==-pitch and rot.Yaw==0 and rot.Roll==0)
assert(Look.SEAT.X==1.53 and Look.SEAT_PITCH==0.69,'SB part seat kept from ride.lua')

-- 2. Built on SB's part.
local part=object({visible=true})
function part:SetVisibility(on,kids) assert(kids==false) self.visible=on end
local look=Look.build(actor,part,seat,pitch,false)
assert(part.visible==false,"SB's mesh is never drawn")
assert(#look.comps==10,'body and nine parts')
local body=look.comps[1]
assert(body.parent==part and body.mesh.path==Look.BODY and near(body.at.X,at.X) and near(body.at.Z,at.Z))
for i,c in ipairs(look.comps) do
    assert(c.visible==false,'built hidden')
    if i>1 then
        local def=Look.PARTS[i-1]
        assert(c.parent==body and c.mesh.path==def.mesh and c.at.X==def.X and c.at.Z==def.Z)
        assert(c.rot.Pitch==(def.Pitch or 0))
    end
end
assert(look.comps[9].rot.Pitch==60,'second ring turned in its plane')

-- 3. Materials: SB's vehicle material for every slot, the orb on SB's glass.
local shell,orb,glow,unknown=body.mats[1],body.mats[2],body.mats[3],body.mats[4]
assert(shell.parent.path:find('MI_Adam_vehicle_02_01',1,true) and shell.t.BaseColor.path:find('T_Quantum_03_shell_C',1,true)
    and shell.t['Baked Normal'].path:find('T_Quantum_02_N',1,true) and shell.s.Metallic==0.3 and shell.s['Roughness Max']==0.22)
assert(orb.parent.path:find('LV_MMI_Glass_A04',1,true) and orb.s.Opacity==0.14 and orb.v.GlassColor.R==0.9167)
assert(glow.t.BaseColor.path:find('WhiteSquareTexture',1,true) and glow.v['Base Color Tint'].G==0.2863
    and glow.s.EmissivePower==14 and glow.v.EmissiveColor.R==1)
assert(unknown.parent.path:find('MI_Adam_vehicle_02_01',1,true) and unknown.t.BaseColor==nil,'an unlisted slot: plain')
assert(look.slots==4+9,"every slot dressed")

-- 4. Shown and hidden together.
Look.show(look,true)
for _,c in ipairs(look.comps) do assert(c.visible==true) end
Look.show(look,false)
for _,c in ipairs(look.comps) do assert(c.visible==false) end
Look.show(nil,true) -- no look: nothing

-- 5. No pak: raises, nothing left, SB's mesh untouched.
missing[Look.BODY]=true
assets[Look.BODY].destroyed=true -- the cached one gone too
assets[Look.BODY]=nil
local part2=object({visible=true})
function part2:SetVisibility(on) self.visible=on end
local before=#actor.components
assert(not pcall(Look.build,actor,part2,seat,pitch,false))
assert(part2.visible==true and #actor.components==before,'no body: no component added, SB bike still shows')
print('fusion look_test ok')
