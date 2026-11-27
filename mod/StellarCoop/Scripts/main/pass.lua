-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The 250 ms loop, with the Steam link only: each module's pass work, guarded, in a fixed order.
return function(M)
local print,log=M.print,M.log
local T=require('ui.text')
-- The chat alone in the SBO lobby said its notice (chat.alone) in this alone stretch.
local alone_told=false
-- A member of the Steam lobby past the handshake, in any ghost slot: link.chatting() reads the slot-0 member only,
-- and a match lobby's other members hear our lines too.
local function heard_by_member()
    for _,m in ipairs(M.link.members()) do if m.linked then return true end end
    return false
end
if M.link then
    -- The ghost turns on when a session starts (none to host or guest): once, so coop puppet off holds until the next.
    -- A status read with no mode (before Steam, or unreadable) is no leave.
    local last_mode='none'
    -- Our CNS packs, once a Lua load, in the log (coop status shows them too).
    local cns_said=false
    local shared_seen=0 -- link.shared_version() as last acted on.
    -- An on or off setting the native part takes through its own ask (hide_popups: popups on or off), asked at the
    -- first pass of a Lua load and at each change of the setting. A request that cannot be written is asked again at
    -- each pass and logged once, as hud_pass does. switch_asked: the value last asked, by key. want, when given,
    -- stands for the setting (the closet's pad chord: on while the closet module is on).
    local switch_asked,switch_refused={},{}
    local function switch_pass(key,word,want)
        if want==nil then want=M.settings[key]==true end
        if want==switch_asked[key] then return end
        local line=word..(want and ' on' or ' off')
        local ok,why=M.link.request(line)
        if ok then switch_asked[key],switch_refused[key]=want,nil; return end
        local text=word..': '..line..' not asked: '..tostring(why)
        if text~=switch_refused[key] then switch_refused[key]=text; log(text) end
    end
    LoopInGameThreadWithDelay(250,function()
        local began=os.clock()
        M.took.slow,M.took.booth=0,0 -- Neither may run in this pass.
        if M.off and not M.blocked then M.blocked=M.native_off() end
        for _,line in ipairs(M.link.changes()) do log('link: '..line) end
        M.guarded('keep',require('core.keep').slow) -- After coop off too: the status's coop_off turns it off.
        M.guarded('daynight',M.daynight.slow,M.off) -- After coop off too: it asks sky off once.
        M.guarded('pause tab',M.pause_tab.slow) -- Asks pausetab on or off; nothing after coop off.
        if not M.off then M.guarded('popups',switch_pass,'hide_popups','popups') end -- Asks popups on or off.
        -- Asks closet on or off: LB held + D-pad Left makes the pad's closet event only while the closet module is on.
        if not M.off then
            M.guarded('closet',switch_pass,'closet','closet',not M.off_modules.closet)
        end
        if not M.off then M.guarded('nightop',M.night.tick) end -- Night Operation's run, if any: it logs its own lines.
        -- Roxanne's Night Operation choices: likewise; after coop off, only her two choices and the rows back.
        M.guarded('roxanne',M.roxanne.tick,M.off)
        M.guarded('lily',M.lily.tick,M.off) -- Lily's signal: likewise.
        if not M.off then M.guarded('guard',M.guard_text.tick) end -- The Xion guard's lines: it logs its own lines.
        M.chat_clock=M.chat_clock+0.25
        -- The friend's revive: it logs its own lines.
        if not M.off then M.guarded('revive',M.group.tick,M.chat_clock) end
        if not M.off then M.guarded('travel',M.travel.tick,M.chat_clock) end -- The follow: likewise.
        if not M.off then M.guarded('gift',M.mailbox.tick) end -- coop gift: likewise.
        if not M.off then M.guarded('sbo',M.sbo.tick,os.clock()) end -- The SBO lobby: likewise.
        if not M.off then M.guarded('halls',M.halls.tick) end -- The hall rows' wait and read-back: likewise.
        -- The team shop rows' wait and read-back, then its open's answer: likewise.
        if not M.off then M.guarded('teamshop',M.teamshop.tick) end
        -- SBO Xion's rows' wait and read-back, then its watch while EVE is there: likewise.
        if not M.off then M.guarded('sboxion',M.sboxion.tick) end
        -- Gun mode's rounds: their rows asked once a co-op save has loaded (never at the title), their wait and
        -- read-back, then the inventory reads: likewise. None with gun_mode=off.
        if not M.off and M.gunrounds then M.guarded('gun rounds',M.gunrounds.tick) end
        if not M.off then M.guarded('recruiter',M.recruiter.auto) end -- The recruiter at each Xion load, on any save.
        local chatting=M.link.chatting() -- nil: the status was not read, which ends no session.
        local heard=chatting or heard_by_member()
        -- In the SBO lobby (a hall or Xion's room) the chat holds a session alone too.
        local alone=not M.off and chatting~=nil and not heard and M.guarded('sbo',M.sbo.in_lobby)==true
        if M.off or chatting~=nil then M.guarded('chat',M.chat.session,not M.off and (heard or alone)) end
        if not M.guarded('race',M.race.armed) then M.guarded('inbox',M.inbox) end -- Each frame while one is.
        -- The score attack's round and run, after the inbox, which keeps its score lines apart: it logs its own lines.
        if not M.off then M.guarded('scoreattack',M.scoreattack.tick) end
        -- The fishing tournament's round and book reads, after the inbox, which keeps its mode lines apart: it logs its
        -- own lines.
        if not M.off then M.guarded('fishing',M.fishing.tick) end
        -- The photo hunt's round and photo checks, after the inbox, which keeps its mode lines apart: it logs its own
        -- lines.
        if not M.off then M.guarded('photohunt',M.photohunt.tick) end
        -- One of ours for the native part, two a second at most; never logged. Alone in the lobby it stays on our
        -- screen only, with one notice until someone is linked.
        local typed=M.guarded('chat',M.chat.take,M.chat_clock)
        if not alone then alone_told=false end
        if typed and alone then
            if not alone_told then alone_told=true; M.tell(function(w) return w.chat.alone end) end
        elseif typed and not M.link.say(typed) then M.chat.fail() end
        -- The menu's shared_enemies and same_place rows, coop fight on once a load (fight/enemies/wiring.lua).
        M.guarded('fight',M.fight_asks)
        -- The menu's shared_quests row, coop quests on once a load (story/quests/wiring.lua).
        M.guarded('quests',M.quests_asks)
        -- The menu's shared_world row, coop world on once a load (world/objects/wiring.lua).
        M.guarded('world',M.world_asks)
        -- The menu's shared_story row, coop scenes on or off once a load (story/together/wiring.lua).
        M.guarded('scenes',M.scenes_asks)
        M.guarded('fight',M.fight_notices)
        M.guarded('pilot',M.pilot_notices)
        M.guarded('quests',M.quest_notices)
        M.guarded('world',M.world_notices)
        M.guarded('scenes',M.story_notices)
        M.guarded('paks',M.paks_notice)
        M.guarded('dlcs',M.dlcs_notice)
        M.guarded('cycle',M.cycle_notice)
        if not cns_said and M.link.cns() then
            cns_said=true
            log(M.link.cns())
        end
        local mode=M.link.mode()
        if mode then
            if last_mode=='none' and mode~='none' and not M.off and not M.guarded('ghost',M.puppet.active) then
                M.guarded('ghost',M.ghost_start)
            end
            last_mode=mode
        end
        -- A join Steam refused in the menu's words, a player who joined or left in SB's (its English for the line
        -- above EVE), any other as it came.
        for _,text in ipairs(M.link.notices()) do
            local build=T.join_refused(text)
            if build then M.tell(build) else M.say(require('core.line').feed(text,M.game_words) or text,text) end
        end
        if not M.off then -- Whether a save is loaded (an accepted invite waits for one), the send rate, the photo mode.
            local world,title=M.guarded('ghost',require('core.where').world)
            -- Each title visit: the rows as shipped.
            if title==true and not M.at_title then M.guarded('sbo',M.sbo.title) end
            M.at_title=title==true
            local asked,why=M.guarded('story',M.story.poll,world==true) -- coop-story.txt, in a loaded world only.
            if why then M.report(asked,why) end
            local photo=world and M.photo_state() or '0'
            local own=photo~='0' -- Our photo or selfie mode: nothing of ours in the shot unless the settings say so.
            M.guarded('notice',M.notice.veil,own)
            M.guarded('ghost',M.puppet.photo,own and not M.settings.photo_ghost,own and not M.settings.photo_name_tag)
            -- The solid partner, as the co-op menu last set it; never in an SBO session (design-lobby 12.7). The
            -- native part pushes enemies out of a ghost under the same rule (collide=0 in the state when false).
            local solid=M.settings.collide and not M.guarded('sbo',M.sbo.active)
            M.guarded('ghost',M.puppet.collide,solid)
            -- The host's cutscene rides the photo state as 'c', and the guest asks for its pause
            -- (online/group/group.lua).
            local line=M.link.state(world,M.settings.send_rate,M.guarded('revive',M.group.photo,photo) or photo,
                M.settings.photo_sync,M.settings.photo_freeze_max,title,M.guarded('revive',M.group.cut),
                M.settings.mod_names,M.look.sounds,solid)
            if line then log('state: '..line) end
            local shown=world~=nil and world~=false and not own -- Our HUD: in a world, out of our own photos.
            M.hud_shown=shown
            -- The root on the title screen too: the co-op saves' question, and the feed for its notices.
            local ok,message=M.peaked('slow','kit',M.kit.slow,shown or title==true,title==true)
            if message then M.report(ok,message) end
            -- UE4SS-settings.ini's notices, the crash sentinel's and one for each module that failed to load
            -- (main/loader.lua), once: in the feed once the UI is up, or above EVE once a save is loaded.
            if (M.ue4ss_notes[1] or M.aside_note or M.off_notes[1]) and (M.kit.ready() or world==true) then
                for _,word in ipairs(M.ue4ss_notes) do M.tell(function(w) return w.ue4ss[word] end) end
                if M.aside_note then
                    local name=M.aside_note
                    M.tell(function(w) return w.ghost.aside:format(name) end)
                end
                for _,name in ipairs(M.off_notes) do
                    M.tell(function(w) return w.module_off:format(w.modules[name] or name) end)
                end
                M.ue4ss_notes,M.aside_note,M.off_notes={},nil,{}
            end
            -- The focus watchdog fired: as coop ui reset, nothing said on screen.
            local dropped,who=M.guarded('kit',M.kit.lost)
            if dropped then
                M.ui_reset('focus watchdog: '..who..' lost the focus for 1 s: co-op UI closed, the game has its input '
                    ..'back')
            end
            M.guarded('menu',M.menu.slow,shown,not (M.box.is_open() or M.code_box.is_open() or M.approval.is_open()
                or M.saves_ui.is_open() or M.open_screen())
                and (M.guarded('booth',M.booth.near,require('core.where').me()) or M.guarded('sbo',M.seat_hint))
                or nil)
            M.guarded('wheel',M.wheel.slow,shown)
            M.guarded('lobby',M.lobby.slow)
            M.guarded('sessions',M.sessions.slow,shown)
            M.guarded('create',M.create.slow,shown)
            M.guarded('arrival',M.arrival_pass) -- After sbo.tick and kit.slow above: this pass's arrival and look.
            M.guarded('lobby',M.lobby_pass) -- After sbo.tick above: this pass's arrival and round lines.
            M.guarded('lobby',M.hud_pass) -- After lobby_pass and ui_reset above: the screens as this pass left them.
            M.peaked('booth','booth',M.booth.tick,os.clock(),
                shown and M.kit.ready() and not M.kit.off() and not M.kit.paused()
                and not M.menu.is_open() and require('core.where').me() or nil)
            M.guarded('chat',M.box.slow,M.chat_clock)
            M.guarded('join',M.code_box.slow,shown)
            M.guarded('join',M.approval.slow,shown) -- After the chat's: it waits while the box is open.
            M.guarded('hud',M.hud.slow)
            M.guarded('saves',M.saves_ui.slow,world==true,title==true)
            -- Matrix XIII's rows at the title with the co-op save files, so a co-op save that names its camp loads
            -- with them (world/maps/matrix13/level/travel.lua: once a game run, with the test pak only).
            M.guarded('mxiii',M.mxiii.title,title==true and world~=true,(M.link.saves() or {}).saves=='coop')
            -- Lily's signal's rows likewise (test pak only), so a co-op save that holds the quest keeps it.
            M.guarded('lily',M.lily.title,title==true and world~=true,(M.link.saves() or {}).saves=='coop')
            -- The hall lobby maps' rows likewise (lobby pak only), so an SBO lobby can warp to them.
            M.guarded('halls',M.halls.title,title==true and world~=true,(M.link.saves() or {}).saves=='coop')
            -- The team shop's rows likewise, so coop teamshop on a co-op save finds its ShopTable row.
            M.guarded('teamshop',M.teamshop.title,title==true and world~=true,(M.link.saves() or {}).saves=='coop')
            -- SBO Xion's rows likewise (its test pak only), so coop xion's warp finds its zone.
            M.guarded('sboxion',M.sboxion.title,title==true and world~=true,(M.link.saves() or {}).saves=='coop')
            -- Her marker carries her name: the ghost's tag is its fallback.
            M.guarded('ghost',M.puppet.marker,M.guarded('hud',M.hud.marking))
            if world or title then M.guarded('photo',M.photo_pause,M.settings.photo_pause=='scenery' and 1 or 0,
                M.settings.photo_pause) end
            -- The race's session and map checks, from the ghost's world read just above.
            local raced,why=M.guarded('race',M.race.slow)
            if why then M.report(raced,why) end
            -- The bike: the preload as bike says, her part, the ride's checks; an end said on screen.
            local rode,ended=M.guarded('bike',M.bike.slow)
            if ended then M.report(rode,ended); M.say(ended) end
            M.guarded('bike',M.others.slow) -- Then the other players' parked bikes on our map.
        else -- After coop off, whether a save is loaded or the title is shown, and no photo mode: the native part's
            -- check of the SBO session records at each title visit still runs then (design-lobby 12.8).
            local world,title=M.guarded('ghost',require('core.where').world)
            local line=M.link.state(world,M.settings.send_rate,'0',M.settings.photo_sync,M.settings.photo_freeze_max,
                title,false,M.settings.mod_names,M.look.sounds,M.settings.collide and not M.guarded('sbo',M.sbo.active))
            if line then log('state: '..line) end
        end
        -- Withdrawn when the ghost is off, coop off included.
        local ok,message=M.guarded('capture',M.capture.tick,M.guarded('ghost',M.puppet.active))
        if message then M.report(ok,message) end
        ok,message=M.guarded('ghost',M.puppet.remote,M.link.remote())
        if message then M.report(ok,message) end
        if not M.off then M.report_each(M.guarded('ghost',M.ghosts.sync)) end -- None made or fed after coop off.
        -- A new list of mods both players have: the ghost built again with what it may now load (or no longer may).
        if M.link.shared_version()~=shared_seen then
            shared_seen=M.link.shared_version()
            message=M.guarded('ghost',M.puppet.rebuild,'shared mods changed')
            if message then M.report(true,message) end
        end
        M.pass_ended=os.clock()
        M.pass_took,M.pass_slow,M.pass_booth=M.pass_ended-began,M.took.slow,M.took.booth
        M.passed(M.timed.pass,M.pass_took)
        M.link.settle() -- From here on, status() reads coop-status.txt again (core/link.lua's pass).
    end)
end
end
