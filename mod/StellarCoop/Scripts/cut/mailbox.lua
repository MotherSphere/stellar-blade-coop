-- coop gift: SB's cut in-game mailbox brought back as a co-op gift box, on a co-op save on both sides. A linked friend
-- sends you consumables from her inventory, they wait in your mailbox, and you take them when you want.
-- What SB kept of its mailbox: the widgets WB_MailBox_Set, _Detail, _ListSlot and _Toast_GetGift, their textures,
-- BP_MailBoxItemData, the sound UI_MailBox_GetGift and MailBoxGiftTable's two rows (they enable a mailbox on an actor
-- of an uncooked test map only). Its UI logic (ESBUILogicType_MailBox, FUN_141ef3850 and its handlers) is still
-- compiled in, unlike the Load Shortcut menu's load call, but it lists MailBoxGiftTable rows only, and taking one
-- grants that row's EventGiftTable gift through SB's event-gift path (FUN_141cfd8e0, then FUN_141cfde20 per item) and
-- adds its alias to the game data's received-gift list (+0x848), which the save most likely keeps
-- (FSBSaveGameData_EventGiftInfo.GiftList). That is a second grant path and a write of mod data into the save, so this
-- file does not feed it. It shows the cut toast (WB_MailBox_Toast_GetGift; its In animation calls its Toast In Play
-- Sound) when a gift arrives and keeps the rest on the console:
--   coop gift: what waits in your mailbox, what you sent that waits for an answer, and the items you can send;
--   coop gift send <item> [count]: 1 to 10 of one of ITEMS (its number or its alias) to the linked friend;
--   coop gift take [n]: every gift that waits, or the nth.
-- A send: the native part reads how many she carries (its items request, game/items.h, answered in the engine line's
-- items=); the game's own remove request takes them out (ServerRequest_ItemBucketItemRemove, FUN_1423ba230, which
-- queues SB's remove by alias for its logic thread: asked for more than she has, that remove takes what there is, so
-- the count comes first); the native part reads again until the count fell by the gift's (SETTLE s of play at most:
-- SB's logic, and its remove with it, stops while the game is paused or in photo mode, so that time does not count;
-- else nothing is sent and the items may be gone); the gift goes into the file, then its line ("s <id> <alias>
-- <count>", link/protocol.h's gift line).
-- Her game answers "a <id>" (kept in her mailbox) or "n <id> <why>": slot (not on a co-op save), full (BOX gifts wait
-- already), item (not one of ITEMS), store (her file cannot be read or written). A refusal, no answer in WAIT s, a
-- friend who left the lobby (not one whose link is lost and coming back), or a line the native part could not send
-- ("n <id> nolink") gives the items back through the shop's grant (nightop/shop.lua's Shop.add), at the first moment
-- EVE is in the world and the game plays. Until her answer the line goes again every AGAIN s with the same id. Her game
-- keeps each gift's key (her friend's SteamID and the id) in the mailbox and, once taken or refused, among the last
-- KEEP keys, so a line that comes again never makes a second gift: it gets the first answer again.
-- ponytail: when her answer is lost with the link right after her game kept the gift, the sender's items come back
-- and she keeps the gift too. The window is the reliable line in flight as the friend leaves, or while a lost link
-- outlasts WAIT s; a two-step commit (her gift held until the sender confirms) is the upgrade if a test shows it.
-- ITEMS are consumables only: the two potions, the Biotic Field Generator and the four grenades, all with SaveType Save
-- in ItemTable. No key, story, quest or equipment item; not the Tumbler (Recovery_HP_Potion, whose charges are stats);
-- not drone ammo (SaveType None: the game does not keep it as these items); not the cut stimpacks, whose rows only
-- the shop adds. Their AchievementTable rows (Acquire_Item_Grenade, Ach_Reward_Acquire_Item_ConcussionGrenade and the
-- two category guides) lead to no trophy (docs/how-it-works.md, Achievements: nothing here moves progress).
-- The file, per SteamID and co-op slot like the shop's wallet: coop-gift-<steamid>-<index>.txt beside the mod, one
-- entry a line, written whole through link.write_file:
--   out <id> <alias> <count> <to> <at> <sent>   sent, waiting for her answer (to: her SteamID, 0 in the loopback; at
--                                               and sent: os.time() of the first and the last send)
--   back <id> <alias> <count>                   coming back at the next chance
--   box <id> <alias> <count> <from> <at> <name> in our mailbox (name: hers as the link showed it, last as it may hold
--                                               spaces)
--   seen <from> <id> <a|n>                      taken (a) or refused (n)
-- Called here: the player controller's ItemBucketItemRemove request (a send) and its ItemBucketItemAdd request through
-- Shop.add (a take, or a gift coming back), both on bucket type 1 (the inventory), EVE's GUID, an alias of ITEMS and 1
-- to 10 items. Never called here: a save, a consume, an equip, a quest or achievement call, the game's own mailbox
-- logic.
local Shop=require('nightop.shop')
local N=require('nightop.probe')
local U=require('core.unreal')
local Mailbox={}
Mailbox.ITEMS={'HP_Potion','HP_Potion_Small','HealGrenade','PulseGrenade','ConcussionGrenade','TrapGrenade',
    'FlashGrenade'}
Mailbox.MOST=Shop.MOST -- Items in one gift: link/protocol.h's kMaxGiftCount.
Mailbox.BOX,Mailbox.KEEP=20,64
-- Seconds: her answer at most; between two sends of one gift; the game's remove at most, time paused not counted;
-- between two reads after it; the native part's answer to a read at most; the toast on screen; between two tries of a
-- gift coming back that failed.
Mailbox.WAIT,Mailbox.AGAIN,Mailbox.SETTLE,Mailbox.POLL,Mailbox.READ,Mailbox.TOAST,Mailbox.RETRY=60,10,10,0.5,5,4,10
local MASK=0xFFFFFFFF
local USE='Use: coop gift [send <item> [count 1-'..Mailbox.MOST..']|take [n]]'
local TOAST='/Game/Art/UI/Widget/GameMenu/MailBox/WB_MailBox_Toast_GetGift.WB_MailBox_Toast_GetGift_C'
local WIDGETS='/Script/UMG.Default__WidgetBlueprintLibrary'
local TOAST_Z=40
local listed={}
for i,alias in ipairs(Mailbox.ITEMS) do listed[alias]=i end
local function why(e) return (tostring(e):gsub('^.-:%d+: ','')) end -- Without the file and line.
local function whole(text) return type(text)=='string' and text:match('^%d+$') and math.tointeger(tonumber(text)) end
-- An id as link/protocol.h's gift_ok() takes it: 1 to 20 digits, not 0.
local function id_ok(id) return #id<=20 and id:match('[1-9]')~=nil end
-- Her line's payload as {kind='s', id=, alias=, count=}, {kind='a', id=} or {kind='n', id=, why=}, or nil.
function Mailbox.parse(payload)
    local id,alias,count=payload:match('^s (%d+) ([%w_]+) (%d+)$')
    count=count and math.tointeger(tonumber(count))
    if id then
        return id_ok(id) and count and count>=1 and count<=Mailbox.MOST and {kind='s',id=id,alias=alias,count=count}
            or nil
    end
    id=payload:match('^a (%d+)$')
    if id then return id_ok(id) and {kind='a',id=id} or nil end
    local word
    id,word=payload:match('^n (%d+) (%l+)$')
    if id and id_ok(id) and #word<=16 then return {kind='n',id=id,why=word} end
end
-- The file's text as its four lists, oldest first; a line in no known shape, or with an item or count a gift never
-- holds, is dropped (counted in bad).
function Mailbox.read(text)
    local st={out={},back={},box={},seen={},bad=0}
    for line in (text or ''):gmatch('[^\r\n]+') do
        local item,n=line:match('^%a+ %d+ ([%w_]+) (%d+)')
        n=tonumber(n)
        if item and not (listed[item] and n>=1 and n<=Mailbox.MOST) then line='' end
        local id,alias,count,to,at,sent=line:match('^out (%d+) ([%w_]+) (%d+) (%d+) (%d+) (%d+)$')
        local from,name,answer
        if id then
            st.out[#st.out+1]={id=id,alias=alias,count=tonumber(count),to=to,at=tonumber(at),sent=tonumber(sent)}
        else
            id,alias,count=line:match('^back (%d+) ([%w_]+) (%d+)$')
            if id then st.back[#st.back+1]={id=id,alias=alias,count=tonumber(count)} else
                id,alias,count,from,at,name=line:match('^box (%d+) ([%w_]+) (%d+) (%d+) (%d+) ?(.*)$')
                if id then
                    st.box[#st.box+1]={id=id,alias=alias,count=tonumber(count),from=from,at=tonumber(at),name=name}
                else
                    from,id,answer=line:match('^seen (%d+) (%d+) ([an])$')
                    if from then st.seen[#st.seen+1]={from=from,id=id,answer=answer} else st.bad=st.bad+1 end
                end
            end
        end
    end
    return st
end
function Mailbox.write(st)
    local lines={}
    for _,e in ipairs(st.out) do
        lines[#lines+1]=string.format('out %s %s %d %s %d %d',e.id,e.alias,e.count,e.to,e.at,e.sent)
    end
    for _,e in ipairs(st.back) do lines[#lines+1]=string.format('back %s %s %d',e.id,e.alias,e.count) end
    for _,e in ipairs(st.box) do
        lines[#lines+1]=string.format('box %s %s %d %s %d %s',e.id,e.alias,e.count,e.from,e.at,e.name)
    end
    for i=math.max(1,#st.seen-Mailbox.KEEP+1),#st.seen do
        local e=st.seen[i]
        lines[#lines+1]=string.format('seen %s %s %s',e.from,e.id,e.answer)
    end
    return #lines>0 and table.concat(lines,'\n')..'\n' or ''
end
-- The one remove call: SB's own request, bucket type 1, EVE's GUID, an alias of ITEMS, 1 to MOST items, no pocket (-1,
-- as SB's request pool sets it, FUN_141b48810).
function Mailbox.remove(pc,guid,alias,count)
    assert(listed[alias],'not a gift item')
    assert(math.type(count)=='integer' and count>=1 and count<=Mailbox.MOST,'not a count')
    assert(math.type(guid)=='integer' and guid>0 and guid<=MASK,'not a GUID')
    pc:ServerRequest_ItemBucketItemRemove(1,guid,FName(alias),count,-1)
end
-- The cut toast on screen with text as its title, through UMG's own Create on SB's player controller: a function that
-- takes it off and the widget's object path, false with no controller (a load), or nil and why. Its class is loaded
-- the first time a gift arrives (LoadAsset, synchronous).
function Mailbox.toast(text)
    local class=U.valid(StaticFindObject(TOAST))
    if not class then
        pcall(LoadAsset,TOAST:sub(1,-3))
        class=U.valid(StaticFindObject(TOAST))
    end
    if not class then return nil,'the toast widget is not in this game build' end
    local pc=N.controller()
    if not pc then return false end -- A load under way: no toast this time.
    local w=U.valid(U.find(WIDGETS):Create(pc,class,pc))
    if not w then return nil,'the toast was not created' end
    w.Text_Title:SetText(FText(text))
    w:AddToViewport(TOAST_Z)
    w:Play()
    return function() if U.valid(w) then w:RemoveFromParent() end end,U.text(w:GetFullName()):match('^%S+ (.+)$')
end
-- A toast an earlier Lua load left on screen, by its object path: taken off. True when it was there. The widget has
-- no removal of its own (its graph plays the In animation and the sound only), so only a Lua load takes it off.
function Mailbox.sweep(path)
    local w=U.valid(StaticFindObject(path))
    if not (w and U.text(w:GetFullName()):find('^WB_MailBox_Toast_GetGift_C ') and w:IsInViewport()) then
        return false
    end
    w:RemoveFromParent()
    return true
end
-- o: log(text) writes a [GF] line; say(text) puts a notice on screen; status() is the native part's status text;
-- request(line) asks the native part (link.request); read(name) and write(name, text) are link.read_file and
-- link.write_file; friend() is link.friend (her name, linked, lost); loopback() whether coop loopback runs; paused()
-- whether the game is paused (photo mode included, ours or the friend's that pauses ours) or shows one of its screens;
-- name(alias) the FName this game holds for an alias, {index=, number=}, or nil; clock() seconds (os.clock); now()
-- whole seconds that survive a reload (os.time); toast(text) Mailbox.toast unless given; store (coop-gift-toast.txt
-- through link.store) keeps the toast's path while it is up, so the next Lua load's first tick takes it off through
-- sweep(path), Mailbox.sweep unless given.
function Mailbox.new(o)
    local log,say,status,request,read,write=o.log,o.say,o.status,o.request,o.read,o.write
    local friend,loopback,paused,name_of=o.friend,o.loopback,o.paused,o.name
    local clock,now,toast,sweep=o.clock or os.clock,o.now or os.time,o.toast or Mailbox.toast,o.sweep or Mailbox.sweep
    local store=o.store or {save=function() end,load=function() end,clear=function() end}
    local self={}
    local sending=nil -- A send under way (Lua memory only: nothing has left the inventory before its remove).
    local pending,last_file=true,nil -- out or back entries may wait in the file named last_file.
    local tried={} -- A gift coming back whose grant raised: when, by id, so it is tried again after RETRY s only.
    local untoast,toast_until,toast_off,swept=nil,nil,false,false
    local asks,seq=0,math.random(0,999)
    local function engine(raw) return ('\n'..(raw or '')):match('\nengine=([^\r\n]*)') or '' end
    -- The next ask's number, never the one the engine line answers now: that answer may be an earlier Lua load's, so
    -- an answer that comes with the new number is always the new read's.
    local function next_ask(raw)
        local shown=math.tointeger(tonumber(engine(raw):match(' items=(%d+) ')))
        repeat asks=asks%65535+1 until asks~=shown
        return asks
    end
    local function new_id() seq=(seq+1)%1000; return string.format('%d%03d',now(),seq) end
    local function peer(raw) return ('\n'..(raw or '')):match('\npeer=(%d+) ') end
    -- This player's file on this co-op save, or nil and a refusal word: slot (no co-op save), store (no SteamID yet).
    local function where(raw)
        raw='\n'..(raw or '')
        local index=raw:match('\nslot=coop index=(%d+)')
        if not index then return nil,'slot' end
        local id=raw:match('\nmod=[^\r\n]* steamid=([1-9]%d*)')
        if not id then return nil,'store' end
        return 'coop-gift-'..id..'-'..index..'.txt'
    end
    -- The file's lists (st.name its name), or nil, a refusal word and why. No file reads as empty; with none, its .tmp:
    -- the newest text when link.write_file removed the file and then failed to rename the .tmp over it.
    local function load(raw)
        local name,word=where(raw or status())
        if not name then return nil,word,word=='slot' and 'not on a co-op save' or 'the Steam link is not ready yet' end
        local text,e,code=read(name)
        if not text and (code or 2)==2 then text,e,code=read(name..'.tmp') end
        if not text and (code or 2)~=2 then return nil,'store','the gift file was not read: '..tostring(e) end
        local st=Mailbox.read(text)
        if st.bad>0 then log(string.format('%s: %d line(s) in no known shape dropped',name,st.bad)) end
        st.name=name
        return st
    end
    -- Written, or left as its .tmp (link.write_file's third value), which counts once the file itself is gone: load()
    -- then reads the .tmp. With the old file still there, its text stands and the save failed.
    local function save(st)
        local ok,e,beside=write(st.name,Mailbox.write(st))
        if not ok and beside then
            local text,_,code=read(st.name)
            ok=not text and (code or 2)==2
            if ok then log('gift file left as its .tmp: '..tostring(e)) end
        end
        if not ok then log('gift file not written: '..tostring(e)) end
        pending=#st.out>0 or #st.back>0
        return ok,e
    end
    -- What a call into the inventory needs: the game playing, EVE with her GUID, her controller. Returns them, or nil
    -- and why.
    local function ready()
        if paused() then return nil,'the game is paused or shows one of its screens' end
        local eve,pc=N.her(),N.controller()
        if not eve then return nil,'no EVE in the world' end
        if not pc then return nil,'no SB player controller' end
        local guid=Shop.guid(eve,pc,status())
        if not guid then return nil,"EVE's ActorGuid reads 0" end
        return {pc=pc,guid=guid}
    end
    local function unshow()
        if not untoast then return end
        pcall(untoast)
        untoast=nil
        store.clear()
    end
    local function show(text)
        if toast_off then return end
        unshow()
        local ok,off,e=pcall(toast,text)
        if ok and off then
            untoast,toast_until=off,clock()+Mailbox.TOAST
            if e then store.save(e) end
            return
        end
        if ok and off==false then return end -- No controller now: the next gift tries again.
        toast_off=true -- The first failure: no toast for this Lua load.
        log('toast off until the mod reloads: '..why(ok and e or off))
    end
    local function her_name() local name=friend(); return name and name~='' and name or 'your friend' end
    local function linked_to(raw,to)
        if to=='0' then return loopback(),false end
        local _,linked,lost=friend()
        local same=peer(raw)==to
        return same and linked==true,same and lost==true
    end
    -- A send's end before its line: nothing left the inventory, or it was given back, or (said so) a read after the
    -- remove failed.
    local function fail(text)
        log('send stopped: '..text)
        sending=nil
        say('Gift not sent: '..text)
    end
    -- The items gone from the inventory: into the file, then the line. Written first, so a gift that left always has
    -- its entry; a file that cannot be written gives the items back at once.
    local function dispatch(s)
        local st,_,e=load()
        local id=new_id()
        if st then
            st.out[#st.out+1]={id=id,alias=s.alias,count=s.count,to=s.to,at=now(),sent=now()}
            local ok,se=save(st)
            if ok then
                sending=nil
                request(string.format('gift s %s %s %d',id,s.alias,s.count))
                log(string.format('sent %s: %s x%d to %s (had %d)',id,s.alias,s.count,s.to,s.before))
                say(string.format('Gift sent: %d %s. It waits for your friend\'s answer.',s.count,s.alias))
                return
            end
            e='the gift file was not written: '..tostring(se)
        end
        local r=ready()
        local back=r and pcall(Shop.add,r.pc,r.guid,s.alias,s.count)
        log(string.format('send %s stopped after the remove: %s; the items %s',id,tostring(e),back and 'came back'
            or 'could not be given back'))
        sending=nil
        say(string.format('Gift not sent: %s. %s',tostring(e),back and 'The items came back.'
            or 'The items could not be given back: see UE4SS.log.'))
    end
    -- A send under way, each tick: the native part's reads and the game's remove. After the remove, a read that fails
    -- sends nothing: with no proof the items left, a gift could make items out of none, so a lost gift is the risk
    -- taken (the log keeps the counts).
    local function step(raw,t)
        local s=sending
        if s.step=='gone' then -- Time paused does not count: SB's logic, which runs the remove, stops with the game.
            if not paused() then s.played=s.played+t-s.last end
            s.last=t
        end
        local line=engine(raw)
        local have,none=line:match(' items='..s.ask..' (%d+)'),line:match(' items='..s.ask..' none (%a+)')
        if not have and not none then
            if t-s.at>Mailbox.READ then
                fail(s.step=='count' and 'the native part did not read the inventory'
                    or 'the native part stopped reading the inventory after the remove (the items may be gone)')
            end
            return
        end
        if none then
            return fail(s.step=='count' and 'your inventory could not be read ('..none..')'
                or 'your inventory could not be read after the remove ('..none..', the items may be gone)')
        end
        have=math.tointeger(tonumber(have))
        if s.step=='count' then
            if have<s.count then return fail(string.format('you carry %d %s',have,s.alias)) end
            local r,e=ready()
            if not r then return fail(e) end
            local called,ce=pcall(Mailbox.remove,r.pc,r.guid,s.alias,s.count)
            if not called then return fail('the game call failed: '..why(ce)) end
            log(string.format('remove asked: %s x%d of %d (guid %d)',s.alias,s.count,have,r.guid))
            s.step,s.before,s.played,s.last,s.next='gone',have,0,t,t+Mailbox.POLL
        elseif have<=s.before-s.count then
            return dispatch(s)
        elseif s.played>=Mailbox.SETTLE then
            return fail(string.format('the count did not fall by %d in %d s of play (%d before, %d now); the items may '
                ..'be gone',s.count,Mailbox.SETTLE,s.before,have))
        end
        if t>=s.next then -- The count has not fallen yet: read again.
            s.ask,s.at,s.next=next_ask(raw),t,t+Mailbox.POLL
            request(string.format('items %d %s %d %d',s.ask,s.alias,s.index,s.number))
        end
    end
    -- The file's waiting entries, each tick while there are some: answers that never came, a friend who left, sends due
    -- again, and gifts coming back.
    local function settle(raw,t)
        local st=load(raw)
        if not st then return end
        local changed,since=false,now()
        for i=#st.out,1,-1 do
            local e=st.out[i]
            local here,lost=linked_to(raw,e.to)
            local gone=since-e.at>=Mailbox.WAIT and 'no answer in '..Mailbox.WAIT..' s'
                or not here and not lost and 'your friend left'
            if gone then
                table.remove(st.out,i)
                st.back[#st.back+1]={id=e.id,alias=e.alias,count=e.count}
                log(string.format('gift %s comes back: %s',e.id,gone))
                changed=true
            elseif here and since-e.sent>=Mailbox.AGAIN then
                e.sent=since
                request(string.format('gift s %s %s %d',e.id,e.alias,e.count))
                log('gift '..e.id..' sent again')
                changed=true
            end
        end
        -- A gift coming back leaves the file before its grant, as a take does: a file that cannot be written gives
        -- nothing, so a gift never comes back twice. A grant that raises puts it back.
        local r=st.back[1] and ready()
        for i=#st.back,1,-1 do
            local e=st.back[i]
            if r and (not tried[e.id] or t-tried[e.id]>=Mailbox.RETRY) then
                table.remove(st.back,i)
                local saved,se=save(st)
                local ok,ge=false,'the gift file was not written ('..tostring(se)..')'
                if saved then
                    changed=false -- The out entries' changes went with it.
                    ok,ge=pcall(Shop.add,r.pc,r.guid,e.alias,e.count)
                    if not ok then ge=why(ge) end
                end
                if ok then
                    tried[e.id]=nil
                    log(string.format('gift %s came back: %s x%d',e.id,e.alias,e.count))
                    say(string.format('Gift returned: %d %s are back in your inventory.',e.count,e.alias))
                else
                    table.insert(st.back,i,e)
                    if saved then changed=true end -- The file lost it: written again below.
                    tried[e.id]=t
                    log(string.format('gift %s could not come back yet: %s',e.id,ge))
                end
            end
        end
        if changed then save(st) else pending=#st.out>0 or #st.back>0 end
    end
    -- Each 250 ms: the toast's end, a send under way, the file's waiting entries (read again when the co-op slot or the
    -- SteamID changed, so a gift sent from another slot comes back once that slot is loaded). The first tick takes off
    -- a toast an earlier Lua load left (a reload within TOAST s of a gift).
    function self.tick()
        local t=clock()
        if not swept then
            swept=true
            local left=store.load()
            if left then
                store.clear()
                local ok,gone=pcall(sweep,left)
                if not ok then log('the toast an earlier Lua load left was not taken off: '..why(gone))
                elseif gone then log('took off the toast an earlier Lua load left') end
            end
        end
        if untoast and t>=toast_until then unshow() end
        local raw=status()
        local file=where(raw)
        if file~=last_file then last_file,pending=file,true end
        if sending then step(raw,t) end
        if pending and file then settle(raw,t) end
    end
    -- coop off: the toast goes. A send between its remove and its entry in the file stops here with its items gone.
    -- ponytail: so does one when Lua reloads in that wait (SETTLE s of play at most); an entry written before the
    -- remove is the upgrade.
    function self.stop()
        sending=nil
        unshow()
    end
    -- Her gift: kept in the mailbox and answered a, or refused with n and why. A key already seen gets its first
    -- answer.
    local function keep(m)
        local function answer(word)
            request(word=='a' and 'gift a '..m.id or 'gift n '..m.id..' '..word)
            log(string.format('gift %s from %s: %s',m.id,her_name(),word=='a' and 'kept' or 'refused ('..word..')'))
        end
        local raw=status()
        local from=peer(raw) or '0'
        if not listed[m.alias] then return answer('item') end
        local st,word=load(raw)
        if not st then return answer(word) end
        for _,e in ipairs(st.box) do if e.from==from and e.id==m.id then return answer('a') end end
        for _,e in ipairs(st.seen) do -- Only a full mailbox's refusal is kept: the others leave no file to keep it in.
            if e.from==from and e.id==m.id then return answer(e.answer=='a' and 'a' or 'full') end
        end
        if #st.box>=Mailbox.BOX then
            st.seen[#st.seen+1]={from=from,id=m.id,answer='n'}
            save(st)
            return answer('full')
        end
        local name=from=='0' and 'you' or her_name()
        st.box[#st.box+1]={id=m.id,alias=m.alias,count=m.count,from=from,at=now(),name=name}
        if not save(st) then return answer('store') end
        answer('a')
        say(string.format('%s sent you %d %s: coop gift take puts them in your inventory.',name,m.count,m.alias))
        show(string.format('%s: %d %s',name,m.count,m.alias))
    end
    -- Her answer to one of ours (or the native part's nolink): kept, or refused and coming back.
    local function answered(m)
        local st=load()
        if not st then return log(string.format('answer %s %s with no gift file here',m.kind,m.id)) end
        for i,e in ipairs(st.out) do
            if e.id==m.id then
                table.remove(st.out,i)
                if m.kind=='a' then
                    log(string.format('gift %s kept by %s: %s x%d',e.id,her_name(),e.alias,e.count))
                    say(string.format('%s got your %d %s.',e.to=='0' and 'You' or her_name(),e.count,e.alias))
                else
                    st.back[#st.back+1]={id=e.id,alias=e.alias,count=e.count}
                    log(string.format('gift %s refused (%s): it comes back',e.id,m.why))
                    say(string.format('Gift refused (%s): the %d %s come back.',m.why,e.count,e.alias))
                end
                save(st)
                return
            end
        end
        log(string.format('answer %s %s for no gift waiting (it may have come back already)',m.kind,m.id))
    end
    -- A gift line of hers, from coop-chat.txt.
    function self.receive(payload)
        local m=Mailbox.parse(payload)
        if not m then return log('gift line in no known shape: '..payload) end
        if m.kind=='s' then return keep(m) end
        answered(m)
    end
    local function list()
        local st,_,e=load()
        if not st then return false,e end
        local parts={}
        for i,b in ipairs(st.box) do parts[#parts+1]=string.format('%d %s x%d from %s',i,b.alias,b.count,b.name) end
        local text='Mailbox: '..(parts[1] and table.concat(parts,', ') or 'empty')
        parts={}
        for _,b in ipairs(st.out) do
            parts[#parts+1]=string.format('%s x%d (%d s)',b.alias,b.count,now()-b.at)
        end
        if parts[1] then text=text..'. Sent, waiting for an answer: '..table.concat(parts,', ') end
        parts={}
        for _,b in ipairs(st.back) do parts[#parts+1]=string.format('%s x%d',b.alias,b.count) end
        if parts[1] then text=text..'. Coming back: '..table.concat(parts,', ') end
        parts={}
        for i,alias in ipairs(Mailbox.ITEMS) do parts[#parts+1]=i..' '..alias end
        return true,text..'. You can send: '..table.concat(parts,', ')..'.'
    end
    local function send(item,count,more)
        local alias=Mailbox.ITEMS[whole(item) or 0]
        if not alias and type(item)=='string' then
            for _,a in ipairs(Mailbox.ITEMS) do if a:lower()==item:lower() then alias=a end end
        end
        local c=count==nil and 1 or whole(count)
        if more~=nil or not alias or not c or c<1 or c>Mailbox.MOST then return false,USE end
        if sending then return false,'a gift is already on its way out: wait for its answer on screen' end
        local raw=status()
        local to=peer(raw)
        local _,linked=friend()
        if not linked or not to then
            if not loopback() then return false,'no friend is linked (coop loopback sends a gift to yourself)' end
            to='0'
        end
        local st,_,e=load(raw)
        if not st then return false,e end
        local r,re=ready()
        if not r then return false,re..': nothing sent' end
        local n=name_of(alias)
        if not n then return false,'this game holds no name '..alias..': nothing sent' end
        local t=clock()
        sending={alias=alias,count=c,to=to,step='count',ask=next_ask(raw),at=t,index=n.index,number=n.number}
        local ok,qe=request(string.format('items %d %s %d %d',sending.ask,alias,n.index,n.number))
        if not ok then sending=nil; return false,'the native part was not asked: '..tostring(qe) end
        return true,string.format('reading how many %s you carry; the gift of %d follows',alias,c)
    end
    local function take(n,more)
        if more~=nil then return false,USE end
        local st,_,e=load()
        if not st then return false,e end
        if not st.box[1] then return false,'your mailbox is empty' end
        local at=n~=nil and whole(n)
        if n~=nil and not (at and at>=1 and at<=#st.box) then
            return false,string.format('coop gift take [1-%d]: %d gift(s) wait',#st.box,#st.box)
        end
        local r,re=ready()
        if not r then return false,re..': nothing taken' end
        local took={}
        for i=at or #st.box,at or 1,-1 do
            local b=table.remove(st.box,i)
            st.seen[#st.seen+1]={from=b.from,id=b.id,answer='a'}
            local saved,se=save(st) -- First: a gift taken never stays in the mailbox to be taken twice.
            if not saved then
                table.insert(st.box,i,b)
                table.remove(st.seen)
                return #took>0,'the gift file was not written ('..tostring(se)..'): '..(#took>0 and 'took '
                    ..table.concat(took,', ')..', the rest wait' or 'nothing taken')
            end
            local called,ce=pcall(Shop.add,r.pc,r.guid,b.alias,b.count)
            if not called then
                table.insert(st.box,i,b)
                table.remove(st.seen)
                save(st)
                log(string.format('take %s failed: %s',b.id,why(ce)))
                return #took>0,'the game call failed ('..why(ce)..'): '..(#took>0 and 'took '
                    ..table.concat(took,', ')..', the rest wait' or 'nothing taken')
            end
            log(string.format('took %s: %s x%d from %s (guid %d)',b.id,b.alias,b.count,b.from,r.guid))
            took[#took+1]=string.format('%d %s from %s',b.count,b.alias,b.name)
        end
        return true,'took '..table.concat(took,', ')
    end
    function self.command(sub,a,b,c)
        if sub==nil then return list() end
        if sub=='send' then return send(a,b,c) end
        if sub=='take' then return take(a,b) end
        return false,USE
    end
    return self
end
return Mailbox
