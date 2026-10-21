-- coop-settings.txt edited from the menu (D-UI4): one line rewritten in place, every other byte kept (comments, unknown
-- lines, blank lines, a BOM, CRLF); the line rewritten is the one link.parse_settings uses, so the new value is the one
-- the mod reads; a key not in the file is added at the end; a value that would not read back is refused. get() reads a
-- value the way link.parse_settings does.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local F=require('settings_file')
local Link=require('link')

-- One line changes, the rest of the default file stays byte for byte, and the mod reads the new value.
local text=assert(F.set(Link.DEFAULT,'menu_key','Shift+F7'))
assert(text==Link.DEFAULT:gsub('\nmenu_key=F5\n','\nmenu_key=Shift+F7\n'),text)
local s,notes=Link.parse_settings(text)
assert(#notes==0 and s.menu_key.name=='Shift+F7' and s.status_key.name=='F6')
text=assert(F.set(Link.DEFAULT,'fight_chars','15011001 15011002'))
assert(text==Link.DEFAULT:gsub('\nfight_chars=auto\n','\nfight_chars=15011001 15011002\n'))
assert(F.set(Link.DEFAULT,'fight_chars','auto')==Link.DEFAULT,'The value it has already')
assert(F.set(text,'fight_chars','')==Link.DEFAULT:gsub('\nfight_chars=auto\n','\nfight_chars=\n'),
    'An empty value is a value')

-- A commented example is a comment: the key goes at the end instead, and the comment stays.
text=assert(F.set(Link.DEFAULT,'cloth','on'))
assert(text==Link.DEFAULT..'cloth=on\n' and text:find('# For example: cloth=on\n',1,true))
assert(Link.parse_settings(text).cloth==true)

-- Comments, unknown lines, blank lines, spacing and case of the line's own name are kept; trailing spaces go.
local mine='# mine\n\ncolour=red\n  SEND_RATE = 12  \n# send_rate=30\nname_tag=off\n'
assert(F.set(mine,'send_rate','25')=='# mine\n\ncolour=red\n  SEND_RATE = 25\n# send_rate=30\nname_tag=off\n')

-- A BOM and CRLF (Notepad): kept, and an added line follows the file's line ends.
local crlf='\239\187\191host_key=F7\r\nname_tag=on\r\n'
assert(F.set(crlf,'name_tag','off')=='\239\187\191host_key=F7\r\nname_tag=off\r\n')
assert(F.set(crlf,'send_rate','30')==crlf..'send_rate=30\r\n')
assert(F.set('host_key=F7\r\nname_tag=on','send_rate','30')=='host_key=F7\r\nname_tag=on\r\nsend_rate=30\r\n',
    'A last line with no end gets one of the same kind')
assert(F.set('name_tag=on','send_rate','30')=='name_tag=on\nsend_rate=30\n')
assert(F.set('','send_rate','30')=='send_rate=30\n')
assert(F.set('name_tag=on','name_tag','off')=='name_tag=off','No line end added to a line that had none')
-- A CR inside the name (a hand edit): the mod drops it, so the line names the key and is rewritten.
assert(Link.parse_settings('menu\r_key=F7\n').menu_key.name=='F7')
assert(F.set('host\r_key=F7\r\n','host_key','F9')=='host_key=F9\r\n')

-- Two lines for one key: the later one is the one the mod reads, so that one is rewritten.
local twice='send_rate=12\nsend_rate=14\n'
assert(F.set(twice,'send_rate','25')=='send_rate=12\nsend_rate=25\n')
assert(Link.parse_settings(F.set(twice,'send_rate','25')).send_rate==25)
-- Even when that later line holds a refused value (the mod reads the earlier one today): after the change, it counts.
twice='send_rate=12\nsend_rate=99\n'
assert(Link.parse_settings(twice).send_rate==12)
assert(Link.parse_settings(F.set(twice,'send_rate','25')).send_rate==25)

-- The mod reads whole lines within the first 8192 bytes only (link.parse_settings).
local pad='#'..string.rep('x',8190)..'\n' -- 8192 bytes: a line after it is never read.
local text2,why=F.set(pad..'send_rate=12\n','send_rate','25')
assert(text2==nil and why=='coop-settings.txt is over 8192 bytes: send_rate would not be read',why)
assert(F.set(pad,'send_rate','25')==nil,'Nor added after them')
local near='#'..string.rep('x',8176)..'\nsend_rate=12\n' -- 8191 bytes.
assert(Link.parse_settings(near).send_rate==12)
text2,why=F.set(near,'send_rate','1234')
assert(text2==nil and why:find('over 8192 bytes',1,true),'Longer, the line would fall out of what is read')
assert(F.set(near,'send_rate','13')==near:gsub('=12','=13'),'Same length: fine')
local bom='\239\187\191#'..string.rep('x',8176)..'\nsend_rate=12\n' -- The BOM is not counted, as in the mod.
assert(Link.parse_settings(bom).send_rate==12 and F.set(bom,'send_rate','13')==bom:gsub('=12','=13'))
-- A longer or shorter value moves the limit for the lines after it: no other setting may leave or join what is read.
local fill='#'..string.rep('x',8165)..'\n'
local edge='host_key=F5\n'..fill..'leave_key=F9\n' -- 8192 bytes: leave_key ends on the last byte read.
assert(Link.parse_settings(edge).leave_key.name=='F9')
text2,why=F.set(edge,'host_key','Shift+F5')
assert(text2==nil and why=='coop-settings.txt is over 8192 bytes: host_key would change what else is read',why)
local past='host_key=Shift+F5\n'..fill..'leave_key=F9\n' -- leave_key ends past byte 8192: not read.
assert(Link.parse_settings(past).leave_key.name=='F8')
text2,why=F.set(past,'host_key','F5')
assert(text2==nil and why:find('what else is read',1,true),'Shorter, leave_key would be read')
assert(F.set(past,'host_key','Shift+F6')==past:gsub('F5','F6',1),'Same length: fine')
local tail='host_key=F5\n#'..string.rep('x',8169)..'\n#tail\n' -- A comment leaving what is read changes nothing.
assert(Link.parse_settings(assert(F.set(tail,'host_key','Shift+F5'))).menu_key.name=='Shift+F5','No menu_key: the menu')

-- Refused: a name the mod would not read, or a value that would not read back as written.
for _,bad in ipairs({{'host key','F7'},{'','F7'},{'host_key','F7\n'},{'host_key','F7\r'},{'host_key',' F7'},
    {'host_key','F7 '},{'host_key','F\0007'},{'host_key','F7\t'},{'host_key','\195\169'}}) do
    local result,reason=F.set('host_key=F5\n',bad[1],bad[2])
    assert(result==nil and reason:find('^not a ') and not reason:find('8192'),bad[1]..'='..bad[2])
end

-- get(): the last line naming the key within what the mod reads, whose value accept() takes (any when absent).
local function rate(value) local n=tonumber(value); return n and n>=10 and n<=60 end
assert(F.get(Link.DEFAULT,'send_rate')=='60' and F.get(Link.DEFAULT,'cloth')==nil)
assert(F.get('SEND_RATE = 12 \r\n','send_rate')=='12','Name case, spaces and CR as the mod reads them')
assert(F.get('send_rate=12\nsend_rate=99\n','send_rate')=='99')
assert(F.get('send_rate=12\nsend_rate=99\n','send_rate',rate)=='12','The last value accept() takes')
assert(F.get(pad..'send_rate=12\n','send_rate')==nil,'Not past 8192 bytes')
assert(F.get('\239\187\191send_rate=12','send_rate')=='12')
-- The same answer as the mod's parser, on texts with the same traps.
for _,case in ipairs({Link.DEFAULT,'send_rate=12\nsend_rate=99\n','send_rate=x\n','  SEND_RATE=25\r\n',near,bom,
    pad..'send_rate=12\n','# send_rate=12\n','\239\187\191send_rate=13'}) do
    assert(tonumber(F.get(case,'send_rate',rate) or '60')==Link.parse_settings(case).send_rate,case:sub(1,40))
end

print('settings_file_test ok')
