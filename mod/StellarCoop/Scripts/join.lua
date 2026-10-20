-- Join codes on screen (UI-DESIGN 4.6, FEATURE-PARITY C5, C6 and Q7) on the Uplink kit (ui.lua); no engine call here.
-- The code box: the co-op menu's Join with a code row closes the menu and opens it. It is a text box like the chat's:
-- Slate types the characters, the game's input goes to the box (focused again 50 ms later) and comes back 150 ms after
-- a close. Enter joins with the text when it is a join code (link.join_code: either case, with or without the dash) and
-- closes; other text gets a line saying what a code looks like and stays. Enter on an empty box closes it, Esc cancels.
-- The box closes by itself outside a world, when the game pauses or shows the mouse cursor, when a session starts and
-- when the kit turns off.
-- The host's question: a player who is not her Steam friend asks to join (link.pending). "<name> wants to join" with
-- Accept and Deny, Deny focused, so a key meant for something else never lets a stranger in. It opens in a world only,
-- not while the game is paused or shows the mouse cursor nor while the chat box is open (it waits, hidden), closes the
-- co-op menu, plays the game's alert and holds the game's input while open: up and down move, Enter or Space answers,
-- Esc denies. 30 s after the request first showed with no answer, open or not (the UI off too), it denies; the native
-- part's own limit is 60 s. Once 3 players were refused in the lobby (the native part's refused= count: denied,
-- removed, or gone before an answer), the next ones are denied with no question and one notice, so a code that leaked
-- cannot keep taking the host's keys. Each player is asked once a lobby.
local T=require('ui_text')
local Chat=require('chat')
local Join={}
local BACK,REFOCUS=0.15,0.05 -- Seconds: the game's input back after a close; the box focused again.
local WAIT,LIMIT,NAME=120,3,24 -- 250 ms ticks before no answer denies (30 s); refusals before no question; characters.
-- A Steam name for the screen: cleaned as a chat line (a name may hold anything), at most 24 characters; nil when
-- nothing is left.
function Join.name(text)
    local name=Chat.clean(text or '')
    if name=='' then return nil end
    if utf8.len(name)>NAME then name=name:sub(1,utf8.offset(name,NAME+1)-1)..'...' end
    return name
end
-- o: {kit=ui.kit's, link=, settings= (main.lua's: ui_language), theme=ui.THEME, run=function(name, arg) -> ok,
-- message (main.lua's: the console's checks and log line)}.
function Join.box(o)
    local kit,link,settings=o.kit,o.link,o.settings
    local self,open,back_at,refocus_at,words={},false,nil,nil,T.en
    -- Where the menu was (it closes first), scaled from its left middle as the menu is.
    kit.add('code',{x=180,y=870,w=1240,h=420,hit=true,pivot={X=0,Y=0.5}},function(b)
        b.panel(0,0,1240,420)
        return {title=b.text(48,36,'','title'),box=b.field(48,140,1144,64,''),
            note=b.text(48,236,'','status',o.theme.error),hints=b.hints(48,320,400,{{'enter',''},{'escape',''}})}
    end)
    function self.is_open() return open end
    -- The menu's row: true once open; false when it cannot be (the kit off, no root, the game paused or on a screen).
    function self.open()
        if open or kit.off() or not kit.ready() or kit.paused() then return false end
        words=T.pick(kit.language(),settings.ui_language)
        kit.show('code',true,os.clock())
        kit.input(true,'code')
        local v=kit.view('code')
        if not v then return false end -- The kit turned off as it took the input: given back.
        open,back_at,refocus_at=true,nil,os.clock()+REFOCUS
        v.title.set(words.join.title)
        v.box.set('')
        v.box.hint(words.join.hint)
        v.note.set('')
        v.hints[1].set(words.join.join)
        v.hints[2].set(words.join.cancel)
        return true
    end
    -- Closed (Esc, an empty box, a join asked...): the text goes, the game's input 150 ms later.
    function self.close()
        if not open then return end
        open,refocus_at,back_at=false,nil,os.clock()+BACK
        local v=kit.view('code')
        if v then v.box.set('') end
        kit.show('code',false,os.clock())
    end
    self.cancel=self.close
    -- Enter: a join code joins and closes; an empty box closes; else why, in the box.
    function self.send()
        if not open then return end
        local v=kit.view('code')
        if not v then return self.close() end
        local text=v.box.text()
        if not text:find('[^ \t]') then return self.close() end
        local code=link.join_code(text)
        local ok,why=false,words.join.bad
        if code then ok,why=o.run('join',code) end
        if ok then return self.close() end
        v.note.set(why)
        refocus_at=os.clock()+REFOCUS
    end
    -- Each 250 ms with whether our HUD may show: closed once it can no longer be open (an unread status, with no mode,
    -- closes nothing); the game's input asked back while still due.
    function self.slow(shown)
        local mode=link.mode()
        if open and not (shown and kit.ready() and not kit.paused() and mode~='host' and mode~='guest') then
            self.close()
        end
        if not (open or back_at) then kit.input(false,'code') end
    end
    -- Each frame: the game's input back, the box focused again, once due.
    function self.tick(now)
        if back_at and now>=back_at then
            back_at=nil
            kit.input(false,'code')
        end
        if refocus_at and now>=refocus_at then
            refocus_at=nil
            local v=open and kit.view('code')
            if v then v.box.focus() end
        end
    end
    -- coop off: closed (kit.stop gives the game its input back).
    function self.stop() open,back_at,refocus_at=false,nil,nil end
    return self
end
-- o: {kit=, link=, settings=, run= (as Join.box's), say=function(text) (a notice), log=function(line), menu=menu.lua's
-- (closed as the question opens), chat=chat.lua's view (the question waits while its box is open)}.
function Join.ask(o)
    local kit,link,settings=o.kit,o.link,o.settings
    local self,open,cursor,back_at,stopped,words={},false,2,nil,false,T.en
    -- asking: {id=, name=, ticks=} the player asked about; answered: the SteamIDs answered in lobby; told: its notice.
    local asking,answered,lobby,told=nil,{},nil,false
    -- Centred, scaled from its centre.
    kit.add('ask',{x=1170,y=780,w=1500,h=600,pivot={X=0.5,Y=0.5}},function(b)
        b.panel(0,0,1500,600)
        return {title=b.text(48,36,'','title'),about=b.text(48,136,'','body'),
            rows={b.row(24,230,1452),b.row(24,306,1452)},
            hints=b.hints(48,500,400,{{'arrows',''},{'enter',''},{'escape',''}})}
    end)
    local function draw()
        local v=open and kit.view('ask')
        if not v then return end
        local w=words.ask
        v.title.set(w.title:format(Join.name(asking.name) or w.someone))
        v.about.set(w.about:format(math.ceil((WAIT-asking.ticks)/4)))
        v.rows[1].set(w.accept,'',cursor==1 and 'focus' or 'normal')
        v.rows[2].set(w.deny,'',cursor==2 and 'focus' or 'normal')
        v.hints[1].set(words.hint.move)
        v.hints[2].set(words.hint.select)
        v.hints[3].set(w.deny)
    end
    local function hide()
        if not open then return end
        open,back_at=false,os.clock()+BACK
        kit.show('ask',false,os.clock())
        kit.sound('close')
    end
    -- The answer about the player asked about, once: allow or deny, through the console's command (logged there).
    local function answer(verb)
        local id=asking.id
        answered[id],asking=true,nil
        hide()
        local ok,why=o.run(verb,id)
        if not ok then o.say(why) end
    end
    function self.is_open() return open end
    -- Each 250 ms with whether our HUD may show. An unread status (no mode) changes nothing but the 30 s.
    function self.slow(shown)
        if stopped then return end
        local p=link.pending()
        if link.mode() then
            if link.lobby()~=lobby then lobby,answered,told=link.lobby(),{},false end
            if asking and not (p and p.id==asking.id) then -- She left, or the console answered.
                asking=nil
                hide()
            end
            if p and not asking and not answered[p.id] then
                local _,refused=link.code()
                asking={id=p.id,name=p.name,ticks=0}
                if (refused or 0)>=LIMIT then
                    o.log('join: '..refused..' players refused in this lobby: '..p.id..' denied with no question')
                    answer('deny')
                    if not told then
                        told=true
                        o.say(T.pick(kit.language(),settings.ui_language).ask.auto)
                    end
                end
            end
            if asking then asking.name=p.name end -- Steam may learn her name after she joined.
        end
        if asking then
            asking.ticks=asking.ticks+1
            if asking.ticks>=WAIT then
                o.log('join: no answer from the host in 30 s: denied')
                return answer('deny')
            end
            local can=shown and kit.ready() and not kit.paused() and not (o.chat and o.chat.is_open())
            if can and not open then
                words=T.pick(kit.language(),settings.ui_language)
                if o.menu and o.menu.is_open() then o.menu.close() end
                open,back_at,cursor=true,nil,2
                kit.show('ask',true,os.clock())
                kit.input(true,'ask')
                kit.sound('alert')
            elseif open and not can then hide() end
        end
        if not (open or back_at) then kit.input(false,'ask') end
        draw()
    end
    -- A key while open: 'up' or 'down' (the other row), 'select' (its answer), 'back' (Esc: deny).
    function self.nav(what)
        if not open or kit.off() then return end -- Unseen: the next slow hides it.
        if what=='up' or what=='down' then
            cursor=3-cursor
            kit.sound('move')
            draw()
        elseif what=='select' then
            kit.sound('select')
            answer(cursor==1 and 'allow' or 'deny')
        elseif what=='back' then
            kit.sound('back')
            answer('deny')
        end
    end
    -- Each frame: the game's input back, once due.
    function self.tick(now)
        if back_at and now>=back_at then
            back_at=nil
            kit.input(false,'ask')
        end
    end
    -- coop ui reset: an open question denied.
    function self.close() if open then answer('deny') end end
    -- coop off: nothing more, no answer either (kit.stop gives the game its input back).
    function self.stop() stopped,open,back_at,asking=true,false,nil,nil end
    return self
end
return Join
