-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop closet probe <1-5|off>: the closet menu design's five in-game tests of Stellar Blade's own widget parts (the
-- piece grid, a grid slot alone, the tab buttons, the detail panel, focus and input), one at a time, each check a
-- "probe: PASS <n> <check>" or "probe: FAIL <n> <check>: <why>" line in UE4SS.log. Their results decide how the closet
-- menu builds its piece grid. Only UI: EVE, saves and the closet's look are never touched.
-- A test is a list of steps {frames=<frames to wait after the step before>, name=<check>, run=function(ctx)}. run
-- returns true (PASS), false and why (FAIL), or 'wait' (run again next frame: a check that watches the mouse or a map
-- change). The first FAIL ends the test. Before each step every part the test made must still be ours (kit.alive),
-- unless a step set ctx.free_parts (a map change it waits for). A test ends by itself after TIMEOUT s (or its own
-- timeout), on coop closet probe off, a second run, coop off (stop) or coop ui reset (the kit gives the input back).
-- Each end runs the test's cleanup, drops its parts, gives the kit's input back and logs "probe: END <n> <passed>/
-- <total>". The parts go in the kit group closet_probe (screen-sized, added once a Lua load at the first run). Every
-- step runs in pcall on the game thread (closet/wiring.lua runs tick each frame through main/frame.lua's guard).
local Probe={}
Probe.TIMEOUT=30 -- Seconds a test may run unless it sets its own.
Probe.USE='Use: coop closet probe <1-5|off>'
Probe.GROUP='closet_probe'
Probe.TESTS={}
-- A game object by path: in memory, else after a synchronous LoadAsset (a class path loads its asset path without
-- _C), as ui/kit/kit.lua's load does.
local function default_find(path)
    local o=StaticFindObject(path)
    if o and o:IsValid() then return o end
    pcall(LoadAsset,path:match('^(.*)_C$') or path)
    o=StaticFindObject(path)
    return o and o:IsValid() and o or nil
end

function Probe.new(o)
    local log=function(m) o.log('probe: '..m) end
    local clock=o.clock or os.clock
    local tests=o.tests or Probe.TESTS
    local find=o.find or default_find
    local construct=o.construct or function(class,outer) return StaticConstructObject(class,outer) end
    local self={}
    local added=false
    local cur -- The running test: {n, test, i, wait, parts, passed, total, deadline, shown, ctx}

    local function finish()
        local c=cur
        if not c then return end
        cur=nil
        if c.test.cleanup then
            local ok,e=pcall(c.test.cleanup,c.ctx)
            if not ok then log('cleanup '..c.n..': '..tostring(e)) end
        end
        local kit=o.kit()
        if kit then
            for _,rec in ipairs(c.parts) do pcall(kit.drop,rec) end
            pcall(kit.input,false,Probe.GROUP)
        end
        log(string.format('END %s %d/%d',c.n,c.passed,c.total))
    end
    local function fail(name,why)
        log(string.format('FAIL %s %s: %s',cur.n,name,tostring(why)))
        finish()
    end

    -- coop closet probe <n>: starts test n (ending one that runs).
    function self.run(n)
        local test=tests[n]
        if not test then return false,Probe.USE end
        finish()
        local kit=o.kit()
        if not (kit and kit.ready() and not kit.off()) then
            log('FAIL '..n..' kit: the UI is not up')
            return false,'closet probe: the UI is not up (it needs the Steam link and the game world)'
        end
        if not added then
            kit.add(Probe.GROUP,{x=0,y=0,w=3840,h=2160,fixed=true,hit=true},function() return {} end)
            added=true
        end
        local c={n=n,test=test,i=1,wait=test.steps[1].frames or 0,parts={},passed=0,total=#test.steps,
            deadline=clock()+(test.timeout or Probe.TIMEOUT),shown=false}
        c.ctx={log=log,find=find,construct=construct,data={},kit=kit,now=clock}
        -- A game widget made in the probe's group, kept for the end; it throws when the kit refuses.
        function c.ctx.make(class_path,x,y,w,h,fill,hit)
            local rec,why=kit.part(Probe.GROUP,class_path,x,y,w,h,fill,hit)
            if not rec then error(why,0) end
            c.parts[#c.parts+1]=rec
            return rec.o
        end
        -- Forgets the parts (a map change freed them).
        function c.ctx.forget() c.parts={} end
        cur=c
        log('START '..n..' ('..c.total..' checks)')
        return true,'closet probe '..n..': running, its lines go to UE4SS.log'
    end
    function self.off()
        if not cur then return true,'probe: nothing running' end
        finish()
        return true,'probe: off'
    end
    -- coop off.
    function self.stop() finish() end
    function self.running() return cur and cur.n or nil end
    -- Each frame, on the game thread.
    function self.tick()
        if not cur then return end
        local kit=o.kit()
        if clock()>cur.deadline then return fail('timeout','after '..(cur.test.timeout or Probe.TIMEOUT)..' s') end
        if not kit then return fail('kit','gone') end
        cur.ctx.kit=kit
        if not cur.shown then
            if not kit.view(Probe.GROUP) then return end
            kit.show(Probe.GROUP,true)
            cur.shown=true
        end
        if cur.wait>0 then cur.wait=cur.wait-1; return end
        if not cur.ctx.free_parts then
            for _,rec in ipairs(cur.parts) do
                if not kit.alive(rec) then return fail('parts','gone') end
            end
        end
        local step=cur.test.steps[cur.i]
        local ran,result,why=pcall(step.run,cur.ctx)
        if not ran then return fail(step.name,result) end
        if result=='wait' then return end
        if not result then return fail(step.name,why or 'no') end
        log(string.format('PASS %s %s%s',cur.n,step.name,why and (': '..tostring(why)) or ''))
        cur.passed=cur.passed+1
        cur.i=cur.i+1
        local next_step=cur.test.steps[cur.i]
        if not next_step then return finish() end
        cur.wait=next_step.frames or 0
    end
    return self
end

return Probe
