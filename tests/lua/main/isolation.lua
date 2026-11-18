-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The load-failure test each module's tests/lua/<module>/off_test.lua runs with its name (not a test file itself):
-- with the main tests' fixture, the module's require, the start of its new, the end of its new and each step of its
-- build raise in turn. Each time main.lua loads; the console handler, both loops and the key binds are registered;
-- the log has that module's off line and no other's; every other module is on (its exports are not the stub);
-- three frames and four passes, then a linked session in a world with the UI up for a frame and two passes, run with
-- no raised error and no "error (logged once" line; each key bind and each hook, called once, raise nothing; coop ui
-- reset and coop off raise nothing; coop off still asks the native part off; no line reads "OK: nil" or
-- "STOP: nil"; a pass with the kit ready says the notice with the module's English name; each late read with a guard
-- in its reader's wiring.lua (the menu's in main/ui.lua) gives a refusal while the module it reads is off; coop status
-- runs. The same run with every module on comes first, with the same checks and no off line. For bike, one more case:
-- with bike off and the tagged bike part of an earlier Lua load on EVE, the capture's leave_out gives that part's
-- address (partner's copy), so the ghost never shows a bike while EVE does not ride.
local real_print=print
dofile('tests/lua/main/fixture.lua')
local Loader=require('main.loader')
local T=require('ui.text')
local M -- main.lua's state table, as main.lua hands it to the loader.
local run=Loader.run
Loader.run=function(state,list) M=state; return run(state,list) end
local MODULES -- main.lua's list.
local menu -- The co-op menu's options, as main/ui.lua builds it (ui/kit/menu.lua).
local Menu=require('ui.kit.menu')
local menu_new=Menu.new
Menu.new=function(o) menu=o; return menu_new(o) end
local START={status_text=status_text,link_mode=link_mode,chatting=chatting,friend_linked=friend_linked,
    in_world=in_world,at_title=at_title,settings_text=settings_text}
-- The late reads with a guard in their reader's wiring.lua (the menu's in main/ui.lua), by the module they read: while
-- it is off, a refusal.
local GUARDED={['cut.enemies']={function() return nr.o.rows(function() end,'buy') end,
        function() return cs.o.rows(function() end) end},
    group={function() return nr.o.revive('Kaanta') end},
    session={function() return menu.sessions.open() end}, -- The menu's Find a session row.
    ['cut.scenes']={function() return ts.o.scene.talk('Sequence',{}) end},
    nightop={function() return sb.o.recruiter.run() end},
    ['cut.eve']={function() return sb.o.emote.sit('chair') end}}
local BINDS -- How many key binds the load with every module on registers.
local function count(list,pattern)
    local n=0
    for _,line in ipairs(list) do if tostring(line):find(pattern,1,true) then n=n+1 end end
    return n
end
-- One load with name broken as how says (nil: every module on), then every check above.
local function case(name,how)
    local at=(name or 'every module on')..', '..(how or 'nothing broken')
    for k,v in pairs(START) do _G[k]=v end
    local files={}
    for k,v in pairs(link_files) do files[k]=v end
    local heard=#said
    local ok,why=pcall(load_main,true)
    assert(ok,at..': the load raised: '..tostring(why))
    BINDS=BINDS or #binds
    assert(handler and #loops==2 and #binds==BINDS and BINDS>0,
        at..': the console handler, the two loops and the key binds')
    local function step(what,f)
        local done,e=pcall(f)
        assert(done,at..': '..what..' raised: '..tostring(e))
        flush()
    end
    for _=1,3 do step('a frame',loops[1].f) end
    for _=1,4 do step('a pass',quarter) end
    status_text=with_slot('slot=coop index=4 marker=4\n'):gsub('link=none','link=host')
    link_mode,chatting,friend_linked,in_world,at_title,kit_ready='host',true,true,true,false,true
    step('a frame in a session',loops[1].f)
    for _=1,2 do step('a pass in a session',quarter) end
    for _,f in ipairs(name and GUARDED[name] or {}) do
        local refused,why=f()
        assert(refused==false and type(why)=='string',at..': a guarded late read gave '..tostring(refused)..', '
            ..tostring(why))
    end
    if M.commands.status then -- It reads the ghost's part late.
        step('coop status',function() coop('status') end)
        assert(printed[#printed]:find('[StellarCoop] OK: ',1,true)==1,at..': coop status: '..printed[#printed])
    end
    local binds_now={}
    for i,b in ipairs(binds) do binds_now[i]=b end
    for _,b in ipairs(binds_now) do step('the bind of '..tostring(b.key),b.f) end
    local paths={}
    for path in pairs(hooks) do paths[#paths+1]=path end
    table.sort(paths)
    for _,path in ipairs(paths) do step('the hook '..path,hooks[path]) end
    step('coop ui reset',function() coop('ui','reset') end)
    local asks=#asked
    step('coop off',function() coop('off') end)
    assert(#asked>asks and asked[#asked]=='off','coop off asks the native part off: '..at)
    for i,line in ipairs(printed) do
        assert(not line:find('error (logged once',1,true),at..': '..line)
        assert(not line:find('%] OK: nil\n') and not line:find('%] STOP: nil\n'),at..': '..line)
        if line:find(': off until the mod reloads: ',1,true) then
            assert(name and line:find('[StellarCoop] '..name..': off until the mod reloads: ',1,true),at..': '..line)
            assert(printed[i+1] and printed[i+1]:find('stack traceback:',1,true),at..': no traceback after '..line)
        end
    end
    assert(count(printed,': off until the mod reloads: ')==(name and 1 or 0),at..': one off line')
    for _,other in ipairs(MODULES) do
        local wiring=package.loaded[other..'.wiring']
        if other~=name then
            assert(M.off_modules[other]==nil,at..': '..other..' went off')
            for _,e in ipairs(wiring.exports) do
                assert(M[e]~=Loader.STUB,at..': '..other..'\'s '..e..' is the stub')
            end
        end
    end
    if name then
        assert(M.off_modules[name],at..': '..name..' is not off')
        local text=T.en.module_off:format(T.en.modules[name])
        local told=false
        for i=heard+1,#said do told=told or said_en[i]==text end
        for _,line in ipairs(chat_calls) do told=told or line:find('system '..text,1,true)==1 end
        assert(told,at..': no notice "'..text..'"')
    end
    link_files,settings_text=files,START.settings_text
end

return function(name)
    local main=assert(io.open('mod/StellarCoop/Scripts/main.lua','rb')):read('a')
    MODULES={}
    for m in main:match('MODULES=(%b{})'):gmatch("'([%w_.]+)'") do MODULES[#MODULES+1]=m end
    local wiring=name..'.wiring'
    local real=require(wiring)
    case(nil,nil)
    local function inject(how,make)
        package.preload[wiring],package.loaded[wiring]=nil,nil
        if how=='its require raises' then package.preload[wiring]=make
        else package.loaded[wiring]=make end
        case(name,how)
        package.preload[wiring],package.loaded[wiring]=nil,real
    end
    local function with(field,value)
        local m={}
        for k,v in pairs(real) do m[k]=v end
        m[field]=value
        return m
    end
    inject('its require raises',function() error('injected: '..name..'/wiring.lua does not load') end)
    inject('its new raises at its start',with('new',function() error('injected: '..name..' new raises') end))
    inject('its new raises after it ran',with('new',function(state)
        real.new(state)
        error('injected: '..name..' new raises at its end')
    end))
    local steps={}
    for step in pairs(real.build or {}) do steps[#steps+1]=step end
    table.sort(steps)
    for _,step in ipairs(steps) do
        local build={}
        for k,v in pairs(real.build) do build[k]=v end
        build[step]=function() error('injected: '..name..' build step '..step..' raises') end
        inject('its build step '..step..' raises',with('build',build))
    end
    if name=='bike' then
        -- An earlier Lua load's bike part on EVE, tagged: the ghost's capture leaves it out through partner's copy.
        local function uobj(o)
            o.type=function() return 'UObject' end
            o.IsValid=function() return true end
            return o
        end
        local MESH='/Game/Art/Character/ETC/Adam_vehicle_02/Adam_Vehicle_02.Adam_Vehicle_02'
        local planted={['/Script/SB.SBCharacter']=uobj({path='/Script/SB.SBCharacter'}),
            ['/Script/Engine.SkeletalMeshComponent']=uobj({path='/Script/Engine.SkeletalMeshComponent'})}
        local part=uobj({SkeletalMesh=uobj({GetFullName=function() return 'SkeletalMesh '..MESH end}),
            GetAddress=function() return 0x203 end,ComponentHasTag=function(_,tag) return tag=='SBO_Bike' end})
        local eve=uobj({GetAddress=function() return 0x100 end,
            IsA=function(_,c) return c.path=='/Script/SB.SBCharacter' end,
            K2_GetComponentsByClass=function() return {part} end})
        local find,UE=StaticFindObject,package.loaded.UEHelpers
        StaticFindObject=function(path) return planted[path] or find(path) end
        UE.GetPlayer=function() return eve end
        package.loaded[wiring]=nil
        package.preload[wiring]=function() error('injected: bike/wiring.lua does not load') end
        load_main(true)
        assert(M.off_modules.bike and capture_leave_out,'bike off, partner gave the capture its leave_out')
        assert(capture_leave_out(0x100)==0x203,'With bike off, the capture leaves out the bike part on EVE')
        assert(capture_leave_out(0x999)==nil,'Another EVE: nothing left out')
        package.preload[wiring],package.loaded[wiring]=nil,real
        StaticFindObject,UE.GetPlayer=find,nil
    end
    print=real_print
end
