-- main.lua's console dispatch with UE4SS stubbed: every coop command reaches the right handler, bad input is refused,
-- and the link is optional (no native part, no Steam link).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local printed,handler,loops={},nil,{}
print=function(text) printed[#printed+1]=text end
RegisterConsoleCommandHandler=function(name,f) assert(name=='coop'); handler=f end
ExecuteInGameThread=function(f) f() end
LoopInGameThreadWithDelay=function(ms,f) loops[#loops+1]={ms=ms,f=f} end
local asked={}
local fake_link={
    request=function(line) asked[#asked+1]=line; return true,'asked the native part: '..line end,
    status=function() return 'mod=v proto=2 steam=ready\nlink=none lobby=0\nlast=#1 ready\n' end,
    changes=function() return {'link=host lobby=7'} end,
    valid_lobby=function(text) return text:match('^%d+$')~=nil end,
}
local toggles=0
package.loaded.puppet={new=function() return {toggle=function() toggles=toggles+1; return true,'puppet' end,tick=function() end} end}
package.loaded.link={new=function() return fake_link end}
package.loaded.version='v9-test'

local function load_main(native_ok)
    package.loadlib=function() if native_ok then return true end return nil,'no dll' end
    printed,handler,loops,asked={},nil,{},{}
    package.loaded.main=nil
    local chunk=assert(loadfile('mod/StellarCoop/Scripts/main.lua'))
    chunk()
end
local function last() return printed[#printed] end
local function coop(...) assert(handler(nil,{...})==true) end

load_main(true)
assert(last():find('Loaded version v9-test',1,true),last())
coop('host'); assert(asked[1]=='host' and last():find('OK: asked the native part: host',1,true),last())
coop('invite'); coop('leave'); coop('report')
assert(asked[2]=='invite' and asked[3]=='leave' and asked[4]=='report')
coop('join'); assert(asked[5]=='join')
coop('join','109775241234567890'); assert(asked[6]=='join 109775241234567890')
coop('join','12x'); assert(#asked==6 and last():find('STOP: a lobby id is digits only',1,true),last())
coop('status'); assert(last():find('OK: mod=v proto=2 steam=ready | link=none lobby=0 | last=#1 ready',1,true),last())
coop('puppet'); assert(toggles==1)
coop('dance'); assert(last():find('Use: coop puppet | host',1,true),last())
coop(); assert(last():find('Use: coop',1,true))
assert(#loops==2 and loops[1].ms==1 and loops[2].ms==250,'puppet every frame, link every 250 ms')
loops[2].f(); assert(last()=='[StellarCoop] link: link=host lobby=7\n',last())

load_main(false)
assert(#loops==1,'No link loop without the native part')
coop('host'); assert(#asked==0 and last():find('STOP: the Steam link needs the native part',1,true),last())
coop('join','123'); assert(last():find('the Steam link needs the native part',1,true),last())
coop('status'); assert(last():find('STOP: no Steam link status yet',1,true),last())
io.stdout:write('main_test ok\n')
