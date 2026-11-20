-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The score attack's copy of tests/lua/online/modes/nightop/challenges_test.lua (2026-11-20), for its copy of the
-- challenge list in online/modes/scoreattack/challenges.lua: the five definitions and the rules they keep, the lookup
-- by name or number, the console list line, and the best match runs in coop-records.txt (read, compared, rewritten)
-- under their own keys, beside the solo bests. Dropped with the copy's code: Night Operation's levels, the co-op run
-- and the board.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local W=require('online.modes.scoreattack.waves')
local C=require('online.modes.scoreattack.challenges')

-- The five, in their numbers.
local ids={}
for n,def in ipairs(C.LIST) do ids[n]=def.id end
assert(table.concat(ids,' ')=='swarm skulls gauntlet targets range',table.concat(ids,' '))

-- Their values: waves (IDs a wave), limit, breather, heals, bonus, aggro and moves.
local function shape(def)
    local waves,heals={},{}
    for k,wave in ipairs(def.waves) do
        waves[k]=table.concat(wave.ids,',')
        assert((k==1)==(wave.at~=nil),def.id..': only wave 1 has a run time')
    end
    for k in pairs(def.heals) do heals[#heals+1]=k end
    table.sort(heals)
    return table.concat(waves,' / ')..' | '..def.limit..' '..def.breather..' ['..table.concat(heals,',')..'] '
        ..def.bonus..' '..tostring(def.aggro)..' '..def.moves
end
local want={
    swarm='50110,50110,50110,50110 / 50110,50110,50110,50110,50110,50110 / '
        ..'50110,50110,50110,50110,50110,50110,50110,50110 | 180 5 [] 1 true 2',
    skulls='50173,50193,50193 / 50183,50183,50193 / 50161,50173,50183 | 360 5 [2] 1 true 2',
    gauntlet='50110,50110,50110,50110 / 50450,50450,50450 / 50173,50173,50193 / 50440,50440,50440 / '
        ..'50183,50183,50193,50193 / 50450,50450,50450,50440,50440,50440 / 50161,50173,50193 / '
        ..'50161,50183,50173,50193 | 720 5 [3,6] 1 true 2',
    targets='40010,40010,40020,40020 / 40010,40010,40020,40020,40030,40030 / '
        ..'40010,40010,40010,40020,40020,40020,40030,40030 | 90 3 [] 10 false 0',
    range='40010,40010,40010 / 40010,40010,40010,40010 / 40010,40010,40010,40010,40010 | 120 3 [] 10 false 0',
}
for _,def in ipairs(C.LIST) do assert(shape(def)==want[def.id],def.id..': '..shape(def)) end
-- The highest scores: every kill and the bonus of a run that ends at run time 0.
local most={swarm=360,skulls=680,gauntlet=1620,targets=1620,range=1680}
for _,def in ipairs(C.LIST) do assert(W.most(def)==most[def.id],def.id..': '..W.most(def)) end
-- Target practice stands its dummies on eight spots 12 to 32 m out; the others use the gates.
local targets=C.find('targets')
assert(targets.aggro==false and targets.moves==0 and #targets.spots==8)
assert(table.concat((function()
    local out={}
    for i,spot in ipairs(targets.spots) do out[i]=spot[1]..':'..spot[2] end
    return out
end)(),' ')=='-45:12 45:12 -25:18 25:18 0:22 -40:26 40:26 0:32')
for _,id in ipairs({'swarm','skulls','gauntlet'}) do assert(C.find(id).spots==nil and C.find(id).aggro==true) end
-- The Shooting Range: M_DummyA in the cut shooting test's three rounds (3, 4, 5), on eight spots all around EVE, every
-- 45 degrees, 15 and 20 m out in turn. No definition here runs for two, none shows the cut test's board.
local range=C.find('range')
assert(range.aggro==false and range.moves==0 and #range.spots==8)
for i,spot in ipairs(range.spots) do
    assert(spot[1]==(i-1)*45-(i>5 and 360 or 0) and spot[2]==(i%2==1 and 15 or 20),'range spot '..i)
end
for _,def in ipairs(C.LIST) do assert(def.coop==nil and def.board==nil,def.id) end
-- Two spots of a wave stand more than twice the solo run's 5 m match radius apart, so a body is never taken for the
-- next spot's slot.
for i,a in ipairs(range.spots) do
    for j,b in ipairs(range.spots) do
        if i<j then
            local d=math.sqrt(a[2]^2+b[2]^2-2*a[2]*b[2]*math.cos(math.rad(a[1]-b[1])))
            assert(d>10,'range spots '..i..' and '..j..': '..d)
        end
    end
end

-- The rules the runs rely on: each wave holds 1 to W.CAP rows of W.POOL, and a definition with spots has one for each
-- body of its biggest wave, each within 40 m of EVE (the solo run's census radius).
for _,def in ipairs(C.LIST) do
    local biggest=0
    for k,wave in ipairs(def.waves) do
        assert(#wave.ids>=1 and #wave.ids<=W.CAP,def.id..': wave '..k)
        for _,row in ipairs(wave.ids) do assert(W.POOL[row],def.id..': '..row..' is not a pool row') end
        biggest=math.max(biggest,#wave.ids)
    end
    for i,spot in ipairs(def.spots or {}) do assert(spot[2]>0 and spot[2]<=40,def.id..': spot '..i) end
    assert(not def.spots or #def.spots>=biggest,def.id..': fewer spots than the biggest wave')
end

-- Lookup by id or by number; nothing for anything else.
for n,def in ipairs(C.LIST) do assert(C.find(def.id)==def and C.find(tostring(n))==def) end
for _,junk in ipairs({'','0','6','01','1.0',' 1','Targets','night','stop','target','hard','random',1}) do
    assert(C.find(junk)==nil,tostring(junk))
end
assert(C.find(nil)==nil)

-- The console list line: number, id, English name, waves, limit, best match run or none; nothing for another table.
assert(C.line(C.LIST[4],1250,37)=='4 targets Target Practice: 3 waves, 1:30, best 1250 in 0:37')
assert(C.line(C.LIST[1],314,46)=='1 swarm Antlion Swarm: 3 waves, 3:00, best 314 in 0:46')
assert(C.line(C.LIST[2])=='2 skulls Skull Squad: 3 waves, 6:00, no best yet')
assert(C.line(C.LIST[3])=='3 gauntlet Gauntlet: 8 waves, 12:00, no best yet')
assert(C.line(C.LIST[5],1590,31)=='5 range Shooting Range: 3 waves, 2:00, best 1590 in 0:31')
assert(C.line({id='night'})==nil)

-- Records: best_match_<id>=<score> <whole seconds>, read the way the mod reads its settings (the last line naming the
-- key). A solo best_<id> is no match best. A match best is no solo best either.
local file='# mine\nbest_match_targets=1250 37\r\nbest_match_swarm = 314 46\nbest_match_skulls=12\n'
    ..'best_match_gauntlet=a b\nbest_range=1590 31\n'
local score,secs=C.best(file,'targets')
assert(score==1250 and secs==37)
score,secs=C.best(file,'swarm')
assert(score==314 and secs==46)
for _,id in ipairs({'skulls','gauntlet','range'}) do assert(C.best(file,id)==nil,id..': malformed or missing') end
assert(C.best(nil,'targets')==nil and C.best('','targets')==nil,'No file, no best')
assert(C.best('best_match_swarm=1 2\nbest_match_swarm=99999999999999999999 1\n','swarm')==nil,'A score past an integer')
assert(C.best('best_match_swarm=-5 2\n','swarm')==nil and C.best('best_match_swarm=5 2 3\n','swarm')==nil)
assert(C.best('best_match_swarm=5 2\nbest_match_swarm=7 9\n','swarm')==7,'The last line wins')

-- Better: a higher score; an equal score in a shorter time; anything beats no best.
assert(C.better(100,50,101,90) and not C.better(100,50,99,10))
assert(C.better(100,50,100,49) and not C.better(100,50,100,50) and not C.better(100,50,100,51))
assert(C.better(nil,nil,0,480))

-- Write: the line rewritten in place, every other line kept (the solo best too); a key not yet there goes at the end;
-- a new or empty file starts with its comment line.
local text=assert(C.write(file,'targets',1300,41))
assert(text==file:gsub('best_match_targets=1250 37','best_match_targets=1300 41'),text)
assert(C.best(text,'targets')==1300 and select(2,C.best(text,'targets'))==41)
text=assert(C.write(file,'range',1600,30))
assert(text==file..'best_match_range=1600 30\r\n','Added with the file\'s line end (it has a CRLF)')
assert(text:find('\nbest_range=1590 31\n',1,true),'The solo best stays')
text=assert(C.write('# mine\nbest_swarm=314 46\n','swarm',200,90))
assert(text=='# mine\nbest_swarm=314 46\nbest_match_swarm=200 90\n',text)
for _,empty in pairs({[1]=false,[2]=''}) do
    text=assert(C.write(empty or nil,'swarm',314,46))
    local first,rest=text:match('^(#[^\n]*)\n(.*)$')
    assert(first and rest=='best_match_swarm=314 46\n',text)
    assert(not first:find('best_'),'The comment names no key')
end
assert(C.write('# kept\n','swarm',1,2)=='# kept\nbest_match_swarm=1 2\n','A file with lines gets no second comment')
-- A run's time is a float (now minus the start): written and shown in whole seconds, never a Lua error.
assert(C.write('# kept\n','swarm',314,46.9)=='# kept\nbest_match_swarm=314 46\n')
assert(C.write('# kept\n','swarm',314.0,46.0)=='# kept\nbest_match_swarm=314 46\n')
assert(C.line(C.LIST[1],314,46.9)=='1 swarm Antlion Swarm: 3 waves, 3:00, best 314 in 0:46')

print('scoreattack_challenges_test: ok')
