-- Roxanne's Night Operation choices (nightop/roxanne.lua, nightop/roxanne_text.lua) over fakes: the status text, the
-- four test rows of TheaterSelectDataTable (FName fields by comparison index), the text libraries, EVE's world, the
-- select widget through the widget library's lookup, and the requests, notices, starts and shop opens it makes.
-- Covered: the text table (every language, its four lines, the asset's Korean sources); nothing on another save or out
-- of Xion; the arm in Xion (the four keys registered, each row checked, written and read back, then roxanne on), once
-- a Lua load, and a row that is not the one known stopping it with nothing asked; a pick read from the widgets, looked
-- for at each tick, only when a SelectIndex turns from -1 to a line of ours (her own Shop, End and a widget first seen
-- on a line do nothing), a box built for a later dialogue watched while an older one stays valid; a level booked and
-- started through coop nightop start once EVE is out of Xion, its refusals said once each, and a host's booking held
-- while the run asks the partner, tried again 30 s after an ask the partner could not join; a guest's pick; the
-- supplies opening the shop's screen after her goodbye; roxanne on asked again when the native part reads
-- off; off on another save and at coop off (roxanne off, asked again every 10 s while her list reads on, then the rows'
-- shipped values only once it reads off, never while it reads on or after a fault); cancel; an arm, a start or a shop
-- open that raises.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=100
os.clock=function() return clock end
-- FName: a registry; FNAME_Find on an unknown name gives None (index 0).
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
for _,n in ipairs({'Temp_TS_Select_Test','TS_GoToTest','A1','A2','A3','Success','Success2'}) do FName(n) end
local function text_of(s) return {type=function() return 'FText' end,ToString=function() return s end} end
FText=function(s) return text_of(s) end
local function object(t)
    t.type=t.type or function() return 'UObject' end
    t.IsValid=t.IsValid or function() return true end
    t.GetAddress=t.GetAddress or function() return 0x1000 end
    t.GetFullName=t.GetFullName or function() return 'Object /Engine/Transient.X' end
    return t
end
-- The four rows as shipped, and her two.
local registered={}
local rows={}
local function row(id,list,exec,task,key)
    return {ID=id,SelectDataName=FName(list),InteractionGraphExec=FName(exec),NextTaskTagName=FName(task),key=key,
        DisplayText=nil}
end
local function ship()
    rows={Temp_TS_Select_Test_1=row(14,'Temp_TS_Select_Test','None','A1','C8A59F404A1B66555B5265ACCF31FCFD'),
        Temp_TS_Select_Test_2=row(15,'Temp_TS_Select_Test','None','A2','CD80DD9243FF6B46E77860B442659254'),
        Temp_TS_Select_Test_3=row(16,'Temp_TS_Select_Test','None','A3','2EF677E140813CB4F455019EBF8EF827'),
        TS_GoToTest_1=row(85,'TS_GoToTest','Success','None','9E5E7E6644D9B537F9CAFF9BB2233462')}
end
ship()
local reads=0
local choices=object({FindRow=function(_,name)
    reads=reads+1
    local r=rows[name]
    if r and registered[r.key] then r.DisplayText=text_of(registered[r.key]) end
    return r
end})
local culture='fr-FR'
-- The select widget: its SelectIndex and its lines' texts.
local widget=object({SelectIndex=-1,DataArray={}})
local function lines_of(...)
    local list={}
    for _,s in ipairs({...}) do list[#list+1]={DisplayText=text_of(s)} end
    widget.DataArray=list
end
local lookups=0
local shown={widget} -- The select widgets the lookup finds.
local objects={
    ['/Game/Local/Data/TheaterSelectDataTable.TheaterSelectDataTable']=choices,
    ['/Script/Engine.Default__KismetTextLibrary']=object({PolyglotDataToText=function(_,d)
        local native=assert(d.NativeString)
        assert(d.Namespace=='' and d.NativeCulture=='ko' and d.CachedText and d.Category==0)
        registered[d.Key]=d.LocalizedStrings[require('nightop.roxanne_text').culture(culture)] or native
        return text_of(registered[d.Key])
    end}),
    ['/Script/Engine.Default__KismetStringLibrary']=object({Len=function(_,s) return utf8.len(s) end}),
    ['/Script/Engine.Default__KismetInternationalizationLibrary']=object({GetCurrentLanguage=function()
        return culture end}),
    ['/Script/SB.SBSequencerInteractionSelectWidget']=object({}),
    ['/Script/UMG.Default__WidgetBlueprintLibrary']=object({GetAllWidgetsOfClass=function(_,ctx,out,cls,top)
        lookups=lookups+1
        assert(ctx and cls and top==false)
        for k,w in ipairs(shown) do out[k]=w end
    end}),
}
StaticFindObject=function(path) return objects[path] end
FindAllOf=function(name) error('FindAllOf '..name..' walks every object') end
local XION,WASTE='World /Game/Art/BG/WorldMap/Level_P/E04.E04','World /Game/Art/BG/WorldMap/Level_P/F01.F01'
local world=XION
local eve=object({GetWorld=function() return {GetFullName=function() return world end} end})
package.loaded['nightop.probe']={her=function() return eve end,controller=function() return nil end}
package.loaded.UEHelpers={}
local Roxanne=require('nightop.roxanne')
local T=require('nightop.roxanne_text')

-- The text: every culture the game ships has the four lines, the keys name their rows' Korean sources.
local R=require('nightop.recruiter_text')
for name in pairs(R.TEXT) do
    local t=assert(T.TEXT[name],name)
    for _,line in ipairs({'E','N','H','S'}) do assert(type(t[line])=='string' and t[line]~='',name..' '..line) end
end
for name in pairs(T.TEXT) do assert(R.TEXT[name],name..': not a game culture') end
local sources={['1번 선택']='E',['2번 선택']='N',['3번 선택']='H',['루프 선택지']='S'}
local n=0
for key,v in pairs(T.KEYS) do
    n=n+1
    assert(sources[v[2]]==v[1],key)
    local found=false
    for _,r in pairs(rows) do found=found or r.key==key end
    assert(found,key..': no row')
end
assert(n==4 and T.culture('fr-FR')=='fr' and T.culture('pt-BR')=='pt-BR')
assert(Roxanne.row_of(T.TEXT.fr.H).level=='hard' and Roxanne.row_of(T.TEXT.ja.S).shop
    and Roxanne.row_of('Boutique')==nil)

-- The flow.
local logs,asked,told,starts,shops={},{},{},{},0
local status_text,paused='',false
local start_answer={true,'Night Operation (hard) starts in 5 s (run 0x01)'}
local rox=Roxanne.new({log=function(m) logs[#logs+1]=m end,status=function() return status_text end,
    ask=function(line) asked[#asked+1]=line; return true,'asked the native part: '..line end,
    paused=function() return paused end,
    tell=function(build) told[#told+1]=build({night={booked='B',host_only='H',shop_failed='F'}}) end,
    start=function(level) starts[#starts+1]=level; return table.unpack(start_answer) end,
    shop=function() shops=shops+1; return true,'Night Operation shop: 3 points as Beta Seeds' end})
local function last() return logs[#logs] end
local function at(t) clock=t end
local function exec(name) return rows[name].InteractionGraphExec:ToString() end
local function task(name) return rows[name].NextTaskTagName:ToString() end
-- Not on a co-op save, or no roxanne line: nothing read.
status_text='mod=v\nslot=main index=0\nroxanne=unread asks=0 want=off why=none\n'
rox.tick()
status_text='mod=v\nslot=coop index=4\n'
rox.tick()
assert(reads==0 and #asked==0 and #logs==0,'Nothing on another save or with an older native part')
-- Out of Xion: nothing either.
world=WASTE
status_text='mod=v\nslot=coop index=4\nroxanne=unread asks=0 want=off why=none\n'
rox.tick()
assert(reads==0 and #asked==0,'Not in Xion')
-- In Xion: the text, the four rows, then roxanne on.
world=XION
rox.tick()
assert(logs[1]:find('^roxanne text: game language fr%-FR %-> fr; 4/4 keys registered, each reads its fr line, and so '
    ..'do rows Temp_TS_Select_Test_1 to _3 and TS_GoToTest_1: TEXT=yes$'),logs[1])
for name in pairs(rows) do assert(exec(name)=='Success2' and task(name)=='None',name) end
assert(#asked==1 and asked[1]=='roxanne on' and last()=='roxanne: 4 rows read back as ours; asked the native part: '
    ..'roxanne on',last())
assert(registered.C8A59F404A1B66555B5265ACCF31FCFD=='Opération nocturne (facile)')
rox.tick(); assert(#asked==1,'Once a Lua load')
-- The native part reads off for 10 s: asked again.
status_text='mod=v\nslot=coop index=4\nroxanne=off asks=1 want=on why=busy\n'
at(105); rox.tick(); assert(#asked==1)
at(110.5); rox.tick()
assert(#asked==2 and asked[2]=='roxanne on'
    and last():find('reads off asks=1 want=on why=busy: roxanne on asked again'))
-- On: the widget looked for at each tick through the lookup, a pick only when SelectIndex turns from -1 to a line of
-- ours.
status_text='mod=v\nslot=coop index=4\nlink=none lobby=0\nroxanne=on asks=2 want=on why=none\n'
widget.SelectIndex=1 -- Seen first on a line: an old pick, nothing.
lines_of(T.TEXT.fr.E,T.TEXT.fr.N,T.TEXT.fr.H,T.TEXT.fr.S,'Boutique','Mettre fin')
at(111); rox.tick()
assert(lookups==1 and #told==0)
widget.SelectIndex=-1
at(111.25); rox.tick()
widget.SelectIndex=4 -- Her own Shop.
at(111.5); rox.tick()
assert(#told==0 and lookups==3,'Her Shop does nothing')
widget.SelectIndex=-1; at(112); rox.tick()
widget.SelectIndex=2 -- Night Operation (Hard).
at(112.25); rox.tick()
assert(told[1]=='B' and last()=='roxanne: hard booked: it starts once EVE is out of Xion with no one within 40 m',
    last())
-- In Xion, no start; out of it, coop nightop start hard, its refusal said once, then its start.
at(113); rox.tick(); assert(#starts==0)
world=WASTE
start_answer={false,'census: 2 living within 40 m: go where no one is within 40 m'}
at(118); rox.tick()
at(123); rox.tick()
assert(#starts==2 and starts[1]=='hard' and last():find('^roxanne: the booked hard run waits: census'),last())
local said=#logs
at(124); rox.tick(); assert(#starts==2,'Every 5 s')
at(128.5); rox.tick(); assert(#starts==3 and #logs==said,'The same refusal said once')
start_answer={true,'Night Operation (hard) starts in 5 s (run 0x01)'}
paused=true
at(134); rox.tick(); assert(#starts==3,'Not while the game is paused')
paused=false
at(139); rox.tick()
assert(#starts==4 and last()=='roxanne: the booked hard run: Night Operation (hard) starts in 5 s (run 0x01)',last())
at(150); rox.tick(); assert(#starts==4,'Started: no booking left')
-- The supplies: the shop's screen 5 s after the pick, once the game plays.
world=XION
widget.SelectIndex=-1; at(151); rox.tick()
widget.SelectIndex=3; at(151.25); rox.tick()
assert(last()=='roxanne: supplies picked: the shop screen opens in 5 s',last())
at(155); rox.tick(); assert(shops==0)
paused=true
at(156.5); rox.tick(); assert(shops==0,'Not while a screen shows')
paused=false
at(157); rox.tick()
assert(shops==1 and last()=='roxanne: supplies: Night Operation shop: 3 points as Beta Seeds',last())
-- A box built for a later dialogue while the first is still valid: watched from the next tick, its pick read, while
-- the first, still on its last line, picks nothing.
local box=object({SelectIndex=-1,DataArray=widget.DataArray,GetAddress=function() return 0x2000 end})
shown={widget,box}
at(158); rox.tick()
box.SelectIndex=0; at(158.25); rox.tick()
assert(told[#told]=='B' and last()=='roxanne: easy booked: it starts once EVE is out of Xion with no one within 40 m',
    last())
assert(rox.cancel()=='easy')
shown={widget}
-- A guest's pick: the host starts a co-op run.
status_text='mod=v\nslot=coop index=4\nlink=guest lobby=7\nroxanne=on asks=2 want=on why=none\n'
widget.SelectIndex=-1; at(160); rox.tick()
widget.SelectIndex=0; at(160.25); rox.tick()
assert(told[#told]=='H' and rox.cancel()==nil,'No booking for a guest')
-- cancel: the booking dropped.
status_text='mod=v\nslot=coop index=4\nlink=none lobby=0\nroxanne=on asks=2 want=on why=none\n'
widget.SelectIndex=-1; at(161); rox.tick()
widget.SelectIndex=1; at(161.25); rox.tick()
assert(rox.cancel()=='normal' and rox.cancel()==nil)
-- A host's booking (a co-op session): the start only asks the partner, so the booking holds while the run asks, is
-- tried again 30 s after an ask the partner could not join, and goes once the run counts down.
local run_phase,host_starts=nil,0
local host=Roxanne.new({log=function(m) logs[#logs+1]=m end,status=function() return status_text end,
    ask=function(line) asked[#asked+1]=line; return true,'asked' end,paused=function() return false end,
    tell=function() end,shop=function() end,phase=function() return run_phase end,
    start=function()
        host_starts,run_phase=host_starts+1,'ask'
        return true,'Night Operation (hard): waiting for Guest to join (run 0x02)'
    end})
status_text='mod=v\nslot=coop index=4\nlink=host lobby=7\nroxanne=on asks=2 want=on why=none\n'
widget.SelectIndex=-1; at(1000); host.tick()
widget.SelectIndex=2; at(1000.25); host.tick()
assert(last()=='roxanne: hard booked: it starts once EVE is out of Xion with no one within 40 m',last())
world=WASTE
at(1006); host.tick()
assert(host_starts==1 and last()=='roxanne: the booked hard run: Night Operation (hard): waiting for Guest to join '
    ..'(run 0x02)',last())
at(1011); host.tick(); assert(host_starts==1,'No new ask while the run asks')
run_phase=nil -- The guest answered map: the host's run dropped its ask.
at(1016); host.tick()
assert(host_starts==1 and last()=='roxanne: the booked hard run: the partner did not join; asked again in 30 s',last())
at(1041); host.tick(); assert(host_starts==1,'Not before 30 s')
at(1046.5); host.tick(); assert(host_starts==2,'Asked again')
run_phase='countdown'
at(1052); host.tick()
assert(last()=='roxanne: the booked hard run: the partner joined' and host.cancel()==nil,last())
world=XION
status_text='mod=v\nslot=coop index=4\nlink=none lobby=0\nroxanne=on asks=2 want=on why=none\n'
-- A start or a shop open that raises: its refusal, logged, and the tick goes on.
start_answer=nil
local raising=Roxanne.new({log=function(m) logs[#logs+1]=m end,status=function() return status_text end,
    ask=function() return true,'asked' end,paused=function() return false end,
    start=function() error('nightop.lua:12: no census',0) end,shop=function() error('shop.lua:3: no wallet',0) end})
widget.SelectIndex=-1; at(162); raising.tick()
widget.SelectIndex=3; at(162.25); raising.tick()
at(168); raising.tick()
assert(last()=='roxanne: supplies: STOP: no wallet',last())
widget.SelectIndex=-1; at(169); raising.tick()
widget.SelectIndex=0; at(169.25); raising.tick()
world=WASTE
at(174.5); raising.tick()
assert(last()=='roxanne: the booked easy run waits: no census',last())
world=XION
start_answer={true,'Night Operation (hard) starts in 5 s (run 0x01)'}
-- Another save: roxanne off asked; the rows stay ours while her list reads on (her entry may still list them), off is
-- asked again every 10 s meanwhile, and they go back once it reads off.
status_text='mod=v\nslot=main index=0\nroxanne=on asks=2 want=on why=none\n'
local offs=#asked
at(171); rox.tick()
assert(asked[#asked]=='roxanne off' and last()=='roxanne off (not a co-op save): asked the native part: roxanne off; '
    ..'the 4 rows go back once her list reads off',last())
assert(exec('Temp_TS_Select_Test_2')=='Success2','Ours while her list reads on')
at(175); rox.tick(); assert(#asked==offs+1 and exec('Temp_TS_Select_Test_2')=='Success2')
status_text='mod=v\nslot=main index=0\nroxanne=on asks=3 want=off why=gate\n' -- The gate stayed shut.
at(181.5); rox.tick(); assert(#asked==offs+2 and asked[#asked]=='roxanne off','Asked again')
status_text='mod=v\nslot=main index=0\nroxanne=off asks=4 want=off why=none\n'
at(182); rox.tick()
assert(last()=='roxanne: her two choices back, the 4 rows shipped' and #asked==offs+2,last())
assert(exec('Temp_TS_Select_Test_2')=='None' and task('Temp_TS_Select_Test_2')=='A2'
    and exec('TS_GoToTest_1')=='Success' and task('TS_GoToTest_1')=='None')
said=#logs
at(183); rox.tick(); assert(#logs==said and #asked==offs+2,'Once')
-- Back on a co-op save in Xion: on again; coop off asks off, then tick(true) puts the rows back once her list reads
-- off.
status_text='mod=v\nslot=coop index=4\nroxanne=off asks=4 want=off why=none\n'
rox.tick()
assert(asked[#asked]=='roxanne on' and exec('Temp_TS_Select_Test_1')=='Success2')
status_text='mod=v\nslot=coop index=4\nroxanne=on asks=5 want=on why=none\n'
rox.stop()
assert(asked[#asked]=='roxanne off' and exec('Temp_TS_Select_Test_1')=='Success2'
    and last():find('^roxanne off %(coop off%)'))
offs=#asked
at(184); rox.tick(true); assert(#asked==offs and exec('Temp_TS_Select_Test_1')=='Success2','No arm after coop off')
status_text='mod=v\nslot=coop index=4\nroxanne=on asks=6 want=off why=gate\n'
at(194.5); rox.tick(true); assert(#asked==offs+1 and asked[#asked]=='roxanne off','Asked again after coop off')
status_text='mod=v\nslot=coop index=4\nroxanne=off asks=7 want=off why=none\n'
at(195); rox.tick(true)
assert(exec('Temp_TS_Select_Test_1')=='None' and last()=='roxanne: her two choices back, the 4 rows shipped')
-- A fault: the rows stay ours (their exec only plays her goodbye), nothing asked again.
status_text='mod=v\nslot=coop index=4\nroxanne=off asks=7 want=off why=none\n'
local again=Roxanne.new({log=function(m) logs[#logs+1]=m end,status=function() return status_text end,
    ask=function(line) asked[#asked+1]=line; return true,'asked' end,paused=function() return false end,
    start=function() end,shop=function() end})
again.tick()
assert(asked[#asked]=='roxanne on' and exec('Temp_TS_Select_Test_1')=='Success2')
status_text='mod=v\nslot=main index=0\nroxanne=fault asks=8 where=SB-Win64-Shipping.exe+0x1702300\n'
offs=#asked
at(200); again.tick(); at(215); again.tick(); at(230); again.tick()
assert(#asked==offs+1 and exec('Temp_TS_Select_Test_1')=='Success2','After a fault: one off, the rows ours')
ship()
-- A row that is not the one known: nothing written, nothing asked, no retry this Lua load.
rows.Temp_TS_Select_Test_3.NextTaskTagName=FName('B9')
local other=Roxanne.new({log=function(m) logs[#logs+1]=m end,status=function() return status_text end,
    ask=function(line) asked[#asked+1]=line; return true end,paused=function() return false end,
    start=function() end,shop=function() end})
status_text='mod=v\nslot=coop index=4\nroxanne=off asks=4 want=off why=none\n'
local before=#asked
other.tick()
assert(#asked==before and last():find('^STOP: roxanne: Temp_TS_Select_Test_3 is not the row we know at '
    ..'NextTaskTagName %(#%d+%): no Night Operation choices %(2/4 rows edited, put back%)$'),last())
assert(exec('Temp_TS_Select_Test_1')=='None' and exec('Temp_TS_Select_Test_2')=='None','Put back')
said=#logs
other.tick(); assert(#logs==said and #asked==before,'No retry')
-- An arm that raises (here its request): STOP once, the rows put back, no retry this Lua load.
ship()
local tries=0
local lost=Roxanne.new({log=function(m) logs[#logs+1]=m end,status=function() return status_text end,
    ask=function() tries=tries+1; error('link.lua:5: closed',0) end,paused=function() return false end,
    start=function() end,shop=function() end})
lost.tick()
assert(tries==1 and last()=='STOP: roxanne: closed (the 4 rows put back)',last())
assert(exec('Temp_TS_Select_Test_1')=='None' and task('Temp_TS_Select_Test_3')=='A3')
said=#logs
lost.tick(); assert(#logs==said and tries==1,'No retry')
print('nightop_roxanne_test ok')
