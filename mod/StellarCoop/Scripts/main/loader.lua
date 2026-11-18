-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The module loader: each module's wiring.lua in main.lua's order, its words merged, its kit groups built.
local Loader={}
-- What an off module's exports read as, so a late read of it never raises: every field is a function that does nothing
-- and returns nothing; a call of the stub itself does the same.
local NOOP=function() end
Loader.STUB=setmetatable({},{__index=function() return NOOP end,__call=NOOP})
local STUB=Loader.STUB
-- Each module's words as its new gave them, by M (the tests load main.lua again in one Lua state).
local words_of=setmetatable({},{__mode='k'})
-- An error with the stack where it was raised.
local function caught(e) return {why=tostring(e),trace=debug.traceback(nil,2)} end
-- The exports a wiring.lua that does not load names in its text, or nil.
local function listed(name)
    local path=package.searchpath(name..'.wiring',package.path)
    local f=path and io.open(path,'rb')
    if not f then return nil end
    local text=f:read('a')
    f:close()
    local names={}
    for e in (text and text:match('exports=(%b{})') or ''):gmatch("'([%w_]+)'") do names[#names+1]=e end
    return names[1] and names or nil
end
-- A module that failed is off until the mod reloads: its exports back to the stub, its words out of M.commands, one
-- log line and its traceback, its name for main/pass.lua's notice. No other module is touched.
local function off(M,name,e,exports)
    for _,x in ipairs(exports or {}) do M[x]=STUB end
    for _,word in ipairs((words_of[M] or {})[name] or {}) do M.commands[word]=nil end
    M.off_modules[name]=e.why
    M.off_notes[#M.off_notes+1]=name
    M.log(name..': off until the mod reloads: '..e.why:match('^[^\n]*')
        ..(exports and '' or ' (its exports were not found in its wiring.lua: they read nil)'))
    M.log(e.trace)
end
-- Every wiring required and every export of every manifest set to the stub first, so no late read finds nil; then
-- each module's new(M) in list order, its exports cleared before it so each is what new left (nil included). The
-- command handlers new returns go into M.commands (a word defined twice raises). A require or a new that raises turns
-- that module alone off; a manifest with needs raises (a wiring mistake: no module needs another).
function Loader.run(M,list)
    M.off_modules=M.off_modules or {}
    M.off_notes=M.off_notes or {}
    words_of[M]={}
    local manifests,failed={},{}
    for _,name in ipairs(list) do
        local ok,m=xpcall(require,caught,name..'.wiring')
        if ok then
            assert(m.needs==nil,name..'/wiring.lua has needs: no module needs another')
            manifests[name]=m
            for _,x in ipairs(m.exports) do M[x]=STUB end
        else
            local found,exports=pcall(listed,name)
            exports=found and exports or nil
            for _,x in ipairs(exports or {}) do M[x]=STUB end
            failed[#failed+1]={name,m,exports}
        end
    end
    for _,f in ipairs(failed) do off(M,f[1],f[2],f[3]) end
    for _,name in ipairs(list) do
        local m=manifests[name]
        if m then
            for _,x in ipairs(m.exports) do M[x]=nil end
            local ok,handlers=xpcall(m.new,caught,M)
            if ok then
                local words={}
                for word,handler in pairs(handlers or {}) do
                    assert(M.commands[word]==nil,'coop '..word..' is defined twice')
                    M.commands[word]=handler
                    words[#words+1]=word
                end
                words_of[M][name]=words
            else off(M,name,handlers,m.exports) end
        end
    end
end
-- One of a module's build steps (some of its kit groups), where main/ui.lua builds them: skipped while the module is
-- off; a step that raises turns it off.
function Loader.build(M,module,step,Ui)
    if M.off_modules[module] then return end
    local m=require(module..'.wiring')
    local ok,e=xpcall(m.build[step],caught,M,Ui)
    if not ok then off(M,module,e,m.exports) end
end
-- An object read late through M: each field read reads M[field]'s at that moment (the stub's while its module is off).
function Loader.view(M,field) return setmetatable({},{__index=function(_,k) return M[field][k] end}) end
-- M[field] at each call while module is on, nil while it is off, for code that tests whether the object is there.
function Loader.get(M,module,field) return function() if not M.off_modules[module] then return M[field] end end end
return Loader
