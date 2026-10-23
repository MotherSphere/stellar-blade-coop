-- coop leviathan, a read and a display of the cut Naytiba 10 with a free camera to film it (cut/leviathan.lua; a test
-- tool, left out of the usage line): show and cam turning the camera on (not off, not its speed) on a co-op save only,
-- as coop race probe doro. coop lion, the cut Lion spawned as an enemy to fight (cut/lion.lua, left out of the usage
-- line too): the words that spawn (none, intro, control) on a co-op save only; rows and brain on any. main.lua builds
-- it with new(o) at each Lua load and merges it into its command table. o: main.lua's coop_slot, leviathan
-- (cut/leviathan.lua's) and lion (cut/lion.lua's).
local Cut={}
function Cut.new(o)
    local coop_slot,leviathan,lion=o.coop_slot,o.leviathan,o.lion
    local self={}
    function self.leviathan(sub,a,b,c,d,e)
        if sub=='show' or sub=='cam' and a==nil and not leviathan.filming() then
            local ok,why=coop_slot('coop leviathan '..sub)
            if not ok then return false,why end
        end
        return leviathan.command(sub,a,b,c,d,e)
    end
    function self.lion(sub,a,b)
        if sub==nil or sub=='intro' or sub=='control' then
            local ok,why=coop_slot('coop lion'..(sub and ' '..sub or ''))
            if not ok then return false,why end
        end
        return lion.command(sub,a,b)
    end
    return self
end
return Cut
