-- Lily's signal (story/lily.lua, story/lily_text.lua) over fakes: the status text (slot, signal=, lily=, signalquest=
-- lines as the native part writes them), the 25 tables with the signal rows as the native part writes them (FName
-- fields by comparison index, the groups' TaskContainerArray as an array of structs each holding a TaskAliasArray of
-- FNames, FText fields), the language library, a text library whose PolyglotDataToText raises as UE4SS does on a
-- Lua-table map, EVE's world, the select widget through the widget library's lookup (SelectIndex -1 until a pick, its
-- DataArray lines' DisplayText), the test pak's files and coop mxiii's travel.
-- Covered: its 7 rows against rows.h's kSignalRecipe and kSignalPatches (names, templates, IDs, each patched field's
-- kind and value, no field more, the quest row last of its rows and the choice row patched in place last); the words
-- in English and French (every line, French for any French culture, English for the others); nothing off a co-op save;
-- the title's batch with no test pak; the words written once the rows read back (no PolyglotDataToText call), a row
-- that is not the one known stopping them and her choice for the Lua load; the rows asked once in game when they are
-- not in; lily on only while every gate holds (co-op save, quest unit read, neither our quest nor Quest_Epic_12, rows
-- in, words written, solo, the test pak), off when one fails, asked again while the native part reads otherwise, a load
-- changing nothing; a pick only of our label on a SelectIndex turning from -1 (her End Conversation, or a widget first
-- seen on a line, do nothing), then after her goodbye signal acquire, and the travel once the quest is held; a refused
-- acquire with no travel; the fallback's signal complete once a visit to Matrix XIII at M01 after 10 s; coop lily
-- signal status, quest (refused with no test pak), travel and no word; coop off.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=100
os.clock=function() return clock end
EFindName={FNAME_Find=0,FNAME_Add=1}
local known,last_index={None=0},0
FName=function(text,find)
    if known[text]==nil then
        if find==EFindName.FNAME_Find then text='None' else last_index=last_index+7; known[text]=last_index end
    end
    local index=known[text]
    return {type=function() return 'FName' end,GetComparisonIndex=function() return index end,
        ToString=function() return text end}
end
local function text_of(s) return {type=function() return 'FText' end,ToString=function() return s end} end
FText=function(s) return text_of(s) end
local next_address=0x70000
local function object(t)
    next_address=next_address+0x100
    local at=next_address
    t.type=t.type or function() return 'UObject' end
    t.IsValid=t.IsValid or function() return true end
    t.GetAddress=t.GetAddress or function() return at end
    t.GetFullName=t.GetFullName or function() return 'Object /Engine/Transient.X' end
    return t
end
package.loaded.UEHelpers={}
local her=nil -- EVE (nil: none), set below.
package.loaded['nightop.probe']={her=function() return her end}
local Lily=require('story.lily')
local T=require('story.lily_text')
local Enemy=require('cut.enemy')

-- The rows against rows.h's hand-written batch.
do
    local f=assert(io.open('native/src/lion/rows.h'))
    local src=f:read('a')
    f:close()
    local patches={}
    for at,kind,value,text,field in assert(src:match('constexpr Patch kSignalPatches%[%] = {\n(.-)\n};'))
        :gmatch('{(0x%x+), Kind::(%w+), ([%d%.%-]+),%s*([^}]-)},%s*// (%w+)') do
        patches[#patches+1]={at=tonumber(at),kind=kind,f=tonumber(value),text=text:match('^"(.*)"$'),field=field}
    end
    local TABLES={quest='QuestTable',group='QuestTaskGroupTable',task='QuestTaskTable',target='LevelTargetFilter',
        select='TheaterSelectDataTable'}
    local KINDS={name='n',names='N',containers='C',u8='e',i32='i'}
    local n=0
    for t,name,donor,id,first,count in assert(src:match('constexpr Row kSignalRecipe%[%] = {\n(.-)\n};'))
        :gmatch('{Table::(%a+), "([%w_]+)", "([%w_]+)", (%d+)u?,%s*(%d+),%s*(%d+)}') do
        n=n+1
        local r=assert(Lily.ROWS[n],'Lua lacks '..name)
        assert(r.table==TABLES[t] and r.name==name and (r.id or 0)==tonumber(id) and (donor==name)==(t=='select'),name)
        assert(#r.checks==tonumber(count),name..': '..#r.checks..' checks, '..count..' patches')
        for p=tonumber(first)+1,tonumber(first)+tonumber(count) do
            local pt,found=patches[p],nil
            for _,c in ipairs(r.checks) do if c[1]==pt.field then found=c end end
            assert(found and found[2]==KINDS[pt.kind],name..' lacks '..pt.field)
            if pt.text then assert(found[3]==pt.text,name..' '..pt.field)
            else assert(found[3]==pt.f,name..' '..pt.field) end
        end
    end
    assert(n==7 and #Lily.ROWS==7 and #patches==19,n..' rows, '..#patches..' patches')
    assert(Lily.ROWS[6].name==Lily.QUEST and Lily.ROWS[6].id==Lily.ID and Lily.ROWS[7].id==nil)
end
-- The words: every line in English and French; French for any French culture, English for the rest.
for _,c in ipairs({'en','fr'}) do
    for _,k in ipairs({'L','T','D','M1','K1','M2'}) do
        assert(type(T.TEXT[c][k])=='string' and T.TEXT[c][k]~='',c..k)
    end
end
assert(T.TEXT.en.T=='On Time' and T.TEXT.fr.T=="À l'heure" and T.TEXT.en.L=='The other signal')
assert(T.culture('fr-FR')=='fr' and T.culture('fr')=='fr' and T.culture('de-DE')=='en' and T.culture(nil)=='en'
    and T.culture('ja')=='en')
assert(T.TEXT.en.D:find('"This lift stays in service so that those who left can come home."',1,true))

-- The tables, each row as the native part writes it: FNames, arrays of FNames, the containers, numbers.
local function fresh(t)
    local rows={}
    for _,r in ipairs(Lily.ROWS) do
        if r.table==t then
            local x={ID=r.id or 86}
            for _,c in ipairs(r.checks) do
                local v=c[3]
                if c[2]=='n' then v=FName(v)
                elseif c[2]=='N' then
                    v={}
                    for item in (c[3]..'|'):gmatch('([^|]*)|') do v[#v+1]=FName(item) end
                elseif c[2]=='C' then
                    v={}
                    for group in (c[3]..';'):gmatch('([^;]*);') do
                        local names={}
                        for item in (group..'|'):gmatch('([^|]*)|') do names[#names+1]=FName(item) end
                        v[#v+1]={TaskAliasArray=names}
                    end
                end
                x[c[1]]=v
            end
            x.TitleName_,x.Description_,x.DisplayText=text_of('[임시] 빛을 찾아서'),text_of('카야는'),text_of('종료 선택지')
            rows[r.name]=x
        end
    end
    return rows
end
local tables={}
for _,t in ipairs(Enemy.TABLES) do
    tables[t]=object({rows=fresh(t),IsA=function(_,c) return c.path=='/Script/Engine.DataTable' end,
        FindRow=function(self,name) return self.rows[name] end})
end
local function build_tables() for _,t in ipairs(Enemy.TABLES) do tables[t].rows=fresh(t) end end -- As shipped again.
local classes={}
local function class(path) classes[path]=classes[path] or object({path=path}); return classes[path] end
local culture='fr-FR'
local polyglots=0
-- The select widget: its SelectIndex and its lines' texts.
local widget=object({SelectIndex=-1,DataArray={}})
local function lines_of(...)
    local list={}
    for _,s in ipairs({...}) do list[#list+1]={DisplayText=text_of(s)} end
    widget.DataArray=list
end
local lookups=0
local shown={widget}
local objects={
    ['/Script/Engine.Default__KismetTextLibrary']=object({PolyglotDataToText=function()
        polyglots=polyglots+1
        error('[push_strproperty] Error: StrProperty can only be set to a string or FString',0)
    end}),
    ['/Script/Engine.Default__KismetInternationalizationLibrary']=object({GetCurrentLanguage=function()
        return culture or error('no language',0) end}),
    ['/Script/UMG.Default__WidgetBlueprintLibrary']=object({GetAllWidgetsOfClass=function(_,ctx,out,cls,top)
        lookups=lookups+1
        assert(ctx and cls and top==false)
        for k,w in ipairs(shown) do out[k]=w end
    end}),
    ['/Script/Engine.Default__GameplayStatics']=object({GetWorldDeltaSeconds=function() return 0.02 end}),
}
StaticFindObject=function(path)
    if objects[path] then return objects[path] end
    local t=path:match('^/Game/Local/Data/(%a+)%.%a+$')
    if t then return tables[t] end
    if path:find('^/Script/') then return class(path) end
end
FindAllOf=function(name) error('FindAllOf '..name..' walks every object') end
local XION='World /Game/Art/BG/WorldMap/Level_P/E04.E04'
local MXIII='World /Game/Art/BG/WorldMap_DLC_01/Level_P/MXIII_P.MXIII_P'
local world=XION
local eve=object({GetWorld=function() return {GetFullName=function() return world end} end})
her=eve
-- The test pak's files, as cut/mxiii.lua reads them.
local PAKS='C:\\G\\SB\\Content\\Paks'
local LOGIC=PAKS..'\\LogicMods\\zMXIII_P.utoc'
local files={}
local function pak_in()
    files[LOGIC]='-==--==--==--==-\0SB\0Content\0WorldMap_DLC_01\0Level_P\0MXIII_P.umap\0'
    files[LOGIC:sub(1,-6)..'.pak'],files[LOGIC:sub(1,-6)..'.ucas']='',('\0'):rep(16)..'\13DLC02_10_EnvS'
end
local function read(path,limit) return files[path] and files[path]:sub(1,limit) end

local logs,asked,travels={},{},0
local mode,paused='none',false
local travel_answer={true,'coop mxiii: the rows are in and the travel to DLC02_10_Camp_01 is asked'}
local lines={slot='slot=coop index=4',signal='signal=off',lily='lily=unread asks=0 want=off why=none',
    quest='signalquest=none state=-1 group=-1 task=-1 epic12=0 asks=0 want=acquire why=none'}
local function status_text()
    return 'mod=v\n'..lines.slot..'\n'..lines.signal..'\n'..lines.lily..'\n'..(lines.quest or '')..'\nlast=x\n'
end
local function new()
    return Lily.new({log=function(m) logs[#logs+1]=m end,status=status_text,
        ask=function(line) asked[#asked+1]=line; return true,'asked the native part: '..line end,
        mode=function() return mode end,paused=function() return paused end,
        travel=function() travels=travels+1; return table.unpack(travel_answer) end,paks=PAKS,read=read})
end
local function last() return logs[#logs] end
local function logged(text) for _,l in ipairs(logs) do if l:find(text,1,true) then return l end end end
local function count(line) local n=0; for _,a in ipairs(asked) do if a==line then n=n+1 end end; return n end
local ROWS_IN='signal=rows added=7/7 asks=%d spawns=? char=0/0 skills=0/0 stance=0/0'
local function label(name) return tables.TheaterSelectDataTable.rows[name].DisplayText:ToString() end

-- Off a co-op save: nothing asked, nothing written.
local ly=new()
lines.slot='slot=main index=0'
her=nil
ly.tick()
lines.slot='slot=coop index=4'
ly.tick() -- No EVE: no rows asked in game.
assert(#asked==0,'Nothing off a co-op save or with no EVE')
-- The title's batch: the co-op save files, no test pak needed: the rows asked with their 5 addresses, then read back.
lines.slot='slot=none index=4'
ly.title(true,false)
assert(#asked==0,'Not on your own saves')
ly.title(true,true)
assert(#asked==1 and asked[1]:find('^signal rows QuestTable=0x%x+ ') and select(2,asked[1]:gsub('=0x',''))==5,
    asked[1])
assert(logged('title: the co-op save files: the rows asked before any save loads (try 1 of 4)'))
lines.signal=ROWS_IN:format(1)
clock=clock+0.5
ly.tick() -- The rows flow's wait ends: the read-back, then the words in the game's language.
assert(logged('rows read back through FindRow: 7/7 authored rows'),last())
assert(logged('title: the rows are in, before any save loads'),last())
assert(logged('text: game language fr-FR -> fr;'),last())
local quest=tables.QuestTable.rows[Lily.QUEST]
assert(quest.TitleName_:ToString()=="À l'heure" and quest.Description_:ToString()==T.TEXT.fr.D and polyglots==0)
assert(tables.QuestTaskGroupTable.rows.Quest_Sub_MX13_01_M01.Description:ToString()==T.TEXT.fr.M1
    and tables.QuestTaskGroupTable.rows.Quest_Sub_MX13_01_M02.Description:ToString()==T.TEXT.fr.M2
    and tables.QuestTaskTable.rows.Quest_Sub_MX13_01_M01_T01.Description:ToString()==T.TEXT.fr.K1
    and label('TS_GoToTest_2')=="L'autre signal")
assert(tables.QuestTaskTable.rows.Quest_Sub_MX13_01_M02_T01.DisplayText:ToString()=='종료 선택지',
    'Task 2 keeps its shipped text')
-- In game, the gate: no test pak, then a partner, then everything: lily on once.
lines.slot='slot=coop index=4'
her=eve
local n=#asked
ly.tick()
assert(#asked==n and logged('her choice stays off: no zMXIII_P test pak'),last())
pak_in()
mode='host'
logs={}
ly=new() -- The pak is looked for once a Lua load: a reload sees it (the words are written again).
ly.tick()
assert(logged('text: game language fr-FR'))
assert(count('lily on')==0 and last()=='her choice stays off: solo only: leave the session first (coop leave)',last())
mode='none'
ly.tick()
assert(count('lily on')==1 and logged('her choice is offered: lily on'))
ly.tick(); assert(count('lily on')==1,'Once')
-- The native part reads off for 10 s: asked again.
lines.lily='lily=off asks=1 want=on why=busy'
clock=clock+10.5
ly.tick()
assert(count('lily on')==2 and last():find('lily on asked again',1,true),last())
-- A load changes nothing.
lines.lily='lily=on asks=2 want=on why=none'
lines.slot='slot=none index=4'
lines.quest='signalquest=unread state=-1 group=-1 task=-1 epic12=0 asks=0 want=acquire why=none'
ly.tick()
assert(count('lily off')==0,'A load holds her choice')
lines.slot='slot=coop index=4'
lines.quest='signalquest=none state=-1 group=-1 task=-1 epic12=0 asks=0 want=acquire why=none'
-- The pick: her list on, the widget looked for at each tick; a widget first seen on a line, her End Conversation and
-- a line of another dialogue do nothing; our label picked: the acquire after her goodbye.
widget.SelectIndex=2
lines_of('Partir vers une autre région',"L'autre signal",'Fin de la conversation')
clock=clock+1; ly.tick()
assert(lookups>=1 and not logged('the other signal picked'),'An old pick')
widget.SelectIndex=-1; clock=clock+0.25; ly.tick()
widget.SelectIndex=2; clock=clock+0.25; ly.tick() -- End Conversation.
assert(not logged('the other signal picked'),'Her End Conversation does nothing')
widget.SelectIndex=-1; clock=clock+0.25; ly.tick()
widget.SelectIndex=1; clock=clock+0.25; ly.tick()
assert(last()=='the other signal picked: the quest, then the travel, in 5 s, after her goodbye',last())
paused=true
clock=clock+6; ly.tick()
assert(count('signal acquire')==0,'Not while her goodbye shows')
paused=false
clock=clock+0.25; ly.tick()
assert(count('signal acquire')==1 and logged('signal acquire asked (signalquest=none'),last())
clock=clock+0.25; ly.tick(); assert(count('signal acquire')==1 and travels==0,'Waits for the quest')
-- The quest held: the travel; her choice off.
lines.quest='signalquest=held state=1 group=0 task=1 epic12=0 asks=1 want=acquire why=none'
clock=clock+0.25; ly.tick()
assert(travels==1 and logged('the quest is held: signalquest=held') and logged('travel: coop mxiii: the rows are in'))
assert(count('lily off')==1 and logged('lily off (the quest is held'),last())
lines.lily='lily=off asks=3 want=off why=none'
-- The fallback: in Matrix XIII at M01 for 10 s, signal complete once; another visit asks again.
world=MXIII
clock=clock+1; ly.tick()
clock=clock+9.5; ly.tick()
assert(count('signal complete')==0,'Not before 10 s')
clock=clock+0.5; ly.tick()
assert(count('signal complete')==1 and last():find('signal complete asked',1,true),last())
clock=clock+20; ly.tick(); assert(count('signal complete')==1,'Once a visit')
-- SB's EnterZone, or the Complete: M02. No more fallback.
lines.quest='signalquest=held state=1 group=1 task=1 epic12=0 asks=2 want=complete why=none'
clock=clock+0.25; ly.tick()
assert(logged('the quest: signalquest=held state=1 group=1'),last())
world=XION; clock=clock+1; ly.tick()
world=MXIII; clock=clock+11; ly.tick()
assert(count('signal complete')==1,'Past M01: nothing')
world=XION

-- A refused acquire: no travel.
lines.quest='signalquest=none state=-1 group=-1 task=-1 epic12=0 asks=2 want=complete why=none'
lines.lily='lily=on asks=4 want=on why=none'
local ok,why=ly.command('quest')
assert(ok and why=='signal acquire asked: [LY] lines follow',why)
lines.quest='signalquest=none state=-1 group=-1 task=-1 epic12=0 asks=3 want=acquire why=refused'
travels=0
clock=clock+0.25; ly.tick()
assert(last()=='STOP: signal acquire refused: signalquest=none state=-1 group=-1 task=-1 epic12=0 asks=3 '
    ..'want=acquire why=refused' and travels==0,last())
-- coop lily signal: usage, status, travel alone, no word (the quest then the travel), the test pak missing.
ok,why=ly.command('now')
assert(ok==false and why=='Use: coop lily signal [status|quest|travel]')
ok,why=ly.command('status')
assert(ok and why:find("^Lily's signal: her choice offered; signal=rows added=7/7") and why:find('words fr')
    and why:find('test pak v2'),why)
ok,why=ly.command('travel')
assert(ok and travels==1 and why:find('^coop mxiii'),why)
ok,why=ly.command()
assert(ok and why=='signal acquire asked: [LY] lines follow, then the travel',why)
ok,why=ly.command('quest')
assert(ok==false and why:find('busy'),why)
lines.quest='signalquest=held state=1 group=0 task=1 epic12=0 asks=4 want=acquire why=none'
clock=clock+0.25; ly.tick()
assert(travels==2,'No word: the travel once the quest is held')
files={}
lines.quest='signalquest=none state=-1 group=-1 task=-1 epic12=0 asks=4 want=acquire why=none'
n=#asked
ok,why=ly.command('quest')
assert(ok==false and why:find('^coop lily signal quest: no zMXIII_P test pak') and why:find('nothing was asked$')
    and #asked==n,why)
pak_in()
-- Quest_Epic_12 held, our quest held: her choice off, the command refused.
lines.quest='signalquest=none state=-1 group=-1 task=-1 epic12=1 asks=4 want=acquire why=none'
ok,why=ly.command('quest')
assert(ok==false and why:find('past the point of no return'),why)
clock=clock+0.25; ly.tick()
assert(last():find('her choice stays off: Quest_Epic_12 is held',1,true),last())
-- coop off: lily off while her list reads on, asked again after 10 s; nothing else.
lines.quest='signalquest=none state=-1 group=-1 task=-1 epic12=0 asks=4 want=acquire why=none'
clock=clock+0.25; ly.tick() -- On again.
n=count('lily off')
ly.stop()
assert(count('lily off')==n+1,'coop off: lily off')
lines.lily='lily=on asks=5 want=on why=none'
clock=clock+1; ly.tick(true); assert(count('lily off')==n+1)
clock=clock+10; ly.tick(true); assert(count('lily off')==n+2,'Asked again while it reads on')

-- The rows asked once in game when they are not in; a row that reads back wrong stops everything for the Lua load.
build_tables()
tables.QuestTaskTable.rows.Quest_Sub_MX13_01_M01_T01.ID=999
lines.signal='signal=off'
lines.lily='lily=off asks=5 want=off why=none'
asked,logs={},{}
ly=new()
clock=clock+1; ly.tick()
assert(#asked==1 and asked[1]:find('^signal rows QuestTable=0x'),tostring(asked[1]))
clock=clock+1; ly.tick(); assert(#asked==1,'Once a Lua load')
lines.signal=ROWS_IN:format(2)
clock=clock+0.5; ly.tick()
assert(logged("STOP: rows: A Lily's signal row reads back wrong (Quest_Sub_MX13_01_M01_T01 ID reads"),last())
clock=clock+1; ly.tick()
assert(count('lily on')==0 and last()=='her choice stays off: the signal rows did not read back as written',last())
assert(label('TS_GoToTest_2')=='종료 선택지','No words written')
-- Rows already in (an earlier Lua load): read back with no ask; a label that does not stick stops the words.
build_tables()
local choice=tables.TheaterSelectDataTable.rows.TS_GoToTest_2
tables.TheaterSelectDataTable.rows.TS_GoToTest_2=setmetatable({},{__index=choice,
    __newindex=function(_,k,v) if k~='DisplayText' then choice[k]=v end end})
asked,logs={},{}
ly=new()
clock=clock+1; ly.tick()
assert(#asked==0 and logged("rows already in"),'Read back, not asked')
assert(logged('STOP: text: TS_GoToTest_2 read back differs at DisplayText'),last())
clock=clock+1; ly.tick()
assert(count('lily on')==0 and last()=='her choice stays off: the words did not write (a STOP: text line says why)',
    last())
print('lily_test: ok')
