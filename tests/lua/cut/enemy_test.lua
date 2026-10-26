-- cut/enemy.lua's parts that need no world (lion_test and gardener_test run its flow through both specs): its 15 tables
-- are link/protocol.h's kLionTables in order, a batch's line parses by its word only (from the start of its own line,
-- each of its forms), the generated rows take their named form, the counts a batch's line gives once its rows are in,
-- and an error's text loses its file and line.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
package.loaded.UEHelpers={} -- nightop/probe.lua's, for EVE and her controller: never called here.
local Enemy=require('cut.enemy')

do
    local f=assert(io.open('native/src/link/protocol.h'))
    local src=f:read('a')
    f:close()
    local list=assert(src:match('constexpr const char %*kLionTables%[kLionTableCount%] = {(.-)};'))
    local n=0
    for t in list:gmatch('"(%a+)"') do
        n=n+1
        assert(Enemy.TABLES[n]==t,'kLionTables order: '..t)
    end
    assert(n==15 and #Enemy.TABLES==15)
    assert(src:find('kRowWords%[kRowWordCount%] = {"lion", "gardener", "tendril", "bolt"}'),
        'The words, the batches\' order')
end

local status='mod=v\npeer=1 name=gardener=rows added=13/13\n'
    ..'lion=rows added=237/237 asks=3 spawns=7 char=2/2 skills=23/23 stance=2/2\n'
    ..'gardener=waiting added=0/13 asks=0 spawns=7 why=net ticks=12\r\n'
local lion,gardener=Enemy.parse(status,'lion'),Enemy.parse(status,'gardener')
assert(lion.state=='rows' and lion.asks==3 and lion.spawns==7 and lion.char=='2/2' and lion.line:find('^lion=rows'))
assert(gardener.state=='waiting' and gardener.asks==0 and gardener.why=='net' and gardener.ticks=='12'
    and gardener.line=='gardener=waiting added=0/13 asks=0 spawns=7 why=net ticks=12','Its own line, not the peer name')
assert(Enemy.parse('lion=off\n','gardener')==nil and Enemy.parse(nil,'lion')==nil)
local fault=Enemy.parse('gardener=fault added=2/13 asks=1 spawns=? where=SB.exe+0x10 (a read)\n','gardener')
assert(fault.state=='fault' and fault.spawns==nil and fault.where=='SB.exe+0x10 (a read)')
local refused=Enemy.parse('gardener=refused added=12/13 asks=2 spawns=6 why=id table=CharacterTable row=M_Gardener',
    'gardener')
assert(refused.why=='id' and refused.table=='CharacterTable' and refused.row=='M_Gardener' and refused.added=='12/13')

local rows=Enemy.rows({{'SkillTable','S',1,{{'AISkillFlag','n','MeleeAttack',true}}},{'CharacterDeadTable','D',nil,{}},
    {'CharacterTable','C',2,{}},{'CharacterStanceTable','T',3,{}}})
assert(rows[1].table=='SkillTable' and rows[1].name=='S' and rows[1].id==1 and rows[1].checks[1][3]=='MeleeAttack')
assert(rows[2].id==nil)
local IN=Enemy.counts(rows)
assert(IN.added=='4/4' and IN.char=='1/1' and IN.skills=='1/1' and IN.stance=='1/1')
assert(Enemy.why('Scripts/cut/enemy.lua:12: no EVE in the world')=='no EVE in the world' and Enemy.why('plain')=='plain')
print('enemy_test: ok')
