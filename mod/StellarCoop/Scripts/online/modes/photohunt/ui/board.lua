-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The photo hunt's screens on the Uplink kit (ui/kit/kit.lua), in the fishing tournament's places
-- (online/modes/fishing/ui/board.lua): the card at the top right, clear of the partner card, the feed and the chat box
-- at the top left (its title line: PHOTO HUNT, then the countdown, the time left or Time up; under it one row a target,
-- its name then open, you in teal or the taker's name; a last line with our points and place) and, from our end, the
-- result panel at the top centre in score attack's layout (online/modes/scoreattack/ui/board.lua: the heading, our
-- points, a note, then one row per ranked player with the time of her last point). The panel closes SHOW seconds after
-- the ranking or after the note that none came. Both are hidden while the game is paused or shows one of its screens;
-- the kit's root is hidden in our photo and selfie modes (main/pass.lua). The card is hidden on the title screen too,
-- where the co-op saves' badge (online/saves/saves.lua) takes the same place. The round's notices (the start with the
-- Camera's, a sit-out, a reloaded game, photo checks that stopped), each target taken and why a photo hunt ends with no
-- ranking come as notices whatever the kit shows. A shot's words for a drawn target (game.lua's feedback) wait in a
-- queue until our selfie mode closes, one a target a selfie session: counts over taken over yours over close. With the
-- kit off or absent, GO, our end, the first three, our place and a new personal best come as notices too. Its words
-- follow the game's language unless ui_language=english.
-- tests/lua/online/modes/photohunt/board_test.lua covers it on a fake kit.
local T=require('ui.text')
local Join=require('core.line')
local Ph=require('online.modes.photohunt.model')
local Tg=require('online.modes.photohunt.targets')
local Board={}
-- Kit layout units (3840 by 2160): the fishing tournament's corner board (its title glass over four rows, 96 in from
-- the top right) and result panel (1040 wide, a heading, two lines, then the ranking's rows).
local SIDE,TOP=96,96
local CORNER_W,TITLE_H,ROW_H,CORNER_ROWS,GAP=720,96,52,4,12
local HUD_W,RESULT_H,RANK_ROWS=1040,720,8
local SHOW=20 -- Seconds the result panel stays after the ranking or the no-ranking note (DESIGN section 2, step 7).
local TOP_THREE=3
local MIDDLE,LEFT,RIGHT={X=0.5,Y=0.5},{X=0,Y=0.5},{X=1,Y=0.5}
local GROUPS={'photohunt','photohunt_result'}
-- A shot's words kept for a target in one selfie session: the strongest.
local STRONG={counts=4,taken=3,yours=2,close=1}
-- Whole seconds as m:ss.
local function clock_text(s) return string.format('%d:%02d',s//60,s%60) end
-- Words p[key] with n points, then the other arguments: p.one[key] (1 point, no number) when n is 1.
local function counted(p,key,n,...)
    if n==1 then return p.one[key]:format(...) end
    return p[key]:format(n,...)
end
-- Target k's name on screen in words w (targets.lua's name).
function Board.target(cur,k,w) return Tg.name(cur.rows[k],w.photohunt) end
-- The world on screen in words w: its words with the preposition, else its alias.
function Board.where(world,w)
    local p=w.photohunt.places
    return p[world] or p.other:format(world)
end
-- Our points and place on the board of round cur: the go line's players ranked as the host ranks (more points, then
-- the earlier last point; every player with 0 points shares the last place). The card cannot tell who left.
function Board.standing(cur)
    local points,s=Ph.score(cur.board,cur.me)
    local place=1
    for _,id in ipairs(cur.ids or {}) do
        local p,t=Ph.score(cur.board,id)
        if id~=cur.me and (p>points or p==points and points>0 and t<s) then place=place+1 end
    end
    return points,place
end
-- The card of round cur (online/modes/photohunt/round.lua's) at now in words w: its title line, then one {label=,
-- value=, ours=} a target (its name, then open, you or the taker's name: name(id)), then our points and place.
function Board.card(cur,now,w,name)
    local p=w.photohunt
    local at,n=Ph.clock(cur.go,cur.minutes,now)
    local clock=at=='count' and p.count:format(n) or at=='play' and not Ph.full(cur.board) and clock_text(n) or p.up
    local rows={}
    for k=1,Ph.ROWS do
        local t=cur.board[k]
        rows[k]={label=Board.target(cur,k,w),value=not t and p.open or t.id==cur.me and p.you or name(t.id),
            ours=t~=nil and t.id==cur.me}
    end
    local points,place=Board.standing(cur)
    return p.head..'  '..clock,rows,counted(p,'card',points,place)
end
-- The result panel of cur in words w: its heading, the line under it (our points, from our row in the ranking or else
-- the board; '' once a ranking without us came), the note (Waiting for the host's ranking. before it, Not ranked. once
-- a ranking without us came, New personal best. when ours wrote one, No ranking came from the host. after the wait)
-- and one {label=, time=, value=, ours=} per ranked player (time: her last point's seconds since GO, '' with none).
function Board.result(cur,w,name)
    local p=w.photohunt
    local mine=nil
    for _,r in ipairs(cur.list or {}) do if r.id==cur.me then mine=r.points end end
    if not cur.list then mine=Ph.score(cur.board,cur.me) end
    local rows={}
    for i,r in ipairs(cur.list or {}) do
        rows[i]={label=r.place..'  '..name(r.id),time=r.points>0 and clock_text(r.s) or '',value=tostring(r.points),
            ours=r.id==cur.me}
    end
    local note=p.waiting
    if cur.list then note=not mine and p.unranked or cur.best and p.best or ''
    elseif cur.why=='norank' then note=p.norank end
    return p.title,mine and counted(p,'points',mine) or '',note,rows
end
-- o: round() (round.lua's round(): our last photo hunt, or nil), name(id) (her Steam name, ours for our SteamID; nil
-- for one no longer in the session), tell(build) (main.lua's notice: build(words) gives its text), clock() (round.lua's
-- clock), log(line), title() (optional: true on the title screen), selfie() (optional: true while our selfie mode is
-- open).
function Board.new(o)
    local self={}
    local hud=nil -- self.hud's {kit, theme, settings}; nil without one, or after a HUD error.
    -- seen: what this photo hunt showed or said {cur=, said={key=true}, taken={[k]=the taker said}, queue={[k]={word=,
    -- id=}} the shot words waiting for our selfie mode to close, closes= when the result panel closes}.
    local seen=nil
    local picked,lang,words=nil,nil,nil
    local known={} -- The last name each SteamID had: a player who left keeps her name on the card.
    local function shown() return hud~=nil and not hud.kit.off() end
    local function name(id)
        local n=o.name(id)
        if n and n~='' then known[id]=n end
        return Join.name(known[id]) or id
    end
    local function tell(build) if o.tell then o.tell(build) end end
    local function fresh(cur)
        if not seen or seen.cur~=cur then seen={cur=cur,said={},taken={},queue={}} end
    end
    -- A notice once a photo hunt: always (why), or only while the kit cannot show it (what the HUD shows).
    local function once(key,always,build)
        if seen.said[key] then return end
        seen.said[key]=true
        if always or not shown() then tell(build) end
    end
    local function hide() for _,g in ipairs(GROUPS) do hud.kit.show(g,false) end end
    local function colour(row,ours)
        local c=ours and hud.theme.teal or hud.theme.text
        row.label.color(c)
        row.value.color(c)
    end
    local function draw(cur,now,playing,result)
        local kit=hud.kit
        local away=kit.paused()
        local card,res=kit.view('photohunt'),kit.view('photohunt_result')
        kit.show('photohunt',playing and not away and not (o.title and o.title()))
        kit.show('photohunt_result',result and not away)
        if card and (card~=picked or hud.settings.ui_language~=lang) then
            picked,lang=card,hud.settings.ui_language
            words=T.pick(kit.language(),lang)
        end
        local w=words or T.en
        if playing and card then
            local title,rows,line=Board.card(cur,now,w,name)
            card.title.set(title)
            for i,row in ipairs(card.rows) do
                local e=rows[i]
                row.label.set(e and e.label or line)
                row.value.set(e and e.value or '')
                colour(row,e and e.ours)
            end
        end
        if result and res then
            local head,sub,note,rows=Board.result(cur,w,name)
            res.head.set(head)
            res.sub.set(sub)
            res.note.set(note)
            for i,row in ipairs(res.rows) do
                local e=rows[i]
                row.label.set(e and e.label or '')
                row.time.set(e and e.time or '')
                row.value.set(e and e.value or '')
                colour(row,e and e.ours)
            end
        end
    end
    -- Our row of a list, or nil.
    local function ours(cur,list)
        for _,r in ipairs(list or {}) do if r.id==cur.me then return r end end
    end
    local function step()
        local cur=o.round()
        if not cur then
            if hud then hide() end
            return
        end
        fresh(cur)
        local now=o.clock()
        local at=cur.go and Ph.clock(cur.go,cur.minutes,now)
        local playing=cur.phase=='play' and cur.go~=nil
        local over=cur.go~=nil and (at=='up' or Ph.full(cur.board))
        -- Each target taken, once a taker: the host's board (on the host its own).
        for k=1,Ph.ROWS do
            local t=cur.rows and cur.board[k]
            if t and seen.taken[k]~=t.id then
                seen.taken[k]=t.id
                tell(function(w)
                    local target=Board.target(cur,k,w)
                    if t.id==cur.me then return w.photohunt.you_took:format(target) end
                    return w.photohunt.took:format(name(t.id),target)
                end)
            end
        end
        -- The shot words, once our selfie mode closed.
        if next(seen.queue) and not (o.selfie and o.selfie()) then
            for k=1,Ph.ROWS do
                local q=seen.queue[k]
                if q then
                    tell(function(w)
                        return w.photohunt.shot[q.word]:format(Board.target(cur,k,w),q.id and name(q.id) or nil)
                    end)
                end
            end
            seen.queue={}
        end
        if (cur.list or cur.why=='norank') and not seen.closes then seen.closes=now+SHOW end
        local result=(playing and over or cur.list~=nil or cur.why=='norank') and not (seen.closes and now>=seen.closes)
        if cur.phase=='over' then -- A photo hunt that ends without a ranking says why.
            if cur.why=='host_left' then once('why',true,function(w) return w.photohunt.host_left end)
            elseif cur.why=='void' then once('why',true,function(w) return w.photohunt.cancelled end)
            elseif cur.why=='norank' then once('why',false,function(w) return w.photohunt.norank end) end
        end
        if playing and at=='play' then
            once('go',false,function(w) return w.photohunt.go:format(cur.minutes) end)
        end
        if over and (playing or cur.phase=='ranked') then
            once('end',false,function(w) return counted(w.photohunt,'end_notice',(Ph.score(cur.board,cur.me))) end)
        end
        if cur.list then
            local list=cur.list
            if list[1] then
                once('top',false,function(w)
                    local p,each=w.photohunt,{}
                    for i=1,math.min(TOP_THREE,#list) do
                        each[i]=p.entry:format(list[i].place,name(list[i].id),list[i].points)
                    end
                    return p.top:format(table.concat(each,p.sep))
                end)
            end
            once('placed',false,function(w)
                local r=ours(cur,list)
                return r and w.photohunt.placed:format(r.place,#list) or w.photohunt.unranked
            end)
            if cur.best then once('best',false,function(w) return w.photohunt.best end) end -- The panel's note.
        end
        if not shown() then return end
        draw(cur,now,playing,result)
    end
    -- Every 250 ms, after the round's pass and the game side's: the notices, then the HUD. An error in the HUD gives
    -- one STOP line and notices from then on.
    function self.tick()
        local ok,e=pcall(step)
        if ok then return end
        o.log('STOP: HUD: '..tostring(e))
        if hud then pcall(hide) end
        hud=nil
    end
    -- game.lua's feedback(k, word): a shot's words for target k of our round (counts, close, yours, taken; taken
    -- names the taker the board had then), kept until our selfie mode closes.
    function self.feedback(k,word)
        local cur=o.round()
        if not (cur and cur.rows and cur.rows[k] and STRONG[word]) then return end
        fresh(cur)
        local q=seen.queue[k]
        if q and STRONG[q.word]>=STRONG[word] then return end
        seen.queue[k]={word=word,id=word=='taken' and cur.board[k] and cur.board[k].id or nil}
    end
    -- round.lua's and game.lua's tell(key, ...), said whatever the kit shows: starts (the host's name, the minutes, the
    -- world alias, the three targets' row names) with the Camera's notice after it, out (check()'s why: off, slot,
    -- checks), stopped (the none answer's why: fault, unpinned; names), reloaded.
    function self.notice(key,a,b,c,...)
        local rows={...}
        tell(function(w)
            local p=w.photohunt
            if key=='starts' then
                local each={}
                for k,row in ipairs(rows) do each[k]=Tg.name(row,p) end
                return p.start:format(Join.name(a) or tostring(a),Board.where(c,w),table.concat(each,p.sep),b)
            end
            if key=='out' then return p.out[a] or p.out.checks end
            if key=='stopped' then return p.stopped[a] or p.stopped.fault end
            return p.reloaded
        end)
        if key=='starts' then tell(function(w) return w.photohunt.camera end) end
    end
    -- coop off (or any stop): every group hidden now, as no tick may come after it to hide them.
    function self.stop() if hud then pcall(hide) end end
    -- The groups on the Uplink kit, before its first build (main/ui.lua's hud step, after the fishing tournament's): h
    -- is {kit, theme=ui.THEME, settings= (main.lua's, ui_language read at each update)}.
    function self.hud(h)
        hud=h
        local kit,theme=h.kit,h.theme
        kit.add('photohunt',{x=3840-SIDE-CORNER_W,y=TOP,w=CORNER_W,h=TITLE_H+GAP+CORNER_ROWS*ROW_H,pivot={X=1,Y=0}},
            function(b)
                b.panel(0,0,CORNER_W,TITLE_H)
                local v={title=b.text(CORNER_W/2,TITLE_H/2,'','name',theme.warn,MIDDLE),rows={}}
                for i=1,CORNER_ROWS do
                    local y=TITLE_H+GAP+(i-1)*ROW_H
                    v.rows[i]={back=b.image(0,y,CORNER_W,ROW_H-4,nil,theme.panel),
                        label=b.text(32,y+ROW_H/2-2,'','body',theme.text,LEFT),
                        value=b.text(CORNER_W-32,y+ROW_H/2-2,'','body',theme.text,RIGHT)}
                end
                return v
            end)
        local x=(3840-HUD_W)/2
        kit.add('photohunt_result',{x=x,y=TOP,w=HUD_W,h=RESULT_H,pivot={X=0.5,Y=0}},function(b)
            b.panel(0,0,HUD_W,RESULT_H)
            local v={head=b.text(HUD_W/2,70,'','title',theme.teal,MIDDLE),
                sub=b.text(HUD_W/2,136,'','body',theme.text,MIDDLE),
                note=b.text(HUD_W/2,186,'','body',theme.grey,MIDDLE),rows={}}
            for i=1,RANK_ROWS do
                local y=250+(i-1)*56
                v.rows[i]={label=b.text(64,y,'','body',theme.text,LEFT),
                    time=b.text(780,y,'','status',theme.grey,RIGHT),
                    value=b.text(HUD_W-64,y,'','item',theme.text,RIGHT)}
            end
            return v
        end)
    end
    return self
end
return Board
