-- The challenge list without the game: the four definitions and their check, the lookup by name or number, the
-- console list line, and the best runs in coop-records.txt (read, compared, rewritten).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local W=require('nightop_waves')
local C=require('challenges')

-- The four, in their numbers, each valid; Night Operation's definition passes the same check.
local ids={}
for n,def in ipairs(C.LIST) do ids[n]=def.id end
assert(table.concat(ids,' ')=='swarm skulls gauntlet targets',table.concat(ids,' '))
for _,def in ipairs(C.LIST) do
    local ok,why=C.check(def)
    assert(ok,def.id..': '..tostring(why))
end
assert(C.check(W.NIGHT))

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

-- The check: each rule refuses a definition that breaks it.
local function copy(t)
    if type(t)~='table' then return t end
    local out={}
    for k,v in pairs(t) do out[k]=copy(v) end
    return out
end
local function bad(change)
    local def=copy(targets)
    def.id='mine'
    change(def)
    local ok,why=C.check(def)
    assert(not ok and type(why)=='string')
    return why
end
assert(C.check((function() local d=copy(targets) d.id='mine' return d end)()),'A copy under a new id passes')
assert(not C.check(copy(targets)),'A copy under a listed id: two definitions, one id')
-- Each bad definition is refused for its own reason (the text C.check gives, found as plain text).
for what,case in pairs({
    ['night id']={function(d) d.id='night' end,'night: id used twice'},
    ['stop id']={function(d) d.id='stop' end,'id: stop'},
    ['blank id']={function(d) d.id='' end,'id: '},
    ['id with a space']={function(d) d.id='my run' end,'id: my run'},
    ['no waves']={function(d) d.waves={} end,'mine: 1 to 255 waves'},
    ['256 waves']={function(d) for _=4,256 do d.waves[#d.waves+1]={ids={40010}} end end,'mine: 1 to 255 waves'},
    ['not a pool row']={function(d) d.waves[1].ids[1]=50160 end,'mine: 50160 is not a pool row'},
    ['an empty wave']={function(d) d.waves[2].ids={} end,'mine: wave 2 has 1 to'},
    ['nine in a wave']={function(d) d.spots=nil for _=1,5 do table.insert(d.waves[1].ids,40010) end end,
        'mine: wave 1 has 1 to'},
    ['wave 1 not at 0']={function(d) d.waves[1].at=5 end,'mine: wave 1 at 0'},
    ['wave 1 with no time']={function(d) d.waves[1].at=nil end,'mine: wave 1 at 0'},
    ['limit 0']={function(d) d.limit=0 end,'mine: limit not above 0'},
    ['breather 0']={function(d) d.breather=0 end,'mine: breather not above 0'},
    ['bonus 0']={function(d) d.bonus=0 end,'mine: bonus not above 0'},
    ['negative moves']={function(d) d.moves=-1 end,'mine: moves'},
    ['fractional moves']={function(d) d.moves=1.5 end,'mine: moves'},
    ['fewer spots than a wave']={function(d) table.remove(d.spots) end,'mine: fewer spots than the biggest wave'},
    ['a spot past 40 m']={function(d) d.spots[8][2]=41 end,'mine: spot 8 not within 40 m'},
}) do
    local why=bad(case[1])
    assert(why:find(case[2],1,true)==1,what..': '..why)
end

-- Lookup by id or by number; nothing for anything else.
for n,def in ipairs(C.LIST) do assert(C.find(def.id)==def and C.find(tostring(n))==def) end
for _,junk in ipairs({'','0','5','01','1.0',' 1','Targets','night','stop','target',1}) do
    assert(C.find(junk)==nil,tostring(junk))
end
assert(C.find(nil)==nil)

-- The console list line: number, id, English name, waves, limit, best run or none; Night Operation's own line.
assert(C.line(C.LIST[4],1250,37)=='4 targets Target Practice: 3 waves, 1:30, best 1250 in 0:37')
assert(C.line(C.LIST[1],314,46)=='1 swarm Antlion Swarm: 3 waves, 3:00, best 314 in 0:46')
assert(C.line(C.LIST[2])=='2 skulls Skull Squad: 3 waves, 6:00, no best yet')
assert(C.line(C.LIST[3])=='3 gauntlet Gauntlet: 8 waves, 12:00, no best yet')
assert(C.line(W.NIGHT)=='night: Night Operation (coop nightop start), no best yet')
assert(C.line(W.NIGHT,659,401)=='night: Night Operation (coop nightop start), best 659 in 6:41')

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
