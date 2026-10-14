-- main.lua's console dispatch with UE4SS stubbed: every coop command reaches the right handler, bad input is refused,
-- and the link is optional (no native part, no Steam link).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local printed,handler,loops={},nil,{}
print=function(text) printed[#printed+1]=text end
RegisterConsoleCommandHandler=function(name,f) assert(name=='coop'); handler=f end
ExecuteInGameThread=function(f) f() end
LoopInGameThreadWithDelay=function(ms,f) loops[#loops+1]={ms=ms,f=f} end
local asked,sessions,ticks={},{},0
local status_text='mod=v proto=2 steam=ready\nlink=none lobby=0\nlast=#1 ready\n'
local fake_link={
    session=function(token) sessions[#sessions+1]=token; return true end,
    components=function() return true end,
    request=function(line) asked[#asked+1]=line; return true,'asked the native part: '..line end,
    status=function() return status_text end,
    changes=function() return {'link=host lobby=7'} end,
    valid_lobby=function(text) return text:match('^%d+$')~=nil end,
}
local toggles,active=0,false
local native_ok
package.loaded.puppet={new=function(publish)
    assert(publish==(native_ok and fake_link.components or nil),'The puppet publishes through the link, if any')
    return {toggle=function() toggles=toggles+1; active=not active; return true,'puppet' end,tick=function() end,
        active=function() return active end}
end}
package.loaded.link={new=function() return fake_link end}
package.loaded.version='v9-test'

local function load_main(with_native)
    native_ok=with_native
    package.loadlib=function(_,name)
        if not native_ok then return nil,'no dll' end
        if name=='coop_tick' then return function() ticks=ticks+1; return 0 end end
        return true
    end
    printed,handler,loops,asked,sessions,ticks,active={},nil,{},{},{},0,false
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
assert(#sessions==1 and sessions[1]:find('^%d+%-%d+$'),'A session token per load')
loops[1].f(); loops[1].f(); assert(ticks==2,'The native tick runs every frame')
coop('probe'); assert(last():find('STOP: spawn the puppet first',1,true),last())
coop('puppet'); assert(toggles==1)
coop('probe'); assert(asked[#asked]=='probe')
coop('off'); assert(asked[#asked]=='off' and toggles==2 and not active,'off removes the puppet and tells the native part')
coop('host'); assert(last():find('STOP: coop off is active until the game restarts',1,true),last())
coop('status'); assert(last():find('OK: mod=v',1,true),'status still answers')
loops[1].f(); assert(ticks==2,'No native tick after coop off')
coop('dance'); assert(last():find('Use: coop puppet | host',1,true),last())
coop(); assert(last():find('Use: coop',1,true))
assert(#loops==2 and loops[1].ms==1 and loops[2].ms==250,'puppet every frame, link every 250 ms')
loops[2].f(); assert(last()=='[StellarCoop] link: link=host lobby=7\n',last())

-- coop off survives a Lua reload: the native part still reports it.
status_text='mod=v proto=2 steam=ready\nlink=none lobby=0\nengine=off reason=coop_off\nlast=#9 coop off\n'
load_main(true)
coop('host'); assert(last():find('coop off is active until the game restarts',1,true),last())
loops[1].f(); assert(ticks==0,'Still no native tick')
status_text='mod=v proto=2 steam=ready\nlink=none lobby=0\nlast=#1 ready\n'

-- Without the native tick export, coop probe says so.
native_ok=true
package.loadlib=function(_,name) if name=='coop_tick' then return nil,'not exported' end return true end
printed,handler,loops,asked={},nil,{},{}
assert(loadfile('mod/StellarCoop/Scripts/main.lua'))()
assert(table.concat(printed,'|'):find('Native tick unavailable: not exported',1,true),table.concat(printed,'|'))
coop('puppet')
coop('probe'); assert(last():find('STOP: the native tick is unavailable',1,true),last())

load_main(false)
assert(#loops==1,'No link loop without the native part')
coop('host'); assert(#asked==0 and last():find('STOP: the Steam link needs the native part',1,true),last())
coop('join','123'); assert(last():find('the Steam link needs the native part',1,true),last())
coop('status'); assert(last():find('STOP: no Steam link status yet',1,true),last())
io.stdout:write('main_test ok\n')
