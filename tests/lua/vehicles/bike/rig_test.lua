-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- vehicles/bike/rig.lua with fake UE4SS objects, built as vehicles/bike/stand_test.lua builds them: the follower rule
-- (hung on her main mesh, no socket, no anim instance of its own, a mesh; the bike part left out by its address; a
-- part with no mesh never called; a part whose read raises left alone; her main mesh never read; address order); the
-- rig made at her location, hidden, posing while hidden, its cloth off, ticking, snapped to her main mesh, the clip
-- looped; a rig that cannot be made raises with no actor left; the hook (her main mesh first, then each follower; a
-- refusal of her main mesh raises, a follower's is counted out); hooked; the unhook (her main mesh to none, each part
-- back once, her main mesh never pointed at itself, a part no longer hers never called, a failing call counted while
-- the others go on, nothing called once her EVE is gone, a part on a socket that the hook moved sent back); remove and
-- sweep; the release after Ctrl+R (the rig found by its path and mesh, each part it leads sent back, then swept).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
FName=function(t) return {type=function() return 'FName' end,ToString=function() return t end} end
local next_address=0x1000
-- fields.address: a fixed address (the coat's: Lua's walk of a table keyed by address then leaves address order).
local function object(fields)
    next_address=next_address+0x100
    local o=fields or {}
    local at=o.address or next_address
    o.type=function() return 'UObject' end
    o.IsValid=o.IsValid or function(self) return not self.destroyed end
    o.GetAddress=function() return at end
    return o
end
local invalid=object({destroyed=true})
local function class(path) return object({path=path,MakeTransform=function() return 'identity' end}) end
local BODY,OTHER='/Game/Test/Body.Body','/Game/Test/Other.Other'
local SKINNED='/Script/Engine.SkeletalMeshComponent'
local function mesh(path)
    return object({GetFullName=function() return 'SkeletalMesh '..path end,
        IsA=function(_,c) return c.path=='/Script/Engine.SkeletalMesh' end})
end
local assets={[BODY]=mesh(BODY),[OTHER]=mesh(OTHER)}
local by_path={} -- Actors StaticFindObject finds by path (an earlier Lua load's), beside classes and assets.
StaticFindObject=function(path)
    if by_path[path] then return by_path[path] end
    if path:find('^/Script/') then return class(path) end
    return assets[path] or invalid
end
LoadAsset=function(path) return assets[path] or invalid end
package.loaded.UEHelpers={GetPlayer=function() end}
local function weak(o) return {type=function() return 'TWeakObjectPtr' end,Get=function() return o end} end

-- Every SetMasterPoseComponent call, in order: {part=, leader=}. made: every part, for the engine's cascade.
local calls,made={},{}
local function count(part)
    local n=0
    for _,c in ipairs(calls) do if c.part==part then n=n+1 end end
    return n
end
-- FUN_144129240 (SetMasterPoseComponent, build 26123051): a leader that is not null moves the part's own followers
-- (the parts whose leader it is) to that leader, then theirs. Not a call of ours: not in calls.
local function cascade(from,to)
    for _,p in ipairs(made) do
        if p.MasterPoseComponent:Get()==from then p.MasterPoseComponent=weak(to); cascade(p,to) end
    end
end
-- One of EVE's skeletal mesh components: f.mesh, f.parent, f.socket (default None), f.anim, f.fail (its
-- SetMasterPoseComponent raises), f.raise (its GetAttachParent raises). c.read: its GetAttachParent was called.
local function part(f)
    local c=object(f)
    c.SkeletalMesh=f.mesh
    c.AnimScriptInstance=f.anim
    c.MasterPoseComponent=weak(nil)
    local function touch(self)
        if not self.SkeletalMesh then self.touched=true; error('a method on a part with no mesh') end
    end
    function c:GetAttachParent()
        self.read=true
        touch(self)
        if self.raise then error('read failed') end
        return self.parent
    end
    function c:GetAttachSocketName()
        touch(self)
        return FName(self.socket or 'None')
    end
    function c:SetMasterPoseComponent(leader,force)
        touch(self)
        assert(force==true,'always forced')
        calls[#calls+1]={part=self,leader=leader}
        if self.fail then error('refused') end
        self.MasterPoseComponent=weak(leader)
        if leader then cascade(self,leader) end
    end
    made[#made+1]=c
    return c
end
local body=assets[BODY]
local main=part({mesh=body})
local hair=part({mesh=body,parent=main})
local suit=part({mesh=body,parent=main})
local sword=part({mesh=body,parent=main,socket='Hand_R'})
local face=part({mesh=body,parent=main,anim=object({})})
local empty=part({parent=main})
local bike=part({mesh=body,parent=main}) -- Hung KeepRelative with no socket: only its address leaves it out.
local bangs=part({mesh=body,parent=hair})
local broken=part({mesh=body,parent=main,raise=true})
local eve=object({Mesh=main})
eve.parts={bangs,suit,main,sword,hair,face,empty,bike,broken}
function eve:K2_GetComponentsByClass(c)
    assert(c.path==SKINNED)
    return self.parts
end
function eve:K2_GetActorLocation() return {X=100,Y=200,Z=300} end

-- The world: SpawnActor makes a plain Actor whose components record what the rig sets.
local world=object({spawned={}})
function eve:GetWorld() return world end
local function component(actor)
    local c=object({})
    function c:SetSkeletalMesh(m) self.SkeletalMesh=m end
    function c:SetRelativeScale3D() end
    function c:SetAnimationMode(n) self.mode=n end
    function c:SetCollisionEnabled(n) self.collision=n end
    function c:K2_SetWorldLocationAndRotation(at,rot,sweep) assert(sweep==false); self.at,self.rot=at,rot end
    function c:SetComponentTickEnabled(on) self.tick=on end
    function c:K2_AttachToComponent(parent,socket,l,r,s,weld)
        if world.fail_attach then error('attach refused') end
        self.attached={parent=parent,socket=socket:ToString(),l=l,r=r,s=s,weld=weld}
    end
    function c:PlayAnimation(clip,loop) self.played={clip=clip,loop=loop} end
    function c:K2_DestroyComponent(owner) assert(owner==actor); self.destroyed=true end
    function c:IsA(k) return k.path==SKINNED end
    return c
end
function world:SpawnActor(c,at,rot)
    assert(c.path=='/Script/Engine.Actor','A plain Actor only')
    local a=object({components={},at=at,rot=rot})
    function a:SetActorEnableCollision(on,fast) assert(fast==false); self.collision=on end
    function a:SetActorHiddenInGame(on) self.hidden=on end
    function a:AddComponentByClass(k,manual,transform,deferred)
        assert(k.path==SKINNED and manual==false and transform=='identity' and deferred==false)
        local added=component(self)
        self.components[#self.components+1]=added
        return added
    end
    function a:K2_GetRootComponent() return self.components[1] end
    function a:K2_DestroyActor() self.destroyed=true end
    local n=#self.spawned+1
    function a:GetFullName() return 'Actor /Game/Map.Map:PersistentLevel.Actor_'..n end
    self.spawned[n]=a
    return a
end

local Rig=require('vehicles.bike.rig')
local function same(list,want)
    if #list~=#want then return false end
    for i=1,#want do if list[i]~=want[i] then return false end end
    return true
end
local function sorted(t) table.sort(t,function(x,y) return x:GetAddress()<y:GetAddress() end); return t end

-- The follower rule: hair and suit only (not her main mesh, the sword on a socket, the face with its own anim, the
-- empty slot, the bangs hung on the hair, the part whose read raises); the bike part only by its address.
assert(same(Rig.followers(eve,bike:GetAddress()),sorted({hair,suit})),'hair and suit follow')
assert(same(Rig.followers(eve),sorted({hair,suit,bike})),'the bike part is left out by its address only')
assert(#calls==0 and not empty.touched,'no method called on the empty slot')
assert(not main.read,'her main mesh is never read as a follower')

-- The rig: made at her location, hidden, posing while hidden, its cloth off, ticking, snapped to her main mesh with no
-- socket, the clip looped.
local clip=object({})
local d=Rig.make(eve,BODY,clip,bike:GetAddress())
assert(#world.spawned==1 and d.actor==world.spawned[1] and d.skip==bike:GetAddress())
local rc=d.mesh
assert(d.actor.at.X==100 and d.actor.at.Y==200 and d.actor.at.Z==300 and d.actor.rot.Yaw==0)
assert(rc.SkeletalMesh==body and rc.collision==0 and d.actor.collision==false,'her body mesh, collision off')
assert(d.actor.hidden==true and rc.VisibilityBasedAnimTickOption==0 and rc.bDisableClothSimulation==true
    and rc.tick==true)
local at=rc.attached
assert(at.parent==main and at.socket=='None' and at.l==2 and at.r==2 and at.s==2 and at.weld==false,'snapped')
assert(rc.played.clip==clip and rc.played.loop==true)
-- A clip that is not in memory, an attach that fails: raises, with no actor left.
assert(not pcall(Rig.make,eve,BODY,invalid,nil) and #world.spawned==1,'no clip: nothing spawned')
world.fail_attach=true
local ok,why=pcall(Rig.make,eve,BODY,clip,nil)
assert(not ok and tostring(why):find('attach refused') and world.spawned[2].destroyed,'removed when it fails')
world.fail_attach=nil
assert(not pcall(Rig.make,object({}),BODY,clip,nil),'no main mesh: raises')

-- The hook: her main mesh first, then hair and suit; both counted.
assert(Rig.hooked(eve,d)==false)
local list,n=Rig.hook(eve,d)
assert(calls[1].part==main and calls[1].leader==rc,'her main mesh first')
assert(same(list,sorted({hair,suit})) and n==2 and #calls==3)
assert(count(hair)==1 and count(suit)==1 and count(bike)==0 and count(sword)==0 and count(face)==0)
assert(Rig.hooked(eve,d)==true and hair.MasterPoseComponent:Get()==rc)
-- A follower that refuses is counted out while the others go on; her main mesh refusing raises.
calls,suit.fail={},true
list,n=Rig.hook(eve,d)
assert(#list==2 and n==1 and count(hair)==1 and count(suit)==1)
suit.fail,main.fail,calls=nil,true,{}
assert(not pcall(Rig.hook,eve,d) and #calls==1,'her main mesh refused: no follower called')
main.fail=nil
-- Something else set her leader: no longer hooked.
main.MasterPoseComponent=weak(face)
assert(Rig.hooked(eve,d)==false)
main.MasterPoseComponent=weak(rc)

-- The unhook: her main mesh to none, then each part back once (hair twice in the list, her main mesh in the list
-- never pointed at itself, the coat that came after the hook, a part that is not hers never called); the suit's call
-- fails and the others still go back.
local coat=part({mesh=body,parent=main,address=0x10000})
local stranger=part({mesh=body,parent=main}) -- Valid at an address of the list, no longer among her parts.
eve.parts[#eve.parts+1]=coat
assert(same(Rig.followers(eve,bike:GetAddress()),{hair,suit,coat}),'in address order')
calls,suit.fail={},true
local back,failed=Rig.unhook(eve,d,{hair,main,suit,hair,stranger})
assert(calls[1].part==main and calls[1].leader==nil,'her main mesh first, to none')
assert(back==2 and failed==1,('%d back, %d failed'):format(back,failed))
assert(count(main)==1 and count(hair)==1 and count(suit)==1 and count(coat)==1 and count(stranger)==0
    and count(bike)==0)
assert(not empty.touched)
assert(hair.MasterPoseComponent:Get()==main and coat.MasterPoseComponent:Get()==main)
assert(Rig.hooked(eve,d)==false)
-- Her main mesh refusing the null leader is counted too; the parts still go back.
suit.fail,main.fail,calls=nil,true,{}
back,failed=Rig.unhook(eve,d,{})
assert(back==3 and failed==1 and count(hair)==1 and count(suit)==1 and count(coat)==1)
main.fail=nil
-- Her EVE gone (a map change): nothing called.
calls,eve.destroyed={},true
back,failed=Rig.unhook(eve,d,{hair,suit})
assert(back==0 and failed==0 and #calls==0)
eve.destroyed=nil
-- A part SB hangs on a socket while it follows her main mesh (SBPonytailShort on Bip001-Head): the hook's call on her
-- main mesh moves it to the rig, the rule does not take it, the unhook still sends it back.
local ponytail=part({mesh=body,parent=main,socket='Bip001-Head'})
ponytail.MasterPoseComponent=weak(main)
eve.parts[#eve.parts+1]=ponytail
calls={}
list=Rig.hook(eve,d)
assert(ponytail.MasterPoseComponent:Get()==rc and count(ponytail)==0,'moved with her main mesh only')
back,failed=Rig.unhook(eve,d,list)
assert(back==4 and failed==0,('%d back, %d failed'):format(back,failed))
assert(count(ponytail)==1 and ponytail.MasterPoseComponent:Get()==main,'the ponytail back at her main mesh')

-- Removed only while its actor is the one made; an earlier Lua load's rig swept only while its root shows the mesh.
Rig.remove(d)
assert(d.actor.destroyed)
local old=Rig.make(eve,BODY,clip)
by_path[old.path]=old.actor
assert(Rig.sweep(old.path,OTHER)==nil and not old.actor.destroyed,'another mesh: left')
assert(Rig.sweep(old.path,BODY)==true and old.actor.destroyed)

-- The release after Ctrl+R: an earlier load's rig found by its path and mesh. Her main mesh to none; each part whose
-- leader is the rig back at her main mesh (the bangs and the ponytail too, which the rule does not take), each
-- follower back, the bike part and the sword (another leader) never called; then the rig swept. Another mesh at that
-- path or no actor there: nothing called, nothing swept. Her EVE gone: nothing called on her, the rig still swept.
local function earlier()
    local r=Rig.make(eve,BODY,clip,bike:GetAddress())
    by_path[r.path]=r.actor
    Rig.hook(eve,r)
    bangs.MasterPoseComponent=weak(r.mesh)
    return r
end
local r=earlier()
sword.MasterPoseComponent=weak(face)
calls={}
back,failed=Rig.release(eve,r.path,OTHER,bike:GetAddress())
assert(back==0 and failed==0 and #calls==0 and not r.actor.destroyed,'another mesh: nothing called')
local swept
back,failed,swept=Rig.release(eve,'/Game/Map.Map:PersistentLevel.Gone',BODY,bike:GetAddress())
assert(back==0 and failed==0 and swept==false and #calls==0)
back,failed,swept=Rig.release(eve,r.path,BODY,bike:GetAddress())
assert(calls[1].part==main and calls[1].leader==nil,'her main mesh first, to none')
assert(back==5 and failed==0 and swept==true and r.actor.destroyed,('%d back, %d failed'):format(back,failed))
assert(bangs.MasterPoseComponent:Get()==main and ponytail.MasterPoseComponent:Get()==main
    and hair.MasterPoseComponent:Get()==main
    and suit.MasterPoseComponent:Get()==main and coat.MasterPoseComponent:Get()==main)
assert(count(bike)==0 and count(sword)==0 and count(face)==0 and count(main)==1)
r=earlier()
calls={}
back,failed,swept=Rig.release(nil,r.path,BODY,bike:GetAddress())
assert(back==0 and failed==0 and swept==true and #calls==0 and r.actor.destroyed)
print('rig_test ok')
