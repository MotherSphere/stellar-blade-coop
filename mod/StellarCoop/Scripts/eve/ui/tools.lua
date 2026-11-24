-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- EVE's cut moves' page of the co-op menu's TEST TOOLS (ui/kit/model.lua says a page's shape): Debug flight (coop
-- fly), Slow motion (coop slowmo) and Glide (coop glide) as switches. Select, left or right asks the other state
-- through the console's own path (run: logged, refused at coop off and, for on, off a co-op save, as typed); a refusal
-- shows under the rows. Each shows On while the native part took its last on in this Lua load (fly and slowmo) or
-- eve/glide.lua has it on (glide).
local Tools={}
Tools.ROWS={'fly','slowmo','glide'}
-- o: {run=function(name, word) -> ok, message (main/commands.lua's run), on=function(name) -> its state}.
function Tools.new(o)
    local page={}
    function page.title(w) return w.modules.eve end
    function page.rows(w)
        local rows={}
        for _,name in ipairs(Tools.ROWS) do
            local on=o.on(name)==true
            local function flip()
                local ok,why=o.run(name,on and 'off' or 'on')
                if ok then return true end
                return false,why
            end
            rows[#rows+1]={id=name,label=w.tools.eve[name],value=w.value[on and 'on' or 'off'],select=flip,step=flip}
        end
        return rows
    end
    return page
end
return Tools
