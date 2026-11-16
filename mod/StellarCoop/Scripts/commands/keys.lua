-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop keys reset [<name>|all]: one key back to its default (menu, host, status, leave, follow or race, or the setting's
-- own name, menu_key and the like), or every key with all or no name, as the co-op menu's key rows and its Reset all
-- keys row do (ui/menu.lua's reset). main.lua builds it with new(o) at each Lua load and merges it into its command
-- table. o: main.lua's, whose menu it sets once the UI is built, with the Steam link only.
local Keys={}
local USE='Use: coop keys reset [menu|host|status|leave|follow|race|all]'
local NAMES={menu=true,host=true,status=true,leave=true,follow=true,race=true,all=true}
function Keys.new(o)
    local self={}
    function self.keys(sub,name,extra)
        name=(name or 'all'):lower():gsub('_key$','')
        if sub~='reset' or extra~=nil or not NAMES[name] then return false,USE end
        if not o.menu then return false,'coop keys needs the co-op UI, which needs the Steam link' end
        return o.menu.reset(name~='all' and name..'_key' or nil)
    end
    return self
end
return Keys
