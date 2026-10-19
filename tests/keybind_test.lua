-- Key settings for the menu's rebind: the grammar of coop-settings.txt (F1 to F12 but F10, at most one of Shift+,
-- Ctrl+, Alt+), the same answer as link.parse_settings on every case, Enter for the chat key and none for the host key
-- only, a pressed key turned into that text, and a clash found against every other key setting.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local K=require('keybind')
local Link=require('link')

local key=K.parse('status_key','Shift+F7')
assert(key.key=='F7' and key.mod=='SHIFT' and key.name=='Shift+F7')
key=K.parse('menu_key','ctrl+f12')
assert(key.key=='F12' and key.mod=='CONTROL' and key.name=='Ctrl+F12','UE4SS ModifierKey names, the file name shown')
local why
key,why=K.parse('leave_key','F10')
assert(key==nil and why=='F10 opens the console')

-- The same grammar as link.parse_settings, refusals and their reasons included, for the three keys it reads today
-- (host_key=none, below, is new).
for _,text in ipairs({'F5','f6','Shift+F7','shift+f7','SHIFT+F7','Ctrl+F1','CTRL+F1','Alt+F12','F12','F1','F10',
    'Ctrl+F10','~','A','F13','F0','F01','Ctrl+Alt+F5','Control+F5','Meta+F5','Shift+','F 5','Enter',''}) do
    for _,name in ipairs({'host_key','status_key','leave_key'}) do
        -- The other two keys apart from every case, so no case clashes with them.
        local s,notes=Link.parse_settings('host_key=Alt+F1\nstatus_key=Alt+F2\nleave_key=Alt+F3\n'..name..'='..text)
        key,why=K.parse(name,text)
        if #notes==0 then
            assert(key and key.key==s[name].key and key.mod==s[name].mod and key.name==s[name].name,name..'='..text)
        else
            assert(key==nil and notes[1]:find('('..why..')',1,true),name..'='..text..': '..tostring(why))
        end
    end
end

-- Enter is the chat key's default (D-UI3) and only its own; none turns the host key off (D-UI2) and only it.
key=K.parse('chat_key','Enter')
assert(key.key=='RETURN' and key.mod==nil and key.name=='Enter','UE4SS calls it RETURN')
assert(K.parse('chat_key','enter').name=='Enter' and K.parse('chat_key','Alt+F3').name=='Alt+F3')
assert(K.parse('chat_key','Shift+Enter')==nil and K.parse('menu_key','Enter')==nil)
key=K.parse('host_key','none')
assert(key.key==nil and key.name=='none' and K.parse('host_key','NONE').name=='none')
assert(K.parse('menu_key','none')==nil and K.parse('chat_key','none')==nil)

-- A key pressed in the rebind prompt (UE4SS's key and modifier names) as the file writes it, then read back.
assert(K.text('F7')=='F7' and K.text('F7','SHIFT')=='Shift+F7' and K.text('F7','CONTROL')=='Ctrl+F7'
    and K.text('F7','ALT')=='Alt+F7' and K.text('RETURN')=='Enter')
key=K.parse('menu_key',K.text('F9','CONTROL'))
assert(key.key=='F9' and key.mod=='CONTROL')
assert(K.parse('menu_key',K.text('F10'))==nil,'F10 pressed: refused like a written F10')

-- A clash: the other key setting that holds the same key (modifier included); none never clashes.
local keys={menu_key=K.parse('menu_key','F5'),status_key=K.parse('status_key','F6'),
    leave_key=K.parse('leave_key','F8'),chat_key=K.parse('chat_key','Enter'),host_key=K.parse('host_key','none')}
assert(K.clash(keys,'status_key',K.parse('status_key','F5'))=='menu_key')
assert(K.clash(keys,'status_key',K.parse('status_key','Shift+F5'))==nil,'Another modifier is another key')
assert(K.clash(keys,'status_key',K.parse('status_key','F6'))==nil,'Its own key is no clash')
assert(K.clash(keys,'menu_key',K.parse('menu_key','F8'))=='leave_key')
assert(K.clash(keys,'host_key',K.parse('host_key','F6'))=='status_key')
assert(K.clash(keys,'host_key',K.parse('host_key','none'))==nil)
keys.leave_key=K.parse('host_key','none')
assert(K.clash(keys,'host_key',K.parse('host_key','none'))==nil,'Two none are no clash')
-- The same answer whatever the table's order: the first other name in sorted order.
keys={b_key=K.parse('menu_key','F7'),a_key=K.parse('menu_key','F7'),c_key=K.parse('menu_key','F7')}
for _=1,20 do assert(K.clash(keys,'c_key',keys.c_key)=='a_key') end

print('keybind_test ok')
