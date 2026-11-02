-- Lily's signal (matrix13/quest/on_time.lua, matrix13/quest/text.lua) over fakes: the status text (slot, signal=,
-- lily=, signalquest= lines as the native part writes them), the 25 tables with the signal rows as the native part
-- writes them (FName fields by comparison index, the groups' TaskContainerArray as an array of structs each holding a
-- TaskAliasArray of FNames, FText fields), the language library, a text library whose PolyglotDataToText raises as
-- UE4SS does on a Lua-table map, EVE's world and place, the select widget through the widget library's lookup
-- (SelectIndex -1 until a pick, its DataArray lines' DisplayText), the test pak's files, coop mxiii's travel and the
-- talk player (story/subtitles.lua: play, arm, playing, cutscene, holds, stop). Covered: its 25 rows against rows.h's
-- kSignalRecipe and kSignalPatches (names, templates, IDs, each patched field's kind and value, no field more, the
-- quest rows last of their rows and the choice row patched in place last); the words in English and French (every line,
-- French for any French culture, English for the others); nothing off a co-op save; no test pak: no rows at the title
-- or in game, no quest unit read; with it, the title's batch with only the 5 tables its rows use; the words written
-- once the rows read back (no PolyglotDataToText call), a row that is not the one known stopping them and her choice
-- for the Lua load; the rows asked once in game when they are not in, also after a title batch refused by a shut gate
-- at all 4 tries; signal watch once the cheap gates hold (co-op save, solo, the test pak, the rows read back) and never
-- before; the prologue's gate (Quest_Epic_11 at M04 in progress, neither quest held, 20 s with no screen, no theater of
-- the game playing) and its acquire once a Lua load, never on a save that holds On Time; lily on only while every gate
-- holds and the prologue is at its task (label 1) or On Time at M06's (label 2, written into the row), off when one
-- fails, asked again while the native part reads otherwise, a load changing nothing; a pick only of the row's label on
-- a SelectIndex turning from -1 (her End Conversation, or a widget first seen on a line, do nothing), then after her
-- goodbye the prologue talk, signal talked, signal acquire once the prologue is complete (or refused, or after 15 s),
-- and the travel once the quest is held; the end talk and signal tell; a talk that does not play; the arrival talk
-- once a Lua load, after 3 s in Matrix XIII with no screen; the fallback's signal complete once a visit at M01 after
-- 10 s; the drive room's signal zone4 once a visit at M05 after 2 s inside its box; a refused acquire with no travel;
-- coop lily signal status, quest (refused with no test pak), travel, next and no word; coop lily talk and hold; coop
-- off.
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
local Lily=require('matrix13.quest.on_time')
local TEXT,culture_of=require('matrix13.quest.text'),require('matrix13.culture')
local Enemy=require('cut.enemy')

-- The rows against rows.h's hand-written batch.
do
    local f=assert(io.open('native/src/lion/rows.h'))
    local src=f:read('a')
    f:close()
    -- A text as C++ writes it: adjacent literals joined; kLilyFilters by its definition.
    local function literal(text) return (text:gsub('"%s+"','')):match('^"(.*)"$') end
    local consts={kLilyFilters=literal(assert(src:match('constexpr const char kLilyFilters%[%] =%s*(.-);')))}
    local patches={}
    for at,kind,value,text,field in assert(src:match('constexpr Patch kSignalPatches%[%] = {\n(.-)\n};'))
        :gmatch('{(0x%x+), Kind::(%w+), ([%d%.%-]+),%s*([^}]-)},%s*// (%w+)') do
        patches[#patches+1]={at=tonumber(at),kind=kind,f=tonumber(value),text=literal(text) or consts[text],field=field}
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
    assert(n==25 and #Lily.ROWS==25 and #patches==57,n..' rows, '..#patches..' patches')
    assert(Lily.ROWS[23].name==Lily.QUEST and Lily.ROWS[23].id==Lily.ID and Lily.ROWS[24].name==Lily.PROLOGUE
        and Lily.ROWS[24].id==Lily.PROLOGUE_ID and Lily.ROWS[25].id==nil)
    assert(consts.kLilyFilters==Lily.FILTERS and select(2,Lily.FILTERS:gsub('|',''))==7)
end
-- The words: every line in English and French; French for any French culture, English for the rest.
for _,c in ipairs({'en','fr'}) do
    for _,k in ipairs({'L','L2','PT','PD','PM','T','D','M1','M2','M3','M4','M5','M6','K1','K2','K3','K4','K5'}) do
        assert(type(TEXT[c][k])=='string' and TEXT[c][k]~='',c..k)
    end
end
assert(TEXT.en.T=='On Time' and TEXT.fr.T=="À l'heure" and TEXT.en.L=='The other signal'
    and TEXT.fr.L2=='À propos de la Matrice 13' and TEXT.en.PT=='A Second Signal')
for _,t in ipairs(Lily.TEXTS) do -- Every words row is one of the signal rows, with its ID.
    local found=false
    for _,r in ipairs(Lily.ROWS) do found=found or r.table==t[1] and r.name==t[2] and (r.id or 86)==t[3] end
    assert(found,t[2])
end
assert(#Lily.TEXTS==15 and Lily.TEXTS[15]==Lily.CHOICE,'The choice row last')
-- The drive room: its plan box in world cm (zone 1's plan frame), inside at its middle, outside past each side.
local function world_of(x,y,z)
    local f,r=math.rad(175),math.rad(265)
    return {X=40585+100*(x*math.cos(r)+y*math.cos(f)),Y=35615+100*(x*math.sin(r)+y*math.sin(f)),Z=-939+100*z}
end
assert(Lily.drive_room(world_of(-87.5,-130,-155)) and Lily.drive_room(world_of(-94.9,-149.9,-156.2)))
for _,v in ipairs({{-96,-130,-155},{-79,-130,-155},{-87.5,-151,-155},{-87.5,-109,-155},{-87.5,-130,-157},
    {-87.5,-130,-139}}) do
    assert(not Lily.drive_room(world_of(v[1],v[2],v[3])),table.concat(v,' '))
end
assert(culture_of('fr-FR')=='fr' and culture_of('fr')=='fr' and culture_of('de-DE')=='en' and culture_of(nil)=='en'
    and culture_of('ja')=='en')
assert(TEXT.en.D:find('"This lift stays in service so that those who left can come home."',1,true))

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
local eve=object({at={X=0,Y=0,Z=0},GetWorld=function() return {GetFullName=function() return world end} end})
eve.K2_GetActorLocation=function(self) return {X=self.at.X,Y=self.at.Y,Z=self.at.Z} end
her=eve
-- The test pak's files, as matrix13/world/travel.lua reads them.
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
local travel_answer={true,'coop mxiii: the rows are in and the travel to DLC02_00_Camp_00 is asked'}
-- The signalquest line: unread, or none with Quest_Sub_005 complete and Quest_Epic_11 at M04 in progress, unless said.
local function quest_line(t)
    local d={'none',-1,-1,-1,0,3,'none',-1,-1,-1,3,1,0,'acquire','none'}
    local keys={'held','state','group','task','epic12','sub005','pro','prostate','progroup','protask','epic11',
        'epic11state','asks','want','why'}
    for i,k in ipairs(keys) do if t and t[k]~=nil then d[i]=t[k] end end
    return string.format('signalquest=%s state=%s group=%s task=%s epic12=%s sub005=%s pro=%s prostate=%s progroup=%s '
        ..'protask=%s epic11=%s epic11state=%s asks=%s want=%s why=%s',table.unpack(d))
end
local lines={slot='slot=coop index=4',signal='signal=off',lily='lily=unread asks=0 want=off why=none',
    quest=quest_line({held='unread',sub005=-1,pro='unread',epic11=-1,epic11state=-1})}
local function status_text()
    return 'mod=v\n'..lines.slot..'\n'..lines.signal..'\n'..lines.lily..'\n'..(lines.quest or '')..'\nlast=x\n'
end
-- The talk player: each play kept with its done; talks.done(how) ends the one under way.
local plays,arms,talk_stops,holds,busy,refuse_talk={},0,0,nil,nil,nil
local talks={}
talks.arm=function() arms=arms+1 end
talks.cutscene=function() return busy end
talks.holds=function(on) holds=on end
talks.holding=function() return holds~=false end
talks.stop=function() talk_stops=talk_stops+1; talks.now=nil end
talks.playing=function() return talks.now end
function talks.play(name,kit,done)
    if refuse_talk then return false,refuse_talk end
    plays[#plays+1]={name=name,kit=kit}
    talks.now=name
    talks.done=function(how) talks.now=nil; done(how) end
    return true,'talk '..name..' asked: [LY] lines follow'
end
-- The zone talks, as far as this file calls them: each call kept as its reason.
local zone_calls={}
local zones={tick=function() end,restart=function() end,
    drop=function(why) zone_calls[#zone_calls+1]='drop '..why end,
    leave=function(why) zone_calls[#zone_calls+1]='leave '..why end}
local function zone_called(what) for _,c in ipairs(zone_calls) do if c==what then return true end end end
local function new()
    return Lily.new({zones=zones,log=function(m) logs[#logs+1]=m end,status=status_text,
        ask=function(line) asked[#asked+1]=line; return true,'asked the native part: '..line end,
        mode=function() return mode end,paused=function() return paused end,
        travel=function() travels=travels+1; return table.unpack(travel_answer) end,paks=PAKS,read=read,talks=talks})
end
local function last() return logs[#logs] end
local function logged(text) for _,l in ipairs(logs) do if l:find(text,1,true) then return l end end end
local function count(line) local n=0; for _,a in ipairs(asked) do if a==line then n=n+1 end end; return n end
local ROWS_IN='signal=rows added=25/25 asks=%d spawns=? char=0/0 skills=0/0 stance=0/0'
-- The signal rows request: the 5 tables its rows go into, in kLionTables' order.
local SIGNAL_REQUEST=string.format('signal rows QuestTable=0x%x QuestTaskGroupTable=0x%x QuestTaskTable=0x%x '
    ..'LevelTargetFilter=0x%x TheaterSelectDataTable=0x%x',tables.QuestTable:GetAddress(),
    tables.QuestTaskGroupTable:GetAddress(),tables.QuestTaskTable:GetAddress(),tables.LevelTargetFilter:GetAddress(),
    tables.TheaterSelectDataTable:GetAddress())
local function label(name) return tables.TheaterSelectDataTable.rows[name].DisplayText:ToString() end

-- Off a co-op save: nothing asked, nothing written.
local ly=new()
lines.slot='slot=main index=0'
her=nil
ly.tick()
lines.slot='slot=coop index=4'
ly.tick() -- No EVE: no rows asked in game.
assert(#asked==0,'Nothing off a co-op save or with no EVE')
-- No test pak: no rows at the title (nothing said either) nor in game, no quest unit read, her choice off.
lines.slot='slot=none index=4'
ly.title(true,true)
assert(#asked==0 and not logged('title:'),'No test pak: nothing at the title')
lines.slot='slot=coop index=4'
her=eve
ly.tick()
assert(#asked==0 and last():find('^her choice stays off: no zMXIII_P test pak %('),last())
-- The test pak (looked for once a Lua load, so a reload sees it): the title's batch on the co-op save files only, with
-- the 5 tables its rows go into, then read back.
pak_in()
her=nil
logs={}
ly=new()
lines.slot='slot=none index=4'
ly.title(true,false)
assert(#asked==0,'Not on your own saves')
ly.title(true,true)
assert(#asked==1 and asked[1]==SIGNAL_REQUEST,asked[1])
assert(logged('title: the co-op save files and test pak v2: the rows asked before any save loads (try 1 of 4)'))
lines.signal=ROWS_IN:format(1)
clock=clock+0.5
ly.tick() -- The rows flow's wait ends: the read-back, then the words in the game's language.
assert(logged('rows read back through FindRow: 25/25 authored rows, 57 fields as written (20 differ from the template '
    ..'row)'),last())
assert(logged('title: the rows are in, before any save loads'),last())
assert(logged('text: game language fr-FR -> fr;'),last())
local quest=tables.QuestTable.rows[Lily.QUEST]
local group,task=tables.QuestTaskGroupTable.rows,tables.QuestTaskTable.rows
assert(quest.TitleName_:ToString()=="À l'heure" and quest.Description_:ToString()==TEXT.fr.D and polyglots==0)
assert(tables.QuestTable.rows[Lily.PROLOGUE].TitleName_:ToString()=='Un second signal'
    and tables.QuestTable.rows[Lily.PROLOGUE].Description_:ToString()==TEXT.fr.PD
    and group.Quest_Sub_MX13_00_M01.Description:ToString()==TEXT.fr.PM)
for i=1,6 do assert(group['Quest_Sub_MX13_01_M0'..i].Description:ToString()==TEXT.fr['M'..i],'M'..i) end
for i=1,5 do assert(task['Quest_Sub_MX13_01_M0'..i..'_T01'].Description:ToString()==TEXT.fr['K'..i],'K'..i) end
assert(label('TS_GoToTest_2')=="L'autre signal")
assert(task.Quest_Sub_MX13_01_M06_T01.Description==nil and task.Quest_Sub_MX13_00_M01_T01.Description==nil,
    'M06 and the prologue keep the shipped Talk to Lily')
assert(#asked==1,'No quest unit read at the title')
-- In game, the gate: a partner (no signal watch yet), then solo: signal watch once, the quest unit unread, then
-- Quest_Sub_005 running or never taken, then complete (Coop00's state) with no quest of ours: her choice stays off.
lines.slot='slot=coop index=4'
her=eve
mode='host'
ly.tick()
assert(count('signal watch')==0 and count('lily on')==0
    and last()=='her choice stays off: solo only: leave the session first (coop leave)',last())
mode='none'
ly.tick()
assert(count('signal watch')==1 and logged('signal watch: asked the native part: signal watch')
    and last()=='her choice stays off: the quest unit is not read yet',last())
lines.quest=quest_line({sub005=1})
ly.tick()
assert(count('signal watch')==1 and count('lily on')==0 and last()=='her choice stays off: Quest_Sub_005 is not '
    ..'complete (sub005=1): her own rows could then fill the six slots of her choice box',last())
lines.quest=quest_line({sub005=-1})
ly.tick()
assert(count('lily on')==0 and last():find('Quest_Sub_005 is not complete (sub005=-1)',1,true),last())
lines.quest='signalquest=none state=-1 group=-1 task=-1 epic12=0 asks=0 want=acquire why=none'
ly.tick()
assert(count('lily on')==0 and last():find('(sub005=nil)',1,true),'An older native part: off')
-- The prologue: Quest_Epic_11 not at M04: nothing; at M04 in progress for 5 s with no screen and no theater: signal
-- prologue, once a Lua load. A screen, then a theater of the game, wait.
lines.quest=quest_line({epic11=2})
for _=1,100 do clock=clock+0.25; ly.tick() end
assert(count('signal prologue')==0 and last():find('^her choice stays off: the prologue is not at its task'),last())
lines.quest=quest_line()
clock=clock+0.25; ly.tick()
clock=clock+3; ly.tick()
paused=true; clock=clock+10; ly.tick(); paused=false -- A screen: the 5 s start again.
clock=clock+0.25; ly.tick()
clock=clock+4.5; ly.tick()
assert(count('signal prologue')==0,'Not before 5 s with no screen')
busy='DED_Area01'
clock=clock+0.5; ly.tick()
assert(count('signal prologue')==0 and last():find('prologue: a theater of the game plays (DED_Area01)',1,true),last())
busy=nil
clock=clock+4.75; ly.tick(); assert(count('signal prologue')==0)
clock=clock+0.25; ly.tick()
assert(count('signal prologue')==1 and logged('Phase 5 at M04 with neither quest held, 5 s with no screen: signal '
    ..'prologue asked'),last())
lines.quest=quest_line({pro='held',prostate=1,progroup=0,protask=0,asks=1,want='prologue'})
clock=clock+0.25; ly.tick()
assert(logged('signal prologue: done: signalquest=none') and logged('the quests: signalquest=none'),last())
clock=clock+60; ly.tick(); assert(count('signal prologue')==1,'Once a Lua load')
-- The prologue at its task: lily on once, label 1 (already written with the words).
lines.quest=quest_line({pro='held',prostate=1,progroup=0,protask=1,asks=1,want='prologue'})
clock=clock+0.25; ly.tick()
assert(count('lily on')==1 and logged('her choice is offered: lily on') and not logged('label:'))
ly.tick(); assert(count('lily on')==1 and count('signal watch')==1,'Once')
-- The native part reads off for 10 s: asked again.
lines.lily='lily=off asks=1 want=on why=busy'
clock=clock+10.5
ly.tick()
assert(count('lily on')==2 and last():find('lily on asked again',1,true),last())
-- A load changes nothing.
lines.lily='lily=on asks=2 want=on why=none'
lines.slot='slot=none index=4'
lines.quest=quest_line({held='unread',pro='unread'})
ly.tick()
assert(count('lily off')==0,'A load holds her choice')
lines.slot='slot=coop index=4'
lines.quest=quest_line({pro='held',prostate=1,progroup=0,protask=1,asks=1,want='prologue'})
-- The pick: her list on, the widget looked for at each tick; a widget first seen on a line, her End Conversation and
-- a line of another dialogue do nothing; our label picked: the talk player armed, then the prologue talk 0.5 s after
-- her goodbye's screen closed.
widget.SelectIndex=2
lines_of('Partir vers une autre région',"L'autre signal",'Fin de la conversation')
clock=clock+1; ly.tick()
assert(lookups>=1 and not logged('the other signal picked'),'An old pick')
widget.SelectIndex=-1; clock=clock+0.25; ly.tick()
widget.SelectIndex=2; clock=clock+0.25; ly.tick() -- End Conversation.
assert(not logged('the other signal picked'),'Her End Conversation does nothing')
widget.SelectIndex=-1; clock=clock+0.25; ly.tick()
widget.SelectIndex=1; clock=clock+0.25; ly.tick()
assert(arms==1 and last()=='the other signal picked: the prologue talk, then the quest and the travel, after her '
    ..'goodbye (in 5 s if none shows)',last())
paused=true
clock=clock+6; ly.tick()
assert(#plays==0,'Not while her goodbye shows')
paused=false
clock=clock+0.25; ly.tick()
assert(#plays==0,'Not before 0.5 s after its screen closed')
clock=clock+0.25; ly.tick()
assert(#plays==1 and plays[1].name=='prologue' and not plays[1].kit and talks.playing()=='prologue',last())
local n=#asked
clock=clock+30; ly.tick(); assert(#asked==n,'Nothing asked during the talk')
-- The talk ends: signal talked; the prologue complete: signal acquire; the quest held: the travel; her choice off.
talks.done('theater')
clock=clock+0.25; ly.tick()
assert(count('signal talked')==1 and logged('talk prologue ended (theater): signal talked asked'),last())
clock=clock+0.25; ly.tick(); assert(count('signal acquire')==0,'Waits for the prologue')
lines.quest=quest_line({pro='held',prostate=3,progroup=0,protask=2,asks=2,want='talked'})
clock=clock+0.25; ly.tick()
assert(logged('the prologue is complete: signalquest=none') and count('signal acquire')==1
    and logged('signal acquire asked (signalquest=none'),last())
clock=clock+0.25; ly.tick(); assert(count('signal acquire')==1 and travels==0,'Waits for the quest')
lines.quest=quest_line({held='held',state=1,group=0,task=1,pro='held',prostate=3,progroup=0,protask=2,asks=3})
clock=clock+0.25; ly.tick()
assert(travels==1 and logged('the quest is held: signalquest=held') and logged('travel: coop mxiii: the rows are in'))
assert(count('lily off')==1 and logged('lily off (the prologue is not at its task'),last())
lines.lily='lily=off asks=3 want=off why=none'
-- In Matrix XIII: the arrival talk 4 s after the map turned with no screen; the fallback at M01 after 10 s, once a
-- visit; a later visit replays no arrival talk.
world=MXIII
clock=clock+1; ly.tick()
paused=true; clock=clock+2.5; ly.tick(); paused=false
clock=clock+3.75; ly.tick()
assert(#plays==1,'Not before 4 s with no screen')
clock=clock+0.25; ly.tick()
assert(#plays==2 and plays[2].name=='arrival' and logged('the arrival talk, once this Lua load'),last())
clock=clock+3; ly.tick()
assert(count('signal complete')==0,'Not before 10 s')
clock=clock+0.5; ly.tick()
assert(count('signal complete')==1 and last():find('signal complete asked',1,true),last())
clock=clock+20; ly.tick(); assert(count('signal complete')==1,'Once a visit')
talks.done('kit')
clock=clock+0.25; ly.tick()
assert(logged('talk arrival ended (kit)'),last())
-- SB's EnterZone, or the Complete: M02. No more fallback, no second arrival talk.
lines.quest=quest_line({held='held',state=1,group=1,task=1,pro='held',prostate=3,progroup=0,protask=2,asks=4,
    want='complete'})
clock=clock+0.25; ly.tick()
assert(logged('signal complete: done: signalquest=held state=1 group=1')
    and logged('the quests: signalquest=held state=1 group=1'),last())
world=XION; clock=clock+1; ly.tick()
world=MXIII; clock=clock+11; ly.tick()
assert(count('signal complete')==1 and #plays==2,'Past M01, the arrival talk played: nothing')
-- The drive room at M05: inside its box for 2 s, signal zone4 once a visit; outside, nothing.
lines.quest=quest_line({held='held',state=1,group=4,task=1,pro='held',prostate=3,progroup=0,protask=2,asks=4,
    want='complete'})
eve.at=world_of(-87.5,-80,-155) -- Zone 4, outside the room.
for _=1,20 do clock=clock+0.25; ly.tick() end
assert(count('signal zone4')==0,'Outside the room')
eve.at=world_of(-87.5,-130,-155)
clock=clock+0.25; ly.tick()
clock=clock+1.5; ly.tick(); assert(count('signal zone4')==0,'Not before 2 s')
clock=clock+0.5; ly.tick()
assert(count('signal zone4')==1 and logged('in the Fusion Drive room for 2 s at M05: signal zone4 asked'),last())
clock=clock+5; ly.tick(); assert(count('signal zone4')==1,'Once a visit')
lines.quest=quest_line({held='held',state=1,group=4,task=1,pro='held',prostate=3,progroup=0,protask=2,asks=5,
    want='zone4',why='task'})
clock=clock+0.25; ly.tick()
assert(logged('STOP: signal zone4 refused: signalquest=held state=1 group=4'),last())
-- coop lily signal next: refused off On Time in progress, else asked.
local ok,why=ly.command('next')
assert(ok and why=='signal next asked: [LY] lines follow' and count('signal next')==1,why)
world,eve.at=XION,{X=0,Y=0,Z=0}
-- M06: her row back as "About Matrix 13" (written into the row), the pick, the end talk, signal tell, the quest done.
lines.quest=quest_line({held='held',state=1,group=5,task=1,pro='held',prostate=3,progroup=0,protask=2,asks=6,
    want='next'})
clock=clock+0.25; ly.tick()
assert(label('TS_GoToTest_2')=='À propos de la Matrice 13'
    and logged('label: her choice reads À propos de la Matrice 13') and count('lily on')==3,last())
lines.lily='lily=on asks=4 want=on why=none'
widget.SelectIndex=-1
lines_of("L'autre signal",'Fin de la conversation')
clock=clock+0.25; ly.tick()
widget.SelectIndex=0; clock=clock+0.25; ly.tick()
assert(not logged('about Matrix 13 picked'),'The old label is no pick')
lines_of('À propos de la Matrice 13','Fin de la conversation')
widget.SelectIndex=-1; clock=clock+0.25; ly.tick()
zone_calls={}
widget.SelectIndex=0; clock=clock+0.25; ly.tick()
assert(zone_called('drop a quest step'),'The pick frees the talk player for her talk')
assert(arms==2 and logged('about Matrix 13 picked: the end talk, then On Time complete, after her goodbye (in 5 s '
    ..'if none shows)'),last())
busy='Subtitle_NPC_Start_WLBXionP5_8DF9E0F244F00B5FB379A5938C796E0C' -- Her goodbye's theater: the talk asked at once.
clock=clock+0.5; ly.tick()
assert(#plays==3 and plays[3].name=='finale',tostring(plays[3]))
busy=nil
talks.done('sequence')
clock=clock+0.25; ly.tick()
assert(count('signal tell')==1 and logged('talk finale ended (sequence): signal tell asked'),last())
lines.quest=quest_line({held='held',state=3,group=5,task=2,pro='held',prostate=3,progroup=0,protask=2,asks=7,
    want='tell'})
clock=clock+0.25; ly.tick()
assert(logged('On Time is complete: signalquest=held state=3') and logged('lily off (On Time is held, not at M06'),
    last())
lines.lily='lily=off asks=5 want=off why=none'
ok,why=ly.command('next')
assert(ok==false and why:find('^coop lily signal next: On Time is not in progress'),why)

-- A talk that does not play, then a refused signal talked: On Time and the travel go on all the same.
ly=new()
logs,plays={},{}
lines.quest=quest_line({pro='held',prostate=1,progroup=0,protask=1,asks=7})
lines.lily='lily=off asks=5 want=off why=none'
travels=0
for _=1,3 do clock=clock+0.25; ly.tick() end
assert(count('lily on')==4,'On again on a new Lua load')
lines.lily='lily=on asks=6 want=on why=none'
lines_of("L'autre signal",'Fin de la conversation')
widget.SelectIndex=-1; clock=clock+0.25; ly.tick()
widget.SelectIndex=0; clock=clock+0.25; ly.tick()
refuse_talk='a talk plays (arrival)'
clock=clock+4.5; ly.tick()
assert(not logged('talk prologue not played'),'No theater or screen seen: not before 5 s')
clock=clock+0.75; ly.tick()
assert(logged('STOP: talk prologue not played: a talk plays (arrival); the quest goes on'),last())
refuse_talk=nil
clock=clock+0.25; ly.tick()
assert(count('signal talked')==2 and logged('talk prologue ended (not played): signal talked asked'),last())
lines.quest=quest_line({pro='held',prostate=1,progroup=0,protask=1,asks=8,want='talked',why='task'})
clock=clock+0.25; ly.tick()
assert(logged('STOP: signal talked refused: ') and count('signal acquire')==2,last())

-- A refused acquire: no travel.
ly=new()
logs={}
lines.quest=quest_line({asks=8,want='complete'})
lines.lily='lily=on asks=4 want=on why=none'
clock=clock+0.25; ly.tick()
ok,why=ly.command('quest')
assert(ok and why=='signal acquire asked: [LY] lines follow',why)
lines.quest=quest_line({asks=9,want='acquire',why='refused'})
travels=0
clock=clock+0.25; ly.tick()
assert(last()=='STOP: signal acquire refused: '..quest_line({asks=9,want='acquire',why='refused'}) and travels==0,
    last())
-- coop lily signal: usage, status, travel alone, no word (the quest then the travel), the test pak missing.
ok,why=ly.command('now')
assert(ok==false and why=='Use: coop lily signal [status|quest|travel|next]')
ok,why=ly.command('status')
assert(ok and why:find("^Lily's signal: her choice off %(the prologue is not at its task") and why:find('words fr')
    and why:find('signal=rows added=25/25',1,true) and why:find('label 1') and why:find('test pak v2')
    and why:find('holds on'),why)
ok,why=ly.command('travel')
assert(ok and travels==1 and why:find('^coop mxiii'),why)
ok,why=ly.command()
assert(ok and why=='signal acquire asked: [LY] lines follow, then the travel',why)
ok,why=ly.command('quest')
assert(ok==false and why:find('busy'),why)
lines.quest=quest_line({held='held',state=1,group=0,task=1,asks=10})
clock=clock+0.25; ly.tick()
assert(travels==2,'No word: the travel once the quest is held')
ok,why=ly.command('quest')
assert(ok==false and why:find('On Time is held',1,true),why)
files={}
lines.quest=quest_line({asks=10})
n=#asked
ok,why=ly.command('quest')
assert(ok==false and why:find('^coop lily signal quest: no zMXIII_P test pak') and why:find('nothing was asked$')
    and #asked==n,why)
ok,why=ly.talk('prologue')
assert(ok==false and why:find('^coop lily talk: no zMXIII_P test pak'),why)
pak_in()
-- coop lily talk: solo only; the kit flag; one at a time; a word it does not know. coop lily hold.
mode='host'
ok,why=ly.talk('arrival','kit')
assert(ok==false and why:find('solo only',1,true),why)
mode='none'
ok,why=ly.talk('arrival','kit')
assert(ok and plays[#plays].name=='arrival' and plays[#plays].kit==true,why)
ok,why=ly.talk('finale'); assert(ok==false and why:find('busy'),why)
talks.done('kit'); clock=clock+0.25; ly.tick()
ok,why=ly.talk('end'); assert(ok==false and why=='Use: coop lily talk prologue|arrival|finale [kit]',why)
ok,why=ly.talk('finale','now'); assert(ok==false and why:find('^Use'),why)
ok,why=ly.hold(false); assert(ok and holds==false and why:find('off'),why)
ly.hold(true)
-- Quest_Epic_12 held, our quest held: her choice off, the command refused.
lines.quest=quest_line({epic12=1,asks=10})
ok,why=ly.command('quest')
assert(ok==false and why:find('past the point of no return'),why)
clock=clock+0.25; ly.tick()
assert(last():find('her choice stays off: Quest_Epic_12 is held',1,true),last())
-- A save that holds On Time never gets the prologue.
lines.quest=quest_line({held='held',state=1,group=2,task=1,asks=10})
for _=1,120 do clock=clock+0.25; ly.tick() end
assert(count('signal prologue')==1,'On Time held: no prologue')
-- Off a solo co-op save, in a load, and at coop off the zone talks leave.
zone_calls={}
lines.slot='slot=none index=4'
clock=clock+0.25; ly.tick()
assert(zone_called('leave a load'),'A load')
lines.slot='slot=coop index=4'
mode='host'
clock=clock+0.25; ly.tick()
assert(zone_called('leave not solo on a co-op save'),'A session')
mode='none'
clock=clock+0.25; ly.tick()
-- coop off: lily off while her list reads on, asked again after 10 s; the talk dropped; nothing else.
lines.quest=quest_line({pro='held',prostate=1,progroup=0,protask=1,asks=10})
clock=clock+0.25; ly.tick() -- On again.
n=count('lily off')
local stops=talk_stops
ly.stop()
assert(zone_called('leave coop off'),'coop off')
assert(count('lily off')==n+1 and talk_stops==stops+1,'coop off: lily off, the talk dropped')
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
assert(#asked==1 and asked[1]==SIGNAL_REQUEST,tostring(asked[1]))
clock=clock+1; ly.tick(); assert(#asked==1,'Once a Lua load')
lines.signal=ROWS_IN:format(2)
clock=clock+0.5; ly.tick()
assert(logged("STOP: rows: A Lily's signal row reads back wrong (Quest_Sub_MX13_01_M01_T01 ID reads"),last())
clock=clock+1; ly.tick()
assert(count('lily on')==0 and last()=='her choice stays off: the signal rows did not read back as written',last())
assert(label('TS_GoToTest_2')=='종료 선택지' and count('signal watch')==0,'No words written, no quest unit read')
-- Rows already in (an earlier Lua load): read back with no ask (signal watch follows); a label that does not stick
-- stops the words.
build_tables()
local choice=tables.TheaterSelectDataTable.rows.TS_GoToTest_2
tables.TheaterSelectDataTable.rows.TS_GoToTest_2=setmetatable({},{__index=choice,
    __newindex=function(_,k,v) if k~='DisplayText' then choice[k]=v end end})
asked,logs={},{}
ly=new()
clock=clock+1; ly.tick()
assert(#asked==1 and asked[1]=='signal watch' and logged("rows already in"),'Read back, not asked')
assert(logged('STOP: text: TS_GoToTest_2 read back differs at DisplayText'),last())
clock=clock+1; ly.tick()
assert(count('lily on')==0 and last()=='her choice stays off: the words did not write (a STOP: text line says why)',
    last())
-- A title batch that a shut gate refused at each of its 4 tries (why=busy): the ask in game, once the co-op save is
-- in, still asks the rows, once a Lua load.
build_tables()
lines.signal,lines.slot='signal=off','slot=none index=4'
asked,logs={},{}
her=nil
ly=new()
for try=1,4 do
    ly.title(true,true)
    assert(#asked==try and asked[try]==SIGNAL_REQUEST,'Try '..try)
    lines.signal='signal=refused added=0/25 asks='..try..' spawns=? why=busy table=- row=-'
    clock=clock+0.5; ly.tick()
    clock=clock+10
end
ly.title(true,true)
assert(#asked==4 and last()=="title: The native part refused the Lily's signal rows (why=busy, table=-, row=-): "
    ..'coop-link.log says why; asking again skips the rows already in. (no more tries this visit of the title: the '
    ..'next visit of the title (or the ask on a co-op save in game once a Lua load, too late for a save that holds a '
    ..'quest) adds them)',last())
lines.slot='slot=coop index=4'
her=eve
clock=clock+1; ly.tick()
assert(#asked==5 and asked[5]==SIGNAL_REQUEST,tostring(asked[5]))
lines.signal='signal=refused added=0/25 asks=5 spawns=? why=busy table=- row=-'
clock=clock+0.5; ly.tick()
clock=clock+1; ly.tick()
assert(#asked==5,'Once a Lua load')
print('matrix13/quest/on_time_test: ok')
