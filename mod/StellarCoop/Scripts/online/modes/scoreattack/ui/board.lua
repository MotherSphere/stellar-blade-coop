-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Score attack's screens on the Uplink kit (ui/kit/kit.lua), at the top centre where Night Operation's card goes: the
-- card (the challenge's name over its countdown, wave, time left and score, as online/modes/nightop/run.lua's card
-- shows a challenge), the in-round board under it (one row per round player, best score first, ours in teal) and, in
-- their place once our run ends or the ranking comes, the result panel (the challenge, our end, score and time, a note,
-- then the ranking with each player's difficulty). It closes at the round's end line, or SHOW seconds after the
-- ranking. All hidden while the game is paused or shows one of its screens. With the kit off or absent, the start, each
-- wave, our run's end (with the record line when it wrote a new best) and our place come as notices, as the solo run's
-- do. A round that ends without a ranking says
-- why as a notice either way. Its words follow the game's language unless ui_language=english.
-- tests/lua/online/modes/scoreattack/board_test.lua covers it on a fake kit.
local T=require('ui.text')
local Join=require('core.line')
local Board={}
-- Kit layout units (3840 by 2160): the card as Night Operation's (1040 wide, clear of the chat's feed), the board's
-- rows under it, the result panel in their place (a heading, two lines, then the ranking's rows).
local HUD_W,CARD_H,HUD_Y=1040,160,96
local ROW_H,ROWS,GAP=52,8,12
local RESULT_H=720
local SHOW=20 -- Seconds the result panel stays after the ranking when no end line comes (DESIGN section 6).
local MIDDLE,LEFT,RIGHT={X=0.5,Y=0.5},{X=0,Y=0.5},{X=1,Y=0.5}
local GROUPS={'scoreattack','scoreattack_board','scoreattack_result'}
-- core/link.lua's cycles: 0 Normal, 1 Story, 2 Hard (ui/text.lua's cycle), the values of SB's ESBGameDifficultyType
-- (its name table at 0x145e30ab0: NormalMode 0, StoryMode 1, HardMode 2).
local LEVEL={[0]='normal','story','hard'}
local function clock_text(seconds) return string.format('%d:%02d',seconds//60,seconds%60) end
-- A run time in tenths as the panel shows it: 1:12.3.
function Board.time(tenths) return string.format('%d:%02d.%d',tenths//600,tenths//10%60,tenths%10) end
-- The card's title and line for the run's state s at game time now, in words w: the challenge's name, then the
-- countdown, then the wave or, once it is down, the next one's countdown, each with the run time left and the score.
-- online/modes/nightop/run.lua's Run.card for a challenge, without the co-op wait and the revive.
function Board.card(s,now,w)
    local n=w.night
    local title=w.challenge.names[s.def.id]
    if s.phase=='countdown' then return title,n.starts:format(math.max(0,math.ceil(s.t0-now))) end
    local rt=now-s.t0
    local wait=s.phase=='breather' and s.next_at and math.ceil(s.next_at-rt)
    local head=wait and wait>0 and n.next:format(wait) or n.wave:format(s.wave,#s.def.waves)
    return title,head..'  '..clock_text(math.max(0,math.ceil(s.def.limit-rt)))..'  '..n.score:format(s.score)
end
-- The in-round board of round cur (online/modes/scoreattack/round.lua's) in words w: one {place=, id=, score=,
-- status=} per round player, best score first (equal scores share a place, in the round's order); status is her end
-- word once her run ended, else her wave once one came, else ''.
function Board.standings(cur,w)
    local sa,list=w.scoreattack,{}
    for k,id in ipairs(cur.ids) do
        local b=cur.board[id] or {}
        local status=''
        if b.ending then status=sa.ending[b.ending] or b.ending
        elseif b.wave and cur.def then status=sa.wave:format(b.wave,#cur.def.waves) end
        list[#list+1]={id=id,k=k,score=b.score or 0,status=status}
    end
    table.sort(list,function(a,c) if a.score~=c.score then return a.score>c.score end return a.k<c.k end)
    for i,e in ipairs(list) do e.place=i>1 and list[i-1].score==e.score and list[i-1].place or i end
    return list
end
-- The result panel of round cur in words w: its heading (the challenge's name), the line under it (our end, score and
-- time once our run ended, else ''), the note (Not ranked. once a ranking without us came, the results still to come
-- before it, else the record line when our run wrote a new best) and one {label=, level=, value=, ours=} per ranked
-- player. name(id): her name as shown; level(id): her difficulty (0 to 2) or nil; best: our run's best ({new=true} when
-- this run wrote it) or nil.
function Board.result(cur,w,name,level,best)
    local sa=w.scoreattack
    local mine=cur.board[cur.me] or {}
    local sub=mine.ending and sa.mine:format(sa.ending[mine.ending] or mine.ending,mine.score or 0,
        Board.time(mine.tenths or 0)) or ''
    local rows,placed,left={},false,0
    for i,r in ipairs(cur.list or {}) do
        placed=placed or r.id==cur.me
        local d=level(r.id)
        rows[i]={label=r.place..'  '..name(r.id),level=d and LEVEL[d] and w.cycle[LEVEL[d]] or '',
            value=r.score..'  '..Board.time(r.tenths),ours=r.id==cur.me}
    end
    for _,id in ipairs(cur.ids) do
        local b=cur.board[id]
        if b and b.ready and not b.ending then left=left+1 end
    end
    local note=''
    if cur.list and not placed then note=sa.unranked
    elseif not cur.list and left>0 then note=sa.waiting:format(left)
    elseif best and best.new then note=w.challenge.record end
    return w.challenge.names[cur.def.id],sub,note,rows
end
-- o: round() (round.lua's round(): our round, or nil), run() (run.lua's state(): s, now and best, or nil), name(id)
-- (her Steam name, ours for our SteamID), level(id) (her difficulty 0 to 2, or nil), tell(build) (main.lua's notice:
-- build(words) gives its text), clock() (seconds), log(line).
function Board.new(o)
    local self={}
    local hud=nil -- self.hud's {kit, theme, settings}; nil without one, or after a HUD error.
    -- seen: what this round showed or said {n=, said={key=true}, best=, ranked_at=}.
    local seen=nil
    local picked,lang,words=nil,nil,nil
    local function shown() return hud~=nil and not hud.kit.off() end
    local function name(id) return Join.name(o.name(id)) or id end
    -- A notice once a round: always (why), or only while the kit cannot show it (what the HUD shows).
    local function once(key,always,build)
        if seen.said[key] then return end
        seen.said[key]=true
        if (always or not shown()) and o.tell then o.tell(build) end
    end
    local function hide() for _,g in ipairs(GROUPS) do hud.kit.show(g,false) end end
    local function draw(cur,s,now,playing,result)
        local kit=hud.kit
        local away=kit.paused()
        local card,board,res=kit.view('scoreattack'),kit.view('scoreattack_board'),kit.view('scoreattack_result')
        kit.show('scoreattack',playing and not away)
        kit.show('scoreattack_board',playing and not away)
        kit.show('scoreattack_result',result and not playing and not away)
        if card and (card~=picked or hud.settings.ui_language~=lang) then
            picked,lang=card,hud.settings.ui_language
            words=T.pick(kit.language(),lang)
        end
        local w=words or T.en
        if playing and card and board then
            local title,line=Board.card(s,now,w)
            card.title.set(title)
            card.line.set(line)
            local list=Board.standings(cur,w)
            for i,row in ipairs(board.rows) do
                local e=list[i]
                row.back.show(e~=nil)
                row.label.set(e and e.place..'  '..name(e.id) or '')
                row.value.set(e and e.score..(e.status~='' and '  '..e.status or '') or '')
                local c=e and e.id==cur.me and hud.theme.teal or hud.theme.text
                row.label.color(c)
                row.value.color(c)
            end
        end
        if result and not playing and res then
            local head,sub,note,rows=Board.result(cur,w,name,o.level,seen.best)
            local mine=cur.board[cur.me] or {}
            res.head.set(head)
            res.head.color(mine.ending=='win' and hud.theme.teal or hud.theme.warn)
            res.sub.set(sub)
            res.note.set(note)
            for i,row in ipairs(res.rows) do
                local e=rows[i]
                row.label.set(e and e.label or '')
                row.level.set(e and e.level or '')
                row.value.set(e and e.value or '')
                local c=e and e.ours and hud.theme.teal or hud.theme.text
                row.label.color(c)
                row.value.color(c)
            end
        end
    end
    local function step()
        local cur=o.round()
        if not cur then
            if hud then hide() end
            return
        end
        if not seen or seen.n~=cur.n then seen={n=cur.n,said={}} end
        local s,now,best=nil,nil,nil
        if o.run then s,now,best=o.run() end
        local mine=cur.board[cur.me] or {}
        -- Our run plays this round: it sent its ready, not its done, and is not in its result.
        local playing=cur.def~=nil and cur.phase~='over' and mine.ready==true and not mine.ending and s~=nil
            and s.phase~='result' and s.phase~='idle'
        if mine.ending and not seen.ended then seen.ended,seen.best=true,best end -- The run's best, read at its end.
        if cur.list and not seen.ranked_at then seen.ranked_at=o.clock() end
        local result=cur.def~=nil and (mine.ending~=nil or cur.list~=nil) and cur.phase~='over'
            and not (seen.ranked_at and o.clock()-seen.ranked_at>=SHOW)
        if cur.phase=='over' and not cur.list then -- A round that ends without a ranking says why.
            if cur.why=='host_left' or cur.why=='host_lost' then
                once('why',true,function(w) return w.scoreattack.host_left end)
            elseif cur.why=='host' or cur.why=='void' then
                once('why',true,function(w) return w.scoreattack.cancelled end)
            end
        end
        if playing then
            local title=function(w) return w.challenge.names[s.def.id] end
            once('start',false,function(w)
                return w.challenge.start_notice:format(title(w),math.max(0,math.ceil(s.t0-now)))
            end)
            if s.wave>0 then
                once('wave'..s.wave,false,function(w)
                    return w.challenge.wave_notice:format(title(w),s.wave,#s.def.waves)
                end)
            end
        end
        if mine.ending and cur.def then
            once('end',false,function(w)
                return w.scoreattack.end_notice:format(w.challenge.names[cur.def.id],
                    w.scoreattack.ending[mine.ending] or mine.ending,mine.score or 0,Board.time(mine.tenths or 0))
            end)
            -- The record line after it, as the solo run's notices give it.
            if seen.best and seen.best.new then once('record',false,function(w) return w.challenge.record end) end
        end
        if cur.list and cur.def then
            once('rank',false,function(w)
                for _,r in ipairs(cur.list) do
                    if r.id==cur.me then return w.scoreattack.placed:format(r.place,#cur.list) end
                end
                return w.scoreattack.unranked
            end)
        end
        if not shown() then return end
        draw(cur,s,now,playing,result)
    end
    -- Every 250 ms, after the round's pass and our run's: the notices, then the HUD. An error in the HUD gives one STOP
    -- line and notices from then on.
    function self.tick()
        local ok,e=pcall(step)
        if ok then return end
        o.log('STOP: HUD: '..tostring(e))
        if hud then pcall(hide) end
        hud=nil
    end
    -- coop off (or any stop): every group hidden now, as no tick may come after it to hide them.
    function self.stop() if hud then pcall(hide) end end
    -- The groups on the Uplink kit, before its first build (main/ui.lua's hud step, after Night Operation's): h is
    -- {kit, theme=ui.THEME, settings= (main.lua's, ui_language read at each update)}.
    function self.hud(h)
        hud=h
        local kit,theme=h.kit,h.theme
        local x=(3840-HUD_W)/2
        kit.add('scoreattack',{x=x,y=HUD_Y,w=HUD_W,h=CARD_H,pivot={X=0.5,Y=0}},function(b)
            b.panel(0,0,HUD_W,CARD_H)
            return {title=b.text(HUD_W/2,48,'','name',theme.warn,MIDDLE),
                line=b.text(HUD_W/2,104,'','item',theme.text,MIDDLE)}
        end)
        -- Each row on its own glass, shown with its player: the board is as tall as the round has players.
        kit.add('scoreattack_board',{x=x,y=HUD_Y+CARD_H+GAP,w=HUD_W,h=ROWS*ROW_H,pivot={X=0.5,Y=0}},function(b)
            local v={rows={}}
            for i=1,ROWS do
                local y=(i-1)*ROW_H
                v.rows[i]={back=b.image(0,y,HUD_W,ROW_H-4,nil,theme.panel),
                    label=b.text(64,y+ROW_H/2-2,'','body',theme.text,LEFT),
                    value=b.text(HUD_W-64,y+ROW_H/2-2,'','body',theme.text,RIGHT)}
            end
            return v
        end)
        kit.add('scoreattack_result',{x=x,y=HUD_Y,w=HUD_W,h=RESULT_H,pivot={X=0.5,Y=0}},function(b)
            b.panel(0,0,HUD_W,RESULT_H)
            local v={head=b.text(HUD_W/2,70,'','title',theme.teal,MIDDLE),
                sub=b.text(HUD_W/2,136,'','body',theme.text,MIDDLE),
                note=b.text(HUD_W/2,186,'','body',theme.grey,MIDDLE),rows={}}
            for i=1,ROWS do
                local y=250+(i-1)*56
                v.rows[i]={label=b.text(64,y,'','body',theme.text,LEFT),
                    level=b.text(660,y,'','status',theme.grey,RIGHT),
                    value=b.text(HUD_W-64,y,'','item',theme.text,RIGHT)}
            end
            return v
        end)
    end
    return self
end
return Board
