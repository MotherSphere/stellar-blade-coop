-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The boot: the native part's DLL and its entry points, the Steam link, the settings and a new session token.
return function(M)
local print,log=M.print,M.log
local loaded,why=false,'mod folder unknown'
if M.folder and package and package.loadlib then loaded,why=package.loadlib(M.folder..'\\StellarCoop.dll','*') end
log(loaded and 'Native part loaded.' or 'Native part not loaded: '..tostring(why))
-- The native per-frame entry: a C function in Lua's shape that ignores its Lua state (the DLL links no Lua).
M.native_tick=nil
if loaded then
    local f,tick_why=package.loadlib(M.folder..'\\StellarCoop.dll','coop_tick')
    if type(f)=='function' then M.native_tick=f else log('Native tick unavailable: '..tostring(tick_why)) end
end
-- The XInput pad, read by the native part: UE4SS binds keyboard keys only, and while the menu or a question holds the
-- game's input the game ignores the pad. An older DLL without it: said once, no pad.
M.native_pad=nil
if loaded then
    local f,pad_why=package.loadlib(M.folder..'\\StellarCoop.dll','coop_pad')
    if type(f)=='function' then M.native_pad=f
    else log('Native pad unavailable (no controller in the co-op menu): '..tostring(pad_why)) end
end
-- The DLL links no Lua: its event (0 for none) is how many of these fourteen arguments it hands back.
function M.pad() return select('#',M.native_pad(0,0,0,0,0,0,0,0,0,0,0,0,0,0)) end
-- The emote wheel's reads (ui/kit/wheel.lua), each how many of its arguments the native part hands back: coop_stick
-- the right stick's 5 degree sector (73 arguments: 0 at rest, 73 with the game's window not in front), coop_held D-pad
-- Left held (2: 1 held, 2 not in front), coop_fkey the lowest F-key held (13: 13 not in front). An older DLL without
-- them: said once, the wheel refuses to open.
-- The closet's pad reads the same way: M.pad_bits() X, L3 and R3 held as bits, 1 X, 2 L3, 4 R3 (coop_padbits, 8
-- arguments: 1 + the bits, 1 not in front); M.pad_levels() the right stick's x and y (-1 to 1, up and right positive)
-- and the left and right triggers (0 to 1), from four coop_levels calls of 260 arguments (1 + 65 * which + a level of 0
-- to 64, which 0 to 3 in that order; at rest not in front). An older DLL without them: said once, both nil.
-- The closet camera's held keys: M.held_keys() the keys and mouse buttons held as bits, 1 right mouse, 2 middle mouse,
-- 4 Shift, 8 I, 16 J, 32 K, 64 L, 128 U, 256 O (coop_keys, 512 arguments: 1 + the bits, 1 not in front). UE4SS's binds
-- see a key's press only. An older DLL without it: said once, nil.
M.wheel_reads,M.pad_bits,M.pad_levels,M.held_keys=nil,nil,nil,nil
if loaded then
    local zeros={}
    for i=1,512 do zeros[i]=0 end
    local fns,missing={},{}
    for _,name in ipairs({'coop_stick','coop_held','coop_fkey','coop_padbits','coop_levels','coop_keys'}) do
        local f,fn_why=package.loadlib(M.folder..'\\StellarCoop.dll',name)
        if type(f)=='function' then fns[name]=f else missing[name]=name..': '..tostring(fn_why) end
    end
    local wheel=missing.coop_stick or missing.coop_held or missing.coop_fkey
    if wheel then log('Native emote wheel reads unavailable (no emote wheel): '..wheel)
    else
        M.wheel_reads={stick=function() return select('#',fns.coop_stick(table.unpack(zeros,1,73))) end,
            held=function() return select('#',fns.coop_held(0,0)) end,
            fkey=function() return select('#',fns.coop_fkey(table.unpack(zeros,1,13))) end}
    end
    local closet=missing.coop_padbits or missing.coop_levels
    if closet then log('Native pad bits and levels unavailable: '..closet)
    else
        function M.pad_bits() return select('#',fns.coop_padbits(table.unpack(zeros,1,8)))-1 end
        function M.pad_levels()
            local got={32,32,0,0}
            for _=1,4 do
                local n=select('#',fns.coop_levels(table.unpack(zeros,1,260)))-1
                got[n//65+1]=n%65
            end
            return (got[1]-32)/32,(got[2]-32)/32,got[3]/64,got[4]/64
        end
    end
    if missing.coop_keys then log('Native held keys unavailable: '..missing.coop_keys)
    else function M.held_keys() return select('#',fns.coop_keys(table.unpack(zeros,1,512)))-1 end end
end
-- The pause menu's close for its Online tab (ui/kit/pause_tab.lua): SB's own close, run by the native part on the game
-- thread. Its answer is how many of three arguments it hands back: 1 closed, 2 SB has no pause menu open, 3 off. An
-- older DLL without it, or none: no close can work.
local native_pause_close,pause_close_why=nil,why
if loaded then native_pause_close,pause_close_why=package.loadlib(M.folder..'\\StellarCoop.dll','coop_pause_close') end
function M.pause_close()
    if type(native_pause_close)~='function' then
        return false,'the native part has no coop_pause_close ('..tostring(pause_close_why)..')',true
    end
    local n=select('#',native_pause_close(0,0,0))
    if n==1 then return true end
    if n==2 then return false,'the game has no pause menu open' end
    return false,'the native part refused the close (not the pinned game build, or after its fault)',true
end
M.link=loaded and require('core.link').new(M.folder) or nil
M.settings=nil
if M.link then
    local notes
    M.settings,notes=M.link.settings()
    for _,note in ipairs(notes) do log(note) end
    log(string.format('keys: menu=%s host=%s status=%s leave=%s race=%s, name tag %s, %d poses a second',
        M.settings.menu_key.name,M.settings.host_key.name,M.settings.status_key.name,M.settings.leave_key.name,
        M.settings.race_key.name,M.settings.name_tag and 'on' or 'off',M.settings.send_rate))
end
-- What the ghost shows: the settings', changed by coop look until the mod reloads (game start or Ctrl+R: the settings
-- again). The ghost holds this same table.
local LOOKS={'cloth','dyes','effects','drone','sounds','faces'}
M.look={}
for _,name in ipairs(LOOKS) do M.look[name]=M.settings~=nil and M.settings[name] end
function M.looks()
    local words={}
    for _,name in ipairs(LOOKS) do words[#words+1]=name..'='..(M.look[name] and 'on' or 'off') end
    return 'look: '..table.concat(words,' ')
end
if M.settings then
    log(M.looks())
    log('shared enemies: '..(M.settings.shared_enemies and 'on' or 'off')..' (experimental), fight_chars '
        ..(#M.settings.fight_chars>0 and table.concat(M.settings.fight_chars,' ') or 'auto')..', same place '
        ..(M.settings.same_place and 'on' or 'off')..' (experimental), same spawns '
        ..(M.settings.same_spawns and 'on' or 'off')..' (experimental), extra enemies '..M.settings.enemy_extra
        ..', bosses '..(M.settings.bosses and 'on' or 'off')..' (experimental), boss HP '
        ..math.floor(M.settings.boss_hp_scale*100+0.5)..' %, spawn filter '..(M.settings.spawn_filter and 'on' or 'off')
        ..' (experimental)')
    log(string.format('photo sync: %s, longest pause %s, ghost in your photos %s, its name tag %s',
        M.settings.photo_sync,M.settings.photo_freeze_max>0 and M.settings.photo_freeze_max..' s' or 'no limit',
        M.settings.photo_ghost and 'on' or 'off',M.settings.photo_name_tag and 'on' or 'off'))
    log('shared quests: '..(M.settings.shared_quests and 'on' or 'off')..' (experimental)'
        ..(M.settings.quest_deny~='' and ', quest_deny '..M.settings.quest_deny or ''))
    log('shared world: '..(M.settings.shared_world and 'on' or 'off')..' (experimental)')
    log('story together: '..(M.settings.shared_story and 'on' or 'off')..' (experimental)')
    log('bike: '..(M.settings.bike and 'on' or 'off')..', bike_key '..M.settings.bike_key.name)
end
-- A new token per Lua load: the native part then drops what an older load published (withdrawn here as well).
if M.link then
    M.link.components(nil)
    M.link.display(nil)
    M.link.session(string.format('%d-%d',os.time(),math.floor(os.clock()*1000000)))
end
end
