-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The hold at an SBO lobby arrival (online/lobby/arrival.lua) over fakes: the clock, SB's black (fade: counted, or a
-- raise), its end fade (lift: the requests, or a refusal), the kit's veil and the log. Covered: no hold without a lobby
-- warp, nor before its new controller; the black up and the kit veiled at the pass after ClientRestart; held until
-- every item is ready, then lifted once, the veil off, and one line with the time; the cap lifts whatever is missing,
-- with what was missing, also when the items cannot be read; a second warp under the hold (a guest following her host)
-- keeps the black and the veil, puts up a new black at its controller and counts the cap from there; disarm (a refused
-- warp, coop off) lifts a black up and drops a waiting warp; a warp with no new controller dropped at the arm cap,
-- lifting a black kept for it; a black that does not show veils nothing; a refused lift still unveils and says SB ends
-- it.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Arrival=require('online.lobby.arrival')
local now,fades,fade_error,lifts,lift_refusal,veils,logs=100,0,nil,0,nil,{},{}
local function new()
    now,fades,fade_error,lifts,lift_refusal,veils,logs=100,0,nil,0,nil,{},{} -- Times in quarters: exact in binary.
    return Arrival.new({clock=function() return now end,log=function(line) logs[#logs+1]=line end,
        fade=function() if fade_error then error(fade_error,0) end fades=fades+1 end,
        lift=function()
            lifts=lifts+1
            if lift_refusal then return false,lift_refusal end
            return true,'asked the native part: loading lift'
        end,
        veil=function(on) veils[#veils+1]=on end})
end
local items={}
local function missing() return items end
local function last() return logs[#logs] end

assert(Arrival.CAP==8 and Arrival.ARM_CAP==60 and Arrival.LIFETIME==10 and Arrival.FADE==0.5)

-- No lobby warp: a new controller holds nothing.
local a=new()
a.restart()
a.pass(missing)
assert(fades==0 and not a.held() and #veils==0 and #logs==0)

-- A lobby warp, its pass before the new controller: nothing yet; ClientRestart, then the pass puts SB's black up.
a.arm()
now=now+2
a.pass(missing)
assert(fades==0 and not a.held())
now=now+0.75
a.restart()
items={'arrival'}
a.pass(missing)
assert(fades==1 and a.held() and #veils==1 and veils[1]==true)
assert(last()=='arrival: SB\'s black up 2.8 s after the lobby warp',last())
-- Held while anything is missing, under the cap.
for _=1,4 do now=now+0.25; a.pass(missing) end
items={'chairs','ui','camera'}
now=now+2
a.pass(missing)
assert(a.held() and lifts==0 and #veils==1)
-- Ready: lifted once, the veil off, one line; nothing after.
items={}
now=now+1.25
a.pass(missing)
assert(not a.held() and lifts==1 and #veils==2 and veils[2]==false)
assert(last()=='arrival: lifted after 4.2 s (ready)',last()) -- 4.25 s.
local n=#logs
now=now+1
a.pass(missing)
a.restart()
a.pass(missing)
assert(lifts==1 and fades==1 and #logs==n)

-- The cap: 8 s after the black went up, lifted whatever is missing, with what was missing.
a=new()
a.arm()
a.restart()
items={'spot','chairs'}
a.pass(missing)
now=now+7.75
a.pass(missing)
assert(a.held() and lifts==0)
now=now+0.25
a.pass(missing)
assert(not a.held() and lifts==1 and veils[#veils]==false)
assert(last()=='arrival: lifted after 8.0 s (the 8 s cap; missing: spot, chairs)',last())

-- Items that cannot be read: the cap still lifts, and says why.
a=new()
a.arm()
a.restart()
a.pass(missing)
local function broken() error('sbo: no link',0) end
now=now+3
a.pass(broken)
assert(a.held())
now=now+5
a.pass(broken)
assert(not a.held() and lifts==1 and last()=='arrival: lifted after 8.0 s (the 8 s cap; missing: sbo: no link)',last())

-- A second lobby warp under the hold (a guest following her host's hall): the black and the veil stay, nothing lifts
-- while it travels, a new black goes up at its controller and the cap counts from there.
a=new()
a.arm()
a.restart()
items={'arrival'}
a.pass(missing)
now=now+6
a.arm()
items={}
for _=1,12 do now=now+0.25; a.pass(missing) end -- 9 s since the first black, and ready-looking items: still held.
assert(a.held() and lifts==0 and fades==1)
a.restart()
items={'arrival'}
a.pass(missing)
assert(fades==2 and #veils==1 and a.held())
now=now+7.75
a.pass(missing)
assert(a.held() and lifts==0)
now=now+0.25
a.pass(missing)
assert(not a.held() and lifts==1 and #veils==2,lifts)
assert(last()=='arrival: lifted after 8.0 s (the 8 s cap; missing: arrival)',last())

-- disarm: a black up lifts at once, with why; a waiting warp is dropped (its controller then holds nothing).
a=new()
a.arm()
a.restart()
a.pass(missing)
now=now+1.5
a.disarm('coop off')
assert(not a.held() and lifts==1 and veils[#veils]==false and last()=='arrival: lifted after 1.5 s (coop off)',last())
a=new()
a.arm()
a.disarm('the warp ended: zone')
a.restart()
a.pass(missing)
assert(fades==0 and lifts==0 and #veils==0 and #logs==0)

-- A warp with no new controller: dropped at the arm cap with one line; a black kept for it (a second warp under the
-- hold) lifts then too.
a=new()
a.arm()
now=now+59.75
a.pass(missing)
assert(#logs==0)
now=now+0.25
a.pass(missing)
assert(last()=='arrival: no new world 60 s after the lobby warp: nothing held',last() and fades==0)
a.restart()
a.pass(missing)
assert(fades==0)
a=new()
a.arm()
a.restart()
a.pass(missing)
a.arm()
now=now+60
a.pass(missing)
assert(not a.held() and lifts==1 and veils[#veils]==false)
assert(logs[#logs-1]=='arrival: no new world 60 s after the lobby warp: nothing held',logs[#logs-1])
assert(last()=='arrival: lifted after 60.0 s (the lobby warp never arrived)',last())

-- A black that does not show: logged, nothing veiled or held.
a=new()
fade_error='LoadingScreenFadeAuto: no such function'
a.arm()
a.restart()
a.pass(missing)
assert(not a.held() and #veils==0 and last()=='arrival: SB\'s black not shown: LoadingScreenFadeAuto: no such function',
    last())

-- A lift the native part cannot take: the veil still goes, and the line says SB ends the black at its own time.
a=new()
a.arm()
a.restart()
a.pass(missing)
lift_refusal='coop-request.txt not written'
items={}
now=now+2
a.pass(missing)
assert(not a.held() and veils[#veils]==false)
assert(last()=='arrival: lifted after 2.0 s (ready); SB ends its black within 10 s: coop-request.txt not written',
    last())
print('online/lobby/arrival_test: ok')
