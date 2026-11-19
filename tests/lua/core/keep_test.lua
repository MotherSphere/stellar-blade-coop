-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- core/keep.lua with a fake native part (the list it writes, the status text) and a fake lookup: off without setup;
-- the whole list written in one file a pass (70 wants in one tick, one write of 70 lines), again every 4 passes while
-- the native count lags; a bad path logged once and never kept; ready() and get() never read the status, slow() reads
-- it once a pass; nothing looked up before the native part settles, one lookup a pass after, none marked while the
-- soft path is not proven; a held object that changed identity dropped and found again; a path missing on this PC
-- logged once, never looked up again; a want after it settled waits again; off for the Lua load on keep=fault, on an
-- engine line that says off or coop off and after 40 passes with no progress, so every module loads as before; 128
-- paths at most; LoadAsset and StaticFindObject never called.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
LoadAsset=function() error('LoadAsset called',0) end
StaticFindObject=function() error('StaticFindObject called',0) end
local Keep=require('core.keep')
local finds,objects,lines,writes={},{},{},{}
local status,status_reads,proven='engine=on keep=0 0 0',0,true
local function object(path)
    return {path=path,type=function() return 'UObject' end,IsValid=function() return true end,
        GetFullName=function(self) return 'Object '..self.path end}
end
local function logged(text) for _,l in ipairs(lines) do if l==text then return true end end return false end
local function count(text) return select(2,text:gsub('\n','')) end
local function setup()
    Keep.setup({write=function(text) writes[#writes+1]=text; return true end,
        status=function() status_reads=status_reads+1; return status end,
        log=function(line) lines[#lines+1]=line end,
        find=function(p)
            finds[#finds+1]=p
            if not proven then return nil,nil end
            return objects[p],true
        end})
end
local A,B,C='/Game/A/A.A','/Game/B/B.B_C','/Game/C/C.C'

-- 1. Off without setup: not wanted, ready, no lookup, no write.
Keep.want({A,B})
assert(not Keep.wanted(A) and Keep.ready() and not Keep.serves(A) and Keep.get(A)==nil and #finds==0 and #writes==0)
-- 2. setup: the paths wanted before it are kept; a bad path is logged once and never kept. The first pass writes the
--    whole list in one file and reads the status once; ready() and get() read none (Review Focus 6).
setup()
Keep.want({A,'/Game/A/A','/Other/X.X',A})
assert(Keep.wanted(A) and Keep.wanted(B) and not Keep.wanted('/Game/A/A'))
assert(logged('keep: /Game/A/A is no object path; not kept') and logged('keep: /Other/X.X is no object path; not kept'))
assert(Keep.path_ok('/Engine/EngineFonts/Roboto.Roboto') and not Keep.path_ok('/Game/A/A.B'))
assert(not Keep.path_ok('/Game/A A/B.B') and not Keep.path_ok('/Game/'..('a'):rep(100)..'.'..('a'):rep(100)))
Keep.slow()
assert(#writes==1 and writes[1]==A..'\n'..B..'\n' and status_reads==1)
assert(not Keep.ready() and Keep.get(A)==nil and status_reads==1 and #finds==0)
-- 3. Review Focus 9: 68 more wanted in one tick, one write of the 70 lines at the next pass. While the native count
--    stays below Lua's, the list is written again every 4 passes (a file the native part never took).
local many={}
for i=1,68 do many[i]='/Game/M/P'..i..'.P'..i end
Keep.want(many)
assert(#writes==1)
Keep.slow()
assert(#writes==2 and count(writes[2])==70)
for _=1,3 do Keep.slow() end
assert(#writes==3 and count(writes[3])==70 and not Keep.ready() and #finds==0)
-- 4. Review Focus 7: settled, one lookup a pass; get() gives the held object with no new lookup; one that changed
--    identity is dropped and found again.
objects[A],objects[B]=object(A),object(B)
status='engine=on keep=70 70 69'
Keep.slow()
assert(Keep.ready() and Keep.serves(A) and #finds==1 and finds[1]==A)
assert(Keep.get(A)==objects[A] and #finds==1 and Keep.get(B)==objects[B] and #finds==2)
Keep.slow()
assert(#finds==3 and finds[3]==many[1])
objects[A].path='/Game/Z/Z.Z'
local other=object(A)
objects[A]=other
assert(Keep.get(A)==other and #finds==4)
-- 5. Settled but not in memory: missing on this PC, logged once, never looked up again.
assert(logged('keep: '..many[1]..' is not in memory after its load: missing on this PC'))
assert(Keep.get(many[1])==nil and #finds==4)
-- 6. A path never wanted gives nil with no lookup.
assert(Keep.get('/Game/E/E.E')==nil and #finds==4 and not Keep.serves('/Game/E/E.E'))
-- 7. The soft path not proven yet (no pawn): nothing marked, the next pass tries the same path again.
proven=false
Keep.slow(); Keep.slow()
assert(finds[#finds]==many[2] and finds[#finds-1]==many[2])
assert(not logged('keep: '..many[2]..' is not in memory after its load: missing on this PC'))
proven=true
-- 8. A want after it settled: written at the next pass, not ready until the native part settled it too.
Keep.want({C}); Keep.slow()
assert(not Keep.ready() and count(writes[#writes])==71)
status='engine=on keep=71 71 70'; Keep.slow()
assert(Keep.ready())
-- 9. Review Focus 10: off for this Lua load on keep=fault, on an engine line that says off for any reason but "not
--    checked yet" (coop off included: the native part keeps nothing after it), or after 40 passes with no progress
--    (no DLL status, an older DLL with no keep= field). Off: not wanted, ready, no lookup, one line.
local function off_after(text,passes)
    Keep.reset()
    lines,finds={},{}
    setup()
    Keep.want({A})
    status=text
    for _=1,passes do Keep.slow() end
    return not Keep.wanted(A) and Keep.ready() and Keep.get(A)==nil and #finds==0
end
assert(off_after('engine=on keep=fault',1))
assert(logged('keep: off for this Lua load (the native part faulted); assets load as before') and #lines==1)
assert(off_after('engine=off reason=build 1.0 is not the pinned one',1))
assert(off_after('engine=on reason=coop_off',1))
assert(logged('keep: off for this Lua load (the native part is off: coop_off); assets load as before') and #lines==1)
assert(not off_after('engine=off reason=not checked yet',30) and off_after('engine=off reason=not checked yet',45))
assert(not off_after('engine=on keep=1 0 0',30) and off_after('engine=on keep=1 0 0',45) and #lines==1)
assert(off_after('engine=on',45))
-- 10. 128 paths at most.
Keep.reset()
lines={}
setup()
status='engine=on keep=0 0 0'
for i=1,Keep.MAX do Keep.want({'/Game/N/P'..i..'.P'..i}) end
Keep.want({'/Game/N/Q.Q'})
assert(not Keep.wanted('/Game/N/Q.Q') and logged('keep: 128 paths kept already; /Game/N/Q.Q not kept'))
Keep.reset()
print('core/keep_test ok')
