-- The challenge list without the game: the five definitions and the rules they keep (a co-op one's waves within the
-- night line's masks and bounds), the lookup by name or number, the console list line, and the best runs in
-- coop-records.txt (read, compared, rewritten).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local W=require('nightop.waves')
local C=require('nightop.challenges')

-- The five, in their numbers (none is night, Night Operation's id, a level's word, or stop).
local ids={}
for n,def in ipairs(C.LIST) do ids[n]=def.id end
assert(table.concat(ids,' ')=='swarm skulls gauntlet targets range',table.concat(ids,' '))
for _,def in ipairs(C.LIST) do assert(not W.LEVEL[def.id],def.id..' is a level word') end

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
-- 45 degrees, 15 and 20 m out in turn; the only challenge for two players, and the only one with the board.
local range=C.find('range')
assert(range.aggro==false and range.moves==0 and range.coop==true and range.board==true and #range.spots==8)
for i,spot in ipairs(range.spots) do
    assert(spot[1]==(i-1)*45-(i>5 and 360 or 0) and spot[2]==(i%2==1 and 15 or 20),'range spot '..i)
end
for _,def in ipairs(C.LIST) do assert((def.coop==true)==(def==range) and (def.board==true)==(def==range),def.id) end
-- Two spots of a wave stand more than twice nightop/run.lua's 5 m match radius apart, so a body is never taken for
-- the next spot's slot.
for i,a in ipairs(range.spots) do
    for j,b in ipairs(range.spots) do
        if i<j then
            local d=math.sqrt(a[2]^2+b[2]^2-2*a[2]*b[2]*math.cos(math.rad(a[1]-b[1])))
            assert(d>10,'range spots '..i..' and '..j..': '..d)
        end
    end
end

-- The rules the runs rely on: each wave holds 1 to W.CAP rows of W.POOL, and a definition with spots has one for each
-- body of its biggest wave, each within 40 m of EVE (nightop/run.lua's census radius). A co-op one has at most
-- #W.SCHEDULE waves, each key of which the night line's masks carry (W.mask, then W.unmask, gives it back), and its
-- best score and wave counts pass W.decode_host under its id.
for _,def in ipairs(C.LIST) do
    local most=0
    for k,wave in ipairs(def.waves) do
        assert(#wave.ids>=1 and #wave.ids<=W.CAP,def.id..': wave '..k)
        for _,row in ipairs(wave.ids) do assert(W.POOL[row],def.id..': '..row..' is not a pool row') end
        most=math.max(most,#wave.ids)
    end
    for i,spot in ipairs(def.spots or {}) do assert(spot[2]>0 and spot[2]<=40,def.id..': spot '..i) end
    assert(not def.spots or #def.spots>=most,def.id..': fewer spots than the biggest wave')
    if def.coop then
        assert(#def.waves<=#W.SCHEDULE,def.id..': more waves than the night line carries')
        local set,n={},0
        for k,wave in ipairs(def.waves) do
            for slot=0,#wave.ids-1 do set[W.key(7,k,slot)]=true; n=n+1 end
        end
        local back,m=W.unmask(W.mask(set,7),7),0
        for key in pairs(back) do assert(set[key],def.id..': a key the mask added'); m=m+1 end
        assert(m==n,def.id..': a key the mask lost')
        local line=W.encode_host({n=1,run=7,seed=9,phase='end',wave=#def.waves,rt=30000,score=W.most(def),kills=n,
            clears=#def.waves,found={},x=0,y=0,z=0,yaw=0,map='/game/x',outcome='success',level=def.id})
        local h=W.decode_host(line,{[def.id]=def})
        assert(h and h.level==def.id and h.score==W.most(def),def.id..': '..line)
    end
end

-- Lookup by id or by number; nothing for anything else.
for n,def in ipairs(C.LIST) do assert(C.find(def.id)==def and C.find(tostring(n))==def) end
for _,junk in ipairs({'','0','6','01','1.0',' 1','Targets','night','stop','target','hard',1}) do
    assert(C.find(junk)==nil,tostring(junk))
end
assert(C.find(nil)==nil)

-- The console list line: number, id, English name, waves, limit, best run or none; Night Operation's own lines.
assert(C.line(C.LIST[4],1250,37)=='4 targets Target Practice: 3 waves, 1:30, best 1250 in 0:37')
assert(C.line(C.LIST[1],314,46)=='1 swarm Antlion Swarm: 3 waves, 3:00, best 314 in 0:46')
assert(C.line(C.LIST[2])=='2 skulls Skull Squad: 3 waves, 6:00, no best yet')
assert(C.line(C.LIST[3])=='3 gauntlet Gauntlet: 8 waves, 12:00, no best yet')
assert(C.line(C.LIST[5],1590,31)=='5 range Shooting Range: 3 waves, 2:00, best 1590 in 0:31')
assert(C.line(W.NIGHT)=='night: Night Operation (coop nightop start), no best yet')
assert(C.line(W.NIGHT,659,401)=='night: Night Operation (coop nightop start), best 659 in 6:41')
-- Each other level of Night Operation under its own id, with its word in the name and the command.
assert(C.line(W.LEVEL.hard,900,300)=='night_hard: Night Operation hard (coop nightop start hard), best 900 in 5:00')
assert(C.line(W.LEVEL.easy)=='night_easy: Night Operation easy (coop nightop start easy), no best yet')
assert(C.line(W.LEVEL.nightmare)
    =='night_nightmare: Night Operation nightmare (coop nightop start nightmare), no best yet')
for _,def in ipairs(W.LEVELS) do assert(not C.find(def.id),def.id..' is no challenge') end

-- Records: best_<id>=<score> <whole seconds>, read the way the mod reads its settings (the last line naming the key).
local file='# mine\nbest_targets=1250 37\r\nbest_swarm = 314 46\nbest_skulls=12\nbest_gauntlet=a b\n'
local score,secs=C.best(file,'targets')
assert(score==1250 and secs==37)
score,secs=C.best(file,'swarm')
assert(score==314 and secs==46)
for _,id in ipairs({'skulls','gauntlet','night'}) do assert(C.best(file,id)==nil,id..': malformed or missing') end
assert(C.best(nil,'targets')==nil and C.best('','targets')==nil,'No file, no best')
assert(C.best('best_night=1 2\nbest_night=99999999999999999999 1\n','night')==nil,'A score past an integer')
assert(C.best('best_night=-5 2\n','night')==nil and C.best('best_night=5 2 3\n','night')==nil)
assert(C.best('best_night=5 2\nbest_night=7 9\n','night')==7,'The last line wins')

-- Better: a higher score; an equal score in a shorter time; anything beats no best.
assert(C.better(100,50,101,90) and not C.better(100,50,99,10))
assert(C.better(100,50,100,49) and not C.better(100,50,100,50) and not C.better(100,50,100,51))
assert(C.better(nil,nil,0,480))

-- Write: the line rewritten in place, every other line kept; a key not yet there goes at the end; a new or empty file
-- starts with its comment line.
local text=assert(C.write(file,'targets',1300,41))
assert(text==file:gsub('best_targets=1250 37','best_targets=1300 41'),text)
assert(C.best(text,'targets')==1300 and select(2,C.best(text,'targets'))==41)
text=assert(C.write(file,'night',659,401))
assert(text==file..'best_night=659 401\r\n','Added with the file\'s line end (it has a CRLF)')
text=assert(C.write('# mine\nbest_swarm=314 46\n','night',659,401))
assert(text=='# mine\nbest_swarm=314 46\nbest_night=659 401\n',text)
for _,empty in pairs({[1]=false,[2]=''}) do
    text=assert(C.write(empty or nil,'swarm',314,46))
    local first,rest=text:match('^(#[^\n]*)\n(.*)$')
    assert(first and rest=='best_swarm=314 46\n',text)
    assert(not first:find('best_'),'The comment names no key')
end
assert(C.write('# kept\n','swarm',1,2)=='# kept\nbest_swarm=1 2\n','A file with lines gets no second comment')
-- A run's time is a float (now minus the start): written and shown in whole seconds, never a Lua error.
assert(C.write('# kept\n','swarm',314,46.9)=='# kept\nbest_swarm=314 46\n')
assert(C.write('# kept\n','swarm',314.0,46.0)=='# kept\nbest_swarm=314 46\n')
assert(C.line(C.LIST[1],314,46.9)=='1 swarm Antlion Swarm: 3 waves, 3:00, best 314 in 0:46')

print('challenges_test: ok')
