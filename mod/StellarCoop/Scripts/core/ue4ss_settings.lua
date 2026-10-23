-- UE4SS's own settings, UE4SS-settings.ini beside UE4SS.dll and its Mods folder: main.lua reads it once a Lua load, at
-- most LIMIT bytes, and never writes it. Two of its keys make Stellar Blade unstable. HookBeginPlay ([Hooks]) on makes
-- the game crash when EVE lets go of a movable crate (issue #3 of Chrisr0's RE-UE4SS; the Stellar Blade UE4SS 1.3
-- author names CNS's own UE4SS-settings.ini, copied over the package's, as the usual cause). bUseUObjectArrayCache
-- ([General]) on brings stutter and crashes at startup. The 1.3 package ships HookBeginPlay = 0 and
-- bUseUObjectArrayCache = false; a key UE4SS does not find takes its compiled default, on for both. Text in, no file
-- access.
local S={}
S.LIMIT=65536 -- Bytes; the 1.3 package's file has 7638.
-- The keys checked: section and key as UE4SS names them, and the word of their notice in ui/text.lua's ue4ss group.
S.KEYS={{section='Hooks',key='HookBeginPlay',word='hook'},{section='General',key='bUseUObjectArrayCache',word='cache'}}
-- The keys of S.KEYS that UE4SS reads as on in text, in S.KEYS's order, each {key=, word=, value=}: value as written,
-- nil when its section lacks the key. Section and key names in any case, a BOM, CRLF, spaces around '=' and the
-- value, comment lines (';' or '#') and a comment after the value; the last line naming a key in its section wins.
-- Off is 0 or false in any case. Any other value counts as on, so a value this cannot read errs toward a notice. nil
-- and why for a text over LIMIT bytes.
function S.check(text)
    if #text>S.LIMIT then return nil,'over '..S.LIMIT..' bytes' end
    local values,section={},nil
    for line in (text:gsub('^\239\187\191','')..'\n'):gmatch('([^\n]*)\n') do
        local head=line:match('^%s*%[([^%]]*)%]')
        if head then section=head:match('^%s*(.-)%s*$'):lower()
        elseif section then
            local key,value=line:match('^%s*([%w_]+)%s*=%s*([^%s;#]*)')
            if key then values[section..'.'..key:lower()]=value end
        end
    end
    local on={}
    for _,k in ipairs(S.KEYS) do
        local value=values[k.section:lower()..'.'..k.key:lower()]
        local v=value and value:lower()
        if v~='0' and v~='false' then on[#on+1]={key=k.key,word=k.word,value=value} end
    end
    return on
end
return S
