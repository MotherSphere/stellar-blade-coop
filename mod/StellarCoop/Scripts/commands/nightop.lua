-- Night Operation's console commands: coop no (the T6 probe), coop nightop, coop challenge and coop recruiter, all on a
-- co-op save only but coop nightop stop and coop challenge stop. main.lua builds them with new(o) at each Lua load and
-- merges them into its command table. o: main.lua's coop_slot, nightop (nightop/probe.lua's), night
-- (nightop/run.lua's), race (race/run.lua's: no run starts while a Doro race is armed), recruiter, and roxanne
-- (nightop/roxanne.lua's, set after this is built, so read at each call: coop nightop stop drops her booking).
local NightOp={}
function NightOp.new(o)
    local coop_slot,nightop,night,race,recruiter=o.coop_slot,o.nightop,o.night,o.race,o.recruiter
    local self={}
    function self.no(sub,extra)
        local ok,why=coop_slot('coop no')
        if not ok then return false,why end
        return nightop.run(sub,extra)
    end
    function self.nightop(sub,a,b,c)
        if sub=='stop' and a==nil and o.roxanne then
            local level=o.roxanne.cancel()
            if level then
                local ok,said=night.command(sub)
                local dropped='the '..level..' run booked at Roxanne is dropped'
                return true,ok and said..'; '..dropped or dropped
            end
        end
        if sub=='start' and race.armed() then return false,'a Doro race is armed: coop race quit leaves it' end
        if sub~='stop' then
            local ok,why=coop_slot('coop nightop')
            if not ok then return false,why end
        end
        return night.command(sub,a,b,c)
    end
    function self.challenge(sub,extra)
        if sub~='stop' then
            if sub~=nil and race.armed() then return false,'a Doro race is armed: coop race quit leaves it' end
            local ok,why=coop_slot('coop challenge')
            if not ok then return false,why end
        end
        return night.challenge(sub,extra)
    end
    function self.recruiter(sub,extra)
        local ok,why=coop_slot('coop recruiter')
        if not ok then return false,why end
        return recruiter.run(sub,extra)
    end
    return self
end
return NightOp
