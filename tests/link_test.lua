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
files[STATUS]='steamid=1 relay=100\nrole=host lobby=7\npeer=2 name=Bob rtt_ms=40\nlast=#3 Bob is in the lobby\n'
lines=link.changes()
assert(#lines==2 and lines[1]=='role=host lobby=7' and lines[2]=='last=#3 Bob is in the lobby','Peer lines stay out of the log')
assert(link.status():find('peer=2 name=Bob',1,true),'coop status still shows them')

assert(link.session('42-7') and files['C:\\Mod\\coop-session.txt']=='42-7\n')
assert(link.components('generation 1\n') and files['C:\\Mod\\coop-components.txt']=='generation 1\n')
assert(link.components('generation 2\n') and files['C:\\Mod\\coop-components.txt']=='generation 2\n','Replaced, not refused')
assert(link.components(nil) and files['C:\\Mod\\coop-components.txt']==nil,'Removed with the puppet')

assert(link.valid_lobby('109775241234567890') and not link.valid_lobby('12x') and not link.valid_lobby('0'))
print('link_test ok')
