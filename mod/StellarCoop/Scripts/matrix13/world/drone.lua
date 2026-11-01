-- Matrix XIII's drone light (matrix13/world/travel.lua ticks it): 20 % more range and cone than the shipped light, at
-- the same intensity, in world 2800 only. CH_Drone_BP writes its spot light's attenuation radius each tick, capped at
-- 1500, so a post hook on its ReceiveTick scales what it just wrote. The cone, which the blueprint never writes, is set
-- once per light and put back when EVE leaves the world.
local U=require('core.unreal')
local Drone={
    HOOK='/Game/Art/Character/NPC/CH_NPC_Drone/Blueprints/CH_Drone_BP.CH_Drone_BP_C:ReceiveTick',
    SCALE=1.2,
    INNER=30,OUTER=40, -- The blueprint's spot light cone.
}
local EVERY=1 -- s between looks at the world.
local RETRY=5 -- s between hook tries: a class not in memory costs a slow lookup each try.

-- o: log, here (EVE in world 2800, or nil).
function Drone.new(o)
    local log,here=o.log,o.here
    local self={}
    local active,hooked,failed=false,false,false
    local next_look,next_hook=0,0
    local written,lights={},{} -- By light address: the radius last written, the light with our cone.
    local function apply(ctx)
        local drone=U.valid(ctx)
        local light=drone and U.valid(drone.SpotLight)
        if not light then return end
        local at=U.address(light)
        local radius=light.AttenuationRadius
        -- A tick that wrote nothing (photo mode) leaves our value there: scaling it again would compound.
        if not written[at] or math.abs(radius-written[at])>0.5 then
            written[at]=radius*Drone.SCALE
            light:SetAttenuationRadius(written[at])
        end
        if not lights[at] then
            lights[at]=light
            light:SetInnerConeAngle(Drone.INNER*Drone.SCALE)
            light:SetOuterConeAngle(Drone.OUTER*Drone.SCALE)
            log(string.format('light: radius x%.1f, cone %.0f/%.0f',Drone.SCALE,Drone.INNER*Drone.SCALE,
                Drone.OUTER*Drone.SCALE))
        end
    end
    local function on_tick(ctx)
        if not active then return end
        local ok,e=pcall(apply,ctx)
        if not ok then
            active,failed=false,true
            log('STOP: light: '..tostring(e)..': the shipped light from now on')
        end
    end
    local function restore()
        for _,light in pairs(lights) do
            pcall(function()
                if U.valid(light) then
                    light:SetInnerConeAngle(Drone.INNER)
                    light:SetOuterConeAngle(Drone.OUTER)
                end
            end)
        end
        written,lights={},{}
    end
    function self.tick()
        local now=os.clock()
        if failed or now<next_look then return end
        next_look=now+EVERY
        local inside=here()~=nil
        if inside and not hooked and now>=next_hook then
            local ok=pcall(RegisterHook,Drone.HOOK,on_tick)
            hooked=ok
            next_hook=now+RETRY
            if ok then log('light: CH_Drone_BP_C:ReceiveTick hooked') end
        end
        if active and not inside then restore() end
        active=inside and hooked
    end
    function self.stop()
        active=false
        restore()
    end
    return self
end
return Drone
