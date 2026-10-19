-- The session chat's model (UI-DESIGN 4.2, 5.2): the feed's lines, the lines waiting for the native part, and when
-- they go. Lua tables only: a reload starts a new model, and nothing here writes a file, a log or the console. Chat
-- text must never reach event(), notice(), status, a log, a report, the console or the settings; counts may.
-- A line is {who='you'|'partner'|'system', name=the partner's (partner only), text, at=the caller's clock in seconds,
-- time='HH:MM', unsent=true once the native part could not send it}.
local Chat={}
local MAX,WAIT,GAP=200,4,0.5 -- Bytes a line, lines waiting to leave, seconds between two (two a second).
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
    -- A line typed: shown at once and queued, or false and why: 'empty' (the box closes), 'no_session', 'off',
    -- 'too_fast' (four already wait).
    function self.send(text,now)
        text=Chat.clean(text)
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
    function self.system(text,now) return add({who='system',text=text,at=now}) end
    -- The feed, oldest first. Read only.
    function self.lines() return feed end
    return self
end
return Chat
