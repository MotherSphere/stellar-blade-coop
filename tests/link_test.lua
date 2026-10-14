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

assert(link.valid_lobby('109775241234567890') and not link.valid_lobby('12x') and not link.valid_lobby('0'))
print('link_test ok')
