-- The co-op saves at the title (AUTO-COOP-SAVE §6), on the Uplink kit (ui.lua). UE4SS is not known yet to hold the
-- game's Continue and Load Game presses, so the question comes when the title screen shows, before any press; it takes
-- a choice (Enter, Space, A on a pad, a click) only 1 s after it shows, so a press meant for the title does not answer
-- it. With auto_coop_save=ask it shows once a visit of the title, while the game uses your own saves (the slot line's
-- saves=main), the Steam ID is known and no copy pass runs, once the kit has its whole look: Convert and play co-op
-- (Play co-op once a co-op copy exists in this account's save folder), Play solo normally, Decide later (Esc or B on an
-- XInput pad, or 60 s with no key: a pad that is not XInput cannot answer) and Don't ask again, which writes
-- auto_coop_save=always as one line of coop-settings.txt, then plays co-op. Co-op asks the native part for "saves coop"
-- (it makes or refreshes the copies, then switches the save name, at the title only) and shows the pass's steps until
-- saves=coop; a pass that ends without the switch, or a request with no answer in 2 s, shows why, with only the solo
-- choices left. An unread status is no answer. A solo choice after a request asks "saves main", which withdraws a
-- switch still to come. The title left or the focus watchdog closes it as Decide later; a pass under way is followed
-- on, its result said as a notice. With always, no question: "saves coop" once a visit, its result a notice. With off,
-- nothing: the manual co-op slot that StellarCoopSlot.txt names is the only co-op save (main.lua's shared enemies
-- notice says how to switch in a session on your own save). While the question is open the game ignores its keys (the
-- kit's input; main.lua's binds hand it up, down, select, back and a left click, and an XInput pad's D-pad, left stick,
-- A and B through the native part), a shade over the whole screen takes the mouse so no click reaches the title menu
-- under it, and the game's input comes back 150 ms after it closes. While the game uses the co-op copies (saves=coop),
-- a CO-OP SAVES badge shows at the top right of the title screen, whatever auto_coop_save says. On another game build
-- (a game update) the co-op saves are off: with ask or always, a notice says so once a Lua load at the title. A
-- friend's invite accepted at the title waits for a save (the link's held invite): the question's first line says so,
-- and once a visit it asks again when such an invite comes after an answer without co-op. With a manual co-op slot
-- (StellarCoopSlot.txt) once the game uses the co-op copies, a notice says once a Lua load which files co-op no longer
-- needs; nothing is moved. No engine call here: the kit makes them.
local T=require('ui_text')
local Chat=require('chat')
local SF=require('settings_file')
local Saves={}
-- Seconds before the game's input comes back; 250 ms ticks: no answer, a pass at most, no key (then Decide later);
-- seconds after the question shows before it takes a choice.
local BACK,WAIT,SLOW,IDLE,ARM=0.15,8,480,240,1
local WIDE,BODY=78,5 -- Columns a body row (18 layout units each, as the feed's); body rows.
local CHOICES={ask={'coop','solo','later','always'},error={'solo','later'}}
local function exists(path)
    local f=io.open(path,'rb')
    if not f then return false end
    f:close()
    return true
end
-- o: {kit=ui.kit's, link=, settings= (main.lua's, changed in place: auto_coop_save, ui_language),
-- theme=ui.THEME, say=function(text,en) (a notice, en: the same in English), log=function(line),
-- exists=function(path) and env=function(name) (io.open's and os.getenv's unless said: the tests' fakes)}.
function Saves.new(o)
    local kit,link,settings,log=o.kit,o.link,o.settings,o.log
    local has,env=o.exists or exists,o.env or os.getenv
    local self={}
    local phase,open,cursor,back_at=nil,false,1,nil -- phase: nil, 'ask', 'wait' (a request out) or 'error'.
    local ready_at=0 -- When the question shown takes a choice.
    local visit,asked,copies=false,false,false -- This visit of the title is answered; "saves coop" is out; copies seen.
    local before,waited,quiet,progress,why,idle=nil,0,0,nil,nil,0
    local queued,stopped=nil,false -- queued: a notice to say once the kit is up or a world loads.
    local lang=T.en
    local badged=false -- The badge is shown.
    local told=false -- Another game build said (once a Lua load).
    local invited,reasked=false,false -- An invite waits for a save; the question shown with one this visit.
    local manual=nil -- The manual co-op slot's digit to say, then false once said (once a Lua load).
    -- At the top right, scaled from that corner; wide enough for the French title. Added first: the question draws over.
    kit.add('badge',{x=3024,y=96,w=720,h=96,pivot={X=1,Y=0}},function(b)
        b.panel(0,0,720,96)
        return {text=b.text(24,14,'','title',o.theme.teal)}
    end)
    -- Over the whole screen, scaled from its centre; the shade reaches past any screen, ui_scale 75 included.
    kit.add('saves',{x=0,y=0,w=3840,h=2160,hit=true,pivot={X=0.5,Y=0.5}},function(b)
        b.shade(-1920,-1080,7680,4320,o.theme.shade)
        b.panel(1170,680,1500,800)
        local v={title=b.text(1218,716,'','title'),body={},rows={}}
        for i=1,BODY do v.body[i]=b.text(1218,800+(i-1)*46,'','body') end
        for i=1,4 do v.rows[i]=b.row(1194,1050+(i-1)*76,1452) end
        v.hints=b.hints(1218,1380,400,{{'move',''},{'enter',''},{'escape',''}})
        return v
    end)
    local function pick() lang=T.pick(kit.language(),settings.ui_language) end
    local function draw()
        local v=open and kit.view('saves')
        if not v then return end
        local w,lines=lang.saves,{}
        local function add(text) for _,row in ipairs(Chat.wrap(text,WIDE)) do lines[#lines+1]=row end end
        if phase=='ask' then
            if invited then add(w.invite) end
            add(copies and w.old or w.new)
            add(copies and w.old_about or w.new_about)
        elseif phase=='wait' then add(progress and w.copying:format(progress[1],progress[2]) or w.switching)
        else
            add(w.failed)
            -- see_log's line ends as the failed one does: 。 in Chinese and Japanese, nothing in Thai.
            add(why or w.see_log..(w.failed:match('。$') or w.failed:match('%.$') or ''))
        end
        v.title.set(w.title)
        for i,t in ipairs(v.body) do t.set(lines[i] or '') end
        local list=CHOICES[phase] or {}
        for i,r in ipairs(v.rows) do
            local id=list[i]
            if not id then r.set('','','normal')
            else
                r.set(id=='coop' and (copies and w.play or w.convert) or w[id],id=='always' and w.always_value or '',
                    i==cursor and 'focus' or 'normal')
            end
        end
        v.hints[1].set(lang.hint.move)
        v.hints[2].set(lang.hint.select)
        v.hints[3].set(w.later)
    end
    local function close()
        if not open then return end
        open=false
        kit.show('saves',false,os.clock())
        kit.sound('close')
        back_at=os.clock()+BACK
    end
    -- Whether a co-op copy of any slot is in this account's save folder (LOCALAPPDATA and the status's Steam ID, as the
    -- native part finds the folder): only opened and closed, never read. Unknown (no Steam ID yet, or a path the C
    -- runtime cannot open) counts as none: the first choice then says Convert, and does the same.
    local function any_copy(info)
        local base=env('LOCALAPPDATA')
        if not (base and info.steamid) then return false end
        for n=0,4 do
            if has(base..'\\SB\\Saved\\SaveGames\\'..info.steamid..'\\StellarBladeCoop0'..n..'.sav') then return true end
        end
        return false
    end
    local function failed(text)
        why=text~=nil and Chat.clean(text) or ''
        if why=='' then why=nil end
        log('co-op saves stay off: '..(why or 'no switch (coop-link.log says why)'))
        if open then phase,cursor,idle='error',1,0 else phase,queued=nil,{'off',why} end
    end
    -- "saves coop", then the pass followed: on the question while it is open, else for a notice.
    local function switch(info)
        local ok,message=link.request('saves coop')
        log('co-op saves: '..tostring(message))
        visit=true
        if not ok then return failed(message) end
        asked,phase,before,waited,quiet,progress,why=true,'wait',info.convert,0,0,nil,nil
    end
    -- A choice: co-op (always: written first), or your own saves (solo, later; a request out is withdrawn).
    local function answer(id)
        if id=='coop' or id=='always' then
            if id=='always' then
                local file,new,why_not=link.settings_text(),nil,'coop-settings.txt cannot be read'
                if file then new,why_not=SF.set(file,'auto_coop_save','always') end
                local saved=new~=nil
                if saved then saved,why_not=link.write_settings(new) end
                if saved then settings.auto_coop_save='always' end
                log('co-op saves: auto_coop_save=always '..(saved and 'saved in coop-settings.txt'
                    or 'not saved: '..tostring(why_not)))
            end
            switch(link.saves() or {})
            return draw()
        end
        if id~='solo' and id~='later' then return end
        log('co-op saves: '..(id=='solo' and 'Play solo normally' or 'Decide later')..': your own saves')
        if asked then
            asked=false
            local _,message=link.request('saves main')
            log('co-op saves: '..tostring(message))
        end
        phase=nil
        close()
    end
    -- Each 250 ms while a request is out: the pass's steps; saves=coop, or why not. An unread status (no convert=
    -- line) is no news: 2 s of them fail as no answer does. Also once a pass said failed (2 minutes, or 2 s with no
    -- answer) switches after all: the copies are on.
    local function follow(info)
        if info.saves=='coop' then
            log('co-op saves on')
            phase,asked,queued=nil,false,{'on'}
            return close()
        end
        waited=waited+1
        local done,jobs=(info.convert or ''):match('^busy (%d+)/(%d+)$')
        if done then progress,quiet={tonumber(done),tonumber(jobs)},0 else quiet=quiet+1 end
        if (not done and (quiet>=WAIT or (info.convert and before and info.convert~=before))) or waited>=SLOW then
            failed((info.convert or ''):match('^error:(.*)$'))
        end
        draw()
    end
    function self.is_open() return open end
    -- Each 250 ms: whether a save is loaded (world) and whether the title screen shows (title, a pawn on its map).
    function self.slow(world,title)
        if stopped then return end
        local info=link.saves() or {}
        local want=settings.auto_coop_save
        invited=info.held==true
        if open and invited then reasked=true end -- Its line drawn in the open question: seen, no second ask.
        -- The badge: shown or hidden on change; its word set at each slow (the kit sets it on change only, and a root
        -- built again shows it).
        local badge=(title and not world and info.saves=='coop')==true
        if badge~=badged then
            badged=badge
            kit.show('badge',badge)
        end
        local bv=badge and kit.view('badge')
        if bv then
            pick()
            bv.text.set(lang.saves.title)
        end
        if phase=='wait' or (asked and info.saves=='coop') then follow(info) end
        if not (open or back_at) then kit.input(false,'saves') end -- Still due (no player controller at the close).
        if open and kit.off() then
            if phase~='wait' then phase=nil end
            close()
        end
        if open and phase~='wait' then
            idle=idle+1
            if idle>=IDLE then
                log('co-op saves: no key in 60 s')
                answer('later')
            end
        end
        if title and not world then
            if info.build and info.saves=='off' and want~='off' and not told then
                told,queued=true,{'build'}
                log('co-op saves: off on this game build (coop-link.log: engine off): your own saves')
            end
            local again=invited and visit and not reasked and want=='ask' -- An invite after an answer without co-op.
            if (not visit or again) and not phase and want~='off' and info.saves=='main' and info.steamid
                and not (info.convert or ''):find('^busy') then
                -- always asks at once, so it waits for the native part to judge the title too (slot=none): it reads
                -- coop-state.txt's world=title on its own pass, and a request that comes first is refused for the run.
                if want=='always' then if info.slot=='none' then switch(info) end
                elseif kit.off() then
                    visit,reasked=true,reasked or invited
                    log('co-op saves: the question cannot show (the co-op UI is off): your own saves')
                elseif kit.whole() then
                    visit,reasked,copies,phase,cursor,back_at,idle=true,reasked or invited,any_copy(info),'ask',1,nil,0
                    pick()
                    open,ready_at=true,os.clock()+ARM
                    kit.show('saves',true,os.clock())
                    kit.input(true,'saves')
                    kit.sound('open')
                    draw()
                end
            end
        else
            if open then
                if phase~='wait' then phase=nil end
                close()
            end
            visit,reasked=false,false
        end
        if queued and (world or kit.ready()) then
            pick()
            local function line(w) return w.saves[queued[1]]:format(queued[2] or w.saves.see_log) end
            o.say(line(lang),line(T.en))
            queued=nil
        end
        if manual==nil and info.saves=='coop' and info.marker then manual=info.marker end
        if manual and (world or kit.ready()) then
            pick()
            o.say(lang.saves.manual:format(manual,manual),T.en.saves.manual:format(manual,manual))
            manual=false
        end
        draw() -- The kit may have built its root again meanwhile: on change only.
    end
    -- A navigation key while open: 'up', 'down', 'select', 'back' (Esc: Decide later, or the pass withdrawn) or
    -- 'click' (the left mouse button: the choice under the mouse, if any). select and click from ARM after it showed.
    function self.nav(what)
        if not open or kit.off() then return end -- Unseen: the next slow closes it.
        if (what=='select' or what=='click') and os.clock()<ready_at then return end
        idle=0
        local list=CHOICES[phase] or {}
        if what=='click' then
            local v=kit.view('saves')
            for i,r in ipairs(v and v.rows or {}) do
                if list[i] and r.hovered() then
                    cursor=i
                    kit.sound('select')
                    return answer(list[i])
                end
            end
        elseif (what=='up' or what=='down') and #list>0 then
            cursor=(cursor-1+(what=='up' and -1 or 1))%#list+1
            kit.sound('move')
            draw()
        elseif what=='select' and list[cursor] then
            kit.sound('select')
            answer(list[cursor])
        elseif what=='back' then
            kit.sound('back')
            answer('later')
        end
    end
    -- Each frame: the game's input back, once due.
    function self.tick(now)
        if back_at and now>=back_at then
            back_at=nil
            kit.input(false,'saves')
        end
    end
    -- coop ui reset: closed as Decide later. keep (the focus watchdog, which the player did not ask for): a pass under
    -- way is followed on instead, as when the title is left.
    function self.close(keep)
        if keep and phase=='wait' then return close() end
        if open then answer('later') end
    end
    -- coop off: nothing more (kit.stop gives the game its input back). Not coop ui off: always still asks then.
    function self.stop() stopped,open,back_at,phase=true,false,nil,nil end
    return self
end
return Saves
