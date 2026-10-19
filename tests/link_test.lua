-- The Steam link's Lua side: requests reach the native part whole, and each status line is reported once.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local files,renames={},0
local fs={
    read=function(path) return files[path] end,
    write=function(path,text) files[path]=text; return true end,
    remove=function(path) files[path]=nil; return true end,
    rename=function(from,to)
        if files[to] then return nil,'exists' end -- Windows' rename never replaces.
        renames=renames+1; files[to],files[from]=files[from],nil; return true
    end,
}
local link=require('link').new('C:\\Mod',fs)
local REQUEST,STATUS='C:\\Mod\\coop-request.txt','C:\\Mod\\coop-status.txt'

local ok,message=link.request('host')
assert(ok and files[REQUEST]=='host\n' and not files[REQUEST..'.tmp'] and renames==1,message)
ok,message=link.request('join 42') -- The native part has not taken the previous request: the newest wins.
assert(ok and files[REQUEST]=='join 42\n',message)
local write=fs.write
fs.write=function() return false end
ok,message=link.request('leave')
assert(not ok and message:find('cannot write'),message)
fs.write=write

assert(#link.changes()==0,'No status yet')
assert(link.status()==nil)
files[STATUS]='steamid=1 relay=100\nrole=none lobby=0\nlast=Steam ready\n'
local lines=link.changes()
assert(#lines==3 and lines[1]=='steamid=1 relay=100' and lines[3]=='last=Steam ready')
assert(#link.changes()==0,'Unchanged lines are not reported again')
files[STATUS]='steamid=1 relay=100\r\nrole=host lobby=7\r\nlast=hosting lobby 7\r\n'
lines=link.changes()
assert(#lines==2 and lines[1]=='role=host lobby=7' and lines[2]=='last=hosting lobby 7')
files[STATUS]='steamid=1 relay=100\nrole=none lobby=0\nlast=Steam ready\n'
assert(#link.changes()==2,'A line seen before, then gone, is new again')
files[STATUS]='steamid=1 relay=100\nrole=host lobby=7\npeer=2 name=Bob rtt_ms=40\nfight=on mode=on sim_us=12/40\n'
    ..'last=#3 Bob is in the lobby\n'
lines=link.changes()
assert(#lines==2 and lines[1]=='role=host lobby=7' and lines[2]=='last=#3 Bob is in the lobby',
    'Peer and fight lines stay out of the log')
assert(link.status():find('peer=2 name=Bob',1,true) and link.status():find('\nfight=on ',1,true),
    'coop status still shows them')

assert(link.session('42-7') and files['C:\\Mod\\coop-session.txt']=='42-7\n')
assert(link.components('generation 1\n') and files['C:\\Mod\\coop-components.txt']=='generation 1\n')
assert(link.components('generation 2\n') and files['C:\\Mod\\coop-components.txt']=='generation 2\n','Replaced, not refused')
assert(link.components(nil) and files['C:\\Mod\\coop-components.txt']==nil,'Withdrawn with the ghost')
-- The display file goes the same way; the remote table is the native part's, only read.
local DISPLAY,REMOTE='C:\\Mod\\coop-display.txt','C:\\Mod\\coop-remote.txt'
assert(link.display('display 7\n') and files[DISPLAY]=='display 7\n' and not files[DISPLAY..'.tmp'])
assert(link.display('display 8\n') and files[DISPLAY]=='display 8\n')
assert(link.display(nil) and files[DISPLAY]==nil)
assert(link.remote_table()==nil)
files[REMOTE]='SBT 3\ngeneration 7\n'
assert(link.remote_table()=='SBT 3\ngeneration 7\n' and files[REMOTE],'Read, never removed')

-- The remote table the native part holds, from the status as of the last changes().
files[STATUS]='mod=v\nengine=on loopback=on 120 30 1 remote=1797 3 loopback\nlast=#5 remote table\n'
link.changes()
local g,n,source=link.remote()
assert(g==1797 and n==3 and source=='loopback',tostring(g))
files[STATUS]='mod=v\nengine=on replay=on remote=1798 4 replay\nlast=#6 replay on\n'
link.changes()
g,n,source=link.remote()
assert(g==1798 and n==4 and source=='replay')
files[STATUS]='mod=v\nengine=on remote=5 2 peer\nlast=#7 peer linked: poses and tables go over Steam\n'
link.changes()
g,n,source=link.remote()
assert(g==5 and n==2 and source=='peer','A linked friend\'s table')
-- A peer's Steam name is hers to choose: only the pose path's line is read.
files[STATUS]='mod=v\npeer=2 name=x remote=1 1 replay hello=1\nengine=on loopback=on 0 0 0 remote=1799 5 loopback\n'
link.changes()
g,n,source=link.remote()
assert(g==1799 and n==5 and source=='loopback',tostring(g))
files[STATUS]='mod=v\npeer=2 name=x remote=1 1 replay hello=1\nengine=on loopback=waiting\nlast=remote=2 2 replay\n'
link.changes()
assert(link.remote()==nil,'Nor from the last line')
files[STATUS]='mod=v\nengine=on loopback=waiting\nlast=#7 loopback on\n'
link.changes()
g,n,source=link.remote()
assert(g==nil and n==nil and source==nil,'No remote table: all nil')
files[STATUS]=nil
link.changes()
assert(link.remote()==nil,'No status: none either')

-- The shared fight's line (Phase 11), as of the last changes(): from the start of its own line only, as a peer's Steam
-- name is hers to choose; nil without one.
files[STATUS]='mod=v\npeer=2 name=x fight=on mode=on hello=1\nengine=on fight=on 3\n'
    ..'fight=on mode=on role=host enemies=3 claims=0\nlast=#8 x\n'
link.changes()
assert(link.fight()=='fight=on mode=on role=host enemies=3 claims=0',tostring(link.fight()))
files[STATUS]='mod=v\r\nfight=off why=not on the co-op save (slot=main index=0 marker=4)\r\nlast=#9 x\r\n'
link.changes()
assert(link.fight()=='fight=off why=not on the co-op save (slot=main index=0 marker=4)','CRLF')
files[STATUS]='mod=v\npeer=2 name=x fight=off\nlast=fight=on mode=on\n'
link.changes()
assert(link.fight()==nil,'Not from a peer line nor from the last line')
files[STATUS]='mod=v\nfight=on mode=probe actors=1\n'
link.changes()
files[STATUS]=nil
link.changes()
assert(link.fight()==nil,'No status: none either')

assert(link.valid_lobby('109775241234567890') and not link.valid_lobby('12x') and not link.valid_lobby('0'))

-- coop-settings.txt (N5): free keys, never F10 or ~ (the console on AZERTY); a bad value keeps its default, with a line.
local Link=require('link')
local s,notes=Link.parse_settings('')
assert(s.menu_key.key=='F5' and s.menu_key.mod==nil and s.status_key.key=='F6' and s.leave_key.key=='F8' and #notes==0)
assert(s.host_key.key==nil and s.host_key.name=='none','Host is in the menu: no host key unless set')
assert(s.name_tag==true and s.send_rate==20,'Empty text: the defaults')
s,notes=Link.parse_settings('status_key=Shift+F7\n menu_key = f6 \n')
assert(s.status_key.key=='F7' and s.status_key.mod=='SHIFT' and s.status_key.name=='Shift+F7' and #notes==0)
assert(s.menu_key.key=='F6' and s.menu_key.mod==nil and s.leave_key.key=='F8','Spaces and case do not matter')
-- The menu (D-UI2): a file with no menu_key line (every file before it) gives the menu host_key's key, and host_key goes
-- off: Host is the menu's first row. The user's Shift+F5 file opens the menu on Shift+F5; a menu_key line keeps both.
s,notes=Link.parse_settings('host_key=F5\nstatus_key=F6\nleave_key=F8\n')
assert(#notes==0 and s.menu_key.name=='F5' and s.host_key.name=='none' and s.host_key.key==nil)
s,notes=Link.parse_settings('host_key=Shift+F5\nstatus_key=Shift+F6\nleave_key=Shift+F8\n')
assert(#notes==0 and s.menu_key.key=='F5' and s.menu_key.mod=='SHIFT' and s.host_key.name=='none'
    and s.status_key.name=='Shift+F6' and s.leave_key.name=='Shift+F8')
s,notes=Link.parse_settings('menu_key=F7\nhost_key=F5\n')
assert(#notes==0 and s.menu_key.name=='F7' and s.host_key.key=='F5','Both set: both kept, host_key hosts at once')
s,notes=Link.parse_settings('host_key=none\n')
assert(#notes==0 and s.menu_key.name=='F5' and s.host_key.name=='none')
s,notes=Link.parse_settings('menu_key=none\n')
assert(#notes==1 and s.menu_key.name=='F5' and notes[1]:find("'none' is not allowed for menu_key",1,true),notes[1])
s,notes=Link.parse_settings('menu_key=F5\nhost_key=F5\n')
assert(#notes==1 and notes[1]=='settings: F5 is set for two actions: default keys used' and s.host_key.name=='none')
local ANY='use F1 to F12, with at most one of Shift+, Ctrl+, Alt+'
for _,refused in ipairs({{'F10','F10 opens the console'},{'Ctrl+F10','F10 opens the console'},{'~',ANY},{'A',ANY},
    {'F13',ANY},{'Ctrl+Alt+F5',ANY}}) do
    s,notes=Link.parse_settings('# keys\nleave_key='..refused[1]..'\n')
    local want="settings: line 2: '"..refused[1].."' is not allowed for leave_key ("..refused[2].."); leave_key stays F8"
    assert(#notes==1 and notes[1]==want and s.leave_key.key=='F8' and s.leave_key.mod==nil,notes[1])
end
s,notes=Link.parse_settings('host_key=F2\nstatus_key=F3\nleave_key=F3\n')
assert(#notes==1 and notes[1]=='settings: F3 is set for two actions: default keys used',notes[1])
assert(s.menu_key.key=='F5' and s.host_key.name=='none' and s.status_key.key=='F6' and s.leave_key.key=='F8',
    'A shared key: all four go back')
s,notes=Link.parse_settings('status_key=Alt+F7\nleave_key=Ctrl+F7\n')
assert(#notes==0 and s.status_key.mod=='ALT' and s.leave_key.mod=='CONTROL','Another modifier is another key')
for _,rate in ipairs({'9','31','x'}) do
    s,notes=Link.parse_settings('send_rate='..rate)
    local want="settings: line 1: '"..rate.."' is not allowed for send_rate (use 10 to 30); send_rate stays 20"
    assert(#notes==1 and notes[1]==want and s.send_rate==20,notes[1])
end
s,notes=Link.parse_settings('send_rate=30'); assert(#notes==0 and s.send_rate==30)
s,notes=Link.parse_settings('name_tag=maybe')
assert(notes[1]=="settings: line 1: 'maybe' is not allowed for name_tag (use on or off); name_tag stays on" and s.name_tag)
s,notes=Link.parse_settings('NAME_TAG=Off'); assert(#notes==0 and s.name_tag==false)
s,notes=Link.parse_settings('name_tag=off\r\nsend_rate=25\r\nmenu_key=Shift+F2\r\n')
assert(#notes==0 and s.name_tag==false and s.send_rate==25 and s.menu_key.name=='Shift+F2','CRLF')
s,notes=Link.parse_settings('colour=red\n\nnot a setting\n')
assert(#notes==2 and notes[1]=="settings: line 1: unknown setting 'colour', ignored"
    and notes[2]=="settings: line 3: unknown setting 'not a setting', ignored",notes[1])
local long='#'..string.rep('x',4088)..'\nsend_rate=25\n' -- The 4096th byte is the r of "send_r": the line is dropped.
long=long..'#'..string.rep('x',5000-#long-2)..'\n'
s,notes=Link.parse_settings(long)
assert(#long==5000 and s.send_rate==20 and #notes==1 and notes[1]=='settings: only the first 4096 bytes are read',notes[1])
s,notes=Link.parse_settings('\239\187\191menu_key=F7\n')
assert(#notes==0 and s.menu_key.name=='F7','A UTF-8 BOM is skipped')
local keys=0
for name,value in Link.DEFAULT:gmatch('\n(%w+_key)=([^\n]*)') do keys=keys+1; assert(not value:upper():find('F10'),name) end
s,notes=Link.parse_settings(Link.DEFAULT)
assert(keys==4 and #notes==0 and s.menu_key.name=='F5' and s.host_key.name=='none' and s.status_key.name=='F6'
    and s.leave_key.name=='F8')
assert(Link.DEFAULT:find('\nmenu_key=F5\nhost_key=none\n',1,true),'A new file names the menu key, and no host key')
-- The menu's own: ui_scale 75 to 150 (%), ui_sounds on or off, ui_language game or english; a new file names them.
assert(s.ui_scale==100 and math.type(s.ui_scale)=='integer' and s.ui_sounds==true and s.ui_language=='game')
assert(Link.DEFAULT:find('\nui_scale=100\nui_sounds=on\nui_language=game\n',1,true))
s,notes=Link.parse_settings('UI_Scale=75\nui_sounds=OFF\nui_language=English\n')
assert(#notes==0 and s.ui_scale==75 and s.ui_sounds==false and s.ui_language=='english')
for _,bad in ipairs({{'ui_scale','74','use 75 to 150','100'},{'ui_scale','151','use 75 to 150','100'},
        {'ui_scale','1.5','use 75 to 150','100'},{'ui_sounds','yes','use on or off','on'},
        {'ui_language','french','use game or english','game'},
        {'who_can_join','public','use friends or private','friends'},
        {'photo_sync','pause','use both, notice or off','both'}}) do
    s,notes=Link.parse_settings(bad[1]..'='..bad[2])
    assert(#notes==1 and notes[1]=="settings: line 1: '"..bad[2].."' is not allowed for "..bad[1].." ("..bad[3].."); "
        ..bad[1].." stays "..bad[4],notes[1])
end
-- Who can join a session hosted here: friends (the default, and an old file's) or private (invited only).
assert(Link.parse_settings('').who_can_join=='friends' and Link.DEFAULT:find('\nwho_can_join=friends\n',1,true))
s,notes=Link.parse_settings('Who_Can_Join=PRIVATE\n'); assert(#notes==0 and s.who_can_join=='private')
-- The chat: on or off (off hides her lines and sends none); a new file names it.
assert(Link.parse_settings('').chat==true and Link.DEFAULT:find('\nchat=on\n',1,true))
s,notes=Link.parse_settings('Chat=OFF\n'); assert(#notes==0 and s.chat==false)
s,notes=Link.parse_settings('chat=maybe\n')
assert(#notes==1 and s.chat==true and notes[1]=="settings: line 1: 'maybe' is not allowed for chat (use on or off); "
    ..'chat stays on',notes[1])
assert(s.cloth==false and s.dyes==false and s.effects==false,'The looks are comments in the defaults: off, as the code says')
-- The partner HUD's parts (Options > Partner): the HP marker over her, the off-screen arrow, the card and its ping
-- and map, each on or off; a new file names them.
s=Link.parse_settings('')
assert(s.partner_bar==true and s.partner_arrow==true and s.partner_card==true and s.card_details==true)
assert(Link.DEFAULT:find('\npartner_bar=on\npartner_arrow=on\npartner_card=on\ncard_details=on\n',1,true))
s,notes=Link.parse_settings('Partner_Bar=OFF\npartner_arrow=off\npartner_card=off\ncard_details=off\n')
assert(#notes==0 and s.partner_bar==false and s.partner_arrow==false and s.partner_card==false
    and s.card_details==false)
-- The ghost's looks: on or off, any case; a bad value keeps it off.
s,notes=Link.parse_settings('cloth=on'); assert(#notes==0 and s.cloth==true)
s,notes=Link.parse_settings('CLOTH=Off'); assert(#notes==0 and s.cloth==false)
s,notes=Link.parse_settings('dyes=ON'); assert(#notes==0 and s.dyes==true and s.cloth==false)
s,notes=Link.parse_settings('effects=on'); assert(#notes==0 and s.effects==true and s.dyes==false)
s,notes=Link.parse_settings('cloth=maybe')
assert(#notes==1 and notes[1]=="settings: line 1: 'maybe' is not allowed for cloth (use on or off); cloth stays off"
    and s.cloth==false,notes[1])
-- The shared enemies (Phase 11, experimental): shared_enemies on or off, off by default; fight_chars at most 16 whole
-- character ids from 1 to 2^32-1 separated by spaces, empty by default. A bad value keeps the default, with a line.
s,notes=Link.parse_settings('')
assert(s.shared_enemies==false and #s.fight_chars==0,'Off and none unless set')
s,notes=Link.parse_settings('Shared_Enemies=ON\nfight_chars= 15011001  2\t4294967295 \n')
assert(#notes==0 and s.shared_enemies==true and #s.fight_chars==3 and s.fight_chars[1]==15011001
    and s.fight_chars[2]==2 and s.fight_chars[3]==4294967295,notes[1])
assert(math.type(s.fight_chars[1])=='integer','Whole numbers: the request prints them without a decimal point')
s,notes=Link.parse_settings('fight_chars=007 '..string.rep('7 ',15))
assert(#notes==0 and #s.fight_chars==16 and s.fight_chars[1]==7,'16 at most')
s,notes=Link.parse_settings('shared_enemies=off\nfight_chars=\n')
assert(#notes==0 and not s.shared_enemies and #s.fight_chars==0)
local CHARS_RULE='use at most 16 character ids, whole numbers separated by spaces'
for _,bad in ipairs({string.rep('7 ',17),'0','4294967296','99999999999999999999','1,2','-1','+1','x','1.5','1e3'}) do
    s,notes=Link.parse_settings('fight_chars='..bad)
    local shown=bad:match('^%s*(.-)%s*$')
    local want="settings: line 1: '"..shown.."' is not allowed for fight_chars ("..CHARS_RULE..'); fight_chars '
        ..'stays empty'
    assert(#notes==1 and notes[1]==want and #s.fight_chars==0,notes[1])
end
s,notes=Link.parse_settings('shared_enemies=yes')
assert(#notes==1 and notes[1]=="settings: line 1: 'yes' is not allowed for shared_enemies (use on or off); "
    .."shared_enemies stays off" and s.shared_enemies==false,notes[1])
-- A new file names both, off and empty; a file written before they existed keeps working unchanged: the same settings,
-- no line.
assert(Link.DEFAULT:find('\nshared_enemies=off\nfight_chars=\n',1,true),'Both written in a new file')
s,notes=Link.parse_settings(Link.DEFAULT)
assert(#notes==0 and s.shared_enemies==false and #s.fight_chars==0)
local older=Link.DEFAULT:gsub('# Shared enemies.*$','')
assert(older~=Link.DEFAULT and not older:find('fight') and not older:find('shared'))
s,notes=Link.parse_settings(older)
assert(#notes==0 and s.shared_enemies==false and #s.fight_chars==0 and s.menu_key.name=='F5' and s.send_rate==20
    and s.name_tag==true and s.cloth==false)

-- The synced photo mode's: photo_sync both, notice or off (any case, both by default); photo_freeze_max 0 or 30 to
-- 3600 whole seconds (600); photo_ghost on and photo_name_tag off. A new file names all four with their defaults; one
-- written before them reads the defaults with no line. A bad value keeps the default, with a line.
s,notes=Link.parse_settings('')
assert(s.photo_sync=='both' and s.photo_freeze_max==600 and s.photo_ghost==true and s.photo_name_tag==false)
assert(math.type(s.photo_freeze_max)=='integer','The state line prints it whole')
s,notes=Link.parse_settings('Photo_Sync=NOTICE\nphoto_freeze_max=0\nphoto_ghost=OFF\nphoto_name_tag=on\n')
assert(#notes==0 and s.photo_sync=='notice' and s.photo_freeze_max==0 and not s.photo_ghost and s.photo_name_tag)
for _,good in ipairs({{'off','30',30},{'both','3600',3600},{'both','0600',600}}) do
    s,notes=Link.parse_settings('photo_sync='..good[1]..'\nphoto_freeze_max='..good[2])
    assert(#notes==0 and s.photo_sync==good[1] and s.photo_freeze_max==good[3])
    assert(math.type(s.photo_freeze_max)=='integer')
end
for _,bad in ipairs({'29','3601','-1','1.5','10m','99999999999999999999',''}) do
    s,notes=Link.parse_settings('photo_freeze_max='..bad)
    assert(#notes==1 and notes[1]=="settings: line 1: '"..bad.."' is not allowed for photo_freeze_max (use 0 (no "
        .."limit) or 30 to 3600 seconds); photo_freeze_max stays 600" and s.photo_freeze_max==600,notes[1])
end
for _,bad in ipairs({'on','yes','pause',''}) do
    s,notes=Link.parse_settings('photo_sync='..bad)
    assert(#notes==1 and notes[1]=="settings: line 1: '"..bad.."' is not allowed for photo_sync (use both, notice or "
        .."off); photo_sync stays both" and s.photo_sync=='both',notes[1])
end
s,notes=Link.parse_settings('photo_ghost=maybe')
assert(#notes==1 and notes[1]=="settings: line 1: 'maybe' is not allowed for photo_ghost (use on or off); photo_ghost "
    .."stays on" and s.photo_ghost==true,notes[1])
assert(Link.DEFAULT:find('\nphoto_sync=both\nphoto_freeze_max=600\nphoto_ghost=on\nphoto_name_tag=off\n',1,true))
s,notes=Link.parse_settings(Link.DEFAULT)
assert(#notes==0 and s.photo_sync=='both' and s.photo_freeze_max==600 and s.photo_ghost and not s.photo_name_tag)
local before_photo=Link.DEFAULT:gsub('# Synced photo mode.*$','')
assert(before_photo~=Link.DEFAULT and not before_photo:find('photo'))
s,notes=Link.parse_settings(before_photo)
assert(#notes==0 and s.photo_sync=='both' and s.photo_freeze_max==600 and s.shared_enemies==false)

-- The file is the user's: written with the defaults when absent, never written again.
local SETTINGS,writes='C:\\Mod\\coop-settings.txt',0
fs.write=function(path,text) writes=writes+1; return write(path,text) end
s,notes=link.settings()
assert(files[SETTINGS]==Link.DEFAULT and not files[SETTINGS..'.tmp'] and s.leave_key.key=='F8')
assert(#notes==1 and notes[1]=='settings: coop-settings.txt written with the defaults',notes[1])
files[SETTINGS],writes='send_rate=30\n',0
s,notes=link.settings()
assert(writes==0 and files[SETTINGS]=='send_rate=30\n' and s.send_rate==30 and #notes==0,'An existing file is never written')
local read=fs.read
fs.read=function(path) if path==SETTINGS then return nil end return read(path) end -- There but unreadable.
s,notes=link.settings()
assert(files[SETTINGS]=='send_rate=30\n' and s.send_rate==20,'Not replaced either')
assert(notes[1]=='settings: cannot write coop-settings.txt (cannot write coop-settings.txt: exists): defaults used',notes[1])
fs.read,fs.write=read,write
-- The menu's changes (D-UI4): the text as it is, and the whole file written back through a temporary one; before the
-- first change of a Lua load, the file as it was then is kept as coop-settings.old.txt (never again in that load).
local OLD_FILE=SETTINGS:gsub('%.txt$','.old.txt')
files[SETTINGS]='# mine\nsend_rate=30\n'
assert(link.settings_text()=='# mine\nsend_rate=30\n')
assert(link.write_settings('# mine\nsend_rate=25\n'))
assert(files[SETTINGS]=='# mine\nsend_rate=25\n' and files[OLD_FILE]=='# mine\nsend_rate=30\n' and not files[SETTINGS..'.tmp'])
assert(link.write_settings('# mine\nsend_rate=20\n'))
assert(files[SETTINGS]=='# mine\nsend_rate=20\n' and files[OLD_FILE]=='# mine\nsend_rate=30\n','The backup once a load')
local second=require('link').new('C:\\Mod',fs)
fs.write=function() return false end
local saved,why=second.write_settings('x\n')
assert(not saved and why:find('cannot write',1,true) and files[SETTINGS]=='# mine\nsend_rate=20\n','Nothing changed')
fs.write=write
assert(second.write_settings('send_rate=12\n') and files[OLD_FILE]=='# mine\nsend_rate=20\n','A new load backs up again')
-- A rename refused after the old file went (a scanner holding the .tmp): the file is written in place, never missing.
local rename=fs.rename
fs.rename=function(from,to) if to==SETTINGS then return nil,'in use' end return rename(from,to) end
assert(second.write_settings('send_rate=14\n') and files[SETTINGS]=='send_rate=14\n','Written in place')
fs.rename=rename
files[SETTINGS],files[OLD_FILE]=nil,nil
assert(link.settings_text()==nil)

-- coop-state.txt: written once per change; a failed write is not remembered, so the next call writes it.
local STATE_FILE,state_writes='C:\\Mod\\coop-state.txt',0
local function counted(path,text) if path==STATE_FILE..'.tmp' then state_writes=state_writes+1 end return write(path,text) end
fs.write=counted
local A,B='world=1 rate=25 photo=0 sync=both max=600','world=0 rate=25 photo=0 sync=both max=600'
assert(link.state(true,25,'0','both',600)==A and files[STATE_FILE]==A..'\n' and state_writes==1)
assert(link.state(true,25,'0','both',600)==nil and state_writes==1,'Unchanged: not written again')
fs.write=function() return false end
assert(link.state(false,25,'0','both',600)==nil and files[STATE_FILE]==A..'\n','The write failed')
fs.write=counted
assert(link.state(false,25,'0','both',600)==B and state_writes==2,'Tried again')
assert(files[STATE_FILE]==B..'\n' and not files[STATE_FILE..'.tmp'])
assert(link.state(false,25,'0','both',600)==nil and state_writes==2)
-- The photo mode and its settings are part of it: each change is written once, within the native part's 64 bytes.
assert(link.state(false,25,'s','both',600)=='world=0 rate=25 photo=s sync=both max=600' and state_writes==3)
assert(link.state(true,30,'1','notice',3600)=='world=1 rate=30 photo=1 sync=notice max=3600' and state_writes==4)
assert(#files[STATE_FILE]<=64 and link.state(true,30,'1','notice',3600)==nil and state_writes==4)
assert(link.state(true,30,'1','off',0)=='world=1 rate=30 photo=1 sync=off max=0' and state_writes==5)
-- The title screen, when no save is loaded: world=title, the longest line still within the 64 bytes.
assert(link.state(false,30,'0','notice',3600,true)=='world=title rate=30 photo=0 sync=notice max=3600'
    and state_writes==6 and #files[STATE_FILE]<=64)
assert(link.state(true,30,'0','notice',3600,true)=='world=1 rate=30 photo=0 sync=notice max=3600','A save wins')
fs.write=write

-- Notices: numbered by the native part for its run; a Lua load only shows those that come after its first look.
local fresh=require('link').new('C:\\Mod',fs)
local HEAD='mod=v proto=4 steam=ready steamid=1\nlink=host lobby=7000\n'
files[STATUS]=HEAD..'notice=1 Hosting: invite a friend from the Steam overlay (Shift+Tab).\nnotice=2 Kaanta joined.\n'
fresh.changes()
assert(#fresh.notices()==0,'The first call only primes: a reload never shows old notices again')
assert(#fresh.notices()==0,'Nothing new since')
files[STATUS]=HEAD..'notice=2 Kaanta joined.\nnotice=3 Kaanta: connection lost.\nnotice=4 Kaanta is back.\n'
fresh.changes()
local texts=fresh.notices()
assert(#texts==2 and texts[1]=='Kaanta: connection lost.' and texts[2]=='Kaanta is back.','Each new one once, in order')
assert(#fresh.notices()==0)
-- A Steam name is hers to choose: only a line that starts with notice= or friend= counts.
files[STATUS]=HEAD..'peer=2 name=x notice=99 fake hello=1\nfriend=1 0 x notice=99 fake\nnotice=4 Kaanta is back.\n'
    ..'last=notice=98 fake\n'
fresh.changes()
assert(#fresh.notices()==0,'No notice from a name')
assert(fresh.friend()=='x notice=99 fake')
files[STATUS]=nil
fresh.changes()
assert(#fresh.notices()==0 and fresh.mode()==nil and fresh.friend()==nil,'No status: nothing')
local primed=require('link').new('C:\\Mod',fs)
primed.changes(); primed.notices() -- No status yet: this does not prime.
files[STATUS]=HEAD..'notice=4 Kaanta is back.\n'
primed.changes()
assert(#primed.notices()==0,'Primed by the first status read, not by its absence')
-- The friend line: the name last and whole; each new friend= or notice= line is logged once, peer lines never.
files[STATUS]=HEAD..'peer=2 name=Ka anta hello=1 accepted=1\nfriend=1 0 Ka anta\nnotice=5 Ka anta joined.\n'
lines=fresh.changes()
local name,linked,lost=fresh.friend()
assert(name=='Ka anta' and linked==true and lost==false,name)
assert(#lines==2 and lines[1]=='friend=1 0 Ka anta' and lines[2]=='notice=5 Ka anta joined.',table.concat(lines,'|'))
assert(#fresh.changes()==0,'Logged once')
-- The status key's line, from the link line and the friend line.
local function summary(status) files[STATUS]=status; fresh.changes(); return fresh.summary() end
assert(summary(nil)=='Co-op: waiting for Steam.')
assert(summary('mod=v proto=4 steam=waiting\nengine=off\nlast=started\n')=='Co-op: waiting for Steam.')
assert(summary('mod=v steam=ready\nlink=none lobby=0\nlast=x\n')=='Co-op: not in a session.')
assert(summary('mod=v steam=ready\nlink=none lobby=0 pending=1\n')=='Co-op: not in a session.')
assert(summary('mod=v steam=ready\nlink=none lobby=0 held=7000\n')=='Co-op: invite held until your save has loaded.')
assert(summary('mod=v steam=ready\nlink=guest lobby=7 pending=1 held=7000\nfriend=1 0 Kaanta\n')
    =='Co-op: invite held until your save has loaded.')
assert(summary('mod=v steam=ready\nlink=none lobby=0\nfriend=1 0 x held=7\nlast=held=7\n')=='Co-op: not in a session.',
    'Only the link line says so')
assert(summary('mod=v steam=ready\nlink=none lobby=0 rejoin=0/3\n')=="Co-op: rejoining your friend's game (try 0/3).")
assert(summary('mod=v steam=ready\nlink=none lobby=0 pending=1 rejoin=2/3\n')=="Co-op: rejoining your friend's game (try 2/3).")
assert(summary('mod=v steam=ready\nlink=none lobby=0\nfriend=1 0 x rejoin=1/3\nlast=rejoin=1/3\n')=='Co-op: not in a session.',
    'Only the link line says so')
assert(summary('mod=v steam=ready\nlink=host lobby=7\nlast=link=guest\n')=='Co-op: hosting, no friend yet.')
assert(fresh.mode()=='host')
assert(summary(HEAD..'friend=0 0 Kaanta\n')=='Co-op: Kaanta is connecting.')
assert(summary(HEAD..'friend=1 0 Kaanta\n')=='Co-op: hosting Kaanta.')
assert(summary(HEAD..'friend=1 1 Kaanta\n')=='Co-op: hosting Kaanta. Connection lost.')
local GUEST='mod=v steam=ready\nlink=guest lobby=7000\n'
assert(summary(GUEST..'friend=1 0 Ka anta\n')=="Co-op: in Ka anta's game.")
assert(summary(GUEST..'friend=1 1 Kaanta\n')=="Co-op: in Kaanta's game. Connection lost.")
assert(summary(GUEST..'friend=0 1 Kaanta\n')=='Co-op: Kaanta is connecting. Connection lost.')
assert(summary(GUEST)=='Co-op: your friend is connecting.')
-- A worker stopped for good: a fault, or another Steamworks build.
assert(summary('stopped=fault 0xc0000005\n')=='Co-op: the Steam link stopped; coop status says why.')
assert(summary('missing=SteamAPI_ISteamMatchmaking_JoinLobby\n')=='Co-op: the Steam link stopped; coop status says why.')
assert(summary(GUEST)=='Co-op: your friend is connecting.','Only as long as the status says so')
-- Paused by her photo mode (the photo line's frozen=1 with peer_photo=1): said after the session part; not for a
-- coop freeze alone, nor from a line that does not start the status line.
local PHOTO='photo=0 peer_photo=1 frozen=1 sync=both\n'
assert(summary(GUEST..'friend=1 0 Kaanta\n'..PHOTO)=="Co-op: in Kaanta's game. Paused by Kaanta.")
assert(summary(HEAD..'friend=1 0 Kaanta\n'..PHOTO)=='Co-op: hosting Kaanta. Paused by Kaanta.')
assert(summary(HEAD..'friend=1 0 Kaanta\nphoto=0 peer_photo=0 frozen=1 sync=both\n')=='Co-op: hosting Kaanta.')
assert(summary(HEAD..'friend=1 0 Kaanta\nphoto=0 peer_photo=1 frozen=0 sync=both\n')=='Co-op: hosting Kaanta.')
assert(summary(HEAD..'friend=1 0 photo=0 peer_photo=1 frozen=1 sync=both\n')=='Co-op: hosting photo=0 peer_photo=1 '
    ..'frozen=1 sync=both.','A name is no photo line')
assert(summary(HEAD..'friend=1 0 Kaanta\n')=='Co-op: hosting Kaanta.','Gone with the line')
files[STATUS]=HEAD..'friend=1 0 Kaanta\n'..PHOTO
lines=fresh.changes()
assert(#lines==1 and lines[1]=='photo=0 peer_photo=1 frozen=1 sync=both','A changed photo line is logged')
files[STATUS]=nil

-- Chat (UI-DESIGN 4.2, 5.2): coop-say.txt, a typed line, is written only while the last one is gone, whole (beside,
-- then renamed), and never left as a temporary; no returned message carries its text. coop-chat.txt is taken and
-- deleted at once: "in <text>" is her line, "fail" says ours could not go, anything else is ignored.
local SAY,CHAT='C:\\Mod\\coop-say.txt','C:\\Mod\\coop-chat.txt'
ok,message=link.say('Salut é à tous')
assert(ok and files[SAY]=='Salut é à tous\n' and not files[SAY..'.tmp'],message)
ok,message=link.say('the second')
assert(not ok and message=='busy' and files[SAY]=='Salut é à tous\n','The native part has not taken the first')
files[SAY]=nil
fs.write=function(path,text) write(path,text); return false end -- A disk full after a part.
ok,message=link.say('the third')
assert(not ok and message=='cannot write' and not files[SAY] and not files[SAY..'.tmp'])
fs.write=write
local rename=fs.rename
fs.rename=function() return nil,'denied' end
ok,message=link.say('the fourth')
assert(not ok and message=='cannot write' and not files[SAY] and not files[SAY..'.tmp'])
fs.rename=rename
assert(#link.take_chat()==0,'Nothing waiting')
files[CHAT]='in Coucou\nfail\nin ça va ?\nin \njunk\nfail now\nin  two spaces\n'
local chat=link.take_chat()
assert(#chat==4 and chat[1].text=='Coucou' and chat[2].fail and chat[3].text=='ça va ?' and chat[4].text==' two spaces')
assert(files[CHAT]==nil and #link.take_chat()==0,'Taken: deleted at once')
local remove=fs.remove
fs.remove=function() return nil,'in use' end -- An indexer holds it: read again next time, never shown twice.
files[CHAT]='in once\n'
assert(#link.take_chat()==0 and files[CHAT]=='in once\n')
fs.remove=remove
chat=link.take_chat()
assert(#chat==1 and chat[1].text=='once' and files[CHAT]==nil and #link.take_chat()==0)

-- The HUD's fields, as of the last changes(): her vitals (mate=, never logged as they change four times a second),
-- the first peer's RTT (its last rtt_ms=, as a Steam name may hold one), and whether a chat session holds: a friend
-- linked (lost or not), a rejoin under way, or the loopback.
local MATE='mate=900 1600 0 50 5 200 1000 0 0 0 0 1\n'
files[STATUS]=HEAD..'peer=2 name=x rtt_ms=5 session=3 session_ping=4 hello=1 accepted=1 compatible=1 lost=0 '
    ..'invalid=0 rtt_ms=118 session=3 session_ping=40\nfriend=1 0 x\n'..MATE..'last=#9 x\n'
lines=fresh.changes()
for _,line in ipairs(lines) do assert(not line:find('^mate='),'mate= stays out of the log') end
local mate=fresh.mate()
assert(mate.hp==900 and mate.max_hp==1600 and mate.shield==0 and mate.max_shield==50 and mate.blocks==5
    and mate.beta==200 and mate.max_beta==1000 and mate.burst==0 and mate.max_burst==0 and mate.tachy==0
    and mate.max_tachy==0 and mate.life==1)
assert(fresh.ping()==118 and fresh.chatting()==true)
files[STATUS]=HEAD..'peer=2 name=x hello=1 accepted=0 compatible=1 lost=0 invalid=0 rtt_ms=-1 session=1 '
    ..'session_ping=-1\nfriend=0 0 x mate=1 2 3 4 5 6 7 8 9 10 11 12\nmate=1 2 3\n'
fresh.changes()
assert(fresh.mate()==nil and fresh.ping()==nil and fresh.chatting()==false,'No vitals, no RTT, not linked')
files[STATUS]=HEAD..'friend=1 1 x\n'
fresh.changes()
assert(fresh.chatting()==true and fresh.mate()==nil,'Lost but linked: the session holds')
files[STATUS]='mod=v steam=ready\nlink=none lobby=0 rejoin=1/3\n'
fresh.changes()
assert(fresh.chatting()==true,'A rejoin keeps the session')
-- Back in her lobby, rejoin= is gone before the handshake: the session holds until she is linked, then as any link.
local GUEST='mod=v steam=ready\nlink=guest lobby=7000\n'
for _,step in ipairs({{nil,nil},{GUEST,true},{GUEST..'friend=0 0 Host\n',true},{GUEST..'friend=1 0 Host\n',true},
        {GUEST..'friend=0 0 Host\n',false},{'mod=v steam=ready\nlink=none lobby=0 rejoin=2/3\n',true},
        {'mod=v steam=ready\nlink=none lobby=0\n',false},{GUEST..'friend=0 0 Host\n',false}}) do
    files[STATUS]=step[1]
    fresh.changes()
    assert(fresh.chatting()==step[2],tostring(step[1])) -- The first: an unread status, which ends nothing (nil).
end
for _,engine in ipairs({'engine=on loopback=on 0 0 0','engine=on loopback=waiting'}) do
    files[STATUS]='mod=v steam=ready\n'..engine..'\nlink=none lobby=0\n'..MATE
    fresh.changes()
    assert(fresh.chatting()==true and fresh.mate().hp==900,'The loopback: a session, with our own vitals')
end
files[STATUS]='mod=v steam=ready\nengine=on\nlink=none lobby=0\nfriend=0 0 x loopback=on 0 0 0\n'
fresh.changes()
assert(fresh.chatting()==false,'Only the pose path\'s line says loopback')
files[STATUS]='mod=v steam=waiting\nengine=on loopback=on 0 0 0\n'
fresh.changes()
assert(fresh.chatting()==false,'Before Steam is ready, the native part would drop a line without a word')
files[STATUS]=nil
fresh.changes()
assert(fresh.chatting()==nil and fresh.mate()==nil and fresh.ping()==nil,'Not read: nil, which ends nothing')
-- An object path kept across Lua loads: the ghost's in coop-puppet.txt, the UI root's in a file of its own.
local ghost,ui=link.store(),link.store('coop-ui.txt')
assert(ghost.save('/Game/Maps/E04.Actor_1') and ui.save('/Engine/Transient.UserWidget_7'))
assert(files['C:\\Mod\\coop-puppet.txt']=='/Game/Maps/E04.Actor_1\n' and ui.load()=='/Engine/Transient.UserWidget_7')
ui.clear()
assert(ui.load()==nil and ghost.load()=='/Game/Maps/E04.Actor_1')
ghost.clear()
-- The real file helper: a write the disk refused (/dev/full takes the open, then fails the flush) is false, so put()
-- never swaps a cut .tmp over the good file and its backup.
local real=require('link').files
local scratch=os.tmpname()
assert(real.write(scratch,'menu_key=F5\n')==true and real.read(scratch)=='menu_key=F5\n','A plain write')
os.remove(scratch)
local full=io.open('/dev/full','wb')
if full then
    full:close()
    assert(real.write('/dev/full','menu_key=F5\n')==false,'A full disk was reported as written')
end

print('link_test ok')
