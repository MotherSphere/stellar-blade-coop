-- The Lua side of the files shared with the native part. Lua writes whole files beside and renames them, so the native
-- part never reads one half-written: coop-request.txt (a console request), coop-session.txt (a token per Lua load),
-- coop-components.txt (EVE's capture), coop-display.txt (the ghost built for the remote table), coop-puppet.txt (the
-- ghost's object path, for the next load) and coop-state.txt (a save loaded, the send rate). The native part writes
-- coop-remote.txt (the table the ghost is built from) the same way. Each line of the native coop-status.txt that
-- changed is returned once, for the log; peer lines change with every ping, so they stay in coop status, out of the
-- log. The same read gives the session's mode, the friend and the notices for the screen, each from the start of its
-- own line: a Steam name is never at the start of one.
local Link={}
-- coop-settings.txt is the user's (N5): written with these defaults when absent, never overwritten, never shipped (an
-- update would replace it). F-key codes do not depend on the keyboard layout, and Stellar Blade binds none of them.
Link.DEFAULT=[[
# StellarCoop settings, read when the mod loads (game start, or Ctrl+R). Delete this file to get the defaults back.
# Keys: F1 to F12 except F10, optionally with Shift+, Ctrl+ or Alt+ in front (for example Shift+F7).
host_key=F5
status_key=F6
leave_key=F8
# Your friend's Steam name above her ghost: on or off.
name_tag=on
# Poses sent to your friend a second: 10 to 30.
send_rate=20
]]
local DEFAULTS={host_key='F5',status_key='F6',leave_key='F8',name_tag='on',send_rate='20'}
local KEYS={'host_key','status_key','leave_key'}
local MODIFIERS={SHIFT='SHIFT',CTRL='CONTROL',ALT='ALT'} -- As written, then UE4SS's ModifierKey name.
-- A setting's value from its text, or nil and why it is refused. A key is {key='F7', mod='SHIFT' or nil, name='Shift+F7'}.
local function setting(name,text)
    if name=='name_tag' then
        text=text:lower()
        if text=='on' or text=='off' then return text=='on' end
        return nil,'use on or off'
    elseif name=='send_rate' then
        local rate=text:match('^%d+$') and tonumber(text)
        if rate and rate>=10 and rate<=30 then return rate end
        return nil,'use 10 to 30'
    end
    local prefix,number=text:upper():match('^(%a+)%+F([1-9]%d?)$')
    if not prefix then number=text:upper():match('^F([1-9]%d?)$') end
    number=tonumber(number)
    if not number or number>12 or (prefix and not MODIFIERS[prefix]) then
        return nil,'use F1 to F12, with at most one of Shift+, Ctrl+, Alt+'
    end
    if number==10 then return nil,'F10 opens the console' end -- And ~ never parses: both open it on AZERTY.
    local shown=(prefix and prefix:sub(1,1)..prefix:sub(2):lower()..'+' or '')..'F'..number
    return {key='F'..number,mod=MODIFIERS[prefix],name=shown}
end
-- The settings from the file's text, and the log lines for what was refused: a bad value keeps its default.
function Link.parse_settings(text)
    local settings,notes,n={},{},0
    for name,value in pairs(DEFAULTS) do settings[name]=setting(name,value) end
    text=text:gsub('^\239\187\191','') -- Notepad's "UTF-8 with BOM".
    if #text>4096 then -- Whole lines only: a cut F11 would read as F1.
        text=text:sub(1,4096):match('^.*\n') or ''
        notes[1]='settings: only the first 4096 bytes are read'
    end
    for line in ((text:gsub('\r',''))..'\n'):gmatch('([^\n]*)\n') do
        n=n+1
        if not line:find('^%s*$') and not line:find('^%s*#') then
            local name,value=line:match('^%s*([%w_]+)%s*=%s*(.-)%s*$')
            local key=name and name:lower()
            if not DEFAULTS[key] then
                notes[#notes+1]=string.format("settings: line %d: unknown setting '%s', ignored",n,name or line:match('^%s*(.-)%s*$'))
            else
                local parsed,why=setting(key,value)
                if why then
                    notes[#notes+1]=string.format("settings: line %d: '%s' is not allowed for %s (%s); %s stays %s",
                        n,value,key,why,key,DEFAULTS[key])
                else
                    settings[key]=parsed
                end
            end
        end
    end
    -- Two actions on one key would both run on each press: all three go back to the defaults.
    local taken={}
    for _,name in ipairs(KEYS) do
        local shown=settings[name].name
        if taken[shown] then
            notes[#notes+1]='settings: '..shown..' is set for two actions: default keys used'
            for _,key in ipairs(KEYS) do settings[key]=setting(key,DEFAULTS[key]) end
            break
        end
        taken[shown]=true
    end
    return settings,notes
end
local files={
    read=function(path) local f=io.open(path,'rb'); if not f then return nil end; local text=f:read('a'); f:close(); return text end,
    write=function(path,text) local f=io.open(path,'wb'); if not f then return false end; f:write(text); f:close(); return true end,
    remove=os.remove,
    rename=os.rename,
}
function Link.new(folder,fs)
    fs=fs or files
    local function path(name) return folder..'\\'..name end
    local status_path=path('coop-status.txt')
    local seen,remote={},{}
    -- As of the last changes(); dead: the worker stopped for good (a fault or another Steamworks build); held: an
    -- invite waits for a save; shown: the last notice number handed out.
    local mode,friend,listed,dead,held,shown=nil,nil,nil,false,nil,nil
    local self={}
    local function put(name,text,keep)
        local final=path(name)
        local temp=final..'.tmp'
        if not fs.write(temp,text) then return false,'cannot write '..temp end
        if not keep then fs.remove(final) end -- An untaken file: the newest wins (rename never replaces on Windows).
        local ok,why=fs.rename(temp,final)
        if not ok then return false,'cannot write '..name..': '..tostring(why) end
        return true
    end
    function self.request(line)
        local ok,why=put('coop-request.txt',line..'\n')
        if not ok then return false,why end
        return true,'asked the native part: '..line
    end
    function self.session(token) return put('coop-session.txt',token..'\n') end
    -- coop-state.txt: whether a save is loaded (held invites wait for one) and the poses sent a second. Written when
    -- its text changes, and remembered only once written, so a failed write is tried again; returns the line it wrote.
    local state=nil
    function self.state(world,rate)
        local line=string.format('world=%d rate=%d',world and 1 or 0,rate)
        if line==state or not put('coop-state.txt',line..'\n') then return nil end
        state=line
        return line
    end
    local function put_or_remove(name,text)
        if text then return put(name,text) end
        fs.remove(path(name))
        return true
    end
    -- EVE's capture, or nil when it is withdrawn.
    function self.components(text) return put_or_remove('coop-components.txt',text) end
    -- The ghost built for the remote table, or nil when there is none.
    function self.display(text) return put_or_remove('coop-display.txt',text) end
    function self.remote_table() return fs.read(path('coop-remote.txt')) end
    function self.status() return fs.read(status_path) end
    -- The ghost's object path, kept across Lua loads so a reload can sweep a ghost left standing.
    function self.store()
        local name='coop-puppet.txt'
        return {
            save=function(object_path) return put(name,object_path..'\n') end,
            load=function() local text=fs.read(path(name)); return text and text:match('^[^\r\n]+') end,
            clear=function() fs.remove(path(name)) end,
        }
    end
    -- The remote table the native part holds, from its status ("remote=<generation> <count> <source>") as of the last
    -- changes(): its generation, how many times it wrote coop-remote.txt (a new count: read it again) and where it came
    -- from ('loopback', 'replay' or 'peer'); all nil when there is none.
    function self.remote() return remote[1],remote[2],remote[3] end
    function self.changes()
        local text,now,new=fs.read(status_path),{},{}
        -- From the pose path's line only: a peer line before it carries a Steam name the other player chooses.
        local engine=('\n'..(text or '')):match('\nengine=[^\r\n]*') or ''
        local generation,count,source=engine:match(' remote=(%d+) (%d+) (%a+)')
        remote={tonumber(generation),tonumber(count),source}
        mode,friend,listed,dead,held=nil,nil,nil,false,nil
        if not text then return new end
        listed={}
        for line in text:gmatch('[^\r\n]+') do
            now[line]=true
            if not seen[line] and not line:find('^peer=') then new[#new+1]=line end
            if not mode and line:find('^link=') then mode,held=line:match('^link=(%a+)'),line:match(' held=(%d+)') end
            dead=dead or line:find('^stopped=')~=nil or line:find('^missing=')~=nil
            local linked,lost,name=line:match('^friend=([01]) ([01]) (.*)$')
            if name then friend={name,linked=='1',lost=='1'} end
            local n,notice=line:match('^notice=(%d+) (.*)$')
            if n then listed[#listed+1]={tonumber(n),notice} end
        end
        seen=now
        return new
    end
    -- 'none', 'host' or 'guest'; nil before Steam is ready.
    function self.mode() return mode end
    -- The first peer: her Steam name, linked (hello accepted, compatible), lost; nil without one.
    function self.friend() if friend then return friend[1],friend[2],friend[3] end end
    -- The notices numbered above the last one handed out, oldest first. The first call only primes the count, so a
    -- Lua reload never shows old ones again (changes() already logged them). Only a status that was read primes it.
    function self.notices()
        if not listed then return {} end
        local texts,top={},listed[#listed]
        for _,item in ipairs(listed) do
            if shown and item[1]>shown then texts[#texts+1]=item[2] end
        end
        shown=math.max(shown or 0,top and top[1] or 0)
        return texts
    end
    -- The status key's line.
    function self.summary()
        if dead then return 'Co-op: the Steam link stopped; coop status says why.' end
        if not mode then return 'Co-op: waiting for Steam.' end
        if held then return 'Co-op: invite held until your save has loaded.' end
        if mode=='none' then return 'Co-op: not in a session.' end
        local name,linked,lost=self.friend()
        local text
        if not name and mode=='host' then text='Co-op: hosting, no friend yet.'
        elseif not linked then text='Co-op: '..(name or 'your friend')..' is connecting.'
        elseif mode=='host' then text='Co-op: hosting '..name..'.'
        else text='Co-op: in '..name.."'s game." end
        return lost and text..' Connection lost.' or text
    end
    -- The settings and their log lines. A file that cannot be read is kept as well: the rename fails if it exists.
    function self.settings()
        local text,wrote=fs.read(path('coop-settings.txt')),nil
        if not text then
            text=Link.DEFAULT
            local ok,why=put('coop-settings.txt',text,true)
            wrote=ok and 'settings: coop-settings.txt written with the defaults'
                or 'settings: cannot write coop-settings.txt ('..tostring(why)..'): defaults used'
        end
        local settings,notes=Link.parse_settings(text)
        if wrote then table.insert(notes,1,wrote) end
        return settings,notes
    end
    function self.valid_lobby(text) return text:match('^%d+$')~=nil and text:match('^0+$')==nil end
    return self
end
return Link
