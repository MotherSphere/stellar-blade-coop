-- matrix13/world/drone.lua with fake UE4SS objects: nothing outside world 2800; in it, the hook once, each radius the
-- blueprint writes scaled once and never compounded on a tick that wrote nothing, the cone set once per light and put
-- back on stopping and forgotten, never called, on leaving; a raise stops it for good.
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
local M=require('matrix13.world.drone')
local mv=M.new({log=function(s) lines[#lines+1]=s end,here=function() return inside and {} or nil end})
local function near(a,b) return math.abs(a-b)<0.001 end

mv.tick()
assert(#hooks==0,'No hook outside world 2800')
inside=true
hook_raises=1
clock=1; mv.tick()
assert(#hooks==0,'A hook that raises is not kept')
clock=3; mv.tick()
assert(#hooks==0,'The hook waits before its next try')
clock=7; mv.tick()
assert(#hooks==1 and hooks[1].path==M.HOOK,'Hooked on the next try')
clock=8; mv.tick()
assert(#hooks==1,'Hooked once')

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
assert(#lines==2,'One hook line and one light line: '..#lines)

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
print('matrix13/world/drone_test: ok')
