-- coop-settings.txt edited from the menu (D-UI4): text in, text out, no file access. set() rewrites the value of the
-- one line the mod reads for a key and keeps every other byte (comments, unknown lines, blank lines, a BOM, CRLF); a
-- key not in the file goes at the end. get() reads a value as link.parse_settings does: a BOM skipped, whole lines
-- within the first 8192 bytes, CRs dropped, names in any case, the last line that names the key winning.
local F={}
local LIMIT=8192 -- link.parse_settings reads no further.
-- The BOM, the lines (split on \n, so a CRLF line keeps its \r) and how many of them the mod reads.
local function split(text)
    local bom=text:match('^\239\187\191') or ''
    local lines={}
    for line in (text:sub(#bom+1)..'\n'):gmatch('([^\n]*)\n') do lines[#lines+1]=line end
    local read,used=#lines,0
    if #text-#bom>LIMIT then
        read=0
        for i,line in ipairs(lines) do
            used=used+#line+1
            if used>LIMIT then break end
            read=i
        end
    end
    return bom,lines,read
end
-- The setting a line names, lowercased, and its value; nil for a comment, a blank or any other line.
local function named(line)
    local name,value=line:gsub('\r',''):match('^%s*([%w_]+)%s*=%s*(.-)%s*$')
    return name and name:lower(),value
end
-- The value of the last line naming key that accept(value) takes (any value without accept), or nil.
function F.get(text,key,accept)
    local _,lines,read=split(text)
    local found=nil
    for i=1,read do
        local name,value=named(lines[i])
        if name==key and (not accept or accept(value)) then found=value end
    end
    return found
end
-- The text with key set to value, or nil and why. value is printable ASCII with no space at either end, so it reads
-- back as written.
function F.set(text,key,value)
    if not key:find('^[%w_]+$') then return nil,'not a setting name: '..key end
    if not value:find('^[ -~]*$') or value:find('^ ') or value:find(' $') then
        return nil,'not a value the mod reads back: '..key
    end
    local bom,lines,read=split(text)
    local last=nil
    for i=1,read do if named(lines[i])==key then last=i end end
    if last then
        local line=lines[last]
        local cr=line:sub(-1)=='\r' and '\r' or ''
        lines[last]=line:gsub('\r',''):match('^%s*[%w_]+%s*=%s*')..value..cr -- Every CR goes, as named() drops them.
    else -- At the end, with the file's own line end; a last line that had none gets one first.
        local cr=text:find('\r\n',1,true) and '\r' or ''
        if lines[#lines]=='' then lines[#lines]=nil elseif cr~='' and lines[#lines]:sub(-1)~='\r' then
            lines[#lines]=lines[#lines]..cr
        end
        lines[#lines+1]=key..'='..value..cr
        lines[#lines+1]=''
    end
    local result=bom..table.concat(lines,'\n')
    if F.get(result,key)~=value then
        return nil,'coop-settings.txt is over '..LIMIT..' bytes: '..key..' would not be read'
    end
    -- A line rewritten longer or shorter moves the limit for the lines after it (the same line numbers before and after;
    -- a line added at the end moves none): no other setting may leave or join what the mod reads.
    local _,after,now=split(result)
    for i=math.min(read,now)+1,last and math.max(read,now) or 0 do
        if named(after[i]) then
            return nil,'coop-settings.txt is over '..LIMIT..' bytes: '..key..' would change what else is read'
        end
    end
    return result
end
return F
