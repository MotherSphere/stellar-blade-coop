-- The death and revive status line's Lua side (glue/tick/revive.inc, core/link.lua's revive()): our state, whether our
-- revive is spent, hers, the distance to her EVE (-1 when unread) and whether the native part holds our 1 HP floor; nil
-- without the line, and never from a peer's line or one of another shape. A fake fs and folder, the real Link.new.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local files={}
local fs={read=function(p) return files[p] end,write=function(p,t) files[p]=t; return true end,
    remove=function(p) files[p]=nil; return true end,rename=function(a,b) files[b]=files[a]; return true end}
local Link=dofile('mod/StellarCoop/Scripts/core/link.lua')
local link=Link.new('C:/Mod',fs)
local status='C:/Mod'..string.char(92)..'coop-status.txt'
assert(link.revive()==nil,'No status yet')
files[status]='mod=v\nengine=on revive=alive used=0 partner=none dist=-1 hold=0\nlast=#12 x\n'
link.changes()
local rev=link.revive()
assert(rev and rev.state=='alive' and rev.used==false and rev.partner=='none' and rev.distance==-1 and
    rev.hold==false,'Alive alone')
files[status]='mod=v\r\nengine=on revive=down used=1 partner=down dist=143 hold=1\r\nlast=#13 x\r\n'
link.changes()
rev=link.revive()
assert(rev.state=='down' and rev.used and rev.partner=='down' and rev.distance==143 and rev.hold,'CRLF, down near her')
-- Neither a peer's line nor a line of another shape carries our own state.
files[status]='mod=v\nengine=on\npeer=2 name=x revive=alive used=0 partner=alive dist=1 hold=1\nlast=revive=alive used=1\n'
link.changes()
assert(link.revive()==nil,"Not from a peer's line nor from a line of another shape")
files[status]=nil
link.changes()
assert(link.revive()==nil,'No status: none either')
io.stdout:write('revive_test ok\n')
