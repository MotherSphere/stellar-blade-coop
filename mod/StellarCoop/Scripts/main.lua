-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- StellarCoop: co-op for Stellar Blade. For now the ghost of an EVE (on with each session; console: coop puppet), drawn
-- by the native part from a table and poses that come back to you: a linked friend's over Steam, yours through an
-- in-process loopback (coop loopback <delay ms> <jitter ms> <loss %> | off), or a recording of yours (coop record
-- [off], coop replay [off]), in the outfit it was captured in (coop basesuit: on the base suit instead; coop look: its
-- cloth, dyes or effects on or off until the mod reloads); the Steam link between two players (coop host, invite, list,
-- join, leave, status, report, copy, allow, deny, remove; the co-op menu on F5, whose rows open the Create a session
-- screen to host (ui/create.lua), invite, leave, open the session list (ui/sessions.lua) and change the settings
-- (ui/menu.lua), within 3 m of a camp phone booth the
-- co-op line instead (session/booth.lua), status and leave on F6 and F8, unless coop-settings.txt says otherwise; join
-- codes and the host's question on a player who is not her Steam friend: session/join.lua), the session chat on Enter,
-- alone in the SBO lobby too (session/chat.lua), its notices in the chat's feed (or, with the UI off, on a line above
-- your EVE), your friend's card, marker and off-screen arrow (partner/hud.lua; the ghost's name tag is their fallback);
-- the co-op saves' question on the title screen
-- (session/saves.lua, auto_coop_save in coop-settings.txt), with coop saves probe|convert|coop|main for the native
-- part's copies and save name by hand, coop saves refresh <0-4> to replace one co-op copy and coop saves export <0-4>
-- <0-4> to write a co-op copy over one of your own saves; and coop where, a line of
-- coordinates to compare between the two PCs; coop mark [text], a numbered line in both players' logs (coop-link.log,
-- and UE4SS.log through the status's mark= line) to line up a test played together;
-- coop no [heal|rule|spawnpt|actor],
-- the Night Operation probe of the T6 test only (nightop/probe.lua), on a co-op save only; coop nightop [start
-- [easy|normal|hard|nightmare] [noaggro|nomove]|stop|revive|shop|buy <n> [count]], Night Operation's run at a level
-- (nightop/run.lua, revive: a downed player's own revive in a co-op run) and its reward shop
-- (nightop/shop.lua), on a co-op save only (stop anywhere); coop challenge
-- [<name>|stop], the challenge runs on the same code (nightop/challenges.lua), solo but the Shooting Range, with each
-- one's best run in coop-records.txt, on a co-op save only (stop anywhere); coop recruiter [off], the cut Night
-- Operation recruiter on a Xion guard near Roxanne (nightop/recruiter.lua), on a co-op save only, who also comes by
-- himself at each Xion load on any save; the friend's revive (session/group.lua, revive
-- in coop-settings.txt or the co-op menu, on by default), with coop revive test, its solo probe at the death screen
-- (co-op saves only, not in the usage line), and the guest's wait while the host watches a cutscene (session/group.lua
-- and the native part's photo pause, cutscene_wait in coop-settings.txt or the co-op menu); the guest's travel to the
-- camp nearest the host (session/travel.lua, follow_host and follow_key in coop-settings.txt or the co-op menu: F7
-- unless set), with coop travel host (as follow_key) and coop travel probe <camp>, its solo test on a co-op save (not
-- in the usage line); coop fight on|off|status|probe|test|record|replay, the shared enemies of Phase 11 (experimental:
-- on only with shared_enemies=on in coop-settings.txt or the co-op menu, which also asks it by itself; the native part
-- shares only on a co-op save, and the probe, test, record and replay run on one only), with notices for what keeps it
-- from sharing; coop fight pilot status|probe|on|off|test freeze|cmc|drive|replay|target, same-place enemies (stages 3a
-- and 3b, same_place and aggro in coop-settings.txt or the co-op menu, the host's for both games: each shared enemy
-- stands in the same place on both screens, moved by the game that runs its AI), with notices for how many it moves and
-- why it went off; same spawns (stage 4, same_spawns in coop-settings.txt or the co-op menu, the host's for both games:
-- where both players stand within 100 m in one zone, the guest's game holds the host's common enemies), with notices
-- for on, stopped and enemies that differ, and coop fight spawn probe, its reads alone on a co-op save; coop quests
-- on|off|status|probe|record|replay|force <number>, the shared quests of Phase 12 (experimental: on only with
-- shared_quests=on in coop-settings.txt or the co-op menu, which also asks it by itself; the native part shares only
-- with a friend linked and both on a co-op save, and the probe, record and replay run on one only), with notices for
-- on, off and each quest step that waits or that the host and the guest made apart; coop world on|off|status, the
-- shared world (experimental: shared_world in coop-settings.txt or the co-op menu asks it on or off by itself, coop
-- world until the mod reloads; doors, levers and lifts one player works change in the other's game too, with a friend
-- linked and both on a co-op save), with notices for on with her and stopped; coop scenes on|off|status, story
-- together (experimental: shared_story in coop-settings.txt or the co-op menu asks it on or off by itself, coop scenes
-- until the mod reloads; a story scene the host plays plays in the guest's game too, with a friend linked and both on a
-- co-op save), with notices for on with her and stopped; the synced photo mode (photo_sync
-- in coop-settings.txt: your friend's photo mode pauses your game, yours pauses theirs; during your own, the notices,
-- and as set the ghost and its name tag, stay out of the shot), with coop freeze <seconds>|off to test the pause alone,
-- and photo_pause=scenery, SB's photo mode without its full pause (experimental); coop ui reset (the menu and the
-- chat's box closed, the game's input back) and coop ui off (the co-op UI gone until the mod reloads); coop race look
-- on|off, your EVE drawn as a Doro and the ghost too, and coop race probe doro, a Doro playing each of its clips
-- (race/doro.lua; test tools, left out of the usage line; both start on a co-op save only); coop race record
-- <name>|cp|save [laps]|cancel|start <name>|quit, Doro races on a track you record (race/run.lua; race_key drops a
-- checkpoint while you record; start on a co-op save only), driven as a car from GO (race/drive.lua), with coop race
-- drive [probe|off|feed impulse|struct|<name> <value>] to probe and tune the driving (a test tool, left out of the
-- usage line; the probe on a co-op save only); coop leviathan [list]|show [body|a|b|tentacle|statue]
-- [<distance m>|auto] [<height m>|auto] [<scale>]|move <distance m>|auto [<height m>|auto]|skin
-- statue|hydra|default|cam [<m/s>]|play [<clip>]|off, a read of the cut Naytiba 10's assets, a display of it playing
-- its clips and a free camera to film it (cut/leviathan.lua; a test tool, left out of the usage line; show, and cam
-- turning the camera on, on a co-op save only); coop gardener, coop tendril, coop mann, coop nier, coop orcal and coop
-- enya, the same words for the cut Naytibas 1 and 6 and four cut models, one of them shown at a time; coop lion
-- [intro]|rows|control|brain skulling|lurker, the cut Lion spawned as an enemy to fight, its table rows added through
-- the native part (cut/lion.lua; left out of the usage line; the words that spawn on a co-op save only); coop gardener
-- fight [intro|half|skulling|rows], the cut Gardener spawned as an enemy the same way (cut/gardener.lua; left out of
-- the usage line; the words that spawn on a co-op save only); coop tendril fight [rows], the cut Tendril the same way,
-- with the Shows of its clips built in memory first (cut/tendril.lua; left out of the usage line; the spawn on a co-op
-- save only); coop chainspin, EVE's cut Tachy Mode ChainSpin, its rows
-- added with the Lion's and the skill started through SB's own effect call while she is in Tachy Mode
-- (cut/chainspin.lua; left out of the usage line; on a co-op save only). coop off stops everything until the game
-- restarts. An XInput pad, read by the native part, drives the co-op menu and the co-op saves' question: View held 1 s
-- opens or closes the menu; D-pad Right held 1 s gets EVE on the bike or off it. The console commands' handlers are in
-- Scripts/commands/ (session, partner, nightop, race, fight and cut), all but coop ui and coop off, which stay here.
-- coop wear [<name>|off [hair|suit]] puts cut hairs and suits on your EVE, display only and on any save (cut/wear.lua).
-- coop scene [emil|orcal|stop] plays two cut scenes through the game's own theater (cut/scene.lua; a scene on a co-op
-- save only). coop lines [<name>|stop] says the unvoiced lines of cut scenes in the chat's feed, and plays unused
-- voice takes with the subtitles the game has for them, on any save (cut/lines.lua).
-- coop glide on|off, EVE's cut glide while Jump is held in the air (cut/glide.lua; a test tool, left out of the usage
-- line; on on a co-op save only).
-- coop emote [list|<name>|off] plays one of EVE's clips on her (a photo-mode pose held until she moves, a wave, or a
-- clip of the Cut category played once), on any save (cut/emote.lua, through the native part's custom animation call).
-- coop bike [status|tune [<name> <value>]] puts EVE on SB's own bike or takes her off it, as bike_key (F3 unless set)
-- and D-pad Right held 1 s do, on any save (commands/bike.lua, bike/ride.lua; its riding model, bike/model.lua, adapts
-- Eve On Wheels by dCharisma1).
-- coop daynight [on|off|status|hour <h>], the day/night cycle's test words (sky/daynight.lua, commands/daynight.lua;
-- left out of the usage line); daynight in coop-settings.txt or the co-op menu turns the cycle on or off.
-- coop shortcut lists the cut Load Shortcut menu's developer saves, read from the game's paks by the native part, on
-- any save (left out of the usage line); coop shortcut load <map> <1-4> writes one, without its achievement data, as
-- co-op slot 5's copy, only with shortcut_load=on and typed twice within 10 s (commands/cut.lua).
-- coop devmenu [list|<row>], the rows of the game's developer cheat menu that still work, through the same Cheat
-- request as coop chainspin (cut/devmenu.lua; left out of the usage line; a row on a co-op save only; coop off runs
-- its clear and lockswitch rows once more when a row ran, even before a Lua reload). coop devinfo quest|player|off, the game's quest debugger
-- and player info panels, opened and closed by the native part through the game's UI manager (game/dev_panels.h; left
-- out of the usage line; any save, as both only read); coop off closes them.
-- coop gift [send <item> [count]|take [n]], SB's cut mailbox as a co-op gift box: consumables sent to the linked
-- friend's mailbox and taken from yours, with the cut toast when one arrives (cut/mailbox.lua; on a co-op save only).
-- coop story [dump|find], the story lines of the game's live save object written to StellarCoopStory.txt, to compare
-- with a save through tools/story_lines.py, or a list of the objects that may hold them; coop-story.txt in the mod
-- folder asks the same while a world is loaded (story/snapshot.lua; read only, any save, left out of the usage line).
-- coop sbo enter|leave|status|hop|back|view [set]|seq <alias>|parts, the SBO lobby in Xion by hand (session/sbo.lua,
-- with sbo_lobby=on; left out of the usage line); the recruiter's Join enters it, or says what is missing. In its world
-- the lobby's screens (ui/lobby.lua) open over the menu camera at the Agit, where menu_key and View held 1 s open them.
-- Every line of ours in UE4SS.log goes through this print, with SteamIDs and join codes masked (core/mask.lua): players
-- post that log in public. coop-status.txt keeps them whole.
local mask=require('core.mask')
local print=function(text) _G.print(mask(text)) end
local function log(message) print('[StellarCoop] '..tostring(message)..'\n') end
local has_version,VERSION=pcall(require,'version') -- Written by tools/install.py; absent in the source tree.
if not has_version or type(VERSION)~='string' then VERSION='dev' end
-- The native part starts its own worker when Windows loads it; '*' only links the DLL and calls nothing. It pins
-- itself, so a Lua reload that frees this state's libraries never unloads it.
local folder=debug.getinfo(1,'S').source:match('^@(.*)[\\/]Scripts[\\/][^\\/]*$')
local loaded,why=false,'mod folder unknown'
if folder and package and package.loadlib then loaded,why=package.loadlib(folder..'\\StellarCoop.dll','*') end
log(loaded and 'Native part loaded.' or 'Native part not loaded: '..tostring(why))
-- The native per-frame entry: a C function in Lua's shape that ignores its Lua state (the DLL links no Lua).
local native_tick=nil
if loaded then
    local f,tick_why=package.loadlib(folder..'\\StellarCoop.dll','coop_tick')
    if type(f)=='function' then native_tick=f else log('Native tick unavailable: '..tostring(tick_why)) end
end
-- The XInput pad, read by the native part: UE4SS binds keyboard keys only, and while the menu or a question holds the
-- game's input the game ignores the pad. An older DLL without it: said once, no pad.
local native_pad=nil
if loaded then
    local f,pad_why=package.loadlib(folder..'\\StellarCoop.dll','coop_pad')
    if type(f)=='function' then native_pad=f
    else log('Native pad unavailable (no controller in the co-op menu): '..tostring(pad_why)) end
end
-- The DLL links no Lua: its event (0 for none) is how many of these eleven arguments it hands back.
local function pad() return select('#',native_pad(0,0,0,0,0,0,0,0,0,0,0)) end
local link=loaded and require('core.link').new(folder) or nil
local settings=nil
if link then
    local notes
    settings,notes=link.settings()
    for _,note in ipairs(notes) do log(note) end
    log(string.format('keys: menu=%s host=%s status=%s leave=%s race=%s, name tag %s, %d poses a second',
        settings.menu_key.name,settings.host_key.name,settings.status_key.name,settings.leave_key.name,
        settings.race_key.name,settings.name_tag and 'on' or 'off',settings.send_rate))
end
-- What the ghost shows: the settings', changed by coop look until the mod reloads (game start or Ctrl+R: the settings
-- again). The ghost holds this same table.
local look={cloth=settings~=nil and settings.cloth,dyes=settings~=nil and settings.dyes,
    effects=settings~=nil and settings.effects}
local function looks()
    return 'look: cloth='..(look.cloth and 'on' or 'off')..' dyes='..(look.dyes and 'on' or 'off')..' effects='
        ..(look.effects and 'on' or 'off')
end
if settings then
    log(looks())
    log('shared enemies: '..(settings.shared_enemies and 'on' or 'off')..' (experimental), fight_chars '
        ..(#settings.fight_chars>0 and table.concat(settings.fight_chars,' ') or 'auto')..', same place '
        ..(settings.same_place and 'on' or 'off')..' (experimental), same spawns '
        ..(settings.same_spawns and 'on' or 'off')..' (experimental), extra enemies '..settings.enemy_extra
        ..', bosses '..(settings.bosses and 'on' or 'off')..' (experimental), boss HP '
        ..math.floor(settings.boss_hp_scale*100+0.5)..' %, spawn filter '..(settings.spawn_filter and 'on' or 'off')
        ..' (experimental)')
    log(string.format('photo sync: %s, longest pause %s, ghost in your photos %s, its name tag %s',settings.photo_sync,
        settings.photo_freeze_max>0 and settings.photo_freeze_max..' s' or 'no limit',
        settings.photo_ghost and 'on' or 'off',settings.photo_name_tag and 'on' or 'off'))
    log('shared quests: '..(settings.shared_quests and 'on' or 'off')..' (experimental)'
        ..(settings.quest_deny~='' and ', quest_deny '..settings.quest_deny or ''))
    log('shared world: '..(settings.shared_world and 'on' or 'off')..' (experimental)')
    log('story together: '..(settings.shared_story and 'on' or 'off')..' (experimental)')
    log('bike: '..(settings.bike and 'on' or 'off')..', bike_key '..settings.bike_key.name)
end
-- A new token per Lua load: the native part then drops what an older load published (withdrawn here as well).
if link then
    link.components(nil)
    link.display(nil)
    link.session(string.format('%d-%d',os.time(),math.floor(os.clock()*1000000)))
end
-- With mod_names=off, no mod's path goes in the capture either.
local capture=require('partner.capture').new(link and link.components or nil,look,link and link.mod_assets or nil,
    settings~=nil and not settings.mod_names)
local notice=require('ui.notice').new()
-- The UI kit, the co-op menu, the chat's box and feed, the partner HUD, the co-op saves' question, the code box, the
-- host's question, the Sessions screen, the Create a session screen and the SBO lobby's screens: with the Steam link.
-- The SBO lobby itself (sbo), its hall maps' rows (halls) and the hold at its arrivals (arrival) are built further
-- down.
local kit,menu,box,hud,saves_ui,code_box,approval,sessions,create,lobby,sbo,halls,arrival
-- The screen the co-op menu opened in its place, while one is open: the Sessions screen or the Create a session screen.
local function open_screen() return sessions.is_open() and sessions or create.is_open() and create or nil end
-- coop ui reset and the focus watchdog: the menu, the chat's box, the code box, the Sessions and Create a session
-- screens and the lobby's screens closed, an open host's question denied, the co-op saves' question closed as Decide
-- later, the game's input given back now and the menu's mouse cursor put back; a lobby screen closed in the lobby world
-- gives the view back to EVE with the room's overlay, as Back does. With why (the watchdog's): it is logged. A co-op
-- saves pass under way is kept.
local function ui_reset(why)
    menu.close(); box.close(); code_box.close(); approval.close(); saves_ui.close(why~=nil); sessions.close()
    create.close()
    local was=lobby.is_open()
    lobby.close()
    if was and sbo.in_lobby() then sbo.to_room(); lobby.room(true) end
    kit.reset()
    if why then log(why) end
end
-- A notice: into the chat's feed while the UI's root is up, else on the line above EVE (ui/notice.lua), the fallback
-- when the UI is off or failed. en: the same line in English (T.en's words), which that line shows when its font cannot
-- draw the other.
local function say(text,en) if not (box and box.say(text)) then notice.say(text,en) end end
-- The words for the screen (ui/text.lua): the game's language unless ui_language=english; English while unread. The
-- log keeps English.
local T=require('ui.text')
local function words() return T.pick(kit and kit.language(),settings and settings.ui_language) end
-- A notice that build(words) puts together: in the menu's words, and in English for the line above EVE.
local function tell(build) say(build(words()),build(T.en)) end
-- UE4SS-settings.ini (core/ue4ss_settings.lua), two folders above the mod's, read only: each key there that UE4SS
-- reads as on is logged now, and its notice said once this Lua load as soon as one can show (the 250 ms loop below,
-- with the Steam link only). A file that cannot be read, or is too large, gets a log line and no notice.
local ue4ss_notes={}
do
    local root=folder and folder:match('^(.*)[\\/][^\\/]+[\\/][^\\/]+$')
    if root then
        local S=require('core.ue4ss_settings')
        local text,why=require('core.link').files.read(root..'\\UE4SS-settings.ini',S.LIMIT+1)
        local on
        if text then on,why=S.check(text) end
        if not on then log('UE4SS-settings.ini not checked: '..tostring(why)) end
        for _,k in ipairs(on or {}) do
            log('UE4SS-settings.ini: '..k.key..(k.value and ' = '..k.value or ' missing (UE4SS then uses its default, '
                ..'on)')..'. '..T.en.ue4ss[k.word])
            ue4ss_notes[#ue4ss_notes+1]=k.word
        end
    end
end
-- The crash sentinel (partner/sentinel.lua): a mod asset the game crashed on during a call of the last Lua load is set
-- aside now, logged, and said once a notice can show, with UE4SS-settings.ini's below.
local sentinel,crashed=require('partner.sentinel').new(link,VERSION)
local aside_note=nil -- The set-aside asset's name for the notice, until said.
if crashed then
    log('Crash sentinel: the game crashed during a call with the mod asset '..crashed.path..' (outfit '..crashed.outfit
        ..'). It is set aside: the ghost draws it as missing until coop cns reset or another mod version.')
    aside_note=(crashed.path:match('([^./]+)$') or crashed.path):sub(1,32)
end
local puppet=require('partner.puppet').new(link,capture,say,settings and settings.name_tag,look,words,sentinel)
-- With the Steam link, a ghost for each other member of a lobby in ghost slots 1 to 6 (a match lobby, or an online
-- session of more than 2 players), each on its slot's files.
local ghosts=link and require('partner.ghosts').new(link,function(files)
    return require('partner.puppet').new(files,capture,say,settings and settings.name_tag,look,words,sentinel)
end)
-- Ghost slot k's puppet past slot 0 (the HUD rows, the revive, the follow), nil before a member held it.
local function ghost_of(k) return ghosts and ghosts.get(k) end
-- coop off lasts until the game restarts, even across a Lua reload (Ctrl+R): the native part remembers it.
-- Read from the pose path's line only, as a peer's Steam name could say the same.
local function native_off()
    return link~=nil and ('\n'..(link.status() or '')):find('\nengine=[^\r\n]* reason=coop_off')~=nil
end
local off=native_off()
-- The native part has it too: from then on its tick runs again, as it only releases a held photo pause tag.
local blocked=off
local USAGE='Use: coop puppet | host [public|friends|invitation|closed] | invite | list [public|friends] | join [lobby id|code|row] | copy | allow|deny|remove|block <SteamID> | unblock <SteamID>|all | blocked | leave | match search|create <mode>|cancel|end|join <code>|leave | mute|unmute <SteamID> | status | report | mark [text] | where | near [metres] | travel host | loopback <delay ms> <jitter ms> <loss %>|off | record [off] | replay [off] | basesuit | look [cloth|dyes|effects on|off] | cns [reset] | wear [<name>|off [hair|suit]] | scene [emil|orcal|stop] | lines [<name>|stop] | emote [list|<name>|off] | bike [status|tune [<name> <value>]] | gun [status] | no [heal|rule|spawnpt|actor] | nightop [start [easy|normal|hard|nightmare] [noaggro|nomove]|stop|revive|shop|buy [<n> [count]]] | challenge [<name>|stop] | recruiter [off] | gift [send <item> [count]|take [n]] | race record <name>|cp|save [laps]|cancel|start <name>|quit | fight on|off|status|probe|test|record|replay|pilot|spawn | quests on|off|status|probe|record|replay|force <number> | world on|off|status | scenes on|off|status | keys reset [<name>|all] | freeze <seconds>|off | ui reset|off | saves probe|convert|coop|main|refresh <0-4>|export <0-4> <0-4> | off'
local function ask(line)
    return function()
        if not link then return false,'the Steam link needs the native part' end
        return link.request(line)
    end
end
-- coop no, coop recruiter, coop fight, coop revive test, the Doro look and probe, coop lion's, coop gardener fight's
-- and coop tendril fight's words that spawn, show and cam turning the free camera on in coop leviathan and the other
-- viewer commands,
-- and a scene of coop scene run only on a co-op save (D2, N9): the native part's slot=coop, from the start of its own
-- line (a Steam name never starts one), for a co-op copy (saves=coop) or the manual co-op slot that StellarCoopSlot.txt
-- names. The ghost, the Steam link and every other command are never locked to it.
local function slot_line() return ('\n'..(link and link.status() or '')):match('\n(slot=[^\r\n]*)') end
local function coop_slot(what)
    local line=slot_line()
    if line and line:find('^slot=coop ') then return true end
    return false,what..' runs only on a co-op save (INSTALL.md: Co-op saves); now '..(line or 'no slot status')
end
-- Its one entry, commands.no, runs only on a co-op save (coop_slot).
local nightop=require('nightop.probe').new(function(m) print('[StellarCoop][NO] '..tostring(m)..'\n') end,
    function(line) return ask(line)() end,function() return link and link.status() end)
-- coop lion (cut/lion.lua), logging [LI] lines: its rows asked of the native part, its status read back. Built before
-- Night Operation's run: the shop asks it for the cut items' rows (rows).
local lion=require('cut.lion').new({log=function(m) print('[StellarCoop][LI] '..tostring(m)..'\n') end,
    ask=function(line) return ask(line)() end,status=function() return link and link.status() end})
-- coop gardener fight (cut/gardener.lua), logging [GD] lines: the same, for the cut Gardener's rows and spawn.
local gardener=require('cut.gardener').new({log=function(m) print('[StellarCoop][GD] '..tostring(m)..'\n') end,
    ask=function(line) return ask(line)() end,status=function() return link and link.status() end})
-- coop tendril fight (cut/tendril.lua), logging [TD] lines: the same, for the cut Tendril's rows, Shows and spawn.
local tendril=require('cut.tendril').new({log=function(m) print('[StellarCoop][TD] '..tostring(m)..'\n') end,
    ask=function(line) return ask(line)() end,status=function() return link and link.status() end})
-- The friend's revive (session/group.lua) and the follow (session/travel.lua), with the Steam link only: built and
-- ticked below.
local group,travel=nil,nil
-- Night Operation's run: commands.nightop starts it on a co-op save only; stop and coop off end it anywhere. It
-- ticks every 250 ms and logs [NR] lines; the game's pause is read even with the UI kit off. Its card and result panel
-- go on the kit (night.hud, below); with the kit off, what they show comes as notices (tell). Linked, its night line
-- goes out through link.night and the partner's name comes from link.friend. The shop's wallets are link.store files.
-- commands.challenge starts the challenges on the same run. Their best runs go in coop-records.txt in the mod folder
-- (none when it is unknown). No such file is no best yet; a file that cannot be opened raises, so nothing is written
-- over it. It is written through a temporary file: a write that fails before the old file is deleted leaves it as it
-- was, one that fails after leaves the new text in coop-records.txt.tmp. In a co-op run, a downed player's revive
-- (with her revive setting on) goes through the friend's revive (group), and the partner's ghost feet come from the
-- puppet.
local night=require('nightop.run').new({log=function(m) print('[StellarCoop][NR] '..tostring(m)..'\n') end,
    status=function() return link and link.status() end,paused=function() return kit~=nil and kit.paused(true) end,
    settings=settings,
    tell=tell,send=function(line) if link then return link.night(line) end end,
    friend=function() return link and (link.friend()) end,store=function(name) return link and link.store(name) end,
    rows=function(done,word) return lion.rows(done,word) end,ask=function(line) return ask(line)() end,
    revive=function(by) if not group then return false,'no Steam link' end return group.night_revive(by) end,
    ghost=function() return select(2,puppet.anchor()) end,
    records=folder and {
        read=function()
            local text,e,code=require('core.link').files.read(folder..'\\coop-records.txt')
            if text==nil and code~=2 then error(e) end -- 2: ENOENT, no such file.
            return text
        end,
        write=function(text)
            local fs,p=require('core.link').files,folder..'\\coop-records.txt'
            if not fs.write(p..'.tmp',text) then return false end
            fs.remove(p) -- rename never replaces on Windows.
            -- The rename refused once the old file went (a virus scanner holding the .tmp): written in place.
            return fs.rename(p..'.tmp',p)==true or not fs.read(p) and fs.write(p,text)
        end} or nil})
-- coop mxiii [30] (matrix13/world/travel.lua), logging [MX] lines: Matrix XIII's camp rows asked of the native part,
-- then the follow's camp travel (read at each call: built below), once the zMXIII_P test pak is found under
-- SB/Content/Paks; coop mxiii leave, the follow's probe to the camp EVE respawned at before coop mxiii, or another camp
-- this save has activated. The same rows alone at the title, before any save loads, while the game uses the co-op save
-- files (the 250 ms loop below: mxiii.title), then its spawn, loot and mechanism rows and the Lion's and the
-- Gardener's. In world 2800 its tick spawns the ladders, ledges and ropes (matrix13/world/move.lua) and fixes the
-- bosses the game spawns (matrix13/world/boss.lua, with coop lion's and coop gardener fight's instances); coop mxiii
-- boss is their key-0 fallback, and coop mxiii warp <n|name> puts EVE on one of the old warp switches' arrival points
-- (a test fallback).
local mxiii=require('matrix13.world.travel').new({log=function(m) print('[StellarCoop][MX] '..tostring(m)..'\n') end,
    ask=function(line) return ask(line)() end,status=function() return link and link.status() end,
    travel=function() return travel end,paks=require('matrix13.world.travel').paks_of(folder),
    read=require('core.link').files.read,lion=lion,gardener=gardener})
-- The teleport screen's extra tabs (ui/region_tabs.lua), logging [RT] lines. Their records come from the native part.
local region_tabs=require('ui.region_tabs').new({log=function(m) print('[StellarCoop][RT] '..tostring(m)..'\n') end,
    ready=function() return link~=nil and require('core.unreal').controller()~=nil end})
-- commands.recruiter runs only on a co-op save; coop off despawns on any slot (cleanup). Once he stands there, his Join
-- is armed, with sbo_lobby=on only: arming swaps a slot in the game's image, and a player who has not turned the lobby
-- on gets no swap (his Join then does what the game's does). The native part counts each Join on the sbo line
-- (session/sbo.lua turns it into an entry, or a notice of what is missing).
local Recruiter=require('nightop.recruiter')
local recruiter=Recruiter.new(function(m) print('[StellarCoop][RC] '..tostring(m)..'\n') end,function()
    if link and settings and settings.sbo_lobby then
        link.request('sbo arm '..Recruiter.index_of(Recruiter.find_name(Recruiter.JOIN))..' 0')
    end
end)
local function ui_log(m) print('[StellarCoop][UI] '..tostring(m)..'\n') end -- The UI kit's lines.
-- The Doro look and probe (race/doro.lua), logging [DR] lines. coop-look.txt lets the next Lua load restore EVE.
local doro=require('race.doro').new({log=function(m) print('[StellarCoop][DR] '..tostring(m)..'\n') end,
    store=link and link.store('coop-look.txt')})
-- The cut model viewer of coop leviathan and the other viewer commands (cut/leviathan.lua): its read, display and
-- free camera, logging [LV] lines. coop-leviathan.txt lets the next Lua load remove a display this one left and give
-- the player controller back. The free camera reads no key while the co-op menu or one of its boxes is open.
local leviathan=require('cut.leviathan').new({log=function(m) print('[StellarCoop][LV] '..tostring(m)..'\n') end,
    store=link and link.store('coop-leviathan.txt'),
    blocked=function()
        return menu~=nil and (menu.is_open() or box.is_open() or code_box.is_open() or approval.is_open()
            or saves_ui.is_open() or open_screen()~=nil)
    end})
-- The races' driving (race/drive.lua), logging [DR] lines: coop-drive.txt lets the next Lua load put EVE's movement
-- back.
local drive=require('race.drive').new({log=doro.log,store=link and link.store('coop-drive.txt'),settings=settings})
-- coop wear (cut/wear.lua), logging [WR] lines: coop-wear.txt lets the next Lua load give EVE the game's meshes back.
-- No look goes on again while the game is paused or shows one of its screens (its wardrobe among them).
local wear=require('cut.wear').new({log=function(m) print('[StellarCoop][WR] '..tostring(m)..'\n') end,
    store=link and link.store('coop-wear.txt'),paused=function() return kit~=nil and kit.paused(true) end})
-- coop scene (cut/scene.lua), logging [SC] lines: two cut scenes through two of SB's theater rows.
local scene=require('cut.scene').new({log=function(m) print('[StellarCoop][SC] '..tostring(m)..'\n') end})
-- coop lines (cut/lines.lua), logging [LN] lines: cut scenes' unvoiced subtitles in the chat's feed, and unused voice
-- takes played as 2D sounds.
local cut_lines=require('cut.lines').new({log=function(m) print('[StellarCoop][LN] '..tostring(m)..'\n') end,
    say=function(text) return box~=nil and box.say(text) end,ready=function() return kit~=nil and kit.ready() end})
-- coop glide (cut/glide.lua), logging [GL] lines: EVE's bGlide set while Jump is held in the air, on a co-op save.
local glide=require('cut.glide').new({log=function(m) print('[StellarCoop][GL] '..tostring(m)..'\n') end,
    slot=function() return coop_slot('coop glide') end})
-- The bike (bike/ride.lua), built below once coop fly's keys are: coop emote, the race, the hall seats and the Doro
-- look read whether EVE rides through riding().
local bike
local function riding() return bike~=nil and bike.riding() end
-- coop emote (cut/emote.lua), logging [EM] lines: one of EVE's clips until she moves, played by the native part (its
-- anim request and the status line's anim field), else as a montage. None starts while she rides.
local emote=require('cut.emote').new({log=function(m) print('[StellarCoop][EM] '..tostring(m)..'\n') end,
    ask=function(line) return ask(line)() end,status=function() return link and link.status() end,riding=riding})
-- Doro races (race/run.lua), logging [DR] lines: the look above on EVE and the ghost's Doro mode while one runs, and
-- the driving from GO. Its start and the guest's answer need a co-op save; it never arms during a Night Operation run.
-- No race starts while EVE rides the bike; the guest's answer to a track line takes her off it first (dismount).
local race=require('race.run').new({log=doro.log,link=link,puppet=puppet,look=doro,drive=drive,tell=tell,
    night=night.running,
    slot=function() return coop_slot('coop race') end,paused=function() return kit~=nil and kit.paused(true) end,
    settings=settings,store=link and link.store('coop-race-doros.txt'),
    dismount=function(why) return bike.stop(why) end})
-- The session chat's model (session/chat.lua, memory only, never logged): her lines come from coop-chat.txt, taken
-- every 250 ms so the file never stays on disk, session or not, and each frame while a race is armed (her race lines
-- come in it too); ours leave through coop-say.txt in the 250 ms loop, or stay on our screen alone in the SBO lobby.
-- Its clock counts that loop's ticks: os.clock is CPU time under some C runtimes, os.time whole seconds.
-- session/chat.lua's view shows and sends the lines (box, below).
local chat,chat_clock=require('session.chat').new(nil,settings and settings.chat),0
-- The chat alone in the SBO lobby said its notice (chat.alone) in this alone stretch.
local alone_told=false
-- A member of the Steam lobby past the handshake, in any ghost slot: link.chatting() reads the slot-0 member only,
-- and a match lobby's other members hear our lines too.
local function heard_by_member()
    for _,m in ipairs(link.members()) do if m.linked then return true end end
    return false
end
-- The synced photo mode: our player in SB's photo mode ('1'), its selfie mode ('s') or neither ('0'), from SB's
-- reflected getters (the library's default object, found once). The first failure turns it off for this Lua load
-- ('0' from then on) with one log line.
local U=require('core.unreal')
-- SB's own word for a StringTable_UI key in the game's language (core/unreal.lua's game_text), for the Sessions screen,
-- the join popups and the feed's join and leave lines; none under ui_language=english.
local function game_words(key) if settings and settings.ui_language~='english' then return U.game_text(key) end end
local Join=require('session.join')
local photo_failed=false
local function photo_state()
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
-- photo_pause (experimental): scenery is SB's own SB.PhotoMode.PauseMethod 1, the method its help calls experimental.
-- The world stops only while photo mode opens; then animations, physics, cloth and effects go on moving (the ghost
-- too, unless photo sync paused the friend's game) while SB's logic stays stopped (enemies, combat, our shared
-- fight). full is 0, the game's default. Each 250 ms with a save loaded or the title shown, the console variable is
-- read and set only when it differs from the setting (with the player controller), then read back: full on an
-- untouched game changes nothing. SB reads it as each photo mode opens, so a change applies from the next. The first
-- engine error, or a set that does not take (another game build), stops it for this Lua load. coop off sets 0 again
-- unless 0 was the last value matched, and logs a line when no player controller lets it.
local PAUSE_METHOD='SB.PhotoMode.PauseMethod'
local pause={synced=nil,failed=false} -- The method last matched (read or set); off for this load.
local function photo_pause(want,why)
    if pause.failed or pause.synced==want then return end
    local ok,result=pcall(function()
        local library=U.find('/Script/Engine.Default__KismetSystemLibrary')
        if library:GetConsoleVariableIntValue(PAUSE_METHOD)==want then return true end
        local pc=U.controller()
        if not pc then return false end -- Not yet: tried again in 250 ms.
        library:ExecuteConsoleCommand(pc,PAUSE_METHOD..' '..want,pc)
        local now=library:GetConsoleVariableIntValue(PAUSE_METHOD)
        if now~=want then error(PAUSE_METHOD..' reads '..tostring(now)..' after the set',0) end
        log('photo pause: '..PAUSE_METHOD..' '..want..' ('..why..')')
        return true
    end)
    if not ok then
        pause.failed=true
        log('photo pause: off until the mod reloads: '..tostring(result))
    elseif result then pause.synced=want end
end
-- shared_enemies=on: coop fight on asked once a load, as soon as the native part judged the slot (coop, main, or none
-- at the title: its build is pinned then); it then waits there for a friend, a co-op save and a loaded save. coop
-- fight off before then cancels the ask. The co-op menu's row changes shared_enemies while the mod runs: on asks again
-- the same way, off asks coop fight off at once when coop fight on waits or runs (fight_wanted: the value last acted
-- on); a probe, record or replay goes on, as at a reload below.
local fight_auto=settings~=nil and settings.shared_enemies
local fight_wanted=fight_auto
-- The co-op menu's same_place row while a mode that pairs (on, record, replay) waits or runs: off asks coop fight
-- pilot off at once, on coop fight pilot on (place_wanted: the value last acted on). With none asked, the next coop
-- fight on carries the setting.
local place_wanted=settings~=nil and settings.same_place
-- shared_enemies=off is a kill switch at a reload too (Ctrl+R): the native part outlives Lua, so a coop fight on that an
-- earlier load started ends here, waiting or running (its fight= line, from the start of its own line). A probe, record
-- or replay goes on: shared_enemies does not gate them.
if settings and not settings.shared_enemies and not off
    and ('\n'..(link.status() or '')):find('\nfight=%a+ mode=on ') then
    local ok,why=ask('fight off')()
    log((ok and 'OK: ' or 'STOP: ')..'shared_enemies=off: '..tostring(why))
end
-- pvp_spike=off is the PvP test's kill switch at a reload the same way: coop pvp on from an earlier load ends here,
-- waiting or running.
if settings and not settings.pvp_spike and not off
    and ('\n'..(link.status() or '')):find('\nfight=%a+ mode=pvp ') then
    local ok,why=ask('fight pvp off')()
    log((ok and 'OK: ' or 'STOP: ')..'pvp_spike=off: '..tostring(why))
end
-- same_place=off too, on the side that hosts: a same place an earlier load asked for ends here, running or waiting
-- (coop fight pilot off, until the next coop fight on). Only there: a guest's own value decides nothing at a start,
-- so a reload never stops what the host's game shows her.
if settings and not settings.same_place and not off then
    local raw='\n'..(link.status() or '')
    if raw:find('\nfight=%a+ mode=record ') or (raw:find('\nfight=%a+ mode=on ') and raw:find('\nlink=host ')) then
        local ok,why=ask('fight pilot off')()
        log((ok and 'OK: ' or 'STOP: ')..'same_place=off: '..tostring(why))
    end
end
-- shared_quests=on: coop quests on asked once a load, as soon as the native part judged the slot, as coop fight on is;
-- it then waits there for a friend and a co-op save. coop quests off before then cancels the ask. The co-op menu's row
-- asks it again (on) or asks coop quests off at once while it waits or runs (off); quests_wanted: the value last acted
-- on. shared_quests=off at a reload (Ctrl+R) ends a coop quests on an earlier load asked, waiting or running; a probe,
-- record or replay goes on.
local quests_auto=settings~=nil and settings.shared_quests
local quests_wanted=quests_auto
if settings and not settings.shared_quests and not off
    and ('\n'..(link.status() or '')):find('\nquests=%a+ mode=on ') then
    local ok,why=ask('quests off')()
    log((ok and 'OK: ' or 'STOP: ')..'shared_quests=off: '..tostring(why))
end
-- shared_world=on: coop world on asked once a load, as soon as the native part judged the slot, as coop quests on is;
-- the native part starts off and then waits for a friend and a co-op save. coop world off before then cancels the ask.
-- The co-op menu's row asks it again (on) or asks coop world off at once (off), whatever the world= line says: that
-- line lags a world on asked a moment before. world_wanted: the value last acted on. shared_world=off at a reload
-- (Ctrl+R) ends a coop world on an earlier load asked.
local world_auto=settings~=nil and settings.shared_world
local world_wanted=world_auto
local function world_running(line) return (line or ''):find('^world=on') or (line or ''):find('^world=waiting') end
if settings and not settings.shared_world and not off
    and world_running(('\n'..(link.status() or '')):match('\n(world=[^\r\n]*)')) then
    local ok,why=ask('world off')()
    log((ok and 'OK: ' or 'STOP: ')..'shared_world=off: '..tostring(why))
end
-- shared_story: the native part starts with it on. Once a load, as soon as the native part judged the slot, the loop
-- asks coop scenes off for shared_story=off, or coop scenes on for shared_story=on while the story= line reads off by
-- the setting (an earlier load's off, or coop scenes off). It asks nothing when the line already agrees. coop scenes on
-- or off before then cancels the ask. The co-op menu's row asks coop scenes on or off at once; scenes_wanted: the value
-- last acted on.
local scenes_auto=settings~=nil
local scenes_wanted=settings~=nil and settings.shared_story
-- The SBO lobby (session/sbo.lua), logging [SB] lines, with the Steam link only: the entry from the recruiter's Join or
-- coop sbo enter, the return, the waiting room, and the rows put back at each title and at coop off. Its notices are
-- keys of ui/text.lua, said in the menu's words. Its engine: SB's game instance, the player controller, EVE, the first
-- actor of a class, FNames, the table rows, each read through a fresh FindRow, and the menu camera (race/doro.lua's
-- free camera actor in EVE's world), and SB's chairs at the hall seats. A fight: EVE's, or an enemy within 30 m that
-- fights. The hall seats SB's chairs leave to menu_key: coop emote plays their loop.
if link then
    local Zones=require('matrix13.quest.zone_talks')
    local Doro=require('race.doro')
    local function row_of(t,name) return U.find('/Game/Local/Data/'..t..'.'..t):FindRow(name) end
    local function eve()
        local her=U.valid(require('UEHelpers').GetPlayer())
        return her and her:IsA(U.find('/Script/SB.SBCharacter')) and her or nil
    end
    local function sbo_log(m) print('[StellarCoop][SB] '..tostring(m)..'\n') end
    -- The hold at each lobby arrival (session/arrival.lua): SB's black (LoadingScreenFadeAuto, tag 5 Load, its fades
    -- 0.5 s each) from the new world's controller until the lobby is ready, the kit veiled under it, then SB's own end
    -- of it through the native part (loading lift). The controller is the one ClientRestart's hook sees (Engine's, as
    -- the warp's map load makes a new one); without the hook no lobby warp holds anything.
    local Arrival=require('session.arrival')
    arrival=Arrival.new({log=sbo_log,
        fade=function()
            U.find('/Script/SB.Default__SBBlueprintLibrary'):LoadingScreenFadeAuto(Arrival.LIFETIME,Arrival.FADE,0,1,
                Arrival.FADE,1,0,5)
        end,
        lift=function() return link.request('loading lift') end,
        veil=function(on) if kit then kit.veil(on) end end})
    local hooked,unhooked=pcall(RegisterHook,'/Script/Engine.PlayerController:ClientRestart',function()
        arrival.restart()
    end)
    if not hooked then
        sbo_log('arrival: no hold at the lobby arrivals: ClientRestart not hooked: '..tostring(unhooked))
    end
    -- The hall lobby maps' world, zone and seat rows (session/halls_rows.lua), asked at the title on the co-op save
    -- files (the 250 ms loop below: halls.title) once the lobby pak gate passed (the SBO lobby's, built next).
    halls=require('session.halls_rows').new({log=sbo_log,status=function() return link.status() end,
        ask=function(line) return ask(line)() end,gate=function() return sbo.gate() end})
    -- The lobby pak gate's inputs: SB/Content/Paks from the mod folder and the file reader; the hall rows' ok().
    sbo=require('session.sbo').new({link=link,settings=settings,recruiter=recruiter,nightop=night,halls=halls,
        paks=require('matrix13.world.travel').paks_of(folder),read=require('core.link').files.read,
        log=sbo_log,emote=emote,arrival=arrival,riding=riding,
        say=function(key) tell(function(w) for part in key:gmatch('[^.]+') do w=w[part] end return w end) end,
        fight=function()
            local her=eve()
            return her~=nil and (her:IsBattle()==true or Zones.engaged(her,3000))
        end,
        ue={game_instance=function() return FindFirstOf('SBGameInstance') end,pc=U.controller,eve=eve,
            first=function(class) return U.valid(FindFirstOf(class)) end,
            find_name=Recruiter.find_name,index_of=Recruiter.index_of,
            rows={read=function(t,name,field) local r=row_of(t,name); return r and U.value_of(r[field]) end,
                write=function(t,name,field,v) local r=row_of(t,name); if r then r[field]=v end end},
            camera=function(at,rotation)
                return Doro.spawn(assert(eve(),'no EVE in the world'):GetWorld(),at,rotation,{camera=true})
            end,
            alive=function(d) return Doro.same(d.actor,d.path) end,
            sweep=function(path) return Doro.sweep(path,'camera') end,
            -- SB's chair blueprint at a hall seat: the class in memory, else loaded (raises when neither). The actor
            -- spawned deferred in EVE's world as matrix13/world/breakables.lua spawns its boxes, AlwaysSpawn (1): its
            -- EnvActorName set to the seat's row before FinishSpawningActor runs its BeginPlay (FUN_142590850, which
            -- registers the name and binds the row), then each named part hidden with its collision off. A step that
            -- raises destroys the actor and raises.
            chair_class=function(asset)
                local path=asset..'_C'
                local c=U.valid(StaticFindObject(path))
                local loaded,why=true,nil
                if not c then
                    loaded,why=pcall(LoadAsset,asset)
                    c=U.valid(StaticFindObject(path))
                end
                return c or error(path..' does not load'..(loaded and '' or ': '..tostring(why)),0)
            end,
            -- The actors of a chair class (its short name: name) in EVE's world, an earlier Lua load's chairs.
            chairs_of=function(class,name) return (U.actors_of(class,name,eve())) end,
            chair=function(class,row,at,parts)
                local gs=U.find('/Script/Engine.Default__GameplayStatics')
                local t=U.find('/Script/Engine.Default__KismetMathLibrary'):MakeTransform({X=at.X,Y=at.Y,Z=at.Z},
                    {Pitch=0,Yaw=at.Yaw,Roll=0},{X=1,Y=1,Z=1})
                local a=U.valid(gs:BeginDeferredActorSpawnFromClass(eve() or error('no EVE in the world',0),class,t,1,
                    nil)) or error('no actor',0)
                local ok,why=pcall(function()
                    a.EnvActorName=FName(row)
                    a=U.valid(gs:FinishSpawningActor(a,t)) or error('FinishSpawningActor gave nothing',0)
                    for _,name in ipairs(parts) do
                        local part=U.valid(a[name]) or error('no component '..name,0)
                        part:SetVisibility(false,false)
                        part:SetCollisionEnabled(0)
                    end
                end)
                if not ok then
                    pcall(function() a:K2_DestroyActor() end)
                    error(why,0)
                end
                return a
            end,
            bound=function(a)
                a=U.valid(a)
                if a then return U.text(a.BindZoneAlias),U.text(a.EnvSpawnAlias) end
            end}})
    if settings.sbo_lobby and not off then sbo.on_load() end
end
-- What the console commands in Scripts/commands/ take from here. group and travel are built later, with the Steam link
-- only, so they are read at each call; coop fight off and coop quests off set fight_auto and quests_auto to false.
local o={link=link,settings=settings,sbo=sbo,puppet=puppet,native_tick=native_tick,look=look,looks=looks,ask=ask,
    coop_slot=coop_slot,nightop=nightop,night=night,race=race,doro=doro,recruiter=recruiter,leviathan=leviathan,
    lion=lion,gardener=gardener,tendril=tendril,mxiii=mxiii,group=function() return group end,
    travel=function() return travel end,
    fight_auto_off=function() fight_auto=false end,quests_auto_off=function() quests_auto=false end,
    world_auto_off=function() world_auto=false end,scenes_auto_off=function() scenes_auto=false end,riding=riding}
-- coop fly's keys (cut/flight.lua), logging [FL] lines: R2 alone flies, Shift with a direction evades.
local flight=require('cut.flight').new({log=function(m) print('[StellarCoop][FL] '..tostring(m)..'\n') end})
o.wear,o.scene,o.lines,o.flight,o.glide,o.emote=wear,scene,cut_lines,flight,glide,emote
-- The bike (bike/ride.lua), logging [BK] lines: SB's own bike as a part on EVE and her ride on it with bike/model.lua
-- through the races' driving (drive), on any save. coop-bike.txt lets the next Lua load put her main mesh back. A mount
-- is refused, with its reason, while SBO's own state holds EVE (busy) or one of our screens is open.
bike=require('bike.ride').new({log=function(m) print('[StellarCoop][BK] '..tostring(m)..'\n') end,
    ask=function(line) return ask(line)() end,status=function() return link and link.status() end,
    store=link and link.store('coop-bike.txt'),drive=drive,settings=settings,
    paused=function() return kit~=nil and kit.paused(true) end,photo=photo_state,
    frozen=function() return link~=nil and link.paused() end,life=function() return link and link.life() end,
    armed=race.armed,
    busy=function()
        if doro.active() then return 'the Doro look is on: coop race look off ends it' end
        if emote.active() then return 'coop emote plays: coop emote off ends it' end
        if sbo and sbo.seated() then return 'EVE sits on a hall seat: stand her up first' end
        if flight.active() then return 'coop fly is on: coop fly off ends it' end
        if glide.active() then return 'coop glide is on: coop glide off ends it' end
        if night.running() then return 'Night Operation is running: coop nightop stop ends it' end
        if menu and (menu.is_open() or box.is_open() or code_box.is_open() or approval.is_open()
            or saves_ui.is_open() or lobby.is_open() or open_screen()~=nil) then
            return 'an SBO menu or the chat is open'
        end
    end})
o.bike=bike
-- The capture leaves the bike's part out while EVE does not ride: hidden, it would take one of the ghost's 16 parts.
capture.leave_out(bike.parked)
-- The day/night cycle (sky/daynight.lua): the request for the native part's env writer (game/sky.h), decided in the
-- 250 ms loop below from the map, the setting and SB's state; coop daynight reads and pins it (commands/daynight.lua).
-- The lobby rule is Xion's training room only: a hall lobby has its own row.
-- coop-sky.txt keeps the originals of the world's lights, so a Lua reload does not take the dimmed ones for them.
o.daynight=require('sky.daynight').new({log=log,ask=function(line) return ask(line)() end,
    status=function() return link and link.status() end,settings=settings,store=link and link.store('coop-sky.txt'),
    her=function() return U.her(U.valid(require('UEHelpers').GetPlayer())) end,address=U.address,map_of=U.map_of,
    world=function(eve) return U.address(eve:GetWorld()) end,
    cutscene=function() return group~=nil and group.cutscene_playing() end,
    screen=function() return kit~=nil and kit.paused(true) end,photo=photo_state,night=night.running,
    frozen=function()
        local p=link and link.photo()
        return p~=nil and p.frozen
    end,
    lobby=function()
        local t=sbo and sbo.target()
        return t~=nil and t.key=='xion'
    end,
    find=function(path) return U.valid(StaticFindObject(path)) end,
    actors_of=function(path)
        local cls,her=U.valid(StaticFindObject(path)),U.her(U.valid(require('UEHelpers').GetPlayer()))
        return cls and her and (U.actors_of(cls,path:match('([^.]+)$'),her)) or {}
    end,
    load=function(path) return LoadAsset(path) end,
    -- The streaming level of a sublevel package in EVE's world (GameplayStatics GetStreamingLevel matches the end of
    -- each streaming level's package name in C++), or nil when it is not streamed.
    level=function(package)
        local her=U.her(U.valid(require('UEHelpers').GetPlayer()))
        return her and U.find('/Script/Engine.Default__GameplayStatics'):GetStreamingLevel(her,FName(package)) or nil
    end,
    exists=function(path)
        local f=io.open(path,'rb')
        if f then f:close() end
        return f~=nil
    end,
    cps=folder and require('sky.rule').cps(folder)})
-- coop chainspin (cut/chainspin.lua), logging [CS] lines: the cut ChainSpin's rows through coop lion, then the request.
o.chainspin=require('cut.chainspin').new({log=function(m) print('[StellarCoop][CS] '..tostring(m)..'\n') end,
    status=function() return link and link.status() end,rows=function(done) return lion.rows(done) end})
-- coop devmenu (cut/devmenu.lua), logging [DM] lines: the developer menu's working rows, through the same call.
o.devmenu=require('cut.devmenu').new({log=function(m) print('[StellarCoop][DM] '..tostring(m)..'\n') end,
    status=function() return link and link.status() end,store=link and link.store('coop-devmenu.txt')})
-- coop story (story/snapshot.lua), logging [ST] lines: the live save object's story lines; its request file is
-- polled in the 250 ms loop below, with the Steam link only.
o.story=require('story.snapshot').new({log=function(m) print('[StellarCoop][ST] '..tostring(m)..'\n') end,
    folder=folder})
-- coop gift (cut/mailbox.lua), logging [GF] lines: SB's cut mailbox as a co-op gift box, with the Steam link only. Its
-- tick runs in the 250 ms loop below, her gift lines come through inbox(), and coop gift runs on a co-op save only
-- (commands/cut.lua). An alias's FName is FNAME_Find's and must read back as the alias, as the follow's camps do.
-- Paused also covers our photo mode and the friend's photo mode that pauses our game: SB's logic stops in both.
local mailbox=link and require('cut.mailbox').new({log=function(m) print('[StellarCoop][GF] '..tostring(m)..'\n') end,
    say=function(text) say(text) end,status=function() return link.status() end,
    request=function(line) return link.request(line) end,read=function(name) return link.read_file(name) end,
    write=function(name,text) return link.write_file(name,text) end,friend=function() return link.friend() end,
    loopback=function() return link.loopback() end,store=link.store('coop-gift-toast.txt'),
    paused=function() return kit~=nil and kit.paused(true) or photo_state()~='0' or link.paused() end,
    name=function(alias)
        local n=U.value_of(FName(alias,EFindName.FNAME_Find))
        local index=n:GetComparisonIndex()
        if not index or index==0 or U.text(n):lower()~=alias:lower() then return nil end
        return {index=index,number=require('session.travel').number(alias)}
    end}) or nil
o.mailbox=mailbox
-- coop ui and coop off stay here: they reach the UI objects built below and the photo pause above.
local commands={
    -- reset, the escape hatch (UI-DESIGN 7.5): the menu and the chat's box closed, the game's input back now; off
    -- (7.6): the co-op UI gone until the mod reloads, the notice line above EVE and the ghost's name tag back (the
    -- co-op saves' question with it; auto_coop_save=always still asks at the title).
    ui=function(sub,arg)
        if (sub=='reset' or sub=='off') and arg==nil then
            if not kit then return false,'the co-op UI needs the Steam link' end
            if sub=='off' then -- The host's question waits for its 30 s: no answer from a UI that is gone.
                menu.stop(); box.stop(); code_box.stop(); kit.stop()
                return true,'co-op UI off until the mod reloads: notices on the line above EVE'
            end
            ui_reset()
            return true,'co-op UI reset: menu and chat closed, the game has its input back'
        end
        return false,'Use: coop ui reset | off'
    end,
    off=function()
        off=true
        if puppet.active() then -- Logged like the stops below: off is set, so a raise here must not skip ask('off').
            local gone,why=pcall(puppet.toggle)
            if not gone then log('ghost: '..tostring(why)) end
        end
        if ghosts then -- The members' ghosts likewise, each line they say logged.
            local gone,said=pcall(ghosts.off)
            if not gone then said={{false,said}} end
            for _,r in ipairs(said) do log((r[1] and 'OK: ' or 'STOP: ')..tostring(r[2])) end
        end
        notice.stop()
        if menu then menu.stop() end
        if box then box.stop() end
        if saves_ui then saves_ui.stop() end
        if code_box then code_box.stop(); approval.stop() end
        if kit then kit.stop() end -- The game's input back, the menu's root gone.
        chat.clear()
        if pause.synced~=0 then -- The game's own photo pause back (a reload may not have read it yet).
            photo_pause(0,'coop off')
            if pause.synced~=0 and not pause.failed then
                log('photo pause: no player controller at coop off: '..PAUSE_METHOD..' stays as it is until the game '
                    ..'exits')
            end
        end
        -- A failing despawn or run end is logged and never stops the rest of coop off.
        local stopped,e=pcall(recruiter.stop)
        if not stopped then log('recruiter: '..tostring(e)) end
        if sbo then -- The rows as shipped and EVE given back; the native off below logs an open record.
            stopped,e=pcall(sbo.off)
            if not stopped then log('sbo: '..tostring(e)) end
        end
        if halls then -- The title's wait for the hall rows ended; rows already in stay for the game run.
            stopped,e=pcall(halls.stop)
            if not stopped then log('halls: '..tostring(e)) end
        end
        region_tabs.stop() -- No more tabs: only a flag.
        stopped,e=pcall(wear.stop) -- EVE's own meshes back.
        if not stopped then log('wear: '..tostring(e)) end
        if o.roxanne then -- Her two choices back before the native part stops taking requests.
            stopped,e=pcall(o.roxanne.stop)
            if not stopped then log('roxanne: '..tostring(e)) end
        end
        if o.lily then -- Lily's eight choices back too.
            stopped,e=pcall(o.lily.stop)
            if not stopped then log('lily: '..tostring(e)) end
        end
        stopped,e=pcall(night.stop,'coop off') -- The shop's screen closes first.
        if not stopped then log('nightop: '..tostring(e)) end
        if group then -- A death screen the revive hid comes back.
            stopped,e=pcall(group.stop)
            if not stopped then log('revive: '..tostring(e)) end
        end
        stopped,e=pcall(bike.stop,'coop off') -- Before the race's stop, which leaves a bike drive to it.
        if not stopped then log('bike: '..tostring(e)) end
        stopped,e=pcall(race.stop)
        if not stopped then log('race: '..tostring(e)) end
        stopped,e=pcall(doro.stop)
        if not stopped then log('doro: '..tostring(e)) end
        stopped,e=pcall(leviathan.stop)
        if not stopped then log('leviathan: '..tostring(e)) end
        stopped,e=pcall(lion.stop)
        if not stopped then log('lion: '..tostring(e)) end
        stopped,e=pcall(gardener.stop)
        if not stopped then log('gardener: '..tostring(e)) end
        stopped,e=pcall(tendril.stop)
        if not stopped then log('tendril: '..tostring(e)) end
        stopped,e=pcall(mxiii.stop)
        if not stopped then log('mxiii: '..tostring(e)) end
        stopped,e=pcall(scene.stop) -- The Stop row: the game's camera, input and HUD back.
        if not stopped then log('scene: '..tostring(e)) end
        stopped,e=pcall(cut_lines.stop)
        if not stopped then log('lines: '..tostring(e)) end
        stopped,e=pcall(flight.off) -- The game's flight keys back.
        if not stopped then log('flight: '..tostring(e)) end
        stopped,e=pcall(glide.stop) -- bGlide false again on EVE.
        if not stopped then log('glide: '..tostring(e)) end
        stopped,e=pcall(emote.stop) -- Her clip stopped: anim stop, asked before off, or the montage's stop.
        if not stopped then log('emote: '..tostring(e)) end
        stopped,e=pcall(o.devmenu.stop) -- clear and lockswitch, while the engine line still names EVE.
        if not stopped then log('devmenu: '..tostring(e)) end
        if mailbox then -- The gift toast off the screen.
            stopped,e=pcall(mailbox.stop)
            if not stopped then log('gift: '..tostring(e)) end
        end
        if not link then return true,'everything is off until the game restarts' end
        stopped,e=pcall(ask('devinfo off')) -- The game's developer panels closed, if open.
        if not stopped then log('devinfo: '..tostring(e)) end
        return ask('off')()
    end,
}
-- The other commands, from Scripts/commands/.
for _,file in ipairs({'session','partner','nightop','race','fight','cut','guide','story','world','scenes','bike','keys',
        'daynight'}) do
    for name,handler in pairs(require('commands.'..file).new(o)) do
        assert(commands[name]==nil,'coop '..name..' is defined twice')
        commands[name]=handler
    end
end
-- Gun mode (gunmode/, logging [GM] lines): a module of its own, built and started inside a pcall so nothing in it
-- can stop the rest of the mod; it reads its own coop-settings.txt lines and finds its own paks. coop gun [status].
local gunmode
do
    local ok,e=pcall(function()
        gunmode=require('gunmode.mode').new({log=function(m) print('[StellarCoop][GM] '..tostring(m)..'\n') end,
            folder=folder})
        gunmode.start()
    end)
    if not ok then log('gun mode: '..tostring(e)); gunmode=nil end
    for name,handler in pairs(require('gunmode.commands').new(function() return gunmode end)) do
        assert(commands[name]==nil,'coop '..name..' is defined twice')
        commands[name]=handler
    end
end
-- Roxanne's Night Operation choices (nightop/roxanne.lua), logging [NR] lines: on a co-op save, once EVE is in Xion;
-- a level picked is booked and started through coop nightop start, the supplies open coop nightop shop. Ticked in the
-- 250 ms loop below (with the Steam link only), after coop off too: coop off puts her two choices back.
local at_title=false -- The title screen shown at the last tick's puppet.world: it drops her booking.
o.roxanne=require('nightop.roxanne').new({log=function(m) print('[StellarCoop][NR] '..tostring(m)..'\n') end,
    status=function() return link and link.status() end,ask=function(line) return ask(line)() end,
    paused=function() return kit~=nil and kit.paused(true) end,title=function() return at_title end,tell=tell,
    start=function(level) return commands.nightop('start',level) end,
    shop=function() return commands.nightop('shop') end,phase=function() return night.phase() end})
-- The Xion guard's lines in the game's language (nightop/guard_text.lua), logging [RC] lines: ticked in the 250 ms loop
-- below (with the Steam link only) until coop off, after which the native part puts his Korean back.
local guard_text=require('nightop.guard_text').new({log=function(m) print('[StellarCoop][RC] '..tostring(m)..'\n') end,
    status=function() return link and link.status() end,ask=function(line) return ask(line)() end})
-- Lily's signal (matrix13/quest/on_time.lua, experimental), logging [LY] lines: on a co-op save, solo, with the
-- zMXIII_P test pak, in Phase 5 the mod's prologue starts and her choice list offers "The other signal"; its pick plays
-- the prologue talk, starts the mod's quest "On Time" and runs coop mxiii's travel; coop lily signal|talk|hold by hand.
-- Ticked in the 250 ms loop below (with the Steam link only), after coop off too: coop off puts her list back. Its rows
-- also go in at the title on the co-op save files, with the test pak only (lily.title). Its talks (story/subtitles.lua)
-- play through coop scene's rows, ticked each frame below.
local function lily_log(m) print('[StellarCoop][LY] '..tostring(m)..'\n') end
local talks=require('story.subtitles').new({log=lily_log,scene=scene})
-- Mila's body (matrix13/world/mila.lua): placed by the zone talks, posed by coop mxiii mila (commands/cut.lua).
o.mila=require('matrix13.world.mila').new({log=lily_log,
    read=function(name) return link and link.read_file(name) end,
    write=function(name,text) if link then return link.write_file(name,text) end end})
o.lily=require('matrix13.quest.on_time').new({log=lily_log,
    status=function() return link and link.status() end,ask=function(line) return ask(line)() end,
    mode=function() return link and link.mode() end,paused=function() return kit~=nil and kit.paused(true) end,
    travel=function() return commands.mxiii() end,paks=require('matrix13.world.travel').paks_of(folder),
    read=require('core.link').files.read,talks=talks,
    zones=require('matrix13.quest.zone_talks').new({log=lily_log,talks=talks,plan=require('matrix13.quest.on_time').plan,
        read=function(name) return link and link.read_file(name) end,
        write=function(name,text) if link then return link.write_file(name,text) end end,mila=o.mila})})
local function report(ok,message) log((ok and 'OK: ' or 'STOP: ')..tostring(message)) end
-- What partner/ghosts.lua's calls said: a list of {ok, message}.
local function report_each(said) for _,r in ipairs(said or {}) do report(r[1],r[2]) end end
local OFF='coop off is active until the game restarts'
-- A console command, a key or a menu row, on the game thread: logged, and its result returned.
local function run(name,a,b,c,d,e,f)
    local command=commands[name or '']
    if not command then log(USAGE); return false,USAGE end
    if off and command~=commands.status and command~=commands.report then
        report(false,OFF)
        return false,OFF
    end
    local ran,ok,message=pcall(command,a,b,c,d,e,f)
    if not ran then ok,message=false,ok end
    report(ok,message)
    return ok,message
end
-- The chat's box and feed (session/chat.lua's view), the partner HUD (partner/hud.lua's), Night Operation's card and
-- result panel (nightop/run.lua's), the code box (session/join.lua), the co-op menu (ui/menu.lua), the host's question
-- (session/join.lua) and the co-op saves' question (session/saves.lua) on the Uplink kit (ui/kit.lua), with the Steam
-- link only: its root is built in a world or on the title screen, after one lookup a 250 ms tick. The feed and the HUDs
-- first: the menu draws over them, the questions over all. The camp phone booths near EVE (session/booth.lua): the menu
-- key opens the co-op line at one.
local booth=require('session.booth').new(log)
-- The lobby's screens closed, the view back to EVE and the room's overlay on (design-lobby 2.7): Back and "Waiting
-- room" on B, menu_key or View held 1 s while B or C is open.
local function lobby_room() lobby.close(); sbo.to_room(); lobby.room(true) end
-- In the lobby world, menu_key and View held 1 s away from a seat: B, then the view on the menu camera.
local function lobby_menu()
    local ok,why=lobby.open('menu')
    if ok then sbo.to_menu() else report(false,why) end
end
-- In the lobby world with no lobby screen open, menu_key and View held 1 s: EVE stands up while she sits on a hall seat,
-- sits on one within reach that SB's chairs left to menu_key (no chair bound there), else B opens.
local function lobby_key()
    if sbo.seated() then return report(sbo.stand()) end
    local seat=sbo.near_seat()
    if seat then return report(sbo.sit(seat)) end
    lobby_menu()
end
-- The hint for lobby_key at the bottom centre while no lobby screen is open: Stand up while EVE sits, Sit near a seat
-- SB's chairs left to menu_key (ui/menu.lua's booth hint, with this word).
local function seat_hint()
    if not sbo.in_lobby() or lobby.is_open() then return nil end
    if sbo.seated() then return {word='stand'} end
    return sbo.near_seat() and {word='sit'} or nil
end
if settings then
    local Ui=require('ui.kit')
    kit=Ui.kit({log=ui_log,store=link.store('coop-ui.txt'),scale=settings.ui_scale,sounds=settings.ui_sounds,
        uidev=link.uidev})
    box=require('session.chat').view({kit=kit,model=chat,settings=settings,theme=Ui.THEME,
        covered=function() return menu.is_open() end})
    hud=require('partner.hud').hud({kit=kit,link=link,puppet=puppet,settings=settings,theme=Ui.THEME,ghost=ghost_of})
    night.hud({kit=kit,theme=Ui.THEME,settings=settings})
    race.hud({kit=kit,theme=Ui.THEME,settings=settings})
    talks.hud({kit=kit,theme=Ui.THEME}) -- The kit version of Lily's talks.
    -- The lobby's view keeps our last match request ('search', 'create', or 'join' from the code box), when its Code
    -- row copied the code, and the map picked on C for a Private match ('random' or a hall's key, for this Lua load).
    local last,copied_at,room=nil,nil,'random'
    code_box=Join.box({kit=kit,link=link,settings=settings,theme=Ui.THEME,run=function(name,...)
        local ok,why=run(name,...)
        if ok and name=='join' then last='join' end
        return ok,why
    end})
    -- The first-launch guide (ui/guide.lua): the menu's Guide row and coop guide open it; in front of the co-op saves'
    -- question, it takes the question's keys, pad, clicks and loops first (front), and the question waits for it. It
    -- never opens over another co-op panel (busy).
    local guide=require('ui.guide').new({kit=kit,link=link,settings=settings,theme=Ui.THEME,log=log,folder=folder,
        busy=function()
            return menu.is_open() or box.is_open() or code_box.is_open() or approval.is_open() or saves_ui.is_open()
                or open_screen()~=nil
        end})
    o.guide=guide
    -- The Sessions screen (ui/sessions.lua), which the menu's Find a session opens: the session list's rows read
    -- fresh at each call, with our protocol and game build from the status's first line; its searches and joins go to
    -- the native part as the lobby's requests do. SB's words in the game's language, none under ui_language=english.
    sessions=require('ui.sessions').new({kit=kit,words=words,log=ui_log,
        view=function()
            local first=('\n'..(link.status() or '')):match('\n(mod=[^\n]*)') or ''
            local search,rows=link.list()
            return {search=search,rows=rows,match=link.match(),role=link.mode() or 'none',
                proto=first:match(' proto=(%d+)'),build=first:match(' build=(%d+)')}
        end,
        act=function(a) report(link.request(a.request)) end,game_text=game_words})
    o.sessions=sessions
    menu=require('ui.menu').new({kit=kit,link=link,settings=settings,look=look,puppet=puppet,run=run,log=log,
        version=VERSION,chat=box,code=code_box,guide=guide,sessions=sessions})
    o.menu=menu -- For coop keys reset (commands/keys.lua).
    -- The Create a session screen (ui/create.lua), which Host a session and coop host alone open (commands/session.lua
    -- reads o.create): the settings in effect, written back as the Options page writes them; Start hosts with its Who
    -- can join word through coop host.
    local Options=require('ui.model')
    create=require('ui.create').new({kit=kit,words=words,log=ui_log,
        view=function()
            return {values=Options.values(settings),readable=link.settings_text()~=nil,role=link.mode() or 'none'}
        end,
        act=function(a)
            if a.set then return menu.set(a.set,a.value) end
            return run('host',a.host)
        end})
    o.create=function() return create end
    approval=Join.ask({kit=kit,link=link,settings=settings,run=run,say=say,log=ui_log,game_text=game_words,menu=menu,
        chat=box,guide=guide})
    saves_ui=guide.front(require('session.saves').new({kit=kit,link=link,settings=settings,theme=Ui.THEME,say=say,
        log=log,wait=guide.waiting}))
    -- The SBO lobby's screens (ui/lobby.lua), over the rest: B and C, the leave question, the countdown and the room's
    -- overlay. view: Model.view's input, read fresh at each call (L15 R25, L12-R1); act: what a row asks for.
    local LAST={['match search']='search',['match create']='create',join='join'}
    local function view()
        local version,proto=('\n'..(link.status() or '')):match('\nmod=(%S+) proto=(%d+)')
        return {match=link.match(),members=link.members(),role=link.mode() or 'none',limit=link.cap(),code=(link.code()),
            me={id=(link.saves() or {}).steamid,name=link.me()},owner=link.owner(),last=last,copied_at=copied_at,
            now=os.clock(),version=version,proto=tonumber(proto),settings=settings,halls=sbo.hall()~='xion',room=room}
    end
    local function act(a)
        if a.request then -- Search (with the SBO lobby's room and hall words), Private, Cancel, and C's mute rows.
            local ok,why
            if a.lobby and a.request:find('^match create') then ok,why=sbo.create(a.request,room) -- On C's map.
            else ok,why=link.request(a.lobby and a.request..' '..sbo.lobby_words() or a.request) end
            report(ok,why)
            local word=a.request:match('^match %a+') or a.request:match('^join')
            if ok and LAST[word or ''] then last=LAST[word] end
        elseif a.open=='join' then -- As the co-op menu's row opens the code box.
            lobby_room()
            code_box.open()
        elseif a.open=='settings' then lobby.open('settings')
        elseif a.close=='room' then lobby_room()
        elseif a.popup=='leave' then
            local ok,why=lobby.popup('leave',function(yes)
                if not yes then return end
                lobby_room() -- The view back to EVE before the return holds her.
                report(sbo.leave())
            end)
            if not ok then report(false,why) end
        elseif a.copy then
            if run('copy') then copied_at=os.clock() end
        elseif a.set=='room' then room=a.value -- Not a coop-settings.txt setting: menu.set knows no such key.
        elseif a.set then menu.set(a.set,a.value)
        elseif a.run then run(a.run) end
    end
    lobby=require('ui.lobby').new({kit=kit,words=words,view=view,act=act,log=ui_log})
    o.lobby=lobby
end
-- Enter with nothing open asks for the chat's box (chat_asked, os.clock), which opens 0.1 s later unless a coop command
-- came from the console around then (typed_at): UE4SS calls our Enter bind whatever has the keyboard, so that Enter was
-- the console's. Its own state is not reflected, so other console commands may still open the box.
local chat_asked,typed_at=nil,-math.huge
local hud_shown=false -- Our HUD may show (a world, out of our photos): the chat's box opens then only, not at the title.
-- The Lua frame time of the ghost's place and of the UI's ticks (UI-DESIGN 7.3, measured in T-UI1), summed and logged
-- once a minute with the UI up. os.clock steps by whole ms under the game's C runtime: over a minute's frames the sum
-- averages out. The Doro look's frame and the race's are timed beside them. A mean hides a frozen frame, so the line
-- also gives the longest frame and the longest 250 ms pass ({longest, count over 16 ms, count over 50 ms}), and the
-- longest call of mxiii, lion and scene (each frame) and of booth and kit.slow (each 250 ms).
local function new_timed(since)
    return {ghost=0,doro=0,race=0,ui=0,frames=0,since=since,frame={0,0,0},pass={0,0,0},mxiii=0,lion=0,scene=0,booth=0,
        slow=0}
end
local timed=new_timed(nil)
-- os.clock steps by whole ms in game (the booths' slow scan lines read 31.0, 44.0, 56.0 ms): over 16 ms reads 17 or
-- more, over 50 ms 51 or more.
local function passed(p,spent)
    if spent>p[1] then p[1]=spent end
    if spent>0.0165 then p[2]=p[2]+1 end
    if spent>0.0505 then p[3]=p[3]+1 end
end
-- The gap line, the Lua twin of the native part's (glue/tick/worker.inc's log_gap, in coop-link.log; UE4SS stamps
-- both in UTC): a frame that starts over 100 ms after the last one names the 250 ms pass that ran in between, by its
-- length and its kit.slow and booth calls (took, set by peaked), or says none did. At most GAP_LINES from the first of
-- a minute, then one line says so: each frame of a long load is a gap.
local GAP_LINES=200 -- A save load, its warp and a hall's arrival logged 25 gaps in 64 s; 600 at most fit a minute.
local took={slow=0,booth=0} -- Each peaked call's time, as last run.
local frame_began,pass_ended,pass_took,pass_slow,pass_booth=nil,-math.huge,0,0,0
local gap_lines,gap_since=0,-math.huge
local function gap_line(began)
    local last=frame_began
    frame_began=began
    if not last or began-last<0.1005 then return end -- os.clock's whole ms, as passed reads them: 101 or more.
    if began-gap_since>=60 then gap_since,gap_lines=began,0 end
    gap_lines=gap_lines+1
    if gap_lines>GAP_LINES then
        if gap_lines==GAP_LINES+1 then log('gap lines: '..GAP_LINES..' this minute, no more until it ends') end
        return
    end
    local function ms(v) return string.format('%.0f',v*1000) end
    if pass_ended>last then
        log('gap '..ms(began-last)..' ms before this frame; 250 ms pass in it: '..ms(pass_took)..' ms (kit.slow '
            ..ms(pass_slow)..', booth '..ms(pass_booth)..')')
    else
        log('gap '..ms(began-last)..' ms before this frame; no pass in it')
    end
end
-- coop-chat.txt, taken and deleted at once: her chat lines to the chat (on the line above EVE while the feed cannot
-- show them: the UI off or failed, or still warming), her race lines to the race, a line of ours that could not go to
-- the chat's fail. Every 250 ms, and each frame while a race is armed.
local function inbox()
    for _,line in ipairs(link.take_chat()) do
        if line.fail then chat.fail()
        elseif line.race then race.receive(line.race)
        elseif line.gift then
            local ok,e=true,nil
            if not off then ok,e=pcall(mailbox.receive,line.gift) end
            if not ok then log('gift: '..tostring(e)) end
        elseif line.text then
            local m=line.from and link.member(line.from)
            local got=chat.receive((m and m.name) or (link.friend()) or '',line.text,chat_clock)
            if got and not kit.ready() then
                local function said(w) return w.chat.said:format(got.name~='' and got.name or w.chat.partner) end
                notice.say(said(words())..got.text,said(T.en)..got.text)
            end
        end
    end
end
-- A pad event, routed as the keys route theirs (the key block below): an open lobby screen (its question, C, B) takes
-- the six navigation words, and menu (View held 1 s) closes B or C to the room; the menu open takes the six navigation
-- words, and menu closes it; the co-op saves' question takes up, down, select and back; with nothing open, in a world
-- with our HUD shown, menu sits EVE down, stands her up or opens B in the lobby world (lobby_key) and opens the co-op
-- menu elsewhere, as menu_key does, its refusals said the same way. The host's question and the joiner's wait, while
-- one is open, take every word first (A is Jump and the D-pad uses items: for 1 s after it shows a press does nothing;
-- Decline has the focus, so a stray A declines; a held stick's or D-pad's repeats never move that focus). While the menu waits for a key only back acts: it stops the wait
-- (menu.nav). The chat's box and the code box take only back, which closes them as Esc does: nothing is typed or sent.
-- A pad alone is never stuck there. LB and RB (tab_left, tab_right) change C's tabs while C is open; nothing
-- elsewhere.
-- The Sessions screen or the Create a session screen, after the lobby's, takes them all and Y (refresh, the Sessions
-- screen's only); menu closes it.
-- bike (D-pad Right held 1 s) gets EVE on the bike or off it as bike_key does, in a world with our HUD shown, none of
-- our screens open (the host's question, the Sessions screen and the Create a session screen included) and the game
-- neither paused nor showing one of its own screens, such as its inventory or map; otherwise it logs why and does
-- nothing.
local PAD={'up','down','left','right','select','back','menu','tab_left','tab_right','bike','refresh'}
-- bike_key and the pad's bike: EVE on the bike or off it, logged as a command is. A refusal also goes on screen, in
-- English as the bike gives it, since the press shows nothing else.
local function bike_press(by)
    if off then return report(false,OFF) end
    local ran,ok,message=pcall(bike.toggle,by)
    if not ran then ok,message=false,ok end
    report(ok,message)
    if not ok then say(tostring(message)) end
end
local function pad_event(what)
    if what=='bike' then
        local why=not hud_shown and 'our HUD is not shown'
            or (approval.is_open() or lobby.is_open() or code_box.is_open() or box.is_open() or menu.is_open()
                or saves_ui.is_open() or open_screen()~=nil) and 'one of our screens is open'
            or kit~=nil and kit.paused(true) and 'the game is paused or shows one of its screens'
        if why then log('pad: bike ignored: '..why); return end
        log('pad: bike')
        bike_press('the pad')
        return
    end
    if approval.is_open() then return approval.nav(what) end
    local screen=open_screen()
    if screen and not lobby.is_open() then
        if what~='menu' then return screen.nav(what) end
        log('pad: menu')
        return screen.close()
    end
    if what=='tab_left' or what=='tab_right' or what=='refresh' then
        if what~='refresh' and lobby.is_open()=='settings' then lobby.nav(what) end
        return
    end
    if lobby.is_open() then
        if what~='menu' then return lobby.nav(what) end
        if lobby.is_open()~='popup' then
            log('pad: menu')
            lobby_room()
        end
        return
    end
    if code_box.is_open() or box.is_open() then
        if what=='back' then (code_box.is_open() and code_box or box).cancel() end
        return
    end
    if menu.is_open() then
        if what~='menu' then return menu.nav(what) end
        if menu.capturing() then return end
        log('pad: menu')
        return menu.toggle()
    end
    if saves_ui.is_open() then
        if what=='up' or what=='down' or what=='select' or what=='back' then saves_ui.nav(what) end
    elseif what=='menu' and hud_shown then
        log('pad: menu')
        if sbo.in_lobby() then return lobby_key() end
        local ok,why,shown,en=menu.toggle(booth.near(puppet.me()))
        if why then report(ok,why); say(shown or why,en) end
    end
end
RegisterConsoleCommandHandler('coop',function(_,parameters)
    typed_at=os.clock()
    -- A seventh word too, so a command that takes six (coop leviathan show) refuses one more.
    local name,a,b,c,d,e,f=parameters[1],parameters[2],parameters[3],parameters[4],parameters[5],parameters[6],
        parameters[7]
    if name=='mark' then a=table.concat(parameters,' ',2) end -- Its text, whatever the number of words.
    ExecuteInGameThread(function() run(name,a,b,c,d,e,f) end)
    return true
end)
assert(type(LoopInGameThreadWithDelay)=='function','This UE4SS lacks game-thread timers.')
-- Each module's work in the two loops below (its tick, slow, restore and the like) runs guarded: an error that escapes
-- it is logged once a Lua load for that call, under the module's name, with its message and stack traceback (most of
-- our errors are raised at level 0, and UE4SS's own carry no line), and the modules after it still run in that pass.
-- The once goes by the function, not the name: a module's other calls under the same name still log their own first
-- error. A guarded call gives back its first two results, or nothing after an error. Measured with Lua 5.4 on the build
-- machine, the xpcall adds about 40 ns a call: under 2 µs a frame for the per-frame loop's 29 to 45 calls (36 with the
-- UI, plus the inbox while a race is armed and up to 8 pad events).
local escaped={} -- The guarded functions whose error was logged this Lua load.
local running -- The guarded function under way: its traceback is built only for the error that gets logged.
local function traced(message)
    if escaped[running] then return message end
    return debug.traceback(message,2)
end
local function guarded(name,f,...)
    running=f
    local ran,ok,message=xpcall(f,traced,...)
    if ran then return ok,message end
    local key=f or name -- A nil index would raise here.
    if not escaped[key] then
        escaped[key]=true
        log(name..': error (logged once until the mod reloads; the other modules go on): '..tostring(ok))
    end
end
-- A guarded call whose time goes into timed[key] when it is the longest of the minute.
local function peaked(key,name,f,...)
    local began=os.clock()
    local ok,message=guarded(name,f,...)
    local spent=os.clock()-began
    if spent>timed[key] then timed[key]=spent end
    took[key]=spent
    return ok,message
end
LoopInGameThreadWithDelay(1,function()
    local began=os.clock()
    if not off then gap_line(began) end -- The native part's gap lines stop at coop off too.
    -- The status as of the last 250 ms pass is dropped even when that pass raised before its own settle().
    if link then link.settle() end
    guarded('doro',doro.restore) -- At the first tick, coop off or not: EVE whole again after a reload with the look on.
    guarded('leviathan',leviathan.restore) -- Likewise for a cut Naytiba display an earlier load left.
    guarded('drive',drive.restore) -- Likewise for her movement after a reload with the driving on.
    guarded('wear',wear.restore) -- Likewise for her own meshes after a reload with a coop wear look on.
    guarded('flight',flight.restore) -- Likewise for the flight keys after a reload with coop fly on.
    guarded('scene',scene.restore) -- Likewise for a scene an earlier load left playing, and the farewell take it lent.
    guarded('glide',glide.restore) -- Likewise for a bGlide an earlier load left on.
    guarded('emote',emote.restore) -- Likewise for a pose's montage an earlier load left playing.
    guarded('bike',bike.restore) -- Likewise for her main mesh after a reload with her on the bike.
    if off then if blocked and native_tick then native_tick() end return end
    local ok,message=guarded('ghost',puppet.tick)
    if message then report(ok,message) end
    if ghosts then report_each(guarded('ghost',ghosts.tick)) end
    local steered=os.clock()
    -- Before the native tick: the pose it captures has the yaw the driving writes.
    ok,message=guarded('race',race.steer)
    if message then report(ok,message) end
    -- The bike's frame, before the native tick too: her drive's yaw, her lean and pitch. Its end said on screen.
    ok,message=guarded('bike',bike.steer)
    if message then report(ok,message); say(message) end
    steered=os.clock()-steered -- The race column carries the bike's frame: the first ride gives its real cost.
    if native_tick then native_tick() end
    local placed=os.clock()
    ok,message=guarded('ghost',puppet.place) -- The root takes the mailbox this native tick just wrote.
    if message then report(ok,message) end
    if ghosts then report_each(guarded('ghost',ghosts.place)) end
    placed=os.clock()-placed
    local looked=os.clock()
    ok,message=guarded('doro',doro.tick) -- After the native tick: EVE's mesh is where this frame draws her.
    if message then report(ok,message) end
    looked=os.clock()-looked
    ok,message=guarded('leviathan',leviathan.tick) -- Outside the doro column of the frame time line.
    if message then report(ok,message) end
    ok,message=peaked('lion','lion',lion.tick)
    if message then report(ok,message) end
    ok,message=guarded('gardener',gardener.tick)
    if message then report(ok,message) end
    ok,message=guarded('tendril',tendril.tick)
    if message then report(ok,message) end
    ok,message=peaked('mxiii','mxiii',mxiii.tick)
    if message then report(ok,message) end
    ok,message=peaked('scene','scene',scene.tick)
    if message then report(ok,message) end
    guarded('region tabs',region_tabs.tick) -- Once a load: its two hooks, once there is a player controller.
    guarded('talks',talks.tick) -- Lily's talks: a hold, the Stop after the last line, the kit's lines.
    guarded('flight',flight.tick)
    ok,message=guarded('lines',cut_lines.tick)
    if message then report(ok,message) end
    ok,message=guarded('glide',glide.tick)
    if message then report(ok,message) end
    ok,message=guarded('emote',emote.tick)
    if message then report(ok,message) end
    local raced=os.clock()
    if link and race.armed() then guarded('inbox',inbox) end
    ok,message=guarded('race',race.tick) -- After the look: its Doros and HUD from where EVE is drawn this frame.
    if message then report(ok,message) end
    raced=os.clock()-raced+steered
    ok,message=guarded('notice',notice.tick)
    if message then report(ok,message) end
    guarded('probe',nightop.tick) -- A due probe follow-up: it logs its own lines.
    guarded('recruiter',recruiter.tick) -- Likewise for coop recruiter.
    ok,message=guarded('wear',wear.tick) -- Once a second at most: a worn look the game replaced goes on again.
    if message then report(ok,message) end
    -- The open and close tweens, the game's input back after a close, the chat box focused again, the partner's marker
    -- (each frame, from the ghost's place just set).
    if kit then
        local now=os.clock()
        ok,message=guarded('kit',kit.tick,now)
        if message then report(ok,message) end
        guarded('menu',menu.tick,now)
        guarded('lobby',lobby.tick,now)
        guarded('sessions',sessions.tick,now)
        guarded('create',create.tick,now)
        guarded('chat',box.tick,now)
        guarded('join',code_box.tick,now)
        guarded('join',approval.tick,now)
        guarded('saves',saves_ui.tick,now)
        guarded('hud',hud.tick,now)
        if native_pad then -- At most 8 pad events a frame, the native part's whole ring.
            for _=1,8 do
                local what=PAD[pad()]
                if not what then break end
                guarded('pad',pad_event,what)
            end
        end
        if chat_asked and now>=chat_asked+0.1 then
            local asked=chat_asked
            chat_asked=nil
            if typed_at<asked-0.3 and not menu.is_open() and not approval.is_open() and not lobby.is_open()
                and not open_screen() then
                local _,why,en=box.open() -- Said on screen only: Enter is the game's too.
                if why then say(why,en) end
            end
        end
        local t=os.clock()
        timed.since=timed.since or t
        timed.ghost,timed.doro,timed.race=timed.ghost+placed,timed.doro+looked,timed.race+raced
        timed.ui,timed.frames=timed.ui+t-now,timed.frames+1
        passed(timed.frame,t-began)
        if t-timed.since>=60 then
            if kit.ready() then
                local function ms(v) return v*1000/timed.frames end
                local f,p=timed.frame,timed.pass
                log(string.format('Lua frame time, last 60 s: ghost %.3f ms, doro %.3f ms, race %.3f ms, UI %.3f ms a '
                    ..'frame (%d frames); longest frame %.1f ms (%d over 16 ms, %d over 50 ms): mxiii %.1f ms, lion '
                    ..'%.1f ms, scene %.1f ms; longest 250 ms pass %.1f ms (%d over 16 ms, %d over 50 ms): booth %.1f '
                    ..'ms, kit.slow %.1f ms',ms(timed.ghost),ms(timed.doro),ms(timed.race),ms(timed.ui),timed.frames,
                    f[1]*1000,f[2],f[3],timed.mxiii*1000,timed.lion*1000,timed.scene*1000,p[1]*1000,p[2],p[3],
                    timed.booth*1000,timed.slow*1000))
            end
            timed=new_timed(t)
        end
    end
end)
if link then
    -- The ghost turns on when a session starts (none to host or guest): once, so coop puppet off holds until the next.
    -- A status read with no mode (before Steam, or unreadable) is no leave.
    local last_mode='none'
    -- The shared enemies' notices, from the fight= line (an unread status changes nothing), in the menu's language
    -- (read only to say one): on with the count when its enemies go from none to some, and the host's scaling unless it
    -- is 100 % and 100 % (the line's scale=, which the guest has from the host); off, or stopped for the run, once it
    -- ran or waited, in any mode, unless our own player ended it (coop fight off, the menu's row, coop off);
    -- and while coop fight on waits or runs, one notice for what keeps it from sharing, said again only when that
    -- changes, and FIGHT_HOLD seconds after the last at the soonest (her lines set her state, so a friend flipping it
    -- cannot flood them): your save or hers not a co-op one, her shared enemies off or stopped for the run, or the two
    -- of you on different maps. Waits that end by themselves (no friend yet, a load, photo mode) say nothing. Sharing
    -- with her on the same map, or the session's end, forgets what was said. Sharing as the guest, two more: once
    -- until it stops or the friend leaves, when the host has enemies we cannot pair for their MaxHP (the line's
    -- maxhp=: another difficulty or New Game+); and each time the host goes down (her vitals, as the partner card reads
    -- them) while enemies are linked: its respawn resets its enemies, and ours heal back to them.
    local P=require('partner.hud')
    local FIGHT_HOLD=5
    local fight_was,fight_count,fight_told,fight_hold=nil,0,nil,0
    local fight_maxhp,host_down=false,false
    -- Same spawns' notices (stage 4), from the same line while coop fight on runs: on once a session when its spawns=
    -- first reads on (the host's words or the guest's), stopped once when it reads stopped (the same-place error that
    -- stops same spawns too), and as guest once a session when its spawns_differ= first counts an enemy. Forgotten
    -- with fight_maxhp.
    local spawns_on,spawns_stopped,spawns_differ=false,false,false
    -- Camp rests in a shared area, as the guest, from the same line's epoch=<zone>/<n>/<resets>: in a shared area only
    -- the host's rest brings its enemies back for both. Said when the host's epoch n moves in the same zone while their
    -- vitals read alive and they were not down in the last REST_CALM seconds (a respawn of theirs has host_down), and
    -- when our own resets move while spawns= reads on and our life= read alive for the REST_CALM seconds before (our
    -- own respawn says nothing). rest: the line's last zone, n and resets, when the host last read down, and since when
    -- ours reads alive. Forgotten with fight_maxhp.
    local REST_CALM,rest=10,{}
    -- That name, or the slot-0 member's, cleaned; '' (a stranger's unknown name) as your friend, in w's words.
    local function her_name(w,name)
        name=require('session.chat').clean(name or (link.friend()) or '')
        return name~='' and name or w.fight.friend
    end
    group=require('session.group').new({link=link,puppet=puppet,settings=settings,tell=tell,name=her_name,
        log=function(m) print('[StellarCoop][GR] '..tostring(m)..'\n') end,night=function() return night.running() end,
        ghost=ghost_of})
    -- The follow waits while the game is paused, in photo mode or in the co-op menu, during a Night Operation run and
    -- during a cutscene in our game. follow=true: on since 2026-11-12 with every other mode, not yet tested in game.
    -- Its tick also gives the native part the host's place and rules words for the session list's row.
    travel=require('session.travel').new({link=link,puppet=puppet,settings=settings,tell=tell,name=her_name,follow=true,
        ghost=ghost_of,
        log=function(m) print('[StellarCoop][TR] '..tostring(m)..'\n') end,
        paused=function() return kit.paused(true) or menu.is_open() or photo_state()~='0' end,
        night=function() return night.running() end,cutscene=function() return group.cutscene_playing() end})
    local function fight_notices()
        if link.mode()=='none' then fight_told=nil end
        local line=link.fight()
        if not line then return end
        local state,mode,her=line:match('^fight=(%a+)'),line:match(' mode=(%a+)'),line:match(' her=(%S+)')
        local why=line:match(' why=(.*)$')
        local now=state=='on' and 'on '..tostring(mode) or state
        if now=='on on' then
            local count=tonumber(line:match(' enemies=(%d+)') or line:match(' pairs=(%d+)')) or 0
            if fight_count==0 and count>0 then
                local hp,balance=line:match(' scale=(%d+)/(%d+)')
                if hp=='100' and balance=='100' then hp=nil end
                tell(function(w)
                    local text=count==1 and w.fight.one or w.fight.on:format(count)
                    return hp and text..' '..w.fight.scale:format(tonumber(hp),tonumber(balance)) or text
                end)
            end
            fight_count=count
            if not fight_maxhp and (tonumber(line:match(' maxhp=(%d+)')) or 0)>0 then
                fight_maxhp=true
                tell(function(w) return w.fight.maxhp:format(her_name(w)) end)
            end
            local guest=line:find(' role=guest ')~=nil
            local m=guest and link.mate()
            local down=m and (m.life>=3 and m.life<=5 or m.hp==0 and m.max_hp>0) or false
            if down and not host_down and count>0 then
                tell(function(w) return w.fight.host_down:format(her_name(w)) end)
            end
            host_down=down
            if down then rest.down_at=chat_clock end
            local life=link.life()
            local alive=life and (life.state==1 or life.state==6) and life.hp>0
            rest.alive_since=alive and (rest.alive_since or chat_clock) or nil
            local zone,n,resets=line:match(' epoch=(%d+)/(%d+)/(%d+)')
            if zone and guest then
                if rest.zone==zone and rest.n~=n and m and (m.life==1 or m.life==6) and not down
                    and (not rest.down_at or chat_clock-rest.down_at>=REST_CALM) then
                    tell(function(w) return w.group.rest:format(her_name(w)) end)
                end
                if rest.resets and resets~=rest.resets and line:find(' spawns=on ') and rest.alive_since
                    and chat_clock-rest.alive_since>=REST_CALM then
                    tell(function(w) return w.group.rest_guest:format(her_name(w)) end)
                end
                rest.zone,rest.n,rest.resets=zone,n,resets
            end
            local spawns=line:match(' spawns=(%a+)')
            if spawns=='on' and not spawns_on then
                spawns_on=true
                local host=line:find(' role=host ')
                tell(function(w) return (host and w.spawns.host or w.spawns.guest):format(her_name(w)) end)
            elseif spawns=='stopped' and not spawns_stopped then
                spawns_stopped=true
                tell(function(w) return w.spawns.stopped end)
            end
            if not spawns_differ and (tonumber(line:match(' spawns_differ=(%d+)')) or 0)>0 then
                spawns_differ=true
                tell(function(w) return w.spawns.differ:format(her_name(w)) end)
            end
        elseif state=='off' or state=='stopped' then
            if fight_was and (fight_was:find('^on ') or fight_was=='waiting') and why~='coop fight off'
                and why~='coop off' then
                tell(function(w) return w.fight[state] end)
            end
            fight_count,fight_maxhp,host_down=0,false,false
            spawns_on,spawns_stopped,spawns_differ,rest=false,false,false,{}
        elseif why=='no friend linked' then -- The friend left: the next one hears about MaxHP again.
            fight_maxhp,host_down=false,false
            spawns_on,spawns_stopped,spawns_differ,rest=false,false,false,{}
        end
        fight_was=now
        if mode~='on' or (state~='on' and state~='waiting') then return end
        local missing
        if state=='waiting' and (why or ''):find('^not on a co%-op save') then missing='you'
        elseif her=='own-save' then missing='her_save'
        elseif her=='off' then missing='her_off'
        elseif her=='stopped' then missing='her_stopped'
        elseif state=='on' and her=='on' then
            local mine=puppet.me()
            local where=P.where(mine and mine.map,puppet.her_map())
            if where=='elsewhere' then missing='map' elseif where=='same' then fight_told=nil end
        end
        if not missing or missing==fight_told or chat_clock<fight_hold then return end
        fight_told,fight_hold=missing,chat_clock+FIGHT_HOLD
        if missing=='you' then -- How to switch, or the manual slot when the co-op copies are off.
            local info=link.saves() or {}
            local manual=settings.auto_coop_save=='off' or info.saves~='main'
            tell(function(w) return manual and w.fight.you_manual or w.fight.you end)
        else
            tell(function(w) return w.fight[missing]:format(her_name(w)) end)
        end
    end
    -- Same place's notices (stage 3a), from the pilot= line, in the menu's language (read only to say one): how many
    -- enemies it moves when they go from none to some, and why it went off once it was on (the host's game turned it
    -- off, or an error stopped it); never for our own coop fight pilot off or the row (why=asked), the host's own
    -- setting (why=setting) or the shared fight not running (why=fight: its own notices say so).
    local pilot_was,pilot_count=nil,0
    local function pilot_notices()
        local line=link.pilot()
        if not line then return end
        local state=line:match('^pilot=(%a+)')
        if state=='on' then
            local count=tonumber(line:match(' piloted=(%d+)')) or 0
            if pilot_count==0 and count>0 then
                tell(function(w) return count==1 and w.pilot.one or w.pilot.on:format(count) end)
            end
            pilot_count=count
        else
            pilot_count=0
            local why=line:match(' why=(%a+)')
            if pilot_was=='on' and (why=='host' or state=='stopped') then
                tell(function(w)
                    local p=w.pilot
                    return p.off:format(state=='stopped' and p.stopped or p.host:format(her_name(w)))
                end)
            end
        end
        pilot_was=state
    end
    -- The shared quests' notices (Phase 12), in the menu's language: from the quests= line, on with her each time both
    -- sides come on, her side off while ours runs, a wait for a co-op save (coop quests on, a friend linked and a main
    -- save loaded, so not at the title or during a load) and stopped for the run, each once as it starts; and each
    -- quest note once (link.quest_notes): her quest ahead (in the host's words or hers, by our role), behind the host,
    -- a step waiting for its zone, a Request to hand in at her board, a kill step, and coop quests force's answers. A
    -- Request not on her board yet and a step no zone can place show in coop quests status only. With several guests,
    -- the host's on notice names the first whose side is on (with=) and his ahead notice the guest whose line it is.
    local QUEST_NOTES={ahead=true,behind=true,zone=true,board=true,kill=true,forced=true,forced_warp=true,
        not_forced=true}
    local quests_was,quests_with,quests_role=nil,false,nil
    local function member_name(id) local m=id and link.member(id); return m and m.name end
    local function quest_notices()
        local line=link.quests()
        if line then
            local state,why,partner=line:match('^quests=(%a+)'),line:match(' why=(%a+)'),line:match(' partner=(%a+)')
            local with=state=='on' and partner=='on'
            if with and not quests_with then
                local name=member_name(line:match(' with=(%d+)'))
                tell(function(w) return w.quests.on:format(her_name(w,name)) end)
            elseif quests_with and state=='on' and partner=='off' then
                tell(function(w) return w.quests.partner_off:format(her_name(w)) end)
            end
            local now=state..(why and ' '..why or '')..((slot_line() or ''):find('^slot=main ') and ' main' or '')
            if now=='waiting save main' and quests_was~=now and line:find(' mode=on ') then
                tell(function(w) return w.quests.save end)
            elseif state=='stopped' and quests_was and quests_was~='stopped' then
                tell(function(w) return w.quests.stopped end)
            end
            quests_was,quests_with,quests_role=now,with,line:match(' role=(%a+)') or quests_role
        end
        for _,n in ipairs(link.quest_notes()) do
            if QUEST_NOTES[n.kind] then
                local key=n.kind=='ahead' and (quests_role=='host' and 'ahead_host' or 'ahead_guest') or n.kind
                local name=member_name(n.from)
                tell(function(w)
                    local q=w.quests
                    if key=='zone' then return q.zone:format(her_name(w),n.alias,n.zone or '?') end
                    if key=='kill' then return q.kill:format(n.alias,n.id) end
                    if key=='board' or key:find('forced') then return q[key]:format(n.alias) end
                    return q[key]:format(her_name(w,name),n.alias) -- ahead_host, ahead_guest, behind
                end)
            end
        end
    end
    -- The shared world's notices, in the menu's language: from the world= line, on with her each time both sides come
    -- on, and stopped for the run, each once as it starts.
    local world_was=nil
    local function world_notices()
        local state=(link.world() or ''):match('^world=(%a+)')
        if not state then return end
        if state=='on' and world_was~='on' then
            tell(function(w) return w.world.on:format(her_name(w)) end)
        elseif state=='stopped' and world_was and world_was~='stopped' then
            tell(function(w) return w.world.stopped end)
        end
        world_was=state
    end
    -- Story together's notices, the same way from the story= line.
    local story_was=nil
    local function story_notices()
        local state=(link.story() or ''):match('^story=(%a+)')
        if not state then return end
        if state=='on' and story_was~='on' then
            tell(function(w) return w.story.on:format(her_name(w)) end)
        elseif state=='stopped' and story_was and story_was~='stopped' then
            tell(function(w) return w.story.stopped end)
        end
        story_was=state
    end
    -- A notice naming mods (a list of core/link.lua's mods()): the file names (no folders) of the first two that fit,
    -- then (+n) for the others (ui/text.lua's T.mods).
    local mods_notice=T.mods
    -- The friend's game loads other .pak mods than ours (the native part compares a hash of them): one notice a session.
    -- With their names (her mod_names=on), it names those she uses and we lack, then those we have in another version,
    -- since parts of her outfit from them look different here; with neither, or without names, the two counts.
    local paks_said=false
    local function paks_notice()
        local paks,mods=link.paks(),link.mods()
        if link.mode()=='none' then paks_said=false
        elseif paks and not paks.same and not paks_said then
            paks_said=true
            local missing,other=mods and mods.missing.n>0,mods and mods.other.n>0
            if missing then
                tell(function(w) return mods_notice(w.fight.mods_missing,her_name(w),mods.missing) end)
            end
            if other then tell(function(w) return mods_notice(w.fight.mods_other,her_name(w),mods.other) end) end
            if not missing and not other then
                tell(function(w) return w.fight.paks:format(her_name(w),paks.hers,paks.ours) end)
            end
        end
    end
    -- The DLCs installed on her PC against ours (link.dlcs()): when they differ, one notice a session names hers we
    -- lack and ours she lacks (ui/text.lua's T.dlcs).
    local dlcs_said=false
    local function dlcs_notice()
        local dlcs=link.dlcs()
        if link.mode()=='none' then dlcs_said=false
        elseif dlcs and not dlcs.same and not dlcs_said then
            dlcs_said=true
            tell(function(w) return T.dlcs(w,her_name(w),dlcs.missing,dlcs.extra) end)
        end
    end
    -- Our CNS packs, once a Lua load, in the log (coop status shows them too).
    local cns_said=false
    local shared_seen=0 -- link.shared_version() as last acted on.
    -- The lobby's screens each 250 ms (design-lobby 2.2 step 5, 2.7, 2.8): the countdown from the match line; a new
    -- start line of a round that lists us closes them and gives the view back to EVE (stage 4 goes on from there; the
    -- fence is session/sbo.lua's); the arrival in the lobby world opens B over the menu camera, once B can open on the
    -- UI root's whole look and while no round of ours plays (the kit builds no new root while B shows, so B on a build
    -- whose look still warms keeps the logo and shades missing); leaving that world closes them and the room's overlay.
    -- R25: a start is new when its number differs from the last one handled, or after an end line.
    local counting,start_n,round_kind,was_here,due=false,nil,nil,false,false
    local framed=false -- The menu camera asked under the arrival's hold, once an arrival in the lobby world.
    -- The arrival's hold, before lobby_pass: SB's black up at the pass after the new controller, lifted once the lobby
    -- holds nothing back (session/sbo.lua's unready) and the kit's root has its whole look. A Lua load under an earlier
    -- load's hold (Ctrl+R) knows nothing of that black: the first pass of this load in the lobby world asks the lift
    -- unless a hold of its own was up before this pass or is up after it (the lift ends tag-5 entries only, which only
    -- this mod puts up). Read after arrival.pass: a black this pass put up is this load's, so no lift for it.
    local stale=true
    local function arrival_pass()
        local was_held=arrival.held()
        arrival.pass(function()
            local missing=sbo.unready()
            if not kit.whole() then missing[#missing+1]='ui' end
            return missing
        end)
        if stale and sbo.in_lobby() then
            stale=false
            if not (was_held or arrival.held()) then
                local ok,why=link.request('loading lift')
                print('[StellarCoop][SB] arrival: loading lift '..(ok and 'asked' or 'not asked: '..tostring(why))
                    ..' at the first lobby pass of this Lua load\n')
            end
        end
    end
    local function lobby_pass()
        local m=link.match()
        if m and m.state=='countdown' then
            counting=true
            lobby.count(m.left or 0,os.clock())
        elseif counting then
            counting=false
            lobby.stop_count()
        end
        local r,me=link.round(),(link.saves() or {}).steamid
        local ours=false
        if r and r.kind=='start' then for _,id in ipairs(r.ids) do ours=ours or id==me end end
        if r and r.kind=='start' and (r.n~=start_n or round_kind=='end') then
            start_n=r.n
            if ours then
                lobby.close()
                counting=false
                lobby.stop_count()
                sbo.to_room()
                log('round start: stage 4 not built')
            end
        end
        round_kind=r and r.kind
        local here=sbo.in_lobby()
        if here~=was_here then
            was_here,due,framed=here,here,false
            if not here then lobby.close(); lobby.room(false) end
        end
        if not (due and not ours and kit.whole()) then return end
        if arrival.held() then -- Under SB's black: the camera now (a refusal is logged once), B at the lift.
            if not framed then framed=true; sbo.to_menu() end
        elseif lobby.open('menu') then
            due=false
            sbo.to_menu()
        end
    end
    -- SB's HUD hidden while B, C or the leave question shows, through SB's own keyed request (the native part's hud
    -- hide); each way they close comes back here. Also under the arrival's hold once in the lobby world, so the hide is
    -- asked before the lift and SB's HUD does not show through the black's fade-out. nil until the first pass of a Lua
    -- load, which sends off. A request that cannot be written is asked again at each pass and logged once (hud_refused:
    -- its line).
    local hud_hidden,hud_refused=nil,nil
    local function hud_pass()
        local hide=lobby.is_open()~=nil or (arrival.held() and sbo.in_lobby())
        if hide==hud_hidden then return end
        local line=hide and 'hud hide on' or 'hud hide off'
        local ok,why=link.request(line)
        if ok then hud_hidden,hud_refused=hide,nil; return end
        local text='hud: '..line..' not asked: '..tostring(why)
        if text~=hud_refused then hud_refused=text; log(text) end
    end
    LoopInGameThreadWithDelay(250,function()
        local began=os.clock()
        took.slow,took.booth=0,0 -- Neither may run in this pass.
        if off and not blocked then blocked=native_off() end
        for _,line in ipairs(link.changes()) do log('link: '..line) end
        guarded('daynight',o.daynight.slow,off) -- After coop off too: it asks sky off once.
        if not off then guarded('nightop',night.tick) end -- Night Operation's run, if any: it logs its own lines.
        -- Roxanne's Night Operation choices: likewise; after coop off, only her two choices and the rows back.
        guarded('roxanne',o.roxanne.tick,off)
        guarded('lily',o.lily.tick,off) -- Lily's signal: likewise.
        if not off then guarded('guard',guard_text.tick) end -- The Xion guard's lines: it logs its own lines.
        chat_clock=chat_clock+0.25
        if not off then guarded('revive',group.tick,chat_clock) end -- The friend's revive: it logs its own lines.
        if not off then guarded('travel',travel.tick,chat_clock) end -- The follow: likewise.
        if not off then guarded('gift',mailbox.tick) end -- coop gift: likewise.
        if not off then guarded('sbo',sbo.tick,os.clock()) end -- The SBO lobby: likewise.
        if not off then guarded('halls',halls.tick) end -- The hall rows' wait and read-back: likewise.
        if not off then guarded('recruiter',recruiter.auto) end -- The recruiter at each Xion load, on any save.
        local chatting=link.chatting() -- nil: the status was not read, which ends no session.
        local heard=chatting or heard_by_member()
        -- In the SBO lobby (a hall or Xion's room) the chat holds a session alone too.
        local alone=not off and chatting~=nil and not heard and guarded('sbo',sbo.in_lobby)==true
        if off or chatting~=nil then guarded('chat',chat.session,not off and (heard or alone)) end
        if not race.armed() then guarded('inbox',inbox) end -- Each frame while one is.
        -- One of ours for the native part, two a second at most; never logged. Alone in the lobby it stays on our
        -- screen only, with one notice until someone is linked.
        local typed=guarded('chat',chat.take,chat_clock)
        if not alone then alone_told=false end
        if typed and alone then
            if not alone_told then alone_told=true; tell(function(w) return w.chat.alone end) end
        elseif typed and not link.say(typed) then chat.fail() end
        if settings.shared_enemies~=fight_wanted and not off then -- The co-op menu's row.
            fight_wanted=settings.shared_enemies
            fight_auto=fight_wanted
            if not fight_wanted and (link.fight() or ''):find('^fight=%a+ mode=on ') then
                local ok,message=ask('fight off')()
                report(ok,'shared_enemies=off: '..tostring(message))
            end
        end
        if settings.same_place~=place_wanted and not off then -- The co-op menu's row.
            place_wanted=settings.same_place
            local mode=(link.fight() or ''):match('^fight=%a+ mode=(%a+)')
            if mode and mode~='probe' then
                local ok,message=ask(place_wanted and 'fight pilot on' or 'fight pilot off')()
                report(ok,'same_place='..(place_wanted and 'on' or 'off')..': '..tostring(message))
            end
        end
        if fight_auto and not off then
            local verdict=(slot_line() or ''):match('^slot=(%a+)')
            if verdict=='coop' or verdict=='main' or verdict=='none' then
                fight_auto=false
                local ok,message=commands.fight('on')
                report(ok,'shared_enemies=on: '..tostring(message))
            end
        end
        if settings.shared_quests~=quests_wanted and not off then -- The co-op menu's row.
            quests_wanted=settings.shared_quests
            quests_auto=quests_wanted
            if not quests_wanted and (link.quests() or ''):find('^quests=%a+ mode=on ') then
                local ok,message=ask('quests off')()
                report(ok,'shared_quests=off: '..tostring(message))
            end
        end
        if quests_auto and not off then
            local verdict=(slot_line() or ''):match('^slot=(%a+)')
            if verdict=='coop' or verdict=='main' or verdict=='none' then
                quests_auto=false
                local ok,message=commands.quests('on')
                report(ok,'shared_quests=on: '..tostring(message))
            end
        end
        if settings.shared_world~=world_wanted and not off then -- The co-op menu's row.
            world_wanted=settings.shared_world
            world_auto=world_wanted
            if not world_wanted then
                local ok,message=ask('world off')()
                report(ok,'shared_world=off: '..tostring(message))
            end
        end
        if world_auto and not off then
            local verdict=(slot_line() or ''):match('^slot=(%a+)')
            if verdict=='coop' or verdict=='main' or verdict=='none' then
                world_auto=false
                local ok,message=commands.world('on')
                report(ok,'shared_world=on: '..tostring(message))
            end
        end
        if settings.shared_story~=scenes_wanted and not off then -- The co-op menu's row.
            scenes_wanted=settings.shared_story
            local word=scenes_wanted and 'on' or 'off'
            local ok,message=commands.scenes(word)
            report(ok,'shared_story='..word..': '..tostring(message))
        end
        if scenes_auto and not off then
            local verdict=(slot_line() or ''):match('^slot=(%a+)')
            if verdict=='coop' or verdict=='main' or verdict=='none' then
                scenes_auto=false
                -- off why=build and off why=coop_off refuse any ask; off scene= is the setting's off.
                local line=link.story() or ''
                local word=settings.shared_story and 'on' or 'off'
                local setting_off=line:find('^story=off scene=')~=nil
                if not line:find('^story=off why=') and settings.shared_story==setting_off then
                    local ok,message=commands.scenes(word)
                    report(ok,'shared_story='..word..': '..tostring(message))
                end
            end
        end
        guarded('fight',fight_notices)
        guarded('pilot',pilot_notices)
        guarded('quests',quest_notices)
        guarded('world',world_notices)
        guarded('scenes',story_notices)
        guarded('paks',paks_notice)
        guarded('dlcs',dlcs_notice)
        if not cns_said and link.cns() then
            cns_said=true
            log(link.cns())
        end
        local mode=link.mode()
        if mode then
            if last_mode=='none' and mode~='none' and not off and not puppet.active() then report(puppet.toggle()) end
            last_mode=mode
        end
        -- A join Steam refused in the menu's words, a player who joined or left in SB's (its English for the line
        -- above EVE), any other as it came.
        for _,text in ipairs(link.notices()) do
            local build=T.join_refused(text)
            if build then tell(build) else say(Join.feed(text,game_words) or text,text) end
        end
        if not off then -- Whether a save is loaded (an accepted invite waits for one), the send rate, the photo mode.
            local world,title=guarded('ghost',puppet.world)
            if title==true and not at_title then guarded('sbo',sbo.title) end -- Each title visit: the rows as shipped.
            at_title=title==true
            local asked,why=guarded('story',o.story.poll,world==true) -- coop-story.txt, in a loaded world only.
            if why then report(asked,why) end
            local photo=world and photo_state() or '0'
            local own=photo~='0' -- Our photo or selfie mode: nothing of ours in the shot unless the settings say so.
            guarded('notice',notice.veil,own)
            guarded('ghost',puppet.photo,own and not settings.photo_ghost,own and not settings.photo_name_tag)
            -- The solid partner, as the co-op menu last set it; never in an SBO session (design-lobby 12.7).
            guarded('ghost',puppet.collide,settings.collide and not sbo.active())
            -- The host's cutscene rides the photo state as 'c', and the guest asks for its pause (session/group.lua).
            local line=link.state(world,settings.send_rate,group.photo(photo),settings.photo_sync,
                settings.photo_freeze_max,title,group.cut(),settings.mod_names)
            if line then log('state: '..line) end
            local shown=world~=nil and world~=false and not own -- Our HUD: in a world, out of our own photos.
            hud_shown=shown
            -- The root on the title screen too: the co-op saves' question, and the feed for its notices.
            local ok,message=peaked('slow','kit',kit.slow,shown or title==true,title==true)
            if message then report(ok,message) end
            -- UE4SS-settings.ini's notices and the crash sentinel's, once: in the feed once the UI is up, or above EVE once
            -- a save is loaded.
            if (ue4ss_notes[1] or aside_note) and (kit.ready() or world==true) then
                for _,word in ipairs(ue4ss_notes) do tell(function(w) return w.ue4ss[word] end) end
                if aside_note then
                    local name=aside_note
                    tell(function(w) return w.ghost.aside:format(name) end)
                end
                ue4ss_notes,aside_note={},nil
            end
            -- The focus watchdog fired: as coop ui reset, nothing said on screen.
            local dropped,who=guarded('kit',kit.lost)
            if dropped then
                ui_reset('focus watchdog: '..who..' lost the focus for 1 s: co-op UI closed, the game has its input '
                    ..'back')
            end
            guarded('menu',menu.slow,shown,not (box.is_open() or code_box.is_open() or approval.is_open()
                or saves_ui.is_open() or open_screen()) and (booth.near(puppet.me()) or guarded('sbo',seat_hint))
                or nil)
            guarded('lobby',lobby.slow)
            guarded('sessions',sessions.slow,shown)
            guarded('create',create.slow,shown)
            guarded('arrival',arrival_pass) -- After sbo.tick and kit.slow above: this pass's arrival and look.
            guarded('lobby',lobby_pass) -- After sbo.tick above: this pass's arrival and round lines.
            guarded('lobby',hud_pass) -- After lobby_pass and ui_reset above: the screens as this pass left them.
            peaked('booth','booth',booth.tick,os.clock(),shown and kit.ready() and not kit.off() and not kit.paused()
                and not menu.is_open() and puppet.me() or nil)
            guarded('chat',box.slow,chat_clock)
            guarded('join',code_box.slow,shown)
            guarded('join',approval.slow,shown) -- After the chat's: it waits while the box is open.
            guarded('hud',hud.slow)
            guarded('saves',saves_ui.slow,world==true,title==true)
            -- Matrix XIII's rows at the title with the co-op save files, so a co-op save that names its camp loads
            -- with them (matrix13/world/travel.lua: once a game run, with the test pak only).
            guarded('mxiii',mxiii.title,title==true and world~=true,(link.saves() or {}).saves=='coop')
            -- Lily's signal's rows likewise (test pak only), so a co-op save that holds the quest keeps it.
            guarded('lily',o.lily.title,title==true and world~=true,(link.saves() or {}).saves=='coop')
            -- The hall lobby maps' rows likewise (lobby pak only), so an SBO lobby can warp to them.
            guarded('halls',halls.title,title==true and world~=true,(link.saves() or {}).saves=='coop')
            -- Her marker carries her name: the ghost's tag is its fallback.
            guarded('ghost',puppet.marker,hud.marking())
            if world or title then photo_pause(settings.photo_pause=='scenery' and 1 or 0,settings.photo_pause) end
            -- The race's session and map checks, from the ghost's world read just above.
            local raced,why=guarded('race',race.slow)
            if why then report(raced,why) end
            -- The bike: the preload as bike says, her part, the ride's checks; an end said on screen.
            local rode,ended=guarded('bike',bike.slow)
            if ended then report(rode,ended); say(ended) end
        else -- After coop off, whether a save is loaded or the title is shown, and no photo mode: the native part's
            -- check of the SBO session records at each title visit still runs then (design-lobby 12.8).
            local world,title=guarded('ghost',puppet.world)
            local line=link.state(world,settings.send_rate,'0',settings.photo_sync,settings.photo_freeze_max,title,
                false,settings.mod_names)
            if line then log('state: '..line) end
        end
        -- Withdrawn when the ghost is off, coop off included.
        local ok,message=guarded('capture',capture.tick,puppet.active())
        if message then report(ok,message) end
        ok,message=guarded('ghost',puppet.remote,link.remote())
        if message then report(ok,message) end
        if not off then report_each(guarded('ghost',ghosts.sync)) end -- None made or fed after coop off.
        -- A new list of mods both players have: the ghost built again with what it may now load (or no longer may).
        if link.shared_version()~=shared_seen then
            shared_seen=link.shared_version()
            message=puppet.rebuild('shared mods changed')
            if message then report(true,message) end
        end
        pass_ended=os.clock()
        pass_took,pass_slow,pass_booth=pass_ended-began,took.slow,took.booth
        passed(timed.pass,pass_took)
        link.settle() -- From here on, status() reads coop-status.txt again (core/link.lua's pass).
    end)
end
-- The keys (N5, D-UI2), only with the Steam link. Every F-key but F10, alone or with Shift, Ctrl or Alt, is bound once
-- (UE4SS cannot take a bind back), so a key changed in the menu works at once and the menu can take any of them; at
-- each press the settings say which action holds it: the menu, Host (host_key, none unless set), the status line,
-- Leave, the follow (follow_key, coop travel host), a race checkpoint (race_key, while a track is recorded; nothing
-- otherwise) or the bike (bike_key: EVE on it or off it). The host's question takes the navigation keys, Enter and Esc first while it is open, then the SBO lobby's
-- screens while one is open (menu_key closes B or C to the room; in the lobby world, menu_key opens B in place of the
-- co-op menu; E and the left tab key are C's tabs), then the Sessions screen while it is open (menu_key closes it; E
-- and the left tab key are its tabs, F its Refresh). Enter goes to the menu's key capture, then selects; the navigation
-- keys go to the menu while it is open only (UI-DESIGN 4.1: up arrow, W or Z; down arrow or S; left arrow, A or Q;
-- right arrow or D; Enter or Space; Esc), and to the co-op saves' question while it is open. The code box takes Enter
-- (join) and Esc (cancel). With all closed, Enter opens the chat's box, then sends, and Esc cancels; while the question
-- or a box is open our F-keys do nothing. The mouse buttons are the join popups' first while one is open (a left click
-- answers with the button under the mouse, a right click declines or closes), then the lobby's screens' and the menu's
-- (a left click selects the row under the mouse, a right click goes back), then the left one the co-op saves'
-- question's (the choice under the mouse); closed, they are the game's. A key callback runs on UE4SS's key thread: it
-- only hands the press to the game thread, where the console's checks (coop off included) apply. A modified F-key is
-- bound before the plain one, so if UE4SS also calls the plain bind for a Shift+F5, the plain press that follows at
-- once is the same press, dropped. The status key gives a one-line summary, in the log in English and on screen in the
-- menu's words; coop status keeps the full status. An XInput pad, which no bind can take, comes through the native part
-- (pad_event above, each frame): View held 1 s does what menu_key does, D-pad Right held 1 s what bike_key does, the
-- D-pad or the left stick, A and B navigate the join popups, the menu and the co-op saves' question, B closes the
-- chat's box and the code box.
if settings then
    local K=require('core.keybind')
    local ACTIONS={'menu','host','status','leave','follow','race','bike'}
    if type(IsKeyBindRegistered)=='function' then
        for _,action in ipairs(ACTIONS) do
            local key=settings[action..'_key']
            local taken
            if key.mod then taken=IsKeyBindRegistered(Key[key.key],{ModifierKey[key.mod]})
            elseif key.key then taken=IsKeyBindRegistered(Key[key.key]) end
            if taken then log('keys: '..key.name..' is also bound by a mod loaded earlier; both run') end
        end
    end
    local modified_at={} -- F-key to when it was last pressed with a modifier (os.clock).
    local function pressed(name)
        local base=name:match('^%a+%+(F%d+)$')
        if base then modified_at[base]=os.clock()
        elseif modified_at[name] and os.clock()-modified_at[name]<0.2 then return end
        -- Typing, or the host's question open: our keys do nothing.
        if box.is_open() or code_box.is_open() or approval.is_open() or menu.capture(name) then return end
        for _,action in ipairs(ACTIONS) do
            if settings[action..'_key'].name==name then
                log('key '..name..': '..action)
                if action=='status' then
                    report(true,link.summary())
                    tell(link.summary)
                elseif action=='follow' then run('travel','host')
                elseif action=='race' then -- A checkpoint while a track is recorded; nothing otherwise.
                    if not off then
                        local ok,why=race.key()
                        if why then report(ok,why) end
                    end
                elseif action=='host' then run('host',settings.who_can_join) -- host_key: at once, never the screen.
                elseif action=='bike' then bike_press('bike_key')
                elseif action~='menu' then run(action)
                elseif off then report(false,OFF)
                elseif lobby.is_open() then
                    if lobby.is_open()~='popup' then lobby_room() end
                elseif open_screen() then open_screen().close()
                elseif sbo.in_lobby() and not menu.is_open() then lobby_key()
                else
                    local ok,why,shown,en=menu.toggle(booth.near(puppet.me()))
                    if why then report(ok,why); say(shown or why,en) end
                end
                return
            end
        end
    end
    local function bind(key,modifier,f)
        if modifier then RegisterKeyBind(Key[key],{ModifierKey[modifier]},f) else RegisterKeyBind(Key[key],f) end
    end
    for n=1,12 do
        for _,modifier in ipairs(n~=10 and {'SHIFT','CONTROL','ALT',false} or {}) do
            local name=K.text('F'..n,modifier or nil)
            bind('F'..n,modifier,function() ExecuteInGameThread(function() pressed(name) end) end)
        end
    end
    -- Alt+Enter (the fullscreen toggle) first: if UE4SS also calls the plain bind for it, that press is dropped.
    local alt_enter_at=-math.huge
    bind('RETURN','ALT',function() ExecuteInGameThread(function() alt_enter_at=os.clock() end) end)
    bind('RETURN',nil,function()
        ExecuteInGameThread(function()
            if os.clock()-alt_enter_at<0.2 then return end
            if approval.is_open() then approval.nav('select')
            elseif lobby.is_open() then lobby.nav('select')
            elseif open_screen() then open_screen().nav('select')
            elseif menu.is_open() then
                if not menu.capture('Enter') then menu.nav('select') end
            elseif saves_ui.is_open() then saves_ui.nav('select')
            elseif code_box.is_open() then code_box.send()
            elseif box.is_open() then box.send()
            -- Paused or on a game screen at the press, or SB's interaction on EVE in a hall (an SB chair's Get up
            -- choice): that Enter was the game's (Resume, a choice), never the chat's.
            elseif not off and hud_shown and not kit.paused() and not (sbo and sbo.busy()) then
                chat_asked=os.clock()
            end
        end)
    end)
    -- The lobby's screens take them all, and on C (L4-menus-b-c 3.6) E is the right tab and Q the left one, or A on an
    -- AZERTY keyboard, where Q is left; the other of A and Q stays left. The Sessions screen takes them the same way,
    -- with F for Refresh (the key Stellar Blade binds to the UI_FaceButton_Top action its Refresh hint shows). The Create
    -- a session screen takes the navigation keys only. E and F do nothing anywhere else.
    local function lobby_key(key,word)
        local screen=lobby.is_open() and lobby or open_screen()
        if lobby.is_open()=='settings' or screen==sessions then
            if key=='E' then word='tab_right' elseif key==(kit.azerty() and 'A' or 'Q') then word='tab_left' end
        end
        if key=='F' then word=screen==sessions and 'refresh' or nil end
        if word and screen then screen.nav(word) end -- Closed on the game thread meanwhile: nothing.
    end
    for _,nav in ipairs({{'UP_ARROW','up'},{'W','up'},{'Z','up'},{'DOWN_ARROW','down'},{'S','down'},
            {'LEFT_ARROW','left'},{'A','left'},{'Q','left'},{'RIGHT_ARROW','right'},{'D','right'},
            {'SPACE','select'},{'E'},{'F'}}) do
        bind(nav[1],nil,function()
            -- The host's question opens on its own: the arrows only, never W, S or Space (walking, jumping, the menu).
            if approval.is_open() then
                if nav[1]:find('_ARROW$') then ExecuteInGameThread(function() approval.nav(nav[2]) end) end
            elseif lobby.is_open() or open_screen() then
                ExecuteInGameThread(function() lobby_key(nav[1],nav[2]) end)
            elseif not nav[2] then return
            elseif menu.is_open() then ExecuteInGameThread(function() menu.nav(nav[2]) end)
            elseif saves_ui.is_open() then ExecuteInGameThread(function() saves_ui.nav(nav[2]) end) end
        end)
    end
    bind('ESCAPE',nil,function()
        if approval.is_open() then ExecuteInGameThread(function() approval.nav('back') end)
        elseif lobby.is_open() then ExecuteInGameThread(function() lobby.nav('back') end)
        elseif open_screen() then ExecuteInGameThread(function()
            local screen=open_screen() -- Still open on the game thread.
            if screen then screen.nav('back') end
        end)
        elseif menu.is_open() then ExecuteInGameThread(function() menu.nav('back') end)
        elseif saves_ui.is_open() then ExecuteInGameThread(function() saves_ui.nav('back') end)
        elseif code_box.is_open() then ExecuteInGameThread(code_box.cancel)
        elseif box.is_open() then ExecuteInGameThread(box.cancel) end
    end)
    -- A left click answers a join popup with the button under the mouse while one is open, else it is the lobby's
    -- while one of its screens is open, else it selects the co-op menu's row under the mouse, or answers the co-op
    -- saves' question with the choice under it; a right click declines or closes a join popup, goes back in the
    -- lobby's screens or the menu (the kit's input leaves Slate the mouse; UE4SS calls the binds whatever has it).
    -- While our UI holds the game's input, either button first has the kit put our focus back (a click on none of our
    -- widgets gives it to the game's viewport). No gamepad button can be bound: the pad comes through the native part.
    bind('LEFT_MOUSE_BUTTON',nil,function()
        if not (kit.holding() or menu.is_open() or saves_ui.is_open()) then return end
        ExecuteInGameThread(function()
            kit.click()
            if approval.is_open() then approval.nav('click')
            elseif lobby.is_open() then lobby.nav('click')
            elseif open_screen() then open_screen().nav('click')
            elseif menu.is_open() then menu.nav('click') elseif saves_ui.is_open() then saves_ui.nav('click') end
        end)
    end)
    bind('RIGHT_MOUSE_BUTTON',nil,function()
        if kit.holding() or menu.is_open() then
            ExecuteInGameThread(function()
                kit.click()
                if approval.is_open() then approval.nav('back')
                elseif lobby.is_open() then lobby.nav('back')
                elseif open_screen() then open_screen().nav('back') else menu.nav('back') end
            end)
        end
    end)
end
log('Loaded version '..VERSION..'. '..USAGE)
