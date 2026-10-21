-- StellarCoop: co-op for Stellar Blade. For now the ghost of an EVE (on with each session; console: coop puppet), drawn
-- by the native part from a table and poses that come back to you: a linked friend's over Steam, yours through an
-- in-process loopback (coop loopback <delay ms> <jitter ms> <loss %> | off), or a recording of yours (coop record
-- [off], coop replay [off]), in the outfit it was captured in (coop basesuit: on the base suit instead; coop look: its
-- cloth, dyes or effects on or off until the mod reloads); the Steam link between two players (coop host, invite, join,
-- leave, status, report, copy, allow, deny, remove; the co-op menu on F5, whose rows host, invite, join, leave and
-- change the settings (menu.lua), status and leave on F6 and F8, unless coop-settings.txt says otherwise; join codes
-- and the host's question on a player who is not her Steam friend: join.lua), the session chat on Enter (chat.lua), its
-- notices in the chat's feed (or, with the UI off, on a line above your EVE), your friend's card, marker and off-screen
-- arrow (partner.lua; the ghost's name tag is their fallback); the co-op saves' question on the title screen
-- (saves.lua, auto_coop_save in coop-settings.txt), with coop saves probe|convert|coop|main for the native part's
-- copies and save name by hand; and
-- coop where, a line of coordinates to compare between the two PCs; coop no [heal|rule|spawnpt|actor], the Night
-- Operation probe of the T6 test only (nightop.lua), on a co-op save only; coop recruiter [off], the cut Night
-- Operation recruiter on a Xion guard near Roxanne (recruiter.lua), on a co-op save only; coop fight
-- on|off|status|probe|test|record|replay, the shared enemies of Phase 11 (experimental: on only with shared_enemies=on
-- in coop-settings.txt or the co-op menu, which also asks it by itself; the native part shares only on a co-op save,
-- and the probe, test, record and replay run on one only), with notices for what keeps it from sharing; coop fight
-- pilot status|probe|on|off|test freeze|cmc|drive|replay|target, same-place enemies (stages 3a and 3b, same_place and
-- aggro in coop-settings.txt or the co-op menu, the host's for both games: each shared enemy stands in the same place
-- on both screens, moved by the game that runs its AI), with notices for how many it moves and why it went off; same
-- spawns (stage 4, same_spawns in coop-settings.txt or the co-op menu, the host's for both games: where both players
-- stand within 100 m in one zone, the guest's game holds the host's common enemies), with notices for on, stopped and
-- enemies that differ, and coop fight spawn probe, its reads alone on a co-op save; the synced photo mode (photo_sync
-- in coop-settings.txt: your friend's photo mode pauses your game, yours pauses theirs; during your own, the notices,
-- and as set the ghost and its name tag, stay out of the shot), with coop freeze <seconds>|off to test the pause alone;
-- coop ui reset (the menu and the chat's box closed, the game's input back) and coop ui off (the co-op UI gone until
-- the mod reloads); coop ui test [game], the UI-layer spike (ui.lua: a small widget on screen for 5 s and its checks in
-- the log; a test tool, left out of the usage line). coop off stops everything until the game restarts.
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
local link=loaded and require('link').new(folder) or nil
local settings=nil
if link then
    local notes
    settings,notes=link.settings()
    for _,note in ipairs(notes) do log(note) end
    log(string.format('keys: menu=%s host=%s status=%s leave=%s, name tag %s, %d poses a second',settings.menu_key.name,
        settings.host_key.name,settings.status_key.name,settings.leave_key.name,settings.name_tag and 'on' or 'off',
        settings.send_rate))
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
        ..(settings.same_spawns and 'on' or 'off')..' (experimental), extra enemies '..settings.enemy_extra)
    log(string.format('photo sync: %s, longest pause %s, ghost in your photos %s, its name tag %s',settings.photo_sync,
        settings.photo_freeze_max>0 and settings.photo_freeze_max..' s' or 'no limit',
        settings.photo_ghost and 'on' or 'off',settings.photo_name_tag and 'on' or 'off'))
end
-- A new token per Lua load: the native part then drops what an older load published (withdrawn here as well).
if link then
    link.components(nil)
    link.display(nil)
    link.session(string.format('%d-%d',os.time(),math.floor(os.clock()*1000000)))
end
local capture=require('capture').new(link and link.components or nil,look)
local notice=require('notice').new()
-- The UI kit, the co-op menu, the chat's box and feed, the partner HUD, the co-op saves' question, the code box and the
-- host's question: with the Steam link.
local kit,menu,box,hud,saves_ui,code_box,approval
-- A notice: into the chat's feed while the UI's root is up, else on the line above EVE (notice.lua), the fallback when
-- the UI is off or failed.
local function say(text) if not (box and box.say(text)) then notice.say(text) end end
-- The words for the screen (ui_text.lua): the game's language unless ui_language=english; English while unread. The
-- log keeps English.
local T=require('ui_text')
local function words() return T.pick(kit and kit.language(),settings and settings.ui_language) end
local puppet=require('puppet').new(link,capture,say,settings and settings.name_tag,look,words)
-- coop off lasts until the game restarts, even across a Lua reload (Ctrl+R): the native part remembers it.
-- Read from the pose path's line only, as a peer's Steam name could say the same.
local function native_off()
    return link~=nil and ('\n'..(link.status() or '')):find('\nengine=[^\r\n]* reason=coop_off')~=nil
end
local off=native_off()
-- The native part has it too: from then on its tick runs again, as it only releases a held photo pause tag.
local blocked=off
local USAGE='Use: coop puppet | host | invite | join [lobby id|code] | copy | allow|deny|remove <SteamID> | leave | status | report | where | loopback <delay ms> <jitter ms> <loss %>|off | record [off] | replay [off] | basesuit | look [cloth|dyes|effects on|off] | no [heal|rule|spawnpt|actor] | recruiter [off] | fight on|off|status|probe|test|record|replay|pilot|spawn | freeze <seconds>|off | ui reset|off | saves probe|convert|coop|main | off'
local function whole(text,max) -- A whole number from 0 to max, or nil.
    local n=type(text)=='string' and text:match('^%d+$') and tonumber(text)
    return n and n<=max and n or nil
end
local function ask(line)
    return function()
        if not link then return false,'the Steam link needs the native part' end
        return link.request(line)
    end
end
-- The host's answers about a player (allow, deny: one who is not her Steam friend and waits; remove: anyone in the
-- lobby), by SteamID only.
local function answer(verb)
    return function(id)
        if type(id)~='string' or not id:match('^%d+$') or #id>20 then return false,'Use: coop '..verb..' <SteamID>' end
        return ask(verb..' '..id)()
    end
end
-- Host by who_can_join: code (an invisible lobby with a join code), private (invited only), friends.
local HOSTS={code='host code',private='host private'}
-- coop no, coop recruiter and coop fight run only on a co-op save (D2, N9): the native part's slot=coop, from the start
-- of its own line (a Steam name never starts one), for a co-op copy (saves=coop) or the manual co-op slot that
-- StellarCoopSlot.txt names. The ghost, the Steam link and every other command are never locked to it.
local function slot_line() return ('\n'..(link and link.status() or '')):match('\n(slot=[^\r\n]*)') end
local function coop_slot(what)
    local line=slot_line()
    if line and line:find('^slot=coop ') then return true end
    return false,what..' runs only on a co-op save (INSTALL.md: Co-op saves); now '..(line or 'no slot status')
end
-- Its one entry, commands.no, runs only on a co-op save (coop_slot).
local nightop=require('nightop').new(function(m) print('[StellarCoop][NO] '..tostring(m)..'\n') end,
    function(line) return ask(line)() end,function() return link and link.status() end)
-- commands.recruiter runs only on a co-op save; coop off despawns on any slot (cleanup).
local recruiter=require('recruiter').new(function(m) print('[StellarCoop][RC] '..tostring(m)..'\n') end)
-- coop ui test: the UI-layer spike, on demand only; it needs neither the native part nor a save slot.
local function ui_log(m) print('[StellarCoop][UI] '..tostring(m)..'\n') end
local ui=require('ui').new(ui_log)
-- The session chat's model (chat.lua, memory only, never logged): her lines come from coop-chat.txt, taken every
-- 250 ms so the file never stays on disk, session or not, and ours leave through coop-say.txt in the same loop. Its
-- clock counts that loop's ticks: os.clock is CPU time under some C runtimes, os.time whole seconds. chat.lua's view
-- shows and sends the lines (box, below).
local chat,chat_clock=require('chat').new(nil,settings and settings.chat),0
-- coop fight (Phase 11, experimental): its line for the native part, or nil when the arguments are off. A change is
-- whole units, signed or not, never 0, at most 10000000 (the native part's cap).
local FIGHT_USE='Use: coop fight on | off | status | probe | test hp|sh|st <change> | test kill | record | replay | '
    ..'pilot status|probe|on|off | pilot test freeze|cmc|drive|replay|target|exec | spawn probe'
local FIGHT_ALONE={on=true,off=true,status=true,probe=true,record=true,replay=true}
local function fight_line(sub,a,b,extra)
    if extra~=nil then return nil end
    if FIGHT_ALONE[sub] and a==nil then return 'fight '..sub end
    if sub~='test' then return nil end
    if a=='kill' and b==nil then return 'fight test kill' end
    local n=(a=='hp' or a=='sh' or a=='st') and type(b)=='string' and b:match('^[+-]?%d+$') and tonumber(b)
    if n and n~=0 and n>=-10000000 and n<=10000000 then return string.format('fight test %s %d',a,n) end
end
-- coop fight pilot (same-place enemies, stages 3a to 3c): status (the pilot= line, after asking the native part,
-- which then logs its stats lines), probe, on (needs same_place=on), off (a kill switch: no other check), or test and
-- how far the drawn side goes, test target (the game's force target once, on an enemy this side owns) or test exec
-- (T11d-solo's takedown probe: the first frozen copy this side draws loses its balance).
local PILOT_ALONE={status=true,probe=true,on=true,off=true}
local PILOT_TESTS={freeze=true,cmc=true,drive=true,replay=true,target=true,exec=true}
local function pilot(a,b,extra)
    if extra~=nil or not (PILOT_ALONE[a] and b==nil or a=='test' and PILOT_TESTS[b]) then
        return false,FIGHT_USE
    end
    if a~='off' and a~='status' and not native_tick then return false,'the native tick is unavailable' end
    if a=='on' and not settings.same_place then
        return false,'same place is off in coop-settings.txt (same_place=off)'
    end
    local ok,why=ask(b and 'fight pilot test '..b or 'fight pilot '..a)()
    if not ok or a~='status' then return ok,why end
    return true,link.pilot() or 'no same-place status yet'
end
-- The synced photo mode: our player in SB's photo mode ('1'), its selfie mode ('s') or neither ('0'), from SB's
-- reflected getters (the library's default object, found once). The first failure turns it off for this Lua load
-- ('0' from then on) with one log line.
local U=require('unreal')
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
-- same_place=off too, on the side that hosts: a same place an earlier load asked for ends here, running or waiting
-- (coop fight pilot off, until the next coop fight on). Only there: a guest's own value decides nothing at a start and
-- is off by default, so a reload never stops what the host's game shows her.
if settings and not settings.same_place and not off then
    local raw='\n'..(link.status() or '')
    if raw:find('\nfight=%a+ mode=record ') or (raw:find('\nfight=%a+ mode=on ') and raw:find('\nlink=host ')) then
        local ok,why=ask('fight pilot off')()
        log((ok and 'OK: ' or 'STOP: ')..'same_place=off: '..tostring(why))
    end
end
local commands={
    puppet=puppet.toggle, invite=ask('invite'),
    host=function() return ask(HOSTS[settings and settings.who_can_join] or 'host')() end,
    leave=ask('leave'), report=ask('report'), copy=ask('copy'),
    allow=answer('allow'), deny=answer('deny'), remove=answer('remove'),
    -- A lobby id, or a join code as the native part takes it.
    join=function(lobby)
        if lobby and link then
            lobby=link.valid_lobby(lobby) and lobby or link.join_code(lobby)
            if not lobby then return false,'a lobby id is digits only, a join code 7 letters and digits' end
        end
        return ask(lobby and 'join '..lobby or 'join')()
    end,
    loopback=function(delay,jitter,loss)
        if not native_tick then return false,'the native tick is unavailable' end
        if delay=='off' then return ask('loopback off')() end
        delay,jitter,loss=whole(delay,1000),whole(jitter,500),whole(loss,100)
        if not (delay and jitter and loss) then
            return false,'Use: coop loopback <delay 0-1000 ms> <jitter 0-500 ms> <segment loss 0-100 %> | off'
        end
        if not puppet.active() then return false,'turn the ghost on first: coop puppet' end
        return ask(string.format('loopback %d %d %d',delay,jitter,loss))()
    end,
    basesuit=puppet.basesuit, where=puppet.where,
    look=function(feature,state)
        if feature==nil then
            return true,looks()..' (coop look <cloth|dyes|effects> <on|off> changes one until the mod reloads: game '
                ..'start or Ctrl+R)'
        end
        local named=({cloth='Cloth',dyes='Dyes',effects='Effects'})[feature]
        if not named or (state~='on' and state~='off') then
            return false,'Use: coop look [cloth|dyes|effects on|off]'
        end
        look[feature]=state=='on'
        puppet.rebuild('look')
        return true,named..' '..state..' until the mod reloads (game start or Ctrl+R; coop-settings.txt unchanged); '
            ..'the ghost is built again.'
    end,
    no=function(sub,extra)
        local ok,why=coop_slot('coop no')
        if not ok then return false,why end
        return nightop.run(sub,extra)
    end,
    recruiter=function(sub,extra)
        local ok,why=coop_slot('coop recruiter')
        if not ok then return false,why end
        return recruiter.run(sub,extra)
    end,
    -- on needs shared_enemies=on, on any save: the native part waits for a co-op save. probe, test, record and replay
    -- are the solo T11a tools, on a co-op save only (the native part checks again, and says in the log why it
    -- refuses). All but test carry fight_chars, none for auto (the native part's rule: every common enemy). Before
    -- them, in this order: guest_kills=confirmed and kill_credit=fought as one word each with on and replay (the modes
    -- that kill on the other side's word), and the host's scaling as "scale" and two whole percents with on and record
    -- (the modes that can host), and same_place=on as "place" and aggro=host as "aggro-host" after them, then with on
    -- only same_spawns=on as "spawns", and with it an enemy_extra above 0 as "extra" and its number. status answers
    -- with the fight= line; pilot is same-place enemies' own (pilot above). spawn probe is the probe with "spawns"
    -- before the ids: same spawns' reads alone (stage 4), whatever same_spawns says; its state is the fight= line's
    -- spawns=.
    fight=function(sub,a,b,extra)
        if sub=='pilot' then return pilot(a,b,extra) end
        local spawn_probe=sub=='spawn'
        if spawn_probe then
            if a~='probe' or b~=nil or extra~=nil then return false,FIGHT_USE end
            sub,a=a,nil
        end
        local line=fight_line(sub,a,b,extra)
        if not line then return false,FIGHT_USE end
        if sub=='off' then fight_auto=false end
        if sub~='off' and sub~='status' then
            if not native_tick then return false,'the native tick is unavailable' end
            if sub=='on' and not settings.shared_enemies then
                return false,'shared enemies are off in coop-settings.txt (shared_enemies=off)'
            end
            if sub~='on' then
                local ok,why=coop_slot('coop fight')
                if not ok then return false,why end
            end
            if (sub=='on' or sub=='replay') and settings.guest_kills=='confirmed' then line=line..' confirmed' end
            if (sub=='on' or sub=='replay') and settings.kill_credit=='fought' then line=line..' fought' end
            if sub=='on' or sub=='record' then
                line=line..string.format(' scale %d %d',math.floor(settings.enemy_hp_scale*100+0.5),
                    math.floor(settings.enemy_balance_scale*100+0.5))..(settings.same_place and ' place' or '')
                    ..(settings.aggro=='host' and ' aggro-host' or '')
                    ..(sub=='on' and settings.same_spawns and ' spawns' or '')
                    ..(sub=='on' and settings.same_spawns and settings.enemy_extra>0
                        and ' extra '..settings.enemy_extra or '')
            end
            if spawn_probe then line=line..' spawns' end
            local chars=settings.fight_chars
            if sub~='test' and #chars>0 then line=line..' '..table.concat(chars,' ') end
        end
        local ok,why=ask(line)()
        if not ok or sub~='status' then return ok,why end
        return true,link.fight() or 'no shared fight status yet'
    end,
    -- The photo pause alone (the solo tests): our pause tag held for 1 to 3600 s, or until off; the native part refuses
    -- it off the pinned build and says why in the log.
    freeze=function(arg,extra)
        local seconds=arg~='off' and whole(arg,3600)
        if extra~=nil or not (arg=='off' or seconds and seconds>0) then
            return false,'Use: coop freeze <1-3600 seconds> | off'
        end
        if not native_tick then return false,'the native tick is unavailable' end
        return ask(seconds and 'freeze '..seconds or 'freeze off')()
    end,
    -- The co-op saves by hand (the question at the title asks for them): probe logs what the native part reads and the
    -- next copy pass's plan; convert makes the copies; coop makes them and switches the save name; main switches back.
    -- The native part refuses all but probe off the title screen, and says why in coop-link.log.
    saves=function(sub,extra)
        if extra~=nil or not ({probe=true,convert=true,coop=true,main=true})[sub or ''] then
            return false,'Use: coop saves probe | convert | coop | main'
        end
        return ask('saves '..sub)()
    end,
    -- reset, the escape hatch (UI-DESIGN 7.5): the menu and the chat's box closed, the game's input back now; off
    -- (7.6): the co-op UI gone until the mod reloads, the notice line above EVE and the ghost's name tag back (the
    -- co-op saves' question with it; auto_coop_save=always still asks at the title).
    ui=function(sub,arg,extra)
        if (sub=='reset' or sub=='off') and arg==nil then
            if not kit then return false,'the co-op UI needs the Steam link' end
            if sub=='off' then -- The host's question waits for its 30 s: no answer from a UI that is gone.
                menu.stop(); box.stop(); code_box.stop(); kit.stop()
                return true,'co-op UI off until the mod reloads: notices on the line above EVE'
            end
            menu.close(); box.close(); code_box.close(); approval.close(); saves_ui.close(); kit.reset()
            return true,'co-op UI reset: menu and chat closed, the game has its input back'
        end
        if sub~='test' or (arg~=nil and arg~='game') or extra~=nil then
            return false,'Use: coop ui test [game] | reset | off'
        end
        return ui.test(arg=='game')
    end,
    off=function()
        off=true
        if puppet.active() then puppet.toggle() end
        notice.stop()
        ui.stop()
        if menu then menu.stop() end
        if box then box.stop() end
        if saves_ui then saves_ui.stop() end
        if code_box then code_box.stop(); approval.stop() end
        if kit then kit.stop() end -- The game's input back, the menu's root gone.
        chat.clear()
        -- A failing despawn is logged and never stops the rest of coop off.
        local stopped,e=pcall(recruiter.stop)
        if not stopped then log('recruiter: '..tostring(e)) end
        if not link then return true,'everything is off until the game restarts' end
        return ask('off')()
    end,
    status=function()
        local text=link and link.status()
        if not text then return false,'no Steam link status yet; '..puppet.status() end
        return true,text:gsub('[\r\n]+',' | ')..puppet.status()
    end,
}
-- coop record and coop replay: on (with the ghost on, which publishes her capture) or off.
for _,name in ipairs({'record','replay'}) do
    commands[name]=function(arg)
        if not native_tick then return false,'the native tick is unavailable' end
        if arg=='off' then return ask(name..' off')() end
        if arg~=nil then return false,'Use: coop '..name..' [off]' end
        if not puppet.active() then return false,'turn the ghost on first: coop puppet' end
        return ask(name)()
    end
end
local function report(ok,message) log((ok and 'OK: ' or 'STOP: ')..tostring(message)) end
local OFF='coop off is active until the game restarts'
-- A console command, a key or a menu row, on the game thread: logged, and its result returned.
local function run(name,a,b,c,d)
    local command=commands[name or '']
    if not command then log(USAGE); return false,USAGE end
    if off and command~=commands.status and command~=commands.report then
        report(false,OFF)
        return false,OFF
    end
    local ran,ok,message=pcall(command,a,b,c,d)
    if not ran then ok,message=false,ok end
    report(ok,message)
    return ok,message
end
-- The chat's box and feed (chat.lua's view), the partner HUD (partner.lua's), the code box (join.lua), the co-op menu
-- (menu.lua), the host's question (join.lua) and the co-op saves' question (saves.lua) on the Uplink kit (ui.lua),
-- with the Steam link only: its root is built in a world or on the title screen, after one lookup a 250 ms tick. The
-- feed and the HUD first: the menu draws over them, the questions over all.
if settings then
    local Ui=require('ui')
    kit=Ui.kit({log=ui_log,store=link.store('coop-ui.txt'),scale=settings.ui_scale,sounds=settings.ui_sounds})
    box=require('chat').view({kit=kit,model=chat,settings=settings,theme=Ui.THEME,
        covered=function() return menu.is_open() end})
    hud=require('partner').hud({kit=kit,link=link,puppet=puppet,settings=settings,theme=Ui.THEME})
    local Join=require('join')
    code_box=Join.box({kit=kit,link=link,settings=settings,theme=Ui.THEME,run=run})
    menu=require('menu').new({kit=kit,link=link,settings=settings,look=look,puppet=puppet,run=run,log=log,
        version=VERSION,chat=box,code=code_box})
    approval=Join.ask({kit=kit,link=link,settings=settings,run=run,say=say,menu=menu,chat=box})
    saves_ui=require('saves').new({kit=kit,link=link,settings=settings,theme=Ui.THEME,say=say,log=log})
end
-- Enter with nothing open asks for the chat's box (chat_asked, os.clock), which opens 0.1 s later unless a coop command
-- came from the console around then (typed_at): UE4SS calls our Enter bind whatever has the keyboard, so that Enter was
-- the console's. Its own state is not reflected, so other console commands may still open the box.
local chat_asked,typed_at=nil,-math.huge
local hud_shown=false -- Our HUD may show (a world, out of our photos): the chat's box opens then only, not at the title.
-- The Lua frame time of the ghost's place and of the UI's ticks (UI-DESIGN 7.3, measured in T-UI1), summed and logged
-- once a minute with the UI up. os.clock steps by whole ms under the game's C runtime: over a minute's frames the sum
-- averages out.
local timed={ghost=0,ui=0,frames=0,since=nil}
RegisterConsoleCommandHandler('coop',function(_,parameters)
    typed_at=os.clock()
    local name,a,b,c,d=parameters[1],parameters[2],parameters[3],parameters[4],parameters[5]
    ExecuteInGameThread(function() run(name,a,b,c,d) end)
    return true
end)
assert(type(LoopInGameThreadWithDelay)=='function','This UE4SS lacks game-thread timers.')
LoopInGameThreadWithDelay(1,function()
    if off then if blocked and native_tick then native_tick() end return end
    local ok,message=puppet.tick()
    if message then report(ok,message) end
    if native_tick then native_tick() end
    local placed=os.clock()
    ok,message=puppet.place() -- The root takes the mailbox this native tick just wrote.
    if message then report(ok,message) end
    placed=os.clock()-placed
    ok,message=notice.tick()
    if message then report(ok,message) end
    nightop.tick() -- A due probe follow-up: it logs its own lines.
    recruiter.tick() -- Likewise for coop recruiter.
    ui.tick() -- Likewise for coop ui test.
    -- The open and close tweens, the game's input back after a close, the chat box focused again, the partner's marker
    -- (each frame, from the ghost's place just set).
    if kit then
        local now=os.clock()
        ok,message=kit.tick(now)
        if message then report(ok,message) end
        menu.tick(now)
        box.tick(now)
        code_box.tick(now)
        approval.tick(now)
        saves_ui.tick(now)
        hud.tick(now)
        if chat_asked and now>=chat_asked+0.1 then
            local asked=chat_asked
            chat_asked=nil
            if typed_at<asked-0.3 and not menu.is_open() and not approval.is_open() then
                local _,why=box.open() -- Said on screen only: Enter is the game's too.
                if why then say(why) end
            end
        end
        local t=os.clock()
        timed.since=timed.since or t
        timed.ghost,timed.ui,timed.frames=timed.ghost+placed,timed.ui+t-now,timed.frames+1
        if t-timed.since>=60 then
            if kit.ready() then
                log(string.format('Lua frame time, last 60 s: ghost %.3f ms, UI %.3f ms a frame (%d frames)',
                    timed.ghost*1000/timed.frames,timed.ui*1000/timed.frames,timed.frames))
            end
            timed={ghost=0,ui=0,frames=0,since=t}
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
    local P=require('partner')
    local FIGHT_HOLD=5
    local fight_was,fight_count,fight_told,fight_hold=nil,0,nil,0
    local fight_maxhp,host_down=false,false
    -- Same spawns' notices (stage 4), from the same line while coop fight on runs: on once a session when its spawns=
    -- first reads on (the host's words or the guest's), stopped once when it reads stopped (the same-place error that
    -- stops same spawns too), and as guest once a session when its spawns_differ= first counts an enemy. Forgotten
    -- with fight_maxhp.
    local spawns_on,spawns_stopped,spawns_differ=false,false,false
    local function fight_words() return words().fight end
    local function her_name(words) -- '' (a stranger's unknown name) as your friend.
        local name=require('chat').clean((link.friend()) or '')
        return name~='' and name or words.friend
    end
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
                local words=fight_words()
                local text,hp,balance=count==1 and words.one or words.on:format(count),line:match(' scale=(%d+)/(%d+)')
                if hp and (hp~='100' or balance~='100') then
                    text=text..' '..words.scale:format(tonumber(hp),tonumber(balance))
                end
                say(text)
            end
            fight_count=count
            if not fight_maxhp and (tonumber(line:match(' maxhp=(%d+)')) or 0)>0 then
                fight_maxhp=true
                say(fight_words().maxhp:format(her_name(fight_words())))
            end
            local m=line:find(' role=guest ') and link.mate()
            local down=m and (m.life>=3 and m.life<=5 or m.hp==0 and m.max_hp>0) or false
            if down and not host_down and count>0 then say(fight_words().host_down:format(her_name(fight_words()))) end
            host_down=down
            local spawns=line:match(' spawns=(%a+)')
            if spawns=='on' and not spawns_on then
                spawns_on=true
                local w=words().spawns
                say((line:find(' role=host ') and w.host or w.guest):format(her_name(fight_words())))
            elseif spawns=='stopped' and not spawns_stopped then
                spawns_stopped=true
                say(words().spawns.stopped)
            end
            if not spawns_differ and (tonumber(line:match(' spawns_differ=(%d+)')) or 0)>0 then
                spawns_differ=true
                say(words().spawns.differ:format(her_name(fight_words())))
            end
        elseif state=='off' or state=='stopped' then
            if fight_was and (fight_was:find('^on ') or fight_was=='waiting') and why~='coop fight off'
                and why~='coop off' then
                say(fight_words()[state])
            end
            fight_count,fight_maxhp,host_down=0,false,false
            spawns_on,spawns_stopped,spawns_differ=false,false,false
        elseif why=='no friend linked' then -- The friend left: the next one hears about MaxHP again.
            fight_maxhp,host_down=false,false
            spawns_on,spawns_stopped,spawns_differ=false,false,false
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
        local words=fight_words()
        if missing=='you' then -- How to switch, or the manual slot when the co-op copies are off.
            local info=link.saves() or {}
            say((settings.auto_coop_save=='off' or info.saves~='main') and words.you_manual or words.you)
        else
            say(words[missing]:format(her_name(words)))
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
                local w=words().pilot
                say(count==1 and w.one or w.on:format(count))
            end
            pilot_count=count
        else
            pilot_count=0
            local why=line:match(' why=(%a+)')
            if pilot_was=='on' and (why=='host' or state=='stopped') then
                local w=words().pilot
                say(w.off:format(state=='stopped' and w.stopped or w.host:format(her_name(fight_words()))))
            end
        end
        pilot_was=state
    end
    -- The friend's game loads other .pak mods than ours (the native part compares a hash of them): one notice a session.
    local paks_said=false
    local function paks_notice()
        local paks=link.paks()
        if link.mode()=='none' then paks_said=false
        elseif paks and not paks.same and not paks_said then
            paks_said=true
            say(fight_words().paks:format(her_name(fight_words()),paks.hers,paks.ours))
        end
    end
    LoopInGameThreadWithDelay(250,function()
        if off and not blocked then blocked=native_off() end
        for _,line in ipairs(link.changes()) do log('link: '..line) end
        chat_clock=chat_clock+0.25
        local chatting=link.chatting() -- nil: the status was not read, which ends no session.
        if off or chatting~=nil then chat.session(not off and chatting) end
        for _,line in ipairs(link.take_chat()) do
            if line.fail then chat.fail()
            else
                local got=chat.receive((link.friend()) or '',line.text,chat_clock)
                -- While the feed cannot show it (the UI off or failed, or still warming): on the line above EVE.
                if got and not kit.ready() then
                    local w=words().chat
                    notice.say(w.said:format(got.name~='' and got.name or w.partner)..got.text)
                end
            end
        end
        local typed=chat.take(chat_clock) -- One of ours for the native part, two a second at most; never logged.
        if typed and not link.say(typed) then chat.fail() end
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
        fight_notices()
        pilot_notices()
        paks_notice()
        local mode=link.mode()
        if mode then
            if last_mode=='none' and mode~='none' and not off and not puppet.active() then report(puppet.toggle()) end
            last_mode=mode
        end
        for _,text in ipairs(link.notices()) do say(text) end
        if not off then -- Whether a save is loaded (an accepted invite waits for one), the send rate, the photo mode.
            local world,title=puppet.world()
            local photo=world and photo_state() or '0'
            local own=photo~='0' -- Our photo or selfie mode: nothing of ours in the shot unless the settings say so.
            notice.veil(own)
            puppet.photo(own and not settings.photo_ghost,own and not settings.photo_name_tag)
            local line=link.state(world,settings.send_rate,photo,settings.photo_sync,settings.photo_freeze_max,title)
            if line then log('state: '..line) end
            local shown=world~=nil and world~=false and not own -- Our HUD: in a world, out of our own photos.
            hud_shown=shown
            -- The root on the title screen too: the co-op saves' question, and the feed for its notices.
            local ok,message=kit.slow(shown or title==true,title==true)
            if message then report(ok,message) end
            menu.slow(shown)
            box.slow(chat_clock)
            code_box.slow(shown)
            approval.slow(shown) -- After the chat's: it waits while the box is open.
            hud.slow()
            saves_ui.slow(world==true,title==true)
            puppet.marker(hud.marking()) -- Her marker carries her name: the ghost's tag is its fallback.
        end
        local ok,message=capture.tick(puppet.active()) -- Withdrawn when the ghost is off, coop off included.
        if message then report(ok,message) end
        ok,message=puppet.remote(link.remote())
        if message then report(ok,message) end
    end)
end
-- The keys (N5, D-UI2), only with the Steam link. Every F-key but F10, alone or with Shift, Ctrl or Alt, is bound once
-- (UE4SS cannot take a bind back), so a key changed in the menu works at once and the menu can take any of them; at
-- each press the settings say which action holds it: the menu, Host (host_key, none unless set), the status line or
-- Leave. The host's question takes the navigation keys, Enter and Esc first while it is open. Enter goes to the menu's
-- key capture, then selects; the navigation keys go to the menu while it is open only (UI-DESIGN 4.1: up arrow, W or Z;
-- down arrow or S; left arrow, A or Q; right arrow or D; Enter or Space; Esc), and to the co-op saves' question while
-- it is open. The code box takes Enter (join) and Esc (cancel). With all closed, Enter opens the chat's box, then
-- sends, and Esc cancels; while the question or a box is open our F-keys do nothing. A
-- key callback runs on UE4SS's key thread: it only hands the press to the game thread, where the console's checks (coop
-- off included) apply. A modified F-key is bound before the plain one, so if UE4SS also calls the plain bind for a
-- Shift+F5, the plain press that follows at once is the same press, dropped. The status key gives a one-line summary,
-- in the log in English and on screen in the menu's words; coop status keeps the full status.
if settings then
    local K=require('keybind')
    local ACTIONS={'menu','host','status','leave'}
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
                    say(link.summary(words()))
                elseif action~='menu' then run(action)
                elseif off then report(false,OFF)
                else
                    local ok,why,shown=menu.toggle()
                    if why then report(ok,why); say(shown or why) end
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
            elseif menu.is_open() then
                if not menu.capture('Enter') then menu.nav('select') end
            elseif saves_ui.is_open() then saves_ui.nav('select')
            elseif code_box.is_open() then code_box.send()
            elseif box.is_open() then box.send()
            -- Paused or on a game screen at the press: that Enter was the game's (Resume, a choice), never the chat's.
            elseif not off and hud_shown and not kit.paused() then chat_asked=os.clock() end
        end)
    end)
    for _,nav in ipairs({{'UP_ARROW','up'},{'W','up'},{'Z','up'},{'DOWN_ARROW','down'},{'S','down'},
            {'LEFT_ARROW','left'},{'A','left'},{'Q','left'},{'RIGHT_ARROW','right'},{'D','right'},
            {'SPACE','select'}}) do
        bind(nav[1],nil,function()
            -- The host's question opens on its own: the arrows only, never W, S or Space (walking, jumping, the menu).
            if approval.is_open() then
                if nav[1]:find('_ARROW$') then ExecuteInGameThread(function() approval.nav(nav[2]) end) end
            elseif menu.is_open() then ExecuteInGameThread(function() menu.nav(nav[2]) end)
            elseif saves_ui.is_open() then ExecuteInGameThread(function() saves_ui.nav(nav[2]) end) end
        end)
    end
    bind('ESCAPE',nil,function()
        if approval.is_open() then ExecuteInGameThread(function() approval.nav('back') end)
        elseif menu.is_open() then ExecuteInGameThread(function() menu.nav('back') end)
        elseif saves_ui.is_open() then ExecuteInGameThread(function() saves_ui.nav('back') end)
        elseif code_box.is_open() then ExecuteInGameThread(code_box.cancel)
        elseif box.is_open() then ExecuteInGameThread(box.cancel) end
    end)
    -- A left click answers the co-op saves' question with the choice under the mouse (the kit's input leaves Slate the
    -- mouse, and UE4SS calls the bind whatever has it); no gamepad button can be bound.
    bind('LEFT_MOUSE_BUTTON',nil,function()
        if saves_ui.is_open() then ExecuteInGameThread(function() saves_ui.nav('click') end) end
    end)
end
log('Loaded version '..VERSION..'. '..USAGE)
