-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- What the runtime and the modules share: notices, words, ask, the co-op save check, the values several files read.
return function(M)
local print,log=M.print,M.log
M.notice=require('ui.kit.notice').new()
-- The UI kit (M.kit), the co-op menu, the chat's box and feed, the partner HUD, the co-op saves' question, the code
-- box, the host's question, the Sessions screen, the Create a session screen and the SBO lobby's screens: with the
-- Steam link, built by main/ui.lua and the modules' build steps. The SBO lobby itself (M.sbo) and its hall maps' rows
-- (M.halls) are built by online/lobby/wiring.lua.
-- The screen the co-op menu opened in its place, while one is open: the Sessions screen or the Create a session screen.
function M.open_screen() return M.sessions.is_open() and M.sessions or M.create.is_open() and M.create or nil end
-- coop ui reset and the focus watchdog: the menu, the chat's box, the code box, the Sessions and Create a session
-- screens and the lobby's screens closed, an open host's question denied, the co-op saves' question closed as Decide
-- later, the game's input given back now and the menu's mouse cursor put back; a lobby screen closed in the lobby world
-- gives the view back to EVE with the room's overlay, as Back does. With why (the watchdog's): it is logged. A co-op
-- saves pass under way is kept.
function M.ui_reset(why)
    M.menu.close(); M.box.close(); M.code_box.close(); M.approval.close(); M.saves_ui.close(why~=nil); M.wheel.close()
    M.sessions.close(); M.create.close()
    local was=M.lobby.is_open()
    M.lobby.close()
    if was and M.sbo.in_lobby() then M.sbo.to_room(); M.lobby.room(true) end
    M.kit.reset()
    if why then log(why) end
end
-- A notice: into the chat's feed while the UI's root is up, else on the line above EVE (ui/kit/notice.lua), the
-- fallback when the UI is off or failed. en: the same line in English (T.en's words), which that line shows when its
-- font cannot draw the other.
function M.say(text,en) if not (M.box and M.box.say(text)) then M.notice.say(text,en) end end
-- The words for the screen (ui/text.lua): the game's language unless ui_language=english; English while unread. The
-- log keeps English.
local T=require('ui.text')
function M.words() return T.pick(M.kit and M.kit.language(),M.settings and M.settings.ui_language) end
-- A notice that build(words) puts together: in the menu's words, and in English for the line above EVE.
function M.tell(build) M.say(build(M.words()),build(T.en)) end
-- UE4SS-settings.ini (core/ue4ss_settings.lua), two folders above the mod's, read only: each key there that UE4SS
-- reads as on is logged now, and its notice said once this Lua load as soon as one can show (main/pass.lua's 250 ms
-- loop, with the Steam link only). A file that cannot be read, or is too large, gets a log line and no notice.
M.ue4ss_notes={}
do
    local root=M.folder and M.folder:match('^(.*)[\\/][^\\/]+[\\/][^\\/]+$')
    if root then
        local S=require('core.ue4ss_settings')
        local text,why=require('core.link').files.read(root..'\\UE4SS-settings.ini',S.LIMIT+1)
        local on
        if text then on,why=S.check(text) end
        if not on then log('UE4SS-settings.ini not checked: '..tostring(why)) end
        for _,k in ipairs(on or {}) do
            log('UE4SS-settings.ini: '..k.key..(k.value and ' = '..k.value or ' missing (UE4SS then uses its default, '
                ..'on)')..'. '..T.en.ue4ss[k.word])
            M.ue4ss_notes[#M.ue4ss_notes+1]=k.word
        end
    end
end
M.aside_note=nil -- The set-aside asset's name for the notice, until said (online/partner/wiring.lua sets it).
-- coop off lasts until the game restarts, even across a Lua reload (Ctrl+R): the native part remembers it.
-- Read from the pose path's line only, as a peer's Steam name could say the same.
function M.native_off()
    return M.link~=nil and ('\n'..(M.link.status() or '')):find('\nengine=[^\r\n]* reason=coop_off')~=nil
end
M.off=M.native_off()
-- The native part has it too: from then on its tick runs again, as it only releases a held photo pause tag.
M.blocked=M.off
M.USAGE='Use: coop puppet | host [public|friends|invitation|closed] | invite | list [public|friends] | join [lobby id|code|row] | copy | allow|deny|remove|block <SteamID> | unblock <SteamID>|all | blocked | leave | match search|create <mode>|cancel|end|join <code>|leave | mute|unmute <SteamID> | status | report | mark [text] | where | near [metres] | travel host | loopback <delay ms> <jitter ms> <loss %>|off | record [off] | replay [off] | basesuit | look [cloth|dyes|effects|drone|sounds|faces on|off] | cns [reset] | wear [<name>|off [hair|suit]] | scene [emil|orcal|stop] | lines [<name>|stop] | emote [list|<name>|off] | bike [status|tune [<name> <value>]] | gun [status] | no [heal|rule|spawnpt|actor] | nightop [start [easy|normal|hard|nightmare] [noaggro|nomove]|stop|revive|shop|buy [<n> [count]]] | challenge [<name>|stop] | scoreattack [status|pick <challenge>] | fish [status|start [<minutes>]|stop] | photohunt [start [<minutes>]|stop|try [<row> ...]|status] | recruiter [off] | gift [send <item> [count]|take [n]] | race record <name>|cp|save [laps]|cancel|start <name>|quit|match [status|pick <track>] | fight on|off|status|probe|test|record|replay|pilot|spawn | spectate on|off|status|test | quests on|off|status|probe|record|replay|force <number> | world on|off|status | teamshop | scenes on|off|status | guide | keys reset [<name>|all] | freeze <seconds>|off | ui reset|off | saves probe|convert|coop|main|refresh <0-4>|export <0-4> <0-4> | off'
function M.ask(line)
    return function()
        if not M.link then return false,'the Steam link needs the native part' end
        return M.link.request(line)
    end
end
-- coop no, coop recruiter, coop fight, coop revive test, the Doro look and probe, coop lion's, coop gardener fight's
-- and coop tendril fight's words that spawn, show and cam turning the free camera on in coop leviathan and the other
-- viewer commands,
-- and a scene of coop scene run only on a co-op save (D2, N9): the native part's slot=coop, from the start of its own
-- line (a Steam name never starts one), for a co-op copy (saves=coop) or the manual co-op slot that StellarCoopSlot.txt
-- names. The ghost, the Steam link and every other command are never locked to it.
function M.slot_line() return ('\n'..(M.link and M.link.status() or '')):match('\n(slot=[^\r\n]*)') end
function M.coop_slot(what)
    local line=M.slot_line()
    if line and line:find('^slot=coop ') then return true end
    return false,what..' runs only on a co-op save (INSTALL.md: Co-op saves); now '..(line or 'no slot status')
end
function M.ui_log(m) print('[StellarCoop][UI] '..tostring(m)..'\n') end -- The UI kit's lines.
-- The bike (vehicles/bike/ride.lua), built by vehicles/bike/wiring.lua: coop emote, the race, the races' driving, the
-- hall seats and the Doro look read whether EVE rides through riding().
function M.riding() return M.bike~=nil and M.bike.riding() end
-- The session chat's clock: the 250 ms loop's ticks, which main/pass.lua counts. os.clock is CPU time under some C
-- runtimes, os.time whole seconds.
M.chat_clock=0
-- The synced photo mode: our player in SB's photo mode ('1'), its selfie mode ('s') or neither ('0'), from SB's
-- reflected getters (the library's default object, found once). The first failure turns it off for this Lua load
-- ('0' from then on) with one log line.
local U=require('core.unreal')
-- SB's own word for a StringTable_UI key (or a key of the string table at path) in the game's language
-- (core/unreal.lua's game_text), for the Sessions screen, the join popups, the feed's join and leave lines and the
-- bike's money name; none under ui_language=english.
function M.game_words(key,path)
    if M.settings and M.settings.ui_language~='english' then return U.game_text(key,path) end
end
local photo_failed=false
function M.photo_state()
    if photo_failed then return '0' end
    local ok,state=pcall(function()
        local library=U.find('/Script/SB.Default__SBAutomationBlueprintFunctionLibrary')
        if library:IsSelfieMode() then return 's' end
        return library:IsPhotoMode() and '1' or '0'
    end)
    if ok then return state end
    photo_failed=true
    log('photo sync: photo mode unreadable, off until the mod reloads: '..tostring(state))
    return '0'
end
-- An alias's FName is FNAME_Find's and must read back as the alias, as the follow's camps do.
function M.fname(alias)
    local n=U.value_of(FName(alias,EFindName.FNAME_Find))
    local index=n:GetComparisonIndex()
    if not index or index==0 or U.text(n):lower()~=alias:lower() then return nil end
    return {index=index,number=require('core.line').number(alias)}
end
-- Paused also covers our photo mode and the friend's photo mode that pauses our game: SB's logic stops in both.
function M.logic_paused() return M.kit~=nil and M.kit.paused(true) or M.photo_state()~='0' or M.link.paused() end
-- Roxanne's booking (online/modes/nightop/wiring.lua) reads it; main/pass.lua sets it at each 250 ms pass.
M.at_title=false -- The title screen shown at the last tick's puppet.world: it drops her booking.
M.OFF='coop off is active until the game restarts'
-- Enter with nothing open asks for the chat's box (chat_asked, os.clock), which opens 0.1 s later unless a coop command
-- came from the console around then (typed_at): UE4SS calls our Enter bind whatever has the keyboard, so that Enter was
-- the console's. Its own state is not reflected, so other console commands may still open the box.
M.chat_asked,M.typed_at=nil,-math.huge
M.hud_shown=false -- Our HUD may show (a world, out of our photos): the chat's box opens then only, not at the title.
-- The gap line's frame start (main/input.lua's gap_line) and the last 250 ms pass's end, length, kit.slow and booth
-- times, which main/pass.lua sets.
M.frame_began,M.pass_ended,M.pass_took,M.pass_slow,M.pass_booth=nil,-math.huge,0,0,0
if M.link then
    -- The keep (core/keep.lua): coop-keep.txt, the pass's status and its lookup through the soft path.
    require('core.keep').setup({write=function(text) return M.link.write_file('coop-keep.txt',text) end,
        status=M.link.status,log=log,find=function(p) return U.object_at(p,U.controller()) end})
    -- That name, or the slot-0 member's, cleaned; '' (a stranger's unknown name) as your friend, in w's words.
    function M.her_name(w,name)
        name=require('core.line').clean(name or (M.link.friend()) or '')
        return name~='' and name or w.fight.friend
    end
end
end
