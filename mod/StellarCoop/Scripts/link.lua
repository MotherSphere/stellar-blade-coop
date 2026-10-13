-- The Steam link's Lua side. A console request becomes one line in coop-request.txt for the native part (written
-- beside, then renamed, so it is never read half-written); each line of its coop-status.txt that changed is
-- returned once, for the log.
local Link={}
local files={
    read=function(path) local f=io.open(path,'rb'); if not f then return nil end; local text=f:read('a'); f:close(); return text end,
    write=function(path,text) local f=io.open(path,'wb'); if not f then return false end; f:write(text); f:close(); return true end,
    remove=os.remove,
    rename=os.rename,
}
function Link.new(folder,fs)
    fs=fs or files
    local request_path,status_path=folder..'\\coop-request.txt',folder..'\\coop-status.txt'
    local seen={}
    local self={}
    function self.request(line)
        local temp=request_path..'.tmp'
        if not fs.write(temp,line..'\n') then return false,'cannot write '..temp end
        fs.remove(request_path) -- An untaken request: the newest wins (rename never replaces on Windows).
        local ok,why=fs.rename(temp,request_path)
        if not ok then return false,'cannot write the request: '..tostring(why) end
        return true,'asked the native part: '..line
    end
    function self.status() return fs.read(status_path) end
    function self.changes()
        local text,now,new=fs.read(status_path),{},{}
        if not text then return new end
        for line in text:gmatch('[^\r\n]+') do
            now[line]=true
            if not seen[line] then new[#new+1]=line end
        end
        seen=now
        return new
    end
    function self.valid_lobby(text) return text:match('^%d+$')~=nil and text:match('^0+$')==nil end
    return self
end
return Link
