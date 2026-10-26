-- coop gift (cut/mailbox.lua) over fakes: the native status (slot, SteamID, peer, the engine line's items=), the gift
-- file in memory, the requests to the native part, the friend and the loopback, EVE and the player controller with its
-- remove and add requests, the clocks and the toast. Covered: the line shapes link/protocol.h takes and the file's;
-- the remove call's five arguments; a send's refusals with nothing asked, its read, the remove, the reads until the
-- count fell, the entry written before its line, and every way it stops with the items still there; her answers (kept,
-- refused, nolink, late); sends again every AGAIN s with the same id, the items coming back after WAIT s, when the
-- friend left (not while her link is lost) or with the loopback gone, through the shop's grant, tried again after
-- RETRY s when it raises; her gifts kept, answered and shown, refused when off a co-op save, unknown, the mailbox full
-- or the file not written, and a key seen before answered as before; take, all or one, written before its grant and put
-- back when the grant raises; the toast's end and its first failure; a gift sent from another co-op slot coming back
-- once that slot loads.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
FName=function(text) return {ToString=function() return text end} end
local removes,adds,remove_raise,add_raise={},{},nil,nil
local pc={ServerRequest_ItemBucketItemRemove=function(_,...)
        removes[#removes+1]=table.pack(...)
        if remove_raise then error(remove_raise) end
    end,
    ServerRequest_ItemBucketItemAdd=function(_,...)
        adds[#adds+1]=table.pack(...)
        if add_raise then error(add_raise) end
    end}
local eve={BroadcastSpawnInfo={ActorGuid=0x51}}
local her,controller=eve,pc
package.loaded['nightop.probe']={her=function() return her end,controller=function() return controller end}
local Mailbox=require('cut.mailbox')
local M=Mailbox

-- 1. Shapes: her lines as link/protocol.h's gift_ok() takes them, the file's lines, the items.
assert(#M.ITEMS==7 and M.ITEMS[1]=='HP_Potion' and M.ITEMS[7]=='FlashGrenade' and M.MOST==10)
for _,alias in ipairs(M.ITEMS) do
    assert(not alias:find('Bullet') and alias~='Recovery_HP_Potion','Consumables only: no ammo, no Tumbler')
end
local p=M.parse('s 1761480000123 HP_Potion 3')
assert(p.kind=='s' and p.id=='1761480000123' and p.alias=='HP_Potion' and p.count==3)
assert(M.parse('a 17').kind=='a' and M.parse('a 17').id=='17')
p=M.parse('n 17 nolink'); assert(p.kind=='n' and p.id=='17' and p.why=='nolink')
for _,bad in ipairs({'s 0 HP_Potion 1','s 1 HP_Potion 0','s 1 HP_Potion 11','s 1 HP-Potion 1','s 1 HP_Potion',
        'a 0','a x','n 1','n 1 Nolink','n 1 abcdefghijklmnopq','x 1','s 123456789012345678901 A 1','a 1 ','',
        's 1  HP_Potion 1'}) do
    assert(M.parse(bad)==nil,bad)
end
local text='out 1761480000123 PulseGrenade 2 99 1000 1010\nback 17 HP_Potion 1\nbox 5 FlashGrenade 3 99 990 Kaanta '
    ..'the second\nbox 6 HealGrenade 1 0 991 \nseen 99 4 a\nseen 99 3 n\n'
local st=M.read(text)
assert(#st.out==1 and st.out[1].to=='99' and st.out[1].at==1000 and st.out[1].sent==1010 and st.out[1].count==2)
assert(#st.back==1 and st.back[1].alias=='HP_Potion' and #st.box==2 and st.box[1].name=='Kaanta the second'
    and st.box[2].name=='' and st.box[2].from=='0' and #st.seen==2 and st.seen[2].answer=='n' and st.bad==0)
assert(M.write(st)==text,'Written back as read')
st=M.read('out 1 Bullet_Normal 2 99 1 1\nback 2 HP_Potion 0\nback 3 HP_Potion 11\nbox x\njunk\nseen 1 2 b\n'
    ..'back 4 HP_Potion 10\n')
assert(st.bad==6 and #st.back==1 and st.back[1].id=='4','An item or count a gift never holds is dropped')
local many={out={},back={},box={},seen={}}
for i=1,M.KEEP+5 do many.seen[i]={from='9',id=tostring(i),answer='a'} end
local kept=M.read(M.write(many))
assert(#kept.seen==M.KEEP and kept.seen[1].id=='6','The last KEEP keys only')
assert(M.write({out={},back={},box={},seen={}})=='')

-- 2. The remove call: an alias of ITEMS, 1-10 items, a GUID; bucket 1 and no pocket.
for _,bad in ipairs({{'Bullet_Normal',1,7},{'HP_Potion',0,7},{'HP_Potion',11,7},{'HP_Potion',1.5,7},
        {'HP_Potion',1,0},{'HP_Potion',1,0x100000000},{nil,1,7}}) do
    assert(not pcall(M.remove,pc,bad[3],bad[1],bad[2]),tostring(bad[1]))
end
assert(#removes==0)
M.remove(pc,7,'TrapGrenade',4)
local r=removes[1]
assert(r.n==5 and r[1]==1 and r[2]==7 and r[3]:ToString()=='TrapGrenade' and r[4]==4 and r[5]==-1,'Its five arguments')
removes={}

-- The mailbox over the fakes.
local ME,HER='76561198000000001','76561198000000002'
local slot,steamid,peer_id,engine='slot=coop index=4 marker=4',ME,HER,'engine=on warp=idle me=81'
local function status()
    return 'mod=v proto=14 steam=ready'..(steamid and ' steamid='..steamid or '')..' appid=1\n'..engine..'\n'
        ..'link=host lobby=5\n'..(peer_id and 'peer='..peer_id..' name=Kaanta hello=1 accepted=1\n' or '')
        ..'friend=1 0 Kaanta\n'..slot..'\n'
end
local files,unreadable,write_fails={},{},nil
local function read(name)
    if unreadable[name] then return nil,name..': Permission denied',13 end
    if files[name] then return files[name] end
    return nil,name..': No such file or directory',2
end
local function write(name,content)
    if write_fails then return false,write_fails end
    files[name]=content
    return true
end
local asked,logs,says,toasts,untoasts={},{},{},{},0
local linked,lost,loop,paused,clock,now=true,false,false,false,100,5000
local toast_fails=nil
local names={}
for i,alias in ipairs(M.ITEMS) do names[alias]={index=4000+i,number=0} end
local mail=M.new({log=function(t) logs[#logs+1]=t end,say=function(t) says[#says+1]=t end,status=status,
    request=function(line) asked[#asked+1]=line; return true,'asked the native part: '..line end,
    read=read,write=write,friend=function() if peer_id then return 'Kaanta',linked,lost end end,
    loopback=function() return loop end,paused=function() return paused end,name=function(a) return names[a] end,
    clock=function() return clock end,now=function() return now end,
    toast=function(t)
        if toast_fails then return nil,toast_fails end
        toasts[#toasts+1]=t
        return function() untoasts=untoasts+1 end
    end})
local FILE='coop-gift-'..ME..'-4.txt'
local function with_items(ask,answer) engine='engine=on warp=idle me=81 items='..ask..' '..answer end
local function tick(seconds) clock=clock+(seconds or 0.25); now=now+math.floor(seconds or 0); mail.tick() end

-- 3. A send's refusals: nothing asked, nothing removed.
local USE='Use: coop gift [send <item> [count 1-10]|take [n]]'
for _,args in ipairs({{'send'},{'send','8'},{'send','Bullet_Normal'},{'send','1','0'},{'send','1','11'},
        {'send','1','2','x'},{'dance'},{'take','1','x'}}) do
    local ok,why=mail.command(table.unpack(args))
    assert(not ok and why==USE,tostring(why))
end
linked=false
local ok,why=mail.command('send','1')
assert(not ok and why=='no friend is linked (coop loopback sends a gift to yourself)')
linked=true
slot='slot=main index=0 marker=4'
ok,why=mail.command('send','1'); assert(not ok and why=='not on a co-op save',why)
slot='slot=coop index=4 marker=4'
steamid=nil
ok,why=mail.command('send','1'); assert(not ok and why=='the Steam link is not ready yet',why)
steamid=ME
paused=true
ok,why=mail.command('send','1'); assert(not ok and why=='the game is paused or shows one of its screens: nothing sent')
paused=false
her=nil
ok,why=mail.command('send','1'); assert(not ok and why=='no EVE in the world: nothing sent')
her=eve
names.HP_Potion=nil
ok,why=mail.command('send','hp_potion'); assert(not ok and why=='this game holds no name HP_Potion: nothing sent')
names.HP_Potion={index=4001,number=0}
unreadable[FILE]=true
ok,why=mail.command('send','1'); assert(not ok and why=='the gift file was not read: '..FILE..': Permission denied')
unreadable[FILE]=nil
assert(#asked==0 and #removes==0,'Nothing asked, nothing removed')

-- 4. A send: the read, the remove, the reads until the count fell, then the entry and its line.
ok,why=mail.command('send','pulsegrenade','2')
assert(ok and why=='reading how many PulseGrenade you carry; the gift of 2 follows',why)
assert(asked[1]=='items 1 PulseGrenade 4004 0')
ok,why=mail.command('send','1')
assert(not ok and why=='a gift is already on its way out: wait for its answer on screen')
tick()
assert(#removes==0,'No answer yet')
with_items(1,'5')
tick()
r=removes[1]
assert(#removes==1 and r[1]==1 and r[2]==0x51 and r[3]:ToString()=='PulseGrenade' and r[4]==2 and r[5]==-1)
assert(logs[#logs]=='remove asked: PulseGrenade x2 of 5 (guid 81)',logs[#logs])
assert(#asked==1,'The next read waits POLL s')
tick(0.5)
assert(asked[2]=='items 2 PulseGrenade 4004 0')
with_items(2,'5') -- Not taken out yet.
tick(0.25)
assert(#asked==2 and files[FILE]==nil)
tick(0.25)
assert(asked[3]=='items 3 PulseGrenade 4004 0')
with_items(3,'3')
tick(0.25)
st=M.read(files[FILE])
assert(#st.out==1 and st.out[1].alias=='PulseGrenade' and st.out[1].count==2 and st.out[1].to==HER
    and st.out[1].at==now and st.out[1].sent==now,'The entry first')
local id=st.out[1].id
assert(id:match('^'..now..'%d%d%d$') and asked[4]=='gift s '..id..' PulseGrenade 2','Then its line')
assert(says[#says]=="Gift sent: 2 PulseGrenade. It waits for your friend's answer.",says[#says])

-- Her answer: kept. The entry goes; an answer for no entry is only logged.
mail.receive('a '..id)
st=M.read(files[FILE])
assert(#st.out==0 and says[#says]=='Kaanta got your 2 PulseGrenade.',says[#says])
local n=#asked
mail.receive('a '..id)
assert(logs[#logs]=='answer a '..id..' for no gift waiting (it may have come back already)' and #asked==n)
mail.receive('s 1 x')
assert(logs[#logs]=='gift line in no known shape: s 1 x' and #asked==n)

-- 5. Every way a send stops before its line, the items still there (nothing in the file, nothing sent).
local function start(item,count)
    removes={}
    local ok2,why2=mail.command('send',item,count)
    assert(ok2,why2)
    return asked[#asked]:match('^items (%d+) ')
end
local ask=start('1','3')
with_items(ask,'2')
tick()
assert(#removes==0 and says[#says]=='Gift not sent: you carry 2 HP_Potion',says[#says])
ask=start('1','3')
with_items(ask,'none nobucket')
tick()
assert(says[#says]=='Gift not sent: your inventory could not be read (nobucket)',says[#says])
ask=start('1','3')
tick(Mailbox.READ+0.25)
assert(says[#says]=='Gift not sent: the native part did not read the inventory',says[#says])
ask=start('1','3')
with_items(ask,'9')
remove_raise='bad call'
tick()
remove_raise=nil
assert(says[#says]:find('^Gift not sent: the game call failed: bad call'),says[#says])
ask=start('1','3')
with_items(ask,'9')
tick()
assert(#removes==1)
for _=1,12 do
    tick(0.25)
    local a=asked[#asked]:match('^items (%d+) ')
    with_items(a,'9')
end
assert(says[#says]=='Gift not sent: the game did not take the items out (9 before, 9 now)',says[#says])
assert(#M.read(files[FILE]).out==0 and not asked[#asked]:find('^gift'),'Nothing in the file, no line')
-- The file cannot be written after the remove: the items come back at once through the shop's grant.
ask=start('2','1')
with_items(ask,'4')
tick()
tick(0.5)
with_items(asked[#asked]:match('^items (%d+) '),'3')
write_fails='disk full'
adds={}
tick()
write_fails=nil
local a=adds[1]
assert(#adds==1 and a[1]==1 and a[2]==0x51 and a[3]:ToString()=='HP_Potion_Small' and a[4]==1 and a.n==9)
assert(says[#says]:find('The items came back%.$'),says[#says])
assert(not asked[#asked]:find('^gift'),'No line for a gift with no entry')

-- 6. Answers that bring the items back: refused, nolink; the grant tried again after RETRY s when it raises.
local function sent(item,count,have)
    local ask2=start(item,count)
    with_items(ask2,tostring(have))
    tick()
    tick(0.5)
    with_items(asked[#asked]:match('^items (%d+) '),tostring(have-math.tointeger(tonumber(count))))
    tick()
    return asked[#asked]:match('^gift s (%d+) ')
end
adds={}
id=sent('7','2',2)
assert(id,'Sent')
mail.receive('n '..id..' full')
st=M.read(files[FILE])
assert(#st.out==0 and #st.back==1 and says[#says]=='Gift refused (full): the 2 FlashGrenade come back.')
tick()
assert(#adds==1 and adds[1][3]:ToString()=='FlashGrenade' and adds[1][4]==2 and #M.read(files[FILE]).back==0)
assert(says[#says]=='Gift returned: 2 FlashGrenade are back in your inventory.')
id=sent('6','1',1)
mail.receive('n '..id..' nolink')
add_raise='not now'
tick()
assert(#adds==2 and #M.read(files[FILE]).back==1,'Kept while the grant raises')
tick(1)
assert(#adds==2,'Not tried again before RETRY s')
add_raise=nil
tick(Mailbox.RETRY)
assert(#adds==3 and adds[3][3]:ToString()=='TrapGrenade' and #M.read(files[FILE]).back==0)
-- Paused, or no EVE: the gift waits to come back.
id=sent('5','1',3)
mail.receive('n '..id..' slot')
paused=true
tick()
assert(#adds==3 and #M.read(files[FILE]).back==1)
paused=false
tick()
assert(#adds==4)

-- 7. No answer: sent again every AGAIN s with the same id, back after WAIT s; the friend leaving brings it back at
-- once, a lost link does not; with the loopback gone, a gift to ourselves comes back.
id=sent('1','1',5)
n=#asked
tick(Mailbox.AGAIN)
assert(asked[n+1]=='gift s '..id..' HP_Potion 1' and logs[#logs]=='gift '..id..' sent again')
tick(1)
assert(#asked==n+1)
tick(Mailbox.WAIT)
assert(#M.read(files[FILE]).out==0 and logs[#logs-1]=='gift '..id..' comes back: no answer in 60 s',logs[#logs-1])
assert(adds[#adds][3]:ToString()=='HP_Potion')
id=sent('2','1',5)
linked,lost=false,true
n=#adds
tick(5)
assert(#M.read(files[FILE]).out==1 and #adds==n,'A lost link: it waits')
lost=false
tick()
assert(#M.read(files[FILE]).out==0 and #adds==n+1,'The friend left: it comes back')
linked=true
peer_id=nil
loop=true
id=sent('2','1',5)
assert(M.read(files[FILE]).out[1].to=='0','To ourselves in the loopback')
loop=false
tick()
assert(#M.read(files[FILE]).out==0 and #adds==n+2,'The loopback gone: it comes back')
peer_id=HER

-- 8. Her gifts: kept and answered, shown; a key seen before answered as before; refused off a co-op save, for an item
-- not listed, with a full mailbox or a file that cannot be written.
asked={}
mail.receive('s 900 HP_Potion 3')
assert(asked[1]=='gift a 900' and says[#says]=='Kaanta sent you 3 HP_Potion: coop gift take puts them in your inventory.')
assert(toasts[1]=='Kaanta: 3 HP_Potion')
st=M.read(files[FILE])
assert(#st.box==1 and st.box[1].from==HER and st.box[1].name=='Kaanta' and st.box[1].count==3)
mail.receive('s 900 HP_Potion 3')
assert(asked[2]=='gift a 900' and #M.read(files[FILE]).box==1,'Sent again: one gift')
mail.receive('s 901 Bullet_Normal 3')
assert(asked[3]=='gift n 901 item')
slot='slot=main index=0 marker=4'
mail.receive('s 902 HP_Potion 1')
assert(asked[4]=='gift n 902 slot')
slot='slot=coop index=4 marker=4'
write_fails='disk full'
mail.receive('s 903 HP_Potion 1')
write_fails=nil
assert(asked[5]=='gift n 903 store' and #M.read(files[FILE]).box==1)
st=M.read(files[FILE])
for i=2,Mailbox.BOX do st.box[i]={id=tostring(1000+i),alias='HP_Potion',count=1,from=HER,at=1,name='Kaanta'} end
files[FILE]=M.write(st)
mail.receive('s 904 HP_Potion 1')
assert(asked[6]=='gift n 904 full')
mail.receive('s 904 HP_Potion 1')
assert(asked[7]=='gift n 904 full','A refusal kept: the same answer')
-- The toast goes after TOAST s; its first failure turns it off for the load.
local u=untoasts
tick(Mailbox.TOAST)
assert(untoasts==u+1)
st=M.read(files[FILE])
st.box={st.box[1]}
files[FILE]=M.write(st)
toast_fails='no class'
mail.receive('s 905 HealGrenade 1')
assert(logs[#logs]=='toast off until the mod reloads: no class',logs[#logs])
toast_fails=nil
mail.receive('s 906 HealGrenade 1')
assert(#toasts==1,'No toast for the rest of the load')

-- 9. take: all, or the nth; written before each grant, put back when the grant raises.
local list_ok,list=mail.command()
assert(list_ok and list:find('^Mailbox: 1 HP_Potion x3 from Kaanta, 2 HealGrenade x1 from Kaanta'),list)
assert(list:find('You can send: 1 HP_Potion, 2 HP_Potion_Small, 3 HealGrenade',1,true),list)
ok,why=mail.command('take','9'); assert(not ok and why=='coop gift take [1-3]: 3 gift(s) wait',why)
paused=true
ok,why=mail.command('take'); assert(not ok and why=='the game is paused or shows one of its screens: nothing taken')
paused=false
adds={}
add_raise='busy'
ok,why=mail.command('take','2')
add_raise=nil
assert(not ok and why=='the game call failed (busy): nothing taken' and #M.read(files[FILE]).box==3,why)
ok,why=mail.command('take','1')
st=M.read(files[FILE])
assert(ok and why=='took 3 HP_Potion from Kaanta' and #st.box==2 and st.seen[#st.seen].id=='900',why)
assert(adds[#adds][3]:ToString()=='HP_Potion' and adds[#adds][4]==3)
n=#asked
mail.receive('s 900 HP_Potion 3')
assert(asked[n+1]=='gift a 900' and #M.read(files[FILE]).box==2,'Taken, then sent again: no second gift')
write_fails='disk full'
ok,why=mail.command('take')
write_fails=nil
assert(not ok and why=='the gift file was not written (disk full): nothing taken' and #M.read(files[FILE]).box==2)
ok,why=mail.command('take')
assert(ok and why=='took 1 HealGrenade from Kaanta, 1 HealGrenade from Kaanta' and #M.read(files[FILE]).box==0,why)
ok,why=mail.command('take'); assert(not ok and why=='your mailbox is empty')

-- 10. A gift sent from another co-op slot comes back once that slot loads.
files['coop-gift-'..ME..'-2.txt']='back 77 ConcussionGrenade 2\n'
n=#adds
tick()
assert(#adds==n,'Slot 4 loaded: not yet')
slot='slot=coop index=2 marker=2'
tick()
assert(#adds==n+1 and adds[#adds][3]:ToString()=='ConcussionGrenade' and files['coop-gift-'..ME..'-2.txt']=='')
-- The .tmp a failed rename left is read when the file is missing.
files['coop-gift-'..ME..'-2.txt']=nil
files['coop-gift-'..ME..'-2.txt.tmp']='box 1 HP_Potion 1 9 1 Kaanta\n'
list_ok,list=mail.command()
assert(list_ok and list:find('^Mailbox: 1 HP_Potion x1 from Kaanta'),list)
mail.stop()
print('cut_mailbox_test ok')
