-- coop challenge's list without a game call: the definitions nightop/waves.lua runs (the fields are listed above
-- W.NIGHT there), the lookup by id or number, the console list line, and each one's best run, Night Operation's levels'
-- too, in coop-records.txt, one line best_<id>=<score> <whole seconds> read and rewritten through
-- core/settings_file.lua. Starting values, to tune after the first in-game runs. A definition with coop=true also runs
-- for two linked players, the host's run carried by the night line under its id (W.decode_host's words); its waves stay
-- within the night line's masks (5 waves of 8 at most). tests/lua/nightop/challenges_test.lua covers it with lua5.4
-- alone, the definitions' rules included.
local W=require('nightop.waves')
local F=require('core.settings_file')
local C={}
local function many(id,n,out)
    out=out or {}
    for _=1,n do out[#out+1]=id end
    return out
end
local ANTLION,LURKER,BOAR=50110,50450,50440
local SWORD,SPEAR,GUNNER,HAMMER=50173,50183,50193,50161
local A,B,DC=40010,40020,40030 -- The target dummies.
-- name: English, for the console only (ui/text.lua holds the player's words).
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
    -- The cut shooting test (LV_Test_Shooting_01, no map in the pak): its zone stood 12 M_DummyA, and its quest asked
    -- for three rounds of kills, 3, 4 and 5. Here they stand all around EVE, 15 or 20 m out, for one player or two.
    {id='range',name='Shooting Range',limit=120,breather=3,heals={},bonus=10,aggro=false,moves=0,coop=true,
        waves={{at=0,ids=many(A,3)},{ids=many(A,4)},{ids=many(A,5)}},
        spots={{0,15},{45,20},{90,15},{135,20},{180,15},{-135,20},{-90,15},{-45,20}}},
}
-- A definition by id or number ('1' to '5'); nil for any other word.
function C.find(word)
    if type(word)~='string' then return nil end
    if word:find('^%d$') then return C.LIST[tonumber(word)] end
    for _,def in ipairs(C.LIST) do if def.id==word then return def end end
end
-- m:ss from seconds, a run's float time cut to whole seconds.
local function clock(s) s=math.floor(s) return string.format('%d:%02d',s//60,s%60) end
-- The console list line of a definition, a challenge or a level of Night Operation (W.LEVELS), and its best run (score
-- and seconds, or nil).
function C.line(def,score,s)
    local best=score and string.format('best %d in %s',score,clock(s)) or 'no best yet'
    if def.level then
        local word=def==W.NIGHT and '' or ' '..def.level
        return string.format('%s: Night Operation%s (coop nightop start%s), %s',def.id,word,word,best)
    end
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
-- Score and seconds are cut to whole numbers, so a run's float time is stored the way C.best reads it back.
function C.write(text,id,score,s)
    if not text or text=='' then text='# StellarCoop: your best challenge runs on this PC (score and seconds).\n' end
    return F.set(text,'best_'..id,string.format('%d %d',math.floor(score),math.floor(s)))
end
return C
