-- main.lua's console dispatch with UE4SS stubbed: every coop command reaches the right handler, bad input is refused,
-- the ghost's capture and remote table are fed every 250 ms, and the link is optional (no native part, no Steam link).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local printed,handler,loops={},nil,{}
print=function(text) printed[#printed+1]=text end
RegisterConsoleCommandHandler=function(name,f) assert(name=='coop'); handler=f end
ExecuteInGameThread=function(f) f() end
LoopInGameThreadWithDelay=function(ms,f) loops[#loops+1]={ms=ms,f=f} end
local asked,sessions,ticks,withdrawn={},{},0,{}
local status_text='mod=v proto=3 steam=ready\nlink=none lobby=0\nlast=#1 ready\n'
local fake_link={
    session=function(token) sessions[#sessions+1]=token; return true end,
    components=function(text) if text==nil then withdrawn[#withdrawn+1]='components' end; return true end,
    display=function(text) if text==nil then withdrawn[#withdrawn+1]='display' end; return true end,
    store=function() return 'store' end,
    remote=function() return 3,1,'loopback' end,
    remote_table=function() return nil end,
    request=function(line) asked[#asked+1]=line; return true,'asked the native part: '..line end,
    status=function() return status_text end,
    changes=function() return {'link=host lobby=7'} end,
    valid_lobby=function(text) return text:match('^%d+$')~=nil end,
}
local native_ok
local captured,remoted={},nil
local fake_capture={tick=function(on) captured[#captured+1]=on; return true,'Capture 7: 3 parts' end,yaw_delta=function() return 0 end}
package.loaded.capture={new=function(publish)
    assert(publish==(native_ok and fake_link.components or nil),'The capture publishes through the link, if any')
    return fake_capture
end}
local toggles,active,basesuits=0,false,0
package.loaded.puppet={new=function(link,capture)
    assert(link==(native_ok and fake_link or nil),'The ghost reads and writes its files through the link, if any')
    assert(capture==fake_capture,'The ghost gets the capture (its offset in loopback)')
    return {toggle=function() toggles=toggles+1; active=not active; return true,'ghost' end,tick=function() end,
        active=function() return active end,status=function() return 'ghost='..(active and 'on' or 'off') end,
        remote=function(g,n,source) remoted={g,n,source} end,place=function() end,
        basesuit=function() basesuits=basesuits+1; return true,'base suit' end}
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
    printed,handler,loops,asked,sessions,ticks,active,withdrawn,captured={},nil,{},{},{},0,false,{},{}
    local chunk=assert(loadfile('mod/StellarCoop/Scripts/main.lua'))
    chunk()
end
local function last() return printed[#printed] end
local function coop(...) assert(handler(nil,{...})==true) end

load_main(true)
assert(last():find('Loaded version v9-test',1,true),last())
assert(withdrawn[1]=='components' and withdrawn[2]=='display','A new load withdraws what an older one published')
coop('host'); assert(asked[1]=='host' and last():find('OK: asked the native part: host',1,true),last())
coop('invite'); coop('leave'); coop('report')
assert(asked[2]=='invite' and asked[3]=='leave' and asked[4]=='report')
coop('join'); assert(asked[5]=='join')
coop('join','109775241234567890'); assert(asked[6]=='join 109775241234567890')
coop('join','12x'); assert(#asked==6 and last():find('STOP: a lobby id is digits only',1,true),last())
coop('status'); assert(last():find('OK: mod=v proto=3 steam=ready | link=none lobby=0 | last=#1 ready | ghost=off',1,true),last())
assert(#sessions==1 and sessions[1]:find('^%d+%-%d+$'),'A session token per load')
loops[1].f(); loops[1].f(); assert(ticks==2,'The native tick runs every frame')
-- The pose path's requests need the ghost on (it publishes her capture); their off forms never do.
local before=#asked
for _,line in ipairs({{'loopback','0','0','0'},{'record'},{'replay'}}) do
    coop(table.unpack(line)); assert(last():find('STOP: turn the ghost on first: coop puppet',1,true),last())
end
assert(#asked==before,'Nothing asked without the ghost')
coop('record','off'); assert(asked[#asked]=='record off')
coop('replay','off'); assert(asked[#asked]=='replay off')
coop('loopback','off'); assert(asked[#asked]=='loopback off')
coop('puppet'); assert(toggles==1)
coop('loopback','120','30','1'); assert(asked[#asked]=='loopback 120 30 1','All three numbers reach the native part')
coop('loopback','0','0','0'); assert(asked[#asked]=='loopback 0 0 0')
coop('record'); assert(asked[#asked]=='record')
coop('replay'); assert(asked[#asked]=='replay')
before=#asked
for _,bad in ipairs({{'120','30'},{'1001','0','0'},{'0','501','0'},{'0','0','101'},{'x','0','0'},{'-1','0','0'},{}}) do
    coop('loopback',table.unpack(bad)); assert(last():find('STOP: Use: coop loopback',1,true),last())
end
coop('record','x'); assert(last():find('STOP: Use: coop record [off]',1,true),last())
coop('replay','now'); assert(last():find('STOP: Use: coop replay [off]',1,true),last())
for _,gone in ipairs({'probe','mirror'}) do -- Phase 3a's, deleted.
    coop(gone,'500'); assert(last():find('Use: coop puppet | host',1,true),last())
end
assert(#asked==before,'Nothing asked on bad input')
coop('basesuit'); assert(basesuits==1 and last():find('OK: base suit',1,true),last())
assert(#loops==2 and loops[1].ms==1 and loops[2].ms==250,'the ghost every frame, the link every 250 ms')
loops[2].f()
assert(table.concat(printed,'|'):find('[StellarCoop] link: link=host lobby=7\n',1,true),'Status lines go to the log')
assert(captured[#captured]==true and last():find('OK: Capture 7',1,true),'The capture runs while the ghost is on')
assert(remoted[1]==3 and remoted[2]==1 and remoted[3]=='loopback','The ghost learns the remote table every 250 ms')
coop('off'); assert(asked[#asked]=='off' and toggles==2 and not active,'off removes the ghost and tells the native part')
loops[2].f(); assert(captured[#captured]==false,'Her capture is withdrawn after coop off')
coop('host'); assert(last():find('STOP: coop off is active until the game restarts',1,true),last())
coop('status'); assert(last():find('OK: mod=v',1,true),'status still answers')
loops[1].f(); assert(ticks==2,'No native tick after coop off')
coop('dance'); assert(last():find('Use: coop puppet | host | invite | join [lobby id] | leave | status | report | loopback <delay ms> <jitter ms> <loss %>|off | record [off] | replay [off] | basesuit | off',1,true),last())
coop(); assert(last():find('Use: coop',1,true))

-- coop off survives a Lua reload: the native part still reports it.
status_text='mod=v proto=3 steam=ready\nlink=none lobby=0\nengine=off reason=coop_off\nlast=#9 coop off\n'
load_main(true)
coop('host'); assert(last():find('coop off is active until the game restarts',1,true),last())
loops[1].f(); assert(ticks==0,'Still no native tick')
-- Only the pose path's line says so: a peer may call herself anything.
status_text='mod=v proto=3 steam=ready\nlink=host lobby=7\npeer=2 name=x reason=coop_off hello=1\nengine=on\nlast=#1 ready\n'
load_main(true)
loops[1].f(); assert(ticks==1,'A peer name never switches the mod off')
status_text='mod=v proto=3 steam=ready\nlink=none lobby=0\nlast=#1 ready\n'

-- Without the native tick export, the pose path's commands say so.
native_ok=true
package.loadlib=function(_,name) if name=='coop_tick' then return nil,'not exported' end return true end
printed,handler,loops,asked={},nil,{},{}
assert(loadfile('mod/StellarCoop/Scripts/main.lua'))()
assert(table.concat(printed,'|'):find('Native tick unavailable: not exported',1,true),table.concat(printed,'|'))
coop('puppet')
for _,name in ipairs({'loopback','record','replay'}) do
    coop(name); assert(last():find('STOP: the native tick is unavailable',1,true),last())
end

load_main(false)
assert(#loops==1,'No link loop without the native part')
coop('host'); assert(#asked==0 and last():find('STOP: the Steam link needs the native part',1,true),last())
coop('join','123'); assert(last():find('the Steam link needs the native part',1,true),last())
coop('status'); assert(last():find('STOP: no Steam link status yet',1,true),last())
io.stdout:write('main_test ok\n')
