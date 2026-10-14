-- The Lua side of the files shared with the native part. Lua writes whole files beside and renames them, so the native
-- part never reads one half-written: coop-request.txt (a console request), coop-session.txt (a token per Lua load),
-- coop-components.txt (EVE's capture), coop-display.txt (the ghost built for the remote table) and coop-puppet.txt (the
-- ghost's object path, for the next load). The native part writes coop-remote.txt (the table the ghost is built from)
-- the same way. Each line of the native coop-status.txt that changed is returned once, for the log; peer lines change
-- with every ping, so they stay in coop status, out of the log.
local Link={}
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
    local self={}
    local function put(name,text)
        local final=path(name)
        local temp=final..'.tmp'
        if not fs.write(temp,text) then return false,'cannot write '..temp end
        fs.remove(final) -- An untaken file: the newest wins (rename never replaces on Windows).
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
        if not text then return new end
        for line in text:gmatch('[^\r\n]+') do
            now[line]=true
            if not seen[line] and not line:find('^peer=') then new[#new+1]=line end
        end
        seen=now
        return new
    end
    function self.valid_lobby(text) return text:match('^%d+$')~=nil and text:match('^0+$')==nil end
    return self
end
return Link
