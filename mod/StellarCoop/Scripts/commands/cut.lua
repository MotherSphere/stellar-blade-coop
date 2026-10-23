-- coop leviathan, a read and a display of the cut Naytiba 10 with a free camera to film it (cut/leviathan.lua; a test
-- tool, left out of the usage line): show and cam turning the camera on (not off, not its speed) on a co-op save only,
-- as coop race probe doro. main.lua builds it with new(o) at each Lua load and merges it into its command table. o:
-- main.lua's coop_slot and leviathan (cut/leviathan.lua's).
local Cut={}
function Cut.new(o)
    local coop_slot,leviathan=o.coop_slot,o.leviathan
    local self={}
    -- coop wear (cut/wear.lua, o.wear): every word to it, on any save, as nothing of it is saved.
    function self.wear(...) return o.wear.command(...) end
    function self.leviathan(sub,a,b,c,d,e)
        if sub=='show' or sub=='cam' and a==nil and not leviathan.filming() then
            local ok,why=coop_slot('coop leviathan '..sub)
            if not ok then return false,why end
        end
        return leviathan.command(sub,a,b,c,d,e)
    end
    return self
end
return Cut
