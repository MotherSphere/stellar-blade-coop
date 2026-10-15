-- main.lua's console dispatch with UE4SS stubbed: every coop command reaches the right handler, bad input is refused,
-- the ghost's capture and remote table are fed every 250 ms, the keys only hand their action to the game thread, and
-- the link is optional (no native part, no Steam link, no keys).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local printed,handler,loops={},nil,{}
print=function(text) printed[#printed+1]=text end
RegisterConsoleCommandHandler=function(name,f) assert(name=='coop'); handler=f end
local queued,executes,binds={},0,{}
ExecuteInGameThread=function(f) executes=executes+1; queued[#queued+1]=f end
local function flush() local now=queued; queued={}; for _,f in ipairs(now) do f() end end
-- Values unlike the names, so a raw setting string never passes for UE4SS's code.
Key=setmetatable({},{__index=function(_,name) return 'Key.'..name end})
ModifierKey={SHIFT=0x10,CONTROL=0x11,ALT=0x12}
-- As strict as UE4SS: (key, callback) or (key, table, callback), nothing else ("No overload found").
RegisterKeyBind=function(key,...)
    local modifiers,f=...
    if select('#',...)==1 then modifiers,f=nil,modifiers
    else assert(select('#',...)==2 and type(modifiers)=='table','No overload found for RegisterKeyBind') end
    assert(type(f)=='function','No overload found for RegisterKeyBind')
    binds[#binds+1]={key=key,modifiers=modifiers,f=f}
end
local function mod(modifiers) return modifiers and modifiers[1] end
IsKeyBindRegistered=function(key,modifiers)
    if key=='Key.F6' and modifiers==nil then return true end -- A mod loaded earlier holds F6.
    for _,bind in ipairs(binds) do if bind.key==key and mod(bind.modifiers)==mod(modifiers) then return true end end
    return false
end
local function press(key) for _,bind in ipairs(binds) do if bind.key=='Key.'..key then return bind.f() end end error(key) end
local settings_text=''
local Link=dofile('mod/StellarCoop/Scripts/link.lua') -- The real parser behind the fake link.
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
    settings=function() return Link.parse_settings(settings_text) end,
}
local native_ok
local captured,remoted={},nil
local fake_capture={tick=function(on) captured[#captured+1]=on; return true,'Capture 7: 3 parts' end,yaw_delta=function() return 0 end}
package.loaded.capture={new=function(publish)
    assert(publish==(native_ok and fake_link.components or nil),'The capture publishes through the link, if any')
    return fake_capture
end}
local toggles,active,basesuits,wheres=0,false,0,0
package.loaded.puppet={new=function(link,capture)
    assert(link==(native_ok and fake_link or nil),'The ghost reads and writes its files through the link, if any')
    assert(capture==fake_capture,'The ghost gets the capture (its offset in loopback)')
    return {toggle=function() toggles=toggles+1; active=not active; return true,'ghost' end,tick=function() end,
        active=function() return active end,status=function() return 'ghost='..(active and 'on' or 'off') end,
        remote=function(g,n,source) remoted={g,n,source} end,place=function() end,
        basesuit=function() basesuits=basesuits+1; return true,'base suit' end,
        where=function() wheres=wheres+1; return true,'where map=/game/e04' end}
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
    queued,binds={},{}
    local chunk=assert(loadfile('mod/StellarCoop/Scripts/main.lua'))
    chunk()
end
local function last() return printed[#printed] end
local function coop(...) assert(handler(nil,{...})==true); flush() end
local function logged(text) return table.concat(printed,'|'):find('[StellarCoop] '..text..'\n',1,true)~=nil end

load_main(true)
assert(last():find('Loaded version v9-test',1,true),last())
assert(withdrawn[1]=='components' and withdrawn[2]=='display','A new load withdraws what an older one published')
-- Keys (N5): the callback runs on UE4SS's key thread, so it only queues the action for the game thread.
assert(logged('keys: host=F5 status=F6 leave=F8, name tag on, 20 poses a second'),table.concat(printed,'|'))
assert(logged('keys: F6 is also bound by a mod loaded earlier; both run') and not logged('keys: F5 is also bound')
    and not logged('keys: F8 is also bound'),'Checked before our own bind')
assert(#binds==3 and binds[1].key=='Key.F5' and binds[2].key=='Key.F6' and binds[3].key=='Key.F8' and not binds[1].modifiers)
local executed=executes
press('F5'); assert(executes==executed+1 and #queued==1 and #asked==0,'Nothing runs before the flush')
flush(); assert(executes==executed+1 and asked[1]=='host' and printed[#printed-1]=='[StellarCoop] key F5: host\n')
assert(last():find('OK: asked the native part: host',1,true),last())
press('F8'); assert(#asked==1); flush(); assert(executes==executed+2 and asked[2]=='leave' and logged('key F8: leave'))
press('F6'); flush(); assert(#asked==2 and last():find('OK: mod=v proto=3',1,true),'Status, until step 3 summarises it')
asked={}
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
coop('where'); assert(wheres==1 and last():find('OK: where map=/game/e04',1,true),last())
assert(#loops==2 and loops[1].ms==1 and loops[2].ms==250,'the ghost every frame, the link every 250 ms')
loops[2].f()
assert(table.concat(printed,'|'):find('[StellarCoop] link: link=host lobby=7\n',1,true),'Status lines go to the log')
assert(captured[#captured]==true and last():find('OK: Capture 7',1,true),'The capture runs while the ghost is on')
assert(remoted[1]==3 and remoted[2]==1 and remoted[3]=='loopback','The ghost learns the remote table every 250 ms')
coop('off'); assert(asked[#asked]=='off' and toggles==2 and not active,'off removes the ghost and tells the native part')
loops[2].f(); assert(captured[#captured]==false,'Her capture is withdrawn after coop off')
coop('host'); assert(last():find('STOP: coop off is active until the game restarts',1,true),last())
local lines
before,lines=#asked,#printed
press('F5'); flush()
assert(#asked==before and #printed==lines+2 and printed[lines+1]=='[StellarCoop] key F5: host\n'
    and printed[lines+2]=='[StellarCoop] STOP: coop off is active until the game restarts\n','A key asks nothing after coop off')
coop('status'); assert(last():find('OK: mod=v',1,true),'status still answers')
loops[1].f(); assert(ticks==2,'No native tick after coop off')
coop('dance'); assert(last():find('Use: coop puppet | host | invite | join [lobby id] | leave | status | report | where | loopback <delay ms> <jitter ms> <loss %>|off | record [off] | replay [off] | basesuit | off',1,true),last())
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

-- A modifier goes with its key; a refused setting is logged and keeps its default.
settings_text='host_key=F10\nleave_key=Ctrl+F8\nsend_rate=25\n'
load_main(true)
assert(logged("settings: line 1: 'F10' is not allowed for host_key (F10 opens the console); host_key stays F5"))
assert(logged('keys: host=F5 status=F6 leave=Ctrl+F8, name tag on, 25 poses a second'),table.concat(printed,'|'))
assert(binds[3].key=='Key.F8' and #binds[3].modifiers==1 and binds[3].modifiers[1]==0x11 and not binds[1].modifiers)
press('F8'); flush(); assert(asked[1]=='leave' and logged('key Ctrl+F8: leave'))
settings_text=''

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
assert(#binds==0 and not logged('keys: host'),'No keys without the native part')
coop('host'); assert(#asked==0 and last():find('STOP: the Steam link needs the native part',1,true),last())
coop('join','123'); assert(last():find('the Steam link needs the native part',1,true),last())
coop('status'); assert(last():find('STOP: no Steam link status yet',1,true),last())
coop('where'); assert(wheres==2 and last():find('OK: where',1,true),'coop where needs no Steam link')
io.stdout:write('main_test ok\n')
