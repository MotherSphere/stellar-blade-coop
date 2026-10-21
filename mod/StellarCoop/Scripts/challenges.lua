-- coop challenge's list without a game call: the definitions nightop_waves.lua runs (the fields are listed above
-- W.NIGHT there), their check, the lookup by id or number, the console list line, and each one's best run in
-- coop-records.txt, one line best_<id>=<score> <whole seconds> read and rewritten through settings_file.lua. Starting
-- values, to tune after the first in-game runs. tests/challenges_test.lua covers it with lua5.4 alone.
local W=require('nightop_waves')
local F=require('settings_file')
local C={}
local function many(id,n,out)
    out=out or {}
    for _=1,n do out[#out+1]=id end
    return out
end
local ANTLION,LURKER,BOAR=50110,50450,50440
local SWORD,SPEAR,GUNNER,HAMMER=50173,50183,50193,50161
local A,B,DC=40010,40020,40030 -- The target dummies.
-- name: English, for the console only (ui_text.lua holds the player's words).
C.LIST={
    {id='swarm',name='Antlion Swarm',limit=180,breather=5,heals={},bonus=1,aggro=true,moves=2,waves={
        {at=0,ids=many(ANTLION,4)},{ids=many(ANTLION,6)},{ids=many(ANTLION,8)}}},
    {id='skulls',name='Skull Squad',limit=360,breather=5,heals={[2]=true},bonus=1,aggro=true,moves=2,waves={
        {at=0,ids={SWORD,GUNNER,GUNNER}},{ids={SPEAR,SPEAR,GUNNER}},{ids={HAMMER,SWORD,SPEAR}}}},
    {id='gauntlet',name='Gauntlet',limit=720,breather=5,heals={[3]=true,[6]=true},bonus=1,aggro=true,moves=2,waves={
        {at=0,ids=many(ANTLION,4)},{ids=many(LURKER,3)},{ids={SWORD,SWORD,GUNNER}},{ids=many(BOAR,3)},
        {ids={SPEAR,SPEAR,GUNNER,GUNNER}},{ids=many(BOAR,3,many(LURKER,3))},{ids={HAMMER,SWORD,GUNNER}},
        {ids={HAMMER,SPEAR,SWORD,GUNNER}}}},
    -- Dummies stand still 12 to 32 m in front of EVE: no aggro, and one that falls is written off where it lies.
    {id='targets',name='Target Practice',limit=90,breather=3,heals={},bonus=10,aggro=false,moves=0,waves={
        {at=0,ids={A,A,B,B}},{ids={A,A,B,B,DC,DC}},{ids={A,A,A,B,B,B,DC,DC}}},
        spots={{-45,12},{45,12},{-25,18},{25,18},{0,22},{-40,26},{40,26},{0,32}}},
}
local REACH=40 -- Metres: the start's census radius and the stuck rule's distance.
-- true, or nil and why.
function C.check(def)
    local id=def.id
    if type(id)~='string' or not id:find('^%l+$') or id=='stop' then return nil,'id: '..tostring(id) end
    for _,other in ipairs({W.NIGHT,table.unpack(C.LIST)}) do
        if other~=def and other.id==id then return nil,id..': id used twice' end
    end
    local waves=def.waves
    if #waves<1 or #waves>255 then return nil,id..': 1 to 255 waves' end
    if waves[1].at~=0 then return nil,id..': wave 1 at 0' end
    local most=0
    for k,wave in ipairs(waves) do
        if #wave.ids<1 or #wave.ids>W.CAP then return nil,id..': wave '..k..' has 1 to '..W.CAP..' IDs' end
        for _,row in ipairs(wave.ids) do
            if not W.POOL[row] then return nil,id..': '..tostring(row)..' is not a pool row' end
        end
        most=math.max(most,#wave.ids)
    end
    for _,field in ipairs({'limit','breather','bonus'}) do
        if not (type(def[field])=='number' and def[field]>0) then return nil,id..': '..field..' not above 0' end
    end
    if math.type(def.moves)~='integer' or def.moves<0 then return nil,id..': moves' end
    if def.spots then
        if #def.spots<most then return nil,id..': fewer spots than the biggest wave' end
        for i,spot in ipairs(def.spots) do
            if not (spot[2]>0 and spot[2]<=REACH) then return nil,id..': spot '..i..' not within '..REACH..' m' end
        end
    end
    return true
end
-- A definition by id or number ('1' to '4'); nil for any other word.
function C.find(word)
    if type(word)~='string' then return nil end
    if word:find('^%d$') then return C.LIST[tonumber(word)] end
    for _,def in ipairs(C.LIST) do if def.id==word then return def end end
end
local function clock(s) return string.format('%d:%02d',s//60,s%60) end
-- The console list line of a definition and its best run (score and seconds, or nil).
function C.line(def,score,s)
    local best=score and string.format('best %d in %s',score,clock(s)) or 'no best yet'
    if def==W.NIGHT then return 'night: Night Operation (coop nightop start), '..best end
    for n,d in ipairs(C.LIST) do
        if d==def then return string.format('%d %s %s: %d waves, %s, %s',n,d.id,d.name,#d.waves,clock(d.limit),best) end
    end
end
-- The best run of id in the records file's text (nil when there is none): score and whole seconds, or nil for a missing
-- or malformed value.
function C.best(text,id)
    local value=text and F.get(text,'best_'..id)
    local score,s=(value or ''):match('^(%d+) (%d+)$')
    score,s=math.tointeger(tonumber(score or '')),math.tointeger(tonumber(s or ''))
    if score and s then return score,s end
end
-- A run of score in s seconds beats the stored best (old_score nil: none): a higher score, or the same in less time.
function C.better(old_score,old_s,score,s)
    return old_score==nil or score>old_score or score==old_score and s<old_s
end
-- The records file's text with id's best set, or nil and why. A new or empty file starts with a line saying what it is.
function C.write(text,id,score,s)
    if not text or text=='' then text='# StellarCoop: your best challenge runs on this PC (score and seconds).\n' end
    return F.set(text,'best_'..id,string.format('%d %d',score,s))
end
return C
