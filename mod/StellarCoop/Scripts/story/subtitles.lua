-- Lily's talks (experimental, untested in game): SB's own subtitle box showing the mod's lines
-- (matrix13/quest/text.lua's TALKS) over an unused subtitle-only sequence that cut/scene.lua's talk() plays through
-- Quinn's borrowed theater. A talk is data: its name, the sequence it borrows and that sequence's subtitle windows
-- (TALKS below); the lines, one per window, come from matrix13/quest/text.lua, and windows past the last line show
-- nothing.
-- - The rewrite: a UE4SS hook on the subtitle slot Blueprint's UpdateText (registered once a Lua load, at the first
--   talk or arm(); UE4SS runs a hook on a Blueprint-only function after it), which returns at once unless a talk runs
--   or a capture is armed. Window k is the k-th new window of the talk, never skipped (bSkipAllow is false on every POD
--   subtitle section, so the jump button cannot skip one): a call is the window already shown again when the slot
--   still holds that window's text (SB's or ours) within the window's time (its length and hold); any other call is
--   the next window. The slot's Duration (+0x6B8) names no window: it read each window's length plus 0.03 to 0.04 s
--   in game (2026-10-30), and the talks repeat lengths (1.26 twice, 2.56 and 2.61, 4.03 and 4.09), so matching it
--   jumped from window 3 to 6 and 13. Each window gets author (+0x688) from StringTable_Seq
--   (SB's own localized speaker names: Seq_Actor_Lily, Seq_Actor_EVE, Seq_Actor_Announcement; '' an empty author),
--   Message (+0x6A0) the line in the game's language (French for a French culture, else English), Type (+0x680) 0
--   (shown at once) for a line longer than its window at READ characters a second, and AuthorColor (+0x76C) once a
--   capture saw that speaker's colour; then UpdateText again under a re-entry guard.
-- - The reading hold: a window whose line needs SPARE + its length / READ seconds, more than the window gives, has the
--   observer's sequence player paused EARLY s before the window ends and played again after the difference. Whether
--   SB keeps the subtitle on screen while its sequence is paused is not known yet (to be checked in game). A Pause or
--   Play that is missing or raises ends the holds for the talk; a sequence that has not moved on to another window
--   STUCK s past a hold gets the Stop row and ends the talk; a skip during a hold ends that hold.
-- - The end: once the last line's window (and its hold) is over and the sequence has more windows, the Stop row.
-- - The fallbacks, each logged: the theater's own sequence played or no observer in 10 s, the same rows on the
--   sequence with no theater (no Stop: it runs to its end, windows past the lines shown empty); window 1 not rewritten
--   FIRST s past its start in the sequence, counted from when the observer showed (the observer is looked for once a
--   second, so it shows up to 1 s after the sequence starts; in a world just loaded the first window came later than
--   1 s after it), or the hook not registered, the Stop row and the kit version (ui/kit.lua: the
--   speaker and the line at the bottom of the screen, each for its window or its reading time, whichever is longer;
--   not SB's widget, so the player's subtitle options do not apply); no kit, no talk. Every talk ends with done(how)
--   (theater, sequence, kit, none or failed), so the quest flow never waits on one.
-- - The wait: a talk (the prologue or the finale after a pick, the arrival, one by hand; not the kit version by hand)
--   starts only once no cutscene of the game plays (her goodbye after a pick), looked for every POLL s up to WAIT s,
--   and POLL s after one it waited for ended; past WAIT s it is asked anyway and the fallbacks follow as above.
-- - Our own sequence: a rewritten window tells scene.lua the talk plays (alive), and a talk refused because a talk's
--   own sequence still plays gets no fallback (failed): the kit would show its lines under SB's.
-- Nothing here reaches the save: the take, the rows and the slot's fields live in memory.
local U=require('core.unreal')
local T=require('matrix13.quest.text')
local Subtitles={}
local HOOK='/Game/Art/UI/Widget/Theater/WB_Theater_Subtitle3_Slot.WB_Theater_Subtitle3_Slot_C:UpdateText'
local SEQ_TABLE='/Game/Local/Localize/StringTable_Seq.StringTable_Seq'
local TEXT_LIB='/Script/Engine.Default__KismetTextLibrary'
local LANGUAGE='/Script/Engine.Default__KismetInternationalizationLibrary'
local DIR='/Game/GameDesign/Level/Subtitle/StarsDescent/Tetrapod/'
local function sequence(n) return DIR..n..'.'..n end
-- Characters read a second; s added to a line's reading time; s before a window's end that a hold pauses; s past
-- window 1's start (after the observer showed) for its rewrite; s past a hold for the next window; s a capture stays
-- armed.
Subtitles.READ,Subtitles.SPARE,Subtitles.EARLY,Subtitles.FIRST,Subtitles.STUCK,Subtitles.CAPTURE=15,0.5,0.15,2.0,2,30
-- s between two looks for a cutscene of the game before a talk (each a walk of every object, 25 to 80 ms); the
-- longest wait for it to end.
Subtitles.POLL,Subtitles.WAIT=0.5,20
-- The talks: the sequence each borrows, its window 1's start in s and its subtitle windows' lengths in s, in order
-- (read from the cooked sequences: 21, 9 and 19 windows).
Subtitles.TALKS={
    prologue={sequence=sequence('Subtitle_POD_1stMeetAdam_01'),first=0,windows={2.10,5.31,5.50,2.56,4.09,2.61,1.26,
        3.17,2.94,3.94,1.26,5.03,4.03,3.28,4.28,2.03,2.92,0.92,5.04,3.43,1.88}},
    arrival={sequence=sequence('Subtitle_POD_ArriveDED_01'),first=0.68,windows={2.59,2.27,2.06,2.24,1.64,4.32,3.15,
        2.88,1.57}},
    finale={sequence=sequence('Subtitle_POD_1stMeetAdam_02'),first=0.53,windows={1.58,2.39,3.72,2.82,4.58,2.54,2.94,
        2.47,4.94,3.42,3.29,0.95,2.67,3.29,2.56,2.05,3.23,5.39,1.63}},
}
local function why(e) return (tostring(e):gsub('^.-:%d+: ','')) end
-- The window of a talk's call: windows (lengths), w the window shown last ({k=, sb=, ours=, until_at=}; k 0 before
-- the first), shown the slot's text at the call (nil when unread), now the os.clock. The window shown again when the
-- slot still holds its text (SB's or ours) before until_at; else the next, never past the last.
function Subtitles.window(windows,w,shown,now)
    if w.k>0 and shown~=nil and (shown==w.sb or shown==w.ours) and now<w.until_at then return w.k end
    return math.min(w.k+1,#windows)
end
-- Window k's speaker key and line in culture ('en' or 'fr'), or nil past the talk's lines.
function Subtitles.entry(lines,k,culture)
    local e=lines[k]
    if not e then return nil end
    return e[1],e[culture=='fr' and 3 or 2]
end
-- The reading hold for a line shown in a window of length s: how many seconds more it needs, or nil.
function Subtitles.hold(line,length)
    local need=Subtitles.SPARE+utf8.len(line)/Subtitles.READ
    return need>length+1e-9 and need-length or nil
end
-- Whether a line is longer than its window at READ characters a second (shown at once, Type 0).
local function long(line,length) return utf8.len(line)/Subtitles.READ>length end
local function culture()
    local ok,c=pcall(function() return U.text(U.find(LANGUAGE):GetCurrentLanguage()) end)
    return T.culture(ok and c or nil)
end

-- o: log (Lily's [LY] lines), scene (cut/scene.lua's: talk, stop_talk, player, busy).
function Subtitles.new(o)
    local log,scene=o.log,o.scene
    local self={}
    local hooked=false -- The hook registered this Lua load.
    local cur=nil -- The talk under way (see play).
    local colors={} -- Speaker key -> AuthorColor {R,G,B,A}, as a capture saw it.
    local capture_until=-math.huge
    local holds=true -- coop lily hold on|off: Lua memory only.
    local kit,theme=nil,nil
    local rewriting=false
    local calls,last_call=0,nil -- SB's UpdateText calls the hook saw this Lua load (ours left out), the last's clock.
    -- A speaker's name as SB's StringTable_Seq gives it (an FText, '' for none), read once a talk; on a failure an
    -- empty one, said once a talk.
    local function speaker(c,key)
        if key=='' then return FText('') end
        if c.names[key]==nil then
            local ok,text=pcall(function() return U.find(TEXT_LIB):TextFromStringTable(FName(SEQ_TABLE),key) end)
            c.names[key]=ok and text or false
            if not ok then log('STOP: talk: '..key..' not read from StringTable_Seq ('..why(text)..'): no name') end
        end
        return c.names[key] or FText('')
    end
    local function finish(how)
        local c=cur
        cur=nil
        if c.kit_on and kit then pcall(kit.show,'talk',false) end
        log(string.format('talk %s: %s (%d windows rewritten)',c.name,how,c.rewritten))
        c.done(how)
    end
    -- The kit version from its first line: shown and timed by tick; with no kit, no talk.
    local function start_kit(now)
        cur.step,cur.line,cur.next_at='kit',0,now
        local v=kit and kit.view('talk')
        if not v then
            log('STOP: talk '..cur.name..': the kit is not up: no talk; the quest goes on')
            return finish('none')
        end
        kit.show('talk',true)
        cur.kit_on,cur.view=true,v
        log('talk '..cur.name..': the kit version')
    end
    local start_sequence
    -- Scene's end of the talk's theater or sequence: done, or the next fallback.
    local function ended(c,ok,message,info)
        if cur~=c or c.step=='kit' then return end
        if c.failed then return start_kit(os.clock()) end
        if c.step=='theater' and (info.own or not info.seen) then
            log('STOP: talk '..c.name..': '..message..': the sequence with no theater next')
            return start_sequence(c)
        end
        if not info.seen then
            log('STOP: talk '..c.name..': '..message..': the kit version next')
            return start_kit(os.clock())
        end
        finish(ok and c.step or 'failed')
    end
    local function call(c,direct)
        return scene.talk(c.t.sequence,{direct=direct,seen=function() if cur==c then c.seen_at=os.clock() end end,
            alive=function() return cur==c and c.last_at or nil end,done=function(...) ended(c,...) end})
    end
    -- Refused because a talk's own sequence still plays: no fallback, whose kit would show under SB's lines.
    local function ours(c,what,said)
        log('STOP: talk '..c.name..': '..what..': '..said..': no fallback while our own sequence plays')
        finish('failed')
    end
    start_sequence=function(c) -- From the theater step: its window count and timers start again.
        c.w={k=0}
        c.step,c.k,c.rewritten,c.seen_at,c.hold,c.watch,c.stop_at,c.stopping,c.last_at='sequence',0,0,nil,nil,nil,nil,
            nil,nil
        local ok,said,mine=call(c,true)
        if not ok then
            if mine then return ours(c,'the sequence with no theater',said) end
            log('STOP: talk '..c.name..': the sequence with no theater: '..said..': the kit version next')
            return start_kit(os.clock())
        end
    end
    -- Before the theater: while a cutscene of the game plays, looked for every POLL s up to WAIT s; then the theater
    -- asked, whatever plays (a refusal leads to the fallbacks).
    local function wait(c,now)
        if now<c.poll_at then return end
        c.poll_at=now+Subtitles.POLL
        local ran,busy=pcall(scene.busy)
        busy=ran and busy or nil
        if busy and now<c.wait_until then
            if not c.waited then
                c.waited=now
                log(string.format('talk %s: waits up to %d s for a cutscene of the game to end (%s)',c.name,
                    Subtitles.WAIT,busy))
            end
            return
        end
        if busy then
            log(string.format('STOP: talk %s: %s still plays after %d s: the theater asked anyway',c.name,busy,
                Subtitles.WAIT))
        elseif c.waited and not c.clear then -- Asked one look (POLL s) after it ended, once the game settled.
            c.clear=now
            return log(string.format('talk %s: the cutscene ended after %.1f s: the theater in %.1f s',c.name,
                now-c.waited,Subtitles.POLL))
        end
        c.step='theater'
        local played,said,mine=call(c,false)
        if not played then
            if mine then return ours(c,'the theater',said) end
            log('STOP: talk '..c.name..': the theater: '..said..': the sequence with no theater next')
            start_sequence(c)
        end
    end
    local function stop_row(c,why_now)
        if c.stopping then return end
        c.stopping=true
        local ok,said=scene.stop_talk()
        log(why_now..': '..tostring(said))
        if not ok and c.step=='sequence' then finish('failed') end
    end
    local function play_player(c,what)
        local ok,e=pcall(function() local p=assert(scene.player(),'no sequence player') p[what](p) end)
        if not ok then
            c.holds_off=true
            log('STOP: hold: '..what..' failed ('..why(e)..'): no more holds this talk')
        end
        return ok
    end
    -- The hook's work for one call of a talk's window.
    local function rewrite(c,slot)
        local now=os.clock()
        local read,shown=pcall(function() return U.text(slot.Message) end)
        shown=read and shown or nil
        local k=Subtitles.window(c.t.windows,c.w,shown,now)
        local again=k==c.k
        if not again and c.hold then -- A new window during a hold ends it.
            if c.hold.paused then play_player(c,'Play') end
            log(string.format('hold %d cancelled: window %d showed',c.hold.k,k))
            c.hold=nil
        end
        c.k=k
        local key,line=Subtitles.entry(c.lines,k,c.culture)
        local length=c.t.windows[k]
        slot.author=line and speaker(c,key) or FText('')
        slot.Message=FText(line or '')
        if line and long(line,length) then slot.Type=0 end
        if line and colors[key] then slot.AuthorColor=colors[key] end
        rewriting=true
        local fine,e=pcall(function() slot:UpdateText() end)
        rewriting=false
        if not fine then error(e,0) end
        if again then return end
        c.rewritten,c.last_at=c.rewritten+1,now
        log(string.format('%s %d/%d',line and 'rewritten' or 'blanked',k,#c.t.windows))
        local h=holds and not c.holds_off and line and Subtitles.hold(line,length) or nil
        c.w={k=k,sb=shown,ours=line or '',until_at=now+length+(h or 0)}
        if h then c.hold={k=k,pause_at=now+length-Subtitles.EARLY,seconds=h} end
        if line and k==#c.lines and #c.lines<#c.t.windows then c.stop_at=now+length+(h or 0) end
        if not line then c.stop_at=c.stop_at or now end
    end
    -- The colour of a Lily or EVE line SB shows while a capture is armed (her goodbye after a pick).
    local function capture(slot)
        local shown=U.text(slot.author)
        for _,key in ipairs({'Seq_Actor_Lily','Seq_Actor_EVE'}) do
            if not colors[key] then
                local ok,name=pcall(function()
                    return U.text(U.find(TEXT_LIB):TextFromStringTable(FName(SEQ_TABLE),key))
                end)
                if ok and name==shown and name~='' then
                    local c=U.value_of(slot.AuthorColor)
                    colors[key]={R=c.R,G=c.G,B=c.B,A=c.A}
                    log('talk: '..key..' colour seen')
                end
            end
        end
    end
    local function on_update(ctx)
        if rewriting then return end
        local now=os.clock()
        calls,last_call=calls+1,now
        local c=cur
        if not c then
            if now<=capture_until then pcall(capture,U.valid(ctx)) end
            return
        end
        if c.failed and not c.late then -- Evidence for the guard: how late SB's first window came.
            c.late=true
            log(string.format('talk %s: SB\'s subtitle slot updated %.1f s after the observer showed, after the '
                ..'fallback',c.name,now-(c.seen_at or now)))
        end
        if c.step~='theater' and c.step~='sequence' then return end
        local ok,e=pcall(rewrite,c,U.valid(ctx))
        if not ok and not c.said then
            c.said=true
            log('STOP: talk '..c.name..': the rewrite failed ('..why(e)..')')
        end
    end
    -- The hook, once a Lua load: ok, or false and why.
    local function hook()
        if hooked then return true end
        local ok,e=pcall(RegisterHook,HOOK,on_update)
        if not ok then return false,why(e) end
        hooked=true
        log('hook: WB_Theater_Subtitle3_Slot_C:UpdateText registered')
        return true
    end
    -- After a pick, before the talk: the hook in place for her goodbye, and the colours it shows captured.
    function self.arm()
        local ok,e=hook()
        if not ok then return log('STOP: hook: '..e..' (tried again at the talk)') end
        capture_until=os.clock()+Subtitles.CAPTURE
    end
    -- name's talk (TALKS); kit: the kit version only. done(how) once it ends, maybe before play returns. Ok, message.
    function self.play(name,kit_only,done)
        if cur then return false,'a talk plays ('..cur.name..')' end
        local t,lines=Subtitles.TALKS[name],T.TALKS[name]
        if not t or not lines then return false,'no talk '..tostring(name) end
        local now=os.clock()
        cur={name=name,t=t,lines=lines,culture=culture(),k=0,w={k=0},rewritten=0,names={},done=done}
        local c=cur
        local known={}
        for key in pairs(colors) do known[#known+1]=key end
        table.sort(known)
        log(string.format('talk %s: %s, %d lines in %d windows, %s; holds %s; colours seen: %s',name,
            t.sequence:match('[^.]+$'),#lines,#t.windows,c.culture,holds and 'on' or 'off',
            known[1] and table.concat(known,', ') or 'none'))
        if kit_only then
            start_kit(now)
            return true,'talk '..name..': the kit version'
        end
        local ok,e=hook()
        if not ok then
            log('STOP: talk '..name..': the subtitle hook: '..e..': the kit version')
            start_kit(now)
            return true,'talk '..name..': the kit version (no hook)'
        end
        c.step,c.wait_until,c.poll_at='wait',now+Subtitles.WAIT,now
        wait(c,now)
        return true,'talk '..name..' asked: [LY] lines follow'
    end
    -- Each frame on the game thread (main.lua's loop): window 1's guard, the holds, the Stop after the last line, the
    -- kit's lines.
    function self.tick()
        local c=cur
        if not c then return end
        local now=os.clock()
        if c.step=='kit' then
            if now<c.next_at then return end
            c.line=c.line+1
            local key,line=Subtitles.entry(c.lines,c.line,c.culture)
            if not line then return finish('kit') end
            local name=U.text(speaker(c,key)):gsub('<[^>]*>','') -- Its rich-text tags off: a plain TextBlock.
            c.view.speaker.set(name)
            c.view.speaker.color(key=='Seq_Actor_Lily' and theme.teal or key=='Seq_Actor_EVE' and theme.text
                or theme.grey)
            c.view.line.set(line)
            local length=c.t.windows[c.line] or 3
            c.next_at=now+length+(holds and Subtitles.hold(line,length) or 0)
            return
        end
        if c.step=='wait' then return wait(c,now) end
        local first=c.t.first+Subtitles.FIRST
        if c.seen_at and c.rewritten==0 and not c.failed and now-c.seen_at>=first then
            c.failed=true
            log(string.format('STOP: talk %s: window 1 not rewritten %.2f s after the observer showed (%d UpdateText '
                ..'calls this Lua load%s)',c.name,first,calls,
                last_call and string.format(', the last %.1f s ago',now-last_call) or ''))
            if c.step=='theater' then return stop_row(c,'the Stop row, then the kit version') end
            return start_kit(now) -- No Stop for a sequence with no theater: SB's own lines go on under the kit's.
        end
        local h=c.hold
        if h and not h.paused and now>=h.pause_at then
            if play_player(c,'Pause') then
                h.paused,h.resume_at=now,now+h.seconds
                log(string.format('hold %d +%.2f s',h.k,h.seconds))
            else
                c.hold=nil
            end
        elseif h and h.paused and now>=h.resume_at then
            play_player(c,'Play')
            c.hold,c.watch=nil,{k=h.k,seconds=h.seconds,until_at=now+h.seconds+Subtitles.STUCK}
        end
        if c.watch and c.k~=c.watch.k then c.watch=nil end
        if c.watch and now>=c.watch.until_at then
            local w=c.watch
            c.watch=nil
            log(string.format('STOP: talk %s: no window after %d in %.2f s past its hold',c.name,w.k,
                w.seconds+Subtitles.STUCK))
            if c.step=='theater' then stop_row(c,'the Stop row') end
            return finish('failed')
        end
        if c.stop_at and now>=c.stop_at and c.step=='theater' then
            stop_row(c,'talk '..c.name..': the last line\'s window is over: the Stop row')
        end
    end
    -- coop lily hold on|off.
    function self.holds(on) holds=on end
    function self.holding() return holds end
    -- The talk under way's name, or nil.
    function self.playing() return cur and cur.name end
    -- A theater the game plays now (cut/scene.lua's busy: a walk of every object), or nil.
    function self.cutscene() return scene.busy() end
    -- The kit's group for the kit version: the speaker and the line at the bottom centre of the screen.
    function self.hud(h)
        kit,theme=h.kit,h.theme
        kit.add('talk',{x=320,y=1700,w=3200,h=240,pivot={X=0.5,Y=1}},function(b)
            return {speaker=b.text(1600,0,'','name',theme.teal,{X=0.5,Y=0}),
                line=b.text(1600,64,'','body',theme.text,{X=0.5,Y=0})}
        end)
    end
    -- coop off: the talk dropped with no done (cut/scene.lua's stop fires the Stop row), the kit's lines hidden.
    function self.stop()
        local c=cur
        if not c then return end
        cur=nil
        if c.hold and c.hold.paused then pcall(play_player,c,'Play') end
        if c.kit_on and kit then pcall(kit.show,'talk',false) end
        log('coop off: talk '..c.name..' dropped')
    end
    return self
end
return Subtitles
