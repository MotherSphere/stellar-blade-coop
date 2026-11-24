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
-- The DLL links no Lua: its event (0 for none) is how many of these thirteen arguments it hands back.
function M.pad() return select('#',M.native_pad(0,0,0,0,0,0,0,0,0,0,0,0,0)) end
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
