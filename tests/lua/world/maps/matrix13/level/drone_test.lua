-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- world/maps/matrix13/level/drone.lua with fake UE4SS objects: nothing outside world 2800; in it, the hook once, each
-- radius the blueprint writes scaled once and never compounded on a tick that wrote nothing, the cone set once per
-- light and put back on stopping and forgotten, never called, on leaving; a raise stops it for good. RegisterHook runs
-- once a stay at most, only once the class is in memory (a fake loaded): a refused try waits for the next stay with one
-- line; a class not in memory is looked for every RETRY s with one line a stay, then tried once it is in; a class look
-- that walked ends the tries for the stay.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
local hooks,hook_raises={},0
RegisterHook=function(path,f)
    if hook_raises>0 then hook_raises=hook_raises-1; error('no such function') end
    hooks[#hooks+1]={path=path,f=f}
end
local function object(fields)
    local o=fields or {}
    o.type=function() return 'UObject' end
    o.IsValid=function(x) return not x.destroyed end
    return o
end
local light=object({AttenuationRadius=1500,inner=30,outer=40,writes=0})
light.GetAddress=function() return 0x100 end
light.SetAttenuationRadius=function(x,r) x.AttenuationRadius=r; x.writes=x.writes+1 end
light.SetInnerConeAngle=function(x,a) x.inner=a end
light.SetOuterConeAngle=function(x,a) x.outer=a end
local drone=object({SpotLight=light})
local function ctx() return {type=function() return 'RemoteUnrealParam' end,get=function() return drone end} end
local inside,lines=false,{}
local M=require('world.maps.matrix13.level.drone')
local mv=M.new({log=function(s) lines[#lines+1]=s end,here=function() return inside and {} or nil end,
    loaded=function() return {},'soft path' end})
local function near(a,b) return math.abs(a-b)<0.001 end

mv.tick()
assert(#hooks==0,'No hook outside world 2800')
inside=true
hook_raises=1
clock=1; mv.tick()
assert(#hooks==0,'A hook that raises is not kept')
assert(#lines==1 and lines[1]:find('no such function',1,true),'The hook error logged: '..tostring(lines[1]))
clock=3; mv.tick()
clock=6; mv.tick()
assert(#hooks==0,'One try a stay: RegisterHook looks its function up by a walk of every object')
inside=false
clock=7; mv.tick()
inside=true
clock=8; mv.tick()
assert(#hooks==1 and hooks[1].path==M.HOOK,'Hooked at the next stay')

hooks[1].f(ctx())
assert(near(light.AttenuationRadius,1800),'The written radius scaled: '..light.AttenuationRadius)
assert(near(light.inner,36) and near(light.outer,48),'The cone widened')
hooks[1].f(ctx())
assert(near(light.AttenuationRadius,1800) and light.writes==1,'A tick that wrote nothing does not compound')
light.AttenuationRadius=1500
hooks[1].f(ctx())
assert(near(light.AttenuationRadius,1800) and light.writes==2,'The next write scaled again')
light.AttenuationRadius=225
hooks[1].f(ctx())
assert(near(light.AttenuationRadius,270),'A faint light keeps its proportion')
assert(#lines==3,'One error line, one hook line and one light line: '..#lines)

-- Leaving: the left world's light is forgotten, never called (the game frees it with the map).
inside=false
light.inner,light.outer=0,0
clock=9; mv.tick()
assert(light.inner==0 and light.outer==0,'The light of the left world untouched')
light.AttenuationRadius=1500
hooks[1].f(ctx())
assert(light.AttenuationRadius==1500,'Nothing outside world 2800')

inside=true
clock=10; mv.tick()
hooks[1].f(ctx())
assert(near(light.outer,48) and near(light.AttenuationRadius,1800) and #hooks==1,'Back in the world, no second hook')
mv.stop()
assert(light.outer==40,'The cone put back on stop')

clock=11; mv.tick()
drone.SpotLight=object({AttenuationRadius=1500})
drone.SpotLight.GetAddress=function() error('boom') end
hooks[1].f(ctx())
assert(lines[#lines]:find('^STOP: light:'),lines[#lines])
drone.SpotLight=light
light.AttenuationRadius=1500
hooks[1].f(ctx())
clock=12; mv.tick()
hooks[1].f(ctx())
assert(light.AttenuationRadius==1500,'A raise stops it for good')

-- A hook that raises at every try: one line a stay in world 2800, and one more on the next stay.
do
    hook_raises=math.huge
    local got={}
    local d2=M.new({log=function(s) got[#got+1]=s end,here=function() return inside and {} or nil end,
        loaded=function() return {},'soft path' end})
    inside=true
    for t=1,30 do clock=clock+1; d2.tick() end
    assert(#hooks==1 and #got==1 and got[1]:find('no such function',1,true),'One error line in 30 s: '..#got)
    inside=false
    clock=clock+1; d2.tick()
    inside=true
    for t=1,10 do clock=clock+1; d2.tick() end
    assert(#got==2 and got[2]:find('no such function',1,true),'One more line on the next stay: '..#got)
    hook_raises=0
end
-- The class not in memory: no RegisterHook, the class looked for by its name hash every RETRY s with one line a stay,
-- then one try once it is in; a class look that walked ends the tries for the stay (Review Focus 17).
do
    local got,tries,in_memory,how={},0,nil,'soft path'
    local function made()
        return M.new({log=function(s) got[#got+1]=s end,here=function() return inside and {} or nil end,
            loaded=function() tries=tries+1; return in_memory,how end})
    end
    local d3=made()
    local before=#hooks
    inside=true
    for _=1,30 do clock=clock+1; d3.tick() end
    assert(#hooks==before and tries==6 and #got==1 and got[1]:find('not in memory',1,true),'By name: '..tries)
    in_memory={}
    for _=1,5 do clock=clock+1; d3.tick() end
    assert(#hooks==before+1 and got[#got]=='light: CH_Drone_BP_C:ReceiveTick hooked',tostring(got[#got]))
    in_memory,how,tries=nil,'walk',0
    local d4=made()
    for _=1,30 do clock=clock+1; d4.tick() end
    assert(tries==1 and got[#got]:find('no hook this stay',1,true),'A class look that walked: once a stay, '..tries)
end
print('world/maps/matrix13/level/drone_test: ok')
