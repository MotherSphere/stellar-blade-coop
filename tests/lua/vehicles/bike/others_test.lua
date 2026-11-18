-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- vehicles/bike/others.lua over a fake vehicles/bike/stand.lua and a fake EVE: other players' parked bikes as copies on
-- our map, only once our EVE stood 2 s, one spawn a pass, moved in place, removed with their reason, never ours, none
-- with bike=off or the mesh not ready, hidden in a cutscene, solid against our EVE once she is clear; their paths kept
-- for the next Lua load's sweep; coop off removes them all.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
FName=function(t) return {type=function() return 'FName' end,ToString=function() return t end} end
package.loaded.UEHelpers={GetPlayer=function() end}
local Park=require('vehicles.bike.park')
local MESH='/Game/Art/Character/ETC/Adam_vehicle_02/Adam_Vehicle_02.Adam_Vehicle_02'
-- vehicles/bike/stand.lua (vehicles/bike/stand_test tests it): each display in made with its place, shown, solid,
-- removed, cull and path; step runs the real open-then-solid rule against eve.feet with a 35 cm capsule; sweep appends
-- to swept.
local made,swept={},{}
local world={GetFullName=function() return 'World /Game/Map/Map.Map' end} -- Our EVE's: /game/map/map.
package.loaded['vehicles.bike.stand']={CULL=20000,
    make=function(w,mesh,cull)
        assert(w==world and mesh==MESH,'In our world, with the bike mesh')
        local d={shown=false,solid=false,k={},cull=cull,path='/Game/Map.Map:PersistentLevel.Actor_'..(#made+1)}
        made[#made+1]=d
        return d
    end,
    put=function(d,place) d.place=place end,
    show=function(d,on) d.shown=on end,
    step=function(d,e)
        if d.shown and d.place then d.solid=Park.solid(d.k,Park.clear(d.place,e.feet,35)) end
    end,
    alive=function(d) return not d.removed and d or nil end,
    remove=function(d) d.removed,d.shown=true,false end,
    sweep=function(path,mesh) assert(mesh==MESH); swept[#swept+1]=path end}
local Others=require('vehicles.bike.others')
local logs={}
local function find(pattern)
    for _,l in ipairs(logs) do if l:find(pattern) then return true end end
    return false
end
local eve={feet={X=0,Y=0,Z=0},sequence=false}
eve.type=function() return 'UObject' end
eve.IsValid=function() return true end
function eve:GetAddress() return 0x40 end
function eve:GetFullName() return 'CH_P_EVE_01_Blueprint_C /Game/Map.Map:PersistentLevel.EVE' end
function eve:GetWorld() return world end
function eve:IsAttachedToLevelSequenceWithoutPlayable() return eve.sequence end
local bikes,names,settings,st_load,stored={},{},{bike=true},'ready',nil
local function new()
    return Others.new({log=function(m) logs[#logs+1]=m end,bikes=function() return bikes end,
        members=function()
            local list={}
            for id,name in pairs(names) do list[#list+1]={id=id,name=name} end
            return list
        end,
        me=function() return '1' end,eve=function() return eve end,
        status=function() return 'mod=v\nengine=on bike='..st_load..' bike_gate=off\n' end,settings=settings,
        store={save=function(p) stored=p end,load=function() return stored end,clear=function() stored=nil end}})
end
local function live()
    local list={}
    for _,d in ipairs(made) do if not d.removed then list[#list+1]=d end end
    return list
end
local O=new()

-- Copies: only park lines on our map once our EVE stood 2 s; one spawn a pass; moved in place; removed on none,
-- another map or a member gone; never ours; none with bike=off or the mesh not ready; hidden in a cutscene; solid
-- against our EVE only once she is clear; their paths kept for the next Lua load's sweep.
bikes={['2002']='park /game/map/map 100 0 0 0 0 0',['4003']='park /game/map/map 900 0 0 0 0 0',
    ['4004']='park /game/other 1 2 3 0 0 0',['1']='park /game/map/map 5 5 5 0 0 0'}   -- 1 is our own SteamID
names={['2002']='Kaanta',['4003']='P3',['4004']='P4'}
O.slow(); assert(#made==0,'Not before our EVE stood 2 s')
clock=2; O.slow(); assert(#made==1); clock=2.25; O.slow(); assert(#made==2); clock=2.5; O.slow(); assert(#made==2)
assert(made[1].cull==20000 and made[1].shown and find('^bike of Kaanta: parked on map at 100,0,0$'))
bikes['2002']='park /game/map/map 150 0 0 0 0 0'; clock=2.75; O.slow(); assert(#made==2 and made[1].place.at.X==150)
bikes['2002']='none'; clock=3; O.slow(); assert(made[1].removed and find('^bike of Kaanta: none$'))
bikes['4003']=nil; clock=3.25; O.slow()
assert(made[2].removed and find('^bike of P3: copy removed %(left the lobby%)$'))
assert(stored==nil,'No copy left: the store cleared')
bikes['2002']='park /game/map/map 0 0 0 0 0 0'; clock=3.5; O.slow()
assert(made[3].solid==false,'Our EVE stands in it: open')
eve.feet={X=0,Y=200,Z=0}; clock=3.75; O.slow(); assert(made[3].solid==true)
eve.sequence=true; clock=4; O.slow(); assert(made[3].shown==false)
eve.sequence=false; clock=4.25; O.slow(); assert(made[3].shown)
assert(stored==made[3].path)
settings.bike=false; clock=4.5; O.slow(); assert(made[3].removed); settings.bike=true
st_load='loading'; clock=4.75; O.slow(); assert(#made==3,'No mesh in memory: no copy')
local O2=new(); stored='/Game/Map.Map:PersistentLevel.Actor_7'; O2.restore()
assert(swept[1]=='/Game/Map.Map:PersistentLevel.Actor_7' and stored==nil)
-- Each path of the tab-separated line, once a Lua load.
stored='/Game/Map.Map:PersistentLevel.Actor_8\t/Game/Map.Map:PersistentLevel.Actor_9'; O2.restore(); assert(#swept==1)
new().restore(); assert(swept[2]=='/Game/Map.Map:PersistentLevel.Actor_8' and swept[3]:find('Actor_9$') and stored==nil)
-- Another map takes the copy away; coop off removes what is left.
st_load='ready'; clock=5; O.slow(); assert(#made==4 and #live()==1)
bikes['2002']='park /game/other 0 0 0 0 0 0'; clock=5.25; O.slow()
assert(made[4].removed and find('^bike of Kaanta: copy removed %(another map%)$'))
bikes['2002']='park /game/map/map 0 0 0 0 0 0'; clock=5.5; O.slow(); assert(#live()==1)
O.clear('coop off'); assert(#live()==0)
print('others_test ok')
