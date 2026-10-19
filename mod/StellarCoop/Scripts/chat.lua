-- The session chat's model (UI-DESIGN 4.2, 5.2): the feed's lines, the lines waiting for the native part, and when
-- they go. Lua tables only: a reload starts a new model, and nothing here writes a file, a log or the console. Chat
-- text must never reach event(), notice(), status, a log, a report, the console or the settings; counts may.
-- A line is {who='you'|'partner'|'system', name=the partner's (partner only), text, at=the caller's clock in seconds,
-- time='HH:MM', unsent=true once the native part could not send it}.
local Chat={}
local MAX,WAIT,GAP=200,4,0.5 -- Bytes a line, lines waiting to leave, seconds between two (two a second).
local PASTE=4096 -- Bytes of a typed line cleaned at most: a pasted megabyte would hold the game thread 100 ms.
local function control(c) -- C0, DEL, C1, and the bidi and zero-width controls.
    return c<0x20 or (c>=0x7F and c<=0x9F) or c==0x061C or (c>=0x200B and c<=0x200F) or (c>=0x2028 and c<=0x202E)
        or (c>=0x2060 and c<=0x206F) or c==0xFEFF
end
-- Spaces off both ends. Once the controls are gone only ASCII spaces are left to trim: no %s, which follows the C
-- locale (0xA0, the end of 'à', is a space in some code pages) and makes a pattern trim slow on long space runs.
local function trim(text)
    local first,last=text:find('[^ ]'),#text
    if not first then return '' end
    while text:byte(last)==32 do last=last-1 end
    return text:sub(first,last)
end
-- The line both players see: well-formed UTF-8 only (any other byte dropped), no controls, trimmed, at most 200
-- bytes, never cut inside a character. '' when nothing is left.
function Chat.clean(text)
    local kept,at={},1
    while at<=#text do
        local _,bad=utf8.len(text,at)
        local stop=bad or #text+1 -- at..stop-1 is well-formed; the byte at stop is not.
        for _,c in utf8.codes(text:sub(at,stop-1)) do if not control(c) then kept[#kept+1]=utf8.char(c) end end
        at=stop+1
    end
    text=trim(table.concat(kept))
    if #text>MAX then
        local cut=MAX+1 -- Back to the first byte of the character the 201st byte belongs to.
        while text:byte(cut)>=0x80 and text:byte(cut)<0xC0 do cut=cut-1 end
        text=trim(text:sub(1,cut-1))
    end
    return text
end
-- lines: how many the feed keeps (the chat_lines setting, 50 unless said); on: false or 'off' for chat=off (nothing
-- sent, nothing received shown; notices still are). Both as numbers and booleans or as ui_model.read's text.
function Chat.new(lines,on)
    lines,on=tonumber(lines) or 50,on~=false and on~='off'
    local self,feed,outbox,session,last,taken={},{},{},false,nil,nil
    local function add(line)
        line.time=os.date('%H:%M')
        feed[#feed+1]=line
        if #feed>lines then table.remove(feed,1) end
        return line
    end
    function self.clear() feed,outbox,taken={},{},nil end
    -- Each check of the link: true while a session holds (a friend linked, or a rejoin pending, or the loopback);
    -- its end clears everything, notices too: call it before adding the notice that says the session ended.
    function self.session(active)
        if session and not active then self.clear() end
        session=active
    end
    function self.active() return session==true end
    -- Chat turned on or off while the mod runs (the menu's Options): as new's on.
    function self.enable(v) on=v~=false and v~='off' end
    -- A line typed: shown at once and queued, or false and why: 'empty' (the box closes), 'no_session', 'off',
    -- 'too_fast' (four already wait).
    function self.send(text,now)
        text=Chat.clean(#text>PASTE and text:sub(1,PASTE) or text)
        if text=='' then return false,'empty' end
        if not session then return false,'no_session' end
        if not on then return false,'off' end
        if #outbox>=WAIT then return false,'too_fast' end
        local line=add({who='you',text=text,at=now})
        outbox[#outbox+1]=line
        return true,line
    end
    -- The next line for the native part, at most one per half second, or nil.
    function self.take(now)
        if not outbox[1] or (last and now-last<GAP) then return nil end
        last,taken=now,table.remove(outbox,1)
        return taken.text
    end
    -- The native part could not send the line taken last.
    function self.fail() if taken then taken.unsent=true end end
    -- The partner's line, cleaned, or nil when there is no session, chat is off or nothing is left of it.
    function self.receive(name,text,now)
        text=Chat.clean(text)
        if not session or not on or text=='' then return nil end
        return add({who='partner',name=Chat.clean(name),text=text,at=now})
    end
    -- A notice, cleaned as a line (a Steam name may hold anything), or nil when nothing is left of it.
    function self.system(text,now)
        text=Chat.clean(text)
        if text=='' then return nil end
        return add({who='system',text=text,at=now})
    end
    -- The feed, oldest first. Read only.
    function self.lines() return feed end
    return self
end
-- The feed and the chat box (UI-DESIGN 3.2, 4.2, 4.4) on the Uplink kit (ui.lua). The feed sits under the partner
-- card and holds chat lines and notices, newest at the bottom: while the box is closed, the last 6 rows of the lines
-- under 8 s old; while open, the last 12 on the panel's glass, the box under them. Her lines are teal (the partner
-- colour), ours white, notices grey, a line not sent red; lines wrap at a space, 70 characters a row. Enter (main.lua's
-- bind) opens the box in a world during a session (or coop loopback) with chat on, never while the game is paused or
-- shows the mouse cursor; outside a session it says so, once per 10 s. While open the game ignores its keys and the box
-- has the keyboard (kit.input with the chat's field, focused again 50 ms later): Slate types the characters, so any
-- layout, accents and dead keys work. Enter sends the line (shown at once; an empty one closes the box; one too fast
-- stays in it), Esc cancels; the game's input comes back 150 ms after a close, so that key never reaches the game.
-- The box closes and empties by itself when the session ends (the history goes with it), chat turns off (her lines
-- hide too), the game pauses or shows the mouse cursor (UI-DESIGN 7.4: a game screen keeps its keys; the friend's
-- photo pause too), our HUD hides or the kit turns off. While the co-op menu covers the feed, the menu shows the newest
-- notice (notice()). No engine call here, and nothing to log with: the text goes to the model and the screen only.
local T=require('ui_text')
local ROWS,SHOWN,FADE,WIDE,HIGH=12,6,8,70,44 -- Rows open, rows closed, seconds shown closed, characters a row, units.
local BACK,REFOCUS,QUIET=0.15,0.05,10 -- Seconds: the game's input back; the box focused again; "needs a session" again.
local COUNT=160 -- Bytes typed from which the box shows how many, of the MAX a line keeps (red past it: cut).
-- Rows of at most WIDE characters (the text is well-formed UTF-8), broken at the last space within reach, else between
-- two characters.
local function wrap(text)
    local rows={}
    while utf8.len(text)>WIDE do
        local cut=utf8.offset(text,WIDE+1)
        local space=text:sub(1,cut):match('.*() ')
        if space and space>1 then rows[#rows+1],text=text:sub(1,space-1),text:sub(space+1)
        else rows[#rows+1],text=text:sub(1,cut-1),text:sub(cut) end
    end
    rows[#rows+1]=text
    return rows
end
-- o: {kit=ui.kit's, model=Chat.new's, settings= (main.lua's: chat, ui_language; the menu changes them in place),
-- theme=ui.THEME, covered=function() -> true while the menu is open over the feed}.
function Chat.view(o)
    local kit,model,settings,theme=o.kit,o.model,o.settings,o.theme
    local self,open,now,back_at,refocus_at,said,covered,heard={},false,0,nil,nil,nil,false,nil
    local words=T.en.chat
    -- Under the feed: the glass and the box, shown while open, with its byte counter at its right; the box takes the
    -- mouse (a click focuses it).
    kit.add('chat',{x=96,y=330,w=1300,h=660,hit=true},function(b)
        b.panel(0,0,1300,660)
        return {box=b.field(24,572,1132,56,words.hint),count=b.text(1172,580,'','num',theme.grey)}
    end)
    kit.add('feed',{x=96,y=330,w=1300,h=40+ROWS*HIGH,shown=true},function(b)
        local rows={}
        for i=1,ROWS do rows[i]=b.text(24,32+(i-1)*HIGH,'','body') end
        return {rows=rows}
    end)
    local function pick() words=T.pick(kit.language(),settings.ui_language).chat end
    local function render(line)
        local who=line.who=='you' and words.you
            or line.who=='partner' and (line.name~='' and line.name or words.partner)
        line.rows=wrap('['..line.time..'] '..(who and words.said:format(who) or '')..line.text
            ..(line.unsent and words.not_sent or ''))
        line.drawn,line.drawn_unsent=words,line.unsent
    end
    local function colour(line)
        return line.unsent and theme.error or line.who=='partner' and theme.teal or line.who=='you' and theme.text
            or theme.grey
    end
    -- The feed as it is now: engine calls only for a row that changed (the kit's text views).
    local function draw()
        local v=kit.view('feed')
        if not v then return end
        local over=o.covered~=nil and o.covered()==true
        if over~=covered then covered=over; kit.show('feed',not over) end
        local lines=model.lines()
        local newest=lines[#lines]
        if newest~=heard then
            heard=newest
            -- Not for a line that waited out its 8 s unseen (a map load, our photo mode).
            if newest and newest.who=='partner' and now-newest.at<FADE then kit.sound('chat') end
        end
        local k,stop,chatting=ROWS,ROWS-(open and ROWS or SHOWN),settings.chat~=false
        for i=#lines,1,-1 do
            local line=lines[i]
            if k==stop or not (open or now-line.at<FADE) then break end
            if chatting or line.who=='system' then
                if line.drawn~=words or line.drawn_unsent~=line.unsent then render(line) end
                for j=#line.rows,1,-1 do
                    if k==stop then break end
                    local row=v.rows[k]
                    row.set(line.rows[j])
                    row.color(colour(line))
                    row.show(true)
                    k=k-1
                end
            end
        end
        for j=1,k do v.rows[j].show(false) end
    end
    function self.is_open() return open end
    -- The newest notice under 8 s old, or nil: the menu shows it while it covers the feed (UI-DESIGN 4.4).
    function self.notice()
        local lines=model.lines()
        for i=#lines,1,-1 do
            if now-lines[i].at>=FADE then return nil end
            if lines[i].who=='system' then return lines[i].text end
        end
    end
    -- Whether the box can open now (the menu's Chat row): a session, chat on, our root up.
    function self.can() return model.active() and settings.chat~=false and kit.ready() end
    -- Enter, the box closed: true once open; false, and why once per 10 s outside a session, with chat off or the kit
    -- off, else quietly (no root yet, the game paused or on a screen of its own: Enter is the game's then).
    function self.open()
        local off=kit.off()
        if open or (not off and (not kit.ready() or kit.paused())) then return false end
        if off or not self.can() then
            if said and now-said<QUIET then return false end
            said=now
            pick()
            return false,not model.active() and words.no_session or settings.chat==false and words.off or words.ui_off
        end
        pick()
        kit.show('chat',true,os.clock())
        kit.input(true,'chat')
        local v=kit.view('chat')
        if not v then return false end -- The kit turned off as it took the input: given back.
        open,back_at,refocus_at=true,nil,os.clock()+REFOCUS
        v.box.set('')
        v.count.set('')
        v.box.hint(words.hint)
        draw()
        return true
    end
    -- The box closed (Esc, an empty line, the session's end...): the draft goes, the game's input 150 ms later.
    function self.close()
        if not open then return end
        open,refocus_at,back_at=false,nil,os.clock()+BACK
        local v=kit.view('chat')
        if v then v.box.set('') end
        kit.show('chat',false,os.clock())
        draw()
    end
    self.cancel=self.close
    -- Enter, the box open: its line sent.
    function self.send()
        if not open then return end
        local v=kit.view('chat')
        if not v then return self.close() end
        local ok,why=model.send(v.box.text(),now)
        if ok then v.box.set(''); v.count.set('') elseif why~='too_fast' then return self.close() end
        refocus_at=os.clock()+REFOCUS
        draw()
    end
    -- A notice into the feed: false when the feed cannot show it (no root, the kit off): the caller's line above EVE
    -- then shows it.
    function self.say(text)
        if not kit.ready() then return false end
        model.system(text,now)
        draw()
        return true
    end
    -- Each 250 ms with the chat's clock: chat on or off, the box closed when it can no longer be open (paused included:
    -- one engine read, while open only), the game's input asked back while still due, the feed drawn.
    function self.slow(t)
        now=t
        model.enable(settings.chat)
        if open and (not self.can() or kit.paused()) then self.close() end
        if not (open or back_at) then kit.input(false,'chat') end
        if kit.ready() then draw() end
        local v=open and kit.view('chat')
        if v then -- The counter: one read of the box a 250 ms while open, a count only.
            local n=#v.box.text()
            v.count.set(n>=COUNT and string.format('%d/%d',n,MAX) or '')
            v.count.color(n>MAX and theme.error or theme.grey)
        end
    end
    -- Each frame: the game's input back, the box focused again, once due.
    function self.tick(t)
        if back_at and t>=back_at then
            back_at=nil
            kit.input(false,'chat')
        end
        if refocus_at and t>=refocus_at then
            refocus_at=nil
            local v=open and kit.view('chat')
            if v then v.box.focus() end
        end
    end
    -- coop off: closed (kit.stop gives the game its input back).
    function self.stop() open,back_at,refocus_at=false,nil,nil end
    return self
end
return Chat
