-- The Doro races' console command, coop race: look on|off and probe doro here (race/doro.lua), the co-op save check of
-- start and drive probe, and the rest in race/run.lua's command. main.lua builds it with new(o) at each Lua load and
-- merges it into its command table. o: main.lua's puppet, doro, coop_slot and race (race/run.lua's).
local Race={}
function Race.new(o)
    local puppet,doro,coop_slot,race=o.puppet,o.doro,o.coop_slot,o.race
    local self={}
    -- The look and the ghost's Doro mode go on together; off ends both, whether the look is on or not, on any save.
    -- The look and the probe start on a co-op save only: the look writes to the player actor.
    function self.race(sub,a,extra)
        if sub=='look' and (a=='on' or a=='off') and extra==nil then
            if a=='off' then
                puppet.doro(false)
                return doro.off('coop race look off')
            end
            local ok,why=coop_slot('coop race look')
            if not ok then return false,why end
            ok,why=doro.on()
            if not ok then return false,why end
            local _,ghost_why=puppet.doro(true,doro.log)
            return true,why..(ghost_why and ' '..ghost_why or '')
        end
        if sub=='probe' and a=='doro' and extra==nil then
            local ok,why=coop_slot('coop race probe')
            if not ok then return false,why end
            return doro.probe()
        end
        if sub=='look' or sub=='probe' then return false,'Use: coop race look on|off | probe doro' end
        if sub=='start' and a~=nil and extra==nil or sub=='drive' and a=='probe' and extra==nil then
            local ok,why=coop_slot('coop race '..sub)
            if not ok then return false,why end
        end
        return race.command(sub,a,extra)
    end
    return self
end
return Race
