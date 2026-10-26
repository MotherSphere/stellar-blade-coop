-- Roxanne's Night Operation choices: on a co-op save, once EVE is in Xion, Roxanne's dialogue offers Night Operation
-- (Easy), (Normal) and (Hard) and its supplies above her own Shop and End Conversation. The game ships no such dialogue
-- (her one dormant Night Operation branch only greets a customer who paid in Beta Seeds, and nothing reaches it), so
-- four of the game's test choice rows that no story graph lists carry ours (ROWS): in memory for the game run, each is
-- edited in place through nightop/recruiter.lua's checked edit (InteractionGraphExec Success2, her End Conversation's,
-- so the graph plays one of her goodbyes and ends; NextTaskTagName None), and their four text keys get the labels in
-- the 23 game languages (nightop/roxanne_text.lua, through nightop/recruiter.lua's registration, after its Korean
-- probe). Then the native part points her choice list's entry in SB's select cache at those four and her two
-- (nightop/roxanne.h: roxanne on). A pick is read from the select widget (SBSequencerInteractionSelectWidget, found
-- through the widget library's class lookup, never by walking every object each tick): its SelectIndex turning from
-- -1 to a line, that line's text matched against our labels. A level is booked and starts on its own once EVE is out of
-- Xion with no one within 40 m (Night Operation never starts in Xion: its people and quests stay out of a fight); in a
-- co-op session only the host's pick books. The supplies open the Night Operation shop's screen once her goodbye is
-- over. Everything goes back (roxanne off, the rows' shipped values) on coop off and on a save that is not a co-op
-- save; coop nightop stop drops a booking. No quest, item, achievement, save or story state is touched here: talking
-- to her still runs her own graph as without the mod.
local U=require('core.unreal')
local N=require('nightop.probe')
local R=require('nightop.recruiter')
local Roxanne={}
local CHOICES='/Game/Local/Data/TheaterSelectDataTable.TheaterSelectDataTable'
local XION='/game/art/bg/worldmap/level_p/e04'
local SELECT='/Script/SB.SBSequencerInteractionSelectWidget'
local WIDGETS='/Script/UMG.Default__WidgetBlueprintLibrary'
-- The four rows, in the native part's order (nightop/roxanne.h's kRows): ID, select list, the shipped
-- InteractionGraphExec and NextTaskTagName (put back when off), its line of nightop/roxanne_text.lua and its pick.
Roxanne.ROWS={
    {row='Temp_TS_Select_Test_1',id=14,list='Temp_TS_Select_Test',exec='None',task='A1',line='E',level='easy'},
    {row='Temp_TS_Select_Test_2',id=15,list='Temp_TS_Select_Test',exec='None',task='A2',line='N',level='normal'},
    {row='Temp_TS_Select_Test_3',id=16,list='Temp_TS_Select_Test',exec='None',task='A3',line='H',level='hard'},
    {row='TS_GoToTest_1',id=85,list='TS_GoToTest',exec='Success',task='None',line='S',shop=true},
}
Roxanne.EXEC='Success2'
-- s: after a supplies pick, before the screen opens (her goodbye first; ponytail: a starting value, tune in game); how
-- long a pick waits for the game to play; between two tries at a booked start; between two looks for the widget;
-- between two roxanne on asks while the native part reads off.
Roxanne.SHOP_AFTER,Roxanne.SHOP_WAIT,Roxanne.BOOK_EVERY,Roxanne.FIND_EVERY,Roxanne.ASK_EVERY=5,30,5,2,10
local function why(e) return (tostring(e):gsub('^.-:%d+: ','')) end
-- Every label of roxanne_text.lua, in any language, to its row.
local function labels()
    local by={}
    local data=require('nightop.roxanne_text')
    for _,r in ipairs(Roxanne.ROWS) do
        for _,lines in pairs(data.TEXT) do by[lines[r.line]]=r end
    end
    return by
end
-- The row a picked line's text names, or nil (her own Shop and End, any other dialogue).
function Roxanne.row_of(text,by) return (by or labels())[text] end
-- log(text) writes an [NR] line; status() the native part's status text; ask(line) its request; paused() whether the
-- game is paused or shows one of its screens (the UI kit's); tell(build) a notice; start(level) coop nightop start
-- <level> and shop() coop nightop shop, through commands/nightop.lua (its co-op save and race checks).
function Roxanne.new(o)
    local log,status,ask,paused,tell=o.log,o.status,o.ask,o.paused,o.tell
    local by=nil -- labels(), once the text is registered.
    local armed,failed=false,false -- Rows edited and asked on in this Lua load; an arm that stopped (no retry).
    local asked_at=-math.huge
    local held,look_at,walk=nil,-math.huge,false -- The select widgets {obj, last}; the next look; FindAllOf's route.
    local booked,shop_at=nil,nil -- {level, next, said}; the time the screen opens after a supplies pick.
    local function one(...) return R.one(...) end
    local function index(text) return R.index_of(R.find_name(text)) end
    -- The rows to ours (on) or back to their shipped values: each checked first (its ID, its list, a value of the two),
    -- written and read back. Gives the STOP line or nil.
    local function rows(on)
        local done={}
        for _,r in ipairs(Roxanne.ROWS) do
            local exec,task=on and Roxanne.EXEC or r.exec,on and 'None' or r.task
            local known={{'ID','n',one(r.id)},{'SelectDataName','name',one(index(r.list))},
                {'InteractionGraphExec','name',one(index(r.exec),index(Roxanne.EXEC))},
                {'NextTaskTagName','name',one(index(r.task),0)}}
            local stop=R.edit(CHOICES,r.row,known,{{'InteractionGraphExec','name',FName(exec),index(exec)},
                {'NextTaskTagName','name',FName(task),index(task)}},nil,'Night Operation choices')
            if stop then return stop,done end
            done[#done+1]=r.row
        end
        return nil,done
    end
    local function line_of(raw) return raw:match('\nroxanne=([^\r\n]*)') end
    -- On, once a Lua load: the text, the rows, then the native part's swap. A step that fails puts back what it changed
    -- and stops trying until the next Lua load.
    local function arm()
        local text=R.register('nightop.roxanne_text',{{'Temp_TS_Select_Test_1','E'},{'Temp_TS_Select_Test_2','N'},
            {'Temp_TS_Select_Test_3','H'},{'TS_GoToTest_1','S'}},'rows Temp_TS_Select_Test_1 to _3 and TS_GoToTest_1',
            ': nothing registered, Roxanne keeps her two choices')
        if text:find('^STOP: ') then
            failed=true
            return log('STOP: roxanne '..text:sub(7))
        end
        log('roxanne '..text)
        local stop,done=rows(true)
        if stop then
            failed=true
            log('STOP: roxanne: '..stop..' ('..#done..'/4 rows edited, put back)')
            if #done>0 then pcall(rows,false) end
            return
        end
        by=labels()
        local ok,said=ask('roxanne on')
        log('roxanne: 4 rows read back as ours; '..tostring(said))
        armed,asked_at=ok,os.clock()
        if not ok then failed=true end
    end
    -- Off: the swap back, then the rows' shipped values.
    local function off(reason)
        local raw='\n'..(status() or '')
        if armed or (line_of(raw) or ''):find('^on ') then pcall(ask,'roxanne off') end
        local fine,stop=pcall(rows,false)
        log(string.format('roxanne off (%s): %s',reason,fine and (stop or 'her two choices back, the 4 rows shipped')
            or why(stop)))
        armed,held,shop_at=false,nil,nil
    end
    -- The select widgets of EVE's world: the widget library's lookup (the engine's class hash), or, when that call
    -- fails, FindAllOf (which walks every object) only while the game shows one of its screens.
    local function widgets(eve)
        local list={}
        if not walk then
            local out={}
            local ok,e=pcall(function() U.find(WIDGETS):GetAllWidgetsOfClass(eve,out,U.find(SELECT),false) end)
            if ok then
                U.each(out,function(_,w) w=U.valid(w); if w then list[#list+1]={obj=w} end end)
                return list
            end
            walk=true
            log('roxanne: the widget lookup failed ('..why(e)..'): the select widget is looked for while a game '
                ..'screen shows')
        end
        if not paused() then return list end
        U.each(FindAllOf('WB_Theater_InteractionSelect_Master_C') or {},function(_,w)
            w=U.valid(w)
            if w and not U.text(w:GetFullName()):find('Default__',1,true) then list[#list+1]={obj=w} end
        end)
        return list
    end
    -- A pick: a level booked (or, for a guest, said to be the host's), the supplies' screen due.
    local function picked(r,raw,now)
        if r.shop then
            shop_at=now+Roxanne.SHOP_AFTER
            log('roxanne: supplies picked: the shop screen opens in '..Roxanne.SHOP_AFTER..' s')
            return
        end
        if raw:match('\nlink=(%a+)')=='guest' then
            log('roxanne: '..r.level..' picked as a guest: the host starts a co-op run')
            if tell then tell(function(w) return w.night.host_only end) end
            return
        end
        booked={level=r.level,next=now}
        log('roxanne: '..r.level..' booked: it starts once EVE is out of Xion with no one within 40 m')
        if tell then tell(function(w) return w.night.booked end) end
    end
    -- In Xion with her choices on: each held widget's SelectIndex, a pick when it turns from -1 to a line.
    local function watch(eve,raw,now)
        if not held and now>=look_at then
            look_at=now+Roxanne.FIND_EVERY
            local list=widgets(eve)
            if #list>0 then held=list end
        end
        for _,w in ipairs(held or {}) do
            local ok,i=pcall(function() return U.value_of(w.obj.SelectIndex) end)
            if not ok or not U.valid(w.obj) then held=nil return end
            if w.last and w.last<0 and i>=0 then
                local got,text=pcall(function() return U.text(w.obj.DataArray[i+1].DisplayText) end)
                local r=got and Roxanne.row_of(text,by)
                if r then picked(r,raw,now) end
            end
            w.last=i
        end
    end
    local self={}
    -- Every 250 ms on the game thread (main.lua's loop).
    function self.tick()
        local now=os.clock()
        local raw='\n'..(status() or '')
        local line=line_of(raw)
        if not raw:find('\nslot=coop ') then
            if armed or (line or ''):find('^on ') then off('not a co-op save') end
            booked=nil
            return
        end
        local eve=N.her()
        local here=eve and U.map_of(eve)==XION
        if not armed and not failed and here and line then arm() end
        if armed and (line or ''):find('^off ') and now-asked_at>=Roxanne.ASK_EVERY then
            asked_at=now -- The game rebuilt its cache, or the gate stayed shut: asked again.
            log('roxanne: the native part reads '..line..': roxanne on asked again')
            pcall(ask,'roxanne on')
        end
        if armed and here and (line or ''):find('^on ') then watch(eve,raw,now) end
        if shop_at and now>=shop_at then
            if not paused() then
                shop_at=nil
                local ok,said=o.shop()
                log('roxanne: supplies: '..(ok and '' or 'STOP: ')..tostring(said))
                if not ok and tell then tell(function(w) return w.night.shop_failed end) end
            elseif now>=shop_at+Roxanne.SHOP_WAIT then
                shop_at=nil
                log('STOP: roxanne: supplies: the game stayed paused or on one of its screens')
            end
        end
        if booked and now>=booked.next then
            booked.next=now+Roxanne.BOOK_EVERY
            if eve and not here and not paused() then
                local level=booked.level
                local ok,said=o.start(level)
                if ok then
                    booked=nil
                    log('roxanne: the booked '..level..' run: '..tostring(said))
                elseif said~=booked.said then
                    booked.said=said
                    log('roxanne: the booked '..level..' run waits: '..tostring(said))
                end
            end
        end
    end
    -- coop nightop stop: the booking dropped; its level, or nil when none was booked.
    function self.cancel()
        local level=booked and booked.level
        booked=nil
        return level
    end
    -- coop off: everything back (may raise; main.lua logs it and goes on).
    function self.stop()
        booked=nil
        if armed or ('\n'..(status() or '')):find('\nroxanne=on ') then off('coop off') end
    end
    return self
end
return Roxanne
