-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's texts against its code and scripts: the rifle layer's pak has one name, the tools say what they make,
-- comments hold no play-session clock times or plans that are not in the repository. Runs from the repository's root.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local S='mod/StellarCoop/Scripts/fight/gunmode/'
local function read(path) local f=assert(io.open(path,'rb'),path); local s=f:read('a'); f:close(); return s end
local function files(cmd)
    local out={}
    for l in io.popen(cmd):lines() do out[#out+1]=l end
    table.sort(out)
    assert(#out>0,cmd)
    return out
end
-- f(path, line number, line) for each line of each file.
local function lines(paths,f)
    for _,p in ipairs(paths) do
        local n=0
        for l in (read(p)..'\n'):gmatch('([^\n]*)\n') do n=n+1; f(p,n,l) end
    end
end
local LUA=files("find "..S.." -name '*.lua'")
local TOOLS=files('find tools/gunmode -type f')
local PAGE='docs/fight/gunmode.md'
local page=read(PAGE)
-- NOTICE's gun mode section: from its title to the next title (a line in capitals).
local notice=read('NOTICE'):match('\nGUN MODE\n(.-)\n%u[%u%- ]+\n')
assert(notice,'NOTICE has a GUN MODE section')
local bad={}
local function fail(m) bad[#bad+1]=m end

-- 1. One pak name: the one the rifle layer's build script writes (its NGM_PAK default), holding the class
--    fight/gunmode/overlay.lua looks for. No other z..._P pak name or ABP_NGM_ asset in gun mode's code, tools, page
--    or NOTICE section. The page and NOTICE name both. NOTICE names the Mixamo set's source.
local PAK=read('tools/gunmode/rebuild/ngm_spike_build_a4.py'):match('"NGM_PAK", "(z[%w_]+_P)"')
assert(PAK,'the build script names its pak')
local ASSET=require('fight.gunmode.overlay').CLASS:match('/([%w_]+)%.[%w_]+$')
assert(ASSET,'overlay.lua names its class')
do
    local paths={PAGE}
    for _,p in ipairs(LUA) do paths[#paths+1]=p end
    for _,p in ipairs(TOOLS) do paths[#paths+1]=p end
    local function check(p,n,l)
        for name in l:gmatch('%f[%w]z%u[%w]*_P%f[%W]') do
            if name~=PAK then fail(('%s:%d: pak %s, not %s'):format(p,n,name,PAK)) end
        end
        for name in l:gmatch('ABP_NGM_[%w]+') do
            if name~=ASSET then fail(('%s:%d: %s, not %s'):format(p,n,name,ASSET)) end
        end
    end
    lines(paths,check)
    local n=0
    for l in (notice..'\n'):gmatch('([^\n]*)\n') do n=n+1; check('NOTICE (GUN MODE)',n,l) end
    for _,where in ipairs({{PAGE,page},{'NOTICE (GUN MODE)',notice}}) do
        for _,want in ipairs({PAK,ASSET}) do
            if not where[2]:find(want,1,true) then fail(where[1]..' does not name '..want) end
        end
    end
    if not notice:find('Mixamo',1,true) then fail('NOTICE (GUN MODE) does not name Mixamo') end
end

-- 2. The tools: each script starts with the SBO license lines. A script name in a tool's comments or the README is the
--    name of a file in tools/gunmode, never an older name. No session notes (v8:, take 4) there. The Blender and Unreal scripts need NGM_TOOLS
--    set (no default folder) and import into no shipped game folder. export_stand.py opens by default what
--    retarget_mixamo_stand.py writes. The README names each file and what no script here makes.
do
    local here={}
    for _,p in ipairs(TOOLS) do here[p:match('[^/]+$')]=true end
    local HEAD='# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors\n'
        ..'# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later\n'
    for _,p in ipairs(TOOLS) do
        if p:match('%.py$') and read(p):sub(1,#HEAD)~=HEAD then fail(p..': no SBO license lines') end
    end
    lines(TOOLS,function(p,n,l)
        if p:match('%.py$') then l=l:match('#(.*)$') or '' end -- Its comments.
        for name in l:gmatch('[%w_]+%.py%f[^%w_]') do
            if not here[name] then fail(('%s:%d: names %s, not a file of tools/gunmode'):format(p,n,name)) end
        end
        if l:find('%f[%w]v%d+:') or l:find('%f[%w][Tt]ake %d') then fail(('%s:%d: a session note'):format(p,n)) end
    end)
    for _,p in ipairs(files("find tools/gunmode/blender tools/gunmode/unreal -name '*.py'")) do
        local s=read(p)
        if not s:find('NGM_TOOLS',1,true) or s:find('Downloads',1,true) then fail(p..': NGM_TOOLS with a default') end
        if s:find('/Game/DLC_2',1,true) then fail(p..': imports into a shipped game folder') end
    end
    local rt=read('tools/gunmode/blender/retarget_mixamo_stand.py')
    local dir=rt:match('OUT = os%.path%.join%(B, "blend", "([%w_]+)"%)')
    local blend=rt:match('save_as_mainfile%(filepath=os%.path%.join%(OUT, "([%w_]+%.blend)"%)%)')
    assert(dir and blend,'retarget_mixamo_stand.py saves a .blend')
    if not read('tools/gunmode/blender/export_stand.py'):find(('"blend", "%s", "%s"'):format(dir,blend),1,true) then
        fail('export_stand.py does not open '..dir..'/'..blend..' by default')
    end
    local readme=read('tools/gunmode/README.md')
    for name in pairs(here) do
        if name~='README.md' and not readme:find(name,1,true) then fail('tools/gunmode/README.md does not name '..name) end
    end
    for _,want in ipairs({ASSET,'NGM_R_','SBOutfitProject'}) do
        if not readme:find(want,1,true) then fail('tools/gunmode/README.md does not name '..want) end
    end
end

-- 3. Gun mode's code, tests, tools and page: no clock time of a play session unless it names its log (as in
--    "UE4SS.log 2026-11-12 21:49"). No reference to NGM_FACTS.md or the rebuild's plan: neither is in this repository.
do
    local paths={PAGE}
    for _,list in ipairs({LUA,TOOLS,files("find tests/lua/fight/gunmode -name '*.lua'")}) do
        for _,p in ipairs(list) do
            if not p:match('texts_test%.lua$') then paths[#paths+1]=p end
        end
    end
    lines(paths,function(p,n,l)
        for at,t in l:gmatch('()(%d%d?:%d%d)') do
            if not l:sub(1,at-1):find('UE4SS%.log %d%d%d%d%-%d%d%-%d%d $') then
                fail(('%s:%d: clock time %s'):format(p,n,t))
            end
        end
        for _,ref in ipairs({'NGM_FACTS','v2 plan','v2:','Phase 0','Phase 1','the plan'}) do
            if l:find(ref,1,true) then fail(('%s:%d: cites %s'):format(p,n,ref)) end
        end
    end)
end

-- 4. The page as the code runs: it names every table fight/gunmode/data.lua changes and the notice the parked key
--    shows. Neither the page nor ammo.lua's header promises the bottom-left round count while mode.lua builds the
--    rounds with no D-pad slot. The page and the docs index row speak of no crouching. Plain prose on the page: no
--    ", and" or ", but", no bold-label bullets, no "co-op session". No ", and" or ", but" either in the comments this
--    pass rewrote: ammo.lua's header, facts.lua's note on the retired F11.
do
    local seen={}
    for t in read(S..'data.lua'):gmatch("tbl%('([%w_]+)'%)") do
        if not seen[t] and not page:find('`'..t..'`',1,true) then fail(PAGE..' does not name '..t) end
        seen[t]=true
    end
    assert(next(seen),'data.lua opens tables')
    if not page:find(require('ui.text').en.gun.rebuilding,1,true) then fail(PAGE..' does not quote the parked notice') end
    if read(S..'mode.lua'):find('Ammo.new(g,cfg,function(v) data.cool(v) end,on_reload,nil)',1,true) then
        local head=read(S..'ammo.lua'):match('^(.-)\nlocal Ammo')
        for _,w in ipairs({{PAGE,page},{S..'ammo.lua (header)',head}}) do
            if w[2]:find('rounds | magazines',1,true) then fail(w[1]..' promises a bottom-left count no code draws') end
        end
    end
    local row=read('docs/README.md'):match('\n(| %[Gun mode%][^\n]*)')
    assert(row,'docs/README.md has a gun mode row')
    for _,w in ipairs({{PAGE,page},{'docs/README.md (gun mode)',row},{S..'commands.lua',read(S..'commands.lua')}}) do
        if w[2]:lower():find('crouch',1,true) then fail(w[1]..' speaks of crouching') end
    end
    local f11=read(S..'facts.lua'):match('(%-%- F11 retired.-)\n%s*if ')
    assert(f11,'facts.lua has its note on the retired F11')
    for _,w in ipairs({{PAGE,page},{S..'ammo.lua (header)',read(S..'ammo.lua'):match('^(.-)\nlocal Ammo')},
            {S..'facts.lua (F11 retired)',f11}}) do
        local flat=w[2]:gsub('%s*%-%-%s+',' '):gsub('%s+',' ')
        for _,j in ipairs({', and ',', but '}) do
            if flat:find(j,1,true) then fail(w[1]..': "'..j..'" joins two clauses') end
        end
    end
    lines({PAGE},function(p,n,l)
        if l:find('^%s*[-*] %*%*[^*]+:%*%*') then fail(('%s:%d: a bold-label bullet'):format(p,n)) end
        if l:lower():find('co-op session',1,true) then fail(('%s:%d: "co-op session"'):format(p,n)) end
    end)
end

if #bad>0 then error('\n'..table.concat(bad,'\n'),0) end
print('gunmode texts: ok')
