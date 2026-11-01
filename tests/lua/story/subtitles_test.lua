-- Lily's talks (story/subtitles.lua) over fakes: UE4SS's RegisterHook (the callback kept, or a raise), the subtitle
-- slot (its Duration, author, Message, Type and AuthorColor; its UpdateText calls the hook again, as a post hook
-- would), the text library's StringTable_Seq names, the language, cut/scene.lua's talk side (talk, stop_talk, player,
-- busy) and the kit. Covered: the three talks' windows (21, 9, 19) and lines (17, 9, 19, in English and French, each
-- with a speaker key); the window of a call (the next, never skipped; the same again only with its text still in the
-- slot within its time); a blank entry past the lines; the reading holds of every window of the three talks in both
-- languages (need = 0.5 + characters / 15 against the window); the prologue through the theater: every window
-- rewritten (author from StringTable_Seq, '' for none, the French line, Type 0 for a long line, a captured colour),
-- the re-entry guard, a hold paused 0.15 s before its window's end and played after its length, windows 18 to 21 blank
-- and the Stop row once window 17 and its hold are over, then done; holds off; a skip during a hold; a Pause that
-- raises ending the holds; a sequence stuck after a hold stopped and failed; window 1 not rewritten in 1 s (the Stop
-- row, then the kit's lines, each for its window or reading time); the theater's own sequence or no theater, then
-- the sequence with no theater; a hook that cannot be registered, and no kit (none); coop off. A cutscene of the game
-- at the call: looked for every 0.5 s, the theater asked 0.5 s after it ended, or anyway after 20 s; a rewritten
-- window given as alive; a hold on the player scene.player() finds with no seen(); a talk refused because our own
-- sequence plays (theater or no theater) failed with no kit. The 2026-10-30 log: a Duration 0.035 s over each length
-- with repeated lengths, every one of the 17 lines once and in order, SB's or our text again not counted. After a map
-- change: window 1 later than 1 s after the observer rewritten; the guard from window 1's start plus 2 s, with the
-- hook's call count; a slot update after the fallback logged.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=0
os.clock=function() return clock end
local function at(t) clock=t end
FName=function(t) return {type=function() return 'FName' end,ToString=function() return t end} end
FText=function(s) return {type=function() return 'FText' end,ToString=function() return s end} end
local hook,hook_raise,hooks=nil,nil,0
RegisterHook=function(path,f)
    if hook_raise then error(hook_raise,0) end
    assert(path=='/Game/Art/UI/Widget/Theater/WB_Theater_Subtitle3_Slot.WB_Theater_Subtitle3_Slot_C:UpdateText',path)
    hooks=hooks+1
    hook=f
end
local function object(t)
    t.type=t.type or function() return 'UObject' end
    t.IsValid=t.IsValid or function() return true end
    return t
end
local NAMES={Seq_Actor_Lily='<Lily>Lily</>',Seq_Actor_EVE='<Eve>EVE</>',
    Seq_Actor_Announcement='<Announcement>Annonce</>'}
local table_reads,language=0,'fr-FR'
local objects={
    ['/Script/Engine.Default__KismetTextLibrary']=object({TextFromStringTable=function(_,id,key)
        assert(id:ToString()=='/Game/Local/Localize/StringTable_Seq.StringTable_Seq')
        table_reads=table_reads+1
        return FText(assert(NAMES[key],key))
    end}),
    ['/Script/Engine.Default__KismetInternationalizationLibrary']=object({
        GetCurrentLanguage=function() return language end}),
}
StaticFindObject=function(path) return objects[path] end
local S=require('story.subtitles')
local T=require('matrix13.quest.text')

-- The talks as data: windows, lines, speakers.
local COUNTS={prologue={21,17},arrival={9,9},finale={19,19}}
for name,n in pairs(COUNTS) do
    local t,lines=S.TALKS[name],T.TALKS[name]
    assert(#t.windows==n[1] and #lines==n[2],name)
    assert(t.sequence:find('^/Game/GameDesign/Level/Subtitle/StarsDescent/Tetrapod/Subtitle_POD_'),name)
    for k,e in ipairs(lines) do
        assert(NAMES[e[1]] or e[1]=='',name..k)
        assert(type(e[2])=='string' and e[2]~='' and type(e[3])=='string' and e[3]~='',name..k)
        assert(S.entry(lines,k,'fr')==e[1] and select(2,S.entry(lines,k,'fr'))==e[3]
            and select(2,S.entry(lines,k,'en'))==e[2])
    end
    assert(S.entry(lines,n[2]+1,'fr')==nil,'Past the lines: blank')
end
assert(S.TALKS.prologue.sequence:find('1stMeetAdam_01') and S.TALKS.arrival.sequence:find('ArriveDED_01')
    and S.TALKS.finale.sequence:find('1stMeetAdam_02'))
-- The window of a call: the next, never skipped; the same again only with its text still in the slot, in its time.
local W=S.TALKS.prologue.windows
assert(S.TALKS.prologue.first==0 and S.TALKS.arrival.first==0.68 and S.TALKS.finale.first==0.53,'Window 1 starts')
local w3={k=3,sb='SB 3',ours='Lily 3',until_at=10}
assert(S.window(W,{k=0},nil,0)==1 and S.window(W,{k=0},'x',0)==1,'The first')
assert(S.window(W,w3,'SB 4',5)==4 and S.window(W,w3,nil,5)==4,'Another text, or none read: the next')
assert(S.window(W,w3,'SB 3',5)==3 and S.window(W,w3,'Lily 3',9.99)==3,'Its text still in the slot: the same')
assert(S.window(W,w3,'SB 3',10)==4,'Past its time: the next, even with its text')
assert(S.window(W,{k=21,sb='a',ours='b',until_at=0},'c',1)==21,'Never past the last window')
-- The reading holds of every window, in both languages: 0.5 s plus 15 characters a second, past the window.
local HOLDS={ -- Talk, culture: window -> hold in s (2 decimals), as the lines of matrix13/quest/text.lua give them.
    prologue={en={[2]=1.19,[3]=0.53,[7]=0.11,[9]=0.36,[11]=0.11,[12]=1.80,[14]=0.22,[15]=1.89,[17]=0.91},
        fr={[1]=0.07,[2]=1.59,[7]=0.77,[9]=1.23,[11]=0.37,[12]=1.60,[14]=0.35,[15]=3.49,[17]=0.65}},
    arrival={en={[1]=0.44,[3]=0.71,[4]=1.93,[5]=2.19,[6]=0.18,[7]=0.75,[8]=0.55,[9]=0.86},
        fr={[1]=0.58,[3]=0.71,[4]=2.26,[5]=2.66,[6]=0.31,[7]=1.22,[8]=0.75,[9]=0.86}},
    finale={en={[1]=0.19,[2]=1.71,[7]=0.16,[9]=0.03,[11]=2.28,[12]=0.02,[13]=1.76,[15]=2.07,[17]=0.07,[19]=0.27},
        fr={[2]=1.64,[7]=0.89,[9]=0.96,[11]=2.88,[12]=0.08,[13]=1.83,[15]=2.01,[19]=0.40}},
}
for name,by in pairs(HOLDS) do
    for c,want in pairs(by) do
        for k,length in ipairs(S.TALKS[name].windows) do
            local _,line=S.entry(T.TALKS[name],k,c)
            local h=line and S.hold(line,length)
            local need=line and 0.5+utf8.len(line)/15
            assert((h~=nil)==(want[k]~=nil),name..' '..c..' window '..k..': '..tostring(h))
            assert(not h or math.abs(h-(need-length))<1e-9 and string.format('%.2f',h)==string.format('%.2f',want[k]),
                name..' '..c..' '..k)
        end
    end
end
assert(S.hold('Go.',2)==nil and math.abs(S.hold(('x'):rep(45),2)-1.5)<1e-9,'0.5 + 45/15 = 3.5 s for a 2 s window')
assert(math.abs(S.hold('Je t\'écoute, d\'accord.',1)-(0.5+22/15-1))<1e-9,'Characters, not bytes')

-- The fakes of the player: cut/scene.lua's talk side, the sequence player, the kit and the slot.
local logs={}
local function last() return logs[#logs] end
local function logged(text) for _,l in ipairs(logs) do if l:find(text,1,true) then return l end end end
local talks,stops,busy={},0,nil
local player={pauses=0,plays=0}
function player.Pause(self) if self.pause_raise then error(self.pause_raise) end self.pauses=self.pauses+1 end
function player.Play(self) self.plays=self.plays+1 end
local player_seen=nil -- The player scene.player() gives (nil before the observer is seen).
local scene={talk=function(seq,o) talks[#talks+1]={seq=seq,o=o}; return true,'asked' end,
    stop_talk=function() stops=stops+1; return true,'stop asked' end,player=function() return player_seen end,
    busy=function() return busy end}
local shown,view={},nil
local kit_up=true
local function text_view()
    local v={text='',col=nil}
    v.set=function(s) v.text=s end
    v.color=function(c) v.col=c end
    v.show=function() end
    return v
end
local kit={add=function(name,place,build)
        assert(name=='talk' and place.pivot.X==0.5)
        view=build({text=function() return text_view() end})
    end,
    view=function(name) return kit_up and name=='talk' and view or nil end,
    show=function(name,on) shown[name]=on end}
local THEME={teal='teal',text='white',grey='grey'}
local slot=object({Duration=0,author=FText('Adam'),Message=FText('...'),Type=1,AuthorColor={R=1,G=1,B=1,A=1},updates=0})
function slot.UpdateText(self) self.updates=self.updates+1; hook(self) end -- The hook runs again: guarded.
local serial=0 -- Each new window: SB's own text for it in the slot, as SB sets it before UpdateText.
local function window(d)
    serial=serial+1
    slot.Duration,slot.Message,slot.updates=d,FText('SB line '..serial),0
    hook(slot)
    assert(slot.updates==1,'One re-call')
end
local done=nil
local function finished(how) done=how end
local P=S.new({log=function(m) logs[#logs+1]=m end,scene=scene})
P.hud({kit=kit,theme=THEME})
assert(view and view.speaker and view.line,'The kit group')

-- A capture after a pick: Lily's colour from her goodbye; then nothing outside a talk or a capture.
at(10)
P.arm()
assert(hooks==1 and logged('hook: WB_Theater_Subtitle3_Slot_C:UpdateText registered'))
slot.author,slot.AuthorColor=FText('<Lily>Lily</>'),{R=0.2,G=0.8,B=0.6,A=1}
hook(slot)
assert(last()=='talk: Seq_Actor_Lily colour seen',last())
at(50)
table_reads=0
slot.author=FText('<Eve>EVE</>'); hook(slot)
assert(table_reads==0,'Outside a talk and a capture: no read')
slot.AuthorColor={R=1,G=1,B=1,A=1}

-- The prologue through the theater, in French: every window rewritten, holds, blank windows, the Stop row.
at(100)
local ok,why=P.play('prologue',false,finished)
assert(ok and why=='talk prologue asked: [LY] lines follow' and #talks==1 and talks[1].seq==S.TALKS.prologue.sequence
    and not talks[1].o.direct and hooks==1,why)
assert(logged('talk prologue: Subtitle_POD_1stMeetAdam_01, 17 lines in 21 windows, fr; holds on; colours seen: '
    ..'Seq_Actor_Lily'))
assert(P.playing()=='prologue' and select(1,P.play('arrival',false,finished))==false,'One talk at a time')
talks[1].o.seen()
player_seen=player
local prologue_fr=HOLDS.prologue.fr
local t=100
for k=1,17 do
    local length=W[k]
    window(length)
    local _,line=S.entry(T.TALKS.prologue,k,'fr')
    assert(slot.Message:ToString()==line and slot.author:ToString()==NAMES[T.TALKS.prologue[k][1]],k)
    assert(last()=='rewritten '..k..'/21',last())
    assert((slot.Type==0)==(utf8.len(line)/15>length),'Type 0 for a long line only: '..k)
    slot.Type=1
    if T.TALKS.prologue[k][1]=='Seq_Actor_Lily' then assert(slot.AuthorColor.G==0.8,'Her colour') end
    slot.AuthorColor={R=1,G=1,B=1,A=1}
    local h=prologue_fr[k] and S.hold(line,length) -- The table's two decimals, exact for the times.
    if h then
        at(t+length-0.16); P.tick(); assert(player.pauses==0,'Not yet')
        at(t+length-0.15); P.tick()
        assert(player.pauses==1 and last()==string.format('hold %d +%.2f s',k,prologue_fr[k]),tostring(last()))
        at(t+length-0.15+h-0.01); P.tick(); assert(player.plays==0,'Held')
        at(t+length-0.15+h+0.001); P.tick(); assert(player.plays==1,'Played again')
        player.pauses,player.plays=0,0
        t=t+h
    end
    if k<17 then t=t+length+0.5; at(t); P.tick() end
end
assert(stops==0,'No Stop before window 17 is over')
at(t+W[17]-0.01); P.tick(); assert(stops==0) -- t already holds window 17's hold.
at(t+W[17]); P.tick()
assert(stops==1 and last()=="talk prologue: the last line's window is over: the Stop row: stop asked",last())
P.tick(); assert(stops==1,'Once')
window(0.92) -- Window 18 shows before the theater stops: blank.
assert(slot.Message:ToString()=='' and slot.author:ToString()=='' and last()=='blanked 18/21',last())
talks[1].o.done(true,"Lily's talk stopped after 68 s.",{seen=true,own=false})
assert(done=='theater' and P.playing()==nil and last()=='talk prologue: theater (18 windows rewritten)',last())
table_reads=0
slot.Message,slot.updates=FText('...'),0
hook(slot)
assert(slot.Message:ToString()=='...' and table_reads==0 and slot.updates==0,'After the talk: SB\'s lines untouched')

-- Holds off; English; a skip during a hold; a Pause that raises; a stuck sequence after a hold.
P.holds(false)
language='en-US'
talks,done,player_seen={},nil,player
at(200); assert(P.play('arrival',false,finished))
assert(logged('talk arrival: Subtitle_POD_ArriveDED_01, 9 lines in 9 windows, en; holds off'))
window(2.59)
assert(slot.Message:ToString()==T.TALKS.arrival[1][2],'English')
at(210); P.tick(); assert(player.pauses==0,'Holds off: no pause')
P.holds(true)
window(2.27) -- Window 2 needs no hold; window 4 does.
window(2.06)
at(220); window(2.24)
at(222.1); P.tick(); assert(player.pauses==1 and last()=='hold 4 +1.93 s',last())
window(1.64) -- A skip to window 5 during the hold: played again at once.
assert(player.plays==1 and logged('hold 4 cancelled: window 5 showed'),last())
at(230); P.tick(); assert(player.plays==1,'No second Play for that hold')
player.pause_raise='no Pause'
at(230); window(4.32) -- Window 6 holds 0.18 s: its Pause raises, and holds stop for the talk.
at(234.2); P.tick()
assert(logged('STOP: hold: Pause failed (') and logged('no more holds this talk'),last())
player.pause_raise=nil
local pauses=player.pauses
at(240); window(3.15); at(243.1); P.tick(); assert(player.pauses==pauses,'No more holds')
talks[1].o.done(true,'ended',{seen=true})
assert(done=='theater')
-- A sequence that does not move on after its hold: the Stop row, the talk failed.
talks,done,stops={},nil,0
player.pauses,player.plays=0,0
at(300); assert(P.play('arrival',false,finished))
talks[1].o.seen()
window(2.59)
at(302.44); P.tick(); assert(player.pauses==1)
at(302.89); P.tick(); assert(player.plays==1)
at(305.32); P.tick(); assert(stops==0 and done==nil,'Within the hold and 2 s')
at(305.34); P.tick()
assert(stops==1 and done=='failed' and logged('STOP: talk arrival: no window after 1 in 2.44 s past its hold'),last())
talks[1].o.done(true,'stopped',{seen=true}) -- Scene's end after: nothing more.
assert(done=='failed')

-- Window 1 not rewritten 2 s past its start (0.53 s) after the observer showed: the Stop row, then the kit's lines.
talks,done,stops={},nil,0
language='fr-FR'
at(400); assert(P.play('finale',false,finished))
talks[1].o.seen()
at(402.52); P.tick(); assert(stops==0)
at(402.54); P.tick()
local said=logged('STOP: talk finale: window 1 not rewritten 2.53 s after the observer showed (')
assert(stops==1 and said and said:find(' UpdateText calls this Lua load, the last ',1,true),last())
talks[1].o.done(true,'stopped',{seen=true})
assert(shown.talk==true and last()=='talk finale: the kit version',last())
P.tick()
assert(view.speaker.text=='Lily' and view.speaker.col=='teal' and view.line.text==T.TALKS.finale[1][3],view.line.text)
local F=S.TALKS.finale.windows
local function more(k) local _,line=S.entry(T.TALKS.finale,k,'fr'); return S.hold(line,F[k]) or 0 end
at(402.54+F[1]-0.01); P.tick()
assert(view.line.text==T.TALKS.finale[1][3],'Line 1 for its window (no hold in French)')
local tk=402.54+F[1]
at(tk); P.tick(); assert(view.line.text==T.TALKS.finale[2][3] and view.speaker.text=='Lily')
tk=tk+F[2]+more(2)
at(tk-0.01); P.tick(); assert(view.line.text==T.TALKS.finale[2][3],'Line 2 for its reading time')
at(tk); P.tick(); assert(view.line.text==T.TALKS.finale[3][3])
for k=3,19 do tk=tk+F[k]+more(k); at(tk); P.tick() end
assert(done=='kit' and shown.talk==false and P.playing()==nil,tostring(done))
-- The kit version by hand (coop lily talk ... kit): no theater asked.
talks,done={},nil
at(500); ok,why=P.play('arrival',true,finished)
assert(ok and why=='talk arrival: the kit version' and #talks==0 and shown.talk==true)
P.tick(); assert(view.speaker.text=='EVE' and view.speaker.col=='white')
P.stop()
assert(shown.talk==false and P.playing()==nil and done==nil and last()=='coop off: talk arrival dropped',last())

-- The theater's own sequence, then the sequence with no theater (windows counted again); no theater seen there: kit.
talks,done,stops={},nil,0
at(600); assert(P.play('prologue',false,finished))
talks[1].o.seen()
window(2.10) -- Quinn's own line rewritten for a moment.
talks[1].o.done(false,"Lily's talk: its theater's own sequence played; stopped",{seen=true,own=true})
assert(#talks==2 and talks[2].o.direct and logged('the sequence with no theater next'),last())
talks[2].o.seen()
window(2.10)
assert(last()=='rewritten 1/21','Counted from window 1 again')
for k=2,21 do window(W[k]) end
assert(last()=='blanked 21/21' and stops==0,'No Stop with no theater: the sequence runs to its end')
talks[2].o.done(true,'ended',{seen=true})
assert(done=='sequence',tostring(done))
talks,done={},nil
at(700); assert(P.play('finale',false,finished))
talks[1].o.done(false,'no theater played in 10 s',{seen=false})
talks[2].o.done(false,'no theater played in 10 s',{seen=false})
assert(done==nil and shown.talk==true and logged('STOP: talk finale: no theater played in 10 s: the kit version next'))
P.stop()
-- A theater refused at once: the sequence with no theater at once.
scene.talk=function(seq,o)
    talks[#talks+1]={seq=seq,o=o}
    if not o.direct then return false,'a cutscene of the game plays (X): nothing was changed' end
    return true,'asked'
end
talks,done={},nil
at(800); assert(P.play('arrival',false,finished))
assert(#talks==2 and talks[2].o.direct and logged('STOP: talk arrival: the theater: a cutscene of the game plays'))
P.stop()
-- A cutscene of the game plays at the call (her goodbye): looked for every 0.5 s, the theater asked once it ended.
scene.talk=function(seq,o) talks[#talks+1]={seq=seq,o=o}; return true,'asked' end
local looks=0
scene.busy=function() looks=looks+1; return busy end
busy='Subtitle_NPC_Start_WLBXionP5_8DF9E0F244F00B5FB379A5938C796E0C'
talks,done,logs={},nil,{}
at(1000); assert(P.play('prologue',false,finished))
assert(#talks==0 and looks==1 and last()=='talk prologue: waits up to 20 s for a cutscene of the game to end '
    ..'(Subtitle_NPC_Start_WLBXionP5_8DF9E0F244F00B5FB379A5938C796E0C)',last())
at(1000.4); P.tick(); assert(looks==1,'Not before 0.5 s')
at(1000.5); P.tick(); assert(looks==2 and #talks==0)
for k=1,4 do at(1000.5+k*0.5); P.tick() end
assert(looks==6 and #talks==0 and #logs==2,'Said once')
busy=nil
at(1003.5); P.tick()
assert(#talks==0 and last()=='talk prologue: the cutscene ended after 3.5 s: the theater in 0.5 s',last())
at(1003.9); P.tick(); assert(#talks==0,'Not before 0.5 s')
at(1004); P.tick(); assert(#talks==1 and not talks[1].o.direct and looks==8,'Asked after one more clear look')
-- A window rewritten is the proof scene.lua reads (alive); the hold's player is the one scene.player() finds when
-- asked, the observer never seen by tick.
assert(talks[1].o.alive()==nil,'Nothing rewritten yet')
local asked=0
scene.player=function() asked=asked+1; return player end
player.pauses,player.plays=0,0
at(1004.5); window(2.10)
assert(talks[1].o.alive()==1004.5 and last()=='rewritten 1/21',last())
at(1004.5+2.10-0.15); P.tick()
assert(asked==1 and player.pauses==1 and logged('hold 1 +0.07 s'),last())
at(1004.5+2.10-0.15+0.08); P.tick(); assert(asked==2 and player.plays==1)
P.stop()
-- Still playing after 20 s: the theater asked anyway, and the fallbacks as before.
busy='Subtitle_NPC_Start_WLBXionP5_8DF9E0F244F00B5FB379A5938C796E0C'
talks,done={},nil
at(1100); assert(P.play('arrival',false,finished))
for k=1,39 do at(1100+k*0.5); P.tick() end
assert(#talks==0,'Waiting')
at(1120); P.tick()
assert(#talks==1 and logged('STOP: talk arrival: Subtitle_NPC_Start_WLBXionP5_8DF9E0F244F00B5FB379A5938C796E0C still '
    ..'plays after 20 s: the theater asked anyway'),last())
P.stop()
busy=nil
-- Refused because our own sequence still plays: no sequence with no theater, no kit; failed.
scene.talk=function(seq,o)
    talks[#talks+1]={seq=seq,o=o}
    return false,'our own Subtitle_POD_ArriveDED_01_566E86D244A289A148AA1CAA771CC6E5 still plays: nothing was changed',
        true
end
talks,done,shown.talk={},nil,nil
at(1200); assert(P.play('arrival',false,finished))
assert(#talks==1 and done=='failed' and shown.talk==nil and P.playing()==nil and logged('STOP: talk arrival: the '
    ..'theater: our own Subtitle_POD_ArriveDED_01_566E86D244A289A148AA1CAA771CC6E5 still plays: nothing was changed: '
    ..'no fallback while our own sequence plays'),last())
scene.talk=function(seq,o) talks[#talks+1]={seq=seq,o=o}; return true,'asked' end
talks,done,shown.talk={},nil,nil
at(1300); assert(P.play('arrival',false,finished))
scene.talk=function(seq,o) talks[#talks+1]={seq=seq,o=o}; return false,'our own X still plays',true end
talks[1].o.done(false,'no theater played in 10 s',{seen=false}) -- The sequence step, refused the same way.
assert(#talks==2 and talks[2].o.direct and done=='failed' and shown.talk==nil
    and last()=='talk arrival: failed (0 windows rewritten)' and logged('STOP: talk arrival: the sequence with no '
    ..'theater: our own X still plays: no fallback while our own sequence plays'),last())
scene.talk=function(seq,o) talks[#talks+1]={seq=seq,o=o}; return true,'asked' end

-- The 2026-10-30 log: SB's Duration is each window's length plus 0.035 s (then window 4 was taken for 6, window 5
-- for 13); no window is skipped for it. A call with the window's text still in the slot (ours, or SB's again) is the
-- same window: every one of the 17 lines shows once, in order.
P.holds(false)
talks,done,stops,logs={},nil,0,{}
at(2000); assert(P.play('prologue',false,finished))
talks[1].o.seen()
local tt=2000
for k=1,17 do
    at(tt); window(W[k]+0.035)
    local _,line=S.entry(T.TALKS.prologue,k,'fr')
    assert(last()=='rewritten '..k..'/21' and slot.Message:ToString()==line,last())
    local n=#logs
    at(tt+0.2); slot.updates=0; hook(slot) -- Our line still in the slot: the same window, written again.
    assert(#logs==n and slot.Message:ToString()==line and slot.updates==1,'Ours again: '..k)
    at(tt+0.3); slot.Message=FText('SB line '..serial); hook(slot) -- SB's text for it again.
    assert(#logs==n and slot.Message:ToString()==line,'SB again: '..k)
    tt=tt+W[k]+0.5
end
local rewritten=0
for _,l in ipairs(logs) do if l:find('^rewritten ') then rewritten=rewritten+1 end end
assert(rewritten==17,'17 lines, each once')
P.stop()
P.holds(true)
-- After a map change (the arrival in a world just loaded), on a new Lua load: window 1 more than 1 s after the
-- observer showed is still rewritten; the guard waits for window 1's start (0.68 s) plus 2 s and says how many
-- UpdateText calls came; a slot update after the fallback is logged (and rewritten while the Stop runs).
local R=S.new({log=function(m) logs[#logs+1]=m end,scene=scene})
R.hud({kit=kit,theme=THEME})
talks,done,stops,logs={},nil,0,{}
at(3000); assert(R.play('arrival',false,finished))
talks[1].o.seen()
at(3001.5); R.tick(); assert(stops==0,'Not at 1 s')
at(3002.6); window(2.59+0.035); assert(last()=='rewritten 1/9',last())
at(3003); R.tick(); assert(stops==0 and not logged('not rewritten'))
R.stop()
talks,done,stops={},nil,0
at(3100); assert(R.play('arrival',false,finished))
talks[1].o.seen()
at(3102.67); R.tick(); assert(stops==0,'Within 2.68 s')
at(3102.69); R.tick()
assert(stops==1 and last()=='the Stop row, then the kit version: stop asked' and logged('STOP: talk arrival: window 1 '
    ..'not rewritten 2.68 s after the observer showed (1 UpdateText calls this Lua load, the last 100.1 s ago)'),last())
at(3103.5); window(2.59)
assert(logged("talk arrival: SB's subtitle slot updated 3.5 s after the observer showed, after the fallback")
    and last()=='rewritten 1/9',last())
talks[1].o.done(true,'stopped',{seen=true})
assert(last()=='talk arrival: the kit version',last())
R.stop()

-- A hook that cannot be registered, on a new Lua load: the kit version; no kit up: no talk (none), done at once.
hook_raise='no UFunction'
local Q=S.new({log=function(m) logs[#logs+1]=m end,scene=scene})
Q.hud({kit=kit,theme=THEME})
talks,done={},nil
at(900); ok,why=Q.play('prologue',false,finished)
assert(ok and why=='talk prologue: the kit version (no hook)' and #talks==0
    and logged('the subtitle hook: no UFunction'))
Q.stop()
kit_up=false
ok,why=Q.play('arrival',true,finished)
assert(ok and done=='none' and logged('STOP: talk arrival: the kit is not up: no talk; the quest goes on'))
assert(Q.play('nothing',false,finished)==false)
busy='DED_Area01'
assert(Q.cutscene()=='DED_Area01')
print('subtitles_test: ok')
