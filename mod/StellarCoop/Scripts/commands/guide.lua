-- coop guide: the first-launch guide (ui/guide.lua) opened on its first page, on the title screen or in the game world,
-- as the co-op menu's Guide row opens it. main.lua builds it with new(o) at each Lua load and merges it into its
-- command table. o: main.lua's, whose guide (ui/guide.lua's) it sets once the UI is built, with the Steam link only.
local Guide={}
function Guide.new(o)
    local self={}
    function self.guide(extra)
        if extra~=nil then return false,'Use: coop guide' end
        if not o.guide then return false,'the guide needs the co-op UI, which needs the Steam link' end
        return o.guide.open()
    end
    return self
end
return Guide
