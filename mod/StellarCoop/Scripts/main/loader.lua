-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The module loader: each module's wiring.lua in main.lua's order, its words merged, its kit groups built.
local Loader={}
-- Each module's new(M) in list order; the command handlers it returns go into M.commands (a word defined twice
-- raises).
function Loader.run(M,list)
    M.off_modules=M.off_modules or {}
    for _,name in ipairs(list) do
        local handlers=require(name..'.wiring').new(M)
        for word,handler in pairs(handlers or {}) do
            assert(M.commands[word]==nil,'coop '..word..' is defined twice')
            M.commands[word]=handler
        end
    end
end
-- One of a module's build steps (some of its kit groups), where main/ui.lua builds them.
function Loader.build(M,module,step,Ui) require(module..'.wiring').build[step](M,Ui) end
-- An object read late through M: each field read reads M[field]'s at that moment.
function Loader.view(M,field) return setmetatable({},{__index=function(_,k) return M[field][k] end}) end
-- M[field] at each call, for code that tests whether the object is there.
function Loader.get(M,module,field) return function() return M[field] end end
return Loader
