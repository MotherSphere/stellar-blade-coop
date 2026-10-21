-- The Lua side of the files shared with the native part. Lua writes whole files beside and renames them, so the native
-- part never reads one half-written: coop-request.txt (a console request), coop-session.txt (a token per Lua load),
-- coop-components.txt (EVE's capture), coop-display.txt (the ghost built for the remote table), coop-puppet.txt (the
-- ghost's object path, for the next load) and coop-state.txt (a save loaded, the send rate). The native part writes
-- coop-remote.txt (the table the ghost is built from) the same way. Each line of the native coop-status.txt that
-- changed is returned once, for the log; peer lines change with every ping, the shared fight's counts (its fight= line)
-- every second and her vitals (mate=) up to 10 times a second, so they stay in coop status, out of the log. The chat
-- has two files of its own that live a moment only (coop-say.txt and coop-chat.txt, see say()), and the race one more
-- (coop-race.txt, see race()); her race lines come in coop-chat.txt. The same read gives the session's mode, the
-- friend and the notices for the screen, each from the start of its own line: a Steam name is never at the start of
-- one.
-- While we host, the read also gives our join code and the joiner who waits for our answer (join.lua asks the host),
-- and keeps who waited in this lobby (the menu's Remove row).
-- coop-settings.txt's shared_enemies, fight_chars, guest_kills, enemy_hp_scale, enemy_balance_scale, kill_credit,
-- same_place, aggro, same_spawns, enemy_extra, bosses and boss_hp_scale (Phase 11, experimental) are main.lua's coop
-- fight; its photo_sync,
-- photo_freeze_max, photo_ghost and photo_name_tag the synced photo mode's (main.lua, and the native part through
-- coop-state.txt), photo_pause main.lua's own; its auto_coop_save the co-op saves' (saves.lua), which also read saves()
-- here; its shared_quests and quest_deny main.lua's coop quests (Phase 12, experimental), which reads quests() and
-- quest_notes() here. The co-op menu (menu.lua) changes the file, one line at a time (D-UI4).
local K=require('keybind')
local SF=require('settings_file')
local T=require('ui_text')
local clean=require('chat').clean
local Link={}
-- coop-settings.txt is the user's (N5): written with these defaults when absent, changed by the co-op menu one line at a
-- time (write_settings) and once for the old default send rate (Link.migrate_rate), never shipped (an update would
-- replace it). F-key codes do not depend on the keyboard layout, and Stellar Blade binds none of them.
Link.DEFAULT=[[
# StellarCoop settings, read when the mod loads (game start, or Ctrl+R). The co-op menu (menu_key) changes them too,
# one line at a time, and keeps the file as it was as coop-settings.old.txt. Delete this file to get the defaults back.
# Keys: F1 to F12 except F10, optionally with Shift+, Ctrl+ or Alt+ in front (for example Shift+F7). menu_key opens
# the co-op menu, whose first row hosts; host_key hosts at once, or none. race_key drops a checkpoint while you record
# a race track (coop race record).
menu_key=F5
host_key=none
status_key=F6
leave_key=F8
race_key=F9
# Who can join a session you host: friends (your Steam friends can join from their friends list), code (anyone you
# give your join code to; the co-op menu shows and copies it) or private (only the friends you invite). A player who
# is not your Steam friend waits until you accept or deny them.
who_can_join=friends
# Co-op saves, the co-op copies of your saves (StellarBladeCoop00.sav to 04.sav): ask (a question on the title
# screen), always (the copies at every title, no question) or off (no copies; the manual co-op slot that
# StellarCoopSlot.txt names is then the only co-op save).
auto_coop_save=ask
# Your friend's Steam name above her ghost: on or off.
name_tag=on
# Poses sent to your friend a second: 10 to 60.
send_rate=60
# What the ghost shows, each on or off: cloth (her ponytail swings as in solo; on unless set here, and it sends
# nothing), dyes (hair colours and material variants) and effects (her attack and skill effects), both off unless set
# here. dyes and effects off also stop sending yours.
# For example: dyes=on
# Shared enemies, experimental: on or off. On, the enemies you and your friend both fight share one HP bar and one
# death, while both of you play a co-op save. fight_chars: auto (every common enemy, and with bosses=on the bosses
# and Alpha Naytibas) or the enemy character ids to share instead, separated by spaces (coop fight probe logs them),
# for example fight_chars=15011001.
shared_enemies=on
fight_chars=auto
# guest_kills: when you are the guest, at_once (an enemy your hit kills dies at once on your screen) or confirmed (it
# stays at 1 HP until the host's game agrees, about one ping later, so it never dies on your screen alone).
guest_kills=at_once
# Two-player scaling, the host's values for both games (the guest's are not used): enemy_hp_scale multiplies a shared
# enemy's maximum HP, enemy_balance_scale its balance gauge, each from 1.0 (no change) to 4.0. kill_credit is yours:
# a shared enemy dies in your game, with its rewards, drops and achievements, only if you took part in its fight.
# together: you hit it, it targeted you, or you stood within 30 m when it died. fought: you hit it or it targeted you.
enemy_hp_scale=1.35
enemy_balance_scale=1.15
kill_credit=together
# Same place, experimental, the host's for both games: on or off. As guest, yours decides nothing at a start; the
# co-op menu's row can still stop it on your screen, and start it again, while shared enemies wait or run. On, each
# shared enemy stands in the same place on both screens. aggro, the host's too: game (an enemy fights whoever hit it
# last, or else the nearer player) or host (enemies fight the host only).
same_place=on
aggro=game
# Same spawns, experimental, the host's for both games: on or off. On, while both players stand within 100 m of each
# other in one zone, the guest's game adds the common enemies the host's game has there and removes those it lacks.
# Bosses, quest and event enemies, and the enemies a save records, stay as they are.
same_spawns=on
# Extra enemies, experimental, the host's for both games, used only with same_spawns=on: enemy_extra adds 0 to 3 more
# of each common enemy where both players stand within 100 m of each other in one zone, in both games. Each one stands
# 2 to 4 m from its enemy and goes once both players are more than 120 m from it, or when shared enemies stop. Bosses,
# Alpha Naytibas, Elites, quest and event enemies, and the enemies a save records get none.
enemy_extra=0
# Shared bosses, experimental, the host's for both games: on or off. On, a boss or an Alpha Naytiba that both games
# hold shares one HP bar and one death, as a common enemy does. With same_place=on it fights the host only.
# boss_hp_scale, the host's too, multiplies a shared boss's maximum HP in place of enemy_hp_scale, from 1.0 (no change)
# to 4.0.
bosses=on
boss_hp_scale=2.0
# Shared quests, experimental: on or off, off by default. On, while you and your friend both play a co-op save, a
# quest step the host makes while you stand in the same zone, with that quest at the same point in your game, is made
# in your game too (Epic, Sub and Request quests). A step made without you is never given to you; a kill step waits
# for your own kill, and a Request waits until you hand it in at your own request board. quest_deny, the host's: quests
# never shared, by name or number, separated by spaces or commas (for example quest_deny=Quest_Epic_14_1).
shared_quests=off
quest_deny=
# Synced photo mode: while your friend is in photo mode, your game pauses. both: pause and be paused (both PCs need
# both), notice: a notice only, off: nothing. photo_freeze_max: the longest pause in seconds, 30 to 3600, or 0 for no
# limit. photo_ghost: your friend's ghost in your own photos; photo_name_tag: its name tag in them. photo_pause,
# experimental: full (photo mode stops your whole game, as without the mod) or scenery (the game's own experimental
# method: enemies, combat and shared enemies stay stopped while animations, cloth and effects go on moving), from your
# next photo mode.
photo_sync=both
photo_freeze_max=600
photo_ghost=on
photo_name_tag=off
photo_pause=full
# The co-op menu: ui_scale 75 to 150 (%), ui_sounds on or off, ui_language game (the game's language) or english.
ui_scale=100
ui_sounds=on
ui_language=game
# The session chat (Enter opens it during a session): on or off. Off hides your friend's lines and sends none.
chat=on
# Your friend on screen, each on or off: partner_bar her name, HP and shield over her head; partner_arrow an arrow at
# the screen's edge toward her when she is out of view; partner_card her card at the top left; card_details the ping
# and her map on it. While partner_bar shows her name, the name tag above her ghost hides.
partner_bar=on
partner_arrow=on
partner_card=on
card_details=on
]]
-- The looks are comments only in the file above: an old file and a new one both follow the code's default here. A file
-- written before shared_enemies and fight_chars existed lacks them: on and auto, as here; one written before the photo
-- settings, or the menu's, lacks those: the defaults here. One written before menu_key: see parse_settings.
local DEFAULTS={menu_key='F5',host_key='none',status_key='F6',leave_key='F8',race_key='F9',name_tag='on',
    send_rate='60',cloth='on',dyes='off',effects='off',shared_enemies='on',fight_chars='auto',guest_kills='at_once',
    enemy_hp_scale='1.35',enemy_balance_scale='1.15',kill_credit='together',same_place='on',aggro='game',
    same_spawns='on',enemy_extra='0',bosses='on',boss_hp_scale='2.0',
    photo_sync='both',photo_freeze_max='600',photo_ghost='on',photo_name_tag='off',photo_pause='full',ui_scale='100',
    ui_sounds='on',ui_language='game',chat='on',partner_bar='on',partner_arrow='on',partner_card='on',card_details='on',
    who_can_join='friends',auto_coop_save='ask',shared_quests='off',quest_deny=''}
local SWITCHES={name_tag=true,shared_enemies=true,same_place=true,same_spawns=true,bosses=true,photo_ghost=true,
    photo_name_tag=true,ui_sounds=true,chat=true,partner_bar=true,partner_arrow=true,partner_card=true,
    card_details=true,shared_quests=true} -- On or off.
local LOOKS={cloth=true,dyes=true,effects=true} -- What the ghost shows (puppet.lua), each on or off.
local KEYS={'menu_key','host_key','status_key','leave_key','race_key'}
local CHOICES={photo_sync={'both','notice','off'},ui_language={'game','english'},guest_kills={'at_once','confirmed'},
    kill_credit={'together','fought'},who_can_join={'friends','code','private'},
    auto_coop_save={'ask','always','off'},aggro={'game','host'},photo_pause={'full','scenery'}}
-- The mate= line's twelve numbers, in the native part's order (link_protocol.h's vital).
local VITALS={'hp','max_hp','shield','max_shield','blocks','beta','max_beta','burst','max_burst','tachy','max_tachy',
    'life'}
local MATE='^mate='..('(%d+) '):rep(11)..'(%d+)$'
-- A setting's value from its text, or nil and why it is refused. A key is keybind.lua's ({key='F7', mod='SHIFT' or nil,
-- name='Shift+F7'}; host_key none: no key); fight_chars a list of whole numbers (the native part takes at most 16, each
-- from 1 to 2^32-1), empty for auto (every Monster, the native part's rule), which an empty value means too (a file
-- written before auto); a choice (CHOICES: photo_sync, ui_language, guest_kills, kill_credit, who_can_join,
-- auto_coop_save, aggro, photo_pause) one of its words; photo_freeze_max a whole number of seconds; ui_scale one of
-- percent; the scales a number from 1 to 4, digits with a decimal point or none (main.lua sends them in whole
-- percents); quest_deny its text, letters, digits, '_', spaces and commas only, at most 200 bytes (the native part's
-- request limit; it names the entries that are no shared quest).
local function setting(name,text)
    if name=='fight_chars' then
        local ids={}
        if text:lower()=='auto' then return ids end
        for word in text:gmatch('%S+') do
            local id=word:match('^%d+$') and tonumber(word)
            if not id or id<1 or id>4294967295 or #ids==16 then
                return nil,'use auto, or at most 16 character ids, whole numbers separated by spaces'
            end
            ids[#ids+1]=id
        end
        return ids
    elseif CHOICES[name] then
        local list=CHOICES[name]
        text=text:lower()
        for _,v in ipairs(list) do if text==v then return v end end
        return nil,'use '..table.concat(list,', ',1,#list-1)..' or '..list[#list]
    elseif name=='photo_freeze_max' then
        local seconds=text:match('^%d+$') and tonumber(text)
        if seconds and (seconds==0 or seconds>=30 and seconds<=3600) then return math.tointeger(seconds) end
        return nil,'use 0 (no limit) or 30 to 3600 seconds'
    elseif SWITCHES[name] or LOOKS[name] then
        text=text:lower()
        if text=='on' or text=='off' then return text=='on' end
        return nil,'use on or off'
    elseif name=='send_rate' then
        local rate=text:match('^%d+$') and tonumber(text)
        if rate and rate>=10 and rate<=60 then return rate end
        return nil,'use 10 to 60'
    elseif name=='enemy_hp_scale' or name=='enemy_balance_scale' or name=='boss_hp_scale' then
        local x=text:match('^%d+%.?%d*$') and tonumber(text)
        if x and x>=1 and x<=4 then return x end
        return nil,'use 1.0 to 4.0'
    elseif name=='enemy_extra' then
        local n=text:match('^%d$') and tonumber(text)
        if n and n<=3 then return n end
        return nil,'use 0 to 3'
    elseif name=='quest_deny' then
        if #text<=200 and text:match('^[%w_, ]*$') then return text end
        return nil,'use quest names or numbers separated by spaces or commas, at most 200 characters'
    elseif name=='ui_scale' then
        local pct=text:match('^%d+$') and tonumber(text)
        if pct and pct>=75 and pct<=150 then return pct end
        return nil,'use 75 to 150'
    end
    return K.parse(name,text)
end
-- send_rate=20 was the default up to 30 poses a second. A file from then (no RATE_NOTE, the comment Link.DEFAULT now
-- has) that still says 20: its text with send_rate=60 and RATE_NOTE (in place of the old comment, else at the end), so
-- it is changed once and a 20 picked later stays. nil for any other file, and nil, why when the line cannot be set.
-- ponytail: an old file that kept another rate and gets 20 from the menu later is still changed at the next load; the
-- menu's write (ui_model.lua) could add RATE_NOTE too if that ever matters.
local RATE_NOTE='# Poses sent to your friend a second: 10 to 60.'
local OLD_RATE_NOTE='# Poses sent to your friend a second: 10 to 30.'
function Link.migrate_rate(text)
    local rate=SF.get(text,'send_rate',function(value) return setting('send_rate',value)~=nil end)
    if tonumber(rate)~=20 or text:find(RATE_NOTE,1,true) then return nil end
    local new,why=SF.set(text,'send_rate','60')
    if not new then return nil,why end
    local at,stop=new:find(OLD_RATE_NOTE,1,true)
    if at then return new:sub(1,at-1)..RATE_NOTE..new:sub(stop+1) end
    local nl=new:find('\r\n',1,true) and '\r\n' or '\n'
    return new..((new=='' or new:sub(-1)=='\n') and '' or nl)..RATE_NOTE..nl
end
-- Development builds before 0.4.0-beta.1 wrote same_place, same_spawns and bosses as off, with "off until it has been
-- tested in game" in the same spawns comment. A file with that comment: its text with each of the three that says off
-- set to on and the comment's first sentence as Link.DEFAULT has it, so it is changed once and an off picked later
-- stays. nil for any other file, and nil, why when a line cannot be set.
local OLD_ON_NOTE="# Same spawns, experimental, the host's for both games: on or off, off until it has been tested in game."
local ON_NOTE="# Same spawns, experimental, the host's for both games: on or off."
function Link.migrate_on(text)
    local at,stop=text:find(OLD_ON_NOTE,1,true)
    if not at then return nil end
    local new=text:sub(1,at-1)..ON_NOTE..text:sub(stop+1)
    for _,key in ipairs({'same_place','same_spawns','bosses'}) do
        if (SF.get(new,key) or ''):lower()=='off' then
            local set,why=SF.set(new,key,'on')
            if not set then return nil,why end
            new=set
        end
    end
    return new
end
-- 0.4.0-beta.1 wrote kill_credit=all, under a comment that names all: the other player's kill killed your copy too,
-- wherever you stood. all is gone. A file with that comment: its text with the comment as Link.DEFAULT has it and an
-- all set to together, so it is changed once (fought stays). nil for any other file, where a hand-written all is
-- refused when read, and nil, why when the line cannot be set.
local OLD_CREDIT_NOTE={'(no change) to 4.0. kill_credit: all (every',
    '# shared enemy that dies gives you the kill rewards in your game) or fought (only those your EVE hit).'}
local CREDIT_NOTE={'(no change) to 4.0. kill_credit is yours:',
    '# a shared enemy dies in your game, with its rewards, drops and achievements, only if you took part in its fight.',
    '# together: you hit it, it targeted you, or you stood within 30 m when it died. fought: you hit it or it targeted you.'}
function Link.migrate_credit(text)
    local nl=text:find('\r\n',1,true) and '\r\n' or '\n'
    local at,stop=text:find(table.concat(OLD_CREDIT_NOTE,nl),1,true)
    if not at then return nil end
    local new=text:sub(1,at-1)..table.concat(CREDIT_NOTE,nl)..text:sub(stop+1)
    if (SF.get(new,'kill_credit') or ''):lower()~='all' then return new end
    return SF.set(new,'kill_credit','together')
end
-- The settings from the file's text, and the log lines for what was refused: a bad value keeps its default.
function Link.parse_settings(text)
    local settings,notes,n={},{},0
    for name,value in pairs(DEFAULTS) do settings[name]=setting(name,value) end
    text=text:gsub('^\239\187\191','') -- Notepad's "UTF-8 with BOM".
    if #text>8192 then -- Whole lines only: a cut F11 would read as F1.
        text=text:sub(1,8192):match('^.*\n') or ''
        notes[1]='settings: only the first 8192 bytes are read'
    end
    local named={} -- The settings a line names, taken or not.
    for line in ((text:gsub('\r',''))..'\n'):gmatch('([^\n]*)\n') do
        n=n+1
        if not line:find('^%s*$') and not line:find('^%s*#') then
            local name,value=line:match('^%s*([%w_]+)%s*=%s*(.-)%s*$')
            local key=name and name:lower()
            if key then named[key]=true end
            if not DEFAULTS[key] then
                notes[#notes+1]=string.format("settings: line %d: unknown setting '%s', ignored",n,name or line:match('^%s*(.-)%s*$'))
            else
                local parsed,why=setting(key,value)
                if why then
                    notes[#notes+1]=string.format("settings: line %d: '%s' is not allowed for %s (%s); %s stays %s",
                        n,value,key,why,key,DEFAULTS[key]~='' and DEFAULTS[key] or 'empty')
                else
                    settings[key]=parsed
                end
            end
        end
    end
    -- A file with no menu_key line (every file written before the menu, D-UI2): the menu opens on host_key's key and
    -- Host is its first row, so host_key goes off. The user's Shift+F5 file keeps Shift+F5.
    if not named.menu_key then
        if settings.host_key.key then settings.menu_key=settings.host_key end
        settings.host_key=setting('host_key','none')
    end
    -- A file from before race_key whose own keys hold F9: race_key has none there (coop race cp still drops a
    -- checkpoint), so the rule below never puts back the keys the player chose.
    if not named.race_key then
        for _,name in ipairs(KEYS) do
            if name~='race_key' and settings[name].name==settings.race_key.name then
                notes[#notes+1]='settings: '..settings[name].name..' is '..name..': race_key has no key'
                settings.race_key=setting('race_key','none')
                break
            end
        end
    end
    -- Two actions on one key would both run on each press: all five go back to the defaults.
    local keys={}
    for _,name in ipairs(KEYS) do keys[name]=settings[name] end
    for _,name in ipairs(KEYS) do
        if K.clash(keys,name,settings[name]) then
            notes[#notes+1]='settings: '..settings[name].name..' is set for two actions: default keys used'
            for _,key in ipairs(KEYS) do settings[key]=setting(key,DEFAULTS[key]) end
            break
        end
    end
    return settings,notes
end
Link.files={
    read=function(path) local f=io.open(path,'rb'); if not f then return nil end; local text=f:read('a'); f:close(); return text end,
    -- A full disk fails at the write or only at the close's flush: either one is a failed write.
    write=function(path,text)
        local f=io.open(path,'wb'); if not f then return false end
        local wrote=f:write(text); local closed=f:close()
        return wrote~=nil and closed==true
    end,
    remove=os.remove,
    rename=os.rename,
}
-- A join code as typed (the code box, coop join <code>): either case, the dash or a space after the third character or
-- nothing there, spaces around. Returned as the native part takes it, 'XXX-XXXX' in capitals; nil for anything else.
-- Its letters and its check digit are the native part's to judge (link_protocol.h's code_lobby), which answers a wrong
-- one on screen.
local ALNUM=('[0-9A-Za-z]'):rep(3)
function Link.join_code(text)
    if type(text)~='string' or #text>32 then return nil end
    local a,b=text:match('^[ \t]*('..ALNUM..')[- ]?('..ALNUM..'[0-9A-Za-z])[ \t]*$')
    return a and (a..'-'..b):upper() or nil
end
function Link.new(folder,fs)
    fs=fs or Link.files
    local function path(name) return folder..'\\'..name end
    local status_path=path('coop-status.txt')
    local seen,remote={},{}
    -- As of the last changes(); dead: the worker stopped for good (a fault or another Steamworks build); held: an
    -- invite waits for a save; rejoin: the tries started to get back into a lost game; shown: the last notice number
    -- handed out; fight: the shared fight's line; pilot: same-place enemies' line; photo: the photo line's {mine=,
    -- peer=,frozen=}; mate: her vitals; ping: the first peer's RTT in ms; loopback: coop loopback runs; rejoined: a
    -- rejoin got her lobby back and waits for the handshake (kept across changes() until she is linked or we are no
    -- longer a guest); saves: the co-op saves' state (saves()); paks: her .pak mods against ours (paks()); quests: the
    -- shared quests' line; noted: their notes listed; noted_shown: the last note number handed out.
    local mode,friend,listed,dead,held,rejoin,shown,fight,photo,pilot=nil,nil,nil,false,nil,nil,nil,nil,nil,nil
    local mate,ping,loopback,rejoined,saves,paks=nil,nil,false,false,{},nil
    local quests,noted,noted_shown=nil,nil,nil
    -- As of the last changes() too: lobby, the link line's; code, our join code while we host with one; refused, the
    -- players refused in this lobby; pending, the first joiner waiting for our answer ({id=, name=}); members, the
    -- lobby members' SteamIDs (peer lines). strangers: each joiner seen waiting in the lobby strangers_in names
    -- (SteamID to her last name), none a Steam friend.
    -- ponytail: Lua memory only: a Lua reload forgets them, and the Remove row with them (coop remove still works); a
    -- flag on her peer line from the native part would outlive the reload.
    local lobby,code,refused,pending,members,strangers,strangers_in=nil,nil,nil,nil,{},{},nil
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
    -- The native part takes one coop-request.txt a pass, and a write before it took the last one replaced it: two
    -- requests in one Lua tick (coop fight on and saves coop at a game start) lost the first. So a request waits here,
    -- in order, while one is on disk, and changes() writes the next once the native part took it.
    -- ponytail: 8 at most, the newest kept, for a native part that never takes them (a fault, another build).
    local queue={}
    local function send()
        if queue[1] and not fs.read(path('coop-request.txt')) and put('coop-request.txt',queue[1]..'\n') then
            table.remove(queue,1)
        end
    end
    function self.request(line)
        if queue[1] or fs.read(path('coop-request.txt')) then
            if #queue>=8 then table.remove(queue,1) end
            queue[#queue+1]=line
            return true,'asked the native part: '..line
        end
        local ok,why=put('coop-request.txt',line..'\n')
        if not ok then return false,why end
        return true,'asked the native part: '..line
    end
    function self.session(token) return put('coop-session.txt',token..'\n') end
    -- coop-state.txt: whether a save is loaded (held invites wait for one) or else the title screen is shown
    -- (world=title: the only time the native part changes the co-op saves), the poses sent a second, and the synced
    -- photo mode's: ours ('0', '1' or 's'), photo_sync and photo_freeze_max. Written when its text changes, and
    -- remembered only once written, so a failed write is tried again; returns the line it wrote.
    local state=nil
    function self.state(world,rate,photo_now,sync,max,title)
        local line=string.format('world=%s rate=%d photo=%s sync=%s max=%d',world and '1' or title and 'title' or '0',
            rate,photo_now,sync,max)
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
    -- A whole file of ours beside coop-settings.txt (a race track, coop-track-<name>.txt): its text or nil, and
    -- written through a temporary file (true, or false and why).
    function self.read_file(name) return fs.read(path(name)) end
    function self.write_file(name,text) return put(name,text) end
    -- An object path kept across Lua loads, so a reload can sweep what an earlier one left: the ghost's in
    -- coop-puppet.txt unless named (the UI root's: coop-ui.txt).
    function self.store(name)
        name=name or 'coop-puppet.txt'
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
    -- Chat (UI-DESIGN 4.2, 5.2). A typed line goes into coop-say.txt, written only while the native part has taken the
    -- last one (else false, 'busy'), whole and never left as a temporary; false, 'cannot write' when it cannot be.
    -- No message here ever holds the text: callers log them.
    function self.say(text)
        local final=path('coop-say.txt')
        if fs.read(final) then return false,'busy' end
        local temp=final..'.tmp'
        if fs.write(temp,text..'\n') and fs.rename(temp,final) then return true end
        fs.remove(temp)
        return false,'cannot write'
    end
    -- Race lines (race_model.lua's). The native part takes coop-race.txt at every pass and sends each line, in order;
    -- a write before it took the last file would replace it, so a cp and a fin sent close together lost the cp. So
    -- race() queues each line, and race_flush() writes every pending one into one new file once the last is gone:
    -- changes() calls it, and the race each frame. It never removes the last: one the native part holds open while it
    -- takes it cannot be read, so the rename fails while it is there and the lines wait for the next flush.
    -- ponytail: 512 lines at most, the oldest dropped, for a native part that never takes them (a fault, another
    -- build); steam_link.cpp reads that many.
    local race_queue={}
    function self.race(line)
        if #race_queue>=512 then table.remove(race_queue,1) end
        race_queue[#race_queue+1]=line
    end
    function self.race_flush()
        if race_queue[1] and not fs.read(path('coop-race.txt'))
            and put('coop-race.txt',table.concat(race_queue,'\n')..'\n',true) then
            race_queue={}
        end
    end
    -- The native part's coop-chat.txt, taken and deleted at once: {text=} for each of her lines, {fail=true} when one
    -- of ours could not go, {race=} for each of her race lines, oldest first; anything else is ignored.
    function self.take_chat()
        local name=path('coop-chat.txt')
        local text,lines=fs.read(name),{}
        if not text or not fs.remove(name) then return lines end -- Not deleted: taken next time, never shown twice.
        for line in text:gmatch('[^\n]+') do
            local said,raced=line:match('^in (.+)$'),line:match('^race (.+)$')
            if said then lines[#lines+1]={text=said}
            elseif raced then lines[#lines+1]={race=raced}
            elseif line=='fail' then lines[#lines+1]={fail=true} end
        end
        return lines
    end
    function self.changes()
        send()
        self.race_flush()
        local text,now,new=fs.read(status_path),{},{}
        -- From the pose path's line only: a peer line before it carries a Steam name the other player chooses.
        local engine=('\n'..(text or '')):match('\nengine=[^\r\n]*') or ''
        local generation,count,source=engine:match(' remote=(%d+) (%d+) (%a+)')
        remote={tonumber(generation),tonumber(count),source}
        mode,friend,listed,dead,held,rejoin,fight,photo,pilot=nil,nil,nil,false,nil,nil,nil,nil,nil
        mate,ping,loopback,saves,paks=nil,nil,engine:find(' loopback=')~=nil,{},nil
        quests,noted=nil,nil
        -- The engine off on another game build (check_build's reasons): a game update, said at the title (saves.lua).
        if engine:find(' reason=build stamp ',1,true) or engine:find(' reason=code bytes differ',1,true) then
            saves.build=true
        end
        lobby,code,refused,pending,members=nil,nil,nil,nil,{}
        if not text then return new end
        listed,noted={},{}
        for line in text:gmatch('[^\r\n]+') do
            now[line]=true
            if not seen[line] and not line:find('^peer=') and not line:find('^fight=') and not line:find('^mate=') then
                new[#new+1]=line
            end
            if ping==nil and line:find('^peer=') then -- Her name comes before: the last rtt_ms= is the native part's.
                ping=tonumber(line:match(' rtt_ms=(%-?%d+) session=%-?%d+ session_ping=%-?%d+$'))
                ping=ping and ping>=0 and ping or false
            end
            if line:find('^mate=') then
                local v={line:match(MATE)}
                if v[12] then
                    mate={}
                    for i,key in ipairs(VITALS) do mate[key]=tonumber(v[i]) end
                end
            end
            if not mode and line:find('^link=') then
                mode,held,rejoin=line:match('^link=(%a+)'),line:match(' held=(%d+)'),line:match(' rejoin=(%d)/3')
                lobby=line:match(' lobby=(%d+)')
            end
            local ours,out=line:match('^code=([%w%-]+) refused=(%d+)$')
            if ours then code,refused=ours~='none' and ours or nil,tonumber(out) end
            local id,name=line:match('^pending=(%d+) (.*)$')
            if id and not pending then pending={id=id,name=name} end
            id=line:match('^peer=(%d+) ')
            if id then members[#members+1]=id end
            dead=dead or line:find('^stopped=')~=nil or line:find('^missing=')~=nil
            if line:find('^fight=') then fight=line end
            if line:find('^pilot=') then pilot=line end
            if line:find('^quests=') then quests=line end
            local qn,kind,id,alias,zone=line:match('^quest_note=(%d+) ([%a_]+) (%d+) ([%w_]+) ([%w_%-]+)$')
            if qn then noted[#noted+1]={n=tonumber(qn),kind=kind,id=id,alias=alias,zone=zone~='-' and zone or nil} end
            local same,ours_n,hers_n=line:match('^paks=(%a+) (%d+) (%d+)$')
            if same then paks={same=same=='same',ours=tonumber(ours_n),hers=tonumber(hers_n)} end
            local mine,peer,frozen=line:match('^photo=(%S) peer_photo=(%S) frozen=([01]) ')
            if mine then photo={mine=mine,peer=peer,frozen=frozen=='1'} end
            local linked,lost,name=line:match('^friend=([01]) ([01]) (.*)$')
            if name then friend={name,linked=='1',lost=='1'} end
            local n,notice=line:match('^notice=(%d+) (.*)$')
            if n then listed[#listed+1]={tonumber(n),notice} end
            local verdict,names=line:match('^slot=(%a+) .* saves=(%S+)$')
            if verdict then saves.slot,saves.saves,saves.marker=verdict,names,line:match(' marker=(%d) ') end
            saves.convert=saves.convert or line:match('^convert=(.+)$')
            if line:find('^mod=') then saves.steamid=line:match(' steamid=(%d+) ') end
        end
        if held then saves.held=true end -- The question at the title says an invite waits (saves.lua).
        -- Back in her lobby, the native part drops rejoin= before the handshake: the rejoin holds until she is linked.
        if rejoin then rejoined=true elseif mode~='guest' or (friend and friend[2]) then rejoined=false end
        if lobby and lobby~=strangers_in then strangers,strangers_in={},lobby end
        if pending then strangers[pending.id]=pending.name end
        seen=now
        return new
    end
    -- 'none', 'host' or 'guest'; nil before Steam is ready.
    function self.mode() return mode end
    -- Her vitals for the partner card ({hp=, max_hp=, shield=, max_shield=, blocks=, beta=, max_beta=, burst=,
    -- max_burst=, tachy=, max_tachy=, life=}, whole units; your own during coop loopback), or nil: none for 3 s.
    function self.mate() return mate end
    -- Whether coop loopback runs, as of the last changes(): with no friend linked, our race lines come back as hers.
    function self.loopback() return loopback end
    -- The friend's round trip in ms, or nil before the first pong.
    function self.ping() return ping or nil end
    -- A chat session holds once Steam is ready: a friend linked (lost or not), a rejoin under way (until she is linked
    -- again), or coop loopback. Its end clears the chat (chat.lua's session()); the native part's own ends with the
    -- link, so a line typed during a rejoin fails. nil when the status was not read: that ends nothing.
    function self.chatting()
        if not listed then return nil end
        return mode~=nil and ((friend~=nil and friend[2]) or rejoin~=nil or rejoined or loopback)
    end
    -- The shared fight's line ("fight=on mode=on role=host enemies=3 ...", "fight=off why=..."; native fight_status());
    -- nil without one.
    function self.fight() return fight end
    -- Same-place enemies' line ("pilot=on piloted=3 owned=1 drawn=2", "pilot=off why=host", "pilot=stopped",
    -- "pilot=refused why=..."; native pilot_status()), from the start of its own line; nil without one.
    function self.pilot() return pilot end
    -- Her .pak mods against ours, once her game said them: {same=, ours=, hers=} (the counts beyond the base game's
    -- paks), or nil.
    function self.paks() return paks end
    -- The shared quests' line ("quests=on mode=on role=guest partner=on", "quests=waiting mode=on why=save",
    -- "quests=off", "quests=stopped"; native quest_engine.h's Worker::status()), from the start of its own line; nil
    -- without one.
    function self.quests() return quests end
    -- Their notes numbered above the last one handed out, oldest first, each {kind=, id=, alias=, zone=} (kind: ahead,
    -- behind, zone, board, locked, kill, unseen, forced, forced_warp or not_forced; id the quest's number as text;
    -- alias its row name; zone for kind zone only). The first call only primes the count, as notices() does.
    function self.quest_notes()
        if not noted then return {} end
        local out,top={},noted[#noted]
        for _,item in ipairs(noted) do
            if noted_shown and item.n>noted_shown then out[#out+1]=item end
        end
        noted_shown=math.max(noted_shown or 0,top and top.n or 0)
        return out
    end
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
    -- The link line's lobby id (digits, '0' outside a lobby), nil when the status was not read.
    function self.lobby() return lobby end
    -- Our join code ('XXX-XXXX', nil when we host without one or do not host) and the players refused in this lobby
    -- (nil when we do not host).
    function self.code() return code,refused end
    -- The first joiner who is not our Steam friend and waits for our answer, {id=her SteamID (digits), name=her Steam
    -- name as the native part cleaned it, maybe ''}; nil when none.
    function self.pending() return pending end
    -- The first lobby member who waited for our answer in this lobby and no longer does (we let her in), {id=, name=};
    -- nil when none.
    function self.stranger()
        for _,id in ipairs(members) do
            if strangers[id] and not (pending and pending.id==id) then return {id=id,name=strangers[id]} end
        end
    end
    -- The co-op saves' state as of the last changes(), each from its own line: {slot=the verdict ('coop', 'main',
    -- 'none', 'unknown'), saves=the save files the game uses ('main', 'coop', 'off', '?'), convert=the last copy pass
    -- ('idle', 'busy <done>/<jobs>', 'done', 'error:<why>'), steamid=ours (digits), build=true when the engine is off
    -- on another game build, held=true while an invite waits for a save (the link line's held=), marker=the slot digit
    -- StellarCoopSlot.txt names (the manual co-op slot)}; a field unread is nil.
    function self.saves() return saves end
    -- The status key's line, in words (ui_text.lua's T.en or T.fr; English when not given). Her name is an argument
    -- to the words' formats, never one itself, and cleaned as a chat line: a stranger waiting for the host's answer
    -- may hold a line separator or a bidi override in it.
    function self.summary(words)
        local w=(words or T.en).summary
        if dead then return w.stopped end
        if not mode then return w.waiting end
        if held then return w.held end
        if rejoin then return w.rejoin:format(rejoin) end
        if mode=='none' then return w.none end
        local name,linked,lost=self.friend()
        local who=name and clean(name)
        if who=='' then who=w.friend end
        local text
        if not name and mode=='host' then text=w.alone
        elseif not linked then text=w.connecting:format(who or w.friend)
        elseif mode=='host' then text=w.hosting:format(who)
        else text=w.guest:format(who) end
        if linked and photo and photo.frozen and photo.peer=='1' then text=text..w.paused:format(who) end
        return lost and text..w.lost or text
    end
    -- The settings and their log lines. A file that cannot be read is kept as well: the rename fails if it exists.
    function self.settings()
        local text,wrote,turned,credited=fs.read(path('coop-settings.txt')),nil,nil,nil
        if not text then
            text=Link.DEFAULT
            local ok,why=put('coop-settings.txt',text,true)
            wrote=ok and 'settings: coop-settings.txt written with the defaults'
                or 'settings: cannot write coop-settings.txt ('..tostring(why)..'): defaults used'
        else -- The old default send rate, read as the new one even when the file cannot be rewritten.
            local new,why=Link.migrate_rate(text)
            if new then
                local ok
                ok,why=self.write_settings(new)
                text=new
                wrote=ok and 'settings: send_rate=20, the old default, is now 60 in coop-settings.txt'
                    or 'settings: send_rate=20, the old default, read as 60 (coop-settings.txt not rewritten: '
                        ..tostring(why)..')'
            elseif why then
                wrote='settings: send_rate=20, the old default, kept: '..why
            end
            local on,why_on=Link.migrate_on(text) -- 0.4.0-beta.1's three off lines, read as on.
            if on then
                local ok
                ok,why_on=self.write_settings(on)
                text=on
                turned=ok and 'settings: same_place, same_spawns and bosses are now on in coop-settings.txt'
                    or 'settings: same_place, same_spawns and bosses read as on (coop-settings.txt not rewritten: '
                        ..tostring(why_on)..')'
            elseif why_on then
                turned='settings: same_place, same_spawns and bosses kept as they are: '..why_on
            end
            local all=(SF.get(text,'kill_credit') or ''):lower()=='all'
            local credit,why_credit=Link.migrate_credit(text) -- 0.4.0-beta.1's kill_credit=all, read as together.
            if credit then
                local ok
                ok,why_credit=self.write_settings(credit)
                text=credit
                credited=all and (ok and 'settings: kill_credit=all is gone: coop-settings.txt now says '
                    ..'kill_credit=together (a shared enemy dies in your game only if you took part in its fight)'
                    or 'settings: kill_credit=all is gone, read as together (coop-settings.txt not rewritten: '
                        ..tostring(why_credit)..')') or nil
            elseif why_credit then
                credited='settings: kill_credit=all is gone, read as together: '..why_credit
            end
        end
        local settings,notes=Link.parse_settings(text)
        if credited then table.insert(notes,1,credited) end
        if turned then table.insert(notes,1,turned) end
        if wrote then table.insert(notes,1,wrote) end
        return settings,notes
    end
    -- The menu's changes (D-UI4): the file's text (nil when it cannot be read), and the whole file written back
    -- through a temporary one; before the first change of a Lua load, the file as it was then is kept as
    -- coop-settings.old.txt.
    local backed=false
    function self.settings_text() return fs.read(path('coop-settings.txt')) end
    function self.write_settings(text)
        if not backed then
            local old=self.settings_text()
            if old then
                local ok,why=put('coop-settings.old.txt',old)
                if not ok then return false,why end
            end
            backed=true
        end
        local ok,why=put('coop-settings.txt',text)
        local final=path('coop-settings.txt')
        -- The rename refused once the old file went (a virus scanner holding the .tmp): written in place, so the next
        -- load never falls back to the defaults (F5, F6, F8, which other mods bind).
        if not ok and not fs.read(final) and fs.write(final,text) then return true end
        return ok,why
    end
    function self.valid_lobby(text) return text:match('^%d+$')~=nil and text:match('^0+$')==nil end
    self.join_code=Link.join_code
    return self
end
return Link
