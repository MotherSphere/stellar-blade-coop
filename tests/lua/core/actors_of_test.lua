-- core/unreal.lua's actors_of: the class hash (UGameplayStatics::GetAllActorsOfClass) once it gave a PlayerController
-- that FindAllOf gives too, else FindAllOf of the short name as before. Covered: no context, no proof and a walk; no
-- player controller yet, no decision and a walk; the hash proven, then used alone (no FindAllOf at all); a hash that
-- fills nothing, the walk for good; a hash call that raises, the walk for that call; FindAllOf absent; invalid actors
-- left out of both routes.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local function object(name,valid)
    return {type=function() return 'UObject' end,IsValid=function() return valid~=false end,name=name}
end
local walks,hashes={},0
local world={PlayerController={},Booth={object('a'),object('dead',false),object('b')}}
local fill=true -- Whether the fake GetAllActorsOfClass fills its out array (as UE4SS does), or raises when 'raise'.
local function classes(name) return {type=function() return 'UClass' end,IsValid=function() return true end,name=name} end
local statics={type=function() return 'UObject' end,IsValid=function() return true end,
    GetAllActorsOfClass=function(_,ctx,cls,out)
        assert(ctx=='ctx')
        hashes=hashes+1
        if fill=='raise' then error('no such function') end
        if fill then for i,a in ipairs(world[cls.name]) do out[i]=a end end
    end}
StaticFindObject=function(path)
    if path=='/Script/Engine.Default__GameplayStatics' then return statics end
    if path=='/Script/Engine.PlayerController' then return classes('PlayerController') end
    error('StaticFindObject '..path)
end
FindAllOf=function(name) walks[#walks+1]=name; local l=world[name]; return l and #l>0 and l or nil end
local function names(list) local t={} for i,a in ipairs(list) do t[i]=a.name end return table.concat(t,',') end
local function fresh()
    package.loaded['core.unreal']=nil
    walks,hashes=({}),0
    return require('core.unreal')
end
local BOOTH=classes('Booth')

-- No context: never proven, the walk.
local U=fresh()
local list,route=U.actors_of(BOOTH,'Booth',nil)
assert(route=='walk' and names(list)=='a,b' and #walks==1 and hashes==0)
-- No player controller yet: no decision, the walk; the proof is tried again at the next call.
list,route=U.actors_of(BOOTH,'Booth','ctx')
assert(route=='walk' and names(list)=='a,b' and walks[2]=='PlayerController' and walks[3]=='Booth' and hashes==0)
-- One player controller: the hash gives it too, proven; from then on the hash alone.
world.PlayerController={object('pc')}
walks={}
list,route=U.actors_of(BOOTH,'Booth','ctx')
assert(route=='class hash' and names(list)=='a,b' and #walks==1 and walks[1]=='PlayerController' and hashes==2)
walks={}
for _=1,100 do list,route=U.actors_of(BOOTH,'Booth','ctx') end
assert(route=='class hash' and #walks==0 and hashes==102,'No FindAllOf once proven')
-- A hash call that raises after the proof: that call walks.
fill='raise'
list,route=U.actors_of(BOOTH,'Booth','ctx')
assert(route=='walk' and names(list)=='a,b' and #walks==1)
-- A hash that fills nothing (UE4SS not filling out arrays): the walk for good, the proof never tried again.
fill=false
U=fresh()
list,route=U.actors_of(BOOTH,'Booth','ctx')
assert(route=='walk' and names(list)=='a,b' and hashes==1)
for _=1,10 do list,route=U.actors_of(BOOTH,'Booth','ctx') end
assert(route=='walk' and hashes==1 and #walks==12)
-- No FindAllOf in this UE4SS: an empty list, no error.
FindAllOf=nil
U=fresh()
list,route=U.actors_of(BOOTH,'Booth','ctx')
assert(route=='walk' and #list==0)
print('actors_of_test ok')
