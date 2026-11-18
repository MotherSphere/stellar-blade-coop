-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop guide: the first-launch guide (ui/kit/guide.lua) opened on its first page, on the title screen or in the game
-- world, as the co-op menu's Guide row opens it. coop keys reset [<name>|all]: one key back to its default (menu, host,
-- status, leave, follow, race or bike, or the setting's own name, menu_key and the like), or every key with all or no
-- name, as the co-op menu's key rows and its Reset all keys row do (ui/kit/menu.lua's reset). main.lua builds them with
-- new(o) at each Lua load and merges them into its command table. o: main.lua's, whose guide (ui/kit/guide.lua's) and
-- menu it sets once the UI is built, with the Steam link only.
local Kit={}
local USE='Use: coop keys reset [menu|host|status|leave|follow|race|bike|all]'
local NAMES={menu=true,host=true,status=true,leave=true,follow=true,race=true,bike=true,all=true}
function Kit.new(o)
    local self={}
    function self.guide(extra)
        if extra~=nil then return false,'Use: coop guide' end
        if not o.guide then return false,'the guide needs the co-op UI, which needs the Steam link' end
        return o.guide.open()
    end
    function self.keys(sub,name,extra)
        name=(name or 'all'):lower():gsub('_key$','')
        if sub~='reset' or extra~=nil or not NAMES[name] then return false,USE end
        if not o.menu then return false,'coop keys needs the co-op UI, which needs the Steam link' end
        return o.menu.reset(name~='all' and name..'_key' or nil)
    end
    return self
end
return Kit
