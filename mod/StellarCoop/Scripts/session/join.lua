-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Join codes on screen (UI-DESIGN 4.6, FEATURE-PARITY C5, C6 and Q7) on the Uplink kit (ui/kit/kit.lua). The join
-- popups on SB's own WB_Common_Popup (ui/kit/parts.lua). The code box: the co-op menu's Join with a code row closes the
-- menu and opens it. It is a text box like the chat's: Slate types the characters, the game's input goes to the box
-- (focused again 50 ms later) and comes back 150 ms after a close. Enter joins with the text when it is a join code
-- (link.join_code: either case, with or without the dash) and closes; other text gets a line saying what a code looks
-- like and stays. Enter on an empty box closes it, Esc cancels. The box closes by itself outside a world, when the game
-- pauses or shows the mouse cursor, when a session starts and when the kit turns off.
-- The host's question: a player asks to join (link.pending: not her Steam friend, or any player with friends_ask=on).
-- SB's popup says "<name> wants to join" with SB's Accept and Decline (UI_Request_Accept,
-- UI_CollectPersonalInfo_Refuse) and the seconds left, Decline focused. Several players asking wait in a queue: the
-- native part asks about the first one (her minute runs). The popup asks about her alone, with how many wait after
-- her on the seconds' line; once she is answered or gone, the next one gets her own popup. The joiner's wait
-- (link.wait): SB's popup with one Close button says "Waiting for <host>'s answer" and the seconds left; Close leaves
-- the host's lobby. Either opens
-- in a world only, not while the game is paused or shows the mouse cursor nor while the chat box is open (it waits,
-- hidden), closes the co-op menu, plays SB's popup cues (the game's alert when a player first asks) and holds the
-- game's input with the mouse cursor while open, as SB's popup asks (bUseShowMouseCursor). Up, down, left and right
-- move (the arrows, a pad's D-pad or left stick); select answers with the focused button (Enter, a pad's A); back
-- declines or closes (Esc, a pad's B, a right click); a left click on a button answers with it. It opens on its own,
-- while the player may be walking, fighting or in the menu: so every key, pad button and click does nothing for 1 s
-- after it shows. Decline has the focus, so a stray select declines. A direction held moves the focus once: its
-- repeats move nothing. main.lua gives it the arrows but not W, S or Space; the game ignores its pad while the popup
-- holds its input. With no answer the native part refuses the player after 60 s (the seconds left show), open or not.
-- Each player is asked once a lobby. When SB's popup cannot be made (logged once), the kit's panel shows the same words
-- in its place. SBO's own words stand in for SB's while the game's
-- string table has none (always under ui_language=english).
-- A name shown is cleaned as a chat line with no < or >, which SB's rich text would read as a tag.
local T=require('ui.text')
local Line=require('core.line')
local Parts=require('ui.kit.parts')
local Join={}
-- Seconds: the game's input back after a close; the box focused again; the question's keys ignored after it shows; a
-- direction this soon after the last one is a held stick's or D-pad's repeat (ui/pad.h: 0.4 s, then every 0.12 s).
local BACK,REFOCUS,ARM,HELD=0.15,0.05,1,0.5
local WAIT,NAME=240,16 -- 250 ms ticks of the native part's 60 s for an answer, from our first read; characters.
Join.name,Join.feed=Line.name,Line.feed
-- o: {kit=ui.kit.kit's, link=, settings= (main.lua's: ui_language), theme=ui.THEME, run=function(name, arg) -> ok,
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
-- Seconds from an answer to the SB popup removed (its Accept or close animation plays first); ESlateVisibility of the
-- popup's hover images, which show its keyboard cursor: Hidden, HitTestInvisible. SB's mouse hover events write them
-- too: tick puts ours back.
local GONE,HIDDEN,SEEN=0.25,2,3
-- o: {kit=, link=, settings=, run= (as Join.box's), say=function(text) (a notice), log=function(line) (the UI log),
-- game_text=function(key) SB's word or nil, menu=ui/kit/menu.lua's and guide=ui/kit/guide.lua's (closed as a popup
-- opens), chat=session/chat.lua's view (a popup waits while its box is open)}.
function Join.ask(o)
    local kit,link,settings=o.kit,o.link,o.settings
    local self,open,cursor,back_at,stopped,words,ready_at={},false,2,nil,false,T.en,0
    local moved_at=nil -- The last direction's os.clock, dead ones included.
    -- asking: who the popup is about: {id=, name=, ticks=, alerted=, more=the players asking after her} a player
    -- asking us while we host, or {wait=true, name=the host's, left=} our own wait after we joined; answered: the
    -- SteamIDs answered in lobby (wait=true once our wait was closed there).
    local asking,answered,lobby=nil,{},nil
    -- pop: the SB popup while it shows ({rec, put=the texts and cursor written to it}); leaving: one answered, removed
    -- at its time ({rec, at}); said: SB's words read since the popup opened (false: none).
    local pop,leaving,said=nil,nil,{}
    local P=Parts.new(kit,o.log or function() end,'join')
    kit.warm_part(Parts.ASSET.popup)
    local function game(key)
        if said[key]==nil then said[key]=o.game_text and o.game_text(key) or false end
        return said[key] or nil
    end
    -- The kit's fallback (ruling 5), centred, scaled from its centre.
    kit.add('ask',{x=1170,y=780,w=1500,h=600,hit=true,pivot={X=0.5,Y=0.5}},function(b)
        b.panel(0,0,1500,600)
        return {title=b.text(48,36,'','title'),about=b.text(48,136,'','body'),
            rows={b.row(24,230,1452),b.row(24,306,1452)},
            hints=b.hints(48,500,400,{{'arrows',''},{'enter',''},{'escape',''}})}
    end)
    -- SB's popup goes in a group of its own over the whole screen. It takes the mouse, as the kit's fallback rows do.
    kit.add('ask_popup',{x=0,y=0,w=3840,h=2160,hit=true,fixed=true},function() return {} end)
    -- What the popup says: its title, description, line of seconds and its two buttons' words (SB's own).
    local function texts()
        local w=words.ask
        if asking.wait then
            local close=game('UI_Close') or w.close
            return {title=w.wait_title:format(Join.name(asking.name) or w.host),desc=w.wait_desc,
                left=w.wait_left:format(math.max(0,asking.left)),yes=close,no=close}
        end
        local left=w.left:format(math.max(0,math.ceil((WAIT-asking.ticks)/4)))
        if (asking.more or 0)>0 then left=left..' '..w.queue:format(asking.more) end
        return {title=w.title:format(Join.name(asking.name) or w.someone),desc=w.desc,left=left,
            yes=game('UI_Request_Accept') or w.accept,no=game('UI_CollectPersonalInfo_Refuse') or w.deny}
    end
    -- The texts and cursor on screen, each written on change only.
    local function draw()
        if not open then return end
        local t=texts()
        if pop then
            local put=pop.put
            if put.title~=t.title then
                put.title=t.title
                P.call(pop.rec,'popup title',function(w)
                    w.TitleText=FText(t.title)
                    w.TitleTextBlock:SetText(FText(t.title))
                end)
            end
            if put.left~=t.left then -- Its Construct showed MessageText once; the block itself shows a new one.
                put.left=t.left
                P.call(pop.rec,'popup message',function(w)
                    w.MessageText=FText(t.left)
                    w.RichTextBlock_Message:SetText(FText(t.left))
                end)
            end
            if not asking.wait and put.cursor~=cursor then -- The hover look of the button the cursor is on.
                put.cursor=cursor
                P.call(pop.rec,'popup cursor',function(w)
                    w.Image_Hover_Positive:SetVisibility(cursor==1 and SEEN or HIDDEN)
                    w.Image_Hover_Negative:SetVisibility(cursor==2 and SEEN or HIDDEN)
                end)
            end
            return
        end
        local v=kit.view('ask')
        if not v then return end
        v.title.set(t.title)
        v.about.set(asking.wait and t.desc..' '..t.left or t.left) -- One line in the panel.
        if asking.wait then
            v.rows[1].set(t.yes,'','focus')
            v.rows[2].set('','','normal')
            v.hints[1].set('')
        else
            v.rows[1].set(t.yes,'',cursor==1 and 'focus' or 'normal')
            v.rows[2].set(t.no,'',cursor==2 and 'focus' or 'normal')
            v.hints[1].set(words.hint.move)
        end
        v.hints[2].set(words.hint.select)
        v.hints[3].set(t.no)
    end
    -- Shown: SB's popup (Yes and No for a player asking, Close for our wait), or the kit's panel once the popup cannot
    -- be made (logged once, then left out until the mod reloads). The menu and the guide close; the game's input is
    -- held, every key dead for ARM s, Decline focused. false while neither can show yet (the UI not up).
    local function show()
        words,said=T.pick(kit.language(),settings.ui_language),{}
        local t,rec=texts(),nil
        if not P.broken.popup then
            kit.show('ask_popup',true)
            rec=P.make('ask_popup','popup',0,0,3840,2160,function(w) -- Filled before its Construct.
                w.TitleText=FText(t.title)
                w.DescText=FText(t.desc)
                w.MessageText=FText(t.left)
                -- Close; Yes and No. 4, 5 and 7 hold a button whose end calls NotifyBlueprint.
                w.ButtonType=asking.wait and 1 or 3
            end,true)
            if not rec then kit.show('ask_popup',false) end
        end
        if not (rec or P.broken.popup) then return false end
        if o.menu and o.menu.is_open() then o.menu.close() end
        if o.guide and o.guide.is_open() then
            o.guide.close(asking.wait and 'the wait for the host' or "the host's question")
        end
        open,back_at,cursor,ready_at,moved_at=true,nil,2,os.clock()+ARM,nil
        pop=rec and {rec=rec,put={title=t.title,left=t.left},over=0} or nil
        if rec then
            P.call(rec,'popup RefreshAll',function(w) w:EventNotification('RefreshAll') end)
            P.call(rec,'popup buttons',function(w) -- After RefreshAll: SB's words for the buttons.
                w.ButtonTextBlock_1:SetText(FText(t.yes))
                w.ButtonTextBlock_2:SetText(FText(t.no))
            end)
        else kit.show('ask',true,os.clock()) end
        kit.input(true,'ask',true)
        if rec then kit.refocus() end -- The popup's Construct took the focus.
        return true
    end
    -- Hidden, how='accept' (SB's Accept animation and confirm cue) or 'close' (its close animation and cue); SB's popup
    -- removed GONE s later, the game's input back BACK s later.
    local function hide(how)
        if not open then return end
        open,back_at=false,os.clock()+BACK
        if pop then
            local rec=pop.rec
            pop=nil
            P.call(rec,'popup '..how,function(w)
                w:PlayAnimation(how=='accept' and w.Accept or w.close,0,1,0,1,false)
            end)
            if leaving then kit.drop(leaving.rec) end
            leaving={rec=rec,at=os.clock()+GONE}
            kit.refocus()
        else kit.show('ask',false,os.clock()) end
        kit.sound(how=='accept' and 'popup_confirm' or 'popup_close')
    end
    -- The answer, once: allow or deny the player asking, through the console's command (logged there); leave: our wait
    -- closed with the host's lobby left.
    local function answer(verb)
        local id=asking.id
        if asking.wait then answered.wait=true else answered[id]=true end
        asking=nil
        hide(verb=='allow' and 'accept' or 'close')
        local ok,why=o.run(verb,id)
        if not ok then o.say(why) end
    end
    function self.is_open() return open end
    -- Each 250 ms with whether our HUD may show. An unread status (no mode) changes nothing but the seconds left.
    function self.slow(shown)
        if stopped then return end
        local mode=link.mode()
        if mode then
            if link.lobby()~=lobby then lobby,answered=link.lobby(),{} end
            local p,w=link.pending(),link.wait()
            if asking and not asking.wait and not (p and p.id==asking.id) then -- She left, or the console or the
                asking=nil                                                     -- native 60 s answered.
                hide('close')
            elseif asking and asking.wait and not w then -- Let in (a guest still), or turned away.
                asking=nil
                hide(mode=='guest' and 'accept' or 'close')
            end
            if not asking then
                if p and not answered[p.id] then asking={id=p.id,ticks=0}
                elseif w and not answered.wait then asking={wait=true} end
            end
            if asking and asking.wait then asking.name,asking.left=w.host,w.left
            elseif asking then -- Steam may learn her name after she joined.
                asking.name,asking.more=p.name,#link.pendings()-1
            end
        end
        if open and pop and not kit.alive(pop.rec) then open,pop=false,nil end -- A root build took it: made again.
        if asking then
            if not asking.wait then asking.ticks=asking.ticks+1 end
            local can=shown and kit.ready() and not kit.paused() and not (o.chat and o.chat.is_open())
            if can and not open then
                if show() then
                    -- A player asking: the game's alert the first time. SB's popup cue when it shows again or for
                    -- our wait.
                    kit.sound((asking.wait or asking.alerted) and 'popup_open' or 'alert')
                    asking.alerted=true
                end
            elseif open and not can then hide('close') end
        end
        if not (open or back_at) then kit.input(false,'ask') end
        draw()
    end
    -- The button under the mouse: 'yes' (Accept, or our wait's Close), 'no' (Decline, or Close), else nil.
    local function under()
        local hit
        if pop then
            P.call(pop.rec,'popup click',function(w)
                if w.Button_Positive:IsHovered() then hit='yes' elseif w.Button_Negative:IsHovered() then hit='no' end
            end)
            return hit
        end
        local v=kit.view('ask')
        if v and v.rows[1].hovered() then return 'yes' end
        if v and not asking.wait and v.rows[2].hovered() then return 'no' end
    end
    -- A key, a pad button or a mouse button while open, from 1 s after it showed. A player asking: 'up', 'down', 'left'
    -- or 'right' (the other button), 'select' (the focused button's answer), 'back' (deny), 'click' (a left click: the
    -- answer of the button under the mouse, else nothing). Our wait: 'select', 'back' or a click on Close closes it and
    -- leaves the lobby. A direction under HELD s after the last one moves nothing: a stick held to run or a D-pad held
    -- in a fight repeats every 0.12 s and would flip the focus to Accept half the time.
    function self.nav(what)
        if not open or kit.off() then return end -- Unseen: the next slow hides it.
        local now=os.clock()
        if what=='up' or what=='down' or what=='left' or what=='right' then
            local held=moved_at~=nil and now-moved_at<HELD
            moved_at=now
            if held then return end
        end
        if now<ready_at then return end
        if what=='click' then what=under() end
        if asking.wait then
            if what=='select' or what=='back' or what=='yes' or what=='no' then answer('leave') end
        elseif what=='up' or what=='down' or what=='left' or what=='right' then
            cursor=3-cursor
            kit.sound('move')
            draw()
        elseif what=='select' then answer(cursor==1 and 'allow' or 'deny')
        elseif what=='yes' then answer('allow')
        elseif what=='back' or what=='no' then answer('deny') end
    end
    -- Each frame: the question's hover look put back on the focused button after the mouse moved onto or off a button
    -- (SB's own hover events show and hide the same two images, so Enter or A would answer a button that does not
    -- look focused); an answered popup removed, the game's input back, once due.
    function self.tick(now)
        if pop and asking and not asking.wait then
            local over
            P.call(pop.rec,'popup hover',function(w)
                over=w.Button_Positive:IsHovered() and 1 or w.Button_Negative:IsHovered() and 2 or 0
            end)
            if over and over~=pop.over then
                pop.over,pop.put.cursor=over,nil
                draw()
            end
        end
        if leaving and now>=leaving.at then
            kit.drop(leaving.rec)
            leaving=nil
            if not pop then kit.show('ask_popup',false) end
        end
        if back_at and now>=back_at then
            back_at=nil
            kit.input(false,'ask')
        end
    end
    -- coop ui reset: an open question denied; our open wait hidden for this lobby, which we stay in.
    function self.close()
        if not open then return end
        if not asking.wait then return answer('deny') end
        answered.wait,asking=true,nil
        hide('close')
    end
    -- coop off: nothing more, no answer either (kit.stop gives the game its input back and takes the popup).
    function self.stop() stopped,open,back_at,asking,pop,leaving=true,false,nil,nil,nil,nil end
    return self
end
return Join
