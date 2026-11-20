-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- A fake native part for core/keep.lua's users' tests: keep_fake(find) resets the keep and sets it up with find (the
-- object at a path and true); settle() makes the native part settle every path written so far, then runs enough
-- passes to find each one. tests/lua/core/keep_test.lua tests the keep itself.
local Keep=require('core.keep')
return function(find)
    Keep.reset()
    local k={status='engine=on keep=0 0 0',text=''}
    Keep.setup({write=function(t) k.text=t; return true end,status=function() return k.status end,
        log=function() end,find=find})
    function k.settle()
        local n=select(2,k.text:gsub('\n',''))
        k.status=('engine=on keep=%d %d %d'):format(n,n,n)
        for _=1,n+1 do Keep.slow() end
    end
    return k
end
