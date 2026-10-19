-- The co-op menu's model: the main page's rows by session state, a cursor that skips section headers and wraps, Leave
-- only on a second Select within 3 s, the Options tree (every co-op setting as a toggle, a choice, a range or a key),
-- its values read as the mod reads coop-settings.txt, each change as the one line to rewrite, and key rebinds checked
-- against the other keys.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local M=require('ui_model')
local SF=require('settings_file')
local K=require('keybind')
local Link=require('link')

local function ids(menu,ctx)
    local out={}
    for _,row in ipairs(menu.rows(ctx)) do out[#out+1]=row.head and 'head:'..row.head or (row.id or row.key) end
    return table.concat(out,' ')
end
local NONE,HOST,GUEST={mode='none'},{mode='host',chat=true},{mode='guest',chat=true}

-- The main page by session state (ctx.mode as link.mode() says; ctx.chat: a friend linked, or the loopback).
local menu=M.new()
assert(ids(menu,{})=='head:settings options head:help report close','Before Steam: no session rows, nor their header')
assert(ids(menu,NONE)=='head:session host join head:settings options head:help report close')
assert(ids(menu,{mode='none',chat=true})=='head:session host join chat head:settings options head:help report close',
    'The loopback chats with no session')
assert(ids(menu,HOST)=='head:session leave invite chat head:settings options head:help report close')
assert(ids(menu,{mode='host'})=='head:session leave invite head:settings options head:help report close',
    'Hosting with no friend linked yet: no chat')
assert(ids(menu,GUEST)=='head:session leave chat head:settings options head:help report close')

-- The cursor: the first row that is not a header, then down and up over headers, wrapping both ways.
assert(menu.current(NONE).id=='host')
local seen={}
for _=1,6 do menu.move(NONE,1); seen[#seen+1]=menu.current(NONE).id end
assert(table.concat(seen,' ')=='join options report close host join',table.concat(seen,' '))
menu.move(NONE,-1)
menu.move(NONE,-1)
assert(menu.current(NONE).id=='close')
-- The session changes under the cursor: the row in its place takes it.
menu.move(NONE,1) -- host
assert(menu.current(NONE).id=='host' and menu.current(HOST).id=='leave')
assert(menu.current(NONE).id=='host','And back')
assert(menu.current({}).id=='options','A header in its place: the next row')

-- Select: each row's action; Leave asks first and counts a second Select within 3 s.
menu=M.new()
assert(menu.select(NONE,0)=='host')
menu.move(NONE,1)
assert(menu.select(NONE,0)=='join')
menu=M.new()
assert(menu.select(HOST,10)=='confirm_leave' and menu.select(HOST,12.9)=='leave')
assert(menu.select(HOST,20)=='confirm_leave' and menu.select(HOST,23.5)=='confirm_leave','Too late: asked again')
assert(menu.select(HOST,24)=='leave')
assert(menu.select(HOST,30)=='confirm_leave')
menu.move(HOST,1)
menu.move(HOST,-1)
assert(menu.select(HOST,31)=='confirm_leave','Moving away forgets the first Select')
menu.move(HOST,1)
assert(menu.select(HOST,0)=='invite')
menu.move(HOST,1)
assert(menu.select(HOST,0)=='chat')
menu.move(HOST,1)
menu.move(HOST,1)
assert(menu.select(HOST,0)=='report')
menu.move(HOST,1)
assert(menu.select(HOST,0)=='close')
-- Back closes the main page.
assert(menu.back()=='close')
-- A first Select on Leave does not outlive the menu: closed by Esc, or by menu_key (close()), it asks again.
menu=M.new()
assert(menu.select(HOST,40)=='confirm_leave' and menu.back()=='close' and menu.select(HOST,41)=='confirm_leave')
menu.close()
assert(menu.select(HOST,42)=='confirm_leave','close()')

-- The Options tree: every row a header or a setting with a unique name the file can hold, and a default it takes.
local names={}
for _,row in ipairs(M.OPTIONS) do
    if not row.head then
        assert(row.key:find('^[%w_]+$') and not names[row.key],row.key)
        names[row.key]=true
        local d=row.default
        if row.bind then assert(K.parse(row.key,d) and K.parse(row.key,d).name==d,row.key)
        elseif row.values then
            local found=false
            for _,v in ipairs(row.values) do found=found or v==d end
            assert(found,row.key)
        else assert(row.min<=tonumber(d) and tonumber(d)<=row.max and tonumber(d)%row.step==0,row.key) end
        -- A row the mod reads today: its values are the mod's (link.parse_settings), its default too.
        local s=Link.parse_settings('')
        if not row.later then assert(s[row.key]~=nil,row.key..': shown, so the mod must read it') end
    end
end
-- The settings the mod reads keep its defaults; the rest (not on this branch yet) the model's.
local s=Link.parse_settings('')
local values=M.read('')
assert(values.status_key==s.status_key.name and values.leave_key==s.leave_key.name and values.send_rate=='20'
    and values.name_tag=='on' and values.cloth=='off' and values.dyes=='off' and values.effects=='off'
    and values.shared_enemies=='off' and values.menu_key=='F5' and values.chat_key=='Enter' and values.host_key=='none'
    and values.photo_freeze_max=='600' and values.ui_scale=='100' and values.ui_sounds=='on'
    and values.ui_language=='game')

-- Values as the mod reads the file: the last line it takes, any case; a refused value leaves the default.
values=M.read('send_rate=25\nsend_rate=99\nNAME_TAG=Off\nphoto_sync=NOTICE\nstatus_key=shift+f7\nui_scale=7\n'
    ..'menu_key=F7\nhost_key=F5\nchat_lines=x\nphoto_freeze_max=0\n')
assert(values.send_rate=='25' and values.name_tag=='off' and values.photo_sync=='notice' and values.menu_key=='F7'
    and values.status_key=='Shift+F7' and values.ui_scale=='100' and values.host_key=='F5' and values.chat_lines=='50'
    and values.photo_freeze_max=='0')
assert(M.read(Link.DEFAULT).menu_key=='F5' and M.read(Link.DEFAULT).host_key=='none'
    and M.read(Link.DEFAULT).send_rate=='20')
-- The migration (D-UI2): a file with no menu_key line, as every file before the menu, gives the menu host_key's key and
-- turns host_key off: Host is the menu's first row. The user's Shift+F5 file opens the menu on Shift+F5.
local OLD='host_key=F5\nstatus_key=F6\nleave_key=F8\n'
values=M.read(OLD)
assert(values.menu_key=='F5' and values.host_key=='none' and values.status_key=='F6')
values=M.read('host_key=Shift+F5\nstatus_key=Shift+F6\nleave_key=Shift+F8\n')
assert(values.menu_key=='Shift+F5' and values.host_key=='none' and values.leave_key=='Shift+F8')
assert(M.read('host_key=F10\n').menu_key=='F5','A refused host_key: the default menu key')
-- Each change rewrites its own line only; the first menu_key written into such a file also writes host_key=none, so the
-- old key never hosts again by itself.
local file=assert(M.write(OLD,'status_key','F7'))
assert(file=='host_key=F5\nstatus_key=F7\nleave_key=F8\n' and M.read(file).menu_key=='F5')
file=assert(M.write(OLD,'menu_key','F7'))
assert(file=='host_key=none\nstatus_key=F6\nleave_key=F8\nmenu_key=F7\n',file)
s=Link.parse_settings(file)
assert(s.menu_key.name=='F7' and s.host_key.name=='none' and M.read(file).host_key=='none')
assert(M.write('menu_key=F5\nhost_key=F9\n','menu_key','F7')=='menu_key=F7\nhost_key=F9\n','A menu_key line: as set')
local pad='#'..string.rep('x',4094)..'\n'
assert(M.write(pad..OLD,'menu_key','F7')==nil,'A file over the limit: nothing changes')

-- The Options page: opened from the main page, back to it on its row.
menu=M.new()
menu.move(NONE,1)
menu.move(NONE,1)
assert(menu.select(NONE,0)=='options' and menu.page()=='options')
assert(menu.current(NONE).key=='menu_key' and menu.rows(NONE)[1].head=='controls')
assert(menu.back()==nil and menu.page()=='main' and menu.current(NONE).id=='options')
menu.select(NONE,0)
-- Only the settings whose feature is on this branch show (the others wait, marked later), and no header without one.
assert(ids(menu,NONE)=='head:controls menu_key status_key leave_key head:photo photo_sync photo_freeze_max photo_ghost '
    ..'photo_name_tag head:partner name_tag head:ghost cloth dyes effects send_rate head:combat shared_enemies '
    ..'head:display ui_scale ui_sounds ui_language',ids(menu,NONE))
-- The two the mod takes at its next load only: the name tag is part of the ghost's build, the shared fight starts once
-- a load.
for _,row in ipairs(M.OPTIONS) do
    assert((row.reload==true)==(row.key=='name_tag' or row.key=='shared_enemies'),tostring(row.key))
end
-- Each change is the one value to write: toggles flip, choices wrap, ranges stop at their ends.
values=M.read('')
local function on(key)
    menu=M.new()
    menu.select({},0) -- options, the first row with no session
    while menu.current(NONE).key~=key do menu.move(NONE,1) end
end
local action,key,text=menu.change(NONE,values,1)
assert(action==nil,'A key row changes by rebind only')
action,key=menu.select(NONE,0,values)
assert(action=='rebind' and key=='menu_key')
on('name_tag')
assert(select(3,menu.change(NONE,values,1))=='off' and select(3,menu.change(NONE,values,-1))=='off')
action,key,text=menu.select(NONE,0,values)
assert(action=='set' and key=='name_tag' and text=='off','Select flips a toggle too')
on('photo_sync')
assert(select(3,menu.change(NONE,values,1))=='notice' and select(3,menu.change(NONE,values,-1))=='off')
on('send_rate')
assert(select(3,menu.change(NONE,values,1))=='21' and select(3,menu.change(NONE,values,-1))=='19')
assert(menu.change(NONE,{send_rate='30'},1)==nil and menu.change(NONE,{send_rate='10'},-1)==nil,'No change at an end')
on('photo_freeze_max')
assert(select(3,menu.change(NONE,values,-1))=='540' and select(3,menu.change(NONE,values,1))=='660')
-- The longest photo pause: the file's range (0 for no limit, or 30 to 3600 s) in minutes; below a minute, no limit.
assert(select(3,menu.change(NONE,{photo_freeze_max='60'},-1))=='0' and menu.change(NONE,{photo_freeze_max='0'},-1)==nil)
local function pause(v,dir) return select(3,menu.change(NONE,{photo_freeze_max=v},dir)) end
assert(pause('0',1)=='60' and pause('3600',1)==nil and pause('45',-1)=='0' and pause('45',1)=='105')
for _,v in ipairs({'0','60','105','3600'}) do
    assert(Link.parse_settings('photo_freeze_max='..v).photo_freeze_max==tonumber(v),'Each one the mod takes')
end
on('ui_language')
assert(select(3,menu.change(NONE,values,1))=='english')
on('ui_scale')
assert(select(3,menu.change(NONE,values,1))=='105')
-- Through the file: the line is rewritten, read back, and the mod reads the same.
action,key,text=menu.change(NONE,values,-1)
local file=assert(SF.set(Link.DEFAULT,key,text))
assert(M.read(file).ui_scale=='95')
on('cloth')
action,key,text=menu.change(NONE,M.read(Link.DEFAULT),1)
file=assert(SF.set(Link.DEFAULT,key,text))
assert(M.read(file).cloth=='on' and Link.parse_settings(file).cloth==true)
-- The main page has no values to change.
menu=M.new()
assert(menu.change(NONE,values,1)==nil)

-- Rebind: the pressed key, checked against every other key setting (host_key too, though not on the page).
values=M.read('')
assert(select(3,M.rebind(values,'status_key',K.text('F5','SHIFT')))=='Shift+F5')
local why,other
action,why,other=M.rebind(values,'status_key','F5')
assert(action==nil and why=='clash' and other=='menu_key')
action,why=M.rebind(values,'status_key',K.text('F10'))
assert(action==nil and why=='F10 opens the console')
action,key,text=M.rebind(values,'chat_key','Enter')
assert(action=='set' and key=='chat_key' and text=='Enter')
action,why,other=M.rebind(M.read('menu_key=F5\nhost_key=F7\n'),'menu_key','F7')
assert(action==nil and why=='clash' and other=='host_key')

print('ui_model_test ok')
