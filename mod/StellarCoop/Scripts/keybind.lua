-- Key settings for the menu's rebind (Options > Controls). The grammar is coop-settings.txt's (link.lua): F1 to F12
-- but F10, with at most one of Shift+, Ctrl+, Alt+; F-key codes do not depend on the keyboard layout and Stellar Blade
-- binds none of them. Additions: Enter for the chat key (D-UI3), none for the host key, once the menu holds Host
-- (D-UI2), and none for the race key, when an older file's keys already hold its F9. A key is {key=UE4SS Key name or
-- nil for none, mod=UE4SS ModifierKey name or nil, name=as the file writes it}.
local K={}
local MODIFIERS={SHIFT='SHIFT',CTRL='CONTROL',ALT='ALT'} -- As written, then UE4SS's ModifierKey name.
local WRITTEN={SHIFT='Shift',CONTROL='Ctrl',ALT='Alt'} -- UE4SS's ModifierKey name, then as written.
local EXTRA={chat_key={ENTER={key='RETURN',name='Enter'}},host_key={NONE={name='none'}},race_key={NONE={name='none'}}}
-- A key setting's value from its text, or nil and why it is refused.
function K.parse(name,text)
    local extra=EXTRA[name] and EXTRA[name][text:upper()]
    if extra then return {key=extra.key,name=extra.name} end
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
-- A key pressed in the rebind prompt (UE4SS's Key and ModifierKey names) as the file writes it; parse() then checks it.
function K.text(key,mod)
    if key=='RETURN' then return 'Enter' end
    return (mod and WRITTEN[mod]..'+' or '')..key
end
-- The other key setting in keys (setting name to key) that holds key, the first in sorted order, or nil. Another
-- modifier is another key; none never clashes.
function K.clash(keys,name,key)
    if not key.key then return nil end
    local names={}
    for other in pairs(keys) do names[#names+1]=other end
    table.sort(names)
    for _,other in ipairs(names) do
        if other~=name and keys[other].name==key.name then return other end
    end
    return nil
end
return K
