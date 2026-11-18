-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- main/loader.lua alone, with fake modules in package.preload: before any new runs, every export of every manifest is
-- the stub (also those of a module whose require raises, read from its wiring.lua's exports through
-- package.searchpath); the modules load in list order; an on module's exports are what its new left in M, nil
-- included, and its words go into M.commands (a word defined twice raises); a require, a new (at its start or after it
-- set its exports) or a build step that raises turns that module alone off: one log line, the traceback on the next,
-- its name in off_notes, its exports back to the stub, its words gone, its later build steps skipped; a manifest with
-- needs raises; view reads the field at each read, get gives nil while the module is off; M.off is kept.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Loader=require('main.loader')
local STUB=assert(Loader.STUB,'main/loader.lua has no stub')
local logged={}
local function fresh() logged={} return {log=function(m) logged[#logged+1]=tostring(m) end,commands={}} end
local function wiring(name,manifest)
    package.loaded[name..'.wiring']=nil
    package.preload[name..'.wiring']=function() return manifest end
end
local function broken(name,why)
    package.loaded[name..'.wiring']=nil
    package.preload[name..'.wiring']=function() error(why) end
end
-- A wiring.lua that does not load: its exports come from its text, through package.searchpath and the file.
local BAD_TEXT="return {\nuses={},\nexports={'c','c2'},\nnew=function(M)\nend,\n}\n"
local real_searchpath,real_open=package.searchpath,io.open
package.searchpath=function(name,path)
    if name=='bad.wiring' then return 'fake/bad/wiring.lua' end
    if name=='gone.wiring' then return nil,'\n\tno file' end
    return real_searchpath(name,path)
end
io.open=function(path,mode)
    if path=='fake/bad/wiring.lua' then return {read=function() return BAD_TEXT end,close=function() end} end
    return real_open(path,mode)
end
local function off_line(name,what)
    for i,line in ipairs(logged) do
        if line:find('^'..name..': off until the mod reloads: ') then
            assert(line:find(what,1,true),line)
            assert(not line:find('\n'),'One line: '..line)
            assert(logged[i+1] and logged[i+1]:find('^stack traceback:'),
                'The traceback after it: '..tostring(logged[i+1]))
            return i
        end
    end
    error('No off line for '..name)
end

local order={}
wiring('one',{uses={},exports={'a','a_nil'},new=function(M)
    order[#order+1]='one'
    assert(M.a==nil and M.a_nil==nil,'Its own stubs cleared before its new')
    assert(M.b==STUB and M.b_ui==STUB and M.d==STUB and M.e==STUB and M.f==STUB,'Every other export is the stub')
    assert(M.c==STUB and M.c2==STUB,'Those of a wiring that did not load too, read from its file')
    M.a={f=function() return 1 end}
    return {one=function() return true,'one' end}
end,build={boom=function() error('one broke') end}})
broken('bad','bad wiring')
wiring('two',{uses={'one'},exports={'b','b_ui'},new=function(M)
    order[#order+1]='two'
    M.b=function() return 'b' end
    return {two=function() return true,'two' end}
end,build={ui=function(M,Ui) M.b_ui={ui=Ui} end}})
wiring('early',{uses={},exports={'d'},new=function(M)
    order[#order+1]='early'
    error('early broke\nsecond line')
end,build={x=function() error('an off module builds nothing') end}})
wiring('late',{uses={},exports={'e'},new=function(M)
    order[#order+1]='late'
    M.e={g=function() return 'real' end}
    error('late broke')
end})
wiring('built',{uses={},exports={'f','f_ui'},new=function(M)
    order[#order+1]='built'
    M.f={h=function() return 'f' end}
    return {built=function() return true,'built' end}
end,build={first=function() error('built broke') end,second=function(M) M.f_ui='built anyway' end}})
broken('gone','gone wiring')

local M=fresh()
M.off='kept'
Loader.run(M,{'one','bad','two','early','late','built','gone'})
assert(M.off=='kept','M.off as it was')
assert(table.concat(order,' ')=='one two early late built','Each new once, in list order')
-- On modules: what their new left.
assert(M.a.f()==1 and M.a_nil==nil and M.b()=='b' and M.f.h()=='f','What new left in M, nil included')
assert(M.b_ui==nil and M.f_ui==nil,'A build step export is nil until its step runs')
assert(M.commands.one and M.commands.two and M.commands.built,'Their words')
-- Off modules: the stub, one line and the traceback each, in off_notes in the order they failed.
assert(M.c==STUB and M.c2==STUB and M.d==STUB and M.e==STUB,'An off module reads as the stub')
assert(M.e.g()==nil and select('#',M.e.g())==0 and select('#',M.e())==0,'The stub does nothing and returns nothing')
off_line('bad','bad wiring')
off_line('gone','gone wiring')
off_line('gone','its exports were not found')
assert(M.gone==nil,'No exports found: no stub')
local i=off_line('early','early broke')
assert(not logged[i]:find('second line',1,true),'The first line of the error only')
off_line('late','late broke')
assert(table.concat(M.off_notes,' ')=='bad gone early late','The notes: '..table.concat(M.off_notes,' '))
for _,name in ipairs({'bad','gone','early','late'}) do assert(M.off_modules[name],name..' is off') end
for _,name in ipairs({'one','two','built'}) do assert(M.off_modules[name]==nil,name..' is on') end
local offs=0
for _,line in ipairs(logged) do if line:find(': off until the mod reloads: ') then offs=offs+1 end end
assert(offs==4,'One off line each: '..offs)

-- view: the field at each read; get: the export while its module is on, nil while it is off.
local v=Loader.view(M,'a')
assert(v.f()==1,'A view reads the real object while its module is on')
assert(Loader.get(M,'two','b')()==M.b and Loader.get(M,'early','d')()==nil,'get: the export, nil while off')

-- A build step: built on success; one that raises turns that module alone off, words and exports included.
Loader.build(M,'two','ui','UI')
assert(M.b_ui.ui=='UI','The step ran with Ui')
Loader.build(M,'early','x','UI') -- Skipped: early is off.
Loader.build(M,'built','first','UI')
off_line('built','built broke')
assert(M.f==STUB and M.f_ui==STUB and M.commands.built==nil,'built is off: its exports stubbed, its words gone')
Loader.build(M,'built','second','UI')
assert(M.f_ui==STUB,'A later step of an off module is skipped')
assert(M.commands.one and M.commands.two and M.a.f()==1 and M.b()=='b','The others stay on')
Loader.build(M,'one','boom','UI')
assert(v.f()==nil and M.a==STUB and M.commands.one==nil,'A view reads the stub once its module went off')
assert(M.b()=='b' and M.commands.two,'two stays on')
assert(table.concat(M.off_notes,' ')=='bad gone early late built one')
offs=0
for _,line in ipairs(logged) do if line:find(': off until the mod reloads: ') then offs=offs+1 end end
assert(offs==6,'No other module went off: '..offs)

-- A word defined twice still raises; a manifest with needs raises (a wiring mistake: the field is gone).
wiring('dup1',{uses={},exports={},new=function() return {same=function() end} end})
wiring('dup2',{uses={},exports={},new=function() return {same=function() end} end})
local ok,why=pcall(Loader.run,fresh(),{'dup1','dup2'})
assert(not ok and tostring(why):find('coop same is defined twice',1,true),tostring(why))
wiring('needy',{needs={'one'},uses={},exports={},new=function() end})
ok,why=pcall(Loader.run,fresh(),{'needy'})
assert(not ok and tostring(why):find('needs',1,true),tostring(why))
wiring('plain',{uses={},exports={'p'},new=function(M) M.p=function() end end})
M=fresh()
Loader.run(M,{'plain'})
assert(M.off==nil and M.off_modules.plain==nil and #M.off_notes==0,'No off set by the loader')

package.searchpath,io.open=real_searchpath,real_open
print('loader_test ok')
