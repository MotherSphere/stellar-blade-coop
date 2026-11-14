-- Lily's signal by hand: coop lily signal [status|quest|travel|next], coop lily talk prologue|arrival|finale [kit] and
-- coop lily hold on|off (matrix13/quest/on_time.lua, experimental). main.lua builds it with new(o) at each Lua load and
-- merges it into its command table. o.lily: Lily's signal, set after this is built, so read at each call; o.coop_slot:
-- main.lua's co-op save check.
local Lily={}
local USE='Use: coop lily signal [status|quest|travel|next] | talk prologue|arrival|finale [kit] | hold on|off'
function Lily.new(o)
    local self={}
    -- The quests and the camp travel may go into the save, so on a co-op save only, and a talk too, as a quest step;
    -- status and hold (Lua memory only) anywhere.
    function self.lily(sub,what,extra)
        if not o.lily then return false,USE end
        if sub=='hold' then
            if extra~=nil or what~='on' and what~='off' then return false,USE end
            return o.lily.hold(what=='on')
        end
        if sub~='talk' and (sub~='signal' or extra~=nil) then return false,USE end
        if sub=='talk' or what~='status' then
            local ok,why=o.coop_slot('coop lily '..sub)
            if not ok then return false,why end
        end
        if sub=='talk' then return o.lily.talk(what,extra) end
        return o.lily.command(what)
    end
    return self
end
return Lily
