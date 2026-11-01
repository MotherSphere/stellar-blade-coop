-- The crash sentinel for mod assets. Before the ghost (partner/puppet.lua) hands the engine an asset your CNS packs
-- declare (its load, SetSkeletalMesh, SetMaterial, a dynamic instance and its values, the hidden slots), call() writes
-- coop-cns-call.txt with that asset's path and outfit, and empties it once the call returns or raises. Only that span
-- is marked: a crash anywhere else finds the file empty. A file still full at the next Lua load means the game died
-- inside such a call, so new() puts that asset on the set-aside list (coop-cns-aside.txt, under the mod's version),
-- empties the marker and returns the asset, for the log and a notice. The ghost draws a set-aside asset as missing
-- (aside()). reset() empties the list (coop cns reset), and a list written by another version is dropped at load.
local Sentinel={}
Sentinel.MARKER,Sentinel.LIST='coop-cns-call.txt','coop-cns-aside.txt'
-- files: core/link.lua's link (read_file, write_file, write_now, cns_assets), or nil without the native part: then
-- nothing is marked or set aside. version: the mod's (main.lua's VERSION). Returns the sentinel, and {path=, outfit=}
-- when the last Lua load's game died during a call.
function Sentinel.new(files,version)
    local self,aside,list,depth={},{},{},0
    if not files then
        function self.call(_,f,...) return f(...) end
        function self.aside() return nil end
        function self.reset() return 0 end
        function self.list() return {} end
        return self
    end
    local function add(path,outfit)
        if aside[path] then return end
        aside[path]=outfit
        list[#list+1]={path=path,outfit=outfit}
    end
    local function save()
        local lines={'version '..version}
        for _,a in ipairs(list) do lines[#lines+1]=a.path..' '..a.outfit end
        return files.write_file(Sentinel.LIST,table.concat(lines,'\n')..'\n')
    end
    local text=files.read_file(Sentinel.LIST)
    local same=text and text:match('^version (%S+)')==version
    if same then
        for path,outfit in text:gmatch('\n(%S+) (%S+)') do add(path,outfit) end
    end
    local marker=files.read_file(Sentinel.MARKER)
    local path,outfit=(marker or ''):match('^(%S+) (%S+)')
    local crashed=path and {path=path,outfit=outfit} or nil
    if crashed then add(path,outfit) end
    if crashed or text and not same then save() end
    if marker and marker~='' then files.write_now(Sentinel.MARKER,'') end
    -- f(...) with the marker naming path while it runs, when path is an asset your CNS packs declare; the marker is
    -- emptied whether f returns or raises, and f's error raised again. A call inside another's span keeps the outer
    -- marker. One small write before, one after: never per frame.
    function self.call(path,f,...)
        local outfit_of=depth==0 and files.cns_assets()[path]
        if not outfit_of then return f(...) end
        depth=1
        files.write_now(Sentinel.MARKER,path..' '..outfit_of..'\n')
        local r=table.pack(pcall(f,...))
        files.write_now(Sentinel.MARKER,'')
        depth=0
        if not r[1] then error(r[2],0) end
        return table.unpack(r,2,r.n)
    end
    -- The outfit of a set-aside asset, nil for any other.
    function self.aside(path_of) return aside[path_of] end
    -- The list emptied (kept on disk with the version line only); returns how many it held.
    function self.reset()
        local n=#list
        aside,list={},{}
        save()
        return n
    end
    -- The set-aside assets, in the order they were set aside: {path=, outfit=} each.
    function self.list()
        local copy={}
        for k,a in ipairs(list) do copy[k]={path=a.path,outfit=a.outfit} end
        return copy
    end
    return self,crashed
end
return Sentinel
