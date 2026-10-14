-- A render-only second EVE: a plain actor with one PoseableMeshComponent per EVE skeletal mesh component (same mesh,
-- materials and visibility, no collision). It is not a Pawn, so lock-on, AI and saves never see it. Each frame her
-- leaders' poses are copied (CopyPoseFromSkeletalComponent: her last evaluated pose) and each part takes her part's
-- world placement, offset to her right; followers follow their puppet leader as hers follow theirs. No cloth or morphs:
-- a rigid ponytail and a neutral face.
-- ponytail: visibility is copied once, and a Lua reload leaves the puppet until the next level load; track both when
-- the puppet shows a friend instead of a mirror.
local UE=require('UEHelpers')
local Puppet={}
local RIGHT=200 -- cm
local function kind(value)
    if type(value)~='userdata' and type(value)~='table' then return nil end
    local ok,result=pcall(function() return value:type() end)
    return ok and result or nil
end
-- UE4SS may wrap values as RemoteUnrealParam/LocalUnrealParam; open them before use.
local function value_of(value)
    for _=1,3 do
        local k=kind(value)
        if k~='RemoteUnrealParam' and k~='LocalUnrealParam' then return value end
        value=value:get()
    end
    return value
end
local function valid(object)
    object=value_of(object)
    return object~=nil and kind(object)~=nil and object:IsValid() and object or nil
end
-- Arrays arrive as converted Lua lists or TArray userdata; elements may be wrapped.
local function each(array,callback)
    array=value_of(array)
    if array==nil then return end
    if type(array)=='table' and rawget(array,'ForEach')==nil then
        for index,value in ipairs(array) do callback(index,value_of(value)) end
        return
    end
    array:ForEach(function(index,element) callback(index,value_of(element:get())) end)
end
local function text(name)
    name=value_of(name)
    return type(name)=='string' and name or name:ToString()
end
local function find(path) return (assert(valid(StaticFindObject(path)),path..' is unavailable in this game build.')) end
-- EVE's skeletal mesh components that have a mesh, and the name of the component each one follows.
local function parts_of(eve)
    local list={}
    each(eve:K2_GetComponentsByClass(find('/Script/Engine.SkeletalMeshComponent')),function(_,component)
        component=valid(component)
        local mesh=component and valid(component.SkeletalMesh)
        if not mesh then return end
        local found,leader=pcall(function() return valid(value_of(component.MasterPoseComponent):Get()) end)
        list[#list+1]={handle=component,name=text(component:GetFName()),mesh=mesh,
            leader=found and leader and text(leader:GetFName()) or nil}
    end)
    table.sort(list,function(a,b) return a.leader==nil and b.leader~=nil end) -- Leaders first: followers find theirs.
    return list
end
local generation=0 -- Of the component table; the native part also gets a new session token per Lua load.
local function address(object) return string.format('0x%x',value_of(object):GetAddress()) end
-- The table the native part reads (native/src/pose_core.h, parse_table): EVE's parts and the puppet's, index for index.
local function component_table(puppet)
    generation=generation+1
    local lines={'generation '..generation,'root '..address(puppet.actor:K2_GetRootComponent())}
    for i,part in ipairs(puppet.parts) do
        local flag=part.leader and 1 or 0
        lines[#lines+1]=string.format('part eve %d %s %s %s %d %d',i-1,address(part.source),
            address(part.source:GetClass()),address(part.mesh),part.source:GetNumBones(),flag)
        lines[#lines+1]=string.format('part puppet %d %s %s %s %d %d',i-1,address(part.target),
            address(part.target:GetClass()),address(part.mesh),part.target:GetNumBones(),flag)
    end
    return table.concat(lines,'\n')..'\n'
end
-- publish(text) hands the component table to the native part, publish(nil) withdraws it; it returns ok, why.
function Puppet.new(publish)
    publish=publish or function() return false,'no native part' end
    local self,puppet={},nil
    local function clear(why)
        local p=puppet; puppet=nil
        if p then publish(nil) end
        if p and valid(p.actor) then p.actor:K2_DestroyActor() end
        return string.format('Puppet removed (%s) after %d frames, %.2f ms per frame.',why,p and p.frames or 0,
            p and p.frames>0 and p.seconds*1000/p.frames or 0)
    end
    local function build()
        local eve=valid(UE.GetPlayer())
        assert(eve and eve:IsA(find('/Script/SB.SBCharacter')),'Load a save first: EVE is not in the world.')
        local poseable=find('/Script/Engine.PoseableMeshComponent')
        local identity=find('/Script/Engine.Default__KismetMathLibrary'):MakeTransform({X=0,Y=0,Z=0},{Pitch=0,Yaw=0,Roll=0},{X=1,Y=1,Z=1})
        local list=parts_of(eve)
        local actor=valid(eve:GetWorld():SpawnActor(find('/Script/Engine.Actor'),value_of(eve:K2_GetActorLocation()),{Pitch=0,Yaw=0,Roll=0}))
        assert(actor,'The puppet actor could not be spawned.')
        puppet={actor=actor,parts={},frames=0,seconds=0}
        actor:SetActorEnableCollision(false,false)
        local by_name,leaders,skipped={},0,0
        for _,c in ipairs(list) do
            local leader=c.leader and by_name[c.leader]
            if c.leader and not leader then skipped=skipped+1 else
                -- The first part becomes the actor's root; the others attach to it.
                local target=valid(actor:AddComponentByClass(poseable,false,identity,false))
                assert(target,'A puppet part could not be added.')
                target:SetCollisionEnabled(0)
                target:SetSkeletalMesh(c.mesh,true)
                for m=0,c.handle:GetNumMaterials()-1 do target:SetMaterial(m,c.handle:GetMaterial(m)) end
                target:SetVisibility(c.handle:IsVisible(),false)
                target:SetHiddenInGame(c.handle.bHiddenInGame==true,false)
                if leader then target:SetMasterPoseComponent(leader.target,false) else leaders=leaders+1 end
                local part={source=c.handle,target=target,mesh=c.mesh,leader=not leader}
                by_name[c.name]=part
                puppet.parts[#puppet.parts+1]=part
            end
        end
        local published,why=publish(component_table(puppet))
        return string.format('Puppet spawned 2 m to her right: %d parts (%d leaders), %d skipped without a leader; %s; coop puppet removes it.',
            #puppet.parts,leaders,skipped,published and 'component table '..generation..' published' or 'component table not published: '..tostring(why))
    end
    function self.active() return puppet~=nil end
    function self.toggle()
        if puppet then return true,clear('coop puppet') end
        local ok,message=pcall(build)
        if not ok then clear('setup failed'); error(message,0) end
        return true,message
    end
    -- Once per game-thread tick; nothing while no puppet stands. A failure removes it and says why.
    function self.tick()
        if not puppet then return end
        local started=os.clock()
        local ok,why=pcall(function()
            local eve=valid(UE.GetPlayer())
            assert(eve and valid(puppet.actor),'EVE or the puppet left the world')
            local yaw=math.rad(value_of(eve:K2_GetActorRotation()).Yaw)
            local dx,dy=-math.sin(yaw)*RIGHT,math.cos(yaw)*RIGHT -- Her right: Unreal is left-handed.
            for _,part in ipairs(puppet.parts) do
                assert(valid(part.source) and valid(part.target),'a part left the world')
                local at,r=value_of(part.source:K2_GetComponentLocation()),value_of(part.source:K2_GetComponentRotation())
                part.target:K2_SetWorldLocationAndRotation({X=at.X+dx,Y=at.Y+dy,Z=at.Z},{Pitch=r.Pitch,Yaw=r.Yaw,Roll=r.Roll},false,{},true)
                if part.leader then part.target:CopyPoseFromSkeletalComponent(part.source) end
            end
        end)
        if not ok then return false,clear('stopped: '..tostring(why)) end
        puppet.frames,puppet.seconds=puppet.frames+1,puppet.seconds+os.clock()-started
    end
    return self
end
return Puppet
