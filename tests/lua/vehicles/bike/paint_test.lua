-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- vehicles/bike/paint.lua with fake UE4SS objects, built as vehicles/bike/stand_test.lua builds them: the shipped table
-- passes its check and holds one entry; the check takes a name with spaces (Base Color Tint), punctuation (A_b-1) or a
-- '}', the top byte the capture sends; it refuses a slot out of 0 to 3, an empty or long name, a control character, a
-- '~' or a byte above '~' in a name, a value that is not four numbers from 0 to 100000 and a key that is no object
-- path; apply makes each instance from the mesh's own material; step runs once a second, paints a component once per
-- mesh and clears it once for a mesh with no entry; a new Lua load clears an earlier load's instance; a component at
-- another address, or at the same address with another path, is a new one; a failing call logs one line and leaves the
-- slot as the mesh made it.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
FName=function(t) return {type=function() return 'FName' end,ToString=function() return t end} end
local next_address=0x1000
local function object(fields)
    next_address=next_address+0x100
    local at=next_address
    local o=fields or {}
    o.type=function() return 'UObject' end
    o.IsValid=o.IsValid or function(self) return not self.destroyed end
    o.GetAddress=function() return o.at or at end
    return o
end
local own={} -- The bike mesh's own material in each slot.
for slot=0,3 do own[slot]=object({}) end
-- A bike component (o.at: its address, o.path: its object path, o.fail: CreateDynamicMaterialInstance raises). It
-- records each instance made (made by slot, made_list), each value set on one, each SetMaterial (set by slot, set_list)
-- and what each slot shows now (current).
local parts=0
local function fake(o)
    o=o or {}
    parts=parts+1
    local mesh=object({Materials={}})
    for slot=0,3 do mesh.Materials[slot+1]={MaterialInterface=own[slot]} end
    local c=object({SkeletalMesh=mesh,made={},made_list={},set={},set_list={},current={},at=o.at})
    for slot=0,3 do c.current[slot]=own[slot] end
    local path=o.path or ('/Game/Map.Map:PersistentLevel.Bike.Part_'..parts)
    function c:GetFullName() return 'SkeletalMeshComponent '..path end
    function c:CreateDynamicMaterialInstance(slot,base,name)
        assert(name:ToString()=='None')
        if o.fail then error('no instance',0) end
        local mid=object({base=base,values={}})
        function mid:SetVectorParameterValue(n,v) self.values[n:ToString()]=v end
        self.made[slot],self.made_list[#self.made_list+1],self.current[slot]=mid,mid,mid
        return mid
    end
    function c:SetMaterial(slot,m) self.set[slot],self.set_list[#self.set_list+1],self.current[slot]=m,m,m end
    return c
end

local Paint=require('vehicles.bike.paint')
assert(Paint.SLOTS==4 and Paint.MAX==1e5 and Paint.EVERY==1)
local M='/Game/Art/Character/PC/CH_P_EVE_IberisCostume/CH_P_EVE_IberisCos.CH_P_EVE_IberisCos'
local OTHER='/Game/Art/Character/PC/CH_P_EVE_01/Mesh/EVE.EVE'
assert(Paint.BY_MESH[M] and Paint.BY_MESH[M][1]['Base Color Tint'],'The example entry: Gothic Rose tints slot 1')
local S=next(Paint.BY_MESH[M])
-- The check.
assert(Paint.check(Paint.BY_MESH))
local n=0; for _ in pairs(Paint.BY_MESH) do n=n+1 end; assert(n==1)
assert(not Paint.check({[M]={[4]={P={0,0,0,1}}}}) and not Paint.check({[M]={[-1]={P={0,0,0,1}}}}))
assert(not Paint.check({[M]={[0]={['']={0,0,0,1}}}}) and not Paint.check({[M]={[0]={P={0,0,0}}}}))
assert(not Paint.check({[M]={[0]={P={0,0,'x',1}}}}) and not Paint.check({[M]={[0]={P={0,0,0,2e5}}}}))
assert(not Paint.check({[M]={[0]={[('x'):rep(65)]={0,0,0,1}}}}) and not Paint.check({[M]={[0]={['a\tb']={0,0,0,1}}}}))
assert(not Paint.check({[M]={[0]={['a~b']={0,0,0,1}}}}),'~ stands for a space in the capture')
assert(Paint.check({[M]={[0]={['Base Color Tint']={0,0,0,1}}}}),'A name with spaces passes: the capture sends it')
assert(not Paint.check({[M]={[0]={['a\128b']={0,0,0,1}}}}),'A byte above ~ is refused: the capture drops it')
assert(Paint.check({[M]={[0]={['A_b-1']={0,0,0,1}}}}),'Punctuation passes: the capture sends it')
assert(Paint.check({[M]={[0]={['a}b']={0,0,0,1}}}}),'} passes: the capture sends it')
assert(not Paint.check({['Adam_Vehicle_02']={[0]={P={0,0,0,1}}}}))
assert(not Paint.check({[M]={[0]={P={0,0,0/0,1}}}}) and not Paint.check({[M]={[0]={P={0,-1,0,1}}}}))
assert(not Paint.check({[M]={[0.5]={P={0,0,0,1}}}}),'A slot is an integer')
assert(Paint.check({[M]={[0]={[('x'):rep(64)]={0,0,0,1e5}}}}),'64 bytes and 100000 pass')
local ok,why=Paint.check({[M]={[0]={['a\tb']={0,0,0,1}}}})
assert(not ok and why:find('a\tb',1,true),why)
-- apply: slots 0 and 2 only, each instance made from the mesh's own material.
local c=fake()
Paint.apply(c,{[0]={P={0.5,0,0,1}},[2]={Q={0,0.5,0,1}}})
assert(c.made[0].base==own[0] and c.made[0].values.P.R==0.5 and c.made[2].values.Q.G==0.5 and c.made[1]==nil)
assert(c.made[2].base==own[2] and c.made[2].values.Q.A==1)
-- step: once a second; the same mesh twice paints once; a mesh with no entry clears once.
local lines={}
local p=Paint.new({log=function(line) lines[#lines+1]=line end})
c=fake()
p.step(10,M,{c}); p.step(10.5,OTHER,{c}); p.step(12,M,{c}); assert(#c.made_list==1 and c.made[S].base==own[S])
p.step(13,OTHER,{c}); assert(c.set[S]==own[S] and c.current[S]==own[S]); local sets=#c.set_list
p.step(15,OTHER,{c}); assert(#c.set_list==sets)
-- reload: a new Paint.new on c, whose slot S holds an earlier load's instance, clears it to own[S], never keeps it.
local q=Paint.new({log=print}); c.current[S]=c.made_list[1]; q.step(20,OTHER,{c})
assert(c.set[S]==own[S] and c.current[S]==own[S],'A new load clears a component it never painted')
q.step(22,M,{c}); assert(c.made_list[#c.made_list].base==own[S])
-- new part: a component at another address, or at the same address with another path, is painted again.
local c3=fake(); p.step(30,M,{c3}); assert(#c3.made_list==1)
local c4=fake{at=c3:GetAddress()}; p.step(32,M,{c3,c4}); assert(#c3.made_list==1 and #c4.made_list==1)
-- clear: every slot back to the mesh's own material; the next step paints it again.
p.clear({c4}); for slot=0,3 do assert(c4.current[slot]==own[slot]) end
p.step(34,M,{c4}); assert(#c4.made_list==2)
-- A failing CreateDynamicMaterialInstance logs one line over repeated steps and leaves the slot as the mesh made it.
local bad=fake{fail=true}; p.step(40,M,{bad}); p.step(42,OTHER,{bad}); p.step(44,M,{bad}); p.step(46,M,{bad})
assert(#lines==1 and bad.current[S]==own[S],tostring(lines[2]))
assert(lines[1]:find('^bike paint not set on .+ for '..M:gsub('%p','%%%0')..': no instance$'),lines[1])
-- A table that fails its check logs its reason once and paints nothing.
local saved=Paint.BY_MESH
Paint.BY_MESH={[M]={[0]={['a\tb']={0,0,0,1}}}}
local said={}
local r=Paint.new({log=function(line) said[#said+1]=line end})
local c5=fake(); r.step(50,M,{c5}); r.step(52,M,{c5})
assert(#said==1 and said[1]:find('^bike paint table refused: ') and #c5.made_list==0,tostring(said[1]))
Paint.BY_MESH=saved
print('paint_test ok')
